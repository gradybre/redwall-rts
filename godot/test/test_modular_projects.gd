extends "res://test/framework/test_case.gd"
## Actual payment, Job, Work and equipped Gear. Only this purpose's physical admission is synthetic.

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
const BuildingsFixture := preload("res://test/test_buildings_spatial.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class FaultWork extends Work:
	## Explicit failure injection after the real paid-owner gate; normal tests execute actual Work unchanged.
	var fail_after_gate: bool = false
	var zero_potential: bool = false

	func _check_progress_row(row: int) -> StringName:
		"""Exercise the real abort path after physical preparation but before actual Work mutation."""
		return &"SYNTHETIC_POST_GATE_REFUSAL" if fail_after_gate else super._check_progress_row(row)

	func _produce_potential(resident: int, factor: int) -> int:
		"""Exercise a legitimate zero-accepted callback without inventing any completed work."""
		return 0 if zero_potential else super._produce_potential(resident, factor)

class SyntheticOwner extends Contract.Owner:
	## This labeled permission fixture never enters production; real Tips is independently composed.
	var construction: Construction = null
	var world: Vector2i = NULL_REF
	var route: WeakRef = null
	var funding: Funding = null
	var purpose_tag: int = Construction.PURPOSE_SPOIL_TIP
	var subject: Vector2i = Vector2i(11, 1)
	var operation: int = 2
	var quantity: int = 0
	var total: int = 4000
	var retained: int = 0
	var prepared: bool = false
	var project: Vector2i = NULL_REF
	var stage_project: Vector2i = NULL_REF
	var stage: int = -1
	var block_worker: StringName = &""
	var block_transition: StringName = &""
	var block_output: StringName = &""
	var completed: int = 0
	var cancelled: int = 0
	var publications: int = 0
	var discards: int = 0
	var facts_after_install: int = 0
	var completion_saw_paid_clear: bool = false
	var spatial: BuildingsFixture.Authority = null
	var math: IntMath.IntResult = IntMath.IntResult.new()

	func construction_owner() -> RefCounted:
		"""Even synthetic physical permission must name the exact actual owner composition."""
		return construction

	func world_ref() -> Vector2i:
		"""Use this fixture's real Directory World generation."""
		return world

	func purpose() -> int:
		"""Keep local physical handles in their declared purpose namespace."""
		return purpose_tag

	func prepared_order_into(candidate: Vector2i, kind: int, out: Contract.Quote) -> StringName:
		"""Only an explicitly prepared cold fixture order supplies its adopted phase facts."""
		if not prepared or candidate != subject or kind != operation:
			return &"SYNTHETIC_ORDER_NOT_PREPARED"
		_fill(out)
		return &""

	func project_facts_into(candidate: Vector2i, out: Contract.Quote) -> StringName:
		"""Read exact live accounting identity; actual installed furniture invalidates this candidate."""
		if candidate != project or not construction.is_live_project(candidate):
			return &"SYNTHETIC_PROJECT_STALE"
		if purpose_tag == Construction.PURPOSE_SPATIAL_FURNITURE \
				and construction.buildings().is_furniture_installed(subject):
			facts_after_install += 1
			return &"SYNTHETIC_ALREADY_INSTALLED"
		_fill(out)
		construction.remaining_mwu_into(candidate, math)
		out.remaining_mwu = math.value
		return &""

	func _fill(out: Contract.Quote) -> void:
		"""Use adopted prepare/compact facts or the actual protected furniture catalog."""
		out.subject = subject
		out.operation = operation
		out.quantity_milli = quantity
		out.total_mwu = total
		out.remaining_mwu = total - retained
		out.job_kind = Jobs.JOB_KIND_BUILD
		out.max_workers = 4
		if purpose_tag == Construction.PURPOSE_SPATIAL_FURNITURE:
			construction.bill_size_into(purpose_tag, operation, math)
			out.input_count = math.value
			for line: int in out.input_count:
				out.input_keys[line] = construction.material_key_at(purpose_tag, operation, line)
				construction.required_milli_into(purpose_tag, operation, line, math)
				out.input_milli[line] = math.value
		elif quantity > 0:
			out.job_kind = Jobs.JOB_KIND_KEEP
			out.input_count = 1
			out.input_keys[0] = &"excavated_earth"
			out.input_milli[0] = quantity

	func transition_refusal(candidate: Vector2i, action: int) -> StringName:
		"""Model actual tip-style staged proof, so abort/zero-progress cleanup is observable."""
		if candidate != project or stage >= 0:
			return &"SYNTHETIC_STAGE_BUSY"
		stage_project = candidate
		stage = action
		return block_transition

	func material_refusal(candidate: Vector2i, _container: Vector2i, _job: Vector2i) -> StringName:
		"""Only contact is synthetic; actual Inventory claims still fund the complete bill."""
		return &"" if candidate == project else &"SYNTHETIC_PROJECT_STALE"

	func output_refusal(_candidate: Vector2i, _container: Vector2i, _job: Vector2i, _tile: int) -> StringName:
		"""Inject physical output refusal independently of actual output capacity."""
		return block_output

	func worker_refusal(candidate: Vector2i, _job: Vector2i, _worker: Vector2i) -> StringName:
		"""Only contact is synthetic; actual Work/Gear must prove every worker and tool."""
		return block_worker if candidate == project else &"SYNTHETIC_PROJECT_STALE"

	func discard_transition(candidate: Vector2i, action: int) -> void:
		"""Only the exact prepared candidate clears; an unrelated Job cannot discard another project."""
		if action == Contract.ADMIT:
			prepared = false
		elif candidate == stage_project and action == stage:
			stage = -1
			stage_project = NULL_REF
			discards += 1

	func _authorized(candidate: Vector2i, action: int) -> bool:
		"""Every physical mutation depends on the actual router's exact synchronous callback."""
		var router: Router = route.get_ref() as Router if route != null else null
		return router != null and router.is_publishing(candidate, action, self)

	func publish_open(candidate: Vector2i) -> void:
		"""Attach only the real Construction identity allocated by the router."""
		if _authorized(candidate, Contract.ADMIT):
			project = candidate
			prepared = false

	func publish_work(candidate: Vector2i) -> void:
		"""Retain only real accepted Construction work in the productive window."""
		if _authorized(candidate, Contract.PRODUCTIVE) and stage == Contract.PRODUCTIVE:
			construction.remaining_mwu_into(candidate, math)
			retained = total - math.value
			publications += 1
			discard_transition(candidate, Contract.PRODUCTIVE)

	func publish_completion(candidate: Vector2i) -> void:
		"""Install a real pending piece only after actual paid receipts have committed away."""
		if not _authorized(candidate, Contract.COMMIT) or stage != Contract.COMMIT:
			return
		completion_saw_paid_clear = not funding.is_funded(candidate)
		if purpose_tag == Construction.PURPOSE_SPATIAL_FURNITURE:
			spatial.allow(Buildings.SPATIAL_FURNITURE_INSTALL, subject, NULL_REF)
			var installed: Buildings.OpResult = construction.buildings().install_spatial_furniture(subject)
			assert(installed.ok, "exact paid installation in synthetic geometry fixture")
			spatial.reset()
		completed += 1
		retained = 0
		discard_transition(candidate, Contract.COMMIT)
		project = NULL_REF

	func publish_cancellation(candidate: Vector2i) -> void:
		"""Retained labor survives actual refund settlement; this fixture publishes no physical stock."""
		if _authorized(candidate, Contract.CANCEL) and stage == Contract.CANCEL:
			cancelled += 1
			discard_transition(candidate, Contract.CANCEL)
			project = NULL_REF

	func embedded_earth_milli() -> int:
		"""Synthetic source fixture owns no earth; real Tips conservation has separate composed tests."""
		return 0

var _residents: Residents = null
var _priorities: Priorities = null
var _schedule: Schedule = null
var _jobs: Jobs = null
var _work: FaultWork = null
var _gear: Gear = null
var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _construction: Construction = null
var _sites: Sites = null
var _funding: Funding = null
var _space: PhysicalFixture.SpatialFixture = null
var _router: Router = null
var _owner: SyntheticOwner = null
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
	_work = FaultWork.new(_jobs)
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


func _new_owner() -> SyntheticOwner:
	"""Create one component-level synthetic physical owner, never a per-project production object."""
	var owner: SyntheticOwner = SyntheticOwner.new()
	owner.construction = _construction
	owner.world = _world
	owner.route = weakref(_router)
	owner.funding = _funding
	return owner


func after_each() -> void:
	"""Audit actual quantities and claim ownership before releasing the composed world."""
	assert_true(_inventory.audit().ok, "actual Inventory audit")
	assert_true(_pool.audit(_inventory).ok, "actual claims audit")
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


func _open(owner: SyntheticOwner = null) -> Vector2i:
	"""Request admission through the real typed router with no caller WU/bill inputs."""
	var actual: SyntheticOwner = _owner if owner == null else owner
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
	var result: Construction.OpResult = _router.start_work(project, 100)
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


func test_actual_work_completion_releases_tools_jobs_and_receipts_exactly_once() -> void:
	"""One paid operation reaches completion only through actual Work and its current owner callback."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	_finish_labor(project, job)
	assert_true(_owner.retained > 0, "physical fixture retained actual work")
	var carry: int = _work.wear_remainder_of(_resident).value
	assert_true(_router.complete_order(project).ok, "actual completion")
	assert_equal(_owner.completed, 1, "physical result once")
	assert_true(_owner.completion_saw_paid_clear, "physical publication follows actual WIP commit")
	assert_false(_construction.is_live_project(project), "actual accounting retires")
	assert_false(_jobs.directory().is_valid(job), "actual Job retires")
	assert_equal(_jobs.job_of(_resident), NULL_REF, "actual worker released")
	assert_equal(_work.tool_lot_of(_resident), NULL_REF, "actual tool claim released")
	assert_equal(_work.wear_remainder_of(_resident).value, carry, "wear carry survives")
	assert_false(_router.complete_order(project).ok, "duplicate cannot republish")


func test_material_payment_is_actual_and_direct_construction_or_work_calls_cannot_bypass_it() -> void:
	"""Delivery credits alone never authorize work; the shared arena must consume real inputs."""
	_owner.operation = 1
	_owner.quantity = 1001
	_owner.total = 251
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	assert_true(_jobs.set_state(_jobs.directory().get_typed_row(job), Jobs.JOB_STATE_WORK).ok, "adversarial ready state")
	var before: PackedByteArray = _image()
	assert_false(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "unpaid direct Work refused")
	assert_false(_construction.add_work_mwu(project, 100).ok, "direct paid counter refused")
	assert_false(_construction.begin_work(project).ok, "direct material consumption claim refused")
	assert_true(_image() == before, "no WU/XP/carry/wear or material changes")
	_start(project)
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "real input consumed")
	_finish_labor(project, job)
	assert_true(_router.complete_order(project).ok, "actual paid lifecycle completes")


func test_missing_tool_gate_and_stale_worker_refuse_before_any_productive_state_changes() -> void:
	"""Unset tools or a coincident replacement resident cannot earn free modular labor."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	var row: int = _jobs.directory().get_typed_row(job)
	assert_true(_jobs.set_tool_gate(row, Jobs.GATE_NOT_REQUIRED).ok, "adversarial unset tool gate")
	var before: PackedByteArray = _image()
	assert_false(_work.tick_solo(row).ok, "required tool cannot be disabled")
	assert_true(_image() == before, "unset gate refusal is byte-identical")
	assert_true(_jobs.set_tool_gate(row, Jobs.GATE_SATISFIED).ok, "restore actual requirement")
	_owner.block_worker = &"SYNTHETIC_ARRIVAL_LOST"
	before = _image()
	assert_equal(_work.tick_solo(row).error, _owner.block_worker, "fresh physical contact required")
	assert_true(_image() == before, "lost contact preserves all state")


func test_post_gate_refusal_and_zero_acceptance_discard_only_the_prepared_work_candidate() -> void:
	"""The actual tip-style owner can prepare the next tick after either kind of nonpublication."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	var row: int = _jobs.directory().get_typed_row(job)
	_work.fail_after_gate = true
	var before: PackedByteArray = _image()
	assert_equal(_work.tick_solo(row).error, &"SYNTHETIC_POST_GATE_REFUSAL", "real Work abort path")
	assert_true(_image() == before, "post-gate refusal changes no authoritative owner")
	assert_equal(_owner.stage, -1, "prepared proof discarded")
	_work.fail_after_gate = false
	_work.zero_potential = true
	var zero: Work.TickResult = _work.tick_solo(row)
	assert_true(zero.ok, "actual Work completes a zero-share tick")
	assert_equal(zero.accepted_mwu, 0, "no fake progress")
	assert_equal(_owner.stage, -1, "zero share also discards prepared proof")
	assert_equal(_owner.publications, 0, "neither tick publishes earned work")
	_work.zero_potential = false
	assert_true(_work.tick_solo(row).ok, "next valid tick succeeds")
	assert_equal(_owner.publications, 1, "one actual positive publication")


func test_direct_reduced_job_counter_and_false_publication_never_become_paid_work() -> void:
	"""Matching job numbers and changed counters do not create Work's same-call-stack attestation."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	assert_false(_router.is_publishing(project, Contract.COMMIT, _owner), "outside callback refuses")
	_owner.publish_completion(project)
	assert_equal(_owner.completed, 0, "direct physical publication refused")
	var row: int = _jobs.directory().get_typed_row(job)
	assert_true(_jobs.set_remaining_mwu(row, 1).ok, "adversarial generic Job counter edit")
	_router.accept_work_tick(job)
	assert_equal(_owner.retained, 0, "no manual progress accepted")
	var before: PackedByteArray = _image()
	assert_false(_work.tick_solo(row).ok, "counter divergence refuses")
	assert_true(_image() == before, "divergent state changes nothing further")


func test_pause_releases_actual_workers_and_rebind_resume_preserves_paid_material_and_work() -> void:
	"""Pausing owns worker/claim departure; resume validates actual equipment without duplicate payment."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	var row: int = _jobs.directory().get_typed_row(job)
	assert_true(_work.tick_solo(row).ok, "one actual productive tick")
	var retained: int = _owner.retained
	assert_true(_router.set_paused(project, true).ok, "actual pause")
	assert_equal(_jobs.job_of(_resident), NULL_REF, "worker departs")
	assert_equal(_work.tool_lot_of(_resident), NULL_REF, "tool claim released")
	assert_true(_funding.is_funded(project), "paid WIP remains")
	var before: PackedByteArray = _image()
	assert_false(_work.tick_solo(row).ok, "direct Work honors actual pause")
	assert_true(_image() == before, "paused tick changes nothing")
	assert_true(_router.set_paused(project, false).ok, "remove hold")
	_assign(job, _resident)
	assert_true(_router.resume_work(project).ok, "actual worker resumes")
	assert_equal(_owner.retained, retained, "resume creates no labor")
	assert_true(_work.tick_solo(row).ok, "subsequent real tick")
	assert_true(_owner.retained > retained, "real work continues")


func test_cancel_unassigned_order_and_blocked_started_refund_leave_no_fake_completion() -> void:
	"""Unstarted physical ownership can retire; blocked paid refunds retain receipts for exact retry."""
	var first: Vector2i = _open()
	assert_true(_router.cancel_order(first).ok, "unassigned order cancels")
	assert_false(_construction.is_live_project(first), "unassigned accounting retires")
	_owner.quantity = 1001
	_owner.operation = 1
	_owner.total = 251
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	assert_true(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "retained paid work")
	var retained: int = _owner.retained
	var blocked: Vector2i = _inventory.create_container(_world, 1, -1, 0, true).ref
	assert_false(_router.cancel_order(project, blocked).ok, "real refund capacity refuses")
	assert_true(_funding.is_funded(project), "blocked WIP retained")
	assert_equal(_owner.retained, retained, "actual labor retained")
	assert_true(_router.cancel_order(project, _output).ok, "same refund retries")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 800, "exact 80 percent refund once")
	assert_equal(_funding.purpose_cancellation_loss_milli(7, _items.compiled_id(&"excavated_earth")), 201, "exact historical sink")
	assert_equal(_owner.retained, retained, "cancel keeps labor")
	assert_equal(_owner.completed, 0, "no physical completion invented")


func test_late_requester_job_prevents_completion_and_every_direct_unbound_job_tick() -> void:
	"""A second Job cannot share the requester and silently double the builder limit or become orphaned."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	var late: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, 4000, 0)
	assert_true(_jobs.set_requester(late.value, project).ok, "late requester")
	assert_false(_router.bind_job(project, late.ref).ok, "duplicate primary refused")
	assert_false(_work.tick_solo(late.value).ok, "unregistered requester cannot work")
	_finish_labor(project, job)
	var before: PackedByteArray = _image()
	assert_false(_router.complete_order(project).ok, "late Job prevents unsafe retirement")
	assert_true(_image() == before, "unsafe completion changes no physical/accounting state")
	assert_true(_jobs.destroy_job(late.value).ok, "caller resolves its unaccepted Job")
	assert_true(_router.complete_order(project).ok, "same finished paid project retries")


func _member(project: Vector2i, coordinator: Vector2i, resident: int, accept: bool = true) -> Vector2i:
	"""Use the existing party contract: member work stays zero; the actual coordinator holds all progress."""
	var primary: int = _jobs.directory().get_typed_row(coordinator)
	var made: Jobs.OpResult = _jobs.create_job(_jobs.kind_of(primary).value, 1, 0, 0, 0)
	assert_true(made.ok, "actual member Job")
	assert_true(_jobs.set_requester(made.value, project).ok, "actual member requester")
	assert_true(_jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok, "member tool required")
	assert_true(_jobs.set_coordinator(made.value, primary).ok, "actual zero-progress membership")
	if accept:
		assert_true(_router.bind_member(project, made.ref).ok, "member explicitly accepted")
	_assign(made.ref, resident)
	return made.ref


func test_party_has_one_progress_owner_and_departure_does_not_halt_the_other_workers() -> void:
	"""Actual party work caps the shared phase once, and member replacement preserves labor and carry."""
	var project: Vector2i = _open()
	var coordinator: Vector2i = _job(project, true)
	var first: Vector2i = _member(project, coordinator, _resident)
	var second_resident: int = _spawn_worker()
	var second: Vector2i = _member(project, coordinator, second_resident)
	_start(project)
	var row: int = _jobs.directory().get_typed_row(coordinator)
	var tick: Work.TickResult = _work.tick_party(row)
	assert_true(tick.ok, "real two-member tick")
	assert_equal(tick.contributor_count, 2, "each actual member contributes")
	assert_equal(_jobs.remaining_mwu_of(_jobs.directory().get_typed_row(first)).value, 0, "first has no duplicate work")
	assert_equal(_jobs.remaining_mwu_of(_jobs.directory().get_typed_row(second)).value, 0, "second has no duplicate work")
	assert_true(_work.release_tool_claim(second_resident).ok, "worker relinquishes actual tool")
	assert_true(_jobs.release_worker(second_resident).ok, "worker departs actual membership")
	tick = _work.tick_party(row)
	assert_true(tick.ok, "remaining member continues")
	assert_equal(tick.contributor_count, 1, "no phantom second contribution")
	_assign(second, second_resident)
	assert_true(_router.resume_work(project).ok, "replacement/current worker resumes actual role")
	_finish_labor(project, coordinator)
	assert_true(_router.complete_order(project).ok, "whole party retires only after one paid completion")
	assert_false(_jobs.directory().is_valid(first), "first member retired")
	assert_false(_jobs.directory().is_valid(second), "second member retired")
	assert_equal(_owner.completed, 1, "one physical completion")


func test_party_rejects_unaccepted_fifth_and_member_direct_work_without_mutating_any_owner() -> void:
	"""A late linked Job cannot bypass explicit acceptance or the adopted four-worker ceiling."""
	var project: Vector2i = _open()
	var coordinator: Vector2i = _job(project, true)
	var first: Vector2i = _member(project, coordinator, _resident)
	for index: int in 3:
		var _member_ref: Vector2i = _member(project, coordinator, _spawn_worker())
	_start(project)
	var fifth: Vector2i = _member(project, coordinator, _spawn_worker(), false)
	var before: PackedByteArray = _image()
	assert_false(_router.bind_member(project, fifth).ok, "fifth exceeds actual cap")
	assert_false(_work.tick_party(_jobs.directory().get_typed_row(coordinator)).ok, "unaccepted member blocks ambiguity")
	assert_false(_work.tick_solo(_jobs.directory().get_typed_row(first)).ok, "member cannot act as independent primary")
	assert_true(_image() == before, "no work, XP, material or tool mutation on any refusal")
	var resident: int = _jobs.directory().get_typed_row(_jobs.worker_of(_jobs.directory().get_typed_row(fifth)))
	assert_true(_work.release_tool_claim(resident).ok, "release refused late member's actual tool")
	assert_true(_jobs.release_worker(resident).ok, "release refused late worker")
	assert_true(_jobs.destroy_job(_jobs.directory().get_typed_row(fifth)).ok, "remove refused late Job")
	assert_true(_work.tick_party(_jobs.directory().get_typed_row(coordinator)).ok, "accepted four can retry")


func test_stale_job_generation_and_orphan_tool_claim_cannot_be_silently_retired_or_rebound() -> void:
	"""A row reused outside its owner stays an explicit stale binding, never a new free work identity."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	assert_true(_jobs.release_worker(_resident).ok, "adversarial detached worker with tool still claimed")
	var before: PackedByteArray = _image()
	assert_false(_router.cancel_order(project).ok, "orphan Work/Gear claim prevents unsafe retirement")
	assert_true(_image() == before, "orphan refusal preserves physical and paid owners")
	assert_true(_work.release_tool_claim(_resident).ok, "resolve actual abandoned tool claim")
	var row: int = _jobs.directory().get_typed_row(job)
	assert_true(_jobs.destroy_job(row).ok, "adversarial owner-external Job removal")
	var reused: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, 4000, 0)
	assert_equal(reused.value, row, "actual typed row reused")
	assert_true(reused.ref != job, "full generation changes")
	assert_true(_jobs.set_requester(reused.value, project).ok, "coincident replacement requester")
	before = _image()
	assert_false(_router.bind_job(project, reused.ref).ok, "retained old binding cannot be overwritten")
	assert_false(_work.tick_solo(reused.value).ok, "recycled identity has no paid permission")
	assert_false(_router.cancel_order(project).ok, "no silent lost-generation retirement")
	assert_equal(_router.job_of(project), NULL_REF, "stale primary diagnosed as absent")
	assert_true(_image() == before, "all replacement refusals preserve accounting and identity history")


func test_refused_initializer_and_foreign_numeric_aliases_never_replace_actual_bindings() -> void:
	"""Actual objects matter even when two worlds allocate identical catalog and entity numbers."""
	var foreign_inventory: Inventory = Inventory.new(16, 128)
	var foreign_items: Items = Items.new()
	assert_true(foreign_items.load_default(foreign_inventory).ok, "coincident foreign catalog")
	assert_equal(foreign_items.compiled_id(&"wood"), _items.compiled_id(&"wood"), "same number proves no ownership")
	var before: PackedByteArray = _image()
	var foreign: Router = Router.new(_construction, foreign_inventory, _pool, foreign_items, _jobs, _work, _sites)
	assert_equal(foreign.initialization_refusal(), Contract.REFUSE_AUTHORITY, "exact Funding composition refuses")
	assert_null(foreign.construction_owner(), "failed initializer grants no owner")
	assert_null(foreign.item_definitions_owner(), "failed initializer grants no catalog")
	assert_equal(foreign.state_bytes().size(), 0, "invalid router allocates no column arena")
	assert_equal(_construction.modular_authority(), _router, "Construction binding untouched")
	assert_equal(_work.modular_authority(), _router, "Work binding untouched")
	var refused: Router = Router.new(null, _inventory, _pool, _items, _jobs, _work, _sites)
	assert_false(refused.start_work(NULL_REF, 0).ok, "failed null composition safely refuses public mutation")
	assert_true(_image() == before, "failed initializations mutate no actual owner")
	assert_equal(_router.state_bytes().size(), 4 * 4 * Jobs.JOB_CAPACITY, "four bounded authoritative I32 columns")
	assert_equal(_router.legacy_save_refusal(), Router.REFUSE_SAVE, "new bindings cannot be silently omitted from old save")


func test_late_catalog_rebinding_refuses_work_before_any_payment_xp_or_tool_change() -> void:
	"""Successful admission does not permanently bless a catalog later wired into another Inventory."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	var foreign_inventory: Inventory = Inventory.new(16, 128)
	assert_true(_items.load_default(foreign_inventory).ok, "legitimate loader can register into another owner")
	var before: PackedByteArray = _image()
	assert_null(_router.item_definitions_owner(), "live shared composition now refuses")
	assert_false(_router.is_bound_owner(_owner), "old physical binding is no longer qualified")
	assert_false(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "late foreign wiring stops actual Work")
	assert_false(_router.resume_work(project).ok, "resume cannot bypass live composition proof")
	assert_true(_image() == before, "no actual worker, wear, WIP, material or accounting changes")


func _furniture_owner() -> SyntheticOwner:
	"""Create a real underground Kitchen and pending catalog bench behind explicit synthetic space proof."""
	var owner: SyntheticOwner = _new_owner()
	var buildings: Buildings = _construction.buildings()
	owner.spatial = BuildingsFixture.Authority.new()
	owner.spatial.owner = weakref(buildings)
	assert_true(buildings.bind_spatial_authority(owner.spatial).ok, "actual Buildings composition")
	owner.spatial.allow(Buildings.SPATIAL_ROOM_CREATE, NULL_REF, NULL_REF, Buildings.ROOM_TYPE_KITCHEN)
	var room: Buildings.OpResult = buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN)
	assert_true(room.ok, "real permanent Kitchen")
	owner.operation = int(Catalog.FURNITURE_DEFINITION["kitchen_bench"])
	owner.spatial.allow(Buildings.SPATIAL_FURNITURE_CREATE, NULL_REF, room.ref, owner.operation)
	var piece: Buildings.OpResult = buildings.stage_spatial_furniture(room.ref, owner.operation, 0)
	assert_true(piece.ok, "real pending bench identity")
	owner.spatial.reset()
	owner.purpose_tag = Construction.PURPOSE_SPATIAL_FURNITURE
	owner.subject = piece.ref
	owner.total = _construction.definitions().furniture_work_mwu_of(owner.operation)
	assert_true(_router.bind_owner(owner).ok, "same shared router binds separate actual furniture purpose")
	return owner


