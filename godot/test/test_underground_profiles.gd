extends "res://test/framework/test_case.gd"
## Synthetic geometric certificates with ACTUAL Residents/Transforms/Gear/Haul/Inventory owners.
## These tests prove identity, bounded storage and refusal, never production asset qualification.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Work := preload("res://scripts/core/work.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const AssemblySource := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const EndpointCertificate := preload("res://data/underground/mole-worker/qualified-assembly-v1/endpoint_certificate.gd")
const ShortStep := preload("res://data/underground/mole-worker/work-step-v1/source_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const FILE_PATH: String = "user://test-underground-profiles-only.bin"
var _profiles: Profiles = null
var _residents: Residents = null
var _transforms: Transforms = null
var _inventory: Inventory = null
var _items: Items = null
var _gear: Gear = null
var _carry: Carry = null
var _work: Work = null
var _jobs: Jobs = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _pool: Pool = null
var _piles: Piles = null
var _worker: Vector2i = NULL_REF
var _slot: int = -1
var _store: Vector2i = NULL_REF
var _identity: PackedInt32Array = PackedInt32Array([0, 0, 0])


func test_actual_stationary_source_appends_one_explicit_row_without_aliasing_old_profiles() -> void:
	"""Real frozen source geometry is a format input; it grants no paid or physical permission in this test."""
	_profiles = null
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "exact proposed joint bank")
	assert_equal(_bind(_profiles), &"", "same actual owner tuple")
	var path: String = "res://data/underground/mole-worker/qualified-assembly-v1/diagnostic-profile-1/mole-worker.ugprof"
	assert_equal(_profiles.load_file(path, "17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9", 4), &"", "immutable actual source rows")
	assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"", "complete exact handling row")
	assert_true(ShortStep.uses(_profiles), "exact appended source preserves old source policy")
	for profile: int in range(2, 29):
		assert_equal(ShortStep.profile_refusal(_profiles, profile, 1, 4), &"", "old policy remains exact")
	assert_false(ShortStep.profile_refusal(_profiles, 29, 1, 4) == &"", "handling cannot alias old WORK")
	_profiles._live.sources[32] ^= 1
	assert_false(ShortStep.uses(_profiles), "thirty alone cannot extend the old protocol")
	assert_false(AssemblySource.profile_refusal(_profiles, 29, 1, 4) == &"", "source digest required")
	_profiles._live.sources[32] ^= 1
	_profiles._live.flags[_profiles._profile_capacity + 29] = Profiles.POLICY_SOURCE_WORK
	assert_false(ShortStep.uses(_profiles), "legacy policy cannot claim new source geometry")
	_profiles._live.flags[_profiles._profile_capacity + 29] = Profiles.POLICY_ASSEMBLY_HANDLING
	_profiles._live.boxes[AssemblySource.FIRST_BOX] -= 1
	assert_false(ShortStep.uses(_profiles), "complete source boxes are pinned")
	assert_equal(AssemblySource.part_refusal(0, 1, 3, Vector3i(1024, 192, -768)), &"", "actual Workpieces turn convention")
	assert_false(AssemblySource.part_refusal(0, 1, 1, Vector3i(1024, 192, -768)) == &"", "opposite turn has different geometry")
	assert_equal(AssemblySource.part_refusal(1, 8, 3, Vector3i(2304, 320, -2816)), &"", "actual second complete bearer")


func test_actual_handling_source_checks_every_descriptor_box_and_digest_word() -> void:
	"""Sequential source leaves must reject each independent drift without retaining a success cache."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "exact source capacity")
	assert_equal(_bind(_profiles), &"", "original real owners")
	assert_equal(_profiles.load_file("res://data/underground/mole-worker/qualified-assembly-v1/diagnostic-profile-1/mole-worker.ugprof",
		"17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9", 4), &"", "exact source input")
	for field: int in Profiles.I32_FIELDS:
		var index: int = field * _profiles._profile_capacity + AssemblySource.PROFILE
		_profiles._live.fields[index] ^= 1
		assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"ASSEMBLY_SOURCE_PROFILE", "descriptor word %d" % field)
		_profiles._live.fields[index] ^= 1
		assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"", "descriptor restoration")
	for ordinal: int in AssemblySource.ROLE_COUNT:
		for field: int in 7:
			var index: int = field * _profiles._box_capacity + AssemblySource.FIRST_BOX + ordinal
			_profiles._live.boxes[index] ^= 1
			assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"ASSEMBLY_SOURCE_PROFILE", "complete box word %d/%d" % [ordinal, field])
			_profiles._live.boxes[index] ^= 1
			assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"", "box restoration")
	for byte: int in 64:
		_profiles._live.sources[byte] ^= 1
		assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"ASSEMBLY_SOURCE_PROFILE", "source digest byte %d" % byte)
		_profiles._live.sources[byte] ^= 1
		assert_equal(AssemblySource.profile_refusal(_profiles, 29, 1, 4), &"", "digest restoration")


func test_prepared_endpoint_certificate_retains_complete_source_envelope_and_footing() -> void:
	"""Every actual source word fits the proposed endpoint; no caller bool, clipping or new profile is used."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "actual source bank")
	assert_equal(_bind(_profiles), &"", "original owners")
	assert_equal(_profiles.load_file("res://data/underground/mole-worker/qualified-assembly-v1/diagnostic-profile-1/mole-worker.ugprof",
		"17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9", 4), &"", "exact source input")
	assert_equal(EndpointCertificate._profiles_refusal(_profiles, 4), &"", "all four complete descriptors and digests")
	for profile: int in [2, 6, 16, 29]: _endpoint_source_boxes(profile)
	_profiles._live.sources[32] ^= 1
	assert_true(EndpointCertificate._profiles_refusal(_profiles, 4) != &"", "handling digest cannot drift")
	_profiles._live.sources[32] ^= 1
	_profiles._live.boxes[4 * _profiles._box_capacity + 16] += 1
	assert_true(EndpointCertificate._profiles_refusal(_profiles, 4) != &"", "complete forward high-pick geometry cannot drift")
	_profiles._live.boxes[4 * _profiles._box_capacity + 16] -= 1
	assert_true(EndpointCertificate._profiles_refusal(_profiles, 3) != &"", "old repeated content is not this source")
	assert_equal(EndpointCertificate._profiles_refusal(_profiles, 4), &"", "unchanged source retries")
	assert_equal(EndpointCertificate.prepared_record_refusal(null, null, null, 0), EndpointCertificate.REFUSE,
		"source metadata grants no prepared owner, payment or clearance")


func _endpoint_source_boxes(profile: int) -> void:
	"""Check all BODY/TURN/STANCE words against their complete source-derived endpoint bounds."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var box: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.descriptor_into(profile, 4, descriptor), &"", "actual exact source descriptor")
	for ordinal: int in descriptor.box_count:
		assert_equal(_profiles.box_into(profile, 1, 4, ordinal, box), &"", "whole source box")
		if box.role != Profiles.BODY_HELD_LOAD and box.role != Profiles.TURN_RECOVERY and box.role != Profiles.STANCE_SUPPORT:
			continue
		for axis: int in 3:
			if box.role == Profiles.STANCE_SUPPORT or box.high.y <= 0:
				assert_true(box.low[axis] >= EndpointCertificate._support_word(axis), "complete below-floor low")
				assert_true(box.high[axis] <= EndpointCertificate._support_word(axis + 3), "complete below-floor high")
			else:
				assert_true(box.low[axis] >= EndpointCertificate._envelope_word(axis), "complete positive low")
				assert_true(box.high[axis] <= EndpointCertificate._envelope_word(axis + 3), "complete positive high")


func test_pending_bearer_span_uses_complete_forward_and_backward_source_only() -> void:
	"""Source components remain diagnostic; complete prepared owners and an actual paid operation are separately required."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "actual source capacity")
	assert_equal(_bind(_profiles), &"", "original owners")
	assert_equal(_profiles.load_file("res://data/underground/mole-worker/qualified-assembly-v1/diagnostic-profile-1/mole-worker.ugprof",
		"17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9", 4), &"", "exact source input")
	_span_source_words(2)
	_span_source_words(6)
	var root: Vector3i = Vector3i(-832, 0, 512)
	assert_true(EndpointCertificate._span_points_match(2, root, root + Vector3i(0, 0, 4096), root), "full forward prefix")
	assert_true(EndpointCertificate._span_points_match(6, root, root, root + Vector3i(0, 0, 4096)), "full reverse prefix")
	assert_false(EndpointCertificate._span_points_match(2, root, root, root + Vector3i(0, 0, 1)), "forward cannot reverse")
	assert_false(EndpointCertificate._span_points_match(6, root, root, root + Vector3i(1, 0, 1)), "no lateral shortcut")
	assert_false(EndpointCertificate._span_points_match(6, root, root, root + Vector3i(0, 1, 1)), "no step or stair")
	assert_false(EndpointCertificate._span_points_match(6, root, root - Vector3i(0, 0, 1), root), "no unproved negative root")
	assert_false(EndpointCertificate._span_points_match(6, root, root, root + Vector3i(0, 0, 4097)), "finite root interval")
	assert_false(EndpointCertificate._span_points_match(12, root, root, root + Vector3i(0, 0, 1024)), "no automatic turn")
	assert_equal(EndpointCertificate.prepared_span_refusal(null, root, root + Vector3i(0, 0, 1), 0),
		EndpointCertificate.REFUSE, "source math alone grants no paid scope")


