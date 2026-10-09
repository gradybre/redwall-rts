extends "res://test/framework/test_case.gd"
## Goods in natural measures (decision 1011, DEC-049; phase 2, decision 1801): scripts/ui/goods_measures.gd.
##
## Expected strings are LITERALS written from 1011's table, never generated from the module under test, so a drift in
## the module fails here. The sweep reads each rendered string back into an amount with its own small parser (the
## number, the measure word from the table's rows, or the weight) and proves `amount` never above the truth and `need`
## never below it, for every good.

const M := preload("res://scripts/ui/goods_measures.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const DishBook := preload("res://demo/kitchen/dish_book.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const CATALOGUE_PATH: String = "res://data/item_definitions.json"
## The display keys 1011 §4 adds beside the catalogue's and the pantry's (planks, earth, mixed food, the kitchen's
## categories).
const DISPLAY_KEYS: Array[StringName] = [&"planks", &"earth", &"food", &"greens", &"fish"]
## The kitchen's recipe categories (dish_book.gd) and the good each is worded as (1011 §1 "Kitchen categories").
const CATEGORY_GOOD: Dictionary = {
	FarmingScript.CROP_GRAIN: &"grain", FarmingScript.CROP_ROOTS: &"roots", FarmingScript.CROP_BEANS: &"beans",
	FarmingScript.CROP_CABBAGE: &"greens", Catalog.CAT_FISH: &"fish", Catalog.CAT_FLOUR: &"flour",
	Catalog.CAT_DRIED_FISH: &"dried_fish", Catalog.CAT_HONEY: &"honey", Catalog.CAT_NUTS: &"nuts",
	Catalog.CAT_HERB: &"herb", Catalog.CAT_BERRIES: &"berries", Catalog.CAT_FRUIT: &"fruit",
}
## Every rule quantity 1011 §1 and §1a list as a whole number of a measure (good, milli-U).
const RULE_QUANTITIES: Array = [
	[&"herb", 250], [&"herb", 500], [&"herb", 1000], [&"honey", 500], [&"nuts", 500], [&"water", 250],
	[&"wood", 100], [&"wood", 250], [&"compost", 250], [&"compost", 500], [&"compost", 2000], [&"cloth", 500],
	[&"rope", 250], [&"wax", 250], [&"flax", 250], [&"seed_grain", 250], [&"seed_grain", 4000],
	[&"seed_grain", 8000], [&"water", 10000], [&"earth", 2000],
]
## The deterministic sweep: every milli-U to this bound, then a stride beyond it.
const SWEEP_DENSE_TO: int = 3000
const SWEEP_TO: int = 260000
const SWEEP_STRIDE: int = 37


func _catalogue() -> Dictionary:
	"""The catalogue's mass_g by id, read from its JSON (the module reads it through item_definitions.gd)."""
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE_PATH))
	var out: Dictionary = {}
	for item: Dictionary in parsed["items"]:
		out[StringName(item["id"])] = int(item["mass_g"])
	return out


# --- the table ----------------------------------------------------------------------------------------------------

func test_every_catalogue_pantry_and_display_good_has_a_row() -> void:
	"""All 61 catalogue items, the demo pantry's 42 items and the display keys are worded (P9 (b), §4)."""
	var keys: Array[StringName] = []
	keys.append_array(_catalogue().keys())
	keys.append_array(Catalog.ITEM_KEYS)
	keys.append_array(DISPLAY_KEYS)
	assert_equal(_catalogue().size(), 61, "the catalogue's 61 items")
	assert_equal(Catalog.ITEM_KEYS.size(), Catalog.PANTRY_ITEM_COUNT, "the pantry's items")
	for key: StringName in keys:
		assert_true(M.knows(key), "%s has a measures row" % key)


func test_each_row_weighs_as_its_catalogue_mass() -> void:
	"""A row's mass is its catalogue row's mass_g, checked against item_definitions.json (never retyped)."""
	var masses: Dictionary = _catalogue()
	for r: Array in M.ROWS:
		assert_true(masses.has(r[1]), "%s weighs as a catalogue item (%s)" % [r[0], r[1]])
		assert_equal(M.grams(r[0], 1000), masses.get(r[1], -1), "%s: one U weighs its catalogue mass_g" % r[0])
	assert_equal(M.grams(&"planks", 1000), 5000, "P2: a plank is 5 kg")
	assert_equal(M.grams(&"barley", 1000), 250, "raw food is 250 g a U")
	assert_equal(M.grams(&"ration", 1000), 500, "a ration is 500 g")


