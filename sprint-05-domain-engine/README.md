# Sprint 5: the trading domain engine

An order is refused for a reason. The account does not exist. It is suspended.
The instrument stopped trading last month. The cash is not there. The customer
already sent this order and it was accepted the first time. Those reasons are the
business, and everything around them is transport. Transport changes three times
in the next five weeks: Sprint 6 wraps these rules in a Spring Boot controller
inside one HTTP request, Sprint 7 has the Trade Executor settle the same order in
another process against a price that did not exist when it was placed, and
Sprint 10 grows extension routes on that same service reading the same accounts.
Rules written in a controller get reimplemented by whatever needs them next, the
copies drift, and the first drift accepts an order the executor then refuses. So
they live here, in a package of plain Java that no caller can bend, with nothing
on the classpath that has to be started before a test runs. Sprint 6 takes this
package into the Trade REST API as source and wraps a transport around it, and
the transport is the part that is allowed to change. Every rule below is provable
with plain objects in milliseconds, which is why the criteria can insist the
tests came first.

## What you deliver

| Deliverable | Where it lives |
|---|---|
| Four entities: `Account`, `Instrument`, `Order`, `Position` | `src/main/java/`, under your base package |
| Three enumerations: `AccountStatus`, `OrderSide`, `OrderStatus` | as above |
| The order request DTO, with validation | as above |
| An exception hierarchy covering the six specified cases | as above |
| Business rules 1 to 8, in the domain | as above |
| JUnit 5 tests, written first | `src/test/java/` |
| A UML class diagram and an order placement sequence diagram | `design/` |

There are no stubs. Designing these types from the requirements is the
assessment.

## The engineering contract

No project skeleton ships with this sprint. Set one up. Five things about it are
fixed, because your teammates and Sprint 6 both depend on them:

- One Maven project rooted in this folder, on Maven 3.9 or later.
  `mvn clean test-compile` succeeds in it on a machine that has never seen your
  code.
- Java 21, JUnit 5 and the surefire plugin, so that `mvn test` leaves reports in
  `target/surefire-reports/`.
- Sources under `src/main/java`, tests under `src/test/java`, all of it below one
  base package of your choosing. Sprint 6 absorbs that package under the name it
  has here, so choose a name that says domain rather than transport.
- `jakarta.validation-api` as the only non-test dependency. Bean Validation
  annotations are declarations rather than behaviour, which is why they are the
  one framework the architecture allows inside the domain. An implementation such
  as hibernate-validator is permitted in test scope if you want a validator to
  run in your tests.
- Nothing else. Spring, a servlet API, a JDBC driver, MyBatis and HikariCP fail
  criterion 5 the moment one of them reaches the dependency tree, including
  transitively.

The coordinates are yours and nothing outside this folder reads them. There is
no artefact to publish and no `mvn install` step: in Sprint 6 the package itself
moves into the Trade REST API as source, compiled by that service's own build,
which is what lets a fresh checkout build the API with one command. Name the
package with that move in mind, because it keeps the name it has here.

Ban the forbidden dependencies in your own build too, with the enforcer plugin's
`bannedDependencies` rule: a failing build tells you the moment somebody adds
one, and tells them why. After the move there is no separate build to enforce it,
so the same constraint becomes a rule about what may appear inside a package,
assessed in Sprint 6 against the package inside the service. That is the form the
constraint takes in most real codebases anyway.

```bash
cd sprint-05-domain-engine
mvn test
```

Nothing in this sprint needs Docker. The suite starts no container, opens no
socket and reads no environment variable, and it should stay that way.

## The domain model

Sprint 3 gave you this domain as tables. A table stores state; an object owns the
behaviour that changes it. A balance is never changed by anything except the
account that holds it.

| Entity | What it owns |
|---|---|
| `Account` | A cash balance in one currency, the holder's name, the trading status, and the only operations that move that balance. It answers whether it can afford an amount |
| `Instrument` | Reference data: a symbol in the Fauxnance scheme, a display name, an asset class, a currency of quotation. It answers whether it may be traded, which is rule 3 |
| `Order` | An instruction to buy or sell a quantity of one instrument at a stated price, against one account, in exactly one status |
| `Position` | The net holding of one instrument in one account, with its average cost, moved by a buy or a sell |

Five properties of that model are assessed and none is visible in the table.

- A debit that would leave the balance negative is refused before anything is
  subtracted, not attempted and then inspected for a negative result. Money is
  decimal at two places and never a `double`: binary floating point cannot
  represent 0.10 exactly, and a balance out by a hundredth of a penny after a
  thousand trades is a defect an auditor finds before you do.
- An account carries two identifiers and they are not interchangeable. The
  numeric key is what `accountId` means in `contracts/trade-api.yaml`, in the JWT
  claim and on every order; the string reference is what a support call quotes.
- The account also carries the version Sprint 6 uses for optimistic locking. The
  domain does not take the lock, it reports the version it was loaded at.
