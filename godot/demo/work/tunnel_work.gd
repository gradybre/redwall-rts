extends "res://demo/work/work_source.gd"
## The tunnels' upgrade and repair jobs as the work board reads them (decision 0411; see work_source.gd): one job a
## segment (tunnel_jobs.gd), worked by one resident's task (tunnel_job_task.gd). A job whose worker was called away
## waits PAUSED with its progress and paid inputs; the board may hand it to an idle resident who can work it -- one who
## fits the bore, and for widening or clearing a fall one who can dig (anybeast whose body fits a standard bore,
## decision 0208) -- unless its worker means to come back to it. Every command is the jobs' own (`post`, `pause`,
## `clear`) and the task's.

const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const NewsJumpScript := preload("res://demo/ui/demo_news_jump.gd")

const PAID_CANCEL: String = "its materials are used already — pause it instead"
const SHORT: String = "the stores are short of its materials"
const CLOSED: String = "the tunnel is closed — it needs its repair first"
const NOT_A_DIGGER: String = "can't dig (its body fits no standard bore)"
const NOT_FITTING: String = "does not fit this tunnel's bore"
const DIGGING: String = "is digging a tunnel"

var _jobs: JobsScript = null
var _network: GraphScript = null
var _stores: StoresScript = null
var _brains: Array = []
## `can_dig(who) -> bool` (tunnel_control.gd `is_digger`).
var _can_dig: Callable = Callable()
## Per segment: the job key the player paused there (-1: none).
var _paused_key: PackedInt64Array = PackedInt64Array()
var _cost: PackedInt32Array = PackedInt32Array([0, 0])


func _init(jobs: JobsScript, network: GraphScript, stores: StoresScript, brains: Array, can_dig: Callable) -> void:
	"""Read these jobs on this network, paid from these stores, worked by these residents' brains."""
	id = WorkIds.SOURCE_TUNNELS
	_jobs = jobs
	_network = network
	_stores = stores
	_brains = brains
	_can_dig = can_dig


func capacity() -> int:
	"""One row a segment slot."""
	return _jobs.kind.size()


func live(row: int) -> bool:
	"""Whether segment `row` has a job posted."""
	return _jobs.has_job(row)


func key(row: int) -> int:
	"""The job's identity: the segment's generation and the job's kind."""
	return _jobs.tunnel_gen[row] * 8 + _jobs.kind[row]


func worker(row: int) -> int:
	"""The resident working it."""
	return _jobs.worker[row]


func activity(row: int) -> int:
	"""Widening and clearing a fall are DIGGING; bracing, lanterns and pumping BUILDING."""
	return WorkIds.ACT_DIG if _mole_job(row) else WorkIds.ACT_BUILD


func point(row: int) -> Vector2:
	"""The segment's middle."""
	var at: Vector3 = NewsJumpScript.tunnel_point(_network, row)
	return Vector2(at.x, at.z)


func _mole_job(row: int) -> bool:
	"""Whether the job digs (widening, clearing a fall)."""
	return _jobs.kind[row] == JobsScript.JOB_WIDEN or _jobs.kind[row] == JobsScript.JOB_CLEAR


func waiting(row: int) -> bool:
	"""A paused job nobody is on, not paused by the player, that can be worked now."""
	return live(row) and _jobs.worker[row] < 0 and not is_paused(row) and _blocked_words(row).is_empty()


func _blocked_words(row: int) -> String:
	"""Why a job nobody is on cannot be worked now ("" when it can)."""
	var repair: bool = _jobs.kind[row] == JobsScript.JOB_PUMP or _jobs.kind[row] == JobsScript.JOB_CLEAR
	if _network.closed[row] != GraphScript.CLOSED_NONE and not repair:
		return CLOSED
	if _jobs.paid[row] == 1:
		return ""
	_jobs.cost_into(row, _jobs.kind[row], _cost)
	return "" if _stores.can_pay(_cost[0], _cost[1]) else SHORT


func eligibility(row: int, who: int) -> String:
	"""One who can dig for widening and clearing; one who fits the bore for anything worked in it (all but pumping)."""
	var brain: BrainScript = _brains[who]
	if brain.order == BrainScript.ORDER_DIG:
		return DIGGING
	if _mole_job(row) and not bool(_can_dig.call(who)):
		return NOT_A_DIGGER
	if _jobs.kind[row] != JobsScript.JOB_PUMP and not _network.fits_tunnel(who, row, false):
		return NOT_FITTING
	return ""


func claim(row: int, who: int) -> bool:
	"""Post the waiting job for `who` (its progress and paid inputs kept) and send it."""
	if not waiting(row) or not eligibility(row, who).is_empty():
		return false
	_send(row, who)
	return true


func _send(row: int, who: int) -> void:
	"""`who` takes the job posted on segment `row` (tunnel_actions.gd's own post-and-send)."""
	_jobs.post(row, _jobs.kind[row], who, 0, 0)
	(_brains[who] as BrainScript).order_task(JobTaskScript.new(_jobs, _network, row))


func is_paused(row: int) -> bool:
	"""Whether the player paused the job."""
	return live(row) and row < _paused_key.size() and _paused_key[row] == key(row)


func fill(task: TaskScript, row: int) -> void:
	"""The job's record."""
	task.reset(id, row)
	task.key = key(row)
	task.action = JobsScript.NAMES[_jobs.kind[row]]
	task.target = "tunnel %d" % (row + 1)
	task.worker = _jobs.worker[row]
	task.activity = activity(row)
	task.point = point(row)
	task.target_kind = NoticesScript.TARGET_TUNNEL
	task.target_id = row
	task.percent = _jobs.percent(row)
	task.remaining_usec = (_jobs.total[row] - _jobs.done_ticks(row)) * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND
	if _jobs.paid[row] == 1:
		task.cancel_refusal = PAID_CANCEL
	if task.worker < 0:
		waiting_state_into(task, is_paused(row), _blocked_words(row))
		return
	var brain: BrainScript = _brains[task.worker]
	worker_state_into(task, brain, brain.state != BrainScript.State.TASK, true)


func pause(row: int, on: bool) -> String:
	"""Pause the job (its worker's task ends at its next step: tunnel_job_task.gd `step`) or resume it."""
	if not live(row):
		return WorkIds.NOT_FOUND
	if _paused_key.size() < capacity():
		var old: int = _paused_key.size()
		_paused_key.resize(capacity())
		for k: int in range(old, capacity()):
			_paused_key[k] = -1
	if not on:
		_paused_key[row] = -1
		return ""
	if is_paused(row):
		return WorkIds.PAUSED_ALREADY
	_paused_key[row] = key(row)
	_jobs.pause(row)
	return ""


func cancel(row: int) -> String:
	"""Take a job off the segment -- only before its materials are paid (PAID_CANCEL)."""
	if not live(row):
		return WorkIds.NOT_FOUND
	if _jobs.paid[row] == 1:
		return PAID_CANCEL
	_jobs.clear(row)
	return ""


func reassign(row: int, who: int) -> String:
	"""`who` takes the job instead: the worker on it stops at its next step, the progress and paid inputs kept."""
	if not live(row):
		return WorkIds.NOT_FOUND
	if who < 0 or who >= _brains.size():
		return "nobody to give it to"
	var why: String = eligibility(row, who)
	if not why.is_empty():
		return why
	if _jobs.worker[row] == who:
		return ""
	if row < _paused_key.size():
		_paused_key[row] = -1
	_jobs.pause(row)
	_send(row, who)
	return ""
