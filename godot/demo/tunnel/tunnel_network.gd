extends RefCounted
## Every tunnel in the demo village, as packed columns. Decision 0196 (live demo). Presentation
## only: it shapes the demo cast's walks and nothing else.
##
## A tunnel is a SLOT in fixed columns sized once for MAX_TUNNELS, referred to as (slot, generation)
## -- the project's EntityRef shape: a slot freed and reused bumps its generation, so an old
## reference can never reach the new tunnel. Its authoritative state is integer: route points and
## lengths in u (1/1024 m), microseconds of digging done, and from those the fixed ticks dug, the
## stage, and the spoil heaped at each mouth.
##
## LIFE. DIGGING (its digger is working, or on the way) -> OPEN when the last tick is dug. A digger
## called away leaves it PAUSED with every tick and every unit of spoil it earned (ECON-005: pause
## retains physical progress and releases workers), or frees the slot when nothing was dug yet --
## no ground was broken, so there is nothing to keep. A digger that could NOT REACH the entrance
## leaves it PAUSED however little was dug (`hold_unreached`): the player chose that route, so it is
## kept as a 0% plan to resume, never silently deleted. `pause_reason` says which. An OPEN tunnel is
## never removed (MOVE-REQ-004). Only OPEN tunnels that are not CLOSED by a hazard are offered to the
## planner; unfinished space is never a through route (MOVE-REQ-002).
##
## THE DIG TIMELINE. A tunnel is a chain of cut quanta -- the entrance shaft, one per started metre
## of bore, the exit shaft -- and each is dug in the ticks its GROUND takes (tunnel_ground.gd; with no
## ground set, all loam: exactly the cited 113 ticks each). `_q_end` holds each quantum's end in
## ticks (a prefix sum), so the stage, the face and the spoil are read off it exactly. Work is
## credited in F1000-equivalent microseconds: `advance()` scales a frame's time by the slot's crew
## RATE (per mille, set by tunnel_crew.gd; 1000 for one worker) and keeps the remainder, so no
## microsecond is lost or counted twice.
##
## UPGRADES AND HAZARDS (tunnel_jobs.gd, tunnel_hazards.gd) end here as plain columns: the BORE
## class (standard, or wide once widened), whether it is BRACED and LIT, whether a hazard has
## CLOSED it (flooded, or a section collapsed), and extra spoil heaped by re-digging.
##
## FIT. Each resident's body is recorded once (`set_body`: standing height and radius in u), and
## fit is judged per tunnel -- against its bore class, and against the load's width for a carrier
## (tunnel_rules.fit_refusal_in). `set_fit` records a bare yes/no for a body not described.
##
## PLANNING (`plan`). A tunnel is offered at its COST (tunnel_rules.route_cost_u: legs rounded up),
## never its floored length, and not at all while someone stands on either mouth. Weather slows
## only the surface (`surface_permille`), lanterns quicken the bore, and a queue at a mouth adds
## its wait to entering there (tunnel_queue.gd). `mouth_circles_into` lists every planned mouth.
##
## HEAPS. Where each mouth's spoil heap will stand (tunnel_heaps.gd chooses it when the dig is
## accepted, at its finished size) is kept here as presentation data: heap_at and heap_radius_m.
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const QueueScript := preload("res://demo/tunnel/tunnel_queue.gd")

const PHASE_FREE: int = 0
const PHASE_DIGGING: int = 1
const PHASE_PAUSED: int = 2
const PHASE_OPEN: int = 3

const PAUSED_CALLED_AWAY: int = 1
const PAUSED_UNREACHED: int = 2

const CLOSED_NONE: int = 0
const CLOSED_FLOODED: int = 1
const CLOSED_COLLAPSED: int = 2

## The longest timeline: the entrance shaft, 64 bore quanta (MAX_LENGTH_U) and the exit shaft.
const MAX_TIMELINE: int = Rules.MAX_LENGTH_U / Rules.QUANTUM_U + 2 * Rules.SHAFT_QUANTA
## Demo: a lit bore is walked at this per mille of walk speed (tunnel_jobs.gd LANTERNS).
const LIT_SPEED_PERMILLE: int = 1100

