extends Node3D
## Exact finite presentation content, not a movement or work authority. Decision1080.
## Original meshes/materials with native RenderingServer skinning of linearly blended final matrices.

const MAX_PARTS: int = 16
const MAX_BINDS: int = 64
const MAX_FRAMES: int = 8192
const MAX_SCALARS: int = 4194304 # 16MiB per shared finite palette; separate presentation admission.
const MAX_VERTICES: int = 200000
const BLEND_ONE: int = 65536
const MATRIX_SCALARS: int = 12
const SOURCE_LIMIT: float = 1024.0


class Palette extends RefCounted:

	var _source: String = ""
	var _frames: int = 0
	var _stride: int = 0
	var _binds: PackedInt32Array = PackedInt32Array()
	var _offsets: PackedInt32Array = PackedInt32Array()
	var _matrices: PackedFloat32Array = PackedFloat32Array()

	func configure(source_sha256: String, frames: int, binds: PackedInt32Array,
			matrices: PackedFloat32Array) -> StringName:
		"""One immutable source image; validate before copying any caller-owned content."""
		if _frames != 0:
			return &"UNDERGROUND_PALETTE_ALREADY_CONFIGURED"
		var code: StringName = _format_error(source_sha256, frames, binds, matrices)
		if code != &"":
			return code
		_source = source_sha256
		_frames = frames
		_binds = binds.duplicate()
		_offsets.resize(binds.size())
		for part: int in binds.size():
			_offsets[part] = _stride
			_stride += maxi(1, binds[part]) * MATRIX_SCALARS
		_matrices = matrices.duplicate()
		return &""

	static func _format_error(source_sha256: String, frames: int, binds: PackedInt32Array,
			matrices: PackedFloat32Array) -> StringName:
		"""Cap multiplication, content length and every finite component before allocating."""
		if source_sha256.length() != 64:
			return &"UNDERGROUND_PALETTE_SOURCE"
		for character: String in source_sha256:
			if not character in "0123456789abcdef":
				return &"UNDERGROUND_PALETTE_SOURCE"
		if frames < 1 or frames > MAX_FRAMES or binds.is_empty() or binds.size() > MAX_PARTS:
			return &"UNDERGROUND_PALETTE_CAPACITY"
		var stride: int = 0
		for count: int in binds:
			if count < 0 or count > MAX_BINDS:
				return &"UNDERGROUND_PALETTE_CAPACITY"
			stride += maxi(1, count) * MATRIX_SCALARS
		if stride * frames > MAX_SCALARS or matrices.size() != stride * frames:
			return &"UNDERGROUND_PALETTE_FORMAT"
		for value: float in matrices:
			if not is_finite(value) or absf(value) > SOURCE_LIMIT:
				return &"UNDERGROUND_PALETTE_NONFINITE"
		return &""

	func frame_count() -> int:
		"""No missing or implicit wrap frame exists outside this finite source image."""
		return _frames

	func source_digest() -> String:
		"""The owner must match this actual presentation content to its selected physical profile."""
		return _source

	func part_count() -> int:
		"""The packed part count includes every body and actual attachment variant."""
		return _binds.size()

	func bind_count(part: int) -> int:
		"""Zero denotes an unskinned attachment with one final affine transform per frame."""
		return _binds[part] if part >= 0 and part < _binds.size() else -1

	func part_offset(part: int) -> int:
		"""Return a scalar offset into caller scratch, never an internal mutable palette array."""
		return _offsets[part] if part >= 0 and part < _offsets.size() else -1

	func scratch_count() -> int:
		"""One fixed float32 frame scratch; no per-frame full palette copy."""
		return _stride

	func sample_into(frames: PackedInt32Array, out: PackedFloat32Array) -> StringName:
		"""[now0,now1,t,old0,old1,u,blend]; exact 16-bit weights, with no quaternion decomposition."""
		var code: StringName = _sample_error(frames, out)
		if code != &"":
			return code
		var t: float = float(frames[2]) / BLEND_ONE
		var u: float = float(frames[5]) / BLEND_ONE
		var blend: float = float(frames[6]) / BLEND_ONE
		for scalar: int in _stride:
			var current: float = _at(frames[0], scalar) * (1.0 - t) + _at(frames[1], scalar) * t
			var previous: float = _at(frames[3], scalar) * (1.0 - u) + _at(frames[4], scalar) * u
			out[scalar] = previous * (1.0 - blend) + current * blend
		return &""

	func _sample_error(frames: PackedInt32Array, out: PackedFloat32Array) -> StringName:
		"""Invalid frames, extrapolation and wrong scratch leave the previous visible pose intact."""
		if _frames == 0 or frames.size() != 7 or out.size() != _stride:
			return &"UNDERGROUND_PALETTE_SAMPLE_FORMAT"
		if frames[0] < 0 or frames[0] >= _frames or frames[1] < 0 or frames[1] >= _frames \
				or frames[3] < 0 or frames[3] >= _frames or frames[4] < 0 or frames[4] >= _frames:
			return &"UNDERGROUND_PALETTE_FRAME"
		if frames[2] < 0 or frames[2] > BLEND_ONE or frames[5] < 0 or frames[5] > BLEND_ONE \
				or frames[6] < 0 or frames[6] > BLEND_ONE:
			return &"UNDERGROUND_PALETTE_WEIGHT"
		return &""

	func _at(frame: int, scalar: int) -> float:
		"""Promote the exact source float32 value before the fixed-weight arithmetic."""
		return _matrices[frame * _stride + scalar]


