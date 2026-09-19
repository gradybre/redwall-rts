# Independent review — SAVE-P2-R02 v1 (fresh reviewer, not either author)

Ack SAVE-P2-R02. 2026-09-19. Scope: `commands.gd` pending-window boundary and ordinary
guards, `save_section_pending_commands.gd` capture/encode/decode/apply, the dedicated
restore suite and the amended codec suite. Review by reading only; **no tools were run and
no test execution is claimed**. The only test evidence considered is the supplied focused log
(118 tests / 27176 assertions, `test_commands.gd`, `test_commands_arena_restore.gd`,
`test_save_section_pending_commands.gd`). The full suite was still running at review time, so
nothing here asserts full-suite, native-build or whole-save acceptance.

## Verdict

**No blocking findings.** Advisory items only, listed and bounded below.

## What was checked independently, and what it showed

### Validator purity and atomicity
`pending_window_refusal()` writes no field, no counter and no `_last_refusal`; the sole
writer is `restore_pending_window()`, which runs the identical validator before its first
write (`_reset_rows()`). A refusal therefore leaves rows, order ring, arena, both sequence
words and accepted/refused/drained counters untouched — this matches decision 0059 and is
exercised by the suite's `_reject()` helper, which compares an encoded image (records,
live payload bytes, cursor, allocator pair, three counters) and separately asserts the
diagnostic is *unchanged* by the pure call.

### Span geometry, non-overlap and dead bytes
`_span_is_bounded()` tests `offset > used` then `length <= used - offset`, i.e. subtraction
before addition, as required. Zero-length spans are legal at any offset in `0..used`
inclusive. The packed key `offset * 2097152 + length` is exact: both components are bounded
by 1048576 < 2097152 and the bound check *precedes* key construction, so a hostile decoded
`payload_offset`/`payload_length` cannot overflow or alias the packing. Sorting ascending by
the packed key orders equal offsets by ascending length, which is what makes a shared
offset between a zero-length span and a live span accept rather than false-refuse: the
zero-length entry is visited first and advances the cursor by nothing. I could not construct
a state the live bump allocator can actually reach that this rejects — a zero-length
allocation always lands on the current highwater, so it can never fall strictly inside an
earlier live span.

### Exact offsets, highwater and future admission capacity
`_copy_arena_prefix()` zero-fills the owned 1 MiB buffer, copies the used prefix and assigns
`_payload_used = arena.size()`, so the saved highwater — not the sum of live lengths — governs
`payload_available()`. The suite's one-byte-too-much / exact-remainder pair is a real capacity
assertion against the owner, not a cursor compared to itself, and the follow-on drain order
and single consumed sequence are asserted. Partial-drain semantics after restore remain the
ordinary bump semantics (space is reclaimed only when the queue empties), which is the
behaviour the ruling asks to be preserved rather than changed.

### Runtime u32 / exhausted pair
`_window_sequence_is_legal()` accepts every ordinary u32 pair plus exactly `(4294967296, 0)`,
and nothing else above u32 or negative. That constant is precisely the state
`_advance_sequence()` leaves after spending the final sequence, and `_sequence_room()` returns
false for `_next_sequence_high > U32_MAX`, so a restored exhausted window keeps its records
and refuses the *next* ordinary submission with `COMMAND_SEQUENCE_EXHAUSTED` instead of
wrapping to zero. Restore consumes no sequence and never calls `_sequence_room()`. The
future schema change is correctly **not** active: `_sequence_range_refusal()` in
`save_section_pending_commands.gd` still bounds all four allocator scalars to `0..U32_MAX`, so
both `capture_into()` and `decode_into()` refuse the exhausted pair with
`SAVE_PC_SEQUENCE_RANGE`. That is the documented prerequisite of decision 0154, not a
regression.

### Ordinary guards
`submit_into`, `submit_group_into`, `submit_id_group_into`, `admit_stamped_into`,
`drain_due_into`, `clear` and `rebind_clock` all test `_barred()` as their first statement —
before `_refused_member = 0`, before any validation and before `_refuse()` can move
`_refused_count`. `_bar_submit()` deliberately bypasses `_refuse()`, so only
`out`/`_last_refusal` change; the suite proves this by priming a nonzero `_refused_member`
and reading it back after the barred calls. Barred `drain_due_into` returns false without
touching the caller's out record (asserted by re-encoding the out envelope). `clear()` keeps
its void API and reports through `last_refusal()`. `rebind_clock` refuses under either the
current or the incoming clock's barrier before `_clock` moves, and the incoming-barrier case
asserts clock identity is retained. `_init()` routes through the private `_reset_state()`, and
construction under a held barrier is tested to produce an empty window, a full arena and a
zero allocator, then to accept a restore — so the private extraction is proven, not assumed.
No privileged escape flag exists on any ordinary public API; the only privilege is the
barrier itself, whose raised bit lives inside the `LoadBarrier` token.

