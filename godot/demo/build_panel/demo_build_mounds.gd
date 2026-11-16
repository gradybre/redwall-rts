extends RefCounted
## THE MOUNDS CONFIRM ALL ORDERED, AND HOW FAR EACH IS BUILT (decision 2002, the proof of concept of decision 2001;
## Brendan's P-2001-11 (a): in the demo, free, drawn over unchanged ground, unsaved, like decision 1912's). Demo layer
## only: nothing here is the settlement's, nothing is paid or saved, and MOUND-REAL replaces it.
##
## THE CELLS. Per cell of the planning area on the Surface, its STAGE in the ruled build order heap → dig → frame → top
## (BUILD-MOUND-007; P-2001-14 (a): the whole hill heaped first): ORDERED (waiting for its heap), HEAPED, DUG (open:
## the works' level 0 reads OPEN), FRAMED (its braces drawn as timber ribs), TOPPED (cover topped up and turfed). The
## room type is the works' (demo_build_works.gd level 0).
## THE DOORS AND WINDOWS. Each confirmed one: its first cell, side, kind and colour (build_mound.gd), ORDERED until a
## resident fits it, then FITTED; EARLY when it came with its rooms, whose yard is then never heaped (P-2001-5 (a));
## one added to a finished hill has its yard dug when it is fitted (P-2001-13 item 2).
## A MOUND is its rooms joined cell to cell (build_mound.gd `components`). THE JOBS (`next_job`): the first Mound, in the
## order of its first cell, that has a door and work left gets the next: heap its ordered cells, nearest the door
## first; once all are heaped, dig breadth first from the door through dug cells, framing each cell as soon as it is
## open (P-2001-14 (a): its braces drawn as ribs); then top, nearest the door first; then fit its doors and windows,
## then the furniture confirmed on its floor (demo_build_mound_jobs.gd). A Mound with no door has no way
## in, and waits. Searches stay inside the planning area's box round the Mound cells.

const Mound := preload("res://scripts/ui/build_mound.gd")
const Fittings := preload("res://demo/build_panel/demo_build_fittings.gd")

const NONE: int = 0
const ORDERED: int = 1
const HEAPED: int = 2
const DUG: int = 3
const FRAMED: int = 4
const TOPPED: int = 5
const STAGES: int = 6
const EDGE_ORDERED: int = 1
const EDGE_FITTED: int = 2
const JOB_HEAP: int = 0
const JOB_DIG: int = 1
const JOB_FRAME: int = 2
const JOB_TOP: int = 3
const JOB_FIT_EDGE: int = 4
const JOB_FIT_PIECE: int = 5
## What each job does to a cell (its stage once done; -1 for a fitting).
const JOB_STAGE: Array[int] = [HEAPED, DUG, FRAMED, TOPPED, -1, -1]
const JOB_WORDS: Array[String] = ["Heaping the hill", "Digging", "Framing", "Topping and turfing", "Fitting the %s",
	"Fitting furniture"]
## A job done from inside the hill (the resident goes in at the door) or outside it (at the door's yard).
const JOB_INSIDE: Array[bool] = [false, true, true, false, false, true]

## Bumped by every change; readers redraw when it moves.
var revision: int = 0
var _bounds: Rect2i = Rect2i()
var _stage: PackedByteArray = PackedByteArray()
var _box: Rect2i = Rect2i()
var _counts: PackedInt32Array = PackedInt32Array()
var _ex: PackedInt32Array = PackedInt32Array()
var _ez: PackedInt32Array = PackedInt32Array()
var _eside: PackedByteArray = PackedByteArray()
var _ekind: PackedByteArray = PackedByteArray()
var _ecolour: PackedByteArray = PackedByteArray()
var _estate: PackedByteArray = PackedByteArray()
var _eearly: PackedByteArray = PackedByteArray()
var _groups: Array[PackedInt32Array] = []
var _groups_at: int = -1


func configure(bounds: Rect2i) -> void:
	"""The planning area in cells; no Mound yet."""
	_bounds = bounds
	_stage.resize(bounds.size.x * bounds.size.y)
	_stage.fill(NONE)
	_box = Rect2i()
	_counts.resize(STAGES)
	_counts.fill(0)
	_clear_edges()
	revision += 1


