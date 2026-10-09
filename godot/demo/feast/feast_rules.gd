extends RefCounted
## THE CALLED FEASTS' NUMBERS (decision 1701; feature #9, review SOC-023). GDD §5.7's three feast themes and its feast
## rules (REQ-SET-100..106), as written -- pure constants and static functions, so the suite checks them without a
## scene. The numbers every feast shares with the regatta's Hearth feast (seats, wood, staffing, coverage, the infusion)
## are regatta_rules.gd's, read from there, never retyped.
##
## THE THEMES (§5.7's table; SET-AMEND-001 §4.2 for the Orchard main course):
##   Hearth   M1  ceil(E/3) bean_hotpot      ceil(E/3) nut_loaf          warm infusion: water ceil(E/4) U + herb
##                                                                        0.25 x ceil(E/12) U
##            Shared Warmth: cold-exposure accumulation -25% and mood +400 for 48 h
##   Harvest  M2  ceil(E/6) feast_fish       ceil(E/3) berry_tart        mead ceil(E/4) U
##            Abundant Tables: purpose restoration +20% and work speed +5% for 48 h
##   Orchard  M3  ceil(E/4) nut_roast        ceil(E/3) orchard_crumble   mead ceil(E/4) U
##            Rooted Community: social decay -20% for 48 h; immigration candidates +2 at the next event within 72 h
## The demo runs no milestones, so a theme's unlock is not evaluated (as the recipe book's: dish_book.gd); a theme is
## cooked when its ingredients exist and says what it needs otherwise (the packet's acceptance).
##
## THE HOUR (Brendan's ruling on Q-D11, 2026-10-07: "All at 17:00 supper"): every feast, called or regatta, is served
## at the kitchen's 17:00 supper (meal_rules.gd MEAL_SUPPER); REQ-SET-103 is amended to 17:00 by DEC-058 (it read
## 18:00). Its waves are the supper's (17:00-18:59): seats >= ceil(E/3) lets up to three seatings share the
## hall's seats, the kitchen seating each guest as a seat frees.
##
## THE DAY (PROVISIONAL, decision 1701): a feast is called for one of the next DAY_CHOICES suppers the kitchen can still
## cook for -- today's before its supper's cooking starts (meal_rules.gd COOK_FROM_HOUR, 15:00), else tomorrow's on.
## THE INTERVAL (§5.7): at most one feast may start in any 72 game hours, the regatta's included; and at most one feast
## is scheduled or active at once (§3's Feast row) -- so a called feast and a held regatta never share the kitchen.

const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const HEARTH: int = 0
const HARVEST: int = 1
const ORCHARD: int = 2
const THEME_COUNT: int = 3
const THEME_NAMES: Array[String] = ["Hearth", "Harvest", "Orchard"]
## §5.7's unlock column, said beside the theme (not evaluated: the demo runs no milestones).
const THEME_UNLOCKS: Array[String] = ["M1", "M2", "M3"]
## Each theme's courses: the recipe book's keys (dish_book.gd) and E per batch.
const MAIN_KEYS: Array[StringName] = [&"bean_hotpot", &"feast_fish", &"nut_roast"]
const MAIN_PER: PackedInt32Array = [3, 6, 4]
const SECOND_KEYS: Array[StringName] = [&"nut_loaf", &"berry_tart", &"orchard_crumble"]
const SECOND_PER: PackedInt32Array = [3, 3, 3]
## The beverage: the Hearth's warm infusion (regatta_rules.gd's numbers), or mead ceil(E/MEAD_PER) U.
const BEV_INFUSION: int = 0
const BEV_MEAD: int = 1
const BEVERAGE: PackedInt32Array = [BEV_INFUSION, BEV_MEAD, BEV_MEAD]
const MEAD_PER: int = 4
## The settlement buffs (§5.7's last column), each for BUFF_HOURS.
const BUFF_NAMES: Array[String] = ["Shared Warmth", "Abundant Tables", "Rooted Community"]
const BUFF_WORDS: Array[String] = ["cold exposure −25% and mood +400", "purpose +20% and work +5%",
	"social decay −20%; +2 newcomers at the next arrivals within 72 h"]
