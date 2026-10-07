extends RefCounted
## THE WINTER'S RULES: heating fuel, room warmth and cold exposure, as integers. Decision 0571 (Brendan's rulings of
## 2026-10-01 on the winter fuel and warmth loop). Pure and static: hearth_fuel.gd, cold_exposure.gd and the words
## (winter_text.gd) read these; nothing here holds state. Presentation only: the settlement simulation is not written.
##
## FUEL IS THE WOOD ITEM (docs/gameplay_balance.md: wood, 5000 g a unit), counted in the village stores' milli-U.
##
## BURN RATES (docs/game_gdd.md §5.8, "Fuel-days"): "One wood U heats one hearth for 6 game hours", so a hearth burns
## HOURS_PER_DAY / HEARTH_HOURS_PER_U = 4 U a day in WINTER; in spring or autumn 2 U a day on a day whose mean is below
## SHOULDER_BELOW_TENTHS (10 °C); in summer nothing. A tier 2 residence or hall multiplies its fuel by
## TIER2_FUEL_PERMILLE (§5.9, REQ-SET-136: "heat fuel x0.75"): each hearth carries its building's tier
## (hearth_fuel.gd `tier`) and burns `day_demand_milli(season, mean, tier_fuel_permille(tier))`. The demo's homes are
## all tier 1; the hall is tier 2 once raised to the great hall (decision 1652). The kitchen's 0.1 U a batch
## (meal_rules.gd WOOD_MILLI_PER_BATCH) is the kitchen's own draw.
##
## FUEL-DAYS (§5.8): available wood over the daily heating demand plus the last three days' mean cooking use; with no
## heating demand, "No current heat demand" -- NO_DEMAND, never a division by zero (§5.10's failure table).
##
## ROOMS (REQ-SET-130/131): a heated room holds HEATED_TENTHS (18 °C) at tier 1, HEATED_TIER2_TENTHS (20 °C) at tier 2. A hearth out of fuel lets its room
## converge HALFWAY toward the outside air each game hour.
##
## EXPOSURE (REQ-SET-018/019, §5.2): outdoors, or in an unheated room, below 0 °C at clothing tier 1, a resident gains
## needs.gd's COLD_GAIN_TIER1 (1000 milli-hours an hour), its HARD_FREEZE figure (2000) in a hard freeze; a heated room
## clears COLD_CLEAR_SHELTER (2000 an hour). The constants are needs.gd's own, read here, never retyped.
##
## CHILLED (Brendan's ruling 1, in place of REQ-SET-018's health loss): at needs.gd's COLD_DAMAGE_HOURS (4) exposure-hours
## or more a resident is CHILLED -- it works at CHILLED_WORK_PERMILLE, §5.10's storm "outdoor work x0.80" borrowed as the
## ruling says, and takes a warm-up break at a heated hearth -- until it is warmed through (exposure 0). No health is
## lost and nobody dies of cold. Exposure is capped at COLD_CAP_MILLI (twice the Chilled line, a demo value: without the
## GDD's health loss an uncapped count would keep a resident chilled for days after the fire is lit again).

