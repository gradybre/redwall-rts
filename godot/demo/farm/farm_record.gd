extends RefCounted
## THE AFTER-ACTION RECORD (decision 0451, review F45 and P4's work package 4): what each day produced, consumed, spoiled
## and missed -- FROM COMMITTED OUTCOMES ONLY. Pure data, no nodes: demo_farm.gd feeds it at each farm hour and posts
## each closed day (and each closed season) to the village news, the history decision 0331 keeps; the seasonal planner's
## Record tab reads it (farm_planner.gd).
##
## WHERE EACH FIGURE COMES FROM -- a ledger that only a committed change moves, read as the difference between the
## day's close and its open (so nothing here re-counts or estimates):
##   harvested     the pantry's LEDGER of food stored (farm_pantry.gd `stored_total_milli`): a harvest counts when it is
##                 credited at its store, never when it is cut, reserved or carried;
##   food used     the pantry's ledger of food withdrawn -- the kitchen's batches as they start and a hungry resident's raw
##                 meal (`withdrawn_total_milli`); split by the kitchen's own counters into cooked and raw;
##   portions      the kitchen's `portions_eaten` (a portion counts when the diner finishes it, REQ-SET-095);
##   spoiled       the pantry's ledger of food spoiled in store (by item), the portions that spoiled on the table
##                 (meal_store.gd `spoiled_portions`) and a cancelled batch's spoiled food (`cancelled_spoil_milli`);
##   missed        residents who went without at the day's meals (the kitchen's meal log, its own tally) and crops LOST:
##                 a bed whose crop withered (farm_sim.gd EVENT_WITHERED, from frost, blight or standing ripe too long).
## The day's WEATHER is read from the farm's real §5.10 row at each farm hour of that day (`note_weather`, into a short
## ring keyed by day), so the calendar can show the weather already rolled beside what is only announced. A day the
## calendar only jumped across, never seen at one of its own hours, is closed with its weather NOT SEEN
## (F_WEATHER_SEEN 0) rather than stamped with a later day's row.
##
## A DAY is the calendar's own (00:00-23:59, day index = hour index / 24 -- the kitchen's meal keys use the same); it is
## closed at the first farm hour at or after its midnight ONCE THE KITCHEN HAS RUN PAST THAT MIDNIGHT (`meals_tallied`:
## its hour index at the next day's, so its supper is tallied): a step that jumps the calendar (the Lab's "Next
## weather") reaches the farm's hour before the kitchen's next frame, so the day waits for the kitchen rather than be
## closed without its meals. A kitchen with nobody to feed never runs its hours and holds nothing. When several days end
## before a close, the first takes what happened in between.
## The last MAX_DAYS days are kept (a long 4x session runs hundreds); a season's totals are summed from the days kept.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## A year of days.
const MAX_DAYS: int = 48
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY
const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
## The per-day scalar fields.
const F_DAY: int = 0
const F_HARVESTED: int = 1
const F_USED: int = 2
const F_COOKED: int = 3
const F_RAW: int = 4
const F_PORTIONS: int = 5
const F_SPOILED: int = 6
const F_PORTIONS_SPOILED: int = 7
const F_KITCHEN_SPOILED: int = 8
const F_ATE: int = 9
const F_WITHOUT: int = 10
const F_LOST: int = 11
const F_LOST_BEDS: int = 12
const F_TEMPERATURE: int = 13
const F_RAIN: int = 14
const F_EVENT: int = 15
const F_WEATHER_SEEN: int = 16
const SCALARS: int = 17
## The per-item groups, ITEM_COUNT values each after the scalars.
const G_HARVESTED: int = 0
const G_USED: int = 1
const G_SPOILED: int = 2
const GROUPS: int = 3
const STRIDE: int = SCALARS + GROUPS * Catalog.ITEM_COUNT
## Each group's day total field.
const GROUP_TOTALS: PackedInt32Array = [F_HARVESTED, F_USED, F_SPOILED]
const NO_DAY: int = -1

var pantry: PantryScript = null
var kitchen: KitchenScript = null
var weather: WeatherScript = null
## Bumped at every close (the planner redraws its Record tab only then).
var revision: int = 0

