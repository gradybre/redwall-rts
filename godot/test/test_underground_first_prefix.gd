extends "res://test/framework/test_case.gd"
## First-prefix integration fixture. All stores and geometry observations are actual owners.
## Motion certificates below are SYNTHETIC; they cannot activate the supplied worker or stair travel.

const GroundTests := preload("res://test/test_underground_surface_anchor.gd")
const ContactTests := preload("res://test/test_underground_connector_contacts.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const CatalogTests := preload("res://test/test_underground_connector_catalog.gd")
const WorldTests := preload("res://test/test_underground_world_routes.gd")
const Anchor := preload("res://scripts/core/underground_surface_anchor.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const Geometry := preload("res://scripts/core/connector_geometry.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const EntryBindings := preload("res://scripts/core/underground_entry_bindings.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const EntryCuts := preload("res://scripts/core/underground_entry_cut_map.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const Contacts := preload("res://scripts/core/underground_connector_contacts.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Modular := preload("res://scripts/core/modular_project_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Provenance := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SOURCE_REVISION: int = 31
const SOURCE_PATH: String = "user://first-prefix-frontier.bin"
const FIXTURE_PATH: String = "../docs/design/underground-planning/first-entry-prefix-v1.json"
const FIXTURE_SHA: String = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"
const ORIGIN: Vector3i = Vector3i(WorldTests.X + 1024, 512, WorldTests.Z)

class Source extends RefCounted:

	static func read_fixture() -> Dictionary:
		"""Load the exact reviewed engineering fixture; no live content file is authored by this suite."""
		var path: String = ProjectSettings.globalize_path("res://").path_join(FIXTURE_PATH)
		if FileAccess.get_sha256(path) != FIXTURE_SHA: return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		return parsed as Dictionary if parsed is Dictionary else {}

	static func profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""Synthetic BUILD certificates use the fixture's real target offset, never the digging source's patch."""
		var bytes: PackedByteArray = ContactTests.Content.profile_image(identity)
		var box_start: int = 64 + 6 * Profiles.PROFILE_WIRE_BYTES
		for rotation: int in 4:
			for role: int in [Profiles.WORK_STROKE, Profiles.CONTACT_POINT, Profiles.CONTACT_PATCH]:
				var box: PackedInt32Array = PackedInt32Array([-16, -32, -480, 16, 0, -384])
				if role == Profiles.CONTACT_POINT: box = PackedInt32Array([0, 0, -448, 0, 0, -448])
				if role == Profiles.CONTACT_PATCH: box = PackedInt32Array([-8, 0, -464, 8, 0, -432])
				box = ContactTests.Content._rotate(box, rotation)
				for axis: int in 6:
					bytes.encode_s32(box_start + (3 + rotation * 7 + role) * 28 + axis * 4, box[axis])
		return bytes

	static func catalog_image(spec: Dictionary, revision: int) -> PackedByteArray:
		"""One finite variant encodes every reviewed positive timber prism once, with no authored stair pace."""
		var bytes: PackedByteArray = CatalogTests.synthetic_image(revision, 2).slice(0, CatalogTests.VARIANT_BASE)
		var counts: PackedInt32Array = PackedInt32Array([1, 2, 26, 14, 56, 1, 1])
		for table: int in 7: bytes.encode_u32(20 + table * 4, counts[table])
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 1, 0, 0, -512, 0, -128, -2304,
			0, 0, 0, 0, 0, 2, 0, 26, 0, 14, 0, 56, 0, 0, Profiles.MODE_WALK, 0, 1]), 1)
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, -512, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([0, -128, -2304, 0]))
		_catalog_regions(bytes, spec)
		_catalog_parts(bytes, spec)
		CatalogTests._append_row(bytes, PackedInt32Array([1024]))
		CatalogTests._append_row(bytes, PackedInt32Array([0, -1, 0, 0, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return bytes

	static func _catalog_regions(bytes: PackedByteArray, spec: Dictionary) -> void:
		"""LANDING is floor metadata only; exact natural bearing and timber rows do not create usable void."""
		CatalogTests._append_row(bytes, PackedInt32Array([-1024, -1152, -3072, 1024, 1157, 0, Space.ENVELOPE, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([-1024, 0, -2048, 1024, 1, 0, Space.LANDING, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([-1024, -128, -2560, 1024, -127, -2048, Space.LANDING, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([-1024, 0, -128, 1024, 1157, 0, Space.OPENING, 0]))
		for bearing: Dictionary in spec["natural_bearings"]:
			var row: PackedInt32Array = PackedInt32Array(bearing["bounds_u"])
			row.append_array(PackedInt32Array([Space.SUPPORT_REQUIRED, 0]))
			CatalogTests._append_row(bytes, row)
		for part: Dictionary in spec["parts"]:
			var row: PackedInt32Array = PackedInt32Array(part["bounds_u"])
			row.append_array(PackedInt32Array([Space.SOLID, 0]))
			CatalogTests._append_row(bytes, row)

	static func _catalog_parts(bytes: PackedByteArray, spec: Dictionary) -> void:
		"""Existing top-polygon contract extrudes down by positive depth; posts are not fictitious deck AABBs."""
		for part: Dictionary in spec["parts"]:
			var box: PackedInt32Array = PackedInt32Array(part["bounds_u"])
			var kind: int = Geometry.POST if (int(part["id"]) % 7) >= 3 else Geometry.TREAD
			CatalogTests._append_row(bytes, PackedInt32Array([kind, box[4] - box[1], 0, -1, 0, 0, 0, int(part["id"]) * 4, 4]))
		for part: Dictionary in spec["parts"]:
			var box: PackedInt32Array = PackedInt32Array(part["bounds_u"])
			for point: Vector3i in [Vector3i(box[0], box[4], box[2]), Vector3i(box[3], box[4], box[2]),
					Vector3i(box[3], box[4], box[5]), Vector3i(box[0], box[4], box[5])]:
				CatalogTests._append_row(bytes, PackedInt32Array([point.x, point.y, point.z]))

	static func cube(ordinal: int) -> PackedInt32Array:
		"""L0's four cubes precede T0's two; each half-open key appears once."""
		var x: int = -1024 if ordinal % 2 == 0 else 0
		@warning_ignore("integer_division")
		var z: int = -1024 * (1 + ordinal / 2)
		return PackedInt32Array([x, -1024, z, x + 1024, 0, z + 1024])

	static func side_root(ordinal: int) -> Vector3i:
		"""A current natural station is outside the entire six-cube pocket, not a free scaffold or pending tread."""
		var box: PackedInt32Array = cube(ordinal)
		return Vector3i(-1408 if ordinal % 2 == 0 else 1408, 0, box[2] + 512)

	static func world_box(local: PackedInt32Array) -> PackedInt32Array:
		"""Test-only integer translation preserves the reviewed root datum and all six exact key boundaries."""
		return PackedInt32Array([local[0] + ORIGIN.x, local[1] + ORIGIN.y, local[2] + ORIGIN.z,
			local[3] + ORIGIN.x, local[4] + ORIGIN.y, local[5] + ORIGIN.z])

class PricedGroups extends GroupTests:
	func _recipe_wire(group_digest: String, anchors: PackedInt32Array) -> PackedByteArray:
		"""Only the two user-approved complete wood/joinery assemblies are charged; included parts have no bills."""
		var bytes: PackedByteArray = super._recipe_wire(group_digest, anchors)
		for ordinal: int in 2:
			var at: int = Recipes.WIRE_HEADER_BYTES + ordinal * Recipes.WIRE_ROW_BYTES
			bytes.encode_s64(at + 8, 32000 if ordinal == 0 else 12000)
			bytes.encode_s64(at + 24, 4000 if ordinal == 0 else 1000)
		return bytes

class ActualWorld extends GroundTests.ActualGround:
	var spec: Dictionary = {}

	func _actual_profiles() -> void:
		"""Bind actual Jobs/Work/Gear/Inventory first, then load clearly synthetic finite motion certificates."""
		super._actual_profiles()
		var identity: PackedInt32Array = PackedInt32Array([0, 0, 0])
		assert_true(_residents.spatial_profile_identity_into(_worker, identity), "actual worker species/rig")
		var bytes: PackedByteArray = _profile_image(identity)
		assert_equal(_profiles.load_file(WorldTests.PROFILE_TEMP, _write(WorldTests.PROFILE_TEMP, bytes), 2), &"", "synthetic source decoder")

	func _profile_image(identity: PackedInt32Array) -> PackedByteArray:
		"""A negative fixture may author invalid physical bounds through the same actual source decoder."""
		return Source.profile_image(identity)

	func _load_catalog(revision: int) -> StringName:
		"""The actual Catalog consumes only the exact pinned fourteen-part fixture wire."""
		var bytes: PackedByteArray = Source.catalog_image(spec, revision)
		return _catalog.load_file(WorldTests.TEMP, _write(WorldTests.TEMP, bytes), revision)

	func _actual_binding() -> void:
		"""Larger finite test graph admits existing surface paths, never implicit stair travel."""
		_binding = WorldRoutes.new()
		var config: WorldRoutes.Configuration = WorldRoutes.Configuration.new()
		config.routes = _routes; config.owner = _owner; config.sources = _sources; config.locations = _locations
		config.profiles = _profiles; config.catalog = _catalog; config.levels = _levels; config.movement = _movement
		config.residents = _residents; config.transforms = _transforms; config.world = _world
		config.terrain = _terrain; config.budget = _budget
		assert_equal(_binding.configure(config), &"", "actual route certificate provider")
		assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
			32, 32, 128, 128, Routes.ARENA_BYTES), &"", "finite graph")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual worker owners")

var _spec: Dictionary = {}
var _world: ActualWorld = null
var _groups: PricedGroups = null
var _source: Frontier = null
var _anchor: Anchor = null
var _section: Vector2i = NULL_REF
var _endpoints: Array[Vector2i] = []
var _storage_binding: Locations.InventoryLocations = null
var _storage: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _wood: Vector2i = NULL_REF
var _stone: Vector2i = NULL_REF
var _tool: Vector2i = NULL_REF
var _provider: WorldBindings = null
var _authority: Authority = null
var _sites: Sites = null
var _router: Router = null
var _placements: Placements = null
var _bindings: EntryBindings = null
var _orders: Orders = null
var _contacts: Contacts = null
var _paid: ConnectorWork = null


func before_each() -> void:
	"""Prepare real empty World, source-bound assemblies and finite existing ground; no paid state is injected."""
	_spec = Source.read_fixture()
	assert_false(_spec.is_empty(), "exact reviewed1113 source")
	_world = _make_world()
	_world.spec = _spec
	_world.location_capacity = 32
	_world._actual_fixture()
	_groups = PricedGroups.new()
	_groups._catalog = _world._catalog; _groups._items = _world._items; _groups._inventory = _world._inventory
	_groups._bind_source(_groups._group_wire(2, 7), PackedInt32Array([0, 7]), false, 2)
	assert_equal(_groups._load_source(), &"", "actual complete grouping and wood-only recipes")
	_bind_frontier()
	_natural_surface()
	_remaining_surface_contacts()
	_surface_routes()
	_finite_stock_and_worker()
	_bind_paid_owners()
	assert_true(_world.failures.is_empty() and _groups.failures.is_empty(), "actual setup: %s / %s" % [_world.failures, _groups.failures])


func _make_world() -> ActualWorld:
	"""Test-only construction hook retains one real owner graph and unchanged default source content."""
	return ActualWorld.new()


func _bind_frontier() -> void:
	"""The actual immutable reader validates every fixed prior dependency; no loaded row is live progress."""
	_source = Frontier.new()
	var capacities: PackedInt32Array = PackedInt32Array([2, 8, 2, 10, 11, 6])
	assert_equal(_source.configure(capacities, Frontier.required_bytes(capacities)), &"", "finite frontier bank")
	assert_equal(_source.bind_actual(_world._catalog, _groups._reader, _groups._recipes, _world._profiles), &"", "actual source chain")
	var bytes: PackedByteArray = _frontier_image(capacities)
	assert_equal(_source.load_file(SOURCE_PATH, CatalogTests._write(SOURCE_PATH, bytes), SOURCE_REVISION), &"", "actual frontier decoder")


func _frontier_image(counts: PackedInt32Array) -> PackedByteArray:
	"""Two whole assemblies, eight explicit work stations and six individual phase episodes are independently encoded."""
	var bytes: PackedByteArray = "UGFRNT01".to_ascii_buffer(); bytes.resize(Frontier.WIRE_HEADER_BYTES)
	bytes.encode_u32(8, 1)
	var revisions: PackedInt64Array = PackedInt64Array([SOURCE_REVISION, 1, 1, GroupTests.GROUP_REVISION, GroupTests.RECIPE_REVISION, 2])
	for index: int in 6: bytes.encode_s64(12 + 8 * index, revisions[index])
	for index: int in 6: bytes.encode_u32(68 + 4 * index, counts[index])
	for index: int in 32:
		bytes[92 + index] = _groups._reader._digests[32 + index]
		bytes[124 + index] = _groups._reader._digests[index]
		bytes[156 + index] = _groups._reader._digests[64 + index]
		bytes[188 + index] = 7
	CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 0, 0, 1, 2, 4, 1, 0]))
	CatalogTests._append_row(bytes, PackedInt32Array([1, 1, 1, 1, 1, 6, 4, 1, 3]))
	_frontier_stations(bytes)
	for group: Dictionary in _spec["cut_groups"]:
		var row: PackedInt32Array = PackedInt32Array(group["bounds_u"])
		row.append(Sites.SUPPORTED_VOID)
		CatalogTests._append_row(bytes, row)
	_frontier_bearings(bytes)
	_frontier_endpoints(bytes)
	_frontier_episodes(bytes)
	bytes.append_array("UGFEND01".to_ascii_buffer())
	return bytes


func _frontier_stations(bytes: PackedByteArray) -> void:
	"""Each episode names its own external root; no source row makes a remote cube reachable."""
	_append_station(bytes, 0, Vector3i(-832, 0, 512), 0, 1)
	_append_station(bytes, 3, Vector3i(0, 0, -1536), 0, 1)
	for ordinal: int in 6:
		_append_station(bytes, 4 + ordinal, Source.side_root(ordinal),
			49152 if ordinal % 2 == 0 else 16384, 2 if ordinal % 2 == 0 else 4)


func _append_station(bytes: PackedByteArray, endpoint: int, root: Vector3i, yaw: int, profile: int) -> void:
	"""Only placement rotation0 is fixture-authored; other quarter-turn selectors explicitly remain absent."""
	CatalogTests._append_row(bytes, PackedInt32Array([endpoint, root.x, root.y, root.z, yaw, profile,
		Profiles.POSTURE_UPRIGHT, 3, Jobs.JOB_KIND_BUILD]), 1)
	for rotation: int in 3: CatalogTests._append_row(bytes, PackedInt32Array([-1]), 0)


func _frontier_bearings(bytes: PackedByteArray) -> void:
	"""Natural post bases are outside paid cuts; T0's fastening face is specifically the already-installed L0 deck."""
	for target: Dictionary in _spec["fastening_candidates"]:
		var ordinal: int = int(target["assembly"])
		var row: PackedInt32Array = PackedInt32Array([Frontier.NATURAL if ordinal == 0 else Frontier.INSTALLED_PART,
			-1 if ordinal == 0 else 0, -1 if ordinal == 0 else 0])
		row.append_array(PackedInt32Array(target["target_bounds_u"]))
		CatalogTests._append_row(bytes, row)
	for bearing: Dictionary in _spec["natural_bearings"]:
		var row: PackedInt32Array = PackedInt32Array([Frontier.NATURAL, -1, -1])
		row.append_array(PackedInt32Array(bearing["bounds_u"]))
		CatalogTests._append_row(bytes, row)


func _frontier_endpoints(bytes: PackedByteArray) -> void:
	"""Every material/output/retreat selector names an actual role and explicit synthetic travel profile."""
	_append_endpoint(bytes, Frontier.SURFACE_ANCHOR, -1, 0, Locations.ROLE_WORK, Vector3i(-832, 0, 512))
	_append_endpoint(bytes, Frontier.SURFACE_CONTACT, -1, 0, Locations.ROLE_STORAGE, Vector3i(512, 0, 512))
	_append_endpoint(bytes, Frontier.SURFACE_CONTACT, -1, 0, Locations.ROLE_STORAGE, Vector3i(-1408, 0, 512))
	_append_endpoint(bytes, Frontier.INSTALLED_CONTACT, 0, 1, Locations.ROLE_WORK, Vector3i(0, 0, -1536))
	for ordinal: int in 6:
		_append_endpoint(bytes, Frontier.SURFACE_CONTACT, -1, 0, Locations.ROLE_WORK, Source.side_root(ordinal))
	_append_endpoint(bytes, Frontier.INSTALLED_CONTACT, 1, 2, Locations.ROLE_WORK, Vector3i(0, -128, -2304))


func _append_endpoint(bytes: PackedByteArray, kind: int, assembly: int, datum: int, role: int, point: Vector3i) -> void:
	"""No endpoint allocation or route is caused by this immutable row; runtime must resolve its exact full identity."""
	CatalogTests._append_row(bytes, PackedInt32Array([kind, assembly, datum, role, point.x, point.y, point.z, 0]), 1)


func _frontier_episodes(bytes: PackedByteArray) -> void:
	"""Every BRACE/CUT/FINISH has an explicit station and output; the installed prefix is not a contact proof."""
	for ordinal: int in 6:
		var row: PackedInt32Array = Source.cube(ordinal)
		var station: int = 2 + ordinal
		row.append_array(PackedInt32Array([7, 0 if ordinal < 4 else 1, station, station, station,
			0, 0, 2 if ordinal < 4 else 6, 4, 1, 2, 4 + ordinal, 3]))
		CatalogTests._append_row(bytes, row)


func _natural_surface() -> void:
	"""Actual SurfaceAnchor independently proves each retained strip; no protected footing overlaps future cuts."""
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


func _remaining_surface_contacts() -> void:
	"""Reviewed1115 creates every full endpoint from actual natural facts in the original World section."""
	var roots: Array[Vector3i] = [Vector3i(-832, 0, 512), Vector3i(512, 0, 512), Vector3i(-1408, 0, 512)]
	for ordinal: int in 6: roots.append(Source.side_root(ordinal))
	for index: int in roots.size():
		if index == 0 or index == 3 or index == 4: continue
		var point: Vector3i = ORIGIN + roots[index]
		var role: int = Locations.ROLE_STORAGE if index == 1 or index == 2 else Locations.ROLE_WORK
		var body: PackedInt32Array = PackedInt32Array([point.x - 192, point.y, point.z - 192, point.x + 192, point.y + 900, point.z + 192])
		var support: PackedInt32Array = PackedInt32Array([point.x - 192, point.y - 128, point.z - 192, point.x + 192, point.y, point.z + 192])
		var added: Anchor.Result = _anchor.create_in_section(point, body, support, _section, role)
		assert_equal(added.error, &"", "actual separate endpoint %d" % index)
		_endpoints[index] = added.location


func _surface_routes() -> void:
	"""Explicit directed ground spans follow actual retained strips; no automatic route or future timber is used."""
	var lease: int = _world._budget.acquire(Budget.COLD_BYTES)
	var begun: Routes.Result = _world._binding.begin_prepare(lease)
	assert_equal(begun.error, &"", "real ground graph preparation")
	for pair: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(2, 3), Vector2i(1, 4),
			Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 8)]:
		assert_equal(_world._routes.stage_add(begun.token, _surface_edge(pair.x, pair.y)).error, &"", "explicit forward span")
		assert_equal(_world._routes.stage_add(begun.token, _surface_edge(pair.y, pair.x)).error, &"", "explicit reverse span")
	assert_equal(_world._binding.seal(begun.token), &"", "actual whole-body and support certificates")
	assert_equal(_world._binding.publish(begun.token), &"", "real graph/certificate publication")
	_world._binding.abort(begun.token)
	assert_equal(_world._budget.release(lease), &"", "ground graph scratch released")


