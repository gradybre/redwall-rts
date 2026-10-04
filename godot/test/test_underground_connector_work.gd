extends "res://test/framework/test_case.gd"
## Real paid owners, immutable grouping and companions; only physical installation contacts/frontier are synthetic.

const ConnectorWork := preload("res://scripts/core/underground_connector_work.gd")
const PlacementTests := preload("res://test/test_underground_connector_placements.gd")
const GroupFixture := preload("res://test/test_underground_connector_assemblies.gd")
const CatalogContent := preload("res://test/test_underground_connector_catalog.gd")
const Placements := preload("res://scripts/core/underground_connector_placements.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Work := preload("res://scripts/core/work.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const WorldFixture := preload("res://test/test_underground_world_routes.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const BuildingCatalog := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class FourPartWorld extends PlacementTests.ActualFixture:

	func _load_catalog(revision: int) -> StringName:
		"""Four actual source parts belong to two billable groups; no price is inferred from geometry count."""
		var bytes: PackedByteArray = GroupFixture._catalog_wire(4, revision)
		return _catalog.load_file(GroupFixture.CATALOG_PATH,
			CatalogContent._write(GroupFixture.CATALOG_PATH, bytes), revision)

class SyntheticContacts extends ConnectorWork.Contacts:
	## These permissions certify neither authored stair motion nor a playable entry; all paid stores remain actual.
	var placements: WeakRef = null
	var router: WeakRef = null
	var world: Vector2i = NULL_REF
	var block: StringName = &""
	var final_block: StringName = &""
	var probe: Callable = Callable()
	var transition_probe: Callable = Callable()
	var worker_probe: Callable = Callable()
	var observations: int = 0
	var worker_observations: int = 0

	func exact_binding(p: Placements, r: Router, w: Vector2i) -> bool:
		"""Even synthetic contact permission cannot qualify numerically identical foreign owners."""
		return placements != null and router != null and placements.get_ref() == p and router.get_ref() == r and world == w

	func admission_refusal(_p: Vector2i, _assembly: int) -> StringName:
		"""Test-only static installation feasibility; no caller sets a production success flag."""
		return block

	func transition_refusal(_p: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""All physical observation scopes remain explicit in component tests."""
		if transition_probe.is_valid():
			var current: Callable = transition_probe
			transition_probe = Callable()
			current.call()
		return block

	func material_refusal(_p: Vector2i, _project: Vector2i, _assembly: int, _container: Vector2i, _job: Vector2i) -> StringName:
		"""Actual Inventory/Funding still own the goods and every reservation."""
		return block

	func worker_refusal(_p: Vector2i, _project: Vector2i, _assembly: int, _job: Vector2i, _worker: Vector2i) -> StringName:
		"""No substitute WU is awarded here; the real Work/Gear path follows this fixture permission."""
		worker_observations += 1
		if worker_probe.is_valid():
			var current: Callable = worker_probe
			worker_probe = Callable()
			current.call()
		return block

	func final_observation_refusal(_p: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""One adversarial callback exercises the last actual contact observation before payment."""
		observations += 1
		if probe.is_valid():
			var current: Callable = probe
			probe = Callable()
			current.call()
		return block

	func final_leaf_refusal(_p: Vector2i, _project: Vector2i, _assembly: int, _action: int) -> StringName:
		"""Synthetic leaf has no callbacks, copies or mutation; real physical implementation remains mandatory."""
		return final_block

class SeedObserver extends RefCounted:
	var contacts: WeakRef = null
	var calls: int = 0
	var probe: Callable = Callable()

	func refuses_seed_consumption(_lot: Vector2i) -> bool:
		"""Actual Inventory invokes this even for reserved wood, after early funding checks."""
		calls += 1
		if probe.is_valid():
			probe.call()
		else:
			(contacts.get_ref() as SyntheticContacts).final_block = &"SYNTHETIC_LATE_CONTACT_DRIFT"
		return false

class ObservedPaidOwner extends ConnectorWork:
	## Negative-only dispatch detector, retaining the entire real owner's publication implementation.
	var postpayment_probe: Callable = Callable()
	var refuse_paid_start_facts: bool = false
	var paid_start_fact_reads: int = 0

	func project_facts_into(project: Vector2i, out: Contract.Quote) -> StringName:
		"""A real bill observer armed only after actual WIP settlement must never run during START publication."""
		if refuse_paid_start_facts and _actual_router()._funding.is_funded(project) \
				and not _construction.has_work_begun(project):
			paid_start_fact_reads += 1
			return &"POSTPAYMENT_START_FACT_OBSERVER"
		return super.project_facts_into(project, out)

	func publish_completion(project: Vector2i) -> void:
		"""Arm ordinary-reader refusals only after actual Funding has committed."""
		if postpayment_probe.is_valid():
			var current: Callable = postpayment_probe
			postpayment_probe = Callable()
			current.call()
		super.publish_completion(project)

class Fixture extends "res://test/framework/test_case.gd":
	var _f: PlacementTests.ActualFixture = null
	var _group: GroupFixture = null
	var _placements: Placements = null
	var _authority: PlacementTests.TestAuthority = null
	var _router: Router = null
	var _physical: PhysicalFixture.SpatialFixture = null
	var _sites: Sites = null
	var _request: Placements.Request = null
	var _lease: int = 0
	var _store: Vector2i = NULL_REF
	var tool_ref: Vector2i = NULL_REF
	var paid_owner: ConnectorWork = null
	var contacts: SyntheticContacts = null
	var math: IntMath.IntResult = IntMath.IntResult.new()

	func before_each() -> void:
		"""Retain the accepted actual-store bootstrap, replacing its synthetic purpose owner with ConnectorWork."""
		_f = FourPartWorld.new()
		_f._actual_fixture()
		_group = GroupFixture.new()
		_group._catalog = _f._catalog
		_group._items = _f._items
		_group._inventory = _f._inventory
		_group._bind_source(_group._group_wire(2, 2), PackedInt32Array([0, 2]), false, 4)
		assert_equal(_group._load_source(), &"", "two complete actual groups")
		_placements = Placements.new()
		assert_equal(_placements.configure(4, 8, Placements.required_bytes(4, 8)), &"", "actual finite placement arena")
		assert_equal(_placements.bind_actual(_f._owner, _f._locations, _f._routes, _f._budget,
			_f._catalog, _group._reader, _group._recipes, _f._construction), &"", "actual source composition")
		_authority = PlacementTests.TestAuthority.new()
		_authority.fixture = weakref(_f)
		_authority.placement_owner = weakref(_placements)
		assert_equal(_placements.bind_authority(_authority), &"", "explicitly synthetic physical frontier")
		_bind_paid()
		_request = _make_request()
		assert_equal(_f.failures.size(), 0, "actual fixture setup: %s" % _f.failures)
		assert_equal(_group.failures.size(), 0, "actual group setup: %s" % _group.failures)

	func _bind_paid() -> void:
		"""The sole real shared Funding/Router compose with the new actual purpose8 owner."""
		_physical = PhysicalFixture.SpatialFixture.new()
		_physical.world = _f._world_ref
		_sites = Sites.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _physical, 64, 8)
		assert_equal(_sites.initialization_refusal(), &"", "actual shared receipt owner")
		_router = Router.new(_f._construction, _f._inventory, _f._pool, _f._items, _f._jobs, _f._work, _sites)
		assert_equal(_router.initialization_refusal(), &"", "actual modular owner")
		contacts = SyntheticContacts.new()
		contacts.placements = weakref(_placements)
		contacts.router = weakref(_router)
		contacts.world = _f._world_ref
		paid_owner = ObservedPaidOwner.new()
		assert_equal(paid_owner.configure(_placements, _router, contacts), &"", "actual ConnectorWork reciprocal binding")

	func after_each() -> void:
		"""Synchronous stages and adversarial callbacks must not retain live owners after the test."""
		contacts.probe = Callable()
		contacts.transition_probe = Callable()
		contacts.worker_probe = Callable()
		(paid_owner as ObservedPaidOwner).postpayment_probe = Callable()
		_f._inventory.set_seed_expiry_authority(null)
		if paid_owner._stage_action >= 0:
			paid_owner.discard_transition(paid_owner._stage_project, paid_owner._stage_action)
		paid_owner = null
		contacts = null
		(_f._sources as PlacementTests.ObservedSources).probe = Callable()
		(_f._sources as PlacementTests.ObservedSources).when = Callable()
		if _lease > 0 and _f._budget.covers(_lease, 1):
			assert_equal(_f._budget.release(_lease), &"", "exact test lease returned")
		assert_true(_f._inventory.audit().ok, "actual Inventory audit")
		assert_true(_f._pool.audit(_f._inventory).ok, "actual claim audit")
		_release_owners()

	func _open_registered(ref: Vector2i) -> Vector2i:
		"""Read the actual prefix and open one full Project for its next immutable assembly."""
		var record: Placements.OrderRecord = Placements.OrderRecord.new()
		assert_equal(_placements.placement_into(ref, record), &"", "actual placed source")
		var opened: Construction.OpResult = _router.open_order(paid_owner, ref, record.installed_count)
		assert_true(opened.ok, "actual next assembly: %s" % opened.error)
		assert_equal(_placements.order_refusal(ref, opened.ref, record.installed_count), &"", "exact Project attached")
		return opened.ref

	func fund_inputs(project: Vector2i, job: Vector2i) -> Vector2i:
		"""Deliver exactly one immutable bill using actual stock, reservation rows and Construction credits."""
		var quote: Contract.Quote = Contract.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual one-group quote")
		assert_true(_router.bind_material_container(project, _store).ok, "actual material contact")
		var lot: Vector2i = _stock(quote.input_keys[0], quote.input_milli[0])
		var claims: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[0], 1000])
		assert_true(_f._pool.claim_batch(job, claims, 1, _f._inventory).ok, "actual reserved wood")
		assert_true(_router.record_deliveries(project).ok, "actual full bill delivered")
		return lot

	func _pay_and_work(project: Vector2i, job: Vector2i) -> void:
		"""No direct work mutation: real shared payment and actual ticks consume wood, wear tools and earn WU."""
		fund_inputs(project, job)
		var started: Construction.OpResult = _router.start_work(project, 100)
		assert_true(started.ok, "actual paid start: %s" % started.error)
		if started.ok:
			finish_work(project, job)

	func finish_work(project: Vector2i, job: Vector2i) -> void:
		"""Bound the test loop while preserving all real Work gates and integer work accounting."""
		for tick: int in 1000:
			_f._construction.remaining_mwu_into(project, math)
			if math.value == 0:
				return
			var result: Work.TickResult = _f._work.tick_solo(_f._residents.directory().get_typed_row(job))
			assert_true(result.ok, "actual productive tick: %s" % result.error)
			if not result.ok:
				return
		fail("actual bounded work did not finish")


	func _make_request() -> Placements.Request:
		"""Exact full refs name real retained metadata and completed approach, never a future Room flag."""
		var request: Placements.Request = Placements.Request.new()
		request.corridor = _f.corridor
		request.section = _f.corridor_floor
		request.anchor = _f._first
		request.origin = Vector3i(WorldFixture.X + 4096, 512, WorldFixture.Z)
		request.level = 0
		for ordinal: int in _placements._opening_count():
			request.targets.append_array(PackedInt32Array([_f.corridor.x, _f.corridor.y, _f.corridor_floor.x, _f.corridor_floor.y]))
		return request

	func _paid_worker(project: Vector2i) -> Vector2i:
		"""The existing real resident receives a real Job, schedule, priorities and equipped tool claim."""
		var row: int = _f._residents.directory().get_typed_row(_f._worker)
		assert_true(_f._jobs.priorities().spawn(row).ok, "actual priorities")
		assert_true(_f._jobs.schedule().spawn(row, _f._jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_f._jobs.schedule().resolve(row, 8, false).ok, "actual work hour")
		assert_true(_f._jobs.spawn_agent(row).ok, "actual worker agent")
		for need: int in Needs.NEED_COUNT:
			var value: int = _f._residents.needs().need_of(row, need).value
			assert_true(_f._residents.needs().apply_need_event(row, need, 5000 - value).ok, "actual base mood")
		_store = _f._inventory.create_container(_f._world_ref, 100000, -1, 0, true).ref
		var tool: Vector2i = _stock(&"tool", 1000)
		tool_ref = tool
		assert_true(_f._gear.create_gear(_f._inventory, _f._items, tool, Gear.MANUFACTURE_BASIC).ok, "actual basic tool")
		assert_true(_f._gear.equip(tool, _f._worker).ok, "actual equipment")
		var quote: Contract.Quote = Contract.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "real recipe supplies exact work")
		var job: Jobs.OpResult = _f._jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
		assert_true(job.ok, "real Job")
		assert_true(_f._jobs.set_requester(job.value, project).ok, "exact requester")
		assert_true(_f._jobs.set_tool_gate(job.value, Jobs.GATE_SATISFIED).ok, "tool gate")
		assert_true(_router.bind_job(project, job.ref).ok, "actual primary Job")
		assert_true(_f._jobs.assign_worker(row, job.value).ok, "actual assignment")
		assert_true(_f._work.claim_tool_for_work(row, tool).ok, "actual Work tool claim")
		return job.ref

	func _stock(key: StringName, quantity: int) -> Vector2i:
		"""Catalogued test stock goes through actual Inventory, never synthetic receipt bytes."""
		var made: Inventory.OpResult = _f._inventory.create_lot(_store, _f._items.compiled_id(key), quantity,
			1, BuildingCatalog.PROVENANCE_ORDINARY, -1, 0, 0)
		assert_true(made.ok, "actual stock")
		return made.ref

	func _register() -> Vector2i:
		"""Every test admission runs the actual finite owner path with the real original Budget token."""
		_lease = _f._budget.acquire(Budget.COLD_BYTES)
		var result: Placements.Result = _placements.register(_request, _lease)
		assert_equal(result.error, &"", "actual Placement registration: %s" % result.error)
		assert_equal(_f._budget.release(_lease), &"", "registration scratch drops")
		_lease = 0
		return result.placement

	func _paid_order() -> Vector2i:
		"""Real shared Router opens the next group of one actual placed connector."""
		return _open_registered(_register())

	func reuse_worker(project: Vector2i) -> Vector2i:
		"""The completed order released its Job claim; the same real equipped worker can take the next group."""
		var quote: Contract.Quote = Contract.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "next real assembly quote")
		var job: Jobs.OpResult = _f._jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
		assert_true(job.ok, "next actual Job")
		assert_true(_f._jobs.set_requester(job.value, project).ok, "next exact requester")
		assert_true(_f._jobs.set_tool_gate(job.value, Jobs.GATE_SATISFIED).ok, "existing actual tool")
		assert_true(_router.bind_job(project, job.ref).ok, "next primary Job")
		var resident: int = _f._residents.directory().get_typed_row(_f._worker)
		assert_true(_f._jobs.assign_worker(resident, job.value).ok, "same worker takes next assembly")
		assert_true(_f._work.claim_tool_for_work(resident, tool_ref).ok, "existing tool claim for new Job")
		return job.ref

	func _release_owners() -> void:
		"""Remove only this fixture's actual owners and source files, after every accounting audit."""
		_request = null
		_router = null
		_sites = null
		_physical = null
		_authority = null
		_placements = null
		_group._reader = null
		_group._recipes = null
		_group._catalog = null
		_group._items = null
		_group._inventory = null
		_group = null
		_f.after_each()
		_f = null
		for path: String in [GroupFixture.GROUP_PATH, GroupFixture.RECIPE_PATH, GroupFixture.CATALOG_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

var _fx: Fixture = null


func before_each() -> void:
	"""One actual World/store composition per case avoids retained source or claim contamination."""
	_fx = Fixture.new()
	_fx.before_each()
	assert_equal(_fx.failures.size(), 0, "fixture setup: %s" % _fx.failures)


func after_each() -> void:
	"""Propagate fixture assertions and actual Inventory/reservation audits through the strict suite."""
	_fx.after_each()
	assert_equal(_fx.failures.size(), 0, "actual fixture checks: %s" % _fx.failures)
	_fx = null


func _record(p: Vector2i) -> Placements.OrderRecord:
	"""Observe actual state through the generation-checked reader, never a mirrored fixture prefix."""
	var out: Placements.OrderRecord = Placements.OrderRecord.new()
	assert_equal(_fx._placements.placement_into(p, out), &"", "current placement read")
	return out


func _ready_work() -> Vector2i:
	"""Finish actual materials and labor, retaining WIP and every physical publication until the test commits."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx._pay_and_work(project, job)
	return project


func test_actual_group_bill_and_once_only_paid_installation() -> void:
	"""Two visual prisms in one group consume one wood bill and advance one installed assembly only."""
	var project: Vector2i = _ready_work()
	var p: Vector2i = _fx._f._construction.subject_ref_of(project)
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_fx._router.project_facts_into(project, quote), &"", "actual immutable bill")
	assert_equal(quote.input_count, 1, "wood only")
	assert_equal(quote.input_keys[0], &"wood", "no rope or invented surcharge")
	assert_equal(quote.input_milli[0], 1000, "one group bill, not two visual-part bills")
	assert_equal(quote.total_mwu, 12000, "one complete assembly effort")
	var revision: int = _fx._f._owner.revision()
	var done: Construction.OpResult = _fx._router.complete_order(project)
	assert_true(done.ok, "real complete: %s" % done.error)
	assert_equal(_record(p).installed_count, 1, "one installed assembly")
	assert_equal(_record(p).project, NULL_REF, "paid project cleared after companions")
	assert_equal(_fx._f._owner.revision(), revision + 1, "one geometry publication")
	assert_false(_fx._f._construction.is_live_project(project), "actual completed Project retired")
	assert_true(_fx._f._budget.is_quiescent(), "copied companion state drops before original lease")
	assert_true(_fx.paid_owner.is_quiescent(), "no transient adapter state escapes publication")
	assert_false(_fx._router.complete_order(project).ok, "duplicate commit cannot install or debit twice")


func test_default_contacts_and_wrong_prefix_never_spend_identity() -> void:
	"""The production base denies admission; an exact actual owner cannot choose an arbitrary next group."""
	var base: ConnectorWork.Contacts = ConnectorWork.Contacts.new()
	assert_false(base.exact_binding(_fx._placements, _fx._router, _fx._f._world_ref), "no default binding permission")
	assert_equal(base.admission_refusal(NULL_REF, 0), ConnectorWork.REFUSE_BINDING, "no default physical permission")
	var p: Vector2i = _fx._register()
	var directory: PackedByteArray = _fx._f._residents.directory().state_bytes()
	assert_false(_fx._router.open_order(_fx.paid_owner, p, 1).ok, "cannot skip first group")
	_fx.contacts.block = &"SYNTHETIC_CONTACT_MISSING"
	assert_false(_fx._router.open_order(_fx.paid_owner, p, 0).ok, "actual owner respects absent contact")
	assert_true(_fx._f._residents.directory().state_bytes() == directory, "refused order spends no identity")
	_fx.contacts.block = &""
	assert_true(_fx._router.open_order(_fx.paid_owner, p, 0).ok, "later explicit complete proof can retry")


func test_late_actual_inventory_observer_refuses_wood_payment_then_retries() -> void:
	"""The last Inventory removal observer cannot make an earlier connector contact proof authorize payment."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var observer: SeedObserver = SeedObserver.new()
	observer.contacts = weakref(_fx.contacts)
	assert_true(_fx._f._inventory.set_seed_expiry_authority(observer).ok, "actual reserved-input observer")
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var claims: PackedByteArray = _fx._f._pool.state_bytes()
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	var refused: Construction.OpResult = _fx._router.start_work(project, 100)
	assert_equal(refused.error, &"SYNTHETIC_LATE_CONTACT_DRIFT", "final guard is after actual removal observers")
	assert_true(observer.calls > 0, "the real late observer executed")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "all staged wood payment rolled back")
	assert_true(_fx._f._pool.state_bytes() == claims, "claims unchanged")
	assert_true(_fx._router._funding.state_bytes() == funding, "no WIP published")
	assert_true(_fx._f._inventory.set_seed_expiry_authority(null).ok, "test observer removed")
	_fx.contacts.final_block = &""
	assert_true(_fx._router.start_work(project, 100).ok, "exact original claims can retry")


