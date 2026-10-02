extends "res://test/framework/test_case.gd"
## The village goals and milestones (decision 0781; demo/goals/): the goal book's registration and its refusals, the
## game-hour tick (nothing evaluated between hours), a goal reached once and kept, a part the demo does not model
## blocking its goal until a later feature binds a measure, the built-in data (the GDD's M1-M4 as stated, the village
## goals), the ledger's running counts from the kitchen's and the planner record's logs, the owner's news, the Goals tab
## and the hourly path's allocation. Off-tree; no staged assets.

const BookScript := preload("res://demo/goals/goal_book.gd")
const LedgerScript := preload("res://demo/goals/goals_ledger.gd")
const VillageScript := preload("res://demo/goals/village_goals.gd")
const GoalsScript := preload("res://demo/goals/demo_goals.gd")
const PageScript := preload("res://demo/goals/goals_page.gd")
const WindowScript := preload("res://demo/guide/guide_window.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HOUR_TICKS: int = SimClock.TICKS_PER_HOUR
const DAY_TICKS: int = SimClock.TICKS_PER_DAY
## An hour index long after every meal a test tallies (its day has ended).
const LATE: int = 1000 * SimClock.HOURS_PER_DAY


## A world whose bridges and tunnels are counted as the test says.
class CountedWorld extends "res://demo/guide/guide_world.gd":
	func open_bridges() -> int:
		"""Two."""
		return 2

	func open_tunnels() -> int:
		"""Three."""
		return 3


## A kitchen whose Ready food is fixed.
class StockedKitchen extends "res://demo/kitchen/kitchen.gd":
	func days_of_meals_milli() -> int:
		"""2.5 days."""
		return 2500

var _nodes: Array[Node] = []
## A measure the tests move by hand, and how often it was read.
var _level: int = 0
var _reads: int = 0


func after_each() -> void:
	"""Free what a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _world_of(goals: GoalsScript) -> WorldScript:
	"""The world a goals owner measures."""
	return goals.village.world


func _measure() -> int:
	"""The hand-moved level, counting the read."""
	_reads += 1
	return _level


func _one(key: StringName, target: int, measure: Callable = Callable()) -> Array[BookScript.Part]:
	"""A single-part list."""
	var parts: Array[BookScript.Part] = [BookScript.part(key, "Level", target, BookScript.UNIT_COUNT, measure)]
	return parts


func _world(residents: int = 9) -> WorldScript:
	"""A world over a calendar, the village stores, a pantry, a kitchen (unconfigured) and `residents` brains."""
	var world := WorldScript.new()
	world.calendar = CalendarScript.new()
	world.stores = ServicesScript.new().stores
	world.pantry = PantryScript.new(StorageScript.new(Vector2.ZERO))
	world.kitchen = KitchenScript.new()
	for i: int in residents:
		world.brains.append(BrainScript.new())
	return world


# --- the book ----------------------------------------------------------------------------------------------------------

func test_register_refuses_in_words() -> void:
	"""No id, a repeated id, no title, no parts, a part without a positive target, an unknown unit or group, two parts
	sharing a key: each refused in its own words, nothing added."""
	var book := BookScript.new()
	assert_equal(book.register(&"a", "A", "why", _one(&"x", 1)), "", "taken")
	assert_equal(book.register(&"", "B", "", _one(&"x", 1)), BookScript.REFUSE_ID, "an id")
	assert_equal(book.register(&"a", "B", "", _one(&"x", 1)), BookScript.REFUSE_DUPLICATE, "unique")
	assert_equal(book.register(&"b", "  ", "", _one(&"x", 1)), BookScript.REFUSE_TITLE, "a title")
	assert_equal(book.register(&"b", "B", "", [] as Array[BookScript.Part]), BookScript.REFUSE_PARTS, "a part")
	assert_equal(book.register(&"b", "B", "", _one(&"x", 0)), BookScript.REFUSE_TARGET, "a positive target")
	var odd: Array[BookScript.Part] = [BookScript.part(&"x", "X", 1, BookScript.UNIT_LIMIT)]
	assert_equal(book.register(&"b", "B", "", odd), BookScript.REFUSE_UNIT, "a known unit")
	assert_equal(book.register(&"b", "B", "", _one(&"x", 1), BookScript.GROUP_COUNT), BookScript.REFUSE_GROUP,
		"a known group")
	var twins: Array[BookScript.Part] = [BookScript.part(&"x", "X", 1), BookScript.part(&"x", "Y", 1)]
	assert_equal(book.register(&"b", "B", "", twins), BookScript.REFUSE_KEY, "distinct keys")
	assert_equal(book.goals.size(), 1, "only the first")
	assert_equal(book.count(BookScript.GROUP_VILLAGE), 1, "a village goal by default")


func test_the_book_evaluates_only_on_a_new_game_hour() -> void:
	"""The first update evaluates; the same hour again reads nothing; the next hour reads again."""
	var book := BookScript.new()
	book.register(&"a", "A", "", _one(&"x", 5, _measure))
	_reads = 0
	assert_true(book.update(10), "the first look evaluates")
	assert_equal(_reads, 1, "read once")
	for k: int in 50:
		assert_false(book.update(10), "the same hour: nothing")
	assert_equal(_reads, 1, "not read again within the hour")
	assert_true(book.update(11), "a new hour")
	assert_equal([_reads, book.evaluations, book.hour_seen()], [2, 2, 11], "read at the hour")


func test_a_goal_is_reached_once_and_stays_reached() -> void:
	"""Below its target nothing; reaching it is said once with its hour; falling back keeps it reached (its value as it
	stands); later hours say nothing more."""
	var book := BookScript.new()
	var said: Array[StringName] = []
	book.reached = func(goal: BookScript.Goal) -> void: said.append(goal.id)
	book.register(&"a", "A", "", _one(&"x", 5, _measure))
	_level = 4
	book.update(1)
	assert_false(book.goal(&"a").done, "4 of 5")
	assert_equal(book.goal(&"a").parts[0].value, 4, "its value read")
	_level = 5
	book.update(2)
	assert_true(book.goal(&"a").done, "5 of 5: reached at the boundary")
	assert_equal(book.goal(&"a").done_hour, 2, "at hour 2")
	_level = 1
	book.update(3)
	book.update(4)
	assert_true(book.goal(&"a").done, "stays reached")
	assert_equal(book.goal(&"a").parts[0].value, 1, "its value goes on being shown")
	assert_equal(said, [&"a"] as Array[StringName], "said once")
	assert_equal(book.done_count(BookScript.GROUP_VILLAGE), 1, "counted")


func test_every_part_must_be_met() -> void:
	"""A goal of two parts: one met is not enough."""
	var book := BookScript.new()
	var parts: Array[BookScript.Part] = [BookScript.part(&"x", "X", 5, BookScript.UNIT_COUNT, _measure),
		BookScript.part(&"y", "Y", 1, BookScript.UNIT_FLAG, func() -> int: return 0)]
	book.register(&"two", "Two", "", parts)
	_level = 9
	book.update(1)
	assert_equal(book.goal(&"two").met_parts(), 1, "one of two")
	assert_false(book.goal(&"two").done, "not reached")


func test_an_unmodelled_part_blocks_until_a_measure_is_bound() -> void:
	"""A part declared without a measure is never met (its value UNREAD), so its goal is not reached; a later feature
	binds one and the goal is reached at the next hour. bind_measure refuses an unknown goal or part, an invalid
	measure, and a goal already reached."""
	var book := BookScript.new()
	book.register(&"m", "M", "", _one(&"fuel", 3))
	book.update(1)
	assert_false(book.goal(&"m").is_measured(), "not modelled")
	assert_equal(book.goal(&"m").parts[0].value, BookScript.UNREAD, "unread")
	assert_false(book.goal(&"m").done, "cannot be reached")
	assert_false(book.bind_measure(&"nope", &"fuel", _measure), "no such goal")
	assert_false(book.bind_measure(&"m", &"nope", _measure), "no such part")
	assert_false(book.bind_measure(&"m", &"fuel", Callable()), "an invalid measure")
	_level = 3
	assert_true(book.bind_measure(&"m", &"fuel", _measure), "bound")
	assert_true(book.update(1) == false and not book.goal(&"m").done, "not before the next hour")
	book.update(2)
	assert_true(book.goal(&"m").done, "reached at the next hour")
	assert_false(book.bind_measure(&"m", &"fuel", _measure), "a reached goal is not rebound")


func test_amounts_read_as_the_player_reads_them() -> void:
	"""Counts, units, days and yes / not yet; a negative shown as nothing."""
	assert_equal(BookScript.amount_text(BookScript.UNIT_COUNT, 12), "12", "count")
	assert_equal(BookScript.amount_text(BookScript.UNIT_MILLI, 40000), "40.0 U", "units")
	assert_equal(BookScript.amount_text(BookScript.UNIT_MILLI, 1999), "1.9 U", "units, floored")
	assert_equal(BookScript.amount_text(BookScript.UNIT_DAYS, 2500), "2.5 days", "days")
	assert_equal(BookScript.amount_text(BookScript.UNIT_FLAG, 1), "yes", "yes")
	assert_equal(BookScript.amount_text(BookScript.UNIT_FLAG, 0), "not yet", "not yet")
	assert_equal(BookScript.amount_text(BookScript.UNIT_COUNT, -1), "0", "never negative")


# --- the built-in goals ------------------------------------------------------------------------------------------------

func test_the_built_in_goals_are_the_gdds_milestones_then_the_village_goals() -> void:
	"""Every row is taken: four milestones first, each as the GDD's table states it (M1: day 4, 12 residents, 200
	portions; M4: fuel for 18 winter days, unmodelled, for the winter-fuel work to bind), then the village goals; every
	goal has a why and something to say."""
	var book := BookScript.new()
	var village := VillageScript.new(_world(), LedgerScript.new(), null)
	assert_equal(village.register_all(book), VillageScript.GOALS.size(), "all taken")
	assert_equal(book.count(BookScript.GROUP_MILESTONE), 4, "M1-M4")
	assert_equal(book.goals[0].id, &"m1_settled_hearth", "M1 first")
	assert_equal([book.part_of(&"m1_settled_hearth", &"day").target, book.part_of(&"m1_settled_hearth", &"residents").target,
		book.part_of(&"m1_settled_hearth", &"portions").target], [4, 12, 200], "M1 as the GDD states it")
	var fuel: BookScript.Part = book.part_of(&"m4_hearth_charter", &"fuel")
	assert_equal([fuel.target, fuel.unit, fuel.is_measured()], [18000, BookScript.UNIT_DAYS, false], "M4 fuel>=18 days")
	assert_equal(book.part_of(&"m3_deep_roots", &"food_days").target, 8000, "M3 food-days>=8")
	assert_equal(book.part_of(&"every_dish", &"dishes").target, Rules.DISH_COUNT, "every dish the kitchen has")
	for goal: BookScript.Goal in book.goals:
		assert_false(goal.why.is_empty() or goal.said.is_empty(), "%s has a why and a line" % goal.id)
	for k: int in 4:
		assert_equal(book.goals[k].group, BookScript.GROUP_MILESTONE, "milestones first")


func test_the_milestones_cannot_be_reached_in_the_nine_resident_demo() -> void:
	"""Day 4 and 200 portions prepared, but nine residents: M1 stays open, its residents 9 of 12; with twelve it would
	be met (the measure is the village's own count)."""
	var world := _world(9)
	world.calendar.tick = 3 * DAY_TICKS - SimClock.CALENDAR_OFFSET_TICKS
	var ledger := LedgerScript.new()
	ledger.portions_prepared = 200
	var book := BookScript.new()
	VillageScript.new(world, ledger, null).register_all(book)
	book.update(world.calendar.hour_index())
	var m1: BookScript.Goal = book.goal(&"m1_settled_hearth")
	assert_equal([m1.parts[0].value, m1.parts[1].value, m1.parts[2].value], [4, 9, 200], "day 4, 9 residents, 200")
	assert_false(m1.done, "nine of twelve")
	for i: int in 3:
		world.brains.append(BrainScript.new())
	book.update(world.calendar.hour_index() + 1)
	assert_true(m1.done, "met with twelve")
	assert_false(book.goal(&"m2_abundance").done, "M2's mastery is not modelled")


func test_the_evaluator_reads_the_calendar_and_the_winters() -> void:
	"""The calendar's day and year; winters come through counted from the first spring after them, while anyone lives."""
	var world := _world(9)
	var village := VillageScript.new(world, LedgerScript.new(), null)
	world.calendar.tick = SimClock.DAYS_PER_YEAR * DAY_TICKS - SimClock.CALENDAR_OFFSET_TICKS
	assert_equal([village.value(VillageScript.M_DAY), village.value(VillageScript.M_YEAR),
		village.value(VillageScript.M_WINTERS)], [SimClock.DAYS_PER_YEAR + 1, 2, 1], "a year on: one winter through")
	world.calendar.tick -= 1
	assert_equal(village.value(VillageScript.M_WINTERS), 0, "the last tick of winter: not yet")
	assert_equal(village.value(VillageScript.M_RESIDENTS), 9, "residents")
	world.calendar.tick = 2 * SimClock.DAYS_PER_YEAR * DAY_TICKS
	world.brains.clear()
	assert_equal(village.value(VillageScript.M_WINTERS), 0, "nobody living has come through a winter")
	world.brains.append(BrainScript.new())
	assert_equal(village.value(VillageScript.M_WINTERS), 2, "two winters on")


func test_the_evaluator_reads_the_stores_and_the_ledger() -> void:
	"""Wood, the harvest in store, unbound bridges and tunnels (0), the HUD's Ready food, the ledger's counts; with
	nothing bound, nothing."""
	var world := _world(9)
	var ledger := LedgerScript.new()
	var village := VillageScript.new(world, ledger, null)
	world.stores.add_wood(5000)
	assert_equal(village.value(VillageScript.M_WOOD), world.stores.wood_milli_u, "wood")
	world.pantry.delivered_milli = 7000
	assert_equal(village.value(VillageScript.M_HARVESTED), 7000, "harvest in store")
	assert_equal([village.value(VillageScript.M_BRIDGES), village.value(VillageScript.M_TUNNELS)], [0, 0], "unbound")
	assert_equal(village.value(VillageScript.M_FOOD_DAYS), world.kitchen.days_of_meals_milli(), "the HUD's Ready food")
	ledger.full_tables = 2
	ledger.clean_seasons = 1
	assert_equal([village.value(VillageScript.M_FULL_TABLES), village.value(VillageScript.M_CLEAN_SEASONS)], [2, 1],
		"the ledger's")
	var empty := VillageScript.new()
	assert_equal([empty.value(VillageScript.M_RESIDENTS), empty.value(VillageScript.M_WINTERS),
		empty.value(VillageScript.M_DAY), empty.value(VillageScript.M_PORTIONS_PREPARED)], [0, 0, 1, 0], "nothing bound")


func test_the_evaluator_counts_bridges_tunnels_and_ready_food() -> void:
	"""The world's own counts of open bridges and tunnel stretches, and the kitchen's Ready food, as they stand."""
	var counted := CountedWorld.new()
	counted.kitchen = StockedKitchen.new()
	var stocked := VillageScript.new(counted, LedgerScript.new(), null)
	assert_equal([stocked.value(VillageScript.M_BRIDGES), stocked.value(VillageScript.M_TUNNELS),
		stocked.value(VillageScript.M_FOOD_DAYS)], [2, 3, 2500], "the bridges, tunnels and Ready food counted")


# --- the ledger --------------------------------------------------------------------------------------------------------

func _cook(kitchen: KitchenScript, dish: int) -> void:
	"""A batch of `dish` finished, as the kitchen logs it."""
	kitchen.batches_cooked += 1
	kitchen.cooked_keys.append(0)
	kitchen.cooked_dishes.append(dish)
	kitchen.cooked_by.append(0)


func test_the_ledger_counts_portions_and_dishes_from_the_kitchens_log() -> void:
	"""Each batch since the last look, at its dish's portions; each dish once in the mask; nothing counted twice; a log
	trimmed to its tail still counts only what is new."""
	var kitchen := KitchenScript.new()
	var ledger := LedgerScript.new()
	_cook(kitchen, Rules.DISH_PORRIDGE)
	_cook(kitchen, Rules.DISH_PORRIDGE)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal([ledger.portions_prepared, ledger.dishes_cooked()], [2 * Rules.PORTIONS_PER_BATCH[0], 1], "two batches")
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.portions_prepared, 2 * Rules.PORTIONS_PER_BATCH[0], "not again")
	_cook(kitchen, Rules.DISH_FISH_STEW)
	kitchen.cooked_dishes.remove_at(0)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.portions_prepared, 2 * Rules.PORTIONS_PER_BATCH[0] + Rules.PORTIONS_PER_BATCH[2], "the new one")
	assert_equal(ledger.dishes_cooked(), 2, "porridge and stew")
	_cook(kitchen, Rules.DISH_SOUP)
	_cook(kitchen, Rules.NO_DISH)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.dishes_cooked(), 3, "the everyday three: the feast's hotpot not yet")
	_cook(kitchen, Rules.DISH_BEAN_HOTPOT)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.dishes_cooked(), Rules.DISH_COUNT, "every dish, the feast's hotpot with them (decision 0781)")


