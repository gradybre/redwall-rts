extends "res://test/framework/test_case.gd"
## Real finite owners and adopted bills. The additional set-down program below is explicitly SYNTHETIC.

const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const EntryFixture := preload("res://test/test_underground_entry_world_bindings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SOURCE_PATH: String = "user://workpiece-synthetic-source.bin"
const SAVE_PATH: String = "user://workpiece-capture.bin"
const PROGRAM_SHA: String = "5353535353535353535353535353535353535353535353535353535353535353"
const SET_DOWN_PROFILE: int = 5

class HandlingWorld extends Prefix.ActualWorld:

	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Add a separate test-only set-down program/row; existing fastening rows retain their original IDs."""
		var source: PackedByteArray = Prefix.Source.profile_image(identity)
		_raise_fastening(source)
		var bytes: PackedByteArray = source.slice(0, 64)
		bytes.encode_u32(20, 7); bytes.encode_u32(24, 41); bytes.encode_u32(28, 2)
		bytes.append_array(PROGRAM_SHA.hex_decode())
		bytes.append_array(source.slice(64, 64 + 5 * Profiles.PROFILE_WIRE_BYTES))
		var row: PackedByteArray = source.slice(64 + Profiles.PROFILE_WIRE_BYTES, 64 + 2 * Profiles.PROFILE_WIRE_BYTES)
		row.encode_s32(Profiles.F_SOURCE * 4, 1)
		row.encode_s32(Profiles.F_FIRST_BOX * 4, 31)
		bytes.append_array(row)
		row = source.slice(64 + 5 * Profiles.PROFILE_WIRE_BYTES, 64 + 6 * Profiles.PROFILE_WIRE_BYTES)
		row.encode_s32(Profiles.F_FIRST_BOX * 4, 38)
		bytes.append_array(row)
		var boxes: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		bytes.append_array(source.slice(boxes, boxes + 31 * 28))
		bytes.append_array(source.slice(boxes + 3 * 28, boxes + 10 * 28))
		bytes.append_array(source.slice(boxes + 31 * 28, source.size()))
		return bytes

	func _raise_fastening(source: PackedByteArray) -> void:
		"""Only the synthetic yaw0 INSTALL row changes: its actual raised target is128u above the root plane."""
		var start: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		for role: int in [Profiles.WORK_STROKE, Profiles.CONTACT_POINT, Profiles.CONTACT_PATCH]:
			var bounds: PackedInt32Array = PackedInt32Array([112, 125, -459, 141, 128, -437])
			if role == Profiles.CONTACT_POINT: bounds = PackedInt32Array([128, 128, -448, 128, 128, -448])
			if role == Profiles.CONTACT_PATCH: bounds = PackedInt32Array([127, 128, -449, 129, 128, -447])
			for axis: int in 6: source.encode_s32(start + (3 + role) * 28 + 4 * axis, bounds[axis])

class Fixture extends EntryFixture:

	func _natural_surface() -> void:
		"""The workpiece pocket stays unoccupied; the later near-side transit endpoint is not precreated through it."""
		_anchor = Anchor.new()
		assert_equal(_anchor.configure(_world._world, _world._terrain, _world._owner, _world._sources,
			_world._locations, _world._budget, Anchor.RESERVED_BYTES), &"", "actual natural provider")
		var strips: Array[PackedInt32Array] = [PackedInt32Array([-1792, 0, 192, 1792, 1157, 832]),
			PackedInt32Array([-1792, 0, -3072, -1024, 1157, 192]), PackedInt32Array([1024, 0, -3072, 1792, 1157, 192])]
		var roots: Array[Vector3i] = [Vector3i(-832, 0, 512), Source.side_root(0), Source.side_root(1)]
		_endpoints.resize(9)
		var metadata: PackedInt32Array = Source.world_box(PackedInt32Array([-1792, 0, -3072, 1792, 1, 832]))
		for index: int in strips.size():
			var support: PackedInt32Array = strips[index].duplicate()
			support[1] = -128; support[4] = 0
			var created: Anchor.Result = _anchor.create(ORIGIN + roots[index], Source.world_box(strips[index]),
				Source.world_box(support), Locations.ROLE_WORK, metadata) if index == 0 else \
				_anchor.create_in_section(ORIGIN + roots[index], Source.world_box(strips[index]), Source.world_box(support), _section)
			assert_equal(created.error, &"", "actual natural strip %d" % index)
			_section = created.section
			_endpoints[0 if index == 0 else index + 2] = created.location


	func _make_world() -> Prefix.ActualWorld:
		"""The existing actual World/stock/phase/installation composition consumes the clearly synthetic program."""
		return HandlingWorld.new()

var _fixture: Fixture = null
var _pieces: Workpieces = null


func before_each() -> void:
	"""Bind actual admitted finite sources without creating any Project, paid receipt or obstacle."""
	_fixture = Fixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual setup: %s" % _fixture.failures)
	_pieces = Workpieces.new()
	assert_equal(_pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "complete admitted arena")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "actual source and paid owners")


func after_each() -> void:
	"""No component may retain a synchronous lease or hide a real Inventory/Reservation audit failure."""
	assert_true(_pieces.is_quiescent(), "no escaped workpiece request")
	_pieces = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual cleanup: %s" % _fixture.failures)
	_fixture = null
	for path: String in [SOURCE_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _source_image() -> PackedByteArray:
	"""An independent fixed wire names the reviewed whole bearer prisms and the distinct synthetic program."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Workpieces.WIRE_HEADER_BYTES)
	for index: int in 8: bytes[index] = "UGWIPC01".unicode_at(index)
	bytes.encode_u32(8, 1)
	var header: PackedInt64Array = PackedInt64Array([1, _fixture._world._catalog._live.header[0], 1,
		_fixture._groups._reader._header[0], _fixture._groups._recipes._header[0], 2, 2, 0, 1])
	for index: int in 9: bytes.encode_s64(12 + 8 * index, header[index])
	for index: int in 32:
		bytes[84 + index] = _fixture._world._catalog._live.digests[index]
		bytes[116 + index] = _fixture._groups._reader._digests[index]
		bytes[148 + index] = _fixture._groups._recipes._digests[index]
		bytes[180 + index] = PROGRAM_SHA.hex_decode()[index]
	_append_row(bytes, PackedInt32Array([1, 3, 1024, 192, -768, SET_DOWN_PROFILE]))
	_append_row(bytes, PackedInt32Array([8, 3, 2304, 320, -2816, SET_DOWN_PROFILE]))
	bytes.append_array("UGWEND01".to_ascii_buffer())
	return bytes


func _append_row(bytes: PackedByteArray, row: PackedInt32Array) -> void:
	"""Independent wire encoding writes six int32 source columns followed by exact profile revision."""
	var start: int = bytes.size()
	bytes.resize(start + 32)
	for field: int in 6: bytes.encode_s32(start + 4 * field, row[field])
	bytes.encode_s64(start + 24, 1)


func _load(bytes: PackedByteArray) -> StringName:
	"""Only the actual immutable source decoder can populate template rows."""
	var file: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return _pieces.load_file(SOURCE_PATH, FileAccess.get_sha256(SOURCE_PATH), 1)


func test_complete_finite_arena_and_once_bound_actual_owners() -> void:
	"""The design ceiling is explicit and refusal allocates no variable bank or foreign owner binding."""
	assert_equal(Workpieces.required_bytes(256, 256), 29928, "all rows, source, stream, controls and provisional native reserve")
	var refused: Workpieces = Workpieces.new()
	assert_equal(refused.configure(256, 256, 29927), Workpieces.REFUSE_CAPACITY, "one byte short refuses")
	assert_equal(refused._live.fields.size(), 0, "no private bank on refusal")
	assert_equal(Workpieces.required_bytes(257, 2), 0, "actual Placement maximum is explicit")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), Workpieces.REFUSE_BINDING, "once bound")
	assert_true(_pieces.exact_binding(_fixture._placements, _fixture._router), "actual initialized objects")
	assert_false(_pieces.exact_binding(null, _fixture._router), "equal numeric identities never replace owner")


