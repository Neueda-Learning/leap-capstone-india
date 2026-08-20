# Fixtures

Canned `GET /candles/{symbol}` responses. Tests read these instead of calling
the Fauxnance API, so the suite runs with no network, no key and no cost
against your daily quota. A test that fails only when the API is slow is a test
nobody trusts.

The envelope matches the `CandlesResponse` schema published at `/v1/docs` on
the Fauxnance base URL: a `data` object carrying `symbol`, `interval`,
`currency` and a `candles` array, and a `meta` object carrying `asOf`,
`disclaimer`, `symbol` and `source`. Each candle carries `date`, `open`,
`high`, `low`, `close`, `adjclose`, `volume` and `synthetic`.

| File | Provenance |
|---|---|
| `candles-reliance-ns-2026-07.json` | Nine NSE trading days in July 2026, shaped from the published `CandlesResponse` schema, prices invented. One weekday is absent because the exchange was shut, so the series has a calendar gap. |
| `candles-infy-ns-2026-07.json` | Eight NSE trading days over the same period, shaped from the same schema, prices invented. One candle reports a null volume and one is flagged `synthetic`, both of which the live API does emit. |
| `candles-malformed.json` | A BSE symbol in the same envelope with the payload deliberately corrupted, written for the malformed-input test the acceptance criteria require. Prices invented. |

No fixture contains a real key, and no fixture was captured with one. The
values are made up, so do not read a market conclusion out of them.

## What is wrong with the malformed fixture

Six defects, each one a thing the live API or an upstream vendor has produced
at some point:

1. `2026-07-01` appears twice, with two different closes.
2. The `2026-07-02` candle has no `close` field at all.
3. The `2026-07-06` candle carries the string `"n/a"` where a number belongs.
4. The `2026-07-07` candle has a high below its low.
5. The `2026-07-08` candle reports a negative volume.
6. The last candle dates itself `09/07/2026`, which is not an ISO date.

Your transform decides what happens to each one. Dropping a row, quarantining
it, or raising an error are all defensible, and they are not equally defensible
for all six defects. What is not defensible is loading a row that says a share
traded at a high below its low, and then drawing a chart from it. Whichever you
choose, the behaviour has to be asserted in a test.
