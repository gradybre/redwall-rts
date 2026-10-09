extends "res://test/framework/test_case.gd"
## Actual phase payment, Sites and all companion banks. Body/structural/contact content is
## explicitly synthetic; this does not qualify the playable entry or source motion.

const EntrySuite := preload("res://test/test_underground_entry_placements.gd")
const AuthorityTests := preload("res://test/test_underground_space_authority.gd")
const PaidTests := preload("res://test/test_underground_connector_placements.gd")
const WorldTests := preload("res://test/test_underground_world_routes.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class GeometryFixture extends EntrySuite.Fixture:

	func _actual_space(obstruction: int) -> void:
		"""Only initial matter/approach extents are synthetic; every later paid transition uses actual owners."""
		super._actual_space(obstruction)
		var token: int = _owner.begin_stage(_owner.revision()).token
		_region(token, PackedInt32Array([X + 4096, 512, Z, X + 5120, 1536, Z + 1024]), Space.DRY_SOLID)
		_region(token, PackedInt32Array([X + 3072, 512, Z, X + 4096, 1536, Z + 1024]), Space.SUPPORTED_VOID)
		assert_equal(_owner.seal(token), &"", "explicit initial physical extents")
		_owner.publish(token)

class PhaseBinding extends AuthorityTests.SyntheticBindings:
	var placements: Placements = null
	var spatial: WeakRef = null
	var placement: Vector2i = NULL_REF
	var final_probe: Callable = Callable()
	var leaf_probe: Callable = Callable()
	var final_calls: int = 0
	var preparation_error: StringName = &""

	func allocation_refusal(store: Owner, rows: int, bytes: int) -> StringName:
		"""Use the actual already-admitted production sparse pack and a bounded eight-row proof cache."""
		return &"" if store == owner and rows <= 8 and bytes == 69 * rows + 60 \
			and store.packed_memory_bytes() <= Budget.SPACE_BANK_BYTES else &"TEST_PHASE_BUDGET"

	func begin_cold_operation(store: Owner, _site: Vector2i, _op: int, _stage: int) -> int:
		"""Acquire the real one shared lease; the ordinary observer-only fixture has no allocation authority."""
		if store != owner or cold_active != 0: return 0
		cold_active = actual_budget.acquire(Budget.COLD_BYTES)
		cold_opened += int(cold_active > 0)
		return cold_active

	func end_cold_operation(token: int) -> void:
		"""Release only the original token after the real companions dropped every owned candidate."""
		assert(token == cold_active, "original operation finishes once")
		assert(placements._cold_token == 0, "all phase companions gone before lease")
		if actual_budget.covers(token, Budget.COLD_BYTES):
			var code: StringName = actual_budget.release(token)
			assert(code == &"", "release original lease only")
		cold_active = 0
		cold_closed += 1

	func prepare_companions(token: int, site: Vector2i, op: int, stage: int,
			room: Vector2i, _plan: Space.Plan) -> int:
		"""Actual refresh-only candidates replace the former synthetic companion number."""
		var result: int = placements.prepare_phase_refresh(spatial.get_ref(), placement, site, op, stage, room, token, cold_active)
		preparation_error = placements.phase_context_leaf_refusal(result)
		return result

	func prepared_refusal(token: int) -> StringName:
		"""All observing source/retention proofs precede actual final payment."""
		return placements.phase_refresh_refusal(token)

	func revision_after(token: int) -> int:
		"""The real immutable frontier source retained at actual entry admission supplies this revision."""
		return placements.phase_revision_after(token)

	func discard_companions(token: int) -> void:
		"""Authority still owns the original Space candidate and lease."""
		placements.discard_phase_refresh(token)

	func publish_companions(_token: int) -> void:
		"""The actual phase kernel never calls an external observer after Funding commits."""
		assert(false, "actual phase publication is static")

	func phase_final_observation_refusal(_site: Vector2i, _op: int, _stage: int,
			token: int, _space: int, companion: int) -> StringName:
		"""A final adverse observer runs inside the real guarded Inventory transaction, before its leaf."""
		final_calls += 1
		if final_probe.is_valid():
			var probe: Callable = final_probe
			final_probe = Callable()
			probe.call()
		return prepared_refusal(companion) if actual_budget.covers(token, Budget.COLD_BYTES) else Budget.REFUSE_TOKEN

	func phase_final_leaf_refusal(site: Vector2i, op: int, stage: int,
			token: int, space: int, companion: int) -> StringName:
		"""Compare every original phase fact, then use the actual complete candidate leaf."""
		var context: Locations.PhaseContext = placements.phase_context(companion)
		if context == null or context.site != site or context.operation != op or context.stage != stage \
				or context.cold_token != token or context.space_token != space:
			return &"TEST_PHASE_CONTEXT"
		var code: StringName = placements.prepared_phase_leaf_refusal(companion)
		if leaf_probe.is_valid():
			var probe: Callable = leaf_probe
			leaf_probe = Callable()
			probe.call()
		return code

class Harness extends "res://test/framework/test_case.gd":
	var _f: GeometryFixture = null
	var _group: PaidTests.GroupFixture = null
	var _placements: Placements = null
	var _frontier: EntrySuite.Frontier = null
	var _bindings: EntrySuite.Binding = null
	var _orders: EntrySuite.Orders = null
	var _router: EntrySuite.Router = null
	var _sites: Sites = null
	var _edge: Vector2i = NULL_REF
	var phase: PhaseBinding = null
	var spatial: Authority = null
	var economic: AuthorityTests = null
	var placement: Vector2i = NULL_REF

	func before_each() -> void:
		"""Reuse actual immutable stores and future-entry admission; replace only the prior synthetic Sites authority."""
		_f = GeometryFixture.new()
		_f._actual_fixture()
		_edge = _f._publish_route()
		_group = PaidTests.GroupFixture.new()
		_group._catalog = _f._catalog
		_group._items = _f._items
		_group._inventory = _f._inventory
		_group._bind_source(_group._group_wire(1, 1), PackedInt32Array([0]), false, 4)
		assert_equal(_group._load_source(), &"", "actual complete assembly source")
		_placements = Placements.new()
		assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "actual finite banks")
		assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
			_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "same actual owners")
		_frontier = EntrySuite.Frontier.new()
		_frontier.fixture = weakref(_f)
		_frontier.placements = weakref(_placements)
		_frontier.edge = _edge
		assert_equal(_placements.bind_authority(_frontier), &"", "explicit fixture physical permission")
		_bind_orders()
		_admit_entry()
		_bind_economic_helpers()

	func _bind_orders() -> void:
		"""Actual Sites retains the real spatial adapter before the actual Room coordinator is constructed."""
		phase = PhaseBinding.new()
		phase.source_reader = _f._sources
		phase.owner = _f._owner
		phase.buildings = _f._buildings
		phase.jobs = _f._jobs
		phase.inventory = _f._inventory
		phase.actual_budget = _f._budget
		phase.placements = _placements
		spatial = Authority.new()
		assert_equal(spatial.configure(_f._owner, phase, 8), &"", "real spatial adapter")
		phase.spatial = weakref(spatial)
		_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, spatial, 64, 8)
		phase.sites = _sites
		assert_equal(_sites.initialization_refusal(), &"", "actual Sites")
		assert_equal(spatial.bind_sites(_sites), &"", "actual reciprocal phase authority")
		_router = EntrySuite.Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
		_orders = EntrySuite.Orders.new()
		_bindings = EntrySuite.Binding.new()
		_bindings.arena = _f._budget
		_bindings.construction = _f._construction
		_bindings.space = _f._owner
		_bindings.world = _f._world_ref
		_bindings.inventory = _f._inventory
		_bindings.orders = weakref(_orders)
		_bindings.placements = _placements
		_bindings.source = _f._sources as PaidTests.ObservedSources
		assert_equal(_orders.configure(_router, _f._owner, _f._sources, EntrySuite.RoomCatalog.new(), _bindings), &"", "real RoomOrders")
		assert_equal(_f._locations.bind_room_orders(_orders), &"", "actual Room scope")

	func _admit_entry() -> void:
		"""A real future Corridor/Placement source binds through the accepted atomic Room command."""
		var result: Buildings.OpResult = _orders.confirm_entry(_plan())
		assert_true(result.ok, "actual future entry: %s" % result.error)
		placement = _bindings.published
		phase.placement = placement
		phase.floor_ref = _bindings.published_section
		assert_equal(_f._locations.bind_sites(_sites), &"", "actual paid Site identity")
		assert_equal(_placements.bind_phase_authority(spatial), &"", "actual once-bound phase context")

	func _bind_economic_helpers() -> void:
		"""Borrow helper methods only; every store and contribution belongs to this actual composed fixture."""
		economic = AuthorityTests.new()
		economic._residents = _f._residents
		economic._priorities = _f._jobs.priorities()
		economic._schedule = _f._jobs.schedule()
		economic._jobs = _f._jobs
		economic._work = _f._work
		economic._gear = _f._gear
		economic._inventory = _f._inventory
		economic._pool = _f._pool
		economic._items = _f._items
		economic._construction = _f._construction
		economic._buildings = _f._buildings
		economic._owner = _f._owner
		economic._sources = _f._sources
		economic._authority = spatial
		economic._bindings = phase
		economic._sites = _sites
		economic._world = _f._world_ref
		economic._room = _placements._pair(_placements._live, Placements.ROOM_SLOT, placement.x)
		economic._floor = phase.floor_ref
		economic._site = _sites.site_at(Vector3i(WorldTests.X + 4096, 512, WorldTests.Z))
		economic._store = _f._inventory.create_container(_f._world_ref, 100000, -1, 0, true).ref
		economic._output = _f._inventory.create_container(_f._world_ref, 100000, -1, 0, true).ref
		_enroll_worker()

	func _enroll_worker() -> void:
		"""The existing actual resident receives ordinary Job/equipment prerequisites, with no actor or contact grant."""
		var row: int = _f._residents.directory().get_typed_row(_f._worker)
		economic._resident = row
		assert_true(economic._priorities.spawn(row).ok, "actual priorities")
		assert_true(economic._schedule.spawn(row, economic._schedule.default_template_id().value).ok, "actual schedule")
		assert_true(economic._schedule.resolve(row, 8, false).ok, "actual work hour")
		assert_true(_f._jobs.spawn_agent(row).ok, "actual Job agent")
		for need: int in Needs.NEED_COUNT:
			var current: int = _f._residents.needs().need_of(row, need).value
			assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - current).ok, "base mood")
		var tool: Vector2i = economic._lot(&"tool", 1000)
		assert_true(_f._gear.create_gear(_f._inventory, _f._items, tool, Gear.MANUFACTURE_BASIC).ok, "real tool")
		assert_true(_f._gear.equip(tool, _f._worker).ok, "actual equipped tool")
		economic._tools.append(tool)

	func after_each() -> void:
		"""All reused helper assertions propagate, and only exact original candidates/lease may need cleanup."""
		if spatial._stage >= 0:
			spatial.discard_transition(_sites.origin_of(economic._site), spatial._next_i32[9], spatial._stage, economic._room)
		assert_true(economic.failures.is_empty(), "real economic helpers: %s" % economic.failures)
		economic = null
		phase.sites = null
		phase.placements = null
		phase = null
		spatial = null
		assert_true(_f._budget.is_quiescent(), "original phase arena released")
		_bindings = null
		_orders = null
		_router = null
		_sites = null
		_frontier = null
		_placements = null
		_group._reader = null
		_group._recipes = null
		_group._catalog = null
		_group._items = null
		_group._inventory = null
		_group = null
		_f.after_each()
		assert_true(_f.failures.is_empty(), "actual World helper: %s" % _f.failures)
		_f = null

	func _plan(offset: int = 4096) -> EntrySuite.EntryPlan.Request:
		"""A genuine source-pinned request uses synthetic non-flat excavation claims, not physical permission."""
		var result: EntrySuite.EntryPlan.Request = EntrySuite.EntryPlan.Request.new()
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