### Section 12 capture and two-owner apply
Capture zero-fills one `staged.payload` and writes each live span at its own offset (no
concatenation, no second 1 MiB arena — confirmed, the parent's claim holds). Every
`read_into`/`read_payload_into` return is checked and every span is bounded before a byte is
written at it. `arena_rebuild_refusal()` no longer requires contiguity, a zero base or
`sum(lengths) == highwater`; it retains shape, bound, per-row span and the sort-based
overlap/zero-hole gates. `apply()` proves record non-null, both stores non-null, clock
*object identity* (not equal tick values), held barrier, saved tick equality and both queues
empty, then runs `record_refusal`, `arena_rebuild_refusal`, `extension_refusal` and
`pending_window_refusal` over the exact bytes it will install, all before the first mutation.
Commands install first; on scheduler failure the prior empty window and exact prior allocator
pair go back through the same owner method and the bool is checked, with
`SAVE_PC_ROLLBACK_FAILED` and a held barrier on failed recovery. Nothing fallible follows a
successful scheduler install; no public `clear()`, no barrier release, no whole-world rollback
claim. `_packed_records_of()` and `_arena_prefix_of()` are private (parent claim confirmed).

### Tests: positive controls, failure snapshots, real late faults
The injected-fault cases are genuine, not flag theatre. `FaultScheduler` records
`observing.pending_count()` at the moment it refuses, and the tests assert `observed_count == 1`
— direct evidence that the economic window was **actually installed** before the scheduler
step, not merely that a rollback flag was set. The failed-recovery test additionally asserts
`_image(target) != before` and `target.pending_count() == 1`, i.e. the uncertain state is
observed rather than asserted, and that the scheduler image is byte-unchanged. The
first-install-failure test asserts neither queue moved. Both owners' states are compared as
encoded bytes (`_image()` for commands, `encode_extension_into()` for the scheduler), which is
the "encoded two-queue state, not flags only" the ruling asks for. Input isolation is proved
by mutating the caller's `records`/`arena` after a successful restore and re-comparing the
image. Counter preservation is proved from a nonzero (1,1,1) fixture. A malformed late row is
covered by corrupting ten distinct fields of the *second* record while a valid first record
and a pre-existing live window are present. Unsigned ordering is covered on **both** words —
the high-word case would be missed by low-word coverage alone and is present.

### The repaired scheduler-boundary fixture
`test_apply_refuses_a_boundary_the_scheduler_owner_rejects` now restores the target clock to
tick 4 and passes `saved_completed_tick = 4`, so `_binding_refusal()` passes on identity and
tick, and sets the incoming economic `execute_tick[0] = 5`, which is strictly future and so
cannot be the cause of the refusal. The refusal therefore genuinely originates in
`scheduler_events.extension_refusal()` (pending boundary 0 vs saved tick 4), and the test's
byte-identity assertion on both stores is meaningful. The fixture change is correct and the
test still tests what its name says.

### No stray Refusal return
`_owner_detail()` is a `String` helper ending in `return String(code)`; no unreachable
`SaveHeader.Refusal` return follows it, and `_install()`'s three exits are the success case,
the recovered-scheduler-failure case and the `SAVE_PC_ROLLBACK_FAILED` case. Parent claim
confirmed.

## Advisory items (non-blocking; none is a new regression)

1. **Window validated twice per `apply()`.** `_preflight_refusal()` calls
   `pending_window_refusal()` and `restore_pending_window()` calls it again internally, so the
   span sort and the full dead-byte walk of up to 1 MiB run twice on every load. Correct and
   deliberately defensive; if the cost matters, the bounded fix is to document the double pass
   in `_install()`'s docstring rather than to weaken either call. Do not remove the mutator's
   own validation.
2. **Two `Command` scratch instances per restore.** The ruling's cold-scratch note says "one
   decoded `Command`"; `restore_pending_window()` allocates its own `probe` and the validator
   it calls allocates another. Bounded fix: either reword the scratch note in `commands.gd`'s
   SAVE-P2-R02 block to "at most two decoded `Command` instances", or pass the mutator's probe
   into the validator. Prefer the wording change — sharing the probe would make the validator
   take caller-owned memory and weaken its purity claim.
3. **`_bytes_are_zero()` is a per-byte GDScript loop.** The codec's equivalent
   (`_is_zero_run()`) uses `bytes.slice(start, end).count(0) == end - start`, a C++ pass. The
   owner-side check walks up to 1048576 bytes in script on the load boundary. (GDScript folds
   `range()` inside a `for` header into a counted loop, so no Array is materialised — this is a
   consistency/throughput note, not a memory-bound violation.) Bounded fix: mirror the codec's
   slice/count form in `commands.gd::_bytes_are_zero()`. Behaviour is identical for the empty
   range, which both forms treat as vacuously zero.
4. **`_sorted_spans()` appends to a `PackedInt64Array` in a loop** (up to 4096 reallocations),
   where `commands.gd` correctly `resize()`s first. Bounded fix: `spans.resize(economic_count)`
   then assign by index in `save_section_pending_commands.gd::_sorted_spans()`.
5. **`extension_bytes_of()` remains public** while the two new packed-buffer helpers were made
   private. Pre-existing and used by nothing outside the module; if the intent was a uniformly
   private buffer surface, renaming it is a one-call-site change inside `apply()`. Flagged only
   so the asymmetry is a recorded choice.

## Limits of this review

- Reading only. No build, no test run, no log reproduction. The focused log was taken at face
  value; I did not verify it was produced from the exact file contents reviewed.
- Full suite, native/export builds and end-to-end save/load acceptance are **out of scope and
  not claimed**. The exhausted-allocator schema migration remains an open save prerequisite per
  decision 0154, and nothing here closes it.
- `entity_directory.gd`, `catalog.gd`, `int_math.gd` and `save_codec.gd` were treated as
  trusted collaborators and not re-reviewed.
- No source or test file was edited by this review.
