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
const Clock := preload("res://scripts/core/sim_clock.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const TransferContract := preload("res://scripts/core/haul_transfer_contract.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const OLD_TO_NEW: Array[int] = [1, 3, 6, 7, 8, 9, 10, 11]

class SeedObserver extends RefCounted:
	var probe: Callable = Callable()
	var fired: int = 0

	func refuses_seed_consumption(_lot: Vector2i) -> bool:
		"""The actual Inventory staging observer can change world facts but supplies no spatial permission."""
		if probe.is_valid():
			var callback: Callable = probe
			probe = Callable()
			fired += 1
			callback.call()
		return false

class ReturningPool extends Pool:
	var probe: Callable = Callable()
	var fired: int = 0

	func transfer_haul_guarded(action: int, job: Vector2i, worker: Vector2i, source_lot: Vector2i,
			destination: Vector2i, original_satchel: Vector2i, reserved_mass_g: int, carry_limit_g: int,
			guard: TransferContract, inventory: Inventory) -> Inventory.OpResult:
		"""The actual guarded transaction succeeds before this outer wrapper changes the original Job."""
		var result: Inventory.OpResult = super.transfer_haul_guarded(action, job, worker, source_lot,
			destination, original_satchel, reserved_mass_g, carry_limit_g, guard, inventory)
		if result.ok and probe.is_valid():
			var callback: Callable = probe
			probe = Callable()
			fired += 1
			callback.call()
		return result

class ReturningPlanner extends Planner:
	var probe: Callable = Callable()
	var fired: int = 0

	func admit_spatial(job: Vector2i, worker: int, source_lot: Vector2i, quantity: int,
			expiry: int, destination: Vector2i, guard: TransferContract) -> Inventory.OpResult:
		"""An outer Planner override runs only after the real claim and Planner receipt are committed."""
		var result: Inventory.OpResult = super.admit_spatial(job, worker, source_lot, quantity, expiry, destination, guard)
		if result.ok and probe.is_valid():
			var callback: Callable = probe
			probe = Callable()
			fired += 1
			callback.call()
		return result

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

class ReturningWorld extends World:

	func _actual_profiles() -> void:
		"""Construct the observed real Pool before any owner binds it; the other source/Work stores are unchanged."""
		_pool = ReturningPool.new(64, Pool.JOB_CAPACITY, 64)
		_piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "actual pile World")
		_carry = Carry.new()
		assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs)
		assert_true(_work.bind_gear(_gear).ok, "actual Work")
		var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
		assert_true(_residents.spatial_profile_identity_into(_worker, identity), "actual worker identity")
		var bytes: PackedByteArray = _profile_image(identity)
		assert_equal(_profiles.load_file(WorldTests.PROFILE_TEMP, _write(WorldTests.PROFILE_TEMP, bytes), 2), &"", "same synthetic source decoder")

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

class ReturningFixture extends Fixture:

	func _make_world() -> Prefix.ActualWorld:
		"""Only the original Pool implementation is observed; no live owner is replaced or rebound."""
		return ReturningWorld.new()

var _fixture: Fixture = null
var _delivery: Delivery = null
var _planner: Planner = null
var _pieces: Workpieces = null
var _clock: Clock = null
var _project: Vector2i = NULL_REF


func before_each() -> void:
	"""Compose the actual accepted first-prefix owners before any spatial shipment or paid installation."""
	assert_equal(_setup(Fixture.new(), Planner.new()), &"", "one bounded Delivery")


func _setup(fixture: Fixture, planner: Planner) -> StringName:
	"""The same cold setup can test a concrete implementation refusal before Delivery allocates its packet."""
	_fixture = fixture
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
	_planner = planner
	var world: Prefix.ActualWorld = _fixture._world
	assert_true(_planner.bind(world._inventory, world._pool, world._residents, world._buildings, world._piles, StorePolicy.new(world._buildings, world._inventory)), "actual Planner composition")
	_delivery = Delivery.new()
	_clock = Clock.new()
	return _delivery.configure(_fixture._placements, _fixture._source, _planner, world._binding, world._work, _clock, Delivery.RESERVED_BYTES)


