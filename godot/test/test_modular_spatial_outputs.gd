extends "res://test/framework/test_case.gd"
## Real Router/Work/Funding/Inventory transactions; only source and location permission is synthetic.

const Router := preload("res://scripts/core/modular_projects.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Priorities := preload("res://scripts/core/priorities.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const PhysicalFixture := preload("res://test/test_excavation_physical.gd")
const ModularFixture := preload("res://test/test_modular_projects.gd")
const LocationFixture := preload("res://test/test_inventory_spatial.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class OutputOwner extends ModularFixture.SyntheticOwner:
	## The quote matches adopted reclaim arithmetic; actual source stock remains a labeled fixture.
	var earth_item: int = -1

	func _fill(out: Contract.Quote) -> void:
		"""The actual shared pipeline receives an exact immutable reclaim or compact quote."""
		super._fill(out)
		if operation != 3:
			return
		out.job_kind = Jobs.JOB_KIND_BUILD
		out.input_count = 0
		out.input_keys.fill(&"")
		out.input_milli.fill(0)
		out.output_count = 1
		out.output_item[0] = earth_item
		out.output_milli[0] = quantity
		out.output_quality[0] = int(Catalog.QUALITY["PLAIN"])
		out.output_provenance[0] = Catalog.PROVENANCE_SPOIL_RECLAIM

var _residents: Residents = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _jobs: Jobs = null
var _work: Work = null
var _gear: Gear = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _construction: Construction = null
var _sites: Sites = null
var _funding: Funding = null
var _space: PhysicalFixture.SpatialFixture = null
var _router: Router = null
var _owner: OutputOwner = null
var _locations: PhysicalFixture.SpatialOutputFixture = null
var _world: Vector2i = NULL_REF
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _resident: int = -1
var _tools: Array[Vector2i] = []
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""One actual material, identity, worker and paid receipt world per test."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	_inventory = Inventory.new(16, 128)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual catalog")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual equipment")
	assert_true(_work.bind_gear(_gear).ok, "actual wear owner")
	_store = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_output = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_construction = Construction.new(Buildings.new(_residents.directory()))
	_space = PhysicalFixture.SpatialFixture.new()
	_space.world = _world
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _space, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual physical composition")
	_funding = _sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work)
	_router = Router.new(_construction, _inventory, _pool, _items, _jobs, _work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual modular router")
	_owner = _new_owner()
	assert_true(_router.bind_owner(_owner).ok, "explicit synthetic purpose permission")
	_resident = _spawn_worker()
	_locations = PhysicalFixture.SpatialOutputFixture.new()
	_locations.inventory = weakref(_inventory)
	_locations.directory = _residents.directory()
	_locations.world = _world
	assert_true(_inventory.bind_spatial_locations(_locations, 4).ok, "actual finite location ownership")


func _new_owner() -> OutputOwner:
	"""Create one component-level synthetic physical owner, never a per-project production object."""
	var owner: OutputOwner = OutputOwner.new()
	owner.construction = _construction
	owner.world = _world
	owner.route = weakref(_router)
	owner.funding = _funding
	owner.earth_item = _items.compiled_id(&"excavated_earth")
	owner.operation = 3
	owner.quantity = 1001
	owner.total = 501
	return owner


func after_each() -> void:
	"""Audit actual quantities and claim ownership before releasing the composed world."""
	assert_true(_inventory.audit().ok, "actual Inventory audit")
	assert_true(_pool.audit(_inventory).ok, "actual claims audit")
	_locations = null
	_owner = null
	_router = null
	_funding = null
	_sites = null
	_space = null
	_construction = null
	_gear = null
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null
	_pool = null
	_items = null
	_inventory = null
	_tools.clear()


func _spawn_worker(stage: int = Residents.LIFE_STAGE_ADULT) -> int:
	"""Equip an actual resident and initialize real JobAgent, schedule, mood and tool ownership."""
	var resident: int = _residents.spawn_with_stage(&"mouse", stage).value
	assert_true(_priorities.spawn(resident).ok, "worker priorities")
	assert_true(_schedule.spawn(resident, _schedule.default_template_id().value).ok, "worker schedule")
	assert_true(_schedule.resolve(resident, 8, false).ok, "real work-hour eligibility")
	assert_true(_jobs.spawn_agent(resident).ok, "actual JobAgent")
	for need: int in Needs.NEED_COUNT:
		var previous: int = _residents.needs().need_of(resident, need).value
		assert_true(_residents.needs().apply_need_event(resident, need, 5000 - previous).ok, "base-rate mood")
	var tool: Vector2i = _lot(&"tool", Gear.GEAR_LOT_QUANTITY_MILLI)
	assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual tool instance")
	assert_true(_gear.equip(tool, _residents.ref_of(resident)).ok, "actual equipment")
	_tools.append(tool)
	return resident


func _lot(key: StringName, quantity: int) -> Vector2i:
	"""Create actual catalogued stock for delivery/tool tests."""
	var lot: Inventory.OpResult = _inventory.create_lot(_store, _items.compiled_id(key), quantity,
		1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0)
	assert_true(lot.ok, "actual loose lot")
	return lot.ref


func _open(owner: OutputOwner = null) -> Vector2i:
	"""Request admission through the real typed router with no caller WU/bill inputs."""
	var actual: OutputOwner = _owner if owner == null else owner
	actual.prepared = true
	var opened: Construction.OpResult = _router.open_order(actual, actual.subject, actual.operation)
	assert_true(opened.ok, "actual order opens: %s" % opened.error)
	assert_equal(actual.project, opened.ref, "physical fixture receives exact actual project")
	return opened.ref


func _job(project: Vector2i, coordinator: bool = false, resident: int = -1) -> Vector2i:
	"""Create a real Job with exact owner-derived work, kind and requester; no fake worker refs."""
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "actual immutable project bill")
	var made: Jobs.OpResult = _jobs.create_job(quote.job_kind, 1, 0, quote.remaining_mwu, 0)
	assert_true(made.ok, "actual primary Job")
	assert_true(_jobs.set_requester(made.value, project).ok, "actual requester")
	assert_true(_jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok, "mandatory tools")
	if coordinator:
		assert_true(_jobs.make_coordinator(made.value).ok, "actual shared coordinator")
	assert_true(_router.bind_job(project, made.ref).ok, "actual primary accepted")
	if not coordinator:
		_assign(made.ref, _resident if resident < 0 else resident)
	return made.ref


