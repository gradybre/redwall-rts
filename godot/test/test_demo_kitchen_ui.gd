extends "res://test/framework/test_case.gd"
## The first meal loop's faces (decision 0381): the top bar's Ready food as days of meals and the ledger behind it,
## the Pantry with the kitchen bound (the Kitchen tab, the Recipes tab's cookable marks, the kitchen's stock rows and
## what the kitchen reserves), the Cook and Draw water cards from the orders' own decisions, the resident panel's fed
## line and the roster's word, and the cook as the night's early riser.
##
## No scene tree and no staged assets: panels built off-tree, brains on a hand-made space.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const TabScript := preload("res://demo/kitchen/kitchen_tab.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const ModelScript := preload("res://demo/ui/demo_hud_model.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const OATS: int = 15
const CARROT: int = 2
const CABBAGE: int = 6
const STORE_AT: Vector2 = Vector2(8.5, 0.5)

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of `day`."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


func _kitchen(count: int, tick: int, pantry: PantryScript, stores: StoresScript) -> KitchenScript:
	"""A kitchen for `count` mice standing at the square, on a calendar at `tick`."""
	var space := CastSpaceScript.new()
	space.setup([] as Array[Dictionary], [] as Array[Vector3])
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var species := PackedStringArray()
	var keys: Array[StringName] = []
	for i in count:
		var brain := BrainScript.new()
		brain.configure(space, 1.0, 0.25, 3 + i, lengths)
		brain.start_at(Vector2(float(i), 1.0), 0.0, -1, -1)
		brains.append(brain)
		names.append("Mouse %d" % i)
		species.append("mouse")
		keys.append(&"mouse_keeper" if i == 0 else &"mouse_fieldworker")
	var calendar := CalendarScript.new()
	calendar.tick = tick
	var places := PlacesScript.new()
	places.set_points(Vector2(6.0, 0.0), Vector2(3.0, -3.0), Vector2(0.0, 4.0), Vector2(1.5, 4.5))
	places.add_table_seats(Vector2(3.0, -3.0), PlacesScript.SEATS_PER_TABLE)
	var kitchen := KitchenScript.new()
	kitchen.configure(brains, names, species, keys, pantry, stores, calendar, places)
	return kitchen


func _pantry() -> PantryScript:
	"""A pantry with its covered store."""
	return PantryScript.new(StorageScript.new(STORE_AT))


# --- the top bar --------------------------------------------------------------------------------

func test_ready_food_is_days_of_meals() -> void:
	"""Nine residents eat 18 portions a day. 6 portions held + grain 20 U (10 porridge batches) + roots 30 U (10 soup
	batches) = 6 + 40 portions over 18 = 2.55 days, shown "2.5 days"; wood limits the batches (water is drawn as
	needed); with nothing it is a real "0 days"."""
	var pantry := _pantry()
	var stores := StoresScript.new()
	var kitchen := _kitchen(9, tick_at(1, 20), pantry, stores)
	var model := ModelScript.new()
	model.bind_meals(kitchen)
	assert_equal(model.value_text(ModelScript.CELL_FOOD, model.food.call()), "0 days", "nothing: a real zero")
	pantry.add_into(OATS, 20000, 0, _read)
	pantry.add_into(CARROT, 30000, 0, _read)
	for k in 3:
		kitchen.store.add(Rules.DISH_PORRIDGE, 2, 0)
	assert_equal(kitchen.cookable_batches(), 20, "ten of each")
	assert_equal(kitchen.days_of_meals_milli(), (6 + 40) * 1000 / 18, "46 portions over 18 a day")
	assert_equal(model.value_text(ModelScript.CELL_FOOD, model.food.call()), "2.5 days", "floored to a tenth")
	stores.wood_milli_u = 500
	assert_equal(kitchen.cookable_batches(), 5, "five batches of wood")
	assert_equal(ModelScript.new().value_text(ModelScript.CELL_FOOD, 0), ModelScript.UNAVAILABLE, "unbound: unknown")


func test_the_ledger_shows_the_stock_behind_the_days() -> void:
	"""The ledger's Ready food line, then one line of the stock behind it: the portions, the grain and the roots (the
	shell's ledger is a fixed size); the tooltip says how the days are counted."""
	var pantry := _pantry()
	var kitchen := _kitchen(9, tick_at(1, 20), pantry, StoresScript.new())
	pantry.add_into(OATS, 20000, 0, _read)
	var model := ModelScript.new()
	model.bind_meals(kitchen)
	var line: String = model.ledger_line(ModelScript.CELL_FOOD, kitchen.days_of_meals_milli())
	assert_equal(line, "Ready food: 1.1 days of meals\n0 portions · grain 20.0 · roots 0.0 U", "the ledger")
	assert_equal(model.tooltip(ModelScript.CELL_FOOD, kitchen.days_of_meals_milli()), "Ready food: 1.1 days of meals "
		+ "(portions held and cookable, over a day's portions). Click for the ledger.", "the tooltip")