func test_actual_pending_furniture_installs_after_paid_work_and_retirement_needs_no_post_install_quote() -> void:
	"""Actual installation invalidates pending-source facts, so all fallible quote reads must already be done."""
	var owner: SyntheticOwner = _furniture_owner()
	var project: Vector2i = _open(owner)
	var job: Vector2i = _job(project)
	var buildings: Buildings = _construction.buildings()
	var room: Vector2i = buildings.room_ref_of_furniture(owner.subject)
	assert_false(buildings.is_furniture_installed(owner.subject), "blueprint offers no installed piece")
	assert_equal(buildings.count_furniture_of_kind(room, owner.operation).value, 0, "no service presence before payment")
	_start(project)
	assert_false(buildings.is_furniture_installed(owner.subject), "material payment alone cannot install")
	_finish_labor(project, job)
	assert_true(_router.complete_order(project).ok, "actual complete bill/work installs")
	assert_true(buildings.is_furniture_installed(owner.subject), "paid pending identity becomes installed")
	assert_equal(buildings.count_furniture_of_kind(room, owner.operation).value, 1, "only installed catalog presence publishes")
	assert_true(owner.completion_saw_paid_clear, "Inventory receipt commit precedes physical installation")
	assert_equal(owner.facts_after_install, 0, "retirement never asks now-invalid pending facts")
	assert_false(_construction.is_live_project(project), "real project safely retired")
	assert_false(_jobs.directory().is_valid(job), "real furnishing Job safely retired")
	assert_equal(owner.completed, 1, "one installation publication")


