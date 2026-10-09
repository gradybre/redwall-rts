extends RefCounted
## Revision-cached interior finish geometry; fixed input is caller truth, never excavation authority.
## Returned ArrayMesh resources are borrowed cache entries: assign materials, never edit/clear surfaces.

const Footprint := preload("res://scripts/core/room_footprint.gd")
const SOLID: int = 0
const CUT: int = 1
const FINISHED: int = 2
const FLOOR: int = 0
const WALL: int = 1
const CEILING: int = 2
const FRONTIER: int = 3
const MESH_KEYS: Array[String] = ["floor_mesh", "wall_mesh", "ceiling_mesh", "frontier_mesh"]
const REFUSE_SPEC: StringName = &"SHELL_SPEC_REQUIRED"
const REFUSE_HEIGHT: StringName = &"SHELL_HEADROOM_OR_HEIGHT"
const REFUSE_OPENING: StringName = &"SHELL_OPENING_NOT_IN_VOID_BOUNDARY"
const REFUSE_REVISION: StringName = &"SHELL_REVISION_CONFLICT"
const REFUSE_PRECISION: StringName = &"SHELL_RENDER_PRECISION"
const UNITS_PER_METRE: float = 1024.0

var build_count: int = 0
var _revision: int = -1
var _snapshot: Dictionary = {}
var _cached: Dictionary = {}


func rebuild(revision: int, spec: Dictionary) -> Dictionary:
	"""Build once per changed revision; mismatched reused or older revisions refuse atomically."""
	if revision < 0 or revision < _revision:
		return _failure(REFUSE_REVISION)
	if revision == _revision:
		return _cached.duplicate(true) if spec == _snapshot else _failure(REFUSE_REVISION)
	var error: StringName = validation_error(spec)
	if error != &"":
		return _failure(error)
	var surfaces: Array[Dictionary] = [_buffer(), _buffer(), _buffer(), _buffer()]
	var indices: Dictionary = _cell_indices(spec.cells)
	var openings: Dictionary = _opening_index(spec.openings)
	for row: int in range(spec.state.size()):
		if spec.state[row] != SOLID:
			_build_cell(spec, row, indices, openings, surfaces)
	var result: Dictionary = _publish(surfaces)
	result["revision"] = revision
	_snapshot = spec.duplicate(true)
	_revision = revision
	_cached = result
	build_count += 1
	return result.duplicate(true)


func clear() -> void:
	"""Release this view's cached snapshot before binding it to a different room identity."""
	_revision = -1
	_snapshot.clear()
	_cached.clear()


static func validation_error(spec: Dictionary) -> StringName:
	"""Require complete typed caller geometry; no default body clearance or inferred openings."""
	if not _typed_spec(spec):
		return REFUSE_SPEC
	var error: StringName = Footprint.validation_error(spec.cells, Footprint.MAX_OPERATION_CELLS, true)
	if error != &"":
		return error
	@warning_ignore("integer_division") var count: int = spec.cells.size() / 2
	if spec.floor_u.size() != count or spec.ceiling_u.size() != count or spec.state.size() != count:
		return REFUSE_SPEC
	if spec.minimum_headroom_u < 1 or spec.minimum_headroom_u > Footprint.INT32_MAX:
		return REFUSE_HEIGHT
	if not _valid_apertures(spec, count):
		return REFUSE_OPENING
	for row: int in range(count):
		if spec.ceiling_u[row] - spec.floor_u[row] < spec.minimum_headroom_u:
			return REFUSE_HEIGHT
		if spec.state[row] > FINISHED:
			return REFUSE_SPEC
		if not _world_cell_fits(spec, row):
			return Footprint.REFUSE_WORLD
		if not _render_cell_exact(spec, row):
			return REFUSE_PRECISION
	return _validate_openings(spec)


