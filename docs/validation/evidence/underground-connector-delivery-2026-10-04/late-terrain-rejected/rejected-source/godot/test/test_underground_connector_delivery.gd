extends "res://test/framework/test_case.gd"
## Actual geometry/economy/Jobs/Work/Inventory; all added HAUL motion certificates below are explicitly synthetic.

const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const WorkpieceTests := preload("res://test/test_underground_connector_workpieces.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const Planner := preload("res://scripts/core/haul_planner.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")
const Work := preload("res://scripts/core/work.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const OLD_TO_NEW: Array[int] = [1, 3, 6, 7, 8, 9, 10, 11]

class LateTerrain extends Prefix.GroundTests.CountedTerrain:
	var guard_inventory: Inventory = null
	var transfer_probe: Callable = Callable()
	var fired: int = 0

	func _local_tiles_refusal(bounds: PackedInt32Array, purpose: int) -> StringName:
		"""An actual late Terrain observation may mutate the real worker after the initial pose check."""
		var code: StringName = super._local_tiles_refusal(bounds, purpose)
		if guard_inventory != null and guard_inventory._attesting and transfer_probe.is_valid():
			var probe: Callable = transfer_probe
			transfer_probe = Callable()
			fired += 1
			probe.call()
		return code

class World extends WorkpieceTests.DeliveryWorld:

	func _actual_space(_obstruction: int) -> void:
		"""Use the same actual empty-World composition with one late observation probe, never fake geometry."""
		_routes = Routes.new(_residents, _transforms)
		_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0), Vector3i(256, 48, 256), 8192, 6144, check_budget), &"", "actual finite Domain")
		_owner = Owner.new(_sources)
		assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual empty sparse owner")
		_locations = Prefix.GroundTests.WatchedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory, _owner, _sources, _budget, location_capacity, 228 * location_capacity + 256), &"", "actual endpoints")
		var terrain: LateTerrain = LateTerrain.new()
		terrain.guard_inventory = _inventory
		_terrain = terrain
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual natural terrain")
		_actual_catalog(domain)

	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Keep all accepted fixture profiles, inserting no-tool WALK/CARRY and complete unloaded/loaded HAUL WORK."""
		var source: PackedByteArray = super._profile_image(identity)
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(16, 96, 3, Profiles.ARENA_BYTES), &"", "finite expanded synthetic source arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "same actual source readers")
		var rows: Array[PackedByteArray] = []
		var boxes: Array[PackedByteArray] = []
		var cursor: int = 0
		for index: int in 12:
			var old: int = OLD_TO_NEW.find(index)
			var row: PackedByteArray = source.slice(96 + maxi(old, 0) * Profiles.PROFILE_WIRE_BYTES,
				96 + (maxi(old, 0) + 1) * Profiles.PROFILE_WIRE_BYTES)
			var primitives: PackedByteArray = _new_boxes(index) if old < 0 else _old_boxes(source, row)
			if old < 0: _new_row(row, index)
			row.encode_s32(Profiles.F_FIRST_BOX * 4, cursor)
			@warning_ignore("integer_division")
			cursor += primitives.size() / 28
			rows.append(row); boxes.append(primitives)
		var bytes: PackedByteArray = source.slice(0, 96)
		bytes.encode_u32(20, 12); bytes.encode_u32(24, cursor); bytes.encode_u32(28, 3)
		bytes.append_array("6464646464646464646464646464646464646464646464646464646464646464".hex_decode())
		for row: PackedByteArray in rows: bytes.append_array(row)
		for primitive: PackedByteArray in boxes: bytes.append_array(primitive)
		bytes.append_array("UGPEND01".to_ascii_buffer())
		return bytes

	func _old_boxes(source: PackedByteArray, row: PackedByteArray) -> PackedByteArray:
		"""Copy the whole original source primitive range, without editing its geometry or source identity."""
		var start: int = 96 + 8 * Profiles.PROFILE_WIRE_BYTES + row.decode_s32(Profiles.F_FIRST_BOX * 4) * 28
		return source.slice(start, start + row.decode_s32(Profiles.F_BOX_COUNT * 4) * 28)

	func _new_row(row: PackedByteArray, index: int) -> void:
		"""The independent synthetic program explicitly covers the actual wood cargo and HAUL Job kind."""
		row.encode_s32(Profiles.F_SOURCE * 4, 2 if index >= 4 else 0)
		row.encode_s32(Profiles.F_TOOL * 4, -1); row.encode_s32(Profiles.F_TOOL_VARIANT * 4, -1)
		row.encode_s32(Profiles.F_CARGO * 4, _items.compiled_id(&"wood") if index == 2 or index == 5 else -1)
		row.encode_s32(Profiles.F_CARGO_VARIANT * 4, -1)
		row.encode_s32(Profiles.F_MODE * 4, Profiles.MODE_WORK if index >= 4 else (Profiles.MODE_CARRY if index == 2 else Profiles.MODE_WALK))
		if index >= 4: row.encode_s32(Profiles.F_YAW_KIND * 4, Profiles.YAW_EXACT)
		if index == 5: row.encode_s32(Profiles.F_YAW * 4, 49152)
		row.encode_s32(Profiles.F_STATES * 4, 511)
		row.encode_s32(Profiles.F_BOX_COUNT * 4, 7 if index >= 4 else 3)
		row.encode_s32(Profiles.F_WORK_KIND * 4, Jobs.JOB_KIND_HAUL if index >= 4 else -1)
		row.encode_s32(Profiles.F_CONTACT_KIND * 4, Profiles.CONTACT_ANCHOR_AND_PATCH if index >= 4 else Profiles.CONTACT_NONE)
		row.encode_s64(80, 1 if index == 2 or index == 5 else 0)
		row.encode_s64(88, 2400 if index == 2 or index == 5 else 0)

	func _new_boxes(index: int) -> PackedByteArray:
		"""Synthetic full motion fits the independently real surface air/support; no part of the source is discarded."""
		var bytes: PackedByteArray = PackedByteArray()
		for role: int in (7 if index >= 4 else 3):
			var box: PackedInt32Array = PackedInt32Array([-128, -1, -128, 128, 900, 128])
			if role == Profiles.STANCE_SUPPORT: box[4] = 0
			if role == Profiles.CONTACT_POINT: box = PackedInt32Array([0, 0, 0, 0, 0, 0])
			if role == Profiles.CONTACT_PATCH: box = PackedInt32Array([-8, 0, -8, 8, 0, 8])
			box.append(role)
			Prefix.CatalogTests._append_row(bytes, box)
		return bytes

	func _load_catalog(revision: int) -> StringName:
		"""Four explicit ground pace selectors reuse the adopted movement cap, without adding a stair route."""
		var bytes: PackedByteArray = Prefix.Source.catalog_image(spec, revision)
		bytes.encode_u32(44, 4)
		bytes.resize(bytes.size() - 44)
		for profile: int in [0, 1, 2, 3]:
			Prefix.CatalogTests._append_row(bytes, PackedInt32Array([profile, -1, 0, 0, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(WorldTests.TEMP, _write(WorldTests.TEMP, bytes), revision)

class Fixture extends WorkpieceTests.DeliveryFixture:

	func _handling_profile() -> int:
		"""Preserve the distinct existing set-down program after insertion of explicit HAUL roles."""
		return 10

	func _assign_installation_worker(job: int, endpoint: Vector2i) -> void:
		"""The original real primary BUILD Job selects the remapped complete INSTALL source before hauling."""
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		assert_true(_world._jobs.assign_worker(worker, job).ok, "actual installation assignment")
		assert_true(_world._work.claim_tool_for_work(worker, _tool).ok, "actual equipped Gear claim")
		_move_existing_actor(job, endpoint, 0)
		assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), 6, 1, 2, 0, -1, _tool), &"", "remapped INSTALL source")

	func _make_world() -> Prefix.ActualWorld:
		"""Only immutable synthetic motion content changes; every World/paid-phase/Inventory owner is real."""
		return World.new()

	func _frontier_stations(bytes: PackedByteArray) -> void:
		"""Remap the existing exact source station selectors after ordered profile insertion."""
		var start: int = bytes.size()
		super._frontier_stations(bytes)
		for station: int in 8:
			var offset: int = start + station * 80 + 20
			bytes.encode_s32(offset, OLD_TO_NEW[bytes.decode_s32(offset)])

	func _append_endpoint(bytes: PackedByteArray, kind: int, assembly: int, datum: int, role: int, point: Vector3i) -> void:
		"""Existing Entry source retains its tool-bearing WALK row; hauling uses separately explicit no-tool rows."""
		super._append_endpoint(bytes, kind, assembly, datum, role, point)
		bytes.encode_s32(bytes.size() - 12, 1)

	func _select_phase_actor(job: int, ordinal: int) -> void:
		"""Actual phase movements and paid work are preserved while selecting the remapped complete BUILD source."""
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		var profile: int = 7 if ordinal % 2 == 0 else 9
		if _world._routes._resident_ref(worker) != NULL_REF:
			_move_existing_actor(job, _endpoints[3 + ordinal], 49152 if ordinal % 2 == 0 else 16384)
			assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), profile, 1, 2, 0, -1, _tool), &"", "actual phase profile")
			return
		var point: Vector3i = ORIGIN + Source.side_root(ordinal)
		assert_true(_world._transforms.place(_world._worker, point.x, point.y, point.z, 49152 if ordinal % 2 == 0 else 16384), "fixture initial arrival")
		assert_equal(_world._routes.admit_work_actor(_world._worker, _world._jobs.ref_of(job), _endpoints[3 + ordinal], profile, 1, 2, 0, -1, _tool), &"", "actual initial phase actor")

var _fixture: Fixture = null
var _delivery: Delivery = null
var _planner: Planner = null
var _pieces: Workpieces = null
var _project: Vector2i = NULL_REF


func before_each() -> void:
	"""Compose the actual accepted first-prefix owners before any spatial shipment or paid installation."""
	_fixture = Fixture.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual fixture: %s" % _fixture.failures)
	_pieces = Workpieces.new()
	assert_equal(_pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "actual bounded workpieces")
	assert_equal(_pieces.bind_actual(_fixture._placements, _fixture._router, _fixture._paid), &"", "same actual paid owners")
	var builder: WorkpieceTests = WorkpieceTests.new()
	builder._fixture = _fixture
	builder._pieces = _pieces
	assert_equal(builder._load(builder._source_image()), &"", "exact remapped synthetic set-down content")
	assert_equal(_fixture._paid.bind_workpieces(_pieces), &"", "actual reciprocal workpiece composition")
	_planner = Planner.new()
	var world: Prefix.ActualWorld = _fixture._world
	assert_true(_planner.bind(world._inventory, world._pool, world._residents, world._buildings, world._piles, StorePolicy.new(world._buildings, world._inventory)), "actual Planner composition")
	_delivery = Delivery.new()
	assert_equal(_delivery.configure(_fixture._placements, _fixture._source, _planner, world._binding, world._work, Delivery.RESERVED_BYTES), &"", "one bounded Delivery")


func after_each() -> void:
	"""No synchronous request, transfer transaction or diagnostic owner reference escapes a test."""
	assert_false(_delivery._busy, "no escaped delivery packet")
	_delivery = null; _planner = null; _pieces = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual fixture cleanup: %s" % _fixture.failures)
	_fixture = null


func _ready() -> bool:
	"""The four real L0 cubes finish with actual stock/Work/companions before the material request is admitted."""
	if _fixture._confirm_prefix() == NULL_REF or not _fixture._complete_l0_cubes():
		assert_true(false, "actual four paid cubes: %s" % _fixture.failures)
		return false
	_project = _fixture._open_installation(0)
	if _project == NULL_REF:
		assert_true(false, "actual order: %s" % _fixture.failures)
		return false
	if _fixture._installation_job(_project, _fixture._endpoints[0]) < 0: return false
	assert_true(_fixture._router.bind_material_container(_project, _fixture._storage).ok, "actual selected material endpoint")
	var worker: int = _fixture._world._residents.directory().get_typed_row(_fixture._world._worker)
	assert_true(_fixture._world._work.release_tool_claim(worker).ok, "release BUILD tool claim before hauling")
	assert_true(_fixture._world._jobs.release_worker(worker).ok, "release primary assignment while its material is fetched")
	assert_true(_fixture._world._gear.unequip(_fixture._tool, _fixture._storage, false).ok, "actual no-tool handling, no fake equipment state")
	return failures.is_empty() and _fixture.failures.is_empty()


func _job() -> Jobs.OpResult:
	"""Use only Directory Project and Job handles; Inventory and Location references stay in their own owners."""
	var world: Prefix.ActualWorld = _fixture._world
	var made: Jobs.OpResult = world._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, Planner.HAUL_LOAD_MILLI_WU, 0)
	assert_true(made.ok, "real HAUL Job")
	assert_true(world._jobs.set_requester(made.value, _project).ok, "real Project source")
	assert_true(world._jobs.set_source(made.value, _project).ok, "actual Directory Project request owner")
	assert_true(world._jobs.assign_worker(world._residents.directory().get_typed_row(world._worker), made.value).ok, "actual solo assignment")
	assert_equal(world._routes.refresh_actor(world._worker, made.ref, Profiles.MODE_WALK, 0, -1, NULL_REF), &"", "source-certified no-tool WALK")
	return made


func _walk(job: int, destination: Vector2i, mode: int) -> bool:
	"""Travel changes actual position over complete certified ground spans, without work or inventory writes."""
	var world: Prefix.ActualWorld = _fixture._world
	assert_equal(world._routes.refresh_actor(world._worker, world._jobs.ref_of(job), mode, 0, -1, NULL_REF), &"", "actual selected travel source")
	assert_equal(world._routes.request_route(world._worker, destination, 0), &"", "actual route request")
	var actor: Routes.Actor = Routes.Actor.new()
	for tick: int in 1000:
		world._routes.advance_tick(tick)
		assert_equal(world._routes.read_actor_into(world._worker, actor), &"", "actual actor")
		if actor.phase == Routes.PHASE_IDLE or actor.phase == Routes.PHASE_HELD: break
	assert_equal(actor.location, destination, "actual arrival is required")
	return failures.is_empty()


func _handling(job: int, profile: int) -> int:
	"""Both actual phases use Work, with the second remaining in HAUL_OUTPUT throughout every accepted tick."""
	var world: Prefix.ActualWorld = _fixture._world
	if profile == 4:
		assert_equal(world._binding.turn_actor(world._binding, world._worker, world._jobs.ref_of(job), 0, Prefix.Space.MAX_CHECKS), &"", "actual supported turn before handling")
	assert_equal(world._routes.refresh_work_actor(world._worker, world._jobs.ref_of(job), profile, 1, 2, 0, -1, NULL_REF), &"", "exact synthetic HAUL source")
	if profile == 4: assert_equal(_delivery.begin_load(world._jobs.ref_of(job)), &"", "actual source arrival starts loading")
	var total: int = 0
	for tick: int in 500:
		var result: Work.TickResult = world._work.tick_solo(job)
		assert_true(result.ok, "actual handling Work: %s" % result.error)
		if not result.ok: return total
		total += result.accepted_mwu
		assert_equal(world._jobs._state[job], Jobs.JOB_STATE_WORK if profile == 4 else Jobs.JOB_STATE_HAUL_OUTPUT, "no synthetic completion before goods commit")
		if result.remaining_mwu == 0: break
	return total


func test_actual_capacity_limited_spatial_shipment_uses_haul_output_unload() -> void:
	"""One actual mouse moves2,400milli wood, earning2,000+2,000mWU once and conserving all finite material."""
	if not _ready(): return
	var job: Jobs.OpResult = _job()
	var result: Inventory.OpResult = _delivery.admit(job.ref, _fixture.remote_wood, 4000, 100000)
	assert_true(result.ok, "atomic actual spatial admission: %s" % result.error)
	if not result.ok: return
	assert_equal(result.value, 2400, "ordinary12kg mouse limits payload")
	assert_true(_fixture._world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel phase")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(_handling(job.value, 4), 2000, "actual load work")
	result = _delivery.load_payload(job.ref)
	assert_true(result.ok, "actual guarded load: %s" % result.error)
	if not result.ok: return
	var carried: Vector2i = result.ref
	assert_equal(_fixture._world._inventory.lot_quantity_milli(carried), 2400, "real satchel goods")
	assert_false(_fixture._world._work.tick_solo(job.value).ok, "departing source is not an unload contact")
	if not _walk(job.value, _fixture._endpoints[1], Profiles.MODE_CARRY): return
	assert_equal(_handling(job.value, 5), 2000, "actual HAUL_OUTPUT unload work")
	result = _delivery.unload_payload(job.ref)
	assert_true(result.ok, "actual guarded unload: %s" % result.error)
	assert_equal(_fixture._world._jobs._state[job.value], Jobs.JOB_STATE_COMPLETE, "goods commit completes the Job")
	assert_false(Delivery.handles_job(_delivery, job.ref), "existing Planner receipt is cleared")
	assert_equal(_fixture._world._inventory.lot_quantity_milli(_fixture.remote_wood), 1600, "undelivered stock remains real")
	assert_false(_delivery.unload_payload(job.ref).ok, "no repeated delivery")


func test_wrong_owner_binding_refuses_without_allocating_and_valid_retry_binds() -> void:
	"""A mismatched existing owner tuple creates no new packet or alternate economic ledger."""
	var other: Delivery = Delivery.new()
	assert_equal(other.configure(_fixture._placements, _fixture._source, Planner.new(), _fixture._world._binding,
		_fixture._world._work, Delivery.RESERVED_BYTES), Delivery.REFUSE_BINDING, "foreign Planner refuses")
	assert_equal(other._frame.size(), 0, "no speculative packet allocation")
	assert_true(other._placements == null and other._planner == null, "failed initialization retains no partial owner tuple")


func test_final_terrain_observer_cannot_move_worker_then_commit_loading() -> void:
	"""A real Terrain override armed only inside Inventory attestation must not escape the final worker proof."""
	if not _ready(): return
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "real shipment admission")
	assert_true(_fixture._world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual travel phase")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(_handling(job.value, 4), 2000, "real load work before probe")
	var before: Array[PackedByteArray] = _fixture._economic_image()
	var terrain: LateTerrain = _fixture._world._terrain as LateTerrain
	terrain.transfer_probe = _displace_transfer_worker
	var result: Inventory.OpResult = _delivery.load_payload(job.ref)
	assert_false(result.ok, "late successful Terrain callback cannot authorize departed worker")
	assert_equal(_fixture._economic_image(), before, "goods, claims, Work, XP and assignment unchanged")


func _displace_transfer_worker() -> void:
	"""Change only the actual Transform through its public owner after the copied pose was accepted."""
	var selected: Profiles.Selection = _delivery._selection
	assert_true(_fixture._world._transforms.place(_fixture._world._worker, selected.x + 64, selected.y, selected.z, selected.yaw), "actual late movement")