const Needs := preload("res://scripts/core/needs.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const MILLI: int = 1000
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY
## §5.8: one wood U heats one hearth for 6 game hours.
const HEARTH_HOURS_PER_U: int = 6
## A hearth's winter day: 24 h / 6 h a unit = 4 U.
@warning_ignore("integer_division")
const WINTER_DAY_MILLI: int = MILLI * HOURS_PER_DAY / HEARTH_HOURS_PER_U
## Spring or autumn on a cold day: 2 U.
@warning_ignore("integer_division")
const SHOULDER_DAY_MILLI: int = WINTER_DAY_MILLI / 2
## §5.8: "spring/autumn consume 2/day when daily mean<10°C".
const SHOULDER_BELOW_TENTHS: int = 100
## §5.9's tier 2 package: "heat fuel x0.75". Tier 1 burns at FULL_PERMILLE.
const TIER2_FUEL_PERMILLE: int = 750
const FULL_PERMILLE: int = 1000
## REQ-SET-130: a heated room at tier 1 holds 18 °C ...
const HEATED_TENTHS: int = 180
## ... and at tier 2, 20 °C.
const HEATED_TIER2_TENTHS: int = 200
## A building's tier (GDD §5.9: tier 1, and the one tier-2 upgrade; tier 3 is absent).
const TIER_1: int = 1
const TIER_2: int = 2
## The freezing line exposure is measured against (REQ-SET-018: "below 0°C").
const FREEZING_TENTHS: int = 0
## REQ-SET-147 and UI §7: the fuel warning under 2 fuel-days while the forecast is below 0 °C (hundredths of a day).
const WARN_FUEL_HUNDREDTHS: int = 200
## §5.8: the forecast's cooking use is "this last-three-days mean".
const COOK_MEAN_DAYS: int = 3
## REQ-SET-114 and Brendan's ruling 6: the twelve-day winter projection.
const PROJECTION_DAYS: int = SimClock.DAYS_PER_SEASON
## Fuel-days with no heating demand (see FUEL-DAYS).
const NO_DEMAND: int = -1
## A tick count is integrated over an hour of this many ticks.
const TICKS_PER_HOUR: int = SimClock.TICKS_PER_HOUR

## Clothing tier 1 for everyone (Brendan's ruling 3).
const CLOTHING_TIER: int = Needs.CLOTHING_TIER_MIN
const GAIN_MILLI_PER_HOUR: int = Needs.COLD_GAIN_TIER1_MILLI_PER_HOUR
const GAIN_HARD_FREEZE_MILLI_PER_HOUR: int = Needs.COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR
const CLEAR_MILLI_PER_HOUR: int = Needs.COLD_CLEAR_SHELTER_MILLI_PER_HOUR
## Ruling 1: Chilled at 4 exposure-hours or more (REQ-SET-018's own line).
const CHILLED_AT_MILLI: int = Needs.COLD_DAMAGE_HOURS * MILLI
## A demo value (see CHILLED): at most twice the Chilled line, so a warm-up never takes more than 4 game hours.
const COLD_CAP_MILLI: int = 2 * CHILLED_AT_MILLI
## Ruling 1: "works at 80% speed, borrowing the storm factor's magnitude" -- §5.10's heavy rain/storm outdoor work.
const CHILLED_WORK_PERMILLE: int = WeatherScript.EVENT_OUTDOOR_WORK_PER_1000[WeatherScript.EVENT_HEAVY_RAIN]

## Where a resident is, for its exposure (needs.gd COLD_ENV_*: neutral, exposed, heated shelter).
const ENV_NEUTRAL: int = Needs.COLD_ENV_NEUTRAL
const ENV_EXPOSED: int = Needs.COLD_ENV_EXPOSED
const ENV_HEATED: int = Needs.COLD_ENV_HEATED_SHELTER


static func div(a: int, b: int) -> int:
	"""Integer division, truncating (GDScript's own `/` on ints), named so the intent is plain -- the one place the
	analyzer's integer-division warning is waived (a statement-level `@warning_ignore`; a function-level one does not
	reach the body on 4.7.2)."""
	@warning_ignore("integer_division")
	var quotient: int = a / b
	return quotient


static func floor_div(a: int, b: int) -> int:
	"""Integer division rounding toward negative infinity (b > 0): a mean of negative tenths floors, not truncates."""
	var q: int = div(a, b)
	return q - 1 if a % b != 0 and a < 0 else q


static func day_demand_milli(season: int, mean_tenths: int, tier_permille: int = FULL_PERMILLE) -> int:
	"""A hearth's fuel for a day (milli-U; see BURN RATES): winter 4 U, spring or autumn below 10 °C 2 U, else 0."""
	var base: int = 0
	if season == WeatherScript.SEASON_WINTER:
		base = WINTER_DAY_MILLI
	elif (season == WeatherScript.SEASON_SPRING or season == WeatherScript.SEASON_AUTUMN) \
			and mean_tenths < SHOULDER_BELOW_TENTHS:
		base = SHOULDER_DAY_MILLI
	return div(base * tier_permille, FULL_PERMILLE)


static func tier_fuel_permille(tier: int) -> int:
	"""A hearth's fuel per mille of the ordinary for its building's tier (§5.9): x0.75 at tier 2, else x1.00."""
	return TIER2_FUEL_PERMILLE if tier >= TIER_2 else FULL_PERMILLE


static func heated_tenths(tier: int) -> int:
	"""REQ-SET-130: the temperature a heated room holds at its building's tier (18 °C; 20 °C at tier 2)."""
	return HEATED_TIER2_TENTHS if tier >= TIER_2 else HEATED_TENTHS


static func converge_tenths(room_tenths: int, air_tenths: int) -> int:
	"""REQ-SET-131: a room without heat moves halfway toward the outside air in a game hour, the odd tenth taken toward
	the air, so it reaches it (review L3)."""
	var gap: int = air_tenths - room_tenths
	return room_tenths + (gap - div(gap, 2))


static func gain_milli_per_hour(hard_freeze: bool) -> int:
	"""Exposure gained an hour in the cold at clothing tier 1 (see EXPOSURE)."""
	return GAIN_HARD_FREEZE_MILLI_PER_HOUR if hard_freeze else GAIN_MILLI_PER_HOUR


static func exposure_rate(env: int, hard_freeze: bool) -> int:
	"""Milli-hours an hour for an environment (ENV_*): + gain exposed, - clearing heated, 0 neutral."""
	if env == ENV_EXPOSED:
		return gain_milli_per_hour(hard_freeze)
	if env == ENV_HEATED:
		return -CLEAR_MILLI_PER_HOUR
	return 0


static func env_for(heated: bool, room_tenths: int) -> int:
	"""A resident's environment in a place: heated (clears), below freezing (exposed), else neutral."""
	if heated:
		return ENV_HEATED
	return ENV_EXPOSED if room_tenths < FREEZING_TENTHS else ENV_NEUTRAL


static func fuel_days_hundredths(wood_milli: int, heating_day_milli: int, cook_mean_milli: int) -> int:
	"""§5.8's fuel-days in hundredths (floored), or NO_DEMAND with no heating demand."""
	if heating_day_milli <= 0:
		return NO_DEMAND
	return div(100 * maxi(wood_milli, 0), heating_day_milli + maxi(cook_mean_milli, 0))


static func hours_of_fuel(wood_milli: int, heating_day_milli: int, cook_mean_milli: int) -> int:
	"""Whole game hours the wood lasts at today's demand (0 with no demand): the last heated hour's distance."""
	if heating_day_milli <= 0:
		return 0
	return div(HOURS_PER_DAY * maxi(wood_milli, 0), heating_day_milli + maxi(cook_mean_milli, 0))


static func projection_milli(hearths: int, cook_mean_milli: int) -> int:
	"""REQ-SET-114 / ruling 6: twelve winter days of projected demand -- every hearth at 4 U, plus the cooking mean."""
	return projection_of_milli(maxi(hearths, 0) * WINTER_DAY_MILLI, cook_mean_milli)


static func projection_of_milli(winter_day_milli: int, cook_mean_milli: int) -> int:
	"""The same twelve winter days over a WINTER day's heating demand already summed hearth by hearth (each at its tier's
	rate, decision 1652), plus the cooking mean."""
	return PROJECTION_DAYS * (maxi(winter_day_milli, 0) + maxi(cook_mean_milli, 0))


static func permille_of(have: int, want: int) -> int:
	"""How much of `want` `have` is, per mille, capped at 1000 (1000 when nothing is wanted)."""
	if want <= 0:
		return FULL_PERMILLE
	return mini(div(FULL_PERMILLE * maxi(have, 0), want), FULL_PERMILLE)


static func is_hard_freeze(event: int) -> bool:
	"""Whether a day's event is §5.10's hard freeze (exposure x2)."""
	return event == WeatherScript.EVENT_HARD_FREEZE


static func hour_season(hour_index: int) -> int:
	"""The season of a calendar hour index (demo_calendar.gd `hour_index_at`)."""
	return div(div(hour_index, HOURS_PER_DAY) % (SimClock.DAYS_PER_SEASON * SimClock.SEASONS_PER_YEAR),
		SimClock.DAYS_PER_SEASON)


static func hour_season_day(hour_index: int) -> int:
	"""The season-local day (1..12) of a calendar hour index."""
	return div(hour_index, HOURS_PER_DAY) % SimClock.DAYS_PER_SEASON + 1


static func hour_absolute_season(hour_index: int) -> int:
	"""The absolute season (0 = the first spring) of a calendar hour index."""
	return div(div(hour_index, HOURS_PER_DAY), SimClock.DAYS_PER_SEASON)


static func hour_of_day(hour_index: int) -> int:
	"""The hour of the day (0..23) of a calendar hour index."""
	return hour_index % HOURS_PER_DAY


static func day_of_hour(hour_index: int) -> int:
	"""The day count (0 = spring 1 of year 1) of a calendar hour index."""
	return div(hour_index, HOURS_PER_DAY)


static func next_season_start_hour(hour_index: int, at_hour: int) -> int:
	"""The hour index of `at_hour` on day 1 of the season after the one `hour_index` is in."""
	var next_day: int = (hour_absolute_season(hour_index) + 1) * SimClock.DAYS_PER_SEASON
	return next_day * HOURS_PER_DAY + at_hour


static func kitchen_batch_milli() -> int:
	"""The kitchen's wood a batch (meal_rules.gd): 0.1 U."""
	return MealRules.WOOD_MILLI_PER_BATCH
