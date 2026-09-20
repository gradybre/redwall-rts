extends RefCounted
## SAVE-J2-R02: shared schema2 layout, typed Record and pure structural validation.
## No planner/codec preload: both consume this schema without a cycle.
## Cold record payload383884B and dirty-validation scratch4096B; no live owner state.
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")

const OPERATION_FARM_TEND: int = 0
const OPERATION_FARM_SOW: int = 1
const OPERATION_COUNT: int = 2
const OWNER_CAPACITY: int = FarmingScript.FARM_PLOT_CAPACITY
const SERVICE_ROW_COUNT: int = OWNER_CAPACITY * OPERATION_COUNT
const ZONE_OWNER_CAPACITY: int = ForageScript.HARVEST_ZONE_CAPACITY
const PATCH_KIND_COUNT: int = ForageScript.PATCHES_PER_ZONE
const DEMAND_ROW_COUNT: int = ZONE_OWNER_CAPACITY * PATCH_KIND_COUNT
const HIVE_OWNER_CAPACITY: int = OrchardHiveScript.HIVE_CAPACITY
const STATUS_FREE: int = 0
const STATUS_PENDING: int = 1
const STATUS_UNMET: int = 2
const STATUS_REQUESTED: int = 3
const STATUS_COUNT: int = 4
const NO_DAY: int = 0
const NO_CYCLE: int = 0
const FIRST_CYCLE: int = 1
const MAX_FIELD_CYCLE: int = 2147483647
const NO_CROP: int = FarmingScript.CROP_NONE
const REASON_COUNT: int = 6
const HIVE_BLOCKER_COUNT: int = 5
const BLOCKER_COUNT: int = 12

# --- ARCH-SAVE-002 identity and layout ------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 7 INVENTORIES_AND_LEASE_INDEXES, 8 JOB_INDEXES, 9 NAVIGATION".
const SECTION_ID: int = 8

## REG-R01 registers exactly one section-8 owner; `jobs.gd`'s section-8 rows are all category 2.
const STORE_COUNT: int = 1
const OWNER_KEY: String = "job_planner"
const OWNER_KEY_BYTES: int = 11
## SAVE-LAYOUT-R01: "nonempty ASCII, max 256 bytes".
const OWNER_KEY_MAX_BYTES: int = 256
const OWNER_SCHEMA_VERSION: int = 2
const SECTION_SCHEMA_VERSION: int = 2
const PREAMBLE_BYTES: int = 23

# --- the five table extents, taken from the owning schema -----------------------------------------

## Shared with `job_planner.gd` through its public aliases. Every one of the five
## is named by the registry artifact's `shape.declared_capacity` for the fields that use it.
const SERVICE_ROWS: int = SERVICE_ROW_COUNT
const OWNER_ROWS: int = OWNER_CAPACITY
const ZONE_ROWS: int = ZONE_OWNER_CAPACITY
const DEMAND_ROWS: int = DEMAND_ROW_COUNT
const HIVE_ROWS: int = HIVE_OWNER_CAPACITY

## SAVE-C3-R01's designated primary count for this block: the PENDING-SERVICE row table.
##
## Written as `SERVICE_ROWS` and not as the literal 8192 because the ruling designates a TABLE, not
## a number -- "designate the pending-service row table, SERVICE_ROW_COUNT, as the primary
## operational table". If `job_planner.gd` ever resized that ledger, this word must move with it,
## and the owner schema version must move too. It is emphatically NOT "whatever ordinal 0's extent
## happens to be": the four other extents are read from their own constants and checked separately,
## and 14080 (all five summed), 5248 (the three owner capacities summed), 4096 (the secondary
## per-plot cycle table) and 7 (the retired test fixture) are each refused by name below.
const PRIMARY_COUNT: int = SERVICE_ROWS

## The planner and codec share these domains.
const CROP_COUNT: int = FarmingScript.CROP_COUNT

## The directory domain every slot/generation pair in this section belongs to.
const DIRECTORY_CAPACITY: int = EntityDirectoryScript.DIRECTORY_CAPACITY
const NULL_SLOT: int = EntityDirectoryScript.NULL_SLOT
const NULL_GENERATION: int = EntityDirectoryScript.NULL_GENERATION
const MAX_INT32: int = EntityDirectoryScript.MAX_INT32

# --- the 35 declared fields, in REG-R01's ordinal order -------------------------------------------

const FIELD_OWNER_SLOT: int = 0
const FIELD_OWNER_GENERATION: int = 1
const FIELD_SERVICE_DAY: int = 2
const FIELD_JOB_SLOT: int = 3
const FIELD_JOB_GENERATION: int = 4
const FIELD_SERVICED_DAY: int = 5
const FIELD_STATUS: int = 6
const FIELD_REQUIRES_WATER: int = 7
const FIELD_FIELD_CYCLE: int = 8
const FIELD_REQUESTED_CROP: int = 9
const FIELD_GATE_REASON: int = 10
const FIELD_CYCLE_CURSOR: int = 11
const FIELD_COMPLETED_CYCLE: int = 12
const FIELD_DEMAND_ENABLED: int = 13
const FIELD_DEMAND_OWNER_SLOT: int = 14
const FIELD_DEMAND_OWNER_GENERATION: int = 15
const FIELD_DEMAND_STATUS: int = 16
const FIELD_DEMAND_BLOCKER: int = 17
const FIELD_DEMAND_JOB_SLOT: int = 18
const FIELD_DEMAND_JOB_GENERATION: int = 19
const FIELD_DEMAND_QUANTIFIED_MILLI: int = 20
const FIELD_HIVE_OWNER_SLOT: int = 21
const FIELD_HIVE_OWNER_GENERATION: int = 22
const FIELD_HIVE_SERVICE_DAY: int = 23
const FIELD_HIVE_JOB_SLOT: int = 24
const FIELD_HIVE_JOB_GENERATION: int = 25
const FIELD_HIVE_FEED_DEMAND_MILLI: int = 26
const FIELD_HIVE_STATUS: int = 27
const FIELD_HIVE_BLOCKER: int = 28
const FIELD_DIRTY_ROWS: int = 29
const FIELD_DIRTY_COUNT: int = 30
const FIELD_DIRTY_ZONE_ROWS: int = 31
const FIELD_DIRTY_ZONE_COUNT: int = 32
const FIELD_DIRTY_HIVE_ROWS: int = 33
const FIELD_DIRTY_HIVE_COUNT: int = 34
const FIELD_COUNT: int = 35

