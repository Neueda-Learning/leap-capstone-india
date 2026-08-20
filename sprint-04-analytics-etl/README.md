# Sprint 4: analytics and the ingestion pipeline

The schema you designed last week answers one kind of question. What is this
account's balance. What is open on this account right now. Those touch a
handful of rows, in milliseconds, thousands of times an hour, while orders are
being written to the same tables.

The desk asks a different kind. What did we trade last quarter, by instrument,
by week. Which names moved most, and when. That question reads millions of rows
and aggregates them. Run it against the operational tables and order placement
slows for everybody while it runs, and the answer depends on when you asked,
because the rows are changing underneath the query.

So the two stores live apart: one shaped for correctness under concurrent
writes, one shaped for reading a lot of history at once. Something has to move
data from the first into the second on a schedule, reshaping it on the way.
That something is what you build this week.

## Why the data is market data

The platform's own order flow does not exist yet. The Trade REST API arrives in
Sprint 6 and the Trade Executor in Sprint 7, so the only trades in your database
are the ones you seeded by hand. A pipeline over thirty rows you invented
teaches nothing, and a dashboard over them says nothing.

Market data is available today. The Fauxnance API serves end-of-day candles
going back years. It is authenticated, rate limited, occasionally missing a day
and occasionally wrong, which is what makes it worth building against.

In Sprint 7 you point the same three functions at the platform's own trades and
load the star schema in `contracts/analytics-schema.sql`. The source changes.
The shape of the pipeline, the way it handles a bad row, and the tests around
the transform do not. Build it this week as though the source were going to
change, because it is.

## Symbols and scope

Choose your own universe of symbols, and include at least two NSE or BSE
instruments in it. `INFY.NS`, `RELIANCE.NS` and `TATASTEEL.BO` all price
through Fauxnance, alongside US equities, foreign exchange and crypto. A chart
is easier to sanity-check when you already know roughly what the numbers should
look like, and a claim about a market you follow is easier to defend in the
review.

The build is scoped for the embedded capstone day and the evenings around it.
That is enough for a narrow pipeline done properly. It is not enough for eight
symbols, six charts and a predictive model, so take the smallest scope that
produces three claims you can stand behind.

## What you deliver

| Deliverable | Where it lives |
|---|---|
| The pipeline, as three functions in three modules | your package |
| The Fauxnance client, with the key read from the environment | your package |
| The dashboard, and the chart artefacts it writes | artefacts committed at the paths you name |
| Three business claims, each naming the chart that supports it | `claims.md` |
| pytest over at least the transform, including a malformed-input case | `tests/` |

## The engineering contract

No project skeleton ships with this sprint. Set one up. Four things about it
are fixed, because your teammates depend on them:

- This folder is an installable Python project. `pip install -e
  sprint-04-analytics-etl` works from the repository root on a machine that has
  never seen your code.
- It declares an optional dependency group called `dev` that brings pytest, so
  that `pip install -e 'sprint-04-analytics-etl[dev]'` leaves a teammate able to
  run the suite.
- Extract, transform and load are importable callables in three distinct
  modules of that package.
- `pytest`, run from this folder, finds and runs your suite. Put the tests in
  `tests/`.

Everything else is yours: the package name, the module names, the function
names, the build backend and the dependency set. Be able to name all of them at
the review.

Two constraints on the dependency set are worth knowing now. Sprint 7 extends
this project rather than replacing it, so pick libraries you are willing to
live with for the rest of the programme. And the chart artefacts have to open
without a network, which rules out anything that fetches its own JavaScript at
render time.

The analytical store is DuckDB: one file on disk, no server, no account to
provision. `requests`, `pandas`, `plotly` and `python-dotenv` cover the rest of
the sprint, and nothing beyond `duckdb` forces that set on you.

## What a business claim is

A claim is a sentence about the business that could turn out to be wrong. It
names what is true, of what, over what period, and by how much. Someone reading
it can disagree with it, and going and checking the data would settle the
disagreement.

A chart description is not a claim. It tells the reader what the picture is of
and leaves them to work out whether anything follows.

Worked example, from a consumer electronics retailer rather than a trading
desk, so that nothing here is one of your three:

> **Chart description.** This chart shows monthly complaint volumes by product
> line over the last two years.

> **Claim.** Complaints about the mid-range laptop range doubled in the month
> after the March firmware update and have not fallen back since.

The second names a subject, a magnitude, a direction and a period. It tells a
product manager where to look on Monday morning. The first tells them a chart
exists.

Supported by a chart a non-technical reader can read unaided means what it
says. Both axes labelled, with units. A title that states the finding rather
than naming the variables. No unexplained abbreviation, no ticker without a
company name, no legend entry that only makes sense to the person who wrote the
query. The reader has your chart and no access to you.

Three claims, minimum. State each one in `claims.md` alongside the artefact
that backs it.

## The pipeline

Three steps, three functions, three modules, wired together by a fourth that
does nothing else.

**Extract** obtains raw responses and hands them on unchanged. It is the only
part that needs a key and a network.

**Transform** takes data and returns data. Parsing, typing, cleaning,
aggregating, deriving. It opens no socket, reads no environment variable and
writes nowhere.

**Load** writes the result into the analytical store, DuckDB, and is the only
part that writes.

The split earns its keep the first time a number comes out wrong. One function
that fetches, cleans and writes can only be tested by running the whole thing
against the live API, and it gives you no way to ask which third of it was
wrong.

