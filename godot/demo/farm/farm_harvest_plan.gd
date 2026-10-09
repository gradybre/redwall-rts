extends RefCounted
## HARVEST PLANS FOR THE HANDS AVAILABLE (review ECO-003, decision 0882): before the beds are sown, a farm STRATEGY says
## when each empty bed is sown, the projection says when everything ripens and what each harvest day asks of the
## village -- the work against the hands, the food against the store room and against what the kitchen eats before it
## spoils -- and a projected overload SUGGESTS a later sowing or a smaller area. It never changes a crop: a bed's crop
## is the one the player chose (Plant…). The chosen plan is BOOKED as one farm order (`book`).
##
## THE STRATEGIES, for the laid, empty beds that have a crop chosen (the rest are shown as they stand):
##   STEADY TABLE           each crop's beds are sown a few days apart, so they ripen one after another: the k-th bed of
##                          a crop (in bed order) is sown `k x gap` days after the first legal day, the gap its growth
##                          days shared among its beds (at least a day), and never past its planting window;
##   ONE PRESERVING HARVEST every bed is sown on its crop's first legal day, so a crop's beds ripen together: one big
##                          harvest to keep or preserve;
##   CUSTOM DATES           each bed's day is the player's own (Earlier / Later), held inside its planting window.
## A day is "legal" when §5.6's planting window and the bed's soil allow the crop (farm_soil_plans.gd
## `first_window_day`); HORIZON_DAYS ahead at most.
##
## THE PROJECTION is an ESTIMATE at a FULL growth rate -- the soil plans' stated assumption: cold, a dry or waterlogged
## bed, frost and blight slow or spoil a crop -- so a planned bed ripens `ceil(growth hours / 24)` days after it is
## sown; a growing crop ripens when the bed panel says (at this hour's rate) and a ripe one today. Its harvest is
## REQ-SET-074's formula at full health (farm_text.gd `sown_estimate_milli`, the picker's own), or the standing crop's
## expected yield. For each HARVEST DAY:
##   * WORK -- each harvest's own work (farm_jobs.gd `plan_work_usec`: cutting and the drop, the walks not counted, as
##     the action cards) against the HANDS: the field crew (farm_crew.gd `crew`) for GDD §5.3's ten work hours a day
##     (farm_soil_plans.gd WORK_HOURS_PER_STAFF_DAY), on the demo's own clock;
##   * ROOM -- the day's harvest against the stores' free room now (the pantry's locations);
##   * KEEPING -- each crop row's harvest against what the kitchen eats of it before it spoils: the kitchen's daily use
##     of the row (each meal's dish -- meal_rules.gd `dish_for_meal` -- its input for the batches the residents need)
##     over the days the food keeps in the slowest-spoiling store at the season's temperature (GDD §5.8). A row no dish
##     uses (cabbage, beans: farm_crop_roles.gd) is eaten only raw by the hungry, so all of it is at risk.
## An OVERLOAD on a day -- more work than hands, more food than room, more than is eaten before it spoils -- gives a
## SUGGESTION: the last bed planned to ripen that day, sown later by the days its window allows (or "leave it empty this
## time": a smaller area). Nothing is changed until the player changes a date or books.
##
## BOOKING (R06-JOB-005's field-cycle wording, applied per bed): a bed planned for today has its sowing ordered now; a
## later one is BOOKED for its day and its crop, and ordered (ORIGIN_ROUTINE) on the first farm hour of that day the
## bed can be sown. A booking whose day has come but whose window is missed waits, warned once, for its next legal
## window or the player's edit; one whose crop the player has since changed is dropped, said once. It never sows a
## crop the player did not choose.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const Plans := preload("res://demo/farm/farm_soil_plans.gd")
const Roles := preload("res://demo/farm/farm_crop_roles.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const STRATEGY_STEADY: int = 0
const STRATEGY_PRESERVE: int = 1
const STRATEGY_CUSTOM: int = 2
const STRATEGY_COUNT: int = 3
const STRATEGY_NAMES: Array[String] = ["Steady table", "One preserving harvest", "Custom dates"]
const STRATEGY_NOTES: Array[String] = ["each crop's beds sown a few days apart, so they ripen one after another",
	"each crop's beds sown together, for one big harvest to keep or preserve", "each bed on the day you set"]
const NO_DAY: int = 0
## How far ahead a plan looks for a legal sowing day: one season (§5.10's twelve days).
const HORIZON_DAYS: int = SimClock.DAYS_PER_SEASON
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY
## A planned row's state.
const ROW_STANDING: int = 0
const ROW_PLANNED: int = 1
const ROW_NO_CROP: int = 2
const ROW_NO_DAY: int = 3
const ROW_RESTING: int = 4
const OVER_WORK: int = 1
const OVER_ROOM: int = 2
const OVER_KEEPING: int = 4

## One bed in the plan.
class Row extends RefCounted:
	var bed: int = 0
	var item: int = Catalog.NO_ITEM
	var state: int = 0
	var sow_day: int = 0
	var ripe_day: int = 0
	var milli: int = 0
	var work_usec: int = 0


## One harvest day of the plan.
class Day extends RefCounted:
	var day: int = 0
	var beds: PackedInt32Array = PackedInt32Array()
	var milli: int = 0
	var work_usec: int = 0
	## Per §5.6 crop row: the milli-U ripening that day.
	var row_milli: PackedInt64Array = PackedInt64Array()
	var over: int = 0
	var at_risk_milli: int = 0

var strategy: int = STRATEGY_STEADY
## Per bed: the player's own sowing day under CUSTOM (NO_DAY: the first legal day).
var custom_day: PackedInt32Array = PackedInt32Array()
## Per bed: the booked sowing day and crop (NO_DAY / NO_ITEM: none), and whether its missed window was said.
var booked_day: PackedInt32Array = PackedInt32Array()
var booked_item: PackedInt32Array = PackedInt32Array()
var _warned: PackedByteArray = PackedByteArray()
var revision: int = 0

var _sim: SimScript = null
var _crew: CrewScript = null
var _pantry: PantryScript = null
## `() -> int`: how many residents the kitchen feeds.
var _residents: Callable = Callable()
## `(text: String) -> void`: a booking's news.
var _notice: Callable = Callable()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _none: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""No custom days, no bookings."""
	for column: PackedInt32Array in [custom_day, booked_day]:
		column.resize(Catalog.BED_COUNT)
	booked_item.resize(Catalog.BED_COUNT)
	booked_item.fill(Catalog.NO_ITEM)
	_warned.resize(Catalog.BED_COUNT)


func configure(sim: SimScript, crew: CrewScript, pantry: PantryScript, residents: Callable,
		notice: Callable = Callable()) -> void:
	"""Plan this farm's harvests for this crew and these stores; `residents() -> int` the mouths the kitchen feeds;
	`notice(text)` posts a booking's news (none: kept quiet)."""
	_sim = sim
	_crew = crew
	_pantry = pantry
	_residents = residents
	_notice = notice


func set_strategy(which: int) -> void:
	"""Choose STRATEGY_*."""
	strategy = clampi(which, STRATEGY_STEADY, STRATEGY_CUSTOM)
	revision += 1


func today() -> int:
	"""The farm calendar's day now."""
	return _sim.absolute_day()


func farm_revision() -> int:
	"""The farm's revision (a reader's cue to recompute)."""
	return _sim.revision


func hour_index() -> int:
	"""The calendar hour now (a reader's cue to recompute: the estimates move with the hour)."""
	return _sim.calendar.hour_index()


# --- the rows -------------------------------------------------------------------------------------------------------

func rows() -> Array[Row]:
	"""Every laid bed's row, in bed order (see THE STRATEGIES and THE PROJECTION)."""
	var out: Array[Row] = []
	var sowing: PackedInt32Array = sow_days()
	for bed: int in Catalog.BED_COUNT:
		if _sim.is_laid(bed):
			out.append(_row(bed, sowing[bed]))
	return out


func _row(bed: int, sow_day: int) -> Row:
	"""One bed's row: standing (its crop's ripening), planned (its sowing day and ripening), or why there is none."""
	var row := Row.new()
	row.bed = bed
	row.item = _sim.item_of(bed)
	if Catalog.is_item(row.item):
		row.state = ROW_STANDING
		_standing(row)
		return row
	row.item = _sim.chosen_of(bed)
	if _sim.is_fallow(bed):
		row.state = ROW_RESTING
	elif not Catalog.is_item(row.item):
		row.state = ROW_NO_CROP
	elif sow_day == NO_DAY:
		row.state = ROW_NO_DAY
	else:
		row.state = ROW_PLANNED
		row.sow_day = sow_day
		row.ripe_day = sow_day + ripen_days(row.item)
		row.milli = Text.sown_estimate_milli(_sim, bed, row.item)
		row.work_usec = harvest_usec()
	return row


func _standing(row: Row) -> void:
	"""A standing crop: ripe today, or when the bed panel says at this hour's rate (none when stalled or withered)."""
	if _sim.stage_of(row.bed) == SimScript.STAGE_RIPE:
		row.ripe_day = today()
	elif Rows.ripe_estimate_tick_into(_sim, row.bed, _read):
		@warning_ignore("integer_division") row.ripe_day = CalendarScript.hour_index_at(_read.value) / HOURS_PER_DAY + 1
	if row.ripe_day != NO_DAY and _sim.expected_yield_into(row.bed, _read):
		row.milli = _read.value
		row.work_usec = harvest_usec()


static func ripen_days(item: int) -> int:
	"""Whole days from sowing to ripe at a full rate: §5.6's growth hours, rounded up to days."""
	@warning_ignore("integer_division") return (FarmingScript.CROP_GROWTH_HOURS[Catalog.crop_of(item)] + HOURS_PER_DAY - 1) / HOURS_PER_DAY


static func harvest_usec() -> int:
	"""A harvest's own work (cutting and the drop; farm_jobs.gd `plan_work_usec`), demo microseconds."""
	return JobsScript.plan_work_usec(JobsScript.KIND_HARVEST, 0)


# --- the strategies -------------------------------------------------------------------------------------------------

func sow_days() -> PackedInt32Array:
	"""Per bed, the day the strategy sows it (NO_DAY: not an empty bed with a crop chosen, or no legal day ahead)."""
	var out := PackedInt32Array()
	out.resize(Catalog.BED_COUNT)
	var rank := PackedInt32Array()
	rank.resize(FarmingScript.CROP_COUNT)
	var count: PackedInt32Array = _planned_per_crop()
	for bed: int in Catalog.BED_COUNT:
		if not _plannable(bed):
			continue
		var crop: int = Catalog.crop_of(_sim.chosen_of(bed))
		out[bed] = _day_for(bed, rank[crop], count[crop])
		rank[crop] += 1
	return out


func is_planned(bed: int) -> bool:
	"""Whether a bed is in the plan to be sown (laid, empty, not resting, a crop chosen): what Earlier / Later act on."""
	return Catalog.is_bed(bed) and _plannable(bed)


func _plannable(bed: int) -> bool:
	"""Whether a bed is planned: laid, empty, not resting, a crop chosen."""
	return _sim.is_laid(bed) and _sim.stage_of(bed) == SimScript.STAGE_EMPTY and not _sim.is_fallow(bed) \
		and Catalog.is_item(_sim.chosen_of(bed))


func _planned_per_crop() -> PackedInt32Array:
	"""How many planned beds each §5.6 row has."""
	var out := PackedInt32Array()
	out.resize(FarmingScript.CROP_COUNT)
	for bed: int in Catalog.BED_COUNT:
		if _plannable(bed):
			out[Catalog.crop_of(_sim.chosen_of(bed))] += 1
	return out


func _day_for(bed: int, k: int, of: int) -> int:
	"""Bed `bed`'s sowing day as the `k`-th of `of` planned beds of its crop (see THE STRATEGIES)."""
	var first: int = first_legal_day(bed, today())
	if first == NO_DAY:
		return NO_DAY
	match strategy:
		STRATEGY_STEADY:
			@warning_ignore("integer_division") var gap: int = maxi(1, ripen_days(_sim.chosen_of(bed)) / maxi(of, 1))
			return latest_legal_day(bed, first, first + k * gap)
		STRATEGY_CUSTOM:
			return latest_legal_day(bed, first, maxi(custom_day[bed], first))
	return first


func first_legal_day(bed: int, from_day: int) -> int:
	"""The first day from `from_day`, within HORIZON_DAYS, the bed's chosen crop may be sown (NO_DAY: none)."""
	var crop: int = Catalog.crop_of(_sim.chosen_of(bed))
	return Plans.first_window_day(crop, Catalog.BED_SOILS[bed], from_day, today() + HORIZON_DAYS)


func latest_legal_day(bed: int, first: int, wanted: int) -> int:
	"""The latest legal day from `first` up to `wanted` (inside the window and the horizon): `wanted` when it is legal,
	else the window's last legal day before it."""
	var crop: int = Catalog.crop_of(_sim.chosen_of(bed))
	var day: int = mini(wanted, today() + HORIZON_DAYS)
	while day > first:
		if Plans.first_window_day(crop, Catalog.BED_SOILS[bed], day, day) == day:
			return day
		day -= 1
	return first


func shift(bed: int, by_days: int) -> String:
	"""CUSTOM: move a planned bed's sowing `by_days` later (negative: earlier), inside its window. Switches to CUSTOM,
	keeping every other bed's day as the strategy had it. Returns what changed."""
	if not _plannable(bed):
		return "Bed %d has no planned sowing: Plant… a crop in an empty bed first" % (bed + 1)
	var first: int = first_legal_day(bed, today())
	if first == NO_DAY:
		return "Bed %d: %s has no sowing day this season ahead (sow in %s)" % [bed + 1,
			Catalog.ITEM_LABELS[_sim.chosen_of(bed)].to_lower(), Text.window_text(Catalog.crop_of(_sim.chosen_of(bed)))]
	var days_now: PackedInt32Array = sow_days()
	if strategy != STRATEGY_CUSTOM:
		custom_day = days_now.duplicate()
		strategy = STRATEGY_CUSTOM
	var wanted: int = maxi(days_now[bed] + by_days, first)
	custom_day[bed] = latest_legal_day(bed, first, wanted) if by_days > 0 else _earliest_legal(bed, first, wanted)
	revision += 1
	return "Bed %d: sown %s" % [bed + 1, day_text(custom_day[bed])]


func _earliest_legal(bed: int, first: int, wanted: int) -> int:
	"""The first legal day at or after `wanted` (moving earlier stays legal), `first` at least."""
	var crop: int = Catalog.crop_of(_sim.chosen_of(bed))
	var found: int = Plans.first_window_day(crop, Catalog.BED_SOILS[bed], wanted, today() + HORIZON_DAYS)
	return found if found != NO_DAY else first


# --- the harvest days ------------------------------------------------------------------------------------------------

func days() -> Array[Day]:
	"""Every day the plan harvests on, in day order, with its work, food and overloads (see THE PROJECTION)."""
	var out: Array[Day] = []
	for row: Row in rows():
		if row.ripe_day == NO_DAY or row.milli <= 0:
			continue
		var day: Day = _day_of(out, row.ripe_day)
		day.beds.append(row.bed)
		day.milli += row.milli
		day.work_usec += row.work_usec
		day.row_milli[Catalog.crop_of(row.item)] += row.milli
	for day: Day in out:
		_judge(day)
	return out


func _day_of(out: Array[Day], day_number: int) -> Day:
	"""The Day for `day_number` in `out`, added in day order when new."""
	var at: int = 0
	while at < out.size() and out[at].day < day_number:
		at += 1
	if at < out.size() and out[at].day == day_number:
		return out[at]
	var day := Day.new()
	day.day = day_number
	day.row_milli.resize(FarmingScript.CROP_COUNT)
	out.insert(at, day)
	return day


func _judge(day: Day) -> void:
	"""A harvest day's overloads: work over the hands, food over the room, food over what is eaten before it spoils."""
	day.over = 0
	if day.work_usec > hands_usec():
		day.over |= OVER_WORK
	if day.milli > room_milli():
		day.over |= OVER_ROOM
	day.at_risk_milli = 0
	for crop: int in FarmingScript.CROP_COUNT:
		day.at_risk_milli += maxi(day.row_milli[crop] - eaten_before_spoiling_milli(crop, day.day), 0)
	if day.at_risk_milli > 0:
		day.over |= OVER_KEEPING


func hands() -> int:
	"""The field crew's hands (farm_crew.gd `crew`)."""
	return _crew.crew().size() if _crew != null else 0


func hands_usec() -> int:
	"""A day of the field crew's work on the demo's clock: hands x GDD §5.3's ten work hours."""
	return hands() * Plans.WORK_HOURS_PER_STAFF_DAY * CalendarScript.HOUR_USEC


func room_milli() -> int:
	"""The stores' free room now, milli-U (every pantry location's)."""
	if _pantry == null:
		return 0
	var room: int = 0
	for location: int in _pantry.storage.count():
		room += maxi(_pantry.room_milli_of(location), 0)
	return room


func daily_use_milli(crop: int) -> int:
	"""What the kitchen eats of a §5.6 row in a day, milli-U: each meal's dish (meal_rules.gd `dish_for_meal`) takes
	its input or second input of the row for the batches the residents need (a portion and a half each, decision
	1732)."""
	var mouths: int = int(_residents.call()) if _residents.is_valid() else 0
	var use: int = 0
	for meal: int in MealRules.MEAL_NAMES.size():
		var dish: int = MealRules.dish_for_meal(meal)
		var per_batch: int = MealRules.PORTIONS_PER_BATCH[dish]
		@warning_ignore("integer_division") var batches: int = (MealRules.portions_for(mouths) + per_batch - 1) / per_batch
		if MealRules.INPUT_CROP[dish] == crop:
			use += batches * MealRules.INPUT_MILLI[dish]
		if MealRules.SIDE_CROP[dish] == crop:
			use += batches * MealRules.SIDE_MILLI[dish]
	return use


func keep_days(crop: int, day_number: int) -> int:
	"""Whole days a row's harvest keeps in the slowest-spoiling store, at the harvest season's temperature (§5.8)."""
	var permille: int = StockAge.STORE_FACTOR[StockAge.STORAGE_COVERED_STORE]
	if _pantry != null:
		for location: int in _pantry.storage.count():
			permille = mini(permille, _pantry.storage.permille_of(location))
	var season_factor: int = StockAge.TEMPERATURE_FACTOR[Plans.season_of_day(day_number)]
	@warning_ignore("integer_division") var hours: int = Catalog.CROP_SHELF_HOURS[crop] * 1000000 / maxi(permille * season_factor, 1)
	@warning_ignore("integer_division") return hours / HOURS_PER_DAY


func eaten_before_spoiling_milli(crop: int, day_number: int) -> int:
	"""How much of a row's harvest the kitchen eats before it spoils (0 for a row no dish uses)."""
	return daily_use_milli(crop) * keep_days(crop, day_number)


func suggestion(day: Day) -> String:
	"""What would ease an overloaded day ('' for none): the last bed planned to ripen that day, sown later by what its
	window allows -- or left empty this time."""
	if day.over == 0:
		return ""
	var days_now: PackedInt32Array = sow_days()
	for k: int in range(day.beds.size() - 1, -1, -1):
		var bed: int = day.beds[k]
		if days_now[bed] == NO_DAY:
			continue
		var later: int = latest_legal_day(bed, days_now[bed], days_now[bed] + ripen_days(_sim.chosen_of(bed)))
		if later > days_now[bed]:
			return "Sow Bed %d on %s instead (%d days later; its window allows it), or leave it empty this time" % [
				bed + 1, day_text(later), later - days_now[bed]]
		return "Leave Bed %d empty this time (its window allows no later sowing)" % (bed + 1)
	return "The crops standing ripen together: harvest them as they come, or make room (Pantry, K)"


func over_words(day: Day) -> String:
	"""A day's overloads in words ('' for none)."""
	var parts := PackedStringArray()
	if day.over & OVER_WORK:
		parts.append("more work than the field crew's day")
	if day.over & OVER_ROOM:
		parts.append("more than the stores' free room (%s)" % Rows.units(room_milli()))
	if day.over & OVER_KEEPING:
		parts.append("about %s would spoil before the kitchen eats it" % Rows.units(day.at_risk_milli))
	return "; ".join(parts)


func day_text(day_number: int) -> String:
	"""An absolute day as the HUD names it: 'Spring 9'."""
	return CalendarScript.day_text(Plans.season_of_day(day_number), Plans.season_day_of(day_number))


# --- booking ---------------------------------------------------------------------------------------------------------

func book() -> String:
	"""Book the plan as one farm order (see BOOKING). Returns what was ordered and booked."""
	var days_now: PackedInt32Array = sow_days()
	var now_beds := PackedInt32Array()
	var later := PackedStringArray()
	for bed: int in Catalog.BED_COUNT:
		if days_now[bed] == NO_DAY:
			continue
		booked_day[bed] = days_now[bed]
		booked_item[bed] = _sim.chosen_of(bed)
		_warned[bed] = 0
		if days_now[bed] <= today():
			now_beds.append(bed)
		else:
			later.append("Bed %d on %s" % [bed + 1, day_text(days_now[bed])])
	revision += 1
	if now_beds.is_empty() and later.is_empty():
		return "Nothing to book: choose crops for the empty beds (Plant…)"
	run_hour()
	return "Booked: %s%s" % ["sowing now on %s" % _beds_list(now_beds) if not now_beds.is_empty() else "",
		("; " if not now_beds.is_empty() and not later.is_empty() else "") + ", ".join(later)]


func run_hour() -> void:
	"""Once a farm hour: each booking whose day has come is ordered when the bed can be sown (see BOOKING)."""
	if _sim == null:
		return
	for bed: int in Catalog.BED_COUNT:
		if booked_day[bed] != NO_DAY and booked_day[bed] <= today():
			_due(bed)


func _due(bed: int) -> void:
	"""A booking whose day has come: dropped (taken up, sown, or its crop changed), ordered, or waiting -- for its
	window, or because the order was refused (a full board) -- warned once; it is cleared only once its job is on the
	board."""
	var item: int = booked_item[bed]
	var dropped: String = _drop_reason(bed, item)
	if not dropped.is_empty():
		_say_once(bed, "Bed %d's booked sowing is dropped: %s" % [bed + 1, dropped])
		_clear_booking(bed)
		return
	var why: String = Text.pick_reason(_sim, bed, item)
	if why.is_empty():
		why = _crew.order(JobsScript.KIND_SOW, bed, _none, JobsScript.ORIGIN_ROUTINE)
		if _crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, bed, _read):
			_clear_booking(bed)
			return
	_say_once(bed, "Bed %d's booked %s waits: %s" % [bed + 1, Catalog.ITEM_LABELS[item].to_lower(), why])