func _tally(kitchen: KitchenScript, key: int, ate: int) -> void:
	"""A meal's tally at its end, as the kitchen logs it."""
	kitchen.meal_keys.append(key)
	kitchen.meal_ate.append(ate)
	kitchen.meal_raw.append(0)
	kitchen.meal_without.append(0)


func test_the_ledger_counts_suppers_where_everyone_ate_cooked() -> void:
	"""A supper where all nine ate a portion counts; one with eight does not; a full breakfast does not; each meal once,
	by its key, after the log is trimmed; with nobody living nothing counts."""
	var kitchen := KitchenScript.new()
	var ledger := LedgerScript.new()
	_tally(kitchen, Rules.meal_key(0, Rules.MEAL_BREAKFAST), 9)
	_tally(kitchen, Rules.meal_key(0, Rules.MEAL_SUPPER), 8)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.full_tables, 0, "breakfast is not supper; eight of nine is not everyone")
	_tally(kitchen, Rules.meal_key(1, Rules.MEAL_SUPPER), 9)
	ledger.observe(kitchen, 9, null, LATE)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.full_tables, 1, "the full supper, once")
	kitchen.meal_keys.remove_at(0)
	kitchen.meal_ate.remove_at(0)
	_tally(kitchen, Rules.meal_key(2, Rules.MEAL_SUPPER), 9)
	ledger.observe(kitchen, 9, null, LATE)
	assert_equal(ledger.full_tables, 2, "the next, after a trim")
	_tally(kitchen, Rules.meal_key(3, Rules.MEAL_SUPPER), 0)
	ledger.observe(kitchen, 0, null, LATE)
	assert_equal(ledger.full_tables, 2, "nobody to feed")
	_tally(kitchen, Rules.meal_key(5, Rules.MEAL_SUPPER), 9)
	ledger.observe(kitchen, 9, null, 5 * SimClock.HOURS_PER_DAY + 23)
	assert_equal(ledger.full_tables, 2, "its day not over: a diner may yet give a portion back")
	kitchen.meal_ate[kitchen.meal_ate.size() - 1] = 8
	ledger.observe(kitchen, 9, null, 6 * SimClock.HOURS_PER_DAY)
	assert_equal(ledger.full_tables, 2, "judged at the day's end, as the tally then stands")


