extends "res://test/framework/test_case.gd"
## Real generated/populated Host and shipped Content; no synthetic source, geometry or phase permission.

const Host := preload("res://scripts/systems/settlement_system.gd")
const Session := preload("res://scripts/core/underground_session.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Composition := preload("res://scripts/core/underground_room_composition.gd")
const Retirement := preload("res://scripts/core/underground_world_retirement.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const World := preload("res://scripts/core/world_init.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")


class ObservedBuildings extends Buildings:
	var deny_installed_once: bool = false

	func spatial_authority() -> SpatialAuthority:
		"""A negative observation may refuse the installed authority, never supply a success override."""
		var actual: SpatialAuthority = super.spatial_authority()
		if actual != null and deny_installed_once:
			deny_installed_once = false
			return null
		return actual


class ObservedConstruction extends Construction:
	var deny_installed_once: bool = false

	func excavation_authority() -> ExcavationContract:
		"""Refuse only the first real installed backlink observation after Sites completed its genuine binding."""
		var actual: ExcavationContract = super.excavation_authority()
		if actual != null and deny_installed_once:
			deny_installed_once = false
			return null
		return actual


class ObservedWorld extends World:
	var session: WeakRef = null
	var prefix: int = -1
	var observer: Callable = Callable()

	func is_published() -> bool:
		"""A selected real constructor observation runs one adverse action after reading its true result."""
		var actual: bool = super.is_published()
		var owner: Session = session.get_ref() as Session if session != null else null
		if owner != null and owner._operations_state == 1 and owner._operations_prefix == prefix and observer.is_valid():
			var action: Callable = observer
			observer = Callable()
			action.call()
		return actual


class ObservedHost extends Host:
	func _compose_stock_layer() -> void:
		"""Create the real stock graph with one test-only negative bind observer before any other owner borrows it."""
		_inventory = ObservedInventory.new()
		_item_definitions = ItemDefinitionsScript.new()
		_item_definitions.load_default(_inventory)
		_stock_age = StockAgeScript.new(_inventory, _item_definitions)
		_bind_seed_expiry_authority()


	func _compose_ground_piles() -> void:
		"""Replace only unbound constructor candidates before the real host builds its original ground-pile graph."""
		_buildings = ObservedBuildings.new(_directory)
		_construction = ObservedConstruction.new(_buildings)
		_demolition_work = DemolitionWorkScript.new(_jobs, _construction)
		var previous: World = _world
		_world = ObservedWorld.new(previous._directory, previous._nodes, previous._forage, previous._fishing,
			previous._rng, previous._farming, previous._orchards, previous._jobs, previous._commands)
		super._compose_ground_piles()


class ObservedInventory extends Inventory:
	var observer: Callable = Callable()

	func bind_spatial_locations(authority: SpatialLocations, capacity: int) -> OpResult:
		"""Run the actual allocator/binder, then one adverse observation at the final installed boundary."""
		var result: OpResult = super.bind_spatial_locations(authority, capacity)
		if result.ok and observer.is_valid():
			var action: Callable = observer
			observer = Callable()
			action.call()
		return result

var _host: Host = null
var _content: Content = null
var _session: Session = null
var _nested_reset: bool = true
var _nested_tick: bool = true
var _original_gear: Gear = null
var _source_script: Script = null
var _source_text: String = ""
var _original_definitions: Composition.RoomCatalog.BuildingDefinitions = null


func before_each() -> void:
	"""Use actual current source/content and the same public World/foundation mount used by boot."""
	_host = Host.new()
	_content = Content.new()
	assert_equal(_content.load_file(Session.ACTOR_PATH, Session.Catalog.Pins.ACTOR_SHA,
		Session.PRESENTATION_BYTES), &"", "current actual image")
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "actual populated World")
	assert_true(_host.mount_underground(_content), "source foundation: %s" % _host.last_refusal())
	_session = _host.underground_session()


func after_each() -> void:
	"""Drop this test's original owners; no private external weak link is cleared by the fixture."""
	if _host != null and _host.world() is ObservedWorld:
		(_host.world() as ObservedWorld).observer = Callable()
	if _host != null and _host.inventory() is ObservedInventory:
		(_host.inventory() as ObservedInventory).observer = Callable()
	if _source_script != null: _source_script.source_code = _source_text
	if _original_definitions != null: _host.buildings()._definitions = _original_definitions
	_original_definitions = null
	_source_script = null
	_source_text = ""
	_original_gear = null
	_session = null
	_content = null
	if _host != null: _host.free()
	_host = null


func _snapshot() -> PackedStringArray:
	"""Canonical gameplay bytes exclude newly allocated empty derived namespaces and owner references."""
	var out: PackedStringArray = PackedStringArray()
	var images: Array[PackedByteArray] = [_host.directory().state_bytes(), _inventory_base_bytes(),
		_host.jobs().state_bytes(), _host.residents().state_bytes(), _host.transforms().state_bytes(),
		_host.construction().state_bytes(), _host.reservations().state_bytes(), _host.buildings().spatial_state_bytes()]
	for data: PackedByteArray in images:
		var hash_state: HashingContext = HashingContext.new()
		hash_state.start(HashingContext.HASH_SHA256)
		hash_state.update(data)
		out.append(hash_state.finish().hex_encode())
	return out


func _inventory_base_bytes() -> PackedByteArray:
	"""Compare all original serialized stock fields; the separate empty spatial appendix is new and checked below."""
	var data: PackedByteArray = _host.inventory().state_bytes()
	var spatial: PackedByteArray = PackedByteArray()
	_host.inventory()._append_spatial_state(spatial)
	data.resize(data.size() - spatial.size())
	return data


func test_actual_host_composes_exact_empty_owner_graph_without_gameplay_mutation() -> void:
	"""Every receiver comes from the mounted host; source-qualified geometry creates no endpoint or Room."""
	var before: PackedStringArray = _snapshot()
	assert_true(_host.compose_underground_room_owners(), "actual composition: %s" % _host.last_refusal())
	assert_equal(_snapshot(), before, "stock, Jobs, identities, buildings and World unchanged")
	var o: Retirement.Owners = _session._retirement_owners
	assert_equal(_session._operations_state, 2, "complete owner graph")
	assert_equal(_session._operations_prefix, 4, "all four owner groups")
	assert_equal(Composition.complete_refusal(o), &"", "complete exact wiring")
	assert_equal(o.room_bindings.get_script(), Retirement.EntryBindings, "initial exact entry-capable owner")
	assert_equal(_session.room_orders(), o.rooms, "actual Rooms borrowed")
	assert_equal(_session.location_owner(), o.locations, "actual Locations borrowed")
	assert_equal(_session.room_phase_provider(), o.world_bindings, "actual closed provider")
	assert_equal(o.sites._capacity, Composition.Sites.MAX_SITE_CAPACITY, "real Site budget")
	assert_equal(o.sites._funding._capacity, Composition.Funding.MAX_RECEIPT_CAPACITY, "one real Funding arena")
	assert_equal(o.router._funding, o.sites._funding, "shared funding, not duplicated")
	assert_equal(o.rooms._catalog._definitions, _host.buildings()._definitions, "original immutable facts borrowed")
	assert_equal(o.sites._count, 0, "no Site introduced")
	assert_equal(o.locations._live.count, 0, "no endpoint invented")
	assert_equal(o.routes._edge_capacity, 0, "route remains an unconfigured source shell")
	assert_equal(o.world_routes, null, "no synthetic route provider")
	assert_equal(o.contacts, null, "no work permission")
	assert_true(_host.compose_underground_room_owners(), "idempotent current recheck")
	assert_equal(_session._retirement_owners, o, "no second owner packet")
	assert_equal(_snapshot(), before, "repeat changes no gameplay bytes")


func test_initial_entry_binding_is_unbound_and_active_brackets_refuse_retirement() -> void:
	"""Inherited ordinary wiring does not fabricate an entry; its real additional brackets still govern reset."""
	assert_true(_host.compose_underground_room_owners(), "compose initial entry-capable authority")
	var entry: Retirement.EntryBindings = _session._retirement_owners.room_bindings as Retirement.EntryBindings
	assert_true(entry != null, "exact actual subtype")
	assert_equal(entry._entry_frontier, null, "no startup source substituted")
	assert_equal(entry._entry_placements, null, "no fabricated Placement")
	assert_equal(entry._entry_authority, null, "entry authority has not been published")
	var before: PackedStringArray = _snapshot()
	entry._entry_busy = true
	assert_false(_host.prepare_world_reset(), "active inherited entry bracket refuses")
	assert_equal(_snapshot(), before, "refused preflight preserves actual stores")
	assert_equal(_session._retirement_scope, null, "no Scope published")
	entry._entry_busy = false
	entry._timber_token = 17
	assert_false(_host.prepare_world_reset(), "active included-timber bracket refuses")
	assert_equal(_snapshot(), before, "second refusal remains unchanged")
	entry._timber_token = 0
	assert_true(_host.reset(), "quiescent original subtype retires")


func test_actual_reset_releases_original_graph_then_reuses_inventory_arena() -> void:
	"""Canonical host clearing precedes exact owner release and a fresh same-capacity namespace."""
	assert_true(_host.compose_underground_room_owners(), "compose")
	var original: Retirement.Owners = _session._retirement_owners
	var world_ref: Vector2i = _host.world_ref()
	assert_equal(_host.inventory()._spatial_container_slot.size(), Budget.INVENTORY_ENDPOINT_CAPACITY, "finite arena")
	assert_true(_host.prepare_world_reset(), "actual complete tuple preflight")
	assert_true(_host.prepare_world_reset(), "same Scope repeated")
	assert_true(_host.reset(), "actual clear/release: %s" % _host.last_refusal())
	assert_equal(_host.construction()._excavation_authority, null, "owner-owned excavation release")
	assert_equal(_host.work()._modular_authority, null, "owner-owned modular release")
	assert_equal(_host.buildings()._spatial_authority, null, "owner-owned Room release")
	assert_equal(_host.inventory()._spatial_authority, null, "owner-owned namespace release")
	assert_equal(_host.inventory()._spatial_container_slot.size(), Budget.INVENTORY_ENDPOINT_CAPACITY, "same arena retained")
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "new full World")
	assert_true(_host.mount_underground(_content), "remount current source")
	_session = _host.underground_session()
	assert_true(_host.compose_underground_room_owners(), "new actual owner graph")
	assert_true(_session._retirement_owners.locations != original.locations, "fresh namespace owner")
	assert_false(_host.directory().is_valid(world_ref), "old full World generation refuses")
	assert_equal(_host.inventory()._spatial_container_slot.size(), Budget.INVENTORY_ENDPOINT_CAPACITY, "no growth")


