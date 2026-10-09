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
const Catalog := preload("res://demo/farm/farm_catalog.gd")
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
const RawReserveScript := preload("res://demo/kitchen/raw_reserve.gd")
const CountersScript := preload("res://demo/ui/demo_hud_counters.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")

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
	## One portion a diner (decision 1732's `portion_halves` 2): this suite's scenarios are about other mechanics, sized
	## for one portion each; the portion and a half and its seconds are test_demo_balance_tuning.gd's.
	kitchen.portion_halves = 2
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
	@warning_ignore("integer_division") assert_equal(kitchen.days_of_meals_milli(), (6 + 40) * 1000 / 18, "46 portions over 18 a day")
	assert_equal(model.value_text(ModelScript.CELL_FOOD, model.food.call()), "2.5 days", "floored to a tenth")
	stores.wood_milli_u = 500
	assert_equal(kitchen.cookable_batches(), 5, "five batches of wood")
	assert_equal(ModelScript.new().value_text(ModelScript.CELL_FOOD, 0), ModelScript.UNAVAILABLE, "unbound: unknown")


func test_the_ledger_shows_the_stock_behind_the_days() -> void:
	"""The ledger's Ready food line with the raw reserve beside it (decision 1736), then one line of the stock behind it:
	the portions, the grain and the roots (the shell's ledger is a fixed size); the tooltip says how the days are
	counted, and the raw reserve's days."""
	var pantry := _pantry()
	var kitchen := _kitchen(9, tick_at(1, 20), pantry, StoresScript.new())
	pantry.add_into(OATS, 20000, 0, _read)
	var model := ModelScript.new()
	model.bind_meals(kitchen)
	var line: String = model.ledger_line(ModelScript.CELL_FOOD, kitchen.days_of_meals_milli())
	assert_equal(line, "Ready food: 1.1 days · raw 0 days\n0 portions · 4 baskets to cook", "the ledger: 20 U of grain, in baskets of food")
	assert_true(("Ready food: %s · raw %s" % [Words.days_value(12500), Words.days_value(12500)]).length() <= 37,
		"the longest line keeps to the ledger's width")
	assert_equal(model.tooltip(ModelScript.CELL_FOOD, kitchen.days_of_meals_milli()), "Ready food: 1.1 days of meals "
		+ "(portions held and cookable, over a day's portions). Eaten raw: 0 days more (berries, fruit, honey, nuts, "
		+ "jam, cheese and other food eaten as it is). Click for the ledger.", "the tooltip")


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