func test_every_measure_is_a_whole_number_of_milli_and_halves_split_evenly() -> void:
	"""Each measure is a positive whole milli-U; a measure shown in halves splits into whole milli; from >= 1; largest
	measure first."""
	for r: Array in M.ROWS:
		var last: int = 1 << 40
		for measure: Array in r[4]:
			var milli: int = measure[2]
			assert_true(milli > 0 and milli < last, "%s %s: positive, largest first" % [r[0], measure[0]])
			assert_true(measure[4] == 0 or milli % 2 == 0, "%s %s: halves are whole milli" % [r[0], measure[0]])
			assert_true(measure[3] >= 1, "%s %s: from at least 1" % [r[0], measure[0]])
			last = milli


func test_one_measure_fits_one_small_residents_carry() -> void:
	"""1011's design rule: a measure one small resident can carry (12 kg), the cask excepted (rolled, not carried)."""
	for r: Array in M.ROWS:
		for measure: Array in r[4]:
			if measure[0] == "cask":
				continue
			assert_true(M.grams(r[0], measure[2]) <= 12000, "%s %s is at most 12 kg" % [r[0], measure[0]])


# --- amount, need, exact: literals from 1011 --------------------------------------------------------------------------

func test_amounts_in_sentences_from_the_table() -> void:
	"""1011 §1/§2's own examples, as literals."""
	assert_equal(M.amount(&"barley", 240000), "12 sacks of barley", "12 sacks")
	assert_equal(M.amount(&"wood", 40000), "40 logs", "40 logs")
	assert_equal(M.amount(&"barley", 19000), "19 scoops of barley", "below 2 sacks: scoops")
	assert_equal(M.amount(&"barley", 150), "37 g of barley", "below a scoop: its weight, floored")
	assert_equal(M.amount(&"herb", 160), "40 g of herbs", "40 g of herbs")
	assert_equal(M.amount(&"herb", 1000), "a bunch of herbs", "a bunch")
	assert_equal(M.amount(&"herb", 250), "a handful of herbs", "a handful")
	assert_equal(M.amount(&"perch", 9000), "9 perch", "fish counted, same plural (P3)")
	assert_equal(M.amount(&"trout", 1000), "a trout", "one fish")
	assert_equal(M.amount(&"onion", 12000), "12 onions", "onions counted (P4)")
	assert_equal(M.amount(&"onion", 1000), "an onion", "an, before a vowel")
	assert_equal(M.amount(&"dried_fish", 3000), "3 strings of dried fish", "a rack batch")
	assert_equal(M.amount(&"honey", 500), "half a jar of honey", "a tart's honey")
	assert_equal(M.amount(&"stone", 800), "4 kg of stone", "a rock quantum's 0.8 U")
	assert_equal(M.amount(&"food", 32500), "6½ baskets of food", "the Pantry's total")
	assert_equal(M.amount(&"wood", 750), "3 quarter logs", "0.25-0.99 U of wood in quarter logs (§1a)")
	assert_equal(M.amount(&"wood", 100), "a bundle of kindling", "the kitchen's 0.1 U")
	assert_equal(M.amount(&"cabbage", 4000), "2 cabbages", "a cabbage is 2 U")
	assert_equal(M.amount(&"celery", 2000), "a head of celery", "a head of celery")
	assert_equal(M.amount(&"water", 250), "a cup of water", "tending: a cup of well water")
	assert_equal(M.amount(&"cloth", 500), "a length of cloth", "a treatment's cloth")
	assert_equal(M.amount(&"rope", 250), "a length of rope", "mending's rope")
	assert_equal(M.amount(&"earth", 2000), "a basket of earth", "a digger's 2 U")
	assert_equal(M.amount(&"ration", 3000), "3 rations", "rations counted")


