extends "res://demo/tunnel/tunnel_task.gd"
## One resident's night (night_routine.gd). Decision 0210 (the underground revamp's P4). Presentation only.
##
## HOME TO BED. The resident walks to its home's middle node through the network (resident_brain.gd `order_task`:
## the route goes in at the home's round front door or through the tunnels, whichever is cheaper), strolls across the
## floor to its bedside, and lies down on the bed -- its body's middle on the mattress's, its head to the pillow
## (`task_lie`; the actor seats it by its lowest point, demo_actor.gd). It sleeps until morning (`morning() -> bool`).
## THE ALARM (`alarm() -> bool`: a threat under way) gets it up to stand by its bed until it clears; then it lies down
## again. In the morning it gets up and walks back to the room's middle, and the task ends there: the brain walks it
## out and takes up the job it parked at dusk (RESUMING).
##
## NO BED (REQ-SET-133): it walks to the hall's door and goes in to sleep on the hall's floor (it is not drawn while
## inside), and comes out in the morning. A threat that covers it there sends it away like anyone (tunnel_works.gd
## evacuation), which wakes it.
##
## An order from the player, a release or the water's rescue takes it off the task (`cancel`): it gets up where it
## lies and goes. There is nothing to come back to: at night the routine sends a free resident to bed again.

const BrainScript := preload("res://demo/cast/resident_brain.gd")

const STAGE_GOING: int = 0
const STAGE_TO_BED: int = 1
const STAGE_ASLEEP: int = 2
const STAGE_ROUSED: int = 3
const STAGE_UP: int = 4
## Where a sleeper stands to get into bed and out of it: this far from the bed's middle, off its foot (m) -- the bed
## stands in its alcove foot to the room, so its foot is open floor (a 1.6 m bed's half-length and a step).
const FOOT_M: float = 1.1
## The same off a large bed's foot (decision 0211): its 2.7 m half-length and the same step.
const LARGE_FOOT_M: float = 1.65

var stage: int = STAGE_GOING

var _room_name: String = ""
var _middle_node: int = -1
var _middle: Vector2 = Vector2.ZERO
var _bed: Vector2 = Vector2.ZERO
var _bed_yaw: float = 0.0
var _bed_top_m: float = 0.0
var _foot_m: float = FOOT_M
var _hall: Vector2 = Vector2.ZERO
var _morning: Callable = Callable()
var _alarm: Callable = Callable()


func _init(morning: Callable, alarm: Callable) -> void:
	"""A night that ends when `morning() -> bool` says so, broken while `alarm() -> bool` does."""
	_morning = morning
	_alarm = alarm


func to_bed(room_name: String, middle_node: int, middle: Vector2, bed: Vector2, bed_yaw: float, bed_top_m: float,
		foot_m: float = FOOT_M) -> void:
	"""Sleep in a bed: the home `room_name` whose middle is `middle_node` (at `middle`, m), the bed's middle at `bed`
	(m), turned `bed_yaw` (its pillow toward its -Z), its mattress `bed_top_m` high, its bedside `foot_m` off its
	middle (FOOT_M; a large bed's LARGE_FOOT_M)."""
	_room_name = room_name
	_middle_node = middle_node
	_middle = middle
	_bed = bed
	_bed_yaw = bed_yaw
	_bed_top_m = bed_top_m
	_foot_m = foot_m


func to_hall(door: Vector2) -> void:
	"""Sleep on the hall's floor (no bed), going in at `door` (m)."""
	_middle_node = -1
	_hall = door


func has_bed() -> bool:
	"""Whether this night is spent in a bed (not on the hall's floor)."""
	return _middle_node >= 0


func bedside() -> Vector2:
	"""Where the sleeper stands to get into (and out of) bed: its foot distance off the bed's middle toward its foot
	(its +Z), on the open floor."""
	return _bed + Vector2(sin(_bed_yaw), cos(_bed_yaw)) * _foot_m


func site(_brain: RefCounted) -> Vector2:
	"""The hall's door (a night without a bed)."""
	return _hall


func site_node(_brain: RefCounted) -> int:
	"""The home's middle node (-1 for the hall)."""
	return _middle_node


func arrived(brain: RefCounted) -> void:
	"""Home: across the floor to the bed. At the hall: in, and asleep."""
	var walker := brain as BrainScript
	if has_bed():
		walker.task_hold_below()
		stage = STAGE_TO_BED
		return
	walker.task_go_indoors(true, BrainScript.INTERIOR_HALL)
	walker.task_play(BrainScript.CLIP_IDLE)
	stage = STAGE_ASLEEP


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of the night; false once it is over (morning, and up)."""
	var walker := brain as BrainScript
	if bool(_morning.call()):
		return _get_up(walker, delta)
	if stage == STAGE_TO_BED and walker.task_stroll_to(bedside(), delta):
		_lie(walker)
	elif stage == STAGE_ASLEEP and has_bed() and bool(_alarm.call()):
		walker.task_rise(bedside())
		stage = STAGE_ROUSED
	elif stage == STAGE_ROUSED:
		walker.task_face(_bed, delta)
		if not bool(_alarm.call()):
			_lie(walker)
	return true


func _lie(walker: BrainScript) -> void:
	"""Into bed (see HOME TO BED)."""
	walker.task_lie(_bed, _bed_yaw, _bed_top_m)
	stage = STAGE_ASLEEP


func _get_up(walker: BrainScript, delta: float) -> bool:
	"""Morning: out of bed and back to the room's middle (false once there); out of the hall at once."""
	if not has_bed():
		walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)
		return false
	if walker.lying:
		walker.task_rise(bedside())
	stage = STAGE_UP
	return not walker.task_stroll_to(_middle, delta)


func finish(brain: RefCounted) -> void:
	"""The night is over: up, and out of doors."""
	_wake(brain as BrainScript)


func cancel(brain: RefCounted) -> void:
	"""Woken by an order, a release or the rescue: up where it lies, and out of doors."""
	_wake(brain as BrainScript)


func _wake(walker: BrainScript) -> void:
	"""Stand up (beside the bed) and come out of any building."""
	if walker.lying:
		walker.task_rise(bedside())
	walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine rather than holding (tunnel_task.gd)."""
	return false


func label() -> String:
	"""What the panel says."""
	if not has_bed():
		return "Asleep in the hall (no bed)" if stage == STAGE_ASLEEP else "Going to the hall to sleep (no bed)"
	match stage:
		STAGE_GOING:
			return "Going home to bed (%s)" % _room_name
		STAGE_ASLEEP:
			return "Asleep in %s" % _room_name
		STAGE_ROUSED:
			return "Up by the bed: the alarm"
		STAGE_UP:
			return "Getting up"
	return "Getting into bed"
