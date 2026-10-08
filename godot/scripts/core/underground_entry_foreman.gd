extends RefCounted
## ADR1196/ADR1202: fixed-tick dispatcher for the first-entry prefix: the L0 cuts, the paid L0 installation,
## the T0 cuts and the paid T0 installation. The plan is derived from the immutable Frontier and Placement only;
## every step is a real owner call whose own final guards decide. Surface arrival and hauling are outside it.
## ADR1217 step 5 (DEC-052): the crew digs with its claws and fits by paw. Every BUILD Job is bound tool-free
## (GATE_NOT_REQUIRED), nothing is claimed, and Routes receives no tool hint.

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
const ContactPath := preload("res://scripts/core/underground_entry_contact_path.gd")
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
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
const STAGE_HAUL: int = 9
## ADR1225: the crew was lost; the step resumes from the replacement's arrival at H (or waits for one).
const STAGE_RESUME: int = 10
## ADR1226 (REQ-SET-034): the crew's hour forbids work; its source recovers to READY at the station and waits there.
const STAGE_REST: int = 11
const REFUSE_SCHEDULE_REST: StringName = &"WORK_SCHEDULE_REST"
const STAGE_TICK_LIMIT: int = 1200
const REFUSE_PLAN: StringName = &"ENTRY_FOREMAN_PLAN"
const REFUSE_STALL: StringName = &"ENTRY_FOREMAN_STALLED"
const REFUSE_STATE: StringName = &"ENTRY_FOREMAN_STATE"
const Construction := preload("res://scripts/core/construction.gd")


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
	var items: RefCounted = null # Compiled item ids of the authored input keys (ADR1210).
	var delivery: RefCounted = null # ADR1210: when bound, missing inputs are hauled from R's staging to M.


class Crew extends RefCounted:
	## One worker and the source-selected containers. Inputs are drawn from whatever free stock of each input item
	## the storage container holds (ADR1210); no caller names a lot.
	var worker: Vector2i = NULL_REF
	## DEC-052: always null (no tool). Kept because the ADR1218 progress record writes the crew's five handles.
	var tool: Vector2i = NULL_REF
	var storage: Vector2i = NULL_REF
	var output: Vector2i = NULL_REF
	## ADR1219: the endpoint the worker stands on when it is first registered with Routes (the stair-top anchor H
	## after its surface walk). NULL_REF admits it on the first station instead (fixtures that place it there).
	var arrival: Vector2i = NULL_REF


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
var _hauler: Hauler = null
var _arrival_profile: int = -1 # ADR1219: H's own authored travel profile, the one it registers the worker on.
var _arrival_revision: int = 0
var _arrival_retreat: Vector2i = NULL_REF
var _arrival_retreat_profile: int = -1
var _arrival_retreat_revision: int = 0
var _haul_mwu: int = 0
var _haul_trips: int = 0
var _haul_marker: int = -1


func configure(owners: Owners, crew: Crew, placement: Vector2i) -> StringName:
	"""Derive all twelve L0 phase tasks from the loaded Frontier before any owner is touched."""
	if owners == null or crew == null or owners.frontier == null or owners.placements == null or owners.items == null:
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
		STAGE_HAUL: return _haul(tick)
		STAGE_RESUME: return _resume(tick)
		STAGE_REST: return _rest(tick)
	return REFUSE_STATE


func _open(tick: int) -> StringName:
	"""Admit the real phase Project and its BUILD Job, haul any missing inputs, then take the Job."""
	var task: Task = _tasks[_index]
	var opened: RefCounted = _owners.sites.open_phase(task.site, task.operation)
	if not opened.ok: return opened.error
	if not _owners.construction.remaining_mwu_into(opened.ref, _math): return REFUSE_STATE
	var made: RefCounted = _owners.jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, 0)
	if not made.ok: return made.error
	_job = made.value
	var ref: Vector2i = _owners.jobs.ref_of(_job)
	var code: StringName = _bind_phase_job(task, opened.ref, ref)
	var queue: PackedInt32Array = PackedInt32Array()
	if code == &"": code = _phase_units(task, queue)
	if code == &"" and not queue.is_empty(): return _begin_haul(task, opened.ref, queue, tick)
	if code == &"": code = _assign()
	return _place_actor(task, ref, tick) if code == &"" else code


func _phase_units(task: Task, out: PackedInt32Array) -> StringName:
	"""ADR1210: whole units of each brace input beyond M's free stock; none without a bound Delivery."""
	out.clear()
	if _owners.delivery == null: return &""
	var items: PackedInt32Array = PackedInt32Array()
	var milli: PackedInt64Array = PackedInt64Array()
	for line: int in Contract.input_count(task.operation):
		items.append(_owners.items.compiled_id(Contract.input_key(task.operation, line)))
		milli.append(Contract.input_milli(task.operation, line))
	return Hauler.units_into(_owners, _crew.storage, items, milli, out)


