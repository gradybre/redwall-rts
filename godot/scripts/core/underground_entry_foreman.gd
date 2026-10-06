extends RefCounted
## ADR1196/ADR1202: fixed-tick dispatcher for the first-entry prefix: the L0 cuts, the paid L0 installation,
## the T0 cuts and the paid T0 installation. The plan is derived from the immutable Frontier and Placement only;
## every step is a real owner call whose own final guards decide. Surface arrival and hauling are outside it.

const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const ContactPath := preload("res://scripts/core/underground_entry_contact_path.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const OPERATIONS: Array[int] = [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]
const STAGE_OPEN: int = 0
const STAGE_TRAVEL: int = 1
const STAGE_ENTER: int = 2
const STAGE_START: int = 3
const STAGE_EARN: int = 4
const STAGE_RECOVER: int = 5
const STAGE_DONE: int = 6
const STAGE_FAILED: int = 7
const STAGE_INSTALL: int = 8
const STAGE_TICK_LIMIT: int = 1200
const REFUSE_PLAN: StringName = &"ENTRY_FOREMAN_PLAN"
const REFUSE_STALL: StringName = &"ENTRY_FOREMAN_STALLED"
const REFUSE_STATE: StringName = &"ENTRY_FOREMAN_STATE"


class Owners extends RefCounted:
	## The actual composed owners; borrowed, never replaced, for the lifetime of this dispatcher.
	var sites: Sites = null
	var jobs: Jobs = null
	var work: RefCounted = null
	var routes: Routes = null
	var binding: WorldRoutes = null
	var residents: RefCounted = null
	var pool: Reservations = null
	var construction: RefCounted = null
	var inventory: RefCounted = null
	var profiles: RefCounted = null
	var frontier: Frontier = null
	var placements: RefCounted = null
	var locations: Locations = null
	var anchor: RefCounted = null # SurfaceAnchor; needed only when an installation stands on an installed contact.


class Crew extends RefCounted:
	## One worker, its equipped tool, the source-selected containers and the stock lots it may draw.
	var worker: Vector2i = NULL_REF
	var tool: Vector2i = NULL_REF
	var storage: Vector2i = NULL_REF
	var output: Vector2i = NULL_REF
	var lot_keys: Array[StringName] = []
	var lots: Array[Vector2i] = []


class Task extends RefCounted:
	## One paid phase (Site, operation, station, heading, work/travel profiles), or one paid installation step.
	var install_ordinal: int = -1
	var site: Vector2i = NULL_REF
	var operation: int = -1
	var station: Vector2i = NULL_REF
	var yaw: int = 0
	var work_profile: int = -1
	var work_revision: int = 0
	var travel_profile: int = -1
	var travel_revision: int = 0


var _owners: Owners = null
var _crew: Crew = null
var _tasks: Array[Task] = []
var _index: int = 0
var _stage: int = STAGE_FAILED
var _stage_ticks: int = 0
var _job: int = -1
var _error: StringName = REFUSE_STATE
var _content: int = 0
var _accepted_mwu: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _actor: Routes.Actor = Routes.Actor.new()
var _installer: Installer = null
var _paid: Installer.Paid = null
var _install_count: int = 0
var _install_mwu: int = 0
var _last_install_stage: int = -1
var _placement: Vector2i = NULL_REF
var _leg_target: Vector2i = NULL_REF
var _leg_profile: int = -1
var _leg_revision: int = 0
var _retreat: Vector2i = NULL_REF
var _retreat_profile: int = -1
var _retreat_revision: int = 0
var _pending_retreat: Vector2i = NULL_REF


func configure(owners: Owners, crew: Crew, placement: Vector2i) -> StringName:
	"""Derive all twelve L0 phase tasks from the loaded Frontier before any owner is touched."""
	if owners == null or crew == null or owners.frontier == null or owners.placements == null \
			or crew.lot_keys.size() != crew.lots.size():
		return REFUSE_PLAN
	_owners = owners
	_crew = crew
	_content = owners.profiles.content_revision()
	_placement = placement
	var code: StringName = _plan(placement)
	if code != &"":
		_tasks.clear()
		return code
	_index = 0
	_stage = STAGE_OPEN
	_error = &""
	return &""


func _plan(placement: Vector2i) -> StringName:
	"""Only episodes that need no installed prefix are planned before any installation is configured."""
	var row: int = placement.x
	if row < 0 or _owners.placements._live.i32[row] != placement.y \
			or _owners.placements._live.i32[_owners.placements.ROTATION * _owners.placements._capacity + row] != 0:
		return REFUSE_PLAN
	return _append_episodes(0)


func _append_episodes(prefix: int) -> StringName:
	"""Each episode needing exactly this installed prefix contributes BRACE, CUT and FINISH at its station."""
	var row: int = _placement.x
	var episode: PackedInt32Array = PackedInt32Array()
	episode.resize(Frontier.row_fields(Frontier.EPISODE))
	for ordinal: int in _owners.frontier.row_count(Frontier.EPISODE, _owners.frontier.content_revision()):
		if _owners.frontier.episode_into(ordinal, episode) != &"" or episode[6] != 7: return REFUSE_PLAN
		if episode[7] != prefix: continue
		var site: Vector2i = _owners.sites.site_at(_world_point(row, episode[0], episode[1], episode[2]))
		if site == NULL_REF: return REFUSE_PLAN
		for operation: int in OPERATIONS:
			var task: Task = _task_for(row, site, operation, episode[8])
			if task == null: return REFUSE_PLAN
			_tasks.append(task)
	return &""


func _task_for(row: int, site: Vector2i, operation: int, station_index: int) -> Task:
	"""Resolve one station to its live Location handle, exact heading and work/travel profile pairs."""
	var station: PackedInt32Array = PackedInt32Array()
	station.resize(Frontier.row_fields(Frontier.STATION))
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.station_into(station_index, station, revision) != &"": return null
	var task: Task = Task.new()
	task.site = site
	task.operation = operation
	task.yaw = station[4]
	task.work_profile = station[5]
	task.work_revision = revision.value
	var travel: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.endpoint_travel_into(station[0], travel, revision) != &"": return null
	task.travel_profile = travel.value
	task.travel_revision = revision.value
	task.station = _resolve_endpoint(row, station[0])
	return task if task.station != NULL_REF else null


func _resolve_endpoint(row: int, selector: int) -> Vector2i:
	"""Exactly one live Location may hold the transformed source point and authored role; aliases refuse."""
	var endpoint: PackedInt32Array = PackedInt32Array()
	endpoint.resize(Frontier.row_fields(Frontier.ENDPOINT))
	if _owners.frontier.endpoint_into(selector, endpoint) != &"": return NULL_REF
	var point: Vector3i = _world_point(row, endpoint[4], endpoint[5], endpoint[6])
	var bank: Locations.Bank = _owners.locations._live
	var capacity: int = _owners.locations._capacity
	var found: Vector2i = NULL_REF
	for at: int in capacity:
		if bank.present[at] != 1 or bank.i32[Locations.ROLE * capacity + at] != endpoint[3]: continue
		if Vector3i(bank.i32[Locations.X * capacity + at], bank.i32[Locations.Y * capacity + at],
				bank.i32[Locations.Z * capacity + at]) != point: continue
		if found != NULL_REF: return NULL_REF
		found = Vector2i(at, bank.i32[Locations.GENERATION * capacity + at])
	return found


func _world_point(row: int, x: int, y: int, z: int) -> Vector3i:
	"""Apply the one original Placement transform to a source-local coordinate."""
	var placements: RefCounted = _owners.placements
	return Vector3i(Locations.installed_coordinate(placements, row, x, y, z, 0),
		Locations.installed_coordinate(placements, row, x, y, z, 1),
		Locations.installed_coordinate(placements, row, x, y, z, 2))


func advance(tick: int) -> StringName:
	"""Run the current stage for one fixed tick; instantaneous owner transitions chain within it."""
	if _stage == STAGE_DONE or _stage == STAGE_FAILED: return _error
	for step: int in 8:
		var before: int = _stage
		var code: StringName = _run_stage(tick)
		if code != &"": return _fail(code)
		if _stage == before or _stage == STAGE_DONE: break
	_stage_ticks += 1
	return &"" if _stage_ticks <= STAGE_TICK_LIMIT else _fail(REFUSE_STALL)


func _run_stage(tick: int) -> StringName:
	"""Dispatch exactly one stage; each returns a refusal code or advances the stage."""
	match _stage:
		STAGE_OPEN: return _open(tick)
		STAGE_TRAVEL: return _travel(tick)
		STAGE_ENTER: return _enter(tick)
		STAGE_START: return _start(tick)
		STAGE_EARN: return _earn(tick)
		STAGE_RECOVER: return _recover(tick)
		STAGE_INSTALL: return _install(tick)
	return REFUSE_STATE


func _open(tick: int) -> StringName:
	"""Admit the real phase Project, then a BUILD Job bound to it, the worker and the equipped tool."""
	var task: Task = _tasks[_index]
	var opened: RefCounted = _owners.sites.open_phase(task.site, task.operation)
	if not opened.ok: return opened.error
	if not _owners.construction.remaining_mwu_into(opened.ref, _math): return REFUSE_STATE
	var made: RefCounted = _owners.jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, 0)
	if not made.ok: return made.error
	_job = made.value
	var ref: Vector2i = _owners.jobs.ref_of(_job)
	var code: StringName = _bind_phase_job(task, opened.ref, ref)
	if code == &"": code = _assign()
	return _place_actor(task, ref, tick) if code == &"" else code


