extends RefCounted
## THE STATIONS' RECIPES (decision 1611, PRESERVE #18): GDD §5.7's preserving rows the demo can make, as one table the
## fishery's station jobs (fishery.gd: the rack, the mill and now the preserving table) read by row -- what each takes,
## makes, how long the work is, how long it then waits, and where it is done. Presentation only.
##
## THE ROWS, exactly §5.7's:
##   dry_fish   fish 4                                  -> dried_fish 3 x 1800, 24 WU + 12 h passive, Dryer, 720 h
##   dry_fruit  fruit 4                                 -> dried_fruit 3 x 1400, 20 WU + 12 h passive, Dryer, 720 h
##   ration     flour 2, dried_fish 1, nuts 1, water 1  -> ration 3 x 2400, 24 WU, Kitchen/PRESERVE, 1440 h
## The Dryer is the smoking rack by the fisher shelter (decision 0434), so `dry_fruit` shares its four passive slots with
## `dry_fish` (§5.9: the Dryer's "4 passive batch slots", whatever it dries). `ration` is made at THE PRESERVING TABLE, a
## work place beside the kitchen (§5.7: "Kitchen/PRESERVE") with the preserves' shelf (`jar_shelf`) and crock
## (`crock_stoneware`), art pass 3's (decision 0971). `salt_fish` needs coastal salt the demo has not (no coast).
## A row's inputs are §5.7 CATEGORIES (farm_catalog.gd category_of), reserved from real lots when it is ordered and
## withdrawn when its work starts (decision 0434's REQ-SET-112/118 flow); water is the stores' butt.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const R_DRY_FISH: int = 0
const R_DRY_FRUIT: int = 1
const R_RATION: int = 2
const RECIPE_COUNT: int = 3

const STATION_RACK: int = 0
const STATION_TABLE: int = 1
const STATION_NAMES: Array[String] = ["the rack", "the preserving table"]

## Per row: §5.7's id, the button's verb, the work board's words, the station, the output and its milli-U, the work and
## the passive wait (0: none -- the batch is carried to the stores as its work ends).
const GDD_ROW: Array[String] = ["dry_fish", "dry_fruit", "ration"]
const VERB: Array[String] = ["Dry fish", "Dry fruit", "Pack rations"]
const JOB_WORDS: Array[String] = ["Dry fish", "Dry fruit", "Pack rations"]
const TAKE_DOWN_WORDS: Array[String] = ["Take down dried fish", "Take down dried fruit", ""]
const DOING_WORDS: Array[String] = ["Drying fish", "Drying fruit", "Packing rations"]
const TAKE_DOWN_DOING: Array[String] = ["Taking down dried fish", "Taking down dried fruit", ""]
const STATION: PackedInt32Array = [STATION_RACK, STATION_RACK, STATION_TABLE]
const OUT_ITEM: PackedInt32Array = [Catalog.ITEM_DRIED_FISH, Catalog.ITEM_DRIED_FRUIT, Catalog.ITEM_RATION]
const OUT_MILLI: PackedInt32Array = [FisheryRules.DRY_OUT_MILLI, 3000, 3000]
const WORK_MWU: PackedInt32Array = [FisheryRules.DRY_WORK_MWU, 20000, 24000]
const PASSIVE_HOURS: PackedInt32Array = [FisheryRules.DRY_PASSIVE_HOURS, 12, 0]
const WATER_MILLI: PackedInt32Array = [0, 0, 1000]
## Per row, its inputs as runs [IN_FIRST, +IN_COUNT) of the input columns: a category and its milli-U.
const IN_FIRST: PackedInt32Array = [0, 1, 2]
const IN_COUNT: PackedInt32Array = [1, 1, 3]
const IN_CATEGORY: PackedInt32Array = [Catalog.CAT_FISH, Catalog.CAT_FRUIT, Catalog.CAT_FLOUR, Catalog.CAT_DRIED_FISH,
	Catalog.CAT_NUTS]
const IN_MILLI: PackedInt32Array = [FisheryRules.DRY_IN_MILLI, 4000, 2000, 1000, 1000]
## A missing input's refusal code (the fish row's is decision 0434's NO_FISH).
const IN_CODE: Array[String] = ["NO_FISH", "NO_FRUIT", "NO_FLOUR", "NO_DRIED_FISH", "NO_NUTS"]
## Where a missing input is got, for a refusal's fix.
const IN_FIX: Array[String] = ["Fishing ▸ Authorise a trip", "Orchard ▸ Harvest (and send the baskets on)",
	"Mill grain (Water ▸ Drying rack and mill)", "Dry fish (Water ▸ Drying rack and mill)", "Woods ▸ Foraging"]

## THE PRESERVING TABLE (DEMO): its place west of the kitchen, the spot a worker faces, and its props' places.
const TABLE_AT: Vector2 = Vector2(10.4, -8.6)
const TABLE_FACE: Vector2 = Vector2(10.4, -9.6)
const SHELF_KEY: StringName = &"jar_shelf"
const CROCK_KEY: StringName = &"crock_stoneware"
const SHELF_AT: Vector2 = Vector2(10.4, -9.5)
const CROCK_AT: Vector2 = Vector2(11.5, -9.3)
## The props the cast walks round (x, radius, z): the shelf (1.35 m wide) and the crock.
const SHELF_RADIUS_M: float = 0.7
const CROCK_RADIUS_M: float = 0.3


static func land_obstacles() -> Array[Vector3]:
	"""What the cast walks round at the stations this file places (x, radius, z): the preserving table's shelf and
	crock."""
	return [Vector3(SHELF_AT.x, SHELF_RADIUS_M, SHELF_AT.y), Vector3(CROCK_AT.x, CROCK_RADIUS_M, CROCK_AT.y)]


static func is_recipe(recipe: int) -> bool:
	"""Whether `recipe` names one of the rows."""
	return recipe >= 0 and recipe < RECIPE_COUNT


static func is_passive(recipe: int) -> bool:
	"""Whether a batch of `recipe` waits in a slot after its work (the Dryer's rows)."""
	return PASSIVE_HOURS[recipe] > 0


static func food_in_milli(recipe: int) -> int:
	"""All the food a batch of `recipe` takes, milli-U (water aside): REQ-SET-094's half is of this."""
	var total: int = 0
	for k: int in IN_COUNT[recipe]:
		total += IN_MILLI[IN_FIRST[recipe] + k]
	return total


static func cap(words: String) -> String:
	"""`words` with its first letter capitalised ("Dried fish")."""
	return words if words.is_empty() else words[0].to_upper() + words.substr(1)


static func category_words(category: int) -> String:
	"""A category as a recipe names it ("dried fish"): meal_rules.gd's words."""
	return MealRules.CATEGORY_WORDS[category] if category >= 0 and category < MealRules.CATEGORY_WORDS.size() else "food"
