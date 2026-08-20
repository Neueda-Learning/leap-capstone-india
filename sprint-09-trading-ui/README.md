# Sprint 9: the trading UI

Every API this application consumes already exists, and your team wrote all of it: the schema
from Sprint 3, the domain rules from Sprint 5, the Trade REST API from Sprint 6, the executor
and the bus from Sprint 7, the Auth service from Sprint 8. That is why the front end is built
last, and it is not a scheduling convenience. A screen written against an API somebody imagined
disagrees with the real one the week it arrives. Building it now means every call you make is a
call you can run, and every failure you render is a failure you can provoke.

One property of the platform becomes visible here for the first time, and it is the thing most
teams get wrong. Execution is asynchronous. The Trade REST API answers before the fill exists.
An interface that renders the response to `POST /api/v1/orders` as the outcome shows `NEW` and
stops, and the team goes looking for a defect in the Trade Executor that is not there.

## A short week

Monday carries self-directed SRE content and Friday is Gandhi Jayanti, so this sprint runs to
four taught days and the first of them is not spent in this folder. The order of the work
decides whether it fits. Stand the workspace up and generate the clients first, then sign-in,
because every other screen needs a token. Then the order ticket with the catalogue rendering,
then the blotter. Configure Playwright as soon as sign-in works: the journeys need your whole
stack up, and finding that out on Thursday costs you the deliverable.

## What you deliver

| Deliverable | Where it lives |
|---|---|
| Typed clients generated from both contracts, committed | one directory of your own naming |
| Sign-in, dashboard, order ticket and blotter | the feature tree you design |
| One interceptor attaching the bearer token | the file you choose |
| Route guards and the redirect | the tree you design |
| Every catalogue code mapped to a readable message | one file or directory of your own naming |
| Unit tests, including the two named interceptor cases | beside the code, as `*.spec.ts` |
| Two Playwright journeys | your end-to-end directory |

## The engineering contract

No workspace scaffold and no starter code ships. Set one Angular workspace up in this folder
and decide for yourself how it is decomposed and where each rule lives, which is most of what
this sprint assesses. Nothing below dictates a file layout. Ten things are fixed, because your
reviewers and your teammates depend on them.

- One Angular workspace rooted here, on Angular 21, where `npm ci`, `npm run build` and
  `npm test` all succeed on a machine that has never seen your code. Commit
  `package-lock.json`. Node 20.19, 22.12 or 24 and above: Angular 21 refuses to start below.
- Standalone components and signals throughout. No `NgModule`, anywhere. The observables stop
  at `HttpClient`.
- Sources under `src/`, or under a directory of your own naming, with the specs as `*.spec.ts`
  beside the code they cover.
- Typed clients generated from `contracts/`, never hand-written, with the generator and its
  version pinned in a committed configuration file. Document the generation command in a README
  of your own here.
- That generated output committed rather than ignored, regenerated on every contract change,
  and never edited by hand.
- One functional interceptor, registered once, with a spec covering the attach case and the
  do-not-attach case, each test named for what it asserts.
- Route guards on every route but the sign-in route, redirecting and carrying the return
  address.
- An order ticket that validates before submission and renders every code in both catalogues,
  and a blotter with a badge per status that tells a working order from a finished one.
- Playwright configured by you, with the two journeys below in one directory of your own
  naming, reading every address and credential from the environment.

```bash
cd sprint-09-trading-ui
npm install                  # first run, and whenever you add a dependency
npm run build
npm test
```

## The typed clients are generated

Pin the generator version rather than taking whatever resolves today, so that two people on the
team generate the same output. Declare one entry per contract, `trade-api.yaml` and
`auth-api.yaml`, each writing into its own subdirectory of the generated tree. The generator
runs on the JVM. You will have to set `skipValidateSpec`, and you should not switch a
validation off without knowing why:
the generator's 3.1 validator asks for `info.license.identifier`, which the OpenAPI
specification makes optional and the contracts do not carry. The contracts are correct and are
not yours to edit.

When `trade-api.yaml` changes a field, a generated client stops compiling at every call site
that used it, and a hand-written one keeps compiling and starts returning `undefined` at
runtime. That is the whole reason the contract exists.

### Committed, and not style-reviewed

Committed, not git-ignored, and your `.gitignore` says so in as many words. Committing it means
a clone builds with no Java runtime and no network, and means a contract change arrives as a
diff a reviewer has to read. Regenerate on every contract change and commit the result in the
same commit as the code that adapts to it. Regenerate into a scratch directory and diff before
the review: a contract that has moved ahead of the committed client is a stale client, whatever
the build says.

Nobody reviews the formatting or the naming inside that tree. It is machine output, and the
next generation reverts anything you tidy. Never edit a file in there: when the generated shape
is awkward to consume, wrap it in a service of your own outside it. A file inside the generated
tree that the generator did not write is a hand-written client hiding in machine output, and a
generated client that nothing outside the tree imports is a build step rather than a client.

