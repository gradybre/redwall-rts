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
## Nobody dies: a victim no one is coming for after WASH_ASHORE_S -- or one a rescuer set off for but has
## not reached after WASH_ASHORE_ENGAGED_S (a rescuer may have far to walk round the village, and the
## victim drifts) -- is carried by the water to the nearest landing ("washed ashore", demo); a rescuer
## still on its way stands down. Ashore, it rests (RestTask) and is free again.

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

const DISPATCH_S: float = 1.0
const WASH_ASHORE_S: float = 90.0
const WASH_ASHORE_ENGAGED_S: float = 240.0

## Rescues so far (for the panel), and whether a victim is waiting.
var rescued: int = 0
var victims: PackedInt32Array = PackedInt32Array()

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
	"""The resident nearest `at` who may go to a rescue, into `out`: on land, not held or in difficulty,
	not in a tunnel -- and, for `swimmers`, one who may swim now (HAZ-001). Refuses when none may."""
	var best_d: float = INF
	for who: int in _cast.actor_count():
		var brain: BrainScript = brain_of(who)
		if who == victim or brain.in_water or brain.water_hold or brain.underground or _is_rescuing(brain):
			continue
		if swimmers and _state.swim_refusal(who, false) != Rules.REFUSE_NONE:
			continue
		var d: float = brain.surface_point().distance_to(at)
		if d < best_d:
			best_d = d
			out.value = who
	if best_d == INF:
		return out.refuse("NO_FREE_RESCUER")
	return out.succeed(out.value)


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
			brain.release()


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
	if not _links.connection_for_into(at, from, _read):
		return nearest_landing(at)
	return PackedVector2Array([_links.conn_land[_read.value], _links.conn_water[_read.value]])


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
