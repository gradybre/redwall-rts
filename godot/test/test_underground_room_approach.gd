extends "res://test/framework/test_case.gd"
## Actual owners/path/WorkFace with explicitly synthetic immutable profiles and completed corridor geometry.
## These tests allocate no productive Job, paid Room, entrance, support permission or production certificate.

const Approach := preload("res://scripts/core/underground_room_approach.gd")
const FaceFixture := preload("res://test/test_underground_work_face.gd")
const Fixture := preload("res://test/test_underground_world_routes.gd")
const Bindings := preload("res://scripts/core/underground_room_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const RoomFixture := preload("res://test/test_underground_furniture_work.gd")
const MaskFixture := preload("res://test/test_underground_room_bindings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const BuildingCatalog := preload("res://scripts/core/catalog.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const FLOOR: int = FaceFixture.FLOOR
const X: int = Fixture.X
const Z: int = Fixture.Z


class ActualFixture extends FaceFixture.UndergroundFixture:
	## Existing real owner fixture; only numeric geometry/profile inputs are synthetic, never a success override.
	var exact_terrain: Terrain = null

	func _actual_profiles() -> void:
		"""Real equipment/load/work readers consume clearly labelled synthetic immutable profile content."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64)
		_piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "actual pile World")
		_carry = Carry.new()
		assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs)
		assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(8, 64, 2, Profiles.ARENA_BYTES), &"", "finite synthetic profile arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual source readers")
		load_profiles()

	func load_profiles(change: int = 0, revision: int = 1) -> void:
		"""New content epochs use the real finite wire decoder and expire every earlier source witness."""
		var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
		assert_true(_residents.spatial_profile_identity_into(_worker, identity), "actual actor identity")
		var bytes: PackedByteArray = profile_image(identity, change, revision)
		assert_equal(_profiles.load_file(PROFILE_TEMP, _write(PROFILE_TEMP, bytes), revision), &"", "synthetic source/geometry wire")


	func _load_catalog(revision: int) -> StringName:
		"""This fixture needs only ground pace; every fixed family remains absent from actual route permission."""
		var bytes: PackedByteArray = ContentFixture.synthetic_image(revision)
		bytes.encode_u32(44, 1)
		bytes.resize(ContentFixture.PACE_BASE + 36)
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)


	func _actual_binding() -> void:
		"""The prospective leaf uses the exact production Terrain script, with no permission override."""
		if exact_terrain == null:
			exact_terrain = Terrain.new()
			assert_equal(exact_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "exact Terrain")
		_binding = WorldRoutes.new()
		var config: WorldRoutes.Configuration = _configuration()
		assert_equal(_binding.configure(config), &"", "actual concrete WorldRoutes")
		assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
			8, 16, 64, 64, Routes.ARENA_BYTES), &"", "actual graph")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual actor readers")
		assert_equal(_binding.binding_refusal(), &"", "complete actual composition")

	func _configuration() -> WorldRoutes.Configuration:
		"""Every source comes from this one actual fixture composition; no caller geometry service is substituted."""
		var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
		config.routes = _routes
		config.owner = _owner
		config.sources = _sources
		config.locations = _locations
		config.profiles = _profiles
		config.catalog = _catalog
		config.levels = _levels
		config.movement = _movement
		config.residents = _residents
		config.transforms = _transforms
		config.world = _world
		config.terrain = exact_terrain
		config.budget = _budget
		return config

	func _edge() -> Routes.Edge:
		"""A real directed complete corridor span uses the existing underground floor and section identity."""
		var edge: Routes.Edge = super._edge()
		edge.level = 1
		edge.room = room
		edge.points[1] = FLOOR
		edge.points[4] = FLOOR
		return edge

	func connect_path() -> void:
		"""The actual graph and WorldRoutes both prove the exact source profile along this corridor."""
		var token: int = _begin()
		assert_equal(_routes.stage_add(token, _edge()).error, &"", "actual edge admitted")
		assert_equal(_binding.seal(token), &"", "actual certificate sealed")
		assert_equal(_binding.publish(token), &"", "actual paired graph/certificate publication")
		assert_equal(_budget.release(_lease), &"", "initial graph lease returned")
		_lease = 0

	func after_each() -> void:
		"""Drop the extra borrowed concrete Terrain before the existing fixture releases its stores."""
		exact_terrain = null
		super.after_each()


	static func profile_image(identity: PackedInt32Array, change: int = 0, revision: int = 1) -> PackedByteArray:
		"""Both rows use the real loader; certificate flags explicitly label test geometry, not source qualification."""
		var boxes: Array[PackedInt32Array] = profile_boxes(change)
		var bytes: PackedByteArray = "UGPROF01".to_ascii_buffer()
		bytes.resize(32)
		bytes.encode_u32(8, 1)
		bytes.encode_s64(12, revision)
		bytes.encode_u32(20, 2)
		bytes.encode_u32(24, boxes.size())
		bytes.encode_u32(28, 1)
		for index: int in 32: bytes.append(7)
		_append_profile(bytes, identity, false)
		_append_profile(bytes, identity, true)
		for box: PackedInt32Array in boxes: Fixture.ContentFixture._append_row(bytes, box)
		bytes.append_array("UGPEND01".to_ascii_buffer())
		return bytes


	static func _append_profile(bytes: PackedByteArray, identity: PackedInt32Array, work: bool) -> void:
		"""Only the explicit work row has a planar source contact; ordinary walk remains unambiguous."""
		Fixture.ContentFixture._append_row(bytes, PackedInt32Array([0, identity[0], identity[1], identity[2],
			Profiles.MODE_WORK if work else Profiles.MODE_WALK, Profiles.POSTURE_UPRIGHT, -1, -1, -1, -1,
			Profiles.YAW_EXACT if work else Profiles.YAW_ALL, 49152 if work else 0,
			31, 511, 3 if work else 0, 7 if work else 3, Jobs.JOB_KIND_BUILD if work else -1,
			Profiles.CONTACT_ANCHOR_AND_PATCH if work else Profiles.CONTACT_NONE]), 1)
		bytes.resize(bytes.size() + 18)
		bytes[bytes.size() - 2] = Profiles.CERT_REQUIRED


	static func profile_boxes(change: int = 0) -> Array[PackedInt32Array]:
		"""Actual role semantics preserve negative body residual, full support and one exact face patch."""
		return [PackedInt32Array([-128 + change, -1, -128, 128, 900, 128, Profiles.BODY_HELD_LOAD]),
			PackedInt32Array([-192, -1, -192, 192, 0, 192, Profiles.STANCE_SUPPORT]),
			PackedInt32Array([-160, -1, -160, 160, 900, 160, Profiles.TURN_RECOVERY]),
			PackedInt32Array([-128, -1, -128, 128, 900, 128, Profiles.BODY_HELD_LOAD]),
			PackedInt32Array([-192, -1, -192, 192, 0, 192, Profiles.STANCE_SUPPORT]),
			PackedInt32Array([-160, -1, -160, 160, 900, 160, Profiles.TURN_RECOVERY]),
			PackedInt32Array([-160, 0, -160, 400, 900, 160, Profiles.WORK_APPROACH]),
			PackedInt32Array([400, 256, -32, 700, 768, 32, Profiles.WORK_STROKE]),
			PackedInt32Array([512, 512, 0, 512, 512, 0, Profiles.CONTACT_POINT]),
			PackedInt32Array([512, 500, -12, 512, 524, 12, Profiles.CONTACT_PATCH])]


class ObservedAdmission extends Bindings:
	## Records actual refusal stages only; no test-only successful proof or publication override exists.
	var plan_code: StringName = &"NOT_CALLED"
	var prepared_code: StringName = &"NOT_CALLED"

	func room_plan_refusal(plan: Orders.RoomPlan, room: Vector2i, token: int) -> StringName:
		"""Retain the exact original production result to distinguish setup, source and prepared failure."""
		plan_code = super.room_plan_refusal(plan, room, token)
		return plan_code

	func room_prepared_refusal(plan: Orders.RoomPlan, room: Vector2i, token: int) -> StringName:
		"""No result is fabricated; all actual companion/cold checks still run."""
		prepared_code = super.room_prepared_refusal(plan, room, token)
		return prepared_code


class ObservedSites extends Sites:
	## Run an adversarial action only after the actual final history observation returns successfully.
	var probe: Callable = Callable()
	var fired: int = 0

	func room_claim_batch_refusal(batch: Sites.RoomClaimBatch) -> StringName:
		"""The genuine observer result is preserved; only this fixture's later source state may change."""
		var code: StringName = super.room_claim_batch_refusal(batch)
		if code == &"" and probe.is_valid():
			var action: Callable = probe
			probe = Callable()
			fired += 1
			action.call()
		return code


class FinalReadProbe extends RefCounted:
	## Count one named observation, then mutate real terrain after its copied value on the last call.
	var kind: StringName = &""
	var calls: int = 0
	var remaining: int = 0
	var fired: int = 0
	var action: Callable = Callable()

	func observe(reader: StringName) -> void:
		"""Arming occurs only after complete preparation; the mutation never supplies a successful proof."""
		if reader != kind: return
		calls += 1
		if not action.is_valid(): return
		remaining -= 1
		if remaining != 0: return
		var callback: Callable = action
		action = Callable()
		fired += 1
		callback.call()


class FinalWorld extends World:
	## Real published World with a one-shot observer only for the final-boundary regression.
	var probe: FinalReadProbe = null

	func is_published() -> bool:
		"""Copy the actual publication fact before any armed mutation."""
		var result: bool = super.is_published()
		if probe != null: probe.observe(&"world")
		return result

	func terrain_into(tile: int, out: IntMath.IntResult) -> bool:
		"""Copy actual terrain into the caller before a possible late observation action."""
		var result: bool = super.terrain_into(tile, out)
		if probe != null: probe.observe(&"terrain")
		return result


class FinalNodes extends Nodes:
	## Real resource store, including the real empty-tile predicate copied before an observer runs.
	var probe: FinalReadProbe = null

	func ref_at_tile(tile: int) -> Vector2i:
		"""Return the original real node reference even when the observer subsequently adds a foundation."""
		var result: Vector2i = super.ref_at_tile(tile)
		if probe != null: probe.observe(&"nodes")
		return result


class FinalBuildings extends Buildings:
	## Real Room and Building columns; observers never substitute identity or footprint outputs.
	var probe: FinalReadProbe = null

	func is_live_room(room: Vector2i) -> bool:
		"""Copy the actual old Room identity before the late final source-tail action."""
		var result: bool = super.is_live_room(room)
		if probe != null: probe.observe(&"room")
		return result

	func building_at_tile(tile: int) -> Vector2i:
		"""Copy the real empty footprint before adding a new real well to a previously checked target."""
		var result: Vector2i = super.building_at_tile(tile)
		if probe != null: probe.observe(&"building")
		return result


class AdmissionFixture extends ActualFixture:
	## Real RoomOrders/RoomBindings and pure publication kernels; only preexisting corridor/profile inputs are synthetic.
	var rooms: ObservedAdmission = null
	var orders: RoomFixture.SyntheticRegistration = null
	var provider: WorldBindings = null
	var sites: ObservedSites = null
	var router: Router = null
	var spatial: MaskFixture.SyntheticSpatial = null

	func _actual_space(obstruction: int) -> void:
		"""Bind the actual sole Room authority before registering the existing completed-corridor fixture."""
		assert_equal(obstruction, 0, "composed fixture has no hidden physical obstruction override")
		_routes = Routes.new(_residents, _transforms)
		_sources = FaceFixture.ObservedSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 16384, 8192, Space.MAX_CHECKS), &"", "complete actual Domain")
		_owner = FaceFixture.ObservedSpace.new(_sources)
		assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual owner")
		_bind_accounting(domain)
		_actual_catalog(domain)
		_bind_orders()
		_seed_corridor()
		_locations = FaceFixture.ObservedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, 8, 228 * 8 + 256), &"", "actual Locations")
		assert_equal(_locations.bind_sites(sites), &"", "actual paid site authority")
		assert_equal(_locations.bind_room_orders(orders), &"", "actual Room companion authority")

	func _bind_accounting(domain: Space.Domain) -> void:
		"""Only initial unstarted Site registration is synthetic; no paid phase or completed geometry is granted."""
		var reservations: Reservations = Reservations.new()
		spatial = MaskFixture.SyntheticSpatial.new()
		spatial.domain = domain
		spatial.buildings = _buildings
		sites = ObservedSites.new(_construction, _inventory, reservations, _items, _jobs, _work, spatial, 32, 256)
		assert_equal(sites.initialization_refusal(), &"", "actual accounting")
		router = Router.new(_construction, _inventory, reservations, _items, _jobs, _work, sites)
		assert_equal(router.initialization_refusal(), &"", "actual Router")
		exact_terrain = Terrain.new()
		assert_equal(exact_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual Terrain")
		provider = WorldBindings.new()
		assert_equal(provider.configure(_world, exact_terrain, _owner, _sources, _budget), &"", "actual composer")

	func _bind_orders() -> void:
		"""All new Kitchen admission calls use inherited actual methods and the production concrete bindings."""
		rooms = ObservedAdmission.new()
		assert_equal(rooms.configure(provider, sites, _budget), &"", "actual RoomBindings")
		orders = RoomFixture.SyntheticRegistration.new()
		assert_equal(orders.configure(router, _owner, _sources, RoomCatalog.new(), rooms), &"", "sole actual RoomOrders")
		assert_equal(rooms.configure_room_admission(orders, _levels), &"", "actual levels")
		orders.permit_action = Buildings.SPATIAL_ROOM_CREATE
		orders.permit_value = Buildings.ROOM_TYPE_CORRIDOR
		room = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR).ref
		orders.permit_action = -1
		assert_true(_buildings.is_live_room(room), "only initial corridor identity is synthetic")
		for x: int in 2:
			assert_true(sites.claim_quantum(Vector3i(X + x * 1024, FLOOR, Z), room).ok, "actual old endpoint Site key")

	func _seed_corridor() -> void:
		"""Retained positive geometry is explicit test content, not paid or production first-entry evidence."""
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, room), &"", "actual Room source")
		_floor = _region(token, PackedInt32Array([X, FLOOR, Z, X + 2048, FLOOR + 1, Z + 2048]), Space.FLOOR_DATUM)
		_void = _region(token, PackedInt32Array([X, FLOOR, Z, X + 2048, FLOOR + 2048, Z + 2048]), Space.SUPPORTED_VOID)
		_region(token, PackedInt32Array([X, FLOOR - 128, Z, X + 2048, FLOOR, Z + 2048]), Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "actual retained fixture seals")
		_owner.publish(token)

	func _actual_binding() -> void:
		"""The real Room provider consumes the same actual catalog/Terrain/Routes objects as travel."""
		super._actual_binding()
		assert_equal(rooms.configure_room_approach(_binding), &"", "real graph approach binding")

	func after_each() -> void:
		"""Discard exact original companions before releasing cold capacity or dropping any actual owner."""
		if orders != null and orders._stage_action == Orders.ROOM_ADMISSION_STAGE:
			orders._discard_room(rooms)
		assert_true(_budget.is_quiescent(), "actual Room scope returned its whole lease")
		assert_false(_owner.has_prepared(), "no future Room leaked")
		rooms = null
		orders = null
		provider = null
		router = null
		sites = null
		spatial = null
		super.after_each()


