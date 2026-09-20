# Immutable codec excerpts

## Lines 190–248
```gdscript
const OWNER_FISHING: int = 0
const OWNER_FORAGE: int = 1
const OWNER_GEAR: int = 2
const OWNER_INVENTORY: int = 3
const OWNER_RESERVATIONS: int = 4
const OWNER_STOCK_AGE: int = 5
const OWNER_COUNT: int = 6
const STORE_COUNT: int = OWNER_COUNT

const OWNER_KEYS: Array[String] = [
	"fishing", "forage", "gear", "inventory", "reservations", "stock_age",
]

## REG-R01's `owner_schema_version` per owner. INV-CANON-R01 takes `inventory` from 2 to **3**
## with the canonicalized unused payload; the other five are still 1. The 3 is READ from
## `inventory.gd`, which declares it beside the projection it describes, rather than restated
## here: two modules naming the version independently is two numbers that can disagree.
const OWNER_SCHEMA_VERSIONS: Array[int] = [
	1, 1, 1, InventoryScript.CANONICAL_OWNER_SCHEMA_VERSION, 1, 1,
]

## The 64-byte descriptor's section schema version. REG-R01's baseline vector gave section 7
## version 2 "for protected provenance"; INV-CANON-R01 moves it to **3** in the same activation
## that takes the `inventory` OWNER to 3. Those are different namespaces and both move here.
## `save_header.gd` carries the number and does not interpret it, so the section owner publishes
## it -- exactly as `save_section_world_runtime.gd` publishes section 1's.
const SECTION_SCHEMA_VERSION: int = 3

## SAVE-LAYOUT-R01 / S2: owner keys are nonempty ASCII, at most 256 bytes.
const OWNER_KEY_MAX_BYTES: int = 256

# --- declared field tables, from REG-R01's ordinals --------------------------------------------

## SAVE-R09 canonical type codes. 0 = u8, 1 = u32, 2 = i32, 4 = i64. There is no code 3 here.
const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_I64: int = 4

## Which declared extent a field's element count comes from. Never inferred from a column length.
const EXT_PRIMARY: int = 0
const EXT_CHILD_0: int = 1
const EXT_SCALAR: int = 2

## No count field governs this ordinal: its element count is its full backing extent.
const NO_COUNT_FIELD: int = -1

const KEYS_FISHING: Array[StringName] = [
	&"_effort_claim_active", &"_effort_claim_expedition_generation",
	&"_effort_claim_habitat_slot", &"_effort_claim_habitat_generation",
	&"_effort_claim_job_slot", &"_effort_claim_job_generation", &"_effort_claim_slot_count",
]
const TYPES_FISHING: Array[int] = [TYPE_U8, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32, TYPE_I32]
const EXTENTS_FISHING: Array[int] = [
	EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY, EXT_PRIMARY,
]
const COUNT_FIELDS_FISHING: Array[int] = [-1, -1, -1, -1, -1, -1, -1]

const KEYS_FORAGE: Array[StringName] = [
```


