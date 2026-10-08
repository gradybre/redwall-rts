extends "res://test/framework/test_case.gd"
## The balance harness (godot/tools/balance/, decision 0911): its roll-up and CSV rules, the labour classes and the
## work board's waits on hand-built residents and a hand-built source, the policy's tally, the runner's refusal of a bad
## command line (its own headless process, no village booted) -- and, only with REDWALL_SLOW_TESTS=1, ONE SEASON of the
## real village run twice at once from the same seed, whose day records must be identical (about five minutes; the
## suite skips it otherwise, decision 0911).

const Rollup := preload("res://tools/balance/balance_rollup.gd")
const Csv := preload("res://tools/balance/balance_csv.gd")
const LabourScript := preload("res://tools/balance/balance_labour.gd")
const FarmWatch := preload("res://tools/balance/balance_farm_watch.gd")
const PolicyScript := preload("res://tools/balance/light_touch_policy.gd")
const RunScript := preload("res://tools/balance/balance_run.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const FoodScript := preload("res://tools/balance/balance_food.gd")
const EventsWatch := preload("res://tools/balance/balance_events.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const FarmSimScript := preload("res://demo/farm/farm_sim.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const ThreatsScript := preload("res://demo/events/demo_events.gd")
const SuppliesScript := preload("res://tools/balance/balance_supplies.gd")
const ProvisioningScript := preload("res://tools/balance/provisioning_policy.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const OrchardModel := preload("res://demo/orchard/orchard_model.gd")
const HallProjectsScript := preload("res://demo/hall/hall_projects.gd")
const FisheryTables := preload("res://demo/fishery/fishery_tables.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ForageRules := preload("res://demo/forage/forage_rules.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")

const RUNNER: String = "res://tools/balance/year_runner.gd"
const SLOW_ENV: String = "REDWALL_SLOW_TESTS"
const SEASON_DAYS: int = 12
## The slow run's wall-clock limit (two village processes at once).
const SLOW_LIMIT_MSEC: int = 1200000


## A work-board source whose rows the test sets by hand.
class FakeSource extends "res://demo/work/work_source.gd":
	var live_rows: PackedByteArray = PackedByteArray([0, 0])
	var waiting_rows: PackedByteArray = PackedByteArray([0, 0])
	var workers: PackedInt32Array = PackedInt32Array([-1, -1])
	var keys: PackedInt32Array = PackedInt32Array([1, 2])

	func capacity() -> int:
		"""Two rows."""
		return 2

	func live(row: int) -> bool:
		"""As set."""
		return live_rows[row] == 1

	func key(row: int) -> int:
		"""As set."""
		return keys[row]

	func worker(row: int) -> int:
		"""As set."""
		return workers[row]

	func waiting(row: int) -> bool:
		"""As set."""
		return waiting_rows[row] == 1


## A fishery whose refusals the test sets, recording what it is asked to order (never configured: no village).
class FakeFishery extends "res://demo/fishery/fishery.gd":
	var refusals: Dictionary = {}
	var mill_why: String = ""
	var ordered: Array[int] = []

	func batch_refusal(recipe: int) -> String:
		"""As set ("" unless the test refused it)."""
		return String(refusals.get(recipe, ""))

	func order_batch(recipe: int, _members: PackedInt32Array) -> String:
		"""Recorded; ordered."""
		ordered.append(recipe)
		return ""

	func mill_refusal() -> String:
		"""As set."""
		return mill_why

	func order_mill(_members: PackedInt32Array) -> String:
		"""Recorded as -1; ordered."""
		ordered.append(-1)
		return ""


## Foraging trips whose refusal and trips out the test sets, recording each trip asked for as [kind, party].
class FakeTrips extends "res://demo/forage/forage_trips.gd":
	var why: String = ""
	var out: int = 0
	var asked: Array[Vector2i] = []

	func trip_refusal(_kind_index: int, _party: int) -> String:
		"""As set."""
		return why

	func trip_count() -> int:
		"""As set."""
		return out

	func order_trip(kind_index: int, party: int, _members: PackedInt32Array) -> String:
		"""Recorded; authorised."""
		asked.append(Vector2i(kind_index, party))
		return ""


func _board_with(count: int, source: FakeSource) -> BoardScript:
	"""A work board over `count` fresh residents, with `source` as the farm's."""
	var brains: Array[BrainScript] = []
	var names: PackedStringArray = PackedStringArray()
	var keys: Array[StringName] = []
	for who: int in count:
		brains.append(BrainScript.new())
		names.append("R%d" % who)
		keys.append(&"mouse_keeper")
	var board := BoardScript.new()
	board.bind(brains, names, keys)
	if source != null:
		source.id = WorkIds.SOURCE_FARM
		board.add_source(source)
	return board


func _day(day: int, season: int, produced: int, reserve_min: int, stock: int, event: String, frost: bool) -> Dictionary:
	"""A small day record shaped like the runner's."""
	return {"day": day, "year": 0, "season": season, "season_day": day % 12 + 1, "partial": false,
		"items": {"produced": {"carrot": produced}}, "reserve_days_milli_min": reserve_min,
		"reserve_days_milli_end": reserve_min + 100, "stock": {"total_milli": stock},
		"weather": {"event": event, "frost_night": frost, "air_tenths_min": -10 * day},
		"board": {"queue_max": day, "wait_ticks_max": 10 - day},
		"labour_ticks_by_resident": [{"work": day}, {"work": 2 * day}],
		"materials": {"wood": {"in": 5, "out": 3, "end": 1000 - day}}}


func test_the_roll_up_sums_flows_and_keeps_levels_minima_and_maxima() -> void:
	"""Flows add; "_min" and "_max" fields take the least and greatest; "_end" and "stock" take the last day's."""
	var rolled: Dictionary = Rollup.roll([_day(1, 0, 500, 3000, 900, "", false), _day(2, 0, 700, 1200, 400, "", false),
		_day(3, 0, 0, 2500, 650, "", false)])
	assert_equal(rolled["days"], 3, "three days rolled")
	assert_equal((rolled["items"] as Dictionary)["produced"], {"carrot": 1200}, "produced summed per item")
	assert_equal(rolled["reserve_days_milli_min"], 1200, "the lowest reserve")
	assert_equal(rolled["reserve_days_milli_end"], 2600, "the last day's closing reserve")
	assert_equal(rolled["stock"], {"total_milli": 650}, "stock is a level: the last day's")
	assert_equal((rolled["board"] as Dictionary)["queue_max"], 3, "the longest queue")
	assert_equal((rolled["board"] as Dictionary)["wait_ticks_max"], 9, "the longest wait")
	assert_equal((rolled["weather"] as Dictionary)["air_tenths_min"], -30, "the coldest reading (negative kept)")
	assert_equal(((rolled["materials"] as Dictionary)["wood"] as Dictionary), {"in": 15, "out": 9, "end": 997},
		"material flows summed, the stock at the end the last day's")
	assert_equal(rolled["day"], 1, "identity fields keep the first day's")


func test_the_roll_up_counts_true_days_joins_texts_and_folds_rows() -> void:
	"""A flag counts the days it was true; texts join their distinct values; per-resident rows add element by element."""
	var rolled: Dictionary = Rollup.roll([_day(1, 0, 0, 0, 0, "heavy_rain", true), _day(2, 0, 0, 0, 0, "", false),
		_day(3, 0, 0, 0, 0, "heavy_rain", true), _day(4, 0, 0, 0, 0, "calm_days", false)])
	assert_equal((rolled["weather"] as Dictionary)["frost_night"], 2, "two frost nights")
	assert_equal((rolled["weather"] as Dictionary)["event"], "heavy_rain+calm_days", "distinct events in order")
	assert_equal(rolled["partial"], 0, "no partial day")
	assert_equal(rolled["labour_ticks_by_resident"], [{"work": 10}, {"work": 20}], "rows folded per resident")


func test_seasons_group_the_days_by_year_and_season() -> void:
	"""Two seasons of days make two roll-ups, in order, each over its own days."""
	var days: Array = [_day(10, 0, 100, 0, 0, "", false), _day(11, 0, 200, 0, 0, "", false),
		_day(12, 1, 400, 0, 0, "", false)]
	var seasons: Array = Rollup.seasons(days)
	assert_equal(seasons.size(), 2, "two seasons")
	assert_equal((seasons[0] as Dictionary)["days"], 2, "spring's two days")
	assert_equal(((seasons[1] as Dictionary)["items"] as Dictionary)["produced"], {"carrot": 400}, "summer's own")


func test_the_csv_has_a_row_a_day_with_item_totals() -> void:
	"""Header plus one row a day; an item ledger column sums its items; a missing figure is 0; a flag is 1 or 0."""
	var day: Dictionary = _day(5, 0, 300, 700, 0, "heavy_rain", true)
	(day["items"] as Dictionary)["produced"] = {"carrot": 300, "trout": 1200}
	var lines: PackedStringArray = Csv.of_days([day]).strip_edges().split("\n")
	assert_equal(lines.size(), 2, "header and one row")
	var header: PackedStringArray = lines[0].split(",")
	assert_equal(header.size(), Csv.COLUMNS.size(), "every column named")
	var cells: PackedStringArray = lines[1].split(",")
	assert_equal(cells[header.find("items_total/produced")], "1500", "produced summed over its items")
	assert_equal(cells[header.find("reserve_days_milli_min")], "700", "a plain figure")
	assert_equal(cells[header.find("meals/without")], "0", "absent: 0")
	assert_equal(cells[header.find("weather/frost_night")], "1", "true as 1")
	(day["weather"] as Dictionary)["event"] = "a,b"
	assert_true(Csv.of_days([day]).contains("\"a,b\""), "a text with a comma is quoted")


func test_a_task_id_keeps_its_source_row_and_key_apart() -> void:
	"""The wait table's id: different source, row or key, different id; the parts read back."""
	var id: int = LabourScript.task_id(WorkIds.SOURCE_FISHERY, 17, 123456)
	assert_equal(id >> LabourScript.SOURCE_SHIFT, WorkIds.SOURCE_FISHERY, "source")
	assert_equal((id >> LabourScript.ROW_SHIFT) & 0xFFFF, 17, "row")
	assert_equal(id & LabourScript.KEY_MASK, 123456, "key")
	assert_false(id == LabourScript.task_id(WorkIds.SOURCE_FISHERY, 17, 123457), "another task on the row")
	assert_false(id == LabourScript.task_id(WorkIds.SOURCE_WOODS, 17, 123456), "another source")


func test_each_resident_falls_in_the_first_class_that_matches() -> void:
	"""Rest (in bed, or its sleep task), work (a board task, or an order), other (in the water), else idle."""
	var source := FakeSource.new()
	var board: BoardScript = _board_with(5, source)
	var labour := LabourScript.new()
	labour.bind(board, null)
	board.brain_of(0).resting = true
	board.brain_of(1).task = SleepTaskScript.new(Callable(), Callable())
	board.brain_of(2).order = BrainScript.ORDER_MOVE
	board.brain_of(3).in_water = true
	labour.scan(0)
	assert_equal(labour.class_of(0), LabourScript.C_REST, "in bed")
	assert_equal(labour.class_of(1), LabourScript.C_REST, "on the way to bed")
	assert_equal(labour.class_of(2), LabourScript.C_WORK, "on an order")
	assert_equal(labour.class_of(3), LabourScript.C_OTHER, "in the water")
	assert_equal(labour.class_of(4), LabourScript.C_IDLE, "wandering")
	source.live_rows[0] = 1
	source.workers[0] = 4
	labour.scan(10)
	assert_equal(labour.class_of(4), LabourScript.C_WORK, "holding a board task")


func test_classified_time_is_charged_per_resident_and_class() -> void:
	"""Each classification charges the ticks since the last one; the day's totals and rows add up."""
	var board: BoardScript = _board_with(2, null)
	var labour := LabourScript.new()
	labour.bind(board, null)
	board.brain_of(0).resting = true
	labour.scan(100)
	labour.classify(100)
	labour.scan(160)
	labour.classify(160)
	var day: Dictionary = labour.close_day()
	assert_equal((day["labour_ticks"] as Dictionary)["rest"], 60, "60 ticks of rest")
	assert_equal((day["labour_ticks"] as Dictionary)["idle"], 60, "60 ticks idle")
	assert_equal(((day["labour_ticks_by_resident"] as Array)[1] as Dictionary)["idle"], 60, "the idle one's row")


func test_a_board_wait_ends_claimed_or_dropped_and_the_queue_is_time_weighted() -> void:
	"""A task waits from the scan it is first seen waiting; a worker on it ends the wait CLAIMED (its length booked), a
	task gone without one ends it DROPPED; the queue length is weighted by the ticks it stood."""
	var source := FakeSource.new()
	var board: BoardScript = _board_with(2, source)
	var labour := LabourScript.new()
	labour.bind(board, null)
	labour.scan(0)
	source.live_rows = PackedByteArray([1, 1])
	source.waiting_rows = PackedByteArray([1, 1])
	labour.scan(10)
	labour.scan(40)
	source.waiting_rows[0] = 0
	source.workers[0] = 1
	source.live_rows[1] = 0
	source.waiting_rows[1] = 0
	labour.scan(70)
	var board_day: Dictionary = labour.close_day()["board"]
	assert_equal(board_day["claimed"], 1, "one claimed")
	assert_equal(board_day["dropped"], 1, "one dropped")
	assert_equal(board_day["wait_ticks_sum"], 60, "waited from tick 10 to tick 70")
	assert_equal(board_day["queue_max"], 2, "two waiting at once")
	assert_equal(board_day["queue_task_ticks"], 2 * 10 + 2 * 30, "two tasks for 10 and 30 ticks (charged at each scan)")
	assert_equal(board_day["claimed_by_source"], {WorkIds.SOURCE_NAMES[WorkIds.SOURCE_FARM]: 1}, "by source")


func test_a_reused_row_is_a_new_task() -> void:
	"""The same row waiting under a new key ends the old task's wait (dropped) and starts the new one's."""
	var source := FakeSource.new()
	var board: BoardScript = _board_with(1, source)
	var labour := LabourScript.new()
	labour.bind(board, null)
	source.live_rows[0] = 1
	source.waiting_rows[0] = 1
	labour.scan(0)
	source.keys[0] = 99
	labour.scan(5)
	var board_day: Dictionary = labour.close_day()["board"]
	assert_equal(board_day["dropped"], 1, "the first task left the queue unclaimed")
	assert_equal(board_day["open_waits_end"], 1, "the new task still waits")


func test_a_live_row_that_stops_waiting_without_a_worker_is_dropped() -> void:
	"""Blocked or paused (still live, same task, no worker): the wait ends DROPPED, never claimed."""
	var source := FakeSource.new()
	var board: BoardScript = _board_with(1, source)
	var labour := LabourScript.new()
	labour.bind(board, null)
	source.live_rows[0] = 1
	source.waiting_rows[0] = 1
	labour.scan(0)
	source.waiting_rows[0] = 0
	labour.scan(30)
	var board_day: Dictionary = labour.close_day()["board"]
	assert_equal(board_day["claimed"], 0, "not claimed")
	assert_equal(board_day["dropped"], 1, "dropped")


func test_the_kitchen_s_roles_classify_diners_and_cooks() -> void:
	"""A diner is MEAL, a cook and a water drawer WORK, even when nothing else holds them; lying down is REST."""
	var board: BoardScript = _board_with(4, null)
	var kitchen := KitchenScript.new()
	kitchen.set(&"_role", PackedInt32Array([KitchenScript.ROLE_EAT, KitchenScript.ROLE_COOK, KitchenScript.ROLE_DRAW,
		KitchenScript.ROLE_EAT]))
	var labour := LabourScript.new()
	labour.bind(board, kitchen)
	board.brain_of(3).lying = true
	labour.scan(0)
	assert_equal(labour.class_of(0), LabourScript.C_MEAL, "a diner")
	assert_equal(labour.class_of(1), LabourScript.C_WORK, "the cook")
	assert_equal(labour.class_of(2), LabourScript.C_WORK, "a water drawer")
	assert_equal(labour.class_of(3), LabourScript.C_REST, "lying down, before its meal")


func test_meals_are_booked_to_their_own_day_once() -> void:
	"""The kitchen's meal log: each meal (key = day x 2 + meal) on its day, booked once however often it is read."""
	var kitchen := KitchenScript.new()
	var food := FoodScript.new()
	food.set(&"_kitchen", kitchen)
	kitchen.meal_keys = PackedInt32Array([6, 7])
	kitchen.meal_ate = PackedInt32Array([8, 5])
	kitchen.meal_raw = PackedInt32Array([1, 0])
	kitchen.meal_without = PackedInt32Array([0, 4])
	food._book_meals()
	food._book_meals()
	kitchen.meal_keys.append(8)
	kitchen.meal_ate.append(9)
	kitchen.meal_raw.append(0)
	kitchen.meal_without.append(0)
	food._book_meals()
	var day3: Dictionary = food._meals_of(3)
	assert_equal(day3["breakfast"], {"ate": 8, "raw": 1, "without": 0}, "day 3's breakfast")
	assert_equal(day3["supper"], {"ate": 5, "raw": 0, "without": 4}, "day 3's supper")
	assert_equal([day3["ate"], day3["raw"], day3["without"]], [13, 1, 4], "day 3's totals, booked once")
	assert_equal((food._meals_of(4)["breakfast"] as Dictionary)["ate"], 9, "day 4's breakfast on its own day")
	assert_equal(food._meals_of(3)["ate"], 0, "a day is handed out once")


func _primed_watch(beds: Array, stage: int) -> FarmWatch:
	"""A farm watch over a fresh farm whose `beds` were last seen at `stage`, full health, the day's tallies zeroed."""
	var watch := FarmWatch.new()
	watch.bind(FarmSimScript.new())
	for bed: int in beds:
		watch.book(bed, stage, 10000, false, false)
	watch.close_day(0, 1)
	return watch


func test_blight_that_kills_a_crop_is_charged_to_blight() -> void:
	"""A blighted bed that withers loses its blight mark in the same step: the stage before still names the cause."""
	var watch: FarmWatch = _primed_watch([0], FarmSimScript.STAGE_GROWING)
	watch.book(0, FarmSimScript.STAGE_BLIGHTED, 4000, true, false)
	watch.book(0, FarmSimScript.STAGE_WITHERED, 0, false, false)
	var beds: Dictionary = watch.close_day(0, 1)["beds"]
	assert_equal((beds["withered"] as Dictionary)["blight"], 1, "withered by blight")
	assert_equal((beds["health_loss"] as Dictionary)["blight"], 10000, "every point lost to blight")
	assert_equal((beds["health_loss"] as Dictionary)["other"], 0, "none to other")


func test_beds_are_booked_sown_harvested_overripe_and_frosted() -> void:
	"""Empty to sown is a sowing; ripe to empty a harvest; ripe to withered overripe; a cold hour's fall frost."""
	var watch: FarmWatch = _primed_watch([1, 4], FarmSimScript.STAGE_RIPE)
	watch.book(0, FarmSimScript.STAGE_EMPTY, 10000, false, false)
	watch.book(5, FarmSimScript.STAGE_GROWING, 10000, false, false)
	watch.close_day(0, 1)
	watch.book(0, FarmSimScript.STAGE_SOWN, 10000, false, false)
	watch.book(1, FarmSimScript.STAGE_EMPTY, 10000, false, false)
	watch.book(4, FarmSimScript.STAGE_WITHERED, 9000, false, false)
	watch.book(5, FarmSimScript.STAGE_GROWING, 9700, false, true)
	var beds: Dictionary = watch.close_day(0, 1)["beds"]
	assert_equal(beds["sown"], 1, "one sowing")
	assert_equal(beds["harvested"], 1, "one harvest")
	assert_equal((beds["withered"] as Dictionary)["overripe"], 1, "left ripe too long")
	assert_equal((beds["health_loss"] as Dictionary)["frost"], 300, "a cold hour's loss")


func test_the_crossing_into_six_charges_the_last_frost_hour() -> void:
	"""Spring 11 is a frost night (02:00-05:59): the crossing into 06:00 damages 05:00, cold at the frost figure; the
	crossing into 02:00 damages 01:00, which is not."""
	assert_true(FarmWatch.cold_hour(0, 11, 6, 120), "05:00 was a frost hour")
	assert_equal(FarmWatch.elapsed_air(0, 11, 6, 120), -30, "at the frost night's -3 °C")
	assert_false(FarmWatch.cold_hour(0, 11, 2, 120), "01:00 was not")
	assert_false(FarmWatch.cold_hour(0, 10, 6, 120), "no frost night on Spring 10")
	assert_true(FarmWatch.cold_hour(3, 5, 12, -50), "a winter hour below 0 °C is cold")


func test_material_moves_and_new_incidents_are_booked() -> void:
	"""A rise is IN and a fall OUT, the stock at the close exact; a new incident is counted by its key's first part,
	a recurrence only as an occurrence, and every critical raise from the store's own cue."""
	var stores := StoresScript.new()
	var incidents := IncidentsScript.new()
	incidents.raise("old:1", 0, IncidentsScript.SEVERITY_ROUTINE, "before the watch")
	var watch := EventsWatch.new()
	watch.bind(stores, incidents, ThreatsScript.new(), null)
	stores.add_wood(3000)
	watch.frame()
	assert_true(stores.take_wood(1000), "wood taken")
	incidents.raise("water:rescue:1", 0, IncidentsScript.SEVERITY_CRITICAL, "in difficulty")
	incidents.resolve("water:rescue:1")
	incidents.raise("water:rescue:1", 0, IncidentsScript.SEVERITY_CRITICAL, "in difficulty again")
	incidents.raise("farm:dry:2", 0, IncidentsScript.SEVERITY_WARNING, "dry")
	watch.frame()
	var day: Dictionary = watch.close_day()
	var wood: Dictionary = (day["materials"] as Dictionary)["wood"]
	assert_equal([wood["in"], wood["out"], wood["end"]], [3000, 1000, stores.wood_milli_u], "wood in, out and end")
	var counted: Dictionary = day["incidents"]
	assert_equal(counted["occurrences"], 3, "two new and one recurrence")
	assert_equal(counted["first_by_source"], {"water": 1, "farm": 1}, "new incidents by source, the old one not")
	assert_equal(counted["critical"], 2, "both critical raises")


func test_weather_events_have_their_names() -> void:
	"""§5.10's events by name; none is empty."""
	assert_equal(FarmWatch.event_name(WeatherScript.EVENT_HEAVY_RAIN), "heavy_rain", "heavy rain")
	assert_equal(FarmWatch.event_name(WeatherScript.EVENT_EARLY_FROST), "early_frost", "early frost")
	assert_equal(FarmWatch.event_name(WeatherScript.EVENT_NONE), "", "none")


func test_the_day_arithmetic() -> void:
	"""The runner's floored quotient (days from hours, seasons from days)."""
	assert_equal(RunScript.quotient(47, 24), 1, "hour 47 is day 1")
	assert_equal(RunScript.quotient(48, 24), 2, "hour 48 is day 2")
	assert_equal(RunScript.quotient(0, 12), 0, "day 0 is the first season")


func test_the_policy_counts_its_orders_by_verb_and_refusals_apart() -> void:
	"""Orders tally by verb; a "Can't ..." answer counts as refused; taking them clears the tally."""
	var policy := PolicyScript.new()
	policy._count("Sow", "Sow queued: the first free resident who can takes it")
	policy._count("Sow", "")
	policy._count("Drain", "Can't drain: not wet")
	assert_equal(policy.take_orders(), {"Sow": 2, "refused": 1}, "two sowings and a refusal")
	assert_equal(policy.take_orders(), {}, "cleared")


func test_unknown_flags_and_a_bad_seed_are_refused_wherever_they_stand() -> void:
	"""A misspelt flag (last on the line too) and a seed that is not an integer stop the run before it boots."""
	var run := RunScript.new()
	run._read_args(PackedStringArray(["--out", "/tmp/x.json", "--hourz"]))
	assert_true(run._error.begins_with("unknown argument --hourz"), "a trailing unknown flag: %s" % run._error)
	run = RunScript.new()
	run._read_args(PackedStringArray(["--seed", "seven", "--out", "/tmp/x.json"]))
	assert_true(run._error.begins_with("--seed must be an integer"), "a non-integer seed: %s" % run._error)


func test_the_runner_refuses_a_bad_command_line() -> void:
	"""An unknown policy stops the runner before the village boots: exit 2 and its error line."""
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "30",
		"--script", RUNNER, "--", "--policy", "nope", "--out", OS.get_temp_dir().path_join("balance_refused.json")]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var text: String = "".join(PackedStringArray(output))
	assert_equal(code, 2, "exit status 2")
	assert_true(text.contains("BALANCE-RUN error unknown --policy nope"), "says why: %s" % text.right(300))


func _season_args(out: String) -> PackedStringArray:
	"""The slow run's own arguments: a season of light-touch from seed 7, into `out`."""
	return PackedStringArray(["--seed", "7", "--policy", "light_touch", "--days", str(SEASON_DAYS), "--fps", "30",
		"--out", out])


func test_one_season_of_the_real_village_is_deterministic() -> void:
	"""SLOW (REDWALL_SLOW_TESTS=1): the same seed and policy, run twice at once for a season, give identical days."""
	var run := RunScript.new()
	run._read_args(_season_args("/tmp/x.json"))
	assert_equal(run._end_hour, SEASON_DAYS * 24, "the slow run's command line is a season")
	assert_equal(run._error, "", "and is accepted")
	if OS.get_environment(SLOW_ENV) != "1":
		print("test_balance_harness: the one-season determinism run is skipped (set %s=1)" % SLOW_ENV)
		return
	var paths: PackedStringArray = []
	var pids: PackedInt32Array = []
	for k: int in 2:
		paths.append(OS.get_temp_dir().path_join("balance_determinism_%d.json" % k))
		DirAccess.remove_absolute(paths[k])
		var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "30",
			"--script", RUNNER, "--"]
		args.append_array(_season_args(paths[k]))
		pids.append(OS.create_process(OS.get_executable_path(), args))
	var began: int = Time.get_ticks_msec()
	while (OS.is_process_running(pids[0]) or OS.is_process_running(pids[1])) \
			and Time.get_ticks_msec() - began < SLOW_LIMIT_MSEC:
		OS.delay_msec(500)
	for pid: int in pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	var runs: Array = []
	for path: String in paths:
		runs.append(JSON.parse_string(FileAccess.get_file_as_string(path)))
	assert_true(runs[0] is Dictionary and runs[1] is Dictionary, "both runs wrote their JSON")
	if not (runs[0] is Dictionary and runs[1] is Dictionary):
		return
	var days: Array = (runs[0] as Dictionary)["days"]
	assert_equal(days.size(), SEASON_DAYS, "a season of days")
	assert_true(days == (runs[1] as Dictionary)["days"], "the two runs' days are identical")


func _primed_supplies(fuel: FuelScript, orchard: OrchardModel, hall: HallProjectsScript) -> SuppliesScript:
	"""A supplies watch bound over every counter already non-zero, so a movement and a running total differ."""
	fuel.burned_milli = 500
	fuel.heated_hours = 3
	fuel.cold_hours = 7
	var apiary := orchard.apiary
	apiary.honey_made_milli = 900
	apiary.released_milli = 800
	apiary.fed_from_hive_milli = 700
	apiary.fed_from_pantry_milli = 600
	apiary.eaten_milli = 500
	apiary.lost_milli = 400
	apiary.wax_made_milli = 300
	apiary.missed_days = 2
	var watch := SuppliesScript.new()
	watch.bind(fuel, apiary, hall)
	return watch


func test_the_supplies_watch_books_each_counter_s_movement_and_rebases() -> void:
	"""Decision 1731: every cumulative counter booked as the day's movement, not its running total; rebased at the
	close."""
	var fuel := FuelScript.new()
	var orchard := OrchardModel.new()
	var hall := HallProjectsScript.new(StoresScript.new())
	var watch := _primed_supplies(fuel, orchard, hall)
	fuel.burned_milli += 4000
	fuel.heated_hours += 24
	fuel.cold_hours += 2
	var a := orchard.apiary
	var moves: PackedInt32Array = [11, 12, 13, 14, 15, 16, 17]
	a.honey_made_milli += moves[0]
	a.released_milli += moves[1]
	a.fed_from_hive_milli += moves[2]
	a.fed_from_pantry_milli += moves[3]
	a.eaten_milli += moves[4]
	a.lost_milli += moves[5]
	a.wax_made_milli += moves[6]
	a.missed_days += 1
	var day: Dictionary = watch.close_day()
	var h: Dictionary = day["hearths"]
	assert_equal([h["burned_milli"], h["heated_hours"], h["cold_hours"]], [4000, 24, 2], "the hearths' movements")
	var ap: Dictionary = day["apiary"]
	assert_equal([ap["honey_made_milli"], ap["released_milli"], ap["fed_from_hive_milli"], ap["fed_from_pantry_milli"],
		ap["eaten_milli"], ap["lost_milli"], ap["wax_made_milli"], ap["missed_days"]],
		[11, 12, 13, 14, 15, 16, 17, 1], "the apiary's movements, fed from the hive among them")
	var next: Dictionary = watch.close_day()
	assert_equal((next["hearths"] as Dictionary)["cold_hours"], 0, "rebased at the close")
	assert_equal((next["apiary"] as Dictionary)["fed_from_hive_milli"], 0, "rebased at the close")


func test_the_supplies_watch_reads_levels_tier_and_abandonment_at_the_close() -> void:
	"""The hives' strength, honey and feed and the hall's tier as they stand; an abandoned hive flagged."""
	var fuel := FuelScript.new()
	var orchard := OrchardModel.new()
	var hall := HallProjectsScript.new(StoresScript.new())
	var watch := _primed_supplies(fuel, orchard, hall)
	var a := orchard.apiary
	assert_true(a.store.restore_hive_state(a.hive_ref[0], 6100, 2500, 1700, 0,
		a.store.hive_serviced_day_of(a.slot_of(0)).value).ok, "the hive's state written")
	hall.tier = 2
	var day: Dictionary = watch.close_day()
	var ap: Dictionary = day["apiary"]
	assert_equal([ap["strength_min"], ap["strength_end"], ap["honey_in_hives_end"], ap["feed_in_hives_end"]],
		[6100, 6100, 1700, 2500], "the hive's levels")
	assert_equal(ap["abandoned"], false, "a living hive")
	assert_equal((day["hearths"] as Dictionary)["hall_tier_end"], 2, "the hall raised")
	assert_true(a.store.restore_hive_state(a.hive_ref[0], 400, 0, 0, 0,
		a.store.hive_serviced_day_of(a.slot_of(0)).value).ok, "a weak hive with no feed")
	orchard.close_day(3, 120)
	orchard.close_day(4, 120)
	assert_true(a.is_abandoned(0), "the hive has died")
	assert_equal((watch.close_day()["apiary"] as Dictionary)["abandoned"], true, "abandoned, flagged")


func test_fuel_days_are_written_only_while_heat_is_demanded() -> void:
	"""Fuel-days with no demand (NO_DEMAND) are left out, so a season rolls up its heated days only; with demand,
	`_min` and `_end` carry the HUD's figure."""
	var fuel := FuelScript.new()
	var watch := SuppliesScript.new()
	watch.bind(fuel, null, null)
	assert_equal(fuel.fuel_days_hundredths(), -1, "a fresh hearth table has no demand")
	var idle: Dictionary = watch.close_day()["hearths"]
	assert_false(idle.has("fuel_days_hundredths_end") or idle.has("fuel_days_hundredths_min"), "no demand: left out")
	var stores := StoresScript.new()
	fuel.bind_stores(stores)
	fuel.set_hearth(FuelScript.HALL, true)
	fuel.pass_hour(0, 3, -50, -50)
	var cold: Dictionary = watch.close_day()["hearths"]
	assert_true(fuel.fuel_days_hundredths() >= 0, "a winter hour demands heat")
	assert_equal(cold.get("fuel_days_hundredths_end", -2), fuel.fuel_days_hundredths(), "the HUD's figure")
	assert_equal(cold.get("fuel_days_hundredths_min", -2), fuel.fuel_days_hundredths(), "and as the day's minimum")
	stores.wood_milli_u = 0
	fuel.pass_hour(1, 3, -50, -50)
	assert_equal(fuel.fuel_days_hundredths(), 0, "demand and no wood: no fuel-days left")
	var out: Dictionary = watch.close_day()["hearths"]
	assert_equal(out.get("fuel_days_hundredths_min", -2), 0, "out of wood is written as 0, not left out")
	var season: Dictionary = Rollup.roll([{"hearths": idle}, {"hearths": cold}, {"hearths": idle}])
	assert_equal((season["hearths"] as Dictionary)["fuel_days_hundredths_end"], cold["fuel_days_hundredths_end"],
		"a season ending on an unheated day keeps its last heated figure")


func test_the_supplies_watch_reads_nothing_from_missing_parts() -> void:
	"""A village without a winter, an apiary or a hall: zeros, -1 for the weakest hive (none), no fuel-days."""
	var watch := SuppliesScript.new()
	watch.bind(null, null, null)
	var day: Dictionary = watch.close_day()
	assert_equal((day["hearths"] as Dictionary)["burned_milli"], 0, "no hearths")
	assert_equal((day["hearths"] as Dictionary)["hall_tier_end"], 0, "no hall")
	assert_false((day["hearths"] as Dictionary).has("fuel_days_hundredths_end"), "no fuel-days")
	assert_equal((day["apiary"] as Dictionary)["strength_end"], -1, "no hive")
	assert_equal((day["apiary"] as Dictionary)["feed_in_hives_end"], 0, "no feed")


func _provisioner(fishery: FakeFishery) -> ProvisioningScript:
	"""A provisioning player ordering through `fishery` over a fresh pantry and takes (no farm, woods or stores)."""
	fishery.pantry = PantryScript.new(StorageScript.new())
	fishery.takes = TakesScript.new()
	var policy := ProvisioningScript.new()
	policy._fishery = fishery
	return policy


func _ration_need(category: int) -> int:
	"""What a batch of rations takes of `category` (0: not an input)."""
	for k: int in Recipes.IN_COUNT[Recipes.R_RATION]:
		var input: int = Recipes.IN_FIRST[Recipes.R_RATION] + k
		if Recipes.IN_CATEGORY[input] == category:
			return Recipes.IN_MILLI[input]
	return 0


func _stock(fishery: FakeFishery, item: int, milli: int) -> void:
	"""Put `milli` of `item` in the pantry."""
	assert_true(fishery.pantry.add_into(item, milli, 0, IntMath.IntResult.new()), "%s stocked" % Catalog.ITEM_KEYS[item])


func test_the_stores_round_orders_every_recipe_the_stations_take_and_counts_the_rest() -> void:
	"""Decision 1731: each recipe row the fishery would take gets a batch, in the table's order; a refused row is counted
	under "Not ordered" with the fishery's code; nothing is milled without dried fish; one forager goes for the cheese."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	var trips := FakeTrips.new()
	policy.bind_forage(trips)
	fishery.refusals[Recipes.R_MEAD] = "Can't: no honey"
	fishery.refused_code = "NO_HONEY"
	policy._stores_round()
	var expected: Array[int] = []
	for recipe: int in Recipes.RECIPE_COUNT:
		if recipe != Recipes.R_MEAD:
			expected.append(recipe)
	assert_equal(fishery.ordered, expected, "every row but the refused one, in order; no mill without dried fish")
	assert_equal(trips.asked.size(), 1, "one forager: the nut cheese waits on nuts alone")
	var orders: Dictionary = policy.take_orders()
	assert_equal(orders.get(Recipes.VERB[Recipes.R_CORDIAL], 0), 1, "a batch counted under its verb")
	assert_equal(orders.get("Not ordered: %s (NO_HONEY)" % Recipes.VERB[Recipes.R_MEAD], 0), 1, "the refusal counted")
	assert_false(orders.has(Recipes.VERB[Recipes.R_MEAD]), "the refused row was not ordered")


func test_a_recipe_with_a_batch_waiting_is_not_ordered_again() -> void:
	"""A live rack batch (KIND_DRY) or station batch (KIND_BATCH) of a row counts as open; a take-down of a cured batch
	(which carries its recipe) does not, nor a closed row; no fishery counts none."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	var t: FisheryTables = fishery.tables
	t.j_live[0] = 1
	t.j_kind[0] = FisheryTables.KIND_BATCH
	t.j_recipe[0] = Recipes.R_RATION
	t.j_live[1] = 1
	t.j_kind[1] = FisheryTables.KIND_DRY
	t.j_recipe[1] = Recipes.R_DRY_FRUIT
	t.j_live[2] = 1
	t.j_kind[2] = FisheryTables.KIND_TAKE_DOWN
	t.j_recipe[2] = Recipes.R_DRY_FISH
	t.j_kind[3] = FisheryTables.KIND_DRY
	t.j_recipe[3] = Recipes.R_MEAD
	assert_equal(policy.open_batches(Recipes.R_RATION), 1, "a live station batch")
	assert_equal(policy.open_batches(Recipes.R_DRY_FRUIT), 1, "a live rack batch")
	assert_equal(policy.open_batches(Recipes.R_DRY_FISH), 0, "a take-down is not a new batch")
	assert_equal(policy.open_batches(Recipes.R_MEAD), 0, "a closed row is not open")
	policy._stores_round()
	assert_false(Recipes.R_RATION in fishery.ordered or Recipes.R_DRY_FRUIT in fishery.ordered, "waiting: not again")
	assert_true(Recipes.R_DRY_FISH in fishery.ordered and Recipes.R_MEAD in fishery.ordered, "the others ordered")
	assert_equal(ProvisioningScript.new().open_batches(Recipes.R_RATION), 0, "no fishery: none")


func test_the_runner_accepts_the_provisioning_policy() -> void:
	"""The third policy is on the command line's list."""
	var run := RunScript.new()
	run._read_args(PackedStringArray(["--policy", "provisioning", "--out", "/tmp/x.json"]))
	assert_equal(run._error, "", "accepted")
	assert_true("provisioning" in RunScript.POLICIES, "listed")


func test_a_row_waits_on_one_input_only_when_every_other_is_free() -> void:
	"""Decision 1731: `waits_only_on` -- the category short and every other input free (one milli-U either side)."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	assert_true(policy.waits_only_on(Recipes.R_CHEESE, Catalog.CAT_NUTS), "nut cheese with no nuts: waits on nuts alone")
	_stock(fishery, Catalog.ITEM_HONEY, 10000)
	assert_false(policy.waits_only_on(Recipes.R_MEAD, Catalog.CAT_NUTS), "mead, its honey there, takes no nuts")
	assert_false(policy.waits_only_on(Recipes.R_RATION, Catalog.CAT_NUTS), "rations lack their flour and dried fish too")
	_stock(fishery, Catalog.ITEM_FLOUR, _ration_need(Catalog.CAT_FLOUR))
	_stock(fishery, Catalog.ITEM_DRIED_FISH, _ration_need(Catalog.CAT_DRIED_FISH) - 1)
	assert_false(policy.waits_only_on(Recipes.R_RATION, Catalog.CAT_NUTS), "dried fish one milli-U short: not nuts alone")
	_stock(fishery, Catalog.ITEM_DRIED_FISH, 1)
	assert_true(policy.waits_only_on(Recipes.R_RATION, Catalog.CAT_NUTS), "flour and dried fish there: nuts alone")
	var take: int = fishery.takes.new_take()
	assert_true(fishery.takes.reserve_into(fishery.pantry, take, Catalog.CAT_DRIED_FISH, 1, 0, IntMath.IntResult.new()),
		"a meal holds one milli-U of the dried fish")
	assert_false(policy.waits_only_on(Recipes.R_RATION, Catalog.CAT_NUTS), "held food is not free: not nuts alone")
	assert_false(policy.ration_input_free(Catalog.CAT_DRIED_FISH), "nor is the dried fish free")
	_stock(fishery, Catalog.ITEM_NUTS, _ration_need(Catalog.CAT_NUTS))
	assert_false(policy.waits_only_on(Recipes.R_RATION, Catalog.CAT_NUTS), "nuts at the need: nothing waits")


func test_the_ration_reserve_s_food_counts_as_the_rations() -> void:
	"""Decision 1742: food the ration reserve holds is not free, but it is the rations' -- `ration_input_free` counts it,
	so the chain's mill and nuts steps see a batch held for; with no reserve, held food is not counted."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	_stock(fishery, Catalog.ITEM_DRIED_FISH, _ration_need(Catalog.CAT_DRIED_FISH))
	fishery.ration_reserve.configure(fishery.pantry, fishery.takes)
	fishery.ration_reserve.target_milli = 6000
	fishery.ration_reserve.top_up(0, 0)
	assert_equal(fishery.takes.free_milli_of_crop(fishery.pantry, Catalog.CAT_DRIED_FISH), 0, "all of it held")
	assert_true(policy.ration_input_free(Catalog.CAT_DRIED_FISH), "held for rations: theirs")
	assert_true(policy.wants_nuts(), "so the rations wait on their nuts")
	var other := FakeFishery.new()
	var bare := _provisioner(other)
	_stock(other, Catalog.ITEM_DRIED_FISH, _ration_need(Catalog.CAT_DRIED_FISH))
	var take: int = other.takes.new_take()
	assert_true(other.takes.reserve_into(other.pantry, take, Catalog.CAT_DRIED_FISH, 1, 0, IntMath.IntResult.new()),
		"a meal holds one milli-U")
	assert_false(bare.ration_input_free(Catalog.CAT_DRIED_FISH), "held by a meal: not the rations'")


func test_one_forager_goes_for_nuts_while_a_batch_waits_on_them() -> void:
	"""Nuts are wanted while some batch waits on them alone (the cheese takes the most); none once the largest need is
	met; a trip out or the woods refusing sends nobody."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	var trips := FakeTrips.new()
	policy.bind_forage(trips)
	for recipe: int in Recipes.RECIPE_COUNT:
		fishery.refusals[recipe] = "Can't"
	assert_equal(ForageRules.KIND_WORDS[ProvisioningScript.NUTS_KIND], "nuts", "the kind sent for is nuts")
	var cheese: int = Recipes.IN_MILLI[Recipes.IN_FIRST[Recipes.R_CHEESE]]
	_stock(fishery, Catalog.ITEM_NUTS, cheese - 1)
	assert_true(policy.wants_nuts(), "one milli-U short of a cheese batch: wanted")
	trips.out = 1
	policy._stores_round()
	trips.out = 0
	trips.why = "nuts are out of season now"
	policy._stores_round()
	assert_true(trips.asked.is_empty(), "a trip out, or the woods refusing: none sent")
	trips.why = ""
	policy._stores_round()
	assert_equal(trips.asked, [Vector2i(ProvisioningScript.NUTS_KIND, ForageRules.PARTY_MIN)] as Array[Vector2i],
		"one forager sent")
	assert_equal(policy.take_orders().get("Forage (nuts)", 0), 1, "counted")
	_stock(fishery, Catalog.ITEM_NUTS, 1)
	assert_false(policy.wants_nuts(), "every batch's nuts there: not wanted")
	policy._stores_round()
	assert_equal(trips.asked.size(), 1, "none sent")
	var take: int = fishery.takes.new_take()
	assert_true(fishery.takes.reserve_into(fishery.pantry, take, Catalog.CAT_NUTS, 1, 0, IntMath.IntResult.new()),
		"a meal holds one milli-U of the nuts")
	assert_true(policy.wants_nuts(), "held nuts are not free: wanted again")


func test_nuts_are_not_wanted_for_a_cheese_that_could_not_be_ordered() -> void:
	"""A cheese batch already waiting, or every crock taken, is not a batch waiting on nuts (the review of beb3bb3b)."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	assert_true(policy.could_order(Recipes.R_CHEESE) and policy.wants_nuts(), "no nuts, a free crock: wanted")
	var t: FisheryTables = fishery.tables
	t.j_live[0] = 1
	t.j_kind[0] = FisheryTables.KIND_DRY
	t.j_recipe[0] = Recipes.R_CHEESE
	assert_false(policy.could_order(Recipes.R_CHEESE), "a cheese batch waiting")
	assert_false(policy.wants_nuts(), "so its nuts are not wanted (rations lack their dried fish)")
	t.j_live[0] = 0
	var first: int = Recipes.STATION_FIRST_SLOT[Recipes.STATION_TABLE]
	for slot: int in range(first, first + Recipes.STATION_SLOTS[Recipes.STATION_TABLE]):
		t.s_state[slot] = FisheryTables.SLOT_CURING
	assert_false(policy.could_order(Recipes.R_CHEESE), "every crock taken")
	assert_false(policy.wants_nuts(), "no crock: not wanted")
	assert_true(policy.could_order(Recipes.R_RATION), "a batch row needs no slot")


func test_flour_is_ground_only_once_rations_lack_nothing_else() -> void:
	"""The mill grinds only when the free flour is short and a batch's dried fish and nuts are both free, and the mill
	takes it -- never the kitchen's grain for a batch that cannot be made."""
	var fishery := FakeFishery.new()
	var policy := _provisioner(fishery)
	for recipe: int in Recipes.RECIPE_COUNT:
		fishery.refusals[recipe] = "Can't"
	_stock(fishery, Catalog.ITEM_NUTS, _ration_need(Catalog.CAT_NUTS))
	policy._stores_round()
	assert_true(fishery.ordered.is_empty(), "no dried fish: nothing ground")
	_stock(fishery, Catalog.ITEM_DRIED_FISH, _ration_need(Catalog.CAT_DRIED_FISH))
	fishery.mill_why = "Can't: both mill slots are grinding"
	policy._stores_round()
	assert_true(fishery.ordered.is_empty(), "the mill refusing: nothing ground")
	fishery.mill_why = ""
	policy._stores_round()
	assert_equal(fishery.ordered, [-1] as Array[int], "dried fish and nuts there, flour short: ground")
	_stock(fishery, Catalog.ITEM_FLOUR, _ration_need(Catalog.CAT_FLOUR))
	policy._stores_round()
	assert_equal(fishery.ordered, [-1] as Array[int], "flour at the need: not ground again")
	var short := FakeFishery.new()
	var other := _provisioner(short)
	for recipe: int in Recipes.RECIPE_COUNT:
		short.refusals[recipe] = "Can't"
	_stock(short, Catalog.ITEM_DRIED_FISH, _ration_need(Catalog.CAT_DRIED_FISH))
	other._stores_round()
	assert_true(short.ordered.is_empty(), "dried fish there but no nuts: nothing ground")


func test_fish_high_sets_the_scripted_player_s_fishing_line() -> void:
	"""--fish-high U (decision 1738, the balance rerun's P6): whole units for a policy that fishes; refused for
	hands_off and for a non-integer; unset, the policy keeps FISH_STOCK_HIGH."""
	var run := RunScript.new()
	run._read_args(PackedStringArray(["--policy", "provisioning", "--fish-high", "12", "--out", "/tmp/x.json"]))
	assert_equal([run._error, run._fish_high_milli], ["", 12000], "12 U")
	run = RunScript.new()
	run._read_args(PackedStringArray(["--policy", "hands_off", "--fish-high", "12", "--out", "/tmp/x.json"]))
	assert_true(run._error.begins_with("--fish-high must be"), "hands_off does not fish: %s" % run._error)
	run = RunScript.new()
	run._read_args(PackedStringArray(["--policy", "light_touch", "--fish-high", "lots", "--out", "/tmp/x.json"]))
	assert_true(run._error.begins_with("--fish-high must be"), "not a number: %s" % run._error)
	run = RunScript.new()
	run._read_args(PackedStringArray(["--policy", "light_touch", "--fish-high", "0", "--out", "/tmp/x.json"]))
	assert_equal([run._error, run._fish_high_milli], ["", 0], "0 U: no trip ever")
	assert_equal(PolicyScript.new().fish_stock_high, PolicyScript.FISH_STOCK_HIGH, "unset: the policy's 4 U")
