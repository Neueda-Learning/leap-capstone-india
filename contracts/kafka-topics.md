# Kafka topic catalogue

Status: binding. Sprint 7 builds these three topics. Sprint 10 extensions consume them. A team that renames a topic or changes a field breaks every downstream consumer in the platform, including ones another team wrote.

## Why the platform has an event bus at all

Until Sprint 7, placing an order is one HTTP request that validates, fills, writes and returns. That works only because nothing real is happening. Real execution takes time, fails part way, and has to survive the trading service restarting mid-flight. It also has more than one interested party: the account has to be updated, the customer notified, the analytics estate loaded, and any strategy service told what happened.

Both problems have the same answer. The service that accepts the order records it and publishes it. Something else executes it and publishes the result. Everyone else subscribes. The Trade REST API stops needing to know who cares.

## Topics

| Topic | Purpose | Key | Partitions | Replication | Retention | Cleanup |
|---|---|---|---|---|---|---|
| `orders` | Orders accepted by the Trade REST API and awaiting execution. A work queue with one logical consumer group. | `accountId` as a string | 3 | 1 locally, 3 in a real cluster | 7 days | delete |
| `trade-events` | Order lifecycle outcomes: filled, rejected, cancelled. The platform's event log, read by many consumers. | `accountId` as a string | 3 | 1 locally, 3 in a real cluster | 30 days | delete |
| `market-data` | Quotes polled from the Fauxnance API. High volume, low value per message. | `symbol` | 6 | 1 locally, 3 in a real cluster | 1 day | delete |

The specification calls the first topic `trades`. This catalogue names it `orders`, because everything on it is an accepted order that has not yet been executed. `trades` is accepted where a team has already built against it, but one repository uses one name.

### Choosing the key

The key decides the partition, and the partition decides the ordering guarantee. Kafka orders messages within a partition and gives no ordering across partitions.

`orders` and `trade-events` are keyed by `accountId` because the ordering that matters is per account. Two orders on the same account must be executed in the order they were accepted, or a sell can be processed before the buy that made it possible. Two orders on different accounts have no relationship and can be processed in parallel.

`market-data` is keyed by `symbol` because the ordering that matters is per instrument: a consumer must never see an older quote for `AAPL` after a newer one. Quotes for different symbols are independent.

Never key by order identifier. Every message would land on its own partition and per-account ordering would be gone.

### Choosing partition counts

Three partitions on `orders` and `trade-events` lets three executor instances run in one consumer group, which is enough to demonstrate rebalancing and enough to show that a consumer group cannot usefully exceed the partition count. Six on `market-data` reflects its higher message rate.

Partitions can be increased later but never decreased, and increasing them rehashes keys, so an account's history splits across partitions from that point. Pick the number deliberately in Sprint 7 and record why.

## Message schemas

Serialisation is JSON with UTF-8 encoding. Every message carries an envelope of five fields plus a `payload`. The envelope is identical on all three topics so that one deserialiser and one dead-letter handler cover the platform.

| Envelope field | Type | Notes |
|---|---|---|
| `eventId` | string, UUID | Unique per message. The idempotency key for consumers. |
| `eventType` | string, enum | Discriminates the payload. |
| `eventTime` | string, RFC 3339 date-time in UTC | When the producer created the event, not when it was consumed. |
| `source` | string | Producing component: `trade-api`, `trade-executor`, `market-poller`. |
| `schemaVersion` | integer | Starts at 1. Increment only on a breaking change. |
| `payload` | object | Topic-specific and event-type-specific. |

`source` names the component that produced the message, not the container it shipped in. Quotes on `market-data` therefore carry `market-poller` even though the poller runs inside the Trade Executor, which keeps a quote distinguishable from an execution event in the same way it always was.

Adding an optional field is not a breaking change and does not increment `schemaVersion`. Removing a field, renaming one, or changing its type is breaking. Consumers must ignore fields they do not recognise.

### `orders`

`eventType` is always `ORDER_PLACED`.

| Payload field | Type | Notes |
|---|---|---|
| `orderId` | string, UUID | Matches `orders.id` in Postgres. |
| `accountId` | integer, int64 | The numeric account key. Also the message key, as a string. |
| `symbol` | string | Instrument symbol in the Fauxnance scheme. |
| `side` | string, enum `BUY` or `SELL` | |
| `quantity` | integer, int32 | Greater than zero. |
| `price` | number | Limit price per unit, two decimal places. |
| `idempotencyKey` | string | The client key that was accepted. |
| `createdOn` | string, date-time | When the order was recorded. |

```json
{
  "eventId": "b19d2c5a-8f31-4d0e-9a77-1c3e5f7a9b0d",
  "eventType": "ORDER_PLACED",
  "eventTime": "2026-09-28T09:14:22Z",
  "source": "trade-api",
  "schemaVersion": 1,
  "payload": {
    "orderId": "6f2b1c2a-6a1e-4a4f-9c0d-2f7a1b3c4d5e",
    "accountId": 1,
    "symbol": "AAPL",
    "side": "BUY",
    "quantity": 100,
    "price": 233.00,
    "idempotencyKey": "6f2b1c2a-6a1e-4a4f-9c0d-2f7a1b3c4d5e",
    "createdOn": "2026-09-28T09:14:22Z"
  }
}
```

