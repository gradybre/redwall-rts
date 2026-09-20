# Section 4 streaming envelope — SAVE-S4-STREAM-R01 v2

Date: 2026-09-20. This is the accepted contract for SAVE-S4-STREAM after independent draft2 follow-up review. SAVE-S4-CODEC remains incomplete until all 18 semantic validators and production owner adapters are complete. No gameplay normalization is authorized.

## Format and metadata authority

SAVE-LAYOUT-R01 and REG-R01 prescribe column-major framing. Current registry 6 and the later REG-R01 LifeStage composition supersede SAVE-LAYOUT-R01's historical initial schema-1 statement: section 4 is schema **2**. This freezes its first implemented body; no previous section-4 codec or emitted fixture is being reinterpreted. Later changes require normal compatibility revision.

`component_columns_layout.json` explicitly declares every primary count, child extent, field count and offset. Its 18 owners / 298 fields contain 12944480 value bytes. Exact framing is:

```
section = store_count:u32=18, owner blocks in ASCII order
owner = key:utf8-u32, owner_schema_version:u32, primary_count:u64,
        payload_length:u64, payload
payload = child_extent_count:u32, child_extents:u64[],
          for each field: element_count:u64, values in LE declared signedness
```

All primary and child extents are compiled **exact** values. All columns cover their full physical capacity. No inferred extents, compaction, unused-row zeroing or rebuilding. The independent layout fixture specifies primaries and children; its sum of primaries is descriptor row_count **193184**, as SAVE-LAYOUT-R01 requires. This is not an entity count. Total section size is **12947565** bytes, including 18 child-count headers and five child extents (+112 bytes over the ordinary-column census).

Buildings declares room and furniture children; FieldPolicy declares plots; Jobs declares agents; OrchardHive declares hives even though orchard and hive capacities are both 1024. Fishing stock stride 3, Forage patch stride 5, FieldPolicy rotation stride 3, Needs stride 5, Residents/Priorities/Work stride 12 and Schedule stride 24 are fixed derived lengths, not independent child extents. Buildings' reference/chain columns already belong to section 5. Fishing's section-7 schema constant and Buildings/Forage section-1 primary constants are not section-4 metadata.

Production files: `save_component_columns_schema.gd`, `save_section_component_columns.gd`. Authoring generator: `tools/generate_component_columns_schema.py`. No owner-module edits. Runtime preloads only SaveCodec, SaveHeader and CanonicalStateHash; it reads no JSON and instantiates no live stores.

The generator compiles explicit checked-in metadata from the layout artifact and canonical registry. Keys, types, versions and order must match the canonical registry/generated table. **Counts and primary/child extents are absent from that table**; they come from the explicit layout and must be independently checked against the source-capacity census/proofs. The generator refuses missing/extra/reordered fields, unsupported types, mismatched counts and inconsistent offsets/lengths before writing. `--check` is read-only. Tests independently compare all 298 fields, not merely regenerate a table from itself. Account for added immutable metadata separately; no runtime JSON parsing or fabricated count lookup.

## Schema API

Expose constants STORE_COUNT=18, FIELD_COUNT=298, SECTION_SCHEMA_VERSION=2, SECTION_BYTES=12947565, DESCRIPTOR_ROW_COUNT=193184, CHUNK_BYTES=65536. All indices below are section-local; field is the ordinal **within its owner**, never the index in a type bucket.

```
static owner_valid(owner:int)->bool
static field_valid(owner:int,field:int)->bool
static child_valid(owner:int,child:int)->bool
static owner_key(owner:int)->String
static owner_version(owner:int)->int
static primary_count(owner:int)->int
static child_extent_count(owner:int)->int
static child_extent(owner:int,child:int)->int
static field_count(owner:int)->int
static field_key(owner:int,field:int)->String
static field_type(owner:int,field:int)->int
static storage_index(owner:int,field:int)->int
static element_count(owner:int,field:int)->int
static field_width(owner:int,field:int)->int
static payload_bytes(owner:int)->int
static owner_block_bytes(owner:int)->int
static owner_offset(owner:int)->int
static field_count_offset(owner:int,field:int)->int
static field_value_offset(owner:int,field:int)->int
static schema_refusal()->SaveHeader.Refusal
```

Offsets are relative to section start. `storage_index` is the count of earlier fields of the SAME type. Invalid lookups return empty String or zero; **all stream/accessor callers must first use the relevant validity predicate**. Zero is not an error sentinel. schema_refusal checks declaration version, complete metadata/table consistency and only supported types u8/i32/i64 (codes 0/2/4); section 4 has no u32/u64/string value field.

## Records and result types

`FramedOwner.new(owner:int)` allocates exact typed columns in `u8_columns:Array[PackedByteArray]`, `i32_columns:Array[PackedInt32Array]` and `i64_columns:Array[PackedInt64Array]`, each bucket ordered by ascending owner-local field ordinal. Invalid owner becomes -1 with no arrays. The public `owner:int` identifies the block. Accessors `u8_column(field:int)->PackedByteArray`, `i32_column(field:int)->PackedInt32Array`, `i64_column(field:int)->PackedInt64Array` return the stored column or empty on invalid/wrong-type ordinal, without duplicating it.