func _begin_haul(task: Task, project: Vector2i, queue: PackedInt32Array, tick: int) -> StringName:
	"""Any pending retreat leg first, then the station's travel profile to M; the BUILD Job brings the worker home.
	ADR1219: an unregistered worker is admitted at its arrival on the arrival's own profile (the first leg)."""
	var legs: Array[Hauler.Leg] = []
	var start: Vector2i = task.station
	if _arriving():
		start = _crew.arrival
		legs.append(_haul_leg(_crew.arrival, _arrival_profile, _arrival_revision))
		_take_arrival_retreat()
	if _retreat != NULL_REF: legs.append(_haul_leg(_retreat, _retreat_profile, _retreat_revision))
	_retreat = NULL_REF
	legs.append(_haul_leg(_owners.inventory.spatial_location_of(_crew.storage), task.travel_profile, task.travel_revision))
	_hauler = Hauler.new()
	_haul_marker = -1
	var code: StringName = _hauler.begin(_owners, _crew, project, _job, queue, legs, start, tick)
	if code == &"": _set_stage(STAGE_HAUL)
	return code


static func _haul_leg(target: Vector2i, profile: int, revision: int) -> Hauler.Leg:
	"""One tooled approach leg."""
	var leg: Hauler.Leg = Hauler.Leg.new()
	leg.target = target
	leg.profile = profile
	leg.revision = revision
	return leg


func _haul(tick: int) -> StringName:
	"""Delegate to the hauler; once home on M, travel to the station (a switch at rest back to the claw rows)."""
	var code: StringName = _hauler.advance(tick)
	if code != &"": return code
	var marker: int = _hauler.trips() * 16 + _hauler.stage()
	_stage_ticks = 0 if marker != _haul_marker else _stage_ticks
	_haul_marker = marker
	if _hauler.stage() != Hauler.STAGE_DONE: return &""
	_haul_mwu += _hauler.haul_mwu()
	_haul_trips += _hauler.trips()
	_hauler = null
	var task: Task = _tasks[_index]
	_set_stage(STAGE_TRAVEL)
	return _leg(_owners.jobs.ref_of(_job), task.station, task.travel_profile, task.travel_revision, tick)


func _place_actor(task: Task, job: Vector2i, tick: int) -> StringName:
	"""First arrival admits the worker where it physically stands; later phases travel or reuse the station."""
	var worker: int = _owners.residents.directory().get_typed_row(_crew.worker)
	if _arriving() and _crew.arrival != task.station:
		return _admit_at_arrival(task, job, tick)
	if _owners.routes._resident_ref(worker) == NULL_REF:
		_set_stage(STAGE_ENTER)
		return _owners.routes.admit_work_actor(_crew.worker, job, task.station, task.work_profile,
			task.work_revision, _content, 0, -1, NULL_REF)
	if _owners.routes._resident_pair(Routes.R_LOCATION_SLOT, worker) == task.station:
		_set_stage(STAGE_ENTER)
		return _refresh_work(task, job)
	_set_stage(STAGE_TRAVEL)
	return _begin_travel(task, job, tick)


func _admit_at_arrival(task: Task, job: Vector2i, tick: int) -> StringName:
	"""ADR1219: register the worker where its surface walk ended, on the arrival's own profile; it leaves by the
	arrival's authored retreat, then travels to the station."""
	_set_stage(STAGE_TRAVEL)
	var code: StringName = _owners.routes.admit_travel_actor(_crew.worker, job, _crew.arrival, _arrival_profile,
		_arrival_revision, _content, 0, -1, NULL_REF)
	if code != &"": return code
	_take_arrival_retreat()
	return _begin_travel(task, job, tick)


func _arriving() -> bool:
	"""ADR1219: the worker is not yet a route actor and has a planned arrival endpoint to be registered on."""
	return _crew.arrival != NULL_REF and _arrival_profile >= 0 \
		and _owners.routes._resident_ref(_owners.residents.directory().get_typed_row(_crew.worker)) == NULL_REF


func _take_arrival_retreat() -> void:
	"""The arrival's authored way out becomes the pending retreat leg (none when it retreats onto itself)."""
	if _arrival_retreat == NULL_REF: return
	_retreat = _arrival_retreat
	_retreat_profile = _arrival_retreat_profile
	_retreat_revision = _arrival_retreat_revision