func _span_source_words(profile: int) -> void:
	"""Actual admitted source bytes, not a hand-authored substitute, exercise the full descriptor and each role."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var box: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.descriptor_into(profile, 4, descriptor), &"", "real source descriptor")
	assert_true(EndpointCertificate._span_descriptor_matches(descriptor, 4), "all descriptor fields match")
	descriptor.box_count -= 1
	assert_false(EndpointCertificate._span_descriptor_matches(descriptor, 4), "cannot omit the held pick")
	descriptor.box_count += 1
	for ordinal: int in descriptor.box_count:
		assert_equal(_profiles.box_into(profile, 1, 4, ordinal, box), &"", "actual source primitive")
		assert_equal(EndpointCertificate._span_body_matches(box), box.role != Profiles.STANCE_SUPPORT,
			"stance cannot receive an air certificate")
		box.high.x += 1
		assert_false(EndpointCertificate._span_body_matches(box), "changed primitive cannot receive certificate")


func before_each() -> void:
	"""One world with deliberately different global Resident slot and typed resident row."""
	_residents = Residents.new()
	var world: Vector2i = _residents.directory().create(Directory.KIND_WORLD)
	_slot = _residents.spawn(&"mouse").value
	_worker = _residents.ref_of(_slot)
	assert_true(_worker.x != _slot, "actual directory identity is not a typed row")
	assert_true(_residents.spatial_profile_identity_into(_worker, _identity), "actual logical rig")
	_transforms = Transforms.new(_residents.directory())
	assert_true(_transforms.place(_worker, 1024, -3584, 3072, 0), "actual positioned worker")
	_inventory = Inventory.new(16, 32)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "real item identities")
	_store = _inventory.create_container(world, 1000000, -1, 0, true).ref
	_pool = Pool.new(64, Pool.JOB_CAPACITY, 32)
	_piles = Piles.new()
	assert_true(_piles.bind_stores(_inventory, Buildings.new(_residents.directory()), StockAge.new(_inventory)), "actual pile owner")
	assert_true(_piles.bind_world(world), "actual World")
	_carry = Carry.new()
	assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual carry owner")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "real gear binding")
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	assert_true(_work.bind_gear(_gear).ok, "actual work binding")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(32, 256, 8, Profiles.ARENA_BYTES), &"", "finite test pack")
	assert_equal(_bind(_profiles), &"", "actual physical identity readers")


func after_each() -> void:
	"""Remove only this suite's temporary file and release borrowed stores in acyclic order."""
	_profiles = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_carry = null
	_gear = null
	_piles = null
	_pool = null
	_items = null
	_inventory = null
	_transforms = null
	_residents = null
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))


func _bind(candidate: Profiles) -> StringName:
	"""No synthetic authority: wire the same actual owner instances on every side."""
	return candidate.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles)


func _row(mode: int = Profiles.MODE_WALK) -> Dictionary:
	"""Explicit synthetic geometry/certificate; actual species/stage/rig remains owner-derived."""
	var fields: PackedInt32Array = PackedInt32Array([0, _identity[0], _identity[1], _identity[2],
		mode, Profiles.POSTURE_UPRIGHT, -1, -1, -1, -1, Profiles.YAW_ALL, 0, 31, 511, 0, 3, -1, 0])
	return {"fields": fields, "longs": PackedInt64Array([1, 0, 0]), "flags": PackedByteArray([15, 0])}


func _boxes() -> Array[PackedInt32Array]:
	"""Body retains actual below-root space; explicit test-only floor contact and turn volume."""
	return [PackedInt32Array([-100, -20, -80, 100, 900, 80, 0]),
		PackedInt32Array([-40, -20, -40, 40, 0, 40, 1]),
		PackedInt32Array([-128, -20, -128, 128, 900, 128, 2])]


func _image(rows: Array[Dictionary], boxes: Array[PackedInt32Array], revision: int = 1,
		sources: int = 1) -> PackedByteArray:
	"""Independent row-wire writer; loader owns column indexing, count validation and atomicity."""
	var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
	bytes.resize(32)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, revision)
	bytes.encode_u32(20, rows.size())
	bytes.encode_u32(24, boxes.size())
	bytes.encode_u32(28, sources)
	for source: int in sources:
		for index: int in 32:
			bytes.append(7 + source) # Synthetic digest, never a production source.
	for row: Dictionary in rows:
		var base: int = bytes.size()
		bytes.resize(base + 98)
		var fields: PackedInt32Array = row.fields
		var longs: PackedInt64Array = row.longs
		for index: int in 18:
			bytes.encode_s32(base + 4 * index, fields[index])
		for index: int in 3:
			bytes.encode_s64(base + 72 + 8 * index, longs[index])
		bytes[base + 96] = row.flags[0]
		bytes[base + 97] = row.flags[1]
	for box: PackedInt32Array in boxes:
		var base: int = bytes.size()
		bytes.resize(base + 28)
		for index: int in 7:
			bytes.encode_s32(base + 4 * index, box[index])
	bytes.append_array("UGPEND01".to_ascii_buffer())
	return bytes


func _load(bytes: PackedByteArray, revision: int = 1, hash_override: String = "") -> StringName:
	"""The trusted expected digest is external to the file being decoded."""
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var digest_context: HashingContext = HashingContext.new()
	digest_context.start(HashingContext.HASH_SHA256)
	digest_context.update(bytes)
	var actual: String = digest_context.finish().hex_encode()
	return _profiles.load_file(FILE_PATH, actual if hash_override == "" else hash_override, revision)


func _query(out: Profiles.Selection, hint: Vector2i = NULL_REF, mode: int = Profiles.MODE_WALK) -> StringName:
	"""A prospective movement lookup still uses the actual present worker and yaw."""
	return _profiles.query_into(_worker, NULL_REF, mode, Profiles.POSTURE_UPRIGHT, -1, hint, out)