Publish after the database commit, not inside the transaction. Publishing first risks an event for an order that was rolled back, which is unrecoverable. Publishing after risks a committed order that was never published, which is recoverable by replaying from the order table. Choose the recoverable failure.

### `trade-events`

`eventType` is one of `ORDER_FILLED`, `ORDER_REJECTED`, `ORDER_CANCELLED`.

| Payload field | Type | Notes |
|---|---|---|
| `orderId` | string, UUID | |
| `accountId` | integer, int64 | Also the message key, as a string. |
| `symbol` | string | |
| `side` | string, enum | |
| `quantity` | integer, int32 | Quantity filled. Equal to the ordered quantity, since partial fills are out of scope. |
| `price` | number | The limit price from the order. |
| `executedPrice` | number or null | The Fauxnance quote the fill was priced at. Null on reject and cancel. |
| `status` | string, enum `FILLED`, `REJECTED`, `CANCELLED` | Terminal order status. |
| `reason` | string or null | Populated on reject and cancel. For example `INSUFFICIENT_FUNDS`, `PRICE_NOT_MET`, `INSTRUMENT_NOT_TRADABLE`, `CANCELLED_BY_CUSTOMER`. |
| `cashDelta` | number | Signed change to the cash balance. Negative for a buy. |
| `positionQuantityAfter` | integer, int32 | Net held quantity after the event. |
| `averageCostAfter` | number | Weighted average cost after the event. |
| `executedOn` | string, date-time | |

```json
{
  "eventId": "d47f9a10-3e2b-4c88-b0a1-7e6d5c4b3a29",
  "eventType": "ORDER_FILLED",
  "eventTime": "2026-09-28T09:14:24Z",
  "source": "trade-executor",
  "schemaVersion": 1,
  "payload": {
    "orderId": "6f2b1c2a-6a1e-4a4f-9c0d-2f7a1b3c4d5e",
    "accountId": 1,
    "symbol": "AAPL",
    "side": "BUY",
    "quantity": 100,
    "price": 233.00,
    "executedPrice": 232.71,
    "status": "FILLED",
    "reason": null,
    "cashDelta": -23271.00,
    "positionQuantityAfter": 300,
    "averageCostAfter": 229.83,
    "executedOn": "2026-09-28T09:14:24Z"
  }
}
```

A rejection is an event. Publish it. Notifications, analytics and the blotter all need to know that an order failed, and a consumer that only ever sees fills will report a fill rate of 100 per cent.

`cashDelta`, `positionQuantityAfter` and `averageCostAfter` are included so that a consumer can maintain its own projection of the portfolio without querying Postgres. That is what makes the Portfolio and P&L extension possible without a read dependency on the trading database.

### `market-data`

`eventType` is always `QUOTE`.

| Payload field | Type | Notes |
|---|---|---|
| `symbol` | string | Also the message key. |
| `price` | number | Latest quoted price. |
| `currency` | string, 3 characters | ISO 4217. |
| `change` | number or null | Absolute change against previous close. |
| `changePercent` | number or null | Percentage points. `0.09` means 0.09 per cent. |
| `previousClose` | number or null | |
| `marketState` | string, enum `open`, `closed`, `pre`, `post`, `unknown` | Passed through from Fauxnance. |
| `stale` | boolean | True when Fauxnance flagged the quote as past its freshness window. |
| `quoteAsOf` | string, date-time | Observation time from Fauxnance, not the poll time. |

```json
{
  "eventId": "3a5c7e91-2b4d-4f60-8c1e-9d0f2a4b6c8e",
  "eventType": "QUOTE",
  "eventTime": "2026-09-28T09:15:00Z",
  "source": "market-poller",
  "schemaVersion": 1,
  "payload": {
    "symbol": "AAPL",
    "price": 232.71,
    "currency": "USD",
    "change": 0.21,
    "changePercent": 0.09,
    "previousClose": 232.50,
    "marketState": "open",
    "stale": false,
    "quoteAsOf": "2026-09-28T09:14:58Z"
  }
}
```

`eventTime` and `quoteAsOf` differ, and the difference matters. `eventTime` is when the poller published. `quoteAsOf` is when the price was observed. Fauxnance serves delayed quotes, so a strategy service acting on `eventTime` is acting on a price that is older than it thinks.

Publish one message per symbol, not one message per batch. Batching the HTTP call is a quota optimisation; batching the Kafka message would break per-symbol keying and ordering.

## Producer and consumer matrix

| Service | `orders` | `trade-events` | `market-data` |
|---|---|---|---|
| Trade REST API | produce | consume, optional, to update read models | not used |
| Trade Executor | consume, group `trade-executor` | produce | produce, from the scheduled poller inside it |
| Python ETL | not used | consume, optional, group `analytics-loader` | not used |
| Portfolio and P&L, in the Trade REST API | not used | consume, group `portfolio-service` | consume, group `portfolio-service` |
| Watchlists and price alerts, in the Trade REST API | not used | not used | consume, group `watchlist-service` |
| Customer notifications, in the Trade REST API | not used | consume, group `notification-service` | not used |
| Customer preferences, in the Trade REST API | not used | not used | not used |
| Trade advice and signals, in the Trade REST API | not used | consume, group `advice-service` | consume, group `advice-service` |
| Automated strategy execution, in the Trade REST API | not used | consume, group `strategy-service` | consume, group `strategy-service` |
| Angular UI | never | never | never |

