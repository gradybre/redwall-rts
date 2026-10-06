extends RefCounted
## ADR1196 increment 2: fixed-tick paid installation of one first-entry assembly after its cuts settle.
## Order, approach legs, handling and INSTALL profiles come from the Frontier install row and the assembly
## source; payment, retirement, handling promotion and commit are the real owners' own transactions.

const Jobs := preload("res://scripts/core/jobs.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Modular := preload("res://scripts/core/modular_project_contract.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Retirement := preload("res://scripts/core/underground_entry_contact_retirement.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Space := preload("res://scripts/core/room_space.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const STAGE_OPEN: int = 0
const STAGE_LEG_MATERIAL: int = 1
const STAGE_LEG_STATION: int = 2
const STAGE_FUND: int = 3
const STAGE_HANDLE: int = 4
const STAGE_INSTALL_ENTER: int = 5
const STAGE_EARN: int = 6
const STAGE_RECOVER: int = 7
const STAGE_DONE: int = 8
const REFUSE_PLAN: StringName = &"ENTRY_INSTALLER_PLAN"
const REFUSE_HEADING: StringName = &"ENTRY_INSTALLER_HEADING"


class Paid extends RefCounted:
	## The paid-order owners beside the foreman's: Router, ConnectorWork, Contacts and the cold Budget.
	var router: RefCounted = null
	var connector: RefCounted = null
	var contacts: RefCounted = null
	var budget: RefCounted = null


class Plan extends RefCounted:
	## One assembly: its station H, material endpoint M, both approach profiles and the two source profiles.
	var ordinal: int = 0
	var placement: Vector2i = NULL_REF
	var station: Vector2i = NULL_REF
	var material: Vector2i = NULL_REF
	var walk_profile: int = -1
	var walk_revision: int = 0
	var approach_profile: int = -1
	var approach_revision: int = 0
	var install_profile: int = -1
	var install_revision: int = 0
	var handling_revision: int = 0
	var retired_first: Vector2i = NULL_REF
	var retired_second: Vector2i = NULL_REF


var _o: RefCounted = null # The foreman's Owners packet.
var _crew: RefCounted = null
var _paid: Paid = null
var _plan: Plan = null
var _content: int = 0
var _stage: int = STAGE_OPEN
var _project: Vector2i = NULL_REF
var _job: int = -1
var _accepted_mwu: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _actor: Routes.Actor = Routes.Actor.new()
var _quote: Modular.Quote = Modular.Quote.new()


func configure(owners: RefCounted, crew: RefCounted, paid: Paid, plan: Plan) -> StringName:
	"""Borrow the composed owners and an already derived plan; no owner is touched here."""
	if owners == null or crew == null or paid == null or plan == null or plan.station == NULL_REF \
			or plan.material == NULL_REF or paid.router == null or paid.connector == null:
		return REFUSE_PLAN
	_o = owners
	_crew = crew
	_paid = paid
	_plan = plan
	_content = owners.profiles.content_revision()
	_stage = STAGE_OPEN
	return &""


func stage() -> int:
	"""Current installation stage."""
	return _stage


func accepted_mwu() -> int:
	"""Fastening work accepted by the real Work owner."""
	return _accepted_mwu


func advance(tick: int) -> StringName:
	"""Run one stage for this fixed tick; instantaneous transitions chain inside it."""
	for step: int in 8:
		var before: int = _stage
		var code: StringName = _run(tick)
		if code != &"" or _stage == before or _stage == STAGE_DONE: return code
	return &""


func _run(tick: int) -> StringName:
	"""Dispatch exactly one stage."""
	match _stage:
		STAGE_OPEN: return _open(tick)
		STAGE_LEG_MATERIAL: return _leg_material(tick)
		STAGE_LEG_STATION: return _leg_station(tick)
		STAGE_FUND: return _fund(tick)
		STAGE_HANDLE: return _handle(tick)
		STAGE_INSTALL_ENTER: return _install_enter(tick)
		STAGE_EARN: return _earn(tick)
		STAGE_RECOVER: return _recover(tick)
	return &""


func _job_ref() -> Vector2i:
	"""Full generation of the current installation Job."""
	return _o.jobs.ref_of(_job)


func _open(tick: int) -> StringName:
	"""Admit the real paid order and its sole BUILD Job, then start the first all-yaw leg to M."""
	var opened: RefCounted = _paid.router.open_order(_paid.connector, _plan.placement, _plan.ordinal)
	if not opened.ok: return opened.error
	_project = opened.ref
	var code: StringName = _paid.router.project_facts_into(_project, _quote)
	if code != &"": return code
	var made: RefCounted = _o.jobs.create_job(_quote.job_kind, 0, 0, _quote.remaining_mwu, 0)
	if not made.ok: return made.error
	_job = made.value
	var result: RefCounted = _o.jobs.set_requester(_job, _project)
	if result.ok: result = _o.jobs.set_tool_gate(_job, Jobs.GATE_SATISFIED)
	if result.ok: result = _paid.router.bind_job(_project, _job_ref())
	if not result.ok: return result.error
	var worker: int = _o.residents.directory().get_typed_row(_crew.worker)
	result = _o.jobs.assign_worker(worker, _job)
	if result.ok: result = _o.work.claim_tool_for_work(worker, _crew.tool)
	if not result.ok: return result.error
	code = _travel(_plan.walk_profile, _plan.walk_revision, _plan.material, tick)
	if code == &"": _stage = STAGE_LEG_MATERIAL
	return code


func _travel(profile: int, revision: int, target: Vector2i, tick: int) -> StringName:
	"""Hand the ready source to one explicit travel profile and request the real itinerary."""
	var code: StringName = _o.routes.refresh_travel_actor(_crew.worker, _job_ref(), profile, revision,
		_content, 0, -1, _crew.tool)
	return _o.routes.request_route(_crew.worker, target, tick) if code == &"" else code


func _arrived(target: Vector2i, profile: int, revision: int, tick: int) -> int:
	"""Advance one route tick: 1 when source-ready at the target, 0 still moving, -1 held."""
	_o.routes.advance_tick(tick)
	if _o.routes.read_actor_into(_crew.worker, _actor) != &"" or _actor.phase == Routes.PHASE_HELD: return -1
	return 1 if _actor.location == target and Routes.source_ready_leaf_refusal(_o.routes, _crew.worker,
		_job_ref(), profile, revision, _content) == &"" else 0


func _leg_material(tick: int) -> StringName:
	"""At M, take the certified all-yaw turn to the narrow approach heading, then approach H."""
	var arrived: int = _arrived(_plan.material, _plan.walk_profile, _plan.walk_revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	if arrived == 0: return &""
	var code: StringName = WorldRoutes.turn_actor(_o.binding, _crew.worker, _job_ref(),
		_yaw(_plan.approach_profile), Space.MAX_CHECKS)
	if code == &"": code = _travel(_plan.approach_profile, _plan.approach_revision, _plan.station, tick)
	if code == &"": _stage = STAGE_LEG_STATION
	return code


func _leg_station(tick: int) -> StringName:
	"""A same-heading approach must already face the handling yaw (H admits no turn); an all-yaw one turns."""
	var arrived: int = _arrived(_plan.station, _plan.approach_profile, _plan.approach_revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	if arrived == 0: return &""
	var code: StringName = &""
	if _actor.yaw != _yaw(Assembly.PROFILE):
		if not _all_yaw(_plan.approach_profile): return REFUSE_HEADING
		code = WorldRoutes.turn_actor(_o.binding, _crew.worker, _job_ref(), _yaw(Assembly.PROFILE), Space.MAX_CHECKS)
	if code == &"": code = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), Assembly.PROFILE,
		_plan.handling_revision, _content, 0, -1, _crew.tool)
	if code == &"": _stage = STAGE_FUND
	return code


func _yaw(profile: int) -> int:
	"""The authored exact heading of one loaded profile row."""
	var profiles: RefCounted = _o.profiles
	return profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + profile]


