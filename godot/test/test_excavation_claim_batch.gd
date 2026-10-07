extends "res://test/framework/test_case.gd"
## Actual Room/Directory/Sites/cold owners. Only prospective terrain/contact feasibility is synthetic.

const Sites := preload("res://scripts/core/excavation_sites.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const OrdersFixture := preload("res://test/test_underground_room_orders.gd")
const FixtureScript := preload("res://test/test_underground_furniture_work.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class WatchedOrders extends FixtureScript.SyntheticRegistration:
	## Faults run after the real batch's complete proof, immediately before production final guard.
	var fault: int = 0
	var saved: Sites.RoomClaimBatch = null
	var external_history: PackedByteArray = PackedByteArray()
	var replacement: int = 0
	var reject_foreign_budget: bool = false
	var foreign_refusal: StringName = &""
	var foreign_copy_bytes: int = -1
	var private_bytes: int = 0
	var direct_refusal: StringName = &""
	var premature_kernel_refusal: StringName = &""
	var scope_calls: int = 0
	var scopes_at_commit: int = 0

	func room_claim_scope_refusal(candidate: Sites.Directory.CreateCandidate, room_type: int,
			budget: Budget, token: int) -> StringName:
		"""Count only preparation scope calls; none is allowed between final guard and physical publication."""
		scope_calls += 1
		return super.room_claim_scope_refusal(candidate, room_type, budget, token)

	func _prepare_room_claims() -> StringName:
		"""Observe the real private packet, then inject an adversarial final-boundary owner mutation."""
		if reject_foreign_budget:
			_probe_foreign_budget()
		if fault == 6:
			var shifted: Space.Domain = Space.Domain.new()
			assert(shifted.configure(_world, Vector3i(1, -8192, 0), Vector3i.ZERO,
				Vector3i(16, 16, 16), Space.MAX_CELLS, 256, Space.MAX_CHECKS) == &"", "valid foreign key namespace")
			_room_domain = shifted
		var code: StringName = super._prepare_room_claims()
		if code != &"":
			return code
		saved = _room_claim_batch
		private_bytes = saved._cells.size() * 4 + saved._cursor._intervals.size() * 8 + saved._room_facts.size() * 4
		direct_refusal = _room_sites.publish_room_claim_batch(saved)
		premature_kernel_refusal = Sites.publish_room_claim_preflighted(_room_sites, saved, self)
		scopes_at_commit = scope_calls
		_inject_fault()
		return code

	func _inject_fault() -> void:
		"""External committed changes must survive refusal; this test never restores owner generations."""
		if fault == 1:
			assert(_room_sites.claim_quantum(Vector3i(14336, -4096, 14336), PhysicalFixture.ROOM).ok, "real late claim")
			external_history = _room_sites.state_bytes()
		elif fault == 2:
			_room_candidate.persistent_id += 1
		elif fault == 3:
			assert(_room_budget.release(_room_cold_token) == &"", "actual admitted token released")
			replacement = _room_budget.acquire(Budget.COLD_BYTES)
		elif fault == 4:
			_room_claim_input.cells[0] += 1
		elif fault == 5:
			_room_claim_input.height_u += 1

	func _probe_foreign_budget() -> void:
		"""A valid second arena with token1 must refuse before its private cell/cursor allocation."""
		var foreign: Budget = Budget.new()
		var token: int = foreign.acquire(Budget.COLD_BYTES)
		var request: Sites.RoomClaimInput = Sites.RoomClaimInput.new()
		request.world = _world
		request.room_type = _room_plan.room_type
		request.level = _room_plan.level
		request.space_revision = _room_plan.space_revision
		request.origin_u = _room_plan.origin_u
		request.cell_size_u = _room_plan.cell_size_u
		request.height_u = _room_plan.height_u
		request.cells = _room_plan.cells
		var batch: Sites.RoomClaimBatch = Sites.RoomClaimBatch.new()
		var actual: Sites = _construction.excavation_authority() as Sites
		foreign_refusal = actual.prepare_room_claim_batch_into(request, _room_candidate,
			self, _room_domain, foreign, token, batch)
		foreign_copy_bytes = batch._cells.size() * 4
		assert(foreign.release(token) == &"", "foreign arena remains independently owned")

class Fixture extends FixtureScript.Fixture:
	func _configure_space() -> void:
		"""Same actual physical Domain, with a finite larger draft/region budget for the unchanged16384-cell limit."""
		orders = WatchedOrders.new()
		sources = Owner.CoreSources.new(buildings.directory(), buildings, construction)
		space = FixtureScript.WatchedSpace.new(sources)
		var domain: Space.Domain = Space.Domain.new()
		check(domain.configure(world, Vector3i(0, -8192, 0), Vector3i.ZERO, Vector3i(16, 16, 16),
			Space.MAX_CELLS, 256, Space.MAX_CHECKS) == &"", "exact finite Domain")
		check(space.configure(domain, 256, 64) == &"", "actual sparse capacity")
		bindings.construction = construction
		bindings.space = space
		bindings.world = world
		bindings.inventory = inventory
		bindings.orders = weakref(orders)

var _f: Fixture = null
var _bindings: OrdersFixture.RoomBindings = null
var _orders: WatchedOrders = null


func before_each() -> void:
	"""Reuse actual accounting, identities, catalogue and Space; permission fixture is explicit."""
	_bindings = OrdersFixture.RoomBindings.new()
	_f = Fixture.new(self, false, _bindings)
	_orders = _f.orders as WatchedOrders


func after_each() -> void:
	"""Every refusal and completed publication must drop the private copies before lease release."""
	_f.audit()
	assert_false(_bindings.room_cold_held, "no escaped Room lease")
	assert_null(_f.sites._current_claim_batch(), "no escaped physical reservation packet")
	assert_equal(_bindings.room_begins, _bindings.room_ends, "balanced cold scope")
	_orders = null
	_f = null
	_bindings = null


func _plan(cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])) -> Orders.RoomPlan:
	"""Fine concave shape shares one whole cube, but retains its exact future marker outline."""
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.world = _f.world
	plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	plan.level = 0
	plan.space_revision = _f.space.revision()
	plan.origin_u = Vector3i(512, -4096, 1024)
	plan.cell_size_u = 256
	plan.height_u = 896
	plan.cells = cells.duplicate()
	return plan