class FinalFixture extends AdmissionFixture:
	## Only the actual World/Nodes/Buildings classes gain observers; all production composition remains identical.
	func _actual_fixture(obstruction: int = 0) -> void:
		"""Construct the same owner set with genuine mutable-reader hooks, before binding any provider."""
		_residents = Residents.new()
		_jobs = Jobs.new(_residents)
		_nodes = FinalNodes.new(_residents.directory())
		var forage: Forage = Forage.new(_residents.directory(), _jobs)
		var fishing: Fishing = Fishing.new(_residents.directory(), forage, _jobs)
		_world = FinalWorld.new(_residents.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
		_inventory = Inventory.new(32, 64)
		_items = Items.new()
		assert_true(_items.load_default(_inventory).ok, "actual item definitions")
		assert_true(_world.generate(World.bound_request(_items).request).ok, "actual terrain generated")
		_world_ref = _residents.directory().create(Directory.KIND_WORLD)
		_worker = _residents.ref_of(_residents.spawn(&"mouse").value)
		_transforms = Transforms.new(_residents.directory())
		assert_true(_transforms.place(_worker, X + 512, 512, Z + 512, 49152), "actual actor pose")
		_buildings = FinalBuildings.new(_residents.directory())
		_construction = Construction.new(_buildings)
		_budget = Budget.new()
		_actual_profiles()
		_actual_space(obstruction)
		_actual_binding()
		_first = _location(Vector3i(X + 512, 512, Z + 512))
		_last = _location(Vector3i(X + 1536, 512, Z + 512))

	func watch(probe: FinalReadProbe) -> void:
		"""Only the already prepared final chain receives the shared one-shot observation probe."""
		(_world as FinalWorld).probe = probe
		(_nodes as FinalNodes).probe = probe
		(_buildings as FinalBuildings).probe = probe

	func after_each() -> void:
		"""Remove bound test callables before dropping any actual store or the enclosing test case."""
		var probe: FinalReadProbe = (_world as FinalWorld).probe
		if probe != null: probe.action = Callable()
		watch(null)
		super.after_each()


var _actual: ActualFixture = null
var _request: Approach.Request = null
var _plan: Orders.RoomPlan = null
var _witness: Approach.Witness = null
var _lease: int = 0
var _replacement: int = 0
var _original_geometry: PackedByteArray = PackedByteArray()


func _setup(connected: bool = true, obstruction: int = 0, admission: bool = false, final_readers: bool = false) -> void:
	"""Only completed fixture geometry is synthetic; actual endpoint/path/source state is never written privately."""
	_actual = FinalFixture.new() if final_readers else (AdmissionFixture.new() if admission else ActualFixture.new())
	_actual._actual_fixture(obstruction)
	if connected: _actual.connect_path()
	assert_true(_actual.failures.is_empty(), "actual setup: %s" % _actual.failures)
	_request = Approach.Request.new()
	_request.world = _actual._world_ref
	_request.space_revision = _actual._owner.revision()
	_request.room_type = Buildings.ROOM_TYPE_KITCHEN
	_request.level = 1
	_request.origin_u = Vector3i(X + 2048, FLOOR, Z)
	_request.height_u = Approach.reachable_height_u(_actual._profiles, 1) # DEC-054: the synthetic 512u anchor digs 1 m.
	_request.cell_size_u = 1024
	_request.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	_request.access = _actual._first
	_request.work_location = _actual._last
	_request.travel_profile = 0
	_request.travel_revision = 1
	_request.work_profile = 1
	_request.work_revision = 1
	_request.content_revision = 1
	_request.target_origin = _request.origin_u
	_request.face = 0
	_request.yaw = 49152
	_plan = Orders.RoomPlan.new()
	_plan.copy_from(_request)
	_lease = _actual._budget.acquire(Budget.COLD_BYTES)


func _observe() -> StringName:
	"""A failed component observation never replaces a previously held successful caller witness."""
	var result: Approach.Result = Approach.begin(_actual._binding, _request, _plan, _lease)
	if result.error == &"": _witness = result.witness
	return result.error


func after_each() -> void:
	"""Drop all cold witness/source/path references before releasing only the exact test-owned lease."""
	_witness = null
	_request = null
	_plan = null
	if _actual == null: return
	if _actual._budget.covers(_lease, 1): assert_equal(_actual._budget.release(_lease), &"", "original lease returned")
	if _replacement > 0: assert_equal(_actual._budget.release(_replacement), &"", "foreign replacement remains caller-owned")
	_lease = 0
	_replacement = 0
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "actual cleanup: %s" % _actual.failures)
	_actual = null