# --- the Pantry ----------------------------------------------------------------------------------

func _panel(kitchen: KitchenScript) -> PantryPanelScript:
	"""The Pantry over the kitchen's pantry, off-tree, with the kitchen bound and its tab."""
	var recipes := RecipesScript.new()
	recipes.load_index()
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(SimScript.new(), kitchen.pantry, recipes)
	var tab := TabScript.new()
	tab.configure(kitchen, func() -> PackedInt32Array: return PackedInt32Array(), Callable())
	panel.set_kitchen(kitchen, tab)
	panel.visible = true
	return panel


func test_the_pantry_shows_the_kitchen_tab_and_marks_two_dishes_cookable() -> void:
	"""With the kitchen bound: tabs Stocks, Recipes, Kitchen; the Recipes tab marks wild oat porridge cookable on oats
	(as the GDD's porridge) and Togget's soup on carrot, and nothing on cabbage."""
	var kitchen := _kitchen(3, tick_at(1, 20), _pantry(), StoresScript.new())
	var panel := _panel(kitchen)
	assert_equal([panel.tab_button(0).text, panel.tab_button(1).text, panel.tab_button(2).text],
		["Stocks", "Recipes", "Kitchen"], "three tabs")
	panel.show_tab(PantryPanelScript.TAB_RECIPES)
	panel.select_item(OATS)
	assert_equal(panel.cookable_text(), "Cookable (active): Wild oat porridge — cooked as the GDD's porridge: grain 2.0 U + water 2.0 U → 2 portions of 1800 NP, 12 WU, keeps 24 h. The kitchen cooks it in turn with togget's vegetable soup.", "oats")
	panel.select_item(CARROT)
	assert_true(panel.cookable_text().begins_with("Cookable (active): Togget's vegetable soup — cooked as the GDD's root_stew: roots 3.0 U + water 1.0 U"), "carrot")
	panel.select_item(CABBAGE)
	assert_equal(panel.cookable_text(), "", "cabbage feeds neither")
	assert_equal(panel.recipe_heading(), PantryPanelScript.RECIPE_HEADING_COOKING, "the heading says two are cookable")
	panel.show_tab(PantryPanelScript.TAB_KITCHEN)
	assert_true(panel.page_shown(PantryPanelScript.TAB_KITCHEN), "the Kitchen tab")


func test_the_stocks_table_shows_portions_water_and_what_the_kitchen_holds() -> void:
	"""The Stocks table ends with each dish's portions (ready food) and the water; a store's row says how much the
	kitchen has reserved there."""
	var pantry := _pantry()
	var stores := StoresScript.new()
	stores.add_water(6000)
	pantry.add_into(OATS, 10000, 0, _read)
	pantry.add_into(CARROT, 20000, 0, _read)
	var kitchen := _kitchen(3, tick_at(1, 20), pantry, stores)
	kitchen.store.add(Rules.DISH_SOUP, 2, 3)
	var panel := _panel(kitchen)
	panel.show_tab(PantryPanelScript.TAB_STOCKS)
	var rows := PackedStringArray()
	for row in panel.stock_row_count() + 2:
		rows.append(" | ".join(panel.shown_stock_row(row)))
	assert_true(rows.has("Oats | 10.0 U · 8.0 U for the kitchen | — | Covered store | all in 24d"), "oats: two breakfasts' reserved")
	assert_true(rows.has("Carrot | 20.0 U · 12.0 U for the kitchen | — | Covered store | all in 10d"), "carrot: two suppers'")
	assert_true(rows.has("Togget's vegetable soup (ready food) | 2 portions | — | Kitchen (pot and table) | spoils in 24 h"), "the portions")
	assert_true(rows.has("Water | 6.0 U | 0.0 U | Water butt by the well | never spoils"), "the water")


# --- the cards -------------------------------------------------------------------------------------