var _palette: Palette = null
var _nodes: Array[MeshInstance3D] = []
var _skeletons: Array[RID] = []
var _scratch: PackedFloat32Array = PackedFloat32Array()
var _visible_parts: int = 0
var _pose_ready: bool = false


func configure(palette: Palette, meshes: Array[Mesh], source_sha256: String,
		bounds: Array[AABB], materials: Array[Material] = []) -> StringName:
	"""Build the exact presentation only in a real backend; headless dummy RIDs cannot count as proof."""
	if _palette != null:
		return &"UNDERGROUND_ACTOR_ALREADY_CONFIGURED"
	var code: StringName = _content_error(palette, meshes, source_sha256, bounds, materials)
	if code != &"":
		return code
	if DisplayServer.get_name() == "headless":
		return &"UNDERGROUND_RENDERER_UNAVAILABLE"
	if not is_inside_tree():
		return &"UNDERGROUND_ACTOR_OUTSIDE_TREE"
	_palette = palette
	_scratch.resize(palette.scratch_count())
	for part: int in palette.part_count():
		_create_part(meshes[part], bounds[part], palette.bind_count(part), materials[part] if not materials.is_empty() else null)
	_visible_parts = (1 << palette.part_count()) - 1
	return &""


static func _content_error(palette: Palette, meshes: Array[Mesh], source_sha256: String,
		bounds: Array[AABB], materials: Array[Material] = []) -> StringName:
	"""Source identity, actual bind indices and finite explicit culling bounds precede any RID allocation."""
	if palette == null or palette.frame_count() == 0 or palette.source_digest() != source_sha256:
		return &"UNDERGROUND_ACTOR_SOURCE"
	if meshes.size() != palette.part_count() or bounds.size() != meshes.size() \
			or (not materials.is_empty() and materials.size() != meshes.size()):
		return &"UNDERGROUND_ACTOR_PARTS"
	var vertices: int = 0
	for part: int in meshes.size():
		if not bounds[part].position.is_finite() or not bounds[part].size.is_finite() \
				or bounds[part].size.x <= 0.0 or bounds[part].size.y <= 0.0 or bounds[part].size.z <= 0.0:
			return &"UNDERGROUND_ACTOR_BOUNDS"
		var code: StringName = _mesh_error(meshes[part], palette.bind_count(part))
		if code != &"":
			return code
		if not materials.is_empty():
			code = _material_error(materials[part])
			if code != &"":
				return code
		for surface: int in meshes[part].get_surface_count():
			vertices += meshes[part].surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
		if vertices > MAX_VERTICES:
			return &"UNDERGROUND_ACTOR_CAPACITY"
	return &""


static func _mesh_error(mesh: Mesh, binds: int) -> StringName:
	"""No new geometry, hidden deformation, ignored influence or invented skin binding is permitted."""
	if mesh == null or mesh.get_surface_count() < 1 or mesh.get_surface_count() > MAX_PARTS \
			or (mesh is ArrayMesh and mesh.get_blend_shape_count() != 0):
		return &"UNDERGROUND_ACTOR_MESH"
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var code: StringName = _surface_error(arrays, binds)
		if code != &"":
			return code
		code = _material_error(mesh.surface_get_material(surface))
		if code != &"":
			return code
	return &""


static func _surface_error(arrays: Array, binds: int) -> StringName:
	"""Validate the actual decoded source geometry, including every four/eight-weight influence."""
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return &"UNDERGROUND_ACTOR_MESH"
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if points.is_empty() or points.size() > MAX_VERTICES:
		return &"UNDERGROUND_ACTOR_CAPACITY"
	for point: Vector3 in points:
		if not point.is_finite() \
				or absf(point.x) > SOURCE_LIMIT or absf(point.y) > SOURCE_LIMIT or absf(point.z) > SOURCE_LIMIT:
			return &"UNDERGROUND_ACTOR_VERTEX"
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	if bones.size() != weights.size() or (binds == 0) != bones.is_empty():
		return &"UNDERGROUND_ACTOR_SKIN"
	if binds == 0:
		return &""
	if weights.size() != points.size() * 4 and weights.size() != points.size() * 8:
		return &"UNDERGROUND_ACTOR_SKIN"
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	return _influence_error(points.size(), stride, binds, bones, weights)