var _h: Harness = null

func before_each() -> void:
	"""Actual setup failures are surfaced by the outer suite, never hidden in a helper object."""
	_h = Harness.new()
	_h.before_each()
	assert_true(_h.failures.is_empty(), "composed setup: %s" % _h.failures)
	assert_true(_h._f.failures.is_empty(), "actual geometry setup: %s" % _h._f.failures)

func after_each() -> void:
	"""Release the whole real composition and propagate every nested assertion."""
	_h.after_each()
	assert_true(_h.failures.is_empty(), "composed lifecycle: %s" % _h.failures)
	_h = null

func test_actual_brace_start_and_commit_refresh_each_bank_once() -> void:
	"""Even unchanged-row START has one actual Space receipt; payment and actual source revisions advance together."""
	var revision: int = _h._f._owner.revision()
	var first: Locations.Record = Locations.Record.new()
	first.envelope.resize(6)
	first.support.resize(6)
	assert_equal(_h._f._locations.read_location_into(_h._f._first, first), &"", "old full endpoint")
	var job: int = _h.economic._start(Contract.OP_BRACE)
	assert_true(_h.economic.failures.is_empty(), "actual paid start: %s (%s)" % [_h.economic.failures, _h.phase.preparation_error])
	assert_equal(_h._f._owner.revision(), revision + 1, "one real unchanged-row START receipt")
	assert_true(_h.economic._finish_work(job) > 0, "actual productive labor")
	var result: Construction.OpResult = _h._sites.settle_phase(_h.economic._site)
	assert_true(result.ok, "actual guarded terminal: %s" % result.error)
	assert_equal(_h._f._owner.revision(), revision + 2, "one COMMIT receipt")
	assert_equal(_h._f._locations.location_revision(_h._f._first), first.payload_revision, "old endpoint payload unchanged")
	assert_equal(_h._f._routes._live.edge_count, 1, "no new edge")
	assert_equal(_h._f._binding.static_profile_edge_refusal(_h._edge, 0, 1, 1), &"", "actual refreshed certificate")
	assert_equal(_h._placements._get32(_h._placements._live, Placements.INSTALLED, _h.placement.x), 0, "no assembly prefix granted")
	assert_true(_h._f._budget.is_quiescent(), "original lease released")