func _observed_host() -> ObservedWorld:
	"""Mount an actual generated host whose source readers can only inject failures or adverse observations."""
	_session = null
	_host.free()
	_host = ObservedHost.new()
	assert_true(_host.create_generated_settlement(_host.item_definitions()), "observed actual World")
	assert_true(_host.mount_underground(_content), "observed source foundation: %s" % _host.last_refusal())
	_session = _host.underground_session()
	var world: ObservedWorld = _host.world() as ObservedWorld
	world.session = weakref(_session)
	return world


func _assert_stopped_prefix(prefix: int, before: PackedStringArray) -> void:
	"""A real bound prefix survives refusal and cannot expose getters, dispatch work or restart composition."""
	assert_equal(_session._operations_state, 3, "retained failed state")
	assert_equal(_session._operations_prefix, prefix, "exact installed prefix")
	assert_equal(_snapshot(), before, "original gameplay fields unchanged")
	assert_equal(_session.current_refusal(), &"UNDERGROUND_COMPOSITION_STOPPED", "ordinary source access stopped")
	assert_equal(_session.room_orders(), null, "no fresh Room borrow")
	assert_equal(_session.location_owner(), null, "no fresh Location borrow")
	assert_equal(_session.room_phase_provider(), null, "no fresh provider borrow")
	assert_false(_host.run_tick(1), "tick stopped")
	assert_false(_host.create_initial_settlement(), "admission stopped")
	assert_false(_host.compose_underground_room_owners(), "no replacement constructor")
	assert_equal(_snapshot(), before, "stopped operations change no gameplay state")


