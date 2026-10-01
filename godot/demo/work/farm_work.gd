extends "res://demo/work/work_source.gd"
## The farm's job board as the work board reads it (decision 0411; see work_source.gd). Every command is the farm
## crew's own (farm_crew.gd `claim`, `pause`, `cancel_row`, `reassign`), so the conservation of decision 0222 holds:
## a harvest already cut is carried on, never paused or handed over from afar.

const CrewScript := preload("res://demo/farm/farm_crew.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const IntMath := preload("res://scripts/core/int_math.gd")

const OTHER_JOB: String = WorkIds.OTHER_FARM_JOB

var _crew: CrewScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(crew: CrewScript) -> void:
	"""Read this farm crew's board."""
	id = WorkIds.SOURCE_FARM
	_crew = crew


func capacity() -> int:
	"""The farm board's rows."""
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
	"""A harvest's delivery is HAULING; every other farm job FARM."""
	return WorkIds.ACT_HAUL if _crew.jobs.kind[row] == JobsScript.KIND_DELIVER else WorkIds.ACT_FARM


func point(row: int) -> Vector2:
	"""The job's bed."""
	return Catalog.bed_centre_m(_crew.jobs.bed[row])


func waiting(row: int) -> bool:
	"""The farm crew's own test (farm_crew.gd `waiting`)."""
	return _crew.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Anybeast may do farm work (LORE-P12); one farm job a resident (farm_crew.gd `reassign`'s own refusal)."""
	if _crew.jobs.job_of_worker_into(who, _read) and _read.value != row:
		return OTHER_JOB
	return ""


func claim(row: int, who: int) -> bool:
	"""farm_crew.gd `claim`."""
	return _crew.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The job's record: its verb and bed, who is on it, its phase in words, the work left in its plan."""
	task.reset(id, row)
	var jobs: JobsScript = _crew.jobs
	task.key = jobs.serial[row]
	task.action = JobsScript.KIND_NAMES[jobs.kind[row]]
	task.target = _crew.bed_label(jobs.bed[row])
	task.worker = jobs.worker[row]
	task.activity = activity(row)
	task.carrying = _crew.holds_load(row)
	task.point = point(row)
	task.target_kind = NoticesScript.TARGET_BED
	task.target_id = jobs.bed[row]
	var code: int = jobs.current_step(row)
	var plan: int = JobsScript.plan_work_usec(jobs.kind[row], jobs.source[row], jobs.step[row])
	task.remaining_usec = maxi(plan - jobs.elapsed_usec[row], 0)
	if task.worker == JobsScript.NOBODY:
		waiting_state_into(task, _crew.is_paused(row), _crew.blocked_words(row))
	else:
		worker_state_into(task, _crew.brain_of(task.worker), code < JobsScript.STEP_WORK, jobs.issued[row] == 1)
	if code >= JobsScript.STEP_WORK and task.worker != JobsScript.NOBODY:
		task.percent = mini(100, int(jobs.elapsed_usec[row] * 100 / maxi(jobs.work_usec(code - JobsScript.STEP_WORK), 1)))
	_refusals(task, row)


func _refusals(task: TaskScript, row: int) -> void:
	"""Why each command cannot be used on the job now (CONSERVATION: a load in hand is finished first)."""
	if task.carrying:
		task.pause_refusal = WorkIds.CARRYING % _who_carries(task)
		task.reassign_refusal = task.pause_refusal
	if _crew.jobs.kind[row] == JobsScript.KIND_DELIVER:
		task.cancel_refusal = WorkIds.DELIVERY_GOES_ON


func _who_carries(task: TaskScript) -> String:
	"""The carrier's name, or the crew's."""
	return _crew.worker_name(task.row) if task.worker != JobsScript.NOBODY else "the crew"


func pause(row: int, on: bool) -> String:
	"""farm_crew.gd `pause`."""
	return _crew.pause(row, on)


func cancel(row: int) -> String:
	"""farm_crew.gd `cancel_row`."""
	return _crew.cancel_row(row)


func reassign(row: int, who: int) -> String:
	"""farm_crew.gd `reassign`."""
	return _crew.reassign(row, who)
