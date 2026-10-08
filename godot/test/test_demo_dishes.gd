extends "res://test/framework/test_case.gd"
## Feature 16 (decision 0601): the kitchen's recipe book, each species' favourites, and the cook's choice. The book is
## data (dish_book.gd) checked against GDD §5.7 and the content library; the tastes are data and display only; the choice
## is deterministic -- the food that keeps least long, then the village's tastes, then the book's order.
##
## No scene tree: a kitchen over hand-built spaces and real brains, as test_demo_kitchen.gd's.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const Book := preload("res://demo/kitchen/dish_book.gd")
const Tastes := preload("res://demo/kitchen/dish_favourites.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const FedScript := preload("res://demo/kitchen/nourishment.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const Words := preload("res://demo/kitchen/kitchen_text.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")
const TabScript := preload("res://demo/kitchen/kitchen_tab.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const FarmSimScript := preload("res://demo/farm/farm_sim.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const DT: float = 1.0 / 30.0
const FRAMES_PER_HOUR: int = SimClock.TICKS_PER_HOUR
const STORE_AT: Vector2 = Vector2(8.5, 0.5)
const RECIPES_PATH: String = "res://../docs/redwall-content-library/shared/recipes.json"
const RADISH: int = 0
const TURNIP: int = 1
const CARROT: int = 2
const BEETROOT: int = 3
const ONION: int = 5
const CABBAGE: int = 6
const LEEK: int = 9
const PEA: int = 11
const WHEAT: int = 13
const BARLEY: int = 14
const OATS: int = 15
const TROUT: int = 16
const DACE: int = 17
## GDD §5.7's recipe rows the book cooks as: inputs (category, milli-U), water, portions x NP, WU, shelf.
const GDD_ROWS: Dictionary = {
	"porridge": [[[FarmingScript.CROP_GRAIN, 2000]], 2000, 2, 1800, 12000, 24],
	"root_stew": [[[FarmingScript.CROP_ROOTS, 3000]], 1000, 2, 1800, 16000, 24],
	"fish_stew": [[[Catalog.CAT_FISH, 2000], [FarmingScript.CROP_ROOTS, 2000]], 2000, 3, 2200, 20000, 24],
	"bean_hotpot": [[[FarmingScript.CROP_BEANS, 2000], [FarmingScript.CROP_CABBAGE, 2000]], 2000, 3, 2100, 20000, 36],
	"woodland_pie": [[[Catalog.CAT_FLOUR, 2000], [Book.NEEDS, 2000], [FarmingScript.CROP_ROOTS, 1000]], 1000, 3, 2300,
		30000, 48],
	"nut_loaf": [[[Catalog.CAT_FLOUR, 2000], [Catalog.CAT_NUTS, 2000]], 1000, 3, 2600, 24000, 72],
}

var _read: IntMath.IntResult = IntMath.IntResult.new()


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of `day`."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


func _pantry() -> PantryScript:
	"""A pantry over a covered store."""
	return PantryScript.new(StorageScript.new(STORE_AT))


func _kitchen(species: PackedStringArray, tick: int, pantry: PantryScript, stores: StoresScript) -> KitchenScript:
	"""A kitchen for one resident of each of `species`, standing at the square, on a calendar at `tick`."""
	var space := CastSpaceScript.new()
	space.setup([] as Array[Dictionary], [] as Array[Vector3])
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i in species.size():
		var brain := BrainScript.new()
		brain.configure(space, 1.0, 0.25, 3 + i, lengths)
		brain.start_at(Vector2(float(i), 1.0), 0.0, -1, -1)
		brains.append(brain)
		names.append("Resident %d" % i)
		keys.append(&"mouse_keeper" if i == 0 else &"mouse_fieldworker")
	var calendar := CalendarScript.new()
	calendar.tick = tick
	var places := PlacesScript.new()
	places.set_points(Vector2(6.0, 0.0), Vector2(3.0, -3.0), Vector2(0.0, 4.0), Vector2(1.5, 4.5))
	places.add_table_seats(Vector2(3.0, -3.0), PlacesScript.SEATS_PER_TABLE)
	var kitchen := KitchenScript.new()
	## One portion a diner (decision 1732's `portion_halves` 2): this suite's scenarios are about other mechanics, sized
	## for one portion each; the portion and a half and its seconds are test_demo_balance_tuning.gd's.
	kitchen.portion_halves = 2
	kitchen.configure(brains, names, species, keys, pantry, stores, calendar, places)
	return kitchen


func _supper_of(species: PackedStringArray, stock: Dictionary) -> int:
	"""The dish today's supper is planned as, for a village of `species` over a pantry holding `stock` (item: milli)."""
	var pantry := _pantry()
	for item: int in stock:
		assert_true(pantry.add_into(item, int(stock[item]), 0, _read), "stocked")
	var kitchen := _kitchen(species, tick_at(0, 10), pantry, StoresScript.new())
	return kitchen.plan_of(Rules.meal_key(0, Rules.MEAL_SUPPER))[0]


func _breakfast_of(species: PackedStringArray, stock: Dictionary) -> int:
	"""The dish tomorrow's breakfast is planned as (the kitchen opened at 10:00, so breakfast is the next day's)."""
	var pantry := _pantry()
	for item: int in stock:
		assert_true(pantry.add_into(item, int(stock[item]), 0, _read), "stocked")
	var kitchen := _kitchen(species, tick_at(0, 10), pantry, StoresScript.new())
	return kitchen.plan_of(Rules.meal_key(1, Rules.MEAL_BREAKFAST))[0]


static func _declared_category(dish: int, k: int) -> int:
	"""Input `k`'s category as the book declares it (Book.NEEDS for an item another lane defines), so the checks hold
	before and after that lane lands it."""
	return int((Book.DISHES[dish]["inputs"] as Array)[k][0])


static func _lot_of(pantry: PantryScript, item: int) -> int:
	"""The first live lot row of `item` (-1: none)."""
	for lot: int in PantryScript.MAX_LOTS:
		if pantry.lot_serial(lot) != 0 and pantry.lot_item(lot) == item:
			return lot
	return -1


static func _many(species: String, n: int) -> PackedStringArray:
	"""`n` residents of one species."""
	var out := PackedStringArray()
	for i in n:
		out.append(species)
	return out


# --- the book --------------------------------------------------------------------------------------

func test_every_dish_is_cooked_as_its_gdd_row_exactly() -> void:
	"""Each dish carries its §5.7 row's inputs (categories and milli-U), water, portions, NP, WU and shelf exactly."""
	assert_equal(Rules.DISH_COUNT, Book.DISHES.size(), "a column per row")
	assert_equal(Rules.DISH_COUNT, 20, "twenty dishes: eight (0601), eleven (0603) and the feast's nut loaf (0682, 0902)")
	assert_equal(GDD_ROWS.keys(), Book.ADOPTED_ROWS, "the adopted rows are the ones checked here")
	for dish: int in Rules.DISH_COUNT:
		if Rules.ROW_ADOPTED[dish] == 0:
			continue
		var row: Array = GDD_ROWS[Rules.GDD_ROWS[dish]]
		var inputs: Array = row[0]
		assert_equal(Rules.INPUT_N[dish], inputs.size(), "%s: its inputs" % Rules.DISH_NAMES[dish])
		for k: int in inputs.size():
			assert_equal([_declared_category(dish, k), Rules.input_milli(dish, k)], inputs[k],
				"%s input %d" % [Rules.DISH_NAMES[dish], k])
		assert_equal([Rules.WATER_MILLI[dish], Rules.PORTIONS_PER_BATCH[dish], Rules.NP_PER_PORTION[dish],
			Rules.WORK_MWU[dish], Rules.SHELF_HOURS[dish]], row.slice(1), Rules.DISH_NAMES[dish])
	assert_equal(Rules.WOOD_MILLI_PER_BATCH, 100, "every batch burns 0.1 U of wood (BAL-SUPPLY-004)")
	assert_equal(Rules.batch_ticks(Rules.DISH_BEAN_HOTPOT), 250, "20 WU at 80 milli-WU a tick")


func test_every_dish_is_a_library_production_candidate() -> void:
	"""Each library id resolves exactly once in the content library's recipes, as a production candidate (LIB-008: its
	numbers are §5.7's); the hotpot alone is the GDD's own dish."""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPES_PATH))
	assert_true(parsed is Dictionary, "the library's recipes load")
	var found: Dictionary = {}
	for recipe: Dictionary in (parsed as Dictionary)["recipes"]:
		if Rules.LIBRARY_IDS.has(String(recipe["id"])):
			found[recipe["id"]] = bool(recipe["production_candidate"])
	for dish: int in Rules.DISH_COUNT:
		var id: String = Rules.LIBRARY_IDS[dish]
		if dish == Rules.DISH_BEAN_HOTPOT or dish == Rules.DISH_WOODLAND_PIE:
			assert_equal(id, "", "the hotpot and the woodland pie are the GDD's")
			continue
		assert_true(found.get(id, false), "%s is a production candidate" % id)


