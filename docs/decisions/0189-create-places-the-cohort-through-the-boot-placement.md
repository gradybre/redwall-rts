# 0189 — Create places the cohort through the boot transaction's own placement
Date: 2026-09-24 · Status: Accepted

## Decision

UI-SET-103's **Create** now stands §5.1's twelve on the hall's south apron, exactly where
booting does. `SettlementSystem.create_placed_cohort_on(world)` spawns the cohort and runs
INIT-POSE-R01's placement against a *given* prepared world. `UiWorldSession` passes it the
world it has just prepared, between seeding and publishing. Boot and Create now share **one**
placement body; the only thing that differs is which prepared world it is proved against.

## What was wrong

After Create, the twelve residents were alive but **none had a pose**. The crowd skips an
unplaced resident, as its docstring promises, so the world drew nobody. Measured by booting
`main.tscn` headless and reading the crowd before and after `UIManager.create_world()`:

```
BOOT          drawn=12  skipped_unplaced=0   bound=12
create_world -> true
AFTER_CREATE  drawn=0   skipped_unplaced=12  bound=0
```

The camera never moved. The Cycle-3 HUD evidence shows an empty field in every
world-generated capture for this reason, and pressing Create in the running game did the same.

## How it happened — two initialization paths that drifted

| Date | Change | Effect |
|---|---|---|
| 2026-09-12 | PR #59 built Create as reset → cohort → generate, through `UiWorldSession` | Create got ids 1–12, matching boot |
| 2026-09-14 | 5e1443e added INIT-POSE-R01's placement **inside `_run_initialization_transaction()` only** | Boot placed the cohort; Create was never updated |

The docstrings on both paths warn against exactly this — *"a second place for it to be
stated and to drift"*. The warning was right and it happened anyway, because placement
was written against the settlement's own `_world`, and Create prepares a **different**
`WorldInit` instance, inside `UiWorldSession`.

## Why this fix, and not the alternatives

- **Route Create through `create_generated_settlement()`.** Rejected, and already tried: the
  `ui_manager.gd` docstring records that it lost the session's published map, attempt report and
  generator refusal codes, and broke two tests that were right to fail.
- **Copy the placement into the session.** Rejected: that would be a second copy of the rule —
  the cause of this defect, not a fix for it.
- **Parametrise the one placement over the prepared world.** Chosen. Only two things in the
  placement tied it to the settlement's own world: the `has_prepared_plan()` check, and
  `refuse_assembly_occupancy(world)`, which was already static and took the world as an argument.
  Every ground check was already a static `WorldInit` rule.

The session's cohort `Callable` now **receives the prepared world** (`cohort.call(_world)`).
A cohort step that cannot see the plan can create residents, but it can never stand them
anywhere.

`_place_initial_cohort()` stays as the boot seam, delegating to `_place_initial_cohort_on(_world)`,
because `test_settlement_system.gd` overrides it to observe the moment of placement.

A placement refusal on Create **empties the settlement and keeps its code**, as a cohort
refusal already did. `create_world()` already replaces `REFUSE_COHORT` with
`SettlementSystem.last_refusal()`, so the player sees the specific INIT-POSE refusal.

## The test, and why it compares paths rather than constants

`test_create_stands_the_cohort_exactly_where_boot_stands_it` runs boot's transaction, keeps
`transforms().state_bytes()`, resets, runs Create, and requires **12 bound** and a
**byte-identical** pose store. It does not compare against the authored constants: those would
agree with the placement code by construction — the symmetric blindness this project has hit
seven times. Two independent routes to one §5.1 initialization must leave the same image.

The existing `test_a_generated_world_is_populated…` asserted `living_count() == 12` after
Create. That was true while the bug was live: the test proved the residents existed and never
asked whether they stood anywhere.

## Evidence

- Before the fix the new test failed — `expected 12, got 0`, and not byte-identical — and it was
  the **only** failure in the suite.
- After the fix: `ok: 5109 tests, 528328 assertions, 0 failures.`
- Mutation: skipping `_place_initial_cohort_on()` inside `create_placed_cohort_on()` fails the new
  test. The file was restored byte-identical (SHA-256 compared).
- Re-running the headless probe on the fixed tree gives `AFTER_CREATE drawn=12 skipped_unplaced=0 bound=12`.

## Not done here

The Cycle-3 HUD captures were not re-taken. They are evidence of the UI geometry they were made
for, and that geometry is unaffected. A capture taken after this change will show the cohort.
