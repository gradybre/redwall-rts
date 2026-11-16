extends RefCounted
## THE CONNECTOR FAMILIES AS THE BUILD PANEL PLACES THEM (decision 2021; Brendan's rulings of 2026-10-16: P-D1-1 (a),
## P-D1-2 (a) "Use the table, marked"). PLANNING-SIDE PLACEHOLDERS: every size and cost here is a PROPOSED value for
## review, labelled "placeholder" wherever it is shown, and adopted nowhere (SET-BUILD-001 §9 still says "to be
## authored"). The Stair-head's row is decision 2043's M5 flight, by Brendan's ruling P-2043-1 (a) of 2026-10-16
## (replacing 2041's F40, which cannot be built in place with qualified motion; still labelled "placeholder").
## These are cells, not room_connectors.gd Definitions: a Definition needs profile-qualified contacts no placeholder
## may invent (decision 2021 F3).
##
## THE SHAPE. A family is a strip ACROSS cells wide and ALONG cells long, anchored at its bounding box's north-west
## cell, falling DROP_U (one level, SET-BUILD-001 §3) from its TOP end to its FOOT end. Turn 0 descends north (the top
## is the strip's south end, its front access pair south of that); each quarter turn (R) turns the descent clockwise
## seen from above: east, south, west.
##   standing cells   along 0 .. TOP_OPEN-1 on the level it stands on: where its void is open to that level (the
##                    burrow mouth's open cut, a stair's trench in a passage floor, a hatch's whole 2 × 2)
##   lower cells      along LOW_FROM .. ALONG-1 on the level below: where its void reaches that level's clear height
##   landing          the foot: the lower cells' last row (sloped), or all of them (a hatch or spiral)
##   access pairs     one front pair at the top (along -1) and one at the foot (along ALONG; a hatch's or spiral's at
##                    along -1 on the level below), OPEN-02 (a)'s "one front access pair"
## The other cells the strip crosses lie under one quantum of earth between the levels (decision 2021 F7) and belong to
## neither level's grid.
##
## WHERE EACH NUMBER COMES FROM (decision 2021 "The placeholder families"):
##   width 2 cells            the Passage minimum (BUILD-REQ-014), wider than the badger (tunnel_rules.gd wide bore)
##   headroom 3072 u          DEC-039's badger, 2611 u, rounded up to whole quanta (the legacy wide bore's height)
##   RAMP run 13696 u         5120 × 2.5 (decision 0212's 1:2.5) + 896 u for its eased ends (RAMP_FILLET_U)
##   EARTH_TIMBER 2 × 27      decision 2043 §3's M5 flight (P-2043-1 (a)): today's qualified 1 m module five times in
##                            a straight line, joined by natural landings; 27 rows of 1024 u, every row an open slot to
##                            the land, STAIR_ROW_DEPTHS cubes deep (rows 0-1 at 1, module j's five rows at j + 1);
##                            rotation 0 only (decision 2041 P-DF-6 (a))
##   STONE run 6400 u         20 risers of decision 0212's 256 u on its least tread, 320 u
##   LADDER_HATCH 2 × 2       the Mound hatch's 1.96 m frame (demo_build_mound_parts.gd) on GDD's 1-tile = 2 × 2 cells
##   SPIRAL 4 × 4             OPEN-02 (a)'s placeholder itself
##   quanta                   every 1024 u cube the void touches (`count_quanta`), an upper bound: a cube already open
##                            is never charged twice (SET-BUILD-001 §7.2)
##   fixtures                 ADR 1202's L0 (4000 milli wood, 32000 milli-WU), T0 at its own bill (1000, 12000) and ADR
##                            1209 D3's tread at DEC-059's work (1000, 5640): the hatch = L0 + one tread per 1024 u of
##                            drop (the weakest number); the stair = L0 + five T0s + 30 treads (2043 §3); the ramp none;
##                            stone and spiral not proposed

const Connectors := preload("res://scripts/core/room_connectors.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")

