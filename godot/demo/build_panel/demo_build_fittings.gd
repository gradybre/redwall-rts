extends RefCounted
## THE FURNITURE CONFIRM ALL ORDERED, AND WHAT IS FITTED: the Furnish tab's PROOF OF CONCEPT (decision 1921; Brendan's
## rulings of 2026-10-13: "A resident fits it" -- after Confirm all a resident walks to the spot and the piece appears
## after a short wait, free, like the rooms). Demo layer only: nothing here is the settlement's, nothing is paid or
## saved (P-1912-4 (a)), and slice E replaces it with ADR 1081's install crews, access tiles and payment.
##
## THE ROWS. Each confirmed piece: its level, north-west anchor, quarter turns and item type (build_furniture.gd's
## geometry), and its state, ORDERED (waiting for a fitter) or FITTED. A piece is ordered only on dug cells (the batch
## judged it so), so it is always reachable from the way in its room was dug from.
## THE FITTER'S WALK (`next_fit`): the nearest cell of a waiting piece -- one of its floor cells, or a floor cell either
## side of a door's or partition's edges -- breadth first through dug cells from where the fitter stands
## (demo_build_works.gd `path_to_any`); a cell two waiting pieces share goes to the lower row. A piece is a handful of
## rows; reads scan them.

const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")

const ORDERED: int = 1
const FITTED: int = 2
## Levels a piece can be ordered on (the underground levels).
const FIRST_LEVEL: int = 1
const LAST_LEVEL: int = 4

## Bumped by every change; readers redraw when it moves.
var revision: int = 0
## Geometry only: its own rows stay empty.
var shapes: Furniture = Furniture.new()
var _levels: PackedInt32Array = PackedInt32Array()
var _xs: PackedInt32Array = PackedInt32Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _turns: PackedInt32Array = PackedInt32Array()
var _items: PackedInt32Array = PackedInt32Array()
var _states: PackedByteArray = PackedByteArray()
var _waiting: int = 0


func order(level: int, anchor: Vector2i, turn: int, item: int) -> bool:
	"""Confirm all ordered a piece: it waits for a fitter. False off the underground levels or for no item."""
	if level < FIRST_LEVEL or level > LAST_LEVEL or not shapes.is_item(item):
		return false
	_levels.append(level)
	_xs.append(anchor.x)
	_zs.append(anchor.y)
	_turns.append(posmod(turn, Furniture.ROTATIONS))
	_items.append(item)
	_states.append(ORDERED)
	_waiting += 1
	revision += 1
	return true


func fit(row: int) -> bool:
	"""A fitter finished row `row`: ORDERED becomes FITTED. False when it was not waiting."""
	if row < 0 or row >= _states.size() or _states[row] != ORDERED:
		return false
	_states[row] = FITTED
	_waiting -= 1
	revision += 1
	return true


func count() -> int:
	"""Confirmed pieces, waiting or fitted."""
	return _levels.size()


func waiting() -> int:
	"""Pieces waiting for a fitter."""
	return _waiting


func level_of(row: int) -> int:
	"""The level row `row` stands on."""
	return _levels[row]


func anchor_of(row: int) -> Vector2i:
	"""Row `row`'s north-west cell (an edge item's cursor cell)."""
	return Vector2i(_xs[row], _zs[row])


func turn_of(row: int) -> int:
	"""Row `row`'s quarter turns, 0-3."""
	return _turns[row]


func item_of(row: int) -> int:
	"""Row `row`'s item type."""
	return _items[row]


func state_of(row: int) -> int:
	"""ORDERED or FITTED."""
	return _states[row]


func cells_of(row: int) -> PackedInt32Array:
	"""Row `row`'s floor cells (empty for an edge item)."""
	return shapes.cells_of(_items[row], _turns[row], anchor_of(row))


func edges_of(row: int) -> Array[Vector3i]:
	"""Row `row`'s cell edges (empty for a floor piece)."""
	return Furniture.edges_of(_turns[row], anchor_of(row)) if shapes.is_edge(_items[row]) else [] as Array[Vector3i]


func occupant(level: int, cell: Vector2i) -> int:
	"""The item type of the confirmed floor piece covering `cell` on `level`, or -1 (build_furniture.gd's host
	reader)."""
	var row: int = row_at(level, cell)
	return _items[row] if row >= 0 else -1


func row_at(level: int, cell: Vector2i) -> int:
	"""The row of the confirmed floor piece covering `cell` on `level`, or -1 (build_furniture.gd's `piece_at`)."""
	for row: int in _levels.size():
		if _levels[row] != level or shapes.is_edge(_items[row]):
			continue
		var size: Vector2i = shapes.size_of(_items[row], _turns[row])
		if Rect2i(anchor_of(row), size).has_point(cell):
			return row
	return -1


func edge_occupant(level: int, edge: Vector3i) -> int:
	"""The item type of the confirmed door or partition on cell edge `edge` on `level`, or -1."""
	for row: int in _levels.size():
		if _levels[row] == level and shapes.is_edge(_items[row]) and edges_of(row).has(edge):
			return _items[row]
	return -1


func fitted_count(item: int) -> int:
	"""How many fitted pieces of `item` there are, on every level."""
	var total: int = 0
	for row: int in _levels.size():
		if _items[row] == item and _states[row] == FITTED:
			total += 1
	return total


func next_fit(works: Works, from: Vector3i) -> Dictionary:
	"""The nearest waiting piece the fitter can reach from `from` (level, x, z): {row, goal, path} -- the cell it fits
	from and the dug cells it walks there -- or {} when none can be reached (or none waits)."""
	var goals: Dictionary = {}
	for row: int in range(_levels.size() - 1, -1, -1):
		if _states[row] == ORDERED:
			for cell: Vector2i in _work_cells(row):
				goals[Vector3i(_levels[row], cell.x, cell.y)] = row
	if goals.is_empty():
		return {}
	if goals.has(from):
		return {"row": goals[from], "goal": from, "path": PackedVector3Array([Vector3(from)])}
	var found: Dictionary = works.path_to_any(from, goals)
	if found.is_empty():
		return {}
	return {"row": goals[found["goal"]], "goal": found["goal"], "path": found["path"]}


func _work_cells(row: int) -> Array[Vector2i]:
	"""Where a fitter may stand to fit row `row`: its floor cells, or the cells either side of its edges."""
	var out: Array[Vector2i] = []
	if not shapes.is_edge(_items[row]):
		var cells: PackedInt32Array = cells_of(row)
		for at: int in range(0, cells.size(), 2):
			out.append(Vector2i(cells[at], cells[at + 1]))
		return out
	for edge: Vector3i in edges_of(row):
		out.append_array(Furniture.edge_sides(edge))
	return out
