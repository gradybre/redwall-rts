extends RefCounted
## THE KITCHEN'S RECIPE BOOK: one row per dish the village can cook -- the data every other kitchen table is built from
## (meal_rules.gd builds its columns from DISHES once, at load). Decision 0601 (feature 16, Brendan's approval of
## 2026-10-01); the first three rows are decisions 0381 and 0436. Presentation only: the settlement simulation is never
## written.
##
## ADDING A RECIPE is adding a row. Each row is a content-library dish COOKED AS one GDD §5.7 recipe row, whose numbers
## it carries exactly (CONTENT-LIB-001 LIB-008: a library candidate has no numbers of its own until an owning
## specification gives them; §5.7 is that specification). A row's fields:
##   key          StringName, unique: the dish's id in the guide (`dish_<key>`) and the favourites table
##   name, short  what the panels call it, in full and in a word or two
##   library      the book-qualified recipe id it is (docs/redwall-content-library/shared/recipes.json); "" for a dish
##                that is the GDD's own (bean_hotpot: no library dish has its beans and greens)
##   gdd_row      the §5.7 recipe id it is cooked as -- also its identity for §5.7's variety: "Ingredient differences
##                inside the same recipe do not fake variety"
##   meal         the meal it is cooked for (meal_rules.gd MEAL_*); another meal cooks it only when none of its own
##                dishes has a batch's food (decision 0381's ruling 1, generalised)
##   portions, np, work_mwu, shelf_hours, water_milli   §5.7's outputs, nutrition, WU, shelf and water, exactly
##   inputs       the food it takes: [category, milli-U a batch, items]. The category is §5.7's input (a §5.6 crop row,
##                or the pantry's fish: farm_catalog.gd category_of); the milli-U are §5.7's; `items` ([] for the whole
##                category) narrows it to the library dish's own ingredients within that category -- Wild-beetroot soup
##                takes beetroot and onion, never parsnip -- so a dish is cooked only from what it is made of.
## Wood is not a row field: every batch burns BAL-SUPPLY-004's 0.1 U (meal_rules.gd WOOD_MILLI_PER_BATCH).
##
## THE ROWS (provenance in decision 0601):
##   porridge       Wild oat porridge          salamandastron  porridge    any grain               (0381)
##   soup           Togget's vegetable soup    outcast         root_stew   any roots               (0381)
##   fish_stew      Poached perch or trout     taggerung       fish_stew   any fresh fish + roots  (0436)
##   barleymeal     Barleymeal porridge        pearls_lutra    porridge    barley or oats
##   beetroot_soup  Wild-beetroot soup         triss           root_stew   beetroot or onion
##   vole_stew      Vole vegetable stew        taggerung       root_stew   carrot, onion or turnip
##   poached_dace   Poached dace               taggerung       fish_stew   dace + any roots
##   bean_hotpot    Bean hotpot                (the GDD's)     bean_hotpot any beans + any greens
## The fish-stew rows' roots are §5.7's second input, which the library's poached fish do not name (as decision 0436).
## bean_hotpot's §5.7 unlock is M1; the demo runs no milestones, so unlocks are not evaluated (as the fishing driver's).
## Rows 0-2 keep their indices: the meal store, the logs and the guide's ids refer to them.

const FarmingScript := preload("res://scripts/core/farming.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

const BREAKFAST: int = 0
const SUPPER: int = 1
const BEANS: int = FarmingScript.CROP_BEANS
const GREENS: int = FarmingScript.CROP_CABBAGE
const GRAIN: int = FarmingScript.CROP_GRAIN
const ROOTS: int = FarmingScript.CROP_ROOTS
const FISH: int = Catalog.CAT_FISH

const DISHES: Array[Dictionary] = [
	{"key": &"porridge", "name": "Wild oat porridge", "short": "porridge",
		"library": "salamandastron::SAL_recipe_wild_oat_porridge", "gdd_row": "porridge", "meal": BREAKFAST,
		"portions": 2, "np": 1800, "work_mwu": 12000, "shelf_hours": 24, "water_milli": 2000,
		"inputs": [[GRAIN, 2000, []]]},
	{"key": &"soup", "name": "Togget's vegetable soup", "short": "soup",
		"library": "outcast::OUT_recipe_togget_s_vegetable_soup", "gdd_row": "root_stew", "meal": SUPPER,
		"portions": 2, "np": 1800, "work_mwu": 16000, "shelf_hours": 24, "water_milli": 1000,
		"inputs": [[ROOTS, 3000, []]]},
	{"key": &"fish_stew", "name": "Poached perch or trout", "short": "fish stew",
		"library": "taggerung::TAG_recipe_requested_perch_or_trout", "gdd_row": "fish_stew", "meal": SUPPER,
		"portions": 3, "np": 2200, "work_mwu": 20000, "shelf_hours": 24, "water_milli": 2000,
		"inputs": [[FISH, 2000, []], [ROOTS, 2000, []]]},
	{"key": &"barleymeal", "name": "Barleymeal porridge", "short": "barleymeal porridge",
		"library": "pearls_lutra::PL_RECIPE_barleymeal_porridge", "gdd_row": "porridge", "meal": BREAKFAST,
		"portions": 2, "np": 1800, "work_mwu": 12000, "shelf_hours": 24, "water_milli": 2000,
		"inputs": [[GRAIN, 2000, [&"barley", &"oats"]]]},
	{"key": &"beetroot_soup", "name": "Wild-beetroot soup", "short": "beetroot soup",
		"library": "triss::TRI_recipe_wild_beetroot_soup", "gdd_row": "root_stew", "meal": SUPPER,
		"portions": 2, "np": 1800, "work_mwu": 16000, "shelf_hours": 24, "water_milli": 1000,
		"inputs": [[ROOTS, 3000, [&"beetroot", &"onion"]]]},
	{"key": &"vole_stew", "name": "Vole vegetable stew", "short": "vole stew",
		"library": "taggerung::TAG_recipe_vole_vegetable_stew", "gdd_row": "root_stew", "meal": SUPPER,
		"portions": 2, "np": 1800, "work_mwu": 16000, "shelf_hours": 24, "water_milli": 1000,
		"inputs": [[ROOTS, 3000, [&"carrot", &"onion", &"turnip"]]]},
	{"key": &"poached_dace", "name": "Poached dace", "short": "poached dace",
		"library": "taggerung::TAG_recipe_poached_dace", "gdd_row": "fish_stew", "meal": SUPPER,
		"portions": 3, "np": 2200, "work_mwu": 20000, "shelf_hours": 24, "water_milli": 2000,
		"inputs": [[FISH, 2000, [&"dace"]], [ROOTS, 2000, []]]},
	{"key": &"bean_hotpot", "name": "Bean hotpot", "short": "bean hotpot",
		"library": "", "gdd_row": "bean_hotpot", "meal": SUPPER,
		"portions": 3, "np": 2100, "work_mwu": 20000, "shelf_hours": 36, "water_milli": 2000,
		"inputs": [[BEANS, 2000, []], [GREENS, 2000, []]]},
]