const EARTH_TIMBER: int = Connectors.EARTH_TIMBER
const STONE: int = Connectors.STONE
const RAMP: int = Connectors.RAMP
const SPIRAL: int = Connectors.SPIRAL
const LADDER_HATCH: int = Connectors.LADDER_HATCH
const FAMILY_COUNT: int = Connectors.FAMILY_COUNT
## The cards' order (P-D1-1 (a)): the three offered, then the two shown locked.
const CARD_ORDER: Array[int] = [RAMP, LADDER_HATCH, EARTH_TIMBER, STONE, SPIRAL]
## Indexed by family (room_connectors.gd order: earth/timber, stone, ramp, spiral, ladder/hatch).
const NAMES: Array[String] = ["Stair-head", "Stone stairs", "Burrow mouth", "Spiral stair", "Hatch with ladder"]
const OFFERED: Array[bool] = [true, false, true, false, true]
const SLOPED: Array[bool] = [true, true, true, false, false]
const ACROSS: Array[int] = [2, 2, 2, 4, 2]
const ALONG: Array[int] = [27, 7, 14, 4, 2]
const TOP_OPEN: Array[int] = [27, 4, 9, 4, 2]
const LOW_FROM: Array[int] = [7, 1, 2, 0, 0]
## Each sloped family's run in u (0: a vertical family, whose drop is straight down its cells).
const RUN_U: Array[int] = [27648, 6400, 13696, 0, 0]
## At most this many quanta (`count_quanta`, or for the stair 2 × ROW_DEPTHS; test_build_connector_families.gd recounts
## them independently).
const QUANTA: Array[int] = [154, 44, 84, 80, 20]
## Decision 2043 §3: the M5 flight's cubes cut per column, row by row from its top (the land down).
const STAIR_ROW_DEPTHS: Array[int] = [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5]
## The families placed at turn 0 only (P-DF-6 (a): no stair qualified for another heading yet).
const TURN_ZERO_ONLY: Array[bool] = [true, false, false, false, false]
const NO_QUALIFIED_TURN: String = "No qualified stair for this direction yet"
## Fixture parts: how many L0s, T0s at their own bill, and treads at D3's (DEC-059) bill; -1: not proposed.
const FIXTURE_L0: Array[int] = [1, -1, 0, -1, 1]
const FIXTURE_T0: Array[int] = [5, -1, 0, -1, 0]
const FIXTURE_TREADS: Array[int] = [30, -1, 0, -1, 5]
const DROP_U: int = 5120
const QUANTUM_U: int = 1024
const HEADROOM_U: int = 3072
const L0_WOOD_MILLI: int = 4000
const L0_WORK_MWU: int = 32000
const TREAD_WOOD_MILLI: int = 1000
const TREAD_WORK_MWU: int = 5640
const T0_WORK_MWU: int = 12000
## The card's words (P-D1-12 (a)).
const PLACEHOLDER: String = "Placeholder: sizes and costs await review"
const CLIMBERS_ONLY: String = "Climbers only: loads need a stair or ramp"
const NOT_QUALIFIED: String = "Proof of concept: free; not yet a qualified descent"
const LATER: String = "stone and spiral stairs come in a later update"
const PICTURES: Array[String] = ["timber steps going down into the earth", "stone steps going down",
	"a burrow mouth in a mound of earth, its floor sloping down", "a stair winding round a post",
	"a framed hatch with its lid open and a ladder going down"]
## The descent's direction per turn, clockwise seen from above (north, east, south, west).
const DESCENT: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func valid(family: int) -> bool:
	"""Whether `family` is one of the five."""
	return family >= 0 and family < FAMILY_COUNT


static func offered(family: int) -> bool:
	"""Whether the panel lets the player place `family` now (P-D1-1 (a): Burrow mouth, Hatch and Stair-head)."""
	return valid(family) and OFFERED[family]


static func name_of(family: int) -> String:
	"""The family's player-facing name ("" for none)."""
	return NAMES[family] if valid(family) else ""


static func turn_refusal(family: int, turn: int) -> String:
	"""Why `family` cannot be placed turned `turn` ("" when it can): the Stair-head descends toward -Z only (decision
	2041 P-DF-6 (a))."""
	if valid(family) and TURN_ZERO_ONLY[family] and posmod(turn, 4) != 0:
		return NO_QUALIFIED_TURN
	return ""


static func sloped(family: int) -> bool:
	"""Whether `family` falls along a run (a ramp or stairs), not straight down its own cells."""
	return valid(family) and SLOPED[family]


