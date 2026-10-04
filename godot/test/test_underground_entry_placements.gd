extends "res://test/framework/test_case.gd"
## Actual future Room/Sites/Space/Placement and old route/endpoint publication.
## Body certificates, source frontier and prospective contacts remain explicit test fixtures.

const PaidTests := preload("res://test/test_underground_connector_placements.gd")
const EntryTests := preload("res://test/test_underground_entry_orders.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const PhysicalTests := preload("res://test/test_excavation_physical.gd")
const WorldTests := preload("res://test/test_underground_world_routes.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const ExcavationContract := preload("res://scripts/core/excavation_contract.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class Fixture extends PaidTests.ActualFixture:

	func _actual_space(obstruction: int) -> void:
		"""Start with complete actual surface fixtures but no pre-created underground Room or Room authority."""
		_space_with_source_probe(obstruction)

class PhysicalBinding extends PhysicalTests.SpatialFixture:

	var space: Owner = null

	func domain_into(out: ExcavationContract.Domain) -> bool:
		"""Actual Site keys use exactly the immutable World geometry Domain, not the small accounting fixture."""
		out.world_ref = space._domain._world
		out.datum_u = space._domain._datum
		out.minimum_quantum = space._domain._min_quantum
		out.size_quanta = space._domain._size_quanta
		return true

class Frontier extends Placements.Authority:
	var fixture: WeakRef = null
	var placements: WeakRef = null
	var edge: Vector2i = NULL_REF
	var probe: Callable = Callable()
	var probes: int = 0
	var location_probe: Callable = Callable()
	var route_probe: Callable = Callable()
	var omit_location: bool = false
	var omit_route: bool = false
	var allow_retirement: bool = false

	func exact_binding(candidate: RefCounted, space: Owner, locations: Locations, routes: Routes, budget: Budget) -> bool:
		"""The fixture grants only prospective frontier permission; all actual owner identities stay mandatory."""
		var f: Fixture = fixture.get_ref() as Fixture
		return candidate == placements.get_ref() and space == f._owner and locations == f._locations \
			and routes == f._routes and budget == f._budget

	func admission_refusal(_placement: Vector2i, _request: Placements.Request, _cold: int) -> StringName:
		"""A one-shot hostile observation can mutate inputs or revoke the original lease before any bank copy."""
		probes += 1
		if probe.is_valid():
			var pending: Callable = probe
			probe = Callable()
			pending.call()
		return &""

	func refresh_admission_locations(_placement: Vector2i, token: int, _cold: int) -> StringName:
		"""Every existing endpoint requalifies against the real sealed future Room without adding one."""
		var f: Fixture = fixture.get_ref() as Fixture
		if location_probe.is_valid():
			var pending: Callable = location_probe
			location_probe = Callable()
			pending.call()
		var code: StringName = f._locations.stage_refresh(token, f._first)
		return f._locations.stage_refresh(token, f._last) if code == &"" and not omit_location else code

	func refresh_admission_routes(_placement: Vector2i, token: int, _cold: int) -> StringName:
		"""Actual WorldRoutes recompiles the old path's exact profile masks from the new physical snapshot."""
		if route_probe.is_valid():
			var pending: Callable = route_probe
			route_probe = Callable()
			pending.call()
		return &"" if omit_route else (fixture.get_ref() as Fixture)._routes.stage_refresh(token, edge)

	func retirement_refusal(_placement: Vector2i, _cold: int) -> StringName:
		"""Only tests which explicitly assume completed structural cleanup can retire their pending identity."""
		return &"" if allow_retirement else Placements.REFUSE_AUTHORITY

class Binding extends EntryTests.EntryBindings:
	var placements: Placements = null
	var request: Placements.Request = null
	var prepared: Vector2i = NULL_REF
	var published: Vector2i = NULL_REF
	var final_probe: Callable = Callable()
	var prepared_probe: Callable = Callable()
	var publication_error: StringName = &""
	var seal_observed: bool = false
	var source: PaidTests.ObservedSources = null
	var final_source_reads: int = 0

	func entry_prepared_refusal(plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
			section_ref: Vector2i, token: int) -> StringName:
		"""Call the actual Placement only after the real RoomOrders sequence has sealed its source and claims."""
		seal_observed = space._sealed
		request = _request_for(plan, candidate.ref, section_ref)
		var result: Placements.Result = placements.prepare_admission(request, candidate, orders.get_ref(), arena_token, token)
		prepared = result.placement
		if result.error == &"" and prepared_probe.is_valid():
			var pending: Callable = prepared_probe
			prepared_probe = Callable()
			pending.call()
		return result.error

	func _request_for(plan: EntryPlan.Request, room: Vector2i, section_ref: Vector2i) -> Placements.Request:
		"""Only the exact paired null tuple expands to the actual future full Room/section identities."""
		var result: Placements.Request = Placements.Request.new()
		result.corridor = room
		result.section = section_ref
		result.anchor = plan.anchor
		result.origin = plan.origin_u
		result.rotation = plan.rotation
		result.level = plan.base_level
		result.targets = plan.opening_targets.duplicate()
		for offset: int in range(0, result.targets.size(), 4):
			if Vector2i(result.targets[offset], result.targets[offset + 1]) == NULL_REF \
					and Vector2i(result.targets[offset + 2], result.targets[offset + 3]) == NULL_REF:
				result.targets[offset] = room.x
				result.targets[offset + 1] = room.y
				result.targets[offset + 2] = section_ref.x
				result.targets[offset + 3] = section_ref.y
		return result

	func entry_final_refusal(_plan: EntryPlan.Request, candidate: Directory.CreateCandidate,
			_section: Vector2i, token: int) -> StringName:
		"""The last test observer precedes the production callback-free candidate/source/companion leaf."""
		if final_probe.is_valid():
			var pending: Callable = final_probe
			final_probe = Callable()
			pending.call()
		var code: StringName = placements.prepared_admission_leaf_refusal(prepared, candidate, orders.get_ref(), arena_token, token)
		final_source_reads = source.observed
		if code == &"":
			source.when = func() -> bool: return construction._buildings.is_live_room(candidate.ref)
			source.probe = func() -> void: pass
		return code

	func publish_entry_plan(room: Vector2i, token: int) -> void:
		"""Real Room, Sites and Space are already published; only the pure actual Placement companion tail follows."""
		var actual: Orders = orders.get_ref() as Orders
		publication_error = placements.publish_admission(prepared, actual._room_candidate, actual, arena_token, token)
		assert(publication_error == &"", "preflighted actual Placement tail")
		assert(source.observed == final_source_reads, "no observing source after identity")
		source.when = Callable()
		source.probe = Callable()
		published = prepared
		published_section = section
		assert(room == pending_room, "same future full Room")
		prepared = NULL_REF
		request = null
		section = NULL_REF
		_clear_room_companion()

	func discard_entry_plan(room: Vector2i, token: int) -> void:
		"""Only owned original Location/Routes scratch is discarded; RoomOrders retains Space and the arena."""
		if prepared != NULL_REF:
			var actual: Orders = orders.get_ref() as Orders
			placements.discard_admission(prepared, actual._room_candidate, actual, arena_token, token)
		prepared = NULL_REF
		request = null
		source.when = Callable()
		source.probe = Callable()
		super.discard_entry_plan(room, token)

var _f: Fixture = null
var _group: GroupTests = null
var _placements: Placements = null
var _frontier: Frontier = null
var _bindings: Binding = null
var _orders: Orders = null
var _router: Router = null
var _sites: Sites = null
var _physical: PhysicalTests.SpatialFixture = null
var _edge: Vector2i = NULL_REF


func before_each() -> void:
	"""Start with actual complete approach identities, immutable content and no pre-created underground Corridor."""
	_f = Fixture.new()
	_f._actual_fixture()
	_edge = _f._publish_route()
	_group = GroupTests.new()
	_group._catalog = _f._catalog
	_group._items = _f._items
	_group._inventory = _f._inventory
	_group._bind_source(_group._group_wire(1, 1), PackedInt32Array([0]), false, 4)
	assert_equal(_group._load_source(), &"", "actual complete assembly/recipe sources")
	_placements = Placements.new()
	assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "admitted actual Placement columns")
	assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
		_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "same actual immutable and physical owners")
	_frontier = Frontier.new()
	_frontier.fixture = weakref(_f)
	_frontier.placements = weakref(_placements)
	_frontier.edge = _edge
	assert_equal(_placements.bind_authority(_frontier), &"", "explicit synthetic frontier only")
	_bind_orders()
	assert_true(_f.failures.is_empty(), "actual fixture: %s" % _f.failures)
	assert_true(_group.failures.is_empty(), "immutable fixture: %s" % _group.failures)