func _all_yaw(profile: int) -> bool:
	"""True when the loaded profile row may turn in place at any endpoint that contains it."""
	var profiles: RefCounted = _o.profiles
	return profiles._live.fields[Profiles.F_YAW_KIND * profiles._profile_capacity + profile] == Profiles.YAW_ALL


func _fund(tick: int) -> StringName:
	"""Deliver the whole bill, retire the completed first pair, START, then enter real handling."""
	var code: StringName = _deliver()
	if code == &"": code = _retire_pair()
	if code != &"": return code
	var started: RefCounted = _paid.router.start_work(_project, tick)
	if not started.ok: return started.error
	code = _o.routes.begin_assembly_handling(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_HANDLE
	return code


func _deliver() -> StringName:
	"""Claim the quoted inputs from the crew's lots and make the Project READY."""
	var result: RefCounted = _paid.router.bind_material_container(_project, _crew.storage)
	if not result.ok: return result.error
	for line: int in _quote.input_count:
		var at: int = _crew.lot_keys.find(_quote.input_keys[line])
		if at < 0: return &"ENTRY_INSTALLER_INPUT_LOT"
		var batch: PackedInt64Array = PackedInt64Array([_crew.lots[at].x, _crew.lots[at].y,
			Reservations.PURPOSE_MODULAR_INPUT, _quote.input_milli[line], 100000])
		var claimed: RefCounted = _o.pool.claim_batch(_job_ref(), batch, 1, _o.inventory)
		if not claimed.ok: return claimed.error
	result = _paid.router.record_deliveries(_project)
	return &"" if result.ok else result.error


func _retire_pair() -> StringName:
	"""ADR1191: the completed first dig pair leaves the graph, then the Locations, before START."""
	if _plan.retired_first == NULL_REF: return &""
	var r: Retirement.Owners = Retirement.Owners.new()
	r.contacts = _paid.contacts
	r.locations = _o.locations
	r.binding = _o.binding
	r.routes = _o.routes
	r.budget = _paid.budget
	r.placement = _plan.placement
	r.project = _project
	r.worker = _crew.worker
	r.job = _job_ref()
	r.first = _plan.retired_first
	r.second = _plan.retired_second
	return Retirement.retire_completed_pair(r)


func _handle(tick: int) -> StringName:
	"""Positioning ticks earn nothing; only complete recovery promotes, then INSTALL is selected."""
	if Routes.assembly_handled_ready_leaf_refusal(_o.routes, _crew.worker, _job_ref(), Assembly.PROFILE,
			_plan.handling_revision, _content) != &"":
		_o.routes.advance_tick(tick)
		return &""
	var code: StringName = _paid.connector.complete_handling(_plan.placement, _project, _crew.worker, _job_ref())
	if code == &"": code = _o.routes.request_source_ready(_crew.worker, _job_ref())
	if code == &"": code = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), _plan.install_profile,
		_plan.install_revision, _content, 0, -1, _crew.tool)
	if code == &"": _stage = STAGE_INSTALL_ENTER
	return code


func _install_enter(tick: int) -> StringName:
	"""The unchanged INSTALL source reaches WORK through real route ticks."""
	if Routes.source_work_leaf_refusal(_o.routes, _crew.worker, _job_ref(), _plan.install_profile,
			_plan.install_revision, _content) == &"":
		_stage = STAGE_EARN
		return &""
	_o.routes.advance_tick(tick)
	return &""


func _earn(tick: int) -> StringName:
	"""Fastening is ordinary real Work; zero remaining hands the source back to READY."""
	_o.routes.advance_tick(tick)
	if not _o.jobs.remaining_mwu_into(_job, _math): return &"ENTRY_INSTALLER_STATE"
	if _math.value > 0:
		var worked: RefCounted = _o.work.tick_solo(_job)
		if not worked.ok: return worked.error
		_accepted_mwu += worked.accepted_mwu
		return &""
	var code: StringName = _o.routes.request_source_ready(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_RECOVER
	return code


func _recover(tick: int) -> StringName:
	"""Full INSTALL recovery precedes the one whole-group commit."""
	if Routes.source_ready_leaf_refusal(_o.routes, _crew.worker, _job_ref(), _plan.install_profile,
			_plan.install_revision, _content) != &"":
		_o.routes.advance_tick(tick)
		return &""
	var completed: RefCounted = _paid.router.complete_order(_project)
	if not completed.ok: return completed.error
	_stage = STAGE_DONE
	return &""
