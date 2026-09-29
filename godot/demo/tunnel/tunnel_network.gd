extends RefCounted
## Every tunnel in the demo village, as packed columns. Decision 0196 (live demo). Presentation
## only: it shapes the demo cast's walks and nothing else.
##
## A tunnel is a SLOT in fixed columns sized once for MAX_TUNNELS, referred to as (slot, generation)
## -- the project's EntityRef shape: a slot freed and reused bumps its generation, so an old
## reference can never reach the new tunnel. Its authoritative state is integer: route points and
## lengths in u (1/1024 m), microseconds of digging done, and from those the fixed ticks dug, the
## stage, and the spoil heaped at each mouth (tunnel_rules.gd).
##
## LIFE. DIGGING (its digger is working, or on the way) -> OPEN when the last tick is dug. A digger
## called away leaves it PAUSED with every tick and every unit of spoil it earned (ECON-005: pause
## retains physical progress and releases workers), or frees the slot when nothing was dug yet --
## no ground was broken, so there is nothing to keep. A digger that could NOT REACH the entrance
## leaves it PAUSED however little was dug (`hold_unreached`): the player chose that route, so it is
## kept as a 0% plan to resume, never silently deleted. `pause_reason` says which. An OPEN tunnel is never removed: the demo has
## no world edit that could change it (MOVE-REQ-004). Only OPEN tunnels are offered to the planner;
## unfinished space is never a through route (MOVE-REQ-002).
##
## FIT. Each resident's fit to the bore is set once, from its body (tunnel_rules.fits_bore), and a
## resident who does not fit is never offered a tunnel.
##
## PLANNING (`plan`). A tunnel is offered at its COST (tunnel_rules.route_cost_u: legs rounded up),
## never its floored length, and not at all while someone stands on either mouth -- a walker sent
## there would only give up. `mouth_circles_into` lists every planned mouth, for orders to keep off.
##
## HEAPS. Where each mouth's spoil heap will stand (tunnel_heaps.gd chooses it when the dig is
## accepted, at its finished size) is kept here as presentation data: heap_at and heap_radius_m.
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")

const PHASE_FREE: int = 0
const PHASE_DIGGING: int = 1
const PHASE_PAUSED: int = 2
const PHASE_OPEN: int = 3

const PAUSED_CALLED_AWAY: int = 1
const PAUSED_UNREACHED: int = 2

var phase: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var digger: PackedInt32Array = PackedInt32Array()
var point_count: PackedInt32Array = PackedInt32Array()
## (x, z) pairs in u, MAX_POINTS per slot.
var points_u: PackedInt32Array = PackedInt32Array()
## Distance from the entrance to each point, in u, MAX_POINTS per slot.
var cumulative_u: PackedInt32Array = PackedInt32Array()
var length_u: PackedInt32Array = PackedInt32Array()
## What the route costs a planner (legs rounded up), in u.
var cost_u: PackedInt32Array = PackedInt32Array()
## Why a PAUSED tunnel waits (PAUSED_*; 0 otherwise).
var pause_reason: PackedByteArray = PackedByteArray()
## Presentation: each mouth's heap centre (x, z) in metres and finished radius, two per slot
## (entrance, exit); radius 0 until placed.
var heap_at: PackedVector2Array = PackedVector2Array()
var heap_radius_m: PackedFloat32Array = PackedFloat32Array()
var quanta: PackedInt32Array = PackedInt32Array()
var dig_usec: PackedInt64Array = PackedInt64Array()
## Per resident index: 1 when its body fits a bore.
var resident_fit: PackedByteArray = PackedByteArray()
## Bumped whenever a tunnel is added, changes phase or is freed (so a drawer can rebuild on change).
var revision: int = 0
var router: RouterScript = RouterScript.new()


func _init() -> void:
	"""Size every column once."""
	phase.resize(Rules.MAX_TUNNELS)
	generation.resize(Rules.MAX_TUNNELS)
	digger.resize(Rules.MAX_TUNNELS)
	digger.fill(-1)
	point_count.resize(Rules.MAX_TUNNELS)
	points_u.resize(Rules.MAX_TUNNELS * Rules.MAX_POINTS * 2)
	cumulative_u.resize(Rules.MAX_TUNNELS * Rules.MAX_POINTS)
	length_u.resize(Rules.MAX_TUNNELS)
	cost_u.resize(Rules.MAX_TUNNELS)
	pause_reason.resize(Rules.MAX_TUNNELS)
	heap_at.resize(Rules.MAX_TUNNELS * 2)
	heap_radius_m.resize(Rules.MAX_TUNNELS * 2)
	quanta.resize(Rules.MAX_TUNNELS)
	dig_usec.resize(Rules.MAX_TUNNELS)


func has_room() -> bool:
	"""Whether a slot is free for another tunnel."""
	return phase.has(PHASE_FREE)


