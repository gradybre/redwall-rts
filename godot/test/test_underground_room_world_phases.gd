extends "res://test/framework/test_case.gd"
## Actual ordinary phase composition. Existing corridor bootstrap is explicit historical fixture state.
## Legacy automatic-heading negatives stay pinned to v2; paid SourceFixture retains the immutable reviewed v3 protocol5.
## Current protocol6 publication has its own catalog/runtime/itinerary gates; historical geometry never follows a moving path.

const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const WorldFixture := preload("res://test/test_underground_world_routes.gd")
const GroupFixture := preload("res://test/test_underground_connector_assemblies.gd")
const FirstPrefix := preload("res://test/test_underground_first_prefix.gd")
const Registration := preload("res://test/test_underground_furniture_work.gd")
const HistoricalSource := preload("res://data/underground/mole-worker/work-approach-v1/source_program.gd")
const SOURCE_WIRE: String = "res://data/underground/mole-worker/profile-publication-v3-frontier/mole-worker.ugprof"
const Pins := preload("res://data/underground/mole-worker/profile-publication-v2/catalog_source.gd")
const CurrentPins := preload("res://data/underground/mole-worker/profile-publication-v3-frontier/catalog_source.gd")
const LEGACY_WIRE: String = "res://data/underground/mole-worker/profile-publication-v2/mole-worker.ugprof"
const Locations := preload("res://scripts/core/underground_locations.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomBindings := preload("res://scripts/core/underground_room_bindings.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Scope := preload("res://scripts/core/underground_world_structure_scope.gd")
const Structure := preload("res://scripts/core/underground_phase_structure.gd")
const WorkFace := preload("res://scripts/core/underground_work_face.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const FLOOR: int = -4608
const X: int = WorldFixture.X
const Z: int = WorldFixture.Z
const NULL_REF: Vector2i = Vector2i(-1, 0)

class MissingEntryContacts extends FirstPrefix:
	## The actual entry is admitted, but its phase Contacts are deliberately never bound.
	func _make_phase_provider() -> WorldBindings:
		"""Construct the composite before actual Authority/Sites binding; no live authority is replaced."""
		return Provider.new()

class EntryRegression extends "res://test/test_underground_entry_world_bindings.gd":
	## Existing explicitly synthetic motion content tests only inherited Entry dispatch, not ordinary physical permission.
	func _make_phase_provider() -> WorldBindings:
		"""Both provider branches share the actual original owner graph from initialization."""
		return Provider.new()

class ObservedProvider extends Provider:
	## A negative-only successful observation boundary; every permission still runs the actual implementation.
	var observe_stage: int = -1
	var final_probe: Callable = Callable()
	var calls: int = 0

	func phase_final_observation_refusal(site: Vector2i, operation: int, stage: int,
			cold_token: int, space_token: int, companion_token: int) -> StringName:
		"""An actual late source/worker mutation occurs after all normal observers, before the original direct leaf."""
		var code: StringName = super.phase_final_observation_refusal(site, operation, stage,
			cold_token, space_token, companion_token)
		if code == &"" and stage == observe_stage and final_probe.is_valid():
			var callback: Callable = final_probe
			final_probe = Callable(); calls += 1
			callback.call(companion_token)
		return code

class Fixture extends WorldFixture:
	## Ordinary Room permission is production; only the already-existing corridor's initial geometry is a bootstrap.
	var endpoints: Locations = null
	var provider: Provider = null
	var sites: Sites = null
	var authority: Authority = null
	var router: Router = null
	var orders: Registration.SyntheticRegistration = null
	var rooms: RoomBindings = null
	var placements: Placements = null
	var groups: GroupFixture = null
	var structure: Structure = null
	var scope: Scope = null
	var face: WorkFace = null
	var phase_terrain: Terrain = null
	var corridor: Vector2i = NULL_REF
	var defer_contacts: bool = false
	var location_capacity: int = 16 # Fixed fixture arenas; a multi-cube loop raises them before _actual_fixture.
	var edge_capacity: int = 32

	func _actual_fixture(_obstruction: int = 0) -> void:
		"""Create one real generated World and a Mole, with no phase permission or paid progress assigned privately."""
		_residents = Residents.new(); _jobs = Jobs.new(_residents)
		_nodes = Nodes.new(_residents.directory())
		var forage: Forage = Forage.new(_residents.directory(), _jobs)
		var fishing: Fishing = Fishing.new(_residents.directory(), forage, _jobs)
		_world = World.new(_residents.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
		_inventory = Inventory.new(32, 64); _items = Items.new()
		assert_true(_items.load_default(_inventory).ok, "actual item definitions")
		assert_true(_world.generate(World.bound_request(_items).request).ok, "actual terrain")
		_world_ref = _residents.directory().create(Directory.KIND_WORLD)
		_worker = _residents.ref_of(_residents.spawn(&"mole").value)
		_transforms = Transforms.new(_residents.directory())
		assert_true(_transforms.place(_worker, X + 1280, FLOOR, Z + 512, 49152), "actual Mole pose")
		_buildings = Buildings.new(_residents.directory()); _construction = Construction.new(_buildings)
		_budget = Budget.new()
		_actual_profiles(); _actual_space(0); _actual_binding()
		_first = _endpoint(Vector3i(X - 1024, FLOOR, Z + 512), Locations.ROLE_TRANSIT)
		_last = _endpoint(Vector3i(X + 1280, FLOOR, Z + 512), Locations.ROLE_WORK)
		_bind_phase_provider()

	func _actual_profiles() -> void:
		"""Load the exact accepted source wire without editing flags or boxes; fingerprints are never bypassed in production."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64); _piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "exact World")
		_carry = Carry.new(); assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs); assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(18, 194, 1, 14520 + Profiles.CONTROL_RESERVE), &"", "exact published bank")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual profile owners")
		assert_equal(FileAccess.get_sha256(LEGACY_WIRE), Pins.WIRE_SHA, "immutable published bytes")
		assert_equal(_profiles.load_file(LEGACY_WIRE, Pins.WIRE_SHA, 1), &"", "unchanged physical source geometry")

	func _actual_space(_obstruction: int) -> void:
		"""Use exact concrete final-reader owners and an actual ordinary phase authority from the beginning."""
		_routes = Routes.new(_residents, _transforms)
		_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
		var domain: Space.Domain = Space.Domain.new()
		assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
			Vector3i(256, 48, 256), 16384, 8192, Space.MAX_CHECKS), &"", "actual finite Domain")
		_owner = Owner.new(_sources)
		assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual sparse owner")
		phase_terrain = _make_phase_terrain()
		assert_equal(phase_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual Terrain")
		provider = _new_provider()
		assert_equal(provider.configure(_world, phase_terrain, _owner, _sources, _budget), &"", "actual phase provider")
		authority = Authority.new(); assert_equal(authority.configure(_owner, provider, 32), &"", "actual spatial authority")
		sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, authority, 64, 128)
		assert_equal(sites.initialization_refusal(), &"", "actual paid Site owner")
		assert_equal(authority.bind_sites(sites), &"", "original Site identity")
		router = Router.new(_construction, _inventory, _pool, _items, _jobs, _work, sites)
		_actual_catalog(domain); _bind_orders(); _bootstrap_corridor()
		endpoints = Locations.new()
		assert_equal(endpoints.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, location_capacity,
			228 * location_capacity + 256 + Locations.AIR_ARENA_BYTES_PER_SLOT * location_capacity), &"", "exact Locations with an ADR1215 air pool")
		assert_equal(endpoints.bind_sites(sites), &"", "actual Sites")
		assert_equal(endpoints.bind_room_orders(orders), &"", "actual Room companion")

	func _make_phase_terrain() -> Terrain:
		"""Existing negative fixtures retain their explicit earlier-observer seam."""
		_terrain = ReenteringTerrain.new()
		return _terrain

	func _new_provider() -> Provider:
		"""All normal fixtures retain the exact original concrete provider."""
		return Provider.new()

	func _load_catalog(revision: int) -> StringName:
		"""Unused connector geometry is bounded authored test content, never ordinary phase permission."""
		var bytes: PackedByteArray = GroupFixture._catalog_wire(4, revision)
		bytes.encode_u32(44, 1)
		bytes.resize(bytes.size() - 44)
		var pace: int = bytes.size() - 36
		bytes.encode_s32(pace, 1)
		bytes.encode_s32(pace + 12, 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, _profiles.content_revision(), digest), "actual published source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func _bind_orders() -> void:
		"""Only old corridor identity receives the explicit bootstrap permit; every new Room uses actual confirmation."""
		rooms = RoomBindings.new(); assert_equal(rooms.configure(provider, sites, _budget), &"", "actual Room bindings")
		orders = Registration.SyntheticRegistration.new()
		assert_equal(orders.configure(router, _owner, _sources, RoomCatalog.new(), rooms), &"", "actual sole Room authority")
		assert_equal(rooms.configure_room_admission(orders, _levels), &"", "authored level")
		assert_equal(provider.bind_room_bindings(rooms), &"", "actual room mask")
		orders.permit_action = Buildings.SPATIAL_ROOM_CREATE; orders.permit_value = Buildings.ROOM_TYPE_CORRIDOR
		corridor = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_CORRIDOR).ref
		orders.permit_action = -1
		assert_true(_buildings.is_live_room(corridor), "pre-existing corridor bootstrap identity")

	func _bootstrap_corridor() -> void:
		"""These explicit existing physical rows do not claim a paid entrance or seed any Site history byte."""
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, corridor), &"", "actual old Room source")
		_floor = _bootstrap_region(token, PackedInt32Array([X - 4096, FLOOR, Z - 2048, X + 2048, FLOOR + 1, Z + 4096]), Space.FLOOR_DATUM)
		_bootstrap_region(token, PackedInt32Array([X - 4096, FLOOR, Z - 2048, X + 2048, FLOOR + 4096, Z + 4096]), Space.SUPPORTED_VOID)
		_bootstrap_region(token, PackedInt32Array([X - 4096, FLOOR - 1024, Z - 2048, X + 2048, FLOOR, Z + 4096]), Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "explicit old corridor geometry")
		_owner.publish(token)
		for x: int in range(-4, 2):
			for z: int in range(-2, 4):
				var claimed: Construction.OpResult = sites.claim_quantum(Vector3i(X + x * 1024, FLOOR, Z + z * 1024), corridor)
				assert_true(claimed.ok, "actual bootstrap Site identity only: %s" % claimed.error)

	func _bootstrap_region(token: int, box: PackedInt32Array, role: int) -> Vector2i:
		"""The named fixture boundary uses normal sparse source/geometry publication and exact full Room ownership."""
		var region: Owner.Region = Owner.Region.new()
		region.box = box; region.role = role; region.owner = corridor; region.level = 1
		region.section = NULL_REF if role == Space.FLOOR_DATUM else _floor
		var result: Owner.Result = _owner.stage_add(token, region)
		assert_equal(result.error, &"", "old physical row")
		return result.handle

	func _configuration() -> Binding.Configuration:
		"""Borrow each original runtime owner explicitly, with no alternate observation service."""
		var config: Binding.Configuration = Binding.Configuration.new()
		config.routes = _routes; config.owner = _owner; config.sources = _sources; config.locations = endpoints
		config.profiles = _profiles; config.catalog = _catalog; config.levels = _levels; config.movement = _movement
		config.residents = _residents; config.transforms = _transforms; config.world = _world
		config.terrain = phase_terrain; config.budget = _budget
		return config

	func _actual_binding() -> void:
		"""The actual graph and Room approach share these same immutable source and physical stores."""
		_binding = Binding.new(); assert_equal(_binding.configure(_configuration()), &"", "actual World routes")
		assert_equal(_routes.configure(endpoints, _owner, _sources, _buildings, _budget, _binding,
			Routes.MAX_LOCATIONS, edge_capacity, 4 * edge_capacity, 64, Routes.ARENA_BYTES), &"", "actual production node/hash ceiling")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual actor readers")
		assert_equal(rooms.configure_room_approach(_binding), &"", "actual approach")

	func _endpoint(point: Vector3i, role: int) -> Vector2i:
		"""Source-sized body air and stance support are separate exact physical obligations."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point; row.section = _floor; row.room = corridor; row.level = 1; row.role = role
		row.envelope = PackedInt32Array([X - 4096, FLOOR, Z - 2048, X + 2048, FLOOR + 4096, Z + 4096])
		row.support = PackedInt32Array([point.x - 406, FLOOR - 1, point.z - 406, point.x + 406, FLOOR, point.z + 406])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = endpoints.begin_prepare(cold).token
		var result: Locations.Result = endpoints.stage_add(token, row)
		assert_equal(result.error, &"", "actual supported endpoint")
		assert_equal(endpoints.seal(token), &"", "current endpoint")
		assert_true(endpoints.publish(token), "actual endpoint published")
		assert_equal(_budget.release(cold), &"", "same lease returned")
		return result.location

	func _edge() -> Routes.Edge:
		"""One exact ground span reaches the real existing WORK station without new geometry or source padding."""
		var edge: Routes.Edge = Routes.Edge.new()
		edge.from_location = _first; edge.to_location = _last
		edge.room = corridor; edge.section = _floor; edge.level = 1
		edge.family = -1; edge.variant = 0; edge.mode = Profiles.MODE_WALK
		edge.posture = Profiles.POSTURE_UPRIGHT; edge.content_revision = 1
		edge.geometry_revision = _owner.revision(); edge.point_count = 2
		edge.points = PackedInt32Array([X - 1024, FLOOR, Z + 512, X + 1280, FLOOR, Z + 512])
		edge.length_u = 2304
		return edge

	func _bind_phase_provider() -> void:
		"""No Placement exists, but the original issuer and its one shared context are bound for future mixed Rooms."""
		groups = GroupFixture.new(); groups._catalog = _catalog; groups._items = _items; groups._inventory = _inventory
		groups._bind_source(groups._group_wire(), PackedInt32Array([0, 2]), false, 2)
		assert_equal(groups._load_source(), &"", "actual unused grouping")
		placements = Placements.new(); assert_equal(placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "finite Placement owner")
		assert_equal(placements.bind_actual(_owner, endpoints, _routes, _budget, _catalog, groups._reader, groups._recipes, _construction), &"", "same actual owner tuple")
		scope = Scope.new(); assert_equal(scope.configure(provider, _levels, _budget), &"", "actual structural scope")
		structure = Structure.new(); assert_equal(structure.configure(scope, _owner, phase_terrain, _levels, sites, _budget), &"", "actual retained natural structure")
		assert_equal(provider.bind_phase_structure(structure, _levels), &"", "actual phase structure")
		face = WorkFace.new()
		if not defer_contacts:
			assert_equal(provider.bind_room_phase_contacts(_binding, face, placements, _first, 1, 1, Provider.ROOM_CONTROL_BYTES), &"", "actual ordinary contacts")

	func _assigned_work_actor() -> Vector2i:
		"""Actual assigned Job/equipment/pose selects WORK16; this bootstrap grants no Site work or walked arrival."""
		var row: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(row).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(row, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(row, 8, false).ok and _jobs.spawn_agent(row).ok, "actual agent")
		var store: Vector2i = _inventory.create_container(_world_ref, 1000000, -1, 0, true).ref
		var tool: Vector2i = _inventory.create_lot(store, _items.compiled_id(&"tool"), 1000, 0, 0, -1, 0, 0).ref
		assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual durable tool")
		assert_true(_gear.equip(tool, _worker).ok, "actual equipment")
		var made: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, 1000, 0)
		assert_true(made.ok and _jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok, "actual BUILD Job")
		assert_true(_jobs.assign_worker(row, made.value).ok and _work.claim_tool_for_work(row, tool).ok, "actual assignment and claim")
		assert_equal(_routes.admit_work_actor(_worker, made.ref, _last, 16, 1, 1, 0, -1, tool), &"", "current exact WORK profile")
		return made.ref

	func after_each() -> void:
		"""Drop adapters before their original owners; never mutate once-bound weak authorities to reset a World."""
		face = null; provider = null; structure = null; scope = null
		orders = null; rooms = null; placements = null; authority = null; router = null; sites = null
		if groups != null:
			groups._reader = null; groups._recipes = null; groups._catalog = null; groups._items = null; groups._inventory = null
		groups = null; endpoints = null; phase_terrain = null
		super.after_each()

class SourceFixture extends Fixture:
	## Actual reviewed v3 source geometry; world construction and economic checks remain mandatory.
	var tool: Vector2i = NULL_REF
	var material: Vector2i = NULL_REF
	var stock_wood: Vector2i = NULL_REF
	var stock_stone: Vector2i = NULL_REF
	var storage: Vector2i = NULL_REF
	var tick: int = 0
	var accepted_mwu: int = 0
	var storage_binding: Locations.InventoryLocations = null
	var observe_final: bool = false

	func _new_provider() -> Provider:
		"""Only explicit adversarial cases add the post-observation mutation hook."""
		return ObservedProvider.new() if observe_final else Provider.new()

	func _actual_fixture(obstruction: int = 0) -> void:
		"""Only the initial unregistered worker is placed at completed access; all subsequent motion uses Routes."""
		super._actual_fixture(obstruction)
		assert_true(_transforms.place(_worker, X - 1024, FLOOR, Z + 512, 49152), "initial actual access pose")

	func after_each() -> void:
		"""The actual Inventory endpoint authority outlives each phase and is released with the fixture."""
		if provider is ObservedProvider: (provider as ObservedProvider).final_probe = Callable()
		storage_binding = null
		super.after_each()

	func _make_phase_terrain() -> Terrain:
		"""The real Room approach requires its exact final-reader implementation, with no subclass exemption."""
		return Terrain.new()

	func _endpoint(point: Vector3i, role: int) -> Vector2i:
		"""The actual access is also the explicit finite material/refund/spoil STORAGE endpoint."""
		return super._endpoint(point, Locations.ROLE_STORAGE if role == Locations.ROLE_TRANSIT else role)

	func _actual_profiles() -> void:
		"""The create-only wire is independently pinned; no role, flag or source byte changes in this fixture."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64); _piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "exact World")
		_carry = Carry.new(); assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs); assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(26, 250, 1, 19224 + Profiles.CONTROL_RESERVE), &"", "exact historical v3 two-bank size")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual source owners")
		assert_equal(FileAccess.get_sha256(SOURCE_WIRE), CurrentPins.WIRE_SHA, "immutable reviewed historical v3 publication")
		assert_equal(_profiles.load_file(SOURCE_WIRE, CurrentPins.WIRE_SHA, 2), &"", "reviewed actual source geometry")
		assert_equal(_profiles.profile_count(2), 26, "exact reviewed historical profile count")
		for profile: int in range(2, 26):
			assert_equal(HistoricalSource.profile_refusal(_profiles, profile, 1, 2), &"", "exact historical source policy")

	func _load_catalog(revision: int) -> StringName:
		"""Two exact ground selectors inherit actual Movement's existing Mole speed; no new pace is authored."""
		var bytes: PackedByteArray = GroupFixture._catalog_wire(4, revision)
		bytes.encode_u32(44, 2); bytes.encode_s64(48, 2)
		bytes.resize(bytes.size() - 80)
		for profile: int in [5, 9]:
			GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, 2, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func _bind_phase_provider() -> void:
		"""Use the actual backward source for directed retreat; reuse the same inherited issuer/context."""
		defer_contacts = true
		super._bind_phase_provider()
		assert_equal(provider.bind_room_phase_contacts(_binding, face, placements, _first, 9, 1,
			Provider.ROOM_CONTROL_BYTES), &"", "actual backward source retreat")

	func _edge() -> Routes.Edge:
		"""Only the current content identity changes; original corridor geometry and complete path remain exact."""
		var edge: Routes.Edge = super._edge()
		edge.content_revision = 2
		return edge

	func connect_source_paths() -> void:
		"""Publish both complete directed certificates; no mirrored heading or free return edge is inferred."""
		var token: int = _begin()
		var forward: Routes.Edge = _edge()
		assert_equal(_routes.stage_add(token, forward).error, &"", "full forward5 clearance")
		var reverse: Routes.Edge = _edge()
		reverse.from_location = _last; reverse.to_location = _first
		reverse.points = PackedInt32Array([X + 1280, FLOOR, Z + 512, X - 1024, FLOOR, Z + 512])
		assert_equal(_routes.stage_add(token, reverse).error, &"", "full backward9 clearance")
		assert_equal(_binding.seal(token), &"", "actual directed certificates sealed")
		assert_equal(_binding.publish(token), &"", "actual graph plus certificate publication")
		_end(token)

	func room_request() -> Approach.Request:
		"""A real2x2 Kitchen request uses its exact first target and supported old corridor access."""
		var request: Approach.Request = Approach.Request.new()
		request.world = _world_ref; request.space_revision = _owner.revision()
		request.room_type = Buildings.ROOM_TYPE_KITCHEN; request.level = 1
		request.origin_u = Vector3i(X + 2048, FLOOR, Z)
		request.cell_size_u = 1024
		request.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
		request.access = _first; request.work_location = _last
		request.travel_profile = 5; request.travel_revision = 1
		request.work_profile = 24; request.work_revision = 1; request.content_revision = 2
		# DEC-054: the painted 4 m is clamped to the band the published WORK rows dig from the floor (2 m today).
		request.height_u = mini(4096, Approach.reachable_height_u(_profiles, request.work_profile))
		request.target_origin = request.origin_u; request.face = 0; request.yaw = 49152
		return request

	func finite_stock_and_worker() -> void:
		"""Explicit initial stock grants no haul credit; each paid phase still consumes the adopted actual bill."""
		storage_binding = Locations.InventoryLocations.new(endpoints)
		assert_true(_inventory.bind_spatial_locations(storage_binding, 4).ok, "actual storage authority")
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(_first)
		assert_true(made.ok, "finite material/refund/spoil store: %s" % made.error)
		material = made.ref; storage = _first
		stock_wood = stock(&"wood", 1000); stock_stone = stock(&"stone", 1000); tool = stock(&"tool", 1000)
		assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual basic pick")
		assert_true(_gear.equip(tool, _worker).ok, "actual carried pick")
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(worker).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(worker, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(worker, 8, false).ok and _jobs.spawn_agent(worker).ok, "actual worker availability")

	func check_full_plan_residuals(site: Vector2i, room: Vector2i) -> void:
		"""Every separate native floor-residual primitive remains surveyed and compared, never clipped into permission."""
		var cold: int = provider.begin_cold_operation(_owner, site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
		var plan: Space.Plan = Space.Plan.new()
		var code: StringName = provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT, room,
			provider.phase_plan_row_limit(_owner, cold), plan)
		assert_equal(code, &"", "complete real source plan with below-plane residuals")
		if code == &"":
			assert_equal(plan.volumes.role.size(), 9, "all eleven source boxes except point/patch remain")
			assert_equal(plan.contacts.profile_id.size(), 3, "only actual above-floor body/turn/approach are air contacts")
			for row: int in [1, 4, 6]:
				assert_equal(plan.volumes.lo_y[row], FLOOR - 1, "original exact lower residual")
				assert_equal(plan.volumes.hi_y[row], FLOOR, "full support-contact residual remains")
			plan.volumes.lo_y[1] += 1
			assert_equal(provider._ordinary_plan(plan, false), Provider.ENTRY_REFUSE_PLAN, "erased residual cannot qualify")
		plan = null
		provider.end_cold_operation(cold)

	func stock(key: StringName, quantity: int) -> Vector2i:
		"""Only explicit fixture initial goods use the source API; CUT is the sole earth producer."""
		var made: Inventory.OpResult = _inventory.create_lot(material, _items.compiled_id(key), quantity, 1, 0, -1, 0, 0)
		assert_true(made.ok, "finite initial %s: %s" % [key, made.error])
		return made.ref

	func open_phase_job(site: Vector2i, operation: int) -> Vector2i:
		"""Actual Site/Project/Job identities and existing work quotes precede any assignment or payment."""
		var opened: Construction.OpResult = sites.open_phase(site, operation)
		assert_true(opened.ok, "actual ordinary phase admission: %s" % opened.error)
		if not opened.ok: return NULL_REF
		var remaining: IntMath.IntResult = IntMath.IntResult.new()
		assert_true(_construction.remaining_mwu_into(opened.ref, remaining), "exact adopted remaining work")
		var created: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, remaining.value, 0)
		assert_true(created.ok and _jobs.set_requester(created.value, opened.ref).ok, "actual phase requester")
		assert_true(_jobs.set_tool_gate(created.value, Jobs.GATE_SATISFIED).ok, "real tool remains mandatory")
		assert_true(sites.bind_job(site, created.ref).ok, "one original full phase Job")
		var bound: Construction.OpResult = sites.bind_material_container(site, material)
		assert_true(bound.ok, "exact real reachable material contact: %s" % bound.error)
		if operation == Contract.OP_CUT:
			bound = sites.bind_output(site, material)
			assert_true(bound.ok, "finite spoil store: %s" % bound.error)
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.assign_worker(worker, created.value).ok, "actual worker assignment")
		assert_true(_work.claim_tool_for_work(worker, tool).ok, "actual exact equipped claim")
		return created.ref

	func walk_to_work(job: Vector2i) -> void:
		"""A complete headless source-ready approach arrives before any WORK source entry or earned credit."""
		assert_equal(_routes.admit_travel_actor(_worker, job, _first, 5, 1, 2, 0, -1, tool), &"", "actual ready-at-access actor")
		assert_equal(_routes.request_route(_worker, _last, tick), &"", "explicit +X route")
		wait_ready(job, 5)
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual arrived actor")
		assert_equal(actor.location, _last, "actual full work endpoint")
		assert_equal(actor.point, Vector3i(X + 1280, FLOOR, Z + 512), "actual root advanced exactly once")

	func wait_ready(job: Vector2i, profile: int) -> void:
		"""Canonical30Hz ticks, with no renderer, finish the real movement and source recovery."""
		var end: int = tick + 300
		while Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, 2) != &"" and tick < end:
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual headless ready transition")
			if not failures.is_empty(): return
		assert_equal(Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, 2), &"", "bounded actual ready terminal")

	func enter_work(job: Vector2i) -> void:
		"""The exact source entry is productive only after canonical readiness, independently of physical idle."""
		assert_equal(_routes.refresh_work_actor(_worker, job, 24, 1, 2, 0, -1, tool), &"", "ready-to-FRONT handoff")
		assert_equal(Routes.source_work_leaf_refusal(_routes, _worker, job, 24, 1, 2), &"ROUTE_SOURCE_WORK_NOT_READY", "entry grants no work")
		var end: int = tick + 100
		while Routes.source_work_leaf_refusal(_routes, _worker, job, 24, 1, 2) != &"" and tick < end:
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual headless source entry")
			if not failures.is_empty(): return
		assert_equal(Routes.source_work_leaf_refusal(_routes, _worker, job, 24, 1, 2), &"", "exact current source WORK")

	func start_phase(site: Vector2i, operation: int, job: Vector2i) -> void:
		"""Current exact input claims and actual worker contact enter the real guarded START transaction."""
		prepare_phase_inputs(site, operation, job)
		if not failures.is_empty(): return
		var started: Construction.OpResult = sites.begin_phase_work(site, tick)
		assert_true(started.ok, "real prepared ordinary START: %s" % started.error)

	func prepare_phase_inputs(site: Vector2i, operation: int, job: Vector2i) -> void:
		"""These real claims and worker registration precede payment and can be reused after an unchanged refusal."""
		for line: int in Contract.input_count(operation):
			var lot: Vector2i = stock_wood if Contract.input_key(operation, line) == &"wood" else stock_stone
			var batch: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Pool.PURPOSE_EXCAVATION_INPUT,
				Contract.input_milli(operation, line), tick + 100000])
			assert_true(_pool.claim_batch(job, batch, 1, _inventory).ok, "actual exact input claim")
		if Contract.input_count(operation) > 0:
			var delivered: Construction.OpResult = sites.record_deliveries(site)
			assert_true(delivered.ok, "current local actual claims: %s" % delivered.error)
		var bound: Construction.OpResult = sites.bind_worker(site)
		assert_true(bound.ok, "actual current worker at the exact source contact: %s" % bound.error)

	func earn_and_recover(job: Vector2i) -> void:
		"""Work owns WU/XP/wear; source motion owns only its canonical phase, and recovery precedes Job release."""
		var remaining: IntMath.IntResult = IntMath.IntResult.new()
		var row: int = _residents.directory().get_typed_row(job)
		var end: int = tick + 1000
		while _jobs.remaining_mwu_into(row, remaining) and remaining.value > 0 and tick < end:
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual current WORK source tick")
			var worked: Work.TickResult = _work.tick_solo(row)
			assert_true(worked.ok, "actual paid productive Work: %s" % worked.error)
			if not worked.ok or not failures.is_empty(): return
			accepted_mwu += worked.accepted_mwu
		assert_true(_jobs.remaining_mwu_into(row, remaining) and remaining.value == 0, "real quoted work complete")
		assert_equal(_routes.request_source_ready(_worker, job), &"", "stop at actual loop boundary and recover")
		wait_ready(job, 24)

	func retreat_after_settlement() -> void:
		"""Worker-free settlement is followed by actual backward locomotion with no surviving old Job permission."""
		assert_equal(_routes.refresh_travel_actor(_worker, NULL_REF, 9, 1, 2, 0, -1, tool), &"", "completed recovery hands off after Job release")
		assert_equal(_routes.request_route(_worker, _first, tick), &"", "explicit actual -X retreat")
		wait_ready(NULL_REF, 9)
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual returned actor")
		assert_equal(actor.location, _first, "original full retreat/storage contact")
		assert_equal(actor.point, Vector3i(X - 1024, FLOOR, Z + 512), "real reverse root displacement")

	func complete_source_phase(site: Vector2i, operation: int, first: bool) -> bool:
		"""One paid operation advances only through actual canonical motion, Work, Funding and original companions."""
		var job: Vector2i = open_phase_job(site, operation)
		if job == NULL_REF or not failures.is_empty(): return false
		if first: walk_to_work(job)
		if not failures.is_empty(): return false
		enter_work(job)
		if not failures.is_empty(): return false
		start_phase(site, operation, job)
		if not failures.is_empty(): return false
		earn_and_recover(job)
		if not failures.is_empty(): return false
		var settled: Construction.OpResult = sites.settle_phase(site)
		assert_true(settled.ok, "real ordinary operation%d settles once: %s" % [operation, settled.error])
		assert_true(_budget.is_quiescent(), "original phase cold lease returned")
		return settled.ok

