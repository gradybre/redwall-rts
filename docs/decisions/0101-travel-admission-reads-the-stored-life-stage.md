# 0101 — Travel admission reads the stored life stage, and a lie about it is its own refusal

Date: 2026-09-12 · Status: **Accepted**

[MOVE-DEP-R02](../rulings/2026-09-12_movement_dependency_rulings.md) states that
"movement admission reads the resident's actual stage and matches the profile; an
`Admission.life_stage` caller value cannot override it."
`godot/scripts/core/movement.gd` did not do that. It compared the caller's own
assertion against its local `LIFE_STAGE_ADULT`:

```gdscript
if admission.life_stage != LIFE_STAGE_ADULT:
	return REFUSE_LIFE_STAGE
```

`Admission.life_stage` arrives through `set_terms(profile, stage, travel_mode,
load_g)` and is caller-supplied, so a caller that passed ADULT for a resident
whose stored stage is CHILD was believed. Every existing caller passes ADULT.
The check therefore refused only callers that were already telling the truth
about a non-adult, and admitted every caller that was not — the exact inversion
of the ruling's sentence.

This was defensible when it was written: `residents.gd` had no life-stage column
at all, and the module said so. [Decision 0095](0095-the-resident-stage-column-and-the-logical-rig-binding.md)
landed `_life_stage:B8[512]` with `life_stage_of(slot)` and
`life_stage_of_ref(ref)`. There is now something to read, and `_residents` was
already a member of `movement.gd` — the very next line of the same function uses
it for `species_of`.

## Decision

1. **The stored stage is the authority; the caller's copy is evidence, checked
   against it.** `_refuse_life_stage()` reads
   `_residents.life_stage_of_ref(resident)` — the generation-checked reader, in
   the **directory's** generation namespace (`entity_directory.gd`'s
   `_generation` on the directory slot), not `inventory.gd`'s container/lot
   spaces and not `navigation.gd`'s descriptor space. The caller's value is
   never the thing compared against the profile.

2. **A caller that disagrees with the store is a DISTINCT refusal from a
   resident that is legitimately unprofiled.** This is the question this record
   was asked to settle, and the answer is *distinct*, on four grounds:

   * **They have different owners.** A caller passing CHILD for a CHILD row is
     correct code meeting a missing feature: PC-04 owns the dependent needs,
     care, schedule, work and hazard rules a non-adult journey would have to be
     admitted under, and none of them exist. A caller passing ADULT for a CHILD
     row is a defect in the caller. One refusal code for both names the wrong
     owner half the time, and it is the half that is a privilege-escalation-
     shaped bug rather than a backlog item.
   * **They have different lifetimes.** `LIFE_STAGE_NOT_PROFILED` is expected to
     disappear when PC-04 lands and child profiles are published.
     `LIFE_STAGE_DISAGREES_WITH_RESIDENT` must never be reachable in correct
     code and should stay at zero occurrences forever. Counting them together
     would hide the second inside the first's expected volume.
   * **MOVE-REQ-018 already requires the distinction downstream.** The UI must
     distinguish "planning, waiting for access, incompatibility and lack of an
     exit using text as well as color". An incompatibility the player can act on
     and an internal inconsistency the player cannot are not the same message.
   * **It is what makes the fix testable.** If both produced
     `LIFE_STAGE_NOT_PROFILED`, a test could not tell the fixed code from the
     broken code on a CHILD row, because the broken code also refuses a *truthful*
     child. Mutation `M7` in this work reorders the two checks so the mismatch is
     reported as a missing profile, and it is killed by exactly one assertion.
     Collapsing the codes would have made that mutation equivalent.

   The order is: unreadable, then out-of-domain, then disagreement, then
   unprofiled. Disagreement is checked **before** the profile match, so a caller
   that lied about a child is told it lied rather than being handed the
   feature-gap code.

