# Independent source review — section 11 event schedule codec

SAVE-S11-R01 v2 · ADR 0161 · 2026-09-19 · independent reviewer (separate session)

Scope: source review of `godot/scripts/core/save_section_event_schedule.gd` against the accepted
contract, read together with `event_schedule.gd`, `save_codec.gd`, `sim_clock.gd`, the
parent-authored `test/test_save_section_event_schedule.gd` and the focused run log. I authored no
code and no tests, ran nothing, and reviewed only the sources supplied with this packet. Nothing
below should be read as evidence that section 11 is wired into a world save, or that any event is
activated; the module disclaims both and no coordinator appears in the reviewed sources.

**Verdict: accept. No defect found.** Three non-blocking observations are recorded at the end,
each with a concrete remedy, and none of them requires a source change.

## Wire form

The frozen payload is `next_sequence:i64` then N 32-byte records in the order
`kind, source_id, arg0, arg1, due_tick, sequence`, little-endian, length `8 + 32*N`.
`encode_section()` writes exactly that: one `write_i64`, then per row four `write_i32` followed by
two `write_i64`. `_read_payload()` reads the same sequence in the same order, so encode and decode
cannot drift apart in field order without both changing. `SaveCodec`'s writers and readers go
through Godot's `encode_*`/`decode_*` at explicit offsets, which is the little-endian guarantee
ARCH-SAVE-001 requires; nothing in this module packs a struct or dumps native memory.

No owner wrapper and no inline count is emitted. N reaches the decoder only as the descriptor's
`row_count`, and `descriptor_row_count_into()` returns `kind.size()` rather than the 64-row
capacity. `EMPTY_SECTION_BYTES` is 8, not zero, and `MAX_SECTION_BYTES` is 2056. `SECTION_ID`,
`MAX_ROWS` and `RECORD_BYTES` are taken from `EventSchedule` rather than restated, so the codec
and the owner cannot disagree about 11, 64 or 32.

I checked the three literal goldens by hand rather than trusting the assertions:

* empty, allocator 1 → `0100000000000000` (8 bytes);
* empty, exhausted → `0000000000000000` (8 bytes, exhaustion preserved, not normalised to 1);
* one extremum row → `0000000000000000` `00000080` `ffffff7f` `ffffffff` `00000000`
  `0100000001000000` `ffffffffffffff7f`.

That last decomposes to allocator 0, `kind = INT32_MIN`, `source_id = INT32_MAX`, `arg0 = -1`,
`arg1 = 0`, `due_tick = 4294967297` (a value beyond 32 bits), `sequence = INT64_MAX` — 80 hex
characters, 40 bytes, exactly `8 + 32*1`, with the four i32 columns preceding the two i64 columns
at the hand-authored offsets the owner's `OFFSET_*` constants declare. The full-capacity case is
2056 bytes.

## Variables, shape and validation order

`Record` carries six independently-declared packed columns and no count scalar; `row_count()` is
`kind.size()`. The columns start empty and carry no pre-required length, which is right for a
variable-row section: a successful decode replaces all six outright rather than writing into a
fixed shape. `next_sequence` defaults to 1.

`record_refusal()` checks null, `rows > 64`, raggedness and a negative allocator itself — all four
before anything is allocated — and then delegates every remaining rule to one temporary
`EventSchedule` through `restore_rows()`. That is the correct structural choice and matches ADR
0161: the allocator relation, the strict `(due_tick, sequence)` order and the O(n²) pairwise
uniqueness scan exist once, in the owner. Count above 64 forwards `EVENT_RESTORE_COUNT`, as the
contract requires, and `SAVE_EVENT_ROW_COUNT` is used only for the descriptor argument in
`decode_section_into()` — I confirmed it appears nowhere else.

Duplicate preservation is genuinely distinct from ordering here, and the delegation preserves the
owner's precedence: `_validate_restore_order()` runs the adjacency check over all rows first and
only then the pairwise scan, so two rows sharing a sequence at *equal* due ticks refuse with
`EVENT_RESTORE_ORDER` while the same sequence at *unequal* due ticks — perfectly sorted — refuses
with `EVENT_RESTORE_DUPLICATE_SEQUENCE`. The tests pin both directions, which is what makes the
uniqueness scan observable rather than incidental.

The four i32 columns are treated as storage domains only. No kind enum, argument domain, producer,
expiry or consumer appears anywhere in the file, and the header says so explicitly. Int32 narrowing
is documented as a storage property rather than a detection mechanism, which is honest: a caller
assigning `0x80000000` has already stored `INT32_MIN` before validation runs.

