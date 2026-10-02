extends "res://test/framework/test_case.gd"
## The first meal loop (decision 0381; review F21, UX-027): the dishes' numbers as the GDD's rows, the crops in each
## category, the need and the fed states, the portions' order and ageing, the reservations on the pantry's lots -- and
## the whole loop on real brains walking a hand-made village: the cook fetching, cooking, carrying the pot, the
## village eating; breakfast and supper over two days with the dishes alternating; a shortage said exactly; and every
## interruption conserving the stock -- no second debit or credit, no lot made fresher.
##
## No scene tree and no staged assets.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const StoreScript := preload("res://demo/kitchen/meal_store.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const FedScript := preload("res://demo/kitchen/nourishment.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const KitchenWork := preload("res://demo/work/kitchen_work.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")

## A frame of the demo clock's longest sub-step (1/30 s) at 1x: one calendar tick (decision 0421: 30 ticks a second,
## a game hour of 750 ticks every 25 s).
const DT: float = 1.0 / 30.0
const TICKS_PER_FRAME: int = 1
@warning_ignore("integer_division") const FRAMES_PER_HOUR: int = SimClock.TICKS_PER_HOUR / TICKS_PER_FRAME
const WALK_M_S: float = 1.0
const BODY_M: float = 0.25
## The village's proportions (world_layout.gd): the kitchen's pantry a few metres from the cauldron, the hall's table
## between the cauldron and the hall, the well in the square.
const STORE_AT: Vector2 = Vector2(8.5, 0.5)
const CAULDRON: Vector2 = Vector2(6.0, 0.0)
const TABLE: Vector2 = Vector2(3.0, -3.0)
const WELL: Vector2 = Vector2(0.0, 4.0)
const BUTT: Vector2 = Vector2(1.5, 4.5)
const HALL: Vector2 = Vector2(-2.0, -7.0)
const OATS: int = 15
const CARROT: int = 2
const TURNIP: int = 1
const WHEAT: int = 13
const CABBAGE: int = 6
const PEA: int = 11


## One village: a space, residents, the pantry over a covered store, the stores, the calendar and the kitchen.
class Village extends RefCounted:
	var space: CastSpaceScript = null
	var brains: Array[BrainScript] = []
	var calendar: CalendarScript = CalendarScript.new()
	var pantry: PantryScript = null
	var stores: StoresScript = StoresScript.new()
	var kitchen: KitchenScript = KitchenScript.new()
	var notices: NoticesScript = NoticesScript.new()
	var incidents: IncidentsScript = IncidentsScript.new()
	var night: NightScript = null
	var places: PlacesScript = PlacesScript.new()


## Every village a test built. A resident's unfinished kitchen job holds the kitchen (cast/unfinished_job.gd keeps a
## reference-counted owner alive) and the kitchen holds the residents: after_each breaks that cycle (decision 0501).
var _villages: Array[Village] = []


func after_each() -> void:
	"""Let go of every village the test built."""
	for v: Village in _villages:
		for brain: BrainScript in v.brains:
			brain.drop_jobs()
	_villages.clear()


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of `day` (day 0 is spring 1; tick 0 is 06:00 of it)."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


