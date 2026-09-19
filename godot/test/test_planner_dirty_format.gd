extends "res://test/framework/test_case.gd"
## SAVE-J2-R01: exact pending work is future-affecting state, including its LIFO order.
const Planner := preload("res://scripts/core/job_planner.gd")
const Section := preload("res://scripts/core/save_section_job_indexes.gd")


func _encode(record: Section.Record) -> PackedByteArray:
	"""Serialize a valid record through the production codec."""
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(record, out), "valid record encodes")
	return out.bytes


func _projection(planner: Planner, fields: int) -> PackedByteArray:
	"""Diagnostic private reads only; this is deliberately not a production capture adapter."""
	var bytes: PackedByteArray = PackedByteArray()
	for ordinal: int in fields:
		var value: Variant = planner.get(String(Section.FIELD_KEYS[ordinal]))
		if value is int:
			bytes.append_array(PackedInt32Array([value]).to_byte_array())
		elif value is PackedByteArray:
			bytes.append_array(value)
		else:
			bytes.append_array(value.to_byte_array())
	return bytes


func test_order_and_membership_distinguish_real_future_outcomes() -> void:
	"""The original 29 fields collide while saved dirty order distinguishes different job IDs."""
	var old: Array[PackedByteArray] = []
	var current: Array[PackedByteArray] = []
	var jobs: Array = []
	for order: Array in [[0, 1], [1, 0], []]:
		var planner: Planner = Planner.new()
		for tile: int in [100, 101]:
			var made: Variant = planner.farming().create_plot_at_tile(tile, 0, 1)
			assert_true(made.ok, "create plot")
			assert_true(planner.farming().plant(made.value, 3, 1, 0, 1).ok, "plant")
			assert_true(planner.farming().begin_growing(made.value).ok, "grow")
		for row: int in order:
			assert_true(planner.mark_plot_dirty(row).ok, "mark in specified order")
		old.append(_projection(planner, 29))
		current.append(_projection(planner, 35))
		assert_true(planner.run_tick(600).ok, "run actual planner")
		var ids: Array[int] = []
		for row: int in [0, 1]:
			ids.append(planner.jobs().directory().get_persistent_id(planner.service_job_of(row, 0)))
		jobs.append(ids)
	assert_equal(old[0].size(), 362880, "historical omitted-list projection")
	assert_equal(current[0].size(), 383884, "all 35 declared values")
	assert_equal(old[0], old[1], "old format loses order")
	assert_equal(old[1], old[2], "old format loses membership")
	assert_true(current[0] != current[1], "new format records order")
	assert_true(current[1] != current[2], "new format records membership")
	assert_equal(jobs, [[4, 3], [3, 4], [3, 0]], "distinct real continuation")


func test_pop_clears_tail_without_reordering_or_duplicate_marks() -> void:
	"""All three live queues preserve LIFO and idempotence, then canonicalize each popped cell."""
	for spec: Array in [["mark_plot_dirty", "_pop_dirty", "_dirty_rows", "_dirty_count", "_is_dirty", 4095],
			["mark_zone_dirty", "_pop_dirty_zone", "_dirty_zone_rows", "_dirty_zone_count", "_is_zone_dirty", 127],
			["mark_hive_dirty", "_pop_dirty_hive", "_dirty_hive_rows", "_dirty_hive_count", "_is_hive_dirty", 1023]]:
		var planner: Planner = Planner.new()
		assert_true(planner.call(spec[0], 0).ok, "row zero is valid")
		assert_true(planner.call(spec[0], spec[5]).ok, "highest row is valid")
		assert_true(planner.call(spec[0], 0).ok, "duplicate mark is idempotent")
		assert_equal(planner.get(spec[3]), 2, "duplicate does not append")
		assert_equal(planner.call(spec[1]), spec[5], "LIFO, not sorted order")
		assert_equal(planner.get(spec[2])[1], 0, "popped high cell zeroed")
		assert_equal(planner.get(spec[4])[spec[5]], 0, "membership cleared")
		assert_equal(planner.call(spec[1]), 0, "original row zero remains")
		assert_equal(planner.get(spec[3]), 0, "empty count")
		assert_true(planner.call(spec[0], spec[5]).ok, "remark after pop")
		assert_equal(planner.call(spec[1]), spec[5], "remark can be serviced again")
		assert_equal(planner.get(spec[2])[0], 0, "empty tail canonical")