func _ready_start() -> int:
	"""Create a real unpaid funded-request candidate, leaving the actual input transaction for the test."""
	var job: int = _h.economic._open(Contract.OP_BRACE)
	_h.economic._deliver(Contract.OP_BRACE, job)
	assert_true(_h._sites.bind_worker(_h.economic._site).ok, "actual worker and tool bound")
	assert_true(_h.economic.failures.is_empty(), "real ready inputs: %s" % _h.economic.failures)
	return job


func _live_state() -> Dictionary:
	"""Independent live byte images detect any partial payment or companion swap on refusal."""
	return {"space": _h._f._owner.state_bytes(), "inventory": _h._f._inventory.state_bytes(),
		"locations": _h._f._locations._live.i32.duplicate(), "location_revisions": _h._f._locations._live.i64.duplicate(),
		"routes": _h._f._routes._live.fields.duplicate(), "route_revisions": _h._f._routes._live.longs.duplicate(),
		"route_vertices": _h._f._routes._live.vertices.duplicate(), "route_metadata": PackedInt64Array([_h._f._routes._live.edge_count, _h._f._routes._live.revision, _h._f._routes._last_published_token]),
		"placement": _h._placements._live.i32.duplicate(), "placement_revisions": _h._placements._live.i64.duplicate(),
		"placement_header": _h._placements._live.header.duplicate()}


