extends RefCounted
## Ground marks for the demo's select-and-command layer: the selection and hover rings and the
## order marker. Decision 0196. One flat annulus mesh, built once and shared; each mark is a
## MeshInstance3D scaled to size, with its own unshaded material so it can fade on its own.

const Palette := preload("res://demo/ui/woodland_palette.gd")

## The shared annulus: outer radius 1, inner radius RING_INNER, lying flat on y = 0.
const RING_INNER: float = 0.76
const RING_SEGMENTS: int = 48
## Marks float this far above the ground so they are not lost in it.
const LIFT_M: float = 0.035

const SELECTED: Color = Palette.BRASS
const HOVER: Color = Color(Palette.CREAM, 0.45)
const ORDERED: Color = Palette.EMBER
const REFUSED: Color = Palette.CLAY

static var _ring: ArrayMesh = null


static func ring_mesh() -> ArrayMesh:
	"""The shared unit annulus (built on first use)."""
	if _ring == null:
		_ring = _annulus(RING_INNER, 1.0, RING_SEGMENTS)
	return _ring


static func _annulus(inner: float, outer: float, segments: int) -> ArrayMesh:
	"""A flat ring of `segments` quads between two radii, facing up."""
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for k in segments:
		var a0 := TAU * float(k) / float(segments)
		var a1 := TAU * float(k + 1) / float(segments)
		var p := [Vector3(cos(a0) * inner, 0.0, sin(a0) * inner), Vector3(cos(a0) * outer, 0.0, sin(a0) * outer),
			Vector3(cos(a1) * outer, 0.0, sin(a1) * outer), Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)]
		for i in [0, 2, 1, 0, 3, 2]:
			vertices.append(p[i])
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func make_ring(colour: Color) -> MeshInstance3D:
	"""One ring mark with its own unshaded, see-through material; hidden until placed."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = colour
	material.render_priority = 1
	var mark := MeshInstance3D.new()
	mark.mesh = ring_mesh()
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.visible = false
	return mark


static func set_alpha(mark: MeshInstance3D, colour: Color, alpha: float) -> void:
	"""Tint a mark (its own material) with `colour` at `alpha`."""
	var material := mark.material_override as StandardMaterial3D
	material.albedo_color = Color(colour.r, colour.g, colour.b, colour.a * alpha)