func _assign(job: Vector2i, resident: int) -> void:
	"""Actual Jobs assignment and Work/Gear claim, with carry retained across projects."""
	var row: int = _jobs.directory().get_typed_row(job)
	assert_true(_jobs.assign_worker(resident, row).ok, "actual worker assignment")
	assert_true(_work.claim_tool_for_work(resident, _tools[resident]).ok, "actual job-scoped equipment claim")


func _deliver(project: Vector2i) -> void:
	"""Claim every exact actual bill line at the bound container, then derive delivery credits."""
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_router.project_facts_into(project, quote), &"", "read actual bill")
	if quote.input_count == 0:
		return
	assert_true(_router.bind_material_container(project, _store).ok, "actual input contact")
	var claims: PackedInt64Array = PackedInt64Array()
	for line: int in quote.input_count:
		var lot: Vector2i = _lot(quote.input_keys[line], quote.input_milli[line])
		claims.append_array(PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, quote.input_milli[line], 1000]))
	assert_true(_pool.claim_batch(_router.job_of(project), claims, quote.input_count, _inventory).ok, "actual input claims")
	assert_true(_router.record_deliveries(project).ok, "actual claims become exact credits")


func _start(project: Vector2i) -> void:
	"""Use actual paid start; no synthetic WIP, elapsed time or direct Construction progress."""
	_deliver(project)
	var result: Construction.OpResult = _router.start_work(project, 100, _output if _owner.operation == 3 else NULL_REF)
	assert_true(result.ok, "actual inputs/output start: %s" % result.error)
	assert_true(_funding.is_funded(project), "actual shared receipt owner records payment")


