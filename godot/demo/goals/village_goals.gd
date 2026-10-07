extends RefCounted
## THE BUILT-IN GOALS (decision 0781) as DATA, and the small evaluator each one's parts are measured by.
##
## MILESTONES first: the GDD's adopted M1-M4 (docs/game_gdd.md §5.11), each condition a part, worded as the GDD states
## it. A condition the demo models is measured over the village's own state; one it does not (recipe mastery, feasts,
## specialists, mood, warm beds, deaths, winter fuel, the three-day hold) is declared with NO measure, so it shows "not
## in this demo yet" and its milestone cannot be reached here until a later feature binds one (goal_book.gd
## `bind_measure`; the winter-fuel work binds M4's `fuel`). The demo village has nine residents and no arrivals, so no
## milestone is reachable in it: they show the road ahead. Reaching one would award NOTHING here -- the GDD's unlocks
## (REQ-SET-154) and its milestone memory belong to a progression system the demo does not run.
##
## Then the VILLAGE GOALS (approved as built by Brendan, 2026-10-01; decision 0781): small aims over systems
## the demo has today -- the pantry, the kitchen, the stores, the bridges, the tunnels, the seasonal planner's record and
## the calendar -- and, after Brendan's ruling on decision 0901's question (option (b), 2026-10-01; decision 1651), the
## ferry's first crossing and the first regatta day, read off their own latched counts (`ferry`, `regatta`).
##
## A row: [id, group, title, why, what the news says, parts]; a part: [key, label, target, unit, measure kind (M_*)].

const BookScript := preload("res://demo/goals/goal_book.gd")
const LedgerScript := preload("res://demo/goals/goals_ledger.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const OpeningPantry := preload("res://demo/farm/opening_pantry.gd")
const FerryScript := preload("res://demo/ferry/ferry.gd")
const RegattaScript := preload("res://demo/regatta/regatta.gd")

## Not modelled in the demo: the part is declared without a measure.
const M_NONE: int = -1
## The calendar's day (1 = spring day 1 of year 1).
const M_DAY: int = 0
const M_RESIDENTS: int = 1
const M_PORTIONS_PREPARED: int = 2
## Winters the village has come through: the year less one, while anyone lives in it.
const M_WINTERS: int = 3
const M_YEAR: int = 4
## The kitchen's Ready food (the HUD's figure), thousandths of a day.
const M_FOOD_DAYS: int = 5
const M_HARVESTED: int = 6
const M_DISHES: int = 7
const M_FULL_TABLES: int = 8
const M_CLEAN_SEASONS: int = 9
const M_WOOD: int = 10
const M_BRIDGES: int = 11
const M_TUNNELS: int = 12
## Ready food the village cooked or brought in: the Ready food less what the opening stock still in the pantry cooks
## (opening_pantry.gd `portions_left`; Brendan's ruling on decision 0902's question 2, 2026-10-02).
const M_OWN_FOOD_DAYS: int = 13
## Crossings the ferry has rowed home (ferry.gd `crossings_done`, latched; decision 1651).
const M_CROSSINGS: int = 14
## Regattas whose feast was served (regatta.gd `feasts_served`; Brendan's ruling of 2026-10-07, decision 1651): a regatta
## day skipped past, its supper lapsed, does not count.
const M_REGATTAS: int = 15

const MILESTONE: int = BookScript.GROUP_MILESTONE
const VILLAGE: int = BookScript.GROUP_VILLAGE
const COUNT: int = BookScript.UNIT_COUNT
const MILLI: int = BookScript.UNIT_MILLI
const DAYS: int = BookScript.UNIT_DAYS
const FLAG: int = BookScript.UNIT_FLAG
## A part's target that is the recipe book's count of everyday dishes (meal_rules.gd `everyday_dish_count`), read when the
## goals are registered: "Every dish on the table" follows the book as dishes are added, as decision 0781 ruled, and counts
## no occasion's course, drink or dish still waiting for an ingredient (decision 0902).
const EVERYDAY_DISHES: int = -1

const GOALS: Array = [
	[&"m1_settled_hearth", MILESTONE, "M1 Settled Hearth",
		"The refuge becomes a settled hearth. In the full game it opens the mill, workshop, cellar, preserver, saltpan, infirmary, lookout and traps, two new recipes and the Hearth feast.",
		"the village meets the Settled Hearth's conditions (the demo grants no unlocks).",
		[[&"day", "Day", 4, COUNT, M_DAY], [&"residents", "Residents", 12, COUNT, M_RESIDENTS],
		[&"portions", "Portions prepared", 200, COUNT, M_PORTIONS_PREPARED]]],
	[&"m2_abundance", MILESTONE, "M2 Abundance",
		"A village that has come through its first winter and mastered its recipes. In the full game it opens weirs, the apiary, the brewery, stone walls, paved paths and the richer recipes.",
		"the village meets Abundance's conditions (the demo grants no unlocks).",
		[[&"residents", "Residents", 48, COUNT, M_RESIDENTS], [&"winter", "The first winter survived", 1, FLAG, M_WINTERS],
		[&"mastered", "Recipes mastered", 3, COUNT, M_NONE]]],
	[&"m3_deep_roots", MILESTONE, "M3 Deep Roots",
		"Roots deep enough to plant for years ahead. In the full game it opens boats, the boathouse, the nursery and orchards, with the first saplings.",
		"the village meets Deep Roots' conditions (the demo grants no unlocks).",
		[[&"residents", "Residents", 80, COUNT, M_RESIDENTS], [&"year", "Year", 2, COUNT, M_YEAR],
		[&"food_days", "Ready food", 8000, DAYS, M_FOOD_DAYS]]],
	[&"m4_hearth_charter", MILESTONE, "M4 Hearth Charter",
		"The settlement's victory: a self-sufficient community that keeps everyone fed, warm and well through the last three days of a winter. Earned only at the midnight starting winter day 12; play goes on after it.",
		"the village meets the Hearth Charter's conditions (the demo grants no unlocks).",
		[[&"year", "Year", 3, COUNT, M_YEAR], [&"residents", "Residents", 120, COUNT, M_RESIDENTS],
		[&"specialists", "Named specialists with skill 8+ across 6 skills", 8, COUNT, M_NONE],
		[&"mastered", "Recipes mastered", 10, COUNT, M_NONE], [&"feasts", "Feasts completed", 12, COUNT, M_NONE],
		[&"mood", "Mean mood", 6500, COUNT, M_NONE], [&"food", "Ready food for winter demand", 18000, DAYS, M_NONE],
		[&"fuel", "Fuel for winter", 18000, DAYS, M_NONE], [&"warm", "Every resident warm-bedded", 1, FLAG, M_NONE],
		[&"no_deaths", "No starvation or exposure deaths this winter", 1, FLAG, M_NONE],
		[&"held", "All of these held through winter days 9-11", 1, FLAG, M_NONE]]],
	[&"harvest_home", VILLAGE, "Harvest home",
		"Food in store is food the kitchen can cook through the cold months; a crop cut but left lying, or carried but not shelved, is not in store yet.",
		"40 U of the village's own harvest has been brought into store.",
		[[&"harvested", "Harvested into store", 40000, MILLI, M_HARVESTED]]],
	[&"every_dish", VILLAGE, "Every dish on the table",
		"Porridge wants grain, soup wants roots and the fish stew a catch from the stream: a village that can cook them all is not at the mercy of one crop.",
		"each of the kitchen's everyday dishes has been cooked.",
		[[&"dishes", "Everyday dishes cooked", EVERYDAY_DISHES, COUNT, M_DISHES]]],
	[&"full_table", VILLAGE, "A table for everyone",
		"Supper is when the village gathers. Everyone eating a cooked portion means the harvest, the water butt, the woodpile and the cook all came together.",
		"every resident ate a cooked supper.",
		[[&"tables", "Suppers with everyone fed", 1, COUNT, M_FULL_TABLES]]],
	[&"full_larder", VILLAGE, "A full larder",
		"Four days of ready food is the margin the full game asks before newcomers may settle (GDD §5.11); below it one bad week empties the pot.",
		"the larder holds four days of ready food the village cooked or brought in.",
		[[&"food_days", "Ready food of the village's own", 4000, DAYS, M_OWN_FOOD_DAYS]]],
	[&"winter_wood", VILLAGE, "Wood for the cold",
		"Every batch the kitchen cooks burns wood, and the tunnels' bracing and lanterns are paid in it: a woodpile laid in before winter keeps the pot on.",
		"60 U of wood is stacked in store.",
		[[&"wood", "Wood in store", 60000, MILLI, M_WOOD]]],
	[&"over_water", VILLAGE, "Over the water",
		"The stream cuts the village in two. A bridge is the dry way to the far bank, in flood and in ice.",
		"a bridge stands open over the stream.",
		[[&"bridges", "Bridges open", 1, COUNT, M_BRIDGES]]],
	[&"first_crossing", VILLAGE, "First crossing",
		"The ferry rows the far copse's windfall wood across the run, and anyone for whom it is the quicker way. One crossing rowed home means the crew, the boat and the timetable all work.",
		"the ferry has rowed its first crossing home.",
		[[&"crossings", "Ferry crossings rowed home", 1, COUNT, M_CROSSINGS]]],
	[&"regatta_day", VILLAGE, "Regatta day",
		"Once a season the village races its two rowboats on the pond and sits down to the Hearth feast at supper: a day kept together, and one the chronicle remembers.",
		"the village has held its first regatta and sat down to its feast.",
		[[&"regattas", "Regattas held", 1, COUNT, M_REGATTAS]]],
	[&"way_below", VILLAGE, "A way below",
		"Tunnels join homes and stores under frost and rain; three open stretches make a passage rather than a hole.",
		"three stretches of tunnel are dug open.",
		[[&"tunnels", "Tunnel stretches open", 3, COUNT, M_TUNNELS]]],
	[&"clean_season", VILLAGE, "A clean season",
		"The seasonal planner's record shows what each season gave and lost. A whole season with food brought in and no crop withered by frost, blight or neglect is a well-kept farm.",
		"a whole season went into the record with food harvested and no crop lost.",
		[[&"seasons", "Clean seasons recorded", 1, COUNT, M_CLEAN_SEASONS]]],
	[&"first_winter", VILLAGE, "The first winter weathered",
		"Winter is the settlement's real test -- the second milestone asks for it. Spring coming round with the village together is the first proof that it works.",
		"the village has come through its first winter.",
		[[&"winter", "The first winter survived", 1, FLAG, M_WINTERS]]],
]

var world: WorldScript = null
var ledger: LedgerScript = null
var record: RecordScript = null
## The ferry and the regatta whose latched counts the "First crossing" and "Regatta day" goals read; bound by the village
## once both are built (demo_village.gd `_bind_goal_measures`). Unbound, their goals read 0 and wait.
var ferry: FerryScript = null
var regatta: RegattaScript = null


func _init(p_world: WorldScript = null, p_ledger: LedgerScript = null, p_record: RecordScript = null) -> void:
	"""Measure over `p_world` (the guide's read-only view of the village), the goals' ledger and the planner's record."""
	world = p_world
	ledger = p_ledger
	record = p_record


func register_all(book: BookScript) -> int:
	"""Every row of GOALS into `book`, each part measured by `value` of its kind (M_NONE: no measure); the book keeps
	this evaluator alive. Returns how many were taken."""
	book.keep(self)
	var taken: int = 0
	for row: Array in GOALS:
		var parts: Array[BookScript.Part] = []
		for spec: Array in row[5] as Array:
			var kind: int = int(spec[4])
			var measure: Callable = value.bind(kind) if kind != M_NONE else Callable()
			var target: int = Rules.everyday_dish_count() if int(spec[2]) == EVERYDAY_DISHES else int(spec[2])
			parts.append(BookScript.part(StringName(spec[0]), String(spec[1]), target, int(spec[3]), measure))
		if book.register(StringName(row[0]), String(row[2]), String(row[3]), parts, int(row[1]), String(row[4])).is_empty():
			taken += 1
	return taken


func value(kind: int) -> int:
	"""THE EVALUATOR: measure kind `kind` (M_*) over the village now (0 when its owner is not bound)."""
	match kind:
		M_DAY, M_YEAR: return _calendar_value(kind)
		M_RESIDENTS: return residents()
		M_WINTERS: return maxi(_calendar_value(M_YEAR) - 1, 0) if residents() > 0 else 0
		M_FOOD_DAYS: return world.kitchen.days_of_meals_milli() if world != null and world.kitchen != null else 0
		M_OWN_FOOD_DAYS: return _own_food_days()
		M_HARVESTED: return world.pantry.delivered_milli if world != null and world.pantry != null else 0
		M_WOOD: return world.stores.wood_milli_u if world != null and world.stores != null else 0
		M_BRIDGES: return world.open_bridges() if world != null else 0
		M_TUNNELS: return world.open_tunnels() if world != null else 0
		M_CROSSINGS: return ferry.crossings_done if ferry != null else 0
		M_REGATTAS: return regatta.feasts_served if regatta != null else 0
	return _ledger_value(kind)


func _own_food_days() -> int:
	"""M_OWN_FOOD_DAYS over the world (0 without a kitchen; the whole Ready food when it opened with no stock)."""
	if world == null or world.kitchen == null:
		return 0
	var ready: int = world.kitchen.days_of_meals_milli()
	if not world.opening_stock or world.pantry == null:
		return ready
	return own_days_milli(ready, world.kitchen.daily_portions(), OpeningPantry.portions_left(world.pantry))


static func own_days_milli(ready_milli: int, daily_portions: int, opening_portions_left: int) -> int:
	"""Ready food (milli-days) less what `opening_portions_left` portions are worth at `daily_portions` a day, never
	below 0 (0 with no one to feed)."""
	if daily_portions <= 0:
		return 0
	@warning_ignore("integer_division")
	return maxi(0, ready_milli - opening_portions_left * 1000 / daily_portions)


func _calendar_value(kind: int) -> int:
	"""The calendar's day or year now (day 1, year 1 unbound)."""
	if world == null or world.calendar == null:
		return 1
	return world.calendar.now().absolute_day if kind == M_DAY else world.calendar.now().year


func _ledger_value(kind: int) -> int:
	"""A count the goals' ledger keeps."""
	if ledger == null:
		return 0
	match kind:
		M_PORTIONS_PREPARED: return ledger.portions_prepared
		M_DISHES: return ledger.dishes_cooked()
		M_FULL_TABLES: return ledger.full_tables
		M_CLEAN_SEASONS: return ledger.clean_seasons
	return 0


func residents() -> int:
	"""How many residents live in the village."""
	return world.brains.size() if world != null else 0


func observe() -> void:
	"""The ledger's hourly look at the kitchen's and the record's logs (before the book evaluates)."""
	if ledger != null and world != null:
		ledger.observe(world.kitchen, residents(), record, world.calendar.hour_index() if world.calendar != null else 0)
