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
const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
## Decision 2044 (P-2044-9 (a)): the module-aware M5 tread geometry (module 0 is the published one).
const Tread := preload("res://data/underground/mole-worker/qualified-m5-runtime-v1/tread_geometry.gd")
const StairPins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
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
## ADR1229: the runtime's work-area path supplier, asked before each cut phase opens; wiring, never saved state.
var _station_paths: Callable = Callable()


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


func bind_station_paths(supplier: Callable) -> void:
	"""ADR1229: the runtime publishes a station's work-area paths when its first phase is about to open."""
	_station_paths = supplier


func _open(tick: int) -> StringName:
	"""Admit the real phase Project and its BUILD Job, haul any missing inputs, then take the Job."""
	var task: Task = _tasks[_index]
	var paths: StringName = _station_paths.call(task.station) if _station_paths.is_valid() else &""
	if paths == &"": paths = _open_deep_floor(task)
	if paths != &"": return paths
	var opened: RefCounted = _owners.sites.open_phase(task.site, task.operation)
	if not opened.ok: return opened.error
	var code: StringName = _create_phase_job(task, opened.ref)
	if code != &"": return code
	var ref: Vector2i = _owners.jobs.ref_of(_job)
	var queue: PackedInt32Array = PackedInt32Array()
	if code == &"": code = _phase_units(task, queue)
	if code == &"" and not queue.is_empty(): return _haul_or_climb(task, opened.ref, queue, tick)
	if code == &"": code = _assign()
	return _place_actor(task, ref, tick) if code == &"" else code


func _haul_or_climb(task: Task, project: Vector2i, queue: PackedInt32Array, tick: int) -> StringName:
	"""Decision 2045: a phase short of inputs hauls them from the surface. A crew standing below it (a deep stage whose
	first phases needed none, so it is already on a landing's floor) first walks up to the crossing arrival X on its
	own legs, turning onto each row as it goes (the hauler cannot turn), and `_travel` begins the haul there. A pending
	installation retreat is walked first, as `_begin_travel` walks it."""
	var row: int = _owners.residents.directory().get_typed_row(_crew.worker)
	var here: Vector2i = _owners.routes._resident_pair(Routes.R_LOCATION_SLOT, row)
	var held: bool = _owners.jobs.job_of(row) == _owners.jobs.ref_of(_job)
	if here == NULL_REF or _arriving() or _surface(_local_of(here)):
		if held and _owners.jobs.schedule().rests_now(row): return &"" # P-2045-10 (a): at X, wait for a work hour.
		var released: RefCounted = _owners.jobs.release_worker(row) if held else null # The climb's own Job.
		if released != null and not released.ok: return released.error
		return _begin_haul(task, project, queue, tick)
	var code: StringName = &"" if held else _assign() # The climb walks under the phase's own BUILD Job.
	if code != &"": return code
	_set_stage(STAGE_TRAVEL)
	if _retreat != NULL_REF: return _begin_travel(task, _owners.jobs.ref_of(_job), tick)
	var hops: Array = _hops_to_crossing(_stops(), _local_of(here))
	if hops.is_empty(): return REFUSE_PLAN
	var first: PackedInt64Array = _first_leg(hops)
	return _leg(_owners.jobs.ref_of(_job), Vector2i(first[0], first[1]), first[2], first[3], tick)


func _create_phase_job(task: Task, project: Vector2i) -> StringName:
	"""The phase's BUILD Job for its whole remaining work, bound to its Project and Site."""
	if not _owners.construction.remaining_mwu_into(project, _math): return REFUSE_STATE
	var made: RefCounted = _owners.jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, 0)
	if not made.ok: return made.error
	_job = made.value
	return _bind_phase_job(task, project, _owners.jobs.ref_of(_job))


func _phase_units(task: Task, out: PackedInt32Array) -> StringName:
	"""ADR1210: whole units of each brace input beyond M's free stock; none without a bound Delivery."""
	out.clear()
	if _owners.delivery == null: return &""
	var items: PackedInt32Array = PackedInt32Array()
	var milli: PackedInt64Array = PackedInt64Array()
	for line: int in Contract.input_count(task.operation):
		items.append(_owners.items.compiled_id(Contract.input_key(task.operation, line)))
		milli.append(Contract.input_milli(task.operation, line))
	var code: StringName = Hauler.units_into(_owners, _crew.storage, items, milli, out)
	if code != &"" or out.is_empty() or _deep_landing(task.station) == 0: return code
	return _stage_units(items, out) # Decision 2044: below the surface, the whole stage's inputs in one trip to M.


