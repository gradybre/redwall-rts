extends RefCounted
## A RESCUE's own incident card: who is in difficulty, who is answering, the landing they are bound for, the phase,
## and an approximate time to safety -- or the blockage, said plainly (review P5's water-safety detail: "one persistent
## incident card owns victim, responder, landing, phase, approximate ETA or explicit blockage, and center/select
## actions"). Decision 0461. Presentation only: every figure is read from the rescue (rescue.gd, rescue_tasks.gd) and
## the swimmers' rows (swim_state.gd); nothing here sends or recalls anybody.
##
## The rescue already keeps ONE incident per victim ("water:rescue:<who>", demo_waterplay.gd RESCUE INCIDENTS), queued
## on the top-centre card until it is over; this fills that card's details (demo_incident_cards.gd `add_details`). It is
## read on real time, so it reads the same while the village is paused (nothing moves, so nothing changes).
##
## THE TIME is approximate and says so: what is left of the rescuer's walk to the water at its walking pace, the swim
## out at its swim speed, a fetch from below at the dive's vertical speed both ways, and the tow to the landing at
## TOW_PERMILLE of its swim -- the flow, which helps or hinders, is left out. A line: the walk, the throw, and the haul
## at LINE_PULL_M_S. A BOAT (water part B's RESPONSE_BOAT, decision 0432): the walk to the jetty, the row out at the
## boat's speed, the row back to its berth, the victim landed at the jetty's land end. With nobody answering, or a line that will not reach, or a swimmer treading above one it cannot
## fetch, there is no time: the BLOCKAGE is said instead, with when the water's safety net brings it ashore.