func _assert_prefix_reset(prefix: int) -> void:
	"""Only whole-World canonical clearing can release the retained exact incomplete owner graph."""
	assert_true(_host.prepare_world_reset(), "prefix preflight: %s" % _host.last_refusal())
	var scope: Retirement.Scope = _session._retirement_scope
	assert_equal(scope._constructor_prefix, prefix, "Scope derives original private prefix")
	assert_true(_host.prepare_world_reset(), "same prefix repeat")
	assert_equal(_session._retirement_scope, scope, "no second Scope")
	assert_true(_host.abandon_world_reset(), "unchanged live abandonment")
	assert_false(_host.run_tick(1), "failed constructor cannot resume through abandonment")
	assert_true(_host.reset(), "actual full prefix retirement: %s" % _host.last_refusal())
	assert_equal(_host.construction()._excavation_authority, null, "Site receiver released")
	assert_equal(_host.construction()._modular_authority, null, "Router receiver released")
	assert_equal(_host.buildings()._spatial_authority, null, "Room receiver released")
	assert_equal(_host.inventory()._spatial_authority, null, "Inventory receiver released")
	assert_equal(_session._retirement_scope, null, "private Scope cycle broken")


func test_constructor_missing_authority_backlink_keeps_prefix_then_retires() -> void:
	"""The genuine Sites constructor can finish before its separately observed Authority backlink refuses."""
	_observed_host()
	(_host.construction() as ObservedConstruction).deny_installed_once = true
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "actual backlink refusal")
	assert_equal(_host.last_refusal(), &"SPACE_SITE_OWNER_MISMATCH", "real Authority refused")
	_assert_stopped_prefix(1, before)
	var o: Retirement.Owners = _session._retirement_owners
	assert_equal(o.authority._sites, null, "backlink was never installed")
	assert_equal(o.construction._excavation_authority.get_ref(), o.sites, "original Sites retained")
	assert_true(Retirement.prepare_into(_host, _session, o, Retirement.Scope.new()) != &"", "normal retirement not weakened")
	_assert_prefix_reset(1)