func _bind_orders() -> void:
	"""The sole real Room authority owns the future candidate, immutable Domain and original whole cold lease."""
	var physical: PhysicalBinding = PhysicalBinding.new()
	physical.space = _f._owner
	_physical = physical
	_physical.world = _f._world_ref
	_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual physical Site/Funding owner")
	_router = Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual shared Router")
	_orders = Orders.new()
	_bindings = Binding.new()
	_bindings.arena = _f._budget
	_bindings.construction = _f._construction
	_bindings.space = _f._owner
	_bindings.world = _f._world_ref
	_bindings.inventory = _f._inventory
	_bindings.orders = weakref(_orders)
	_bindings.placements = _placements
	_bindings.source = _f._sources as PaidTests.ObservedSources
	assert_equal(_orders.configure(_router, _f._owner, _f._sources, RoomCatalog.new(), _bindings), &"", "actual RoomOrders")
	assert_equal(_f._locations.bind_room_orders(_orders), &"", "exact actual Room companion scope")


func after_each() -> void:
	"""Every failure leaves original scratch unowned; propagate inherited real fixture assertions and leaks."""
	assert_true(_f._budget.is_quiescent(), "no lease escaped actual RoomOrders cleanup")
	assert_equal(_placements._cold_token, 0, "no retained Placement operation")
	_bindings = null
	_orders = null
	_router = null
	_sites = null
	_physical = null
	_frontier = null
	_placements = null
	_group._reader = null
	_group._recipes = null
	_group._catalog = null
	_group._items = null
	_group._inventory = null
	_group = null
	_f.after_each()
	assert_true(_f.failures.is_empty(), "actual fixture helpers: %s" % _f.failures)
	_f = null
	for path: String in [GroupTests.GROUP_PATH, GroupTests.RECIPE_PATH, GroupTests.CATALOG_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _plan(offset: int = 4096) -> EntryPlan.Request:
	"""A genuine source-pinned request uses synthetic non-flat excavation claims, not physical permission."""
	var result: EntryPlan.Request = EntryPlan.Request.new()
	result.world = _f._world_ref
	result.space_revision = _f._owner.revision()
	result.base_level = 0
	result.origin_u = Vector3i(WorldTests.X + offset, 512, WorldTests.Z)
	result.rotation = 0
	result.anchor = _f._first
	result.catalog_row = _placements._live.header[Placements.H_CATALOG_ROW]
	result.catalog_revision = _placements._live.header[Placements.H_CATALOG_REV]
	result.variant_revision = _placements._live.header[Placements.H_VARIANT_REV]
	result.grouping_revision = _placements._live.header[Placements.H_GROUP_REV]
	result.recipe_revision = _placements._live.header[Placements.H_RECIPE_REV]
	result.frontier_revision = 1
	result.source_digests = _placements._live.digests.duplicate()
	for index: int in 32:
		result.source_digests[96 + index] = 19
	result.claims = PackedInt32Array([result.origin_u.x, -512, result.origin_u.z,
		result.origin_u.x + 1024, 1536, result.origin_u.z + 1024])
	for ordinal: int in _placements._opening_count():
		result.opening_targets.append_array(PackedInt32Array([-1, 0, -1, 0]))
	return result


func test_actual_confirmation_publishes_future_placement_and_refreshes_old_paths() -> void:
	"""Room identity, SOLID paid keys, metadata and Placement publish together; old complete circulation remains."""
	var previous_revision: int = _f._owner.revision()
	var previous_locations: int = _f._locations._live.count
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_true(result.ok, "actual entry confirmation: %s" % result.error)
	assert_true(_bindings.seal_observed, "Placement starts only after real Space seal")
	assert_equal(_bindings.publication_error, &"", "pure actual Placement publication")
	assert_equal(_f._owner.revision(), previous_revision + 1, "one physical metadata revision")
	assert_equal(_f._locations._live.count, previous_locations, "no future endpoint created")
	assert_equal(_f._routes._live.edge_count, 1, "no future edge created")
	assert_equal(_f._binding.static_profile_edge_refusal(_edge, 0, 1, 1), &"", "old actual profile certificate refreshed")
	var record: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_placements.placement_into(_bindings.published, record), &"", "new full Placement live")
	assert_equal(record.corridor, result.ref, "the actual newly allocated permanent Corridor")
	assert_equal(record.installed_count, 0, "no paid assembly installed")
	assert_equal(record.project, NULL_REF, "no temporary Project or Job")
	assert_equal(_placements.audit(), &"", "actual streamed-store invariants")


