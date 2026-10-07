extends RefCounted
## ADR1197: drive the first entry in the real settlement, step by step, and stop at the first missing capability
## with its exact refusal code and gap row. Completed steps stay published; nothing is faked or rolled back.
## ADR1210 (G7): once the crew is chosen the foreman is planned here and advanced by SettlementSystem.run_tick.

const Site := preload("res://scripts/core/underground_entry_site.gd")
const WorkArea := preload("res://scripts/core/underground_entry_work_area.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const SEARCH_RINGS: int = 8
const REFUSE_SCOPE: StringName = &"ENTRY_RUNTIME_SCOPE"
const REFUSE_NO_TOOLED_MOLE: StringName = &"ENTRY_CREW_NO_TOOLED_MOLE"
const REFUSE_SURFACE_ARRIVAL: StringName = &"ENTRY_SURFACE_ARRIVAL_MISSING"
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
	&"ENTRY_SURFACE_ARRIVAL_MISSING": "G5 the crew mole must stand on the first cut station (surface walking into the work area is not simulated yet)",
	&"JOB_AGENT_BUSY": "G6 the crew mole already holds another Job (reserving the crew from the JobSelector is not built)",
	&"STEP2_ACTIVITY_FORBIDS_WORK": "G6 the crew mole's schedule forbids work this hour (the foreman does not wait for a work hour yet)",
	&"ENTRY_FOREMAN_INPUT_LOT": "G4 inputs must be hauled from R's staging to M; a tooled source-clocked mole cannot select the tool-free haul rows (ADR 1168, ADR 1210)",
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


func advance(tick: int) -> StringName:
	"""ADR1210 G7: one fixed tick of the planned foreman; its first refusal stops the chain for alerting."""
	if not is_running() or not _crew_resolved(): return &""
	var code: StringName = _foreman.advance(tick)
	if code != &"": return _stop(code)
	if _foreman.is_done(): _step = STEP_DONE
	return &""


func _crew_resolved() -> bool:
	"""Eligibility reads the mole's resolved activity; the JobSelector resolves every idle resident within its
	30-tick stagger, so the foreman waits that bounded time rather than refusing an hour nobody has read yet."""
	return _jobs.schedule().current_activity_of(_worker_row).ok


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
	"""The first adult mole holding an equipped tool lot; no tool is created or equipped here."""
	var residents: RefCounted = o.residents
	for row: int in o.gear._row_capacity:
		if o.gear._occupied[row] != 1 or o.gear._equipped[row] != 1: continue
		var owner: Vector2i = Vector2i(o.gear._owner_slot[row], o.gear._owner_generation[row])
		var slot: int = residents.directory().get_typed_row(owner)
		if slot < 0 or not residents.is_present(slot) or residents.species_key(residents.species_of(slot).value) != &"mole":
			continue
		_crew = Foreman.Crew.new()
		_crew.worker = owner
		_crew.tool = Vector2i(o.gear._lot_slot[row], o.gear._lot_generation[row])
		_crew.storage = _storage
		_crew.output = _output
		_step = STEP_CREW
		return &""
	return REFUSE_NO_TOOLED_MOLE


func _plan_foreman(o: RefCounted) -> StringName:
	"""Plan the whole prefix from the mounted Frontier, then require the crew mole on the first station (G5)."""
	var foreman: Foreman = Foreman.new()
	var code: StringName = foreman.configure(_foreman_owners(o), _crew, _entry_placement(o))
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = o.router; paid.connector = o.connector; paid.contacts = o.contacts; paid.budget = o.budget
	for ordinal: int in INSTALLATIONS:
		if code == &"": code = foreman.configure_installation(paid, ordinal)
	if code == &"": code = _arrival_refusal(o, foreman.first_station())
	if code != &"": return code
	_foreman = foreman
	_jobs = o.jobs
	_worker_row = o.residents.directory().get_typed_row(_crew.worker)
	_step = STEP_RUNNING
	return &""


func _foreman_owners(o: RefCounted) -> Foreman.Owners:
	"""The mounted Session's own owners, borrowed unchanged."""
	var f: Foreman.Owners = Foreman.Owners.new()
	f.sites = o.sites; f.jobs = o.jobs; f.work = o.work; f.routes = o.routes; f.binding = o.world_routes
	f.residents = o.residents; f.pool = o.reservations; f.construction = o.construction; f.inventory = o.inventory
	f.profiles = o.profiles; f.frontier = o.room_bindings._entry_frontier; f.placements = o.placements
	f.locations = o.locations; f.anchor = o.surface_anchor; f.items = o.items
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


func _arrival_refusal(o: RefCounted, station: Vector2i) -> StringName:
	"""G5: the simulation never walks a resident from the surface, so the mole must already stand on the station."""
	var record: Foreman.Locations.Record = Foreman.Locations.Record.new()
	var pose: Transforms.Pose = Transforms.Pose.new()
	record.envelope.resize(6)
	record.support.resize(6)
	if station == NULL_REF or o.locations.read_location_into(station, record) != &"": return REFUSE_SCOPE
	if not o.transforms.read_into(_crew.worker, pose): return REFUSE_SURFACE_ARRIVAL
	return &"" if Vector3i(pose.x, pose.y, pose.z) == record.point else REFUSE_SURFACE_ARRIVAL
