# 0128 — The merge gate, and the injury double budget it found

**Status:** accepted. **Date:** 2026-09-12.

## Context

Automatic merging needs a machine to refuse what a human has been catching by
hand. Every defect in this repository's merge history that a green suite did not
catch was an arithmetic or bookkeeping error in the memory ledger, or an agent
report whose exceptions nobody read:

- A lane reported "net +96, it replaces the array it supersedes". The replaced
  array had never been ledgered, so nothing was freed. The true figure was +144.
- A lane reported `wear_remainder` as "either annotate or add a row". It was
  already budgeted inside a ResidentRuntime group, for a store that does not
  exist. Adding it again would have counted one field twice.
- Five separate merges have moved a carried total while dropping or conflating
  the row that justified it, leaving every total internally consistent.
- A lane correctly refused its own brief, citing SAVE-LAYOUT-R01 over the
  instruction it was given. It was right. No script can judge that.

## Decision

`docs/validation/merge_gate.py` refuses an automatic merge on four checks, and
runs in the `contracts` CI job in under a second with no engine and no LFS.

**L1 — trail chain.** Every ARCH-MEM-009 running payload must equal the row
above it plus its own delta, and the reserve column must equal the payload plus
8388608, checked row by row. Comparing totals is what let five merges through.

**L2 — cross-form double budget.** A field written `x` in one ledger row and
`_x` in another is one byte budgeted twice: once under the planned component and
once under the store that implements it. A bare name repeated across owners is
NOT a finding — Building, FarmPlot, Feast, Job and RngStream each legitimately
carry their own `state`. An earlier draft that keyed on the bare name produced
84 false positives and was discarded as useless.

**L3 — row arithmetic.** Width x columns x rows must equal the row's own bytes.

**A1 — agent report.** A report is refused unless it declares `DEVIATIONS:`,
`SURVIVED_MUTANTS:` and `BLOCKED:` and all three are empty. This does not judge
the exception; it removes the change from the automatic path so a human reads
it. A missing block is a refusal, not a pass — a lane that never wrote the
section is exactly the lane whose exceptions would otherwise be invisible.

Exit 0 means "safe to merge without a human reading the arithmetic". Exit 1
means a human must look. It never means the change is wrong.

## The defect found by the first run

L2 fired immediately on master's own ledger. Decision 0109 added all eleven of
`injury.gd`'s packed columns to section 3 as +21504, while section 2.2 already
carried the Injury component's planned rows:

```
| Injury | kind, severity, untreated_hours, rescuer_slot, rescuer_generation | I32 | 4 | 5 | 512 | 10240 |
| Injury | care_progress_mwu | I64 | 8 | 1 | 512 | 4096 |
```

Those 14336 bytes budget the same fields. Section 2.2 is where implemented
component columns live — `residents.gd`'s own `_named` and `_selected` are
there — so the correct repair moves `injury.gd`'s actual layout into 2.2
(5 B8 = 2560, 3 I32 = 6144, 3 I64 = 12288, plus `needs.gd`'s `airless` byte at
512) and reduces decision 0109's trail delta to its **net +7168**.

Corrected figures: section 2.2 is 144 rows totalling 25036642; section 3 is 72
rows totalling 20150752; the allocation rows sum to a payload of **63765395**,
a live world of **72154003**, a candidate of 57549811 and a transactional peak
of **129703814**. `ready07_arithmetic.py`'s `DECISION_0109_ADDED` term now
carries the subtraction with the reason written beside it.

## Consequences

The tool caught an error its own author had made and shipped. That is the
strongest evidence available that it is checking something real, and it is why
the negative case is a first-class test: `test_merge_gate.py` drives all four
checks with the defect they exist for and with a clean input, including the
reduced form of this very double budget. A gate that only ever passes is
indistinguishable from a gate that does nothing.

L2 cannot see a field budgeted twice under two *different* names, and L1 cannot
see a delta that is wrong but self-consistent. Those still need the owning
lane's arithmetic. The gate narrows what a human must read; it does not replace
reading.