func _stage_units(items: PackedInt32Array, out: PackedInt32Array) -> StringName:
	"""Decision 2044: whole units covering every input of the stage's remaining phases from this one on (a deep stage's
	braces), beyond M's free stock: the crew climbs to M once a stage instead of once a cube."""
	var milli: PackedInt64Array = PackedInt64Array()
	milli.resize(items.size())
	milli.fill(0)
	for at: int in range(_index, _tasks.size()):
		var step: Task = _tasks[at]
		if step.install_ordinal >= 0: continue
		for line: int in Contract.input_count(step.operation):
			var item: int = items.find(_owners.items.compiled_id(Contract.input_key(step.operation, line)))
			if item >= 0: milli[item] += Contract.input_milli(step.operation, line)
	return Hauler.units_into(_owners, _crew.storage, items, milli, out)


func _deep_landing(station: Vector2i) -> int:
	"""Decision 2044: the landing whose deep station this is, or 0."""
	var at: Vector3i = StairPath.classify_deep(_local_of(station))
	return at.x if at.x > 0 else 0


func _open_deep_floor(task: Task) -> StringName:
	"""Decision 2044: before a deep phase opens, its landing's floor walks to its station are published. Decision 2045
	(P-2045-5 (a)): only the station's block of rows is joined; a block's walks leave with its stations, and the next
	block is joined when its first phase opens (nothing is prepared while the block is joined)."""
	var landing: int = _deep_landing(task.station)
	if landing == 0: return &""
	var row: int = StairPath.classify_deep(_local_of(task.station)).y
	return StairPath.publish_floor(_owners.binding, _owners.routes, _paid.budget, _owners.binding._owner(),
		_owners.locations, _stops(), _deep(landing), row, _content)


func _retire_landing_floor() -> StringName:
	"""Decision 2044 (P-2044-16 (a)): a later module's T0 order, on its last leg onto its station (off the floor's
	stops, the bearer not yet set down), retires
	its landing's deep floor: the hub D and the last deep stations (the landing row's), whose air reaches the bearer's
	place. Their cuts are done; nothing comes back for them. `_install` calls it once, on the tick the installer
	reaches that leg; it is idempotent, so a second call retires nothing."""
	var ordinal: int = _tasks[_index].install_ordinal
	if not Tread.is_t0(ordinal) or Tread.module_of(ordinal) == 0: return &""
	var landing: int = Tread.module_of(ordinal)
	var stops: StairPath.Stops = _stops()
	var deep: StairPath.Deep = _deep(landing)
	var left: Array[Vector2i] = [stops.d[landing]]
	for index: int in deep.handles.size(): left.append(deep.handles[index])
	if left.count(NULL_REF) == left.size(): return &""
	return StairPath.retire_stops(_owners.binding, _owners.routes, _owners.locations, _paid.budget, left)


func _retire_deep_rows(task: Task) -> StringName:
	"""Decision 2044: before a deep cube's BRACE starts, the stations of its row and of every row past it have
	struck their last cube and the crew has left them: their edges and Locations leave, so the row's strip can go
	with this BRACE (the entry structure's hook, P-2044-12 (a))."""
	var landing: int = _deep_landing(task.station)
	if landing == 0 or task.operation != Contract.OP_BRACE: return &""
	var deep: StairPath.Deep = _deep(landing)
	var struck: int = StairPath.classify_deep(_local_of(task.station)).y + 1
	for row: int in range(struck, Tread.ROWS - 1):
		if deep.at(row, 0) == NULL_REF and deep.at(row, 1) == NULL_REF: continue
		var code: StringName = StairPath.retire_row(_owners.binding, _owners.routes, _owners.locations, _paid.budget,
			deep, row)
		if code != &"": return code
	return &""


## Decision 2044 (P-2044-7 (a)): the runtime plans stage by stage. A stage is the episodes that need one installed
## prefix, that installation, and every installation after it that needs no new cut (a module's chained treads).


func installations() -> int:
	"""The mounted Frontier's INSTALL rows."""
	return _owners.frontier.row_count(Frontier.INSTALL, _owners.frontier.content_revision())


func planned_installations() -> int:
	"""Installations configured so far, over every stage."""
	return _install_count


func stage_last(first: int) -> int:
	"""The last installation of the stage that opens with installation `first`; -1 when there is none."""
	var count: int = installations()
	if first < 0 or first >= count: return -1
	var last: int = first
	while last + 1 < count and not _prefix_has_episodes(last + 1): last += 1
	return last


