extends "res://demo/tunnel/tunnel_task.gd"
## One resident's place on a hall project (hall_crew.gd): carrying the materials in and building. Decision 0771.
## Presentation only.
##
## A thin adapter, as the kitchen's is (kitchen_task.gd): the crew holds every number -- what is reserved, in arms,
## delivered and built -- and decides each next step; this task only lets the brain walk where the crew says and stand
## at the work (resident_brain.gd TASKS), and tells the crew when it arrives, when it is called away and when it is
## over. The crew is held WEAKLY (its residents' brains keep this task, so a strong reference back would be a cycle
## that outlives a Restart); once the crew is gone the task is over.

## The board row (place) it works, and the project and that project's generation when it was handed out: a resume
## record is made only for the same planning of the same project.
var row: int = -1
var project: int = -1
var generation: int = 0
## Set when the crew itself lets the resident go (a pause, a reassignment, a cancelled project): nothing to come back
## to.
var let_go: bool = false

var _crew: WeakRef = null


func _init(crew: RefCounted, p_row: int, p_project: int, p_generation: int) -> void:
	"""Place `p_row` of `crew`'s project `p_project` (planned as generation `p_generation`)."""
	_crew = weakref(crew)
	row = p_row
	project = p_project
	generation = p_generation


func _owner() -> Object:
	"""The crew, or null once it is gone."""
	return _crew.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the crew sends it first (where it stands, once the crew is gone)."""
	var crew: Object = _owner()
	return crew.call(&"first_site", row) if crew != null else brain.get(&"position")


func arrived(_brain: RefCounted) -> void:
	"""At the place the crew sent it."""
	var crew: Object = _owner()
	if crew != null:
		crew.call(&"arrived", row, self)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the crew drives (false once its part is over, or the crew is gone)."""
	var crew: Object = _owner()
	return crew != null and bool(crew.call(&"drive", row, self, brain, delta))


func finish(_brain: RefCounted) -> void:
	"""Its part is over."""
	var crew: Object = _owner()
	if crew != null:
		crew.call(&"part_over", row, self)


func cancel(_brain: RefCounted) -> void:
	"""Called away (an order, the night, a release, a walk it could not finish)."""
	var crew: Object = _owner()
	if crew != null:
		crew.call(&"part_over", row, self)


func unfinished() -> RefCounted:
	"""The project to come back to, while it is still the same planning and waits for hands; none once the crew let it
	go."""
	var crew: Object = _owner()
	if crew == null or let_go:
		return null
	return crew.call(&"unfinished_of", self) as RefCounted


func label() -> String:
	"""What the panel says it is doing."""
	var crew: Object = _owner()
	return String(crew.call(&"doing_text", row)) if crew != null else ""


func urgent() -> bool:
	"""While it carries a load the night does not take it to bed first (decision 0222: a load in hand is delivered)."""
	var crew: Object = _owner()
	return crew != null and bool(crew.call(&"carrying", row))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the work board hands the place out again)."""
	return false
