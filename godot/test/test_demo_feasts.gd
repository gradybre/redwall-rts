extends "res://test/framework/test_case.gd"
## The called feasts (decision 1701; feature #9, review SOC-023): GDD §5.7's three themes for E -- their batches,
## beverage, seats, wood and buffs -- the plan's refusals in order (a keeper who cooks, too few hands, another feast
## within 72 game hours or planned, "needs X" for a course or the beverage, the wood, the seats, REQ-SET-101's reserves
## and their override), holding and cancelling (everything back untouched), every theme cooked, served at the 17:00
## supper (Brendan's ruling on Q-D11), eaten and tallied on real brains, its buff granted once and read by the winter's
## cold and the work pace, the regatta's hooks, and the panel's words.
##
## A hand-made village (as test_demo_kitchen.gd): no scene tree and no staged assets.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const Rules := preload("res://demo/feast/feast_rules.gd")
const FeastScript := preload("res://demo/feast/called_feast.gd")
const MenuScript := preload("res://demo/feast/feast_menu.gd")
const BuffsScript := preload("res://demo/feast/feast_buffs.gd")
const Words := preload("res://demo/feast/feast_text.gd")
const PanelScript := preload("res://demo/feast/feast_panel.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const RegattaScript := preload("res://demo/regatta/regatta.gd")
const RegattaMenuScript := preload("res://demo/regatta/regatta_menu.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ColdScript := preload("res://demo/winter/cold_exposure.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const WorkPaceScript := preload("res://demo/work/work_pace.gd")
const TableDrinkScript := preload("res://demo/kitchen/table_drink.gd")

const DT: float = 1.0 / 30.0
const STORE_AT: Vector2 = Vector2(8.5, 0.5)
const CAULDRON: Vector2 = Vector2(6.0, 0.0)
const TABLE: Vector2 = Vector2(3.0, -3.0)
const WELL: Vector2 = Vector2(0.0, 4.0)
const BUTT: Vector2 = Vector2(1.5, 4.5)
const CARROT: int = 2
const CABBAGE: int = 6
const PEA: int = 11
const WHEAT: int = 13
const TROUT: int = 16
const RESIDENTS: int = 6
## The §5.6 rows the hotpot's greens-or-roots input spans.
const CABBAGE_ROW: int = FarmingScript.CROP_CABBAGE
const ROOTS_ROW: int = FarmingScript.CROP_ROOTS
const DAY: int = 14


## One village: residents in a space, the pantry over a covered store, the stores, the calendar, the kitchen and a
## called feast over them; and what the feast told the news and the people.
class Village extends RefCounted:
	var space: CastSpaceScript = null
	var brains: Array[BrainScript] = []
	var calendar: CalendarScript = CalendarScript.new()
	var pantry: PantryScript = null
	var stores: StoresScript = StoresScript.new()
	var kitchen: KitchenScript = KitchenScript.new()
	var places: PlacesScript = PlacesScript.new()
	var feast: FeastScript = FeastScript.new()
	var posted: PackedStringArray = PackedStringArray()
	var shared: Array = []


var _villages: Array[Village] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Let go of every village (a resident's unfinished kitchen job holds the kitchen; the hooks hold the village)."""
	for v: Village in _villages:
		for brain: BrainScript in v.brains:
			brain.drop_jobs()
		v.feast.post = Callable()
		v.feast.share_feast = Callable()
		v.feast.say = Callable()
	_villages.clear()


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of `day` (day 0 is spring 1; tick 0 is 06:00 of it)."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


func _village(count: int = RESIDENTS, hour: int = 9) -> Village:
	"""A village of `count` residents at the square, the kitchen open over it (resident 0 its cook), wood and water in
	store, at `hour`:00 of DAY; the feast configured over it."""
	var v := Village.new()
	_villages.append(v)
	v.space = CastSpaceScript.new()
	v.space.setup([] as Array[Dictionary], [] as Array[Vector3])
	var names := PackedStringArray()
	var kinds := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in count:
		v.brains.append(_brain(v, i))
		names.append("resident %d" % i)
		kinds.append("mouse")
		keys.append(&"mouse_keeper" if i == 0 else StringName("mouse_%d" % i))
	v.calendar.tick = tick_at(DAY, hour)
	v.pantry = PantryScript.new(StorageScript.new(STORE_AT))
	v.places.set_points(CAULDRON, TABLE, WELL, BUTT)
	v.places.add_table_seats(TABLE, PlacesScript.SEATS_PER_TABLE)
	v.stores.add_wood(20000)
	v.stores.add_water(40000)
	v.kitchen.configure(v.brains, names, kinds, keys, v.pantry, v.stores, v.calendar, v.places)
	v.feast.configure(v.kitchen, v.stores, v.calendar, names)
	v.feast.post = func(text: String, _summary: String) -> void: v.posted.append(text)
	v.feast.share_feast = func(who: PackedInt32Array) -> void: v.shared.append(who)
	return v


func _brain(v: Village, i: int) -> BrainScript:
	"""Resident `i`, standing in a row at the square."""
	var lengths := {}
	for clip: StringName in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(v.space, 1.0, 0.25, 11 + i, lengths)
	brain.start_at(Vector2(-2.0 + 1.2 * float(i), 1.0), 0.0, -1, -1)
	v.space.tunnels.set_body(brain.index, 1024, 256)
	return brain


func _stock(v: Village, item: int, milli: int) -> void:
	"""Put `milli` of `item` in the covered store."""
	assert_true(v.pantry.add_into(item, milli, 0, _read), "stocked")


func _stock_everyday(v: Village) -> void:
	"""Ordinary food for the village's meals around the feast: wheat and carrots, plenty of both."""
	_stock(v, WHEAT, 60000)
	_stock(v, CARROT, 60000)


func _stock_theme(v: Village, theme: int) -> void:
	"""Everything theme `theme` takes for RESIDENTS, with some to spare."""
	match theme:
		Rules.HEARTH:
			_stock(v, PEA, 8000)
			_stock(v, CABBAGE, 8000)
			_stock(v, Catalog.ITEM_FLOUR, 8000)
			_stock(v, Catalog.ITEM_NUTS, 8000)
			_stock(v, Catalog.ITEM_HERB, 1000)
		Rules.HARVEST:
			_stock(v, TROUT, 6000)
			_stock(v, CARROT, 4000)
			_stock(v, Catalog.ITEM_HERB, 1000)
			_stock(v, Catalog.ITEM_FLOUR, 8000)
			_stock(v, Catalog.ITEM_BERRIES, 8000)
			_stock(v, Catalog.ITEM_HONEY, 2000)
			_stock(v, Catalog.ITEM_MEAD, 4000)
			_stock(v, Catalog.ITEM_CIDER, 4000)
			_stock(v, Catalog.ITEM_ALE, 4000)
		Rules.ORCHARD:
			_stock(v, PEA, 8000)
			_stock(v, CARROT, 6000)
			_stock(v, Catalog.ITEM_NUTS, 4000)
			_stock(v, Catalog.ITEM_HERB, 1000)
			_stock(v, Catalog.ITEM_APPLE, 8000)
			_stock(v, Catalog.ITEM_FLOUR, 6000)
			_stock(v, Catalog.ITEM_HONEY, 2000)
			_stock(v, Catalog.ITEM_MEAD, 4000)


func _run(v: Village, until: Callable, frames: int) -> bool:
	"""Step the calendar, every brain, the kitchen and the feast a frame at a time at 1x until `until()` (bounded)."""
	for f: int in frames:
		if bool(until.call()):
			return true
		v.calendar.tick += 1
		for brain: BrainScript in v.brains:
			brain.step(DT)
		v.kitchen.update()
		v.feast.update()
	return bool(until.call())


func _cooked(v: Village, dish: int) -> int:
	"""Batches of `dish` the kitchen has cooked."""
	var n: int = 0
	for each: int in v.kitchen.cooked_dishes:
		n += 1 if each == dish else 0
	return n


# --- the numbers ---------------------------------------------------------------------------------------------------

func test_the_three_themes_are_the_gdds_for_nine() -> void:
	"""§5.7 for E = 9: Hearth 3 hotpot + 3 nut loaf; Harvest ceil(9/6) = 2 feast fish + 3 berry tart + mead ceil(9/4) =
	3 U; Orchard ceil(9/4) = 3 nut roast + 3 crumble + 3 U of mead; the buffs' names, 48 h."""
	assert_equal([Rules.main_batches(Rules.HEARTH, 9), Rules.second_batches(Rules.HEARTH, 9)], [3, 3], "Hearth")
	assert_equal([Rules.main_batches(Rules.HARVEST, 9), Rules.second_batches(Rules.HARVEST, 9)], [2, 3], "Harvest")
	assert_equal([Rules.main_batches(Rules.ORCHARD, 9), Rules.second_batches(Rules.ORCHARD, 9)], [3, 3], "Orchard")
	assert_equal(Rules.mead_milli(9), 3000, "mead ceil(E/4) U")
	assert_equal([Rules.mead_milli(12), Rules.mead_milli(13), Rules.mead_milli(0)], [3000, 4000, 0], "12: 3 U, 13: 4 U")
	for theme: int in Rules.THEME_COUNT:
		assert_equal(Rules.second_batches(theme, 12), 4, "%s: ceil(12/3) second-course batches" % Rules.THEME_NAMES[theme])
	assert_equal([MealRules.DISH_KEYS[Rules.main_dish(Rules.HARVEST)], MealRules.DISH_KEYS[Rules.second_dish(Rules.HARVEST)]],
		[&"feast_fish", &"berry_tart"], "the Harvest courses")
	assert_equal([MealRules.DISH_KEYS[Rules.main_dish(Rules.ORCHARD)], MealRules.DISH_KEYS[Rules.second_dish(Rules.ORCHARD)]],
		[&"nut_roast", &"orchard_crumble"], "the Orchard courses")
	assert_equal(Rules.main_dish(Rules.HEARTH), MealRules.DISH_BEAN_HOTPOT, "the hotpot")
	assert_equal(Rules.second_dish(Rules.HEARTH), MealRules.DISH_NUT_LOAF, "the nut loaf")
	assert_equal(Rules.BUFF_NAMES, ["Shared Warmth", "Abundant Tables", "Rooted Community"] as Array[String], "the buffs")
	assert_equal([Rules.BUFF_HOURS, Rules.WARMTH_COLD_PERMILLE, Rules.TABLES_WORK_PERMILLE], [48, 750, 1050], "48 h, -25%, +5%")
	assert_equal(Rules.dish_of(&"no_such_dish"), MealRules.NO_DISH, "an unknown key is no dish")
	assert_false(Rules.valid_theme(-1) or Rules.valid_theme(Rules.THEME_COUNT), "three themes")


func test_the_orchard_main_course_is_set_amend_001s() -> void:
	"""SET-AMEND-001 §4.2: E = 12 takes 3 nut roast batches (beans 9, roots 6, nuts 3, herb 0.75 U), E = 13 takes 4 --
	never floor(E/4); the roast is §4.1's row exactly."""
	assert_equal([Rules.main_batches(Rules.ORCHARD, 12), Rules.main_batches(Rules.ORCHARD, 13)], [3, 4], "3 and 4")
	var roast: int = Rules.main_dish(Rules.ORCHARD)
	var aside := PackedInt64Array()
	aside.resize(MealRules.CATEGORY_COUNT)
	MenuScript.add_course(aside, roast, 3)
	assert_equal([aside[MealRules.input_category(roast, 0)], aside[MealRules.input_category(roast, 1)],
		aside[MealRules.input_category(roast, 2)], aside[MealRules.input_category(roast, 3)]], [9000, 6000, 3000, 750],
		"beans 9, roots 6, nuts 3, herb 0.75")
	assert_equal([MealRules.PORTIONS_PER_BATCH[roast], MealRules.NP_PER_PORTION[roast], MealRules.WORK_MWU[roast],
		MealRules.SHELF_HOURS[roast], MealRules.WATER_MILLI[roast]], [4, 2400, 30000, 36, 0], "4 x 2400, 30 WU, 36 h, no water")


func test_the_hour_the_day_and_the_interval() -> void:
	"""Q-D11 (Brendan, 2026-10-07: "All at 17:00 supper"): a feast starts at its day's 17:00 supper call; THE DAY: today
	before 15:00, else tomorrow; THE INTERVAL: 72 game hours exactly apart is allowed, an hour less is not."""
	assert_equal(Rules.FEAST_HOUR, 17, "the 17:00 supper, not REQ-SET-103's 18:00")
	assert_equal(Rules.start_tick(DAY), tick_at(DAY, 17), "its supper's call")
	assert_equal(Rules.feast_key(DAY), MealRules.meal_key(DAY, MealRules.MEAL_SUPPER), "the kitchen's supper key")
	assert_equal([Rules.first_day(DAY, 14), Rules.first_day(DAY, 15)], [DAY, DAY + 1], "15:00 the cut")
	var a: int = Rules.start_tick(DAY)
	assert_false(Rules.too_close(a, a + 72 * SimClock.TICKS_PER_HOUR), "72 h apart: allowed")
	assert_true(Rules.too_close(a, a + 72 * SimClock.TICKS_PER_HOUR - 1), "a tick less: not")
	assert_true(Rules.too_close(a + 71 * SimClock.TICKS_PER_HOUR, a), "either way round")
	assert_equal([Rules.waves(9, 12), Rules.waves(9, 3), Rules.waves(30, 5), Rules.waves(0, 5), Rules.waves(5, 0)],
		[1, 3, 3, 0, 0], "seatings: one a seat's worth, at most three")
	assert_equal(Rules.buff_until(1000), 1000 + 48 * SimClock.TICKS_PER_HOUR, "48 h")


func test_no_theme_takes_one_category_twice() -> void:
	"""A theme's courses and beverage never share an input category, so each is checked and reserved on its own."""
	for theme: int in Rules.THEME_COUNT:
		var seen: Dictionary = {}
		for second: bool in [false, true]:
			var dish: int = MenuScript.course_dish(theme, second)
			for k: int in MealRules.INPUT_N[dish]:
				assert_false(seen.has(MealRules.input_category(dish, k)), "%s: one use of each category" % Rules.THEME_NAMES[theme])
				seen[MealRules.input_category(dish, k)] = true
		assert_false(seen.has(MenuScript.bev_selector(theme)), "%s: the beverage's own" % Rules.THEME_NAMES[theme])


# --- the plan ------------------------------------------------------------------------------------------------------

func test_each_theme_says_what_it_needs() -> void:
	"""An empty pantry: every theme names its first missing input and where it comes from (REQ-SET-099); stocked, the
	theme is ready; mead alone missing names the brewery."""
	var v: Village = _village()
	for theme: int in Rules.THEME_COUNT:
		assert_true(Words.theme_ready_words(v.feast, theme).contains("needs"), "%s needs" % Rules.THEME_NAMES[theme])
	_stock_theme(v, Rules.HARVEST)
	assert_equal(v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS).size(), 0, "Harvest stocked")
	assert_true(Words.theme_ready_words(v.feast, Rules.HARVEST).contains("every course can be made"), "ready")
	var mead: int = v.feast.menu.free_of(Catalog.CAT_MEAD)
	var take: int = v.kitchen.takes.new_take()
	v.kitchen.takes.reserve_into(v.pantry, take, Catalog.CAT_MEAD, mead, 0, _read)
	var short: PackedStringArray = v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS)
	assert_equal(short.size(), 1, "only the mead")
	assert_true(short[0].begins_with("needs mead: 2.0 U (0.0 U free)") and short[0].contains("brewery"), short[0])
	assert_equal(v.feast.refusal(Rules.HARVEST, DAY, 1, true), short[0], "the plan refused with it")
	assert_equal(v.feast.refused_code, "NEEDS", "its code")
	v.kitchen.takes.release(take)
	v.kitchen.takes.reserve_into(v.pantry, take, Catalog.CAT_MEAD, mead - 1999, 0, _read)
	assert_equal(v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS).size(), 1, "1.999 U of mead free: short")
	v.kitchen.takes.release(take)
	v.kitchen.takes.reserve_into(v.pantry, take, Catalog.CAT_MEAD, mead - 2000, 0, _read)
	assert_equal(v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS).size(), 0, "2.0 U free: enough")
	var berries: int = v.feast.menu.free_of(Catalog.CAT_BERRIES)
	var tart: int = v.kitchen.takes.new_take()
	v.kitchen.takes.reserve_into(v.pantry, tart, Catalog.CAT_BERRIES, berries - 3999, 0, _read)
	assert_true(v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS)[0].begins_with("needs berries: 4.0 U (3.99 U free)"),
		"a course's input a part short")
	v.kitchen.takes.release(tart)
	_stock_theme(v, Rules.HEARTH)
	v.stores.take_water(v.stores.water_milli_u - 1999)
	var dry: PackedStringArray = v.feast.menu.shortfalls(Rules.HEARTH, RESIDENTS)
	assert_equal(dry.size(), 1, "the infusion's water alone short")
	assert_true(dry[0].begins_with("needs water in the butt: 2.0 U (1.99 U there)"), dry[0])