func _prefix_has_episodes(prefix: int) -> bool:
	"""Whether some episode waits for exactly this installed prefix."""
	var episode: PackedInt32Array = PackedInt32Array()
	episode.resize(Frontier.row_fields(Frontier.EPISODE))
	for ordinal: int in _owners.frontier.row_count(Frontier.EPISODE, _owners.frontier.content_revision()):
		if _owners.frontier.episode_into(ordinal, episode) == &"" and episode[7] == prefix: return true
	return false


func begin_stage() -> StringName:
	"""Once every planned step has settled, drop them so the next stage's steps can be configured (`configure_installation`
	from `planned_installations()` to `stage_last` of it). The ledgers carry on."""
	if _stage != STAGE_DONE or _index != _tasks.size() or _install_count >= installations(): return REFUSE_PLAN
	_tasks.clear()
	_index = 0
	_stage = STAGE_OPEN
	_stage_ticks = 0
	_error = &""
	return &""


func _begin_haul(task: Task, project: Vector2i, queue: PackedInt32Array, tick: int) -> StringName:
	"""Any pending retreat leg first, then the station's travel profile to M; the BUILD Job brings the worker home.
	ADR1219: an unregistered worker is admitted at its arrival on the arrival's own profile (the first leg)."""
	var legs: Array[Hauler.Leg] = []
	var start: Vector2i = task.station
	var from: Vector2i = _owners.routes._resident_pair(Routes.R_LOCATION_SLOT,
		_owners.residents.directory().get_typed_row(_crew.worker))
	if _arriving():
		start = _crew.arrival
		from = _crew.arrival
		legs.append(_haul_leg(_crew.arrival, _arrival_profile, _arrival_revision))
		_take_arrival_retreat()
	if _retreat != NULL_REF:
		legs.append(_haul_leg(_retreat, _retreat_profile, _retreat_revision))
		from = _retreat
	_retreat = NULL_REF
	var material: Vector2i = _owners.inventory.spatial_location_of(_crew.storage)
	var route: PackedInt64Array = _all_legs(_route_hops(from, material, task.travel_profile)) # Decision 2044.
	for at: int in range(0, route.size(), 4):
		legs.append(_haul_leg(Vector2i(route[at], route[at + 1]), route[at + 2], route[at + 3]))
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
	return _begin_travel(task, _owners.jobs.ref_of(_job), tick) # Decision 2044: back down the stair when needed.


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
	"""A pending installation retreat leg goes first on its own profile; then the station's travel profile.
	Decision 2044: on M5 the way to a station below the surface (or back up from one) is a run of legs along the stair,
	derived afresh at each leg's end from where the crew stands, so nothing about it is saved."""
	if _retreat != NULL_REF:
		var target: Vector2i = _retreat
		_retreat = NULL_REF
		return _leg(job, target, _retreat_profile, _retreat_revision, tick)
	var here: Vector2i = _owners.routes._resident_pair(Routes.R_LOCATION_SLOT,
		_owners.residents.directory().get_typed_row(_crew.worker))
	var hops: Array = _route_hops(here, task.station, task.travel_profile)
	if hops.is_empty(): return REFUSE_PLAN
	var first: PackedInt64Array = _first_leg(hops)
	if first[0] == task.station.x and first[1] == task.station.y:
		return _leg(job, task.station, task.travel_profile, task.travel_revision, tick)
	return _leg(job, Vector2i(first[0], first[1]), first[2], first[3], tick)