func _lengths() -> Dictionary:
	"""Every clip the cast knows, with round lengths."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _village(count: int, tick: int, species: String = "mouse") -> Village:
	"""A village of `count` residents standing in a row at the square, on the calendar at `tick`."""
	var v := Village.new()
	_villages.append(v)
	v.space = CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": NightScript.HALL_POI, "position": Vector3(HALL.x, 0.0, HALL.y),
		"capacity": 4}]
	v.space.setup(points, [] as Array[Vector3])
	var names := PackedStringArray()
	var kinds := PackedStringArray()
	var keys: Array[StringName] = []
	for i in count:
		var brain := BrainScript.new()
		brain.configure(v.space, WALK_M_S, BODY_M, 11 + i, _lengths())
		brain.start_at(Vector2(-2.0 + 1.2 * float(i), 1.0), 0.0, -1, -1)
		v.space.tunnels.set_body(brain.index, 1024, 256)
		v.brains.append(brain)
		names.append("resident %d" % i)
		kinds.append(species)
		keys.append(&"mouse_keeper" if i == 0 else StringName("mouse_%d" % i))
	v.calendar.tick = tick
	v.pantry = PantryScript.new(StorageScript.new(STORE_AT))
	v.places.set_points(CAULDRON, TABLE, WELL, BUTT)
	v.places.add_table_seats(TABLE, PlacesScript.SEATS_PER_TABLE)
	v.notices.bind_calendar(v.calendar)
	v.incidents.bind(v.notices, v.calendar, NewsClockScript.new())
	v.kitchen.bind_news(v.notices, v.incidents)
	v.set_meta(&"who", [names, kinds, keys])
	return v


func _open(v: Village) -> Village:
	"""Open the kitchen over the village as it is stocked now."""
	var who: Array = v.get_meta(&"who")
	v.kitchen.configure(v.brains, who[0], who[1], who[2], v.pantry, v.stores, v.calendar, v.places)
	return v


func _stock(v: Village, item: int, milli: int) -> void:
	"""Put `milli` of `item` in the covered store."""
	var read := IntMath.IntResult.new()
	assert_true(v.pantry.add_into(item, milli, 0, read), "stocked")


func _run(v: Village, frames: int, until: Callable = Callable()) -> int:
	"""Step the calendar, the night (when there is one), every brain and the kitchen, a frame at a time at 1x; stop
	early once `until() -> bool`. Returns the frames run."""
	for f in frames:
		v.calendar.tick += TICKS_PER_FRAME
		if v.night != null:
			v.night.step()
		for brain in v.brains:
			brain.step(DT)
		v.kitchen.update()
		if until.is_valid() and bool(until.call()):
			return f + 1
	return frames


func _with_night(v: Village) -> void:
	"""The night routine over the village (no beds: everyone sleeps in the hall), the cook its early riser."""
	v.night = NightScript.new()
	var heights := PackedInt32Array()
	var names := PackedStringArray()
	for i in v.brains.size():
		heights.append(1024)
		names.append("resident %d" % i)
	v.night.configure(v.space.tunnels, v.brains, names, heights, v.calendar, null)
	v.night.set_alarm(func() -> bool: return false)
	v.night.set_hall(HALL)
	v.night.set_early_riser(v.kitchen.up_early)


# --- the numbers ------------------------------------------------------------------------------------

func test_a_supper_with_fresh_fish_is_the_fish_stew() -> void:
	"""Decision 0436: with a batch's fresh fish and roots free, supper is the fish stew -- both inputs reserved from real
	lots, withdrawn together when the batch starts, 3 portions of 2200 NP a batch; the books balance."""
	var v := _open(_village(3, tick_at(0, 14)))
	_stock(v, Catalog.FIRST_CATCH + 3, 4000)
	_stock(v, CARROT, 4000)
	v.stores.add_water(10000)
	_run(v, FRAMES_PER_HOUR + 10)
	var plan: PackedInt32Array = v.kitchen.plan_of(Rules.meal_key(0, Rules.MEAL_SUPPER))
	assert_equal(plan[0], Rules.DISH_FISH_STEW, "supper is the fish stew")
	assert_true(_run(v, 6 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.store.portions_of(Rules.DISH_FISH_STEW) >= 3) > 0,
		"a batch cooked")
	assert_equal(v.kitchen.store.portions_of(Rules.DISH_FISH_STEW) % 3, 0, "three portions a batch")
	@warning_ignore("integer_division") var batches: int = v.kitchen.store.portions_of(Rules.DISH_FISH_STEW) / 3
	assert_equal(v.pantry.milli_of(Catalog.FIRST_CATCH + 3), 4000 - batches * 2000, "2 U of perch a batch")
	assert_equal(v.pantry.milli_of(CARROT), 4000 - batches * 2000, "2 U of roots a batch")
	assert_equal(v.kitchen.consumed_food_milli, batches * 4000, "the books: both inputs")


func test_without_roots_the_fish_is_baked_not_left_to_rot() -> void:
	"""Fresh fish but no roots: no fish stew (both inputs or neither) -- but since Brendan's tuning ruling E2 (decision
	0603) the fish is baked, a fish dish needing no roots, rather than kept while porridge is cooked and the fish rots."""
	var v := _open(_village(2, tick_at(0, 14)))
	_stock(v, Catalog.FIRST_CATCH, 4000)
	_stock(v, OATS, 4000)
	v.stores.add_water(10000)
	_run(v, FRAMES_PER_HOUR + 10)
	assert_equal(v.kitchen.plan_of(Rules.meal_key(0, Rules.MEAL_SUPPER))[0], Rules.DISH_BAKED_FISH, "baked fish")
	assert_true(v.kitchen.takes.free_milli_of_crop(v.pantry, Catalog.CAT_FISH) < 4000, "the fish held for it")


func test_the_ready_food_counts_each_dish_at_its_own_portions() -> void:
	"""The HUD's Ready food: the fish stew's fish and the roots it takes make 3 portions a batch; the roots left the soup's
	2 -- never the roots counted twice."""
	var v := _open(_village(4, tick_at(0, 8)))
	_stock(v, Catalog.FIRST_CATCH, 2000)
	_stock(v, CARROT, 6000)
	assert_equal(v.kitchen.cookable_batches(), 2, "one stew batch, one soup batch from the 4 U of roots left (not two from 6)")
	assert_equal(v.kitchen.cookable_portions(), 5, "3 + 2 portions")


func test_the_dishes_are_the_gdd_rows() -> void:
	"""Porridge is §5.7's `porridge` (grain 2 + water 2 -> 2 x 1800 NP, 12 WU, 24 h) and the soup its `root_stew`
	(roots 3 + water 1 -> 2 x 1800, 16 WU, 24 h); a batch burns BAL-SUPPLY-004's 0.1 U of wood; at §5.2's 80 milli-WU a
	tick a batch is 150 and 200 calendar ticks."""
	assert_equal([Rules.GDD_ROWS[0], Rules.INPUT_MILLI[0], Rules.WATER_MILLI[0], Rules.PORTIONS_PER_BATCH[0],
		Rules.NP_PER_PORTION[0], Rules.WORK_MWU[0], Rules.SHELF_HOURS[0]], ["porridge", 2000, 2000, 2, 1800, 12000, 24], "porridge")
	assert_equal([Rules.GDD_ROWS[1], Rules.INPUT_MILLI[1], Rules.WATER_MILLI[1], Rules.PORTIONS_PER_BATCH[1],
		Rules.NP_PER_PORTION[1], Rules.WORK_MWU[1], Rules.SHELF_HOURS[1]], ["root_stew", 3000, 1000, 2, 1800, 16000, 24], "soup")
	assert_equal(Rules.WOOD_MILLI_PER_BATCH, 100, "0.1 U of wood a batch")
	assert_equal([Rules.batch_ticks(0), Rules.batch_ticks(1)], [150, 200], "12 and 16 WU at 60 WU a game hour")
	assert_equal(Rules.LIBRARY_IDS.slice(0, 3), ["salamandastron::SAL_recipe_wild_oat_porridge",
		"outcast::OUT_recipe_togget_s_vegetable_soup", "taggerung::TAG_recipe_requested_perch_or_trout"],
		"the library's first three recipes (the third: decision 0436; the rest: decision 0601, test_demo_dishes.gd)")
	assert_equal([Rules.GDD_ROWS[2], Rules.INPUT_MILLI[2], Rules.SIDE_MILLI[2], Rules.WATER_MILLI[2], Rules.PORTIONS_PER_BATCH[2],
		Rules.NP_PER_PORTION[2], Rules.WORK_MWU[2], Rules.SHELF_HOURS[2]], ["fish_stew", 2000, 2000, 2000, 3, 2200, 20000, 24],
		"§5.7 fish_stew: fish 2 + roots 2 + water 2 -> 3 x 2200 NP, 20 WU, 24 h")
	assert_equal([Rules.INPUT_CROP[2], Rules.SIDE_CROP[2]], [Catalog.CAT_FISH, FarmingScript.CROP_ROOTS], "fresh fish and roots")
	assert_false(Rules.is_input(Rules.DISH_FISH_STEW, Catalog.ITEM_DRIED_FISH), "dried fish is not §5.7's `fish`")


func test_grain_and_roots_are_their_rows() -> void:
	"""Grain is wheat, barley and oats; roots radish, turnip, carrot, beetroot, parsnip and onion -- the §5.6 rows they
	grow by; nothing else is either."""
	var grain := PackedStringArray()
	var roots := PackedStringArray()
	for item in Catalog.ITEM_COUNT:
		if Rules.is_input(Rules.DISH_PORRIDGE, item):
			grain.append(String(Catalog.ITEM_KEYS[item]))
		if Rules.is_input(Rules.DISH_SOUP, item):
			roots.append(String(Catalog.ITEM_KEYS[item]))
	assert_equal(grain, PackedStringArray(["wheat", "barley", "oats"]), "grain")
	assert_equal(roots, PackedStringArray(["radish", "turnip", "carrot", "beetroot", "parsnip", "onion"]), "roots")
	assert_false(Rules.is_input(Rules.DISH_PORRIDGE, Catalog.NO_ITEM), "no item is no input")


func test_the_need_is_the_gdds() -> void:
	"""§5.2 through family_rules.gd: 250 a game hour for a small resident (6000 a day), 300 medium, 400 large; x1.2 in
	winter. The otter is medium, the badger large, the beaver medium (a demo value), a placeholder small."""
	var fed := FedScript.new()
	fed.configure(PackedStringArray(["mouse", "otter", "badger", "beaver", "placeholder"]))
	assert_equal([fed.hourly_milli(0, false), fed.hourly_milli(1, false), fed.hourly_milli(2, false)],
		[250000, 300000, 400000], "milli-points an hour")
	assert_equal([fed.daily_need(0, false), fed.daily_need(1, false), fed.daily_need(2, false), fed.daily_need(0, true)],
		[6000, 7200, 9600, 7200], "NP a day")
	assert_equal([int(fed.size_class[3]), int(fed.size_class[4])], [Rules.SIZE_MEDIUM, Rules.SIZE_SMALL], "beaver, placeholder")
	fed.configure(PackedStringArray(["Mouse", "Otter", "Badger", "Beaver"]))
	assert_equal([int(fed.size_class[0]), int(fed.size_class[1]), int(fed.size_class[2]), int(fed.size_class[3])],
		[Rules.SIZE_SMALL, Rules.SIZE_MEDIUM, Rules.SIZE_LARGE, Rules.SIZE_MEDIUM], "as the cast's actors name them")


func test_fed_peckish_hungry_are_the_thresholds() -> void:
	"""§5.2: above 3500 fed, down to 1501 peckish, 1500 and below hungry."""
	assert_equal([Rules.fed_state(10000), Rules.fed_state(3501), Rules.fed_state(3500), Rules.fed_state(1501),
		Rules.fed_state(1500), Rules.fed_state(0)], [Rules.FED, Rules.FED, Rules.PECKISH, Rules.PECKISH, Rules.HUNGRY,
		Rules.HUNGRY], "the bands")


func test_hunger_falls_by_the_hour_and_a_portion_raises_it_clamped() -> void:
	"""A day's 24 hours take a small resident's 6000; a portion adds 1800, clamped at 10000 without refund; NP eaten
	are counted for the day and the count starts afresh at midnight."""
	var fed := FedScript.new()
	fed.configure(PackedStringArray(["mouse"]))
	for h in 24:
		fed.pass_hour(0, false, h)
	assert_equal(fed.hunger[0], 4000, "10000 - 24 x 250")
	assert_equal(fed.eat(0, 1800), 1800, "a portion counts in full")
	fed.hunger[0] = 9500
	assert_equal(fed.eat(0, 1800), 500, "clamped at 10000")
	assert_equal(fed.hunger[0], 10000, "full")
	assert_equal(fed.today_np[0], 3600, "both portions eaten today")
	fed.pass_hour(1, false, 24)
	assert_equal(fed.today_np[0], 0, "a new day")


func test_alternating_dishes_still_turn_monotonous_on_the_fifth_meal() -> void:
	"""§5.7 counts the last six meals: porridge, soup, porridge, soup -- the fifth meal, porridge, has two porridge in
	the six before it: monotonous -200 for 6 h; after six it is three, still -200."""
	var fed := FedScript.new()
	fed.configure(PackedStringArray(["mouse"]))
	for k in 4:
		fed.ate_meal(0, k, k % 2, 10)
		assert_equal(fed.monotony[0], 0, "meal %d: no memory" % (k + 1))
	fed.ate_meal(0, 4, Rules.DISH_PORRIDGE, 30)
	assert_equal([fed.monotony[0], fed.monotony_until[0]], [Rules.MONOTONY_LOW, 36], "monotonous, for 6 h")
	fed.pass_hour(1, false, 36)
	assert_equal(fed.monotony[0], 0, "lapsed")
	assert_equal(Rules.monotony_for(4), Rules.MONOTONY_HIGH, "4 of 6: -400")


# --- the loop on real brains -------------------------------------------------------------------------

func _everyone_had(v: Village, key: int) -> bool:
	"""Whether every resident has eaten or missed meal `key`."""
	for i in v.brains.size():
		if not v.kitchen.fed.had(i, key):
			return false
	return true


func test_stock_becomes_breakfast_by_exactly_the_recipe() -> void:
	"""02:00 with oats and carrots in the store and an empty butt: the cook fetches the meals' food, the free
	residents draw the water, the cook (up from 05:00) cooks two batches of porridge, carries the pot to the table, and
	the village eats breakfast; the one portion left over is still good at supper's call, so supper is one batch of
	soup (decision 0421's hours: breakfast out by 07:00 lasts to supper in spring), carried out and eaten. The oats fall
	by exactly 2 x 2 U, the carrots by 3 U, the water by 2 x 2 + 1 U, the wood by 3 x 0.1 U; every portion is held,
	eaten or spoiled."""
	var v := _village(3, tick_at(1, 2))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 12000)
	_open(v)
	var breakfast := Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_equal(v.kitchen.planned_keys(), PackedInt32Array([breakfast, breakfast + 1, breakfast + 2, breakfast + 3]),
		"two days' meals planned")
	var ran := _run(v, 17 * FRAMES_PER_HOUR, func() -> bool: return _everyone_had(v, breakfast + 1))
	assert_true(ran < 17 * FRAMES_PER_HOUR, "breakfast and supper eaten before supper ended (%d frames)" % ran)
	assert_equal(v.pantry.milli_of(OATS), 6000, "oats: 10.0 - 4.0 U")
	assert_equal(v.pantry.milli_of(CARROT), 9000, "carrots: 12.0 - 3.0 U")
	assert_equal(v.kitchen.consumed_water_milli, 5000, "two porridge batches' water and one soup's")
	assert_equal(v.kitchen.poured_water_milli - v.kitchen.consumed_water_milli, v.stores.water_milli_u,
		"every unit poured is in the butt or was used")
	assert_equal(v.stores.wood_milli_u, StoresScript.START_WOOD_MILLI_U - 300, "three batches of wood")
	assert_equal(v.kitchen.batches_cooked, 3, "three batches: the leftover cut supper to one")
	for i in v.brains.size():
		assert_equal(v.kitchen.fed.last_outcome[i], FedScript.OUTCOME_ATE, "resident %d ate" % i)
	assert_equal(v.kitchen.store.portions() + v.kitchen.portions_eaten + v.kitchen.store.spoiled_portions, 6,
		"every portion cooked is held, eaten or spoiled")
	assert_true(v.kitchen.portions_eaten >= 6, "everyone's breakfast and supper among them")
	assert_equal(v.kitchen.store.spoiled_portions, 0, "none spoiled")



func _log_meals(v: Village, meal_log: Dictionary) -> void:
	"""Record each resident's meals as they are eaten or missed: meal_log[[i, key]] = the dish (or -1 missed, -2 raw)."""
	for i in v.brains.size():
		var key: int = v.kitchen.fed.last_meal[i]
		if key < 0 or meal_log.has([i, key]):
			continue
		match v.kitchen.fed.last_outcome[i]:
			FedScript.OUTCOME_ATE:
				meal_log[[i, key]] = v.kitchen.fed.last_dish[i]
			FedScript.OUTCOME_RAW:
				meal_log[[i, key]] = -2
			_:
				meal_log[[i, key]] = -1


func _run_logging(v: Village, frames: int, meal_log: Dictionary) -> void:
	"""`_run` a frame at a time, logging the meals."""
	for f in frames:
		_run(v, 1)
		_log_meals(v, meal_log)


func test_two_days_of_breakfast_and_supper_alternate_the_dishes() -> void:
	"""From 14:00 of day 0 to dusk of day 2 with the night routine (everyone sleeps in the hall; the cook is up at
	05:00): breakfast is porridge and supper soup each day (ruling 1); on day 2 every resident eats breakfast after
	dawn and supper before dusk; every milli-U of food the pantry lost is in the batches cooked."""
	var v := _village(4, tick_at(0, 14))
	_stock(v, OATS, 20000)
	_stock(v, CARROT, 30000)
	_open(v)
	_with_night(v)
	var meal_log := {}
	_run_logging(v, 54 * FRAMES_PER_HOUR, meal_log)
	for k in v.kitchen.cooked_keys.size():
		var key: int = v.kitchen.cooked_keys[k]
		assert_equal(v.kitchen.cooked_dishes[k], Rules.DISH_PORRIDGE if key % 2 == Rules.MEAL_BREAKFAST else Rules.DISH_SOUP,
			"meal %d's batch was its dish" % key)
	for day in [1, 2]:
		assert_true(v.kitchen.cooked_keys.has(Rules.meal_key(day, Rules.MEAL_BREAKFAST)), "day %d: breakfast cooked" % day)
		assert_true(v.kitchen.cooked_keys.has(Rules.meal_key(day, Rules.MEAL_SUPPER)), "day %d: supper cooked" % day)
	for i in 4:
		for meal in 2:
			assert_true(int(meal_log.get([i, Rules.meal_key(2, meal)], -9)) >= 0, "day 2: resident %d ate %s" % [i, Rules.MEAL_NAMES[meal]])
	assert_equal(50000 - v.pantry.milli_of(OATS) - v.pantry.milli_of(CARROT), v.kitchen.consumed_food_milli
		+ v.kitchen.raw_eaten_milli, "the pantry lost exactly what the batches took and the hungry ate raw")
	var by_recipe: int = 0
	for dish in v.kitchen.cooked_dishes:
		by_recipe += Rules.INPUT_MILLI[dish]
	assert_equal(v.kitchen.consumed_food_milli, by_recipe, "and the batches took exactly their recipes")


# --- the portions, the reservations and the pantry's withdrawals -------------------------------------

func test_portions_are_eaten_oldest_first_and_once() -> void:
	"""§5.7's order: the lot with least shelf life left first, then the dish, then the row; a portion is reserved,
	then consumed once; a portion given back is there again; nothing is offered before it is put out, nor a later
	meal's before its own meal (unless asked for exactly)."""
	var store := StoreScript.new()
	var old := store.add(Rules.DISH_SOUP, 2, 1)
	store.age_hour(0)
	var fresh := store.add(Rules.DISH_PORRIDGE, 2, 2)
	var later := store.add(Rules.DISH_SOUP, 2, 3)
	assert_equal(store.available(2), 0, "nothing out yet")
	assert_equal(store.carry_out(), 6, "the pot goes out")
	assert_equal(store.available(2), 4, "breakfast's diners see the old lot and their own")
	assert_equal(store.reserve_one(2), old, "the oldest first")
	assert_equal(store.reserve_one(2), old, "and again")
	assert_equal(store.reserve_one(2), fresh, "then breakfast's own")
	store.release_one(fresh)
	assert_equal(store.consume_one(old), Rules.DISH_SOUP, "eaten: soup")
	assert_equal(store.consume_one(fresh), Rules.NO_DISH, "a portion given back is no longer reserved")
	assert_equal(store.reserve_one(3, true), later, "supper's own, asked for exactly")
	assert_equal(store.portions(), 5, "six cooked, one eaten")


func test_meals_are_cooked_close_to_their_calls_and_last_their_windows_in_summer() -> void:
	"""Decision 0421: breakfast is cooked from the cook's rising at 05:00, supper from 15:00. On the table a portion ages
	at the open-pile factor times summer's, 10.7 h of its 24 -- so a breakfast an hour in the pot and put out at 06:00
	is good to the end of its window at 09:00 and beyond, and a supper put out at 16:00 is good to 19:00; a supper put
	out at 06:00 would have spoiled before its window opened."""
	assert_equal([KitchenScript._cook_from(Rules.meal_key(3, Rules.MEAL_BREAKFAST)),
		KitchenScript._cook_from(Rules.meal_key(3, Rules.MEAL_SUPPER))], [3 * 24 + 5, 3 * 24 + 15], "05:00 and 15:00")
	const SUMMER: int = 1
	for meal: int in 2:
		var store := StoreScript.new()
		store.add(Rules.dish_for_meal(meal), 2, meal)
		store.age_hour(SUMMER)
		store.carry_out()
		var out_hour: int = Rules.COOK_FROM_HOUR[meal] + 1
		for h in Rules.END_HOUR[meal] - out_hour + 1:
			store.age_hour(SUMMER)
		assert_equal(store.portions(), 2, "%s: out at %02d:00, good past %02d:00" % [Rules.MEAL_NAMES[meal], out_hour,
			Rules.END_HOUR[meal]])
	var dawn := StoreScript.new()
	dawn.add(Rules.DISH_SOUP, 2, 1)
	dawn.carry_out()
	for h in Rules.CALL_HOUR[Rules.MEAL_SUPPER] - 6:
		dawn.age_hour(SUMMER)
	assert_equal(dawn.portions(), 0, "a supper out from 06:00 is gone by 17:00")


func test_the_day_s_hours_follow_decision_0421() -> void:
	"""Breakfast 07:00-08:59 and supper 17:00-18:59; the cook up at 05:00, an hour before the village; supper ends an
	hour before dusk (20:00), so a raw meal at its end is eaten before bed; no meal is served at night."""
	assert_equal([Rules.CALL_HOUR, Rules.END_HOUR, Rules.COOK_RISE_HOUR, Rules.COOK_FROM_HOUR],
		[[7, 17], [9, 19], 5, [5, 15]], "the hours")
	var served := PackedInt32Array()
	for hour: int in 24:
		served.append(Rules.meal_of_hour(hour))
	assert_equal(served, PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, 0, 0, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, -1,
		-1, -1, -1, -1]), "breakfast at 7 and 8, supper at 17 and 18")
	assert_equal(Rules.END_HOUR[Rules.MEAL_SUPPER], NightScript.DUSK_HOUR - 1, "supper ends an hour before dusk")
	assert_equal(Rules.COOK_RISE_HOUR, NightScript.DAWN_HOUR - 1, "the cook an hour before dawn")
	for meal: int in 2:
		assert_false(NightScript.is_night_hour(Rules.CALL_HOUR[meal]) or NightScript.is_night_hour(Rules.END_HOUR[meal] - 1),
			"%s is served by day" % Rules.MEAL_NAMES[meal])