var _h: Fixture = null
var _entry_fixture: FirstPrefix = null
var _nested_bind_code: StringName = &""

func after_each() -> void:
	"""Each isolated actual composition frees all owners and propagates its real setup/cleanup assertions."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null
	if _entry_fixture != null:
		_entry_fixture.after_each()
		assert_true(_entry_fixture.failures.is_empty(), "inherited actual Entry fixture: %s" % _entry_fixture.failures)
	_entry_fixture = null

func test_initial_actual_binding_uses_one_context_without_phase_permission() -> void:
	"""Binding current immutable geometry creates no Room, Site history, WIP, paid prefix or new context."""
	_h = Fixture.new(); _h._actual_fixture()
	assert_true(_h.failures.is_empty(), "actual initial binding: %s" % _h.failures)
	assert_equal(_h.placements._live.header[Placements.H_COUNT], 0, "no fabricated connector Placement")
	assert_equal(_h.sites._ever_cut.count(1), 0, "no injected paid Site history")
	assert_true(_h.provider.qualification_revision() > 0, "all original source owners current")
	assert_false(_h.provider._ordinary_entry_room(_h.corridor), "painted Corridor is ordinary without a Placement")
	assert_equal(_h.provider.bind_room_phase_contacts(_h._binding, _h.face, _h.placements,
		_h._first, 1, 1, Provider.ROOM_CONTROL_BYTES), Provider.ROOM_REFUSE_BINDING, "once-only binding")
	assert_true(_h._budget.is_quiescent(), "no retained cold lease")


func test_published_ground_profile_still_refuses_the_front_work_station_wall() -> void:
	"""Preserve the real source gap: the yaw-all held pick enters the solid wall even though FRONT work fits."""
	_h = Fixture.new(); _h._actual_fixture()
	assert_true(_h.failures.is_empty(), "actual initial binding: %s" % _h.failures)
	var before: PackedByteArray = _h._owner.state_bytes()
	var token: int = _h._begin()
	var added: WorldFixture.Routes.Result = _h._routes.stage_add(token, _h._edge())
	assert_equal(added.error, &"WORLD_ROUTE_NO_FITTING_PROFILE", "published 1256u held-tool radius cannot fit 768u wall contact")
	_h._end(token)
	assert_equal(_h._routes._live.edge_count, 0, "no fabricated fitting profile or path")
	assert_equal(_h._owner.state_bytes(), before, "no geometry expansion to waive full source collision")


func _face_request() -> WorkFace.Request:
	"""The exact source FRONT contact is centered inside one actual datum-aligned virgin cube face."""
	var request: WorkFace.Request = WorkFace.Request.new()
	request.location = _h._last; request.target_origin = Vector3i(X + 2048, FLOOR, Z)
	request.face = 0; request.profile_id = 16; request.profile_revision = 1
	request.content_revision = 1; request.geometry_revision = _h._owner.revision(); request.yaw = 49152
	return request


func test_actual_published_front_motion_fits_the_current_solid_face() -> void:
	"""Complete source body/recovery/stance/stroke and contact qualify locally; this does not create a travel transition."""
	_h = Fixture.new(); _h._actual_fixture()
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_h.face.solid_face_refusal(_h._configuration(), _face_request(), cold), &"", "actual complete source work-face proof")
	assert_equal(_h._budget.release(cold), &"", "proof dies before original lease release")
	assert_equal(_h._routes._live.edge_count, 0, "contact is not an approach or movement permission")


func test_location_restore_invalidates_qualification_until_a_fresh_publication() -> void:
	"""Bank epochs can rewind legally; original non-restored publication tokens cannot be replayed by a saved image."""
	_h = Fixture.new(); _h._actual_fixture()
	var before: int = _h.provider.qualification_revision()
	var saved: PackedByteArray = PackedByteArray()
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_h.endpoints.capture_state_into(cold, saved), &"", "original leased snapshot")
	assert_equal(_h.endpoints.restore_state_bytes(cold, saved), &"", "real same-world restore")
	assert_equal(_h.provider.qualification_revision(), 0, "restore clears the required publication receipt")
	assert_equal(_old_worker_qualification(before), Provider.ROOM_REFUSE_SOURCE, "old qualification cannot be reused after restore")
	var token: int = _h.endpoints.begin_prepare(cold).token
	assert_equal(_h.endpoints.seal(token), &"", "all current endpoint/source facts freshly proved")
	assert_equal(_h.provider.revision_after(token), 0, "a real Location token alone is not an original prepared phase context")
	assert_true(_h.endpoints.publish(token), "new exact publication")
	assert_true(_h.provider.qualification_revision() > before, "next token never rewinds with saved header")
	assert_equal(_old_worker_qualification(before), Provider.ROOM_REFUSE_SOURCE, "old qualification also cannot alias the new publication")
	assert_equal(_h._budget.release(cold), &"", "original lease released")


func test_actual_profile_publication_or_replacement_invalidates_the_qualification() -> void:
	"""Source reload and equal-number foreign owner replacement cannot reuse the old cached phase epoch."""
	_h = Fixture.new(); _h._actual_fixture()
	var before: int = _h.provider.qualification_revision()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(LEGACY_WIRE)
	bytes.encode_s64(12, 2)
	assert_equal(_h._profiles.load_file(WorldFixture.PROFILE_TEMP, _h._write(WorldFixture.PROFILE_TEMP, bytes), 2), &"", "real monotone source reload")
	assert_true(_h.provider.qualification_revision() > before, "profile alone changes qualification")
	var original: Profiles = _h._binding._profiles
	_h._binding._profiles = Profiles.new()
	assert_equal(_h.provider.qualification_revision(), 0, "different actual owner refuses even before numbers matter")
	_h._binding._profiles = original


func test_overflow_refuses_before_any_qualification_cache_mutation() -> void:
	"""Checked arithmetic has no mutable epoch/cache side effect and cannot wrap into an older permission."""
	assert_equal(Provider._ordinary_revision_add(9223372036854775807, 1), 0, "overflow is unavailable")
	assert_equal(Provider._ordinary_revision_add(0, 1), 0, "unavailable prefix propagates")
	assert_equal(Provider._ordinary_revision_add(4, 8), 12, "valid exact sum")


func test_expired_optional_entry_receiver_cannot_become_a_never_bound_ordinary_epoch() -> void:
	"""A refusal-only lifetime fault must not upgrade to permission when its actual RefCounted receiver expires."""
	_h = Fixture.new(); _h._actual_fixture()
	var ordinary: int = _h.provider.qualification_revision()
	assert_true(ordinary > 0 and _h.provider._entry_contacts == null, "never-bound optional Entry uses the valid ordinary epoch")
	var receiver: Provider.PhaseContacts = Provider.PhaseContacts.new()
	var original: WeakRef = weakref(receiver)
	_h.provider._entry_contacts = original
	assert_equal(_h.provider.qualification_revision(), 0, "live unconfigured foreign receiver is a refusal-only injected fault")
	receiver = null
	assert_equal(original.get_ref(), null, "actual receiver lifetime ended")
	var config: WorldFixture.Binding.Configuration = _h.provider._ordinary_config
	var query: WorkFace.Request = _h.provider._ordinary_query
	var context: Locations.PhaseContext = _h.placements._phase_context
	var space: PackedByteArray = _h._owner.state_bytes()
	var state: PackedByteArray = _h.sites.state_bytes()
	var before: PackedInt64Array = PackedInt64Array([_h._budget._next_token, _h._budget._token,
		_h._budget._used, _h._budget._peak, _h.endpoints._last_published_token, _h._routes._last_published_token])
	for attempt: int in 4:
		assert_equal(_h.provider.qualification_revision(), 0, "expired original receiver remains unavailable on read %d" % attempt)
	assert_equal(_h.provider._entry_contacts, original, "no implicit unbinding or replacement")
	assert_true(_h.provider._ordinary_config == config and _h.provider._ordinary_query == query \
		and _h.placements._phase_context == context, "existing packets are reused without replacement")
	assert_true(_h._owner.state_bytes() == space and _h.sites.state_bytes() == state, "no physical or paid state changes")
	assert_equal(PackedInt64Array([_h._budget._next_token, _h._budget._token, _h._budget._used, _h._budget._peak,
		_h.endpoints._last_published_token, _h._routes._last_published_token]), before, "no lease, allocation admission or publication mutation")


func test_actual_max_revision_source_makes_qualification_unavailable_without_wrapping() -> void:
	"""An accepted maximum int64 source revision cannot silently wrap a derived phase qualifier into an old value."""
	_h = Fixture.new(); _h._actual_fixture()
	var before: int = _h.provider.qualification_revision()
	assert_equal(_h._load_catalog(9223372036854775807), &"", "actual source loader accepts the exact monotone maximum")
	assert_equal(_h.provider.qualification_revision(), 0, "combined revision overflow is unavailable")
	assert_equal(_old_worker_qualification(before), Provider.ROOM_REFUSE_SOURCE, "old work qualification remains refused")
	assert_equal(_h.sites._ever_cut.count(1), 0, "no paid state created by arithmetic failure")


func _old_worker_qualification(revision: int) -> StringName:
	"""A cached caller epoch must be rejected before any Site, worker or geometry permission can be reused."""
	return _h.provider.worker_refusal(Vector3i(X + 2048, FLOOR, Z), Contract.OP_BRACE,
		_h.corridor, NULL_REF, _h._worker, _h._owner.revision(), revision)


func test_independent_catalog_change_and_coincident_foreign_revision_refuse_old_cache() -> void:
	"""A catalog reload changes the real source tuple independently; another owner cannot borrow matching sums."""
	_h = Fixture.new(); _h._actual_fixture()
	var before: int = _h.provider.qualification_revision()
	assert_equal(_h._load_catalog(2), &"", "actual immutable catalog revision alone advances")
	assert_true(_h.provider.qualification_revision() > before, "catalog alone changes qualification")
	assert_equal(_old_worker_qualification(before), Provider.ROOM_REFUSE_SOURCE, "old catalog cannot qualify Work")
	var original: WorldFixture.Catalog = _h._binding._catalog
	var foreign: WorldFixture.Catalog = WorldFixture.Catalog.new()
	assert_equal(foreign.configure(WorldFixture.Catalog.RESERVED_BYTES), &"", "independent finite owner")
	_h._binding._catalog = foreign
	assert_equal(_h.provider.qualification_revision(), 0, "foreign identity refuses independent of any revision arithmetic")
	_h._binding._catalog = original


func test_work_endpoint_publication_without_space_change_invalidates_the_old_epoch() -> void:
	"""A changed current selector cannot borrow an old phase qualification merely because Space stayed unchanged."""
	_h = Fixture.new(); _h._actual_fixture()
	var before: int = _h.provider.qualification_revision()
	var geometry: int = _h._owner.revision()
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var token: int = _h.endpoints.begin_prepare(cold).token
	assert_equal(_h.endpoints.stage_remove(token, _h._last), &"", "retire actual old unretained WORK contact")
	assert_equal(_h.endpoints.seal(token), &"", "changed exact selector set")
	assert_true(_h.endpoints.publish(token), "real Location publication")
	assert_equal(_h._budget.release(cold), &"", "same original lease")
	assert_equal(_h._owner.revision(), geometry, "no Space publication occurred")
	assert_true(_h.provider.qualification_revision() > before, "monotone Location receipt changes qualification")
	assert_equal(_old_worker_qualification(before), Provider.ROOM_REFUSE_SOURCE, "old selector proof refuses before Work")


func _bind_contacts() -> StringName:
	"""Use the original once-bound actual owners for initialization and retry."""
	return _h.provider.bind_room_phase_contacts(_h._binding, _h.face, _h.placements,
		_h._first, 1, 1, Provider.ROOM_CONTROL_BYTES)


func _nested_bind() -> void:
	"""An actual Terrain binding observer tries to allocate the same contact packet recursively."""
	_nested_bind_code = _bind_contacts()


func test_reentrant_initial_binding_refuses_without_allocating_or_publishing_context() -> void:
	"""The ordinary observation bracket closes before the one shared PhaseContext and fixed packet can bind."""
	_h = Fixture.new(); _h.defer_contacts = true; _h._actual_fixture()
	_h._terrain.binding_countdown = 1
	_h._terrain.binding_probe = _nested_bind
	assert_equal(_bind_contacts(), Provider.ENTRY_REFUSE_BUSY, "outer initialization poisoned")
	assert_equal(_nested_bind_code, Provider.ENTRY_REFUSE_BUSY, "nested initialization rejected")
	assert_equal(_h.provider._ordinary_config, null, "no packet allocated before complete admission")
	assert_equal(_h.placements._phase_context.authority, null, "no partial shared context binding")
	assert_equal(_bind_contacts(), &"", "ordinary valid retry succeeds")


func _clear_source_binding() -> void:
	"""The real earlier source observer drops one original provider reference before the final binding read."""
	_h.provider._source_reader = null


func test_late_initial_binding_loss_preserves_unbound_state_and_allows_corrected_retry() -> void:
	"""A successful old Terrain read cannot retain or allocate a partially invalid contact composition."""
	_h = Fixture.new(); _h.defer_contacts = true; _h._actual_fixture()
	_h._terrain.binding_countdown = 1
	_h._terrain.binding_probe = _clear_source_binding
	assert_equal(_bind_contacts(), Provider.ROOM_REFUSE_BINDING, "direct final initialization leaf refuses missing original source")
	assert_equal(_h.provider._ordinary_config, null, "no retained partially initialized packet")
	assert_equal(_h.placements._phase_context.authority, null, "no new shared context link")
	_h.provider._source_reader = weakref(_h._sources)
	assert_equal(_bind_contacts(), &"", "same real composition may retry after correction")


func _replace_initial_route_field(field: StringName, replacement: Variant) -> void:
	"""The actual final Terrain binding observer changes a WorldRoutes field after its earlier checks."""
	_h._binding.set(field, replacement)


func _late_initial_route_field(field: StringName, replacement: Variant) -> void:
	"""A refused original tuple must publish neither the shared authority nor any ordinary packet."""
	_h = Fixture.new(); _h.defer_contacts = true; _h._actual_fixture()
	var original: Variant = _h._binding.get(field)
	_h._terrain.binding_countdown = 1
	_h._terrain.binding_probe = _replace_initial_route_field.bind(field, replacement)
	var code: StringName = _bind_contacts()
	_h._binding.set(field, original)
	assert_true(code != &"", "late original %s mutation returns a named refusal" % field)
	assert_equal(_h._terrain.binding_probe_count, 1, "real final Terrain observer executed")
	assert_equal(_h.provider._ordinary_routes, null, "no ordinary binding was published")
	assert_equal(_h.provider._ordinary_config, null, "no configuration allocation on refusal")
	assert_equal(_h.provider._ordinary_query, null, "no query allocation on refusal")
	assert_true(_h.provider._ordinary_checks.is_empty(), "no fixed output allocation on refusal")
	assert_equal(_h.placements._phase_context.authority, null, "shared authority binding unchanged")
	assert_equal(_bind_contacts(), &"", "same actual original tuple retries after restoration")
	_h.after_each()
	assert_true(_h.failures.is_empty(), "late original tuple fixture: %s" % _h.failures)
	_h = null


func test_late_initial_world_route_null_fields_preserve_unbound_state_and_retry() -> void:
	"""Every WorldRoutes field adopted by the ordinary configuration closes before any allocation or link."""
	for field: StringName in [&"_locations_ref", &"_profiles", &"_catalog", &"_levels", &"_movement", &"_residents", &"_transforms"]:
		_late_initial_route_field(field, null)


func test_late_initial_world_route_foreign_sources_preserve_unbound_state_and_retry() -> void:
	"""An existing typed but foreign source cannot become the once-bound ordinary source after observation."""
	_late_initial_route_field(&"_profiles", Profiles.new())
	_late_initial_route_field(&"_catalog", WorldFixture.Catalog.new())
	_late_initial_route_field(&"_levels", WorldFixture.Levels.new())


func _cleared_binding_refusal(owner: RefCounted, field: StringName) -> void:
	"""Each missing original binding must return a refusal without invalid-property diagnostics."""
	var original: Variant = owner.get(field)
	owner.set(field, null)
	assert_equal(_h.provider._ordinary_binding_leaf(), Provider.ROOM_REFUSE_BINDING, "cleared %s" % field)
	assert_equal(_h.provider.qualification_revision(), 0, "cleared source cannot retain a usable epoch")
	owner.set(field, original)
	assert_equal(_h.provider._ordinary_binding_leaf(), &"", "original exact %s restored" % field)


func test_missing_original_weak_bindings_refuse_cleanly_at_current_and_final_boundaries() -> void:
	"""Missing actual graph, owner, Construction and reciprocal Authority weak references never dereference null."""
	_h = Fixture.new(); _h._actual_fixture()
	for field: StringName in [&"_routes_ref", &"_owner_ref", &"_sources_ref", &"_locations_ref"]:
		_cleared_binding_refusal(_h._binding, field)
	_cleared_binding_refusal(_h.provider, &"_owner")
	_cleared_binding_refusal(_h.provider, &"_source_reader")
	_cleared_binding_refusal(_h._construction, &"_excavation_authority")
	_cleared_binding_refusal(_h.authority, &"_sites")
	_cleared_binding_refusal(_h.sites, &"_space")
	_cleared_binding_refusal(_h.placements, &"_construction")
	_cleared_binding_refusal(_h._terrain, &"_space")
	_cleared_binding_refusal(_h._terrain, &"_sources")
	_cleared_binding_refusal(_h._terrain, &"_world")


func test_assigned_worker_keeps_its_actual_contact_when_a_second_full_motion_fits() -> void:
	"""Contact selection is tested with actual Job/Routes state; this does not claim a paid Site or walked arrival."""
	_h = Fixture.new(); _h._actual_fixture()
	var second: Vector2i = _h._endpoint(Vector3i(X + 1280, FLOOR, Z + 640), Locations.ROLE_WORK)
	var request: WorkFace.Request = _face_request()
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	assert_equal(_h.face.solid_face_refusal(_h._configuration(), request, cold), &"", "first complete actual motion fits")
	request.location = second
	assert_equal(_h.face.solid_face_refusal(_h._configuration(), request, cold), &"", "second complete actual motion fits")
	assert_equal(_h._budget.release(cold), &"", "both physical proofs dropped")
	_h.provider._ordinary_job = _h._assigned_work_actor()
	_h.provider._ordinary_worker = _h._worker
	_h.provider._entry_origin = request.target_origin
	_h.provider._entry_remaining = Space.MAX_CHECKS
	assert_equal(_h.provider._ordinary_unique_contact(), Provider.ROOM_REFUSE_CONTACT, "worker-free terminal selection is ambiguous")
	assert_equal(_h.provider._ordinary_committed_contact(), &"", "actual committed assigned contact is unambiguous")
	assert_equal(_h.provider._ordinary_query.location, _h._last, "uses original full current endpoint")
	assert_equal(_h.provider._ordinary_query.profile_id, 16, "uses original exact current WORK profile")
	_h.provider._ordinary_job.y += 1
	assert_equal(_h.provider._ordinary_committed_contact(), Provider.ROOM_REFUSE_WORKER, "a different full Job cannot borrow the selection")
	assert_equal(_h.sites._ever_cut.count(1), 0, "selector test seeds no paid phase history")


func test_even_a_remote_living_resident_requires_actual_physical_registration() -> void:
	"""No position-only cull may invent physical profiles; whole-host registration is an explicit prerequisite."""
	_h = Fixture.new(); _h._actual_fixture()
	_h._assigned_work_actor()
	_h.provider._entry_remaining = Space.MAX_CHECKS
	assert_equal(_h.provider._ordinary_occupants_leaf(_h._worker), &"", "only exact current worker present")
	var other: Vector2i = _h._residents.ref_of(_h._residents.spawn(&"mouse").value)
	assert_true(_h._transforms.place(other, X + 50000, 512, Z + 50000, 0), "actual remote surface resident")
	assert_equal(_h.provider._ordinary_occupants_leaf(_h._worker), Provider.ROOM_REFUSE_WORKER, "remote unregistered actor also refuses")
	assert_true(_h._residents.despawn(other).ok, "actual removal closes the unsupported host state")
	assert_equal(_h.provider._ordinary_occupants_leaf(_h._worker), &"", "same exact registered population retries")


func test_actual_entry_corridor_without_contacts_cannot_use_the_ordinary_branch() -> void:
	"""An unbound ordinary reader cannot substitute for the missing Entry binding; legacy source fixtures are synthetic."""
	_entry_fixture = MissingEntryContacts.new(); _entry_fixture.before_each()
	var actual: MissingEntryContacts = _entry_fixture as MissingEntryContacts
	var provider: Provider = actual._provider as Provider
	var admitted: Buildings.OpResult = actual._orders.confirm_entry(actual._entry_plan())
	assert_true(admitted.ok, "actual Entry Room and Placement: %s" % admitted.error)
	assert_equal(actual._placements._live.header[Placements.H_COUNT], 1, "actual full Entry Placement exists")
	assert_true(provider._ordinary_entry_room(admitted.ref), "unconfigured ordinary branch preserves Entry dispatch")
	assert_equal(provider._entry_actual(), null, "Entry phase Contacts remain unbound")
	var site: Vector2i = actual._sites.site_at(FirstPrefix.ORIGIN + Vector3i(-1024, -1024, -1024))
	var plan: Space.Plan = Space.Plan.new()
	assert_equal(provider.phase_plan_into(site, Contract.OP_BRACE, Contract.STAGE_ADMIT,
		admitted.ref, 64, plan), Provider.ENTRY_REFUSE_SCOPE, "ordinary contacts cannot substitute for missing Entry contacts")
	assert_equal(plan.volumes.role.size(), 0, "refusal copies no source plan")
	assert_equal(actual._world._construction.live_project_count(), 0, "refusal creates no paid Project")
	assert_true(actual._world._budget.is_quiescent(), "no borrowed phase lease escapes")


func test_shared_composite_preserves_real_entry_start_work_and_settlement() -> void:
	"""Existing synthetic-motion Entry regression exercises actual accounting; it is not an ordinary Room physical pass."""
	_entry_fixture = EntryRegression.new(); _entry_fixture.before_each()
	var actual: EntryRegression = _entry_fixture as EntryRegression
	assert_true(actual.failures.is_empty(), "actual inherited Entry initialization: %s" % actual.failures)
	actual.test_first_real_brace_requires_actual_start_work_settlement_and_conservation()
	assert_true(actual.failures.is_empty(), "original Entry paid lifecycle: %s" % actual.failures)


func test_actual_v3_source_confirms_ordinary_kitchen_through_both_directed_paths() -> void:
	"""The diagnostic source is real geometry, while native/publication acceptance remains explicitly separate."""
	_h = SourceFixture.new(); _h._actual_fixture()
	var actual: SourceFixture = _h as SourceFixture
	if not actual.failures.is_empty(): return
	actual.connect_source_paths()
	if not actual.failures.is_empty(): return
	var inventory: PackedByteArray = actual._inventory.state_bytes()
	var made: Buildings.OpResult = actual.orders.confirm_room(actual.room_request())
	assert_true(made.ok, "real Room admission with source5/24 and backward9: %s" % made.error)
	if not made.ok: return
	assert_equal(actual._inventory.state_bytes(), inventory, "confirmation buys no phase material")
	assert_equal(actual.sites.room_of(actual.sites.site_at(Vector3i(X + 2048, FLOOR, Z))), made.ref, "actual full Kitchen claim")
	assert_equal(actual._routes._live.edge_count, 2, "only explicitly proved directed paths")
	assert_equal(actual.sites._ever_cut.count(1), 0, "no paid history seeded by confirmation")
	actual.check_full_plan_residuals(actual.sites.site_at(Vector3i(X + 2048, FLOOR, Z)), made.ref)


func test_actual_v3_walk_brace_work_recovery_settlement_and_retreat() -> void:
	"""Real geometry/economy/owner publication is exercised; diagnostic source qualification and whole Room remain open."""
	_h = SourceFixture.new(); _h._actual_fixture()
	var actual: SourceFixture = _h as SourceFixture
	actual.connect_source_paths(); actual.finite_stock_and_worker()
	if not actual.failures.is_empty(): return
	var made: Buildings.OpResult = actual.orders.confirm_room(actual.room_request())
	assert_true(made.ok, "actual Kitchen confirmation: %s" % made.error)
	if not made.ok: return
	var site: Vector2i = actual.sites.site_at(Vector3i(X + 2048, FLOOR, Z))
	var job: Vector2i = actual.open_phase_job(site, Contract.OP_BRACE)
	if job == NULL_REF or not actual.failures.is_empty(): return
	actual.walk_to_work(job)
	if not actual.failures.is_empty(): return
	assert_equal(actual.accepted_mwu, 0, "real walking and ready transitions earn no work")
	actual.enter_work(job); actual.start_phase(site, Contract.OP_BRACE, job)
	if not actual.failures.is_empty(): return
	actual.earn_and_recover(job)
	if not actual.failures.is_empty(): return
	var settled: WorldFixture.Construction.OpResult = actual.sites.settle_phase(site)
	assert_true(settled.ok, "real worker-free paid BRACE settlement: %s" % settled.error)
	if not settled.ok: return
	assert_true(actual.sites.installed_support(site), "only paid completed BRACE installs support")
	assert_equal(actual.accepted_mwu, Contract.BRACE_WORK_MWU, "unchanged adopted work")
	assert_equal(actual._inventory.lot_quantity_milli(actual.stock_wood), 750, "actual adopted wood debit")
	assert_equal(actual._inventory.lot_quantity_milli(actual.stock_stone), 750, "actual adopted stone debit")
	assert_equal(actual.sites.support_conservation_refusal(), &"", "actual support conservation")
	actual.retreat_after_settlement()


func test_actual_v3_first_cube_brace_cut_finish_and_directed_retreat_conserve_every_owner() -> void:
	"""One paid cube is not a complete multi-cube Kitchen; only the tested source/geometry/economy sequence is asserted."""
	_h = SourceFixture.new(); _h._actual_fixture()
	var actual: SourceFixture = _h as SourceFixture
	actual.connect_source_paths(); actual.finite_stock_and_worker()
	if not actual.failures.is_empty(): return
	var made: Buildings.OpResult = actual.orders.confirm_room(actual.room_request())
	assert_true(made.ok, "actual2×2 Kitchen confirmation: %s" % made.error)
	if not made.ok: return
	var site: Vector2i = actual.sites.site_at(Vector3i(X + 2048, FLOOR, Z))
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		if not actual.complete_source_phase(site, operation, operation == Contract.OP_BRACE): return
	assert_equal(actual.accepted_mwu, Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU + Contract.FINISH_WORK_MWU, "all actual adopted work exactly once")
	assert_equal(actual._inventory.lot_quantity_milli(actual.stock_wood), 750, "one actual wood debit")
	assert_equal(actual._inventory.lot_quantity_milli(actual.stock_stone), 750, "one actual stone debit")
	assert_equal(actual.sites.virgin_sourced_milli(), Contract.EARTH_MILLI, "only actual CUT creates the adopted earth")
	assert_equal(actual.sites.support_conservation_refusal(), &"", "actual support conserved")
	assert_equal(actual.sites.earth_conservation_refusal(), &"", "actual earth conserved")
	assert_equal(actual.sites._phase[site.x], Sites.SUPPORTED_VOID, "actual finished paid cube")
	assert_equal(actual.sites._ever_cut.count(1), 1, "all other claimed Kitchen cubes remain unpaid")
	assert_equal(actual._construction.live_project_count(), 0, "no orphan phase Project")
	actual.retreat_after_settlement()


func _observed_source_site() -> Vector2i:
	"""Create the exact same real source/owner Kitchen and finite stock, adding only a negative callback hook."""
	var actual: SourceFixture = SourceFixture.new()
	actual.observe_final = true; _h = actual; actual._actual_fixture()
	actual.connect_source_paths(); actual.finite_stock_and_worker()
	if not actual.failures.is_empty(): return NULL_REF
	var made: Buildings.OpResult = actual.orders.confirm_room(actual.room_request())
	assert_true(made.ok, "actual observed Kitchen confirmation: %s" % made.error)
	return actual.sites.site_at(Vector3i(X + 2048, FLOOR, Z)) if made.ok else NULL_REF


func _late_actual_departure(_companion_token: int) -> void:
	"""Use the actual Transform owner after successful final observations; copied old pose is insufficient."""
	assert_true(_h._transforms.place(_h._worker, X + 1281, FLOOR, Z + 512, 49152), "real one-unit late departure")


func _late_original_site_change(companion_token: int) -> void:
	"""The public borrowed context cannot redirect a completed phase's original output transaction."""
	var context: Locations.PhaseContext = _h.authority.room_phase_context(companion_token)
	assert_true(context != null, "actual sealed original ordinary context")
	if context != null: context.site.y += 1


