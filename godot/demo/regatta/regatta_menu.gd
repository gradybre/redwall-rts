extends RefCounted
## THE HEARTH FEAST'S FULL MENU (decision 0682; Brendan's ruling of 2026-10-01: "add nuts & herbs now"): the regatta
## feast's SECOND COURSE and WARM INFUSION, and the SHARED WARMTH they earn -- GDD §5.7's Hearth row as written.
## Owned by the regatta (regatta.gd), which keeps the main course; numbers in regatta_rules.gd and meal_rules.gd.
##
## THE SECOND COURSE: ceil(E/3) batches of `nut_loaf` (flour 2, nuts 2, water 1 -> 3 x 2600 NP, 24 WU, 72 h). At
## confirmation, when the pantry holds every batch's flour and nuts free, both are RESERVED in the regatta's own take
## beside the main course's beans and cabbage, and the kitchen cooks the loaves once the hotpot is done (kitchen.gd AN
## OCCASION's second course); each guest eats one portion of each course (§5.7).
## THE WARM INFUSION: water ceil(E/4) U + herb 0.25 x ceil(E/12) U, "prepared during service from its reserved
## water/herb; it has no stored output item or extra work". At confirmation, when both are there, the herb is reserved
## in a take of its own and the water set aside from the butt (as the service wood is); at the supper's end they are
## consumed "proportionally to attended/E with milli-unit rounding at the last attendee" -- floor(total x attended / E),
## the rest given back.
## A COURSE THE PANTRY CANNOT MAKE is declared in the preview with its exact shortfall and the way to fix it (REQ-SET-099:
## "display that specific blocking reason and the missing quantity"); the feast is still held with what it can serve and
## then grants no buff (REQ-SET-104's "otherwise": decision 0438's reading, kept for that case).
## SHARED WARMTH (REQ-SET-104/105): granted at the supper's end when the second course and the infusion were both served
## and at least 80% of E ate every course; "cold-exposure accumulation -25% and mood +400 for 48 h", applied once -- a
## second Hearth feast while it lasts neither stacks nor extends it. The demo models no mood and no cold exposure
## (meal_rules.gd: "the demo models no mood"), so the buff is a settlement state its readers can use (`cold_exposure_
## permille`, `mood_bonus`) and the village news and the Regatta section show; nothing in the demo consumes it yet.