func test_portions_age_faster_on_the_table_and_spoil_at_equal_mass() -> void:
	"""In the pot a portion ages at the covered-store factor, on the table at the open pile's (§5.8: "Prepared food
	left on tables uses open-pile factor"); at 24 h its unreserved portions are spoiled food at equal mass -- a 500 g
	portion is 2 U of 250 g spoiled food; a reserved one spoils only when given back."""
	var store := StoreScript.new()
	var pot := store.add(Rules.DISH_PORRIDGE, 2, 0)
	store.age_hour(0)
	assert_equal(store.lot_age(pot), 1000, "an hour in the pot: 1000 milli-hours in spring")
	store.carry_out()
	store.age_hour(0)
	assert_equal(store.lot_age(pot), 2500, "an hour on the table: 1500 more")
	var lot := store.reserve_one(0)
	for h in 15:
		store.age_hour(0)
	assert_equal(store.portions(), 1, "the unreserved portion spoiled")
	assert_equal(store.spoiled_milli, 2000, "as 2 U of spoiled food")
	store.release_one(lot)
	assert_equal([store.portions(), store.spoiled_milli], [0, 4000], "the other spoils once given back")


func test_a_take_reserves_the_soonest_to_spoil_and_withdraws_exactly_once() -> void:
	"""Two lots of oats, one older: a take reserves from the older first and only what is there; free food is what
	nobody reserves; a batch withdraws exactly its milli-U from the lots, once (a second asks more than is left and is
	refused, changing nothing); a release gives back the rest without moving any food."""
	var pantry := PantryScript.new(StorageScript.new(STORE_AT))
	var read := IntMath.IntResult.new()
	pantry.add_into(OATS, 3000, 0, read)
	var older: int = read.value
	for h in 10:
		pantry.age_hour(0)
	pantry.add_into(OATS, 3000, 0, read)
	var takes := TakesScript.new()
	var take := takes.new_take()
	takes.reserve_into(pantry, take, Catalog.ITEM_CROP[OATS], 4000, 0, read)
	assert_equal(read.value, 4000, "reserved")
	assert_equal(takes.free_milli(pantry, older), 0, "the older lot first, all of it")
	assert_equal(takes.free_milli_of_crop(pantry, Catalog.ITEM_CROP[OATS]), 2000, "2 U still free")
	takes.pick_up(pantry, take, 0)
	takes.put_down(take)
	assert_true(takes.consume_into(pantry, take, 2000, TakesScript.AT_KITCHEN, 0, read), "a batch's 2 U")
	assert_equal(pantry.milli_of(OATS), 4000, "withdrawn once")
	assert_equal(pantry.lot_milli(older), 1000, "from the lot that spoils first")
	assert_false(takes.consume_into(pantry, take, 3000, TakesScript.AT_KITCHEN, 0, read), "more than is left: refused")
	assert_equal(pantry.milli_of(OATS), 4000, "nothing moved")
	assert_equal(takes.release_milli(pantry, take, 1000, 0), 1000, "1 U no longer needed given back")
	assert_equal([takes.free_milli(pantry, older), takes.live_milli(pantry, take)], [0, 1000],
		"the later-spoiling lot's first: the older lot stays reserved")
	assert_equal(takes.release(take), 1000, "the rest given back")
	assert_equal(pantry.milli_of(OATS), 4000, "giving back moves no food")
	assert_equal(pantry.lot_age(older), 10000, "and makes nothing fresher")


func test_an_unreachable_store_lets_go_only_what_is_still_there() -> void:
	"""The cook could not get to a store (MAX_FAILS walks): what still waits there is let go; food already fetched
	stays the meal's -- and a take whose lot no longer holds all it reserves is cut to what is there before a batch
	withdraws, so the withdrawal is whole."""
	var pantry := PantryScript.new(StorageScript.new(STORE_AT))
	var read := IntMath.IntResult.new()
	pantry.add_into(OATS, 6000, 0, read)
	var lot: int = read.value
	var takes := TakesScript.new()
	var take := takes.new_take()
	takes.reserve_into(pantry, take, Catalog.ITEM_CROP[OATS], 4000, 0, read)
	takes.pick_up(pantry, take, 0)
	takes.reserve_into(pantry, take, Catalog.ITEM_CROP[OATS], 2000, 0, read)
	assert_equal(takes.release_at_store(pantry, take, 0), 2000, "the 2 U still at the store let go")
	assert_equal(takes.live_milli(pantry, take, TakesScript.IN_HAND), 4000, "the 4 U in hand kept")
	takes.put_down(take)
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 3000, read), "someone else takes 3 U of the lot")
	assert_true(takes.consume_into(pantry, take, 2000, TakesScript.AT_KITCHEN, 0, read), "a batch from what is there")
	assert_equal([pantry.milli_of(OATS), takes.live_milli(pantry, take)], [1000, 1000], "cut to the lot, then 2 U")
	assert_false(takes.consume_into(pantry, take, 2000, TakesScript.AT_KITCHEN, 0, read), "not another")
	assert_equal(pantry.milli_of(OATS), 1000, "refused whole")


func test_withdraw_free_takes_only_what_nobody_holds() -> void:
	"""An owner outside the kitchen (the care shelf's herbs, decision 0902) takes away up to what it asks of a category's
	UNRESERVED food: a take's reservation is untouched; nothing for none or a bad quantity."""
	var pantry := PantryScript.new(StorageScript.new(STORE_AT))
	var read := IntMath.IntResult.new()
	var herb: int = Catalog.ITEM_HERB
	pantry.add_into(herb, 3000, 0, read)
	var takes := TakesScript.new()
	var held := takes.new_take()
	takes.reserve_into(pantry, held, Catalog.CAT_HERB, 1000, 0, read)
	assert_equal(takes.withdraw_free(pantry, Catalog.CAT_HERB, 5000, 0), 2000, "the free 2 U, not the held one")
	assert_equal([pantry.milli_of(herb), takes.live_milli(pantry, held)], [1000, 1000], "the held unit stays, still held")
	assert_equal(takes.withdraw_free(pantry, Catalog.CAT_HERB, 1000, 0), 0, "none free")
	assert_equal(takes.withdraw_free(pantry, Catalog.CAT_HERB, 0, 0), 0, "a bad quantity")


func test_a_reserved_lot_that_spoils_is_no_longer_the_takes() -> void:
	"""A lot that spoils frees its row; a new lot in that row has a new serial, so the take's entry counts for nothing
	and is pruned -- the kitchen never cooks spoiled food or another lot's."""
	var pantry := PantryScript.new(StorageScript.new(STORE_AT))
	var read := IntMath.IntResult.new()
	pantry.add_into(CARROT, 3000, 0, read)
	var row: int = read.value
	var serial := pantry.lot_serial(row)
	var takes := TakesScript.new()
	var take := takes.new_take()
	takes.reserve_into(pantry, take, Catalog.ITEM_CROP[CARROT], 3000, 0, read)
	for h in 240:
		pantry.age_hour(0)
	pantry.add_into(CARROT, 3000, 0, read)
	assert_equal(read.value, row, "the row is reused")
	assert_true(pantry.lot_serial(row) != serial, "with a new serial")
	assert_equal(takes.live_milli(pantry, take), 0, "the take holds nothing of it")
	assert_equal(takes.prune(pantry), 3000, "pruned")
	assert_false(pantry.withdraw_into(row, serial, 1000, read), "the old serial cannot withdraw")
	assert_equal(read.error, PantryScript.REFUSE_STALE_LOT, "LOT_NOT_THE_SAME")


func test_the_butt_takes_what_fits_and_gives_all_or_nothing() -> void:
	"""The water butt by the well holds WATER_CAP: a pour takes what fits; a batch takes its water all or nothing."""
	var stores := StoresScript.new()
	assert_equal(stores.add_water(StoresScript.WATER_CAP_MILLI_U + 5000), StoresScript.WATER_CAP_MILLI_U, "what fits")
	assert_equal(stores.water_room(), 0, "full")
	assert_false(stores.take_water(StoresScript.WATER_CAP_MILLI_U + 1), "more than it holds: none")
	assert_true(stores.take_water(2000), "a batch's water")
	assert_equal(stores.water_milli_u, StoresScript.WATER_CAP_MILLI_U - 2000, "taken once")


