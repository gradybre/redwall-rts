# Task 09.2 — Save codec contract decisions

2026-09-11 · SAVE-R09-001–005. Engineering rulings; no production codec or
release-save compatibility is certified by this document. Read ARCH-SAVE-001–007,
ARCH-HASH-001, the persistence registry and the earlier READY_07 save/UI addendum.
These choices resolve the five questions; implementation and complete owner
schemas remain required. Do not serialize a missing system as if it were complete.

## SAVE-R09-001 — Container and section versions

Keep `RWLSET01`, outer `format_version=1`, 256-byte header and 64-byte descriptors.
Initial section versions for IDs 1–15 are `[1,1,1,1,1,1,1,1,1,1,1,2,1,1,1]`.
Section 12's prefix already declares schema 2; its nested `SCHQ0001` schema stays
1. Section 2 stays 1. Weather's nested store schema stays 2 and rejects schema 1.
The scheduler proposal's outer-container version 2 is superseded. SET-AMEND-001's
v1/v2 compatibility language describes hunting/ruleset generations, not this
outer container number. Reject hunting-era state using rules/catalog compatibility
and the canonical-empty reserved fauna, skill, zone and RNG validations.

Change the outer version only when header/descriptor interpretation changes.
Increment the owning section when field order, width, meaning, occupancy encoding
or nested-store version changes; update rules identity too. Never silently
repurpose reserved bytes. Writers emit current versions. Loaders accept exact
supported versions or an explicit, tested migration, otherwise refuse before
world mutation. Released versions are immutable. Unreleased prototypes carry no
implicit migration promise; a section-12-v1 file is not silently filled with an
empty scheduler. MOVE-G02 must publish its expanded version/rejection matrix
before expanded release saves can be written.

## SAVE-R09-002 — Strings

All direct binary string fields use `utf8_byte_count:u32 LE` followed by exactly that many
UTF-8 bytes, without NUL terminator, alignment or padding. Zero represents an
empty string, never a null/signed sentinel. Check the schema cap and remaining
section bytes before allocation; reject invalid UTF-8, overlong encodings,
surrogates, truncation, length overflow and trailing payload bytes.

Names/aliases allow at most 128 encoded bytes, then must pass the owning 2–32
Unicode scalar-value and no-control-character rules. Empty names are allowed
only where the owning unused-row schema permits them. A live resident cannot
load an empty name. Independently enforce the 131072-byte name-pool arena limit.
Other string fields require their own explicit byte cap; u32 is not an allocation
permission. Fixed tags and embedded artifacts retain their own formats. In
particular section2 wraps opaque canonical JSON bytes with a u32 artifact-byte
length; strings INSIDE that JSON remain JSON strings, not binary-prefixed fields.
Existing section2 artifact framing is retained.

Pinned byte examples (hex): empty `00000000`; `Oak` = `030000004f616b`;
`Móle` = `050000004dc3b36c65`. These are encoding fixtures, not a waiver of a
field's name-length validation. `01000000c0` and `02000000c080` must fail UTF-8.

## SAVE-R09-003 — Identity producers

All five header identities are SHA-256 raw 32-byte outputs. No FNV benchmark,
transform fold, inventory-only dump or isolated `RWLCTRL1` checkpoint substitutes
for any of them. Only CatalogIds currently has a production artifact producer.
The four new producers below must be implemented and independently vector-tested.
Do not insert made-up hex digests into release saves.

**Catalog:** preserve `CatalogIds.digest_of()`: SHA-256 of the exact committed
canonical `godot/data/catalog_ids.json` bytes. Validate and compile that artifact
under its existing contract. Never silently regenerate it during load.

**Rules:** build `rules_identity.bin` from explicit authoritative-owner
registrations, not prose, comments, filenames, presentation settings or inferred
source scanning. Bytes are `RWL-RULES-1\0` (literal terminating zero byte), u32
record count, then records sorted by ASCII qualified key. Each record is
`key:string, type:u8, element_count:u32, values`. Keys are nonempty ASCII,
max 256 bytes, unique. Type 0=u8, 1=u32, 2=i32, 3=u64, 4=i64, 5=UTF-8 string;
integers use their named LE width; string values each use SAVE-R09-002, max4096
bytes. No padding. Reject duplicate keys, invalid type/count/width/ranges and
missing registrations. SHA-256 covers these exact artifact bytes.

