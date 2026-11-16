extends RefCounted
## GOODS IN NATURAL MEASURES: the one place a player-facing amount is worded. Decision 1011 (the table, §1 and §1a;
## the wording rules, §2), Brendan's DEC-049, and docs/ui_ux_controls.md "Amounts are shown in natural measures".
## Phase 2 (MEAS-2) is decision 1801.
##
## DISPLAY ONLY. Every amount stays integer milli-U (GDD §4.1, 1000 = one catalogue unit) in the simulation, saves and
## data; this module only words one. Nothing here is ever written back, and nothing here rounds a figure a rule uses.
##
## A GOOD, NOT A NUMBER. Each call takes the good as well as its milli-U: the measure comes from the good ("40 logs",
## "12 sacks of barley", "9 perch", "a bunch of herbs"), so an amount can never again say only "U". Goods are keyed by
## the catalogue's StringName (`data/item_definitions.json`, all 61), by the demo pantry's own item keys (farm_catalog.gd
## ITEM_KEYS: "a radish is a radish"), and by a few display keys: `planks`, `earth`, `food` (mixed food: the Pantry's
## total and every food store's capacity), `greens` and `fish` (the kitchen's recipe categories; §1 "Kitchen
## categories"). An UNKNOWN key push_errors and returns UNKNOWN ("?"): the suite's log gate (decision 0501) fails on
## it, so "U" can never come back as a fallback, and a good the demo begins to show needs its row here first.
##
## THE ROWS. Each good has an ordered list of measures, largest first; each measure is [singular, plural, milli-U per
## measure, from, halves, of]:
##   * from:   a container measure used only from this many upward ("from 2": "2 sacks", never "1 sack"); below it the
##             next measure takes over. 1 for an ordinary measure.
##   * halves: shown in halves below ten measures ("half a jar", "1½ sacks"); from ten upward whole measures only.
##   * of:     the measure names its good in a sentence ("12 sacks of barley"); 0 for a measure that is the good
##             itself ("40 logs", "9 perch", "3 onions") or names its own stuff ("3 bundles of kindling").
## Below the smallest measure an amount shows its weight ("40 g of herbs"), never 0 (decision 0222's rule kept); under
## 1 g it is "a trace of herbs". Each good's MASS (grams per U) comes from the catalogue through item_definitions.gd,
## never retyped: a demo good names the catalogue row it weighs as (a radish weighs as `roots`; planks as `wood`, P2).
## A good with no catalogue row at all names the row it is weighed as (decision 1801; approved by Brendan, P-M1 (a)).
##
## FOUR RENDERINGS (1011 §2). `amount` rounds DOWN (stock, yield, catch: never claims what is not there); `need` rounds
## UP (a requirement, cost or rate: never understates it, BAL-NUM-001's direction); `exact` rounds not at all (an
## authored constant or a player-set target: the largest measure that divides it, else its exact weight); `have_need`
## puts a have beside a need in the NEED's measure and reads "enough" once the have meets the need in milli-U. Each has
## a sentence form ("a sack of barley", "no barley") and a CELL form for a table cell or a labelled row, which drops the
## good's name and articles ("1 sack", "none"). `weight` is the tooltip's exact weight in integer grams, shown in kg or
## g (liquids in litres too, P8); `tooltip` is an amount with its weight ("12 sacks of barley — 60 kg").

const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

const MILLI_PER_U: int = 1000
const UNKNOWN: String = "?"
const NONE_CELL: String = "none"
const TRACE: String = "a trace"
const UNDER_A_GRAM: String = "under 1 g"
const HALF_GLYPH: String = "½"
const ENOUGH: String = "enough"
## From this many measures upward only whole measures are shown (1011 §2 "Halves").
const WHOLE_FROM: int = 10
## Grams at or above which a weight shows in kg (1011 §2 "Weight for tooltips").
const KG_FROM_G: int = 1000
## kg are shown floored (or, for a need, raised) to this many grams: "4.75 kg", "62.5 kg".
const KG_STEP_G: int = 10

const ROUND_DOWN: int = 0
const ROUND_UP: int = 1
const ROUND_EXACT: int = 2

