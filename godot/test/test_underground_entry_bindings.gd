extends "res://test/framework/test_case.gd"
## Real World/Terrain/Room/Sites/Placement admission. Motion flags and connector parts remain synthetic source fixtures.

const Binding := preload("res://scripts/core/underground_entry_bindings.gd")
const EntryTests := preload("res://test/test_underground_entry_placements.gd")
const WorldTests := preload("res://test/test_underground_world_routes.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const ProfileTests := preload("res://test/test_underground_entry_frontier.gd")
const CatalogTests := preload("res://test/test_underground_connector_catalog.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const PhysicalTests := preload("res://test/test_excavation_physical.gd")
const PaidFixture := preload("res://test/test_underground_connector_work.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Anchor := preload("res://scripts/core/underground_surface_anchor.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const PATH: String = "user://entry-binding-source.bin"

class ObservedFrontier extends Frontier:
	## Adversarial binding callback only; genuine source identity/validation still decides the return value.
	var probe: Callable = Callable()
	var gate: Callable = Callable()
	var probe_count: int = 0

	func binding_matches(catalog: Catalog, assemblies: Assemblies, recipes: Recipes, profiles: Profiles) -> bool:
		"""Inject one observer after the actual full source proof, optionally delayed to a specific operation boundary."""
		var valid: bool = super.binding_matches(catalog, assemblies, recipes, profiles)
		if probe.is_valid() and (not gate.is_valid() or gate.call()):
			var selected: Callable = probe
			probe = Callable()
			probe_count += 1
			selected.call()
		return valid


class ObservedBinding extends Binding:
	## Negative-only observer around the complete actual Terrain operation; it supplies no permission.
	var probe: Callable = Callable()
	var after_prepared: bool = false
	var probe_count: int = 0
	var preflight_count: int = 0
	var final_physical_read: bool = false
	var timber_final_probe: Callable = Callable()
	var datum_support_checks: int = 0
	var staged_contact_checks: int = 0

	func _timber_staged_support(proof: TimberClearance, bounds: PackedInt32Array) -> StringName:
		"""Count real complete LANDING support proofs without replacing any physical decision."""
		datum_support_checks += 1
		return super._timber_staged_support(proof, bounds)

	func _timber_air_box(proof: TimberClearance, token: int, staging: bool) -> StringName:
		"""Every distinct endpoint still passes its own exact physical air proof."""
		if staging: staged_contact_checks += 1
		return super._timber_air_box(proof, token, staging)

	func _preflight_entry() -> StringName:
		"""Count actual entrance preflights; failed original-lease proof must stop before any private cursor."""
		preflight_count += 1
		return super._preflight_entry()

	func _entry_physical_refusal(space_token: int) -> StringName:
		"""Expose the end of the actual final local-facts pass to a negative observer, granting no permission."""
		var code: StringName = super._entry_physical_refusal(space_token)
		if space_token > 0: final_physical_read = true
		return code

	func _entry_terrain_box(bounds: PackedInt32Array, purpose: int, space_token: int) -> StringName:
		"""Run a one-shot adversarial observer after actual Terrain has completed its read."""
		var code: StringName = super._entry_terrain_box(bounds, purpose, space_token)
		if probe.is_valid() and (not after_prepared or space_token > 0):
			var selected: Callable = probe
			probe = Callable()
			probe_count += 1
			selected.call()
		return code

	func _timber_final(placement: Vector2i, project: Vector2i, assembly: int, cold: int) -> StringName:
		"""A negative observer after complete physical proof must still precede the final pure installed witness."""
		var code: StringName = super._timber_final(placement, project, assembly, cold)
		if code == &"" and timber_final_probe.is_valid():
			var selected: Callable = timber_final_probe
			timber_final_probe = Callable()
			selected.call()
		return code


class WatchedLocations extends WorldTests.RefusingLocations:
	## Count actual installed proofs without supplying a result or modifying authoritative state.
	var watch_witness: bool = false
	var pre_swap_witnesses: int = 0
	var post_swap_witnesses: int = 0
	var prepared_probe: Callable = Callable()

	func prepared_refusal(token: int) -> StringName:
		"""A negative callback at the final ordinary observation may replace the actual immutable profile bank."""
		var code: StringName = super.prepared_refusal(token)
		if code == &"" and prepared_probe.is_valid():
			var selected: Callable = prepared_probe
			prepared_probe = Callable()
			selected.call()
		return code

	func _installed_witnesses_refusal() -> StringName:
		"""The new witness must finish before Space swaps, never restart against its old inactive bank."""
		if watch_witness and _owner_token > 0:
			if _owner._stage_token == _owner_token: pre_swap_witnesses += 1
			else: post_swap_witnesses += 1
		return super._installed_witnesses_refusal()


class ActualFixture extends EntryTests.Fixture:
	var extra_floor: Vector2i = NULL_REF
	var geometry_mode: int = 0

	func _actual_space(obstruction: int) -> void:
		"""Replace only the endpoint observation spy before the actual Routes/Inventory bindings are created."""
		super._actual_space(obstruction)
		_locations = WatchedLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, 8, 228 * 8 + 256), &"", "actual witnessed endpoint store")

	func _fixture_void(token: int, obstruction: int) -> void:
		"""A second independently valid surface section exists before any endpoint proof is made."""
		super._fixture_void(token, obstruction)
		extra_floor = _region(token, PackedInt32Array([X + 1024, 512, Z,
			X + 2048, 513, Z + 2048]), Space.FLOOR_DATUM)

	func _actual_profiles() -> void:
		"""Reuse the reviewed independent source generator, with this actual World's resident identity."""
		super._actual_profiles()
		var generator: ProfileTests = ProfileTests.new()
		generator._fixture = GroupTests.new()
		generator._fixture._fixture = GroupTests.IsolatedFixture.new()
		generator._fixture._fixture._identity.resize(3)
		assert_true(_residents.spatial_profile_identity_into(_worker, generator._fixture._fixture._identity), "actual worker identity")
		var bytes: PackedByteArray = generator._work_profiles()
		assert_equal(_profiles.load_file(PROFILE_TEMP, _write(PROFILE_TEMP, bytes), 2), &"", "four source WORK headings")

	func _load_catalog(revision: int) -> StringName:
		"""One actual finite four-part variant pins the new profile content revision before route binding."""
		var bytes: PackedByteArray = TimberContent.image(revision, geometry_mode)
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func _location(point: Vector3i) -> Vector2i:
		"""Publish actual World WORK and STORAGE contacts, with complete real endpoint support proofs."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point
		row.section = _floor
		row.level = 0
		row.role = Locations.ROLE_WORK if point.x == X + 512 else Locations.ROLE_STORAGE
		row.envelope = PackedInt32Array([point.x - 256, point.y, point.z - 256, point.x + 256, point.y + 1024, point.z + 256])
		row.support = PackedInt32Array([point.x - 256, point.y - 128, point.z - 256, point.x + 256, point.y, point.z + 256])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = _locations.begin_prepare(cold).token
		var added: Locations.Result = _locations.stage_add(token, row)
		assert_equal(added.error, &"", "actual complete endpoint")
		assert_equal(_locations.seal(token), &"", "actual endpoint seal")
		assert_true(_locations.publish(token), "actual endpoint publication")
		assert_equal(_budget.release(cold), &"", "original endpoint lease released")
		return added.location

class TimberPhysical extends EntryTests.PhysicalBinding:
	## Synthetic contact/phase-companion only. Sites, receipts, WU, materials and final timber geometry are real.
	func room_refusal(room: Vector2i) -> StringName:
		"""Use the real full Room identity; only physical work reach is a synthetic component fixture."""
		return &"" if space._sources._buildings.is_live_room(room) else super.room_refusal(room)

	func final_start_leaf_refusal(_origin: Vector3i, _operation: int, room: Vector2i) -> StringName:
		"""Retain the explicit synthetic START scope with this fixture's actual full Room generation."""
		if start_leaf_block != &"": return start_leaf_block
		if pending_stage != Contract.STAGE_START or not space._sources._buildings.is_live_room(room):
			return &"SYNTHETIC_START_STALE"
		if block_operation != &"": return block_operation
		return block_worker if block_worker != &"" else block_output

	func final_settlement_leaf_refusal(_origin: Vector3i, _operation: int,
			stage: int, room: Vector2i) -> StringName:
		"""No worker is needed for a synthetic terminal proof; its actual Room and prepared stage remain exact."""
		if pending_stage != stage or not space._sources._buildings.is_live_room(room):
			return &"SYNTHETIC_SETTLEMENT_STALE"
		return block_operation


class TimberContent extends RefCounted:
	static func image(revision: int, mode: int = 0) -> PackedByteArray:
		"""Two complete rectangular fixture groups: each includes a deck and its sole connected bearing post."""
		var bytes: PackedByteArray = GroupTests._catalog_wire(14 if mode == 3 else 4, revision)
		bytes.encode_s64(48, 2)
		bytes.encode_s32(136 + 3 * 4, 512)
		bytes.encode_s32(136 + 5 * 4, -512)
		bytes.encode_s32(136 + 112, 512)
		bytes.encode_s32(136 + 112 + 8, -512)
		var regions: int = 136 + 112 + 32
		bytes.encode_s32(regions + 4, -2048)
		var landing: PackedInt32Array = PackedInt32Array([0, 0, -1024, 1024, 1024, 0, Space.LANDING, 0])
		for field: int in 8: bytes.encode_s32(regions + 32 + 4 * field, landing[field])
		var parts: int = regions + 192
		var vertices: int = parts + 4 * 36
		for part: int in 4:
			var post: bool = part % 2 == 1
			bytes.encode_s32(parts + part * 36, 3 if post else 0)
			bytes.encode_s32(parts + part * 36 + 4, 896 if post else 128)
			var lo: Vector3i = Vector3i(384, -128, -768) if post else Vector3i(0, 0, -1024)
			var hi: Vector3i = Vector3i(640, -128, -256) if post else Vector3i(1024, 0, 0)
			for index: int in 4:
				var point: Vector3i = Vector3i(hi.x if index in [1, 2] else lo.x, lo.y, hi.z if index >= 2 else lo.z)
				for axis: int in 3: bytes.encode_s32(vertices + part * 48 + index * 12 + axis * 4, point[axis])
		if mode == 1: bytes.encode_s32(vertices + 12, 900) # Real skewed quad, not its rectangle envelope.
		if mode == 2: bytes.encode_s32(parts + 36 + 4, 768) # Post misses actual ground by128u.
		if mode == 3: return _l0_image(revision)
		if mode == 4: _lower_deck(bytes, regions, parts, vertices)
		if mode == 5: _fractional_deck(bytes, regions, parts, vertices)
		return bytes

	static func _l0_boxes() -> Array[PackedInt32Array]:
		"""Exact accepted1113 L0 prisms; the second fixture group repeats them and is never installed here."""
		return [PackedInt32Array([-1024, -64, -2048, 1024, 0, 0]),
			PackedInt32Array([-896, -192, -2048, -768, -64, 0]), PackedInt32Array([768, -192, -2048, 896, -64, 0]),
			PackedInt32Array([-896, -1024, -256, -768, -192, -128]), PackedInt32Array([-896, -1024, -1920, -768, -192, -1792]),
			PackedInt32Array([768, -1024, -256, 896, -192, -128]), PackedInt32Array([768, -1024, -1920, 896, -192, -1792])]

	static func _l0_image(revision: int) -> PackedByteArray:
		"""Bind the real seven-prism geometry to a test-only Catalog, retaining explicit synthetic profile flags."""
		var bytes: PackedByteArray = GroupTests._catalog_wire(14, revision)
		bytes.encode_s64(48, 2)
		bytes.encode_s32(136 + 3 * 4, 512); bytes.encode_s32(136 + 5 * 4, -512)
		bytes.encode_s32(248, 512); bytes.encode_s32(256, -512)
		bytes.encode_s32(280 + 4, -2048)
		var landing: PackedInt32Array = PackedInt32Array([-1024, 0, -2048, 1024, 1, 0, Space.LANDING, 0])
		for field: int in 8: bytes.encode_s32(312 + 4 * field, landing[field])
		var boxes: Array[PackedInt32Array] = _l0_boxes()
		for part: int in 14:
			var box: PackedInt32Array = boxes[part % 7]
			bytes.encode_s32(472 + part * 36, 3 if part % 7 >= 3 else 0)
			bytes.encode_s32(476 + part * 36, box[4] - box[1])
			for index: int in 4:
				var point: Vector3i = Vector3i(box[3] if index in [1, 2] else box[0], box[4], box[5] if index >= 2 else box[2])
				for axis: int in 3: bytes.encode_s32(976 + part * 48 + index * 12 + axis * 4, point[axis])
		return bytes

	static func _lower_deck(bytes: PackedByteArray, regions: int, parts: int, vertices: int) -> void:
		"""Put the actual deck below tree roots while its contact air remains inside separately paid complete void."""
		bytes.encode_s32(regions + 4, -3072)
		bytes.encode_s32(regions + 32 + 4, -1024)
		bytes.encode_s32(regions + 32 + 16, 1024)
		for part: int in 4:
			for index: int in 4:
				var at: int = vertices + part * 48 + index * 12 + 4
				bytes.encode_s32(at, bytes.decode_s32(at) - 1024)
		assert(bytes.decode_s32(parts + 4) == 128)

	static func _fractional_deck(bytes: PackedByteArray, regions: int, parts: int, vertices: int) -> void:
		"""A real 128u-lower deck has its root inside the already completed cube, not on that cube's floor."""
		bytes.encode_s32(regions + 32 + 4, -128)
		for part: int in 4:
			if part % 2 == 1: bytes.encode_s32(parts + part * 36 + 4, 768)
			for index: int in 4:
				var at: int = vertices + part * 48 + index * 12 + 4
				bytes.encode_s32(at, bytes.decode_s32(at) - 128)


class ObservedRetention extends Routes.EndpointRetention:
	## Same actual graph retention, with a negative-only callback after a chosen changed-row observation.
	var probe: Callable = Callable()
	var calls: int = 0
	var trigger: int = 1

	func retains(location: Vector2i) -> bool:
		"""An observer that does not retain the retired endpoint may still invalidate a different installed witness."""
		var result: bool = super.retains(location)
		calls += 1
		if calls == trigger and probe.is_valid():
			var selected: Callable = probe
			probe = Callable()
			selected.call()
		return result


var _f: ActualFixture = null
var _group: GroupTests = null
var _source: ObservedFrontier = null
var _placements: Placements = null
var _physical: EntryTests.PhysicalBinding = null
var _sites: Sites = null
var _router: Router = null
var _orders: Orders = null
var _provider: WorldBindings = null
var _bindings: ObservedBinding = null
var _replacement_token: int = 0
var _catalog_mode: int = 0
var _extra_transit_points: Array[Vector3i] = []


func before_each() -> void:
	"""Every admission and conserved store is real; no prospective geometric permission callback is supplied."""
	_f = ActualFixture.new()
	_f.geometry_mode = _catalog_mode
	_f._actual_fixture()
	_f._publish_route()
	_group = GroupTests.new()
	_group._catalog = _f._catalog
	_group._items = _f._items
	_group._inventory = _f._inventory
	var parts: int = 7 if _catalog_mode == 3 else 2
	_group._bind_source(_group._group_wire(2, parts), PackedInt32Array([0, parts]))
	assert_equal(_group._load_source(), &"", "real grouping and recipes")
	_bind_frontier()
	_placements = Placements.new()
	assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "actual Placement capacity")
	assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
		_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "actual Placement owners")
	_bind_orders()
	assert_true(_f.failures.is_empty(), "actual World fixture %s" % _f.failures)
	assert_true(_group.failures.is_empty(), "actual immutable fixture %s" % _group.failures)


