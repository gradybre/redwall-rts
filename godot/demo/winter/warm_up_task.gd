extends "res://demo/tunnel/tunnel_task.gd"
## A CHILLED resident's WARM-UP BREAK at a heated hearth (Brendan's ruling 1). Decision 0571. Presentation only.
##
## TO A HOME: the resident walks to the home's middle node through the network (as the night's sleep task does: the
## route goes in at its front door or through the tunnels), strolls to the hearth's side and stands facing the fire.
## TO THE HALL: it walks to the hall's door and goes in (it is not drawn inside), as a bedless sleeper does.
## It stays until it is WARMED THROUGH (`warmed() -> bool`: its exposure back to 0, cold_exposure.gd) -- then it comes
## out (a home: back to the room's middle; the hall: out of the door) and the task ends, and the brain takes up the job
## it parked (resident_brain.gd RESUMING). It also ends as soon as the place stops being heated (`heated() -> bool`: its
## hearth ran out of fuel): there is no warmth left to wait for.
##
## Dusk takes it to bed like anyone (it is not `urgent`): a heated home's bed clears exposure as well. An order, a release
## or the water's rescue takes it off the task as any task.

const BrainScript := preload("res://demo/cast/resident_brain.gd")

const STAGE_GOING: int = 0
const STAGE_TO_FIRE: int = 1
const STAGE_WARMING: int = 2
const STAGE_UP: int = 3

var stage: int = STAGE_GOING
## The hearth source it warms at (hearth_fuel.gd row: a home's room row, or HALL).
var source: int = -1

var _place_name: String = ""
var _middle_node: int = -1
var _middle: Vector2 = Vector2.ZERO
var _fire_side: Vector2 = Vector2.ZERO
var _fire: Vector2 = Vector2.ZERO
var _door: Vector2 = Vector2.ZERO
var _warmed: Callable = Callable()
var _heated: Callable = Callable()


func _init(warmed: Callable, heated: Callable) -> void:
	"""A break that ends when `warmed() -> bool` says so, or once `heated() -> bool` stops saying so."""
	_warmed = warmed
	_heated = heated


func to_home(p_source: int, place_name: String, middle_node: int, middle: Vector2, fire_side: Vector2,
		fire: Vector2) -> void:
	"""Warm up in a home: its row `p_source`, its name, its middle node (at `middle`, m), the spot by the hearth to stand
	at and the fire to face (m)."""
	source = p_source
	_place_name = place_name
	_middle_node = middle_node
	_middle = middle
	_fire_side = fire_side
	_fire = fire


func to_hall(p_source: int, place_name: String, door: Vector2) -> void:
	"""Warm up in the hall (row `p_source`), going in at `door` (m)."""
	source = p_source
	_place_name = place_name
	_middle_node = -1
	_door = door


func in_home() -> bool:
	"""Whether this break is in a home (not the hall)."""
	return _middle_node >= 0


func site(_brain: RefCounted) -> Vector2:
	"""The hall's door (a break in the hall)."""
	return _door


func site_node(_brain: RefCounted) -> int:
	"""The home's middle node (-1 for the hall)."""
	return _middle_node


func arrived(brain: RefCounted) -> void:
	"""In the home: across the floor to the fire. At the hall: in, by its fire."""
	var walker := brain as BrainScript
	if in_home():
		walker.task_hold_below()
		stage = STAGE_TO_FIRE
		return
	walker.task_go_indoors(true, BrainScript.INTERIOR_HALL)
	walker.task_play(BrainScript.CLIP_IDLE)
	stage = STAGE_WARMING


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of the break; false once it is over (warmed through, or the fire gone)."""
	var walker := brain as BrainScript
	if stage != STAGE_GOING and (bool(_warmed.call()) or not bool(_heated.call())):
		return _come_out(walker, delta)
	if stage == STAGE_TO_FIRE and walker.task_stroll_to(_fire_side, delta):
		stage = STAGE_WARMING
	elif stage == STAGE_WARMING and in_home():
		walker.task_face(_fire, delta)
	return true


func _come_out(walker: BrainScript, delta: float) -> bool:
	"""Back to the room's middle (false once there); out of the hall at once."""
	stage = STAGE_UP
	if not in_home():
		walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)
		return false
	return not walker.task_stroll_to(_middle, delta)


func finish(brain: RefCounted) -> void:
	"""The break is over: out of doors."""
	(brain as BrainScript).task_go_indoors(false, BrainScript.INTERIOR_NONE)


func cancel(brain: RefCounted) -> void:
	"""Called away: out of doors."""
	(brain as BrainScript).task_go_indoors(false, BrainScript.INTERIOR_NONE)


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the winter sends it again while a fire burns)."""
	return false


func why() -> String:
	"""Why it is on this break, for the party panel (demo_people.gd `why_of`)."""
	return "Why: Chilled — warming up at a lit hearth until warmed through"


func label() -> String:
	"""What the panel says."""
	match stage:
		STAGE_GOING:
			return "Going to warm up (%s): Chilled" % _place_name
		STAGE_TO_FIRE, STAGE_WARMING:
			return "Warming up by the fire (%s)" % _place_name
	return "Warmed through"
