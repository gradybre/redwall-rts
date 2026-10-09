extends "res://test/framework/test_case.gd"
## Entry lifecycle only. The inherited source/physical fixtures are explicitly synthetic and grant no demo permission.

const DeliveryTests := preload("res://test/test_underground_connector_delivery.gd")
const Retirement := preload("res://scripts/core/underground_world_retirement.gd")
const Entry := preload("res://scripts/core/underground_entry_bindings.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const Assemblies := preload("res://scripts/core/underground_connector_assemblies.gd")
const Recipes := preload("res://scripts/core/underground_connector_recipes.gd")
const Host := preload("res://scripts/systems/settlement_system.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _fixture: DeliveryTests = null
var _original: Retirement.Owners = null
var _persistent_id: int = 0
var _kernel_host: Host = null
var _scope: Retirement.Scope = null
var _session_identity: RefCounted = null


func before_each() -> void:
	"""Reuse actual complete paid owners and finite source readers, without bypassing any lifetime binding."""
	_fixture = DeliveryTests.new()
	_fixture.before_each()
	assert_true(_fixture.failures.is_empty(), "actual fixture setup: %s" % _fixture.failures)
	_original = _original_packet()
	_persistent_id = _original.directory._persistent_id[_original.world_ref.x]
	assert_equal(_original.room_bindings.configure_room_approach(_original.world_routes), &"", "actual graph observer")
	assert_equal(_new_owner_refusal(), &"", "all three original leaves")


func after_each() -> void:
	"""Only this component fixture owns these objects; normal production cleanup belongs to the captured Host."""
	_scope = null
	_session_identity = null
	if _kernel_host != null: _kernel_host.free()
	_kernel_host = null
	_original = null
	_drop_fixture()


func _drop_fixture() -> void:
	"""Aggregate every nested assertion, then release all test-owned actual source and store references."""
	if _fixture == null: return
	_fixture.after_each()
	assertions += _fixture.assertions
	failures.append_array(_fixture.failures)
	_fixture = null


func _original_packet() -> Retirement.Owners:
	"""Copy the exact concrete identities; this fixture is not a production Session registration."""
	var out: Retirement.Owners = Retirement.Owners.new()
	var world: DeliveryTests.Prefix.ActualWorld = _fixture._fixture._world
	out.world = world._world; out.world_ref = world._world_ref; out.directory = world._residents._directory
	out.buildings = world._buildings; out.construction = world._construction; out.inventory = world._inventory
	out.items = world._items; out.residents = world._residents; out.jobs = world._jobs; out.work = world._work
	out.reservations = world._pool; out.transforms = world._transforms; out.gear = world._gear
	out.carry = world._carry; out.piles = world._piles; out.budget = world._budget; out.space = world._owner
	out.sources = world._sources; out.routes = world._routes; out.terrain = world._terrain
	out.profiles = world._profiles; out.levels = world._levels; out.locations = world._locations
	out.world_routes = world._binding
	out.content = RefCounted.new() # Identity-only fixture. Production Session owns the actual immutable image.
	_copy_operational(out)
	return out


func _copy_operational(out: Retirement.Owners) -> void:
	"""The retained operation graph includes both existing complete Workpiece activation links."""
	out.rooms = _fixture._fixture._orders
	out.room_bindings = _fixture._fixture._bindings
	out.world_bindings = _fixture._fixture._provider
	out.sites = _fixture._fixture._sites
	out.router = _fixture._fixture._router
	out.authority = _fixture._fixture._authority
	out.inventory_locations = _fixture._fixture._storage_binding
	out.surface_anchor = _fixture._fixture._anchor
	out.connector = _fixture._fixture._paid
	out.contacts = _fixture._fixture._contacts
	out.placements = _fixture._fixture._placements
	out.workpieces = _fixture._pieces
	out.delivery = _fixture._delivery


func _new_owner_refusal() -> StringName:
	"""Complete source/reciprocal preflight happens before any individual owner releases its own links."""
	var code: StringName = Delivery.retirement_refusal_in(_original.delivery, _original)
	if code == &"": code = Entry.retirement_refusal_in(_original.room_bindings, _original)
	if code == &"": code = Placements.retirement_refusal_in(_original.placements, _original)
	return code


func _clear_original_stores() -> void:
	"""Real canonical clearing supplies no permission until every original release preflight succeeds."""
	_original.residents.clear()
	_original.jobs.clear()
	_original.work.clear()
	_original.gear.clear()
	_original.reservations.clear()
	_original.inventory.clear()
	assert_true(_original.items.load_default(_original.inventory).ok, "same actual definitions reload")
	_original.buildings.clear()
	_original.construction.clear()
	_original.world.clear()


func _release_three() -> StringName:
	"""Use the required complete core empty preflight; the production kernel will also include the other owner leaves."""
	var code: StringName = _new_owner_refusal()
	if code == &"": code = Retirement._leaves(_original, _persistent_id, _original.work._delivery_script, true)
	if code != &"": return code
	code = Delivery.world_retirement_release_preflighted_in(_original.delivery, _original, _persistent_id)
	if code == &"": code = Entry.world_retirement_release_preflighted_in(_original.room_bindings, _original, _persistent_id)
	if code == &"": code = Placements.world_retirement_release_preflighted_in(_original.placements, _original, _persistent_id)
	return code


func test_live_or_partial_clear_preserves_original_owner_links_and_buffers() -> void:
	"""All preflights precede the first write, including a World clear that leaves real Inventory populated."""
	var placement_bytes: int = _original.placements._live.i32.size()
	var entry_bytes: int = _original.room_bindings._entry_row.size()
	assert_true(_release_three() != &"", "live original World refuses")
	_original.world.clear()
	assert_true(_original.inventory._l_live_count > 0, "partial clear still owns actual goods")
	assert_true(_release_three() != &"", "canonical core clear incomplete")
	assert_equal(_original.delivery._work, _original.work, "delivery link retained")
	assert_equal(_original.room_bindings._entry_placements, _original.placements, "entry link retained")
	assert_equal(_original.placements._live.i32.size(), placement_bytes, "Placement image retained")
	assert_equal(_original.room_bindings._entry_row.size(), entry_bytes, "Entry scratch retained")
	_clear_original_stores()
	assert_equal(_release_three(), &"", "same actual original releases after complete clear")


func test_active_brackets_and_wrong_original_refuse_before_any_release() -> void:
	"""A coincident replacement or escaped operation cannot select another lifetime to retire."""
	_original.room_bindings._entry_busy = true
	assert_true(_new_owner_refusal() != &"", "entry observation active")
	_original.room_bindings._entry_busy = false
	_original.placements._cold_token = 7
	assert_true(_new_owner_refusal() != &"", "Placement cold window active")
	_original.placements._cold_token = 0
	_original.delivery._work_tick = true
	assert_true(_new_owner_refusal() != &"", "actual Work frame active")
	_original.delivery._work_tick = false
	var old: Vector2i = _original.world_ref
	_original.world_ref = Vector2i(old.x, old.y + 1)
	assert_true(_new_owner_refusal() != &"", "full World generation differs")
	_original.world_ref = old
	_clear_original_stores()
	assert_true(Delivery.world_retirement_release_preflighted_in(_original.delivery, _original, 0) != &"", "uncaptured PID refuses")
	assert_equal(_original.delivery._work, _original.work, "PID refusal preserves owned links")
	assert_equal(_release_three(), &"", "original complete scope releases")


func test_stale_handles_cannot_rebind_or_keep_old_heavy_owners_alive() -> void:
	"""Keep all three external old handles while their actual former World/graph/source owners become collectible."""
	var entry: Entry = _original.room_bindings as Entry
	var placements: Placements = _original.placements
	var delivery: Delivery = _original.delivery
	var space: WeakRef = weakref(_original.space)
	var world: WeakRef = weakref(_original.world)
	var profiles: WeakRef = weakref(_original.profiles)
	_clear_original_stores()
	assert_equal(_release_three(), &"", "actual complete original retired")
	assert_equal(placements._live.i32.size() + placements._stage.i32.size(), 0, "both large Placement images released")
	assert_equal(entry._entry_row.size() + delivery._frame.size(), 0, "all small caller arrays released")
	assert_true(placements.configure(4, 8, Placements.required_bytes(4, 8)) != &"", "Placement cannot reconfigure")
	assert_true(placements.bind_actual(_original.space, _original.locations, _original.routes, _original.budget,
		_original.world_routes._catalog, null, null, _original.construction) != &"", "old World tombstone refuses bind")
	assert_true(entry.bind_entry(_fixture._fixture._source, placements) != &"", "Entry tombstone refuses bind")
	assert_true(delivery.configure(placements, _fixture._fixture._source, _fixture._planner,
		_original.world_routes, _original.work, _fixture._clock, Delivery.RESERVED_BYTES) != &"", "Delivery cannot bind again")
	assert_true(_release_three() != &"", "second release refuses")
	_original = null
	_drop_fixture()
	assert_equal(space.get_ref(), null, "old sparse arena collected despite three old handles")
	assert_equal(world.get_ref(), null, "old actual World collected")
	assert_equal(profiles.get_ref(), null, "old immutable Profile banks collected")


func _kernel_setup() -> void:
	"""Exercise the real kernel with exact fixture owners; this does not claim a mounted production Session."""
	_kernel_host = Host.new()
	_kernel_host._haul_planner = _fixture._planner
	_kernel_host._store_policy = _fixture._planner._store_policy
	_kernel_host._commands._clock = _fixture._clock
	_scope = Retirement.Scope.new()
	_session_identity = RefCounted.new()


func test_complete_kernel_releases_every_original_owner_after_full_clear() -> void:
	"""All three peer leaves and the original core leaves participate in the same captured release tail."""
	_kernel_setup()
	assert_equal(Retirement._owners_refusal(_original), &"", "whole original peer graph")
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "capture whole original")
	assert_true(Retirement.release_preflighted(_scope, _kernel_host, _session_identity) != &"", "no live World release")
	assert_equal(_original.workpieces._placements, _original.placements, "refusal preserves Workpieces")
	_clear_original_stores()
	assert_equal(Retirement.cleared_refusal(_scope, _kernel_host, _session_identity), &"", "all leaves empty first")
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "complete observer-free release")
	assert_equal(_scope._stage, 2, "single-use Scope consumed")
	assert_equal(_original.contacts._placements, null, "Contacts drops its own heavy peer")
	assert_equal(_original.connector._placements, null, "CW drops its own heavy peer")
	assert_equal(_original.workpieces._capacity, 0, "Workpieces tombstone")
	assert_equal(_original.work._spatial_delivery, null, "actual Work weak authority released")
	assert_equal(_original.buildings._spatial_authority, null, "actual Room authority released")
	assert_true(Retirement.release_preflighted(_scope, _kernel_host, _session_identity) != &"", "Scope never repeats")


