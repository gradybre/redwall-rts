extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 7 INVENTORIES_AND_LEASE_INDEXES.
##
## Section 7 is the largest multi-owner section, and round trip is nowhere near sufficient for
## it. The four failures it exists to prevent are the four REG-R01 names, and each has its own
## test that fails against the specific wrong implementation rather than against noise:
##
##   1. FREE-STACK ORDER AND ITS GARBAGE TAIL. `_c_free`/`_l_free` are STACKS, so pop order is
##      the array permutation. `test_free_stack_order_survives_a_round_trip` pins a permutation
##      that is NOT the descending refill, so an encoder that sorted or rebuilt the stack
##      ascending fails. `test_free_stack_garbage_tail_is_not_persisted` gives two records the
##      same logical state and DIFFERENT tails and demands identical bytes, so an encoder that
##      wrote the whole column fails.
##   2. GENERATION NAMESPACES. `test_gear_declares_no_generation_of_its_own` and its reservations
##      twin pin the exact declared field lists, so a column invented for either store fails.
##   3. PROVENANCE. `test_provenance_six_is_refused_not_clamped` proves 6 and -1 are REFUSED, and
##      that the refusal leaves the caller's record byte-identical -- clamping to ORDINARY would
##      pass a round trip and silently grant a coastal-brine entitlement.
##   4. EXTENTS. `test_child_extent_is_not_the_first_column_length` builds an inventory block
##      whose containers and lots differ AND whose first declared column is a one-element scalar,
##      so an implementation that read the extent off the first column produces 1, not 8 or 4.
##
## INTEGER BOUNDARIES COME FROM BIT CONVERSIONS, NOT LITERALS. `0x80000000` is a POSITIVE
## GDScript int and `-2147483648` as an int32. `test_generation_high_bit_is_read_signed` builds
## the boundary through `SaveCodec.u32_bits_to_int32()` and asserts the pair agrees before using
## it, because typing the signed literal is how a sign-trap test ends up testing nothing.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Section := preload("res://scripts/core/save_section_inventories.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

## Small runtime capacities for the three owners whose primary count is a construction argument.
## `fishing`, `forage` and `stock_age` are compile-time fixed and cannot be shrunk.
const SMALL_CONTAINERS: int = 8
const SMALL_LOTS: int = 4
const SMALL_ROWS: int = 8

var _record: Section.Record = null
var _encoded: Section.EncodeResult = null


func before_each() -> void:
	"""Build a small empty record and an EncodeResult for each test."""
	_record = _small_record()
	_encoded = Section.EncodeResult.new()


func _small_record() -> Section.Record:
	"""A record at the six stores' empty state, with the three runtime owners shrunk."""
	var record: Section.Record = Section.Record.new()
	record.owners[Section.OWNER_GEAR] = Section.OwnerRecord.new(
		Section.OWNER_GEAR, SMALL_ROWS, PackedInt64Array())
	record.owners[Section.OWNER_RESERVATIONS] = Section.OwnerRecord.new(
		Section.OWNER_RESERVATIONS, SMALL_ROWS, PackedInt64Array())
	record.owners[Section.OWNER_INVENTORY] = Section.OwnerRecord.new(
		Section.OWNER_INVENTORY, SMALL_CONTAINERS, PackedInt64Array([SMALL_LOTS]))
	Section.fill_empty(record)
	return record


func _set_cell(block: Section.OwnerRecord, ordinal: int, row: int, value: int) -> void:
	"""Write one column cell, replacing the whole packed array because it is a value type."""
	var type_code: int = Section.field_type_of(block.owner, ordinal)
	var index: int = Section.storage_index_of(block.owner, ordinal)
	if type_code == Section.TYPE_U8:
		var bytes: PackedByteArray = block.u8_columns[index].duplicate()
		bytes[row] = value
		block.u8_columns[index] = bytes
		return
	if type_code == Section.TYPE_I32:
		var words: PackedInt32Array = block.i32_columns[index].duplicate()
		words[row] = value
		block.i32_columns[index] = words
		return
	var longs: PackedInt64Array = block.i64_columns[index].duplicate()
	longs[row] = value
	block.i64_columns[index] = longs


func _block_offset(record: Section.Record, owner: int) -> int:
	"""Byte offset of one owner block from the start of the section."""
	var offset: int = Section.SECTION_FRAMING_BYTES
	for earlier: int in owner:
		offset += Section.block_bytes_of(record.of(earlier))
	return offset


