extends "res://demo/tunnel/tunnel_task.gd"
## One resident's part in a fishery job -- a fishing trip's seat, a trap's collection, the rack, the mill, making or
## mending gear (fishery.gd). Decision 0431 (live demo). A thin adapter like the kitchen's (kitchen_task.gd): the
## fishery holds every number (what is reserved, caught, carried and how much work is done) and decides each next
## step; this task only lets the brain walk where the fishery says and stand at the work (resident_brain.gd TASKS),
## and tells the fishery when it arrives, when it is called away and when it is over -- so an interruption loses
## nothing: a load in hand is set down at its landing for the next fisher (REQ-SET-054: "retain cargo there").

## The fishery (fishery.gd; untyped: it preloads this script), held WEAKLY so a Restart frees both.
var _owner_ref: WeakRef = null
var job: int = -1
var serial: int = 0


func _init(owner: RefCounted, p_job: int, p_serial: int) -> void:
	"""Job row `p_job` (opened with `p_serial`) of `owner`'s."""
	_owner_ref = weakref(owner)
	job = p_job
	serial = p_serial


func _owner() -> Object:
	"""The fishery, or null once it is gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the fishery sends it first (where it stands, once the fishery is gone)."""
	var fishery: Object = _owner()
	return fishery.call(&"first_site", job, serial) if fishery != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the place the fishery sent it."""
	var fishery: Object = _owner()
	if fishery != null:
		fishery.call(&"arrived", job, serial, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the fishery drives (false once its part is over, or the fishery is gone)."""
	var fishery: Object = _owner()
	return fishery != null and bool(fishery.call(&"drive", job, serial, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away (an order, the night, a release, a walk it could not finish)."""
	var fishery: Object = _owner()
	if fishery != null:
		fishery.call(&"called_away", job, serial, brain)


func label() -> String:
	"""What the panel says it is doing."""
	var fishery: Object = _owner()
	return String(fishery.call(&"doing_text", job, serial)) if fishery != null else ""


func urgent() -> bool:
	"""While it carries a load (a catch, dried fish, flour, made gear) or is out on the water or the ice, the night does
	not take it to bed first (decision 0222: a load in hand is delivered; MOVE-REQ-007: a crossing entered is
	finished)."""
	var fishery: Object = _owner()
	return fishery != null and bool(fishery.call(&"must_finish", job, serial))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the fishery offers the job again)."""
	return false
