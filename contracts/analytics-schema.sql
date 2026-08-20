-- =============================================================================
-- Enterprise Trading Platform: analytical schema (dimensional model)
-- Status: binding. First used in Sprint 4, loaded in full in Sprint 7.
-- =============================================================================
--
-- WHY A SECOND SCHEMA
--
-- The operational schema you design in Sprint 3 is normalised so that a write
-- touches one row and a constraint can be trusted. That shape is wrong for
-- analysis. "Trade value by asset class by quarter" against normalised tables
-- is four joins and a full scan, run while somebody is trying to place an
-- order.
--
-- This schema answers the analytical questions instead. It is denormalised,
-- append-mostly, and loaded by the Python ETL. It is never written to by a
-- service and never read by one.
--
-- Modelled as a star: one fact table surrounded by dimensions, joined on
-- integer surrogate keys. A star is chosen over a snowflake because the join
-- depth is one, which is what makes the queries readable to an analyst who is
-- not an engineer.
--
-- SOURCE
--
-- Tables and columns follow the project specification, section 18.2, without
-- alteration. Keys, constraints, the two additional fact columns and the
-- audit columns are supplied here because the specification stops at column
-- names. Each addition is marked.
--
-- WHERE IT RUNS
--
-- DuckDB. One file on disk, no server, no account and no credentials. It reads
-- Parquet and CSV directly, it has real DECIMAL, and the analytics service
-- creates, loads and reads it.
--
-- The DDL below is nevertheless written in plain ANSI SQL rather than in DuckDB
-- dialect. That is what makes the model portable to a hosted warehouse without
-- a rewrite, and it is the property that made DuckDB a safe choice in the first
-- place. What is assessed is the model and the load, not the store.
--
-- Portability rules followed here, and to follow in any SQL you add:
--   - No IDENTITY, SERIAL, AUTOINCREMENT or SEQUENCE. Surrogate keys are
--     assigned by the ETL, which is where the key lookup already happens.
--   - No vendor date functions in DDL. DIM_DATE is populated by the ETL.
--   - DECIMAL, not NUMERIC or NUMBER. VARCHAR, not TEXT or STRING.
--   - No CHECK constraint that a target might not enforce. Data quality is
--     enforced in the pipeline, before load, where a failure can be
--     dead-lettered and reported.
--
-- LOADING IT
--
-- The load is incremental, driven by a watermark on orders.created_on. Load
-- dimensions before facts, or a fact row will reference a key that does not
-- exist yet. Make the load idempotent: re-running yesterday's load must not
-- double-count. Merge on the natural key, do not blindly insert.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- DIM_ACCOUNT
-- One row per account per version of that account.
-- Specification: section 18.2.
--
-- effective_date makes this a slowly changing dimension. An account that moves
-- from ACTIVE to SUSPENDED gets a new row, it does not overwrite the old one.
-- Overwriting would silently rewrite history: a trade placed last month while
-- the account was active would report as having been placed on a suspended
-- account. That is the whole reason the column exists.
--
-- end_date and is_current are added here. The specification gives only
-- effective_date, which is enough to record when a version started but not
-- enough to find the current version without a correlated subquery on every
-- query. Type 2 dimensions carry all three in practice.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_account (
    account_key     BIGINT       NOT NULL,
    account_id      VARCHAR(32)  NOT NULL,
    holder_name     VARCHAR(255) NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    effective_date  DATE         NOT NULL,

    -- Added here, not in the specification.
    end_date        DATE,
    is_current      BOOLEAN      NOT NULL,
    source_id       BIGINT       NOT NULL,
    loaded_at       TIMESTAMP    NOT NULL,

    CONSTRAINT pk_dim_account PRIMARY KEY (account_key)
);

-- account_key   Surrogate key assigned by the ETL. Never the operational id.
--               A surrogate lets a version of an account exist independently of
--               the row it came from.
-- account_id    The business account reference from accounts.account_id. This
--               is the natural key the ETL merges on, together with
--               effective_date.
-- source_id     The operational accounts.id. Kept for lineage, so that a fact
--               row can be traced back to the system of record. Do not join on
--               it.
-- end_date      NULL on the current version. Set to the day before the next
--               version starts when a new version is written.
-- is_current    TRUE on exactly one row per account_id. Every dashboard query
--               that wants "accounts as they are now" filters on this.