Setters `set_u8(field:int,values:PackedByteArray)->bool`, `set_i32(field:int,values:PackedInt32Array)->bool`, `set_i64(field:int,values:PackedInt64Array)->bool` validate ordinal/type/exact extent before duplicating that ONE column. Refusal changes nothing. `owner_shape_refusal(record:FramedOwner)->SaveHeader.Refusal` validates a nonnull record, valid owner index, bucket lengths and every column extent. No semantic checks.

Constructor zeros are arbitrary representable wire data, **not** semantic defaults. There is deliberately no assignment bitmap: this layer cannot detect an ignored setter failure or an omitted capture field. Future capture adapters must propagate every failure, populate every canonical field and prove full coverage. Frame acceptance cannot authorize publishing zero substitutes.

Use the new class name `WireChunk` (not Directory.Chunk): bytes:PackedByteArray, code:StringName, detail:String, and `is_ok()->bool` (code empty). `OwnerResult` has record:FramedOwner=null, code/detail and `is_ok()->bool` (code empty AND record nonnull). Successful output clears diagnostics; refused output clears bytes/record. These wrappers may expose succeed/refuse helpers, but cannot alter the protocol.

## Encoder

`EncodeCursor.new(section_schema:int,descriptor_rows:int)` preflights schema, rows, compiled metadata and host byte order, in that order. First error is sticky. No owner is initially bound; offset is zero. The cursor is single-use, with no reset.

- `needs_owner()->bool`: true after the store-count fragment is emitted, or after an owner finishes, while another owner is required. False on failure/completion.
- `owner_index()->int`: next/current expected index 0..17; 18 after all owners.
- `bind_owner(record:FramedOwner)->SaveHeader.Refusal`: allowed only when needs_owner. Check expected owner and full shape before borrowing the record. Failure is sticky. Caller freezes that record for its entire emission; no snapshot copy or live capture occurs here.
- `has_more()->bool`: true until complete, including while waiting for an owner; false on failure.
- `next_chunk_into(out:WireChunk)->bool`: emit store_count as 4 bytes; owner wrapper INCLUDING child header/extents as one fragment; each field count as 8 bytes; then whole-element value fragments of at most 65536 bytes. No value fragment crosses fields. First Buildings wrapper is 53 bytes, the maximum wrapper size. Use bulk packed conversions only after the host-order probe.
- After the final value fragment of an owner, release the borrowed reference and request the next owner. Never hold an array of 18 records.
- `emitted_bytes()->int` counts bytes returned by successful next_chunk_into, regardless of whether a downstream sink subsequently writes them. Sink acknowledgement/durability is outside this codec.
- `is_complete()->bool` requires all owners emitted and byte count exactly SECTION_BYTES. `finish()->SaveHeader.Refusal` succeeds only then; otherwise stores TRUNCATED or returns the first prior error.
- `refusal()->SaveHeader.Refusal` returns the current first error. Calling next while awaiting bind or after completion refuses STATE. Null output refuses STATE safely. Every output refusal carries the same first sticky code/detail as the cursor, clears output bytes, and emits no accepted bytes.

No whole-column/owner/section concatenation helper in the production encoder.

## Decoder

`DecodeCursor.new(section_schema:int,descriptor_rows:int,section_byte_length:int)` preflights schema, rows, exact length, metadata and host order, in that order, before allocating a FramedOwner. On load, these arguments MUST come from the same decoded 64-byte section descriptor, never substitute this module's constants. On capture, the encoder receives the descriptor values prepared for that file. Common-file provenance and outer descriptor validation remain coordinator obligations.

- `next_read_size()->int`: exact next fragment length, 1..65536 while input is required; zero while an owner is ready, complete, or failed. First size is 4, then Buildings wrapper size 53, then its first field count size 8. Thereafter boundaries exactly match the encoder. A disk adapter must assemble precisely this amount in a caller window <=65536; this API does not accept arbitrary partial fragments.
- `accept_chunk(bytes:PackedByteArray)->SaveHeader.Refusal`: require legal state and exact expected size before any change. Zero/short/long fragments refuse CHUNK. Never retain caller bytes. Compare framing byte-for-byte with the compiled expected bytes, including every key, schema, count, extent and payload length. Hostile fields never drive allocation. Allocate the current owner's private columns only AFTER its entire wrapper matches. Check every field-count fragment before values.
- Value fragments are copied/converted into exact private field positions, preserving u8 bits and signed i32/i64 two's-complement values. No interpretation of occupancy, blanks or gameplay meaning. SaveCodec constructs framing; its integer-reader high-bit guard is not the validation path for byte-compared framing.
- `owner_ready()->bool`: true only after every field of the current owner is complete. No more input is accepted until `take_owner_into(out:OwnerResult)->bool` transfers that record by reference, clears the decoder's reference and advances the expected owner. There is no whole-record publication copy. Early take, double take or null output refuses STATE; partial records never escape.
- `consumed_bytes()->int`: accepted fragment bytes only. `is_complete()->bool`: final owner transferred AND consumed count equals SECTION_BYTES. `finish()->SaveHeader.Refusal`: success only in that state; otherwise first prior error or TRUNCATED. Extra accept after completion refuses STATE. Cursor is single-use; no reset.
- `refusal()->SaveHeader.Refusal`: current first error. Any failure drops a private partial/completed-but-untransferred record, retains the last accepted offset and first diagnostic, and leaves input and every previously transferred record unchanged. A refused output wrapper clears its record; a separately retained earlier record remains unchanged.

