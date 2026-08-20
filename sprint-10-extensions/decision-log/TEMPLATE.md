# 0000 The decision, stated as a sentence

Copy this file to one of your own in this folder, named `NNNN-short-slug.md`
with a number that increases and a slug a teammate can recognise from the
listing: `0003-consumer-group-layout.md`, not `0003-kafka.md`. Write the title as
the decision itself, in the present tense, so that the folder listing reads as a
list of positions rather than a list of topics.

One entry per significant choice. A choice is significant when reversing it later
would cost more than an afternoon, when a reasonable engineer would have chosen
differently, or when somebody asked why during the sprint and the answer took
more than a sentence.

Delete this paragraph and the two above it when you fill the file in. Every
`TODO` below has to go: an entry with a `TODO` left in it is not an entry.

| Field | Value |
|---|---|
| Status | TODO: proposed, accepted, or superseded by NNNN |
| Date | TODO: YYYY-MM-DD |
| Decided by | TODO: who was in the room |

## Context

TODO. What was true when the decision was taken, in three or four sentences.
The constraint that made the choice necessary, the part of the system it touches,
and anything that was already fixed by a contract or by an earlier decision.
Somebody reading this in Sprint 11 was not in the room, so write what they would
need to reconstruct the situation.

Facts here, not preferences. If a number drove the decision, put the number in.

## Options considered

TODO. At least two, each with the case for it and the case against it. An entry
with one option is a record of what you did, not a decision.

| Option | For | Against |
|---|---|---|
| TODO | TODO | TODO |
| TODO | TODO | TODO |

## Decision

TODO. One sentence saying what was chosen, then the reasoning that separated it
from the option nearest to it. Name the thing that decided it. "Neither option
was reversible cheaply, and this one fails in a way we can observe" is a reason.
"It seemed cleaner" is not.

## Consequences

TODO. What this makes easy, what it makes hard, and what has to happen because of
it. Include the cost you accepted, because an entry with no cost in it has not
described a real choice. Note anything this decision now constrains, and any
follow-up work it creates, so that the next entry can refer back to it.
