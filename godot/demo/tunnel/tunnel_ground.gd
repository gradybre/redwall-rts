extends RefCounted
## What the ground under the demo village is made of. Decision 0196 (live demo). Presentation
## only: it shapes the demo's digging, and nothing here feeds the simulation.
##
## ---------------------------------------------------------------------------------------
## A GRID OF WHOLE-METRE CELLS over the village's bounds, one byte each (sized once): bits 0-1 the
## GROUND type, bit 2 whether the cell is WET. The types' first three ordinals are §4.3's own
## `Soil` domain (catalog.gd SOIL: LOAM=0, CLAY=1, SAND=2); ROCK=3 is a demo addition, not a soil.
##
## THE LAYOUT IS AUTHORED, ITS EDGES SEEDED. A cell takes the type of the first authored patch
## (x, z, radius in u) whose disc holds its centre -- rock pockets first, then clay and sand --
## else loam. Each patch edge is roughened by an integer hash of (cell, SEED) of up to EDGE_WOBBLE_U,
## so the patches read as ground rather than circles, yet every run is identical. A cell is WET when
## the water query says it lies near water (tunnel_water.gd -- the one place the tunnel works learn
## where water is; the village's real water is another branch's, and replaces its demo table).
##
## WHAT THE TYPES DO (all DEMO values -- ECON-003 adopts "no soil type multiplier" for production,
## and this demo departs from it on purpose; see decision 0196):
##   * DIG_PERMILLE: the work a cut quantum takes, per mille of the cited 113 ticks (loam 1000).
##     Rock is cut at 1000 only with a badger helping; a mole alone crawls at ROCK_ALONE_PERMILLE of
##     its rate (tunnel_crew.gd).
##   * SPOIL_MILLI_U: the excavated earth a quantum yields (loam's 2000 is ECON-002's cited value);
##     rock also yields ROCK_STONE_MILLI_U of stone to the demo stores.
##   * WEAK: sand is weak ground -- an unbraced bore through it can partly collapse
##     (tunnel_hazards.gd). WET ground can flood an unbraced bore in rain.
## Allocation: the grid is allocated once in _init(); every query is integer and allocates nothing.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const WaterScript := preload("res://demo/tunnel/tunnel_water.gd")

const LOAM: int = 0
const CLAY: int = 1
const SAND: int = 2
const ROCK: int = 3
const NAMES: Array[String] = ["loam", "clay", "sand", "rock"]
const TYPE_MASK: int = 3
const WET_BIT: int = 4

const DIG_PERMILLE: Array[int] = [1000, 1300, 800, 1000]
const SPOIL_MILLI_U: Array[int] = [2000, 2400, 1800, 1200]
const ROCK_STONE_MILLI_U: int = 800
const ROCK_ALONE_PERMILLE: int = 250

const CELL_U: int = Rules.QUANTUM_U
const SEED: int = 1964
const EDGE_WOBBLE_U: int = 320
## Authored patches (x, z, radius) in u, by type. Rock pockets are checked first.
const ROCK_PATCHES: Array[Vector3i] = [Vector3i(5632, 1536, 1536), Vector3i(-5632, -3584, 1330),
	Vector3i(9216, -12288, 1536), Vector3i(-2048, 11264, 1433)]
const CLAY_PATCHES: Array[Vector3i] = [Vector3i(7168, -2048, 4096), Vector3i(-7168, 5120, 3584),
	Vector3i(3072, -16384, 4096), Vector3i(-15360, -10240, 3584)]
const SAND_PATCHES: Array[Vector3i] = [Vector3i(-16384, 10240, 4608), Vector3i(12288, 12288, 3584),
	Vector3i(-3072, 16384, 3072)]

var origin_u: Vector2i = Vector2i.ZERO
var columns: int = 0
var rows: int = 0
## One byte per cell, row-major from origin_u (see the header).
var cells: PackedByteArray = PackedByteArray()

var _water: WaterScript = null


