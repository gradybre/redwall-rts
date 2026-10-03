extends RefCounted
## Pure, cold-path geometry for room drafts; no spatial identity, material or paid-cut state.
## Cells are packed [x,z] grid indices, canonicalized by z then x. Caller owns grid spacing.
## Bounds are algorithm safety limits, not adopted room size, level count or resident clearance.

const NORTH: int = 0
const EAST: int = 1
const SOUTH: int = 2
const WEST: int = 3
const MAX_OPERATION_CELLS: int = 16384
const MAX_SHAPE_SPAN: int = 32767
const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647
const REFUSE_NONE: StringName = &""
const REFUSE_FORMAT: StringName = &"FOOTPRINT_PAIR_FORMAT"
const REFUSE_CAPACITY: StringName = &"FOOTPRINT_CAPACITY"
const REFUSE_COORDINATE: StringName = &"FOOTPRINT_COORDINATE_RANGE"
const REFUSE_EMPTY: StringName = &"FOOTPRINT_EMPTY"
const REFUSE_CANONICAL: StringName = &"FOOTPRINT_NOT_CANONICAL"
const REFUSE_DISCONNECTED: StringName = &"FOOTPRINT_DISCONNECTED"
const REFUSE_PINCH: StringName = &"FOOTPRINT_PINCHED_BOUNDARY"
const REFUSE_HOLES: StringName = &"FOOTPRINT_HOLES_NOT_ALLOWED"
const REFUSE_SHAPE: StringName = &"FOOTPRINT_SHAPE_ARGUMENTS"
const REFUSE_OPENING: StringName = &"FOOTPRINT_OPENING_NOT_BOUNDARY"
const REFUSE_WORLD: StringName = &"FOOTPRINT_WORLD_RANGE"


