extends RefCounted
## THE FIRST MEAL LOOP'S NUMBERS: the two dishes, what they take, how long the work is, what a resident needs, and
## when the village eats. Decision 0381 (review F21, UX-027; Brendan's rulings of 2026-09-30). Presentation only:
## nothing here touches the settlement simulation. Every number is cited; the demo values are named as such.
##
## THE DISHES (ruling 1: two, alternating). Each is a content-library recipe COOKED AS a GDD §5.7 recipe row, with
## the row's numbers exactly (docs/game_gdd.md §5.7; docs/gameplay_balance.md §3.1-3.2):
##   Wild oat porridge (salamandastron::SAL_recipe_wild_oat_porridge) as `porridge`:
##       grain 2 + water 2 -> meal_porridge 2 x 1800 NP, 12 WU, Kitchen/COOK, shelf 24 h
##   Togget's vegetable soup (outcast::OUT_recipe_togget_s_vegetable_soup) as `root_stew`:
##       roots 3 + water 1 -> meal_root_stew 2 x 1800 NP, 16 WU, Kitchen/COOK, shelf 24 h
## and BAL-SUPPLY-004's fuel, 100 milli-U of wood a batch. A portion is 1 U (balance: outputs 2000 milli-U = 2
## portions), 500 g (§5.7: "prepared meal ... units weigh 500 g").
##
## THE CROPS IN EACH CATEGORY. The GDD has one `grain` item and one `roots` item; the demo grows sixteen fine-grained
## crops, each by ONE §5.6 row (farm_catalog.gd ITEM_CROP), which also sets its shelf life. A recipe's category is
## therefore that row: grain = wheat, barley, oats (the §5.6 grain row; §5.7's "Grain/flour"); roots = radish,
## turnip, carrot, beetroot, parsnip, onion (the §5.6 roots row). The porridge's book ingredient is "wild oats" and the
## soup's is only "vegetables" (the library's carrot and turnip are its AI-authored selection), so every crop of the
## category is accepted, as the GDD's category is.
##
## THE NEED (§5.2): hunger 0..10000 falls 250 x size multiplier / 1000 an hour (x1.2 in winter) -- scripts/core/
## family_rules.gd's own table, called, never retyped: 6000 NP a day for a small resident (GDD §2 glossary: "small
## resident requires 6000/day"; §7.1: `(small + 1.2 medium + 1.6 large) x 6000`). A portion adds its NP (PLAIN quality,
## factor 1000), the fullness clamped at 10000 without refund (§5.2). The readable state is §5.2's thresholds: "Eat
## <= 3500; urgent <= 1500" -- above 3500 FED, 1501..3500 PECKISH, 1500 and below HUNGRY. Two meals are 3600 NP, 60% of
## a small resident's 6000: the rest is left for later food work, and the demo applies no penalty (REQ-SET-014's
## health loss and the mood memories are not modelled here).
##
## SIZE CLASS by species (scripts/core/residents.gd SPECIES_*_KEYS: mouse, mole, squirrel small; otter medium; badger
## large). The BEAVER is not in the GDD's sixteen; DEC-041 puts it between the squirrel and the otter "but stockier",
## so it is MEDIUM here -- a demo value.
##
## THE DAY (ruling 4: breakfast and supper; decision 0421's times, now that a game hour is 25 s and walking fits it).
## Night is 20:00-05:59 (night_routine.gd). BREAKFAST is called at 07:00, the GDD's work start (§5.3's default
## schedule: WORK from 07:00), and served until 08:59; SUPPER is called at 17:00 and served until 18:59 -- its end,
## with the raw emergency meals it starts, comes an hour before bedtime, so they are eaten before the night takes
## anyone. The cook is up at COOK_RISE_HOUR (05:00), an hour before the village, to cook breakfast (five batches of
## porridge for nine is 60 WU, a game hour at the step rate, plus the fetch); SUPPER is cooked from 15:00
## (COOK_FROM_HOUR), two hours before its call. Portions keep 24 h in the pot at the covered factor, but out on the
## table they age at the open-pile one (§5.8, 1500) -- times summer's 1500, 10.7 h -- so a breakfast put out as early
## as 06:00 lasts to about 16:40, and a supper put out as early as 16:00 to about 02:40: past their windows in any
## season. These hours are demo values.
##
## THE WORK RATE (§5.2): "Each work tick produces 80 milli-WU x factor/1000"; the demo has no cooking skill, mood or
## health model, so the factor is 1000 (skill 0, PLAIN): 80 milli-WU each calendar tick, 60 WU a game hour. Eating is
## "60 WU/game hour ... a 12-WU eating task" (§5.2, REQ-SET-012); drawing water is "10000 milli-U per 10000 milli-WU"
## (BAL-SUPPLY-004): a WU a unit. Picking food up, putting it down and putting the portions out are 1 WU each, as the
## farm's drop (farm_jobs.gd WORK_DROP) -- demo values.
##
## VARIETY (§5.7): "Meal variety uses last 6 recipe IDs: repeat count 0-1 no penalty; 2-3 applies monotonous memory
## -200; 4-6 applies -400" (6 hours: §5.2's memory catalog). Shown as a readout; the demo models no mood.
##
## RAW EMERGENCY FOOD (REQ-SET-013, WorldPolicy raw_emergency_food default true): with no portion, a resident at
## hunger 1500 or less may eat raw-edible food nobody has reserved, "enough quantity to add at most 3000 NP", in the
## same 12 WU. Raw-edible are the roots row (800 NP/U), the cabbage row (600 NP/U) and dried fish (1800 NP/U, decision
## 0431); grain, beans, flour and fresh fish are not (§5.7:
## "Raw ingredients marked 'No' cannot be consumed even in emergency").

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")