func test_every_dish_has_an_input_and_a_meal() -> void:
	"""No row of the book is empty (a dish of no inputs would make endless batches) or for no meal; the other meal's
	dish of no dish is none."""
	for dish: int in Rules.DISH_COUNT:
		assert_true(Rules.INPUT_N[dish] >= 1, "%s has an input" % Rules.DISH_NAMES[dish])
		assert_true(Rules.is_meal_dish(dish) or Rules.DISH_MEAL[dish] == Book.DRINK or Rules.is_occasion_dish(dish),
			"a meal, a drink or an occasion's course")
	assert_equal(Rules.other(Rules.NO_DISH), Rules.NO_DISH, "no dish")


func test_every_pantry_category_fits_the_estimate() -> void:
	"""The ready-food estimate pools food by category: every pantry item's category is below CATEGORY_COUNT, counted from
	the catalog (a lane adding a category is counted, never written past the pool)."""
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		assert_true(Catalog.category_of(item) >= 0 and Catalog.category_of(item) < Rules.CATEGORY_COUNT,
			"%s's category fits" % Catalog.ITEM_KEYS[item])
	assert_true(Rules.CATEGORY_COUNT >= Rules.CATEGORY_WORDS.size(), "at least the named ones")


func test_inputs_are_the_demos_own_produce_and_never_overlap() -> void:
	"""Every input's items are of its category and are things the demo grows or catches; a dish's inputs never share an
	item (so no food counts twice); keys are unique."""
	var keys: Dictionary = {}
	for dish: int in Rules.DISH_COUNT:
		assert_false(keys.has(Rules.DISH_KEYS[dish]), "unique key %s" % Rules.DISH_KEYS[dish])
		keys[Rules.DISH_KEYS[dish]] = true
		for item: int in Catalog.PANTRY_ITEM_COUNT:
			var k: int = Rules.input_of(dish, item)
			if k >= 0:
				assert_true(Rules.input_categories(dish, k) & (1 << Catalog.category_of(item)) != 0,
					"%s takes %s in its categories" % [Rules.DISH_NAMES[dish], Catalog.ITEM_KEYS[item]])
				var takers: int = 0
				for j: int in Rules.INPUT_N[dish]:
					takers += 1 if TakesScript.matches(Rules.input_selector(dish, j), item) else 0
				assert_equal(takers, 1, "one input takes %s" % Catalog.ITEM_KEYS[item])
	assert_true(Catalog.PANTRY_ITEM_COUNT <= TakesScript.MASK_BITS, "every pantry item fits a selector mask")


func test_a_dish_takes_only_its_own_ingredients() -> void:
	"""Wild-beetroot soup takes beetroot and onion, never parsnip; the vole stew carrot, onion and turnip; Poached dace
	only dace (and any roots); the barleymeal barley and oats, never wheat; the plain dishes their whole category."""
	assert_true(Rules.is_input(Rules.DISH_BEETROOT_SOUP, BEETROOT) and Rules.is_input(Rules.DISH_BEETROOT_SOUP, ONION),
		"beetroot and onion")
	assert_false(Rules.is_input(Rules.DISH_BEETROOT_SOUP, 4), "not parsnip")
	assert_equal(Rules.items_text(Rules.input_selector(Rules.DISH_VOLE_STEW, 0)), "turnip, carrot or onion", "the stew")
	assert_equal([Rules.input_of(Rules.DISH_POACHED_DACE, DACE), Rules.input_of(Rules.DISH_POACHED_DACE, TROUT),
		Rules.input_of(Rules.DISH_POACHED_DACE, RADISH)], [0, -1, 1], "dace, not trout; any roots second")
	assert_false(Rules.is_input(Rules.DISH_BARLEYMEAL, WHEAT), "no wheat in barleymeal")
	assert_true(Rules.is_input(Rules.DISH_PORRIDGE, WHEAT), "the plain porridge takes any grain")
	assert_equal(Rules.PLAIN.slice(0, 8), PackedByteArray([1, 1, 1, 0, 0, 0, 0, 1]), "the plain dishes of 0601")
	assert_equal(Rules.batch_food_milli(Rules.DISH_BEAN_HOTPOT), 4000, "beans 2 + greens 2")
	assert_false(Rules.is_input(Rules.DISH_SOUP, Catalog.NO_ITEM), "no item is no input")


func test_selectors_match_categories_items_and_nothing_else() -> void:
	"""ANY takes every item; a category its row; an item mask exactly its items; no item is never taken."""
	var mask: int = TakesScript.items_selector(PackedInt32Array([BEETROOT, ONION]))
	assert_true(TakesScript.matches(TakesScript.ANY, CABBAGE), "any")
	assert_true(TakesScript.matches(FarmingScript.CROP_ROOTS, CARROT), "a category")
	assert_false(TakesScript.matches(FarmingScript.CROP_ROOTS, CABBAGE), "not another's")
	assert_equal([TakesScript.matches(mask, BEETROOT), TakesScript.matches(mask, ONION), TakesScript.matches(mask, CARROT)],
		[true, true, false], "a mask takes exactly its items")
	assert_false(TakesScript.matches(TakesScript.ANY, Catalog.NO_ITEM), "no item")
	assert_false(TakesScript.matches(mask, 40), "past the mask")


