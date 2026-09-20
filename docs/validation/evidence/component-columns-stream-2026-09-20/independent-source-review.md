# Independent source review — section 4 streaming envelope

Date: 2026-09-20. Separate author session, Claude Opus. Scope: the three new production files
(`save_component_columns_schema.gd`, `save_section_component_columns.gd`,
`tools/generate_component_columns_schema.py`), the black-box generator tests and both Godot
suites, read against SAVE-S4-STREAM-R01 v2, ADR 0169 and the parent's repair notes. Source
reading only; nothing here was executed and no production file was edited. The first focused run
(20 tests / 11764 assertions / 0 failures) is noted but is not the basis of any judgement below.

## Verdict

**No blockers.** Nine ranked non-blocking findings follow, the strongest being two preflight
branches that no test can kill.

## What I re-derived independently

I recomputed the framing from the checked-in constants rather than trusting any total:

- Buildings: 4 u8 columns (1024 + 16384 + 81920 + 16384 = 115712 bytes) and 25 i32 columns
  (9×1024 + 8×16384 + 8×81920 = 795648 elements = 3182592 bytes), plus 29×8 count prefixes and a
  20-byte child header/extent block → payload **3298556**, block 24 + 9 + payload = **3298589**,
  next offset 4 + 3298589 = **3298593**. All three match `OWNER_PAYLOAD_BYTES[0]`,
  `OWNER_BLOCK_BYTES[0]` and `OWNER_OFFSETS[1]`, and the decoder's literal 3298593 boundary
  assertion.
- Buildings wrapper: 4 + 9 key + 4 + 8 + 8 + 4 + 2×8 = **53**, equal to
  `OWNER_BLOCK_BYTES[0] − OWNER_PAYLOAD_BYTES[0] + 4 + 16` and to the goldens' framing_hex length.
- Owner keys total 153 UTF-8 bytes; framing = 4 + 18×24 + 153 + 18×4 + 5×8 + 298×8 = **3085**;
  12947565 − 3085 = **12944480** value bytes, and the child header/extent surcharge is 72 + 40 =
  **112**, exactly the contract's "+112 over the ordinary-column census".
- Primaries sum to **193184**; `OWNER_OFFSETS[17] + OWNER_BLOCK_BYTES[17]` = 12932095 + 15470 =
  **12947565**.
- Construction: payload 4893828 − 4 child header − 16×8 counts = **4893696** owner value bytes;
  largest single field 82944 × 8 = **663552**. The bound 4893696 + 3×65536 + 2×663552 =
  **6417408** is arithmetically exact.

The parent's regenerated region is therefore internally consistent and consistent with the
contract literals. The generator's own `check_arithmetic` re-derives the same numbers plus the
widest wrapper (53) and child overhead (112), so table and tool agree without either being the
sole oracle: the Python wire fixture takes counts from `fixed-column-census.json` and offsets from
the layout and asserts `at == section_offset` and `at − start == block_bytes` per owner, so a
layout/census divergence breaks the oracle rather than being papered over.

## Contract clauses I checked line by line, and which hold

- **Preflight order.** `decode_preflight_refusal` runs schema → rows → length → metadata → byte
  order; `encode_preflight_refusal` drops the length step. Matches the contract exactly.
- **State before size before framing.** `accept_chunk` tests `failed()`, then
  `_owners_done or _ready` (STATE), then exact size (CHUNK), then byte-for-byte framing (FRAME).
  The suite pins this with a zero-length chunk offered to a ready cursor.
- **Allocate only after the whole wrapper matches.** `_accept_framing` compares the whole array
  first, calls `_allocate_owner()` only on stage 1, and advances `_consumed` *after* allocation
  succeeds. A hostile payload_length can never size anything: the comparison is whole-array
  equality against compiled bytes. The high byte of payload_length is wrapper offset 32 and is an
  explicit witness in `test_each_wrapper_member_is_checked_before_owner_allocation`.
- **No caller-byte retention.** `_pending.append_array(bytes)` copies; `install_column`'s u8 path
  installs the decoder's own `_pending`, which is then reassigned. `column_fragment` always
  returns a fresh `slice()`/`to_byte_array()`, so an emitted chunk never aliases a record column.
- **Exact signed bits.** i32/i64 travel through `to_byte_array()`/`to_int32_array()`/
  `to_int64_array()` with no clamping; u8 bytes are installed verbatim. The patterned fixture
  drives row 0/1/2 to INT32_MIN/MAX, INT64_MIN/MAX and −1 and non-boolean u8, and pins a
  whole-section SHA-256 from an independent Python emitter.
- **Single use, sticky first error, first-error order.** Both `_fail()` bodies refuse to overwrite
  `_code`; every output wrapper refuses with `_code`/`_detail`, not with the local reason. No
  `reset()` exists on either cursor.
- **Partial publication impossible.** `_ready` is set only in `_install_field` after the last
  field; `take_owner_into` requires `_ready` *and* a nonnull record; `_drop()` nulls the private
  record on any failure. `OwnerResult.refuse()` clears `record`.
