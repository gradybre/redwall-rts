extends "res://test/framework/test_case.gd"
## SAVE-J2-R02 independent owner continuation and codec-boundary tests.
const Planner := preload("res://scripts/core/job_planner.gd")
const Schema := preload("res://scripts/core/job_index_schema.gd")
const Section := preload("res://scripts/core/save_section_job_indexes.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")

var _planner: Planner
var _record: Schema.Record
var _clock: Clock


func before_each() -> void:
	"""Construct one consistent world; restored planner instances borrow its existing owners."""
	_planner = Planner.new()
	_record = Schema.Record.new()
	_clock = Clock.new()
	assert_true(_clock.acquire_load_barrier().is_ok(), "test load barrier")


func _growing(planner: Planner, tile: int = 100) -> int:
	"""A real growable plot with unserved daily demand."""
	var created = planner.farming().create_plot_at_tile(tile, 0, 1)
	assert_true(created.ok, "plot created")
	assert_true(planner.farming().plant(created.value, 3, 1, 0, 1).ok, "grain planted")
	assert_true(planner.farming().begin_growing(created.value).ok, "growing")
	return created.value


func _bytes(record: Schema.Record) -> PackedByteArray:
	"""All caller values and group shapes, including invalid ones, without running a validator."""
	return var_to_bytes([record.u8_columns, record.i32_columns, record.i64_columns])


func _fields(object: Object) -> PackedByteArray:
	"""Probe-only reflection of values, excluding borrowed object identity cycles."""
	var result: PackedByteArray = PackedByteArray()
	for field: Dictionary in object.get_property_list():
		if (int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var value: Variant = object.get(field.name)
		if not value is Object:
			result.append_array(var_to_bytes(value))
	return result


func _collaborators() -> PackedByteArray:
	"""Actual source owners must not change during capture/restore/refusal."""
	var result: PackedByteArray = PackedByteArray()
	for owner: Object in [_planner.directory(), _planner.jobs(), _planner.farming(),
			_planner.forage(), _planner.hives(), _planner.get("_math"), _planner.get("_calendar")]:
		result.append_array(_fields(owner))
	return result


func _refuses_restore(code: StringName) -> void:
	"""Refusal leaves all owner, input and borrowed data unchanged."""
	var before: PackedByteArray = _planner.state_bytes()
	var source: PackedByteArray = _bytes(_record)
	var other: PackedByteArray = _collaborators()
	assert_false(_planner.restore_job_index_columns(_record), "restore refuses")
	assert_equal(_planner.last_column_refusal(), code, "exact owner diagnostic")
	assert_equal(_planner.state_bytes(), before, "owner unchanged")
	assert_equal(_bytes(_record), source, "input unchanged")
	assert_equal(_collaborators(), other, "collaborators and scratch unchanged")


func _refuses_capture(code: StringName) -> void:
	"""Source faults must not produce a plausible or partially overwritten record."""
	var before: PackedByteArray = _planner.state_bytes()
	var target: PackedByteArray = _bytes(_record)
	assert_false(_planner.copy_job_index_columns_into(_record), "capture refuses")
	assert_equal(_planner.last_column_refusal(), code, "exact capture diagnostic")
	assert_equal(_bytes(_record), target, "output unchanged")
	assert_equal(_planner.state_bytes(), before, "source unchanged")


func test_empty_copy_and_restore_have_exact_wire_and_payload() -> void:
	"""The actual current format, not a newly self-consistent replacement."""
	assert_true(_planner.copy_job_index_columns_into(_record), "capture empty")
	assert_true(_record.equals(Schema.Record.new()), "exact empty record")
	var encoded: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record, encoded), "encode")
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(encoded.bytes)
	assert_equal(hash.finish().hex_encode(),
		"46760dad840a3e5480ae15857964dc342306b4bbe3dcf543ca318c2a69beae9d", "pre-extraction hash")
	assert_equal(encoded.bytes.size(), 384203, "wire unchanged")
	var payload: int = 0
	for field: int in Schema.FIELD_COUNT:
		payload += _record.column_bytes(field).size()
	assert_equal(payload, 383884, "actual record packed payload")
	assert_true(Section.apply(_record, _planner, _clock).is_ok(), "apply empty")


