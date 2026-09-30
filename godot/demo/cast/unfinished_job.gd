extends RefCounted
## One unfinished job a resident was called away from, to come back to (resident_brain.gd RESUMING).
## Decision 0205 (the playtest of 2026-09-29: a mole ordered to hang lanterns, then to raise a bed,
## raised the bed and never went back to the lanterns). Presentation only.
##
## The job's owner makes it when its worker is taken off the job -- a tunnel job (tunnel_job_task.gd),
## a dig (resident_brain.gd `_leave_dig`), a farm job (farm_crew.gd), a woods job (forest_crew.gd) --
## with `take_back`: `(brain: RefCounted) -> bool`, which gives the job back to that resident (its
## resident_brain.gd) if it still waits for someone (still posted, the same job, nobody on it) and
## answers whether it did. A stale job answers false and is simply dropped.

var _take_back: Callable = Callable()
var _label: String = ""
## A Callable does not keep its object alive: the owner is held here when it is reference-counted (a
## tunnel job's task, dropped by the brain the moment it is called away).
var _owner: RefCounted = null


func _init(take_back: Callable, what: String) -> void:
	"""The job, as its owner's `take_back(brain) -> bool` and a few words for the panel."""
	_take_back = take_back
	_label = what
	_owner = take_back.get_object() as RefCounted


func resume(brain: RefCounted) -> bool:
	"""Give the job back to this resident; false when it no longer waits (done, cancelled, taken)."""
	if not _take_back.is_valid():
		return false
	return bool(_take_back.call(brain))


func label() -> String:
	"""What the job is, in words ("Hang lanterns, tunnel 2")."""
	return _label
