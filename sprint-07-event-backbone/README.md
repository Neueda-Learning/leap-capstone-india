# Sprint 7: the event backbone

Placing an order is one HTTP request. Your service validates it, fills it,
writes it and answers. That works only because nothing real is happening.
Execution against a market takes time, fails part way, and has to survive the
process that requested it being restarted mid-flight. It also has more than one
interested party: the account, the customer, the analytics estate, and any
strategy service. So split the two. The service that accepts the order records
it and publishes it, something else executes it and publishes the result, and
everybody else subscribes.

That answer has a price, and the price is the subject of this sprint. A message
bus that never loses a message will sometimes deliver one twice. Kafka
guarantees at-least-once, deliberately, because the alternative is a broker
that occasionally loses a trade. So the executor will be handed the same order
twice: during a rebalance, after a crash between the database commit and the
offset commit, or when somebody replays a topic to debug something. If handling
that order twice debits an account twice, the customer is out of pocket and
nothing reports it. Nobody finds out until the cash is reconciled against the
order history, which in a real firm happens the following morning.

The deliverable is not a consumer that works. It is a consumer that is correct
when the message arrives twice, and a team that can prove it on demand.

## Four taught days

Monday is Ganesh Chaturthi, so the order of the work matters more than usual.
Create the topics first. It is an hour of work, and until it is done every
other piece of the sprint fails at the same place. Then the change to your
Sprint 6 service, with its characterisation tests committed ahead of it. Then
the executor, which is most of the week and the only part that cannot be
compressed. Inside the executor, write the poller before the fill path: it
needs no database, it is the smaller half, and a `market-data` topic with
something on it is easier to work against than one with nothing. The batch load
is deliberately narrow this sprint and fits alongside the last day.

## What you deliver

| Deliverable | Where |
|---|---|
| The three topics and their dead-letter topics, with the properties the contract fixes | the broker; the command that creates them is named in `design/kafka.md` |
| The written justification of the partition counts and the key choices | `design/kafka.md` |
| Characterisation tests pinning your Sprint 6 order placement, committed first | inside `sprint-06-trade-api/` |
| A change to that service: record the order, publish it, answer `NEW` | `sprint-06-trade-api/` |
| The Trade Executor: consume, price, fill or reject, settle, publish | `executor/` |
| The market-data poller, scheduled inside the executor: batched quotes onto `market-data` | `executor/` |
| One incremental load into `FACT_TRADES` and its dimensions | `etl/` |
| A SonarQube gate passing on the executor and the pipeline | your local SonarQube |

No starter code, no project skeleton and no topic creation script ships.
Deciding how the executor is decomposed, where the fill rule lives inside it
and how the topics come to exist is most of what this sprint assesses.

## The engineering contract

Set up two projects in this folder, and put the topics on the broker. The
internals are yours. Eight things are fixed, because the contract and your
teammates all depend on them.

- The Trade Executor is one Maven project rooted at `executor/`, on Java 21 and
  Maven 3.9 or later, sources under `src/main/java` and tests under
  `src/test/java`, below one base package of your choosing. `mvn clean verify`
  succeeds in it on a machine that has never seen your code.
- Every executor instance joins the consumer group `trade-executor`. The
  contract fixes that name because `orders` is a work queue with exactly one
  logical consumer group, and the broker will tell you which group is reading it.
- The market-data poller is a scheduled component inside that Maven project,
  in Java, in a package of its own. It is not a second service, not a second
  container and not a second language.
- The pipeline is one Python project rooted at `etl/`, on Python 3.12 or later,
  importable from `src/` and installable from its own `pyproject.toml`. It
  declares its test dependencies under a `dev` optional dependency group, so
  that `pip install -e 'etl[dev]'` into an empty environment leaves a teammate
  able to run the suite. That empty environment is the state a teammate cloning
  the repository starts from, so install it that way at least once yourself.
- The three topics exist on the broker with the names, partition counts and
  retention `contracts/kafka-topics.md` fixes, along with the three
  `<topic>.DLT` dead-letter topics whose shape is your decision. One command
  creates all six against an empty broker, and `design/kafka.md` names it.
