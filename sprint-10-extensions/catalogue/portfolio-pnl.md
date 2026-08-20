# Portfolio and P&L

A customer can see what they hold and what they paid for it. They cannot see what it is worth
now, or whether they are up or down. The Trade REST API returns positions unpriced: a quantity
and an average cost, and nothing else. Pricing a holding needs a live quote, and a quote is a
third-party HTTP call with its own latency and its own failure modes. Putting that call inside
the transaction that records a trade is the wrong trade-off for a system of record, so the
valuation lives in its own module, on its own routes, reads the same positions, and is allowed
to fail without stopping anyone from trading.

This is the module that turns a list of holdings into a statement: market value, cost basis,
unrealised profit and loss, realised profit and loss, and one total the customer can act on.

## Where it sits in the order

Fourth in the list and outside the chain. It depends on none of the other three and none of
them depend on it, so it can start on Monday alongside preferences and finish whenever it is
finished.

| Direction | Module | What crosses the boundary |
|---|---|---|
| Depends on | None of the other three | Nothing in this sprint waits on this module and this module waits on nothing in it |
| Depends on | The platform you already built | Postgres, the Trade REST API it lives in, the Fauxnance API, and optionally the topics |

Independent does not mean easy. This is the one of the four whose API is already written, whose
arithmetic is defined for you, and whose hardest problems come from a third party you do not
control. Give it to whoever would rather build to a contract than design one, and start it
early: it is the one most likely to be waiting on a quota, a stale quote or a currency question
at four o'clock on Thursday.

## Who uses it

The customer, through a portfolio screen in the Angular application: their holdings priced,
their profit and loss for the day and for the lifetime of the account, and a total portfolio
value that includes cash. An adviser or a support agent reads the same numbers when a customer
telephones.

## What it integrates with

| Surface | How this module uses it |
|---|---|
| `contracts/portfolio-api.yaml` | Binding. The routes, the fields, the error codes and the staleness rules are already specified |
| Postgres: `accounts`, `instruments`, `positions` | Read-only. Quantity, average cost, instrument currency and cash balance |
| Fauxnance `GET /quotes?symbols=A,B,C` | Batch quotes, up to 25 symbols in one call. This is where a price comes from |
| `trade-events` | Optional, and the natural source for realised profit and loss, which is booked at the moment of a sale and never recomputed |
| `market-data` | Optional. The topic already carries the last quote the poller published, which is one answer to what to serve when Fauxnance is unreachable |
| The account balance the Trade REST API already serves | One of the two places cash can come from. Choose one and say why, and reach it through the layer that owns it rather than through a second query of your own |

Nothing in the shared trading schema is written by this module. Whatever it owns, it owns in
its own tables.

## The contract binds

`contracts/portfolio-api.yaml` is the specification for this module, in the same sense that
`trade-api.yaml` was the specification for Sprint 6. Build to it rather than around it. It
fixes three routes and a health check, the exact field names on every response, the error
catalogue including `MKT-503`, and what the platform answers when a price is unavailable for
some instruments rather than all of them. The routes are served by the Trade REST API on 8080,
alongside the Sprint 6 endpoints, and nothing else about the document changes.

Read its description block before you design anything. The definitions of cost basis, market
value, unrealised and realised profit and loss are in there, and they are most of the
assessment. The common error is computing realised profit and loss from today's price. Realised
profit and loss has nothing to do with today's price.

## What makes it worth building

The arithmetic is small and the failure modes are not. Every hard part of this module is a
question about data that is late, missing, or in the wrong currency.

- A quote is delayed, and the Fauxnance API can serve a stale one when its own upstreams are
  down. Every priced figure therefore carries the time it was observed and whether it is stale,
  and a stale portfolio is rendered with a visible marker rather than passed off as live.
- The daily quota is 2000 requests, shared with everything else on the platform that prices.
  A per-position loop over ten holdings costs ten times what one batched call costs for the
  same answer. Caching, batching and deciding how fresh a price has to be are design decisions
  with a number attached to them.
- Holdings can be in more than one currency, and a total has to be in one.
- Some symbols price and others do not. The contract says what a partial answer looks like, and
  getting that path right is what separates a demonstration that survives a Fauxnance outage
  from one that does not.

## Scope for one week

The three contract routes and the health check, priced against live quotes, for an account with
several holdings. Realised profit and loss accumulated from sales rather than recomputed.
Batched, cached quote fetching. The partial and stale paths working and visible in the UI.

Out of scope unless the rest is finished: performance attribution, time-weighted returns, tax
lots, and anything that needs a price history this platform does not store.

## What to get right

- **Access control.** The token's `accountId` claim is compared against the account in the path
  on every route. A mismatch is `403` with `ACC-403`, not `404`, and it is logged. A customer
  probing another customer's portfolio is an access-control failure, not a lookup miss.
- **The key stays server-side.** The browser never calls the Fauxnance API. Prices reach the
  screen through the platform.
- **Stale is a state, not an error.** Serve the number and mark it. Hiding it and showing
  nothing are both worse than saying how old it is.
- **Read-only means read-only.** This module reads the trading tables and writes only to its
  own. It shares a database connection with the code that records orders, so nothing but review
  keeps that boundary: no write to `accounts`, `orders` or `positions` comes from a portfolio
  path.
