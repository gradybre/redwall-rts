extends RefCounted
## THE FIRST MEAL LOOP'S NUMBERS: the two dishes, what they take, how long the work is, what a resident needs, and
## when the village eats. Decision 0381 (review F21, UX-027; Brendan's rulings of 2026-09-30). Presentation only:
## nothing here touches the settlement simulation. Every number is cited; the demo values are named as such.
##
## THE DISHES (ruling 1: two, alternating; since decision 0601, the recipe book's eight -- dish_book.gd -- chosen by
## the kitchen from the food in store, the meal and the village's favourites: kitchen.gd THE CHOICE). Each is a
## content-library recipe COOKED AS a GDD §5.7 recipe row, with the row's numbers exactly (docs/game_gdd.md §5.7;
## docs/gameplay_balance.md §3.1-3.2). The first two:
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
const Book := preload("res://demo/kitchen/dish_book.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")

const DISH_PORRIDGE: int = 0
const DISH_SOUP: int = 1
## THE THIRD DISH (water part B, decision 0436): the library's "Requested perch or trout" COOKED AS §5.7's `fish_stew`
## row, cooked at supper whenever the stores hold a batch's fresh fish and roots nobody has set aside (fresh fish keeps
## 48 h: it is used while fresh -- `fresher_first` below keeps that rule for every dish).
const DISH_FISH_STEW: int = 2
## THE DISHES OF DECISION 0601 (feature 16): dish_book.gd's rows 3..7, each a library dish cooked as its §5.7 row.
const DISH_BARLEYMEAL: int = 3
const DISH_BEETROOT_SOUP: int = 4
const DISH_VOLE_STEW: int = 5
const DISH_POACHED_DACE: int = 6
const DISH_BEAN_HOTPOT: int = 7
## THE DISHES OF DECISION 0603 (Brendan's DEC-045 and his tuning E2/E3): dish_book.gd's rows 8..18.
const DISH_OATCAKE: int = 8
const DISH_FARL: int = 9
const DISH_HARDTACK: int = 10
const DISH_SALAD: int = 11
const DISH_BAKED_FISH: int = 12
const DISH_BISCUIT_SOUP: int = 13
const DISH_PASTY: int = 14
const DISH_ROOT_PIE: int = 15
const DISH_WOODLAND_PIE: int = 16
const DISH_SCONES: int = 17
const DISH_CORDIAL: int = 18
const NO_DISH: int = -1

## THE RECIPE BOOK'S COLUMNS (dish_book.gd: one row a dish; adding a recipe is adding a row there). Built once, when this
## script loads (`_static_init`); read-only after. Per dish: its key, names, library id, §5.7 row (and that row's index
## among the book's distinct rows, for variety), meal, outputs and work, and its INPUTS as a run [INPUT_FIRST, +INPUT_N)
## of the input columns: each input's SELECTOR (ingredient_takes.gd: its category, or its own items), category and
## milli-U a batch.
static var DISH_COUNT: int = 0
static var DISH_KEYS: Array[StringName] = []
static var DISH_NAMES: Array[String] = []
static var DISH_SHORT: Array[String] = []
static var LIBRARY_IDS: Array[String] = []
## The GDD §5.7 rows they are cooked as, and each one's index among the distinct rows (ROW_COUNT of them).
static var GDD_ROWS: Array[String] = []
static var ROW_OF: PackedInt32Array = PackedInt32Array()
static var ROW_COUNT: int = 0
## Per dish: 1 when its row is one the GDD adopts (dish_book.gd ADOPTED_ROWS), 0 for one of Brendan's DEC-045 rows (decision 0603).
static var ROW_ADOPTED: PackedByteArray = PackedByteArray()
## How many categories the pantry's items use (the highest farm_catalog.gd category_of, plus one; at least the words'):
## a category another lane adds is counted, so the ready-food estimate's pool fits it (built in `_static_init`).
static var CATEGORY_COUNT: int = 0
static var DISH_MEAL: PackedInt32Array = PackedInt32Array()
static var PORTIONS_PER_BATCH: PackedInt32Array = PackedInt32Array()
static var NP_PER_PORTION: PackedInt32Array = PackedInt32Array()
static var WORK_MWU: PackedInt32Array = PackedInt32Array()
static var SHELF_HOURS: PackedInt32Array = PackedInt32Array()
static var WATER_MILLI: PackedInt32Array = PackedInt32Array()
static var INPUT_FIRST: PackedInt32Array = PackedInt32Array()
static var INPUT_N: PackedInt32Array = PackedInt32Array()
## Per input (all dishes' inputs, in dish order).
static var IN_SELECTOR: PackedInt64Array = PackedInt64Array()
static var IN_CATEGORY: PackedInt32Array = PackedInt32Array()
static var IN_MILLI: PackedInt32Array = PackedInt32Array()
## Per input: its items in words ("beetroot or onion"), what a recipe calls it ("roots", "honey"), and what it waits for
## ("" when it can be had: `_waits_for`).
static var IN_ITEMS_TEXT: Array[String] = []
static var IN_WORDS: Array[String] = []
static var IN_WAITS: Array[String] = []
## Per dish: what it WAITS for -- its inputs' reasons, "; "-joined ("" when every input can be had: decision 0603).
static var DISH_WAITS: Array[String] = []
## Per dish: the shortest base shelf life among its inputs' categories (`fresher_first`).
## Per dish: 1 when every input is a whole category (the meal's plain dish of its §5.7 row: porridge, Togget's soup,
## the perch-or-trout stew, the hotpot) -- the Ready food estimate counts these (kitchen.gd THE READY-FOOD ESTIMATE).
static var PLAIN: PackedByteArray = PackedByteArray()
static var FRESHEST_HOURS: PackedInt32Array = PackedInt32Array()
## VIEWS OF THE FIRST TWO INPUTS for the readers written before inputs were a list (the guide's practice stories, the
## older tests): a dish's first input's category and milli-U, and its second's (-1 and 0: none).
static var INPUT_CROP: PackedInt32Array = PackedInt32Array()
static var INPUT_MILLI: PackedInt32Array = PackedInt32Array()
static var SIDE_CROP: PackedInt32Array = PackedInt32Array()
static var SIDE_MILLI: PackedInt32Array = PackedInt32Array()