## The Wood level words (DEC-049 P6, 1011 §3 and §4b), in the order they are judged; `wood_level` picks one.
const LEVEL_NONE: int = 0
const LEVEL_VERY_LOW: int = 1
const LEVEL_RUNNING_LOW: int = 2
const LEVEL_ENOUGH: int = 3
const LEVEL_PLENTY: int = 4
const LEVEL_WORDS: Array[String] = ["none", "very low", "running low", "enough", "plenty"]

## Measures shared by many rows (see THE ROWS).
const M_SACK: Array = ["sack", "sacks", 20000, 2, 1, 1]
const M_SCOOP: Array = ["scoop", "scoops", 1000, 1, 0, 1]
const M_BASKET: Array = ["basket", "baskets", 5000, 2, 1, 1]
const M_BOWL: Array = ["bowl", "bowls", 1000, 1, 0, 1]
const M_BUNCH: Array = ["bunch", "bunches", 1000, 1, 0, 1]
const M_BUCKET: Array = ["bucket", "buckets", 10000, 2, 1, 1]
const M_JUG: Array = ["jug", "jugs", 1000, 1, 0, 1]
const M_CUP: Array = ["cup", "cups", 250, 1, 0, 1]
## The cask shows halves (Brendan's ruling on 1801 P-M3 (b), 2026-10-09), so every "from 2" measure keeps 1011's 20%.
const M_CASK: Array = ["cask", "casks", 20000, 2, 1, 1]
const M_JAR: Array = ["jar", "jars", 1000, 1, 1, 1]
const M_PORTION: Array = ["portion", "portions", 1000, 1, 0, 1]
const M_SEED_POUCH: Array = ["pouch", "pouches", 4000, 1, 0, 1]
const M_SEED_HANDFUL: Array = ["handful", "handfuls", 250, 1, 0, 1]
const M_FOOD_BASKET: Array = ["basket", "baskets", 5000, 1, 1, 1]

