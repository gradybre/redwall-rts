extends "res://test/framework/test_case.gd"
## Actual Sites/Directory/Buildings publication. Prospective entry geometry/contact permission is synthetic.
## The typed claim seam uses actual EntryPlan publication; Terrain/frontier/Placement permission stays synthetic.

const ClaimTests := preload("res://test/test_excavation_claim_batch.gd")
const EntryFixture := preload("res://test/test_underground_entry_orders.gd")
const EntryPlan := preload("res://scripts/core/underground_entry_plan.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class ObservedDomain extends Space.Domain:
	var calls: int = 0
	var fault: int = 0
	var mutate_call: int = 2
	var budget: Budget = null
	var token: int = 0
	var replacement: int = 0

	func descriptor() -> Dictionary:
		"""A valid-looking second observation can change the quantum rank or revoke the admitted lease."""
		calls += 1
		var facts: Dictionary = super.descriptor()
		if calls == mutate_call and fault == 1:
			facts.datum_u.x += 1
			facts.bounds_u[0] += 1
			facts.bounds_u[3] += 1
		elif calls == mutate_call and fault == 2:
			assert(budget.release(token) == &"", "original lease revoked inside descriptor observer")
			replacement = budget.acquire(Budget.COLD_BYTES)
		return facts

class EntryOrders extends ClaimTests.WatchedOrders:
	var input_boxes: PackedInt32Array = PackedInt32Array()
	var entry_input: Sites.EntryClaimInput = null
	var scope_fault: int = 0
	var entry_fault: int = 0
	var shifted_domain: bool = false
	var attempted_private_bytes: int = -1
	var observed_domain: ObservedDomain = null
	var domain_fault: int = 0
	var domain_mutate_call: int = 2
	var use_flat_claims: bool = false

	func _prepare_room_claims() -> StringName:
		"""Exercise the actual typed entry batch inside the real future Corridor Room receipt window."""
		if domain_fault > 0:
			_replace_with_observed_domain()
		if use_flat_claims:
			return super._prepare_room_claims()
		return _prepare_entry_claims()

	func _prepare_entry_claims() -> StringName:
		"""Actual non-flat batch seam, with separate controlled external-observer failures."""
		_room_sites = _construction.excavation_authority() as Sites
		entry_input = Sites.EntryClaimInput.new()
		entry_input.world = _world
		entry_input.base_level = _entry_plan.base_level if _entry_mode else _room_plan.level
		entry_input.space_revision = _entry_plan.space_revision if _entry_mode else _room_plan.space_revision
		entry_input.boxes = input_boxes
		if _entry_mode:
			_entry_claim_input = entry_input
		_room_claim_batch = Sites.RoomClaimBatch.new()
		if reject_foreign_budget:
			_probe_foreign_entry_budget()
		if shifted_domain:
			_replace_domain()
		var code: StringName = _room_sites.prepare_entry_claim_batch_into(entry_input, _room_candidate,
			self, _room_domain, _room_budget, _room_cold_token, _room_claim_batch)
		attempted_private_bytes = _room_claim_batch._boxes.size() * 4
		if code != &"":
			return code
		saved = _room_claim_batch
		private_bytes = saved._boxes.size() * 4 + saved._entry_cursor._intervals.size() * 8 + saved._room_facts.size() * 4
		direct_refusal = _room_sites.publish_room_claim_batch(saved)
		scopes_at_commit = scope_calls
		_inject_entry_fault()
		return &""

	func room_claim_scope_refusal(candidate: Sites.Directory.CreateCandidate, room_type: int,
			budget: Budget, token: int) -> StringName:
		"""Mutate after the real actual-budget guard so the Sites post-observer check is necessary."""
		var code: StringName = super.room_claim_scope_refusal(candidate, room_type, budget, token)
		if code == &"" and entry_input != null and scope_fault == 1:
			entry_input.boxes.append(99)
		elif code == &"" and entry_input != null and scope_fault == 2:
			assert(budget.release(token) == &"", "original lease released during callback")
			replacement = budget.acquire(Budget.COLD_BYTES)
		return code

	func _inject_entry_fault() -> void:
		"""Late external changes survive a refused admission; no test resets generations or history."""
		if entry_fault == 1:
			assert(_room_sites.claim_quantum(Vector3i(14336, -4096, 14336), ClaimTests.PhysicalFixture.ROOM).ok, "late real history")
			external_history = _room_sites.state_bytes()
		elif entry_fault == 2:
			_room_candidate.persistent_id += 1
		elif entry_fault == 3:
			entry_input.base_level += 1
		elif entry_fault == 4:
			entry_input.boxes[2] += 256
		elif entry_fault == 5:
			entry_input.world.y += 1
		elif entry_fault == 6:
			entry_input.space_revision += 1
		elif entry_fault == 7:
			assert(_room_budget.release(_room_cold_token) == &"", "original lease released after preparation")
			replacement = _room_budget.acquire(Budget.COLD_BYTES)

	func _probe_foreign_entry_budget() -> void:
		"""An independent valid token1 cannot stand in for the actual RoomOrders arena."""
		var foreign: Budget = Budget.new()
		var token: int = foreign.acquire(Budget.COLD_BYTES)
		var batch: Sites.RoomClaimBatch = Sites.RoomClaimBatch.new()
		foreign_refusal = _room_sites.prepare_entry_claim_batch_into(entry_input, _room_candidate,
			self, _room_domain, foreign, token, batch)
		foreign_copy_bytes = batch._boxes.size() * 4
		assert(foreign.release(token) == &"", "foreign owner releases its own independent scope")

	func _replace_domain() -> void:
		"""Keep valid bounds/World but shift the actual physical namespace for a negative control."""
		var shifted: Space.Domain = Space.Domain.new()
		assert(shifted.configure(_world, Vector3i(1, -8192, 0), Vector3i.ZERO,
			Vector3i(16, 16, 16), Space.MAX_CELLS, 256, Space.MAX_CHECKS) == &"", "valid shifted domain")
		_room_domain = shifted

	func _replace_with_observed_domain() -> void:
		"""Insert the observer only at the claim boundary, after earlier actual coordinator geometry reads."""
		var facts: Dictionary = _room_domain.descriptor()
		observed_domain = ObservedDomain.new()
		assert(observed_domain.configure(facts.world_ref, facts.datum_u, facts.min_quantum,
			facts.size_quanta, facts.max_cells, facts.max_regions, facts.max_checks) == &"", "exact observed source")
		observed_domain.fault = domain_fault
		observed_domain.mutate_call = domain_mutate_call
		observed_domain.budget = _room_budget
		observed_domain.token = _room_cold_token
		_room_domain = observed_domain

class Fixture extends ClaimTests.Fixture:
	func _configure_space() -> void:
		"""Reuse real stores; replace only the synthetic entry coordinator before once-bound configuration."""
		super._configure_space()
		orders = EntryOrders.new()
		bindings.orders = weakref(orders)

var _f: Fixture = null
var _orders: EntryOrders = null
var _bindings: EntryFixture.EntryBindings = null


func before_each() -> void:
	"""Each case starts from actual independent accounting, World and physical-history owners."""
	_bindings = EntryFixture.EntryBindings.new()
	_f = Fixture.new(self, false, _bindings)
	_orders = _f.orders as EntryOrders
	_orders.input_boxes = PackedInt32Array([0, -4096, 0, 512, -3072, 512,
		256, -3840, 256, 1024, -2816, 1024, 1024, -3072, 1024, 1536, -2560, 1536])


func after_each() -> void:
	"""Every outcome drops the private cursor/images before the actual original lease ends."""
	_f.audit()
	assert_false(_bindings.room_cold_held, "no escaped Room lease")
	assert_null(_f.sites._current_claim_batch(), "no escaped physical claim observation")
	assert_equal(_bindings.room_begins, _bindings.room_ends, "balanced cold acquisition/release")
	_orders = null
	_f = null
	_bindings = null


func _plan() -> Orders.RoomPlan:
	"""Synthetic whole-Corridor geometry proof; the tested Sites input has independently varying heights."""
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.world = _f.world
	plan.room_type = Buildings.ROOM_TYPE_CORRIDOR
	plan.level = 0
	plan.space_revision = _f.space.revision()
	plan.origin_u = Vector3i(0, -4096, 0)
	plan.cell_size_u = 1024
	plan.height_u = 2048
	plan.cells = PackedInt32Array([0, 0, 1, 0, 1, 1])
	return plan


func _confirm(plan: Orders.RoomPlan) -> Buildings.OpResult:
	"""Entry tests now use the real non-flat coordinator; Kitchen refusal and the one flat control stay flat."""
	if _orders.use_flat_claims or plan.room_type != Buildings.ROOM_TYPE_CORRIDOR:
		return _orders.confirm_room(plan)
	var entry: EntryPlan.Request = EntryPlan.Request.new()
	entry.world = plan.world
	entry.space_revision = plan.space_revision
	entry.base_level = plan.level
	entry.origin_u = plan.origin_u
	entry.rotation = 0
	entry.anchor = Vector2i(0, 1)
	entry.catalog_row = 0
	entry.catalog_revision = 1
	entry.variant_revision = 1
	entry.grouping_revision = 1
	entry.recipe_revision = 1
	entry.frontier_revision = 1
	entry.source_digests.resize(EntryPlan.SOURCE_BYTES)
	entry.source_digests.fill(17)
	entry.claims = _orders.input_boxes
	entry.opening_targets = PackedInt32Array([-1, 0, -1, 0, -1, 0, -1, 0])
	return _orders.confirm_entry(entry)


func _image() -> PackedByteArray:
	"""Include actual directory, physical history, goods and all Buildings packed state."""
	var image: PackedByteArray = _f.residents.directory().state_bytes()
	image.append_array(_f.image())
	image.append_array(_f.sites.state_bytes())
	for property: Dictionary in _f.buildings.get_property_list():
		var value: Variant = _f.buildings.get(property["name"])
		if value is PackedByteArray:
			image.append_array(value)
		elif value is PackedInt32Array or value is PackedInt64Array:
			image.append_array(value.to_byte_array())
	return image


func test_entry_union_reserves_actual_unique_corridor_cuts_without_goods_or_void() -> void:
	"""Overlapping varying floors claim each whole cube once; no construction, labor or output is granted."""
	var goods: PackedByteArray = _f.inventory.state_bytes()
	var room: Buildings.OpResult = _confirm(_plan())
	assert_true(room.ok, "actual future Corridor allocation: %s" % room.error)
	assert_equal(_orders.saved.count(), 3, "three distinct paid-cube identities")
	assert_equal(_f.sites.remaining_history_capacity(), 61, "exact permanent rows reserved")
	for origin: Vector3i in [Vector3i(0, -4096, 0), Vector3i(0, -3072, 0), Vector3i(1024, -3072, 1024)]:
		var site: Vector2i = _f.sites.site_at(origin)
		assert_true(_f.sites.phase_into(site, _f.math), "actual whole quantum exists")
		assert_equal(_f.math.value, Sites.SOLID, "reserved, not excavated or finished")
		assert_equal(Vector2i(_f.sites._room_slot[site.x], _f.sites._room_generation[site.x]), room.ref, "full permanent Corridor owner")
	assert_equal(_f.sites.site_at(Vector3i(1024, -4096, 1024)), NULL_REF, "gap below higher pocket remains unclaimed")
	assert_equal(_f.sites.virgin_sourced_milli(), 0, "no spoil generated")
	assert_true(_f.inventory.state_bytes() == goods, "no material debit or output")
	assert_equal(_orders.private_bytes, 3 * 32 + 24, "one24B image,8B intervals and reused24 Room facts")
	assert_true(_orders.saved._boxes.is_empty() and _orders.saved._entry_cursor == null, "all private packed scratch released")
	assert_equal(_orders.scope_calls, _orders.scopes_at_commit, "no new external scope query during publication")


func test_prepared_or_already_published_entry_batch_cannot_publish_again() -> void:
	"""Exact same-stack Room receipt is required once; a complete cursor is not authority by itself."""
	assert_true(_confirm(_plan()).ok, "actual entry claim completion")
	assert_true(_orders.direct_refusal != &"", "publication before Room allocation refused")
	var before: PackedByteArray = _image()
	assert_true(_f.sites.publish_room_claim_batch(_orders.saved) != &"", "repeated/idle publication refused")
	assert_true(_image() == before, "refusal does not duplicate claims")


func test_entry_claims_require_permanent_corridor_purpose() -> void:
	"""A typed entry batch cannot silently become a Kitchen or reclassify a confirmed room."""
	var plan: Orders.RoomPlan = _plan()
	plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	var before: PackedByteArray = _image()
	assert_false(_confirm(plan).ok, "actual Room scope refuses non-Corridor future purpose")
	assert_true(_image() == before, "no identity, claims or goods changed")
	assert_equal(_orders.attempted_private_bytes, 0, "purpose refusal precedes private input allocation")


func test_every_late_entry_request_or_candidate_change_refuses_all_writes() -> void:
	"""Pins cover World generation, level, space revision, box bytes and the full future Directory tuple."""
	for fault: int in [2, 3, 4, 5, 6]:
		_orders.entry_fault = fault
		var before: PackedByteArray = _image()
		assert_false(_confirm(_plan()).ok, "late input/candidate mutation refused")
		assert_true(_image() == before, "all authoritative bytes unchanged")
	_orders.entry_fault = 0
	assert_true(_confirm(_plan()).ok, "fresh request can retry discarded operation")


func test_late_external_history_survives_refusal_without_partial_entry_claims() -> void:
	"""Actual history count invalidates the prepared stream after all provider preflight."""
	_orders.entry_fault = 1
	var before_ids: PackedByteArray = _f.residents.directory().state_bytes()
	var before_space: PackedByteArray = _f.space.state_bytes()
	assert_equal(_confirm(_plan()).error, Sites.REFUSE_CLAIM_BATCH, "late actual claim refuses admission")
	assert_true(_f.sites.state_bytes() == _orders.external_history, "external committed cut ownership preserved")
	assert_true(_f.residents.directory().state_bytes() == before_ids, "no future Room allocated")
	assert_true(_f.space.state_bytes() == before_space, "no partial spatial source/markers")
	assert_equal(_f.sites.site_at(Vector3i(0, -4096, 0)), NULL_REF, "no entry prefix reserved")


func test_same_sized_replacement_lease_refuses_before_allocation_and_at_final_guard() -> void:
	"""A live foreign replacement token cannot rescue an invalid original operation."""
	for stage: int in 2:
		_orders.scope_fault = 2 if stage == 0 else 0
		_orders.entry_fault = 7 if stage == 1 else 0
		var before: PackedByteArray = _image()
		assert_false(_confirm(_plan()).ok, "replaced original lease refused")
		assert_true(_image() == before, "no partial writes")
		assert_true(_bindings.arena.covers(_orders.replacement, Budget.COLD_BYTES), "new owner retains its lease")
		assert_equal(_bindings.arena.release(_orders.replacement), &"", "replacement owner cleans up")
		if stage == 0:
			assert_equal(_orders.attempted_private_bytes, 0, "post-observer guard precedes copy")


func test_foreign_actual_arena_with_coincident_token_refuses_before_private_copy() -> void:
	"""The actual RoomOrders owner checks Budget identity, not just its numeric token."""
	_orders.reject_foreign_budget = true
	assert_true(_confirm(_plan()).ok, "proper original lease still succeeds")
	assert_equal(_orders.foreign_refusal, Orders.REFUSE_ROOM_COLD, "foreign token1 refused")
	assert_equal(_orders.foreign_copy_bytes, 0, "no foreign arena allocation")


func test_scope_callback_shape_mutation_and_shifted_domain_refuse_before_copy() -> void:
	"""The source observer cannot bypass the post-observer shape and physical-namespace checks."""
	var before: PackedByteArray = _image()
	var original: PackedInt32Array = _orders.input_boxes.duplicate()
	_orders.scope_fault = 1
	assert_false(_confirm(_plan()).ok, "scope callback appended malformed field")
	assert_equal(_orders.attempted_private_bytes, 0, "shape rechecked before copy")
	assert_true(_image() == before, "shape refusal has no authoritative writes")
	_orders.scope_fault = 0
	_orders.input_boxes = original
	_orders.shifted_domain = true
	assert_equal(_confirm(_plan()).error, Sites.REFUSE_DOMAIN, "same World with different datum refused")
	assert_equal(_orders.attempted_private_bytes, 0, "namespace refusal before copy")
	assert_true(_image() == before, "domain refusal has no authoritative writes")


func test_retained_history_and_capacity_cannot_partly_reserve_entry() -> void:
	"""Only virgin unique keys can enter a new claim batch; history never returns on cancellation."""
	assert_true(_f.sites.claim_quantum(Vector3i(0, -4096, 0), ClaimTests.PhysicalFixture.ROOM).ok, "actual existing key")
	var before: PackedByteArray = _image()
	assert_equal(_confirm(_plan()).error, Sites.REFUSE_CLAIM_HISTORY, "shared physical key is not virgin")
	assert_true(_image() == before, "existing history preserved")
	_orders.input_boxes = PackedInt32Array([1024, -4096, 0, 10240, -3072, 9216])
	assert_equal(_confirm(_plan()).error, Sites.REFUSE_SITE_CAPACITY, "81 unique keys exceed actual remaining63")
	assert_true(_image() == before, "capacity failure leaves no partly admitted Room or keys")


func test_sorted_merge_preserves_full_existing_site_references_and_gaps() -> void:
	"""Shared publication merges keys without moving prior physical history rows."""
	var low: Vector2i = _f.sites.claim_quantum(Vector3i(0, -8192, 0), ClaimTests.PhysicalFixture.ROOM).ref
	var high: Vector2i = _f.sites.claim_quantum(Vector3i(15360, 7168, 15360), ClaimTests.PhysicalFixture.ROOM).ref
	assert_true(_confirm(_plan()).ok, "three intermediate keys admitted")
	assert_equal(_f.sites.site_at(Vector3i(0, -8192, 0)), low, "old lower key keeps full identity")
	assert_equal(_f.sites.site_at(Vector3i(15360, 7168, 15360)), high, "old upper key keeps full identity")
	assert_equal(_f.sites._ordered_row.slice(0, 5), PackedInt32Array([0, 2, 3, 4, 1]), "sorted index over stable rows")
	assert_equal(_f.sites.remaining_history_capacity(), 59, "all five permanent histories retained")


func test_entry_image_coexistence_has_explicit_bounded_admission() -> void:
	"""Source buffers and interval payload coexist only after allocating companion surveys are dropped."""
	assert_equal(Sites.entry_claim_cold_bytes(0), 0, "empty entry invalid")
	assert_equal(Sites.entry_claim_cold_bytes(Space.MAX_REGIONS + 1), 0, "unbounded entry invalid")
	assert_equal(Sites.entry_claim_cold_bytes(100), 10400 + 2048, "four24B box images plus8B intervals and controls")
	assert_true(Sites.entry_claim_cold_bytes(Space.MAX_REGIONS) > Budget.COLD_BYTES, "independent input ceiling grants no composed memory")
	_orders.input_boxes.resize(6 * Space.MAX_REGIONS)
	var before: PackedByteArray = _image()
	assert_false(_confirm(_plan()).ok, "oversized coexistence refused")
	assert_equal(_orders.attempted_private_bytes, -1, "whole EntryPlan refuses before claim preparation or copied image")
	assert_true(_image() == before, "no partial claim from oversized input")


func test_only_the_attested_domain_snapshot_can_choose_entry_physical_keys() -> void:
	"""A second shifted descriptor previously reserved the unintended X0 key in the actual ledger."""
	_orders.domain_fault = 1
	_orders.input_boxes = PackedInt32Array([1024, -4096, 1024, 1536, -3072, 1536])
	assert_true(_confirm(_plan()).ok, "actual first descriptor remains valid")
	assert_equal(_orders.observed_domain.calls, 1, "no second caller Domain observer before cursor allocation")
	assert_equal(_orders.saved.count(), 1, "exactly one actual datum-relative physical key")
	assert_equal(_f.sites.site_at(Vector3i(0, -4096, 1024)), NULL_REF, "unintended neighboring key remains virgin")
	assert_true(_f.sites.site_at(Vector3i(1024, -4096, 1024)) != NULL_REF, "intended actual key is claimed")


func test_only_the_attested_domain_snapshot_can_choose_flat_room_physical_keys() -> void:
	"""The existing flat cursor shares the same fixed admission window without widening RoomPlan."""
	_orders.domain_fault = 1
	_orders.use_flat_claims = true
	var plan: Orders.RoomPlan = _plan()
	plan.origin_u = Vector3i(1024, -4096, 1024)
	plan.cell_size_u = 512
	plan.height_u = 1024
	plan.cells = PackedInt32Array([0, 0])
	assert_true(_confirm(plan).ok, "ordinary flat plan accepted")
	assert_equal(_orders.observed_domain.calls, 1, "no second caller Domain observation on flat path")
	assert_equal(_orders.saved.count(), 1, "one intended physical key")
	assert_equal(_f.sites.site_at(Vector3i(0, -4096, 1024)), NULL_REF, "no neighboring phantom flat claim")


func test_second_domain_lease_observer_cannot_run_between_private_and_interval_copies() -> void:
	"""A later observable callback cannot revoke the original lease immediately before bank allocation."""
	_orders.domain_fault = 2
	var made: Buildings.OpResult = _confirm(_plan())
	assert_true(made.ok, "original attested scope completes without a second observer")
	assert_equal(_orders.observed_domain.calls, 1, "only initial caller observation")
	assert_equal(_orders.observed_domain.replacement, 0, "no replacement lease minted")
	if _orders.observed_domain.replacement > 0:
		assert_equal(_bindings.arena.release(_orders.observed_domain.replacement), &"", "negative control cleans its replacement")


func test_first_domain_namespace_or_lease_mutation_refuses_before_private_copy() -> void:
	"""The one permitted observer is still revalidated against actual namespace and original lease."""
	for fault: int in [1, 2]:
		_orders.domain_fault = fault
		_orders.domain_mutate_call = 1
		var before: PackedByteArray = _image()
		assert_false(_confirm(_plan()).ok, "changed initial Domain observation refused")
		assert_equal(_orders.attempted_private_bytes, 0, "namespace/lease validation precedes private image")
		assert_true(_image() == before, "no physical or identity publication")
		if _orders.observed_domain.replacement > 0:
			assert_equal(_bindings.arena.release(_orders.observed_domain.replacement), &"", "replacement remains its owner's")


func test_flat_room_cannot_publish_nonflat_entry_batch() -> void:
	"""A synthetic entry batch cannot bypass the ordinary Room's exact flat input and cursor guards."""
	var before: PackedByteArray = _image()
	var result: Buildings.OpResult = _orders.confirm_room(_plan())
	assert_false(result.ok, "non-flat batch under flat Room admission refuses")
	assert_true(_image() == before, "no partial Room, Sites, Space or inventory write")