func _policy_image(policies: Array[int], revision: int = 1) -> PackedByteArray:
	"""Labelled synthetic policy wire tests use whole existing boxes and actual dynamic stores."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for policy: int in policies:
		var row: Dictionary = _row()
		row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		if policy != Profiles.POLICY_AUTOMATIC and policy != Profiles.POLICY_CANONICAL_GROUND:
			row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
		row.flags[1] = policy
		rows.append(row)
		boxes.append_array(_boxes())
	var bytes: PackedByteArray = _image(rows, boxes, revision)
	bytes.encode_u32(8, 2)
	return bytes


func test_explicit_travel_policy_does_not_change_automatic_selection() -> void:
	"""Two finite directional programmes coexist without becoming default matches or losing real actor proof."""
	assert_equal(_load(_policy_image([0, 1, 2])), &"", "different explicit policies are distinct")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"", "ordinary default remains unique")
	assert_equal(out.profile_id, 0, "same automatic row")
	assert_equal(_profiles.query_travel_profile_into(_worker, NULL_REF, 1, 1, 1, 0, -1, NULL_REF, out), &"", "explicit forward row")
	assert_equal(out.profile_id, 1, "exact requested row")
	assert_equal(_profiles.selection_policy_of(1, 1, 1), Profiles.POLICY_READY_FORWARD, "stored immutable policy")
	assert_equal(_profiles.query_travel_profile_into(_worker, NULL_REF, 2, 1, 1, 0, -1, NULL_REF, out), &"", "explicit backward row")
	assert_equal(out.profile_id, 2, "opposite source policy is explicit")
	assert_true(_transforms.set_yaw(_worker, 16384), "real pose changed")
	assert_equal(_profiles.query_travel_profile_into(_worker, NULL_REF, 1, 1, 1, 0, -1, NULL_REF, out), &"PROFILE_VARIANT_UNAUTHORED", "fixed heading cannot follow actual turn")
	assert_equal(out.profile_id, 2, "refusal preserves prior full output")
	assert_equal(_profiles.selection_policy_of(1, 2, 1), -1, "stale full profile revision")
	assert_equal(_profiles.query_travel_profile_into(_worker, NULL_REF, 0, 1, 1, 0, -1, NULL_REF, out), &"PROFILE_TRAVEL_SELECTION_REQUIRED", "automatic row is not selected protocol")


func test_finite_step_and_canonical_ground_are_explicit_while_default_selection_stays_legacy() -> void:
	"""New policy values partition source state without changing physical keys or default policy0 selection."""
	assert_equal(_load(_policy_image([0, 4, 5, 6])), &"", "explicit source policies are separately admitted")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_profiles.query_into(_worker, NULL_REF, Profiles.MODE_WALK, 0, -1, NULL_REF, out), &"", "ordinary lookup")
	assert_equal(out.profile_id, 0, "default remains the original automatic row")
	for row: int in range(1, 4):
		assert_equal(_profiles.query_travel_profile_into(_worker, NULL_REF, row, 1, 1, 0, -1, NULL_REF, out), &"", "explicit actual travel selection")
		assert_equal(out.profile_id, row, "caller selects an exact source row")
		assert_equal(_profiles.selection_policy_of(row, 1, 1), row + 3, "immutable versioned policy")
	var bad: PackedByteArray = _policy_image([0, 6], 2)
	bad.encode_s32(64 + 98 + 4 * Profiles.F_YAW_KIND, Profiles.YAW_EXACT)
	assert_equal(_load(bad, 2), &"PROFILE_POLICY_FORMAT", "canonical ground must retain the complete all-yaw source")
	assert_equal(_load(_policy_image([0, 6, 6], 2), 2), &"PROFILE_AMBIGUOUS_KEY", "same canonical source policy still rejects overlap")
	assert_equal(_profiles.content_revision(), 1, "failed replacement retains old content")


func test_policy_version_unknown_and_same_policy_ambiguity_refuse_atomically() -> void:
	"""Schema1 reserved byte remains zero; schema2 never interprets an unknown or ambiguous programme."""
	assert_equal(_load(_policy_image([0, 1, 2])), &"", "valid predecessor")
	var image: PackedByteArray = _policy_image([0, 1], 2)
	image.encode_u32(8, 1)
	assert_equal(_load(image, 2), &"PROFILE_CERTIFICATE_REQUIRED", "historical wire cannot acquire new meaning")
	assert_equal(_load(_policy_image([0, 8], 2), 2), &"PROFILE_CERTIFICATE_REQUIRED", "unknown policy refuses")
	assert_equal(_load(_policy_image([0, 1, 1], 2), 2), &"PROFILE_AMBIGUOUS_KEY", "same-policy overlap remains ambiguous")
	image = _policy_image([0, 1], 2)
	image.encode_s32(64 + 98 + Profiles.F_YAW_KIND * 4, Profiles.YAW_ALL)
	assert_equal(_load(image, 2), &"PROFILE_POLICY_FORMAT", "selected travel cannot turn freely")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"", "refused reload retains original live bank")
	assert_equal(out.profile_id, 0, "automatic predecessor intact")


func _handling_case() -> Dictionary:
	"""Synthetic format fixture only: curved contact carries whole volumes, never a planar contact alias."""
	var row: Dictionary = _row(Profiles.MODE_WORK)
	row.fields[Profiles.F_TOOL] = _items.compiled_id(&"tool")
	row.fields[Profiles.F_TOOL_VARIANT] = Gear.MANUFACTURE_BASIC
	row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
	row.fields[Profiles.F_BOX_COUNT] = 4
	row.fields[Profiles.F_WORK_KIND] = Jobs.JOB_KIND_BUILD
	row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ASSEMBLY_PALM
	row.flags[1] = Profiles.POLICY_ASSEMBLY_HANDLING
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append(PackedInt32Array([-128, -20, -128, 128, 1000, 256, Profiles.WORK_APPROACH]))
	return {"row": row, "boxes": boxes}


func _handling_image(fixture: Dictionary, revision: int = 1) -> PackedByteArray:
	"""Version2 is mandatory for every explicit source policy, including the separate handling programme."""
	var bytes: PackedByteArray = _image([fixture.row], fixture.boxes, revision)
	bytes.encode_u32(8, 2)
	return bytes


func test_assembly_handling_is_explicit_actual_build_selection_without_stroke_or_patch() -> void:
	"""Loading a geometry row never grants travel, paid handling or productive work."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "original actual tool claim")
	assert_equal(_load(_handling_image(_handling_case())), &"", "distinct curved source format")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_profiles.query_into(_worker, job.ref, Profiles.MODE_WORK, 0, -1, NULL_REF, out),
		&"PROFILE_VARIANT_UNAUTHORED", "automatic work cannot select handling")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 0, 1, 1, 0, -1, NULL_REF, out),
		&"", "explicit selection still proves actual BUILD/tool/cargo/pose")
	assert_equal(out.tool, tool, "full original tool")
	assert_equal(_profiles.selection_policy_of(0, 1, 1), Profiles.POLICY_ASSEMBLY_HANDLING, "separate stored policy")
	assert_equal(_profiles.query_travel_profile_into(_worker, job.ref, 0, 1, 1, 0, -1, NULL_REF, out),
		&"PROFILE_TRAVEL_SELECTION_REQUIRED", "handling is never a travel row")
	assert_true(_work.release_tool_claim(_slot).ok, "release real claim")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 0, 1, 1, 0, -1, tool, out),
		&"PROFILE_TOOL_CLAIM", "source metadata cannot recreate a released claim")


func test_assembly_contact_cannot_alias_productive_contact_roles_or_legacy_policy() -> void:
	"""A reserved policy, an added stroke/point/patch or missing reverse source fails atomic replacement."""
	assert_equal(_load(_handling_image(_handling_case())), &"", "valid format baseline")
	for role: int in [Profiles.WORK_STROKE, Profiles.CONTACT_POINT, Profiles.CONTACT_PATCH]:
		var fixture: Dictionary = _handling_case()
		fixture.boxes.append(PackedInt32Array([0, 0, 0, 1, 1, 1, role]) if role == Profiles.WORK_STROKE \
			else PackedInt32Array([0, 0, 0, 0, 0, 0, role]) if role == Profiles.CONTACT_POINT \
			else PackedInt32Array([0, 0, 0, 1, 0, 1, role]))
		fixture.row.fields[Profiles.F_BOX_COUNT] += 1
		assert_equal(_load(_handling_image(fixture, 2), 2), &"PROFILE_ROLE_MISSING", "no productive alias")
	var changed: Dictionary = _handling_case()
	changed.row.flags[1] = Profiles.POLICY_AUTOMATIC
	assert_equal(_load(_handling_image(changed, 2), 2), &"PROFILE_WORK_IDENTITY", "curved kind requires its explicit policy")
	changed = _handling_case()
	changed.row.fields[Profiles.F_STATES] &= ~Profiles.STATE_REVERSAL
	assert_equal(_load(_handling_image(changed, 2), 2), &"PROFILE_ROLE_MISSING", "interruption source is mandatory")
	assert_equal(_profiles.content_revision(), 1, "all refused replacements preserve the live bank")