func test_recipes_and_freshness_rank_as_the_gdd_says() -> void:
	"""Variety is per §5.7 recipe (two porridges are one recipe); fresh fish keeps 48 h, greens 144, roots 240, grain 720;
	the other meal's plain dish is porridge for supper's and the soup for breakfast's."""
	assert_true(Rules.same_recipe(Rules.DISH_PORRIDGE, Rules.DISH_BARLEYMEAL), "one recipe")
	assert_false(Rules.same_recipe(Rules.DISH_SOUP, Rules.DISH_FISH_STEW), "two recipes")
	assert_false(Rules.same_recipe(Rules.NO_DISH, Rules.DISH_SOUP), "no dish")
	assert_equal(Rules.ROW_COUNT, 16, "four §5.7 rows of 0601, woodland_pie, ten drafts and nut_loaf")
	assert_equal(Rules.FRESHEST_HOURS.slice(0, 8), PackedInt32Array([720, 240, 48, 720, 240, 240, 48, 144]),
		"freshest input")
	assert_true(Rules.fresher_first(Rules.DISH_FISH_STEW, Rules.DISH_BEAN_HOTPOT) < 0, "fish before greens")
	assert_true(Rules.fresher_first(Rules.DISH_BEAN_HOTPOT, Rules.DISH_SOUP) < 0, "greens before roots")
	assert_equal(Rules.fresher_first(Rules.DISH_SOUP, Rules.DISH_VOLE_STEW), 0, "roots alike")
	assert_equal([Rules.other(Rules.DISH_BEAN_HOTPOT), Rules.other(Rules.DISH_BARLEYMEAL)],
		[Rules.DISH_PORRIDGE, Rules.DISH_SOUP], "the other meal's plain dish")
	assert_equal([Rules.category_shelf_hours(Catalog.CAT_FLOUR), Rules.category_shelf_hours(99)], [240, 0], "goods")


# --- the favourites --------------------------------------------------------------------------------

func test_the_favourites_table_names_real_species_and_dishes() -> void:
	"""Every entry names a species of the table and a dish of the book, with a taste and a basis; a species is found in
	any case; only the beaver dislikes anything."""
	for entry: Array in Tastes.ENTRIES:
		assert_true(Tastes.SPECIES.has(entry[0]), "species %s" % entry[0])
		assert_true(Rules.DISH_KEYS.has(entry[1]), "dish %s" % entry[1])
		assert_true(int(entry[2]) == Tastes.LIKE or int(entry[2]) == Tastes.DISLIKE, "a taste")
		assert_true(entry[3] == Tastes.LIBRARY or entry[3] == Tastes.PROPOSAL, "a basis")
	assert_equal(Tastes.species_row("Badger"), Tastes.SPECIES.find(&"badger"), "any case")
	assert_equal(Tastes.species_row("hare"), Tastes.NONE, "no tastes")
	assert_equal(Tastes.taste(Tastes.species_row("mole"), &"soup"), Tastes.LIKE, "Togget's soup: a mole's")
	assert_equal(Tastes.basis_of(Tastes.species_row("mole"), &"soup"), Tastes.LIBRARY, "from the library")
	assert_equal([Tastes.taste(Tastes.species_row("mole"), &"root_pie"), Tastes.basis_of(Tastes.species_row("mole"),
		&"root_pie")], [Tastes.LIKE, Tastes.LIBRARY], "moles like their deeper'n'ever pie (Brendan's ruling on 0603)")
	assert_equal(Tastes.species_with(&"root_pie", Tastes.LIKE), PackedStringArray(["mole"]), "moles alone")
	assert_equal(Tastes.basis_of(Tastes.species_row("otter"), &"poached_dace"), Tastes.PROPOSAL, "a proposal")
	assert_equal(Tastes.basis_of(Tastes.species_row("otter"), &"soup"), "", "none")
	assert_equal(Tastes.taste(Tastes.NONE, &"soup"), 0, "no species")
	assert_equal(Tastes.species_with(&"poached_dace", Tastes.DISLIKE), PackedStringArray(["beaver"]), "the beaver")
	assert_equal(Tastes.species_with(&"beetroot_soup", Tastes.LIKE), PackedStringArray(["mole", "badger"]), "likers")


func test_eating_a_favourite_is_noted_and_counted_and_nothing_else() -> void:
	"""A mole eating Togget's soup: noted, counted -- and its NP is the portion's alone (no favourite bonus); the next
	meal clears the note; raw food and a missed meal never are favourites."""
	var fed := FedScript.new()
	fed.configure(PackedStringArray(["mole", "beaver", "Otter"]))
	fed.hunger[0] = 1000
	fed.ate_meal(0, 0, Rules.DISH_SOUP, 0)
	assert_equal([fed.last_favourite[0], fed.favourites_eaten[0], fed.hunger[0]], [1, 1, 1000 + 1800],
		"noted, counted, 1800 NP and no more")
	fed.ate_meal(0, 1, Rules.DISH_FISH_STEW, 0)
	assert_equal([fed.last_favourite[0], fed.favourites_eaten[0]], [0, 1], "cleared by a dish it does not like")
	fed.ate_meal(0, 2, Rules.DISH_BEETROOT_SOUP, 0)
	fed.ate_raw(0, 3, 800)
	assert_equal(fed.last_favourite[0], 0, "raw food is no favourite")
	fed.ate_meal(0, 4, Rules.DISH_SOUP, 0)
	fed.missed(0, 5)
	assert_equal([fed.last_favourite[0], fed.favourites_eaten[0]], [0, 3], "a missed meal neither")
	assert_equal([fed.taste_of(1, Rules.DISH_POACHED_DACE), fed.taste_of(2, Rules.DISH_POACHED_DACE),
		fed.taste_of(0, Rules.NO_DISH)], [Tastes.DISLIKE, Tastes.LIKE, 0], "the beaver, the otter, no dish")
	assert_equal([fed.village_taste(Rules.DISH_POACHED_DACE), fed.likers_of(Rules.DISH_POACHED_DACE)], [0, 1],
		"one like, one dislike")
	var two := FedScript.new()
	two.configure(PackedStringArray(["beaver", "mole"]))
	assert_equal(two.taste_of(0, Rules.DISH_COUNT + 1), 0, "past the book: none (not the next resident's)")


func test_variety_counts_recipes_not_dishes() -> void:
	"""§5.7: "Ingredient differences inside the same recipe do not fake variety" -- porridge then barleymeal porridge is
	the porridge recipe twice; the soups three are root_stew thrice."""
	var fed := FedScript.new()
	fed.configure(PackedStringArray(["mouse"]))
	fed.ate_meal(0, 0, Rules.DISH_PORRIDGE, 0)
	fed.ate_meal(0, 1, Rules.DISH_SOUP, 0)
	fed.ate_meal(0, 2, Rules.DISH_BARLEYMEAL, 0)
	fed.ate_meal(0, 3, Rules.DISH_BEETROOT_SOUP, 0)
	fed.ate_meal(0, 4, Rules.DISH_VOLE_STEW, 0)
	assert_equal([fed.repeats_of(0, Rules.DISH_PORRIDGE), fed.repeats_of(0, Rules.DISH_SOUP),
		fed.repeats_of(0, Rules.DISH_BEAN_HOTPOT)], [2, 3, 0], "by recipe")
	assert_equal(fed.monotony[0], Rules.MONOTONY_LOW, "the fifth meal's -200: the root stew's third in six")


# --- the choice ------------------------------------------------------------------------------------

