extends RefCounted
## THE STANDING ORDERS' KINDS AND GOODS (decision 0711): what an order can keep, read from data. Presentation only.
##
## A KIND is how a good is measured and which work fulfils it (each kind has its goal, order_goal.gd). A GOOD is one
## thing the player can ask to keep: a kind and, for a crop, its pantry item. The goods are listed from the owners'
## own tables (`goods_into`) -- the stores' wood and planks, the kitchen's days of meals, then every crop the farm's
## catalog grows (farm_catalog.gd ITEM_COUNT, ITEM_LABELS) -- so a crop added to the catalog slots in with no change
## here. FIREWOOD is the winter's built-in order (decision 0571): listed, never offered to add.
##
## Every amount is integer: milli-U for goods, milli-days for meals (1000 = a day). A good's amount is worded in its
## natural measure (goods_measures.gd; decisions 1011, 1801): "Keep 20 planks", "Keep 2 baskets of carrots". The
## numbers below are demo values (decision 0711): the first amount offered, the step of the − and + buttons, the most
## allowed, the hysteresis BAND, and how many of its jobs an order keeps on the boards at once -- the band and the jobs
## held at once approved as built by Brendan's rulings of 2026-10-01.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const KitchenText := preload("res://demo/kitchen/kitchen_text.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const KIND_PLANKS: int = 0
const KIND_WOOD: int = 1
const KIND_MEALS: int = 2
const KIND_CROP: int = 3
const KIND_FIREWOOD: int = 4
const KIND_COUNT: int = 5
## No item: a kind that is one good (everything but a crop).
const NO_ITEM: int = -1

const UNIT_MILLI_U: int = 0
const UNIT_MILLI_DAYS: int = 1
const UNITS: Array[int] = [UNIT_MILLI_U, UNIT_MILLI_U, UNIT_MILLI_DAYS, UNIT_MILLI_U, UNIT_MILLI_U]
## What each kind is called, and the work that fulfils it, in the player's words.
const GOOD_WORDS: Array[String] = ["planks", "wood", "meals", "", "firewood"]
const WORK_WORDS: Array[String] = ["sawing at the sawhorse (Woods)", "gathering deadfall, else felling in a forestry zone (Woods)",
	"harvesting ripe crops a dish takes (Farm)", "harvesting its ripe beds (Farm)",
	"gathering deadfall, else felling in a forestry zone (Woods)"]
## The first amount offered, the − / + step, and the most allowed (in the kind's unit). "Keep 20 planks stocked" and
## "always keep 3 days of meals" are the brief's own examples.
const FIRST_AMOUNT: Array[int] = [20000, 40000, 3000, 10000, 0]
const STEP: Array[int] = [5000, 10000, 500, 5000, 0]
const MAX_AMOUNT: Array[int] = [200000, 400000, 10000, 100000, 0]
## THE BAND (hysteresis): an order starts working when its good falls BELOW its amount, and stops raising work once the
## good and the work under way reach the amount plus the band; it is satisfied again at amount plus band. One saw
## batch for planks, a large deadfall pile for wood, one meal for the village's meals, 1000 milli-U of a crop.
const BAND: Array[int] = [ForestRules.SAW_BATCH_MILLI, ForestRules.DEADFALL_MAX_MILLI, 500, 1000, 0]
## How many of its jobs an order keeps on the boards at once (the Firewood's one at a time is decision 0571's).
const MAX_JOBS: Array[int] = [2, 2, 3, 3, 1]


static func is_kind(kind: int) -> bool:
	"""Whether `kind` names one of the kinds."""
	return kind >= 0 and kind < KIND_COUNT


static func addable(kind: int) -> bool:
	"""Whether the player may add an order of `kind` (the Firewood is the winter's own)."""
	return is_kind(kind) and kind != KIND_FIREWOOD


static func goods_into(kinds: PackedInt32Array, items: PackedInt32Array) -> int:
	"""Every good the player may keep, in the Add row's order: planks, wood, meals, then each crop of the farm's catalog
	(see the header). How many."""
	kinds.clear()
	items.clear()
	for kind: int in [KIND_PLANKS, KIND_WOOD, KIND_MEALS]:
		kinds.append(kind)
		items.append(NO_ITEM)
	for item: int in Catalog.ITEM_COUNT:
		kinds.append(KIND_CROP)
		items.append(item)
	return kinds.size()


static func good_name(kind: int, item: int) -> String:
	"""The good in words: "planks", "meals", "carrot"."""
	if kind == KIND_CROP:
		return Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "?"
	return GOOD_WORDS[kind] if is_kind(kind) else "?"


static func good_key(kind: int, item: int) -> StringName:
	"""The good an order of `kind` keeps, as goods_measures.gd knows it: &"planks", &"wood" (the Firewood's too), a
	crop's own key (farm_catalog.gd ITEM_KEYS); &"" for the meals, which are counted in days."""
	match kind:
		KIND_PLANKS: return &"planks"
		KIND_WOOD, KIND_FIREWOOD: return &"wood"
		KIND_CROP: return Catalog.ITEM_KEYS[item] if Catalog.is_item(item) else &""
	return &""


static func amount_text(kind: int, amount: int, item: int = NO_ITEM) -> String:
	"""An amount of the kind's good in a sentence: "20 planks", "2 baskets of carrots", "no wood" (rounded down: what is
	there or coming), "3.0 days" for the meals."""
	if is_kind(kind) and UNITS[kind] == UNIT_MILLI_DAYS:
		return KitchenText.days_value(amount)
	return Measures.amount(good_key(kind, item), maxi(amount, 0))


static func target_text(kind: int, amount: int, item: int = NO_ITEM) -> String:
	"""An amount the player set (or a rule's: a step, the most allowed), unrounded: "20 planks", "3.0 days"."""
	if is_kind(kind) and UNITS[kind] == UNIT_MILLI_DAYS:
		return KitchenText.days_value(amount)
	return Measures.exact(good_key(kind, item), maxi(amount, 0))


static func title(kind: int, item: int, amount: int) -> String:
	"""The order as the player gave it: "Keep 20 planks", "Keep 2 baskets of carrots", "Keep 3.0 days of meals"."""
	if kind == KIND_FIREWOOD:
		return "Firewood for the winter"
	if is_kind(kind) and UNITS[kind] == UNIT_MILLI_DAYS:
		return "Keep %s of %s" % [target_text(kind, amount), good_name(kind, item)]
	return "Keep %s" % target_text(kind, amount, item)