func _bind_frontier() -> void:
	"""Load the genuine streamed reader with an independently serialized finite source and exact digest."""
	var caps: PackedInt32Array = PackedInt32Array([2, 1, 1, 5 if _catalog_mode == 3 else 1, 3 + _extra_transit_points.size(), 1])
	_source = ObservedFrontier.new()
	assert_equal(_source.configure(caps, Frontier.required_bytes(caps)), &"", "source storage admitted")
	assert_equal(_source.bind_actual(_f._catalog, _group._reader, _group._recipes, _f._profiles), &"", "same source objects")
	var bytes: PackedByteArray = _source_image()
	assert_equal(_source.load_file(PATH, _f._write(PATH, bytes), 23), &"", "source semantic validation")


func _source_image() -> PackedByteArray:
	"""A virgin cube in front of the surface approach has all phases and a disjoint retained bearing."""
	var bytes: PackedByteArray = "UGFRNT01".to_ascii_buffer()
	bytes.resize(Frontier.WIRE_HEADER_BYTES)
	bytes.encode_u32(8, 1)
	var revisions: PackedInt64Array = PackedInt64Array([23, 1, 1, GroupTests.GROUP_REVISION, GroupTests.RECIPE_REVISION, 2])
	for index: int in 6: bytes.encode_s64(12 + 8 * index, revisions[index])
	var counts: PackedInt32Array = PackedInt32Array([2, 1, 1, 5 if _catalog_mode == 3 else 1, 3 + _extra_transit_points.size(), 1])
	for table: int in 6: bytes.encode_u32(68 + 4 * table, counts[table])
	_source_hashes(bytes)
	for ordinal: int in 2:
		CatalogTests._append_row(bytes, PackedInt32Array([ordinal, 0, 0, 0, 1, 1 if _catalog_mode == 3 else 0,
			4 if _catalog_mode == 3 else 1, 1, 0]))
	CatalogTests._append_row(bytes, PackedInt32Array([0, 512, 0, 512, 0, 1, 0, 4, Jobs.JOB_KIND_BUILD]), 1)
	for rotation: int in range(1, 4): CatalogTests._append_row(bytes, PackedInt32Array([rotation + 1]), 1)
	var cut: PackedInt32Array = _local_cut()
	cut.append(Sites.SUPPORTED_VOID)
	CatalogTests._append_row(bytes, cut)
	_append_timber_bearings(bytes)
	_append_timber_endpoints(bytes)
	var episode: PackedInt32Array = _local_cut()
	episode.append_array(PackedInt32Array([7, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 4]))
	CatalogTests._append_row(bytes, episode)
	bytes.append_array("UGFEND01".to_ascii_buffer())
	return bytes


