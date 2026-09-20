# Follow-up review — SAVE-S4-STREAM-R01 draft 2

Date 2026-09-20. Bounded scope: does draft 2 close B1-B5 / A1-A10 from
`stream-contract-review.md`, and does any implementer-blocking ambiguity or wrong arithmetic
remain? Inputs: `component_columns_stream_contract.md` (draft 2),
`component_columns_layout.json`, the draft 1 review, `stream-draft1-disposition.md`,
`independent_wire_fixture.py`, `independent-wire-goldens.json`. Nothing was executed; every
number below was recomputed by hand from the layout artifact. No semantic-validity, capture,
apply or SAVE-S4-CODEC completion claim is made or implied here.

## Verdict

Draft 2 is dispatchable. All five blockers and all ten ambiguities are closed in text, and I
found no arithmetic error anywhere in the layout artifact or the contract. Three non-blocking
documentation fixes (F1-F3) should be folded in, but none of them requires a re-review before
an author starts.

## Arithmetic recomputed independently

I recomputed every owner from its field list rather than trusting any declared total.
Per-owner value bytes: buildings 3298304, construction 4893696, farming 266240,
field_policy 44288, fishing 5344, forage 30336, injury 20992, jobs 685568, movement 32768,
needs 57344, orchard_hive 102400, priorities 7680, residents 102912, resource_nodes 172032,
schedule 17920, transforms 3151872, work 39424, world_init 15360. These sum to **12944480**,
matching the contract.

Payload is `4 + 8*extents + 8*fields + value_bytes` and block is `24 + len(key) + payload`.
Every one of the 18 `payload_bytes` and `block_bytes` entries reproduces exactly, and the
section_offset chain closes: 4 -> 3298593 -> 8192457 -> 8458852 -> 8503348 -> 8508903 ->
8539433 -> 8560547 -> 9246459 -> 9279391 -> 9336928 -> 9439576 -> 9447326 -> 9550427 ->
9722581 -> 9740585 -> 12892567 -> 12932095, and 12932095 + 15470 = **12947565**.

Whole-section composition is independently consistent: `4 + 585 + 2384 + 72 + 40 + 12944480 =
12947565`, where 585 is the sum of `24 + len(key)` over the 18 keys (432 + 153), 2384 is
298 field-count fragments, and the `+112` overhead is 18 child-count headers (72) plus five
extent entries (40). Field ordinals sum to **298** and primary counts to **193184**, matching
FIELD_COUNT and DESCRIPTOR_ROW_COUNT.

Framing details also hold. Wrapper size is `24 + len(key) + 4 + 8*extents`: buildings 53,
field_policy and orchard_hive 48, resource_nodes 42, jobs 40 — so **53 is genuinely the
maximum**, and the pinned 4 / 53 / 8 opening read sizes are right. 65536 is divisible by 1, 4
and 8, so whole-element fragments never straddle a field; the largest field
(construction `_remaining_mwu`, 663552 bytes) splits into ten full fragments plus 8192.

All eight stride relations check: fishing 96/32=3, forage 640/128=5, field_policy rotation
384/128=3, needs 2560/512=5, residents/priorities/work 6144/512=12, schedule 12288/512=24.
The four extent-bearing owners are buildings (16384, 81920), field_policy (4096), jobs (512)
and orchard_hive (1024) — four owners, five extents, fourteen with none. The disposition's
correction of the draft 1 "thirteen" slip is confirmed; the draft 1 claim stays refuted.

## B1-B5 and A1-A10

B1 closed: `component_columns_layout.json` is now the explicit metadata authority, the
contract states that counts and extents are **absent** from the generated table, and it scopes
registry parity to keys/types/versions/order with a separate source-capacity census check.
B2 closed: the 6417408 bound is stated as conditional on release-before-next-allocation, the
decoder enforces take-before-next-input, and the excluded misuse case is published —
I reproduce both figures (3298304 + 4893696 = 8192000; + 1523712 transient = **9715712**).
B3 closed: the justification is now two copies of the single largest field, 2*663552 =
1327104, and 4893696 + 3*65536 + 1327104 = 6417408 is correct.
B4 closed: a local `byte_order_refusal()` emitting SAVE_COMPONENT_BYTE_ORDER, invoked by both
cursors before bulk conversions, with Directory explicitly not preloaded.
B5 closed: one sentence reconciles SAVE-LAYOUT-R01's historical wording with schema 2 and
scopes the freeze to this first body.

A1-A10 are each closed: WireChunk rename (A1); output refusal carries the same first sticky
code/detail (A2); owner-local ordinal plus `storage_index` (A3); packed setter parameter types
(A4); owner/field/child validity predicates required before neutral lookups, with zero
explicitly not a sentinel (A5); decoder arguments must come from the decoded 64-byte descriptor
(A6); `emitted_bytes()` defined as successful returned output, sink durability excluded (A7);
encoder `is_complete()`/`finish()`/single-use (A8); 4/53/8 pinned (A9); no assignment bitmap,
with the detection gap and the capture-adapter obligation stated plainly (A10).

The goldens are consistent with the contract where I could check them by inspection: the
buildings framing hex decodes to key length 9, version 1, primary 1024, payload 3298556,
child count 2, extents 16384 and 81920 — 53 bytes — and fishing pins owner version 1,
distinct from section 7's version 2, so that mutant remains byte-detectable.

## Non-blocking fixes

**F1.** `independent_wire_fixture.py` reads `proposed-layout.json`, but the contract now names
`component_columns_layout.json` as the metadata authority. Repoint the fixture (or record that
the two files are the same content under a rename) before the goldens are regenerated. This is
a parent fixture-maintenance item, not a stream-implementer input.

**F2.** The memory section says "Maximum owner payload: Construction 4893696 bytes", but
`payload_bytes(construction)` is 4893828 per the API and the layout. 4893696 is the *value*
byte count, which is the right basis for the budget; only the word "payload" is wrong. The
6417408 total is unaffected.

**F3.** `owner_shape_refusal` is said to validate a "nonnull owner". Say whether that means a
nonnull record or `owner != -1`; both are presumably required.

## Disposition

Dispatchable. Bounded author scope: `save_component_columns_schema.gd`,
`save_section_component_columns.gd` and `tools/generate_component_columns_schema.py`, plus the
tests named in the acceptance section — no owner-module edits, no coordinator, no capture or
apply adapter, no semantic validator, no canonical hash or filesystem work. F1-F3 are text
edits and do not gate the start. SAVE-S4-CODEC remains open on its enumerated follow-through.
