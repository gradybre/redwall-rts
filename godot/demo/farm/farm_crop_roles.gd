extends RefCounted
## CROP ROLES (review ECO-001, decision 0881): why a player would choose one crop over another, said as a ROLE with at
## most TWO consequential differences and its USES -- every one read from the rules the demo already runs. Nothing here
## changes a number.
##
## THE ROLES ARE THE GDD'S OWN ROWS. GDD §5.6 has five crop rows and §5.7 gives each its storage category; the demo
## grows each ingredient by exactly one row (farm_catalog.gd ITEM_CROP), and every ingredient of one row grows, keeps and
## feeds identically. The review asks for "six role profiles ... quick fresh crop, reliable staple, long-storing root,
## rotation restorative, flour crop and fiber crop"; five of those six ARE the adopted rows, so each row's role is named
## for what its numbers already make it:
##   §5.6 Roots   -> KEEPING ROOT    the reliable staple: keeps 10 days (§5.7 240 h), ripens in 5 days (§5.6 120 h);
##   §5.6 Cabbage -> FRESH GREENS    the quick fresh crop: sown in summer and autumn when roots may not be (§5.6 windows),
##                                    keeps only 6 days (§5.7 144 h) -- eat it fresh;
##   §5.6 Beans   -> SOIL RESTORER   the rotation restorative: its harvest GIVES 800 fertility (§5.6 cost -800) and a
##                                    legume after a change of family harvests 110% (§5.6 rotation 1100);
##   §5.6 Grain   -> FLOUR CROP      the most a bed gives (§5.6 10 U), the slowest (8 days, spring 1-4 only); ground to
##                                    flour at the mill (fishery.gd `mill_refusal`: §5.7 `flour`, grain 3 -> flour 3);
##   §5.6 Flax    -> FIBRE CROP      cloth and rope (§5.7); the demo grows no flax (farm_catalog.gd EXCLUDED).
## The review's sixth, a LONG-STORING ROOT apart from a quick fresh root (radish fast, parsnip slow), would give
## siblings of ONE row different numbers -- inventing constants no document states. It is a PROPOSAL for Brendan
## (decision 0881), not built: sibling ingredients stay explicitly equivalent, as the review itself asks "until approved
## culinary use distinguishes them".
##
## THE TWO DIFFERENCES each role shows are named per row (ROLE_TRAITS) and worded from the constants themselves, so a
## changed table changes the words. They are differences of 20% or more between rows (the review: "test 15-25%
## differences, not tiny hidden bonuses"): the rows' own numbers.
##
## THE USES are read from data, so a dish added to the kitchen appears here without an edit (the Dishes lane):
##   * every kitchen dish whose input or second input is the ingredient's category (meal_rules.gd DISH_COUNT,
##     `is_input` -- the kitchen's own test);
##   * the mill, for the grain row (MILL_CROP);
##   * eaten raw in a pinch, when the kitchen's raw-emergency table lists the category (meal_rules.gd `raw_np_per_u`).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const ROLE_KEEPING_ROOT: int = 0
const ROLE_FRESH_GREENS: int = 1
const ROLE_SOIL_RESTORER: int = 2
const ROLE_FLOUR_CROP: int = 3
const ROLE_FIBRE_CROP: int = 4
const ROLE_COUNT: int = 5
const ROLE_NAMES: Array[String] = ["Keeping root", "Fresh greens", "Soil restorer", "Flour crop", "Fibre crop"]
## What each role is for, in a few words.
const ROLE_PURPOSE: Array[String] = ["the reliable staple: stores for the lean days", "fresh food for the summer and autumn table",
	"food now, and a richer bed for the next crop", "the heaviest harvest, slow, ground to flour", "cloth and rope"]
## The role of each §5.6 crop row (FarmingScript.CROP_*: beans, cabbage, flax, grain, roots).
const ROLE_OF_CROP: Array[int] = [ROLE_SOIL_RESTORER, ROLE_FRESH_GREENS, ROLE_FIBRE_CROP, ROLE_FLOUR_CROP,
	ROLE_KEEPING_ROOT]

