# Sprint 6: the Trade REST API

Everything the platform has built so far is unreachable. The schema answers
psql. The rules answer a JUnit test. Neither answers a customer, and no other
service can reach either of them. This sprint is the front door: one HTTP
service that accepts an order, proves the caller is who they claim to be,
applies the rules you wrote in Sprint 5, writes the result to the schema you
designed in Sprint 3, and answers in the shape the Angular application generates
a client from.

It decides nothing about whether a trade is allowed and it prices nothing. It
owns transport and persistence: JSON into a domain call, a domain exception into
a documented error code, one transaction around the work that has to succeed or
fail together. That thinness is not tidiness. In Sprint 7 whoever writes the
Trade Executor reads these rules again to settle the same order in another
process, so every rule that leaks into a controller this week gets written again
there, and the first drift between the copies is a customer whose order this
service accepted and the executor then refused.

This service is also the host. The Sprint 5 domain package moves in here this
week, as source, and it is the only place in the platform that holds it. In
Sprint 10 your extensions arrive the same way: further packages inside this
service, with their own routes on the same port and their own Kafka consumers.
The layering you set up this week is the layering they are added to, and the
token verification you write once, for every route under `/api/v1/`, is what
will protect routes nobody has designed yet.

## What you deliver

| Deliverable | Where |
|---|---|
| The Sprint 5 domain package, moved in as source | `src/main/java/`, under its own package |
| Six endpoints implementing `contracts/trade-api.yaml` | `src/main/java/` |
| A layered controller, service and mapper structure | one package per layer |
| MyBatis mappers with parameterised statements | XML or interface annotations |
| One `@ControllerAdvice` producing the error envelope | as above |
| JWT verification on every `/api/v1/**` route | as above |
| Tests, unit and slice, that run without a container | `src/test/java/` |
| A multi-stage `Dockerfile` | this folder |
| Your service added to your local orchestration | repository root |

No starter code and no stubs ship. Deciding what belongs in which layer is most
of what this sprint assesses.

## The engineering contract

No project skeleton ships either. Set one up. Six things about it are fixed,
because the later sprints and your teammates all depend on them:

- One Maven project rooted in this folder, on Maven 3.9 or later and Java 21.
  `mvn clean verify` succeeds in it on a machine that has never seen your code.
- Spring Boot 3.5.x with the web and validation starters, MyBatis through the
  Spring Boot starter, and the Postgres JDBC driver.
- The Sprint 5 domain as source in this project rather than as a dependency of
  it. Copy those sources into `src/main/java` here, keeping the package name,
  and copy the tests across so that they keep running. Copy rather than move:
  Sprint 5 is assessed in its own folder, and from this week the copy in this
  service is the one the platform runs. There is no artefact and no
  `mvn install`, which is what lets a fresh checkout build this service with one
  command.
- Sources under `src/main/java`, tests under `src/test/java`, below one base
  package of your choosing, with controllers in one sub-package and mappers in
  another. The layering criterion is read against that split, so make it obvious
  from the package names which is which.
- A multi-stage `Dockerfile` of your own design, in this folder.
- The service joined to the local orchestration your team built against
  `infra/README.md`, so that one command still starts the platform.

Three boundaries inside that, stated plainly. Controller sources import nothing
from your mapper package, `java.sql`, `javax.sql`, MyBatis, Spring JDBC or a
persistence API, and hold no SQL string. No class in your domain package
references a servlet, Spring or MyBatis type: the Sprint 5 build refused those
because none of them were on that classpath, and here they resolve, so the
constraint is now a rule about what may appear inside a package and nothing but
the review holds it. `JWT_SECRET` comes from the environment at runtime and
appears in no properties file, no YAML file and no Java constant, as does every
other value that differs between a laptop and a container.

```bash
cd sprint-06-trade-api
mvn clean verify
```

## The contract is the specification

`contracts/trade-api.yaml` is not documentation of something you build. It is
the thing you build, and you neither author it nor change it. It exists so that
the Angular application in Sprint 9 can generate a typed client without reading
your Java. Six operations, with paths, verbs and status codes fixed.

Two parts of it are behaviour rather than decoration, and both are assessed.

**The error envelope.** Every failure leaves as
`{"errorCode": "...", "message": "..."}` and nothing else: no whitelabel page,
no stack trace, no bare status with an empty body. The Angular application has
one error handler because there is one envelope.

**Every code in the catalogue.** Clients branch on `errorCode`, never on the
status alone, because 404 and 409 each carry more than one code.