## Lines 440–538
```gdscript
	"""
	var owner: int = OWNER_FISHING
	var primary_count: int = 0
	var child_extents: PackedInt64Array = PackedInt64Array()
	var u8_columns: Array[PackedByteArray] = []
	var i32_columns: Array[PackedInt32Array] = []
	var i64_columns: Array[PackedInt64Array] = []

	func _init(p_owner: int, p_primary_count: int, p_child_extents: PackedInt64Array) -> void:
		"""Allocate every column of one owner at its declared extents. The only resize here."""
		owner = p_owner
		primary_count = p_primary_count
		child_extents = p_child_extents.duplicate()
		for ordinal: int in SaveSectionInventoriesScript.field_count_of(p_owner):
			_allocate_column(ordinal)

	func _allocate_column(ordinal: int) -> void:
		"""Append one column, sized to its declared backing extent and canonically filled."""
		var length: int = SaveSectionInventoriesScript.backing_extent_of(self, ordinal)
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		var fill: int = SaveSectionInventoriesScript.canonical_fill_of(owner, ordinal)
		if type_code == TYPE_U8:
			var bytes: PackedByteArray = PackedByteArray()
			bytes.resize(length)
			bytes.fill(fill)
			u8_columns.append(bytes)
		elif type_code == TYPE_I32:
			var words: PackedInt32Array = PackedInt32Array()
			words.resize(length)
			words.fill(fill)
			i32_columns.append(words)
		else:
			var longs: PackedInt64Array = PackedInt64Array()
			longs.resize(length)
			longs.fill(fill)
			i64_columns.append(longs)

	func u8_column(ordinal: int) -> PackedByteArray:
		"""The u8 column at `ordinal`. Empty when that ordinal is not a u8 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_U8:
			return PackedByteArray()
		return u8_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i32_column(ordinal: int) -> PackedInt32Array:
		"""The i32 column at `ordinal`. Empty when that ordinal is not an i32 field."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I32:
			return PackedInt32Array()
		return i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func i64_column(ordinal: int) -> PackedInt64Array:
		"""The u32/i64 column at `ordinal`. Empty when that ordinal is neither."""
		var type_code: int = SaveSectionInventoriesScript.field_type_of(owner, ordinal)
		if type_code != TYPE_I64 and type_code != TYPE_U32:
			return PackedInt64Array()
		return i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)]

	func scalar(ordinal: int) -> int:
		"""The single value of a scalar field, or 0 when `ordinal` is not one."""
		if SaveSectionInventoriesScript.field_extent_of(owner, ordinal) != EXT_SCALAR:
			return 0
		var column: PackedInt64Array = i64_column(ordinal)
		if column.is_empty():
			return 0
		return column[0]

	func set_u8_column(ordinal: int, values: PackedByteArray) -> bool:
		"""Replace one u8 column. Refuses a wrong type or a length that is not its extent."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_U8:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		u8_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_i32_column(ordinal: int, values: PackedInt32Array) -> bool:
		"""Replace one i32 column. Refuses a count-governed ordinal: use `set_stack_column()`."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I32:
			return false
		if SaveSectionInventoriesScript.count_field_of(owner, ordinal) != NO_COUNT_FIELD:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		i32_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_i64_column(ordinal: int, values: PackedInt64Array) -> bool:
		"""Replace one i64 column. Refuses a wrong type or a length that is not its extent."""
		if SaveSectionInventoriesScript.field_type_of(owner, ordinal) != TYPE_I64:
			return false
		if values.size() != SaveSectionInventoriesScript.backing_extent_of(self, ordinal):
			return false
		i64_columns[SaveSectionInventoriesScript.storage_index_of(owner, ordinal)] = values.duplicate()
		return true

	func set_scalar(ordinal: int, value: int) -> bool:
		"""Set a scalar field's single value. Refuses a non-scalar ordinal or a negative u32.

		The column is rebuilt and assigned back rather than written through a local: a packed
		array taken out of a typed `Array` is a copy-on-write VALUE, so `column[0] = v` would
```