func _image() -> PackedByteArray:
	"""Actual Directory, economic and physical snapshots make partial reservations visible."""
	var out: PackedByteArray = _f.residents.directory().state_bytes()
	out.append_array(_f.image())
	out.append_array(_f.sites.state_bytes())
	for property: Dictionary in _f.buildings.get_property_list():
		var field: Variant = _f.buildings.get(property["name"])
		if field is PackedByteArray:
			out.append_array(field)
		elif field is PackedInt32Array or field is PackedInt64Array:
			out.append_array(field.to_byte_array())
	return out


func test_exact_fine_plan_reserves_once_before_spatial_publication_without_payment() -> void:
	"""Reserved SOLID is real paid-history capacity, never completed excavation, support, work or yield."""
	var before_goods: PackedByteArray = _f.inventory.state_bytes()
	var room: Buildings.OpResult = _orders.confirm_room(_plan())
	assert_true(room.ok, "actual confirmation: %s" % room.error)
	assert_equal(_orders.saved.count(), 1, "fine union contains one distinct physical cube")
	assert_equal(_f.sites.remaining_history_capacity(), 63, "one permanent key spent once")
	var site: Vector2i = _f.sites.site_at(Vector3i(0, -4096, 1024))
	assert_true(_f.sites.phase_into(site, _f.math), "actual full Site exists")
	assert_equal(_f.math.value, Sites.SOLID, "no cut performed")
	assert_equal(Vector2i(_f.sites._room_slot[site.x], _f.sites._room_generation[site.x]), room.ref, "actual full Room owns claim")
	assert_equal(_f.sites.virgin_sourced_milli(), 0, "no geological output")
	assert_true(_f.inventory.state_bytes() == before_goods, "no material spent or generated")
	assert_equal(_orders.scope_calls, _orders.scopes_at_commit, "no external scope callback during publication")
	assert_true(_orders.direct_refusal != &"", "prepared packet cannot publish before actual Room")
	assert_equal(_orders.premature_kernel_refusal, Sites.REFUSE_CLAIM_BATCH, "direct static kernel cannot borrow preparation")
	var after: PackedByteArray = _image()
	assert_true(_f.sites.publish_room_claim_batch(_orders.saved) != &"", "duplicate/idle publication refused")
	assert_equal(Sites.publish_room_claim_preflighted(_f.sites, _orders.saved, _orders),
		Sites.REFUSE_CLAIM_BATCH, "already consumed static kernel refuses duplicate publication")
	assert_true(_image() == after, "duplicate refusal leaves every owner byte unchanged")