func test_all35_ordinals_match_registry_and_owner_fields() -> void:
	"""Read the committed source-of-truth declaration, including scalar count ordinals."""
	var path: String = ProjectSettings.globalize_path("res://../docs/planning/canonical_state_registry.json")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var owner: Dictionary = {}
	for candidate: Dictionary in registry.owners:
		if candidate.owner_key == "job_planner":
			owner = candidate
	assert_equal(owner.fields.size(), 35, "canonical field census")
	assert_true(_planner.copy_job_index_columns_into(_record), "capture")
	for field: int in 35:
		assert_equal(String(Schema.FIELD_KEYS[field]), owner.fields[field].field_key, "ordinal key")
		assert_equal(Schema.FIELD_TYPES[field], owner.fields[field].type_code, "ordinal type")
		var live: Variant = _planner.get(String(Schema.FIELD_KEYS[field]))
		var bytes: PackedByteArray
		if live is int:
			bytes = PackedInt32Array([live]).to_byte_array()
		elif live is PackedByteArray:
			bytes = live.duplicate()
		else:
			bytes = live.to_byte_array()
		assert_equal(_record.column_bytes(field), bytes, "all owner bytes captured")


func test_group_shape_null_and_extent_errors_refuse_before_indexing() -> void:
	"""Short/long typed groups and column extents are normal refusals, never script errors."""
	assert_false(_planner.copy_job_index_columns_into(null), "null output")
	assert_equal(_planner.last_column_refusal(), &"COLUMN_JOB_INDEX_SHAPE", "shape")
	assert_false(_planner.restore_job_index_columns(null), "null input")
	for group: StringName in [&"u8_columns", &"i32_columns", &"i64_columns"]:
		for delta: int in [-1, 1]:
			_record = Schema.Record.new()
			var columns: Variant = _record.get(group)
			columns.resize(columns.size() + delta)
			_record.set(group, columns)
			_refuses_restore(&"COLUMN_JOB_INDEX_SHAPE")
			_refuses_capture(&"COLUMN_JOB_INDEX_SHAPE")
	_record = Schema.Record.new()
	_record.i32_columns[0] = PackedInt32Array([1])
	_refuses_restore(&"COLUMN_JOB_INDEX_SHAPE")


func test_capture_refuses_native_count_and_derived_inconsistency() -> void:
	"""No native i64 truncation and no silently reconstructed source mismatch."""
	for name: StringName in [&"_dirty_count", &"_dirty_zone_count", &"_dirty_hive_count"]:
		for value: int in [-1, 4294967296]:
			_planner.set(name, value)
			_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
		_planner.set(name, 0)
	for name: StringName in [&"_pending_count", &"_unmet_count", &"_requested_count",
			&"_demand_enabled_count", &"_demand_pending_count", &"_demand_unmet_count",
			&"_hive_pending_count", &"_hive_unmet_count"]:
		_planner.set(name, 1)
		_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
		_planner.set(name, 0)
	for name: StringName in [&"_is_dirty", &"_is_zone_dirty", &"_is_hive_dirty"]:
		_planner.get(name)[0] = 1
		_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
		_planner.get(name)[0] = 2
		_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
		_planner.get(name)[0] = 0


func test_invalid_domain_lists_and_tail_restore_are_atomic() -> void:
	"""The owner must use the same structural rules as the byte decoder."""
	for field: int in [Schema.FIELD_STATUS, Schema.FIELD_DEMAND_STATUS, Schema.FIELD_HIVE_STATUS]:
		_record.set_value(field, 0, 255)
		_refuses_restore(&"COLUMN_JOB_INDEX_RECORD")
		_record.clear()
	for field: int in [Schema.FIELD_DIRTY_ROWS, Schema.FIELD_DIRTY_ZONE_ROWS,
			Schema.FIELD_DIRTY_HIVE_ROWS]:
		_record.set_value(field + 1, 0, 2)
		_refuses_restore(&"COLUMN_JOB_INDEX_RECORD")
		_record.clear()
		_record.set_value(field, 0, 1)
		_refuses_restore(&"COLUMN_JOB_INDEX_RECORD")
		_record.clear()


