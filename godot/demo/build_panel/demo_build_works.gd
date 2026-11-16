extends RefCounted
## WHAT CONFIRM ALL ORDERED, AND WHAT IS DUG: the build panel's PROOF OF CONCEPT (decision 1912; Brendan's ruling of
## 2026-10-12: "A simple mole digs", "Free for now", "Place a simple entrance", "Paint rooms + passages"). Demo layer
## only: nothing here is the settlement's, nothing is paid or saved, and slice C3 replaces all of it with the real
## room foreman, excavation and payment.
##
## THE CELLS. Per underground level (1-4), one byte a cell of the planning area: EARTH, ORDERED (confirmed, waiting
## for the mole) or OPEN (dug), and the room type painted there (TYPE_NONE for a way down's landing). On the Surface
## (level 0) the same for MOUND rooms (decision 2002): ORDERED until dug into their hill, then OPEN; how far each is
## heaped, framed and topped is demo_build_mounds.gd's, and the mole's searches never walk them.
## THE WAYS DOWN. Each confirmed way: the level it stands on (0 for an entrance), its north-west cell, its family and
## quarter turns (build_connector_families.gd: decision 2021, every size a placeholder) and whether it still stands
## (a removed one keeps its row, so a trip naming it stays valid). Its lower cells are ordered with it: its landing
## (TYPE_NONE, a way in for the rooms beside it) and a sloped one's run (TYPE_WAY: solid earth it cuts through, walked
## only along itself, never a way in). A hatch lands on the same 2 × 2 cells, as decision 1912's way down did.
## `way_cell` is its top 2 × 2's north-west cell and `landing_of` its foot 2 × 2's, where it is drawn and walked.
##
## THE DIG ORDER (`next_dig`): from where the mole stands, breadth first through open cells and open ways down, the
## nearest ordered cell beside open space (or a landing below an open way down, or the mole's own cell): so rooms
## open outward from the way in, as SET-BUILD-001 §8 wants, by the plainest rule. `path_to` is the same search for a
## resident walking to an open cell. Searches stop at SEARCH_LIMIT cells -- a guard, not a tuning. EVERY ENTRANCE IS
## JOINED TO EVERY OTHER through the surface (the node SURFACE), so the mole reaches cells beyond a second Entrance
## (review H4). Per level, a box around its non-earth cells (`box_of`) keeps scans to what was ordered (review H2).
##
## SLICE C3 (decision 1991; Brendan, P-1990-1 (b) "Keep the mole, build real"): the proof of concept stays the demo's
## digging until slice D2 switches it to the real route, now with the player's crew and Stop. THE CREW: each ordered
## cell carries the number of the Confirm all that ordered it (`crew_of`); the moles of that batch's crew dig only its
## cells (`next_dig`'s `crews`; none given: any cell), up to four at once, each cell claimed by the one mole digging it
## (`claim`), so two never dig one cell. THE STOP (P-1990-5 (a)): `stop_room` puts a room's cells still waiting back
## to earth and returns them (the panel puts them back in the plan); what is dug stays dug.

const LEVELS: int = 5
const EARTH: int = 0
const ORDERED: int = 1
const OPEN: int = 2
const TYPE_NONE: int = 255
## A sloped way's run below its standing level: dug with it, walked only along itself (decision 2021).
const TYPE_WAY: int = 254
const SIDE: int = 2
const SEARCH_LIMIT: int = 65536
## Decision 1991: crew numbers are one byte; 0 means any crew.
const CREWS: int = 256
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The surface, as one node joining every Entrance's landing (a walk through it goes up and over).
const SURFACE: Vector3i = Vector3i(0, -1, -1)
const QUAD: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]
const Families := preload("res://scripts/ui/build_connector_families.gd")

