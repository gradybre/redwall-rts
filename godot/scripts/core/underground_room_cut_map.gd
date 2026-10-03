extends RefCounted
## One synchronous derived cursor, never a second excavation ledger or a construction permission.
## The caller admits the complete cold lifetime before configure and owns the canonical input image.

const Space := preload("res://scripts/core/room_space.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const REFUSE_INPUT: StringName = &"ROOM_CUT_MAP_INPUT"
const REFUSE_DOMAIN: StringName = &"ROOM_CUT_MAP_DOMAIN"
const REFUSE_WORK: StringName = &"ROOM_CUT_MAP_WORK"
const REFUSE_CAPACITY: StringName = &"ROOM_CUT_MAP_CAPACITY"
const REFUSE_CLOSED: StringName = &"ROOM_CUT_MAP_CLOSED"
const LOW_MASK: int = 4294967295

var _cells: PackedInt32Array = PackedInt32Array()
var _intervals: PackedInt64Array = PackedInt64Array()
var _capacity: int = 0
var _origin: Vector3i = Vector3i.ZERO
var _datum: Vector3i = Vector3i.ZERO
var _minimum: Vector3i = Vector3i.ZERO
var _size: Vector3i = Vector3i.ZERO
var _pitch: int = 0
var _remaining: int = 0
var _limit: int = 0
var _emitted: int = 0
var _y: int = 0
var _y_end: int = 0
var _first_z: int = 0
var _next_z: int = 0
var _band_z: int = 0
var _first: int = 0
var _interval_count: int = 0
var _interval_at: int = 0
var _x: int = 0
var _x_end: int = 0
var _current_key: int = -1
var _current: Vector3i = Vector3i.ZERO
var _started: bool = false
var _ready: bool = false
var _error: StringName = &""


func configure(cells: PackedInt32Array, origin_u: Vector3i, pitch_u: int, height_u: int,
		domain: Space.Domain, checks: int, cube_limit: int) -> StringName:
	"""Preflight every transformed cell and rank before the only variable scratch allocation."""
	if _started:
		return REFUSE_CLOSED
	_started = true
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	_capacity = clampi(count, 0, Footprint.MAX_OPERATION_CELLS)
	if cells.size() < 2 or cells.size() % 2 != 0 or count != _capacity or domain == null \
			or pitch_u < 1 or pitch_u > Space.I32_MAX or height_u < 1 or height_u > Space.I32_MAX \
			or checks < 1 or checks > Space.MAX_CHECKS or cube_limit < 0 or cube_limit > Space.MAX_CHECKS:
		return _fail(REFUSE_INPUT)
	if cube_limit == 0:
		return _fail(REFUSE_CAPACITY)
	_origin = origin_u
	_pitch = pitch_u
	_remaining = checks
	_limit = cube_limit
	_error = _domain_refusal(domain.descriptor(), height_u)
	if _error == &"":
		_error = _cells_refusal(cells)
	if _error != &"":
		return _error
	_cells = cells # Borrow the caller's private immutable image; this owner never writes it.
	_intervals.resize(_capacity)
	_first_z = _quantum(int(_origin.z) + int(cells[1]) * _pitch, 2)
	_next_z = _first_z
	_ready = true
	return &""


func _domain_refusal(descriptor: Dictionary, height_u: int) -> StringName:
	"""The actual immutable Domain must support the same signed-I64 key rank as Sites."""
	_datum = descriptor.datum_u
	_minimum = descriptor.min_quantum
	_size = descriptor.size_quanta
	if not Space.valid_ref(descriptor.world_ref) or not Space.valid_box(descriptor.bounds_u) \
			or _size.x < 1 or _size.y < 1 or _size.z < 1 or _capacity > descriptor.max_cells:
		return REFUSE_DOMAIN
	if _remaining > descriptor.max_checks:
		return REFUSE_WORK
	var math: IntMath.IntResult = IntMath.IntResult.new()
	if not IntMath.checked_mul_into(_size.x, _size.z, math) \
			or not IntMath.checked_mul_into(math.value, _size.y, math):
		return REFUSE_DOMAIN
	var high: int = int(_origin.y) + height_u
	if not Space.int32(high):
		return REFUSE_INPUT
	_y = _quantum(_origin.y, 1)
	_y_end = _quantum(high - 1, 1) + 1
	if _y < 0 or _y_end > _size.y:
		return REFUSE_DOMAIN
	return REFUSE_CAPACITY if _y_end - _y > _limit else &""


func _cells_refusal(cells: PackedInt32Array) -> StringName:
	"""A pure geometry cursor accepts canonical unions; RoomFootprint separately owns room shape policy."""
	for pair: int in range(0, cells.size(), 2):
		if not _spend(1):
			return _error
		if pair > 0 and (cells[pair + 1] < cells[pair - 1] \
				or (cells[pair + 1] == cells[pair - 1] and cells[pair] <= cells[pair - 2])):
			return REFUSE_INPUT
		var code: StringName = _cell_refusal(cells[pair], cells[pair + 1])
		if code != &"":
			return code
	return &""


func _cell_refusal(x: int, z: int) -> StringName:
	"""Multiply in int64, test endpoints, and reject an individually impossible bill without allocating."""
	var low_x: int = int(_origin.x) + x * _pitch
	var low_z: int = int(_origin.z) + z * _pitch
	var high_x: int = low_x + _pitch
	var high_z: int = low_z + _pitch
	if not Space.int32(low_x) or not Space.int32(low_z) or not Space.int32(high_x) or not Space.int32(high_z):
		return REFUSE_INPUT
	var left: int = _quantum(low_x, 0)
	var near: int = _quantum(low_z, 2)
	var right: int = _quantum(high_x - 1, 0) + 1
	var far: int = _quantum(high_z - 1, 2) + 1
	if left < 0 or near < 0 or right > _size.x or far > _size.z:
		return REFUSE_DOMAIN
	@warning_ignore("integer_division") var horizontal_limit: int = _limit / (_y_end - _y)
	@warning_ignore("integer_division") var width_limit: int = horizontal_limit / (far - near)
	return REFUSE_CAPACITY if right - left > width_limit else &""


func advance() -> bool:
	"""Emit each touched whole cube once in exact Sites Y/Z/X key order; false requires checking refusal."""
	_current_key = -1
	if not _ready or _error != &"":
		return false
	while _y < _y_end:
		if _x < _x_end:
			return _emit()
		if _interval_at < _interval_count:
			var encoded: int = _intervals[_interval_at]
			_interval_at += 1
			_x = encoded >> 32
			_x_end = encoded & LOW_MASK
			continue
		if not _prepare_band():
			return false
		if _interval_count == 0:
			_y += 1
			_first = 0
			_next_z = _first_z
	return false


func _emit() -> bool:
	"""The bound limits work/output without ever silently truncating the returned stream."""
	if _emitted >= _limit:
		_fail(REFUSE_CAPACITY)
		return false
	if not _spend(1):
		return false
	_current = Vector3i(_x, _y, _band_z)
	_current_key = (int(_y) * _size.z + _band_z) * _size.x + _x
	_x += 1
	_emitted += 1
	return true


func _prepare_band() -> bool:
	"""Skip absent coordinate spans directly; overlapping fine rows contribute at most one interval per run."""
	_interval_count = 0
	_interval_at = 0
	while _first < _cells.size() and _row_last_quantum(_first) < _next_z:
		if not _spend(1):
			return false
		_first += 2
	if _first == _cells.size():
		return true
	_next_z = maxi(_next_z, _row_first_quantum(_first))
	_band_z = _next_z
	_next_z += 1
	return _gather_band() and _sort_intervals() and _merge_intervals()


func _gather_band() -> bool:
	"""Transform maximal canonical fine X runs; duplicate fine rows are merged before any cube is emitted."""
	var at: int = _first
	while at < _cells.size() and _row_first_quantum(at) <= _band_z:
		var end: int = at + 2
		if not _spend(1):
			return false
		while end < _cells.size() and _cells[end + 1] == _cells[at + 1] \
				and int(_cells[end]) == int(_cells[end - 2]) + 1:
			if not _spend(1):
				return false
			end += 2
		var low: int = _quantum(int(_origin.x) + int(_cells[at]) * _pitch, 0)
		var high: int = _quantum(int(_origin.x) + (int(_cells[end - 2]) + 1) * _pitch - 1, 0) + 1
		_intervals[_interval_count] = (low << 32) | high
		_interval_count += 1
		at = end
	return true


func _sort_intervals() -> bool:
	"""In-place active-prefix heapsort avoids copying, resizing or sorting unused capacity."""
	@warning_ignore("integer_division") var parent: int = _interval_count / 2 - 1
	while parent >= 0:
		if not _sift(parent, _interval_count):
			return false
		parent -= 1
	for end: int in range(_interval_count - 1, 0, -1):
		var saved: int = _intervals[0]
		_intervals[0] = _intervals[end]
		_intervals[end] = saved
		if not _sift(0, end):
			return false
	return true


func _sift(root: int, length: int) -> bool:
	"""Charge each bounded heap comparison step to the caller's finite cold operation."""
	while root * 2 + 1 < length:
		if not _spend(1):
			return false
		var child: int = root * 2 + 1
		if child + 1 < length and _intervals[child] < _intervals[child + 1]:
			child += 1
		if _intervals[root] >= _intervals[child]:
			return true
		var saved: int = _intervals[root]
		_intervals[root] = _intervals[child]
		_intervals[child] = saved
		root = child
	return true


func _merge_intervals() -> bool:
	"""Merge overlaps and touching economic intervals in place, preserving genuine whole-cube gaps."""
	var written: int = 0
	for at: int in _interval_count:
		if not _spend(1):
			return false
		var encoded: int = _intervals[at]
		if written > 0 and (encoded >> 32) <= (_intervals[written - 1] & LOW_MASK):
			var right: int = maxi(_intervals[written - 1] & LOW_MASK, encoded & LOW_MASK)
			_intervals[written - 1] = ((_intervals[written - 1] >> 32) << 32) | right
		else:
			_intervals[written] = encoded
			written += 1
	_interval_count = written
	return true


func _row_first_quantum(pair: int) -> int:
	"""Read the first paid Z band touched by this validated fine row."""
	return _quantum(int(_origin.z) + int(_cells[pair + 1]) * _pitch, 2)


func _row_last_quantum(pair: int) -> int:
	"""The high endpoint is exclusive, including for negative coordinates and an offset datum."""
	return _quantum(int(_origin.z) + (int(_cells[pair + 1]) + 1) * _pitch - 1, 2)


func _quantum(value: int, axis: int) -> int:
	"""Use the immutable economic datum and signed floor division, then normalize to the actual Domain."""
	var delta: int = value - int(_datum[axis])
	@warning_ignore("integer_division") var coordinate: int = delta / Space.QUANTUM_U
	if delta < 0 and delta % Space.QUANTUM_U != 0:
		coordinate -= 1
	return coordinate - int(_minimum[axis])


func current_origin() -> Vector3i:
	"""Return the absolute paid-cube origin only while the last advance succeeded."""
	if _current_key < 0:
		return Vector3i.ZERO
	return Vector3i(int(_datum.x) + (int(_minimum.x) + _current.x) * Space.QUANTUM_U,
		int(_datum.y) + (int(_minimum.y) + _current.y) * Space.QUANTUM_U,
		int(_datum.z) + (int(_minimum.z) + _current.z) * Space.QUANTUM_U)


func current_key() -> int:
	"""Expose the exact Sites rank as geometry data; -1 denotes no current cube."""
	return _current_key


func emitted_count() -> int:
	"""A partial cold count after refusal is diagnostic only, never an accepted bill."""
	return _emitted


func remaining_checks() -> int:
	"""Return unused work for the enclosing exact same cold operation."""
	return _remaining


func charge_checks(checks: int) -> StringName:
	"""Let the synchronous consumer charge real owner observations against this same finite work envelope."""
	if not _ready or _error != &"":
		return _error if _error != &"" else REFUSE_CLOSED
	return &"" if _spend(checks) else _error


func refusal() -> StringName:
	"""End-of-stream is successful only after configure and when this code is empty."""
	return _error if _started else REFUSE_CLOSED


func clear() -> void:
	"""Drop both packed lifetimes before the caller releases its lease; a closed cursor cannot resume."""
	_cells = PackedInt32Array()
	_intervals = PackedInt64Array()
	_ready = false
	_current_key = -1
	_error = REFUSE_CLOSED


func _spend(checks: int) -> bool:
	"""No coordinate span or nested sorting loop can evade the finite engineering work envelope."""
	if checks < 0 or checks > _remaining:
		_fail(REFUSE_WORK)
		return false
	_remaining -= checks
	return true


func _fail(code: StringName) -> StringName:
	"""Refusals invalidate only this cold derived cursor, never any authoritative owner."""
	_error = code
	_current_key = -1
	return code