- **Earlier record and input immutability.** The decoder holds no reference to a transferred
  record; the double-take test shows a separately retained record's first and last columns
  unchanged after a later STATE refusal, and the wrapper-mutation test re-compares the hostile
  input buffer.
- **Typed shapes.** `FramedOwner` buckets are `Array[PackedByteArray]/[PackedInt32Array]/
  [PackedInt64Array]` ordered by `storage_index`; an invalid owner or an unsupported width leaves
  `owner == -1` with all buckets cleared, which `owner_shape_refusal` then refuses.
- **Setter discipline.** `_writable_index` validates ordinal, type and exact extent before the
  slot is emptied and exactly one column is duplicated, so a refusal changes nothing and no old
  column is alive beside its replacement.
- **Invalid `field_type` returns 0.** Restored as the contract requires; every internal caller
  reaches it only after `field_valid`/`owner_valid`, and the module header states plainly that
  zero is not an error sentinel.

## Memory: is 6417408 actual?

Yes, and conservatively so. During Construction the record holds 4893696 value bytes minus the
current field, which `_begin_field` releases before staging starts. The peak for a field is
staging + converted column = 2f, so the owner peak is ≈ 4893696 + f ≤ 5557248, plus at most three
65536-byte windows (caller chunk, `slice()`, `to_byte_array()`) — under the charged 6417408. The
encoder peak is lower: it borrows the record and allocates two windows per fragment. Nothing
retains a second whole owner, and no whole-section buffer or 18-record array exists anywhere.

Two honest qualifications. (1) The suite itself peaks at roughly two copies of one owner
(≈9.8 MB for Construction) because the round trip holds `expected` beside `result.record` for the
comparison; both are nulled before the next owner is bound, so it never retains an adjacent pair,
but the suite demonstrates protocol, not the budget. (2) Nothing here is measured RSS, and the
`Array`-of-Variant metadata overhead below is genuinely outside the 10536 figure.

## Shared 10536 logical metadata

The file contains exactly the 15 const arrays the accounting names: ten owner integer columns
(18 each = 180), two field integer columns (298 each = 596) and five child extents = **781** cells
× 8 = 6248, plus 18 owner keys and 298 field keys = 4288 claimed UTF-8 bytes, total **10536**. I
re-counted the 781 cells and the 153 owner-key bytes exactly; I did not hand-recount all 298 field
keys, so 4288 implies 4135 field-key bytes (mean 13.9), which is consistent with keys such as
`_habitat_protected_fraction` and is pinned by `ready07_arithmetic.py`. The figure is a *logical
wire* payload: these are untyped `Array`s of Variant and Godot Strings are not UTF-8 internally,
so actual resident cost is a multiple of 10536. ADR 0169 already excludes headers, Variant and
native code and calls them unmeasured, so this is disclosed rather than hidden — see L7.

## Required mutants — all killable

1. *Omit child-extent comparison* — wrapper offsets 37 and 45 are witnesses.
2. *Omit payload-length comparison* — offsets 25 and 32 (its high byte) are witnesses.
3. *Swap equal-width/equal-length columns* — **not** killed by the stream round trip alone: a
   permutation applied consistently inside `storage_index` cancels between setter and accessor and
   leaves the golden SHA intact. It is killed by
   `test_every_field_matches_registry_and_explicit_source_count_layout`, which recomputes the
   bucket index from the registry type codes. A one-sided swap in the decoder is separately killed
   by the patterned per-field comparison. Worth recording that the kill lives in the schema suite.
4. *Allow wrong owner order* — encoder `bind_owner` OWNER refusal is asserted; the decoder side is
   covered implicitly because the expected wrapper is compiled for `_owner`.
5. *Publish a partial owner* — `test_initial_decode_read_sizes_...` asserts STATE and a null record
   after only the wrapper has arrived.
6. *Omit section-length preflight* — lengths 12947564/12947566/0/−1/MAX64 all assert LENGTH.

## Findings, ranked

**M1 (medium-low) — two preflight branches no test can kill.**
`save_section_component_columns.gd`, `encode_preflight_refusal()` / `decode_preflight_refusal()`.
Witness: delete the trailing `return byte_order_refusal()` (return `accepted()` instead), or delete
the `Schema.schema_refusal()` step, and every one of the 20 tests still passes — the in-tree host
is little-endian and the const metadata is always coherent, so neither branch is ever false.
Smallest repair: add to `test_save_section_component_columns.gd` a test asserting
`Section.byte_order_refusal().is_ok()` plus a source-level check that
`FileAccess.get_file_as_string("res://scripts/core/save_section_component_columns.gd")` contains
`byte_order_refusal()` three times and `Schema.schema_refusal()` twice. That pins the call sites
without pretending a big-endian host was exercised, which the contract explicitly forbids.

**M2 (low-medium) — no float guard.** The module header states "there is no float in this file and
there must never be one", but unlike `save_codec.gd` (whose suite greps its own source) nothing
enforces it. Repair: one grep test over both new production files for `float`/`0.0`/`/ 2.0`.

