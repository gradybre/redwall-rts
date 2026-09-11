# 0054 — The scheduler-event queue drains before every tick, including paused ones
Date: 2026-09-11 · Status: Accepted

## Decision

`godot/scripts/core/scheduler_events.gd` implements R07-SCHED-001, the
[scheduler contract](../planning/ready07_scheduler_contract.md) adopted by
[READY_07 §3](../rulings/2026-09-11_ready07_open_item_answers.md). It is
ARCH-CMD-002's **separate** speed/pause queue: 256 records at a 32-byte stride,
a 32-byte control header, **8224 bytes** added once to ARCH-MEM-010's reconciled
basis.

Every width, offset, capacity, enum value and refusal in that file is
**transcribed** from the contract. Task 04.1 reserved them as design
deliverables — "not unspecified values a coder may choose at runtime" — so none
of them was chosen here. Where the contract left something unresolved it is
named below rather than filled in.

Seven things are settled.

1. **It is a second queue, not an extension of `commands.gd`.** ARCH-CMD-003's
   24 economic kind ids are not renumbered and no speed or pause key enters the
   sorted catalog domain; `catalog_ids.json` is byte-unchanged. The scheduler's
   kinds are its own two-value domain, `SET_REQUESTED_SPEED=0` and
   `SET_PAUSE_REASON=1`, compiled nowhere.
2. **Its 64-bit sequence space is independent and compared unsigned.** Same
   reasoning as decision 0042: the words are u32 bits in `PackedInt32Array`
   columns, so a signed comparison orders `0x80000000` before `0x7fffffff` and
   silently reverses two events. The two queues never share a number.
3. **Exhaustion refuses; it never wraps.** All-ones is the last usable
   sequence, so the next state is `(0,0)`, the sentinel, which is never a valid
   event. From there every admission path refuses
   `SCHEDULER_SEQUENCE_EXHAUSTED` and recovery is save/restart. **Sequence 1 is
   never reused**, because reusing it would make two distinct events compare
   equal in a replay stream.
4. **The tail derives from head and count.** No order index is allocated, which
   is the difference from decision 0042's economic ring: admission stamps
   monotonically increasing keys here, so ring order already *is* canonical
   order. A record is fully written before `_count` is incremented.
5. **`last_drained_boundary` is diagnostic and suppresses nothing.** A paused
   frame sits at one completed tick forever and must keep admitting and
   applying events there — that is how the unpause itself arrives. A second
   drain at the same boundary is normal, not a bug.
6. **The pump runs before every fixed-tick decision and on paused frames.**
   `sim_clock.advance()` gained an optional `before_tick: Callable`; the tick
   loop now calls it *before* re-testing the pause mask and the debt, so a pause
   admitted during tick 3 of an eight-tick catch-up frame stops tick 4. This is
   what prevents unpause waiting on the very tick pause prevents.
7. **Persistence is implemented and unwired.** The `SCHQ0001` subsection —
   tag, `schema_version=1`, `payload_byte_length`, the control header with
   canonical head 0, then `count` records — exists as encode, decode and
   validation. **No save module exists in this repository**, so the
   cross-process round trip is **BLOCKED**, not passing. Task 09 owns the codec.

## Why

### ARCH-CLOCK-002's recovery exception against the higher no-skipped-ticks rule

This is the reconciliation READY_07 §3 required to be made explicitly, so it is
made here rather than left to a reader.

Three sources speak, and the authority order settles them:

- **GDD REQ-SET-008** (authority item 2): at 1x the system "shall pause with a
  diagnostic rather than skip ticks."
- **ARCH-CLOCK-001** (item 4, derived): "never discard completed or owed ticks
  to hide sustained overload."
- **ARCH-CLOCK-002** (item 4, derived): explicit "resume without wall-time
  catch-up" *may* clear scheduler debt, and "record this scheduler event."

The GDD outranks `systems_architecture.md`, so **no-skipped-ticks is the rule
and ARCH-CLOCK-002's exception is subordinate to it.** They are reconciled, not
traded off, by reading the exception for what it actually says:

- REQ-SET-008 governs what the system may do **on its own initiative** under
  sustained overload. On its own initiative the system may only slow down and
  then stop. It never discards. That is unchanged, and the overload ladder still
  retains every owed tick in unchanged tick-cost units at every rung.
- ARCH-CLOCK-002's exception governs what a **player** may do deliberately,
  once, having been told. It is not the system hiding overload; it is a person
  declining a catch-up they were shown. `acknowledge_without_catchup()` is that
  path, and its whole design is the reconciliation: it is never called
  implicitly, it reports how many ticks it dropped, it counts the call in
  `acknowledged_catchup_resets()` and the total in
  `acknowledged_ticks_discarded()`, and **`_completed_tick` never moves** — so no
  tick is ever recorded as completed that did not run. Discarded work stays
  visibly discarded. That is exactly ARCH-CLOCK-002's "record this scheduler
  event."
- The second, much narrower exception is the sub-tick presentation debt dropped
  when PLAYER pause is entered with **less than one whole tick owed**. No whole
  tick can be lost to it by construction, so it does not touch the rule at all.
  It is counted in `subtick_debt_discards()`.

The contract's "Recommended U3 resolution" asks that whole-debt discard
recovery not be *offered in production* until a higher-authority amendment
reconciles it. **No production caller of `acknowledge_without_catchup()` is
added by this work, and none exists.** It remains an explicit, counted, tested
API with no UI path. Retiring it was considered and rejected: READY_07 §3 says
in terms that its behaviour and tests "are not silently approved or retired",
and deleting it would destroy task 02's recorded evidence for U3.

**`acknowledge_without_catchup()` is byte-unchanged**, and so are its tests.

### The overload ladder now crosses the same barrier

This is an intentional behaviour change and is logged as one.

The contract says the overload downgrade must "pass through the same recorded
barrier", reserves a queue slot for it, and states that "the next frame pumps
before producing another". So when a scheduler drives the frame, the ladder's
rung is **queued** rather than applied inside the frame, and the next frame's
opening pump applies it before any tick of that frame runs.

Gameplay is unaffected: the immediate ladder set the rung *after* the frame's
ticks, and the queued one applies it *before* the next frame's ticks, so no tick
ever runs at the superseded speed either way. What changes is that the pending
rung is now visible, saveable and replayable instead of being an invisible
in-frame mutation.

**The clock's own counters are preserved**, which is why `apply_overload()` was
split rather than replaced. `overload_ladder_target()` chooses the rung,
`apply_overload_target()` applies it, and `note_overload_step()` records
`fallback_count()`, `diagnostic_pause_count()` and `last_diagnostic()` and emits
the UI signal. `apply_overload()` still calls all three in the original order,
so **`sim_clock.advance()` with no hooks behaves exactly as it did before**;
`test_the_clocks_direct_ladder_is_unchanged_when_no_hook_is_supplied` pins that.

One honest wrinkle: on the queued path `note_overload_step()` fires when the
rung is *chosen*, so a handler of `clock_diagnostic_pause` reading `is_paused()`
sees the pause land one pump later. Those signals are UI-only and the contract
states that "performance diagnostics are not gameplay RNG inputs", so this was
accepted rather than papered over.

### Producer ownership without inventing an id space

The contract says "each producer is allowed only its own pause reason" and names
no producer numbering. Since it also gives each reason exactly one owner, the
producer **is** its reason bit — `PRODUCER_OVERLOAD == CRITICAL`, and so on. No
new enum was invented. `submit_player_resume_into()` is the "ordinary Resume
clears PLAYER only" path and can express nothing else, which is what stops a
generic UI toggle from clearing CRITICAL or LOAD.

### What was left unresolved rather than invented

- The contract fixes `reason` at 0 for a speed event, so **a record cannot
  carry its producer**. A drained `SET_REQUESTED_SPEED` is therefore
  indistinguishable from a player's; that is why the ladder's diagnostics stay
  with the clock instead of being restored from the record. Naming a producer
  field would be a record-format change nobody authorised.
- The contract's container-version-2 section-12 prefix spans economic *and*
  scheduler state. Only the pure arithmetic and bounds (`72 + 64E + P + 32S`,
  `E<=4096`, `P<=1048576`, `S<=256`) are implemented here, as static helpers
  that read no economic store. Wiring them needs the save module and
  `commands.gd`'s cooperation; neither is in this change's scope.

