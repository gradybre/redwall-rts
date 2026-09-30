extends RefCounted
## The tasks of a rescue in the water (rescue.gd dispatches them). Decision 0196 (live demo). No
## combat and no death: a resident in difficulty is held where it is, drifting, until it is brought
## ashore at a bank landing (REQ-SET-054's rescue job "at the ... bank landing point"), where it rests.
##
##   VictimTask   the one in difficulty (HAZ-003 EXHAUSTION): held by the rescue (`water_hold`), at the
##                surface drifting with the flow and treading hard, or -- exhausted below -- held at
##                its depth spending air (HAZ-003: "underwater distress continues consuming air") until
##                a diver fetches it or its air runs out, when it floats up (demo: no one drowns).
##   SwimRescue   a capable swimmer: in at the connection nearest the victim, out to it (a diver fetches
##                one below), and tows it at TOW_PERMILLE of its swim to the landing nearest it.
##   LineRescue   anyone on the bank when no swimmer is free: from the landing nearest the victim, a
##                thrown line that reaches LINE_REACH_M hauls it in at LINE_PULL_M_S; out of reach, the
##                thrower waits, and every RESITE_S walks on to the landing nearest the drifting victim.
##   RestTask     ashore: up the landing's bank and rest (REST_AFTER_RESCUE_TICKS, three times the land
##                recovery), then back to its routine.

const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const Rules := preload("res://demo/waterplay/swim_rules.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")

## A rescuer has the victim within this (m); a towed victim trails this far behind (m).
const REACH_M: float = 0.9
const TOW_BEHIND_M: float = 0.7
## A thrower plays the throw this long before hauling (s).
const THROW_S: float = 1.2
## A thrower waiting with the victim out of reach looks again this often (s).
const RESITE_S: float = 2.0
const CLIP_THROW: StringName = &"wave_one_hand"
const CLIP_HAUL: StringName = &"pull_radish"
const CLIP_REST: StringName = &"stand_and_drink"


## The resident in difficulty (see the header).
class VictimTask extends "res://demo/tunnel/tunnel_task.gd":
	var down_m: float = 0.0
	var towed: bool = false
	var engaged: bool = false
	var waited_s: float = 0.0
	var _motion: MotionScript = null

	func _init(motion: MotionScript, below_m: float) -> void:
		"""In difficulty `below_m` under the surface (0: at it)."""
		_motion = motion
		down_m = below_m

	func arrived(brain: RefCounted) -> void:
		"""Held by the rescue from now on."""
		brain.water_hold = true
		brain.water_in()

	func step(brain: RefCounted, delta: float) -> bool:
		"""Held below spending air, float up when it runs out, else drift at the surface."""
		waited_s += delta
		if towed:
			return true
		var who: int = brain.index
		if down_m > 0.0 and _motion.state.air[who] > 0:
			_motion.state.set_mode(who, StateScript.MODE_DISTRESS_UNDER)
			_motion.dive_to(brain, brain.position, down_m)
			return true
		if down_m > 0.0:
			down_m = maxf(down_m - float(Rules.DIVE_VERTICAL_MM_S) / 1000.0 * delta, 0.0)
			_motion.dive_to(brain, brain.position, down_m)
			return true
		_motion.state.set_mode(who, StateScript.MODE_DISTRESS)
		_motion.drift(brain, delta)
		return true

	func label() -> String:
		"""In words."""
		if towed:
			return "being brought ashore"
		if down_m > 0.0:
			return "in difficulty underwater"
		return "in difficulty — rescue coming" if engaged else "in difficulty — no rescuer free"


