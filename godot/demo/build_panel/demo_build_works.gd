extends RefCounted
## WHAT CONFIRM ALL ORDERED, AND WHAT IS DUG: the build panel's PROOF OF CONCEPT (decision 1912; Brendan's ruling of
## 2026-10-12: "A simple mole digs", "Free for now", "Place a simple entrance", "Paint rooms + passages"). Demo layer
## only: nothing here is the settlement's, nothing is paid or saved, and slice C3 replaces all of it with the real
## room foreman, excavation and payment.
##
## THE CELLS. Per underground level (1-4), one byte a cell of the planning area: EARTH, ORDERED (confirmed, waiting
## for the mole) or OPEN (dug), and the room type painted there (TYPE_NONE for a way down's landing).
## THE WAYS DOWN. Each confirmed way down: the level it stands on (0 for the Entrance) and its north-west cell; it
## lands on the same 2 × 2 cells one level down. Those landing cells are ordered with it.
##
## THE DIG ORDER (`next_dig`): from where the mole stands, breadth first through open cells and open ways down, the
## nearest ordered cell beside open space (or a landing below an open way down, or the mole's own cell): so rooms
## open outward from the way in, as SET-BUILD-001 §8 wants, by the plainest rule. `path_to` is the same search for a
## resident walking to an open cell. Searches stop at SEARCH_LIMIT cells -- a guard, not a tuning. EVERY ENTRANCE IS
## JOINED TO EVERY OTHER through the surface (the node SURFACE), so the mole reaches cells beyond a second Entrance
## (review H4). Per level, a box around its non-earth cells (`box_of`) keeps scans to what was ordered (review H2).

const LEVELS: int = 5
const EARTH: int = 0
const ORDERED: int = 1
const OPEN: int = 2
const TYPE_NONE: int = 255
const SIDE: int = 2
const SEARCH_LIMIT: int = 65536
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The surface, as one node joining every Entrance's landing (a walk through it goes up and over).
const SURFACE: Vector3i = Vector3i(0, -1, -1)
const QUAD: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]

## Bumped by every change; readers redraw when it moves.
var revision: int = 0
var _bounds: Rect2i = Rect2i()
var _state: Array[PackedByteArray] = []
var _type: Array[PackedByteArray] = []
var _way_levels: PackedInt32Array = PackedInt32Array()
var _way_xs: PackedInt32Array = PackedInt32Array()
var _way_zs: PackedInt32Array = PackedInt32Array()
var _ordered: int = 0
## Per level: the box around its non-earth cells (an empty Rect2i: none yet).
var _boxes: Array[Rect2i] = []


func configure(bounds: Rect2i) -> void:
	"""The planning area in cells; everything is earth."""
	_bounds = bounds
	_state.clear()
	_type.clear()
	for level: int in LEVELS:
		var states: PackedByteArray = PackedByteArray()
		var types: PackedByteArray = PackedByteArray()
		if level > 0:
			states.resize(bounds.size.x * bounds.size.y)
			types.resize(bounds.size.x * bounds.size.y)
			types.fill(TYPE_NONE)
		_state.append(states)
		_type.append(types)
	_way_levels.clear()
	_way_xs.clear()
	_way_zs.clear()
	_ordered = 0
	_boxes.clear()
	for level: int in LEVELS:
		_boxes.append(Rect2i())
	revision += 1


func state(level: int, cell: Vector2i) -> int:
	"""EARTH, ORDERED or OPEN (EARTH off the area or on the surface)."""
	var index: int = _index(level, cell)
	return _state[level][index] if index >= 0 else EARTH


func type_of(level: int, cell: Vector2i) -> int:
	"""The room type painted at `cell` (TYPE_NONE: none, or a way down's landing)."""
	var index: int = _index(level, cell)
	return _type[level][index] if index >= 0 else TYPE_NONE


func order_room(level: int, cells: PackedInt32Array, room_type: int) -> bool:
	"""Confirm all ordered a room: its earth cells wait for the mole. False when a cell is off the area."""
	for at: int in range(0, cells.size(), 2):
		if _index(level, Vector2i(cells[at], cells[at + 1])) < 0:
			return false
	for at: int in range(0, cells.size(), 2):
		_order(level, Vector2i(cells[at], cells[at + 1]), room_type)
	revision += 1
	return true