# --- shortages ---------------------------------------------------------------------------------------------

func test_no_water_says_so_exactly_and_supper_is_missed() -> void:
	"""Keep water drawn off and an empty butt, carrots in store: the meal's decision refuses NO_WATER in the cards'
	words with its fix; supper's call raises "No supper tonight: ..." with the same reason and fix; nobody eats, the
	tally says so, the food is untouched -- and a Draw water order then fills the butt (credited once) and the next
	meal is cooked."""
	var v := _village(3, tick_at(1, 17))
	_stock(v, CARROT, 12000)
	_stock(v, OATS, 8000)
	v.kitchen.keep_water = false
	_open(v)
	var d: KitchenScript.Decision = v.kitchen.decide_meal()
	assert_equal(d.code, KitchenScript.NO_WATER, "refused: no water")
	assert_equal(Words.cant(d.reason, d.fix), "Can't now: the water butt holds 0.0 U; togget's vegetable soup needs 1.0 U a batch (2.0 U for the meal)\nTo fix: Pantry (K) ▸ Kitchen ▸ Draw water",
		"the exact refusal and fix")
	var serial: int = v.incidents.serial_of(KitchenScript.INCIDENT_KEY)
	assert_true(serial >= 0 and v.incidents.is_unresolved(serial), "the incident is open")
	assert_equal(v.incidents.text_of(serial), "No supper tonight: " + d.reason + ". To fix: " + d.fix, "No supper tonight, why, and the fix")
	_run(v, 5 * FRAMES_PER_HOUR)
	var supper := Rules.meal_key(1, Rules.MEAL_SUPPER)
	assert_equal(v.kitchen.meal_keys[v.kitchen.meal_keys.size() - 1], supper, "supper's tally")
	assert_equal([v.kitchen.meal_ate[v.kitchen.meal_ate.size() - 1], v.kitchen.meal_without[v.kitchen.meal_without.size() - 1]],
		[0, 3], "nobody ate")
	for i: int in 3:
		assert_equal([v.kitchen.fed.last_meal[i], v.kitchen.fed.last_outcome[i]], [supper, FedScript.OUTCOME_SKIPPED],
			"resident %d went without supper, recorded" % i)
	assert_equal([v.pantry.milli_of(CARROT), v.pantry.milli_of(OATS), v.kitchen.batches_cooked], [12000, 8000, 0], "nothing cooked")
	_with_night(v)
	_run(v, 1, func() -> bool: return v.calendar.hour_index() % 24 == 7)
	_run(v, 14 * FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() % 24 == 7)
	assert_true(v.kitchen.order_draw(PackedInt32Array([1])).begins_with("Draw 12.0 U of water"), "Draw water: a mouse's carry")
	_run(v, 6 * FRAMES_PER_HOUR, func() -> bool: return v.stores.water_milli_u > 0)
	assert_equal([v.stores.water_milli_u, v.kitchen.poured_water_milli], [12000, 12000], "poured once")
	var next: int = Rules.meal_key(2, Rules.MEAL_BREAKFAST)
	v.kitchen.store.add(Rules.DISH_PORRIDGE, 2, next)
	v.kitchen.store.carry_out()
	v.kitchen._meal[2] = next
	v.kitchen._portion[2] = v.kitchen.store.reserve_one(next)
	v.kitchen._eat_portion(2)
	assert_equal(v.kitchen.portions_eaten, 1, "the village eats again")
	assert_false(v.incidents.is_unresolved(serial), "and the incident is resolved")


func test_no_food_and_no_fuel_are_said_too() -> void:
	"""An empty pantry refuses NO_FOOD naming both categories; with food but no wood, NO_FUEL."""
	var v := _open(_village(2, tick_at(1, 6)))
	var d: KitchenScript.Decision = v.kitchen.decide_meal()
	assert_equal(d.code, KitchenScript.NO_FOOD, "no food")
	assert_true(d.reason.contains("no grain for wild oat porridge") and d.reason.contains("nor roots for togget's vegetable soup"),
		"both dishes named: " + d.reason)
	assert_equal(d.fix, Words.FIX_FOOD, "harvest or plant")
	var w := _village(2, tick_at(1, 6))
	_stock(w, OATS, 4000)
	w.stores.wood_milli_u = 50
	_open(w)
	d = w.kitchen.decide_meal()
	assert_equal([d.code, d.fix], [KitchenScript.NO_FUEL, Words.FIX_FUEL], "no fuel")


func test_hungry_with_no_portion_eats_raw_roots_never_grain() -> void:
	"""REQ-SET-013: at a meal's end a resident at hunger 1500 or less with no portion eats raw-edible food nobody
	reserved, at most 3000 NP (3.75 U of roots at 800 NP a unit), where it is stored; grain is never eaten raw."""
	var v := _village(1, tick_at(1, 9))
	_stock(v, OATS, 4000)
	_stock(v, CARROT, 2000)
	v.kitchen.keep_water = false
	_open(v)
	v.kitchen.fed.hunger[0] = 2400
	_run(v, 11 * FRAMES_PER_HOUR)
	assert_equal(v.kitchen.fed.last_outcome[0], FedScript.OUTCOME_RAW, "ate raw")
	assert_equal(v.pantry.milli_of(CARROT), 0, "the 2.0 U of carrot there was")
	assert_equal(v.kitchen.raw_eaten_milli, 2000, "counted")
	assert_equal(v.pantry.milli_of(OATS), 4000, "never the oats")
	assert_equal(Rules.raw_np_per_u(OATS), 0, "grain is not raw-edible")
	@warning_ignore("integer_division") assert_equal(Rules.RAW_NP_CAP * 1000 / Rules.raw_np_per_u(CARROT), 3750, "a full raw meal is 3.75 U of roots")


func test_a_raw_meal_at_supper_s_end_is_eaten_before_bed() -> void:
	"""With the night running: supper's serving ends at 19:00, an hour before dusk, and the hungry with no portion go
	to eat raw food then; dusk does not take them off it (should they still be eating after dark, they finish, then go
	to bed). The tally posted at the end stands: each counted once."""
	var v := _village(3, tick_at(1, 17))
	_stock(v, CARROT, 30000)
	v.kitchen.keep_water = false
	_open(v)
	_with_night(v)
	for i: int in 3:
		v.kitchen.fed.hunger[i] = 1200
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	_run(v, 3 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.meal_keys.has(supper))
	assert_equal(v.calendar.hour_index() % 24, Rules.END_HOUR[Rules.MEAL_SUPPER], "supper ends at 19:00")
	var at: int = v.kitchen.meal_keys.find(supper)
	var counted: Array[int] = [v.kitchen.meal_raw[at], v.kitchen.meal_without[at]]
	assert_true(counted[0] > 0, "the hungry set off to eat raw")
	assert_true(v.kitchen.final_pending(supper), "the meal is not finalized while raw food is held (decision 0997)")
	_run(v, 8 * FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() % 24 == 23)
	var raw: int = 0
	for i: int in 3:
		raw += 1 if v.kitchen.fed.last_outcome[i] == FedScript.OUTCOME_RAW else 0
	assert_equal(raw, counted[0], "everyone counted as eating raw ate raw, night or no night")
	assert_equal([v.kitchen.meal_raw[at], v.kitchen.meal_without[at]], counted, "the tally stands")
	var final: KitchenScript.MealFinal = v.kitchen.final_of(supper)
	assert_true(final != null, "finalized once the raw meals were eaten")
	if final != null:
		assert_equal([final.raw.size(), final.diners.size(), final.without], [raw, 0, counted[1]], "its raw eaters, committed")


func test_the_cook_takes_its_portion_when_it_decides_to_eat_and_never_waits() -> void:
	"""The cook's portion is reserved as it decides to eat, so diners waiting cannot take it on its way; with none left
	it eats nothing and goes on with its round -- it never sits waiting at a table (that held the whole round)."""
	var v := _village(3, tick_at(1, 1))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	var key: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_true(_run(v, 12 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.store.available(key) > 0) < 12 * FRAMES_PER_HOUR, "out")
	var cook: int = v.kitchen.cook
	var out: int = v.kitchen.store.available(key)
	v.kitchen._cook_eat(cook, key)
	assert_true(v.kitchen._portion[cook] != KitchenScript.FREE, "its portion reserved at once")
	assert_equal(v.kitchen.store.available(key), out - 1, "one fewer for the waiting")
	assert_true(v.kitchen.step_of(cook) != KitchenScript.WORK_WAIT, "it does not wait")
	v.kitchen._clear_role(cook)
	while v.kitchen.store.reserve_one(key) != KitchenScript.FREE:
		pass
	v.kitchen._cook_eat(cook, key)
	assert_equal([v.kitchen._portion[cook], v.kitchen.step_of(cook)], [KitchenScript.FREE, KitchenScript.STEP_DONE],
		"none left: on with its round")


func test_with_the_night_the_cook_rises_at_five_and_is_not_sent_back() -> void:
	"""The night routine's early riser: asleep in the hall at dusk, the cook (with the day's food to fetch and cook) is
	up at 05:00 on its round while the village sleeps, and the night does not send it back to bed."""
	var v := _village(3, tick_at(1, 20))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	_with_night(v)
	_run(v, 4 * FRAMES_PER_HOUR, func() -> bool: return v.brains[0].task is SleepTaskScript)
	assert_true(v.brains[0].task is SleepTaskScript, "the cook asleep")
	_run(v, 10 * FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() % 24 == Rules.COOK_RISE_HOUR)
	@warning_ignore("integer_division") _run(v, FRAMES_PER_HOUR / 2)
	assert_equal(v.kitchen.role_of(0), KitchenScript.ROLE_COOK, "up at 05:00 on its round")
	assert_true(v.brains[1].task is SleepTaskScript, "the village still asleep")
	var stayed: bool = true
	for f in FRAMES_PER_HOUR:
		_run(v, 1)
		stayed = stayed and not (v.brains[0].task is SleepTaskScript)
	assert_true(stayed, "never sent back to bed while it has work")


func test_a_late_breakfast_goes_out_before_supper_is_cooked() -> void:
	"""Breakfast cooked late (07:00) with supper's food already at the cauldron and supper cookable now (the player's
	Cook now): the cook takes breakfast's pot to the table before it cooks supper -- breakfast is not kept in the pot
	till its serving is over."""
	var v := _village(4, tick_at(1, 7))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 12000)
	v.stores.water_milli_u = 30000
	v.brains[0].position = CAULDRON + Vector2(-1.0, 0.0)
	_open(v)
	for key: int in v.kitchen.planned_keys():
		var take: int = v.kitchen._slot_take[v.kitchen._slot_index_of(key)]
		v.kitchen.takes.pick_up(v.pantry, take, 0)
		v.kitchen.takes.put_down(take)
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	v.kitchen._cook_now_key = supper
	var settled := func() -> bool: return v.kitchen.store.at_table() > 0 or v.kitchen.cooked_keys.has(supper) \
			or v.kitchen.wip_key() == supper
	assert_true(_run(v, 6 * FRAMES_PER_HOUR, settled) < 6 * FRAMES_PER_HOUR, "breakfast out, or supper begun")
	assert_true(v.kitchen.store.at_table() > 0, "breakfast went out first")
	assert_false(v.kitchen.cooked_keys.has(supper) or v.kitchen.wip_key() == supper, "supper not begun before it")