static func _typed_spec(spec: Dictionary) -> bool:
	"""Accept only fixed integer input streams and explicit grid/headroom parameters."""
	for key: String in ["cells", "floor_u", "ceiling_u", "openings"]:
		if not spec.get(key) is PackedInt32Array:
			return false
	if not spec.get("state") is PackedByteArray or not spec.get("origin_u") is Vector2i:
		return false
	for key: String in ["cell_size_u", "minimum_headroom_u"]:
		if typeof(spec.get(key)) != TYPE_INT:
			return false
	return spec.cell_size_u > 0 and spec.cell_size_u <= Footprint.INT32_MAX


static func _valid_apertures(spec: Dictionary, count: int) -> bool:
	"""A connector aperture must name actual void, never erase an unexcavated floor or ceiling."""
	for key: String in ["floor_open", "ceiling_open"]:
		if not spec.has(key):
			continue
		if not spec[key] is PackedByteArray or spec[key].size() != count:
			return false
		for row: int in range(count):
			if spec[key][row] > 1 or (spec[key][row] == 1 and spec.state[row] == SOLID):
				return false
	return true


static func _world_cell_fits(spec: Dictionary, row: int) -> bool:
	"""Check fixed corners before float presentation conversion or mesh allocation."""
	var x: int = spec.origin_u.x + spec.cells[row * 2] * spec.cell_size_u
	var z: int = spec.origin_u.y + spec.cells[row * 2 + 1] * spec.cell_size_u
	return x >= Footprint.INT32_MIN and z >= Footprint.INT32_MIN and \
		x + spec.cell_size_u <= Footprint.INT32_MAX and z + spec.cell_size_u <= Footprint.INT32_MAX


static func _render_cell_exact(spec: Dictionary, row: int) -> bool:
	"""Refuse a display conversion that would collapse a thin cell or silently move a fixed boundary."""
	var x: int = spec.origin_u.x + spec.cells[row * 2] * spec.cell_size_u
	var z: int = spec.origin_u.y + spec.cells[row * 2 + 1] * spec.cell_size_u
	for value: int in [x, z, x + spec.cell_size_u, z + spec.cell_size_u, spec.floor_u[row], spec.ceiling_u[row]]:
		if not _render_value_exact(value):
			return false
	return true


static func _render_value_exact(value: int) -> bool:
	"""Every emitted coordinate, including sill/lintel heights, must retain the supplied fixed value."""
	var rounded: Vector3 = Vector3(float(value) / UNITS_PER_METRE, 0, 0)
	return roundi(rounded.x * UNITS_PER_METRE) == value


static func _validate_openings(spec: Dictionary) -> StringName:
	"""Openings are [x,z,side,bottom_u,top_u], each a unique exterior edge with valid height."""
	var openings: PackedInt32Array = spec.openings
	if openings.size() % 5 != 0 or openings.size() > spec.state.size() * 20:
		return REFUSE_OPENING
	var indices: Dictionary = _cell_indices(spec.cells)
	var seen: Dictionary = {}
	for at: int in range(0, openings.size(), 5):
		var cell: Vector2i = Vector2i(openings[at], openings[at + 1])
		var side: int = openings[at + 2]
		var key: Vector3i = Vector3i(cell.x, cell.y, side)
		if not indices.has(cell) or side < 0 or side > 3 or seen.has(key):
			return REFUSE_OPENING
		var row: int = indices[cell]
		if spec.state[row] == SOLID or indices.has(cell + _offset(side)):
			return REFUSE_OPENING
		if openings[at + 3] < spec.floor_u[row] or openings[at + 4] > spec.ceiling_u[row]:
			return REFUSE_OPENING
		if openings[at + 3] >= openings[at + 4]:
			return REFUSE_OPENING
		if not _render_value_exact(openings[at + 3]) or not _render_value_exact(openings[at + 4]):
			return REFUSE_PRECISION
		seen[key] = true
	return &""