func _append_timber_endpoints(bytes: PackedByteArray) -> void:
	"""Additional test-authored transit selectors keep their exact points and share only immutable LANDING metadata."""
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.SURFACE_ANCHOR, -1, 0, Locations.ROLE_WORK, 512, 0, 512, 0]), 1)
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.SURFACE_CONTACT, -1, 0, Locations.ROLE_STORAGE, 1536, 0, 512, 0]), 1)
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.INSTALLED_CONTACT, 0, 1, Locations.ROLE_TRANSIT,
		512, -1024 if _catalog_mode == 4 else (-128 if _catalog_mode == 5 else 0), -512, 0]), 1)
	for point: Vector3i in _extra_transit_points:
		CatalogTests._append_row(bytes, PackedInt32Array([Frontier.INSTALLED_CONTACT, 0, 1,
			Locations.ROLE_TRANSIT, point.x, point.y, point.z, 0]), 1)


func _local_cut() -> PackedInt32Array:
	"""The exact L0 four-cube pocket and the deep two-cube exclusion witness are paid in full, once each."""
	if _catalog_mode == 3: return PackedInt32Array([-1024, -1024, -2048, 1024, 0, 0])
	return PackedInt32Array([0, -2048 if _catalog_mode == 4 else -1024, -1024, 1024, 0, 0])


func _append_timber_bearings(bytes: PackedByteArray) -> void:
	"""The exact1113 fastening face is separate from all four true post bases; no source row implies another role."""
	if _catalog_mode != 3:
		var low: int = -2176 if _catalog_mode == 4 else -1152
		CatalogTests._append_row(bytes, PackedInt32Array([Frontier.NATURAL, -1, -1, 384, low, -768, 640, low + 128, -256]))
		return
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.NATURAL, -1, -1, -1024, -128, 0, -512, 0, 128]))
	var boxes: Array[PackedInt32Array] = TimberContent._l0_boxes()
	for post: int in range(3, 7):
		var box: PackedInt32Array = boxes[post]
		CatalogTests._append_row(bytes, PackedInt32Array([Frontier.NATURAL, -1, -1, box[0], -1152, box[2], box[3], -1024, box[5]]))


func _source_hashes(bytes: PackedByteArray) -> void:
	"""Pin the actual Catalog/Grouping/Recipes and qualified-program fixture hashes, not file paths."""
	var hash_bytes: PackedByteArray = PackedByteArray()
	hash_bytes.resize(32)
	assert_true(_f._catalog.content_hash_into(1, hash_bytes), "Catalog digest")
	for index: int in 32: bytes[92 + index] = hash_bytes[index]
	var group_hash: PackedByteArray = _group._group_hash.hex_decode()
	var recipe_hash: PackedByteArray = _group._recipe_hash.hex_decode()
	for index: int in 32:
		bytes[124 + index] = group_hash[index]
		bytes[156 + index] = recipe_hash[index]
	assert_true(_f._profiles.source_hash_into(0, 2, hash_bytes), "profile program digest")
	for index: int in 32: bytes[188 + index] = hash_bytes[index]


func _bind_orders() -> void:
	"""Connect the real phase composer and Room authority to the new concrete admission provider."""
	_physical = TimberPhysical.new()
	_physical.space = _f._owner
	_physical.world = _f._world_ref
	_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "real Site ledger")
	assert_equal(_f._locations.bind_sites(_sites), &"", "actual paid Location scope")
	_router = Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
	_provider = WorldBindings.new()
	assert_equal(_provider.configure(_f._world, _f._terrain, _f._owner, _f._sources, _f._budget), &"", "actual composer")
	_bindings = ObservedBinding.new()
	assert_equal(_bindings.configure(_provider, _sites, _f._budget), &"", "actual Room phase provider")
	_orders = Orders.new()
	assert_equal(_orders.configure(_router, _f._owner, _f._sources, RoomCatalog.new(), _bindings), &"", "actual RoomOrders")
	assert_equal(_bindings.configure_room_admission(_orders, _f._levels), &"", "actual level/admission namespace")
	assert_equal(_f._locations.bind_room_orders(_orders), &"", "real endpoint Room companion")
	assert_equal(_bindings.bind_entry(_source, _placements), &"", "actual entrance source binding")