func test_last_callback_free_guard_rejects_late_history_without_rolling_it_back() -> void:
	"""The external insertion occurs after full batch preflight; a prior provider check cannot catch it."""
	var before_ids: PackedByteArray = _f.residents.directory().state_bytes()
	var before_space: PackedByteArray = _f.space.state_bytes()
	_orders.fault = 1
	assert_equal(_orders.confirm_room(_plan()).error, Sites.REFUSE_CLAIM_BATCH, "late physical key invalidates final proof")
	assert_true(_f.sites.state_bytes() == _orders.external_history, "only the external committed history remains")
	assert_true(_f.residents.directory().state_bytes() == before_ids, "no Room identity allocated")
	assert_true(_f.space.state_bytes() == before_space, "no marker/source published")
	assert_equal(_f.sites.site_at(Vector3i(0, -4096, 1024)), NULL_REF, "no partial room cut reservation")
	_orders.fault = 0
	assert_true(_orders.confirm_room(_plan()).ok, "fresh actual history observation retries safely")


func test_late_candidate_or_input_drift_refuses_all_owner_writes() -> void:
	"""Both exposed request scalars and the whole mutable candidate tuple are independently pinned."""
	for fault: int in [2, 4, 5]:
		var before: PackedByteArray = _image()
		_orders.fault = fault
		assert_false(_orders.confirm_room(_plan()).ok, "late identity/input mutation refuses")
		assert_true(_image() == before, "every authoritative byte remains unchanged")
	_orders.fault = 0
	assert_true(_orders.confirm_room(_plan()).ok, "clean retry follows discarded private packet")


func test_replaced_actual_lease_never_allocates_room_or_releases_the_replacement() -> void:
	"""Same actual arena with a newer token does not extend the old operation's lifetime."""
	var before: PackedByteArray = _image()
	_orders.fault = 3
	assert_equal(_orders.confirm_room(_plan()).error, Orders.REFUSE_ROOM_COLD, "last exact token refuses")
	assert_true(_image() == before, "replacement causes no live mutation")
	assert_true(_bindings.arena.covers(_orders.replacement, Budget.COLD_BYTES), "foreign replacement survives cleanup")
	assert_equal(_bindings.arena.release(_orders.replacement), &"", "replacement owner cleans up")


func test_foreign_valid_budget_with_coincident_token_refuses_before_copy() -> void:
	"""Actual Room authority must attest object identity, not merely a live token with enough bytes."""
	_orders.reject_foreign_budget = true
	assert_true(_orders.confirm_room(_plan()).ok, "real exact-scope preparation still succeeds")
	assert_equal(_orders.foreign_refusal, Orders.REFUSE_ROOM_COLD, "foreign token1 is not the actual Room arena")
	assert_equal(_orders.foreign_copy_bytes, 0, "no private input copied under another arena")


func test_retained_history_and_partial_capacity_cannot_create_room_or_virgin_claims() -> void:
	"""Already-known cubes stay known even without a Room claim; large requests cannot partly reserve capacity."""
	assert_true(_f.sites.claim_quantum(Vector3i(0, -4096, 1024), PhysicalFixture.ROOM).ok, "actual prior history")
	var before: PackedByteArray = _image()
	assert_equal(_orders.confirm_room(_plan()).error, Sites.REFUSE_CLAIM_HISTORY, "existing key cannot be a virgin batch")
	assert_true(_image() == before, "retained history refusal preserves all owners")
	var large: Orders.RoomPlan = _plan(PackedInt32Array([0, 0]))
	large.origin_u = Vector3i(0, -4096, 0)
	large.cell_size_u = 9216
	large.height_u = 1024
	assert_equal(_orders.confirm_room(large).error, Sites.REFUSE_SITE_CAPACITY, "81 unique keys exceed remaining63")
	assert_true(_image() == before, "capacity refusal has no partial room/site/source writes")