static func _build_cell(spec: Dictionary, row: int, indices: Dictionary,
		openings: Dictionary, surfaces: Array[Dictionary]) -> void:
	"""Add only supplied void cells, with exact floor/ceiling coverage and exposed wall bands."""
	var cell: Vector2i = Vector2i(spec.cells[row * 2], spec.cells[row * 2 + 1])
	if not _aperture(spec, "floor_open", row):
		_horizontal(spec, row, spec.floor_u[row], Vector3.UP, surfaces[FLOOR])
	if not _aperture(spec, "ceiling_open", row):
		_horizontal(spec, row, spec.ceiling_u[row], Vector3.DOWN, surfaces[CEILING])
	for side: int in range(4):
		var neighbor: Vector2i = cell + _offset(side)
		var other: int = int(indices.get(neighbor, -1))
		if other >= 0 and spec.state[other] != SOLID:
			_height_bands(spec, row, other, side, surfaces[WALL])
		elif other >= 0:
			_wall(spec, row, side, spec.floor_u[row], spec.ceiling_u[row], surfaces[FRONTIER], true)
		else:
			_exterior(spec, row, side, openings, surfaces[WALL])


static func _height_bands(spec: Dictionary, row: int, other: int, side: int, surface: Dictionary) -> void:
	"""Draw A's void minus B's void: floor risers and ceiling soffits, with no internal double walls."""
	var low: int = spec.floor_u[row]
	var high: int = spec.ceiling_u[row]
	if low < spec.floor_u[other]:
		_wall(spec, row, side, low, mini(high, spec.floor_u[other]), surface, false)
	if high > spec.ceiling_u[other]:
		_wall(spec, row, side, maxi(low, spec.ceiling_u[other]), high, surface, false)


static func _exterior(spec: Dictionary, row: int, side: int, openings: Dictionary, surface: Dictionary) -> void:
	"""Split a real wall around the reviewed opening; no fragment discard approximates a doorway."""
	var key: Vector3i = Vector3i(spec.cells[row * 2], spec.cells[row * 2 + 1], side)
	var low: int = spec.floor_u[row]
	var high: int = spec.ceiling_u[row]
	if openings.has(key):
		var opening: Vector2i = openings[key]
		_wall(spec, row, side, low, opening.x, surface, false)
		_wall(spec, row, side, opening.y, high, surface, false)
	else:
		_wall(spec, row, side, low, high, surface, false)


static func _horizontal(spec: Dictionary, row: int, height_u: int, normal: Vector3, surface: Dictionary) -> void:
	"""One exact cell quad; neighboring cells share its edge and never overlap its interior."""
	var corners: PackedVector3Array = _corners(spec, row, height_u)
	_quad(surface, corners, normal, spec.state[row], false)


static func _wall(spec: Dictionary, row: int, side: int, bottom_u: int, top_u: int,
		surface: Dictionary, frontier: bool) -> void:
	"""One inward-facing vertical band, empty only for equal endpoints."""
	if bottom_u >= top_u:
		return
	var floor_corners: PackedVector3Array = _corners(spec, row, bottom_u)
	var ceiling_corners: PackedVector3Array = _corners(spec, row, top_u)
	var next: int = (side + 1) % 4
	var quad: PackedVector3Array = PackedVector3Array([floor_corners[side], floor_corners[next],
		ceiling_corners[next], ceiling_corners[side]])
	var outward: Vector2i = _offset(side)
	_quad(surface, quad, Vector3(-outward.x, 0, -outward.y), spec.state[row], frontier)


static func _corners(spec: Dictionary, row: int, height_u: int) -> PackedVector3Array:
	"""Convert validated fixed NW,NE,SE,SW corners only at the presentation boundary."""
	var x: int = spec.origin_u.x + spec.cells[row * 2] * spec.cell_size_u
	var z: int = spec.origin_u.y + spec.cells[row * 2 + 1] * spec.cell_size_u
	var size_u: int = spec.cell_size_u
	return PackedVector3Array([Vector3(x, height_u, z) / UNITS_PER_METRE,
		Vector3(x + size_u, height_u, z) / UNITS_PER_METRE,
		Vector3(x + size_u, height_u, z + size_u) / UNITS_PER_METRE,
		Vector3(x, height_u, z + size_u) / UNITS_PER_METRE])