func test_actual_path_and_work_face_are_observed_before_any_candidate() -> void:
	"""Prospective geometry creates no Room, Job, resident actor, paid cut or live geometry change."""
	_setup()
	var geometry: PackedByteArray = _actual._owner.state_bytes()
	var identities: PackedByteArray = _actual._jobs.directory().state_bytes()
	assert_equal(_observe(), &"", "real complete path and exact source face")
	assert_equal(_witness.path_count, 1, "exact full edge retained")
	assert_true(_witness.face.proof == null, "large source image/fragments are released before prepared work")
	assert_equal(_witness.source_refusal(), &"", "current full source pins")
	assert_equal(_actual._owner.state_bytes(), geometry, "no geometry allocation/publication")
	assert_equal(_actual._jobs.directory().state_bytes(), identities, "no fake worker or future Room")
	assert_false(_actual._owner.has_prepared(), "WorkFace preceded all staging")


func test_disconnected_profile_path_refuses_a_genuine_available_work_face() -> void:
	"""A reachable-looking contact never invents the actual approach graph."""
	_setup(false)
	assert_equal(_observe(), &"ROUTE_NOT_CONNECTED", "no real path")
	assert_true(_witness == null, "no partial output witness")


func test_zero_edge_path_still_proves_the_whole_selected_travel_pose() -> void:
	"""One actual completed station can be both access and work only when every travel role fits there."""
	_setup(false)
	_request.access = _request.work_location
	assert_equal(_observe(), &"", "same actual complete endpoint")
	assert_equal(_witness.path_count, 0, "no invented connecting edge")


