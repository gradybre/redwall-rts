extends RefCounted
## ADR1196 increment 2: fixed-tick paid installation of one first-entry assembly after its cuts settle.
## Order, approach legs, handling and INSTALL profiles come from the Frontier install row and the assembly
## source; payment, retirement, handling promotion and commit are the real owners' own transactions.
## ADR1217 step 5 (DEC-052): the bearer is handled and seated by paw. The order's Job needs no tool, nothing is
## claimed, and the handling row is the set-down program Workpieces names (paw row 59 on source 5).

const Jobs := preload("res://scripts/core/jobs.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Modular := preload("res://scripts/core/modular_project_contract.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Retirement := preload("res://scripts/core/underground_entry_contact_retirement.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
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
const STAGE_LEG_ARRIVAL: int = 9 # Split landing: M to the station's arrival on the material profile.
const STAGE_HAUL: int = 10 # ADR1210: the quoted inputs missing at M are hauled before the Job is taken.
const STAGE_REST: int = 11 # ADR1226 (REQ-SET-034): INSTALL recovers to READY and waits while the hour forbids work.
const STAGE_RESUME: int = 12 # DEC-057: the crew was lost; the replacement re-handles in place from its arrival.
## ADR1229: from the crossing arrival down the stair (walk-in step, step forward, descent) to the tread above.
const STAGE_LEG_STAIRS: int = 13
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const Construction := preload("res://scripts/core/construction.gd")
const REFUSE_PLAN: StringName = &"ENTRY_INSTALLER_PLAN"
const REFUSE_HEADING: StringName = &"ENTRY_INSTALLER_HEADING"
## ADR1197 G4 / ADR1210: the storage container holds less free stock of an input item than the bill.
const REFUSE_INPUT_STOCK: StringName = &"ENTRY_FOREMAN_INPUT_LOT"
const CLAIM_EXPIRY: int = 100000


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
	## ADR1202 split landing: a station admitting only its narrow approach is reached through this arrival,
	## M to arrival on the material selector's profile; null when M approaches the station directly.
	var arrival: Vector2i = NULL_REF
	var material_profile: int = -1
	var material_revision: int = 0
	var install_profile: int = -1
	var install_revision: int = 0
	var handling_revision: int = 0
	var retired_first: Vector2i = NULL_REF
	var retired_second: Vector2i = NULL_REF
	## ADR1229, a tread order: the legs from the crossing arrival down to the stop above the station, the legs from
	## a previous tread station back up to the crossing arrival, as [slot, generation, profile, revision] rows, and
	## the arrival stop the pending bearer covers (retracted at FUND, re-created when the tread commits).
	var downs: PackedInt64Array = PackedInt64Array()
	var ups: PackedInt64Array = PackedInt64Array()
	var retract: Vector2i = NULL_REF


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
var _hauler: Hauler = null
var _haul_mwu: int = 0
var _haul_trips: int = 0
var _stair_leg: int = 0 # ADR1229: the next down leg while in STAGE_LEG_STAIRS.


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


func haul_mwu() -> int:
	"""Lift and set-down Work of this installation's hauls (ADR1210)."""
	return _haul_mwu + (_hauler.haul_mwu() if _hauler != null else 0)


func haul_trips() -> int:
	"""Whole units this installation hauled to M (ADR1210)."""
	return _haul_trips + (_hauler.trips() if _hauler != null else 0)


func progress_marker() -> int:
	"""Changes whenever the installation or its haul advances a stage; the foreman's stall budget reads it."""
	return _stage * 1024 + (_hauler.trips() * 16 + _hauler.stage() if _hauler != null else 0)


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
		STAGE_HAUL: return _haul(tick)
		STAGE_LEG_ARRIVAL: return _leg_arrival(tick)
		STAGE_LEG_STATION: return _leg_station(tick)
		STAGE_LEG_STAIRS: return _leg_stairs(tick)
		STAGE_FUND: return _fund(tick)
		STAGE_HANDLE: return _handle(tick)
		STAGE_INSTALL_ENTER: return _install_enter(tick)
		STAGE_EARN: return _earn(tick)
		STAGE_RECOVER: return _recover(tick)
		STAGE_REST: return _rest(tick)
	return &"" # STAGE_RESUME waits for the foreman to bring the replacement in (resume).


func _job_ref() -> Vector2i:
	"""Full generation of the current installation Job."""
	return _o.jobs.ref_of(_job)


func _open(tick: int) -> StringName:
	"""Admit the real paid order and its sole BUILD Job, bind M, haul what M lacks, then walk to M."""
	var code: StringName = _open_order()
	if code != &"": return code
	var queue: PackedInt32Array = PackedInt32Array()
	code = _units(queue)
	# ADR1229: from a tread station the walk back up the stair is the haul's first legs (a walk-in when empty).
	if code == &"" and (not queue.is_empty() or not _plan.ups.is_empty()): return _begin_haul(queue, tick)
	if code != &"": return code
	var worker: int = _o.residents.directory().get_typed_row(_crew.worker)
	var result: RefCounted = _o.jobs.assign_worker(worker, _job)
	if not result.ok: return result.error
	code = _travel(_plan.walk_profile, _plan.walk_revision, _plan.material, tick)
	if code == &"": _stage = STAGE_LEG_MATERIAL
	return code


func _open_order() -> StringName:
	"""The real paid order, its tool-free BUILD Job (DEC-052: paws), and M as its material container."""
	var opened: RefCounted = _paid.router.open_order(_paid.connector, _plan.placement, _plan.ordinal)
	if not opened.ok: return opened.error
	_project = opened.ref
	var code: StringName = _paid.router.project_facts_into(_project, _quote)
	if code != &"": return code
	var made: RefCounted = _o.jobs.create_job(_quote.job_kind, 0, 0, _quote.remaining_mwu, 0)
	if not made.ok: return made.error
	_job = made.value
	var result: RefCounted = _o.jobs.set_requester(_job, _project)
	if result.ok: result = _o.jobs.set_tool_gate(_job, Jobs.GATE_NOT_REQUIRED)
	if result.ok: result = _paid.router.bind_job(_project, _job_ref())
	if result.ok: result = _paid.router.bind_material_container(_project, _crew.storage)
	return &"" if result.ok else result.error


func _units(out: PackedInt32Array) -> StringName:
	"""ADR1210: whole units of each quoted input beyond M's free stock; none without a bound Delivery."""
	out.clear()
	if _o.delivery == null: return &""
	var items: PackedInt32Array = PackedInt32Array()
	var milli: PackedInt64Array = PackedInt64Array()
	for line: int in _quote.input_count:
		items.append(_o.items.compiled_id(_quote.input_keys[line]))
		milli.append(_quote.input_milli[line])
	return Hauler.units_into(_o, _crew.storage, items, milli, out)


func _begin_haul(queue: PackedInt32Array, tick: int) -> StringName:
	"""The walk to M uses the last cut's travel profile, exactly as the unhauled walk does."""
	var leg: Hauler.Leg = Hauler.Leg.new()
	leg.target = _plan.material
	leg.profile = _plan.walk_profile
	leg.revision = _plan.walk_revision
	var legs: Array[Hauler.Leg] = []
	for at: int in range(0, _plan.ups.size(), 4):
		legs.append(_plan_leg(_plan.ups, at))
	legs.append(leg)
	_hauler = Hauler.new()
	var code: StringName = _hauler.begin(_o, _crew, _project, _job, queue, legs, _plan.material, tick)
	if code == &"": _stage = STAGE_HAUL
	return code


func _haul(tick: int) -> StringName:
	"""Delegate to the hauler; home on M the worker switches back to the source walk profile at rest (ADR1210) and
	continues exactly as an arrival at M."""
	var code: StringName = _hauler.advance(tick)
	if code != &"" or _hauler.stage() != Hauler.STAGE_DONE: return code
	_haul_mwu += _hauler.haul_mwu()
	_haul_trips += _hauler.trips()
	_hauler = null
	code = _o.routes.refresh_travel_actor(_crew.worker, _job_ref(), _plan.walk_profile, _plan.walk_revision,
		_content, 0, -1, NULL_REF)
	return _from_material(tick) if code == &"" else code


func _travel(profile: int, revision: int, target: Vector2i, tick: int) -> StringName:
	"""Hand the ready source to one explicit travel profile and request the real itinerary."""
	var code: StringName = _o.routes.refresh_travel_actor(_crew.worker, _job_ref(), profile, revision,
		_content, 0, -1, NULL_REF)
	return _o.routes.request_route(_crew.worker, target, tick) if code == &"" else code


func _arrived(target: Vector2i, profile: int, revision: int, tick: int) -> int:
	"""Advance one route tick: 1 when source-ready at the target, 0 still moving, -1 held."""
	_o.routes.advance_tick(tick)
	if _o.routes.read_actor_into(_crew.worker, _actor) != &"" or _actor.phase == Routes.PHASE_HELD: return -1
	return 1 if _actor.location == target and Routes.source_ready_leaf_refusal(_o.routes, _crew.worker,
		_job_ref(), profile, revision, _content) == &"" else 0


func _leg_material(tick: int) -> StringName:
	"""Source-ready arrival at M continues from M."""
	var arrived: int = _arrived(_plan.material, _plan.walk_profile, _plan.walk_revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	return _from_material(tick) if arrived == 1 else &""


func _from_material(tick: int) -> StringName:
	"""At M, take the certified all-yaw turn, then approach H directly or walk to the station's arrival first."""
	if _plan.arrival == NULL_REF:
		return _turn_and_travel(_plan.approach_profile, _plan.approach_revision, _plan.station, STAGE_LEG_STATION, tick)
	return _turn_and_travel(_plan.material_profile, _plan.material_revision, _plan.arrival, STAGE_LEG_ARRIVAL, tick)


func _leg_arrival(tick: int) -> StringName:
	"""ADR1202 split landing: at the arrival, turn to the narrow approach heading and walk onto the station.
	ADR1229: for a tread, turn onto the first down leg instead and walk down the stair."""
	var arrived: int = _arrived(_plan.arrival, _plan.material_profile, _plan.material_revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	if arrived == 0: return &""
	if _plan.downs.is_empty():
		return _turn_and_travel(_plan.approach_profile, _plan.approach_revision, _plan.station, STAGE_LEG_STATION, tick)
	_stair_leg = 0
	var first: Hauler.Leg = _plan_leg(_plan.downs, 0)
	return _turn_and_travel(first.profile, first.revision, first.target, STAGE_LEG_STAIRS, tick)


func _leg_stairs(tick: int) -> StringName:
	"""ADR1229: each source-ready arrival takes the next down leg; the last stop above the station steps back onto
	it on the station's own approach row (the step back), facing down the stair as every down leg does."""
	var leg: Hauler.Leg = _plan_leg(_plan.downs, 4 * _stair_leg)
	var arrived: int = _arrived(leg.target, leg.profile, leg.revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	if arrived == 0: return &""
	_stair_leg += 1
	if 4 * _stair_leg >= _plan.downs.size():
		var code: StringName = _travel(_plan.approach_profile, _plan.approach_revision, _plan.station, tick)
		if code == &"": _stage = STAGE_LEG_STATION
		return code
	var next: Hauler.Leg = _plan_leg(_plan.downs, 4 * _stair_leg)
	return _travel(next.profile, next.revision, next.target, tick)


static func _plan_leg(rows: PackedInt64Array, at: int) -> Hauler.Leg:
	"""One [slot, generation, profile, revision] row as a travel leg."""
	var leg: Hauler.Leg = Hauler.Leg.new()
	leg.target = Vector2i(rows[at], rows[at + 1])
	leg.profile = rows[at + 2]
	leg.revision = rows[at + 3]
	return leg


func _turn_and_travel(profile: int, revision: int, target: Vector2i, next: int, tick: int) -> StringName:
	"""Certified in-place turn to the profile's own heading, then one route on that profile."""
	var code: StringName = WorldRoutes.turn_actor(_o.binding, _crew.worker, _job_ref(), _yaw(profile), Space.MAX_CHECKS)
	if code == &"": code = _travel(profile, revision, target, tick)
	if code == &"": _stage = next
	return code


func _leg_station(tick: int) -> StringName:
	"""A same-heading approach must already face the handling yaw (H admits no turn); an all-yaw one turns."""
	var arrived: int = _arrived(_plan.station, _plan.approach_profile, _plan.approach_revision, tick)
	if arrived < 0: return &"ENTRY_INSTALLER_ROUTE_HELD"
	if arrived == 0: return &""
	var code: StringName = &""
	if _actor.yaw != _yaw(_handling_profile()):
		if not _all_yaw(_plan.approach_profile): return REFUSE_HEADING
		code = WorldRoutes.turn_actor(_o.binding, _crew.worker, _job_ref(), _yaw(_handling_profile()), Space.MAX_CHECKS)
	if code == &"" and _funded() and _handled(): return _resume_funded() # DEC-057: straight to INSTALL.
	if code == &"": code = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), _handling_profile(),
		_plan.handling_revision, _content, 0, -1, NULL_REF)
	if code == &"": _stage = STAGE_FUND
	return code


func _handling_profile() -> int:
	"""ADR1217 step 5: the set-down (handling) row the bound Workpieces names for this assembly (paw row 59)."""
	return Routes.Handling.profile_of(_paid.connector._workpieces, _plan.ordinal)


func _handled() -> bool:
	"""DEC-057: the order's piece has completed handling (it is installed by INSTALL work alone)."""
	return Workpieces.handled_leaf_refusal(_paid.connector._workpieces, _plan.placement, _project) == &""


func _yaw(profile: int) -> int:
	"""The authored exact heading of one loaded profile row."""
	var profiles: RefCounted = _o.profiles
	return profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + profile]


func _all_yaw(profile: int) -> bool:
	"""True when the loaded profile row may turn in place at any endpoint that contains it."""
	var profiles: RefCounted = _o.profiles
	return profiles._live.fields[Profiles.F_YAW_KIND * profiles._profile_capacity + profile] == Profiles.YAW_ALL


func _fund(tick: int) -> StringName:
	"""Deliver the whole bill, retire the completed first pair, START, then enter real handling. DEC-057: an order
	a lost crew had already funded is not paid again; the replacement resumes it in place."""
	if _funded(): return _resume_funded()
	var code: StringName = _retract_stop()
	if code == &"": code = _deliver()
	if code == &"": code = _retire_pair()
	if code != &"": return code
	var started: RefCounted = _paid.router.start_work(_project, tick)
	if not started.ok: return started.error
	code = _o.routes.begin_assembly_handling(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_HANDLE
	return code


func _retract_stop() -> StringName:
	"""ADR1229: the tread's bearer is staged where the arrival stop of the tread above stands, so that stop and its
	edges leave before FUND; the tread's commit re-creates it."""
	if _plan.retract == NULL_REF or not _o.locations._live_ref(_o.locations._live, _plan.retract): return &""
	return StairPath.retract(_o.binding, _o.routes, _o.locations, _paid.budget, _plan.retract)


func _funded() -> bool:
	"""The order's START already ran (WORKING, or its fastening is done)."""
	if not _o.construction.phase_into(_project, _math): return false
	return _math.value == Construction.PHASE_WORKING or _math.value == Construction.PHASE_WORK_DONE


func _resume_funded() -> StringName:
	"""DEC-057 re-handle in place: a piece still pending handling is revalidated at handling READY (resume_work) and
	handled again where it stands; an already handled piece goes to INSTALL, revalidated once its source works."""
	if _handled():
		var refreshed: StringName = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), _plan.install_profile,
			_plan.install_revision, _content, 0, -1, NULL_REF)
		if refreshed == &"": _stage = STAGE_INSTALL_ENTER
		return refreshed
	var result: RefCounted = _paid.router.resume_work(_project)
	if not result.ok: return result.error
	var code: StringName = _o.routes.begin_assembly_handling(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_HANDLE
	return code


func _finish_resume() -> StringName:
	"""DEC-057: the INSTALL source now works; unfinished fastening is revalidated by Router, finished fastening needs
	only its retained zero work to read complete again (as Router's own START writes it)."""
	if not _o.construction.phase_into(_project, _math): return &"ENTRY_INSTALLER_STATE"
	if _math.value == Construction.PHASE_WORKING:
		var result: RefCounted = _paid.router.resume_work(_project)
		return &"" if result.ok else result.error
	var completed: RefCounted = _o.jobs.set_state(_job, Jobs.JOB_STATE_COMPLETE)
	return &"" if completed.ok else completed.error


func release_lost_crew(lost: Vector2i, row: int) -> StringName:
	"""DEC-057: the lost crew's haul is cancelled and its hold on the order's Job released; the piece, the
	paid inputs and every Work mWU stay where they are. The installation then waits in STAGE_RESUME."""
	var code: StringName = &""
	if _hauler != null:
		_haul_mwu += _hauler.haul_mwu()
		_haul_trips += _hauler.trips()
		code = _hauler.release_lost(lost, row)
		_hauler = null
	if code == &"" and row >= 0 and _job >= 0 and _o.jobs.worker_of(_job) == lost:
		var released: RefCounted = _o.jobs.release_worker(row)
		if not released.ok: return released.error
	if code == &"" and _project != NULL_REF and _funded(): _o.construction.set_assigned_count(_project, 0)
	if code == &"": _stage = STAGE_RESUME
	return code


func resume(legs: Array[Hauler.Leg], tick: int) -> StringName:
	"""DEC-057: the replacement walks in on the foreman's legs (arrival at H, its retreat, M), hauling what M still
	lacks for an unfunded order; from M it continues exactly as an arrival there."""
	var code: StringName = _open_order() if _project == NULL_REF else &""
	var queue: PackedInt32Array = PackedInt32Array()
	if code == &"" and not _funded(): code = _units(queue)
	if code != &"": return code
	_hauler = Hauler.new()
	code = _hauler.begin(_o, _crew, _project, _job, queue, legs, _crew.arrival, tick)
	if code == &"": _stage = STAGE_HAUL
	return code


func _deliver() -> StringName:
	"""Claim the quoted inputs from M's free stock (bound at open) and make the Project READY."""
	for line: int in _quote.input_count:
		var code: StringName = claim_stock(_o, _crew.storage, _job_ref(), _o.items.compiled_id(_quote.input_keys[line]),
			_quote.input_milli[line], Reservations.PURPOSE_MODULAR_INPUT)
		if code != &"": return code
	var result: RefCounted = _paid.router.record_deliveries(_project)
	return &"" if result.ok else result.error


static func claim_stock(owners: RefCounted, container: Vector2i, job: Vector2i, item: int, milli: int,
		purpose: int) -> StringName:
	"""ADR1210: claim exactly `milli` of one item for the Job from the container's free lots in list order, in one
	batch; refuse REFUSE_INPUT_STOCK, claiming nothing, when the container holds less than that."""
	var batch: PackedInt64Array = PackedInt64Array()
	var inventory: RefCounted = owners.inventory
	var lot: Vector2i = inventory.container_first_lot(container)
	var left: int = milli
	while left > 0 and lot != NULL_REF:
		var take: int = mini(left, inventory.lot_available_milli(lot)) if inventory.lot_item_id(lot) == item else 0
		if take > 0:
			batch.append_array(PackedInt64Array([lot.x, lot.y, purpose, take, CLAIM_EXPIRY]))
			left -= take
		lot = inventory.container_next_lot(lot)
	if item < 0 or milli <= 0 or left > 0: return REFUSE_INPUT_STOCK
	@warning_ignore("integer_division") var rows: int = batch.size() / Reservations.CLAIM_STRIDE
	var claimed: RefCounted = owners.pool.claim_batch(job, batch, rows, inventory)
	return &"" if claimed.ok else claimed.error


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
	if Routes.assembly_handled_ready_leaf_refusal(_o.routes, _crew.worker, _job_ref(), _handling_profile(),
			_plan.handling_revision, _content) != &"":
		_o.routes.advance_tick(tick)
		return &""
	var code: StringName = _paid.connector.complete_handling(_plan.placement, _project, _crew.worker, _job_ref())
	if code == &"": code = _o.routes.request_source_ready(_crew.worker, _job_ref())
	if code == &"": code = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), _plan.install_profile,
		_plan.install_revision, _content, 0, -1, NULL_REF)
	if code == &"": _stage = STAGE_INSTALL_ENTER
	return code


