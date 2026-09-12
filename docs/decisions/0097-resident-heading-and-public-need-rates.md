# 0097 — Resident heading geometry and published need rates

> **Renumbered on commit, 2026-09-12.** Filed as 0090, which was already held on
> master by [the clock's one validated restore boundary](0090-the-clocks-one-validated-restore-boundary.md).
> Astra and the executor allocate decision numbers from separate sessions with no
> shared counter, so collisions are the expected outcome rather than bad luck. This
> one was caught by [`decision_numbers.py`](../validation/decision_numbers.py) before
> it reached master, which is the difference the gate makes: every collision before it
> was found by hand, late, and cost a renumber plus a link sweep. Only the number changed.

2026-09-12 · Accepted engineering/layout contract; runtime and visual evidence open.

UI-SET-037's280px standalone minimum cannot fit beside the medallion and Close
inside the amended journal. Adopt [UI-IDENTITY-R01 and NEED-RATE-R01](../rulings/2026-09-12_resident_header_and_need_rates.md):
flexible name columns with wrapping/measured header height, plus four owner-
published signed net need-rate readers. Existing hunger decay remains positive
at its API and is negated only by the adapter. All rows display continuous current-
context rates, with explicit cap disclosure and no pause/speed multiplication.

This supersedes the conflicting resident-title minimum and clarifies UXV-020's
rate meaning. It changes neither need formulas nor numerical integration. No
private-state reads, universal baseline substitution, new authoritative cache or
per-resident hot-path reader fan-out is introduced. Generic emblems remain generic;
life-stage/age data must be real. Main source audit and executor reports may differ
while worktrees advance; preserve current implementation and apply the ruling.

The scoped validation records document/arithmetic evidence only. Claude's UI and
needs owners implement and test the change; actual captures remain required.