## Every good: [key, the catalogue row it weighs as, its name in a sentence, liquid (1: litres in its tooltip),
## measures largest first]. The last block is decision 1801's rows for goods 1011 has no row for (Brendan, 2026-10-09).
const ROWS: Array = [
	# Materials and stores (1011 §1).
	[&"wood", &"wood", "wood", 0, [["log", "logs", 1000, 1, 0, 0], ["quarter log", "quarter logs", 250, 1, 0, 0],
		["bundle of kindling", "bundles of kindling", 100, 1, 0, 0]]],
	[&"planks", &"wood", "planks", 0, [["plank", "planks", 1000, 1, 0, 0]]],
	[&"stone", &"stone", "stone", 0, [["block", "blocks", 1000, 1, 0, 1]]],
	[&"earth", &"excavated_earth", "earth", 0, [["basket", "baskets", 2000, 1, 0, 1]]],
	[&"excavated_earth", &"excavated_earth", "earth", 0, [["basket", "baskets", 2000, 1, 0, 1]]],
	[&"compost", &"compost", "compost", 0, [["basket", "baskets", 2000, 1, 0, 1],
		["spadeful", "spadefuls", 250, 1, 0, 1]]],
	[&"water", &"water", "water", 1, [M_BUCKET, M_JUG, M_CUP]],
	[&"cloth", &"cloth", "cloth", 0, [["bolt", "bolts", 8000, 1, 1, 1], ["length", "lengths", 500, 1, 0, 1]]],
	[&"rope", &"rope", "rope", 0, [["coil", "coils", 1000, 1, 0, 1], ["length", "lengths", 250, 1, 0, 1]]],
	[&"iron", &"iron", "iron", 0, [["bar", "bars", 1000, 1, 0, 1]]],
	[&"flax", &"flax", "flax", 0, [["bundle", "bundles", 4000, 1, 1, 1], ["handful", "handfuls", 250, 1, 0, 1]]],
	[&"wax", &"wax", "wax", 0, [["cake", "cakes", 1000, 1, 1, 1], ["piece", "pieces", 250, 1, 0, 1]]],
	[&"mead", &"mead", "mead", 1, [M_CASK, M_JUG]],
	# Food (1011 §1): grain, flour and pulses in sacks and scoops.
	[&"wheat", &"grain", "wheat", 0, [M_SACK, M_SCOOP]],
	[&"barley", &"grain", "barley", 0, [M_SACK, M_SCOOP]],
	[&"oats", &"grain", "oats", 0, [M_SACK, M_SCOOP]],
	[&"grain", &"grain", "grain", 0, [M_SACK, M_SCOOP]],
	[&"flour", &"flour", "flour", 0, [M_SACK, M_SCOOP]],
	[&"pea", &"beans", "peas", 0, [M_SACK, M_SCOOP]],
	[&"broad_bean", &"beans", "broad beans", 0, [M_SACK, M_SCOOP]],
	[&"beans", &"beans", "beans", 0, [M_SACK, M_SCOOP]],
	[&"potato", &"roots", "potatoes", 0, [M_SACK, ["potato", "potatoes", 1000, 1, 0, 0]]],
	# Roots and greens in baskets and bunches; the rest counted (P4).
	[&"radish", &"roots", "radishes", 0, [M_BASKET, M_BUNCH]],
	[&"carrot", &"roots", "carrots", 0, [M_BASKET, M_BUNCH]],
	[&"beetroot", &"roots", "beetroot", 0, [M_BASKET, M_BUNCH]],
	[&"spinach", &"cabbage", "spinach", 0, [M_BASKET, M_BUNCH]],
	[&"turnip", &"roots", "turnips", 0, [["turnip", "turnips", 1000, 1, 0, 0]]],
	[&"parsnip", &"roots", "parsnips", 0, [["parsnip", "parsnips", 1000, 1, 0, 0]]],
	[&"onion", &"roots", "onions", 0, [["onion", "onions", 1000, 1, 0, 0]]],
	[&"leek", &"cabbage", "leeks", 0, [["leek", "leeks", 1000, 1, 0, 0]]],
	[&"lettuce", &"cabbage", "lettuce", 0, [["lettuce", "lettuces", 1000, 1, 0, 0]]],
	[&"cabbage", &"cabbage", "cabbage", 0, [["cabbage", "cabbages", 2000, 1, 0, 0]]],
	[&"celery", &"cabbage", "celery", 0, [["head", "heads", 2000, 1, 0, 1]]],
	[&"roots", &"roots", "roots", 0, [M_BASKET, M_BOWL]],
	[&"greens", &"cabbage", "greens", 0, [M_BASKET, M_BOWL]],
	# Fruit, forage and honey.
	[&"apple", &"fruit", "apples", 0, [M_BASKET, ["apple", "apples", 1000, 1, 0, 0]]],
	[&"pear", &"fruit", "pears", 0, [M_BASKET, ["pear", "pears", 1000, 1, 0, 0]]],
	[&"fruit", &"fruit", "fruit", 0, [M_BASKET, M_BOWL]],
	[&"honey", &"honey", "honey", 0, [M_JAR]],
	[&"nuts", &"nuts", "nuts", 0, [M_SACK, ["handful", "handfuls", 500, 1, 0, 1]]],
	[&"mushrooms", &"mushrooms", "mushrooms", 0, [M_BASKET, M_BOWL]],
	[&"berries", &"berries", "berries", 0, [M_BASKET, M_BOWL]],
	[&"herb", &"herb", "herbs", 0, [M_BUNCH, ["handful", "handfuls", 250, 1, 0, 1]]],
	# Fish: one fish a U for every species (P3), counted with the same plural.
	[&"trout", &"trout", "trout", 0, [["trout", "trout", 1000, 1, 0, 0]]],
	[&"dace", &"dace", "dace", 0, [["dace", "dace", 1000, 1, 0, 0]]],
	[&"salmon", &"salmon", "salmon", 0, [["salmon", "salmon", 1000, 1, 0, 0]]],
	[&"perch", &"perch", "perch", 0, [["perch", "perch", 1000, 1, 0, 0]]],
	[&"carp", &"carp", "carp", 0, [["carp", "carp", 1000, 1, 0, 0]]],
	[&"whitefish", &"whitefish", "whitefish", 0, [["whitefish", "whitefish", 1000, 1, 0, 0]]],
	[&"herring", &"herring", "herring", 0, [["herring", "herring", 1000, 1, 0, 0]]],
	[&"mackerel", &"mackerel", "mackerel", 0, [["mackerel", "mackerel", 1000, 1, 0, 0]]],
	[&"fish", &"trout", "fish", 0, [["fish", "fish", 1000, 1, 0, 0]]],
	[&"dried_fish", &"dried_fish", "dried fish", 0, [["string", "strings", 1000, 1, 0, 1]]],
	[&"mussel", &"mussel", "mussels", 0, [["bowl", "bowls", 1000, 1, 0, 1]]],
	[&"salted_fish", &"salted_fish", "salted fish", 0, [["piece", "pieces", 1000, 1, 0, 1]]],
	# Mixed food (the Pantry's total, every food store's capacity), and spoiled food (§1a: from 2).
	[&"food", &"roots", "food", 0, [M_FOOD_BASKET, M_BOWL]],
	[&"spoiled_food", &"spoiled_food", "spoiled food", 0, [M_BASKET, M_BOWL]],
	# Portions and rations: whole counts already.
	[&"ration", &"ration", "rations", 0, [["ration", "rations", 1000, 1, 0, 0]]],
	[&"meal_bean_hotpot", &"meal_bean_hotpot", "bean hotpot", 0, [M_PORTION]],
	[&"meal_crumble", &"meal_crumble", "crumble", 0, [M_PORTION]],
	[&"meal_feast_fish", &"meal_feast_fish", "feast fish", 0, [M_PORTION]],
	[&"meal_fish_stew", &"meal_fish_stew", "fish stew", 0, [M_PORTION]],
	[&"meal_nut_roast", &"meal_nut_roast", "nut roast", 0, [M_PORTION]],
	[&"meal_nut_loaf", &"meal_nut_loaf", "nut loaf", 0, [M_PORTION]],
	[&"meal_pie", &"meal_pie", "pie", 0, [M_PORTION]],
	[&"meal_porridge", &"meal_porridge", "porridge", 0, [M_PORTION]],
	[&"meal_root_stew", &"meal_root_stew", "root stew", 0, [M_PORTION]],
	[&"meal_tart", &"meal_tart", "tart", 0, [M_PORTION]],
	# The rest of the game catalogue (1011 §1a, approved under P9 (b)).
	[&"dried_fruit", &"dried_fruit", "dried fruit", 0, [["bag", "bags", 1000, 1, 0, 1]]],
	[&"brine", &"brine", "brine", 1, [M_BUCKET, M_JUG, M_CUP]],
	[&"salt", &"salt", "salt", 0, [["bag", "bags", 1000, 1, 0, 1]]],
	[&"seed_grain", &"seed_grain", "grain seed", 0, [M_SEED_POUCH, M_SEED_HANDFUL]],
	[&"seed_roots", &"seed_roots", "root seed", 0, [M_SEED_POUCH, M_SEED_HANDFUL]],
	[&"seed_beans", &"seed_beans", "bean seed", 0, [M_SEED_POUCH, M_SEED_HANDFUL]],
	[&"seed_cabbage", &"seed_cabbage", "cabbage seed", 0, [M_SEED_POUCH, M_SEED_HANDFUL]],
	[&"seed_flax", &"seed_flax", "flax seed", 0, [M_SEED_POUCH, M_SEED_HANDFUL]],
	[&"sapling_apple", &"sapling_apple", "apple saplings", 0, [["apple sapling", "apple saplings", 1000, 1, 0, 0]]],
	[&"sapling_pear", &"sapling_pear", "pear saplings", 0, [["pear sapling", "pear saplings", 1000, 1, 0, 0]]],
	[&"candle", &"candle", "candles", 0, [["candle", "candles", 1000, 1, 0, 0]]],
	[&"tool", &"tool", "tools", 0, [["tool", "tools", 1000, 1, 0, 0]]],
	[&"net", &"net", "nets", 0, [["net", "nets", 1000, 1, 0, 0]]],
	[&"trap", &"trap", "traps", 0, [["trap", "traps", 1000, 1, 0, 0]]],
	[&"ice_kit", &"ice_kit", "ice kits", 0, [["ice kit", "ice kits", 1000, 1, 0, 0]]],
	[&"outfit_tier2", &"outfit_tier2", "winter outfits", 0, [["winter outfit", "winter outfits", 1000, 1, 0, 0]]],
	# Decision 1801, approved by Brendan 2026-10-09 (P-M1 (a)): the demo's goods added after 1011, which no catalogue
	# row weighs. The drinks weigh as mead (a litre a U) and are measured as mead (ale, cider) or as water's jug and
	# cup (cordial, vinegar); the eaten-as-they-are preserves weigh as dried fruit (250 g a U) and are measured as
	# honey is, in jars, or in rounds.
	[&"ale", &"mead", "ale", 1, [M_CASK, M_JUG]],
	[&"cider", &"mead", "cider", 1, [M_CASK, M_JUG]],
	[&"cordial", &"mead", "cordial", 1, [M_JUG, M_CUP]],
	[&"vinegar", &"mead", "apple vinegar", 1, [M_JUG, M_CUP]],
	[&"jam", &"dried_fruit", "berry jam", 0, [M_JAR]],
	[&"pickles", &"dried_fruit", "pickles", 0, [M_JAR]],
	[&"cheese", &"dried_fruit", "nut cheese", 0, [["round", "rounds", 1000, 1, 1, 1]]],
]

