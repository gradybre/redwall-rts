extends "res://test/framework/test_case.gd"
## Actual Tips/Router/Construction/Funding/Jobs/Work/Gear composition.
## Only terrain, route and contact permission is synthetic; no fake source or payment publisher.

const Tips := preload("res://scripts/core/spoil_tips.gd")
const Spoil := preload("res://scripts/core/spoil_work.gd")
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
const NULL_REF: Vector2i = Vector2i(-1, 0)
const INITIAL_EARTH: int = 10000

class ContactFixture extends Spoil.Contacts:
	## Labeled synthetic physical proof; the actual owner/router must still authorize each publication.
	var tips: Tips = null
	var construction: Construction = null
	var world: Vector2i = NULL_REF
	var bound: bool = true
	var refuse_admission: StringName = &""
	var refuse_transition: StringName = &""
	var refuse_worker: StringName = &""
	var refuse_output: StringName = &""
	var discards: int = 0
	var publications: int = 0
	var last_published_action: int = -1

	func exact_binding(actual: Tips, owner: Construction, identity: Vector2i) -> bool:
		"""Even the isolated contact fixture requires the exact real stores and live World."""
		return bound and actual == tips and owner == construction and identity == world \
			and owner.directory().is_valid_of_kind(identity, Directory.KIND_WORLD)

	func admission_refusal(_tip: Vector2i, _tile: int, _operation: int, _quantity: int) -> StringName:
		"""Inject a cold contact refusal without allocating a physical fake tip."""
		return refuse_admission

	func transition_refusal(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, _action: int) -> StringName:
		"""Only this test's geometry permission is synthetic; the payment/work stores stay actual."""
		return refuse_transition

	func material_refusal(_tip: Vector2i, _project: Vector2i, _container: Vector2i,
			_job: Vector2i) -> StringName:
		"""Real Inventory and Reservations independently require exact delivered inputs."""
		return &""

	func output_refusal(_tip: Vector2i, _project: Vector2i, _container: Vector2i,
			_job: Vector2i, _promotion_tile: int) -> StringName:
		"""Block contact independently of the real finite output reservation."""
		return refuse_output

	func worker_refusal(_tip: Vector2i, _project: Vector2i, _job: Vector2i,
			_worker: Vector2i) -> StringName:
		"""Inject a fresh contact failure while actual Jobs/Gear prove the worker/tool."""
		return refuse_worker

	func discard_transition(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, _action: int) -> void:
		"""Observe rejected proof cleanup without releasing actual source or Inventory state."""
		discards += 1

	func publish_transition(_tip: Vector2i, _tile: int, _project: Vector2i,
			_operation: int, action: int) -> void:
		"""Count actual router-authorized publication; this fixture changes no map truth."""
		publications += 1
		last_published_action = action

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
var _tips: Tips = null
var _owner: Spoil = null
var _router: Router = null
var _contacts: ContactFixture = null
var _world: Vector2i = NULL_REF
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _earth: Vector2i = NULL_REF
var _tool: Vector2i = NULL_REF
var _resident: int = -1
var _math: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""One actual shared material/work world; imported starting earth is captured before Sites binds."""
	_residents = Residents.new()
	_world = _residents.directory().create(Directory.KIND_WORLD)
	_priorities = Priorities.new()
	_schedule = Schedule.new(_residents.needs())
	_jobs = Jobs.new(_residents, _priorities, _schedule)
	_work = Work.new(_jobs)
	_inventory = Inventory.new(16, 64)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual authored item definitions")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear composition")
	assert_true(_work.bind_gear(_gear).ok, "actual Work equipment composition")
	_store = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_output = _inventory.create_container(_world, 100000, -1, 0, true).ref
	_earth = _inventory.create_lot(_store, _items.compiled_id(&"excavated_earth"), INITIAL_EARTH,
		int(Catalog.QUALITY["PLAIN"]), Catalog.PROVENANCE_ORDINARY, -1, 0, 0).ref
	_construction = Construction.new(Buildings.new(_residents.directory()))
	_bind_operations()
	_spawn_worker()


func _bind_operations() -> void:
	"""Actual Sites owns the single receipt arena, shared by the real Router and Tips publisher."""
	_space = PhysicalFixture.SpatialFixture.new()
	_space.world = _world
	_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _space, 64, 8)
	assert_equal(_sites.initialization_refusal(), &"", "actual Sites composition")
	_funding = _sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work)
	assert_true(_funding != null, "one actual shared receipt owner")
	_router = Router.new(_construction, _inventory, _pool, _items, _jobs, _work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual modular Router")
	_tips = Tips.new(_construction, _world, 4)
	_owner = Spoil.new()
	_contacts = ContactFixture.new()
	_contacts.tips = _tips
	_contacts.construction = _construction
	_contacts.world = _world
	assert_equal(_owner.configure(_tips, _router, _contacts), &"", "actual tip operation publisher")


func _spawn_worker() -> void:
	"""Create an eligible real adult and equip a durable actual tool."""
	_resident = _residents.spawn_with_stage(&"mouse", Residents.LIFE_STAGE_ADULT).value
	assert_true(_priorities.spawn(_resident).ok, "worker priorities")
	assert_true(_schedule.spawn(_resident, _schedule.default_template_id().value).ok, "worker schedule")
	assert_true(_schedule.resolve(_resident, 8, false).ok, "real working hours")
	assert_true(_jobs.spawn_agent(_resident).ok, "actual JobAgent")
	for need: int in Needs.NEED_COUNT:
		var previous: int = _residents.needs().need_of(_resident, need).value
		assert_true(_residents.needs().apply_need_event(_resident, need, 5000 - previous).ok, "base-rate mood")
	_tool = _inventory.create_lot(_store, _items.compiled_id(&"tool"), Gear.GEAR_LOT_QUANTITY_MILLI,
		1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0).ref
	assert_true(_gear.create_gear(_inventory, _items, _tool, Gear.MANUFACTURE_BASIC).ok, "actual durable tool")
	assert_true(_gear.equip(_tool, _residents.ref_of(_resident)).ok, "actual resident equipment")


func after_each() -> void:
	"""Audit actual accounts after every refusal and release component ownership without cycles."""
	assert_true(_inventory.audit().ok, "actual Inventory audit")
	assert_true(_pool.audit(_inventory).ok, "actual claim ownership audit")
	if _contacts != null and _contacts.bound:
		assert_equal(_tips.audit_refusal(), &"", "actual source ledger audit")
		assert_equal(_sites.earth_conservation_refusal(), &"", "whole-world earth conserved")
	_contacts = null
	_owner = null
	_tips = null
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


func _designate(tile: int = 30) -> Vector2i:
	"""Only real prepared owner facts can allocate a purpose-qualified Construction project."""
	assert_equal(_owner.prepare_tip_order(tile), &"", "physical tip candidate")
	var tip: Vector2i = _owner.prepared_subject()
	var opened: Construction.OpResult = _router.open_order(_owner, tip, Tips.PREPARE)
	assert_true(opened.ok, "actual preparation order: %s" % opened.error)
	assert_equal(_tips.project_of(tip), opened.ref, "real project attached to source ledger")
	return tip


func _open(tip: Vector2i, operation: int, quantity: int = 0) -> Vector2i:
	"""Keep quantity in the actual prepared purpose owner, never pass caller prices to Router."""
	assert_equal(_owner.prepare_operation(tip, operation, quantity), &"", "actual immutable quantity order")
	var opened: Construction.OpResult = _router.open_order(_owner, tip, operation)
	assert_true(opened.ok, "real tip operation: %s" % opened.error)
	return opened.ref


func _physical_image() -> PackedByteArray:
	"""Byte comparison covers actual stock, claims, paid receipts, Construction and source history."""
	var image: PackedByteArray = _inventory.state_bytes()
	image.append_array(_pool.state_bytes())
	image.append_array(_funding.state_bytes())
	image.append_array(_construction.state_bytes())
	image.append_array(_tips.state_bytes())
	image.append_array(_router.state_bytes())
	return image


func _start(tip: Vector2i, output: Vector2i = Vector2i(-1, 0)) -> int:
	"""Bind an actual Job, material claims, worker and tool, then enter the real paid START transaction."""
	var project: Vector2i = _tips.project_of(tip)
	var quote: Contract.Quote = Contract.Quote.new()
	assert_equal(_owner.project_facts_into(project, quote), &"", "actual operation facts")
	var job: int = _jobs.create_job(quote.job_kind, 0, 0, quote.remaining_mwu, 0).value
	assert_true(_jobs.set_requester(job, project).ok, "full actual Construction requester")
	assert_true(_jobs.set_tool_gate(job, Jobs.GATE_SATISFIED).ok, "mandatory real tool")
	assert_true(_router.bind_job(project, _jobs.ref_of(job)).ok, "exact real Job accepted")
	assert_true(_router.bind_material_container(project, _store).ok, "real delivery contact")
	_deliver_inputs(project, job, quote)
	assert_true(_jobs.assign_worker(_resident, job).ok, "actual worker assignment")
	assert_true(_work.claim_tool_for_work(_resident, _tool).ok, "actual equipped tool claim")
	var started: Construction.OpResult = _router.start_work(project, 0, output)
	assert_true(started.ok, "actual paid work starts: %s" % started.error)
	return job


func _deliver_inputs(project: Vector2i, job: int, quote: Contract.Quote) -> void:
	"""Claim only real starting/refunded loose material; quantities come from the adopted owner quote."""
	if quote.input_count == 0:
		return
	for index: int in quote.input_count:
		_claim_input(job, _items.compiled_id(quote.input_keys[index]), quote.input_milli[index])
	var delivered: Construction.OpResult = _router.record_deliveries(project)
	assert_true(delivered.ok, "actual claims credited: %s" % delivered.error)


func _claim_input(job: int, item: int, quantity: int) -> void:
	"""A real refund may leave several distinct lots; reserve the complete bill across their actual stock."""
	var claims: PackedInt64Array = PackedInt64Array()
	var remaining: int = quantity
	var count: int = 0
	var lot: Vector2i = _inventory.container_first_lot(_store)
	while lot != NULL_REF and remaining > 0:
		if _inventory.lot_item_id(lot) == item:
			var take: int = mini(remaining, _inventory.lot_available_milli(lot))
			if take > 0:
				claims.append_array(PackedInt64Array([lot.x, lot.y, Reservations.PURPOSE_MODULAR_INPUT, take, 100000]))
				remaining -= take
				count += 1
		lot = _inventory.container_next_lot(lot)
	assert_equal(remaining, 0, "complete adopted input exists in real lots")
	assert_true(_pool.claim_batch(_jobs.ref_of(job), claims, count, _inventory).ok, "actual complete input claim")


func _finish_work(job: int) -> void:
	"""Advance the real integer Work system; no test writes Construction or source progress."""
	var ticks: int = 0
	while _jobs.remaining_mwu_into(job, _math) and _math.value > 0 and ticks < 1000:
		var result: Work.TickResult = _work.tick_solo(job)
		assert_true(result.ok, "actual productive work: %s" % result.error)
		if not result.ok:
			return
		ticks += 1
	assert_true(_jobs.remaining_mwu_into(job, _math), "actual Job still live before completion")
	assert_equal(_math.value, 0, "all paid work earned")


func _complete(tip: Vector2i, output: Vector2i = Vector2i(-1, 0)) -> void:
	"""Run one complete actual paid source operation and verify the shared physical accounts."""
	var project: Vector2i = _tips.project_of(tip)
	_finish_work(_start(tip, output))
	var completed: Construction.OpResult = _router.complete_order(project)
	assert_true(completed.ok, "real source commit: %s" % completed.error)
	assert_false(_construction.is_live_project(project), "project retires after publication")
	assert_equal(_tips.project_of(tip), NULL_REF, "source releases only the completed project")
	assert_equal(_sites.earth_conservation_refusal(), &"", "all actual earth accounts conserved")


func _prepared_tip() -> Vector2i:
	"""Physical preparation requires the actual worker to finish its adopted4000mWU."""
	var tip: Vector2i = _designate()
	_complete(tip)
	assert_true(_tips.is_prepared(tip), "actual paid preparation complete")
	return tip


func _worker_image() -> PackedByteArray:
	"""Compare authoritative work, XP, claims, wear and job progress around blocked productive ticks."""
	var image: PackedByteArray = _physical_image()
	image.append_array(_work.state_bytes())
	image.append_array(_gear.state_bytes())
	image.append_array(_jobs.state_bytes())
	image.append_array(_residents.state_bytes())
	return image


func test_actual_admission_has_separate_purpose_and_no_payment_or_direct_publication() -> void:
	"""A designated footprint is unfinished, carries a real project and grants no paid source mutation."""
	var tip: Vector2i = _designate()
	var project: Vector2i = _tips.project_of(tip)
	assert_true(_construction.purpose_into(project, _math), "actual project purpose")
	assert_equal(_math.value, Construction.PURPOSE_SPOIL_TIP, "not fake excavation/building accounting")
	assert_equal(_tips.tile_of(tip), 30, "actual exterior footprint retained")
	assert_false(_tips.is_prepared(tip), "designation alone is unfinished")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), INITIAL_EARTH, "no prepayment")
	var before: PackedByteArray = _physical_image()
	assert_false(_tips.publish_work(tip, project) == &"", "direct source work lacks real publication window")
	assert_false(_tips.publish_completion(tip, project) == &"", "direct completion cannot mint stock")
	_owner.publish_open(project)
	assert_equal(_physical_image(), before, "all actual paid and physical accounts unchanged")
	assert_equal(_contacts.publications, 1, "only exact actual ADMIT published")


func test_contact_refusal_precedes_project_and_tip_generation_allocation() -> void:
	"""Blocked ground leaves no retired project, consumed tip generation or accepted footprint."""
	assert_equal(_owner.prepare_tip_order(30), &"", "candidate stages")
	var tip: Vector2i = _owner.prepared_subject()
	_contacts.refuse_admission = &"SYNTHETIC_TERRAIN_BLOCKED"
	var before: PackedByteArray = _physical_image()
	var directory: PackedByteArray = _construction.directory().state_bytes()
	assert_equal(_router.open_order(_owner, tip, Tips.PREPARE).error, _contacts.refuse_admission, "exact reason")
	assert_equal(_physical_image(), before, "stock, funding and source remain byte identical")
	assert_equal(_construction.directory().state_bytes(), directory, "no leaked project identity")
	assert_equal(_tips.candidate_tip_ref(), tip, "no consumed source generation")
	assert_equal(_owner.prepared_subject(), NULL_REF, "rejected admission scratch discarded")
	assert_equal(_contacts.publications, 0, "no physical permission published")
	assert_equal(_contacts.discards, 1, "one rejected proof discarded")


func test_quotes_read_adopted_price_and_actual_catalog_without_extra_accounts() -> void:
	"""The only operation quote belongs to actual source identity and adopted fixed preparation work."""
	var tip: Vector2i = _designate()
	var quote: Contract.Quote = Contract.Quote.new()
	var project: Vector2i = _tips.project_of(tip)
	assert_equal(_owner.project_facts_into(project, quote), &"", "actual physical facts")
	assert_equal(quote.subject, tip, "same actual source generation")
	assert_equal(quote.total_mwu, Tips.FIXED_WORK_MWU, "adopted4000mWU")
	assert_equal(quote.remaining_mwu, Tips.FIXED_WORK_MWU, "no invented work")
	assert_equal(quote.job_kind, int(Catalog.JOB_KIND["BUILD"]), "actual adopted job kind")
	assert_equal(quote.input_count, 0, "preparation has no invented recipe")
	assert_equal(quote.output_count, 0, "preparation yields no earth")
	assert_true(_sites.funding_owner(_construction, _inventory, _pool, _items, _jobs, _work) == _funding, "one receipt arena")
	assert_equal(_owner.embedded_earth_milli(), 0, "no source stock invented")


func test_expired_contacts_fail_closed_without_source_or_accounting_changes() -> void:
	"""Late loss of the physical composition cannot become a zero-cost fallback."""
	var tip: Vector2i = _designate()
	var project: Vector2i = _tips.project_of(tip)
	var before: PackedByteArray = _physical_image()
	_contacts.bound = false
	assert_equal(_owner.project_facts_into(project, Contract.Quote.new()), Spoil.REFUSE_BINDING, "actual contact invalidated")
	assert_equal(_owner.embedded_earth_milli(), -1, "unavailable stock is not zero")
	assert_equal(_owner.prepare_tip_order(31), Spoil.REFUSE_BINDING, "no new order through dead binding")
	assert_equal(_physical_image(), before, "all authoritative state retained")
	_contacts.bound = true


func test_paid_preparation_requires_real_work_and_releases_worker_for_next_operation() -> void:
	"""Physical completion is not a visual timer or direct Construction credit."""
	var tip: Vector2i = _designate()
	var project: Vector2i = _tips.project_of(tip)
	assert_false(_router.complete_order(project).ok, "unfinished actual preparation refuses")
	_complete(tip)
	assert_true(_tips.is_prepared(tip), "real paid empty footprint available")
	assert_equal(_work.tool_job_of(_resident), NULL_REF, "tool claim released after actual Job retirement")
	assert_equal(_owner.embedded_earth_milli(), 0, "empty prepared source")
	assert_equal(_contacts.last_published_action, Contract.COMMIT, "exact completion published")
	_open(tip, Tips.COMPACT, 1001)
	_complete(tip)
	assert_equal(_tips.embedded_milli(tip), 1001, "same real worker can compact a following operation")


func test_actual_compaction_and_reclamation_conserve_source_and_normalize_only_earth() -> void:
	"""Real loose inputs become embedded stock, then paid reclamation emits the exact adopted lot."""
	var tip: Vector2i = _prepared_tip()
	_open(tip, Tips.COMPACT, 1001)
	assert_equal(_tips.incoming_milli(tip), 1001, "full actual incoming capacity held")
	_complete(tip)
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), INITIAL_EARTH - 1001, "actual loose stock consumed")
	assert_equal(_tips.embedded_milli(tip), 1001, "exact physical embedded stock")
	_open(tip, Tips.RECLAIM, 1001)
	assert_equal(_tips.locked_milli(tip), 1001, "source locked before work")
	_complete(tip, _output)
	var lot: Vector2i = _inventory.container_first_lot(_output)
	assert_true(lot != NULL_REF, "actual reclaimed output exists")
	assert_equal(_inventory.lot_quantity_milli(lot), 1001, "exact source amount, no new yield")
	assert_equal(_inventory.lot_provenance(lot), Catalog.PROVENANCE_SPOIL_RECLAIM, "actual typed provenance")
	assert_equal(_inventory.lot_quality(lot), int(Catalog.QUALITY["PLAIN"]), "adopted earth quality")
	assert_equal(_inventory.lot_recipe_id(lot), -1, "not a recipe output")
	assert_equal(_inventory.lot_age_milli_hours(lot), 0, "earth output age")
	assert_equal(_inventory.lot_age_remainder(lot), 0, "earth output remainder")
	assert_equal(_tips.embedded_milli(tip), 0, "source debited once at actual commit")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), INITIAL_EARTH, "loose stock restored exactly")


func test_blocked_productive_contact_preserves_xp_wear_wip_and_source() -> void:
	"""An actual bound worker cannot earn progress through a newly invalid physical contact."""
	var tip: Vector2i = _designate()
	var job: int = _start(tip)
	_contacts.refuse_worker = &"SYNTHETIC_CURRENT_CONTACT_BLOCKED"
	var before: PackedByteArray = _worker_image()
	assert_false(_work.tick_solo(job).ok, "real Work consults current physical permission")
	assert_equal(_worker_image(), before, "no labor, XP, durability or resource changes")
	assert_equal(_tips.retained_work_mwu(tip, Tips.PREPARE), 0, "no earned source progress")
	_contacts.refuse_worker = &""
	assert_true(_work.tick_solo(job).ok, "same paid job resumes at valid contact")
	assert_true(_tips.retained_work_mwu(tip, Tips.PREPARE) > 0, "real accepted labor retained")


func test_blocked_reclamation_commit_keeps_source_and_reserved_output_for_retry() -> void:
	"""Work-complete output retry cannot debit stock twice or charge another productive tick."""
	var tip: Vector2i = _prepared_tip()
	_open(tip, Tips.COMPACT, 1001)
	_complete(tip)
	var project: Vector2i = _open(tip, Tips.RECLAIM, 1001)
	var job: int = _start(tip, _output)
	_finish_work(job)
	_contacts.refuse_output = &"SYNTHETIC_OUTPUT_CONTACT_BLOCKED"
	var before: PackedByteArray = _worker_image()
	assert_false(_router.complete_order(project).ok, "new output blockage refuses")
	assert_equal(_worker_image(), before, "all paid and physical owners retained")
	assert_equal(_tips.embedded_milli(tip), 1001, "source remains embedded until output commits")
	assert_equal(_tips.locked_milli(tip), 1001, "source lock retained")
	assert_equal(_inventory.container_reserved_mass_g(_output), 1001, "owned finite output headroom retained")
	_contacts.refuse_output = &""
	assert_true(_router.complete_order(project).ok, "same earned operation retries without Work")
	assert_equal(_tips.embedded_milli(tip), 0, "source debits exactly once")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "owned claim releases")
	assert_false(_router.complete_order(project).ok, "retired project cannot replay output")


func test_cancelled_compaction_keeps_work_and_requires_same_full_input_on_resume() -> void:
	"""Actual80percent refund/loss does not erase the paid site's exact-q work contract."""
	var tip: Vector2i = _prepared_tip()
	var project: Vector2i = _open(tip, Tips.COMPACT, 1001)
	var job: int = _start(tip)
	assert_true(_work.tick_solo(job).ok, "actual partial compaction labor")
	var retained: int = _tips.retained_work_mwu(tip, Tips.COMPACT, 1001)
	assert_true(retained > 0 and retained < Tips.total_work_mwu(Tips.COMPACT, 1001), "partial work really earned")
	assert_true(_router.cancel_order(project, _store).ok, "actual refund and source cancellation")
	assert_equal(_tips.incoming_milli(tip), 0, "incoming reservation releases after refund")
	assert_equal(_tips.embedded_milli(tip), 0, "uncommitted source never credited")
	var earth: int = _items.compiled_id(&"excavated_earth")
	assert_equal(_funding.purpose_cancellation_loss_milli(Construction.PURPOSE_SPOIL_TIP, earth), 201, "actual201milli refund loss retained")
	assert_equal(_owner.prepare_operation(tip, Tips.COMPACT, 1000), Tips.REFUSE_CONTRACT, "cannot erase work by changing quantity")
	project = _open(tip, Tips.COMPACT, 1001)
	assert_true(_construction.remaining_mwu_into(project, _math), "actual resumed price")
	assert_equal(_math.value, Tips.total_work_mwu(Tips.COMPACT, 1001) - retained, "only remaining labor requested")
	_complete(tip)
	assert_equal(_tips.embedded_milli(tip), 1001, "full replacement input compacted once")
	assert_equal(_inventory.total_live_milli(earth), INITIAL_EARTH - 1001 - 201, "loose plus embedded plus loss conserved")


func test_actual_empty_closure_retires_footprint_and_stale_generation_refuses() -> void:
	"""Even empty closure is paid; the replacement on the same dirt has a new full source identity."""
	var tip: Vector2i = _prepared_tip()
	_open(tip, Tips.CLOSE)
	_complete(tip)
	assert_false(_tips.is_live_tip(tip), "old source generation retired")
	assert_equal(_tips.tip_at(30), NULL_REF, "footprint released only after actual work")
	var replacement: Vector2i = _designate(30)
	var replacement_project: Vector2i = _tips.project_of(replacement)
	assert_true(replacement != tip, "same tile cannot reuse the stale identity")
	assert_equal(_owner.prepare_operation(tip, Tips.CLOSE), Tips.REFUSE_TIP, "stale full handle refused")
	assert_equal(_tips.project_of(replacement), replacement_project, "replacement project unchanged")
	assert_equal(_construction.subject_ref_of(replacement_project), replacement, "replacement's actual subject remains live")
