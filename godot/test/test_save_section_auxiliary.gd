extends "res://test/framework/test_case.gd"
## Suite for `save_section_auxiliary.gd` and its generated table (ADR 1222 step 4a).
##
## The table is compared against the registry JSON read here (never by production code); the
## codec is exercised through empty and non-empty round trips, every SAVE_S6_* refusal with `out`
## proved untouched, DEC-055 Q9's UnsupportedAdapter and the validate-all-then-apply order.

const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"

const ECOLOGY: int = 3
const EXCAVATION_INVENTORY: int = 4
const EXCAVATION_SITES: int = 5
const INVENTORY: int = 7
const ROOM_LAYOUT: int = 9
const SPOIL_TIPS: int = 11
const ENTRY_PROGRESS: int = 12


class Recorder:
	"""A test adapter that appends every call to a shared log and can refuse validation."""
	var _name: String = ""
	var _log: Array = []
	var _refuse_validate: bool = false

	func _init(p_name: String, p_log: Array, p_refuse_validate: bool) -> void:
		"""Name, shared log and whether validate() refuses."""
		_name = p_name
		_log = p_log
		_refuse_validate = p_refuse_validate

	func capture(_block: Section.Block) -> SaveHeader.Refusal:
		"""Leave the canonical empty block."""
		_log.append("capture:" + _name)
		return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")

	func validate(_block: Section.Block) -> SaveHeader.Refusal:
		"""Accept, or refuse with a test code."""
		_log.append("validate:" + _name)
		if _refuse_validate:
			return SaveHeader.Refusal.new(&"TEST_REFUSED", _name)
		return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")

	func apply(_block: Section.Block) -> SaveHeader.Refusal:
		"""Record the application."""
		_log.append("apply:" + _name)
		return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")


func _encode(state: Section.State) -> PackedByteArray:
	"""Encode `state`, asserting success."""
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(state, out), "encode: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _marked_state() -> Section.State:
	"""A State distinguishable from the empty one, used as a decode target that must not change."""
	var state: Section.State = Section.State.new()
	assert_true(state.block(ECOLOGY).set_scalar(0, 77).is_ok(), "mark ecology._last_day")
	return state


func _assert_refused(bytes: PackedByteArray, offset: int, length: int, code: StringName,
		what: String) -> void:
	"""Decode must refuse with exactly `code` and leave the marked target byte-identical."""
	var target: Section.State = _marked_state()
	var refusal: SaveHeader.Refusal = Section.decode_section(bytes, offset, length, target)
	assert_equal(refusal.code, code, "%s: %s" % [what, refusal.detail])
	assert_true(target.equals(_marked_state()), "%s leaves `out` untouched" % what)


func _block_offset(owner: int) -> int:
	"""Section-relative offset of `owner`'s block in the EMPTY section."""
	var at: int = Schema.STORE_COUNT_BYTES
	for previous: int in owner:
		at += Schema.wrapper_bytes_of(previous) + Schema.payload_bytes_at(previous, false)
	return at


func _empty_count_offset(owner: int, ordinal: int) -> int:
	"""Section-relative offset of one field's element count in the EMPTY section."""
	var at: int = _block_offset(owner) + Schema.wrapper_bytes_of(owner)
	for previous: int in ordinal:
		at += Schema.FIELD_COUNT_BYTES + Schema.empty_count_of(owner, previous) \
			* Schema.width_of(owner, previous)
	return at


# --- the generated table ------------------------------------------------------------------------

