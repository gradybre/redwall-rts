# 0092 — GameManager's load barrier, and the two halves of RESTORE-R01 it cannot close

Date: 2026-09-12 · Status: **Accepted**

RESTORE-R01's LOAD integration section is implemented in
`godot/scripts/systems/game_manager.gd`: the shared load-in-progress guard, the
monotonic origin reset, and the one call site of the clock's
`restore_runtime()`. Two named halves of the same ruling are **not** closed here,
and this record says exactly which and why, so no later reader mistakes the
barrier for the whole contract.

## Decision

1. **A transient load barrier, raised and released by GameManager.**
   `begin_load()` / `end_load()` bracket a load; `is_loading()` reports it.
   The guard is checked **before host advance** (top of `_process`, and again at
   the top of `advance_host_time()` so a direct test or service entry point
   cannot walk round the node callback) and **before scheduler pumping**
   (`_drain_boundary()`). Every operational control refuses under it with
   `LOAD_IN_PROGRESS` and mutates nothing: `start_game`, `pause_game`,
   `resume_game`, `toggle_pause`, `set_speed`, `cycle_speed`,
   `acknowledge_overload`. `bind_simulation()` deliberately still works — step 3
   of the ruling rebinds callbacks under the guard.

2. **The barrier is not a pause reason.** It is never written into the clock's
   mask, never submitted to the scheduler queue and never serialized. The saved
   logical mask is the thing being restored; giving it a bit that describes the
   act of restoring it would put a transient overlay into the canonical digest.
   `is_loading()` exists so the HUD can display LOAD without that.

3. **One call site, straight to the clock's assignment boundary.**
   `restore_clock_runtime()` takes the same ten integers in the same order and
   forwards them to `SimClock.restore_runtime()`. It calls no setter, submits no
   event, runs no tick, pumps no queue and emits no signal. A clock-side refusal
   surfaces as `CLOCK_RESTORE_REFUSED` and leaves all ten fields untouched; the
   clock's `last_error()` is deliberately not consulted, because decision 0089
   makes a refused restore leave even that string unwritten.

4. **Publication is explicit and derives from the restored mask.**
   `publish_restored_world()` sets `_started` itself and re-derives
   PLAYING/PAUSED from the clock's restored pause mask, while the guard still
   holds. It refuses (`LOAD_NOT_INSTALLED`) until a restore has actually been
   installed, so a half-validated file cannot publish a world. A load from BOOT
   therefore needs no `start_game()` — which is what the ruling requires, since
   `start_game()` clears the queue, replaces the clock and queues a resume the
   saved mask never asked for.

5. **The monotonic host origin is reset at every release.** `end_load()` and
   `rollback_load()` both set `_last_host_usec` to the current
   `Time.get_ticks_usec()`. A load spanning many real seconds therefore owes the
   restored clock no debt, and the restored debt is exactly the saved one.

6. **Rollback reinstalls through the same API.** `begin_load()` copies the
   clock's ten runtime scalars into a pre-allocated `PackedInt64Array(10)` before
   anything can move them; `rollback_load()` reinstalls them with the same
   `restore_runtime()` call and then restores the previous `_started`/`_state`,
   so a failed first load stays in BOOT with no partial world. If the checkpoint
   itself will not reinstall, the barrier **stays held** and
   `is_load_unrecoverable()` reports it rather than releasing a partial world.

7. **`end_load()` refuses before publication.** The only other way out of a load
   is `rollback_load()`. There is no path that releases the barrier over a world
   that was installed but never published.

## Why

The ruling forbids manufacturing the saved state through the ordinary mutation
path, and decision 0089 records the concrete corruption that would follow:
`set_pause(PLAYER, true)` zeroes a sub-tick debt and counts the discard, so a
save with 999999 debt in a PLAYER pause would come back as 0 debt and one extra
`_subtick_debt_discards`. `test_a_restored_player_pause_does_not_zero_the_sub_tick_debt`
pins that difference from this side of the boundary as well.

The guard has to sit ahead of the advance, not inside it, because loading spans
many host frames. Without it, a single `_process` during a load would fold real
elapsed microseconds into a clock whose tick had just been rewritten — the
restored tick would drift before the world was ever published.

The origin reset is the other half of the same problem: the barrier stops debt
accruing *during* the load, and the reset stops the accumulated wall-clock gap
from being charged the instant it drops.

