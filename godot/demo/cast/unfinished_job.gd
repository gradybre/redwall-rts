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
##
## THE ORDER LIST (decision 0411, review UX-002): the same record is a player's QUEUED order (Shift+right-click) --
## `queued` -- appended to the resident's list rather than kept from an interruption; and it names the work board's task
## it stands for (`source`, `key`: demo/work/work_ids.gd SOURCE_*, the job's serial), so the Work screen can say who
## means to come back to a task and the board's claims leave a task promised to a resident alone. -1: no board task
## (a dig, a work spot, a walk).

## A NEXT entry the player queued, not a job kept from an interruption.
var queued: bool = false
## The work board task it stands for (demo/work/work_ids.gd SOURCE_*; -1: none) and that task's key (its serial).
var source: int = -1
var key: int = -1

var _take_back: Callable = Callable()
var _label: String = ""
## A Callable does not keep its object alive: the owner is held here when it is reference-counted (a
## tunnel job's task, dropped by the brain the moment it is called away).
var _owner: RefCounted = null


func _init(take_back: Callable, what: String, task_source: int = -1, task_key: int = -1) -> void:
	"""The job, as its owner's `take_back(brain) -> bool` and a few words for the panel; the work board task it stands
	for, if any (see THE ORDER LIST)."""
	_take_back = take_back
	_label = what
	_owner = take_back.get_object() as RefCounted
	source = task_source
	key = task_key


func names_task(task_source: int, task_key: int) -> bool:
	"""Whether this entry stands for that work board task (see THE ORDER LIST)."""
	return source >= 0 and source == task_source and key == task_key


func resume(brain: RefCounted) -> bool:
	"""Give the job back to this resident; false when it no longer waits (done, cancelled, taken)."""
	if not _take_back.is_valid():
		return false
	return bool(_take_back.call(brain))


func label() -> String:
	"""What the job is, in words ("Hang lanterns, tunnel 2")."""
	return _label