func test_a_full_supper_is_counted_once_its_day_is_over() -> void:
	"""Looked at every hour of its evening, a full supper waits; at midnight it counts."""
	var kitchen := KitchenScript.new()
	var ledger := LedgerScript.new()
	_tally(kitchen, Rules.meal_key(6, Rules.MEAL_SUPPER), 9)
	for hour: int in range(19, 24):
		ledger.observe(kitchen, 9, null, 6 * SimClock.HOURS_PER_DAY + hour)
	assert_equal(ledger.full_tables, 0, "its evening: not yet")
	ledger.observe(kitchen, 9, null, 7 * SimClock.HOURS_PER_DAY)
	assert_equal(ledger.full_tables, 1, "its day over: counted")


func _record_days(record: RecordScript, pantry: PantryScript, days: int, lost_on: int = -1) -> void:
	"""Close the next `days` days from the record's open day, food stored on each, a crop withered on day `lost_on`."""
	var read := IntMath.IntResult.new()
	for day: int in range(record.open_day(), record.open_day() + days):
		pantry.add_into(0, 100, 0, read)
		if day == lost_on:
			record.note_events(PackedInt32Array([SimScript.EVENT_WITHERED, 0]))
		record.close_through((day + 1) * SimClock.HOURS_PER_DAY)


