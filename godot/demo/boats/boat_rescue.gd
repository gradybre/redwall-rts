extends RefCounted
## BOAT RESCUE: a boat as one more rescuer rank (decision 0231's note for water part B: "add its responder as another
## RESPONSE_* rank through `reserve`/`release`, rank it with `nearest_capable_into`, and never post per-tick status to
## the feed"). Decision 0432 (live demo). Presentation over the boat rows; nothing writes into the simulation.
##
## WHO AND WHEN (rescue.gd ranks it). A victim at the SURFACE of water a moored boat can row to in a straight leg (the
## pond) may be answered by a boat: its crew is anyone on land free to go who can take a boat's helm (FISH >= 1; the
## fishery's skills). Ranked by route like every rescuer (rescue.gd NEAREST BY ROUTE): the walk to the jetty plus the
## row out, as metres of walking (ROW_WEIGHT). rescue.gd sends the boat in place of a swimmer only when it is the
## nearer way, and in place of a line always; a victim held BELOW needs a diver, so a boat never answers one.
##
## THE RESCUE (BoatRescue, a resident's task): to the jetty, down it into the free boat at its berth (its helm seat),
## rowed straight at the victim; in reach (REACH_M) the victim is hauled aboard (`towed`: in hand, nobody relieves it
## now) and rowed back to the berth, where both step off at the jetty's land end -- the victim ashore there (rescue.gd
## `ashore`, REQ-SET-054's landing). ONE RESPONDER: a rescue whose victim is no longer reserved for it (relieved, or it
## came ashore another way) rows home empty. Out on the water it is held (`water_hold`): no order takes it off the
## boat mid-pond (MOVE-REQ-007); the player's way to stop it is to let the victim be taken over.