func test_zero_trace_and_cells() -> void:
	"""Zero is "none" in a cell and "no barley" in a sentence; under a gram is a trace, never 0; a cell keeps the
	digit for one and drops the good's name."""
	assert_equal(M.amount(&"barley", 0), "no barley", "zero, sentence")
	assert_equal(M.amount_cell(&"barley", 0), "none", "zero, cell")
	assert_equal(M.amount(&"herb", 1), "a trace of herbs", "1 milli of herbs is 0.25 g")
	assert_equal(M.amount_cell(&"herb", 1), "a trace", "a trace, cell")
	assert_equal(M.amount(&"barley", 3), "a trace of barley", "3 milli of barley is 0.75 g")
	assert_equal(M.amount(&"barley", 4), "1 g of barley", "4 milli of barley is 1 g")
	assert_equal(M.amount_cell(&"herb", 1000), "1 bunch", "one, in a cell: the digit")
	assert_equal(M.amount_cell(&"barley", 240000), "12 sacks", "a cell drops 'of barley'")
	assert_equal(M.amount_cell(&"honey", 500), "½ jar", "a half, cell")
	assert_equal(M.amount_cell(&"stone", 20000), "20 blocks", "P1: Stone in blocks")
	assert_equal(M.amount(&"barley", -5), "no barley", "a negative amount is shown as none")


func test_halves_below_ten_and_whole_from_ten() -> void:
	"""Halves below ten measures ("1½ jars", "9½ sacks"); whole measures from ten up."""
	assert_equal(M.amount(&"honey", 1500), "1½ jars of honey", "1½")
	assert_equal(M.amount(&"honey", 1999), "1½ jars of honey", "just below 2: floored to the half")
	assert_equal(M.amount(&"barley", 50000), "2½ sacks of barley", "2½ sacks")
	assert_equal(M.amount(&"barley", 199999), "9½ sacks of barley", "just below ten: halves")
	assert_equal(M.amount(&"barley", 200000), "10 sacks of barley", "ten: whole")
	assert_equal(M.amount(&"barley", 210000), "10 sacks of barley", "10½ shows as 10")
	assert_equal(M.need(&"barley", 199999), "10 sacks of barley", "a need just below ten rounds up to ten")
	assert_equal(M.amount(&"honey", 499), "124 g of honey", "below half a jar: its weight")


func test_from_two_threshold_and_just_below() -> void:
	"""A "from 2" container appears only from two of it: 39.999 U of barley is scoops, 40 U is 2 sacks."""
	assert_equal(M.amount(&"barley", 39999), "39 scoops of barley", "just below 2 sacks")
	assert_equal(M.amount(&"barley", 40000), "2 sacks of barley", "2 sacks")
	assert_equal(M.amount(&"water", 19999), "19 jugs of water", "just below 2 buckets")
	assert_equal(M.amount(&"water", 20000), "2 buckets of water", "2 buckets")
	assert_equal(M.amount(&"radish", 9999), "9 bunches of radishes", "just below 2 baskets")
	assert_equal(M.amount(&"radish", 10000), "2 baskets of radishes", "2 baskets")
	assert_equal(M.amount(&"food", 5000), "a basket of food", "mixed food has no 'from 2' (§1)")
	assert_equal(M.amount(&"spoiled_food", 5000), "5 bowls of spoiled food", "spoiled food is from 2 (§1a)")


func test_each_measure_and_just_below_it() -> void:
	"""At each measure the measure shows; just below, the next one down (or the weight)."""
	assert_equal(M.amount(&"wood", 1000), "a log", "a log")
	assert_equal(M.amount(&"wood", 999), "3 quarter logs", "just below a log")
	assert_equal(M.amount(&"wood", 250), "a quarter log", "a quarter log")
	assert_equal(M.amount(&"wood", 249), "2 bundles of kindling", "just below a quarter log")
	assert_equal(M.amount(&"wood", 99), "495 g of wood", "just below a bundle of kindling")
	assert_equal(M.amount(&"cloth", 4000), "half a bolt of cloth", "half a bolt")
	assert_equal(M.amount(&"cloth", 3999), "7 lengths of cloth", "just below half a bolt")
	assert_equal(M.amount(&"mead", 40000), "2 casks of mead", "2 casks")
	assert_equal(M.amount(&"mead", 39999), "39 jugs of mead", "just below 2 casks")