## SAVE-R09 canonical type codes: 0 = u8, 2 = i32, 4 = i64.
const CANONICAL_TYPE_U8: int = 0
const CANONICAL_TYPE_I32: int = 2
const CANONICAL_TYPE_I64: int = 4

## Transcribed from the registry artifact's declared ordinals. NOT GDScript declaration order.
const FIELD_KEYS: Array[StringName] = [
	&"_owner_slot", &"_owner_generation", &"_service_day", &"_job_slot", &"_job_generation",
	&"_serviced_day", &"_status", &"_requires_water", &"_field_cycle", &"_requested_crop",
	&"_gate_reason", &"_cycle_cursor", &"_completed_cycle", &"_demand_enabled",
	&"_demand_owner_slot", &"_demand_owner_generation", &"_demand_status", &"_demand_blocker",
	&"_demand_job_slot", &"_demand_job_generation", &"_demand_quantified_milli",
	&"_hive_owner_slot", &"_hive_owner_generation", &"_hive_service_day", &"_hive_job_slot",
	&"_hive_job_generation", &"_hive_feed_demand_milli", &"_hive_status", &"_hive_blocker",
	&"_dirty_rows", &"_dirty_count", &"_dirty_zone_rows", &"_dirty_zone_count",
	&"_dirty_hive_rows", &"_dirty_hive_count",
]

## Canonical type code per ordinal, from the artifact's `type_code`.
const FIELD_TYPES: Array[int] = [
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_U8,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_U8, CANONICAL_TYPE_U8, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I64, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I64, CANONICAL_TYPE_U8,
	CANONICAL_TYPE_U8,
	CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32, CANONICAL_TYPE_I32,
]

## Element width in bytes per ordinal. Equals the type code's width; `field_width()` recomputes it.
const FIELD_WIDTHS: Array[int] = [
	4, 4, 4, 4, 4, 4, 1, 1, 4, 4, 1, 4, 4, 1, 4, 4, 1, 1, 4, 4, 8, 4, 4, 4, 4, 4, 8, 1, 1,
	4, 4, 4, 4, 4, 4,
]

## Row count per ordinal, from the owning schema's five table constants. NEVER from column zero.
const FIELD_EXTENTS: Array[int] = [
	SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS,
	SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS, SERVICE_ROWS,
	OWNER_ROWS, OWNER_ROWS,
	ZONE_ROWS, ZONE_ROWS, ZONE_ROWS,
	DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS, DEMAND_ROWS,
	HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS, HIVE_ROWS,
	OWNER_ROWS, 1, ZONE_ROWS, 1, HIVE_ROWS, 1,
]

## SAVE-LAYOUT-R01's DECLARED canonical unused value per ordinal: "Use zero only where the owner
## declares zero". `job_planner.gd::clear()` declares every one of these; the six slot columns and
## `_requested_crop` are -1, and every null reference generation is 0.
const FIELD_UNUSED: Array[int] = [
	NULL_SLOT, NULL_GENERATION, NO_DAY, NULL_SLOT, NULL_GENERATION, NO_DAY, STATUS_FREE, 0,
	NO_CYCLE, NO_CROP, 0, NO_CYCLE, NO_CYCLE, 0, NULL_SLOT, NULL_GENERATION, STATUS_FREE, 0,
	NULL_SLOT, NULL_GENERATION, 0, NULL_SLOT, NULL_GENERATION, NO_DAY, NULL_SLOT,
	NULL_GENERATION, 0, STATUS_FREE, 0,
	0, 0, 0, 0, 0, 0,
]

## Index of each field within its own type group, in ordinal order. `Record._init()` produces this
## layout by construction and `storage_index_of()` recomputes it, so the table cannot drift.
const FIELD_STORAGE: Array[int] = [
	0, 1, 2, 3, 4, 5, 0, 1, 6, 7, 2, 8, 9, 3, 10, 11, 4, 5, 12, 13, 0, 14, 15, 16, 17, 18, 1, 6, 7,
	19, 20, 21, 22, 23, 24,
]

## Fields whose value must be a DIRECTORY slot: -1, or in `[0, DIRECTORY_CAPACITY)`.
const SLOT_FIELDS: Array[int] = [
	FIELD_OWNER_SLOT, FIELD_JOB_SLOT, FIELD_DEMAND_OWNER_SLOT, FIELD_DEMAND_JOB_SLOT,
	FIELD_HIVE_OWNER_SLOT, FIELD_HIVE_JOB_SLOT,
]