func add_into(route_u: PackedInt32Array, count: int, digger_index: int, out_ref: PackedInt32Array) -> bool:
	"""Store a route -- `count` (x, z) points in u, already validated (tunnel_rules.validate_route) --
	as a tunnel `digger_index` is to dig, and write its (slot, generation) into out_ref[0..1]. Refuses
	(false, nothing stored) with no free slot, a point count out of 2..MAX_POINTS or a route shorter
	than MIN_LENGTH_U."""
	var slot := phase.find(PHASE_FREE)
	if slot < 0 or count < 2 or count > Rules.MAX_POINTS:
		return false
	if Rules.route_length_u(route_u, count) < Rules.MIN_LENGTH_U:
		return false
	var base := slot * Rules.MAX_POINTS
	var run := 0
	for k in count:
		if k > 0:
			var dx := route_u[2 * k] - route_u[2 * k - 2]
			var dz := route_u[2 * k + 1] - route_u[2 * k - 1]
			run += Rules.isqrt(dx * dx + dz * dz)
		points_u[2 * (base + k)] = route_u[2 * k]
		points_u[2 * (base + k) + 1] = route_u[2 * k + 1]
		cumulative_u[base + k] = run
	_store(slot, run, Rules.route_cost_u(route_u, count), count)
	_set_phase(slot, PHASE_DIGGING, digger_index)
	out_ref[0] = slot
	out_ref[1] = generation[slot]
	return true


func _store(slot: int, run: int, cost: int, count: int) -> void:
	"""A new tunnel's scalars: its point count, length, cost and quanta, nothing dug, no heaps placed."""
	point_count[slot] = count
	length_u[slot] = run
	cost_u[slot] = cost
	quanta[slot] = Rules.bore_quanta(run)
	dig_usec[slot] = 0
	heap_radius_m[2 * slot] = 0.0
	heap_radius_m[2 * slot + 1] = 0.0


func _set_phase(slot: int, to: int, digger_index: int) -> void:
	"""Change a slot's phase and digger, and note the change (a pause reason lasts only while paused)."""
	phase[slot] = to
	digger[slot] = digger_index
	if to != PHASE_PAUSED:
		pause_reason[slot] = 0
	revision += 1


func is_ref(slot: int, gen: int) -> bool:
	"""Whether (slot, gen) names a tunnel that still exists (EntityRef validation)."""
	return slot >= 0 and slot < Rules.MAX_TUNNELS and phase[slot] != PHASE_FREE and generation[slot] == gen


func is_open(slot: int) -> bool:
	"""Whether a slot holds a finished tunnel."""
	return phase[slot] == PHASE_OPEN


func open_count() -> int:
	"""How many tunnels are finished."""
	return phase.count(PHASE_OPEN)


func advance(slot: int, gen: int, usec: int) -> void:
	"""Credit `usec` microseconds of digging to a DIGGING tunnel (others are left alone); it opens
	when the last tick is dug."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING or usec <= 0:
		return
	dig_usec[slot] += usec
	if done(slot) >= Rules.total_ticks(quanta[slot]):
		_set_phase(slot, PHASE_OPEN, -1)


func stop_digging(slot: int, gen: int) -> void:
	"""The digger was called away: keep the tunnel PAUSED with its progress, or free the slot (and
	retire its generation) when not one tick was dug."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING:
		return
	if done(slot) > 0:
		_set_phase(slot, PHASE_PAUSED, -1)
		pause_reason[slot] = PAUSED_CALLED_AWAY
		return
	generation[slot] += 1
	_set_phase(slot, PHASE_FREE, -1)


func hold_unreached(slot: int, gen: int) -> void:
	"""The digger could not reach the entrance: keep the tunnel PAUSED as it stands (at 0% if nothing
	was dug), to be resumed, rather than dropping the player's route (see LIFE)."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING:
		return
	_set_phase(slot, PHASE_PAUSED, -1)
	pause_reason[slot] = PAUSED_UNREACHED


func resume(slot: int, gen: int, digger_index: int) -> bool:
	"""Put a PAUSED tunnel back to DIGGING under `digger_index`. False when it is not paused."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_PAUSED:
		return false
	_set_phase(slot, PHASE_DIGGING, digger_index)
	return true


func done(slot: int) -> int:
	"""Fixed ticks dug so far."""
	return Rules.done_ticks(dig_usec[slot], quanta[slot])


func stage(slot: int) -> int:
	"""Rules.STAGE_*: which part is being dug, or STAGE_OPEN."""
	return Rules.stage_of(done(slot), quanta[slot])


func percent(slot: int) -> int:
	"""Whole percent dug."""
	return Rules.percent(done(slot), quanta[slot])


func spoil_into(slot: int, out: PackedInt64Array) -> void:
	"""Spoil heaped so far, milli-U: out[0] at the entrance, out[1] at the exit."""
	Rules.spoil_into(done(slot), quanta[slot], out)


func face_m(slot: int) -> float:
	"""How far along the route the dig face is, in metres (presentation)."""
	return Rules.to_m(Rules.face_u(done(slot), quanta[slot], length_u[slot]))


