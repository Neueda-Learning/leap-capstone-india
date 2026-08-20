# Sprint 10: extensions

For seven sprints the work was specified for you. A contract said what the Trade REST API
returned, `contracts/kafka-topics.md` said what an envelope looked like, a brief said which
business rules the domain engine enforced, and the acceptance criteria said when you were
finished. That was deliberate. A platform built by four teams to four different designs cannot
be assessed against itself, and the fastest way to teach a convention is to hand it over and
make people build to it.

This week the platform is finished and nobody is handing you a design. Four extensions are
named and their behaviour is fixed by the acceptance criteria, and everything between those two
things is yours: the APIs, the schemas, the order the work is taken in, who does what, and how
you know on Wednesday whether Friday is reachable. The technology is technology you already
have. What is new is that the decisions are yours, and that the way you took them is part of
what is assessed.

That is why this folder is thin. There is no scaffold in here, because there is nothing to
scaffold until you have designed it. What is here is the four briefs and the shape of the two
documents you have to produce.

## The extensions are not new services

All four are built inside the Trade REST API you wrote in Sprint 6. Each one is a package with
its own routes on 8080, its own service layer, its own tables and, where it needs one, its own
Kafka consumer with its own group id. None of them has a Dockerfile, a port, a compose entry or
a second copy of token verification.

The reason is what a week costs. Four containers cost four Dockerfiles, four port allocations,
four compose entries and four JWT verifiers before a single feature exists, and none of that is
the feature. Written as packages in a service that already boots, already verifies tokens and
already holds a database connection, the four start on Monday afternoon. The integration lesson
the separate services were supposed to teach was taught by the five real services and the
broker between them, five sprints running.

Two things get harder rather than easier, and both are assessed. Authorisation, because there
is no service boundary to lean on: every route each module adds decides for itself whether this
caller may reach this resource, inside the same application that holds the order book. And the
boundaries between the four, because a compiler no longer stops one module reaching into
another's tables. Both are now decisions you make and defend rather than properties of the
deployment.

## What changes this week

No new technology is taught. Every tool this sprint needs, you have used: Java and Spring Boot
for the code, Kafka for the events, Postgres for the state, Angular for the screens, JUnit for
the tests.

You run the sprint. Plan it, split it, track it, review each other's pull requests, and hold
whatever ceremonies your team has settled into. Instructors are available all week and will not
be assigning work.

Process is assessed alongside product. A team that ships four working features with no backlog,
no decision log and a security review written on the Thursday evening scores below a team that
ships less and can show how it was decided. The two documents in this folder are not paperwork
attached to the build. They are half of the deliverable.

This is also the last sprint in which the platform is assessed. The cloud week that follows is
assessed on the deployment, so the demonstration of the platform itself happens at the end of
this one, against a running stack.

## Four modules, and why the order is fixed

All four are mandatory. They are not four unrelated features either: three of them form one
chain, and the chain is the reason the build order is not a matter of taste.

| Order | Extension | Brief | Depends on |
|---|---|---|---|
| 1 | Customer preferences | [catalogue/customer-preferences.md](catalogue/customer-preferences.md) | Nothing in this list |
| 2 | Customer notifications | [catalogue/customer-notifications.md](catalogue/customer-notifications.md) | Preferences, for the channel |
| 3 | Watchlists and price alerts | [catalogue/watchlists-price-alerts.md](catalogue/watchlists-price-alerts.md) | Notifications, for delivery |
| 4 | Portfolio and P&L | [catalogue/portfolio-pnl.md](catalogue/portfolio-pnl.md) | Nothing in this list |

Read the chain in one sentence. Preferences owns the customer's alert channel and hands it to
notifications; notifications consumes `trade-events` and delivers on that channel, and is also
the delivery path watchlists uses; watchlists consumes `market-data`, decides that a threshold
has been crossed, and asks notifications to tell the customer.

Each link is a hard dependency rather than a preference. A notification cannot be routed
without a channel, so notifications built before preferences either hardcodes a channel or
waits. An alert has to arrive somewhere, so watchlists built before notifications either writes
to a log, which does not meet the criterion, or waits. Build them in order and each module
finds its dependency already there.

The links are Java interfaces this year rather than HTTP calls, and that changes what a link
costs to get wrong. A published interface with one implementation behind it is a seam another
module can be built against on Tuesday and can be replaced on Thursday. A call straight into
another module's mapper is the same work on Tuesday and cannot be replaced at all.

Portfolio and P&L sits outside the chain. It depends on none of the other three and none of
them depend on it, so it can be built at any point in the week and by anyone. It has its own
external dependencies instead: `contracts/portfolio-api.yaml`, which binds it the way
`trade-api.yaml` bound Sprint 6 and which now names the Trade REST API on 8080 as the server
for its routes, the Fauxnance API for prices, and the platform data it reads. That combination
makes it the one of the four with the least design freedom and the most failure modes, which is
worth knowing when you decide who takes it.