func test_the_plan_is_refused_in_order() -> void:
	"""A keeper who cooks, a day not offered, too few hands, the wood, the seats, the reserves (and their override)."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	assert_equal(v.feast.cook(), 0, "resident 0 cooks")
	v.feast.refusal(Rules.HEARTH, DAY, 0, true)
	assert_equal(v.feast.refused_code, "HOST_COOKS", "the cook cannot keep it")
	v.feast.refusal(Rules.HEARTH, DAY + Rules.DAY_CHOICES, 1, true)
	assert_equal(v.feast.refused_code, "NO_DAY", "too far ahead")
	v.feast.refusal(Rules.HEARTH, DAY - 1, 1, true)
	assert_equal(v.feast.refused_code, "NO_DAY", "past")
	v.feast.refusal(-1, DAY, 1, true)
	assert_equal(v.feast.refused_code, "NO_THEME", "no theme")
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY, 1, true), "", "otherwise it may be held (overridden)")
	v.stores.take_wood(v.stores.wood_milli_u)
	v.feast.refusal(Rules.HEARTH, DAY, 1, true)
	assert_equal(v.feast.refused_code, "NO_WOOD", "no service wood")
	var two: Village = _village(2)
	two.feast.refusal(Rules.HEARTH, DAY, 1, true)
	assert_equal(two.feast.refused_code, "STAFF", "2 cooks + 1 keeper")


func test_the_seats_come_from_the_hall_when_bound() -> void:
	"""Seats >= ceil(E/3): the hall's gathering seats when bound, else the kitchen's."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	assert_equal(v.feast.seats_now(), PlacesScript.SEATS_PER_TABLE, "the kitchen's seats")
	v.feast.seats = func() -> int: return 1
	v.feast.refusal(Rules.HEARTH, DAY, 1, true)
	assert_equal(v.feast.refused_code, "NO_SEATS", "a hall of one seat cannot sit 6 in 3 seatings")
	v.feast.seats = func() -> int: return 2
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY, 1, true), "", "two seats: three seatings")
	v.feast.seats = Callable()


