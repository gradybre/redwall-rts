extends RefCounted
## THE STATIONS' RECIPES (decision 1611, PRESERVE #18; decision 1621, BREW #19): GDD §5.7's preserving and brewing rows
## the demo can make, as one table the fishery's station jobs (fishery.gd: the rack, the mill, the preserving table and
## the brewery) read by row -- what each takes,
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
## BREWING (decision 1621, BREW #19) adds two rows at THE BREWERY east of the kitchen (art pass 3's `brew_vat` and
## `ale_cask`), whose four passive slots are §5.9's Brewery's ("Cook 1 | 4 passive batch slots"):
##   mead       honey 3, water 3                        -> mead 4, 20 WU + 72 h passive, Brewery/COOK, 1440 h
##   cordial    berries 2, honey 0.5, water 2           -> cordial 4, 10 WU, keeps 72 h -- Brendan's DEC-045 drink
##              (dish_book.gd's `cordial` row, decision 0603: the raspberry cordial), made at the brewery's bench and
##              kept as a drink, never a meal's dish
## Mead is "feast ingredient only; no intoxication subsystem" (§5.7): nothing here, or anywhere, models drink's effect.
## A row's inputs are §5.7 CATEGORIES (farm_catalog.gd category_of), reserved from real lots when it is ordered and
## withdrawn when its work starts (decision 0434's REQ-SET-112/118 flow); water is the stores' butt.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const R_DRY_FISH: int = 0
const R_DRY_FRUIT: int = 1
const R_RATION: int = 2
const R_MEAD: int = 3
const R_CORDIAL: int = 4
const RECIPE_COUNT: int = 5

const STATION_RACK: int = 0
const STATION_TABLE: int = 1
const STATION_BREWERY: int = 2
const STATION_NAMES: Array[String] = ["the rack", "the preserving table", "the brewery"]
## Each station's passive slots in the fishery's one slot table: the rack's four first (fishery_rules.gd RACK_SLOTS), then
## the brewery's four vats (§5.9's Brewery: "4 passive batch slots"); the table has none.
const VAT_SLOTS: int = 4
const SLOT_COUNT: int = FisheryRules.RACK_SLOTS + VAT_SLOTS
const STATION_FIRST_SLOT: PackedInt32Array = [0, 0, FisheryRules.RACK_SLOTS]
const STATION_SLOTS: PackedInt32Array = [FisheryRules.RACK_SLOTS, 0, VAT_SLOTS]

## Per row: §5.7's id, the button's verb, the work board's words, the station, the output and its milli-U, the work and
## the passive wait (0: none -- the batch is carried to the stores as its work ends).
const GDD_ROW: Array[String] = ["dry_fish", "dry_fruit", "ration", "mead", "cordial"]
const VERB: Array[String] = ["Dry fish", "Dry fruit", "Pack rations", "Brew mead", "Make cordial"]
const JOB_WORDS: Array[String] = ["Dry fish", "Dry fruit", "Pack rations", "Brew mead", "Make cordial"]
const TAKE_DOWN_WORDS: Array[String] = ["Take down dried fish", "Take down dried fruit", "", "Draw off the mead", ""]
const DOING_WORDS: Array[String] = ["Drying fish", "Drying fruit", "Packing rations", "Brewing mead", "Making cordial"]
const TAKE_DOWN_DOING: Array[String] = ["Taking down dried fish", "Taking down dried fruit", "", "Drawing off the mead", ""]
const STATION: PackedInt32Array = [STATION_RACK, STATION_RACK, STATION_TABLE, STATION_BREWERY, STATION_BREWERY]
const OUT_ITEM: PackedInt32Array = [Catalog.ITEM_DRIED_FISH, Catalog.ITEM_DRIED_FRUIT, Catalog.ITEM_RATION,
	Catalog.ITEM_MEAD, Catalog.ITEM_CORDIAL]