func _field_value_offset(record: Section.Record, owner: int, ordinal: int) -> int:
	"""Byte offset of one field's first value, from the start of the section."""
	var offset: int = _block_offset(record, owner) + Section.wrapper_bytes_of(owner) \
		+ Section.extent_block_bytes_of(owner)
	for earlier: int in ordinal:
		offset += Section.ELEMENT_COUNT_BYTES
		offset += Section.width_of_type(Section.field_type_of(owner, earlier)) \
			* Section.persisted_count_of(record.of(owner), earlier)
	return offset + Section.ELEMENT_COUNT_BYTES


func _encode(record: Section.Record) -> PackedByteArray:
	"""Encode a record, failing the test rather than returning half a section."""
	var result: Section.EncodeResult = Section.EncodeResult.new()
	if not Section.encode_record(record, result):
		fail("encode refused: %s %s" % [result.refusal, result.detail])
		return PackedByteArray()
	return result.bytes


func _allocate_container(record: Section.Record, slot: int) -> void:
	"""Take one container slot off the free stack and mark it live, as `create_container()` does."""
	var block: Section.OwnerRecord = record.of(Section.OWNER_INVENTORY)
	var count: int = block.scalar(0) - 1
	block.set_scalar(0, count)
	_set_cell(block, 2, slot, 1)


func _allocate_lot(record: Section.Record, slot: int, container: int) -> void:
	"""Take one lot slot off the free stack, fill a plausible live lot, and link its container."""
	var block: Section.OwnerRecord = record.of(Section.OWNER_INVENTORY)
	block.set_scalar(1, block.scalar(1) - 1)
	_set_cell(block, 3, slot, 1)
	_set_cell(block, 16, slot, 3)
	_set_cell(block, 18, slot, CatalogScript.PROVENANCE_STARTER)
	_set_cell(block, 20, slot, container)
	_set_cell(block, 21, slot, 1)
	_set_cell(block, 24, slot, 2500)
	_set_cell(block, 25, slot, 500)
	_set_cell(block, 9, container, 1)
	_set_cell(block, 10, container, slot)


# --- framing and declared identity -------------------------------------------------------------

func test_store_count_and_owner_order_are_ascii() -> void:
	"""REG-R01 names six owners and requires ASCII key order; the keys must actually be sorted."""
	assert_equal(Section.OWNER_COUNT, 6, "section 7 declares six owners")
	assert_equal(Section.STORE_COUNT, 6, "store_count equals the owner count")
	for owner: int in Section.OWNER_COUNT - 1:
		assert_true(Section.OWNER_KEYS[owner] < Section.OWNER_KEYS[owner + 1],
			"owner key '%s' sorts before '%s'"
				% [Section.OWNER_KEYS[owner], Section.OWNER_KEYS[owner + 1]])
	assert_equal(Section.OWNER_KEYS[0], "fishing", "the first block is fishing")
	assert_equal(Section.OWNER_KEYS[5], "stock_age", "the last block is stock_age")


func test_owner_schema_versions_match_the_registry() -> void:
	"""REG-R01: inventory is owner schema 2 for protected provenance; the other five are 1."""
	assert_equal(Section.OWNER_SCHEMA_VERSIONS[Section.OWNER_INVENTORY], 2,
		"inventory declares owner schema 2")
	for owner: int in Section.OWNER_COUNT:
		if owner == Section.OWNER_INVENTORY:
			continue
		assert_equal(Section.OWNER_SCHEMA_VERSIONS[owner], 1,
			"owner '%s' declares schema 1" % Section.OWNER_KEYS[owner])