func test_supper_picks_the_food_that_keeps_least_long() -> void:
	"""Fresh fish (48 h) before greens (144 h) before roots (240 h), whatever the village likes: the fish stew over the
	hotpot over a soup; a meal with only roots is a soup."""
	var everything: Dictionary = {TROUT: 4000, PEA: 4000, CABBAGE: 4000, CARROT: 6000}
	assert_equal(_supper_of(_many("beaver", 3), everything), Rules.DISH_BAKED_FISH,
		"fish first, even for beavers -- the fish dish they do not dislike (E2's baked fish)")
	assert_equal(_supper_of(_many("mouse", 3), {PEA: 4000, CABBAGE: 4000, CARROT: 6000}), Rules.DISH_BEAN_HOTPOT,
		"greens before roots")
	assert_equal(_supper_of(_many("mouse", 3), {CARROT: 6000}), Rules.DISH_SOUP, "roots: the soup")


func test_among_alike_the_village_s_favourite_wins_then_the_book_s_order() -> void:
	"""Roots alike: squirrels get the vole stew from carrots, moles and badgers the beetroot soup from beetroot, mice
	(who like neither) Togget's soup; a radish feeds only Togget's. Fish alike: otters get poached dace from dace,
	beavers (who dislike both) the plain stew."""
	assert_equal(_supper_of(_many("squirrel", 2), {CARROT: 6000}), Rules.DISH_VOLE_STEW, "squirrels")
	assert_equal(_supper_of(PackedStringArray(["mole", "badger"]), {BEETROOT: 6000, CARROT: 6000}),
		Rules.DISH_BEETROOT_SOUP, "moles and badgers")
	assert_equal(_supper_of(_many("mouse", 2), {BEETROOT: 6000, CARROT: 6000}), Rules.DISH_SOUP, "mice: the book's order")
	assert_equal(_supper_of(_many("squirrel", 2), {RADISH: 6000}), Rules.DISH_SOUP, "radish: only Togget's")
	assert_equal(_supper_of(_many("otter", 2), {DACE: 4000, CARROT: 4000}), Rules.DISH_POACHED_DACE, "otters")
	assert_equal(_supper_of(PackedStringArray(["otter", "beaver", "beaver"]), {DACE: 4000, CARROT: 4000}),
		Rules.DISH_BAKED_FISH, "an otter and two beavers: the baked fish's 0 beats the dace's -1 and the stew's -2")
	assert_equal(_supper_of(_many("beaver", 2), {DACE: 4000, CARROT: 4000}), Rules.DISH_BAKED_FISH,
		"beavers dislike both stews: the baked fish")
	assert_equal(_supper_of(_many("otter", 2), {TROUT: 4000, CARROT: 4000}), Rules.DISH_FISH_STEW, "trout: no dace")


func test_a_dish_that_feeds_the_whole_meal_comes_first() -> void:
	"""Four moles and badgers like the beetroot soup, but 3 U of beetroot is one batch (2 portions): Togget's soup from
	the carrots feeds all four, so it is cooked; with beetroot for everyone, the favourite. Six residents and 2 U of
	fresh fish (3 portions): the soup from the roots, not a short fish stew; with too few roots for the soup either,
	the fish stew after all (the fresher of two short meals)."""
	var four := PackedStringArray(["mole", "badger", "mole", "badger"])
	assert_equal(_supper_of(four, {BEETROOT: 3000, CARROT: 9000}), Rules.DISH_SOUP, "the soup feeds everyone")
	assert_equal(_supper_of(four, {BEETROOT: 6000, CARROT: 9000}), Rules.DISH_BEETROOT_SOUP, "enough beetroot")
	assert_equal(_supper_of(_many("otter", 6), {DACE: 2000, CARROT: 12000}), Rules.DISH_SOUP, "fish for three of six")
	assert_equal(_supper_of(_many("otter", 6), {DACE: 2000, CARROT: 3000}), Rules.DISH_POACHED_DACE,
		"neither feeds six: the fish, fresher")


func test_leftovers_count_toward_feeding_the_whole_meal() -> void:
	"""Four moles and badgers, 3 U of beetroot (2 portions) and carrots: alone, the soup feeds all four; with two good
	portions left from breakfast, two are wanted, so the beetroot soup feeds the meal and is cooked."""
	var pantry := _pantry()
	var kitchen := _kitchen(PackedStringArray(["mole", "badger", "mole", "badger"]), tick_at(0, 10), pantry,
		StoresScript.new())
	var key: int = Rules.meal_key(0, Rules.MEAL_SUPPER)
	pantry.add_into(BEETROOT, 3000, 0, _read)
	pantry.add_into(CARROT, 9000, 0, _read)
	kitchen._plan(kitchen.hour_index())
	assert_equal(kitchen.plan_of(key)[0], Rules.DISH_SOUP, "no leftovers: the soup")
	var fresh := _pantry()
	var with_leftovers := _kitchen(PackedStringArray(["mole", "badger", "mole", "badger"]), tick_at(0, 10), fresh,
		StoresScript.new())
	with_leftovers.store.add(Rules.DISH_PORRIDGE, 2, Rules.meal_key(0, Rules.MEAL_BREAKFAST))
	fresh.add_into(BEETROOT, 3000, 0, _read)
	fresh.add_into(CARROT, 9000, 0, _read)
	with_leftovers._plan(with_leftovers.hour_index())
	assert_equal(with_leftovers.plan_of(key)[0], Rules.DISH_BEETROOT_SOUP, "two leftovers: the favourite feeds the rest")


func test_the_cook_card_counts_free_food_too() -> void:
	"""The Cook decision's have counts the meal's reservation and the food still free: 2 U of peas held, 4 U more free."""
	var pantry := _pantry()
	pantry.add_into(PEA, 2000, 0, _read)
	pantry.add_into(CABBAGE, 2000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 1), tick_at(0, 10), pantry, StoresScript.new())
	pantry.add_into(PEA, 4000, 0, _read)
	var d: KitchenScript.Decision = kitchen.decide_meal()
	assert_equal(d.dish, Rules.DISH_BEAN_HOTPOT, "the hotpot")
	assert_equal([d.input_have[0], d.input_need[0], d.input_have[1]], [6000, 2000, 2000], "held and free")


func test_breakfast_picks_among_the_porridges_and_falls_back_to_supper_s() -> void:
	"""Squirrels like the barleymeal: from barley or oats it is theirs, from wheat the plain porridge; with no grain at
	all, breakfast is a supper dish (ruling 1's other dish) -- the best of them; with nothing, the porridge, waiting."""
	assert_equal(_breakfast_of(_many("squirrel", 2), {OATS: 4000}), Rules.DISH_BARLEYMEAL, "oats: barleymeal")
	assert_equal(_breakfast_of(_many("squirrel", 2), {WHEAT: 4000}), Rules.DISH_PORRIDGE, "wheat: the plain porridge")
	assert_equal(_breakfast_of(_many("mouse", 2), {BARLEY: 4000}), Rules.DISH_PORRIDGE, "mice: the book's order")
	assert_equal(_breakfast_of(PackedStringArray(["mole", "badger"]), {BEETROOT: 6000, CARROT: 6000}),
		Rules.DISH_BEETROOT_SOUP, "no grain: the village's favourite supper dish")
	assert_equal(_breakfast_of(_many("mole", 2), {}), Rules.DISH_PORRIDGE, "nothing: the porridge, waiting")


