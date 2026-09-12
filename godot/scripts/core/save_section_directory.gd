extends RefCounted
## ARCH-SAVE-002 section 3 ENTITY_DIRECTORY: the identity backbone every `EntityRef` in every
## other section resolves through, encoded through `save_codec.gd`'s ARCH-SAVE-001 primitives.
##
## THIS IS THE DIRECTORY GENERATION NAMESPACE AND NO OTHER. The 2026-09-11 addendum records four
## distinct generation spaces in this codebase: `entity_directory.gd`'s slot generation (this
## one), `inventory.gd`'s container generation `_c_generation`, `inventory.gd`'s lot generation
## `_l_generation`, and `navigation.gd`'s route-descriptor generation. `gear.gd` and
## `reservations.gd` rows carry NO generation of their own and are addressed by bare row index.
## Every number this module validates as a generation is a DIRECTORY generation; a codec that
## checked a container handle against this column would accept a stale reference whose two
## integers happen to match.
##
## ## What section 3's bytes are
##
## SAVE-LAYOUT-R01 (2026-09-12) settles the framing and it is quoted, not invented: "For section3
## there is exactly one entity_directory block, primary_count equal to the compiled directory
## capacity (352418 in the reviewed baseline). Column order: `_active:u8`, `_generation:i32`,
## `_retired:u8`, `_persistent_id:i32`, `_kind:i32`, `_typed_row:i32`. Every column covers full
## capacity. Descriptor row_count is that capacity, never the count of living residents."
##
##   | Offset | Type     | Field                                              | Bytes   |
##   |-------:|----------|----------------------------------------------------|--------:|
##   |      0 | u32      | store_count = 1                                    |       4 |
##   |      4 | u32      | owner_key byte length = 16                         |       4 |
##   |      8 | utf8     | owner_key = "entity_directory"                     |      16 |
##   |     24 | u32      | owner_schema_version = 1                           |       4 |
##   |     28 | u64      | primary_count = 352418                             |       8 |
##   |     36 | u64      | payload_byte_length = 6343572                      |       8 |
##   |     44 | u64      | element_count = 352418                             |       8 |
##   |     52 | u8 x N   | `_active`                                          |  352418 |
##   | 352470 | u64      | element_count = 352418                             |       8 |
##   | 352478 | i32 x N  | `_generation`                                      | 1409672 |
##   |1762150 | u64      | element_count = 352418                             |       8 |
##   |1762158 | u8 x N   | `_retired`                                         |  352418 |
##   |2114576 | u64      | element_count = 352418                             |       8 |
##   |2114584 | i32 x N  | `_persistent_id`                                   | 1409672 |
##   |3524256 | u64      | element_count = 352418                             |       8 |
##   |3524264 | i32 x N  | `_kind`                                            | 1409672 |
##   |4933936 | u64      | element_count = 352418                             |       8 |
##   |4933944 | i32 x N  | `_typed_row`                                       | 1409672 |
##   |6343616 |          | end of section                                     |         |
##
## COLUMN-MAJOR, BY RULING AND NOT BY INFERENCE. SAVE-LAYOUT-R01: "Packed stores use column-major
## bytes. Field schema order is the outer loop; ascending physical slot is the inner loop. SoA
## does not mathematically force a wire order; this ruling explicitly chooses it."
##
## ## What is written, what is rebuilt, and why the two lists are not the same
##
## `docs/persistence_state_registry.md`'s `entity_directory.gd` rows classify every member, and
## this module follows that classification exactly:
##
##   * CATEGORY 1, WRITTEN (the six columns above). `_persistent_id` and `_kind` are the identity
##     pair; `_generation` is THE generation, held on the directory slot and not on the typed row;
##     `_active` is ARCH-SAVE-002's occupied bitset, one byte per slot and deliberately not a
##     packed bitset; `_retired` is its named "allocator-retirement state"; `_typed_row` is not
##     derivable, because nothing else records which row of a kind's store a slot owns.
##   * CATEGORY 2, REBUILT AND NEVER WRITTEN. `_typed_owner_slot` is the exact inverse of
##     `_typed_row`; writing it too would give ARCH-ID-003's validator two sources that can
##     disagree. `_free_heap` and `_heap_index` are min-heaps, and `_pop_min()` returns the window
##     MINIMUM, so allocation order depends on the SET of free entries and not on the array
##     permutation -- which is exactly why persisting them would be a bug and not merely waste.
##     ONLY the first `_free_count` / `_kind_free_count[kind]` entries of each window mean
##     anything; the tail is stale garbage left behind by earlier pops. Two worlds that are
##     identical in every observable way can hold different garbage there, so a section 3 that
##     wrote the heaps would make those two worlds produce different bytes and different CRCs.
##     `_kind_base` is the prefix sum of a compile-time constant. `_kind_free_count`,
##     `_kind_live_count`, `_free_count` and `_live_count` are counts of `_active`/`_retired`.
##   * CATEGORY 3, NOT STATE. `_last_refusal`, the code from the most recent refused `create()`.
##   * NOT THIS SECTION'S. `_next_persistent_id` IS future-affecting and IS NOT derivable
##     (`destroy()` zeroes `_persistent_id`, so "max live id + 1" is wrong the moment anything has
##     died), but the registry assigns it to §1 WORLD as `WorldRuntime.next_persistent_id`. See
##     BLOCKER D2: nothing writes it yet.
##
## PERSISTENCE OBLIGATION AND DIGEST MEMBERSHIP ARE SEPARATE AXES (decision 0063). For section 3
## the two lists happen to coincide, and that is a finding, not an assumption: ARCH-HASH-001
## includes "all authoritative occupied/generation and typed fields in schema order" and excludes
## "derived spatial/active indexes". So all six written columns are hashed, every category-2
## member is excluded from BOTH, and there is no section-3 field that is saved-but-not-hashed of
## the kind `save_section_world_runtime.gd` has in host debt and the six clock counters.
##
## ## Size: this section is streamed, because ARCH-SAVE-003 says large sections are
##
## 6343616 bytes is roughly sixty thousand times section 10 and eighty thousand times the
## WorldRuntime block. ARCH-SAVE-003: "stream Chronicle and large sections in 65536-byte chunks,
## calculating CRC/digest incrementally." `ChunkCursor` is that stream: bounded to CHUNK_BYTES per
## chunk, field-aligned so no chunk ever straddles two columns, and driven by the caller so the
## whole section never has to exist at once. `encode_record()` concatenates the same chunks for a
## caller that genuinely wants one buffer (fixtures, the canonical walker, tests) and says so.
##
## THE CHUNK CURSOR DOES NOT FOLD THE CRC ITSELF. `save_header.gd::crc32_update()` takes a running
## register and returns the next one, which is the incremental API ARCH-SAVE-003 asks for; the
## caller folds each chunk as it writes it, because the caller is the one that also has to fold
## the body SHA-256 over the same bytes and must not do it twice.
##
## ## Allocate before consume
##
## Decision 0059. `decode_into()` proves the whole extent is present, reads into a LOCAL Record,
## validates every framing field, every column domain and every cross-column invariant, and only
## then copies into the caller's Record. A refusal -- truncated, or full-length and invalid --
## leaves the caller's Record byte-identical. `test_save_section_directory.gd` asserts that by
## comparing the six columns, not by eye.
##
## ## The int32 sign trap
##
## GDScript ints are 64-bit, so `0x80000000` is a POSITIVE 2147483648 and `-2147483648` is the
## same bit pattern read as int32. Generation and persistent ID live at exactly that boundary:
## generation 2147483647 is the last one a slot ever spends before it retires. Every four-byte
## field here is read SIGNED, through `Reader.read_i32_into()`, because `save_codec.gd` carries
## signedness explicitly and never infers it from a width. A generation whose bytes are
## `00 00 00 80` therefore decodes as -2147483648 and is REFUSED as a negative generation, rather
## than being accepted as a plausible 2147483648 that no i32 column could ever have held.
##
## ## COLD PATH
##
## ARCH-SAVE-003 saves at a completed boundary and loads at a load boundary. This module allocates
## Records, Deriveds and chunk buffers freely. It is explicitly NOT a per-tick path; ARCH-MEM-001's
## per-tick allocation ban applies to `entity_directory.gd`'s columns, which this module only
## mirrors. Nothing here is a new authoritative column: `Record` and `Derived` are bounded codec
## scratch that exists only between `capture` and `apply`.
##
## ## NO FLOAT
##
## ARCH-AUTH-002. There is no float in this file and there must never be one;
## `test_save_section_directory.gd` greps this source to enforce that.
##
## ## BLOCKER D1 -- THERE IS NO WAY TO READ, OR TO PUBLISH, THE FULL COLUMNS OF A LIVE DIRECTORY
##
## `entity_directory.gd` is owned by another agent and is byte-untouched here. Its public surface
## is `ref_of_slot()`, `get_kind()`, `get_typed_row()`, `get_persistent_id()`, `is_slot_retired()`
## and the counters -- every one of which answers only for a LIVE slot. There is no reader for the
## generation of an INACTIVE slot, and that is precisely the value the registry says must survive
## verbatim: "a load that wrote generations only for live slots, or that reset them, would hand
## the next `create()` a `(slot, generation)` pair that an `EntityRef` taken before the save still
## holds". There is no writer for any column at all, and no reachable variant of
## `_rebuild_free_heaps()` that excludes live slots.
##
## No module in this repository reads another module's underscore-prefixed columns, and this one
## will not be the first: reaching into `store._generation` would put the heap invariants in two
## files. `save_section_world_runtime.gd` hit the same wall against `sim_clock.gd` (its BLOCKER
## W1), refused to half-publish, and Astra then ruled the missing API into existence as
## RESTORE-R01's `restore_runtime()`. This module takes the same position. What section 3 needs
## from the directory owner is two bulk, by-reference column operations:
##
##     func copy_columns_into(out_active: PackedByteArray, out_generation: PackedInt32Array,
##         out_retired: PackedByteArray, out_persistent_id: PackedInt32Array,
##         out_kind: PackedInt32Array, out_typed_row: PackedInt32Array) -> bool
##     func restore_columns(active: PackedByteArray, generation: PackedInt32Array,
##         retired: PackedByteArray, persistent_id: PackedInt32Array,
##         kind: PackedInt32Array, typed_row: PackedInt32Array) -> bool
##
## `restore_columns()` must, after assigning the six, rebuild `_typed_owner_slot`, both heaps and
## all five counters from them, excluding live slots from `_free_heap` and filling every window
## ASCENDING -- ascending fill is what makes the rebuild canonical, because it is what makes the
## next `create()` return the lowest free slot. Until those exist, `capture_columns_into()` is the
## capture step and takes the columns from whoever can supply them, `capture_into()` refuses
## explicitly rather than capturing five of six columns, and there is no `apply()`.
## `agrees_with_directory()` verifies a decoded Record against a live store as far as the public
## readers allow, which is every live slot and every counter.
##
## ## BLOCKER D2 -- `_next_persistent_id` IS REGISTERED TO §1 WORLD AND NOBODY WRITES IT
##
## The registry puts it in §1 as `WorldRuntime.next_persistent_id`, so it is deliberately absent
## from this section's six columns. But `save_section_world_runtime.gd`'s 80-byte block does not
## carry it either, and `entity_directory.gd` exposes no reader for it. Until §1's owner adds the
## field AND the directory owner adds a reader, a reloaded world restarts persistent IDs at 1 and
## breaks ARCH-SAVE-004's unique-persistent-id validation. Section 3 cannot fix this by writing
## the scalar itself: that would put one future-affecting value in two sections.
##
## ## OPEN, NOT INVENTED
##
##   * `owner_key` is `"entity_directory"`. SAVE-LAYOUT-R01 names the block in exactly those
##     words ("exactly one entity_directory block") and the registry heads its rows with
##     `godot/scripts/core/entity_directory.gd`, so the key is read off the ruling rather than
##     chosen. No document publishes the formal section-3 owner-key registry; if one lands with a
##     different spelling, OWNER_KEY and OWNER_SCHEMA_VERSION change together and the schema
##     version increments.
##   * `owner_schema_version` is 1, from SAVE-LAYOUT-R01's "Adopt the above as the initial
##     section3/4/5/10 schema1 framing". The 64-byte DESCRIPTOR's `schema_version` is a different
##     number, carried opaquely by `save_header.gd`, and is not set here.
##   * `FIELD_KEYS` are this module's PROPOSAL for SAVE-R09's canonical `field_key` strings, taken
##     from the actual member names. SAVE-R09 requires the save owner to freeze the ordered
##     canonical registry with each store owner before a production digest is emitted, and that
##     registry does not exist yet, so this module emits canonical VALUES only
##     (`ColumnCursor`) and leaves the `section_id/owner_key/field_key/type/value_count` record
##     prefix to section 15, which owns `RWL-STATE-1`.
##   * The section CRC-32 and the body SHA-256 are `save_header.gd`'s. This module produces the
##     bytes they protect and computes neither.