func test_unbound_or_refused_companion_preserves_all_live_owners() -> void:
	"""Missing actual old-path requalification refuses before Room/Site identity and preserves source pins."""
	var ids: PackedByteArray = _f._residents.directory().state_bytes()
	var space: PackedByteArray = _f._owner.state_bytes()
	var locations: PackedInt32Array = _f._locations._live.i32.duplicate()
	var revisions: PackedInt64Array = _f._locations._live.i64.duplicate()
	_frontier.omit_route = true
	var result: Buildings.OpResult = _orders.confirm_entry(_plan())
	assert_false(result.ok, "old route must be fully refreshed")
	assert_equal(_f._residents.directory().state_bytes(), ids, "no generation or PID spent")
	assert_equal(_f._owner.state_bytes(), space, "live source/claims unchanged")
	assert_equal(_f._locations._live.i32, locations, "old endpoint fields unchanged")
	assert_equal(_f._locations._live.i64, revisions, "old endpoint revisions unchanged")
	assert_equal(_placements._live.header[Placements.H_COUNT], 0, "no Placement published")
	assert_equal(_placements._live.header[Placements.H_FRONTIER_REV], 0, "refused first source bind remains unbound")


func _live_state() -> Dictionary:
	"""Test-only full byte copies make refused identity, Site, geometry, endpoint, graph and Placement changes visible."""
	return {"ids": _f._residents.directory().state_bytes(), "space": _f._owner.state_bytes(),
		"sites": _sites.state_bytes(), "locations": _f._locations._live.i32.duplicate(),
		"location_revisions": _f._locations._live.i64.duplicate(), "edges": _f._routes._live.fields.duplicate(),
		"edge_revisions": _f._routes._live.longs.duplicate(), "vertices": _f._routes._live.vertices.duplicate(),
		"header": _placements._live.header.duplicate(), "digests": _placements._live.digests.duplicate(),
		"rows": _placements._live.i32.duplicate(), "revisions": _placements._live.i64.duplicate(),
		"openings": _placements._live.openings.duplicate(), "opening_revisions": _placements._live.opening_revision.duplicate()}