func test_stale_job_reference_survives_roundtrip_and_reconciles_normally() -> void:
	"""Destroyed jobs are legal pending history, not an invitation for load-time repair."""
	var plot: int = _growing(_planner)
	assert_true(_planner.reconcile_plot(plot, 600).ok, "create service")
	var old: Vector2i = _planner.service_job_of(plot, 0)
	assert_true(_planner.jobs().destroy_job(_planner.directory().get_typed_row(old)).ok, "destroy out of band")
	assert_true(Section.capture_into(_planner, _record).is_ok(), "capture stale reference")
	var encoded: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record, encoded), "encode")
	var decoded: Schema.Record = Schema.Record.new()
	assert_true(Section.decode_section_into(encoded.bytes, 0, decoded).is_ok(), "decode")
	_planner.clear()
	var others: PackedByteArray = _collaborators()
	assert_true(Section.apply(decoded, _planner, _clock).is_ok(), "strict restore")
	assert_equal(_collaborators(), others, "no collaborator mutation")
	assert_equal(_planner.service_job_of(plot, 0), old, "stale bytes preserved")
	assert_equal(_planner.pending_service_count(), 1, "derived pending restored")
	assert_equal(_planner.dropped_on_load_count(), 0, "new observation session reset")
	var after: Schema.Record = Schema.Record.new()
	assert_true(_planner.copy_job_index_columns_into(after), "recapture")
	assert_true(after.equals(_record), "canonical parity")
	assert_true(_planner.reconcile_plot(plot, 600).ok, "normal reconciliation reopens")
	assert_true(_planner.service_job_of(plot, 0) != old, "one new generation")
	assert_equal(_planner.jobs().job_count(), 1, "one replacement job")


func test_resolving_wrong_kind_and_wrong_owner_row_refuse() -> void:
	"""A reference that resolves cannot impersonate another owner or table row."""
	var first: int = _growing(_planner)
	var second: int = _growing(_planner, 101)
	assert_true(_planner.reconcile_plot(first, 600).ok, "first service")
	assert_true(_planner.copy_job_index_columns_into(_record), "capture valid")
	var wrong: Vector2i = _planner.farming().ref_of(second)
	_record.set_value(Schema.FIELD_OWNER_SLOT, first * 2, wrong.x)
	_record.set_value(Schema.FIELD_OWNER_GENERATION, first * 2, wrong.y)
	_refuses_restore(&"COLUMN_JOB_INDEX_REFERENCE")
	assert_true(_planner.copy_job_index_columns_into(_record), "restore valid fixture")
	_record.set_value(Schema.FIELD_JOB_SLOT, first * 2, wrong.x)
	_record.set_value(Schema.FIELD_JOB_GENERATION, first * 2, wrong.y)
	_refuses_restore(&"COLUMN_JOB_INDEX_REFERENCE")


func _next_ids(order: Array[int], restore: bool) -> PackedInt64Array:
	"""Run the same actual two-plot world with or without one exact owner round trip."""
	var planner: Planner = Planner.new()
	_growing(planner, 100)
	_growing(planner, 101)
	for row: int in order:
		assert_true(planner.mark_plot_dirty(row).ok, "mark order")
	if restore:
		var record: Schema.Record = Schema.Record.new()
		assert_true(planner.copy_job_index_columns_into(record), "snapshot dirty order")
		planner.clear()
		assert_true(planner.restore_job_index_columns(record), "restore order")
	assert_true(planner.run_tick(600).ok, "normal tick")
	return PackedInt64Array([planner.directory().get_persistent_id(planner.service_job_of(0, 0)),
		planner.directory().get_persistent_id(planner.service_job_of(1, 0))])


func test_exact_dirty_order_reproduces_future_job_ids_and_empty_membership() -> void:
	"""A restore that marks all owners or sorts the work stack changes these outcomes."""
	assert_equal(_next_ids([0, 1], true), PackedInt64Array([4, 3]), "LIFO order01")
	assert_equal(_next_ids([1, 0], true), PackedInt64Array([3, 4]), "LIFO order10")
	assert_equal(_next_ids([], true), PackedInt64Array([3, 0]), "empty stack only staggered row")
	assert_equal(_next_ids([0, 1], true), _next_ids([0, 1], false), "natural continuation identical")


func test_export_and_restore_are_independent_of_caller_buffers() -> void:
	"""No owner array may alias a caller's saved or received snapshot."""
	assert_true(_planner.mark_plot_dirty(0).ok, "one dirty row")
	assert_true(_planner.copy_job_index_columns_into(_record), "capture")
	var original: PackedByteArray = _planner.state_bytes()
	_record.set_value(Schema.FIELD_DIRTY_ROWS, 0, 1)
	assert_equal(_planner.state_bytes(), original, "export does not alias")
	assert_true(_planner.restore_job_index_columns(_record), "valid changed stack")
	var restored: PackedByteArray = _planner.state_bytes()
	_record.set_value(Schema.FIELD_DIRTY_ROWS, 0, 2)
	assert_equal(_planner.state_bytes(), restored, "restore does not alias")
	assert_true(_planner.is_plot_dirty(1), "membership rebuilt only from saved stack")
	assert_false(_planner.is_plot_dirty(0), "old membership removed")


