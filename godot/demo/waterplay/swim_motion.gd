extends RefCounted
## How a resident moves in and by the water, frame by frame. Decision 0196 (live demo). Presentation:
## positions and heights are float metres the actor draws; what the water does to the resident this
## tick (swim_state.gd MODE_*) and the stamina a swimming tick costs are set here, as integers, for the
## fixed-tick owner to apply.
##
##   walk_bank   on land and in the shallows: the walk (or carry) at the leg's pace, slowed to
##               WADE_PERMILLE in wading water, the feet on the carved ground or the bed.
##   swim        towards a point: in water the body wades (depth <= its wade depth, water_rules.gd)
##               it wades; deeper it swims at the water's SURFACE (decision 0203: a swim clip's root
##               is at the waterline) with the swim clip, angling into the flow to hold its line
##               (swim_rules.gd `ground_speed_mm_s`) -- or, where the flow across is too strong to
##               hold, swept along by it.
##   tread       holding a point in deep water with the tread-water clip, against the flow.
##   drift       in difficulty: carried by the flow (never onto dry land), treading hard.
## The stream's surface rises with a flood (demo_water.gd `flood_rise_m`), and so do its swimmers.

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const CLIP_WALK: StringName = &"walk"
const CLIP_SWIM: StringName = &"swim"
const CLIP_TREAD: StringName = &"tread_water"
const CLIP_DIVE: StringName = &"dive"
## A swimmer is where it swam to within this.
const REACH_M: float = 0.08
## Treading hard in difficulty.
const DRIFT_CLIP_RATE: float = 1.6
## A swimmer's clip rate at its stroke's own speed (times swim_rules.stroke_rate), and the least it plays at.
const SWIM_CLIP_RATE: float = 1.0
const MIN_CLIP_RATE: float = 0.4

var map: WaterMapScript = null
var state: StateScript = null
## Of a full flood, per mille (0..1000), and how far the stream's surface stands above its level.
var flood_permille: int = 0
var flood_rise_m: float = 0.0
## Whether the water is cold today (swim_rules.gd `cold_water`).
var cold: bool = false

var _body: IntMath.IntResult = IntMath.IntResult.new()


func configure(water_map: WaterMapScript, swim_state: StateScript) -> void:
	"""Move residents in `water_map`, recording what the water does to them in `swim_state`."""
	map = water_map
	state = swim_state


static func u_of(at: Vector2) -> Vector2i:
	"""A metre point as integer u (the import boundary)."""
	return Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.y))


func surface_y_m(at: Vector2) -> float:
	"""The water's surface height at `at` (its body's level, raised by a flood on the stream); the
	datum's own level where there is no water."""
	if not map.body_at_into(u_of(at), _body):
		return 0.0
	var level: float = -WaterRules.to_m(map.body_level_drop_u(_body.value))
	if map.body_kind(_body.value) == WaterMapScript.KIND_STREAM:
		level += flood_rise_m
	return level


func ground_y_m(at: Vector2) -> float:
	"""The carved ground (or the bed, under water) at `at`."""
	var u: Vector2i = u_of(at)
	if not map.is_near_water(u):
		return 0.0
	return WaterRules.to_m(map.ground_height_at(u))


func flow_m_s(at: Vector2) -> Vector2:
	"""The flow at `at` in m/s, sped by a flood."""
	var flow: Vector2i = map.flow_at(u_of(at))
	@warning_ignore("integer_division") var factor: float = float(Rules.PERMILLE + Rules.FLOOD_FLOW_PERMILLE * flood_permille / Rules.PERMILLE) / float(Rules.PERMILLE)
	return Vector2(flow) * factor / float(Rules.UNITS_PER_M)


func zone_for(who: int, at: Vector2) -> int:
	"""WaterRules.ZONE_* at `at` for resident `who`'s own height."""
	return WaterRules.zone_for_depth(map.depth_at(u_of(at)), state.height_u[who])


func walk_bank(brain: RefCounted, target: Vector2, delta: float) -> bool:
	"""Walk towards `target` on land or in the shallows (see the header); true once there."""
	var who: int = brain.index
	var at: Vector2 = brain.position
	var wet: bool = map.depth_at(u_of(at)) > 0
	var pace: float = brain.leg_speed() * (float(Rules.WADE_PERMILLE) / float(Rules.PERMILLE) if wet else 1.0)
	var to: Vector2 = target - at
	var arrived: bool = to.length() <= pace * delta + 1e-4
	var next: Vector2 = target if arrived else at + to.normalized() * pace * delta
	var face: float = brain.yaw if to.length() < 1e-4 else atan2(to.x, to.y)
	brain.water_place(next, ground_y_m(next), face)
	brain.water_clip(brain.leg_clip(), maxf(brain.leg_clip_rate() * (pace / maxf(brain.leg_speed(), 1e-4)), MIN_CLIP_RATE))
	state.set_mode(who, StateScript.MODE_WADE if wet else StateScript.MODE_LAND)
	return arrived