func _init(bounds_u: Rect2i = Rect2i(-20480, -20480, 40960, 40960), water: WaterScript = null) -> void:
	"""Lay the ground over these bounds (u), whole cells, once; wet where `water` says (none: the demo
	water table)."""
	_water = water if water != null else WaterScript.new()
	origin_u = bounds_u.position
	columns = Rules.ceil_div(bounds_u.size.x, CELL_U)
	rows = Rules.ceil_div(bounds_u.size.y, CELL_U)
	cells.resize(columns * rows)
	for r in rows:
		for c in columns:
			cells[r * columns + c] = _classify(_centre(c, r))


func _centre(c: int, r: int) -> Vector2i:
	"""The centre of cell (c, r) in u."""
	return Vector2i(origin_u.x + c * CELL_U + CELL_U / 2, origin_u.y + r * CELL_U + CELL_U / 2)


func _classify(at: Vector2i) -> int:
	"""The byte for a cell centred at `at` (see A GRID and THE LAYOUT)."""
	var kind := LOAM
	if _in_any(at, ROCK_PATCHES):
		kind = ROCK
	elif _in_any(at, CLAY_PATCHES):
		kind = CLAY
	elif _in_any(at, SAND_PATCHES):
		kind = SAND
	return kind | (WET_BIT if _water.near_water(at.x, at.y) else 0)


static func wobble_u(at: Vector2i) -> int:
	"""A seeded integer edge roughness in [-EDGE_WOBBLE_U, EDGE_WOBBLE_U] for the point `at`."""
	var h := ((at.x * 73856093) ^ (at.y * 19349663) ^ (SEED * 83492791)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return posmod(h, 2 * EDGE_WOBBLE_U + 1) - EDGE_WOBBLE_U


static func _in_any(at: Vector2i, patches: Array[Vector3i]) -> bool:
	"""Whether `at` lies inside any patch's roughened disc."""
	for patch in patches:
		var reach := patch.z + wobble_u(at)
		var dx := at.x - patch.x
		var dz := at.y - patch.y
		if dx * dx + dz * dz < reach * reach:
			return true
	return false


func cell_of(x_u: int, z_u: int) -> int:
	"""The cell index holding (x_u, z_u), clamped into the grid (a point before the origin truncates
	toward it and clamps to the first cell, as flooring would)."""
	var c := clampi((x_u - origin_u.x) / CELL_U, 0, columns - 1)
	var r := clampi((z_u - origin_u.y) / CELL_U, 0, rows - 1)
	return r * columns + c


func type_at(x_u: int, z_u: int) -> int:
	"""The ground type (LOAM, CLAY, SAND or ROCK) at (x_u, z_u)."""
	return cells[cell_of(x_u, z_u)] & TYPE_MASK


func wet_at(x_u: int, z_u: int) -> bool:
	"""Whether the ground at (x_u, z_u) is wet."""
	return cells[cell_of(x_u, z_u)] & WET_BIT != 0


static func dig_ticks(kind: int) -> int:
	"""Ticks one F1000 worker needs to brace, cut and finish a quantum of this ground (rounded up)."""
	return Rules.ceil_div(Rules.TICKS_PER_QUANTUM * DIG_PERMILLE[kind], Rules.PERMILLE)


static func cut_ticks(kind: int) -> int:
	"""Ticks into a quantum of this ground at which its CUT completes (brace + cut, rounded up)."""
	return Rules.ceil_div((Rules.BRACE_TICKS + Rules.CUT_TICKS) * DIG_PERMILLE[kind], Rules.PERMILLE)


static func spoil_of(kind: int) -> int:
	"""Excavated earth, milli-U, a quantum of this ground yields."""
	return SPOIL_MILLI_U[kind]


static func stone_of(kind: int) -> int:
	"""Stone, milli-U, a quantum of this ground yields to the demo stores (rock only)."""
	return ROCK_STONE_MILLI_U if kind == ROCK else 0