func test_final_contact_failure_preserves_wip_geometry_and_retry() -> void:
	"""Complete earned work survives a blocked physical installation without partial geometry or material loss."""
	var project: Vector2i = _ready_work()
	var p: Vector2i = _fx._f._construction.subject_ref_of(project)
	var geometry: PackedByteArray = _fx._f._owner.state_bytes()
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	_fx.contacts.final_block = &"SYNTHETIC_INSTALL_CONTACT_BLOCKED"
	assert_false(_fx._router.complete_order(project).ok, "late contact denies settlement")
	assert_true(_fx._f._owner.state_bytes() == geometry, "no physical publication")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "paid Inventory unchanged")
	assert_true(_fx._router._funding.state_bytes() == funding, "original complete WIP retained")
	assert_equal(_record(p).installed_count, 0, "no prefix advance")
	assert_equal(_record(p).project, project, "actual paid order stays attached")
	assert_true(_fx._f._budget.is_quiescent(), "failed prepared companions release original arena")
	_fx.contacts.final_block = &""
	assert_true(_fx._router.complete_order(project).ok, "explicit fresh retry installs without new work or bill")


func test_late_inventory_pause_prevents_payment_and_can_retry() -> void:
	"""A valid last seed callback may pause the actual project; the staged wood and claims must roll back."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var observer: SeedObserver = SeedObserver.new()
	observer.probe = func() -> void: assert_true(_fx._f._construction.set_paused(project, true).ok, "late actual pause")
	assert_true(_fx._f._inventory.set_seed_expiry_authority(observer).ok, "actual late Inventory observer")
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var claims: PackedByteArray = _fx._f._pool.state_bytes()
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	assert_equal(_fx._router.start_work(project, 100).error, Construction.REFUSE_PAUSED, "final pause closes payment")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "wood transaction rolled back")
	assert_true(_fx._f._pool.state_bytes() == claims, "actual reservation rows unchanged")
	assert_true(_fx._router._funding.state_bytes() == funding, "no paid receipt published")
	assert_false(_fx._f._construction.has_work_begun(project), "work has not started")
	observer.probe = Callable()
	assert_true(_fx._f._inventory.set_seed_expiry_authority(null).ok, "observer removed")
	assert_true(_fx._f._construction.set_paused(project, false).ok, "fresh actual resume")
	assert_true(_fx._router.start_work(project, 100).ok, "same original stock and claims retry")


func test_connector_start_has_no_bill_observer_after_wip_settlement() -> void:
	"""Only concrete receipt/quote leaves remain after payment; ordinary begin_work bill callbacks are forbidden."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var actual: ObservedPaidOwner = _fx.paid_owner as ObservedPaidOwner
	actual.refuse_paid_start_facts = true
	assert_true(_fx._router.start_work(project, 100).ok, "actual pure paid start tail")
	assert_equal(actual.paid_start_fact_reads, 0, "no recipe/owner callback after irreversible WIP settlement")
	assert_true(_fx._f._construction.has_work_begun(project), "actual Construction publication completed")
	actual.refuse_paid_start_facts = false


