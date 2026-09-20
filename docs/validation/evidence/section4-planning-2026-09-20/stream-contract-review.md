# Independent review — SAVE-S4-STREAM-R01 draft 1 stream contract

Date 2026-09-20. Scope: `docs/planning/component_columns_stream_contract.md` draft 1, reviewed against
`proposed-layout.json`, `fixed-column-census.json`, `feasibility-disposition.md`, and the current
`save_codec.gd`, `canonical_state_hash.gd` and `save_section_directory.gd` sources supplied in the packet.
Where the disposition and earlier reviewer findings disagree, the disposition is taken as authority.
This review makes no claim that section 4 bytes are semantically valid, that any owner adapter exists,
or that SAVE-S4-CODEC is closable. Nothing was executed; all figures below were recomputed by hand from
the supplied inputs.

## Verdict

The envelope is arithmetically sound and the streaming shape is the right one, but the contract is not
yet dispatchable. Five blocking items (B1-B5) must be resolved in the contract text, and ten ambiguities
(A1-A10) must be closed, before an author can implement without guessing. B1 is the serious one: the
named metadata source does not contain the numbers the contract says to take from it.

## What I recomputed and what holds

The framing arithmetic is internally consistent and I reproduce it independently. Owner header is
`4 + len(key) + 4 + 8 + 8 = 24 + len(key)`; per-owner header bytes therefore run 28 (`jobs`, `work`) to 38
(`resource_nodes`), summing to `432 + 153 = 585` across the 18 keys. Payload is `4 + 8*extents + 8*fields +
value_bytes`. Every `block_bytes` and every `section_offset` in proposed-layout.json reproduces exactly,
and the chain closes at `12932095 + 15470 = 12947565`, matching SECTION_BYTES. The overhead claim also
reproduces: `18 * 4 = 72` child-count headers, five extent entries (buildings 2, field_policy 1, jobs 1,
orchard_hive 1) at `5 * 8 = 40`, and `12947453 + 112 = 12947565` against the census `ordinary_section_bytes`.
Whole-section composition checks too: `4 + 585 + 2384 + 72 + 40 + 12944480 = 12947565`.

Field count sums to 298 across the census owners and matches `OWNER_FIELD_COUNTS[11..28]` in the
CanonicalStateHash generated table. Primary counts sum to 193184, which is DESCRIPTOR_ROW_COUNT as the
disposition's reading of SAVE-LAYOUT-R01 requires; it is a sum of block primary counts, not an entity
census, and the contract says so correctly. Declared ASCII owner order in the contract table is correct,
including the three pairs that are easy to get wrong: `field_policy` before `fishing` (`e` < `s`),
`residents` before `resource_nodes` (`i` < `o`), and `work` before `world_init` (`k` < `l`). That order
matches the section-4 slice of `OWNER_KEYS`, so an order parity check against the generated table is
feasible.

Per-owner section-4 schema versions in the census match `OWNER_VERSIONS[11..28]` exactly, including the
three twos (`needs`, `residents`, `work`). The "no u64/u32 field exists here" claim also holds: scanning
`FIELD_TYPES` across global indices 51..348 (the section-4 span, since sections 1-3 contribute
`3+1+10+1+1+5+2+9+12+1+6 = 51` fields) yields only type codes 0, 2 and 4 — no 1, 3 or 5. Likewise every
entry of `FIELD_EXCLUDED_INDEXES` (32, 37-43) is below 51, so all 298 section-4 fields are hashed and
there is no saved-but-not-hashed divergence of the kind world_runtime carries. The disposition's Finding
3 also checks out structurally: the 15 buildings reference/chain fields it names are a separate
section-5 owner block, consistent with section-4 buildings holding 29 fields and not 44.

## Blocking findings

**B1. The named metadata source does not contain element counts, primary counts or child extents.**
The contract says to "use exact keys/types/versions/order from canonical_state_registry.json and its
checked-in CanonicalStateHash generated table" and separately requires "deterministic source/registry
parity checks". But `FIELD_COUNT_INDEXES` in the generated table lists only 57 sparse entries, every one
of which is either below 51 or at 365 and above — none falls inside the section-4 span 51..348. So
`Declaration.field_declared_count()` returns nothing usable for any of the 298 fields, and the registry
carries no primary_count or child_extent concept at all. Every count in this envelope therefore
originates in the census JSON, which runtime must not read, which means the schema module must compile
its own extent table from the owner capacity constants. The contract must say this explicitly and must
scope the parity check honestly: keys, types, versions and order can be checked against the generated
table; counts and extents cannot, and need a separate generator-plus-test parity path against the census
and the capacity constants.