func test_full_queues_and_row_zero_round_trip() -> void:
	"""Maximum unique prefixes include row zero; no living entity is required by this local codec."""
	var record: Section.Record = Section.Record.new()
	for spec: Array in [[29, 30, 4096], [31, 32, 128], [33, 34, 1024]]:
		record.set_value(spec[1], 0, spec[2])
		for row: int in spec[2]:
			record.set_value(spec[0], row, spec[2] - 1 - row)
	var bytes: PackedByteArray = _encode(record)
	assert_equal(bytes.size(), 384203, "current exact extent")
	var restored: Section.Record = Section.Record.new()
	assert_true(Section.decode_section_with_schema_into(bytes, 0, 2, restored).is_ok(), "current descriptor accepted")
	assert_true(restored.equals(record), "exact unsorted prefixes retained")
	assert_equal(_encode(restored), bytes, "all bytes retained")


func test_malformed_dirty_fields_refuse_atomically() -> void:
	"""Corrupt raw bytes after encoding, so malformed cases cannot be filtered out by the writer."""
	for spec: Array in [[29, 30, 4096], [31, 32, 128], [33, 34, 1024]]:
		for bad: Array in [[spec[1], 0, -1, "SAVE_JOB_NEGATIVE_VALUE"],
				[spec[1], 0, spec[2] + 1, "SAVE_JOB_DIRTY_COUNT"],
				[spec[0], 0, -1, "SAVE_JOB_NEGATIVE_VALUE"],
				[spec[0], 0, spec[2], "SAVE_JOB_DIRTY_INDEX"],
				[spec[0], 1, 1, "SAVE_JOB_DIRTY_DUPLICATE"],
				[spec[0], 2, 1, "SAVE_JOB_DIRTY_TAIL"]]:
			var record: Section.Record = Section.Record.new()
			record.set_value(spec[1], 0, 2)
			record.set_value(spec[0], 0, 1)
			record.set_value(spec[0], 1, 0)
			var bytes: PackedByteArray = _encode(record)
			bytes.encode_s32(Section.field_value_offset(bad[0]) + bad[1] * 4, bad[2])
			var input_before: PackedByteArray = bytes.duplicate()
			var out: Section.Record = Section.Record.new()
			out.set_value(30, 0, 1)
			out.set_value(29, 0, 7)
			var before: PackedByteArray = _encode(out)
			assert_equal(String(Section.decode_section_with_schema_into(bytes, 0, 2, out).code),
				bad[3], "specific malformed queue refusal")
			assert_equal(_encode(out), before, "no partial publication")
			assert_equal(bytes, input_before, "input unchanged")


func test_previous_valid_extent_gets_schema_refusal_before_truncation() -> void:
	"""The original 29 fields and framing form a real schema-1 empty record, shorter than v2."""
	var bytes: PackedByteArray = _encode(Section.Record.new()).slice(0, 363151)
	bytes.encode_u32(19, 1)
	bytes.encode_u64(31, 363112)
	var out: Section.Record = Section.Record.new()
	out.set_value(30, 0, 1)
	out.set_value(29, 0, 19)
	var before: PackedByteArray = _encode(out)
	for schema: int in [1, 2]:
		assert_equal(String(Section.decode_section_with_schema_into(bytes, 0, schema, out).code),
			"SAVE_JOB_OWNER_SCHEMA_VERSION", "owner version has precedence over extent and descriptor")
	assert_equal(_encode(out), before, "old data did not publish")