const DISH_PORRIDGE: int = 0
const DISH_SOUP: int = 1
## THE THIRD DISH (water part B, decision 0436): the library's "Requested perch or trout"
## (taggerung::TAG_recipe_requested_perch_or_trout, a poached perch proposal) COOKED AS §5.7's `fish_stew` row exactly:
## "fish 2, roots 2, water 2 | meal_fish_stew 3x2200 | 20 | Kitchen/COOK | 24 | Start". Its fish is §5.7's `fish`
## selector -- the six fresh species the village catches (never dried fish: that is its own item, the reserve) -- and
## its second input is the roots row. It is cooked at SUPPER in place of the soup whenever the stores hold a batch's fresh
## fish and roots nobody has set aside (fresh fish keeps 48 h: it is used while fresh); otherwise the alternation runs as
## ruling 1 has it.
const DISH_FISH_STEW: int = 2
const DISH_COUNT: int = 3
const NO_DISH: int = -1
const DISH_NAMES: Array[String] = ["Wild oat porridge", "Togget's vegetable soup", "Poached perch or trout"]
const DISH_SHORT: Array[String] = ["porridge", "soup", "fish stew"]
const LIBRARY_IDS: Array[String] = ["salamandastron::SAL_recipe_wild_oat_porridge",
	"outcast::OUT_recipe_togget_s_vegetable_soup", "taggerung::TAG_recipe_requested_perch_or_trout"]
## The GDD §5.7 rows they are cooked as.
const GDD_ROWS: Array[String] = ["porridge", "root_stew", "fish_stew"]
## Each dish's food input: its §5.6 crop row (or the pantry's fish category), and how much a batch takes.
const INPUT_CROP: Array[int] = [FarmingScript.CROP_GRAIN, FarmingScript.CROP_ROOTS, Catalog.CAT_FISH]
const INPUT_WORDS: Array[String] = ["grain", "roots", "fresh fish"]
const INPUT_CROPS_TEXT: Array[String] = ["oats, wheat or barley", "carrot, turnip, radish, beetroot, parsnip or onion",
	"trout, dace, salmon, perch, carp or whitefish"]
const INPUT_MILLI: Array[int] = [2000, 3000, 2000]
## A dish's second food input (§5.7's fish_stew: "fish 2, roots 2"): its row and a batch's milli-U; -1: none.
const SIDE_CROP: Array[int] = [-1, -1, FarmingScript.CROP_ROOTS]
const SIDE_WORDS: Array[String] = ["", "", "roots"]
const SIDE_MILLI: Array[int] = [0, 0, 2000]
const WATER_MILLI: Array[int] = [2000, 1000, 2000]
const PORTIONS_PER_BATCH: Array[int] = [2, 2, 3]
const NP_PER_PORTION: Array[int] = [1800, 1800, 2200]
const WORK_MWU: Array[int] = [12000, 16000, 20000]
const SHELF_HOURS: Array[int] = [24, 24, 24]
## BAL-SUPPLY-004: "wood 100 milli-U/batch".
const WOOD_MILLI_PER_BATCH: int = 100
## A portion's mass and spoiled food's (§5.7: 500 g and 250 g a unit): a spoiled portion is twice its milli-U.
const PORTION_G: int = 500
const SPOILED_G: int = 250
const MILLI_PER_U: int = 1000

## §5.2's work arithmetic (see THE WORK RATE).
const MWU_PER_TICK: int = 80
const EAT_MWU: int = 12000
const DRAW_MWU_PER_MILLI: int = 1
const HANDLE_MWU: int = 1000

## The meals (see THE DAY).
const MEAL_BREAKFAST: int = 0
const MEAL_SUPPER: int = 1
const MEAL_NAMES: Array[String] = ["breakfast", "supper"]
const MEAL_TITLES: Array[String] = ["Breakfast", "Supper"]
const CALL_HOUR: Array[int] = [7, 17]
const END_HOUR: Array[int] = [9, 19]
const COOK_RISE_HOUR: int = 5
## The hour of its day each meal may be cooked from: breakfast at the cook's rising, supper from 15:00.
const COOK_FROM_HOUR: Array[int] = [COOK_RISE_HOUR, 15]

