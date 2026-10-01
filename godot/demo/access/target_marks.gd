extends Node3D
## "SHOW INTERACTIVE TARGETS": a brass ring on every thing in the village a click selects. Decision 0471 (review
## UX-023, the Keyboard planner preset). Presentation only.
##
## The targets are world_targets.gd's: residents, crop beds, trees, bridges and tunnel mouths on the surface; rooms
## (and the mouths again) below, in the U view. Two MultiMeshes, one per view (demo_layers.gd: a mark that shows in
## both views is a pair): the surface's on SURFACE_MARKS a little above the ground, the underground's on every level's
## marks layer at the target's own depth. Rings are drawn unshaded, without depth test, so a ring under a crown or a
## roof still shows -- that is what they are for.
##
## COST. One flat unit ring mesh, built once; each target is one instance, placed and scaled to its kind's radius.
## Re-placed REFRESH_S apart (residents walk): at the demo's ~190 targets (most of them trees) that is ~190 instance
## transforms ten times a second, and the instance buffers only grow. Hidden, it does nothing.

const TargetsScript := preload("res://demo/access/world_targets.gd")
const Layers := preload("res://demo/demo_layers.gd")

const REFRESH_S: float = 0.1
const SEGMENTS: int = 24
## The ring's band as a share of its radius, and how far above its target's ground it floats (m).
const BAND_SHARE: float = 0.08
const LIFT_M: float = 0.06
const COLOUR: Color = Color(0.96, 0.78, 0.30, 0.92)

var _targets: TargetsScript = null
var _surface: MultiMeshInstance3D = null
var _below: MultiMeshInstance3D = null
var _refresh_in: float = 0.0
## The transform being written (reused).
var _xform: Transform3D = Transform3D.IDENTITY
## The rings' own listing (never the object list's columns, which must not move under it), grown only.
var _kinds: PackedByteArray = PackedByteArray()
var _ids: PackedInt32Array = PackedInt32Array()
## Rings drawn at the last rebuild, on the surface and below (checks).
var surface_rings: int = 0
var below_rings: int = 0


func _init() -> void:
	"""Hidden; the ring mesh and the two MultiMeshes made once."""
	name = "TargetMarks"
	visible = false
	var ring: ArrayMesh = unit_ring()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = COLOUR
	material.render_priority = 10
	_surface = _instance(ring, material, Layers.SURFACE_MARKS)
	_below = _instance(ring, material, Layers.MARKS_ALL)


static func unit_ring() -> ArrayMesh:
	"""A flat band from 1 - BAND_SHARE to 1 round the origin, in the XZ plane (two triangles a segment)."""
	var points := PackedVector3Array()
	var inner: float = 1.0 - BAND_SHARE
	for s: int in SEGMENTS:
		var a: float = TAU * float(s) / float(SEGMENTS)
		var b: float = TAU * float(s + 1) / float(SEGMENTS)
		var ia := Vector3(cos(a) * inner, 0.0, sin(a) * inner)
		var oa := Vector3(cos(a), 0.0, sin(a))
		var ob := Vector3(cos(b), 0.0, sin(b))
		var ib := Vector3(cos(b) * inner, 0.0, sin(b) * inner)
		points.append_array([ia, oa, ob, ia, ob, ib])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _instance(ring: Mesh, material: Material, layers_mask: int) -> MultiMeshInstance3D:
	"""One view's MultiMesh of rings, on its layers, casting no shadow."""
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = ring
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.layers = layers_mask
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func configure(targets: TargetsScript) -> void:
	"""Ring these targets."""
	_targets = targets


func set_shown(on: bool) -> void:
	"""Show the rings (placed at once) or hide them."""
	visible = on
	_refresh_in = 0.0
	if on:
		rebuild()


func _process(delta: float) -> void:
	"""Keep the rings on their targets while shown."""
	if not visible or _targets == null:
		return
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	rebuild()


func rebuild() -> void:
	"""Every target's ring, placed again: the surface's, then the underground's."""
	var count: int = _targets.collect_into(TargetsScript.ALL_KINDS, _kinds, _ids) if _targets != null else 0
	surface_rings = _place(_surface.multimesh, false, count)
	below_rings = _place(_below.multimesh, true, count)


func _place(multi: MultiMesh, below: bool, count: int) -> int:
	"""One view's rings: on the surface every kind but rooms, below the rooms and the mouths. Returns how many."""
	if multi.instance_count < count:
		multi.instance_count = count
	var rings: int = 0
	for k: int in count:
		var kind: int = _kinds[k]
		var wanted: bool = (kind == TargetsScript.KIND_ROOM or kind == TargetsScript.KIND_MOUTH) if below \
			else kind != TargetsScript.KIND_ROOM
		var at: Vector3 = _targets.point_at(kind, _ids[k]) if wanted else Vector3.INF
		if not wanted or not at.is_finite():
			continue
		var radius: float = TargetsScript.RING_M[kind]
		_xform.basis = Basis.from_scale(Vector3(radius, 1.0, radius))
		_xform.origin = Vector3(at.x, (minf(at.y, Layers.FLOOR_Y_M) if below else 0.0) + LIFT_M, at.z)
		multi.set_instance_transform(rings, _xform)
		rings += 1
	multi.visible_instance_count = rings
	return rings