## The interceptor, and the half of it that is a security control

One functional interceptor, registered once in `withInterceptors`, is the only place in this
application that sets an `Authorization` header. Doing it in each service instead means the day
somebody adds a service and forgets is the day a call goes out unauthenticated. The rule has
two halves.

Attach the bearer token to your own platform APIs: the Trade REST API, and the protected route
on the Auth service. Not to `/auth/login`, `/auth/register` or `/auth/refresh`, which are
`security: []` in the contract and take no header.

Attach it to nothing else, and decide by comparing the outgoing URL against the origins you
configured, never by excluding a list of hosts you happened to think of. An allow list fails
closed when somebody adds a new third party. A deny list fails open, silently, on the day
somebody adds one you did not list.

The second half is the security control. An interceptor that adds the header to every outbound
request hands a live session token to whatever host that request was going to. The token is a
bearer credential: whoever holds it is the customer until it expires. It arrives in that third
party's access log, their analytics pipeline and their error tracker, and it stays in all three
long after your fifteen minutes are up. That is a reportable security incident with a named
customer attached, not a bug to fix next sprint. The Fauxnance API is the case closest to hand,
and the rule is about every host that is not yours.

Two unit tests are assessed by name: one that a request to your API carries the header, one that
a request to a third-party origin does not.

## Route guards

The sign-in route is the only route an unauthenticated visitor may reach. Every other route
runs a guard, and a signed-out visitor is redirected to it carrying where they were going. Do
not render an empty screen instead: a user who has been told nothing will retry, then raise a
ticket. Accept that return address only if it is a path on this origin, because a parameter the
user controls and you follow without checking is an open redirect, and an open redirect on a
trading login page is a phishing kit somebody else assembles for free.

Say this out loud once, because it is asked at the review: the guard is a usability control,
not a security control. The bundle is public and every route in it is readable. Authorisation
is the Trade REST API's decision, taken on every `/api/v1/**` call.

## The order ticket

Validate before you submit. Quantity is a whole number greater than zero. Price is greater than
zero with at most two decimal places. The symbol matches the shape the contract allows. The
account is the one the token says this session may trade, rendered read-only, because an
account field the user can edit is an authorisation decision moved into the browser.

Client-side validation is not enforcement. Business rules 1 to 8 live in the Trade REST API and
stay there. The form exists so that the obvious mistakes never reach the wire; the error
rendering exists because the rest of them will.

### Rendering the catalogue is a deliverable

Both contracts return one envelope, `{ "errorCode": ..., "message": ... }`. Branch on
`errorCode`. Never branch on the `message`, which is written for a developer reading a log and
changes without notice, and never show it to a trader as the explanation.

Every code in the two catalogues gets a rendering. All eight of them.

| Code | Contract | What the user has to be told |
|---|---|---|
| `ACC-404` | trade | The account could not be found |
| `ACC-403` | trade | This account is not active, or is not the one this sign-in may trade |
| `INS-404` | trade | The instrument is not one that can be traded |
| `ORD-400` | trade | There is not enough cash for this order |
| `ORD-409` | trade | Not enough of the holding to sell, or this order has already been placed |
| `VAL-422` | both | A field is not acceptable |
| `AUTH-401` | both | The session has expired or the sign-in was refused |
| `AUTH-409` | auth | That username is already taken |

The wording above is the meaning, not the copy. Write sentences a trader can act on.

Two cases are in neither catalogue and still reach the screen: a response the browser never
received, which arrives as status 0 and is usually a service that is down or a CORS rule that
does not allow your dev server origin, and a code you have never seen, which needs a fallback
sentence rather than a blank panel.

Treat this as a mapping with a completeness property, not as a switch statement you extend when
somebody reports a blank screen. Read the codes out of the two contracts and check every one of
them against your mapping.

## The blotter

Every order for the account, newest first, rejections included. A blotter that hides rejected
orders is worse than no blotter: the rejection is the record that the desk tried and was
refused, and it is the first thing anyone looks for when a customer rings.

Four statuses, four badges: `NEW`, `FILLED`, `REJECTED`, `CANCELLED`. Each badge carries the
word as well as the colour, because roughly one man in twelve cannot separate red from green.

### An order sitting at `NEW` is normal

`NEW` is the working state. The Trade REST API validated the order, wrote it and published it,
and the Trade Executor has not resolved it yet. Nothing is lost. It is not an error state, not
a stalled request, and not a defect in Sprint 7.

The screen therefore cannot be a snapshot taken once. Something has to bring the row up to
date: re-reading order history on an interval while anything is at `NEW`, a refresh the user
can press, or both. Neither contract offers a push channel to the browser.