class ValidationScratch extends RefCounted:
	## One caller-admitted cold validation, not per-cell objects or persistent geometry.
	const VISITED: int = 1
	const DIAGONAL_LEFT: int = 2
	const DIAGONAL_RIGHT: int = 4
	var _validation_capacity: int = 0
	var _validation_up: PackedInt32Array = PackedInt32Array()
	var _validation_down: PackedInt32Array = PackedInt32Array()
	var _validation_queue: PackedInt32Array = PackedInt32Array()
	var _validation_flags: PackedByteArray = PackedByteArray()

	func _init(requested: int) -> void:
		"""Refuse invalid sizes before allocation; four exact arrays occupy13N packed bytes."""
		_validation_capacity = clampi(requested, 0, MAX_OPERATION_CELLS)
		if requested < 1 or requested > MAX_OPERATION_CELLS:
			return
		_validation_up.resize(_validation_capacity)
		_validation_down.resize(_validation_capacity)
		_validation_queue.resize(_validation_capacity)
		_validation_flags.resize(_validation_capacity)
		_validation_up.fill(-1)
		_validation_down.fill(-1)

	func link_vertical_rows(cells: PackedInt32Array) -> void:
		"""Merge only adjacent occupied Z rows; enormous absent coordinate spans allocate nothing."""
		var start: int = 0
		var previous_start: int = 0
		var previous_end: int = 0
		while start < _validation_capacity:
			var end: int = start + 1
			while end < _validation_capacity and cells[end * 2 + 1] == cells[start * 2 + 1]:
				end += 1
			if previous_end > 0 and cells[start * 2 + 1] == int(cells[previous_start * 2 + 1]) + 1:
				_link_row_pair(cells, previous_start, previous_end, start, end)
			previous_start = start
			previous_end = end
			start = end

	func _link_row_pair(cells: PackedInt32Array, prior_start: int, prior_end: int,
			current_start: int, current_end: int) -> void:
		"""A monotone lower bound plus at most three adjacent X cells keeps all joins linear."""
		var near: int = current_start
		for previous: int in range(prior_start, prior_end):
			var x: int = cells[previous * 2]
			while near < current_end and cells[near * 2] < x - 1:
				near += 1
			var current: int = near
			while current < current_end and cells[current * 2] <= x + 1:
				var delta: int = cells[current * 2] - x
				if delta == -1:
					_validation_flags[previous] |= DIAGONAL_LEFT
				elif delta == 0:
					_validation_down[previous] = current
					_validation_up[current] = previous
				else:
					_validation_flags[previous] |= DIAGONAL_RIGHT
				current += 1

	func connected(cells: PackedInt32Array) -> bool:
		"""Each canonical cell enters the exact-sized queue once; no Dictionary or coordinate grid exists."""
		_validation_flags[0] |= VISITED
		_validation_queue[0] = 0
		var head: int = 0
		var tail: int = 1
		while head < tail:
			var row: int = _validation_queue[head]
			head += 1
			tail = _enqueue(_left(cells, row), tail)
			tail = _enqueue(_right(cells, row), tail)
			tail = _enqueue(_validation_up[row], tail)
			tail = _enqueue(_validation_down[row], tail)
		return tail == _validation_capacity

	func _enqueue(row: int, tail: int) -> int:
		"""The visited bit marks enqueue, so later neighbors never duplicate a queue entry."""
		if row < 0 or (_validation_flags[row] & VISITED) != 0:
			return tail
		_validation_flags[row] |= VISITED
		_validation_queue[tail] = row
		return tail + 1

	func _left(cells: PackedInt32Array, row: int) -> int:
		"""Canonical adjacency yields the horizontal neighbor without a search or packed coordinate cast."""
		return row - 1 if row > 0 and cells[row * 2 - 1] == cells[row * 2 + 1] \
			and int(cells[row * 2 - 2]) + 1 == cells[row * 2] else -1

	func _right(cells: PackedInt32Array, row: int) -> int:
		"""Signed int64 comparison preserves both authored int32 extremes."""
		return row + 1 if row + 1 < _validation_capacity and cells[row * 2 + 3] == cells[row * 2 + 1] \
			and int(cells[row * 2]) + 1 == cells[row * 2 + 2] else -1

	func topology_refusal(cells: PackedInt32Array, allow_holes: bool) -> StringName:
		"""After connectivity and diagonal-pinch checks, integer Euler characteristic counts holes exactly."""
		var edges: int = 0
		var filled_squares: int = 0
		for row: int in _validation_capacity:
			var left: bool = _left(cells, row) >= 0
			var right: bool = _right(cells, row) >= 0
			var down: bool = _validation_down[row] >= 0
			if not down and (((_validation_flags[row] & DIAGONAL_LEFT) != 0 and not left) \
					or ((_validation_flags[row] & DIAGONAL_RIGHT) != 0 and not right)):
				return REFUSE_PINCH
			edges += int(right) + int(down)
			if right and down and (_validation_flags[row] & DIAGONAL_RIGHT) != 0:
				filled_squares += 1
		return REFUSE_NONE if allow_holes or _validation_capacity - edges + filled_squares == 1 else REFUSE_HOLES


static func validation_scratch_bytes(cell_count: int) -> int:
	"""Logical packed payload plus capacity scalar; callers separately admit native headers and helper frames."""
	return 13 * cell_count + 8 if cell_count > 0 and cell_count <= MAX_OPERATION_CELLS else 0


static func canonicalize(cells: PackedInt32Array, max_cells: int) -> Dictionary:
	"""Sort and deduplicate packed pairs without modifying the input; reject oversize input."""
	var error: StringName = _input_error(cells, max_cells)
	if error != REFUSE_NONE:
		return _failure(error)
	var keys: PackedInt64Array = PackedInt64Array()
	for pair: int in range(0, cells.size(), 2):
		keys.append(_key(cells[pair], cells[pair + 1]))
	keys.sort()
	var result: PackedInt32Array = PackedInt32Array()
	for index: int in range(keys.size()):
		if index == 0 or keys[index] != keys[index - 1]:
			_append_key(result, keys[index])
	return _success(result)


static func validation_error(cells: PackedInt32Array, max_cells: int, allow_holes: bool) -> StringName:
	"""Require one cardinally connected, canonical footprint and an unambiguous boundary."""
	var error: StringName = _canonical_error(cells, max_cells)
	if error != REFUSE_NONE:
		return error
	if cells.is_empty():
		return REFUSE_EMPTY
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	var scratch: ValidationScratch = ValidationScratch.new(count)
	scratch.link_vertical_rows(cells)
	if not scratch.connected(cells):
		return REFUSE_DISCONNECTED
	return scratch.topology_refusal(cells, allow_holes)