func _started_record(pantry: PantryScript, hour_index: int = 0) -> RecordScript:
	"""A record over `pantry`, opened at `hour_index`."""
	var record := RecordScript.new()
	record.bind(pantry, null)
	record.start(hour_index)
	return record


func test_a_clean_season_is_judged_once_its_days_are_closed() -> void:
	"""Eleven days: not over; twelve, with food stored each day and nothing lost: clean, counted once."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var record := _started_record(pantry)
	var ledger := LedgerScript.new()
	_record_days(record, pantry, SimClock.DAYS_PER_SEASON - 1)
	ledger.observe(null, 9, record, LATE)
	assert_equal(ledger.clean_seasons, 0, "eleven days: the season is not over")
	_record_days(record, pantry, 1)
	ledger.observe(null, 9, record, LATE)
	ledger.observe(null, 9, record, LATE)
	assert_equal(ledger.clean_seasons, 1, "twelve: clean, once")
	assert_false(LedgerScript.is_clean(record, 5), "a season never seen")


func test_a_season_with_a_crop_lost_or_partly_seen_is_not_clean() -> void:
	"""A crop withered on day 5; a record opened on day 4: neither season is clean."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var spoiled := _started_record(pantry)
	var other := LedgerScript.new()
	_record_days(spoiled, pantry, SimClock.DAYS_PER_SEASON, 4)
	other.observe(null, 9, spoiled, LATE)
	assert_equal(other.clean_seasons, 0, "a crop lost")
	var late := _started_record(pantry, 3 * SimClock.HOURS_PER_DAY)
	var third := LedgerScript.new()
	_record_days(late, pantry, SimClock.DAYS_PER_SEASON - 3)
	third.observe(null, 9, late, LATE)
	assert_equal(third.clean_seasons, 0, "nine days of twelve seen")