Bound whatever you choose and be able to defend the numbers. An interval that never stops is a
request every two seconds for as long as the tab is open, which is a load test you did not mean
to run. Stop when nothing is at `NEW`, stop after a sensible number of attempts, and say on
screen that the order is still working rather than pretending it has finished. Re-read order
history to do it. Never re-post the order: the same idempotency key returns `ORD-409`, and a
new key places a second order.

## The Playwright deliverable

Two journeys against your running stack, one file each, in a directory of your own naming.

| Journey | Suggested file | Covers |
|---|---|---|
| Sign in | `e2e/login.spec.ts` | The guard redirect, a refused sign-in, a successful sign-in, arriving where you were going |
| Place an order | `e2e/place-order.spec.ts` | The read-only account, a rejection before submission, a placed order and whatever status came back |

Two is the assessed set for this cohort, and this is a four-day week. A third journey over the
blotter is worth writing if the time is there, and it is worth nothing against the criteria if
it is not.

These run against your real services, because an end-to-end test that talks to a stub proves
nothing about integration. Each journey starts from a clean sign-in and leaves nothing behind
that another journey needs. Playwright gives each test a fresh browser context, so this rule
gets broken with shared state on your side: a token stashed in a module variable, an account
seeded by one spec and read by the next, an order a blotter spec expects because the order spec
placed it. Run each file in its own process before the review, so that a journey which only
passes when its neighbour ran first fails on your machine rather than in front of your
instructor.

Order-placement assertions accept `NEW`, `FILLED` or `REJECTED`. A spec that asserts `FILLED`
fails the week the executor is switched on, which is the wrong signal from a test.

Read every address and credential from the environment, under these names, so that every spec
stays on one set: `E2E_BASE_URL`, `E2E_TRADE_API`, `E2E_AUTH_API`, `E2E_USERNAME`,
`E2E_PASSWORD`, `E2E_ACCOUNT_ID` and `E2E_SYMBOL`. Give the sign-in form's username field,
password field and submit button a stable `data-testid`: a test that finds a control by the
text on it breaks the first time somebody rewrites the label.

## Nothing secret in the bundle

`npm run build` produces files that every browser downloading this application receives. There
is no private part of a front-end build. Minification is not obfuscation, and a `.map` file is
the source back again. Three things must not appear in the output. Search the built files for
each of them before the review.

| Pattern | Why |
|---|---|
| `x-api-key`, `api_key`, `api-key`, `fauxnance` | A market-data key in the bundle is a key published. Revoke it, do not delete it |
| An `execute-api.<region>.amazonaws.com` host | This application never calls the market-data API. Prices reach the browser through your own services |
| `jwt_secret`, a secret assigned a long literal, a three-part JWT written into source | A signing secret in the browser lets any reader mint a token the whole platform accepts |

Search the bundle for the literal values of your own key and your own signing secret as well.
That catches a value pasted in under a name none of those patterns would match.

The rule underneath all three: the Angular application never calls the Fauxnance API. Prices
reach the browser through a service of yours that holds the key server-side.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. Sign-in works end to end against the real Auth service.
2. The interceptor attaches the bearer token to every platform API call, and attaches it to no
   Fauxnance or third-party call.
3. Route guards block unauthenticated access and redirect.
4. The API clients are generated from `contracts/`, not hand-written.
5. The order ticket validates before submission.
6. Every error code in the catalogue renders as a readable message.
7. The blotter shows status badges and handles an order sitting at `NEW`.
8. Playwright covers signing in and placing an order, each journey standing on its own.
9. No API key and no secret is present in the built bundle.

## Evaluation

This sprint contributes 13 marks to the 100-mark Capstone assessment. The API contracts are
inputs. Marks are awarded for the workspace, application and evidence the team produces.

| Criterion | Marks |
|---|---:|
| Required screens, reactive validation and asynchronous order states | 3 |
| Sign-in, token handling, interceptor and route guards | 3 |
| Generated clients and working account and order integration | 3 |
| Clear loading, success and error states, with basic accessibility | 1 |
| Unit tests, independent Playwright journeys and bundle secret scan | 3 |
| **Sprint total** | **13** |

## The review

Your instructor assesses this sprint by reading the code against the criteria above and by
driving the running application. Whether your messages are readable by a trader, whether the
interceptor decides by origin rather than by a list of hosts somebody remembered, whether the
blotter tells a working order apart from a stalled one, and whether a value could reach the
browser by a route no search can see are all read rather than counted.

Bring to the review: the three services up and the application signed in against the real Auth
service, a clean browser sent straight at a guarded route so the redirect can be watched, a
recording of the requests one signed-in page makes showing where the bearer token went and
where it did not, each of the eight catalogue codes rendered as a sentence a trader can act on,
an order left sitting at `NEW` and the screen bringing it up to date, both Playwright journeys
run one file at a time, and the built bundle searched in front of the panel for a key and a
secret.