## Lines 1135–1285
```gdscript
	`save_section_directory.gd::extent_refusal()` is. Section 7's length is not fixed -- six
	owners with runtime capacities -- so the descriptor's declared length is an argument rather
	than a compiled constant, and a load orchestrator can ask before committing to anything.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if byte_length < SECTION_FRAMING_BYTES:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 7 declares %d bytes, fewer than its %d framing bytes"
				% [byte_length, SECTION_FRAMING_BYTES])
	if bytes.size() < byte_length or offset > bytes.size() - byte_length:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 7 needs %d bytes at offset %d, buffer holds %d"
				% [byte_length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func decode_into(bytes: PackedByteArray, offset: int, byte_length: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode section 7 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the extent is proved, every owner wrapper is
	checked, each primary count and child extent is bounded against the compiled maximum BEFORE
	its `OwnerRecord` is allocated, the six blocks land in a LOCAL Record, and every column
	domain and cross-column invariant runs against that local. Only then is `out` overwritten.
	A full-length section carrying a provenance of 6, a free stack naming a live slot or blocks
	in the wrong ASCII order therefore leaves `out` byte-identical.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset, byte_length)
	if not extent.is_ok():
		return extent
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return order
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var parsed: Record = Record.new()
	var framing: SaveHeader.Refusal = _read_section(bytes, reader, parsed)
	if not framing.is_ok():
		return framing
	if reader.position() - offset != byte_length:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 7 consumed %d bytes, not the declared %d"
				% [reader.position() - offset, byte_length])
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_section(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read `store_count` then six owner blocks, tiling with no gaps in declared ASCII order."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 7 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	for owner: int in OWNER_COUNT:
		var block: SaveHeader.Refusal = _read_block(bytes, reader, owner, parsed)
		if not block.is_ok():
			return block
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_block(bytes: PackedByteArray, reader: SaveCodec.Reader, owner: int,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read one owner's wrapper, extents and columns, and check it consumed exactly its length.

	The payload begins after the three fixed-width wrapper fields the key is followed by, so
	`start` is computed from the key's end rather than sampled after `_read_wrapper()` -- which
	also consumes the child-extent block and would put those bytes outside the measured payload.
	"""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEYS[owner]:
		return SaveHeader.Refusal.new(REFUSE_OWNER_ORDER,
			("block %d is owned by '%s', not the ASCII-ordered '%s'. REG-R01 fixes the order; "
				+ "this reader does not sort blocks on the way in.")
				% [owner, text.value, OWNER_KEYS[owner]])
	var start: int = reader.position() + SaveCodec.U32_BYTES + SaveCodec.U64_BYTES \
		+ SaveCodec.U64_BYTES
	var declared: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var wrapper: SaveHeader.Refusal = _read_wrapper(reader, owner, parsed, declared)
	if not wrapper.is_ok():
		return wrapper
	var columns: SaveHeader.Refusal = _read_columns(bytes, reader, parsed.of(owner))
	if not columns.is_ok():
		return columns
	var consumed: int = reader.position() - start
	if consumed != declared.value:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' consumed %d payload bytes, not the %d its wrapper declares"
				% [OWNER_KEYS[owner], consumed, declared.value])
	if consumed != payload_bytes_of(parsed.of(owner)):
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"owner '%s' consumed %d payload bytes, not the %d its extents give"
				% [OWNER_KEYS[owner], consumed, payload_bytes_of(parsed.of(owner))])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_wrapper(reader: SaveCodec.Reader, owner: int, parsed: Record,
		out_declared: SaveCodec.Scalar) -> SaveHeader.Refusal:
	"""Read schema version, primary count, payload length and child extents, then allocate.

	HAZARD 4 and H4's "bounds are checked before allocation": the primary count and every child
	extent are bounded against the owning module's compiled maximum first, so a hostile count
	cannot make this allocate, and no extent is read off whichever column happens to come first.

	`out_declared` carries the wrapper's own `payload_byte_length` back to the caller, which
	compares it to the bytes the block ACTUALLY consumes. Recomputing the length from the
	decoded extents instead would compare the reader against itself and accept any declared
	length inside the arithmetically possible window -- which mutation testing confirmed.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSIONS[owner]:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner '%s' schema %d is not the supported %d"
				% [OWNER_KEYS[owner], scalar.value, OWNER_SCHEMA_VERSIONS[owner]])
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var primary_count: int = scalar.value
	var bound: SaveHeader.Refusal = primary_count_refusal(owner, primary_count)
	if not bound.is_ok():
		return bound
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	out_declared.succeed(scalar.value)
	return _read_extents(reader, owner, primary_count, scalar.value, parsed)


static func primary_count_refusal(owner: int, primary_count: int) -> SaveHeader.Refusal:
	"""Bound one owner's declared primary count against its compiled capacity.

	Three owners size their table from a construction argument, so their count is a stored
	runtime value in `[1, maximum]`. The other three are compile-time fixed and any other value
	is a refusal rather than a smaller world.
	"""
	var maximum: int = PRIMARY_COUNT_MAXIMA[owner]
	if PRIMARY_COUNT_IS_FIXED[owner] and primary_count != maximum:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
			"owner '%s' declares primary_count %d, not the compiled %d"
				% [OWNER_KEYS[owner], primary_count, maximum])
	if primary_count < 1 or primary_count > maximum:
		return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
```


## Lines 1530–1595
```gdscript
	"""
	if value < NULL_GENERATION or value > MAX_INT32:
		return _refuse(REFUSE_GENERATION_RANGE,
			"owner '%s' field '%s' row %d holds generation %d, outside 0..%d"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row, value, MAX_INT32])
	if live and value == NULL_GENERATION:
		return _refuse(REFUSE_GENERATION_RANGE,
			"owner '%s' field '%s' row %d is live with the null generation"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row])
	return _accepted()


static func _slot_refusal(value: int, live: bool, capacity: int, owner: int, ordinal: int,
		row: int) -> SaveHeader.Refusal:
	"""Bound one slot reference: NULL_SLOT when free, and inside `capacity` when live."""
	if value < NULL_SLOT or value >= capacity:
		return _refuse(REFUSE_SLOT_RANGE,
			"owner '%s' field '%s' row %d holds slot %d, outside %d..%d"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row, value, NULL_SLOT,
					capacity - 1])
	if live and value == NULL_SLOT:
		return _refuse(REFUSE_SLOT_RANGE,
			"owner '%s' field '%s' row %d is live with the null slot"
				% [OWNER_KEYS[owner], field_keys_of(owner)[ordinal], row])
	return _accepted()


static func _blank_row_refusal(block: OwnerRecord, row: int,
		ordinals: Array[int]) -> SaveHeader.Refusal:
	"""Refuse a released row that is not at its owning module's canonical empty value.

	`fishing._clear_effort_claim_row()`, `forage._clear_claim_row()`, `gear._blank_row()` and
	`reservations._free_row()` each blank EVERY column of a released row, so a nonzero residue
	there is corruption, not history -- and, left unchecked, two observably identical worlds
	would produce different bytes. `inventory.gd` still does NOT blank a retired row at
	retirement time -- see `_inventory_unused_refusal()` for why that would be a defect -- so it
	uses its own literal INV-CANON-R01 table rather than this one.
	"""
	for ordinal: int in ordinals:
		var expected: int = canonical_fill_of(block.owner, ordinal)
		var actual: int = _cell_of(block, ordinal, row)
		if actual != expected:
			return _refuse(REFUSE_BLANK_ROW,
				"owner '%s' row %d is free but '%s' holds %d, not the blank %d"
					% [OWNER_KEYS[block.owner], row, field_keys_of(block.owner)[ordinal],
						actual, expected])
	return _accepted()


## INV-CANON-R01's unused-value table for `inventory`, written out as LITERALS.
##
## DELIBERATELY NOT `canonical_fill_of()`. That function is what a freshly allocated
## `OwnerRecord` column is FILLED with, so validating an inactive row against it would be a
## check whose expectation comes from the thing it checks: change the fill and the check moves
## with it, silently. These are the twenty-two numbers the ruling prints, typed here once, and
## `test_save_section_inventories.gd` reads them back off the encoded wire at literal offsets.
##
## Container ordinals 6..15 and lot ordinals 16..27 -- every inventory payload field. The three
## groups NOT in these lists are the ones the ruling preserves: occupancy (2, 3), the row's own
## generation (4, 5), and the two free stacks (28, 29).
const INVENTORY_UNUSED_CONTAINER_ORDINALS: Array[int] = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const INVENTORY_UNUSED_CONTAINER_VALUES: Array[int] = [-1, 0, 0, 0, -1, 0, 0, 0, 0, 0]
const INVENTORY_UNUSED_LOT_ORDINALS: Array[int] = [
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
]
const INVENTORY_UNUSED_LOT_VALUES: Array[int] = [0, 0, 0, 0, -1, 0, -1, -1, 0, 0, 0, 0]
```


