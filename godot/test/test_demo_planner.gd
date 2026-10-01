extends "res://test/framework/test_case.gd"
## The seasonal planner (decision 0451; review F45, UX-008, ECO-005's presentation): the pantry's ledger and the
## after-action record against what really moved, the overview's forecasts against the farm model run forward, its
## filters, the season calendar against the one calendar and the HUD's date, the soil plans against the farm's own
## rules run for real, the beds' Compare view and its map marks, and the planner screen and its keys. No scene tree and
## no staged assets: the farm is test_demo_farm_ui.gd's off-tree village, the kitchen test_demo_kitchen.gd's.

const FarmUiTest := preload("res://test/test_demo_farm_ui.gd")
const KitchenTest := preload("res://test/test_demo_kitchen.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const SeasonScript := preload("res://demo/farm/farm_season.gd")
const Plans := preload("res://demo/farm/farm_soil_plans.gd")
const PlanText := preload("res://demo/farm/farm_soil_plan_text.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const RecordText := preload("res://demo/farm/farm_record_text.gd")
const PlannerScript := preload("res://demo/farm/farm_planner.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const HudDateScript := preload("res://demo/ui/demo_hud_date.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const HOUR_USEC: int = CalendarScript.HOUR_USEC
const RADISH: int = 0
const CARROT: int = 2
const CABBAGE: int = 6
const PEA: int = 11
const WHEAT: int = 13
const OATS: int = 15
const BED_LOAM: int = 0
const BED_CLAY: int = 1
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_WHEAT: int = 5

var _ui: FarmUiTest = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""The farm UI suite's fixtures, borrowed."""
	_ui = FarmUiTest.new()
	_ui.before_each()


func after_each() -> void:
	"""Free what the fixtures built."""
	_ui.after_each()


func _pantry() -> PantryScript:
	"""A pantry over the covered store alone."""
	return PantryScript.new(StorageScript.new(Vector2.ZERO))


func _balanced(pantry: PantryScript) -> bool:
	"""Whether every item's stock is what came in less what went out and what spoiled (THE LEDGER)."""
	for item: int in Catalog.ITEM_COUNT:
		if pantry.milli_of(item) != pantry.stored_total_milli(item) - pantry.withdrawn_total_milli(item) \
				- pantry.spoiled_total_milli(item):
			return false
	return true


# --- the ledger ---------------------------------------------------------------------------------------------------------

func test_the_pantry_ledger_balances_stock_in_out_and_spoiled() -> void:
	"""Deliveries count in once, a withdrawal out once, a lot spoiling once -- and for every item the stock is in less
	out less spoiled, through a merge, a partial withdrawal and composting."""
	var pantry := _pantry()
	assert_true(pantry.add_into(CARROT, 5000, 0, _read), "a carrot delivery")
	var lot: int = _read.value
	assert_true(pantry.store_upto_into(RADISH, 2500, 0, -1, _read) and _read.value == 2500, "a radish delivery")
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 1200, _read), "the cook takes 1.2 U of carrot")
	assert_equal([pantry.stored_total_milli(CARROT), pantry.withdrawn_total_milli(CARROT), pantry.spoiled_total_milli(CARROT)],
		[5000, 1200, 0], "carrot in, out, spoiled")
	for hour: int in Catalog.shelf_hours_of(RADISH):
		pantry.age_hour(0)
	assert_equal(pantry.spoiled_total_milli(RADISH), 2500, "the radish lot spoiled at its shelf life, counted once")
	assert_equal(pantry.spoiled_total_milli(CARROT), 3800, "and the carrot lot (same row, same shelf life)")
	assert_true(_balanced(pantry), "every item balances")
	pantry.compost_spoiled()
	assert_equal(pantry.spoiled_total_milli(RADISH), 2500, "composting spoiled food leaves the ledger alone")
	assert_true(_balanced(pantry), "still balanced")
	assert_false(pantry.withdraw_into(lot, pantry.lot_serial(lot), 1, _read), "a spoiled lot gives nothing")
	assert_equal(pantry.withdrawn_total_milli(CARROT), 1200, "and a refused withdrawal counts nothing")


# --- the record ---------------------------------------------------------------------------------------------------------

func test_a_closed_day_is_the_ledgers_movement_that_day() -> void:
	"""What is stored before midnight is the day's; what comes after is the next day's; the day's weather is the row's
	at one of its own hours; days crossed at once close at once, the first taking what moved, a day never seen with its
	weather NOT SEEN rather than a later day's."""
	var pantry := _pantry()
	var sim := SimScript.new()
	var record := RecordScript.new()
	record.bind(pantry, sim.crop_weather().weather())
	record.start(6)
	assert_equal(record.open_day(), 0, "spring 1 opens")
	pantry.add_into(CARROT, 5100, 0, _read)
	assert_equal(record.close_through(23), 0, "23:00 is still spring 1")
	assert_equal(record.close_through(24), 1, "midnight closes spring 1")
	pantry.add_into(WHEAT, 8000, 0, _read)
	assert_equal([record.value(0, RecordScript.F_DAY), record.value(0, RecordScript.F_HARVESTED),
		record.item_value(0, RecordScript.G_HARVESTED, CARROT)], [0, 5100, 5100], "spring 1: the carrots only")
	assert_equal(record.close_through(24 * 4), 3, "three more days at once")
	assert_equal([record.value(1, RecordScript.F_HARVESTED), record.value(2, RecordScript.F_HARVESTED)], [8000, 0],
		"the first of them takes the wheat, the rest nothing")
	assert_equal([record.value(0, RecordScript.F_WEATHER_SEEN), record.value(0, RecordScript.F_TEMPERATURE)], [1, 120],
		"spring 1's 12 °C, seen at its opening hour")
	assert_equal([record.value(1, RecordScript.F_WEATHER_SEEN), record.value(2, RecordScript.F_WEATHER_SEEN)], [0, 0],
		"spring 2 and 3, only jumped across: not seen")
	assert_equal(RecordText.day_summary(record, 0), "Spring 1's record: +5.1 U harvested · 0 portions eaten",
		"the news strip's line")
	assert_true(RecordText.day_line(record, 0).begins_with("Day's record, Spring 1: harvested 5.1 U (carrot 5.1 U) · "),
		RecordText.day_line(record, 0))


func test_the_record_counts_the_kitchen_meals_from_its_ledgers() -> void:
	"""A real day of the kitchen: the food used is what the pantry's ledger says left it, split as the kitchen's own
	counters, the portions eaten its count, who ate and who went without its meal log -- day 1, both meals."""
	var kt := KitchenTest.new()
	var v: KitchenTest.Village = kt._village(3, KitchenTest.tick_at(1, 2))
	kt._stock(v, OATS, 10000)
	kt._stock(v, CARROT, 12000)
	kt._open(v)
	v.kitchen.portions_eaten = 5
	v.kitchen.consumed_food_milli = 1000
	var record := RecordScript.new()
	record.bind(v.pantry, null)
	record.set_kitchen(v.kitchen)
	record.start(v.calendar.hour_index())
	kt._run(v, 23 * KitchenTest.FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() >= 48)
	assert_equal(record.close_through(v.calendar.hour_index()), 1, "day 1 closed at its midnight")
	var used: int = 22000 - v.pantry.milli_of(OATS) - v.pantry.milli_of(CARROT)
	assert_true(used > 0, "the kitchen cooked (%d milli-U)" % used)
	assert_equal(record.value(0, RecordScript.F_USED), used, "food used: what left the pantry")
	assert_equal(record.value(0, RecordScript.F_COOKED) + record.value(0, RecordScript.F_RAW), used, "cooked plus raw")
	assert_equal(record.value(0, RecordScript.F_COOKED), v.kitchen.consumed_food_milli - 1000,
		"the kitchen's cooked food that day (what it had counted before is not the day's)")
	assert_equal(record.value(0, RecordScript.F_PORTIONS), v.kitchen.portions_eaten - 5, "portions eaten that day")
	assert_true(record.value(0, RecordScript.F_PORTIONS) > 0, "some eaten")
	var ate: int = 0
	var without: int = 0
	for k: int in v.kitchen.meal_keys.size():
		if v.kitchen.meal_keys[k] / 2 == 1:
			ate += v.kitchen.meal_ate[k] + v.kitchen.meal_raw[k]
			without += v.kitchen.meal_without[k]
	assert_equal([record.value(0, RecordScript.F_ATE), record.value(0, RecordScript.F_WITHOUT)], [ate, without],
		"day 1's two meals, from the kitchen's log")


func test_who_went_without_is_the_kitchen_s_tally() -> void:
	"""No water and keep-water off: supper is missed by all three -- the day records three who went without."""
	var kt := KitchenTest.new()
	var v: KitchenTest.Village = kt._village(3, KitchenTest.tick_at(1, 17))
	kt._stock(v, CARROT, 12000)
	v.kitchen.keep_water = false
	kt._open(v)
	var record := RecordScript.new()
	record.bind(v.pantry, null)
	record.set_kitchen(v.kitchen)
	record.start(v.calendar.hour_index())
	kt._run(v, 8 * KitchenTest.FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() >= 48)
	record.close_through(v.calendar.hour_index())
	assert_equal([record.value(0, RecordScript.F_WITHOUT), record.value(0, RecordScript.F_PORTIONS)], [3, 0],
		"three went without, nobody ate")
	assert_true(RecordText.day_line(record, 0).ends_with("missed: 3 went without a meal"), RecordText.day_line(record, 0))


func test_a_day_waits_for_the_kitchen_to_run_past_its_midnight() -> void:
	"""A calendar jump past midnights reaches the farm's hour before the kitchen's frame: no day closes until the kitchen
	has run past its midnight -- then each closes with its own supper's tally, however many were jumped."""
	var kt := KitchenTest.new()
	var v: KitchenTest.Village = kt._village(3, KitchenTest.tick_at(1, 17))
	kt._stock(v, CARROT, 12000)
	v.kitchen.keep_water = false
	kt._open(v)
	var record := RecordScript.new()
	record.bind(v.pantry, null)
	record.set_kitchen(v.kitchen)
	record.start(v.calendar.hour_index())
	v.calendar.tick = KitchenTest.tick_at(3, 1)
	assert_equal(record.close_through(v.calendar.hour_index()), 0, "held: the kitchen has not run day 1's supper")
	v.kitchen.update()
	assert_equal(record.close_through(v.calendar.hour_index()), 2, "the kitchen ran: day 1 and day 2 close")
	assert_equal(record.value(0, RecordScript.F_WITHOUT), 3, "day 1's supper: all three went without")
	assert_equal(record.value(1, RecordScript.F_WITHOUT) + record.value(1, RecordScript.F_ATE), 6,
		"day 2's two meals tallied, three residents each")


func test_the_record_maps_every_kitchen_counter() -> void:
	"""Raw meals count among who ate; a portion spoiled on the table and a cancelled batch's spoiled food are the day's;
	the counters before the day are not."""
	var kt := KitchenTest.new()
	var v: KitchenTest.Village = kt._village(3, KitchenTest.tick_at(1, 20))
	kt._open(v)
	v.kitchen.store.spoiled_portions = 4
	v.kitchen.cancelled_spoil_milli = 3000
	var record := RecordScript.new()
	record.bind(v.pantry, null)
	record.set_kitchen(v.kitchen)
	record.start(v.calendar.hour_index())
	v.kitchen.store.spoiled_portions += 2
	v.kitchen.cancelled_spoil_milli += 1500
	v.kitchen.raw_eaten_milli += 700
	for column: PackedInt32Array in [v.kitchen.meal_keys, v.kitchen.meal_ate, v.kitchen.meal_raw, v.kitchen.meal_without]:
		column.append(0)
	var last: int = v.kitchen.meal_keys.size() - 1
	v.kitchen.meal_keys[last] = MealRules.meal_key(1, MealRules.MEAL_SUPPER)
	v.kitchen.meal_ate[last] = 1
	v.kitchen.meal_raw[last] = 2
	kt._run(v, 5 * KitchenTest.FRAMES_PER_HOUR, func() -> bool: return v.calendar.hour_index() >= 48)
	assert_equal(record.close_through(v.calendar.hour_index()), 1, "day 1 closed")
	assert_equal([record.value(0, RecordScript.F_PORTIONS_SPOILED), record.value(0, RecordScript.F_KITCHEN_SPOILED),
		record.value(0, RecordScript.F_RAW)], [2, 1500, 700], "the day's own spoilage and raw food")
	assert_equal(record.value(0, RecordScript.F_ATE), 3, "one portion and two raw meals: three ate")
	assert_true(RecordText.day_line(record, 0).contains("2 portions, 1.5 U from a cancelled batch"),
		RecordText.day_line(record, 0))


func test_the_day_s_event_is_the_one_active_on_it() -> void:
	"""First spring's Ideal spell is on spring 6-8: spring 5 records none, spring 6 records it."""
	var farm: DemoFarmScript = _ui._farm()
	for hour: int in 24 * 5 + 18:
		farm.advance_calendar(HOUR_USEC)
	var record: RecordScript = farm.record
	var k5: int = record.index_of_day(4)
	var k6: int = record.index_of_day(5)
	assert_true(k5 >= 0 and k6 >= 0, "both closed")
	assert_equal(record.value(k5, RecordScript.F_EVENT), WeatherScript.EVENT_NONE, "spring 5: no event")
	assert_equal(record.value(k6, RecordScript.F_EVENT), WeatherScript.EVENT_IDEAL_SPELL, "spring 6: the Ideal spell")
	assert_equal(record.value(k6, RecordScript.F_TEMPERATURE), 180, "at its 18 °C")


func test_a_withered_crop_is_a_crop_lost_on_its_day() -> void:
	"""The hour's EVENT_WITHERED pairs are the open day's crops lost, named by bed; ripening is not."""
	var record := RecordScript.new()
	record.bind(_pantry(), null)
	record.start(6)
	var events := PackedInt32Array([SimScript.EVENT_RIPENED, 1, SimScript.EVENT_WITHERED, 2, SimScript.EVENT_WITHERED, 4])
	assert_equal(record.note_events(events), 2, "two crops lost")
	record.close_through(24)
	assert_equal([record.value(0, RecordScript.F_LOST), record.value(0, RecordScript.F_LOST_BEDS)], [2, (1 << 2) | (1 << 4)],
		"beds 3 and 5")
	assert_true(RecordText.day_line(record, 0).ends_with("missed: 2 crops lost (bed 3, bed 5)"), RecordText.day_line(record, 0))


func test_a_season_s_totals_are_its_days_and_a_year_is_kept() -> void:
	"""A season's totals sum its kept days only; after a year and more only the last MAX_DAYS days are kept."""
	var pantry := _pantry()
	var record := RecordScript.new()
	record.bind(pantry, null)
	record.start(0)
	for day: int in 14:
		pantry.add_into(RADISH, 1000 * (day + 1), 0, _read)
		record.close_through((day + 1) * 24)
	assert_equal(record.season_total(0, RecordScript.F_HARVESTED), 78000, "spring: 1 + 2 + ... + 12 U")
	assert_equal(record.season_total(1, RecordScript.F_HARVESTED), 27000, "summer's two days: 13 + 14 U")
	assert_equal([record.season_days(0), record.season_days(1)], [12, 2], "days kept per season")
	assert_equal(record.season_item_total(1, RecordScript.G_HARVESTED, RADISH), 27000, "by item")
	assert_true(RecordText.season_line(record, 0).begins_with("Spring, year 1 (12 days): harvested 78.0 U · "),
		RecordText.season_line(record, 0))
	record.close_through(60 * 24)
	assert_equal(record.day_count(), RecordScript.MAX_DAYS, "a year kept")
	assert_equal(record.value(0, RecordScript.F_DAY), 60 - RecordScript.MAX_DAYS, "the oldest kept")
	assert_equal(record.index_of_day(0), -1, "spring 1 of year 1 is gone")


func test_the_farm_posts_each_day_and_each_season_to_the_news() -> void:
	"""The farm closes the day at its midnight hour and posts its record to the village news (the history's Farm
	place); at a season's last day, the season's record too."""
	var farm: DemoFarmScript = _ui._farm()
	farm.advance_calendar(18 * HOUR_USEC)
	var notices: NoticesScript = farm.services.notices
	assert_true(notices.has_text(RecordText.day_line(farm.record, 0)), "spring 1's record in the news")
	assert_true(notices.has_summary("Spring 1's record: +0 U harvested · 0 portions eaten"), "with its short line")
	farm.advance_calendar(24 * 11 * HOUR_USEC)
	assert_equal(farm.record.value(farm.record.day_count() - 1, RecordScript.F_DAY), 11, "spring 12 closed")
	assert_true(notices.has_text("Season's record, " + RecordText.season_line(farm.record, 0)), "spring's record posted")


# --- the overview -------------------------------------------------------------------------------------------------------

func test_a_growing_bed_s_forecast_is_the_tick_it_ripens() -> void:
	"""The carrots' "≈" date is the farm model's own: run hour by hour, they ripen at exactly the forecast tick, and
	the amount forecast is what the harvest then brings."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	assert_true(Rows.ripe_estimate_tick_into(sim, BED_CARROTS, _read), "growing at a rate")
	var forecast: int = _read.value
	assert_true(Rows.harvest_text(sim, BED_CARROTS, _read).begins_with("≈ %s · about " % Rows.date_text(sim, forecast)),
		Rows.harvest_text(sim, BED_CARROTS, _read))
	for hour: int in 48:
		if sim.stage_of(BED_CARROTS) == SimScript.STAGE_RIPE:
			break
		farm.advance_calendar(HOUR_USEC)
	assert_equal(Rows.ripe_tick_of(sim, BED_CARROTS), forecast, "ripe at the very tick forecast")
	assert_true(sim.expected_yield_into(BED_CARROTS, _read), "a harvest now")
	var shown: int = _read.value
	assert_true(Rows.harvest_text(sim, BED_CARROTS, _read).begins_with("Ripe now: %s" % Rows.units(shown)), "said")
	assert_equal(sim.harvest(BED_CARROTS).value, shown, "the harvest brings what was shown")


func test_a_ripe_bed_shows_its_rule_dates() -> void:
	"""Ripe: full yield until 48 hours after it ripened, then losing and the day it withers (REQ-SET-075)."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	farm.advance_calendar(24 * HOUR_USEC)
	var ripe: int = Rows.ripe_tick_of(sim, BED_CARROTS)
	assert_true(ripe >= 0, "ripe")
	var grace: String = Rows.date_text(sim, ripe + 48 * SimClock.TICKS_PER_HOUR)
	assert_true(Rows.harvest_text(sim, BED_CARROTS, _read).ends_with("full yield until " + grace), grace)
	farm.advance_calendar(50 * HOUR_USEC)
	var withers: String = Rows.date_text(sim, ripe + 120 * SimClock.TICKS_PER_HOUR)
	assert_true(Rows.harvest_text(sim, BED_CARROTS, _read).ends_with("losing 10% a day · withers " + withers),
		Rows.harvest_text(sim, BED_CARROTS, _read))
	assert_true(Rows.needs_attention(sim, farm.crew, BED_CARROTS, _read), "spoiling needs attention")


func test_the_overview_s_cells_are_the_bed_panel_s_words() -> void:
	"""Seven cells: the bed, its crop, its stage, its harvest, its moisture as the bed panel says it, the work on it and
	who has it, and its next sowing."""
	var farm: DemoFarmScript = _ui._farm()
	var cells := PackedStringArray()
	Rows.cells_into(farm.sim, farm.crew, BED_RADISH, _read, cells)
	assert_equal(cells.size(), Rows.COLUMN_COUNT, "seven cells")
	assert_equal([cells[0], cells[1]], ["Bed 4", "Radish"], "bed and crop")
	assert_true(cells[2].begins_with("Growing "), cells[2])
	assert_equal("Soil moisture: " + cells[4], Text.moisture_line(farm.sim, BED_RADISH), "the panel's moisture words")
	_ui._set_moisture(farm.sim, BED_RADISH, 9550)
	assert_equal("Soil moisture: " + Rows.moisture_text(farm.sim, BED_RADISH), Text.moisture_line(farm.sim, BED_RADISH),
		"above its range rounded up, as the panel does (Waterlogged · 96%)")
	_ui._set_moisture(farm.sim, BED_RADISH, 6000)
	assert_equal(cells[5], "—", "no work")
	assert_equal(cells[6], "Choose after the harvest", "next sowing")
	farm.crew.order(JobsScript.KIND_WATER, BED_RADISH, PackedInt32Array(), JobsScript.ORIGIN_PLAYER)
	assert_equal(Rows.work_text(farm.crew, BED_RADISH), "Water: queued", "a queued job")
	Rows.cells_into(farm.sim, farm.crew, BED_LOAM, _read, cells)
	assert_equal(cells[6], "Choose a crop: %d sowable now" % Rows.sowable_count(farm.sim, BED_LOAM), "empty bed")
	farm.sim.choose(BED_LOAM, RADISH)
	assert_equal(Rows.next_text(farm.sim, BED_LOAM), "Sow Radish now", "chosen and sowable")
	assert_true(Rows.harvest_text(farm.sim, BED_LOAM, _read).begins_with("If sown now: ≈ "), "what it would bring")
	assert_true(Rows.harvest_text(farm.sim, BED_LOAM, _read).ends_with("about " + Rows.units(
		Text.sown_estimate_milli(farm.sim, BED_LOAM, RADISH))), "the picker's own estimate")


func test_needs_attention_is_the_warning_needs_and_waiting_harvests() -> void:
	"""Waterlogged and parched growing beds need attention (Drain, Water); a bed fine in its band does not; nor does a
	ripe crop in its grace -- that is Harvest soon."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	assert_equal(Rows.count_matching(sim, farm.crew, Rows.FILTER_ATTENTION, _read), 0, "nothing at the opening")
	_ui._set_moisture(sim, BED_RADISH, 9500)
	_ui._set_moisture(sim, BED_WHEAT, 1000)
	assert_equal(Rows.attention_verb(sim, farm.crew, BED_RADISH, _read), "Drain", "waterlogged: Drain")
	assert_equal(Rows.attention_verb(sim, farm.crew, BED_WHEAT, _read), "Water", "parched: Water")
	assert_equal(Rows.count_matching(sim, farm.crew, Rows.FILTER_ATTENTION, _read), 2, "two beds")
	assert_true(Rows.stage_text(sim, farm.crew, BED_RADISH, _read).ends_with("\nNeeds: Drain"), "named in the stage")
	assert_false(Rows.matches(sim, farm.crew, BED_LOAM, Rows.FILTER_ATTENTION, _read), "an empty bed does not")
	sim.infect_for_test(BED_CARROTS)
	assert_equal(Rows.attention_verb(sim, farm.crew, BED_CARROTS, _read), "Clear", "blighted: Clear")
	sim.choose(BED_LOAM, RADISH)
	farm.crew.order(JobsScript.KIND_SOW, BED_LOAM, PackedInt32Array(), JobsScript.ORIGIN_PLAYER)
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "a job on bed 1")
	farm.crew.jobs.blocked[_read.value] = JobsScript.BLOCK_WAY
	assert_equal(Rows.attention_verb(sim, farm.crew, BED_LOAM, _read), "a way to the job", "nobody can reach it")


func test_harvest_soon_is_ripe_or_within_a_day_at_today_s_rate() -> void:
	"""The carrots (ripe within a day) are soon; the radish (days off) and the empty beds are not; ripe, still soon."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	assert_true(sim.hours_to_ripe_into(BED_CARROTS, _read) and _read.value <= Rows.HARVEST_SOON_HOURS, "carrots close")
	assert_true(Rows.harvest_soon(sim, BED_CARROTS, _read), "carrots soon")
	assert_false(Rows.harvest_soon(sim, BED_RADISH, _read), "radish not")
	assert_false(Rows.harvest_soon(sim, BED_LOAM, _read), "an empty bed not")
	assert_equal(Rows.count_matching(sim, farm.crew, Rows.FILTER_SOON, _read), 1, "one bed")
	farm.advance_calendar(24 * HOUR_USEC)
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_RIPE, "ripe now")
	assert_true(Rows.harvest_soon(sim, BED_CARROTS, _read), "still soon")
	assert_false(Rows.needs_attention(sim, farm.crew, BED_CARROTS, _read), "in its grace: not a warning")