func test_the_reserves_are_refused_truthfully_and_may_be_overridden() -> void:
	"""REQ-SET-101: with only the feast's food in store, ready food after it is under 3 days -- refused, naming both
	figures; the player's override for this feast holds it. The figure leaves the reservation out."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	var after: int = v.feast.food_days_after_milli(Rules.HEARTH, RESIDENTS)
	assert_true(after < v.kitchen.days_of_meals_milli(), "the hotpot's beans and greens are not food-days after it")
	assert_true(v.feast.refusal(Rules.HEARTH, DAY, 1, false).contains("days of ready food"), "refused")
	assert_equal(v.feast.refused_code, "RESERVES", "REQ-SET-101")
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY, 1, true), "", "overridden")
	_stock_everyday(v)
	v.stores.add_wood(100000)
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY, 1, false), "", "with food and wood to spare, no override needed")
	var fuel := FuelScript.new()
	fuel.set_hearth(0, true)
	fuel.day_rate_milli = 4000
	v.feast.fuel = fuel
	v.stores.take_wood(v.stores.wood_milli_u - 3000)
	assert_true(v.feast.refusal(Rules.HEARTH, DAY, 1, false).contains("days of fuel"), "too little wood for 3 fuel-days")
	assert_equal(v.feast.refused_code, "RESERVES", "REQ-SET-101's fuel half")
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY, 1, true), "", "overridden")


func test_fuel_days_after_are_the_winters() -> void:
	"""§5.8's fuel-days after the feast: the wood left over the hearths' heating demand plus the cooking mean; before a
	day of cooking is kept, the kitchen's batches (0.1 U for every two portions)."""
	var v: Village = _village()
	var cooking: int = RegattaRules.ceil_div(v.kitchen.daily_portions(), 2) * MealRules.WOOD_MILLI_PER_BATCH
	@warning_ignore("integer_division") var kitchen_days: int = 6000 * 1000 / cooking
	assert_equal(v.feast.fuel_days_after_milli(6000), kitchen_days, "6 U over the day's batches at 0.1 U each")
	assert_equal(kitchen_days, 6666, "six residents at a portion and a half, two meals: 18 portions, 9 batches, 0.9 U a day")
	assert_equal(v.feast.fuel_days_after_milli(-50), 0, "none left")
	var fuel := FuelScript.new()
	v.feast.fuel = fuel
	assert_equal(v.feast.fuel_days_after_milli(6000), kitchen_days, "no hearth burning, no cooking kept: the kitchen's")
	fuel.set_hearth(0, true)
	fuel.day_rate_milli = 4000
	assert_equal(fuel.heating_day_milli(), 4000, "a hearth burning 4 U a day")
	@warning_ignore("integer_division") var heated_days: int = 6000 * 1000 / (4000 + cooking)
	assert_equal(v.feast.fuel_days_after_milli(6000), heated_days, "6 U over 4 U of heat and the day's cooking")
	assert_equal(heated_days, 1224, "6 U over 4.9 U a day")
	assert_equal(v.feast.wood_after_milli(Rules.HEARTH, RESIDENTS), v.stores.wood_milli_u - 1000 - 4 * 100,
		"the service and 4 batches")


