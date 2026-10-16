extends RefCounted
## Decision 1933 (C2.1), ECON-001: what one room builder may occupy. While it stands still (parked, or READY at a
## station between cubes) that is its body, in the pose it stands in. Once it sets off for a cube it is the cube's
## whole footprint: the way there, the station's work and the way back, each leg swept in short pieces. The foreman
## lets a builder set off only when its footprint meets no other builder's, so two builders never wait on each
## other's bodies. Boxes are half-open integer AABBs, six ints each; the row extents are cached once per row.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
## A footprint is claimed in pieces of this length along each leg (a resolution, not a rule).
const CLAIM_STEP_U: int = 256
const UNFILLED: int = 1 << 30
## Decision 1936, P-1936-5 (a): a claim holds at most this many boxes (12,288 B), so ADR 1212 can count it exactly; a
## longer plan is refused. The 16-Site Kitchen's longest is 306.
const MAX_BOXES: int = 512

var _profiles: Profiles = null
var _boxes: PackedInt32Array = PackedInt32Array()
var _body: PackedInt32Array = PackedInt32Array()
var _extents: PackedInt32Array = PackedInt32Array()
var _serial: int = 0
var _overflow: bool = false # A sweep met MAX_BOXES: the claim is incomplete and must be refused.


func configure(profiles: Profiles) -> void:
	"""One cached extent per published row, filled on first use."""
	_profiles = profiles
	_extents.resize(6 * profiles._live.header[1])
	_extents.fill(UNFILLED)
	_body.resize(6)
	_body.fill(0)


func serial() -> int:
	"""Changes whenever the body or the claim changes, so a cached overlap answer is known to be stale."""
	return _serial


func claim() -> PackedInt32Array:
	"""The claimed footprint's boxes (shared, not copied)."""
	return _boxes


func body() -> PackedInt32Array:
	"""The standing body's one box (shared, not copied)."""
	return _body


func clear_claim() -> void:
	"""Drop the claimed footprint before a new cube's is planned."""
	_boxes.clear()
	_overflow = false
	_serial += 1


func overflowed() -> bool:
	"""The last plan needed more than MAX_BOXES boxes (its claim stopped there)."""
	return _overflow


func stand(point: Vector3i, profile: int) -> void:
	"""The body standing still on `point` in `profile`'s pose, written in place (no allocation)."""
	var at: int = _extent_at(profile)
	for axis: int in 3:
		_body[axis] = point[axis] + _extents[at + axis]
		_body[axis + 3] = point[axis] + _extents[at + axis + 3]
	_serial += 1


func sweep(from: Vector3i, to: Vector3i, profile: int) -> void:
	"""Append the row's boxes swept from `from` to `to`, one AABB per CLAIM_STEP_U piece of the leg, so a long or
	diagonal leg does not claim the whole rectangle around it. Past MAX_BOXES nothing is appended and the claim is
	marked overflowed."""
	var at: int = _extent_at(profile)
	var delta: Vector3i = to - from
	@warning_ignore("integer_division") var pieces: int = maxi(1, (maxi(absi(delta.x), absi(delta.z)) + CLAIM_STEP_U - 1) / CLAIM_STEP_U)
	for piece: int in pieces:
		if _boxes.size() >= 6 * MAX_BOXES:
			_overflow = true
			break
		@warning_ignore("integer_division") var a: Vector3i = from + delta * piece / pieces
		@warning_ignore("integer_division") var b: Vector3i = from + delta * (piece + 1) / pieces
		for axis: int in 3: _boxes.append(mini(a[axis], b[axis]) + _extents[at + axis])
		for axis: int in 3: _boxes.append(maxi(a[axis], b[axis]) + _extents[at + axis + 3])
	_serial += 1


func _extent_at(profile: int) -> int:
	"""Offset of the row's cached extent: the union (low xyz, high xyz) of every published box of the row (a contact
	point or patch lies inside the stroke that reaches it, so it adds nothing)."""
	var at: int = 6 * profile
	if _extents[at] != UNFILLED: return at
	var stride: int = _profiles._profile_capacity
	var cap: int = _profiles._box_capacity
	for axis: int in 3:
		_extents[at + axis] = UNFILLED - 1
		_extents[at + axis + 3] = -UNFILLED
	var first: int = _profiles._live.fields[Profiles.F_FIRST_BOX * stride + profile]
	for box: int in range(first, first + _profiles._live.fields[Profiles.F_BOX_COUNT * stride + profile]):
		for axis: int in 3:
			_extents[at + axis] = mini(_extents[at + axis], _profiles._live.boxes[axis * cap + box])
			_extents[at + axis + 3] = maxi(_extents[at + axis + 3], _profiles._live.boxes[(axis + 3) * cap + box])
	return at


static func overlap(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	"""Any half-open box of one list meets any box of the other; the two hulls are compared first."""
	if a.is_empty() or b.is_empty() or not _hulls_meet(a, b): return false
	@warning_ignore("integer_division") var count_a: int = a.size() / 6
	@warning_ignore("integer_division") var count_b: int = b.size() / 6
	for i: int in count_a:
		for j: int in count_b:
			if _meets(a, 6 * i, b, 6 * j): return true
	return false


static func _meets(a: PackedInt32Array, i: int, b: PackedInt32Array, j: int) -> bool:
	"""Two half-open boxes, at offsets i and j, share volume."""
	for axis: int in 3:
		if a[i + axis] >= b[j + axis + 3] or b[j + axis] >= a[i + axis + 3]: return false
	return true


static func _hulls_meet(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	"""The bounding boxes of the two lists share volume (a cheap reject before the pairwise test)."""
	for axis: int in 3:
		if _low(a, axis) >= _high(b, axis) or _low(b, axis) >= _high(a, axis): return false
	return true


static func _low(boxes: PackedInt32Array, axis: int) -> int:
	"""The smallest low face on one axis."""
	var value: int = UNFILLED
	for at: int in range(axis, boxes.size(), 6): value = mini(value, boxes[at])
	return value


static func _high(boxes: PackedInt32Array, axis: int) -> int:
	"""The largest high face on one axis."""
	var value: int = -UNFILLED
	for at: int in range(axis + 3, boxes.size(), 6): value = maxi(value, boxes[at])
	return value
