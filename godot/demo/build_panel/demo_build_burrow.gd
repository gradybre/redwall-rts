extends RefCounted
## ONE SURFACE OF THE ROUNDED DUG LEVEL (decision 1914), for build_burrow.gdshader: either flat quads (the earth's top,
## the dug floors) or PATCHES, one cell of the rounded walls each, a ROW × ROW heightfield read from the field
## (demo_build_burrow_field.gd). Every vertex carries what the shader reads: UV.x the floor-grid flag, UV.y the water
## mark, UV2.x how far the vertex moves down while the cell being dug is dug (`dig_share` of it), and COLOR its normal
## once dug (n * 0.5 + 0.5). A patch's normals come from the field one lattice step past its own edge, so they agree
## across patches. Built only when the dug level changes, never per frame. Presentation only.

const Field := preload("res://demo/build_panel/demo_build_burrow_field.gd")

const STEP_M: float = 1.0 / Field.SAMPLES
## The heights read for a patch: its ROW × ROW lattice and one point past each edge (for the normals).
const SPAN: int = Field.ROW + 2
const PATCH_VERTICES: int = Field.ROW * Field.ROW
const PATCH_INDICES: int = Field.SAMPLES * Field.SAMPLES * 6
const UP_COLOUR: Color = Color(0.5, 1.0, 0.5)

## The index list for consecutive patches (each PATCH_VERTICES vertices), grown when more are needed.
static var _pattern: PackedInt32Array = PackedInt32Array()

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var uv2s: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()
var patches: int = 0
## Each patch's cell (absolute), in the order drawn (checks: `height_at`).
var patch_cells: Array[Vector2i] = []
var _depth: float = 1.0
## The index list's guard: made on a worker, grown once for all builds.
static var _pattern_lock: Mutex = Mutex.new()


func _init(depth_m: float = 1.0) -> void:
	"""A surface whose walls are `depth_m` deep."""
	_depth = depth_m


func flat(low: Vector2, high: Vector2, y: float, grid: float) -> void:
	"""One level quad from `low` to `high` (x, z in m) at `y`, facing up; `grid` 1 shows the floor grid on it."""
	var start: int = vertices.size()
	for corner: Vector2 in [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]:
		vertices.append(Vector3(corner.x, y, corner.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(grid, 0.0))
		uv2s.append(Vector2.ZERO)
		colors.append(UP_COLOUR)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


func patch(fields: Array, cell: Vector2i, corner: Vector3, wet: bool) -> void:
	"""Cell `cell` (absolute) as a heightfield with its north-west corner at `corner` (m, the top's height): its depth
	from `fields[0]`, and where `fields` holds a second field (the cell being dug, dug), how far each point moves."""
	var field0: Field = fields[0]
	var field1: Field = fields[1] if fields.size() > 1 else null
	var h0: PackedFloat32Array = PackedFloat32Array()
	h0.resize(SPAN * SPAN)
	field0.fill_patch(cell, h0)
	var h1: PackedFloat32Array = h0
	if field1 != null:
		h1 = PackedFloat32Array()
		h1.resize(SPAN * SPAN)
		field1.fill_patch(cell, h1)
	for j: int in Field.ROW:
		for i: int in Field.ROW:
			var at: int = (j + 1) * SPAN + i + 1
			var normal: Vector3 = _normal(h0, at)
			vertices.append(corner + Vector3(i * STEP_M, -_depth * h0[at], j * STEP_M))
			normals.append(normal)
			uvs.append(Vector2(0.0, 1.0 if wet and h0[at] == 0.0 else 0.0))
			uv2s.append(Vector2(-_depth * (h1[at] - h0[at]), 0.0))
			var dug: Vector3 = normal if field1 == null else _normal(h1, at)
			colors.append(Color(dug.x * 0.5 + 0.5, dug.y * 0.5 + 0.5, dug.z * 0.5 + 0.5))
	patches += 1
	patch_cells.append(cell)


func add(piece: RefCounted) -> void:
	"""Append what `piece` (another surface of patches, kept from an earlier draw) holds."""
	vertices.append_array(piece.get("vertices"))
	normals.append_array(piece.get("normals"))
	uvs.append_array(piece.get("uvs"))
	uv2s.append_array(piece.get("uv2s"))
	colors.append_array(piece.get("colors"))
	patches += int(piece.get("patches"))
	patch_cells.append_array(piece.get("patch_cells"))


func _normal(heights: PackedFloat32Array, at: int) -> Vector3:
	"""The surface's normal at lattice index `at` of `heights`, from its four neighbours."""
	var scale: float = _depth / (2.0 * STEP_M)
	return Vector3((heights[at + 1] - heights[at - 1]) * scale, 1.0,
		(heights[at + SPAN] - heights[at - SPAN]) * scale).normalized()


func count() -> int:
	"""Quads (flat) or patches drawn."""
	@warning_ignore("integer_division") var quads: int = indices.size() / 6
	return patches if patches > 0 else quads


func arrays() -> Array:
	"""What was built as a surface's arrays, ready for `add_to` (empty when nothing was): made on a worker, added on the
	main thread."""
	if vertices.is_empty():
		return []
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_TEX_UV2] = uv2s
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = _patch_indices(patches) if patches > 0 else indices
	return out