static func box(family: int, turn: int, anchor: Vector2i) -> Rect2i:
	"""The cells the strip covers seen from above, `anchor` its north-west cell."""
	var size: Vector2i = Vector2i(ACROSS[family], ALONG[family])
	return Rect2i(anchor, size if posmod(turn, 4) % 2 == 0 else Vector2i(size.y, size.x))


static func cell_at(family: int, turn: int, anchor: Vector2i, along: int, across: int) -> Vector2i:
	"""The cell `along` the strip from its top end and `across` it, for the family turned `turn` times."""
	var length: int = ALONG[family]
	var width: int = ACROSS[family]
	match posmod(turn, 4):
		1:
			return anchor + Vector2i(along, across)
		2:
			return anchor + Vector2i(width - 1 - across, along)
		3:
			return anchor + Vector2i(length - 1 - along, width - 1 - across)
	return anchor + Vector2i(across, length - 1 - along)


static func _rows(family: int, turn: int, anchor: Vector2i, first: int, last: int) -> PackedInt32Array:
	"""The cells of rows `first` .. `last - 1` along the strip (pairs, canonical: by z, then x)."""
	var box_of: Rect2i = Rect2i()
	for along: int in [first, last - 1]:
		for across: int in [0, ACROSS[family] - 1]:
			var corner: Vector2i = cell_at(family, turn, anchor, along, across)
			box_of = Rect2i(corner, Vector2i.ONE) if box_of.size == Vector2i.ZERO else box_of.expand(corner).expand(
				corner + Vector2i.ONE)
	var out: PackedInt32Array = PackedInt32Array()
	if last <= first:
		return out
	for z: int in range(box_of.position.y, box_of.end.y):
		for x: int in range(box_of.position.x, box_of.end.x):
			out.append_array(PackedInt32Array([x, z]))
	return out