static func rectangle(min_x: int, min_z: int, width: int, depth: int, max_cells: int) -> Dictionary:
	"""Rasterize a positive rectangular extent; invalid requests never yield a partial stamp."""
	return _raster_shape(min_x, min_z, width, depth, 0, 0, max_cells)


static func ellipse(min_x: int, min_z: int, width: int, depth: int, max_cells: int) -> Dictionary:
	"""Include cells whose centers lie inside the ellipse, using exact integer products."""
	return _raster_shape(min_x, min_z, width, depth, 1, 0, max_cells)


static func rounded_rectangle(min_x: int, min_z: int, width: int, depth: int,
		radius_cells: int, max_cells: int) -> Dictionary:
	"""Round the four corners inside the requested rectangle; radius zero keeps straight sides."""
	if radius_cells < 0 or radius_cells > MAX_SHAPE_SPAN or radius_cells * 2 > mini(width, depth):
		return _failure(REFUSE_SHAPE)
	return _raster_shape(min_x, min_z, width, depth, 2, radius_cells, max_cells)


static func brush(center_x: int, center_z: int, radius_cells: int, max_cells: int) -> Dictionary:
	"""Stamp an integer-center disk, including its rim; radius zero paints exactly one cell."""
	if radius_cells < 0 or radius_cells > 16383:
		return _failure(REFUSE_SHAPE)
	if not _cell_coordinate(center_x, center_z):
		return _failure(REFUSE_COORDINATE)
	return _raster_shape(center_x - radius_cells, center_z - radius_cells,
		radius_cells * 2 + 1, radius_cells * 2 + 1, 3, radius_cells, max_cells)


static func tunnel_path(points: PackedInt32Array, radius_cells: int, max_cells: int) -> Dictionary:
	"""Union disk stamps along a reversal-invariant cardinal supercover of the given route."""
	var error: StringName = _input_error(points, max_cells)
	if error != REFUSE_NONE:
		return _failure(error)
	if points.is_empty():
		return _failure(REFUSE_EMPTY)
	var stamp: Dictionary = brush(0, 0, radius_cells, max_cells)
	if not stamp.ok:
		return stamp
	var route: Dictionary = _route_cells(points, max_cells)
	if not route.ok:
		return route
	return _expand_route(route.cells, stamp.cells, max_cells)


static func combine(base: PackedInt32Array, paint: PackedInt32Array, erase: bool,
		max_cells: int) -> Dictionary:
	"""Add or erase complete cells. An empty draft is allowed; validate before confirming it."""
	var error: StringName = _input_error(base, max_cells)
	if error == REFUSE_NONE:
		error = _input_error(paint, max_cells)
	if error != REFUSE_NONE:
		return _failure(error)
	var selected: Dictionary = _cell_set(base)
	for pair: int in range(0, paint.size(), 2):
		var cell_key: int = _key(paint[pair], paint[pair + 1])
		if erase:
			selected.erase(cell_key)
		else:
			selected[cell_key] = true
			if selected.size() > max_cells:
				return _failure(REFUSE_CAPACITY)
	return _success(_sorted_cells(selected))


static func transform_cells(cells: PackedInt32Array, quarter_turns: int,
		offset_x: int, offset_z: int, max_cells: int) -> Dictionary:
	"""Rotate cells clockwise around grid vertex (0,0), then translate by whole cells."""
	var error: StringName = _input_error(cells, max_cells)
	if error != REFUSE_NONE:
		return _failure(error)
	var result: PackedInt32Array = PackedInt32Array()
	var turns: int = posmod(quarter_turns, 4)
	for pair: int in range(0, cells.size(), 2):
		var x: int = cells[pair]
		var z: int = cells[pair + 1]
		for turn: int in range(turns):
			var previous_x: int = x
			x = -z - 1
			z = previous_x
		x += offset_x
		z += offset_z
		if not _cell_coordinate(x, z):
			return _failure(REFUSE_COORDINATE)
		result.append_array(PackedInt32Array([x, z]))
	return canonicalize(result, max_cells)