- The executor joins your local orchestration, as the Trade REST API did
  in Sprint 6. It needs `KAFKA_BOOTSTRAP_SERVERS` pointing at `kafka:29092`,
  `FAUXNANCE_API_KEY` and `POLL_INTERVAL_SECONDS` from `.env`, the database
  variables, and a `depends_on` for Postgres on its health condition.
- The Fauxnance key is read from the environment at runtime, and appears in no
  properties file, no YAML file and no Java constant.
- The three columns the executor writes and your Sprint 3 schema may not have
  yet, the price a fill happened at, when it happened and why an order was
  rejected, arrive as a migration in the same folder and style as your Sprint 3
  migrations. The analytical model needs the executed price too.

```bash
# start your stack, including the broker, with no topics on it

# then whatever you wrote that creates them

cd sprint-07-event-backbone/executor && mvn clean verify

cd .. && python3 -m venv .venv
.venv/bin/python -m pip install -e 'etl[dev]'
.venv/bin/python -m pytest etl
```

## The three topics

`contracts/kafka-topics.md` is binding. It fixes the names, the keys, the
partition counts, the envelope and the payloads, because Sprint 10 extensions
consume these topics.

| Topic | Carries | Key | Partitions | Retention |
|---|---|---|---|---|
| `orders` | Accepted orders awaiting execution. A work queue with exactly one consumer group | `accountId` as a string | 3 | 7 days |
| `trade-events` | Lifecycle outcomes: filled, rejected, cancelled. The platform's event log | `accountId` as a string | 3 | 30 days |
| `market-data` | Quotes polled from the Fauxnance API | `symbol` | 6 | 1 day |

Two of those columns are decisions rather than settings, and you are asked
about both at the review.

**The key decides the partition, and the partition decides the ordering.**
Kafka orders messages within a partition and promises nothing across
partitions. `orders` and `trade-events` are keyed by account because the
ordering that matters is per account: two orders on one account have to be
executed in the order they were accepted, or a sell is processed before the buy
that made it possible. Keying by order identifier puts every message on its own
partition and throws the guarantee away. **Partitions can be increased and
never decreased**, and increasing them rehashes the keys, so an account's
history splits from that point onwards. Three on `orders` lets three executor
instances share the work and shows that a consumer group cannot usefully exceed
the partition count.

Serialisation is JSON, and every message carries the same five-field envelope
on all three topics, so one deserialiser and one dead-letter handler cover the
platform. Consumers ignore fields they do not recognise: one that fails on an
unknown field turns an additive change into an outage.

### Creating them

The broker your team stood up against `infra/README.md` starts empty. Nothing
creates a topic for you. The topics, the partition counts and keys with the
reasoning behind them, and the producer and consumer configuration in every
service that touches them are all the deliverable.

Four things have to be true, and how you get there is your decision.

- The three topics exist with the contracted names, partition counts,
  replication factor and retention, and the three `<topic>.DLT` dead-letter
  topics exist alongside them. Their shape is not fixed by the contract, so
  choose it and be ready to say why.
- One command takes an empty broker to that state, runs without prompting, and
  is named in `design/kafka.md`. Resetting the broker's data volume removes
  every topic on it, and you will do that more than once this week, so a set of
  topics that exists because somebody typed the commands on Tuesday is not a
  deliverable.
- Auto-creation stays off on the broker. An auto-created topic arrives
  with one partition and default retention, silently, on first use. With it
  off, a producer writing to a topic nobody created gets an error, and an error
  is something you can act on.
- `design/kafka.md` records why the partition counts and the keys are what they
  are, what you chose for the dead-letter topics, and what breaks under the
  alternatives you rejected. The contract states the reasoning, so repeating it
  back is not the deliverable. Applying it is: how many executor instances you
  can usefully run, what raising the partition count in Sprint 10 does to
  per-account ordering, and which of your consumers would notice.

What is assessed is what the broker holds and why it is shaped that way.
Whether the command is a script, a Makefile target or something else is your
decision, and how the topics came to exist is read at the review. Confirm the
result with `kafka-topics.sh --describe` rather than assuming it: one partition
where the contract says six is the signature of a topic a producer created before
anybody configured it.