func _leg(job: Vector2i, target: Vector2i, profile: int, revision: int, tick: int) -> StringName:
	"""Hand the recovered source to one explicit travel profile and request the real itinerary. Decision 2044: a
	yaw-exact row is first turned to (as the installer's legs are), when the crew does not already face it."""
	_leg_target = target
	_leg_profile = profile
	_leg_revision = revision
	var code: StringName = _face_profile(job, profile)
	if code == &"": code = _owners.routes.refresh_travel_actor(_crew.worker, job, profile, revision, _content,
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
	var queue: PackedInt32Array = PackedInt32Array()
	code = &"" if _phase_started(task) else _phase_units(task, queue) # Decision 2045: still short, so climb or haul.
	if code != &"" or not queue.is_empty():
		_stage_ticks = 0
		return code if code != &"" else _haul_or_climb(task, _owners.sites.project_of(task.site), queue, tick)
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
	var code: StringName = _retire_deep_rows(task)
	if code == &"": code = _reserve_inputs(task)
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
		if not worked.ok and _proof_lost(worked.error): worked = _reproved_tick()
		if not worked.ok: return _rest_or(worked.error)
		_accepted_mwu += worked.accepted_mwu
		return &""
	if _hands_over(): return _hand_over()
	var code: StringName = _owners.routes.request_source_ready(_crew.worker, _owners.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_RECOVER)
	return code


static func _proof_lost(code: StringName) -> bool:
	"""The Space authority's cached static proof of a funded phase is absent or stale: not saved, so a settlement load
	(or a revision change) leaves it to be re-derived."""
	return code == &"SPACE_STATIC_PROOF_MISSING" or code == &"SPACE_STATIC_PROOF_STALE"


func _reproved_tick() -> RefCounted:
	"""DEC-059 (found with the whole-entry save goal): the authority's own cold revalidation (refresh_static_proof,
	"recovers funded work after revision/load changes") re-derives the phase's proof, and the same tick's Work runs
	again, so a loaded chain spends exactly the ticks the uninterrupted one does. A refused refresh leaves the proof
	missing, and the retried tick refuses with it."""
	_owners.sites._spatial().refresh_static_proof(_tasks[_index].site)
	return _owners.work.tick_solo(_job)


func _hands_over() -> bool:
	"""DEC-059 (P2): a finished BRACE or CUT whose next step is the same cube's next phase at the same station, on
	the same claw row, keeps the source in WORK (one entry and one recovery per cube). Not while the crew's hour
	forbids work: then it recovers to READY at the station, the resting point (ADR1226)."""
	if _index + 1 >= _tasks.size(): return false
	var task: Task = _tasks[_index]
	var next: Task = _tasks[_index + 1]
	return next.install_ordinal < 0 and task.install_ordinal < 0 and next.site == task.site \
		and next.station == task.station and next.work_profile == task.work_profile \
		and next.work_revision == task.work_revision and next.operation != Contract.OP_BRACE \
		and not _owners.jobs.schedule().rests_now(_owners.residents.directory().get_typed_row(_crew.worker))


func _hand_over() -> StringName:
	"""DEC-059 (P2): settle the finished phase, open the next one and hand the working source to its Job in the same
	tick; its START then runs as after an entry. Nothing moves: the loop goes on, on the same row and station."""
	var task: Task = _tasks[_index]
	var old: Vector2i = _owners.jobs.ref_of(_job)
	var settled: RefCounted = _owners.sites.settle_phase(task.site)
	if not settled.ok: return settled.error
	_index += 1
	task = _tasks[_index]
	var opened: RefCounted = _owners.sites.open_phase(task.site, task.operation)
	if not opened.ok: return opened.error
	var code: StringName = _create_phase_job(task, opened.ref)
	if code == &"": code = _assign()
	if code == &"": code = _owners.routes.hand_over_source_job(_crew.worker, old, _owners.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_START)
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


func release_lost_crew(resting: bool = false) -> StringName:
	"""ADR1225: detach the dispatch from a crew that died or left: cancel its admitted haul, release its Job
	(Sites' own departure path once the phase is bound), unregister its actor, then wait in RESUME for
	a replacement. Paid progress, consumed inputs and the parked Jobs stay; carried goods stay with the lost crew.
	DEC-057: a paid installation is released by its installer and re-handled in place by the replacement.
	DEC-059: `resting` releases a living crew that changes shift at a resting point; Routes unregisters it there."""
	if _terminal(): return _error
	var lost: Vector2i = _crew.worker
	var row: int = _owners.residents.directory().get_typed_row(lost)
	var code: StringName = _release_haul(lost, row)
	if code == &"" and _installer != null: code = _installer.release_lost_crew(lost, row)
	elif code == &"" and _job >= 0 and _owners.jobs.worker_of(_job) == lost: code = _release_phase_job(row)
	if code == &"" and _owners.routes._lost_actor_row(lost) >= 0:
		code = _owners.routes.unregister_resting_actor(lost) if resting else _owners.routes.unregister_lost_actor(lost)
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
		return _haul_or_climb(task, _owners.sites.project_of(task.site), queue, tick)
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
	if paid == null or ordinal != _install_count or _stage != STAGE_OPEN or _index != 0 \
			or (_tasks.is_empty() and _install_count == 0):
		return REFUSE_PLAN
	var install: PackedInt32Array = PackedInt32Array()
	install.resize(Frontier.row_fields(Frontier.INSTALL))
	if _owners.frontier.installation_into(ordinal, install) != &"": return REFUSE_PLAN
	var before: int = _tasks.size()
	var code: StringName = _append_episodes(ordinal) if ordinal > 0 else &""
	# ADR1229: a tread after the first follows the previous tread directly; no cut is planned between them. Decision
	# 2044: a later module's T1 follows its T0 likewise; a stage never opens on an installation.
	if code != &"" or _tasks.is_empty() or (_tasks[_tasks.size() - 1].install_ordinal >= 0 and not Tread.is_tread(install[0])):
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
	var code: StringName = _station_paths.call(plan.station) if _station_paths.is_valid() else &""
	if code == &"": code = _connect_contact(install, plan)
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
	"""The worker leaves the preceding cut on its profile; only L0's START retires episodes 0 and 1 (ADR1191).
	ADR1229: a tread following a tread walks to M on the last cut's profile too (an installation step has none)."""
	var at: int = _index - 1
	while at > 0 and _tasks[at].install_ordinal >= 0: at -= 1
	var last: Task = _tasks[at]
	plan.walk_profile = last.travel_profile
	plan.walk_revision = last.travel_revision
	var profiles: RefCounted = _owners.profiles
	var handling: int = Routes.Handling.profile_of(_paid.connector._workpieces, plan.ordinal)
	if handling < 0: return null
	plan.handling_revision = profiles._live.quantities[Profiles.L_REVISION * profiles._profile_capacity + handling]
	if plan.ordinal == 0:
		plan.retired_first = _tasks[0].station
		plan.retired_second = _tasks[OPERATIONS.size()].station
	if plan.station == NULL_REF or plan.material == NULL_REF: return null
	return plan if _plan_stairs(plan) else null


func _stops() -> StairPath.Stops:
	"""ADR1229: every live installed stair stop of the mounted bundle, by kind and level. Decision 2044: one pass over
	the live Locations of the entry's Room, each filed by its own source-local point (M5 has 301 selectors)."""
	var stops: StairPath.Stops = StairPath.Stops.new()
	var locations: Locations = _owners.locations
	var room: Vector2i = _entry_room()
	for row: int in locations._capacity:
		if locations._live.present[row] != 1 or locations._ref_at(locations._live, Locations.ROOM_SLOT, row) != room: continue
		var kind: Vector2i = StairPath.classify(_local_of_row(row))
		if kind.x >= 0: StairPath.record(stops, kind, Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row)))
	return stops