func test_the_cook_card_is_the_orders_decision() -> void:
	"""The Cook card reads `decide_meal`: with no water and Keep water drawn off it is refused with the exact words
	and fix, and the button is disabled; with water it names the batches, the costs, the work and who cooks."""
	var pantry := _pantry()
	var stores := StoresScript.new()
	pantry.add_into(CARROT, 9000, 0, _read)
	var kitchen := _kitchen(3, tick_at(1, 14), pantry, stores)
	kitchen.keep_water = false
	var card := CardScript.new()
	kitchen.preview_cook_into(card, PackedInt32Array())
	assert_false(card.is_ok(), "refused")
	assert_equal(card.code, KitchenScript.NO_WATER, "the order's code")
	assert_equal(card.reason, "the water butt holds 0.0 U; togget's vegetable soup needs 1.0 U a batch (2.0 U for the meal)", "the reason")
	assert_equal(card.fix, "Pantry (K) ▸ Kitchen ▸ Draw water", "the fix")
	assert_true(card.text().begins_with("Cook supper now\nCan't now: the water butt holds 0.0 U;"), "the card leads with it")
	var d: KitchenScript.Decision = kitchen.decide_meal()
	assert_equal(Words.cant(card.reason, card.fix), Words.cant(d.reason, d.fix), "the same words as the order")
	stores.add_water(10000)
	kitchen.preview_cook_into(card, PackedInt32Array())
	assert_true(card.is_ok(), "allowed with water")
	assert_equal(card.verb, "Cook supper now", "the verb")
	assert_equal(card.result, "2 batches of togget's vegetable soup: 4 portions of 1800 NP", "what it makes")
	assert_equal(card.who, "Queue for the cook: Mouse 0 (the village cook)", "who")
	assert_equal(card.work_usec, 2 * 200 * CalendarScript.HOUR_USEC / SimClock.TICKS_PER_HOUR, "two batches at the step rate")
	assert_equal(kitchen.order_cook(PackedInt32Array()), "Cook supper now: 2 batches of togget's vegetable soup · Queue for the cook: Mouse 0 (the village cook)", "the order says the same")


func test_the_draw_card_and_a_full_butt() -> void:
	"""Draw water names a carry for the nearest selected; a full butt refuses."""
	var stores := StoresScript.new()
	var kitchen := _kitchen(2, tick_at(1, 14), _pantry(), stores)
	var card := CardScript.new()
	kitchen.preview_draw_into(card, PackedInt32Array([1]))
	assert_true(card.is_ok(), "allowed")
	assert_equal(card.who, "Assign selected: Mouse 1", "the selected")
	assert_true(card.result.begins_with("12.0 U into the water butt by the well"), card.result)
	for brain: RefCounted in kitchen._brains:
		brain.set(&"resting", true)
	kitchen.preview_draw_into(card, PackedInt32Array())
	assert_equal([card.who, card.result.begins_with("Up to 24.0 U into the water butt")], ["Queue for anyone free: "
		+ "whoever is nearest the well, when someone is", true], "queued: up to the largest carry, never 0.0 U")
	stores.add_water(StoresScript.WATER_CAP_MILLI_U)
	kitchen.preview_draw_into(card, PackedInt32Array([1]))
	assert_equal(card.code, KitchenScript.BUTT_FULL, "full")
	assert_true(kitchen.order_draw(PackedInt32Array([1])).begins_with("Can't now: the butt is full"), "the order refuses alike")


# --- the resident ------------------------------------------------------------------------------

func test_the_fed_line_and_the_roster_word() -> void:
	"""Alone: fed state, fullness, NP today against the GDD's need, the last meal; in a list or the roster, the word."""
	var kitchen := _kitchen(2, tick_at(1, 14), _pantry(), StoresScript.new())
	kitchen.fed.ate_meal(0, 2, Rules.DISH_PORRIDGE, 30)
	kitchen.fed.hunger[1] = 2000
	assert_equal(kitchen.fed_text(0, true), "Fed · 100% full · 1800/6000 NP today\nLast meal: breakfast, porridge",
		"alone, two lines that fit the panel")
	assert_equal([kitchen.fed_text(1, false), kitchen.fed_word(1)], ["peckish", "peckish"], "in a list, and the roster")
	for k in 4:
		kitchen.fed.ate_meal(0, 3 + k, Rules.DISH_PORRIDGE if k % 2 == 1 else Rules.DISH_SOUP, kitchen.hour_index())
	assert_true(kitchen.fed_text(0, true).ends_with("\nMonotony -200 (6 h): porridge 3 of last 6"), kitchen.fed_text(0, true))


# --- the cook rises early -----------------------------------------------------------------------

func test_the_cook_rises_early_only_with_work_and_is_not_sent_back() -> void:
	"""At 01:00 the cook with today's meals to get cooked is up early (the night's early riser); with nothing to do it
	is not; another resident never is. Its sleep task ends then, and the night does not send it back to bed."""
	var pantry := _pantry()
	var kitchen := _kitchen(2, tick_at(1, 1), pantry, StoresScript.new())
	assert_false(kitchen.up_early(0), "no food: nothing to do")
	pantry.add_into(OATS, 10000, 0, _read)
	kitchen.update()
	kitchen.calendar.tick += SimClock.TICKS_PER_HOUR
	kitchen.update()
	assert_true(kitchen.up_early(0), "food to fetch: up early")
	assert_false(kitchen.up_early(1), "not the others")
	kitchen.calendar.tick = tick_at(1, 6)
	kitchen.update()
	assert_false(kitchen.up_early(0), "dawn: everyone is up")
