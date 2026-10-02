extends "res://demo/tunnel/tunnel_task.gd"
## One resident's part in an orchard job (orchard_jobs.gd; decision 0671). A thin adapter like the fishery's
## (fishery_task.gd): the orchard's board holds every number and decides each next step; this task only lets the brain
## walk where the board says and stand at the work, and tells the board when it arrives, when it is called away and
## when it is over -- so an interruption loses nothing (a load in hand is set down for the next to carry on).

## The orchard's board (orchard_jobs.gd; untyped: it preloads this script), held WEAKLY so a Restart frees both.
var _owner_ref: WeakRef = null
var job: int = -1
var serial: int = 0


func _init(owner: RefCounted, p_job: int, p_serial: int) -> void:
	"""Job row `p_job` (opened with `p_serial`) of `owner`'s."""
	_owner_ref = weakref(owner)
	job = p_job
	serial = p_serial


func _owner() -> Object:
	"""The board, or null once it is gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the board sends it first (where it stands, once the board is gone)."""
	var jobs: Object = _owner()
	return jobs.call(&"first_site", job, serial) if jobs != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the place the board sent it."""
	var jobs: Object = _owner()
	if jobs != null:
		jobs.call(&"arrived", job, serial, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the board drives (false once its part is over, or the board is gone)."""
	var jobs: Object = _owner()
	return jobs != null and bool(jobs.call(&"drive", job, serial, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away (an order, the night, a release, a walk it could not finish)."""
	var jobs: Object = _owner()
	if jobs != null:
		jobs.call(&"called_away", job, serial, brain)


func label() -> String:
	"""What the panel says it is doing."""
	var jobs: Object = _owner()
	return String(jobs.call(&"doing_text", job, serial)) if jobs != null else ""


func urgent() -> bool:
	"""While fruit or berries are in its hands, the night does not take it to bed first (decision 0222: a load in hand
	is delivered)."""
	var jobs: Object = _owner()
	return jobs != null and bool(jobs.call(&"must_finish", job, serial))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the board offers the job again)."""
	return false
