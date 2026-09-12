# 0109 — The aggregate Injury store, and the one health rate it feeds

Date: 2026-09-12 · Status: **Accepted**

Owners: GDD §4.2's `Injury` row and §4.3's `InjuryKind`, REQ-SET-171/172/173/174,
and [SET-MOVE-ECON-001](../underground_economy_hazard_amendment.md) HAZ-001/002/004
under [DEC-040](../setting_decisions.md). Implements the EH-04 row of the
[handoff](../planning/underground_economy_hazard_handoff.md).

## What was missing

`needs.gd` already carried the health integrator, `apply_health_event()`,
`set_injury_state()` and a three-member `INJURY_*` input whose header said
"Mapping the Injury component's severity onto these is deferred with that
component." The component did not exist. So REQ-SET-172's untreated drain, the
one-shot damage of §5.4 fishing and §5.5 foraging, REQ-SET-173's treatment and
REQ-SET-171's rescue relationship all had a place to arrive and nowhere to live.

`InjuryKind` was **not** missing. GDD §4.3 numbers it `NONE=0, CUT=1, BITE=2,
FALL=3, EXPOSURE=4, EXHAUSTION=5`, and HAZ-001 corrects an earlier review that
said otherwise. No parallel domain was created.

## Decision

`godot/scripts/core/injury.gd` is the aggregate Injury owner: eleven packed
columns, one row per RESIDENT typed row, allocated once in `_init()`.

**1. The drain is a rate term of the existing integrator, not a second clock.**
HAZ-002 says in as many words: "Never run separate rounded health clocks."
`needs.gd` gains two constants and one input column — nothing else about its
integration changed:

```gdscript
const HEALTH_UNTREATED_INJURY_DRAIN_PER_HOUR: Array[int] = [0, 1, 4]
const HEALTH_AIRLESS_DRAIN_PER_HOUR: int = 125
```

They are summed into `_health_rate_per_hour()` alongside starvation, cold and
REQ-SET-017 recovery, and integrated by the same `_integrate_step()` with the
same signed denominator-750 remainder. Untreated severity 2 plus airless is
therefore exactly −129/hour, and HAZ-002's fixtures (6 / 495 / 582 intervals
from 100 give 99 / 15 / 0) hold because the remainder is shared, not because
three drains were separately rounded and added up.

**2. The three-member `INJURY_*` input is the severity mapping, not a fourth
domain.** `needs_injury_state_for()` maps severity 1 to `INJURY_ACTIVE` and
severity 2 to `INJURY_UNTREATED_SERIOUS`. That is the only mapping in the
codebase, and it is why severity 2 both drains 4/hour and bars recovery, which
§5.2 and HAZ-002 each require independently. No `_injury_severity` column was
added to `needs.gd`: the existing three-member input already distinguishes
exactly the two rates REQ-SET-172 publishes.

**3. Death is made final by ordering, not by a later check.**
`complete_treatment()` calls `needs.apply_health_event(slot, +10)` **before** it
clears the aggregate injury. `apply_health_event()` validates through
`_check_live_slot()` and refuses `RESIDENT_DEAD` before writing, so for a
resident at health 0 the function returns at the heal and the clear is never
reached. There is no "was it alive?" re-check that a future edit could reorder
past. HAZ-004: "a completed treatment cannot undo it."

**4. One-shot events are deduplicated by a per-resident ordinal.** HAZ-004
requires one-shot health events to apply "once each; deduplicate by incident
identity/event ordinal". `_last_incident_ordinal` is a monotonic int64 per
resident; an incident whose ordinal is not strictly greater refuses as
`DUPLICATE_INCIDENT`. A replayed hazard roll or a retried job commit cannot
charge the same 20 health twice.

**5. Merging keeps the worst severity and, on a tie, the lower kind ID.**
GDD §4.2's "worse severity replaces, damage still accumulates" plus HAZ-004's
"retain the lower InjuryKind ID deterministically". `_untreated_ticks` and
`_care_progress_mwu` are deliberately untouched by a merge, because HAZ-004
states a new incident erases neither.

**6. `untreated_hours` is stored as ticks.** GDD §4.2 names the field
`untreated_hours:int32`; the column is `_untreated_ticks:int64` and
`untreated_hours_of()` is its floor over 750. This is `needs.gd`'s own
`_starving_ticks` / `starving_hours` pattern: storing ticks makes the counter its
own remainder, so §4.2's `IntegrationRemainders` row does not have to grow an
accumulator it does not provide.

