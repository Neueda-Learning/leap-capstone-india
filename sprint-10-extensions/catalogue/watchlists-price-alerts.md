# Watchlists and price alerts

A customer holds five instruments and is curious about twenty. The platform knows about the
five, because the Trade REST API records what they bought, and knows nothing about the other
fifteen. It also has no way to tell a customer that a price they cared about has been crossed,
so the only way to find out is to sit and watch a screen. This module owns both halves: the
list of instruments a customer is tracking, and the thresholds they want to be told about.

## Where it sits in the order

Third of the four, and last in the chain. Everything it needs is behind it by the time it
starts, which is the payoff for building in this order.

| Direction | Module | What crosses the boundary |
|---|---|---|
| Depends on | Customer notifications | Delivery. A crossed threshold is handed to notifications, which resolves the channel and sends |
| Depends on | Customer preferences | Indirectly, through notifications. This module never asks for a channel itself |

The indirect dependency is the design and not an accident. If this module resolved the channel
itself, there would be two places on the platform deciding how to reach a customer, and they
would disagree within a fortnight. Raise the alert, hand it over, and let one module own
delivery. Sharing a process with notifications makes the shortcut easy to take: a call into its
tables, or a channel read straight from preferences, is the same design mistake with a shorter
stack trace.

An alert written to a log is not an alert, and the acceptance criterion says so in as many
words. Building this before notifications answers means building the one thing the criterion
rules out.

## Who uses it

The customer, in the Angular application: a watchlist with live prices beside each entry, and
alerts they can create, see the state of, and cancel. A watchlist entry is not a position, and
a customer must be able to watch something they have never traded.

## What it integrates with

| Surface | How this module uses it |
|---|---|
| `market-data` | Consume, with a group of its own. Every quote the poller publishes passes through this consumer, which checks it against the active thresholds for that symbol |
| Customer notifications | In-process, through the delivery interface that module publishes. A triggered threshold is handed over, and notifications resolves the customer's channel |
| The platform's reference data | Read-only, to resolve an instrument by symbol, through the layer that owns it. Instruments and positions are referenced, never copied |
| Angular application | Watchlist management, live prices, alert creation and alert state |

Do not consume `orders` or `trade-events`. Neither says anything about what a customer is
curious about.

## The API is yours

There is no contract for this module. Design the API, write it as OpenAPI before you write the
controller, and bring it to your instructor on day one for review. The platform conventions
still bind: the `{errorCode, message}` envelope, the platform error catalogue extended only
where nothing in it fits, and the bearer token the Trade REST API verifies before any of your
routes run. What the verifier cannot decide is whether this caller may reach this resource, so
every route compares the `accountId` claim against the watchlist it is about to return.

## What makes it worth building

The consumer is the part worth thinking about. Every quote for every symbol arrives here, and
the consumer has to decide, per message, whether any customer cares. That is a lookup on the hot
path, and how it is indexed is a real decision with a real answer.

Then there is the meaning of "crossed", which is less obvious than it looks. A threshold above
the current price triggers when the price rises through it; one below triggers when it falls
through it. What happens next is open: an alert can deactivate itself, wait for the customer to
reset it, or fire on every quote past the level. The third choice sends a customer forty
messages in a minute, and it sends them through code somebody else on your team is responsible
for. Decide which behaviour this module implements, and record why.

Delivery is where this stops being a private feature and becomes part of the platform. The call
to notifications is in-process, so it will not time out, and it can still fail: the channel is
unknown, the provider refuses, the record cannot be written. The customer asked to be told, and
the moment has passed. Decide what happens when the delivery call fails, and make the alert
state readable either way, because a customer looking at an alert that says nothing has no idea
whether it fired.

## Scope for one week

Watchlists a customer can create and add instruments to, with a live price beside each entry.
Price alerts with a threshold and a direction, evaluated against the `market-data` stream,
delivered through the notifications module to the channel the customer configured. Alert state
visible to the customer, including the state that says an alert has fired.

Out of scope unless the rest is finished: percentage-move alerts, a push channel to the
browser, and alert history with per-delivery status.

## What to get right

- **Access control.** A watchlist and its alerts belong to one customer. Every read and write
  filters on the account in the verified token, never on an identifier the client supplied.
- **Alerts are delivered through notifications.** Not to a log, not to standard output, not to
  a table nobody reads. The criterion is a notification reaching a customer on their chosen
  channel, demonstrated end to end.
- **A cap per account.** An unbounded alert-creation route lets one account fill the table and
  turn your own `market-data` consumer into the thing that takes the service down, and the
  service it takes down is the one that places orders.
- **Authorise every route.** The service verified the token before your handler ran. Whether
  this caller owns this watchlist is your decision to make, on every route, from the claim
  rather than from anything in the request body.
