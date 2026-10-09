extends RefCounted
## THE DEMO'S HUD READ MODEL: what the top bar's six cells and its ledger say, read from the village's own
## owners. Decision 0251 (review group E, finding F10). Presentation only: it READS the demo's stores, pantry,
## cast and homes and writes nothing anywhere -- least of all into the settlement simulation.
##
## ONE OWNER PER FIGURE. The top bar used to mix two economies: its Wood and Stone were the settlement
## simulation's (UIManager reads EconomySystem, which the demo never runs a village through) while the Tunnels,
## Woods and Water panels spent the demo's; its Food was the pantry's but its ledger the settlement's; its
## Residents read "--" beside nine working residents; its Beds read "Unavailable" beside homes full of beds.
## Here each cell has exactly one source, the same object its panel reads:
##
##   cell (shell slot)       figure                    owner (and the panel that shows the same number)
##   Ready food (ID_FOOD)    milli-U                   the pantry's total, `food` (the Pantry's headline, K)
##   Heating fuel (ID_FUEL)  fuel-days, hundredths     the winter, `fuel` (the Heating fuel breakdown, its cell's click)
##   Wood (ID_WOOD)          milli-U                   stores.wood_milli_u  (the same panels)
##   Stone (ID_STONE)        milli-U                   stores.stone_milli_u (the same panels)
##   Residents               how many                  the cast, `residents` (the Residents roster)
##   Beds                    beds installed in homes   the fit-out, `beds` (the Tunnels panel's housing line)
##
## HEATING FUEL (decision 0571, Brendan's ruling 5; it restores UI-SET-003 over decision 0251's Planks). The hearths
## burn wood now (demo/winter/), so Fuel's slot is UI-SET-003's own: "Heating fuel: N days" -- fuel-days, one decimal,
## floored -- or, with no heat demanded, "No current heat demand" (the cell's short "No demand"); under 2 days it is
## in its WARNING state (`is_warning`: UI §7's fuel warning). Its tooltip adds the breakdown (today's demand, the last
## heated hour, the winter projection), which its click opens in full (demo/winter/fuel_panel.gd); its ledger line is the
## one line, the shell's ledger being a fixed size. PLANKS, which held the slot, move to the ledger -- on Wood's line,
## "Wood: 40 logs · 3 planks in store", short enough for the ledger's one line (296 px), so the ledger keeps its eight
## lines -- and to the Wood cell's tooltip.
##
## NATURAL MEASURES (decision 1011 §3, DEC-049; MEAS-2, decision 1801). No cell says "U". Wood is a WORD LEVEL -- none /
## very low / running low / enough / plenty -- judged by goods_measures.gd `wood_level` from the winter's own owners
## (`bind_fuel`): `firewood_urgent()` (under 2 fuel-days or a hearth out: Heating fuel's own warning), `firewood_wanted()`
## (the Firewood order stands) and the fuel's twelve-day `projection_milli()`. No threshold is made here. The words are a
## state, so they draw in the 16 px disclosure role as Heating fuel's "No demand" does ("running low" is 106 px in the
## 18 px value face, past the 1280x720 cell's 101; 91 px at 16). With no winter bound the cell shows the count, "40
## logs". Stone is a count in blocks (P1: it has no use rate to judge a level by). The tooltip and the ledger keep the
## figures, with the weight in the tooltip.
##
## UNAVAILABLE IS NOT ZERO. A figure whose owner is absent (a suite that builds no farm; `food` unset) is
## UNKNOWN, reported by `known()` and worded UNAVAILABLE -- never 0, which would read as an empty store.
##
## READY FOOD IS DAYS OF MEALS (decision 0381, review F21/UX-027). With the village's kitchen bound (`bind_meals`), the
## Ready food cell is the kitchen's `days_of_meals_milli`: the portions held plus the portions the stores' grain and
## roots would cook, over the portions the village eats a day (a portion a meal, two meals, every resident) -- "4.5
## days" -- and the ledger's food line shows the raw stock behind it on one more line (the kitchen's `ledger_lines`: the
## portions, the grain and the roots; the shell's ledger is a fixed size). Without a kitchen it is the pantry's total, as
## before.
##
## THE SAME WORDS AS THE PANELS. Every amount is goods_measures.gd's, the module every panel words its amounts with:
## food the pantry's own milli-U total in baskets of food (the Pantry headline's figure), wood in logs, stone in blocks,
## planks counted. Nothing here re-rounds a figure its panel shows differently.

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const KitchenWords := preload("res://demo/kitchen/kitchen_text.gd")
const RawReserveScript := preload("res://demo/kitchen/raw_reserve.gd")
const WinterText := preload("res://demo/winter/winter_text.gd")