func _install_enter(tick: int) -> StringName:
	"""The unchanged INSTALL source reaches WORK through real route ticks."""
	if Routes.source_work_leaf_refusal(_o.routes, _crew.worker, _job_ref(), _plan.install_profile,
			_plan.install_revision, _content) == &"":
		var code: StringName = _finish_resume() if _o.jobs._state[_job] == Jobs.JOB_STATE_RESERVED else &""
		if code == &"": _stage = STAGE_EARN
		return code
	_o.routes.advance_tick(tick)
	return &""


func _earn(tick: int) -> StringName:
	"""Fastening is ordinary real Work; zero remaining hands the source back to READY."""
	_o.routes.advance_tick(tick)
	if not _o.jobs.remaining_mwu_into(_job, _math): return &"ENTRY_INSTALLER_STATE"
	if _math.value > 0:
		var worked: RefCounted = _o.work.tick_solo(_job)
		if not worked.ok: return _rest_or(worked.error)
		_accepted_mwu += worked.accepted_mwu
		return &""
	var code: StringName = _o.routes.request_source_ready(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_RECOVER
	return code


func _rest_or(code: StringName) -> StringName:
	"""ADR1226: Work stopped at a safe point for the crew's rest hour; INSTALL recovers to READY on the station."""
	if code != &"WORK_SCHEDULE_REST": return code
	code = _o.routes.request_source_ready(_crew.worker, _job_ref())
	if code == &"": _stage = STAGE_REST
	return code


func _rest(tick: int) -> StringName:
	"""ADR1226: READY on the station is the resting point; when the hour permits work INSTALL re-enters WORK."""
	if Routes.source_ready_leaf_refusal(_o.routes, _crew.worker, _job_ref(), _plan.install_profile,
			_plan.install_revision, _content) != &"":
		_o.routes.advance_tick(tick)
		return &""
	if _o.jobs.schedule().rests_now(_o.residents.directory().get_typed_row(_crew.worker)): return &""
	var code: StringName = _o.routes.refresh_work_actor(_crew.worker, _job_ref(), _plan.install_profile,
		_plan.install_revision, _content, 0, -1, NULL_REF)
	if code == &"": _stage = STAGE_INSTALL_ENTER
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


func write_state(w: Progress.Writer) -> void:
	"""ADR1218: the plan derived at the installation's start, then its cursor, quoted inputs and any haul."""
	_write_plan(w)
	w.i64(_content)
	w.i32(_stage)
	w.ref(_project)
	w.i32(_job)
	w.ref(Progress.job_ref(_o.jobs, _job, _project != NULL_REF))
	w.i64(_accepted_mwu)
	w.i64(_haul_mwu)
	w.i32(_haul_trips)
	w.i32(_stair_leg)
	var lines: int = _quote.input_count if _project != NULL_REF else 0
	w.i32(lines)
	for line: int in lines:
		w.i32(_o.items.compiled_id(_quote.input_keys[line]))
		w.i64(_quote.input_milli[line])
	w.flag(_hauler != null)
	if _hauler != null: _hauler.write_state(w)


func _write_plan(w: Progress.Writer) -> void:
	"""Every Plan field: the Locations it was resolved to may since have retired, so none is re-derived."""
	w.i32(_plan.ordinal)
	for at: Vector2i in [_plan.placement, _plan.station, _plan.material]:
		w.ref(at)
	w.i32(_plan.walk_profile)
	w.i64(_plan.walk_revision)
	w.i32(_plan.approach_profile)
	w.i64(_plan.approach_revision)
	w.ref(_plan.arrival)
	w.i32(_plan.material_profile)
	w.i64(_plan.material_revision)
	w.i32(_plan.install_profile)
	w.i64(_plan.install_revision)
	w.i64(_plan.handling_revision)
	w.ref(_plan.retired_first)
	w.ref(_plan.retired_second)
	_write_legs(w, _plan.downs)
	_write_legs(w, _plan.ups)
	w.ref(_plan.retract)


static func _write_legs(w: Progress.Writer, rows: PackedInt64Array) -> void:
	"""ADR1229: a stair leg list, count first, each leg as Progress.LEG_BYTES."""
	@warning_ignore("integer_division") var count: int = rows.size() / 4
	w.i32(count)
	for leg: int in count:
		w.ref(Vector2i(rows[4 * leg], rows[4 * leg + 1]))
		w.i32(rows[4 * leg + 2])
		w.i64(rows[4 * leg + 3])


static func _read_legs(r: Progress.Reader) -> PackedInt64Array:
	"""A stair leg list in wire order."""
	var rows: PackedInt64Array = PackedInt64Array()
	for leg: int in r.ranged(0, Progress.MAX_STAIR_LEGS):
		var target: Vector2i = r.ref()
		rows.append_array(PackedInt64Array([target.x, target.y, r.i32(), r.i64()]))
	return rows


func read_state(r: Progress.Reader, owners: RefCounted, crew: RefCounted, paid: Paid) -> StringName:
	"""ADR1218: decode a saved installation under the foreman's owners, then re-prove every handle."""
	_o = owners
	_crew = crew
	_paid = paid
	_plan = _read_plan(r)
	_content = r.i64()
	_stage = r.ranged(STAGE_OPEN, STAGE_LEG_STAIRS)
	_project = r.ref()
	_job = r.i32()
	var job: Vector2i = r.ref()
	_accepted_mwu = r.i64()
	_haul_mwu = r.i64()
	_haul_trips = r.i32()
	_stair_leg = r.ranged(0, Progress.MAX_STAIR_LEGS)
	var lines: PackedInt64Array = PackedInt64Array()
	for line: int in r.ranged(0, Progress.MAX_QUOTE_LINES):
		lines.append_array(PackedInt64Array([r.i32(), r.i64()]))
	var code: StringName = _read_haul(r, r.flag())
	if code != &"": return code
	if _stage == STAGE_DONE or (_stage == STAGE_HAUL) != (_hauler != null) \
			or (_stage == STAGE_OPEN and _project != NULL_REF) or (_project == NULL_REF) != lines.is_empty() \
			or (_stage != STAGE_OPEN and _stage != STAGE_RESUME and _project == NULL_REF):
		return Progress.REFUSE_SHAPE
	return _restored_refusal(job, lines)


func _read_plan(r: Progress.Reader) -> Plan:
	"""The Plan fields in wire order."""
	var plan: Plan = Plan.new()
	plan.ordinal = r.i32()
	plan.placement = r.ref()
	plan.station = r.ref()
	plan.material = r.ref()
	plan.walk_profile = r.i32()
	plan.walk_revision = r.i64()
	plan.approach_profile = r.i32()
	plan.approach_revision = r.i64()
	plan.arrival = r.ref()
	plan.material_profile = r.i32()
	plan.material_revision = r.i64()
	plan.install_profile = r.i32()
	plan.install_revision = r.i64()
	plan.handling_revision = r.i64()
	plan.retired_first = r.ref()
	plan.retired_second = r.ref()
	plan.downs = _read_legs(r)
	plan.ups = _read_legs(r)
	plan.retract = r.ref()
	return plan


func _read_haul(r: Progress.Reader, present: bool) -> StringName:
	"""A saved haul belongs to this installation's own BUILD Job."""
	if r.bad: return Progress.REFUSE_SHAPE
	if not present: return &""
	_hauler = Hauler.new()
	return _hauler.read_state(r, _o, _crew, _job)


func _restored_refusal(job: Vector2i, lines: PackedInt64Array) -> StringName:
	"""The paid order must still quote the saved bill; every Location the plan will still read must be live."""
	if _paid == null or _paid.router == null or _paid.connector == null: return Progress.REFUSE_OWNERS
	if _content != _o.profiles.content_revision(): return Progress.REFUSE_CONTENT
	var code: StringName = Progress.job_refusal(_o.jobs, _job, job, _project != NULL_REF)
	if code == &"" and _project != NULL_REF: code = _quote_refusal(lines)
	var retiring: bool = _stage in [STAGE_OPEN, STAGE_LEG_MATERIAL, STAGE_LEG_ARRIVAL, STAGE_LEG_STATION, STAGE_HAUL,
		STAGE_FUND, STAGE_RESUME] and not _funded() # DEC-057: a resumed funded order retired its pair already.
	for at: Vector2i in [_plan.station, _plan.material]:
		if code == &"": code = Progress.location_refusal(_o.locations, at, false)
	if code == &"": code = Progress.location_refusal(_o.locations, _plan.arrival, true)
	if code == &"" and not _funded(): code = Progress.location_refusal(_o.locations, _plan.retract, true)
	for at: Vector2i in [_plan.retired_first, _plan.retired_second]:
		if code == &"" and retiring: code = Progress.location_refusal(_o.locations, at, true)
	if code == &"" and _stage != STAGE_OPEN and _stage != STAGE_RESUME and _hauler == null:
		code = Progress.actor_refusal(_o, _crew.worker, job)
	return code


func _quote_refusal(lines: PackedInt64Array) -> StringName:
	"""Re-read the restored order's immutable bill; it must be the very bill that was saved."""
	if _paid.router.project_facts_into(_project, _quote) != &"": return Progress.REFUSE_PROJECT
	if lines.size() != 2 * _quote.input_count: return Progress.REFUSE_PROJECT
	for line: int in _quote.input_count:
		if lines[2 * line] != _o.items.compiled_id(_quote.input_keys[line]) or lines[2 * line + 1] != _quote.input_milli[line]:
			return Progress.REFUSE_PROJECT
	return &""