func test_last_productive_contact_pause_earns_no_work_xp_or_wear() -> void:
	"""An otherwise successful final physical observer cannot invalidate the phase after the early Work check."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "actual paid start")
	var row: int = _fx._f._residents.directory().get_typed_row(job)
	var work: PackedByteArray = _fx._f._work.state_bytes()
	var gear: PackedByteArray = _fx._f._gear.state_bytes()
	var jobs: PackedByteArray = _fx._f._jobs.state_bytes()
	_fx.contacts.transition_probe = func() -> void:
		assert_true(_fx._f._construction.set_paused(project, true).ok, "pause in final productive contact")
	assert_equal(_fx._f._work.tick_solo(row).error, Construction.REFUSE_PAUSED, "last phase proof follows contact")
	assert_true(_fx._f._work.state_bytes() == work, "no Work carry or XP mutation")
	assert_true(_fx._f._gear.state_bytes() == gear, "no tool wear")
	assert_true(_fx._f._jobs.state_bytes() == jobs, "no Job labor retired")
	assert_true(_fx._f._construction.set_paused(project, false).ok, "explicit resume")
	assert_true(_fx._f._work.tick_solo(row).ok, "fresh actual worker can continue")


func test_late_input_phase_and_delivered_mutation_refuse_before_payment() -> void:
	"""Every exact prepared start fact remains current after actual Inventory's last removal observer."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var row: int = _fx._f._residents.directory().get_typed_row(project)
	var observer: SeedObserver = SeedObserver.new()
	assert_true(_fx._f._inventory.set_seed_expiry_authority(observer).ok, "real late removal observer")
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var claims: PackedByteArray = _fx._f._pool.state_bytes()
	observer.probe = func() -> void: _fx._f._construction._phase[row] = Construction.PHASE_WORKING
	assert_equal(_fx._router.start_work(project, 100).error, Construction.REFUSE_WRONG_PHASE, "late phase refuses")
	_fx._f._construction._phase[row] = Construction.PHASE_READY
	observer.probe = func() -> void: _fx._f._construction._delivered_milli[row * 4] -= 1
	assert_equal(_fx._router.start_work(project, 100).error, Construction.REFUSE_MATERIALS_INCOMPLETE, "late delivered fact refuses")
	_fx._f._construction._delivered_milli[row * 4] += 1
	observer.probe = func() -> void: _fx._router._quote.total_mwu += 1
	assert_equal(_fx._router.start_work(project, 100).error, Contract.REFUSE_QUOTE, "changed prepared quote refuses")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "all three staged payments rolled back")
	assert_true(_fx._f._pool.state_bytes() == claims, "all actual claims retained")
	assert_false(_fx._router._funding.is_funded(project), "no attempted WIP escaped")
	observer.probe = Callable()
	assert_true(_fx._f._inventory.set_seed_expiry_authority(null).ok, "remove adversarial callback")
	assert_true(_fx._router.start_work(project, 100).ok, "new exact quote retries same goods")