## progress_into() writes these slots.
const P_CUTS: int = 0
const P_SPOIL: int = 1
const P_STONE: int = 2
const P_QUANTUM: int = 3
const P_INTO: int = 4
const P_SIZE: int = 5

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
## F1000-equivalent microseconds of digging credited, and the crew rate's remainder (see THE DIG
## TIMELINE).
var dig_usec: PackedInt64Array = PackedInt64Array()
var dig_rem: PackedInt64Array = PackedInt64Array()
var rate_permille: PackedInt32Array = PackedInt32Array()
## Per slot: bore class (Rules.BORE_*), braced and lit (0/1), CLOSED_*, and the collapsed section.
var bore: PackedByteArray = PackedByteArray()
var braced: PackedByteArray = PackedByteArray()
var lit: PackedByteArray = PackedByteArray()
var closed: PackedByteArray = PackedByteArray()
var closed_from_u: PackedInt32Array = PackedInt32Array()
var closed_to_u: PackedInt32Array = PackedInt32Array()
## Spoil (milli-U) heaped at the entrance by re-digging (widening, clearing a collapse).
var extra_spoil: PackedInt64Array = PackedInt64Array()
## Per resident index: 1 when its body fits a standard bore; its height and radius in u (0: unknown).
var resident_fit: PackedByteArray = PackedByteArray()
var body_height_u: PackedInt32Array = PackedInt32Array()
var body_radius_u: PackedInt32Array = PackedInt32Array()
## Bumped whenever a tunnel is added, changes phase, bore, bracing, lighting or closure, or is freed.
var revision: int = 0
## Surface walking speed per mille (the weather's), for planning.
var surface_permille: int = 1000
var router: RouterScript = RouterScript.new()
var queue: QueueScript = QueueScript.new()
var ground: GroundScript = null