func _unchanged(before: Dictionary) -> void:
	"""Compare every original live owner, excluding legitimate worker-release/REFUNDING retry controls."""
	var after: Dictionary = _live_state()
	for key: String in before:
		assert_equal(after[key], before[key], "%s remains exact after refusal" % key)


func test_actual_cut_finish_advances_sources_without_new_endpoints_or_prefix() -> void:
	"""Real economic work converts only its paid cube while each current source certificate follows one receipt."""
	var revision: int = _h._f._owner.revision()
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		assert_true(_h.economic._complete(operation) > 0, "actual paid phase contributes labor")
		assert_true(_h.economic.failures.is_empty(), "actual phase %s: %s" % [operation, _h.economic.failures])
	assert_equal(_h._f._owner.revision(), revision + 6, "each real START/COMMIT swaps once")
	assert_equal(_h._sites.virgin_sourced_milli(), 2000, "earth produced exactly once")
	assert_equal(_h.economic._phase(), Sites.SUPPORTED_VOID, "actual FINISH truth")
	assert_equal(_h._f._locations._live.count, 2, "no free endpoint")
	assert_equal(_h._f._routes._live.edge_count, 1, "no free path")
	assert_equal(_h._placements._get32(_h._placements._live, Placements.INSTALLED, _h.placement.x), 0, "no timber prefix")
	assert_equal(_h._f._binding.static_profile_edge_refusal(_h._edge, 0, 1, 1), &"", "actual old edge refreshed")


