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
##   Ready food (ID_FOOD)    whole units in store      the pantry's total, `food` (the Pantry's headline, K)
##   Planks (ID_FUEL's slot) milli-U                   stores.plank_milli_u (Woods, Tunnels, Water panels)
##   Wood (ID_WOOD)          milli-U                   stores.wood_milli_u  (the same panels)
##   Stone (ID_STONE)        milli-U                   stores.stone_milli_u (the same panels)
##   Residents               how many                  the cast, `residents` (the Residents roster)
##   Beds                    beds installed in homes   the fit-out, `beds` (the Tunnels panel's housing line)
##
## FUEL'S SLOT HOLDS PLANKS. The village keeps no fuel (nothing burns it), so "Fuel: Unavailable" was a
## genuinely unsupported summary; planks are a real, spent stock that had no place in the top bar. The slot is
## relabelled rather than a seventh cell added: the shell's grid is six cells (UI-C3-R01 §1).
##
## UNAVAILABLE IS NOT ZERO. A figure whose owner is absent (a suite that builds no farm; `food` unset) is
## UNKNOWN, reported by `known()` and worded UNAVAILABLE -- never 0, which would read as an empty store.
##
## THE SAME WORDS AS THE PANELS. Food is `FarmHud.food_text` of the pantry's own total (the Pantry headline's
## figure); materials are `StoresScript.units_text`, the formatter the stores' panels print. Nothing here
## re-rounds a figure its panel shows differently.

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FarmHud := preload("res://demo/farm/farm_hud.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

const CELL_FOOD: int = 0
const CELL_PLANKS: int = 1
const CELL_WOOD: int = 2
const CELL_STONE: int = 3
const CELL_RESIDENTS: int = 4
const CELL_BEDS: int = 5
const CELL_COUNT: int = 6
## The captions, in the cells' order (the shell's COUNTER_IDS order).
const CAPTIONS: Array[String] = ["Ready food", "Planks", "Wood", "Stone", "Residents", "Beds"]
## What each figure is, for the ledger and the cell's tooltip.
const WHERE: Array[String] = ["in the Pantry (K)", "in the village stores", "in the village stores",
	"in the village stores", "living in the village", "in the burrow homes"]
const UNAVAILABLE: String = "Unavailable"
const LEDGER_TITLE: String = "Village stores and residents"

## The village's one stores (wood, stone, planks); null: those three are unknown.
var stores: StoresScript = null
## () -> int: the pantry's total in whole units (the Pantry's headline figure). Unset: unknown.
var food: Callable = Callable()
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
	food = pantry.total_units
	residents = cast.actor_count
	beds = network.rooms.beds.bind(network)
	homes = network.rooms.count_done.bind(network, RoomsScript.TEMPLATE_HOME)


func known(cell: int) -> bool:
	"""Whether `cell`'s owner is present, so its figure is a reading rather than unknown."""
	match cell:
		CELL_FOOD:
			return food.is_valid()
		CELL_PLANKS, CELL_WOOD, CELL_STONE:
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
	out[CELL_PLANKS] = stores.plank_milli_u if stores != null else 0
	out[CELL_WOOD] = stores.wood_milli_u if stores != null else 0
	out[CELL_STONE] = stores.stone_milli_u if stores != null else 0
	out[CELL_RESIDENTS] = int(residents.call()) if known(CELL_RESIDENTS) else 0
	out[CELL_BEDS] = int(beds.call()) if known(CELL_BEDS) else 0


func value_text(cell: int, figure: int) -> String:
	"""A cell's value as the top bar and the ledger print it: the panels' own formatter, or UNAVAILABLE."""
	if not known(cell):
		return UNAVAILABLE
	return figure_text(cell, figure)


static func figure_text(cell: int, figure: int) -> String:
	"""A known figure in its panel's words: food "12 U", materials "40.0 U", residents and beds a count."""
	match cell:
		CELL_FOOD:
			return FarmHud.food_text(figure)
		CELL_PLANKS, CELL_WOOD, CELL_STONE:
			return StoresScript.units_text(figure)
	return "%d" % figure


func tooltip(cell: int, figure: int) -> String:
	"""A cell's hover and accessible text: "Wood: 40.0 U in the village stores. Click for the ledger."."""
	if not known(cell):
		return "%s: %s" % [CAPTIONS[cell], UNAVAILABLE]
	return "%s: %s %s. Click for the ledger." % [CAPTIONS[cell], figure_text(cell, figure), WHERE[cell]]


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
	var where: String = WHERE[cell]
	if cell == CELL_BEDS and homes.is_valid():
		var count: int = int(homes.call())
		where = "in %d burrow %s" % [count, "home" if count == 1 else "homes"]
	return "%s: %s %s" % [CAPTIONS[cell], figure_text(cell, figure), where]