-- -----------------------------------------------------------------------------
-- DIM_INSTRUMENT
-- One row per tradable instrument.
-- Specification: section 18.2.
--
-- Type 1: instrument attributes are overwritten in place. A company changing
-- its name does not change the meaning of a trade from two years ago, so there
-- is no reason to keep the old name. Contrast that with account status, which
-- does change the meaning.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_instrument (
    instrument_key  BIGINT       NOT NULL,
    symbol          VARCHAR(20)  NOT NULL,
    name            VARCHAR(255) NOT NULL,
    asset_class     VARCHAR(20)  NOT NULL,
    currency        CHAR(3)      NOT NULL,

    -- Added here, not in the specification.
    exchange        VARCHAR(20),
    tradable        BOOLEAN      NOT NULL,
    loaded_at       TIMESTAMP    NOT NULL,

    CONSTRAINT pk_dim_instrument PRIMARY KEY (instrument_key),
    CONSTRAINT uq_dim_instrument_symbol UNIQUE (symbol)
);

-- symbol      The natural key. Unique, because this dimension is Type 1 and
--             holds one row per instrument.
-- exchange    Derived by the ETL from the Fauxnance symbol scheme: a .NS
--             suffix means NSE, .BO means BSE, an FX: prefix means FX, X:
--             means crypto, and a plain ticker means a US venue. Added because
--             "volume by venue" is a question the dashboard is asked and the
--             operational schema cannot answer it.


-- -----------------------------------------------------------------------------
-- DIM_DATE
-- One row per calendar day. Pre-populated by the ETL, typically for ten years,
-- before any fact is loaded.
-- Specification: section 18.2.
--
-- A date dimension exists so that "trades by quarter" is a join and a GROUP BY
-- rather than a vendor-specific date function embedded in every query. It also
-- carries facts about a date that cannot be computed from the date itself,
-- such as whether a market was open.
-- -----------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key    INTEGER     NOT NULL,
    full_date   DATE        NOT NULL,
    day         INTEGER     NOT NULL,
    month       INTEGER     NOT NULL,
    year        INTEGER     NOT NULL,
    quarter     INTEGER     NOT NULL,

    -- Added here, not in the specification.
    day_of_week INTEGER     NOT NULL,
    day_name    VARCHAR(9)  NOT NULL,
    month_name  VARCHAR(9)  NOT NULL,
    is_weekday  BOOLEAN     NOT NULL,

    CONSTRAINT pk_dim_date PRIMARY KEY (date_key),
    CONSTRAINT uq_dim_date_full_date UNIQUE (full_date)
);

-- date_key    An integer in YYYYMMDD form, for example 20260928. Integer keys
--             sort and range-scan in date order, join faster than dates, and
--             stay readable in a result set. This is the one place a
--             "meaningful" surrogate key is standard practice.
-- day_name    Full name, for example 'Wednesday'. Held rather than computed so
--             that a dashboard renders identical labels on every target.
-- is_weekday  Trading activity concentrates on weekdays. Charts that ignore
--             this show a five-day sawtooth that a reader misreads as a
--             trend.


-- -----------------------------------------------------------------------------
-- FACT_TRADES
-- One row per order, in whatever status it reached.
-- Specification: section 18.2.
--
-- The grain is one order, not one execution and not one order-state change.
-- State the grain before writing a fact table: nearly every dimensional
-- modelling error is a grain that was never decided.
--
-- Rejected and cancelled orders are loaded, not filtered out. Fill rate is one
-- of the analytics the curriculum asks for, and it cannot be computed from
-- fills alone.
-- -----------------------------------------------------------------------------
CREATE TABLE fact_trades (
    trade_key       BIGINT        NOT NULL,
    account_key     BIGINT        NOT NULL,
    instrument_key  BIGINT        NOT NULL,
    date_key        INTEGER       NOT NULL,
    side            VARCHAR(4)    NOT NULL,
    quantity        INTEGER       NOT NULL,
    price           DECIMAL(18,2) NOT NULL,
    status          VARCHAR(20)   NOT NULL,

    -- Added here, not in the specification.
    executed_price  DECIMAL(18,2),
    trade_value     DECIMAL(18,2) NOT NULL,
    source_order_id VARCHAR(36)   NOT NULL,
    created_at      TIMESTAMP     NOT NULL,
    loaded_at       TIMESTAMP     NOT NULL,

    CONSTRAINT pk_fact_trades PRIMARY KEY (trade_key),
    CONSTRAINT uq_fact_trades_source UNIQUE (source_order_id),
    CONSTRAINT fk_fact_trades_account
        FOREIGN KEY (account_key)    REFERENCES dim_account (account_key),
    CONSTRAINT fk_fact_trades_instrument
        FOREIGN KEY (instrument_key) REFERENCES dim_instrument (instrument_key),
    CONSTRAINT fk_fact_trades_date
        FOREIGN KEY (date_key)       REFERENCES dim_date (date_key)
);