## Fields that can never hold a negative value. This is the int32 sign trap's guard: the six
## DIRECTORY generations, the three day columns and the three cycle columns.
const NON_NEGATIVE_FIELDS: Array[int] = [
	FIELD_OWNER_GENERATION, FIELD_SERVICE_DAY, FIELD_JOB_GENERATION, FIELD_SERVICED_DAY,
	FIELD_FIELD_CYCLE, FIELD_CYCLE_CURSOR, FIELD_COMPLETED_CYCLE,
	FIELD_DEMAND_OWNER_GENERATION, FIELD_DEMAND_JOB_GENERATION, FIELD_HIVE_OWNER_GENERATION,
	FIELD_HIVE_SERVICE_DAY, FIELD_HIVE_JOB_GENERATION,
	FIELD_DIRTY_ROWS, FIELD_DIRTY_COUNT, FIELD_DIRTY_ZONE_ROWS, FIELD_DIRTY_ZONE_COUNT,
	FIELD_DIRTY_HIVE_ROWS, FIELD_DIRTY_HIVE_COUNT,
]

## The i64 quantity columns, both of which are milli-unit amounts and neither of which may be
## negative: `quantity_milli` is the GDD's unit and a negative claim is not a smaller claim.
const QUANTITY_FIELDS: Array[int] = [
	FIELD_DEMAND_QUANTIFIED_MILLI, FIELD_HIVE_FEED_DEMAND_MILLI,
]

## What `job_planner.gd::service_row_is_clear()` requires of a FREE service row, field by field.
## `_serviced_day` is deliberately absent: `_retire_row()` keeps it, because it is the completion
## history "the ruling forbids discarding".
const SERVICE_CLEAR_FIELDS: Array[int] = [
	FIELD_OWNER_SLOT, FIELD_OWNER_GENERATION, FIELD_SERVICE_DAY, FIELD_JOB_SLOT,
	FIELD_JOB_GENERATION, FIELD_REQUIRES_WATER, FIELD_FIELD_CYCLE, FIELD_REQUESTED_CROP,
	FIELD_GATE_REASON,
]

## What `demand_row_is_clear()` requires of a FREE demand row. `_demand_blocker` is deliberately
## absent: it is "the row's retained REASON, written by the gate sweep onto a free row".
const DEMAND_CLEAR_FIELDS: Array[int] = [
	FIELD_DEMAND_JOB_SLOT, FIELD_DEMAND_JOB_GENERATION, FIELD_DEMAND_QUANTIFIED_MILLI,
]

## What `hive_service_row_is_clear()` requires of a FREE hive row. The blocker byte AND the winter
## feed demand are deliberately absent, for the reason that predicate states.
const HIVE_CLEAR_FIELDS: Array[int] = [
	FIELD_HIVE_OWNER_SLOT, FIELD_HIVE_OWNER_GENERATION, FIELD_HIVE_SERVICE_DAY,
	FIELD_HIVE_JOB_SLOT, FIELD_HIVE_JOB_GENERATION,
]

# --- byte arithmetic -------------------------------------------------------------------------------

const OFFSET_STORE_COUNT: int = 0
const OFFSET_OWNER_KEY_LENGTH: int = 4
const OFFSET_OWNER_KEY: int = 8
const OFFSET_OWNER_SCHEMA_VERSION: int = 19
const OFFSET_PRIMARY_COUNT: int = 23
const OFFSET_PAYLOAD_BYTE_LENGTH: int = 31
const FRAMING_BYTES: int = 39

## Each field's payload is `element_count:u64` then its tightly packed LE values.
const ELEMENT_COUNT_BYTES: int = 8

## 35 * 8 element counts + the summed column widths. Stated as a constant because a const cannot
## hold a loop; `payload_bytes()` recomputes it from FIELD_WIDTHS and FIELD_EXTENTS and the suite
## asserts the two agree, so a changed extent cannot leave this literal behind.
const CANONICAL_VALUE_BYTES: int = 383884
const PAYLOAD_BYTES: int = 384164
const SECTION_BYTES: int = 384203

## `save_header.gd`'s endian sentinel, reused as the little-endian probe constant. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_BYTE_ORDER: StringName = &"SAVE_JOB_BYTE_ORDER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_JOB_NEGATIVE_OFFSET"
const REFUSE_SECTION_SCHEMA_VERSION: StringName = &"SAVE_JOB_SECTION_SCHEMA_VERSION"
const REFUSE_DIRTY_COUNT: StringName = &"SAVE_JOB_DIRTY_COUNT"
const REFUSE_DIRTY_INDEX: StringName = &"SAVE_JOB_DIRTY_INDEX"
const REFUSE_DIRTY_DUPLICATE: StringName = &"SAVE_JOB_DIRTY_DUPLICATE"
const REFUSE_DIRTY_TAIL: StringName = &"SAVE_JOB_DIRTY_TAIL"
const REFUSE_TRUNCATED: StringName = &"SAVE_JOB_TRUNCATED"
const REFUSE_LENGTH: StringName = &"SAVE_JOB_LENGTH"
const REFUSE_RECORD_SHAPE: StringName = &"SAVE_JOB_RECORD_SHAPE"
const REFUSE_STORE_COUNT: StringName = &"SAVE_JOB_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_JOB_OWNER_KEY"
const REFUSE_OWNER_SCHEMA_VERSION: StringName = &"SAVE_JOB_OWNER_SCHEMA_VERSION"
## SAVE-C3-R01 retired SAVE_JOB_PRIMARY_COUNT_UNRULED: the count is ruled, so an unruled-count
## refusal can no longer be raised. The old store-API refusal is retained for compatibility.
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_JOB_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_JOB_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_JOB_ELEMENT_COUNT"
const REFUSE_FIELD_ORDINAL: StringName = &"SAVE_JOB_FIELD_ORDINAL"
const REFUSE_STATUS_DOMAIN: StringName = &"SAVE_JOB_STATUS_DOMAIN"
const REFUSE_REASON_DOMAIN: StringName = &"SAVE_JOB_REASON_DOMAIN"
const REFUSE_FLAG_DOMAIN: StringName = &"SAVE_JOB_FLAG_DOMAIN"
const REFUSE_SLOT_DOMAIN: StringName = &"SAVE_JOB_SLOT_DOMAIN"
const REFUSE_NEGATIVE_VALUE: StringName = &"SAVE_JOB_NEGATIVE_VALUE"
const REFUSE_CROP_DOMAIN: StringName = &"SAVE_JOB_CROP_DOMAIN"
const REFUSE_CYCLE_RANGE: StringName = &"SAVE_JOB_CYCLE_RANGE"
const REFUSE_ROW_NOT_CLEAR: StringName = &"SAVE_JOB_ROW_NOT_CLEAR"
const REFUSE_OPERATION_MISMATCH: StringName = &"SAVE_JOB_OPERATION_MISMATCH"
const REFUSE_REFERENCE_SHAPE: StringName = &"SAVE_JOB_REFERENCE_SHAPE"
const REFUSE_JOB_BINDING: StringName = &"SAVE_JOB_JOB_BINDING"
const REFUSE_OWNER_MISSING: StringName = &"SAVE_JOB_OWNER_MISSING"
const REFUSE_CYCLE_DISAGREES: StringName = &"SAVE_JOB_CYCLE_DISAGREES"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_JOB_ENCODE_FAILED"
const REFUSE_STORE_NO_COLUMN_API: StringName = &"SAVE_JOB_STORE_NO_COLUMN_API"