static func standing_cells(family: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""The cells it takes on the level it stands on (pairs)."""
	return _rows(family, turn, anchor, 0, TOP_OPEN[family]) if valid(family) else PackedInt32Array()


static func lower_cells(family: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""The cells it takes on the level below (pairs)."""
	return _rows(family, turn, anchor, LOW_FROM[family], ALONG[family]) if valid(family) else PackedInt32Array()


static func landing_cells(family: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""Its foot on the level below, where it opens onto that level (pairs): a sloped run's last row, else all its
	lower cells."""
	if not valid(family):
		return PackedInt32Array()
	return _rows(family, turn, anchor, ALONG[family] - 1, ALONG[family]) if SLOPED[family] \
		else lower_cells(family, turn, anchor)


static func run_cells(family: int, turn: int, anchor: Vector2i) -> PackedInt32Array:
	"""Its lower cells that are not its landing: solid earth it cuts through, never a way in (pairs)."""
	if not sloped(family):
		return PackedInt32Array()
	return _rows(family, turn, anchor, LOW_FROM[family], ALONG[family] - 1)


static func access_pair(family: int, turn: int, anchor: Vector2i, foot: bool) -> PackedInt32Array:
	"""The front access pair at the top, or at the foot (`foot`), centred across the strip (pairs)."""
	if not valid(family):
		return PackedInt32Array()
	var along: int = ALONG[family] if foot and SLOPED[family] else -1
	@warning_ignore("integer_division") var first: int = (ACROSS[family] - 2) / 2
	var out: PackedInt32Array = PackedInt32Array()
	for across: int in [first, first + 1]:
		var cell: Vector2i = cell_at(family, turn, anchor, along, across)
		out.append_array(PackedInt32Array([cell.x, cell.y]))
	return out


static func top_corner(family: int, turn: int, anchor: Vector2i) -> Vector2i:
	"""The north-west cell of the 2 × 2 at its top end (rows 0-1, the first two cells across): where it is drawn going
	down and where residents go in."""
	return _corner_of(_square(family, turn, anchor, 0))


static func foot_corner(family: int, turn: int, anchor: Vector2i) -> Vector2i:
	"""The north-west cell of the 2 × 2 at its foot (its last two rows): where it is drawn rising and where residents
	come out below."""
	return _corner_of(_square(family, turn, anchor, ALONG[family] - 2))


static func _square(family: int, turn: int, anchor: Vector2i, along: int) -> PackedInt32Array:
	"""Rows `along` and `along + 1`, the first two cells across (pairs)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in [along, along + 1]:
		for across: int in [0, 1]:
			var cell: Vector2i = cell_at(family, turn, anchor, row, across)
			out.append_array(PackedInt32Array([cell.x, cell.y]))
	return out


static func _corner_of(cells: PackedInt32Array) -> Vector2i:
	"""The north-west corner of `cells` (pairs)."""
	var least: Vector2i = Vector2i(cells[0], cells[1])
	for at: int in range(2, cells.size(), 2):
		least = Vector2i(mini(least.x, cells[at]), mini(least.y, cells[at + 1]))
	return least


static func paired_landing(family: int, turn: int, anchor: Vector2i, cell: Vector2i) -> Vector2i:
	"""The foot cell a walker reaches from top cell `cell` (its first two rows): the same cell under a hatch or spiral;
	for a run, the landing-row cell the same way across. `cell` itself when it is not a top cell."""
	if not valid(family):
		return cell
	for along: int in [0, 1]:
		for across: int in ACROSS[family]:
			if cell_at(family, turn, anchor, along, across) == cell:
				return cell_at(family, turn, anchor, ALONG[family] - 1 if SLOPED[family] else along, across)
	return cell


static func descent(turn: int) -> Vector2i:
	"""Which way it goes down, seen from above (turn 0: north)."""
	return DESCENT[posmod(turn, 4)]


static func fixtures_priced(family: int) -> bool:
	"""Whether a fixture bill is proposed for `family` (stone and spiral: not yet)."""
	return valid(family) and FIXTURE_L0[family] >= 0


static func fixture_wood(family: int) -> int:
	"""Its fittings' wood, milli-U (PLACEHOLDER; 0 when not proposed)."""
	if not fixtures_priced(family):
		return 0
	return FIXTURE_L0[family] * L0_WOOD_MILLI + (FIXTURE_T0[family] + FIXTURE_TREADS[family]) * TREAD_WOOD_MILLI


static func fixture_work(family: int) -> int:
	"""Its fittings' work, milli-WU (PLACEHOLDER; 0 when not proposed)."""
	if not fixtures_priced(family):
		return 0
	return FIXTURE_L0[family] * L0_WORK_MWU + FIXTURE_T0[family] * T0_WORK_MWU + FIXTURE_TREADS[family] * TREAD_WORK_MWU


static func bill_into(family: int, out: PackedInt64Array) -> void:
	"""Add the family's whole placeholder bill to the ledger tally `out`: its quanta at the excavation contract's own
	prices (build_ledger.gd) plus its fittings' wood and work."""
	if not valid(family):
		return
	Ledger.add_quanta_into(QUANTA[family], out)
	out[Ledger.WOOD] += fixture_wood(family)
	out[Ledger.WORK] += fixture_work(family)


static func count_quanta(run_u: int, headroom_u: int, drop_u: int) -> int:
	"""Per cell of width: the 1024 u cubes a run's void touches, the floor falling `drop_u` evenly over `run_u` and the
	void `headroom_u` high, clipped at the level it starts from (open above it). Integer only."""
	var columns: int = ceil_div(run_u, QUANTUM_U)
	var total: int = 0
	for column: int in columns:
		var near: int = column * QUANTUM_U
		var far: int = mini(near + QUANTUM_U, run_u)
		# The void's lowest point, -drop*far/run, and highest, min(0, -drop*near/run + headroom), scaled by run.
		var lowest_row: int = -ceil_div(drop_u * far, run_u * QUANTUM_U)
		var top_scaled: int = mini(0, headroom_u * run_u - drop_u * near)
		var highest_row: int = -floor_div(-top_scaled, run_u * QUANTUM_U)
		total += maxi(0, highest_row - lowest_row)
	return total


static func ceil_div(a: int, b: int) -> int:
	"""a / b rounded up, b > 0, a >= 0."""
	@warning_ignore("integer_division") var out: int = (a + b - 1) / b
	return out


static func floor_div(a: int, b: int) -> int:
	"""a / b rounded down, b > 0, a >= 0."""
	@warning_ignore("integer_division") var out: int = a / b
	return out
