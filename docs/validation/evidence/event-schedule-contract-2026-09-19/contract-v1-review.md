# Section 11 codec contract — independent review of version 1

SAVE-S11-R01 · 2026-09-19 · review of `docs/planning/event_schedule_codec_contract.md`
(sha256 2523a65a…) against SAVE-R09-005, the 2026-09-12 distinct-form ruling (REG-R01),
`event_schedule.gd`, `save_codec.gd`, `save_header.gd` and `test_event_schedule.gd`.

**Verdict: feasible, approve for author dispatch conditional on C1–C11 below.** No
contradiction was found between the draft and any authority supplied in this packet. This
is a document review only; nothing was run, built or edited.

## 1. Scope boundary — correctly drawn

The draft implements a byte adapter over an already-ruled wire form. It introduces no event
kind, no argument domain, no production or consumption rule, no expiry and no consumer, and
it says so explicitly. That matches `event_schedule.gd`'s own header, which names the
missing kind domain and production rules as a reported blocker, and SAVE-R09-005's
requirement that those be registered *before real events are activated*. Treating the four
i32 values as storage domains only — all signed int32 permitted — is the only defensible
reading while no catalog exists. Keep the semantic-activation obligation on a separate queue
item; acceptance of this codec must not be recorded as closing it.

## 2. Exact bytes and framing — consistent

- Payload `next_sequence:i64` then N × 32-byte records, fields `kind, source_id, arg0, arg1,
  due_tick, sequence`, little-endian, length `8 + 32*N`, empty 8, full 2056. This matches
  SAVE-R09-005 verbatim and the `OFFSET_*` / `MAX_PAYLOAD_BYTES` constants transcribed in
  `event_schedule.gd` (0/4/8/12/16/24, stride 32, `8 + 32*64`).
- Count carried by the descriptor and the canonical registry, not duplicated inline. This is
  the correct reading of REG-R01's "preserve the distinct existing forms of §10, §11, §12,
  §13 and §15" and its instruction that generic owner-wrapper/column framing applies to
  §§1/2/4/5/6/7/8/9 — **not** here. The draft's refusal to add an owner wrapper is right.
- Section ID 11, section schema 1, agrees with REG-R01's baseline vector
  `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]` at position 11.
- §11 can never be a zero-byte payload: even an empty schedule encodes the 8-byte allocator.
  Descriptor `byte_length` 8 with `row_count` 0 and a CRC over those 8 bytes is therefore
  the empty case, not SAVE-R09-004's zero-length payload case. State this in the module doc
  so a later layout reader does not "optimise" the empty section to length 0.
- Outer CRC, body SHA, section placement, gapless layout and canonical logical-state hashing
  stay with their existing owners (`save_header.gd`, the layout owner, §15). Correct.

## 3. Shape, allocator, order, duplicate, refusal ordering

The draft's `record_refusal` order — null; count > 64; ragged; allocator < 0; row scan in
index order (nonnegative due tick, positive sequence, upper allocator relation); strict pair
order; uniqueness across unequal due ticks — is **exactly** the order `_validate_restore()`
and `_validate_restore_order()` already implement. Delegating to one temporary
`EventSchedule` and converting `last_refusal()` is therefore the right way to avoid a second,
divergent validator. Two consequences to pin:

- The pairwise duplicate scan is genuinely not implied by the order check (equal sequences at
  unequal due ticks sort fine). The draft's test item 3 names this; keep it.
- `next_sequence = 0` with live rows is a valid saved state (exhausted), and rows at or above
  a nonzero `next_sequence` refuse. Both are already enforced by the owner and both are named
  in the draft. Empty-and-exhausted must stay exhausted on round trip.

## 4. Stale output safety and atomic restore

`restore_rows()` validates everything before `clear()`, so a refused apply leaves the live
owner byte-identical; `state_bytes()` exists precisely to prove that. The draft's "all other
refused public methods leave caller Record and live canonical owner state unchanged" is
achievable because the owner already behaves this way and because decode parses into a
temporary Record before publication.

One hazard the draft does not name: the Output Record has no pre-required lengths, so a
*partially* successful decode must not leave some of the six arrays replaced. Publication
must replace all six arrays plus `next_sequence` after validation, never incrementally.

## 5. Validation temporary-owner memory

A fresh `EventSchedule` allocates six columns at capacity 64 → 4×4×64 + 2×8×64 = **2048 B**
packed, matching the draft's claim, plus the object and its `IntMath.IntResult` scratch.
Coexisting worst case at apply time: caller Record (≤2048 B of payload arrays) + staging
Record + validation owner (2048 B) + a 2056 B encoded buffer ≈ under 10 KB transient. That
is acceptable for a cold save/load path.

**C1.** This transient is not an architecture ledger row and must not be presented as one.
SAVE-R09-005's accounting statement is only that `next_event_sequence` moves from
`WorldRuntime` to EventSchedule with no net 8-byte change; the codec adds no canonical bytes
and claims no RSS qualification.

**C2.** Decide whether `apply()` constructs the validation temporary at all. `restore_rows()`
already validates atomically, so `apply()` could call it directly and map `last_refusal()`,
halving the allocation and removing any chance of the two paths disagreeing. If the draft
keeps the pre-check, say explicitly that a `restore_rows()` refusal *after* `record_refusal`
passed is an internal-consistency failure, and name which refusal is surfaced.

