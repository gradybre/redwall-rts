extends RefCounted
## A job owner as the work board reads it (decision 0411, review F22/F32): one per source (work_ids.gd SOURCE_*). Each
## owner keeps its own board; this adapter lists its rows, fills a task's record (work_task.gd) and carries the
## board's commands to the owner's own functions -- it never decides a job's outcome itself. Presentation only.
##
## The base answers for a source with no rows; each source overrides what it supports. A command a source does not
## support refuses with words (UNSUPPORTED), shown on the Work screen's disabled button.

const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const UNSUPPORTED: String = "not for this kind of task"
## The routing desk's and A's words (decision 0361), as the party panel says them.
const FINDING_ROUTE: String = "finding a route"
const CANT_REACH: String = "can't reach it — %s"
const PAUSED_BY_YOU: String = "paused by you — Resume to let it be taken"
const WAITS_FOR_SOMEONE: String = "waits for a free resident who can do it"

## WorkIds.SOURCE_* of this adapter.
var id: int = -1


func capacity() -> int:
	"""How many rows the owner's board has (fixed)."""
	return 0


func live(_row: int) -> bool:
	"""Whether `row` holds a task."""
	return false


func key(_row: int) -> int:
	"""The task's identity on its row (a serial; a reused row is a different task)."""
	return 0


func worker(_row: int) -> int:
	"""The resident on the task (-1: nobody)."""
	return -1


func activity(_row: int) -> int:
	"""Which crew activity the task is (WorkIds.ACT_*)."""
	return WorkIds.ACT_HAUL


func point(_row: int) -> Vector2:
	"""Where the task is (presentation metres): its distance decides between equals."""
	return Vector2.ZERO


func may_wait() -> bool:
	"""Whether any row of this source can ever hold a task waiting to be claimed (work_board.gd THE INDEX DOES NOT GROW
	WITH THE VILLAGE): the board reads no row of one that cannot."""
	return true


func waiting(_row: int) -> bool:
	"""Whether the task waits for a worker and may be claimed now."""
	return false


func eligibility(_row: int, _who: int) -> String:
	"""Why resident `who` could not take the task ("" when it could): GDD §5.3's physical fit and skills -- never a
	species lock (LORE-P12)."""
	return UNSUPPORTED


func claim(_row: int, _who: int) -> bool:
	"""Hand the waiting task to `who`, who sets off at once."""
	return false


func fill(task: TaskScript, row: int) -> void:
	"""The task's record for the Work screen."""
	task.reset(id, row)


func pause(_row: int, _on: bool) -> String:
	"""Pause the task (its worker let go) or resume it: "" when done, else why not."""
	return UNSUPPORTED


func cancel(_row: int) -> String:
	"""Cancel the task alone: "" when done, else why not."""
	return UNSUPPORTED


func reassign(_row: int, _who: int) -> String:
	"""Give the task to `who` instead: "" when done, else why not."""
	return UNSUPPORTED


static func worker_state_into(task: TaskScript, brain: BrainScript, walking: bool, issued: bool) -> void:
	"""A task with a worker: TRAVELLING while its route is being found ("finding a route"), BLOCKED while a walk it was
	given up holds ("can't reach it — ..."), else on a walk ASSIGNED / TRAVELLING / HAULING, at work WORKING."""
	if brain.state == BrainScript.State.ROUTE:
		task.state = WorkIds.STATE_TRAVELLING
		task.reason = FINDING_ROUTE
	elif walking and brain.state == BrainScript.State.HOLD and brain.trip_failed():
		task.state = WorkIds.STATE_BLOCKED
		task.reason = CANT_REACH % brain.route_refusal()
	elif walking:
		task.state = task.walking_state(issued, task.carrying)
	else:
		task.state = WorkIds.STATE_WORKING


static func waiting_state_into(task: TaskScript, paused: bool, blocked: String) -> void:
	"""A task with nobody on it: PAUSED by the player, BLOCKED for `blocked` (the owner's words), else QUEUED."""
	task.paused = paused
	if paused:
		task.state = WorkIds.STATE_PAUSED
		task.reason = PAUSED_BY_YOU
	elif not blocked.is_empty():
		task.state = WorkIds.STATE_BLOCKED
		task.reason = blocked
	else:
		task.state = WorkIds.STATE_QUEUED
		task.reason = WAITS_FOR_SOMEONE