const Routes := preload("res://demo/boats/boat_routes.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const TaskBase := preload("res://demo/tunnel/tunnel_task.gd")

## A row counts this many times its straight length against a walk (DEMO: rowing is a little quicker than walking,
## but the boat must be boarded and pushed off first).
const ROW_WEIGHT: float = 1.2
## The serial a rescue takes a boat under: RESCUE_SERIAL + the victim (trips' serials are far below it).
const RESCUE_SERIAL: int = 1000000

var fleet: FleetScript = null
var map: WaterMapScript = null
## `can_helm(who) -> bool`: the fishery's FISH skill gate.
var can_helm: Callable = Callable()


func configure(p_fleet: FleetScript, p_map: WaterMapScript, helm_gate: Callable) -> void:
	"""Rescue with these boats on this water; `helm_gate(who)` says who may take a helm."""
	fleet = p_fleet
	map = p_map
	can_helm = helm_gate


func boat_for(at: Vector2) -> int:
	"""A free boat that can row straight from its berth to `at` (-1: none)."""
	if fleet == null or map == null:
		return -1
	var to: Vector2i = Routes.u_of(at)
	for boat: int in fleet.count:
		if fleet.is_free(boat) and Routes.leg_is_water(map, Routes.BERTH_U[boat], to):
			return boat
	return -1


func may_crew(who: int) -> bool:
	"""Whether `who` may take a boat's helm (rescue.gd checks the rest: on land, free, not the one let go)."""
	return can_helm.is_valid() and bool(can_helm.call(who))


func entry_m() -> Vector2:
	"""Where a crew walks to: the jetty's land end."""
	return Routes.m_of(Routes.JETTY_LAND_U)


func row_cost_m(at: Vector2) -> float:
	"""The row out to `at` from the boat that would go, as metres of walking (ROW_WEIGHT); INF when none can."""
	var boat: int = boat_for(at)
	if boat < 0:
		return INF
	return ROW_WEIGHT * Routes.m_of(Routes.BERTH_U[boat]).distance_to(at)


func make_task(motion: RefCounted, victim: RefCounted, victim_task: RefCounted, on_ashore: Callable) -> TaskBase:
	"""The task that sends a crew out to `victim` (held by `victim_task`) in the boat that can reach it; null when
	none can now."""
	var boat: int = boat_for(victim.get(&"position"))
	if boat < 0 or not fleet.take(boat, RESCUE_SERIAL + int(victim.get(&"index"))):
		return null
	return BoatRescue.new(self, boat, victim, victim_task, on_ashore)


## Out in the boat to the victim, and back to the jetty with it.
class BoatRescue extends "res://demo/tunnel/tunnel_task.gd":
	const PHASE_BOARD: int = 0
	const PHASE_OUT: int = 1
	const PHASE_HAUL: int = 2
	const PHASE_BACK: int = 3
	const PHASE_LAND: int = 4
	const PHASE_DONE: int = 5
	const WORDS: Array[String] = ["boarding a boat for the rescue", "rowing out to the rescue", "hauling them aboard",
		"rowing them back", "landing them", "done"]
	## The victim is in reach of the boat within this (m).
	const REACH_M: float = 1.3
	## Hauling aboard takes this long (s, presentation).
	const HAUL_S: float = 1.5
	## Walking the jetty's deck (m/s; the fishery's).
	const DECK_WALK_M_S: float = 0.6
	var phase: int = PHASE_BOARD
	var boat: int = -1
	var victim: RefCounted = null
	var victim_task: RefCounted = null
	var _owner: RefCounted = null
	var _on_ashore: Callable = Callable()
	var _sub: int = 0
	var _timer: float = 0.0
	var _with_victim: bool = false

	func _init(owner: RefCounted, p_boat: int, the_victim: RefCounted, task: RefCounted, on_ashore: Callable) -> void:
		"""Row boat `p_boat` out to `the_victim` (held by `task`); `on_ashore(victim, [land, water])` lands it."""
		_owner = owner
		boat = p_boat
		victim = the_victim
		victim_task = task
		_on_ashore = on_ashore

	func site(_brain: RefCounted) -> Vector2:
		"""The jetty's land end."""
		return Routes.m_of(Routes.JETTY_LAND_U)

	func arrived(brain: RefCounted) -> void:
		"""At the jetty: on to the boat, held on the water from now on."""
		phase = PHASE_BOARD
		_sub = 0
		brain.water_hold = true

	func _mine(brain: RefCounted) -> bool:
		"""Whether the victim is still this rescuer's (ONE RESPONDER) -- or already in hand."""
		return _with_victim or (victim.get(&"task") == victim_task and int(victim_task.get(&"responder")) == brain.index)

	func step(brain: RefCounted, delta: float) -> bool:
		"""One frame of the boat rescue (rowing home empty once the victim is no longer this rescuer's)."""
		var fleet: FleetScript = _owner.fleet
		if not _mine(brain) and phase < PHASE_BACK:
			_go_home(brain, fleet)
		match phase:
			PHASE_BOARD:
				_board(brain, fleet, delta)
			PHASE_OUT:
				_row_out(brain, fleet)
			PHASE_HAUL:
				_haul(brain, fleet, delta)
			PHASE_BACK:
				_row_back(brain, fleet)
			PHASE_LAND:
				_land(brain, fleet, delta)
		if phase >= PHASE_OUT and phase <= PHASE_BACK:
			brain.water_place(fleet.seat_m(boat, FleetScript.HELM), Routes.JETTY_DECK_Y_M - 0.1, fleet.yaw(boat))
			brain.task_play(&"pull_radish" if fleet.moving(boat) else &"idle")
		return phase != PHASE_DONE

	func _board(brain: RefCounted, fleet: FleetScript, delta: float) -> void:
		"""Down the deck to the berth step, into the helm, and off straight for the victim."""
		var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if _sub == 0 else fleet.seat_m(boat, FleetScript.HELM)
		if not _walk(brain, target, delta):
			return
		_sub += 1
		if _sub < 2:
			return
		fleet.seat(boat, FleetScript.HELM, brain.index)
		var course := PackedInt32Array([Routes.BERTH_U[boat].x, Routes.BERTH_U[boat].y])
		var to: Vector2i = Routes.u_of(victim.get(&"position"))
		course.append_array(PackedInt32Array([to.x, to.y]))
		if fleet.set_course(boat, course, _owner.map) and fleet.set_off(boat):
			phase = PHASE_OUT
		else:
			_go_home(brain, fleet)

	func _row_out(brain: RefCounted, fleet: FleetScript) -> void:
		"""Rowing out; there, the victim in reach is hauled aboard (or, drifted off, the boat comes back for another try)."""
		if fleet.phase[boat] != FleetScript.PHASE_ON_STATION:
			return
		if fleet.position_m(boat).distance_to(victim.get(&"position")) <= REACH_M:
			phase = PHASE_HAUL
			_timer = 0.0
			victim_task.set(&"towed", true)
			_with_victim = true
			return
		_go_home(brain, fleet)

	func _haul(brain: RefCounted, fleet: FleetScript, delta: float) -> void:
		"""The victim hauled over the side into the bow seat, then the row home."""
		_timer += delta
		brain.task_play(&"pull_radish")
		_place_victim(fleet)
		if _timer >= HAUL_S:
			fleet.row_back(boat)
			phase = PHASE_BACK

	func _row_back(brain: RefCounted, fleet: FleetScript) -> void:
		"""Home to the berth, the victim aboard."""
		if _with_victim:
			_place_victim(fleet)
		if fleet.phase[boat] == FleetScript.PHASE_MOORED:
			fleet.seat(boat, FleetScript.HELM, FleetScript.NOBODY)
			phase = PHASE_LAND
			_sub = 0

	func _land(brain: RefCounted, fleet: FleetScript, delta: float) -> void:
		"""Up the deck to the land end, the victim handed over there (rescue.gd `ashore`), the boat free again."""
		var target: Vector2 = Routes.m_of(Routes.BERTH_STEP_U[boat]) if _sub == 0 else Routes.m_of(Routes.JETTY_LAND_U)
		if not _walk(brain, target, delta):
			return
		_sub += 1
		if _sub < 2:
			if _with_victim and _on_ashore.is_valid():
				_on_ashore.call(victim, PackedVector2Array([Routes.m_of(Routes.JETTY_LAND_U), target]))
				_with_victim = false
			return
		brain.water_hold = false
		fleet.give_back(boat, RESCUE_SERIAL + int(victim.get(&"index")))
		phase = PHASE_DONE

	func _place_victim(fleet: FleetScript) -> void:
		"""The victim in the bow seat."""
		victim.call(&"water_place", fleet.seat_m(boat, 1), Routes.JETTY_DECK_Y_M - 0.1, fleet.yaw(boat))
		victim.call(&"water_clip", &"tread_water", 0.3)

	func _go_home(brain: RefCounted, fleet: FleetScript) -> void:
		"""Stand down: the victim left for another rescuer (if still this one's), then row home empty (out on the
		water), or straight back up the jetty (still boarding)."""
		if not _with_victim and victim.get(&"task") == victim_task and int(victim_task.get(&"responder")) == brain.index:
			victim_task.call(&"release", brain.index)
		if phase == PHASE_BOARD:
			phase = PHASE_LAND
			_sub = 1
			return
		fleet.row_back(boat)
		phase = PHASE_BACK

	func _walk(brain: RefCounted, target: Vector2, delta: float) -> bool:
		"""A straight walk on the deck at its height; true once there."""
		var to: Vector2 = target - brain.position
		if to.length() <= 0.05:
			return true
		brain.water_place(brain.position + to.normalized() * minf(DECK_WALK_M_S * delta, to.length()),
			Routes.JETTY_DECK_Y_M, atan2(to.x, to.y))
		brain.task_play(&"walk")
		return false

	func cancel(brain: RefCounted) -> void:
		"""Taken off the task (never out on the water: it is held there) -- on the way to the jetty, or a walk it could
		not finish: the victim left for another rescuer, the boat (not yet boarded) free again."""
		if phase != PHASE_DONE and not _with_victim and int(victim_task.get(&"responder")) == brain.index:
			victim_task.call(&"release", brain.index)
		if phase == PHASE_BOARD:
			var fleet: FleetScript = _owner.fleet
			fleet.seat(boat, FleetScript.HELM, FleetScript.NOBODY)
			fleet.give_back(boat, RESCUE_SERIAL + int(victim.get(&"index")))
		brain.water_hold = false

	func urgent() -> bool:
		"""The water's rescue is never interrupted by bedtime (decision 0210)."""
		return true

	func label() -> String:
		"""In words."""
		return WORDS[phase]