-- trade_key        Surrogate key assigned by the ETL.
-- source_order_id  The operational orders.id as text. The unique constraint on
--                  it is what makes the load idempotent: re-running a window
--                  cannot insert the same order twice. Enforce it in the
--                  pipeline as well, because some warehouse configurations
--                  will not.
-- quantity, price  Additive and semi-additive measures. quantity sums.
--                  price does NOT sum: averaging or summing a price across
--                  rows is meaningless. Sum trade_value instead. This mistake
--                  appears in roughly half of first dashboards.
-- trade_value      quantity multiplied by executed_price where the order
--                  filled, otherwise quantity multiplied by price. Precomputed
--                  in the ETL rather than in every query, because it is the
--                  measure nearly every question aggregates.
-- executed_price   NULL for orders that never filled.
-- created_at       The operational orders.created_on. date_key is derived from
--                  it. Kept so that intraday analysis is still possible, since
--                  the date dimension only reaches day grain.
-- loaded_at        When the ETL wrote the row. Not a business attribute. It is
--                  how you answer "is the warehouse behind" without guessing.


-- =============================================================================
-- INDEXES
-- Not in the specification, and deliberately few.
--
-- DuckDB supports indexes and benefits from them on the foreign keys. The
-- statements below are commented out: apply the ones a query of yours actually
-- needs, and be able to name that query.
--
-- Worth knowing before you meet one: a columnar warehouse has no user-defined
-- indexes at all. It prunes by micro-partition, and the same star is tuned
-- there by declaring a clustering key on date_key. The model does not change;
-- only the mechanism that makes it fast does.
-- =============================================================================

-- CREATE INDEX ix_fact_trades_date       ON fact_trades (date_key);
-- CREATE INDEX ix_fact_trades_account    ON fact_trades (account_key);
-- CREATE INDEX ix_fact_trades_instrument ON fact_trades (instrument_key);
-- CREATE INDEX ix_dim_account_current    ON dim_account (account_id, is_current);


-- =============================================================================
-- THE ANALYTICS THIS MODEL HAS TO SUPPORT
--
-- The curriculum names five. Each must be answerable with one join per
-- dimension and no subquery. If one of them is awkward against your model, the
-- model is wrong, not the question.
--
--   Trade volume         count and summed trade_value by date_key.
--   Most active accounts count by account_key, joined to dim_account where
--                        is_current is true.
--   Fill rate            count where status = 'FILLED' divided by total count,
--                        by date_key. This is why rejected orders are loaded.
--   Exposure by          summed trade_value by instrument_key and side, joined
--   instrument           to dim_instrument.
--   Average trade size   average trade_value over a date range. Note that this
--                        averages values, not prices.
--
-- Worked example, fill rate by month:
--
--   SELECT d.year,
--          d.month,
--          COUNT(*)                                                  AS orders_placed,
--          SUM(CASE WHEN f.status = 'FILLED' THEN 1 ELSE 0 END)      AS orders_filled,
--          SUM(CASE WHEN f.status = 'FILLED' THEN 1 ELSE 0 END) * 100.0
--            / COUNT(*)                                              AS fill_rate_pct
--     FROM fact_trades f
--     JOIN dim_date    d ON d.date_key = f.date_key
--    GROUP BY d.year, d.month
--    ORDER BY d.year, d.month;
--
-- One join, one GROUP BY, readable by a non-engineer. That is the test of a
-- star schema.
-- =============================================================================


-- =============================================================================
-- LOAD ORDER AND DATA QUALITY
--
-- Run in this order on every load:
--
--   1. dim_date        once, ahead of everything, covering the full range.
--   2. dim_instrument  merge on symbol, Type 1 overwrite.
--   3. dim_account     merge on account_id, Type 2. Close the previous version
--                      by setting end_date and is_current = FALSE, then insert
--                      the new version.
--   4. fact_trades     insert orders created since the last watermark,
--                      resolving each dimension key by lookup.
--
-- Checks to run before load, failing the batch or dead-lettering the row:
--
--   - Every fact row resolves to an existing account_key, instrument_key and
--     date_key. An unresolved key means the dimension load was skipped, and
--     inserting a placeholder row to make it pass hides the real fault.
--   - quantity > 0 and price > 0.
--   - side is BUY or SELL; status is one of the four order statuses.
--   - trade_value equals its inputs, recomputed rather than trusted.
--   - source_order_id has not been loaded before.
--
-- Reconcile after load: the row count and summed trade_value in fact_trades
-- for a given day must equal the same figures computed against Postgres for
-- that day. A pipeline nobody reconciles is a pipeline nobody can trust, and
-- the reconciliation query is part of the Sprint 7 deliverable.
-- =============================================================================
