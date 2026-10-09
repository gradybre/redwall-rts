extends RefCounted
## THE SEASON CALENDAR's entries (decision 0451; review F45, P1's "Seasonal forecast" row, P4): what a season holds, on
## the demo's ONE calendar (demo_calendar.gd -- the very date the HUD shows). Pure data: `build` fills packed columns,
## the planner draws them as a compact timeline and as the accessible table alternative (farm_planner.gd,
## farm_timeline.gd), and test_demo_planner.gd reads them without a scene.
##
## FOUR KINDS OF KNOWING, kept apart in every entry and on screen:
##   SCHEDULED  a rule or an announcement: it will happen. §5.6's planting windows; §5.10's season baseline; the demo's
##              frost nights and blight outbreaks (farm_weather.gd's fixed schedule, published in godot/demo/README.md);
##              §5.10's season event ONCE ANNOUNCED (REQ-SET-142: three days before it starts -- never before, so the
##              calendar never shows a future the game has not disclosed); a ripe crop's grace and withering (REQ-SET-075);
##              the kitchen's planned meals (kitchen.gd plans the next four, their food reserved).
##   RECORDED   what already happened: each past day's weather as the farm's real row had it (farm_record.gd).
##   NOW        today's conditions: today's weather.
##   ESTIMATE   at today's rate, and it may move: when a crop sown in its window would ripen (at a full growth rate), when
##              each growing bed ripens (the bed panel's own figure, farm_plan_rows.gd), and until when the food in
##              store makes meals (the HUD's Ready food, kitchen.gd `days_of_meals_milli`, from today).
## What is NOT known is said, not drawn: an unannounced season event, next season's event, the weather of days to come.
##
## THE FUEL LANE (decision 0571, demo/winter/): the hearths' rule for the season (SCHEDULED: §5.8's 4 U a day a hearth
## in winter, 2 U on a spring or autumn day under 10 °C, nothing in summer), in autumn the twelve-day winter target
## (REQ-SET-114, Brendan's ruling 6: SCHEDULED on the season's last day, with the wood in store against it), and today
## either "No current heat demand" (NOW) or how long the wood heats the village at today's demand -- to REQ-SET-147's
## last heated hour (ESTIMATE). Bound with `fuel` (hearth_fuel.gd); unbound, said in the notes.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const WeatherDemo := preload("res://demo/weather/demo_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const WinterText := preload("res://demo/winter/winter_text.gd")
const WinterRules := preload("res://demo/winter/winter_rules.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const SCHEDULED: int = 0
const RECORDED: int = 1
const NOW: int = 2
const ESTIMATE: int = 3
const KNOWING_NAMES: Array[String] = ["Scheduled", "Recorded", "Now", "Estimate"]
const KNOWING_MEANING: Array[String] = ["a rule or an announcement: it will happen", "already happened",
	"today's conditions", "at today's rate: it may move"]
## The timeline's lanes, top down: the four crop rows the farm grows, the weather, frost, blight, the beds, the meals.
const LANE_ROOTS: int = 0
const LANE_CABBAGE: int = 1
const LANE_BEANS: int = 2
const LANE_GRAIN: int = 3
const LANE_WEATHER: int = 4
const LANE_FROST: int = 5
const LANE_BLIGHT: int = 6
const LANE_BEDS: int = 7
const LANE_MEALS: int = 8
const LANE_FUEL: int = 9
const LANE_COUNT: int = 10
const LANE_NAMES: Array[String] = ["Roots", "Cabbage", "Beans", "Grain", "Weather", "Frost", "Blight", "Beds", "Meals",
	"Fuel"]
## The §5.6 crop row each crop lane shows.
const LANE_CROPS: Array[int] = [FarmingScript.CROP_ROOTS, FarmingScript.CROP_CABBAGE, FarmingScript.CROP_BEANS,
	FarmingScript.CROP_GRAIN]
const DAYS: int = SimClock.DAYS_PER_SEASON

var absolute_season: int = 0
var season: int = 0
var year: int = 1
## Today, when the season shown is this one: its season day and hour (0 when it is not).
var today: int = 0
var today_hour: int = 0
## The entries, one row each: lane, knowing, first and last season day, and the words.
var lane: PackedInt32Array = PackedInt32Array()
var knowing: PackedInt32Array = PackedInt32Array()
var first_day: PackedInt32Array = PackedInt32Array()
var last_day: PackedInt32Array = PackedInt32Array()
var label: PackedStringArray = PackedStringArray()
var detail: PackedStringArray = PackedStringArray()
## A short word the timeline writes in an entry's bar when it fits ('' none): the bed, the event.
var tag: PackedStringArray = PackedStringArray()
## What is not known, said in words (see the header).
var notes: PackedStringArray = PackedStringArray()
## The hearths' fuel (see THE FUEL LANE); null: none.
var fuel: FuelScript = null

var _read: IntMath.IntResult = IntMath.IntResult.new()


func build(sim: SimScript, record: RecordScript, kitchen: KitchenScript, p_absolute_season: int) -> void:
	"""Every entry of absolute season `p_absolute_season` (this one or a later one) as known now."""
	_clear()
	absolute_season = p_absolute_season
	season = absolute_season % SimClock.SEASONS_PER_YEAR
	@warning_ignore("integer_division") year = absolute_season / SimClock.SEASONS_PER_YEAR + 1
	var now: SimClock.Calendar = sim.calendar.now()
	@warning_ignore("integer_division") var current: int = (now.absolute_day - 1) / DAYS
	today = now.season_day if current == absolute_season else 0
	today_hour = now.hour if today > 0 else 0
	_add_windows()
	_add_baseline(sim)
	_add_demo_schedule()
	_add_event(sim, current)
	_add_recorded(record, sim)
	_add_beds(sim)
	_add_meals(kitchen, sim)
	_add_fuel()


func count() -> int:
	"""How many entries there are."""
	return lane.size()


func title() -> String:
	"""'Spring, year 1'."""
	return "%s, year %d" % [CalendarScript.SEASON_TITLES[season], year]


func when_text(k: int) -> String:
	"""An entry's days: 'Spring 5–10' or 'Spring 11'."""
	var name: String = CalendarScript.SEASON_TITLES[season]
	if first_day[k] == last_day[k]:
		return "%s %d" % [name, first_day[k]]
	return "%s %d–%d" % [name, first_day[k], last_day[k]]


func order() -> PackedInt32Array:
	"""The entries by first day, then lane (the table's reading order); a stable insertion sort."""
	var out := PackedInt32Array()
	for k: int in count():
		var at: int = out.size()
		while at > 0 and _after(out[at - 1], k):
			at -= 1
		out.insert(at, k)
	return out


func _after(a: int, b: int) -> bool:
	"""Whether entry `a` reads after entry `b`."""
	return first_day[a] > first_day[b] or (first_day[a] == first_day[b] and lane[a] > lane[b])


func _clear() -> void:
	"""No entries, no notes."""
	for column: PackedInt32Array in [lane, knowing, first_day, last_day]:
		column.clear()
	label.clear()
	detail.clear()
	tag.clear()
	notes.clear()


func _add(p_lane: int, p_knowing: int, first: int, last: int, words: String, more: String, short: String = "") -> void:
	"""One entry, its days clipped to the season (dropped when none of it falls in it); `short` its bar's word."""
	var from: int = maxi(first, 1)
	var to: int = mini(last, DAYS)
	if from > to:
		return
	lane.append(p_lane)
	knowing.append(p_knowing)
	first_day.append(from)
	last_day.append(to)
	label.append(words)
	detail.append(more)
	tag.append(short)


# --- what is scheduled ------------------------------------------------------------------------------------------------

func _add_windows() -> void:
	"""§5.6's planting windows that fall in this season, and when a crop sown in them would ripen at a full rate --
	from this season's windows and the last season's that ripen into it."""
	for k: int in LANE_CROPS.size():
		var crop: int = LANE_CROPS[k]
		@warning_ignore("integer_division") var grow_days: int = (FarmingScript.CROP_GROWTH_HOURS[crop] + SimClock.HOURS_PER_DAY - 1) / SimClock.HOURS_PER_DAY
		for w: int in FarmingScript.PLANT_WINDOWS_PER_CROP:
			var index: int = crop * FarmingScript.PLANT_WINDOWS_PER_CROP + w
			var window_season: int = FarmingScript.CROP_WINDOW_SEASON[index]
			if window_season == FarmingScript.NO_WINDOW:
				continue
			var first: int = FarmingScript.CROP_WINDOW_FIRST_DAY[index]
			var last: int = FarmingScript.CROP_WINDOW_LAST_DAY[index]
			if window_season == season:
				_add(k, SCHEDULED, first, last, "Sow %s" % Text.ROWS[crop], "%s; %s soil (§5.6 planting window)" % [
					_items_of(crop), Text.soils_text(crop)])
				_add(k, ESTIMATE, first + grow_days, last + grow_days, _ripen_words(crop),
					"if sown in the window: %s at a full growth rate" % Text.span_text(FarmingScript.CROP_GROWTH_HOURS[crop]))
			elif (window_season + 1) % SimClock.SEASONS_PER_YEAR == season:
				_add(k, ESTIMATE, first + grow_days - DAYS, last + grow_days - DAYS, _ripen_words(crop),
					"if sown in last season's window: %s at a full growth rate" % Text.span_text(
					FarmingScript.CROP_GROWTH_HOURS[crop]))


static func _ripen_words(crop: int) -> String:
	"""'Roots ripen', 'Grain ripens'."""
	var row: String = Text.ROWS[crop]
	return "%s ripen%s" % [row.capitalize(), "" if row.ends_with("s") else "s"]


static func _items_of(crop: int) -> String:
	"""The farmed ingredients a §5.6 row grows, 'radish, turnip, carrot ...'."""
	var names := PackedStringArray()
	for item: int in Catalog.ITEM_COUNT:
		if Catalog.ITEM_CROP[item] == crop:
			names.append(Catalog.ITEM_LABELS[item].to_lower())
	return ", ".join(names)


func _add_baseline(sim: SimScript) -> void:
	"""§5.10's season baseline: its temperature and its daily rain, all season."""
	var row: WeatherScript = sim.crop_weather().weather()
	var tenths: int = row.baseline_temperature_tenths_of(season).value
	var rain: int = row.baseline_rain_of(season).value
	var words: String = "%s °C, rain +%s moisture points a day" % [Text.degrees_text(tenths), Text.points_text(rain, false)]
	if tenths < FarmingScript.TEMPERATURE_COOL_MIN_TENTHS:
		words += "; below freezing, nothing grows"
	_add(LANE_WEATHER, SCHEDULED, 1, DAYS, "Season baseline", words + " (§5.10)")


func _add_demo_schedule() -> void:
	"""The demo's frost nights and blight outbreaks (farm_weather.gd), every one of this season."""
	var name: String = CalendarScript.SEASON_TITLES[season]
	for day: int in range(1, DAYS + 1):
		if Weather.is_frost_night(season, day):
			_add(LANE_FROST, SCHEDULED, day, day, "Frost night", "the night into %s %d, %02d:00–%02d:59 (−3 °C); announced at "
				% [name, day, Weather.FROST_FIRST_HOUR, Weather.FROST_LAST_HOUR] + "noon the day before. Cover or raise growing beds")
		if Weather.is_blight_outbreak(season, day):
			_add(LANE_BLIGHT, SCHEDULED, day, day, "Blight outbreak", "at 00:00 on %s %d one growing bed catches blight; " % [
				name, day] + "it spreads to its neighbours at the next midnight unless cleared")


func _add_event(sim: SimScript, current: int) -> void:
	"""§5.10's season event once announced (REQ-SET-142), else what is known about it, in words."""
	var row: WeatherScript = sim.crop_weather().weather()
	if row.is_forecast_disclosed() and row.forecast_absolute_season() == absolute_season:
		var event: int = row.forecast_event()
		var first: int = row.forecast_start_day()
		_add(LANE_WEATHER, SCHEDULED, first, first + row.forecast_duration_days() - 1, "%s (announced)" %
			WeatherDemo.EVENT_NAMES[event], _event_effects(row, event), WeatherDemo.EVENT_NAMES[event])
	elif absolute_season == current:
		notes.append("This season's weather event is not announced yet: it is announced three days before it starts.")
	else:
		notes.append("%s's weather event is drawn when the season begins and announced three days before it starts." %
			CalendarScript.SEASON_TITLES[season])
	if absolute_season > current:
		notes.append("Weather for days to come is not known: only the season's baseline and announced events are.")


func _event_effects(row: WeatherScript, event: int) -> String:
	"""An announced event's §5.10 temperature and rain in this season."""
	var tenths: int = row.temperature_tenths_for(season, event).value
	var rain: int = row.rain_for(season, event).value
	return "%s °C, rain +%s moisture points a day (§5.10)" % [Text.degrees_text(tenths), Text.points_text(rain, false)]


# --- what is recorded, now, and estimated -----------------------------------------------------------------------------

func _add_recorded(record: RecordScript, sim: SimScript) -> void:
	"""Each past day's weather as recorded, and today's as it is now."""
	if record != null:
		for k: int in record.day_count():
			var day: int = record.value(k, RecordScript.F_DAY)
			@warning_ignore("integer_division") if day / DAYS == absolute_season and record.value(k, RecordScript.F_WEATHER_SEEN) == 1:
				_add(LANE_WEATHER, RECORDED, day % DAYS + 1, day % DAYS + 1, "Weather", _day_weather(record.value(k,
					RecordScript.F_TEMPERATURE), record.value(k, RecordScript.F_RAIN), record.value(k, RecordScript.F_EVENT)))
	if today > 0:
		var row: WeatherScript = sim.crop_weather().weather()
		var event: int = sim.active_event()
		_add(LANE_WEATHER, NOW, today, today, "Today", _day_weather(row.temperature_tenths(), row.rain(), event))


static func _day_weather(tenths: int, rain: int, event: int) -> String:
	"""'12 °C, rain +12 moisture points' (and the day's event)."""
	var words: String = "%s °C, %s" % [Text.degrees_text(tenths),
		"rain +%s moisture points" % Text.points_text(rain, false) if rain > 0 else "no rain"]
	if event != WeatherScript.EVENT_NONE:
		words += ", %s" % WeatherDemo.EVENT_NAMES[event]
	return words


func _add_beds(sim: SimScript) -> void:
	"""Each bed's harvest: a ripe one's grace and withering (rules), a growing one's ripening (an estimate)."""
	for bed: int in Catalog.BED_COUNT:
		var what: String = "Bed %d %s" % [bed + 1, Rows.crop_text(sim, bed).to_lower()]
		var ripe: int = Rows.ripe_tick_of(sim, bed)
		if ripe >= 0:
			_add_bed_tick(sim, bed, ripe + FarmingScript.RIPE_GRACE_HOURS * SimClock.TICKS_PER_HOUR, SCHEDULED,
				what + ": full yield ends", "48 hours after it ripened (REQ-SET-075); then −10% a day")
			_add_bed_tick(sim, bed, ripe + FarmingScript.RIPE_WITHER_HOURS * SimClock.TICKS_PER_HOUR, SCHEDULED,
				what + ": withers", "if not harvested (REQ-SET-075)")
		elif Rows.ripe_estimate_tick_into(sim, bed, _read):
			_add_bed_tick(sim, bed, _read.value, ESTIMATE, what + " ripens", "at this hour's growth rate")


func _add_bed_tick(sim: SimScript, bed: int, tick: int, how: int, words: String, more: String) -> void:
	"""A bed entry on the day of `tick`, when that day falls in this season, its hour in the detail."""
	var at: SimClock.Calendar = sim.calendar.calendar_at(tick)
	@warning_ignore("integer_division") if (at.absolute_day - 1) / DAYS == absolute_season:
		var hour: String = ("≈ %02d:00, " if how == ESTIMATE else "%02d:00, ") % at.hour
		_add(LANE_BEDS, how, at.season_day, at.season_day, words, hour + more, "Bed %d" % (bed + 1))


func _add_meals(kitchen: KitchenScript, sim: SimScript) -> void:
	"""The kitchen's planned meals (scheduled) and until when the food in store makes meals (an estimate)."""
	if kitchen == null:
		notes.append("No kitchen: meals are not planned.")
		return
	for key: int in kitchen.planned_keys():
		var plan: PackedInt32Array = kitchen.plan_of(key)
		@warning_ignore("integer_division") var day: int = key / 2
		@warning_ignore("integer_division") if plan.is_empty() or day / DAYS != absolute_season:
			continue
		_add(LANE_MEALS, SCHEDULED, day % DAYS + 1, day % DAYS + 1, "%s planned" % MealRules.MEAL_TITLES[key % 2],
			"%s, %d batches for %d portions; food reserved for %d of them" % [MealRules.DISH_SHORT[plan[0]], plan[1],
			plan[1] * MealRules.PORTIONS_PER_BATCH[plan[0]], plan[3]])
	_add_runway(kitchen, sim)


func _add_fuel() -> void:
	"""THE FUEL LANE: the season's rule, autumn's winter target, and today's demand or none (see the header)."""
	if fuel == null:
		notes.append("No hearths are kept: heating fuel is not planned.")
		return
	_add(LANE_FUEL, SCHEDULED, 1, DAYS, "Hearths' rule", _fuel_rule())
	if season == WeatherScript.SEASON_AUTUMN:
		_add(LANE_FUEL, SCHEDULED, DAYS, DAYS, "Winter target", "%s (REQ-SET-114)" % WinterText.projection_line(fuel),
			"Target")
	if today == 0:
		return
	if fuel.heating_day_milli() <= 0:
		_add(LANE_FUEL, NOW, today, today, WinterText.NO_DEMAND, WinterText.demand_line(fuel))
		return
	var last: int = fuel.last_heated_hour()
	var until: int = DAYS if WinterRules.hour_absolute_season(last) != absolute_season else WinterRules.hour_season_day(last)
	_add(LANE_FUEL, ESTIMATE, today, until, "Heated until about %s" % WinterText.hour_text(last),
		"%s; %s (%s)" % [WinterText.demand_line(fuel), WinterText.last_heated_line(fuel),
		WinterText.hud_line(fuel.fuel_days_hundredths())], "Heat")


func _fuel_rule() -> String:
	"""The season's hearth rule, in words (§5.8): the rules' own rates, in logs ("every hearth burns 4 logs a day")."""
	if season == WeatherScript.SEASON_WINTER:
		return "every hearth burns %s a day, a great hall's %s (a log heats a hearth 6 hours)" % [
			Measures.exact(&"wood", WinterRules.WINTER_DAY_MILLI), Measures.exact(&"wood", WinterRules.day_demand_milli(
			WeatherScript.SEASON_WINTER, 0, WinterRules.TIER2_FUEL_PERMILLE))]
	if season == WeatherScript.SEASON_SUMMER:
		return "no hearth is lit for heat in summer"
	return "a hearth burns %s a day on a day whose mean is under %s, else nothing" % [
		Measures.exact(&"wood", WinterRules.SHOULDER_DAY_MILLI), WinterText.degrees(WinterRules.SHOULDER_BELOW_TENTHS)]


func _add_runway(kitchen: KitchenScript, _sim: SimScript) -> void:
	"""The HUD's Ready food from today: the days of meals the stores make, at the village's portions a day."""
	if today == 0:
		return
	@warning_ignore("integer_division") var days: int = kitchen.days_of_meals_milli() / 1000
	_add(LANE_MEALS, ESTIMATE, today, today + days, "Food in store",
		"%s at %d portions a day (the HUD's Ready food: portions held and the grain and roots in store)" % [
		kitchen.days_text(), kitchen.daily_portions()])