func test_section_opens_with_a_store_count_of_six() -> void:
	"""The first four bytes are the little-endian u32 6, then the fishing owner key."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(bytes.slice(0, 4), PackedByteArray([6, 0, 0, 0]),
		"store_count is the little-endian u32 6")
	assert_equal(bytes.slice(4, 8), PackedByteArray([7, 0, 0, 0]),
		"the first owner key is seven bytes long")
	assert_equal(bytes.slice(8, 15).get_string_from_utf8(), "fishing",
		"the first block is owned by fishing")


func test_default_capacity_section_has_the_declared_byte_vector() -> void:
	"""Pin the real byte arithmetic at the compiled maxima with every slot free."""
	var full: Section.Record = Section.empty_record()
	var sizes: Array[int] = [12891, 434298, 688256, 7481637, 1212520, 608353]
	for owner: int in Section.OWNER_COUNT:
		assert_equal(Section.block_bytes_of(full.of(owner)), sizes[owner],
			"owner '%s' block is %d bytes" % [Section.OWNER_KEYS[owner], sizes[owner]])
	assert_equal(Section.section_bytes_of(full), 10437959,
		"the whole empty section is 10437959 bytes")
	assert_equal(Section.section_bytes_of(full), 4 + 12891 + 434298 + 688256 + 7481637
		+ 1212520 + 608353, "the six blocks tile the section with no gaps")


func test_small_record_block_arithmetic_is_exact() -> void:
	"""The shrunk owners' blocks match wrapper + extents + per-column counts and values."""
	var gear: int = Section.wrapper_bytes_of(Section.OWNER_GEAR) + 4 + 12 * 8 \
		+ (2 * 1 + 10 * 4) * SMALL_ROWS
	assert_equal(Section.block_bytes_of(_record.of(Section.OWNER_GEAR)), gear,
		"the gear block is %d bytes at %d rows" % [gear, SMALL_ROWS])
	var reservations: int = Section.wrapper_bytes_of(Section.OWNER_RESERVATIONS) + 4 + 8 * 8 \
		+ (1 + 5 * 4 + 2 * 8) * SMALL_ROWS
	assert_equal(Section.block_bytes_of(_record.of(Section.OWNER_RESERVATIONS)), reservations,
		"the reservations block is %d bytes at %d rows" % [reservations, SMALL_ROWS])


# --- round trip ---------------------------------------------------------------------------------

func test_empty_record_round_trips_byte_identically() -> void:
	"""Encode, decode and re-encode the empty state; the two byte images must be identical."""
	var bytes: PackedByteArray = _encode(_record)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "the empty section decodes: %s" % refusal.detail)
	assert_true(back.equals(_record), "the decoded record equals the encoded one")
	assert_equal(_encode(back), bytes, "re-encoding the decoded record is byte-identical")


func test_populated_record_round_trips_byte_identically() -> void:
	"""A world with a live container, a live lot and a partially consumed free stack."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	block.set_stack_column(28, PackedInt32Array([7, 6, 5, 4, 3, 2, 1]), 7)
	block.set_stack_column(29, PackedInt32Array([3, 2, 1]), 3)
	var bytes: PackedByteArray = _encode(_record)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "the populated section decodes: %s" % refusal.detail)
	assert_equal(back.of(Section.OWNER_INVENTORY).scalar(0), 7, "seven container slots stay free")
	assert_equal(back.of(Section.OWNER_INVENTORY).scalar(1), 3, "three lot slots stay free")
	assert_equal(_encode(back), bytes, "re-encoding the populated record is byte-identical")


func test_offset_decoding_reads_the_same_section() -> void:
	"""A section that does not start at byte zero decodes identically from its own offset."""
	var bytes: PackedByteArray = _encode(_record)
	var padded: PackedByteArray = PackedByteArray([9, 9, 9])
	padded.append_array(bytes)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(padded, 3, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "decoding at offset 3 succeeds")
	assert_true(back.equals(_record), "the record decoded at an offset is the same record")


# --- HAZARD 1: free-stack order and the garbage tail -------------------------------------------

func test_free_stack_order_survives_a_round_trip() -> void:
	"""Pop order is the permutation, so a non-descending stack must come back in that exact order."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	_allocate_container(_record, 0)
	_allocate_container(_record, 4)
	var permutation: PackedInt32Array = PackedInt32Array([5, 7, 6, 1, 3, 2])
	block.set_stack_column(28, permutation, 6)
	var bytes: PackedByteArray = _encode(_record)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "the permuted stack decodes: %s" % refusal.detail)
	var decoded: PackedInt32Array = back.of(Section.OWNER_INVENTORY).i32_column(28)
	for index: int in 6:
		assert_equal(decoded[index], permutation[index],
			"free stack entry %d survived as %d" % [index, permutation[index]])