func test_the_choice_is_deterministic_and_reads_the_whole_village() -> void:
	"""The same stores and village give the same dish every time, whatever the order the residents are listed in."""
	var first: int = _supper_of(PackedStringArray(["squirrel", "mole", "badger", "squirrel"]), {CARROT: 6000, ONION: 6000})
	for k in 3:
		assert_equal(_supper_of(PackedStringArray(["badger", "squirrel", "squirrel", "mole"]), {ONION: 6000, CARROT: 6000}),
			first, "the same, run %d" % k)
	assert_equal(first, Rules.DISH_BEETROOT_SOUP, "2 likes each: the book's order puts the beetroot soup first")


# --- cooking the new dishes --------------------------------------------------------------------------

func test_a_hotpot_reserves_both_inputs_and_the_card_shows_each() -> void:
	"""Supper's hotpot reserves beans and greens from real lots, whole batches of both; the Cook card shows Beans and
	Greens had and needed, then water and wood; a supper short of greens says so."""
	var pantry := _pantry()
	pantry.add_into(PEA, 6000, 0, _read)
	pantry.add_into(LEEK, 4000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 3), tick_at(0, 10), pantry, StoresScript.new())
	var plan: PackedInt32Array = kitchen.plan_of(Rules.meal_key(0, Rules.MEAL_SUPPER))
	assert_equal([plan[0], plan[1], plan[3]], [Rules.DISH_BEAN_HOTPOT, 1, 1], "one batch wanted (3 portions), reserved")
	var take: int = kitchen.take_of(Rules.meal_key(0, Rules.MEAL_SUPPER))
	assert_equal([kitchen.takes.live_milli(pantry, take, -1, FarmingScript.CROP_BEANS),
		kitchen.takes.live_milli(pantry, take, -1, FarmingScript.CROP_CABBAGE)], [2000, 2000], "2 U of each, no more")
	var card := CardScript.new()
	kitchen.preview_cook_into(card, PackedInt32Array())
	var text: String = card.text()
	assert_true(text.contains("Beans") and text.contains("Greens"), "both inputs on the card: " + text)
	var short := _pantry()
	short.add_into(PEA, 6000, 0, _read)
	short.add_into(CARROT, 1000, 0, _read)
	var bare := _kitchen(_many("mouse", 3), tick_at(0, 16), short, StoresScript.new())
	assert_equal(bare.plan_of(Rules.meal_key(0, Rules.MEAL_SUPPER))[0], Rules.DISH_SOUP, "no greens: no hotpot")


func test_a_meal_of_two_inputs_holds_only_whole_batches_of_both() -> void:
	"""Nine residents want three hotpot batches; 6 U of peas but 2 U of greens make one: the meal holds 2 U of each, the
	other 4 U of peas stay free (no other dish can feed nine, so the short hotpot is still the fresher choice)."""
	var pantry := _pantry()
	pantry.add_into(PEA, 6000, 0, _read)
	pantry.add_into(CABBAGE, 2000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 9), tick_at(0, 10), pantry, StoresScript.new())
	var key: int = Rules.meal_key(0, Rules.MEAL_SUPPER)
	assert_equal(kitchen.plan_of(key)[0], Rules.DISH_BEAN_HOTPOT, "the hotpot")
	var take: int = kitchen.take_of(key)
	assert_equal([kitchen.takes.live_milli(pantry, take, -1, FarmingScript.CROP_BEANS),
		kitchen.takes.live_milli(pantry, take, -1, FarmingScript.CROP_CABBAGE)], [2000, 2000], "one batch of each")
	assert_equal(kitchen.takes.free_milli_of_crop(pantry, FarmingScript.CROP_BEANS), 4000, "the rest of the peas free")


func test_a_batch_missing_part_of_an_input_takes_nothing() -> void:
	"""The hotpot's food at the kitchen, then half its greens taken from their lot by someone else (the lot lives on): the
	batch cannot start -- nothing withdrawn, nothing counted consumed -- and with the first input gone instead, the same
	(all inputs or none; the review's H1)."""
	var pantry := _pantry()
	pantry.add_into(PEA, 2000, 0, _read)
	pantry.add_into(CABBAGE, 2000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 1), tick_at(0, 15), pantry, StoresScript.new())
	var key: int = Rules.meal_key(0, Rules.MEAL_SUPPER)
	var take: int = kitchen.take_of(key)
	kitchen.takes.pick_up(pantry, take, kitchen.takes.store_to_fetch(pantry, take))
	kitchen.takes.put_down(take)
	var lot: int = _lot_of(pantry, CABBAGE)
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 1000, _read), "half the greens gone")
	assert_false(kitchen._consume_batch_food(kitchen._slot_index_of(key), Rules.DISH_BEAN_HOTPOT), "no batch")
	assert_equal([pantry.milli_of(PEA), pantry.milli_of(CABBAGE), kitchen.consumed_food_milli], [2000, 1000, 0],
		"the peas and the greens left untouched, nothing counted")
	var peas: int = _lot_of(pantry, PEA)
	assert_true(pantry.withdraw_into(peas, pantry.lot_serial(peas), 1000, _read), "half the peas gone too")
	pantry.add_into(CABBAGE, 1000, 0, _read)
	assert_false(kitchen._consume_batch_food(kitchen._slot_index_of(key), Rules.DISH_BEAN_HOTPOT), "still no batch")
	assert_equal([pantry.milli_of(PEA), pantry.milli_of(CABBAGE)], [1000, 2000], "nothing withdrawn")


func test_a_variant_cooks_from_its_own_ingredients_only() -> void:
	"""A batch of the beetroot soup withdraws 3 U of beetroot and onion and leaves the carrots: real lots, the books
	balancing (food consumed = the pantry's loss)."""
	var pantry := _pantry()
	pantry.add_into(CARROT, 3000, 0, _read)
	pantry.add_into(BEETROOT, 3000, 0, _read)
	var stores := StoresScript.new()
	stores.add_water(10000)
	var kitchen := _kitchen(PackedStringArray(["badger"]), tick_at(0, 15), pantry, stores)
	var key: int = Rules.meal_key(0, Rules.MEAL_SUPPER)
	assert_equal(kitchen.plan_of(key)[0], Rules.DISH_BEETROOT_SOUP, "the badger's favourite")
	var take: int = kitchen.take_of(key)
	assert_equal([kitchen.takes.live_milli(pantry, take, -1, TakesScript.items_selector(PackedInt32Array([CARROT]))),
		kitchen.takes.live_milli(pantry, take, -1, TakesScript.items_selector(PackedInt32Array([BEETROOT])))], [0, 3000],
		"it holds the beetroot, not the carrots stocked first (the first lot)")
	kitchen.takes.pick_up(pantry, take, kitchen.takes.store_to_fetch(pantry, take))
	kitchen.takes.put_down(take)
	assert_true(kitchen._consume_batch_food(kitchen._slot_index_of(key), Rules.DISH_BEETROOT_SOUP), "a batch withdrawn")
	assert_equal([pantry.milli_of(BEETROOT), pantry.milli_of(CARROT)], [0, 3000], "beetroot taken, carrots left")