func after_each() -> void:
	"""No synchronous request, transfer transaction or diagnostic owner reference escapes a test."""
	assert_false(_delivery._busy, "no escaped delivery packet")
	_delivery = null; _planner = null; _pieces = null; _clock = null
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


func _job(mode: int = Profiles.MODE_WALK) -> Jobs.OpResult:
	"""Use only Directory Project and Job handles; Inventory and Location references stay in their own owners."""
	var world: Prefix.ActualWorld = _fixture._world
	var made: Jobs.OpResult = world._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, Planner.HAUL_LOAD_MILLI_WU, 0)
	assert_true(made.ok, "real HAUL Job")
	assert_true(world._jobs.set_requester(made.value, _project).ok, "real Project source")
	assert_true(world._jobs.set_source(made.value, _project).ok, "actual Directory Project request owner")
	assert_true(world._jobs.assign_worker(world._residents.directory().get_typed_row(world._worker), made.value).ok, "actual solo assignment")
	assert_equal(world._routes.refresh_actor(world._worker, made.ref, mode, 0, -1, NULL_REF), &"", "source-certified current ground load")
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
		assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, world._jobs.ref_of(job), 0, Prefix.Space.MAX_CHECKS), &"", "actual supported turn before handling")
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
		_fixture._world._work, _clock, Delivery.RESERVED_BYTES), Delivery.REFUSE_BINDING, "foreign Planner refuses")
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
	var terrain: LateTerrain = _fixture._world._terrain as LateTerrain
	terrain.transfer_probe = _displace_transfer_worker
	var result: Inventory.OpResult = _delivery.load_payload(job.ref)
	assert_true(result.ok, "actual unchanged pose permits the one guarded load")
	assert_equal(terrain.fired, 0, "no late Terrain instance helper runs after the final worker check")


func _displace_transfer_worker() -> void:
	"""Change only the actual Transform through its public owner after the copied pose was accepted."""
	var selected: Profiles.Selection = _delivery._selection
	assert_true(_fixture._world._transforms.place(_fixture._world._worker, selected.x + 64, selected.y, selected.z, selected.yaw), "actual late movement")


