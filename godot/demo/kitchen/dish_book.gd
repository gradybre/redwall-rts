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
##
## THE FAMILIES BRENDAN DIRECTED (decision 0603, DEC-045, 2026-10-01: "add in everything for 5 now"), and his tuning
## experiments E2 and E3. Their `gdd_row` is a NEW recipe row in §5.7's format, drafted and then CONFIRMED by him ("Approve all"; 0603's
## table) -- woodland_pie alone is §5.7's own:
##   oatcake        Breakfast oatcake          rakkety_tam    oatcake (new)        oats                    cookable
##   farl           Barley farl                taggerung      farl (new)           barley                  cookable
##   hardtack       Haversack hardtack         rakkety_tam    hardtack (new)       flour                   cookable
##   salad          Spring salad               outcast        salad (new)          greens + roots          cookable
##   baked_fish     Baked fish (E2)            mossflower     baked_fish (new)     fresh fish, no roots    cookable
##   biscuit_soup   Durral's dried-fish        pearls_lutra   fish_biscuit_soup    dried fish + flour +    cookable
##                  biscuit soup (E3)                        (new)                roots
##   pasty          Vegetable pasty            salamandastron pasty (new)          flour, roots, greens,   cookable
##                                                                                + nuts
##   root_pie       Turnip, potato and         martin_warrior root_pie (new)       flour, turnip or beet-  waits:
##                  beetroot pie                                                  root, potato, nuts      potato
##   woodland_pie   Woodland pie               (the GDD's)    woodland_pie         flour, mushrooms, roots cookable
##   scones         Hazelnut scones            martin_warrior scones (new)         flour + nuts            cookable
##   cordial        Raspberry cordial          lord_brocktree cordial (new)        berries + honey         waits: honey
## A dish whose ingredient the demo cannot yet produce WAITS: it is listed, never hidden, with its reason
## (PENDING_SOURCES). An input of category NEEDS names items by their pantry key -- items another lane owns -- and takes
## its category from them. The library's hazelnut, mushroom and raspberry are the foraging lane's `nuts`, `mushrooms` and
## `berries` (farm_catalog.gd THE WOODS' FORAGE, decision 0681): the batch 7 integration mapped them so and struck them
## from PENDING_SOURCES (decision 0902). Potato and honey still wait.
## The cordial is a DRINK: never chosen for a meal (the feasts lane serves drinks); it is listed with its recipe.
##
## THE FEAST'S SECOND COURSE (decision 0682): nut_loaf, the library's Nutbread cooked as §5.7's own `nut_loaf` row
## (flour 2 + nuts 2, the GDD's numbers), is an OCCASION dish -- never a meal's choice, cooked only as the Hearth feast's
## second course (meal_rules.gd DISH_NUT_LOAF; added to the book at the batch 7 integration, decision 0902).

const FarmingScript := preload("res://scripts/core/farming.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")