func test_seventeenth_variant_is_only_the_single_explicit_handling_tail() -> void:
	"""The old16 automatic window is complete; a seventeenth legacy row or any eighteenth row refuses."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in Profiles.MAX_KEY_VARIANTS:
		var prior: Dictionary = _patch_case()
		prior.row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		rows.append(prior.row)
		boxes.append_array(prior.boxes)
	assert_equal(_load(_image(rows, boxes)), &"", "original sixteen contacts")
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "actual original claim")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_profiles.query_into(_worker, job.ref, Profiles.MODE_WORK, 0, -1, NULL_REF, out),
		&"PROFILE_SELECTION_AMBIGUOUS", "old actual result")
	var tail: Dictionary = _handling_case()
	tail.row.fields[Profiles.F_FIRST_BOX] = boxes.size()
	rows.append(tail.row)
	boxes.append_array(tail.boxes)
	var bytes: PackedByteArray = _image(rows, boxes, 2)
	bytes.encode_u32(8, 2)
	assert_equal(_load(bytes, 2), &"", "one explicit tail beyond the automatic window")
	assert_equal(_profiles.query_into(_worker, job.ref, Profiles.MODE_WORK, 0, -1, NULL_REF, out),
		&"PROFILE_SELECTION_AMBIGUOUS", "all old automatic matches/results are unchanged")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 16, 1, 2, 0, -1, NULL_REF, out),
		&"", "explicit full source row remains reachable")
	var extra: Dictionary = _handling_case()
	extra.row.fields[Profiles.F_FIRST_BOX] = boxes.size()
	rows.append(extra.row)
	boxes.append_array(extra.boxes)
	bytes = _image(rows, boxes, 3)
	bytes.encode_u32(8, 2)
	assert_equal(_load(bytes, 3), &"PROFILE_KEY_CAPACITY", "eighteenth row never becomes hidden")
	assert_equal(_profiles.content_revision(), 2, "failed tail growth retains exact old content")
	assert_true(_work.release_tool_claim(_slot).ok, "release actual claim")


func test_actual_identity_and_nonzero_directory_slot_select_without_state_mutation() -> void:
	"""Full Directory refs, real Transforms and exact source keys are required before writing output."""
	assert_equal(_load(_image([_row()], _boxes())), &"", "synthetic certificate image loads")
	var before: PackedByteArray = _residents.state_bytes()
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"", "real identity selects synthetic envelope")
	assert_equal(out.worker, _worker, "full ref retained")
	assert_equal(out.species, _identity[0], "actual species")
	assert_equal(out.rig, _identity[2], "actual logical rig")
	assert_equal(out.y, -3584, "actual multi-level XYZ")
	assert_equal(out.cargo, NULL_REF, "actual empty cargo")
	assert_equal(_residents.state_bytes(), before, "lookup has no gameplay mutation")
	var box: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.box_into(out.profile_id, out.profile_revision, out.content_revision, 0, box), &"", "whole body")
	assert_equal(box.low.y, -20, "below-root body is never clipped away")
	assert_equal(box.role, Profiles.BODY_HELD_LOAD, "typed role")


func test_refusal_preserves_outputs_and_source_scratch() -> void:
	"""Stale full references and wrong scratch shapes do not overwrite a caller's prior answer."""
	assert_equal(_load(_image([_row()], _boxes())), &"", "fixture load")
	var out: Profiles.Selection = Profiles.Selection.new()
	out.profile_id = 77
	assert_equal(_profiles.query_into(Vector2i(_worker.x, _worker.y + 1), NULL_REF, 1, 0, -1, NULL_REF, out),
		&"PROFILE_WORKER_STALE", "generation mismatch")
	assert_equal(out.profile_id, 77, "selection untouched")
	var box: Profiles.Box = Profiles.Box.new()
	box.role = 77
	assert_equal(_profiles.box_into(0, 1, 99, 0, box), &"PROFILE_SELECTION_STALE", "content stale")
	assert_equal(box.role, 77, "box untouched")
	var digest: PackedByteArray = PackedByteArray([9])
	assert_false(_profiles.source_hash_into(0, 1, digest), "exact32 scratch")
	assert_equal(digest[0], 9, "digest untouched")
	digest.resize(32)
	assert_true(_profiles.source_hash_into(0, 1, digest), "source digest")
	assert_equal(digest.count(7), 32, "exact synthetic source")


func test_exact_orientation_is_never_rounded_to_cardinal() -> void:
	"""One yaw difference refuses; all-yaw and exact-yaw certificates remain distinct."""
	var row: Dictionary = _row()
	row.fields[10] = Profiles.YAW_EXACT
	row.fields[11] = 16384
	assert_equal(_load(_image([row], _boxes())), &"", "exact authored yaw")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"PROFILE_VARIANT_UNAUTHORED", "zero is not quarter turn")
	assert_true(_transforms.set_yaw(_worker, 16383), "one short of quarter")
	assert_equal(_query(out), &"PROFILE_VARIANT_UNAUTHORED", "no rounding")
	assert_true(_transforms.set_yaw(_worker, 16384), "exact quarter")
	assert_equal(_query(out), &"", "exact authored orientation")
	assert_equal(out.yaw, 16384, "actual yaw retained")


func test_failed_replacement_preserves_live_bank_and_success_invalidates_old_selection() -> void:
	"""Truncation/digest_context/certificate refusal leaves a prior valid catalog and its boxes intact."""
	assert_equal(_load(_image([_row()], _boxes())), &"", "initial")
	var image: PackedByteArray = _image([_row()], _boxes(), 2)
	assert_equal(_load(image, 2, "0".repeat(64)), &"PROFILE_SOURCE_HASH", "wrong digest")
	assert_equal(_profiles.content_revision(), 1, "prior content retained")
	assert_equal(_load(image.slice(0, image.size() - 1), 2), &"PROFILE_SOURCE_FORMAT", "truncated footer")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"", "prior content still usable")
	assert_equal(_load(image, 2), &"", "complete verified candidate swaps")
	assert_equal(_profiles.box_into(out.profile_id, out.profile_revision, out.content_revision, 0, Profiles.Box.new()),
		&"PROFILE_SELECTION_STALE", "old selection cannot read new boxes")
	assert_equal(_load(image, 2), &"PROFILE_SOURCE_IDENTITY", "no mutable same-revision replacement")


func test_missing_proof_state_stance_and_box_census_refuse() -> void:
	"""Positive dimensions or sampled evidence alone cannot become a usable profile."""
	var row: Dictionary = _row()
	row.flags[0] = 3
	assert_equal(_load(_image([row], _boxes())), &"PROFILE_CERTIFICATE_REQUIRED", "numerical/presentation proof missing")
	row.flags[0] = 15
	row.fields[13] = Profiles.STATE_WALK
	assert_equal(_load(_image([row], _boxes())), &"PROFILE_STATE_MISSING", "entry/reversal/recovery omitted")
	row.fields[13] = 511
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[1][6] = 0
	assert_equal(_load(_image([row], boxes)), &"PROFILE_ROLE_MISSING", "stance cannot be inferred from body")
	row.fields[14] = 1
	assert_equal(_load(_image([row], _boxes())), &"PROFILE_BOX_CENSUS", "no unowned gap or overlapping prefix")


func test_duplicate_and_unsorted_physical_keys_refuse_atomically() -> void:
	"""Ambiguous selection and hidden linear scans are refused by the cold input owner."""
	var first: Dictionary = _row()
	var second: Dictionary = _row()
	second.fields[14] = 3
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append_array(_boxes())
	assert_equal(_load(_image([first, second], boxes)), &"PROFILE_AMBIGUOUS_KEY", "identical source selection")
	first.fields[4] = Profiles.MODE_CARRY
	assert_equal(_load(_image([first, second], boxes)), &"PROFILE_KEY_ORDER", "required deterministic prefix order")
	assert_equal(_profiles.content_revision(), 0, "neither candidate publishes")


func test_configure_reserves_both_banks_and_limits_native_control() -> void:
	"""Maximum pack includes replacement, source digests and explicit32KiB native/control reserve."""
	var store: Profiles = Profiles.new()
	assert_equal(store.configure(256, 3072, 64, 259135), &"PROFILE_ARENA_CAPACITY", "one byte short")
	assert_equal(store.configure(256, 3072, 64, 262144), &"", "complete admitted maximum")
	assert_equal(store.packed_memory_bytes(), 226368, "two banks plus their headers")
	assert_equal(store.configure(1, 1, 1, 262144), &"PROFILE_ALREADY_CONFIGURED", "no resize")
	assert_equal(Profiles.new().configure(257, 1, 1, 262144), &"PROFILE_CAPACITY", "finite descriptors")


func _equip() -> Vector2i:
	"""Create and equip one real indivisible basic tool using its owner recipe."""
	var tool: Vector2i = _inventory.create_lot(_store, _items.compiled_id(&"tool"), 1000, 0, 0, -1, 0, 0).ref
	assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool")
	assert_true(_gear.equip(tool, _worker).ok, "actual equip")
	return tool


func test_equipped_tool_cannot_disappear_behind_an_empty_hint_or_unloaded_profile() -> void:
	"""Real Gear identity and manufacture are part of the physical key even outside a Work claim."""
	assert_equal(_load(_image([_row()], _boxes())), &"", "unloaded synthetic profile")
	var tool: Vector2i = _equip()
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out), &"PROFILE_TOOL_REQUIRED", "no null-hint hiding")
	assert_equal(_query(out, Vector2i(tool.x, tool.y + 1)), &"PROFILE_TOOL_STALE", "exact gear generation")
	assert_equal(_query(out, tool), &"PROFILE_VARIANT_UNAUTHORED", "held tool requires its own envelope")
	var row: Dictionary = _row()
	row.fields[6] = _items.compiled_id(&"tool")
	row.fields[7] = Gear.MANUFACTURE_BASIC
	assert_equal(_load(_image([row], _boxes(), 2), 2), &"", "explicit synthetic basic-tool envelope")
	assert_equal(_query(out, tool), &"", "actual tool matches")
	assert_equal(out.tool, tool, "no cloned or substituted gear")