func test_barrier_and_participant_precedence_preserve_owner() -> void:
	"""Pause/absence cannot substitute for the actual clock's held load barrier."""
	var before: PackedByteArray = _planner.state_bytes()
	var lowered: Clock = Clock.new()
	assert_equal(Section.apply(null, null, lowered).code, &"SAVE_JOB_RECORD_SHAPE", "null record first")
	assert_equal(Section.apply(_record, null, lowered).code, &"SAVE_JOB_NULL_STORE", "null store second")
	assert_equal(Section.apply(_record, _planner).code, &"SAVE_JOB_NULL_CLOCK", "clock missing")
	assert_equal(Section.apply(_record, _planner, lowered).code,
		&"SAVE_JOB_BARRIER_NOT_HELD", "actual barrier needed")
	assert_equal(_planner.state_bytes(), before, "no owner changes")
	assert_true(_clock.is_load_barrier_held(), "other clock unaffected")


func test_malformed_codec_targets_and_reused_records_refuse_atomically() -> void:
	"""Public byte decode and staged capture never index a caller's short groups."""
	var encoded: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(_record, encoded), "valid bytes")
	var malformed: Schema.Record = Schema.Record.new()
	malformed.i32_columns.clear()
	var before: PackedByteArray = _bytes(malformed)
	assert_equal(Section.capture_record_into(_record, malformed).code,
		&"SAVE_JOB_RECORD_SHAPE", "capture output malformed")
	assert_equal(Section.decode_section_into(encoded.bytes, 0, malformed).code,
		&"SAVE_JOB_RECORD_SHAPE", "decode output malformed")
	assert_equal(_bytes(malformed), before, "output unchanged")
	assert_equal(Section.decode_section_into(encoded.bytes, 0, null).code,
		&"SAVE_JOB_RECORD_SHAPE", "decode null target")


func _real_forage() -> int:
	"""Create real basin patches and an enabled player designation with one harvest claim."""
	var basin = _planner.forage().create_zone(2, 0, 0, false, true)
	assert_true(basin.ok, "basin")
	assert_true(_planner.forage().create_patch_set(basin.ref,
		PackedInt32Array([10, 11, 12, 13, 14])).ok, "patches")
	var zone = _planner.forage().create_zone(2, 0, 0, false, true)
	assert_true(zone.ok, "designation")
	assert_true(_planner.forage().set_basin(zone.ref, basin.ref).ok, "basin bound")
	assert_true(_planner.enable_forage_demand(zone.ref).ok, "enabled")
	var row: int = _planner.forage().zone_slot_of(zone.ref).value
	assert_true(_planner.reconcile_forage_kind(row, 2, 600).ok, "mushroom harvest")
	return row


func _real_hive(x: int) -> int:
	"""An actual hive under a directory-owned building, matching existing owner fixtures."""
	var building: Vector2i = _planner.directory().create(Directory.KIND_BUILDING)
	var hive = _planner.hives().create_hive(building, x, 10, x, 10, 1)
	assert_true(hive.ok, "hive")
	return hive.value