func test_the_pantry_shows_the_kitchen_tab_and_marks_the_dishes_cookable() -> void:
	"""With the kitchen bound: tabs Stocks, Recipes, Kitchen; the Recipes tab marks every recipe-book dish that takes the
	item cookable -- oats: the two porridges (as the GDD's porridge), carrot: Togget's soup, the vole stew and both
	fish stews' roots, cabbage: the bean hotpot (decision 0601) -- then how the cook picks."""
	var kitchen := _kitchen(3, tick_at(1, 20), _pantry(), StoresScript.new())
	var panel := _panel(kitchen)
	assert_equal([panel.tab_button(0).text, panel.tab_button(1).text, panel.tab_button(2).text],
		["Stocks", "Recipes", "Kitchen"], "three tabs")
	panel.show_tab(PantryPanelScript.TAB_RECIPES)
	panel.select_item(OATS)
	var oats: PackedStringArray = panel.cookable_text().split("\n")
	assert_equal(oats[0], "Cookable (active): Wild oat porridge — cooked as the GDD's porridge: 2 scoops of grain (wheat, barley or oats) + 2 jugs of water → 2 portions of 1800 NP, 12 WU, keeps 24 h; for breakfast.", "oats: the porridge")
	assert_true(oats[1].begins_with("Cookable (active): Barleymeal porridge — cooked as the GDD's porridge: 2 scoops of grain (barley or oats)"), "and the barleymeal")
	assert_equal(oats[oats.size() - 1], Words.CHOICE_NOTE, "then how the cook picks")
	panel.select_item(CARROT)
	var carrot: String = panel.cookable_text()
	for dish_name: String in ["Togget's vegetable soup", "Poached perch or trout", "Vole vegetable stew", "Poached dace"]:
		assert_true(carrot.contains("Cookable (active): %s —" % dish_name), "carrot: " + dish_name)
	assert_false(carrot.contains("Wild-beetroot soup"), "not the beetroot soup: it takes beetroot and onion")
	panel.select_item(CABBAGE)
	assert_true(panel.cookable_text().begins_with("Cookable (active): Bean hotpot — cooked as the GDD's bean_hotpot: 2 scoops of beans (pea or broad bean) + 2 bowls of greens or roots (radish, turnip"), "cabbage: the hotpot")
	panel.select_item(Catalog.ITEM_FLOUR)
	assert_true(panel.cookable_text().begins_with("Cookable (active): Haversack hardtack — cooked as a recipe from Rakkety Tam: 2 scoops of flour"),
		"flour: the hardtack, its book named (decision 0603)")
	assert_false(panel.cookable_text().contains("DEC-") or panel.cookable_text().contains("Brendan"),
		"no ruling or person in player text")
	assert_true(panel.cookable_text().contains("Rakkety Tam: 2 scoops of flour + 2 cups of water → 2 portions"),
		"a category named by its one item is said once")
	assert_true(panel.cookable_text().contains("Waiting (needs potato: grown in the fields, not yet planted in the demo): Turnip, potato and beetroot pie"),
		"and the root pie, waiting and said why")
	assert_equal(panel.recipe_heading(), PantryPanelScript.RECIPE_HEADING_COOKING, "the heading says the kitchen's dishes are cookable")
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
	assert_true(rows.has("Oats | 10 scoops · 8 scoops for the kitchen | — | Covered store | all in 24d"), "oats: two breakfasts' reserved")
	assert_true(rows.has("Carrot | 4 baskets · 2 baskets for the kitchen | — | Covered store | all in 10d"), "carrot: two suppers'")
	assert_true(rows.has("Togget's vegetable soup (ready food) | 2 portions | — | Kitchen (pot and table) | spoils in 24 h"), "the portions")
	assert_true(rows.has("Water | 6 jugs | none | Water butt by the well | never spoils"), "the water")


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
	assert_equal(card.reason, "the water butt holds 0 of 2 jugs for the meal (togget's vegetable soup takes 1 jug a batch)", "the reason")
	assert_equal(card.fix, "Pantry (K) ▸ Kitchen ▸ Draw water", "the fix")
	assert_true(card.text().begins_with("Cook supper now\nCan't now: the water butt holds 0 of 2 jugs"), "the card leads with it")
	var d: KitchenScript.Decision = kitchen.decide_meal()
	assert_equal(Words.cant(card.reason, card.fix), Words.cant(d.reason, d.fix), "the same words as the order")
	stores.add_water(10000)
	kitchen.preview_cook_into(card, PackedInt32Array())
	assert_true(card.is_ok(), "allowed with water")
	assert_equal(card.verb, "Cook supper now", "the verb")
	assert_equal(card.result, "2 batches of togget's vegetable soup: 4 portions of 1800 NP", "what it makes")
	assert_equal(card.who, "Queue for the cook: Mouse 0 (the village cook)", "who")
	@warning_ignore("integer_division") assert_equal(card.work_usec, 2 * 200 * CalendarScript.HOUR_USEC / SimClock.TICKS_PER_HOUR, "two batches at the step rate")
	assert_equal(kitchen.order_cook(PackedInt32Array()), "Cook supper now: 2 batches of togget's vegetable soup · Queue for the cook: Mouse 0 (the village cook)", "the order says the same")


func test_the_draw_card_and_a_full_butt() -> void:
	"""Draw water names a carry for the nearest selected; a full butt refuses."""
	var stores := StoresScript.new()
	var kitchen := _kitchen(2, tick_at(1, 14), _pantry(), stores)
	var card := CardScript.new()
	kitchen.preview_draw_into(card, PackedInt32Array([1]))
	assert_true(card.is_ok(), "allowed")
	assert_equal(card.who, "Assign selected: Mouse 1", "the selected")
	assert_true(card.result.begins_with("12 jugs of water into the water butt by the well (it has none of its 4 buckets)"), card.result)
	for brain: RefCounted in kitchen._brains:
		brain.set(&"resting", true)
	kitchen.preview_draw_into(card, PackedInt32Array())
	assert_equal([card.who, card.result.begins_with("Up to 2 buckets of water into the water butt")], ["Queue for anyone free: "
		+ "whoever is nearest the well, when someone is", true], "queued: up to the largest carry, never none")
	stores.add_water(StoresScript.WATER_CAP_MILLI_U)
	kitchen.preview_draw_into(card, PackedInt32Array([1]))
	assert_equal(card.code, KitchenScript.BUTT_FULL, "full")
	assert_true(kitchen.order_draw(PackedInt32Array([1])).begins_with("Can't now: the butt is full"), "the order refuses alike")


# --- the resident ------------------------------------------------------------------------------