func test_constructor_missing_room_backlink_keeps_prefix_then_retires() -> void:
	"""Buildings publishes its real RoomOrders before reciprocal RoomAdmission can return a refusal."""
	_observed_host()
	(_host.buildings() as ObservedBuildings).deny_installed_once = true
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "real Room admission refused")
	_assert_stopped_prefix(3, before)
	var o: Retirement.Owners = _session._retirement_owners
	assert_equal(o.room_bindings._orders, null, "admission backlink absent")
	assert_equal(o.buildings._spatial_authority.get_ref(), o.rooms, "original Room authority retained")
	assert_true(Retirement.prepare_into(_host, _session, o, Retirement.Scope.new()) != &"", "complete retirement still rejects missing link")
	_assert_prefix_reset(3)


func _reenter_reset_and_tick() -> void:
	"""Attempt ordinary host operations from an actual constructor reader; both must poison and refuse."""
	_nested_reset = _host.reset()
	_nested_tick = _host.run_tick(1)


func test_reentrant_constructor_after_router_retains_both_original_bindings() -> void:
	"""Later observer refusal cannot drop the already once-bound Sites and Router or allow a gameplay tick."""
	var world: ObservedWorld = _observed_host()
	world.prefix = 2
	world.observer = _reenter_reset_and_tick
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "late constructor observes reentry")
	assert_false(world.observer.is_valid(), "actual selected reader executed")
	assert_false(_nested_reset, "recursive reset refuses")
	assert_false(_nested_tick, "recursive tick refuses")
	_assert_stopped_prefix(2, before)
	assert_equal(_session._retirement_owners.rooms, null, "unbound Room candidate not retained")
	_assert_prefix_reset(2)


func test_refusal_before_first_binding_keeps_foundation_and_can_retry() -> void:
	"""The only safely dropped candidates have never published a borrowed owner's one-way link."""
	var world: ObservedWorld = _observed_host()
	world.prefix = 0
	world.observer = _reenter_reset_and_tick
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "private prepare poisoned")
	assert_false(world.observer.is_valid(), "real source reader executed")
	assert_equal(_session._operations_state, 0, "foundation retained")
	assert_equal(_session._operations_prefix, 0, "no installed prefix")
	assert_equal(_host.construction()._excavation_authority, null, "no owner mutated")
	assert_equal(_session._retirement_owners.world_bindings, null, "private provider dropped")
	assert_equal(_snapshot(), before, "no gameplay mutation")
	assert_true(_host.compose_underground_room_owners(), "clean real retry")


func _change_profile_revision() -> void:
	"""Mutate the actual published bank only as an adverse source fixture; no replacement permission is supplied."""
	_session._profiles._live.header[0] += 1