## What a recipe calls each category, by farm_catalog.gd category id (beans, cabbage, flax, grain, roots, fish, dried
## fish, flour). §5.7's `cabbage` input is the cabbage row -- cabbage, lettuce, spinach, leek and celery -- so it is
## "greens" to the player.
const CATEGORY_WORDS: Array[String] = ["beans", "greens", "flax", "grain", "roots", "fresh fish", "dried fish", "flour",
	"honey"]
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
## A dish's meal in words, by dish_book.gd `meal`: a drink is no meal (decision 0603).
const DISH_MEAL_WORDS: Array[String] = ["breakfast", "supper", "a drink"]
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
## the village's reserve, eaten this way or in the biscuit soup (decision 0603) -- §5.7's `fish` selector names the nine species, not their dried form.
## Honey is §5.7's "Honey | 1200 | Yes" (decision 0603's item; no source yet).
const RAW_NP_PER_U: Dictionary = {FarmingScript.CROP_ROOTS: 800, FarmingScript.CROP_CABBAGE: 600,
	Catalog.CAT_DRIED_FISH: 1800, Catalog.CAT_HONEY: 1200}


static func _static_init() -> void:
	"""Build the recipe book's columns from dish_book.gd DISHES, once."""
	DISH_COUNT = Book.DISHES.size()
	CATEGORY_COUNT = CATEGORY_WORDS.size()
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		CATEGORY_COUNT = maxi(CATEGORY_COUNT, Catalog.category_of(item) + 1)
	for dish: int in DISH_COUNT:
		var row: Dictionary = Book.DISHES[dish]
		DISH_KEYS.append(StringName(row["key"]))
		DISH_NAMES.append(String(row["name"]))
		DISH_SHORT.append(String(row["short"]))
		LIBRARY_IDS.append(String(row["library"]))
		_add_row(String(row["gdd_row"]))
		ROW_ADOPTED.append(1 if Book.ADOPTED_ROWS.has(String(row["gdd_row"])) else 0)
		DISH_MEAL.append(int(row["meal"]))
		PORTIONS_PER_BATCH.append(int(row["portions"]))
		NP_PER_PORTION.append(int(row["np"]))
		WORK_MWU.append(int(row["work_mwu"]))
		SHELF_HOURS.append(int(row["shelf_hours"]))
		WATER_MILLI.append(int(row["water_milli"]))
		_add_inputs(row["inputs"])
		INPUT_CROP.append(IN_CATEGORY[INPUT_FIRST[dish]])
		INPUT_MILLI.append(IN_MILLI[INPUT_FIRST[dish]])
		SIDE_CROP.append(IN_CATEGORY[INPUT_FIRST[dish] + 1] if INPUT_N[dish] > 1 else -1)
		SIDE_MILLI.append(IN_MILLI[INPUT_FIRST[dish] + 1] if INPUT_N[dish] > 1 else 0)


