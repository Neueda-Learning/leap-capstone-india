# Seed data

Fixture rows, as `.sql` files, written by you and applied after every migration
has run. Number them the way you number migrations if you use more than one
file, because insert order has to respect your foreign keys.

Keep seed data out of `migrations/`. The two are reloaded on different
schedules: you will rebuild the schema without wanting fixtures, and reload
fixtures without wanting to rebuild the schema.

## What the data has to cover

Seed data is not decoration. It is the fixture set Sprint 4 analyses, Sprint 6
tests against, and Sprint 7 prices against live quotes. Every error path in
`contracts/trade-api.yaml` is reachable only if a row exists that reaches it. A
fixture set of one happy customer buying one share leaves most of the platform
untestable.

| Coverage | Why it is needed |
|---|---|
| Accounts in all three states, `ACTIVE`, `SUSPENDED` and `CLOSED` | The refusal paths for a frozen and a finished account |
| An account whose cash cannot afford a realistic order | The insufficient funds path |
| An account holding a position | Selling something, and the refusal to sell more than is held |
| Several instruments, at least one not an equity | Asset class handling, and the Sprint 4 breakdown by class |
| An instrument that no longer trades, still referenced by an older order and by a holding | The refusal to trade a delisted name, and the reason reference data is retired rather than deleted |
| Orders in all four lifecycle states: working, filled, rejected and cancelled | Order history, status filtering, and the compliance question a run of rejections raises |
| Holdings that reconcile against the filled orders that produced them | Positions are derived state, and you should be able to demonstrate the derivation |

Two of those rows are traps if you read them quickly. A suspended or closed
account that has placed no order is a fixture; one that traded after losing
`ACTIVE` status is a defect you have seeded into your own data. And a holding
is the net result of the filled orders for that account and instrument, with a
sale reducing the units held and leaving the average price alone. If you can
write the query that rebuilds your holdings from your orders and get the same
numbers, you have understood what a holding is.

The table above is written in business terms. It is not a suggestion about what
your columns are called, how many tables the data belongs in, or which values
belong together. An account has a customer-facing reference that a customer
quotes on a call and reads on a statement; whether that reference is also the
key an order carries internally is your decision, and writing these inserts is
where that decision first gets tested. A fixture set that is awkward to write
is usually telling you something about the schema.

Use symbols the Fauxnance API actually serves. The base URL and the endpoint
list are in the root `README.md`. Inventing tickers costs you a pass over every
fixture in Sprint 7 when no quote resolves.

Spread creation timestamps across several months rather than stamping every row
with the same instant. Query 5 in the sprint brief, the incremental extract,
returns everything or nothing against a fixture set created in one second, and
Sprint 4 has nothing to plot.

## Reloading

Your apply command applies every migration and then loads these files. Inserts
that collide with rows already present will fail, which is correct: seed data is
loaded into a known state, not merged into an unknown one. Reload by starting
from an empty database, which is the only state the command is written for.