func test_kernel_rechecks_context_and_original_planner_after_prepare() -> void:
	"""Permanent identity links may exist, but an active token or substituted Host source never authorizes clear."""
	_kernel_setup()
	_original.placements._context.route_token = 7
	assert_true(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope) != &"", "live install context")
	assert_equal(_scope._stage, 0, "refusal leaves output unused")
	_original.placements._context.route_token = 0
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "original context idle")
	_kernel_host._haul_planner = null
	assert_true(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope) != &"", "post-capture Planner changed")
	_kernel_host._haul_planner = _fixture._planner
	_clear_original_stores()
	_kernel_host._commands._clock = Host.SimClockScript.new()
	assert_true(Retirement.release_preflighted(_scope, _kernel_host, _session_identity) != &"", "post-clear clock changed")
	assert_equal(_original.contacts._placements, _original.placements, "every owner preserved on refusal")
	_kernel_host._commands._clock = _fixture._clock
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "same clock completes captured release")


func test_all_stale_entry_handles_release_heavy_graph_after_kernel_tail() -> void:
	"""Keep all eight public old handles while retired Space and immutable source banks become collectible."""
	_kernel_setup()
	var old: Array[RefCounted] = [_original.delivery, _original.workpieces, _original.contacts,
		_original.connector, _original.room_bindings, _original.placements,
		_original.placements.assemblies_owner(), _original.placements.recipes_owner()]
	var space: WeakRef = weakref(_original.space)
	var profiles: WeakRef = weakref(_original.profiles)
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "original Scope")
	_clear_original_stores()
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "all entry and core owners")
	_scope = null
	_original = null
	_drop_fixture()
	_kernel_host._haul_planner = null
	_kernel_host._store_policy = null
	assert_equal(space.get_ref(), null, "old sparse arenas collected with all stale entry handles retained")
	assert_equal(profiles.get_ref(), null, "old source banks collected with all stale entry handles retained")
	assert_equal(old.size(), 8, "all public stale handles remain alive")