The dependency order is the build order and it is not the assignment order. Four people
starting four modules on Monday morning produces three of them blocked by lunchtime.

## Day one

Three things happen before any code is written, and they happen on the Monday.

**Read all four briefs, as a team.** Every one of you, all four. The chain means a decision
taken inside preferences on Monday becomes notifications' problem on Tuesday and watchlists'
problem on Wednesday, and the people who will hit that need to have read the brief it came
from. All four are written as packages and routes inside the Trade REST API, whatever the brief
calls them.

**Confirm the scope with an instructor.** Bring what you intend to build by Friday, what you
have decided not to build, and the APIs you propose to expose for the three extensions that
have no contract. Bring the shape of the integration between them: the interface notifications
resolves a channel through, and the one watchlists delivers through. Bring the four package
names as well, because they are the boundary. Scope confirmed on day one is an acceptance
criterion, not a courtesy.

**Write the backlog for all four before you write code.** Stories with acceptance criteria, in
whatever tracker your team has been using, covering every one of the four rather than the one
somebody started first. One of those stories is the Sprint 6 service itself: four people are
about to commit into one Maven project, and nothing in this week's criteria forgives breaking
order placement. A backlog assembled on Friday morning from the commits is visible as one, and
it is worth less to you than to anybody marking it. Writing it first is what tells you on
Wednesday whether the scope you agreed is still the scope you are building, which is the week's
real risk with four extensions in it.

## What all four have to do

The features differ. Five properties do not.

**Each one is a module, and the boundary is yours to hold.** One package per extension under
the service's base package, with its own controllers, its own service classes, its own mappers
and its own tables inside it. Nothing outside a module imports anything inside it except the
interface that module publishes. Four packages, not four sets of classes sharing a folder, and
no module reaching into another's tables because the connection happens to be right there.

A compiler enforces none of that now. In four separate services the boundary was a network hop
nobody could cross by accident; here it is a decision made every time somebody writes an
import, which is why it is assessed and why the package names are agreed on day one.

**Every route each module adds enforces its own authorisation.** The Trade REST API verifies
the signature, the expiry and the algorithm on every route under `/api/v1/`, so a route added
under that prefix is authenticated the moment it exists and nobody writes a second verifier.
What is not decided for you is whether this caller may reach this resource. Compare the
`accountId` claim against the account being addressed, on every route, and refuse a mismatch
with `ACC-403`. A route that returns another customer's preferences, notifications, watchlist
or portfolio to a valid token is the finding this sprint's review exists to catch, and this
week there are four sets of routes to leave it out of, all of them in the application that
holds the order book.

Mapping a route out of the verified prefix to make something easier publishes it. If a route
has to be public, it is a decision log entry and a line in the review.

The one place this gets interesting is the work that runs with nobody logged in. The
notification consumer acts on a `trade-events` message, and the alert evaluation acts on a
`market-data` quote. Neither holds a customer's token, and neither needs one, because neither
is serving an HTTP request. What they must not do is reach the customer's data through a route
that assumes a token was checked. Decide where the authorisation boundary sits for a consumer
path, and write the entry.

**Nothing built in Sprint 6 regresses.** The six contract endpoints answer exactly as they did,
the service's tests are still green, and the image still builds and starts. Four people are
adding packages to a service other work depends on: the Angular application calls it, the Trade
Executor reads what it wrote, and the analytics extract reads the same tables. A module that
breaks order placement has cost more than it added.

**Each one runs on live data at the demonstration.** Real quotes from the Fauxnance API, real
messages from the topics your poller and executor are producing, real rows from your Postgres.
Not fixtures, not a seeded response, not a recorded payload replayed from a file. Fixtures
belong in the test suite, and a demonstration that runs on them is demonstrating the fixture.

**One OWASP security review covers all four.** One document, not four concatenated. See below.

Two platform rules carry over unchanged. The Fauxnance key is read from the environment and
never reaches the browser. Every consumer sets an explicit `group.id`, named for its module and
written down where your team keeps operational detail, and does not share it with another
consumer. A group id names a logical
consumer rather than a process, so running in one service changes nothing: separate ids are
what keep each module's offsets independent. You are adding two consumers this week and both of
them read topics something else is already reading.

## Splitting four modules without four silos

Four modules and one team is an obvious split and the wrong one. One person per module produces
four people who can each explain a quarter of the deliverable, three of whom are blocked on the
fourth by Tuesday, and a showcase where every question goes to whoever wrote that part. Every
member is expected to walk any of the four unaided.