| Code | HTTP | Raised when |
|---|---|---|
| `ACC-404` | 404 | No account exists with that key |
| `ACC-403` | 403 | The account is not `ACTIVE`, or the token does not reach it |
| `INS-404` | 404 | The instrument is unknown or no longer tradable |
| `ORD-400` | 400 | A buy costs more than the available cash |
| `ORD-409` | 409 | Insufficient holdings, a reused idempotency key, or an order that cannot be cancelled |
| `VAL-422` | 422 | The request failed field validation |
| `AUTH-401` | 401 | Missing, malformed, expired or wrongly signed token |

`message` is for a human reading a screen: no class name, no SQL fragment, no
account key, no internal identifier. What an investigation needs is logged on
the server. Response bodies are the contract schemas, field for field, and
`AccountResponse.accountId` is the one place in the platform where that name
means the string business reference rather than the numeric key.

## Layering, stated concretely

Three layers, and each one is allowed to speak exactly one language.

| Layer | Speaks | Must not |
|---|---|---|
| Controller | HTTP, DTOs, status codes, validation annotations | Contain SQL, open a transaction, or hold a business rule |
| Service | The domain package, mappers, one transaction | Take a servlet type, a request object or a status code as a parameter |
| Mapper | SQL, parameterised, and result mapping | Decide anything, or reach back into HTTP |

Two violations fail review on sight.

**SQL in a controller.** A query in the class that handles the request cannot be
tested without a web layer, cannot be reused by the service needing the same
rows next sprint, and puts your schema and your JSON in one file.

**An HTTP type in the domain.** A domain exception carrying an HTTP status, an
entity annotated for a web framework, or a rule taking a request DTO has bound
the rules to one caller. Whoever writes the Trade Executor in Sprint 7 has no
HTTP request and needs the same rules to mean the same thing, and the Sprint 10
extension routes read the same domain from a second set of controllers in this
service.

## MyBatis, and why interpolation is a security finding

Persistence is MyBatis, in XML under `src/main/resources/mapper/` or in
annotations on the mapper interface. Either style is acceptable.

Bind every value arriving from outside with `#{}`, which becomes a JDBC bind
parameter: the driver sends the statement and the value separately, so nothing
the caller sends changes what the statement does. `${}` substitutes the value in
first. A symbol of `AAPL' OR '1'='1` written with `${}` becomes part of the
statement, and the positions that come back are whichever account the attacker
asked for. That is OWASP A03, injection, and the outside values here include an
account key, a symbol, a status filter and two timestamps.

Any `${}` in a mapper fails criterion 3. One use is legitimate, a column name or
sort direction that cannot be a bind parameter, and only when the value is
checked against a fixed list of permitted names first. Put a comment above the
statement naming what does that checking, and bring the list of every such
statement to the review. Each one is a question you will be asked.

## Optimistic locking on the account version column

Sprint 3 put a version column on the account row and Sprint 5 had the domain
report the version it was loaded at. This is the sprint where it does something.

Account 3 holds 25,000, and two buys costing 20,000 each arrive at the same
moment. Without a lock, both read the row, both see 25,000, and both write 5,000
back. Both orders are recorded and filled, 40,000 of stock has been bought, and
the account holds 5,000 instead of being 15,000 overdrawn. One update was lost,
with no error and no symptom until somebody reconciles the cash against the
order history, which in a real firm happens the next morning.

Optimistic locking makes the version part of the write rather than a check
before it. The update names the version the row held when it was read, and
increments it. The database serialises the two writes: the first affects one
row, the second affects none. Zero rows affected is not success, so the service
that gets it refuses the order and the caller sees `ORD-409`. Read the version
with the row, and return the affected row count, because a mapper returning
`void` has thrown away the only evidence that anything happened. The same
applies behind `DELETE /api/v1/orders/{id}`: make the transition conditional on
the state you expect, in one statement.

## Authentication during Sprint 6

No token issuer is supplied. Build tests that mint signed tokens with a
team-owned test fixture and verify them through the same production code path.
The fixture must follow `contracts/auth-api.yaml` and must not be deployed as a
service. Sprint 8 adds the real auth service.