Register ruleset ID, semantic implementation revision of each authoritative
algorithm, section/store schema versions, ordered field IDs/types/capacities/
null rules/persistence and canonical-hash membership, command/event payload
schemas, authoritative scalar constants and numeric production definitions.
Use indexed qualified keys to preserve ordered lists (do not sort their values).
An algorithm change that affects outcomes changes its declared semantic revision,
even if no numeric constant changed. This rules artifact is build-time streamed; only its verified32-byte digest is
retained at runtime, reusing the existing65536-byte validation buffer for checks.
Do not allocate its record_count or entire file. Require exact EOF after the
declared records and reject any trailing byte. Each count must be bounded by
remaining bytes before reading; iterate without count-sized allocation. The
finite build registration inventory must exactly match record_count.
The build must compare registrations with
the state registry, catalog domains and owning schema inventories and fail missing
coverage. No hand-selected subset may be called the release rules identity.

**Lookup:** build `lookup_identity.bin`: bytes `RWL-LOOKUP-1\0`, u32 table count,
then unique ASCII-key-sorted records `key:string, element_type:u8, count:u32,
values_in_declared_order`. Types 0–4 have the same encoding above; no string-valued
integer tables. Every authoritative multi-value integer lookup registers here
(including arithmetic/geometry tables); declare multidimensional shape in the
rules artifact and flatten row-major. Scalars belong in rules, tables here;
rules contain each table's key/type/shape, not a second divergent value list.
Require exact EOF after table_count records and bounds checks before every
read; no count-sized allocation during verification.
SHA-256 covers exact artifact bytes. Catalog and lookup immutable-arena limits
remain binding; stream generation/hashing and account all resident artifact bytes.

**Map:** SHA-256 of `RWL-MAP-1\0 || scenario_version:u32 || effective_seed:i32 ||
map_generator_schema:u32 || authored_map_digest:32`, all integers LE. The zero
32-byte authored digest is permitted only for the current wholly procedural
estuary. Authored scenarios supply SHA-256 of the EXACT committed authored-map source
file bytes selected by their scenario manifest (including any existing newline
and embedded metadata), without load-time parse/reserialize normalization. Task04
scenario-import owns that immutable file and its format/schema validator; the
map-identity producer streams the file bytes. Every referenced authoritative map
dependency must be embedded or named with a verified content digest in that file.
Only locally supported/validated scenario formats may load; no authored map is
claimed implemented. This defines the hash byte boundary even when the scenario
content decoder has yet to be built. Purely visual assets are excluded.
New baseline `map_generator_schema=1`; generator outcome changes increment it
and its rules semantic revision. Preserve the effective published seed, not an
unsuccessful attempt's input. This identifies initial map provenance; subsequent
terrain/topology changes belong in saved state and ARCH-HASH-001, not this hash.

Section 1 schema 1 begins with an explicit 44-byte identity prefix:
scenario_version u32 at0, effective_seed i32 at4, map_generator_schema u32 at8,
authored_map_digest32 at12. These map to the owning World/scenario fields, not
independent competing values. Duplicate seed fields elsewhere must agree.
Persist/registry-budget the new scenario/generator/digest metadata; it is not
currently all produced by world_init.gd. The save owner owns this framing;
world/scenario owner supplies the identity fields and supported generator set.
Before allocating a world, read this bounded prefix, validate scenario/generator
support and authored digest against local content, and recompute the expected
map hash. Do NOT compare it only with the currently open world's different seed,
or trust the incoming header digest as its own expected value.

**Engine:** SHA-256 of UTF-8
`major.minor.patch.status.build.full_commit_hash\n`, assembled from the matching
`Engine.get_version_info()` fields using unlocalized decimal numbers, literal
periods and one LF. Require full commit hash, not its short display abbreviation;
refuse an unidentified build. Do not hash platform-specific executable bytes.
Use the same exact line in ARCH-HASH-001. This permits matching engine source
build identities across Mac/Windows; it is not evidence of platform parity.