**L3 — generator numeric-token check covers only the layout.**
`tools/generate_component_columns_schema.py:main()` calls `check_integer_tokens(layout)` but not
on `registry`. A registry `"type_code": 2.0` or `"owner_schema_version": true` compares equal in
`check_registry_parity` and is silently accepted. Emitted values are taken from the layout, so the
table cannot be corrupted — this masks a parity failure rather than producing one, which is why it
is low. Repair: `check_integer_tokens(registry, "registry")` beside the layout call, with a
negative fixture in `tools/test_component_columns_schema.py`.

**L4 — three untested wrapper high bytes.** The witness list `[0,4,13,17,25,32,33,37,45]` omits
offset 24 (primary_count high byte) and 44/52 (child-extent high bytes). Since the comparison is
whole-array equality these are witnesses, not coverage of distinct code, but the test name claims
"each wrapper member". Repair: extend the array to `[...,24,44,52]`.

**L5 — one unreachable defensive branch and one ambiguous zero.** `DecodeCursor._accept_values()`
refuses on `bytes.size() % width != 0`, which the preceding exact-size check makes unreachable;
and `next_read_size()` returns 0 for "ready", "complete" and "failed" alike. The zero is
disambiguated by `owner_ready()`/`is_complete()`/`refusal()` and `accept_chunk` refuses STATE
before size in all three, so nothing is exploitable. No repair needed; do not count that branch as
exercised.

**L6 — `SECTION_ID` is declared and never read.** Documentation value only; harmless.

**L7 — metadata stored as untyped `Array`.** Every lookup pays a Variant unbox (`int(...)`) and the
real footprint is several times the 10536 logical payload. ADR 0169 excludes that overhead
explicitly, so this is not a contract breach; if a future measurement matters, `static var`
`PackedInt32Array`/`PackedStringArray` tables built once would cut it sharply (const packed arrays
may not be a valid constant expression in GDScript, hence `static var`).

**L8 — `_pending.append_array()` reallocs per fragment.** The largest field arrives in 11 fragments
and each append is an exact resize, so assembly copies O(n²) bytes (~7 MB for one 663552-byte
field) and transiently holds 2f. Both stay inside the charged bound and this is an explicitly cold
path; GDScript has no bulk blit-at-offset, so a `resize()`-once alternative would need a per-byte
loop and be worse. Recorded as a known allocation lifetime, not a repair.

**L9 — generator defensive gaps.** `check_extent_bindings()` would raise `KeyError` (a traceback,
which its own harness treats as a failure mode) if `PRIMARY_FIELDS` lacked an owner, and its
`counts` dict would silently collapse duplicate field keys within an owner. Both are unreachable
because `check_registry_parity` pins owner keys and field keys/ordinals first. Optional repair: a
`refuse()` guard on a missing binding and on `len(counts) != len(owner["fields"])`.

## Parent repairs, assessed

The regenerated region reproduces under my own arithmetic (above), so the manual-table defect is
genuinely gone rather than re-pinned to itself. The splice now requires exactly one ordered
whole-line BEGIN/END pair and preserves the remainder verbatim, with four marker fixtures covering
missing, duplicate and reversed markers. The named `PRIMARY_FIELDS`/`CHILD_FIELDS` bindings fix the
real hole the black-box tests exposed: Buildings' reversed `[81920, 16384]` and OrchardHive's
balanced 1024/1024 pair are now distinguishable, and the balanced-but-wrong primary fixture guards
the summation shortcut. `check_integer_tokens` correctly tests `bool` before `float` (Python's
`isinstance(True, int)` would otherwise let a boolean through). `--check` writes nothing; the
failure fixtures run *without* `--check`, so a missing refusal would show up as a real write.

## Not blockers

Excluded caller misuse: mutating a borrowed encoder record mid-emission, retaining a prior owner
via a live `OwnerResult` while feeding the next wrapper (the adjacent-pair 9715712 figure), or
passing `null` to `take_owner_into` on a ready cursor and thereby losing that owner to the sticky
STATE refusal — all are documented consequences of the stated conditional lifetime contract, which
the decoder cannot enforce. Gameplay semantics, occupancy, blanks, CRC, digests, coupled-section
atomicity, the 18 semantic validators and the capture/apply adapters are deliberately outside this
layer; constructor zeros remain arbitrary wire data and frame acceptance authorises nothing.

## Function length

Only `_owner_payload_refusal()` (~32 physical lines including signature and a one-line docstring)
and the test helper `_stream_round_trip()` (~58) exceed 30 lines. Both are dense logic — extent
and type validation over two loops, and a full encode/decode/compare/golden loop respectively —
not comment padding. The long `##` headers on both production files are module documentation in
the established `save_codec.gd`/`save_header.gd` style and sit outside any function.

## Honest limits of this review

Source reading only: no run, no measurement, no editor import. Little-endian behaviour is assumed,
not demonstrated on a big-endian host. The 4288 field-key byte total was not hand-recounted. The
20-test result is consistent with what I read but is not the evidence for any statement above.