func test_actual_v3_late_worker_departure_refuses_payment_then_original_start_retries() -> void:
	"""The final direct worker leaf preserves finite stock/WIP/work/skill/wear after a successful old observation."""
	var site: Vector2i = _observed_source_site()
	if site == NULL_REF: return
	var actual: SourceFixture = _h as SourceFixture
	var job: Vector2i = actual.open_phase_job(site, Contract.OP_BRACE)
	actual.walk_to_work(job); actual.enter_work(job); actual.prepare_phase_inputs(site, Contract.OP_BRACE, job)
	if not actual.failures.is_empty(): return
	var inventory: PackedByteArray = actual._inventory.state_bytes()
	var funding: PackedByteArray = actual.router._funding.state_bytes()
	var work: PackedByteArray = actual._work.state_bytes()
	var gear: PackedByteArray = actual._gear.state_bytes()
	var geometry: PackedByteArray = actual._owner.state_bytes()
	var observer: ObservedProvider = actual.provider as ObservedProvider
	observer.observe_stage = Contract.STAGE_START; observer.final_probe = _late_actual_departure
	var refused: WorldFixture.Construction.OpResult = actual.sites.begin_phase_work(site, actual.tick)
	assert_false(refused.ok, "late departed worker cannot pay")
	assert_equal(observer.calls, 1, "the genuine late observation ran")
	assert_equal(actual._inventory.state_bytes(), inventory, "all finite stock and claims preserved")
	assert_equal(actual.router._funding.state_bytes(), funding, "no funded WIP escaped")
	assert_true(actual._work.state_bytes() == work and actual._gear.state_bytes() == gear, "no work/XP/wear on refusal")
	assert_equal(actual._owner.state_bytes(), geometry, "no partial Space publication")
	assert_true(actual._budget.is_quiescent(), "original candidate was discarded")
	assert_true(actual._transforms.place(actual._worker, X + 1280, FLOOR, Z + 512, 49152), "restore the negative-only physical mutation")
	var retry: WorldFixture.Construction.OpResult = actual.sites.begin_phase_work(site, actual.tick)
	assert_true(retry.ok, "same original unpaid phase retries: %s" % retry.error)
	assert_equal(actual._inventory.lot_quantity_milli(actual.stock_wood), 750, "exactly one actual debit")
	assert_equal(actual.accepted_mwu, 0, "START earns no productive credit")