Expected rules/catalog/lookup/engine identities come from the local verified
build; map identity comes from the validated incoming provenance prefix. All
are checked before live-world mutation. Body hash/CRC protect file integrity;
compatibility identities and canonical state validation have different jobs.

## SAVE-R09-004 — Gapless section layout

Exactly 15 descriptors, in ID order1–15. Every current descriptor has flags0
and24 reserved zero bytes; reject any nonzero value. New flag meanings require
an explicit owning section-version change. Table occupies `[256,1216)`.
First section starts1216. Each next offset is prior offset plus prior length;
last end equals total file length. No padding, overlap, gaps or trailing bytes.
A zero-byte payload, where its section schema permits it, has current cursor
offset, row_count0 and CRC-32/ISO-HDLC0. A schema with a mandatory prefix cannot
use a zero-byte payload just because it has no live rows.

Check `offset <= total` and `length <= total-offset` before addition, validate
all schema-specific lengths/counts, and stream body SHA-256 over `[256,total)`.
CRC vector ASCII123456789 remains3421780262. Section15's digest is included in
the body hash; the body digest itself is outside the body. No cyclic hashing.

## SAVE-R09-005 — Missing owners and payloads

**Section11 EVENT_SCHEDULE:** proposed `godot/scripts/core/event_schedule.gd`,
owned by timed-game-event integration. Preserve existing maximum64 records,
32-byte record fields in order `kind:i32, source_id:i32, arg0:i32, arg1:i32,
due_tick:i64, sequence:i64`, dense and sorted `(due_tick,sequence)`.
Descriptor row_count=N; payload is `next_sequence:i64` then N records, length
`8+32*N`. This is the ALREADY BUDGETED WorldRuntime.next_event_sequence i64
(architecture §3), reassigned to EventSchedule ownership/section11, not a new
allocation. Preserve one scalar only; do not also serialize it in section1.
Update owner/registry accounting without adding8 bytes to the total. Initial next_sequence1; issued sequences1 through
I64_MAX, never reused; zero means exhausted, in which case insertion refuses
atomically. Every live sequence is unique and below next_sequence unless
exhausted. Due ticks obey the owning completed-boundary event rule; no silently
expired rows. Capacity failure must not consume a sequence. Do not infer the
allocator from live rows after consumed events disappear. Scheduler pause/speed
commands stay in section12, never here. The event owner must register concrete
kind/argument domains and event production/consumption rules before real events
are activated. Empty development fixtures still encode the allocator scalar.

**Section13 CHRONICLE:** proposed `godot/scripts/core/chronicle.gd`, functionally
owned by task08.5; save owner streams it. Preserve 24-byte record order
`resident_id:i32, event:i32, tick:i64, other_id:i32, detail_key:i32`.
Append-only insertion order, descriptor row_count agrees with header count;
length=24*count with overflow checks. Rolling digest is
`SHA256(previous_digest || exact_record_bytes)`, starting with32 zero bytes.
Retain two64-record RAM pages and65536-byte I/O streams. Never load all history.
GDD's semantic StringName detail_key means a compiled stable `ChronicleDetail`
ID on disk/in packed storage, not a Godot intern handle. Catalog owner adds the
ASCII-key domain and versioned artifact alongside task08.5's actual event/detail
inventory; unknown IDs fail. Human text/localization stays outside canonical
record identity. This resolves width/owner, not an invented list of story events.
Do not call an empty Chronicle stub release-complete.

**Section15 STATE_DIGEST:** proposed `godot/scripts/core/canonical_state_hash.gd`,
owned by task09 save/hash coder. Exactly32 raw SHA-256 bytes, row_count1, flags0.
Use the exact canonical logical-state stream below for both writing and
verification, preserving ARCH-HASH-001's declared field ownership and exclusions. Exclude section15 itself,
section CRCs/body-digest bookkeeping and output hash bytes from its input.
Recompute during inactive validation and again after final array decode, before
publication. This is the full canonical digest, not the cross-speed gameplay
projection. Host debt/counters are saved but excluded as ARCH-SAVE-007 requires.

