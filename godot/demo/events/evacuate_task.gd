extends "res://demo/tunnel/tunnel_task.gd"
## One resident getting out of a threat's way (demo_events.gd). Decision 0196 (live demo).
## Presentation only.
##
## THROUGH THE NETWORK: walk to the near mouth, go down, walk the network's cheapest way to the far mouth
## (resident_brain.gd `task_tunnel_to`), come up, walk on to the shelter beyond it. ON FOOT: walk straight
## to a shelter outside the disc. Either way it then waits there, facing the threat, until the threat
## clears (`clear() -> bool`), and the task ends: the resident goes back to its own routine -- home, in
## its own time.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const STAGE_TO_MOUTH: int = 0
const STAGE_BELOW: int = 1
const STAGE_TO_SHELTER: int = 2
const STAGE_SHELTERING: int = 3

var stage: int = STAGE_TO_SHELTER
var through_tunnel: bool = false

var _network: GraphScript = null
var _near: int = -1
var _far: int = -1
var _shelter: Vector2 = Vector2.ZERO
var _threat: Vector2 = Vector2.ZERO
var _threat_name: String = ""
var _over: Callable = Callable()


func _init(network: GraphScript, escape: PackedFloat32Array, via_tunnel: bool, shelter: Vector2,
		threat_at: Vector2, threat_name: String, over: Callable) -> void:
	"""Escape through the network as `escape` says (demo_events.plan_escape: the mouth rows in and out, the
	shelter beyond) when `via_tunnel`, else on foot to `shelter`; `over() -> bool` says when the threat at
	`threat_at` has cleared."""
	_network = network
	through_tunnel = via_tunnel
	_threat = threat_at
	_threat_name = threat_name
	_over = over
	if via_tunnel:
		_near = int(escape[0])
		_far = int(escape[1])
		_shelter = Vector2(escape[2], escape[3])
		stage = STAGE_TO_MOUTH
	else:
		_shelter = shelter


func site(_brain: RefCounted) -> Vector2:
	"""The near mouth, or the shelter when it goes on foot."""
	return _network.mouth_at(_near) if through_tunnel else _shelter


func arrived(brain: RefCounted) -> void:
	"""At the near mouth: down and through, or on foot when the way has closed. Up at the far mouth: on to the
	shelter. At the shelter: wait."""
	var walker := brain as BrainScript
	if stage == STAGE_TO_MOUTH:
		stage = STAGE_BELOW
		if _network.mouth_usable(_near) and _network.mouth_usable(_far) \
				and walker.task_tunnel_to(_network.mouth_node[_near], _network.mouth_node[_far]):
			return
	if stage == STAGE_BELOW:
		stage = STAGE_TO_SHELTER
		walker.task_walk_to(_shelter)
		return
	stage = STAGE_SHELTERING


func step(brain: RefCounted, delta: float) -> bool:
	"""Shelter, facing the threat, until it clears. False once it has."""
	var walker := brain as BrainScript
	walker.task_face(_threat, delta)
	walker.task_play(BrainScript.CLIP_IDLE)
	return not bool(_over.call())


func label() -> String:
	"""What the panel says."""
	if stage == STAGE_SHELTERING:
		return "Sheltering from the %s" % _threat_name
	return "Evacuating — %s" % _threat_name


func urgent() -> bool:
	"""An evacuation is never interrupted by bedtime (decision 0210)."""
	return true