func test_concrete_start_kernel_requires_original_full_scope_and_receipt() -> void:
	"""The static publication method grants no authority to direct callers or coincident/stale full refs."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var before: PackedByteArray = _fx._f._construction.state_bytes()
	assert_false(Construction.begin_connector_work_preflighted(_fx._f._construction, _fx._router, project, job).ok, "idle Router refuses")
	var observer: SeedObserver = SeedObserver.new()
	observer.probe = func() -> void:
		assert_equal(Construction.connector_start_refusal(_fx._f._construction, _fx._router, project, job, false), &"", "real final input scope")
		assert_false(Construction.begin_connector_work_preflighted(_fx._f._construction, _fx._router, project, job).ok, "WIP permit cannot publish BEGIN_WORK")
		assert_true(Construction.connector_start_refusal(_fx._f._construction, Contract.new(), project, job, false) != &"", "base authority refuses")
		assert_true(Construction.connector_start_refusal(_fx._f._construction, _fx._router, project + Vector2i(0, 1), job, false) != &"", "stale Project refuses")
		assert_true(Construction.connector_start_refusal(_fx._f._construction, _fx._router, project, job + Vector2i(0, 1), false) != &"", "stale Job refuses")
		assert_true(_fx._f._construction.state_bytes() == before, "all refused direct entries leave actual accounting unchanged")
	assert_true(_fx._f._inventory.set_seed_expiry_authority(observer).ok, "probe real open settlement")
	assert_true(_fx._router.start_work(project, 100).ok, "only real original paid tail publishes")
	observer.probe = Callable()
	assert_true(_fx._f._inventory.set_seed_expiry_authority(null).ok, "drop probe")
	before = _fx._f._construction.state_bytes()
	assert_false(Construction.begin_connector_work_preflighted(_fx._f._construction, _fx._router, project, job).ok, "duplicate tail refuses")
	assert_true(_fx._f._construction.state_bytes() == before, "duplicate changes no row")


func test_late_actual_worker_release_refuses_inputs_before_start() -> void:
	"""After final Contacts, the last actual crew identity pass may not reenter any contact or recipe observer."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	var resident: int = _fx._f._residents.directory().get_typed_row(_fx._f._worker)
	var observer: SeedObserver = SeedObserver.new()
	observer.probe = func() -> void: assert_true(_fx._f._jobs.release_worker(resident).ok, "actual worker release after early proof")
	assert_true(_fx._f._inventory.set_seed_expiry_authority(observer).ok, "actual late observer")
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var claims: PackedByteArray = _fx._f._pool.state_bytes()
	assert_equal(_fx._router.start_work(project, 100).error, Work.REFUSE_JOB_HAS_NO_WORKER, "last concrete crew proof refuses")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "no wood consumed for stale crew")
	assert_true(_fx._f._pool.state_bytes() == claims, "all claims retained")
	assert_false(_fx._router._funding.is_funded(project), "no orphan funded order")
	observer.probe = Callable()
	assert_true(_fx._f._inventory.set_seed_expiry_authority(null).ok, "drop observer")
	assert_true(_fx._f._jobs.assign_worker(resident, _fx._f._residents.directory().get_typed_row(job)).ok, "same actual worker reassigned")
	assert_true(_fx._router.start_work(project, 100).ok, "fresh actual crew can retry same inputs")


