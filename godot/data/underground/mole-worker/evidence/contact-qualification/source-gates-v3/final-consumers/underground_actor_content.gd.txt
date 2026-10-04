extends RefCounted
## Immutable finite presentation source. Original meshes remain borrowed; this grants no movement/work permission.

const Actor := preload("res://demo/cast/underground_actor.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const MAX_PARTS: int = 8
const MAX_CLIPS: int = 16
const MAX_FRAMES: int = 2048
const MAX_SCALARS: int = 1048576
const MAX_VERTICES: int = 32768
const MAX_SURFACES: int = 8
const CONTROL_RESERVE: int = 2097152
const MESH_BYTES_PER_VERTEX: int = 256
const HEADER_BYTES: int = 184
const PART_BYTES: int = 72
const CLIP_BYTES: int = 48
const FRACTION: int = 65536

var _palette: Actor.Palette = null
var _parts: PackedInt32Array = PackedInt32Array() # bind count, vertices, surfaces, kind, culling low/high XYZ.
var _part_hashes: PackedByteArray = PackedByteArray()
var _clips: PackedInt32Array = PackedInt32Array() # first frame, count, loop mode, exact-source outward Q16 duration.
var _clip_hashes: PackedByteArray = PackedByteArray()
var _sources: PackedByteArray = PackedByteArray() # basis, raw source, proof, plan SHA256.
var _bounds: PackedInt32Array = PackedInt32Array()
var _digest: String = ""
var _revision: int = 0
var _frames: int = 0
var _stride: int = 0
var _peak: int = 0
var _loading: bool = false


func load_file(path: String, expected_digest: String, reserved_bytes: int) -> StringName:
	"""One same-file streamed digest; all row/scalar/native allowances are admitted before large allocations."""
	if _palette != null or _loading:
		return &"ACTOR_CONTENT_ALREADY_LOADED"
	if path.length() > 1024 or not Actor.WorldBasis.valid_digest(expected_digest):
		return &"ACTOR_CONTENT_ARGUMENT"
	_loading = true
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var code: StringName = &"ACTOR_CONTENT_FILE" if file == null else _decode(file, hashing, reserved_bytes, expected_digest)
	if file != null:
		file.close()
	if code == &"":
		_digest = expected_digest
	else:
		_clear_failed()
	_loading = false
	return code


func _read(file: FileAccess, hashing: HashingContext, count: int) -> PackedByteArray:
	"""Only bounded header, row or 4KiB scalar chunks coexist with the final arrays."""
	var data: PackedByteArray = file.get_buffer(count)
	hashing.update(data)
	return data


func _decode(file: FileAccess, hashing: HashingContext, reserved: int, digest: String) -> StringName:
	"""No partial source becomes externally observable before complete footer/hash and Palette validation."""
	var head: PackedByteArray = _read(file, hashing, HEADER_BYTES)
	var code: StringName = _header(head, file.get_length(), reserved)
	if code != &"":
		return code
	code = _read_parts(file, hashing)
	if code == &"":
		code = _read_clips(file, hashing)
	if code != &"":
		return code
	_peak = _required_peak()
	if _peak > reserved:
		return &"ACTOR_CONTENT_PRESENTATION_RESERVE"
	var matrices: PackedFloat32Array = PackedFloat32Array()
	var grounding: PackedFloat32Array = PackedFloat32Array()
	code = _read_scalars(file, hashing, _frames * _stride, matrices)
	if code == &"":
		code = _read_scalars(file, hashing, _frames, grounding)
	if code != &"":
		return code
	var end: PackedByteArray = _read(file, hashing, 8)
	if end.get_string_from_ascii() != "UGAEND01" or file.get_position() != file.get_length():
		return &"ACTOR_CONTENT_FOOTER"
	if hashing.finish().hex_encode() != digest:
		return &"ACTOR_CONTENT_DIGEST"
	return _publish_palette(digest, matrices, grounding)


func _publish_palette(digest: String, matrices: PackedFloat32Array, grounding: PackedFloat32Array) -> StringName:
	"""Only the immutable Palette copy is retained after the admitted decode overlap ends."""
	var palette: Actor.Palette = Actor.Palette.new()
	var code: StringName = palette.configure(digest, _frames, _bind_counts(), matrices, grounding)
	if code == &"":
		_palette = palette
	return code


func _header(bytes: PackedByteArray, length: int, reserved: int) -> StringName:
	"""Fixed counts and exact integer roots are bounded before table/scalar multiplication or allocation."""
	if bytes.size() != HEADER_BYTES or bytes.slice(0, 8).get_string_from_ascii() != "UGACNT01" \
			or bytes.decode_u32(8) != 1 or bytes.decode_u32(12) < 1 or bytes.decode_u32(12) > 2147483647:
		return &"ACTOR_CONTENT_HEADER"
	var parts: int = bytes.decode_u32(16)
	var clips: int = bytes.decode_u32(20)
	var frames: int = bytes.decode_u32(24)
	var stride: int = bytes.decode_u32(28)
	if parts < 1 or parts > MAX_PARTS or clips < 1 or clips > MAX_CLIPS or frames < 2 or frames > MAX_FRAMES \
			or stride < 12 or stride > MAX_PARTS * Actor.MAX_BINDS * 12 or frames * (stride + 1) > MAX_SCALARS:
		return &"ACTOR_CONTENT_CAPACITY"
	if length != HEADER_BYTES + parts * PART_BYTES + clips * CLIP_BYTES + frames * (stride + 1) * 4 + 8 \
			or reserved < 8 * frames * (stride + 1) + 80 * parts + 48 * clips + 152 + CONTROL_RESERVE:
		return &"ACTOR_CONTENT_PRESENTATION_RESERVE"
	for axis: int in 3:
		var low: int = bytes.decode_s32(32 + axis * 4)
		var high: int = bytes.decode_s32(44 + axis * 4)
		if low >= high or absi(low) > 16777216 or absi(high) > 16777216:
			return &"ACTOR_CONTENT_DOMAIN"
	_revision = bytes.decode_u32(12)
	_frames = frames
	_stride = stride
	_allocate_tables(parts, clips, bytes)
	return &""


func _allocate_tables(parts: int, clips: int, bytes: PackedByteArray) -> void:
	"""Called only after exact small-table and complete scalar-copy admission."""
	_parts.resize(parts * 10)
	_part_hashes.resize(parts * 32)
	_clips.resize(clips * 4)
	_clip_hashes.resize(clips * 32)
	_sources = bytes.slice(56, HEADER_BYTES)
	_bounds.resize(6)
	for axis: int in 6:
		_bounds[axis] = bytes.decode_s32(32 + axis * 4)


func _read_parts(file: FileAccess, hashing: HashingContext) -> StringName:
	"""Each original mesh gets one digest and a bounded culling box in its pre-instance-transform frame."""
	var stride: int = 0
	for part: int in part_count():
		var bytes: PackedByteArray = _read(file, hashing, PART_BYTES)
		if bytes.size() != PART_BYTES:
			return &"ACTOR_CONTENT_TRUNCATED"
		for field: int in 4:
			_parts[part * 10 + field] = bytes.decode_s32(field * 4)
		var binds: int = _parts[part * 10]
		if binds < 0 or binds > Actor.MAX_BINDS or _parts[part * 10 + 1] < 1 \
				or _parts[part * 10 + 1] > MAX_VERTICES or _parts[part * 10 + 2] < 1 \
				or _parts[part * 10 + 2] > MAX_SURFACES or _parts[part * 10 + 3] != int(binds == 0):
			return &"ACTOR_CONTENT_PART"
		stride += maxi(1, binds) * 12
		for index: int in 32:
			_part_hashes[part * 32 + index] = bytes[16 + index]
		for axis: int in 6:
			_parts[part * 10 + 4 + axis] = bytes.decode_s32(48 + axis * 4)
		for axis: int in 3:
			var low: int = _parts[part * 10 + 4 + axis]
			var high: int = _parts[part * 10 + 7 + axis]
			if low >= high or absi(low) > 2097152 or absi(high) > 2097152:
				return &"ACTOR_CONTENT_CULLING_BOX"
	return &"" if stride == _stride else &"ACTOR_CONTENT_STRIDE"


func _read_clips(file: FileAccess, hashing: HashingContext) -> StringName:
	"""Disjoint contiguous clip spans account for every frame exactly once."""
	var next: int = 0
	for clip: int in clip_count():
		var bytes: PackedByteArray = _read(file, hashing, CLIP_BYTES)
		if bytes.size() != CLIP_BYTES:
			return &"ACTOR_CONTENT_TRUNCATED"
		for field: int in 4:
			_clips[clip * 4 + field] = bytes.decode_s32(field * 4)
		var count: int = _clips[clip * 4 + 1]
		var duration: int = _clips[clip * 4 + 3]
		if _clips[clip * 4] != next or count < 2 or next + count > _frames \
				or _clips[clip * 4 + 2] < 0 or _clips[clip * 4 + 2] > 2 \
				or duration <= (count - 2) * FRACTION or duration > (count - 1) * FRACTION:
			return &"ACTOR_CONTENT_CLIP"
		next += count
		for index: int in 32:
			_clip_hashes[clip * 32 + index] = bytes[16 + index]
	return &"" if next == _frames else &"ACTOR_CONTENT_FRAME_CENSUS"


func _read_scalars(file: FileAccess, hashing: HashingContext, count: int, out: PackedFloat32Array) -> StringName:
	"""A bounded chunk is decoded without a second full raw byte image; no nonfinite matrix reaches native code."""
	out.resize(count)
	var at: int = 0
	while at < count:
		var span: int = mini(1024, count - at)
		var bytes: PackedByteArray = _read(file, hashing, span * 4)
		if bytes.size() != span * 4:
			return &"ACTOR_CONTENT_TRUNCATED"
		for scalar: int in span:
			var value: float = bytes.decode_float(scalar * 4)
			if not is_finite(value) or absf(value) > 1024.0:
				return &"ACTOR_CONTENT_SCALAR"
			out[at + scalar] = value
		at += span
	return &""


func _bind_counts() -> PackedInt32Array:
	"""One small cold copy becomes the immutable Palette's part table."""
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(part_count())
	for part: int in part_count():
		result[part] = _parts[part * 10]
	return result


func _required_peak() -> int:
	"""All bytes coexist as declared: retained Palette plus the larger decode copy or borrowed-mesh array pass."""
	var vertices: int = 0
	for part: int in part_count():
		vertices = maxi(vertices, _parts[part * 10 + 1])
	var retained: int = _frames * (_stride + 1) * 4
	return retained + maxi(retained, vertices * MESH_BYTES_PER_VERTEX) \
		+ 80 * part_count() + 48 * clip_count() + 152 + CONTROL_RESERVE


func part_count() -> int:
	"""The finite part prefix is private until load_file returns successfully."""
	@warning_ignore("integer_division") var count: int = _parts.size() / 10
	return count


func clip_count() -> int:
	"""Stable numeric clip IDs follow the exact source plan order."""
	@warning_ignore("integer_division") var count: int = _clips.size() / 4
	return count


func clip_timing_into(clip: int, out: PackedInt32Array) -> bool:
	"""Copy the exact finite duration and authored loop mode into caller-owned fixed scratch."""
	if _palette == null or clip < 0 or clip >= clip_count() or out.size() != 2:
		return false
	out[0] = _clips[clip * 4 + 3]
	out[1] = _clips[clip * 4 + 2]
	return true


func source_digest() -> String:
	"""Exact immutable content image bound to the Actor and the physical profile source table."""
	return _digest


func required_peak_bytes() -> int:
	"""Logical admission including explicitly reserved native controls; not an allocator measurement."""
	return _peak if _palette != null else 0


func source_hash_into(which: int, out: PackedByteArray) -> bool:
	"""Copy basis/raw/proof/plan provenance only after successful immutable loading."""
	if _palette == null or which < 0 or which >= 4 or out.size() != 32:
		return false
	for index: int in 32:
		out[index] = _sources[which * 32 + index]
	return true


func domain_matches(bounds_u: PackedInt32Array) -> bool:
	"""The content's numerical certificate cannot migrate to a different finite root range."""
	return _palette != null and bounds_u.size() == 6 and bounds_u == _bounds


func clip_into(clip: int, elapsed_q16_ticks: int, out: PackedInt32Array) -> StringName:
	"""Presentation-only 30Hz source sampling; no gameplay speed or state is changed."""
	if _palette == null or clip < 0 or clip >= clip_count() or out.size() != 3 or elapsed_q16_ticks < 0:
		return &"ACTOR_CONTENT_CLIP_QUERY"
	var duration: int = _clips[clip * 4 + 3]
	var time: int = mini(elapsed_q16_ticks, duration)
	if _clips[clip * 4 + 2] == 1:
		time = elapsed_q16_ticks % duration
	elif _clips[clip * 4 + 2] == 2:
		time = elapsed_q16_ticks % (duration * 2)
		time = duration * 2 - time if time > duration else time
	@warning_ignore("integer_division") var frame: int = time / FRACTION
	out[0] = _clips[clip * 4] + frame
	out[1] = _clips[clip * 4] + mini(frame + 1, _clips[clip * 4 + 1] - 1)
	out[2] = time % FRACTION
	_finish_clip_interval(clip, time, out)
	return &""


func _finish_clip_interval(clip: int, time: int, out: PackedInt32Array) -> void:
	"""The last short source interval reaches its final pose; a loop closes to its exact first finite pose."""
	var first: int = _clips[clip * 4]
	var count: int = _clips[clip * 4 + 1]
	var duration: int = _clips[clip * 4 + 3]
	var final_start: int = (count - 2) * FRACTION
	if time < final_start:
		return
	if time == duration:
		out[0] = first + count - 1
		out[1] = out[0]
		out[2] = 0
		return
	out[0] = first + count - 2
	out[1] = first if _clips[clip * 4 + 2] == 1 else first + count - 1
	@warning_ignore("integer_division") var weight: int = (time - final_start) * FRACTION / (duration - final_start)
	out[2] = weight


func profile_matches(profiles: Profiles, profile: int, revision: int, content_revision: int) -> bool:
	"""Cold source identity only; actual worker/tool/contact selection is still the simulation owner's duty."""
	if _palette == null or profiles == null:
		return false
	var descriptor: Profiles.Descriptor = Profiles.Descriptor.new()
	if profiles.descriptor_into(profile, content_revision, descriptor) != &"" or descriptor.profile_revision != revision:
		return false
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(32)
	return profiles.source_hash_into(descriptor.source_id, content_revision, digest) and digest.hex_encode() == _digest


func mesh_binding_refusal(meshes: Array[Mesh]) -> StringName:
	"""Actual original geometry and every influence are checked, not a resource name supplied by a caller."""
	if _palette == null or meshes.size() != part_count():
		return &"ACTOR_CONTENT_MESH_COUNT"
	for part: int in part_count():
		var mesh: ArrayMesh = meshes[part] as ArrayMesh
		if mesh == null:
			return &"ACTOR_CONTENT_ORIGINAL_ARRAY_MESH"
		var digest: PackedByteArray = mesh_fingerprint(mesh, _parts[part * 10], _parts[part * 10 + 1], _parts[part * 10 + 2])
		if digest.size() != 32:
			return &"ACTOR_CONTENT_MESH_FORMAT"
		for index: int in 32:
			if digest[index] != _part_hashes[part * 32 + index]:
				return &"ACTOR_CONTENT_MESH_DIGEST"
	return &""


func configure_actor(actor: Actor, meshes: Array[Mesh], materials: Array[Material]) -> StringName:
	"""Borrow one shared immutable Palette; this component never copies it per Actor or changes a world owner."""
	if actor == null:
		return &"ACTOR_CONTENT_ACTOR"
	var code: StringName = mesh_binding_refusal(meshes)
	if code != &"":
		return code
	var boxes: Array[AABB] = []
	for part: int in part_count():
		var low: Vector3 = Vector3(_parts[part * 10 + 4], _parts[part * 10 + 5], _parts[part * 10 + 6]) / 1024.0
		var high: Vector3 = Vector3(_parts[part * 10 + 7], _parts[part * 10 + 8], _parts[part * 10 + 9]) / 1024.0
		boxes.append(AABB(low, high - low))
	return actor.configure(_palette, meshes, _digest, boxes, materials)


static func mesh_fingerprint(mesh: ArrayMesh, binds: int, vertices: int, surfaces: int) -> PackedByteArray:
	"""Preflight array counts before decoding one bounded surface; hash exact original float32 geometry."""
	if not _mesh_counts_match(mesh, binds, vertices, surfaces):
		return PackedByteArray()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update("UGMESH01".to_ascii_buffer())
	var header: PackedByteArray = PackedByteArray()
	header.resize(32)
	header.encode_u32(0, binds)
	header.encode_u32(4, surfaces)
	var box: AABB = mesh.get_aabb()
	for axis: int in 3:
		header.encode_float(8 + axis * 4, box.position[axis])
		header.encode_float(20 + axis * 4, box.size[axis])
	hashing.update(header)
	for surface: int in surfaces:
		if not _hash_surface(mesh, surface, binds, hashing):
			return PackedByteArray()
	return hashing.finish()


static func _mesh_counts_match(mesh: ArrayMesh, binds: int, vertices: int, surfaces: int) -> bool:
	"""Counts and index storage are bounded without first allocating the engine's complete decoded arrays."""
	if mesh == null or binds < 0 or binds > Actor.MAX_BINDS or surfaces < 1 or surfaces > MAX_SURFACES \
			or mesh.get_surface_count() != surfaces or vertices < 1 or vertices > MAX_VERTICES \
			or mesh.get_blend_shape_count() != 0:
		return false
	var total: int = 0
	for surface: int in surfaces:
		var count: int = mesh.surface_get_array_len(surface)
		var indices: int = mesh.surface_get_array_index_len(surface)
		if count < 1 or count > vertices or indices < 0 or indices > count * 6 \
				or mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		total += count
	return total == vertices


static func _hash_surface(mesh: ArrayMesh, surface: int, binds: int, hashing: HashingContext) -> bool:
	"""A fixed per-vertex transcript avoids copying the entire surface again just to hash it."""
	var arrays: Array = mesh.surface_get_arrays(surface)
	if Actor._surface_error(arrays, binds) != &"":
		return false
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if binds > 0 else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if binds > 0 else PackedFloat32Array()
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			if index < 0 or index >= points.size():
				return false
	var header: PackedByteArray = PackedByteArray()
	header.resize(16)
	header.encode_u64(0, mesh.surface_get_format(surface))
	header.encode_u32(8, points.size())
	header.encode_u32(12, stride)
	hashing.update(header)
	var row: PackedByteArray = PackedByteArray()
	row.resize(12 + stride * 8)
	for vertex: int in points.size():
		for axis: int in 3:
			row.encode_float(axis * 4, points[vertex][axis])
		for influence: int in stride:
			row.encode_u32(12 + influence * 8, bones[vertex * stride + influence])
			row.encode_float(16 + influence * 8, weights[vertex * stride + influence])
		hashing.update(row)
	return true


func _clear_failed() -> void:
	"""Failed loading retains neither a partial image nor an observable source identity."""
	_palette = null
	_parts.clear()
	_part_hashes.clear()
	_clips.clear()
	_clip_hashes.clear()
	_sources.clear()
	_bounds.clear()
	_digest = ""
	_revision = 0
	_frames = 0
	_stride = 0
	_peak = 0
