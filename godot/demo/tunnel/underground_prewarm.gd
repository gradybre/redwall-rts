extends RefCounted
## Every material and mesh the underground view draws, registered at boot, and drawn once while the
## opening pause holds. Decision 0206 (the underground revamp's P0; design §5 "Prewarm").
##
## WHY. Godot compiles a pipeline the first time a surface is drawn with a material in a pass it has not
## been drawn in. The U view draws things nothing on the surface draws -- the cap's shader, the troughs,
## rooms, frames and lanterns, the marks drawn through the cap -- and the old view pushed hundreds of
## opaque materials into the transparent pass. The first U press paid all of it in one frame (278 ms on
## the Mac with a tunnel and two rooms; decision 0206 has the measurements).
##
## WHAT. Whoever builds something the U view draws registers it here when it builds it (`add_mesh`: the
## mesh and the material it is drawn with, or the mesh's own; `add_label`: a label style). The tunnel
## view's prewarm (tunnel_view.gd `begin_prewarm`) builds one hidden-in-plain-sight SAMPLE of each --
## under the cap, where the depth test rejects every fragment but the draw is still issued -- and draws
## the U view for FRAMES frames behind the opening pause (demo_prewarm.gd `add_frame_step`), then frees
## the samples. Rooms, props and marks are built when they are dug or placed, never on a toggle.
##
## `covers(node)` answers whether a node's every material was registered (the test that walks the U view).

const Layers := preload("res://demo/demo_layers.gd")

## Frames the underground view is drawn for at boot (the first compiles; the second, the specializations
## that settle once the first frame's lights and shadows are known).
const FRAMES: int = 2
## A label sample's size: under a pixel, so the flash of the prewarm shows no text.
const LABEL_SAMPLE_PIXEL: float = 0.00001
## The Label3D properties its generated material depends on.
const LABEL_FLAGS: Array[StringName] = [&"billboard", &"no_depth_test", &"shaded", &"double_sided", &"fixed_size",
	&"alpha_cut", &"texture_filter", &"render_priority", &"outline_render_priority"]

var _meshes: Array[Mesh] = []
var _overrides: Array[Material] = []
## Meshes drawn instanced (a MultiMesh's), and the override each is drawn with (null: its own): sampled as
## a one-instance MultiMeshInstance3D, since an instanced draw is its own pipeline.
var _instanced: Array[Mesh] = []
var _instanced_overrides: Array[Material] = []
var _materials: Dictionary = {}
## Label styles: key -> the flags a sample is built with (LABEL_FLAGS).
var _label_keys: Dictionary = {}


func add_mesh(mesh: Mesh, override: Material = null) -> void:
	"""Register `mesh` drawn with `override` (null: its own surface materials). Once per pair."""
	if mesh == null:
		return
	for k: int in _meshes.size():
		if _meshes[k] == mesh and _overrides[k] == override:
			return
	_meshes.append(mesh)
	_overrides.append(override)
	if override != null:
		_materials[override] = true
		return
	_add_surfaces(mesh)


func _add_surfaces(mesh: Mesh) -> void:
	"""Every surface material `mesh` carries, as registered."""
	for surface: int in mesh.get_surface_count():
		var own: Material = mesh.surface_get_material(surface)
		if own != null:
			_materials[own] = true


func add_multimesh(mesh: Mesh, override: Material = null) -> void:
	"""Register `mesh` drawn through a MultiMesh with `override` (null: its own surface materials). Once
	per pair."""
	if mesh == null:
		return
	for k: int in _instanced.size():
		if _instanced[k] == mesh and _instanced_overrides[k] == override:
			return
	_instanced.append(mesh)
	_instanced_overrides.append(override)
	if override != null:
		_materials[override] = true
		return
	_add_surfaces(mesh)


func add_label(template: Label3D) -> void:
	"""Register a label style (a label drawn in the U view builds its material from its flags); one
	style, one entry, however often it is registered."""
	var flags: Dictionary = {}
	for property: StringName in LABEL_FLAGS:
		flags[property] = template.get(property)
	_label_keys[label_key(template)] = flags


static func label_key(label: Label3D) -> String:
	"""The flags a Label3D's generated material depends on, as one string."""
	var parts := PackedStringArray()
	for property: StringName in LABEL_FLAGS:
		parts.append(str(label.get(property)))
	return ",".join(parts)


func mesh_count() -> int:
	"""How many mesh-and-material pairs, and instanced meshes, are registered."""
	return _meshes.size() + _instanced.size()


func label_count() -> int:
	"""How many label styles are registered."""
	return _label_keys.size()


func has_material(material: Material) -> bool:
	"""Whether `material` is drawn by a registered pair."""
	return _materials.has(material)


func covers(node: GeometryInstance3D) -> bool:
	"""Whether every material `node` draws with (its override, else its surfaces' own) is registered;
	a Label3D, whether its style is."""
	var label := node as Label3D
	if label != null:
		return _label_keys.has(label_key(label))
	if node.material_override != null:
		return has_material(node.material_override)
	var mesh: Mesh = _mesh_of(node)
	if mesh == null:
		return true
	for surface: int in mesh.get_surface_count():
		var used: Material = mesh.surface_get_material(surface)
		var instance := node as MeshInstance3D
		if instance != null and instance.get_surface_override_material(surface) != null:
			used = instance.get_surface_override_material(surface)
		if used != null and not has_material(used):
			return false
	return true


static func _mesh_of(node: GeometryInstance3D) -> Mesh:
	"""The mesh a geometry node draws (a MultiMesh's, a particle system's), or null."""
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		return (node as MultiMeshInstance3D).multimesh.mesh
	if node is CPUParticles3D:
		return (node as CPUParticles3D).mesh
	return null


func build_samples(parent: Node3D, at: Vector3) -> int:
	"""One sample of every registered pair and label under `parent`, all at `at` on the U view's layers,
	and one lantern-style light. Returns how many were made."""
	for k: int in _meshes.size():
		var sample := MeshInstance3D.new()
		sample.mesh = _meshes[k]
		sample.material_override = _overrides[k]
		sample.layers = Layers.UNDERGROUND
		sample.position = at
		parent.add_child(sample)
	for flags: Dictionary in _label_keys.values():
		var label := Label3D.new()
		for property: StringName in flags:
			label.set(property, flags[property])
		label.text = "Ag"
		label.pixel_size = LABEL_SAMPLE_PIXEL
		label.layers = Layers.UNDERGROUND_MARKS
		label.position = at
		parent.add_child(label)
	for k: int in _instanced.size():
		var sample := _instanced_sample(_instanced[k], at)
		sample.material_override = _instanced_overrides[k]
		parent.add_child(sample)
	var light := OmniLight3D.new()
	light.layers = Layers.UNDERGROUND
	light.light_cull_mask = Layers.UNDERGROUND
	light.omni_range = 1.0
	light.position = at
	parent.add_child(light)
	return mesh_count() + _label_keys.size() + 1


static func _instanced_sample(mesh: Mesh, at: Vector3) -> MultiMeshInstance3D:
	"""A one-instance MultiMesh of `mesh` at `at`, on the underground layer."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 1
	var sample := MultiMeshInstance3D.new()
	sample.multimesh = multimesh
	sample.layers = Layers.UNDERGROUND
	sample.position = at
	return sample
