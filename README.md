# Enterprise Trading Platform

A working trading platform, built by your team over nine weeks, one component
per sprint. Customers hold accounts, place buy and sell orders against real
instruments, and see their positions and cash move. Orders are accepted by a
REST API, executed asynchronously against live market prices, recorded in a
transactional database, published as events, loaded into an analytical store,
and driven from a browser.

Nothing about that is a toy. The problems are the ones a real trading system
has: an order that must not be executed twice, a price that arrives stale, a
token that must be verified before a single claim in it is trusted, a schema
that has to answer both "what is this account's cash balance right now" and
"what was trade value by asset class last quarter".

## What you will have built by week 9

| Component | What it does |
|---|---|
| Trade database | A normalised Postgres schema for accounts, instruments, orders and positions, with the constraints and indexes that keep it correct under concurrent writes |
| Analytics pipeline | A Python extract, transform, load pipeline into a DuckDB star schema, and a dashboard that answers business questions rather than showing charts |
| Domain package | The trading rules in Java 21, unit tested, with no database and no HTTP anywhere near them. Sprint 6 absorbs it as source |
| Trade REST API | A layered, Dockerised Spring Boot service implementing `contracts/trade-api.yaml`, persisting through MyBatis, verifying a JWT on every route. It hosts the domain package and every extension module |
| Event backbone | The Kafka topics your team creates and configures, and the Trade Executor that fills orders against live quotes and runs the market-data poller that turns a request-response pricing API into a stream |
| Auth service | A NestJS service issuing and validating JWTs, with hashed credentials and refresh tokens |
| Trading UI | An Angular application: login, dashboard, order ticket and blotter, with a typed client generated from the contracts and Playwright tests |
| Extensions | Four integrated modules inside the Trade REST API: Portfolio and P&L, Customer Preferences, Customer Notifications, and Watchlists and Price Alerts |

Each component depends on the ones before it. The platform accumulates. What
you build in Sprint 3 is what Sprint 6 queries, and what Sprint 6 exposes is
what Sprint 9 renders. There is no throwaway week.

## The nine weeks

Week 1 is induction and carries no capstone deliverable. The capstone runs
from week 2 to week 9, as Sprints 3 to 10. Sprint numbers and week numbers
differ by one for the whole run, which is deliberate: the sprint numbering is
shared across every Leap cohort, and the week numbering is yours.

| Week | Sprint | Component | Folder |
|---|---|---|---|
| 1 | Induction | No capstone deliverable | none |
| 2 | 3 | Data systems and data modelling | `sprint-03-trade-database` |
| 3 | 4 | Financial services and data analytics | `sprint-04-analytics-etl` |
| 4 | 5 | Software engineering, Java and OOAD | `sprint-05-domain-engine` |
| 5 | 6 | Software architecture and enterprise Java | `sprint-06-trade-api` |
| 6 | 7 | Enterprise data engineering and engineering excellence | `sprint-07-event-backbone` |
| 7 | 8 | Node.js, NestJS and authentication | `sprint-08-auth-service` |
| 8 | 9 | UI development with Angular | `sprint-09-trading-ui` |
| 9 | 10 | Applied project | `sprint-10-extensions` |

Two weeks are shorter than the rest. The Monday of the Sprint 7 week is Ganesh
Chaturthi and the Friday of the Sprint 9 week is Gandhi Jayanti. Both are
holidays, both weeks have one fewer taught day, and the material for those
sprints is scoped for four days rather than five. Plan the sprint accordingly
rather than discovering it on the Thursday. Confirm the dates with the
delivery team; this file gives no dates on purpose.

### After Sprint 10: cloud deployment

Cloud deployment runs as a separate week after the capstone, delivered by
Fidelity as experiential learning and supported by Fidelity alumni. You deploy
the Angular build to a private S3 bucket behind CloudFront, with an automated
build, upload and invalidate cycle, and share the link. It assumes a Sprint 10
build whose own tests pass and a local stack that starts cleanly, so leave your
repository in that state at the end of week 9. Material for the
week is supplied separately.

## How this repository is organised

```
contracts/    Binding interface definitions. Read contracts/README.md.
infra/        Requirements for the local infrastructure. Read infra/README.md.
.env.example  Environment template. Copy to .env, never commit .env.
```