func _finish_labor(project: Vector2i, job: Vector2i) -> void:
	"""Advance real capped labor, XP and tool wear; no accepted-WU parameter enters the router."""
	var row: int = _jobs.directory().get_typed_row(job)
	for tick: int in 1000:
		_construction.remaining_mwu_into(project, _math)
		if _math.value == 0:
			return
		var result: Work.TickResult = _work.tick_party(row) if _jobs.is_coordinator(row) else _work.tick_solo(row)
		assert_true(result.ok, "real Work tick: %s" % result.error)
		if not result.ok:
			return
	fail("real Work did not complete within the fixture's bounded duration")


func _image() -> PackedByteArray:
	"""Capture every actual authoritative accounting/worker owner for refusal comparisons."""
	var image: PackedByteArray = _inventory.state_bytes()
	image.append_array(_pool.state_bytes())
	image.append_array(_funding.state_bytes())
	image.append_array(_construction.state_bytes())
	image.append_array(_router.state_bytes())
	image.append_array(_jobs.state_bytes())
	image.append_array(_work.state_bytes())
	image.append_array(_gear.state_bytes())
	image.append_array(_residents.state_bytes())
	return image


func _stage(location: Vector2i = LocationFixture.LOWER) -> Vector2i:
	"""Create an actual finite World-owned endpoint, never an ordinary unlimited output buffer."""
	var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(location)
	assert_true(made.ok, "actual finite endpoint: %s" % made.error)
	return made.ref


func _paid_image() -> PackedByteArray:
	"""Compare the actual atomic material owners independently of cancellation's safe worker release."""
	var image: PackedByteArray = _inventory.state_bytes()
	image.append_array(_pool.state_bytes())
	image.append_array(_funding.state_bytes())
	return image