func test_wrong_final_phase_tuple_refuses_real_input_payment_then_retries() -> void:
	"""An observer cannot substitute a different phase in the borrowed packet while original controls stay fixed."""
	_ready_start()
	var before: Dictionary = _live_state()
	_h.phase.final_probe = func() -> void: _h._placements._phase_context.operation = Contract.OP_CUT
	var result: Construction.OpResult = _h._sites.begin_phase_work(_h.economic._site, 0)
	assert_false(result.ok, "wrong operation refuses inside actual input barrier")
	_unchanged(before)
	assert_true(_h._f._budget.is_quiescent(), "discard releases original lease")
	result = _h._sites.begin_phase_work(_h.economic._site, 0)
	assert_true(result.ok, "fresh exact retry: %s" % result.error)


func test_final_observer_replacement_arena_survives_failed_payment() -> void:
	"""A same-size replacement lease never inherits the old copied image and is never released by cleanup."""
	_ready_start()
	var before: Dictionary = _live_state()
	var replacement: PackedInt64Array = PackedInt64Array([0])
	_h.phase.final_probe = func() -> void:
		assert_equal(_h._f._budget.release(_h.phase.cold_active), &"", "actual original revoked")
		replacement[0] = _h._f._budget.acquire(Budget.COLD_BYTES)
	assert_false(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "replacement refuses before payment")
	_unchanged(before)
	assert_true(_h._f._budget.covers(replacement[0], Budget.COLD_BYTES), "replacement retained untouched")
	assert_equal(_h._f._budget.release(replacement[0]), &"", "test releases its replacement")
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "valid actual retry")


func test_discard_after_final_provider_leaf_cannot_fall_back_to_ordinary_publish() -> void:
	"""Even a lying last callback cannot erase the once-bound actual companion requirement before payment."""
	_ready_start()
	var before: Dictionary = _live_state()
	_h.phase.leaf_probe = func() -> void: _h._placements.discard_phase_refresh(_h._placements._location_token)
	assert_false(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "discarded companions refuse in concrete outer leaf")
	_unchanged(before)
	assert_true(_h._f._budget.is_quiescent(), "original cleanup completes")
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "valid complete companion retry")


func _discard_then_publish(use_static: bool) -> void:
	"""The real final observer discards companions before attempting to steal Authority's still-sealed Space token."""
	var c: Locations.PhaseContext = _h._placements._phase_context
	var token: int = c.space_token
	var base: int = c.base_revision
	var target: int = c.target_revision
	_h._placements.discard_phase_refresh(c.location_token)
	if use_static:
		assert_false(Owner.commit_preflighted(_h._f._owner, token, base, target), "discard cannot reopen static publication")
	else:
		_h._f._owner.publish(token)


