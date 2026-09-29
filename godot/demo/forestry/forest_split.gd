extends RefCounted
## A tree model cut in two at its felling cut. Decision 0196 (live demo). Presentation only.
##
## A felled tree must leave its root mound and a stub standing while the trunk and crown above the
## cut topple (forest_roots.gd: a staged oak's mound is ~9 m across; turning the whole model over
## would lift the mound off the ground like a lid). So the model's own mesh is split once per model
## key: every triangle whose lowest corner stands below the cut goes to the LOWER mesh, every other
## to the UPPER one. The vertex arrays are shared, only the index lists differ, and each surface keeps
## its material. Done at most once per key (the oak and the beech, ~5,800 triangles each), on the first
## fall of that kind; nothing here runs per frame.
##
## A placeholder (no staged model) is a plain box with nothing above any cut: `parts_into` refuses it,
## and the whole box falls instead.

const IntMath := preload("res://scripts/core/int_math.gd")

const REFUSE_NO_MESH: String = "NO_MESH"
const REFUSE_NOTHING_ABOVE: String = "NOTHING_ABOVE_THE_CUT"

## key -> [lower: ArrayMesh, upper: ArrayMesh, mesh-to-model transform].
var _parts: Dictionary = {}


func parts_into(key: StringName, model: Node3D, cut_model_y: float, out: Array) -> bool:
	"""`key`'s [lower, upper, mesh transform] split at `cut_model_y` (in `model`'s own units), into
	`out`; made the first time a key is asked for. False (nothing written) for a model with no mesh or
	nothing above the cut."""
	if not _parts.has(key):
		_parts[key] = _split(model, cut_model_y)
	var parts: Array = _parts[key]
	if parts.is_empty():
		return false
	out.assign(parts)
	return true


func _split(model: Node3D, cut_model_y: float) -> Array:
	"""Split `model`'s first mesh at the cut; [] when it cannot be."""
	var found: Array = _find_mesh(model, Transform3D.IDENTITY, model)
	if found.is_empty() or not found[0] is ArrayMesh:
		return []
	var mesh := found[0] as ArrayMesh
	var xform: Transform3D = found[1]
	var lower := ArrayMesh.new()
	var upper := ArrayMesh.new()
	for s: int in mesh.get_surface_count():
		_split_surface(mesh, s, xform, cut_model_y, lower, upper)
	if upper.get_surface_count() == 0:
		return []
	return [lower, upper, xform]


func _split_surface(mesh: ArrayMesh, s: int, xform: Transform3D, cut_y: float, lower: ArrayMesh, upper: ArrayMesh) -> void:
	"""One surface's triangles into the lower or the upper mesh, by their lowest corner."""
	var arrays: Array = mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		index = PackedInt32Array(range(verts.size()))
	var below := PackedInt32Array()
	var above := PackedInt32Array()
	for f: int in index.size() / 3:
		var low: float = minf((xform * verts[index[3 * f]]).y, minf((xform * verts[index[3 * f + 1]]).y, (xform * verts[index[3 * f + 2]]).y))
		for corner: int in 3:
			if low < cut_y:
				below.append(index[3 * f + corner])
			else:
				above.append(index[3 * f + corner])
	_add_part(lower, arrays, below, mesh.surface_get_material(s))
	_add_part(upper, arrays, above, mesh.surface_get_material(s))


static func _add_part(part: ArrayMesh, arrays: Array, index: PackedInt32Array, material: Material) -> void:
	"""One surface of `part`: the shared vertex arrays with this index list."""
	if index.is_empty():
		return
	var copy: Array = arrays.duplicate()
	copy[Mesh.ARRAY_INDEX] = index
	part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy)
	part.surface_set_material(part.get_surface_count() - 1, material)


static func _find_mesh(node: Node, to_root: Transform3D, root: Node) -> Array:
	"""[mesh, its transform in `root`'s own space] of the first MeshInstance3D at or under `node`, or []."""
	var here: Transform3D = to_root
	if node != root and node is Node3D:
		here = to_root * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return [(node as MeshInstance3D).mesh, here]
	for child: Node in node.get_children():
		var found: Array = _find_mesh(child, here, root)
		if not found.is_empty():
			return found
	return []


func has_parts(key: StringName) -> bool:
	"""Whether `key` was split (checks)."""
	return _parts.has(key) and not (_parts[key] as Array).is_empty()