func test_a_season_with_nothing_harvested_is_not_clean() -> void:
	"""A whole season kept with no food stored: nothing lost, but not a well-kept farm."""
	var bare := _started_record(PantryScript.new(StorageScript.new(Vector2.ZERO)))
	bare.close_through(SimClock.DAYS_PER_SEASON * SimClock.HOURS_PER_DAY)
	assert_equal(bare.season_days(0), SimClock.DAYS_PER_SEASON, "a whole season kept")
	assert_false(LedgerScript.is_clean(bare, 0), "nothing harvested: not clean, however little was lost")


# --- the owner ---------------------------------------------------------------------------------------------------------

func test_the_owner_says_a_reached_goal_once_in_village_news() -> void:
	"""60 U of wood stacked: at the next game hour 'Goal reached: Wood for the cold' goes into the Village news once;
	within the hour nothing is evaluated; a milestone would be said as its conditions met."""
	var world := _world(9)
	var notices := NoticesScript.new()
	var goals := GoalsScript.new()
	goals.post = func(text: String) -> void: notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, text)
	goals.configure(world, null)
	assert_true(goals.update(), "the first look")
	assert_equal(notices.count(), 0, "nothing reached at the start")
	world.stores.add_wood(60000 - world.stores.wood_milli_u)
	assert_false(goals.update(), "the same hour: nothing")
	assert_equal(notices.count(), 0, "not before the hour")
	world.calendar.tick += HOUR_TICKS
	assert_true(goals.update(), "the hour")
	assert_equal(notices.count(), 1, "one entry")
	assert_equal(notices.source(0), NoticesScript.SOURCE_VILLAGE, "the Village's")
	assert_equal(notices.text(0), "Goal reached: Wood for the cold -- 60 U of wood is stacked in store.", "its words")
	world.calendar.tick += HOUR_TICKS
	goals.update()
	assert_equal(notices.count(), 1, "said once")