func swim(brain: RefCounted, target: Vector2, delta: float, speed_permille: int = Rules.PERMILLE) -> bool:
	"""Swim towards `target` at `speed_permille` of this swimmer's own speed (see the header); true
	once there. In water it can wade, it wades."""
	var who: int = brain.index
	var at: Vector2 = brain.position
	if zone_for(who, at) <= WaterRules.ZONE_WADE:
		return walk_bank(brain, target, delta)
	@warning_ignore("integer_division") var s_mm: int = state.swim_mm_s[who] * speed_permille / Rules.PERMILLE
	var s: float = float(s_mm) / 1000.0
	var rate: float = maxf(SWIM_CLIP_RATE * Rules.stroke_rate(s_mm, state.stroke_mm_s[who]), MIN_CLIP_RATE)
	var flow: Vector2 = flow_m_s(at)
	var to: Vector2 = target - at
	var distance: float = to.length()
	if distance <= REACH_M:
		_float_at(brain, at, brain.yaw, CLIP_SWIM, rate)
		return true
	var dir: Vector2 = to / distance
	var heading: Vector2 = ferry_heading(dir, flow, s)
	var ground: Vector2 = heading * s + flow
	var along: float = ground.dot(dir)
	var next: Vector2 = target if along * delta >= distance else _keep_wet(at, at + ground * delta)
	_float_at(brain, next, atan2(heading.x, heading.y), CLIP_SWIM, rate)
	_set_drain(who, flow)
	state.set_mode(who, StateScript.MODE_SWIM)
	return along * delta >= distance


static func ferry_heading(dir: Vector2, flow: Vector2, speed: float) -> Vector2:
	"""The unit heading a swimmer of `speed` takes to make good along `dir` in `flow`: into the flow's
	across part, so the two sum along `dir`; straight at `dir` when it cannot (then it is swept)."""
	var across: Vector2 = flow - dir * flow.dot(dir)
	var left: float = speed * speed - across.length_squared()
	if speed <= 0.0 or left <= 0.0:
		return dir
	return (dir * sqrt(left) - across) / speed


func tread(brain: RefCounted, hold: Vector2, delta: float) -> void:
	"""Hold `hold` in deep water, treading, against the flow (swept if it is too strong)."""
	var who: int = brain.index
	var flow: Vector2 = flow_m_s(brain.position)
	var s: float = float(state.swim_mm_s[who]) / 1000.0
	var at: Vector2 = hold if s > flow.length() else _keep_wet(brain.position, brain.position + flow * delta)
	_float_at(brain, at, brain.yaw, CLIP_TREAD, SWIM_CLIP_RATE)
	_set_drain(who, flow)
	state.set_mode(who, StateScript.MODE_TREAD)


func drift(brain: RefCounted, delta: float) -> void:
	"""Carried by the flow, never onto dry land, treading hard (the mode is the caller's)."""
	var at: Vector2 = _keep_wet(brain.position, brain.position + flow_m_s(brain.position) * delta)
	_float_at(brain, at, brain.yaw, CLIP_TREAD, DRIFT_CLIP_RATE)


func dive_to(brain: RefCounted, spot: Vector2, down_m: float) -> void:
	"""Hang `down_m` below the surface at `spot` in the dive pose (the mode is the caller's)."""
	var y: float = surface_y_m(spot) - down_m
	brain.water_place(spot, y, brain.yaw)
	brain.water_clip(CLIP_DIVE, SWIM_CLIP_RATE)


func max_dive_m(who: int, spot: Vector2) -> float:
	"""How far below the surface `who` may take its root at `spot`: the depth less its own height's
	share the dive clip holds below the root, and DIVE_FLOOR_CLEAR_M above the bed (0: not at all)."""
	var depth: float = WaterRules.to_m(map.depth_at(u_of(spot)))
	return maxf(depth - WaterRules.to_m(state.height_u[who]) * 0.5 - Rules.DIVE_FLOOR_CLEAR_M, 0.0)


func _float_at(brain: RefCounted, at: Vector2, face: float, clip: StringName, rate: float) -> void:
	"""Place a swimmer at the surface at `at`, facing `face`, playing `clip`."""
	brain.water_place(at, surface_y_m(at), face)
	brain.water_clip(clip, rate)


func _keep_wet(from: Vector2, to: Vector2) -> Vector2:
	"""`to`, unless it is dry ground -- then `from` (a swimmer is never swept onto land)."""
	return to if map.depth_at(u_of(to)) > 0 else from


func _set_drain(who: int, flow: Vector2) -> void:
	"""What a swimming tick costs `who` now: cold and the flow (swim_rules.gd)."""
	state.drain[who] = Rules.rest_drain_per_tick(state.swim_mm_s[who], roundi(flow.length() * 1000.0), cold)