const CELL_FOOD: int = 0
const CELL_FUEL: int = 1
const CELL_WOOD: int = 2
const CELL_STONE: int = 3
const CELL_RESIDENTS: int = 4
const CELL_BEDS: int = 5
const CELL_COUNT: int = 6
## The captions, in the cells' order (the shell's COUNTER_IDS order).
const CAPTIONS: Array[String] = ["Ready food", "Heating fuel", "Wood", "Stone", "Residents", "Beds"]
## What each figure is, for the ledger and the cell's tooltip.
const WHERE: Array[String] = ["in the Pantry (K)", "of wood at today's demand", "in the village stores",
	"in the village stores", "living in the village", "in the burrow homes"]
const UNAVAILABLE: String = "Unavailable"
const LEDGER_TITLE: String = "Village stores and residents"
## Ready food in days (see READY FOOD IS DAYS OF MEALS): tenths, floored (kitchen_text.gd `days_value`).
const DAYS_WHERE: String = "of meals"
const DAYS_TIP: String = "of meals (portions held and cookable, over a day's portions)"
## EATEN RAW BESIDE IT (decision 1736): the raw reserve Ready food does not count, on the ledger's food line -- short,
## "Ready food: 2.5 days · raw 0.4 days", as the ledger keeps its eight lines at 296 px (at most 37 characters, both
## figures in double digits) -- and in full words in the cell's tooltip.
const RAW_LINE: String = "%s: %s · raw %s"
const RAW_TIP: String = " Eaten raw: %s more (berries, fruit, honey, nuts, jam, cheese and other food eaten as it is)."
## Wood's ledger line with the planks on it, and the planks in the Wood tooltip (see HEATING FUEL).
const WOOD_LINE: String = "Wood: %s · %s in store"
const PLANKS_NOTE: String = " (and %s)"
## The Wood tooltip with its level (see NATURAL MEASURES): the level, the wood and its weight, the winter's need.
const WOOD_TIP: String = "Wood: %s — %s (%s) in the village stores; winter needs %s%s. Click for the ledger."
## The goods the amount cells word, in the cells' order ("" for a cell that is not an amount).
const CELL_GOODS: Array[StringName] = [&"food", &"", &"wood", &"stone", &"", &""]

## The village's one stores (wood, stone, planks); null: those three are unknown.
var stores: StoresScript = null
## () -> int: the pantry's total in milli-U, summed before any rounding (the Pantry's headline figure). Unset:
## unknown.
var food: Callable = Callable()
## Whether `food` is days of meals in thousandths (see READY FOOD IS DAYS OF MEALS), and () -> PackedStringArray:
## the lines behind it for the ledger.
var food_days: bool = false
var food_detail: Callable = Callable()
## The raw reserve beside Ready food (decision 1736); null: not shown.
var raw_reserve: RawReserveScript = null
## () -> int: the fuel-days in hundredths, -1 with no heat demand (demo_winter.gd `fuel_days_hundredths`); and
## () -> PackedStringArray, its breakdown (`detail_lines`). Unset: unknown.
var fuel: Callable = Callable()
var fuel_detail: Callable = Callable()
## () -> int: bumped whenever the fuel's breakdown may read differently (demo_winter.gd `stamp`). Unset: 0.
var fuel_stamp: Callable = Callable()
## The Wood level's three readings (see NATURAL MEASURES): () -> bool the winter's `firewood_urgent` and
## `firewood_wanted`, () -> int its fuel's `projection_milli`. Unset: no level, the count.
var wood_urgent: Callable = Callable()
var wood_wanted: Callable = Callable()
var wood_projection: Callable = Callable()
## () -> int: how many residents live in the village (the cast). Unset: unknown.
var residents: Callable = Callable()
## () -> int: beds installed in the dug homes. Unset: unknown.
var beds: Callable = Callable()
## () -> int: dug burrow homes, for the beds' ledger line. Unset: the line names no count of homes.
var homes: Callable = Callable()


func bind_village(village_stores: StoresScript, pantry: PantryScript, cast: DemoCastScript, network: GraphScript) -> void:
	"""Read the village's own owners (demo_village.gd wires this): the stores, the pantry's total, the cast's count,
	and the beds installed in -- and the count of -- the network's dug burrow homes."""
	stores = village_stores
	food = pantry.total_milli
	residents = cast.actor_count
	beds = network.rooms.beds.bind(network)
	homes = network.rooms.count_done.bind(network, RoomsScript.TEMPLATE_HOME)