func test_free_stack_garbage_tail_is_not_persisted() -> void:
	"""Two worlds identical in logical state and different in stale tail must encode identically."""
	var other: Section.Record = _small_record()
	for record: Section.Record in [_record, other]:
		_allocate_container(record, 0)
		record.of(Section.OWNER_INVENTORY).set_stack_column(28,
			PackedInt32Array([7, 6, 5, 4, 3, 2, 1]), 7)
	var block: Section.OwnerRecord = other.of(Section.OWNER_INVENTORY)
	var index: int = Section.storage_index_of(Section.OWNER_INVENTORY, 28)
	var polluted: PackedInt32Array = block.i32_columns[index].duplicate()
	polluted[7] = 4
	block.i32_columns[index] = polluted
	assert_equal(_encode(other), _encode(_record),
		"stale garbage beyond the free count changes no byte of the section")
	assert_equal(polluted[7], 4, "the polluted record really did hold a different tail cell")


func test_declared_slot_list_tail_is_not_persisted() -> void:
	"""`stock_age`'s dense list is the same shape: only `[0, _declared_count)` reaches the wire."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_STOCK_AGE)
	assert_equal(Section.persisted_count_of(block, 5), 0,
		"an undeclared world persists no declared slots")
	_set_cell(block, 2, 11, 3)
	_set_cell(block, 4, 11, 1)
	block.set_scalar(0, 1)
	block.set_stack_column(5, PackedInt32Array([11]), 1)
	assert_equal(Section.persisted_count_of(block, 5), 1, "one declaration persists one slot")
	var bytes: PackedByteArray = _encode(_record)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "the declaration decodes: %s" % refusal.detail)
	assert_equal(back.of(Section.OWNER_STOCK_AGE).i32_column(5)[0], 11,
		"the declared slot survives in sweep order")


func test_free_stack_naming_a_live_slot_is_refused() -> void:
	"""REG-R01: validate the counts against occupancy. A live slot cannot also be free."""
	_allocate_container(_record, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	block.set_stack_column(28, PackedInt32Array([7, 6, 5, 4, 3, 2, 0]), 7)
	var refusal: SaveHeader.Refusal = Section.record_refusal(_record)
	assert_equal(refusal.code, Section.REFUSE_FREE_STACK,
		"a free stack naming a live slot is refused")


func test_slot_that_is_neither_live_nor_free_must_be_retired() -> void:
	"""The only way out of both sets is generation exhaustion; anything else is a lost slot."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	block.set_scalar(0, 7)
	block.set_stack_column(28, PackedInt32Array([7, 6, 5, 4, 3, 2, 1]), 7)
	var refusal: SaveHeader.Refusal = Section.record_refusal(_record)
	assert_equal(refusal.code, Section.REFUSE_SLOT_UNACCOUNTED,
		"slot 0 is neither live, free nor retired")
	_set_cell(block, 4, 0, InventoryScript.MAX_INT32)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_NONE,
		"the same slot retired at MAX_INT32 is accounted for")