func _assert_discard_publication_refused(use_static: bool) -> void:
	"""Both generic entry points must preserve live Space and its successful receipt before Funding commits."""
	_ready_start()
	var before: Dictionary = _live_state()
	var receipt: int = _h._f._owner.last_published_token()
	_h.phase.leaf_probe = func() -> void: _discard_then_publish(use_static)
	assert_false(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "lost companions refuse payment")
	_unchanged(before)
	assert_equal(_h._f._owner.last_published_token(), receipt, "successful Space receipt unchanged")
	assert_true(_h._f._budget.is_quiescent(), "original Authority cleanup releases lease")
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "fresh complete retry succeeds")


func test_discarded_companions_cannot_reopen_generic_space_publish() -> void:
	"""Actual public publish stays guarded until Authority aborts or publishes its original candidate."""
	_assert_discard_publication_refused(false)


func test_discarded_companions_cannot_reopen_static_space_commit() -> void:
	"""The callback-free kernel likewise cannot infer generic ownership from cleared companion controls."""
	_assert_discard_publication_refused(true)


func test_actual_terminal_failure_retries_after_worker_release_without_new_labor() -> void:
	"""COMMIT uses exact paid state and sources after worker release; it cannot require another productive actor."""
	var job: int = _h.economic._start(Contract.OP_BRACE)
	assert_true(_h.economic._finish_work(job) > 0, "real finished work")
	var before: Dictionary = _live_state()
	var paid_work: int = _h._sites._earned_mwu[_h.economic._site.x * Contract.OP_COUNT + Contract.OP_BRACE]
	_h.phase.final_probe = func() -> void: _h._placements._phase_context.project.y += 1
	assert_false(_h._sites.settle_phase(_h.economic._site).ok, "wrong Project refuses terminal payment")
	_unchanged(before)
	assert_equal(_h._f._jobs.worker_of(job), NULL_REF, "actual terminal released worker")
	assert_equal(_h._sites._earned_mwu[_h.economic._site.x * Contract.OP_COUNT + Contract.OP_BRACE], paid_work, "labor unchanged")
	assert_true(_h._sites.settle_phase(_h.economic._site).ok, "worker-free exact terminal retry")


func test_actual_paid_cancel_failure_preserves_refund_then_worker_free_retry() -> void:
	"""CANCEL preserves paid WIP and installed state on late refusal, then publishes one exact no-op Space receipt."""
	var job: int = _h.economic._start(Contract.OP_BRACE)
	assert_true(_h._f._work.tick_solo(job).ok, "actual partial labor")
	var before: Dictionary = _live_state()
	var revision: int = _h._f._owner.revision()
	_h.phase.final_probe = func() -> void: _h._placements._phase_context.stage = Contract.STAGE_COMMIT
	assert_false(_h._sites.cancel_phase(_h.economic._site, _h.economic._store).ok, "late wrong terminal refuses refund")
	_unchanged(before)
	assert_equal(_h._f._jobs.worker_of(job), NULL_REF, "cancel released actual worker")
	assert_true(_h._sites.cancel_phase(_h.economic._site, _h.economic._store).ok, "actual worker-free refund retry")
	assert_equal(_h._f._owner.revision(), revision + 1, "one CANCEL receipt only on success")
	assert_equal(_h._sites.support_conservation_refusal(), &"", "actual refund/consumption balances")


func test_prepaid_generic_and_static_publication_attempts_cannot_swap_candidates() -> void:
	"""The original sealed token does not convey the actual Sites postpayment publication window."""
	_ready_start()
	var revision: int = _h._f._owner.revision()
	_h.phase.final_probe = func() -> void:
		var context: Locations.PhaseContext = _h._placements._phase_context
		_h._f._owner.publish(context.space_token)
		assert_false(Owner.commit_preflighted(_h._f._owner, context.space_token, context.base_revision, context.target_revision), "no early static Space swap")
		assert_false(Placements.commit_phase_preflighted(_h._placements, context.location_token), "no early complete phase swap")
		assert_equal(_h._f._owner.revision(), revision, "original live revision remains before payment")
	var result: Construction.OpResult = _h._sites.begin_phase_work(_h.economic._site, 0)
	assert_true(result.ok, "real Sites window later succeeds: %s" % result.error)
	assert_equal(_h._f._owner.revision(), revision + 1, "exactly one real payment/publication")


