extends "res://test/framework/test_case.gd"
## THE RATION RESERVE (decision 1742; Brendan's F7 (b), 2026-10-08): one batch of rations' inputs held from the
## kitchen's planning and raw eating while the rations owned are below the target. The fishery's side (the rations'
## order and refusal, the mill, the stored flour) is test_demo_preserve.gd's.

const ReserveScript := preload("res://demo/preserve/ration_reserve.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const WHEAT: int = 13
const GRAIN: int = FarmingScript.CROP_GRAIN

var _read: IntMath.IntResult = IntMath.IntResult.new()


## A kitchen that holds food beyond its next meal in a take of its own and gives it back when asked, counted.
class KitchenBeyond extends RefCounted:
	var takes: TakesScript = null
	var pantry: PantryScript = null
	var take: int = 0
	## The nuts asked for (every short category is asked; the test follows the nuts).
	var asked: Array[int] = []

	func give(milli: int, crop: int) -> int:
		"""Give back up to `milli` of `crop` (the kitchen's `release_beyond_next_meal`), the nuts counted."""
		if crop == Catalog.CAT_NUTS:
			asked.append(milli)
		return takes.release_milli(pantry, take, milli, 0, crop)


func _reserve(target: int) -> ReserveScript:
	"""A reserve of `target` milli-U of rations over a fresh pantry and takes."""
	var reserve := ReserveScript.new()
	reserve.configure(PantryScript.new(StorageScript.new()), TakesScript.new())
	reserve.target_milli = target
	return reserve


func _stock(reserve: ReserveScript, item: int, milli: int) -> void:
	"""Put `milli` of `item` in the reserve's pantry."""
	assert_true(reserve.pantry.add_into(item, milli, 0, _read), "stocked")


func _need(category: int) -> int:
	"""What one batch of rations takes of `category`."""
	return Recipes.input_milli(Recipes.R_RATION, category)


func test_with_no_target_nothing_is_held() -> void:
	"""The GDD's default (WorldPolicy ration_reserve_milli 0): nothing wanted, nothing held; unconfigured, the same."""
	var reserve := _reserve(0)
	_stock(reserve, Catalog.ITEM_DRIED_FISH, 3000)
	reserve.top_up(0, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), 0, "nothing held")
	assert_equal(reserve.wanted_milli(Catalog.CAT_NUTS, 0), 0, "nothing wanted")
	var bare := ReserveScript.new()
	assert_equal([bare.held_milli(Catalog.CAT_FLOUR), bare.wanted_milli(Catalog.CAT_FLOUR, 0)], [0, 0], "unconfigured")
	assert_equal(bare.give(Catalog.CAT_FLOUR, 1000, 0), 0, "unconfigured gives nothing")
	bare.top_up(0, 0)
	assert_equal(ReserveScript.DEMO_TARGET_MILLI, 6000, "the demo's PROVISIONAL target: two batches")


func test_one_batch_s_inputs_are_held_from_everyone_else() -> void:
	"""Below the target: dried fish 1 U, nuts 1 U, flour 2 U -- and, while the flour held is short, a mill batch's grain
	(3 U) -- held in the reserve's take, so the free food (what the kitchen and a raw meal may take) is less by it."""
	var reserve := _reserve(6000)
	_stock(reserve, Catalog.ITEM_DRIED_FISH, 3000)
	_stock(reserve, Catalog.ITEM_NUTS, 3000)
	_stock(reserve, Catalog.ITEM_FLOUR, 1000)
	_stock(reserve, WHEAT, 5000)
	reserve.top_up(0, 0)
	assert_equal([reserve.held_milli(Catalog.CAT_DRIED_FISH), reserve.held_milli(Catalog.CAT_NUTS),
		reserve.held_milli(Catalog.CAT_FLOUR), reserve.held_milli(GRAIN)],
		[_need(Catalog.CAT_DRIED_FISH), _need(Catalog.CAT_NUTS), 1000, FisheryRules.MILL_IN_MILLI],
		"one batch: the 1 U of flour there, and grain to grind the rest")
	assert_equal(reserve.takes.free_milli_of_crop(reserve.pantry, Catalog.CAT_DRIED_FISH), 2000, "2 U of dried fish free")
	assert_equal(reserve.takes.free_milli_of_crop(reserve.pantry, Catalog.CAT_FLOUR), 0, "no flour free")
	_stock(reserve, Catalog.ITEM_FLOUR, 2000)
	reserve.top_up(0, 0)
	assert_equal([reserve.held_milli(Catalog.CAT_FLOUR), reserve.held_milli(GRAIN)], [_need(Catalog.CAT_FLOUR), 0],
		"the flour held: the grain let go")
	reserve.top_up(0, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), _need(Catalog.CAT_DRIED_FISH), "never more than a batch")


func test_at_the_target_or_released_everything_goes_back() -> void:
	"""Rations owned at the target (one milli-U either side): all let go; below it, gathered again. Released (§5.10's
	emergency action): all let go whatever the rations; restored, gathered again."""
	var reserve := _reserve(6000)
	_stock(reserve, Catalog.ITEM_DRIED_FISH, 3000)
	reserve.top_up(5999, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "one milli-U below the target: held")
	reserve.top_up(6000, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), 0, "at the target: let go")
	reserve.top_up(0, 0)
	reserve.released = true
	reserve.top_up(0, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), 0, "released: let go")
	reserve.released = false
	reserve.top_up(0, 0)
	assert_equal(reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "restored: held again")


func test_what_is_short_is_taken_from_the_kitchen_s_later_meals() -> void:
	"""Free food first; for the rest, the kitchen is asked for exactly the shortfall (its meals beyond the next one,
	decisions 1739 and 1741), then it is held. Free food enough asks nothing."""
	var reserve := _reserve(6000)
	_stock(reserve, Catalog.ITEM_NUTS, 3000)
	var kitchen := KitchenBeyond.new()
	kitchen.takes = reserve.takes
	kitchen.pantry = reserve.pantry
	kitchen.take = reserve.takes.new_take()
	assert_true(reserve.takes.reserve_into(reserve.pantry, kitchen.take, Catalog.CAT_NUTS, 2600, 0, _read), "planned")
	reserve.kitchen_give = kitchen.give
	reserve.top_up(0, 0)
	assert_equal(kitchen.asked, [600] as Array[int], "0.4 U free: the kitchen asked for 0.6 U")
	assert_equal(reserve.held_milli(Catalog.CAT_NUTS), 1000, "a batch's nuts held")
	reserve.top_up(0, 0)
	assert_equal(kitchen.asked.size(), 1, "held: no nuts asked again")


func test_give_lets_the_held_food_go_for_its_batch() -> void:
	"""`give` lets go up to what is asked, never more than is held; the food is free for the batch to take."""
	var reserve := _reserve(6000)
	_stock(reserve, Catalog.ITEM_FLOUR, 5000)
	reserve.top_up(0, 0)
	assert_equal(reserve.give(Catalog.CAT_FLOUR, 500, 0), 500, "0.5 U given")
	assert_equal(reserve.give(Catalog.CAT_FLOUR, 9000, 0), 1500, "the rest, no more")
	assert_equal(reserve.takes.free_milli_of_crop(reserve.pantry, Catalog.CAT_FLOUR), 5000, "all free again")