func _loaded_job() -> Jobs.OpResult:
	"""Earn real load work and move the finite 2,400 milli-unit payload once through the Inventory owner."""
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "actual shipment admission")
	assert_true(_fixture._world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return job
	assert_equal(_handling(job.value, 4), 2000, "only original load work")
	assert_true(_delivery.load_payload(job.ref).ok, "guarded actual load")
	return job


func test_cancel_carried_goods_repost_partial_payload_without_second_load() -> void:
	"""A cancelled loaded shipment retains goods; a new partial Job delivers 1,000 and keeps 1,400 in the satchel."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var original: Jobs.OpResult = _loaded_job()
	if not failures.is_empty(): return
	var worker: int = world._residents.directory().get_typed_row(world._worker)
	var satchel: Vector2i = world._residents.satchel_of(worker)
	var lot: Vector2i = Vector2i(world._inventory._c_first_lot[satchel.x], 1)
	lot.y = world._inventory._l_generation[lot.x]
	assert_true(_delivery.cancel(original.ref).ok, "atomic cancellation releases claims and grams")
	assert_equal(world._inventory.lot_quantity_milli(lot), 2400, "cancel retains carried goods")
	assert_true(world._jobs.release_worker(worker).ok, "real reassignment after cancellation")
	var next: Jobs.OpResult = _job(Profiles.MODE_CARRY)
	var before_xp: int = world._residents._skill_xp[worker * Work.SKILL_COUNT + Jobs.JOB_KIND_HAUL]
	assert_true(_delivery.admit(next.ref, lot, 1000, 100000).ok, "owned satchel can be admitted for partial delivery")
	assert_true(_delivery.repost_payload(next.ref).ok, "repost without moving goods or another load")
	assert_equal(world._residents._skill_xp[worker * Work.SKILL_COUNT + Jobs.JOB_KIND_HAUL], before_xp, "no second load XP")
	assert_equal(world._jobs._state[next.value], Jobs.JOB_STATE_HAUL_OUTPUT, "direct existing unload phase")
	if not _walk(next.value, _fixture._endpoints[1], Profiles.MODE_CARRY): return
	assert_equal(_handling(next.value, 5), 2000, "one actual unload")
	assert_true(_delivery.unload_payload(next.ref).ok, "partial guarded unload")
	assert_equal(world._residents.satchel_of(worker), satchel, "live satchel mirror is preserved")
	assert_equal(world._inventory.lot_quantity_milli(lot), 1400, "undelivered real cargo survives")
	assert_equal(world._inventory.lot_reserved_milli(lot), 0, "no cancelled or completed claim survives")


func test_ordinary_terrain_observation_move_refuses_loading_then_exact_retry() -> void:
	"""A supported earlier source observation may move the worker; payment then refuses without consuming earned work."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "real admission")
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(_handling(job.value, 4), 2000, "load work already earned")
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(world._transforms.read_into(world._worker, pose), "original actual pose")
	var before: Array[PackedByteArray] = _fixture._economic_image()
	var terrain: LateTerrain = world._terrain as LateTerrain
	terrain.binding_probe = _displace_transfer_worker
	terrain.binding_countdown = 1
	assert_false(_delivery.load_payload(job.ref).ok, "moved worker cannot commit")
	assert_equal(terrain.binding_probe_count, 1, "supported source observer ran once")
	_fixture._assert_economic_image(before)
	assert_true(world._transforms.place(world._worker, pose.x, pose.y, pose.z, pose.yaw), "restore original actual position")
	assert_true(_delivery.load_payload(job.ref).ok, "same earned work can retry the original transfer")


func test_expiry_equal_to_clock_tick_being_committed_refuses_work_before_sweep() -> void:
	"""Clock.step runs before completed_tick increments; expiry at the committed tick is already stale."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 2).ok, "claim valid for next tick1")
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, job.ref, 0, Prefix.Space.MAX_CHECKS), &"", "actual ground turn")
	assert_equal(world._routes.refresh_work_actor(world._worker, job.ref, 4, 1, 2, 0, -1, NULL_REF), &"", "actual selected HAUL work")
	assert_equal(_delivery.begin_load(job.ref), &"", "current tick1 may begin")
	_clock.set_pause(Clock.PLAYER, false)
	assert_equal(_clock.advance(33334, _expiry_work_tick.bind(job.value)), 1, "one real clock step")
	var before: Array[PackedByteArray] = _fixture._economic_image()
	assert_equal(_clock.advance(33334, _expiry_work_tick.bind(job.value)), 1, "next real clock step")
	_fixture._assert_economic_image(before)
	assert_equal(_clock.completed_tick(), 2, "the refused operation does not prevent authoritative time")
	assert_true(_delivery.cancel(job.ref).ok, "expired claims and grams remain explicitly cancellable")


func _expiry_work_tick(job: int) -> void:
	"""Exercise Work in the actual pre-increment Clock callback, independently of any delayed expiry sweep."""
	var result: Work.TickResult = _fixture._world._work.tick_solo(job)
	if _clock.completed_tick() == 0:
		assert_true(result.ok and result.accepted_mwu > 0, "expiry2 permits work in tick1")
	else:
		assert_false(result.ok, "expiry2 refuses unswept work during tick2")
		assert_equal(result.error, &"CONNECTOR_DELIVERY_LEASE_EXPIRED", "exact expiry cause")


func test_real_inventory_observers_refuse_each_staged_transfer_without_payment_or_extra_work() -> void:
	"""ADMIT, LOAD and UNLOAD all close real staging observers before quantities, grams or satchel publication."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	_assert_staged_move_refuses(job.ref, Delivery.ADMIT)
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "same admission retry")
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual travel phase")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(_handling(job.value, 4), 2000, "one complete load phase")
	_assert_staged_move_refuses(job.ref, Delivery.LOAD)
	assert_true(_delivery.load_payload(job.ref).ok, "completed load retries without WU")
	if not _walk(job.value, _fixture._endpoints[1], Profiles.MODE_CARRY): return
	assert_equal(_handling(job.value, 5), 2000, "one complete unload phase")
	_assert_staged_move_refuses(job.ref, Delivery.UNLOAD)
	assert_true(_delivery.unload_payload(job.ref).ok, "completed unload retries without WU")