# --- the calendar -------------------------------------------------------------------------------------------------------

func test_the_calendar_s_today_is_the_hud_s_date_on_the_ten_minute_day() -> void:
	"""The HUD's date trigger and the planner read one calendar: its day is the calendar's today, its hour the
	timeline's, through half a game day at 1x (five real minutes, decision 0421) and a day boundary."""
	var farm: DemoFarmScript = _ui._farm()
	var shell := UiShell.new()
	_ui._nodes.append(shell)
	shell.build()
	var manager := GameManagerScript.new()
	_ui._nodes.append(manager)
	manager.start_game()
	var date := HudDateScript.new()
	date.bind(shell, farm.services.calendar, manager)
	var season := SeasonScript.new()
	for step: int in [12, 12, 7]:
		farm.step(step * HOUR_USEC)
		date.sync()
		season.build(farm.sim, farm.record, null, 0)
		var at: SimClock.Calendar = farm.services.calendar.now()
		assert_equal(shell.status_label().text, CalendarScript.day_text(at.season, at.season_day), "the HUD's day")
		assert_equal([season.today, season.today_hour], [at.season_day, at.hour], "the planner's today")
		farm.planner.refresh()
		assert_equal(farm.planner.date_text(), "Today: " + farm.services.calendar.date_text(), "the planner's header")
		assert_true(shell.status_label().tooltip_text.begins_with(farm.services.calendar.date_text()), "the same hour")
	assert_equal(farm.services.calendar.now().season_day, 2, "31 hours from 06:00 of spring 1: spring 2, 13:00")