func _unchanged(before: Dictionary) -> void:
	"""No failed prospective operation may spend a generation, claim a key or change a retained owner byte."""
	var after: Dictionary = _live_state()
	for key: String in before:
		assert_equal(after[key], before[key], "unchanged %s" % key)


func test_first_frontier_bind_is_exact_and_remains_bound_after_retirement_to_empty() -> void:
	"""An empty row count never licenses replacing a source which was already accepted for this immutable store."""
	assert_true(_orders.confirm_entry(_plan()).ok, "first actual pending Corridor")
	var first: Vector2i = _bindings.published
	var accepted: PackedByteArray = _placements._live.digests.duplicate()
	_frontier.allow_retirement = true
	var cold: int = _f._budget.acquire(Placements.CONTROL_BYTES)
	assert_equal(_placements.retire(first, cold), &"", "explicit synthetic cleanup of uninstalled pending Placement")
	assert_equal(_f._budget.release(cold), &"", "test-owned cleanup lease")
	assert_equal(_placements._live.header[Placements.H_COUNT], 0, "all pending rows retired")
	assert_equal(_placements._live.header[Placements.H_FRONTIER_REV], 1, "source revision retained")
	assert_equal(_placements._live.digests, accepted, "source hash retained")
	var before: Dictionary = _live_state()
	var changed: EntryPlan.Request = _plan(8192)
	changed.frontier_revision = 2
	changed.source_digests[96] += 1
	assert_false(_orders.confirm_entry(changed).ok, "retired-to-empty cannot rebind")
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan(8192)).ok, "the same immutable source can admit a later Corridor")
	assert_equal(_bindings.published.x, first.x, "deterministic local row reuse")
	assert_equal(_bindings.published.y, first.y + 1, "local full generation advances")
	assert_equal(_placements.audit(), &"", "retired/reused store audits")


func test_late_frontier_tuple_and_original_request_changes_refuse_atomically() -> void:
	"""Neither an early frontier callback nor the final post-Sites observer may rewrite immutable pins."""
	var before: Dictionary = _live_state()
	_frontier.probe = func() -> void: _orders._entry_plan.source_digests[96] += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "private source tuple changed after admission")
	_unchanged(before)
	_bindings.final_probe = func() -> void: _bindings.request.origin.x += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "original expanded request changed after all preparation")
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan()).ok, "valid retry uses the original immutable source")