const Rules := preload("res://demo/regatta/regatta_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const NUT_LOAF: int = MealRules.DISH_NUT_LOAF

var kitchen: KitchenScript = null
var stores: StoresScript = null
## What the held plan serves besides the main course.
var second_planned: bool = false
var infusion_planned: bool = false
## The infusion's herb (its own take) and water (set aside), and what the service used of them.
var herb_take: int = 0
var water_held_milli: int = 0
var herb_used_milli: int = 0
var water_used_milli: int = 0
## Shared Warmth: the calendar tick it lasts until (-1: never granted), and how many were granted.
var warmth_until: int = -1
var warmth_granted: int = 0

var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(p_kitchen: KitchenScript, p_stores: StoresScript) -> void:
	"""The kitchen (its pantry and takes) and the stores (the butt's water) the menu draws on."""
	kitchen = p_kitchen
	stores = p_stores


func _free(category: int) -> int:
	"""Category `category`'s food in the pantry nobody has set aside, milli-U."""
	return kitchen.takes.free_milli_of_crop(kitchen.pantry, category) if kitchen != null else 0


func free_flour() -> int:
	"""Flour nobody has set aside."""
	return _free(Catalog.CAT_FLOUR)


func free_nuts() -> int:
	"""Nuts nobody has set aside."""
	return _free(Catalog.CAT_NUTS)


func free_herb() -> int:
	"""Herb nobody has set aside."""
	return _free(Catalog.CAT_HERB)


static func second_need_milli(eligible: int) -> int:
	"""Flour (and, the same, nuts) the second course takes: ceil(E/3) batches of nut_loaf."""
	return Rules.second_batches(eligible) * MealRules.INPUT_MILLI[NUT_LOAF]


func second_short(eligible: int) -> String:
	"""Why the second course can't be made now ("" when it can): the exact shortfall and its fix."""
	var need: int = second_need_milli(eligible)
	if free_nuts() < need:
		return "short of nuts: %s needed, %s free — a foraging trip (Woods ▸ Foraging)" % [_units(need), _units(free_nuts())]
	if free_flour() < need:
		return "short of flour: %s needed, %s free — Mill grain (Water ▸ Drying rack and mill)" % [_units(need), _units(free_flour())]
	return ""


func infusion_short(eligible: int) -> String:
	"""Why the warm infusion can't be made now ("" when it can): the exact shortfall and its fix."""
	var herb: int = Rules.infusion_herb_milli(eligible)
	if free_herb() < herb:
		return "short of herb: %s needed, %s free — a foraging trip for herbs (Woods ▸ Foraging)" % [_units(herb), _units(free_herb())]
	var water: int = Rules.infusion_water_milli(eligible)
	if stores != null and stores.water_milli_u < water:
		return "short of water: %s needed in the butt, %s there — Draw water (Pantry ▸ Kitchen)" % [_units(water),
			_units(stores.water_milli_u)]
	return ""


func second_batches_now(eligible: int) -> int:
	"""Batches of the second course a plan held now would cook (0 when it can't be made)."""
	return Rules.second_batches(eligible) if second_short(eligible).is_empty() else 0


func preview_lines(eligible: int) -> PackedStringArray:
	"""The preview's second course, infusion and buff lines, from the pantry's real stock."""
	var lines := PackedStringArray()
	var b: int = Rules.second_batches(eligible)
	var second: String = second_short(eligible)
	lines.append("Second: %s x%d (%d portions): flour %s (free %s), nuts %s (free %s), water %s%s" % [Rules.SECOND_COURSE, b,
		b * MealRules.PORTIONS_PER_BATCH[NUT_LOAF], _units(second_need_milli(eligible)), _units(free_flour()),
		_units(second_need_milli(eligible)), _units(free_nuts()), _units(b * MealRules.WATER_MILLI[NUT_LOAF]),
		"" if second.is_empty() else " — can't be made: " + second])
	var infusion: String = infusion_short(eligible)
	lines.append("Warm infusion: water %s, herb %s (free %s)%s" % [_units(Rules.infusion_water_milli(eligible)),
		_units(Rules.infusion_herb_milli(eligible)), _units(free_herb()), "" if infusion.is_empty() else " — can't be made: " + infusion])
	lines.append(buff_words(eligible, second.is_empty() and infusion.is_empty()))
	return lines


static func buff_words(eligible: int, every_course: bool) -> String:
	"""The preview's buff line: what earns Shared Warmth, or why it can't be earned."""
	@warning_ignore("integer_division") var needed: int = (Rules.COVERAGE_PERMILLE * eligible + 999) / 1000
	if every_course:
		return "%s if %d of %d eat every course: cold exposure −25%% and mood +%d for %d h; each guest has the meal and the feast's company (+%d friendship a pair)" % [
			Rules.BUFF_NAME, needed, eligible, Rules.BUFF_MOOD, Rules.BUFF_HOURS, Rules.FEAST_GAIN]
	return "So no %s (80%% must eat every course); each guest has the meal and the feast's company (+%d friendship a pair)" % [
		Rules.BUFF_NAME, Rules.FEAST_GAIN]


# --- holding and giving back ------------------------------------------------------------------------------

func reserve(take: int, eligible: int, hour_index: int) -> void:
	"""At confirmation: the second course's flour and nuts into the regatta's `take` (the kitchen cooks from it), the
	infusion's herb into its own take and its water set aside -- each course only when the pantry can make all of it."""
	release()
	if second_short(eligible).is_empty():
		var need: int = second_need_milli(eligible)
		kitchen.takes.reserve_into(kitchen.pantry, take, Catalog.CAT_FLOUR, need, hour_index, _read)
		kitchen.takes.reserve_into(kitchen.pantry, take, Catalog.CAT_NUTS, need, hour_index, _read)
		second_planned = true
	if infusion_short(eligible).is_empty():
		herb_take = kitchen.takes.new_take()
		kitchen.takes.reserve_into(kitchen.pantry, herb_take, Catalog.CAT_HERB, Rules.infusion_herb_milli(eligible), hour_index, _read)
		water_held_milli = Rules.infusion_water_milli(eligible)
		stores.take_water(water_held_milli)
		infusion_planned = true


func second_dish() -> int:
	"""The occasion's second course for the kitchen (MealRules.NO_DISH: none planned)."""
	return NUT_LOAF if second_planned else MealRules.NO_DISH


func release() -> void:
	"""Give back what the infusion set aside (the second course's food is in the regatta's take, released with it)."""
	if herb_take != 0:
		kitchen.takes.release(herb_take)
	herb_take = 0
	if water_held_milli > 0 and stores != null:
		stores.add_water(water_held_milli)
	water_held_milli = 0
	second_planned = false
	infusion_planned = false


# --- the supper's end ----------------------------------------------------------------------------------------

func settle(eligible: int, attended: int, every_course: int, now_tick: int, hour_index: int) -> String:
	"""The supper is over: the infusion's herb and water used for `attended` of `eligible` (the rest given back), and
	Shared Warmth granted when every course was served and `every_course` reached 80% of E. The chronicle's words."""
	var served_all: bool = second_planned and infusion_planned
	if infusion_planned:
		_pour(eligible, attended, hour_index)
	release()
	if not served_all:
		return "no %s (not every course was served)" % Rules.BUFF_NAME
	if not Rules.covered(every_course, eligible):
		return "no %s (%d of %d ate every course; 80%% are asked)" % [Rules.BUFF_NAME, every_course, eligible]
	if warmth_active(now_tick):
		return "%s already warms the village (not stacked or extended)" % Rules.BUFF_NAME
	warmth_until = now_tick + Rules.BUFF_HOURS * SimClock.TICKS_PER_HOUR
	warmth_granted += 1
	return "%s for %d h" % [Rules.BUFF_NAME, Rules.BUFF_HOURS]


func _pour(eligible: int, attended: int, hour_index: int) -> void:
	"""The infusion consumed proportionally to attended/E (floor: §5.7's rounding at the last attendee)."""
	var guests: int = clampi(attended, 0, eligible)
	@warning_ignore("integer_division") var herb: int = Rules.infusion_herb_milli(eligible) * guests / maxi(eligible, 1)
	@warning_ignore("integer_division") var water: int = water_held_milli * guests / maxi(eligible, 1)
	if herb > 0 and kitchen != null and kitchen.takes.consume_into(kitchen.pantry, herb_take, herb, TakesScript.AT_STORE, hour_index, _read,
			Catalog.CAT_HERB):
		herb_used_milli += herb
	water_used_milli += water
	water_held_milli -= water


func warmth_active(now_tick: int) -> bool:
	"""Whether Shared Warmth lasts at `now_tick`."""
	return warmth_until >= 0 and now_tick < warmth_until


func warmth_hours_left(now_tick: int) -> int:
	"""Whole game hours of Shared Warmth left (0: none)."""
	@warning_ignore("integer_division") var hours: int = maxi(0, warmth_until - now_tick) / SimClock.TICKS_PER_HOUR
	return hours if warmth_active(now_tick) else 0


func cold_exposure_permille(now_tick: int) -> int:
	"""Cold-exposure accumulation, per mille of its rate: 750 while Shared Warmth lasts, else 1000."""
	return Rules.BUFF_COLD_PERMILLE if warmth_active(now_tick) else 1000


func mood_bonus(now_tick: int) -> int:
	"""Shared Warmth's mood, +400 while it lasts (else 0)."""
	return Rules.BUFF_MOOD if warmth_active(now_tick) else 0


static func _units(milli: int) -> String:
	"""'6.0 U'."""
	return ForestRules.units_text(milli)