func _surface_edge(first: int, last: int) -> Routes.Edge:
	"""One bounded same-section polyline names its actual endpoints and bends only on retained earth."""
	var edge: Routes.Edge = Routes.Edge.new()
	var from: Vector3i = _surface_point(first)
	var to: Vector3i = _surface_point(last)
	edge.from_location = _endpoints[first]; edge.to_location = _endpoints[last]
	edge.section = _section; edge.level = 0; edge.family = -1; edge.variant = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = 2; edge.geometry_revision = _world._owner.revision()
	edge.points = PackedInt32Array([from.x, from.y, from.z])
	if (first == 1 and last == 4) or (first == 4 and last == 1):
		var bend: Vector3i = ORIGIN + Vector3i(1408, 0, 512)
		edge.points.append_array(PackedInt32Array([bend.x, bend.y, bend.z]))
	edge.points.append_array(PackedInt32Array([to.x, to.y, to.z]))
	@warning_ignore("integer_division")
	edge.point_count = edge.points.size() / 3
	edge.length_u = absi(to.x - from.x) + absi(to.z - from.z)
	return edge


func _surface_point(index: int) -> Vector3i:
	"""Test-authored ground graph points exactly match the independent immutable endpoint selectors."""
	if index == 0: return ORIGIN + Vector3i(-832, 0, 512)
	if index == 1: return ORIGIN + Vector3i(512, 0, 512)
	if index == 2: return ORIGIN + Vector3i(-1408, 0, 512)
	return ORIGIN + Source.side_root(index - 3)