func test_also_reached_is_told_each_goal_once_after_its_news() -> void:
	"""The tapestry's hook (decision 0902): told the goal's id, title and words once, after its news line."""
	var world := _world(9)
	var told: Array[String] = []
	var goals := GoalsScript.new()
	goals.post = func(_text: String) -> void: told.append("news")
	goals.also_reached = func(goal_id: StringName, title: String, said: String) -> void:
		told.append("%s|%s|%s" % [goal_id, title, said])
	goals.configure(world, null)
	goals.update()
	world.stores.add_wood(60000 - world.stores.wood_milli_u)
	world.calendar.tick += HOUR_TICKS
	goals.update()
	world.calendar.tick += HOUR_TICKS
	goals.update()
	assert_equal(told, ["news", "winter_wood|Wood for the cold|60 U of wood is stacked in store."], "once, after its news")
	goals.post = Callable()
	goals.also_reached = Callable()


func test_a_milestone_is_said_as_conditions_met_never_as_an_award() -> void:
	"""Twelve residents, day 4, 200 portions: at the hour M1 is said as its conditions met, with no unlocks."""
	var world := _world(12)
	var said: Array[String] = []
	var goals := GoalsScript.new()
	goals.post = func(text: String) -> void: said.append(text)
	goals.configure(world, null)
	goals.ledger.portions_prepared = 200
	world.calendar.tick = 3 * DAY_TICKS - SimClock.CALENDAR_OFFSET_TICKS
	goals.update()
	assert_equal(said.size(), 1, "M1 alone")
	assert_equal(said[0], "Milestone conditions met: M1 Settled Hearth -- the village meets the Settled Hearth's " \
		+ "conditions (the demo grants no unlocks).", "conditions met, nothing granted")