func test_sorted_index_merge_keeps_earlier_and_later_existing_histories_exact() -> void:
	"""Publication merges the new sorted suffix backward; old Site refs never move or recycle."""
	var low: Vector2i = _f.sites.claim_quantum(Vector3i(0, -8192, 0), PhysicalFixture.ROOM).ref
	var high: Vector2i = _f.sites.claim_quantum(Vector3i(15360, 7168, 15360), PhysicalFixture.ROOM).ref
	assert_true(_orders.confirm_room(_plan()).ok, "middle key fits between real old keys")
	assert_equal(_f.sites.site_at(Vector3i(0, -8192, 0)), low, "low full Site unchanged")
	assert_equal(_f.sites.site_at(Vector3i(15360, 7168, 15360)), high, "high full Site unchanged")
	assert_equal(_f.sites._ordered_row.slice(0, 3), PackedInt32Array([0, 2, 1]), "index orders keys without reordering history rows")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "all three permanent rows retained")


func test_domain_comparison_requires_full_live_world_datum_and_bounds() -> void:
	"""A matching World number is insufficient for a shifted physical key namespace."""
	var datum: Vector3i = Vector3i(0, -8192, 0)
	var size: Vector3i = Vector3i(16, 16, 16)
	assert_true(_f.sites.domain_matches(_f.world, datum, Vector3i.ZERO, size), "actual exact Domain")
	assert_false(_f.sites.domain_matches(_f.world, datum + Vector3i(1, 0, 0), Vector3i.ZERO, size), "shifted datum")
	assert_false(_f.sites.domain_matches(_f.world, datum, Vector3i(1, 0, 0), size), "shifted minimum")
	assert_false(_f.sites.domain_matches(_f.world, datum, Vector3i.ZERO, Vector3i(16, 15, 16)), "different bound")
	assert_false(_f.sites.domain_matches(Vector2i(_f.world.x, _f.world.y + 1), datum, Vector3i.ZERO, size), "wrong World generation")
	var before: PackedByteArray = _image()
	_orders.fault = 6
	assert_equal(_orders.confirm_room(_plan()).error, Sites.REFUSE_DOMAIN, "a valid shifted same-World Domain refuses actual batch")
	assert_true(_image() == before, "Domain mismatch cannot reserve any owner row")


func test_full_painted_limit_uses_one_private_copy_and_one_replayed_interval_bank() -> void:
	"""All16384 fine cells remain legal; no physical key list scales with emitted whole cubes."""
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in 128:
		for x: int in 128:
			cells.append(x)
			cells.append(z)
	var plan: Orders.RoomPlan = _plan(cells)
	plan.cell_size_u = 1
	plan.height_u = 1
	assert_true(_orders.confirm_room(plan).ok, "full existing fine-cell limit confirms in fixture")
	assert_equal(_orders.private_bytes, 16 * 16384 + 24, "one8N private image, one8N interval bank, six-I32 Room facts")
	assert_equal(_orders.saved.count(), 1, "full fine shape still touches only one physical quantum")
	assert_true(_orders.saved._cells.is_empty() and _orders.saved._cursor == null, "both packed lifetimes dropped before release")


func test_source_counted_companion_lifetimes_fit_only_in_the_documented_order() -> void:
	"""Maximum buffers are charged together only when their source lifetimes actually overlap."""
	var count: int = Space.MAX_CELLS
	var plans: int = 24 * count
	var snapshot: int = 48 * Budget.REGION_CAPACITY + 16 * Budget.SOURCE_CAPACITY
	var endpoints: int = snapshot + 24 * Budget.PHASE_VOLUME_CAPACITY + 384 + plans + 2048
	var routes: int = WorldRoutes.COLD_BYTES + plans + 2048
	assert_equal(endpoints, 919936, "actual region/source snapshot, endpoint fragments, three plans and controls")
	assert_equal(routes, 774912, "actual route proof (with ADR1205 staged changes 1792 at 64 journal entries, ADR1212) and three plans")
	assert_equal(Sites.room_claim_cold_bytes(count), 657408, "only sealed companions coexist with fourth copy and cursor")
	assert_true(endpoints <= Budget.COLD_BYTES and routes <= Budget.COLD_BYTES, "sequential companions fit")
	assert_true(endpoints + 8 * count > Budget.COLD_BYTES, "a retained interval bank during endpoints must refuse")
	assert_equal(Sites.room_claim_cold_bytes(count + 1), 0, "unbounded input never gets a byte admission")