class Record:
	"""One decoded section8:35 fields held in typed groups, addressed by wire ordinal.

	The appended counts are extent-1 i32 columns. Dirty arrays retain exact order and zero tails.
	Record allocation is cold-path scratch; FIELD_STORAGE maps each ordinal to its type group.
	"""
	var u8_columns: Array[PackedByteArray] = []
	var i32_columns: Array[PackedInt32Array] = []
	var i64_columns: Array[PackedInt64Array] = []

	func _init() -> void:
		"""Allocate all 35 columns at their declared extents, then fill the canonical empty state."""
		for field: int in FIELD_COUNT:
			if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
				var bytes: PackedByteArray = PackedByteArray()
				bytes.resize(FIELD_EXTENTS[field])
				u8_columns.append(bytes)
			elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
				var words: PackedInt32Array = PackedInt32Array()
				words.resize(FIELD_EXTENTS[field])
				i32_columns.append(words)
			else:
				var longs: PackedInt64Array = PackedInt64Array()
				longs.resize(FIELD_EXTENTS[field])
				i64_columns.append(longs)
		clear()

	func clear() -> void:
		"""Refill every column with SAVE-LAYOUT-R01's DECLARED canonical unused value.

		This is `job_planner.gd::clear()`'s state exactly: every slot -1, every generation 0, every
		day and cycle 0, every status FREE and every requested crop NO_CROP.

		Each column is read out, filled and written back explicitly. This does not promise
		buffer independence: callers needing a snapshot must duplicate the columns.
		"""
		for field: int in FIELD_COUNT:
			var index: int = FIELD_STORAGE[field]
			if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
				var bytes: PackedByteArray = u8_columns[index]
				bytes.fill(FIELD_UNUSED[field])
				u8_columns[index] = bytes
			elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
				var words: PackedInt32Array = i32_columns[index]
				words.fill(FIELD_UNUSED[field])
				i32_columns[index] = words
			else:
				var longs: PackedInt64Array = i64_columns[index]
				longs.fill(FIELD_UNUSED[field])
				i64_columns[index] = longs

	func copy_from(other: Record) -> void:
		"""Overwrite all 35 columns from `other`. C++ copies, one per column, no element loop."""
		for index: int in other.u8_columns.size():
			u8_columns[index] = other.u8_columns[index].duplicate()
		for index: int in other.i32_columns.size():
			i32_columns[index] = other.i32_columns[index].duplicate()
		for index: int in other.i64_columns.size():
			i64_columns[index] = other.i64_columns[index].duplicate()

	func equals(other: Record) -> bool:
		"""True when all 35 columns are byte-identical. Proves a refusal changed nothing."""
		return u8_columns == other.u8_columns and i32_columns == other.i32_columns \
			and i64_columns == other.i64_columns

	func u8_column(field: int) -> PackedByteArray:
		"""One u8 column by ordinal. Refuses nothing: an ordinal of the wrong type is a code bug."""
		return u8_columns[FIELD_STORAGE[field]]

	func i32_column(field: int) -> PackedInt32Array:
		"""One i32 column by ordinal."""
		return i32_columns[FIELD_STORAGE[field]]

	func i64_column(field: int) -> PackedInt64Array:
		"""One i64 column by ordinal."""
		return i64_columns[FIELD_STORAGE[field]]

	func value_of(field: int, row: int) -> int:
		"""One value of one column, whatever its width. For validators that walk mixed tables."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]][row]
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]][row]
		return i64_columns[FIELD_STORAGE[field]][row]

	func set_value(field: int, row: int, value: int) -> void:
		"""Write one value of one column, whatever its width. Read out, write, store back.

		The column is written back explicitly. Snapshot isolation is provided by duplication,
		not by this setter.
		"""
		var index: int = FIELD_STORAGE[field]
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			var bytes: PackedByteArray = u8_columns[index]
			bytes[row] = value
			u8_columns[index] = bytes
		elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			var words: PackedInt32Array = i32_columns[index]
			words[row] = value
			i32_columns[index] = words
		else:
			var longs: PackedInt64Array = i64_columns[index]
			longs[row] = value
			i64_columns[index] = longs

	func assign_column(field: int, raw: PackedByteArray) -> void:
		"""Reinterpret one column's little-endian bytes into its packed array. C++, no loop."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			u8_columns[FIELD_STORAGE[field]] = raw
		elif FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			i32_columns[FIELD_STORAGE[field]] = raw.to_int32_array()
		else:
			i64_columns[FIELD_STORAGE[field]] = raw.to_int64_array()

	func column_size(field: int) -> int:
		"""The number of values one column currently holds. `_shape_refusal()`'s input."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]].size()
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]].size()
		return i64_columns[FIELD_STORAGE[field]].size()

	func column_bytes(field: int) -> PackedByteArray:
		"""One column's little-endian wire bytes. C++ conversions, never a per-element loop."""
		if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
			return u8_columns[FIELD_STORAGE[field]].duplicate()
		if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
			return i32_columns[FIELD_STORAGE[field]].to_byte_array()
		return i64_columns[FIELD_STORAGE[field]].to_byte_array()


