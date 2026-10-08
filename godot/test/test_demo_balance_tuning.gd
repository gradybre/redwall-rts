extends "res://test/framework/test_case.gd"
## The balance rerun's tuning (Brendan's rulings of 2026-10-07 on decision 1731's P1-P14): the cordial a table drink
## that keeps 240 h (decision 1733), the drinks' stock warning (1734) and the batches' water held in the fishery
## (1737). The portion and a half a diner is test_demo_kitchen.gd's (1732), the hotpot's greens or roots
## test_demo_dishes.gd's (1735) and the raw reserve test_demo_kitchen_ui.gd's (1736).

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const TableDrinkScript := preload("res://demo/kitchen/table_drink.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const PreserveText := preload("res://demo/preserve/preserve_text.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")

var _read: IntMath.IntResult = IntMath.IntResult.new()


## Ingredient takes that sees free food but can reserve none (as when every entry row is taken).
class FullTakes extends "res://demo/kitchen/ingredient_takes.gd":
	func reserve_into(_pantry: PantryScript, _which: int, _crop: int, _amount: int, _hour_index: int,
			out: IntMath.IntResult) -> bool:
		"""Nothing reserved."""
		return out.succeed(0)


# --- the cordial (decision 1733) ---------------------------------------------------------------------------------

func test_the_cordial_keeps_240_hours_and_is_a_table_drink() -> void:
	"""P2 (c): 240 h in the pantry and in the recipe book alike; P2 (a): its words say it is poured at supper."""
	assert_equal(Catalog.shelf_hours_of(Catalog.ITEM_CORDIAL), 240, "the pantry keeps it 240 h")
	assert_equal(MealRules.SHELF_HOURS[MealRules.DISH_CORDIAL], 240, "the recipe book's row")
	assert_equal(PreserveText.card_use(Recipes.R_CORDIAL), "poured at supper and at feasts", "the card")
	assert_equal(PreserveText.card_use(Recipes.R_MEAD), "kept for feasts", "mead stays a feast drink")
	assert_true(PreserveText.guide_fields(Catalog.ITEM_CORDIAL, 0)[0].begins_with("A table drink"), "the guide")


func _kitchen_with_cordial(milli: int) -> KitchenScript:
	"""A bare kitchen over a pantry holding `milli` of cordial (none: 0)."""
	var kitchen := KitchenScript.new()
	kitchen.pantry = PantryScript.new(StorageScript.new())
	if milli > 0:
		assert_true(kitchen.pantry.add_into(Catalog.ITEM_CORDIAL, milli, 0, _read), "cordial stocked")
	return kitchen


func _publish(kitchen: KitchenScript, key: int, diners: int) -> void:
	"""Publish meal `key`'s event as the kitchen does, with `diners` who ate."""
	var final := KitchenScript.MealFinal.new()
	final.key = key
	for i: int in diners:
		final.diners.append(i)
	kitchen.finals_published += 1
	final.serial = kitchen.finals_published
	kitchen.finals.append(final)


func test_need_is_a_unit_for_every_four_who_ate() -> void:
	"""ceil(diners / 4) U, the feast's measure."""
	assert_equal([TableDrinkScript.need_milli(0), TableDrinkScript.need_milli(1), TableDrinkScript.need_milli(4),
		TableDrinkScript.need_milli(5), TableDrinkScript.need_milli(9), TableDrinkScript.need_milli(-3)],
		[0, 1000, 1000, 2000, 3000, 0], "ceil(n/4) U")


func test_cordial_is_poured_at_an_ordinary_supper_never_at_breakfast() -> void:
	"""A supper nine ate pours 3 U; a breakfast pours none; each event is read once."""
	var kitchen := _kitchen_with_cordial(10000)
	var drink := TableDrinkScript.new()
	drink.bind(kitchen)
	_publish(kitchen, MealRules.meal_key(2, MealRules.MEAL_BREAKFAST), 9)
	drink.update()
	assert_equal(kitchen.pantry.milli_of(Catalog.ITEM_CORDIAL), 10000, "breakfast: none poured")
	_publish(kitchen, MealRules.meal_key(2, MealRules.MEAL_SUPPER), 9)
	drink.update()
	drink.update()
	assert_equal(kitchen.pantry.milli_of(Catalog.ITEM_CORDIAL), 7000, "supper: 3 U, once")
	assert_equal([drink.poured_milli, drink.pours, drink.dry_suppers], [3000, 1, 0], "the books")


func test_a_feast_supper_and_an_empty_supper_pour_nothing_here() -> void:
	"""The occasion's supper (noted while it was set, even once cleared after it cooked) pours its own drinks; a supper
	nobody ate pours none; events published before the drink was bound are not poured."""
	var kitchen := _kitchen_with_cordial(10000)
	var feast: int = MealRules.meal_key(3, MealRules.MEAL_SUPPER)
	_publish(kitchen, MealRules.meal_key(1, MealRules.MEAL_SUPPER), 9)
	var drink := TableDrinkScript.new()
	drink.bind(kitchen)
	drink.update()
	kitchen.occasion_key = feast
	drink.update()
	kitchen.cooked_keys.append(feast)
	kitchen.occasion_key = KitchenScript.FREE
	_publish(kitchen, feast, 9)
	_publish(kitchen, MealRules.meal_key(4, MealRules.MEAL_SUPPER), 0)
	drink.update()
	assert_equal(kitchen.pantry.milli_of(Catalog.ITEM_CORDIAL), 10000, "nothing poured")
	assert_equal(drink.pours, 0, "no pour counted")


func test_a_feast_cleared_before_it_cooked_is_an_ordinary_supper() -> void:
	"""The FEAST lane's note to 1733 (decision 1701): an occasion cleared before any batch of its meal cooked (a called
	feast cancelled) is forgotten, so its supper pours the table cordial; one cleared with a batch at the cauldron is
	still the occasion's and pours none."""
	var kitchen := _kitchen_with_cordial(10000)
	var drink := TableDrinkScript.new()
	drink.bind(kitchen)
	var cancelled: int = MealRules.meal_key(3, MealRules.MEAL_SUPPER)
	var cooking: int = MealRules.meal_key(4, MealRules.MEAL_SUPPER)
	assert_false(kitchen.meal_under_way(cancelled), "nothing of it cooked")
	kitchen.occasion_key = cancelled
	drink.update()
	kitchen.occasion_key = KitchenScript.FREE
	drink.update()
	_publish(kitchen, cancelled, 8)
	drink.update()
	assert_equal([drink.pours, drink.poured_milli], [1, 2000], "the cancelled feast's supper: 2 U, as any supper")
	kitchen.occasion_key = cooking
	drink.update()
	kitchen._wip_key = cooking
	assert_true(kitchen.meal_under_way(cooking), "a batch at the cauldron")
	kitchen.occasion_key = KitchenScript.FREE
	drink.update()
	kitchen._wip_key = KitchenScript.FREE
	_publish(kitchen, cooking, 8)
	drink.update()
	assert_equal(drink.pours, 1, "cleared while cooking: still the occasion's, nothing poured")
	assert_false(kitchen.meal_under_way(KitchenScript.FREE), "no meal: never under way")


func test_only_free_cordial_is_poured_and_a_dry_supper_is_counted() -> void:
	"""Cordial set aside (the feast's take) is never poured; with less free than the measure, what is free is poured;
	with none free, the supper is counted dry."""
	var kitchen := _kitchen_with_cordial(2500)
	var take: int = kitchen.takes.new_take()
	assert_true(kitchen.takes.reserve_into(kitchen.pantry, take, Catalog.CAT_CORDIAL, 1000, 0, _read), "1 U set aside")
	var drink := TableDrinkScript.new()
	drink.bind(kitchen)
	_publish(kitchen, MealRules.meal_key(2, MealRules.MEAL_SUPPER), 9)
	drink.update()
	assert_equal(drink.poured_milli, 1500, "the 1.5 U free of the 3 U measure")
	assert_equal(kitchen.pantry.milli_of(Catalog.ITEM_CORDIAL), 1000, "the reserved unit stays")
	_publish(kitchen, MealRules.meal_key(3, MealRules.MEAL_SUPPER), 9)
	drink.update()
	assert_equal([drink.pours, drink.dry_suppers], [1, 1], "the next supper had none free")


# --- the drinks' stock warning (decision 1734) -------------------------------------------------------------------

func _fishery_with(item: int, milli: int) -> FisheryScript:
	"""A bare fishery over a pantry holding `milli` of `item`, the stores' butt full."""
	var fishery := FisheryScript.new()
	fishery.pantry = PantryScript.new(StorageScript.new())
	fishery.takes = TakesScript.new()
	fishery.stores = StoresScript.new()
	fishery.stores.water_milli_u = StoresScript.WATER_CAP_MILLI_U
	if milli > 0:
		assert_true(fishery.pantry.add_into(item, milli, 0, _read), "stocked")
	return fishery


func test_a_drink_two_feasts_deep_is_warned_of_one_milli_unit_either_side() -> void:
	"""6 U (two feasts of nine: ceil(9/4) x 2) of a drink warns; 1 milli-U less does not."""
	assert_equal(Recipes.DRINK_STOCK_WARN_MILLI, 2 * 3000, "two feasts' worth")
	var below := _fishery_with(Catalog.ITEM_MEAD, Recipes.DRINK_STOCK_WARN_MILLI - 1)
	assert_equal(below.drink_stock_warning(Recipes.R_MEAD), "", "under two feasts' worth: no warning")
	var at := _fishery_with(Catalog.ITEM_MEAD, Recipes.DRINK_STOCK_WARN_MILLI)
	var words: String = at.drink_stock_warning(Recipes.R_MEAD)
	assert_true(words.contains("already hold 6.0 U of mead, two feasts' worth (6.0 U)"), words)


func test_every_drink_is_warned_of_and_nothing_else() -> void:
	"""Mead, the cordial, ale and cider warn; jam (eaten) and vinegar (an ingredient) never do, however deep."""
	for recipe: int in Recipes.RECIPE_COUNT:
		var fishery := _fishery_with(Recipes.OUT_ITEM[recipe], 20000)
		var warned: bool = not fishery.drink_stock_warning(recipe).is_empty()
		assert_equal(warned, Recipes.USE[recipe] == Recipes.USE_DRINK, "%s" % Recipes.VERB[recipe])
	assert_false(Recipes.is_drink(-1) or Recipes.is_drink(Recipes.RECIPE_COUNT), "no such row")
	var bare := FisheryScript.new()
	assert_equal(bare.drink_stock_warning(Recipes.R_MEAD), "", "no pantry: no warning")


# --- the batches' water (decision 1737) --------------------------------------------------------------------------

func _job(fishery: FisheryScript, kind: int, recipe: int, started: int) -> int:
	"""A live job of `kind` for `recipe`, started or not."""
	var j: int = fishery.tables.open_job(kind, 0, Tables.NONE)
	fishery.tables.j_recipe[j] = recipe
	fishery.tables.j_started[j] = started
	return j


func test_water_is_held_for_batches_ordered_and_not_yet_started() -> void:
	"""A batch ordered holds its recipe's water until it starts (or is cancelled); a started batch, a recipe without
	water and a job of another kind hold none."""
	var fishery := _fishery_with(Catalog.ITEM_HONEY, 0)
	var mead: int = _job(fishery, Tables.KIND_DRY, Recipes.R_MEAD, 0)
	_job(fishery, Tables.KIND_BATCH, Recipes.R_RATION, 0)
	_job(fishery, Tables.KIND_DRY, Recipes.R_CORDIAL, 1)
	_job(fishery, Tables.KIND_DRY, Recipes.R_DRY_FRUIT, 0)
	var seat: int = _job(fishery, Tables.KIND_SEAT, Recipes.R_MEAD, 0)
	assert_equal(fishery.water_held_milli(), Recipes.WATER_MILLI[Recipes.R_MEAD] + Recipes.WATER_MILLI[Recipes.R_RATION],
		"mead's 3 U and the rations' 1 U")
	fishery.tables.j_started[mead] = 1
	fishery.tables.j_live[seat] = 0
	assert_equal(fishery.water_held_milli(), Recipes.WATER_MILLI[Recipes.R_RATION], "the mead started: its water taken")
	var second: int = _job(fishery, Tables.KIND_DRY, Recipes.R_MEAD, 0)
	assert_equal(fishery.water_held_milli(), Recipes.WATER_MILLI[Recipes.R_RATION] + Recipes.WATER_MILLI[Recipes.R_MEAD],
		"a second mead ordered")
	fishery.tables.close_job(second)
	assert_equal(fishery.water_held_milli(), Recipes.WATER_MILLI[Recipes.R_RATION],
		"cancelled before it started: its water given back (close_job keeps its recipe and start flag)")


func test_a_second_batch_cannot_be_ordered_against_water_already_held() -> void:
	"""The butt holds 4 U: one mead (3 U) may be ordered; with it held, a second is refused NO_WATER and says why, one
	milli-U short; with a milli-U more in the butt it may be."""
	var fishery := _fishery_with(Catalog.ITEM_HONEY, 20000)
	fishery.stores.water_milli_u = 4000
	assert_equal(fishery.batch_refusal(Recipes.R_MEAD), "", "the first mead")
	_job(fishery, Tables.KIND_DRY, Recipes.R_MEAD, 0)
	fishery.stores.water_milli_u = 2 * Recipes.WATER_MILLI[Recipes.R_MEAD] - 1
	var why: String = fishery.batch_refusal(Recipes.R_MEAD)
	assert_equal(fishery.refused_code, "NO_WATER", "refused for water: %s" % why)
	assert_true(why.contains("set aside for batches already ordered"), why)
	fishery.stores.water_milli_u += 1
	assert_equal(fishery.batch_refusal(Recipes.R_MEAD), "", "6 U in the butt: a second mead")


func test_a_pour_that_cannot_be_reserved_is_a_dry_supper() -> void:
	"""Free cordial seen, but none could be set aside for the pour (the takes full): nothing poured, the supper counted
	dry, the cordial untouched (the review's D4)."""
	var kitchen := _kitchen_with_cordial(10000)
	kitchen.takes = FullTakes.new()
	var drink := TableDrinkScript.new()
	drink.bind(kitchen)
	_publish(kitchen, MealRules.meal_key(2, MealRules.MEAL_SUPPER), 9)
	drink.update()
	assert_equal([drink.poured_milli, drink.pours, drink.dry_suppers], [0, 0, 1], "a dry supper, nothing poured")
	assert_equal(kitchen.pantry.milli_of(Catalog.ITEM_CORDIAL), 10000, "the cordial untouched")


# --- the rations' dried fish (decision 1740) ---------------------------------------------------------------------

func test_the_rations_dried_fish_is_one_batch_s_and_nothing_else_is_kept() -> void:
	"""F5 (a): raw eaters leave the dried fish one batch of rations takes (§5.7 `ration`: 1 U); every other category,
	the rations' flour and nuts among them, is not kept."""
	var fishery := FisheryScript.new()
	var dried: int = 0
	for k: int in Recipes.IN_COUNT[Recipes.R_RATION]:
		var input: int = Recipes.IN_FIRST[Recipes.R_RATION] + k
		dried += Recipes.IN_MILLI[input] if Recipes.IN_CATEGORY[input] == Catalog.CAT_DRIED_FISH else 0
	assert_equal(dried, 1000, "a batch of rations takes 1 U of dried fish")
	assert_equal(fishery.ration_keep_milli(Catalog.CAT_DRIED_FISH), dried, "that is kept")
	for category: int in [Catalog.CAT_FLOUR, Catalog.CAT_NUTS, Catalog.CAT_FISH, Catalog.CAT_DRIED_FRUIT]:
		assert_equal(fishery.ration_keep_milli(category), 0, "category %d is not kept" % category)
	assert_equal(Recipes.input_milli(Recipes.R_RATION, Catalog.CAT_FLOUR), 2000, "the row read: 2 U of flour")
	assert_equal(Recipes.input_milli(Recipes.R_RATION, Catalog.CAT_HONEY), 0, "none of what it does not take")
	var guide := FieldGuideScript.new()
	var uses: String = guide.entry(guide.index_of(FieldGuideScript.item_id(Catalog.ITEM_DRIED_FISH))).uses
	assert_true(uses.contains("all but the %s a batch of rations takes" % FarmText.units_text(dried)), uses)
