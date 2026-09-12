# Astra follow-up — exact clock restore and save layout

2026-09-12 · RESTORE-R01 and SAVE-LAYOUT-R01. Complements, rather than replaces,
[SAVE-R09](2026-09-11_save_codec_contract.md) and
[G3](2026-09-11_ready07_save_ui_addendum.md). This is an implementation contract;
no new production restore API or codec is claimed implemented by this document.

## RESTORE-R01 — one validated assignment boundary

The report is correct: current sim_clock.gd exposes readers but no restore writer
for completed tick, debt and six counters. Its PLAYER pause setter deliberately
removes a sub-tick debt under normal command semantics. Restore is not such a
command; do not call set_pause, set_speed, advance, start_game or a queue pump
to manufacture the saved state. No simulated tick replay to reach the saved tick.

Clock owner adds exactly one public assignment operation (names below map to the
existing ten fields; all arguments are typed integers):

```gdscript
func restore_runtime(
    completed_tick: int, debt: int, requested_speed: int, pause_mask: int,
    fallback_count: int, diagnostic_pause_count: int,
    acknowledged_catchup_resets: int, acknowledged_ticks_discarded: int,
    subtick_debt_discards: int, day_boundaries_crossed: int
) -> bool:
```

This is a required API signature, not an implementation. A pure validation helper
may share its checks with the codec, returning an explicit refusal reason without
mutating the clock. Caller must hold the load/restore barrier and be outside any
advance/step/boundary callback. The operation itself never opens that barrier.

Validate EVERY argument before the first assignment:

- completed_tick nonnegative and representable by the current offset-calendar
  arithmetic: at most `INT64_MAX - CALENDAR_OFFSET_TICKS`. This is an arithmetic
  safety bound derived from the existing `tick+4500`, not a new calendar design.
  Header completed tick and section1 tick must match before this API is invoked.
- debt and each of the six counters in `0..INT64_MAX`.
- requested_speed exactly1,2,4; effective paused speed0 is derived from mask,
  never an accepted requested speed. Refuse3 and0 here.
- pause_mask nonnegative and contains only the existing PLAYER1, MENU2,
  CRITICAL4, VICTORY8, LOAD16 bits. Composite valid masks and zero are legal.

On refusal return false with ALL existing runtime fields, transient diagnostics
and callbacks unchanged. Report the validator's reason through the save owner's
result; do not partially restore and then repair. On success assign all ten
fields verbatim, then clear only the transient `_last_error`/`_last_diagnostic`
strings. Arithmetic scratch need not be serialized or allocated again. No signal,
calendar/day notification, RNG draw, callback, queue admission/drain, overload
step, tick, debt adjustment or counter increment occurs. Do not recompute recorded
counters from the tick or impose guessed cross-counter relationships.

The signature owns no queue or host timestamp. Preserve exactly one clock's
existing scalar allocation: this adds no duplicate WorldRuntime store. Packed
file widths follow the declared section1 schema, not the width of a GDScript
argument. Debt/counters remain saved but excluded from canonical state per G3.
Normal PLAYER-pause behavior is unchanged by this ruling; restoration bypasses
that behavior. Subsequent arithmetic must continue to refuse overflow rather than
wrap or clamp; restoring a representable value is not permission to overflow
it on the next normal operation. Calendar terminal-boundary fixtures must exercise
a checked next_tick and `next_tick+CALENDAR_OFFSET_TICKS` before ANY debt
subtraction, simulation step, completed-tick/counter increment or day callback.
Overflow refuses before those effects and retains owed debt. A caller must not
reach the old unchecked increment after already simulating a tick.

## LOAD integration — preserve the restored state until publication

The save/GameManager integration owner adds an out-of-band load-in-progress guard
(or an equivalent existing coordinator barrier) checked BEFORE both host advance
and scheduler pumping, including direct test/service entry points. The same
barrier must also guard EVERY operational clock/queue mutator: pause/resume/speed
admission, direct setters, acknowledgement-without-catchup, start_game, clear,
rebind and direct advance/pump. Share the coordinator guard with clock/queue
objects while mutable raw access exists; a GameManager-only check is insufficient.
Only the explicitly owned restore/install operations may write under that barrier.
Ordinary UI/service calls refuse LOADING without altering saved state or queues.
UI may display
LOAD, but this transient guard is not a new queued scheduler operation and is
not OR-ed into the serialized/canonical logical pause mask. If adding a scalar,
record its transient allocation; do not charge a second clock or second world.