## Bumped by every change; readers redraw when it moves.
var revision: int = 0
var _bounds: Rect2i = Rect2i()
var _state: Array[PackedByteArray] = []
var _type: Array[PackedByteArray] = []
var _way_levels: PackedInt32Array = PackedInt32Array()
var _way_xs: PackedInt32Array = PackedInt32Array()
var _way_zs: PackedInt32Array = PackedInt32Array()
var _way_families: PackedByteArray = PackedByteArray()
var _way_turns: PackedByteArray = PackedByteArray()
var _way_live: PackedByteArray = PackedByteArray()
## Each live way's links, rebuilt when the ways change: cell (level, x, z) -> the cells (or SURFACE) it reaches; and
## which live way owns each cell (level, x, z) it stands on, takes below, cuts as its run, or opens onto as its landing
## (review H4: a run is left only onto its own landing; M: `on_way` reads them, never building sets).
var _links: Dictionary = {}
var _standing_owner: Dictionary = {}
var _lower_owner: Dictionary = {}
var _run_owner: Dictionary = {}
var _foot_owner: Dictionary = {}
var _ordered: int = 0
## Per level: the box around its non-earth cells (an empty Rect2i: none yet).
var _boxes: Array[Rect2i] = []
## Decision 1991: per level, the crew number of each ordered or dug cell (0: any crew); cells waiting per crew; the
## cells being dug now and by whom (cell (level, x, z) -> the digger's key).
var _crew: Array[PackedByteArray] = []
var _crew_waiting: PackedInt32Array = PackedInt32Array()
var _claims: Dictionary = {}
var _ask_crews: PackedByteArray = PackedByteArray()
var _ask_digger: int = -1


func configure(bounds: Rect2i) -> void:
	"""The planning area in cells; everything is earth."""
	_bounds = bounds
	_state.clear()
	_type.clear()
	_crew.clear()
	for level: int in LEVELS:
		var states: PackedByteArray = PackedByteArray()
		var types: PackedByteArray = PackedByteArray()
		var crews: PackedByteArray = PackedByteArray()
		states.resize(bounds.size.x * bounds.size.y)
		types.resize(bounds.size.x * bounds.size.y)
		crews.resize(bounds.size.x * bounds.size.y)
		types.fill(TYPE_NONE)
		_state.append(states)
		_type.append(types)
		_crew.append(crews)
	_crew_waiting.resize(CREWS)
	_crew_waiting.fill(0)
	_claims.clear()
	_way_levels.clear()
	_way_xs.clear()
	_way_zs.clear()
	_way_families.clear()
	_way_turns.clear()
	_way_live.clear()
	_relink()
	_ordered = 0
	_boxes.clear()
	for level: int in LEVELS:
		_boxes.append(Rect2i())
	revision += 1


func state(level: int, cell: Vector2i) -> int:
	"""EARTH, ORDERED or OPEN (EARTH off the area; on the surface, a Mound room's cell or EARTH)."""
	var index: int = _index(level, cell)
	return _state[level][index] if index >= 0 else EARTH


func type_of(level: int, cell: Vector2i) -> int:
	"""The room type painted at `cell` (TYPE_NONE: none, or a way down's landing)."""
	var index: int = _index(level, cell)
	return _type[level][index] if index >= 0 else TYPE_NONE


func order_room(level: int, cells: PackedInt32Array, room_type: int, crew: int = 0) -> bool:
	"""Confirm all ordered a room: its earth cells wait for crew `crew`'s moles (0: any). False when a cell is off the
	area."""
	for at: int in range(0, cells.size(), 2):
		if _index(level, Vector2i(cells[at], cells[at + 1])) < 0:
			return false
	for at: int in range(0, cells.size(), 2):
		_order(level, Vector2i(cells[at], cells[at + 1]), room_type, crew)
	revision += 1
	return true