## Out to the victim, and tow it to the landing nearest it.
class SwimRescue extends "res://demo/tunnel/tunnel_task.gd":
	const PHASE_DOWN: int = 0
	const PHASE_OUT: int = 1
	const PHASE_FETCH: int = 2
	const PHASE_TOW: int = 3
	const PHASE_UP: int = 4
	const PHASE_DONE: int = 5
	const WORDS: Array[String] = ["going to the rescue", "swimming out to the rescue", "diving to fetch them",
		"towing them ashore", "climbing out", "done"]
	var phase: int = PHASE_DOWN
	var victim: RefCounted = null
	var victim_task: VictimTask = null
	var landing_land: Vector2 = Vector2.ZERO
	var landing_water: Vector2 = Vector2.ZERO
	var _motion: MotionScript = null
	var _in_land: Vector2 = Vector2.ZERO
	var _in_water: Vector2 = Vector2.ZERO
	var _on_ashore: Callable = Callable()
	var _down_m: float = 0.0

	func _init(motion: MotionScript, the_victim: RefCounted, task: VictimTask, entry: PackedVector2Array,
			landing: PackedVector2Array, on_ashore: Callable) -> void:
		"""Rescue `the_victim` (held by `task`): in at `entry` [land, water], ashore at `landing` [land,
		water]; `on_ashore(victim, landing)` takes it over there."""
		_motion = motion
		victim = the_victim
		victim_task = task
		_in_land = entry[0]
		_in_water = entry[1]
		landing_land = landing[0]
		landing_water = landing[1]
		_on_ashore = on_ashore

	func site(_brain: RefCounted) -> Vector2:
		"""The connection nearest the victim."""
		return _in_land

	func arrived(_brain: RefCounted) -> void:
		"""On the bank."""
		phase = PHASE_DOWN

	func step(brain: RefCounted, delta: float) -> bool:
		"""One frame of the rescue."""
		match phase:
			PHASE_DOWN:
				if _motion.walk_bank(brain, _in_water, delta):
					brain.water_in()
					phase = PHASE_OUT
			PHASE_OUT:
				_step_out(brain, delta)
			PHASE_FETCH:
				_step_fetch(brain, delta)
			PHASE_TOW:
				_step_tow(brain, delta)
			PHASE_UP:
				if _motion.walk_bank(brain, landing_land, delta):
					brain.water_out()
					_motion.state.set_mode(brain.index, StateScript.MODE_LAND)
					phase = PHASE_DONE
		return phase != PHASE_DONE

	func _step_out(brain: RefCounted, delta: float) -> void:
		"""Swim to the victim; a diver fetches one below, anyone else waits above it."""
		var reached: bool = _motion.swim(brain, victim.position, delta) or brain.position.distance_to(victim.position) <= REACH_M
		if not reached:
			return
		if victim_task.down_m <= 0.0:
			victim_task.towed = true
			phase = PHASE_TOW
		elif _motion.state.can_dive(brain.index):
			phase = PHASE_FETCH
		else:
			_motion.tread(brain, brain.position, delta)

	func _step_fetch(brain: RefCounted, delta: float) -> void:
		"""Down to the victim, then both up together."""
		var vertical: float = float(Rules.DIVE_VERTICAL_MM_S) / 1000.0 * delta
		_motion.state.set_mode(brain.index, StateScript.MODE_DIVE)
		if _down_m < victim_task.down_m and not victim_task.towed:
			_down_m = minf(_down_m + vertical, victim_task.down_m)
			_motion.dive_to(brain, brain.position, _down_m)
			victim_task.towed = _down_m >= victim_task.down_m
			return
		_down_m = maxf(_down_m - vertical, 0.0)
		victim_task.down_m = _down_m
		_motion.dive_to(brain, brain.position, _down_m)
		_motion.dive_to(victim, victim.position, _down_m)
		if _down_m <= 0.0:
			phase = PHASE_TOW

	func _step_tow(brain: RefCounted, delta: float) -> void:
		"""Tow the victim to the landing's water point, it trailing behind; hand it over there."""
		_motion.state.set_mode(victim.index, StateScript.MODE_TOWED)
		var there: bool = _motion.swim(brain, landing_water, delta, Rules.TOW_PERMILLE)
		var behind: Vector2 = brain.position - Vector2(sin(brain.yaw), cos(brain.yaw)) * TOW_BEHIND_M
		if _motion.map.depth_at(MotionScript.u_of(behind)) <= 0:
			behind = brain.position
		victim.water_place(behind, _motion.surface_y_m(behind), brain.yaw)
		victim.water_clip(MotionScript.CLIP_TREAD, 0.6)
		if there:
			phase = PHASE_UP
			if _on_ashore.is_valid():
				_on_ashore.call(victim, PackedVector2Array([landing_land, landing_water]))

	func cancel(_brain: RefCounted) -> void:
		"""Called away: the victim is left for another rescuer."""
		if phase != PHASE_UP and phase != PHASE_DONE:
			victim_task.engaged = false
			victim_task.towed = false

	func label() -> String:
		"""In words."""
		return WORDS[phase]


## A line thrown from the landing nearest the victim.
class LineRescue extends "res://demo/tunnel/tunnel_task.gd":
	const PHASE_THROW: int = 0
	const PHASE_HAUL: int = 1
	const PHASE_WAIT: int = 2
	const PHASE_DONE: int = 3
	const WORDS: Array[String] = ["throwing a line", "hauling them in on the line",
		"waiting on the bank: the line won't reach", "done"]
	var phase: int = PHASE_THROW
	var victim: RefCounted = null
	var victim_task: VictimTask = null
	var landing_land: Vector2 = Vector2.ZERO
	var landing_water: Vector2 = Vector2.ZERO
	var _motion: MotionScript = null
	var _timer: float = 0.0
	var _on_ashore: Callable = Callable()
	var _landing_for: Callable = Callable()

	func _init(motion: MotionScript, the_victim: RefCounted, task: VictimTask, landing: PackedVector2Array,
			on_ashore: Callable, landing_for: Callable) -> void:
		"""Throw to `the_victim` from `landing` [land, water]; `on_ashore(victim, landing)` takes it;
		`landing_for(at) -> PackedVector2Array` names the landing nearest a point."""
		_motion = motion
		victim = the_victim
		victim_task = task
		landing_land = landing[0]
		landing_water = landing[1]
		_on_ashore = on_ashore
		_landing_for = landing_for

	func site(_brain: RefCounted) -> Vector2:
		"""The landing's land point."""
		return landing_land

	func arrived(_brain: RefCounted) -> void:
		"""On the landing: throw."""
		phase = PHASE_THROW
		_timer = 0.0

	func step(brain: RefCounted, delta: float) -> bool:
		"""Throw, then haul in -- or wait for the victim to come within reach."""
		brain.task_face(victim.position, delta)
		_timer += delta
		match phase:
			PHASE_THROW:
				brain.task_play(CLIP_THROW)
				if _timer >= THROW_S:
					phase = PHASE_HAUL if reaches() else PHASE_WAIT
			PHASE_WAIT:
				brain.task_play(&"idle")
				phase = PHASE_THROW if reaches() else PHASE_WAIT
				if phase == PHASE_WAIT and _timer >= RESITE_S:
					_resite(brain)
			PHASE_HAUL:
				brain.task_play(CLIP_HAUL)
				_haul(delta)
		return phase != PHASE_DONE

	func _resite(brain: RefCounted) -> void:
		"""Walk on to the landing now nearest the drifting victim, if it is another."""
		_timer = 0.0
		var landing: PackedVector2Array = _landing_for.call(victim.position) if _landing_for.is_valid() else PackedVector2Array()
		if landing.size() < 2 or landing[0].distance_to(landing_land) < 0.5:
			return
		landing_land = landing[0]
		landing_water = landing[1]
		brain.task_walk_to(landing_land)

	func reaches() -> bool:
		"""Whether the line reaches the victim at the surface from the landing."""
		return victim_task.down_m <= 0.0 and landing_water.distance_to(victim.position) <= Rules.LINE_REACH_M

	func _haul(delta: float) -> void:
		"""Draw the victim in towards the landing's water point; hand it over there."""
		victim_task.towed = true
		_motion.state.set_mode(victim.index, StateScript.MODE_TOWED)
		var at: Vector2 = victim.position.move_toward(landing_water, Rules.LINE_PULL_M_S * delta)
		victim.water_place(at, _motion.surface_y_m(at), victim.yaw)
		victim.water_clip(MotionScript.CLIP_TREAD, 0.6)
		if at.distance_to(landing_water) < 1e-3:
			phase = PHASE_DONE
			if _on_ashore.is_valid():
				_on_ashore.call(victim, PackedVector2Array([landing_land, landing_water]))

	func cancel(_brain: RefCounted) -> void:
		"""Called away: the victim is left for another rescuer."""
		if phase != PHASE_DONE:
			victim_task.engaged = false
			victim_task.towed = false

	func line_out() -> bool:
		"""Whether the line is out to the victim (drawn by the view)."""
		return phase == PHASE_HAUL

	func label() -> String:
		"""In words."""
		return WORDS[phase]


## Ashore: up the landing and rest.
class RestTask extends "res://demo/tunnel/tunnel_task.gd":
	var _motion: MotionScript = null
	var _land: Vector2 = Vector2.ZERO
	var _up: bool = false
	var _rest_s: float = 0.0

	func _init(motion: MotionScript, land: Vector2) -> void:
		"""Climb out to `land` and rest there."""
		_motion = motion
		_land = land

	func arrived(brain: RefCounted) -> void:
		"""Still held until it is up the bank."""
		brain.water_hold = true

	func step(brain: RefCounted, delta: float) -> bool:
		"""Up the bank, then rest REST_AFTER_RESCUE_TICKS."""
		if not _up:
			_up = _motion.walk_bank(brain, _land, delta)
			if _up:
				brain.water_out()
				brain.water_hold = false
			return true
		_motion.state.set_mode(brain.index, StateScript.MODE_RESTING)
		brain.task_play(CLIP_REST)
		_rest_s += delta
		return _rest_s * float(Rules.TICKS_PER_SECOND) < float(Rules.REST_AFTER_RESCUE_TICKS)

	func finish(brain: RefCounted) -> void:
		"""Rested: back on land, free."""
		_motion.state.set_mode(brain.index, StateScript.MODE_LAND)
		brain.water_hold = false

	func cancel(brain: RefCounted) -> void:
		"""Ordered on before the rest was over."""
		finish(brain)

	func label() -> String:
		"""In words."""
		return "resting after the rescue" if _up else "climbing out, rescued"
