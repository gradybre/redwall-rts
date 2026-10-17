extends RefCounted
## THE PENDING WAYS DOWN in the build panel's batch (decision 1912's proof of concept, made per family by slice D1:
## decision 2021, Brendan's rulings of 2026-10-16). A row is one connector of a family (build_connector_families.gd:
## Burrow mouth, Hatch with ladder, Stair-head) standing on one level, its north-west cell and its quarter turns; it
## takes its standing cells there and its lower cells on the level below, and opens onto that level at its landing. A
## way placed with "Up" on level N is the same row standing on level N - 1 (P-D1-4 (a)), so there is no direction.
## A row may instead be a REMOVAL of a confirmed way (P-D1-6 (a)): it names that way and takes nothing.
##   on the surface (level 0)   an entrance: it lands on underground level 1
##   on a passage on levels 1-3 a way down to the next level (P-D1-5 (a))
## A drafted way gives the cells it lands on their way in before it is built (OPEN-07 (a): "paint against a planned
## entrance; the digging waits for it"). Presentation-side and never saved, like the rest of the batch: packed columns,
## one row per placement, `live` cleared by Undo and set again by Redo.

const Families := preload("res://scripts/ui/build_connector_families.gd")

const SIDE: int = 2
## The generic names a level's way had in the proof of concept (kept for words that name no family).
const ENTRANCE_NAME: String = "Entrance"
const WAY_DOWN_NAME: String = "Way down"
## The deepest level a way down can stand on (it lands on level 4).
const DEEPEST_TOP: int = 3
## A row placed with no family named is a hatch: the proof of concept's 2 × 2 that lands on the same cells.
const DEFAULT_FAMILY: int = Families.LADDER_HATCH

var _levels: PackedInt32Array = PackedInt32Array()
var _xs: PackedInt32Array = PackedInt32Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _families: PackedByteArray = PackedByteArray()
var _turns: PackedByteArray = PackedByteArray()
var _removals: PackedByteArray = PackedByteArray()
var _live: PackedByteArray = PackedByteArray()


static func name_of(level: int) -> String:
	"""What a way standing on `level` was generically called: the surface's is an Entrance."""
	return ENTRANCE_NAME if level == 0 else WAY_DOWN_NAME


static func footprint(cell: Vector2i) -> PackedInt32Array:
	"""The 2 × 2 cells with `cell` as their north-west corner, canonical (row-major)."""
	return PackedInt32Array([cell.x, cell.y, cell.x + 1, cell.y, cell.x, cell.y + 1, cell.x + 1, cell.y + 1])


func add(level: int, cell: Vector2i, family: int = DEFAULT_FAMILY, turn: int = 0, removal: bool = false) -> int:
	"""A live row: a way of `family` turned `turn` standing on `level` at `cell` (or its removal); its row."""
	_levels.append(level)
	_xs.append(cell.x)
	_zs.append(cell.y)
	_families.append(family)
	_turns.append(posmod(turn, 4))
	_removals.append(1 if removal else 0)
	_live.append(1)
	return _levels.size() - 1


func set_live(row: int, live: bool) -> void:
	"""Row `row` pending (Redo) or not (Undo, or ordered)."""
	_live[row] = 1 if live else 0


func is_live(row: int) -> bool:
	"""Whether row `row` is pending."""
	return row >= 0 and row < _live.size() and _live[row] == 1


func count() -> int:
	"""Rows, live or not."""
	return _levels.size()


func live_count() -> int:
	"""Pending ways and removals."""
	return _live.count(1)


func level_of(row: int) -> int:
	"""The level row `row` stands on."""
	return _levels[row]


func cell_of(row: int) -> Vector2i:
	"""Row `row`'s north-west cell."""
	return Vector2i(_xs[row], _zs[row])


func family_of(row: int) -> int:
	"""Row `row`'s family (build_connector_families.gd)."""
	return _families[row]


func turn_of(row: int) -> int:
	"""Row `row`'s quarter turns."""
	return _turns[row]


func is_removal(row: int) -> bool:
	"""Whether row `row` asks for a confirmed way's removal."""
	return _removals[row] == 1


func name_of_row(row: int) -> String:
	"""Row `row`'s family name ("Hatch with ladder")."""
	return Families.name_of(_families[row])


func standing(row: int) -> PackedInt32Array:
	"""The cells row `row` takes where it stands (pairs)."""
	return Families.standing_cells(_families[row], _turns[row], cell_of(row))