func test_leftovers_still_good_at_the_call_cook_fewer_batches() -> void:
	"""Portions left from a meal already over that will still be good at the next call are eaten first, so that meal
	cooks fewer batches: four residents and two leftovers want one batch, not two."""
	var v := _village(4, tick_at(1, 2))
	_stock(v, OATS, 10000)
	_open(v)
	var breakfast: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_equal(v.kitchen.plan_of(breakfast)[1], 2, "four residents: two batches")
	v.kitchen.store.add(Rules.DISH_SOUP, 2, breakfast - 1)
	v.kitchen.store.carry_out()
	_run(v, FRAMES_PER_HOUR + 10)
	assert_equal(v.kitchen.plan_of(breakfast)[1], 1, "two leftovers: one batch")
	v.kitchen.store.add(Rules.DISH_SOUP, 2, breakfast - 1)
	v.kitchen.store.carry_out()
	_run(v, FRAMES_PER_HOUR + 10)
	var d: KitchenScript.Decision = v.kitchen.decide_meal()
	assert_equal([v.kitchen.plan_of(breakfast)[1], d.code], [0, KitchenScript.NOTHING_TO_COOK], "four: nothing to cook")
	assert_equal(d.reason, "breakfast, day 2 has all it needs: its portions are cooked or left over", "said so")


func test_with_only_roots_breakfast_turns_to_soup() -> void:
	"""Ruling 1's alternation gives way when one dish's food is wanting and the other's is there: with roots and no
	grain, breakfast is cooked as soup."""
	var v := _village(2, tick_at(1, 2))
	_stock(v, CARROT, 12000)
	_open(v)
	assert_equal(v.kitchen.plan_of(Rules.meal_key(1, Rules.MEAL_BREAKFAST))[0], Rules.DISH_SOUP, "soup at breakfast")


func test_a_raw_meal_is_at_most_three_thousand_np() -> void:
	"""REQ-SET-013: with plenty of roots, a hungry resident eats raw only enough for 3000 NP -- 3.75 U at 800 NP/U."""
	var v := _village(1, tick_at(1, 9))
	_stock(v, CARROT, 20000)
	v.kitchen.keep_water = false
	_open(v)
	v.kitchen.fed.hunger[0] = 1000
	_run(v, 11 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.raw_eaten_milli > 0)
	assert_equal(v.kitchen.raw_eaten_milli, 3750, "3.75 U")
	assert_true(v.kitchen.fed.hunger[0] <= 1000 + 3000, "at most 3000 NP")


func test_the_night_does_not_send_the_early_riser_back_between_tasks() -> void:
	"""Up early with work to do, the cook between two parts (wandering on its own) is not sent back to bed by the
	night's sweep of the free; anyone else wandering at night is."""
	var v := _village(3, tick_at(1, Rules.COOK_RISE_HOUR))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	_with_night(v)
	_run(v, 2)
	assert_true(v.kitchen.up_early(0), "the cook is up early")
	v.brains[0].release()
	v.brains[1].release()
	v.night._sent_tick.fill(-100000)
	v.night._send_the_free()
	assert_false(v.brains[0].task is SleepTaskScript, "the cook left at its work")
	assert_true(v.brains[1].task is SleepTaskScript, "the rest sent to bed")


func test_the_cook_s_early_supper_is_breakfast_gone_without() -> void:
	"""The cook who ate today's supper early (it left to fetch while breakfast was served) went without breakfast: the
	tally says so and its skipped count rises -- its own record still says supper, so it is not called to it again.
	One who ate breakfast and then supper early ate both: not counted as going without."""
	var v := _open(_village(3, tick_at(1, 8)))
	var breakfast: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	v.kitchen._serving = breakfast
	v.kitchen.fed.ate_meal(0, breakfast + 1, Rules.DISH_SOUP, 0)
	v.kitchen.fed.ate_meal(1, breakfast, Rules.DISH_PORRIDGE, 0)
	v.kitchen.fed.ate_meal(1, breakfast + 1, Rules.DISH_SOUP, 0)
	v.kitchen.fed.ate_meal(2, breakfast, Rules.DISH_PORRIDGE, 0)
	v.kitchen._close_meal(breakfast)
	assert_equal(v.kitchen.meal_without[v.kitchen.meal_without.size() - 1], 1, "one went without breakfast")
	assert_equal([v.kitchen.fed.skipped[0], v.kitchen.fed.last_meal[0]], [1, breakfast + 1], "the cook, still fed supper")


func test_a_meal_is_coming_only_for_its_own_or_earlier_food() -> void:
	"""Breakfast's diners are not kept waiting by supper's batch on the fire: a later meal's cooking is not breakfast
	coming."""
	var v := _open(_village(2, tick_at(1, 10)))
	var breakfast: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	v.kitchen._wip_key = breakfast + 1
	assert_false(v.kitchen.meal_coming(breakfast), "supper cooking is not breakfast coming")
	assert_true(v.kitchen.meal_coming(breakfast + 1), "it is supper coming")
	v.kitchen._wip_key = KitchenScript.FREE


func test_a_diner_waiting_for_a_meal_with_nothing_planned_gets_up() -> void:
	"""Seated waiting for breakfast with nothing out, nothing in the pot, nothing cooking and nothing planned to cook
	(an empty pantry): the diner gets up and goes; with a batch on the fire for it, it waits."""
	var v := _open(_village(2, tick_at(1, 8)))
	var breakfast: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	for wait: bool in [false, true]:
		v.kitchen._role[1] = KitchenScript.ROLE_EAT
		v.kitchen._step[1] = KitchenScript.WORK_WAIT
		v.kitchen._at_work[1] = 1
		v.kitchen._meal[1] = breakfast
		v.kitchen._seat[1] = 0
		v.kitchen._wip_key = breakfast if wait else KitchenScript.FREE
		v.kitchen._watch_tables()
		assert_equal(v.kitchen.step_of(1) == KitchenScript.WORK_WAIT, wait, "waits only for food on its way")
	v.kitchen._wip_key = KitchenScript.FREE
	v.kitchen._clear_role(1)


func test_a_cook_with_food_in_hand_is_not_sent_to_bed() -> void:
	"""Decision 0222: the cook with food picked up -- at the store still, picking more -- delivers it before bed."""
	var v := _village(2, tick_at(1, 17))
	_stock(v, OATS, 8000)
	_open(v)
	var take: int = v.kitchen._slot_take[v.kitchen._slot_order[0]]
	v.kitchen.takes.pick_up(v.pantry, take, 0)
	v.kitchen._role[0] = KitchenScript.ROLE_COOK
	v.kitchen._step[0] = KitchenScript.WORK_PICK
	assert_true(v.kitchen.must_finish(0), "food in hand: it finishes first")
	v.kitchen.takes.put_down(take)
	v.kitchen._role[0] = KitchenScript.ROLE_NONE
	v.kitchen._step[0] = KitchenScript.STEP_DONE


func test_the_planned_meals_stay_in_order_after_one_is_cancelled() -> void:
	"""A slot freed by a cancel is filled with a later meal: the planned meals are still read earliest first."""
	var v := _village(2, tick_at(1, 2))
	_stock(v, OATS, 20000)
	_stock(v, CARROT, 20000)
	_open(v)
	var first: PackedInt32Array = v.kitchen.planned_keys()
	v.kitchen.cancel_meal()
	var keys: PackedInt32Array = v.kitchen.planned_keys()
	assert_equal(keys.size(), first.size(), "the slot refilled")
	for k: int in keys.size() - 1:
		assert_true(keys[k] < keys[k + 1], "earliest first: %s" % [keys])
	assert_equal(keys[0], first[1], "the cancelled meal gone from the front")


# --- interruptions conserve the stock -----------------------------------------------------------------

func _cooking(v: Village) -> bool:
	"""Whether a batch is cooking, part-done."""
	return v.kitchen.wip_key() != KitchenScript.FREE and v.kitchen.wip_progress() > 2000


func _lot_ages(v: Village) -> Dictionary:
	"""Every live lot's (row, serial) -> its age, milli-hours."""
	var ages := {}
	for lot in PantryScript.MAX_LOTS:
		if v.pantry.lot_item(lot) != PantryScript.FREE:
			ages[Vector2i(lot, v.pantry.lot_serial(lot))] = v.pantry.lot_age(lot)
	return ages


func _assert_no_fresher(before: Dictionary, after: Dictionary, what: String) -> void:
	"""No lot still standing is younger than it was."""
	for key in after:
		if before.has(key):
			assert_true(int(after[key]) >= int(before[key]), "%s: lot %s is no fresher" % [what, key])


func _assert_books(v: Village, stocked: int, what: String) -> void:
	"""The pantry lost exactly what the batches took and the hungry ate raw; every portion cooked is held, eaten or
	spoiled."""
	var held: int = 0
	for item in Catalog.ITEM_COUNT:
		held += v.pantry.milli_of(item)
	var portion_spoil: int = v.kitchen.store.spoiled_portions * 2000
	assert_equal(stocked - held, v.kitchen.consumed_food_milli + v.kitchen.raw_eaten_milli + v.pantry.spoiled_milli
		- v.kitchen.cancelled_spoil_milli - portion_spoil, "%s: the pantry's books" % what)
	var by_recipe: int = 0
	for dish in v.kitchen.cooked_dishes:
		by_recipe += Rules.INPUT_MILLI[dish]
	var cancelled: int = 2 * v.kitchen.cancelled_spoil_milli
	var cooking: int = Rules.INPUT_MILLI[v.kitchen.wip_dish()] if v.kitchen.wip_dish() != Rules.NO_DISH else 0
	assert_equal(v.kitchen.consumed_food_milli, by_recipe + cancelled + cooking, "%s: each batch taken once" % what)
	assert_equal(v.kitchen.store.portions() + v.kitchen.portions_eaten + v.kitchen.store.spoiled_portions,
		2 * v.kitchen.batches_cooked, "%s: each portion once" % what)


func test_the_cook_called_away_mid_batch_comes_back_to_it() -> void:
	"""A batch part-cooked when the cook is ordered away waits at the cauldron (its inputs taken once); the cook keeps
	its round on its resume list and, its other work done, finishes the same batch -- nothing taken twice."""
	var v := _village(4, tick_at(1, 1))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	assert_true(_run(v, 8 * FRAMES_PER_HOUR, func() -> bool: return _cooking(v)) < 8 * FRAMES_PER_HOUR, "a batch cooking")
	var cook: int = v.kitchen.cook
	var key: int = v.kitchen.wip_key()
	var progress: int = v.kitchen.wip_progress()
	var taken: int = v.kitchen.consumed_food_milli
	v.brains[cook].order_move(v.brains[cook].position + Vector2(-3.0, 0.0))
	_run(v, 300)
	assert_equal([v.kitchen.wip_key(), v.kitchen.wip_progress(), v.kitchen.consumed_food_milli], [key, progress, taken],
		"the batch waits, its inputs taken once")
	assert_true(v.brains[cook].unfinished_labels().has(Words.ROUND_LABEL), "the round is kept to come back to")
	v.brains[cook].work_done()
	_run(v, 6 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.wip_key() != key or v.kitchen.wip_progress() < progress)
	assert_true(v.kitchen.cooked_keys.has(key), "the same batch finished")
	_assert_books(v, 20000, "called away")


func test_a_diner_called_away_gives_its_portion_back_and_eats_once() -> void:
	"""A diner eating, ordered away, gives its portion back (nothing eaten, nothing lost); called again while the meal
	lasts, it eats -- one portion, once."""
	var v := _village(3, tick_at(1, 1))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	var eating := func() -> bool: return v.kitchen.step_of(1) == KitchenScript.WORK_EAT
	assert_true(_run(v, 12 * FRAMES_PER_HOUR, eating) < 12 * FRAMES_PER_HOUR, "resident 1 eating")
	var out: int = v.kitchen.store.at_table()
	v.brains[1].order_move(v.brains[1].position + Vector2(0.0, 3.0))
	_run(v, 2)
	assert_equal(v.kitchen.store.at_table(), out, "its portion is back on the table")
	assert_false(v.kitchen.fed.had(1, Rules.meal_key(1, Rules.MEAL_BREAKFAST)), "and not eaten")
	v.brains[1].release()
	_run(v, 6 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.fed.had(1, Rules.meal_key(1, Rules.MEAL_BREAKFAST)))
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_ATE, "called again, it ate")
	_assert_books(v, 20000, "diner called away")