# --- validation -------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 8 rule: shape, then column domains, then each table's own invariants."""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	var domain: SaveHeader.Refusal = _domain_refusal(record)
	if not domain.is_ok():
		return domain
	var service: SaveHeader.Refusal = _service_table_refusal(record)
	if not service.is_ok():
		return service
	var demand: SaveHeader.Refusal = _demand_table_refusal(record)
	if not demand.is_ok():
		return demand
	var hive: SaveHeader.Refusal = _hive_table_refusal(record)
	if not hive.is_ok():
		return hive
	return _dirty_lists_refusal(record)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column must hold exactly its OWN declared extent before anything indexes into it.

	This is where an extent guessed from the first column dies: a `_demand_enabled` column holding
	8192 values instead of the zone table's 128 is refused here, not silently walked.
	"""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE, "no planner record")
	if record.u8_columns.size() != 8 or record.i32_columns.size() != 25 \
			or record.i64_columns.size() != 2:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE, "planner groups require8/25/2 columns")
	for field: int in FIELD_COUNT:
		if record.column_size(field) != FIELD_EXTENTS[field]:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"column %s holds %d values, not its declared %d"
					% [FIELD_KEYS[field], record.column_size(field), FIELD_EXTENTS[field]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column's own value domain, independent of any other column."""
	var bytes_invalid: SaveHeader.Refusal = _byte_domain_refusal(record)
	if not bytes_invalid.is_ok():
		return bytes_invalid
	var slots: SaveHeader.Refusal = _slot_domain_refusal(record)
	if not slots.is_ok():
		return slots
	var signs: SaveHeader.Refusal = _non_negative_refusal(record)
	if not signs.is_ok():
		return signs
	var crop: SaveHeader.Refusal = _i32_range_refusal(
		record.i32_column(FIELD_REQUESTED_CROP), NO_CROP, CROP_COUNT - 1,
		FIELD_REQUESTED_CROP, REFUSE_CROP_DOMAIN)
	if not crop.is_ok():
		return crop
	return _quantity_refusal(record)