func order_way_down(level: int, cell: Vector2i, family: int = Families.LADDER_HATCH, turn: int = 0, crew: int = 0) -> bool:
	"""Confirm all ordered a way of `family` turned `turn` on `level` at `cell`: its landing and run below wait for the
	mole. False off the levels or the area."""
	if level < 0 or level >= LEVELS - 1 or not Families.valid(family):
		return false
	var lower: PackedInt32Array = Families.lower_cells(family, turn, cell)
	for at: int in range(0, lower.size(), 2):
		if _index(level + 1, Vector2i(lower[at], lower[at + 1])) < 0:
			return false
	_way_levels.append(level)
	_way_xs.append(cell.x)
	_way_zs.append(cell.y)
	_way_families.append(family)
	_way_turns.append(posmod(turn, 4))
	_way_live.append(1)
	var run: Dictionary = _set_of(Families.run_cells(family, turn, cell))
	for at: int in range(0, lower.size(), 2):
		var at_cell: Vector2i = Vector2i(lower[at], lower[at + 1])
		_order(level + 1, at_cell, TYPE_WAY if run.has(at_cell) else TYPE_NONE, crew)
	_relink()
	revision += 1
	return true


func remove_way_at(level: int, cell: Vector2i) -> bool:
	"""Confirm all removed the way standing on `level` at `cell` (decision 2021, P-D1-6 (a)): its row stops standing;
	its cells still waiting go back to earth, and those dug stay dug, bare (backfill is slice F's). False with none."""
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == level and way_anchor(row) == cell:
			_way_live[row] = 0
			_relink()
			_unorder_way(row)
			revision += 1
			return true
	return false


func _unorder_way(row: int) -> void:
	"""Way `row`'s lower cells: waiting ones back to earth, dug ones bare (no room type) -- but never a cell another
	standing way still takes (review H2)."""
	var lower: PackedInt32Array = Families.lower_cells(_way_families[row], _way_turns[row], way_anchor(row))
	var below: int = _way_levels[row] + 1
	for at: int in range(0, lower.size(), 2):
		var index: int = _index(below, Vector2i(lower[at], lower[at + 1]))
		var type: int = _type[below][index]
		if _lower_owner.has(Vector3i(below, lower[at], lower[at + 1])):
			continue
		if type != TYPE_NONE and type != TYPE_WAY:
			continue
		if _state[below][index] == ORDERED:
			_back_to_earth(below, index, Vector2i(lower[at], lower[at + 1]))
		_type[below][index] = TYPE_NONE


static func _set_of(cells: PackedInt32Array) -> Dictionary:
	"""`cells` (pairs) as a set of Vector2i."""
	var out: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		out[Vector2i(cells[at], cells[at + 1])] = true
	return out


func _order(level: int, cell: Vector2i, room_type: int, crew: int = 0) -> void:
	"""One cell ordered for crew `crew` (a cell already ordered or open keeps its state and crew; the type is kept if
	one was painted)."""
	var index: int = _index(level, cell)
	if _state[level][index] == EARTH:
		_state[level][index] = ORDERED
		_crew[level][index] = crew
		_crew_waiting[crew] += 1 if level > 0 else 0
		_ordered += 1 if level > 0 else 0
		var box: Rect2i = _boxes[level]
		_boxes[level] = Rect2i(cell, Vector2i.ONE) if box.size == Vector2i.ZERO else box.expand(cell).expand(cell + Vector2i.ONE)
	if room_type != TYPE_NONE or _type[level][index] == TYPE_NONE:
		_type[level][index] = room_type