func _finite_stock_and_worker() -> void:
	"""One actual resident/tool and finite real goods cover only the adopted six phases and two assemblies."""
	_storage_binding = Locations.InventoryLocations.new(_world._locations)
	assert_true(_world._inventory.bind_spatial_locations(_storage_binding, 4).ok, "actual endpoint Inventory adapter")
	var material: Inventory.OpResult = _world._inventory.create_spatial_ground_staging(_endpoints[1])
	var output: Inventory.OpResult = _world._inventory.create_spatial_ground_staging(_endpoints[2])
	assert_true(material.ok and output.ok, "distinct finite spatial cells: %s / %s" % [material.error, output.error])
	_storage = material.ref; _output = output.ref
	assert_true(_storage != NULL_REF and _output != NULL_REF, "two finite spatial containers")
	_wood = _stock(&"wood", 6500)
	_stone = _stock(&"stone", 1500)
	_tool = _stock(&"tool", 1000)
	assert_true(_world._gear.create_gear(_world._inventory, _world._items, _tool, Gear.MANUFACTURE_BASIC).ok, "actual durable basic tool")
	assert_true(_world._gear.equip(_tool, _world._worker).ok, "actual resident equipment")
	var row: int = _world._residents.directory().get_typed_row(_world._worker)
	assert_true(_world._jobs.priorities().spawn(row).ok, "actual priorities")
	assert_true(_world._jobs.schedule().spawn(row, _world._jobs.schedule().default_template_id().value).ok, "actual schedule")
	assert_true(_world._jobs.schedule().resolve(row, 8, false).ok and _world._jobs.spawn_agent(row).ok, "actual worker readiness")
	for need: int in Needs.NEED_COUNT:
		var value: int = _world._residents.needs().need_of(row, need).value
		assert_true(_world._residents.needs().apply_need_event(row, need, 5000 - value).ok, "ordinary base-rate mood")