func test_productive_phase_and_worker_pause_refuse_without_labor() -> void:
	"""Both final transition and worker observers must leave actual current phase and remaining labor usable."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "real paid start")
	var row: int = _fx._f._residents.directory().get_typed_row(project)
	var job_row: int = _fx._f._residents.directory().get_typed_row(job)
	var work: PackedByteArray = _fx._f._work.state_bytes()
	var gear: PackedByteArray = _fx._f._gear.state_bytes()
	var jobs: PackedByteArray = _fx._f._jobs.state_bytes()
	_fx.contacts.transition_probe = func() -> void: _fx._f._construction._phase[row] = Construction.PHASE_WORK_DONE
	assert_equal(_fx._f._work.tick_solo(job_row).error, Construction.REFUSE_WRONG_PHASE, "late wrong phase refuses")
	_fx._f._construction._phase[row] = Construction.PHASE_WORKING
	_fx.contacts.worker_probe = func() -> void: assert_true(_fx._f._construction.set_paused(project, true).ok, "late worker pause")
	assert_equal(_fx._f._work.tick_solo(job_row).error, Construction.REFUSE_PAUSED, "worker callback cannot bypass pause")
	assert_true(_fx._f._work.state_bytes() == work, "no carry or XP from either refused attempt")
	assert_true(_fx._f._gear.state_bytes() == gear, "no wear")
	assert_true(_fx._f._jobs.state_bytes() == jobs, "no actual Job work retired")
	assert_true(_fx._f._construction.set_paused(project, false).ok, "explicit resume")
	assert_true(_fx._f._work.tick_solo(job_row).ok, "next exact attempt works")


func test_late_completion_pause_retains_wip_and_paused_cancel_remains_legal() -> void:
	"""COMMIT requires live unpaused WORK_DONE, while actual cancellation intentionally accepts a paused order."""
	var project: Vector2i = _ready_work()
	var p: Vector2i = _fx._f._construction.subject_ref_of(project)
	var inventory: PackedByteArray = _fx._f._inventory.state_bytes()
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	var geometry: PackedByteArray = _fx._f._owner.state_bytes()
	_fx.contacts.probe = func() -> void: assert_true(_fx._f._construction.set_paused(project, true).ok, "pause at final COMMIT observer")
	assert_equal(_fx._router.complete_order(project).error, Construction.REFUSE_PAUSED, "paused final settlement refuses")
	assert_true(_fx._f._inventory.state_bytes() == inventory, "no output settlement")
	assert_true(_fx._router._funding.state_bytes() == funding, "complete paid WIP retained")
	assert_true(_fx._f._owner.state_bytes() == geometry, "no installed geometry")
	assert_true(_fx._router.cancel_order(project, _fx._store).ok, "paused cancellation still refunds")
	assert_equal(_stored_wood(), 800, "ordinary started refund remains80 percent")
	assert_equal(_record(p).installed_count, 0, "no prefix installed by refused commit")


func test_replaced_actual_arena_survives_failed_installation_cleanup() -> void:
	"""Cleanup retains its original Budget strongly and never releases another owner's replacement token."""
	var project: Vector2i = _ready_work()
	_fx._authority.probe = func() -> void:
		assert_equal(_fx._f._budget.release(_fx.paid_owner._cold_token), &"", "replace original lease at final observer")
		_fx._lease = _fx._f._budget.acquire(Budget.COLD_BYTES)
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	assert_false(_fx._router.complete_order(project).ok, "original prepared scope is invalid")
	assert_true(_fx._router._funding.state_bytes() == funding, "no settlement after lost lease")
	assert_true(_fx._f._budget.covers(_fx._lease, Budget.COLD_BYTES), "foreign token survives cleanup")
	assert_equal(_fx._f._budget.release(_fx._lease), &"", "test-owned replacement release")
	_fx._lease = 0
	assert_true(_fx._router.complete_order(project).ok, "new preparation retries once arena is available")