1. Reach a completed tick and scheduler barrier; freeze new world-affecting input.
   Capture the original logical mask/debt/counters/queues for the verified rollback
   checkpoint before any operational pause setter could change them. Loading may
   span many host frames, all barred from clock/queue advancement.
2. Validate incoming header, section1 fields, section12 and all other required
   state into the existing bounded inactive-checkpoint workflow. No partial live
   restore occurs during validation. Build no second full mutable world.
3. During the single-world installation phase, invoke restore_runtime once, then
   restore section12's exact pending queue/control state under the same guard.
   Rebind callbacks/clock references without pumping. Do NOT call start_game:
   that API clears the queue, replaces the clock and queues a player resume.
4. Rebuild derived views and recompute the canonical digest from the exact logical
   saved state. No transient LOAD overlay enters that digest. Publish only after
   all verification passes. Publication explicitly sets `_started=true` and
   derives PLAYING/PAUSED from the restored logical mask while the guard still
   holds, including a successful load from BOOT. UI may receive one post-publication refresh,
   never retroactive tick/day/overload events.
5. At release of the external guard, reset GameManager's host sample origin to
   the current monotonic time. Loading elapsed time adds no debt. Preserve every
   saved logical pause bit, including any existing LOAD bit; never blindly clear
   the LOAD bit because this particular load operation finished. Pending scheduler
   commands remain pending until the next normal scheduler boundary.
6. On failure after array reuse, restore the verified rollback checkpoint through
   the SAME assignment API and queue restoration, still guarded. Reset host origin
   when recovering too. Restore the previous coordinator `_started/_state` on
   rollback; failed initial load stays BOOT with no partial world. If rollback
   fails after live-array reuse, retain the existing explicit unrecoverable
   LOAD state and files; do not release a partial world.

## RESTORE-R01 acceptance and ownership

Clock coder owns sim_clock.gd and its focused tests. Save/integration owner owns
GameManager/load coordinator and production section1/12 wiring; no competing
writers of those shared files. Independent reviewer checks API/restore call sites.

- Direct restore with debt1,999999,1000000 and2500001, each requested speed1/2/4,
  masks0,PLAYER,MENU|CRITICAL,PLAYER|VICTORY and all31. Every accepted scalar is
  exact; PLAYER with999999 must NOT zero debt or increment discard counters.
- Give six different nonzero counters; all survive exactly. Reject negative fields,
  invalid speed/mask and calendar-overflow tick, including a late invalid argument,
  with byte-identical pre-call state and no signal/callback invocations.
- Restore at13500 and18000; no midnight notification is replayed during restore.
  Subsequent real crossing is delivered exactly once by the normal clock.
- Restore a paused pending scheduler queue; multiple load frames pump nothing.
  Its pending records apply once, in order, after the guard releases. No implicit
  resume and no loss of MENU/CRITICAL/VICTORY/PLAYER holds.
- Compare uninterrupted versus restored snapshots under identical subsequent
  elapsed-microsecond/event inputs, including nonzero retained debt and speed
  changes. Compare saved debt/counters separately from the canonical hash.
- Load successfully from BOOT without start_game, preserving saved pause/debt and
  queue. Attempt every public mutator and raw-object route during the barrier;
  none changes clock/queue state. Reject next-tick overflow before a step callback.
- Inject section12/final-digest failure after clock installation: verified rollback
  restores original clock/queue, loading time is excluded, and no event was emitted.

This API blocks complete09.3 load/rollback continuation acceptance until implemented.
Independent disk checkpoint, validation, file rotation and I/O fault-injection work
can proceed now. A documented API is not itself a passing09.3 result.

## SAVE-LAYOUT-R01

**Packed stores use column-major bytes.** Field schema order is the outer loop;
ascending physical slot is the inner loop. SoA does not mathematically force a
wire order; this ruling explicitly chooses it. Never infer record-major packing
from the phrase "ascending slot". Fixed record formats listed below remain
intentional exceptions, not contradictions.

### New explicit block framing for sections3/4/5

```
section = store_count:u32, store blocks in registered order
store = owner_key:utf8-u32, owner_schema_version:u32,
        primary_count:u64, payload_byte_length:u64, payload
ordinary column payload = for each schema field:
                         element_count:u64, tightly packed LE values
```

owner_key is unique within its section, nonempty ASCII, max256 bytes. Registry
order is section ID then ASCII owner key; fields retain their declared ordinal.
No field name/type is repeated inside payload; the supported owner schema fixes
both. The registry bounds store_count and every capacity/stride; validate count,
checked multiplication, remaining bytes, exact block consumption and section EOF
before allocating or writing a store. Decode validation is independent of restore.