func test_free_count_above_capacity_is_refused() -> void:
	"""A count field outside its column is refused before anything is read into that column."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	block.set_scalar(1, SMALL_LOTS + 1)
	var refusal: SaveHeader.Refusal = Section.record_refusal(_record)
	assert_equal(refusal.code, Section.REFUSE_FREE_STACK,
		"a lot free count above the lot capacity is refused")


# --- HAZARD 2: generation namespaces ------------------------------------------------------------

func test_gear_declares_no_generation_of_its_own() -> void:
	"""REG-R01: gear rows are bare indices. The declared list is pinned so none can be added."""
	var keys: Array[StringName] = Section.field_keys_of(Section.OWNER_GEAR)
	assert_equal(keys.size(), 12, "gear declares exactly twelve fields")
	assert_false(keys.has(&"_generation"), "gear declares no generation column of its own")
	assert_equal(keys[2], &"_lot_generation", "gear's ordinal 2 is the INVENTORY lot generation")
	assert_equal(keys[7], &"_owner_generation", "gear's ordinal 7 is the DIRECTORY generation")
	assert_equal(Section.child_extent_count_of(Section.OWNER_GEAR), 0,
		"gear declares one logical table and no child extent")


func test_reservations_declares_no_generation_of_its_own() -> void:
	"""The same rule for reservations: two borrowed generation spaces, none belonging to the row."""
	var keys: Array[StringName] = Section.field_keys_of(Section.OWNER_RESERVATIONS)
	assert_equal(keys.size(), 8, "reservations declares exactly eight fields")
	assert_false(keys.has(&"_generation"), "reservations declares no generation of its own")
	assert_equal(keys[2], &"_r_job_generation", "ordinal 2 is the DIRECTORY job generation")
	assert_equal(keys[4], &"_r_lot_generation", "ordinal 4 is the INVENTORY lot generation")


func test_generation_high_bit_is_read_signed() -> void:
	"""`00 00 00 80` is -2147483648 as an int32, not a plausible 2147483648, and is refused."""
	var bits: int = SaveCodec.UINT32_SIGN_BIT
	var as_int32: int = SaveCodec.u32_bits_to_int32(bits)
	assert_equal(as_int32, -2147483648, "0x80000000 reads as -2147483648 through an i32 column")
	assert_equal(SaveCodec.int32_bits_to_u32(as_int32), bits, "and converts back to 0x80000000")
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _field_value_offset(_record, Section.OWNER_INVENTORY, 4)
	bytes[offset] = 0
	bytes[offset + 1] = 0
	bytes[offset + 2] = 0
	bytes[offset + 3] = 128
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_GENERATION_RANGE,
		"a container generation with the high bit set is refused as negative")


# --- HAZARD 3: the protected provenance domain --------------------------------------------------

func test_every_published_provenance_member_is_accepted() -> void:
	"""All six of decision 0113's members, and only those, are in domain."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	for member: int in range(CatalogScript.PROVENANCE_ORDINARY,
			CatalogScript.PROVENANCE_SPOIL_RECLAIM + 1):
		_set_cell(block, 18, 0, member)
		assert_equal(Section.record_refusal(_record).code, Section.REFUSE_NONE,
			"InventoryProvenance member %d is accepted" % member)


func test_provenance_six_is_refused_not_clamped() -> void:
	"""PROV-R01: 6 and -1 fail. A clamp to ORDINARY would pass and grant a false entitlement."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	for outside: int in [CatalogScript.PROVENANCE_SPOIL_RECLAIM + 1, -1, 255]:
		_set_cell(block, 18, 0, outside)
		assert_equal(Section.record_refusal(_record).code, Section.REFUSE_PROVENANCE_DOMAIN,
			"provenance %d is refused, not clamped" % outside)


func test_out_of_domain_provenance_refuses_a_full_length_section_without_writing() -> void:
	"""Commit-then-validate would leave `out` half written. The section is FULL LENGTH and valid
	in every framing field; only the provenance value is out of domain."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _field_value_offset(_record, Section.OWNER_INVENTORY, 18)
	bytes[offset] = 6
	var target: Section.Record = _small_record()
	var before: PackedByteArray = _encode(target)
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), target)
	assert_equal(refusal.code, Section.REFUSE_PROVENANCE_DOMAIN,
		"a full-length section carrying provenance 6 is refused")
	assert_equal(_encode(target), before,
		"the refused decode left the caller's record byte-identical")


# --- HAZARD 4: extents are declared, never inferred ---------------------------------------------

