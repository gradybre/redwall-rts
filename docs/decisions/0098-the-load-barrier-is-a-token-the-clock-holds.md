# 0098 — The load barrier is a token the clock holds, and the queue reads the clock's

Date: 2026-09-12 · Status: **Accepted**

Decision [0092](0092-the-load-barrier-and-the-one-restore-call-site.md) landed
GameManager's load barrier and named the hole it left open:

> **The shared guard does not reach the raw clock and queue.** RESTORE-R01 says
> "Share the coordinator guard with clock/queue objects while mutable raw access
> exists; a GameManager-only check is insufficient." `clock()` and
> `scheduler_events()` still hand out objects whose own mutators know nothing
> about this barrier.

This record closes that hole inside `godot/scripts/core/sim_clock.gd` and
`godot/scripts/core/scheduler_events.gd`, and states the one wiring change in
`game_manager.gd` that is still owed by that file's owner.

## Decision

1. **The barrier's raised/lowered bit lives inside a capability object, not in a
   settable flag.** `SimClock.acquire_load_barrier()` returns a
   `LoadBarrierGrant`; on acceptance the grant carries a `LoadBarrier` token
   whose `_held` bool **is** the barrier. The clock holds a reference to that
   token and reads it (`is_load_barrier_held()`); it exposes no call that lowers
   it. Releasing the token is lowering the barrier, and only its holder can.

2. **One barrier per world.** A second `acquire_load_barrier()` while one is held
   refuses with `CLOCK_LOAD_BARRIER_ALREADY_HELD` and hands out no token, so two
   concurrent loads cannot each believe they own the world and have the first
   release open the clock under the second. A spent token cannot lower a later
   load's barrier — the bit it owns is its own.

3. **`scheduler_events.gd` reads the clock's barrier and keeps none of its own.**
   `SchedulerEvents.is_load_barrier_held()` asks `_clock`. There is therefore
   exactly one barrier per world, no second coordinator, and no way for a queue
   and the clock it applies events to to disagree about whether a load is open.
   This is also why `rebind_clock()` had to be barred: the queue reads the
   barrier *through* its clock, so a rebind under a held barrier would be an
   escape from the barrier as well as the re-basing of stamped events the
   function already refused.

4. **The barred surface is the operational command surface, named in one place.**
   Each file has a private `_command_barred()` and every guarded entry point
   calls it:

   | `sim_clock.gd` | `scheduler_events.gd` |
   | --- | --- |
   | `set_speed` | `submit_speed_into` |
   | `set_pause` | `submit_pause_into` (and `submit_player_resume_into` through it) |
   | `advance` | `submit_safety_hold_into` |
   | `acknowledge_without_catchup` | `submit_overload_downgrade_into` |
   | `apply_overload` | `admit_stamped_into` |
   | `apply_overload_target` | `pump_into` (and `pump()` through it) |
   | `note_overload_step` | `clear` |
   | | `rebind_clock` |
   | | `begin_host_frame` |
   | | `advance_frame` |

   `apply_overload_target()` and `note_overload_step()` are guarded in their own
   right and not only through `apply_overload()`: the first writes
   `_pause_mask` and `_requested_speed`, the second writes two restored counters
   and emits a signal, and both are public.

5. **Restore passes *through* the barrier, structurally.** `restore_runtime()`,
   `restore_extension()` and `restore_sequence()` do not call `_command_barred()`
   and are not affected by a held barrier. RESTORE-R01 says restore "is not such
   a command"; the structure says the same thing, because the guard is called by
   command entry points only and restore is not one. Blocking the restore with
   the barrier raised for it would block the load with the load's own guard.
   To keep that from being an accident of code sharing, `restore_extension()`
   now resets the queue through the private `_reset_to_initial_state()` rather
   than through the public `clear()` it used to call, and `_init()` does the
   same, so barring the command cannot break the install that shared its body.

6. **A barred call changes nothing at all.** Not the ten runtime fields, not
   `_last_error`, not `_last_diagnostic`, not the queue's `_last_refusal` or
   `_refused_count`. This is deliberately stricter than either file's ordinary
   validation refusals, which do record a reason. A caller-owned `SubmitResult`
   *is* filled with `SCHEDULER_LOAD_BARRIER`, because that is output rather than
   state: leaving a reused result carrying a previous success would let a
   careless caller read `ok` and believe its event was admitted.

7. **The barrier never touches the pause mask.** It is not a pause reason, is
   never OR-ed into `_pause_mask`, is never serialized, and lowering it never
   clears a *saved* `LOAD` hold. Being paused and being mid-load are different
   states. `is_load_barrier_held()` is how a HUD shows LOAD without either.

8. **Refusal is explicit, never a sentinel.** `apply_overload`,
   `apply_overload_target`, `note_overload_step` and `begin_host_frame` changed
   from `void` to `bool` so that "barred" is reportable; `clear()` did the same.
   `advance()`, `advance_frame()`, `pump_into()` and
   `acknowledge_without_catchup()` return 0, which is the truth — no tick ran,
   nothing was applied, nothing was dropped — and a caller separates that from a
   real zero with `is_load_barrier_held()`. No negative sentinel is returned
   anywhere.

## Why this layering and not another