## The compiled table (see THE ROWS), built once on first use from ROWS and the catalogue's masses.
static var _row_of: Dictionary = {}
static var _mass_g: PackedInt32Array = PackedInt32Array()
static var _noun: PackedStringArray = PackedStringArray()
static var _liquid: PackedByteArray = PackedByteArray()
static var _first: PackedInt32Array = PackedInt32Array()
static var _count: PackedInt32Array = PackedInt32Array()
static var _one: PackedStringArray = PackedStringArray()
static var _many: PackedStringArray = PackedStringArray()
static var _milli: PackedInt32Array = PackedInt32Array()
static var _from: PackedInt32Array = PackedInt32Array()
static var _halves: PackedByteArray = PackedByteArray()
static var _of: PackedByteArray = PackedByteArray()


# --- the renderings -----------------------------------------------------------------------------------------------

static func amount(good: StringName, milli: int) -> String:
	"""Stock, a harvest, a yield or a catch in a sentence, rounded DOWN: "12 sacks of barley", "a log", "no barley"."""
	return _render(good, milli, ROUND_DOWN, false)


static func amount_cell(good: StringName, milli: int) -> String:
	"""The same for a table cell or a labelled row: "12 sacks", "1 log", "none"."""
	return _render(good, milli, ROUND_DOWN, true)