func plan_arrival(arrival: Vector2i) -> StringName:
	"""ADR1219: the surface arrival must be the first installation's authored handling station (H). The worker is
	registered there on H's own authored travel profile and leaves by that installation's authored retreat."""
	var install: PackedInt32Array = PackedInt32Array()
	install.resize(Frontier.row_fields(Frontier.INSTALL))
	var station: PackedInt32Array = PackedInt32Array()
	station.resize(Frontier.row_fields(Frontier.STATION))
	var profile: IntMath.IntResult = IntMath.IntResult.new()
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _crew == null or _owners.frontier.installation_into(0, install) != &"" \
			or _owners.frontier.station_into(install[1], station, revision) != &"" \
			or _resolve_endpoint(_placement.x, station[0]) != arrival \
			or _owners.frontier.endpoint_travel_into(station[0], profile, revision) != &"": return REFUSE_PLAN
	_arrival_profile = profile.value
	_arrival_revision = revision.value
	_arrival_retreat = _resolve_endpoint(_placement.x, install[8])
	if _arrival_retreat == NULL_REF or _owners.frontier.endpoint_travel_into(install[8], profile, revision) != &"":
		return REFUSE_PLAN
	_arrival_retreat = NULL_REF if _arrival_retreat == arrival else _arrival_retreat
	_arrival_retreat_profile = profile.value
	_arrival_retreat_revision = revision.value
	_crew.arrival = arrival
	return &""


func arrival_yaw() -> int:
	"""The heading the arrival profile is authored at, or -1 when it admits every heading (none is derived)."""
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	if _arrival_profile < 0 or _owners.profiles.descriptor_into(_arrival_profile, _content, descriptor) != &"": return -1
	return descriptor.yaw if descriptor.yaw_kind == Profiles.YAW_EXACT else -1


func _bind_phase_job(task: Task, project: Vector2i, job: Vector2i) -> StringName:
	"""The Job names its Project, needs no tool (DEC-052: claws), its Site and the source-selected containers."""
	var result: RefCounted = _owners.jobs.set_requester(_job, project)
	if result.ok: result = _owners.jobs.set_tool_gate(_job, Jobs.GATE_NOT_REQUIRED)
	if result.ok: result = _owners.sites.bind_job(task.site, job)
	if result.ok: result = _owners.sites.bind_material_container(task.site, _crew.storage)
	if result.ok and task.operation == Contract.OP_CUT: result = _owners.sites.bind_output(task.site, _crew.output)
	return &"" if result.ok else result.error


func _assign() -> StringName:
	"""The same real worker takes the Job; nothing is claimed (DEC-052)."""
	var result: RefCounted = _owners.jobs.assign_worker(_owners.residents.directory().get_typed_row(_crew.worker), _job)
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
		0, -1, NULL_REF)
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
		_content, 0, -1, NULL_REF)


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
	"""Claim the exact existing input stock, record delivery, bind the worker and START the paid phase.
	ADR1225: a phase a lost crew had already started is not paid again; the replacement is bound and resumes it."""
	var task: Task = _tasks[_index]
	if _phase_started(task): return _resume_started(task)
	var code: StringName = _reserve_inputs(task)
	if code != &"": return code
	var result: RefCounted = _owners.sites.bind_worker(task.site)
	if result.ok: result = _owners.sites.begin_phase_work(task.site, tick)
	if not result.ok: return result.error
	_set_stage(STAGE_EARN)
	return &""


func _phase_started(task: Task) -> bool:
	"""ADR1225: the paid START already ran for this step's Project (it is WORKING or its work is done)."""
	if not _owners.construction.phase_into(_owners.sites.project_of(task.site), _math): return false
	return _math.value == Construction.PHASE_WORKING or _math.value == Construction.PHASE_WORK_DONE


func _resume_started(task: Task) -> StringName:
	"""ADR1225: bind the replacement where the lost crew worked; funded work resumes, finished work recovers."""
	var working: bool = _owners.construction.phase_into(_owners.sites.project_of(task.site), _math) 		and _math.value == Construction.PHASE_WORKING
	var result: RefCounted = _owners.sites.bind_worker(task.site)
	if result.ok and working: result = _owners.sites.resume_phase_work(task.site)
	if not result.ok: return result.error
	_set_stage(STAGE_EARN)
	return &""


func _reserve_inputs(task: Task) -> StringName:
	"""Each authored input line claims its exact quantity from the free stock of its item in the Site's storage."""
	var count: int = Contract.input_count(task.operation)
	for line: int in count:
		var code: StringName = Installer.claim_stock(_owners, _crew.storage, _owners.jobs.ref_of(_job),
			_owners.items.compiled_id(Contract.input_key(task.operation, line)), Contract.input_milli(task.operation, line),
			Reservations.PURPOSE_EXCAVATION_INPUT)
		if code != &"": return code
	if count == 0: return &""
	var delivered: RefCounted = _owners.sites.record_deliveries(task.site)
	return &"" if delivered.ok else delivered.error