func after_each() -> void:
	"""Verify no cold scope escaped and release only test-owned files, observers and actual fixtures."""
	if _f != null: assert_true(_f._budget.is_quiescent(), "no original lease escaped")
	if _source != null:
		_source.probe = Callable()
		_source.gate = Callable()
	if _bindings != null:
		_bindings.probe = Callable()
		_bindings.timber_final_probe = Callable()
	_replacement_token = 0
	_catalog_mode = 0
	_extra_transit_points.clear()
	if _f != null:
		_f._sources.probe = Callable()
		_f._sources.when = Callable()
		(_f._locations as WatchedLocations).prepared_probe = Callable()
	_bindings = null
	_orders = null
	_provider = null
	_placements = null
	_source = null
	_router = null
	_sites = null
	_physical = null
	_group = null
	if _f != null:
		_f.after_each()
		assert_true(_f.failures.is_empty(), "fixture remained valid %s" % _f.failures)
	_f = null
	for path: String in [PATH, GroupTests.GROUP_PATH, GroupTests.RECIPE_PATH, GroupTests.CATALOG_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _plan() -> EntryPlan.Request:
	"""An exact source-cube plan touches no existing approach support and contains no free air."""
	var plan: EntryPlan.Request = EntryPlan.Request.new()
	plan.world = _f._world_ref
	plan.space_revision = _f._owner.revision()
	plan.base_level = 0
	plan.origin_u = Vector3i(WorldTests.X, 512, WorldTests.Z)
	plan.rotation = 0
	plan.anchor = _f._first
	plan.catalog_row = 0
	plan.catalog_revision = 1
	plan.variant_revision = 1
	plan.grouping_revision = GroupTests.GROUP_REVISION
	plan.recipe_revision = GroupTests.RECIPE_REVISION
	plan.frontier_revision = 23
	plan.source_digests.resize(128)
	for index: int in 96: plan.source_digests[index] = _source._digests[32 + index]
	for index: int in 32: plan.source_digests[96 + index] = _source._digests[index]
	plan.claims = _local_cut()
	for axis: int in 3:
		plan.claims[axis] += plan.origin_u[axis]
		plan.claims[axis + 3] += plan.origin_u[axis]
	plan.opening_targets = PackedInt32Array([-1, 0, -1, 0])
	return plan


func _image() -> Array:
	"""Only test code copies authoritative state to prove refusals preserve every identity, claim and account."""
	return [_f._residents.directory().state_bytes(), _sites.state_bytes(), _f._inventory.state_bytes(),
		_f._owner.state_bytes(), _f._locations._live.i32.duplicate(), _f._locations._live.i64.duplicate(),
		_f._routes._live.fields.duplicate(), _f._routes._live.longs.duplicate(), _placements._live.header.duplicate()]


func _refused(plan: EntryPlan.Request, why: String) -> StringName:
	"""A failed confirmation changes no authoritative bytes and gives back the exact original arena."""
	var before: Array = _image()
	var result: Buildings.OpResult = _orders.confirm_entry(plan)
	assert_false(result.ok, why)
	assert_true(_image() == before, "all owners unchanged: " + why)
	assert_true(_f._budget.is_quiescent(), "no retained lease: " + why)
	return result.error


func test_actual_entry_admission_reserves_exact_virgin_cube_and_old_circulation() -> void:
	"""Concrete terrain/source proof composes actual publication; it installs no part and advances no work."""
	var goods: PackedByteArray = _f._inventory.state_bytes()
	var old_revision: int = _f._owner.revision()
	var free_history: int = _sites.remaining_history_capacity()
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(result.ok, "real admission: %s" % result.error)
	assert_equal(_f._buildings.type_of_room(result.ref).value, Buildings.ROOM_TYPE_CORRIDOR, "permanent Corridor")
	assert_equal(_placements._live.header[Placements.H_COUNT], 1, "one actual placement")
	assert_equal(_sites.remaining_history_capacity(), free_history - 1, "one actual canonical paid key")
	assert_equal(_f._owner.revision(), old_revision + 1, "one metadata publication")
	assert_equal(_f._locations._live.count, 2, "no invented installed endpoint")
	assert_equal(_f._routes._live.edge_count, 1, "old route retained only")
	assert_equal(_f._inventory.state_bytes(), goods, "no material charge before construction")
	assert_equal(_sites.virgin_sourced_milli(), 0, "no excavation or spoil")


func test_source_change_wrong_anchor_and_extra_cube_refuse_unchanged() -> void:
	"""Exact loaded source, full WORK anchor and complete source cut set are independent mandatory gates."""
	var plan: EntryPlan.Request = _plan()
	plan.source_digests[127] ^= 1
	_refused(plan, "changed frontier digest")
	plan = _plan()
	plan.anchor = _f._last
	_refused(plan, "storage is not a WORK anchor")
	plan = _plan()
	plan.claims[3] += 1024
	_refused(plan, "extra cube missing from source")
	plan = _plan()
	plan.claims[0] += 1024
	plan.claims[3] += 1024
	_refused(plan, "same-count substituted cube cannot omit the authored source cut")


func test_fractional_claim_keeps_exact_shape_and_whole_paid_key() -> void:
	"""One exact half-width marker still pays its full cube and does not expand the usable footprint."""
	var plan: EntryPlan.Request = _plan()
	plan.claims[0] += 512
	var result: Buildings.OpResult = _orders.confirm_entry(plan)
	assert_true(result.ok, "fine claim admission: %s" % result.error)
	assert_equal(_sites._count, 1, "whole canonical key once")
	var markers: int = 0
	for row: int in _f._owner._region_capacity:
		if _f._owner._r_present[row] != 1 or _f._owner._r_claim_kind[row] != Owner.CLAIM_ROOM: continue
		markers += 1
		assert_equal(_f._owner._r_lo_x[row], plan.claims[0], "exact usable boundary preserved")
	assert_equal(markers, 1, "single fine marker")


func test_outside_claim_paid_remainder_is_physically_checked() -> void:
	"""A real obstacle in the removed half of a fine claim still blocks its whole paid excavation cube."""
	var token: int = _f._owner.begin_stage(_f._owner.revision()).token
	_f._region(token, PackedInt32Array([WorldTests.X + 100, -400, WorldTests.Z - 900,
		WorldTests.X + 200, -300, WorldTests.Z - 800]), Space.OBSTACLE)
	assert_equal(_f._owner.seal(token), &"", "real remainder obstacle")
	_f._owner.publish(token)
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var locations: int = _f._locations.begin_prepare(cold).token
	for endpoint: Vector2i in [_f._first, _f._last]:
		assert_equal(_f._locations.stage_refresh(locations, endpoint), &"", "unaffected approach refresh")
	assert_equal(_f._locations.seal(locations), &"", "approach sealed")
	assert_true(_f._locations.publish(locations), "approach current")
	assert_equal(_f._budget.release(cold), &"", "own lease")
	var plan: EntryPlan.Request = _plan()
	plan.claims[0] += 512
	assert_equal(_refused(plan, "obstacle outside fine claim"), Binding.REFUSE_CUT, "whole-cube obstacle gate")


func test_actual_retained_obstacle_and_natural_bearing_loss_refuse() -> void:
	"""An actual retained obstacle cannot be bypassed by otherwise valid source and dry original terrain."""
	var token: int = _f._owner.begin_stage(_f._owner.revision()).token
	var box: PackedInt32Array = PackedInt32Array([WorldTests.X + 100, -400, WorldTests.Z - 900,
		WorldTests.X + 200, -300, WorldTests.Z - 800])
	_f._region(token, box, Space.OBSTACLE)
	assert_equal(_f._owner.seal(token), &"", "actual obstruction sealed")
	_f._owner.publish(token)
	assert_false(_f._owner.has_prepared(), "actual obstruction committed")
	_refused(_plan(), "live retained obstacle and stale approach require requalification")


func test_unbound_cold_entry_cannot_borrow_foreign_lease() -> void:
	"""A separate unconfigured binding grants no entry and cannot release another consumer's arena."""
	var other: Binding = Binding.new()
	var token: int = _f._budget.acquire(Budget.COLD_BYTES)
	assert_true(other.begin_entry_cold(_plan()) != &"", "unbound actual composition refuses")
	other.end_entry_cold()
	assert_true(_f._budget.covers(token, Budget.COLD_BYTES), "foreign lease preserved")
	assert_equal(_f._budget.release(token), &"", "test owns lease release")


func test_surface_contact_must_exist_with_exact_role_and_current_full_proof() -> void:
	"""The authored material/output selector cannot silently resolve a missing, wrong-role or stale endpoint."""
	var locations: Locations = _f._locations
	locations._live.present[_f._last.x] = 0
	assert_equal(_refused(_plan(), "missing storage"), Binding.REFUSE_ENTRY_CONTACT, "actual contact gate")
	locations._live.present[_f._last.x] = 1
	var role_at: int = Locations.ROLE * locations._capacity + _f._last.x
	locations._live.i32[role_at] = Locations.ROLE_WORK
	assert_equal(_refused(_plan(), "wrong role"), Binding.REFUSE_ENTRY_CONTACT, "role is authoritative")
	locations._live.i32[role_at] = Locations.ROLE_STORAGE
	var revision_at: int = Locations.GEOMETRY_REVISION * locations._capacity + _f._last.x
	var revision: int = locations._live.i64[revision_at]
	locations._live.i64[revision_at] -= 1
	assert_equal(_refused(_plan(), "stale endpoint proof"), Binding.REFUSE_ENTRY_CONTACT, "revision is current")
	locations._live.i64[revision_at] = revision


func test_duplicate_actual_surface_contact_refuses_without_arbitrary_selection() -> void:
	"""Even two valid published endpoints at the source point cannot pick a material contact implicitly."""
	var duplicate: Vector2i = _f._location(Vector3i(WorldTests.X + 1536, 512, WorldTests.Z + 512))
	assert_true(duplicate != _f._last and duplicate != NULL_REF, "actual second full endpoint")
	assert_equal(_refused(_plan(), "ambiguous contact"), Binding.REFUSE_ENTRY_CONTACT, "no arbitrary winner")


func _nested_entry_cleanup() -> void:
	"""A callback attempts all cleanup/publication entries while the real request still owns the lease."""
	var original: int = _bindings.room_cold_token()
	assert_true(original > 0, "the observer is inside the actual leased operation")
	_bindings.end_entry_cold()
	_bindings.discard_entry_plan(NULL_REF, _bindings._entry_space_token)
	_bindings.publish_entry_plan(NULL_REF, _bindings._entry_space_token)
	assert_equal(_bindings.room_cold_token(), original, "nested cleanup cannot release the live request")


func test_nested_cleanup_during_actual_local_facts_poison_refuses_unchanged() -> void:
	"""Before preparation, an observer cannot null the live plan or create an unowned cold lease."""
	_bindings.probe = _nested_entry_cleanup
	_refused(_plan(), "nested local cleanup")
	assert_equal(_bindings.probe_count, 1, "actual local facts observer executed")


func test_nested_cleanup_after_actual_prepared_facts_aborts_every_companion() -> void:
	"""Final prepared Terrain observation cannot publish or discard a candidate owned by the outer Room order."""
	_bindings.probe = _nested_entry_cleanup
	_bindings.after_prepared = true
	_refused(_plan(), "nested final cleanup")
	assert_equal(_bindings.probe_count, 1, "actual prepared local facts observer executed")


func _replace_original_lease() -> void:
	"""An observer legitimately releases its witnessed token and acquires another consumer's replacement."""
	var original: int = _bindings.room_cold_token()
	assert_true(original > 0, "actual entrance lease exists")
	assert_equal(_f._budget.release(original), &"", "negative observer removes original lease")
	_replacement_token = _f._budget.acquire(Budget.COLD_BYTES)
	assert_true(_replacement_token > original, "replacement is a distinct real operation")


func _has_original_lease() -> bool:
	"""Delay the negative source observer until the actual entrance owns its arena."""
	return _bindings.room_cold_token() > 0


func test_source_observer_cannot_replace_lease_before_private_allocation() -> void:
	"""Post-observer pure guards reject before plan/cursor preparation and never release another operation's lease."""
	var before: Array = _image()
	_source.gate = _has_original_lease
	_source.probe = _replace_original_lease
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_false(result.ok, "replacement lease refuses")
	assert_equal(_source.probe_count, 1, "binding observer actually ran")
	assert_equal(_bindings.preflight_count, 0, "no preflight/cursor after original lease loss")
	assert_equal(_image(), before, "every authoritative owner unchanged")
	assert_true(_f._budget.covers(_replacement_token, Budget.COLD_BYTES), "foreign replacement survives cleanup")
	assert_equal(_f._budget.release(_replacement_token), &"", "test releases only its replacement")


func _after_final_facts() -> bool:
	"""An observer armed here could invalidate already-read local terrain without changing the Space revision."""
	return _bindings.final_physical_read


func _outside_entry_operation() -> bool:
	"""An unguarded public stage must not expose mutable private images to a cleanup callback."""
	return _bindings._entry_pin != null and not _bindings._entry_busy


func test_final_local_facts_have_no_later_binding_observer() -> void:
	"""Confirmation succeeds without invoking a source observer after the last actual prepared physical proof."""
	_source.gate = _after_final_facts
	_source.probe = _nested_entry_cleanup
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(result.ok, "all actual checks publish: %s" % result.error)
	assert_true(_bindings.final_physical_read, "complete final actual physical pass executed")
	assert_equal(_source.probe_count, 0, "no binding observer can stale the final local facts")


func test_public_entry_stage_guards_do_not_reenter_cleanup() -> void:
	"""All successful coordinator stages use pure scope guards while private candidate images are retained."""
	_source.gate = _outside_entry_operation
	_source.probe = _nested_entry_cleanup
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(result.ok, "actual Room/Site/Placement stages complete: %s" % result.error)
	assert_equal(_source.probe_count, 0, "no unguarded binding callback can discard the live image")


func test_valid_foreign_surface_section_cannot_supply_source_contact() -> void:
	"""A current real World floor containing the storage point is still outside the anchor's exact source namespace."""
	var locations: Locations = _f._locations
	var slot_at: int = Locations.SECTION_SLOT * locations._capacity + _f._last.x
	var generation_at: int = (Locations.SECTION_SLOT + 1) * locations._capacity + _f._last.x
	locations._live.i32[slot_at] = _f.extra_floor.x
	locations._live.i32[generation_at] = _f.extra_floor.y
	var point: Vector3i = Vector3i(WorldTests.X + 1536, 512, WorldTests.Z + 512)
	assert_equal(locations._resolve_section_refusal(NULL_REF, _f.extra_floor, 0, point), &"", "foreign floor is actual and valid")
	assert_equal(_refused(_plan(), "wrong full surface section"), Binding.REFUSE_ENTRY_CONTACT, "same-point foreign contact refuses")


func _seed_backfilled_history(origin: Vector3i) -> void:
	"""Negative fixture seeds existing paid history, not a claim that free material or actual excavation was performed."""
	var result: RefCounted = _sites.claim_quantum(origin, PhysicalTests.ROOM)
	assert_true(result.ok, "canonical key claimed through actual Sites")
	_sites._ever_cut[result.ref.x] = 1
	_sites._phase[result.ref.x] = Sites.BACKFILLED
	_sites._embedded_milli[result.ref.x] = Sites.EARTH_MILLI
	_sites._room_slot[result.ref.x] = -1
	_sites._room_generation[result.ref.x] = 0


func test_backfilled_source_bearing_is_not_original_natural_earth() -> void:
	"""Fresh Terrain and dry support labels cannot erase the immutable canonical paid-cut history."""
	_seed_backfilled_history(Vector3i(WorldTests.X, -1536, WorldTests.Z - 1024))
	assert_equal(_refused(_plan(), "paid source footing"), Binding.REFUSE_ENTRY_BEARING, "source bearing checks history")


func test_backfilled_anchor_footing_is_not_original_natural_earth() -> void:
	"""The actual exterior worker support receives the same immutable-history check as source load bearings."""
	_seed_backfilled_history(Vector3i(WorldTests.X, -512, WorldTests.Z))
	assert_equal(_refused(_plan(), "paid anchor footing"), Binding.REFUSE_ENTRY_BEARING, "anchor checks history")


func test_backfilled_storage_footing_is_not_original_natural_earth() -> void:
	"""A real storage endpoint cannot claim a natural-foundation exemption over earlier paid fill."""
	_seed_backfilled_history(Vector3i(WorldTests.X + 1024, -512, WorldTests.Z))
	assert_equal(_refused(_plan(), "paid storage footing"), Binding.REFUSE_ENTRY_BEARING, "storage checks history")


func _timber_paid_fixture() -> PaidFixture.Fixture:
	"""Actual paid accounting; source/contact flags and the separate excavation companion are explicit test fixtures."""
	var paid: PaidFixture.Fixture = PaidFixture.Fixture.new()
	paid._f = _f; paid._group = _group; paid._placements = _placements
	paid._router = _router; paid._sites = _sites
	paid.contacts = PaidFixture.SyntheticContacts.new()
	paid.contacts.placements = weakref(_placements)
	paid.contacts.router = weakref(_router)
	paid.contacts.world = _f._world_ref
	paid.paid_owner = ConnectorWork.new()
	assert_equal(paid.paid_owner.configure(_placements, _router, paid.contacts), &"", "actual installation accounting")
	return paid


func _timber_actor(paid: PaidFixture.Fixture) -> void:
	"""Initialize one genuine equipped worker; only component contact feasibility is synthetic."""
	var row: int = _f._residents.directory().get_typed_row(_f._worker)
	assert_true(_f._jobs.priorities().spawn(row).ok, "actual priorities")
	assert_true(_f._jobs.schedule().spawn(row, _f._jobs.schedule().default_template_id().value).ok, "actual schedule")
	assert_true(_f._jobs.schedule().resolve(row, 8, false).ok, "actual work hour")
	assert_true(_f._jobs.spawn_agent(row).ok, "actual agent")
	for need: int in PaidFixture.Needs.NEED_COUNT:
		var value: int = _f._residents.needs().need_of(row, need).value
		assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - value).ok, "actual mood")
	paid._store = _f._inventory.create_container(_f._world_ref, 100000, -1, 0, true).ref
	paid.tool_ref = paid._stock(&"tool", 1000)
	assert_true(_f._gear.create_gear(_f._inventory, _f._items, paid.tool_ref, PaidFixture.Gear.MANUFACTURE_BASIC).ok, "actual tool")
	assert_true(_f._gear.equip(paid.tool_ref, _f._worker).ok, "actual equipment")