func test_late_source_drift_retains_bound_prefix_and_refuses_reset_until_restored() -> void:
	"""Source revision equality is part of original lifetime, including a failed constructor's retirement."""
	var world: ObservedWorld = _observed_host()
	world.prefix = 2
	world.observer = _change_profile_revision
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "late current profile drift")
	assert_false(world.observer.is_valid(), "actual late observation executed")
	_assert_stopped_prefix(2, before)
	assert_false(_host.reset(), "changed original source cannot attest retirement")
	assert_equal(_snapshot(), before, "no store clear on stale source")
	_session._profiles._live.header[0] -= 1 # Restore only this test's exact tamper.
	_assert_prefix_reset(2)


func test_busy_foundation_refuses_before_allocating_any_operational_owner() -> void:
	"""A real active lease refuses composition without changing its original token or private owner packet."""
	var before: PackedStringArray = _snapshot()
	var token: int = _session._budget.acquire(64)
	assert_true(token > 0, "real held token")
	assert_false(_host.compose_underground_room_owners(), "busy foundation")
	assert_equal(_session._operations_state, 0, "no constructor started")
	assert_equal(_session._retirement_owners.sites, null, "no bank/owner admitted")
	assert_true(_session._budget.covers(token, 64), "original lease untouched")
	assert_equal(_snapshot(), before, "no stores mutated")
	assert_equal(_session._budget.release(token), &"", "release original token")
	assert_true(_host.compose_underground_room_owners(), "quiescent actual retry")


func test_captured_prefix_rejects_tuple_and_prefix_replacement() -> void:
	"""Same-number foreign objects and changed private phase cannot replace the Scope's original tuple."""
	_observed_host()
	(_host.construction() as ObservedConstruction).deny_installed_once = true
	assert_false(_host.compose_underground_room_owners(), "prefix one")
	assert_true(_host.prepare_world_reset(), "capture original")
	var before: PackedStringArray = _snapshot()
	_session._operations_prefix = 2
	assert_false(_host.reset(), "different prefix")
	assert_equal(_snapshot(), before, "no clear after scope mutation")
	_session._operations_prefix = 1
	var original: Composition.Authority = _session._retirement_owners.authority
	_session._retirement_owners.authority = Composition.Authority.new()
	assert_false(_host.reset(), "foreign Authority object")
	assert_equal(_snapshot(), before, "foreign object clears nothing")
	_session._retirement_owners.authority = original
	assert_true(_host.reset(), "original exact scope survives refusal")


func test_constructor_prefix_entry_refuses_arbitrary_supplied_session() -> void:
	"""The special path derives from the actual cached private Session and never accepts caller-declared incompleteness."""
	var scope: Retirement.Scope = Retirement.Scope.new()
	assert_equal(Retirement.prepare_constructor_prefix_into(_host, RefCounted.new(),
		_session._retirement_owners, scope), &"WORLD_RETIREMENT_INPUT", "foreign Session")
	assert_equal(Retirement.prepare_constructor_prefix_into(_host, _session,
		_session._retirement_owners, scope), &"WORLD_RETIREMENT_CONSTRUCTOR", "ordinary foundation is not a stopped prefix")
	assert_equal(scope._stage, 0, "no output Scope publication")
	assert_equal(scope._constructor_prefix, -1, "ordinary default unchanged")


func test_final_inventory_boundary_retains_complete_failed_prefix_for_reset() -> void:
	"""A real final bind may succeed before the original source leaf detects a change; its adapter must stay alive."""
	_observed_host()
	(_host.inventory() as ObservedInventory).observer = _change_profile_revision
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "actual final bind then source refusal")
	_assert_stopped_prefix(4, before)
	var o: Retirement.Owners = _session._retirement_owners
	assert_equal(_host.inventory()._spatial_authority.get_ref(), o.inventory_locations, "original bound adapter retained")
	assert_false(_host.reset(), "changed original source refuses")
	_session._profiles._live.header[0] -= 1
	_assert_prefix_reset(4)


func _change_host_gear_alias() -> void:
	"""The original Session remains internally coherent while a callback changes only the mounted host alias."""
	_original_gear = _host._gear
	_host._gear = Gear.new()


func test_final_host_tuple_mismatch_stops_newly_bound_composition() -> void:
	"""The host's post-observer mount leaf must stop a completed constructor before reporting its mismatch."""
	_observed_host()
	(_host.inventory() as ObservedInventory).observer = _change_host_gear_alias
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "late mounted host alias changed")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_HOST_OWNER", "host original tuple leaf")
	_assert_stopped_prefix(4, before)
	assert_false(_host.reset(), "foreign host alias cannot authorize release")
	assert_equal(_snapshot(), before, "no clear with wrong mounted tuple")
	_host._gear = _original_gear
	_original_gear = null
	_assert_prefix_reset(4)