func test_need_rounds_up() -> void:
	"""A requirement never understated: planks for 4.7 m of deck are 5 planks."""
	assert_equal(M.need(&"planks", 4700), "5 planks", "5 planks")
	assert_equal(M.need(&"barley", 150), "38 g of barley", "a need below a scoop: weight raised")
	assert_equal(M.need(&"herb", 300), "2 handfuls of herbs", "0.3 U of herbs: 2 handfuls")
	assert_equal(M.need(&"barley", 40001), "2½ sacks of barley", "just above 2 sacks: raised to the half")
	assert_equal(M.need_cell(&"herb", 1), "1 g", "the least need: a gram, never a trace")
	assert_equal(M.need(&"iron", 901), "1.81 kg of iron", "a need's kg are raised to 10 g")


func test_exact_picks_the_largest_dividing_measure() -> void:
	"""Authored constants print exactly: "2 scoops of grain", "a handful of herbs", "Keep 15 scoops of barley"."""
	assert_equal(M.exact(&"grain", 2000), "2 scoops of grain", "porridge's grain")
	assert_equal(M.exact(&"herb", 250), "a handful of herbs", "a nut roast's herbs")
	assert_equal(M.exact(&"barley", 15000), "15 scoops of barley", "a standing order's target")
	assert_equal(M.exact(&"wood", 100), "a bundle of kindling", "the kitchen's wood a batch")
	assert_equal(M.exact(&"mead", 59000), "59 jugs of mead", "59 U is no whole number of casks")
	assert_equal(M.exact(&"barley", 30000), "30 scoops of barley", "1½ sacks is below the from-2 threshold")
	assert_equal(M.exact(&"barley", 150), "37 g of barley", "no measure divides: the weight")
	assert_equal(M.exact_cell(&"compost", 2000), "1 basket", "a cell")
	assert_equal(M.exact(&"barley", 230000), "230 scoops of barley", "11½ sacks: halves stop at ten, scoops divide")


func test_exact_round_trips_every_recipe_input_and_rule_quantity() -> void:
	"""Every dish_book.gd input and water, and every quantity 1011 §1/§1a lists, is a whole number of a measure: no
	rule ever prints a weight."""
	for dish: Dictionary in DishBook.DISHES:
		for input: Array in dish["inputs"]:
			var good: StringName = _input_good(input)
			_assert_exact_round_trip(good, int(input[1]), "%s: %s" % [dish["key"], good])
		if int(dish["water_milli"]) > 0:
			_assert_exact_round_trip(&"water", int(dish["water_milli"]), "%s: water" % dish["key"])
	for q: Array in RULE_QUANTITIES:
		_assert_exact_round_trip(q[0], q[1], "1011's %s" % q[0])


func _input_good(input: Array) -> StringName:
	"""A recipe input's good: its category's, or a NEEDS input's own item."""
	if int(input[0]) == DishBook.NEEDS:
		return (input[2] as Array)[0]
	return CATEGORY_GOOD[int(input[0])]


func _assert_exact_round_trip(good: StringName, milli: int, what: String) -> void:
	"""`exact` names a measure (not a weight) and reads back to exactly `milli`."""
	var words: String = M.exact(good, milli)
	var back: Vector2i = _parse(good, words)
	assert_equal(back.y, 0, "%s: '%s' is a measure, not a weight" % [what, words])
	assert_equal(back.x, milli, "%s: '%s' reads back exactly" % [what, words])


func test_the_kitchen_categories_are_worded_as_their_goods() -> void:
	"""meal_rules.gd CATEGORY_GOODS lines up with CATEGORY_WORDS: each category's good has that category's name (the
	kitchen's "fresh fish" are counted "fish"; "greens" are §5.7's cabbage row)."""
	assert_equal(MealRules.CATEGORY_GOODS.size(), MealRules.CATEGORY_WORDS.size(), "one good a category")
	for c: int in MealRules.CATEGORY_GOODS.size():
		var words: String = MealRules.CATEGORY_WORDS[c].trim_prefix("fresh ")
		var good: StringName = MealRules.CATEGORY_GOODS[c]
		assert_true(M.noun(good).ends_with(words) or M.noun(good).ends_with(words.trim_suffix("s")),
			"category %d '%s' is the good %s ('%s')" % [c, MealRules.CATEGORY_WORDS[c], good, M.noun(good)])