func test_the_calendar_holds_the_windows_and_the_demo_schedule() -> void:
	"""Spring's §5.6 windows (roots 1-8, grain 1-4, beans 5-10) scheduled; when they would ripen, estimates; spring's
	frost night 11 and blight 12; summer's cabbage window and blight days 4 and 10; and no frost in spring but day 11."""
	var farm: DemoFarmScript = _ui._farm()
	var season := SeasonScript.new()
	season.build(farm.sim, farm.record, null, 0)
	assert_true(_has_entry(season, SeasonScript.LANE_ROOTS, SeasonScript.SCHEDULED, 1, 8), "sow roots 1-8")
	assert_true(_has_entry(season, SeasonScript.LANE_GRAIN, SeasonScript.SCHEDULED, 1, 4), "sow grain 1-4")
	assert_true(_has_entry(season, SeasonScript.LANE_BEANS, SeasonScript.SCHEDULED, 5, 10), "sow beans 5-10")
	assert_true(_has_entry(season, SeasonScript.LANE_ROOTS, SeasonScript.ESTIMATE, 6, 12), "roots ripen 6-13, clipped")
	assert_true(_has_entry(season, SeasonScript.LANE_FROST, SeasonScript.SCHEDULED, 11, 11), "frost night 11")
	assert_equal(_lane_count(season, SeasonScript.LANE_FROST), 1, "one frost night in spring")
	assert_true(_has_entry(season, SeasonScript.LANE_BLIGHT, SeasonScript.SCHEDULED, 12, 12), "blight on 12")
	assert_true(_has_entry(season, SeasonScript.LANE_BEDS, SeasonScript.ESTIMATE, 2, 2), "the carrots' estimate")
	season.build(farm.sim, farm.record, null, 1)
	assert_equal(season.today, 0, "next season has no today")
	assert_true(_has_entry(season, SeasonScript.LANE_CABBAGE, SeasonScript.SCHEDULED, 5, 10), "sow cabbage summer 5-10")
	assert_true(_has_entry(season, SeasonScript.LANE_ROOTS, SeasonScript.ESTIMATE, 1, 1), "spring roots ripen into summer 1")
	assert_equal(_lane_count(season, SeasonScript.LANE_BLIGHT), 2, "summer blight days 4 and 10")
	assert_true(season.notes.has("Weather for days to come is not known: only the season's baseline and announced events are."),
		"the unknown said")


