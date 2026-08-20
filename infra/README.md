# Local infrastructure requirements

This branch does not supply an executable local stack. Your team must design,
create and document the infrastructure used by the platform.

The local environment must provide:

- PostgreSQL 16 on `localhost:5432`
- Kafka 3.8 in KRaft mode on `localhost:9092`
- a network that lets your services reach PostgreSQL and Kafka by stable names
- explicit creation of the topics in `contracts/kafka-topics.md`
- health checks and a repeatable start and stop process

PostgreSQL starts empty. No schema, migration or seed loader is supplied.
Designing the schema and its migration process is the Sprint 3 deliverable.
`infra/postgres/README.md` describes the initialisation convention the rest of
the material assumes, so read it before you decide how your database is built.

Kafka topic auto-creation must be disabled. Create each topic explicitly with
the partition count and retention policy in `contracts/kafka-topics.md`. The
creation process must be safe to run more than once.

## Configuration

Copy `.env.example` to `.env`, replace the values marked `replace`, and keep
the real file out of version control. Configure your services and local
orchestration to read these values at runtime.

Use these local addresses unless your team documents another arrangement:

| Service | Address |
|---|---|
| PostgreSQL from the host | `localhost:5432` |
| PostgreSQL from a service | `postgres:5432` |
| Kafka from the host | `localhost:9092` |
| Kafka from a service | `kafka:29092` |
| Auth service | `localhost:3000` |

Port 3000 is reserved for the auth service built in Sprint 8.

## Team deliverables

Commit the configuration needed to reproduce the local environment, excluding
secrets and generated data. Include instructions for:

- starting and stopping the whole stack and individual dependencies
- applying migrations to an empty database
- creating and inspecting Kafka topics
- resetting PostgreSQL and Kafka data
- diagnosing port conflicts, failed health checks and service-name errors

Every executable file and infrastructure definition is a team deliverable.