func order_way_down(level: int, cell: Vector2i) -> bool:
	"""Confirm all ordered a way down on `level` at `cell`: it and its landing below wait for the mole."""
	if level < 0 or level >= LEVELS - 1 or _index(level + 1, cell + Vector2i.ONE) < 0 or _index(level + 1, cell) < 0:
		return false
	_way_levels.append(level)
	_way_xs.append(cell.x)
	_way_zs.append(cell.y)
	for offset: Vector2i in QUAD:
		_order(level + 1, cell + offset, TYPE_NONE)
	revision += 1
	return true


func _order(level: int, cell: Vector2i, room_type: int) -> void:
	"""One cell ordered (a cell already ordered or open keeps its state; the type is kept if one was painted)."""
	var index: int = _index(level, cell)
	if _state[level][index] == EARTH:
		_state[level][index] = ORDERED
		_ordered += 1
		var box: Rect2i = _boxes[level]
		_boxes[level] = Rect2i(cell, Vector2i.ONE) if box.size == Vector2i.ZERO else box.expand(cell).expand(cell + Vector2i.ONE)
	if room_type != TYPE_NONE or _type[level][index] == TYPE_NONE:
		_type[level][index] = room_type


func open_cell(level: int, cell: Vector2i) -> bool:
	"""The mole dug `cell`: ORDERED becomes OPEN. False when it was not ordered."""
	var index: int = _index(level, cell)
	if index < 0 or _state[level][index] != ORDERED:
		return false
	_state[level][index] = OPEN
	_ordered -= 1
	revision += 1
	return true


func box_of(level: int) -> Rect2i:
	"""The box around `level`'s ordered and dug cells (empty with none)."""
	return _boxes[level] if level >= 0 and level < _boxes.size() else Rect2i()


func cells_into(level: int, wanted: int, out: PackedInt32Array) -> void:
	"""Every cell of `level` in state `wanted`, canonical pairs, into `out` (cleared first): a scan of its box only."""
	out.clear()
	var box: Rect2i = box_of(level)
	if level <= 0 or level >= LEVELS:
		return
	var states: PackedByteArray = _state[level]
	for z: int in range(box.position.y, box.end.y):
		var row: int = (z - _bounds.position.y) * _bounds.size.x - _bounds.position.x
		for x: int in range(box.position.x, box.end.x):
			if states[row + x] == wanted:
				out.append(x)
				out.append(z)


func waiting() -> int:
	"""How many ordered cells wait for the mole."""
	return _ordered


func way_count() -> int:
	"""Confirmed ways down."""
	return _way_levels.size()


func way_level(row: int) -> int:
	"""The level way down `row` stands on (0: the Entrance)."""
	return _way_levels[row]


func way_cell(row: int) -> Vector2i:
	"""Way down `row`'s north-west cell."""
	return Vector2i(_way_xs[row], _way_zs[row])


func entrance() -> int:
	"""The first confirmed Entrance's row, or -1."""
	return _way_levels.find(0)


func on_way(level: int, cell: Vector2i) -> bool:
	"""Whether `cell` on `level` is under a confirmed way down: where one stands (below the surface) or where one lands
	(decision 1921: furniture keeps clear of the stairs)."""
	for row: int in _way_levels.size():
		var top: int = _way_levels[row]
		if (top == level and level > 0) or top + 1 == level:
			if Rect2i(Vector2i(_way_xs[row], _way_zs[row]), Vector2i(SIDE, SIDE)).has_point(cell):
				return true
	return false


func landing_of(row: int) -> Vector3i:
	"""Where way down `row` lands: (level below, its north-west cell)."""
	return Vector3i(_way_levels[row] + 1, _way_xs[row], _way_zs[row])


func next_dig(from: Vector3i) -> Dictionary:
	"""The nearest ordered cell the mole can dig from `from` (level, x, z): {target, path} -- the cells it walks
	(ending where it digs from) and the cell it digs -- or {} when none can be reached."""
	return _search(from, {}, true)


