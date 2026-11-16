extends "res://demo/tunnel/tunnel_task.gd"
## One resident's part in a job row that an OWNER holds (resident_brain.gd TASKS): the fishery's (fishery_task.gd), the
## ferry's (ferry_task.gd), the forage trips' (forage_task.gd) and the orchard's board (orchard_task.gd). Decision 1905
## (as the orchard's 1900) shares this one adapter between them. The owner holds every number and decides each next
## step; this task only lets the brain walk where the owner says and stand at the work, and tells the owner when it
## arrives, when it is called away and when it is over. Called away by an order, a meal or the night, its resident keeps
## the job to come back to (`unfinished`) when the owner lets her.
##
## The owner answers, by name, for row `job` opened with `serial`: `first_site`, `arrived`, `drive`, `called_away`
## (whether she keeps the job), `unfinished_of`, `doing_text` and `must_finish`. Presentation only.

## The owner (untyped: it preloads the script that extends this one), held WEAKLY so a Restart frees both.
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
	"""The owner, or null once it is gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the owner sends it first (where it stands, once the owner is gone)."""
	var owner: Object = _owner()
	return owner.call(&"first_site", job, serial) if owner != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the place the owner sent it."""
	var owner: Object = _owner()
	if owner != null:
		owner.call(&"arrived", job, serial, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the owner drives (false once its part is over, or the owner is gone)."""
	var owner: Object = _owner()
	return owner != null and bool(owner.call(&"drive", job, serial, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away (an order, the night, a meal call, a release, a walk it could not finish)."""
	var owner: Object = _owner()
	_called_away = true
	_kept = owner != null and bool(owner.call(&"called_away", job, serial, brain))


func unfinished() -> RefCounted:
	"""The job to come back to (the owner's `unfinished_of`): asked before it is called away (an action card's "goes
	back to it after"), the job while it lasts; after, only one the owner let its resident keep -- not a walk it could
	not finish, nor one the board itself took away (Pause, Reassign)."""
	var owner: Object = _owner()
	if owner == null or (_called_away and not _kept):
		return null
	return owner.call(&"unfinished_of", job, serial) as RefCounted


func label() -> String:
	"""What the panel says it is doing."""
	var owner: Object = _owner()
	return String(owner.call(&"doing_text", job, serial)) if owner != null else ""


func urgent() -> bool:
	"""While the owner says its part must finish -- a load in hand, or a crossing entered -- the night does not take it
	to bed first (decision 0222: a load in hand is delivered; MOVE-REQ-007: a crossing entered is finished)."""
	var owner: Object = _owner()
	return owner != null and bool(owner.call(&"must_finish", job, serial))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the owner offers the job again)."""
	return false