func _assert_staged_move_refuses(job: Vector2i, action: int) -> void:
	"""Capture each complete economic owner independently, mutate only actual Transform, and restore after refusal."""
	var world: Prefix.ActualWorld = _fixture._world
	var observer: SeedObserver = SeedObserver.new()
	assert_true(world._inventory.set_seed_expiry_authority(observer).ok, "bind real Inventory observation")
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(world._transforms.read_into(world._worker, pose), "original current pose")
	observer.probe = _displace_transfer_worker
	var before: Array[PackedByteArray] = _fixture._economic_image()
	var grams: PackedInt64Array = _planner._reserved_g.duplicate()
	var result: Inventory.OpResult = _delivery.admit(job, _fixture.remote_wood, 2400, 100000) if action == Delivery.ADMIT \
		else (_delivery.load_payload(job) if action == Delivery.LOAD else _delivery.unload_payload(job))
	assert_false(result.ok, "late staged movement cannot commit action %d" % action)
	assert_equal(observer.fired, 1, "actual Inventory callback ran")
	_fixture._assert_economic_image(before)
	assert_equal(_planner._reserved_g, grams, "no changed Planner grams")
	assert_false(world._inventory._tx_open or world._pool._haul_active, "original journal and scope cleaned")
	assert_true(world._transforms.place(world._worker, pose.x, pose.y, pose.z, pose.yaw), "restore same actual station")
	assert_true(world._inventory.set_seed_expiry_authority(null).ok, "restore ordinary no-seed fixture")


func test_inventory_observer_reentry_poisons_original_admission_and_preserves_retry() -> void:
	"""A nested Delivery call cannot replace the original request or authorize either staged resource write."""
	if not _ready(): return
	var job: Jobs.OpResult = _job()
	var observer: SeedObserver = SeedObserver.new()
	assert_true(_fixture._world._inventory.set_seed_expiry_authority(observer).ok, "actual Inventory observer")
	observer.probe = _reenter_delivery.bind(job.ref)
	var before: Array[PackedByteArray] = _fixture._economic_image()
	assert_false(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "outer request poisoned")
	assert_equal(observer.fired, 1, "actual staging observer ran once")
	_fixture._assert_economic_image(before)
	assert_false(Delivery.handles_job(_delivery, job.ref), "no Planner receipt")
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "valid original tuple retries")


func _reenter_delivery(job: Vector2i) -> void:
	"""Use the public cancellation door while admission owns its one fixed synchronous packet."""
	var result: Inventory.OpResult = _delivery.cancel(job)
	assert_false(result.ok, "nested cleanup cannot overwrite original admission")
	assert_equal(result.error, Delivery.REFUSE_BUSY, "named reentry refusal")


func _ship_requested(requested: int) -> int:
	"""One complete real trip uses the new Planner/Work/Delivery lifecycle, never the historical second-WORK bridge."""
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	var admitted: Inventory.OpResult = _delivery.admit(job.ref, _fixture.remote_wood, requested, 100000)
	assert_true(admitted.ok, "actual sized spatial shipment")
	if not admitted.ok: return 0
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return 0
	assert_equal(_handling(job.value, 4), 2000, "one load phase for this payload")
	assert_true(_delivery.load_payload(job.ref).ok, "real satchel load")
	if not _walk(job.value, _fixture._endpoints[1], Profiles.MODE_CARRY): return 0
	assert_equal(_handling(job.value, 5), 2000, "one HAUL_OUTPUT unload phase for this payload")
	assert_true(_delivery.unload_payload(job.ref).ok, "real loose goods arrive")
	assert_true(world._jobs.release_worker(world._residents.directory().get_typed_row(world._worker)).ok, "release completed haul assignment")
	return admitted.value


