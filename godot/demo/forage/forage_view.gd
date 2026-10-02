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
## What each resident holds for the trips (&"": nothing), and who held something last frame and this.
var _held: Array[StringName] = []
var _holding: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()


func configure(trips: TripsScript, props: PropsScript, residents: int) -> void:
	"""Draw these trips with these props for `residents` residents."""
	name = "ForageView"
	_trips = trips
	_props = props
	_held.resize(residents)
	_held.fill(&"")


func refresh() -> void:
	"""Each seat's forager holds what the trips say it carries; one who held a basket and no longer carries drops it."""
	if _trips == null or _props == null:
		return
	_next.resize(0)
	for j: int in Rules.MAX_JOBS:
		var who: int = _trips.j_worker[j]
		if _trips.j_live[j] == 0 or who < 0 or who >= _held.size():
			continue
		var key: StringName = _trips.held_key_of_job(j)
		if key != &"":
			_show_held(who, key)
			_next.append(who)
	for who: int in _holding:
		if not _next.has(who):
			_show_held(who, &"")
	var swap: PackedInt32Array = _holding
	_holding = _next
	_next = swap


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
