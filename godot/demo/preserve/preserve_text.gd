extends RefCounted
## What the preserves say in the field guide (decision 1611): dried fruit and rations -- what they are for (ECO-028: each
## preservation its own purpose; fresh food keeps its role), how they are made, and how long they keep. Presentation.

const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const SUMMARY: Array[String] = ["Fruit dried on the rack", "Packed at the preserving table"]


static func is_preserve(item: int) -> bool:
	"""Whether `item` is one of the preserves (dried fruit, rations)."""
	return item == Catalog.ITEM_DRIED_FRUIT or item == Catalog.ITEM_RATION


static func summary(item: int) -> String:
	"""The guide's one line for a preserve."""
	return SUMMARY[0] if item == Catalog.ITEM_DRIED_FRUIT else SUMMARY[1]


static func guide_fields(item: int, raw_np: int) -> PackedStringArray:
	"""A preserve's four fields: its use, how it is made, its alternative, how long it keeps."""
	var recipe: int = Recipes.R_DRY_FRUIT if item == Catalog.ITEM_DRIED_FRUIT else Recipes.R_RATION
	var inputs := PackedStringArray()
	for k: int in Recipes.IN_COUNT[recipe]:
		var input: int = Recipes.IN_FIRST[recipe] + k
		inputs.append("%s %s" % [Recipes.category_words(Recipes.IN_CATEGORY[input]), ForestRules.units_text(Recipes.IN_MILLI[input])])
	if Recipes.WATER_MILLI[recipe] > 0:
		inputs.append("water %s" % ForestRules.units_text(Recipes.WATER_MILLI[recipe]))
	var wait: String = " and %d hours on the rack" % Recipes.PASSIVE_HOURS[recipe] if Recipes.is_passive(recipe) else ""
	@warning_ignore("integer_division") var work_wu: int = Recipes.WORK_MWU[recipe] / 1000
	return PackedStringArray([
		"The village's reserve: eaten as it is by a hungry resident when a meal is missed (%d NP a unit)." % raw_np,
		"%s (the Water panel's Preserves) at %s: %s make %s, %d WU%s." % [Recipes.VERB[recipe],
			Recipes.STATION_NAMES[Recipes.STATION[recipe]], ", ".join(inputs), ForestRules.units_text(Recipes.OUT_MILLI[recipe]),
			work_wu, wait],
		"Fresh fruit for the table while it keeps (%d game hours); the kitchen cooks fresh food first." %
			Catalog.shelf_hours_of(Catalog.ITEM_APPLE) if item == Catalog.ITEM_DRIED_FRUIT else
			"Dried fish and nuts eaten as they are; rations keep longest of all.",
		"Keeps %d game hours in store; the Pantry (K) lists it." % Catalog.shelf_hours_of(item)])