func test_wrong_job_and_owner_cannot_discard_or_publish_another_prepared_productive_stage() -> void:
	"""Exact callback identities also govern preparation cleanup, not only positive publication."""
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	assert_equal(_router.work_tick_refusal(job), &"", "explicit cold test prepares actual productive proof")
	assert_equal(_owner.stage, Contract.PRODUCTIVE, "candidate is prepared")
	_router.discard_work_tick(Vector2i(job.x, job.y + 1))
	_router.discard_work_tick(NULL_REF)
	var other: SyntheticOwner = _new_owner()
	assert_false(_router.is_publishing(project, Contract.PRODUCTIVE, other), "foreign same-number owner is not actual callback")
	assert_equal(_owner.stage, Contract.PRODUCTIVE, "wrong identities cannot discard the valid candidate")
	_router.discard_work_tick(job)
	assert_equal(_owner.stage, -1, "exact identity clears its own scratch")
	assert_true(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "subsequent actual tick succeeds")
	assert_equal(_owner.publications, 1, "only actual Work publishes")


func test_work_binding_preflight_cannot_strand_an_unbound_construction_owner() -> void:
	"""A competing Work owner is diagnosed before either owner gets a partial router binding."""
	var residents: Residents = Residents.new()
	var world: Vector2i = residents.directory().create(Directory.KIND_WORLD)
	var jobs: Jobs = Jobs.new(residents, Priorities.new(), Schedule.new(residents.needs()))
	var work: Work = Work.new(jobs)
	var inventory: Inventory = Inventory.new(4, 8)
	var items: Items = Items.new()
	assert_true(items.load_default(inventory).ok, "actual second catalog")
	var pool: Reservations = Reservations.new()
	var gear: Gear = Gear.new(4)
	assert_true(gear.bind_equipment(inventory, residents.directory(), residents).ok, "actual second equipment")
	assert_true(work.bind_gear(gear).ok, "actual second wear owner")
	var construction: Construction = Construction.new(Buildings.new(residents.directory()))
	var spatial: PhysicalFixture.SpatialFixture = PhysicalFixture.SpatialFixture.new()
	spatial.world = world
	var sites: Sites = Sites.new(construction, inventory, pool, items, jobs, work, spatial, 8, 2)
	assert_equal(sites.initialization_refusal(), &"", "actual second physical ledger")
	var competing: Contract = Contract.new()
	assert_true(work.bind_modular_authority(competing).ok, "existing competing Work owner")
	var refused: Router = Router.new(construction, inventory, pool, items, jobs, work, sites)
	assert_equal(refused.initialization_refusal(), Contract.REFUSE_AUTHORITY, "both-owner preflight refuses")
	assert_false(construction.has_modular_binding(), "no half-bound Construction zombie")
	assert_equal(work.modular_authority(), competing, "previous Work owner remains exact")
	assert_equal(refused.state_bytes().size(), 0, "refused candidate allocates no Job arena")