func _timber_site_phase(paid: PaidFixture.Fixture, site: Vector2i, operation: int) -> void:
	"""Real BRACE/CUT/FINISH earn work and settle exact materials/earth; no Site state is seeded."""
	var opened: Construction.OpResult = _sites.open_phase(site, operation)
	assert_true(opened.ok, "real excavation order %s" % opened.error)
	if not opened.ok: return
	assert_true(_f._construction.remaining_mwu_into(opened.ref, paid.math), "actual requested work")
	var job: Jobs.OpResult = _f._jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, paid.math.value, 0)
	assert_true(_f._jobs.set_requester(job.value, opened.ref).ok, "actual requester")
	assert_true(_f._jobs.set_tool_gate(job.value, Jobs.GATE_SATISFIED).ok, "actual tool gate")
	assert_true(_sites.bind_job(site, job.ref).ok, "actual Site Job")
	assert_true(_sites.bind_material_container(site, paid._store).ok, "real stock")
	if operation == Contract.OP_CUT: assert_true(_sites.bind_output(site, paid._store).ok, "real finite earth output")
	var resident: int = _f._residents.directory().get_typed_row(_f._worker)
	assert_true(_f._jobs.assign_worker(resident, job.value).ok, "actual phase assignment")
	assert_true(_f._work.claim_tool_for_work(resident, paid.tool_ref).ok, "actual tool claim")
	_timber_phase_inputs(paid, site, job.ref, operation)
	assert_true(_sites.bind_worker(site).ok, "actual face worker")
	var start: Construction.OpResult = _sites.begin_phase_work(site, 100)
	assert_true(start.ok, "actual phase start %s" % start.error)
	if not start.ok: return
	paid.finish_work(opened.ref, job.ref)
	var settled: Construction.OpResult = _sites.settle_phase(site)
	assert_true(settled.ok, "actual phase settlement %s" % settled.error)
	assert_equal(_sites.earth_conservation_refusal(), &"", "actual earth conservation")
	assert_equal(_sites.support_conservation_refusal(), &"", "actual installed brace accounting")


func _timber_phase_inputs(paid: PaidFixture.Fixture, site: Vector2i, job: Vector2i, operation: int) -> void:
	"""Exact adopted excavation inputs use real Inventory claims; the fixture creates only initial stock."""
	for line: int in Contract.input_count(operation):
		var quantity: int = Contract.input_milli(operation, line)
		var lot: Vector2i = paid._stock(Contract.input_key(operation, line), quantity)
		assert_true(_f._pool.claim_batch(job, PackedInt64Array([lot.x, lot.y,
			Reservations.PURPOSE_EXCAVATION_INPUT, quantity, 1000]), 1, _f._inventory).ok, "actual phase claim")
	if Contract.input_count(operation) > 0:
		assert_true(_sites.record_deliveries(site).ok, "actual phase deliveries")


func _timber_fixture_void(room: Vector2i) -> void:
	"""Explicit test-only phase companion: real completed cavity and existing source-refresh algorithm, no Site edits."""
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var token: int = _f._owner.begin_stage(_f._owner.revision()).token
	var region: Owner.Region = Owner.Region.new()
	region.owner = room
	region.role = Space.SUPPORTED_VOID
	region.level = 0
	region.section = _placements._pair(_placements._live, Placements.SECTION_SLOT, 0)
	region.box = _plan().claims
	assert_equal(_f._owner.stage_add(token, region).error, &"", "actual paid cavity")
	assert_equal(_f._owner.seal(token), &"", "real cavity sealed")
	_placements._copy_bank(_placements._live, _placements._stage)
	assert_equal(_placements._update_staged_source_pins(), &"", "existing full old-source proof and refresh")
	_f._owner.publish(token)
	var saved: Placements.Bank = _placements._live
	_placements._live = _placements._stage; _placements._stage = saved
	var locations: int = _f._locations.begin_prepare(cold).token
	assert_equal(_f._locations.stage_refresh(locations, _f._first), &"", "old real work endpoint")
	assert_equal(_f._locations.stage_refresh(locations, _f._last), &"", "old real stock endpoint")
	assert_equal(_f._locations.seal(locations), &"", "old endpoints requalified")
	assert_true(_f._locations.publish(locations), "actual endpoints published")
	var routes: int = _f._binding.begin_prepare(cold).token
	assert_equal(_f._routes.stage_refresh(routes, Vector2i(0, _f._routes._live.fields[0])), &"", "old route")
	assert_equal(_f._binding.seal(routes), &"", "actual route certificate")
	assert_equal(_f._binding.publish(routes), &"", "actual route publication")
	assert_equal(_f._budget.release(cold), &"", "phase fixture drops original scratch")


func _ready_timber(paid: PaidFixture.Fixture) -> Vector2i:
	"""The concrete entry is confirmed before real physical phases and a genuine paid installation order."""
	var admitted: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(admitted.ok, "real permanent entry %s" % admitted.error)
	if not admitted.ok: return NULL_REF
	_timber_actor(paid)
	for row: int in _sites._count:
		var site: Vector2i = Vector2i(row, Sites.SITE_GENERATION)
		for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
			_timber_site_phase(paid, site, operation)
	if not failures.is_empty() or not paid.failures.is_empty(): return NULL_REF
	_timber_fixture_void(admitted.ref)
	var placement: Vector2i = Vector2i(0, _placements._live.i32[0])
	var project: Vector2i = paid._open_registered(placement)
	var job: Vector2i = paid.reuse_worker(project)
	paid._pay_and_work(project, job)
	return project