## The change to your Sprint 6 service

Small, contained, and in your own code. The order is recorded and not filled:
`POST /api/v1/orders` writes the order at `NEW` and answers `NEW`, because
there is no price in that request and pricing is the executor's job.

After the transaction commits, publish an `ORDER_PLACED` message to `orders`,
keyed by the account. After, not inside. Publishing inside the transaction
risks an event for an order that then rolled back, and nothing can undo that.
Publishing after risks an order that committed and was never published, and
that is recoverable by replaying from the order table. Choose the recoverable
failure.

Nothing else changes. The validation, the layering, the error catalogue, the
optimistic lock and the token verification all stay as they are. What the
service does acquire is a Kafka producer, which means producer configuration:
`acks=all`, `enable.idempotence=true`, a high retry count, and no more than
five requests in flight per connection. An idempotent producer removes the
duplicates a producer retry causes, not the duplicates an application retry
causes, which is why the executor still has work to do.

## Characterisation tests, before you touch that service

The service you are about to change is the one that takes customer orders, and
you wrote it a week ago under time pressure. Some of what it does now is
deliberate and some of it is accident, and nobody can reliably say which is
which from memory.

A characterisation test does not assert what the code should do. It records
what it does now, including the parts you disagree with, so that a change which
alters behaviour by accident fails loudly instead of quietly. You cannot write
one afterwards, because a test written against changed code records the
behaviour of the changed code, which is the one thing it cannot then be used to
check.

Pin the order placement path, because that is the path this sprint moves, and
start where the behaviour is observable at the edge of the service. What comes
back for an order the account can afford, field by field, including the status.
Which error code and which HTTP status come back for a reused idempotency key,
an unaffordable buy, an unknown symbol, an account that is not `ACTIVE`. What
is written to the order row, the cash and the position when an order is
accepted. Three tests is the floor and it is a floor rather than a target. Write
them against your own service in `sprint-06-trade-api` and keep them in one
package of their own, so that the history reads clearly and the package is easy
to point at in the review.

Then make the change. Returning `NEW` instead of a terminal status is a
behaviour you are altering deliberately, so change that test in the same commit
as the change and say so in the message. That is a different act from the tests
silently going green again.

### The rule on ordering, exactly

The first commit that adds a file to that package has to be a proper ancestor of
the first commit, after this sprint folder arrived in the repository, that
changes anything under `sprint-06-trade-api/src/main/java`.

Tests and a change to the service in the same commit do not satisfy it. Neither
does a history where the service was changed first and pinned afterwards. Your
instructor reads `git log` for those two commits, so make them easy to find.
Commit in small pieces: a history of one commit per week cannot show this and
cannot show anything else either.

## The Trade Executor

This is the centre of the sprint. There is no broker simulator in this platform
and there will not be one. You build the execution venue, and it is the only
component that decides whether an order fills. What it does with one order:

1. Consumes an `ORDER_PLACED` message from `orders`, in the consumer group
   `trade-executor`.
2. Loads the order from Postgres. A status other than `NEW` means a previous
   delivery already settled it.
3. Checks the instrument is still tradable, then fetches a quote from
   `GET /quotes/{symbol}`.
4. Applies the fill rule to the quote and the order's limit price.
5. Settles in one transaction: the order's status, the account's cash, and the
   position.
6. Publishes `ORDER_FILLED` or `ORDER_REJECTED` to `trade-events`, keyed by the
   account.
7. Acknowledges the offset.

Steps 5, 6 and 7 are in that order for a reason. Publishing before the commit
risks an event for a transaction that rolled back. Acknowledging before
publishing risks an order that settled in Postgres and told nobody.

### The fill rule

The rule is a design decision, constrained by the business rules you
implemented in Sprint 5. The default, and the one to start from:

> Fill the whole order at the current quoted price when a BUY's limit price is
> at or above the quote, or a SELL's limit price is at or below it. Reject
> otherwise.