static func contains_cell(cells: PackedInt32Array, x: int, z: int) -> bool:
	"""Binary-search a previously canonicalized footprint; never allocate a spatial entity."""
	if cells.size() % 2 != 0 or not _cell_coordinate(x, z):
		return false
	@warning_ignore("integer_division") var high: int = cells.size() / 2 - 1
	var low: int = 0
	while low <= high:
		@warning_ignore("integer_division") var middle: int = (low + high) / 2
		var mx: int = cells[middle * 2]
		var mz: int = cells[middle * 2 + 1]
		if mx == x and mz == z:
			return true
		if mz < z or (mz == z and mx < x):
			low = middle + 1
		else:
			high = middle - 1
	return false


static func contains_all(cells: PackedInt32Array, occupied: PackedInt32Array) -> bool:
	"""Require every occupied cell, including concave corners, to lie within the footprint."""
	if occupied.is_empty() or _canonical_error(cells, MAX_OPERATION_CELLS) != REFUSE_NONE:
		return false
	if _input_error(occupied, MAX_OPERATION_CELLS) != REFUSE_NONE:
		return false
	for pair: int in range(0, occupied.size(), 2):
		if not contains_cell(cells, occupied[pair], occupied[pair + 1]):
			return false
	return true


static func boundary_edges(cells: PackedInt32Array) -> PackedInt32Array:
	"""Return exposed [cell_x,cell_z,side] triples in canonical cell/N,E,S,W order."""
	if _canonical_error(cells, MAX_OPERATION_CELLS) != REFUSE_NONE:
		return PackedInt32Array()
	return _boundary_edges_unchecked(cells)


static func _boundary_edges_unchecked(cells: PackedInt32Array) -> PackedInt32Array:
	"""Use temporary O(1) membership for a whole shell, avoiding four binary searches per cell."""
	var edges: PackedInt32Array = PackedInt32Array()
	var selected: Dictionary = _cell_set(cells)
	for pair: int in range(0, cells.size(), 2):
		var x: int = cells[pair]
		var z: int = cells[pair + 1]
		for side: int in range(4):
			var nx: int = x + _side_dx(side)
			var nz: int = z + _side_dz(side)
			if not _cell_coordinate(nx, nz) or not selected.has(_key(nx, nz)):
				edges.append_array(PackedInt32Array([x, z, side]))
	return edges


static func boundary_loops(cells: PackedInt32Array) -> Array[PackedInt32Array]:
	"""Return closed integer corner loops, or no loops for malformed or pinched boundaries."""
	return _trace_loops(boundary_edges(cells))


static func opening_edges(cells: PackedInt32Array, cell_x: int, cell_z: int,
		side: int, width: int) -> Dictionary:
	"""Describe a straight exposed edge run; N/S advance +X and E/W advance +Z."""
	var result: Dictionary = {"ok": false, "error": REFUSE_OPENING, "edges": PackedInt32Array()}
	if side < NORTH or side > WEST or width < 1 or width > MAX_OPERATION_CELLS:
		return result
	if _canonical_error(cells, MAX_OPERATION_CELLS) != REFUSE_NONE:
		return result
	var edges: PackedInt32Array = PackedInt32Array()
	for offset: int in range(width):
		var x: int = cell_x + (offset if side == NORTH or side == SOUTH else 0)
		var z: int = cell_z + (offset if side == EAST or side == WEST else 0)
		if not _cell_coordinate(x, z) or not contains_cell(cells, x, z):
			return result
		if not _is_boundary(cells, x, z, side):
			return result
		edges.append_array(PackedInt32Array([x, z, side]))
	return {"ok": true, "error": REFUSE_NONE, "edges": edges}


static func to_world_corners(corners: PackedInt32Array, cell_size_u: int,
		origin_x_u: int, origin_z_u: int) -> Dictionary:
	"""Convert grid corners to int32 fixed positions; a world unit is the existing 1/1024 m."""
	var result: Dictionary = {"ok": false, "error": REFUSE_WORLD, "points": PackedInt32Array()}
	if cell_size_u < 1 or cell_size_u > INT32_MAX or corners.size() % 2 != 0:
		return result
	if corners.size() > (MAX_OPERATION_CELLS * 4 + 1) * 2:
		return result
	if not _int32(origin_x_u) or not _int32(origin_z_u):
		return result
	var points: PackedInt32Array = PackedInt32Array()
	for pair: int in range(0, corners.size(), 2):
		var x: int = origin_x_u + corners[pair] * cell_size_u
		var z: int = origin_z_u + corners[pair + 1] * cell_size_u
		if not _int32(x) or not _int32(z):
			return result
		points.append_array(PackedInt32Array([x, z]))
	return {"ok": true, "error": REFUSE_NONE, "points": points}