## Lines 1649–1710
```gdscript


## Ordinals every released row of the four blanking owners must carry at its canonical value.
const BLANK_ORDINALS_FISHING: Array[int] = [1, 2, 3, 4, 5, 6]
const BLANK_ORDINALS_FORAGE: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const BLANK_ORDINALS_GEAR: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
const BLANK_ORDINALS_RESERVATIONS: Array[int] = [1, 2, 3, 4, 5, 6, 7]


static func _fishing_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `fishing.gd`'s FishingEffortClaim rows: a lease on a habitat's effort slots.

	The row index is the OWNING EXPEDITION'S typed row, so a loader must never compact these.
	`_effort_claim_habitat_slot` and `_effort_claim_job_slot` are DIRECTORY slots, taken from
	`habitat_ref.x` and `job_ref.x` in `_write_effort_claim()`, not typed rows of their stores.
	"""
	var active: PackedByteArray = block.u8_column(0)
	var occupancy: SaveHeader.Refusal = _occupancy_refusal(active, block.owner, 0)
	if not occupancy.is_ok():
		return occupancy
	for row: int in block.primary_count:
		var live: bool = active[row] == 1
		if not live:
			var blank: SaveHeader.Refusal = _blank_row_refusal(block, row, BLANK_ORDINALS_FISHING)
			if not blank.is_ok():
				return blank
			continue
		var claim: SaveHeader.Refusal = _fishing_row_refusal(block, row)
		if not claim.is_ok():
			return claim
	return _accepted()


static func _fishing_row_refusal(block: OwnerRecord, row: int) -> SaveHeader.Refusal:
	"""Validate one live effort claim: three references and a positive slot count."""
	for ordinal: int in [1, 3, 5]:
		var generation: SaveHeader.Refusal = _generation_refusal(block.i32_column(ordinal)[row],
			true, block.owner, ordinal, row)
		if not generation.is_ok():
			return generation
	for ordinal: int in [2, 4]:
		var slot: SaveHeader.Refusal = _slot_refusal(block.i32_column(ordinal)[row], true,
			DIRECTORY_CAPACITY, block.owner, ordinal, row)
		if not slot.is_ok():
			return slot
	if block.i32_column(6)[row] < 1:
		return _refuse(REFUSE_SLOT_COUNT,
			"fishing row %d is an active claim on %d effort slots"
				% [row, block.i32_column(6)[row]])
	return _accepted()


static func _forage_refusal(block: OwnerRecord) -> SaveHeader.Refusal:
	"""Validate `forage.gd`'s ForageClaim rows: live claims against a zone's quota.

	Indexed by the owning Job's typed row (decision 0030 §4.7), so these rows are not compacted
	either. `_claim_remaining_milli` is work in progress and `_claim_created_tick` orders expiry.
	"""
	var active: PackedByteArray = block.u8_column(0)
	var occupancy: SaveHeader.Refusal = _occupancy_refusal(active, block.owner, 0)
	if not occupancy.is_ok():
		return occupancy
```