func test_full_source_contact_rejects_an_interior_approach_hole() -> void:
	"""A narrow missing void beyond the graph endpoint still intersects actual work approach geometry."""
	_setup(true, 1)
	assert_equal(_observe(), Approach.Face.REFUSE_BODY, "real WorkFace full-volume proof refuses")
	assert_true(_witness == null, "no geometry shortcut")


func test_target_must_belong_to_exact_room_cut_union() -> void:
	"""The same existing contact cannot qualify a separate room footprint or upper/lower course."""
	_setup()
	_request.origin_u.x += 4096
	_plan.copy_from(_request)
	assert_equal(_observe(), Approach.REFUSE_TARGET, "face outside intended cells")
	_request.origin_u.x -= 4096
	_request.origin_u.y += 1024
	_plan.copy_from(_request)
	assert_equal(_observe(), Approach.REFUSE_TARGET, "face outside intended vertical cuts")


func test_every_added_request_field_is_pinned_against_late_mutation() -> void:
	"""Plain RoomPlan copies cannot erase source selection, endpoint, face or exact yaw identity."""
	_setup()
	assert_equal(_observe(), &"", "original complete observation")
	for name: StringName in [&"access", &"work_location", &"travel_profile", &"travel_revision", &"work_profile",
		&"work_revision", &"content_revision", &"target_origin", &"face", &"yaw"]:
		var original: Variant = _request.get(name)
		if original is Vector2i: _request.set(name, original + Vector2i(0, 1))
		elif original is Vector3i: _request.set(name, original + Vector3i(1, 0, 0))
		else: _request.set(name, original + 1)
		assert_equal(_witness.source_refusal(), Approach.REFUSE_STALE, "extra field cannot reuse witness: %s" % name)
		_request.set(name, original)
		assert_equal(_witness.source_refusal(), &"", "exact original field restored")


