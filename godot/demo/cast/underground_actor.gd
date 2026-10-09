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
const Space := preload("res://scripts/core/room_space.gd")
const EXACT_ROOT_U: int = 16777216


class WorldBasis extends RefCounted:

	const HEADINGS: int = 65536
	const COEFFICIENT_BYTES: int = HEADINGS * 8
	const METADATA_BYTES: int = 4096
	const TEXT_BYTES: int = 1024
	const RESERVED_BYTES: int = COEFFICIENT_BYTES + METADATA_BYTES + 16384
	const ENGINE_HASH: String = "ed1daf0bf001b61586d9930840f2f1394092c079"
	var _coefficients: PackedFloat32Array = PackedFloat32Array()
	var _source: String = ""
	var _producer: String = ""
	var _backend: String = ""

	func load_file(path: String, digest: String, producer: String, reserved_bytes: int) -> StringName:
		"""Stream one immutable source image, with no second coefficient bank or whole-file byte buffer."""
		if not _source.is_empty():
			return &"UNDERGROUND_WORLD_BASIS_ALREADY_LOADED"
		if reserved_bytes < RESERVED_BYTES or not valid_digest(digest) or not valid_digest(producer):
			return &"UNDERGROUND_WORLD_BASIS_ADMISSION"
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return &"UNDERGROUND_WORLD_BASIS_FILE"
		var hashing: HashingContext = HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		var metadata: Dictionary = _header(file, hashing, producer)
		var code: StringName = &"UNDERGROUND_WORLD_BASIS_HEADER" if metadata.is_empty() \
			else _read_rows(file, hashing, int(metadata.get("schema", 1)))
		if code == &"" and hashing.finish().hex_encode() != digest:
			code = &"UNDERGROUND_WORLD_BASIS_DIGEST"
		file.close()
		if code != &"":
			_coefficients.clear()
			return code
		_source = digest
		_producer = producer
		_backend = backend_key(metadata)
		return &""

	static func valid_digest(value: String) -> bool:
		"""Source keys are exact lowercase SHA256 values, never permissive labels or implicit defaults."""
		if value.length() != 64:
			return false
		for character: String in value:
			if character not in "0123456789abcdef":
				return false
		return true

	static func _header(file: FileAccess, hashing: HashingContext, producer: String) -> Dictionary:
		"""Validate bounded metadata and exact wire size before allocating the coefficient array."""
		if file.get_length() < 28 + COEFFICIENT_BYTES or file.get_length() > 28 + COEFFICIENT_BYTES + METADATA_BYTES:
			return {}
		var header: PackedByteArray = file.get_buffer(20)
		var version: int = _wire_version(header)
		if version == 0:
			return {}
		var count: int = header.decode_u32(16)
		if count < 1 or count > TEXT_BYTES or file.get_length() != 28 + COEFFICIENT_BYTES + count:
			return {}
		hashing.update(header)
		var bytes: PackedByteArray = file.get_buffer(count)
		if bytes.size() != count or not metadata_shape_admitted(bytes):
			return {}
		hashing.update(bytes)
		var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not value is Dictionary or not value.get("source") is Dictionary \
				or value.source.get("sha256") != producer or not _wire_metadata_matches(value, version):
			return {}
		return value

	static func _wire_version(header: PackedByteArray) -> int:
		"""The fixed header admits exactly one reviewed version; no filename or metadata can substitute for it."""
		if header.size() != 20 or header.decode_u32(12) != HEADINGS:
			return 0
		var version: int = header.decode_u32(8)
		var magic: String = header.slice(0, 8).get_string_from_ascii()
		if (version == 1 and magic == "UGYAW001") or (version == 2 and magic == "UGYAW002"):
			return version
		return 0

	static func _wire_metadata_matches(metadata: Dictionary, version: int) -> bool:
		"""Version, actual backend and source schema are one contract; v1's previously optional schema stays optional."""
		if metadata.get("schema", 1) != version or backend_refusal(metadata) != &"":
			return false
		if version == 1:
			return metadata.get("rendering_driver") == "opengl3"
		var coefficient_source: Variant = metadata.get("coefficient_source_sha256")
		return version == 2 and metadata.get("rendering_driver") == "metal" \
			and coefficient_source is String and valid_digest(coefficient_source) \
			and metadata.get("heading_count") == HEADINGS and metadata.get("physical_qualified") == false \
			and metadata.get("orientation") == "0=-Z,+quarter=-X; +Y up" \
			and metadata.get("coefficient_order") == ["basis.x.x", "basis.z.x"]

	static func metadata_shape_admitted(bytes: PackedByteArray) -> bool:
		"""Bound JSON container/member work before its decoder allocates; string contents never count as syntax."""
		var quoted: bool = false
		var escaped: bool = false
		var depth: int = 0
		var containers: int = 0
		var members: int = 0
		for character: int in bytes:
			if quoted:
				if escaped:
					escaped = false
				elif character == 92:
					escaped = true
				elif character == 34:
					quoted = false
			elif character == 34:
				quoted = true
			elif character == 123 or character == 91:
				depth += 1
				containers += 1
			elif character == 125 or character == 93:
				depth -= 1
			elif character == 58 or character == 44:
				members += 1
			if depth < 0 or depth > 2 or containers > 4 or members > 64:
				return false
		return not quoted and depth == 0 and bytes.size() <= TEXT_BYTES

	func _read_rows(file: FileAccess, hashing: HashingContext, version: int = 1) -> StringName:
		"""Every binary32 pair and footer participates in the same open-file hash before publication."""
		if version != 1 and version != 2:
			return &"UNDERGROUND_WORLD_BASIS_HEADER"
		_coefficients.resize(HEADINGS * 2)
		for yaw: int in HEADINGS:
			var row: PackedByteArray = file.get_buffer(8)
			if row.size() != 8:
				return &"UNDERGROUND_WORLD_BASIS_TRUNCATED"
			hashing.update(row)
			var c: float = row.decode_float(0)
			var s: float = row.decode_float(4)
			if not is_finite(c) or not is_finite(s) or absf(c) > 1.0 or absf(s) > 1.0:
				return &"UNDERGROUND_WORLD_BASIS_NONFINITE"
			_coefficients[yaw * 2] = c
			_coefficients[yaw * 2 + 1] = s
		var footer: PackedByteArray = file.get_buffer(8)
		hashing.update(footer)
		var expected: String = "UGYEND01" if version == 1 else "UGYEND02"
		return &"" if footer.get_string_from_ascii() == expected and file.get_position() == file.get_length() \
			else &"UNDERGROUND_WORLD_BASIS_FOOTER"

	static func backend_refusal(metadata: Dictionary) -> StringName:
		"""The exact official engine and reviewed GL or Metal source backend are required independently of wire metadata."""
		var raw: Variant = metadata.get("engine")
		if not raw is Dictionary:
			return &"UNDERGROUND_WORLD_BASIS_ENGINE"
		var engine: Dictionary = raw
		if engine.get("major") != 4 or engine.get("minor") != 7 or engine.get("patch") != 2 \
				or engine.get("hash") != ENGINE_HASH or engine.get("build") != "official" or engine.get("status") != "stable":
			return &"UNDERGROUND_WORLD_BASIS_ENGINE"
		if metadata.get("rendering_driver") == "metal":
			if metadata.get("rendering_method") != "forward_plus" or metadata.get("display_server") != "macOS":
				return &"UNDERGROUND_WORLD_BASIS_BACKEND"
			return &"" if metadata.get("api_version") == "4.0" else &"UNDERGROUND_WORLD_BASIS_PRECISION"
		if metadata.get("rendering_driver") != "opengl3" or metadata.get("rendering_method") != "gl_compatibility" \
				or metadata.get("display_server") not in ["macOS", "Windows", "X11", "Wayland"]:
			return &"UNDERGROUND_WORLD_BASIS_BACKEND"
		var raw_api: Variant = metadata.get("api_version")
		if not raw_api is String:
			return &"UNDERGROUND_WORLD_BASIS_PRECISION"
		var api: String = raw_api
		return &"" if api.begins_with("4.") and api.length() >= 3 and api[2] in "123456" \
			else &"UNDERGROUND_WORLD_BASIS_PRECISION"

	static func backend_key(metadata: Dictionary) -> String:
		"""The source and actual consumer backend must match exactly; no platform inheritance is assumed."""
		return String(metadata.rendering_driver) + "\n" + String(metadata.rendering_method) + "\n" \
			+ String(metadata.display_server) + "\n" + String(metadata.api_version)

	func matches_runtime() -> bool:
		"""Cold binding compares the actual engine/backend, independently of the source-file declaration."""
		var metadata: Dictionary = {"engine": Engine.get_version_info(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"display_server": DisplayServer.get_name(), "api_version": RenderingServer.get_video_adapter_api_version()}
		return not _source.is_empty() and backend_refusal(metadata) == &"" and backend_key(metadata) == _backend

	func source_digest() -> String:
		"""An unbound or refused candidate never exposes a successful immutable source identity."""
		return _source

	func producer_digest() -> String:
		"""Physical proof must pin this exact producer, not only a coincidentally compatible wire format."""
		return _producer

	func coefficients_into(yaw: int, out: PackedFloat32Array) -> StringName:
		"""Borrowed two-scalar caller scratch; invalid headings leave the previous output untouched."""
		if _source.is_empty() or yaw < 0 or yaw >= HEADINGS or out.size() != 2:
			return &"UNDERGROUND_WORLD_BASIS_SELECTION"
		out[0] = _coefficients[yaw * 2]
		out[1] = _coefficients[yaw * 2 + 1]
		return &""


class Palette extends RefCounted:

	var _source: String = ""
	var _frames: int = 0
	var _stride: int = 0
	var _binds: PackedInt32Array = PackedInt32Array()
	var _offsets: PackedInt32Array = PackedInt32Array()
	var _matrices: PackedFloat32Array = PackedFloat32Array()
	var _grounding: PackedFloat32Array = PackedFloat32Array()

	func configure(source_sha256: String, frames: int, binds: PackedInt32Array,
			matrices: PackedFloat32Array, grounding: PackedFloat32Array = PackedFloat32Array()) -> StringName:
		"""One immutable source image; validate before copying any caller-owned content."""
		if _frames != 0:
			return &"UNDERGROUND_PALETTE_ALREADY_CONFIGURED"
		var code: StringName = _format_error(source_sha256, frames, binds, matrices)
		if code == &"":
			code = _grounding_error(frames, matrices.size(), grounding)
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
		_grounding = grounding.duplicate()
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

	static func _grounding_error(frames: int, scalars: int, grounding: PackedFloat32Array) -> StringName:
		"""Optional legacy-zero or one common post-skin Y per frame; count within the same scalar ceiling."""
		if (not grounding.is_empty() and grounding.size() != frames) or scalars + grounding.size() > MAX_SCALARS:
			return &"UNDERGROUND_PALETTE_GROUNDING_FORMAT"
		for value: float in grounding:
			if not is_finite(value) or absf(value) > SOURCE_LIMIT:
				return &"UNDERGROUND_PALETTE_GROUNDING_NONFINITE"
		return &""

	func grounding_y(out: PackedFloat32Array) -> float:
		"""Read the common Y only from an already successful exact scratch sample; zero for legacy content."""
		return out[_stride] if not _grounding.is_empty() and out.size() == scratch_count() else 0.0

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
		return _stride + int(not _grounding.is_empty())

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
		if not _grounding.is_empty():
			var current: float = _grounding[frames[0]] * (1.0 - t) + _grounding[frames[1]] * t
			var previous: float = _grounding[frames[3]] * (1.0 - u) + _grounding[frames[4]] * u
			out[_stride] = previous * (1.0 - blend) + current * blend
		return &""

	func _sample_error(frames: PackedInt32Array, out: PackedFloat32Array) -> StringName:
		"""Invalid frames, extrapolation and wrong scratch leave the previous visible pose intact."""
		if _frames == 0 or frames.size() != 7 or out.size() != scratch_count():
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
var _world_basis: WorldBasis = null
var _world_ref: Vector2i = Vector2i(-1, 0)
var _world_bounds: PackedInt32Array = PackedInt32Array()
var _world_root: Vector3i = Vector3i.ZERO
var _world_heading: PackedFloat32Array = PackedFloat32Array([1.0, 0.0])
var _world_ready: bool = false


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


func bind_world_source(heading_source: WorldBasis, domain: Space.Domain, descriptor: Dictionary,
		palette_digest: String, basis_digest: String) -> StringName:
	"""Bind exact rendering sources and real Domain; the caller separately owns physical certificate authority."""
	if _palette == null or _world_basis != null or not is_inside_tree() or not _parts_live():
		return &"UNDERGROUND_ACTOR_WORLD_BINDING"
	if heading_source == null or heading_source.source_digest() != basis_digest or not heading_source.matches_runtime() \
			or _palette.source_digest() != palette_digest:
		return &"UNDERGROUND_ACTOR_WORLD_SOURCE"
	var code: StringName = world_domain_refusal(domain, descriptor)
	if code != &"":
		return code
	var actual: Dictionary = domain.descriptor()
	_world_bounds = actual.bounds_u
	_world_ref = actual.world_ref
	_world_basis = heading_source
	_world_ready = false
	_apply_visibility()
	for node: MeshInstance3D in _nodes:
		node.top_level = true
	return &""


static func world_domain_refusal(domain: Space.Domain, descriptor: Dictionary) -> StringName:
	"""Exact immutable World, datum, extents and work budgets bind the parameterized source proof."""
	if domain == null or descriptor.size() != 8:
		return &"UNDERGROUND_ACTOR_WORLD_DOMAIN"
	var actual: Dictionary = domain.descriptor()
	for key: String in actual:
		if not descriptor.has(key) or typeof(actual[key]) != typeof(descriptor[key]) or actual[key] != descriptor[key]:
			return &"UNDERGROUND_ACTOR_WORLD_DOMAIN"
	var bounds: PackedInt32Array = actual.bounds_u
	if not Space.Value.valid_ref(actual.world_ref) or bounds.size() != 6:
		return &"UNDERGROUND_ACTOR_WORLD_DOMAIN"
	for coordinate: int in bounds:
		if coordinate < -EXACT_ROOT_U or coordinate > EXACT_ROOT_U:
			return &"UNDERGROUND_ACTOR_WORLD_PRECISION"
	return &""


func set_world_root(world: Vector2i, root_u: Vector3i, yaw: int) -> StringName:
	"""Actual integer root and exact 16-bit heading are presentation inputs, never movement authorization."""
	if _world_basis == null or world != _world_ref or not _parts_live():
		return &"UNDERGROUND_ACTOR_WORLD_BINDING"
	for axis: int in 3:
		if root_u[axis] < _world_bounds[axis] or root_u[axis] >= _world_bounds[axis + 3]:
			return &"UNDERGROUND_ACTOR_WORLD_ROOT"
	var code: StringName = _world_basis.coefficients_into(yaw, _world_heading)
	if code != &"":
		return code
	_world_root = root_u
	_world_ready = true
	if _pose_ready:
		var grounding: float = _palette.grounding_y(_scratch)
		for part: int in _nodes.size():
			_apply_part_transform(part, grounding)
	_apply_visibility()
	return &""


func _parts_live() -> bool:
	"""A removed actual mesh refuses before a pose or root update changes any retained visible part."""
	for node: MeshInstance3D in _nodes:
		if not is_instance_valid(node):
			return false
	return true


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
	if not _parts_live():
		return &"UNDERGROUND_ACTOR_PART_RETIRED"
	var code: StringName = _palette.sample_into(frames, _scratch)
	if code != &"":
		return code
	var grounding: float = _palette.grounding_y(_scratch)
	for part: int in _nodes.size():
		_apply_part_pose(part, grounding)
	_pose_ready = true
	_apply_visibility()
	return &""


func _apply_part_pose(part: int, grounding: float) -> void:
	"""Identical post-skin translation for the body and held items, independent of source weight sums."""
	var offset: int = _palette.part_offset(part)
	_apply_part_transform(part, grounding)
	if _palette.bind_count(part) != 0:
		for bind: int in _palette.bind_count(part):
			RenderingServer.skeleton_bone_set_transform(_skeletons[part], bind,
				matrix_at(_scratch, offset + bind * MATRIX_SCALARS))


func _apply_part_transform(part: int, grounding: float) -> void:
	"""Only bound world presentation bypasses parents; existing local behavior preserves its exact equation."""
	var value: Transform3D = Transform3D.IDENTITY if _palette.bind_count(part) != 0 \
		else matrix_at(_scratch, _palette.part_offset(part))
	if _world_basis != null:
		_nodes[part].global_transform = world_transform(value, grounding, _world_root,
			_world_heading[0], _world_heading[1])
	else:
		value.origin.y += grounding
		_nodes[part].transform = value


static func world_transform(local: Transform3D, grounding: float, root_u: Vector3i,
		c: float, s: float) -> Transform3D:
	"""Pinned scalar binary64 equations, each Vector3 store binary32; no hidden hierarchy or trigonometry."""
	var rotated: Basis = Basis(world_column(local.basis.x, c, s), world_column(local.basis.y, c, s),
		world_column(local.basis.z, c, s))
	var point: Vector3 = local.origin
	var origin: Vector3 = Vector3(c * float(point.x) + s * float(point.z) + float(root_u.x) / 1024.0,
		float(point.y) + grounding + float(root_u.y) / 1024.0,
		-s * float(point.x) + c * float(point.z) + float(root_u.z) / 1024.0)
	return Transform3D(rotated, origin)


static func world_column(column: Vector3, c: float, s: float) -> Vector3:
	"""Exact stored table coefficients rotate one original affine column before its binary32 store."""
	return Vector3(c * float(column.x) + s * float(column.z), column.y,
		-s * float(column.x) + c * float(column.z))


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
			_nodes[part].visible = _pose_ready and (_world_basis == null or _world_ready) \
				and (_visible_parts & (1 << part)) != 0


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
	_world_basis = null
	_world_ref = Vector2i(-1, 0)
	_world_bounds.clear()
	_world_root = Vector3i.ZERO
	_world_heading[0] = 1.0
	_world_heading[1] = 0.0
	_world_ready = false


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
