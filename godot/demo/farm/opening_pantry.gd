extends RefCounted
## THE PANTRY THE DEMO OPENS WITH (decision 0912, Brendan's E1 of the balance baseline, decision 0911). The demo used to
## open with an empty pantry and its first crops still growing, so nobody could eat until the first harvest: every
## day-0 meal was missed whatever the player did. It now opens with STOCK -- the 40 U of wheat and 50 U of carrots the
## meal loop's acceptance runs (decisions 0381, 0421) topped the kitchen up with: four days of meals for nine
## (20 batches of porridge at 2 U and 16 of soup at 3 U, two portions a batch: 72 portions over 18 a day).
##
## The stock goes into the covered store (location 0) as fresh lots, through the pantry's own `add_into`, so it ages
## and spoils by the same rules as any harvest. It is OPENING stock, not a harvest: the farm's after-action record
## (decision 0451) is re-opened on its hour once the stock is in, so the day-0 record does not count it as harvested.
## Demo values, called once by the village at boot (demo_village.gd `_build_kitchen`).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

## The opening stock: pantry item keys and milli-U, in the order they are stored.
const ITEMS: Array[StringName] = [&"wheat", &"carrot"]
const MILLI: Array[int] = [40000, 50000]
## The covered store (farm_storage.gd: location 0).
const LOCATION: int = 0
## The plain dish each opening item cooks (porridge from the wheat, soup from the carrots: the 72 portions above).
const DISHES: Array[int] = [MealRules.DISH_PORRIDGE, MealRules.DISH_SOUP]


static func total_milli() -> int:
	"""The whole opening stock, milli-U."""
	var total: int = 0
	for milli: int in MILLI:
		total += milli
	return total


static func left_milli(pantry: PantryScript, k: int) -> int:
	"""How much of opening item `k` is still in `pantry`: its stock less every milli-U of that item withdrawn or spoiled
	since, and never more than the pantry holds of it (none when it was never stocked). The pantry spends the lot that
	spoils first first, and the opening lots are the oldest, so they go first."""
	var item: int = Catalog.ITEM_KEYS.find(ITEMS[k])
	if item < 0:
		return 0
	var left: int = MILLI[k] - pantry.withdrawn_total_milli(item) - pantry.spoiled_total_milli(item)
	return clampi(left, 0, pantry.milli_of(item))


static func portions_left(pantry: PantryScript) -> int:
	"""The portions the opening stock still in `pantry` cooks, each item as its plain dish (DISHES) -- what "A full
	larder" leaves out (decision 0902: the goal counts only food the village cooked or brought in)."""
	var portions: int = 0
	for k: int in ITEMS.size():
		var dish: int = DISHES[k]
		@warning_ignore("integer_division")
		var batches: int = left_milli(pantry, k) / MealRules.INPUT_MILLI[dish]
		portions += batches * MealRules.PORTIONS_PER_BATCH[dish]
	return portions


static func stock(pantry: PantryScript, record: RecordScript, hour_index: int) -> int:
	"""Store the opening stock in `pantry` and re-open `record` (may be null) on `hour_index` so it is not counted as a
	harvest. Returns the milli-U stored (all of it, or less where the store refused a row: nothing is forced)."""
	var stored: int = 0
	var read := IntMath.IntResult.new()
	for k: int in ITEMS.size():
		var item: int = Catalog.ITEM_KEYS.find(ITEMS[k])
		if item >= 0 and pantry.add_into(item, MILLI[k], LOCATION, read):
			stored += MILLI[k]
	if record != null:
		record.start(hour_index)
	return stored