func test_holding_reserves_everything_and_cancelling_gives_it_back() -> void:
	"""Held (REQ-SET-102): both courses' food in the feast's take, the mead in its own, the service wood set aside, the
	kitchen's occasion its courses; cancelled before the supper: every unit back, untouched."""
	var v: Village = _village()
	_stock_theme(v, Rules.HARVEST)
	var wood: int = v.stores.wood_milli_u
	var after: int = v.feast.wood_after_milli(Rules.HARVEST, RESIDENTS)
	assert_equal(v.feast.hold(Rules.HARVEST, DAY + 1, 2, true), "", "held")
	assert_equal(v.feast.wood_after_milli(Rules.HARVEST, RESIDENTS), after, "held, its service wood is not taken twice")
	assert_equal(v.feast.state, FeastScript.ST_PREPARING, "preparing")
	assert_equal(v.feast.menu.free_of(Catalog.CAT_FISH), 6000 - 4000, "one feast fish's fish")
	assert_equal(v.feast.menu.free_of(Catalog.CAT_BERRIES), 8000 - 4000, "two tarts' berries")
	assert_equal(v.feast.menu.free_of(Catalog.CAT_MEAD), 4000 - 2000, "ceil(6/4) U of mead")
	assert_equal(v.feast.menu.extras_planned, PackedInt64Array([2000]), "the cider held too")
	assert_equal(v.feast.menu.free_of(MenuScript.extra_selector(0)), 4000 - 2000, "ceil(6/4) U of cider")
	assert_equal(v.stores.wood_milli_u, wood - 1000, "ceil(6/12) U of service wood")
	assert_equal([v.kitchen.occasion_dish, v.kitchen.occasion_batches, v.kitchen.occasion_second,
		v.kitchen.occasion_second_batches], [Rules.main_dish(Rules.HARVEST), 1, Rules.second_dish(Rules.HARVEST), 2],
		"the kitchen's occasion")
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY + 2, 2, true), "the Harvest feast is preparing already", "one at a time")
	assert_equal([v.feast.menu.water_held_milli, v.feast.menu.bev_planned_milli], [0, 2000], "mead, no infusion water")
	var aside := PackedInt64Array()
	v.feast.menu.set_aside(Rules.HARVEST, RESIDENTS, aside)
	assert_equal([aside[Catalog.CAT_FISH], aside[Catalog.CAT_BERRIES], aside[Catalog.CAT_MEAD]], [4000, 4000, 2000],
		"the reservation by category, the mead included")
	var take: int = v.feast.take
	assert_equal(v.kitchen.takes.live_milli(v.pantry, take), 4000 + 2000 + 500 + 4000 + 4000 + 1000, "both courses' food in its take")
	assert_equal(v.feast.cancel(), "", "cancelled")
	assert_equal(v.kitchen.takes.live_milli(v.pantry, take), 0, "its take let go (the kitchen's own supper may plan the fish)")
	assert_equal([v.feast.menu.free_of(Catalog.CAT_BERRIES), v.feast.menu.free_of(Catalog.CAT_MEAD), v.stores.wood_milli_u],
		[8000, 4000, wood], "the berries, the mead and the wood back")
	assert_equal(v.feast.menu.free_of(MenuScript.extra_selector(0)), 4000, "the cider back")
	assert_equal(v.kitchen.occasion_key, KitchenScript.FREE, "no occasion")
	assert_equal(v.feast.cancel(), "no feast is planned", "nothing left to cancel")


# --- the feast on its day --------------------------------------------------------------------------------------------

func _feast_day(theme: int) -> Village:
	"""Theme `theme` held for DAY's supper at 09:00 and run until it is tallied."""
	var v: Village = _village()
	_stock_everyday(v)
	_stock_theme(v, theme)
	assert_equal(v.feast.hold(theme, DAY, 1, true), "", "held")
	var feast: FeastScript = v.feast
	assert_true(_run(v, func() -> bool: return feast.state == FeastScript.ST_IDLE, 30000),
		"tallied (%s)" % Words.status_line(feast))
	return v


func test_a_hearth_feast_is_cooked_eaten_and_warms_the_village() -> void:
	"""The 17:00 supper: 2 hotpot and 2 nut loaf from the reserved food, one portion of each a guest, the infusion poured
	for those who came, Shared Warmth (80% at every course) read by the cold; the company shared; one chronicle line;
	a completed feast whose start bars another within 72 h."""
	var v: Village = _feast_day(Rules.HEARTH)
	var f: FeastScript = v.feast
	assert_equal([_cooked(v, MealRules.DISH_BEAN_HOTPOT), _cooked(v, MealRules.DISH_NUT_LOAF)], [2, 2], "2 and 2 batches")
	assert_true(Rules.covered(f.every_course, RESIDENTS), "80%% ate every course (%d)" % f.every_course)
	assert_equal(v.pantry.milli_of(Catalog.ITEM_NUTS), 8000 - 4000, "the loaves' nuts, no more")
	@warning_ignore("integer_division") var herb: int = 250 * f.attendees.size() / RESIDENTS
	assert_equal(v.pantry.milli_of(Catalog.ITEM_HERB), 1000 - herb, "the infusion's herb for those who came")
	assert_true(f.buffs.active(Rules.HEARTH, f.now_tick()), "Shared Warmth: %s" % f.last_line)
	assert_equal(f.buffs.cold_permille(f.now_tick()), 750, "cold exposure -25%")
	assert_equal(f.wood_burnt_milli, 1000, "the service wood burnt")
	assert_equal([f.completed, f.starts.size(), v.posted.size(), v.shared.size()], [1, 1, 1, 1], "completed and remembered")
	assert_true(v.posted[0].contains("Hearth feast") and v.posted[0].contains("Shared Warmth"), v.posted[0])
	assert_equal(f.starts[0], Rules.start_tick(DAY), "its start latched at the supper")
	assert_equal(f.today(), DAY, "tallied the evening of its day")
	@warning_ignore("integer_division") var water: int = 2000 * f.attendees.size() / RESIDENTS
	assert_equal(f.menu.water_used_milli, water, "the infusion's water for those who came")
	assert_true(f.clash(DAY + 2).contains("at most one feast in any 72 game hours"), "two days later: refused")
	assert_equal(f.clash(DAY + 3), "", "three days later: allowed")
	assert_equal([v.kitchen.occasion_key, f.take, f.menu.bev_take], [KitchenScript.FREE, 0, 0], "the occasion and takes let go")
	_stock_theme(v, Rules.HEARTH)
	f.refusal(Rules.HEARTH, f.day_choices()[0], 1, true)
	assert_equal(f.refused_code, "INTERVAL", "the plan refused within the interval")
	assert_true(f.hold(Rules.HEARTH, f.day_choices()[0], 1, true).contains("72 game hours"), "and not held")
	assert_equal(f.state, FeastScript.ST_IDLE, "nothing planned")


func test_a_harvest_feast_pours_mead_and_quickens_the_work() -> void:
	"""Feast fish then berry tart; mead poured proportionally to attended/E; Abundant Tables' +5% on the work pace."""
	var v: Village = _feast_day(Rules.HARVEST)
	var f: FeastScript = v.feast
	assert_equal([_cooked(v, Rules.main_dish(Rules.HARVEST)), _cooked(v, Rules.second_dish(Rules.HARVEST))], [1, 2], "1 and 2")
	@warning_ignore("integer_division") var mead: int = 2000 * f.attendees.size() / RESIDENTS
	assert_equal(v.pantry.milli_of(Catalog.ITEM_MEAD), 4000 - mead, "mead for those who came, the rest back")
	assert_equal(f.menu.bev_used_milli, mead, "poured")
	assert_equal(v.pantry.milli_of(Catalog.ITEM_CIDER), 4000 - mead, "the cider poured as the mead is (the mead rule)")
	assert_equal(v.pantry.milli_of(Catalog.ITEM_ALE), 4000, "ale is not poured (Brendan's ruling: mead and cider)")
	assert_equal(f.menu.extras_poured_milli, PackedInt64Array([mead]), "the cider's tally")
	assert_equal(f.menu.extra_take, 0, "their take let go")
	assert_true(f.buffs.active(Rules.HARVEST, f.now_tick()), "Abundant Tables: %s" % f.last_line)
	var pace := WorkPaceScript.new()
	pace.add_factor("feast", f.buffs.work_permille)
	assert_equal(pace.permille(3), 1050, "work +5%")
	assert_equal(f.buffs.cold_permille(f.now_tick()), 1000, "no warmth from a Harvest feast")


func test_an_orchard_feast_cooks_its_waterless_courses() -> void:
	"""The nut roast and the crumble take no water (§5.7): cooked with none drawn for them; Rooted Community granted."""
	var v: Village = _feast_day(Rules.ORCHARD)
	var f: FeastScript = v.feast
	assert_equal([_cooked(v, Rules.main_dish(Rules.ORCHARD)), _cooked(v, Rules.second_dish(Rules.ORCHARD))], [2, 2], "2 and 2")
	assert_true(f.buffs.active(Rules.ORCHARD, f.now_tick()), "Rooted Community: %s" % f.last_line)
	assert_equal(v.pantry.milli_of(Catalog.ITEM_APPLE), 8000 - 6000, "two crumbles' fruit")


