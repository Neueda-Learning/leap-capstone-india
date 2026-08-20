# The two stretch extensions

The catalogue this programme draws from holds six extensions. Four of them are mandatory here
and have a brief each in this folder. The other two are described below.

Neither is available until all four mandatory modules meet the criteria. That is not a rule
about ambition, it is arithmetic: a team that starts a fifth module on Thursday with the
notification chain half-built finishes the week with five things nobody can demonstrate, and
the criteria are all about the four. If you reach Thursday with the chain working end to end,
the review written and the log up to date, tell your instructor, agree a scope, and take one of
these on the same terms as everything else. Both are larger than they look, and both are modules inside the Trade REST API like the four
before them.

## Trade advice and signals

A customer with a blotter and a priced portfolio still has to decide what to do next, and the
platform gives them nothing to decide with. Market data arrives on `market-data` every polling
interval, is used once to price a fill, and is then discarded. This module turns that data into
a stated view on an instrument, a buy, a sell or a hold, with the reason it was generated and
the numbers behind it. It informs a customer who trades; it does not trade. It consumes
`market-data` for anything reacting to now, and Fauxnance `GET /candles/{symbol}` for anything
with a lookback window, and it renders a direction, a strength and a sentence saying what
produced it.

The interesting decisions are about cost and cadence rather than about the indicator.
End-of-day candles do not change during the day, so refetching them per request burns quota for
an answer that cannot have moved: cache them, and be able to say for how long. Recomputing a
signal on every quote is expensive and mostly noise, while recomputing on a fixed interval is
usually enough. The second decision is what a signal is allowed to claim, because a generated
number presented as a recommendation is a product and legal problem before it is an engineering
one. One methodology computed from real candles, explained in the response and rendered in the
UI, is worth more here than three nobody can defend.

## Automated strategy execution

A customer configures a rule once and the platform trades it for them. Buy fifty of an
instrument when its price falls through a level; sell the holding when it rises through
another. The customer is asleep, the condition is met, and the order is placed without anyone
confirming it. That is the whole feature, and it is also why every control in it is
load-bearing rather than hardening added after a demonstration works. A defect here does not
render the wrong number on a screen. It spends a customer's money. Orders are placed through
`POST /api/v1/orders`, never published straight onto the `orders` topic and never by calling
the order service directly, because the route's validation, authorisation and idempotency check
are what stands between a strategy bug and an unrecoverable position. Sharing a process with
that code makes the shortcut easy to take and no less wrong.

Identity is the first question and it has no obvious answer: a strategy runs when nobody is
logged in, so it cannot borrow a customer's access token, and deciding what it does instead is
the strongest decision log entry in the whole catalogue. The second is bounding the damage, in
code and at the point of decision, with a maximum spend, a maximum position size and a stop
after repeated failures. The third is state: a strategy that has been disabled must stop
placing orders now, not at the end of its current evaluation cycle, and that is demonstrated
live by disabling one mid-cycle.