func test_child_extent_is_not_the_first_column_length() -> void:
	"""Containers, lots and the first declared column all differ, so a guess produces none of them."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	assert_equal(Section.persisted_count_of(block, 0), 1,
		"the FIRST declared inventory column is a one-element scalar")
	assert_equal(Section.backing_extent_of(block, 2), SMALL_CONTAINERS,
		"`_c_live` runs to the container extent")
	assert_equal(Section.backing_extent_of(block, 3), SMALL_LOTS,
		"`_l_live` runs to the lot extent, which is different")
	var bytes: PackedByteArray = _encode(_record)
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_NONE, "the two-table block decodes: %s" % refusal.detail)
	assert_equal(back.of(Section.OWNER_INVENTORY).child_extents,
		PackedInt64Array([SMALL_LOTS]), "the lot extent came off the declaration")
	assert_equal(back.of(Section.OWNER_INVENTORY).u8_column(3).size(), SMALL_LOTS,
		"`_l_live` decoded at the lot extent, not the container extent or one")


func test_only_inventory_declares_a_child_extent() -> void:
	"""The other five owners hold one logical table each and declare zero child extents."""
	for owner: int in Section.OWNER_COUNT:
		var expected: int = 1 if owner == Section.OWNER_INVENTORY else 0
		assert_equal(Section.child_extent_count_of(owner), expected,
			"owner '%s' declares %d child extents" % [Section.OWNER_KEYS[owner], expected])


func test_child_extent_above_the_compiled_lot_capacity_is_refused() -> void:
	"""Bounds are checked before allocation (H4), so a hostile extent never allocates."""
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _block_offset(_record, Section.OWNER_INVENTORY) \
		+ Section.wrapper_bytes_of(Section.OWNER_INVENTORY) + 4
	var oversized: int = InventoryScript.LOT_CAPACITY + 1
	for index: int in 8:
		bytes[offset + index] = (oversized >> (index * 8)) & 255
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_CHILD_EXTENT,
		"a lot extent above the compiled capacity is refused")


func test_primary_count_bounds_are_enforced_per_owner() -> void:
	"""Three owners carry a runtime capacity; three are compile-time fixed and admit no other."""
	assert_equal(Section.primary_count_refusal(Section.OWNER_FISHING, 511).code,
		Section.REFUSE_PRIMARY_COUNT, "fishing's fixed capacity admits no other value")
	assert_equal(Section.primary_count_refusal(Section.OWNER_GEAR, 0).code,
		Section.REFUSE_PRIMARY_COUNT, "a gear capacity of zero is refused")
	assert_equal(Section.primary_count_refusal(Section.OWNER_GEAR, 16385).code,
		Section.REFUSE_PRIMARY_COUNT, "a gear capacity above the compiled maximum is refused")
	assert_equal(Section.primary_count_refusal(Section.OWNER_GEAR, SMALL_ROWS).code,
		Section.REFUSE_NONE, "a gear capacity inside the maximum is accepted")


# --- owner ordering on the wire -----------------------------------------------------------------

func test_blocks_out_of_ascii_order_are_refused() -> void:
	"""A stream carrying forage before fishing is refused, not sorted on the way in."""
	var bytes: PackedByteArray = _encode(_record)
	var first: int = Section.block_bytes_of(_record.of(Section.OWNER_FISHING))
	var second: int = Section.block_bytes_of(_record.of(Section.OWNER_FORAGE))
	var swapped: PackedByteArray = bytes.slice(0, 4)
	swapped.append_array(bytes.slice(4 + first, 4 + first + second))
	swapped.append_array(bytes.slice(4, 4 + first))
	swapped.append_array(bytes.slice(4 + first + second))
	assert_equal(swapped.size(), bytes.size(), "the swap preserved the section length")
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(swapped, 0, swapped.size(), back)
	assert_equal(refusal.code, Section.REFUSE_OWNER_ORDER,
		"blocks out of ASCII order are refused")


func test_wrong_owner_schema_version_is_refused() -> void:
	"""A stream declaring inventory schema 1 is an older layout and must not be read as 2."""
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _block_offset(_record, Section.OWNER_INVENTORY) + 4 + 9
	assert_equal(bytes[offset], 2, "inventory's wire schema version is 2")
	bytes[offset] = 1
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_OWNER_SCHEMA_VERSION,
		"inventory schema 1 is refused")


func test_declared_payload_length_must_match_what_the_block_consumes() -> void:
	"""A length inside the extent window but wrong is caught by exact consumption, not by bounds.

	`inventory` is the owner where the two checks differ: its free stacks make a RANGE of payload
	lengths arithmetically possible, so a length picked inside that range passes the bounds gate
	and only the byte-exact comparison finds it.
	"""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	block.set_stack_column(28, PackedInt32Array([7, 6, 5, 4, 3, 2, 1]), 7)
	block.set_stack_column(29, PackedInt32Array([3, 2, 1]), 3)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _block_offset(_record, Section.OWNER_INVENTORY) + 4 + 9 + 4 + 8
	var truth: int = Section.payload_bytes_of(block)
	assert_equal(bytes[offset], truth & 255, "the declared payload length starts here")
	var wrong: int = truth + 4
	for index: int in 8:
		bytes[offset + index] = (wrong >> (index * 8)) & 255
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_PAYLOAD_LENGTH,
		"a payload length four bytes long is refused")


func test_wrong_element_count_is_refused() -> void:
	"""Each column carries its own count, and a count that disagrees with the declared extent
	is refused there rather than being discovered later as a payload-length mismatch."""
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = _field_value_offset(_record, Section.OWNER_INVENTORY, 2) \
		- Section.ELEMENT_COUNT_BYTES
	assert_equal(bytes[offset], SMALL_CONTAINERS, "`_c_live` declares the container extent")
	bytes[offset] = SMALL_CONTAINERS - 1
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_ELEMENT_COUNT,
		"a column count that disagrees with its declared extent is refused")


func test_wrong_store_count_is_refused() -> void:
	"""Five stores is a different section; the reader refuses instead of reading five blocks."""
	var bytes: PackedByteArray = _encode(_record)
	bytes[0] = 5
	var back: Section.Record = Section.Record.new()
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes, 0, bytes.size(), back)
	assert_equal(refusal.code, Section.REFUSE_STORE_COUNT, "a store count of five is refused")


# --- extents, truncation and the stream ---------------------------------------------------------

func test_extent_refusal_is_the_primary_gate() -> void:
	"""Negative offsets, short buffers and impossible lengths refuse before any read."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(Section.extent_refusal(bytes, -1, bytes.size()).code,
		Section.REFUSE_NEGATIVE_OFFSET, "a negative offset is refused")
	assert_equal(Section.extent_refusal(bytes, 0, 3).code, Section.REFUSE_LENGTH,
		"a length below the framing bytes is refused")
	assert_equal(Section.extent_refusal(bytes, 1, bytes.size()).code, Section.REFUSE_TRUNCATED,
		"a section that would run past the buffer is refused")
	assert_equal(Section.extent_refusal(bytes, 0, bytes.size()).code, Section.REFUSE_NONE,
		"the exact extent is accepted")