**B2. The one-owner memory bound does not hold across the take/next-owner boundary.** The contract states
"at most one private FramedOwner" and derives a 6417408-byte total, then separately allows the caller to
"retain at most one completed owner during production" and to "persist/release before feeding next
owner" as a coordinator obligation. Those two statements are not compatible as a bound. If the caller
holds a transferred record while `accept_chunk` allocates the next owner's columns, peak live value bytes
is the sum of an adjacent pair. In ASCII order the worst adjacent pair is buildings then construction:
`3298304 + 4893696 = 8192000` value bytes, plus the transients, which is roughly 8.4 MB against a claimed
6417408. Either the budget must be restated as conditional on release-before-next-allocation and the
worst adjacent pair must be published, or the decoder must not allocate owner *n+1* until
`take_owner_into` for owner *n* has occurred and the contract must state that ordering as enforced
rather than as etiquette.

**B3. The "two largest field copies" justification is wrong, though the resulting number is conservative.**
There is exactly one 663552-byte field in section 4 (`construction._remaining_mwu`, 82944 i64). The next
largest are 350208 (transforms i32 columns), 331776 (construction i32 columns) and 327680 (buildings
`_f_*`). Two genuinely largest copies would be `663552 + 350208 = 1013760`, not `1327104`. The stated
total still adds correctly (`4893696 + 65536 + 2*65536 + 1327104 = 6417408`) and 1327104 is a safe upper
bound, so fix the wording — charge twice the single largest field — rather than the number.

**B4. There is no existing byte-order probe the new module can call.** The contract says the probe "must
fail closed using existing pattern". The only implementation in the packet is
`save_section_directory.byte_order_refusal()`, which returns a `SAVE_DIR_BYTE_ORDER` refusal and lives in
a section-3 module that is deliberately outside the declared preload set (SaveCodec, SaveHeader,
CanonicalStateHash). `save_codec.gd` has no probe at all. The contract must say the probe is reimplemented
locally, emits SAVE_COMPONENT_BYTE_ORDER, and is exercised on both the encode and the decode path,
because the bulk `to_byte_array()` / `to_int32_array()` conversions bypass the codec's explicit
little-endian writes.

**B5. SECTION_SCHEMA_VERSION 2 conflicts with a quoted ruling and the conflict is unaddressed.**
`save_section_directory.gd` quotes SAVE-LAYOUT-R01 as "Adopt the above as the initial section3/4/5/10
schema1 framing", while this contract, the census `section_schema_versions[3]` and the disposition all
say section 4 is schema 2. The disposition is authority here and settles it at 2 — the ruling's "schema1
framing" plainly describes the block framing shape, not the section descriptor's schema_version — but the
contract must record that reconciliation in one sentence rather than leaving a live contradiction between
two checked-in documents.

## Ambiguities that must be closed in text

**A1. `Chunk` collides with an existing, differently shaped class.** `save_section_directory.gd` already
defines an inner `Chunk` with `ok/bytes/refusal/detail` and `succeed()`/`refuse()`. The proposed one uses
`bytes/code/detail` and `is_ok()`. Either align the new one to the existing shape or rename it; two
same-named codec chunk types with different member names is a readability trap in review.

**A2. Two error channels are defined without a stated relationship.** `next_chunk_into` writes
`Chunk.code` and the cursor exposes a sticky `refusal()`. State that on any refusal `Chunk.code` equals
the sticky code and that the sticky code is first-wins, matching the Reader/Writer pattern in
`save_codec.gd`.

**A3. "field-type storage order" is undefined.** `FramedOwner` holds three typed arrays-of-arrays, but it
is not stated whether the `field` argument to `u8_column(field)` is the global field ordinal or an index
within the u8 sublist. Assume global ordinal with a compiled ordinal-to-(bucket, slot) map, say so, and
require a test that a valid ordinal of the wrong type returns empty rather than a neighbouring column.

**A4. Setter parameter types are unspecified.** `set_u8/set_i32/set_i64(field, values)` must declare
`PackedByteArray` / `PackedInt32Array` / `PackedInt64Array`. With packed types the u8 0..255 and i32
range domains are structural and need no per-element loop; with untyped `Array` they would need one.

**A5. Neutral metadata lookup values alias valid data.** `child_extent_count` returning 0 is
indistinguishable from the true answer for thirteen owners, and `field_type` returning 0 aliases the u8
type code. The contract already says a neutral value proves nothing, but that is unenforceable at the
call site. Add an explicit `index_valid(owner, field) -> bool` (or a Refusal-returning accessor) so
validity is never inferred from a returned number, and require the tests to assert refusal at the stream
layer rather than asserting the neutral values.

**A6. Preflight may be vacuous.** Both cursors take `section_schema` and `descriptor_rows` and compare
them against compiled constants. State that these arguments must come from the decoded 64-byte
descriptor and never from the module's own constants; otherwise the preflight compares a constant with
itself and the "decoder old schema / wrong rows" tests pass for the wrong reason.