func _during_phase_location_copy() -> bool:
	"""Select the real source-observation boundary before the first owned endpoint bank copy."""
	return _h._placements._busy and _h._placements._phase_mode and _h._placements._location_token == 0


func test_early_busy_context_leaf_requires_every_original_argument() -> void:
	"""A structural PREPARED observer can inspect its exact busy phase, but no neighboring operation may borrow it."""
	_ready_start()
	var source: PaidTests.ObservedSources = _h._f._sources as PaidTests.ObservedSources
	source.when = _during_phase_location_copy
	source.probe = func() -> void:
		var c: Locations.PhaseContext = _h._placements._phase_context
		assert_true(_h._placements._busy, "actual protected preparation interval")
		assert_equal(Placements.phase_operation_leaf_refusal(_h._placements, _h.spatial, c.site, c.operation, c.stage,
			c.room, c.project, c.cold_token, c.space_token), &"", "exact early tuple before endpoint/route seal")
		assert_true(Placements.phase_operation_leaf_refusal(_h._placements, _h.spatial, c.site, c.operation, c.stage + 1,
			c.room, c.project, c.cold_token, c.space_token) != &"", "different stage cannot borrow busy")
		assert_true(Placements.phase_operation_leaf_refusal(_h._placements, _h.spatial, c.site, c.operation, c.stage,
			Vector2i(c.room.x, c.room.y + 1), c.project, c.cold_token, c.space_token) != &"", "full Room generation")
		assert_true(Placements.phase_operation_leaf_refusal(_h._placements, _h.spatial, c.site, c.operation, c.stage,
			c.room, c.project, c.cold_token + 1, c.space_token) != &"", "original token only")
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "read-only exact scope does not poison original")
	assert_equal(source.observed, 1, "actual callback was exercised")


func test_actual_source_replaces_lease_before_endpoint_bank_copy() -> void:
	"""The copy observes the original arena immediately after all source callbacks, never a same-size replacement."""
	_ready_start()
	var before: Dictionary = _live_state()
	var counted: PaidTests.CountedLocationBank = PaidTests.CountedLocationBank.new()
	counted.allocate(_h._f._locations._capacity)
	_h._f._locations._stage = counted
	var replacement: PackedInt64Array = PackedInt64Array([0])
	var source: PaidTests.ObservedSources = _h._f._sources as PaidTests.ObservedSources
	source.when = _during_phase_location_copy
	source.probe = func() -> void:
		assert_equal(_h._f._budget.release(_h.phase.cold_active), &"", "original actual source lease revoked")
		replacement[0] = _h._f._budget.acquire(Budget.COLD_BYTES)
	assert_false(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "stale original scope refuses")
	assert_equal(source.observed, 1, "real source observer")
	assert_equal(counted.copies, 0, "no endpoint bank copy after callback revoked original token")
	_unchanged(before)
	assert_true(_h._f._budget.covers(replacement[0], Budget.COLD_BYTES), "replacement lease survives")
	assert_equal(_h._f._budget.release(replacement[0]), &"", "test releases replacement")
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "original candidate may be retried freshly")
	assert_equal(counted.copies, 1, "one real admitted endpoint copy")


func test_nested_phase_preparation_poison_refuses_outer_without_payment() -> void:
	"""The source observer cannot obtain a second phase while the original owns shared scratch."""
	_ready_start()
	var before: Dictionary = _live_state()
	var source: PaidTests.ObservedSources = _h._f._sources as PaidTests.ObservedSources
	source.when = _during_phase_location_copy
	source.probe = func() -> void:
		var c: Locations.PhaseContext = _h._placements._phase_context
		assert_equal(_h._placements.prepare_phase_refresh(_h.spatial, c.placement, c.site, c.operation, c.stage,
			c.room, c.space_token, c.cold_token), 0, "reentrant phase cannot take mutable scratch")
	assert_false(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "outer poisoned operation refuses")
	_unchanged(before)
	assert_true(_h._sites.begin_phase_work(_h.economic._site, 0).ok, "fresh original operation retries")