## §5.2's hunger need and its thresholds.
const NEED_MAX: int = 10000
const EAT_AT: int = 3500
const URGENT_AT: int = 1500
## The demo opens with everyone fed (a demo value).
const START_HUNGER: int = 10000
const FED: int = 0
const PECKISH: int = 1
const HUNGRY: int = 2
const FED_WORDS: Array[String] = ["fed", "peckish", "hungry"]
const SIZE_SMALL: int = 0
const SIZE_MEDIUM: int = 1
const SIZE_LARGE: int = 2
## GDD §5.2: carry capacities 12000 / 16000 / 24000 g -- water is 1000 g a unit, so that many milli-U of it.
const CARRY_G: Array[int] = [12000, 16000, 24000]

## §5.7 variety.
const HISTORY: int = 6
const MONOTONY_LOW_FROM: int = 2
const MONOTONY_HIGH_FROM: int = 4
const MONOTONY_LOW: int = -200
const MONOTONY_HIGH: int = -400
const MONOTONY_HOURS: int = 6

## REQ-SET-013 and §5.7's raw table.
const RAW_NP_CAP: int = 3000
## Dried fish is §5.7's PRESERVED `dried_fish` (1800 NP/U, "Dried/salted fish ... are directly edible"; decision 0431):
## the village's reserve, eaten only this way -- §5.7's `fish` selector names the nine species, not their dried form.
const RAW_NP_PER_U: Dictionary = {FarmingScript.CROP_ROOTS: 800, FarmingScript.CROP_CABBAGE: 600,
	Catalog.CAT_DRIED_FISH: 1800}


static func batch_ticks(dish: int) -> int:
	"""Calendar ticks one batch of `dish` takes at the step rate (12 WU: 150 ticks)."""
	@warning_ignore("integer_division") return WORK_MWU[dish] / MWU_PER_TICK


static func is_input(dish: int, item: int) -> bool:
	"""Whether pantry `item` is in one of `dish`'s food categories (see THE CROPS IN EACH CATEGORY)."""
	var category: int = Catalog.category_of(item)
	return category >= 0 and (category == INPUT_CROP[dish] or category == SIDE_CROP[dish])


static func batch_food_milli(dish: int) -> int:
	"""All the food a batch of `dish` takes, milli-U (its input and any second one)."""
	return INPUT_MILLI[dish] + SIDE_MILLI[dish]


static func dish_for_meal(meal: int) -> int:
	"""The alternation (ruling 1): porridge at breakfast, soup at supper -- the meals alternate, so the dishes do."""
	return DISH_PORRIDGE if meal == MEAL_BREAKFAST else DISH_SOUP


static func other(dish: int) -> int:
	"""The dish the alternation turns to when `dish`'s food is short (ruling 1): porridge and soup each other; the fish
	stew, the soup it stands in for."""
	return DISH_PORRIDGE if dish == DISH_SOUP else DISH_SOUP


static func raw_np_per_u(item: int) -> int:
	"""NP a unit of `item` gives eaten raw (0: not raw-edible, never eaten in an emergency)."""
	return int(RAW_NP_PER_U.get(Catalog.category_of(item), 0))


static func size_of_species(species: String) -> int:
	"""A species' §5.2 size class (see SIZE CLASS), by its name in any case (the cast's actors say "Badger"); an
	unknown one (a placeholder) is small."""
	var key := StringName(species.to_lower())
	if ResidentsScript.SPECIES_LARGE_KEYS.has(key):
		return SIZE_LARGE
	if ResidentsScript.SPECIES_MEDIUM_KEYS.has(key) or key == &"beaver":
		return SIZE_MEDIUM
	return SIZE_SMALL


static func fed_state(hunger: int) -> int:
	"""FED above EAT_AT, PECKISH down to URGENT_AT exclusive, HUNGRY at it and below."""
	if hunger > EAT_AT:
		return FED
	return PECKISH if hunger > URGENT_AT else HUNGRY


static func monotony_for(repeats: int) -> int:
	"""§5.7's monotonous memory for a dish eaten `repeats` times among the last HISTORY meals (0: none)."""
	if repeats >= MONOTONY_HIGH_FROM:
		return MONOTONY_HIGH
	return MONOTONY_LOW if repeats >= MONOTONY_LOW_FROM else 0


static func meal_key(day: int, meal: int) -> int:
	"""One number per meal of the calendar: day x 2 + meal."""
	return day * 2 + meal


static func meal_of_hour(hour: int) -> int:
	"""The meal whose serving window holds `hour` (0..23), or -1."""
	for meal: int in 2:
		if hour >= CALL_HOUR[meal] and hour < END_HOUR[meal]:
			return meal
	return -1