var _q_kind: PackedByteArray = PackedByteArray()
var _q_end: PackedInt32Array = PackedInt32Array()
var _progress: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""Size every column once."""
	_size_bytes()
	_size_ints()
	points_u.resize(Rules.MAX_TUNNELS * Rules.MAX_POINTS * 2)
	cumulative_u.resize(Rules.MAX_TUNNELS * Rules.MAX_POINTS)
	heap_at.resize(Rules.MAX_TUNNELS * 2)
	heap_radius_m.resize(Rules.MAX_TUNNELS * 2)
	_q_kind.resize(Rules.MAX_TUNNELS * MAX_TIMELINE)
	_q_end.resize(Rules.MAX_TUNNELS * MAX_TIMELINE)
	_progress.resize(P_SIZE)


func _size_bytes() -> void:
	"""Size the per-slot byte columns."""
	phase.resize(Rules.MAX_TUNNELS)
	pause_reason.resize(Rules.MAX_TUNNELS)
	bore.resize(Rules.MAX_TUNNELS)
	braced.resize(Rules.MAX_TUNNELS)
	lit.resize(Rules.MAX_TUNNELS)
	closed.resize(Rules.MAX_TUNNELS)


func _size_ints() -> void:
	"""Size the per-slot integer columns."""
	generation.resize(Rules.MAX_TUNNELS)
	digger.resize(Rules.MAX_TUNNELS)
	digger.fill(-1)
	point_count.resize(Rules.MAX_TUNNELS)
	length_u.resize(Rules.MAX_TUNNELS)
	cost_u.resize(Rules.MAX_TUNNELS)
	quanta.resize(Rules.MAX_TUNNELS)
	rate_permille.resize(Rules.MAX_TUNNELS)
	rate_permille.fill(Rules.PERMILLE)
	closed_from_u.resize(Rules.MAX_TUNNELS)
	closed_to_u.resize(Rules.MAX_TUNNELS)
	dig_usec.resize(Rules.MAX_TUNNELS)
	dig_rem.resize(Rules.MAX_TUNNELS)
	extra_spoil.resize(Rules.MAX_TUNNELS)


func set_ground(value: GroundScript) -> void:
	"""The ground new tunnels are dug through (null: all loam)."""
	ground = value


func has_room() -> bool:
	"""Whether a slot is free for another tunnel."""
	return phase.has(PHASE_FREE)


func add_into(route_u: PackedInt32Array, count: int, digger_index: int, out_ref: PackedInt32Array) -> bool:
	"""Store a route -- `count` (x, z) points in u, already validated (tunnel_rules.validate_route) --
	as a tunnel `digger_index` is to dig, and write its (slot, generation) into out_ref[0..1]. Refuses
	(false, nothing stored) with no free slot, a point count out of 2..MAX_POINTS, or a route shorter
	than MIN_LENGTH_U or longer than MAX_LENGTH_U."""
	var slot := phase.find(PHASE_FREE)
	if slot < 0 or count < 2 or count > Rules.MAX_POINTS:
		return false
	var run := Rules.route_length_u(route_u, count)
	if run < Rules.MIN_LENGTH_U or run > Rules.MAX_LENGTH_U:
		return false
	var base := slot * Rules.MAX_POINTS
	for k in count:
		points_u[2 * (base + k)] = route_u[2 * k]
		points_u[2 * (base + k) + 1] = route_u[2 * k + 1]
		cumulative_u[base + k] = Rules.route_length_u(route_u, k + 1)
	_store(slot, run, Rules.route_cost_u(route_u, count), count)
	_set_phase(slot, PHASE_DIGGING, digger_index)
	out_ref[0] = slot
	out_ref[1] = generation[slot]
	return true


func _store(slot: int, run: int, cost: int, count: int) -> void:
	"""A new tunnel's scalars: its point count, length, cost, quanta and timeline, nothing dug, a
	standard unbraced unlit open bore, no heaps placed."""
	point_count[slot] = count
	length_u[slot] = run
	cost_u[slot] = cost
	quanta[slot] = Rules.bore_quanta(run)
	dig_usec[slot] = 0
	dig_rem[slot] = 0
	rate_permille[slot] = Rules.PERMILLE
	extra_spoil[slot] = 0
	bore[slot] = Rules.BORE_STANDARD
	braced[slot] = 0
	lit[slot] = 0
	closed[slot] = CLOSED_NONE
	heap_radius_m[2 * slot] = 0.0
	heap_radius_m[2 * slot + 1] = 0.0
	_lay_timeline(slot)


func _lay_timeline(slot: int) -> void:
	"""Each quantum's ground and end tick (see THE DIG TIMELINE)."""
	var count := timeline_count(slot)
	var run := 0
	for k in count:
		var at := quantum_point_u(slot, k)
		var kind := ground.type_at(at.x, at.y) if ground != null else GroundScript.LOAM
		_q_kind[slot * MAX_TIMELINE + k] = kind
		run += GroundScript.dig_ticks(kind)
		_q_end[slot * MAX_TIMELINE + k] = run


func timeline_count(slot: int) -> int:
	"""How many quanta the tunnel's timeline has: both shafts and the bore."""
	return quanta[slot] + 2 * Rules.SHAFT_QUANTA


func quantum_kind(slot: int, k: int) -> int:
	"""The ground (tunnel_ground.gd type) quantum `k` of the timeline is dug through."""
	return _q_kind[slot * MAX_TIMELINE + k]


func quantum_along_u(slot: int, k: int) -> int:
	"""Where along the route quantum `k` of the timeline lies, in u: 0 for the entrance shaft, the
	length for the exit shaft, and the middle of its metre for a bore quantum."""
	if k < Rules.SHAFT_QUANTA:
		return 0
	if k >= Rules.SHAFT_QUANTA + quanta[slot]:
		return length_u[slot]
	var j := k - Rules.SHAFT_QUANTA
	return (2 * j + 1) * length_u[slot] / (2 * quanta[slot])


func quantum_point_u(slot: int, k: int) -> Vector2i:
	"""Where quantum `k` of the timeline lies, (x, z) in u."""
	return point_at_u(slot, quantum_along_u(slot, k))


func point_at_u(slot: int, along: int) -> Vector2i:
	"""The route point `along` u from the entrance (clamped), (x, z) in u, exact to a unit."""
	var base := slot * Rules.MAX_POINTS
	var a := clampi(along, 0, length_u[slot])
	var k := 1
	while k < point_count[slot] - 1 and a > cumulative_u[base + k]:
		k += 1
	var c0 := cumulative_u[base + k - 1]
	var span := maxi(cumulative_u[base + k] - c0, 1)
	var i0 := 2 * (base + k - 1)
	var dx := points_u[i0 + 2] - points_u[i0]
	var dz := points_u[i0 + 3] - points_u[i0 + 1]
	return Vector2i(points_u[i0] + dx * (a - c0) / span, points_u[i0 + 1] + dz * (a - c0) / span)


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