## 6. Existing diagnostic changes on capture

`read_into()` sets `_last_refusal = REFUSE_NONE` on success — an observable owner mutation.
The draft captures this correctly and allows it explicitly, including the empty-capture case
where no read occurs and the prior diagnostic is preserved. Two refinements:

**C3.** `read_into()` also sets `_last_refusal = EVENT_ROW_OUT_OF_RANGE` *and clears the
caller's Event* when it refuses. Capture only reads indices `0..count()-1`, so this path is
unreachable unless the owner is internally inconsistent; the draft's "an invalid row getter
must return an explicit refusal" should name the forwarded code (`EVENT_ROW_OUT_OF_RANGE`)
and acknowledge that reaching it leaves the owner diagnostic changed.

**C4.** `find_sequence_into()`, `cancel()` and `due_day_index_into()` also write
`_last_refusal`. Capture must not call them; state that the capture surface is exactly
`count()`, `next_sequence()`, `read_into()` and nothing else. The public getters are
sufficient — no private reflection is needed, confirming that part of the draft.

## 7. Refusal vocabulary and precedence

**C5.** Resolve the overlap between `SAVE_EVENT_ROW_COUNT` and forwarded
`EVENT_RESTORE_COUNT`. Recommended: `SAVE_EVENT_ROW_COUNT` covers only the **decode
`row_count` argument** outside 0..64; a Record whose arrays exceed 64 forwards
`EVENT_RESTORE_COUNT`. Same split for ragged/allocator/order/duplicate, which have no
`SAVE_EVENT_*` spellings and must forward.

**C6.** Decode precedence places `length != 8 + 32*N` before `negative offset`, while
`save_codec.gd` primitives check `REFUSE_NEGATIVE_OFFSET` before `REFUSE_TRUNCATED`. That is
a legitimate section-level choice, but tests assert "exact refusal precedence", so the draft
must state that the section gate runs its own order *before* any primitive is invoked, and
that a negative offset combined with a wrong length yields `SAVE_EVENT_LENGTH`.

**C7.** `EncodeResult` is specified as `ok, bytes, refusal, detail`, but every other public
method returns `SaveHeader.Refusal`, which already bundles `code` + `detail`. Either make
`EncodeResult.refusal` a `SaveHeader.Refusal` and drop `detail`, or justify the split. The
"mirrors existing section modules" claim is not verifiable from this packet — no section
module was supplied. Confirm the shape against a real one before dispatch.

## 8. Unverified inputs (confirm before dispatch, not blockers on this review)

**C8.** `SimClock.is_load_barrier_held()` and `SimClock.CALENDAR_OFFSET_TICKS`/`day_index_at`
are referenced by the draft and by `event_schedule.gd`, but `sim_clock.gd` is not in this
packet. Confirm the barrier predicate's exact name and that it is a pure query.

**C9.** `IntMath.fits_int32` exists (used by the owner), but the draft's Record columns are
`PackedInt32Array`. A caller assigning `0x80000000` into a Record column is **silently
narrowed at assignment**, before `record_refusal` can ever observe it, so no
`SAVE_EVENT_*`/`EVENT_FIELD_NOT_INT32` refusal is reachable from the Record path. Document
this: the Record's int32 typing *is* the enforcement, capture from the owner cannot produce
an out-of-range value, and tests should pin the narrowed extrema (−2147483648 / 2147483647)
rather than expecting a refusal.

## 9. Barrier and world responsibility

Correctly assigned: apply refuses on null clock or unheld barrier, never acquires or releases
it, never alters clock state; clock identity, world association and completed-boundary
coordination remain caller obligations. This matches REG-R01's load-owner item 1 (one
orchestrator holds the barrier, restores under it, publishes once). Note that §11 has no
cross-section reference to validate — unlike §4/§14 — so the codec needs no sibling-section
hook.

**C10.** `descriptor_row_count(record)` is specified only for records that already passed
`record_refusal`, and its behaviour on `null` is unstated. Either state a non-null
precondition as a hard contract or have it refuse; do not let it fault.

**C11.** State that `_count` remains a declared canonical field in REG-R01 even though the
wire form does not carry it. The canonical logical-state stream and the §11 wire form are
different artifacts; the §15 walker emits `_count` from the registry, and that is not a
duplication defect in this codec.

## 10. Tests

The six test obligations are adequate and well targeted: hand-authored golden bytes at both
extremes, exact 2056 at N=64, descriptor-counts-rows-not-capacity, nonzero outer offset with
prefix/suffix, every truncation boundary, populated-target preservation, input-byte
immutability, the equal-sequence-at-unequal-due-ticks case, exhausted `I64_MAX`, real
owner schedule/cancel/pop round trips against an uninterrupted owner, barrier failures, and
buffer-independence after mutation. Add one: a record captured from an owner whose allocator
is exhausted *while rows are live*, proving `next_sequence = 0` survives encode/decode/apply
and that no further insertion is admitted afterwards.

## 11. Disposition

Dispatch the author with C1–C11 folded into version 2 of the contract. Keep the separate
source review after integration, the focused and full suites, static gates, import and
exact-head CI before merge, and keep real event activation as an open queue obligation.