static func need(good: StringName, milli: int) -> String:
	"""A requirement, a cost or a rate in a sentence, rounded UP: never understates it ("5 planks")."""
	return _render(good, milli, ROUND_UP, false)


static func need_cell(good: StringName, milli: int) -> String:
	"""The same for a table cell or a labelled row."""
	return _render(good, milli, ROUND_UP, true)


static func exact(good: StringName, milli: int) -> String:
	"""An authored constant or a player-set target, unrounded: the largest measure that divides it ("2 scoops of
	grain", "a handful of herbs"), otherwise its weight -- floored to the gram (or, from a kilogram, to 10 g), so only
	a measure is truly exact (see `divides`)."""
	return _render(good, milli, ROUND_EXACT, false)


static func exact_cell(good: StringName, milli: int) -> String:
	"""The same for a table cell or a labelled row."""
	return _render(good, milli, ROUND_EXACT, true)


static func have_need(good: StringName, have_milli: int, need_milli: int) -> String:
	"""A have beside a need, both in the NEED's measure (have down, need up): "4 of 5 planks"; "5 planks — enough"
	once the have meets the need in milli-U; "under 1 of 5 planks" for a have the measure cannot show."""
	var row: int = _row(good)
	if row < 0:
		return UNKNOWN
	var need_words: String = _render_row(row, need_milli, ROUND_UP, true)
	if have_milli >= need_milli:
		return "%s — %s" % [need_words, ENOUGH]
	var m: int = _pick(row, need_milli, ROUND_UP)
	if m < 0:
		return "%s of %s" % [_weight_words(row, maxi(have_milli, 0), ROUND_DOWN), need_words]
	var halves: int = _halves_of(m, maxi(have_milli, 0), ROUND_DOWN, need_milli)
	if halves <= 0:
		return "%s of %s" % ["0" if have_milli <= 0 else "under %s" % _number(_halves_shown(m, need_milli)), need_words]
	return "%s of %s" % [_number(halves), need_words]


