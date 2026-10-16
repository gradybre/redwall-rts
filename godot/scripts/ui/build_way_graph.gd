extends RefCounted
## WHAT A REMOVAL WOULD CUT OFF: BUILD-REQ-017's connectivity check (decision 2021; Brendan's ruling P-D1-6 (a),
## "Real check now"). "If removing a connector or room cells would leave any room, occupant, stored lot or reservation
## without another way out, then the system shall refuse the removal and name what would be cut off."
##
## A host describes its space as a graph and asks: the WALKABLE CELLS (level, x, z), joined to their four neighbours
## on the same level; LINKS between two cells, or between a cell and the OUTSIDE (the Surface's open ground), each
## carrying a TAG -- a way down's or a door's -- that a removal takes away; and TARGETS, named things standing on a cell
## (a room's cells, a resident below; a stored lot or reservation when a host has them). `cut_off(removed)` is every
## target reached from the outside with nothing removed and not reached once the links tagged `removed` are gone: so
## something already out of reach never holds a removal back.
##
## COLD: built and searched once per removal judgement, never per frame. A breadth-first search over a Dictionary of
## the cells given (bounded by what the host gives: the proof of concept's ordered and dug cells).

## The outside: the Surface's open ground (never a cell: level -1).
const OUTSIDE: Vector3i = Vector3i(-1, 0, 0)
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## How many names a refusal lists before "and N more".
const NAMES_SHOWN: int = 4
const MORE: String = "%s and %d more"

## Walkable cells: Vector3i -> true.
var _cells: Dictionary = {}
## Links: Vector3i -> Array of [other end, tag] pairs, both ways.
var _links: Dictionary = {}
var _target_at: Array[Vector3i] = []
var _target_name: PackedInt32Array = PackedInt32Array()
var _names: PackedStringArray = PackedStringArray()


func add_cells(level: int, cells: PackedInt32Array) -> void:
	"""Walkable cells on `level` (pairs)."""
	for at: int in range(0, cells.size(), 2):
		_cells[Vector3i(level, cells[at], cells[at + 1])] = true


func add_link(a: Vector3i, b: Vector3i, tag: int) -> void:
	"""A way between `a` and `b` (either may be OUTSIDE), taken away by removing `tag`."""
	_link_one(a, b, tag)
	_link_one(b, a, tag)


func _link_one(from: Vector3i, to: Vector3i, tag: int) -> void:
	"""One direction of a link."""
	if not _links.has(from):
		_links[from] = []
	(_links[from] as Array).append([to, tag])


func add_target(at: Vector3i, name: String) -> void:
	"""Something named `name` standing on cell `at` (names repeat: a room's cells all share its name)."""
	var index: int = _names.find(name)
	if index < 0:
		_names.append(name)
		index = _names.size() - 1
	_target_at.append(at)
	_target_name.append(index)


func reached(removed: PackedInt32Array) -> Dictionary:
	"""Every cell reached from the outside with the links tagged in `removed` gone (Vector3i -> true)."""
	var seen: Dictionary = {OUTSIDE: true}
	var queue: Array[Vector3i] = [OUTSIDE]
	var head: int = 0
	while head < queue.size():
		var at: Vector3i = queue[head]
		head += 1
		for next: Vector3i in _next_of(at, removed):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _next_of(at: Vector3i, removed: PackedInt32Array) -> Array[Vector3i]:
	"""The walkable cells beside `at` and the ends of its links not removed."""
	var out: Array[Vector3i] = []
	if at != OUTSIDE:
		for side: Vector2i in SIDES:
			var beside: Vector3i = Vector3i(at.x, at.y + side.x, at.z + side.y)
			if _cells.has(beside):
				out.append(beside)
	for link: Array in _links.get(at, []):
		var to: Vector3i = link[0]
		if not removed.has(int(link[1])) and (to == OUTSIDE or _cells.has(to)):
			out.append(to)
	return out


func cut_off(removed: PackedInt32Array) -> PackedStringArray:
	"""The names of the targets reached with nothing removed and not reached with `removed` gone, each once, in the
	order they were given."""
	var before: Dictionary = reached(PackedInt32Array())
	var after: Dictionary = reached(removed)
	var lost: PackedByteArray = PackedByteArray()
	lost.resize(_names.size())
	for at: int in _target_at.size():
		if before.has(_target_at[at]) and not after.has(_target_at[at]):
			lost[_target_name[at]] = 1
	var out: PackedStringArray = PackedStringArray()
	for index: int in _names.size():
		if lost[index] == 1:
			out.append(_names[index])
	return out


static func names_text(names: PackedStringArray) -> String:
	"""The names as one phrase for "Would cut off <names>: ...": "Kitchen (level 1), Basil", at most NAMES_SHOWN of
	them, then "and N more"."""
	if names.size() <= NAMES_SHOWN:
		return ", ".join(names)
	return MORE % [", ".join(names.slice(0, NAMES_SHOWN)), names.size() - NAMES_SHOWN]