func test_after_the_guide_one_note_points_at_the_goals() -> void:
	"""While the guide runs, nothing; once it is complete, one note, never repeated."""
	var said: Array[String] = []
	var goals := GoalsScript.new()
	goals.post = func(text: String) -> void: said.append(text)
	var complete: Array[bool] = [false]
	goals.guide_done = func() -> bool: return complete[0]
	goals.configure(_world(), null)
	goals.update()
	assert_equal(said.size(), 0, "the guide still runs")
	complete[0] = true
	goals.update()
	assert_equal(said.size(), 0, "not in the frame the guide completes: its own line goes first")
	_world_of(goals).calendar.tick += HOUR_TICKS
	goals.update()
	_world_of(goals).calendar.tick += HOUR_TICKS
	goals.update()
	assert_equal(said, [GoalsScript.AFTER_GUIDE] as Array[String], "the pointer at the hour, once")


func test_the_pointer_never_shares_the_guides_completion_hour() -> void:
	"""The guide completing in the very frame the hour turns: no pointer that hour; at the next, one."""
	var said: Array[String] = []
	var goals := GoalsScript.new()
	goals.post = func(text: String) -> void: said.append(text)
	var complete: Array[bool] = [false]
	goals.guide_done = func() -> bool: return complete[0]
	goals.configure(_world(), null)
	goals.update()
	complete[0] = true
	_world_of(goals).calendar.tick += HOUR_TICKS
	assert_true(goals.update(), "the hour turned in the same frame")
	assert_equal(said.size(), 0, "not beside the guide's own line")
	_world_of(goals).calendar.tick += HOUR_TICKS
	goals.update()
	assert_equal(said, [GoalsScript.AFTER_GUIDE] as Array[String], "at the next hour")


func test_the_kitchens_log_is_read_on_the_hour_only() -> void:
	"""A batch cooked within the hour is not counted until the hour turns."""
	var world := _world(9)
	var goals := GoalsScript.new()
	goals.configure(world, null)
	goals.update()
	_cook(world.kitchen, Rules.DISH_PORRIDGE)
	goals.update()
	assert_equal(goals.ledger.portions_prepared, 0, "within the hour: not read")
	world.calendar.tick += HOUR_TICKS
	goals.update()
	assert_equal(goals.ledger.portions_prepared, Rules.PORTIONS_PER_BATCH[Rules.DISH_PORRIDGE], "read at the hour")


func test_the_hourly_path_allocates_no_objects() -> void:
	"""Between hours `update` is a compare; at the hour the ledger and every measure are read -- neither leaves an object
	behind (nothing is reached, so nothing is said)."""
	var world := _world(9)
	var record := RecordScript.new()
	record.start(0)
	var goals := GoalsScript.new()
	goals.configure(world, record)
	goals.update()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 200:
		goals.update()
	for k: int in SimClock.DAYS_PER_SEASON * SimClock.HOURS_PER_DAY + 1:
		world.calendar.tick += HOUR_TICKS
		record.close_through(world.calendar.hour_index())
		assert_true(goals.update(), "hour %d evaluated" % k)
	assert_equal(record.open_day(), SimClock.DAYS_PER_SEASON, "a season closed in the window")
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object retained")


