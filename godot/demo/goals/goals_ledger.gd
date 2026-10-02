extends RefCounted
## THE GOALS' LEDGER (decision 0781): the few running counts the built-in goals need that no model keeps for the whole
## session -- read from the models' own logs ONCE A GAME HOUR, just before the goal book evaluates, and never unlatched.
## Read-only over the village (it writes nothing into a model):
##   * PORTIONS PREPARED  every portion the kitchen has cooked (M1's "prepared 200 portions cumulatively"): the kitchen
##                        counts its batches (`batches_cooked`) and keeps the latest MAX_BATCH_LOG batches' dishes
##                        (`cooked_dishes`), so each new batch is read from the log's tail and counted at its dish's
##                        PORTIONS_PER_BATCH;
##   * DISHES             a bit for each dish the kitchen has ever cooked (meal_rules.gd DISH_*);
##   * FULL TABLES        suppers at which every resident ate a cooked portion (the kitchen's meal log, read by its KEYS,
##                        which only grow -- guide_facts.gd's reading, since the log is trimmed), judged once the
##                        supper's DAY has ended, as the planner's record reads the same tally: a diner counted while
##                        holding a portion who later gives it back is taken off the tally (`_served_but_missed`);
##   * CLEAN SEASONS      whole seasons in the seasonal planner's record (farm_record.gd, decision 0451) in which food was
##                        harvested and no crop was lost: a season is judged once all of its days are closed.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY

var portions_prepared: int = 0
var dish_mask: int = 0
var full_tables: int = 0
var clean_seasons: int = 0

var _batches_seen: int = 0
var _last_meal: int = NONE
var _season_judged: int = NONE


func observe(kitchen: KitchenScript, residents: int, record: RecordScript, hour_index: int) -> void:
	"""Read the kitchen's and the record's logs since the last look (either may be null: nothing to read), at the
	calendar's hour index `hour_index`."""
	if kitchen != null:
		_observe_batches(kitchen)
		@warning_ignore("integer_division")
		var today: int = hour_index / HOURS_PER_DAY
		_observe_tables(kitchen, residents, today)
	if record != null:
		_observe_seasons(record)


func _observe_batches(kitchen: KitchenScript) -> void:
	"""Each batch finished since the last look: its portions and its dish, from the log's tail."""
	var fresh: int = kitchen.batches_cooked - _batches_seen
	_batches_seen = kitchen.batches_cooked
	var dishes: PackedInt32Array = kitchen.cooked_dishes
	var from: int = maxi(dishes.size() - fresh, 0)
	for k: int in range(from, dishes.size()):
		var dish: int = dishes[k]
		if dish < 0 or dish >= Rules.PORTIONS_PER_BATCH.size():
			continue
		portions_prepared += Rules.PORTIONS_PER_BATCH[dish]
		dish_mask |= 1 << dish


func _observe_tables(kitchen: KitchenScript, residents: int, today: int) -> void:
	"""Each supper tallied since the last look, of a day before `today`, at which every resident ate a cooked portion."""
	var keys: PackedInt32Array = kitchen.meal_keys
	var k: int = keys.size() - 1
	while k >= 0 and keys[k] > _last_meal:
		k -= 1
	for row: int in range(k + 1, keys.size()):
		@warning_ignore("integer_division")
		var day: int = keys[row] / 2
		if day >= today:
			return
		_last_meal = keys[row]
		if residents > 0 and posmod(keys[row], 2) == Rules.MEAL_SUPPER and kitchen.meal_ate[row] >= residents:
			full_tables += 1


func _observe_seasons(record: RecordScript) -> void:
	"""Every season before the record's open day not judged yet, once each: the record closes days in order, so a season
	is over when its open day is past it. Clean when all its days are kept, food came in and no crop was lost."""
	if record.open_day() == RecordScript.NO_DAY:
		return
	@warning_ignore("integer_division")
	var last_over: int = record.open_day() / RecordScript.DAYS_PER_SEASON - 1
	for season: int in range(_season_judged + 1, last_over + 1):
		_season_judged = season
		if is_clean(record, season):
			clean_seasons += 1


static func is_clean(record: RecordScript, season: int) -> bool:
	"""Whether absolute season `season` is wholly in the record, with food harvested and no crop lost."""
	return record.season_days(season) == RecordScript.DAYS_PER_SEASON \
		and record.season_total(season, RecordScript.F_HARVESTED) > 0 \
		and record.season_total(season, RecordScript.F_LOST) == 0


func dishes_cooked() -> int:
	"""How many different everyday dishes have been cooked (meal_rules.gd `is_everyday_dish`: an occasion's course, a
	drink or a dish still waiting for an ingredient is not counted; decision 0902)."""
	var n: int = 0
	for dish: int in Rules.DISH_COUNT:
		if Rules.is_everyday_dish(dish) and dish_mask & (1 << dish) != 0:
			n += 1
	return n