func is_usable(slot: int) -> bool:
	"""Whether a slot holds a finished tunnel no hazard has closed: one a walker may be routed through."""
	return phase[slot] == PHASE_OPEN and closed[slot] == CLOSED_NONE


func open_count() -> int:
	"""How many tunnels are finished."""
	return phase.count(PHASE_OPEN)


func set_rate(slot: int, permille: int) -> void:
	"""The crew's digging rate on `slot`, per mille of one F1000 worker's (tunnel_crew.gd)."""
	rate_permille[slot] = maxi(permille, 0)


func advance(slot: int, gen: int, usec: int) -> void:
	"""Credit `usec` microseconds of digging, scaled by the slot's rate, to a DIGGING tunnel (others are
	left alone); it opens when the last tick is dug."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING or usec <= 0:
		return
	var work := usec * rate_permille[slot] + dig_rem[slot]
	dig_usec[slot] += work / Rules.PERMILLE
	dig_rem[slot] = work % Rules.PERMILLE
	if done(slot) >= total_ticks(slot):
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


func total_ticks(slot: int) -> int:
	"""Ticks one F1000 worker needs to dig the whole tunnel through its ground."""
	return _q_end[slot * MAX_TIMELINE + timeline_count(slot) - 1]


func done(slot: int) -> int:
	"""Fixed ticks dug so far (F1000-equivalent), capped at the total."""
	return mini(total_ticks(slot), dig_usec[slot] * Rules.TICKS_PER_SECOND / Rules.USEC_PER_SECOND)


func stage(slot: int) -> int:
	"""Rules.STAGE_*: which part is being dug, or STAGE_OPEN."""
	var d := done(slot)
	if d >= total_ticks(slot):
		return Rules.STAGE_OPEN
	if d < _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA - 1]:
		return Rules.STAGE_ENTRANCE
	if d < _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA + quanta[slot] - 1]:
		return Rules.STAGE_BORE
	return Rules.STAGE_EXIT


func percent(slot: int) -> int:
	"""Whole percent dug (floored, so 100 only when it is open)."""
	return done(slot) * 100 / total_ticks(slot)


func progress_into(slot: int, ticks: int, repeat: int, out: PackedInt64Array) -> void:
	"""After `ticks` of work on a pass that digs every timeline quantum `repeat` times over (1: the
	dig; Rules.WIDE_EXTRA_QUANTA: a widening), write into `out` (P_SIZE slots): cuts completed,
	spoil and stone posted (milli-U), the timeline quantum under way and the ticks into its current
	repeat. A quantum's cut completes tunnel_ground.cut_ticks into it; its ground sets its spoil."""
	out.fill(0)
	var start := 0
	for k in timeline_count(slot):
		var kind := _q_kind[slot * MAX_TIMELINE + k]
		var each := GroundScript.dig_ticks(kind)
		var span := each * repeat
		var into := ticks - start
		var whole := clampi(into / each, 0, repeat) if into > 0 else 0
		var cuts := whole + (1 if whole < repeat and into > 0 and into % each >= GroundScript.cut_ticks(kind) else 0)
		out[P_CUTS] += cuts
		out[P_SPOIL] += cuts * GroundScript.spoil_of(kind)
		out[P_STONE] += cuts * GroundScript.stone_of(kind)
		out[P_QUANTUM] = k
		out[P_INTO] = clampi(into - whole * each, 0, each)
		if into < span:
			return
		start += span


func pass_ticks(slot: int, repeat: int) -> int:
	"""Ticks a pass digging every timeline quantum `repeat` times takes one F1000 worker."""
	return total_ticks(slot) * repeat