func ways_on(level: int) -> PackedInt32Array:
	"""The north-west cells of the confirmed ways down standing on `level` (pairs): the batch's reader (decision
	2002)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == level:
			out.append(_way_xs[row])
			out.append(_way_zs[row])
	return out


func hatches_on(level: int) -> PackedInt32Array:
	"""The north-west cells of the confirmed hatches standing on `level` (pairs): what a Mound's cutaway draws as a
	hatch (decision 2002's E15; decision 2021: other families draw themselves)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == level and _way_families[row] == Families.LADDER_HATCH:
			out.append_array(PackedInt32Array([_way_xs[row], _way_zs[row]]))
	return out


func shapes_on(level: int) -> PackedInt32Array:
	"""The confirmed ways standing on `level` as (x, z, family, turn) quads: the batch's shape reader (decision
	2021)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == level:
			out.append_array(PackedInt32Array([_way_xs[row], _way_zs[row], _way_families[row], _way_turns[row]]))
	return out


func landings_on(level: int) -> PackedInt32Array:
	"""The cells confirmed ways land on, on `level` (pairs): the batch's landings reader (decision 2021: confirmed ways
	count, built or waiting, P-D1-7 (a))."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] + 1 == level:
			out.append_array(Families.landing_cells(_way_families[row], _way_turns[row], way_anchor(row)))
	return out


func room_type_at(level: int, cell: Vector2i) -> int:
	"""The room type ordered or dug at `cell` (-1: earth, a landing or a run): the batch's type reader."""
	if state(level, cell) == EARTH:
		return -1
	var type: int = type_of(level, cell)
	return -1 if type == TYPE_NONE or type == TYPE_WAY else type


func open_cell(level: int, cell: Vector2i) -> bool:
	"""The mole dug `cell`: ORDERED becomes OPEN. False when it was not ordered."""
	var index: int = _index(level, cell)
	if index < 0 or _state[level][index] != ORDERED:
		return false
	_state[level][index] = OPEN
	_ordered -= 1 if level > 0 else 0
	_crew_waiting[_crew[level][index]] -= 1 if level > 0 else 0
	_claims.erase(Vector3i(level, cell.x, cell.y))
	revision += 1
	return true


func _back_to_earth(level: int, index: int, cell: Vector2i) -> void:
	"""A cell still waiting goes back to earth: not ordered, no crew, no claim."""
	_state[level][index] = EARTH
	_ordered -= 1 if level > 0 else 0
	_crew_waiting[_crew[level][index]] -= 1 if level > 0 else 0
	_crew[level][index] = 0
	_claims.erase(Vector3i(level, cell.x, cell.y))


# --- decision 1991: the crew, the claims and the Stop ---------------------------------------------------------------

func crew_of(level: int, cell: Vector2i) -> int:
	"""The crew number an ordered or dug cell was ordered for (0: any, or earth)."""
	var index: int = _index(level, cell)
	return _crew[level][index] if index >= 0 else 0


func waiting_for(crew: int) -> int:
	"""Cells below the surface still waiting for crew `crew`."""
	return _crew_waiting[crew] if crew >= 0 and crew < CREWS else 0


func claim(cell: Vector3i, digger: int) -> bool:
	"""`digger` (a trip's key) takes `cell` to dig; false when another holds it or it is not waiting."""
	if state(cell.x, Vector2i(cell.y, cell.z)) != ORDERED or int(_claims.get(cell, digger)) != digger:
		return false
	_claims[cell] = digger
	return true


func unclaim(cell: Vector3i, digger: int) -> void:
	"""`digger` lets `cell` go (nothing when another holds it)."""
	if int(_claims.get(cell, -1)) == digger:
		_claims.erase(cell)


func claimed_by(cell: Vector3i) -> int:
	"""The digger holding `cell`, or -1."""
	return int(_claims.get(cell, -1))


func room_cells(level: int, cell: Vector2i) -> PackedInt32Array:
	"""The confirmed room at `cell` (4-connected cells of its room type, ordered or dug), as pairs; empty when `cell`
	is no room's (earth, a landing or a way's run)."""
	var type: int = room_type_at(level, cell)
	var out: PackedInt32Array = PackedInt32Array()
	if type < 0:
		return out
	var seen: Dictionary = {cell: true}
	var queue: Array[Vector2i] = [cell]
	var head: int = 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		out.append_array(PackedInt32Array([at.x, at.y]))
		for side: Vector2i in SIDES:
			var next: Vector2i = at + side
			if not seen.has(next) and room_type_at(level, next) == type:
				seen[next] = true
				queue.append(next)
	return out