func test_distinct_set_down_program_and_complete_included_parts_load_once() -> void:
	"""Accepted synthetic content is not a production handling certificate and cannot be replaced in place."""
	assert_equal(_load(_source_image()), &"", "complete actual source closure")
	assert_equal(_pieces._parts[Workpieces.PART * 2], 1, "whole included L0 bearer")
	assert_equal(_pieces._parts[Workpieces.PART * 2 + 1], 8, "whole included T0 bearer")
	assert_equal(_pieces._header[Workpieces.H_PROGRAM], 1, "set-down program is separate from fastening source0")
	assert_equal(_pieces._parts[Workpieces.PROFILE * 2], SET_DOWN_PROFILE, "explicit new profile selection")
	assert_equal(_load(_source_image()), Workpieces.REFUSE_SOURCE, "successful source is immutable")
	assert_equal(_pieces._live.present.count(1), 0, "source loading creates no paid piece")


func test_second_bill_or_missing_actual_part_refuses_without_retained_source() -> void:
	"""A visual prism from the next assembly cannot be charged or owned by the current whole bill."""
	var bytes: PackedByteArray = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES, 8)
	assert_equal(_load(bytes), Workpieces.REFUSE_SOURCE, "cross-group part is not included")
	assert_false(_pieces._loaded, "failed source unpublished")
	assert_equal(_pieces._parts.count(0), _pieces._parts.size(), "failed private rows cleared")
	bytes = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES + 32, 14)
	assert_equal(_load(bytes), Workpieces.REFUSE_SOURCE, "nonexistent part cannot fabricate timber")
	assert_equal(_load(_source_image()), &"", "exact source retry")