## Self-preload, so the inner cursor classes can reach this script's static functions. An inner
## class resolves constants from its outer script but NOT functions, exactly as `save_codec.gd`'s
## own `SaveCodecScript` self-preload exists to work around.
const SaveSectionDirectoryScript := preload("res://scripts/core/save_section_directory.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "1 WORLD, 2 CATALOG_IDS, 3 ENTITY_DIRECTORY, ...".
const SECTION_ID: int = 3

## SAVE-LAYOUT-R01: "exactly one entity_directory block".
const STORE_COUNT: int = 1
const OWNER_KEY: String = "entity_directory"
const OWNER_KEY_BYTES: int = 16
## SAVE-LAYOUT-R01: "nonempty ASCII, max256 bytes".
const OWNER_KEY_MAX_BYTES: int = 256
const OWNER_SCHEMA_VERSION: int = 1

## Taken from `entity_directory.gd` rather than restated, so the two cannot drift.
const PRIMARY_COUNT: int = EntityDirectoryScript.DIRECTORY_CAPACITY
const KIND_COUNT: int = EntityDirectoryScript.KIND_COUNT
const MAX_INT32: int = EntityDirectoryScript.MAX_INT32
const NULL_SLOT: int = EntityDirectoryScript.NULL_SLOT
const KIND_ANY: int = EntityDirectoryScript.KIND_ANY
const RESIDENT_LIVING_CAP: int = EntityDirectoryScript.RESIDENT_LIVING_CAP
const KIND_RESIDENT: int = EntityDirectoryScript.KIND_RESIDENT

## Declared field ordinals, in SAVE-LAYOUT-R01's stated column order. Changing one changes the
## wire format and must increment OWNER_SCHEMA_VERSION.
const FIELD_ACTIVE: int = 0
const FIELD_GENERATION: int = 1
const FIELD_RETIRED: int = 2
const FIELD_PERSISTENT_ID: int = 3
const FIELD_KIND: int = 4
const FIELD_TYPED_ROW: int = 5
const FIELD_COUNT: int = 6

## Element width of each field, by ordinal.
const FIELD_WIDTHS: Array[int] = [1, 4, 1, 4, 4, 4]

## 1+4+1+4+4+4. Stated as a constant because PAYLOAD_BYTES needs it before any function runs;
## `total_field_width()` recomputes it from FIELD_WIDTHS and the suite asserts the two agree.
const TOTAL_FIELD_WIDTH: int = 18

## SAVE-R09 canonical type codes: 0 = u8, 2 = i32. Used for the record prefixes section 15 builds.
const CANONICAL_TYPE_U8: int = 0
const CANONICAL_TYPE_I32: int = 2

## This module's PROPOSAL for the canonical field keys; see OPEN, NOT INVENTED.
const FIELD_KEYS: Array[StringName] = [
	&"_active", &"_generation", &"_retired", &"_persistent_id", &"_kind", &"_typed_row",
]

const OFFSET_STORE_COUNT: int = 0
const OFFSET_OWNER_KEY_LENGTH: int = 4
const OFFSET_OWNER_KEY: int = 8
const OFFSET_OWNER_SCHEMA_VERSION: int = 24
const OFFSET_PRIMARY_COUNT: int = 28
const OFFSET_PAYLOAD_BYTE_LENGTH: int = 36
const FRAMING_BYTES: int = 44

## Each field's payload is `element_count:u64` then its tightly packed LE values.
const ELEMENT_COUNT_BYTES: int = 8
const PAYLOAD_BYTES: int = FIELD_COUNT * ELEMENT_COUNT_BYTES + TOTAL_FIELD_WIDTH * PRIMARY_COUNT
const SECTION_BYTES: int = FRAMING_BYTES + PAYLOAD_BYTES

## ARCH-SAVE-003: "stream Chronicle and large sections in 65536-byte chunks".
const CHUNK_BYTES: int = 65536

## `save_header.gd`'s endian sentinel, reused as the little-endian probe constant. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BYTE_ORDER: StringName = &"SAVE_DIR_BYTE_ORDER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_DIR_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_DIR_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_DIR_LENGTH"
const REFUSE_RECORD_SHAPE: StringName = &"SAVE_DIR_RECORD_SHAPE"
const REFUSE_STORE_COUNT: StringName = &"SAVE_DIR_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_DIR_OWNER_KEY"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_DIR_OWNER_SCHEMA_VERSION"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_DIR_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_DIR_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_DIR_ELEMENT_COUNT"
const REFUSE_OCCUPANCY_BYTE: StringName = &"SAVE_DIR_OCCUPANCY_BYTE"
const REFUSE_RETIRED_BYTE: StringName = &"SAVE_DIR_RETIRED_BYTE"
const REFUSE_GENERATION_RANGE: StringName = &"SAVE_DIR_GENERATION_RANGE"
const REFUSE_RETIREMENT_DISAGREES: StringName = &"SAVE_DIR_RETIREMENT_DISAGREES"
const REFUSE_FREE_SLOT_IDENTITY: StringName = &"SAVE_DIR_FREE_SLOT_IDENTITY"
const REFUSE_LIVE_SLOT_GENERATION: StringName = &"SAVE_DIR_LIVE_SLOT_GENERATION"
const REFUSE_LIVE_SLOT_PERSISTENT_ID: StringName = &"SAVE_DIR_LIVE_SLOT_PERSISTENT_ID"
const REFUSE_LIVE_SLOT_KIND: StringName = &"SAVE_DIR_LIVE_SLOT_KIND"
const REFUSE_LIVE_SLOT_ROW: StringName = &"SAVE_DIR_LIVE_SLOT_ROW"
const REFUSE_DUPLICATE_TYPED_ROW: StringName = &"SAVE_DIR_DUPLICATE_TYPED_ROW"
const REFUSE_DUPLICATE_PERSISTENT_ID: StringName = &"SAVE_DIR_DUPLICATE_PERSISTENT_ID"
const REFUSE_KIND_OVERFLOW: StringName = &"SAVE_DIR_KIND_OVERFLOW"
const REFUSE_LIVING_CAP: StringName = &"SAVE_DIR_LIVING_CAP"
const REFUSE_FIELD_ORDINAL: StringName = &"SAVE_DIR_FIELD_ORDINAL"
const REFUSE_CURSOR_EXHAUSTED: StringName = &"SAVE_DIR_CURSOR_EXHAUSTED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_DIR_ENCODE_FAILED"
const REFUSE_STORE_NO_COLUMN_READER: StringName = &"SAVE_DIR_STORE_NO_COLUMN_READER"
const REFUSE_STORE_MISMATCH: StringName = &"SAVE_DIR_STORE_MISMATCH"


class Record:
	"""One decoded section 3: the six category-1 columns, each at full directory capacity.

	Allocated once in `_init` and never resized again. There is no heap column and no counter
	column here, and that absence is the design: see the module header on why persisting the
	min-heaps would make two identical worlds produce different bytes.
	"""
	var active: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var retired: PackedByteArray = PackedByteArray()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate all six columns to DIRECTORY_CAPACITY. The only place this class resizes."""
		active.resize(PRIMARY_COUNT)
		generation.resize(PRIMARY_COUNT)
		retired.resize(PRIMARY_COUNT)
		persistent_id.resize(PRIMARY_COUNT)
		kind.resize(PRIMARY_COUNT)
		typed_row.resize(PRIMARY_COUNT)
		clear()

	func clear() -> void:
		"""Refill every column with SAVE-LAYOUT-R01's DECLARED canonical never-used value.

		"Use zero only where the owner declares zero": `_kind` and `_typed_row` go to -1, not 0.
		A never-used slot holds generation 0, which is GDD §4.1's null generation.
		"""
		active.fill(0)
		generation.fill(0)
		retired.fill(0)
		persistent_id.fill(0)
		kind.fill(KIND_ANY)
		typed_row.fill(NULL_SLOT)

	func copy_from(other: Record) -> void:
		"""Overwrite all six columns from `other`. Six C++ copies on the cold path, no loop."""
		active = other.active.duplicate()
		generation = other.generation.duplicate()
		retired = other.retired.duplicate()
		persistent_id = other.persistent_id.duplicate()
		kind = other.kind.duplicate()
		typed_row = other.typed_row.duplicate()

	func equals(other: Record) -> bool:
		"""True when all six columns are byte-identical. Used to prove a refusal changed nothing."""
		return active == other.active and generation == other.generation \
			and retired == other.retired and persistent_id == other.persistent_id \
			and kind == other.kind and typed_row == other.typed_row


class Derived:
	"""The category-2 members section 3 rebuilds instead of writing, and never persists.

	`typed_owner_slot` is `_typed_owner_slot` exactly: the inverse of `_typed_row`, indexed by
	`_kind_base[kind] + row`. The four counters mirror `_live_count`, `_free_count` and the two
	per-kind counters. The two min-heaps are deliberately absent: rebuilding them is
	`entity_directory.gd`'s own `_rebuild_free_heaps()`, and reimplementing it here would put the
	heap invariants in two files (BLOCKER D1).
	"""
	var typed_owner_slot: PackedInt32Array = PackedInt32Array()
	var kind_live_count: PackedInt32Array = PackedInt32Array()
	var kind_free_count: PackedInt32Array = PackedInt32Array()
	var live_count: int = 0
	var inactive_count: int = 0
	var retired_count: int = 0
	var allocatable_slot_count: int = 0

	func _init() -> void:
		"""Allocate the reverse map and both per-kind counters once."""
		typed_owner_slot.resize(PRIMARY_COUNT)
		kind_live_count.resize(KIND_COUNT)
		kind_free_count.resize(KIND_COUNT)
		clear()

	func clear() -> void:
		"""Reset to the empty-directory state: no owner anywhere, no live row of any kind."""
		typed_owner_slot.fill(NULL_SLOT)
		kind_live_count.fill(0)
		kind_free_count.fill(0)
		live_count = 0
		inactive_count = 0
		retired_count = 0
		allocatable_slot_count = 0


class Chunk:
	"""One streamed chunk: at most CHUNK_BYTES of payload, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record one chunk's bytes; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with no bytes; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


class EncodeResult:
	"""Outcome of materialising a whole section: the payload bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded payload; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


class ColumnCursor:
	"""Streams ONE column's values in field-aligned chunks of at most CHUNK_BYTES.

	This is also section 15's handle on section 3: SAVE-R09's canonical field record is
	`section_id, owner_key, field_key, type, value_count, values`, and this cursor produces
	exactly the `values` half. The record prefix belongs to the canonical registry, which is not
	frozen yet (see OPEN, NOT INVENTED), so nothing here writes a key or a type code.
	"""
	var _record: Record
	var _field: int
	var _element: int = 0
	var _per_chunk: int = 0

	func _init(p_record: Record, p_field: int) -> void:
		"""Open a cursor over one field. `elements_per_chunk()` fixes the chunk granularity."""
		_record = p_record
		_field = p_field
		_per_chunk = SaveSectionDirectoryScript.elements_per_chunk(p_field)

	func field() -> int:
		"""The field ordinal this cursor streams."""
		return _field

	func has_more() -> bool:
		"""True while unemitted values remain."""
		return _element < PRIMARY_COUNT

	func next_chunk_into(out: Chunk) -> bool:
		"""Emit the next run of values, at most CHUNK_BYTES. Refuses past the end of the column."""
		if not has_more():
			return out.refuse(REFUSE_CURSOR_EXHAUSTED,
				"field %d already emitted all %d values" % [_field, PRIMARY_COUNT])
		var end: int = mini(_element + _per_chunk, PRIMARY_COUNT)
		var bytes: PackedByteArray = _slice(_element, end)
		_element = end
		return out.succeed(bytes)

	func _slice(start: int, end: int) -> PackedByteArray:
		"""The little-endian bytes of one column's `[start, end)` values. C++ copies, no loop."""
		if _field == FIELD_ACTIVE:
			return _record.active.slice(start, end)
		if _field == FIELD_GENERATION:
			return _record.generation.slice(start, end).to_byte_array()
		if _field == FIELD_RETIRED:
			return _record.retired.slice(start, end)
		if _field == FIELD_PERSISTENT_ID:
			return _record.persistent_id.slice(start, end).to_byte_array()
		if _field == FIELD_KIND:
			return _record.kind.slice(start, end).to_byte_array()
		return _record.typed_row.slice(start, end).to_byte_array()


class ChunkCursor:
	"""Streams a whole section 3 in chunks of at most CHUNK_BYTES, never materialising it.

	Chunk boundaries are field-aligned: the 44 framing bytes are one chunk, each field's 8-byte
	`element_count` is one chunk, and a column's values are split into whole-element runs. No
	chunk straddles two columns, so a caller folding CRC-32 and SHA-256 over the stream sees the
	same bytes `encode_record()` would produce, in the same order.
	"""
	var _record: Record
	var _field: int = 0
	var _framing_done: bool = false
	var _count_done: bool = false
	var _emitted: int = 0
	var _column: ColumnCursor = null

	func _init(p_record: Record) -> void:
		"""Open a cursor positioned before the framing chunk."""
		_record = p_record

	func has_more() -> bool:
		"""True while any chunk of the section is still unemitted."""
		return not _framing_done or _field < FIELD_COUNT

	func emitted_bytes() -> int:
		"""Total bytes emitted so far. Equals SECTION_BYTES once the cursor is drained."""
		return _emitted

	func next_chunk_into(out: Chunk) -> bool:
		"""Emit the next chunk of the section, or refuse past its end."""
		if not _framing_done:
			return _framing_into(out)
		if _field >= FIELD_COUNT:
			return out.refuse(REFUSE_CURSOR_EXHAUSTED,
				"section 3 already emitted all %d bytes" % _emitted)
		if not _count_done:
			return _count_into(out)
		return _values_into(out)

	func _framing_into(out: Chunk) -> bool:
		"""Emit the 44-byte block header, refusing first if this build is not little-endian."""
		var order: SaveHeader.Refusal = SaveSectionDirectoryScript.byte_order_refusal()
		if not order.is_ok():
			return out.refuse(order.code, order.detail)
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(FRAMING_BYTES)
		writer.write_u32(STORE_COUNT)
		writer.write_utf8_u32(OWNER_KEY, OWNER_KEY_MAX_BYTES)
		writer.write_u32(OWNER_SCHEMA_VERSION)
		writer.write_u64(PRIMARY_COUNT)
		writer.write_u64(PAYLOAD_BYTES)
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		_framing_done = true
		return _accept(writer.to_bytes(), out)

	func _count_into(out: Chunk) -> bool:
		"""Emit one field's `element_count:u64`, which is always the full directory capacity."""
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(ELEMENT_COUNT_BYTES)
		writer.write_u64(PRIMARY_COUNT)
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		_count_done = true
		_column = ColumnCursor.new(_record, _field)
		return _accept(writer.to_bytes(), out)

	func _values_into(out: Chunk) -> bool:
		"""Emit the next run of the current column's values, advancing the field when it ends."""
		if not _column.next_chunk_into(out):
			return false
		if not _column.has_more():
			_field += 1
			_count_done = false
		_emitted += out.bytes.size()
		return true

	func _accept(bytes: PackedByteArray, out: Chunk) -> bool:
		"""Count a framing or count chunk toward `emitted_bytes()` and hand it to the caller."""
		_emitted += bytes.size()
		return out.succeed(bytes)


# --- layout arithmetic ----------------------------------------------------------------------------

static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove `PackedInt32Array.to_byte_array()` is little-endian on this build.

	The bulk conversions in `ColumnCursor._slice()` and `decode_into()` are C++ memory copies, not
	`save_codec.gd` writes, so they inherit the host's byte order instead of the codec's explicit
	little-endian. Every Godot target platform is little-endian, but an assumption that is never
	checked is how a save written on one machine silently transposes every generation on another.
	This turns it into one four-byte refusal per encode and per decode.
	"""
	var probe: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()
	if probe.size() != SaveCodec.I32_BYTES:
		return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
			"an i32 converted to %d bytes, not %d" % [probe.size(), SaveCodec.I32_BYTES])
	for index: int in SaveCodec.I32_BYTES:
		var expected: int = (BYTE_ORDER_PROBE >> (index * 8)) & SaveCodec.UINT8_MAX
		if probe[index] != expected:
			return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
				"byte %d of the sentinel is %d, not the little-endian %d"
					% [index, probe[index], expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func total_field_width() -> int:
	"""Sum of the six element widths, recomputed so TOTAL_FIELD_WIDTH cannot drift from them."""
	var total: int = 0
	for field: int in FIELD_COUNT:
		total += FIELD_WIDTHS[field]
	return total


static func elements_per_chunk(field: int) -> int:
	"""How many of one field's values fit in CHUNK_BYTES. 65536 for a u8 column, 16384 for i32."""
	return CHUNK_BYTES / FIELD_WIDTHS[field]


static func field_count_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's `element_count:u64`."""
	var offset: int = FRAMING_BYTES
	for earlier: int in field:
		offset += ELEMENT_COUNT_BYTES + FIELD_WIDTHS[earlier] * PRIMARY_COUNT
	return offset


static func field_value_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's first value."""
	return field_count_offset(field) + ELEMENT_COUNT_BYTES


static func canonical_type_of(field: int) -> int:
	"""SAVE-R09's type code for one field: 0 for the u8 columns, 2 for the i32 columns."""
	if FIELD_WIDTHS[field] == SaveCodec.U8_BYTES:
		return CANONICAL_TYPE_U8
	return CANONICAL_TYPE_I32


static func descriptor_row_count() -> int:
	"""SAVE-LAYOUT-R01: "Descriptor row_count is that capacity, never the count of living residents"."""
	return PRIMARY_COUNT


# --- capture -------------------------------------------------------------------------------------

static func capture_columns_into(active: PackedByteArray, generation: PackedInt32Array,
		retired: PackedByteArray, persistent_id: PackedInt32Array, kind: PackedInt32Array,
		typed_row: PackedInt32Array, out: Record) -> SaveHeader.Refusal:
	"""Validate six supplied directory columns and copy them into a caller-owned Record.

	This is the capture step. It takes columns rather than a store because BLOCKER D1 says
	`entity_directory.gd` publishes no bulk column reader yet; the day it does, the wrapper is two
	lines. `out` is untouched unless every shape, domain and cross-column rule passes.
	"""
	var staged: Record = Record.new()
	staged.active = active.duplicate()
	staged.generation = generation.duplicate()
	staged.retired = retired.duplicate()
	staged.persistent_id = persistent_id.duplicate()
	staged.kind = kind.duplicate()
	staged.typed_row = typed_row.duplicate()
	var invalid: SaveHeader.Refusal = record_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func capture_into(store: EntityDirectoryScript, out: Record) -> SaveHeader.Refusal:
	"""Refuse to capture a live directory, because its generation column is not readable.

	BLOCKER D1 in full. `store` answers `ref_of_slot()` only for a LIVE slot, so the generation of
	every free and retired slot -- the column the registry says must survive verbatim -- is
	unreachable through the public surface. Capturing the other five and leaving that one at zero
	would hand the next `create()` a `(slot, generation)` pair that a pre-save `EntityRef` still
	holds. `out` is deliberately untouched: this refuses rather than half-capturing.
	"""
	return SaveHeader.Refusal.new(REFUSE_STORE_NO_COLUMN_READER,
		("entity_directory.gd exposes no reader for the generation of an inactive slot, so the "
			+ "%d live of %d slots are capturable and the free-slot generations are not; "
			+ "it needs copy_columns_into(...) (BLOCKER D1). Use capture_columns_into().")
			% [store.total_live_count(), PRIMARY_COUNT])


# --- encode ---------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole validated section 3 in one buffer, by draining a `ChunkCursor`.

	ARCH-SAVE-003 streams large sections, and `ChunkCursor` is that stream; this is the
	concatenation, for a caller that genuinely wants all 6343616 bytes at once -- a pinned
	fixture, the canonical walker, a test. A file writer should drive the cursor instead.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	var cursor: ChunkCursor = ChunkCursor.new(record)
	var chunk: Chunk = Chunk.new()
	while cursor.has_more():
		if not cursor.next_chunk_into(chunk):
			return out.refuse(chunk.refusal, chunk.detail)
		if chunk.bytes.size() > CHUNK_BYTES:
			return out.refuse(REFUSE_LENGTH,
				"a chunk of %d bytes exceeds the %d-byte stream bound"
					% [chunk.bytes.size(), CHUNK_BYTES])
		buffer.append_array(chunk.bytes)
	if buffer.size() != SECTION_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"encoded %d bytes, not the fixed %d" % [buffer.size(), SECTION_BYTES])
	return out.succeed(buffer)


