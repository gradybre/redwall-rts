extends RefCounted
## THE CREWS OF THE PROOF OF CONCEPT'S CONFIRM ALLS (decision 1991; Brendan's ruling P-1990-4 (a), "Selected moles crew
## it"): the moles selected when Confirm all is pressed, 1 to 4, crew every room and way that batch ordered; with none
## selected, the first free mole digs (decision 1912's rule) and becomes that batch's crew when it is sent. Each batch
## gets a crew number (1-255, demo_build_works.gd stamps it on the cells it ordered); a number is reused only once no
## cell waits for it. Demo layer only, unsaved, like the works it serves; the real route names its crew the same way
## (underground_room_confirm.gd `Painted.crew`).

const MAX_CREW: int = 4
const CREWS: int = 256
const NAMED: String = "Crew: %s"
const MORE_THAN_FOUR: String = "Crew: %s (four at most dig a room)"
const FIRST_FREE: String = "Crew: the first free mole"
const NO_MOLE_HERE: String = "Crew: the first free resident (no mole lives here)"

## crew number -> the cast indices digging for it (empty: not yet sent, the first free mole will be).
var _members: Dictionary = {}
## crew number -> whether the player named it (false: the first free mole).
var _named: Dictionary = {}
var _next: int = 1


func begin(members: PackedInt32Array, waiting: Callable) -> int:
	"""A new crew number for one Confirm all, with its named members (at most MAX_CREW kept; empty: the first free
	mole). `waiting(crew) -> int` says how many cells still wait for a number; one is reused only at zero."""
	forget_finished(waiting)
	var crew: int = _next
	for tries: int in CREWS - 1:
		if not _members.has(crew) and int(waiting.call(crew)) == 0:
			break
		crew = crew % (CREWS - 1) + 1
	_next = crew % (CREWS - 1) + 1
	var kept: PackedInt32Array = members.slice(0, MAX_CREW)
	_members[crew] = kept
	_named[crew] = not kept.is_empty()
	return crew


func forget_finished(waiting: Callable) -> void:
	"""Forget every crew no cell waits for any more."""
	for crew: int in _members.keys():
		if int(waiting.call(crew)) == 0:
			_members.erase(crew)
			_named.erase(crew)


func ids() -> PackedInt32Array:
	"""Every crew number in use, lowest first."""
	var out: PackedInt32Array = PackedInt32Array(_members.keys())
	out.sort()
	return out


func members_of(crew: int) -> PackedInt32Array:
	"""The cast indices of crew `crew` (empty: none sent yet)."""
	return _members.get(crew, PackedInt32Array())


func named(crew: int) -> bool:
	"""Whether the player named crew `crew`."""
	return bool(_named.get(crew, false))


func set_sent(crew: int, member: int) -> void:
	"""The first free mole sent for an unnamed crew becomes its member."""
	if _members.has(crew) and not named(crew):
		_members[crew] = PackedInt32Array([member])


static func first_name(full: String) -> String:
	"""A resident's first name, as the footer and the room card name the crew ("Tuppen" of "Tuppen Clayholm")."""
	return full.get_slice(" ", 0)


static func words(names: PackedStringArray, selected: int, has_mole: bool) -> String:
	"""What the footer says Confirm all will send: the named moles by first name (`selected` how many were selected),
	else the first free mole, else (an art-free village) the first free resident."""
	if not names.is_empty():
		return (MORE_THAN_FOUR if selected > MAX_CREW else NAMED) % ", ".join(names.slice(0, MAX_CREW))
	return FIRST_FREE if has_mole else NO_MOLE_HERE