## Decode bounds and atomic publication

The section gate runs in the ruled order: schema, `row_count` outside 0..64, `length != 8 + 32*N`,
negative offset, `offset > bytes.size()`, `length > bytes.size() - offset`, null output. A wrong
length therefore wins over a negative offset, as specified. The remainder is computed by
subtraction only after `offset > bytes.size()` is excluded, so `offset + length` is never formed and
a huge claimed length cannot wrap into looking small. `row_count` is bounded to 64 before any
column is sized, so a length claim can allocate at most 2048 bytes of columns.

Parsing goes into a local `Record`; publication is a single `out.copy_from(parsed)` after
`record_refusal()` accepts. A truncated read, a semantically invalid row and a null output all
return before that call, so a refused decode leaves the caller's populated target byte-identical —
including the case where the target previously held a *different* row count, which is the failure a
variable-length section is most exposed to. `SaveCodec.Reader`'s sticky refusal means one truncated
field stops the whole parse rather than letting the loop run on.

No aliasing survives any path. `copy_from()` duplicates all six buffers, so a Record whose `arg0`
and `arg1` are literally the same array still publishes as independent columns; the decoded Record
is independent of the input `PackedByteArray`; and `apply()` hands the record's arrays to
`restore_rows()`, which copies element-wise into the owner's pre-sized columns, so mutating the
source afterwards cannot reach live state. I traced each of these three in the source rather than
relying on the assertions.

## Capture, continuation and owner diagnostics

`capture_into()` gates on null store, null output and a count outside 0..64, stages the allocator
*before* any row, and publishes only after the staged Record validates. The count gate precedes the
`resize()` calls, so a corrupt negative live count cannot reach a negative resize. The only
owner-visible effect is the allowed one: `read_into()` clears `last_refusal()` on success and sets
`EVENT_ROW_OUT_OF_RANGE` on failure. An empty capture performs no read at all and so preserves the
owner's existing diagnostic — I confirmed the loop body is unreachable at `rows == 0`. No canonical
field, allocator, row, scheduling operation or `_math` scratch is written by any capture path, and
no private owner state is reached by reflection from the module.

Continuation is real rather than asserted. After a schedule/cancel round trip the restored owner
issues the same next sequence as an uninterrupted one, pops in the same `(due_tick, sequence)`
order, and reproduces the full 64-row state image including the zeroed unused tail — the last of
those is what proves `restore_rows()` installs the exact count and allocator rather than leaving
residue from the target's prior rows. Exhaustion survives: allocator 0 with live rows loads, reports
`is_sequence_exhausted()`, and refuses further insertion without changing a canonical byte.

## Apply

`apply()` gates null record, null store, null clock and `!clock.is_load_barrier_held()` in that
order, then calls `restore_rows()` directly. There is no validation owner inside apply, which is
correct: `restore_rows()` validates its entire input before `clear()`, so a refusal leaves the live
store byte-identical and its code is forwarded unchanged. The barrier is only read —
`is_load_barrier_held()` is a pure predicate on `sim_clock.gd`, and nothing here acquires, releases
or otherwise touches clock state. Clock identity and world association remain caller obligations,
which the module states rather than pretends to check.

## Observations (non-blocking)

1. `encode_section(record, out)` and `descriptor_row_count_into(record, out)` do not null-check
   `out`; a null would fault rather than refuse. This matches the contract ("Caller supplies a
   nonnull IntResult") and the sibling section modules, so it is a documented caller obligation,
   not a defect. Remedy if ever tightened: add the check to the two entry points only, never to
   `Record.copy_from()`.
2. Test gap, not a source gap: `rows == 0` is covered with allocator 1 and with allocator 0, but not
   with a *high non-exhausted* cursor. Concrete addition: a Record with no rows and
   `next_sequence = 500` should encode to the 8-byte golden `f401000000000000`, decode, apply, then
   report `next_sequence() == 500` and issue 500 on the next schedule.
3. Test gap: the decode bound `offset == bytes.size()` exactly is not exercised; the nearest cases
   are `offset = 1` and a huge offset. Concrete addition: decode at `offset = bytes.size()` with a
   valid 40-byte length and expect `SAVE_EVENT_TRUNCATED` with the target unchanged.

The focused run recorded 41 tests, 528 assertions, 0 failures. The full suite, static gates, import
and exact-head CI remain outstanding and are not evidenced here. Semantic event activation stays a
separate queue obligation under PLAN-COMMUNITY-EVENTS.