# --- have_need, weight, tooltip ----------------------------------------------------------------------------------------

func test_have_need_uses_the_needs_measure_and_reads_enough_at_the_edge() -> void:
	""""4 of 5 planks"; "5 planks — enough" at have == need; one milli short is not enough."""
	assert_equal(M.have_need(&"planks", 4000, 5000), "4 of 5 planks", "short")
	assert_equal(M.have_need(&"planks", 5000, 5000), "5 planks — enough", "have == need: enough")
	assert_equal(M.have_need(&"planks", 4999, 5000), "4 of 5 planks", "one milli short: not enough")
	assert_equal(M.have_need(&"planks", 9000, 5000), "5 planks — enough", "more than enough")
	assert_equal(M.have_need(&"planks", 0, 5000), "0 of 5 planks", "none")
	assert_equal(M.have_need(&"planks", 300, 5000), "under 1 of 5 planks", "something, under one plank")
	assert_equal(M.have_need(&"barley", 31000, 45000), "1½ of 2½ sacks", "halves of the need's sack")
	assert_equal(M.have_need(&"herb", 100, 250), "under 1 of 1 handful", "under one of the need's measure")
	assert_equal(M.have_need(&"honey", 100, 500), "under ½ of ½ jar", "under half a jar")
	assert_equal(M.have_need(&"barley", 190000, 200000), "9 of 10 sacks", "a need of ten measures: whole ones, both")
	assert_equal(M.have_need(&"barley", 190000, 199999), "9½ of 10 sacks", "just under ten: halves")
	assert_equal(M.have_need(&"stone", 300, 800), "1.5 kg of 4 kg", "a need below every measure: both as weights")
	assert_equal(M.have_need(&"stone", 199, 800), "995 g of 4 kg", "the have's weight floored, never above it")
	assert_equal(M.have_need(&"herb", 3, 100), "a trace of 25 g", "a trace beside a need in grams")


func test_weight_is_exact_in_grams() -> void:
	"""milli × mass_g / 1000 in integer grams; kg from 1 kg, floored to 10 g, trailing zeros dropped; water in litres."""
	assert_equal(M.grams(&"barley", 250000), 62500, "250 U of barley is 62,500 g")
	assert_equal(M.grams(&"herb", 250), 62, "a handful of herbs floors to 62 g")
	assert_equal(M.grams(&"barley", -4000), 0, "a negative amount weighs nothing")
	assert_equal(M.weight(&"barley", 250000), "62.5 kg", "62.5 kg")
	assert_equal(M.weight(&"wood", 950), "4.75 kg", "4.75 kg")
	assert_equal(M.weight(&"stone", 1000), "5 kg", "5 kg")
	assert_equal(M.weight(&"barley", 2500), "625 g", "625 g")
	assert_equal(M.weight(&"barley", 4001), "1 kg", "1,000.25 g floors to 1 kg")
	assert_equal(M.weight(&"water", 10000), "10 litres (10 kg)", "P8: litres and kg")
	assert_equal(M.weight(&"water", 1000), "1 litre (1 kg)", "one litre")
	assert_equal(M.weight(&"water", 250), "250 ml (250 g)", "a cup")
	assert_equal(M.weight(&"herb", 1), "under 1 g", "a trace")
	assert_equal(M.weight(&"herb", 0), "0 g", "nothing")
	assert_true(M.divides(&"cabbage", 4000) and not M.divides(&"cabbage", 5000), "a cabbage is 2 U: 5 U is no whole count")
	assert_false(M.divides(&"barley", 0), "nothing is no measure")
	assert_equal(M.weight(&"stone", 1000000), "5,000 kg", "kg grouped")