func test_preamble_schema_precedence_and_offsets() -> void:
	"""A readable 23-byte preamble refuses unsupported schemas before touching the absent body."""
	var current: PackedByteArray = _encode(Section.Record.new())
	var out: Section.Record = Section.Record.new()
	for owner: int in [0, 1, 3]:
		var preamble: PackedByteArray = current.slice(0, 23)
		preamble.encode_u32(19, owner)
		assert_equal(String(Section.decode_section_with_schema_into(preamble, 0, 1, out).code),
			"SAVE_JOB_OWNER_SCHEMA_VERSION", "owner first")
	for descriptor: int in [0, 1, 3]:
		assert_equal(String(Section.decode_section_with_schema_into(current.slice(0, 23), 0, descriptor, out).code),
			"SAVE_JOB_SECTION_SCHEMA_VERSION", "actual descriptor refused before body extent")
	assert_equal(String(Section.decode_section_with_schema_into(current.slice(0, 22), 0, 1, out).code),
		"SAVE_JOB_TRUNCATED", "incomplete preamble first")
	assert_equal(String(Section.decode_section_with_schema_into(current, -1, 1, out).code),
		"SAVE_JOB_NEGATIVE_OFFSET", "negative offset first")
	var offset_bytes: PackedByteArray = PackedByteArray([7, 8, 9])
	offset_bytes.append_array(current)
	assert_true(Section.decode_section_with_schema_into(offset_bytes, 3, 2, out).is_ok(), "nonzero section offset")


func test_appended_wire_offsets_are_literal_independent_pins() -> void:
	"""Pin new count words and scalar values after the unchanged original29-field payload."""
	var record: Section.Record = Section.Record.new()
	for spec: Array in [[29, 30, 7], [31, 32, 19], [33, 34, 91]]:
		record.set_value(spec[0], 0, spec[2])
		record.set_value(spec[1], 0, 1)
	var bytes: PackedByteArray = _encode(record)
	assert_equal(bytes.slice(363151, 363163).hex_encode(), "001000000000000007000000", "farm extent4096 and row7")
	assert_equal(bytes.slice(379543, 379555).hex_encode(), "010000000000000001000000", "farm scalar extent1 and count1")
	assert_equal(bytes.slice(379555, 379567).hex_encode(), "800000000000000013000000", "zone extent128 and row19")
	assert_equal(bytes.slice(380075, 380087).hex_encode(), "010000000000000001000000", "zone scalar extent1 and count1")
	assert_equal(bytes.slice(380087, 380099).hex_encode(), "00040000000000005b000000", "hive extent1024 and row91")
	assert_equal(bytes.slice(384191, 384203).hex_encode(), "010000000000000001000000", "hive scalar extent1 and count1")


func test_invalid_dirty_state_cannot_emit_section_payload_or_canonical_values() -> void:
	"""Every public emission path validates queues; refusal clears previously successful bytes."""
	var record: Section.Record = Section.Record.new()
	record.set_value(34, 0, 2)
	record.set_value(33, 0, 17)
	record.set_value(33, 1, 17)
	var before: Section.Record = Section.Record.new()
	before.copy_from(record)
	var out: Section.EncodeResult = Section.EncodeResult.new()
	out.succeed(PackedByteArray([1, 2, 3]))
	assert_false(Section.encode_section(record, out), "duplicate cannot emit section")
	assert_equal(String(out.refusal), "SAVE_JOB_DIRTY_DUPLICATE", "specific refusal")
	assert_equal(out.bytes.size(), 0, "no stale successful output")
	out.succeed(PackedByteArray([4]))
	assert_false(Section.encode_payload(record, out), "duplicate cannot emit payload")
	assert_equal(out.bytes.size(), 0, "no stale payload")
	out.succeed(PackedByteArray([5]))
	assert_false(Section.canonical_bytes_of(record, out), "duplicate cannot emit canonical values")
	assert_equal(out.bytes.size(), 0, "no stale canonical values")
	assert_true(record.equals(before), "validation never repairs the caller's record")
