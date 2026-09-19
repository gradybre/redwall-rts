# Final delta review — SAVE-W1-R02 test additions

2026-09-19 · Independent reviewer, not the author. **SAVE-W1-R02 is acknowledged as
the governing contract**, alongside RESTORE-R01. Scope: the delta since the prior
independent review, read against the exact supplied
`godot/scripts/core/save_world_runtime_install.gd` and
`godot/test/test_save_world_runtime_install.gd`.

I ran nothing. No suite invocation, no Godot execution, no file mutation is claimed
here. The counts reported by the parent are the parent's.

## Verdict

**No blocker.** Production logic is unchanged apart from one reworded docstring, so
the prior no-blocker ruling stands undisturbed. Every added test is meaningful.

## The delta, checked one item at a time

### Real pending command before the barrier

`_open()` now submits a real `SPEED_QUADRUPLE` through
`scheduler_events().submit_speed_into()` and asserts admission **before**
`begin_load()`. This runs for every manager the suite builds, including the two
`FaultManager` fixtures. Ordering is right: submission must precede the barrier,
because `scheduler_events.gd` bars every `submit_*` once the clock barrier is held.
The consequence matters — the queue under test is no longer empty, so "the install
changed no queue state" is now a claim about real bytes.

### Byte-exact queue comparison

`_queue_image()` sizes a buffer from `extension_byte_length()` and fills it through
`encode_extension_into()`, asserting success. That serializes the 32-byte control
header plus every pending record — head, count, next sequence, last drained
boundary, last applied sequence, and each record's boundary, sequence, kind, reason
and value. Comparing the image before and after the install is therefore stronger
than the three counters beside it, and it does not drain the queue.

### Pending-queue positive control

`assert_true(pending > 0, ...)` is exactly the guard this test needed. Without it,
equality of `pending_count()` and of two queue images would hold trivially for two
empty queues, and a regression that wiped the queue would pass. With the pending
command in place, the control is genuine.

### Terminal counters at MAX

The terminal test passes `all_counters = DEBT_MAX` through `_world()` and then
asserts, over `_clock_ten(...).slice(4)`, that all six counters came back exact —
not merely that the record was accepted. Tick is checked at `COMPLETED_TICK_MAX`
and debt at `DEBT_MAX` separately. This covers the ruling's terminal representable
requirement.

### Input record byte immutability

The alias test now snapshots both records through `encode_block` /
`encode_record` **before** the install and re-encodes them after, comparing whole
byte arrays, before going on to mutate them and confirm the installed world does not
follow. That closes the advisory raised previously: unchanged-input and
no-retained-alias are now both asserted, in that order.

### First-seed failure injection

`seed_calls_before_failure = 0` refuses the very first `seed_world`, which is the
forward install's own first write. The expected result is `SAVE_WORLD_RNG_SEED_FAILED`
— not `ROLLBACK_FAILED` — because `_restore_prior` re-seeds the prior seed and that
later call succeeds once the one-shot latch has cleared. The test asserts that code,
full prior-image equality, an untouched clock and a retained barrier. Correct.

### Recovery-stream failure injection — ordinal arithmetic

This is the subtlest addition, and the ordinal is right.
`stream_calls_before_failure = STREAM_COUNT` (nine) means the counter decrements on
each of the nine forward `restore_stream` calls issued by `SaveSectionRng.apply`,
reaching zero without refusing any of them. The forward RNG install therefore
succeeds in full. `fail_next_restore` then makes the clock refuse, `_recover` runs,
`_restore_prior` re-seeds and issues its first recovery write — and *that* call sees
the counter at zero and refuses. The assertions match: `SAVE_WORLD_ROLLBACK_FAILED`,
detail containing `restore_stream(0)` and `TEST_ROLLBACK_STREAM_REFUSED`, barrier
still held, nothing published. Note that `fail_stream` stays at its default `-1`, so
the two injection mechanisms do not interfere.

### No-float source check

`test_the_adapter_declares_no_float_path` reads the module and rejects `: float`,
`-> float` and `PackedFloat`, matching the sibling section suites. The previous
advisory on ARCH-AUTH-002 is closed.

## No false completion claim

No test asserts whole-world save/load, disk rollback, same-capture provenance or
release readiness. The failed-recovery test explicitly declines to claim
byte-identical recovery. The module header and the suite header both defer those to
the coordinator.

## Advisories (unchanged, non-blocking)

1. The `scripts/core/` → `scripts/systems/game_manager.gd` preload inverts the usual
   direction. The ruling fixes the signature and there is no cycle; this is a note
   for SAVE-ORCHESTRATOR.
2. `_restore_prior`'s docstring line remains wider than the file's prevailing width.

The full coordinator is correctly out of scope for this bounded packet and is not
demanded here. `release_save_ready` remains false.
