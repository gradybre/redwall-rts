extends "res://demo/tunnel/tunnel_task.gd"
## One resident's part in the village's meals (kitchen.gd): the COOK's round -- fetching, cooking, carrying the pot to
## the table -- a DRAWER's trip to the well, or a DINER's meal at the table. Decision 0381. Presentation only.
##
## A thin adapter: the kitchen holds every number (what is reserved, carried, cooked and eaten, and how much work is
## done) and decides each next step; this task only lets the brain walk where the kitchen says and stand at the work
## (resident_brain.gd TASKS), and tells the kitchen when it arrives, when it is called away and when it is over. So
## an interruption -- an order, the night, a release -- loses nothing: the kitchen's records stay where they had got
## to, and a cook or a drawer called away keeps its round to come back to (resident_brain.gd RESUMING); a diner does
## not (it is called again while the meal lasts).

const ROLE_COOK: int = 1
const ROLE_DRAW: int = 2
const ROLE_EAT: int = 3
## The kitchen's steps (kitchen.gd and kitchen_text.gd read them here): walks below WORK_FIRST, works from it.
const STEP_DONE: int = -1
const WALK_STORE: int = 1
const WALK_KITCHEN: int = 2
const WALK_TABLE: int = 3
const WALK_WELL: int = 4
const WALK_BUTT: int = 5
const WALK_SEAT: int = 6
const WALK_RAW: int = 7
const WORK_FIRST: int = 10
const WORK_PICK: int = 10
const WORK_PUT_DOWN: int = 11
const WORK_COOK: int = 12
const WORK_PUT_OUT: int = 13
const WORK_DRAW: int = 14
const WORK_POUR: int = 15
const WORK_WAIT: int = 16
const WORK_EAT: int = 17
const WORK_EAT_RAW: int = 18

## The kitchen (kitchen.gd; untyped: it preloads this script), held WEAKLY: the kitchen keeps its tasks and its
## residents' brains keep them too, so a strong reference back would be a cycle that outlives a Restart. Once the kitchen
## is gone the task is over.
var _kitchen: WeakRef = null
var who: int = -1
var role: int = 0


func _init(p_kitchen: RefCounted, p_who: int, p_role: int) -> void:
	"""Resident `p_who`'s part `p_role` in `p_kitchen`'s meals."""
	_kitchen = weakref(p_kitchen)
	who = p_who
	role = p_role


func _owner() -> Object:
	"""The kitchen, or null once it is gone."""
	return _kitchen.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the kitchen sends it first (where it stands, once the kitchen is gone)."""
	var kitchen: Object = _owner()
	return kitchen.call(&"first_site", who) if kitchen != null else brain.get(&"position")


func arrived(_brain: RefCounted) -> void:
	"""At the place the kitchen sent it."""
	var kitchen: Object = _owner()
	if kitchen != null:
		kitchen.call(&"arrived", who)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the kitchen drives (false once its part is over, or the kitchen is gone)."""
	var kitchen: Object = _owner()
	return kitchen != null and bool(kitchen.call(&"drive", who, brain, delta))


func finish(_brain: RefCounted) -> void:
	"""Its part is over."""
	var kitchen: Object = _owner()
	if kitchen != null:
		kitchen.call(&"part_over", who, self)


func cancel(_brain: RefCounted) -> void:
	"""Called away (an order, the night, a release, a walk it could not finish)."""
	var kitchen: Object = _owner()
	if kitchen != null:
		kitchen.call(&"called_away", who, self)


func unfinished() -> RefCounted:
	"""A cook's round or a drawer's trip to come back to; a diner has none."""
	var kitchen: Object = _owner()
	return kitchen.call(&"unfinished_of", who, role) as RefCounted if kitchen != null else null


func label() -> String:
	"""What the panel says it is doing."""
	var kitchen: Object = _owner()
	return String(kitchen.call(&"doing_text", who)) if kitchen != null else ""


func urgent() -> bool:
	"""While it carries a load to where it goes -- the cook's food or pot, a drawer's water -- the night does not
	take it to bed first (decision 0222's rule: a load in hand is delivered), nor while it is eating its meal;
	otherwise it is ordinary work."""
	var kitchen: Object = _owner()
	return kitchen != null and bool(kitchen.call(&"must_finish", who))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the kitchen sends it again)."""
	return false
