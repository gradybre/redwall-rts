extends RefCounted
## ADR1205: a bounded record of the traversal volumes that each Space publication changed.
## SpaceOwner feeds it from the one bank swap every publication path shares, by comparing the
## exact traversal image of each region slot before and after. WorldRoutes may carry a route
## certificate forward only when its sweeps meet none of the volumes changed since the
## certificate's own geometry revision. Anything the journal cannot vouch for is rechecked in full.
## Derived and unsaved: a load or an out-of-sequence revision empties it and raises the floor.
## ADR1207: a second instance keeps the *full* view (every present row, Room reservation markers
## included), which is the image a World preparation proves Locations against.

const Space := preload("res://scripts/core/room_space.gd")
const CAPACITY: int = 256
const STAGED_STRIDE: int = 7 # Six box words, then the effective traversal role.
const REVISION_FIELD: int = 17
const CLAIM_NONE: int = 0
const CLAIM_ROOM: int = 2

## Ring of changed sides, oldest at `_head`: the revision that changed it, the effective traversal
## role the side has in its own image (any claim reads as OBSTACLE) and its half-open box.
var _revisions: PackedInt64Array = PackedInt64Array()
var _roles: PackedByteArray = PackedByteArray()
var _boxes: PackedInt32Array = PackedInt32Array()
var _box: PackedInt32Array = PackedInt32Array()
var _full: bool = false
var _head: int = 0
var _count: int = 0
## Every change made by a revision above the floor is still in the ring.
var _floor: int = 0


func allocate(full: bool = false) -> void:
	"""Fixed ring and one scratch box; nothing grows after configuration. `full` selects the full-image view."""
	_full = full
	_revisions.resize(CAPACITY)
	_roles.resize(CAPACITY)
	_boxes.resize(6 * CAPACITY)
	_box.resize(6)


func reset(revision: int) -> void:
	"""Forget all history: only a certificate proved at `revision` or later may be carried again."""
	_head = 0
	_count = 0
	_floor = revision
	_revisions.fill(0)
	_roles.fill(0)
	_boxes.fill(0)


func floor_revision() -> int:
	"""The oldest certificate geometry revision whose later changes are all retained."""
	return _floor


func entry_count() -> int:
	"""Retained changed sides."""
	return _count


func count_after(since: int) -> int:
	"""Retained changes made after `since`: the work one `clean` query does."""
	var count: int = 0
	for index: int in _count:
		count += 1 if _revisions[(_head + index) % CAPACITY] > since else 0
	return count


func clean(envelope: PackedInt32Array, since: int, inert_role: int) -> bool:
	"""True only when every change after `since` is retained and none but `inert_role` sides meets the envelope."""
	if since < _floor or _revisions.size() != CAPACITY:
		return false
	for index: int in _count:
		var slot: int = (_head + index) % CAPACITY
		if _revisions[slot] <= since or _roles[slot] == inert_role:
			continue
		for axis: int in 6:
			_box[axis] = _boxes[slot * 6 + axis]
		if Space.overlaps(envelope, _box):
			return false
	return true


func _push(revision: int, role: int, box: PackedInt32Array) -> void:
	"""Append one change; a full ring evicts its oldest entry and raises the floor to that entry's revision."""
	if _count == CAPACITY:
		_floor = maxi(_floor, _revisions[_head])
		_head = (_head + 1) % CAPACITY
		_count -= 1
	var slot: int = (_head + _count) % CAPACITY
	_revisions[slot] = revision
	_roles[slot] = role
	for axis: int in 6:
		_boxes[slot * 6 + axis] = box[axis]
	_count += 1


static func record(owner: RefCounted) -> void:
	"""Called before the live/stage swap: journal both views (ADR1205 traversal, ADR1207 full) of the change."""
	_record_into(owner, owner._journal)
	_record_into(owner, owner._location_journal)


static func _record_into(owner: RefCounted, journal: RefCounted) -> void:
	"""Journal every slot whose row in this journal's view differs between the two banks."""
	if journal == null or journal._revisions.size() != CAPACITY:
		return
	var base: int = owner._header[REVISION_FIELD]
	var target: int = owner._s_header[REVISION_FIELD]
	if target != base + 1:
		journal.reset(target + 1 if target == base else target)
		return
	for row: int in owner._region_capacity:
		if not _row_changed(owner, row, journal._full):
			continue
		_push_side(journal, owner, row, false, target)
		_push_side(journal, owner, row, true, target)


static func _push_side(journal: RefCounted, owner: RefCounted, row: int, staged: bool, target: int) -> void:
	"""Journal one bank's side of a changed slot when that side is visible in the journal's view."""
	if _visible(owner, row, staged, journal._full):
		_box_into(owner, row, staged, journal._box)
		journal._push(target, _role(owner, row, staged), journal._box)


static func staged_clean(owner: RefCounted, envelope: PackedInt32Array, inert_role: int) -> bool:
	"""ADR1207: no full-view side of a sealed stage's changed rows but `inert_role` meets the envelope.
	Reads SpaceOwner's own changed-row index, which every staged region edit marks."""
	for index: int in owner._changed_count:
		var row: int = owner._changed_rows[index]
		if _row_changed(owner, row, true) and (_side_meets(owner, row, false, envelope, inert_role) \
				or _side_meets(owner, row, true, envelope, inert_role)):
			return false
	return true