static func _influence_error(vertices: int, stride: int, binds: int,
		bones: PackedInt32Array, weights: PackedFloat32Array) -> StringName:
	"""Keep source weights, including non-unit sums; a positive finite sum is required per vertex."""
	for vertex: int in vertices:
		var sum: float = 0.0
		for influence: int in stride:
			var at: int = vertex * stride + influence
			if bones[at] < 0 or bones[at] >= binds or not is_finite(weights[at]) \
					or weights[at] < 0.0 or weights[at] > 1.0:
				return &"UNDERGROUND_ACTOR_SKIN"
			sum += weights[at]
		if sum == 0.0:
			return &"UNDERGROUND_ACTOR_SKIN"
	return &""


static func _material_error(material: Material) -> StringName:
	"""Retain original PBR materials; unproved vertex displacement and later passes refuse."""
	if material == null:
		return &""
	if not material is BaseMaterial3D:
		return &"UNDERGROUND_ACTOR_SHADER"
	var base: BaseMaterial3D = material as BaseMaterial3D
	return &"UNDERGROUND_ACTOR_DISPLACEMENT" if base.next_pass != null or base.grow \
		or base.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED else &""


func _create_part(mesh: Mesh, bounds: AABB, binds: int, material: Material) -> void:
	"""Each body owns one native palette; static attachments retain their original material and affine path."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.skeleton = NodePath()
	node.custom_aabb = bounds
	node.visible = false # No uninitialized bind pose may flash before the first explicit palette.
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	var rid: RID = RID()
	if binds > 0:
		rid = RenderingServer.skeleton_create()
		RenderingServer.skeleton_allocate_data(rid, binds)
		RenderingServer.instance_attach_skeleton(node.get_instance(), rid)
	_nodes.append(node)
	_skeletons.append(rid)


func apply_pose(frames: PackedInt32Array) -> StringName:
	"""Only explicit caller time advances a pose; a paused caller issues no update."""
	if _palette == null:
		return &"UNDERGROUND_ACTOR_UNBOUND"
	for node: MeshInstance3D in _nodes:
		if not is_instance_valid(node):
			return &"UNDERGROUND_ACTOR_PART_RETIRED"
	var code: StringName = _palette.sample_into(frames, _scratch)
	if code != &"":
		return code
	for part: int in _nodes.size():
		var offset: int = _palette.part_offset(part)
		if _palette.bind_count(part) == 0:
			_nodes[part].transform = matrix_at(_scratch, offset)
		else:
			for bind: int in _palette.bind_count(part):
				RenderingServer.skeleton_bone_set_transform(_skeletons[part], bind,
					matrix_at(_scratch, offset + bind * MATRIX_SCALARS))
	_pose_ready = true
	_apply_visibility()
	return &""


func set_parts_visible(mask: int) -> StringName:
	"""Actual Gear/Haul presentation chooses parts; this never changes a physical clearance profile."""
	if _palette == null or mask < 0 or mask >= (1 << _nodes.size()):
		return &"UNDERGROUND_ACTOR_PART_MASK"
	_visible_parts = mask
	_apply_visibility()
	return &""


func _apply_visibility() -> void:
	"""Retain a requested visibility mask while keeping an uninitialized or retired part hidden."""
	for part: int in _nodes.size():
		if is_instance_valid(_nodes[part]):
			_nodes[part].visible = _pose_ready and (_visible_parts & (1 << part)) != 0


func native_matrix(part: int, bind: int) -> Transform3D:
	"""Native qualification reader: dummy/headless results never establish the backend contract."""
	if _palette == null or part < 0 or part >= _nodes.size() or bind < 0 or bind >= maxi(1, _palette.bind_count(part)):
		return Transform3D()
	if not is_instance_valid(_nodes[part]):
		return Transform3D()
	return _nodes[part].transform if _palette.bind_count(part) == 0 \
		else RenderingServer.skeleton_bone_get_transform(_skeletons[part], bind)


func release() -> void:
	"""Detach instances before freeing only the RIDs this adapter created; repeated release is harmless."""
	for part: int in _nodes.size():
		if _skeletons[part].is_valid():
			if is_instance_valid(_nodes[part]):
				RenderingServer.instance_attach_skeleton(_nodes[part].get_instance(), RID())
			RenderingServer.free_rid(_skeletons[part])
		if is_instance_valid(_nodes[part]):
			_nodes[part].free()
	_nodes.clear()
	_skeletons.clear()
	_scratch.clear()
	_palette = null
	_visible_parts = 0
	_pose_ready = false


func _exit_tree() -> void:
	"""Scene teardown cannot leave an externally owned RenderingServer skeleton behind."""
	release()


func _notification(what: int) -> void:
	"""Out-of-tree fixtures and discarded previews also release their native skeleton ownership."""
	if what == NOTIFICATION_PREDELETE:
		release()


static func matrix_at(values: PackedFloat32Array, offset: int) -> Transform3D:
	"""Three basis columns and origin; never Basis.slerp or Transform3D.interpolate_with."""
	return Transform3D(Basis(Vector3(values[offset], values[offset + 1], values[offset + 2]),
		Vector3(values[offset + 3], values[offset + 4], values[offset + 5]),
		Vector3(values[offset + 6], values[offset + 7], values[offset + 8])),
		Vector3(values[offset + 9], values[offset + 10], values[offset + 11]))
