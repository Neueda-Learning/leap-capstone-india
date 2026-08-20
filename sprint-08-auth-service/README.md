# Sprint 8: the auth service

Five services in this platform need to know who is calling and which account
that caller may act on, and none of them should hold a password to find out. A
password that lives in the Trade REST API leaks the day that service has an
injection defect, and a hashing routine copied into the Trade Executor gets
upgraded in one of the two places. This sprint builds the one component that
ever sees a credential, and gives every other component a signed statement of
identity it can check on its own.

That is why authentication is a service rather than a library. One process owns
registration, login, hashing and the token lifecycle, and every other process
verifies a signature with no network call and no shared database. Sprints 6 and
7 verified tokens minted by a team-owned test fixture. This sprint builds the
process that issues them for real.

## A short week

Two SME cloud sessions run on Monday and Tuesday, so the order of the work
decides whether it fits. Take registration and login first, with the hashing and
the uniform failure built in rather than retrofitted. Then the guard and
`/auth/me`, then refresh, then integration, which needs the rest of the stack
up. Fill in the security review as each part lands.

## What you deliver

| Deliverable | Where it lives |
|---|---|
| Four endpoints implementing `contracts/auth-api.yaml` | the module tree you design |
| A credential store with hashed passwords | your migration or bootstrap, plus the repository that reads it |
| Access and refresh token issuance, and refresh token storage | as above |
| A guard protecting `/auth/me` | as above |
| Jest suites, including the guard paths named below | alongside the code, as `*.spec.ts` |
| A multi-stage `Dockerfile` | this folder |
| Your service added to your local orchestration | repository root |
| The OWASP review, filled in | `security-review/` |

No starter code and no project skeleton ships. Deciding how this service is
decomposed, and where the verification happens inside it, is most of what the
sprint assesses.

## The engineering contract

Set one project up in this folder. Its internals are yours. Nine things are
fixed, because the contract and your teammates depend on them.

- One NestJS project rooted in this folder, on Node 20 or later and TypeScript,
  where `npm ci`, `npm run build` and `npm test` all succeed on a machine that
  has never seen your code. Commit `package-lock.json`: `npm ci` installs
  exactly the tree it names.
- Sources under `src/`, or under a directory of your own naming, with the specs
  as `*.spec.ts` beside the code they cover.
- The four operations in `contracts/auth-api.yaml`, at the paths, verbs, status
  codes and bodies it fixes, answering on port 3000.
- Access tokens signed HS256 with `JWT_SECRET`, carrying exactly `sub`,
  `accountId`, `roles`, `iat` and `exp`, plus the `iss` the contract defines.
- Passwords stored with argon2id, or bcrypt at cost 12 or above, and never
  written to a log.
- Jest covering the guard, including the expired-token and wrong-signature
  paths, each test named for what it asserts.
- The OpenAPI document generated from your code and served by the running
  service, at two paths you choose and can name.
- `JWT_SECRET`, the database connection and every other value that differs
  between a laptop and a container read from the environment at runtime, and
  present in no committed file.
- A multi-stage `Dockerfile` of your own design here, and the service joined to
  your local orchestration on the auth port, so that adopting it is a
  configuration change in your Sprint 6 service rather than a code change in
  it.

```bash
cd sprint-08-auth-service
npm install                  # first run, and whenever you add a dependency
npm run build
npm test
```

## The contract is the specification

`contracts/auth-api.yaml` was written before either implementation existed and
it binds both. Four operations, with paths, verbs, status codes and bodies
fixed.

| Method | Path | Protected | Success | Documented failures |
|---|---|---|---|---|
| POST | `/auth/register` | no | 201 `UserResponse` | `AUTH-409`, `VAL-422` |
| POST | `/auth/login` | no | 200 `TokenResponse` | `AUTH-401`, `VAL-422` |
| POST | `/auth/refresh` | no | 200 `TokenResponse` | `AUTH-401`, `VAL-422` |
| GET | `/auth/me` | bearer token | 200 `UserResponse` | `AUTH-401` |

Registration issues no tokens, because an unauthenticated route that mints a
session is an authentication bypass as soon as it has its first defect. It does
not create a trading account either: accounts are owned by the Sprint 3 schema.
Every failure leaves in the platform envelope, `{"errorCode": ..., "message":
...}` and nothing else, so that Sprint 9 keeps one error handler for the whole
platform.

## The claim set, exactly

The token payload is not a place to put things that might be useful later. Every
claim in it is a field a consumer can start depending on, and every consumer
that depends on one is a service that breaks when you remove it.

| Claim | Type | Meaning |
|---|---|---|
| `sub` | string | The user identifier, a UUID. Stable for the life of the user, and not the username, because a username can change |
| `accountId` | integer | The numeric trading account key, `ACCOUNTS.id`. The Trade REST API compares it against the account in the request and answers `ACC-403` when they differ |
| `roles` | array of string | `CUSTOMER` or `ADMIN`. Always present, never empty |
| `iat` | integer | Issued at, seconds since the Unix epoch |
| `exp` | integer | Expiry, seconds since the Unix epoch. Fifteen minutes after `iat` |

