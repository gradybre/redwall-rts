extends "res://demo/tunnel/tunnel_task.gd"
## One resident's place in the regatta's race (regatta.gd, decision 0438): to the boathouse jetty, aboard its boat, the
## race, and ashore again. A thin adapter like the fishery's and the ferry's: the regatta holds every number and decides
## each step; this task only lets the brain walk where the regatta says and tells the regatta when it arrives, when it
## is called away and when it is over.

## The regatta (regatta.gd; untyped: it preloads this script), held WEAKLY so a Restart frees both.
var _owner_ref: WeakRef = null
## Which crew place this is (regatta.gd's crew order: boat x 2 + seat).
var place: int = -1


func _init(owner: RefCounted, p_place: int) -> void:
	"""Crew place `p_place` of `owner`'s race."""
	_owner_ref = weakref(owner)
	place = p_place


func _owner() -> Object:
	"""The regatta, or null once it is gone."""
	return _owner_ref.get_ref()


func site(brain: RefCounted) -> Vector2:
	"""Where the regatta sends it: its wait by the boathouse jetty."""
	var regatta: Object = _owner()
	return regatta.call(&"crew_site", place) if regatta != null else brain.get(&"position")


func arrived(brain: RefCounted) -> void:
	"""At the jetty."""
	var regatta: Object = _owner()
	if regatta != null:
		regatta.call(&"crew_arrived", place, brain)


func step(brain: RefCounted, delta: float) -> bool:
	"""One frame: the regatta drives (false once the race is over for it, or the regatta is gone)."""
	var regatta: Object = _owner()
	return regatta != null and bool(regatta.call(&"crew_drive", place, brain, delta))


func cancel(brain: RefCounted) -> void:
	"""Called away before it boarded (aboard, it is held: `water_hold`)."""
	var regatta: Object = _owner()
	if regatta != null:
		regatta.call(&"crew_called_away", place, brain)


func label() -> String:
	"""What the panel says it is doing."""
	var regatta: Object = _owner()
	return String(regatta.call(&"crew_text", place)) if regatta != null else ""


func urgent() -> bool:
	"""The race is an occasion of its own: no meal call or bedtime takes a crew off it."""
	return true


func holds_when_lost() -> bool:
	"""Lost on the way, it goes back to its own routine (its boat then does not race)."""
	return false