func _place_actor(task: Task, job: Vector2i, tick: int) -> StringName:
	"""First arrival admits the worker where it physically stands; later phases travel or reuse the station."""
	var worker: int = _owners.residents.directory().get_typed_row(_crew.worker)
	if _owners.routes._resident_ref(worker) == NULL_REF:
		_set_stage(STAGE_ENTER)
		return _owners.routes.admit_work_actor(_crew.worker, job, task.station, task.work_profile,
			task.work_revision, _content, 0, -1, _crew.tool)
	if _owners.routes._resident_pair(Routes.R_LOCATION_SLOT, worker) == task.station:
		_set_stage(STAGE_ENTER)
		return _refresh_work(task, job)
	_set_stage(STAGE_TRAVEL)
	return _begin_travel(task, job, tick)


func _bind_phase_job(task: Task, project: Vector2i, job: Vector2i) -> StringName:
	"""The Job names its Project, the satisfied tool gate, its Site and the source-selected containers."""
	var result: RefCounted = _owners.jobs.set_requester(_job, project)
	if result.ok: result = _owners.jobs.set_tool_gate(_job, Jobs.GATE_SATISFIED)
	if result.ok: result = _owners.sites.bind_job(task.site, job)
	if result.ok: result = _owners.sites.bind_material_container(task.site, _crew.storage)
	if result.ok and task.operation == Contract.OP_CUT: result = _owners.sites.bind_output(task.site, _crew.output)
	return &"" if result.ok else result.error