func test_actual_paid_prism_group_publishes_supported_contact_and_exact_residual() -> void:
	"""Actual installation publishes both included solids and one contact, keeping paid cavity volume disjoint."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	assert_equal(paid.failures.size(), 0, "real accounting setup: %s" % paid.failures)
	if project == NULL_REF or not failures.is_empty(): return
	var before_edges: int = _f._routes._live.edge_count
	var completed: Construction.OpResult = _router.complete_order(project)
	assert_true(completed.ok, "actual paid group publication: %s" % completed.error)
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 1, "one group once")
	assert_equal(_f._locations._live.count, 3, "one exact real installed contact")
	assert_equal(_f._routes._live.edge_count, before_edges, "no stair permission or new path")
	_timber_conservation()
	assert_equal(_sites.virgin_sourced_milli(), Sites.EARTH_MILLI, "earth emitted once")
	assert_true(_f._inventory.audit().ok, "real stock audit")
	assert_true(_f._pool.audit(_f._inventory).ok, "real reservation audit")


func _timber_conservation() -> void:
	"""Independent integer volume/overlap checks distinguish real solids from metadata and cavity residuals."""
	var room: Vector2i = _placements._pair(_placements._live, Placements.ROOM_SLOT, 0)
	var volume: int = 0
	var timber: int = 0
	for row: int in _f._owner._region_capacity:
		if _f._owner._r_present[row] != 1 or _f._owner._r_claim_kind[row] != Owner.CLAIM_NONE \
				or Vector2i(_f._owner._r_owner_slot[row], _f._owner._r_owner_generation[row]) != room: continue
		var role: int = _f._owner._r_role[row]
		if role != Space.SUPPORT and role != Space.SUPPORTED_VOID: continue
		var units: int = (int(_f._owner._r_hi_x[row]) - _f._owner._r_lo_x[row]) \
			* (int(_f._owner._r_hi_y[row]) - _f._owner._r_lo_y[row]) * (int(_f._owner._r_hi_z[row]) - _f._owner._r_lo_z[row])
		volume += units
		if role == Space.SUPPORT: timber += units
	assert_equal(timber, 1024 * 1024 * 128 + 256 * 512 * 896, "complete deck and bearer once")
	assert_equal(volume, 1024 * 1024 * 1024, "solid plus retained cavity exactly conserved")


func test_shared_landing_stages_support_once_but_proves_every_contact() -> void:
	"""Several real endpoints share one physical deck while retaining independent profile/air/Location admission."""
	after_each()
	_extra_transit_points = [Vector3i(256, 0, -512), Vector3i(768, 0, -512), Vector3i(512, 0, -256)]
	before_each()
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	assert_true(paid.failures.is_empty(), "real paid phase and work setup")
	if project == NULL_REF or not failures.is_empty(): return
	var result: Construction.OpResult = _router.complete_order(project)
	assert_true(result.ok, "all distinct actual contacts publish: %s" % result.error)
	assert_equal(_bindings.datum_support_checks, 1, "one exact assembly/LANDING support union")
	assert_equal(_bindings.staged_contact_checks, 4, "every complete endpoint envelope checked separately")
	assert_equal(_f._locations._live.count, 6, "two original and four installed full endpoints")
	_timber_conservation()


func test_shared_landing_does_not_authorize_an_unsupported_later_contact() -> void:
	"""A later point near the deck boundary cannot inherit the first endpoint's valid physical envelope."""
	after_each()
	_extra_transit_points = [Vector3i(1, 0, -512)]
	before_each()
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	assert_true(paid.failures.is_empty(), "real paid phase and work setup")
	if project == NULL_REF or not failures.is_empty(): return
	var before: Array = _image()
	var funding: PackedByteArray = _router._funding.state_bytes()
	assert_false(_router.complete_order(project).ok, "full later endpoint cannot fit actual support")
	assert_equal(_image(), before, "no partial physical or endpoint publication")
	assert_equal(_router._funding.state_bytes(), funding, "all paid receipts retained for retry")


func test_datum_and_profile_budget_exhaustion_stays_distinct_from_physical_refusal() -> void:
	"""An exhausted finite proof is reported as capacity, without pretending a physical contact was disproved."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	_bindings._entry_checks = 0
	_bindings._entry_contact.role = Locations.ROLE_WORK
	assert_equal(_bindings._timber_profile_envelope(2), Binding.REFUSE_MASK_BUDGET, "profile scan exhausted")
	var proof: Binding.TimberClearance = Binding.TimberClearance.new()
	proof.remaining = 0
	assert_equal(_bindings._timber_profile_foot(proof, 2), Binding.REFUSE_MASK_BUDGET, "same foot scan exhaustion")
	assert_equal(_bindings._timber_create_datum(proof, 0), Binding.REFUSE_MASK_BUDGET, "datum lookup exhausted")
	assert_equal(_bindings._timber_prior_landing(proof, 2), -1, "prior selector scan spends finite work")


func test_nonrectangular_and_floating_source_groups_refuse_before_settlement() -> void:
	"""A genuine decoded skew or missing bearing is not replaced with a convenient bounding prism."""
	for mode: int in [1, 2]:
		after_each()
		_catalog_mode = mode
		before_each()
		var paid: PaidFixture.Fixture = _timber_paid_fixture()
		var project: Vector2i = _ready_timber(paid)
		assert_equal(paid.failures.size(), 0, "real ready accounting")
		if project == NULL_REF or not failures.is_empty(): return
		var state: Array = _image()
		var funding: PackedByteArray = _router._funding.state_bytes()
		var result: Construction.OpResult = _router.complete_order(project)
		assert_false(result.ok, "unsupported actual source geometry")
		assert_true(_image() == state, "refusal preserves all physical/source stores")
		assert_true(_router._funding.state_bytes() == funding, "WIP not settled")
		assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 0, "no partial group")


func test_missing_finished_dependency_refuses_then_retries_same_paid_work() -> void:
	"""The finite dependency's exact current phase remains mandatory after a real installation reaches WORK_DONE."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	var site: Vector2i = _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))
	_sites._phase[site.x] = Sites.OPEN_UNFINISHED # Negative corruption witness only; setup used real paid FINISH.
	var state: Array = _image()
	var funding: PackedByteArray = _router._funding.state_bytes()
	assert_equal(_router.complete_order(project).error, Binding.REFUSE_TIMBER_CUT, "exact stable dependency required")
	assert_true(_image() == state and _router._funding.state_bytes() == funding, "all prepayment facts preserved")
	_sites._phase[site.x] = Sites.SUPPORTED_VOID
	assert_true(_router.complete_order(project).ok, "same paid work succeeds after true dependency restored")


func test_original_lease_replaced_in_preflight_preserves_new_scope_and_payment() -> void:
	"""The new live preflight runs before candidate mutation and never releases another consumer's replacement token."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	_source.probe = func() -> void:
		assert_equal(_f._budget.release(paid.paid_owner._cold_token), &"", "actual original token released")
		_replacement_token = _f._budget.acquire(Budget.COLD_BYTES)
	var state: Array = _image()
	var funding: PackedByteArray = _router._funding.state_bytes()
	assert_false(_router.complete_order(project).ok, "preflight loses original scope")
	assert_true(_image() == state and _router._funding.state_bytes() == funding, "no physical or paid publication")
	assert_true(_f._budget.covers(_replacement_token, Budget.COLD_BYTES), "replacement owner preserved")
	assert_equal(_f._budget.release(_replacement_token), &"", "release only test-owned token")
	_replacement_token = 0
	assert_true(_router.complete_order(project).ok, "valid retry is funded once")


func test_late_new_well_after_companion_observation_blocks_settlement() -> void:
	"""The final actual physical pass follows companion observers, catching a new unregistered surface exclusion."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	var well: Array[Vector2i] = [NULL_REF]
	_f._sources.when = func() -> bool: return _f._owner._sealed and _placements._route_token > 0
	_f._sources.probe = func() -> void:
		var made: Buildings.OpResult = _f._buildings.place_building(int(PaidFixture.BuildingCatalog.BUILDING_DEFINITION["well"]),
			49 * Buildings.MAP_TILES_X + 60, 0, 31)
		assert_true(made.ok, "actual unregistered later well")
		well[0] = made.ref
	var funding: PackedByteArray = _router._funding.state_bytes()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	assert_false(_router.complete_order(project).ok, "fresh physical exclusion refuses before payment")
	assert_true(well[0] != NULL_REF, "late observing source executed")
	assert_true(_router._funding.state_bytes() == funding and _f._owner.state_bytes() == geometry, "paid WIP and geometry preserved")
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 0, "nothing installed")
	assert_true(_f._buildings.demolish_building(well[0]).ok, "test removes genuine blocker")
	assert_true(_router.complete_order(project).ok, "same source retries with current exclusions")


func _installed_contact_ref() -> Vector2i:
	"""Select the single genuinely published Room contact in this finite actual fixture."""
	for row: int in _f._locations._capacity:
		if _f._locations._live.present[row] == 1 and _f._locations._ref_at(_f._locations._live, Locations.ROOM_SLOT, row) != NULL_REF:
			return Vector2i(row, _f._locations._live.i32[row])
	return NULL_REF