One folder per sprint arrives at the start of that sprint, named as in the
table above. Each carries its own README with the reasoning for the component,
the deliverable, the acceptance criteria and the tests. Work for that sprint
goes in that folder unless the README says otherwise. Create the service and
infrastructure layout your team needs, and document the decisions you make.

The platform is one repository and one stack. By Sprint 10 your local
orchestration describes five containers, all of which your team created:
Postgres, Kafka, the Trade REST API, the Trade Executor and the auth service.
The Angular dev server and the Python tooling run on the host. Four extensions
and the domain package add no containers, because they are packages inside the
Trade REST API.

## Local infrastructure

This branch supplies infrastructure requirements, not an executable local
stack. Your team creates the local Postgres and Kafka setup described in
`infra/README.md`, including topic creation and service orchestration.

Postgres starts empty: no schema and no seed data ship with this branch,
because designing the schema is the Sprint 3 deliverable. Kafka starts with no
topics on it, because creating the topics in `contracts/kafka-topics.md` and
justifying their shape is the Sprint 7 deliverable.

Copy `.env.example` to `.env` before the first run and replace
`FAUXNANCE_API_KEY` with the key issued to you. Every other value has a working
local default.

## Market data: the Fauxnance API

Prices come from Fauxnance, a REST API provided for the programme. You will
receive a personal key. Send it in the `X-Api-Key` header.

| Endpoint | Use |
|---|---|
| `GET /candles/{symbol}` | End-of-day OHLCV history. Sprint 4 analytics, Sprint 10 signals. |
| `GET /quotes/{symbol}` | One delayed quote. The Trade Executor prices a fill with this. |
| `GET /quotes?symbols=A,B,C` | Batch quotes, up to 25 symbols, counting as one request. |
| `GET /usage` | Your own quota status. Check it before assuming a 429 is somebody else's fault. |
| `GET /health` | No key required. Rules out "is it the API or is it me". |

The base URL is in `.env.example` and Swagger UI is at `/v1/docs` on that
host.

Three things about it shape your design.

The quota is 2000 requests per day per key. That is a real constraint and it
is meant to be. A poller that fetches every symbol every second exhausts a key
before lunch. Poll only the symbols someone holds or is watching, batch up to
25 per call, and cache what you have already asked for.

The key lives in an environment variable and is read from there at runtime. It
is never committed, never hard-coded, and never reaches the browser: the
Angular application does not call Fauxnance, because anything the browser
sends is visible to whoever is using it. If a key does reach a commit, say so
immediately and have it rotated. A quiet fix leaves it in the history.

There is no price stream. Fauxnance answers requests; it does not push. The
real-time behaviour in this platform is something you build in Sprint 7, with
a poller inside the Trade Executor that calls the batch endpoint on an interval
and publishes each quote onto `market-data`. Everything downstream, including
the watchlist alerts in Sprint 10, consumes what that poller produces.

Fauxnance covers NSE and BSE symbols alongside US equities, FX and crypto, so
`INFY.NS`, `RELIANCE.NS` and `TATASTEEL.BO` all price. Trade instruments you
recognise. A dashboard is easier to sanity-check when you already know roughly
what the numbers should look like.

## Working as a team

You are building one system together, not four assignments in one repository.

Work from the board. Every deliverable is broken into stories before the work
starts, and a story is only done when it is merged, tested and demonstrable,
not when it runs on the author's machine.

Branch per story, pull request into the team's main branch, reviewed by
someone who did not write it. Keep the branch short-lived. A branch that lives
a week produces a merge nobody can review properly.

Rotate the work. Every member should be able to walk through any component in
the platform, including one they did not write. That is the standard the
showcase and the review conversations are set at, and pairing on the component
you understand least is the cheapest way to reach it.

Write the tests with the code. Sprint 7 asks you to put characterisation tests
around your own Sprint 6 work before extending it, which is considerably
easier if that code was testable when you wrote it.

Keep secrets out of the repository. `.env` is git-ignored and stays that way.
Commit `.env.example` with placeholders when you add a variable, so the next
person knows what to set.

Ask early. An integration assumption that goes unchecked for a sprint costs
the whole team a day in the sprint after it.