func _entry_room() -> Vector2i:
	"""The entry Placement's Room."""
	var p: RefCounted = _owners.placements
	return Vector2i(p._live.i32[p.ROOM_SLOT * p._capacity + _placement.x], p._live.i32[(p.ROOM_SLOT + 1) * p._capacity + _placement.x])


func _local_of_row(row: int) -> Vector3i:
	"""A live Location row's point in the Placement's source frame (rotation 0: a translation)."""
	var locations: Locations = _owners.locations
	return Vector3i(locations._get32(locations._live, Locations.X, row), locations._get32(locations._live, Locations.Y, row),
		locations._get32(locations._live, Locations.Z, row)) - _world_point(_placement.x, 0, 0, 0)


func _local_of(location: Vector2i) -> Vector3i:
	"""A live Location's source-local point; (0, 1, 0), which no stop or station has, for none."""
	if location == NULL_REF or not _owners.locations._live_ref(_owners.locations._live, location): return Vector3i(0, 1, 0)
	return _local_of_row(location.x)


func _deep(landing: int) -> StairPath.Deep:
	"""Decision 2044: landing j's live deep stations, by row and column."""
	var deep: StairPath.Deep = StairPath.Deep.new()
	deep.landing = landing
	deep.first_row = Tread.deep_first_row(landing) - 1
	for index: int in 2 * (Tread.ROWS - 1 - deep.first_row): deep.handles.append(NULL_REF)
	var locations: Locations = _owners.locations
	var room: Vector2i = _entry_room()
	for row: int in locations._capacity:
		if locations._live.present[row] != 1 or locations._ref_at(locations._live, Locations.ROOM_SLOT, row) != room: continue
		var at: Vector3i = StairPath.classify_deep(_local_of_row(row))
		if at.x == landing:
			deep.handles[(at.y - deep.first_row) * 2 + at.z] = Vector2i(row, locations._get32(locations._live, Locations.GENERATION, row))
	return deep


## Decision 2044: M5's ways between two places. The surface (M, R, the work area and the crossing arrival X) is joined
## to the stair at X; a landing's floor stops and deep stations are joined among themselves on the claw WALK. Every
## other way climbs to X and descends again, one published edge a hop.


func _surface(local: Vector3i) -> bool:
	"""A place on the surface: anything at the stair top's height that is not a stair stop (X included)."""
	var kind: int = StairPath.classify(local).x
	return local.y == 0 and (kind < 0 or kind == StairPath.KIND_X)


