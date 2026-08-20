# Customer notifications

An order is filled at nine in the morning and the customer finds out at four in the afternoon,
because that is when they next opened the blotter. A rejection is worse: nothing on the
platform tells anyone that the order they placed will never happen. `trade-events` already
carries every outcome that matters. This module is what turns one of those events into a
message a customer actually receives, on the channel they chose.

It is also the delivery path the rest of the platform uses. The alert watchlists raises this
week ends up here, which means its reliability matters to more than its own feature list.

## Where it sits in the order

Second of the four. It has a dependency behind it and a dependant in front of it, which makes
it the module most exposed to somebody else's schedule.

| Direction | Module | What crosses the boundary |
|---|---|---|
| Depends on | Customer preferences | The customer's alert channel, resolved through that module's interface before a message is sent |
| Provides | Watchlists and price alerts | A delivery interface, called when a threshold has been crossed |

Do not start this one before preferences has an interface that answers. Hardcoding a channel to
unblock yourself is the one shortcut this module does not have, because the criterion is that
the message goes out on the channel preferences holds. Agree that interface and what it returns
with the preferences pair, and agree the one watchlists will call on you, before either side
builds against a guess.

## Who uses it

The customer, on whichever channel they configured: email, SMS or a push message. The Angular
application shows the same history as an inbox, so a customer who missed a message can find it.

## What it integrates with

| Surface | How this module uses it |
|---|---|
| `trade-events` | Consume, with a group of its own. `ORDER_FILLED`, `ORDER_REJECTED` and `ORDER_CANCELLED` are all newsworthy |
| Customer preferences | In-process, through the interface that module publishes, to resolve the channel before sending |
| Watchlists and price alerts | Inbound. A triggered alert arrives here for delivery |
| Angular application | Notification history, and marking a message read if you build an inbox |
| An outbound channel | Email, SMS or push. A logging stub is acceptable for a channel you cannot provision, provided the routing decision is real and the resolved channel is recorded |

## The API is yours

There is no contract for this module. Design the API, write it as OpenAPI before you write the
controller, and bring it to your instructor on day one for review. The platform conventions
still bind: the `{errorCode, message}` envelope, the platform error catalogue extended only
where nothing in it fits, and the bearer token the Trade REST API verifies before any of your
routes run. What the verifier cannot decide is whether this caller may reach this resource, so
every route compares the `accountId` claim against the history it is about to return.

One part of this module is not for a customer at all: what watchlists calls to have an alert
delivered. That is a Java interface rather than a route. Publishing it as an HTTP route is how
a customer ends up able to send themselves anything, and it is the finding the review will look
for first.

## What makes it worth building

Consumption and delivery are two different failures, and separating them is the design problem
in this module. The Kafka offset says what has been read. The delivery state says what has
reached a customer. Commit the offset once the notification is durably recorded for delivery,
not once an external provider has confirmed it, because an email provider having a bad
afternoon should not stall a partition and back up every other account on it. Track queued,
sent and failed separately from the offset.

Kafka delivers at least once, so a duplicated event must not produce a duplicated message. The
discipline is the one the Trade Executor already uses: key on `eventId` and make the second
attempt a no-op. Being able to replay an event in front of your instructor and show that
nothing is sent twice is worth building the ledger for.

The last piece is the dependency. A notification cannot be routed without knowing where to
route it, so the channel comes from the preferences module on every send rather than from a
constant here or a copy taken at start-up. What happens when no preference has been stored is a
decision, and both answers are defensible: hold the message, or send on a documented default.
Choosing nothing means the message is lost and nobody finds out.

## Scope for one week

Consumption of the three order outcomes, resolution of the channel through preferences,
delivery on at least one channel, notification history exposed to the customer, an interface
watchlists calls to have an alert delivered, and idempotency proven by replaying an event and
showing that nothing is sent twice.

Out of scope unless the rest is finished: digest batching, retry with backoff that
distinguishes a transient failure from a permanent one, and read receipts.

## What to get right

- **Access control.** Notification history is read by its owning account only, checked against
  the verified token.
- **The channel is resolved, not assumed.** The criterion is delivery through the channel
  preferences holds. Record the resolved channel on the notification, so that the demonstration
  is a record you can show rather than a claim you make.
- **Nothing sensitive in a message.** A payload carrying a credential, a full card number or
  anything `contracts/kafka-topics.md` prohibits from a message is a disclosure that outlives
  the incident. The outbound message is held to the same rule as the event.
- **No caller-supplied destinations.** A webhook target or channel URL that a customer can set,
  and that the platform then fetches or posts to, is a server-side request forgery. Fix the
  destination per channel type or validate it hard.
- **A rejection is news.** A customer who only hears about successes has no idea their order
  failed.