What works better is splitting by the order of the chain rather than by the module. The chain
is built in sequence anyway, so pair on preferences until its API is real and its persistence
works, then move the pair onto notifications while somebody else hardens preferences against
the security review, then onto watchlists. Portfolio and P&L runs in parallel throughout,
because nothing waits on it, and it is the natural place for whoever wants a contract to build
against rather than an API to design.

Four of you are now committing into one Maven project, which is new. The files everyone wants
to edit at once are the application class, the security configuration and anything under
`config`: agree who touches those and when, and keep the rest of the work inside package
boundaries where two people cannot collide. A branch per module and a review before it lands is
the cheapest version of that.

Three more things are worth agreeing on Monday whichever way you split.

Agree the interfaces between the modules before you build either side. What notifications calls
to resolve a channel, and what watchlists calls to deliver, are the two seams in this week's
work. Write both down on Monday, as Java interfaces, and both sides can build against
something.

Rotate before the last day, not on it. Somebody who first opens the watchlist consumer on
Friday afternoon cannot answer a question about it on Friday afternoon.

Fix the scope of each module when you agree it and be willing to cut inside one rather than
drop one. Four narrow modules that integrate beat three finished ones and one that was never
started, because the criteria are about the chain working end to end.

## The decision log

Committed in `decision-log/`, one file per decision, using the shape in
[decision-log/TEMPLATE.md](decision-log/TEMPLATE.md). It is an acceptance criterion.

Write entries as you take the decisions. A log assembled in the last hour of the sprint records
what you built, which everyone can already see, and loses the thing that makes it worth
reading: what you nearly did instead, and why you did not. It also reads exactly like what it
is.

An entry is worth writing when reversing the choice later would cost more than an afternoon,
when a competent engineer would have chosen the other option, or when somebody on the team
asked why and the answer took a paragraph. Six entries is the floor, and a week with four
modules and two integration seams in it produces more decisions than a week with one, not
fewer.

The entries worth having this week are mostly about the seams rather than about any one module.
What notifications does when no preference has been stored. Where the boundary between two
modules is drawn, and what crosses it. What happens to an alert whose delivery fails. Which
module owns the customer's contact details, given that storing a second copy doubles the number
of places a leak can happen. Those are the ones a reader in the cloud week will want, and each
of them is a decision two people on the team will remember differently by Friday.

### A worked entry

Neutral subject, so that the shape is visible without the content doing the work for you.

````markdown
# 0003 One consumer group per module, sized to the partition count

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-10-06 |
| Decided by | the whole team, at the Tuesday stand-up |

## Context

The watchlist module consumes `market-data`, which `contracts/kafka-topics.md` fixes at six
partitions because it carries the highest message rate on the platform. We intend to run more
than one instance of the Trade REST API in Docker Compose so that we can show what happens when
one is killed. Kafka assigns partitions to consumers within a group, so how we set `group.id`
decides whether a second instance shares the work or duplicates it.

## Options considered

| Option | For | Against |
|---|---|---|
| One group for the module, one consumer per instance | Partitions are split across instances, so work is shared and a lost instance is rebalanced onto the others | Only useful up to six instances, since a consumer beyond the partition count is idle |
| A group per instance | Every instance sees every message, which is simple to reason about | Every instance does the same work, and every alert would be evaluated and delivered as many times as we have instances |
| One consumer, no scaling | Nothing to configure | A single point of failure, and no way to demonstrate a rebalance |

## Decision

One group, `watchlist-service`, with each instance running one consumer, and no more than six
instances. The second option is not a scaling design at all: with this module the duplicate
work is a duplicate customer notification, which is a defect a customer sees rather than wasted
CPU.

## Consequences

Scaling past six instances buys nothing, and we have written that in our README next to the
compose entry for the Trade REST API. A rebalance pauses consumption briefly when an instance
joins or leaves, so alert evaluation has to be idempotent on `eventId` anyway, which we were
going to need for at-least-once delivery. The group identifier is now part of our operational
surface: another consumer adopting the same name would silently take half our messages, which
is why it is listed in the README.
````

What makes that entry useful is not its length. It states what was true when the decision was
taken, gives an option that was genuinely considered and rejected, names the thing that decided
it, and admits a cost. An entry with one option in it is a record of what you did.

## The security review

One OWASP review across the four modules, committed in this folder, using the shape of the
template at `../sprint-08-auth-service/security-review/TEMPLATE.md`. Copy it into
`security-review/` in this folder and retitle it.

The subject is the four modules and the routes they add, not the whole of the Trade REST API.
Where a module changes something the service already did, say so: a filter altered, a route
exempted, a table granted access to. Those are the rows that matter, because they are where new
features reach into an application that was already holding a customer's money.

Three things change from Sprint 8. The categories are the full Top Ten, because four modules
that consume events, call each other, call a third party and serve a customer touch more of the
list than an authentication service did. A category that applies to none of the four is
dispositioned as out of scope with the reason, not deleted: a category with nothing in it is
the one worth asking about.