func length_m(slot: int) -> float:
	"""The tunnel's length in metres (presentation)."""
	return Rules.to_m(length_u[slot])


func cost_m(slot: int) -> float:
	"""What the tunnel costs a planner, in metres (legs rounded up; see PLANNING)."""
	return Rules.to_m(cost_u[slot])


func set_heap(slot: int, exit: bool, at: Vector2, radius: float) -> void:
	"""Where a mouth's heap stands, and its finished radius (tunnel_heaps.gd)."""
	var k := 2 * slot + (1 if exit else 0)
	heap_at[k] = at
	heap_radius_m[k] = radius


# --- geometry (presentation) ------------------------------------------------------------------

func point(slot: int, k: int) -> Vector2:
	"""Route point `k` in metres (x, z)."""
	var i := 2 * (slot * Rules.MAX_POINTS + k)
	return Vector2(Rules.to_m(points_u[i]), Rules.to_m(points_u[i + 1]))


func mouth(slot: int, exit: bool) -> Vector2:
	"""The entrance, or the exit when `exit`, in metres."""
	return point(slot, point_count[slot] - 1 if exit else 0)


func _segment_at(slot: int, along_m: float) -> int:
	"""The route leg (1..count-1, ending at that point) holding distance `along_m`."""
	var base := slot * Rules.MAX_POINTS
	for k in range(1, point_count[slot]):
		if along_m <= Rules.to_m(cumulative_u[base + k]):
			return k
	return point_count[slot] - 1


func point_at(slot: int, along_m: float) -> Vector2:
	"""The route's point `along_m` metres from the entrance (clamped to the route)."""
	var k := _segment_at(slot, along_m)
	var c0 := Rules.to_m(cumulative_u[slot * Rules.MAX_POINTS + k - 1])
	var c1 := Rules.to_m(cumulative_u[slot * Rules.MAX_POINTS + k])
	var t := clampf((along_m - c0) / maxf(c1 - c0, 1e-6), 0.0, 1.0)
	return point(slot, k - 1).lerp(point(slot, k), t)


func direction_at(slot: int, along_m: float) -> Vector2:
	"""The unit direction of the route leg `along_m` metres from the entrance (entrance -> exit)."""
	var k := _segment_at(slot, along_m)
	return (point(slot, k) - point(slot, k - 1)).normalized()


func floor_y_at(slot: int, along_m: float) -> float:
	"""The bore floor's height this far along (negative underground; 0 at each mouth)."""
	return Rules.floor_y_m(along_m, length_m(slot))


# --- residents and planning -------------------------------------------------------------------

func set_fit(index: int, fits_bore: bool) -> void:
	"""Record whether resident `index` fits a bore (setup only: the column grows here)."""
	if resident_fit.size() <= index:
		resident_fit.resize(index + 1)
	resident_fit[index] = 1 if fits_bore else 0


func fits(index: int) -> bool:
	"""Whether resident `index` fits a bore (unknown residents do not)."""
	return index >= 0 and index < resident_fit.size() and resident_fit[index] == 1


func mouth_circles_into(out: PackedVector3Array, first: int) -> int:
	"""Write every planned tunnel's mouths as circles (x, rim radius, z) into `out` from index `first`
	(`out` has room for 2 x MAX_TUNNELS more); returns how many."""
	var count := 0
	var rim := Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR
	for slot in Rules.MAX_TUNNELS:
		if phase[slot] == PHASE_FREE:
			continue
		for end in 2:
			var at := mouth(slot, end == 1)
			out[first + count] = Vector3(at.x, rim, at.y)
			count += 1
	return count


func mouth_occupied(slot: int, body: float, standing: PackedVector3Array, residents: int) -> bool:
	"""Whether a resident stands on either of a tunnel's mouths: closer to it than their radius plus
	the walker's `body` plus the planning margin (the first `residents` circles of `standing`)."""
	for end in 2:
		var at := mouth(slot, end == 1)
		for s in residents:
			var reach := standing[s].y + body + CastNavScript.PLAN_MARGIN_M
			if Vector2(standing[s].x, standing[s].z).distance_squared_to(at) < reach * reach:
				return true
	return false


func plan(nav: CastNavScript, from: Vector2, to: Vector2, body: float, standing: PackedVector3Array,
		standing_count: int, out: PackedVector2Array, legs: PackedInt32Array) -> bool:
	"""Plan from -> to through any OPEN tunnel whose mouths are free (tunnel_router.gd), round the
	first `standing_count` standing residents in `standing`. True when a route was found."""
	router.clear_pairs()
	for slot in Rules.MAX_TUNNELS:
		if phase[slot] == PHASE_OPEN and not mouth_occupied(slot, body, standing, standing_count):
			router.add_pair(slot, mouth(slot, false), mouth(slot, true), cost_m(slot))
	return router.plan(nav, from, to, body, standing, standing_count, revision, out, legs)