**A7. "Accepted output" on the encoder is undefined.** There is no acknowledgement API, so it is unclear
whether `emitted_bytes()` advances on a successful `next_chunk_into` regardless of what the caller does
with the chunk. Define it as advancing on successful emission, matching the existing ChunkCursor.

**A8. The encoder has no completion or reuse policy.** The decoder gets `finish()`, `is_complete()` and an
explicit "no reset/reuse". The encoder gets neither. A caller that stops mid-section receives no refusal
from the codec. Add an encoder `is_complete()`/`finish()` so encode-side truncation is detectable inside
the module, and state whether EncodeCursor is single-use after a sticky failure.

**A9. The first decode fragment boundary is only implied.** The encoder emits store_count as its own
4-byte chunk, then the owner wrapper. Say directly that the decoder's first `next_read_size()` is 4, then
the exact wrapper length for owner 0 (53 bytes for buildings), so "same deterministic boundaries" is not
the only rule an implementer has.

**A10. An unset column is indistinguishable from a legitimately zero one.** Constructor zeros are
explicitly not semantic defaults, and a refused setter "changes nothing", so a caller that ignores the
bool ships a well-formed all-zero column. Either have `FramedOwner` track per-field assignment and have
`owner_shape_refusal` refuse unassigned fields on the capture path, or state plainly that the codec cannot
detect this and that the obligation sits with the future capture adapters.

## Hostile framing and decode

The decode posture is sound in principle: every framing field is a compile-time constant, so byte-for-byte
comparison against expected bytes means no hostile count, length or extent can ever drive an allocation,
and allocation happens only after a wrapper has fully matched. Two consequences should be written down.
First, because framing is compared rather than parsed, `save_codec.gd`'s decode primitives — including the
`REFUSE_UNREPRESENTABLE_U64` high-bit guard — are never exercised on this path; the contract should state
that SaveCodec is used for encode-side writes and the conversion helpers only, so the preload is not
mistaken for validation coverage. Second, the "test high bits / huge hostile length bytes" acceptance item
is therefore near-trivially satisfied; keep it, but add a test that a hostile `payload_length` differing in
a single high byte is refused *before* `next_read_size()` advances and before any column is allocated,
which is the property actually worth pinning.

Chunking is exact: 65536 is divisible by 1, 4 and 8, so whole-element chunks never straddle a field. The
largest single field, 663552 bytes, splits into ten full chunks plus an 8192-byte remainder. The maximum
wrapper chunk is 53 bytes (buildings), so the "<256 bytes" framing bound is correct but loose; stating 53
would make the test assertion sharper.

## Test and mutation adequacy

Two of the implied mutants cannot be killed by byte tests, and the contract should admit it. Section-4
`buildings` primary 1024 equals `BUILDING_CAPACITY`, and section-4 `forage` primary 128 equals
`HARVEST_ZONE_CAPACITY`; a mutation that sources those from the section-1 constants produces byte-identical
output. That guard is source-level only and belongs in the independent source review, not in the assertion
list. By contrast the fishing leak *is* detectable, because section-4 fishing is owner schema 1 while
section 7 fishing is 2 — pin `owner_version(fishing) == 1` explicitly.

Add two mutation targets: emitting buildings' child extents in reversed order (16384/81920 swapped), which
the current "omit child extent comparison" target does not cover; and emitting an owner's `payload_length`
computed from a running total rather than from the compiled constant, which survives a naive round trip.

The whole-section SHA-256 pin needs an owner. A test that independently constructs 12947565 bytes cannot
also derive its expected digest from the module under test; name the generator that produces the pinned
hex, check it in beside proposed-layout.json, and allow the test to build value bytes from a declared
deterministic pattern through bulk packed conversions rather than per-byte GDScript loops.

## Scope and authority conformance

The contract stays inside the disposition's permission: no owner or gameplay normalization, no unused-row
zeroing, no whole-section buffer in production, no publication to a live world, no canonical hash, no
clocks, no filesystem, and an explicit statement that SAVE-S4-CODEC remains incomplete with named
follow-through (18 semantic validators, 15 missing bulk APIs, capture/apply adapters, jobs 4+5 and
buildings 4+5 atomicity, resident 4+14 name agreement, saved directory matching, claim projection
binding, owner canonical adapters). The eight stride relations are listed correctly, field_policy's
stride-3 rotation is correctly held independent of its 4096-plot child table, and the equal-capacity
orchard/hive pair is correctly declared as two independent tables. No re-litigation of the refuted
Finding 8 appears. I found no scope creep to flag.

## Disposition

Not ready for author dispatch as written. Resolve B1 through B5 and A1 through A10 in the contract text,
then re-review. No production code should be written against draft 1.