func test_real_cargo_quantity_and_recipe_are_exact_not_mass_or_case_aliases() -> void:
	"""Actual HaulCarry/Inventory drives profile selection and preserves full carried refs."""
	var item: int = _items.compiled_id(&"stone")
	var source: Vector2i = _inventory.create_lot(_store, item, 5000, 0, 0, -1, 0, 0).ref
	var job: Vector2i = Vector2i(500, 1) # Real Reservations/Carry support a full caller Job token.
	var batch: PackedInt64Array = PackedInt64Array([source.x, source.y, Pool.PURPOSE_HAUL_SOURCE, 2000, 300])
	assert_true(_pool.claim_batch(job, batch, 1, _inventory).ok, "actual source claim")
	assert_true(_carry.load_payload(job, _slot, source).ok, "actual carried lot")
	assert_equal(_load(_image([_row(Profiles.MODE_CARRY)], _boxes())), &"", "empty envelope is not a cargo alias")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out, NULL_REF, Profiles.MODE_CARRY), &"PROFILE_VARIANT_UNAUTHORED", "real held cargo cannot disappear")
	var row: Dictionary = _row(Profiles.MODE_CARRY)
	row.fields[8] = item
	row.fields[9] = -1
	row.longs[1] = 2000
	row.longs[2] = 2000
	assert_equal(_load(_image([row], _boxes(), 2), 2), &"", "exact physical cargo/recipe/range")
	assert_equal(_query(out, NULL_REF, Profiles.MODE_CARRY), &"", "actual quantity selects")
	assert_equal(out.cargo, _carry.carried_lot(_slot), "actual carried full ref")
	assert_equal(out.cargo_quantity_milli, 2000, "real quantity")
	row.longs[1] = 2001
	row.longs[2] = 3000
	assert_equal(_load(_image([row], _boxes(), 3), 3), &"", "different range is independently authored")
	assert_equal(_query(out, NULL_REF, Profiles.MODE_CARRY), &"PROFILE_VARIANT_UNAUTHORED", "no rounding to range")


func test_collaborator_rebinding_is_refused_with_no_identity_alias() -> void:
	"""A typed owner rebind changes composition even when all capacities/references match."""
	assert_equal(_load(_image([_row()], _boxes())), &"", "profile")
	assert_true(_profiles.binding_matches(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), "exact composition")
	assert_false(_profiles.binding_matches(_residents, Transforms.new(_residents.directory()), _inventory,
		_gear, _carry, _work, _pool, _piles), "foreign transform owner")
	assert_true(_carry.bind(_inventory, Pool.new(64, Pool.JOB_CAPACITY, 32), _residents, _piles), "actual collaborator rebind")
	assert_equal(_query(Profiles.Selection.new()), &"PROFILE_OWNER_UNBOUND", "fresh binding check")


func test_absent_stage_and_wrong_connector_family_do_not_inherit_permissions() -> void:
	"""Even a valid source certificate is exact to the current life stage, physical family and posture."""
	var row: Dictionary = _row()
	row.fields[12] = 1
	assert_equal(_load(_image([row], _boxes())), &"", "one family only")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_profiles.query_into(_worker, NULL_REF, 1, 0, 1, NULL_REF, out), &"PROFILE_VARIANT_UNAUTHORED", "different connector")
	assert_equal(_profiles.query_into(_worker, NULL_REF, 1, 1, 0, NULL_REF, out), &"PROFILE_VARIANT_UNAUTHORED", "different posture")
	var child: Residents.OpResult = _residents.spawn_with_stage(&"mouse", Residents.LIFE_STAGE_CHILD)
	assert_true(child.ok, "real child")
	assert_true(_transforms.place(child.ref, 0, -3584, 0, 0), "child transform")
	assert_equal(_profiles.query_into(child.ref, NULL_REF, 1, 0, 0, NULL_REF, out), &"PROFILE_WORKER_STALE", "absent child rig never adult alias")


func test_work_requires_actual_job_and_exact_contact_orientation() -> void:
	"""No caller-provided work state can inherit a mobile envelope or all-yaw contact point."""
	var row: Dictionary = _row(Profiles.MODE_WORK)
	row.fields[15] = 6
	row.fields[16] = Jobs.JOB_KIND_BUILD
	row.fields[17] = 1
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append(PackedInt32Array([-128, -20, -128, 128, 1000, 256, 3]))
	boxes.append(PackedInt32Array([-128, 300, -256, 128, 1000, 128, 4]))
	boxes.append(PackedInt32Array([0, 512, -200, 0, 512, -200, 5]))
	assert_equal(_load(_image([row], boxes)), &"PROFILE_CONTACT_ORIENTATION", "work point requires actual orientation")
	row.fields[10] = Profiles.YAW_EXACT
	assert_equal(_load(_image([row], boxes)), &"", "complete synthetic contact roles")
	assert_equal(_query(Profiles.Selection.new(), NULL_REF, Profiles.MODE_WORK), &"PROFILE_JOB_REQUIRED", "actual Job required")
	assert_equal(_profiles.query_into(_worker, Vector2i(9, 123), 3, 0, -1, NULL_REF, Profiles.Selection.new()),
		&"PROFILE_JOB_STALE", "foreign generation no authority")


func _actual_work_job() -> Jobs.OpResult:
	"""Give the existing real worker its actual schedule/priorities/JobAgent and BUILD assignment."""
	assert_true(_priorities.spawn(_slot).ok, "actual priorities")
	assert_true(_schedule.spawn(_slot, _schedule.default_template_id().value).ok, "actual schedule")
	assert_true(_schedule.resolve(_slot, 8, false).ok, "work hour")
	assert_true(_jobs.spawn_agent(_slot).ok, "actual JobAgent")
	var job: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1000, 0)
	assert_true(job.ok, "actual BUILD")
	assert_true(_jobs.assign_worker(_slot, job.value).ok, "actual assignment")
	return job


func _install_work_profile() -> void:
	"""Six synthetic physical roles for the actual basic tool and BUILD Job kind."""
	var row: Dictionary = _row(Profiles.MODE_WORK)
	row.fields[6] = _items.compiled_id(&"tool")
	row.fields[7] = Gear.MANUFACTURE_BASIC
	row.fields[10] = Profiles.YAW_EXACT
	row.fields[15] = 6
	row.fields[16] = Jobs.JOB_KIND_BUILD
	row.fields[17] = 1
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append(PackedInt32Array([-128, -20, -128, 128, 1000, 256, 3]))
	boxes.append(PackedInt32Array([-128, 300, -256, 128, 1000, 128, 4]))
	boxes.append(PackedInt32Array([0, 512, -200, 0, 512, -200, 5]))
	assert_equal(_load(_image([row], boxes)), &"", "synthetic work certificate")