func test_truncated_section_leaves_the_target_untouched() -> void:
	"""Allocate before consume: a short buffer changes nothing the caller already held."""
	var bytes: PackedByteArray = _encode(_record)
	var target: Section.Record = _small_record()
	_allocate_container(target, 0)
	target.of(Section.OWNER_INVENTORY).set_stack_column(28,
		PackedInt32Array([7, 6, 5, 4, 3, 2, 1]), 7)
	var before: PackedByteArray = _encode(target)
	var refusal: SaveHeader.Refusal = Section.decode_into(bytes.slice(0, bytes.size() - 1), 0,
		bytes.size(), target)
	assert_equal(refusal.code, Section.REFUSE_TRUNCATED, "a one-byte-short section is refused")
	assert_equal(_encode(target), before, "the refused decode wrote nothing")


func test_chunk_cursor_is_bounded_and_reproduces_the_section() -> void:
	"""ARCH-SAVE-003's 65536-byte stream: field-aligned, bounded and identical to one buffer."""
	var bytes: PackedByteArray = _encode(_record)
	var cursor: Section.ChunkCursor = Section.ChunkCursor.new(_record)
	var chunk: Section.Chunk = Section.Chunk.new()
	var streamed: PackedByteArray = PackedByteArray()
	var chunks: int = 0
	while cursor.has_more():
		assert_true(cursor.next_chunk_into(chunk), "chunk %d was emitted" % chunks)
		assert_true(chunk.bytes.size() <= Section.CHUNK_BYTES,
			"chunk %d holds at most %d bytes" % [chunks, Section.CHUNK_BYTES])
		streamed.append_array(chunk.bytes)
		chunks += 1
	assert_equal(streamed, bytes, "the stream reproduces the single-buffer encoding")
	assert_equal(cursor.emitted_bytes(), bytes.size(), "the cursor counted every byte")
	assert_false(cursor.next_chunk_into(chunk), "a drained cursor refuses")
	assert_equal(chunk.refusal, Section.REFUSE_CURSOR_EXHAUSTED, "and says it is exhausted")


func test_large_column_is_split_into_bounded_chunks() -> void:
	"""A full-capacity stock_age column is 101376 bytes and must not arrive as one chunk."""
	var full: Section.Record = Section.empty_record()
	var cursor: Section.ChunkCursor = Section.ChunkCursor.new(full)
	var chunk: Section.Chunk = Section.Chunk.new()
	var largest: int = 0
	var count: int = 0
	while cursor.has_more():
		assert_true(cursor.next_chunk_into(chunk), "chunk %d was emitted" % count)
		largest = maxi(largest, chunk.bytes.size())
		count += 1
	assert_equal(largest, Section.CHUNK_BYTES, "the largest chunk is exactly the 65536-byte bound")
	assert_equal(cursor.emitted_bytes(), Section.section_bytes_of(full),
		"the streamed section is the whole 10437959 bytes")