func _drop_reason(bed: int, item: int) -> String:
	"""Why a due booking is dropped ('' when it is not): the bed taken up, sown, or its crop changed."""
	var stage: int = _sim.stage_of(bed)
	if stage == SimScript.STAGE_SITE:
		return "the bed was taken up"
	if stage != SimScript.STAGE_EMPTY:
		return "it is sown"
	return "its crop was changed" if _sim.chosen_of(bed) != item else ""


func _clear_booking(bed: int) -> void:
	"""Forget a bed's booking."""
	booked_day[bed] = NO_DAY
	booked_item[bed] = Catalog.NO_ITEM
	_warned[bed] = 0
	revision += 1


func _say_once(bed: int, text: String) -> void:
	"""A booking's news, said once while it stands."""
	if _warned[bed] == 1:
		return
	_warned[bed] = 1
	if _notice.is_valid():
		_notice.call(text)


func is_booked(bed: int) -> bool:
	"""Whether a bed's sowing is booked (the tending policy leaves it to the booking)."""
	return Catalog.is_bed(bed) and booked_day[bed] != NO_DAY


func booking_text(bed: int) -> String:
	"""'booked: lettuce on Summer 7' ('' for none)."""
	if booked_day[bed] == NO_DAY:
		return ""
	return "booked: %s on %s" % [Catalog.ITEM_LABELS[booked_item[bed]].to_lower(), day_text(booked_day[bed])]


static func _beds_list(beds: PackedInt32Array) -> String:
	"""'Bed 2, Bed 7'."""
	var names := PackedStringArray()
	for bed: int in beds:
		names.append("Bed %d" % (bed + 1))
	return ", ".join(names)


static func role_words(item: int) -> String:
	"""A crop's name with its role (farm_crop_roles.gd): 'Lettuce (fresh greens)'."""
	return "%s (%s)" % [Catalog.ITEM_LABELS[item], Roles.role_name(item).to_lower()]