static func grams(good: StringName, milli: int) -> int:
	"""The exact weight in whole grams (floored): milli-U × the good's catalogue mass_g / 1000. 0 for an unknown key
	(after its error)."""
	var row: int = _row(good)
	if row < 0:
		return 0
	@warning_ignore("integer_division") return maxi(milli, 0) * _mass_g[row] / MILLI_PER_U


static func weight(good: StringName, milli: int) -> String:
	"""The tooltip's exact weight: "60 kg", "625 g", "62.5 kg"; a liquid in litres too, "10 litres (10 kg)" (P8);
	"under 1 g" for a trace."""
	var row: int = _row(good)
	if row < 0:
		return UNKNOWN
	var g: int = grams(good, milli)
	if g <= 0:
		return UNDER_A_GRAM if milli > 0 else "0 g"
	if _liquid[row] == 0:
		return _grams_text(g, ROUND_DOWN)
	return "%s (%s)" % [_litres_text(g), _grams_text(g, ROUND_DOWN)]


static func tooltip(good: StringName, milli: int) -> String:
	"""An amount with its exact weight, for a hover: "12 sacks of barley — 60 kg" (an amount already shown as a weight,
	"40 g of herbs", is not repeated)."""
	var row: int = _row(good)
	if row < 0:
		return UNKNOWN
	if milli <= 0 or _pick(row, milli, ROUND_DOWN) < 0:
		return _render_row(row, milli, ROUND_DOWN, false)
	return "%s — %s" % [_render_row(row, milli, ROUND_DOWN, false), weight(good, milli)]


static func divides(good: StringName, milli: int) -> bool:
	"""Whether `exact` names a measure for `milli` of `good` rather than falling back to its weight ("5 cabbages" for
	10 U; 5 U of cabbage is no whole count): a caller may then prefer `need`."""
	var row: int = _row(good)
	return row >= 0 and _pick(row, milli, ROUND_EXACT) >= 0


static func noun(good: StringName) -> String:
	"""The good's name as a sentence uses it ("barley", "herbs", "dried fish")."""
	var row: int = _row(good)
	return UNKNOWN if row < 0 else _noun[row]


static func knows(good: StringName) -> bool:
	"""Whether the good has a row (no error when it has not: for a test or a guard)."""
	_compile()
	return _row_of.has(good)


static func wood_level(available_milli: int, very_low: bool, running_low: bool, projection_milli: int) -> int:
	"""The Wood level (1011 §3, §4b), judged in order: none (no wood); very low (the fuel warning: under 2 fuel-days);
	running low (below the twelve-day winter projection while it is wanted); plenty (at or above the projection);
	otherwise enough. The caller supplies its owner's own flags and projection: no threshold is made here."""
	if available_milli <= 0:
		return LEVEL_NONE
	if very_low:
		return LEVEL_VERY_LOW
	if running_low:
		return LEVEL_RUNNING_LOW
	if projection_milli > 0 and available_milli >= projection_milli:
		return LEVEL_PLENTY
	return LEVEL_ENOUGH


static func level_words(level: int) -> String:
	"""A Wood level's words ("running low"); UNKNOWN for a level out of range."""
	return LEVEL_WORDS[level] if level >= 0 and level < LEVEL_WORDS.size() else UNKNOWN


# --- wording ------------------------------------------------------------------------------------------------------