func test_same_revision_refuses_and_new_epochs_expire_original_source() -> void:
	"""Equal revision replacement is forbidden by the actual loader; a new epoch cannot borrow the old witness."""
	_setup()
	assert_equal(_observe(), &"", "original source")
	var bytes: PackedByteArray = PackedByteArray([1])
	assert_equal(_actual._profiles.load_file(Fixture.PROFILE_TEMP, _actual._write(Fixture.PROFILE_TEMP, bytes), 1),
		&"PROFILE_SOURCE_IDENTITY", "actual same-revision refusal")
	assert_equal(_witness.source_refusal(), &"", "refused replacement preserves original source")
	_actual.load_profiles(0, 2)
	assert_equal(_witness.source_refusal(), Approach.REFUSE_STALE, "first swap changes bank identity")
	_actual.load_profiles(1, 3)
	assert_equal(_witness.source_refusal(), Approach.REFUSE_STALE, "second swap cannot hide changed source box")


func _mutate_request() -> void:
	"""Only this test's caller tuple changes, after an actual successful endpoint read."""
	_request.face = 1


func _replace_lease() -> void:
	"""A new same-size lease cannot replace the exact original operation token."""
	assert_equal(_actual._budget.release(_lease), &"", "original token released by fixture")
	_replacement = _actual._budget.acquire(Budget.COLD_BYTES)


func test_endpoint_callbacks_close_original_request_and_lease() -> void:
	"""Real endpoint observations may invalidate proof; neither changed input nor renewed capacity is accepted."""
	_setup()
	(_actual._locations as FaceFixture.ObservedLocations).countdown = 1
	(_actual._locations as FaceFixture.ObservedLocations).probe = _mutate_request
	assert_equal(_observe(), Approach.REFUSE_STALE, "late extra-field mutation")
	_request.face = 0
	(_actual._locations as FaceFixture.ObservedLocations).countdown = 1
	(_actual._locations as FaceFixture.ObservedLocations).probe = _replace_lease
	assert_equal(_observe(), Budget.REFUSE_BUSY, "foreign token never reused")
	assert_true(_actual._budget.covers(_replacement, Budget.COLD_BYTES), "refusal never closes a replacement lease")


func test_wrong_profile_and_preexisting_candidate_refuse_without_output() -> void:
	"""The ordinary pre-candidate source proof cannot be moved under an arbitrary geometry transaction."""
	_setup()
	_request.work_revision += 1
	assert_equal(_observe(), Approach.REFUSE_PROFILE, "stale exact selected work revision")
	_request.work_revision -= 1
	var staged: int = _actual._owner.begin_stage(_actual._owner.revision()).token
	assert_true(_observe() != &"", "actual WorkFace/path refuse prepared geometry")
	assert_true(_witness == null, "no successful witness")
	assert_true(_actual._owner.abort(staged), "only fixture candidate discarded")


func test_current_cold_admission_and_plain_plan_remain_explicit() -> void:
	"""The full existing operation peak precedes any new witness or path allocation."""
	_setup()
	assert_true(Approach.input_refusal(_actual._binding, null, _plan, _lease) != &"", "plain plan supplies no approach")
	assert_true(Approach.COLD_BYTES + 24 * 16384 + Bindings.ROOM_CONTROL_BYTES <= Budget.COLD_BYTES, "complete pre-Sites peak")
	assert_true(32 * 16384 + 8 * 16384 + Approach.PATH_BYTES + Approach.CONTROL_BYTES <= Budget.COLD_BYTES,
		"post-Sites four plans/cursor and retained witness fit without a new snapshot")
	assert_equal(_actual._budget.release(_lease), &"", "end exact complete admission")
	_lease = _actual._budget.acquire(Approach.COLD_BYTES - 1)
	assert_equal(_observe(), Budget.REFUSE_BUSY, "undersized existing token refuses before witness allocation")


func _orders_fixture(final_readers: bool = false) -> AdmissionFixture:
	"""Return the actual composed fixture after releasing the standalone caller's unrelated lease."""
	_setup(true, 0, true, final_readers)
	assert_equal(_actual._budget.release(_lease), &"", "standalone lease is not the coordinator's scope")
	_lease = 0
	_original_geometry = _actual._owner.state_bytes()
	return _actual as AdmissionFixture


func _prepared_room(final_readers: bool = false) -> AdmissionFixture:
	"""Execute real ordinary admission/preparation and claim preparation without publishing the future identity."""
	var fixture: AdmissionFixture = _orders_fixture(final_readers)
	fixture.orders._stage_action = Orders.ROOM_ADMISSION_STAGE
	fixture.orders._room_request = _request
	var code: StringName = fixture.orders._begin_room_cold(fixture.rooms, _request)
	assert_equal(code, &"", "actual original Room cold observation")
	if code != &"": return null
	fixture.orders._room_plan.copy_from(_request)
	code = fixture.orders._prepare_room(fixture.rooms)
	assert_equal(code, &"", "actual Room/Location/WorldRoutes preparation; plan=%s prepared=%s" % [fixture.rooms.plan_code, fixture.rooms.prepared_code])
	if code != &"": return null
	code = fixture.orders._prepare_room_claims()
	assert_equal(code, &"", "actual four-image Sites claim preparation")
	return fixture if code == &"" else null


func _final_room(fixture: AdmissionFixture) -> StringName:
	"""Use the exact public callback-free approach leaf with all original candidate and token objects."""
	return fixture.rooms.room_approach_final_refusal(fixture.orders._room_plan,
		fixture.orders._room_candidate, fixture.orders._stage_token)


