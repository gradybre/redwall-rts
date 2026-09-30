extends RefCounted
## The water's hazards and their rescue: deterministic, warned, preventable, and never fatal.
## Decision 0196 (live demo). No combat (REQ-SET-053/054, SET-MOVE-001 §1).
##
## WARNED. Every tick's events (swim_state.gd) are read here once: a swimmer TIRED at rest <= 1500
## turns for the bank (HAZ-003's return request: its swim, dive or crossing leg is told to) and the
## feed says so; LOW AIR at <= 450 below is a warning (HAZ-002's advisory); the panels show every
## swimmer's breath and stamina, and the water's cold and flood. PREVENTABLE: entry is refused tired
## (rest < 4000) or without consent, loads cannot swim, a planned dive keeps a 300-tick reserve, and
## bridges and the ford need no swimming at all. DETERMINISTIC: nothing here rolls a die.
##
## IN DIFFICULTY. A swimmer EXHAUSTED in the water (rest 0: HAZ-003 stops self-propelled swimming) is
## taken off whatever it was doing where it is (resident_brain.gd `interrupt_to_task`) and held
## (rescue_tasks.gd VictimTask), with a warning. Then, retried every DISPATCH_S until someone comes:
##   * the nearest resident who may swim now (it swims, rest >= 4000, on land, not held) is sent to
##     swim out and tow it to a bank LANDING (REQ-SET-054: the rescue job is "at the ... bank landing
##     point") -- the nearest it can make headway to against the flow -- a diver fetches one held below;
##   * otherwise the nearest resident on land throws it a line from that landing.
## NEAREST BY ROUTE (playtest 2026-09-29, decision 0205). "Nearest" is the way it would actually go:
## its planned route to where it goes in -- a swimmer's connection (`_entry_for`) plus SWIM_WEIGHT times
## the straight swim on, a thrower's landing -- not the straight line, which the stream can make a long
## way round. The straight walk is a lower bound on the route, so candidates are planned nearest bound
## first, and only while a bound still beats the best route found: usually one plan, once a DISPATCH_S.
## Nobody dies: a victim no one is coming for after WASH_ASHORE_S -- or one a rescuer set off for but has
## not reached after WASH_ASHORE_ENGAGED_S (a rescuer may have far to walk round the village, and the
## victim drifts) -- is carried by the water to the nearest landing ("washed ashore", demo); a rescuer
## still on its way stands down. Ashore, it rests (RestTask) and is free again.

