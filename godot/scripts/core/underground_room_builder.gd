extends RefCounted
## Decision 1933 (C2.1): one builder of a room dig, a fixed-tick stage machine over the real owners. For each cube
## the foreman hands it: prove (or publish) a contact, open BRACE with a real BUILD Job and assign itself, walk the
## real itinerary, enter WORK, START, earn, hand over to CUT and FINISH at the same station (DEC-059 P2), settle,
## and retreat to its own parking. Every step is an owner call whose own final guard decides; nothing is paid or
## shown done here. It follows whatever rows are bound: the work row decides the tool gate (DEC-052: the game's
## claw rows name no tool, so nothing is claimed).

const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Work := preload("res://scripts/core/work.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Space := preload("res://scripts/core/room_space.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Publication := preload("res://scripts/core/underground_room_frontier_publication.gd")
const Face := preload("res://scripts/core/underground_work_face.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
const Provider := preload("res://scripts/core/underground_room_world_bindings.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Footprint := preload("res://scripts/core/underground_room_footprint.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const STAGE_IDLE: int = 0
const STAGE_TRAVEL: int = 1
const STAGE_ENTER: int = 2
const STAGE_START: int = 3
const STAGE_EARN: int = 4
const STAGE_RECOVER: int = 5
## 6 is unused: Work rests only at 30-WU safe points (ADR1226) and every excavation phase is shorter, so a rest
## hour is waited out between phases (STAGE_BETWEEN), never inside one.
const STAGE_RETREAT: int = 7
const STAGE_FAILED: int = 8
## Between two cubes of one column, READY at the station that finished the lower one.
const STAGE_COLUMN: int = 9
## READY at the station between two phases of one cube, waiting for a working hour.
const STAGE_BETWEEN: int = 10
## The entry foreman's stall bound (ADR1196): no stage may wait longer without moving on.
const STAGE_TICK_LIMIT: int = 1200
const LEG_NONE: int = 0
const LEG_TURNED: int = 1
const LEG_MOVING: int = 2
const REFUSE_SCOPE: StringName = &"ROOM_BUILDER_SCOPE"
const REFUSE_STATE: StringName = &"ROOM_BUILDER_STATE"
const REFUSE_STALL: StringName = &"ROOM_BUILDER_STALLED"
const REFUSE_LEG: StringName = &"ROOM_BUILDER_LEG_PROFILE"
const REFUSE_TOOL: StringName = &"ROOM_BUILDER_TOOL_REQUIRED"
const REFUSE_TARGET: StringName = &"ROOM_BUILDER_TARGET_MOVED"
const REFUSE_LOST: StringName = &"ROOM_BUILDER_CREW_LOST"
const REFUSE_OCCUPIED: StringName = &"ROUTE_OCCUPIED"
const WAIT: StringName = &"ROOM_BUILDER_WAIT" # Internal: still on the way; never returned to the foreman.


class Owners extends RefCounted:
	## The actual composed owners; borrowed, never replaced, for the dig's lifetime.
	var provider: Provider = null # bound once with the gateway (retreat endpoint) and the retreat row
	var sites: Sites = null
	var jobs: Jobs = null
	var work: Work = null
	var routes: Routes = null
	var binding: WorldRoutes = null
	var residents: Residents = null
	var pool: Reservations = null
	var inventory: Inventory = null
	var profiles: Profiles = null
	var construction: Construction = null
	var items: Items = null
	var owner: Owner = null # read for the dig order's open regions
	var budget: Budget = null
	var transforms: Transforms = null # the crew's arrival pose on its parking (ADR1219)


class Crew extends RefCounted:
	## One builder: the resident, its tool (null for the claws), and the endpoint it parks on between cubes.
	var worker: Vector2i = NULL_REF
	var tool: Vector2i = NULL_REF
	var parking: Vector2i = NULL_REF


class Context extends RefCounted:
	## Shared by every builder of one room: the bound rows, content pin and the room's two containers.
	var owners: Owners = null
	var content: int = 0
	var forward: int = -1
	var backward: int = -1
	var storage: Vector2i = NULL_REF
	var output: Vector2i = NULL_REF


var _ctx: Context = null
var _crew: Crew = null
var _stage: int = STAGE_IDLE
var _stage_ticks: int = 0
var _error: StringName = &""
var _index: int = -1
var _site: Vector2i = NULL_REF
var _operation: int = -1
var _job: int = -1
var _station: Vector2i = NULL_REF
var _work_profile: int = -1
var _at: Vector2i = NULL_REF
var _legs: PackedInt32Array = PackedInt32Array()
var _home_legs: PackedInt32Array = PackedInt32Array() # The way back claimed with the cube, walked as claimed.
var _home_profiles: PackedInt32Array = PackedInt32Array()
var _foot: Footprint = null
var _leg_profiles: PackedInt32Array = PackedInt32Array()
var _leg: int = 0
var _leg_state: int = LEG_NONE
var _leg_job: bool = true
var _finished: int = -1
var _cubes: int = 0
var _column_cubes: int = 0
var _accepted_mwu: int = 0
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _actor: Routes.Actor = Routes.Actor.new()
var _tick: Work.TickResult = Work.TickResult.new(false, &"")


func configure(ctx: Context, member: Crew) -> StringName:
	"""Bind one crew member; it starts idle on its own parking endpoint, where it is admitted on its first leg."""
	if ctx == null or ctx.owners == null or member == null or member.worker == NULL_REF or member.parking == NULL_REF:
		return REFUSE_SCOPE
	if _worker_row_of(ctx, member) < 0: return REFUSE_LOST
	_ctx = ctx
	_crew = member
	_foot = Footprint.new()
	_foot.configure(ctx.owners.profiles)
	_at = member.parking
	return &""


static func _worker_row_of(ctx: Context, member: Crew) -> int:
	"""The live resident row of the crew member, or -1."""
	return ctx.owners.residents.directory().get_typed_row(member.worker)


func idle() -> bool:
	"""Parked and free for the next cube."""
	return _stage == STAGE_IDLE


func failed() -> bool:
	"""A refusal stopped this builder for good."""
	return _stage == STAGE_FAILED


func stage() -> int:
	"""The current stage, for status and tests."""
	return _stage


func error() -> StringName:
	"""The refusal that stopped the builder, or empty."""
	return _error


func cubes() -> int:
	"""Cubes this builder has finished (FINISH settled)."""
	return _cubes


func accepted_mwu() -> int:
	"""Work this builder's Jobs were paid, in milli-WU."""
	return _accepted_mwu


func crew() -> Crew:
	"""The bound crew member."""
	return _crew


func target_index() -> int:
	"""The foreman's order index this builder works, or -1 while idle."""
	return _index if _stage != STAGE_IDLE else -1


func walking_next() -> bool:
	"""In a travel stage: on the way to a station or back to parking (or about to set off)."""
	return _stage == STAGE_TRAVEL or _stage == STAGE_RETREAT


func in_motion() -> bool:
	"""Has set off on its planned legs (a leg started, or the last one done and the final turn pending)."""
	return walking_next() and (_leg > 0 or _leg_state != LEG_NONE or _leg >= _leg_profiles.size())


func take_finished() -> int:
	"""The order index whose FINISH settled since the last call, once; -1 otherwise."""
	var index: int = _finished
	_finished = -1
	return index


func register() -> StringName:
	"""ADR1219's arrival, for a builder: its Transform is placed exactly on its parking endpoint, facing the forward
	row's heading, and it is registered with Routes there, before any of the room's work moves. Builders arrive one
	after another, so each one's occupancy proof sees the ones already registered (ROUTE_UNREGISTERED_RESIDENT_NEAR).
	The walk to the parking is not modelled here; C2.3 brings the crew in (as the entry's surface walk does)."""
	if _registered(): return &""
	var o: Owners = _ctx.owners
	var locations: Locations = o.binding._locations_ref.get_ref() as Locations
	if locations == null or not locations._live_ref(locations._live, _crew.parking): return REFUSE_SCOPE
	var point: Vector3i = _point(_crew.parking)
	if not o.transforms.place(_crew.worker, point.x, point.y, point.z, _yaw(_ctx.forward)): return REFUSE_LOST
	var code: StringName = o.routes.admit_travel_actor(_crew.worker, NULL_REF, _crew.parking, _ctx.forward,
		_revision(_ctx.forward), _ctx.content, 0, -1, _crew.tool)
	if code == &"": _foot.stand(point, _ctx.forward)
	return code


func begin(index: int, site: Vector2i, key: int, tick: int) -> StringName:
	"""Prove or publish a contact for the Site, then open its BRACE and plan the approach. A refusal before the BRACE
	is opened leaves the builder idle (the foreman retries later); one after it fails the builder."""
	if _stage != STAGE_IDLE: return REFUSE_STATE
	var code: StringName = _contact(site, key)
	if code != &"": return code
	_index = index
	_site = site
	_operation = Contract.OP_BRACE
	code = _open_phase(tick)
	if code == &"": code = _plan_claim()
	if code == &"": _set_stage(STAGE_TRAVEL)
	return _fail(code) if code != &"" else &""


func _plan_claim() -> StringName:
	"""The cube's whole footprint before setting off: the way back (kept for going home), the station's work and the
	way there. The legs left planned are the approach."""
	_foot.clear_claim()
	var code: StringName = _plan_legs(_station, _crew.parking, _ctx.backward, false)
	if code != &"": return code
	_claim_legs(_station)
	_home_legs = _legs.duplicate()
	_home_profiles = _leg_profiles.duplicate()
	var point: Vector3i = _point(_station)
	_foot.sweep(point, point, _work_profile)
	code = _plan_legs(_at, _station, _ctx.forward, true)
	if code == &"": _claim_legs(_at)
	return code


func _claim_legs(start: Vector2i) -> void:
	"""Each planned leg's row swept from its start point to its end point."""
	var from: Vector3i = _point(start)
	for leg: int in _leg_profiles.size():
		var to: Vector3i = _point(Vector2i(_legs[2 * leg], _legs[2 * leg + 1]))
		_foot.sweep(from, to, _leg_profiles[leg])
		from = to


func _point(location: Vector2i) -> Vector3i:
	"""The integer point of a live Location (read from its bank, as the entry foreman resolves its endpoints)."""
	var locations: Locations = _ctx.owners.binding._locations_ref.get_ref() as Locations
	var cap: int = locations._capacity
	return Vector3i(locations._live.i32[Locations.X * cap + location.x], locations._live.i32[Locations.Y * cap + location.x],
		locations._live.i32[Locations.Z * cap + location.x])


func standing() -> bool:
	"""Not on its way: parked, at a column's end, or about to set off from where it stands."""
	return _stage == STAGE_IDLE or (walking_next() and not in_motion())


func occupied() -> PackedInt32Array:
	"""What this builder may occupy from now on (shared, not copied): its body in its pose while it stands still,
	the claimed cube footprint while it is out at the work (ECON-001; the foreman keeps two builders apart)."""
	return _foot.body() if standing() else _foot.claim()


func claim() -> PackedInt32Array:
	"""The cube's planned footprint (boxes of six ints, shared), for the foreman's check before this builder sets off."""
	return _foot.claim()


func footprint_serial() -> int:
	"""Changes whenever the body or the claimed footprint changes."""
	return _foot.serial()


func _contact(site: Vector2i, key: int) -> StringName:
	"""ADR1213's foreman step, aimed at one Site: the next unpaid Site after key-1 must be this one."""
	var o: Owners = _ctx.owners
	var cold: int = o.budget.acquire(Budget.COLD_BYTES)
	if cold == 0: return Budget.REFUSE_BUSY
	var candidate: Frontier.Candidate = Frontier.Candidate.new()
	var contact: Face.Request = Face.Request.new()
	var request: Publication.Request = Publication.Request.new()
	var result: Publication.Result = Publication.Result.new()
	result.locations.resize(2 * Publication.MAX_STATIONS)
	result.edges.resize(4 * Publication.MAX_STATIONS)
	var code: StringName = Planner.next_contact_into(o.provider, o.sites.room_of(site), key - 1, cold, Space.MAX_CHECKS,
		candidate, contact, request, result)
	if code == &"" and (candidate.key != key or candidate.site != site): code = REFUSE_TARGET
	if code == &"":
		_station = contact.location
		_work_profile = contact.profile_id
	candidate = null; contact = null; request = null; result = null
	o.budget.release(cold)
	return code


func _open_phase(tick: int) -> StringName:
	"""Open the paid phase, create its BUILD Job for the whole quoted work, bind it and assign this builder."""
	var o: Owners = _ctx.owners
	var opened: Construction.OpResult = o.sites.open_phase(_site, _operation)
	if not opened.ok: return opened.error
	if not o.construction.remaining_mwu_into(opened.ref, _math): return REFUSE_STATE
	var made: Jobs.OpResult = o.jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, _math.value, tick)
	if not made.ok: return made.error
	_job = made.value
	var code: StringName = _bind_phase_job(opened.ref)
	if code != &"" and o.sites.job_of(_site) != o.jobs.ref_of(_job):
		o.jobs.destroy_job(_job) # Never bound to the Site: no one may be offered it (the phase is cancelled on abandon).
		_job = -1
	if code == &"": code = _assign()
	return code


func tool_gate() -> int:
	"""DEC-052: the bound work row decides; a row naming no tool needs none, one naming a tool needs it claimed."""
	return tool_gate_of(_ctx.owners.profiles, _work_profile)


static func tool_gate_of(profiles: Profiles, row: int) -> int:
	"""GATE_SATISFIED when the work row names a tool item, GATE_NOT_REQUIRED otherwise."""
	if profiles == null or row < 0 or row >= profiles._live.header[1]: return Jobs.GATE_NOT_REQUIRED
	var tool: int = profiles._live.fields[Profiles.F_TOOL * profiles._profile_capacity + row]
	return Jobs.GATE_SATISFIED if tool >= 0 else Jobs.GATE_NOT_REQUIRED


func _bind_phase_job(project: Vector2i) -> StringName:
	"""The Job names its Project, the row's tool gate, its Site and the room's containers (output for CUT)."""
	var o: Owners = _ctx.owners
	var gate: int = tool_gate()
	if gate == Jobs.GATE_SATISFIED and _crew.tool == NULL_REF: return REFUSE_TOOL
	var result: RefCounted = o.jobs.set_requester(_job, project)
	if result.ok: result = o.jobs.set_tool_gate(_job, gate)
	if result.ok: result = o.sites.bind_job(_site, o.jobs.ref_of(_job))
	if result.ok: result = o.sites.bind_material_container(_site, _ctx.storage)
	if result.ok and _operation == Contract.OP_CUT: result = o.sites.bind_output(_site, _ctx.output)
	return &"" if result.ok else result.error


func _assign() -> StringName:
	"""This builder takes the Job, and claims its tool only when the row requires one."""
	var o: Owners = _ctx.owners
	var row: int = _worker_row_of(_ctx, _crew)
	var result: RefCounted = o.jobs.assign_worker(row, _job)
	if result.ok and tool_gate() == Jobs.GATE_SATISFIED: result = o.work.claim_tool_for_work(row, _crew.tool)
	return &"" if result.ok else result.error


func _plan_legs(from: Vector2i, to: Vector2i, anchor: int, with_job: bool) -> StringName:
	"""Copy the static itinerary's edges and each edge's first certified family row before anyone moves."""
	var o: Owners = _ctx.owners
	_legs.clear(); _leg_profiles.clear()
	_leg = 0
	_leg_state = LEG_NONE
	_leg_job = with_job
	if from == to: return &"" # Already there: no leg.
	var remaining: PackedInt32Array = PackedInt32Array([0])
	var code: StringName = Itinerary.reachability_refusal(o.binding, from, to, anchor, _revision(anchor),
		_ctx.content, Space.MAX_CHECKS, remaining)
	if code != &"": return code
	for index: int in o.routes._proposed_count:
		var row: int = o.routes._proposed_edges[(o.routes._proposed_count - index - 1) * 2]
		var next: Vector2i = o.routes._edge_pair(o.routes._live, Routes.E_TO_SLOT, row)
		var profile: int = _edge_profile(row, anchor)
		if profile < 0: return REFUSE_LEG
		_legs.append(next.x); _legs.append(next.y); _leg_profiles.append(profile)
	return &""


func _edge_profile(edge: int, anchor: int) -> int:
	"""The first certified row the edge admits that shares the anchor's travel family (ADR1213)."""
	var profiles: Profiles = _ctx.owners.profiles
	for profile: int in profiles._live.header[1]:
		if _ctx.owners.binding._live.admits(edge, profile) and Itinerary._compatible(profiles, anchor, profile):
			return profile
	return -1


func _revision(profile: int) -> int:
	"""The published revision of one row."""
	return _ctx.owners.profiles._live.quantities[profile]


func advance(tick: int, may_move: bool = true) -> StringName:
	"""One fixed tick of this builder (the foreman has already advanced Routes this tick). Without `may_move` a builder
	that has not set off yet waits where it stands: the foreman lets one builder walk at a time."""
	if _stage == STAGE_IDLE or _stage == STAGE_FAILED: return _error
	if lost(): return _fail(REFUSE_LOST)
	if not may_move and walking_next() and not in_motion():
		_stage_ticks = 0 # Waiting for the way to clear is not a stall.
		return &""
	var before: int = _stage
	var code: StringName = _run_stage(tick)
	if code != &"": return _fail(code)
	if _stage == before:
		_stage_ticks += 1
		if _stage_ticks > STAGE_TICK_LIMIT: return _fail(REFUSE_STALL)
	return &""


func _run_stage(tick: int) -> StringName:
	"""Dispatch exactly one stage."""
	match _stage:
		STAGE_TRAVEL, STAGE_RETREAT: return _travel(tick)
		STAGE_ENTER: return _enter()
		STAGE_START: return _start(tick)
		STAGE_EARN: return _earn(tick)
		STAGE_RECOVER: return _recover(tick)
		STAGE_BETWEEN: return _between(tick)
	return REFUSE_STATE


func _set_stage(stage_value: int) -> void:
	"""Every stage change restarts the stall count."""
	_stage = stage_value
	_stage_ticks = 0


func _fail(code: StringName) -> StringName:
	"""Stop this builder for good; the foreman stops the room with the same code."""
	_error = code
	_stage = STAGE_FAILED
	return code


func _job_ref() -> Vector2i:
	"""The current phase Job during the approach and the phases; null on the way back (settlement released it)."""
	return _ctx.owners.jobs.ref_of(_job) if _leg_job else NULL_REF


func _travel(tick: int) -> StringName:
	"""Walk the planned legs one at a time; past the last one the builder either faces the work or parks."""
	if _leg >= _leg_profiles.size(): return _end_travel()
	if _leg_state == LEG_MOVING:
		var arrived: StringName = _arrived()
		if arrived != &"": return &"" if arrived == WAIT else arrived
		_at = Vector2i(_legs[2 * _leg], _legs[2 * _leg + 1])
		_leg += 1
		_leg_state = LEG_NONE
		_stage_ticks = 0
		if _leg >= _leg_profiles.size(): return _end_travel()
	return _start_leg(tick)


func _arrived() -> StringName:
	"""Empty once the actor stands READY at the leg's end; WAIT while it is on the way."""
	var o: Owners = _ctx.owners
	var code: StringName = o.routes.read_actor_into(_crew.worker, _actor)
	if code != &"": return code
	if _actor.phase == Routes.PHASE_HELD: return WAIT # Routes retries a held step every tick (another body in the way).
	var target: Vector2i = Vector2i(_legs[2 * _leg], _legs[2 * _leg + 1])
	var profile: int = _leg_profiles[_leg]
	if _actor.location != target or Routes.source_ready_leaf_refusal(o.routes, _crew.worker, _job_ref(), profile,
			_revision(profile), _ctx.content) != &"": return WAIT
	return &""


func _start_leg(tick: int) -> StringName:
	"""Admit an unregistered builder where it stands, or turn to an exact-heading row, then request the route."""
	var o: Owners = _ctx.owners
	var profile: int = _leg_profiles[_leg]
	var target: Vector2i = Vector2i(_legs[2 * _leg], _legs[2 * _leg + 1])
	var code: StringName = &""
	if not _registered():
		code = o.routes.admit_travel_actor(_crew.worker, _job_ref(), _at, profile, _revision(profile), _ctx.content,
			0, -1, _crew.tool)
	elif _leg_state == LEG_NONE and _needs_turn(profile):
		_leg_state = LEG_TURNED
		return WorldRoutes.turn_actor(o.binding, _crew.worker, _job_ref(), _yaw(profile), Space.MAX_CHECKS)
	else:
		code = o.routes.refresh_travel_actor(_crew.worker, _job_ref(), profile, _revision(profile), _ctx.content,
			0, -1, _crew.tool)
	if code == &"": code = o.routes.request_route(_crew.worker, target, tick)
	if code == &"": _leg_state = LEG_MOVING
	return &"" if code == REFUSE_OCCUPIED else code # Another builder is in the way: wait (the stall bound holds).


func _registered() -> bool:
	"""The builder is already a route actor."""
	return _ctx.owners.routes.read_actor_into(_crew.worker, _actor) == &""


func _needs_turn(profile: int) -> bool:
	"""An exact-heading row needs the body already facing its yaw (ADR1213 lateral seam)."""
	var profiles: Profiles = _ctx.owners.profiles
	if profiles._live.fields[Profiles.F_YAW_KIND * profiles._profile_capacity + profile] != Profiles.YAW_EXACT: return false
	return _ctx.owners.routes.read_actor_into(_crew.worker, _actor) == &"" and _actor.yaw != _yaw(profile)


func _yaw(profile: int) -> int:
	"""The exact heading of one row."""
	var profiles: Profiles = _ctx.owners.profiles
	return profiles._live.fields[Profiles.F_YAW * profiles._profile_capacity + profile]


func _end_travel() -> StringName:
	"""Back at parking: idle. At the station: face the work row (its own stationary tick), then select it."""
	if _stage == STAGE_RETREAT:
		_index = -1
		_foot.clear_claim()
		_foot.stand(_point(_crew.parking), _ctx.forward)
		_set_stage(STAGE_IDLE)
		return &""
	if _leg_state != LEG_TURNED and _needs_turn(_work_profile):
		_leg_state = LEG_TURNED
		return WorldRoutes.turn_actor(_ctx.owners.binding, _crew.worker, _job_ref(), _yaw(_work_profile), Space.MAX_CHECKS)
	_set_stage(STAGE_ENTER)
	return _refresh_work()


func _refresh_work() -> StringName:
	"""Select the station's exact WORK source for the current Job."""
	var o: Owners = _ctx.owners
	return o.routes.refresh_work_actor(_crew.worker, o.jobs.ref_of(_job), _work_profile, _revision(_work_profile),
		_ctx.content, 0, -1, _crew.tool)


func _enter() -> StringName:
	"""The canonical source entry must reach WORK through real route ticks before payment."""
	var o: Owners = _ctx.owners
	if Routes.source_work_leaf_refusal(o.routes, _crew.worker, o.jobs.ref_of(_job), _work_profile,
			_revision(_work_profile), _ctx.content) == &"":
		_set_stage(STAGE_START)
	return &""


func _start(tick: int) -> StringName:
	"""Claim the BRACE inputs from the room's storage, record delivery, bind the worker and START."""
	var o: Owners = _ctx.owners
	var code: StringName = _reserve_inputs()
	if code != &"": return code
	var result: Construction.OpResult = o.sites.bind_worker(_site)
	if result.ok: result = o.sites.begin_phase_work(_site, tick)
	if not result.ok: return result.error
	_set_stage(STAGE_EARN)
	return &""


func _reserve_inputs() -> StringName:
	"""Each input line claims its exact quantity from the free stock of its item in the room's storage container."""
	var o: Owners = _ctx.owners
	var count: int = Contract.input_count(_operation)
	for line: int in count:
		var code: StringName = Installer.claim_stock(o, _ctx.storage, o.jobs.ref_of(_job),
			o.items.compiled_id(Contract.input_key(_operation, line)), Contract.input_milli(_operation, line),
			Reservations.PURPOSE_EXCAVATION_INPUT)
		if code != &"": return code
	if count == 0: return &""
	var delivered: Construction.OpResult = o.sites.record_deliveries(_site)
	return &"" if delivered.ok else delivered.error


func _earn(tick: int) -> StringName:
	"""One real Work tick per fixed tick; zero remaining work hands over to the next phase or recovers."""
	var o: Owners = _ctx.owners
	if not o.jobs.remaining_mwu_into(_job, _math): return REFUSE_STATE
	if _math.value > 0:
		o.work.tick_solo_into(_job, _tick)
		if not _tick.ok and _proof_lost(_tick.error):
			o.sites._spatial().refresh_static_proof(_site)
			o.work.tick_solo_into(_job, _tick)
		if not _tick.ok: return _tick.error
		_accepted_mwu += _tick.accepted_mwu
		return &""
	if _hands_over(): return _hand_over(tick)
	var code: StringName = o.routes.request_source_ready(_crew.worker, o.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_RECOVER)
	return code


static func _proof_lost(code: StringName) -> bool:
	"""The Space authority's cached static proof is absent or stale and is re-derived (entry foreman, DEC-059)."""
	return code == &"SPACE_STATIC_PROOF_MISSING" or code == &"SPACE_STATIC_PROOF_STALE"


func _hands_over() -> bool:
	"""DEC-059 (P2): a finished BRACE or CUT keeps the source in WORK at the same station, unless the hour rests."""
	return _operation != Contract.OP_FINISH \
		and not _ctx.owners.jobs.schedule().rests_now(_worker_row_of(_ctx, _crew))


func _hand_over(tick: int) -> StringName:
	"""Settle the finished phase, open the cube's next phase and hand the working source to its new Job."""
	var o: Owners = _ctx.owners
	var old: Vector2i = o.jobs.ref_of(_job)
	var settled: Construction.OpResult = o.sites.settle_phase(_site)
	if not settled.ok: return settled.error
	_operation = Contract.OP_CUT if _operation == Contract.OP_BRACE else Contract.OP_FINISH
	var code: StringName = _open_phase(tick)
	if code == &"": code = o.routes.hand_over_source_job(_crew.worker, old, o.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_START)
	return code


func _between(tick: int) -> StringName:
	"""READY at the station between two phases of one cube with no Job: wait out a rest hour (ADR1226), then open
	the next phase and re-enter WORK."""
	if not may_work():
		_stage_ticks = 0 # A rest is not a stall.
		return &""
	var code: StringName = _open_phase(tick)
	if code == &"": code = _refresh_work()
	if code == &"": _set_stage(STAGE_ENTER)
	return code


func lost() -> bool:
	"""The crew member left (its directory row is gone) or died (ADR1223's crew-loss rule)."""
	var row: int = _worker_row_of(_ctx, _crew)
	if row < 0: return true
	return _ctx.owners.jobs.needs().status_into(row, _math) and _math.value == Needs.STATUS_DEAD


func abandon() -> StringName:
	"""The room stopped: free the resident and the owners' records for this builder's open phase. A started phase
	keeps its paid Project for a later resume (C2.3) and only its worker is released. An unstarted one is cancelled
	(claims released, Project and Job retired: nothing was paid). The route actor stays where it stopped."""
	_stage = STAGE_FAILED
	var o: Owners = _ctx.owners
	if _site == NULL_REF or o.sites.project_of(_site) == NULL_REF: return &""
	var released: Construction.OpResult = o.sites.release_worker(_site)
	if _phase_started(): return &"" if released.ok else released.error
	if not released.ok:
		var code: StringName = _release_assignment()
		if code != &"": return code
	var cancelled: Construction.OpResult = o.sites.cancel_phase(_site, _ctx.storage)
	return &"" if cancelled.ok else cancelled.error


func _release_assignment() -> StringName:
	"""Before the worker is bound to its Site only Jobs holds it: release its tool claim, then the Job (as the entry
	foreman's `_release_phase_job` does before START)."""
	var o: Owners = _ctx.owners
	var row: int = _worker_row_of(_ctx, _crew)
	if row < 0 or _job < 0 or o.jobs.job_of(row) != o.jobs.ref_of(_job): return REFUSE_LOST
	if o.work.tool_lot_of(row) != NULL_REF:
		var tool_released: RefCounted = o.work.release_tool_claim(row)
		if not tool_released.ok: return tool_released.error
	var detached: RefCounted = o.jobs.release_worker(row)
	return &"" if detached.ok else detached.error


func _phase_started() -> bool:
	"""The paid START already ran for this phase's Project (it is WORKING or its work is done)."""
	if not _ctx.owners.construction.phase_into(_ctx.owners.sites.project_of(_site), _math): return false
	return _math.value == Construction.PHASE_WORKING or _math.value == Construction.PHASE_WORK_DONE


func may_work() -> bool:
	"""GDD 5.3 steps 1-2, allocation-free: the hour does not rest (REQ-SET-034) and health permits work."""
	var row: int = _worker_row_of(_ctx, _crew)
	return row >= 0 and not _ctx.owners.jobs.schedule().rests_now(row) and _ctx.owners.jobs.resident_may_work_into(row, _math)


func _recover(tick: int) -> StringName:
	"""Full source recovery precedes the paid settlement that releases the Job; FINISH then walks home."""
	var o: Owners = _ctx.owners
	if Routes.source_ready_leaf_refusal(o.routes, _crew.worker, o.jobs.ref_of(_job), _work_profile,
			_revision(_work_profile), _ctx.content) != &"": return &""
	var settled: Construction.OpResult = o.sites.settle_phase(_site)
	if not settled.ok: return settled.error
	if _operation != Contract.OP_FINISH:
		_operation = Contract.OP_CUT if _operation == Contract.OP_BRACE else Contract.OP_FINISH
		_set_stage(STAGE_BETWEEN)
		return _between(tick)
	_cubes += 1
	_finished = _index
	_at = _station
	_foot.stand(_point(_station), _work_profile)
	_set_stage(STAGE_COLUMN) # The foreman sends it up its column, or home.
	return &""


func at_column_end() -> bool:
	"""Just finished a cube and stands READY at its station, waiting to be sent up the column or home."""
	return _stage == STAGE_COLUMN


func last_index() -> int:
	"""The order index of the cube this builder last took."""
	return _index


func continue_column(index: int, site: Vector2i, key: int, tick: int) -> StringName:
	"""Painted height (decision 1971): the next cube up the same column is taken straight from where the builder
	stands. A refused contact leaves it at the station (the foreman then sends it home); a later refusal fails it."""
	if _stage != STAGE_COLUMN: return REFUSE_STATE
	var code: StringName = _contact(site, key)
	if code != &"": return code
	_index = index
	_site = site
	_operation = Contract.OP_BRACE
	code = _open_phase(tick)
	if code == &"": code = _plan_claim()
	if code == &"":
		_set_stage(STAGE_TRAVEL)
		_column_cubes += 1
	return _fail(code) if code != &"" else &""


func column_cubes() -> int:
	"""Cubes this builder took straight up a column without walking home first."""
	return _column_cubes


func go_home() -> StringName:
	"""From the station back to its parking, along the way back claimed with the cube (never re-planned: chains
	published since could lead outside the claimed footprint)."""
	if _stage != STAGE_COLUMN: return REFUSE_STATE
	_legs = _home_legs.duplicate()
	_leg_profiles = _home_profiles.duplicate()
	_leg = 0
	_leg_state = LEG_NONE
	_leg_job = false
	_set_stage(STAGE_RETREAT)
	return &""
