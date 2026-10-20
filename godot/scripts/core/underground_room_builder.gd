extends RefCounted
## Decision 1933 (C2.1): one builder of a room dig, a fixed-tick stage machine over the real owners. For each cube
## the foreman hands it: prove (or publish) a contact, open BRACE with a real BUILD Job and assign itself, walk the
## real itinerary, enter WORK, START, earn, hand over to CUT and FINISH at the same station (DEC-059 P2), settle,
## and retreat to its own parking. Every step is an owner call whose own final guard decides; nothing is paid or
## shown done here. It follows whatever rows are bound: the work row decides the tool gate (DEC-052: the game's
## claw rows name no tool, so nothing is claimed).
## Decision 1934 (C2.2): with a Delivery bound, a BRACE whose inputs the room's storage lacks is preceded by a haul:
## the builder walks to the storage and the entry's hauler (unchanged) carries whole units from the level's staging
## container through Delivery's room branch; the BRACE Job then brings it back onto the storage and on to the station.

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
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Walk := preload("res://scripts/core/underground_room_walk.gd")
const Claim := preload("res://scripts/core/underground_room_claim.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const EntryProgress := preload("res://scripts/core/underground_entry_progress.gd")
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
## Decision 1934: walking to the room's storage, with no Job, to haul what the BRACE lacks.
const STAGE_TO_STORE: int = 11
## Decision 1934: the hauler's trips from the staging container's stand to the storage's, and back onto the storage.
const STAGE_HAUL: int = 12
## The entry foreman's stall bound (ADR1196): no stage may wait longer without moving on.
const STAGE_TICK_LIMIT: int = 1200
const LEG_NONE: int = 0
const LEG_TURNED: int = 1
const LEG_MOVING: int = 2
const REFUSE_SCOPE: StringName = &"ROOM_BUILDER_SCOPE"
const REFUSE_STATE: StringName = &"ROOM_BUILDER_STATE"
const REFUSE_STALL: StringName = &"ROOM_BUILDER_STALLED"
const REFUSE_LEG: StringName = &"ROOM_BUILDER_LEG_PROFILE"
## Decision 1943: the content has no READY sibling of the bound travel rows at the cube's work-row heading.
const REFUSE_HEADING_ROWS: StringName = &"ROOM_BUILDER_HEADING_ROWS"
## Decision 1943, P-1943-1 ("Claws for turns, warn"): a claw digger that picked up a tool after the order. The dig
## stops in words (`UndergroundRoomConfirm.refusal_words`), never as a bare planner refusal.
const REFUSE_PICK_CANNOT_TURN: StringName = &"ROOM_DIG_PICK_CANNOT_TURN"
const REFUSE_TARGET: StringName = &"ROOM_BUILDER_TARGET_MOVED"
const REFUSE_LOST: StringName = &"ROOM_BUILDER_CREW_LOST"
## Decision 1934 (P-C22-1): no certified stair row carries cargo yet, so stock is hauled only within one level.
const REFUSE_STAIR: StringName = &"ROOM_HAUL_NO_STAIR_CARRY"
## Decision 1936, P-1936-5 (a): the cube's plan needs more than the footprint's MAX_BOXES boxes.
const REFUSE_FOOTPRINT: StringName = &"ROOM_BUILDER_FOOTPRINT_CAPACITY"
## Decision 1937 (review M1): a stopped builder still not at rest after STAGE_TICK_LIMIT ticks is named once.
const REFUSE_STUCK: StringName = &"ROOM_BUILDER_STUCK_UNDERGROUND"
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
	var delivery: RefCounted = null # Decision 1934: when bound, a BRACE's missing inputs are hauled first.
	var locations: Locations = null # The hauler finds the grip stands here (needed only with a Delivery).
	var extents: Footprint.RowExtents = null # Decision 1937 (P-1937-1 B): the row extents all builders share.


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
	var staging: Vector2i = NULL_REF # Decision 1934: the same-level container missing BRACE inputs come from.


class HaulCrew extends RefCounted:
	## The hauler's view of a builder (it reads these by name): M is the room's storage, R the staging container.
	var worker: Vector2i = NULL_REF
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
var _plan: Claim = Claim.new() # Decision 1936: the cube's planned legs and trips, its footprint swept from them.
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
var _queue: PackedInt32Array = PackedInt32Array() # Whole units the cube's BRACE still lacks, in bill order.
var _hauler: Hauler = null
var _departed: bool = false # Set off for the cube (or home): the claimed footprint, not the body, is occupied.
var _haul_store: Vector2i = NULL_REF # The storage and staging endpoints the haul was planned between.
var _haul_source: Vector2i = NULL_REF
var _haul_marker: int = -1
var _haul_trips: int = 0
var _haul_mwu: int = 0
var _walk: Walk = Walk.new() # Decision 1936: the walk in to the parking, or out to where it came from.
var _failed_from: int = STAGE_IDLE # The stage a refusal stopped the builder in (abandon recovers a work source).
var _resuming: bool = false
var _release_pending: bool = false # Stopped in a work source: its phase is released once it has recovered. # P-1933-2 (a): the current phase was paid before a stop and is taken over, not opened.


func configure(ctx: Context, member: Crew) -> StringName:
	"""Bind one crew member; it starts idle on its own parking endpoint, where it is admitted on its first leg."""
	if ctx == null or ctx.owners == null or member == null or member.worker == NULL_REF or member.parking == NULL_REF:
		return REFUSE_SCOPE
	if _worker_row_of(ctx, member) < 0: return REFUSE_LOST
	_ctx = ctx
	_crew = member
	_foot = Footprint.new()
	_foot.configure(ctx.owners.profiles, ctx.owners.extents)
	_at = member.parking
	return &""


static func _worker_row_of(ctx: Context, member: Crew) -> int:
	"""The live resident row of the crew member, or -1."""
	return ctx.owners.residents.directory().get_typed_row(member.worker)


func worker_row() -> int:
	"""The crew member's Resident row, or -1 once it has gone."""
	return _worker_row_of(_ctx, _crew)


func underground() -> bool:
	"""Still underground: a registered route actor (Routes keeps it until it leaves from rest, or until a lost one's
	actor is removed, as the entry foreman's `_lost_actor_row` check), or walking in or out."""
	return _walk.walking() or _ctx.owners.routes._lost_actor_row(_crew.worker) >= 0


func walking() -> bool:
	"""On its timed walk in to the parking, or out (decision 1936)."""
	return _walk.walking()


func begin_walk_in() -> StringName:
	"""P-1933-1 (a), ADR1219's arrival: the builder walks from where it stands to its parking (P-1936-6 (a): the
	straight distance at its ground speed) and is registered there on arrival; already there, at once."""
	if _registered(): return &""
	var o: Owners = _ctx.owners
	var locations: Locations = o.binding._locations_ref.get_ref() as Locations
	var pose: Transforms.Pose = Transforms.Pose.new()
	if locations == null or not locations._live_ref(locations._live, _crew.parking): return REFUSE_SCOPE
	if not o.transforms.read_into(_crew.worker, pose): return REFUSE_LOST
	_walk.origin = Vector3i(pose.x, pose.y, pose.z)
	var code: StringName = _walk.begin(o.residents, worker_row(), _walk.origin, _point(_crew.parking), false)
	if code == &"" and not _walk.walking(): code = register()
	return code


func advance_walk() -> StringName:
	"""One tick of the walk: arriving in registers the builder on its parking; arriving out places it back."""
	if not _walk.step(): return &""
	return _arrive_out() if _walk.leaving else register()


func leave() -> StringName:
	"""P-1936-3 (a): after the dig the builder leaves the underground from rest on an endpoint and walks back to
	where it came from. A lost builder's actor is removed (ADR1225). One not yet at rest waits (a builder stopped
	while working stays at its station: decision 1937)."""
	if _walk.walking() or not underground(): return &""
	var o: Owners = _ctx.owners
	if _release_pending:
		if not lost() and not _at_source_ready(): return _wait_out()
		_release_pending = false
		var released: StringName = _release_phase()
		if released != &"": return released
	if lost(): return o.routes.unregister_lost_actor(_crew.worker)
	var code: StringName = o.routes.unregister_resting_actor(_crew.worker)
	if code == &"ROUTE_UNREGISTER_NOT_AT_REST": return _wait_out()
	if code != &"": return code
	var pose: Transforms.Pose = Transforms.Pose.new()
	if not o.transforms.read_into(_crew.worker, pose): return REFUSE_LOST
	code = _walk.begin(o.residents, worker_row(), Vector3i(pose.x, pose.y, pose.z), _walk.origin, true)
	if code == &"" and not _walk.walking(): code = _arrive_out()
	return code


func _on_a_span() -> bool:
	"""The actor is walking a span or has a route queued: its Job stays until it comes to rest (decision 1939: an actor
	left holding a retired Job is stale to every other actor's proof, and Routes holds it)."""
	if _ctx.owners.routes.read_actor_into(_crew.worker, _actor) != &"": return false
	return _actor.edge != NULL_REF or _actor.phase != Routes.PHASE_IDLE


func _at_source_ready() -> bool:
	"""The actor stands at READY in the source it actually holds, under its own Job and row (after a hand-over these
	are not the builder's `_job` and work row any more: review M1)."""
	var o: Owners = _ctx.owners
	if o.routes.read_actor_into(_crew.worker, _actor) != &"": return false
	return Routes.source_ready_leaf_refusal(o.routes, _crew.worker, _actor.job, _actor.profile_id,
		_actor.profile_revision, _actor.content_revision) == &""


func _wait_out() -> StringName:
	"""One more tick waiting to leave from rest; named once at the stall bound (the wait goes on, reserved)."""
	_stage_ticks += 1
	return REFUSE_STUCK if _stage_ticks == STAGE_TICK_LIMIT else &""


func _arrive_out() -> StringName:
	"""Back where it came from, facing as it stood. The placement is a foreign pose change to Routes, which every
	builder still underground must see: its occupancy roots are rebuilt at once (decision 1937), or no actor could
	move again."""
	var o: Owners = _ctx.owners
	var pose: Transforms.Pose = Transforms.Pose.new()
	if not o.transforms.read_into(_crew.worker, pose): return REFUSE_LOST
	if not o.transforms.place(_crew.worker, _walk.origin.x, _walk.origin.y, _walk.origin.z, pose.yaw): return REFUSE_LOST
	return o.routes.refresh_occupancy()


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
	"""In a travel stage: on the way to a station, the storage or back to parking (or about to set off), or hauling."""
	return _stage == STAGE_TRAVEL or _stage == STAGE_RETREAT or _stage == STAGE_TO_STORE or _stage == STAGE_HAUL


func in_motion() -> bool:
	"""Has set off: a leg was started or a turn made (and every leg after a haul), or a haul is under way. A builder
	with no leg to walk has not set off until it acts, so the foreman's footprint check still runs first."""
	return walking_next() and (_departed or _stage == STAGE_HAUL)


func take_finished() -> int:
	"""The order index whose FINISH settled since the last call, once; -1 otherwise."""
	var index: int = _finished
	_finished = -1
	return index


func register() -> StringName:
	"""ADR1219's arrival, for a builder: its Transform is placed exactly on its parking endpoint, facing the forward
	row's heading, and it is registered with Routes there, before any of the room's work moves. Builders arrive one
	after another, so each one's occupancy proof sees the ones already registered (ROUTE_UNREGISTERED_RESIDENT_NEAR).
	`begin_walk_in` times the walk there and calls this on arrival."""
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
	if _ctx.owners.sites.project_of(site) != NULL_REF:
		code = _take_paid_phase()
	else:
		_operation = _next_operation(site)
		code = _open_phase(tick)
	if code == &"": code = _set_off(_ctx.forward)
	return _fail(code) if code != &"" else &""


func _next_operation(site: Vector2i) -> int:
	"""Decision 1991 (item 24 of decision 1990): the phase a cube with no live Project needs next, by Sites' own
	record. A dig stopped between a hand-over and its next phase's start leaves a cube BRACED (or open and unfinished)
	with the next phase cancelled unpaid; a re-order continues it from there, never opening a BRACE twice."""
	var phase: int = _ctx.owners.sites._phase[site.x]
	if phase == Sites.BRACED or phase == Sites.CUTTING: return Contract.OP_CUT
	if phase == Sites.OPEN_UNFINISHED or phase == Sites.FINISHING: return Contract.OP_FINISH
	return Contract.OP_BRACE


func _take_paid_phase() -> StringName:
	"""P-1933-2 (a): a phase a stopped dig had started is taken over, not reopened: its own bound Job, no new inputs,
	and Sites' `resume_phase_work` at the station instead of START."""
	var o: Owners = _ctx.owners
	if not _phase_started() or not o.sites.operation_into(_site, _math): return REFUSE_STATE
	_operation = _math.value
	_job = o.jobs.directory().get_typed_row(o.sites.job_of(_site))
	_resuming = true
	return &"" if _job >= 0 else REFUSE_STATE


func _set_off(store_anchor: int) -> StringName:
	"""Claim the cube's footprint and set off for the station; or, when the BRACE lacks inputs, first for the storage
	(along `store_anchor`'s family), where the haul's last trip hands the builder its Job. Otherwise it takes it now
	and reserves the inputs at once, so no other builder plans against them. A tool the work row names is claimed at
	the station, where the work begins."""
	_departed = false
	var code: StringName = _haul_units(_queue)
	if code == &"": code = _plan_claim(store_anchor)
	if code == &"" and _foot.overflowed(): code = REFUSE_FOOTPRINT
	if code != &"": return code
	if not _queue.is_empty():
		_set_stage(STAGE_TO_STORE)
		return &""
	var result: RefCounted = _ctx.owners.jobs.assign_worker(_worker_row_of(_ctx, _crew), _job)
	code = result.error if not result.ok else (&"" if _resuming else _reserve_inputs())
	if code == &"": _set_stage(STAGE_TRAVEL)
	return code


func _haul_units(out: PackedInt32Array) -> StringName:
	"""ADR1210's rule: whole units of each BRACE input beyond the storage's free stock. None without a bound Delivery
	and a staging container; a staging container on another level is the stair-carry gap (decision 1934)."""
	out.clear()
	var o: Owners = _ctx.owners
	if o.delivery == null or _ctx.staging == NULL_REF or _operation != Contract.OP_BRACE or _resuming: return &""
	var items: PackedInt32Array = PackedInt32Array()
	var milli: PackedInt64Array = PackedInt64Array()
	for line: int in Contract.input_count(_operation):
		items.append(o.items.compiled_id(Contract.input_key(_operation, line)))
		milli.append(Contract.input_milli(_operation, line))
	var code: StringName = Hauler.units_into(o, _ctx.storage, items, milli, out)
	return _level_refusal() if code == &"" and not out.is_empty() else code


func _level_refusal() -> StringName:
	"""Both containers stand on live endpoints of one level, in the binding's own Locations; a missing endpoint has no
	stand (the hauler's word). The endpoints are kept: the haul starts only between the same two."""
	var o: Owners = _ctx.owners
	if o.locations == null or o.locations != o.binding._locations_ref.get_ref(): return REFUSE_SCOPE
	var store: Vector2i = o.inventory.spatial_location_of(_ctx.storage)
	var source: Vector2i = o.inventory.spatial_location_of(_ctx.staging)
	if not o.locations._live_ref(o.locations._live, store) or not o.locations._live_ref(o.locations._live, source):
		return Hauler.REFUSE_STAND
	_haul_store = store
	_haul_source = source
	var bank: Locations.Bank = o.locations._live
	var stride: int = o.locations._capacity
	return &"" if bank.i32[Locations.LEVEL * stride + store.x] == bank.i32[Locations.LEVEL * stride + source.x] \
		else REFUSE_STAIR


func _plan_claim(store_anchor: int) -> StringName:
	"""The cube's whole plan before setting off: the way back (kept for going home), the way there and, with a haul,
	the walk to the storage (along `store_anchor`'s family) and the trips; then its footprint is swept from the plan.
	The legs left planned are the first ones walked."""
	_plan.clear()
	_plan.start = _at
	var forward: int = _heading_row(_ctx.forward, Profiles.POLICY_READY_FORWARD) # Decision 1943: the cube's heading.
	var backward: int = _heading_row(_ctx.backward, Profiles.POLICY_READY_BACKWARD)
	if forward < 0 or backward < 0: return REFUSE_HEADING_ROWS
	var code: StringName = _plan_legs(_station, _crew.parking, backward, false)
	if code != &"": return code
	_plan.home_legs = _legs.duplicate()
	_plan.home_profiles = _leg_profiles.duplicate()
	if not _queue.is_empty():
		_plan.store = _store()
		code = _plan_trips()
	if code == &"": code = _plan_legs(_plan.store if _plan.hauls() else _at, _station, forward, true)
	if code != &"": return code
	_plan.approach_legs = _legs.duplicate()
	_plan.approach_profiles = _leg_profiles.duplicate()
	if _plan.hauls():
		code = _plan_legs(_at, _plan.store, store_anchor, false)
		_plan.store_legs = _legs.duplicate()
		_plan.store_profiles = _leg_profiles.duplicate()
	if code == &"" and not _plan.bounded(): code = REFUSE_FOOTPRINT
	if code == &"": _sweep_claim()
	return code


func _heading_row(row: int, policy: int) -> int:
	"""Decision 1943: the bound travel row itself when the cube's work row shares its heading (as before), else that
	row's own sibling at the work row's yaw (ADR 1213's family), or -1 when the content has none."""
	var yaw: int = _yaw(_work_profile)
	if yaw == _yaw(row): return row
	return Itinerary.family_row(_ctx.owners.profiles, row, yaw, policy)


func _sweep_claim() -> void:
	"""The footprint swept from the plan (the same at planning and after a load)."""
	_plan.sweep_into(_foot, _ctx.owners.locations if _ctx.owners.locations != null \
		else _ctx.owners.binding._locations_ref.get_ref(), _ctx.owners.routes, _station, _work_profile)


func _store() -> Vector2i:
	"""The room storage's endpoint."""
	return _ctx.owners.inventory.spatial_location_of(_ctx.storage)


func _plan_trips() -> StringName:
	"""The trips along the routes Routes would take: empty on the haul WALK row from the storage to the staging stand,
	between the stands and back onto the storage; loaded on each item's CARRY row between the stands. Each searched
	edge is kept, with the two stands and the carried rows (ADR1206: lift +2, set-down +4, swept at the stands)."""
	var store: Vector2i = _haul_store
	var stand_store: Vector2i = _stand_of(store)
	var stand_source: Vector2i = _stand_of(_haul_source)
	var walk: int = _walk_row()
	if stand_store == NULL_REF or stand_source == NULL_REF or walk < 0: return Hauler.REFUSE_STAND
	_plan.stands = PackedInt32Array([stand_source.x, stand_source.y, stand_store.x, stand_store.y])
	var code: StringName = _trip_path(store, stand_source, walk)
	if code == &"": code = _trip_path(stand_store, stand_source, walk)
	if code == &"": code = _trip_path(stand_store, store, walk)
	for line: int in _queue.size():
		if code != &"" or _queue.find(_queue[line]) != line: continue
		var carry: int = Grip.carry_row_for(_queue[line])
		_plan.carries.append(carry)
		code = _trip_path(stand_source, stand_store, carry)
	return code


func _trip_path(from: Vector2i, to: Vector2i, row: int) -> StringName:
	"""Search the graph as Routes would for one row and keep every edge it takes."""
	var o: Owners = _ctx.owners
	var remaining: PackedInt32Array = PackedInt32Array([0])
	var code: StringName = WorldRoutes.profile_reachability_refusal(o.binding, from, to, row, _revision(row),
		_ctx.content, Space.MAX_CHECKS, remaining)
	if code != &"": return code
	var graph: Routes = o.routes
	for index: int in graph._proposed_count:
		_plan.trips.append_array(PackedInt32Array([graph._proposed_edges[2 * index], graph._proposed_edges[2 * index + 1],
			row]))
	return &""


func _stand_of(storage: Vector2i) -> Vector2i:
	"""The one live WORK endpoint at the certified stand offset from a storage endpoint (the hauler's own rule)."""
	var bank: Locations.Bank = _ctx.owners.locations._live
	var stride: int = _ctx.owners.locations._capacity
	var point: Vector3i = _point(storage) - Grip.stock_offset(Grip.QUARTER)
	var found: Vector2i = NULL_REF
	for at: int in stride:
		if bank.present[at] != 1 or bank.i32[Locations.ROLE * stride + at] != Locations.ROLE_WORK \
				or _point(Vector2i(at, 0)) != point: continue
		if found != NULL_REF: return NULL_REF
		found = Vector2i(at, bank.i32[Locations.GENERATION * stride + at])
	return found


func _walk_row() -> int:
	"""The certified automatic WALK row with no tool and no cargo: the row the hauler's switch at rest selects for a
	tool-free worker (one such row in contents 6-10, row 31)."""
	var profiles: Profiles = _ctx.owners.profiles
	var stride: int = profiles._profile_capacity
	for row: int in profiles._live.header[1]:
		if profiles._live.flags[row] == Profiles.CERT_REQUIRED and profiles._live.flags[stride + row] == Profiles.POLICY_AUTOMATIC \
				and profiles._live.fields[Profiles.F_MODE * stride + row] == Profiles.MODE_WALK \
				and profiles._live.fields[Profiles.F_TOOL * stride + row] == -1 \
				and profiles._live.fields[Profiles.F_CARGO * stride + row] == -1: return row
	return -1


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
	"""ADR1213's foreman step, aimed at one Site: the next unpaid Site after key-1 must be this one. Decision 1943: a
	claw digger now holding a tool stops the dig in words (`REFUSE_PICK_CANNOT_TURN`)."""
	var o: Owners = _ctx.owners
	if _crew.tool == NULL_REF and o.residents.has_equipped_tool(_worker_row_of(_ctx, _crew)):
		return _fail(REFUSE_PICK_CANNOT_TURN)
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
	if code == Frontier.REFUSE_ACTIVE and candidate.site == site: # P-1933-2 (a): a paid phase is taken over.
		code = Planner.resume_contact_into(o.provider, candidate, _ctx.forward, cold, Space.MAX_CHECKS, contact)
	if code == &"" and (candidate.key != key or candidate.site != site): code = REFUSE_TARGET
	if code == &"":
		_station = contact.location
		_work_profile = contact.profile_id
	candidate = null; contact = null; request = null; result = null
	o.budget.release(cold)
	return code


func _open_phase(tick: int) -> StringName:
	"""Open the paid phase and create its BUILD Job for the whole quoted work, bound to it (not yet assigned)."""
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
	var result: RefCounted = o.jobs.set_requester(_job, project)
	if result.ok: result = o.jobs.set_tool_gate(_job, tool_gate())
	if result.ok: result = o.sites.bind_job(_site, o.jobs.ref_of(_job))
	if result.ok: result = o.sites.bind_material_container(_site, _ctx.storage)
	if result.ok and _operation == Contract.OP_CUT: result = o.sites.bind_output(_site, _ctx.output)
	return &"" if result.ok else result.error


func _assign() -> StringName:
	"""This builder takes the Job, and claims its tool only when the row requires one."""
	var result: RefCounted = _ctx.owners.jobs.assign_worker(_worker_row_of(_ctx, _crew), _job)
	return _claim_tool() if result.ok else result.error


func _claim_tool() -> StringName:
	"""Claim the crew member's tool for the Job only when the work row names one (DEC-052: the claw rows do not)."""
	if tool_gate() != Jobs.GATE_SATISFIED: return &""
	var result: RefCounted = _ctx.owners.work.claim_tool_for_work(_worker_row_of(_ctx, _crew), _crew.tool)
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
		STAGE_TRAVEL, STAGE_RETREAT, STAGE_TO_STORE: return _travel(tick)
		STAGE_HAUL: return _haul(tick)
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
	_failed_from = _stage
	_stage = STAGE_FAILED
	return code


func _job_ref() -> Vector2i:
	"""The current phase Job during the approach and the phases; null on the way back (settlement released it)."""
	return _ctx.owners.jobs.ref_of(_job) if _leg_job else NULL_REF


func _travel(tick: int) -> StringName:
	"""Walk the planned legs one at a time; past the last one the builder faces the work, hauls or parks."""
	if _leg >= _leg_profiles.size(): return _end_travel(tick)
	if _leg_state == LEG_MOVING:
		var arrived: StringName = _arrived()
		if arrived != &"": return &"" if arrived == WAIT else arrived
		_at = Vector2i(_legs[2 * _leg], _legs[2 * _leg + 1])
		_leg += 1
		_leg_state = LEG_NONE
		_stage_ticks = 0
		if _leg >= _leg_profiles.size(): return _end_travel(tick)
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
		_departed = true
		return WorldRoutes.turn_actor(o.binding, _crew.worker, _job_ref(), _yaw(profile), Space.MAX_CHECKS)
	else:
		code = o.routes.refresh_travel_actor(_crew.worker, _job_ref(), profile, _revision(profile), _ctx.content,
			0, -1, _crew.tool)
	if code == &"": code = o.routes.request_route(_crew.worker, target, tick)
	if code == &"":
		_leg_state = LEG_MOVING
		_departed = true
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


func _end_travel(tick: int) -> StringName:
	"""Back at parking: idle. On the storage: haul. At the station: face the work row (its own stationary tick), then
	select it."""
	if _stage == STAGE_TO_STORE:
		if may_work(): return _start_haul(tick)
		_stage_ticks = 0 # Arrived in a rest hour: the haul starts when the hour allows work.
		return &""
	if _stage == STAGE_RETREAT:
		_index = -1
		_foot.clear_claim()
		_foot.stand(_point(_crew.parking), _ctx.forward)
		_set_stage(STAGE_IDLE)
		return &""
	if _leg_state != LEG_TURNED and _needs_turn(_work_profile):
		_leg_state = LEG_TURNED
		return WorldRoutes.turn_actor(_ctx.owners.binding, _crew.worker, _job_ref(), _yaw(_work_profile), Space.MAX_CHECKS)
	var code: StringName = _claim_tool()
	if code != &"": return code
	_set_stage(STAGE_ENTER)
	return _refresh_work()


func _start_haul(tick: int) -> StringName:
	"""On the storage: both endpoints are re-proved to be the ones planned (still one level), then the hauler
	(unchanged) carries every queued unit and the BRACE Job takes the builder back onto the storage. Its one leg is
	already walked, so the first trip starts at once."""
	var o: Owners = _ctx.owners
	var planned: Vector4i = Vector4i(_haul_store.x, _haul_store.y, _haul_source.x, _haul_source.y)
	var code: StringName = _level_refusal()
	if code != &"": return code
	if planned != Vector4i(_haul_store.x, _haul_store.y, _haul_source.x, _haul_source.y): return REFUSE_TARGET
	_at = _store()
	_departed = true
	var leg: Hauler.Leg = Hauler.Leg.new()
	leg.target = _at
	leg.profile = _ctx.forward
	leg.revision = _revision(_ctx.forward)
	var legs: Array[Hauler.Leg] = [leg]
	var haul: HaulCrew = HaulCrew.new()
	haul.worker = _crew.worker
	haul.storage = _ctx.storage
	haul.output = _ctx.staging
	_hauler = Hauler.new()
	_haul_marker = -1
	_set_stage(STAGE_HAUL)
	return _hauler.begin(o, haul, o.sites.project_of(_site), _job, _queue, legs, _at, tick)


func _haul(tick: int) -> StringName:
	"""Delegate to the hauler (a finished trip or stage restarts the stall bound); during a rest hour it is not
	advanced, so no trip takes its Job then (Jobs refuses an assignment in a rest hour). Once home on the storage under
	the BRACE Job, reserve the inputs and go on along the claimed way to the station (still set off: the claim stays
	occupied)."""
	if not may_work():
		_stage_ticks = 0 # ADR1226: a rest hour is waited out where the haul stands (each trip takes a new Job).
		return &""
	var code: StringName = _hauler.advance(tick)
	if code != &"": return code
	var marker: int = _hauler.trips() * 16 + _hauler.stage()
	if marker != _haul_marker: _stage_ticks = 0
	_haul_marker = marker
	if _hauler.stage() != Hauler.STAGE_DONE: return &""
	_haul_trips += _hauler.trips()
	_haul_mwu += _hauler.haul_mwu()
	_hauler = null
	_foot.stand(_point(_at), _walk_row())
	_legs = _plan.approach_legs.duplicate()
	_leg_profiles = _plan.approach_profiles.duplicate()
	_leg = 0
	_leg_state = LEG_NONE
	_leg_job = true
	code = _reserve_inputs()
	if code == &"": _set_stage(STAGE_TRAVEL)
	return code


func haul_trips() -> int:
	"""Whole units this builder carried from the staging container to the room's storage."""
	return _haul_trips


func haul_mwu() -> int:
	"""Lift and set-down Work the hauls' HAUL Jobs were paid, in milli-WU."""
	return _haul_mwu


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
	"""Record the delivery of the inputs reserved when the builder set off (or after its haul), bind the worker and
	START; a paid phase taken over resumes instead (its inputs were consumed at its first START). Sites proves the
	delivery with the worker at its station, so it is recorded here."""
	var o: Owners = _ctx.owners
	if Contract.input_count(_operation) > 0 and not _resuming:
		var delivered: Construction.OpResult = o.sites.record_deliveries(_site)
		if not delivered.ok: return delivered.error
	var result: Construction.OpResult = o.sites.bind_worker(_site)
	if result.ok: result = o.sites.resume_phase_work(_site) if _resuming else o.sites.begin_phase_work(_site, tick)
	if not result.ok and _resuming and _proof_lost(result.error): # Decision 1938: the stopped dig's proof is stale.
		o.sites._spatial().refresh_static_proof(_site)
		result = o.sites.resume_phase_work(_site)
	if not result.ok: return result.error
	_resuming = false
	_set_stage(STAGE_EARN)
	return &""


func _reserve_inputs() -> StringName:
	"""Each input line claims its exact quantity from the free stock of its item in the room's storage container for
	the phase Job (consumed only at START, ECON-003)."""
	var o: Owners = _ctx.owners
	for line: int in Contract.input_count(_operation):
		var code: StringName = Installer.claim_stock(o, _ctx.storage, o.jobs.ref_of(_job),
			o.items.compiled_id(Contract.input_key(_operation, line)), Contract.input_milli(_operation, line),
			Reservations.PURPOSE_EXCAVATION_INPUT)
		if code != &"": return code
	return &""


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
	if code == &"": code = _assign()
	if code == &"": code = o.routes.hand_over_source_job(_crew.worker, old, o.jobs.ref_of(_job))
	if code == &"": _set_stage(STAGE_START)
	return code


func _between(tick: int) -> StringName:
	"""READY at the station between two phases of one cube with no Job: wait out a rest hour (ADR1226), then open
	the next phase and re-enter WORK."""
	if not may_work():
		_stage_ticks = 0 # A rest is not a stall.
		return _drop_retired_job() if _holds_a_job() else &"" # Decision 1939 (review M4): not stale while it rests.
	var code: StringName = _open_phase(tick)
	if code == &"": code = _assign()
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
	keeps its paid Project for a later resume (P-1933-2 (a)) and only its worker is released. An unstarted one is
	cancelled (claims released, Project and Job retired: nothing was paid). A builder stopped in a work source is
	first asked to recover to READY under its Job, and the release waits for that (`leave`), so it can leave from rest
	(decision 1936); otherwise the route actor stays where it stopped."""
	var was: int = _failed_from if _stage == STAGE_FAILED else _stage
	_stage = STAGE_FAILED
	_stage_ticks = 0
	if _walk.walking() and not _walk.leaving: _walk.ticks_left = 0 # Its body never left where it stood.
	var o: Owners = _ctx.owners
	if was >= STAGE_ENTER and was <= STAGE_RECOVER and _job >= 0 and not lost() \
			and o.routes.read_actor_into(_crew.worker, _actor) == &"" \
			and o.routes.request_source_ready(_crew.worker, _actor.job) == &"": # Under the Job it holds (M1).
		_release_pending = true
		return &""
	if _job >= 0 and not lost() and _on_a_span() and _actor.job != NULL_REF and _actor.job == o.jobs.ref_of(_job):
		# Decision 1939 (B5): a leg walked under the phase Job keeps it until rest, never released mid-step. A builder
		# walking home holds no Job (review H1), so it is released at once.
		_release_pending = true
		return &""
	return _release_phase()


func _release_phase() -> StringName:
	"""Free the resident and this builder's open phase (see `abandon`)."""
	var o: Owners = _ctx.owners
	var dropped: StringName = _drop_haul() # A refused haul release is reported, but the phase is still released.
	if _site == NULL_REF or o.sites.project_of(_site) == NULL_REF: return dropped
	var released: Construction.OpResult = o.sites.release_worker(_site)
	if not released.ok: # Sites releases a Job nobody holds as already free (TO_STORE, a haul's own Job, or a paid
		if _phase_started() and released.error != Sites.REFUSE_WORKER: return released.error # phase taken over
		var code: StringName = _release_assignment(released.error) # but not yet bound: only Jobs holds it).
		if code != &"": return dropped if dropped != &"" else code
	if _phase_started(): return dropped # A started phase keeps its paid Project (never while hauling).
	var cancelled: Construction.OpResult = o.sites.cancel_phase(_site, _ctx.storage)
	return dropped if dropped != &"" or cancelled.ok else cancelled.error


func _drop_haul() -> StringName:
	"""A haul under way returns its admitted claims through Delivery's own cancel and retires its HAUL Job; goods
	already lifted stay in the satchel (ADR1225, as the entry's)."""
	if _hauler == null: return &""
	var hauler: Hauler = _hauler
	_hauler = null
	_haul_trips += hauler.trips()
	_haul_mwu += hauler.haul_mwu()
	return hauler.release_lost(_crew.worker, _worker_row_of(_ctx, _crew))


func _release_assignment(sites_refusal: StringName) -> StringName:
	"""Before the worker is bound to its Site only Jobs holds it: release its tool claim, then the Job (as the entry
	foreman's `_release_phase_job` does before START). When Jobs does not hold it either, Sites' refusal stands."""
	var o: Owners = _ctx.owners
	var row: int = _worker_row_of(_ctx, _crew)
	if row < 0 or _job < 0 or o.jobs.job_of(row) != o.jobs.ref_of(_job): return sites_refusal
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
	return _drop_retired_job()


func _drop_retired_job() -> StringName:
	"""Decision 1939: the cube's last Job is retired. Another actor's occupancy proof reads every registered actor's
	selection, and a retired Job is stale there (ROUTE_TURN_ACTOR_STALE), so the builder stands at its station on the
	READY travel row of its heading with no Job until its next leg."""
	var o: Owners = _ctx.owners
	var row: int = Itinerary.family_row(o.profiles, _ctx.forward, _yaw(_work_profile), Profiles.POLICY_READY_FORWARD)
	if row < 0: return REFUSE_LEG
	return o.routes.refresh_travel_actor(_crew.worker, NULL_REF, row, _revision(row), _ctx.content, 0, -1, _crew.tool)


func _holds_a_job() -> bool:
	"""The builder's route actor still names a Job (the phase it just settled, before a rest is waited out)."""
	return _ctx.owners.routes.read_actor_into(_crew.worker, _actor) == &"" and _actor.job != NULL_REF


func at_column_end() -> bool:
	"""Just finished a cube and stands READY at its station, waiting to be sent up the column or home."""
	return _stage == STAGE_COLUMN


func last_index() -> int:
	"""The order index of the cube this builder last took."""
	return _index


func station() -> Vector2i:
	"""The WORK station of the cube in hand, or of the last cube while idle (decision 1942), or null."""
	return _station


func last_site() -> Vector2i:
	"""The Site of the cube in hand, or of the last cube while idle (decision 1942), or null."""
	return _site


func holds(ref: Vector2i) -> bool:
	"""Decision 1942: this builder still holds the endpoint: its parking or where it stands, or, while out at work (or
	stopped there), its station, any planned leg's end, its stands or its haul endpoints. An idle builder's last
	station and plan are only history (`forget_retired`)."""
	if ref == _crew.parking or ref == _at: return true
	if _stage == STAGE_IDLE: return false
	if ref == _station or ref == _plan.start or ref == _plan.store or ref == _haul_store or ref == _haul_source:
		return true
	return _pair_in(_legs, ref) or _pair_in(_plan.home_legs, ref) or _pair_in(_plan.approach_legs, ref) \
		or _pair_in(_plan.store_legs, ref) or _pair_in(_plan.stands, ref)


static func _pair_in(pairs: PackedInt32Array, ref: Vector2i) -> bool:
	"""`ref` is one of the (slot, generation) pairs."""
	for at: int in range(0, pairs.size() - 1, 2):
		if pairs[at] == ref.x and pairs[at + 1] == ref.y: return true
	return false


func forget_retired(chain: PackedInt32Array) -> void:
	"""Decision 1942: an idle builder whose last station or plan named a retired station forgets them (a save must
	name only live endpoints); its next cube plans afresh. Nothing else changes."""
	if _stage != STAGE_IDLE or not _names_any(chain): return
	_station = NULL_REF
	_plan.clear()
	_legs.clear()
	_leg_profiles.clear()
	_leg = 0
	_sweep_claim()


func _names_any(chain: PackedInt32Array) -> bool:
	"""The station, the current legs or any planned leg names one of the chain's (slot, generation) pairs."""
	for at: int in range(0, chain.size() - 1, 2):
		var ref: Vector2i = Vector2i(chain[at], chain[at + 1])
		if ref == _station or ref == _plan.start or ref == _plan.store or _pair_in(_legs, ref) \
				or _pair_in(_plan.home_legs, ref) or _pair_in(_plan.approach_legs, ref) or _pair_in(_plan.store_legs, ref):
			return true
	return false


func continue_column(index: int, site: Vector2i, key: int, tick: int) -> StringName:
	"""Painted height (decision 1971): the next cube up the same column is taken straight from where the builder
	stands. A refused contact leaves it at the station (the foreman then sends it home); a later refusal fails it."""
	if _stage != STAGE_COLUMN: return REFUSE_STATE
	var code: StringName = _contact(site, key)
	if code != &"": return code
	_index = index
	_site = site
	_operation = _next_operation(site)
	code = _open_phase(tick)
	if code == &"": code = _set_off(_ctx.backward)
	if code == &"": _column_cubes += 1
	return _fail(code) if code != &"" else &""


func column_cubes() -> int:
	"""Cubes this builder took straight up a column without walking home first."""
	return _column_cubes


func go_home() -> StringName:
	"""From the station back to its parking, along the way back claimed with the cube (never re-planned: chains
	published since could lead outside the claimed footprint)."""
	if _stage != STAGE_COLUMN: return REFUSE_STATE
	_legs = _plan.home_legs.duplicate()
	_leg_profiles = _plan.home_profiles.duplicate()
	_leg = 0
	_leg_state = LEG_NONE
	_leg_job = false
	_departed = false
	_set_stage(STAGE_RETREAT)
	return &""


# --- Decision 1936: save and load (inside `underground_room_progress`) ----------------------------------------------

func _job_in_use() -> bool:
	"""Stages that still read the current phase's Job (a released Job slot may be reused)."""
	return _release_pending or _stage in [STAGE_TRAVEL, STAGE_ENTER, STAGE_START, STAGE_EARN, STAGE_RECOVER,
		STAGE_TO_STORE, STAGE_HAUL]


func write_state(w: EntryProgress.Writer) -> void:
	"""The crew, the cursor, the cube plan, the haul ledgers, the walk, the standing body and any haul in flight."""
	for at: Vector2i in [_crew.worker, _crew.tool, _crew.parking]:
		w.ref(at)
	_write_cursor(w)
	Progress.write_legs(w, _legs, _leg_profiles)
	Progress.write_legs(w, _plan.home_legs, _plan.home_profiles)
	Progress.write_legs(w, _plan.approach_legs, _plan.approach_profiles)
	Progress.write_legs(w, _plan.store_legs, _plan.store_profiles)
	Progress.write_list(w, _plan.trips)
	Progress.write_list(w, _plan.stands)
	Progress.write_list(w, _plan.carries)
	Progress.write_list(w, _queue)
	_write_tail(w)
	w.flag(_hauler != null)
	if _hauler != null: _hauler.write_state(w)


func _write_cursor(w: EntryProgress.Writer) -> void:
	"""Stage, stall count, refusal, the cube in hand and where the builder stands."""
	w.i32(_stage)
	w.i32(_stage_ticks)
	w.code(_error)
	w.i32(_failed_from)
	w.i32(_index)
	w.ref(_site)
	w.i32(_operation)
	w.i32(_job)
	w.ref(EntryProgress.job_ref(_ctx.owners.jobs, _job, _job_in_use()))
	w.ref(_station)
	w.i32(_work_profile)
	w.ref(_at)
	w.ref(_plan.start)
	w.ref(_plan.store)


func _write_tail(w: EntryProgress.Writer) -> void:
	"""The leg cursor and flags, the ledgers, the haul endpoints and ledgers, the walk and the standing body."""
	w.i32(_leg)
	w.i32(_leg_state)
	w.flag(_leg_job)
	w.flag(_departed)
	w.i32(_finished)
	w.i32(_cubes)
	w.i32(_column_cubes)
	w.i64(_accepted_mwu)
	w.ref(_haul_store)
	w.ref(_haul_source)
	w.i32(_haul_marker)
	w.i32(_haul_trips)
	w.i64(_haul_mwu)
	w.flag(_resuming)
	w.flag(_release_pending)
	w.i32(_walk.ticks_left)
	w.flag(_walk.leaving)
	for axis: int in 3:
		w.i32(_walk.origin[axis])
	Progress.write_box(w, _foot.body())


func read_state(r: EntryProgress.Reader, ctx: Context) -> StringName:
	"""Decode a saved builder under the restored context, re-prove the handles it will still read and sweep its
	footprint again from its plan."""
	var member: Crew = Crew.new()
	member.worker = r.ref()
	member.tool = r.ref()
	member.parking = r.ref()
	_ctx = ctx
	_crew = member
	_foot = Footprint.new()
	_foot.configure(ctx.owners.profiles, ctx.owners.extents)
	var job: Vector2i = _read_cursor(r)
	_read_plan(r)
	_read_tail(r)
	if r.bad: return Progress.REFUSE_SHAPE
	var code: StringName = _restored_refusal(job)
	if code == &"" and r.flag(): code = _read_hauler(r)
	if code == &"": _sweep_claim()
	return code


func _read_cursor(r: EntryProgress.Reader) -> Vector2i:
	"""The cursor in wire order; returns the saved Job handle."""
	_stage = r.ranged(STAGE_IDLE, STAGE_HAUL)
	_stage_ticks = r.ranged(0, STAGE_TICK_LIMIT + 1)
	_error = r.code()
	_failed_from = r.ranged(STAGE_IDLE, STAGE_HAUL)
	_index = r.i32()
	_site = r.ref()
	_operation = r.i32()
	_job = r.i32()
	var job: Vector2i = r.ref()
	_station = r.ref()
	_work_profile = r.i32()
	_at = r.ref()
	_plan.start = r.ref()
	_plan.store = r.ref()
	return job


func _read_plan(r: EntryProgress.Reader) -> void:
	"""The current legs and the cube plan."""
	Progress.read_legs(r, _legs, _leg_profiles)
	Progress.read_legs(r, _plan.home_legs, _plan.home_profiles)
	Progress.read_legs(r, _plan.approach_legs, _plan.approach_profiles)
	Progress.read_legs(r, _plan.store_legs, _plan.store_profiles)
	Progress.read_list(r, 3 * Claim.MAX_TRIP_EDGES, _plan.trips)
	Progress.read_list(r, 4, _plan.stands)
	Progress.read_list(r, 2, _plan.carries)
	Progress.read_list(r, EntryProgress.MAX_QUEUE, _queue)


func _read_tail(r: EntryProgress.Reader) -> void:
	"""The tail in wire order."""
	_leg = r.ranged(0, Claim.MAX_LEGS)
	_leg_state = r.ranged(LEG_NONE, LEG_MOVING)
	_leg_job = r.flag()
	_departed = r.flag()
	_finished = r.i32()
	_cubes = r.i32()
	_column_cubes = r.i32()
	_accepted_mwu = r.i64()
	_haul_store = r.ref()
	_haul_source = r.ref()
	_haul_marker = r.i32()
	_haul_trips = r.i32()
	_haul_mwu = r.i64()
	_resuming = r.flag()
	_release_pending = r.flag()
	_walk.ticks_left = r.i32()
	_walk.leaving = r.flag()
	_walk.origin = Vector3i(r.i32(), r.i32(), r.i32())
	Progress.read_box(r, _foot._body)


func _restored_refusal(job: Vector2i) -> StringName:
	"""The Job it still reads, its parking and every endpoint it stands on or walks to must be live; a builder
	underground and not walking must be a registered route actor (a lost one may already be gone)."""
	var o: Owners = _ctx.owners
	var code: StringName = EntryProgress.job_refusal(o.jobs, _job, job, _job_in_use())
	if code != &"": return code
	for at: Vector2i in [_crew.parking, _station, _at, _plan.start, _plan.store, _haul_store, _haul_source]:
		if at != NULL_REF and not o.locations.is_live_location(at): return EntryProgress.REFUSE_LOCATION
	if _walk.walking() or lost() or _stage == STAGE_IDLE and not _registered(): return &""
	return &"" if _registered() else EntryProgress.REFUSE_ACTOR


func _read_hauler(r: EntryProgress.Reader) -> StringName:
	"""The entry hauler's own block (ADR1218), under the builder's own Job and its storage and staging."""
	var haul: HaulCrew = HaulCrew.new()
	haul.worker = _crew.worker
	haul.storage = _ctx.storage
	haul.output = _ctx.staging
	_hauler = Hauler.new()
	return _hauler.read_state(r, _ctx.owners, haul, _job)