func test_tooltip_adds_the_weight() -> void:
	""""12 sacks of barley — 60 kg"; an amount already a weight is not repeated; zero has none."""
	assert_equal(M.tooltip(&"barley", 240000), "12 sacks of barley — 60 kg", "a tooltip")
	assert_equal(M.tooltip(&"herb", 160), "40 g of herbs", "already a weight")
	assert_equal(M.tooltip(&"barley", 0), "no barley", "nothing")
	assert_equal(M.tooltip(&"water", 20000), "2 buckets of water — 20 litres (20 kg)", "water")


func test_noun_and_unknown_good() -> void:
	"""The good's sentence name; an unknown good errors and returns "?" from every rendering."""
	assert_equal(M.noun(&"dried_fish"), "dried fish", "noun")
	assert_false(M.knows(&"no_such_good"), "knows() asks without an error")
	expect_diagnostic("no measure for the good 'no_such_good'")
	assert_equal(M.amount(&"no_such_good", 1000), "?", "amount")
	expect_diagnostic("no measure for the good 'no_such_good_2'")
	assert_equal(M.need_cell(&"no_such_good_2", 1000), "?", "need_cell")
	expect_diagnostic("no measure for the good 'no_such_good_3'")
	assert_equal(M.have_need(&"no_such_good_3", 1, 2), "?", "have_need")
	expect_diagnostic("no measure for the good 'no_such_good_4'")
	assert_equal(M.weight(&"no_such_good_4", 1000), "?", "weight")
	expect_diagnostic("no measure for the good 'no_such_good_5'")
	assert_equal(M.grams(&"no_such_good_5", 1000), 0, "grams")


# --- the Wood level ---------------------------------------------------------------------------------------------------

func test_wood_level_in_order_at_each_boundary() -> void:
	"""none / very low / running low / plenty / enough, judged in that order (1011 §3, §4b)."""
	assert_equal(M.wood_level(0, true, true, 1000), M.LEVEL_NONE, "no wood: none, whatever else")
	assert_equal(M.wood_level(1, true, true, 1000), M.LEVEL_VERY_LOW, "the fuel warning: very low")
	assert_equal(M.wood_level(1, false, true, 1000), M.LEVEL_RUNNING_LOW, "wanted: running low")
	assert_equal(M.wood_level(1000, false, false, 1000), M.LEVEL_PLENTY, "at the projection: plenty")
	assert_equal(M.wood_level(999, false, false, 1000), M.LEVEL_ENOUGH, "just below it, not wanted: enough")
	assert_equal(M.wood_level(5000, false, false, 0), M.LEVEL_ENOUGH, "no projection: enough")
	assert_equal(M.level_words(M.LEVEL_RUNNING_LOW), "running low", "words")
	assert_equal(M.level_words(M.LEVEL_PLENTY), "plenty", "words")
	assert_equal(M.level_words(9), "?", "out of range")
	assert_equal(M.level_words(-1), "?", "below range")


func test_the_half_glyph_is_in_every_ui_font() -> void:
	"""1011 §4: "½" must exist in the body fonts and the heading font, or the halves would be written out."""
	for path: String in ["res://ui/fonts/NotoSans-Regular.ttf", "res://ui/fonts/NotoSans-Medium.ttf",
			"res://ui/fonts/NotoSans-SemiBold.ttf", "res://ui/fonts/NotoSans-Bold.ttf",
			"res://demo/ui/fonts/NotoSerif-SemiBold.ttf"]:
		var font := FontFile.new()
		assert_equal(font.load_dynamic_font(path), OK, "%s loads" % path)
		assert_true(font.has_char(0x00BD) and font.has_char(0x2014), "%s has ½ and —" % path)


# --- the sweep --------------------------------------------------------------------------------------------------------

func test_amount_never_above_and_need_never_below_the_truth() -> void:
	"""For every good, densely to 3 U and then on a stride to 260 U: amount <= true <= need, read back from the
	words; from a from-2 container's threshold up, amount is within 20% of the truth. Something present never reads 0
	(under a gram it is "a trace"). The cask (mead, ale, cider) is the one from-2 measure without halves, so 2.99 casks
	reads "2 casks" (33% under): it is outside the 20% bound, with the exact weight in its tooltip (decision 1801)."""
	var bad: int = 0
	for r: Array in M.ROWS:
		bad += _sweep_row(r)
	assert_equal(bad, 0, "every swept amount is within its rounding's bound (failures printed above)")


