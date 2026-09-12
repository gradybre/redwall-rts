# Decision log

One file per decision that would otherwise live only in someone's head or in a
chat transcript. Numbered, append-only, never deleted — a decision that turned
out wrong gets a **Superseded by** line and stays, because the reasoning is what
future readers need.

**Write one whenever you decide something that a later reader could reasonably
undo by accident.** Anchoring a scale, picking a library, rejecting an approach,
discovering a tool behaves unexpectedly. If a future agent could plausibly do
the opposite thing without knowing why it is wrong, it belongs here.

## This is not the only decision log, and the split has cost us

**`NNNN` records live here. `DEC-nnn` records live in
[`docs/setting_decisions.md`](../setting_decisions.md).**

This directory holds *engineering* decisions — what an agent or the executor
settled while building something. `setting_decisions.md` holds **Brendan's own
decisions**: creative direction, approvals, and answers to open questions. The two
numbering schemes are independent and `DEC-017` has nothing to do with `0017`.

Nothing said so until 2026-09-12, and it cost a real audit: a planner review
looked here for **DEC-039**, the approval of the five species' proportions, could
not find it, and correctly reported the approval as *"source not located"* — while
it sat in `setting_decisions.md` all along. An auditor searching the decision log
for a user decision will come up empty **every time**, so say which log you mean
when you cite one.

Format:

```markdown
# NNNN — Short title
Date: YYYY-MM-DD · Status: Accepted | Superseded by NNNN

## Decision
One or two sentences. What was decided.

## Why
The reasoning, including what was rejected and why.

## Consequences
What this forces or forbids later.

## Source
Where the authority comes from — a document section, a measurement, a user call.
```

Keep them short. A decision record nobody reads is worse than none.
