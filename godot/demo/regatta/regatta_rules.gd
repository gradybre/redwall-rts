extends RefCounted
## THE REGATTA's numbers (decision 0438; review SOC-023, SOC-025, UX-028; water part B lane 3). Every value is the GDD's
## or a named DEMO value; pure constants and static functions, so the suite checks them without a scene.
##
## THE OCCASION (SOC-023, SOC-025). Once a season -- the first in the first summer (Brendan's approval of "the regatta
## feast", group K) -- the village holds a regatta on the pond: the player picks its day (the season's days from
## tomorrow, or the coming summer's before the first) and its host, sees the feast's preview, and holds it, or skips the
## season with no penalty and nothing withheld (no exclusive item, nothing granted that skipping loses). Held or skipped,
## the season is done: no second regatta, no reroll of the day (anti-farming).
##
## THE RACE (presentation of a deterministic result). The boathouse's two rowboats race: each rows out its own lane to
## its mark and back to its berth (equal lanes, LANE_U each way); its crew a helm (FISH >= 1, the boat core's rule) and a
## second. Each boat rows at `pace_permille(helm FISH, second FISH)` of the boat core's speed (DEMO: +PACE_PER_LEVEL a
## level of the crew's fishing), so the better-skilled crew wins, the same every time; equal paces are a dead heat. No
## wager, no prize: the winners are honoured in the chronicle and their own history.
##
## THE FEAST (GDD §5.7's feast rules, as written; Brendan did not change them). The regatta's feast is the GDD's HEARTH
## theme -- the earliest -- for E, every living resident: main course ceil(E/3) batches of bean_hotpot, second course
## ceil(E/3) of nut_loaf, warm infusion water ceil(E/4) U + herb 0.25 x ceil(E/12) U; staffing 2 cooks + 1 keeper;
## seats >= ceil(E/3); service wood ceil(E/12) U reserved at confirmation; at most one feast in any 72 game hours;
## REQ-SET-101's 3 food-days and 3 fuel-days after it, or the player's explicit override; REQ-SET-104's settlement buff
## only when 80% of E attend ALL required courses. The demo village has NO NUTS AND NO HERB (no source of either: the
## content groups that add them are queued), so the second course and the infusion cannot be made: the preview says so,
## the feast serves the main course it can, and no settlement buff is granted (REQ-SET-104's "otherwise": the attendees'
## meal and its social benefits only). That reading -- confirm a feast whose missing courses are declared, rather than
## refuse it outright under REQ-SET-099 -- is decision 0438's, recorded for Brendan's ruling.
##
## THE DAY. Crews are called at CREW_CALL_HOUR, the race starts at RACE_HOUR once both boats are crewed (called off at
## RACE_GIVE_UP_HOUR if not: the feast still is), and the feast is the day's supper (the kitchen's 17:00 call, decision
## 0421: the GDD's 18:00 start would run its waves into the demo's 20:00 night). Its tally is taken at the supper's end.