func test_the_kitchens_words_name_their_measures() -> void:
	"""Decision 1801: the kitchen's lines word each amount in its good's measure (1011's table) -- a raw meal eaten in
	bunches, the wood a batch burns as a bundle of kindling, the butt's water in buckets and jugs."""
	assert_equal(Words.raw_line("Mouse 0", 2250, CARROT, Rules.MEAL_SUPPER),
		"Mouse 0, hungry with no supper, ate 2 bunches of carrots raw", "a raw meal, floored to whole bunches")
	assert_equal(Words.batch_wood(), "a bundle of kindling", "0.1 U of wood a batch")
	assert_equal(Words.no_fuel_reason(300, 900), "the stores hold 1 of 4 quarter logs for the meal (a bundle of kindling a batch)",
		"the wood short, in the need's measure")
	assert_equal(Words.butt_full_reason(40000, 0), "the butt is full (4 buckets)", "full")
	assert_equal(Words.butt_full_reason(30000, 10000), "the butt will be full: it holds 3 buckets, with 10 jugs on its way",
		"filling")
	assert_equal(Words.draw_ordered(12000, "Mouse 1"), "Draw 12 jugs of water for the kitchen · Mouse 1", "a mouse's 12 kg")


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
	kitchen.fed.ate_meal(0, 8, Rules.DISH_BEAN_HOTPOT, kitchen.hour_index())
	assert_true(kitchen.fed_text(0, true).contains("\nLast meal: breakfast, bean hotpot — a favourite"),
		"a mouse's favourite is noted (decision 0601): " + kitchen.fed_text(0, true))
	kitchen.fed.ate_meal(0, 9, Rules.DISH_SOUP, kitchen.hour_index())
	assert_false(kitchen.fed_text(0, true).contains("a favourite"), "not after a dish it does not like")


# --- the cook rises early -----------------------------------------------------------------------

func test_the_cook_rises_early_only_with_work_and_is_not_sent_back() -> void:
	"""At 05:00 (decision 0421) the cook with today's meals to get cooked is up early (the night's early riser); before
	05:00, or with nothing to do, it is not; another resident never is; at dawn everyone is up."""
	var idle := _kitchen(2, tick_at(1, Rules.COOK_RISE_HOUR), _pantry(), StoresScript.new())
	assert_false(idle.up_early(0), "no food: nothing to do")
	var pantry := _pantry()
	var kitchen := _kitchen(2, tick_at(1, Rules.COOK_RISE_HOUR - 1), pantry, StoresScript.new())
	pantry.add_into(OATS, 10000, 0, _read)
	kitchen.update()
	assert_false(kitchen.up_early(0), "04:00: still asleep")
	kitchen.calendar.tick += SimClock.TICKS_PER_HOUR
	kitchen.update()
	assert_true(kitchen.up_early(0), "05:00, food to fetch: up early")
	assert_false(kitchen.up_early(1), "not the others")
	kitchen.calendar.tick = tick_at(1, 6)
	kitchen.update()
	assert_false(kitchen.up_early(0), "dawn: everyone is up")


func test_the_kitchen_tab_shows_the_dishes_icons_only_when_staged() -> void:
	"""kitchen_tab.gd (decision 0903): no props, or none staged -> no icon row; a dish in the pot with a staged icon by
	its key (`dish_<key>`) -> its icon, once; the Stocks rows' dishes in their order, the water's last."""
	var kitchen := _kitchen(2, 6 * SimClock.TICKS_PER_HOUR, _pantry(), StoresScript.new())
	var tab := TabScript.new()
	_nodes.append(tab)
	tab.configure(kitchen, func() -> PackedInt32Array: return PackedInt32Array(), Callable())
	tab.refresh()
	assert_equal(tab.meal_icons_shown(), 0, "no props: no icons")
	DirAccess.make_dir_recursive_absolute("user://kitchen_icons")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.save_png("user://kitchen_icons/dish_pasty.png")
	var props := preload("res://demo/props/demo_props.gd").new()
	props.load_from({"icons": {"dish_pasty": {"icon": "user://kitchen_icons/dish_pasty.png"}}})
	tab.set_props(props)
	kitchen.store.add(Rules.DISH_KEYS.find(&"pasty"), 2, 0)
	kitchen.store.add(Rules.DISH_KEYS.find(&"scones"), 2, 0)
	tab.refresh()
	assert_equal(tab.meal_icons_shown(), 1, "the pasty's icon; the scones have none staged")
	var dishes: PackedInt32Array = kitchen.stock_row_dishes()
	assert_equal(dishes[dishes.size() - 1], Rules.NO_DISH, "the water's row last")
	assert_equal(dishes.size(), kitchen.stock_rows().size(), "a dish a stock row")
	assert_equal(dishes[0], Rules.DISH_KEYS.find(&"pasty"), "the pasty first, in the book's order")