func _floor_of(local: Vector3i) -> int:
	"""The landing whose floor a place stands on (a floor stop, a later module's H' or a deep station), else 0."""
	var deep: Vector3i = StairPath.classify_deep(local)
	if deep.x > 0: return deep.x
	var kind: Vector2i = StairPath.classify(local)
	if kind.x == StairPath.KIND_F or kind.x == StairPath.KIND_UF or kind.x == StairPath.KIND_FP \
			or kind.x == StairPath.KIND_D: return kind.y
	if kind.x < 0 or kind.y < 0 or (kind.x != StairPath.KIND_H and kind.x != StairPath.KIND_P): return 0
	return StairPath.module_of_level(kind.y) if kind.y == StairPath.global_level(StairPath.module_of_level(kind.y), -1) \
		else 0


func _route_hops(from: Vector2i, target: Vector2i, final_profile: int) -> Array:
	"""Hops [stop, row] from `from` to `target`, the last on `final_profile` when the target is on the surface."""
	var a: Vector3i = _local_of(from)
	var b: Vector3i = _local_of(target)
	if (from == NULL_REF or _surface(a)) and _surface(b): return [[target, final_profile]]
	var stops: StairPath.Stops = _stops()
	if _floor_of(a) > 0 and _floor_of(a) == _floor_of(b):
		var across: Array = _floor_hops(stops, _floor_of(a), a, b, target)
		if not across.is_empty(): return across
	var out: Array = _hops_to_crossing(stops, a)
	out.append_array(_hops_from_crossing(stops, b, target, final_profile))
	for at: int in range(out.size() - 1, -1, -1): # A crew already standing on the way joins it there.
		if out[at][0] == from: return out.slice(at + 1)
	return out


func _hops_to_crossing(stops: StairPath.Stops, local: Vector3i) -> Array:
	"""Hops from a place up to the crossing arrival X (none from X itself)."""
	if _surface(local): return [] if StairPath.classify(local).x == StairPath.KIND_X else [[stops.x, StairPins.CLAW_WALK_ROW]]
	var deep: Vector3i = StairPath.classify_deep(local)
	if deep.x > 0: return _to_hub(stops, deep.x, local) + [[stops.fp[deep.x], StairPins.CLAW_RETREAT_ROWS[0]]] \
		+ StairPath.hops_up_from_walk_off(stops, deep.x)
	var kind: Vector2i = StairPath.classify(local)
	var level: int = kind.y
	match kind.x:
		StairPath.KIND_F: return [[stops.uf[level], StairPins.CLAW_TURN_ROW]] + StairPath.hops_up_from_floor(stops, level)
		StairPath.KIND_UF: return StairPath.hops_up_from_floor(stops, level)
		StairPath.KIND_FP: return StairPath.hops_up_from_walk_off(stops, level)
		StairPath.KIND_H:
			var module: int = StairPath.module_of_level(level)
			if module == 0: return [[stops.x, StairPins.CLAW_RETREAT_ROWS[0]]] # The prefix's H backs off to X.
			return [[stops.fp[module], StairPins.CLAW_RETREAT_ROWS[0]]] + StairPath.hops_up_from_walk_off(stops, module)
		StairPath.KIND_P:
			var landing: int = StairPath.module_of_level(level)
			if landing == 0: return []
			return [[stops.fp[landing], StairPins.CLAW_RETREAT_ROWS[0]]] + StairPath.hops_up_from_walk_off(stops, landing)
		StairPath.KIND_D:
			return [[stops.fp[level], StairPins.CLAW_RETREAT_ROWS[0]]] + StairPath.hops_up_from_walk_off(stops, level)
		StairPath.KIND_S: return [[stops.a[level + 1], StairPins.CLAW_STEP_FORWARD_ROW],
			[stops.u[level + 1], StairPins.CLAW_TURN_ROW]] + StairPath.hops_up(stops, level)
		StairPath.KIND_A: return [[stops.u[level + 1], StairPins.CLAW_TURN_ROW]] + StairPath.hops_up(stops, level)
		StairPath.KIND_U: return StairPath.hops_up(stops, level)
	return []


func _hops_from_crossing(stops: StairPath.Stops, local: Vector3i, target: Vector2i, final_profile: int) -> Array:
	"""Hops from the crossing arrival X down to a place."""
	if _surface(local): return [[target, final_profile]]
	var deep: Vector3i = StairPath.classify_deep(local)
	if deep.x > 0: return StairPath.hops_down_to_walk_off(stops, deep.x) + [[_hub(stops, deep.x),
		StairPins.CLAW_APPROACH_ROWS[0]], [target, StairPath.FLOOR_ROW]]
	var kind: Vector2i = StairPath.classify(local)
	if kind.x == StairPath.KIND_H and kind.y >= 0:
		return StairPath.hops_down_to_walk_off(stops, StairPath.module_of_level(kind.y)) \
			+ [[target, StairPins.CLAW_APPROACH_ROWS[0]]]
	if kind.x == StairPath.KIND_S: return StairPath.hops_down(stops, kind.y) + [[target, StairPins.CLAW_STEP_BACK_ROW]]
	return []