static func _add_row(gdd_row: String) -> void:
	"""Record a dish's §5.7 row and its index among the distinct rows."""
	var at: int = GDD_ROWS.find(gdd_row)
	GDD_ROWS.append(gdd_row)
	if at < 0:
		ROW_OF.append(ROW_COUNT)
		ROW_COUNT += 1
	else:
		ROW_OF.append(ROW_OF[at])


static func _add_inputs(inputs: Array) -> void:
	"""Append a dish's inputs to the input columns (`_add_input`), and the dish's plainness, freshest input's shelf hours
	and what it waits for."""
	INPUT_FIRST.append(IN_SELECTOR.size())
	INPUT_N.append(inputs.size())
	var freshest: int = 1 << 30
	var plain: int = 1
	var reasons := PackedStringArray()
	for input: Variant in inputs:
		_add_input(input)
		var k: int = IN_SELECTOR.size() - 1
		plain = plain if (input[2] as Array).is_empty() else 0
		if IN_CATEGORY[k] >= 0:
			freshest = mini(freshest, category_shelf_hours(IN_CATEGORY[k]))
		if not IN_WAITS[k].is_empty():
			reasons.append(IN_WAITS[k])
	FRESHEST_HOURS.append(freshest)
	PLAIN.append(plain)
	DISH_WAITS.append("; ".join(reasons))


static func _add_input(input: Array) -> void:
	"""One input: its selector (its category, or its own items -- none yet when a NEEDS item does not exist), its
	category (a NEEDS input takes its items' own), milli-U, words and what it waits for (Book.PENDING_SOURCES)."""
	var keys: Array = input[2]
	var items := PackedInt32Array()
	for key: Variant in keys:
		var item: int = Catalog.ITEM_KEYS.find(StringName(key))
		if item >= TakesScript.MASK_BITS or (item < 0 and not Book.PENDING_SOURCES.has(StringName(key))):
			push_error("meal_rules: dish_book.gd names no pantry item %s" % key)
		elif item >= 0:
			items.append(item)
	var category: int = int(input[0])
	if category == Book.NEEDS and not items.is_empty():
		category = Catalog.category_of(items[0])
	IN_SELECTOR.append(category if keys.is_empty() else TakesScript.items_selector(items))
	IN_CATEGORY.append(category)
	IN_MILLI.append(int(input[1]))
	IN_ITEMS_TEXT.append(items_text(IN_SELECTOR[IN_SELECTOR.size() - 1]) if not items.is_empty() or keys.is_empty() \
		else " or ".join(PackedStringArray(keys)))
	IN_WORDS.append(CATEGORY_WORDS[category] if category >= 0 and category < CATEGORY_WORDS.size() \
		else IN_ITEMS_TEXT[IN_ITEMS_TEXT.size() - 1])
	IN_WAITS.append(_waits_for(category, keys))


static func _waits_for(category: int, keys: Array) -> String:
	"""What an input waits for: "needs hazelnut: gathered by foragers" when every item it takes is pending (an item
	not yet in the pantry, or one with no source yet: Book.PENDING_SOURCES); "" when it can be had."""
	var named := PackedStringArray()
	for key: Variant in keys:
		named.append(String(key))
	if keys.is_empty():
		for item: int in Catalog.PANTRY_ITEM_COUNT:
			if Catalog.category_of(item) == category:
				named.append(String(Catalog.ITEM_KEYS[item]))
	var reasons := PackedStringArray()
	for key: String in named:
		if not Book.PENDING_SOURCES.has(StringName(key)):
			return ""
		reasons.append("needs %s: %s" % [key.replace("_", " "), Book.PENDING_SOURCES[StringName(key)]])
	return "; ".join(reasons)


static func category_shelf_hours(category: int) -> int:
	"""§5.7's base shelf hours of a category's items (crop rows from CROP_SHELF_HOURS, goods from GOODS_SHELF_HOURS)."""
	if category >= 0 and category < Catalog.CROP_SHELF_HOURS.size():
		return Catalog.CROP_SHELF_HOURS[category]
	var goods: int = Catalog.GOODS_CATEGORY.find(category)
	return Catalog.GOODS_SHELF_HOURS[goods] if goods >= 0 else 0


static func batch_ticks(dish: int) -> int:
	"""Calendar ticks one batch of `dish` takes at the step rate (12 WU: 150 ticks)."""
	@warning_ignore("integer_division") return WORK_MWU[dish] / MWU_PER_TICK