func _assign() -> StringName:
	"""The same real worker takes the Job and claims its equipped tool for work."""
	var worker: int = _owners.residents.directory().get_typed_row(_crew.worker)
	var result: RefCounted = _owners.jobs.assign_worker(worker, _job)
	if result.ok: result = _owners.work.claim_tool_for_work(worker, _crew.tool)
	return &"" if result.ok else result.error


func _begin_travel(task: Task, job: Vector2i, tick: int) -> StringName:
	"""A pending installation retreat leg goes first on its own profile; then the station's travel profile."""
	if _retreat != NULL_REF:
		var target: Vector2i = _retreat
		_retreat = NULL_REF
		return _leg(job, target, _retreat_profile, _retreat_revision, tick)
	return _leg(job, task.station, task.travel_profile, task.travel_revision, tick)


func _leg(job: Vector2i, target: Vector2i, profile: int, revision: int, tick: int) -> StringName:
	"""Hand the recovered source to one explicit travel profile and request the real itinerary."""
	_leg_target = target
	_leg_profile = profile
	_leg_revision = revision
	var code: StringName = _owners.routes.refresh_travel_actor(_crew.worker, job, profile, revision, _content,
		0, -1, _crew.tool)
	return _owners.routes.request_route(_crew.worker, target, tick) if code == &"" else code