func test_retained_zero_work_requires_full_actual_repayment_and_can_complete_without_productive_tick() -> void:
	"""Retained labor is no free materials discount, and zero remaining work does not need fake ticking."""
	_owner.operation = 1
	_owner.quantity = 1001
	_owner.total = 251
	_owner.retained = _owner.total
	var project: Vector2i = _open()
	var _job_ref: Vector2i = _job(project)
	var before: PackedByteArray = _image()
	assert_false(_router.start_work(project, 100).ok, "unpaid retained work cannot begin")
	assert_false(_router.complete_order(project).ok, "unpaid retained work cannot complete")
	assert_true(_image() == before, "no free paid-owner transition")
	_start(project)
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "full adopted input repaid")
	assert_equal(_funding.reserved_output_mass_g(project), 0, "funded no-output phase is distinct from absent WIP")
	assert_true(_router.complete_order(project).ok, "zero work completion uses fresh actual paid publication")
	assert_equal(_owner.publications, 0, "no fake productive tick")
	assert_equal(_owner.completed, 1, "one paid physical completion")
	assert_equal(_funding.reserved_output_mass_g(project), -1, "retired receipts explicitly absent")


func test_late_generic_tool_gate_or_child_never_contributes_to_a_paid_party() -> void:
	"""A member cannot remove its required-tool declaration or substitute a child to gain work."""
	var project: Vector2i = _open()
	var coordinator: Vector2i = _job(project, true)
	var first: Vector2i = _member(project, coordinator, _resident)
	var second: Vector2i = _member(project, coordinator, _spawn_worker())
	_start(project)
	var first_row: int = _jobs.directory().get_typed_row(first)
	var primary: int = _jobs.directory().get_typed_row(coordinator)
	assert_true(_jobs.set_tool_gate(first_row, Jobs.GATE_NOT_REQUIRED).ok, "adversarial unset declaration")
	var before: PackedByteArray = _image()
	assert_false(_work.tick_party(primary).ok, "unset mandatory gate is not silently skipped")
	assert_true(_image() == before, "unset gate creates no party labor")
	assert_true(_jobs.set_tool_gate(first_row, Jobs.GATE_SATISFIED).ok, "restore declared requirement")
	assert_true(_work.release_tool_claim(_resident).ok, "actual first member release")
	assert_true(_jobs.release_worker(_resident).ok, "actual first member departs")
	var child: int = _spawn_worker(Residents.LIFE_STAGE_CHILD)
	_assign(first, child)
	assert_true(_jobs.set_state(first_row, Jobs.JOB_STATE_WORK).ok, "adversarial productive child assignment")
	before = _image()
	assert_false(_work.tick_party(primary).ok, "child may not do this paid modular labor")
	assert_true(_image() == before, "child refusal creates no adult or child labor")
	assert_true(_jobs.directory().is_valid(second), "unrelated accepted member still owned")