`sim_clock.gd` and `scheduler_events.gd` sit **below** `game_manager.gd`:
`scheduler_events.gd` preloads `sim_clock.gd`, `game_manager.gd` preloads both,
and nothing in `scripts/core/` may preload `scripts/systems/`. A guard that
called into GameManager would be a circular dependency and would also make every
unit fixture in `test/` depend on an autoload singleton.

Three shapes were considered:

- **A public flag with a declared writer** (`set_loading(true)`). Rejected: a
  hook any caller can set is not a barrier, and the convention that "only the
  coordinator writes it" is exactly the convention decision 0092 already found
  insufficient one layer up.
- **An owner-registered callback** — the clock asks a `Callable` whether a load
  is open. Rejected: it puts the state back in whoever registered, so the answer
  can change without any barrier being raised, it allocates an indirection on
  paths `advance()` reaches every frame, and a stale registration outlives the
  loader silently.
- **A held token** — adopted. The capability is the state. There is no public
  lowering call to misuse, the failure direction is safe (a dropped token leaves
  the barrier **up**, refusing loudly, rather than letting a tick run over a
  half-installed world), and a stale token has no authority over a later load.

**What stops an arbitrary caller lowering it:** no public API on either object
lowers the barrier. The only route down is `LoadBarrier.release()` on the exact
object `acquire_load_barrier()` handed to the loader, and a caller that never
received it cannot mint one that matches — the clock compares nothing, it
*holds* the object whose bit it reads. This is honest about its limit: GDScript
has no access control, so `clock.get("_load_barrier")` can still reach the token
by reflection. That is not a route this design claims to close, and no GDScript
construct closes it. What it does close is every ordinary route: there is no
setter, no flag, no callback registration and no rebind that lowers the barrier.

## What is still owed, and by whom

**`godot/scripts/systems/game_manager.gd` is not this task's file** (its owner
holds it under decision 0092). Until the three lines below land there, the
barrier implemented here is never raised by the running game and the raw-access
hole stays open in production even though the mechanism now exists:

- `begin_load()` — take the grant alongside the existing checkpoint capture, and
  refuse the whole `begin_load()` if `acquire_load_barrier()` refuses, keeping
  its "nothing changed" contract.
- `end_load()` and `rollback_load()` — release the held token at the same point
  each already resets `_last_host_usec`, after every other step has succeeded.
- The token is one transient reference field; it is not serialized and belongs in
  the same transient-scalar note decision 0092 already owes the ledger.

`GameManager`'s own `_loading` flag stays as it is: it guards the coordinator's
own controls and its `_process`, and the clock-side barrier guards the raw
objects. They are one barrier's two checkpoints, not two barriers, because
`begin_load()` would raise both and `end_load()` would lower both.

## Consequences

- Every mutator listed in §4 now has a state a caller must be prepared for:
  refused, with nothing written. Callers that ignored the return value of
  `set_speed`/`clear`/`begin_host_frame` still compile, which is why the tests
  assert the *state*, not only the verdict.
- `restore_extension()` and `_init()` no longer route through `clear()`. Anything
  that assumed "the queue was cleared" implies "the public `clear()` ran" is
  wrong; `_reset_to_initial_state()` is the shared body.
- **Memory ledger rows owed in `docs/systems_architecture.md`**, which is not on
  this task's allowlist. No packed column is added, so
  `docs/persistence_state_registry.md` is owed nothing and
  `state_registry_coverage.py` passes unchanged (verified: 44 modules, 315 rows,
  630 packed columns). The transient allocation, in the same table that carries
  the 8224-byte scheduler queue row and decision 0092's 80-byte checkpoint:

  | Allocation | Count | Bytes each | Total | Lifetime | Note |
  | --- | --- | --- | --- | --- | --- |
  | Load barrier token reference | 1 | 8 | 8 | mutable | decision 0098: `_load_barrier: LoadBarrier` in `godot/scripts/core/sim_clock.gd`, one object reference, null while no load is open. Transient: never serialized, never in the canonical digest, and never a pause bit. |
  | Load barrier token | 0 or 1 | 1 | 1 | per load | decision 0098: one `LoadBarrier` RefCounted holding a single bool, allocated by `acquire_load_barrier()` at a load boundary and released with it. Cold path — one per load, never per frame or per tick. |

  `scheduler_events.gd` adds **no** field: it reads the clock's barrier, so the
  8224-byte queue row and its diagnostics are unchanged.

## Source

- `docs/rulings/2026-09-12_clock_restore_and_layout_followup.md` — RESTORE-R01,
  "The same barrier must also guard EVERY operational clock/queue mutator ...
  Share the coordinator guard with clock/queue objects while mutable raw access
  exists; a GameManager-only check is insufficient", and "Only the explicitly
  owned restore/install operations may write under that barrier."
- `docs/decisions/0092-the-load-barrier-and-the-one-restore-call-site.md` — the
  coordinator half, and the "what this does NOT close" section this record
  answers.
- `docs/decisions/0090-the-clocks-one-validated-restore-boundary.md` — the
  assignment boundary that passes through the barrier, and the purity rule a
  refused restore already obeyed.
- GDD §5.1 offset calendar `(tick + 4500) mod 18000`: the barrier tests restore
  at 13499 and confirm the first midnight at 13500 is delivered once by the
  normal clock afterwards, never `tick % 18000`.
