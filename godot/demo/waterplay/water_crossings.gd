extends "res://demo/cast/crossing_hook.gd"
## The water's answer to the cast (cast/crossing_hook.gd): which crossings a trip may use, and how a
## resident walks or swims one. Decision 0196 (live demo). Presentation around integer rules.
##
## ---------------------------------------------------------------------------------------
## ROWS. A crossing row is a bridge (rows 0 .. Bridges.MAX_BRIDGES - 1, offered once OPEN) or a swim
## link (water_links.gd, rows from LINK_ROW0). The tunnel router gives crossings their own leg codes
## (tunnel_router.gd CROSSINGS), so a route can mix tunnels, bridges and swims.
##
## WHAT A TRIP IS OFFERED (`offers_for` / `offer_into`). Nothing when the straight line from start to
## goal meets no water (water_map.gd `segment_crosses_water`): a trip in the village plans exactly as
## before. Otherwise every open bridge, walked at the weather's surface pace like any ground; and, for
## a resident that may swim now (swim_state.gd `swim_refusal`: it swims, carries nothing -- LOADS
## CANNOT SWIM, so a carrier walks round, wades the ford or takes a bridge -- consents, and has
## rest >= 4000, HAZ-001), the SWIM_OFFERS links nearest the line whose flow it can hold its line
## against. A link costs its bank walks plus the swim at the speed the swimmer makes good across the
## flow, as metres at its walk speed -- so a swimmer takes a swim only when it is genuinely quicker.
##
## A LEG. A bridge: from the approach onto the deck (its drawn height), along it and off. A swim link:
## down the bank, into the water, across (swim_motion.gd: wading where it can, swimming where it must,
## angling into the flow) and up the far bank. A swimmer that tires mid-swim (HAZ-003's return at rest
## <= 1500, `turn_back`) makes for the nearer bank, and plans again from there -- tired, it is offered
## no swim. A resident in the water given a new order first swims to its nearest connection
## (`swim_ashore`), a leg of its own (ASHORE_ROW).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const LINK_ROW0: int = BridgesScript.MAX_BRIDGES
## The row of a swim to the nearest connection (never offered to a plan).
const ASHORE_ROW: int = 4000
## Swim links offered to one trip, at most.
const SWIM_OFFERS: int = 3
## Climbing in and out of the water costs this much walking on top of the bank walks (m, demo).
const ENTRY_EXIT_M: float = 1.0
## A route's legs are sampled this often for wading water (m).
const WADE_SAMPLE_M: float = 0.5
## Beyond every body's bank: as far from the water as the answer needs to be (m).
const FAR_M: float = 64.0
## Leg phases: onto the crossing, across it, off it.
const PHASE_ON: int = 0
const PHASE_ACROSS: int = 1
const PHASE_OFF: int = 2

var map: WaterMapScript = null
var links: LinksScript = null
var bridges: BridgesScript = null
var state: StateScript = null
var motion: MotionScript = null

var _cast: DemoCastScript = null
var _leg_row: PackedInt32Array = PackedInt32Array()
var _leg_reverse: PackedByteArray = PackedByteArray()
var _leg_phase: PackedByteArray = PackedByteArray()
var _ashore_land: PackedVector2Array = PackedVector2Array()
var _ashore_water: PackedVector2Array = PackedVector2Array()
var _pick_rows: PackedInt32Array = PackedInt32Array()
var _pick_cost: PackedFloat32Array = PackedFloat32Array()
var _pick_count: int = 0
var _pick_key: Array = []
var _near_d: PackedFloat32Array = PackedFloat32Array()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _revision: int = 0


func configure(cast: DemoCastScript, water_map: WaterMapScript, water_links: LinksScript,
		bridge_rows: BridgesScript, swim_state: StateScript, swim_motion: MotionScript) -> void:
	"""Answer for `cast` over these water parts; one leg row per resident."""
	_cast = cast
	map = water_map
	links = water_links
	bridges = bridge_rows
	state = swim_state
	motion = swim_motion
	var n: int = cast.actor_count()
	_leg_row.resize(n)
	_leg_reverse.resize(n)
	_leg_phase.resize(n)
	_ashore_land.resize(n)
	_ashore_water.resize(n)
	_pick_rows.resize(RouterScript.MAX_CROSSING_PAIRS)
	_pick_cost.resize(RouterScript.MAX_CROSSING_PAIRS)
	_near_d.resize(RouterScript.MAX_CROSSING_PAIRS)