func _hub(stops: StairPath.Stops, landing: int) -> Vector2i:
	"""P-2044-16 (a): landing j's deep hub D, the hub of its floor walks."""
	return stops.d[landing]


func _to_hub(stops: StairPath.Stops, landing: int, local: Vector3i) -> Array:
	"""Hops on landing j's floor from a place to its hub D, or [null] when none is published from there."""
	if StairPath.classify_deep(local).x > 0: return [[_hub(stops, landing), StairPath.FLOOR_ROW]]
	var approach: Array = [_hub(stops, landing), StairPins.CLAW_APPROACH_ROWS[0]]
	var back: Array = [stops.fp[landing], StairPins.CLAW_RETREAT_ROWS[0]]
	match StairPath.classify(local).x:
		StairPath.KIND_D: return []
		StairPath.KIND_FP: return [approach]
		StairPath.KIND_F: return [[stops.fp[landing], StairPins.STAIR_EMPTY_FLOOR_ROWS[0]], approach]
		StairPath.KIND_H, StairPath.KIND_U, StairPath.KIND_P: return [back, approach]
	return [null]


func _from_hub(stops: StairPath.Stops, landing: int, local: Vector3i, target: Vector2i) -> Array:
	"""Hops on landing j's floor from its hub D to a place, or [null] when none is published to there."""
	if StairPath.classify_deep(local).x > 0: return [[target, StairPath.FLOOR_ROW]]
	var back: Array = [stops.fp[landing], StairPins.CLAW_RETREAT_ROWS[0]]
	match StairPath.classify(local).x:
		StairPath.KIND_D: return []
		StairPath.KIND_FP: return [back]
		StairPath.KIND_F: return [back, [stops.f[landing], StairPins.STAIR_EMPTY_FLOOR_ROWS[1]]]
		StairPath.KIND_H, StairPath.KIND_P: return [back, [target, StairPins.CLAW_APPROACH_ROWS[0]]]
	return [null]


func _floor_hops(stops: StairPath.Stops, landing: int, a: Vector3i, b: Vector3i, target: Vector2i) -> Array:
	"""P-2044-16 (a): a way between two places on landing j's floor through its hub D, or [] when either end has no
	floor edge (the way up and down then serves)."""
	var out: Array = _to_hub(stops, landing, a)
	var rest: Array = _from_hub(stops, landing, b, target)
	if null in out or null in rest: return []
	out.append_array(rest)
	return out


func _first_leg(hops: Array) -> PackedInt64Array:
	"""The first run of hops on one row as one leg [slot, generation, profile, revision]."""
	return _all_legs(hops).slice(0, 4)


func _all_legs(hops: Array) -> PackedInt64Array:
	"""Hops as legs: each run of consecutive hops on one row is one route to the run's last stop."""
	var pairs: Array = []
	for at: int in hops.size():
		if at + 1 < hops.size() and hops[at + 1][1] == hops[at][1]: continue
		pairs.append_array([hops[at][0], hops[at][1]])
	return _legs(pairs)


func _face_profile(job: Vector2i, profile: int) -> StringName:
	"""Turn to a yaw-exact row's heading when the crew does not already face it (decision 2044's leg changes)."""
	var profiles: RefCounted = _owners.profiles
	if profile < 0 or profiles._live.fields[Profiles.F_YAW_KIND * profiles._profile_capacity + profile] != Profiles.YAW_EXACT:
		return &""
	var yaw: int = profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + profile]
	if _owners.routes.read_actor_into(_crew.worker, _actor) != &"" or _actor.yaw == yaw: return &""
	return WorldRoutes.turn_actor(_owners.binding, _crew.worker, job, yaw, Space.MAX_CHECKS)


