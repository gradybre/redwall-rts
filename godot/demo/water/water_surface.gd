extends RefCounted
## The water surfaces: one mesh and ONE material per body, built once on the water grid, and the
## flow clock that drives them. Decision 0196 (live demo), water foundation. Presentation only.
##
## Each grid cell whose deepest corner is within SURFACE_OVERLAP_M of the waterline goes to the
## body whose margin wins at that corner, so the stream's and the pond's surfaces tile without
## overlapping. The surface is flat at the body's level; the carved bank rises through it, so the
## visible shoreline is exactly where the integer map puts the waterline.
##
## Colours are blends of the locked ART-LOCK-001 pigments (world_look.gd), as the ground's are:
## sandy shallows (brass/sage/oat), deep water darkening from ink, and the sky's own hazy horizon
## (cream/sage, world_look.gd's `sky_horizon_color`) in the fresnel reflection. The engine adds the
## real sky's specular on top (REFLECTION_SOURCE_SKY).
##
## TIME. `advance(frame_usec)` adds the demo clock's microseconds for the frame (0 while paused) to
## an integer total, and the shader's phase is that total modulo one cycle -- so the flow freezes
## when the game pauses, runs 2x / 4x with it, and never loses precision however long the demo runs.
## Two shader parameters per frame, no allocation.