func test_real_room_preparation_retains_witness_without_large_surveys_after_sites() -> void:
	"""The prepared proof coexists with real Sites copies while all old endpoints/edges remain unpublished."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	var witness: Approach.Witness = fixture.rooms._room_approach
	assert_true(witness.face.proof == null and fixture._binding._proof == null, "both complete proof images are gone")
	assert_true(fixture.orders._room_claim_batch != null, "actual fourth image/cursor retained")
	assert_equal(fixture.rooms.room_approach_observation_refusal(fixture.orders._room_plan,
		fixture.orders._room_candidate, fixture.orders._stage_token), &"", "actual last observation after Sites")
	assert_equal(_final_room(fixture), &"", "pure prepared source/candidate/companion closure")
	assert_false(fixture._buildings.is_live_room(fixture.orders._stage_room), "no future Room publication")
	assert_equal(fixture._locations._live.count, 2, "old endpoints only")
	assert_equal(fixture._routes._live.edge_count, 1, "old graph only")
	assert_equal(witness.path_count, 1, "original exact path retained")


func test_real_confirm_kitchen_preserves_fine_cells_and_refreshes_exact_existing_approach() -> void:
	"""Real callback-free tails publish claims and existing companions, never a finished shell or paid phase."""
	var fixture: AdmissionFixture = _orders_fixture()
	var revision: int = fixture._owner.revision()
	var inventory: PackedByteArray = fixture._inventory.state_bytes()
	var result: Buildings.OpResult = fixture.orders.confirm_room(_request)
	assert_true(result.ok, "actual complete Room confirmation: %s" % result.error)
	if not result.ok: return
	assert_equal(fixture._buildings.type_of_room(result.ref).value, Buildings.ROOM_TYPE_KITCHEN, "permanent confirmed purpose")
	assert_equal(fixture._owner.revision(), revision + 1, "one geometry publication")
	assert_equal(fixture._locations._live.count, 2, "no fabricated future work endpoint")
	assert_equal(fixture._routes._live.edge_count, 1, "no fabricated future route")
	assert_equal(fixture._inventory.state_bytes(), inventory, "Room confirmation purchases no phase materials")
	assert_equal(fixture.sites.room_of(fixture.sites.site_at(_request.target_origin)), result.ref, "target cube is claimed by the exact Room")
	assert_true(fixture._locations._last_published_token > 0 and fixture._routes._last_published_token > 0,
		"actual successful companion receipts")
	assert_true(fixture.rooms._room_approach == null and fixture._budget.is_quiescent(), "all cold packets die before return")
	assert_equal(_request.cells, PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1]), "original fine shape unchanged")


func test_prepared_final_rejects_every_extra_request_field_and_foreign_candidate() -> void:
	"""The protected plain plan cannot erase exact source/access/contact pins after actual Sites prepares."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	for name: StringName in [&"access", &"work_location", &"travel_profile", &"travel_revision", &"work_profile",
		&"work_revision", &"content_revision", &"target_origin", &"face", &"yaw"]:
		var original: Variant = _request.get(name)
		if original is Vector2i: _request.set(name, original + Vector2i(0, 1))
		elif original is Vector3i: _request.set(name, original + Vector3i(1, 0, 0))
		else: _request.set(name, original + 1)
		assert_equal(_final_room(fixture), Approach.REFUSE_STALE, "changed original extra: %s" % name)
		_request.set(name, original)
		assert_equal(_final_room(fixture), &"", "exact original tuple still proves")
	var candidate: Directory.CreateCandidate = Directory.CreateCandidate.new()
	assert_equal(fixture._residents.directory().peek_create_into(Directory.KIND_ROOM, candidate), &"", "same unused numeric candidate")
	assert_equal(fixture.rooms.room_approach_final_refusal(fixture.orders._room_plan, candidate,
		fixture.orders._stage_token), Approach.REFUSE_STALE, "same ref is not the original candidate object")
	assert_false(fixture._buildings.is_live_room(candidate.ref), "all refusals precede identity")


func _nested_room_release() -> void:
	"""The adversarial real endpoint observer attempts to close a scope it does not own."""
	(_actual as AdmissionFixture).rooms.end_room_cold()


func test_final_observer_reentry_cannot_close_or_reuse_the_original_room_scope() -> void:
	"""A real endpoint observation poisons nested cleanup, then the actual coordinator alone aborts safely."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	var token: int = fixture.rooms.room_cold_token()
	var geometry: PackedByteArray = _original_geometry
	(fixture._locations as FaceFixture.ObservedLocations).countdown = 1
	(fixture._locations as FaceFixture.ObservedLocations).probe = _nested_room_release
	assert_equal(fixture.rooms.room_approach_observation_refusal(fixture.orders._room_plan,
		fixture.orders._room_candidate, fixture.orders._stage_token), Bindings.REFUSE_MASK_BUSY, "nested cleanup is poisoned")
	assert_equal(_final_room(fixture), Bindings.REFUSE_MASK_BUSY, "later pure leaf retains poison")
	assert_true(fixture._budget.covers(token, Budget.COLD_BYTES), "observer cannot release original cold lease")
	assert_equal(fixture._owner.revision(), _request.space_revision, "no live revision changed")
	fixture.orders._discard_room(fixture.rooms)
	assert_true(fixture._budget.is_quiescent(), "owner abort frees every candidate before lease release")
	assert_true(fixture._owner.state_bytes() == geometry, "abort preserves original live bytes")


func _late_profiles() -> void:
	"""A real different immutable profile epoch replaces no retained source permission."""
	_actual.load_profiles(0, 2)


func _late_foundation() -> void:
	"""A new actual surface well is outside the old sparse snapshot but protects the selected target."""
	var result: Buildings.OpResult = _actual._buildings.place_building(
		int(BuildingCatalog.BUILDING_DEFINITION["well"]), 50 * 128 + 61, 0, 31)
	assert_true(result.ok, "actual well added by final Sites observer")


func _late_room_lease() -> void:
	"""Release and replace the actual Room lease after the last Sites observation succeeds."""
	var fixture: AdmissionFixture = _actual as AdmissionFixture
	assert_equal(fixture._budget.release(fixture.rooms.room_cold_token()), &"", "exact original token released")
	_replacement = fixture._budget.acquire(Budget.COLD_BYTES)


func _assert_publication_refused(fixture: AdmissionFixture, code: StringName) -> void:
	"""The actual coordinator's last-observer chain refuses before any future identity or paid history publication."""
	var count: int = fixture.sites._count
	var room: Vector2i = fixture.orders._stage_room
	assert_equal(fixture.orders._room_publication_refusal(fixture.rooms), code, "fresh final source closure")
	assert_equal(fixture.sites.fired, 1, "one real successful Sites observation preceded the mutation")
	assert_false(fixture._buildings.is_live_room(room), "future Room remains absent")
	assert_equal(fixture.sites._count, count, "no prepared cut claim is published")
	assert_equal(fixture._owner.revision(), _request.space_revision, "no physical revision published")
	fixture.orders._discard_room(fixture.rooms)
	assert_true(fixture._owner.state_bytes() == _original_geometry, "abort preserves original live geometry")
	assert_equal(fixture._locations._token, 0, "original endpoint candidate discarded")
	assert_equal(fixture._routes._token, 0, "original route candidate discarded")


func test_last_sites_observer_cannot_replace_the_actual_profile_source() -> void:
	"""After all prepared companions exist, a real profile reload invalidates the original approach tuple."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	fixture.sites.probe = _late_profiles
	_assert_publication_refused(fixture, Approach.REFUSE_STALE)


func test_last_sites_observer_cannot_hide_a_new_actual_foundation() -> void:
	"""The final Terrain leaf observes source changes even when the sparse geometry revision stays equal."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	fixture.sites.probe = _late_foundation
	_assert_publication_refused(fixture, Terrain.REFUSE_FOUNDATION)


func test_last_sites_observer_cannot_substitute_equal_cold_capacity() -> void:
	"""Cleanup discards only original candidates and cannot release the observer's replacement lease."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	fixture.sites.probe = _late_room_lease
	_assert_publication_refused(fixture, Budget.REFUSE_BUSY)
	assert_true(fixture._budget.covers(_replacement, Budget.COLD_BYTES), "foreign exact token stays owned by fixture")
	assert_equal(fixture._budget.release(_replacement), &"", "fixture alone returns replacement capacity")
	_replacement = 0


func _claimed_point(fixture: AdmissionFixture, room: Vector2i, point: Vector3i) -> bool:
	"""Inspect actual published fine claim prisms, independently of the whole paid cube lattice."""
	var owner: Owner = fixture._owner
	for row: int in owner._region_capacity:
		if owner._r_present[row] == 0 or owner._r_claim_kind[row] != Owner.CLAIM_ROOM \
				or Vector2i(owner._r_claim_slot[row], owner._r_claim_generation[row]) != room: continue
		if point.x >= owner._r_lo_x[row] and point.x < owner._r_hi_x[row] \
				and point.y >= owner._r_lo_y[row] and point.y < owner._r_hi_y[row] \
				and point.z >= owner._r_lo_z[row] and point.z < owner._r_hi_z[row]: return true
	return false


func test_actual_confirm_preserves_a_fine_hole_and_claims_whole_cubes_once() -> void:
	"""A fine512u hole remains outside Room claims although its intersected paid metre cube is claimed once."""
	var fixture: AdmissionFixture = _orders_fixture()
	_request.cell_size_u = 512
	_request.cells = PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2])
	var original: PackedInt32Array = _request.cells.duplicate()
	var prior: int = fixture.sites._count
	var result: Buildings.OpResult = fixture.orders.confirm_room(_request)
	assert_true(result.ok, "actual concave fine-grid confirmation: %s" % result.error)
	if not result.ok: return
	@warning_ignore("integer_division") var levels: int = _request.height_u / 1024
	assert_equal(fixture.sites._count - prior, 4 * levels, "four unique metre cubes on each reachable level (DEC-054)")
	assert_true(_claimed_point(fixture, result.ref, _request.origin_u + Vector3i(256, 1, 768)), "drawn fine cell is claimed")
	assert_false(_claimed_point(fixture, result.ref, _request.origin_u + Vector3i(768, 1, 768)), "fine centre hole stays outside Room")
	assert_equal(_request.cells, original, "exact caller fine cells preserved")


func _final_reader_case(kind: StringName) -> void:
	"""An armed last real reader must remain completely uncalled by the entire final source/Terrain chain."""
	var fixture: FinalFixture = _prepared_room(true) as FinalFixture
	if fixture == null: return
	var probe: FinalReadProbe = FinalReadProbe.new()
	probe.kind = kind
	fixture.watch(probe)
	assert_equal(_final_room(fixture), &"", "complete original prepared proof")
	probe.remaining = maxi(1, probe.calls)
	probe.calls = 0
	probe.action = _late_foundation
	var before: int = fixture._buildings._b_live_count
	assert_equal(_final_room(fixture), &"", "static final reads preserve the unchanged real facts")
	assert_equal(probe.calls, 0, "no overridable final %s reader" % kind)
	assert_equal(probe.fired, 0, "no side effect after copied observation")
	assert_equal(fixture._buildings._b_live_count, before, "no actual late foundation allocated")
	probe.action = Callable()
	fixture.watch(null)
	if probe.fired == 0: _late_foundation()
	assert_equal(_final_room(fixture), Terrain.REFUSE_FOUNDATION, "same concrete well is visible to the static leaf")


func test_final_world_publication_read_cannot_run_after_terrain_proof() -> void:
	"""A genuine copied World publication value cannot carry a late actual foundation mutation."""
	_final_reader_case(&"world")


func test_final_world_tile_reader_cannot_mutate_after_copying_terrain() -> void:
	"""Exact Terrain script identity alone does not make its transitive World reader observer-free."""
	_final_reader_case(&"terrain")


func test_final_resource_reader_cannot_mutate_after_copying_node_identity() -> void:
	"""The final resource lookup consumes actual packed columns without invoking the mutable node adapter."""
	_final_reader_case(&"nodes")


func test_final_building_tile_reader_cannot_mutate_after_copying_empty_ref() -> void:
	"""The final static foundation pass does not call a copied-empty footprint observer."""
	_final_reader_case(&"building")


func test_final_room_reader_cannot_run_after_prepared_companion_checks() -> void:
	"""A source-tail actual Room lookup is also part of the no-observer publication boundary."""
	_final_reader_case(&"room")


func _leaf_box(tile: int, low: int, high: int) -> PackedInt32Array:
	"""Use exact half-open generated tile bounds, independently of the authored test contact."""
	var x: int = (tile % 128) * 2048
	@warning_ignore("integer_division") var z: int = (tile / 128) * 2048
	return PackedInt32Array([x, low, z, x + 2048, high, z + 2048])


func _assert_leaf_parity(fixture: AdmissionFixture, bounds: PackedInt32Array) -> void:
	"""Compare every existing purpose and conflict identity; the ordinary reader remains the observed oracle."""
	for purpose: int in range(Terrain.DIG, Terrain.EXCLUSIONS + 1):
		var code: StringName = fixture.exact_terrain.prepared_local_facts_refusal(bounds, purpose,
			_request.space_revision, fixture.orders._stage_token, fixture.orders._room_cold_token)
		var ref: Vector2i = fixture.exact_terrain.last_conflict_ref()
		var tile: int = fixture.exact_terrain.last_conflict_tile()
		assert_equal(Terrain.prepared_local_leaf_refusal(fixture.exact_terrain, bounds, purpose,
			_request.space_revision, fixture.orders._stage_token, fixture.orders._room_cold_token), code, "same purpose/vertical result")
		assert_equal(fixture.exact_terrain.last_conflict_ref(), ref, "same exact conflict generation")
		assert_equal(fixture.exact_terrain.last_conflict_tile(), tile, "same local conflict tile")


func test_static_terrain_preserves_water_ford_surface_and_local_boundaries() -> void:
	"""Direct final reads preserve real world masks, role distinctions, half-open faces and the64-tile limit."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	for tile: int in [50 * 128 + 60, 60 * 128 + 76, 49 * 128 + 77, 5 * 128 + 20, 66 * 128 + 100]:
		for heights: Vector2i in [Vector2i(-512, 512), Vector2i(512, 513), Vector2i(-384, -128), Vector2i(-128, 0)]:
			_assert_leaf_parity(fixture, _leaf_box(tile, heights.x, heights.y))
	_assert_leaf_parity(fixture, PackedInt32Array())
	_assert_leaf_parity(fixture, PackedInt32Array([-1, 0, 0, 1024, 1, 1024]))
	_assert_leaf_parity(fixture, PackedInt32Array([0, 0, 0, 262144, 1, 262144]))