func _resume_primary() -> int:
	"""The same primary BUILD Job regains its actual equipped claimed tool and reaches the real fastening station."""
	var world: Prefix.ActualWorld = _fixture._world
	assert_true(world._gear.equip(_fixture._tool, world._worker).ok, "equip actual existing basic tool")
	var primary: int = _fixture._router._primary_row(_project)
	_fixture._assign_installation_worker(primary, _fixture._endpoints[0])
	assert_true(_fixture.failures.is_empty(), "actual BUILD source: %s" % _fixture.failures)
	return primary


func _pause_primary_for_payload(primary: int) -> void:
	"""Partial loose goods remain in Inventory while the real worker releases its tool and fetches the remaining payload."""
	var world: Prefix.ActualWorld = _fixture._world
	assert_true(world._pool.release_job_claims(world._jobs.ref_of(primary), world._inventory).ok, "partial input claims released")
	var worker: int = world._residents.directory().get_typed_row(world._worker)
	assert_true(world._work.release_tool_claim(worker).ok, "release BUILD claim before carry")
	assert_true(world._jobs.release_worker(worker).ok, "same worker may haul again")
	assert_true(world._gear.unequip(_fixture._tool, _fixture._storage, false).ok, "no-tool real handling source")


func _stored_wood() -> int:
	"""Sum the real destination lot chain; physical unload may preserve several separate lot identities."""
	var inventory: Inventory = _fixture._world._inventory
	var item: int = _fixture._world._items.compiled_id(&"wood")
	var quantity: int = 0
	var lot: Vector2i = inventory.container_first_lot(_fixture._storage)
	while lot != NULL_REF:
		if inventory.lot_item_id(lot) == item: quantity += inventory.lot_quantity_milli(lot)
		lot = inventory.container_next_lot(lot)
	return quantity


func test_two_actual_shipments_supply_one_paid_static_workpiece_without_extra_wood() -> void:
	"""A 12kg mouse supplies the real 20kg bill in ordinary payloads; only complete actual delivery permits START."""
	if not _ready(): return
	assert_equal(_stored_wood(), 1500, "real local stock after four paid cubes")
	assert_equal(_ship_requested(4000), 2400, "first actual capacity-limited payload")
	if not failures.is_empty(): return
	var primary: int = _resume_primary()
	assert_equal(_fixture._claim_delivery(_project, primary), 3900, "partial real loose stock is still100 short")
	assert_false(_fixture._router.start_work(_project, 0).ok, "incomplete actual bill cannot become WIP")
	assert_equal(_pieces._live.present.count(1), 0, "no physical bearer from partial delivery")
	assert_false(_fixture._router._funding.is_funded(_project), "no WIP quantity receipt")
	_pause_primary_for_payload(primary)
	assert_equal(_ship_requested(1600), 1600, "second ordinary payload")
	if not failures.is_empty(): return
	assert_equal(_stored_wood(), 5500, "all finite post-excavation stock is conserved")
	assert_equal(_resume_primary(), primary, "same full primary Job after hauling")
	assert_true(_fixture._pay_installation(_project, primary), "actual prepared workpiece START follows actual deliveries")
	assert_equal(_stored_wood(), 1500, "one4000 bill, no hauling/set-down material surcharge")
	assert_equal(_pieces._live.present.count(1), 1, "one real paid non-supporting obstacle")
	assert_true(_fixture._router._funding.is_funded(_project), "original actual Funding receipt")
	assert_true(_fixture.failures.is_empty(), "full paid composition: %s" % _fixture.failures)