func bind_meals(kitchen: RefCounted) -> void:
	"""The Ready food cell reads the kitchen (see READY FOOD IS DAYS OF MEALS)."""
	food = Callable(kitchen, &"days_of_meals_milli")
	food_detail = Callable(kitchen, &"ledger_lines")
	food_days = true
	raw_reserve = RawReserveScript.new(kitchen)


func bind_fuel(winter: Object) -> void:
	"""The Heating fuel cell reads the winter (see HEATING FUEL), and the Wood cell's level its Firewood order's own
	readings (see NATURAL MEASURES)."""
	fuel = Callable(winter, &"fuel_days_hundredths")
	fuel_detail = Callable(winter, &"detail_lines")
	fuel_stamp = Callable(winter, &"stamp")
	wood_urgent = Callable(winter, &"firewood_urgent")
	wood_wanted = Callable(winter, &"firewood_wanted")
	wood_projection = Callable(winter.get(&"fuel") as Object, &"projection_milli")


func stamp() -> int:
	"""What the ledger and the tooltips show beyond the six figures -- the planks, the fuel's breakdown, the raw
	reserve beside Ready food (decision 1736) and the Wood level (decision 1801) -- as one integer that changes when they
	do (demo_hud_counters.gd repaints on it)."""
	var planks: int = stores.plank_milli_u if stores != null else 0
	var detail: int = int(fuel_stamp.call()) if fuel_stamp.is_valid() else 0
	var raw: int = raw_reserve.hourly_days_milli() if raw_reserve != null else 0
	var level: int = wood_level(stores.wood_milli_u) + 1 if stores != null else 0
	return planks ^ (detail << 32) ^ (raw << 16) ^ (level << 56)


func wood_level(wood_milli: int) -> int:
	"""The Wood cell's level (goods_measures.gd LEVEL_*) from the winter's readings, or -1 with no winter bound (the
	cell then shows the count)."""
	if not wood_urgent.is_valid() or not wood_wanted.is_valid() or not wood_projection.is_valid():
		return -1
	return Measures.wood_level(wood_milli, bool(wood_urgent.call()), bool(wood_wanted.call()),
		int(wood_projection.call()))


func known(cell: int) -> bool:
	"""Whether `cell`'s owner is present, so its figure is a reading rather than unknown."""
	match cell:
		CELL_FOOD:
			return food.is_valid()
		CELL_FUEL:
			return fuel.is_valid()
		CELL_WOOD, CELL_STONE:
			return stores != null
		CELL_RESIDENTS:
			return residents.is_valid()
		CELL_BEDS:
			return beds.is_valid()
	return false


func read_into(out: PackedInt64Array) -> void:
	"""Every cell's figure now, in the cells' order (0 for an unknown one -- ask `known()`; never shown as 0).
	Allocates nothing: `out` is the caller's, sized CELL_COUNT."""
	out[CELL_FOOD] = int(food.call()) if known(CELL_FOOD) else 0
	out[CELL_FUEL] = int(fuel.call()) if known(CELL_FUEL) else 0
	out[CELL_WOOD] = stores.wood_milli_u if stores != null else 0
	out[CELL_STONE] = stores.stone_milli_u if stores != null else 0
	out[CELL_RESIDENTS] = int(residents.call()) if known(CELL_RESIDENTS) else 0
	out[CELL_BEDS] = int(beds.call()) if known(CELL_BEDS) else 0


func value_text(cell: int, figure: int) -> String:
	"""A cell's value as the top bar and the ledger print it: the panels' own formatter, or UNAVAILABLE."""
	if not known(cell):
		return UNAVAILABLE
	return _text(cell, figure)


func _text(cell: int, figure: int) -> String:
	"""A known figure in its panel's words -- Ready food in days when it is days of meals."""
	if cell == CELL_FOOD and food_days:
		return KitchenWords.days_value(figure)
	if cell == CELL_FUEL:
		return WinterText.cell_value(figure)
	if cell == CELL_WOOD and wood_level(figure) >= 0:
		return Measures.level_words(wood_level(figure))
	return figure_text(cell, figure)


func is_state(cell: int, figure: int) -> bool:
	"""Whether a known cell's value is a state in words rather than a figure: Heating fuel's no demand, and the Wood
	level (see NATURAL MEASURES)."""
	if cell == CELL_WOOD:
		return known(cell) and wood_level(figure) >= 0
	return cell == CELL_FUEL and known(cell) and figure == WinterText.Rules.NO_DEMAND


func is_warning(cell: int, figure: int) -> bool:
	"""Whether a cell is in its warning state: Heating fuel under 2 days (see HEATING FUEL)."""
	return cell == CELL_FUEL and known(cell) and WinterText.is_warning(figure)