func _change_cached_consumer_source() -> void:
	"""Change cached text without reloading or altering the on-disk consumer, as an explicit negative proof."""
	_source_script = ResourceLoader.get_cached_ref(Session.Catalog.Pins.PATHS[0]) as Script
	_source_text = _source_script.source_code
	_source_script.source_code = _source_text + "\n# test-only late constructor source drift\n"


func test_final_cached_consumer_drift_cannot_publish_ready_owner_state() -> void:
	"""All real constructors can finish, but actual current cached-source proof still precedes readiness."""
	_observed_host()
	(_host.inventory() as ObservedInventory).observer = _change_cached_consumer_source
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "late exact cached source changed")
	assert_equal(_host.last_refusal(), &"MOLE_CATALOG_SOURCE_DRIFT", "source guard remains strict")
	_assert_stopped_prefix(4, before)
	assert_false(_host.reset(), "changed runtime proof cannot release original source")
	_source_script.source_code = _source_text
	_source_script = null
	_source_text = ""
	_assert_prefix_reset(4)


func test_complete_composition_refuses_equal_value_foreign_catalog_owner() -> void:
	"""Standalone catalog construction stays compatible, but its separate facts cannot replace mounted identity."""
	assert_true(_host.compose_underground_room_owners(), "compose with borrowed facts")
	var o: Retirement.Owners = _session._retirement_owners
	var standalone: Composition.RoomCatalog = Composition.RoomCatalog.new()
	assert_true(standalone._definitions != o.buildings._definitions, "no-argument behavior still owns facts")
	assert_equal(standalone.allowed_types_mask(2), o.rooms._catalog.allowed_types_mask(2), "unchanged purpose semantics")
	o.rooms._catalog._definitions = standalone._definitions
	assert_equal(Composition.complete_refusal(o), &"UNDERGROUND_COMPOSITION_CATALOG", "equal data is a foreign owner")
	assert_false(_host.compose_underground_room_owners(), "idempotent observation refuses changed facts")
	o.rooms._catalog._definitions = o.buildings._definitions
	assert_true(_host.compose_underground_room_owners(), "restore this test's original identity")


func test_failed_room_prefix_refuses_foreign_fact_owner_before_clear() -> void:
	"""A partial Room mount must preserve the same immutable catalog during capture and final release."""
	_observed_host()
	(_host.buildings() as ObservedBuildings).deny_installed_once = true
	assert_false(_host.compose_underground_room_owners(), "retain real prefix three")
	var o: Retirement.Owners = _session._retirement_owners
	var standalone: Composition.RoomCatalog = Composition.RoomCatalog.new()
	var before: PackedStringArray = _snapshot()
	o.rooms._catalog._definitions = standalone._definitions
	assert_false(_host.prepare_world_reset(), "foreign definitions refuse before Scope")
	assert_equal(_session._retirement_scope, null, "no Scope published")
	assert_equal(_snapshot(), before, "no canonical owner cleared")
	o.rooms._catalog._definitions = o.buildings._definitions
	_assert_prefix_reset(3)


func _remove_original_definitions() -> void:
	"""A negative final pre-constructor observation cannot trigger the standalone catalog allocation fallback."""
	_original_definitions = _host.buildings()._definitions
	_host.buildings()._definitions = null


func test_null_original_facts_refuse_before_default_catalog_allocation() -> void:
	"""The current argument is rechecked after observers, so null never selects the optional standalone allocator."""
	var world: ObservedWorld = _observed_host()
	world.prefix = 2
	world.observer = _remove_original_definitions
	var before: PackedStringArray = _snapshot()
	assert_false(_host.compose_underground_room_owners(), "late original catalog missing")
	assert_false(world.observer.is_valid(), "actual pre-room observer executed")
	assert_equal(_host.last_refusal(), &"UNDERGROUND_COMPOSITION_CATALOG", "no default constructor fallback")
	_assert_stopped_prefix(2, before)
	assert_equal(_session._retirement_owners.rooms, null, "no RoomOrders/catalog retained")
	_host.buildings()._definitions = _original_definitions
	_original_definitions = null
	_assert_prefix_reset(2)