func bump() -> void:
	"""What is offered changed (a bridge planned into a row): the router's cache must be dropped."""
	_revision += 1


func revision() -> int:
	"""See crossing_hook.gd."""
	return _revision


# --- planning --------------------------------------------------------------------------------------

func offers_for(walker: int, from: Vector2, to: Vector2, loaded: bool) -> bool:
	"""Whether this trip has a crossing to consider (see WHAT A TRIP IS OFFERED); the pick is kept for
	the `offer_into` that follows."""
	_pick_count = 0
	_pick_key = [walker, from, to, loaded]
	if walker < 0 or not state.has(walker):
		return false
	if not map.segment_crosses_water(MotionScript.u_of(from), MotionScript.u_of(to), 0):
		return false
	_pick_bridges()
	if state.swim_refusal(walker, loaded) == Rules.REFUSE_NONE:
		_pick_links(walker, from, to)
	return _pick_count > 0


func offer_into(router: RefCounted, walker: int, from: Vector2, to: Vector2, loaded: bool) -> void:
	"""Offer the router this trip's pick (made by `offers_for` for the same trip)."""
	if _pick_key != [walker, from, to, loaded]:
		offers_for(walker, from, to, loaded)
	for k: int in _pick_count:
		var row: int = _pick_rows[k]
		(router as RouterScript).add_crossing(row, end_point(row, false), end_point(row, true), _pick_cost[k])


func _pick_bridges() -> void:
	"""Every open bridge, at its walk at the weather's pace."""
	var scale: float = float(Rules.PERMILLE) / float(maxi(_cast.space().tunnels.surface_permille, 1))
	for row: int in BridgesScript.MAX_BRIDGES:
		if bridges.is_open(row) and _pick_count < RouterScript.MAX_CROSSING_PAIRS:
			_pick_rows[_pick_count] = row
			_pick_cost[_pick_count] = bridges.walk_length_m(row) * scale
			_pick_count += 1


func _pick_links(walker: int, from: Vector2, to: Vector2) -> void:
	"""The SWIM_OFFERS links nearest the line from -> to that `walker` can swim, nearest first."""
	var room: int = mini(SWIM_OFFERS, RouterScript.MAX_CROSSING_PAIRS - _pick_count)
	var first: int = _pick_count
	for k: int in links.link_count:
		var cost: float = link_cost_m(walker, k)
		if cost == INF:
			continue
		var d: float = _segment_distance((links.link_water_a[k] + links.link_water_b[k]) * 0.5, from, to)
		_insert_pick(first, room, LINK_ROW0 + k, cost, d)


func _insert_pick(first: int, room: int, row: int, cost: float, d: float) -> void:
	"""Keep the `room` nearest links in picks [first, first + room), sorted by distance `d`."""
	var used: int = _pick_count - first
	var at: int = used
	while at > 0 and _near_d[at - 1] > d:
		at -= 1
	if at >= room:
		return
	var last: int = mini(used, room - 1)
	for k: int in range(last, at, -1):
		_near_d[k] = _near_d[k - 1]
		_pick_rows[first + k] = _pick_rows[first + k - 1]
		_pick_cost[first + k] = _pick_cost[first + k - 1]
	_near_d[at] = d
	_pick_rows[first + at] = row
	_pick_cost[first + at] = cost
	_pick_count = first + mini(used + 1, room)


func link_cost_m(walker: int, k: int) -> float:
	"""What swim link `k` costs `walker`, as metres at its walk speed: the bank walks, climbing in and
	out, and the swim at the speed it makes good across the flow (INF: it cannot hold its line)."""
	var flood_scale: int = Rules.PERMILLE + Rules.FLOOD_FLOW_PERMILLE * motion.flood_permille / Rules.PERMILLE
	var across: int = links.link_flow_across[k] * flood_scale / Rules.PERMILLE
	var ground: int = Rules.ground_speed_mm_s(state.swim_mm_s[walker], across, 0)
	if ground <= 0:
		return INF
	var walk: float = (_cast.actor(walker) as DemoActorScript).brain.walk_speed
	return links.link_bank_m(k) + ENTRY_EXIT_M + links.link_length_m(k) * walk * 1000.0 / float(ground)


func end_point(row: int, far: bool) -> Vector2:
	"""Where crossing `row` is stepped onto (its end b when `far`): a bridge's approach, or a link's
	land end."""
	if row < LINK_ROW0:
		return bridges.approach(row, far)
	var k: int = row - LINK_ROW0
	return links.link_land_b[k] if far else links.link_land_a[k]


