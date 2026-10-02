extends RefCounted
## A uniform bucket grid over points on the ground plane (x, z), for the demo cast. Decision 0196.
##
## Built once from a fixed set of points (obstacle centres, or a navigation graph's nodes) and
## queried by box: `query()` writes the indices of every point whose cell overlaps the box into a
## caller-owned array and returns how many, so a query allocates nothing. Each point lives in the
## one cell holding it, so a caller looking for points within `reach` of something widens its box by
## that reach itself.
##
## Rebuilt per plan for the residents standing still (cast_nav.gd, decision 1001), so a rebuild allocates nothing once
## its arrays have grown: the counting sort's cursor is a member, not a copy.
##
## DISKS (`build_disks`, decision 1001). A disk is kept in EVERY cell its bounding box overlaps, not only its centre's:
## a question about a box then reads only the cells the box itself overlaps, however wide the widest disk -- the
## village's widest circle is 7.3 m, and a look padded by it read sixty-odd cells. A disk can then come back more
## than once from one query; a yes-or-no test over them does not mind.

const DEFAULT_CELL_M: float = 2.0

var cell_m: float = DEFAULT_CELL_M
var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _first: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()
var _cursor: PackedInt32Array = PackedInt32Array()


func build(points: PackedVector2Array, cell: float, count: int = -1) -> void:
	"""Bucket the first `count` of `points` (all of them when -1) into cells of `cell` metres (compressed rows: _first
	per cell, then _items). Its arrays only grow (see the header)."""
	cell_m = cell
	var n := points.size() if count < 0 else count
	if _items.size() < n:
		_items.resize(n)
	if n == 0:
		_cols = 0
		_rows = 0
		_first = PackedInt32Array([0])
		return
	var lo := points[0]
	var hi := points[0]
	for i in n:
		lo = lo.min(points[i])
		hi = hi.max(points[i])
	_origin = lo
	_cols = int((hi.x - lo.x) / cell) + 1
	_rows = int((hi.y - lo.y) / cell) + 1
	_fill(points, n)


func _fill(points: PackedVector2Array, n: int) -> void:
	"""Counting sort of the first `n` points into their cells."""
	var cells := _cols * _rows
	if _first.size() < cells + 1:
		_first.resize(cells + 1)
		_cursor.resize(cells + 1)
	_first.fill(0)
	for i in n:
		_first[_cell_of(points[i]) + 1] += 1
	for c in cells:
		_first[c + 1] += _first[c]
	for c in cells + 1:
		_cursor[c] = _first[c]
	for i in n:
		var c := _cell_of(points[i])
		_items[_cursor[c]] = i
		_cursor[c] += 1


func build_disks(centres: PackedVector2Array, radii: PackedFloat32Array, cell: float) -> void:
	"""Bucket each disk (centre, radius) into every cell its bounding box overlaps (see DISKS)."""
	cell_m = cell
	if centres.is_empty():
		_cols = 0
		_rows = 0
		_first = PackedInt32Array([0])
		return
	var lo := centres[0]
	var hi := centres[0]
	for i in centres.size():
		lo = lo.min(centres[i] - Vector2(radii[i], radii[i]))
		hi = hi.max(centres[i] + Vector2(radii[i], radii[i]))
	_origin = lo
	_cols = int((hi.x - lo.x) / cell) + 1
	_rows = int((hi.y - lo.y) / cell) + 1
	_fill_disks(centres, radii)


func _fill_disks(centres: PackedVector2Array, radii: PackedFloat32Array) -> void:
	"""Counting sort of the disks into every cell they overlap: count, prefix, place."""
	var cells := _cols * _rows
	_first.resize(cells + 1)
	_cursor.resize(cells + 1)
	_first.fill(0)
	for pass_index in 2:
		if pass_index == 1:
			for c in cells:
				_first[c + 1] += _first[c]
			for c in cells + 1:
				_cursor[c] = _first[c]
			_items.resize(_first[cells])
		for i in centres.size():
			_disk_cells(i, centres[i], radii[i], pass_index == 1)


func _disk_cells(i: int, centre: Vector2, radius: float, place: bool) -> void:
	"""Disk `i`'s cells: counted (into _first), or `i` placed into each (through _cursor)."""
	var a := _cell_xz(centre - Vector2(radius, radius))
	var b := _cell_xz(centre + Vector2(radius, radius))
	for cz in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var c := cz * _cols + cx
			if place:
				_items[_cursor[c]] = i
				_cursor[c] += 1
			else:
				_first[c + 1] += 1


func _cell_xz(p: Vector2) -> Vector2i:
	"""The (column, row) of the cell holding `p` (clamped to the grid)."""
	return Vector2i(clampi(int((p.x - _origin.x) / cell_m), 0, _cols - 1), clampi(int((p.y - _origin.y) / cell_m), 0, _rows - 1))


func item_count() -> int:
	"""How many entries the grid holds (a query's `out` needs at most this many)."""
	return _first[_cols * _rows] if _cols > 0 else 0


func _cell_of(p: Vector2) -> int:
	"""The flat index of the cell holding `p` (clamped to the grid)."""
	var cx := clampi(int((p.x - _origin.x) / cell_m), 0, _cols - 1)
	var cz := clampi(int((p.y - _origin.y) / cell_m), 0, _rows - 1)
	return cz * _cols + cx


func query(lo: Vector2, hi: Vector2, out: PackedInt32Array) -> int:
	"""Write the index of every point in a cell overlapping [lo, hi] into `out`; return the count.
	`out` must be at least as long as the point set."""
	if _cols == 0 or hi.x < _origin.x - cell_m or hi.y < _origin.y - cell_m:
		return 0
	var x0 := clampi(int(floorf((lo.x - _origin.x) / cell_m)), 0, _cols - 1)
	var x1 := clampi(int(floorf((hi.x - _origin.x) / cell_m)), 0, _cols - 1)
	var z0 := clampi(int(floorf((lo.y - _origin.y) / cell_m)), 0, _rows - 1)
	var z1 := clampi(int(floorf((hi.y - _origin.y) / cell_m)), 0, _rows - 1)
	var count := 0
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var c := cz * _cols + cx
			for k in range(_first[c], _first[c + 1]):
				out[count] = _items[k]
				count += 1
	return count