func test_food_waiting_in_the_larder_keeps_the_dish() -> void:
	"""Roots fetched for a supper that is over wait in the larder: the next supper is still soup though the pantry has
	no roots left unreserved (ruling 1 turns to the other dish only when neither store nor larder has a batch's)."""
	var v := _village(3, tick_at(1, 1))
	_stock(v, OATS, 40000)
	_stock(v, CARROT, 6000)
	v.stores.water_milli_u = 20000
	_open(v)
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	var fetched := func() -> bool:
		var s: int = v.kitchen._slot_index_of(supper)
		return s >= 0 and v.kitchen.takes.live_milli(v.pantry, v.kitchen._slot_take[s], TakesScript.AT_KITCHEN) >= 3000
	assert_true(_run(v, 12 * FRAMES_PER_HOUR, fetched) < 12 * FRAMES_PER_HOUR, "supper's roots at the kitchen")
	v.kitchen._retire(v.kitchen._slot_index_of(supper))
	assert_equal(v.kitchen.takes.free_milli_of_crop(v.pantry, Rules.INPUT_CROP[Rules.DISH_SOUP]), 0,
		"no roots unreserved in the pantry")
	assert_true(v.kitchen.takes.free_milli_of_crop(v.pantry, Rules.INPUT_CROP[Rules.DISH_PORRIDGE]) >= 2000,
		"grain free for porridge, were the larder not counted")
	assert_equal(v.kitchen._choose_dish(Rules.DISH_SOUP), Rules.DISH_SOUP, "the larder's roots keep it soup")
	_assert_books(v, 46000, "the larder")


func test_a_resident_carrying_a_load_is_not_called_to_the_table() -> void:
	"""Decision 0222: a load in hand is delivered first -- a carrier (a harvest, logs) is not taken off its walk for a
	meal, nor for a raw one; empty-handed again, it may be."""
	var v := _open(_village(3, tick_at(1, 7)))
	assert_true(v.kitchen._may_take(2), "free to be called")
	v.brains[2].carrying = true
	assert_false(v.kitchen._may_take(2), "not while carrying")
	v.brains[2].carrying = false
	assert_true(v.kitchen._may_take(2), "again once delivered")


func _eating_at_the_end(v: Village) -> int:
	"""Run a stocked breakfast until resident 1 is eating, then end the meal's serving there; the meal's key."""
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	var eating := func() -> bool: return v.kitchen.step_of(1) == KitchenScript.WORK_EAT and v.kitchen.must_finish(1)
	assert_true(_run(v, 12 * FRAMES_PER_HOUR, eating) < 12 * FRAMES_PER_HOUR, "resident 1 eating")
	var key: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_true(v.brains[1].task.urgent(), "eating, the night lets it finish first")
	v.kitchen._close_meal(key)
	return key


func test_a_diner_eating_at_the_end_is_counted_once() -> void:
	"""A diner still eating when the serving ends is counted then, as served -- and finishing, it is not counted
	again; nothing is left in the tallies for a meal already over."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	var at: int = v.kitchen.meal_keys.find(key)
	var ate: int = v.kitchen.meal_ate[at]
	assert_true(ate >= 1, "counted at the end")
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.fed.had(1, key))
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_ATE, "it finished")
	assert_equal([v.kitchen.meal_ate[at], v.kitchen._ate_by_meal.has(key)], [ate, false], "and was not counted again")
	_assert_books(v, 20000, "eating at the end")


func test_a_diner_called_away_after_the_end_went_without() -> void:
	"""Counted as served at the end, a diner ordered away before it has eaten gives its portion back: the tally moves
	it to "went without" and its meal is missed -- never both, never neither."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	var at: int = v.kitchen.meal_keys.find(key)
	var counted: Array[int] = [v.kitchen.meal_ate[at], v.kitchen.meal_without[at]]
	v.brains[1].order_move(v.brains[1].position + Vector2(0.0, 3.0))
	_run(v, 2)
	assert_equal([v.kitchen.meal_ate[at], v.kitchen.meal_without[at]], [counted[0] - 1, counted[1] + 1], "moved")
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_SKIPPED, "it went without")
	assert_true(v.kitchen.fed.had(1, key), "and is not called to that meal again")
	_assert_books(v, 20000, "called away after the end")


# --- the meal finalized (decision 0997; Brendan's ruling on review R05) -----------------------------------------

func _finals_of(v: Village, key: int) -> int:
	"""How many events the kitchen has published for meal `key`."""
	var n: int = 0
	for final: KitchenScript.MealFinal in v.kitchen.finals:
		n += 1 if final.key == key else 0
	return n


func test_a_last_bowl_eaten_after_the_end_finalizes_the_meal_with_its_diner() -> void:
	"""BOUNDARY (R05): the serving has ended while resident 1 still eats. No event yet -- the meal waits on its holder;
	once that bowl is eaten the meal is finalized, its committed diners including resident 1, once and only once."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	assert_true(v.kitchen.final_pending(key), "ended with a bowl still held")
	assert_true(v.kitchen.holders_of(key) >= 1, "resident 1 holds it")
	var published: int = v.kitchen.finals_published
	var seen: Array[int] = [0]
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool:
		if v.kitchen.final_of(key) != null and seen[0] == 0:
			seen[0] = 1 if v.kitchen.fed.last_outcome[1] == FedScript.OUTCOME_ATE and v.kitchen.holders_of(key) == 0 else -1
		return seen[0] != 0)
	assert_equal(seen[0], 1, "published only once its last bowl was eaten")
	var final: KitchenScript.MealFinal = v.kitchen.final_of(key)
	assert_true(final != null and final.diners.has(1), "resident 1 among its committed diners")
	assert_false(v.kitchen.final_pending(key), "no longer pending")
	_run(v, FRAMES_PER_HOUR)
	v.kitchen._close_meal(key)
	v.kitchen._publish_finals()
	assert_equal([_finals_of(v, key), v.kitchen.finals_published], [1, published + 1], "published exactly once")


func test_a_last_bowl_given_back_after_the_end_finalizes_the_meal_without_its_diner() -> void:
	"""BOUNDARY (R05): the serving has ended while resident 1 still eats, and it is ordered away before it finishes: the
	bowl goes back, the meal is finalized on that return, resident 1 not among its diners and counted as gone without."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	var at: int = v.kitchen.meal_keys.find(key)
	var without: int = v.kitchen.meal_without[at]
	assert_true(v.kitchen.final_of(key) == null, "no event while the bowl is held")
	v.brains[1].order_move(v.brains[1].position + Vector2(0.0, 3.0))
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.final_of(key) != null)
	var final: KitchenScript.MealFinal = v.kitchen.final_of(key)
	assert_true(final != null, "finalized once the bowl came back")
	if final == null:
		return
	assert_false(final.diners.has(1), "resident 1 did not eat it")
	assert_equal(final.without, without + 1, "and went without, as the corrected tally says")
	assert_equal(final.without, v.kitchen.meal_without[at], "the event carries the corrected tally")
	assert_equal(_finals_of(v, key), 1, "one event")


func test_a_meal_nobody_holds_at_its_end_is_finalized_at_its_end() -> void:
	"""No food: breakfast ends with nobody holding anything, so its event is published in the very update that ended
	it -- no diners, everyone gone without."""
	var v := _open(_village(3, tick_at(1, 1)))
	var ended: Array[bool] = [false]
	_run(v, 10 * FRAMES_PER_HOUR, func() -> bool:
		if v.kitchen.meal_keys.is_empty():
			return false
		ended[0] = v.kitchen.final_of(v.kitchen.meal_keys[-1]) != null
		return true)
	assert_true(ended[0], "published in the update that ended the meal")
	var final: KitchenScript.MealFinal = v.kitchen.final_of(v.kitchen.meal_keys[-1])
	if final == null:
		return
	assert_equal([final.diners.size(), final.raw.size(), final.without, final.serial], [0, 0, 3, 1], "nobody ate")
	assert_equal(v.kitchen.holders_of(final.key), 0, "nobody holds it")


static func tick_hour_of_end(key: int) -> int:
	"""The calendar hour index meal `key`'s serving ends at."""
	@warning_ignore("integer_division") var day: int = key / 2
	return day * SimClock.HOURS_PER_DAY + Rules.END_HOUR[key % 2]


func test_a_held_meal_waits_without_allocating_and_a_skipped_meal_has_lapsed() -> void:
	"""Waiting on a holder costs no objects a frame; a meal a season skip passed over is lapsed (no event will come),
	one ended and finalized is not, nor is one still ahead."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _frame: int in 200:
		v.kitchen._publish_finals()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "200 waits allocate nothing")
	assert_true(v.kitchen.final_pending(key) and not v.kitchen.meal_lapsed(key), "pending, not lapsed")
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.final_of(key) != null)
	_run(v, 4 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.hour_index() >= tick_hour_of_end(key))
	assert_true(v.kitchen.hour_index() >= tick_hour_of_end(key), "the kitchen has run past its end")
	assert_false(v.kitchen.meal_lapsed(key), "finalized: not lapsed")
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	assert_false(v.kitchen.meal_lapsed(supper), "a meal still ahead")
	v.kitchen.skip_to_hour(3 * SimClock.HOURS_PER_DAY + 6)
	assert_true(v.kitchen.meal_lapsed(supper), "skipped over: lapsed")
	assert_true(v.kitchen.final_of(supper) == null, "and never published")


func test_a_holder_is_a_portion_raw_food_or_a_diners_part_for_that_meal() -> void:
	"""`holders_of`: the cook holding its portion, a raw eater's food (held after a blocked walk too), and a diner walking
	to its seat or waiting for a course each hold the meal; a part over, or another meal's, does not."""
	var v := _open(_village(3, tick_at(1, 1)))
	var k: KitchenScript = v.kitchen
	var key: int = Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_equal(k.holders_of(key), 0, "nobody")
	k._meal[0] = key
	k._role[0] = KitchenScript.ROLE_COOK
	k._portion[0] = 0
	assert_equal(k.holders_of(key), 1, "the cook's portion in hand")
	k._portion[0] = KitchenScript.FREE
	k._raw_take[0] = 7
	assert_equal(k.holders_of(key), 1, "raw food reserved")
	k._raw_take[0] = 0
	k._step[0] = KitchenScript.WALK_KITCHEN
	assert_equal(k.holders_of(key), 0, "the cook's round under way holds nothing of it")
	k._step[0] = KitchenScript.STEP_DONE
	k._meal[1] = key
	k._role[1] = KitchenScript.ROLE_EAT
	for step: int in [KitchenScript.WALK_SEAT, KitchenScript.WORK_WAIT]:
		k._step[1] = step
		assert_equal(k.holders_of(key), 1, "a diner's part under way (step %d)" % step)
	k._step[1] = KitchenScript.STEP_DONE
	assert_equal(k.holders_of(key), 0, "its part over")
	k._step[1] = KitchenScript.WORK_WAIT
	assert_equal(k.holders_of(key + 1), 0, "another meal's holder is not this one's")
	k._step[1] = KitchenScript.STEP_DONE
	k._role[1] = KitchenScript.ROLE_NONE
	k._role[0] = KitchenScript.ROLE_NONE