func test_direct_publication_and_final_observer_reentry_do_not_install() -> void:
	"""Possession of full handles cannot replace the actual Router window or bypass exclusive preparation."""
	var project: Vector2i = _ready_work()
	var p: Vector2i = _fx._f._construction.subject_ref_of(project)
	_fx.paid_owner.publish_completion(project)
	assert_equal(_record(p).installed_count, 0, "direct completion has no authority")
	_fx.contacts.probe = func() -> void:
		assert_false(_fx.paid_owner.is_quiescent(), "composed capture cannot enter a prepared callback")
		var ignored: Contract.Quote = Contract.Quote.new()
		assert_equal(_fx.paid_owner.project_facts_into(project, ignored), ConnectorWork.REFUSE_REENTRY, "same owner observer cannot reenter")
	assert_equal(_fx._router.complete_order(project).error, ConnectorWork.REFUSE_REENTRY, "nested attempt poisons outer payment")
	assert_true(_fx._router._funding.is_funded(project), "WIP remains complete")
	assert_equal(_record(p).installed_count, 0, "nested proof did not install")
	assert_true(_fx._router.complete_order(project).ok, "fresh operation clears only old transient poison")


func _stored_wood() -> int:
	"""Read actual lots so refund/loss assertions do not mirror the Funding receipt implementation."""
	var quantity: int = 0
	var lot: Vector2i = _fx._f._inventory.container_first_lot(_fx._store)
	while lot != NULL_REF:
		if _fx._f._inventory.lot_item_id(lot) == _fx._f._items.compiled_id(&"wood"):
			quantity += _fx._f._inventory.lot_quantity_milli(lot)
		lot = _fx._f._inventory.container_next_lot(lot)
	return quantity