func _clear_edges() -> void:
	"""Every door and window row dropped."""
	_ex.resize(0)
	_ez.resize(0)
	_eside.resize(0)
	_ekind.resize(0)
	_ecolour.resize(0)
	_estate.resize(0)
	_eearly.resize(0)


func _index(cell: Vector2i) -> int:
	"""`cell`'s index in the stage column, or -1 off the planning area."""
	if not _bounds.has_point(cell):
		return -1
	return (cell.y - _bounds.position.y) * _bounds.size.x + cell.x - _bounds.position.x


func stage_of(cell: Vector2i) -> int:
	"""`cell`'s stage (NONE off the area or in no Mound)."""
	var index: int = _index(cell)
	return _stage[index] if index >= 0 else NONE


func is_open(cell: Vector2i) -> bool:
	"""Whether `cell` is dug (DUG, FRAMED or TOPPED): walked through, furnished."""
	return stage_of(cell) >= DUG


func count(stage: int) -> int:
	"""How many cells are at `stage`."""
	return _counts[stage] if stage >= 0 and stage < STAGES else 0


func box() -> Rect2i:
	"""The box round every Mound cell (empty with none)."""
	return _box


func order_cells(cells: PackedInt32Array) -> bool:
	"""Confirm all ordered a Mound room: its cells wait for their heap. False when a cell is off the area (nothing
	changes)."""
	for at: int in range(0, cells.size(), 2):
		if _index(Vector2i(cells[at], cells[at + 1])) < 0:
			return false
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		if stage_of(cell) == NONE:
			_set_stage(cell, ORDERED)
			_box = Rect2i(cell, Vector2i.ONE) if _box.size == Vector2i.ZERO else _box.expand(cell).expand(cell + Vector2i.ONE)
	revision += 1
	return true


func advance(cell: Vector2i, stage: int) -> bool:
	"""A resident took `cell` one stage on, to `stage`. False unless `cell` stood at the stage just before it."""
	if stage <= ORDERED or stage >= STAGES or stage_of(cell) != stage - 1:
		return false
	_set_stage(cell, stage)
	revision += 1
	return true


func _set_stage(cell: Vector2i, stage: int) -> void:
	"""`cell`'s stage now `stage`, the counts kept."""
	var index: int = _index(cell)
	_counts[_stage[index]] -= 1 if _stage[index] != NONE else 0
	_stage[index] = stage
	_counts[stage] += 1


func cells_into(least: int, out: PackedInt32Array) -> void:
	"""Every Mound cell at `least` or further on (pairs, row by row), into `out` (cleared first)."""
	out.clear()
	for z: int in range(_box.position.y, _box.end.y):
		for x: int in range(_box.position.x, _box.end.x):
			if stage_of(Vector2i(x, z)) >= maxi(least, ORDERED):
				out.append(x)
				out.append(z)


func all_cells() -> PackedInt32Array:
	"""Every confirmed Mound room cell (pairs): the batch's reader."""
	var out: PackedInt32Array = PackedInt32Array()
	cells_into(ORDERED, out)
	return out


func groups() -> Array[PackedInt32Array]:
	"""The Mounds: their rooms joined cell to cell, in the order of their first cells (worked out once a revision)."""
	if _groups_at != revision:
		_groups_at = revision
		_groups = Mound.components(all_cells())
	return _groups


func group_of(cell: Vector2i) -> int:
	"""The Mound `cell` belongs to (its index in `groups`), or -1."""
	var all: Array[PackedInt32Array] = groups()
	for k: int in all.size():
		for at: int in range(0, all[k].size(), 2):
			if all[k][at] == cell.x and all[k][at + 1] == cell.y:
				return k
	return -1


func least_stage(group: int) -> int:
	"""The least-built stage among Mound `group`'s cells (NONE for no such Mound)."""
	var all: Array[PackedInt32Array] = groups()
	if group < 0 or group >= all.size():
		return NONE
	var least: int = TOPPED
	for at: int in range(0, all[group].size(), 2):
		least = mini(least, stage_of(Vector2i(all[group][at], all[group][at + 1])))
	return least


# --- doors and windows ---------------------------------------------------------------------------------------------

