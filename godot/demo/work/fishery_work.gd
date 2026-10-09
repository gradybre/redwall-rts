extends "res://demo/work/work_source.gd"
## The fishery's jobs as the work board reads them (decision 0411; water part B, decision 0431; see work_source.gd):
## each trip's seat (a boat has two), each trap's collection, each rack batch and take-down, each mill batch, each
## piece of gear made or mended. The board CLAIMS them -- an idle resident takes the best one it may -- and every
## command is the fishery's own (fishery.gd): a load in hand is delivered and one out on the water or the ice comes
## back before it is stopped or swapped; Cancel calls a trip off (its claims released) or cancels a station batch
## (REQ-SET-094's half spoiled once its food was withdrawn).

const FisheryScript := preload("res://demo/fishery/fishery.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

var _fishery: FisheryScript = null


func _init(fishery: FisheryScript) -> void:
	"""Read this fishery's jobs."""
	id = WorkIds.SOURCE_FISHERY
	_fishery = fishery


func capacity() -> int:
	"""The fishery's job rows."""
	return Tables.MAX_JOBS


func live(row: int) -> bool:
	"""Whether the row holds a job."""
	return _fishery.tables.j_live[row] == 1


func key(row: int) -> int:
	"""The job's serial (a reused row is a new task)."""
	return _fishery.tables.j_serial[row]


func worker(row: int) -> int:
	"""Who does it (-1: nobody yet)."""
	return _fishery.tables.j_worker[row]


func activity(row: int) -> int:
	"""Fishing for a trip's jobs, crafting for the stations'."""
	return WorkIds.ACT_FISH if _fishery.tables.j_kind[row] <= Tables.KIND_COLLECT else WorkIds.ACT_CRAFT


func point(row: int) -> Vector2:
	"""Where the job is now."""
	return _fishery.goal_point(row)


func waiting(row: int) -> bool:
	"""Whether it waits for a resident and may be taken now."""
	return _fishery.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Why `who` may not take it ("" when it may): fishery.gd's own test."""
	return _fishery.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""Hand it to `who`, who sets off at once."""
	return _fishery.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The Work screen's record of job `row`."""
	var tables: Tables = _fishery.tables
	task.reset(id, row)
	task.key = tables.j_serial[row]
	task.action = _fishery.job_words(row)
	task.target = _fishery.trip_name(tables.j_trip[row]) if tables.j_trip[row] >= 0 else _fishery.place_words(row)
	task.worker = tables.j_worker[row]
	task.activity = activity(row)
	task.carrying = tables.j_load_milli[row] > 0
	task.point = _fishery.goal_point(row)
	task.remaining_usec = _fishery.remaining_usec(row)
	var hold: String = _fishery.hold_refusal(row)
	task.pause_refusal = hold
	task.reassign_refusal = hold
	task.cancel_refusal = _cancel_words(row)
	if task.worker >= 0:
		task.target_kind = NoticesScript.TARGET_RESIDENT
		task.target_id = task.worker
	if task.worker < 0:
		waiting_state_into(task, tables.j_paused[row] == 1, tables.j_words[row] if tables.j_wait_usec[row] > 0 else "")
		return
	worker_state_into(task, _fishery.brain_of(task.worker), _fishery.is_walking(row), tables.j_issued[row] != 0)


func _cancel_words(row: int) -> String:
	"""Why Cancel is refused now ("" when it may)."""
	var tables: Tables = _fishery.tables
	if tables.j_load_milli[row] > 0:
		return WorkIds.DELIVERY_GOES_ON
	var trip: int = tables.j_trip[row]
	if trip >= 0 and tables.t_state[trip] == Tables.TRIP_LANDING:
		return "the catch is out of the water — it is landed first"
	if tables.j_kind[row] == Tables.KIND_TAKE_DOWN:
		return "a cured batch is always taken down"
	return ""


func pause(row: int, on: bool) -> String:
	"""Pause or resume the job."""
	return _fishery.pause_job(row, on)


func cancel(row: int) -> String:
	"""Cancel the job (its trip, or its station batch)."""
	return _fishery.cancel_job(row)


func reassign(row: int, who: int) -> String:
	"""Give the job to `who`."""
	return _fishery.reassign_job(row, who)