Two rules follow from the matrix.

`orders` has exactly one consumer group. It is a work queue: adding a second group means two services executing the same order. If something else needs to know an order was placed, it reads `trade-events`, or the Trade REST API publishes a separate notification event.

The Angular UI never speaks to Kafka. Browsers do not hold Kafka credentials. Push to the UI, where a team builds it, goes through a service over WebSocket or server-sent events.

Every consumer sets an explicit `group.id`. Two different consumers sharing a group identifier will split the partitions between them and each will see only part of the stream, which presents as messages going missing at random.

The group ids stay distinct per extension module, even though the modules now run in one process. A group id names a logical consumer, and separate ids keep each module's offsets independent: a redeployed notifications consumer must not move the watchlist consumer's position in the stream.

## Delivery semantics

The platform runs at-least-once. Producers retry, consumers commit offsets after processing, and duplicates therefore happen. Plan for them; do not try to eliminate them.

**Producers.** Set `acks=all`, `enable.idempotence=true`, `retries` high and `max.in.flight.requests.per.connection=5` or fewer. Idempotent producers remove duplicates caused by a producer retry. They do not remove duplicates caused by an application retrying after a crash.

**Consumers.** Disable auto-commit. Process the message, then commit the offset. Committing first means a crash loses the message; committing after means a crash reprocesses it. Reprocessing is survivable if the handler is idempotent, and losing a trade is not.

**Idempotent handling.** Every consumer that has a side effect must be able to see the same `eventId` twice without doing the work twice. Two mechanisms are acceptable:

1. A processed-events table keyed on `eventId`, written inside the same transaction as the side effect. A duplicate hits the primary key and the transaction rolls back with nothing done.
2. A guarded state transition. The Trade Executor updates `orders` with `WHERE id = ? AND status = 'NEW'` and treats zero rows affected as "already handled". No extra table, and it holds under concurrency because the database serialises the update.

The Trade Executor uses the second mechanism. It is the exact mechanism a team must be able to demonstrate in the Sprint 7 acceptance check: replay a consumed `ORDER_PLACED` message and show that the cash balance does not move twice.

**Dead-letter handling.** A message that fails deserialisation, fails validation, or fails processing after a bounded number of retries goes to a dead-letter topic named `<topic>.DLT`, with the original message as the value and the failure reason in a header. Do not retry a poison message indefinitely: one bad message blocking a partition stops every account keyed to that partition.

Distinguish the two failure classes. A malformed message will never succeed, so send it to the dead-letter topic on the first attempt. A transient failure, for example Fauxnance returning 503, will succeed later, so retry it with backoff and only dead-letter it after the retry budget is spent.

**Ordering.** Guaranteed within a partition, so guaranteed per account and per symbol, and guaranteed nowhere else. A consumer that assumes it will see a fill for account 1 before a fill for account 2 is relying on an ordering the platform never promised.

**Exactly-once.** Kafka transactions can give exactly-once between topics. This platform does not use them, because the side effects here are database writes rather than topic writes, and the guarded transition above gives the same outcome with less machinery. Teams should be able to explain that choice.

## Local operation

Your team runs the broker, as `infra/README.md` requires. It starts empty, and creating the topics is the team's work too: no creation script ships with the platform and nothing creates them on your behalf.

Auto-creation is switched off on the broker and stays off. It produces a one-partition topic with default retention, which is wrong for all three topics here, and it produces it silently on first use. With it off, a team that has not created its topics gets an error rather than a subtly wrong platform, which is the failure you can act on.

The three commands below state what the contracted topics require. Where the command lives, whether it is a script, a Makefile target or three lines typed once and recorded, is the team's decision.

```bash
kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic orders --partitions 3 --replication-factor 1 \
  --config retention.ms=604800000

kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic trade-events --partitions 3 --replication-factor 1 \
  --config retention.ms=2592000000

kafka-topics.sh --bootstrap-server localhost:9092 --create \
  --topic market-data --partitions 6 --replication-factor 1 \
  --config retention.ms=86400000
```

Watch consumer lag while testing. A group whose lag climbs steadily is not keeping up, and on `market-data` that usually means the poller interval is shorter than the consumer's processing time.

## Security

Local development runs plaintext with no authentication, because TLS, SASL and ACLs on a single-node broker teach configuration rather than architecture. Document what you would configure in production: TLS between clients and brokers, SASL for client authentication, and per-topic ACLs so that only the Trade REST API can write to `orders` and only the Trade Executor can read it. Document it as a plan. Do not claim it is implemented.

Never put a credential, a full name, an email address or an API key in a message payload. Topics are retained for days and read by services that have no need for that data.