func test_the_season_event_shows_only_once_announced() -> void:
	"""First spring's forced Ideal spell (days 6-8) is not on the calendar on spring 2 -- the notes say it is announced
	three days ahead -- and is, as announced, from spring 3 on; days already passed are recorded, today is now."""
	var farm: DemoFarmScript = _ui._farm()
	var season := SeasonScript.new()
	farm.advance_calendar(18 * HOUR_USEC)
	season.build(farm.sim, farm.record, null, 0)
	assert_false(_has_label(season, "Ideal spell (announced)"), "not announced on spring 2")
	assert_true(season.notes.has("This season's weather event is not announced yet: it is announced three days before it starts."),
		"said instead")
	farm.advance_calendar(24 * HOUR_USEC)
	season.build(farm.sim, farm.record, null, 0)
	assert_true(_has_entry(season, SeasonScript.LANE_WEATHER, SeasonScript.SCHEDULED, 6, 8), "announced on spring 3: 6-8")
	assert_true(_has_label(season, "Ideal spell (announced)"), "named")
	assert_true(_has_entry(season, SeasonScript.LANE_WEATHER, SeasonScript.RECORDED, 1, 1), "spring 1 recorded")
	assert_true(_has_entry(season, SeasonScript.LANE_WEATHER, SeasonScript.RECORDED, 2, 2), "spring 2 recorded")
	assert_true(_has_entry(season, SeasonScript.LANE_WEATHER, SeasonScript.NOW, 3, 3), "spring 3 now")


func test_the_calendar_shows_the_kitchen_s_planned_meals_and_the_food_in_store() -> void:
	"""With a kitchen: its planned meals on their days (scheduled) and the HUD's Ready food from today (an estimate)."""
	var kt := KitchenTest.new()
	var v: KitchenTest.Village = kt._village(3, KitchenTest.tick_at(1, 2))
	kt._stock(v, OATS, 10000)
	kt._stock(v, CARROT, 12000)
	kt._open(v)
	var farm: DemoFarmScript = _ui._farm()
	farm.advance_calendar(20 * HOUR_USEC)
	var season := SeasonScript.new()
	season.build(farm.sim, farm.record, v.kitchen, 0)
	assert_equal(_lane_count(season, SeasonScript.LANE_MEALS), 5, "four planned meals and the food in store")
	assert_true(_has_entry(season, SeasonScript.LANE_MEALS, SeasonScript.SCHEDULED, 2, 2), "spring 2's meals")
	var days: int = v.kitchen.days_of_meals_milli() / 1000
	assert_true(_has_entry(season, SeasonScript.LANE_MEALS, SeasonScript.ESTIMATE, 2, 2 + days), "food lasts %d days" % days)


func _has_entry(season: SeasonScript, lane: int, knowing: int, first: int, last: int) -> bool:
	"""Whether the season has such an entry."""
	for k: int in season.count():
		if season.lane[k] == lane and season.knowing[k] == knowing and season.first_day[k] == first \
				and season.last_day[k] == last:
			return true
	return false