**7. A rescue is a reference, not a cure.** `set_rescuer()` writes only
`_rescuer_slot`/`_rescuer_generation`. GDD §5.2: "a rescue does not clear an
injury until treatment completes." REQ-SET-171's one-casualty limit is enforced
by a bounded ascending scan of the 512 rows; **no reverse rescuer index is
budgeted**, and rescue assignment is an event rather than a per-tick sweep.

**8. A despawn does not sweep rescuer references, and must not.** `rescuer` is an
EntityRef in the **directory's** slot/generation space, while this store is
indexed by RESIDENT **typed row**. `despawn(slot)` cannot identify which stored
references named the departing resident without the directory, and comparing the
two spaces would silently clear the wrong rows. `rescuer_is_live(slot, directory)`
generation-checks instead — which is what generation validation is for.

**9. `required_mwu` is a checked argument, not an invented mode column.**
REQ-SET-173 is 60000 milli-WU and REQ-SET-174's conscious-last-resident
self-treatment is 120000. Which applies is a property of the treatment job, which
this store does not model, so `complete_treatment()` takes the requirement and
refuses anything that is not one of the two published constants. Care work in
progress is a property of the **patient**, so HAZ-004's "changing helpers retains
WIP" costs nothing and needs no transfer.

**10. `_care_context_blocked` is an input with a named unavailable default.**
HAZ-004 forbids treatment work "in active water, on an unsupported climb, during
falling or while being carried". Which of those a resident is in is the movement
owner's fact, so it is an input byte defaulting to 0, exactly as `needs.gd`
treats beds, rooms and weather. No movement state is guessed here.

## Three existing tests changed, and why

`test_health_recovery_is_gated_on_needs_and_untreated_serious_injury`,
`test_exposure_damages_health_only_after_four_hours_and_stops_on_shelter` and
`test_proper_clothing_also_stops_exposure_damage` all used
`INJURY_UNTREATED_SERIOUS` purely as a lever to suppress REQ-SET-017 recovery.
That was correct while REQ-SET-172's drain was in `needs.gd`'s documented GAPS
block. It is not correct now.

- The recovery-gate test keeps the injury and expects **46 rather than 50** after
  an hour. Recovery would have given 52, so the property it tested is still
  proved, and the 4/hour drain is proved with it.
- The two exposure tests switch their recovery suppressant to hunger 3999, which
  is REQ-SET-017's other gate and contributes no health rate of its own (the
  starving value is 0). Their expected numbers are unchanged, so the cold
  arithmetic they exist to pin is untouched.

No test was weakened or deleted.

## What this does NOT establish

- **No scheduler binding.** `injury.tick_all()` exists and installs itself
  nowhere. The phase that pairs it with `needs.tick_all()` is G02/task 08's.
- **No inventory debit.** herb 1000 + cloth 500 milli-U are published constants;
  `inventory.gd` performs the transaction and `complete_treatment()` is called
  only after it commits.
- **No rescue route, carry speed, envelope or landing**, and no HAUL work
  accrual. Those are `movement.gd` (EH-05, blocked) and `work.gd` (EH-03).
- **No PC-04 coefficients.** No life-stage term appears anywhere in the store.
- **No MOVE gate and no task 05.1b completion.**
- **`InjuryKind` still does not live in `catalog.gd`.** Decision 0018 says a
  module needing one of §4.3's numbered enums reads it from there, and
  `catalog.gd`'s header says adding one of the five it does not carry —
  `WorldMode`, `ResidentStatus`, `Role`, `InjuryKind`, `FeastState` — "is an
  intentional artifact/digest change, not a fix". That change belongs to the
  catalog owner and was not made here. The six constants transcribe GDD §4.3
  line 215 and `test_injury.gd` asserts each value literally, so a renumbering
  fails a test rather than quietly re-labelling every saved injury. **Migrating
  them into `PROTECTED_ENUM_DOMAINS` remains owed.**

## Owed documentation rows (not in this change's file ownership)

`state_registry_coverage.py` fails until these land, which is expected and is
reported rather than worked around.

`docs/persistence_state_registry.md`, a new `### godot/scripts/core/injury.gd`
section with three rows, and `_airless` appended to `needs.gd`'s existing
"Resident state bytes" row (11 members to 12, 5632 B to 6144 B).

`docs/systems_architecture.md` §3.1, three ledger lines totalling **20992 bytes**:
byte columns 5 × 1 × 512 = 2560, int32 columns 3 × 4 × 512 = 6144, int64 columns
3 × 8 × 512 = 12288; plus 512 bytes for `needs._airless`. Grand total **21504
bytes** of new simulation-owned storage.