Rollback goes through `restore_runtime()` rather than through a private
assignment so that the recovery path is validated by the same ten rules as the
load path. A rollback that could write a state the restore would have refused is
a second, weaker writer of the same ten fields, which is exactly what RESTORE-R01
exists to prevent.

## What this does NOT close

- **The shared guard does not reach the raw clock and queue.** RESTORE-R01 says
  "Share the coordinator guard with clock/queue objects while mutable raw access
  exists; a GameManager-only check is insufficient." `clock()` and
  `scheduler_events()` still hand out objects whose own mutators —
  `SimClock.set_speed/set_pause/advance/acknowledge_without_catchup`,
  `SchedulerEvents.submit_*/pump/clear/rebind_clock` — know nothing about this
  barrier. Closing that needs an edit inside `scripts/core/sim_clock.gd` and
  `scripts/core/scheduler_events.gd`, which belong to the clock owner. It is
  **not** worked round here with a check a raw caller bypasses anyway.
- **"Disk-backed" rollback is in memory only.** The checkpoint is the clock's ten
  scalars held in a packed column. No §1 WORLD section writer exists on this
  base — the section is in review as PR #64 and is not merged — so there is
  nothing to write a checkpoint file from or validate one against. Section 12's
  queue restore (`scheduler_events.restore_extension()`) exists and is called by
  the save owner under this barrier, not by this node.
- **No save parity, no full colony, no movement gate and no Windows
  qualification** are claimed or implied. Task 09.3 acceptance stays open.

## Consequences

- The load sequence is fixed: `begin_load()` → `restore_clock_runtime()` →
  section 12 / other section restores by their owners, under the same barrier →
  `publish_restored_world()` → `end_load()`, or `rollback_load()` on any failure.
- A future owner of the raw-access hole must add the barrier check inside the
  clock and queue, not a second barrier in a second coordinator. There is one
  guard, and this node owns it.
- **Memory ledger rows are owed in `docs/systems_architecture.md`**, which is not
  this task's file to edit. The exact arithmetic, for the allocation table that
  already carries the 8224-byte scheduler queue row:

  | Allocation | Count | Bytes each | Total | Lifetime | Note |
  | --- | --- | --- | --- | --- | --- |
  | Load rollback checkpoint | 1 | 80 | 80 | mutable | decision 0092: `_checkpoint: PackedInt64Array` in `godot/scripts/systems/game_manager.gd`, 10 elements x 8 bytes = 80, allocated once in `_init()` and overwritten in place. Holds the clock's ten runtime scalars in `restore_runtime()` argument order. Transient: never serialized, and it duplicates no clock — RESTORE-R01 forbids a second WorldRuntime store. |

  Plus five transient booleans and one int (`_loading`, `_restore_installed`,
  `_published`, `_unrecoverable`, `_checkpoint_started`, `_checkpoint_state`),
  which the ruling asks to be recorded as a transient scalar allocation rather
  than charged as a second clock or a second world.
- `docs/validation/state_registry_coverage.py` does not scan
  `godot/scripts/systems`, so the new column is invisible to it. That is a gap in
  the checker's scope, not a registry exemption; the row above is the record.

## ADR numbering note

Master carries **two** files numbered 0089 (`0089-restore-layout-and-movement-followup.md`
and `0089-the-clocks-one-validated-restore-boundary.md`). Branch
`fix/adr-0089-collision` renumbers the second to 0090, so 0091 is the next free
number above everything in flight. 0086 remains a deliberate unused gap.

## Source

- `docs/rulings/2026-09-12_clock_restore_and_layout_followup.md` — RESTORE-R01,
  "LOAD integration — preserve the restored state until publication", steps 1–6.
- `docs/rulings/2026-09-12_executor_followup.md` — the WORLD restore row and its
  explicit "no save parity, full colony, movement gate or Windows qualification
  may be inferred" limit.
- `docs/decisions/0089-the-clocks-one-validated-restore-boundary.md` — the clock
  half this node calls.
- GDD §5.1 offset calendar `(tick + 4500) mod 18000`, first midnight tick 13500,
  which `test_the_next_real_midnight_after_a_restore_is_delivered_exactly_once`
  exercises rather than `tick % 18000`.