static func _render(good: StringName, milli: int, rounding: int, cell: bool) -> String:
	"""One rendering of `milli` of `good`, or UNKNOWN (after an error) for a good with no row."""
	var row: int = _row(good)
	if row < 0:
		return UNKNOWN
	return _render_row(row, milli, rounding, cell)


static func _render_row(row: int, milli: int, rounding: int, cell: bool) -> String:
	"""Zero as "none" / "no barley"; otherwise in the measure `_pick` chooses, or as a weight below every measure."""
	if milli <= 0:
		return NONE_CELL if cell else "no %s" % _noun[row]
	var m: int = _pick(row, milli, rounding)
	if m < 0:
		return _weight_words(row, milli, rounding) if cell else _weight_sentence(row, milli, rounding)
	return _measure_words(row, m, _halves_of(m, milli, rounding, milli), cell)


static func _pick(row: int, milli: int, rounding: int) -> int:
	"""The measure an amount is shown in: the largest it reaches (its "from" count, or half of it when it shows
	halves); for an exact amount, the largest that divides it. -1: below every measure (or none divides it)."""
	for m: int in range(_first[row], _first[row] + _count[row]):
		if rounding == ROUND_EXACT:
			if _divides(m, milli):
				return m
		elif milli >= _threshold(m):
			return m
	return -1


static func _threshold(m: int) -> int:
	"""The least amount a measure is used for: `from` of it ("from 2"), half of it (halves), or one of it."""
	if _from[m] > 1:
		return _from[m] * _milli[m]
	@warning_ignore("integer_division") return _milli[m] / 2 if _halves[m] == 1 else _milli[m]


static func _divides(m: int, milli: int) -> bool:
	"""Whether `milli` is a whole number of measure `m` -- or of halves of it, below ten -- at or above its threshold."""
	if milli < _threshold(m):
		return false
	if milli % _milli[m] == 0:
		return true
	return _halves[m] == 1 and milli < WHOLE_FROM * _milli[m] and (2 * milli) % _milli[m] == 0


static func _halves_of(m: int, milli: int, rounding: int, scale_milli: int) -> int:
	"""`milli` in HALVES of measure `m`, rounded down or up -- in halves only while `scale_milli` (the amount the
	measure was chosen for) is under ten measures and the measure shows halves; otherwise whole measures, doubled."""
	var unit: int = _milli[m]
	if _halves[m] == 1 and scale_milli < WHOLE_FROM * unit:
		@warning_ignore("integer_division") unit = _milli[m] / 2
	var units: int = _div(milli, unit, rounding)
	return units if unit != _milli[m] else units * 2


static func _halves_shown(m: int, scale_milli: int) -> int:
	"""The least amount `_halves_of` can show in measure `m` at this scale, in halves: a half or a whole one."""
	return 1 if _halves[m] == 1 and scale_milli < WHOLE_FROM * _milli[m] else 2


static func _div(a: int, b: int, rounding: int) -> int:
	"""a / b, floored or (ROUND_UP) raised; exact amounts divide exactly, so either serves them."""
	@warning_ignore("integer_division") return (a + b - 1) / b if rounding == ROUND_UP else a / b


static func _measure_words(row: int, m: int, halves: int, cell: bool) -> String:
	"""`halves` halves of measure `m`: "a sack of barley", "half a sack of barley", "1½ sacks of barley", "12 sacks of
	barley" -- or, in a cell, "1 sack", "½ sack", "1½ sacks", "12 sacks"."""
	var of: String = " of " + _noun[row] if _of[m] == 1 and not cell else ""
	if halves == 2 and not cell:
		return "%s %s%s" % [_article(_one[m]), _one[m], of]
	if halves == 1:
		return ("%s %s" % [HALF_GLYPH, _one[m]]) if cell else "half %s %s%s" % [_article(_one[m]), _one[m], of]
	return "%s %s%s" % [_number(halves), _one[m] if halves == 2 else _many[m], of]


static func _number(halves: int) -> String:
	"""A count in halves as it is printed: "3", "1½", "½", "1,234"."""
	@warning_ignore("integer_division") var whole: int = halves / 2
	var words: String = _grouped(whole) if whole > 0 else ""
	return words + HALF_GLYPH if halves % 2 == 1 else words