# --- the page and the window -------------------------------------------------------------------------------------------

func test_the_goals_page_shows_the_book() -> void:
	"""Two headings with their counts, each goal's mark and progress -- met, still to go, not in this demo yet -- the
	date a goal was reached, and a goal registered later gets its row."""
	var world := _world(9)
	var goals := GoalsScript.new()
	goals.configure(world, null)
	var page: PageScript = _keep(PageScript.new())
	page.book = goals.book
	page.refresh()
	assert_true(page.goal_text(&"harvest_home").contains("not checked yet"), "before the first hour")
	world.stores.add_wood(60000 - world.stores.wood_milli_u)
	world.pantry.delivered_milli = 12000
	goals.update()
	page.refresh()
	assert_equal(page.heading_text(BookScript.GROUP_VILLAGE), "Village goals: 1 of %d reached" %
		goals.book.count(BookScript.GROUP_VILLAGE), "one reached")
	assert_equal(page.heading_text(BookScript.GROUP_MILESTONE), "Milestones (the full game's): 0 of 4 met", "none met")
	assert_true((page.get_child(1) as Label).text.begins_with("Village goals"), "the reachable goals drawn first")
	assert_equal(page.goal_text(&"winter_wood"), "✓ Wood for the cold -- reached Y1 Spring 1, 06:00\n  ✓ Wood in store: 60.0 U",
		"reached, dated")
	assert_equal(page.goal_text(&"harvest_home"), "◻ Harvest home\n  · Harvested into store: 12.0 U of 40.0 U", "to go")
	assert_true(page.goal_text(&"m2_abundance").contains("  · Recipes mastered (3): not in this demo yet"), "unmodelled")
	assert_true(page.goal_text(&"m4_hearth_charter").contains("  · Every resident warm-bedded (yes): not in this demo yet"),
		"an unmodelled yes-or-no")
	assert_true(page.goal_text(&"first_winter").contains("The first winter survived: not yet"), "a yes-or-no to go")
	goals.book.register(&"later", "Later", "Added by a later feature.", _one(&"x", 1, func() -> int: return 0))
	page.refresh()
	assert_true(page.goal_text(&"later").begins_with("◻ Later"), "its row")


func test_dates_of_hours() -> void:
	"""Hour 0 is midnight before spring day 1; a year of hours on is year 2; winter's first day is in the fourth season."""
	assert_equal(PageScript.date_of_hour(0), "Y1 Spring 1, 00:00", "the first hour")
	assert_equal(PageScript.date_of_hour(SimClock.DAYS_PER_YEAR * SimClock.HOURS_PER_DAY), "Y2 Spring 1, 00:00", "a year")
	assert_equal(PageScript.date_of_hour(3 * SimClock.DAYS_PER_SEASON * SimClock.HOURS_PER_DAY + 13),
		"Y1 Winter 1, 13:00", "winter")
	assert_equal(PageScript.date_of_hour(-5), "Y1 Spring 1, 00:00", "never before the start")


func test_the_guide_window_has_a_goals_tab() -> void:
	"""The Goals tab is the second; it shows the goals page in the scrolling column; the Objectives page's button goes
	to it."""
	var window: WindowScript = _keep(WindowScript.new())
	var goals := GoalsScript.new()
	goals.configure(_world(), null)
	window.goals.book = goals.book
	assert_equal(WindowScript.TAB_NAMES[WindowScript.TAB_GOALS], "Goals", "named")
	window.show_tab(WindowScript.TAB_GOALS)
	assert_true(window.goals.visible and window.tab() == WindowScript.TAB_GOALS, "shown")
	assert_true(window.goals.goal_text(&"m1_settled_hearth").begins_with("◻ M1 Settled Hearth"), "filled on show")
	window.show_tab(WindowScript.TAB_OBJECTIVES)
	var to_goals: Button = null
	for node: Node in window.goals.get_parent().get_child(0).get_children():
		if node is Button and (node as Button).text == WindowScript.GOALS_TEXT:
			to_goals = node as Button
	assert_not_null(to_goals, "the Objectives page's way to the goals")
	to_goals.pressed.emit()
	assert_equal(window.tab(), WindowScript.TAB_GOALS, "it goes there")