func test_unrelated_actual_jobs_keep_existing_work_behavior_and_expired_purpose_never_becomes_permission() -> void:
	"""Installing the shared paid router does not reinterpret ordinary Jobs as paid operations."""
	var ordinary: Jobs.OpResult = _jobs.create_job(Jobs.JOB_KIND_BUILD, 1, 0, 80, 0)
	assert_true(_jobs.set_tool_gate(ordinary.value, Jobs.GATE_SATISFIED).ok, "ordinary actual tool gate")
	_assign(ordinary.ref, _resident)
	assert_true(_jobs.set_state(ordinary.value, Jobs.JOB_STATE_WORK).ok, "ordinary actual job readiness")
	var tick: Work.TickResult = _work.tick_solo(ordinary.value)
	assert_true(tick.ok, "ordinary Work still runs")
	assert_equal(tick.accepted_mwu, 80, "ordinary actual capped contribution unchanged")
	assert_equal(_owner.publications, 0, "ordinary Job cannot publish a physical operation")
	assert_true(_work.release_tool_claim(_resident).ok, "ordinary tool claim released")
	assert_true(_jobs.release_worker(_resident).ok, "ordinary worker released")
	assert_true(_jobs.destroy_job(ordinary.value).ok, "ordinary caller retires its own Job")
	var project: Vector2i = _open()
	var job: Vector2i = _job(project)
	_start(project)
	_owner = null
	var before: PackedByteArray = _image()
	assert_false(_work.tick_solo(_jobs.directory().get_typed_row(job)).ok, "expired purpose owner cannot supply paid proof")
	assert_false(_router.cancel_order(project).ok, "expired purpose cannot silently lose source ownership")
	assert_equal(_router.embedded_earth_milli(), -1, "missing ledger is not assumed zero")
	assert_false(_router.bind_owner(_new_owner()).ok, "new owner cannot replace retained purpose history")
	assert_true(_image() == before, "expired binding never mutates paid or worker state")