static func add_to(mesh: ArrayMesh, surface_arrays: Array, material: Material) -> void:
	"""`surface_arrays` (from `arrays`) as one more surface of `mesh` in `material` (nothing when empty)."""
	if surface_arrays.is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func _patch_indices(count_of: int) -> PackedInt32Array:
	"""The triangles of `count_of` consecutive patches, each square's two facing up (the pattern grown once)."""
	_pattern_lock.lock()
	@warning_ignore("integer_division") var have: int = _pattern.size() / PATCH_INDICES
	if have < count_of:
		_pattern.resize(count_of * PATCH_INDICES)
		for p: int in range(have, count_of):
			var at: int = p * PATCH_INDICES
			for j: int in Field.SAMPLES:
				for i: int in Field.SAMPLES:
					var a: int = p * PATCH_VERTICES + j * Field.ROW + i
					for corner: int in [a, a + 1, a + 1 + Field.ROW, a, a + 1 + Field.ROW, a + Field.ROW]:
						_pattern[at] = corner
						at += 1
	var out: PackedInt32Array = _pattern.slice(0, count_of * PATCH_INDICES)
	_pattern_lock.unlock()
	return out


func height_at(point: Vector2, share: float = 0.0) -> float:
	"""The drawn height under `point` (x, z in m) with the cell being dug `share` of the way down (the shader's
	`dig_share`), read from the built vertices (NAN: not here)."""
	if patches == 0:
		return _flat_height_at(point)
	for p: int in patches:
		var low: Vector3 = vertices[p * PATCH_VERTICES]
		var local: Vector2 = (point - Vector2(low.x, low.z)) / STEP_M
		if local.x < 0.0 or local.y < 0.0 or local.x > Field.SAMPLES or local.y > Field.SAMPLES:
			continue
		var i: int = mini(int(local.x), Field.SAMPLES - 1)
		var j: int = mini(int(local.y), Field.SAMPLES - 1)
		return _triangle_height(p * PATCH_VERTICES + j * Field.ROW + i, local - Vector2(i, j), share)
	return NAN


func _triangle_height(a: int, f: Vector2, share: float) -> float:
	"""The height at fraction `f` across lattice square `a` (its two triangles as drawn)."""
	var h00: float = _y(a, share)
	var h10: float = _y(a + 1, share)
	var h01: float = _y(a + Field.ROW, share)
	var h11: float = _y(a + 1 + Field.ROW, share)
	if f.x >= f.y:
		return h00 + (h10 - h00) * f.x + (h11 - h10) * f.y
	return h00 + (h11 - h01) * f.x + (h01 - h00) * f.y


func _y(at: int, share: float) -> float:
	"""Vertex `at`'s height with the cell being dug `share` of the way down."""
	return vertices[at].y + share * uv2s[at].x


func _flat_height_at(point: Vector2) -> float:
	"""The height of the flat quad under `point` (NAN: none)."""
	for q: int in range(0, vertices.size(), 4):
		var low: Vector3 = vertices[q]
		var high: Vector3 = vertices[q + 2]
		if point.x >= low.x and point.x <= high.x and point.y >= low.z and point.y <= high.z:
			return low.y
	return NAN