func test_a_feast_nobody_ate_is_not_completed() -> void:
	"""A supper the kitchen ran past (a skip over it): tallied with nobody, its food and wood given back, no buff, not
	completed, and it starts no interval."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	var wood: int = v.stores.wood_milli_u
	assert_equal(v.feast.hold(Rules.HEARTH, DAY + 1, 1, true), "", "held")
	v.calendar.tick = tick_at(DAY + 3, 9)
	v.kitchen.update()
	v.feast.update()
	assert_equal(v.feast.state, FeastScript.ST_IDLE, "tallied")
	assert_equal([v.feast.completed, v.feast.starts.size()], [0, 0], "not completed")
	assert_true(v.feast.last_line.contains("nobody came"), v.feast.last_line)
	assert_equal(v.stores.wood_milli_u, wood, "its service wood back")
	assert_equal(v.feast.menu.free_of(Catalog.CAT_HERB), 1000, "its herb back")


func test_the_supper_call_serves_it_and_it_can_no_longer_be_cancelled() -> void:
	"""At the 17:00 call the feast is ACTIVE (REQ-SET-103 at Brendan's 17:00): its wood burns and it cannot be cancelled."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	v.calendar.tick = tick_at(DAY, 17) - 1
	v.feast.update()
	assert_equal(v.feast.state, FeastScript.ST_PREPARING, "16:59: preparing")
	v.calendar.tick = tick_at(DAY, 17)
	v.feast.update()
	assert_equal(v.feast.state, FeastScript.ST_ACTIVE, "17:00: served")
	assert_equal(v.feast.wood_burnt_milli, 1000, "its wood burns")
	assert_equal(v.feast.cancel(), "the feast is being served", "too late to cancel")


func test_the_tally_counts_every_course_and_the_buff_needs_all_of_it() -> void:
	"""Of the supper's diners, those who ate the main course attended; only those who ate both ate every course; under
	80% at every course, or a beverage not all there, no buff."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	var both: int = KitchenScript.COURSE_MAIN | KitchenScript.COURSE_SECOND
	for i: int in RESIDENTS:
		v.kitchen._occasion_courses[i] = both if i < 4 else (KitchenScript.COURSE_MAIN if i == 4 else KitchenScript.COURSE_SECOND)
	var final := KitchenScript.MealFinal.new()
	final.diners = PackedInt32Array([0, 1, 2, 3, 4, 5])
	v.feast._count(final)
	assert_equal(v.feast.attendees, PackedInt32Array([0, 1, 2, 3, 4]), "five ate the main course")
	assert_equal(v.feast.every_course, 4, "four ate both")
	assert_true(v.feast._buff_words(true).contains("4 of 6 ate every course"), v.feast._buff_words(true))
	v.kitchen._occasion_courses[4] = both
	v.feast._count(final)
	assert_true(v.feast._buff_words(false).contains("was not all there to pour"), v.feast._buff_words(false))
	assert_true(v.feast._buff_words(true).begins_with("Shared Warmth for 48 h"), "5 of 6: granted")


func test_a_beverage_partly_gone_is_poured_as_far_as_it_goes() -> void:
	"""Mead taken from its lot after the feast was held: the pour is trimmed to what is there, and is not whole."""
	var v: Village = _village()
	_stock_theme(v, Rules.HARVEST)
	assert_equal(v.feast.hold(Rules.HARVEST, DAY, 1, true), "", "held")
	for lot: int in PantryScript.MAX_LOTS:
		if v.pantry.lot_serial(lot) != 0 and v.pantry.lot_item(lot) == Catalog.ITEM_MEAD:
			assert_true(v.pantry.withdraw_into(lot, v.pantry.lot_serial(lot), 3000, _read), "most of the mead taken")
	assert_false(v.feast.menu.pour(Rules.HARVEST, RESIDENTS, RESIDENTS, 0), "not all poured")
	assert_equal(v.feast.menu.bev_used_milli, 1000, "the 1.0 U still there poured")
	assert_equal(v.feast.menu.bev_take, 0, "its take let go")
	assert_false(v.feast.menu.pour(Rules.HARVEST, RESIDENTS, 0, 0), "nobody came: nothing poured")


func test_a_feast_the_kitchen_has_not_planned_yet_is_given_back_whole() -> void:
	"""Held for the last supper offered, beyond the kitchen's plans: cancelled, its take is let go by the feast itself."""
	var v: Village = _village()
	_stock_theme(v, Rules.HARVEST)
	v.kitchen.update()
	var day: int = v.feast.day_choices()[Rules.DAY_CHOICES - 1]
	assert_equal(v.feast.hold(Rules.HARVEST, day, 1, true), "", "held")
	assert_false(v.kitchen.occasion_adopted(), "not yet in the kitchen's plans")
	assert_equal(v.feast.cancel(), "", "cancelled")
	assert_equal([v.feast.menu.free_of(Catalog.CAT_FISH), v.feast.menu.free_of(Catalog.CAT_BERRIES)], [6000, 8000], "all back")


func test_a_supper_the_kitchen_never_served_lapses_with_nobody() -> void:
	"""A feast whose supper the kitchen ran past long ago (a long skip: its meal event has left the kitchen's log before
	the feast looks): tallied by the lapse, with nobody, everything given back."""
	var v: Village = _village()
	_stock_theme(v, Rules.HARVEST)
	var day: int = v.feast.day_choices()[Rules.DAY_CHOICES - 1]
	var wood: int = v.stores.wood_milli_u
	assert_equal(v.feast.hold(Rules.HARVEST, day, 1, true), "", "held")
	v.calendar.tick = tick_at(day + KitchenScript.MAX_MEAL_LOG, 9)
	v.kitchen.update()
	assert_true(v.kitchen.final_of(Rules.feast_key(day)) == null, "its event gone from the log")
	assert_true(v.kitchen.meal_lapsed(Rules.feast_key(day)), "lapsed")
	v.feast.update()
	assert_equal(v.feast.state, FeastScript.ST_IDLE, "tallied by the lapse")
	assert_true(v.feast.last_line.contains("nobody came"), v.feast.last_line)
	assert_equal([v.stores.wood_milli_u, v.feast.menu.free_of(Catalog.CAT_MEAD)], [wood, 4000], "wood and mead back")


func test_a_feast_the_kitchen_is_cooking_cannot_be_cancelled() -> void:
	"""REQ-SET-102's release is "before the serving event"; once the kitchen starts cooking it (15:00 on its day) its
	batches are under way, so the feast is no longer cancelled."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	v.calendar.tick = tick_at(DAY, 15) - 1
	assert_equal(v.feast.cancel_refusal(), "", "14:59: it may be cancelled")
	v.calendar.tick = tick_at(DAY, 15)
	assert_equal(v.feast.cancel(), "the kitchen is cooking it", "15:00: no longer")
	assert_equal(v.feast.state, FeastScript.ST_PREPARING, "still preparing")


func test_the_other_drinks_are_poured_for_those_who_came() -> void:
	"""Half the village at a Harvest feast: half its cider poured (floor), the rest given back with the take; a cider
	short of ceil(E/4) is not held at all."""
	var v: Village = _village()
	_stock_theme(v, Rules.HARVEST)
	assert_equal(v.feast.hold(Rules.HARVEST, DAY, 1, true), "", "held")
	assert_true(v.feast.menu.pour(Rules.HARVEST, RESIDENTS, 3, 0), "the mead poured for three")
	assert_equal(v.feast.menu.extras_poured_milli, PackedInt64Array([1000]), "1.0 U of the 2.0 U of cider")
	assert_equal(v.pantry.milli_of(Catalog.ITEM_CIDER), 3000, "the rest back in store")
	assert_equal(v.feast.menu.free_of(MenuScript.extra_selector(0)), 3000, "and free")
	var short: Village = _village()
	_stock_theme(short, Rules.ORCHARD)
	_stock(short, Catalog.ITEM_CIDER, 1999)
	assert_equal(short.feast.hold(Rules.ORCHARD, DAY, 1, true), "", "held")
	assert_equal(short.feast.menu.extras_planned, PackedInt64Array([0]), "1.999 U of cider: not poured")
	assert_true(short.feast.menu.extras_words(Rules.ORCHARD, RESIDENTS).contains("not poured"), "said so")


func test_a_feast_counts_the_food_its_own_supper_already_holds() -> void:
	"""Brendan's ruling on 1701 P6 (b): today's supper planned as a hotpot holds every bean and green there is; a Hearth
	feast called for that supper counts them (the feast replaces that meal), is held, and the kitchen cooks its courses
	from them -- while a feast for another supper, or with a batch already cooked, does not count them."""
	var v: Village = _village()
	_stock(v, PEA, 4000)
	_stock(v, CABBAGE, 4000)
	_stock(v, Catalog.ITEM_FLOUR, 60000)
	_stock(v, Catalog.ITEM_NUTS, 20000)
	_stock(v, Catalog.ITEM_HERB, 1000)
	v.calendar.tick = tick_at(DAY, 10)
	v.kitchen.update()
	var key: int = Rules.feast_key(DAY)
	var beans: int = MealRules.input_selector(MealRules.DISH_BEAN_HOTPOT, 0)
	assert_equal(v.kitchen.held_for_meal_milli(key, beans), 4000, "today's supper holds the beans")
	assert_equal(v.feast.menu.free_of(beans), 0, "none of them free")
	assert_false(v.feast.menu.shortfalls(Rules.HEARTH, RESIDENTS).is_empty(), "free food alone: short")
	assert_true(v.feast.menu.shortfalls(Rules.HEARTH, RESIDENTS, Rules.feast_key(DAY + 1)).size() > 0, "another supper: short")
	assert_equal(v.feast.menu.shortfalls(Rules.HEARTH, RESIDENTS, key), PackedStringArray(), "its own supper's food counted")
	v.feast.choice_day = DAY
	assert_true(Words.theme_ready_words(v.feast, Rules.HEARTH).contains("every course can be made"), "the themes say so")
	assert_true("\n".join(Words.preview_lines(v.feast, Rules.HEARTH, DAY, 1)).contains("beans 4.0 U (free 4.0 U)"),
		"the plan counts them")
	assert_true("\n".join(Words.preview_lines(v.feast, Rules.HEARTH, DAY + 1, 1)).contains("beans 4.0 U (free 0.0 U)"),
		"a plan for another supper does not")
	assert_equal(v.feast.refusal(Rules.HEARTH, DAY + 1, 1, true), "needs beans: 4.0 U (0.0 U free) — the fields (Farm ▸ the planner) (and 1 more: see The themes)",
		"tomorrow's feast may not count today's supper")
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	assert_true(v.kitchen.occasion_adopted(), "the supper is the feast's now")
	assert_equal(v.kitchen.held_for_meal_milli(key, beans), 0, "an occasion's meal is not counted again")
	var f: FeastScript = v.feast
	assert_true(_run(v, func() -> bool: return f.state == FeastScript.ST_IDLE, 30000), "tallied (%s)" % Words.status_line(f))
	assert_equal(_cooked(v, MealRules.DISH_BEAN_HOTPOT), 2, "both hotpot batches cooked from the supper's beans")
	assert_true(Rules.covered(f.every_course, RESIDENTS), "and eaten: %s" % f.last_line)


func test_a_supper_planned_as_another_dish_lends_its_food_too() -> void:
	"""Today's supper planned as a fish stew holds the fish and roots; a Harvest feast for it counts them, is held and
	cooked from them (the kitchen tops the feast fish up at adoption)."""
	var v: Village = _village()
	_stock(v, TROUT, 4000)
	_stock(v, CARROT, 4000)
	for item: int in [Catalog.ITEM_FLOUR, Catalog.ITEM_BERRIES]:
		_stock(v, item, 60000)
	_stock(v, Catalog.ITEM_HERB, 1000)
	_stock(v, Catalog.ITEM_HONEY, 2000)
	_stock(v, Catalog.ITEM_MEAD, 4000)
	v.calendar.tick = tick_at(DAY, 10)
	v.kitchen.update()
	var key: int = Rules.feast_key(DAY)
	assert_equal(v.kitchen.held_for_meal_milli(key, Catalog.CAT_FISH), 4000, "the supper's fish stew holds the fish")
	assert_equal(v.feast.menu.shortfalls(Rules.HARVEST, RESIDENTS, key), PackedStringArray(), "counted")
	assert_equal(v.feast.hold(Rules.HARVEST, DAY, 1, true), "", "held")
	var f: FeastScript = v.feast
	assert_true(_run(v, func() -> bool: return f.state == FeastScript.ST_IDLE, 30000), "tallied (%s)" % Words.status_line(f))
	assert_equal(_cooked(v, Rules.main_dish(Rules.HARVEST)), 1, "the feast fish cooked from the stew's fish")
	assert_true(f.attendees.size() > 0, f.last_line)


func test_a_supper_with_a_batch_cooked_lends_the_feast_nothing() -> void:
	"""The hook gives 0 for a meal not planned, nothing for no supper named, and 0 once a batch of the meal is cooked."""
	var v: Village = _village()
	_stock(v, PEA, 4000)
	_stock(v, CABBAGE, 4000)
	v.calendar.tick = tick_at(DAY, 10)
	v.kitchen.update()
	var beans: int = MealRules.input_selector(MealRules.DISH_BEAN_HOTPOT, 0)
	assert_equal(v.kitchen.held_for_meal_milli(Rules.feast_key(DAY + 9), beans), 0, "a meal not planned")
	assert_equal(v.feast.menu.available_of(beans, MenuScript.NO_KEY), 0, "no supper named: the free food alone")
	assert_equal(v.feast.menu.available_of(beans, Rules.feast_key(DAY)), 4000, "the supper's own")
	var regatta_menu := RegattaMenuScript.new()
	regatta_menu.configure(v.kitchen, v.stores)
	assert_equal(regatta_menu._course_free(beans), 0, "the regatta's menu: free food alone, no supper named")
	regatta_menu.supper_key = Rules.feast_key(DAY)
	assert_equal(regatta_menu._course_free(beans), 4000, "with its supper named, a course counts that supper's food")
	assert_equal(regatta_menu._free(beans), 0, "the herb and the drinks count free food alone")
	var key: int = Rules.feast_key(DAY)
	assert_true(_run(v, func() -> bool: return v.kitchen._wip_key == key, 30000), "today's supper at the cauldron")
	assert_equal(v.kitchen.batches_cooked, 0, "nothing cooked yet")
	assert_equal(v.kitchen.held_for_meal_milli(key, beans), 0, "a batch at the cauldron: 0")
	assert_true(_run(v, func() -> bool: return v.kitchen.batches_cooked > 0, 30000), "a batch of today's supper cooked")
	assert_equal(v.kitchen.held_for_meal_milli(Rules.feast_key(DAY), beans), 0, "nothing cooked is undone: 0")


func test_the_regattas_second_course_counts_the_suppers_flour() -> void:
	"""With only flour and nuts in store the supper is planned from them (the other meal's dish: scones or hardtack) and
	holds flour; the regatta's menu, naming that supper, counts it for its nut loaf (a course the kitchen tops up), and
	not without it."""
	var v: Village = _village()
	_stock(v, Catalog.ITEM_FLOUR, 6000)
	_stock(v, Catalog.ITEM_NUTS, 6000)
	v.calendar.tick = tick_at(DAY, 10)
	v.kitchen.update()
	var key: int = Rules.feast_key(DAY)
	var held: int = v.kitchen.held_for_meal_milli(key, Catalog.CAT_FLOUR)
	assert_true(held > 0, "the supper holds flour (%d)" % held)
	var regatta_menu := RegattaMenuScript.new()
	regatta_menu.configure(v.kitchen, v.stores)
	var free: int = regatta_menu.free_flour()
	regatta_menu.supper_key = key
	assert_equal(regatta_menu.free_flour(), free + held, "the nut loaf's flour counts the supper's")


func test_the_hotpot_takes_roots_when_there_are_no_greens() -> void:
	"""Decision 1735: the hotpot's second input is greens or roots, so a Hearth feast's main course is made from beans
	and carrots alone -- checked, held and cooked."""
	var v: Village = _village()
	_stock(v, PEA, 8000)
	_stock(v, CARROT, 8000)
	_stock(v, Catalog.ITEM_FLOUR, 60000)
	_stock(v, Catalog.ITEM_NUTS, 8000)
	_stock(v, Catalog.ITEM_HERB, 1000)
	var hotpot: int = MealRules.DISH_BEAN_HOTPOT
	assert_equal(MenuScript.input_word(hotpot, 1), "greens or roots", "the book's words")
	for line: String in v.feast.menu.shortfalls(Rules.HEARTH, RESIDENTS):
		assert_false(line.contains("greens"), "roots satisfy it: %s" % line)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	var f: FeastScript = v.feast
	assert_true(_run(v, func() -> bool: return f.state == FeastScript.ST_IDLE, 30000), "tallied (%s)" % Words.status_line(f))
	assert_equal(_cooked(v, hotpot), 2, "two hotpots from beans and carrots")


func test_a_feast_supper_pours_no_table_cordial() -> void:
	"""Decision 1733's table drink skips an occasion's supper: a called feast is one (the kitchen's occasion), so the
	cordial in store is not poured at it (the Hearth feast pours its infusion; the cordial is never poured twice)."""
	var v: Village = _village()
	_stock_everyday(v)
	_stock_theme(v, Rules.HEARTH)
	_stock(v, Catalog.ITEM_CORDIAL, 4000)
	var drink := TableDrinkScript.new()
	drink.bind(v.kitchen)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	var f: FeastScript = v.feast
	assert_true(_run(v, func() -> bool:
		drink.update()
		return f.state == FeastScript.ST_IDLE, 30000), "tallied (%s)" % Words.status_line(f))
	drink.update()
	assert_true(f.attendees.size() > 0, "the feast was eaten: %s" % f.last_line)
	assert_true(v.kitchen.final_of(Rules.feast_key(DAY)) != null, "its supper published, so the drink looked at it")
	assert_equal([drink.pours, drink.poured_milli], [0, 0], "no table cordial at the feast's supper")
	assert_equal(v.pantry.milli_of(Catalog.ITEM_CORDIAL), 4000, "the cordial untouched")


func test_a_cancelled_feast_s_supper_pours_the_table_cordial() -> void:
	"""The note this lane left for 1733's owner, fixed: a feast called and then cancelled before its supper is an
	ordinary supper again, so the table drink pours the cordial at it (ceil(diners/4) U), as at any supper."""
	var v: Village = _village()
	_stock_everyday(v)
	_stock_theme(v, Rules.HEARTH)
	_stock(v, Catalog.ITEM_CORDIAL, 4000)
	var drink := TableDrinkScript.new()
	drink.bind(v.kitchen)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY, 1, true), "", "held")
	drink.update()
	assert_equal(v.feast.cancel(), "", "cancelled before the supper")
	var key: int = Rules.feast_key(DAY)
	assert_true(_run(v, func() -> bool:
		drink.update()
		return v.kitchen.final_of(key) != null, 30000), "the day's supper published")
	drink.update()
	var diners: int = v.kitchen.final_of(key).diners.size()
	assert_true(diners > 0, "the supper was eaten")
	assert_equal([drink.pours, drink.poured_milli], [1, TableDrinkScript.need_milli(diners)], "the table cordial poured")


func test_a_roots_hotpot_is_left_out_of_the_reserves_as_a_greens_one_is() -> void:
	"""REQ-SET-101 with decision 1735's greens or roots: the feast's hotpot input is set aside the way the kitchen's
	estimate draws it (greens first, then roots), so the ready food after a feast of beans and carrots is the same as
	after one of beans and cabbage -- and both are refused under 3 days, never the roots one let through."""
	var greens: Village = _village()
	var roots: Village = _village()
	for v: Village in [greens, roots]:
		_stock(v, PEA, 4000)
		_stock(v, Catalog.ITEM_FLOUR, 4000)
		_stock(v, Catalog.ITEM_NUTS, 4000)
		_stock(v, Catalog.ITEM_HERB, 1000)
	_stock(greens, CABBAGE, 4000)
	_stock(greens, CARROT, 72000)
	_stock(roots, CARROT, 76000)
	var after: int = greens.feast.food_days_after_milli(Rules.HEARTH, RESIDENTS)
	assert_equal(roots.feast.food_days_after_milli(Rules.HEARTH, RESIDENTS), after, "the same figure after the feast")
	var aside := PackedInt64Array()
	roots.feast.menu.set_aside(Rules.HEARTH, RESIDENTS, aside)
	assert_equal([aside[CABBAGE_ROW], aside[ROOTS_ROW]], [0, 4000], "no greens in store: the roots set aside")
	greens.feast.menu.set_aside(Rules.HEARTH, RESIDENTS, aside)
	assert_equal([aside[CABBAGE_ROW], aside[ROOTS_ROW]], [4000, 0], "greens in store: the greens first")
	var regatta := RegattaScript.new()
	regatta.kitchen = roots.kitchen
	regatta.stores = roots.stores
	regatta.menu.configure(roots.kitchen, roots.stores)
	roots.feast.bind_regatta(regatta)
	assert_equal(int(regatta.food_days_after.call(RESIDENTS)), after, "the regatta's Hearth feast sets its roots aside too")
	greens.feast.refusal(Rules.HEARTH, DAY, 1, false)
	roots.feast.refusal(Rules.HEARTH, DAY, 1, false)
	assert_equal([greens.feast.refused_code, roots.feast.refused_code], ["RESERVES", "RESERVES"],
		"both under 3 days after it (%d thousandths)" % after)


# --- the buffs -------------------------------------------------------------------------------------------------------

func test_a_buff_is_granted_once_and_never_stacks_or_extends() -> void:
	"""REQ-SET-105: granted for 48 h; again while it lasts: not stacked, not extended; after it lapses, granted again;
	the regatta's Shared Warmth is the Hearth's too."""
	var buffs := BuffsScript.new()
	assert_true(buffs.grant(Rules.HARVEST, 1000).contains("48 h"), "granted")
	var until: int = buffs.until[Rules.HARVEST]
	assert_true(buffs.grant(Rules.HARVEST, 2000).contains("not stacked"), "not stacked")
	assert_equal(buffs.until[Rules.HARVEST], until, "nor extended")
	assert_equal(buffs.hours_left(Rules.HARVEST, 1000), 48, "48 h left")
	assert_equal(buffs.hours_left(Rules.HARVEST, until - 1), 0, "a part hour is not a whole one")
	assert_false(buffs.active(Rules.HARVEST, until), "lapsed at its end")
	assert_true(buffs.grant(Rules.HARVEST, until).contains("48 h"), "granted again after it")
	assert_equal(buffs.granted[Rules.HARVEST], 2, "twice in all")
	assert_equal(buffs.status_words(until), "Abundant Tables 48 h", "its words")
	assert_equal(buffs.grant(-1, 0), "", "no theme")
	var menu := RegattaMenuScript.new()
	menu.warmth_until = 5000
	buffs.regatta_menu = menu
	assert_true(buffs.active(Rules.HEARTH, 4999) and not buffs.active(Rules.HEARTH, 5000), "the regatta's warmth")
	assert_true(buffs.grant(Rules.HEARTH, 100).contains("not stacked"), "a Hearth feast does not stack on it")
	assert_equal(buffs.cold_permille(4999), 750, "its cold exposure")


func test_shared_warmth_slows_the_cold_a_quarter() -> void:
	"""cold_exposure.gd's gain scaled by `gain_permille` (§5.2: 2000 -> 1500, 1000 -> 750), clearing unscaled, never
	more than §5.7's 40% reduction; an exposed hour at 750 adds 750 milli-hours."""
	assert_equal([ColdScript.gained_rate(2000, 750), ColdScript.gained_rate(1000, 750)], [1500, 750], "-25%")
	assert_equal(ColdScript.gained_rate(-2000, 750), -2000, "clearing is never slowed")
	assert_equal(ColdScript.gained_rate(1000, 100), 600, "at most a 40% reduction")
	assert_equal(ColdScript.gained_rate(1000, 2000), 1000, "never more than full")
	var cold := ColdScript.new()
	cold.configure(1)
	cold.gain_permille = 750
	cold.integrate(0, 1000, SimClock.TICKS_PER_HOUR)
	assert_equal(cold.cold_milli[0], 750, "an hour exposed: 750")
	cold.gain_permille = ColdScript.FULL_GAIN_PERMILLE
	cold.integrate(0, 1000, SimClock.TICKS_PER_HOUR)
	assert_equal(cold.cold_milli[0], 1750, "and 1000 without it")


# --- one feast among others: the regatta ---------------------------------------------------------------------------

func test_the_regatta_and_a_called_feast_never_overlap() -> void:
	"""The regatta's hooks: its feast refused (FEAST_CLASH) while a called feast is planned; a regatta feast eaten
	latches its start, barring a called feast within 72 h; its ready food leaves out its reservation."""
	var v: Village = _village()
	_stock_theme(v, Rules.HEARTH)
	var regatta := RegattaScript.new()
	regatta.kitchen = v.kitchen
	regatta.stores = v.stores
	regatta.menu.configure(v.kitchen, v.stores)
	v.feast.bind_regatta(regatta)
	assert_equal(v.feast.hold(Rules.HEARTH, DAY + 1, 1, true), "", "a called feast held")
	assert_true(regatta._feast_refusal(true, DAY + 10).contains("one feast is prepared at a time"), "the regatta refused")
	assert_equal(regatta.refused_code, "FEAST_CLASH", "its code")
	assert_equal(v.feast.cancel(), "", "cancelled")
	assert_equal(v.feast.clash_for_regatta(DAY + 10), "", "free again")
	regatta.plan_day = DAY + 4
	regatta.state = RegattaScript.ST_PLANNED
	assert_true(v.feast.clash(DAY).contains("the regatta's feast is planned"), "a held regatta bars a called feast")
	regatta.state = RegattaScript.ST_DONE
	regatta.feasts_served += 1
	v.feast.observe_regatta()
	assert_equal(v.feast.starts, PackedInt64Array([Rules.start_tick(DAY + 4)]), "the regatta's feast latched")
	assert_true(v.feast.clash(DAY + 2).contains("72 game hours"), "two days before it: refused")
	assert_true(int(regatta.food_days_after.call(RESIDENTS)) < v.kitchen.days_of_meals_milli(), "its ready food without its hotpot")
	assert_equal(int(regatta.food_days_after.call(RESIDENTS)), v.feast.food_days_after_milli(Rules.HEARTH, RESIDENTS),
		"the Hearth menu's reservation, all of it makeable")
	regatta.food_days_after = func(_e: int) -> int: return 12345
	regatta.fuel_days_after = func(_wood: int) -> int: return 678
	assert_equal([regatta.food_days_milli(), regatta.fuel_days_milli(0)], [12345, 678], "read through the hooks")
	regatta.food_days_after = Callable()
	regatta.fuel_days_after = Callable()
	assert_equal(regatta.fuel_days_milli(0), v.feast.fuel_days_after_milli(v.stores.wood_milli_u), "its fuel: the winter's")


# --- the words and the panel -----------------------------------------------------------------------------------------

func test_the_plan_reads_as_req_set_100_asks() -> void:
	"""The preview: attendees and the 17:00 supper, both courses with their food, the beverage, seats and seatings,
	staffing, the reserves after it and the buff's terms."""
	var v: Village = _village()
	_stock_theme(v, Rules.ORCHARD)
	var text: String = "\n".join(Words.preview_lines(v.feast, Rules.ORCHARD, DAY, 1))
	for words: String in ["Orchard feast (M3 in the full game) for 6", "17:00 supper", "nut roast x2 (8 portions)",
			"orchard crumble x2", "Mead: 2.0 U", "Also poured, if there: cider 2.0 U", "2 seatings", "keeps it", "After it: ready food", "Rooted Community if 5 of 6"]:
		assert_true(text.contains(words), "says %s: %s" % [words, text])
	assert_true(Words.status_line(v.feast).begins_with("No feast is called."), "the status")
	assert_true(Words.choice_line(v.feast).contains("Theme: Hearth"), "the choice")
	assert_equal(FeastScript.served_words(Rules.HEARTH), "bean hotpot, nut loaf and the warm infusion", "the menu")
	assert_false("\n".join(Words.preview_lines(v.feast, Rules.HEARTH, DAY, 1)).contains("Also poured"),
		"the Hearth pours only its infusion")


func test_the_choice_steps_and_keeps_current() -> void:
	"""Theme wraps; the day stays inside the three offered; the keeper is never the cook; the override toggles."""
	var v: Village = _village()
	var f: FeastScript = v.feast
	assert_equal(f.day_choices(), PackedInt32Array([DAY, DAY + 1, DAY + 2]), "today and the two after (before 15:00)")
	f.step_theme(-1)
	assert_equal(f.choice_theme, Rules.ORCHARD, "wrapped back")
	f.step_day(5)
	assert_equal(f.choice_day, DAY + 2, "the last offered")
	f.step_day(-9)
	assert_equal(f.choice_day, DAY, "the first")
	f.choice_host = RESIDENTS - 1
	f.step_host()
	assert_equal(f.choice_host, 1, "past the cook")
	f.toggle_override()
	assert_true(f.override, "toggled")
	f.step_theme(1)
	assert_false(f.override, "a new theme is a new feast: the override off again")
	f.toggle_override()
	f.step_day(1)
	assert_false(f.override, "and a new day")
	f.choice_host = f.cook()
	f.keep_choice_current()
	assert_equal(f.choice_host, 1, "the cook never keeps it")
	v.calendar.tick = tick_at(DAY, 16)
	f.keep_choice_current()
	assert_equal(f.choice_day, DAY + 1, "past today's cooking: tomorrow first")


func test_the_panel_shows_the_plan_and_calls_the_feast() -> void:
	"""Built out of the tree: the plan with its refusal first, Call disabled while refused; stocked, Call holds the feast
	through its action and Cancel gives it back."""
	var v: Village = _village()
	var panel := PanelScript.new()
	panel.configure(v.feast)
	var f: FeastScript = v.feast
	panel.set_actions({&"call": func() -> String: return f.hold(f.choice_theme, f.choice_day, f.choice_host, true),
		&"cancel": f.cancel})
	panel.refresh()
	assert_true(panel.text_of(&"plan").begins_with("Can't call it: needs"), panel.text_of(&"plan"))
	assert_true(panel.button(&"call").disabled, "Call disabled while refused")
	_stock_theme(v, Rules.HEARTH)
	_stock_everyday(v)
	v.stores.add_wood(100000)
	panel.refresh()
	assert_true(panel.text_of(&"plan").begins_with("Ready to call"), panel.text_of(&"plan"))
	assert_false(panel.button(&"call").disabled, "Call enabled")
	assert_equal(panel.press(&"call"), "", "held")
	assert_equal(f.state, FeastScript.ST_PREPARING, "preparing")
	assert_true(panel.text_of(&"status").contains("preparing"), panel.text_of(&"status"))
	assert_false(panel.button(&"cancel").disabled, "Cancel enabled")
	assert_equal(panel.press(&"cancel"), "", "cancelled")
	assert_equal(panel.press(&"nothing"), "", "an unknown action does nothing")
	panel.set_actions({})
	panel.free()