The second change is that the review is one document. That is harder than four and it is the
point. A category rarely lands the same way on all four, and the row worth reading is the one
that says where it landed differently: injection means one thing in the module that builds a
query from a symbol a customer typed and another in the module that only reads its own tables.
Write the finding per category, and name the module or modules it belongs to. Four reviews
stapled together will read as four reviews stapled together.

The third is that findings have to be addressed. The criterion is not a review that exists, it
is a review whose findings were dealt with. Fixed, with the commit. Mitigated, with what limits
the exposure. Accepted, with the residual risk stated and named as a decision the team took. A
finding still open on Friday belongs in the outstanding items table with an owner against it,
and it will be asked about.

Start with the access-control row. Every brief in this folder names the same first risk,
because all four modules hold data belonging to one customer and reachable with a token
belonging to another, and this year they hold it inside the service that places orders.

Two risks are specific to this week and worth looking for by name. A resolution route that
exists only so another module can call it, reachable by anyone holding a customer token, is an
access-control failure the Sprint 8 review had no equivalent of, and the fix is usually that it
should never have been an HTTP route. And a customer-supplied destination that the service then
posts to, which is the shape a notification channel takes if nobody thinks about it, is a
server-side request forgery.

## What is in this folder

```
README.md              this brief
catalogue/             four briefs, one per mandatory extension, plus stretch.md
decision-log/          TEMPLATE.md, and your entries beside it
security-review/       your combined OWASP review of the four modules
```

Your code does not live here. It lives in the Trade REST API, under
`sprint-06-trade-api/src/main/java`, one package per extension. There is nothing to add to
your local orchestration: the service it goes into is already there. This folder holds the
sprint's documents.

[catalogue/stretch.md](catalogue/stretch.md) describes the two extensions in the catalogue that
are not mandatory here. They are stretch goals and they are available only once all four
mandatory modules meet the criteria below.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. All four extensions are built and integrated end to end, in the dependency order above.
2. Customer preferences persists a default account and an alert channel per customer, and
   applies them at the customer's next login.
3. Customer notifications consumes `trade-events` and delivers through the channel preferences
   holds.
4. Watchlists and price alerts monitors `market-data` and raises threshold alerts through
   notifications, not to a log.
5. Portfolio and P&L implements `contracts/portfolio-api.yaml` and prices from the Fauxnance
   API.
6. Each one is built as a module inside the Trade REST API, in its own package, and every route
   it adds enforces authorisation on the account it addresses.
7. Nothing built in Sprint 6 regressed: the six contract endpoints answer as they did and the
   service's tests are green.
8. One combined OWASP security review covers all four, and its findings are addressed.
9. An architecture decision log is committed, giving the reasoning for each significant choice.

## Evaluation

This sprint contributes 8 marks to the 100-mark Capstone assessment. The catalogue briefs and the
decision-log template are inputs. All six catalogue extensions are eligible evidence under the same
rubric, and the maximum remains 8 marks regardless of how many the team delivers.

| Criterion | Marks |
|---|---:|
| Agreed scope, backlog and architecture decisions | 1 |
| Functional depth of the delivered extensions | 2 |
| End-to-end API, event, data and authentication integration | 2 |
| Combined OWASP review and treatment of its findings | 1 |
| Tests, quality evidence and team explanation | 2 |
| **Sprint total** | **8** |

## Integration quality is read by a person

Every criterion this week is read or demonstrated. Four sets of routes answering the right way
is the floor, and it says nothing about whether the four modules form a chain.

Everything the criteria turn on is watched by somebody sitting in front of the running chain.
Whether the channel a notification went out on came from the preferences module or from a
constant in the notifications one. Whether the boundaries between the four hold, or one of them
reads another's tables directly. Whether the customer's stored default account is applied when
they sign in again, rather than stored and ignored. Whether a replayed event produces one
message or two. Whether an alert reaches a customer or a log file. Whether the portfolio numbers
came from a live quote or a fixture. Whether the scope you agreed on Monday is the scope you
delivered.

Every member of the team is expected to walk any of the four modules unaided at the showcase,
including the ones they did not write, and to say where its boundary with the rest of the
service runs.

Bring to the review: the Trade REST API running with all four modules in it, beside the Auth
service and the broker. Sign in once, the way the Angular application does, and put the same
three requests to one route of each module: refused with no token, refused with a well-formed
token signed by a key nobody holds, answered with a real one. Then walk the chain. A preference
written through your API and read back. One `trade-events` message published and the
notification record it produced. One `market-data` quote that crosses an alert, the alert
reading as triggered, and the notification that went out because of it. The portfolio summary
and positions routes answering the shapes in `contracts/portfolio-api.yaml`, priced from a live
quote. And one Sprint 6 contract route answering as it did in week 6.