func test_generated_table_matches_the_registry_json() -> void:
	"""Owner order, schemas, field keys, type codes and ordinals equal the registry's section 6."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	assert_false(text.is_empty(), "the registry is readable")
	var registry: Dictionary = JSON.parse_string(text) as Dictionary
	var owner: int = 0
	for raw: Variant in registry["owners"] as Array:
		var row: Dictionary = raw as Dictionary
		if int(row["section_id"]) != 6:
			continue
		assert_equal(Schema.OWNER_KEYS[owner], String(row["owner_key"]), "owner %d key" % owner)
		assert_equal(Schema.OWNER_SCHEMAS[owner], int(row["owner_schema_version"]), "schema")
		var fields: Array = row["fields"] as Array
		assert_equal(Schema.field_count_of(owner), fields.size(), "%d field count" % owner)
		for ordinal: int in fields.size():
			var field: Dictionary = fields[ordinal] as Dictionary
			assert_equal(Schema.field_key_of(owner, ordinal), String(field["field_key"]), "key")
			assert_equal(Schema.field_type_of(owner, ordinal), int(field["type_code"]), "type")
			assert_equal(int(field["ordinal"]), ordinal, "ordinal")
		owner += 1
	assert_equal(owner, Schema.OWNER_COUNT, "thirteen section-6 owners")
	assert_equal(Schema.SECTION_SCHEMA_VERSION, int((registry["section_schema_versions"] as Array)[5]),
		"section schema")


func test_table_rules_and_pinned_lengths() -> void:
	"""The compiled table is coherent and its rules are the proved ones; unproved stays zero-only."""
	assert_true(Schema.table_refusal().is_ok(), "table_refusal accepts the compiled table")
	assert_equal(Schema.EMPTY_SECTION_BYTES, 4471529, "the empty section length")
	assert_equal(Schema.MAX_SECTION_BYTES, 16428145, "the maximum section length")
	assert_equal(Schema.rule_kind_of(0, 0), Schema.RULE_FIXED, "buildings._r_spatial_kind FIXED")
	assert_equal(Schema.rule_value_of(0, 0), 16384, "at ROOM_CAPACITY")
	assert_equal(Schema.rule_kind_of(ECOLOGY, 0), Schema.RULE_SCALAR, "ecology._last_day")
	assert_equal(Schema.rule_value_of(EXCAVATION_INVENTORY, 2), 32768, "_free max_count")
	assert_equal(Schema.rule_kind_of(ROOM_LAYOUT, 3), Schema.RULE_BOUNDED, "_room_slots bounded")
	assert_equal(Schema.rule_value_of(EXCAVATION_SITES, 27), 369545, "_earned_mwu bound")
	assert_equal(Schema.rule_value_of(ENTRY_PROGRESS, 1), 2559, "progress_record max_count")
	assert_equal(Schema.rule_kind_of(INVENTORY, 3), Schema.RULE_UNPROVED, "no proved bound")
	assert_equal(Schema.UNPROVED_FIELDS.size(), 19, "5 inventory + 14 spoil_tips fields")
	assert_false(Schema.count_admissible(SPOIL_TIPS, 6, 1), "an unproved field admits no element")


# --- round trips --------------------------------------------------------------------------------

func test_empty_state_round_trips_to_identical_bytes() -> void:
	"""State.new() encodes to EMPTY_SECTION_BYTES and decodes back to the same bytes."""
	var bytes: PackedByteArray = _encode(Section.State.new())
	assert_equal(bytes.size(), Schema.EMPTY_SECTION_BYTES, "empty section length")
	assert_equal(bytes.decode_u32(0), 13, "store_count")
	var decoded: Section.State = _marked_state()
	var refusal: SaveHeader.Refusal = Section.decode_section(bytes, 0, bytes.size(), decoded)
	assert_true(refusal.is_ok(), "decode: %s %s" % [refusal.code, refusal.detail])
	assert_true(decoded.equals(Section.State.new()), "decoded state is the canonical empty one")
	assert_equal(_encode(decoded), bytes, "re-encoding is byte-identical")


func _filled_state() -> Section.State:
	"""A state with scalars and bounded columns of every column type set through the setters."""
	var state: Section.State = Section.State.new()
	var layout: Section.Block = state.block(ROOM_LAYOUT)
	assert_true(layout.set_scalar(0, 2).is_ok(), "_room_capacity")
	assert_true(layout.set_i32_column(3, PackedInt32Array([5, -6])).is_ok(), "_room_slots")
	assert_true(layout.set_u8_column(6, PackedByteArray([1, 255])).is_ok(), "_room_modes")
	var sites: Section.Block = state.block(EXCAVATION_SITES)
	assert_true(sites.set_i64_column(20, PackedInt64Array([1 << 40, -3])).is_ok(), "_site_key")
	assert_true(sites.set_scalar(2, -(1 << 50)).is_ok(), "_domain_capacity i64 scalar")
	var entry: Section.Block = state.block(ENTRY_PROGRESS)
	assert_true(entry.set_scalar(0, 4000000000).is_ok(), "progress_length u32")
	assert_true(entry.set_u8_column(1, PackedByteArray([9, 8, 7])).is_ok(), "progress_record")
	return state


func test_non_empty_blocks_round_trip_through_the_setters() -> void:
	"""Every set value survives encode -> decode -> encode, and the primary counts follow."""
	var state: Section.State = _filled_state()
	var bytes: PackedByteArray = _encode(state)
	assert_equal(bytes.size(), Schema.EMPTY_SECTION_BYTES + 8 + 2 + 16 + 3, "added value bytes")
	var decoded: Section.State = Section.State.new()
	assert_true(Section.decode_section(bytes, 0, bytes.size(), decoded).is_ok(), "decodes")
	assert_true(decoded.equals(state), "decoded equals the source")
	assert_equal(_encode(decoded), bytes, "byte-identical re-encode")
	assert_equal(decoded.block(ROOM_LAYOUT).i32_column(3), PackedInt32Array([5, -6]), "i32 back")
	assert_equal(decoded.block(ROOM_LAYOUT).u8_column(6), PackedByteArray([1, 255]), "u8 back")
	assert_equal(decoded.block(EXCAVATION_SITES).i64_column(20), PackedInt64Array([1 << 40, -3]),
		"i64 back")
	assert_equal(decoded.block(EXCAVATION_SITES).scalar(2), -(1 << 50), "i64 scalar back")
	assert_equal(decoded.block(ENTRY_PROGRESS).scalar(0), 4000000000, "u32 scalar back")
	assert_equal(decoded.block(ROOM_LAYOUT).primary_count(), 2, "first non-scalar count")
	assert_equal(decoded.block(ECOLOGY).primary_count(), 1, "all-scalar owner")


func test_setters_refuse_wrong_types_counts_and_ranges_and_copy() -> void:
	"""Setters check type, rule and range; getters and setters never share a buffer."""
	var block: Section.Block = Section.State.new().block(ROOM_LAYOUT)
	assert_equal(block.set_i32_column(6, PackedInt32Array([1])).code, Section.REFUSE_FIELD_TYPE,
		"i32 into a u8 field")
	var over: PackedInt32Array = PackedInt32Array()
	over.resize(16385)
	assert_equal(block.set_i32_column(3, over).code, Section.REFUSE_ELEMENT_COUNT, "over bound")
	assert_equal(block.set_scalar(3, 1).code, Section.REFUSE_FIELD_TYPE, "scalar into a column")
	assert_equal(block.set_scalar(99, 1).code, Section.REFUSE_FIELD, "undeclared ordinal")
	assert_equal(block.set_scalar(0, 1 << 31).code, Section.REFUSE_VALUE_RANGE, "i32 overflow")
	var fixed: Section.Block = Section.State.new().block(0)
	assert_equal(fixed.set_u8_column(0, PackedByteArray([1])).code, Section.REFUSE_ELEMENT_COUNT,
		"FIXED(16384) refuses one element")
	var tips: Section.Block = Section.State.new().block(SPOIL_TIPS)
	assert_equal(tips.set_u8_column(6, PackedByteArray([1])).code, Section.REFUSE_ELEMENT_COUNT,
		"UNPROVED refuses any element")
	var source: PackedByteArray = PackedByteArray([4, 5])
	assert_true(block.set_u8_column(6, source).is_ok(), "u8 column installs")
	source[0] = 99
	var copy: PackedByteArray = block.u8_column(6)
	copy[1] = 99
	assert_equal(block.u8_column(6), PackedByteArray([4, 5]), "no shared buffer either way")


# --- refusals -----------------------------------------------------------------------------------

func test_extent_refusals_leave_out_untouched() -> void:
	"""NEGATIVE_OFFSET, SECTION_LENGTH both ways, TRUNCATED buffer, and the host order proof."""
	var bytes: PackedByteArray = _encode(Section.State.new())
	_assert_refused(bytes, -1, bytes.size(), Section.REFUSE_NEGATIVE_OFFSET, "negative offset")
	_assert_refused(bytes, 0, bytes.size() - 1, Section.REFUSE_SECTION_LENGTH, "below empty")
	_assert_refused(bytes, 0, Schema.MAX_SECTION_BYTES + 1, Section.REFUSE_SECTION_LENGTH,
		"above maximum")
	_assert_refused(bytes, 1, bytes.size(), Section.REFUSE_TRUNCATED, "buffer too short")
	assert_true(Section.little_endian_refusal().is_ok(), "this host is little-endian")
	assert_equal(Section.REFUSE_ENDIANNESS, &"SAVE_S6_ENDIANNESS", "the endianness code")


func test_wrapper_refusals_leave_out_untouched() -> void:
	"""STORE_COUNT, OWNER_KEY, OWNER_SCHEMA, PRIMARY_COUNT and PAYLOAD_LENGTH, exact codes."""
	var empty: PackedByteArray = _encode(Section.State.new())
	var bytes: PackedByteArray = empty.duplicate()
	bytes.encode_u32(0, 12)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_STORE_COUNT, "store_count 12")
	var key_at: int = _block_offset(1) + 4
	bytes = empty.duplicate()
	bytes[key_at] = 0x64
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_OWNER_KEY, "wrong key byte")
	var head: int = _block_offset(ECOLOGY) + 4 + "ecology".length()
	bytes = empty.duplicate()
	bytes.encode_u32(head, 2)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_OWNER_SCHEMA, "schema 2")
	bytes = empty.duplicate()
	bytes.encode_u64(head + 4, 2)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_PRIMARY_COUNT, "primary 2")
	bytes = empty.duplicate()
	bytes.encode_u64(head + 12, 13)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_PAYLOAD_LENGTH, "payload above max")
	bytes = empty.duplicate()
	bytes.encode_u64(head + 12, 11)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_PAYLOAD_LENGTH, "payload too short")


func test_count_and_tiling_refusals_leave_out_untouched() -> void:
	"""ELEMENT_COUNT (wrong FIXED, high-bit u64), in-section TRUNCATED and NOT_TILED."""
	var empty: PackedByteArray = _encode(Section.State.new())
	var bytes: PackedByteArray = empty.duplicate()
	bytes.encode_u64(_empty_count_offset(0, 0), 16383)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_ELEMENT_COUNT, "FIXED 16383")
	bytes = empty.duplicate()
	bytes.encode_s64(_empty_count_offset(ROOM_LAYOUT, 3), -1)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_ELEMENT_COUNT, "u64 with the top bit")
	bytes = empty.duplicate()
	bytes.encode_u64(_empty_count_offset(SPOIL_TIPS, 6), 1)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_ELEMENT_COUNT, "unproved field")
	var filled: PackedByteArray = _encode(_filled_state())
	_assert_refused(filled, 0, filled.size() - 1, Section.REFUSE_TRUNCATED, "last payload cut")
	bytes = empty.duplicate()
	bytes.append_array(PackedByteArray([0, 0, 0, 0]))
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_NOT_TILED, "four trailing bytes")


func test_encode_refuses_a_malformed_block_with_no_bytes() -> void:
	"""A block whose public members were broken by hand cannot be encoded."""
	var state: Section.State = Section.State.new()
	state.block(ECOLOGY).values[0] = PackedByteArray([1])
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_false(Section.encode_section(state, out), "refused")
	assert_equal(out.refusal, Section.REFUSE_ELEMENT_COUNT, "shape refusal")
	assert_equal(out.bytes.size(), 0, "no bytes")


# --- adapters -----------------------------------------------------------------------------------

func _adapters(holds: int, calls: Array, refuse_owner: int) -> Section.Adapters:
	"""UnsupportedAdapters everywhere (owner `holds` reports state) plus Recorders at 2 and 12."""
	var adapters: Section.Adapters = Section.Adapters.new()
	for owner: int in Schema.OWNER_COUNT:
		var adapter: Object = Section.UnsupportedAdapter.new(owner, func() -> bool:
			return owner == holds)
		if owner == 2 or owner == ENTRY_PROGRESS:
			adapter = Recorder.new(Schema.OWNER_KEYS[owner], calls, owner == refuse_owner)
		assert_true(adapters.register(owner, adapter).is_ok(), "register %d" % owner)
	return adapters


func test_unsupported_adapter_captures_empty_or_refuses_and_validates_empty_only() -> void:
	"""DEC-055 Q9: empty owners capture the canonical block; a holding owner is named."""
	var calls: Array = []
	var out: Section.State = _marked_state()
	var refusal: SaveHeader.Refusal = Section.capture_into(_adapters(-1, calls, -1), out)
	assert_true(refusal.is_ok(), "capture: %s %s" % [refusal.code, refusal.detail])
	assert_true(out.equals(Section.State.new()), "every block is canonical empty")
	out = _marked_state()
	refusal = Section.capture_into(_adapters(INVENTORY, calls, -1), out)
	assert_equal(refusal.code, Section.REFUSE_UNSUPPORTED_STATE, "holding owner refuses")
	assert_true(refusal.detail.contains("inventory"), "and is named: %s" % refusal.detail)
	assert_true(out.equals(_marked_state()), "a refused capture leaves `out` untouched")
	var adapter: Section.UnsupportedAdapter = Section.UnsupportedAdapter.new(ECOLOGY,
		func() -> bool: return false)
	assert_true(adapter.validate(Section.State.new().block(ECOLOGY)).is_ok(), "empty validates")
	assert_equal(adapter.validate(_marked_state().block(ECOLOGY)).code,
		Section.REFUSE_UNSUPPORTED_STATE, "non-empty block refuses")
	assert_true(adapter.apply(_marked_state().block(ECOLOGY)).is_ok(), "apply does nothing")
	var broken: Section.UnsupportedAdapter = Section.UnsupportedAdapter.new(ECOLOGY, Callable())
	assert_equal(broken.capture(Section.State.new().block(ECOLOGY)).code,
		Section.REFUSE_UNSUPPORTED_STATE, "an invalid probe fails closed")


func test_apply_validates_every_owner_before_applying_any() -> void:
	"""A refusal at the LAST owner means no apply ran; otherwise validate-all then apply in order."""
	var calls: Array = []
	var refusal: SaveHeader.Refusal = Section.apply_section(Section.State.new(),
		_adapters(-1, calls, ENTRY_PROGRESS))
	assert_equal(refusal.code, &"TEST_REFUSED", "the last owner's refusal surfaces")
	assert_equal(calls, ["validate:crop_weather", "validate:underground_entry_progress"],
		"both validated, nothing applied")
	calls.clear()
	refusal = Section.apply_section(Section.State.new(), _adapters(-1, calls, -1))
	assert_true(refusal.is_ok(), "apply: %s %s" % [refusal.code, refusal.detail])
	assert_equal(calls, ["validate:crop_weather", "validate:underground_entry_progress",
		"apply:crop_weather", "apply:underground_entry_progress"], "validate all, then apply")


func test_missing_adapter_and_bad_interface_refuse() -> void:
	"""SAVE_S6_ADAPTER_MISSING before any owner is called; a non-adapter cannot register."""
	var adapters: Section.Adapters = Section.Adapters.new()
	var calls: Array = []
	assert_true(adapters.register(2, Recorder.new("a", calls, false)).is_ok(), "one adapter")
	assert_equal(Section.validate_section(Section.State.new(), adapters).code,
		Section.REFUSE_ADAPTER_MISSING, "twelve missing")
	assert_equal(Section.capture_into(adapters, Section.State.new()).code,
		Section.REFUSE_ADAPTER_MISSING, "capture refuses too")
	assert_equal(calls.size(), 0, "no adapter was called")
	assert_equal(adapters.register(3, RefCounted.new()).code, Section.REFUSE_ADAPTER_INTERFACE,
		"no capture/validate/apply")
	assert_equal(adapters.register(2, Recorder.new("b", calls, false)).code,
		Section.REFUSE_ADAPTER_INTERFACE, "a repeat")


# --- canonical hash adapters --------------------------------------------------------------------

func test_register_adapters_covers_every_section_six_owner() -> void:
	"""All thirteen §6 owners register on the production walker and supply typed columns."""
	var walker: Digest.Walker = Digest.production_walker()
	var state: Section.State = _filled_state()
	var refusal: Digest.Refusal = Section.register_adapters(walker, state)
	assert_true(refusal.is_ok(), "register_adapters: %s %s" % [refusal.code, refusal.detail])
	for entry: String in walker.missing_adapter_owners():
		assert_false(entry.begins_with("6:"), "no §6 owner left unregistered: %s" % entry)
	var values: Digest.FieldValues = Digest.FieldValues.new()
	var adapter: Section.Adapter = Section.Adapter.new(state, ENTRY_PROGRESS)
	assert_true(adapter.canonical_field_values(&"progress_length", values), "u32 scalar")
	assert_equal(values.int64s, PackedInt64Array([4000000000]), "as its logical int64 value")
	assert_true(adapter.canonical_field_values(&"progress_record", values), "u8 column")
	assert_equal(values.count, 3, "at its element count")
	assert_false(adapter.canonical_field_values(&"_nope", values), "unknown field")
	assert_equal(values.refusal, Section.REFUSE_FIELD, "refused by name")
