extends RefCounted
## CONTROL GROUPS for the live demo's residents (decision 0791; UI §5's `group_assign_0..9` Ctrl+0..9, `group_recall_0..9`
## 0..9, `group_center_0..9` "double digit within 300 ms", and §5.2's "Group recall removes dead/departed/transferred
## residents and announces remaining count"). Pure: no nodes, no clock of its own -- the caller passes the real time of a
## key press, so a check can tap twice inside or outside the window.
##
## A group holds residents by CAST INDEX, sorted. The demo's cast index is its persistent identity (a resident is never
## removed or re-slotted while the demo runs), so it stands in for UI §5's "persistent IDs"; a recall still drops any
## index the cast no longer has, as §5.2 asks, and says how many are left. Groups are presentation (GDD §4: "Selection
## flags ... are outside saved gameplay truth"): nothing is saved, and Restart forgets them with the village.

## Ten groups, 0 to 9.
const GROUP_COUNT: int = 10
## UI §5: a second press of the same digit within this long recalls AND centres.
const DOUBLE_TAP_USEC: int = 300000

## Each group's members, sorted cast indices.
var _members: Array[PackedInt32Array] = []
var _last_slot: int = -1
var _last_usec: int = 0


func _init() -> void:
	"""Ten empty groups."""
	for k: int in GROUP_COUNT:
		_members.append(PackedInt32Array())


static func is_slot(slot: int) -> bool:
	"""Whether `slot` names one of the ten groups."""
	return slot >= 0 and slot < GROUP_COUNT


func assign(slot: int, members: PackedInt32Array) -> bool:
	"""Keep these residents as group `slot`, replacing what it held. False (and nothing changed) for an unknown slot or
	no residents: Ctrl+digit with nobody selected leaves the group as it was (decision 0791 PROPOSAL P2)."""
	if not is_slot(slot) or members.is_empty():
		return false
	var kept := members.duplicate()
	kept.sort()
	_members[slot] = kept
	return true


func size_of(slot: int) -> int:
	"""How many residents group `slot` holds (0 for an unknown slot)."""
	return _members[slot].size() if is_slot(slot) else 0


func recall_into(slot: int, cast_size: int, out: PackedInt32Array) -> int:
	"""Group `slot`'s members still in a cast of `cast_size`, into `out` (resized); how many. Members the cast no longer
	has are dropped from the group for good (§5.2)."""
	out.resize(0)
	if not is_slot(slot):
		return 0
	var kept := PackedInt32Array()
	for who: int in _members[slot]:
		if who >= 0 and who < cast_size:
			kept.append(who)
	_members[slot] = kept
	out.append_array(kept)
	return kept.size()


func tap(slot: int, usec: int) -> bool:
	"""A recall key pressed at real time `usec`: true when it is the SECOND press of the same digit within
	DOUBLE_TAP_USEC of the first (recall and centre). A double tap is used up: a third press starts again."""
	var double: bool = slot == _last_slot and usec - _last_usec <= DOUBLE_TAP_USEC and usec >= _last_usec
	_last_slot = -1 if double else slot
	_last_usec = usec
	return double


func slot_holding(members: PackedInt32Array) -> int:
	"""The lowest group holding exactly these residents (in cast order, as the selection reads), or -1."""
	if members.is_empty():
		return -1
	for slot: int in GROUP_COUNT:
		if _members[slot] == members:
			return slot
	return -1