# --- decode ----------------------------------------------------------------------------------------

static func decode_into(bytes: PackedByteArray, offset: int, out: Record) -> SaveHeader.Refusal:
	"""Decode section 3 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the extent is proved, the framing is checked, the six
	columns land in a LOCAL Record, and every cross-column invariant runs against that local. Only
	then is `out` overwritten. A full-length section carrying an invalid generation, a reusable
	retired slot or a live slot claiming an occupied typed row therefore leaves `out` byte-
	identical -- validate-then-commit, never commit-then-validate.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var framing: SaveHeader.Refusal = _read_framing(reader)
	if not framing.is_ok():
		return framing
	var parsed: Record = Record.new()
	var columns: SaveHeader.Refusal = _read_columns(bytes, reader, parsed)
	if not columns.is_ok():
		return columns
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove `SECTION_BYTES` are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_rng.gd::extent_refusal()` is: the Reader is bounded too, so a slack extent check
	would still end in a refusal and hide. A load orchestrator can also ask before committing.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < SECTION_BYTES or offset > bytes.size() - SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 3 needs %d bytes at offset %d, buffer holds %d"
				% [SECTION_BYTES, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func section_length_refusal(byte_length: int) -> SaveHeader.Refusal:
	"""Check a descriptor's declared section length against this schema's fixed size.

	SAVE-R09-004 requires exact block consumption and no trailing bytes; section 3 has one fixed
	length, so the descriptor is wrong before a single payload byte is read.
	"""
	if byte_length != SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 3 declares %d bytes, not the fixed %d" % [byte_length, SECTION_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_framing(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read and check the 44-byte block header: store count, owner, schema, counts, length."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 3 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	var owner: SaveHeader.Refusal = _read_owner(reader)
	if not owner.is_ok():
		return owner
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"primary_count %d is not the compiled capacity %d" % [scalar.value, PRIMARY_COUNT])
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != PAYLOAD_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"payload_byte_length %d is not the fixed %d" % [scalar.value, PAYLOAD_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_owner(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read the owner key and its schema version, refusing any owner but this one."""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEY:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"section 3 block is owned by '%s', not '%s'" % [text.value, OWNER_KEY])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner schema %d is not the supported %d" % [scalar.value, OWNER_SCHEMA_VERSION])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_columns(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read all six `element_count` prefixes and their value runs into `parsed`."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for field: int in FIELD_COUNT:
		if not reader.read_u64_into(scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		if scalar.value != PRIMARY_COUNT:
			return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
				"field %d declares %d elements, not %d"
					% [field, scalar.value, PRIMARY_COUNT])
		var start: int = reader.position()
		var end: int = start + FIELD_WIDTHS[field] * PRIMARY_COUNT
		_assign_column(bytes.slice(start, end), field, parsed)
		if not reader.seek(end):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _assign_column(raw: PackedByteArray, field: int, parsed: Record) -> void:
	"""Reinterpret one column's little-endian bytes into its packed array. C++ copies, no loop."""
	if field == FIELD_ACTIVE:
		parsed.active = raw
	elif field == FIELD_GENERATION:
		parsed.generation = raw.to_int32_array()
	elif field == FIELD_RETIRED:
		parsed.retired = raw
	elif field == FIELD_PERSISTENT_ID:
		parsed.persistent_id = raw.to_int32_array()
	elif field == FIELD_KIND:
		parsed.kind = raw.to_int32_array()
	else:
		parsed.typed_row = raw.to_int32_array()