Partial fills are out of scope, because the order status enumeration has no
state to represent one, and there is no working state between `NEW` and a
terminal status, so an unmarketable order is rejected rather than rested. Four
details decide whether the rule survives contact with real prices, and each is
yours to settle and defend.

| Question | Why it matters |
|---|---|
| What price is stored | The quote carries more decimal places than the column holds. Round before the comparison, or an order can fill at a price that failed its own check |
| Which rules are re-checked here | Rules 6 and 7 were checked at acceptance against a limit price and an older balance. Both have moved while the order sat on the topic |
| What a suspended account does | An account suspended after the order was accepted should not trade, including on orders accepted before the suspension |
| What happens when there is no price | Fauxnance can be down or out of quota. Leaving the order at `NEW` for ever is worse than rejecting it: the customer sees an order that never resolves |

Write the rule as a function of an order and a quote, returning a decision. It
touches no database and no socket, which is the only reason its interesting
cases will actually get tested.

### One transaction, three writes

The status change, the cash movement and the position write are one
transaction. If any of the three fails, none of them happened. An order marked
filled beside cash that did not move leaves the audit trail disagreeing with
the balance, and nothing reconciles the two for you. Two guards sit inside that
transaction and they answer different questions.

The **guarded state transition** answers "has this order already been
executed". It is the first write in the transaction, not a read before it:

```sql
UPDATE orders SET status = ?, executed_price = ?, executed_on = ?
 WHERE id = ? AND status = 'NEW'
```

Zero rows affected means another delivery got there first, and the transaction
returns having changed nothing and published nothing. A read, then a decision,
then a write can be run twice by two deliveries; a write conditioned on the
state it expects cannot, because the database serialises the two updates.

The **optimistic lock** answers "has anybody else moved this account's cash".
It is the mechanism you built in Sprint 6, on the same version column, and it
is needed here because the Trade REST API is still writing to the account row
and the Sprint 10 portfolio service will be. Zero rows affected is not a
failure: re-read and try again, up to a bounded number of attempts, and treat
only an exhausted budget as an error.

### The demonstration you have to be able to give

The acceptance criterion is that replaying a duplicate message does not
double-debit an account, and that the team can demonstrate it, on demand, at
any point in the review. Read one message off `orders` and produce it back:

```bash
kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic orders \
  --from-beginning --max-messages 1 \
  --property print.key=true --property key.separator=$'\t' > order.txt

kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic orders \
  --property parse.key=true --property key.separator=$'\t' < order.txt
```

Those are the broker's own tools. Run them however your stack exposes them,
from the host or from inside the broker container.

Then show four things: the balance before, the balance after, the log line
where the executor recognised the duplicate and did nothing, and that no second
message appeared on `trade-events`, because a consumer that believes the order
happened twice is the same bug one service further downstream.

### Failure handling

Two classes of failure, handled differently, and telling them apart is the
assessed part.

| Class | Examples | Handling |
|---|---|---|
| Will never succeed | Malformed JSON, a missing `orderId`, an order identifier that is not in Postgres, an unexpected `eventType` | Dead-letter it on the first attempt |
| Will succeed later | The broker briefly unreachable, a lost database connection, an exhausted optimistic-lock budget | Retry with a backoff that grows, dead-letter once the budget is spent |

Do not retry a poison message indefinitely: one bad message blocking a
partition stops every account keyed to that partition. A Fauxnance outage
belongs in neither row. It is retried inside the quote client, and if the
budget is spent the order is rejected with a reason that says so. A price feed
being down is a business outcome, not a message-processing failure, and
dead-lettering the order would leave it at `NEW` for ever.

## The market-data poller

The curriculum promises a real-time price stream. Fauxnance does not have one:
it serves end-of-day candles and delayed quotes over HTTP, with no WebSocket
and no server-sent events. The poller manufactures the stream, and its
existence is the reason the Sprint 10 extensions that read prices have anything
to consume. It calls `GET /quotes?symbols=A,B,C` on an interval and publishes
one message per symbol to `market-data`. One per symbol, never one per batch:
batching the HTTP call is a quota optimisation and it is correct, but batching
the Kafka message puts several symbols behind one key and destroys the
per-symbol ordering the contract promises.