static func _input_error(cells: PackedInt32Array, max_cells: int) -> StringName:
	"""Bound cold-path work before allocating and retain room for each cell's far corners."""
	if cells.size() % 2 != 0:
		return REFUSE_FORMAT
	if max_cells < 1 or max_cells > MAX_OPERATION_CELLS or cells.size() > max_cells * 2:
		return REFUSE_CAPACITY
	for pair: int in range(0, cells.size(), 2):
		if not _cell_coordinate(cells[pair], cells[pair + 1]):
			return REFUSE_COORDINATE
	return REFUSE_NONE


static func _canonical_error(cells: PackedInt32Array, max_cells: int) -> StringName:
	"""Check packed format and strict row-major order without silently repairing saved data."""
	var error: StringName = _input_error(cells, max_cells)
	if error != REFUSE_NONE:
		return error
	for pair: int in range(2, cells.size(), 2):
		if _key(cells[pair - 2], cells[pair - 1]) >= _key(cells[pair], cells[pair + 1]):
			return REFUSE_CANONICAL
	return REFUSE_NONE


static func _shape_error(min_x: int, min_z: int, width: int, depth: int,
		max_cells: int) -> StringName:
	"""Guard fourth-order ellipse arithmetic and raster work before entering its loops."""
	if width < 1 or depth < 1 or width > MAX_SHAPE_SPAN or depth > MAX_SHAPE_SPAN:
		return REFUSE_SHAPE
	if max_cells < 1 or max_cells > MAX_OPERATION_CELLS or width * depth > max_cells * 4:
		return REFUSE_CAPACITY
	if not _cell_coordinate(min_x, min_z) or not _cell_coordinate(min_x + width - 1, min_z + depth - 1):
		return REFUSE_COORDINATE
	return REFUSE_NONE


static func _raster_shape(min_x: int, min_z: int, width: int, depth: int,
		shape: int, radius: int, max_cells: int) -> Dictionary:
	"""Share canonical coverage and capacity failure across the shape palette."""
	var error: StringName = _shape_error(min_x, min_z, width, depth, max_cells)
	if error != REFUSE_NONE:
		return _failure(error)
	var cells: PackedInt32Array = PackedInt32Array()
	for z: int in range(depth):
		for x: int in range(width):
			if _shape_contains(x, z, width, depth, shape, radius):
				if cells.size() == max_cells * 2:
					return _failure(REFUSE_CAPACITY)
				cells.append_array(PackedInt32Array([min_x + x, min_z + z]))
	return _success(cells)


static func _shape_contains(x: int, z: int, width: int, depth: int, shape: int, radius: int) -> bool:
	"""Rasterize centers exactly; maximum products stay below signed int64 with MAX_SHAPE_SPAN."""
	if shape == 1:
		var dx: int = 2 * x + 1 - width
		var dz: int = 2 * z + 1 - depth
		return dx * dx * depth * depth + dz * dz * width * width <= width * width * depth * depth
	if shape == 2 and radius > 0:
		var dx: int = maxi(0, maxi(2 * radius - (2 * x + 1), 2 * x + 1 - 2 * (width - radius)))
		var dz: int = maxi(0, maxi(2 * radius - (2 * z + 1), 2 * z + 1 - 2 * (depth - radius)))
		return dx * dx + dz * dz <= 4 * radius * radius
	if shape == 3:
		return (x - radius) * (x - radius) + (z - radius) * (z - radius) <= radius * radius
	return true


static func _route_cells(points: PackedInt32Array, max_cells: int) -> Dictionary:
	"""Bound total raster traversal, including repeated segments, before walking the route."""
	var steps: int = 1
	for pair: int in range(2, points.size(), 2):
		steps += absi(points[pair] - points[pair - 2]) + absi(points[pair + 1] - points[pair - 1])
		if steps > max_cells * 4:
			return _failure(REFUSE_CAPACITY)
	var selected: Dictionary = {_key(points[0], points[1]): true}
	for pair: int in range(2, points.size(), 2):
		_supercover(points[pair - 2], points[pair - 1], points[pair], points[pair + 1], selected)
		if selected.size() > max_cells:
			return _failure(REFUSE_CAPACITY)
	return _success(_sorted_cells(selected))