# --- validation ------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 3 rule, checked by rebuilding the derived indexes and discarding them."""
	return rebuild_into(record, Derived.new())


static func rebuild_into(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Validate a Record and rebuild every category-2 member of the directory from it.

	This is the "rebuild, never write" half of the registry's classification, and it is also the
	validator: a duplicate `(kind, row)` claim is found precisely because two live slots try to
	own the same `_typed_owner_slot` entry. `out` is scratch, cleared on entry, and its contents
	are meaningless unless the returned Refusal is ok -- unlike a decoded Record or a live store,
	which decision 0059 requires to stay byte-identical through a refusal.
	"""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	var domain: SaveHeader.Refusal = _domain_refusal(record)
	if not domain.is_ok():
		return domain
	out.clear()
	var live: SaveHeader.Refusal = _scan_live_refusal(record, out)
	if not live.is_ok():
		return live
	var retirement: SaveHeader.Refusal = _retirement_refusal(record, out)
	if not retirement.is_ok():
		return retirement
	return _closure_refusal(record, out)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column must be exactly DIRECTORY_CAPACITY long before anything indexes into it."""
	var sizes: Array[int] = [record.active.size(), record.generation.size(),
		record.retired.size(), record.persistent_id.size(), record.kind.size(),
		record.typed_row.size()]
	for field: int in FIELD_COUNT:
		if sizes[field] != PRIMARY_COUNT:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"column %s holds %d values, not %d"
					% [FIELD_KEYS[field], sizes[field], PRIMARY_COUNT])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""The two occupancy bytes are 0 or 1, and no generation is negative.

	The generation check sorts a copy rather than walking 352418 values in GDScript: the sort is
	one C++ call and only the minimum matters. It is the guard against the int32 sign trap --
	bytes `00 00 00 80` read signed are -2147483648, which no generation can ever be.
	"""
	if record.active.count(0) + record.active.count(1) != PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_OCCUPANCY_BYTE,
			"_active holds a byte outside {0, 1}")
	if record.retired.count(0) + record.retired.count(1) != PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_RETIRED_BYTE,
			"_retired holds a byte outside {0, 1}")
	var sorted: PackedInt32Array = record.generation.duplicate()
	sorted.sort()
	if sorted[0] < 0:
		return SaveHeader.Refusal.new(REFUSE_GENERATION_RANGE,
			"a directory generation is %d; generations start at 0 and only rise" % sorted[0])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _scan_live_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Walk only the live slots, validating each and rebuilding the reverse owner map.

	`PackedByteArray.find()` jumps from one live slot to the next in C++, so the cost is the
	number of LIVE rows and not the 352418-slot capacity.
	"""
	var slot: int = record.active.find(1, 0)
	while slot >= 0:
		var invalid: SaveHeader.Refusal = _live_slot_refusal(record, out, slot)
		if not invalid.is_ok():
			return invalid
		out.live_count += 1
		slot = record.active.find(1, slot + 1)
	out.inactive_count = PRIMARY_COUNT - out.live_count
	for kind: int in KIND_COUNT:
		out.kind_free_count[kind] = \
			EntityDirectoryScript.KIND_CAPACITY[kind] - out.kind_live_count[kind]
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _live_slot_refusal(record: Record, out: Derived, slot: int) -> SaveHeader.Refusal:
	"""Validate one live slot's four identity values and claim its typed row."""
	if record.generation[slot] < 1:
		return SaveHeader.Refusal.new(REFUSE_LIVE_SLOT_GENERATION,
			"live slot %d holds generation %d; _publish_row() starts live rows at 1"
				% [slot, record.generation[slot]])
	if record.persistent_id[slot] < 1:
		return SaveHeader.Refusal.new(REFUSE_LIVE_SLOT_PERSISTENT_ID,
			"live slot %d holds persistent id %d; 0 marks a free slot"
				% [slot, record.persistent_id[slot]])
	var kind: int = record.kind[slot]
	if kind < 0 or kind >= KIND_COUNT:
		return SaveHeader.Refusal.new(REFUSE_LIVE_SLOT_KIND,
			"live slot %d holds kind %d, outside [0, %d)" % [slot, kind, KIND_COUNT])
	var row: int = record.typed_row[slot]
	if row < 0 or row >= EntityDirectoryScript.KIND_CAPACITY[kind]:
		return SaveHeader.Refusal.new(REFUSE_LIVE_SLOT_ROW,
			"live slot %d claims row %d of kind %d, capacity %d"
				% [slot, row, kind, EntityDirectoryScript.KIND_CAPACITY[kind]])
	var arena: int = _kind_base_of(kind) + row
	if out.typed_owner_slot[arena] != NULL_SLOT:
		return SaveHeader.Refusal.new(REFUSE_DUPLICATE_TYPED_ROW,
			"slots %d and %d both claim row %d of kind %d"
				% [out.typed_owner_slot[arena], slot, row, kind])
	out.typed_owner_slot[arena] = slot
	out.kind_live_count[kind] += 1
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _kind_base_of(kind: int) -> int:
	"""The prefix sum `_kind_base[kind]` that partitions the reverse map into per-kind arenas.

	Recomputed from `KIND_CAPACITY` rather than persisted: the registry classifies `_kind_base` as
	the prefix sum of a compile-time constant, which "can never differ between two builds of the
	same rules".
	"""
	var base: int = 0
	for earlier: int in kind:
		base += EntityDirectoryScript.KIND_CAPACITY[earlier]
	return base


