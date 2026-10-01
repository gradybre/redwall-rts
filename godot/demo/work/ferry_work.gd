extends "res://demo/work/work_source.gd"
## The ferry's jobs as the work board reads them (decision 0437, with 0411; see work_source.gd): each windfall pile to
## gather in the far copse (the Woods crew's work), each load of ferried wood to haul from the ferry stage to the log
## stack, and each crossing's crew (both hauling). The board CLAIMS them -- an idle resident takes the best one it may --
## and every command is the ferry's own (ferry.gd): a load in hand is delivered and one on the ferry finishes the
## crossing before it is stopped or swapped; Cancel calls a crossing off before its crew is aboard.

const FerryScript := preload("res://demo/ferry/ferry.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

var _ferry: FerryScript = null


func _init(ferry: FerryScript) -> void:
	"""Read this ferry's jobs."""
	id = WorkIds.SOURCE_FERRY
	_ferry = ferry


func capacity() -> int:
	"""The ferry's job rows."""
	return FerryScript.MAX_JOBS


func live(row: int) -> bool:
	"""Whether the row holds a job."""
	return _ferry.j_live[row] == 1


func key(row: int) -> int:
	"""The job's serial (a reused row is a new task)."""
	return _ferry.j_serial[row]


func worker(row: int) -> int:
	"""Who does it (-1: nobody yet)."""
	return _ferry.j_worker[row]


func activity(row: int) -> int:
	"""Woods for gathering windfall; hauling for the haul and the crossing."""
	return WorkIds.ACT_WOODS if _ferry.j_kind[row] == FerryScript.KIND_GATHER else WorkIds.ACT_HAUL


func point(row: int) -> Vector2:
	"""Where the job is now."""
	return _ferry.goal_point(row)


func waiting(row: int) -> bool:
	"""Whether it waits for a resident and may be taken now."""
	return _ferry.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Why `who` may not take it ("" when it may): ferry.gd's own test."""
	return _ferry.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""Hand it to `who`, who sets off at once."""
	return _ferry.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The Work screen's record of job `row`."""
	task.reset(id, row)
	task.key = _ferry.j_serial[row]
	task.action = FerryScript.KIND_WORDS[_ferry.j_kind[row]]
	task.target = _ferry.place_words(row)
	task.worker = _ferry.j_worker[row]
	task.activity = activity(row)
	task.carrying = _ferry.j_load[row] > 0
	task.point = _ferry.goal_point(row)
	task.remaining_usec = _ferry.remaining_usec(row)
	var hold: String = _ferry.hold_refusal(row)
	task.pause_refusal = hold
	task.reassign_refusal = hold
	task.cancel_refusal = WorkIds.DELIVERY_GOES_ON if _ferry.j_load[row] > 0 else ""
	if task.worker >= 0:
		task.target_kind = NoticesScript.TARGET_RESIDENT
		task.target_id = task.worker
		worker_state_into(task, _ferry.brain_of(task.worker), _ferry.is_walking(row), _ferry.j_issued[row] != 0)
		if FerryScript.DECK_STEPS.has(_ferry.j_step[row]):
			task.state = WorkIds.STATE_HAULING if _ferry.j_step[row] == FerryScript.S_ROW else WorkIds.STATE_WORKING
		return
	var why: String = _ferry.j_words[row] if _ferry.j_wait_usec[row] > 0 else ""
	if why.is_empty() and _ferry.j_kind[row] == FerryScript.KIND_CREW:
		why = _ferry.x_words
	waiting_state_into(task, _ferry.j_paused[row] == 1, why)


func pause(row: int, on: bool) -> String:
	"""Pause or resume the job."""
	return _ferry.pause_job(row, on)


func cancel(row: int) -> String:
	"""Cancel the job (a gather or haul not yet carrying; a crossing before its crew is aboard)."""
	return _ferry.cancel_job(row)


func reassign(row: int, who: int) -> String:
	"""Give the job to `who`."""
	return _ferry.reassign_job(row, who)