func _completed_timber() -> bool:
	"""Reuse actual paid setup; this helper grants no production source or excavation companion permission."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	assert_equal(paid.failures.size(), 0, "real accounting setup")
	if project == NULL_REF or not failures.is_empty(): return false
	var completed: Construction.OpResult = _router.complete_order(project)
	assert_true(completed.ok, "actual installation %s" % completed.error)
	return completed.ok


func _location_image(cold: int) -> PackedByteArray:
	"""One caller-owned wire under the exact shared lease is used only by this lifecycle test."""
	var image: PackedByteArray = PackedByteArray()
	assert_equal(_f._locations.capture_state_into(cold, image), &"", "actual current endpoint image")
	return image


func test_installed_contact_refresh_and_restore_use_actual_lower_paid_site() -> void:
	"""A published deck can refresh and restore without inventing an above-ground air Site."""
	if not _completed_timber(): return
	var ref: Vector2i = _installed_contact_ref()
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	assert_equal(_f._locations.read_location_into(ref, record), &"", "actual installed endpoint")
	assert_equal(_sites.site_at(_f._locations._cube_origin(record.point)), NULL_REF, "no fabricated upper Site")
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var token: int = _f._locations.begin_prepare(cold).token
	assert_equal(_f._locations.stage_refresh(token, ref), &"", "source-supported installed witness")
	assert_equal(_f._locations.seal(token), &"", "complete old payload requalified")
	assert_true(_f._locations.publish(token), "same full handle publishes")
	var image: PackedByteArray = _location_image(cold)
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"", "actual installed source survives load")
	assert_true(_location_image(cold) == image, "canonical payload unchanged")
	assert_equal(_f._budget.release(cold), &"", "original scope released")


func test_installed_restore_refuses_missing_prefix_paid_site_and_stale_source() -> void:
	"""The real installed witness is rederived on load; existing bytes do not authorize lost physical dependencies."""
	if not _completed_timber(): return
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var image: PackedByteArray = _location_image(cold)
	var prefix: int = Placements.INSTALLED * _placements._capacity
	_placements._live.i32[prefix] = 0
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"LOCATION_PAID_SITE_MISSING", "no uninstalled permission")
	_placements._live.i32[prefix] = 1
	var site: Vector2i = _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))
	_sites._phase[site.x] = Sites.OPEN_UNFINISHED
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"LOCATION_PAID_SITE_MISSING", "no unfinished witness")
	_sites._phase[site.x] = Sites.SUPPORTED_VOID
	_placements._live.i64[Placements.ROOM_REVISION * _placements._capacity] -= 1
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"LOCATION_PAID_SITE_MISSING", "old source pin cannot refresh itself")
	_placements._live.i64[Placements.ROOM_REVISION * _placements._capacity] += 1
	assert_true(_location_image(cold) == image, "every refusal preserves canonical endpoint bytes")
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"", "same original image retries")
	assert_equal(_f._budget.release(cold), &"", "own lease")


func test_installed_restore_rejects_provider_domain_and_catalog_substitution() -> void:
	"""Equal revisions cannot substitute another actual route/source namespace for the installed contact."""
	if not _completed_timber(): return
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var image: PackedByteArray = _location_image(cold)
	var catalog: Placements.Catalog = _f._binding._catalog
	_f._binding._catalog = null
	assert_true(_f._locations.restore_state_bytes(cold, image) != &"", "actual provider Catalog identity mandatory")
	_f._binding._catalog = catalog
	_f._binding._domain._bounds[0] += 1
	assert_true(_f._locations.restore_state_bytes(cold, image) != &"", "complete provider Domain mandatory")
	_f._binding._domain._bounds[0] -= 1
	assert_true(_location_image(cold) == image, "no partial replacement")
	assert_equal(_f._locations.restore_state_bytes(cold, image), &"", "restored actual wiring retries")
	assert_equal(_f._budget.release(cold), &"", "own lease")


func test_preflight_reentry_and_exhaustion_preserve_paid_state() -> void:
	"""A provider callback cannot discard the outer operation or consume work after exhausting its finite proof."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	var state: Array = _image()
	var funding: PackedByteArray = _router._funding.state_bytes()
	_source.probe = func() -> void:
		_bindings._discard_timber(_placements._prepared_placement, project, paid.paid_owner._cold_token)
	assert_false(_router.complete_order(project).ok, "nested cleanup poisons outer proof")
	assert_true(_image() == state and _router._funding.state_bytes() == funding, "reentry preserves all paid state")
	_source.probe = func() -> void: _bindings._entry_checks = 0
	assert_equal(_router.complete_order(project).error, Binding.REFUSE_MASK_BUDGET, "no proof after exhausted budget")
	assert_true(_image() == state and _router._funding.state_bytes() == funding, "finite refusal preserves all paid state")
	assert_true(_router.complete_order(project).ok, "same paid work retries after discarded observers")


func test_exact_l0_detached_fastening_target_uses_only_actual_post_bearings() -> void:
	"""The accepted1113 target is real near-side earth; all seven installed parts connect through four separate posts."""
	after_each()
	_catalog_mode = 3
	before_each()
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	assert_equal(paid.failures.size(), 0, "real four-cube accounting setup")
	if project == NULL_REF or not failures.is_empty(): return
	var completed: Construction.OpResult = _router.complete_order(project)
	assert_true(completed.ok, "separate1113 target and structural bearings: %s" % completed.error)
	assert_equal(_placements._get32(_placements._live, Placements.INSTALLED, 0), 1, "all seven parts paid as one group")
	assert_equal(_sites.virgin_sourced_milli(), 4 * Sites.EARTH_MILLI, "four unique complete paid cubes")
	assert_equal(_f._locations._live.count, 3, "one supported contact, no path permission")


func test_new_tree_in_retained_contact_air_outside_all_timber_and_bearings_refuses() -> void:
	"""Tree roots start exactly above the deep deck; only the full already-covered contact air intersects them."""
	after_each()
	_catalog_mode = 4
	before_each()
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	var added: Array[Vector2i] = [NULL_REF]
	_f._sources.when = func() -> bool: return _f._owner._sealed and _placements._route_token > 0
	_f._sources.probe = func() -> void:
		var made: Nodes.OpResult = _f._nodes.create_at_tile(49 * Buildings.MAP_TILES_X + 60, _f._items.compiled_id(&"wood"), 1000, 4, 1)
		assert_true(made.ok, "actual new unregistered tree")
		added[0] = made.ref
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var funding: PackedByteArray = _router._funding.state_bytes()
	assert_equal(_router.complete_order(project).error, Terrain.REFUSE_RESOURCE, "retained void cannot hide fresh root exclusion")
	assert_true(added[0] != NULL_REF, "last ordinary source observer ran")
	assert_true(_f._inventory.state_bytes() == inventory and _router._funding.state_bytes() == funding, "no paid settlement")
	assert_true(_f._owner.state_bytes() == geometry and _placements._get32(_placements._live, Placements.INSTALLED, 0) == 0, "no geometry/prefix swap")
	assert_true(_f._nodes.destroy(added[0]).ok, "remove actual new blocker")
	assert_true(_router.complete_order(project).ok, "same earned order retries after real exclusion disappears")


func _retention_observer() -> ObservedRetention:
	"""Replace only this test's retention adapter with a subclass that still asks the real graph."""
	var observer: ObservedRetention = ObservedRetention.new(_f._routes)
	_f._locations._retention = weakref(observer)
	return observer


func _without_endpoint_image(cold: int, extra: Vector2i) -> PackedByteArray:
	"""Create both lifecycle images through actual remove/seal/publish/load rather than forging serialized rows."""
	var original: PackedByteArray = _location_image(cold)
	var token: int = _f._locations.begin_prepare(cold).token
	assert_equal(_f._locations.stage_remove(token, extra), &"", "actual unretained extra can retire")
	assert_equal(_f._locations.seal(token), &"", "actual replacement sealed")
	assert_true(_f._locations.publish(token), "actual replacement published")
	var replacement: PackedByteArray = _location_image(cold)
	assert_equal(_f._locations.restore_state_bytes(cold, original), &"", "restore actual original image before late observer")
	return replacement


func test_final_restore_retention_profile_replacement_refuses_installed_witness() -> void:
	"""The final retention callback follows installed-row validation; actual new content must invalidate its proof."""
	if not _completed_timber(): return
	var extra: Vector2i = _f._location(Vector3i(WorldTests.X + 512, 512, WorldTests.Z + 512))
	var observer: ObservedRetention = _retention_observer()
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var replacement: PackedByteArray = _without_endpoint_image(cold, extra)
	var original: PackedByteArray = _location_image(cold)
	observer.calls = 0; observer.trigger = 2
	observer.probe = func() -> void:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_f.PROFILE_TEMP)
		bytes.encode_s64(12, 3)
		assert_equal(_f._profiles.load_file(_f.PROFILE_TEMP, _f._write(_f.PROFILE_TEMP, bytes), 3), &"", "actual newer profile content")
	assert_true(_f._locations.restore_state_bytes(cold, replacement) != &"", "late content change refuses complete replacement")
	assert_equal(observer.calls, 2, "observer ran only after installed-row validation")
	assert_true(_location_image(cold) == original, "all old endpoint bytes remain")
	assert_equal(_f._budget.release(cold), &"", "original lease remains caller-owned")
	_f._locations._retention = weakref(_f._routes._retention)


func test_fractional_installed_root_keeps_source_witness_after_final_retention() -> void:
	"""A completed containing Site cannot hide the actual fractional deck's source or installed-prefix identity."""
	after_each(); _catalog_mode = 5; before_each()
	if not _completed_timber(): return
	var point: Vector3i = Vector3i(WorldTests.X + 512, 384, WorldTests.Z - 512)
	var site: Vector2i = _sites.site_at(_f._locations._cube_origin(point))
	assert_true(site != NULL_REF, "fractional root lies inside actual completed cube")
	assert_equal(_sites._phase[site.x], Sites.SUPPORTED_VOID, "root cube is genuinely complete")
	var extra: Vector2i = _f._location(Vector3i(WorldTests.X + 512, 512, WorldTests.Z + 512))
	var observer: ObservedRetention = _retention_observer()
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var replacement: PackedByteArray = _without_endpoint_image(cold, extra)
	var original: PackedByteArray = _location_image(cold)
	_fractional_witness_refusals(cold, original, site)
	observer.calls = 0; observer.trigger = 2
	observer.probe = _replace_actual_profiles
	assert_true(_f._locations.restore_state_bytes(cold, replacement) != &"", "fractional timber source remains mandatory")
	assert_equal(observer.calls, 2, "late final observer ran")
	assert_true(_location_image(cold) == original, "complete old endpoint image survives")
	assert_equal(_f._budget.release(cold), &"", "original lease retained")
	_f._locations._retention = weakref(_f._routes._retention)