func _earn(tick: int) -> StringName:
	"""One real Work tick per fixed tick; zero remaining work hands the source back to READY."""
	_owners.routes.advance_tick(tick)
	if not _owners.jobs.remaining_mwu_into(_job, _math): return REFUSE_STATE
	if _math.value > 0:
		var worked: RefCounted = _owners.work.tick_solo(_job)
		if not worked.ok: return _rest_or(worked.error)
		_accepted_mwu += worked.accepted_mwu
		return &""
	var code: StringName = _owners.routes.request_source_ready(_crew.worker, _owners.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_RECOVER)
	return code


func _rest_or(code: StringName) -> StringName:
	"""ADR1226: Work stopped at a 30-WU safe point because the crew's hour forbids work; the source recovers to
	READY at the station, the resting point, instead of failing."""
	if code != REFUSE_SCHEDULE_REST: return code
	code = _owners.routes.request_source_ready(_crew.worker, _owners.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_REST)
	return code


func _rest(tick: int) -> StringName:
	"""ADR1226: recover to READY, wait while the hour forbids work, then re-enter WORK; START resumes the funded
	phase (ADR1225's path) without paying again."""
	var task: Task = _tasks[_index]
	var job: Vector2i = _owners.jobs.ref_of(_job)
	if Routes.source_ready_leaf_refusal(_owners.routes, _crew.worker, job, task.work_profile, task.work_revision,
			_content) != &"":
		_owners.routes.advance_tick(tick)
		return &""
	if _owners.jobs.schedule().rests_now(_owners.residents.directory().get_typed_row(_crew.worker)): return &""
	var code: StringName = _refresh_work(task, job)
	if code == &"": _set_stage(STAGE_ENTER)
	return code


func _recover(tick: int) -> StringName:
	"""Full source recovery precedes the paid settlement that releases the Job."""
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


func halt(code: StringName) -> StringName:
	"""ADR1223: the runtime stops the chain for a reason outside the dispatch (crew loss, arrival); same as a refusal."""
	return _fail(code) if not _terminal() else _error


func release_lost_crew() -> StringName:
	"""ADR1225: detach the dispatch from a crew that died or left: cancel its admitted haul, release its Job
	(Sites' own departure path once the phase is bound), unregister its actor, then wait in RESUME for
	a replacement. Paid progress, consumed inputs and the parked Jobs stay; carried goods stay with the lost crew.
	DEC-057: a paid installation is released by its installer and re-handled in place by the replacement."""
	if _terminal(): return _error
	var lost: Vector2i = _crew.worker
	var row: int = _owners.residents.directory().get_typed_row(lost)
	var code: StringName = _release_haul(lost, row)
	if code == &"" and _installer != null: code = _installer.release_lost_crew(lost, row)
	elif code == &"" and _job >= 0 and _owners.jobs.worker_of(_job) == lost: code = _release_phase_job(row)
	if code == &"" and _owners.routes._lost_actor_row(lost) >= 0: code = _owners.routes.unregister_lost_actor(lost)
	if code != &"": return code
	_crew.worker = NULL_REF
	_crew.tool = NULL_REF
	_retreat = NULL_REF
	if _installer == null: _set_stage(STAGE_RESUME)
	return &""


func _release_haul(lost: Vector2i, row: int) -> StringName:
	"""The admitted haul's claims go back through Delivery's own cancel; its HAUL Job is retired."""
	if _hauler == null: return &""
	var hauler: Hauler = _hauler
	_haul_mwu += _hauler.haul_mwu()
	_haul_trips += _hauler.trips()
	_hauler = null
	_haul_marker = -1
	return hauler.release_lost(lost, row)


func _release_phase_job(row: int) -> StringName:
	"""Sites releases a bound phase worker itself; before START only the Job is released (nothing is claimed)."""
	if row < 0: return &""
	var task: Task = _tasks[_index]
	if _stage in [STAGE_START, STAGE_EARN, STAGE_RECOVER, STAGE_REST]:
		var departed: RefCounted = _owners.sites.release_worker(task.site)
		return &"" if departed.ok else departed.error
	var released: RefCounted = _owners.jobs.release_worker(row)
	return &"" if released.ok else released.error