static func _article(word: String) -> String:
	"""'a' or 'an' before `word` ("an onion", "a sack")."""
	return "an" if "aeiou".contains(word.left(1)) else "a"


static func _grouped(n: int) -> String:
	"""A whole number with thousands grouped: "1,234"."""
	var digits: String = str(n)
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


# --- weights ------------------------------------------------------------------------------------------------------

static func _weight_sentence(row: int, milli: int, rounding: int) -> String:
	"""An amount below every measure, in a sentence: "40 g of herbs"; "a trace of herbs" under a gram."""
	return "%s of %s" % [_weight_words(row, milli, rounding), _noun[row]]


static func _weight_words(row: int, milli: int, rounding: int) -> String:
	"""An amount below every measure as its weight ("40 g", "1.8 kg"), floored for a stock and raised for a need;
	"a trace" for something under a gram, so nothing present ever reads 0; "0 g" for nothing."""
	if milli <= 0:
		return "0 g"
	var g: int = _div(milli * _mass_g[row], MILLI_PER_U, rounding)
	return TRACE if g <= 0 else _grams_text(g, rounding)


static func _grams_text(g: int, rounding: int) -> String:
	"""Grams as they are shown: "625 g" below a kilogram; from it, kg to 10 g with trailing zeros dropped ("62.5 kg",
	"4.75 kg", "5 kg"), floored -- or, for a need, raised."""
	if g < KG_FROM_G:
		return "%d g" % g
	var tens: int = _div(g, KG_STEP_G, rounding)
	@warning_ignore("integer_division") var kg: int = tens / 100
	var frac: String = ("%02d" % (tens % 100)).trim_suffix("0").trim_suffix("0")
	return "%s kg" % _grouped(kg) if frac.is_empty() else "%s.%s kg" % [_grouped(kg), frac]


static func _litres_text(g: int) -> String:
	"""A liquid's volume (a litre a kilogram): "10 litres", "1 litre", "250 ml"."""
	if g < KG_FROM_G:
		return "%d ml" % g
	var words: String = _grams_text(g, ROUND_DOWN).trim_suffix(" kg")
	return "%s litre" % words if words == "1" else "%s litres" % words


# --- the table ----------------------------------------------------------------------------------------------------

static func _row(good: StringName) -> int:
	"""The good's row; -1 and an error for a good with no row (see UNKNOWN)."""
	_compile()
	if not _row_of.has(good):
		push_error("goods_measures: no measure for the good '%s' -- add its row (decision 1011, 1801)" % good)
		return -1
	return int(_row_of[good])


static func _compile() -> void:
	"""Build the packed table from ROWS once, weighing each row by its catalogue mass."""
	if not _row_of.is_empty():
		return
	var masses: Dictionary = _catalogue_masses()
	for row: int in ROWS.size():
		var r: Array = ROWS[row]
		_row_of[r[0]] = row
		_mass_g.append(int(masses.get(r[1], 0)))
		_noun.append(r[2])
		_liquid.append(r[3])
		_first.append(_one.size())
		_count.append((r[4] as Array).size())
		for measure: Array in r[4]:
			_add_measure(measure)


static func _add_measure(measure: Array) -> void:
	"""Append one measure's columns."""
	_one.append(measure[0])
	_many.append(measure[1])
	_milli.append(measure[2])
	_from.append(measure[3])
	_halves.append(measure[4])
	_of.append(measure[5])


static func _catalogue_masses() -> Dictionary:
	"""Every catalogue item's mass_g by key, read through item_definitions.gd into a one-slot inventory (the
	catalogue's own loader and validator: never retyped here)."""
	var inventory := InventoryScript.new(1, 1)
	var definitions := ItemDefinitionsScript.new()
	var masses: Dictionary = {}
	if not definitions.load_default(inventory).ok:
		push_error("goods_measures: the item catalogue did not load")
		return masses
	for r: Array in ROWS:
		masses[r[1]] = inventory.item_mass_g(definitions.compiled_id(r[1]))
	return masses