For section3 there is exactly one entity_directory block, primary_count equal to
the compiled directory capacity (352418 in the reviewed baseline). Column order:
`_active:u8`, `_generation:i32`, `_retired:u8`, `_persistent_id:i32`, `_kind:i32`,
`_typed_row:i32`. Every column covers full capacity. Descriptor row_count is that
capacity, never the count of living residents.

For section4 each registered component owner gets a block. primary_count is its
full physical capacity. Occupancy first where the store owns it, then its OWN
generation/retirement columns, then remaining fields in frozen schema order.
Reference generation fields are ordinary references checked against their actual
owner, not invented local generations. Fixed-stride arrays have
`element_count=primary_count*stride`, with slot-major/within-slot-index flattening
inside that SINGLE field column. Section4 descriptor row_count is the checked sum
of block primary_count values, not unique world entities.

For section5 the same block wrapper applies; the owner schema chooses ONE form:

- Variable-child payload: `owner_count:u64` (equals primary_count), exactly
  `owner_count` child_count:u32 values, `total_child_count:u64`, then each declared
  child field as `element_count:u64 + column values`. Sum child_count equals total;
  fields flatten ascending owner slot then child index, and each field's element
  count equals total times its declared stride. No count-first-per-child AoS loop.
- Fixed-stride child payload: ordinary column payload over full owner_count×stride,
  including declared unused values. primary_count is owner_count.
- Slot/linked-arena payload: ordinary columns at full physical arena capacity,
  including occupancy/link/order columns and holes. primary_count is arena capacity.
  Intrusive building/room/furniture/job chains use this form; do not compact them
  into a different logical child ordering or duplicate links with different authority.

Section5 descriptor row_count is the checked sum of block primary_count values.
An owner may not switch forms without a versioned schema change. Empty-variable
children still have their required framing, not a zero-byte section.

### Canonical unused values — correction to the old zero-fill sentence

Inactive fields encode their DECLARED canonical unused values. Use zero only
where the owner declares zero. For example, directory inactive kind/typed_row
and null reference slots retain -1; null reference generations remain0.
Preserve all generations and retirement state, including free slots. Do not
silently normalize an invalid used-row value into a valid null. Apply the same
unused-value rule to SAVE-R09's canonical hash walker, otherwise valid saves and
hashes would disagree. Frozen owner schemas must enumerate these values.

### RNG and fixed-format exceptions

Section10 is exactly `stream_count:u32=9`, then all9 state:i32 bit patterns in
stream-ID order, then all9 draw_count:i64 values:112 bytes, row_count9. There is
no generic store wrapper for this compact schema. Recover unsigned state bits
before restore_stream and validate the retired HUNTING stream. Seed remains
section1 state; do not recreate draws to reach the saved state.

Retain the existing explicit formats: section1's44-byte provenance prefix;
section2's u32-sized opaque JSON artifact; section11's i64 sequence allocator
plus32-byte records; section12's schema2 prefix,64-byte economic records,payload
and record-major SCHQ0001 extension; section13's24-byte Chronicle records;
section15's32-byte digest. Their record layouts override the packed-store default.
The remainder of section1 and sections6/7/8/9/14 still require registered owner
schemas and exact bounded framing before production serialization. This ruling
does not pretend those complete byte maps exist.

### Version and acceptance

Adopt the above as the initial section3/4/5/10 schema1 framing, retaining outer
format1, section12 schema2 and nested SCHQ0001 schema1. No body codec for3/4/5/10
was found in the reviewed main tree; inspect current executor worktrees before
integration and never silently reinterpret already emitted incompatible fixtures.
New LifeStage state is a separate semantic schema change: when it lands after the
published baseline registry, increment affected owner/section4 versions and rules
identity as SAVE-R09 requires. Catalog JSON content changes update catalog identity
without changing section2's opaque-artifact framing version.

The header owner must replace current tests permitting gaps/unknown section
versions with the already ruled strict versions, ordered gapless descriptors,
flags0 and reserved-zero validation. Those changes conform to format1.

Pin bytes with unequal-width, non-symmetric columns. For A:i32=[1,258] and
B:i64=[3,4], VALUES ONLY (excluding framing) must equal
`010000000201000003000000000000000400000000000000`.
Also test free/retired generations, -1 sentinels, fixed strides, uneven variable
child counts, linked holes, malformed counts, exact EOF and every fixed-record
exception. Production save/next-tick parity remains separate evidence.
