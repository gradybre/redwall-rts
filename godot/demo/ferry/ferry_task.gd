extends "res://demo/tunnel/tunnel_task.gd"
## One resident's part in a ferry job -- gathering the far copse's windfall, hauling the landed wood to the log stack, or
## crewing a crossing (ferry.gd). Decision 0437 (live demo). A thin adapter like the fishery's (fishery_task.gd): the
## ferry holds every number (what is lying, carried, aboard and stacked, and how much work is done) and decides each
## next step; this task only lets the brain walk where the ferry says and stand at the work (resident_brain.gd TASKS),
## and tells the ferry when it arrives, when it is called away and when it is over -- so an interruption loses nothing:
## a load in hand is set down where it is for the next to fetch.
## Called away by an order, a meal or the night, its resident keeps the job to come back to (`unfinished`; decision
## 1905, as the orchard's 1900).

## The ferry (ferry.gd; untyped: it preloads this script), held WEAKLY so a Restart frees both.
var _owner_ref: WeakRef = null
var job: int = -1
var serial: int = 0
## Set once the brain has called it away (`cancel`), and whether the owner let its resident keep the job then.
var _called_away: bool = false
var _kept: bool = false


func _init(owner: RefCounted, p_job: int, p_serial: int) -> void:
	"""Job row `p_job` (opened with `p_serial`) of `owner`'s."""
	_owner_ref = weakref(owner)
	job = p_job
	serial = p_serial


func _owner() -> Object:
	"""The ferry, or null once it is gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the ferry sends it first (where it stands, once the ferry is gone)."""
	var ferry: Object = _owner()
	return ferry.call(&"first_site", job, serial) if ferry != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the place the ferry sent it."""
	var ferry: Object = _owner()
	if ferry != null:
		ferry.call(&"arrived", job, serial, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the ferry drives (false once its part is over, or the ferry is gone)."""
	var ferry: Object = _owner()
	return ferry != null and bool(ferry.call(&"drive", job, serial, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away (an order, the night, a release, a walk it could not finish)."""
	var ferry: Object = _owner()
	_called_away = true
	_kept = ferry != null and bool(ferry.call(&"called_away", job, serial, brain))


func unfinished() -> RefCounted:
	"""The job to come back to (the owner's `unfinished_of`; decision 1905): asked before it is called away (an action
	card's "goes back to it after"), the job while it lasts; after, only one its resident was let keep -- not a walk it
	could not finish, nor one the board itself took away (Pause, Reassign)."""
	var ferry: Object = _owner()
	if ferry == null or (_called_away and not _kept):
		return null
	return ferry.call(&"unfinished_of", job, serial) as RefCounted


func label() -> String:
	"""What the panel says it is doing."""
	var ferry: Object = _owner()
	return String(ferry.call(&"doing_text", job, serial)) if ferry != null else ""


func urgent() -> bool:
	"""While it carries wood or is on a stage's deck or afloat, the night does not take it to bed first (decision 0222: a
	load in hand is delivered; MOVE-REQ-007: a crossing entered is finished)."""
	var ferry: Object = _owner()
	return ferry != null and bool(ferry.call(&"must_finish", job, serial))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the ferry offers the job again)."""
	return false