static func _byte_domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""The eight u8 columns are bounded enums or flags, each by its OWN owning domain count."""
	var fields: Array[int] = [FIELD_STATUS, FIELD_DEMAND_STATUS, FIELD_HIVE_STATUS,
		FIELD_GATE_REASON, FIELD_DEMAND_BLOCKER, FIELD_HIVE_BLOCKER, FIELD_REQUIRES_WATER,
		FIELD_DEMAND_ENABLED]
	var limits: Array[int] = [STATUS_COUNT, STATUS_COUNT, STATUS_COUNT, REASON_COUNT,
		BLOCKER_COUNT, HIVE_BLOCKER_COUNT, 2, 2]
	var codes: Array[StringName] = [REFUSE_STATUS_DOMAIN, REFUSE_STATUS_DOMAIN,
		REFUSE_STATUS_DOMAIN, REFUSE_REASON_DOMAIN, REFUSE_REASON_DOMAIN, REFUSE_REASON_DOMAIN,
		REFUSE_FLAG_DOMAIN, REFUSE_FLAG_DOMAIN]
	for index: int in fields.size():
		var invalid: SaveHeader.Refusal = _byte_range_refusal(record.u8_column(fields[index]),
			limits[index], fields[index], codes[index])
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _byte_range_refusal(column: PackedByteArray, limit: int, field: int,
		code: StringName) -> SaveHeader.Refusal:
	"""Refuse unless every byte of `column` is below `limit`. `count()` is one C++ pass per value."""
	var counted: int = 0
	for value: int in limit:
		counted += column.count(value)
	if counted != column.size():
		return SaveHeader.Refusal.new(code,
			"%s holds %d of %d bytes outside [0, %d)"
				% [FIELD_KEYS[field], column.size() - counted, column.size(), limit])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _slot_domain_refusal(record: Record) -> SaveHeader.Refusal:
	"""The six DIRECTORY slot columns hold -1 or a slot inside the directory's capacity.

	DIRECTORY, not typed row: these are the `x` of an `EntityRef`, and a value of 4096 would be a
	plausible farm-plot row and an implausible directory slot.
	"""
	for field: int in SLOT_FIELDS:
		var invalid: SaveHeader.Refusal = _i32_range_refusal(record.i32_column(field), NULL_SLOT,
			DIRECTORY_CAPACITY - 1, field, REFUSE_SLOT_DOMAIN)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _non_negative_refusal(record: Record) -> SaveHeader.Refusal:
	"""No generation, day or cycle is negative. THE INT32 SIGN TRAP'S GUARD.

	Bytes `00 00 00 80` read as int32 are -2147483648, which no generation, absolute day or field
	cycle can ever be; read as u32 they are a plausible 2147483648. They are read signed and
	refused here. The upper bound needs no separate check: `MAX_FIELD_CYCLE` is 2147483647, which
	is also the largest value an i32 column can hold.
	"""
	for field: int in NON_NEGATIVE_FIELDS:
		var invalid: SaveHeader.Refusal = _i32_range_refusal(record.i32_column(field), 0,
			MAX_INT32, field, REFUSE_NEGATIVE_VALUE)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _quantity_refusal(record: Record) -> SaveHeader.Refusal:
	"""Neither milli-unit quantity column may be negative: a negative claim is not a small one."""
	for field: int in QUANTITY_FIELDS:
		var sorted: PackedInt64Array = record.i64_column(field).duplicate()
		sorted.sort()
		if sorted[0] < 0:
			return SaveHeader.Refusal.new(REFUSE_NEGATIVE_VALUE,
				"%s holds %d milli-units; quantities are never negative"
					% [FIELD_KEYS[field], sorted[0]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _i32_range_refusal(column: PackedInt32Array, minimum: int, maximum: int, field: int,
		code: StringName) -> SaveHeader.Refusal:
	"""Refuse unless every value of one i32 column lies in `[minimum, maximum]`.

	Sorting a copy is one C++ call and only the two endpoints matter, so this costs one sort
	instead of a GDScript walk over as many as 8192 values.
	"""
	var sorted: PackedInt32Array = column.duplicate()
	sorted.sort()
	if sorted[0] < minimum:
		return SaveHeader.Refusal.new(code,
			"%s holds %d, below the declared minimum %d" % [FIELD_KEYS[field], sorted[0], minimum])
	if sorted[sorted.size() - 1] > maximum:
		return SaveHeader.Refusal.new(code,
			"%s holds %d, above the declared maximum %d"
				% [FIELD_KEYS[field], sorted[sorted.size() - 1], maximum])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- the pending-service table (8192 rows) and its per-plot cycle history (4096) ---------------------

static func _service_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 8192-row service table and the 4096-row cycle history carry between them."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_STATUS,
		SERVICE_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var tend: SaveHeader.Refusal = _tend_row_refusal(record)
	if not tend.is_ok():
		return tend
	var days: SaveHeader.Refusal = _sow_day_refusal(record)
	if not days.is_ok():
		return days
	var cycles: SaveHeader.Refusal = _sow_cycle_refusal(record)
	if not cycles.is_ok():
		return cycles
	var references: SaveHeader.Refusal = _service_reference_refusal(record)
	if not references.is_ok():
		return references
	return _cycle_history_refusal(record)


static func _tend_row_refusal(record: Record) -> SaveHeader.Refusal:
	"""A TEND row carries no sowing state, and STATUS_REQUESTED is R06-JOB-004's, never a tend's.

	`_write_requested_row()` writes the cycle, the crop and the REQUESTED status only onto the SOW
	row of an owner, and `_reconcile_sow()` is the only writer of the gate reason. A tend row
	carrying a field cycle is a row whose two operations have been transposed.
	"""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var cycle: PackedInt32Array = record.i32_column(FIELD_FIELD_CYCLE)
	var crop: PackedInt32Array = record.i32_column(FIELD_REQUESTED_CROP)
	var reason: PackedByteArray = record.u8_column(FIELD_GATE_REASON)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_TEND
		if status[row] == STATUS_REQUESTED:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds STATUS_REQUESTED, which only a sowing row takes" % row)
		if cycle[row] != NO_CYCLE or crop[row] != NO_CROP:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds field cycle %d and crop %d" % [row, cycle[row], crop[row]])
		if reason[row] != 0:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"tend row %d holds sowing gate reason %d" % [row, reason[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _sow_day_refusal(record: Record) -> SaveHeader.Refusal:
	"""A SOW row carries no day: sowing is not a daily service and midnight never settles one.

	`_write_requested_row()` writes NO_DAY explicitly, and both writers of `_serviced_day`
	(`_record_completion()` and `record_service_completed()`) refuse a non-daily operation. A SOW
	row holding a day would be read by a once-per-day test that sowing does not take part in.
	"""
	var service_day: PackedInt32Array = record.i32_column(FIELD_SERVICE_DAY)
	var serviced_day: PackedInt32Array = record.i32_column(FIELD_SERVICED_DAY)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_SOW
		if service_day[row] != NO_DAY or serviced_day[row] != NO_DAY:
			return SaveHeader.Refusal.new(REFUSE_OPERATION_MISMATCH,
				"sowing row %d holds service day %d and serviced day %d"
					% [row, service_day[row], serviced_day[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _sow_cycle_refusal(record: Record) -> SaveHeader.Refusal:
	"""An outstanding sowing request names the cycle its owner's cursor most recently allocated.

	`_write_requested_row()` sets `_cycle_cursor[owner]` to the cycle it writes, and
	`_outstanding_request_code()` refuses a second confirm while the row is not FREE, so the cursor
	can only advance while the row is free. A non-free row naming an older cycle is a row whose
	cycle was reused -- exactly what "never reuse a field cycle" forbids.
	"""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var cycle: PackedInt32Array = record.i32_column(FIELD_FIELD_CYCLE)
	var crop: PackedInt32Array = record.i32_column(FIELD_REQUESTED_CROP)
	var cursor: PackedInt32Array = record.i32_column(FIELD_CYCLE_CURSOR)
	for owner: int in OWNER_ROWS:
		var row: int = owner * OPERATION_COUNT + OPERATION_FARM_SOW
		if status[row] == STATUS_FREE:
			continue
		if cycle[row] < FIRST_CYCLE or cycle[row] != cursor[owner]:
			return SaveHeader.Refusal.new(REFUSE_CYCLE_DISAGREES,
				"sowing row %d holds cycle %d, its owner's cursor %d"
					% [row, cycle[row], cursor[owner]])
		if crop[row] < 0 or crop[row] >= CROP_COUNT:
			return SaveHeader.Refusal.new(REFUSE_CROP_DOMAIN,
				"outstanding sowing row %d requests crop %d" % [row, crop[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _cycle_history_refusal(record: Record) -> SaveHeader.Refusal:
	"""No plot has completed a cycle its cursor never allocated.

	`_close_sowing_cycle()` copies the row's `_field_cycle` into `_completed_cycle`, and that cycle
	came from the cursor, so completion can never run ahead of allocation.
	"""
	var cursor: PackedInt32Array = record.i32_column(FIELD_CYCLE_CURSOR)
	var completed: PackedInt32Array = record.i32_column(FIELD_COMPLETED_CYCLE)
	for owner: int in OWNER_ROWS:
		if completed[owner] > cursor[owner]:
			return SaveHeader.Refusal.new(REFUSE_CYCLE_RANGE,
				"plot %d completed cycle %d but allocated only %d"
					% [owner, completed[owner], cursor[owner]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _service_reference_refusal(record: Record) -> SaveHeader.Refusal:
	"""Both DIRECTORY references on every service row: shape, presence and Job binding."""
	var status: PackedByteArray = record.u8_column(FIELD_STATUS)
	var owner: SaveHeader.Refusal = _owner_reference_refusal(record, status, FIELD_OWNER_SLOT,
		FIELD_OWNER_GENERATION)
	if not owner.is_ok():
		return owner
	return _job_reference_refusal(record, status, FIELD_JOB_SLOT, FIELD_JOB_GENERATION)


# --- the forage demand tables (128 designations, 640 rows) ------------------------------------------

static func _demand_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 640-row demand table and the 128-row enablement table carry."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_DEMAND_STATUS,
		DEMAND_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var status: PackedByteArray = record.u8_column(FIELD_DEMAND_STATUS)
	var jobs: SaveHeader.Refusal = _job_reference_refusal(record, status, FIELD_DEMAND_JOB_SLOT,
		FIELD_DEMAND_JOB_GENERATION)
	if not jobs.is_ok():
		return jobs
	var requested: SaveHeader.Refusal = _no_requested_status_refusal(status, FIELD_DEMAND_STATUS)
	if not requested.is_ok():
		return requested
	return _zone_reference_refusal(record)


static func _zone_reference_refusal(record: Record) -> SaveHeader.Refusal:
	"""An enabled designation names the zone `EntityRef` its enablement was recorded against.

	`_write_enabled_demand()` stores both halves, and `_clear_enabled_demand()` keeps them while
	any of the zone's five rows still holds a record. The reverse implication is deliberately NOT
	asserted: a disabled zone may legitimately retain its owner reference.
	"""
	var enabled: PackedByteArray = record.u8_column(FIELD_DEMAND_ENABLED)
	var slot: PackedInt32Array = record.i32_column(FIELD_DEMAND_OWNER_SLOT)
	var generation: PackedInt32Array = record.i32_column(FIELD_DEMAND_OWNER_GENERATION)
	for zone: int in ZONE_ROWS:
		if not _pair_is_shaped(slot[zone], generation[zone]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"zone %d holds designation reference (%d, %d)"
					% [zone, slot[zone], generation[zone]])
		if enabled[zone] == 1 and slot[zone] == NULL_SLOT:
			return SaveHeader.Refusal.new(REFUSE_OWNER_MISSING,
				"zone %d has demand enabled with no designation reference" % zone)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- the hive service table (1024 rows) --------------------------------------------------------------

static func _hive_table_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every rule the 1024-row hive service table carries."""
	var clear: SaveHeader.Refusal = _clear_table_refusal(record, FIELD_HIVE_STATUS,
		HIVE_CLEAR_FIELDS)
	if not clear.is_ok():
		return clear
	var status: PackedByteArray = record.u8_column(FIELD_HIVE_STATUS)
	var owner: SaveHeader.Refusal = _owner_reference_refusal(record, status, FIELD_HIVE_OWNER_SLOT,
		FIELD_HIVE_OWNER_GENERATION)
	if not owner.is_ok():
		return owner
	var jobs: SaveHeader.Refusal = _job_reference_refusal(record, status, FIELD_HIVE_JOB_SLOT,
		FIELD_HIVE_JOB_GENERATION)
	if not jobs.is_ok():
		return jobs
	return _no_requested_status_refusal(status, FIELD_HIVE_STATUS)