- Delisting is a flag, never a deleted row, because the order history references
  the symbol and that history is the audit trail. An order is recorded when it is
  received, before anyone knows whether it will succeed, and reaches exactly one
  terminal state, with a disallowed transition refused by the order itself rather
  than by its caller. Its limit price is what the customer submitted; its
  executed price is what the Trade Executor achieves against a live quote in
  Sprint 7 and does not exist until the order is filled.
- The average cost rule is asymmetric. A buy recalculates the average across the
  old holding and the new units at the price they were bought at; a sell reduces
  the quantity and leaves the average alone, which is what makes realised profit
  and loss computable at the point of sale. A position never goes negative,
  because short selling is out of scope.

### The three enumerations

These are fixed. They appear in `contracts/trade-api.yaml`, the database stores
the same strings, and the Angular UI generates its types from that file in
Sprint 9, so a renamed or extra literal breaks three places at once.

| Enumeration | Literals, exactly |
|---|---|
| `AccountStatus` | `ACTIVE`, `SUSPENDED`, `CLOSED` |
| `OrderSide` | `BUY`, `SELL` |
| `OrderStatus` | `NEW`, `FILLED`, `REJECTED`, `CANCELLED` |

`ACTIVE` accounts trade. `SUSPENDED` accounts can be read and cannot trade, and
the suspension is reversible. `CLOSED` accounts never trade again and are never
deleted. `NEW` is the working state and the other three are terminal. There is no
partial-fill literal, which is why the Trade Executor fills in full or rejects.
Spell `CANCELLED` with two `L`s. It is the literal teams get wrong most often,
and a misspelling breaks the contract, the database and the generated Angular
types at once.

### The order request DTO

Six fields. The schema is `PlaceOrderRequest` in `contracts/trade-api.yaml` and
it is binding.

| Field | Constraint |
|---|---|
| `accountId` | Required. The numeric account key, at least 1 |
| `symbol` | Required, not blank, at most 20 characters |
| `side` | Required, one of `BUY` or `SELL` |
| `quantity` | Required, whole units, greater than zero |
| `price` | Required, greater than zero, at most two decimal places |
| `idempotencyKey` | Required, between 8 and 100 characters |

These are business constraints rather than transport constraints, which is why
the DTO lives here and not in the Sprint 6 service: a second caller gets them
without reimplementing them. Quantity greater than zero is rule 4 and price
greater than zero is rule 5. Validating by hand rather than by annotation is
allowed. What is assessed is that every constraint is enforced and tested,
including the boundary either side of each limit.

## The exception hierarchy

Six cases, one type each, all extending a single domain base type so that the
Sprint 6 service catches the base in one place and maps it.

| # | Case | Raised when | Code |
|---|---|---|---|
| 1 | Account not found | No account exists with the key on the request | `ACC-404` |
| 2 | Account not active | The account exists and is `SUSPENDED` or `CLOSED` | `ACC-403` |
| 3 | Instrument not found | The symbol is unknown, or it is known and no longer tradable | `INS-404` |
| 4 | Insufficient funds | A buy costs more than the available cash balance | `ORD-400` |
| 5 | Insufficient holdings | A sell is larger than the quantity held | `ORD-409` |
| 6 | Duplicate order | The idempotency key has already been accepted | `ORD-409` |

Three things about the hierarchy are assessed. The base type carries the
catalogue code and not an HTTP status, because Sprint 6 maps that code to a
status in one place and Sprint 7 maps it to a rejection reason on a Kafka event.
One code can mean two things and one case can carry two codes, and neither is an
accident. The message is the catalogue message and nothing else, because it
becomes the response body: anything an investigation needs is a typed field on
the exception, logged on the server, since leaking internal detail in an error
body is OWASP A05.

Rules 4 and 5 then need a decision from you: `VAL-422` is a documented outcome of
order placement and the list of six has no member for a quantity or a price out
of range. Adding a type is a reasonable answer, and so is an argument that
validation alone covers it, provided you can say what happens when the caller is
the Trade Executor replaying an order and never ran a validator. Those six are
what is assessed; any type you add beyond them is your business, provided it
descends from the same base.

## Business rules 1 to 8

The acceptance criteria refer to these rules by number. They are enforced in this
order and the first failure wins.

| # | Rule | Case raised | Code |
|---|---|---|---|
| 1 | The account must exist | Account not found | `ACC-404` |
| 2 | The account must be `ACTIVE` | Account not active | `ACC-403` |
| 3 | The instrument must exist and be tradable | Instrument not found | `INS-404` |
| 4 | Quantity must be greater than zero | see above | `VAL-422` |
| 5 | Price must be greater than zero | see above | `VAL-422` |
| 6 | On a `BUY`, the cash balance must be at least quantity multiplied by price | Insufficient funds | `ORD-400` |
| 7 | On a `SELL`, the held quantity must be at least the order quantity | Insufficient holdings | `ORD-409` |
| 8 | The idempotency key must not already have been used | Duplicate order | `ORD-409` |