It runs inside the Trade Executor, as a scheduled component in Java, in a
package of its own. The reason is the key. The executor already calls Fauxnance
to price every fill, and a separate poller means a second process holding the
same credential, spending the same 2000 requests with no idea what the other
one has spent, and an argument about which of the two owns the retry policy.
One component calls Fauxnance, so one component holds the key and one component
divides the budget.

The placement decides nothing else, and that is the part teams get wrong. The
poller is not on the order path. It does not start a poll because an order
arrived, and the consumer does not wait for a poll to finish. Sharing a process
is not sharing a lifecycle either: a scheduled method that throws is not
necessarily rescheduled, and a poller that quietly stopped inside a running
container is harder to notice than one whose container exited.

The batch endpoint takes at most 25 symbols and costs one request whatever the
symbol count. The quota is 2000 requests per day per key, resetting at 00:00
UTC, and the poller shares it with every fill the executor prices.

| Interval | Requests in 24 hours | How long 2000 requests last |
|---|---|---|
| 15s | 5760 | 8 hours 20 minutes |
| 30s | 2880 | 16 hours 40 minutes |
| 60s | 1440 | A full day, with 560 to spare |
| 120s | 720 | A full day, with 1280 to spare |

Three conclusions follow, and the arithmetic is the assessed part rather than
the code. Batch, or lose the day before lunch: eight symbols fetched one at a
time every 30 seconds is 23040 requests and the key is gone in two hours, where
the same data batched is 2880. Nothing at 30 seconds survives being left
running overnight, so stop the executor at the end of the session or run at 60.
And the budget is shared inside one process now, which makes it easier to get
right and no less important: a poller that spends the whole allowance leaves
the fill path with nothing, and the first symptom is orders rejected because no
price could be obtained. Poll only the symbols you hold or watch, give the two
callers one place that counts what has been spent, enforce the interval floor
in the code rather than documenting one and hoping, and check `GET /usage`
before assuming the API is broken. The key is read from `FAUXNANCE_API_KEY` and
appears nowhere in the repository.

## The batch load

`contracts/analytics-schema.sql` is the model: a star with `FACT_TRADES` at the
centre and three dimensions around it. The grain is one order, in whatever
status it reached. Rejected and cancelled orders are loaded rather than
filtered out, because fill rate is one of the analytics the model has to answer
and it cannot be computed from fills alone.

The scope this sprint is one incremental load into `FACT_TRADES` and its three
dimensions, and nothing else: no scheduler, no orchestration, no history
rebuild and no reconciliation job. Four properties are assessed.

**Load order.** Dimensions before facts, or a fact row references a key that
does not exist yet. `dim_date` first, covering the whole range, then
`dim_instrument`, then `dim_account`, then `fact_trades`.

**Incremental, not full.** A watermark on the order's creation timestamp, so
that a second run reads what is new rather than the whole table.

**Idempotent.** Re-running yesterday's load must not double-count. Merge on the
natural key rather than inserting: `source_order_id` is unique per order, and
the unique constraint on it in the contract makes that enforceable in the store
as well as in the pipeline. This is the property the executor needs, arrived at
from the other direction.

**Dead-lettered, not dropped.** Every check named in the contract's load and
data quality section runs before a row reaches the fact table: referential
integrity into all three dimensions, positive quantity and price, a valid side
and status, and a `trade_value` recomputed rather than trusted. A row that
fails goes somewhere with the reason it failed and the batch it came from.
Dropping it silently and dead-lettering it produce the same fact table, and
only one of them can be investigated on Monday morning. Do not insert a
placeholder dimension row to make an unresolved key pass: that hides the fault,
which is almost always that the dimension load was skipped.

The store is DuckDB, as it was in Sprint 4: one file on disk, no server, no
account to provision. `contracts/analytics-schema.sql` is plain ANSI SQL and runs
on it unchanged.

## SonarQube