Cache raw pulls to disk. One symbol over one date range is one request against
a quota of 2000 per day, and a team debugging a chart runs the pipeline twenty
times before lunch. Write the raw response to `.cache/`, keyed by symbol and
range, read it back when it is already there, and re-runs cost nothing. Cache
the raw response and not the cleaned frame: changing the transform is the thing
you will do most this week, and it should not need a fresh pull.

## The key and the quota

The key is read from `FAUXNANCE_API_KEY` and from nowhere else. Copy
`.env.example` at the repository root to `.env`, which is git-ignored, and put
your key there. It is never a literal in source, never in a test, never in a
fixture, never in a notebook you commit. A key that reaches a commit has to be
revoked, and the history keeps it whether or not you revoke it.

The quota is 2000 requests per day per key, and this sprint uses very few of
them. A year of daily candles for one symbol is one request. Eight symbols is
eight requests. With a cache on disk, a full team working all day stays in the
low tens of requests, well inside one person's allowance. A team that runs out
this week has a bug, almost always a pull inside a loop that should have been a
cache lookup.

Check where you stand with `GET /usage` before assuming the API is broken, and
`GET /health`, which needs no key, before assuming anything at all.

## Error handling

A bare `try` around the whole run does not meet the criteria, because it cannot
tell these four apart and they need different answers.

| What happened | How you know | What to do about it |
|---|---|---|
| The daily quota is exhausted | HTTP 429, with `Retry-After` giving the seconds until it resets at midnight UTC | Stop, and say so plainly. Sleeping until midnight inside a batch run is not recovery |
| The request itself is wrong | Another 4xx: 401 for a bad or missing key, 404 for a symbol Fauxnance does not serve, 400 for a range over ten years | Fail this symbol, keep the message, and carry on with the others. Retrying repeats the mistake |
| Nothing reached the service | A connection error or a timeout from your HTTP client | Retry with a backoff that grows, and give up after a small number of attempts |
| The response arrived and is wrong | HTTP 200 with a candle missing a field, a price that is not a number, a high below a low | Not an HTTP problem. This belongs to the transform, and the transform decides between dropping the row, quarantining it and raising |

Log enough that a teammate can tell which of the four happened without rerunning
it. Never log the key.

## Testing

pytest, over at least the transform, including at least one malformed-input
case. That is the floor rather than the target, and a suite of two or three
tests over a transform this size is not coverage.

The suite never touches the network. `fixtures/` holds three canned responses
in the real envelope shape, one of them deliberately corrupted. Read them from
disk in your tests, or wrap them in a pytest fixture of your own.

`fixtures/README.md` lists the six defects in the malformed payload. Decide what
your transform does with each, then assert it. Dropping a row, quarantining it
and raising are all defensible, and they are not equally defensible for all six.
What is not defensible is loading a row that says a share traded at a high below
its low and then drawing a chart from it.

Name the malformed-input test for what it asserts, so that
`test_rejects_a_high_below_a_low` can be run and read on its own.

## The dashboard

One artefact per claim, or one file holding all three charts, committed either
way. plotly can inline its own JavaScript, so an HTML report opens with no
network and no build step. A dashboard that only exists while a notebook kernel
is running cannot be assessed, and a chart that loads its library from a content
delivery network is a blank page on a locked-down machine.

Name the artefacts in `claims.md`. Where one file holds several charts, point at
the chart inside it with a fragment, for example `report.html#weekly-turnover`.

## How you work

From the repository root, once your project has packaging metadata in this
folder:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e 'sprint-04-analytics-etl[dev]'
.venv/bin/python -m pytest sprint-04-analytics-etl
```

That install has to work from a clean environment on a teammate's machine, not
only on the laptop the code was written on. Run it that way at least once before
the review.

Give the pipeline an entry point a teammate can run without reading the source,
either a console script declared in your packaging metadata or a module with a
`__main__` block, and say which in a note at the bottom of `claims.md`.

Write the transform tests as you write the transform, not on the last evening.
The malformed fixture is in the repository from day one for that reason.

## Acceptance criteria

These are the criteria your instructor assesses against.

1. Three or more insights, each stated as a business claim and supported by a
   chart a non-technical reader can read unaided.
2. Fauxnance candles pulled through `GET /candles/{symbol}`, with the key read
   from the environment.
3. The pipeline is separated into extract, transform and load functions.
4. pytest covers at least the transform step, including one malformed-input
   case.
5. Rate-limit and error handling are present, and not a bare `try` block.
6. The symbols in scope include at least two NSE or BSE instruments.

## Evaluation

This sprint contributes 8 marks to the 100-mark Capstone assessment. The
contracts, the candle fixtures and the `claims.md` template are inputs. Marks
are awarded for the analysis, pipeline and evidence the team produces.

| Criterion | Marks |
|---|---:|
| Data preparation and defensible exploratory analysis | 2 |
| Three valid business claims with readable charts | 2 |
| Separated, repeatable extract, transform and load pipeline | 2 |
| pytest coverage, malformed-input handling and output validation | 2 |
| **Sprint total** | **8** |

## The review

Whether the claim holds, whether the chart supports it, whether a reader outside
your team could read that chart unaided, whether the symbols you pulled meet
criterion 6, and whether your error handling is four cases or one bare `try` are
assessed by your instructor, reading your code and your `claims.md` against the
criteria above.

Bring to the review: the three claims, the charts, the numbers behind one of
them traced back to the rows they came from, your transform's decision on each
of the six defects in the malformed fixture, and the answer to "what would have
to be true for this claim to be wrong".