# --- shared row rules ---------------------------------------------------------------------------------

static func _clear_table_refusal(record: Record, status_field: int,
		clear_fields: Array[int]) -> SaveHeader.Refusal:
	"""Every FREE row of one table holds its declared unused value in every hygiene field.

	`job_planner.gd` publishes this predicate three times -- `service_row_is_clear()`,
	`demand_row_is_clear()`, `hive_service_row_is_clear()` -- for one reason: "a retired row that
	kept a field cycle, an owner reference or a gate reason would hand the row's next occupant
	someone else's identity". The fields each of them deliberately EXCLUDES (the durable
	`_serviced_day`, the retained blocker bytes, the winter feed demand) are excluded here too.
	"""
	var status: PackedByteArray = record.u8_column(status_field)
	for field: int in clear_fields:
		var invalid: SaveHeader.Refusal = _clear_column_refusal(record, status, field)
		if not invalid.is_ok():
			return invalid
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_column_refusal(record: Record, status: PackedByteArray,
		field: int) -> SaveHeader.Refusal:
	"""Route one hygiene column to the loop for its own width."""
	var unused: int = FIELD_UNUSED[field]
	if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
		return _clear_u8_refusal(record.u8_column(field), status, unused, field)
	if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
		return _clear_i32_refusal(record.i32_column(field), status, unused, field)
	return _clear_i64_refusal(record.i64_column(field), status, unused, field)