const Look := preload("res://demo/world/world_look.gd")
const Rules := preload("res://demo/water/water_rules.gd")
const WaterGridScript := preload("res://demo/water/water_grid.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WATER_SHADER := preload("res://demo/water/water.gdshader")

## Cells this far beyond the waterline still carry surface, tucked under the bank (m).
const SURFACE_OVERLAP_M: float = 0.6
## One flow-map cycle, in demo microseconds (and the shader's `cycle_seconds`).
const CYCLE_USEC: int = 2000000
const USEC_PER_SECOND: int = 1000000
## Still water's ripple drift, m/s, written as the flow of every vertex the map calls still (the
## pond), so its ripples creep slowly and stream and pond share one flow field without a seam.
const POND_DRIFT: Vector2 = Vector2(0.045, 0.03)
## The sky's top colour when no world sky is given (world_look.gd's `_sky()` sky_top_color).
const DEFAULT_SKY: Color = Color(0.36, 0.52, 0.7)
## Transparent draw order: the bank film (0) first, then the water over it, then the overlay (2).
const RENDER_PRIORITY: int = 1
const RIPPLE_SEED: int = 23
const FOAM_SEED: int = 29

const PARAM_PHASE: StringName = &"flow_phase"
const PARAM_FADE: StringName = &"fade"

var nodes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var _usec: int = 0


func build(grid: WaterGridScript, map: WaterMapScript, sky: Color) -> void:
	"""One surface mesh and material per body of `map`, on `grid`, reflecting the `sky` colour."""
	var ripple: NoiseTexture2D = _noise(RIPPLE_SEED, 0.035, 4, true)
	var foam: NoiseTexture2D = _noise(FOAM_SEED, 0.05, 3, false)
	for body: int in map.body_count():
		var material: ShaderMaterial = _material(ripple, foam, sky)
		var node := MeshInstance3D.new()
		node.name = "WaterSurface_%s" % map.body_name(body)
		node.mesh = _mesh(grid, map, body, material)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodes.append(node)
		materials.append(material)


func advance(frame_usec: int) -> void:
	"""Add one frame of demo time (0 while paused) and move every surface's flow phase."""
	_usec = (_usec + frame_usec) % CYCLE_USEC
	var phase: float = float(_usec) / float(CYCLE_USEC)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(PARAM_PHASE, phase)


func phase_usec() -> int:
	"""Where in its cycle the flow is, in demo microseconds (0 .. CYCLE_USEC - 1)."""
	return _usec


func _material(ripple: Texture2D, foam: Texture2D, sky: Color) -> ShaderMaterial:
	"""A body's own material: shared textures and colours."""
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter(&"shallow_color", Look.SAGE.lerp(Look.BRASS, 0.3))
	material.set_shader_parameter(&"deep_color", Look.INK.lerp(Look.SAGE, 0.08).darkened(0.4))
	material.set_shader_parameter(&"horizon_color", Look.CREAM.lerp(Look.SAGE, 0.25))
	material.set_shader_parameter(&"sky_color", sky)
	material.set_shader_parameter(&"foam_color", Look.CREAM)
	material.set_shader_parameter(&"ripple_normal", ripple)
	material.set_shader_parameter(&"foam_noise", foam)
	material.set_shader_parameter(&"cycle_seconds", float(CYCLE_USEC) / float(USEC_PER_SECOND))
	material.set_shader_parameter(PARAM_PHASE, 0.0)
	material.set_shader_parameter(PARAM_FADE, 1.0)
	return material


func _mesh(grid: WaterGridScript, map: WaterMapScript, body: int, material: Material) -> ArrayMesh:
	"""The body's flat surface over every cell it owns, with depth, margin and flow per vertex."""
	var count: int = grid.xs.size() * grid.zs.size()
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var flows := PackedVector2Array()
	vertices.resize(count)
	colours.resize(count)
	flows.resize(count)
	var y: float = -Rules.to_m(map.body_level_drop_u(body))
	for k: int in count:
		var at: Vector2 = grid.position_m(k % grid.xs.size(), k / grid.xs.size())
		vertices[k] = Vector3(at.x, y, at.y)
		var margin: float = clampf(Rules.to_m(grid.margin_u[k]), -1.0, 1.0)
		colours[k] = Color(clampf(Rules.to_m(grid.depth_u[k]) / 2.0, 0.0, 1.0), margin * 0.5 + 0.5, 0.0, 1.0)
		flows[k] = _vertex_flow(grid, map, k)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = flows
	arrays[Mesh.ARRAY_NORMAL] = _up_normals(count)
	arrays[Mesh.ARRAY_INDEX] = _owned_cells(grid, body)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func _vertex_flow(grid: WaterGridScript, map: WaterMapScript, k: int) -> Vector2:
	"""Vertex `k`'s surface motion in m/s: the map's flow on a stream, POND_DRIFT on still water."""
	if map.body_kind(grid.body[k]) == WaterMapScript.KIND_POND:
		return POND_DRIFT
	return Vector2(Rules.to_m(grid.flow_x[k]), Rules.to_m(grid.flow_z[k]))


static func _up_normals(count: int) -> PackedVector3Array:
	"""`count` straight-up normals: the surface is flat; the shader's normal map does the rest."""
	var normals := PackedVector3Array()
	normals.resize(count)
	normals.fill(Vector3.UP)
	return normals


static func _owned_cells(grid: WaterGridScript, body: int) -> PackedInt32Array:
	"""The triangles of every cell near the water whose deepest corner belongs to `body`."""
	var out := PackedInt32Array()
	var nx: int = grid.xs.size()
	var reach: int = -Rules.to_u(SURFACE_OVERLAP_M)
	for j: int in grid.zs.size() - 1:
		for i: int in nx - 1:
			var a: int = grid.index(i, j)
			var corners: PackedInt32Array = [a, a + 1, a + nx, a + nx + 1]
			var best: int = a
			for k: int in corners:
				if grid.margin_u[k] > grid.margin_u[best]:
					best = k
			if grid.margin_u[best] <= reach or grid.body[best] != body:
				continue
			for k: int in [corners[3], corners[2], corners[1], corners[2], corners[0], corners[1]]:
				out.append(k)
	return out


static func _noise(seed_value: int, frequency: float, octaves: int, as_normal: bool) -> NoiseTexture2D:
	"""A seamless, seeded noise texture (optionally a normal map), like the ground's."""
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = as_normal
	texture.bump_strength = 4.0
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture
