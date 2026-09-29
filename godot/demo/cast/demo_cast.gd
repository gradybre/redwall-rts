extends Node3D
## The live demo's residents. Decision 0196. Presentation only: scripted wandering, not the
## simulation's movement (the MOVE gates are open), and nothing here feeds the simulation.
##
## `build()` spawns one actor (demo_actor.gd) per creature in the staged manifest -- or
## PLACEHOLDER_COUNT capsules when nothing is staged -- each at its own starting POI. They then
## wander between the world's POIs, sharing one CastSpace for slots, obstacles and separation.
##
## The world hands over:
##   points:    [{"name": StringName, "position": Vector3, "face": Vector3,
##                "activities": Array[StringName], "capacity": int}]
##   obstacles: [Vector3(x, radius, z)] -- circle centre (x, z) and radius y, in metres
## on flat ground at y = 0. Activities name clips; one this creature lacks plays as idle.
## Each actor's random choices come from its own seed, so a run at a fixed step repeats exactly.
##
## ORDERS (demo/control/ drives these): `order_move()`, `order_work()` and `release()` take actor
## indices (positions in `actors()`); formations and slot assignment are cast_orders.gd. Orders stay
## inside `set_bounds()` -- the world's walkable area -- which defaults to unbounded.

const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")

const PLACEHOLDER_COUNT: int = 6
const BASE_SEED: int = 196
const SEED_STRIDE: int = 7919
const NO_POI_RING_M: float = 1.5

var _space: CastSpaceScript = null
var _actors: Array[Node3D] = []
var _bounds: Rect2 = Rect2(-1e4, -1e4, 2e4, 2e4)


func build(manifest: Dictionary, points: Array[Dictionary], obstacles: Array[Vector3]) -> void:
	"""Spawn the cast: one actor per manifest creature (or placeholders), at distinct starting POIs."""
	_clear()
	_space = CastSpaceScript.new()
	_space.setup(points, obstacles)
	var cast: Dictionary = manifest.get("cast", {})
	var keys: Array = cast.keys()
	var count := keys.size() if not keys.is_empty() else PLACEHOLDER_COUNT
	for i in count:
		var actor: DemoActorScript = DemoActorScript.new()
		if keys.is_empty():
			actor.setup_placeholder(i, _space, BASE_SEED + i * SEED_STRIDE)
		else:
			actor.setup_creature(i, StringName(keys[i]), cast[keys[i]], _space, BASE_SEED + i * SEED_STRIDE)
		actor.name = String(actor.creature_key)
		actor.brain.homes = CastRoutinesScript.homes_for(actor.creature_key, _space.poi_names)
		actor.brain.socials = CastRoutinesScript.socials_for(_space.poi_names)
		_place(actor, i, count)
		add_child(actor)
		_actors.append(actor)


func actors() -> Array[Node3D]:
	"""Every spawned resident, in spawn order."""
	return _actors.duplicate()


func actor(i: int) -> Node3D:
	"""Actor `i` in spawn order, without copying the list (per-frame safe)."""
	return _actors[i]


func actor_count() -> int:
	"""How many actors were spawned."""
	return _actors.size()


func set_bounds(bounds: AABB) -> void:
	"""The walkable area (its x/z extent) that ordered formations must stay inside."""
	_bounds = Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)


func bounds() -> Rect2:
	"""The walkable area (x, z) orders and tunnels stay inside."""
	return _bounds


func order_move(members: PackedInt32Array, point: Vector3) -> Dictionary:
	"""Send these actors to stand in a formation at `point`. {"ok": bool, "at": Vector3}: where the
	order landed (snapped when `point` was not standable), or ok false when refused."""
	var spots := CastOrdersScript.order_move(_space, _brains(members), Vector2(point.x, point.z), _bounds)
	if spots.is_empty():
		return {"ok": false, "at": point}
	return {"ok": true, "at": Vector3(spots[0].x, 0.0, spots[0].y)}


func order_work(members: PackedInt32Array, poi: int) -> Dictionary:
	"""Send these actors to work at `poi`. {"ok": true, "at": the POI, "placed": how many got a slot}."""
	var placed := CastOrdersScript.order_work(_space, _brains(members), poi, _bounds)
	var at := _space.poi_position[poi]
	return {"ok": true, "at": Vector3(at.x, 0.0, at.y), "placed": placed}


func poi_at(point: Vector3) -> int:
	"""The POI whose standing area is under `point`, or -1."""
	return CastOrdersScript.poi_at(_space, Vector2(point.x, point.z))


func release(members: PackedInt32Array) -> void:
	"""Hand these actors back to wandering."""
	CastOrdersScript.release(_brains(members))


func _brains(members: PackedInt32Array) -> Array[BrainScript]:
	"""The brains of these actor indices (unknown indices skipped)."""
	var out: Array[BrainScript] = []
	for i in members:
		if i >= 0 and i < _actors.size():
			out.append((_actors[i] as DemoActorScript).brain)
	return out


func space() -> CastSpaceScript:
	"""The shared POI/obstacle/resident state (null before build)."""
	return _space


func _place(actor: DemoActorScript, i: int, count: int) -> void:
	"""Start actor i at its own POI, spread evenly through the list; share, or ring the origin, if short."""
	var n := _space.poi_position.size()
	var poi := -1
	if n > 0:
		poi = floori(float(i * n) / float(count)) if n >= count else i % n
		if _space.free_slot(poi) < 0:
			poi = _space.choose_poi(-1, actor.brain.rng)
	if poi < 0:
		var angle := TAU * float(i) / float(count)
		actor.place(Vector2(cos(angle), sin(angle)) * NO_POI_RING_M, angle, -1, -1)
		return
	var slot := _space.free_slot(poi)
	_space.reserve(poi, slot)
	var face := _space.poi_face[poi]
	var face_yaw := BrainScript.yaw_of(face) if face != Vector2.ZERO else 0.0
	actor.place(_space.slot_position(poi, slot), face_yaw, poi, slot)


func _clear() -> void:
	"""Remove any cast from an earlier build."""
	for actor in _actors:
		if is_instance_valid(actor):
			remove_child(actor)
			actor.free()
	_actors.clear()
	_space = null