static func _clear_u8_refusal(column: PackedByteArray, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's u8 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_i32_refusal(column: PackedInt32Array, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's i32 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _clear_i64_refusal(column: PackedInt64Array, status: PackedByteArray, unused: int,
		field: int) -> SaveHeader.Refusal:
	"""Refuse when a FREE row's i64 hygiene column holds anything but its declared unused value."""
	for row: int in status.size():
		if status[row] == STATUS_FREE and column[row] != unused:
			return SaveHeader.Refusal.new(REFUSE_ROW_NOT_CLEAR,
				"free row %d holds %s = %d, not %d" % [row, FIELD_KEYS[field], column[row], unused])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _owner_reference_refusal(record: Record, status: PackedByteArray, slot_field: int,
		generation_field: int) -> SaveHeader.Refusal:
	"""A row that is not FREE names the live owner it was written against, in both halves.

	Every writer of a used row stores the owner's full `EntityRef` -- `_write_pending_row()`,
	`_retain_unmet_demand()`, `_write_requested_row()`, `_write_pending_hive_row()` and
	`_retain_unmet_hive_demand()` all call `ref_of()` after the owner was found present -- because
	"a reused typed row can be republished under a different slot carrying the SAME generation
	number", so half a reference is worse than none.
	"""
	var slot: PackedInt32Array = record.i32_column(slot_field)
	var generation: PackedInt32Array = record.i32_column(generation_field)
	for row: int in status.size():
		if not _pair_is_shaped(slot[row], generation[row]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"row %d holds %s reference (%d, %d)"
					% [row, FIELD_KEYS[slot_field], slot[row], generation[row]])
		if status[row] != STATUS_FREE and slot[row] == NULL_SLOT:
			return SaveHeader.Refusal.new(REFUSE_OWNER_MISSING,
				"row %d holds status %d with no owner reference" % [row, status[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _job_reference_refusal(record: Record, status: PackedByteArray, slot_field: int,
		generation_field: int) -> SaveHeader.Refusal:
	"""Exactly the PENDING rows carry a Job. Every other status carries the null reference.

	PENDING is the only status any writer pairs with a created Job; `_retain_unmet_demand()` and
	`_retain_unmet_demand_row()` null the pair explicitly, and `_write_requested_row()` opens a
	cycle with no Job at all. A PENDING row with no Job is work nothing records; a retired row
	still holding one is a Job nothing will ever cancel.
	"""
	var slot: PackedInt32Array = record.i32_column(slot_field)
	var generation: PackedInt32Array = record.i32_column(generation_field)
	for row: int in status.size():
		if not _pair_is_shaped(slot[row], generation[row]):
			return SaveHeader.Refusal.new(REFUSE_REFERENCE_SHAPE,
				"row %d holds %s reference (%d, %d)"
					% [row, FIELD_KEYS[slot_field], slot[row], generation[row]])
		if (status[row] == STATUS_PENDING) != (slot[row] != NULL_SLOT):
			return SaveHeader.Refusal.new(REFUSE_JOB_BINDING,
				"row %d holds status %d with %s = %d"
					% [row, status[row], FIELD_KEYS[slot_field], slot[row]])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no_requested_status_refusal(status: PackedByteArray,
		field: int) -> SaveHeader.Refusal:
	"""STATUS_REQUESTED belongs to R06-JOB-004's sowing rows and to no other table.

	The demand and hive tables' writers use FREE, PENDING and UNMET only; a REQUESTED byte in
	either would be read by `_settle_existing_demand()` as a status it has no branch for.
	"""
	if status.count(STATUS_REQUESTED) != 0:
		return SaveHeader.Refusal.new(REFUSE_STATUS_DOMAIN,
			"%s holds %d STATUS_REQUESTED bytes, which only a sowing row takes"
				% [FIELD_KEYS[field], status.count(STATUS_REQUESTED)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _pair_is_shaped(slot: int, generation: int) -> bool:
	"""True when a DIRECTORY reference is either the null pair (-1, 0) or a live (slot, >= 1).

	The domain pass has already bounded the slot to `[-1, DIRECTORY_CAPACITY)` and the generation
	to `[0, 2147483647]`, so agreement between the two halves is all that is left: a slot of -1
	with generation 4, or a real slot with generation 0, is a reference that validates against
	nothing and resolves to something.
	"""
	return (slot == NULL_SLOT) == (generation == NULL_GENERATION)


static func _dirty_lists_refusal(record: Record) -> SaveHeader.Refusal:
	"""Validate exact prefixes in farm/zone/hive order, reusing bounded cold-path seen bytes."""
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(maxi(OWNER_ROWS, maxi(ZONE_ROWS, HIVE_ROWS)))
	for field: int in [FIELD_DIRTY_ROWS, FIELD_DIRTY_ZONE_ROWS, FIELD_DIRTY_HIVE_ROWS]:
		seen.fill(0)
		var rows: PackedInt32Array = record.i32_column(field)
		var count: int = record.value_of(field + 1, 0)
		if count > rows.size():
			return SaveHeader.Refusal.new(REFUSE_DIRTY_COUNT, "%s count exceeds capacity" % FIELD_KEYS[field])
		for index: int in count:
			var row: int = rows[index]
			if row >= rows.size():
				return SaveHeader.Refusal.new(REFUSE_DIRTY_INDEX, "%s prefix row outside capacity" % FIELD_KEYS[field])
			if seen[row] != 0:
				return SaveHeader.Refusal.new(REFUSE_DIRTY_DUPLICATE, "%s repeats a prefix row" % FIELD_KEYS[field])
			seen[row] = 1
		for index: int in range(count, rows.size()):
			if rows[index] != 0:
				return SaveHeader.Refusal.new(REFUSE_DIRTY_TAIL, "%s unused tail is nonzero" % FIELD_KEYS[field])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Validate a caller output's groups/extents without inspecting prior values."""
	return _shape_refusal(record)