static func input_selector(dish: int, k: int) -> int:
	"""`dish`'s input `k`'s selector (ingredient_takes.gd: its category, or its own items)."""
	return IN_SELECTOR[INPUT_FIRST[dish] + k]


static func input_category(dish: int, k: int) -> int:
	"""`dish`'s input `k`'s category (§5.7's input)."""
	return IN_CATEGORY[INPUT_FIRST[dish] + k]


static func input_milli(dish: int, k: int) -> int:
	"""Milli-U of `dish`'s input `k` a batch takes."""
	return IN_MILLI[INPUT_FIRST[dish] + k]


static func input_of(dish: int, item: int) -> int:
	"""Which of `dish`'s inputs pantry `item` fills (-1: none)."""
	for k: int in INPUT_N[dish]:
		if TakesScript.matches(input_selector(dish, k), item):
			return k
	return -1


static func is_input(dish: int, item: int) -> bool:
	"""Whether pantry `item` is one `dish` takes (its category, narrowed to the dish's own ingredients)."""
	return input_of(dish, item) >= 0


static func batch_food_milli(dish: int) -> int:
	"""All the food a batch of `dish` takes, milli-U (every input)."""
	var total: int = 0
	for k: int in INPUT_N[dish]:
		total += input_milli(dish, k)
	return total


static func serves(dish: int, meal: int, own: bool) -> bool:
	"""Whether the cook may pick `dish` for `meal`: one of that meal's dishes (`own`) or of the other meal's (not `own`)
	-- never a drink, nor a dish still waiting for an ingredient (its label is the cook's rule too; decision 0603)."""
	return is_meal_dish(dish) and not waits(dish) and (DISH_MEAL[dish] == meal) == own


static func is_meal_dish(dish: int) -> bool:
	"""Whether `dish` is served at breakfast or supper (a drink is not)."""
	return DISH_MEAL[dish] == MEAL_BREAKFAST or DISH_MEAL[dish] == MEAL_SUPPER


static func waits(dish: int) -> bool:
	"""Whether `dish` waits for an ingredient the demo cannot produce yet (DISH_WAITS)."""
	return not DISH_WAITS[dish].is_empty()


static func is_everyday_dish(dish: int) -> bool:
	"""Whether `dish` is one the kitchen cooks for an ordinary meal now: served at breakfast or supper (not a drink, not
	an occasion's course alone) and waiting for no ingredient. "Every dish on the table" counts these (decision 0902)."""
	return dish >= 0 and dish < DISH_COUNT and is_meal_dish(dish) and not waits(dish)


static func everyday_dish_count() -> int:
	"""How many everyday dishes the book holds (`is_everyday_dish`)."""
	var n: int = 0
	for dish: int in DISH_COUNT:
		n += 1 if is_everyday_dish(dish) else 0
	return n


static func dish_for_meal(meal: int) -> int:
	"""The meal's first dish, cooked when nothing is (ruling 1's: porridge at breakfast, soup at supper)."""
	return DISH_PORRIDGE if meal == MEAL_BREAKFAST else DISH_SOUP


static func other(dish: int) -> int:
	"""The other meal's first dish -- what a meal turns to when none of its own dishes has food (ruling 1); NO_DISH for
	no dish."""
	if dish < 0 or dish >= DISH_COUNT:
		return NO_DISH
	return DISH_SOUP if DISH_MEAL[dish] == MEAL_BREAKFAST else DISH_PORRIDGE


static func fresher_first(a: int, b: int) -> int:
	"""Which of two dishes uses the food that keeps less long (§5.7's base shelf hours of its inputs' categories):
	negative for `a`, positive for `b`, 0 alike. Fresh fish (48 h) before greens (144 h), roots (240 h) and grain
	(720 h): decision 0436's "fresh fish is cooked while it is fresh", for every dish."""
	return FRESHEST_HOURS[a] - FRESHEST_HOURS[b]


static func same_recipe(a: int, b: int) -> bool:
	"""Whether two dishes are one §5.7 recipe (§5.7: "Ingredient differences inside the same recipe do not fake
	variety")."""
	return a >= 0 and b >= 0 and ROW_OF[a] == ROW_OF[b]


static func items_text(selector: int) -> String:
	"""The items a selector takes, in words: "beetroot or onion"."""
	var names := PackedStringArray()
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		if TakesScript.matches(selector, item):
			names.append(Catalog.ITEM_LABELS[item].to_lower())
	if names.size() < 2:
		return "".join(names)
	return "%s or %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


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
