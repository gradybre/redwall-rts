extends RefCounted
## Bounded union of non-flat entry boxes on the existing immutable physical cut lattice.
## Derived cold scratch only. Actual Sites owns claims, paid history and publication. Decision1107.

const Space := preload("res://scripts/core/room_space.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const REFUSE_INPUT: StringName = &"ENTRY_CUT_MAP_INPUT"
const REFUSE_DOMAIN: StringName = &"ENTRY_CUT_MAP_DOMAIN"
const REFUSE_WORK: StringName = &"ENTRY_CUT_MAP_WORK"
const REFUSE_CAPACITY: StringName = &"ENTRY_CUT_MAP_CAPACITY"
const REFUSE_CLOSED: StringName = &"ENTRY_CUT_MAP_CLOSED"
const BOX_FIELDS: int = 6
const CONTROL_BYTES: int = 512
const LOW_MASK: int = 4294967295

var _boxes: PackedInt32Array = PackedInt32Array()
var _intervals: PackedInt64Array = PackedInt64Array()
var _datum: Vector3i = Vector3i.ZERO
var _minimum: Vector3i = Vector3i.ZERO
var _size: Vector3i = Vector3i.ZERO
var _capacity: int = 0
var _remaining: int = 0
var _limit: int = 0
var _emitted: int = 0
var _y: int = 0
var _next_z: int = 0
var _band_z: int = 0
var _interval_count: int = 0
var _interval_at: int = 0
var _x: int = 0
var _x_end: int = 0
var _current_key: int = -1
var _current: Vector3i = Vector3i.ZERO
var _started: bool = false
var _ready: bool = false
var _ended: bool = false
var _error: StringName = &""


static func scratch_bytes(box_count: int) -> int:
	"""Caller-owned box images and native overhead must coexist separately in the actual cold lease."""
	return 8 * box_count + CONTROL_BYTES if box_count > 0 and box_count <= Space.MAX_REGIONS else 0


func configure(boxes: PackedInt32Array, domain: Space.Domain, checks: int, cube_limit: int) -> StringName:
	"""Validate complete borrowed input and rank before allocating the one variable interval bank."""
	if _started:
		return REFUSE_CLOSED
	_started = true
	@warning_ignore("integer_division") _capacity = boxes.size() / BOX_FIELDS
	if boxes.is_empty() or boxes.size() % BOX_FIELDS != 0 or _capacity > Space.MAX_REGIONS \
			or domain == null or checks < 1 or checks > Space.MAX_CHECKS \
			or cube_limit < 0 or cube_limit > Space.MAX_CHECKS:
		return _fail(REFUSE_INPUT)
	if cube_limit == 0:
		return _fail(REFUSE_CAPACITY)
	_remaining = checks
	_limit = cube_limit
	var descriptor: Dictionary = domain.descriptor()
	var code: StringName = _domain_refusal(descriptor)
	if code == &"":
		code = _boxes_refusal(boxes, descriptor.bounds_u)
	if code != &"":
		return _fail(code)
	_boxes = boxes
	_intervals.resize(_capacity)
	_ready = true
	return &""


func _domain_refusal(descriptor: Dictionary) -> StringName:
	"""World bounds and exact signed-I64 key rank must agree with the actual Sites Domain."""
	_datum = descriptor.datum_u
	_minimum = descriptor.min_quantum
	_size = descriptor.size_quanta
	if not Space.valid_ref(descriptor.world_ref) or not Space.valid_box(descriptor.bounds_u) \
			or _size.x < 1 or _size.y < 1 or _size.z < 1 or _capacity > descriptor.max_regions:
		return REFUSE_DOMAIN
	if _remaining > descriptor.max_checks:
		return REFUSE_WORK
	var result: IntMath.IntResult = IntMath.IntResult.new()
	if not IntMath.checked_mul_into(_size.x, _size.z, result) \
			or not IntMath.checked_mul_into(result.value, _size.y, result):
		return REFUSE_DOMAIN
	return &""


func _boxes_refusal(boxes: PackedInt32Array, bounds: PackedInt32Array) -> StringName:
	"""Reject each invalid or individually over-capacity box before any variable allocation."""
	for at: int in range(0, boxes.size(), BOX_FIELDS):
		if not _spend(1):
			return _error
		var count: int = 1
		for axis: int in 3:
			var low: int = boxes[at + axis]
			var high: int = boxes[at + axis + 3]
			if low >= high or low < bounds[axis] or high > bounds[axis + 3]:
				return REFUSE_INPUT
			var first: int = _quantum(low, axis)
			var limit: int = _quantum(high - 1, axis) + 1
			if first < 0 or limit > _size[axis]:
				return REFUSE_DOMAIN
			count *= limit - first # Complete domain rank already bounds this product in signed I64.
		if count > _limit:
			return REFUSE_CAPACITY
	return &""


func advance() -> bool:
	"""Emit each intersecting physical cube once in exact Sites Y/Z/X key order."""
	_current_key = -1
	if not _ready or _error != &"" or _ended:
		return false
	while _x >= _x_end:
		if _interval_at < _interval_count:
			_x = _intervals[_interval_at] >> 32
			_x_end = _intervals[_interval_at] & LOW_MASK
			_interval_at += 1
			break
		if not _prepare_band() or _ended:
			return false
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
	"""Jump directly to the next occupied band; empty coordinate distances do not become iteration work."""
	_interval_count = 0
	_interval_at = 0
	var best: Vector2i = Vector2i(_size.y, _size.z)
	for at: int in range(0, _boxes.size(), BOX_FIELDS):
		if not _spend(1):
			return false
		var candidate: Vector2i = _next_box_band(at)
		if candidate.x >= 0 and (candidate.x < best.x or (candidate.x == best.x and candidate.y < best.y)):
			best = candidate
	if best.x == _size.y:
		_ended = true
		return true
	_y = best.x
	_band_z = best.y
	_next_z = _band_z + 1
	return _gather_band() and _sort_intervals() and _merge_intervals()


func _next_box_band(at: int) -> Vector2i:
	"""Find this box's first band at or after the current lexicographic Y/Z cursor."""
	var first_y: int = _quantum(_boxes[at + 1], 1)
	var limit_y: int = _quantum(int(_boxes[at + 4]) - 1, 1) + 1
	var first_z: int = _quantum(_boxes[at + 2], 2)
	var limit_z: int = _quantum(int(_boxes[at + 5]) - 1, 2) + 1
	var next_y: int = maxi(_y, first_y)
	var next_z: int = first_z if next_y > _y else maxi(_next_z, first_z)
	if next_z >= limit_z:
		next_y += 1
		next_z = first_z
	return Vector2i(next_y, next_z) if next_y < limit_y else Vector2i(-1, -1)


func _gather_band() -> bool:
	"""Collect only X intervals whose complete physical Y/Z band intersects the borrowed box."""
	for at: int in range(0, _boxes.size(), BOX_FIELDS):
		if not _spend(1):
			return false
		if _y < _quantum(_boxes[at + 1], 1) or _y > _quantum(int(_boxes[at + 4]) - 1, 1) \
				or _band_z < _quantum(_boxes[at + 2], 2) or _band_z > _quantum(int(_boxes[at + 5]) - 1, 2):
			continue
		var low: int = _quantum(_boxes[at], 0)
		var high: int = _quantum(int(_boxes[at + 3]) - 1, 0) + 1
		_intervals[_interval_count] = (low << 32) | high
		_interval_count += 1
	return true


func _sort_intervals() -> bool:
	"""In-place active-prefix heapsort retains the same bounded interval bank throughout replay."""
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
	"""Every heap descent consumes the same finite cold-work allowance as input and output visits."""
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
	"""Overlap and touching intervals merge without filling an untouched whole-cube gap."""
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


func _quantum(value: int, axis: int) -> int:
	"""Signed floor division preserves the actual offset datum, including negative half-open faces."""
	var delta: int = value - int(_datum[axis])
	@warning_ignore("integer_division") var coordinate: int = delta / Space.QUANTUM_U
	if delta < 0 and delta % Space.QUANTUM_U != 0:
		coordinate -= 1
	return coordinate - int(_minimum[axis])


func current_origin() -> Vector3i:
	"""Absolute complete paid-cube origin; there is no current cube after end or refusal."""
	if _current_key < 0:
		return Vector3i.ZERO
	return Vector3i(int(_datum.x) + (int(_minimum.x) + _current.x) * Space.QUANTUM_U,
		int(_datum.y) + (int(_minimum.y) + _current.y) * Space.QUANTUM_U,
		int(_datum.z) + (int(_minimum.z) + _current.z) * Space.QUANTUM_U)


func current_key() -> int:
	"""Exact physical history rank; -1 is not a valid emitted quantum."""
	return _current_key


func emitted_count() -> int:
	"""A partial stream count is diagnostic and cannot become an accepted physical bill."""
	return _emitted


func remaining_checks() -> int:
	"""The enclosing owner charges observations against this same finite operation allowance."""
	return _remaining


func rewind_prepaid(checks: int) -> StringName:
	"""Replay completed immutable input using only remaining work, with no allocation or new authority."""
	if not _ready or _error != &"" or not _ended or _current_key != -1:
		return REFUSE_CLOSED
	if checks < 1 or checks > _remaining:
		return REFUSE_WORK
	_remaining = checks
	_y = 0
	_next_z = 0
	_interval_count = 0
	_interval_at = 0
	_x = 0
	_x_end = 0
	_emitted = 0
	_current = Vector3i.ZERO
	_ended = false
	return &""


func charge_checks(checks: int) -> StringName:
	"""No consumer receives a separate hidden allowance for actual history or source lookups."""
	if not _ready or _error != &"":
		return _error if _error != &"" else REFUSE_CLOSED
	return &"" if _spend(checks) else _error


func refusal() -> StringName:
	"""A successful empty error at end is distinct from a truncated or unconfigured stream."""
	return _error if _started else REFUSE_CLOSED


func clear() -> void:
	"""Drop both packed lifetimes before releasing the caller's original cold lease."""
	_boxes = PackedInt32Array()
	_intervals = PackedInt64Array()
	_ready = false
	_started = true
	_current_key = -1
	_error = REFUSE_CLOSED


func _spend(checks: int) -> bool:
	"""Refusal never underflows or mints checks; all nested loops terminate under this bound."""
	if checks < 0 or checks > _remaining:
		_fail(REFUSE_WORK)
		return false
	_remaining -= checks
	return true


func _fail(code: StringName) -> StringName:
	"""Only this derived operation is invalidated; no authoritative owner or bill is written."""
	_error = code
	_current_key = -1
	return code