const SimClock := preload("res://scripts/core/sim_clock.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

## The first regatta's season (summer) and year; seasons are counted absolutely (year x 4 + season).
const FIRST_SEASON: int = 1
const SEASONS_PER_YEAR: int = 4
## The day (DEMO): crews called, the start, the latest start, and the feast (the kitchen's supper).
const CREW_CALL_HOUR: int = 13
const RACE_HOUR: int = 15
const RACE_GIVE_UP_HOUR: int = 16
const FEAST_MEAL: int = MealRules.MEAL_SUPPER
## The race's lanes (DEMO): each boat straight out from its berth along +x for LANE_U and back (equal: whole u).
const LANE_U: int = 6144                 # 6.0 m
const LANE_DIRECTION: Vector2i = Vector2i(1, 0)
## Pace (DEMO): +PACE_PER_LEVEL per mille of the boat core's speed for each level of the crew's fishing.
const PACE_PER_LEVEL: int = 40
## The GDD's Hearth feast (§5.7, the table and its rules), as written.
const THEME_NAME: String = "Hearth"
const BUFF_NAME: String = "Shared Warmth"
const MAIN_PER: int = 3                  # ceil(E/3) bean_hotpot
const SECOND_PER: int = 3                # ceil(E/3) nut_loaf
const INFUSION_WATER_PER: int = 4        # water ceil(E/4) U
const INFUSION_HERB_MILLI: int = 250     # herb 0.25 x ceil(E/12) U
const INFUSION_HERB_PER: int = 12
const SEATS_PER: int = 3                 # seats >= ceil(E/3)
const WOOD_PER: int = 12                 # service wood ceil(E/12) U
const COOKS: int = 2
const KEEPERS: int = 1
const COOK_SKILL: int = 2
const COVERAGE_PERMILLE: int = 800       # REQ-SET-104: 80% of E attend all required courses
const RESERVE_DAYS: int = 3              # REQ-SET-101: 3 food-days and 3 fuel-days
const FEAST_INTERVAL_HOURS: int = 72     # at most one feast in any 72 game hours
const FEAST_GAIN: int = 5                # REQ-SET-036: two residents sharing a feast, +5 affinity
## The second course (nut_loaf: flour 2, nuts 2, water 1) and the infusion's herb need what the demo has none of.
const SECOND_COURSE: String = "nut loaf"
const SECOND_MISSING: String = "nuts"
const INFUSION_MISSING: String = "herb"
const MILLI_PER_U: int = 1000


static func ceil_div(a: int, b: int) -> int:
	"""ceil(a / b) for a >= 0, b > 0, in integers."""
	@warning_ignore("integer_division") var q: int = (a + b - 1) / b
	return q


static func main_batches(eligible: int) -> int:
	"""The main course's bean_hotpot batches: ceil(E/3)."""
	return ceil_div(eligible, MAIN_PER)


static func second_batches(eligible: int) -> int:
	"""The second course's nut_loaf batches: ceil(E/3)."""
	return ceil_div(eligible, SECOND_PER)


static func seats_needed(eligible: int) -> int:
	"""Seats the feast needs: ceil(E/3)."""
	return ceil_div(eligible, SEATS_PER)


static func service_wood_milli(eligible: int) -> int:
	"""Service wood, reserved at confirmation: ceil(E/12) U."""
	return ceil_div(eligible, WOOD_PER) * MILLI_PER_U


static func infusion_water_milli(eligible: int) -> int:
	"""The warm infusion's water: ceil(E/4) U."""
	return ceil_div(eligible, INFUSION_WATER_PER) * MILLI_PER_U


static func infusion_herb_milli(eligible: int) -> int:
	"""The warm infusion's herb: 0.25 x ceil(E/12) U."""
	return INFUSION_HERB_MILLI * ceil_div(eligible, INFUSION_HERB_PER)


static func covered(attended_all: int, eligible: int) -> bool:
	"""REQ-SET-104: whether at least 80% of E attended every required course."""
	return eligible > 0 and attended_all * 1000 >= COVERAGE_PERMILLE * eligible


static func pace_permille(helm_level: int, second_level: int) -> int:
	"""A race boat's pace, per mille of the boat core's speed (see THE RACE)."""
	return FleetScript.PACE_NORMAL + PACE_PER_LEVEL * (helm_level + second_level)


static func lane(boat: int) -> PackedInt32Array:
	"""Boat `boat`'s race lane: its berth, and its mark LANE_U along LANE_DIRECTION (x, z pairs, u)."""
	var berth: Vector2i = Routes.BERTH_U[boat]
	var mark: Vector2i = berth + LANE_DIRECTION * LANE_U
	return PackedInt32Array([berth.x, berth.y, mark.x, mark.y])


static func mark_m(boat: int) -> Vector2:
	"""Where boat `boat`'s turning mark floats, metres."""
	var course: PackedInt32Array = lane(boat)
	return Routes.m_of(Vector2i(course[2], course[3]))


static func season_of_day(absolute_day: int) -> int:
	"""The absolute season (year x 4 + season) an absolute day is in."""
	@warning_ignore("integer_division") var season: int = absolute_day / SimClock.DAYS_PER_SEASON
	return season


static func first_day_of_season(season: int) -> int:
	"""The absolute day an absolute season begins on."""
	return season * SimClock.DAYS_PER_SEASON


static func race_tick(absolute_day: int, hour: int) -> int:
	"""The calendar tick of `hour` on a day counted from the first spring morning as 0 (the offset calendar: day 0
	begins at tick -4500, its 06:00 is tick 0)."""
	return (absolute_day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


static func feast_key(absolute_day: int) -> int:
	"""The kitchen's meal key of the feast: that day's supper."""
	return MealRules.meal_key(absolute_day, FEAST_MEAL)