func order_edge(cell: Vector2i, side: int, kind: int, colour: int) -> bool:
	"""Confirm all ordered a door or window on a Mound room's outer edge: it waits for a fitter (EARLY when its cells
	are not heaped yet: its yard is never heaped). False off the Mound's cells."""
	for edge: Vector3i in Mound.edges_of(kind, cell, side):
		if stage_of(Mound.cell_of(edge)) == NONE:
			return false
	_ex.append(cell.x)
	_ez.append(cell.y)
	_eside.append(posmod(side, Mound.SIDES))
	_ekind.append(kind)
	_ecolour.append(colour)
	_estate.append(EDGE_ORDERED)
	_eearly.append(1 if stage_of(cell) < HEAPED else 0)
	revision += 1
	return true


func remove_edge(first: Vector3i) -> bool:
	"""Confirm all removed the door or window whose first edge is `first`. False when there is none."""
	var row: int = row_at(first)
	if row < 0:
		return false
	_ex.remove_at(row)
	_ez.remove_at(row)
	_eside.remove_at(row)
	_ekind.remove_at(row)
	_ecolour.remove_at(row)
	_estate.remove_at(row)
	_eearly.remove_at(row)
	revision += 1
	return true


func edge_count() -> int:
	"""Confirmed doors and windows."""
	return _ex.size()


func edge_cell(row: int) -> Vector2i:
	"""Row `row`'s first cell."""
	return Vector2i(_ex[row], _ez[row])


func edge_side(row: int) -> int:
	"""Row `row`'s side."""
	return _eside[row]


func edge_kind(row: int) -> int:
	"""Row `row`'s kind (build_mound.gd KIND_*)."""
	return _ekind[row]


func edge_colour(row: int) -> int:
	"""Row `row`'s door colour."""
	return _ecolour[row]


func edge_fitted(row: int) -> bool:
	"""Whether row `row` has been fitted."""
	return _estate[row] == EDGE_FITTED


func edge_early(row: int) -> bool:
	"""Whether row `row` came with its rooms (its yard is never heaped)."""
	return _eearly[row] == 1


func edges_of(row: int) -> Array[Vector3i]:
	"""Row `row`'s edges."""
	return Mound.edges_of(_ekind[row], edge_cell(row), _eside[row])


func fit_edge(row: int) -> bool:
	"""A resident fitted row `row`. False when it was not waiting."""
	if row < 0 or row >= _estate.size() or _estate[row] != EDGE_ORDERED:
		return false
	_estate[row] = EDGE_FITTED
	revision += 1
	return true


func row_at(edge: Vector3i) -> int:
	"""The row with `edge` among its edges (named from either side), or -1."""
	for row: int in _ex.size():
		for own: Vector3i in edges_of(row):
			if Mound.same_edge(own, edge):
				return row
	return -1


func edge_at(_level: int, edge: Vector3i) -> Vector4i:
	"""The batch's confirmed reader: the door or window on `edge` as (kind, x, z, side of its first edge), or kind -1."""
	var row: int = row_at(edge)
	return Vector4i(_ekind[row], _ex[row], _ez[row], _eside[row]) if row >= 0 else Vector4i(-1, 0, 0, 0)


func doors() -> Array[Vector3i]:
	"""The first edges of every confirmed front door (the batch's way-in reader)."""
	return listed(Mound.KIND_DOOR)


func listed(kind: int) -> Array[Vector3i]:
	"""The first edges of every confirmed door or window of `kind` (the batch's reader)."""
	var out: Array[Vector3i] = []
	for row: int in _ex.size():
		if _ekind[row] == kind:
			out.append(Vector3i(_ex[row], _ez[row], _eside[row]))
	return out


func door_of(group: int) -> int:
	"""The first door row on Mound `group`'s rooms, or -1."""
	for row: int in _ex.size():
		if _ekind[row] == Mound.KIND_DOOR and group_of(edge_cell(row)) == group:
			return row
	return -1


func yards() -> Array[Vector3i]:
	"""The first edges of the doors whose yards are cut: early ones, and fitted ones."""
	var out: Array[Vector3i] = []
	for row: int in _ex.size():
		if _ekind[row] == Mound.KIND_DOOR and (edge_early(row) or edge_fitted(row)):
			out.append(Vector3i(_ex[row], _ez[row], _eside[row]))
	return out
