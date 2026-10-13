extends RefCounted
## THE PENDING WAYS DOWN in the build panel's batch (decision 1912: Brendan's proof-of-concept ruling of 2026-10-12,
## "Place a simple entrance"; a lite slice D). A way down is a 2 × 2-cell item on one level whose LANDING is the same
## 2 × 2 cells on the level below:
##   Entrance   placed on the surface (level 0): lands on underground level 1
##   Way down   placed on a planned or dug passage or room on levels 1-3: lands on the next level
## A drafted way down gives the cells it lands on their way in before it is built (OPEN-07 (a): "paint against a
## planned entrance; the digging waits for it"). No geometry, flight or fixture bill is authored here: the real
## connector families (SET-BUILD-001 §9, OPEN-02/OPEN-10) are slice D's. Presentation-side and never saved, like the
## rest of the batch: packed columns, one row per placement, `live` cleared by Undo and set again by Redo.

const SIDE: int = 2
const ENTRANCE_NAME: String = "Entrance"
const WAY_DOWN_NAME: String = "Way down"
## The deepest level a way down can stand on (it lands on level 4).
const DEEPEST_TOP: int = 3

var _levels: PackedInt32Array = PackedInt32Array()
var _xs: PackedInt32Array = PackedInt32Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _live: PackedByteArray = PackedByteArray()


static func name_of(level: int) -> String:
	"""What a way down standing on `level` is called: the surface's is the Entrance."""
	return ENTRANCE_NAME if level == 0 else WAY_DOWN_NAME


static func footprint(cell: Vector2i) -> PackedInt32Array:
	"""The 2 × 2 cells with `cell` as their north-west corner, canonical (row-major)."""
	return PackedInt32Array([cell.x, cell.y, cell.x + 1, cell.y, cell.x, cell.y + 1, cell.x + 1, cell.y + 1])


func add(level: int, cell: Vector2i) -> int:
	"""A live way down on `level` at `cell`; its row."""
	_levels.append(level)
	_xs.append(cell.x)
	_zs.append(cell.y)
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
	"""Pending ways down."""
	return _live.count(1)


func level_of(row: int) -> int:
	"""The level row `row` stands on."""
	return _levels[row]


func cell_of(row: int) -> Vector2i:
	"""Row `row`'s north-west cell."""
	return Vector2i(_xs[row], _zs[row])


func landings(level: int) -> PackedInt32Array:
	"""The cells every pending way down lands on, on `level` (pairs; empty for the surface)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _levels.size():
		if _live[row] == 1 and _levels[row] + 1 == level:
			out.append_array(footprint(cell_of(row)))
	return out


func clashes(level: int, cell: Vector2i) -> int:
	"""The first pending way down on `level` whose cells overlap a way down at `cell` there; -1 when none."""
	var mine: Rect2i = Rect2i(cell, Vector2i(SIDE, SIDE))
	for row: int in _levels.size():
		if _live[row] == 1 and _levels[row] == level \
				and mine.intersects(Rect2i(cell_of(row), Vector2i(SIDE, SIDE))):
			return row
	return -1


func clear() -> void:
	"""Every row dropped (Discard all)."""
	_levels.clear()
	_xs.clear()
	_zs.clear()
	_live.clear()