static func _side_meets(owner: RefCounted, row: int, staged: bool, envelope: PackedInt32Array, inert_role: int) -> bool:
	"""One full-view side of a changed slot that is present, not inert, and overlaps the envelope."""
	return _visible(owner, row, staged, true) and _role(owner, row, staged) != inert_role \
		and side_overlaps(owner, row, staged, envelope)


static func side_overlaps(owner: RefCounted, row: int, staged: bool, box: PackedInt32Array) -> bool:
	"""Half-open overlap of one bank's slot box with `box`, without copying the slot."""
	if staged:
		return owner._s_r_lo_x[row] < box[3] and box[0] < owner._s_r_hi_x[row] \
			and owner._s_r_lo_y[row] < box[4] and box[1] < owner._s_r_hi_y[row] \
			and owner._s_r_lo_z[row] < box[5] and box[2] < owner._s_r_hi_z[row]
	return owner._r_lo_x[row] < box[3] and box[0] < owner._r_hi_x[row] \
		and owner._r_lo_y[row] < box[4] and box[1] < owner._r_hi_y[row] \
		and owner._r_lo_z[row] < box[5] and box[2] < owner._r_hi_z[row]


static func staged_changes_into(owner: RefCounted, out: PackedInt32Array, limit: int) -> int:
	"""The same comparison for a sealed, unpublished stage, STAGED_STRIDE words per side; -1 past `limit`."""
	if owner == null or out.size() < STAGED_STRIDE * limit:
		return -1
	var count: int = 0
	for row: int in owner._region_capacity:
		if not _row_changed(owner, row):
			continue
		count = _staged_side(owner, row, false, out, count, limit)
		count = _staged_side(owner, row, true, out, count, limit)
		if count < 0:
			return -1
	return count


static func _staged_side(owner: RefCounted, row: int, staged: bool, out: PackedInt32Array, count: int, limit: int) -> int:
	"""Append one visible side of a changed slot; -1 stays -1 and marks overflow."""
	if count < 0 or not _visible(owner, row, staged):
		return count
	if count >= limit:
		return -1
	_box_into(owner, row, staged, out, count * STAGED_STRIDE)
	out[count * STAGED_STRIDE + 6] = _role(owner, row, staged)
	return count + 1


static func _row_changed(owner: RefCounted, row: int, full: bool = false) -> bool:
	"""Compare exactly what the view's snapshot copies: visibility, effective role and the half-open box."""
	var before: bool = _visible(owner, row, false, full)
	if before != _visible(owner, row, true, full):
		return true
	if not before:
		return false
	return _role(owner, row, false) != _role(owner, row, true) \
		or owner._r_lo_x[row] != owner._s_r_lo_x[row] or owner._r_lo_y[row] != owner._s_r_lo_y[row] \
		or owner._r_lo_z[row] != owner._s_r_lo_z[row] or owner._r_hi_x[row] != owner._s_r_hi_x[row] \
		or owner._r_hi_y[row] != owner._s_r_hi_y[row] or owner._r_hi_z[row] != owner._s_r_hi_z[row]


static func _visible(owner: RefCounted, row: int, staged: bool, full: bool = false) -> bool:
	"""Traversal: present and not a Room's own typed reservation marker. Full: every present row."""
	if full:
		return (owner._s_r_present[row] if staged else owner._r_present[row]) != 0
	if staged:
		return owner._s_r_present[row] != 0 and not (owner._s_r_claim_kind[row] == CLAIM_ROOM \
			and owner._s_r_role[row] == Space.OBSTACLE and owner._s_r_owner_slot[row] == owner._s_r_claim_slot[row] \
			and owner._s_r_owner_generation[row] == owner._s_r_claim_generation[row])
	return owner._r_present[row] != 0 and not (owner._r_claim_kind[row] == CLAIM_ROOM \
		and owner._r_role[row] == Space.OBSTACLE and owner._r_owner_slot[row] == owner._r_claim_slot[row] \
		and owner._r_owner_generation[row] == owner._r_claim_generation[row])


static func _role(owner: RefCounted, row: int, staged: bool) -> int:
	"""Any claim reads as OBSTACLE in the traversal image, whatever the stored role."""
	if staged:
		return Space.OBSTACLE if owner._s_r_claim_kind[row] != CLAIM_NONE else owner._s_r_role[row]
	return Space.OBSTACLE if owner._r_claim_kind[row] != CLAIM_NONE else owner._r_role[row]


static func _box_into(owner: RefCounted, row: int, staged: bool, out: PackedInt32Array, at: int = 0) -> void:
	"""Copy one bank's half-open extent for a slot."""
	if staged:
		out[at] = owner._s_r_lo_x[row]; out[at + 1] = owner._s_r_lo_y[row]; out[at + 2] = owner._s_r_lo_z[row]
		out[at + 3] = owner._s_r_hi_x[row]; out[at + 4] = owner._s_r_hi_y[row]; out[at + 5] = owner._s_r_hi_z[row]
		return
	out[at] = owner._r_lo_x[row]; out[at + 1] = owner._r_lo_y[row]; out[at + 2] = owner._r_lo_z[row]
	out[at + 3] = owner._r_hi_x[row]; out[at + 4] = owner._r_hi_y[row]; out[at + 5] = owner._r_hi_z[row]