func _stock(key: StringName, quantity: int) -> Vector2i:
	"""Initial stock is explicit; actual CUT must remain the only producer of excavated earth."""
	var created: Inventory.OpResult = _world._inventory.create_lot(_storage, _world._items.compiled_id(key),
		quantity, 1, Provenance.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(created.ok, "finite initial %s: %s" % [key, created.error])
	return created.ref


func _bind_paid_owners() -> void:
	"""The real physical authority remains closed wherever its concrete phase provider has not been composed."""
	_provider = _make_phase_provider()
	assert_equal(_provider.configure(_world._world, _world._terrain, _world._owner, _world._sources,
		_world._budget), &"", "actual phase composer")
	_authority = Authority.new()
	assert_equal(_authority.configure(_world._owner, _provider, 8), &"", "actual phase authority")
	_sites = Sites.new(_world._construction, _world._inventory, _world._pool, _world._items,
		_world._jobs, _world._work, _authority, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual finite Site ledger")
	assert_equal(_authority.bind_sites(_sites), &"", "exact reciprocal Site authority")
	_router = Router.new(_world._construction, _world._inventory, _world._pool, _world._items,
		_world._jobs, _world._work, _sites)
	_placements = Placements.new()
	assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "actual finite Placement owner")
	assert_equal(_placements.bind_actual(_world._owner, _world._locations, _world._routes, _world._budget,
		_world._catalog, _groups._reader, _groups._recipes, _world._construction), &"", "exact installation source owners")
	_bind_entry_and_installation()


func _make_phase_provider() -> WorldBindings:
	"""A concrete phase subclass can reuse the same real fixture without rebinding any initialized owner."""
	return WorldBindings.new()


func _bind_entry_and_installation() -> void:
	"""One actual Buildings authority owns admission and installation; no permissive fixture subclass is present."""
	_bindings = EntryBindings.new()
	assert_equal(_bindings.configure(_provider, _sites, _world._budget), &"", "actual entry geometry")
	_orders = Orders.new()
	assert_equal(_orders.configure(_router, _world._owner, _world._sources, RoomCatalog.new(), _bindings), &"", "sole actual Room authority")
	assert_equal(_bindings.configure_room_admission(_orders, _world._levels), &"", "actual authored level identity")
	assert_equal(_world._locations.bind_room_orders(_orders), &"", "actual Room companion")
	assert_equal(_bindings.bind_entry(_source, _placements), &"", "exact physical Frontier")
	assert_equal(_provider.bind_room_bindings(_bindings), &"", "actual fine mask delegation")
	_contacts = _make_contacts()
	assert_equal(_contacts.configure(_placements, _router, _source, Contacts.CONTROL_BYTES), &"", "actual installation contact observations")
	_paid = ConnectorWork.new()
	assert_equal(_paid.configure(_placements, _router, _contacts), &"", "actual grouped paid adapter")


func _make_contacts() -> Contacts:
	"""Adversarial tests may observe a real contact callback without replacing its actual physical proof."""
	return Contacts.new()


func _entry_plan() -> EntryPlan.Request:
	"""The exact proposed fine claim keeps T0's unneeded half-cube tail outside usable Room space."""
	var plan: EntryPlan.Request = EntryPlan.Request.new()
	plan.world = _world._world_ref; plan.space_revision = _world._owner.revision()
	plan.base_level = 0; plan.origin_u = ORIGIN; plan.rotation = 0; plan.anchor = _endpoints[0]
	plan.catalog_row = 0; plan.catalog_revision = 1; plan.variant_revision = 1
	plan.grouping_revision = GroupTests.GROUP_REVISION; plan.recipe_revision = GroupTests.RECIPE_REVISION
	plan.frontier_revision = SOURCE_REVISION
	plan.source_digests.resize(128)
	for index: int in 96: plan.source_digests[index] = _source._digests[32 + index]
	for index: int in 32: plan.source_digests[96 + index] = _source._digests[index]
	plan.claims = Source.world_box(PackedInt32Array([-1024, -1024, -2048, 1024, 0, 0]))
	plan.claims.append_array(Source.world_box(PackedInt32Array([-1024, -1024, -2560, 1024, 0, -2048])))
	plan.opening_targets = PackedInt32Array([-1, 0, -1, 0])
	return plan


func after_each() -> void:
	"""Retained source/owner test helpers never escape into another suite or a live composition."""
	if _world != null:
		assert_true(_world._budget.is_quiescent(), "no escaped first-prefix lease")
		assert_true(_world._inventory.audit().ok and _world._pool.audit(_world._inventory).ok, "actual resource/claim audit")
	_paid = null; _contacts = null; _orders = null; _bindings = null; _placements = null
	_router = null; _sites = null; _authority = null; _provider = null
	_storage_binding = null; _anchor = null; _source = null; _groups = null
	_endpoints.clear()
	if _world != null:
		_world.after_each()
		assert_true(_world.failures.is_empty(), "actual World helper checks: %s" % _world.failures)
	_world = null
	for path: String in [SOURCE_PATH, GroupTests.GROUP_PATH, GroupTests.RECIPE_PATH, GroupTests.CATALOG_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_exact_two_assembly_prices_and_six_cube_phase_ledger() -> void:
	"""Expected prices derive from adopted contracts and full groups, not each visual prism or an invented rate."""
	var quote: Modular.Quote = Modular.Quote.new()
	var wood: int = 6 * Contract.input_milli(Contract.OP_BRACE, 0)
	var work: int = 6 * (Contract.work_mwu(Contract.OP_BRACE) + Contract.work_mwu(Contract.OP_CUT)
		+ Contract.work_mwu(Contract.OP_FINISH))
	assert_equal(wood, 1500, "six installed braces wood")
	assert_equal(6 * Contract.input_milli(Contract.OP_BRACE, 1), 1500, "six installed braces stone")
	assert_equal(work, 54000, "all18 actual phase bills")
	for ordinal: int in 2:
		assert_equal(_groups._recipes.recipe_into(0, 1, ordinal * 7, GroupTests.RECIPE_REVISION, quote), &"", "exact complete assembly quote")
		assert_equal(quote.input_count, 1, "wood only, no rope or per-part surcharge")
		assert_equal(quote.input_keys[0], &"wood", "actual named material")
		assert_equal(quote.input_milli[0], 4000 if ordinal == 0 else 1000, "approved quantity")
		assert_equal(quote.total_mwu, 32000 if ordinal == 0 else 12000, "approved BUILD work")
		wood += quote.input_milli[0]; work += quote.total_mwu
	assert_equal(wood, 6500, "complete first-prefix wood")
	assert_equal(work, 98000, "complete first-prefix work, not elapsed time")
	assert_equal(6 * Contract.EARTH_MILLI, 12000, "only six new CUT completions may create this earth")
	assert_equal(_world._inventory.item_mass_g(_world._items.compiled_id(&"excavated_earth")), 1000, "current adopted earth mass")


func test_initial_stock_is_finite_and_does_not_precreate_spoil_or_paid_progress() -> void:
	"""No initial dirt, Project, Room, worker credit or installed-prefix bit substitutes for the paid sequence."""
	assert_equal(_world._inventory.lot_quantity_milli(_wood), 6500, "explicit whole-prefix wood stock")
	assert_equal(_world._inventory.lot_quantity_milli(_stone), 1500, "explicit whole-prefix stone stock")
	assert_equal(_world._inventory.container_used_mass_g(_storage), 40000, "wood32,500g plusstone7,500g; equipped tool is separate")
	assert_equal(_world._inventory.container_max_mass_g(_storage), 400000, "finite actual ground policy")
	assert_equal(_world._inventory.container_max_mass_g(_output), 400000, "finite actual output policy")
	assert_equal(_world._inventory.container_first_lot(_output), NULL_REF, "no earth before actual cuts")
	assert_equal(_world._construction.live_project_count(), 0, "no fake paid phase")
	assert_equal(_world._buildings.live_room_count(), 0, "admission has not been bypassed")
	assert_equal(_world._jobs.job_count(), 0, "no Job without an actual order")
	assert_equal(_sites.virgin_sourced_milli(), 0, "actual conserved spoil ledger starts empty")
	assert_equal(_sites.remaining_history_capacity(), 8, "no retained key is seeded by the fixture")


func test_common_metadata_grants_no_support_over_any_future_paid_cube() -> void:
	"""Every root has separately proved natural footing, while the broad common floor is metadata only."""
	var actual: Owner.Region = Owner.Region.new()
	actual.box.resize(6)
	assert_equal(_world._owner.region_into_reused(_section, actual), &"", "actual common section")
	assert_equal(actual.role, Space.FLOOR_DATUM, "metadata only")
	for ordinal: int in 6:
		var cube: PackedInt32Array = Source.world_box(Source.cube(ordinal))
		var handles: PackedInt32Array = PackedInt32Array()
		assert_equal(_world._owner.overlapping_regions_into(cube, handles), &"", "actual complete retained census")
		for index: int in range(0, handles.size(), 2):
			assert_equal(_world._owner.region_into_reused(Vector2i(handles[index], handles[index + 1]), actual), &"", "actual full retained handle")
			assert_equal(actual.role, Space.FLOOR_DATUM, "future pockets contain no borrowed support, air or paid cavity")


func test_actual_surface_paths_connect_each_selected_contact_without_entering_cut_pockets() -> void:
	"""Every approach/retreat is explicitly authored and independently certified from live natural body and stance union."""
	assert_equal(_world._routes._live.edge_count, 16, "eight explicit bidirectional spans")
	var remaining: PackedInt32Array = PackedInt32Array([0])
	for endpoint: Vector2i in _endpoints:
		assert_equal(WorldRoutes.profile_reachability_refusal(_world._binding, _endpoints[1], endpoint,
			0, 1, 2, Space.MAX_CHECKS, remaining), &"", "actual storage to selected contact")
		assert_equal(WorldRoutes.profile_reachability_refusal(_world._binding, endpoint, _endpoints[2],
			0, 1, 2, Space.MAX_CHECKS, remaining), &"", "actual selected contact to output/retreat")
	assert_equal(_world._buildings.live_room_count(), 0, "all paths precede any paid entrance")


func test_fine_entry_request_keeps_tail_outside_claims_and_derives_all_six_paid_keys() -> void:
	"""Half-cube usable geometry does not discount whole-cube cuts or silently enlarge the confirmed claim."""
	var plan: EntryPlan.Request = _entry_plan()
	assert_equal(EntryPlan.shape_refusal(plan), &"", "exact fine input is well formed")
	assert_equal(plan.claims[8], ORIGIN.z - 2560, "T0 starts at its exact painted edge")
	var lease: int = _world._budget.acquire(Budget.COLD_BYTES)
	var cursor: EntryCuts = EntryCuts.new()
	assert_equal(cursor.configure(plan.claims, _world._owner.domain_copy(), Space.MAX_CHECKS, 64), &"", "actual streamed whole-key union")
	var observed: Array[Vector3i] = []
	while cursor.advance(): observed.append(cursor.current_origin())
	assert_equal(cursor.refusal(), &"", "complete finite enumeration")
	assert_equal(observed.size(), 6, "six distinct whole paid cubes")
	for ordinal: int in 6:
		var cube: PackedInt32Array = Source.world_box(Source.cube(ordinal))
		assert_true(observed.has(Vector3i(cube[0], cube[1], cube[2])), "source key %d covered once" % ordinal)
	cursor.clear()
	assert_equal(_world._budget.release(lease), &"", "cursor scratch released")
	assert_equal(_sites.remaining_history_capacity(), 8, "enumeration creates no Site or paid state")
