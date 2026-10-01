extends "res://demo/work/work_source.gd"
## The woods' job board as the work board reads it (decision 0411; see work_source.gd). Every command is the forestry
## crew's own (forest_crew.gd `claim`, `pause`, `cancel_row`, `reassign`), so the conservation of decision 0222 holds:
## a load in hand is carried on to its stack, never paused or handed over from afar.

const CrewScript := preload("res://demo/forestry/forest_crew.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const IntMath := preload("res://scripts/core/int_math.gd")

const BLOCKED_WAY: String = "can't reach it — tried again at the woods' next hour"
const OTHER_JOB: String = WorkIds.OTHER_WOODS_JOB

var _crew: CrewScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(crew: CrewScript) -> void:
	"""Read this forestry crew's board."""
	id = WorkIds.SOURCE_WOODS
	_crew = crew


func capacity() -> int:
	"""The woods board's rows."""
	return JobsScript.MAX_JOBS


func live(row: int) -> bool:
	"""Whether `row` holds a job."""
	return _crew.jobs.is_live(row)


func key(row: int) -> int:
	"""The job's serial."""
	return _crew.jobs.serial[row]


func worker(row: int) -> int:
	"""The resident on the job."""
	return _crew.jobs.worker[row]


func activity(row: int) -> int:
	"""forest_crew.gd `activity_of`: carrying and gathering wood is HAULING, the rest WOODS."""
	return CrewScript.activity_of(_crew.jobs.kind[row])


func point(row: int) -> Vector2:
	"""Where the job's target stands."""
	return _crew.target_point(row)


func waiting(row: int) -> bool:
	"""The forestry crew's own test (forest_crew.gd `waiting`)."""
	return _crew.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Anybeast may do woods work (LORE-P12; skill changes only how long it takes); one woods job a resident
	(forest_crew.gd `reassign`'s own refusal)."""
	if _crew.jobs.of_worker_into(who, _read) and _read.value != row:
		return OTHER_JOB
	return ""


func claim(row: int, who: int) -> bool:
	"""forest_crew.gd `claim`."""
	return _crew.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The job's record: its verb and target, who is on it, its phase in words, the work left in its plan."""
	task.reset(id, row)
	var jobs: JobsScript = _crew.jobs
	task.key = jobs.serial[row]
	task.action = JobsScript.KIND_NAMES[jobs.kind[row]]
	task.target = _crew.target_words(row)
	task.worker = jobs.worker[row]
	task.activity = activity(row)
	task.carrying = jobs.load_milli[row] > 0
	task.point = point(row)
	_target_of(task, row)
	task.remaining_usec = _crew.remaining_usec(row)
	var code: int = jobs.current_step(row)
	if task.worker == JobsScript.NOBODY:
		waiting_state_into(task, _crew.is_paused(row), BLOCKED_WAY if jobs.blocked[row] == 1 else "")
	else:
		worker_state_into(task, _crew.brain_of(task.worker), code < JobsScript.STEP_WORK, jobs.issued[row] == 1)
	if code >= JobsScript.STEP_WORK and jobs.issued[row] == 1 and jobs.work_usec[row] > 0:
		task.percent = mini(100, int(jobs.elapsed_usec[row] * 100 / jobs.work_usec[row]))
	if task.carrying:
		task.pause_refusal = WorkIds.CARRYING % (_crew.worker_name(row) if task.worker >= 0 else "the crew")
		task.reassign_refusal = task.pause_refusal
	if jobs.is_delivery(row):
		task.cancel_refusal = WorkIds.DELIVERY_GOES_ON


func _target_of(task: TaskScript, row: int) -> void:
	"""What "Go to" selects: the tree for felling, hauling, planting and grubbing; else only its place."""
	match _crew.jobs.kind[row]:
		JobsScript.KIND_FELL, JobsScript.KIND_HAUL, JobsScript.KIND_PLANT, JobsScript.KIND_GRUB:
			task.target_kind = NoticesScript.TARGET_TREE
			task.target_id = _crew.jobs.target[row]


func pause(row: int, on: bool) -> String:
	"""forest_crew.gd `pause`."""
	return _crew.pause(row, on)


func cancel(row: int) -> String:
	"""forest_crew.gd `cancel_row`."""
	return _crew.cancel_row(row)


func reassign(row: int, who: int) -> String:
	"""forest_crew.gd `reassign`."""
	return _crew.reassign(row, who)