static func _supercover(x: int, z: int, end_x: int, end_z: int, selected: Dictionary) -> void:
	"""A line exactly through a corner includes both neighbors, so reversal preserves coverage."""
	var nx: int = absi(end_x - x)
	var nz: int = absi(end_z - z)
	var sx: int = signi(end_x - x)
	var sz: int = signi(end_z - z)
	var ix: int = 0
	var iz: int = 0
	while ix < nx or iz < nz:
		var decision: int = (2 * ix + 1) * nz - (2 * iz + 1) * nx
		if decision == 0:
			selected[_key(x + sx, z)] = true
			selected[_key(x, z + sz)] = true
			x += sx
			z += sz
			ix += 1
			iz += 1
		elif decision < 0:
			x += sx
			ix += 1
		else:
			z += sz
			iz += 1
		selected[_key(x, z)] = true


static func _expand_route(route: PackedInt32Array, stamp: PackedInt32Array, max_cells: int) -> Dictionary:
	"""Apply width to the whole route, preserving joins; refuse large repeated raster workloads."""
	if route.size() * stamp.size() > max_cells * 64:
		return _failure(REFUSE_CAPACITY)
	var selected: Dictionary = {}
	for point: int in range(0, route.size(), 2):
		for offset: int in range(0, stamp.size(), 2):
			var x: int = route[point] + stamp[offset]
			var z: int = route[point + 1] + stamp[offset + 1]
			if not _cell_coordinate(x, z):
				return _failure(REFUSE_COORDINATE)
			selected[_key(x, z)] = true
			if selected.size() > max_cells:
				return _failure(REFUSE_CAPACITY)
	return _success(_sorted_cells(selected))


static func _connected(cells: PackedInt32Array) -> bool:
	"""Cardinal flood fill over cells only; a huge sparse bounding rectangle allocates no grid."""
	var pending: Dictionary = _cell_set(cells)
	var queue: PackedInt64Array = PackedInt64Array([_key(cells[0], cells[1])])
	pending.erase(queue[0])
	var cursor: int = 0
	while cursor < queue.size():
		var cell_key: int = queue[cursor]
		var x: int = _key_x(cell_key)
		var z: int = _key_z(cell_key)
		for side: int in range(4):
			var nx: int = x + _side_dx(side)
			var nz: int = z + _side_dz(side)
			if not _cell_coordinate(nx, nz):
				continue
			var neighbor: int = _key(nx, nz)
			if pending.has(neighbor):
				pending.erase(neighbor)
				queue.append(neighbor)
		cursor += 1
	return pending.is_empty()


static func _is_boundary(cells: PackedInt32Array, x: int, z: int, side: int) -> bool:
	"""A cell owns a wall only where its cardinal neighbor is absent."""
	return not contains_cell(cells, x + _side_dx(side), z + _side_dz(side))


static func _trace_loops(edges: PackedInt32Array) -> Array[PackedInt32Array]:
	"""Trace oriented exposed edges; duplicate outgoing corners identify a pinched boundary."""
	var loops: Array[PackedInt32Array] = []
	var outgoing: Dictionary = {}
	for edge: int in range(0, edges.size(), 3):
		var start_key: int = _edge_start(edges[edge], edges[edge + 1], edges[edge + 2])
		if outgoing.has(start_key):
			return []
		outgoing[start_key] = edge
	for edge: int in range(0, edges.size(), 3):
		var start_key: int = _edge_start(edges[edge], edges[edge + 1], edges[edge + 2])
		if not outgoing.has(start_key):
			continue
		var loop: PackedInt32Array = _trace_one_loop(start_key, outgoing, edges)
		if loop.is_empty():
			return []
		loops.append(_canonical_loop(loop))
	return loops


static func _trace_one_loop(start_key: int, outgoing: Dictionary, edges: PackedInt32Array) -> PackedInt32Array:
	"""Consume one complete loop, retaining its clockwise exterior or counterclockwise hole winding."""
	var loop: PackedInt32Array = PackedInt32Array()
	var cursor: int = start_key
	while outgoing.has(cursor):
		_append_key(loop, cursor)
		var edge: int = int(outgoing[cursor])
		outgoing.erase(cursor)
		cursor = _edge_end(edges[edge], edges[edge + 1], edges[edge + 2])
		if cursor == start_key:
			_append_key(loop, cursor)
			return loop
	return PackedInt32Array()


