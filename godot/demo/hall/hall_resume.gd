extends RefCounted
## A hall project to come back to (resident_brain.gd RESUMING; cast/unfinished_job.gd): a resident called away from a
## place on a hall project takes up a free place on the same planning of it again, if it still waits for hands.
## Decision 0771. Holds the crew WEAKLY, so the brain's record never keeps a restarted village's crew alive.

var _crew: WeakRef = null
var _project: int = -1
var _generation: int = 0


func _init(crew: RefCounted, project: int, generation: int) -> void:
	"""`crew`'s project `project`, as planned (generation `generation`)."""
	_crew = weakref(crew)
	_project = project
	_generation = generation


func take_back(brain: RefCounted) -> bool:
	"""Give `brain`'s resident a free place on the project again; false when the crew is gone, the project was cancelled
	or finished since, or no place waits."""
	var crew: Object = _crew.get_ref()
	return crew != null and bool(crew.call(&"take_back", brain, _project, _generation))