func stop_room(level: int, cell: Vector2i) -> PackedInt32Array:
	"""P-1990-5 (a): the room at `cell` stops being dug. Its cells still waiting go back to earth and are returned (the
	panel puts them back in the plan); its dug cells stay dug. Empty when nothing of it was waiting."""
	var cells: PackedInt32Array = room_cells(level, cell)
	var back: PackedInt32Array = PackedInt32Array()
	for at: int in range(0, cells.size(), 2):
		var here: Vector2i = Vector2i(cells[at], cells[at + 1])
		var index: int = _index(level, here)
		if _state[level][index] != ORDERED:
			continue
		_back_to_earth(level, index, here)
		_type[level][index] = TYPE_NONE
		back.append_array(PackedInt32Array([here.x, here.y]))
	if not back.is_empty():
		revision += 1
	return back


func level_states(level: int) -> PackedByteArray:
	"""A copy of `level`'s cell states row by row over the planning area (`area`), so a rebuild may read it on a worker
	while the mole goes on digging (demo_build_earth.gd, decision 1914; review H1: a packed array kept in an Array is
	shared, not copied on write)."""
	return _state[level].duplicate() if level >= 0 and level < _state.size() else PackedByteArray()


func area() -> Rect2i:
	"""The planning area in cells."""
	return _bounds


func box_of(level: int) -> Rect2i:
	"""The box around `level`'s ordered and dug cells (empty with none)."""
	return _boxes[level] if level >= 0 and level < _boxes.size() else Rect2i()


func cells_into(level: int, wanted: int, out: PackedInt32Array) -> void:
	"""Every cell of `level` in state `wanted`, canonical pairs, into `out` (cleared first): a scan of its box only."""
	out.clear()
	var box: Rect2i = box_of(level)
	if level < 0 or level >= LEVELS:
		return
	var states: PackedByteArray = _state[level]
	for z: int in range(box.position.y, box.end.y):
		var row: int = (z - _bounds.position.y) * _bounds.size.x - _bounds.position.x
		for x: int in range(box.position.x, box.end.x):
			if states[row + x] == wanted:
				out.append(x)
				out.append(z)


func waiting() -> int:
	"""How many ordered cells wait for the mole (underground: a Mound's wait for its own builder, decision 2002)."""
	return _ordered


func way_count() -> int:
	"""Confirmed ways' rows, removed ones included (`way_live`)."""
	return _way_levels.size()


func way_row_at(level: int, anchor: Vector2i) -> int:
	"""The standing way on `level` placed at `anchor`, or -1."""
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == level and way_anchor(row) == anchor:
			return row
	return -1


func way_live(row: int) -> bool:
	"""Whether way `row` still stands (not removed)."""
	return row >= 0 and row < _way_live.size() and _way_live[row] == 1


func way_family(row: int) -> int:
	"""Way `row`'s family (build_connector_families.gd)."""
	return _way_families[row]


func way_turn(row: int) -> int:
	"""Way `row`'s quarter turns."""
	return _way_turns[row]


func way_anchor(row: int) -> Vector2i:
	"""Way `row`'s north-west cell, as placed."""
	return Vector2i(_way_xs[row], _way_zs[row])


func way_level(row: int) -> int:
	"""The level way down `row` stands on (0: the Entrance)."""
	return _way_levels[row]


func way_cell(row: int) -> Vector2i:
	"""The north-west cell of way `row`'s top 2 × 2 (a hatch's own cells): where it is drawn going down and where
	residents go in."""
	return Families.top_corner(_way_families[row], _way_turns[row], way_anchor(row))


func entrance() -> int:
	"""The first standing entrance's row, or -1."""
	for row: int in _way_levels.size():
		if way_live(row) and _way_levels[row] == 0:
			return row
	return -1