func test_a_short_second_input_is_refused_in_words() -> void:
	"""With the hotpot planned and its greens gone (and no roots), the Cook order refuses: "the pantry has 0 U of greens or
	roots for bean hotpot; a batch takes 2.0 U" (decision 1735: its second input is greens or roots)."""
	var pantry := _pantry()
	pantry.add_into(PEA, 2000, 0, _read)
	pantry.add_into(CABBAGE, 2000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 1), tick_at(0, 10), pantry, StoresScript.new())
	var take: int = kitchen.take_of(Rules.meal_key(0, Rules.MEAL_SUPPER))
	kitchen.takes.release_milli(pantry, take, 2000, kitchen.hour_index(), FarmingScript.CROP_CABBAGE)
	var lot: int = _lot_of(pantry, CABBAGE)
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 2000, _read), "the greens eaten elsewhere")
	var d: KitchenScript.Decision = kitchen.decide_meal()
	assert_equal(d.code, KitchenScript.NO_FOOD, "refused")
	assert_equal(d.reason, Words.no_side_reason(Rules.DISH_BEAN_HOTPOT, 1, 0), "its words")
	assert_true(d.reason.contains("0 U of greens or roots for bean hotpot; a batch takes 2.0 U"), d.reason)


func test_ready_food_counts_the_hotpot_and_never_a_variant_twice() -> void:
	"""Beans 4 + greens 4 make 2 hotpot batches (6 portions); 6 U of beetroot 2 soup batches (4), counted once though
	three dishes could cook them; the wood bounds it; the scratch columns are reused, not regrown."""
	var pantry := _pantry()
	pantry.add_into(PEA, 4000, 0, _read)
	pantry.add_into(CABBAGE, 4000, 0, _read)
	pantry.add_into(BEETROOT, 6000, 0, _read)
	var stores := StoresScript.new()
	var kitchen := _kitchen(_many("mole", 2), tick_at(0, 6), pantry, stores)
	assert_equal([kitchen.cookable_batches(), kitchen.cookable_portions()], [4, 10], "2 hotpots + 2 soups")
	stores.wood_milli_u = 300
	assert_equal(kitchen.cookable_batches(), 3, "three batches of wood: the hotpots first")
	assert_equal(kitchen.cookable_portions(), 8, "3 + 3 + 2")
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k in 200:
		kitchen.days_of_meals_milli()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object made per call")
	assert_equal([kitchen._pool.size(), kitchen._estimated.size()], [Rules.CATEGORY_WORDS.size(), Rules.DISH_COUNT],
		"the scratch columns keep their size")


# --- what the player sees ------------------------------------------------------------------------------

func test_the_new_dishes_are_in_the_guide_the_tab_and_the_card() -> void:
	"""The field guide has an entry per dish, with who likes it; the Kitchen tab's plan line says how many like the
	dish; a resident's card marks a favourite last meal."""
	var guide := FieldGuideScript.new()
	for dish: int in Rules.DISH_COUNT:
		assert_true(guide.index_of(FieldGuideScript.DISH_IDS[dish]) >= 0, "an entry for %s" % Rules.DISH_NAMES[dish])
	var beet: FieldGuideScript.Entry = guide.entry(guide.index_of(&"dish_beetroot_soup"))
	assert_true(beet.uses.contains("A favourite of moles and badgers."), beet.uses)
	var dace: FieldGuideScript.Entry = guide.entry(guide.index_of(&"dish_poached_dace"))
	assert_true(dace.uses.contains("Not liked by beavers."), dace.uses)
	var pantry := _pantry()
	pantry.add_into(BEETROOT, 6000, 0, _read)
	var kitchen := _kitchen(PackedStringArray(["mole", "badger"]), tick_at(0, 10), pantry, StoresScript.new())
	kitchen.fed.ate_meal(0, Rules.meal_key(0, Rules.MEAL_BREAKFAST), Rules.DISH_BEETROOT_SOUP, 0)
	assert_true(kitchen.fed_text(0, true).contains("Last meal: breakfast, beetroot soup — a favourite"), kitchen.fed_text(0, true))
	assert_equal(kitchen.taste_of_village(Rules.DISH_BEETROOT_SOUP), 2, "both like it")
	assert_equal(kitchen.taste_of_village(Rules.NO_DISH), 0, "no dish")
	var tab := TabScript.new()
	tab.configure(kitchen, func() -> PackedInt32Array: return PackedInt32Array(), Callable())
	assert_true(tab.meals_text().contains("Supper, day 1 — Wild-beetroot soup (liked by 2):"), tab.meals_text())
	tab.free()


# --- the Recipes tab's index (decision 0602) -------------------------------------------------------------

func test_the_recipe_index_lists_the_catch_dried_fish_and_flour() -> void:
	"""Rebuilt with every pantry item: trout, dace, perch and whitefish feed library dishes; salmon and carp are not in
	the library's pantry; dried fish is the library's dried trout; flour its flours of wheat, barley and oats. An entry
	whose key is not the catalog's is refused."""
	var recipes := RecipesScript.new()
	assert_true(recipes.load_index(), "loaded")
	assert_true(recipes.direct_count(TROUT) > 0 and recipes.direct_count(DACE) > 0, "trout and dace feed dishes")
	assert_true(recipes.dishes_of(DACE).has("Poached dace"), "the kitchen's own poached dace is there")
	assert_equal([recipes.in_library(18), recipes.in_library(20)], [false, false], "salmon and carp: not in the library")
	assert_equal(recipes.direct_count(18), 0, "no dishes for salmon")
	assert_true(recipes.in_library(Catalog.ITEM_DRIED_FISH) and recipes.in_library(Catalog.ITEM_FLOUR), "goods are")
	assert_true(recipes.direct_count(Catalog.ITEM_FLOUR) > recipes.direct_count(WHEAT), "flour feeds the baking")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RecipesScript.INDEX_PATH))
	assert_equal(index["schema"], "demo_pantry_index_v2", "the goods schema")
	var renamed: Dictionary = index.duplicate(true)
	((renamed["items"] as Array)[TROUT] as Dictionary)["item_key"] = "pike"
	var path: String = "user://dishes_index_renamed.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(renamed))
	file.close()
	assert_false(RecipesScript.new().load_index(path), "a goods entry out of the catalog's order")
	DirAccess.remove_absolute(path)


func test_the_recipes_tab_lists_every_pantry_item() -> void:
	"""The Pantry's Recipes tab has a row for every pantry item -- the crops, then the catch, dried fish and flour -- and
	salmon says it is not in the library."""
	var recipes := RecipesScript.new()
	recipes.load_index()
	var panel := PantryPanelScript.new()
	panel.configure(FarmSimScript.new(), _pantry(), recipes)
	panel.visible = true
	panel.show_tab(PantryPanelScript.TAB_RECIPES)
	assert_equal(panel.item_button(Catalog.ITEM_FLOUR).text, "Flour · none in store", "the last row: flour")
	panel.select_item(DACE)
	assert_true(panel.dish_title().begins_with("Dace feeds "), panel.dish_title())
	panel.select_item(18)
	assert_equal(panel.dish_title(), PantryPanelScript.NOT_IN_LIBRARY % "Salmon", "salmon")
	panel.free()


# --- the families Brendan directed (decision 0603, DEC-045) -------------------------------------------------