static func _quad(surface: Dictionary, corners: PackedVector3Array, normal: Vector3,
		stage: int, frontier: bool) -> void:
	"""Emit stable clockwise triangles, physical UV metres and the actual supplied finish state."""
	var vertices: PackedVector3Array = surface.vertices
	var normals: PackedVector3Array = surface.normals
	var uv: PackedVector2Array = surface.uv
	var colors: PackedColorArray = surface.colors
	var indices: PackedInt32Array = surface.indices
	var start: int = vertices.size()
	for point: Vector3 in corners:
		vertices.append(point)
		normals.append(normal)
		uv.append(_uv(point, normal))
		colors.append(Color(1.0 if stage == FINISHED else 0.0, 1.0 if frontier else 0.0, 0.0, 1.0))
	var clockwise: bool = (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) < 0.0
	var winding: PackedInt32Array = PackedInt32Array([0, 1, 2, 0, 2, 3] if clockwise else [0, 2, 1, 0, 3, 2])
	for offset: int in winding:
		indices.append(start + offset)
	surface.vertices = vertices
	surface.normals = normals
	surface.uv = uv
	surface.colors = colors
	surface.indices = indices


static func _uv(point: Vector3, normal: Vector3) -> Vector2:
	"""Absolute physical projection keeps texture scale and phase fixed through expansions."""
	if absf(normal.y) > 0.5:
		return Vector2(point.x, point.z)
	return Vector2(point.z, point.y) if absf(normal.x) > 0.5 else Vector2(point.x, point.y)


static func _publish(surfaces: Array[Dictionary]) -> Dictionary:
	"""Create at most four category meshes, including an empty mesh for an absent category."""
	var result: Dictionary = {"ok": true, "error": &"", "stats": PackedInt32Array()}
	var stats: PackedInt32Array = PackedInt32Array()
	for category: int in range(4):
		var buffer: Dictionary = surfaces[category]
		var mesh: ArrayMesh = ArrayMesh.new()
		if not buffer.vertices.is_empty():
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = buffer.vertices
			arrays[Mesh.ARRAY_NORMAL] = buffer.normals
			arrays[Mesh.ARRAY_TEX_UV] = buffer.uv
			arrays[Mesh.ARRAY_COLOR] = buffer.colors
			arrays[Mesh.ARRAY_INDEX] = buffer.indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result[MESH_KEYS[category]] = mesh
		@warning_ignore("integer_division") var quads: int = buffer.vertices.size() / 4
		stats.append(quads)
	result.stats = stats
	return result


static func _buffer() -> Dictionary:
	"""Temporary packed mesh streams, retained only until this revision has been uploaded."""
	return {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uv": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}


static func _cell_indices(cells: PackedInt32Array) -> Dictionary:
	"""Temporary integer cell lookup; iteration order is never used for mesh emission."""
	var result: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		@warning_ignore("integer_division") var row: int = at / 2
		result[Vector2i(cells[at], cells[at + 1])] = row
	return result


static func _opening_index(openings: PackedInt32Array) -> Dictionary:
	"""Index the already validated explicit opening intervals."""
	var result: Dictionary = {}
	for at: int in range(0, openings.size(), 5):
		result[Vector3i(openings[at], openings[at + 1], openings[at + 2])] = Vector2i(openings[at + 3], openings[at + 4])
	return result


static func _offset(side: int) -> Vector2i:
	"""The four canonical sides follow NORTH,EAST,SOUTH,WEST in negative-Z-forward space."""
	return Vector2i(1 if side == 1 else (-1 if side == 3 else 0), 1 if side == 2 else (-1 if side == 0 else 0))


static func _aperture(spec: Dictionary, key: String, row: int) -> bool:
	"""Only a caller-declared whole-cell aperture removes a floor or ceiling patch."""
	return spec.has(key) and spec[key][row] == 1


static func _failure(error: StringName) -> Dictionary:
	"""Failed geometry never replaces the previously reviewed mesh snapshot."""
	return {"ok": false, "error": error}