const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const StateScript := preload("res://demo/waterplay/swim_state.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CardsScript := preload("res://demo/ui/demo_incident_cards.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const BoatRescueScript := preload("res://demo/boats/boat_rescue.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const BoatRoutes := preload("res://demo/boats/boat_routes.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

## The rescue incidents' key (demo_waterplay.gd RESCUE_KEY's prefix).
const KEY_PREFIX: String = "water:rescue:"
const NOBODY_PHASE: String = "Needs a rescuer"
const NOBODY_BLOCK: String = "Blocked: no capable rescuer free — the water brings them ashore in about %d s"
const LINE_BLOCK: String = "Blocked: the line won't reach yet — the thrower waits for the drift, or a swimmer to come free"
const WATCH_BLOCK: String = "Blocked: no diver with the air free — the swimmer above tows them the moment they float up (about %d s)"
const ETA: String = "safe ashore in about %d s at 1× (approximate: the flow is not counted)"
const APPROACH: String = "on the way to the water"
## A boat rescue's phase words (boat_rescue.gd BoatRescue PHASE_*).
const BOAT_PHASES: Array[String] = ["by boat: boarding at the jetty", "by boat: rowing out", "by boat: hauling them aboard",
	"by boat: rowing back to the jetty", "by boat: landing at the jetty", "by boat: ashore"]
## The residents' targets carry their names (decision 0491): "Victim: Tobit Highbough ▸".
const VICTIM: String = "Victim: %s ▸"
const RESPONDER: String = "Responder: %s ▸"
const LANDING: String = "Landing ▸"

## One card's details (the caller's, reused).
class Details:
	extends RefCounted
	var victim: int = -1
	var responder: int = -1
	var landing: Vector2 = Vector2.INF
	var phase: String = ""
	var time: String = ""


var _rescue: RescueScript = null
var _state: StateScript = null
var _cast: DemoCastScript = null
var _details: Details = Details.new()


func configure(rescue: RescueScript, state: StateScript, cast: DemoCastScript) -> void:
	"""Read this rescue, these swimmers and this cast."""
	_rescue = rescue
	_state = state
	_cast = cast


static func victim_of(key: String) -> int:
	"""The victim a rescue incident's key names (-1: not a rescue's key)."""
	if not key.begins_with(KEY_PREFIX):
		return -1
	var rest: String = key.substr(KEY_PREFIX.length())
	return int(rest) if rest.is_valid_int() else -1


func details_into(key: String, out: Details) -> bool:
	"""The card's details for incident `key` into `out`; false when it is not a rescue still under way."""
	var who: int = victim_of(key)
	var task: Tasks.VictimTask = _rescue.victim_task(who) if who >= 0 else null
	if task == null or not _rescue.victims.has(who):
		return false
	out.victim = who
	out.responder = task.responder
	out.landing = Vector2.INF
	out.time = ""
	if not task.engaged:
		out.phase = NOBODY_PHASE
		out.time = NOBODY_BLOCK % maxi(ceili(RescueScript.WASH_ASHORE_S - task.waited_s), 0)
		out.landing = _rescue.nearest_landing(brain_of(who).position)[0]
		return true
	var rescuer: BrainScript = brain_of(task.responder)
	out.phase = "%s: %s" % [name_of(task.responder), rescuer.task_label() if rescuer.state == BrainScript.State.TASK else APPROACH]
	if rescuer.task is BoatRescueScript.BoatRescue:
		_boat_into(rescuer, rescuer.task as BoatRescueScript.BoatRescue, out)
	elif rescuer.task is Tasks.LineRescue:
		_line_into(rescuer, rescuer.task as Tasks.LineRescue, out)
	elif rescuer.task is Tasks.SwimRescue:
		_swim_into(rescuer, rescuer.task as Tasks.SwimRescue, task, out)
	return true


func card_into(key: String, out: CardsScript.Extra) -> bool:
	"""The incident card's details (demo_incident_cards.gd DETAILS) for rescue incident `key`: the phase, the time or
	the blockage, and Victim / Responder / Landing to select and centre. False when it is no rescue under way."""
	if not details_into(key, _details):
		return false
	out.lines.append(_details.phase)
	if not _details.time.is_empty():
		out.lines.append(_details.time)
	out.add_target(VICTIM % name_of(_details.victim), NoticesScript.TARGET_RESIDENT, _details.victim, Vector2.ZERO)
	if _details.responder >= 0:
		out.add_target(RESPONDER % name_of(_details.responder), NoticesScript.TARGET_RESIDENT, _details.responder,
			Vector2.ZERO)
	if _details.landing.is_finite():
		out.add_target(LANDING, NoticesScript.TARGET_NONE, -1, _details.landing)
	return true


func _line_into(rescuer: BrainScript, line: Tasks.LineRescue, out: Details) -> void:
	"""A line from a landing: the walk there, the throw and the haul -- or the line that will not reach."""
	out.landing = line.landing_land
	if rescuer.state == BrainScript.State.TASK and line.phase == Tasks.LineRescue.PHASE_WAIT:
		out.time = LINE_BLOCK
		return
	var seconds: float = walk_left_s(rescuer)
	if rescuer.state != BrainScript.State.TASK or line.phase == Tasks.LineRescue.PHASE_THROW:
		seconds += Tasks.THROW_S
	seconds += line.landing_water.distance_to(line.victim.position) / SwimRules.LINE_PULL_M_S
	out.time = ETA % ceili(seconds)


func _swim_into(rescuer: BrainScript, swim: Tasks.SwimRescue, task: Tasks.VictimTask, out: Details) -> void:
	"""A swimmer: the walk to the water, the swim out, a fetch from below, the tow -- or treading above one it cannot
	fetch."""
	var who: int = rescuer.index
	var speed: float = float(_state.swim_mm_s[who]) / 1000.0
	var tow: float = speed * float(SwimRules.TOW_PERMILLE) / float(SwimRules.PERMILLE)
	if speed <= 0.0:
		out.time = ""
		return
	var victim: Vector2 = swim.victim.position
	var towing: bool = rescuer.state == BrainScript.State.TASK and swim.phase >= Tasks.SwimRescue.PHASE_TOW
	out.landing = swim.landing_land if towing else _rescue.tow_landing(victim, roundi(tow * 1000.0))[0]
	if rescuer.state == BrainScript.State.TASK and swim.is_above():
		out.time = WATCH_BLOCK % ceili(_air_s(swim))
		return
	if towing:
		out.time = ETA % ceili(rescuer.position.distance_to(swim.landing_water) / tow)
		return
	var seconds: float = walk_left_s(rescuer) + rescuer.position.distance_to(victim) / speed
	if task.down_m > 0.0:
		seconds += 2.0 * task.down_m * 1000.0 / float(SwimRules.DIVE_VERTICAL_MM_S)
	seconds += victim.distance_to(_rescue.tow_landing(victim, roundi(tow * 1000.0))[1]) / tow
	out.time = ETA % ceili(seconds)


func _boat_into(rescuer: BrainScript, boat: BoatRescueScript.BoatRescue, out: Details) -> void:
	"""A boat: the phase, the jetty it lands them at, and the walk, the row out and the row back at the boat's speed."""
	out.phase = "%s: %s" % [name_of(rescuer.index), BOAT_PHASES[clampi(boat.phase, 0, BOAT_PHASES.size() - 1)]]
	var jetty: Vector2 = BoatRoutes.m_of(BoatRoutes.JETTY_LAND_U)
	out.landing = jetty
	var speed: float = WaterRules.to_m(FleetScript.ROW_SPEED_U_S)
	var fleet: FleetScript = _rescue.boats.fleet if _rescue.boats != null else null
	if speed <= 0.0 or fleet == null or boat.boat < 0:
		return
	var berth: Vector2 = BoatRoutes.m_of(BoatRoutes.BERTH_U[boat.boat])
	var at: Vector2 = fleet.position_m(boat.boat)
	var victim: Vector2 = boat.victim.get(&"position")
	var seconds: float = at.distance_to(berth) / speed
	if boat.phase <= BoatRescueScript.BoatRescue.PHASE_OUT:
		seconds = walk_left_s(rescuer) + (at.distance_to(victim) + victim.distance_to(berth)) / speed
	out.time = ETA % ceili(seconds)


func _air_s(swim: Tasks.SwimRescue) -> float:
	"""The victim's air left, in demo seconds below."""
	var victim: BrainScript = swim.victim as BrainScript
	return float(_state.air[victim.index]) / float(SwimRules.TICKS_PER_SECOND)


static func walk_left_s(brain: BrainScript) -> float:
	"""What is left of a walker's route at its walking pace (0 once it is at its task)."""
	if brain.state == BrainScript.State.TASK:
		return 0.0
	var total: float = 0.0
	var at: Vector2 = brain.position
	for k: int in range(brain.path_index, brain.path.size()):
		total += at.distance_to(brain.path[k])
		at = brain.path[k]
	return total / maxf(brain.walk_speed, 0.01)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name