func test_fastening_or_stale_profile_cannot_replace_distinct_handling_source() -> void:
	"""Neither an existing INSTALL row nor a same-ID stale revision can grant set-down permission."""
	var bytes: PackedByteArray = _source_image()
	bytes.encode_s32(Workpieces.WIRE_HEADER_BYTES + 20, 1)
	assert_equal(_load(bytes), Workpieces.REFUSE_PROFILE, "actual existing fastening row belongs to another program")
	bytes = _source_image()
	bytes.encode_s64(Workpieces.WIRE_HEADER_BYTES + 24, 2)
	assert_equal(_load(bytes), Workpieces.REFUSE_PROFILE, "exact handling revision required")
	assert_equal(_load(_source_image()), &"", "exact profile source retry")


func test_live_source_drift_and_world_generation_refuse_even_empty_capture() -> void:
	"""Every read checks actual current profiles/source/World, not just a cached successful decoder result."""
	assert_equal(_load(_source_image()), &"", "source loaded")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var profiles: Profiles = _fixture._world._profiles
	profiles._live.header[0] += 1
	assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "current content replacement refuses")
	assert_equal(file.get_position(), 0, "no capture bytes before validation")
	profiles._live.header[0] -= 1
	var original: int = _fixture._world._residents._directory._generation[_fixture._world._world_ref.x]
	_fixture._world._residents._directory._generation[_fixture._world._world_ref.x] += 1
	assert_equal(_pieces.capture_into(file), Workpieces.REFUSE_STAGE, "full World generation required")
	_fixture._world._residents._directory._generation[_fixture._world._world_ref.x] = original
	assert_equal(_pieces.capture_into(file), &"", "exact binding retry")
	file.close()


func test_streamed_empty_restore_preserves_live_bank_on_malformed_full_refs() -> void:
	"""Restore uses the already-admitted spare bank and refuses a fabricated paid row without publication."""
	assert_equal(_load(_source_image()), &"", "source loaded")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_equal(_pieces.capture_into(file), &"", "streamed quiescent capture")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_equal(file.get_length(), 60 + 4 * 21, "exact wire, no full retained image")
	assert_equal(_pieces.restore_from(file), &"", "same complete actual owner composition")
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ_WRITE)
	file.seek(60); file.store_8(1); file.store_32(1)
	file.close()
	file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var old_bank: Workpieces.Bank = _pieces._live
	assert_equal(_pieces.restore_from(file), Workpieces.REFUSE_PROJECT, "full actual paid identities required")
	assert_true(_pieces._live == old_bank, "refused restore never swaps live bank")
	assert_equal(_pieces._live.present.count(1), 0, "no paid obstacle fabricated")
	file.close()