const OUT_MILLI: PackedInt32Array = [FisheryRules.DRY_OUT_MILLI, 3000, 3000, 4000, 4000]
const WORK_MWU: PackedInt32Array = [FisheryRules.DRY_WORK_MWU, 20000, 24000, 20000, 10000]
const PASSIVE_HOURS: PackedInt32Array = [FisheryRules.DRY_PASSIVE_HOURS, 12, 0, 72, 0]
const WATER_MILLI: PackedInt32Array = [0, 0, 1000, 3000, 2000]
## Per row, its inputs as runs [IN_FIRST, +IN_COUNT) of the input columns: a category and its milli-U.
const IN_FIRST: PackedInt32Array = [0, 1, 2, 5, 6]
const IN_COUNT: PackedInt32Array = [1, 1, 3, 1, 2]
const IN_CATEGORY: PackedInt32Array = [Catalog.CAT_FISH, Catalog.CAT_FRUIT, Catalog.CAT_FLOUR, Catalog.CAT_DRIED_FISH,
	Catalog.CAT_NUTS, Catalog.CAT_HONEY, Catalog.CAT_BERRIES, Catalog.CAT_HONEY]
const IN_MILLI: PackedInt32Array = [FisheryRules.DRY_IN_MILLI, 4000, 2000, 1000, 1000, 3000, 2000, 500]
## A missing input's refusal code (the fish row's is decision 0434's NO_FISH).
const IN_CODE: Array[String] = ["NO_FISH", "NO_FRUIT", "NO_FLOUR", "NO_DRIED_FISH", "NO_NUTS", "NO_HONEY", "NO_BERRIES",
	"NO_HONEY"]
## Where a missing input is got, for a refusal's fix.
const IN_FIX: Array[String] = ["Fishing ▸ Authorise a trip", "Orchard ▸ Harvest (and send the baskets on)",
	"Mill grain (Water ▸ Drying rack and mill)", "Dry fish (Water ▸ Drying rack and mill)", "Woods ▸ Foraging",
	"Orchard ▸ the apiary (and send the baskets on)", "Orchard ▸ Pick berries, or Woods ▸ Foraging",
	"Orchard ▸ the apiary (and send the baskets on)"]

## THE PRESERVING TABLE (DEMO): its place west of the kitchen, by the cauldron, the spot a worker faces, and its props' places.
const TABLE_AT: Vector2 = Vector2(7.8, -6.6)
const TABLE_FACE: Vector2 = Vector2(7.8, -7.6)
const SHELF_KEY: StringName = &"jar_shelf"
const CROCK_KEY: StringName = &"crock_stoneware"
const SHELF_AT: Vector2 = Vector2(7.8, -7.6)
const CROCK_AT: Vector2 = Vector2(8.9, -7.4)
## The props the cast walks round (x, radius, z): the shelf (1.35 m wide) and the crock.
const SHELF_RADIUS_M: float = 0.7
const CROCK_RADIUS_M: float = 0.3

## THE BREWERY (DEMO; decision 1621): its place east of the kitchen, the spot a brewer faces, the mash vat and the
## conditioning cask west of it (its spigot, on its +Z head, toward the brewer), both clear of the kitchen and the rocks.
const BREWERY_AT: Vector2 = Vector2(18.5, -5.9)
const BREWERY_FACE: Vector2 = Vector2(18.8, -7.0)
const VAT_KEY: StringName = &"brew_vat"
const CASK_KEY: StringName = &"ale_cask"
const VAT_AT: Vector2 = Vector2(18.8, -7.0)
const CASK_AT: Vector2 = Vector2(17.6, -7.3)
const VAT_RADIUS_M: float = 0.65
const CASK_RADIUS_M: float = 0.45
## The vat's rim, where its steam rises while a batch brews (art_pass3_mapping.md: 0.80 m).
const VAT_RIM_M: float = 0.8


static func land_obstacles() -> Array[Vector3]:
	"""What the cast walks round at the stations this file places (x, radius, z): the preserving table's shelf and
	crock, the brewery's vat and cask."""
	return [Vector3(SHELF_AT.x, SHELF_RADIUS_M, SHELF_AT.y), Vector3(CROCK_AT.x, CROCK_RADIUS_M, CROCK_AT.y),
		Vector3(VAT_AT.x, VAT_RADIUS_M, VAT_AT.y), Vector3(CASK_AT.x, CASK_RADIUS_M, CASK_AT.y)]


static func station_of_slot(slot: int) -> int:
	"""The station passive slot `slot` belongs to (the rack's first, then the brewery's vats; -1 for none)."""
	for station: int in STATION_SLOTS.size():
		if slot >= STATION_FIRST_SLOT[station] and slot < STATION_FIRST_SLOT[station] + STATION_SLOTS[station]:
			return station
	return -1


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
