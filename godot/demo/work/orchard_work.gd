extends "res://demo/work/work_source.gd"
## The orchard's jobs as the work board reads them (decision 0671; see work_source.gd, source SOURCE_ORCHARD): tending,
## picking, the hedge's baskets, hauling the baskets on, planting, propagating and the grove's observation. The board
## CLAIMS them -- an idle resident takes the best one it may, the Field crew first (the hauls are the Haulers') -- and
## every command is the orchard's own (demo/orchard/orchard_jobs.gd): a load in hand is delivered before it is paused
## or handed over, and a harvest already picked always finishes.

const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

var _jobs: JobsScript = null


func _init(jobs: JobsScript) -> void:
	"""Read this orchard's board."""
	id = WorkIds.SOURCE_ORCHARD
	_jobs = jobs


func capacity() -> int:
	"""The orchard's job rows."""
	return JobsScript.MAX_JOBS


func live(row: int) -> bool:
	"""Whether the row holds a job."""
	return _jobs.is_live(row)


func key(row: int) -> int:
	"""The job's serial (a reused row is a new task)."""
	return _jobs.serial[row]


func worker(row: int) -> int:
	"""Who does it (-1: nobody yet)."""
	return _jobs.worker[row]


func activity(row: int) -> int:
	"""Hauling for a haul, field work for the rest (GDD §5.3's TEND work is the Field crew's)."""
	return WorkIds.ACT_HAUL if _jobs.activity_is_haul(row) else WorkIds.ACT_FARM


func point(row: int) -> Vector2:
	"""Where the job is now."""
	return _jobs.point(row)


func waiting(row: int) -> bool:
	"""Whether it waits for a resident and may be taken now."""
	return _jobs.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Why `who` may not take it ("" when it may): orchard_jobs.gd's own test, never a species."""
	return _jobs.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""Hand it to `who`, who sets off at once."""
	return _jobs.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The Work screen's record of job `row`."""
	task.reset(id, row)
	task.key = _jobs.serial[row]
	task.action = Text.KIND_NAMES[_jobs.kind[row]]
	task.target = Text.target_words(_jobs, row)
	task.worker = _jobs.worker[row]
	task.activity = activity(row)
	task.carrying = _jobs.carrying(row)
	task.point = _jobs.point(row)
	task.remaining_usec = _jobs.remaining_usec(row)
	if _jobs.need_mwu[row] > 0:
		@warning_ignore("integer_division") var percent: int = _jobs.done_mwu[row] * 100 / _jobs.need_mwu[row]
		task.percent = mini(100, percent)
	if _jobs.in_hand(row):
		task.pause_refusal = WorkIds.CARRYING % _jobs.name_of(task.worker)
		task.reassign_refusal = task.pause_refusal
	if _jobs.carrying(row) and _jobs.kind[row] != JobsScript.K_HAUL:
		task.cancel_refusal = WorkIds.DELIVERY_GOES_ON
	if task.worker >= 0:
		task.target_kind = NoticesScript.TARGET_RESIDENT
		task.target_id = task.worker
		worker_state_into(task, _jobs.brain_of(task.worker), _jobs.at_work[row] == 0, _jobs.issued[row] != 0)
		return
	waiting_state_into(task, _jobs.paused[row] == 1, _jobs.words[row] if _jobs.wait_usec[row] > 0 else "")


func pause(row: int, on: bool) -> String:
	"""Pause or resume the job."""
	return _jobs.pause(row, on)


func cancel(row: int) -> String:
	"""Cancel the job."""
	return _jobs.cancel(row)


func reassign(row: int, who: int) -> String:
	"""Give the job to `who`."""
	return _jobs.reassign(row, who)
