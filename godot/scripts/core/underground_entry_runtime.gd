extends RefCounted
## ADR1197: drive the first entry in the real settlement, step by step, and stop at the first missing capability
## with its exact refusal code and gap row. Completed steps stay published; nothing is faked or rolled back.
## ADR1210 (G7): once the crew is chosen the foreman is planned here and advanced by SettlementSystem.run_tick.
## ADR1219 (G5, registration on arrival): the crew mole then walks from its surface pose to the stair-top anchor H
## over BAL-WORK-003's straight-leg tick count; on arrival its Transform is placed exactly on H and the foreman
## registers it with Routes there. No other surface resident is registered.
## ADR1223 (G6): the runtime is the Jobs dispatcher. The JobSelector never offers its Jobs (any Job an excavation or
## connector-installation Project requests) to anyone and never selects its crew; only the foreman commits them.

const Site := preload("res://scripts/core/underground_entry_site.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Haul := preload("res://scripts/core/haul_planner.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SEARCH_RINGS: int = 8
const REFUSE_SCOPE: StringName = &"ENTRY_RUNTIME_SCOPE"
const REFUSE_NO_TOOLED_MOLE: StringName = &"ENTRY_CREW_NO_TOOLED_MOLE"
const REFUSE_SURFACE_ARRIVAL: StringName = &"ENTRY_SURFACE_ARRIVAL_MISSING"
const REFUSE_CREW_LOST: StringName = &"ENTRY_CREW_LOST"
const INSTALLATIONS: int = 2 # The first-entry prefix: L0, then the T0 cuts and T0 (ADR1202).
const STEP_NONE: int = 0
const STEP_SITE: int = 1
const STEP_PUBLISHED: int = 2
const STEP_CONFIRMED: int = 3
const STEP_CONTAINERS: int = 4
const STEP_CREW: int = 5
const STEP_RUNNING: int = 6
const STEP_DONE: int = 7
## ADR1197 gap rows; an alert names the row that, once built, clears it.
const GAPS: Dictionary = {
	&"ENTRY_SITE_NONE_FOUND": "G1/G2 no surveyed entry site near the settlement",
	&"ENTRY_CREW_NO_TOOLED_MOLE": "G11 no adult mole with an equipped basic tool (tool equipping is not gameplay yet)",
	&"ROUTE_UNREGISTERED_RESIDENT_NEAR": "G5 a resident outside the entry crew stands within reach of the work area (surface Movement does not route residents around it yet; ADR 1219)",
	&"ENTRY_SURFACE_ARRIVAL_MISSING": "G5 the crew mole has no surface pose to walk from, or could not be placed on the stair-top anchor (ADR 1219)",
	&"JOB_HAS_WORKER": "G6 an entry Job already had another worker (the dispatch reservation should prevent this; ADR 1223)",
	&"JOB_AGENT_BUSY": "G6 every tooled adult mole already holds another Job; the crew is chosen only from idle moles (ADR 1223)",
	&"STEP2_ACTIVITY_FORBIDS_WORK": "G6 the crew's schedule forbade work when the foreman committed it (the runtime waits for a work hour; ADR 1223)",
	&"JOB_DISPATCHED_TO_CREW": "G6 an entry Job was committed to a resident outside the crew (ADR 1223)",
	&"JOB_AGENT_RESERVED_BY_DISPATCH": "G6 the crew was committed to a Job outside the entry (ADR 1223)",
	&"ENTRY_CREW_LOST": "G6 the crew left the settlement; choosing a replacement crew is not built (ADR 1223)",
	&"STEP1_RESIDENT_DEAD": "G6 the crew died; choosing a replacement crew is not built (ADR 1223)",
	&"STEP1_RESIDENT_INCAPACITATED": "G6 the crew was incapacitated mid-dispatch; interrupting and resuming a dispatch is not built (ADR 1223)",
	&"STEP1_REST_COLLAPSED": "G6 the crew collapsed from exhaustion mid-dispatch; interrupting and resuming a dispatch is not built (ADR 1223)",
	&"ROUTE_ASSEMBLY_ACTOR_UNBOUND": "G5 the paid installation's handling occupancy proof still requires every living resident to be a route actor (ADR 1219's reach-cube rule is not applied there yet; ADR 1224)",
	&"WORLD_COMPOSITION_BINDING": "G12 the phase provider has no bound structure provider, or a bound owner was rewired (ADR 1224 composes it at entry prefix 13)",
	&"ENTRY_FOREMAN_INPUT_LOT": "G4 inputs missing at M and no Delivery is composed to haul them from R's staging (ADR 1210)",
	&"ENTRY_HAUL_NO_STAGED_STOCK": "G4 surface stock must be staged at R's container; moving settlement stores to the entry anchor is not built (ADR 1210)",
}

var _step: int = STEP_NONE
var _error: StringName = &""
var _origin: Vector3i = Vector3i.ZERO
var _published: WorkArea.Published = WorkArea.Published.new()
var _storage: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _crew: Foreman.Crew = null
var _foreman: Foreman = null
var _jobs: RefCounted = null
var _worker_row: int = -1
var _transforms: Transforms = null
var _anchor: Vector3i = Vector3i.ZERO
var _walk_left: int = 0 # ADR1219: fixed ticks of the crew's surface walk still to run before arrival at H.
var _arrival_yaw: int = -1 # H's authored arrival heading, or -1 to keep the resident's own.
var _scratch: IntMath.IntResult = IntMath.IntResult.new() # ADR1223 dispatch reads; never state.


static func gap_of(code: StringName) -> String:
	"""The ADR1197 gap row an alert maps to, or an unclassified refusal that needs triage."""
	return GAPS.get(code, "unclassified refusal %s" % code)


func step() -> int:
	"""How far the real chain got."""
	return _step


func error() -> StringName:
	"""The first refusal, or empty."""
	return _error


func is_running() -> bool:
	"""True while the planned foreman still has work and has not refused."""
	return _step == STEP_RUNNING and _foreman.error() == &""


func crew() -> Foreman.Crew:
	"""The selected entry crew once chosen, or null; read-only for presentation (ADR 1211)."""
	return _crew


func origin() -> Vector3i:
	"""The surveyed entry origin once chosen."""
	return _origin


func start(session: RefCounted, near: Vector3i) -> StringName:
	"""Run every not-yet-done step in order; a refusal stops the chain and is retained for alerting."""
	if session == null or session._operations_prefix != 17 or session._operations_state != 2: return _stop(REFUSE_SCOPE)
	var o: RefCounted = session._retirement_owners
	var code: StringName = _choose_site(session, o, near) if _step < STEP_SITE else &""
	if code == &"" and _step < STEP_PUBLISHED: code = _publish(session, o)
	if code == &"" and _step < STEP_CONFIRMED: code = _confirm(session, o)
	if code == &"" and _step < STEP_CONTAINERS: code = _containers(o)
	if code == &"" and _step < STEP_CREW: code = _select_crew(o)
	if code == &"" and _step < STEP_RUNNING: code = _plan_foreman(o)
	if code == &"" and _step == STEP_RUNNING and _foreman.error() != &"": code = _foreman.error()
	return _stop(code) if code != &"" else &""


func walk_ticks_left() -> int:
	"""ADR1219: fixed ticks of the crew's surface walk to H still to run; zero once it has arrived."""
	return _walk_left


func advance(tick: int) -> StringName:
	"""ADR1210 G7: one fixed tick of the planned foreman; its first refusal stops the chain for alerting.
	ADR1219: while the crew walks to H the tick is the walk's; arrival places it on H the same tick."""
	if not is_running(): return &""
	var code: StringName = _crew_loss_refusal()
	if code != &"": return _halt(code)
	if _walk_left > 0:
		_walk_left -= 1
		if _walk_left > 0: return &""
		if not _place_on_anchor(): return _halt(REFUSE_SURFACE_ARRIVAL)
	if not _crew_ready(): return &""
	code = _foreman.advance(tick)
	if code != &"": return _stop(code)
	if _foreman.is_done(): _step = STEP_DONE
	return &""


func _halt(code: StringName) -> StringName:
	"""A runtime-level stop also fails the foreman, so the chain stops for good and the record carries the code."""
	_foreman.halt(code)
	return _stop(code)


func _crew_loss_refusal() -> StringName:
	"""ADR1223: the crew left (its row is gone or now names another resident) or died. Either stops the chain with
	its G6 alert; the entry's Jobs stay the dispatcher's, offered to nobody (no other resident can work them)."""
	if _foreman._owners.residents.directory().get_typed_row(_crew.worker) != _worker_row \
			or not _jobs.needs().status_into(_worker_row, _scratch):
		return REFUSE_CREW_LOST
	return Foreman.Jobs.REFUSE_RESIDENT_DEAD if _scratch.value == Needs.STATUS_DEAD else &""


func _crew_ready() -> bool:
	"""ADR1210/1223: an idle crew is committed only once the JobSelector has resolved its hour (within its 30-tick
	stagger) and that hour and its health permit work (GDD 5.3 steps 1-2); otherwise the dispatch waits, reserved,
	through the rest or night. A crew already holding a dispatched Job carries on (busy residents are not
	re-resolved anywhere in the settlement: REQ-SET-034's safe segment is a recorded gap)."""
	if _jobs.job_of(_worker_row) != NULL_REF: return true
	var activity: IntMath.IntResult = _jobs.schedule().current_activity_of(_worker_row)
	if not activity.ok or (activity.value != Foreman.Jobs.ACTIVITY_WORK
			and activity.value != Foreman.Jobs.ACTIVITY_ANYTHING):
		return false
	return _jobs.resident_may_work_into(_worker_row, _scratch)


func owns_job(job_slot: int) -> bool:
	"""ADR1223 dispatch rule: every Job an excavation phase or connector installation Project requests is the entry's,
	derived from saved Jobs and Construction state alone, so it holds after a stop and across a load."""
	if _foreman == null: return false
	var requester: Vector2i = _jobs.requester_of(job_slot)
	if not _foreman._owners.construction.purpose_into(requester, _scratch): return false
	return _scratch.value == Construction.PURPOSE_EXCAVATION \
		or _scratch.value == Construction.PURPOSE_CONNECTOR_INSTALL


func reserves_resident(resident_slot: int) -> bool:
	"""ADR1223: the crew is reserved from the foreman's planning while the chain can run, and for good once it is a
	route actor (ADR1219: it stays registered underground); a chain stopped before registration releases it."""
	if _foreman == null or resident_slot != _worker_row \
			or _foreman._owners.residents.directory().get_typed_row(_crew.worker) != _worker_row:
		return false
	return is_running() or _foreman._owners.routes._resident_ref(resident_slot) != NULL_REF


func _bind_dispatcher(o: RefCounted) -> StringName:
	"""ADR1223: this runtime answers the JobSelector's dispatch questions from now on (a restore rebinds)."""
	var bound: RefCounted = o.jobs.bind_dispatcher(owns_job, reserves_resident)
	return &"" if bound.ok else bound.error


func _stop(code: StringName) -> StringName:
	"""Retain the first refusal of this attempt."""
	_error = code
	return code


func _choose_site(session: RefCounted, o: RefCounted, near: Vector3i) -> StringName:
	"""Read-only survey of the cube grid around the requested point."""
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var code: StringName = Site.suggest(session._terrain, o.room_bindings._entry_frontier, o.space.revision(),
		near, SEARCH_RINGS, out)
	if code != &"": return code
	_origin = Vector3i(out[0], out[1], out[2])
	_step = STEP_SITE
	return &""


func _publish(session: RefCounted, o: RefCounted) -> StringName:
	"""All eleven endpoints, then all 31 paths, through the real SurfaceAnchor and WorldRoutes."""
	var code: StringName = WorkArea.publish_locations(session.surface_anchor(), _origin, _published)
	if code == &"": code = WorkArea.publish_paths(o.world_routes, o.routes, o.budget, o.space, _origin, _published,
		o.profiles.content_revision())
	if code == &"": _step = STEP_PUBLISHED
	return code


func _confirm(session: RefCounted, o: RefCounted) -> StringName:
	"""The EntryPlan comes from the mounted bundle and the published anchor; RoomOrders admits it."""
	var plan: RefCounted = Site.entry_plan(session._world_ref, o.space.revision(), _origin, _published.endpoints[0],
		o.world_routes._catalog, o.room_bindings._entry_frontier)
	if plan == null: return REFUSE_SCOPE
	var result: RefCounted = o.rooms.confirm_entry(plan)
	if not result.ok: return result.error
	_step = STEP_CONFIRMED
	return &""


func _containers(o: RefCounted) -> StringName:
	"""Material storage at M and spoil output at R are real spatial ground-staging containers."""
	var material: RefCounted = o.inventory.create_spatial_ground_staging(_published.endpoints[1])
	if not material.ok: return material.error
	var output: RefCounted = o.inventory.create_spatial_ground_staging(_published.endpoints[2])
	if not output.ok: return output.error
	_storage = material.ref
	_output = output.ref
	_step = STEP_CONTAINERS
	return &""


func _select_crew(o: RefCounted) -> StringName:
	"""The first idle adult mole holding an equipped tool lot; no tool is created or equipped here. ADR1223: a mole
	holding another Job is passed over (its Job is never taken from it), and `JOB_AGENT_BUSY` names that case."""
	var residents: RefCounted = o.residents
	var busy: bool = false
	for row: int in o.gear._row_capacity:
		if o.gear._occupied[row] != 1 or o.gear._equipped[row] != 1: continue
		var owner: Vector2i = Vector2i(o.gear._owner_slot[row], o.gear._owner_generation[row])
		var slot: int = residents.directory().get_typed_row(owner)
		if slot < 0 or not residents.is_present(slot) or residents.species_key(residents.species_of(slot).value) != &"mole":
			continue
		if o.jobs.job_of(slot) != NULL_REF:
			busy = true
			continue
		_crew = Foreman.Crew.new()
		_crew.worker = owner
		_crew.tool = Vector2i(o.gear._lot_slot[row], o.gear._lot_generation[row])
		_crew.storage = _storage
		_crew.output = _output
		_step = STEP_CREW
		return &""
	return Foreman.Jobs.REFUSE_AGENT_BUSY if busy else REFUSE_NO_TOOLED_MOLE


func _plan_foreman(o: RefCounted) -> StringName:
	"""Plan the whole prefix from the mounted Frontier, then require the crew mole on the first station (G5)."""
	var foreman: Foreman = Foreman.new()
	var code: StringName = foreman.configure(_foreman_owners(o), _crew, _entry_placement(o))
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = o.router; paid.connector = o.connector; paid.contacts = o.contacts; paid.budget = o.budget
	for ordinal: int in INSTALLATIONS:
		if code == &"": code = foreman.configure_installation(paid, ordinal)
	if code == &"": code = foreman.plan_arrival(_published.endpoints[0])
	if code == &"": code = _begin_walk(o, foreman.arrival_yaw())
	if code != &"": return code
	_foreman = foreman
	_jobs = o.jobs
	_worker_row = o.residents.directory().get_typed_row(_crew.worker)
	_step = STEP_RUNNING
	return _bind_dispatcher(o)


func _foreman_owners(o: RefCounted) -> Foreman.Owners:
	"""The mounted Session's own owners, borrowed unchanged."""
	var f: Foreman.Owners = Foreman.Owners.new()
	f.sites = o.sites; f.jobs = o.jobs; f.work = o.work; f.routes = o.routes; f.binding = o.world_routes
	f.residents = o.residents; f.pool = o.reservations; f.construction = o.construction; f.inventory = o.inventory
	f.profiles = o.profiles; f.frontier = o.room_bindings._entry_frontier; f.placements = o.placements
	f.locations = o.locations; f.anchor = o.surface_anchor; f.items = o.items; f.delivery = o.delivery; f.gear = o.gear
	return f


func _entry_placement(o: RefCounted) -> Vector2i:
	"""The one live entry Placement the confirmation created; zero or several plan nothing."""
	var found: Vector2i = NULL_REF
	for row: int in o.placements._capacity:
		var ref: Vector2i = Vector2i(row, o.placements._live.i32[o.placements.GENERATION * o.placements._capacity + row])
		if not o.placements._is_live(o.placements._live, ref): continue
		if found != NULL_REF: return NULL_REF
		found = ref
	return found


func _begin_walk(o: RefCounted, yaw: int) -> StringName:
	"""ADR1219: the crew walks from its surface pose to H (endpoint 0) over BAL-WORK-003's straight-leg lower bound
	ceil_div(D*30, v), D the exact integer length rounded up and v its size class's ground cap. No path, obstacle or
	clearance is modelled (no surface Navigation is composed); the Transform stays put until arrival places it."""
	var record: Foreman.Locations.Record = Foreman.Locations.Record.new()
	var pose: Transforms.Pose = Transforms.Pose.new()
	var ticks: IntMath.IntResult = IntMath.IntResult.new()
	record.envelope.resize(6)
	record.support.resize(6)
	if o.locations.read_location_into(_published.endpoints[0], record) != &"": return REFUSE_SCOPE
	if not o.transforms.read_into(_crew.worker, pose): return REFUSE_SURFACE_ARRIVAL
	var size: IntMath.IntResult = o.residents.size_class_of(o.residents.directory().get_typed_row(_crew.worker))
	var speed: IntMath.IntResult = o.residents.size_movement_u_per_s(size.value) if size.ok else size
	if not speed.ok: return REFUSE_SURFACE_ARRIVAL
	var length: int = ceil_length(record.point - Vector3i(pose.x, pose.y, pose.z))
	if not Haul.travel_ticks_into(length, speed.value, ticks): return REFUSE_SURFACE_ARRIVAL
	_anchor = record.point
	_arrival_yaw = yaw
	_transforms = o.transforms
	_walk_left = ticks.value
	return &"" if ticks.value > 0 or _place_on_anchor() else REFUSE_SURFACE_ARRIVAL


func _place_on_anchor() -> bool:
	"""Arrival: the Transform is placed exactly on H's integer point, facing H's authored arrival heading (the
	resident keeps its own heading when the arrival profile admits every heading; nothing is derived from motion)."""
	var pose: Transforms.Pose = Transforms.Pose.new()
	if not _transforms.read_into(_crew.worker, pose): return false
	var yaw: int = _arrival_yaw if _arrival_yaw >= 0 else pose.yaw
	return _transforms.place(_crew.worker, _anchor.x, _anchor.y, _anchor.z, yaw)


static func ceil_length(delta: Vector3i) -> int:
	"""The exact Euclidean length of an integer offset, rounded up; int32 components keep the square in int64."""
	var square: int = int(delta.x) * delta.x + int(delta.y) * delta.y + int(delta.z) * delta.z
	var low: int = 0
	var high: int = 3037000499 # floor(sqrt(2^63 - 1)): every int64 square's root lies at or below it.
	while low < high:
		@warning_ignore("integer_division") var mid: int = (low + high) / 2
		if mid * mid >= square:
			high = mid
		else:
			low = mid + 1
	return low


func capture(out: PackedByteArray) -> StringName:
	"""ADR1218 (G10): the whole entry progress record at a quiescent tick boundary, dispatch in flight or not."""
	out.clear()
	var code: StringName = Progress.busy_refusal(_foreman._owners) if _foreman != null and _foreman._owners != null else &""
	if code != &"": return code
	var w: Progress.Writer = Progress.begin(Progress.KIND_RUNTIME)
	_write_state(w)
	out.append_array(Progress.finish(w))
	return &"" if not out.is_empty() else Progress.REFUSE_SHAPE


func restore(bytes: PackedByteArray, session: RefCounted) -> StringName:
	"""ADR1218: rebuild a fresh runtime exactly from its record against the restored Session's owners. A refused
	record leaves this runtime at STEP_NONE holding the refusal; no owner is touched."""
	if _step != STEP_NONE or _error != &"" or _crew != null or _foreman != null: return Progress.REFUSE_TARGET
	if session == null or session._operations_prefix != 17 or session._operations_state != 2: return REFUSE_SCOPE
	var r: Progress.Reader = Progress.Reader.new()
	var code: StringName = Progress.open(bytes, Progress.KIND_RUNTIME, r)
	if code == &"": code = _read_state(r, session._retirement_owners)
	if code == &"": code = Progress.close(r)
	if code == &"":
		var w: Progress.Writer = Progress.begin(Progress.KIND_RUNTIME)
		_write_state(w)
		code = &"" if Progress.finish(w) == bytes else Progress.REFUSE_NONCANONICAL
	if code == &"" and _foreman != null: code = _bind_dispatcher(session._retirement_owners)
	if code != &"": _refuse_restore(code)
	return code


func _write_state(w: Progress.Writer) -> void:
	"""Step, retained refusal, origin, the published handles, containers, then the crew or the whole foreman."""
	w.i32(_step)
	w.code(_error)
	for axis: int in 3:
		w.i32(_origin[axis])
	w.ref(_published.section)
	w.i32(_published.endpoints.size())
	for at: Vector2i in _published.endpoints:
		w.ref(at)
	w.ref(_storage)
	w.ref(_output)
	w.i32(_walk_left)
	w.i32(_arrival_yaw)
	for axis: int in 3:
		w.i32(_anchor[axis])
	w.flag(_crew != null)
	w.flag(_foreman != null)
	if _foreman != null: _foreman.write_state(w)
	elif _crew != null: Foreman.write_crew(w, _crew)


func _read_state(r: Progress.Reader, o: RefCounted) -> StringName:
	"""Decode in wire order; each step's products exist exactly from that step on."""
	_step = r.ranged(STEP_NONE, STEP_DONE)
	_error = r.code()
	_origin = Vector3i(r.i32(), r.i32(), r.i32())
	_published.section = r.ref()
	var endpoints: int = r.ranged(0, WorkArea.ENDPOINTS)
	for index: int in endpoints:
		_published.endpoints.append(r.ref())
	_storage = r.ref()
	_output = r.ref()
	_walk_left = r.ranged(0, 2147483647)
	_arrival_yaw = r.ranged(-1, 2147483647)
	_anchor = Vector3i(r.i32(), r.i32(), r.i32())
	var has_crew: bool = r.flag()
	var has_foreman: bool = r.flag()
	if r.bad or has_crew != (_step >= STEP_CREW) or has_foreman != (_step >= STEP_RUNNING) \
			or (endpoints == WorkArea.ENDPOINTS) != (_step >= STEP_PUBLISHED) or (endpoints != 0 and endpoints != WorkArea.ENDPOINTS) \
			or (_storage != NULL_REF) != (_step >= STEP_CONTAINERS) or (_output != NULL_REF) != (_step >= STEP_CONTAINERS):
		return Progress.REFUSE_SHAPE
	if has_foreman: return _read_foreman(r, o)
	if _walk_left != 0 or _arrival_yaw != -1 or _anchor != Vector3i.ZERO: return Progress.REFUSE_SHAPE
	if has_crew: _crew = Foreman.read_crew(r)
	if r.bad: return Progress.REFUSE_SHAPE
	return _restored_refusal(o)


func _read_foreman(r: Progress.Reader, o: RefCounted) -> StringName:
	"""The planned foreman under the Session's own owners and paid-order owners, exactly as _plan_foreman wires it."""
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = o.router; paid.connector = o.connector; paid.contacts = o.contacts; paid.budget = o.budget
	_foreman = Foreman.new()
	var code: StringName = _foreman.read_state(r, _foreman_owners(o), paid)
	if code != &"": return code
	if (_step == STEP_DONE) != _foreman.is_done(): return Progress.REFUSE_SHAPE
	_crew = _foreman._crew
	if _crew.storage != _storage or _crew.output != _output: return Progress.REFUSE_SHAPE
	_jobs = o.jobs
	_worker_row = o.residents.directory().get_typed_row(_crew.worker)
	_transforms = o.transforms
	return _walk_refusal(o)


func _walk_refusal(o: RefCounted) -> StringName:
	"""ADR1219: a walk still under way must end on the live H at H's own point, facing the foreman's arrival
	heading; the Transforms handle is the Session's own (re-derived, never written)."""
	if _walk_left == 0: return &""
	if _step != STEP_RUNNING or _arrival_yaw != _foreman.arrival_yaw(): return Progress.REFUSE_SHAPE
	var record: Foreman.Locations.Record = Foreman.Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	if o.locations.read_location_into(_published.endpoints[0], record) != &"" or record.point != _anchor:
		return Progress.REFUSE_LOCATION
	return &""


func _restored_refusal(o: RefCounted) -> StringName:
	"""Before the foreman exists, the runtime still reads M/R's endpoints (to make containers) or its crew."""
	if _step >= STEP_PUBLISHED and _step < STEP_CONTAINERS:
		for index: int in 3:
			if Progress.location_refusal(o.locations, _published.endpoints[index], false) != &"":
				return Progress.REFUSE_LOCATION
	if _step >= STEP_CONTAINERS:
		for container: Vector2i in [_storage, _output]:
			if o.inventory.spatial_location_of(container) == NULL_REF: return Progress.REFUSE_CREW
	if _crew == null: return &""
	var owners: Foreman.Owners = _foreman_owners(o)
	return Foreman._crew_refusal(owners, _crew)


func _refuse_restore(code: StringName) -> void:
	"""Back to a fresh, unstarted runtime that holds only the refusal."""
	_step = STEP_NONE
	_origin = Vector3i.ZERO
	_published = WorkArea.Published.new()
	_storage = NULL_REF
	_output = NULL_REF
	_crew = null
	_foreman = null
	_jobs = null
	_worker_row = -1
	_transforms = null
	_anchor = Vector3i.ZERO
	_walk_left = 0
	_arrival_yaw = -1
	_error = code
