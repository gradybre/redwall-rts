extends RefCounted
## Authored presentation treatments, not a construction recipe, support catalog or room service bonus.

const SurfaceShader := preload("res://demo/burrow/modular_surface.gdshader")
const EARTH: int = 0
const TIMBER: int = 1
const STONE: int = 2
const FLOOR: int = 0
const WALL: int = 1
const CEILING: int = 2
const FINISH_NAMES: Array[String] = ["Packed earth", "Worn timber", "Warm stone"]
const MESH_KEYS: Array[String] = ["floor_mesh", "wall_mesh", "ceiling_mesh", "frontier_mesh"]

var _finishes: PackedInt32Array = PackedInt32Array([EARTH, EARTH, EARTH])
var _cache: Dictionary = {}
var _cut_y: float = 1000000000.0


func set_finishes(floor_finish: int, wall_finish: int, ceiling_finish: int) -> bool:
	"""Select whole surface categories atomically; compatibility and ordering belong to the caller."""
	for finish: int in [floor_finish, wall_finish, ceiling_finish]:
		if finish < EARTH or finish > STONE:
			return false
	_finishes = PackedInt32Array([floor_finish, wall_finish, ceiling_finish])
	return true


func selections() -> PackedInt32Array:
	"""Expose a copy of presentation selections without allowing edits to the cached policy."""
	return _finishes.duplicate()


func apply(shell: Dictionary) -> bool:
	"""Apply materials to existing category meshes, preserving all vertices and caller state."""
	if not shell.get("ok", false):
		return false
	for key: String in MESH_KEYS:
		if not shell.get(key) is ArrayMesh:
			return false
	for category: int in range(4):
		var mesh: ArrayMesh = shell[MESH_KEYS[category]]
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, material(EARTH if category == 3 else _finishes[category], WALL if category == 3 else category))
	return true


func material(finish: int, category: int) -> ShaderMaterial:
	"""Cache a treatment per whole category; shader UVs are metres rather than normalized room bounds."""
	if finish < EARTH or finish > STONE or category < FLOOR or category > CEILING:
		return null
	var key: int = finish * 3 + category
	if not _cache.has(key):
		var result: ShaderMaterial = ShaderMaterial.new()
		result.shader = SurfaceShader
		result.set_shader_parameter("finish_kind", finish)
		result.set_shader_parameter("surface_kind", category)
		result.set_shader_parameter("cut_y", _cut_y)
		_cache[key] = result
	return _cache[key]


func set_cutaway_y(height_m: float) -> void:
	"""Follow the owning view's section plane; this presentation change rebuilds no geometry."""
	_cut_y = height_m
	for value: ShaderMaterial in _cache.values():
		value.set_shader_parameter("cut_y", height_m)
