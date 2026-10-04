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


class ActualFixture extends EntryTests.Fixture:
	var extra_floor: Vector2i = NULL_REF

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
		var bytes: PackedByteArray = GroupTests._catalog_wire(4, revision)
		bytes.encode_s64(48, 2)
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


func before_each() -> void:
	"""Every admission and conserved store is real; no prospective geometric permission callback is supplied."""
	_f = ActualFixture.new()
	_f._actual_fixture()
	_f._publish_route()
	_group = GroupTests.new()
	_group._catalog = _f._catalog
	_group._items = _f._items
	_group._inventory = _f._inventory
	_group._bind_source(_group._group_wire(), PackedInt32Array([0, 2]))
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
	var caps: PackedInt32Array = PackedInt32Array([2, 1, 1, 1, 2, 1])
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
	var counts: PackedInt32Array = PackedInt32Array([2, 1, 1, 1, 2, 1])
	for table: int in 6: bytes.encode_u32(68 + 4 * table, counts[table])
	_source_hashes(bytes)
	for ordinal: int in 2:
		CatalogTests._append_row(bytes, PackedInt32Array([ordinal, 0, 0, 0, 1, 0, 1, 1, 0]))
	CatalogTests._append_row(bytes, PackedInt32Array([0, 512, 0, 512, 0, 1, 0, 4, Jobs.JOB_KIND_BUILD]), 1)
	for rotation: int in range(1, 4): CatalogTests._append_row(bytes, PackedInt32Array([rotation + 1]), 1)
	CatalogTests._append_row(bytes, PackedInt32Array([0, -1024, -1024, 1024, 0, 0, Sites.SUPPORTED_VOID]))
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.NATURAL, -1, -1, -1024, -1024, -1024, 0, 0, 0]))
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.SURFACE_ANCHOR, -1, 0, Locations.ROLE_WORK, 512, 0, 512, 0]), 1)
	CatalogTests._append_row(bytes, PackedInt32Array([Frontier.SURFACE_CONTACT, -1, 0, Locations.ROLE_STORAGE, 1536, 0, 512, 0]), 1)
	CatalogTests._append_row(bytes, PackedInt32Array([0, -1024, -1024, 1024, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 4]))
	bytes.append_array("UGFEND01".to_ascii_buffer())
	return bytes


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
	_physical = EntryTests.PhysicalBinding.new()
	_physical.space = _f._owner
	_physical.world = _f._world_ref
	_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "real Site ledger")
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
	if _bindings != null: _bindings.probe = Callable()
	_replacement_token = 0
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
	plan.claims = PackedInt32Array([WorldTests.X, -512, WorldTests.Z - 1024, WorldTests.X + 1024, 512, WorldTests.Z])
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
	assert_equal(_image(), before, "all owners unchanged: " + why)
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


func test_source_change_wrong_anchor_and_fractional_claim_refuse_unchanged() -> void:
	"""Exact loaded source, full WORK anchor and complete source cut set are independent mandatory gates."""
	var plan: EntryPlan.Request = _plan()
	plan.source_digests[127] ^= 1
	_refused(plan, "changed frontier digest")
	plan = _plan()
	plan.anchor = _f._last
	_refused(plan, "storage is not a WORK anchor")
	plan = _plan()
	plan.claims[0] += 256
	_refused(plan, "fractional marker cannot claim a hidden full cube")
	plan = _plan()
	plan.claims[3] += 1024
	_refused(plan, "extra cube missing from source")


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
	_seed_backfilled_history(Vector3i(WorldTests.X - 1024, -512, WorldTests.Z - 1024))
	assert_equal(_refused(_plan(), "paid source footing"), Binding.REFUSE_ENTRY_BEARING, "source bearing checks history")


func test_backfilled_anchor_footing_is_not_original_natural_earth() -> void:
	"""The actual exterior worker support receives the same immutable-history check as source load bearings."""
	_seed_backfilled_history(Vector3i(WorldTests.X, -512, WorldTests.Z))
	assert_equal(_refused(_plan(), "paid anchor footing"), Binding.REFUSE_ENTRY_BEARING, "anchor checks history")


func test_backfilled_storage_footing_is_not_original_natural_earth() -> void:
	"""A real storage endpoint cannot claim a natural-foundation exemption over earlier paid fill."""
	_seed_backfilled_history(Vector3i(WorldTests.X + 1024, -512, WorldTests.Z))
	assert_equal(_refused(_plan(), "paid storage footing"), Binding.REFUSE_ENTRY_BEARING, "storage checks history")
