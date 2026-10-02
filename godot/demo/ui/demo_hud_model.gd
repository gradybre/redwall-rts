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
## "Wood: 40.0 U · planks 2.5 U in store", short enough for the ledger's one line (296 px), so the ledger keeps its eight
## lines -- and to the Wood cell's tooltip.
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
## THE SAME WORDS AS THE PANELS. Food is `FarmHud.food_text` of the pantry's own milli-U total (the Pantry
## headline's figure, in the farm's one units form: farm_text.gd UNITS, decision 0222); materials are `StoresScript.units_text`, the formatter the stores' panels print. Nothing here
## re-rounds a figure its panel shows differently.

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FarmHud := preload("res://demo/farm/farm_hud.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const KitchenWords := preload("res://demo/kitchen/kitchen_text.gd")
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
## Wood's ledger line with the planks on it, and the planks in the Wood tooltip (see HEATING FUEL).
const WOOD_LINE: String = "Wood: %s · planks %s in store"
const PLANKS_NOTE: String = " (planks: %s)"

## The village's one stores (wood, stone, planks); null: those three are unknown.
var stores: StoresScript = null
## () -> int: the pantry's total in milli-U, summed before any rounding (the Pantry's headline figure). Unset:
## unknown.
var food: Callable = Callable()
## Whether `food` is days of meals in thousandths (see READY FOOD IS DAYS OF MEALS), and () -> PackedStringArray:
## the lines behind it for the ledger.
var food_days: bool = false
var food_detail: Callable = Callable()
## () -> int: the fuel-days in hundredths, -1 with no heat demand (demo_winter.gd `fuel_days_hundredths`); and
## () -> PackedStringArray, its breakdown (`detail_lines`). Unset: unknown.
var fuel: Callable = Callable()
var fuel_detail: Callable = Callable()
## () -> int: bumped whenever the fuel's breakdown may read differently (demo_winter.gd `stamp`). Unset: 0.
var fuel_stamp: Callable = Callable()
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


func bind_fuel(winter: Object) -> void:
	"""The Heating fuel cell reads the winter (see HEATING FUEL)."""
	fuel = Callable(winter, &"fuel_days_hundredths")
	fuel_detail = Callable(winter, &"detail_lines")
	fuel_stamp = Callable(winter, &"stamp")


func stamp() -> int:
	"""What the ledger and the Heating fuel tooltip show beyond the six figures -- the planks and the fuel's breakdown --
	as one integer that changes when they do (demo_hud_counters.gd repaints on it)."""
	var planks: int = stores.plank_milli_u if stores != null else 0
	var detail: int = int(fuel_stamp.call()) if fuel_stamp.is_valid() else 0
	return planks ^ (detail << 32)


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
	return figure_text(cell, figure)


func is_state(cell: int, figure: int) -> bool:
	"""Whether a known cell's value is a state in words rather than a figure: Heating fuel's no demand."""
	return cell == CELL_FUEL and known(cell) and figure == WinterText.Rules.NO_DEMAND


func is_warning(cell: int, figure: int) -> bool:
	"""Whether a cell is in its warning state: Heating fuel under 2 days (see HEATING FUEL)."""
	return cell == CELL_FUEL and known(cell) and WinterText.is_warning(figure)


static func figure_text(cell: int, figure: int) -> String:
	"""A known figure in its panel's words: food "12.4 U", materials "40.0 U", residents and beds a count."""
	match cell:
		CELL_FOOD:
			return FarmHud.food_text(figure)
		CELL_FUEL:
			return WinterText.cell_value(figure)
		CELL_WOOD, CELL_STONE:
			return StoresScript.units_text(figure)
	return "%d" % figure


func tooltip(cell: int, figure: int) -> String:
	"""A cell's hover and accessible text: "Wood: 40.0 U in the village stores. Click for the ledger."."""
	if not known(cell):
		return "%s: %s" % [CAPTIONS[cell], UNAVAILABLE]
	if cell == CELL_FUEL:
		return "%s. %s. Click for the ledger." % [WinterText.hud_line(figure), ". ".join(_fuel_lines())]
	var where: String = DAYS_TIP if cell == CELL_FOOD and food_days else WHERE[cell]
	if cell == CELL_WOOD and stores != null:
		where += PLANKS_NOTE % StoresScript.units_text(stores.plank_milli_u)
	return "%s: %s %s. Click for the ledger." % [CAPTIONS[cell], _text(cell, figure), where]


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
	"""One ledger line: "Wood: 40.0 U in the village stores", "Beds: 3 in 1 burrow home", or "...: Unavailable"."""
	if not known(cell):
		return "%s: %s" % [CAPTIONS[cell], UNAVAILABLE]
	if cell == CELL_FUEL:
		return WinterText.hud_line(figure)
	if cell == CELL_WOOD and stores != null:
		return WOOD_LINE % [_text(cell, figure), StoresScript.units_text(stores.plank_milli_u)]
	var where: String = _where(cell)
	if cell == CELL_BEDS and homes.is_valid():
		var count: int = int(homes.call())
		where = "in %d burrow %s" % [count, "home" if count == 1 else "homes"]
	var line: String = "%s: %s %s" % [CAPTIONS[cell], _text(cell, figure), where]
	if cell == CELL_FOOD and food_detail.is_valid():
		line += "\n" + "\n".join(PackedStringArray(food_detail.call()))
	return line