func test_actual_claimed_work_query_refuses_after_tool_or_job_changes() -> void:
	"""A successful full Work/Gear/Job pairing cannot survive actual claim release or reassignment."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "real Work and Gear claim")
	_install_work_profile()
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, NULL_REF, out), &"", "Work supplies actual tool")
	assert_equal(out.tool, tool, "exact claimed full reference")
	assert_equal(out.job, job.ref, "exact assigned Job")
	assert_equal(out.box_count, 6, "full productive envelope and contact")
	assert_true(_work.release_tool_claim(_slot).ok, "real claim release")
	assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, tool, out), &"PROFILE_TOOL_CLAIM", "hint does not recreate claim")
	assert_equal(out.tool, tool, "refusal leaves prior scratch unchanged")
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "claim restored through actual owner")
	assert_true(_jobs.release_worker(_slot).ok, "actual Job assignment removed")
	assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, tool, out), &"PROFILE_JOB_STALE", "old Job cannot authorize new work")
	assert_true(_work.release_tool_claim(_slot).ok, "release actual retained tool claim")


func test_cold_authored_contact_is_readable_before_any_job_or_owner_binding() -> void:
	"""Admission may inspect feasible authored work geometry without inventing an assigned worker."""
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(32, 256, 8, Profiles.ARENA_BYTES), &"", "cold catalog only")
	_install_work_profile()
	var out: Profiles.Descriptor = Profiles.Descriptor.new()
	assert_equal(_profiles.profile_count(1), 1, "finite exact-version search")
	assert_equal(_profiles.descriptor_into(0, 1, out), &"", "authored descriptor before Sites creates a Job")
	assert_equal(out.profile_id, 0, "exact row identity")
	assert_equal(out.profile_revision, 1, "authored identity revision")
	assert_equal(out.content_revision, 1, "immutable content version")
	assert_equal(out.species, _identity[0], "source species")
	assert_equal(out.life_stage, _identity[1], "source life stage")
	assert_equal(out.rig, _identity[2], "source rig")
	_assert_work_descriptor(out)
	var point: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.box_into(out.profile_id, out.profile_revision, out.content_revision, 5, point), &"", "exact contact")
	assert_equal(point.role, Profiles.CONTACT_POINT, "authored contact role")
	assert_equal(point.low, point.high, "no invented reach radius")
	assert_equal(_query(Profiles.Selection.new(), NULL_REF, Profiles.MODE_WORK), &"PROFILE_OWNER_UNBOUND", "descriptor grants no actual work")


func _assert_work_descriptor(out: Profiles.Descriptor) -> void:
	"""Check all geometry key classes, independently of the actual worker selection type."""
	assert_equal(out.source_id, 0, "source bundle")
	assert_equal(out.mode, Profiles.MODE_WORK, "work geometry mode")
	assert_equal(out.posture, Profiles.POSTURE_UPRIGHT, "authored posture")
	assert_equal(out.tool_item, _items.compiled_id(&"tool"), "authored actual catalog tool")
	assert_equal(out.tool_variant, Gear.MANUFACTURE_BASIC, "physical manufacture variant")
	assert_equal(out.cargo_item, -1, "no cargo variant")
	assert_equal(out.cargo_variant, -1, "no cargo recipe")
	assert_equal(out.quantity_min_milli + out.quantity_max_milli, 0, "empty load")
	assert_equal(out.yaw_kind, Profiles.YAW_EXACT, "work contact cannot round yaw")
	assert_equal(out.yaw, 0, "exact orientation")
	assert_equal(out.family_mask, 31, "explicit synthetic family coverage")
	assert_equal(out.state_mask, 511, "explicit synthetic state coverage")
	assert_equal(out.work_kind, Jobs.JOB_KIND_BUILD, "owning Job kind")
	assert_equal(out.contact_kind, 1, "authored contact classification")
	assert_equal(out.box_count, 6, "all six required roles")
	assert_equal(out.certificate_flags, Profiles.CERT_REQUIRED, "synthetic complete certificate")


func test_authored_descriptor_refuses_stale_or_foreign_identity_without_output_mutation() -> void:
	"""A new catalog cannot inherit an older descriptor or its contact coordinates."""
	assert_equal(_profiles.profile_count(0), -1, "unloaded search refused")
	assert_equal(_load(_image([_row()], _boxes())), &"", "first content")
	var out: Profiles.Descriptor = Profiles.Descriptor.new()
	assert_equal(_profiles.descriptor_into(0, 1, out), &"", "read first content")
	out.tool_item = 888
	out.quantity_max_milli = 999
	for row: int in [-1, 1, 2147483647]:
		assert_equal(_profiles.descriptor_into(row, 1, out), &"PROFILE_SELECTION_STALE", "invalid identity")
		assert_equal(out.tool_item, 888, "refused output unchanged")
	assert_equal(_profiles.descriptor_into(0, 1, null), &"PROFILE_SELECTION_STALE", "null scratch")
	var changed: Dictionary = _row()
	changed.longs[0] = 2
	assert_equal(_load(_image([changed], _boxes(), 2), 2), &"", "complete replacement")
	assert_equal(_profiles.profile_count(1), -1, "old content search refuses")
	assert_equal(_profiles.descriptor_into(0, 1, out), &"PROFILE_SELECTION_STALE", "old version cannot read reused row")
	assert_equal(out.quantity_max_milli, 999, "stale refusal preserves every prior field")
	assert_equal(_profiles.descriptor_into(0, 2, out), &"", "new exact identity")
	assert_equal(out.profile_revision, 2, "new profile revision")
	assert_equal(out.tool_item, -1, "caller scratch did not alias the prior bank")


func test_cold_body_extent_includes_all_load_and_recovery_variants_only() -> void:
	"""A broadphase cannot index only the currently equipped smaller actor variant."""
	var first: Dictionary = _row(Profiles.MODE_STAND)
	var second: Dictionary = _row(Profiles.MODE_WALK)
	second.fields[14] = 3
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes[1] = PackedInt32Array([-999, -500, -999, 999, 0, 999, Profiles.STANCE_SUPPORT])
	boxes.append_array(_boxes())
	boxes[3] = PackedInt32Array([-400, -30, -350, 800, 1700, 350, Profiles.BODY_HELD_LOAD])
	boxes[5] = PackedInt32Array([-500, -40, -450, 900, 1800, 450, Profiles.TURN_RECOVERY])
	assert_equal(_load(_image([first, second], boxes)), &"", "two exact source variants")
	var extent: PackedInt32Array = PackedInt32Array([9, 9, 9, 9, 9, 9])
	assert_equal(_profiles.body_extent_into(1, extent), &"", "cold exact catalog extent")
	assert_equal(extent, PackedInt32Array([-500, -40, -450, 900, 1800, 450]), "all collision roles, no support inflation")
	assert_equal(_load(_image([first], _boxes(), 2), 2), &"", "new immutable content")
	assert_equal(_profiles.body_extent_into(1, extent), &"PROFILE_SELECTION_STALE", "old hash-grid needs refresh")
	assert_equal(extent, PackedInt32Array([-500, -40, -450, 900, 1800, 450]), "stale refusal preserves result")
	assert_equal(_profiles.body_extent_into(2, extent), &"", "fresh replacement extent")
	assert_equal(extent, PackedInt32Array([-128, -20, -128, 128, 900, 128]), "replacement does not retain old bounds")


func _patch_case(axis: int = 1) -> Dictionary:
	"""Synthetic source patch, explicitly distinct from production trajectory or contact qualification."""
	var row: Dictionary = _row(Profiles.MODE_WORK)
	row.fields[6] = _items.compiled_id(&"tool")
	row.fields[7] = Gear.MANUFACTURE_BASIC
	row.fields[10] = Profiles.YAW_EXACT
	row.fields[15] = 7
	row.fields[16] = Jobs.JOB_KIND_BUILD
	row.fields[17] = Profiles.CONTACT_ANCHOR_AND_PATCH
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append(PackedInt32Array([-128, -20, -128, 128, 1000, 256, Profiles.WORK_APPROACH]))
	boxes.append(PackedInt32Array([-128, 0, -256, 128, 1000, 128, Profiles.WORK_STROKE]))
	boxes.append(PackedInt32Array([0, 0, 0, 0, 0, 0, Profiles.CONTACT_POINT]))
	var patch: PackedInt32Array = PackedInt32Array([-5, -5, -5, 5, 5, 5, Profiles.CONTACT_PATCH])
	patch[axis] = 0
	patch[axis + 3] = 0
	boxes.append(patch)
	return {"row": row, "boxes": boxes}


func test_planar_source_patch_is_readable_on_every_normal_axis_with_exact_actual_work() -> void:
	"""The planar source witness survives decode/read, while actual Work still owns productive selection."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "real claimed tool")
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	var out: Profiles.Selection = Profiles.Selection.new()
	var patch: Profiles.Box = Profiles.Box.new()
	for axis: int in 3:
		var fixture: Dictionary = _patch_case(axis)
		assert_equal(_load(_image([fixture.row], fixture.boxes, axis + 1), axis + 1), &"", "explicit planar row")
		assert_equal(_profiles.descriptor_into(0, axis + 1, descriptor), &"", "static before contact")
		assert_equal(descriptor.contact_kind, Profiles.CONTACT_ANCHOR_AND_PATCH, "stronger contact contract")
		assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, NULL_REF, out), &"", "real work identity")
		assert_equal(_profiles.box_into(0, 1, axis + 1, 6, patch), &"", "caller-owned patch")
		assert_equal(patch.role, Profiles.CONTACT_PATCH, "no physical volume alias")
		assert_equal(patch.low[axis], patch.high[axis], "exact face plane")
		assert_equal(patch.low[(axis + 1) % 3], -5, "outward lower span")
		assert_equal(patch.high[(axis + 2) % 3], 5, "outward upper span")
	assert_true(_work.release_tool_claim(_slot).ok, "release real claim")