func _resume(tick: int) -> StringName:
	"""ADR1225: the replacement, unregistered at H, continues the interrupted step exactly as a first arrival does:
	an unopened step opens; an open one hauls what M still lacks or takes the parked Job and travels to the station."""
	if _crew.worker == NULL_REF: return &""
	var task: Task = _tasks[_index]
	if _owners.sites.job_of(task.site) != _owners.jobs.ref_of(_job) or _owners.sites.job_of(task.site) == NULL_REF:
		_set_stage(STAGE_OPEN)
		return &""
	var queue: PackedInt32Array = PackedInt32Array()
	var code: StringName = &"" if _phase_started(task) else _phase_units(task, queue)
	if code == &"" and not queue.is_empty():
		return _begin_haul(task, _owners.sites.project_of(task.site), queue, tick)
	if code == &"": code = _assign()
	return _place_actor(task, _owners.jobs.ref_of(_job), tick) if code == &"" else code


func awaiting_crew() -> bool:
	"""ADR1225: the crew was lost and no replacement has been chosen yet (a cut step or an installation)."""
	return _crew.worker == NULL_REF and (_stage == STAGE_RESUME or _stage == STAGE_INSTALL)


func is_done() -> bool:
	"""True once all planned phases have settled."""
	return _stage == STAGE_DONE


func error() -> StringName:
	"""The first refusal, or empty while running or after success."""
	return _error if _stage == STAGE_FAILED else &""


func first_station() -> Vector2i:
	"""The Location the first planned phase works at, where the worker must already stand; null before planning."""
	return _tasks[0].station if not _tasks.is_empty() else NULL_REF


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
	return _finish_plan(plan) if _plan_arrival(install, plan) else null


func _plan_arrival(install: PackedInt32Array, plan: Installer.Plan) -> bool:
	"""ADR1202 split landing: when M's own travel profile is not the station's narrow approach, the worker
	changes profile at the authored retreat endpoint (the arrival), as Contacts' admission proves."""
	var profile: IntMath.IntResult = IntMath.IntResult.new()
	var revision: IntMath.IntResult = IntMath.IntResult.new()
	if _owners.frontier.endpoint_travel_into(install[7], profile, revision) != &"": return false
	if profile.value == plan.approach_profile and revision.value == plan.approach_revision: return true
	plan.material_profile = profile.value
	plan.material_revision = revision.value
	plan.arrival = _resolve_endpoint(_placement.x, install[8])
	return plan.arrival != NULL_REF and plan.arrival != plan.station


func _finish_plan(plan: Installer.Plan) -> Installer.Plan:
	"""The worker leaves the preceding cut on its profile; only L0's START retires episodes 0 and 1 (ADR1191)."""
	var last: Task = _tasks[_index - 1]
	plan.walk_profile = last.travel_profile
	plan.walk_revision = last.travel_revision
	var profiles: RefCounted = _owners.profiles
	var handling: int = Routes.Handling.profile_of(_paid.connector._workpieces, plan.ordinal)
	if handling < 0: return null
	plan.handling_revision = profiles._live.quantities[Profiles.L_REVISION * profiles._profile_capacity + handling]
	if plan.ordinal == 0:
		plan.retired_first = _tasks[0].station
		plan.retired_second = _tasks[OPERATIONS.size()].station
	return plan if plan.station != NULL_REF and plan.material != NULL_REF else null


func _connect_contact(install: PackedInt32Array, plan: Installer.Plan) -> StringName:
	"""A station on an installed contact has no route edge yet: publish M <-> (arrival <->) contact via WorldRoutes."""
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
	ends.arrival = plan.arrival
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
	if _installer.stage() == Installer.STAGE_RESUME: return _resume_installation(tick)
	var code: StringName = _installer.advance(tick)
	if code != &"": return code
	if _installer.stage() == Installer.STAGE_DONE:
		_install_mwu += _installer.accepted_mwu()
		_haul_mwu += _installer.haul_mwu()
		_haul_trips += _installer.haul_trips()
		_installer = null
		_retreat = _pending_retreat
		_pending_retreat = NULL_REF
		_index += 1
		return _next_step()
	_stage_ticks = 0 if _installer.progress_marker() != _last_install_stage else _stage_ticks
	_last_install_stage = _installer.progress_marker()
	return &""


func _resume_installation(tick: int) -> StringName:
	"""DEC-057: the replacement, unregistered on H, is registered there on H's own profile, leaves by its authored
	retreat and walks to M (hauling what M still lacks), then the installation continues from M and re-handles the
	piece in place without paying again."""
	if _crew.worker == NULL_REF or not _arriving(): return &""
	var legs: Array[Hauler.Leg] = [_haul_leg(_crew.arrival, _arrival_profile, _arrival_revision)]
	_take_arrival_retreat()
	if _retreat != NULL_REF: legs.append(_haul_leg(_retreat, _retreat_profile, _retreat_revision))
	_retreat = NULL_REF
	var plan: Installer.Plan = _installer._plan
	legs.append(_haul_leg(plan.material, plan.walk_profile, plan.walk_revision))
	_stage_ticks = 0
	return _installer.resume(legs, tick)