func test_a_cooked_dish_row_in_the_stocks_carries_its_icon() -> void:
	"""farm_pantry_panel.gd `_fill_kitchen_row` (decision 0903): a dish's Stocks row shows its staged icon by key; the
	water's none."""
	var kitchen := _kitchen(2, 6 * SimClock.TICKS_PER_HOUR, _pantry(), StoresScript.new())
	var panel := _panel(kitchen)
	DirAccess.make_dir_recursive_absolute("user://kitchen_icons")
	Image.create(8, 8, false, Image.FORMAT_RGBA8).save_png("user://kitchen_icons/dish_pasty.png")
	var props := preload("res://demo/props/demo_props.gd").new()
	props.load_from({"icons": {"dish_pasty": {"icon": "user://kitchen_icons/dish_pasty.png"}}})
	panel.set_goods(preload("res://demo/farm/farm_goods.gd").new(props))
	kitchen.store.add(Rules.DISH_KEYS.find(&"pasty"), 2, 0)
	panel.refresh()
	var shown: Array = []
	for icon: TextureRect in panel.get("_stock_icons"):
		if icon.get_parent().visible and icon.texture != null:
			shown.append(icon.texture)
	assert_true(shown.has(props.staged_icon(&"dish_pasty")), "the pasty's row carries its icon")


func test_the_raw_reserve_counts_what_ready_food_does_not_in_days() -> void:
	"""Decision 1736 (P7 (a)): berries 10 U (700 NP) and honey 5 U (1200 NP), free, are 13 000 NP: over nine
	residents' day of portions (18 x 1800 NP) that is 0.401 days; oats and carrots (Ready food's own) and honey set
	aside are not counted; the HUD's figure is worked out once a game hour."""
	var pantry := _pantry()
	var kitchen := _kitchen(9, tick_at(1, 20), pantry, StoresScript.new())
	pantry.add_into(OATS, 20000, 0, _read)
	pantry.add_into(CARROT, 20000, 0, _read)
	pantry.add_into(Catalog.ITEM_BERRIES, 10000, 0, _read)
	pantry.add_into(Catalog.ITEM_HONEY, 6000, 0, _read)
	var take: int = kitchen.takes.new_take()
	assert_true(kitchen.takes.reserve_into(pantry, take, Catalog.CAT_HONEY, 1000, 0, _read), "1 U of honey set aside")
	var reserve := RawReserveScript.new(kitchen)
	var cooked: int = RawReserveScript.cooked_categories()
	for c: int in [Catalog.CAT_FISH, 0, 1, 3, 4]:
		assert_true(cooked & (1 << c) != 0, "Ready food counts category %d" % c)
		assert_false(reserve.categories().has(c), "so the reserve does not")
	assert_equal(reserve.np_total(), 10 * 700 + 5 * 1200, "13 000 NP free")
	assert_equal(reserve.days_milli(), 401, "0.401 days: 13 000 000 / 32 400, floored")
	assert_equal(reserve.hourly_days_milli(), 401, "the HUD's figure")
	pantry.add_into(Catalog.ITEM_BERRIES, 10000, 0, _read)
	assert_equal(reserve.hourly_days_milli(), 401, "the same game hour: not worked out again")
	assert_equal(reserve.days_milli(), 617, "the figure itself moves: 20 000 NP")
	assert_equal(RawReserveScript.new(null).days_milli(), 0, "no kitchen: 0")


func test_the_raw_reserve_restamps_the_food_cell_each_game_hour() -> void:
	"""The HUD's stamp carries the raw reserve, so the food cell and the ledger repaint when it changes -- at the next
	game hour, not before (decision 1736); the food cell is among the stamped cells."""
	var pantry := _pantry()
	var kitchen := _kitchen(9, tick_at(1, 20), pantry, StoresScript.new())
	var model := ModelScript.new()
	model.bind_meals(kitchen)
	var before: int = model.stamp()
	pantry.add_into(Catalog.ITEM_BERRIES, 20000, 0, _read)
	assert_equal(model.stamp(), before, "the same hour: the stamp holds")
	kitchen._hour_seen += 1
	assert_true(model.stamp() != before, "the next hour: the raw reserve restamps")
	assert_true(CountersScript._stamped(ModelScript.CELL_FOOD), "the food cell repaints on a restamp")
	assert_false(CountersScript._stamped(ModelScript.CELL_STONE), "the stone cell does not")