func test_mixed_actual_owners_restore_counters_claims_and_diagnostic_reset() -> void:
	"""Actual farm/sow/forage/hive state plus valid retained-demand variants cover all8counts."""
	var tended: int = _growing(_planner)
	var unmet: int = _growing(_planner, 101)
	assert_true(_planner.reconcile_plot(tended, 600).ok, "tend")
	var empty = _planner.farming().create_plot_at_tile(102, 0, 1)
	assert_true(empty.ok, "empty plot")
	assert_true(_planner.confirm_first_planting(empty.value, 3).ok, "sowing requested")
	var zone: int = _real_forage()
	var hive: int = _real_hive(10)
	var unmet_hive: int = _real_hive(12)
	assert_true(_planner.reconcile_hive(hive, 13500).ok, "hive keeping")
	assert_true(_planner.copy_job_index_columns_into(_record), "actual mixed capture")
	var saved: Schema.Record = Schema.Record.new()
	saved.copy_from(_record)
	var borrowed: PackedByteArray = _collaborators()
	assert_true(_planner.restore_job_index_columns(_record), "actual mixed restore")
	assert_equal(_collaborators(), borrowed, "claims/work/owners untouched")
	assert_true(_planner.copy_job_index_columns_into(_record), "actual recapture")
	assert_true(_record.equals(saved), "all actual mixed bytes preserved")
	# Valid retained demand records exercise counts without filling all8192Job slots again.
	var plot_ref: Vector2i = _planner.farming().ref_of(unmet)
	_record.set_value(Schema.FIELD_STATUS, unmet * 2, 2)
	_record.set_value(Schema.FIELD_OWNER_SLOT, unmet * 2, plot_ref.x)
	_record.set_value(Schema.FIELD_OWNER_GENERATION, unmet * 2, plot_ref.y)
	_record.set_value(Schema.FIELD_SERVICE_DAY, unmet * 2, 1)
	_record.set_value(Schema.FIELD_DEMAND_STATUS, zone * 5 + 3, 2)
	var hive_ref: Vector2i = _planner.hives().hive_ref_of(unmet_hive)
	_record.set_value(Schema.FIELD_HIVE_STATUS, unmet_hive, 2)
	_record.set_value(Schema.FIELD_HIVE_OWNER_SLOT, unmet_hive, hive_ref.x)
	_record.set_value(Schema.FIELD_HIVE_OWNER_GENERATION, unmet_hive, hive_ref.y)
	_record.set_value(Schema.FIELD_HIVE_SERVICE_DAY, unmet_hive, 2)
	var diagnostics: PackedStringArray = _diagnostic_names()
	assert_equal(diagnostics.size(), 21, "actual reset assignment census")
	for name: String in diagnostics:
		_planner.set(name, &"prior observation" if name == "_last_blocker" else 77)
	assert_true(Schema.record_refusal(_record).is_ok(), "retained demand fixture valid")
	assert_true(_planner.restore_job_index_columns(_record), "restore retained demands")
	for name: String in diagnostics:
		assert_equal(_planner.get(name), &"" if name == "_last_blocker" else 0, "diagnostic reset: " + name)
	for name: StringName in [&"_pending_count", &"_unmet_count", &"_requested_count",
			&"_demand_enabled_count", &"_demand_pending_count", &"_demand_unmet_count",
			&"_hive_pending_count", &"_hive_unmet_count"]:
		assert_equal(_planner.get(name), 1, "derived count: " + String(name))
	assert_equal(_collaborators(), borrowed, "restoring diagnostics never consumes claims")


func _diagnostic_names() -> PackedStringArray:
	"""Read the real reset assignment list, not the new diagnostic-count constant."""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/job_planner.gd")
	var block: String = source.split("func _reset_counters() -> void:")[1].split("\n\n\n")[0]
	var result: PackedStringArray = PackedStringArray()
	for line: String in block.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("_") and trimmed.contains(" = "):
			result.append(trimmed.split(" = ")[0])
	return result


func test_source_short_columns_and_derived_buffers_refuse_safely() -> void:
	"""Parent integration guard: check extents before walking saved-prefix membership."""
	assert_true(_planner.mark_plot_dirty(0).ok, "one saved entry")
	var original: PackedInt32Array = _planner.get("_dirty_rows")
	_planner.set("_dirty_rows", PackedInt32Array())
	_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
	_planner.set("_dirty_rows", original)
	var bits: PackedByteArray = _planner.get("_is_dirty")
	_planner.set("_is_dirty", PackedByteArray())
	_refuses_capture(&"COLUMN_JOB_INDEX_RECORD")
	_refuses_restore(&"COLUMN_JOB_INDEX_RECORD")
	_planner.set("_is_dirty", bits)


func test_capture_rejects_resolving_reference_of_wrong_kind() -> void:
	"""Capture must validate the live owner's references, not only its shape and counts."""
	var plot: int = _growing(_planner)
	assert_true(_planner.reconcile_plot(plot, 600).ok, "pending farm work")
	var hive: int = _real_hive(10)
	var ref: Vector2i = _planner.hives().hive_ref_of(hive)
	var slots: PackedInt32Array = _planner.get("_owner_slot")
	var generations: PackedInt32Array = _planner.get("_owner_generation")
	slots[plot * Planner.OPERATION_COUNT] = ref.x
	generations[plot * Planner.OPERATION_COUNT] = ref.y
	_planner.set("_owner_slot", slots)
	_planner.set("_owner_generation", generations)
	_refuses_capture(&"COLUMN_JOB_INDEX_REFERENCE")