func path_to(from: Vector3i, goal: Vector3i) -> PackedVector3Array:
	"""The open cells from `from` to `goal` (both included; goal open), or empty when there is no way."""
	var found: Dictionary = _search(from, {goal: true}, false)
	return found.get("path", PackedVector3Array())


func path_to_any(from: Vector3i, goals: Dictionary) -> Dictionary:
	"""The nearest of `goals` (keys: open cells (level, x, z)) from `from`, other than `from` itself: {goal, path} --
	the open cells walked, both ends included -- or {} when none can be reached (decision 1921: a fitter's walk to the
	nearest piece waiting)."""
	var found: Dictionary = _search(from, goals, false)
	if found.is_empty():
		return {}
	var path: PackedVector3Array = found["path"]
	return {"goal": Vector3i(path[path.size() - 1]), "path": path}


func _search(from: Vector3i, goals: Dictionary, digging: bool) -> Dictionary:
	"""Breadth first from `from` through open cells and open ways down: the first ordered cell beside them (digging)
	or the first of `goals` (walking)."""
	if digging and state(from.x, Vector2i(from.y, from.z)) == ORDERED:
		return {"target": from, "path": PackedVector3Array([Vector3(from)])}
	var came: Dictionary = {from: from}
	var queue: Array[Vector3i] = [from]
	var head: int = 0
	while head < queue.size() and head < SEARCH_LIMIT:
		var at: Vector3i = queue[head]
		head += 1
		for next: Vector3i in _neighbours(at):
			if came.has(next):
				continue
			if not digging and goals.has(next):
				came[next] = at
				return {"path": _walk(came, next)}
			if digging and state(next.x, Vector2i(next.y, next.z)) == ORDERED:
				return {"target": next, "path": _walk(came, at)}
			if next == SURFACE or state(next.x, Vector2i(next.y, next.z)) == OPEN:
				came[next] = at
				queue.append(next)
	return {}


func _neighbours(at: Vector3i) -> Array[Vector3i]:
	"""The four cells beside `at` on its level, the other end of a way down it stands on or lands on, and the surface
	from an Entrance's landing (or every Entrance's landing from the surface)."""
	var out: Array[Vector3i] = []
	if at == SURFACE:
		return _entrance_landings()
	for side: Vector2i in SIDES:
		out.append(Vector3i(at.x, at.y + side.x, at.z + side.y))
	for row: int in _way_levels.size():
		var top: Vector3i = Vector3i(_way_levels[row], _way_xs[row], _way_zs[row])
		if not Rect2i(Vector2i(top.y, top.z), Vector2i(SIDE, SIDE)).has_point(Vector2i(at.y, at.z)):
			continue
		if at.x == top.x and (top.x == 0 or state(top.x, Vector2i(at.y, at.z)) == OPEN):
			out.append(Vector3i(top.x + 1, at.y, at.z))
		elif at.x == top.x + 1 and top.x > 0:
			out.append(Vector3i(top.x, at.y, at.z))
		elif at.x == 1 and top.x == 0 and state(1, Vector2i(at.y, at.z)) == OPEN:
			out.append(SURFACE)
	return out


func _entrance_landings() -> Array[Vector3i]:
	"""Every cell an Entrance lands on, on level 1."""
	var out: Array[Vector3i] = []
	for row: int in _way_levels.size():
		if _way_levels[row] == 0:
			for offset: Vector2i in QUAD:
				out.append(Vector3i(1, _way_xs[row] + offset.x, _way_zs[row] + offset.y))
	return out


static func _walk(came: Dictionary, end: Vector3i) -> PackedVector3Array:
	"""The cells from the search's start to `end`, in walking order."""
	var out: PackedVector3Array = PackedVector3Array()
	var at: Vector3i = end
	while true:
		out.append(Vector3(at))
		var back: Vector3i = came[at]
		if back == at:
			break
		at = back
	out.reverse()
	return out


func _index(level: int, cell: Vector2i) -> int:
	"""The column index of `cell` on underground `level`, or -1 (the surface, or off the area)."""
	if level <= 0 or level >= LEVELS or not _bounds.has_point(cell):
		return -1
	return (cell.y - _bounds.position.y) * _bounds.size.x + cell.x - _bounds.position.x