func test_the_finalized_meals_log_is_bounded_and_counts_every_event() -> void:
	"""At most MAX_MEAL_LOG events are kept, oldest dropped; each carries its serial in publication order."""
	var kitchen := KitchenScript.new()
	for key: int in KitchenScript.MAX_MEAL_LOG + 6:
		kitchen._publish(KitchenScript.MealFinal.new(), key)
	assert_equal(kitchen.finals.size(), KitchenScript.MAX_MEAL_LOG, "bounded")
	assert_equal(kitchen.finals_published, KitchenScript.MAX_MEAL_LOG + 6, "every one counted")
	assert_true(kitchen.final_of(0) == null and kitchen.final_of(KitchenScript.MAX_MEAL_LOG + 5) != null, "oldest dropped")
	assert_equal(kitchen.finals[-1].serial, KitchenScript.MAX_MEAL_LOG + 6, "serial in order")


func test_an_event_that_can_never_be_published_is_let_go_at_the_next_end() -> void:
	"""A meal ended quietly by a season skip, whose held bowl is eaten afterwards, starts an event that will never be
	published: the next meal's end lets it go; a meal still waiting on a holder keeps its own."""
	var kitchen := KitchenScript.new()
	kitchen._final_for(1).diners.append(0)
	kitchen._final_for(3).diners.append(1)
	kitchen._final_for(6).diners.append(2)
	kitchen._final_pending.append(3)
	kitchen._forget_unfinalizable(5)
	assert_equal([kitchen._building.has(1), kitchen._building.has(3), kitchen._building.has(6)], [false, true, true],
		"the skipped meal's let go; the pending and the later ones kept")


func test_a_cancelled_meal_gives_its_food_back_and_spoils_half_a_batch_cooking() -> void:
	"""Cancel with a batch cooking: REQ-SET-094 -- half its food's mass becomes spoiled food, no portions; the meal's
	other food is given back untouched (no lot fresher), what was fetched stays fetched for the next meal."""
	var v := _village(4, tick_at(1, 1))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	assert_true(_run(v, 8 * FRAMES_PER_HOUR, func() -> bool: return _cooking(v)) < 8 * FRAMES_PER_HOUR, "a batch cooking")
	var dish: int = v.kitchen.wip_dish()
	var batches: int = v.kitchen.batches_cooked
	var ages := _lot_ages(v)
	var said: String = v.kitchen.cancel_meal()
	assert_true(said.ends_with("what was fetched stays at the kitchen for the next meal)"), said)
	assert_equal(v.kitchen.wip_key(), KitchenScript.FREE, "the batch is gone")
	@warning_ignore("integer_division") assert_equal(v.pantry.spoiled_milli, Rules.INPUT_MILLI[dish] / 2, "half its food spoiled")
	assert_equal(v.kitchen.batches_cooked, batches, "no portions from it")
	_assert_no_fresher(ages, _lot_ages(v), "cancel")
	_assert_books(v, 20000, "cancel")


func test_night_falling_mid_batch_keeps_it_for_the_morning() -> void:
	"""Supper over, tomorrow's breakfast ordered cooked now (Cook now; twelve residents, six batches -- 72 WU, over an
	hour; its food already fetched to the cauldron, the cook beside it) when dusk takes the cook to bed with a batch on
	the fire: the batch waits, its food taken once; up early, the cook finishes it -- exactly one more batch of that
	meal. The reserved food ages through the night like any (no lot is made fresher)."""
	var v := _village(12, tick_at(1, NightScript.DUSK_HOUR - 1) + 300)
	_stock(v, CARROT, 30000)
	_stock(v, OATS, 20000)
	v.stores.water_milli_u = 30000
	_open(v)
	_with_night(v)
	var tomorrow: int = Rules.meal_key(2, Rules.MEAL_BREAKFAST)
	for key: int in v.kitchen.planned_keys():
		var take: int = v.kitchen._slot_take[v.kitchen._slot_index_of(key)]
		v.kitchen.takes.pick_up(v.pantry, take, 0)
		v.kitchen.takes.put_down(take)
	v.brains[0].position = CAULDRON + Vector2(-1.0, 0.0)
	var said: String = v.kitchen.order_cook(PackedInt32Array())
	assert_true(said.begins_with("Cook breakfast now: 6 batches"), said)
	var late := func() -> bool: return v.calendar.hour_index() % 24 == NightScript.DUSK_HOUR \
			and v.kitchen.wip_key() == tomorrow
	assert_true(_run(v, 2 * FRAMES_PER_HOUR, late) < 2 * FRAMES_PER_HOUR, "tomorrow's breakfast on the fire as dusk falls")
	_run(v, 30)
	var taken: int = v.kitchen.consumed_food_milli
	assert_equal(v.kitchen.wip_key(), tomorrow, "still on the fire after dusk")
	assert_true(v.brains[v.kitchen.cook].task is SleepTaskScript, "the cook gone to bed")
	var done_before: int = _count_of(v.kitchen.cooked_keys, tomorrow)
	var ages := _lot_ages(v)
	_run(v, 10 * FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() % 24 == Rules.COOK_RISE_HOUR)
	assert_equal([v.kitchen.wip_key(), v.kitchen.consumed_food_milli], [tomorrow, taken], "untouched all night")
	_assert_no_fresher(ages, _lot_ages(v), "night")
	_run(v, 8 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.wip_key() != tomorrow)
	assert_equal(_count_of(v.kitchen.cooked_keys, tomorrow), done_before + 1, "finished in the morning, once")
	_assert_books(v, 50000, "night")


func _count_of(keys: PackedInt32Array, key: int) -> int:
	"""How many times `key` is in `keys`."""
	var n: int = 0
	for k: int in keys:
		n += 1 if k == key else 0
	return n


# --- the kitchen on the work board (decision 0411 with 0381) -------------------------------------------------

func _board(v: Village) -> BoardScript:
	"""A work board over the village's residents with the kitchen's adapter and its meals gate (demo_work.gd
	`add_kitchen`)."""
	var who: Array = v.get_meta(&"who")
	var board := BoardScript.new()
	board.bind(v.brains, who[0], who[2])
	board.add_source(KitchenWork.new(v.kitchen, v.brains))
	board.set_needs_gate(v.kitchen.kept_for_meals)
	return board


func _role_holder(v: Village, role: int) -> int:
	"""Who has kitchen `role` now (-1: nobody)."""
	for i in v.brains.size():
		if v.kitchen.role_of(i) == role:
			return i
	return -1


func test_the_work_board_lists_the_cook_and_the_drawers_and_never_claims_them() -> void:
	"""The cook's round and a water draw are rows on the Work screen in the kitchen's words, with their worker; the
	board's commands refuse with the way to change them and change nothing; and the board keeps its hands off whoever
	the kitchen has."""
	var v := _village(3, tick_at(1, 2))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 12000)
	_open(v)
	var board := _board(v)
	assert_false(v.kitchen.kept_for_meals(-1), "nobody by that number")
	_run(v, 4 * FRAMES_PER_HOUR, func() -> bool: return _role_holder(v, KitchenScript.ROLE_COOK) >= 0 \
		and _role_holder(v, KitchenScript.ROLE_DRAW) >= 0)
	var cook: int = _role_holder(v, KitchenScript.ROLE_COOK)
	var drawer: int = _role_holder(v, KitchenScript.ROLE_DRAW)
	assert_true(cook >= 0 and drawer >= 0, "a cook and a drawer at work (%d, %d)" % [cook, drawer])
	var src := board.source(WorkIds.SOURCE_KITCHEN)
	var task := TaskRecord.new()
	assert_true(board.fill(WorkIds.SOURCE_KITCHEN, cook, task), "the cook's round is a row")
	assert_equal([task.action, task.worker, task.cancel_refusal], [KitchenWork.COOK_ACTION, cook,
		KitchenWork.BY_KITCHEN], "Cook, by its cook, run by the kitchen")
	assert_false(task.reason.is_empty(), "in the kitchen's words")
	assert_true(board.fill(WorkIds.SOURCE_KITCHEN, drawer, task), "the draw is a row")
	assert_equal(task.action, KitchenWork.DRAW_ACTION, "Draw water")
	assert_equal(task.point, v.places.well, "at the well")
	for i in v.brains.size():
		var role: int = v.kitchen.role_of(i)
		assert_equal(src.live(i), role == KitchenScript.ROLE_COOK or role == KitchenScript.ROLE_DRAW,
			"resident %d: a row only for the round or a draw" % i)
	assert_false(board.cancel(WorkIds.SOURCE_KITCHEN, cook).is_empty(), "Cancel refuses")
	assert_false(board.reassign(WorkIds.SOURCE_KITCHEN, drawer, cook).is_empty(), "Reassign refuses")
	assert_equal([v.kitchen.role_of(cook), v.kitchen.role_of(drawer)], [KitchenScript.ROLE_COOK,
		KitchenScript.ROLE_DRAW], "and nothing changed")
	var counts := PackedInt32Array()
	board.cancel_all_counts_into(counts)
	assert_equal(counts[WorkIds.SOURCE_KITCHEN], 0, "Cancel all work leaves the kitchen alone")
	assert_true(v.kitchen.kept_for_meals(cook) and v.kitchen.kept_for_meals(drawer), "kept for the meals")
	assert_false(board.idle(cook) or board.idle(drawer), "so the board claims nothing for them")


func test_the_work_board_hands_out_no_work_at_mealtime() -> void:
	"""With breakfast on its way, a free resident who has not eaten is the meal's: the board's needs gate keeps it out
	of claims until it has eaten; then it is free for work again."""
	var v := _village(3, tick_at(1, 1))
	_stock(v, OATS, 10000)
	_stock(v, CARROT, 10000)
	v.stores.water_milli_u = 20000
	_open(v)
	var board := _board(v)
	var breakfast := Rules.meal_key(1, Rules.MEAL_BREAKFAST)
	assert_false(v.kitchen.kept_for_meals(2), "before the meal: free for work")
	assert_true(board.idle(2), "and the board may claim it")
	assert_true(_run(v, 12 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.serving() == breakfast \
		and v.kitchen.meal_coming(breakfast)) < 12 * FRAMES_PER_HOUR, "breakfast on its way")
	v.kitchen.update()
	assert_true(v.kitchen.kept_for_meals(2), "due at the table")
	assert_false(board.idle(2), "so the board hands it no work")
	_run(v, 12 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.fed.had(2, breakfast) and v.kitchen.role_of(2) \
		== KitchenScript.ROLE_NONE)
	assert_true(v.kitchen.fed.had(2, breakfast), "it ate")
	assert_false(v.kitchen.kept_for_meals(2), "fed and done: the meals let it go")



# --- decision 0421: the re-timed day ----------------------------------------------------------------------

func test_the_intervals_keep_their_real_seconds() -> void:
	"""Decision 0421: the hand-out cadence and the diners' re-call keep the real seconds they had on the old calendar --
	half a second, and the night's 1.27 s -- now that a calendar tick is a thirtieth of a second at 1x."""
	@warning_ignore("integer_division") assert_equal(KitchenScript.PICKUP_TICKS * 1000000 / SimClock.TICKS_PER_SECOND, 500000, "half a second")
	assert_equal(KitchenScript.RESEND_TICKS, NightScript.RESEND_TICKS, "the night's re-send")
	@warning_ignore("integer_division") assert_equal(NightScript.RESEND_TICKS * 1000 / SimClock.TICKS_PER_SECOND, 1266, "1.27 s")


func test_the_tab_note_says_the_rules_hours() -> void:
	"""The Kitchen tab's note is filled from meal_rules.gd's hours, so it cannot drift from them."""
	assert_true(Words.tab_note().begins_with("Breakfast is called at 07:00 and supper at 17:00. The cook is up at 05:00 "
		+ "to cook breakfast, and cooks supper from 15:00;"), Words.tab_note())