func spoil_into(slot: int, out: PackedInt64Array) -> void:
	"""Spoil heaped so far, milli-U: out[0] at the entrance, out[1] at the exit. The entrance shaft and
	the bore spoil out of the entrance, the only opening while they are dug; the exit shaft's own
	quantum spoils out of the exit. Re-digging (extra_spoil) heaps at the entrance too."""
	var d := done(slot)
	var bore_end := _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA + quanta[slot] - 1]
	progress_into(slot, mini(d, bore_end), 1, _progress)
	out[0] = _progress[P_SPOIL] + extra_spoil[slot]
	progress_into(slot, d, 1, _progress)
	out[1] = _progress[P_SPOIL] - (out[0] - extra_spoil[slot])


func finished_spoil_into(slot: int, extra_milli_u: int, out: PackedInt64Array) -> void:
	"""The spoil each mouth will have heaped when the tunnel is done, plus `extra_milli_u` more at the
	entrance (a widening accepted): where its heaps are sized for (tunnel_heaps.gd)."""
	var bore_end := _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA + quanta[slot] - 1]
	progress_into(slot, bore_end, 1, _progress)
	out[0] = _progress[P_SPOIL] + extra_spoil[slot] + extra_milli_u
	progress_into(slot, total_ticks(slot), 1, _progress)
	out[1] = _progress[P_SPOIL] - (out[0] - extra_spoil[slot] - extra_milli_u)


func stone_milli_u(slot: int) -> int:
	"""Stone the dig has yielded so far (rock quanta cut), milli-U."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_STONE]


func cut_count(slot: int) -> int:
	"""How many of the dig's quanta have been cut so far."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_CUTS]


func face_quantum(slot: int) -> int:
	"""The timeline quantum the dig is working (the last once it is open)."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_QUANTUM]


func face_u(slot: int) -> int:
	"""How far along the route the dig face has reached, in u: 0 during the entrance shaft, the whole
	length from the exit shaft on, and through the bore by whole quanta and the fraction dug of the
	one under way (exactly the uniform rule when every quantum is loam)."""
	var q := quanta[slot]
	var d := done(slot)
	var shaft := _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA - 1]
	if d <= shaft:
		return 0
	if d >= _q_end[slot * MAX_TIMELINE + Rules.SHAFT_QUANTA + q - 1]:
		return length_u[slot]
	progress_into(slot, d, 1, _progress)
	var j := int(_progress[P_QUANTUM]) - Rules.SHAFT_QUANTA
	var each := GroundScript.dig_ticks(_q_kind[slot * MAX_TIMELINE + _progress[P_QUANTUM]])
	return (j * each + int(_progress[P_INTO])) * length_u[slot] / (q * each)


func face_m(slot: int) -> float:
	"""How far along the route the dig face is, in metres (presentation)."""
	return Rules.to_m(face_u(slot))


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


# --- upgrades and hazards -------------------------------------------------------------------

func set_bore(slot: int, value: int) -> void:
	"""The tunnel's bore class from now on (Rules.BORE_*)."""
	bore[slot] = value
	revision += 1


func set_braced(slot: int) -> void:
	"""Timber support is installed along the whole tunnel."""
	braced[slot] = 1
	revision += 1


func set_lit(slot: int) -> void:
	"""Lanterns hang along the whole tunnel."""
	lit[slot] = 1
	revision += 1


func close(slot: int, reason: int, from_u: int, to_u: int) -> void:
	"""A hazard closes the tunnel (CLOSED_*): nobody is routed through it until it is reopened. A
	collapse closes the section from_u..to_u along it."""
	closed[slot] = reason
	closed_from_u[slot] = from_u
	closed_to_u[slot] = to_u
	revision += 1


func reopen(slot: int) -> void:
	"""The hazard is repaired: the tunnel is open to walkers again."""
	closed[slot] = CLOSED_NONE
	revision += 1


func add_spoil(slot: int, milli_u: int) -> void:
	"""Spoil from re-digging heaped at the entrance."""
	extra_spoil[slot] += milli_u


func speed_permille(slot: int) -> int:
	"""Walking speed in the bore, per mille of walk speed: faster when lit; weather never reaches it."""
	return LIT_SPEED_PERMILLE if lit[slot] == 1 else Rules.PERMILLE


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