func _travel(tick: int) -> StringName:
	"""Advance real route ticks; a source-ready retreat arrival starts the next leg, the station arrival turns."""
	var task: Task = _tasks[_index]
	var job: Vector2i = _owners.jobs.ref_of(_job)
	_owners.routes.advance_tick(tick)
	var code: StringName = _owners.routes.read_actor_into(_crew.worker, _actor)
	if code != &"": return code
	if _actor.phase == Routes.PHASE_HELD: return &"ENTRY_FOREMAN_ROUTE_HELD"
	if _actor.location != _leg_target or Routes.source_ready_leaf_refusal(_owners.routes, _crew.worker, job,
			_leg_profile, _leg_revision, _content) != &"": return &""
	if _leg_target != task.station:
		_stage_ticks = 0
		return _begin_travel(task, job, tick)
	code = WorldRoutes.turn_actor(_owners.binding, _crew.worker, job, task.yaw, Space.MAX_CHECKS)
	if code == &"": code = _refresh_work(task, job)
	if code == &"": _set_stage(STAGE_ENTER)
	return code


func _refresh_work(task: Task, job: Vector2i) -> StringName:
	"""Select the station's exact WORK source for the current Job."""
	return _owners.routes.refresh_work_actor(_crew.worker, job, task.work_profile, task.work_revision,
		_content, 0, -1, _crew.tool)


func _enter(tick: int) -> StringName:
	"""The canonical source entry must reach WORK through real route ticks before payment."""
	var task: Task = _tasks[_index]
	if Routes.source_work_leaf_refusal(_owners.routes, _crew.worker, _owners.jobs.ref_of(_job),
			task.work_profile, task.work_revision, _content) == &"":
		_set_stage(STAGE_START)
		return &""
	_owners.routes.advance_tick(tick)
	return &""


func _start(tick: int) -> StringName:
	"""Claim the exact existing input stock, record delivery, bind the worker and START the paid phase."""
	var task: Task = _tasks[_index]
	var code: StringName = _reserve_inputs(task)
	if code != &"": return code
	var result: RefCounted = _owners.sites.bind_worker(task.site)
	if result.ok: result = _owners.sites.begin_phase_work(task.site, tick)
	if not result.ok: return result.error
	_set_stage(STAGE_EARN)
	return &""


func _reserve_inputs(task: Task) -> StringName:
	"""Each authored input line draws its exact quantity from the crew's lot for that key."""
	var count: int = Contract.input_count(task.operation)
	for line: int in count:
		var key: StringName = Contract.input_key(task.operation, line)
		var at: int = _crew.lot_keys.find(key)
		if at < 0: return &"ENTRY_FOREMAN_INPUT_LOT"
		var batch: PackedInt64Array = PackedInt64Array([_crew.lots[at].x, _crew.lots[at].y,
			Reservations.PURPOSE_EXCAVATION_INPUT, Contract.input_milli(task.operation, line), 100000])
		var claimed: RefCounted = _owners.pool.claim_batch(_owners.jobs.ref_of(_job), batch, 1, _owners.inventory)
		if not claimed.ok: return claimed.error
	if count == 0: return &""
	var delivered: RefCounted = _owners.sites.record_deliveries(task.site)
	return &"" if delivered.ok else delivered.error


func _earn(tick: int) -> StringName:
	"""One real Work tick per fixed tick; zero remaining work hands the source back to READY."""
	_owners.routes.advance_tick(tick)
	if not _owners.jobs.remaining_mwu_into(_job, _math): return REFUSE_STATE
	if _math.value > 0:
		var worked: RefCounted = _owners.work.tick_solo(_job)
		if not worked.ok: return worked.error
		_accepted_mwu += worked.accepted_mwu
		return &""
	var code: StringName = _owners.routes.request_source_ready(_crew.worker, _owners.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_RECOVER)
	return code