func on_way(level: int, cell: Vector2i) -> bool:
	"""Whether `cell` on `level` is under a confirmed way down: where one stands (below the surface, or on a Mound room's
	floor: decision 2002) or where one lands (decision 1921: furniture keeps clear of the stairs)."""
	var at: Vector3i = Vector3i(level, cell.x, cell.y)
	if _lower_owner.has(at):
		return true
	return _standing_owner.has(at) and (level > 0 or state(0, cell) != EARTH)


func down_dir(row: int) -> Vector2i:
	"""Which way way `row`'s stairs go down where it stands, seen from above (turn 0: north)."""
	return Families.descent(_way_turns[row])


func rise_dir(row: int) -> Vector2i:
	"""Which way the stairs drawn at way `row`'s foot rise: a hatch's as it goes down (turn 0: north, as decision
	1912's way down), a run's back toward its top."""
	var down: Vector2i = Families.descent(_way_turns[row])
	return -down if Families.sloped(_way_families[row]) else down


func head_cells(row: int) -> Array[Vector2i]:
	"""The two cells just beyond way `row`'s foot 2 × 2 where its drawn stairs rise into the earth (kept square)."""
	var foot: Vector3i = landing_of(row)
	var corner: Vector2i = Vector2i(foot.y, foot.z)
	var rise: Vector2i = rise_dir(row)
	var first: Vector2i = corner + Vector2i(2 if rise.x > 0 else (-1 if rise.x < 0 else 0),
		2 if rise.y > 0 else (-1 if rise.y < 0 else 0))
	var along: Vector2i = Vector2i(0, 1) if rise.x != 0 else Vector2i(1, 0)
	return [first, first + along]


func landing_of(row: int) -> Vector3i:
	"""Where way `row` comes out below: (level below, its foot 2 × 2's north-west cell)."""
	var foot: Vector2i = Families.foot_corner(_way_families[row], _way_turns[row], way_anchor(row))
	return Vector3i(_way_levels[row] + 1, foot.x, foot.y)


func next_dig(from: Vector3i, crews: PackedByteArray = PackedByteArray(), digger: int = -1) -> Dictionary:
	"""The nearest ordered cell the mole can dig from `from` (level, x, z): {target, path} -- the cells it walks
	(ending where it digs from) and the cell it digs -- or {} when none can be reached. Decision 1991: only cells of
	`crews` (empty: any crew) that no other digger holds (`digger`: the asker's key)."""
	_ask_crews = crews
	_ask_digger = digger
	var found: Dictionary = _search(from, {}, true)
	_ask_crews = PackedByteArray()
	_ask_digger = -1
	return found


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
	if digging and _diggable(from):
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
			if digging and _diggable(next):
				return {"target": next, "path": _walk(came, at)}
			if next == SURFACE or state(next.x, Vector2i(next.y, next.z)) == OPEN:
				came[next] = at
				queue.append(next)
	return {}


func _diggable(cell: Vector3i) -> bool:
	"""An ordered cell of one of the asking crew's numbers (any, with none given) that no other digger holds."""
	if cell == SURFACE or state(cell.x, Vector2i(cell.y, cell.z)) != ORDERED:
		return false
	var holder: int = int(_claims.get(cell, _ask_digger))
	return holder == _ask_digger and (_ask_crews.is_empty() or _ask_crews.has(crew_of(cell.x, Vector2i(cell.y, cell.z))))


func _neighbours(at: Vector3i) -> Array[Vector3i]:
	"""The cells beside `at` on its level (a run's cells only along the run and onto its landing), and what a standing
	way links it to: the other end of the way, or the surface from an entrance's landing (every entrance's landing
	from the surface)."""
	var out: Array[Vector3i] = []
	if at != SURFACE:
		for side: Vector2i in SIDES:
			var next: Vector3i = Vector3i(at.x, at.y + side.x, at.z + side.y)
			if _side_step(at, next):
				out.append(next)
	if _links.has(at):
		for linked: Vector3i in _links[at]:
			out.append(linked)
	return out