const TRAIT_KEEPS: int = 0
const TRAIT_RIPENS: int = 1
const TRAIT_SOWN: int = 2
const TRAIT_FEEDS_SOIL: int = 3
const TRAIT_YIELD: int = 4
## Each role's two consequential differences, in the order shown: ROLE_TRAITS[role * 2] and [role * 2 + 1].
const ROLE_TRAITS: PackedInt32Array = [
	TRAIT_KEEPS, TRAIT_RIPENS,
	TRAIT_SOWN, TRAIT_KEEPS,
	TRAIT_FEEDS_SOIL, TRAIT_KEEPS,
	TRAIT_YIELD, TRAIT_RIPENS,
	TRAIT_SOWN, TRAIT_YIELD,
]
## The mill grinds the grain row (fishery.gd `mill_refusal` and `order_mill` reserve CROP_GRAIN: §5.7's `flour`).
const MILL_CROP: int = FarmingScript.CROP_GRAIN
const MILL_USE: String = "the mill (flour)"
const RAW_USE: String = "eaten raw in a pinch"
const NO_USE: String = "no dish in the village yet"


static func role_of(item: int) -> int:
	"""The role of a farmed ingredient (its §5.6 row's); -1 for anything that is not a crop."""
	if not Catalog.is_item(item):
		return -1
	return ROLE_OF_CROP[Catalog.crop_of(item)]


static func role_name(item: int) -> String:
	"""The role's name ('' for no crop)."""
	var role: int = role_of(item)
	return ROLE_NAMES[role] if role >= 0 else ""


static func trait_text(crop: int, trait_kind: int) -> String:
	"""One difference of a §5.6 row, in words, from its constants."""
	match trait_kind:
		TRAIT_KEEPS:
			return "keeps %s" % days_text(Catalog.CROP_SHELF_HOURS[crop])
		TRAIT_RIPENS:
			return "ripens in %s" % days_text(FarmingScript.CROP_GROWTH_HOURS[crop])
		TRAIT_SOWN:
			return "sown in %s" % seasons_text(crop)
		TRAIT_FEEDS_SOIL:
			return "gives the soil %d fertility" % -FarmingScript.CROP_FERTILITY_COST[crop]
		TRAIT_YIELD:
			@warning_ignore("integer_division") return "%d U a bed" % (FarmingScript.CROP_BASE_YIELD_MILLI[crop] / 1000)
	return ""


static func traits_text(item: int) -> String:
	"""The ingredient's two differences, 'keeps 10 days · ripens in 5 days' ('' for no crop)."""
	var role: int = role_of(item)
	if role < 0:
		return ""
	var crop: int = Catalog.crop_of(item)
	return "%s · %s" % [trait_text(crop, ROLE_TRAITS[role * 2]), trait_text(crop, ROLE_TRAITS[role * 2 + 1])]


static func uses_of(item: int) -> PackedStringArray:
	"""What the village does with the ingredient, read from the kitchen's and the mill's own tables (see THE USES)."""
	var out := PackedStringArray()
	if not Catalog.is_item(item):
		return out
	for dish: int in MealRules.DISH_COUNT:
		if MealRules.is_input(dish, item):
			out.append(MealRules.DISH_NAMES[dish])
	if Catalog.crop_of(item) == MILL_CROP:
		out.append(MILL_USE)
	if MealRules.raw_np_per_u(item) > 0:
		out.append(RAW_USE)
	return out


static func uses_text(item: int) -> String:
	"""'Uses: Togget's vegetable soup, Poached perch or trout; eaten raw in a pinch' -- or that nothing uses it yet."""
	var uses: PackedStringArray = uses_of(item)
	return "Uses: %s" % (", ".join(uses) if not uses.is_empty() else NO_USE)


static func role_line(item: int) -> String:
	"""The picker's role line: 'Keeping root — keeps 10 days · ripens in 5 days. Uses: ...' ('' for no crop)."""
	if role_of(item) < 0:
		return ""
	return "%s — %s. %s" % [role_name(item), traits_text(item), uses_text(item)]


static func days_text(hours: int) -> String:
	"""Hours as whole days where they are whole ('10 days'), else days and hours ('6 days 4 h')."""
	@warning_ignore("integer_division") var days: int = hours / SimClock.HOURS_PER_DAY
	var rest: int = hours % SimClock.HOURS_PER_DAY
	var day_words: String = "%d day%s" % [days, "" if days == 1 else "s"]
	return day_words if rest == 0 else "%s %d h" % [day_words, rest]


static func seasons_text(crop: int) -> String:
	"""The seasons a row may be sown in, from its §5.6 windows: 'summer and autumn'."""
	var parts := PackedStringArray()
	for k: int in FarmingScript.PLANT_WINDOWS_PER_CROP:
		var season: int = FarmingScript.CROP_WINDOW_SEASON[crop * FarmingScript.PLANT_WINDOWS_PER_CROP + k]
		if season != FarmingScript.NO_WINDOW and not parts.has(Text.SEASONS[season].to_lower()):
			parts.append(Text.SEASONS[season].to_lower())
	return " and ".join(parts)