func test_kernel_partial_clear_preserves_every_owner_until_original_stores_empty() -> void:
	"""Retiring Directory identity alone cannot release the retained graph while real stock still exists."""
	_kernel_setup()
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "original Scope")
	_original.world.clear()
	assert_true(_original.inventory._l_live_count > 0, "real goods survive this incomplete clear")
	assert_true(Retirement.release_preflighted(_scope, _kernel_host, _session_identity) != &"", "complete core preflight refuses")
	assert_equal(_original.delivery._work, _original.work, "Delivery retained")
	assert_equal(_original.workpieces._placements, _original.placements, "Workpieces retained")
	assert_equal(_original.contacts._placements, _original.placements, "Contacts retained")
	assert_equal(_original.connector._placements, _original.placements, "CW retained")
	assert_equal(_original.room_bindings._entry_placements, _original.placements, "Entry retained")
	assert_equal(_original.placements._space, _original.space, "Placement retained")
	assert_equal(_scope._stage, 1, "same prepared Scope retained")
	_clear_original_stores()
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "same Scope completes later")


func test_phase_metadata_is_not_a_lease_but_original_context_identity_is_required() -> void:
	"""Contacts may retain a discarded numeric token; actual Budget and all permanent context links must still match."""
	_kernel_setup()
	_original.contacts._phase_cold_token = 97
	assert_equal(Retirement._owners_refusal(_original), &"", "stale unowned metadata is not an active lease")
	var context: Retirement.Locations.PhaseContext = _original.locations._phase_context
	_original.locations._phase_context = Retirement.Locations.PhaseContext.new()
	assert_true(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope) != &"", "different empty context refuses")
	_original.locations._phase_context = context
	context.space_token = 3
	assert_true(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope) != &"", "actual live phase token refuses")
	context.space_token = 0
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "exact idle phase identity")
	_clear_original_stores()
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "full peer release retains metadata distinction")


