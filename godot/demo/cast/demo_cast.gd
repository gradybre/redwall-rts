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

const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const PLACEHOLDER_COUNT: int = 6
const BASE_SEED: int = 196
const SEED_STRIDE: int = 7919
const NO_POI_RING_M: float = 1.5

var _space: CastSpaceScript = null
var _actors: Array[Node3D] = []


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
			actor.setup_creature(StringName(keys[i]), cast[keys[i]], _space, BASE_SEED + i * SEED_STRIDE)
		actor.name = String(actor.creature_key)
		_place(actor, i, count)
		add_child(actor)
		_actors.append(actor)


func actors() -> Array[Node3D]:
	"""Every spawned resident, in spawn order."""
	return _actors.duplicate()


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