func test_diagnostic_image_covers_every_nonobject_owner_member() -> void:
	"""Independently perturb all reflected value members so omission weakens no atomicity proof."""
	var baseline: PackedByteArray = _planner.state_bytes()
	var covered: int = 0
	for field: Dictionary in _planner.get_property_list():
		if (int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = String(field.name)
		var old: Variant = _planner.get(name)
		if old is Object or name == "_last_column_refusal":
			continue
		var changed: Variant
		if old is int:
			changed = old + 1
		elif old is StringName:
			changed = &"distinct observation"
		elif old is PackedByteArray or old is PackedInt32Array or old is PackedInt64Array:
			changed = old.duplicate()
			changed[0] = old[0] + 1
		else:
			assert_true(false, "new member needs image classification: " + name)
			continue
		_planner.set(name, changed)
		assert_false(_planner.state_bytes() == baseline, "image includes " + name)
		_planner.set(name, old)
		assert_equal(_planner.state_bytes(), baseline, "probe restored " + name)
		covered += 1
	assert_equal(covered, 67, "35canonical +3membership +8derived +21diagnostics")
	_planner.set("_last_column_refusal", &"intentionally excluded")
	assert_equal(_planner.state_bytes(), baseline, "column refusal excluded by contract")


func test_diagnostic_image_framing_order_and_distinct_diagnostics() -> void:
	"""Decode the specified format independently of the owner's append helpers."""
	var diagnostics: PackedStringArray = _diagnostic_names()
	for index: int in diagnostics.size():
		_planner.set(diagnostics[index], &"évidence" if diagnostics[index] == "_last_blocker" else 101 + index)
	# Distinct values make same-width column/counter swaps observable, even in empty fixtures.
	for index: int in Schema.FIELD_KEYS.size():
		var name: StringName = Schema.FIELD_KEYS[index]
		var value: Variant = _planner.get(name)
		if value is int:
			_planner.set(name, 30 + index)
		else:
			var changed: Variant = value.duplicate()
			changed[0] = 30 + index
			_planner.set(name, changed)
	var derived: Array[StringName] = [&"_pending_count", &"_unmet_count", &"_requested_count",
		&"_demand_enabled_count", &"_demand_pending_count", &"_demand_unmet_count",
		&"_hive_pending_count", &"_hive_unmet_count"]
	for index: int in derived.size():
		_planner.set(derived[index], 201 + index)
	var image: PackedByteArray = _planner.state_bytes()
	var offset: int = 0
	var names: Array[StringName] = []
	for name: StringName in Schema.FIELD_KEYS:
		names.append(name)
	names.append_array([&"_is_dirty", &"_is_zone_dirty", &"_is_hive_dirty"])
	for name: StringName in names:
		var value: Variant = _planner.get(name)
		if value is int:
			assert_equal(image.decode_s64(offset), value, "native i64 scalar " + String(name))
			offset += 8
		else:
			assert_equal(image.decode_u32(offset), value.size(), "array element count " + String(name))
			offset += 4
			var raw: PackedByteArray = value if value is PackedByteArray else value.to_byte_array()
			assert_equal(image.slice(offset, offset + raw.size()), raw, "array bytes " + String(name))
			offset += raw.size()
	for name: StringName in [&"_pending_count", &"_unmet_count", &"_requested_count",
			&"_demand_enabled_count", &"_demand_pending_count", &"_demand_unmet_count",
			&"_hive_pending_count", &"_hive_unmet_count"]:
		assert_equal(image.decode_s64(offset), _planner.get(name), "derived order " + String(name))
		offset += 8
	for name: String in diagnostics:
		if name == "_last_blocker":
			var bytes: PackedByteArray = String(_planner.get(name)).to_utf8_buffer()
			assert_equal(image.decode_u32(offset), bytes.size(), "UTF8 byte length")
			offset += 4
			assert_equal(image.slice(offset, offset + bytes.size()), bytes, "UTF8 payload")
			offset += bytes.size()
		else:
			assert_equal(image.decode_s64(offset), _planner.get(name), "diagnostic order " + name)
			offset += 8
	assert_equal(offset, image.size(), "exact full diagnostic consumption")


func test_staged_capture_source_error_precedes_malformed_output() -> void:
	"""A semantic source failure wins over output shape and leaves both records alone."""
	_record.set_value(Schema.FIELD_STATUS, 0, 4)
	var target: Schema.Record = Schema.Record.new()
	target.i32_columns.clear()
	var source_before: PackedByteArray = _bytes(_record)
	var target_before: PackedByteArray = _bytes(target)
	assert_equal(Section.capture_record_into(_record, target).code,
		&"SAVE_JOB_STATUS_DOMAIN", "source semantic error first")
	assert_equal(_bytes(_record), source_before, "source unchanged")
	assert_equal(_bytes(target), target_before, "target unchanged")
