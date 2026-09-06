# Decision log

One file per decision that would otherwise live only in someone's head or in a
chat transcript. Numbered, append-only, never deleted — a decision that turned
out wrong gets a **Superseded by** line and stays, because the reasoning is what
future readers need.

**Write one whenever you decide something that a later reader could reasonably
undo by accident.** Anchoring a scale, picking a library, rejecting an approach,
discovering a tool behaves unexpectedly. If a future agent could plausibly do
the opposite thing without knowing why it is wrong, it belongs here.

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