func test_source_reader_preflights_require_complete_idle_original_sources() -> void:
	"""No busy, unloaded, wrong-sized or same-value foreign source is a retirement candidate."""
	var groups: Assemblies = _original.placements.assemblies_owner()
	var recipes: Recipes = _original.placements.recipes_owner()
	assert_equal(Assemblies.retirement_refusal_in(groups, _original), &"", "original partition")
	assert_equal(Recipes.retirement_refusal_in(recipes, _original), &"", "original bills")
	assert_true(Assemblies.retirement_refusal_in(Assemblies.new(), _original) != &"", "foreign partition")
	assert_true(Recipes.retirement_refusal_in(Recipes.new(), _original) != &"", "foreign bills")
	groups._busy = true
	assert_true(Assemblies.retirement_refusal_in(groups, _original) != &"", "partition observer active")
	groups._busy = false
	recipes._loaded = false
	assert_true(Recipes.retirement_refusal_in(recipes, _original) != &"", "unloaded is not an incomplete prefix")
	recipes._loaded = true
	recipes._part.resize(8)
	assert_true(Recipes.retirement_refusal_in(recipes, _original) != &"", "scratch shape changed")
	recipes._part.resize(9)
	groups._digests[0] ^= 1
	assert_true(Assemblies.retirement_refusal_in(groups, _original) != &"", "partition source changed")
	groups._digests[0] ^= 1
	recipes._digests[0] ^= 1
	assert_true(Recipes.retirement_refusal_in(recipes, _original) != &"", "bill source changed")
	recipes._digests[0] ^= 1
	assert_equal(Assemblies.retirement_refusal_in(groups, _original), &"", "original partition restored")
	assert_equal(Recipes.retirement_refusal_in(recipes, _original), &"", "original bill restored")


