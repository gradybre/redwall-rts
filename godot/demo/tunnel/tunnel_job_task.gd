extends "res://demo/tunnel/tunnel_task.gd"
## A resident working one tunnel job (tunnel_jobs.gd). Decision 0196 (live demo). Presentation only.
##
## The worker walks to the end of the segment nearer where the work stands -- a mouth on the surface, or a
## node inside the network, reached through it (decision 0208) -- pays the job's inputs as it starts
## (ECON-003), and -- for every job but PUMP -- goes into the bore and works along it, standing where the
## work has reached, crediting the job its time every frame. PUMP works from beside the mouth nearest the
## segment, on the surface. The task ends when the job is done, voided (its segment freed) or given to
## someone else, or when the stores cannot pay for it; called away, the job is paused with its progress
## (ECON-005).

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
## The work board's names (decision 0411): an order-list entry names its job by SOURCE_TUNNELS and the job's key, the
## segment's generation x 8 + the job's kind (demo/work/tunnel_work.gd `key`).
const WorkIds := preload("res://demo/work/work_ids.gd")

## A pump stands this far out from its mouth's centre, off the hole.
const PUMP_STAND_M: float = 1.1
const WORK_CLIP: StringName = &"collect_object"

var slot: int = 0
## Set when the stores could not pay for the job as it started.
var short_of_inputs: bool = false

var _jobs: JobsScript = null
var _network: GraphScript = null
var _kind: int = 0
var _gen: int = 0
var _via_b: bool = false
var _pump_mouth: int = -1


func _init(jobs: JobsScript, network: GraphScript, job_slot: int) -> void:
	"""The job now posted on segment `job_slot`."""
	_jobs = jobs
	_network = network
	slot = job_slot
	_kind = jobs.kind[job_slot]
	_gen = network.generation[job_slot]
	_via_b = _kind != JobsScript.JOB_PUMP and jobs.along_m(job_slot) > network.length_m(job_slot) * 0.5
	if _kind == JobsScript.JOB_PUMP:
		_pump_mouth = _mouth_near(network, job_slot)


static func _mouth_near(network: GraphScript, at_slot: int) -> int:
	"""The mouth a pump on segment `at_slot` works from: a mouth it opens at, else the nearest by the walk
	from its node A (any bore), else none (-1)."""
	for end in 2:
		if network.mouth_of_end(at_slot, end == 1) >= 0:
			return network.mouth_of_end(at_slot, end == 1)
	return network.paths.nearest_mouth(network, network.node_a[at_slot], PathsScript.CLASS_ANY)


func _below() -> bool:
	"""Whether this job is worked in the bore (all but PUMP)."""
	return _kind != JobsScript.JOB_PUMP


func is_valid() -> bool:
	"""Whether the job this task works is still posted, as the same kind, on the same segment."""
	return _jobs.has_job(slot) and _jobs.kind[slot] == _kind and _network.generation[slot] == _gen


func site_node(_brain: RefCounted) -> int:
	"""The node inside the network the worker walks to first, when the end it goes in at is not a mouth (-1
	otherwise: `site`)."""
	if not _below():
		return -1
	var node := _network.end_node(slot, _via_b)
	return node if _network.node_mouth[node] < 0 else -1


func site(_brain: RefCounted) -> Vector2:
	"""The mouth the worker goes down (or, for a pump, a spot beside the mouth it works from)."""
	if _below():
		return _network.end_at(slot, _via_b)
	if _pump_mouth < 0:
		return _network.end_at(slot, false)
	return _network.mouth_at(_pump_mouth) - _network.mouth_inward(_pump_mouth) * PUMP_STAND_M


func arrived(brain: RefCounted) -> void:
	"""At the job: pay its inputs, and go into the bore to where the work stands."""
	if not is_valid():
		return
	if not _jobs.start(slot):
		short_of_inputs = true
		return
	if _below():
		var from := _network.length_m(slot) if _via_b else 0.0
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
		worker.task_face(_network.mouth_at(_pump_mouth) if _pump_mouth >= 0 else worker.position, delta)
		worker.task_play(WORK_CLIP)
	return not _jobs.is_done(slot)


func _digs() -> bool:
	"""Whether this job digs (widening, clearing a fall) rather than fitting things."""
	return _kind == JobsScript.JOB_WIDEN or _kind == JobsScript.JOB_CLEAR


func cancel(brain: RefCounted) -> void:
	"""Called away: the job waits, paused with its progress."""
	if is_valid() and _jobs.worker[slot] == (brain as BrainScript).index:
		_jobs.pause(slot)


func unfinished() -> RefCounted:
	"""Called away with the job paused and not done: the job to come back to (resident_brain.gd RESUMING) --
	this same job, taken back while it still waits for a worker."""
	if not is_valid() or _jobs.is_done(slot):
		return null
	return UnfinishedScript.new(take_back, "%s, tunnel %d" % [JobsScript.NAMES[_kind], slot + 1], WorkIds.SOURCE_TUNNELS,
		_gen * 8 + _kind)


func take_back(brain: RefCounted) -> bool:
	"""Give the paused job back to this resident (its spans, progress and paid inputs kept) and send it, if the
	job is still this one, not done and nobody is on it."""
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
