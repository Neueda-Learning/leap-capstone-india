# Postgres initialisation scripts

Mount this directory into your `postgres` container at
`/docker-entrypoint-initdb.d`. Every file in it ending in `.sql` or `.sh` then
runs once, in filename order, the first time the container starts against an
empty data volume. It ships empty because the schema is yours to design in
Sprint 3.

Put your DDL and your seed data here once you have them, numbered so the order
is explicit:

```
infra/postgres/01-schema.sql
infra/postgres/02-seed.sql
```

Nothing reruns against a volume that already holds data. To apply a change,
reset the volume as described in `infra/README.md`, or apply the change by
hand with `psql` and keep the file in step. Decide as a team which of those
two you do, and be consistent, because a schema file that no longer matches
the running database is worse than no file at all.

This README is ignored by Postgres, which only executes `.sql`, `.sql.gz` and
`.sh` files.
