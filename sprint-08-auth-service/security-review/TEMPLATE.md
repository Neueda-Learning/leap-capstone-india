# Security review: auth service

Copy this file to one of your own in this folder and fill it in as you build. A
review written the night before the demonstration is a reading of this template
rather than a reading of your service, and it reads that way.

Fill in the header, then every row of the table. Every category carries a
finding and a disposition. Your instructor checks whether they are true.

## Header

| Field | Value |
|---|---|
| Service | auth service, Sprint 8 |
| Reviewed by | |
| Date of review | |
| Commit reviewed | |
| Version of the OWASP Top Ten used | 2021 |

## How to fill this in

**Finding.** What you found when you looked, in one or two sentences. Name the
file or the route. "Login accepts an unlimited number of attempts from one
address" is a finding. "Needs improvement" is not.

**Finding of none.** Allowed, and it requires a sentence of justification saying
what you checked and how you know. "None. Every statement in
`users.repository.ts` and `refresh-token.repository.ts` binds its parameters,
and no statement is assembled by string concatenation" is a finding of none.
The word on its own is indistinguishable from a category nobody looked at, and
it is read that way.

**Disposition.** What you did about it, in the past tense, or what you decided
not to do and why. Four dispositions are useful: fixed, with the commit;
mitigated, with what limits the exposure; accepted, with the residual risk
stated and named as a decision the team took; or out of scope, with the reason
it does not apply to this service.

## Categories

The rows below are the OWASP Top Ten items that bear on an authentication
service. Add rows if your review finds something that belongs in a category not
listed. Do not delete rows: a category with nothing in it is the one worth
asking about.

| Category | In scope | Finding | Disposition |
|---|---|---|---|
| A01 Broken access control | | | |
| A02 Cryptographic failures | | | |
| A03 Injection | | | |
| A04 Insecure design | | | |
| A05 Security misconfiguration | | | |
| A06 Vulnerable and outdated components | | | |
| A07 Identification and authentication failures | | | |
| A09 Security logging and monitoring failures | | | |

### What each category means here

| Category | Where to look in this service |
|---|---|
| A01 | `/auth/me` reading identity from the verified token and never from a parameter the client controls. Self-declared roles on the public registration route. Whether an `ADMIN` role changes what any route will do |
| A02 | The hashing algorithm and its cost factors. The signing algorithm, pinned rather than read from the token. The secret's length and where it comes from. Whether the refresh token is stored as a hash or as itself |
| A03 | Every statement that touches the credential store, and whether each value that arrives from outside is bound rather than concatenated |
| A04 | Refresh rotation and the response to a replayed token. Throttling on the login route. The uniform failure. Registration issuing no tokens. These are design decisions, and their absence is not a defect in any one file |
| A05 | Defaults that work when a variable is missing. The CORS list. What the container runs as. Whether an unhandled fault leaks an exception name or a stack |
| A06 | `npm audit` against your dependency tree, and what you did with what it said. A pinned lock file. Anything you added and stopped using |
| A07 | The whole service, and specifically: identical response and comparable timing for an unknown user and a wrong password, token lifetimes, expiry checked on every protected request, and the minimum password length the contract sets |
| A09 | What a login failure records, what a rotation records, what a replayed refresh token records, and whether any of them records a credential. A service that logs nothing usable cannot answer the questions asked after an incident |

### Two categories deliberately absent

A08, software and data integrity failures, and A10, server-side request forgery,
are not listed. A08 is covered for this service by A06 and by whether your
dependency tree is pinned, and A10 needs the service to make outbound requests
on a caller's behalf, which this one does not. If your implementation added
either, add the row and review it.

## Evidence

List what you actually ran or read, so that the review is repeatable.

| Check | How it was performed | Result |
|---|---|---|
| | | |

## Outstanding items

Anything found and not fixed, with an owner and a date. An empty section here
is a claim that nothing is outstanding, so leave it empty only when that is
true.

| Item | Owner | Target date |
|---|---|---|
| | | |
