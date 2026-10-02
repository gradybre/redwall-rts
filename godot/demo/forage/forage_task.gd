extends "res://demo/tunnel/tunnel_task.gd"
## One resident's seat on a foraging trip (forage_trips.gd): walking to its spot in the woods, gathering its share and
## carrying the haul to its store. Decision 0681 (live demo). A thin adapter like the ferry's (ferry_task.gd): the trips
## hold every number (what is claimed, gathered, carried and stored, and how much work is done) and decide each next
## step; this task only lets the brain walk where the trips say and stand at the work (resident_brain.gd TASKS), and
## tells them when it arrives, when it is called away and when it is over -- so an interruption loses nothing: a haul in
## hand is set down where it is for the next to fetch.

## The trips (forage_trips.gd; untyped: it preloads this script), held WEAKLY so a Restart frees both.
var _owner_ref: WeakRef = null
var job: int = -1
var serial: int = 0


func _init(owner: RefCounted, p_job: int, p_serial: int) -> void:
	"""Seat row `p_job` (opened with `p_serial`) of `owner`'s."""
	_owner_ref = weakref(owner)
	job = p_job
	serial = p_serial


func _owner() -> Object:
	"""The trips, or null once they are gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the trips send it first (where it stands, once they are gone)."""
	var trips: Object = _owner()
	return trips.call(&"first_site", job, serial) if trips != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the place the trips sent it."""
	var trips: Object = _owner()
	if trips != null:
		trips.call(&"arrived", job, serial, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the trips drive (false once its part is over, or the trips are gone)."""
	var trips: Object = _owner()
	return trips != null and bool(trips.call(&"drive", job, serial, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away (an order, the night, a meal call, a release, a walk it could not finish)."""
	var trips: Object = _owner()
	if trips != null:
		trips.call(&"called_away", job, serial, brain)


func label() -> String:
	"""What the panel says it is doing."""
	var trips: Object = _owner()
	return String(trips.call(&"doing_text", job, serial)) if trips != null else ""


func urgent() -> bool:
	"""While it carries its haul, the night and a meal call wait (decision 0222: a load in hand is delivered)."""
	var trips: Object = _owner()
	return trips != null and bool(trips.call(&"must_finish", job, serial))


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (the trips offer the seat again)."""
	return false
