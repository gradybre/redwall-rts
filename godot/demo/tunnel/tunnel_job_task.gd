extends "res://demo/tunnel/tunnel_task.gd"
## A resident working one tunnel job (tunnel_jobs.gd). Decision 0196 (live demo). Presentation only.
##
## The worker walks to the mouth nearer where the work stands (the entrance, for a pump), pays the
## job's inputs as it starts (ECON-003), and -- for every job but PUMP -- goes down and works along
## the bore, standing where the work has reached, crediting the job its time every frame. PUMP works
## from beside the entrance, on the surface. The task ends when the job is done, voided (its tunnel
## freed) or given to someone else, or when the stores cannot pay for it; called away, the job is
## paused with its progress (ECON-005).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")

## A pump stands this far out from the entrance's centre, off the hole.
const PUMP_STAND_M: float = 1.1
const WORK_CLIP: StringName = &"collect_object"

var slot: int = 0
## Set when the stores could not pay for the job as it started.
var short_of_inputs: bool = false

var _jobs: JobsScript = null
var _network: NetworkScript = null
var _kind: int = 0
var _gen: int = 0
var _via_exit: bool = false


func _init(jobs: JobsScript, network: NetworkScript, job_slot: int) -> void:
	"""The job now posted on tunnel `job_slot`."""
	_jobs = jobs
	_network = network
	slot = job_slot
	_kind = jobs.kind[job_slot]
	_gen = network.generation[job_slot]
	_via_exit = _kind != JobsScript.JOB_PUMP and jobs.along_m(job_slot) > network.length_m(job_slot) * 0.5


func _below() -> bool:
	"""Whether this job is worked in the bore (all but PUMP)."""
	return _kind != JobsScript.JOB_PUMP


func is_valid() -> bool:
	"""Whether the job this task works is still posted, as the same kind, on the same tunnel."""
	return _jobs.has_job(slot) and _jobs.kind[slot] == _kind and _network.generation[slot] == _gen


func site(_brain: RefCounted) -> Vector2:
	"""The mouth the worker goes down (or, for a pump, a spot beside the entrance)."""
	var at := _network.mouth(slot, _via_exit)
	if _below():
		return at
	var outward := -_network.direction_at(slot, 0.0)
	return at + outward * PUMP_STAND_M


func arrived(brain: RefCounted) -> void:
	"""At the job: pay its inputs, and go down to where the work stands."""
	if not is_valid():
		return
	if not _jobs.start(slot):
		short_of_inputs = true
		return
	if _below():
		var from := _network.length_m(slot) if _via_exit else 0.0
		(brain as BrainScript).task_enter_bore(slot, from, _jobs.along_m(slot))


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame of work: credit it, stand where it has reached, play the work. False when over."""
	var worker := brain as BrainScript
	if short_of_inputs or not is_valid() or _jobs.worker[slot] != worker.index:
		return false
	_jobs.work(slot, roundi(delta * float(Rules.USEC_PER_SECOND)))
	if _below():
		worker.task_stand_in_bore(slot, _jobs.along_m(slot), true)
		worker.task_play(worker.dig_clip() if _digs() else WORK_CLIP)
	else:
		worker.task_face(_network.mouth(slot, false), delta)
		worker.task_play(WORK_CLIP)
	return not _jobs.is_done(slot)


func _digs() -> bool:
	"""Whether this job digs (widening, clearing a fall, a chamber) rather than fitting things."""
	return _kind == JobsScript.JOB_WIDEN or _kind == JobsScript.JOB_CLEAR or _kind == JobsScript.JOB_CHAMBER


func cancel(brain: RefCounted) -> void:
	"""Called away: the job waits, paused with its progress."""
	if is_valid() and _jobs.worker[slot] == (brain as BrainScript).index:
		_jobs.pause(slot)


func unfinished() -> RefCounted:
	"""Called away with the job paused and not done: the job to come back to (resident_brain.gd
	RESUMING) -- this same job, taken back while it still waits for a worker."""
	if not is_valid() or _jobs.is_done(slot):
		return null
	return UnfinishedScript.new(take_back, "%s, tunnel %d" % [JobsScript.NAMES[_kind], slot + 1])


func take_back(brain: RefCounted) -> bool:
	"""Give the paused job back to this resident (its spans, progress and paid inputs kept) and send it,
	if the job is still this one, not done and nobody is on it."""
	if not is_valid() or _jobs.is_done(slot) or _jobs.worker[slot] >= 0:
		return false
	var worker := brain as BrainScript
	_jobs.post(slot, _kind, worker.index, 0, 0)
	worker.order_task((get_script() as GDScript).new(_jobs, _network, slot))
	return true


func label() -> String:
	"""e.g. "Bracing the tunnel — 40%"."""
	if not is_valid():
		return "finishing a job"
	return "%s — %d%%" % [JobsScript.ACTIVITY[_kind].capitalize(), _jobs.percent(slot)]