func lower(row: int) -> PackedInt32Array:
	"""The cells row `row` takes on the level below (pairs)."""
	return Families.lower_cells(_families[row], _turns[row], cell_of(row))


func landing(row: int) -> PackedInt32Array:
	"""Where row `row` opens onto the level below (pairs)."""
	return Families.landing_cells(_families[row], _turns[row], cell_of(row))


func _placed(row: int) -> bool:
	"""Whether row `row` is a live placement (not a removal)."""
	return _live[row] == 1 and _removals[row] == 0


func landings(level: int) -> PackedInt32Array:
	"""The cells every pending way lands on, on `level` (pairs; empty for the surface)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _levels.size():
		if _placed(row) and _levels[row] + 1 == level:
			out.append_array(landing(row))
	return out


func removed_landings(level: int) -> PackedInt32Array:
	"""The cells confirmed ways a pending removal takes away land on, on `level` (pairs)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _levels.size():
		if _live[row] == 1 and _removals[row] == 1 and _levels[row] + 1 == level:
			out.append_array(landing(row))
	return out


func taken(level: int) -> PackedInt32Array:
	"""Every cell pending ways take on `level`: where they stand there, and where they come down from the level above
	(pairs; decision 1921: furniture keeps clear of them)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _levels.size():
		if not _placed(row):
			continue
		if _levels[row] == level:
			out.append_array(standing(row))
		elif _levels[row] + 1 == level:
			out.append_array(lower(row))
	return out


func clashes(level: int, cell: Vector2i, own_row: int = -1, family: int = DEFAULT_FAMILY, turn: int = 0) -> int:
	"""The first pending way (not `own_row`) sharing a cell with a way of `family` turned `turn` at `cell` standing on
	`level`: where both stand, where both come down, or where either's run cuts (a run is solid earth only its way may
	take); -1 when none. A way may stand on a hatch's landing (open floor below it)."""
	var mine: Array = taken_sets(level, family, turn, cell)
	for row: int in _levels.size():
		if row != own_row and _placed(row) and meets(mine, taken_sets(_levels[row], _families[row], _turns[row],
				cell_of(row))):
			return row
	return -1


static func taken_sets(level: int, family: int, turn: int, cell: Vector2i) -> Array:
	"""[level, its standing cells, the level below, its lower cells, its run cells] (sets of Vector2i)."""
	return [level, _set_of(Families.standing_cells(family, turn, cell)), level + 1,
		_set_of(Families.lower_cells(family, turn, cell)), _set_of(Families.run_cells(family, turn, cell))]


static func meets(mine: Array, theirs: Array) -> bool:
	"""Whether two ways' cells clash: a cell both stand on, or both come down onto (no two ways share a landing:
	removing one would strip the other's), or one where either's run cuts it."""
	for ours: int in [0, 2]:
		for other: int in [0, 2]:
			if int(mine[ours]) != int(theirs[other]):
				continue
			var a: Dictionary = mine[ours + 1]
			var b: Dictionary = theirs[other + 1]
			for at: Vector2i in a:
				if b.has(at) and (ours == other or (ours == 2 and (mine[4] as Dictionary).has(at)) \
						or (other == 2 and (theirs[4] as Dictionary).has(at))):
					return true
	return false


static func _set_of(cells: PackedInt32Array) -> Dictionary:
	"""`cells` (pairs) as a set of Vector2i."""
	var out: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		out[Vector2i(cells[at], cells[at + 1])] = true
	return out


func removal_row(level: int, cell: Vector2i) -> int:
	"""The live removal row naming the confirmed way standing on `level` at `cell`, or -1."""
	for row: int in _levels.size():
		if _live[row] == 1 and _removals[row] == 1 and _levels[row] == level and cell_of(row) == cell:
			return row
	return -1


func removals_into(out: PackedInt32Array) -> void:
	"""Every live removal's way as (level, x, z) triples into `out` (cleared first)."""
	out.clear()
	for row: int in _levels.size():
		if _live[row] == 1 and _removals[row] == 1:
			out.append_array(PackedInt32Array([_levels[row], _xs[row], _zs[row]]))


func clear() -> void:
	"""Every row dropped (Discard all)."""
	_levels.clear()
	_xs.clear()
	_zs.clear()
	_families.clear()
	_turns.clear()
	_removals.clear()
	_live.clear()