static func _retirement_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""A retired slot is inactive and holds the last generation; nothing else is retired.

	The registry: retirement "is also implied by `_generation[slot] >= 2147483647`, so a loader
	can and should cross-check the two rather than trust either alone". Both directions are
	checked, which is what makes a retired slot loaded as reusable a refusal rather than a
	plausible free slot the allocator will hand straight back out.
	"""
	var slot: int = record.retired.find(1, 0)
	while slot >= 0:
		if record.active[slot] != 0:
			return SaveHeader.Refusal.new(REFUSE_RETIREMENT_DISAGREES,
				"slot %d is retired and live at once" % slot)
		if record.generation[slot] != MAX_INT32:
			return SaveHeader.Refusal.new(REFUSE_RETIREMENT_DISAGREES,
				"retired slot %d holds generation %d, not the spent %d"
					% [slot, record.generation[slot], MAX_INT32])
		out.retired_count += 1
		slot = record.retired.find(1, slot + 1)
	out.allocatable_slot_count = out.inactive_count - out.retired_count
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _closure_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Whole-column closure: free slots carry their declared unused values, nothing else does."""
	var unused: SaveHeader.Refusal = _unused_value_refusal(record, out)
	if not unused.is_ok():
		return unused
	var spent: int = record.generation.count(MAX_INT32)
	var live_spent: int = _live_spent_generation_count(record)
	if spent - live_spent != out.retired_count:
		return SaveHeader.Refusal.new(REFUSE_RETIREMENT_DISAGREES,
			"%d inactive slots hold the spent generation but %d are retired"
				% [spent - live_spent, out.retired_count])
	var duplicate: SaveHeader.Refusal = _persistent_id_refusal(record, out)
	if not duplicate.is_ok():
		return duplicate
	return _capacity_refusal(out)


