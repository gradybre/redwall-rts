extends RefCounted
## The notice feed's SNOOZED KINDS: "quiet this kind of notice for N game hours". Decision 0591 (feature #39).
## Presentation only: it is read by the feed (demo_notices.gd) when it decides whether a new entry toasts and
## chimes; a snoozed entry is still KEPT in the history. Nothing in the simulation reads it.
##
## A row is a kind (demo_notices.gd `kind(k)`: the poster's own kind, or the one inferred for it) and the game TICK
## (demo_calendar.gd `tick`, 750 a game hour) it wakes at. MAX_SNOOZES rows, sized once; an empty kind is a free row.
## A row whose tick has passed is asleep no more and is reused; with every row in use, the one waking soonest goes.

const MAX_SNOOZES: int = 16

## Bumped by every snooze or wake (a reader redraws by it).
var revision: int = 0

var _kind: PackedStringArray = PackedStringArray()
var _until: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""Size both columns once."""
	_kind.resize(MAX_SNOOZES)
	_until.resize(MAX_SNOOZES)


func snooze(kind: String, until_tick: int, now_tick: int) -> bool:
	"""Quiet `kind` from game tick `now_tick` until `until_tick` (a later snooze of the same kind replaces its tick).
	Refuses (false) an empty kind or an `until_tick` not after `now_tick`."""
	if kind.is_empty() or until_tick <= now_tick:
		return false
	var row: int = _row_of(kind)
	if row < 0:
		row = _free_row(now_tick)
	_kind[row] = kind
	_until[row] = until_tick
	revision += 1
	return true


func wake(kind: String) -> bool:
	"""End `kind`'s snooze now (false when it was not snoozed)."""
	var row: int = _row_of(kind)
	if row < 0:
		return false
	_kind[row] = ""
	revision += 1
	return true


func wake_all() -> int:
	"""End every snooze; returns how many rows were in use."""
	var woken: int = 0
	for row: int in MAX_SNOOZES:
		if not _kind[row].is_empty():
			_kind[row] = ""
			woken += 1
	if woken > 0:
		revision += 1
	return woken


func is_snoozed(kind: String, now_tick: int) -> bool:
	"""Whether `kind` is quiet at game tick `now_tick`."""
	var row: int = _row_of(kind)
	return row >= 0 and _until[row] > now_tick


func until(kind: String) -> int:
	"""The game tick `kind` wakes at (-1: not snoozed)."""
	var row: int = _row_of(kind)
	return _until[row] if row >= 0 else -1


func count(now_tick: int) -> int:
	"""How many kinds are quiet at `now_tick`."""
	var n: int = 0
	for row: int in MAX_SNOOZES:
		n += 1 if not _kind[row].is_empty() and _until[row] > now_tick else 0
	return n


func kinds_into(now_tick: int, out: PackedStringArray) -> int:
	"""Fill `out` with the kinds quiet at `now_tick`, waking soonest first; returns how many."""
	out.clear()
	for row: int in MAX_SNOOZES:
		if _kind[row].is_empty() or _until[row] <= now_tick:
			continue
		var at: int = out.size()
		while at > 0 and _until[_row_of(out[at - 1])] > _until[row]:
			at -= 1
		out.insert(at, _kind[row])
	return out.size()


func _row_of(kind: String) -> int:
	"""The row holding `kind` (-1: none; an empty kind is never held)."""
	if kind.is_empty():
		return -1
	for row: int in MAX_SNOOZES:
		if _kind[row] == kind:
			return row
	return -1


func _free_row(now_tick: int) -> int:
	"""A free row, else one already awake at `now_tick`, else the row waking soonest."""
	var soonest: int = 0
	for row: int in MAX_SNOOZES:
		if _kind[row].is_empty() or _until[row] <= now_tick:
			return row
		if _until[row] < _until[soonest]:
			soonest = row
	return soonest