func test_patch_refuses_volume_line_point_inversion_and_unknown_role_without_replacement() -> void:
	"""Exactly one zero axis is required; failed replacements preserve the whole previous catalog."""
	var fixture: Dictionary = _patch_case()
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"", "prior complete content")
	var bad: Array[PackedInt32Array] = [PackedInt32Array([-5, -5, -5, 5, 5, 5, Profiles.CONTACT_PATCH]),
		PackedInt32Array([0, 0, -5, 0, 0, 5, Profiles.CONTACT_PATCH]),
		PackedInt32Array([0, 0, 0, 0, 0, 0, Profiles.CONTACT_PATCH]),
		PackedInt32Array([6, 0, -5, 5, 0, 5, Profiles.CONTACT_PATCH])]
	for malformed: PackedInt32Array in bad:
		fixture.boxes[6] = malformed
		assert_equal(_load(_image([fixture.row], fixture.boxes, 2), 2), &"PROFILE_BOX_FORMAT", "not one finite face patch")
		assert_equal(_profiles.content_revision(), 1, "old live bank retained")
	fixture.boxes[6] = PackedInt32Array([-5, 0, -5, 5, 0, 5, 7])
	assert_equal(_load(_image([fixture.row], fixture.boxes, 2), 2), &"PROFILE_BOX_ROLE", "unknown role")
	var out: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.box_into(0, 1, 1, 6, out), &"", "prior patch still readable")
	assert_equal(out.low, Vector3i(-5, 0, -5), "no rejected staging alias")


func test_patch_requires_exact_kind_count_and_coplanar_contained_anchor() -> void:
	"""A legacy anchor never silently acquires patch semantics, nor may a stronger witness be omitted."""
	var fixture: Dictionary = _patch_case()
	fixture.row.fields[17] = Profiles.CONTACT_ANCHOR_ONLY
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"PROFILE_CONTACT_PATCH_KIND", "legacy kind cannot carry patch")
	fixture.row.fields[17] = Profiles.CONTACT_ANCHOR_AND_PATCH
	fixture.row.fields[15] = 6
	assert_equal(_load(_image([fixture.row], fixture.boxes.slice(0, 6))), &"PROFILE_CONTACT_PATCH_MISSING", "witness missing")
	fixture.row.fields[15] = 8
	fixture.boxes.append(fixture.boxes[6])
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"PROFILE_CONTACT_PATCH_MISSING", "duplicate witness")
	fixture.boxes.pop_back()
	fixture.row.fields[15] = 7
	fixture.boxes[5] = PackedInt32Array([0, 1, 0, 0, 1, 0, Profiles.CONTACT_POINT])
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"PROFILE_CONTACT_PATCH_ANCHOR", "parallel wrong plane")
	fixture.boxes[5] = PackedInt32Array([6, 0, 0, 6, 0, 0, Profiles.CONTACT_POINT])
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"PROFILE_CONTACT_PATCH_ANCHOR", "point outside source patch")
	fixture.boxes[5] = PackedInt32Array([5, 0, 5, 5, 0, 5, Profiles.CONTACT_POINT])
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"", "closed patch edge is explicit")


func test_patch_is_excluded_from_body_broadphase_and_stale_read_preserves_caller() -> void:
	"""Planar contact metadata does not enlarge a body/turn search or bypass full content identity."""
	var fixture: Dictionary = _patch_case()
	fixture.boxes[6] = PackedInt32Array([-20000, 0, -20000, 20000, 0, 20000, Profiles.CONTACT_PATCH])
	assert_equal(_load(_image([fixture.row], fixture.boxes)), &"", "deliberately wider synthetic patch")
	var extent: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	assert_equal(_profiles.body_extent_into(1, extent), &"", "bounded collision-role union")
	assert_equal(extent, PackedInt32Array([-128, -20, -128, 128, 900, 128]), "patch adds no occupied volume")
	var out: Profiles.Box = Profiles.Box.new()
	out.low = Vector3i(13, 17, 19)
	out.high = Vector3i(23, 29, 31)
	out.role = 99
	assert_equal(_profiles.box_into(0, 1, 2, 6, out), &"PROFILE_SELECTION_STALE", "exact revision mandatory")
	assert_equal(out.low, Vector3i(13, 17, 19), "low unchanged")
	assert_equal(out.high, Vector3i(23, 29, 31), "high unchanged")
	assert_equal(out.role, 99, "role unchanged")


func test_cold_body_extent_refusal_never_resizes_or_overwrites_scratch() -> void:
	"""Absent content and malformed output cannot masquerade as a zero-sized resident."""
	var extent: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
	assert_equal(_profiles.body_extent_into(0, extent), &"PROFILE_SELECTION_STALE", "unloaded")
	assert_equal(extent, PackedInt32Array([1, 2, 3, 4, 5, 6]), "unloaded output unchanged")
	var short_out: PackedInt32Array = PackedInt32Array([7])
	assert_equal(_profiles.body_extent_into(1, short_out), &"PROFILE_EXTENT_FORMAT", "exact six required")
	assert_equal(short_out, PackedInt32Array([7]), "wrong-shaped output not resized")


func _work_choices() -> Dictionary:
	"""Two independently pinned synthetic WORK sources and the unchanged actual-tool movement key."""
	var moving: Dictionary = _row()
	moving.fields[Profiles.F_TOOL] = _items.compiled_id(&"tool")
	moving.fields[Profiles.F_TOOL_VARIANT] = Gear.MANUFACTURE_BASIC
	var first: Dictionary = _patch_case(1)
	var second: Dictionary = _patch_case(2)
	first.row.fields[Profiles.F_FIRST_BOX] = 3
	first.row.longs[Profiles.L_REVISION] = 3
	second.row.fields[Profiles.F_FIRST_BOX] = 10
	second.row.fields[Profiles.F_SOURCE] = 1
	second.row.longs[Profiles.L_REVISION] = 7
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append_array(first.boxes)
	boxes.append_array(second.boxes)
	var rows: Array[Dictionary] = [moving, first.row, second.row]
	return {"rows": rows, "boxes": boxes}


func test_exact_work_choice_uses_each_source_and_ordinary_query_refuses_ambiguity() -> void:
	"""The same actual worker/Job/tool may fit two contacts; row order cannot choose the intended face."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "actual assigned tool claim")
	var fixture: Dictionary = _work_choices()
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 1, 2)), &"", "both WORK sources admitted")
	var out: Profiles.Selection = Profiles.Selection.new()
	assert_equal(_query(out, tool), &"", "ordinary movement remains unique")
	assert_equal(out.profile_id, 0, "same movement row")
	assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, tool, out), &"PROFILE_SELECTION_AMBIGUOUS", "no first-match work")
	assert_equal(out.profile_id, 0, "ambiguous refusal preserves prior movement output")
	_assert_exact_work_choice(job.ref, 1, 3, 0, tool, out)
	_assert_exact_work_choice(job.ref, 2, 7, 1, tool, out)
	var patch: Profiles.Box = Profiles.Box.new()
	assert_equal(_profiles.box_into(2, 7, 1, 6, patch), &"", "selected source owns its contact")
	assert_equal(patch.low.z, patch.high.z, "second contact has its own plane")
	assert_equal(_profiles.query_into(_worker, job.ref, 3, 0, -1, tool, out), &"PROFILE_SELECTION_AMBIGUOUS", "prior explicit choice is not cached")
	assert_equal(out.profile_id, 2, "refusal preserves exact prior source")
	assert_true(_work.release_tool_claim(_slot).ok, "release actual claim")


func _assert_exact_work_choice(job: Vector2i, row: int, version: int, source: int,
		tool: Vector2i, out: Profiles.Selection) -> void:
	"""Full source/worker/job/tool identity is preserved by a successful explicit match."""
	assert_equal(_profiles.query_work_profile_into(_worker, job, row, version, 1, 0, -1, NULL_REF, out), &"", "explicit work source")
	assert_equal(out.profile_id, row, "exact row")
	assert_equal(out.profile_revision, version, "exact source row revision")
	assert_equal(out.content_revision, 1, "exact enclosing source revision")
	assert_equal(out.source_id, source, "distinct source digest identity")
	assert_equal(out.worker, _worker, "actual resident full reference")
	assert_equal(out.job, job, "actual assigned job")
	assert_equal(out.tool, tool, "actual equipped claimed tool")


func test_explicit_work_selection_refuses_stale_pins_wrong_mode_and_actual_pose() -> void:
	"""An explicit selection is an exact additional constraint, never a bypass or automatic fallback."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "actual claim")
	var fixture: Dictionary = _work_choices()
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 1, 2)), &"", "two sources")
	var out: Profiles.Selection = Profiles.Selection.new()
	_assert_exact_work_choice(job.ref, 1, 3, 0, tool, out)
	for pins: Vector3i in [Vector3i(-1, 3, 1), Vector3i(3, 3, 1), Vector3i(1, 7, 1), Vector3i(1, 3, 2)]:
		assert_equal(_profiles.query_work_profile_into(_worker, job.ref, pins.x, pins.y, pins.z, 0, -1, tool, out),
			&"PROFILE_SELECTION_STALE", "wrong exact source tuple")
		assert_equal(out.profile_id, 1, "stale refusal preserves selection")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 0, 1, 1, 0, -1, tool, out),
		&"PROFILE_WORK_SELECTION_REQUIRED", "movement cannot impersonate productive contact")
	assert_true(_transforms.set_yaw(_worker, 1), "actual nonmatching yaw")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 2, 7, 1, 0, -1, tool, out),
		&"PROFILE_VARIANT_UNAUTHORED", "explicit row cannot round current yaw")
	assert_equal(out.yaw, 0, "refused actual-pose read did not overwrite output")
	assert_equal(_query(out, tool), &"", "ordinary all-yaw movement still matches")
	assert_equal(out.yaw, 1, "movement keeps exact current yaw")
	assert_true(_work.release_tool_claim(_slot).ok, "release actual claim")