func test_first_frontier_pin_cannot_change_both_observed_request_images() -> void:
	"""First-bind revision/hash were pinned before the authority observation, even while the live store is unbound."""
	var before: Dictionary = _live_state()
	_frontier.probe = func() -> void:
		_orders._entry_plan.frontier_revision += 1
		_orders._entry_request.frontier_revision += 1
		_orders._entry_plan.source_digests[96] += 1
		_orders._entry_request.source_digests[96] += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "both mutable packets cannot replace the prepared source")
	_unchanged(before)
	assert_equal(_placements._live.header[Placements.H_FRONTIER_REV], 0, "first refusal does not bind live source")
	assert_true(_orders.confirm_entry(_plan()).ok, "the exact original source can retry")


func test_original_lease_replacement_after_sites_never_publishes_or_releases_replacement() -> void:
	"""A same-size arena lease has a new issuer token and cannot inherit sealed Room/Placement companions."""
	var before: Dictionary = _live_state()
	var replacement: PackedInt64Array = PackedInt64Array([0])
	_bindings.final_probe = func() -> void:
		assert_equal(_f._budget.release(_bindings.arena_token), &"", "last observer releases original")
		replacement[0] = _f._budget.acquire(Budget.COLD_BYTES)
	assert_false(_orders.confirm_entry(_plan()).ok, "replaced original lease refuses before identity")
	assert_true(_f._budget.covers(replacement[0], Budget.COLD_BYTES), "independent replacement not released")
	_unchanged(before)
	assert_equal(_f._budget.release(replacement[0]), &"", "only its owner releases replacement")
	assert_true(_orders.confirm_entry(_plan()).ok, "later exact original lease succeeds")


func test_final_candidate_and_prepared_payload_changes_refuse_before_identity() -> void:
	"""A current numerical geometry revision cannot launder another allocator tuple or altered old endpoint/path."""
	var before: Dictionary = _live_state()
	_bindings.final_probe = func() -> void: _orders._room_candidate.persistent_id += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "late candidate packet changed")
	_unchanged(before)
	_bindings.final_probe = func() -> void:
		_f._locations._stage.i32[Locations.X * _f._locations._capacity + _f._first.x] += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "old completed endpoint payload changed")
	_unchanged(before)
	_bindings.final_probe = func() -> void:
		_f._routes._stage.vertices[0] += 1
	assert_false(_orders.confirm_entry(_plan()).ok, "retained complete path changed")
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan()).ok, "unmodified old payloads remain usable")


func test_original_context_reentry_and_early_publication_cannot_commit() -> void:
	"""All external observers run before the exact real Room publication window and retain sticky reentry faults."""
	var before: Dictionary = _live_state()
	_frontier.probe = func() -> void:
		var result: Placements.Result = _placements.prepare_admission(_bindings.request, _orders._room_candidate,
			_orders, _bindings.arena_token, _orders._stage_token)
		assert_equal(result.error, Placements.REFUSE_BUSY, "same owner recursive preparation refuses")
	assert_false(_orders.confirm_entry(_plan()).ok, "outer callback remains poisoned")
	_unchanged(before)
	_bindings.prepared_probe = func() -> void:
		assert_false(Owner.room_commit_preflighted(_f._owner, _orders._stage_token, _orders._room_candidate,
			Buildings.ROOM_TYPE_CORRIDOR, _orders, _f._budget, _bindings.arena_token), "no preallocation kernel window")
		assert_true(_placements.publish_admission(_bindings.prepared, _orders._room_candidate, _orders,
			_bindings.arena_token, _orders._stage_token) != &"", "no early Placement receipt")
	assert_true(_orders.confirm_entry(_plan()).ok, "refused early attempt leaves exact original prepared state")


func test_second_admission_preserves_prior_self_target_and_rejects_other_source_tuple() -> void:
	"""The internal full self target remains pending metadata and can be a strictly validated later opening target."""
	assert_true(_orders.confirm_entry(_plan()).ok, "first Corridor")
	var old_row: int = _bindings.published.x
	var old_room: Vector2i = _placements._pair(_placements._live, Placements.ROOM_SLOT, old_row)
	var old_section: Vector2i = _placements._pair(_placements._live, Placements.SECTION_SLOT, old_row)
	var before: Dictionary = _live_state()
	var wrong: EntryPlan.Request = _plan(8192)
	wrong.source_digests[96] += 1
	assert_false(_orders.confirm_entry(wrong).ok, "same revision with a different source hash")
	_unchanged(before)
	var next: EntryPlan.Request = _plan(8192)
	next.opening_targets = PackedInt32Array([old_room.x, old_room.y, old_section.x, old_section.y])
	assert_true(_orders.confirm_entry(next).ok, "actual existing target passes unchanged")
	assert_equal(_placements._live.header[Placements.H_COUNT], 2, "two actual permanent pending Placements")
	assert_equal(_f._locations._live.count, 2, "no entrance endpoint manufactured")
	assert_equal(_f._routes._live.edge_count, 1, "no installed route manufactured")
	assert_equal(_placements.audit(), &"", "exact previous full target/source pins remain current")


