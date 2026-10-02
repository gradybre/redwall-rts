extends "res://demo/orders/goal_crop.gd"
## KEEP N DAYS OF MEALS (decision 0711): the kitchen's READY FOOD -- the HUD's figure, kitchen.gd `days_of_meals_milli`:
## the portions held and those the stores' grain, roots and fresh fish would cook, over the village's daily portions.
## The kitchen cooks every meal itself from those stores (decision 0381), so a batch only turns food the figure already
## counts into portions -- and a portion keeps 24 h (§5.7) -- so what RAISES the figure is food into store: the order
## harvests the ripe beds of any crop a dish takes (meal_rules.gd `is_input`, read from the dishes' data). With no wood
## for the fire nothing is cookable: the order says so. Its harvests are in the food bucket under two food-days
## (REQ-SET-113).

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const KitchenText := preload("res://demo/kitchen/kitchen_text.gd")

const NO_FIRE: String = "the kitchen's fire has no wood (%s a batch) — keep wood stocked"
const NONE_RIPE_MEALS: String = "nothing a dish takes is ripe yet (%d beds growing) — the order harvests them as they ripen"
const NONE_GROWING_MEALS: String = "nothing a dish takes is growing — sow grain or roots from a bed's panel"

var _kitchen: KitchenScript = null


func _init(crew: FarmCrewScript, sim: SimScript, pantry: PantryScript, kitchen: KitchenScript) -> void:
	"""Over this farm crew, its beds and pantry, and this kitchen."""
	super(crew, sim, pantry, kitchen.days_of_meals_milli)
	kind = Kinds.KIND_MEALS
	_kitchen = kitchen


func measure(_item: int) -> int:
	"""The kitchen's Ready food, milli-days."""
	return _kitchen.days_of_meals_milli()


func urgent(_item: int) -> bool:
	"""Food acquisition while food-days are under two (REQ-SET-113)."""
	return food_short()


func wants_bed(bed: int, _item: int) -> bool:
	"""A bed of any crop a dish takes."""
	return is_meal_crop(_sim.item_of(bed))


func output_of(row: int, item: int) -> int:
	"""The harvest's food as days of meals: whole batches of the dish it feeds, their portions over the daily
	portions."""
	var milli: int = super(row, item)
	var dish: int = dish_of(_sim.item_of(_crew.jobs.bed[row]))
	var daily: int = _kitchen.daily_portions()
	if dish < 0 or daily <= 0:
		return 0
	@warning_ignore("integer_division")
	return milli / MealRules.INPUT_MILLI[dish] * MealRules.PORTIONS_PER_BATCH[dish] * 1000 / daily


static func dish_of(item: int) -> int:
	"""The first dish whose main input `item` is (-1: none)."""
	for dish: int in MealRules.DISH_COUNT:
		if Catalog.is_item(item) and Catalog.category_of(item) == MealRules.INPUT_CROP[dish]:
			return dish
	return -1


func raise_into(item: int, tracked: Callable, out: IntMath.IntResult) -> String:
	"""No wood for the fire: say so. Else the first ripe dish crop's harvest (goal_crop.gd)."""
	if _kitchen.stores != null and _kitchen.stores.wood_milli_u < MealRules.WOOD_MILLI_PER_BATCH:
		return NO_FIRE % KitchenText.units(MealRules.WOOD_MILLI_PER_BATCH)
	return super(item, tracked, out)


func none_words(item: int) -> String:
	"""Nothing a dish takes ripe yet, or growing."""
	var growing: int = growing_count(item)
	return NONE_RIPE_MEALS % growing if growing > 0 else NONE_GROWING_MEALS