func haul_mwu() -> int:
	"""Lift and set-down Work of every completed haul, the foreman's and its installations' (ADR1210)."""
	return _haul_mwu + (_installer.haul_mwu() if _installer != null else 0)


func haul_trips() -> int:
	"""Whole units hauled from R's staging to M across the prefix (ADR1210)."""
	return _haul_trips + (_installer.haul_trips() if _installer != null else 0)


func install_mwu() -> int:
	"""Fastening work accepted across completed and current installations, or zero."""
	return _install_mwu + (_installer.accepted_mwu() if _installer != null else 0)


func capture(out: PackedByteArray) -> StringName:
	"""ADR1218 (G10): write this foreman's whole progress record at a quiescent tick boundary, in flight or not."""
	out.clear()
	if _owners == null: return Progress.REFUSE_TARGET
	var code: StringName = Progress.busy_refusal(_owners)
	if code != &"": return code
	var w: Progress.Writer = Progress.begin(Progress.KIND_FOREMAN)
	write_state(w)
	out.append_array(Progress.finish(w))
	return &"" if not out.is_empty() else Progress.REFUSE_SHAPE


func restore(bytes: PackedByteArray, owners: Owners, paid: Installer.Paid) -> StringName:
	"""ADR1218: rebuild a fresh foreman exactly from its record against the restored owners. A refused record
	leaves this foreman failed with the refusal as its error; it never touches an owner."""
	if _owners != null or not _tasks.is_empty(): return Progress.REFUSE_TARGET
	var r: Progress.Reader = Progress.Reader.new()
	var code: StringName = Progress.open(bytes, Progress.KIND_FOREMAN, r)
	if code == &"": code = read_state(r, owners, paid)
	if code == &"": code = Progress.close(r)
	if code == &"": code = canonical_refusal(bytes, Progress.KIND_FOREMAN)
	if code != &"": refuse_restore(code)
	return code


func canonical_refusal(bytes: PackedByteArray, kind: int) -> StringName:
	"""A restored foreman must write back exactly the record it was read from."""
	var w: Progress.Writer = Progress.begin(kind)
	write_state(w)
	return &"" if Progress.finish(w) == bytes else Progress.REFUSE_NONCANONICAL


func refuse_restore(code: StringName) -> void:
	"""Drop everything a refused record decoded; the foreman stays failed with that refusal."""
	_owners = null
	_crew = null
	_paid = null
	_tasks.clear()
	_installer = null
	_hauler = null
	_stage = STAGE_FAILED
	_error = code


static func write_crew(w: Progress.Writer, crew: Crew) -> void:
	"""The crew's five handles; ADR1219's arrival endpoint is null until the arrival is planned."""
	for at: Vector2i in [crew.worker, crew.tool, crew.storage, crew.output, crew.arrival]:
		w.ref(at)


static func read_crew(r: Progress.Reader) -> Crew:
	"""The crew's five handles in wire order."""
	var crew: Crew = Crew.new()
	crew.worker = r.ref()
	crew.tool = r.ref()
	crew.storage = r.ref()
	crew.output = r.ref()
	crew.arrival = r.ref()
	return crew


func _terminal() -> bool:
	"""Done or failed: nothing further reads the world, so sub-dispatchers are folded into the ledgers."""
	return _stage == STAGE_DONE or _stage == STAGE_FAILED


func _job_in_use() -> bool:
	"""Stages that still read the current phase's BUILD Job."""
	if _stage == STAGE_RESUME: return _index < _tasks.size() and _job >= 0 \
		and _owners.sites.job_of(_tasks[_index].site) == _owners.jobs.ref_of(_job)
	return _stage in [STAGE_TRAVEL, STAGE_ENTER, STAGE_START, STAGE_EARN, STAGE_RECOVER, STAGE_HAUL, STAGE_REST]