func test_food_fetched_for_a_later_meal_does_not_keep_the_cook_on_duty() -> void:
	"""Supper's food put down at the cauldron at 10:00 (supper is cooked from 15:00): the cook is not on duty, so it may
	be called to the table like anyone. Ordered cooked now with the butt empty, the same food keeps it on duty (waiting
	for water it may draw itself)."""
	var v := _village(3, tick_at(1, 10))
	_stock(v, CARROT, 12000)
	v.kitchen.keep_water = false
	_open(v)
	for key: int in v.kitchen.planned_keys():
		var take: int = v.kitchen._slot_take[v.kitchen._slot_index_of(key)]
		v.kitchen.takes.pick_up(v.pantry, take, 0)
		v.kitchen.takes.put_down(take)
	assert_false(v.kitchen._on_duty(0), "supper's food waits for 15:00: the cook is free")
	assert_true(v.kitchen._may_call(0), "and may be called to a meal")
	v.kitchen._cook_now_key = Rules.meal_key(1, Rules.MEAL_SUPPER)
	v.kitchen._duty_tick = -1
	assert_true(v.kitchen._on_duty(0), "ordered cooked now: on duty")


func _raw_walker(v: Village) -> void:
	"""Resident 1 hungry at supper's end with no supper (the butt empty): it sets off for its raw meal."""
	_stock(v, CARROT, 30000)
	v.kitchen.keep_water = false
	_open(v)
	v.kitchen.fed.hunger[1] = 1200
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.step_of(1) == KitchenScript.WALK_RAW)
	_run(v, 2)
	assert_equal(v.kitchen.step_of(1), KitchenScript.WALK_RAW, "walking to its raw meal")


func test_a_raw_meal_whose_walk_was_given_up_sets_off_again_after_a_pause() -> void:
	"""Decision 0421: a raw meal comes after the serving's end, so a walk given up (blocked) is not the end of it: the
	food stays reserved, and once RESEND_TICKS have passed it sets off again; it eats raw."""
	var v := _village(3, tick_at(1, 18))
	_raw_walker(v)
	v.brains[1]._abandon_trip()
	assert_equal([v.kitchen._raw_retry[1], v.kitchen.role_of(1)], [1, KitchenScript.ROLE_NONE], "held, off its walk")
	assert_true(v.kitchen._raw_take[1] > 0, "its food still reserved")
	_run(v, KitchenScript.RESEND_TICKS - 2)
	assert_equal(v.kitchen.role_of(1), KitchenScript.ROLE_NONE, "not before the pause")
	_run(v, KitchenScript.RESEND_TICKS)
	assert_equal([v.kitchen.role_of(1), v.kitchen.step_of(1), v.kitchen._fails[1]], [KitchenScript.ROLE_EAT,
		KitchenScript.WALK_RAW, 1], "off again, one walk failed")
	_run(v, 2 * FRAMES_PER_HOUR, func() -> bool: return v.kitchen.fed.last_outcome[1] == FedScript.OUTCOME_RAW)
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_RAW, "it ate raw")


func test_a_raw_meal_given_up_by_an_order_or_the_night_is_gone_without() -> void:
	"""Only a walk the resident gave up is tried again: ordered away, it goes without at once; held for a retry when
	dusk takes it to bed, it goes without then -- its food given back either way, not kept reserved all night."""
	var v := _village(3, tick_at(1, 18))
	_raw_walker(v)
	v.brains[1].order_move(v.brains[1].position + Vector2(0.0, 3.0))
	assert_equal([v.kitchen._raw_retry[1], v.kitchen._raw_take[1]], [0, 0], "an order: not held, the food back")
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_SKIPPED, "it went without")
	var w := _village(3, tick_at(1, 18))
	_raw_walker(w)
	_with_night(w)
	w.brains[1]._abandon_trip()
	w.brains[1].order_move(w.brains[1].position + Vector2(1.0, 0.0))
	w.brains[1].release()
	assert_equal(w.kitchen._raw_retry[1], 1, "held")
	w.calendar.tick = tick_at(1, NightScript.DUSK_HOUR)
	_run(w, 2 * KitchenScript.RESEND_TICKS, func() -> bool: return w.kitchen._raw_retry[1] == 0)
	assert_true(w.brains[1].task is SleepTaskScript, "sent to bed at dusk")
	assert_equal([w.kitchen._raw_retry[1], w.kitchen._raw_take[1], w.kitchen.role_of(1)], [0, 0,
		KitchenScript.ROLE_NONE], "given up at bedtime, the food back")
	assert_equal(w.kitchen.fed.last_outcome[1], FedScript.OUTCOME_SKIPPED, "it went without")


func test_a_held_raw_meal_waits_out_an_order_and_is_kept_from_the_work_board() -> void:
	"""Held for a retry, a resident is kept for the meals (the work board claims nothing for it, and it is handed no
	water to draw); a player's order is waited out, never overridden; three walks given up and it goes without."""
	var v := _village(3, tick_at(1, 18))
	_raw_walker(v)
	v.brains[1]._abandon_trip()
	assert_true(v.kitchen.kept_for_meals(1), "kept for its meal")
	assert_false(v.kitchen._free_for(1), "not free for the kitchen's other work")
	v.brains[1].order_move(v.brains[1].position + Vector2(0.0, 2.0))
	_run(v, 3 * KitchenScript.RESEND_TICKS)
	assert_equal([v.brains[1].order, v.kitchen.role_of(1), v.kitchen._raw_retry[1]], [BrainScript.ORDER_MOVE,
		KitchenScript.ROLE_NONE, 1], "the order stands; still held")
	v.brains[1].release()
	_run(v, 2 * KitchenScript.RESEND_TICKS, func() -> bool: return v.kitchen.role_of(1) == KitchenScript.ROLE_EAT)
	assert_equal(v.kitchen.step_of(1), KitchenScript.WALK_RAW, "free again: off to eat")
	for attempt: int in 2:
		_run(v, 2)
		v.brains[1]._abandon_trip()
		_run(v, 2 * KitchenScript.RESEND_TICKS, func() -> bool: return v.kitchen.role_of(1) == KitchenScript.ROLE_EAT \
			or v.kitchen._raw_take[1] == 0)
	assert_equal([v.kitchen._raw_retry[1], v.kitchen._raw_take[1], v.kitchen.role_of(1)], [0, 0,
		KitchenScript.ROLE_NONE], "a third walk given up: the meal let go")
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_SKIPPED, "it went without")


func test_a_held_raw_meal_not_to_be_taken_when_free_is_gone_without() -> void:
	"""Held for a retry, a resident the water holds when it comes free (an emergency of the river) is not sent off:
	the raw meal is given up -- it went without, its food given back."""
	var v := _village(3, tick_at(1, 18))
	_raw_walker(v)
	v.brains[1]._abandon_trip()
	v.brains[1].water_hold = true
	_run(v, 2 * KitchenScript.RESEND_TICKS)
	assert_equal([v.kitchen._raw_retry[1], v.kitchen._raw_take[1], v.kitchen.role_of(1)], [0, 0,
		KitchenScript.ROLE_NONE], "given up, the food back")
	assert_equal(v.kitchen.fed.last_outcome[1], FedScript.OUTCOME_SKIPPED, "it went without")


func test_a_held_raw_eater_called_to_the_next_meal_went_without_the_last() -> void:
	"""A raw meal still held when the next meal is called (its resident kept busy by an order till then): the call
	gives the raw food back and the tally of the meal it missed moves it to "went without" -- never counted as fed."""
	var v := _village(3, tick_at(1, 18))
	_raw_walker(v)
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	var at: int = v.kitchen.meal_keys.find(supper)
	var counted: Array[int] = [v.kitchen.meal_raw[at], v.kitchen.meal_without[at]]
	v.brains[1]._abandon_trip()
	var next: int = Rules.meal_key(2, Rules.MEAL_BREAKFAST)
	v.kitchen.store.add(Rules.DISH_PORRIDGE, 2, next)
	v.kitchen.store.carry_out()
	v.kitchen._open_meal(next)
	v.kitchen._call_diners()
	assert_equal([v.kitchen.meal_raw[at], v.kitchen.meal_without[at]], [counted[0] - 1, counted[1] + 1],
		"supper's tally: went without")
	assert_equal([v.kitchen._raw_take[1], v.kitchen._raw_retry[1]], [0, 0], "the raw food given back")
	assert_equal([v.kitchen.role_of(1), v.kitchen.meal_of(1)], [KitchenScript.ROLE_EAT, next], "called to breakfast")
	assert_true(v.kitchen.fed.had(1, supper), "supper recorded as missed")


func test_a_store_walk_that_failed_goes_to_a_spot_clear_of_those_standing() -> void:
	"""The first walk to a store goes to the spot nearest it; after a failed walk, to one clear of everyone standing
	still -- a second raw eater does not walk into the first, eating at the store."""
	var v := _open(_village(3, tick_at(1, 10)))
	v.brains[2].start_at(STORE_AT, 0.0, -1, -1)
	v.kitchen._location[1] = 0
	v.kitchen._step[1] = KitchenScript.WALK_RAW
	assert_true(v.kitchen._store_spot(1, v.brains[1]).distance_to(STORE_AT) < 0.01, "first: the store's own spot")
	v.kitchen._fails[1] = 1
	assert_true(v.kitchen._store_spot(1, v.brains[1]).distance_to(STORE_AT) > 0.4, "after a failure: clear of resident 2")


func test_an_earlier_meal_still_held_when_the_next_ends_is_settled_and_published() -> void:
	"""THE DEADLINE (the R05 review's M1): a holder that never lets go (here: resident 1's part left hanging) cannot stall
	a meal for good -- when the next meal's serving ends, what it still holds goes back, it went without, its part and
	its brain's task end, and the earlier meal's event is published at that update's end, once."""
	var v := _village(3, tick_at(1, 1))
	var key: int = _eating_at_the_end(v)
	var at: int = v.kitchen.meal_keys.find(key)
	var without: int = v.kitchen.meal_without[at]
	assert_true(v.kitchen.final_pending(key) and v.kitchen.holders_of(key) >= 1, "held at its end")
	var next: int = key + 1
	v.kitchen._final_for(key - 2).diners.append(0)
	v.kitchen._serving = next
	v.kitchen._close_meal(next)
	assert_false(v.kitchen._building.has(key - 2), "an earlier event that can never be published let go at the end")
	assert_equal(v.kitchen.holders_of(key), 0, "the next meal's end gave every held part of it back")
	var task: Object = v.brains[1].task
	assert_true(task == null or task.get_script() != KitchenScript.TaskScript, "resident 1's kitchen task let go")
	v.kitchen._publish_finals()
	var final: KitchenScript.MealFinal = v.kitchen.final_of(key)
	assert_true(final != null, "the overdue meal published")
	if final == null:
		return
	assert_false(final.diners.has(1), "resident 1 did not eat it")
	assert_true(final.without > without, "it (with any other holder) went without it")
	assert_equal(final.without, v.kitchen.meal_without[at], "as the corrected tally says")
	assert_equal(final.diners.size() + final.raw.size() + final.without, 3, "every resident counted once")
	assert_equal(_finals_of(v, key), 1, "once")
	assert_true(v.kitchen.final_of(next) != null, "the next meal, held by nobody, published too")
	var n: int = v.kitchen.meal_keys.find(next)
	assert_equal(v.kitchen.meal_ate[n] + v.kitchen.meal_raw[n] + v.kitchen.meal_without[n], 3,
		"the closing meal counts every resident, the one freed from the overdue meal too")
	var later: KitchenScript.MealFinal = v.kitchen.final_of(next)
	if later != null:
		assert_equal(later.diners.size() + later.raw.size() + later.without, 3, "and so does its event")
	assert_true(v.kitchen.fed.had_exact(1, next), "resident 1's own record holds the closing meal (eaten, raw or missed)")