## The kept days, STRIDE values each, oldest first.
var _days: PackedInt64Array = PackedInt64Array()
## The open day: its index, what it has noted so far, and the ledgers as they stood when it opened.
var _open_day: int = NO_DAY
var _open: PackedInt64Array = PackedInt64Array()
var _snap_items: PackedInt64Array = PackedInt64Array()
var _snap_kitchen: PackedInt64Array = PackedInt64Array()
## The ledgers as they stand at a close (reused).
var _now_items: PackedInt64Array = PackedInt64Array()
var _now_kitchen: PackedInt64Array = PackedInt64Array()
## The kitchen's counters read for a snapshot: cooked food, raw food, portions eaten, portions spoiled, cancelled.
const K_COOKED: int = 0
const K_RAW: int = 1
const K_PORTIONS: int = 2
const K_PORTIONS_SPOILED: int = 3
const K_CANCELLED: int = 4
const K_COUNT: int = 5
## The weather ring: the last WEATHER_DAYS days seen, (day, temperature, rain, event) each.
const WEATHER_DAYS: int = 4
const W_STRIDE: int = 4
var _weather_seen: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""Size the open day and its snapshots once."""
	_open.resize(STRIDE)
	_snap_items.resize(GROUPS * Catalog.ITEM_COUNT)
	_now_items.resize(GROUPS * Catalog.ITEM_COUNT)
	_snap_kitchen.resize(K_COUNT)
	_now_kitchen.resize(K_COUNT)
	_weather_seen.resize(WEATHER_DAYS * W_STRIDE)
	for slot: int in WEATHER_DAYS:
		_weather_seen[slot * W_STRIDE] = NO_DAY


func bind(p_pantry: PantryScript, p_weather: WeatherScript) -> void:
	"""Read this pantry's ledger and this weather row (the farm's real §5.10 row)."""
	pantry = p_pantry
	weather = p_weather


func set_kitchen(p_kitchen: KitchenScript) -> void:
	"""Read this kitchen's counters too, from now on (what it did before is not the open day's)."""
	kitchen = p_kitchen
	_read_kitchen_into(_snap_kitchen)


func start(hour_index: int) -> void:
	"""Open the day holding `hour_index` (the calendar's hour index), the ledgers as they stand now, its weather seen."""
	_open_day_at(hour_index / HOURS_PER_DAY)
	note_weather(hour_index)


static func day_of_hour(hour_index: int) -> int:
	"""The calendar day index (0 = spring day 1 of year 1) an hour index falls in."""
	return hour_index / HOURS_PER_DAY


func open_day() -> int:
	"""The day being recorded now (NO_DAY before `start`)."""
	return _open_day


func note_events(events: PackedInt32Array) -> int:
	"""The farm's (kind, bed) event pairs of the hour (farm_sim.gd `take_events_into`): each crop that withered is a crop
	LOST on the open day. Returns how many it counted."""
	var lost: int = 0
	for k: int in range(0, events.size() - 1, 2):
		if events[k] == SimScript.EVENT_WITHERED and Catalog.is_bed(events[k + 1]):
			_open[F_LOST] += 1
			_open[F_LOST_BEDS] |= 1 << events[k + 1]
			lost += 1
	return lost


func close_through(hour_index: int) -> int:
	"""Close every open day that ended at or before `hour_index` (see A DAY). Returns how many it closed."""
	if _open_day == NO_DAY:
		return 0
	var closed: int = 0
	while day_of_hour(hour_index) > _open_day:
		if not meals_tallied(_open_day):
			break
		_close_open_day()
		_open_day_at(_open_day + 1)
		closed += 1
	return closed


func meals_tallied(day: int) -> bool:
	"""Whether the kitchen has run past day `day`'s midnight, so its meals are tallied (see A DAY) -- always without a
	kitchen or with nobody to feed."""
	if kitchen == null or kitchen.daily_portions() == 0:
		return true
	return kitchen.hour_index() >= (day + 1) * HOURS_PER_DAY


func note_weather(hour_index: int) -> void:
	"""The farm's real row as it stands at farm hour `hour_index`: that day's weather, kept in the ring."""
	if weather == null:
		return
	var day: int = day_of_hour(hour_index)
	var at: int = (day % WEATHER_DAYS) * W_STRIDE
	_weather_seen[at] = day
	_weather_seen[at + 1] = weather.temperature_tenths()
	_weather_seen[at + 2] = weather.rain()
	_weather_seen[at + 3] = weather.event_of() if weather.is_event_active(day / DAYS_PER_SEASON,
		day % DAYS_PER_SEASON + 1) else WeatherScript.EVENT_NONE


func _open_day_at(day: int) -> void:
	"""Start recording day `day`: nothing noted, the ledgers snapshotted."""
	_open_day = day
	_open.fill(0)
	_open[F_DAY] = day
	_open[F_EVENT] = WeatherScript.EVENT_NONE
	_read_items_into(_snap_items)
	_read_kitchen_into(_snap_kitchen)


func _close_open_day() -> void:
	"""The open day's figures: the ledgers' movement since it opened, its meals and what it noted; kept, newest last."""
	_fill_items()
	_fill_kitchen()
	_fill_weather()
	_days.append_array(_open)
	if _days.size() > MAX_DAYS * STRIDE:
		_days = _days.slice(STRIDE)
	revision += 1


func _fill_weather() -> void:
	"""The open day's weather from the ring, when one of its own hours was seen (else F_WEATHER_SEEN stays 0)."""
	var at: int = (_open_day % WEATHER_DAYS) * W_STRIDE
	if _weather_seen[at] != _open_day:
		return
	_open[F_WEATHER_SEEN] = 1
	_open[F_TEMPERATURE] = _weather_seen[at + 1]
	_open[F_RAIN] = _weather_seen[at + 2]
	_open[F_EVENT] = _weather_seen[at + 3]


func _fill_items() -> void:
	"""Each item's stored, withdrawn and spoiled movement into the open day, and their totals."""
	if pantry == null:
		return
	_read_items_into(_now_items)
	for group: int in GROUPS:
		for item: int in Catalog.ITEM_COUNT:
			var at: int = group * Catalog.ITEM_COUNT + item
			var delta: int = _now_items[at] - _snap_items[at]
			_open[SCALARS + at] = delta
			_open[GROUP_TOTALS[group]] += delta


func _fill_kitchen() -> void:
	"""The kitchen's movement into the open day, and the day's two meals from its log (who ate, who went without)."""
	if kitchen == null:
		return
	var now: PackedInt64Array = _now_kitchen
	_read_kitchen_into(now)
	_open[F_COOKED] = now[K_COOKED] - _snap_kitchen[K_COOKED]
	_open[F_RAW] = now[K_RAW] - _snap_kitchen[K_RAW]
	_open[F_PORTIONS] = now[K_PORTIONS] - _snap_kitchen[K_PORTIONS]
	_open[F_PORTIONS_SPOILED] = now[K_PORTIONS_SPOILED] - _snap_kitchen[K_PORTIONS_SPOILED]
	_open[F_KITCHEN_SPOILED] = now[K_CANCELLED] - _snap_kitchen[K_CANCELLED]
	for meal: int in 2:
		var at: int = kitchen.meal_keys.rfind(_open_day * 2 + meal)
		if at >= 0:
			_open[F_ATE] += kitchen.meal_ate[at] + kitchen.meal_raw[at]
			_open[F_WITHOUT] += kitchen.meal_without[at]


func _read_items_into(out: PackedInt64Array) -> void:
	"""The pantry's three ledgers, item by item (zeros without a pantry)."""
	for item: int in Catalog.ITEM_COUNT:
		out[G_HARVESTED * Catalog.ITEM_COUNT + item] = pantry.stored_total_milli(item) if pantry != null else 0
		out[G_USED * Catalog.ITEM_COUNT + item] = pantry.withdrawn_total_milli(item) if pantry != null else 0
		out[G_SPOILED * Catalog.ITEM_COUNT + item] = pantry.spoiled_total_milli(item) if pantry != null else 0


func _read_kitchen_into(out: PackedInt64Array) -> void:
	"""The kitchen's cumulative counters (zeros without a kitchen)."""
	out.fill(0)
	if kitchen == null:
		return
	out[K_COOKED] = kitchen.consumed_food_milli
	out[K_RAW] = kitchen.raw_eaten_milli
	out[K_PORTIONS] = kitchen.portions_eaten
	out[K_PORTIONS_SPOILED] = kitchen.store.spoiled_portions
	out[K_CANCELLED] = kitchen.cancelled_spoil_milli


# --- readers ----------------------------------------------------------------------------------------------------------

func day_count() -> int:
	"""How many closed days are kept."""
	return _days.size() / STRIDE


func value(k: int, field: int) -> int:
	"""Kept day `k`'s scalar field F_* (k 0 = the oldest kept)."""
	return _days[k * STRIDE + field]


func item_value(k: int, group: int, item: int) -> int:
	"""Kept day `k`'s movement of `item` in group G_* (milli-U)."""
	return _days[k * STRIDE + SCALARS + group * Catalog.ITEM_COUNT + item]


func open_value(field: int) -> int:
	"""The open day's field as noted so far (its weather, its lost crops; the ledgers fill at its close)."""
	return _open[field]


func index_of_day(day: int) -> int:
	"""The kept row of calendar day `day`, or -1 when it is not kept (not closed yet, or too old)."""
	for k: int in day_count():
		if value(k, F_DAY) == day:
			return k
	return -1


func season_total(absolute_season: int, field: int) -> int:
	"""A field summed over the kept days of one absolute season (season index = day / 12)."""
	var total: int = 0
	for k: int in day_count():
		if value(k, F_DAY) / DAYS_PER_SEASON == absolute_season:
			total += value(k, field)
	return total


func season_item_total(absolute_season: int, group: int, item: int) -> int:
	"""An item's movement in group G_* summed over the kept days of one absolute season."""
	var total: int = 0
	for k: int in day_count():
		if value(k, F_DAY) / DAYS_PER_SEASON == absolute_season:
			total += item_value(k, group, item)
	return total


func season_days(absolute_season: int) -> int:
	"""How many of a season's days are kept (closed)."""
	var days: int = 0
	for k: int in day_count():
		if value(k, F_DAY) / DAYS_PER_SEASON == absolute_season:
			days += 1
	return days