func _has_label(season: SeasonScript, words: String) -> bool:
	"""Whether an entry says `words`."""
	return season.label.has(words)


func _lane_count(season: SeasonScript, lane: int) -> int:
	"""Entries on a lane."""
	return season.lane.count(lane)


# --- the soil plans -----------------------------------------------------------------------------------------------------

func test_the_fallow_plan_is_the_farm_s_own_fallow_season() -> void:
	"""An empty loam bed rested twelve days on the real farm ends at the fertility the fallow plan said, with no
	harvest and no staff time; its next crop's figure is the picker's own estimate then."""
	var farm: DemoFarmScript = _ui._farm()
	var plan: Plans.Plan = Plans.plans_for(farm.sim, BED_LOAM, _read)[Plans.PLAN_FALLOW]
	assert_equal([plan.harvest_day, plan.work_usec], [Plans.NO_DAY, 0], "nothing sown, nothing worked")
	farm.advance_calendar((24 * 12) * HOUR_USEC)
	assert_equal(farm.sim.fertility_of(BED_LOAM), plan.fertility_end, "the farm's own twelve days of rest")
	assert_equal(plan.next_milli, Text.sown_estimate_milli(farm.sim, BED_LOAM, plan.next_crop), "the picker's estimate")


func test_the_fallow_gain_is_farming_gd_s_after_a_real_legume() -> void:
	"""After a real pea harvest, REQ-SET-078's daily gain is the plans' on every day around the bonus."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	var legume_day: int = _grow_peas(farm, BED_LOAM)
	var tile: int = sim.farming().tile_of(sim.slot_of(BED_LOAM)).value
	assert_equal(sim.farming().tile_last_legume_day_of(tile).value, legume_day, "the legume dated")
	for day: int in range(legume_day - 2, legume_day + 16):
		assert_true(sim.farming().fallow_gain_into(tile, day, _read), "a gain on day %d" % day)
		assert_equal(Plans.fallow_gain(day, legume_day), _read.value, "day %d" % day)


func test_the_legume_plan_gives_back_its_cost_as_the_farm_does() -> void:
	"""On spring 5 the legume plan sows peas today; a real pea crop grown and harvested leaves the bed at the plan's
	fertility after the harvest; the next crop then rotates from a legume. Sand refuses peas."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	farm.advance_calendar(24 * 4 * HOUR_USEC)
	var plan: Plans.Plan = Plans.plans_for(sim, BED_LOAM, _read)[Plans.PLAN_LEGUME]
	assert_equal([plan.crop, plan.sow_day], [PEA, sim.absolute_day()], "peas sown today")
	assert_equal(plan.harvest_day, sim.absolute_day() + 6, "144 hours: six days")
	assert_equal(plan.harvest_milli, Text.sown_estimate_milli(sim, BED_LOAM, PEA), "the picker's estimate for peas")
	_grow_peas(farm, BED_LOAM)
	assert_equal(sim.fertility_of(BED_LOAM), plan.after_harvest, "the farm gives back 800 as the plan said")
	assert_equal(sim.rotation_preview(BED_LOAM, RADISH), FarmingScript.ROTATION_FACTOR_FIRST, "radish after peas")
	assert_equal(plan.next_milli, Text.estimate_milli(6000, Plans.fertility_factor(plan.fertility_end),
		FarmingScript.ROTATION_FACTOR_FIRST), "then radish: at the season's end fertility, after a legume")
	assert_equal(plan.fertility_end, Plans.rest(plan.after_harvest, plan.harvest_day, plan.end_day, plan.harvest_day),
		"the rest after it with the legume's bonus")
	assert_equal(plan.fertility_end - plan.after_harvest, 100 * (plan.end_day - plan.harvest_day), "+100 a day")
	var after_roots: Plans.Plan = Plans.plans_for(sim, BED_RADISH, _read)[Plans.PLAN_LEGUME]
	var soil: int = after_roots.fertility_end if after_roots.harvest_day <= after_roots.end_day else after_roots.after_harvest
	assert_equal(after_roots.next_milli, Text.estimate_milli(6000, Plans.fertility_factor(soil),
		FarmingScript.ROTATION_FACTOR_FIRST), "radish after the radish then peas: a change of family, not 850")
	var sand: Plans.Plan = Plans.plans_for(sim, BED_CARROTS, _read)[Plans.PLAN_LEGUME]
	assert_equal(PlanText.warning(sand), "Can't now: Peas and beans need loam or clay; this bed is sand", "sand refused")