func test_late_actual_retained_room_drift_never_gets_refreshed_into_a_new_placement() -> void:
	"""A second admission does not repair changed real before-facts belonging to the first pending Corridor."""
	assert_true(_orders.confirm_entry(_plan()).ok, "actual first Corridor")
	var room: Vector2i = _placements._pair(_placements._live, Placements.ROOM_SLOT, _bindings.published.x)
	var row: int = _f._residents.directory().get_typed_row(room)
	var before: Dictionary = _live_state()
	_bindings.final_probe = func() -> void: _f._buildings._r_type[row] = Buildings.ROOM_TYPE_DORMITORY
	assert_false(_orders.confirm_entry(_plan(8192)).ok, "real changed Room facts after observers")
	_f._buildings._r_type[row] = Buildings.ROOM_TYPE_CORRIDOR
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan(8192)).ok, "unchanged old sources permit later admission")


func test_missing_refresh_stale_anchor_and_mixed_opening_tuple_refuse_without_identity() -> void:
	"""Completed endpoint proof and exact paired opening semantics precede all future identity allocation."""
	var before: Dictionary = _live_state()
	_frontier.omit_location = true
	assert_false(_orders.confirm_entry(_plan()).ok, "every old Location must refresh")
	_frontier.omit_location = false
	_unchanged(before)
	var stale: EntryPlan.Request = _plan()
	stale.anchor.y += 1
	assert_false(_orders.confirm_entry(stale).ok, "full completed anchor generation")
	_unchanged(before)
	var mixed: EntryPlan.Request = _plan()
	mixed.opening_targets[2] = _f._floor.x
	mixed.opening_targets[3] = _f._floor.y
	assert_false(_orders.confirm_entry(mixed).ok, "one null and one live tuple is not an unconnected opening")
	_unchanged(before)


func test_request_growth_in_last_location_scope_refuses_before_actual_bank_copy() -> void:
	"""A late callback cannot enlarge both retained request images beyond the arena and then allocate a proof."""
	var before: Dictionary = _live_state()
	var counted: PaidTests.CountedLocationBank = PaidTests.CountedLocationBank.new()
	counted.allocate(_f._locations._capacity)
	_f._locations._stage = counted
	var source: PaidTests.ObservedSources = _f._sources as PaidTests.ObservedSources
	source.when = func() -> bool: return _placements._admission_mode and _f._locations._token == 0
	source.probe = func() -> void:
		_orders._entry_plan.claims.resize(6 * 16384)
		_orders._entry_request.claims.resize(6 * 16384)
	assert_false(_orders.confirm_entry(_plan()).ok, "mutable request growth refused")
	assert_equal(source.observed, 1, "actual final Location scope observation reached")
	assert_equal(counted.copies, 0, "size/token are rechecked before actual preallocated-bank copy")
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan()).ok, "bounded exact request retries")


func test_replaced_location_candidate_cannot_be_inherited_or_destroyed_by_original_cleanup() -> void:
	"""Even a new candidate for the same future Room has a different original issuer token."""
	var before: Dictionary = _live_state()
	var replacement: PackedInt64Array = PackedInt64Array([0])
	_bindings.prepared_probe = func() -> void:
		assert_true(_f._locations.abort(_placements._location_token), "observer discards original Location candidate")
		var next: Locations.Result = _f._locations.begin_room_prepare(_bindings.arena_token, _orders._stage_token,
			_orders._stage_room, Buildings.ROOM_TYPE_CORRIDOR)
		assert_equal(next.error, &"", "independent replacement starts under still-current Room scope")
		replacement[0] = next.token
	assert_false(_orders.confirm_entry(_plan()).ok, "old Placement cannot inherit replacement context")
	assert_equal(_f._locations._token, replacement[0], "original cleanup preserves unrelated Location token")
	assert_true(_f._locations.abort(replacement[0]), "test owner discards its independent candidate")
	_unchanged(before)
	assert_true(_orders.confirm_entry(_plan()).ok, "a fresh whole admission retries")
