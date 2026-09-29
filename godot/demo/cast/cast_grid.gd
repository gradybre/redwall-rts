extends RefCounted
## A uniform bucket grid over points on the ground plane (x, z), for the demo cast. Decision 0196.
##
## Built once from a fixed set of points (obstacle centres, or a navigation graph's nodes) and
## queried by box: `query()` writes the indices of every point whose cell overlaps the box into a
## caller-owned array and returns how many, so a query allocates nothing. Each point lives in the
## one cell holding it, so a caller looking for points within `reach` of something widens its box by
## that reach itself.

const DEFAULT_CELL_M: float = 2.0

var cell_m: float = DEFAULT_CELL_M
var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _first: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()


func build(points: PackedVector2Array, cell: float) -> void:
	"""Bucket `points` into cells of `cell` metres (compressed rows: _first per cell, then _items)."""
	cell_m = cell
	_items.resize(points.size())
	if points.is_empty():
		_cols = 0
		_rows = 0
		_first = PackedInt32Array([0])
		return
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	_origin = lo
	_cols = int((hi.x - lo.x) / cell) + 1
	_rows = int((hi.y - lo.y) / cell) + 1
	_fill(points)


func _fill(points: PackedVector2Array) -> void:
	"""Counting sort of the points into their cells."""
	_first.resize(_cols * _rows + 1)
	_first.fill(0)
	for p in points:
		_first[_cell_of(p) + 1] += 1
	for c in _cols * _rows:
		_first[c + 1] += _first[c]
	var cursor := _first.duplicate()
	for i in points.size():
		var c := _cell_of(points[i])
		_items[cursor[c]] = i
		cursor[c] += 1


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