func write_state(w: Progress.Writer) -> void:
	"""ADR1218 wire order: crew, wiring flags, plan, cursor, ledgers, then the live installation and haul."""
	write_crew(w, _crew)
	w.flag(_owners.delivery != null)
	w.flag(_paid != null)
	w.i64(_content)
	w.ref(_placement)
	w.i32(_tasks.size())
	for task: Task in _tasks:
		_write_task(w, task)
	w.i32(_index)
	w.i32(_stage)
	w.i32(_stage_ticks)
	w.i32(_job)
	w.ref(Progress.job_ref(_owners.jobs, _job, _job_in_use()))
	w.code(_error if _stage == STAGE_FAILED else &"")
	_write_ledgers(w)
	_write_arrival(w)
	w.flag(_installer != null and not _terminal())
	if _installer != null and not _terminal(): _installer.write_state(w)
	w.flag(_hauler != null and not _terminal())
	if _hauler != null and not _terminal(): _hauler.write_state(w)


static func _write_task(w: Progress.Writer, task: Task) -> void:
	"""One planned step, exactly as configured; its station may since have retired."""
	w.i32(task.install_ordinal)
	w.ref(task.site)
	w.i32(task.operation)
	w.ref(task.station)
	w.i32(task.yaw)
	w.i32(task.work_profile)
	w.i64(task.work_revision)
	w.i32(task.travel_profile)
	w.i64(task.travel_revision)


func _write_arrival(w: Progress.Writer) -> void:
	"""ADR1219: H's own registration row and the authored retreat the worker leaves H by."""
	w.i32(_arrival_profile)
	w.i64(_arrival_revision)
	w.ref(_arrival_retreat)
	w.i32(_arrival_retreat_profile)
	w.i64(_arrival_retreat_revision)


func _read_arrival(r: Progress.Reader) -> void:
	"""ADR1219 arrival plan in wire order."""
	_arrival_profile = r.i32()
	_arrival_revision = r.i64()
	_arrival_retreat = r.ref()
	_arrival_retreat_profile = r.i32()
	_arrival_retreat_revision = r.i64()


func _write_ledgers(w: Progress.Writer) -> void:
	"""Work ledgers and leg/retreat cursors; a terminal foreman writes its getters' folded totals."""
	w.i64(_accepted_mwu)
	w.i32(_install_count)
	w.i64(install_mwu() if _terminal() else _install_mwu)
	w.i32(_last_install_stage)
	w.ref(_leg_target)
	w.i32(_leg_profile)
	w.i64(_leg_revision)
	w.ref(_retreat)
	w.i32(_retreat_profile)
	w.i64(_retreat_revision)
	w.ref(_pending_retreat)
	w.i64(haul_mwu() if _terminal() else _haul_mwu)
	w.i32(haul_trips() if _terminal() else _haul_trips)
	w.i32(_haul_marker)


func read_state(r: Progress.Reader, owners: Owners, paid: Installer.Paid) -> StringName:
	"""ADR1218: decode a saved foreman under the restored owners, then re-prove every handle it will still read."""
	if owners == null or owners.frontier == null or owners.placements == null or owners.items == null \
			or owners.profiles == null or owners.jobs == null:
		return Progress.REFUSE_OWNERS
	_owners = owners
	_crew = read_crew(r)
	var delivery: bool = r.flag()
	var paid_bound: bool = r.flag()
	_paid = paid
	_content = r.i64()
	_placement = r.ref()
	for index: int in r.ranged(1, Progress.MAX_TASKS):
		_tasks.append(_read_task(r))
	_index = r.ranged(0, _tasks.size())
	_stage = r.ranged(STAGE_OPEN, STAGE_REST)
	_stage_ticks = r.ranged(0, STAGE_TICK_LIMIT + 1)
	_job = r.i32()
	var job: Vector2i = r.ref()
	_error = r.code()
	_read_ledgers(r)
	_read_arrival(r)
	if (_stage == STAGE_FAILED) == (_error == &""): return Progress.REFUSE_SHAPE
	var code: StringName = _read_children(r)
	if code == &"" and (delivery != (owners.delivery != null) or paid_bound != (paid != null)):
		code = Progress.REFUSE_OWNERS
	if code != &"" or _terminal(): return code
	code = Progress.job_refusal(owners.jobs, _job, job, _job_in_use())
	return _restored_refusal(job) if code == &"" else code


static func _read_task(r: Progress.Reader) -> Task:
	"""One planned step in wire order."""
	var task: Task = Task.new()
	task.install_ordinal = r.i32()
	task.site = r.ref()
	task.operation = r.i32()
	task.station = r.ref()
	task.yaw = r.i32()
	task.work_profile = r.i32()
	task.work_revision = r.i64()
	task.travel_profile = r.i32()
	task.travel_revision = r.i64()
	return task