Rules 9 and 10 carry no error code and are not countable criteria this sprint,
but leave room for them: cash and position move together or neither moves, and
every order is recorded, including a rejected one, because the order table is the
audit trail. An object graph half mutated when a precondition fails depends on
somebody remembering to roll back a transaction, and that somebody does not exist
yet in Sprint 5.

Three points decide whether the rules are implemented well or merely present.
The order is part of the contract, so a request that breaks two rules receives
the code of the first and a suspended account holding no cash gets `ACC-403`
rather than `ORD-400`: test the ordering itself, not only the eight rules. They
belong to the domain and not to a controller, which is the criterion that fails
most often, because the shortest route to a working Sprint 6 is an `if` in the
controller. Rules 4 and 5 are checked twice on purpose, once as a DTO constraint
and once in the rules, because the domain has to hold for a caller that never
ran a validator.

Rule 8 then needs a design decision from you. In Sprint 6 the authority is the
unique constraint on `orders.idempotency_key` you built in Sprint 3, not a read
followed by a write, because two concurrent requests carrying the same key both
pass a read-then-write check and losing that race duplicates a trade. The rule
still has to be expressible and testable here without a database, so design the
seam that lets it be. You will be asked about it.

## Tests

The tests come first, and it is assessed from the commit history rather than from
the final state of the repository. An assessor opens `git log` and expects the
test for a rule in an earlier commit than the code that satisfies it. A history
in which a rule and its test first appear together does not meet the criterion,
and one commit at the end of the week holding the whole module fails it outright.

Three test classes are named in the criteria and all three must be green. Name
them exactly this; the packages are yours. The criteria set a floor rather than a
target, so write the other classes the entities need.

| Class | Covers |
|---|---|
| `AccountTest` | Status, debit, credit, affordability, the refusal to go negative, and money that does not drift over many operations |
| `OrderLogicTest` | Business rules 1 to 8, each one firing and each one not firing, plus the evaluation order itself |
| `PlaceOrderRequestValidationTest` | Every constraint on the DTO, including the boundary either side of each limit |

At least 24 tests across those three, which is arithmetic rather than ambition:
eight rules firing and eight not firing is 16 in `OrderLogicTest` alone, and six
DTO fields is six more.

## The UML diagrams

Two diagrams, committed to `design/`. **A class diagram of the domain**: every
type you wrote, its fields, the operations that carry behaviour, the
enumerations, the exception hierarchy, and the relationships with their
cardinality. It is a picture of your design, not of the model this brief
describes. **A sequence diagram of order placement**: one order arriving at the
domain and the eight rules being evaluated against it, in order, showing what is
consulted at each step and where each failure leaves the flow. Draw the refusal
paths, because a diagram showing an order sail through eight boxes and come out
accepted has not documented the interesting half of this module.

Mermaid in `design/class-diagram.md` and `design/sequence-diagram.md`, using
`classDiagram` and `sequenceDiagram` blocks, is the better of the two acceptable
formats, because it diffs in review and cannot drift out of the repository. An
exported `.png` or `.svg` is also accepted; commit the export, not a link to a
cloud document your instructor cannot open. The review walks both diagrams
against the code in both directions, so update them when the code moves, and
every team member walks the whole diagram, including the parts they did not
write.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. `Account`, `Instrument`, `Order` and `Position` match the domain model.
2. `AccountStatus`, `OrderSide` and `OrderStatus` match exactly.
3. The exception hierarchy covers all six specified cases.
4. Business rules 1 to 8 are implemented in the domain, not in a controller.
5. No database, HTTP or Spring dependency in the domain package.
6. Tests are written before implementation, evidenced in commit history.
7. `AccountTest`, `OrderLogicTest` and `PlaceOrderRequestValidationTest` are all
   green.
8. UML class and sequence diagrams are committed and match the code.

## Evaluation

This sprint contributes 18 marks to the 100-mark Capstone assessment. The
requirements in this brief and the contracts are inputs. Marks are awarded for
the Java design, implementation and evidence the team produces.

| Criterion | Marks |
|---|---:|
| UML and domain-boundary design | 3 |
| Entities, enumerations, DTO validation and exception hierarchy | 4 |
| Business rules, state transitions and idempotency design | 5 |
| SOLID structure and framework-independent domain logic | 2 |
| Meaningful JUnit coverage and test-first commit history | 4 |
| **Sprint total** | **18** |

## The review

Assessed by your instructor, reading the code and the history against the
criteria above:

- whether each of the eight rules is correct, in the right order, and in the
  domain rather than in a caller
- whether the commit history shows tests arriving before implementation
- whether the two diagrams match the code they claim to describe
- whether your seam for rule 8 survives two concurrent requests
- whether every member of the team can walk the model unaided

A green suite is the floor. A test that asserts nothing is still green, and a
package that compiles proves only that eight rules could have been implemented.

Bring to the review: the diagrams, the `git log`, one rule traced from its first
failing test to the code that satisfies it, `mvn clean test` running from a fresh
clone, `mvn dependency:tree` showing no Spring, servlet, JDBC, MyBatis or
connection-pool artefact, each of the three enumerations holding exactly the
contractual literals, and your answer to why the evaluation order is what it is.