func _sweep_row(r: Array) -> int:
	"""The sweep over one good; the count of failures, the first few recorded."""
	var bad: int = 0
	var milli: int = 1
	while milli <= SWEEP_TO and bad < 3:
		bad += _check_one(r, milli)
		milli += 1 if milli < SWEEP_DENSE_TO else SWEEP_STRIDE
	return bad


func _check_one(r: Array, milli: int) -> int:
	"""amount <= truth <= need for one amount (compared in gram-milli, so weights compare exactly)."""
	var good: StringName = r[0]
	var mass: int = M.grams(good, 1000)
	var truth: int = milli * mass
	var down_words: String = M.amount(good, milli)
	var down: int = _shown(good, down_words, mass)
	var up: int = _shown(good, M.need(good, milli), mass)
	var trace: bool = down_words.begins_with("a trace") and truth < 1000
	var ok: bool = down <= truth and up >= truth and (down > 0 or trace)
	var from2: int = _from_two_threshold(r)
	if from2 > 0 and milli >= from2 and r[0] != &"mead" and r[0] != &"ale" and r[0] != &"cider":
		ok = ok and down * 5 >= truth * 4
	if not ok:
		fail("%s at %d milli: amount '%s' (%d), need '%s' (%d), truth %d" % [good, milli, M.amount(good, milli), down,
			M.need(good, milli), up, truth])
		return 1
	return 0


func _from_two_threshold(r: Array) -> int:
	"""A row's "from 2" container threshold in milli-U, or 0 without one."""
	for measure: Array in r[4]:
		if int(measure[3]) >= 2:
			return int(measure[3]) * int(measure[2])
	return 0


func _shown(good: StringName, words: String, mass: int) -> int:
	"""What the words claim, in gram-milli (milli-U × mass_g)."""
	var back: Vector2i = _parse(good, words)
	return back.x * mass if back.y == 0 else back.x * 1000


func _parse(good: StringName, words: String) -> Vector2i:
	"""Read a sentence back: (milli-U, 0) for a measure, (grams, 1) for a weight, (-1, 0) unreadable."""
	var noun: String = M.noun(good)
	var of_noun: String = " of " + noun
	if words == "no " + noun or words.begins_with("a trace"):
		return Vector2i(0, 1)
	var weight: Vector2i = _parse_weight(words.trim_suffix(of_noun))
	if weight.x >= 0:
		return weight
	var count: Vector2i = _parse_count(words)
	var rest: String = words.substr(count.y).trim_suffix(of_noun)
	for r: Array in M.ROWS:
		if r[0] != good:
			continue
		for measure: Array in r[4]:
			if rest == measure[0] or rest == measure[1]:
				@warning_ignore("integer_division") return Vector2i(count.x * int(measure[2]) / 2, 0)
	return Vector2i(-1, 0)


func _parse_weight(words: String) -> Vector2i:
	"""(grams, 1) for "37 g" or "4.75 kg"; (-1, 1) otherwise."""
	if words.ends_with(" kg"):
		var kg: String = words.trim_suffix(" kg").replace(",", "")
		var parts: PackedStringArray = kg.split(".")
		var frac: String = (parts[1] + "000").left(3) if parts.size() > 1 else "000"
		return Vector2i(int(parts[0]) * 1000 + int(frac), 1)
	if words.ends_with(" g") and words.trim_suffix(" g").is_valid_int():
		return Vector2i(int(words.trim_suffix(" g")), 1)
	return Vector2i(-1, 1)


func _parse_count(words: String) -> Vector2i:
	"""(halves, characters read) for the count at the start: "half a ", "a ", "an ", "12 ", "1½ "."""
	for lead: String in ["half a ", "half an "]:
		if words.begins_with(lead):
			return Vector2i(1, lead.length())
	for lead: String in ["a ", "an "]:
		if words.begins_with(lead):
			return Vector2i(2, lead.length())
	var space: int = words.find(" ")
	var number: String = words.left(space).replace(",", "")
	var half: int = 1 if number.ends_with("½") else 0
	return Vector2i(int(number.trim_suffix("½")) * 2 + half, space + 1)