### Canonical logical-state stream, RWL-STATE-1

The input to SHA-256 is exactly, with no padding:

1. Eleven ASCII bytes `RWL-STATE-1`, NO terminating zero byte.
2. rules, catalog, map and lookup digests,32raw bytes each in that order.
3. SAVE-R09-002 string containing the exact engine identity line (including LF).
4. completed_tick:i64 LE.
5. record_count:u32 LE followed by exactly that many typed field records.

Each field record is `section_id:u32, owner_key:string, field_key:string,
type:u8, value_count:u64, values`. Keys are unique nonempty ASCII, max256 bytes
per key. Types0–5 use the rules-manifest encodings above; each type5 value has
its own u32 UTF-8 byte length. There is no record terminator/padding. Records
appear by section1–14, then ASCII owner_key, then the DECLARED field ordinal in
that owner's versioned canonical schema (not alphabetically by display label).
The canonical registry supplies the finite record_count and ordered declarations;
missing/duplicate/unregistered fields or an order mismatch fail verification.

Packed slot columns emit full schema capacity in ascending slot order, with
unused payload normalized to zero, while preserving every generation/retirement
and future-affecting allocator value. An occupancy column is emitted before
other columns for sparse stores. Do not sort active residents by names or compact
holes. Dense event/command sequences emit their exact used rows in execution
order; schema declares count/order fields before dependent data. A variable
child arena emits owner slots in ascending order, per-owner child counts first,
then flattened child fields in child-index order. Explicit offsets/used-prefix
bytes that affect future admission remain separate canonical fields; semantic
normalization cannot erase them. Each owner schema must declare which of these
storage forms applies before registration; no inference from GDScript object
iteration is allowed. Direct binary strings follow SAVE-R09-002, not intern IDs.

Prefix-owned tick/compatibility values are emitted once and excluded from the
field records. Chronicle contributes its count:u64 and rolling-digest32bytes
(type0,count32), never its whole historical stream; validate that stream against
the rolling digest separately. Scheduler control state remains included except
ARCH-SAVE-007's explicit host debt/counter exclusions. Exclude UI selections,
rollback scratch, derived indexes and the other ARCH-HASH-001 exclusions from
record_count as well as values. No CRC, section15 or body-hash value is an input.

The save owner must freeze the actual ordered canonical registry with each
store owner BEFORE a production digest is emitted. The grammar above settles
framing; missing owner fields remain a coverage failure, not permission to hash
a subset. This uses bounded streaming and no second world. Add independent vectors
with holes/generations, zero-length fields, variable children and exclusions.

## Implementation order and evidence

1. Save coder: codec/version/length/descriptor validation and canonical identity
   artifact framing; world owner: map prefix bindings; each store owner: schema
   registrations, capacities and independent continuation fixtures.
2. Integration lead: registry ownership and memory deltas (reuse existing event allocator; exact map
   metadata/manifest resident bytes), section membership and canonical walker.
3. Event/Chronicle owner: real task08 producers, catalog domains and bounded
   stores. Save coder may use labelled empty fixtures while those are absent.
4. QA: independently pinned UTF-8/CRC/SHA/manifest vectors; perturb every identity
   component and missing registration; version refusals; gap/overlap/trailing/
   overflow corruption; separate generation spaces, slot holes and stale refs;
   full next-tick continuation at task09's required boundaries.

This package settles storage choices and responsibility. Task09.2 implementation,
complete authoritative registration, task08 event/history production, MOVE-G02's
expanded schema, transactional recovery and Windows parity remain unverified.

[Synthetic byte/hash vectors](../planning/save_identity_test_vectors.json) supply
independent encoder fixtures, not production compatibility digests. Reproduce
document/registry/arithmetic checks from the repository root with
`python3 docs/validation/validate_blocker_package.py`. This is not a codec test run.