Receiving a framed owner is **not** approval to install it into a live store. External section range/EOF, CRC, digest, semantic validation and file transactions are not supplied by this cursor.

## Errors and byte order

StringName codes: SAVE_COMPONENT_SCHEMA, SAVE_COMPONENT_DESCRIPTOR, SAVE_COMPONENT_LENGTH, SAVE_COMPONENT_METADATA, SAVE_COMPONENT_OWNER, SAVE_COMPONENT_SHAPE, SAVE_COMPONENT_FRAME, SAVE_COMPONENT_CHUNK, SAVE_COMPONENT_STATE, SAVE_COMPONENT_TRUNCATED, SAVE_COMPONENT_BYTE_ORDER. Success code/detail are empty. After constructor preflight, check state, size, then framing. Detail identifies owner, field and offset where applicable. After a sticky error, every later operation returns that same error without progress.

Implement a local `byte_order_refusal()->SaveHeader.Refusal` using the existing Directory probe's four-byte packed-conversion pattern, mapped to SAVE_COMPONENT_BYTE_ORDER. Directory is not preloaded. Both cursors invoke this before bulk conversions. A source-level test may pin the probe pattern; do not pretend a little-endian host exercised a real big-endian machine.

## Memory and ownership

The production caller MUST persist and release an owner, including clearing any OwnerResult reference, BEFORE feeding the next owner's wrapper. This is a conditional lifetime contract; the decoder cannot revoke externally held records. The decoder itself enforces take-before-next-input and holds at most one private owner. Arbitrary callers can retain more and are outside this budget.

Maximum owner value bytes: Construction 4893696 bytes. Conservatively charge three 65536-byte input/conversion windows plus **two copies of the single largest field**, 2*663552=1327104 bytes, for COW/reallocation. Total owner plus transient allowance **6417408 bytes**, before metadata/native overhead. No second full-owner copy. Explain actual allocation lifetimes in implementation review; the allowance is not evidence of measured RSS.

If the caller violates release-before-next-allocation, the largest adjacent owner pair (Buildings+Construction) alone retains8192000 value bytes; with the same transient allowance that is9715712 bytes. This is an explicitly excluded misuse case, not hidden headroom. Releasing only the local variable while OwnerResult still references the record is insufficient.

No whole-section Record or wire buffer, live owner object, signal, callback, clock mutation, cleanup, barrier release or filesystem operation. Encode callers hold the appropriate completed-boundary/load barrier outside the codec. Full world publication requires semantic/cross-section/digest validation of the inactive checkpoint first. No token authenticates the common origin of arbitrary arrays.

## Acceptance and follow-through

Parent owns independent fixtures: `section4-planning-2026-09-20/independent_wire_fixture.py` and `independent-wire-goldens.json`. It imports no production module, streams the format and pins whole-section hashes for zero-wire and non-symmetric signed-boundary patterns. Both are structural, not valid-world fixtures. See parent-stream-test-plan.md for exact checks.

Crosscheck all 298 metadata entries and pin literal framing/offsets. Stream encode/decode one owner at a time; compare every value, every owner boundary and final12947565 bytes; prove max fragment65536. Include signed extrema and nonboolean u8. Refuse wrong owner, shape, schema, descriptor, counts, lengths, key/order, every child extent, malformed field counts, short/long/empty chunks, early take/finish, extra input, null outputs and illegal reuse. Preserve caller inputs and a previously transferred owner on a later failure. A high-byte-only payload-length change must refuse the wrapper before allocation or offset advance.

Six required mutants: omit child-extent comparison; omit payload-length comparison; swap equal-width/equal-length columns; allow wrong owner order; publish a partial owner; omit section-length preflight. Child-order reversal and wrong cumulative payload encoding may be additional variants. Test assertion failures must kill them; parser failures do not count. Fishing section4owner version1 is pinned separately from section7version2. Buildings/Forage section1primary is16384, not section4's1024/128; those substitutions ARE distinguishable by bytes (the review's contrary equivalence claim was false).

Full suite, static gates, editor import and independent source review are required before merge. SAVE-S4-CODEC still requires18 semantic validators,15 missing bulk APIs, exact capture/apply and canonical adapters. Coupled owner sections must restore atomically: Buildings1/4/5, Construction4/5, Farming1/4, Fishing4/7, Forage1/4/5/7, Jobs4/5, Movement2/4/9, OrchardHive4/5, Residents4/14, ResourceNodes1/4, WorldInit1/4. Existing partial APIs do not certify those compositions. Other bodies, saved-Directory matching, claim binding, coordinator, disk rollback and full continuation remain explicit prerequisites. No release flag or first-playable milestone changes.