func _plan_stairs(plan: Installer.Plan) -> bool:
	"""ADR1229: a tread order walks down from the crossing arrival (walk-in step, step forward, descent to the stop
	above the station) and retracts that stop at FUND. DEC-059 (P1): from the previous tread's station it walks
	straight down instead (step forward, one descent); from anywhere else below it first climbs back to the crossing
	arrival. Decision 2044: on M5 the same holds in every module, the way down crossing every landing above it, and a
	later module's T0 is reached the same way: down to its landing's F' (P-2044-16 (a)), then the narrow approach onto
	H'."""
	var t0: bool = Tread.is_t0(plan.ordinal) and Tread.module_of(plan.ordinal) > 0
	if not Tread.is_tread(plan.ordinal) and not t0: return true
	var stops: StairPath.Stops = _stops()
	var module: int = Tread.module_of(plan.ordinal)
	var level: int = StairPath.global_level(module, Tread.level_of(plan.ordinal) - 1)
	if t0:
		plan.arrival = stops.x
		plan.downs = _all_legs(StairPath.hops_down_to_walk_off(stops, module))
	else:
		if plan.arrival != stops.x or stops.s[level + 1] != plan.station: return false
		plan.downs = _all_legs(StairPath.hops_down(stops, level))
		plan.retract = stops.a[level + 1]
	var here: Vector2i = _owners.routes._resident_pair(Routes.R_LOCATION_SLOT,
		_owners.residents.directory().get_typed_row(_crew.worker))
	var from: int = stops.s.find(here) - 1
	if here != NULL_REF and not t0 and from >= 0 and from == level - 1:
		plan.chain = _legs([stops.a[level], StairPins.CLAW_STEP_FORWARD_ROW, stops.a[level + 1],
			StairPins.CLAW_DESCENT_ROW]) # DEC-059 (P1): straight down from the previous tread's station.
	elif here != NULL_REF and not _surface(_local_of(here)):
		plan.ups = _all_legs(_hops_to_crossing(stops, _local_of(here)))
	return not plan.downs.is_empty() and (t0 or plan.retract != NULL_REF)


func _legs(pairs: Array) -> PackedInt64Array:
	"""[target, profile] pairs as [slot, generation, profile, revision] rows; empty when a target is not live."""
	var rows: PackedInt64Array = PackedInt64Array()
	var profiles: RefCounted = _owners.profiles
	for at: int in range(0, pairs.size(), 2):
		var target: Vector2i = pairs[at]
		if target == NULL_REF: return PackedInt64Array()
		var profile: int = pairs[at + 1]
		rows.append_array(PackedInt64Array([target.x, target.y, profile,
			profiles._live.quantities[Profiles.L_REVISION * profiles._profile_capacity + profile]]))
	return rows


func _connect_contact(install: PackedInt32Array, plan: Installer.Plan) -> StringName:
	"""A station on an installed contact has no route edge yet: publish M <-> (arrival <->) contact via WorldRoutes.
	ADR1229: a tread station is reached down the stair: every stair edge between live stops is published instead."""
	if Tread.is_tread(plan.ordinal) or (Tread.is_t0(plan.ordinal) and Tread.module_of(plan.ordinal) > 0):
		return StairPath.publish(_owners.binding, _owners.routes, _paid.budget, _owners.binding._owner(),
			_owners.locations, _stops(), _content)
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
	# Decision 2044: from a station on the stair the way out is a run of legs, derived where the next step starts.
	if Tread.is_tread(plan.ordinal) or (Tread.is_t0(plan.ordinal) and Tread.module_of(plan.ordinal) > 0): return &""
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
	# Decision 2044: once, on the tick the installer reaches its last leg (its progress marker changes into it).
	if _installer.stage() == Installer.STAGE_LEG_STATION and _installer.progress_marker() != _last_install_stage:
		code = _retire_landing_floor()
		if code != &"": return code
	if _installer.stage() == Installer.STAGE_DONE:
		_install_mwu += _installer.accepted_mwu()
		_haul_mwu += _installer.haul_mwu()
		_haul_trips += _installer.haul_trips()
		_installer = null
		_retreat = _pending_retreat
		_pending_retreat = NULL_REF
		_index += 1
		code = _publish_sill_edges()
		return code if code != &"" else _next_step()
	_stage_ticks = 0 if _installer.progress_marker() != _last_install_stage else _stage_ticks
	_last_install_stage = _installer.progress_marker()
	return &""


func _publish_sill_edges() -> StringName:
	"""Decision 1972: once the sill's stops stand (after its commit), the sill's edges and the stair carry (H to T6 and
	back) are published between the live stops; before that, nothing (the stair path gates them on the sill's A)."""
	var stops: StairPath.Stops = _stops()
	if stops.at(StairPath.KIND_A, StairPath.SILL_LEVEL) == NULL_REF: return &""
	return StairPath.publish(_owners.binding, _owners.routes, _paid.budget, _owners.binding._owner(),
		_owners.locations, stops, _content)


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
