extends RefCounted
## Where the demo cast's residents stand, bucketed by ground cell (decision 1004). Presentation only.
##
## WHY. A walker's step asked of every resident whether it was in the way (cast_space.gd `separation`, `constrain`,
## `standing_blocks`): O(walkers x residents) every sub-step, the scale test's fourth hot spot (decision 0561), 20 ms a
## frame when a crowd walks home at dusk. Each resident is kept in the bucket of the CELL_M cell it stands in -- moved
## between buckets only when it crosses into another cell (`move`) -- so a question about a box reads the residents in
## the cells it overlaps, not all of them.
##
## `gather` writes the candidates into the caller's array: every resident in a cell the box overlaps, and possibly
## others (cells share BUCKETS by hash), so a caller still tests each by distance exactly as it tested everyone. Asked
## `sorted`, they come in ascending order -- the order the old scan visited them in -- so a sum or a sequence of pushes
## over them is the very sum or sequence it was. Each bucket keeps its residents in ascending order (`_link`), so the
## sort moves nothing for a crowd in one cell, and only the residents of different cells out of order for others. A box wider than MAX_CELLS cells gathers everyone. Nothing allocates
## after the columns have grown with the residents.

const CELL_M: float = 2.0
## Hashed buckets (a power of two).
const BUCKETS: int = 1024
## A box over more cells than this reads every resident instead (a long sight line across the village).
const MAX_CELLS: int = 64

## Per bucket its first resident (-1: none), and the look that last read it; per resident the next and previous in its
## bucket, and its bucket.
var _head: PackedInt32Array = PackedInt32Array()
var _read_by: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _prev: PackedInt32Array = PackedInt32Array()
var _bucket_of: PackedInt32Array = PackedInt32Array()
var _look: int = 0


func _init() -> void:
	"""Every bucket empty."""
	_head.resize(BUCKETS)
	_head.fill(-1)
	_read_by.resize(BUCKETS)


func clear() -> void:
	"""Nobody kept."""
	_head.fill(-1)
	_next.clear()
	_prev.clear()
	_bucket_of.clear()


func count() -> int:
	"""How many residents are kept (index 0 to count - 1)."""
	return _next.size()


func add(at: Vector2) -> void:
	"""Keep the next resident (index `count()`), standing at `at`."""
	var i := _next.size()
	_next.append(-1)
	_prev.append(-1)
	_bucket_of.append(-1)
	_link(i, _bucket(at))


func move(i: int, at: Vector2) -> void:
	"""Resident `i` now stands at `at`: into its new cell's bucket when it has crossed into another."""
	var b := _bucket(at)
	if b != _bucket_of[i]:
		_unlink(i)
		_link(i, b)


func gather(lo: Vector2, hi: Vector2, out: PackedInt32Array, sorted: bool) -> int:
	"""Into `out` (at least `count()` long): every resident in a cell the box [lo, hi] overlaps (and maybe others), in
	ascending order when `sorted`; everyone, in order, when the box spans more than MAX_CELLS cells. The count."""
	var x0 := floori(lo.x / CELL_M)
	var x1 := floori(hi.x / CELL_M)
	var z0 := floori(lo.y / CELL_M)
	var z1 := floori(hi.y / CELL_M)
	if (x1 - x0 + 1) * (z1 - z0 + 1) > MAX_CELLS:
		for i in _next.size():
			out[i] = i
		return _next.size()
	_look += 1
	var n := 0
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var b := _bucket_at(cx, cz)
			if _read_by[b] != _look:
				_read_by[b] = _look
				n = _gather_bucket(b, out, n, sorted)
	return n


func _gather_bucket(b: int, out: PackedInt32Array, n: int, sorted: bool) -> int:
	"""Bucket `b`'s residents onto the first `n` of `out` (each into its place, when `sorted`). The new count."""
	var i := _head[b]
	while i >= 0:
		var k := n
		if sorted:
			while k > 0 and out[k - 1] > i:
				out[k] = out[k - 1]
				k -= 1
		out[k] = i
		n += 1
		i = _next[i]
	return n


func _link(i: int, b: int) -> void:
	"""Resident `i` into bucket `b` in its place: a bucket lists its residents in ascending order, so a crowd in one cell
	comes out of a sorted look already in order (the insertion sort moves nothing)."""
	_bucket_of[i] = b
	var before := -1
	var after := _head[b]
	while after >= 0 and after < i:
		before = after
		after = _next[after]
	_prev[i] = before
	_next[i] = after
	if after >= 0:
		_prev[after] = i
	if before >= 0:
		_next[before] = i
	else:
		_head[b] = i


func _unlink(i: int) -> void:
	"""Resident `i` out of its bucket."""
	if _prev[i] >= 0:
		_next[_prev[i]] = _next[i]
	else:
		_head[_bucket_of[i]] = _next[i]
	if _next[i] >= 0:
		_prev[_next[i]] = _prev[i]


func _bucket(at: Vector2) -> int:
	"""The bucket of the cell holding `at`."""
	return _bucket_at(floori(at.x / CELL_M), floori(at.y / CELL_M))


static func _bucket_at(cx: int, cz: int) -> int:
	"""The bucket of cell (cx, cz)."""
	return ((cx * 73856093) ^ (cz * 19349663)) & (BUCKETS - 1)