func test_the_compost_plan_is_compost_then_the_picker_s_estimate() -> void:
	"""The compost plan's harvest is what the picker estimates once the bed is really composted; its staff time is the
	compost, sowing and harvest jobs' work; composted already this season, it is refused."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	sim.choose(BED_LOAM, RADISH)
	var plan: Plans.Plan = Plans.plans_for(sim, BED_LOAM, _read)[Plans.PLAN_COMPOST]
	assert_equal(plan.sow_day, sim.absolute_day(), "radish sown today")
	var work: int = JobsScript.plan_work_usec(JobsScript.KIND_COMPOST, 0) + JobsScript.plan_work_usec(JobsScript.KIND_SOW,
		0) + JobsScript.plan_work_usec(JobsScript.KIND_HARVEST, 0)
	assert_equal(plan.work_usec, work, "the three jobs' work")
	assert_equal(PlanText.staff_line(plan), "Staff time: %s (0.%02d staff-days)" % [CardScript.hours_text(work),
		Plans.staff_hundredths(work)], "said as the cards say it")
	assert_equal(Plans.staff_hundredths(10 * HOUR_USEC), 100, "ten game hours of work: a staff-day")
	assert_true(sim.compost(BED_LOAM).ok, "really composted")
	assert_equal(plan.harvest_milli, Text.sown_estimate_milli(sim, BED_LOAM, RADISH), "the estimate after compost")
	var again: Plans.Plan = Plans.plans_for(sim, BED_LOAM, _read)[Plans.PLAN_COMPOST]
	assert_true(PlanText.warning(again).begins_with("Can't now: Composted this season already"), PlanText.warning(again))


func test_a_standing_crop_s_plans_start_at_its_harvest() -> void:
	"""The carrots' plans start on the day they ripen, their cost taken and their root family banked: a carrot after
	them is the same family again."""
	var farm: DemoFarmScript = _ui._farm()
	var sim: SimScript = farm.sim
	var start: Plans.Start = Plans.start_of(sim, BED_CARROTS, _read)
	assert_true(Rows.ripe_estimate_tick_into(sim, BED_CARROTS, _read), "forecast")
	assert_equal(start.day, SimClock.Calendar.new(_read.value).absolute_day, "the ripening day")
	assert_equal(start.fertility, sim.fertility_of(BED_CARROTS) - FarmingScript.CROP_FERTILITY_COST[FarmingScript.CROP_ROOTS],
		"roots' 700 taken")
	assert_equal([start.last_family, start.streak], [FarmingScript.FAMILY_ROOT, 1], "a root harvest banked")
	var compost: Plans.Plan = Plans.plans_for(sim, BED_CARROTS, _read)[Plans.PLAN_COMPOST]
	assert_equal(compost.harvest_milli, Text.estimate_milli(6000, Plans.fertility_factor(start.fertility + 1500),
		FarmingScript.ROTATION_FACTOR_SECOND), "carrot again: 850")
	farm.advance_calendar(24 * HOUR_USEC)
	assert_true(sim.harvest(BED_CARROTS).ok, "the carrots in")
	_ui._sow(sim, BED_CARROTS, RADISH)
	start = Plans.start_of(sim, BED_CARROTS, _read)
	assert_equal([start.last_family, start.streak], [FarmingScript.FAMILY_ROOT, 2], "a second root harvest banked")
	compost = Plans.plans_for(sim, BED_CARROTS, _read)[Plans.PLAN_COMPOST]
	assert_equal(compost.harvest_milli, Text.estimate_milli(6000, Plans.fertility_factor(mini(start.fertility + 1500,
		10000)), FarmingScript.ROTATION_FACTOR_THIRD_PLUS), "radish third of the family: 700")


func _grow_peas(farm: DemoFarmScript, bed: int) -> int:
	"""Sow peas in `bed` (advancing to spring 5 when earlier), grow them to ripe at a good hour, harvest; the day."""
	var sim: SimScript = farm.sim
	while sim.season_day() < 5:
		farm.advance_calendar(24 * HOUR_USEC)
	_ui._sow(sim, bed, PEA)
	for hour: int in FarmingScript.CROP_GROWTH_HOURS[FarmingScript.CROP_BEANS]:
		sim.farming().advance_growth_hour_into(sim.slot_of(bed), 150, sim.calendar.tick, _read)
	assert_true(sim.harvest(bed).ok, "peas harvested")
	return sim.absolute_day()


# --- compare ------------------------------------------------------------------------------------------------------------

func test_compare_sorts_and_holds_its_order_until_sorted_again() -> void:
	"""By harvest the wheat leads; the order is held while a value changes; pressing a sort sorts again."""
	var farm: DemoFarmScript = _ui._farm()
	var panel := farm.bed_panel
	farm.select_bed(BED_CARROTS)
	panel.open_compare()
	var view := panel.compare_view()
	assert_true(view.visible and panel.comparing, "showing")
	assert_equal(view.order[0], BED_WHEAT, "the wheat's 8.5 U first")
	assert_equal(view.order.slice(3), PackedInt32Array([BED_LOAM, BED_CLAY, 4]), "the empty beds tied, in bed order")
	assert_equal(view.table().shown_rows(), Catalog.BED_COUNT, "every bed")
	assert_true(view.table().row_texts(_row_of(view, BED_CARROTS))[0].contains("(this bed)"), "this bed marked")
	view.sort_button(Rows.SORT_MOISTURE).pressed.emit()
	var held: PackedInt32Array = view.order.duplicate()
	assert_true(held[0] != BED_LOAM, "the loam bed is not the worst yet")
	_ui._set_moisture(farm.sim, BED_LOAM, 0)
	panel.refresh()
	assert_equal(view.order, held, "the order held while a figure changed")
	view.sort_button(Rows.SORT_MOISTURE).pressed.emit()
	assert_equal(view.order[0], BED_LOAM, "sorted again: the parched bed first")
	view.sort_button(Rows.SORT_FERTILITY).pressed.emit()
	assert_equal(view.sort, Rows.SORT_FERTILITY, "by fertility")


func test_compare_rings_and_ranks_the_beds_on_the_map() -> void:
	"""Open, every bed is ranked on the map and ringed; a row opens its bed and the view stays; Back clears the marks."""
	var farm: DemoFarmScript = _ui._farm()
	farm.select_bed(BED_CARROTS)
	farm.bed_panel.open_compare()
	assert_equal(farm.view.compare_mark(BED_WHEAT), "#1 by harvest", "the wheat ranked first")
	farm.view.refresh()
	assert_true(farm.view.beds[BED_WHEAT].compare_ring.visible, "ringed")
	assert_true(farm.view.beds[BED_WHEAT].label.text.ends_with("\n#1 by harvest"), "ranked under its label")
	(farm.bed_panel.compare_view().table().row(0) as Button).pressed.emit()
	assert_equal(farm.selected_bed, BED_WHEAT, "the row opens its bed")
	assert_true(farm.bed_panel.comparing, "the view stays")
	farm.bed_panel.back_button().pressed.emit()
	assert_false(farm.bed_panel.comparing, "Back")
	farm.bed_panel.open_compare()
	farm.bed_panel.set_zone(false, 0.0)
	assert_false(farm.bed_panel.comparing, "the panel hidden closes the view")
	farm.bed_panel.set_zone(true, 0.0)
	farm.bed_panel.open_compare()
	farm.select_bed(-1)
	assert_false(farm.bed_panel.comparing, "no bed closes it too")
	assert_equal(farm.view.compare_mark(BED_WHEAT), "", "the marks gone")
	farm.view.refresh()
	assert_false(farm.view.beds[BED_WHEAT].compare_ring.visible, "the ring gone")


func _row_of(view: Object, bed: int) -> int:
	"""Which row of the compare table shows `bed`."""
	for k: int in view.call(&"table").shown_rows():
		if view.call(&"table").row_id(k) == bed:
			return k
	return -1


# --- the planner --------------------------------------------------------------------------------------------------------

func test_g_opens_the_planner_and_g_and_esc_close_it() -> void:
	"""G toggles the planner, as the bed panel's "Planner (G)" does; Esc closes it before the Pantry or the bed."""
	var farm: DemoFarmScript = _ui._farm()
	assert_true(farm.handle_key(_key(KEY_G)), "G is the farm's")
	assert_true(farm.planner.visible, "open")
	assert_true(farm.handle_key(_key(KEY_G)), "again")
	assert_false(farm.planner.visible, "closed")
	farm.select_bed(BED_CARROTS)
	farm.bed_panel.planner_requested.emit()
	assert_true(farm.planner.visible, "the Farm panel's button opens it")
	assert_true(farm.handle_key(_key(KEY_ESCAPE)), "Esc")
	assert_false(farm.planner.visible, "Esc closes it first")
	assert_equal(farm.selected_bed, BED_CARROTS, "the bed stays open")
	var ctrl := _key(KEY_G)
	ctrl.ctrl_pressed = true
	assert_false(farm.handle_key(ctrl), "Ctrl+G is not the planner's")