3. **Four refusal codes, none of them a sentinel value.**

   | Constant | StringName | Means |
   |---|---|---|
   | `REFUSE_LIFE_STAGE_UNREADABLE` | `RESIDENT_LIFE_STAGE_UNREADABLE` | the store would not answer: stale, wrong-kind or unoccupied row |
   | `REFUSE_LIFE_STAGE_RANGE` | `LIFE_STAGE_NOT_IN_ENUM` | the caller's value is outside `residents.gd`'s 0..2 |
   | `REFUSE_LIFE_STAGE_MISMATCH` | `LIFE_STAGE_DISAGREES_WITH_RESIDENT` | a valid stage, but not this resident's |
   | `REFUSE_LIFE_STAGE` | `LIFE_STAGE_NOT_PROFILED` | the resident's own stage has no starter profile |

   `REFUSE_LIFE_STAGE`'s name and value are **unchanged**, so no other owner's
   string comparison moves under it.

4. **An unreadable stage refuses; it does not default.** `IntMath.IntResult`
   documents that `refuse()` zeroes the value "so an ignored refusal cannot
   surface an earlier operation's number as if it were this one's answer". Zero
   is ADULT. Reading `.value` without checking `.ok` would therefore admit every
   unreadable resident as an adult — the same shape as the `-1` overflow
   sentinel this repository has already been bitten by. Mutation `M4` deletes
   the `.ok` check and is killed.

5. **`movement.gd` no longer defines the adult encoding.**
   `const LIFE_STAGE_ADULT: int = ResidentsScript.LIFE_STAGE_ADULT` aliases the
   store's constant instead of writing `0` a second time. `LIFE_STAGE_COUNT: int
   = 1` is **deleted**: it meant "how many stages this module profiles", which is
   one character away from `residents.LIFE_STAGE_COUNT = 3` meaning the domain
   bound, and the profiled set is now a per-profile table rather than a count.
   Nothing outside `movement.gd` and `test_movement.gd` referenced it.

6. **`PROFILE_LIFE_STAGE` is a const table, not a packed column — because the
   packed column is blocked.** See below. It is one entry per `PROFILE_KEYS`
   row, in the same order, all ADULT, and the admission compares the stored
   stage against `PROFILE_LIFE_STAGE[profile_id]`, so a future row set to a
   different stage changes behaviour without touching the check.

## What is blocked, and on whom

**`_profile_life_stage:B8[4]` as a packed column** is not implemented. It is not
a judgement call that it should not exist; it is that landing it fails CI from
this agent's file allowlist:

`docs/validation/state_registry_coverage.py` check **C3** requires every packed
column declared under `godot/scripts/core` to appear in exactly one row of
`docs/persistence_state_registry.md`. Verified by experiment on this branch:
adding `var _profile_life_stage: PackedByteArray` and changing nothing else
turns `PASS -- 44 modules, 315 rows, 630 packed columns checked` into
`FAIL C3 movement.gd declares '_profile_life_stage' with no registry row`,
exit 1. `docs/persistence_state_registry.md` is owned by the persistence lane,
which is editing it concurrently. The row also cannot be folded into the
existing `StarterGroundProfile catalog` row: check **C5** compares the registry's
element width against the declared GDScript type, and that row's width is 4
while a `PackedByteArray` column is 1.

The ruling's semantics are met in the meantime — a per-profile, immutable,
compile-time stage binding, which the ruling itself describes as "catalog/profile
metadata is immutable binding, not another mutable life-stage authority". What is
deferred is the **storage shape and its four bytes**, not the behaviour.

Three rows are owed by their owners before the column can land. None of the
three files is touched by this work.

**`docs/persistence_state_registry.md`**, in the `godot/scripts/core/movement.gd`
section, a new row beside `StarterGroundProfile catalog` and
`StarterGroundProfile revisions`:

| Row | Members | Width | Count | Null/unused | Category | Save section |
|---|---|---|---|---|---|---|
| StarterGroundProfile life stage | `_profile_life_stage` | 1 | `PROFILE_COUNT` = 4 | unpublished rows hold 0, which is also ADULT; `_profile_revision` is what distinguishes them | 2 | §2 CATALOG_IDS |

**`docs/systems_architecture.md` §2.3.** `StarterGroundProfile` has **no row at
all** yet — decision 0083 owes it, and `movement.gd`'s header has carried that
gap since. The four bytes belong **inside that owed row**, not in a new
allocation row: it is a seventh column on an existing four-row table, so the
allocation count does not move.

```
StarterGroundProfile, 6 I32 columns x 4 bytes x 4 rows          = 96 bytes   (owed, decision 0083)
                    + 1 B8  column  x 1 byte  x 4 rows          =  4 bytes   (this record)
                                                          total = 100 bytes