func test_source_reader_release_refuses_live_world_without_dropping_any_data() -> void:
	"""Even exact original immutable readers cannot release before the canonical World clear."""
	var groups: Assemblies = _original.placements.assemblies_owner()
	var recipes: Recipes = _original.placements.recipes_owner()
	var group_bytes: int = groups.packed_memory_bytes()
	var recipe_bytes: int = recipes.packed_memory_bytes()
	assert_true(Assemblies.world_retirement_release_preflighted_in(groups, _original, _persistent_id) != &"", "live partition")
	assert_true(Recipes.world_retirement_release_preflighted_in(recipes, _original, _persistent_id) != &"", "live bills")
	assert_equal(groups._catalog, _original.world_routes._catalog, "partition still retains original source")
	assert_equal(recipes._inventory, _original.inventory, "bill still retains original inventory")
	assert_equal(groups.packed_memory_bytes(), group_bytes, "partition payload unchanged")
	assert_equal(recipes.packed_memory_bytes(), recipe_bytes, "bill payload unchanged")
	_clear_original_stores()
	assert_true(Assemblies.world_retirement_release_preflighted_in(groups, _original, 0) != &"", "uncaptured original identity")
	assert_equal(groups.packed_memory_bytes(), group_bytes, "identity refusal leaves source intact")


func test_source_reader_tombstones_refuse_reuse_and_preserve_caller_outputs() -> void:
	"""Placement releases both exported readers before dropping its source links; neither can be revived."""
	var groups: Assemblies = _original.placements.assemblies_owner()
	var recipes: Recipes = _original.placements.recipes_owner()
	var catalog: Placements.Catalog = _original.world_routes._catalog
	var output: PackedByteArray = PackedByteArray()
	output.resize(32)
	output.fill(97)
	_clear_original_stores()
	assert_equal(_release_three(), &"", "complete original source release")
	assert_equal(groups.packed_memory_bytes() + recipes.packed_memory_bytes(), 0, "source banks and scratch released")
	assert_equal(groups._catalog, null, "partition drops Catalog")
	assert_equal(groups._recipes, null, "partition drops Recipe")
	assert_equal(recipes._catalog, null, "bill drops Catalog")
	assert_true(groups.configure(2, Assemblies.required_bytes(2)) != &"", "partition configure is one-way")
	assert_true(recipes.configure(2, Recipes.required_bytes(2)) != &"", "bill configure is one-way")
	assert_true(groups.bind_actual(catalog, recipes, _original.items, _original.inventory) != &"", "partition rebind refuses")
	assert_true(recipes.bind_actual(catalog, _original.items, _original.inventory) != &"", "bill rebind refuses")
	assert_true(groups.load_file("", "", 1, "", 1) != &"", "partition load refuses before file access")
	assert_true(recipes.load_file("", "", 1, "", 1) != &"", "bill load refuses before file access")
	assert_false(groups.content_hash_into(1, output), "partition query refuses")
	assert_false(recipes.content_hash_into(1, output), "bill query refuses")
	assert_equal(output.count(97), 32, "refusals preserve entire output")
	assert_equal(groups.content_revision() + recipes.content_revision(), 0, "retired metadata is not a usable source")


func test_late_source_busy_refuses_kernel_before_the_first_owner_release() -> void:
	"""Source readers participate in the complete pre-clear and final kernel preflights."""
	_kernel_setup()
	var recipes: Recipes = _original.placements.recipes_owner()
	var groups: Assemblies = _original.placements.assemblies_owner()
	recipes._busy = true
	assert_true(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope) != &"", "pre-clear bill observer")
	recipes._busy = false
	assert_equal(Retirement.prepare_into(_kernel_host, _session_identity, _original, _scope), &"", "same idle original")
	_clear_original_stores()
	groups._busy = true
	assert_true(Retirement.release_preflighted(_scope, _kernel_host, _session_identity) != &"", "late partition observer")
	assert_equal(_original.delivery._work, _original.work, "first owner was not released")
	assert_equal(recipes._catalog, _original.world_routes._catalog, "source data remains intact")
	groups._busy = false
	assert_equal(Retirement.release_preflighted(_scope, _kernel_host, _session_identity), &"", "original idle retry")