# --- legs --------------------------------------------------------------------------------------------

func begin_leg(brain: RefCounted, row: int, reverse: bool) -> void:
	"""Resident `brain` starts across crossing `row` (see A LEG)."""
	var who: int = brain.index
	_leg_row[who] = row
	_leg_reverse[who] = 1 if reverse else 0
	_leg_phase[who] = PHASE_ON


func step_leg(brain: RefCounted, delta: float) -> bool:
	"""One step of `brain`'s leg; true once it stands at the far end."""
	var who: int = brain.index
	var row: int = _leg_row[who]
	if row == ASHORE_ROW:
		return _step_ashore(brain, delta)
	if row < LINK_ROW0:
		return _step_bridge(brain, row, delta)
	return _step_link(brain, row - LINK_ROW0, delta)


func _leg_point(row: int, k: int, reverse: bool) -> Vector2:
	"""Point `k` (0..3) of a leg's path: on-end, across-start, across-end, off-end."""
	var j: int = 3 - k if reverse else k
	if row < LINK_ROW0:
		match j:
			0: return bridges.approach(row, false)
			1: return bridges.deck_end(row, false)
			2: return bridges.deck_end(row, true)
		return bridges.approach(row, true)
	var l: int = row - LINK_ROW0
	match j:
		0: return links.link_land_a[l]
		1: return links.link_water_a[l]
		2: return links.link_water_b[l]
	return links.link_land_b[l]


func _step_bridge(brain: RefCounted, row: int, delta: float) -> bool:
	"""On, along and off a bridge's deck."""
	var who: int = brain.index
	var reverse: bool = _leg_reverse[who] == 1
	if _leg_phase[who] == PHASE_ON:
		if motion.walk_bank(brain, _leg_point(row, 1, reverse), delta):
			_leg_phase[who] = PHASE_ACROSS
		return false
	if _leg_phase[who] == PHASE_OFF:
		return motion.walk_bank(brain, _leg_point(row, 3, reverse), delta)
	var to: Vector2 = _leg_point(row, 2, reverse)
	var step: float = brain.leg_speed() * delta
	var at: Vector2 = brain.position.move_toward(to, step)
	var t: float = clampf(bridges.deck_end(row, false).distance_to(at) / maxf(bridges.deck_end(row, false).distance_to(bridges.deck_end(row, true)), 1e-4), 0.0, 1.0)
	brain.water_place(at, bridges.deck_y_m(row, t), atan2(to.x - brain.position.x, to.y - brain.position.y) if at != to else brain.yaw)
	brain.water_clip(brain.leg_clip(), brain.leg_clip_rate())
	state.set_mode(who, StateScript.MODE_LAND)
	if at.distance_to(to) < 1e-4:
		_leg_phase[who] = PHASE_OFF
	return false


func _step_link(brain: RefCounted, k: int, delta: float) -> bool:
	"""Down the bank, across the water and up the other side."""
	var who: int = brain.index
	var row: int = LINK_ROW0 + k
	var reverse: bool = _leg_reverse[who] == 1
	match _leg_phase[who]:
		PHASE_ON:
			if motion.walk_bank(brain, _leg_point(row, 1, reverse), delta):
				_leg_phase[who] = PHASE_ACROSS
				brain.water_in()
			return false
		PHASE_ACROSS:
			if motion.swim(brain, _leg_point(row, 2, reverse), delta):
				_leg_phase[who] = PHASE_OFF
			return false
	var done: bool = motion.walk_bank(brain, _leg_point(row, 3, reverse), delta)
	if done:
		state.set_mode(who, StateScript.MODE_LAND)
	return done


func _step_ashore(brain: RefCounted, delta: float) -> bool:
	"""Swim to the connection chosen by `swim_ashore`, then up its bank."""
	var who: int = brain.index
	if _leg_phase[who] == PHASE_ACROSS:
		if motion.swim(brain, _ashore_water[who], delta):
			_leg_phase[who] = PHASE_OFF
		return false
	var done: bool = motion.walk_bank(brain, _ashore_land[who], delta)
	if done:
		state.set_mode(who, StateScript.MODE_LAND)
	return done


func abandon_leg(brain: RefCounted) -> void:
	"""Forget `brain`'s leg (an emergency took it off where it is)."""
	_leg_row[brain.index] = -1