## The drafted rows, as decision 0603's table puts them for Brendan: inputs (category, milli-U), water, portions, NP, WU,
## shelf, meal. Changing one here is changing the draft he confirms.
const DRAFT_ROWS: Dictionary = {
	"oatcake": [[[FarmingScript.CROP_GRAIN, 2000]], 1000, 2, 1800, 14000, 72, Rules.MEAL_BREAKFAST],
	"farl": [[[FarmingScript.CROP_GRAIN, 2000]], 1000, 2, 1800, 14000, 48, Rules.MEAL_BREAKFAST],
	"hardtack": [[[Catalog.CAT_FLOUR, 2000]], 500, 2, 1800, 16000, 480, Rules.MEAL_BREAKFAST],
	"salad": [[[FarmingScript.CROP_CABBAGE, 2000], [FarmingScript.CROP_ROOTS, 1000]], 500, 2, 1400, 6000, 12,
		Rules.MEAL_SUPPER],
	"baked_fish": [[[Catalog.CAT_FISH, 2000]], 500, 2, 1900, 14000, 24, Rules.MEAL_SUPPER],
	"fish_biscuit_soup": [[[Catalog.CAT_DRIED_FISH, 1000], [Catalog.CAT_FLOUR, 1000], [FarmingScript.CROP_ROOTS, 1000]],
		2000, 3, 2000, 20000, 24, Rules.MEAL_SUPPER],
	"pasty": [[[Catalog.CAT_FLOUR, 2000], [FarmingScript.CROP_ROOTS, 1000], [FarmingScript.CROP_CABBAGE, 1000],
		[Book.NEEDS, 500]], 500, 3, 2200, 24000, 48, Rules.MEAL_SUPPER],
	"root_pie": [[[Catalog.CAT_FLOUR, 2000], [FarmingScript.CROP_ROOTS, 2000], [FarmingScript.CROP_ROOTS, 1000],
		[Book.NEEDS, 500]], 500, 4, 2300, 32000, 48, Rules.MEAL_SUPPER],
	"scones": [[[Catalog.CAT_FLOUR, 2000], [Book.NEEDS, 500]], 1000, 3, 1800, 20000, 48, Rules.MEAL_BREAKFAST],
	"cordial": [[[Book.NEEDS, 2000], [Catalog.CAT_HONEY, 500]], 2000, 4, 500, 10000, 240, Book.DRINK],
}


func test_the_drafted_rows_are_decision_0603_s_table() -> void:
	"""Every row not adopted by the GDD is a draft in decision 0603's table, with these numbers; every batch still
	burns 0.1 U of wood (§5.8: kitchen production)."""
	var drafts: int = 0
	for dish: int in Rules.DISH_COUNT:
		if Rules.ROW_ADOPTED[dish] == 1:
			continue
		drafts += 1
		var row: Array = DRAFT_ROWS[Rules.GDD_ROWS[dish]]
		var inputs: Array = []
		for k: int in Rules.INPUT_N[dish]:
			inputs.append([_declared_category(dish, k), Rules.input_milli(dish, k)])
		assert_equal([inputs, Rules.WATER_MILLI[dish], Rules.PORTIONS_PER_BATCH[dish], Rules.NP_PER_PORTION[dish],
			Rules.WORK_MWU[dish], Rules.SHELF_HOURS[dish], Rules.DISH_MEAL[dish]], row, Rules.DISH_NAMES[dish])
	assert_equal(drafts, DRAFT_ROWS.size(), "ten drafted rows")


func test_what_the_demo_cannot_make_waits_and_says_why() -> void:
	"""The root pie waits for potato; the foragers' nuts, mushrooms and berries are in the pantry (the library's hazelnut,
	mushroom and raspberry: decision 0902), so the pasty, the scones and the woodland pie can be had; the apiary's honey
	(decision 1601) makes the cordial cookable; everything else can be had."""
	assert_equal(Rules.DISH_WAITS[Rules.DISH_ROOT_PIE], "needs potato: grown in the fields, not yet planted in the demo",
		"root pie")
	assert_false(Book.PENDING_SOURCES.has(&"honey"), "honey has its source: the apiary")
	for dish: int in [Rules.DISH_CORDIAL, Rules.DISH_SOUP, Rules.DISH_OATCAKE, Rules.DISH_FARL, Rules.DISH_HARDTACK, Rules.DISH_SALAD,
			Rules.DISH_BAKED_FISH, Rules.DISH_BISCUIT_SOUP, Rules.DISH_PASTY, Rules.DISH_SCONES, Rules.DISH_WOODLAND_PIE,
			Rules.DISH_NUT_LOAF]:
		assert_false(Rules.waits(dish), "%s can be had" % Rules.DISH_NAMES[dish])
	assert_true(TakesScript.matches(Rules.input_selector(Rules.DISH_PASTY, 3), Catalog.ITEM_NUTS)
		and Rules.is_input(Rules.DISH_SCONES, Catalog.ITEM_NUTS), "the library's hazelnut: the foragers' nuts")
	assert_true(Rules.is_input(Rules.DISH_WOODLAND_PIE, Catalog.ITEM_MUSHROOMS), "its mushroom: their mushrooms")
	assert_true(Rules.is_input(Rules.DISH_CORDIAL, Catalog.ITEM_BERRIES), "its raspberry: their berries")
	for dish: int in Rules.DISH_COUNT:
		for input: Array in Book.DISHES[dish]["inputs"]:
			for key: Variant in input[2]:
				assert_true(Catalog.ITEM_KEYS.has(key) or Book.PENDING_SOURCES.has(key),
					"%s names an item or a pending one: %s" % [Rules.DISH_NAMES[dish], key])


func test_the_kitchen_tab_and_the_recipes_list_the_waiting_dishes() -> void:
	"""The Kitchen tab lists every waiting dish and why; the potato's Recipes lines mark the root pie waiting."""
	var kitchen := _kitchen(_many("mouse", 2), tick_at(0, 10), _pantry(), StoresScript.new())
	var text: String = kitchen.waiting_text()
	assert_true(text.begins_with("Waiting for ingredients:\n"), text)
	assert_true(text.contains(Words.waiting_line(Rules.DISH_ROOT_PIE)), Rules.DISH_NAMES[Rules.DISH_ROOT_PIE])
	assert_false(text.contains(Rules.DISH_NAMES[Rules.DISH_CORDIAL]), "the cordial has its honey (decision 1601)")
	assert_equal(text.count("\n"), 1, "one waiting dish (the foragers' items in, decision 0902; honey, 1601)")
	var potato: String = kitchen.cookable_text(Catalog.ITEM_POTATO)
	assert_true(potato.contains("Waiting (needs potato: grown in the fields, not yet planted in the demo): Turnip, potato and beetroot pie"),
		potato)
	assert_true(potato.contains("Cookable (active): Togget's vegetable soup"), "a potato is roots for the soup")
	assert_false(potato.contains("Raspberry cordial") or potato.contains("Hazelnut scones"),
		"only the dishes that take a potato")
	var tab := TabScript.new()
	tab.configure(kitchen, func() -> PackedInt32Array: return PackedInt32Array(), Callable())
	tab.refresh()
	assert_equal(tab.waiting_shown(), text, "shown on the tab")
	tab.free()