func _side_step(at: Vector3i, next: Vector3i) -> bool:
	"""Whether a walker may step from `at` to `next` beside it: off the runs; along one run; or between a run and its
	own way's landing (review H4: never sideways out of a run, nor from one run to another)."""
	var mine: int = int(_run_owner.get(at, -1))
	var theirs: int = int(_run_owner.get(next, -1))
	if mine == theirs:
		return true
	if mine >= 0 and theirs >= 0:
		return false
	return int(_foot_owner.get(next if mine >= 0 else at, -2)) == maxi(mine, theirs)


func _relink() -> void:
	"""Every standing way's links: each top 2 × 2 cell (below the Surface) to the foot cell in its place, or the
	surface to an entrance's foot."""
	_links.clear()
	_standing_owner.clear()
	_lower_owner.clear()
	_run_owner.clear()
	_foot_owner.clear()
	for row: int in _way_levels.size():
		if not way_live(row):
			continue
		_own_cells(row)
		var family: int = _way_families[row]
		var turn: int = _way_turns[row]
		var top: int = _way_levels[row]
		var foot: PackedInt32Array = Families.landing_cells(family, turn, way_anchor(row))
		if top == 0:
			for at: int in range(0, foot.size(), 2):
				_link(SURFACE, Vector3i(1, foot[at], foot[at + 1]))
			continue
		var standing: PackedInt32Array = Families.standing_cells(family, turn, way_anchor(row))
		for at: int in range(0, standing.size(), 2):
			var from: Vector2i = Vector2i(standing[at], standing[at + 1])
			var to: Vector2i = Families.paired_landing(family, turn, way_anchor(row), from)
			if to != from or not Families.sloped(family):
				_link(Vector3i(top, from.x, from.y), Vector3i(top + 1, to.x, to.y))


func _own_cells(row: int) -> void:
	"""Record live way `row`'s cells in the owner maps."""
	var family: int = _way_families[row]
	var turn: int = _way_turns[row]
	var anchor: Vector2i = way_anchor(row)
	var top: int = _way_levels[row]
	var sets: Array = [[_standing_owner, Families.standing_cells(family, turn, anchor), top],
		[_lower_owner, Families.lower_cells(family, turn, anchor), top + 1],
		[_run_owner, Families.run_cells(family, turn, anchor), top + 1],
		[_foot_owner, Families.landing_cells(family, turn, anchor), top + 1]]
	for entry: Array in sets:
		var cells: PackedInt32Array = entry[1]
		for at: int in range(0, cells.size(), 2):
			(entry[0] as Dictionary)[Vector3i(int(entry[2]), cells[at], cells[at + 1])] = row


func run_foot(cell: Vector3i) -> Vector3i:
	"""For a cell of a standing way's run, that way's first landing cell (where one walking it comes out); else `cell`
	(the cut-off check's residents on a run: review M)."""
	var row: int = int(_run_owner.get(cell, -1))
	if row < 0:
		return cell
	var foot: PackedInt32Array = Families.landing_cells(_way_families[row], _way_turns[row], way_anchor(row))
	return Vector3i(cell.x, foot[0], foot[1])


func _link(a: Vector3i, b: Vector3i) -> void:
	"""A way between `a` and `b`, both ways."""
	for pair: Array in [[a, b], [b, a]]:
		if not _links.has(pair[0]):
			_links[pair[0]] = []
		(_links[pair[0]] as Array).append(pair[1])


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
	"""The column index of `cell` on `level` (the surface's for its Mound rooms), or -1 off the area."""
	if level < 0 or level >= LEVELS or not _bounds.has_point(cell):
		return -1
	return (cell.y - _bounds.position.y) * _bounds.size.x + cell.x - _bounds.position.x