```

The running total `movement.gd`'s header owes §2.3 and
`ready07_arithmetic.py` therefore moves from
`2048 + 10240 + 96 = 12384` to `2048 + 10240 + 100 = 12388` bytes when the
column lands. It stays **12384** today, because no byte is claimed for a column
that does not exist.

**`docs/validation/ready07_arithmetic.py`**: when the §2.3 rows land, its
decision-0083 term becomes `DECISION_0083_ADDED=(5*4*512)+(6*4*4)+(1*1*4)`,
i.e. `10336 + 4 = 10340`. It is **not** changed now: the script asserts against
the rows actually printed in `systems_architecture.md`, and both must move
together or it fails.

## What this does not do

* It does not enable non-adult travel. A CHILD or ELDER resident refuses, by
  design, until PC-04 publishes the needs, care, schedule, work and hazard rules
  that a dependent journey would be admitted under.
* It does not close MOVE-G01, G02, G04 or PC-04, and it invents no clearance,
  envelope, air budget, path cost or depth. `profile_clearance_class_into()`
  still refuses for every profile.
* It introduces no stage change during an active route, which MOVE-DEP-R02
  explicitly excludes. `_advance_row()` is unchanged.
* It does not persist or hash anything. No save module exists.

## Evidence

Full suite on this branch: **3405 test(s), 122669 assertion(s), 0 failure(s)**.
`ready07_arithmetic.py`, `state_registry_coverage.py` and `decision_numbers.py`
all exit 0.

Seven mutations, one per Godot invocation, each restored and `shasum -a 256`
byte-compared, failure counts parsed as integers:

| # | Mutation | Verdict | Failures |
|---|---|---|---|
| M1 | restore the pre-fix body: trust `admission.life_stage`, read nothing | KILLED | 4 |
| M2 | stored stage need not match the profile's stage | KILLED | 2 |
| M3 | the otter profile silently covers ELDER | KILLED | 6 |
| M4 | an unreadable stage falls through on the zeroed value | KILLED | 1 |
| M5 | drop the 0..2 domain check on the caller's value | KILLED | 1 |
| M6 | `life_stage_of(get_typed_row(ref))` instead of `life_stage_of_ref(ref)` | **SURVIVED** | 0 |
| M7 | check the profile match before the disagreement | KILLED | 1 |

**M6 survives and the reason is recorded rather than waved away.** The two
readers differ only for a reference the directory rejects, and `begin_travel()`
calls `_motion_row()` — which is `is_valid_of_kind(ref, KIND_RESIDENT)` — before
`_refuse_admission()` runs, so no such reference reaches the stage check through
this entry point; the `is_present` half is covered by the orphan-reference test.
The equivalence is a property of the **caller**, not of `_refuse_life_stage()`,
so the generation-checked reader is kept: a later reordering of the admission
checks would turn the slot-addressed read into a live hole with no test to catch
it. No test is added for it, because adding public API purely to make a mutation
die would be inventing surface this increment does not own.

## Tests

`godot/test/test_movement.gd` replaces
`test_travel_refuses_a_life_stage_that_is_not_the_profiled_adult` — its only
assertion about a caller-supplied stage tested the defect, and it asserted the
now-deleted `LIFE_STAGE_COUNT == 1`. **Its case is not lost**: an adult row with
a non-adult caller value is still tested, in
`test_a_caller_that_asserts_the_wrong_stage_for_an_adult_disagrees`, and now
expects `REFUSE_LIFE_STAGE_MISMATCH`. Eight tests cover the fix: the encoding
alias, the per-profile ADULT binding, ADULT-asserted-for-a-CHILD, a truthful
CHILD, an ELDER, a wrong assertion on an adult, out-of-domain values including
`-1` and `256`, and a directory reference the resident store will not answer for.