func test_cancel_next_group_preserves_installed_prefix_and_ordinary_loss() -> void:
	"""One paid assembly stays installed while the second refunds80%; restarting receives its full work bill."""
	var first: Vector2i = _ready_work()
	var p: Vector2i = _fx._f._construction.subject_ref_of(first)
	assert_true(_fx._router.complete_order(first).ok, "first assembly installed")
	var geometry: PackedByteArray = _fx._f._owner.state_bytes()
	var project: Vector2i = _fx._open_registered(p)
	var job: Vector2i = _fx.reuse_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "second wood bill paid")
	assert_true(_fx._f._work.tick_solo(_fx._f._residents.directory().get_typed_row(job)).ok, "real partial work")
	var canceled: Construction.OpResult = _fx._router.cancel_order(project, _fx._store)
	assert_true(canceled.ok, "actual ordinary cancellation: %s" % canceled.error)
	assert_equal(_record(p).installed_count, 1, "existing completed assembly remains")
	assert_equal(_record(p).project, NULL_REF, "only canceled Project detached")
	assert_true(_fx._f._owner.state_bytes() == geometry, "completed physical support is not demolished")
	assert_equal(_stored_wood(), 800, "exact ordinary started-work refund")
	assert_equal(_fx._router._funding.purpose_cancellation_loss_milli(Construction.PURPOSE_CONNECTOR_INSTALL,
		_fx._f._items.compiled_id(&"wood")), 200, "connector loss domain alone records200 wood")
	var replacement: Vector2i = _fx._open_registered(p)
	assert_true(replacement != project, "fresh full Project identity")
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_fx._router.project_facts_into(replacement, quote), &"", "new exact next-group bill")
	assert_equal(quote.remaining_mwu, 12001, "no excavation retained-work exception for canceled installation")
	assert_equal(quote.input_milli[0], 1000, "full repayment; returned goods remain available to deliver")


func test_unfunded_cancellation_never_debits_stock_or_installs() -> void:
	"""A delivered but unstarted ordinary order releases its actual claims and retains all wood."""
	var project: Vector2i = _fx._paid_order()
	var p: Vector2i = _fx._f._construction.subject_ref_of(project)
	var job: Vector2i = _fx._paid_worker(project)
	var lot: Vector2i = _fx.fund_inputs(project, job)
	assert_true(_fx._router.cancel_order(project).ok, "unstarted cancellation requires no refund destination")
	assert_equal(_stored_wood(), 1000, "all original stock remains")
	assert_equal(_fx._f._pool.claim_quantity_milli(job, lot, Reservations.PURPOSE_MODULAR_INPUT), 0, "original claim released")
	assert_equal(_record(p).installed_count, 0, "no free installation")
	assert_equal(_record(p).project, NULL_REF, "canceled full Project cleared")