func test_the_new_dishes_that_can_be_had_are_cooked() -> void:
	"""Flour alone makes breakfast hardtack (flour keeps less than grain); dried fish, flour and 2 U of roots make
	supper the biscuit soup when the soup cannot feed four (E3); greens and a little root make the salad; fish alone
	is baked (E2); oats-only breakfast for squirrels is still their barleymeal (the oatcake waits on the book's order)."""
	assert_equal(_breakfast_of(_many("mouse", 2), {Catalog.ITEM_FLOUR: 4000, OATS: 4000}), Rules.DISH_HARDTACK, "hardtack")
	assert_equal(_supper_of(_many("mouse", 4), {Catalog.ITEM_DRIED_FISH: 2000, Catalog.ITEM_FLOUR: 2000, CARROT: 2000}),
		Rules.DISH_BISCUIT_SOUP, "the biscuit soup")
	assert_equal(_supper_of(_many("mouse", 2), {CABBAGE: 4000, CARROT: 2000}), Rules.DISH_SALAD, "the salad")
	assert_equal(_supper_of(_many("mouse", 2), {TROUT: 4000}), Rules.DISH_BAKED_FISH, "baked fish")
	assert_equal(_breakfast_of(_many("squirrel", 2), {OATS: 4000}), Rules.DISH_BARLEYMEAL, "barleymeal")
	assert_equal(_breakfast_of(_many("mouse", 2), {OATS: 4000}), Rules.DISH_PORRIDGE, "the plain porridge first")


func test_a_drink_is_never_a_meal_and_the_guide_says_what_waits() -> void:
	"""The cordial is a drink and the nut loaf an occasion's course, never planned for a meal; the guide's root pie says
	what it waits for, the potato's entry that nothing produces it yet, and flour's what cooks it now."""
	assert_false(Rules.is_meal_dish(Rules.DISH_CORDIAL), "a drink")
	for meal: int in 2:
		assert_false(Rules.serves(Rules.DISH_CORDIAL, meal, true) or Rules.serves(Rules.DISH_CORDIAL, meal, false),
			"the cordial serves no meal, its own or the other")
		assert_false(Rules.serves(Rules.DISH_ROOT_PIE, Rules.MEAL_SUPPER, meal == 0), "a waiting dish serves none")
		assert_false(Rules.serves(Rules.DISH_NUT_LOAF, meal, true) or Rules.serves(Rules.DISH_NUT_LOAF, meal, false),
			"the feast's nut loaf serves no meal")
	assert_true(Rules.serves(Rules.DISH_SALAD, Rules.MEAL_SUPPER, true), "the salad, supper's own")
	assert_true(Rules.serves(Rules.DISH_SALAD, Rules.MEAL_BREAKFAST, false), "and breakfast's fallback")
	assert_false(Rules.serves(Rules.DISH_SALAD, Rules.MEAL_BREAKFAST, true), "not breakfast's own")
	assert_true(Rules.is_meal_dish(Rules.DISH_SALAD), "a meal")
	var pantry := _pantry()
	pantry.add_into(Catalog.ITEM_HONEY, 4000, 0, _read)
	var kitchen := _kitchen(_many("mouse", 2), tick_at(0, 10), pantry, StoresScript.new())
	for key: int in kitchen.planned_keys():
		assert_true(kitchen.plan_of(key)[0] != Rules.DISH_CORDIAL, "never the cordial")
	var guide := FieldGuideScript.new()
	var pie: FieldGuideScript.Entry = guide.entry(guide.index_of(&"dish_root_pie"))
	assert_true(pie.requires.contains("Waiting: needs potato: grown in the fields, not yet planted in the demo."), pie.requires)
	var loaf: FieldGuideScript.Entry = guide.entry(guide.index_of(&"dish_nut_loaf"))
	assert_equal(loaf.summary, "Cooked for a feast", "the nut loaf's summary")
	var cordial: FieldGuideScript.Entry = guide.entry(guide.index_of(&"dish_cordial"))
	assert_equal(cordial.summary, "A drink", "the cordial's summary")
	var potato: FieldGuideScript.Entry = guide.entry(guide.index_of(&"goods_potato"))
	assert_equal(potato.summary, "Not yet in the demo", "the potato")
	var flour: FieldGuideScript.Entry = guide.entry(guide.index_of(&"goods_flour"))
	assert_true(flour.uses.contains("Haversack hardtack") and flour.uses.contains("Vegetable pasty;")
		and flour.uses.contains("Turnip, potato and beetroot pie (waiting)") and flour.uses.contains("Nutbread"), flour.uses)
	assert_true(flour.links.has(&"dish_hardtack"), "flour links its dishes")
	assert_true(potato.alternatives.contains("cook without it"), "the potato's dishes are not all waiting")
	var trout: FieldGuideScript.Entry = guide.entry(guide.index_of(&"goods_trout"))
	assert_true(trout.uses.contains("Baked fish"), "fresh fish names the baked fish (E2)")
	assert_false(cordial.here.contains("hall's tables"), "a drink is not served at the tables")
	assert_true(cordial.uses.begins_with("A drink:"), cordial.uses)
	assert_equal(Rules.raw_np_per_u(Catalog.ITEM_HONEY), 1200, "honey is raw-edible (§5.7)")


func test_the_hotpot_takes_greens_or_roots_and_ready_food_counts_it() -> void:
	"""Decision 1735 (P5 (a)): the bean hotpot's second input is greens or roots -- every greens item and every root,
	never a bean or a grain -- in words "greens or roots"; the hotpot stays a plain dish, and Ready food counts beans with
	roots as hotpots before the roots' own soup (greens first, then roots); a single-category item list is not plain."""
	var hotpot: int = Rules.DISH_BEAN_HOTPOT
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var c: int = Catalog.category_of(item)
		var expected: bool = c == FarmingScript.CROP_CABBAGE or c == FarmingScript.CROP_ROOTS
		assert_equal(TakesScript.matches(Rules.input_selector(hotpot, 1), item), expected,
			"the second input takes %s: %s" % [Catalog.ITEM_KEYS[item], expected])
	assert_equal(Words.input_words(hotpot, 1), "greens or roots", "its words")
	assert_equal(Rules.PLAIN[hotpot], 1, "still plain")
	assert_equal(Rules.IN_WHOLE[Rules.INPUT_FIRST[Rules.DISH_SCONES] + 1], 0, "the scones' nuts alone: not whole")
	var pantry := _pantry()
	pantry.add_into(PEA, 4000, 0, _read)
	pantry.add_into(CARROT, 7000, 0, _read)
	var kitchen := _kitchen(_many("mole", 2), tick_at(0, 6), pantry, StoresScript.new())
	assert_equal(kitchen.cookable_portions(), 6 + 2, "2 hotpots from 4 U of roots (6 portions), then a soup from 3 U")
	assert_equal(Rules.categories_words(PackedInt32Array([PEA])), "", "one category: no words")


func test_ready_food_s_hotpot_draws_greens_before_roots() -> void:
	"""Beans 2, greens 4, roots 2: the hotpot takes the greens first, so a salad (greens 2 + roots 1) still counts --
	3 + 2 portions; drawn from the roots first, the salad would have none (the review's K12)."""
	var pantry := _pantry()
	pantry.add_into(PEA, 2000, 0, _read)
	pantry.add_into(CABBAGE, 4000, 0, _read)
	pantry.add_into(CARROT, 2000, 0, _read)
	var kitchen := _kitchen(_many("mole", 2), tick_at(0, 6), pantry, StoresScript.new())
	assert_equal([kitchen.cookable_batches(), kitchen.cookable_portions()], [2, 5], "a hotpot and a salad")