static func _canonical_loop(loop: PackedInt32Array) -> PackedInt32Array:
	"""Start each ring at its smallest z/x corner without changing winding or dropping steps."""
	var first: int = 0
	for pair: int in range(2, loop.size() - 2, 2):
		if _key(loop[pair], loop[pair + 1]) < _key(loop[first], loop[first + 1]):
			first = pair
	var result: PackedInt32Array = PackedInt32Array()
	for offset: int in range(0, loop.size() - 2, 2):
		var pair: int = (first + offset) % (loop.size() - 2)
		result.append_array(PackedInt32Array([loop[pair], loop[pair + 1]]))
	result.append_array(PackedInt32Array([result[0], result[1]]))
	return result


static func _edge_start(x: int, z: int, side: int) -> int:
	"""Orient edges with room interior on the right in X/Z plan, including cavity walls."""
	return _key(x + (1 if side == EAST or side == SOUTH else 0),
		z + (1 if side == SOUTH or side == WEST else 0))


static func _edge_end(x: int, z: int, side: int) -> int:
	"""Match the next corner of NORTH eastward, EAST southward, SOUTH westward, WEST northward."""
	return _key(x + (1 if side == NORTH or side == EAST else 0),
		z + (1 if side == EAST or side == SOUTH else 0))


static func _side_dx(side: int) -> int:
	"""Return the integer horizontal offset for a cardinal side."""
	return 1 if side == EAST else (-1 if side == WEST else 0)


static func _side_dz(side: int) -> int:
	"""Return the integer depth offset; north is the project's negative Z direction."""
	return 1 if side == SOUTH else (-1 if side == NORTH else 0)


static func _cell_set(cells: PackedInt32Array) -> Dictionary:
	"""Build temporary set scratch only for cold draft operations; dictionary order is never output."""
	var selected: Dictionary = {}
	for pair: int in range(0, cells.size(), 2):
		selected[_key(cells[pair], cells[pair + 1])] = true
	return selected


static func _sorted_cells(selected: Dictionary) -> PackedInt32Array:
	"""Sort set keys before returning authoritative cells, independent of insertion order."""
	var keys: PackedInt64Array = PackedInt64Array(selected.keys())
	keys.sort()
	var cells: PackedInt32Array = PackedInt32Array()
	for cell_key: int in keys:
		_append_key(cells, cell_key)
	return cells


static func _key(x: int, z: int) -> int:
	"""Pack signed z in the high word and biased signed x below it, preserving row-major order."""
	return (z << 32) | ((x - INT32_MIN) & 0xffffffff)


static func _key_x(cell_key: int) -> int:
	"""Decode signed X from the biased low word."""
	return (cell_key & 0xffffffff) + INT32_MIN


static func _key_z(cell_key: int) -> int:
	"""Arithmetic right shift restores signed Z, including negative coordinates."""
	return cell_key >> 32


static func _append_key(cells: PackedInt32Array, cell_key: int) -> void:
	"""Append one packed pair without narrowing a fixed-point world coordinate."""
	cells.append(_key_x(cell_key))
	cells.append(_key_z(cell_key))


static func _cell_coordinate(x: int, z: int) -> bool:
	"""Cells need an int32 far corner, so INT32_MAX itself can only be a corner."""
	return x >= INT32_MIN and x < INT32_MAX and z >= INT32_MIN and z < INT32_MAX


static func _int32(value: int) -> bool:
	"""Check before narrowing into PackedInt32Array; wrapping is never a placement operation."""
	return value >= INT32_MIN and value <= INT32_MAX


static func _success(cells: PackedInt32Array) -> Dictionary:
	"""Publish a cold value result; this helper stores no authoritative room or entity state."""
	return {"ok": true, "error": REFUSE_NONE, "cells": cells}


static func _failure(error: StringName) -> Dictionary:
	"""Refuse atomically: a failure carries no partial paint or silently clipped footprint."""
	return {"ok": false, "error": error, "cells": PackedInt32Array()}