func _ready_reclaim() -> Vector2i:
	"""Real integer labor completes the immutable quote; physical source permission stays synthetic."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	_finish_labor(project, job)
	return project


func test_actual_router_commits_outputs_on_distinct_stacked_locations() -> void:
	"""Equal fixture X/Z on two floors owns separate real output containers and payload revisions."""
	_output = _stage(LocationFixture.LOWER)
	var lower: Vector2i = _output
	var first: Vector2i = _ready_reclaim()
	assert_true(_router.complete_order(first).ok, "first actual paid output")
	_output = _stage(LocationFixture.UPPER)
	var second: Vector2i = _ready_reclaim()
	assert_true(_router.complete_order(second).ok, "second actual paid output")
	assert_equal(_inventory.spatial_location_of(lower), LocationFixture.LOWER, "first full actual location")
	assert_equal(_inventory.spatial_location_of(_output), LocationFixture.UPPER, "different full actual location")
	assert_true(lower != _output, "separate real container identities")
	assert_equal(_inventory.container_policy(lower), Inventory.POLICY_GROUND_PILE, "lower pile published")
	assert_equal(_inventory.container_policy(_output), Inventory.POLICY_GROUND_PILE, "upper pile published")
	assert_equal(_inventory.ground_pile_at_tile(0), NULL_REF, "neither endpoint aliases surface zero")
	assert_equal(_inventory.total_live_milli(_owner.earth_item), 2002, "exact two paid quote outputs")
	assert_equal(_owner.completed, 2, "source publication runs once for each actual project")
	var before: PackedByteArray = _image()
	assert_false(_router.complete_order(first).ok, "retired generation cannot produce again")
	assert_true(_image() == before, "duplicate is byte-identical across every actual owner")


func test_surface_alias_and_stale_payload_refuse_before_payment() -> void:
	"""Neither a surface argument nor a changed location payload can consume inputs or claim space."""
	_output = _stage()
	var project: Vector2i = _open()
	_job(project)
	var before: PackedByteArray = _image()
	assert_equal(_router.start_work(project, 100, _output, 0).error, Inventory.REFUSE_SPATIAL_REQUIRED, "surface alias refuses")
	assert_true(_image() == before, "alias cannot change WIP, claims, worker or endpoint")
	_locations.revision += 1
	assert_equal(_router.start_work(project, 100, _output).error, Inventory.REFUSE_SPATIAL_LOCATION, "same numbers with stale payload refuse")
	assert_true(_image() == before, "stale endpoint cannot fund an operation")
	_locations.revision -= 1
	assert_true(_router.start_work(project, 100, _output).ok, "original endpoint starts actual work")
	assert_equal(_inventory.container_reserved_mass_g(_output), 1001, "actual output reservation, once")
	assert_true(_router.cancel_order(project).ok, "material-free cancellation settles")


func test_commit_time_spatial_failure_restores_all_actual_owners_then_retries() -> void:
	"""The endpoint can refuse after actual goods creation without any source or WIP publication."""
	_output = _stage()
	var project: Vector2i = _ready_reclaim()
	_locations.watched_output = _output
	_locations.refuse_after_output = true
	var before: PackedByteArray = _image()
	assert_false(_router.complete_order(project).ok, "new goods trigger fresh support refusal inside transaction")
	assert_true(_image() == before, "all actual accounting/work owners are byte-identical")
	assert_equal(_inventory.container_reserved_mass_g(_output), 1001, "owned output headroom retained")
	assert_equal(_inventory.container_lot_count(_output), 0, "no output escaped rollback")
	assert_equal(_owner.completed, 0, "source publication did not run")
	assert_true(_funding.is_funded(project), "actual receipts survive")
	_locations.refuse_after_output = false
	assert_true(_router.complete_order(project).ok, "same paid work retries without extra labor")
	assert_equal(_inventory.lot_quantity_milli(_inventory.container_first_lot(_output)), 1001, "exact one real output")
	assert_false(_funding.is_funded(project), "WIP retires only after commit")
	assert_equal(_owner.completed, 1, "source publication finally occurs once")


func test_existing_spatial_pile_accepts_another_paid_output_without_repromotion() -> void:
	"""A nonempty real pile remains the same full identity while separate projects add their goods."""
	_output = _stage()
	assert_true(_router.complete_order(_ready_reclaim()).ok, "first output promotes staging")
	var first: Vector2i = _inventory.container_first_lot(_output)
	var project: Vector2i = _ready_reclaim()
	assert_true(_router.complete_order(project).ok, "existing pile needs no second promotion")
	assert_equal(_inventory.container_lot_count(_output), 2, "both real output lots survive")
	assert_equal(_inventory.lot_quantity_milli(first), 1001, "older goods unchanged")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "each output claim settled")
	assert_equal(_inventory.spatial_ground_container_at(LocationFixture.LOWER), _output, "same endpoint still owns pile")


func test_zero_input_cancel_retires_only_owned_empty_staging_and_keeps_source_claims() -> void:
	"""A no-refund cancellation needs no fake destination and cannot release another Job's inputs."""
	_output = _stage()
	var project: Vector2i = _open()
	_job(project)
	_start(project)
	var other: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, 1000, 0)
	assert_true(other.ok, "separate actual Job identity")
	var untouched: Vector2i = _lot(&"wood", 17)
	var claim: PackedInt64Array = PackedInt64Array([untouched.x, untouched.y, Reservations.PURPOSE_HAUL_SOURCE, 17, 1000])
	assert_true(_pool.claim_batch(other.ref, claim, 1, _inventory).ok, "other actual source claim")
	assert_true(_router.cancel_order(project).ok, "no returned goods need no destination")
	assert_false(_inventory.is_container_valid(_output), "sole empty pending output retires")
	assert_false(_inventory.has_spatial_location(LocationFixture.LOWER, 1), "exact owned endpoint released")
	assert_equal(_inventory.lot_reserved_milli(untouched), 17, "other Job's actual source quantity remains")
	assert_equal(_pool.job_claim_count(other.ref), 1, "other pool row remains")
	assert_equal(_inventory.total_live_milli(_owner.earth_item), 0, "no canceled source output")
	assert_equal(_owner.cancelled, 1, "one physical cancellation")