func test_productive_observer_cannot_release_original_claim_then_credit_work() -> void:
	"""A copied lease is insufficient: real claim removal after selection must block WU and XP until a valid retry."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "actual source claim")
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return
	assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, job.ref, 0, Prefix.Space.MAX_CHECKS), &"", "actual ground turn")
	assert_equal(world._routes.refresh_work_actor(world._worker, job.ref, 4, 1, 2, 0, -1, NULL_REF), &"", "exact HAUL work source")
	assert_equal(_delivery.begin_load(job.ref), &"", "arrived loading phase")
	var work_image: PackedByteArray = world._work.state_bytes()
	var resident_image: PackedByteArray = world._residents.state_bytes()
	var terrain: LateTerrain = world._terrain as LateTerrain
	terrain.binding_probe = _release_haul_claim.bind(job.ref)
	terrain.binding_countdown = 1
	assert_false(world._work.tick_solo(job.value).ok, "lost current claim grants no productive work")
	assert_equal(world._jobs._remaining_mwu[job.value], 2000, "no accepted WU after release")
	assert_true(world._work.state_bytes() == work_image, "no fractional or XP remainder credit")
	assert_true(world._residents.state_bytes() == resident_image, "no skill credit")
	assert_equal(world._inventory.lot_reserved_milli(_fixture.remote_wood), 0, "the real observer released its claim")
	var batch: PackedInt64Array = PackedInt64Array([_fixture.remote_wood.x, _fixture.remote_wood.y,
		Prefix.ContactTests.Reservations.PURPOSE_HAUL_SOURCE, 2400, 100000])
	assert_true(world._pool.claim_batch(job.ref, batch, 1, world._inventory).ok, "restore actual original claim")
	assert_true(world._work.tick_solo(job.value).ok, "same physical worker can retry against the current claim")


func _release_haul_claim(job: Vector2i) -> void:
	"""The ordinary observer acts through the actual reservation API before the final productive leaf."""
	assert_true(_fixture._world._pool.release_job_claims(job, _fixture._world._inventory).ok, "actual claim release")


func _begin_loading(job: Jobs.OpResult) -> bool:
	"""Use actual route arrival and the complete HAUL work profile before a one-tick or transfer regression."""
	var world: Prefix.ActualWorld = _fixture._world
	assert_true(world._jobs.set_state(job.value, Jobs.JOB_STATE_TRAVEL).ok, "actual source travel")
	if not _walk(job.value, _fixture._endpoints[2], Profiles.MODE_WALK): return false
	assert_equal(Prefix.WorldRoutes.turn_actor(world._binding, world._worker, job.ref, 0, Prefix.Space.MAX_CHECKS), &"", "actual ground turn")
	assert_equal(world._routes.refresh_work_actor(world._worker, job.ref, 4, 1, 2, 0, -1, NULL_REF), &"", "exact HAUL work source")
	assert_equal(_delivery.begin_load(job.ref), &"", "arrived loading phase")
	return failures.is_empty()


func test_pool_outer_return_override_is_refused_before_any_delivery_packet_or_payment() -> void:
	"""A real post-super Pool wrapper must never enter the coordinator's pure return-to-publication boundary."""
	after_each()
	var code: StringName = _setup(ReturningFixture.new(), Planner.new())
	if code != &"":
		assert_equal(code, Delivery.REFUSE_BINDING, "exact Pool implementation is required")
		assert_true(_delivery._frame.is_empty() and _delivery._placements == null, "no allocation or partial binding")
		return
	if not _ready(): return
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "real initial claim")
	if not _begin_loading(job): return
	assert_equal(_handling(job.value, 4), 2000, "actual original loading work")
	var pool: ReturningPool = _fixture._world._pool as ReturningPool
	pool.probe = _reassign_after_return
	var result: Inventory.OpResult = _delivery.load_payload(job.ref)
	assert_false(result.ok, "an unpinned outer Pool return cannot authorize the paid tail")
	assert_equal(pool.fired, 1, "rejected-source witness called the real transaction before reassignment")
	assert_equal(_fixture._world._jobs._state[job.value], Jobs.JOB_STATE_QUEUED, "no stale original Job publication")


