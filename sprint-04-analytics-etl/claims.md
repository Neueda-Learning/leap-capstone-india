# Claims

Three claims, minimum. One row each. Replace every CHANGE_ME.

A claim is a sentence about the business that could turn out to be wrong. It
names what is true, of what, over what period, and with what magnitude. It is
not a description of a chart, and it is not a question. If a reader can
disagree with it, it is a claim. See the sprint README for the worked example.

The chart artefact is the path to the file holding the chart that supports the
claim, relative to this folder. Where one file holds several charts, point at
the chart inside it with a fragment, and the file has to be committed either
way.

| # | Claim | Chart artefact |
|---|---|---|
| 1 | CHANGE_ME | CHANGE_ME |
| 2 | CHANGE_ME | CHANGE_ME |
| 3 | CHANGE_ME | CHANGE_ME |

Filled in, a row looks like this. The claim is invented and out of domain
deliberately, so that copying it gets you nothing. It is numbered `x` rather
than with a digit so that nobody mistakes it for one of yours:

| x | Complaints about the mid-range laptop range doubled in the month after the March firmware update and have not fallen back since. | report.html#laptop-complaints |

Add rows past the third if you have more, numbered in sequence. Every artefact
named in this table has to exist in the repository. Whether the claim is true,
whether the chart supports it, and whether a non-technical reader can read the
chart
unaided are assessed by your instructor.

## Notes

Use this space for anything a reviewer needs in order to trust the numbers:
the date range you pulled, the symbols in scope, what your transform did with
the rows it rejected, and any claim you started to make and then withdrew
because the data did not support it. A withdrawn claim with its reasoning is
worth more in the review than a fourth weak claim.

Say here how a teammate runs your pipeline, whether that is a console script
declared in your packaging metadata or a module with a `__main__` block.