func _recover(tick: int) -> StringName:
	"""Full source recovery precedes the paid settlement that releases the Job and tool claim."""
	var task: Task = _tasks[_index]
	if Routes.source_ready_leaf_refusal(_owners.routes, _crew.worker, _owners.jobs.ref_of(_job),
			task.work_profile, task.work_revision, _content) != &"":
		_owners.routes.advance_tick(tick)
		return &""
	var settled: RefCounted = _owners.sites.settle_phase(task.site)
	if not settled.ok: return settled.error
	_index += 1
	return _next_step()


func _next_step() -> StringName:
	"""Start the next planned step: a cut phase opens, an installation derives its plan now, or all is done."""
	if _index >= _tasks.size():
		_set_stage(STAGE_DONE)
		return &""
	if _tasks[_index].install_ordinal < 0:
		_set_stage(STAGE_OPEN)
		return &""
	var code: StringName = _begin_installation(_tasks[_index].install_ordinal)
	if code == &"": _set_stage(STAGE_INSTALL)
	return code


func _set_stage(stage: int) -> void:
	"""Every stage change restarts the per-stage stall budget."""
	_stage = stage
	_stage_ticks = 0


func _fail(code: StringName) -> StringName:
	"""Stop permanently with the first real refusal; nothing is retried or rolled back here."""
	_stage = STAGE_FAILED
	_error = code
	return code


func is_done() -> bool:
	"""True once all planned phases have settled."""
	return _stage == STAGE_DONE


func error() -> StringName:
	"""The first refusal, or empty while running or after success."""
	return _error if _stage == STAGE_FAILED else &""


func task_count() -> int:
	"""Number of planned cut phases; installation steps are not phases."""
	var count: int = 0
	for task: Task in _tasks:
		if task.install_ordinal < 0: count += 1
	return count


func accepted_mwu() -> int:
	"""Work accepted by the real Work owner across all settled and current phases."""
	return _accepted_mwu


func configure_installation(paid: Installer.Paid, ordinal: int) -> StringName:
	"""Append the episodes needing this installed prefix, then the paid installation; nothing is touched."""
	if paid == null or ordinal != _install_count or _stage != STAGE_OPEN or _index != 0 or _tasks.is_empty():
		return REFUSE_PLAN
	var install: PackedInt32Array = PackedInt32Array()
	install.resize(Frontier.row_fields(Frontier.INSTALL))
	if _owners.frontier.installation_into(ordinal, install) != &"": return REFUSE_PLAN
	var before: int = _tasks.size()
	var code: StringName = _append_episodes(ordinal) if ordinal > 0 else &""
	if code != &"" or _tasks[_tasks.size() - 1].install_ordinal >= 0:
		_tasks.resize(before)
		return REFUSE_PLAN
	var step: Task = Task.new()
	step.install_ordinal = ordinal
	_tasks.append(step)
	_paid = paid
	_install_count += 1
	return &""


func _begin_installation(ordinal: int) -> StringName:
	"""Resolve the plan against the live Locations now, publish a contact path if needed, then configure."""
	var install: PackedInt32Array = PackedInt32Array()
	install.resize(Frontier.row_fields(Frontier.INSTALL))
	if _owners.frontier.installation_into(ordinal, install) != &"": return REFUSE_PLAN
	var plan: Installer.Plan = _installation_plan(ordinal, install)
	if plan == null: return REFUSE_PLAN
	var code: StringName = _connect_contact(install, plan)
	if code != &"": return code
	_installer = Installer.new()
	_last_install_stage = -1
	code = _installer.configure(_owners, _crew, _paid, plan)
	if code == &"": code = _plan_retreat(install, plan)
	return code