func swim_ashore(brain: RefCounted) -> void:
	"""A resident in the water under a new order: swim to the nearest connection of its body and climb
	out there, then carry the order out from the bank (see A LEG)."""
	var who: int = brain.index
	var at: Vector2 = brain.position
	var body: int = 0
	if links.body_at_into(at, _read):
		body = _read.value
	if not links.nearest_connection_into(at, body, _read):
		return
	_ashore_land[who] = links.conn_land[_read.value]
	_ashore_water[who] = links.conn_water[_read.value]
	_leg_row[who] = ASHORE_ROW
	_leg_phase[who] = PHASE_ACROSS
	brain.path.resize(1)
	brain.path[0] = _ashore_land[who]
	brain.path_tunnel.resize(1)
	brain.path_tunnel[0] = RouterScript.crossing_code(ASHORE_ROW, false)
	brain.path_index = 0
	brain.state = BrainScript.State.CROSS


func turn_back(brain: RefCounted) -> bool:
	"""HAZ-003's return for a swimmer tiring on a link: make for the nearer bank and plan again from
	there. True when it turned (it was mid-swim and the start was nearer)."""
	var who: int = brain.index
	var row: int = _leg_row[who]
	if row < LINK_ROW0 or row == ASHORE_ROW or _leg_phase[who] != PHASE_ACROSS:
		return false
	var reverse: bool = _leg_reverse[who] == 1
	var back: Vector2 = _leg_point(row, 1, reverse)
	if brain.position.distance_to(back) >= brain.position.distance_to(_leg_point(row, 2, reverse)):
		return false
	_leg_reverse[who] = 0 if reverse else 1
	_leg_phase[who] = PHASE_ACROSS
	brain.path.resize(brain.path_index + 1)
	brain.path_tunnel.resize(brain.path_index + 1)
	brain.path[brain.path_index] = _leg_point(row, 3, not reverse)
	return true


func leg_text(brain: RefCounted) -> String:
	"""What a resident on a crossing leg is doing, in words."""
	var row: int = _leg_row[brain.index]
	if row == ASHORE_ROW:
		return "swimming ashore"
	if row >= 0 and row < LINK_ROW0:
		return "crossing the %s" % bridges.names[row]
	return StateScript.MODE_WORDS[state.mode[brain.index]]


# --- walking -----------------------------------------------------------------------------------------

func ground_y_m(at: Vector2) -> float:
	"""The carved banks and the ford's bed under a walker (see crossing_hook.gd)."""
	return motion.ground_y_m(at)


func wade_extra_m(a: Vector2, b: Vector2) -> float:
	"""The walk a -> b's extra time in wading water, as metres at walk speed: its wet share (sampled
	every WADE_SAMPLE_M) walked at WADE_PERMILLE instead of full pace. Nothing for a leg that meets no
	water (the map's segment test first, so a dry leg costs one pass over the primitives)."""
	if not map.segment_crosses_water(MotionScript.u_of(a), MotionScript.u_of(b), 0):
		return 0.0
	var length: float = a.distance_to(b)
	var steps: int = maxi(1, ceili(length / WADE_SAMPLE_M))
	var wet: int = 0
	for k: int in steps:
		if map.depth_at(MotionScript.u_of(a.lerp(b, (float(k) + 0.5) / float(steps)))) > 0:
			wet += 1
	return length * float(wet) / float(steps) * (float(Rules.PERMILLE) / float(Rules.WADE_PERMILLE) - 1.0)


func water_clearance_m(at: Vector2) -> float:
	"""How far `at` stands from the waterline (the map's inside margin, negated): no spot a resident is
	sent to is in the water (see crossing_hook.gd STANDING). Far from any water: FAR_M."""
	var u: Vector2i = MotionScript.u_of(at)
	if not map.is_near_water(u):
		return FAR_M
	return -WaterRules.to_m(map.inside_margin_u(u))


func wade_permille(walker: int, at: Vector2) -> int:
	"""Wading water slows a walker to WADE_PERMILLE (and marks it wading); dry ground does not."""
	if not map.is_near_water(MotionScript.u_of(at)) or map.depth_at(MotionScript.u_of(at)) <= 0:
		if state.has(walker) and state.mode[walker] == StateScript.MODE_WADE:
			state.set_mode(walker, StateScript.MODE_LAND)
		return Rules.PERMILLE
	if state.has(walker) and state.mode[walker] == StateScript.MODE_LAND:
		state.set_mode(walker, StateScript.MODE_WADE)
	return Rules.WADE_PERMILLE


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from `p` to the segment a-b."""
	var ab: Vector2 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-9 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
