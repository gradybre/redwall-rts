# 0149 — A prohibited entry and a preserved rescue are different rows
Date: 2026-09-15 · Status: Accepted

## Decision

[MOVE-C3-R01](../rulings/2026-09-14_cycle03_movement_policy.md) is applied to the Q2 readiness
register. The register now separates four things it previously ran together, and
`tools/test_movement_profile_policy.py` enforces the separation as executable checks over the
register's own `validator_rules`.

**1. Child hazardous *entry* is prohibited; recovery and rescue of a child already in danger is
preserved, and the two are not the same row.** 32 rows — 16 species × {`SWIM_SURFACE`, `DIVE`} at
`CHILD` — become `explicitly_disabled` under a new `PROHIB-CHILD-HAZARDOUS-ENTRY`. Recovery is
recorded as `recovery_is_not_entry` and is deliberately **not a leaf in `rows` at all**: a child
being rescued from water is not a child entering water, and no state in the traversal matrix should
be able to represent it as one. The prohibition is explicitly a *new-entry* restriction, carries an
explicit `cannot_be_overridden_by` list (consent, a direct order, an escort's presence, a skill
value, a caller boolean), and states that rescue grants no child voluntary mode and creates no child
rescue job.

**2. Climb protection is a property of the connection, not a seventh mode.** The 16 `CHILD` `CLIMB`
rows are **not** disabled. `RC_CHILD_HAZ`'s unconditional grouping of the whole mode is replaced by
`RC_CHILD_CLIMB_CONDITIONAL`, whose `climb_action_variants` record the unprotected case as
prohibited and the protected case as permitted nonproductive access subject to a complete child
profile. The whole-row state stays `unresolved_q2`, because the variant the policy permits has no
published profile. The six compiled mode ids are untouched.

**3. A disabled row still names the admission contract it independently fails.** The prohibited
`CHILD` water rows keep `blocking_contract: BC-PC04`, with a note saying in terms that clearing that
contract would not lift the prohibition. A reader who satisfies the contract does not thereby earn
the row, and a reader who reads the prohibition does not conclude the profile is unnecessary.

**4. A missing definition is not an authored inability.** `PROHIB-SITUATIONAL` keeps only genuine
authored prohibitions. The absence of a float/return posture, an airless-recovery binding, a
breathable-endpoint set, a protected-support definition or a fall landing moves to a new
`missing_definitions_not_prohibitions` block carrying the `unresolved_q2` state and its Q2 slot ids.

Four supporting choices go with it:

- **`totals` is a recount, never an edit.** Both the applying script and the test recompute every
  figure from `rows` × `row_classes` independently. Nine separate off-by-one mutations of `totals`
  and one quiet reclassification of a row are each refused.
- **No slot was filled.** All 35 `q2_slots` still hold `value: null`. A settled *policy* is recorded
  as a `cycle3_disposition` with `decision_source`, `settled` and `still_open`, and the validator
  refuses a disposition containing **any** numeric leaf — a smuggled depth, a smuggled speed list.
- **PR123's all-null validator rule is replaced, not deleted.** MOVE-C3-R01's source boundary says
  that constraint "belongs to its proposal lane; it cannot remain the validator rule for the
  subsequently adopted register". Rule 5 now reads "a supplied policy or binding value MUST cite an
  adopted ruling; unresolved numeric and measurement fields remain explicitly empty" — and, because
  this revision supplied nothing, also asserts that every value is still null. Both forms hold.
- **Register schema 2 is this planning file's shape**, not the movement envelope input schema 2 that
  MOVE-C3-R01 §6 adopted under a different owner, and not a save schema version.

## Why

The register had one bucket where it needed three, and the cost of that is not cosmetic. PR123
filed missing float/recovery/support **definitions** alongside known prohibited **actions**, because
at runtime both refuse. But "we have not authored this yet" and "this is forbidden" point at
opposite work: the first is a backlog item with an owner, the second is a decision with a source and
an escape condition. Collapsing them makes unfinished authoring look permanent and makes real policy
look provisional.