func test_static_terrain_observes_actual_resource_lifecycle_and_full_generation() -> void:
	"""New/depleted/regrown/retired sources never borrow old geometry or skip a stale typed mirror."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	var node: Nodes.OpResult = fixture._nodes.create_at_tile(50 * 128 + 60, fixture._items.compiled_id(&"wood"), 1000, 4, 1)
	assert_true(node.ok, "actual clear-tile tree")
	if not node.ok: return
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, -512, 512))
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, 1024, 2048))
	fixture._nodes._ref_generation[node.value] += 1
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, -512, 512))
	fixture._nodes._ref_generation[node.value] -= 1
	assert_true(fixture._nodes.harvest_all(node.value, 2).ok, "actual renewable stump")
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, -512, 512))
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, 1024, 2048))
	assert_true(fixture._nodes.regrow(node.value, 6).ok, "actual regrowth")
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, 1024, 2048))
	assert_true(fixture._nodes.destroy(node.ref).ok, "actual retirement")
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, -512, 2048))


func test_static_terrain_preserves_actual_rotated_foundation_and_site_envelope() -> void:
	"""Same real Building identities and rotated footprint survive lower/upper half-open query boundaries."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	var made: Buildings.OpResult = fixture._buildings.place_building(int(BuildingCatalog.BUILDING_DEFINITION["boathouse"]),
		50 * 128 + 60, 1, 31)
	assert_true(made.ok, "actual rotated structure")
	if not made.ok: return
	for tile: int in [50 * 128 + 60, 50 * 128 + 61, 51 * 128 + 60]:
		_assert_leaf_parity(fixture, _leaf_box(tile, -512, 512))
		_assert_leaf_parity(fixture, _leaf_box(tile, 512, 1024))
		_assert_leaf_parity(fixture, _leaf_box(tile, -1024, -512))
	var row: int = fixture._buildings._directory.get_typed_row(made.ref)
	fixture._buildings._b_ref_generation[row] += 1
	_assert_leaf_parity(fixture, _leaf_box(50 * 128 + 60, -512, 512))
	fixture._buildings._b_ref_generation[row] -= 1


func test_static_terrain_requires_original_prepared_revision_and_lease() -> void:
	"""A valid actual local box grants no final read through a different geometry operation or cold token."""
	var fixture: AdmissionFixture = _prepared_room()
	if fixture == null: return
	var bounds: PackedInt32Array = _leaf_box(50 * 128 + 60, -512, 512)
	assert_equal(Terrain.prepared_local_leaf_refusal(fixture.exact_terrain, bounds, Terrain.DIG,
		_request.space_revision + 1, fixture.orders._stage_token, fixture.orders._room_cold_token), Terrain.REFUSE_BINDING, "wrong original revision")
	assert_equal(Terrain.prepared_local_leaf_refusal(fixture.exact_terrain, bounds, Terrain.DIG,
		_request.space_revision, fixture.orders._stage_token + 1, fixture.orders._room_cold_token), Terrain.REFUSE_BINDING, "foreign Space token")
	assert_equal(Terrain.prepared_local_leaf_refusal(fixture.exact_terrain, bounds, Terrain.DIG,
		_request.space_revision, fixture.orders._stage_token, fixture.orders._room_cold_token + 1), Terrain.REFUSE_BINDING, "foreign cold lease")
	assert_equal(Terrain.prepared_local_leaf_refusal(fixture.exact_terrain, bounds, Terrain.EXCLUSIONS + 1,
		_request.space_revision, fixture.orders._stage_token, fixture.orders._room_cold_token), Terrain.REFUSE_BOUNDS, "unknown purpose")