func test_positive_cancel_refund_promotes_actual_spatial_destination() -> void:
	"""Compact's real consumed earth returns80 percent into a different actual underground endpoint."""
	_owner.operation = 1
	_owner.quantity = 1001
	_owner.total = 251
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	assert_true(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "actual started work")
	var destination: Vector2i = _stage(LocationFixture.UPPER)
	assert_true(_router.cancel_order(project, destination).ok, "actual positive refund commits")
	assert_equal(_inventory.container_policy(destination), Inventory.POLICY_GROUND_PILE, "actual refund goods promote same row")
	assert_equal(_inventory.spatial_location_of(destination), LocationFixture.UPPER, "exact refund endpoint")
	assert_equal(_inventory.total_live_milli(_owner.earth_item), 800, "actual aggregate80 percent refund")
	assert_equal(_funding.purpose_cancellation_loss_milli(Construction.PURPOSE_SPOIL_TIP, _owner.earth_item), 201, "exact adopted loss")
	assert_equal(_inventory.lot_provenance(_inventory.container_first_lot(destination)), Catalog.PROVENANCE_ORDINARY, "consumed source metadata retained")
	assert_false(_funding.is_funded(project), "settled receipts retire")


func test_positive_refund_support_refusal_restores_receipts_goods_and_loss_until_retry() -> void:
	"""Geometry refusing after real refund lots exist leaves all paid material owners unchanged."""
	_owner.operation = 1
	_owner.quantity = 1001
	_owner.total = 251
	var project: Vector2i = _open()
	_job(project)
	_start(project)
	var destination: Vector2i = _stage()
	_locations.watched_output = destination
	_locations.refuse_after_output = true
	var before: PackedByteArray = _paid_image()
	assert_false(_router.cancel_order(project, destination).ok, "refund promotion sees fresh support refusal")
	assert_true(_paid_image() == before, "Inventory, reservations, WIP and loss exactly roll back")
	assert_true(_construction.phase_into(project, _math), "frozen actual project remains")
	assert_equal(_math.value, Construction.PHASE_REFUNDING, "safe cancellation freeze remains retryable")
	assert_equal(_inventory.container_lot_count(destination), 0, "no orphan refund goods")
	assert_equal(_owner.cancelled, 0, "source lock remains until material settlement")
	_locations.refuse_after_output = false
	assert_true(_router.cancel_order(project, destination).ok, "worker-free cancellation retries")
	assert_equal(_inventory.total_live_milli(_owner.earth_item), 800, "exact one refund")
	assert_equal(_owner.cancelled, 1, "one source unlock after settlement")


func test_spatial_cancellation_retains_another_purposes_actual_input_claims() -> void:
	"""Actual Sites and Router share one receipt owner without crossing their claimed source goods."""
	_output = _stage()
	var site: Vector2i = _sites.claim_quantum(PhysicalFixture.ORIGIN, PhysicalFixture.ROOM).ref
	var brace: Construction.OpResult = _sites.open_phase(site, PhysicalFixture.Contract.OP_BRACE)
	assert_true(brace.ok, "actual second purpose project")
	var job: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 2000, 0)
	assert_true(_jobs.set_requester(job.value, brace.ref).ok, "actual Site requester")
	assert_true(_jobs.set_tool_gate(job.value, Jobs.GATE_SATISFIED).ok, "actual required-tool declaration")
	assert_true(_sites.bind_job(site, job.ref).ok, "actual Site binds Job")
	assert_true(_sites.bind_material_container(site, _store).ok, "actual delivered materials")
	for key: StringName in [&"wood", &"stone"]:
		var lot: Vector2i = _lot(key, 250)
		var claim: PackedInt64Array = PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_EXCAVATION_INPUT, 250, 1000])
		assert_true(_pool.claim_batch(job.ref, claim, 1, _inventory).ok, "actual neighbor source claim")
	assert_true(_sites.record_deliveries(site).ok, "actual neighbor delivery")
	var project: Vector2i = _open()
	_job(project)
	_start(project)
	var claim_before: PackedByteArray = _pool.state_bytes()
	assert_true(_router.cancel_order(project).ok, "actual modular cancellation settles")
	assert_true(_pool.state_bytes() == claim_before, "different paid-purpose source claims stay byte-identical")
	assert_equal(_pool.job_claim_count(job.ref), 2, "both actual neighbor materials retained")
	assert_true(_construction.is_live_project(brace.ref), "neighbor accounting identity remains")
	assert_false(_inventory.is_container_valid(_output), "only canceled output staging retires")
	assert_true(_sites.cancel_phase(site, _store).ok, "neighbor releases its own claims independently")