## Consequences

- **Blocker U2 is closed in process and open on disk.** Queued speed and pause
  events exist, they have an ordering tiebreak, they drain before every tick and
  while paused, and they have a specified save subsection. What does *not*
  close: ARCH-SAVE-002 §12 cannot actually be written or read by anything,
  because no save module exists. `sim_clock.gd`'s two "BLOCKER U2 … not
  implemented" comments were false after this change and have been corrected to
  say precisely that.
- Blocker U3 is **not** closed. The conservative reading stands, now with the
  reconciliation above written down.
- ARCH-MEM-010's basis moves from 60256806 to **60265030** — decision 0050's
  437632 reconciliation is **reproduced, not reapplied**:
  `60265030 − 8224 − 59819174 = 437632` still holds exactly. One-world plus
  reserve becomes 68653638, headroom 31346362, and the rejected two-world peak
  122703084, which rises by `2 × 8224` because the queue is mutable state in
  both worlds.
- `sim_clock.advance()` has two new **optional** Callables. Existing callers are
  unaffected; a future caller that wants the barrier must pass it.
- `docs/validation/ready07_arithmetic.py` now reads `QUEUE_CAPACITY`,
  `RECORD_BYTES`, `CONTROL_BYTES` and `NORMAL_CAPACITY` out of the GDScript, so
  changing a capacity in the implementation without moving the ledger fails the
  validator rather than drifting.

## Evidence

Suite before this change: **1999 tests, 56972 assertions, 0 failures**. After:
**2082 tests, 59643 assertions, 0 failures** (`./tools/run_tests.sh`). The two
`Unicode parsing error` lines are a pre-existing deliberate negative test.

**76 mutations, one per Godot invocation, every production file restored and
sha256-compared against a pristine copy afterwards: 0 survivors.** Mutated:
every record offset and the stride, every control-header offset, the 256 and 250
capacities, the 32-byte control header, the initial sequence and the initial
`last_drained_boundary` of −1, both unsigned comparisons, the exhaustion
sentinel and its wrap, every admission refusal, the coalescing scan, the ring's
head/tail derivation, the drain-before-tick ordering, the whole `SCHQ0001`
validator, and the clock's ladder and debt rules.

Three of those mutations found real gaps and **two found real defects**, which is
why they are worth recording:

1. `compare_sequence()`'s **high-word** mask survived the first sweep. The test
   passed a literal `0x80000000`, which is simply positive in GDScript's 64-bit
   ints, so the mask was never exercised. Only a value that came *out* of a
   `PackedInt32Array` (`-2147483648`) proves it. Test added.
2. `current_boundary()`'s `+1` survived, because `_submit_stamped()`
   **re-derived the same `+1` independently** instead of calling it — a DRY
   defect that would have let the boundary a record is stamped with drift from
   the boundary its admission was validated against. Extracted into
   `_executing_offset()`, now the single place that `+1` is written.
3. `event_refusal()`'s negative-boundary check was unreachable from every tested
   path; the reachable one is a corrupt save claiming a negative completed tick.
   Test added.

One mutant is genuinely **equivalent** and is recorded in the harness rather
than counted: incrementing `_count` first and then writing
`(_head + _count - 1)` names the same row as `_tail_row()` did before. The
"fully initialized before `count` is incremented" ordering is not observable
single-threaded in GDScript; the non-equivalent variant that writes one row past
the intended one is the one in the suite, and it is killed.

## Source

[R07-SCHED-001](../planning/ready07_scheduler_contract.md) in full;
[READY_07 §3](../rulings/2026-09-11_ready07_open_item_answers.md) adopting it;
`docs/systems_architecture.md` ARCH-CMD-002 and ARCH-CLOCK-001/002;
`docs/tasks/04_world_commands.md` §04.1; GDD REQ-SET-002–008;
[decision 0042](0042-the-command-queue-orders-by-an-unsigned-key.md) for the
unsigned-key precedent and [decision 0050](0050-ready07-source-audit-and-ledger-reconciliation.md)
for the ledger basis this adds to.