func _fractional_witness_refusals(cold: int, original: PackedByteArray, site: Vector2i) -> void:
	"""Neither a completed root cube nor retained support replaces the exact installed prefix/lower paid witness."""
	var prefix: int = Placements.INSTALLED * _placements._capacity
	_placements._live.i32[prefix] = 0
	assert_equal(_f._locations.restore_state_bytes(cold, original), &"LOCATION_PAID_SITE_MISSING", "fractional prefix remains mandatory")
	_placements._live.i32[prefix] = 1
	_sites._phase[site.x] = Sites.OPEN_UNFINISHED
	assert_equal(_f._locations.restore_state_bytes(cold, original), &"LOCATION_PAID_SITE_MISSING", "fractional lower Site remains mandatory")
	_sites._phase[site.x] = Sites.SUPPORTED_VOID
	assert_true(_location_image(cold) == original, "fractional witness refusals preserve all old payloads")


func _replace_actual_profiles() -> void:
	"""Load a genuinely newer immutable source through its real cold decoder, retaining no stale success flag."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_f.PROFILE_TEMP)
	bytes.encode_s64(12, 3)
	assert_equal(_f._profiles.load_file(_f.PROFILE_TEMP, _f._write(_f.PROFILE_TEMP, bytes), 3), &"", "real content replaced")


func _actual_natural_anchor() -> Anchor:
	"""This real provider borrows the same generated World and all original actual stores."""
	var anchor: Anchor = Anchor.new()
	assert_equal(anchor.configure(_f._world, _f._terrain, _f._owner, _f._sources,
		_f._locations, _f._budget, Anchor.RESERVED_BYTES), &"", "actual natural World publisher")
	return anchor


func _create_natural_anchor(anchor: Anchor) -> Anchor.Result:
	"""Request fresh exterior ground outside every installed prism, paid cavity and retained Room claim."""
	var point: Vector3i = Vector3i(WorldTests.X + 3072, 512, WorldTests.Z + 512)
	var envelope: PackedInt32Array = PackedInt32Array([point.x - 256, 512, point.z - 256, point.x + 256, 1536, point.z + 256])
	var support: PackedInt32Array = PackedInt32Array([point.x - 256, 384, point.z - 256, point.x + 256, 512, point.z + 256])
	return anchor.create(point, envelope, support, Locations.ROLE_WORK)


func test_actual_world_create_refreshes_installed_contact_before_space_swap_only() -> void:
	"""A real new natural anchor preserves old timber endpoints; its final witness cannot inspect a retired bank."""
	if not _completed_timber(): return
	var anchor: Anchor = _actual_natural_anchor()
	var ref: Vector2i = _installed_contact_ref()
	var watched: WatchedLocations = _f._locations as WatchedLocations
	watched.watch_witness = true
	var result: Anchor.Result = _create_natural_anchor(anchor)
	assert_equal(result.error, &"", "actual create with existing installed contact")
	assert_true(watched.pre_swap_witnesses > 0, "installed proof precedes first swap")
	assert_equal(watched.post_swap_witnesses, 0, "no installed work or old-bank read follows Space publication")
	assert_true(_f._locations._live_ref(_f._locations._live, ref), "same full installed handle retained")
	assert_equal(_f._locations._live.count, 4, "only the requested new natural contact added")


func test_world_final_profile_observer_refuses_before_either_bank_swaps() -> void:
	"""The actual World publisher needs its final installed proof after the last public Location observation."""
	if not _completed_timber(): return
	var anchor: Anchor = _actual_natural_anchor()
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var original: PackedByteArray = _location_image(cold)
	assert_equal(_f._budget.release(cold), &"", "only the actual provider acquires the next lease")
	var geometry: PackedByteArray = _f._owner.state_bytes()
	(_f._locations as WatchedLocations).prepared_probe = _replace_actual_profiles
	assert_true(_create_natural_anchor(anchor).error != &"", "late immutable source refuses")
	assert_true(_f._owner.state_bytes() == geometry, "no earlier Space publication")
	cold = _f._budget.acquire(Budget.COLD_BYTES)
	assert_true(_location_image(cold) == original, "no endpoint publication")
	assert_equal(_f._budget.release(cold), &"", "actual provider released only its original scope")


func test_generic_site_preparation_cannot_publish_an_installed_refresh() -> void:
	"""An actual Site order/token cannot borrow the installation or World commit kernels; phase composition is separate."""
	if not _completed_timber(): return
	var site: Vector2i = _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))
	assert_true(_sites.open_phase(site, Contract.OP_BACKFILL_CLOSE).ok, "actual scoped terminal order")
	var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
	var original: PackedByteArray = _location_image(cold)
	var geometry: PackedByteArray = _f._owner.state_bytes()
	var space_token: int = _f._owner.begin_stage(_f._owner.revision()).token
	assert_equal(_f._owner.seal(space_token), &"", "actual generic Space candidate")
	var begun: Locations.Result = _f._locations.begin_prepare(cold, space_token, site, Contract.OP_BACKFILL_CLOSE, Contract.STAGE_START)
	assert_equal(begun.error, &"", "actual Site/project context")
	assert_equal(_f._locations.stage_refresh(begun.token, _installed_contact_ref()), &"LOCATION_PAID_SITE_MISSING", "no generic installed refresh")
	assert_true(_f._locations.seal(begun.token) != &"", "skipping refresh cannot seal retained installed payload")
	assert_true(_f._locations.abort(begun.token), "own refused candidate discarded")
	assert_true(_f._owner.abort(space_token), "original Space never swapped")
	assert_true(_f._owner.state_bytes() == geometry and _location_image(cold) == original, "both banks remain unchanged")
	assert_equal(_f._budget.release(cold), &"", "original scope remains caller-owned")


func test_final_seal_prepared_and_publish_retention_recheck_lower_paid_site() -> void:
	"""All three ordinary candidate boundaries recheck a late loss of the exact lower paid Site without another survey."""
	for boundary: int in 3:
		if boundary > 0:
			after_each(); before_each()
		if not _completed_timber(): return
		var extra: Vector2i = _f._location(Vector3i(WorldTests.X + 512, 512, WorldTests.Z + 512))
		var observer: ObservedRetention = _retention_observer()
		var cold: int = _f._budget.acquire(Budget.COLD_BYTES)
		var original: PackedByteArray = _location_image(cold)
		var site: Vector2i = _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))
		var token: int = _f._locations.begin_prepare(cold).token
		assert_equal(_f._locations.stage_refresh(token, _installed_contact_ref()), &"", "installed source initially qualifies")
		assert_equal(_f._locations.stage_remove(token, extra), &"", "separate unretained endpoint removed")
		if boundary > 0: assert_equal(_f._locations.seal(token), &"", "initial candidate valid")
		observer.calls = 0
		observer.probe = func() -> void: _sites._phase[site.x] = Sites.OPEN_UNFINISHED # Negative late fact corruption only.
		if boundary == 0: assert_true(_f._locations.seal(token) != &"", "seal rejects lost lower Site")
		elif boundary == 1: assert_true(_f._locations.prepared_refusal(token) != &"", "prepared proof rejects lost lower Site")
		else: assert_false(_f._locations.publish(token), "publication rejects lost lower Site")
		assert_equal(observer.calls, 1, "the final actual graph observer executed")
		_sites._phase[site.x] = Sites.SUPPORTED_VOID
		assert_true(_f._locations.abort(token), "refused candidate remains uncommitted")
		assert_true(_location_image(cold) == original, "full original payload remains")
		assert_equal(_f._budget.release(cold), &"", "exact held lease preserved")
		_f._locations._retention = weakref(_f._routes._retention)


func test_lower_site_drift_after_last_physical_observer_refuses_before_funding() -> void:
	"""The final pure Placement guard covers new installed endpoints after every Authority observer has returned."""
	var paid: PaidFixture.Fixture = _timber_paid_fixture()
	var project: Vector2i = _ready_timber(paid)
	if project == NULL_REF or not failures.is_empty(): return
	var site: Vector2i = _sites.site_at(Vector3i(WorldTests.X, -512, WorldTests.Z - 1024))
	_bindings.timber_final_probe = func() -> void: _sites._phase[site.x] = Sites.OPEN_UNFINISHED
	var inventory: PackedByteArray = _f._inventory.state_bytes()
	var funding: PackedByteArray = _router._funding.state_bytes()
	var geometry: PackedByteArray = _f._owner.state_bytes()
	assert_equal(_router.complete_order(project).error, &"LOCATION_PAID_SITE_MISSING", "late paid-witness drift refused")
	assert_true(_f._inventory.state_bytes() == inventory and _router._funding.state_bytes() == funding, "no settlement")
	assert_true(_f._owner.state_bytes() == geometry and _placements._get32(_placements._live, Placements.INSTALLED, 0) == 0, "no companion publication")
	_sites._phase[site.x] = Sites.SUPPORTED_VOID
	assert_true(_router.complete_order(project).ok, "exact original order retries")