Verification means checking the signature, the expiry and the algorithm the
token asks for, in that order, before reading a claim. A verifier that decodes
the payload first has already trusted whatever the client sent. A missing
header, a wrong scheme, an expired token and a forged signature are one answer,
`AUTH-401` with the same body, because a more specific message tells an attacker
which of the four they got wrong. Whether the caller holds a valid token is
answered once, for every route under `/api/v1/`, before any controller runs.
Whether that caller may reach the account is answered where the account key is
known, and the answer is `ACC-403` with the same message a suspended account
gets, so that nobody can enumerate keys.

When Sprint 8 adds the auth service, only configuration should change. If Java
code has to move, this service is coupled to an implementation detail rather
than to the token contract, and that is worth finding now rather than in week 7.

## The Dockerfile and local orchestration

A single-stage build ships the image that built the service: Maven, a full JDK,
the dependency cache and your source. The reason to care is not disk. Every tool
in an image is a tool available to whoever gets into the container. So one stage
carrying Maven and a JDK 21 builds the jar, and a second carrying a Java runtime
and neither of the other two takes it through `COPY --from=`. Order the copies
so that changing a source file does not invalidate the resolved-dependency
layer, run as a user that is not root, expose the service port and answer a
health check. One constraint has gone this year and it is worth knowing it was
there: when the domain was a separate artefact, the image build started with an
empty `~/.m2`, could not reach your laptop's repository, and had to compile two
projects from a context wide enough to hold both folders. The domain is source
in this project, so the context is this folder and the build stage runs one
`mvn package`.

Adding the service to your local orchestration is your change. It needs:

| Needs | Because |
|---|---|
| A `build` block with the context and the Dockerfile path | The image is built from source, not pulled |
| A shared service network | It resolves Postgres by service name |
| A published port for the service port | `curl` from the host reaches it |
| Database host, port, name, user and password from the environment | `localhost` inside a container is the container |
| `JWT_SECRET` passed through from `.env` | Test tokens and the later auth service use the same configured value |
| `depends_on` Postgres, on its health condition | Starting before the database is ready is a crash loop, not a failure |
| A health check | The orchestrator should report the service as healthy, not merely running |

Nothing this sprint needs Kafka.

## Working with Copilot

GitHub Copilot is introduced this sprint. It is quick at the parts of this
service that look the same in every Spring Boot application, and it knows
nothing about your schema, your domain package or the contract unless you open
those files beside the one you are writing. What it produces is assessed exactly
as anything you typed: against the error catalogue, the layering rules and the
parameterisation rule. A generated mapper interpolating a symbol with `${}` is a
finding under your name. Read each suggestion, and be able to say why the line is
there.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. All six endpoints are implemented and match the contract, including the error
   envelope and every code in the catalogue.
2. Layering is enforced: no SQL in a controller, no HTTP type in the domain.
3. MyBatis mappers use parameterised statements throughout.
4. `@ControllerAdvice` maps every domain exception to its documented code and
   status.
5. Order placement is `@Transactional`.
6. Optimistic locking is applied on the account version column.
7. A protected route rejects a missing or invalid token with `AUTH-401`.
8. The service builds and runs from a multi-stage Dockerfile.

## Evaluation

This sprint contributes 18 marks to the 100-mark Capstone assessment. The API
contract is the input. Marks are awarded for the service design, implementation
and evidence the team produces.

| Criterion | Marks |
|---|---:|
| Contract-compliant endpoints, responses and error catalogue | 4 |
| Controller, service, domain and mapper boundaries | 3 |
| MyBatis persistence, transactions and concurrency control | 4 |
| Validation, authentication, authorisation and structured logging | 3 |
| Reproducible multi-stage container build | 1 |
| Unit, slice, integration and contract evidence | 3 |
| **Sprint total** | **18** |

## The review

Your instructor assesses this sprint by reading the code against the criteria
above and by exercising the running service. Structure is the easy half. A mapper
can bind every parameter and still run the wrong statement, and an annotation can
be present with the transaction boundary in the wrong place.

Read rather than searched for:

- whether the transaction encloses the work that has to be atomic, and no more
- whether every domain exception leaves as its documented code, rather than most
- whether the layering holds where a search cannot see it, including a business
  rule written in a service that should have called the domain
- whether the lock is applied to every write to the account row
- whether the image would survive being deployed, including what it runs as

Bring to the review: the running stack, one order traced from the request to the
committed row, all six endpoints answering with
the status and body the contract states, each code in the catalogue produced on
demand in the envelope, a missing token and a tampered token on a protected
route, several concurrent orders against one account with the cash reconciled
against the order history afterwards, your Dockerfile, and your answer to what
happens when two customers spend the same money at the same moment.