The gate has to pass on the executor and on the pipeline. Run it locally
rather than reading about it. Give the container a name that is yours: several
of these run on one machine during the sprint, and a second
`docker run --name sonarqube` fails against the first team's container rather
than starting yours. Open `http://localhost:9000`, sign in as `admin` with the
password `admin`, change it when asked, create a project and generate a token.
The token is a credential: export it, never commit it.

```bash
docker run -d --name sonarqube-<yourteam> -p 9000:9000 sonarqube:community

export SONAR_TOKEN=the-token-you-generated

cd executor && mvn -B verify \
  org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.projectKey=trade-executor -Dsonar.token="${SONAR_TOKEN}"

cd ../etl && docker run --rm -v "${PWD}:/usr/src" \
  -e SONAR_HOST_URL=http://host.docker.internal:9000 \
  -e SONAR_TOKEN="${SONAR_TOKEN}" \
  sonarsource/sonar-scanner-cli -Dsonar.projectKey=analytics-pipeline \
  -Dsonar.sources=src -Dsonar.tests=tests
```

On Linux, `host.docker.internal` does not resolve: add `--network host` and use
`http://localhost:9000`. The expectation is the default Sonar way gate,
passing: no new blocker or critical issue, no new security hotspot left
unreviewed, and duplication and coverage on new code inside the thresholds.
Passing by marking findings as "won't fix" is visible in the dashboard and is
not passing. Nothing runs SonarQube for you, so the gate is checked at the
review, on your screen, on the project you scanned.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. The three topics and their dead-letter topics exist, created by the team,
   with the contracted names, keys, partition counts and retention, and the
   partition and key choices are justified in writing.
2. The Trade REST API publishes to `orders` and returns `NEW`.
3. The Trade Executor consumes, prices against a live Fauxnance quote, applies
   fill or reject rules, updates order, cash and position in one transaction,
   and publishes to `trade-events`.
4. Replaying a duplicate message does not double-debit an account, and the team
   can demonstrate that.
5. The poller runs on a schedule inside the executor, batches up to 25 symbols
   per call and stays inside the daily quota.
6. One incremental batch load into `FACT_TRADES` and its dimensions, with
   dead-letter handling for bad rows.
7. SonarQube gate passing on the pipeline and the executor.
8. Characterisation tests written around your Sprint 6 service before it is
   changed.

## Evaluation

This sprint contributes 10 marks to the 100-mark Capstone assessment. The topic
and analytics contracts are inputs. Marks are awarded for the services,
integration and evidence the team produces.

| Criterion | Marks |
|---|---:|
| Topic creation, keys, partitions and event contracts | 2 |
| Trade REST API producer and Trade Executor integration | 2 |
| Incremental, idempotent analytics load with bad-row handling | 2 |
| Duplicate handling, retries, dead-letter paths and transaction boundaries | 2 |
| Tests, characterisation history, SonarQube gate and live event flow | 2 |
| **Sprint total** | **10** |

## The review

Your instructor assesses this sprint by reading the code against the criteria
above and by watching the platform run. A green suite proves less here than
anywhere else in the programme. A duplicate that moved no money once says
nothing about whether the mechanism holds under load, and a row that was
dead-lettered says nothing about whether the reason recorded with it is usable
on Monday morning.

Read or demonstrated, never counted: the partition counts and the key choices,
the fill rule at its boundaries, whether the transaction encloses the three
writes and nothing more, whether the retry and dead-letter split really
distinguishes a poison message from a transient failure, the quota arithmetic
and the cap of 25 symbols per call, the SonarQube gate, and whether the
characterisation tests pin behaviour worth pinning.

Bring to the review: the running stack, the topics described from the broker
with `design/kafka.md` beside them, one order traced from the HTTP request
through the topic to the committed rows and the published event, the duplicate
replay performed live, a quote arriving on `market-data` inside one polling
interval with several distinct symbols in the cycle, a bad row landing in the
dead-letter path rather than in `FACT_TRADES`, a second load over the same data
that adds nothing, your fill rule and the reasoning behind it, the quota
arithmetic for your configuration, the SonarQube dashboard, and the `git log`
showing the tests arriving before the change.
