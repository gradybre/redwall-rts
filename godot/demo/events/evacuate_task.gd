extends "res://demo/tunnel/tunnel_task.gd"
## One resident getting out of a threat's way (demo_events.gd). Decision 0196 (live demo).
## Presentation only.
##
## THROUGH A TUNNEL: walk to the near mouth, go down, walk the bore to the far mouth, come up, walk
## on to the shelter beyond it. ON FOOT: walk straight to a shelter outside the disc. Either way it
## then waits there, facing the threat, until the threat clears (`clear() -> bool`), and the task
## ends: the resident goes back to its own routine -- home, in its own time.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")

const STAGE_TO_MOUTH: int = 0
const STAGE_BELOW: int = 1
const STAGE_TO_SHELTER: int = 2
const STAGE_SHELTERING: int = 3

var stage: int = STAGE_TO_SHELTER
var through_tunnel: bool = false

var _network: NetworkScript = null
var _slot: int = 0
var _in_at_exit: bool = false
var _shelter: Vector2 = Vector2.ZERO
var _threat: Vector2 = Vector2.ZERO
var _threat_name: String = ""
var _over: Callable = Callable()


func _init(network: NetworkScript, escape: PackedFloat32Array, via_tunnel: bool, shelter: Vector2,
		threat_at: Vector2, threat_name: String, over: Callable) -> void:
	"""Escape through the tunnel in `escape` (demo_events.plan_escape) when `via_tunnel`, else on foot
	to `shelter`; `over() -> bool` says when the threat at `threat_at` has cleared."""
	_network = network
	through_tunnel = via_tunnel
	_threat = threat_at
	_threat_name = threat_name
	_over = over
	if via_tunnel:
		_slot = int(escape[0])
		_in_at_exit = int(escape[1]) == 1
		_shelter = Vector2(escape[2], escape[3])
		stage = STAGE_TO_MOUTH
	else:
		_shelter = shelter


func site(_brain: RefCounted) -> Vector2:
	"""The near mouth, or the shelter when it goes on foot."""
	return _network.mouth(_slot, _in_at_exit) if through_tunnel else _shelter


func arrived(brain: RefCounted) -> void:
	"""At the near mouth: down and through. At the shelter: wait."""
	var walker := brain as BrainScript
	if stage == STAGE_TO_MOUTH and _network.is_usable(_slot):
		stage = STAGE_BELOW
		var length := _network.length_m(_slot)
		walker.task_enter_bore(_slot, length if _in_at_exit else 0.0, 0.0 if _in_at_exit else length)
	elif stage == STAGE_TO_MOUTH:
		stage = STAGE_TO_SHELTER
		walker.task_walk_to(_shelter)
	else:
		stage = STAGE_SHELTERING


func step(brain: RefCounted, delta: float) -> bool:
	"""Come up at the far mouth and walk on; shelter until the threat clears. False once it has."""
	var walker := brain as BrainScript
	if stage == STAGE_BELOW:
		stage = STAGE_TO_SHELTER
		walker.task_surface(_slot, not _in_at_exit)
		walker.task_walk_to(_shelter)
		return true
	walker.task_face(_threat, delta)
	walker.task_play(BrainScript.CLIP_IDLE)
	return not bool(_over.call())


func label() -> String:
	"""What the panel says."""
	if stage == STAGE_SHELTERING:
		return "Sheltering from the %s" % _threat_name
	return "Evacuating — %s" % _threat_name