const BREAKFAST: int = 0
const SUPPER: int = 1
## Not a meal: a drink (meal_rules.gd: never chosen for breakfast or supper).
const DRINK: int = 2
## Not a meal: an occasion's course alone, cooked only when an occasion names it (kitchen.gd `set_occasion`), never by
## the cook's choice -- the Hearth feast's nut loaf (decision 0682; batch 7 integration, decision 0902).
const OCCASION: int = 3
## An input whose items another lane defines: its category is theirs (meal_rules.gd resolves it, or the input waits).
const NEEDS: int = -1
const FLOUR: int = Catalog.CAT_FLOUR
const DRIED_FISH: int = Catalog.CAT_DRIED_FISH
const HONEY: int = Catalog.CAT_HONEY
const BEANS: int = FarmingScript.CROP_BEANS
const GREENS: int = FarmingScript.CROP_CABBAGE
const GRAIN: int = FarmingScript.CROP_GRAIN
const ROOTS: int = FarmingScript.CROP_ROOTS
const FISH: int = Catalog.CAT_FISH
const NUTS: int = Catalog.CAT_NUTS

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
	{"key": &"oatcake", "name": "Breakfast oatcake", "short": "oatcakes",
		"library": "rakkety_tam::RAK_recipe_breakfast_oatcake", "gdd_row": "oatcake", "meal": BREAKFAST,
		"portions": 2, "np": 1800, "work_mwu": 14000, "shelf_hours": 72, "water_milli": 1000,
		"inputs": [[GRAIN, 2000, [&"oats"]]]},
	{"key": &"farl", "name": "Barley farl", "short": "farls",
		"library": "taggerung::TAG_recipe_barley_farl", "gdd_row": "farl", "meal": BREAKFAST,
		"portions": 2, "np": 1800, "work_mwu": 14000, "shelf_hours": 48, "water_milli": 1000,
		"inputs": [[GRAIN, 2000, [&"barley"]]]},
	{"key": &"hardtack", "name": "Haversack hardtack", "short": "hardtack",
		"library": "rakkety_tam::RAK_recipe_haversack_hardtack", "gdd_row": "hardtack", "meal": BREAKFAST,
		"portions": 2, "np": 1800, "work_mwu": 16000, "shelf_hours": 480, "water_milli": 500,
		"inputs": [[FLOUR, 2000, []]]},
	{"key": &"salad", "name": "Spring salad", "short": "salad",
		"library": "outcast::OUT_recipe_spring_salad", "gdd_row": "salad", "meal": SUPPER,
		"portions": 2, "np": 1400, "work_mwu": 6000, "shelf_hours": 12, "water_milli": 500,
		"inputs": [[GREENS, 2000, []], [ROOTS, 1000, []]]},
	{"key": &"baked_fish", "name": "Baked fish", "short": "baked fish",
		"library": "mossflower::MF_recipe_baked_fish", "gdd_row": "baked_fish", "meal": SUPPER,
		"portions": 2, "np": 1900, "work_mwu": 14000, "shelf_hours": 24, "water_milli": 500,
		"inputs": [[FISH, 2000, []]]},
	{"key": &"biscuit_soup", "name": "Durral's dried-fish biscuit soup", "short": "biscuit soup",
		"library": "pearls_lutra::PL_RECIPE_durral_s_dried_fish_biscuit_soup", "gdd_row": "fish_biscuit_soup",
		"meal": SUPPER, "portions": 3, "np": 2000, "work_mwu": 20000, "shelf_hours": 24, "water_milli": 2000,
		"inputs": [[DRIED_FISH, 1000, []], [FLOUR, 1000, []], [ROOTS, 1000, []]]},
	{"key": &"pasty", "name": "Vegetable pasty", "short": "pasties",
		"library": "salamandastron::SAL_recipe_vegetable_pasty", "gdd_row": "pasty", "meal": SUPPER,
		"portions": 3, "np": 2200, "work_mwu": 24000, "shelf_hours": 48, "water_milli": 500,
		"inputs": [[FLOUR, 2000, []], [ROOTS, 1000, []], [GREENS, 1000, []], [NEEDS, 500, [&"nuts"]]]},
	{"key": &"root_pie", "name": "Turnip, potato and beetroot pie", "short": "root pie",
		"library": "martin_warrior::MW_RECIPE_turnip_potato_and_beetroot_pie", "gdd_row": "root_pie", "meal": SUPPER,
		"portions": 4, "np": 2300, "work_mwu": 32000, "shelf_hours": 48, "water_milli": 500,
		"inputs": [[FLOUR, 2000, []], [ROOTS, 2000, [&"turnip", &"beetroot"]], [ROOTS, 1000, [&"potato"]],
			[NEEDS, 500, [&"nuts"]]]},
	{"key": &"woodland_pie", "name": "Woodland pie", "short": "woodland pie",
		"library": "", "gdd_row": "woodland_pie", "meal": SUPPER,
		"portions": 3, "np": 2300, "work_mwu": 30000, "shelf_hours": 48, "water_milli": 1000,
		"inputs": [[FLOUR, 2000, []], [NEEDS, 2000, [&"mushrooms"]], [ROOTS, 1000, []]]},
	{"key": &"scones", "name": "Hazelnut scones", "short": "scones",
		"library": "martin_warrior::MW_RECIPE_hazelnut_scones", "gdd_row": "scones", "meal": BREAKFAST,
		"portions": 3, "np": 1800, "work_mwu": 20000, "shelf_hours": 48, "water_milli": 1000,
		"inputs": [[FLOUR, 2000, []], [NEEDS, 500, [&"nuts"]]]},
	{"key": &"cordial", "name": "Raspberry cordial", "short": "cordial",
		"library": "lord_brocktree::LB-RECIPE-raspberry-cordial", "gdd_row": "cordial", "meal": DRINK,
		"portions": 4, "np": 500, "work_mwu": 10000, "shelf_hours": 72, "water_milli": 2000,
		"inputs": [[NEEDS, 2000, [&"berries"]], [HONEY, 500, []]]},
	{"key": &"nut_loaf", "name": "Nutbread", "short": "nut loaf",
		"library": "redwall::RW-RECIPE-nutbread", "gdd_row": "nut_loaf", "meal": OCCASION,
		"portions": 3, "np": 2600, "work_mwu": 24000, "shelf_hours": 72, "water_milli": 1000,
		"inputs": [[FLOUR, 2000, []], [NUTS, 2000, []]]},
]

## The §5.7 recipe rows the GDD adopts; every other `gdd_row` here is one of Brendan's DEC-045 rows (decision 0603).
const ADOPTED_ROWS: Array[String] = ["porridge", "root_stew", "fish_stew", "bean_hotpot", "woodland_pie", "nut_loaf"]

## WHERE A MISSING INGREDIENT WILL COME FROM, by item key: a dish taking one waits, saying so ("needs potato: grown in
## the fields, not yet planted in the demo"). The lane that lands a source deletes its key here (and a NEEDS key resolves itself once its
## item exists).
const PENDING_SOURCES: Dictionary = {
	&"potato": "grown in the fields, not yet planted in the demo",
	&"honey": "made in beehives, not yet in the demo",
}