# --- per-owner domain rules ---------------------------------------------------------------------

func test_occupancy_byte_above_one_is_refused() -> void:
	"""ARCH-SAVE-002's bitset is one byte per row and holds only 0 or 1."""
	_set_cell(_record.of(Section.OWNER_GEAR), 0, 3, 2)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_OCCUPANCY_BYTE,
		"a gear occupancy byte of 2 is refused")


func test_released_row_residue_is_refused() -> void:
	"""`gear._blank_row()` clears every column, so residue on a free row is corruption."""
	_set_cell(_record.of(Section.OWNER_GEAR), 4, 2, 700)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_BLANK_ROW,
		"durability left on a released gear row is refused")
	_set_cell(_record.of(Section.OWNER_FISHING), 6, 5, 1)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_BLANK_ROW,
		"an effort slot count left on a released fishing claim is refused")


func test_reserved_above_quantity_is_refused() -> void:
	"""ARCH-SAVE-005: `0 <= reserved <= quantity`, on every lot row."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	_set_cell(block, 25, 0, 9000)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_QUANTITY_RANGE,
		"reserving more than a lot holds is refused")


func test_negative_age_is_refused() -> void:
	"""A negative age inverts every downstream spoilage result; refusal is the only response."""
	_allocate_container(_record, 0)
	_allocate_lot(_record, 0, 0)
	_set_cell(_record.of(Section.OWNER_INVENTORY), 26, 0, -1)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_AGE_RANGE,
		"a negative lot age is refused rather than stored")


func test_container_over_capacity_is_refused() -> void:
	"""BAL-SAFE-002's `used + reserved <= max`, re-derived without an addition that can overflow."""
	_allocate_container(_record, 0)
	var block: Section.OwnerRecord = _record.of(Section.OWNER_INVENTORY)
	_set_cell(block, 11, 0, 1000)
	_set_cell(block, 14, 0, 800)
	_set_cell(block, 13, 0, 300)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_CONTAINER_CAPACITY,
		"800 used plus 300 reserved against a 1000 gram capacity is refused")
	_set_cell(block, 13, 0, 200)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_NONE,
		"800 plus 200 against 1000 is exactly at capacity and is accepted")


func test_storage_class_outside_the_domain_is_refused() -> void:
	"""GDD §5.8 publishes five storage classes; a sixth is refused, not treated as undeclared."""
	_set_cell(_record.of(Section.OWNER_STOCK_AGE), 2, 9, 5)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_STORAGE_CLASS,
		"storage class 5 is outside the published domain")


func test_declared_list_must_match_the_storage_classes() -> void:
	"""A declared container missing from the dense list silently stops being aged."""
	var block: Section.OwnerRecord = _record.of(Section.OWNER_STOCK_AGE)
	_set_cell(block, 2, 20, 4)
	_set_cell(block, 4, 20, 1)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_DECLARED_LIST,
		"a cellar absent from the dense list is refused")
	block.set_scalar(0, 1)
	block.set_stack_column(5, PackedInt32Array([20]), 1)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_NONE,
		"the same cellar present in the list is accepted")


func test_undeclared_container_carries_no_declaration_generation() -> void:
	"""A generation on an undeclared slot would let a recycled slot inherit a storage class."""
	_set_cell(_record.of(Section.OWNER_STOCK_AGE), 4, 30, 7)
	assert_equal(Section.record_refusal(_record).code, Section.REFUSE_HEATED_BYTE,
		"a declaration generation without a storage class is refused")


func test_source_holds_no_float() -> void:
	"""ARCH-AUTH-002. Section 7 decides integer state and its CODE must contain no float.

	Comment lines are stripped first, because the module header says in prose that there is no
	float in it -- a grep over the raw file would match that sentence and pass for the wrong
	reason. What is searched is every executable line.
	"""
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/save_section_inventories.gd")
	assert_true(source.length() > 0, "the section source was read")
	var code: String = ""
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	assert_true(code.contains("PackedInt64Array"), "the stripped code still holds real code")
	for token: String in ["float", "randf", "PackedFloat", "is_equal_approx"]:
		assert_false(code.contains(token), "the code contains no '%s'" % token)