Those five are assessed. The contract defines one more, `iss`, carrying
`auth-service`. Consumers validate the configured issuer.

Anything beyond those six is a finding, not a bonus. An email address in the
payload is an email address published to every holder of the token, because the
payload is base64 and not encryption: paste one into any decoder and read it.
A claim outside that set is a finding, because removing one after Sprint 9 has
generated a client from it is not a configuration change.

## Password storage

Store passwords with argon2id, or with bcrypt at cost 12 or above. Never MD5,
never SHA-256, never an unsalted digest of any kind. A general-purpose hash is
built to be fast, and fast is the one property a password hash must not have: a
modern GPU runs SHA-256 in the billions per second, so a stolen table of those
digests is a stolen table of passwords by the weekend. The cost factor is a
decision you make and defend. Pick values that make one verification take on the
order of a tenth of a second on the hardware you deploy to: too low and an
offline attacker gets the same speedup you did, too high and your login route is
the cheapest denial-of-service target in the platform.

Never log a password. The ways one reaches a log are all indirect: an error
object serialised whole, a request body dumped by a debug interceptor, a DTO
printed in a stack trace. Two habits make the rule structural. Log through one
logger that redacts by key name at any depth, and never hand a whole request
body to a log call. Searching your sources for a log call that names a
credential field catches the direct case and none of the indirect ones, and the
indirect ones are what the review asks about.

## Refresh rotation

An access token cannot be withdrawn. It is verified by signature alone, so
fifteen minutes is the size of that compromise. The refresh token is the
opposite: opaque, stored, revocable, and the reason a user is not asked for a
password every quarter of an hour.

The requirement for this cohort is that every refresh issues a new refresh
token, so a client still presenting the value it was given at login is
presenting a value the service has stopped issuing. Revoking the presented token
is optional here. If you build it, that token is dead in your store before the
response is written and a second presentation answers `AUTH-401`. If you do not,
write the decision and the risk it accepts in the security review.

Reissue on its own defends against a stolen token used once. Suppose one is
taken from a log, from browser storage, or from a proxy that recorded a request
body. The real user refreshes and carries on with the new value, and what the
thief holds is no longer the one the session runs on. What is missing without
revocation is that the old value still works: both parties refresh, both hold
live sessions, and nothing in the service can tell there are two of them.

Revocation closes that. Exactly one of the two can use the token, and the other
presents one that has already been exchanged. That presentation is the alarm,
because either a client repeated a request or somebody stole a token and the
service cannot tell which. The contract treats it as theft: revoke every live
refresh token for that user, answer `AUTH-401`, and you have a record of when
the two diverged. Store a hash of the refresh token rather than the token either
way, so that read access to your database is not session takeover.

## One answer for every failure

An unknown username and a wrong password get the same status, the same body and
comparable timing. This is the requirement most often failed by accident, and it
fails in three distinct ways.

**The body.** `AUTH-401` with the message `Unauthorised`, for an unknown user, a
wrong password, an expired token, a wrongly signed token and a malformed header.
A helpful message tells an attacker which half of the credential pair was wrong.

**The status.** 401 for all of them. A 404 for an unknown user and a 401 for a
bad password is the same disclosure written in the status line.

**The timing.** If the unknown-user path returns as soon as the lookup misses it
answers in a millisecond, while the wrong-password path spends a tenth of a
second verifying a hash. An attacker with a username list and a stopwatch reads
your customer base off the response times without guessing a password. Make both
paths do the same work: where the username is not found, verify the supplied
password against a fixed dummy hash of the same algorithm and the same
parameters, discard the result and return the same failure.

Be ready to demonstrate it. Run both paths repeatedly and compare the elapsed
times. Judge the shape rather than the size: a generous absolute threshold is
fair, because a laptop under load and a cold connection pool each move a response
by tens of milliseconds, but one path taking twice as long as the other is an
early return even when both numbers are small. A consistent gap is proof of an
early return, and comparable timing is not proof of constant time. A burst of
failed logins from one address collides with a login throttle, so build the
throttle and know its cooldown window, and run the comparison outside it. A
throttle limits how fast an attacker can use an oracle you left open, and does
not close it.

## Integrating the auth service

The acceptance statement is that the Trade REST API needs no code change. Not a
small one, and not only a configuration class: no Java changes. That is
achievable because the Sprint 6 service already verifies the claims and the
algorithm in the contract and reads `JWT_SECRET` from configuration.

| Change | Where |
|---|---|
| Your service is added on the auth port | local orchestration |
| Your service reads the same `JWT_SECRET` the Trade REST API verifies with | root `.env`, passed through your local orchestration |
| The Trade REST API's issuer setting names your issuer | that service's configuration, from the environment |
| The database connection for the credential store | your service's environment |

Nothing in that table is a Java file. If your Trade REST API needs a code change
to accept a token from this service, something in it is coupled to a test
fixture rather than to the contract: a hard-coded issuer string, a claim read
with a name the fixture happened to use, or a verifier that decodes the payload
before checking the signature.