func along_of(slot: int, at: Vector2) -> float:
	"""How far along the route (m) its closest point to `at` lies."""
	var best := INF
	var best_along := 0.0
	var base := slot * Rules.MAX_POINTS
	for k in range(1, point_count[slot]):
		var a := point(slot, k - 1)
		var b := point(slot, k)
		var closest := Geometry2D.get_closest_point_to_segment(at, a, b)
		var d := closest.distance_to(at)
		if d < best:
			best = d
			best_along = Rules.to_m(cumulative_u[base + k - 1]) + a.distance_to(closest)
	return best_along


func distance_to_route(slot: int, at: Vector2) -> float:
	"""How far `at` lies from the route's polyline, in metres."""
	return point_at(slot, along_of(slot, at)).distance_to(at)


# --- residents and planning -------------------------------------------------------------------

func set_fit(index: int, fits_bore: bool) -> void:
	"""Record whether resident `index` fits a standard bore, with no body described (setup only: the
	columns grow here)."""
	_grow_residents(index)
	resident_fit[index] = 1 if fits_bore else 0


func set_body(index: int, height_u: int, radius_u: int) -> void:
	"""Record resident `index`'s standing height and body radius in u (setup only): its fit to every
	bore class, loaded or not, is judged from them."""
	_grow_residents(index)
	body_height_u[index] = height_u
	body_radius_u[index] = radius_u
	resident_fit[index] = 1 if Rules.fits_bore(height_u, radius_u) else 0


func _grow_residents(index: int) -> void:
	"""Make room in the resident columns for `index`."""
	if resident_fit.size() > index:
		return
	resident_fit.resize(index + 1)
	body_height_u.resize(index + 1)
	body_radius_u.resize(index + 1)


func fits(index: int) -> bool:
	"""Whether resident `index` fits a standard bore (unknown residents do not)."""
	return index >= 0 and index < resident_fit.size() and resident_fit[index] == 1


func fit_refusal(index: int, slot: int, loaded: bool) -> int:
	"""Rules.FIT_*: how resident `index` (carrying, when `loaded`) fits tunnel `slot`'s bore. A body
	recorded only as yes/no fits exactly the standard bore, loaded or not; an unknown one is too wide."""
	if index < 0 or index >= resident_fit.size():
		return Rules.FIT_TOO_WIDE
	if body_height_u[index] <= 0:
		return Rules.FIT_OK if resident_fit[index] == 1 else Rules.FIT_TOO_WIDE
	var h := body_height_u[index]
	var width := Rules.loaded_width_u(h, body_radius_u[index]) if loaded else 2 * body_radius_u[index]
	return Rules.fit_refusal_in(h, width, bore[slot])


func fits_tunnel(index: int, slot: int, loaded: bool) -> bool:
	"""Whether resident `index` (carrying, when `loaded`) fits tunnel `slot`'s bore."""
	return fit_refusal(index, slot, loaded) == Rules.FIT_OK


func fits_any(index: int, loaded: bool) -> bool:
	"""Whether resident `index` fits any usable tunnel's bore."""
	for slot in Rules.MAX_TUNNELS:
		if is_usable(slot) and fits_tunnel(index, slot, loaded):
			return true
	return false


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
		standing_count: int, out: PackedVector2Array, legs: PackedInt32Array, walker: int = -1,
		loaded: bool = false) -> bool:
	"""Plan from -> to through any usable tunnel whose mouths are free and whose bore resident `walker`
	(carrying, when `loaded`) fits -- every usable tunnel when `walker` is -1 -- round the first
	`standing_count` standing residents in `standing` (tunnel_router.gd). True when a route was found."""
	router.clear_pairs()
	router.surface_permille = surface_permille
	for slot in Rules.MAX_TUNNELS:
		if not is_usable(slot) or mouth_occupied(slot, body, standing, standing_count):
			continue
		if walker >= 0 and not fits_tunnel(walker, slot, loaded):
			continue
		router.add_pair(slot, mouth(slot, false), mouth(slot, true), cost_m(slot) * float(Rules.PERMILLE)
			/ float(speed_permille(slot)), queue.wait_m(2 * slot), queue.wait_m(2 * slot + 1))
	return router.plan(nav, from, to, body, standing, standing_count, revision, out, legs)