func _read_ledgers(r: Progress.Reader) -> void:
	"""Work ledgers and leg/retreat cursors in wire order."""
	_accepted_mwu = r.i64()
	_install_count = r.ranged(0, _tasks.size())
	_install_mwu = r.i64()
	_last_install_stage = r.i32()
	_leg_target = r.ref()
	_leg_profile = r.i32()
	_leg_revision = r.i64()
	_retreat = r.ref()
	_retreat_profile = r.i32()
	_retreat_revision = r.i64()
	_pending_retreat = r.ref()
	_haul_mwu = r.i64()
	_haul_trips = r.i32()
	_haul_marker = r.i32()


func _read_children(r: Progress.Reader) -> StringName:
	"""The installation exists exactly in STAGE_INSTALL and the haul exactly in STAGE_HAUL."""
	if r.bad or not _cursor_shape_ok(): return Progress.REFUSE_SHAPE
	var code: StringName = &""
	if r.flag() != (_stage == STAGE_INSTALL): return Progress.REFUSE_SHAPE
	if _stage == STAGE_INSTALL:
		if _paid == null: return Progress.REFUSE_OWNERS
		_installer = Installer.new()
		code = _installer.read_state(r, _owners, _crew, _paid)
		if code == &"" and _installer._plan.placement != _placement: code = Progress.REFUSE_SHAPE
	if code == &"" and r.flag() != (_stage == STAGE_HAUL): code = Progress.REFUSE_SHAPE
	if code == &"" and _stage == STAGE_HAUL:
		_hauler = Hauler.new()
		code = _hauler.read_state(r, _owners, _crew, _job)
	return code if not r.bad else Progress.REFUSE_SHAPE


func _cursor_shape_ok() -> bool:
	"""The cursor points at a step of the kind its stage runs; DONE is exactly past the last step."""
	if _stage == STAGE_DONE: return _index == _tasks.size()
	if _index >= _tasks.size() or _tasks.size() <= OPERATIONS.size() or _stage == STAGE_FAILED:
		return _stage == STAGE_FAILED and _index <= _tasks.size()
	return (_stage == STAGE_INSTALL) == (_tasks[_index].install_ordinal >= 0)


func _restored_refusal(job: Vector2i) -> StringName:
	"""Content, crew, Placement, every future task and every pending leg must exist in the restored owners."""
	if _content != _owners.profiles.content_revision(): return Progress.REFUSE_CONTENT
	var code: StringName = &"" if awaiting_crew() else _crew_refusal(_owners, _crew)
	var placements: RefCounted = _owners.placements
	if code == &"" and not placements._is_live(placements._live, _placement): code = Progress.REFUSE_PLACEMENT
	if code == &"": code = _task_refusal()
	if code == &"" and _stage == STAGE_TRAVEL: code = Progress.location_refusal(_owners.locations, _leg_target, false)
	for at: Vector2i in [_retreat, _pending_retreat]:
		if code == &"": code = Progress.location_refusal(_owners.locations, at, true)
	if code == &"" and _arriving(): # ADR1219: still to be registered on H, then to leave by its retreat.
		code = Progress.location_refusal(_owners.locations, _crew.arrival, false)
		if code == &"": code = Progress.location_refusal(_owners.locations, _arrival_retreat, true)
	if code == &"" and _stage in [STAGE_TRAVEL, STAGE_ENTER, STAGE_START, STAGE_EARN, STAGE_RECOVER, STAGE_REST]:
		code = Progress.actor_refusal(_owners, _crew.worker, job)
	return code


static func _crew_refusal(owners: RefCounted, crew: Crew) -> StringName:
	"""A live resident worker holding no tool (DEC-052) and two live spatial containers."""
	if owners.residents.directory().get_typed_row(crew.worker) < 0 or crew.tool != NULL_REF:
		return Progress.REFUSE_CREW
	for container: Vector2i in [crew.storage, crew.output]:
		if owners.inventory.spatial_location_of(container) == NULL_REF: return Progress.REFUSE_CREW
	return &""


func _task_refusal() -> StringName:
	"""Every step not yet settled needs its Site and station; an unstarted L0 still retires tasks 0 and 3."""
	for index: int in range(_index, _tasks.size()):
		var task: Task = _tasks[index]
		if task.install_ordinal >= 0:
			if task.install_ordinal == 0 and (index > _index or _stage != STAGE_INSTALL) \
					and (Progress.location_refusal(_owners.locations, _tasks[0].station, false) != &""
					or Progress.location_refusal(_owners.locations, _tasks[OPERATIONS.size()].station, false) != &""):
				return Progress.REFUSE_LOCATION
			continue
		if not _owners.sites.is_live_site(task.site): return Progress.REFUSE_SITE
		if Progress.location_refusal(_owners.locations, task.station, false) != &"": return Progress.REFUSE_LOCATION
	return &""