func _installation_plan(ordinal: int, install: PackedInt32Array) -> Installer.Plan:
	"""H from the install station, M from its material selector, profiles from the source; aliases refuse."""
	var station: PackedInt32Array = PackedInt32Array()
	station.resize(Frontier.row_fields(Frontier.STATION))
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.station_into(install[1], station, revision) != &"": return null
	var plan: Installer.Plan = Installer.Plan.new()
	plan.ordinal = ordinal
	plan.placement = _placement
	plan.install_profile = station[5]
	plan.install_revision = revision.value
	plan.station = _resolve_endpoint(_placement.x, station[0])
	plan.material = _resolve_endpoint(_placement.x, install[7])
	var approach: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.endpoint_travel_into(station[0], approach, revision) != &"": return null
	plan.approach_profile = approach.value
	plan.approach_revision = revision.value
	return _finish_plan(plan)


func _finish_plan(plan: Installer.Plan) -> Installer.Plan:
	"""The worker leaves the preceding cut on its profile; only L0's START retires episodes 0 and 1 (ADR1191)."""
	var last: Task = _tasks[_index - 1]
	plan.walk_profile = last.travel_profile
	plan.walk_revision = last.travel_revision
	var profiles: RefCounted = _owners.profiles
	plan.handling_revision = profiles._live.quantities[Profiles.L_REVISION * profiles._profile_capacity + Assembly.PROFILE]
	if plan.ordinal == 0:
		plan.retired_first = _tasks[0].station
		plan.retired_second = _tasks[OPERATIONS.size()].station
	return plan if plan.station != NULL_REF and plan.material != NULL_REF else null


func _connect_contact(install: PackedInt32Array, plan: Installer.Plan) -> StringName:
	"""A station on an installed contact has no route edge yet: publish M <-> contact through WorldRoutes."""
	var station: PackedInt32Array = PackedInt32Array()
	station.resize(Frontier.row_fields(Frontier.STATION))
	var endpoint: PackedInt32Array = PackedInt32Array()
	endpoint.resize(Frontier.row_fields(Frontier.ENDPOINT))
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.station_into(install[1], station, revision) != &"" \
			or _owners.frontier.endpoint_into(station[0], endpoint) != &"": return REFUSE_PLAN
	if endpoint[0] != Frontier.INSTALLED_CONTACT: return &""
	var ends: ContactPath.Ends = ContactPath.Ends.new()
	ends.ground = plan.material
	ends.contact = plan.station
	ends.origin = _world_point(_placement.x, 0, 0, 0)
	ends.content_revision = _content
	return ContactPath.publish(_owners.anchor, _owners.binding, _owners.routes, _paid.budget,
		_owners.binding._owner(), ends, _owners.locations)


func _plan_retreat(install: PackedInt32Array, plan: Installer.Plan) -> StringName:
	"""A distinct authored retreat endpoint becomes the first leg after this installation, on its own profile."""
	var retreat: Vector2i = _resolve_endpoint(_placement.x, install[8])
	if retreat == NULL_REF: return REFUSE_PLAN
	if retreat == plan.station: return &""
	var profile: IntMath.IntResult = IntMath.IntResult.new()
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.endpoint_travel_into(install[8], profile, revision) != &"": return REFUSE_PLAN
	_retreat_profile = profile.value
	_retreat_revision = revision.value
	_pending_retreat = retreat
	return &""


func _install(tick: int) -> StringName:
	"""Delegate every tick to the installer until its one whole-group commit, then take the next step."""
	var code: StringName = _installer.advance(tick)
	if code != &"": return code
	if _installer.stage() == Installer.STAGE_DONE:
		_install_mwu += _installer.accepted_mwu()
		_installer = null
		_retreat = _pending_retreat
		_pending_retreat = NULL_REF
		_index += 1
		return _next_step()
	_stage_ticks = 0 if _installer.stage() != _last_install_stage else _stage_ticks
	_last_install_stage = _installer.stage()
	return &""


func install_mwu() -> int:
	"""Fastening work accepted across completed and current installations, or zero."""
	return _install_mwu + (_installer.accepted_mwu() if _installer != null else 0)