## Routes planned per ranking at most (demo value, 0205): the nearest four by line cover the cast.
const MAX_PLANS: int = 4
const Rules := preload("res://demo/waterplay/swim_rules.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const SwimTaskScript := preload("res://demo/waterplay/swim_task.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")

const DISPATCH_S: float = 1.0
const WASH_ASHORE_S: float = 90.0
const WASH_ASHORE_ENGAGED_S: float = 240.0
## A swim counts this many times its straight length against a walk -- the weighting water_links.gd
## picks a swimmer's way in by, so the ranking and the pick agree.
const SWIM_WEIGHT: float = LinksScript.SWIM_WEIGHT

## Rescues so far (for the panel), and whether a victim is waiting.
var rescued: int = 0
var victims: PackedInt32Array = PackedInt32Array()
## How many routes the last `nearest_free_into` planned (NEAREST BY ROUTE: the bound spares the rest),
## and the way the one it chose would go (m: its route, and a swimmer's weighted swim on; INF when no
## candidate's route could be planned).
var last_plans: int = 0
var last_cost_m: float = INF

var _cast: DemoCastScript = null
var _state: StateScript = null
var _motion: MotionScript = null
var _links: LinksScript = null
var _crossings: CrossingsScript = null
var _map: WaterMapScript = null
var _say: Callable = Callable()
var _victim_task: Array[Tasks.VictimTask] = []
var _dispatch_s: float = 0.0
var _bank: WaterMapScript.Bank = WaterMapScript.Bank.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _conn: IntMath.IntResult = IntMath.IntResult.new()
## Scratch for NEAREST BY ROUTE, one row per candidate (sized at configure): who, where it goes in on
## land, its weighted swim on from there, the lower bound on its cost, and whether it was planned.
var _cand: PackedInt32Array = PackedInt32Array()
var _in_land: PackedVector2Array = PackedVector2Array()
var _swim_cost: PackedFloat32Array = PackedFloat32Array()
var _bound: PackedFloat32Array = PackedFloat32Array()
var _planned: PackedByteArray = PackedByteArray()
var _route: PackedVector2Array = PackedVector2Array()
var _legs: PackedInt32Array = PackedInt32Array()


func configure(cast: DemoCastScript, crossings: CrossingsScript, say: Callable) -> void:
	"""Watch `cast` in the water `crossings` runs; `say(text, warning: bool)` posts to the feed."""
	_cast = cast
	_crossings = crossings
	_state = crossings.state
	_motion = crossings.motion
	_links = crossings.links
	_map = crossings.map
	_say = say
	_victim_task.resize(cast.actor_count())
	_cand.resize(cast.actor_count())
	_in_land.resize(cast.actor_count())
	_swim_cost.resize(cast.actor_count())
	_bound.resize(cast.actor_count())
	_planned.resize(cast.actor_count())


func update(delta_s: float) -> void:
	"""Read the tick's events, and dispatch rescuers (every DISPATCH_S of demo time; newest victim
	first, so one brought ashore -- and struck off -- skips nobody)."""
	for who: int in _state.count:
		var bits: int = _state.take_events(who)
		if bits != 0:
			_on_events(who, bits)
	_dispatch_s += delta_s
	if _dispatch_s < DISPATCH_S:
		return
	_dispatch_s = 0.0
	for k: int in range(victims.size() - 1, -1, -1):
		_look_after(victims[k])


func _on_events(who: int, bits: int) -> void:
	"""A resident's events: exhausted (in difficulty), tired (turn for the bank), low air, air out."""
	var brain: BrainScript = brain_of(who)
	if bits & StateScript.EVENT_EXHAUSTED and brain.in_water and not brain.water_hold:
		start_difficulty(who)
		return
	if bits & StateScript.EVENT_TIRED and brain.in_water and not brain.water_hold:
		_tire(brain)
	if bits & StateScript.EVENT_LOW_AIR and not brain.water_hold:
		_note("%s is low on air (%d): coming up" % [name_of(who), _state.air[who]], true)
	if bits & StateScript.EVENT_AIR_OUT and brain.water_hold:
		_note("%s's air ran out: floating up, unconscious" % name_of(who), true)


func _tire(brain: BrainScript) -> void:
	"""HAZ-003's return request to whatever has the swimmer in the water."""
	var turned: bool = false
	if brain.state == BrainScript.State.CROSS:
		turned = _crossings.turn_back(brain)
	elif brain.task is SwimTaskScript:
		(brain.task as SwimTaskScript).tire(brain)
		turned = true
	elif brain.task is DiveTaskScript:
		(brain.task as DiveTaskScript).tire(brain)
		turned = true
	_note("%s is tiring in the water (stamina %d%%): %s" % [name_of(brain.index), _state.rest_percent(brain.index),
		"making for the bank" if turned else "pressing on to the far bank"], true)


func start_difficulty(who: int) -> void:
	"""`who` is in difficulty: held where it is, a warning posted, and a rescuer looked for at once."""
	var brain: BrainScript = brain_of(who)
	if brain.water_hold:
		return
	var below: float = maxf(_motion.surface_y_m(brain.position) - brain.ground_y_m, 0.0) if brain.in_water else 0.0
	var task := Tasks.VictimTask.new(_motion, below if below > 0.05 else 0.0)
	_victim_task[who] = task
	brain.interrupt_to_task(task)
	if not victims.has(who):
		victims.append(who)
	_note("%s is in difficulty in the %s!" % [name_of(who), _water_name(brain.position)], true)
	_look_after(who)


func _look_after(who: int) -> void:
	"""Send someone to a victim nobody is coming for; wash it ashore when it has waited too long."""
	var task: Tasks.VictimTask = _victim_task[who]
	if task == null or task.towed:
		return
	if task.waited_s >= (WASH_ASHORE_ENGAGED_S if task.engaged else WASH_ASHORE_S):
		_wash_ashore(who)
		return
	if task.engaged:
		return
	var brain: BrainScript = brain_of(who)
	var landing: PackedVector2Array = nearest_landing(brain.position)
	if nearest_free_into(brain.position, who, true, _read):
		var swimmer: int = _read.value
		var entry: PackedVector2Array = _entry_for(brain.position, brain_of(swimmer).surface_point())
		brain_of(swimmer).order_task(Tasks.SwimRescue.new(_motion, brain, task, entry, ashore, tow_landing))
		task.engaged = true
		_note("%s swims out to rescue %s" % [name_of(swimmer), name_of(who)], false)
		return
	if nearest_free_into(brain.position, who, false, _read):
		var thrower: int = _read.value
		brain_of(thrower).order_task(Tasks.LineRescue.new(_motion, brain, task, landing, ashore, nearest_landing))
		task.engaged = true
		_note("No swimmer is free: %s runs to throw %s a line" % [name_of(thrower), name_of(who)], false)


func nearest_free_into(at: Vector2, victim: int, swimmers: bool, out: IntMath.IntResult) -> bool:
	"""The resident who may go to a rescue at `at` (`may_go`) with the shortest way there, into `out`
	(NEAREST BY ROUTE). A candidate whose route cannot be planned counts only when none can, and then
	the one with the least bound goes. At most MAX_PLANS routes are planned a call, nearest bound first,
	so a dispatch with nobody routable cannot plan the whole cast in one frame. Refuses when none may go."""
	var count: int = _gather(at, victim, swimmers)
	last_plans = 0
	last_cost_m = INF
	if count == 0:
		return out.refuse("NO_FREE_RESCUER")
	var best: int = -1
	var best_cost: float = INF
	for n: int in count:
		var k: int = _least_unplanned_bound(count)
		if _bound[k] >= best_cost or last_plans >= MAX_PLANS:
			break
		_planned[k] = 1
		last_plans += 1
		var cost: float = route_cost_m(_cand[k], _in_land[k]) + _swim_cost[k]
		if best < 0 or cost < best_cost:
			best_cost = cost
			best = _cand[k]
	last_cost_m = best_cost
	return out.succeed(best)


func may_go(who: int, victim: int, swimmers: bool) -> bool:
	"""Whether resident `who` may go to `victim`'s rescue: on land, not held or in difficulty, not in a
	tunnel, not already rescuing -- and, for `swimmers`, one who may swim now (HAZ-001)."""
	var brain: BrainScript = brain_of(who)
	if who == victim or brain.in_water or brain.water_hold or brain.underground or _is_rescuing(brain):
		return false
	return not swimmers or _state.swim_refusal(who, false) == Rules.REFUSE_NONE


func _gather(at: Vector2, victim: int, swimmers: bool) -> int:
	"""Fill the NEAREST BY ROUTE rows with everyone who may go: where each goes in (a swimmer's own
	connection, a thrower the landing nearest `at`), its weighted swim on, and its straight-line bound.
	Returns how many rows."""
	var landing: PackedVector2Array = nearest_landing(at)
	var count: int = 0
	for who: int in _cast.actor_count():
		if not may_go(who, victim, swimmers):
			continue
		var from: Vector2 = brain_of(who).surface_point()
		var way: PackedVector2Array = _entry_for(at, from) if swimmers else landing
		_cand[count] = who
		_in_land[count] = way[0]
		_swim_cost[count] = SWIM_WEIGHT * way[1].distance_to(at) if swimmers else 0.0
		_bound[count] = from.distance_to(way[0]) + _swim_cost[count]
		_planned[count] = 0
		count += 1
	return count


func _least_unplanned_bound(count: int) -> int:
	"""The row not yet planned with the least bound (the first of equals, so ties keep cast order)."""
	var best: int = -1
	for k: int in count:
		if _planned[k] == 0 and (best < 0 or _bound[k] < _bound[best]):
			best = k
	return best


func route_cost_m(who: int, to: Vector2) -> float:
	"""How far resident `who` would walk from where it stands on the surface to `to`: the length of the
	route cast_space.plan_path gives it (bridges, the ford and its own swims across included), or INF
	when no route is found."""
	var brain: BrainScript = brain_of(who)
	var from: Vector2 = brain.surface_point()
	var space: CastSpaceScript = _cast.space()
	space.plan_path(brain.index, from, to, brain.radius, _route, _legs, true, false)
	if not space.nav.last_found:
		return INF
	return CastNavScript.path_length(from, _route)


func _is_rescuing(brain: BrainScript) -> bool:
	"""Whether a resident is already on a rescue."""
	return brain.task is Tasks.SwimRescue or brain.task is Tasks.LineRescue


func ashore(victim: RefCounted, landing: PackedVector2Array) -> void:
	"""A victim brought to a landing's water point: it climbs out there and rests."""
	var who: int = victim.index
	victims.erase(who)
	_victim_task[who] = null
	rescued += 1
	(victim as BrainScript).interrupt_to_task(Tasks.RestTask.new(_motion, landing[0]))
	_note("%s is safe ashore at the landing, resting" % name_of(who), false)


func _wash_ashore(who: int) -> void:
	"""The safety net: the water carries a victim nobody reached to the nearest landing."""
	var brain: BrainScript = brain_of(who)
	var landing: PackedVector2Array = nearest_landing(brain.position)
	brain.water_place(landing[1], _motion.surface_y_m(landing[1]), brain.yaw)
	_note("%s washed ashore at the landing, unhurt" % name_of(who), true)
	_stand_down(brain)
	ashore(brain, landing)


func _stand_down(victim: BrainScript) -> void:
	"""Every rescuer still on its way to `victim` (which came ashore another way) goes back to its
	routine -- one already in the water swims ashore (resident_brain.gd `release`)."""
	for who: int in _cast.actor_count():
		var brain: BrainScript = brain_of(who)
		if _is_rescuing(brain) and brain.task.get(&"victim") == victim:
			brain.work_done()


func nearest_landing(at: Vector2) -> PackedVector2Array:
	"""[land, water] of the authored bank landing nearest `at` (REQ-SET-054's landing) whose land point
	is clear to stand on (water_links.gd `landing_ok`), metres."""
	var best: int = 0
	var best_d: float = INF
	for k: int in _map.landing_count():
		var water: Vector2 = _m(_map.landing_water(k))
		if _links.landing_ok[k] == 1 and water.distance_to(at) < best_d:
			best_d = water.distance_to(at)
			best = k
	var land: Vector2 = _m(_map.landing_land(best))
	var water_m: Vector2 = _m(_map.landing_water(best))
	return PackedVector2Array([land, water_m + (water_m - land).normalized() * LinksScript.WATER_INSET_M])


func tow_landing(at: Vector2, tow_mm_s: int) -> PackedVector2Array:
	"""[land, water] of the landing nearest `at` that a tow at `tow_mm_s` makes headway to against the
	flow there (swim_rules.gd `ground_speed_mm_s`); the nearest of all when none can be reached."""
	var flow: Vector2 = _motion.flow_m_s(at) * 1000.0
	var best: int = -1
	var best_d: float = INF
	for k: int in _map.landing_count():
		var water: Vector2 = _m(_map.landing_water(k))
		var dir: Vector2 = (water - at).normalized()
		var along: int = roundi(flow.dot(dir))
		var across: int = roundi(flow.dot(dir.orthogonal()))
		if _links.landing_ok[k] == 1 and Rules.ground_speed_mm_s(tow_mm_s, across, along) > 0 and water.distance_to(at) < best_d:
			best_d = water.distance_to(at)
			best = k
	if best < 0:
		return nearest_landing(at)
	var land: Vector2 = _m(_map.landing_land(best))
	var water_m: Vector2 = _m(_map.landing_water(best))
	return PackedVector2Array([land, water_m + (water_m - land).normalized() * LinksScript.WATER_INSET_M])


func _entry_for(at: Vector2, from: Vector2) -> PackedVector2Array:
	"""[land, water] of the connection best for a rescuer on land at `from` to reach `at` by (where it
	goes in; water_links.gd `connection_for_into`)."""
	if not _links.connection_for_into(at, from, _conn):
		return nearest_landing(at)
	return PackedVector2Array([_links.conn_land[_conn.value], _links.conn_water[_conn.value]])


func victim_task(who: int) -> Tasks.VictimTask:
	"""The task holding a victim (null: not in difficulty)."""
	return _victim_task[who] if who >= 0 and who < _victim_task.size() else null


func line_of(brain: BrainScript) -> Tasks.LineRescue:
	"""The line a thrower has out (null: none)."""
	var task: Tasks.LineRescue = brain.task as Tasks.LineRescue if brain.task is Tasks.LineRescue else null
	return task if task != null and task.line_out() else null


func _water_name(at: Vector2) -> String:
	"""'stream' or 'pond' for a point in the water."""
	if _map.body_at_into(MotionScript.u_of(at), _read):
		return String(_map.body_name(_read.value))
	return "water"


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name for the feed."""
	return (_cast.actor(who) as DemoActorScript).display_name


func _note(text: String, warning: bool) -> void:
	"""Post to the feed."""
	if _say.is_valid():
		_say.call(text, warning)


static func _m(at_u: Vector2i) -> Vector2:
	"""An integer point as metres."""
	return Vector2(WaterRules.to_m(at_u.x), WaterRules.to_m(at_u.y))
