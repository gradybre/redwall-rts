extends "res://demo/tunnel/tunnel_task.gd"
## A resident's place in a dig crew (tunnel_crew.gd). Decision 0196 (live demo). Presentation only.
##
## Every member first walks to its own spot beside the entrance and works there as a hand while
## the Foremole digs the entrance shaft. Once the Foremole is down in the bore, a member who fits
## steps to the hole, follows it in and works CREW_GAP_M behind it (further back by its place in the
## crew), finishing what the Foremole cuts. A member who does not fit stays a surface hand. Either way it counts as at its post only once there (tunnel_crew.set_present). The
## place ends when the Foremole's work on the tunnel does (`active` answers false): a member below
## walks out to the nearest mouth, and everyone goes back to their routine.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")

const CREW_GAP_M: float = 0.9
## A member below never stands nearer its mouth than this.
const MIN_ALONG_M: float = 0.5
const HAND_CLIP: StringName = &"collect_object"
## A member this close to the hole steps down it.
const ENTER_REACH_M: float = 0.35

var slot: int = 0

var _crew: CrewScript = null
var _network: NetworkScript = null
var _fits: bool = false
var _hand_spot: Vector2 = Vector2.ZERO
var _active: Callable = Callable()
var _along: Callable = Callable()


func _init(crew: CrewScript, network: NetworkScript, crew_slot: int, fits: bool, hand_spot: Vector2,
		active: Callable, along: Callable) -> void:
	"""A place on tunnel `crew_slot`'s crew for a member who `fits` its bore (or works from
	`hand_spot`). `active(slot) -> bool`: whether the Foremole's work goes on; `along(slot) -> float`:
	where it stands in the bore (0 while it works the entrance)."""
	_crew = crew
	_network = network
	slot = crew_slot
	_fits = fits
	_hand_spot = hand_spot
	_active = active
	_along = along


func site(_brain: RefCounted) -> Vector2:
	"""Its spot beside the entrance."""
	return _hand_spot


func step(brain: RefCounted, delta: float) -> bool:
	"""Keep to its post while the Foremole works (see the header). False when the work is over."""
	var member := brain as BrainScript
	if not bool(_active.call(slot)):
		return false
	var lead_m := float(_along.call(slot))
	if not _fits or (lead_m <= 0.0 and not member.underground):
		member.task_face(_network.mouth(slot, false), delta)
		member.task_play(HAND_CLIP)
		_crew.set_present(member.index, true)
		return true
	var target := maxf(lead_m - CREW_GAP_M * float(_crew.member_rank[member.index] + 1), MIN_ALONG_M)
	if not member.underground:
		_crew.set_present(member.index, false)
		var hole := _network.mouth(slot, false)
		if member.position.distance_to(hole) > ENTER_REACH_M:
			member.task_walk_to(hole)
		else:
			member.task_enter_bore(slot, 0.0, target)
		return true
	member.task_stand_in_bore(slot, target, true)
	member.task_play(member.dig_clip())
	_crew.set_present(member.index, true)
	return true


func finish(brain: RefCounted) -> void:
	"""The work is over: off the crew."""
	_crew.leave((brain as BrainScript).index)


func cancel(brain: RefCounted) -> void:
	"""Called away: off the crew."""
	_crew.leave((brain as BrainScript).index)


func label() -> String:
	"""What the panel says."""
	return "Dig crew" if _fits else "Dig crew — surface hand"