func test_actual_tool_pause_and_contact_gates_preserve_work_and_wear() -> void:
	"""A productive proof cannot replace the real tool claim or paused state, and refusals earn nothing."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "actual paid start")
	var resident: int = _fx._f._residents.directory().get_typed_row(_fx._f._worker)
	var row: int = _fx._f._residents.directory().get_typed_row(job)
	assert_true(_fx._f._work.release_tool_claim(resident).ok, "remove only real worker tool binding")
	var before: PackedByteArray = _fx._f._construction.state_bytes()
	var wear: PackedByteArray = _fx._f._gear.state_bytes()
	assert_false(_fx._f._work.tick_solo(row).ok, "no productive unset-tool loophole")
	assert_true(_fx._f._construction.state_bytes() == before, "no work credit without tool")
	assert_true(_fx._f._gear.state_bytes() == wear, "no wear on refusal")
	assert_true(_fx._f._work.claim_tool_for_work(resident, _fx.tool_ref).ok, "real tool rebind")
	assert_true(_fx._f._construction.set_paused(project, true).ok, "actual player pause")
	assert_false(_fx._f._work.tick_solo(row).ok, "paused installation cannot earn")
	assert_true(_fx._f._construction.set_paused(project, false).ok, "actual resume")
	before = _fx._f._construction.state_bytes()
	_fx.contacts.block = &"SYNTHETIC_WORK_CONTACT_BLOCKED"
	assert_false(_fx._f._work.tick_solo(row).ok, "actual contact remains mandatory")
	assert_true(_fx._f._construction.state_bytes() == before, "contact refusal preserves all post-resume work state")
	_fx.contacts.block = &""
	assert_true(_fx._f._work.tick_solo(row).ok, "fresh actual gates allow work again")


func test_productive_tick_does_not_rebuild_cold_quote_packets() -> void:
	"""Real tick reads full immutable identities but never overwrites the reused cold source records."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "actual paid start")
	_fx.paid_owner._order.payload_revision = 987654321
	_fx.paid_owner._assembly.recipe_anchor = -12345
	var observed: int = _fx.contacts.worker_observations
	assert_true(_fx._f._work.tick_solo(_fx._f._residents.directory().get_typed_row(job)).ok, "actual productive tick")
	assert_true(_fx.contacts.worker_observations > observed, "hot actual contact checked")
	assert_equal(_fx.paid_owner._order.payload_revision, 987654321, "no cold Placement packet refill")
	assert_equal(_fx.paid_owner._assembly.recipe_anchor, -12345, "no cold grouping or recipe quote")
	assert_equal(_fx.paid_owner._stage_action, -1, "exact productive preparation discarded or published")


func test_late_catalog_rewire_releases_original_budget_and_preserves_funding() -> void:
	"""Invalidated owner getters do not hide the already acquired arena from refusal cleanup."""
	var project: Vector2i = _ready_work()
	var original: PlacementTests.ConnectorCatalog = _fx._f._catalog
	var foreign: PlacementTests.ConnectorCatalog = PlacementTests.ConnectorCatalog.new()
	_fx._authority.probe = func() -> void: _fx._f._binding._catalog = foreign
	var funding: PackedByteArray = _fx._router._funding.state_bytes()
	assert_false(_fx._router.complete_order(project).ok, "coincident or absent foreign source cannot publish")
	assert_true(_fx._router._funding.state_bytes() == funding, "actual complete receipt retained")
	assert_true(_fx._f._budget.is_quiescent(), "exact original Budget still released after getter refuses")
	_fx._f._binding._catalog = original
	assert_true(_fx._router.complete_order(project).ok, "fresh actual composition retries")


func test_paid_publication_uses_no_fallible_contact_or_source_observers() -> void:
	"""The complete physical tail is sealed before settlement; ordinary readers are unreachable afterward."""
	var project: Vector2i = _ready_work()
	(_fx.paid_owner as ObservedPaidOwner).postpayment_probe = func() -> void:
		assert_false(_fx._router._funding.is_funded(project), "actual receipt settled before prefix publication")
		_fx._f._locations.refuse_live_read = true
		_fx._f._terrain.binding_countdown = 1
		_fx._f._terrain.binding_probe = func() -> void: fail("postpayment Terrain observer is forbidden")
		_fx.contacts.probe = func() -> void: fail("postpayment Contacts observer is forbidden")
	assert_true(_fx._router.complete_order(project).ok, "actual pure tail completes")
	assert_true(_fx.contacts.probe.is_valid(), "no final contact observer after settlement")
	assert_equal(_fx._f._terrain.binding_probe_count, 0, "no final source callback after settlement")
	_fx.contacts.probe = Callable()
	_fx._f._terrain.binding_probe = Callable()
	_fx._f._terrain.binding_countdown = 0
	_fx._f._locations.refuse_live_read = false


func test_stale_project_and_expired_contact_owner_cannot_earn_or_rebind() -> void:
	"""Same slots do not qualify stale generations; weak contacts require an actual live retained owner."""
	var project: Vector2i = _fx._paid_order()
	var job: Vector2i = _fx._paid_worker(project)
	_fx.fund_inputs(project, job)
	assert_true(_fx._router.start_work(project, 100).ok, "actual start")
	var quote: Contract.Quote = Contract.Quote.new()
	assert_true(_fx._router.project_facts_into(project + Vector2i(0, 1), quote) != &"", "stale generation has no quote")
	assert_true(_fx.paid_owner.configure(_fx._placements, _fx._router, _fx.contacts) != &"", "once-bound owner cannot reset wiring")
	_fx.paid_owner._contacts = weakref(ConnectorWork.Contacts.new())
	var before: PackedByteArray = _fx._f._construction.state_bytes()
	assert_false(_fx._f._work.tick_solo(_fx._f._residents.directory().get_typed_row(job)).ok, "expired actual contact refuses")
	assert_true(_fx._f._construction.state_bytes() == before, "no credit after wiring expiry")
	_fx.paid_owner._contacts = weakref(_fx.contacts)
	assert_true(_fx._f._work.tick_solo(_fx._f._residents.directory().get_typed_row(job)).ok, "test restoration permits fresh proof")


func test_adapter_numeric_census_and_no_duplicate_packed_arena() -> void:
	"""Reflection counts the actual additional fields rather than a second declared paid-state model."""
	var bytes: int = 0
	var actual: ConnectorWork = ConnectorWork.new()
	for source: RefCounted in [actual, actual._order, actual._assembly]:
		for property: Dictionary in source.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var value: Variant = source.get(String(property.name))
			assert_false(value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array,
				"adapter and caller records own no packed receipt/progress bank")
			if value is int or value is Vector2i:
				bytes += 8
			elif value is bool:
				bytes += 1
	assert_equal(bytes, 179, "128 caller records +51 exact synchronous controls")