const BUFF_HOURS: int = 48
## Shared Warmth's cold-exposure gain (cold_exposure.gd `gain_permille`) and Abundant Tables' work factor
## (work_pace.gd `add_factor`), per mille.
const WARMTH_COLD_PERMILLE: int = RegattaRules.BUFF_COLD_PERMILLE
const TABLES_WORK_PERMILLE: int = 1050
const FULL_PERMILLE: int = 1000
## THE HOUR and THE DAY.
const FEAST_MEAL: int = MealRules.MEAL_SUPPER
const FEAST_HOUR: int = MealRules.CALL_HOUR[MealRules.MEAL_SUPPER]
const DAY_CHOICES: int = 3
## THE INTERVAL, and REQ-SET-101's reserves (regatta_rules.gd's, the GDD's).
const INTERVAL_HOURS: int = RegattaRules.FEAST_INTERVAL_HOURS
const RESERVE_DAYS: int = RegattaRules.RESERVE_DAYS
## A seating's length (REQ-SET-103: "up to three one-hour waves").
const MAX_WAVES: int = 3


static func dish_of(key: StringName) -> int:
	"""The recipe book's row for `key` (MealRules.NO_DISH: none)."""
	var dish: int = MealRules.DISH_KEYS.find(key)
	return dish if dish >= 0 else MealRules.NO_DISH


static func valid_theme(theme: int) -> bool:
	"""Whether `theme` is one of §5.7's three."""
	return theme >= 0 and theme < THEME_COUNT


static func main_dish(theme: int) -> int:
	"""The theme's main course (the book's row)."""
	return dish_of(MAIN_KEYS[theme])


static func second_dish(theme: int) -> int:
	"""The theme's second course (the book's row)."""
	return dish_of(SECOND_KEYS[theme])


static func main_batches(theme: int, eligible: int) -> int:
	"""The main course's batches: ceil(E/3) hotpot, ceil(E/6) feast fish or ceil(E/4) nut roast."""
	return RegattaRules.ceil_div(maxi(eligible, 0), MAIN_PER[theme])


static func second_batches(theme: int, eligible: int) -> int:
	"""The second course's batches: ceil(E/3) of every theme's."""
	return RegattaRules.ceil_div(maxi(eligible, 0), SECOND_PER[theme])


static func mead_milli(eligible: int) -> int:
	"""Mead for the Harvest and Orchard feasts: ceil(E/4) U."""
	return RegattaRules.ceil_div(maxi(eligible, 0), MEAD_PER) * RegattaRules.MILLI_PER_U


static func waves(eligible: int, seats: int) -> int:
	"""How many seatings the hall's `seats` take to sit E (at most MAX_WAVES; 0 with nobody or no seat)."""
	if eligible <= 0 or seats <= 0:
		return 0
	return mini(RegattaRules.ceil_div(eligible, seats), MAX_WAVES)


static func start_tick(day: int) -> int:
	"""The calendar tick a feast on absolute `day` starts: that day's supper call (THE HOUR)."""
	return RegattaRules.race_tick(day, MealRules.CALL_HOUR[FEAST_MEAL])


static func feast_key(day: int) -> int:
	"""The kitchen's meal key of a feast on `day`: its supper."""
	return MealRules.meal_key(day, FEAST_MEAL)


static func too_close(a_tick: int, b_tick: int) -> bool:
	"""THE INTERVAL: whether two feasts starting at these ticks fall within 72 game hours of each other."""
	return absi(a_tick - b_tick) < INTERVAL_HOURS * SimClock.TICKS_PER_HOUR


static func first_day(today: int, hour: int) -> int:
	"""THE DAY: the first day a feast may be called for -- today before its supper's cooking starts, else tomorrow."""
	return today if hour < MealRules.COOK_FROM_HOUR[FEAST_MEAL] else today + 1


static func covered(attended_all: int, eligible: int) -> bool:
	"""REQ-SET-104: at least 80% of E attended every required course."""
	return RegattaRules.covered(attended_all, eligible)


static func buff_until(granted_at: int) -> int:
	"""The tick a buff granted at `granted_at` lasts until (48 game hours)."""
	return granted_at + BUFF_HOURS * SimClock.TICKS_PER_HOUR
