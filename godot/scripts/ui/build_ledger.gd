extends RefCounted
## UI-BUILD-005, the running ledger's arithmetic and words (DEC-061; SET-BUILD-001 §7.2 and §10).
##
## A painted underground cell is dug to its level's clear height, so it is `clear_height_u / 1024` excavation
## quanta, and each quantum costs what the excavation contract already charges (BAL-ROOM-001's derivation from
## BAL-UG-001 and ECON-002): brace wood and stone, brace + cut + finish work, and earth out. Every number here is
## READ from `excavation_contract.gd`; nothing is restated. At the level pack's 4096 u clear height that is wood
## 1000, stone 1000, work 16920 milli-WU and earth 8000 milli-U per cell (SET-BUILD-001 §7.2's table, which
## test_build_ledger.gd checks against these reads).
##
## Amounts are words in natural measures (DEC-049; goods_measures.gd): what a plan needs rounds UP, what the stores
## hold rounds DOWN. Work is GDD §4.1's WU, one game minute of base-speed labour, shown in minutes or hours. The
## ledger SHOWS needs beside stock and never reserves, deducts or orders anything (BUILD-REQ-019, -020).

const Excavation := preload("res://scripts/core/excavation_contract.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

## The initial level pack's `clear_height_u` (data/underground/initial_level_pack.json), for a host with no level
## catalog to read it from; the demo passes the catalog's own value.
const DEFAULT_CLEAR_HEIGHT_U: int = 4096
## Slots of a cost tally.
const WOOD: int = 0
const STONE: int = 1
const WORK: int = 2
const EARTH: int = 3
const SLOTS: int = 4
## GDD §4.1: one WU is one game minute; milli-WU per game hour.
const MILLI_WU_PER_MINUTE: int = 1000
const MINUTES_PER_HOUR: int = 60
const LINE_FORMAT: String = "%s (+%d cells)"
const NOTHING_YET: String = "Plan needs nothing yet"


static func quanta_per_cell(clear_height_u: int) -> int:
	"""How many 1 m³ excavation quanta one painted cell opens: its level's clear height in whole quanta."""
	@warning_ignore("integer_division") var quanta: int = maxi(clear_height_u, 0) / Excavation.QUANTUM_SIDE_U
	return quanta


static func per_cell_into(clear_height_u: int, out: PackedInt64Array) -> void:
	"""One cell's cost into `out` (resized to SLOTS only when it differs): wood and stone in milli-U, work in
	milli-WU, earth out in milli-U."""
	totals_into(1, clear_height_u, out)


static func totals_into(cells: int, clear_height_u: int, out: PackedInt64Array) -> void:
	"""`cells` painted cells' cost into `out` (see per_cell_into). No allocation once `out` is sized."""
	if out.size() != SLOTS:
		out.resize(SLOTS)
	var quanta: int = maxi(cells, 0) * quanta_per_cell(clear_height_u)
	out[WOOD] = quanta * Excavation.BRACE_WOOD_MILLI
	out[STONE] = quanta * Excavation.BRACE_STONE_MILLI
	out[WORK] = quanta * (Excavation.BRACE_WORK_MWU + Excavation.CUT_WORK_MWU + Excavation.FINISH_WORK_MWU)
	out[EARTH] = quanta * Excavation.EARTH_MILLI


static func work_text(milli_wu: int) -> String:
	"""Work as time for one worker at base speed, rounded UP: "about 17 minutes", "about 6.8 hours"."""
	var work: int = maxi(milli_wu, 0)
	@warning_ignore("integer_division") var minutes: int = (work + MILLI_WU_PER_MINUTE - 1) / MILLI_WU_PER_MINUTE
	if minutes < MINUTES_PER_HOUR:
		return "about 1 minute" if minutes == 1 else "about %d minutes" % minutes
	var per_hour: int = MILLI_WU_PER_MINUTE * MINUTES_PER_HOUR
	@warning_ignore("integer_division") var tenths: int = (work * 10 + per_hour - 1) / per_hour
	@warning_ignore("integer_division") var whole: int = tenths / 10
	return "about %d.%d hours" % [whole, tenths % 10]


static func cost_words(tally: PackedInt64Array) -> String:
	"""A tally as a cost: "1 log of wood, 1 block of stone; work about 17 minutes; earth out 4 baskets"."""
	return "%s, %s; work %s; earth out %s" % [Measures.need(&"wood", tally[WOOD]),
		Measures.need(&"stone", tally[STONE]), work_text(int(tally[WORK])), Measures.need(&"excavated_earth", tally[EARTH])]


static func stock_words(wood_milli: int, stone_milli: int) -> String:
	"""What the stores hold, rounded down: "stores hold 40 logs of wood, 20 blocks of stone"."""
	return "stores hold %s, %s" % [Measures.amount(&"wood", wood_milli), Measures.amount(&"stone", stone_milli)]


static func summary(cells: int, clear_height_u: int, wood_milli: int, stone_milli: int, tally: PackedInt64Array) -> String:
	"""UI-BUILD-005's accessible line: "Plan needs <totals>; work <hours>; earth out <amount>; stores hold <stock>".
	`tally` is scratch space (filled here)."""
	if cells <= 0:
		return "%s; %s" % [NOTHING_YET, stock_words(wood_milli, stone_milli)]
	totals_into(cells, clear_height_u, tally)
	return "Plan needs %s; %s" % [cost_words(tally), stock_words(wood_milli, stone_milli)]


static func line(type_name: String, cells: int) -> String:
	"""One expanded-ledger line: "Dormitory (+24 cells)"."""
	return LINE_FORMAT % [type_name, cells]
