# 0084 — The running game drives the scheduler-event queue
Date: 2026-09-11 · Status: Accepted

## Decision

`godot/scripts/systems/game_manager.gd` now drives R07-SCHED-001's speed/pause
queue. This closes open item 1 of
[decision 0054](0054-the-scheduler-event-queue-drains-before-every-tick.md),
which recorded — correctly — that `scheduler_events.gd` was implemented,
mutation-tested and `preload`ed by nothing but its own test file.

`godot/scripts/core/scheduler_events.gd` is **byte-unchanged** by this work.
`godot/scripts/core/sim_clock.gd` changes in **comments only**: no statement, no
constant, no signature and no counter moves.

Five things are settled.

1. **The host frame goes through `advance_frame()`, not `advance()`.**
   `advance_host_time()` calls
   `_events.advance_frame(elapsed, step, day_boundary)`, which opens the host
   frame (restoring the overload producer's one downgrade), pumps the queue once
   before any tick decision, and hands the clock **both** the `before_tick`
   barrier and the `on_overload` hook. Decision 0054's open item was precisely
   that this one line passed neither.

2. **Every player speed and pause control is a queued event.** `pause_game()`,
   `resume_game()`, `toggle_pause()`, `set_speed()` and the opening release of a
   fresh clock's PLAYER pause inside `start_game()` all submit through the queue.
   `resume_game()` uses `submit_player_resume_into()`, the contract's "ordinary
   Resume clears PLAYER only" path, so a Resume button cannot lift a MENU, LOAD
   or overload CRITICAL hold — it cannot *express* that.

3. **A control submitted between frames is drained in the same call.** See below;
   this is the one real design choice in this change.

4. **`start_game()`'s order is `clear()` → new clock → `rebind_clock()`**, and it
   returns `bool` rather than `void` so a refused rebind is refused, not
   swallowed. `rebind_clock()` refuses a non-empty queue by design, so this order
   is load-bearing and is pinned by
   `test_restarting_clears_the_queue_before_rebinding_it_to_the_new_clock`, whose
   fixture deliberately leaves a record pending.

5. **`acknowledge_overload()` still reaches the clock directly, and drains
   first.** See "What deliberately still bypasses the queue".

## Why

### The same-boundary drain, which is the only real choice here

The contract says input accumulated between frames "belongs to the next safe
boundary", and that an event admitted between ticks is stamped **the current
completed tick**. Between ticks, that boundary *is* the current one. So
`_drain_boundary()` — one `pump()` immediately after each control submission —
performs exactly the drain the next frame's opening pump would perform, at the
same boundary, in the same sequence order. Decision 0054's settled point 5 states
in terms that a second drain at one boundary is normal rather than a bug.

The alternative, submitting and waiting for the next frame's opening pump, was
rejected for a concrete reason rather than a stylistic one:
`ui_manager.apply_opening_pause()` calls `pause_game()` and then reports success,
and its own docstring says it refuses rather than "claim an inspection pause that
is not held". A deferred pause would make that report false for one frame. The
headless boot confirms the difference is not theoretical: `[Main] boot complete:
PAUSED` is UI-SET-103's opening inspection pause, and it now arrives through the
queue.

**No guard against pumping mid-tick is written, and none is needed.** A control
re-entered from inside tick k is stamped k while `completed_tick()` still reads
k-1, and `pump_into()` drains only `boundary_tick <= completed_tick`, so the
immediate pump is provably a no-op on the record just submitted. The queue
enforces the property; duplicating that as an `is_executing_tick()` branch in
`game_manager.gd` would have been unobservable code, and unobservable code
survives mutation. It was written, found unkillable, and removed.

### What this changes in play, and what it does not

- **The overload ladder now crosses the barrier**, which is decision 0054's
  recorded behaviour change finally reaching the running game. At 1x an
  overloaded frame *queues* the CRITICAL rung and the next frame's opening pump
  applies it before any tick of that frame. No tick runs at the superseded rung
  either way, and every owed tick stays owed: the two-frame sequence is pinned at
  22 retained ticks by name.
- **A pause produced inside tick k stops tick k+1 of the same frame.** This is
  what `before_tick` buys and a bare `advance()` cannot do, and it is the
  difference between an eight-tick catch-up frame that honours a pause and one
  that does not.
- **A refused admission is now readable.** `last_refusal()` carries the queue's
  own codes unchanged, so `set_speed(3)` and `set_speed(0)` refuse as
  `SCHEDULER_SPEED_NOT_SELECTABLE` instead of being rejected silently inside the
  clock. Decision 0054 listed "nothing in production reads
  `event_refusal()`/`last_refusal()`" as its cheaper open item; a caller now
  does. A UI surface for it is still UI's to build.
- **Nothing about the time contract moves.** 30 ticks/second, 18000 ticks/day,
  offset calendar `(tick+4500) mod 18000`, first midnight 13500, speeds 0/1/2/4.
  The economic command queue keeps its own arena, its own sequence space and
  ARCH-CMD-003's 24 unrenumbered kind ids.

### ARCH-CLOCK-002 versus no-skipped-ticks is not widened

Decision 0054 reconciled these and that reconciliation is untouched. REQ-SET-008
governs what the system may do on its own initiative — slow, then stop, never
discard — and the wired ladder still retains every owed tick at every rung.
ARCH-CLOCK-002's exception governs one deliberate player action, and
`acknowledge_without_catchup()` remains the only counted path that drops owed
ticks. Blocker **U3 is not closed** and its conservative reading stands.

### What deliberately still bypasses the queue

`acknowledge_overload()` calls `_clock.acknowledge_without_catchup()` directly.
The queue has two kinds, `SET_REQUESTED_SPEED` and `SET_PAUSE_REASON`, and
**neither can express "clear the retained debt"**. Routing this through the
barrier would need `sim_clock.gd` to split debt clearing from the CRITICAL
release so the release could travel as an ordinary pause-clear event — a
structural change to the one path decision 0054 keeps byte-unchanged, on a file a
concurrent agent is reading. It was **not made**; it is named here instead.

What *was* done is the part that needs no new contract: `acknowledge_overload()
drains the boundary first`. Without that, a player acknowledging during the frame
between a queued rung and its pump would clear a CRITICAL hold that was still
pending, and the next pump would put them straight back into the pause they had
just left. `test_acknowledging_overload_drains_the_pending_rung_before_clearing_it`
pins it and kills the mutation that removes the drain.

Two smaller gaps, named rather than filled:

- **`toggle_pause()` reads the live pause mask, not pending intent.** The queue's
  `_pending_pause_state()` is private and no public reader exists. Between frames
  the distinction cannot arise, because every control drains at submission; it
  could only arise for a toggle re-entered from inside a tick, which no input
  path does. Exposing a pending-state reader is a `scheduler_events.gd` change and
  was not invented here.
- **There is still no way to withdraw an admitted record.** `clear()` is world
  initialization and resets the sequence, so it is not a cancel. Nothing in the
  wired paths needs one.

## Consequences

- **Persistence stays blocked, exactly as before.** There is no §12 section
  codec, so `SCHQ0001` remains an implemented, validated, unwired encoder and
  decoder, and a pending queue still cannot survive a process restart. Task 09
  owns it. Wiring the queue into the frame loop does not move this at all — and
  the §1 WORLD save section's `_debt` and six clock counters are untouched by
  this change, in name and in meaning.
- **ARCH-MEM-010 does not move.** The 8224 bytes were added once by decision
  0054; this change allocates no new column and adds no capacity. `GameManager`
  gains one reference, one reused `SubmitResult` and nothing else.
- **Public API changed on four functions.** `start_game()`, `pause_game()`,
  `resume_game()` and `toggle_pause()` return `bool` instead of `void`.
  Existing callers — `main.gd`, `ui_shell.gd`, `ui_manager.gd` — ignore the
  return value and are unaffected; none was edited.
- **`ui_manager.apply_opening_pause()` does not check `pause_game()`'s new return
  value**, so it would still report success if the queue refused the hold. That
  file belongs to another owner and was left alone; it is reported rather than
  changed.
- No new packed column, so `docs/validation/state_registry_coverage.py` needs no
  new row; it and `docs/validation/ready07_arithmetic.py` both pass unchanged.

## Evidence

Suite before this change: **2837 tests, 101328 assertions, 0 failures**. After:
**2853 tests, 101389 assertions, 0 failures** (`./tools/run_tests.sh`).
`state_registry_coverage: PASS -- 38 modules, 282 rows, 548 packed columns
checked`. `ready07_arithmetic` `{"status": "PASS", ... "scheduler_total_bytes":
8224}`. The one `Unicode parsing error` line is a pre-existing deliberate
negative test.

Sixteen tests were added, all in `godot/test/test_game_manager.gd`. **No existing
test was weakened, changed or deleted**, which is itself the evidence that the
same-boundary drain preserves every previously pinned contract — including
`test_the_clocks_direct_ladder_is_unchanged_when_no_hook_is_supplied`, which
still pins the bare no-hook `advance()` path in `test_sim_clock.gd`.

**17 mutations, one per Godot invocation, each file restored and sha256-compared
against a pristine copy afterwards: 0 survivors.** Every one was killed with a
failure count parsed as an integer from the runner's own summary line:

| Mutation | Failures |
|---|---:|
| the frame path calls `advance()` instead of `advance_frame()` | 4 |
| `rebind_clock()` before `clear()` | 1 |
| no `clear()` at all | 2 |
| rebind to the *old* clock | 34 |
| `start_game()` releases PLAYER on the clock directly | 2 |
| `pause_game()` sets the clock directly | 1 |
| `set_speed()` sets the clock directly | 1 |
| `_drain_boundary()` never pumps | 17 |
| `acknowledge_overload()` skips the drain | 1 |
| `resume_game()` clears the whole mask | 3 |
| `pause_game()` loses its `_started` guard | 1 |
| `_queue_pause()` leaves the record pending | 4 |
| the queue's refusal code is swallowed | 2 |
| `advance_frame()` drops the `before_tick` barrier | 5 |
| `advance_frame()` drops the `on_overload` hook | 6 |
| `advance_frame()` drops the opening pump | 5 |
| `advance_frame()` drops `begin_host_frame()` | 1 |

The third block mutates `scheduler_events.gd` — a file this change does not
otherwise touch — because the new caller's correctness depends on those four
lines, and decision 0054's own sweep could not have exercised them through a
production driver that did not exist.

The `rebind_clock()` order mutations are the ones this decision most needed.
`clear()` guarantees an empty queue, so in production the rebind can never
actually refuse; the order is only observably load-bearing against a fixture that
leaves a record pending on purpose, which is what that test does.

One unkillable line was found and **removed rather than left in**: the
`is_executing_tick()` guard described above. That is recorded because "the
mutation survived, so the code went" is a better outcome than a green suite over
a branch nothing can reach.

## Source

[Decision 0054](0054-the-scheduler-event-queue-drains-before-every-tick.md),
whose open list this closes item 1 of;
[R07-SCHED-001](../planning/ready07_scheduler_contract.md), in particular
"Boundary pump and clock debt";
[READY_07 §3](../rulings/2026-09-11_ready07_open_item_answers.md);
`docs/systems_architecture.md` ARCH-CMD-002 and ARCH-CLOCK-001/002;
GDD REQ-SET-002–008; `docs/tasks/04_world_commands.md` §04.1.