func test_absent_reciprocal_publication_context_cannot_create_paid_workpiece() -> void:
	"""Even a valid source and coincident cold number cannot impersonate actual initialized publication owners."""
	assert_equal(_load(_source_image()), &"", "valid source")
	var out: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
	assert_equal(_pieces.bounds_into(NULL_REF, NULL_REF, out), Workpieces.REFUSE_PROJECT, "no invented future Project")
	assert_equal(out, PackedInt32Array([1, 2, 3, 4, 5, 6]), "refused output unchanged")
	var lease: int = _fixture._world._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_pieces.prepare_start(NULL_REF, NULL_REF, lease), Workpieces.REFUSE_BINDING, "missing reciprocal concrete owners")
	assert_false(Workpieces.publish_start_preflighted(_pieces, NULL_REF), "no public publication permission boolean")
	assert_false(Workpieces.clear_preflighted(_pieces, NULL_REF, Contract.CANCEL), "no foreign cancel tail")
	assert_equal(_fixture._world._budget.release(lease), &"", "original lease still belongs to caller")


func test_adopted_wood_mass_and_payload_handling_are_not_repriced_per_visual_prism() -> void:
	"""Actual bill and item registration establish20kg/5kg assemblies; partial shipment policy remains existing hauling."""
	var quote: Contract.Quote = Contract.Quote.new()
	var groups: RefCounted = _fixture._groups._reader
	var recipes: RefCounted = _fixture._groups._recipes
	var item: int = _fixture._world._items.compiled_id(&"wood")
	assert_equal(_fixture._world._inventory.item_mass_g(item), 5000, "actual adopted wood mass")
	assert_equal(recipes.recipe_into(0, 1, groups._recipe_anchor[0], recipes._header[0], quote), &"", "one L0 assembly bill")
	assert_equal(quote.input_milli[0], 4000, "four wood units, no price for included bearer again")
	assert_equal(quote.input_milli[0] * _fixture._world._inventory.item_mass_g(item), 20000000, "exact grams numerator")
	assert_equal(recipes.recipe_into(0, 1, groups._recipe_anchor[1], recipes._header[0], quote), &"", "one T0 bill")
	assert_equal(quote.input_milli[0], 1000, "one wood unit")
	assert_equal(HaulPlanner.HAUL_LOAD_MILLI_WU, 2000, "actual load policy per payload")
	assert_equal(HaulPlanner.HAUL_UNLOAD_MILLI_WU, 2000, "actual unload policy per payload")


func _ready_l0() -> Vector2i:
	"""All four full cubes finish through real Sites/Funding/Work/companions before one real next-assembly order."""
	assert_equal(_load(_source_image()), &"", "distinct immutable set-down source")
	assert_equal(_fixture._paid.bind_workpieces(_pieces), &"", "actual reciprocal once-bound workpieces")
	var room: Vector2i = _fixture._confirm_prefix()
	if room == NULL_REF or not _fixture.failures.is_empty(): return NULL_REF
	if not _fixture._complete_l0_cubes(): return NULL_REF
	var project: Vector2i = _fixture._open_installation(0)
	assert_true(_fixture.failures.is_empty(), "actual four-cube lifecycle: %s" % _fixture.failures)
	return project


func test_actual_l0_start_publishes_one_paid_raised_non_supporting_workpiece() -> void:
	"""Real paid owners publish the complete included bearer only after full delivery and distinct synthetic handling proof."""
	var project: Vector2i = _ready_l0()
	if project == NULL_REF: return
	var job: int = _fixture._installation_job(project, _fixture._endpoints[0])
	if job < 0: return
	if not _fixture._pay_installation(project, job): return
	var placement: Vector2i = _fixture._world._construction.subject_ref_of(project)
	var region: Vector2i = _pieces.workpiece_region(placement, project)
	assert_true(region != NULL_REF, "one exact live Project-owned obstacle")
	assert_equal(_pieces._live.present.count(1), 1, "no separate quantity or per-part receipt")
	assert_true(_fixture._router._funding.is_funded(project), "actual original Funding receipt")
	assert_equal(_fixture._world._owner._r_role[region.x], Prefix.Space.OBSTACLE, "never support")
	assert_equal(_fixture._world._owner._r_lo_y[region.x], Prefix.ORIGIN.y, "piece bottom on actual floor")
	assert_equal(_fixture._world._owner._r_hi_y[region.x], Prefix.ORIGIN.y + 128, "real raised fastening top")
	assert_equal(_fixture._placements._get32(_fixture._placements._live, Prefix.Placements.INSTALLED, placement.x), 0,
		"START does not install the assembly")
	assert_true(_pieces.is_quiescent() and _fixture._world._budget.is_quiescent(), "original scratch released after publication")