func test_planner_outer_return_override_is_refused_before_admission() -> void:
	"""The real Planner return tail is also concrete, rather than a new observation seam after claim commit."""
	after_each()
	var planner: ReturningPlanner = ReturningPlanner.new()
	var code: StringName = _setup(Fixture.new(), planner)
	if code != &"":
		assert_equal(code, Delivery.REFUSE_BINDING, "exact Planner implementation is required")
		assert_true(_delivery._frame.is_empty() and _delivery._planner == null, "refused cold bind has no packet")
		return
	if not _ready(): return
	var job: Jobs.OpResult = _job()
	planner.probe = _reassign_after_return
	var result: Inventory.OpResult = _delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000)
	assert_false(result.ok, "an outer Planner return cannot mutate the original admitted tuple")
	assert_equal(planner.fired, 1, "rejected-source witness followed the real admission")


func _reassign_after_return() -> void:
	"""Actual public Jobs APIs replace the original assignment after the lower guarded operation has returned."""
	var world: Prefix.ActualWorld = _fixture._world
	var row: int = world._residents.directory().get_typed_row(world._worker)
	assert_true(world._jobs.release_worker(row).ok, "actual original assignment released")
	var replacement: Jobs.OpResult = world._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, 5000, 0)
	assert_true(replacement.ok, "different actual full Job")
	assert_true(world._jobs.assign_worker(row, replacement.value).ok, "actual replacement assignment")


func test_late_public_factor_read_preserves_original_workers_prepared_remainder() -> void:
	"""A harmless observer reading another real resident's unequal factor cannot change prepared tick arithmetic."""
	if not _ready(): return
	var world: Prefix.ActualWorld = _fixture._world
	var job: Jobs.OpResult = _job()
	assert_true(_delivery.admit(job.ref, _fixture.remote_wood, 2400, 100000).ok, "real source reservation")
	if not _begin_loading(job): return
	var other: int = _other_ground_worker()
	if not failures.is_empty(): return
	var worker: int = world._residents.directory().get_typed_row(world._worker)
	var factor: int = world._work.work_factor_of(worker, Jobs.JOB_KIND_HAUL).value
	assert_true(factor != world._work.work_factor_of(other, Jobs.JOB_KIND_HAUL).value, "actual unequal factors")
	var before: int = world._work._potential_remainder[worker]
	var terrain: LateTerrain = world._terrain as LateTerrain
	terrain.binding_probe = _read_other_factor.bind(other)
	terrain.binding_countdown = 1
	var result: Work.TickResult = world._work.tick_solo(job.value)
	assert_true(result.ok, "a read-only late observation preserves valid productive work")
	@warning_ignore("integer_division") var expected: int = (before + Work.BASE_MWU_PER_TICK * factor) / Work.WORK_FACTOR_DENOMINATOR
	assert_equal(result.accepted_mwu, expected, "original worker's prepared factor")
	assert_equal(world._work._potential_remainder[worker],
		(before + Work.BASE_MWU_PER_TICK * factor) % Work.WORK_FACTOR_DENOMINATOR, "original exact integer remainder")
	assert_true(world._work.tick_solo(job.value).ok, "the next tick remains valid")


func _other_ground_worker() -> int:
	"""Place and register a separate actual living body at the remote existing destination, without overlap."""
	var world: Prefix.ActualWorld = _fixture._world
	var made: Prefix.WorldTests.Residents.OpResult = world._residents.spawn(&"mouse")
	assert_true(made.ok, "other actual Resident")
	var worker: Vector2i = world._residents.ref_of(made.value)
	var record: Prefix.Locations.Record = Prefix.Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	assert_equal(world._locations.read_location_into(_fixture._endpoints[1], record), &"", "actual existing destination")
	assert_true(world._transforms.place(worker, record.point.x, record.point.y, record.point.z, 0), "initial actual pose")
	assert_equal(world._routes.admit_actor(worker, NULL_REF, _fixture._endpoints[1], Profiles.MODE_WALK, 0, -1), &"", "actual full stationary body")
	assert_true(world._work.set_memory_total(made.value, -100000).ok, "public factor input for unequal resident")
	return made.value


func _read_other_factor(row: int) -> void:
	"""The late observer uses the public read API only; it mutates no gameplay input."""
	assert_true(_fixture._world._work.work_factor_of(row, Jobs.JOB_KIND_HAUL).ok, "ordinary public factor read")