The same failure in miniature is the child-rescue case, which is why it gets its own record rather
than a note. The natural way to implement "children may not swim" is a predicate on the traversal
matrix — and a predicate on the traversal matrix will also refuse the rescue path of a child who is
already submerged, because from the matrix's point of view those are the same edge. MOVE-C3-R01 §2
says the prohibition "is a **new-entry** restriction, not immunity, disappearance or a ban on
recovering a child already in danger. Preserve occupancy, air, cargo and injury for an existing
distressed occupant." A register that stored recovery as a *row* would be one careless join away
from freezing a drowning child in place to enforce a safety rule. So recovery is not a row, and the
disabled row says so out loud in `not_covered_by_this_row`.

Keeping `blocking_contract` populated on a prohibited row is the same instinct. The alternative —
`null`, because a prohibition is terminal — reads as "nothing further is needed here", which is
false: no `CHILD` profile exists for any species, and if the DEC-032 boundary were ever revisited the
row would still refuse. It also keeps the register's own rule 6 literally true rather than carved
out, so the invariant that no presentation gap ever gates admission survives with no exception a
later editor could widen.

The 32/16 split matters for the same reason the totals are recounted rather than typed. The ruling
says "do not mark all 48 rows wholly disabled" — the easy, wrong move is one `CHILD_HAZ` class for
everything dangerous, which is exactly what the previous register had. 32 + 16 = 48 is asserted in
the test against a recount, so a future edit that quietly folds the conditional climb rows into the
prohibited count fails rather than passing with a plausible-looking number.

## What this does not decide

No measurement, dimension, cost, speed, air budget, depth or clearance value is authored here.
`invented_values` is still 0 and `admission_qualified` is still 0 for every one of the 288 rows. No
row is `ENABLED`, `answers_q2` is still `false`, and `closes_gates` is still empty — the test refuses
all three if changed.

**MOVE-G01/Q2 remains open** for complete mode and species cost rows, **ADULT and ELDER permissions
for surface swimming, voluntary diving and unprotected climbing**, real source-bound measured
envelopes, support and contact producers, and the associated G02 contracts. Ford semantics are
*authored* but not *enforced*: `movement.gd` still writes `_cursor_mode` once at `_attach_route()`,
and the per-segment field, API and version change belongs to Movement/G02. The 128u water/floor
difference is not a per-species wading depth and the 640u land/floor difference is not a step
capability; both are recorded in the register as explicitly not inferred.

## Consequences

- A later editor cannot fold the 16 conditional CHILD climb rows into the 32 prohibited ones,
  cannot mark a row `explicitly_disabled` without naming a real prohibition with escape conditions,
  cannot hand-edit `totals`, cannot put a number in a policy disposition, and cannot relabel
  `BC-RIG` as an admission contract. Each of those is a failing negative test, not a convention.
- Any future ruling that enables a row must arrive with a measured envelope: `admission_qualified`
  is pinned false on every one of the thirteen row classes and on the total, and both are checked.
- Movement/G02 inherits an explicit, written ford contract to implement per segment, including the
  statement that old saved route-wide labels must not be silently reinterpreted.
- PC-04 inherits an answered policy with an unanswered profile: it must enforce the child action
  context with no adult fallback, and publishing a CHILD profile does not by itself open any water
  row.

## Source

[MOVE-C3-R01](../rulings/2026-09-14_cycle03_movement_policy.md) 1-5 and 7;
[Cycle 3 report](../planning/astra_cycles/cycle_03.md) "Movement progress and the new defect";
[DEC-032](../setting_decisions.md#dec-032--adopted-dependent-resident-family-model);
[MOVE-C2-R01](../rulings/2026-09-14_cycle02_movement_envelopes.md) for the three catalog meanings;
[MOVE-DEP-R03](../rulings/2026-09-12_movement_dependency_rulings.md) for the presentation/admission
split; `godot/scripts/core/needs.gd` for the two denominators named in the Q2-15 correction.

## Alternatives considered

**A fourth catalog state meaning "policy-approved, profile pending".** Rejected — MOVE-C3-R01 §5
forbids it by name, and it would put a planning disposition into a domain that three runtime
meanings already partition. The positive permission is instead a separate row field,
`ordinary_access_policy`, carried by 144 rows that all remain `unresolved_q2`.

**Deleting the prohibited rows from `rows` rather than marking them disabled.** Rejected: the leaf
count is the invariant the whole register is checked against, and a disposition that is absent is
indistinguishable from one that was never considered.

**Leaving rule 5 as "every value must remain null".** Rejected on the ruling's explicit instruction.
Keeping it would have been safe today and wrong in six months, when the first real measured value
arrives and the honest rule — cite your ruling — is the one that must already be in place.