static func _unused_value_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""Exactly the inactive slots hold `_persistent_id` 0, `_kind` -1 and `_typed_row` -1.

	Counting is enough because `_live_slot_refusal()` has already proved every LIVE slot holds an
	id of at least 1, a kind inside `[0, 18)` and a row of at least 0 -- none of which is the
	unused value. So if the column holds exactly `inactive_count` unused values, they can only be
	on the inactive slots. This is what refuses a free slot whose -1 typed row was loaded as row 0.
	"""
	if record.persistent_id.count(0) != out.inactive_count:
		return SaveHeader.Refusal.new(REFUSE_FREE_SLOT_IDENTITY,
			"%d slots hold persistent id 0 but %d are inactive"
				% [record.persistent_id.count(0), out.inactive_count])
	if record.kind.count(KIND_ANY) != out.inactive_count:
		return SaveHeader.Refusal.new(REFUSE_FREE_SLOT_IDENTITY,
			"%d slots hold kind %d but %d are inactive"
				% [record.kind.count(KIND_ANY), KIND_ANY, out.inactive_count])
	if record.typed_row.count(NULL_SLOT) != out.inactive_count:
		return SaveHeader.Refusal.new(REFUSE_FREE_SLOT_IDENTITY,
			"%d slots hold typed row %d but %d are inactive"
				% [record.typed_row.count(NULL_SLOT), NULL_SLOT, out.inactive_count])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _live_spent_generation_count(record: Record) -> int:
	"""How many LIVE slots sit on the last generation they will ever hold.

	A slot reaches 2147483647 while still live -- it retires on the NEXT `destroy()`, not on
	reaching the value -- so this count is what separates "spent and retired" from "spent and
	still in use" in `_closure_refusal()`.
	"""
	var total: int = 0
	var slot: int = record.active.find(1, 0)
	while slot >= 0:
		if record.generation[slot] == MAX_INT32:
			total += 1
		slot = record.active.find(1, slot + 1)
	return total


static func _persistent_id_refusal(record: Record, out: Derived) -> SaveHeader.Refusal:
	"""No two live slots share a persistent ID (ARCH-SAVE-004's unique-persistent-id check).

	Sorting the whole column is one C++ call; the `inactive_count` zeros land first, already
	proved to be exactly the inactive slots, so only the live tail is walked.
	"""
	var sorted: PackedInt32Array = record.persistent_id.duplicate()
	sorted.sort()
	var index: int = out.inactive_count + 1
	while index < PRIMARY_COUNT:
		if sorted[index] == sorted[index - 1]:
			return SaveHeader.Refusal.new(REFUSE_DUPLICATE_PERSISTENT_ID,
				"persistent id %d is held by two live slots" % sorted[index])
		index += 1
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _capacity_refusal(out: Derived) -> SaveHeader.Refusal:
	"""No kind exceeds its typed-store capacity, and living residents stay at or below 256."""
	for kind: int in KIND_COUNT:
		if out.kind_live_count[kind] > EntityDirectoryScript.KIND_CAPACITY[kind]:
			return SaveHeader.Refusal.new(REFUSE_KIND_OVERFLOW,
				"kind %d holds %d live rows, capacity %d"
					% [kind, out.kind_live_count[kind],
						EntityDirectoryScript.KIND_CAPACITY[kind]])
	if out.kind_live_count[KIND_RESIDENT] > RESIDENT_LIVING_CAP:
		return SaveHeader.Refusal.new(REFUSE_LIVING_CAP,
			"%d living residents exceed the GDD §4.1 cap of %d"
				% [out.kind_live_count[KIND_RESIDENT], RESIDENT_LIVING_CAP])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- verification against a live store --------------------------------------------------------------

static func agrees_with_directory(record: Record,
		store: EntityDirectoryScript) -> SaveHeader.Refusal:
	"""Verify a decoded Record against a live directory, as far as the public readers allow.

	Every live slot's reference, kind, typed row and persistent ID is compared, and all five
	counters. What CANNOT be compared is the generation of an inactive slot, for the same
	BLOCKER D1 reason capture cannot read it; the counter comparison closes most of that gap,
	because a store with an extra retirement or an extra live row fails it.
	"""
	var derived: Derived = Derived.new()
	var invalid: SaveHeader.Refusal = rebuild_into(record, derived)
	if not invalid.is_ok():
		return invalid
	var live: SaveHeader.Refusal = _store_live_refusal(record, store)
	if not live.is_ok():
		return live
	return _store_counter_refusal(derived, store)


static func _store_live_refusal(record: Record,
		store: EntityDirectoryScript) -> SaveHeader.Refusal:
	"""Compare every live slot in the Record with the same slot in the store."""
	var slot: int = record.active.find(1, 0)
	while slot >= 0:
		var expected: Vector2i = Vector2i(slot, record.generation[slot])
		if store.ref_of_slot(slot) != expected:
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"slot %d is %s in the store, %s in the record"
					% [slot, store.ref_of_slot(slot), expected])
		var mismatch: SaveHeader.Refusal = _store_identity_refusal(record, store, expected)
		if not mismatch.is_ok():
			return mismatch
		if store.is_slot_retired(slot):
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"slot %d is live in the record and retired in the store" % slot)
		slot = record.active.find(1, slot + 1)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _store_identity_refusal(record: Record, store: EntityDirectoryScript,
		ref: Vector2i) -> SaveHeader.Refusal:
	"""Compare one live slot's kind, typed row and persistent ID with the store's."""
	var slot: int = ref.x
	if store.get_kind(ref) != record.kind[slot]:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"slot %d is kind %d in the store, %d in the record"
				% [slot, store.get_kind(ref), record.kind[slot]])
	if store.get_typed_row(ref) != record.typed_row[slot]:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"slot %d holds row %d in the store, %d in the record"
				% [slot, store.get_typed_row(ref), record.typed_row[slot]])
	if store.get_persistent_id(ref) != record.persistent_id[slot]:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"slot %d holds persistent id %d in the store, %d in the record"
				% [slot, store.get_persistent_id(ref), record.persistent_id[slot]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _store_counter_refusal(derived: Derived,
		store: EntityDirectoryScript) -> SaveHeader.Refusal:
	"""Compare the rebuilt counters with the store's own. This is where a retirement gap shows."""
	if store.total_live_count() != derived.live_count:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"the store holds %d live rows, the record %d"
				% [store.total_live_count(), derived.live_count])
	if store.free_slot_count() != derived.allocatable_slot_count:
		return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
			"the store has %d allocatable slots, the record %d"
				% [store.free_slot_count(), derived.allocatable_slot_count])
	for kind: int in KIND_COUNT:
		if store.live_count(kind) != derived.kind_live_count[kind]:
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"kind %d holds %d live rows in the store, %d in the record"
					% [kind, store.live_count(kind), derived.kind_live_count[kind]])
		if store.free_row_count(kind) != derived.kind_free_count[kind]:
			return SaveHeader.Refusal.new(REFUSE_STORE_MISMATCH,
				"kind %d has %d free rows in the store, %d in the record"
					% [kind, store.free_row_count(kind), derived.kind_free_count[kind]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