func test_the_overview_rows_follow_the_filter_and_open_their_bed() -> void:
	"""All beds; Needs attention: the waterlogged one; Harvest soon: the carrots; a row press closes the planner and
	opens its bed; an empty filter says so."""
	var farm: DemoFarmScript = _ui._farm()
	var planner: PlannerScript = farm.planner
	planner.toggle()
	assert_equal(planner.overview().shown_rows(), Catalog.BED_COUNT, "every bed")
	assert_equal(planner.overview().header_texts(), PackedStringArray(Rows.COLUMN_TITLES), "the columns")
	_ui._set_moisture(farm.sim, BED_RADISH, 9500)
	planner.filter_button(Rows.FILTER_ATTENTION).pressed.emit()
	assert_equal(planner.overview().shown_rows(), 1, "one needs attention")
	assert_equal(planner.overview().row_id(0), BED_RADISH, "the waterlogged radish")
	assert_equal(planner.overview().row_colour(0), Palette.CLAY, "in clay")
	assert_equal(planner.filter_button(Rows.FILTER_ATTENTION).text, "Needs attention (1)", "counted on its button")
	planner.filter_button(Rows.FILTER_SOON).pressed.emit()
	assert_equal(planner.overview().row_id(0), BED_CARROTS, "the carrots soon")
	(planner.overview().row(0) as Button).pressed.emit()
	assert_false(planner.visible, "the planner closed")
	assert_equal(farm.selected_bed, BED_CARROTS, "the carrots' bed open")
	_ui._set_moisture(farm.sim, BED_RADISH, 6000)
	planner.toggle()
	planner.set_filter(Rows.FILTER_ATTENTION)
	assert_equal(planner.overview().shown_rows(), 0, "none now")


func test_every_tab_fills_from_the_farm() -> void:
	"""The calendar's table lists every entry; the soil plans their three columns; the record yesterday once a day has
	closed; the timeline draws the same season."""
	var farm: DemoFarmScript = _ui._farm()
	var planner: PlannerScript = farm.planner
	planner.toggle()
	planner.show_tab(PlannerScript.TAB_RECORD)
	assert_equal(planner.yesterday_text(), PlannerScript.NO_DAY_YET, "no day yet")
	farm.advance_calendar(18 * HOUR_USEC)
	planner.refresh()
	assert_equal(planner.yesterday_text(), RecordText.day_line(farm.record, 0), "yesterday")
	assert_equal(planner.record_table().shown_rows(), 1, "this season's one day")
	planner.show_tab(PlannerScript.TAB_CALENDAR)
	planner.set_table_view(1)
	assert_equal(planner.calendar_table().shown_rows(), planner.season().count(), "every entry in the table")
	assert_true(planner.calendar_table().visible and not planner.timeline().visible, "the table instead of the timeline")
	planner.set_next_season(1)
	assert_equal(planner.season().absolute_season, 1, "next season")
	planner.show_tab(PlannerScript.TAB_PLANS)
	planner.set_plan_bed(BED_CLAY)
	assert_true(planner.plan_texts(Plans.PLAN_FALLOW).begins_with("Rest it from Spring 2"), planner.plan_texts(2))
	planner.open_bed_button().pressed.emit()
	assert_equal(farm.selected_bed, BED_CLAY, "Open bed 2")


func _key(code: Key) -> InputEventKey:
	"""A pressed key."""
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event