The development `JWT_SECRET` in `.env.example` is published in this repository,
so anyone who has read it can mint a token your consumers accept for as long as
that value is in use. Keeping it is defensible in a training stack; rotating it
once a real issuer exists is the better habit. Record which you chose in the
security review, as a decision with its reason.

## Tests

Jest, with the Nest testing utilities, running without a database and without an
HTTP server. This is the service where a defect is a breach rather than a bug,
so the suite is a deliverable. The guard is assessed specifically, and two paths
through it are named.

| Path | What the test proves |
|---|---|
| An expired token | A token that was valid, signed by you, with an `exp` in the past, is refused. A guard that checks the signature and forgets the clock accepts every token it ever issued, for ever |
| A wrong signature | A well-formed token whose signature does not match the key is refused before any claim is read. This is the test that catches a verifier that decoded first and verified afterwards |

Make them fail for the right reason. Build the expired case by signing a genuine
token with a past `exp`, not by corrupting the payload, which the signature
check refuses first and which therefore passes against a guard with no expiry
check at all. Build the wrong-signature case by signing a genuine, unexpired
token with a different key.

Name both tests for what they assert, so that a reader finds them without
opening the guard. Which spec file they live in is your design's business: a
guard that hands the token to a token service, and tests the two cases where the
verifying actually happens, is a defensible shape. Beyond the guard, expect to be
asked at the review for tests covering the identical failure for an unknown user
and a wrong password, and the reissue on refresh.

## OpenAPI, served by the running service

The running service publishes its own OpenAPI document, generated from the
decorators on your controller and your DTOs. A YAML file maintained by hand
beside the code drifts within a fortnight, and the document that matters
describes what is deployed. Two paths: the human page, `/docs`, and the JSON
document, `/docs/json`. Serve them elsewhere if your design says so, and say
where at the review. What is assessed is that the JSON is a valid OpenAPI
document served by the running process and that it describes all four routes. It
does not replace `contracts/auth-api.yaml`. It is the evidence that your code
still matches it.

## The security review

The deliverable is a committed file, not a conversation at the review. Copy
`security-review/TEMPLATE.md` to a file of your own in the same folder and fill
it in as you build. The categories are the OWASP Top
Ten items that bear on an authentication service, and the template says where to
look for each of them.

Every category carries a finding and a disposition, both written. A finding of
"none" needs a sentence naming what you checked, because "none" with nothing
beside it is indistinguishable from a category nobody looked at. A disposition of
"accepted" needs the residual risk and why the team is carrying it. If you did
not build revocation of the presented refresh token, A04 is where that decision
and its risk are written. Whether what is in the cells is true is read by your
instructor.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. All four endpoints are implemented and match the contract, including the
   error envelope and every code in it.
2. The access token carries exactly the claims contract: `sub`, `accountId`,
   `roles`, `iat`, `exp`, and the `iss` the contract also defines.
3. Adopting this service in the Trade REST API is a configuration change only,
   with no code change in it.
4. Passwords are hashed with argon2 or bcrypt, and never logged.
5. Every refresh issues a new refresh token. Revoking the token that was
   presented is optional, and where it is not built the decision and the risk it
   accepts are written in the security review.
6. A failed login returns the same response, and comparable timing, for an
   unknown user as for a wrong password.
7. Jest tests cover the guard, including the expired-token and wrong-signature
   paths.
8. The running service serves its OpenAPI document.
9. The security review against the auth-related OWASP items is committed, with a
   finding and a disposition for every category.

## Evaluation

This sprint contributes 13 marks to the 100-mark Capstone assessment. The API
contract and the security-review template are inputs. Marks are awarded for the
service, security decisions and evidence the team produces.

| Criterion | Marks |
|---|---:|
| NestJS design and contract-compliant endpoints | 2 |
| Registration, login, refresh and token lifecycle | 3 |
| Password hashing, JWT claims and uniform authentication failures | 2 |
| Guards, account authorisation and Trade REST API integration | 3 |
| Jest coverage, served OpenAPI document and completed OWASP review | 3 |
| **Sprint total** | **13** |

## The review

Your instructor assesses this sprint by reading the code against the criteria
above and by exercising the running service. A green suite and a complete
template are the floor, and neither can see intent.

Read or demonstrated, never counted: whether a password reaches a log by an
indirect route, whether the cost factors were chosen against anything, whether
your refresh decision is one the team reasoned about, whether the uniform failure
holds because both paths do the same work rather than because the machine was
quiet, whether the security review is a reading of your service or of the
template, and whether the guard runs before every route that needs it.

Bring to the review: the running stack, all four endpoints exercised against the
contract, one token decoded in front of the panel claim by claim, a wrong password and an unknown user compared on status, body and elapsed
time, one refresh traced through your store with the reissued token working and
the presented one behaving as your security review says it does, the stored
password hash, the OpenAPI document fetched from the running process, a protected
Trade REST API route answering a token from this service and refusing one signed
with a key it should not trust, the `git diff` showing no Java changed, and your
answer to what you would do at 09:00 on the morning somebody reports a stolen
refresh token.
