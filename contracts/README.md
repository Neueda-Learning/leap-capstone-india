# Contracts

These five files are binding. They are the interfaces between the components
your team builds and between your team and everyone else's. Implement them
exactly. A field renamed here breaks a consumer you did not write, and a
status code changed here breaks a UI that generated its client from the file.

Each contract carries its own reasoning. Read the prose in them, not only the
schemas: the descriptions explain why an endpoint is shaped the way it is,
which is what you will be asked about in review.

| File | What it is | First used |
|---|---|---|
| `trade-api.yaml` | OpenAPI 3.1 description of the Trade REST API: order placement, cancellation, account queries, balance, positions, and the error envelope with its full code catalogue. | Sprint 6, and again in Sprint 9 when the Angular client is generated from it |
| `auth-api.yaml` | OpenAPI 3.1 description of the authentication service: register, login, refresh, and the current user. Defines the JWT claims every other service verifies. | Sprint 6 as the shape of the provided stub, Sprint 8 as the specification of the service you build |
| `kafka-topics.md` | The topic catalogue: three topics with their keys, partition counts, retention and cleanup policy, the message envelope, the payload schema for each topic, and the producer and consumer matrix. | Sprint 7 |
| `analytics-schema.sql` | The analytical star schema: one fact table and its dimensions, in portable ANSI SQL. The target your extract, transform, load pipeline writes into. | Sprint 4 for the dashboard, loaded in full in Sprint 7 |
| `portfolio-api.yaml` | OpenAPI 3.1 description of the Portfolio and P&L service: priced holdings, cost basis, and realised and unrealised profit and loss. | Sprint 10 |

There is no contract for the transactional database. The operational schema is
the Sprint 3 deliverable, and your team designs it from the domain and the
business rules rather than implementing one handed to you. `trade-api.yaml`
names the columns the API is required to expose, so read it before you finish
the model.

## Working with them

Generate clients rather than hand-writing them. The Angular application in
Sprint 9 is assessed on using a client generated from `trade-api.yaml` and
`auth-api.yaml`, and the same generators are worth using earlier for a quick
check that your implementation matches.

View a contract as documentation while you work:

```bash
npx @redocly/cli preview-docs contracts/trade-api.yaml
```

Validate one before claiming it is implemented:

```bash
npx @redocly/cli lint contracts/trade-api.yaml
```

If you believe a contract is wrong, raise it. Do not quietly build something
else. A divergence you did not announce surfaces in Sprint 10 as an
integration failure between two teams' services, at the point in the programme
when there is least time to fix it.