static func figure_text(cell: int, figure: int) -> String:
	"""A known figure in its cell's words: food "6½ baskets" (of food), wood "40 logs", stone "20 blocks", residents
	and beds a count."""
	if cell == CELL_FUEL:
		return WinterText.cell_value(figure)
	if not CELL_GOODS[cell].is_empty():
		return Measures.amount_cell(CELL_GOODS[cell], figure)
	return "%d" % figure


func tooltip(cell: int, figure: int) -> String:
	"""A cell's hover and accessible text, with the amount's weight: "Wood: plenty — 40 logs (200 kg) in the village
	stores; winter needs 30 logs (and 3 planks). Click for the ledger."."""
	if not known(cell):
		return "%s: %s" % [CAPTIONS[cell], UNAVAILABLE]
	if cell == CELL_FUEL:
		return "%s. %s. Click for the ledger." % [WinterText.hud_line(figure), ". ".join(_fuel_lines())]
	if cell == CELL_WOOD and wood_level(figure) >= 0:
		return WOOD_TIP % [Measures.level_words(wood_level(figure)), Measures.amount(&"wood", figure),
			Measures.weight(&"wood", figure), Measures.need(&"wood", int(wood_projection.call())), _planks_note()]
	var where: String = DAYS_TIP if cell == CELL_FOOD and food_days else WHERE[cell]
	if cell == CELL_WOOD:
		where += _planks_note()
	var raw: String = RAW_TIP % raw_days_text() if cell == CELL_FOOD and raw_reserve != null else ""
	return "%s: %s %s.%s Click for the ledger." % [CAPTIONS[cell], _tip_figure(cell, figure), where, raw]


func _tip_figure(cell: int, figure: int) -> String:
	"""A tooltip's figure: an amount with its weight ("40 logs (200 kg)"; none has none), else the cell's words."""
	if (cell == CELL_FOOD and food_days) or CELL_GOODS[cell].is_empty() or figure <= 0:
		return _text(cell, figure)
	return "%s (%s)" % [figure_text(cell, figure), Measures.weight(CELL_GOODS[cell], figure)]


func _planks_note() -> String:
	"""The planks beside the wood in its tooltip: " (and 3 planks)"; nothing without stores."""
	return PLANKS_NOTE % Measures.amount(&"planks", stores.plank_milli_u) if stores != null else ""


func raw_days_text() -> String:
	"""The raw reserve in days ("3.5 days"; "0 days"), as Ready food is worded (decision 1736)."""
	return KitchenWords.days_value(raw_reserve.hourly_days_milli()) if raw_reserve != null else UNAVAILABLE


func _fuel_lines() -> PackedStringArray:
	"""The fuel's breakdown lines (none unbound)."""
	return PackedStringArray(fuel_detail.call()) if fuel_detail.is_valid() else PackedStringArray()


func _where(cell: int) -> String:
	"""Where a cell's figure is, in words."""
	return DAYS_WHERE if cell == CELL_FOOD and food_days else WHERE[cell]


func ledger_text(figures: PackedInt64Array) -> String:
	"""The ledger the counters open: a title and one line per cell, each figure with where it is, in the cells'
	order -- the same figures the cells show, so the drill-down never changes a number's meaning."""
	var lines := PackedStringArray([LEDGER_TITLE])
	for cell: int in CELL_COUNT:
		lines.append(ledger_line(cell, figures[cell]))
	return "\n".join(lines)


func ledger_line(cell: int, figure: int) -> String:
	"""One ledger line: "Wood: 40 logs · 3 planks in store", "Beds: 3 in 1 burrow home", or "...: Unavailable". The
	ledger keeps the figures where a cell shows a level (see NATURAL MEASURES)."""
	if not known(cell):
		return "%s: %s" % [CAPTIONS[cell], UNAVAILABLE]
	if cell == CELL_FUEL:
		return WinterText.hud_line(figure)
	if cell == CELL_WOOD and stores != null:
		return WOOD_LINE % [figure_text(cell, figure), Measures.amount(&"planks", stores.plank_milli_u)]
	var where: String = _where(cell)
	if cell == CELL_BEDS and homes.is_valid():
		var count: int = int(homes.call())
		where = "in %d burrow %s" % [count, "home" if count == 1 else "homes"]
	var line: String = "%s: %s %s" % [CAPTIONS[cell], _text(cell, figure), where]
	if cell == CELL_FOOD and raw_reserve != null:
		line = RAW_LINE % [CAPTIONS[cell], _text(cell, figure), raw_days_text()]
	if cell == CELL_FOOD and food_detail.is_valid():
		line += "\n" + "\n".join(PackedStringArray(food_detail.call()))
	return line
