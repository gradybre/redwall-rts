extends Node3D
## The foraging trips drawn (decision 0681): a forager carrying its haul home holds the fishery's basket (the props'
## `basket`, staged library art; no new asset) in its hands. Presentation only; one pass over the seat rows a frame, a
## model changed only when it changes (the fishery view's rule).

const TripsScript := preload("res://demo/forage/forage_trips.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")

var _trips: TripsScript = null
var _props: PropsScript = null
## What each resident holds for the trips (&"": nothing), and which carry a haul this frame.
var _held: Array[StringName] = []
var _carrying: PackedByteArray = PackedByteArray()


func configure(trips: TripsScript, props: PropsScript, residents: int) -> void:
	"""Draw these trips with these props for `residents` residents."""
	name = "ForageView"
	_trips = trips
	_props = props
	_held.resize(residents)
	_held.fill(&"")
	_carrying.resize(residents)


func refresh() -> void:
	"""Each seat's forager holds what the trips say it carries; one who held a basket and no longer carries drops it.
	One pass over the seat rows and one over the residents, flags in a column sized once (no allocation a frame)."""
	if _trips == null or _props == null:
		return
	_carrying.fill(0)
	for j: int in Rules.MAX_JOBS:
		var who: int = _trips.j_worker[j]
		if _trips.j_live[j] == 1 and who >= 0 and who < _held.size() and _trips.held_key_of_job(j) != &"":
			_carrying[who] = 1
	for who: int in _held.size():
		_show_held(who, TripsScript.BASKET_KEY if _carrying[who] == 1 else &"")


func _show_held(who: int, key: StringName) -> void:
	"""Resident `who` holds the model `key` (&"": nothing)."""
	if _held[who] == key:
		return
	var actor: DemoActorScript = _trips.cast_actor(who)
	if key == &"":
		actor.drop_held()
	else:
		var bound: AABB = _props.drawn_bound(key)
		actor.hold(_props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key))
	_held[who] = key


func holding(who: int) -> StringName:
	"""What resident `who` holds for the trips (&"": nothing; the checks)."""
	return _held[who] if who >= 0 and who < _held.size() else &""