func test_selected_work_retains_real_job_claim_and_physical_variant_checks() -> void:
	"""A different source cannot hide real manufacture, stale equipment or removed assignment."""
	var tool: Vector2i = _equip()
	var job: Jobs.OpResult = _actual_work_job()
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "actual claim")
	var fixture: Dictionary = _work_choices()
	fixture.rows[2].fields[Profiles.F_TOOL_VARIANT] = Gear.MANUFACTURE_IRON
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 1, 2)), &"", "distinct authored physical sources")
	var out: Profiles.Selection = Profiles.Selection.new()
	_assert_exact_work_choice(job.ref, 1, 3, 0, tool, out)
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 2, 7, 1, 0, -1, tool, out),
		&"PROFILE_VARIANT_UNAUTHORED", "iron source cannot fit actual basic tool or choose another row")
	assert_equal(out.profile_id, 1, "refused source leaves previous choice")
	assert_true(_work.release_tool_claim(_slot).ok, "remove actual equipped work claim")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 1, 3, 1, 0, -1, tool, out),
		&"PROFILE_TOOL_CLAIM", "exact source does not replace Gear authority")
	assert_true(_work.claim_tool_for_work(_slot, tool).ok, "restore actual claim")
	assert_true(_jobs.release_worker(_slot).ok, "remove actual Job assignment")
	assert_equal(_profiles.query_work_profile_into(_worker, job.ref, 1, 3, 1, 0, -1, tool, out),
		&"PROFILE_JOB_STALE", "selected source does not replace Work authority")
	assert_equal(out.job, job.ref, "refusal preserves prior output")
	assert_true(_work.release_tool_claim(_slot).ok, "release retained actual tool claim")


func test_work_choices_keep_certificate_state_capacity_and_replacement_guards() -> void:
	"""Allowing contact alternatives does not weaken source qualification or finite key admission."""
	var fixture: Dictionary = _work_choices()
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 1, 2)), &"", "initial exact sources")
	fixture.rows[2].flags[0] = Profiles.CERT_SOURCE
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 2, 2), 2), &"PROFILE_CERTIFICATE_REQUIRED", "second source still needs full proof")
	fixture.rows[2].flags[0] = Profiles.CERT_REQUIRED
	fixture.rows[2].fields[Profiles.F_STATES] = Profiles.STATE_WORK
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 2, 2), 2), &"PROFILE_STATE_MISSING", "second source still needs complete states")
	fixture.rows[2].fields[Profiles.F_STATES] = 511
	assert_equal(_load(_image(fixture.rows, fixture.boxes, 2, 2), 2), &"", "new immutable source version")
	var out: Profiles.Selection = Profiles.Selection.new()
	out.source_id = 77
	assert_equal(_profiles.query_work_profile_into(_worker, NULL_REF, 1, 3, 1, 0, -1, NULL_REF, out),
		&"PROFILE_SELECTION_STALE", "old exact row cannot survive replacement")
	assert_equal(out.source_id, 77, "stale source refuses before output writes")
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in Profiles.MAX_KEY_VARIANTS + 1:
		var variant: Dictionary = _patch_case()
		variant.row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		rows.append(variant.row)
		boxes.append_array(variant.boxes)
	assert_equal(_load(_image(rows, boxes, 3), 3), &"PROFILE_KEY_CAPACITY", "no hidden unbounded WORK scan")
	rows[16].flags[1] = Profiles.POLICY_SOURCE_WORK
	var legacy_source: PackedByteArray = _image(rows, boxes, 3)
	legacy_source.encode_u32(8, 2)
	assert_equal(_load(legacy_source, 3), &"PROFILE_KEY_CAPACITY", "seventeenth explicit legacy WORK is still forbidden")
	assert_equal(_profiles.content_revision(), 2, "refused overcapacity preserves live source")


func _haul_grip_case() -> Dictionary:
	"""Synthetic format fixture only: a tool-free HAUL row whose curved grip is a separate certificate (ADR1198)."""
	var row: Dictionary = _row(Profiles.MODE_WORK)
	row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
	row.fields[Profiles.F_BOX_COUNT] = 5
	row.fields[Profiles.F_WORK_KIND] = Jobs.JOB_KIND_HAUL
	row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_HAUL_GRIP
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append(PackedInt32Array([-128, -20, -256, 128, 900, 128, Profiles.WORK_APPROACH]))
	boxes.append(PackedInt32Array([-100, 0, -600, 100, 500, -300, Profiles.WORK_STROKE]))
	return {"row": row, "boxes": boxes}


func test_haul_grip_row_needs_all_body_roles_and_no_planar_contact() -> void:
	"""ADR1198: the two-hand grip is never a planar point/patch alias, and the row stays tool-free HAUL."""
	assert_equal(_load(_image([_haul_grip_case().row], _haul_grip_case().boxes)), &"", "tool-free certified HAUL grip row")
	var planar: Dictionary = _haul_grip_case()
	planar.row.fields[Profiles.F_BOX_COUNT] = 6
	planar.boxes.append(PackedInt32Array([0, 0, -400, 0, 0, -400, Profiles.CONTACT_POINT]))
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(4, 16, 2, Profiles.ARENA_BYTES), &"", "fresh arena")
	assert_equal(_bind(_profiles), &"", "actual owners")
	assert_equal(_load(_image([planar.row], planar.boxes)), &"PROFILE_ROLE_MISSING", "no planar contact alias")
	var tooled: Dictionary = _haul_grip_case()
	tooled.row.fields[Profiles.F_TOOL] = _items.compiled_id(&"tool")
	tooled.row.fields[Profiles.F_TOOL_VARIANT] = Gear.MANUFACTURE_BASIC
	assert_equal(_load(_image([tooled.row], tooled.boxes)), &"PROFILE_ROLE_MISSING", "hauling is tool-free")
	var build: Dictionary = _haul_grip_case()
	build.row.fields[Profiles.F_WORK_KIND] = Jobs.JOB_KIND_BUILD
	assert_equal(_load(_image([build.row], build.boxes)), &"PROFILE_ROLE_MISSING", "only HAUL work grips stock")


func test_appended_source_need_not_sort_against_earlier_sources() -> void:
	"""ADR1198: key order binds within a source; a later source never renumbers earlier rows."""
	var walk: Dictionary = _row(Profiles.MODE_WALK)
	var stand: Dictionary = _row(Profiles.MODE_STAND)
	stand.fields[Profiles.F_SOURCE] = 1
	stand.fields[Profiles.F_FIRST_BOX] = 3
	var boxes: Array[PackedInt32Array] = _boxes()
	boxes.append_array(_boxes())
	assert_equal(_load(_image([walk, stand], boxes, 1, 2)), &"", "lower key in a later source is accepted")
	_profiles = Profiles.new()
	assert_equal(_profiles.configure(4, 16, 2, Profiles.ARENA_BYTES), &"", "fresh arena")
	assert_equal(_bind(_profiles), &"", "actual owners")
	stand.fields[Profiles.F_SOURCE] = 0
	assert_equal(_load(_image([walk, stand], boxes, 1, 2)), &"PROFILE_KEY_ORDER", "same-source order still binds")
