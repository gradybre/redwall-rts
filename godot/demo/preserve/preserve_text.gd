extends RefCounted
## What the stations' goods say in the field guide (decision 1611: dried fruit and rations; decision 1621: mead and the
## cordial; decision 1625: jam, cheese, ale, cider, vinegar and pickles) -- what each is for (ECO-028: each preservation its own purpose, fresh food keeping its role; ECO-031: a
## modest drink culture, no intoxication), how it is made, and how long it keeps. Presentation only.

const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

## Per recipe row (preserve_rules.gd R_*): the guide's one line (the fish row's is the guide's own, decision 0434).
const SUMMARY: Array[String] = ["", "Fruit dried on the rack", "Packed at the preserving table", "Brewed at the brewery",
	"Made at the brewery's bench", "Cooked at the preserving table", "Set in a crock at the preserving table",
	"Brewed at the brewery", "Pressed and brewed at the brewery", "Soured in a vat at the brewery",
	"Pickled in a crock at the preserving table"]
const DRINK_USE: String = "A drink for the feast: poured at the regatta's supper, a unit for every four guests, when the brewery has made enough. No one is made drunk."
const VINEGAR_USE: String = "An ingredient: the pickles' apple vinegar. Never drunk or eaten."
const DRINK_ALTERNATIVE: String = "The Hearth feast's warm infusion of herbs and water is poured whatever the brewery has made."


static func recipe_of(item: int) -> int:
	"""The station row that makes `item` (-1: none, or the fish row's dried fish, which the guide already describes)."""
	for recipe: int in range(Recipes.R_DRY_FRUIT, Recipes.RECIPE_COUNT):
		if Recipes.OUT_ITEM[recipe] == item:
			return recipe
	return -1


static func is_station_good(item: int) -> bool:
	"""Whether `item` is one of the stations' goods this file describes (dried fruit, rations, mead, cordial, jam,
	cheese, ale, cider, vinegar, pickles)."""
	return recipe_of(item) >= 0


static func summary(item: int) -> String:
	"""The guide's one line for a station good ("" for none)."""
	var recipe: int = recipe_of(item)
	return SUMMARY[recipe] if recipe >= 0 else ""


static func card_use(recipe: int) -> String:
	"""A recipe card's few words on what its row's good is for (preserve_rules.gd USE)."""
	if Recipes.USE[recipe] == Recipes.USE_INGREDIENT:
		return "kept for pickling"
	return "kept for feasts" if Recipes.USE[recipe] == Recipes.USE_DRINK else "eaten as it is"


static func guide_fields(item: int, raw_np: int) -> PackedStringArray:
	"""A station good's four fields: its use, how it is made, its alternative, how long it keeps."""
	var recipe: int = recipe_of(item)
	var drink: bool = Recipes.USE[recipe] == Recipes.USE_DRINK
	var use: String = DRINK_USE if drink \
		else "The village's reserve: eaten as it is by a hungry resident when a meal is missed (%d NP a unit)." % raw_np
	if Recipes.USE[recipe] == Recipes.USE_INGREDIENT:
		use = VINEGAR_USE
	return PackedStringArray([use, made_words(recipe), DRINK_ALTERNATIVE if drink else _alternative(item),
		"Keeps %d game hours in store; the Pantry (K) lists it." % Catalog.shelf_hours_of(item)])


static func made_words(recipe: int) -> String:
	"""How a row is made, in the guide's words: its button, station, inputs, output, work and wait."""
	var inputs := PackedStringArray()
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		inputs.append("%s %s" % [Recipes.category_words(Recipes.IN_CATEGORY[input]), ForestRules.units_text(Recipes.IN_MILLI[input])])
	if Recipes.WATER_MILLI[recipe] > 0:
		inputs.append("water %s" % ForestRules.units_text(Recipes.WATER_MILLI[recipe]))
	var wait: String = " and %d hours at %s" % [Recipes.PASSIVE_HOURS[recipe], Recipes.STATION_NAMES[Recipes.STATION[recipe]]] \
		if Recipes.is_passive(recipe) else ""
	@warning_ignore("integer_division") var work_wu: int = Recipes.WORK_MWU[recipe] / 1000
	return "%s (the Water panel) at %s: %s make %s, %d WU%s." % [Recipes.VERB[recipe],
		Recipes.STATION_NAMES[Recipes.STATION[recipe]], ", ".join(inputs), ForestRules.units_text(Recipes.OUT_MILLI[recipe]),
		work_wu, wait]


static func station_uses(item: int) -> PackedStringArray:
	"""The stations' rows that take `item`, short, for a crop card: 'the brewery (ale)' (preserve_rules.gd rows_taking)."""
	var out := PackedStringArray()
	for recipe: int in Recipes.rows_taking(item):
		out.append("%s (%s)" % [Recipes.STATION_NAMES[Recipes.STATION[recipe]], good_words(recipe)])
	return out


static func made_into_text(item: int) -> String:
	"""The stations' rows that take `item`, for the guide: 'Made into: cider at the brewery; ...' ('' for none)."""
	var parts := PackedStringArray()
	for recipe: int in Recipes.rows_taking(item):
		parts.append("%s at %s" % [good_words(recipe), Recipes.STATION_NAMES[Recipes.STATION[recipe]]])
	return "Made into: %s." % "; ".join(parts) if not parts.is_empty() else ""


static func good_words(recipe: int) -> String:
	"""A row's output in words: 'apple vinegar'."""
	return Catalog.ITEM_LABELS[Recipes.OUT_ITEM[recipe]].to_lower()


static func _alternative(item: int) -> String:
	"""What else does a preserve's work."""
	if item == Catalog.ITEM_JAM:
		return "Fresh berries while they keep (%d game hours); honey sweetens as it is." % Catalog.shelf_hours_of(Catalog.ITEM_BERRIES)
	if item == Catalog.ITEM_CHEESE:
		return "Nuts eaten as they are keep 720 game hours; set as a cheese they keep twice as long."
	if item == Catalog.ITEM_VINEGAR:
		return "Cider is the apples' other brew; vinegar is kept for pickling, never drunk or eaten."
	if item == Catalog.ITEM_PICKLES:
		return "Roots eaten as they are keep %d game hours; pickled they keep %d." % [
			Catalog.CROP_SHELF_HOURS[FarmingScript.CROP_ROOTS], Catalog.shelf_hours_of(Catalog.ITEM_PICKLES)]
	if item == Catalog.ITEM_DRIED_FRUIT:
		return "Fresh fruit for the table while it keeps (%d game hours); the kitchen cooks fresh food first." % \
			Catalog.shelf_hours_of(Catalog.ITEM_APPLE)
	return "Dried fish and nuts eaten as they are; rations keep longest of all."