func test_actual_v3_worker_free_cut_output_retry_reproves_original_context_without_more_work() -> void:
	"""A released worker is not reacquired to retry terminal output; original full Site and sealed context still matter."""
	var site: Vector2i = _observed_source_site()
	if site == NULL_REF: return
	var actual: SourceFixture = _h as SourceFixture
	if not actual.complete_source_phase(site, Contract.OP_BRACE, true): return
	var job: Vector2i = actual.open_phase_job(site, Contract.OP_CUT)
	actual.enter_work(job); actual.start_phase(site, Contract.OP_CUT, job); actual.earn_and_recover(job)
	if not actual.failures.is_empty(): return
	var inventory: PackedByteArray = actual._inventory.state_bytes()
	var funding: PackedByteArray = actual.router._funding.state_bytes()
	var geometry: PackedByteArray = actual._owner.state_bytes()
	var observer: ObservedProvider = actual.provider as ObservedProvider
	observer.observe_stage = Contract.STAGE_COMMIT; observer.final_probe = _late_original_site_change
	var refused: WorldFixture.Construction.OpResult = actual.sites.settle_phase(site)
	assert_false(refused.ok, "changed full Site in original sealed context refuses output")
	assert_equal(observer.calls, 1, "real terminal final observer executed")
	assert_true(actual._inventory.state_bytes() == inventory and actual.router._funding.state_bytes() == funding, "output journal and paid receipt preserved")
	assert_equal(actual._owner.state_bytes(), geometry, "no partial terminal topology")
	assert_equal(actual._jobs.worker_of(actual._residents.directory().get_typed_row(job)), NULL_REF, "actual terminal path already released worker")
	assert_equal(actual._work.tool_job_of(actual._residents.directory().get_typed_row(actual._worker)), NULL_REF, "actual tool claim released after recovery")
	assert_equal(actual.sites.virgin_sourced_milli(), 0, "no earth emitted by refused output")
	var retry: WorldFixture.Construction.OpResult = actual.sites.settle_phase(site)
	assert_true(retry.ok, "original worker-free completed CUT retries: %s" % retry.error)
	assert_equal(actual.accepted_mwu, Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU, "no extra WU to retry output")
	assert_equal(actual.sites.virgin_sourced_milli(), Contract.EARTH_MILLI, "exactly one adopted CUT output")
	assert_equal(actual.sites.earth_conservation_refusal(), &"", "actual output conserves")
	assert_true(actual._budget.is_quiescent(), "original lease and companion context released")
