extends RefCounted
## What the demo farm grows, and where. Decision 0196 (live demo), farming increment.
##
## ---------------------------------------------------------------------------------------
## INDIVIDUAL INGREDIENTS, REAL CROP ARITHMETIC. Brendan: "individual items should be farmed, that
## will feed into potential ingredients for cooking. ie. a radish is a radish, not a food." So a bed
## grows a SPECIFIC plant chosen from the content library's pantry -- each item below is a
## `game_leaf_inputs` LEAF of docs/redwall-content-library/shared/pantry.json, named by its exact
## LEAF id -- and its harvest goes into the demo pantry AS THAT ITEM. The growth, ripening, yield,
## frost, blight, moisture and rotation arithmetic is the settlement's own (scripts/core/farming.gd,
## GDD §5.6), which has exactly five CropDefinition rows. Each item therefore names the ONE §5.6 row
## whose numbers it grows by -- its growth hours, yield, soils, plant windows, moisture band, frost
## damage, fertility cost and rotation FAMILY -- and every item of one row grows identically. A
## radish and a turnip differ in what they are, not in how fast they grow: giving them different
## numbers would be inventing constants no document states (AGENTS.md).
##
## THE MAPPING IS AN AUTHORED DEMO CHOICE, cited to what each row is for:
##   §5.6 Roots   / ROOT   (loam, sand):  radish, turnip, carrot, beetroot, parsnip, onion
##   §5.6 Cabbage / LEAF   (loam, clay):  cabbage, lettuce, spinach, leek, celery
##   §5.6 Beans   / LEGUME (loam, clay):  pea, broad bean
##   §5.6 Grain   / CEREAL (loam, clay):  wheat, barley, oats
## Roots are the underground crops (onion is a bulb, harvested from the soil like the rest); the
## leaf row takes the plants eaten for their leaf or leaf-stalk (leek and celery included, so the
## two alliums split across two rotation families -- a demo simplification, stated); the legume
## row takes the pod crops; the grain row the cereals. The storage category that sets an item's
## shelf life follows the same row (§5.7: roots 240 h, cabbage 144 h, beans 480 h, grain 720 h,
## which `data/item_definitions.json` also carries and test_demo_farm.gd compares).
##
## EXCLUDED, and why (reported for decision 0196):
##   * FLAX (§5.6 FIBER row): not in the pantry at all -- it is cloth and rope (§5.7), not food.
##     The demo offers no fibre crop, so the FIBER row is never planted.
##   * STRAWBERRY (a pantry leaf): no §5.6 row fits a perennial soft fruit; the orchard rows are
##     trees. Mapping it onto a vegetable row would invent its growth.
##   * The library's FICTIONAL leaves (`fictional hotroot spice`, `fictional ditchnettle spice`)
##     and its `cultivated game ...` counterparts: the handoff (§4) makes those stand-ins for
##     uncertain source plants, not field crops, and no §5.6 row describes them.
##   * Livestock, dairy and eggs are excluded pipelines (pantry `policy.excluded_food_pipelines`);
##     no field crop is affected.
## Everything else in the pantry was simply not selected: this is a six-bed demo, and each §5.6 row
## already has two to six items.
##
## ACTIVATION. Every library record stays NOT_RUNTIME_ACTIVE (CONTENT-LIB-001 LIB-008,
## PANTRY-005). The demo uses the leaf IDENTITY and label as a presentation name, takes every
## number from §5.6/§5.7, and shows library dishes only as candidates (pantry_index.json).
##
## BEDS. The six world crop beds (world/world_layout.gd CROPS), the south field's six (decision 0886) and the kitchen
## garden's four sites (decision 0883), one FarmPlot row each. §5.1's soil
## bands belong to the unbuilt world generator, so each bed's soil is a DEMO value, varied so the
## soil filter means something: sand refuses the loam/clay rows, clay refuses roots.

const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Layout := preload("res://demo/world/world_layout.gd")

const REFUSE_NO_BED: String = "NO_BED_THERE"

const NO_ITEM: int = -1

## The farmed ingredients: key, label, pantry LEAF id and the §5.6 crop row each grows by. ITEM_KEYS, ITEM_LABELS,
## ITEM_PROP and ITEM_SWATCH run on past the sixteen crops to the PANTRY'S OTHER GOODS (see below); every crop-only
## table (ITEM_LEAVES, ITEM_CROP, the visuals) stops at ITEM_COUNT.
const ITEM_KEYS: Array[StringName] = [
	&"radish", &"turnip", &"carrot", &"beetroot", &"parsnip", &"onion",
	&"cabbage", &"lettuce", &"spinach", &"leek", &"celery",
	&"pea", &"broad_bean",
	&"wheat", &"barley", &"oats",
	&"trout", &"dace", &"salmon", &"perch", &"carp", &"whitefish",
	&"dried_fish", &"flour",
	&"potato", &"honey",
	&"nuts", &"mushrooms", &"herb", &"berries",
	&"apple", &"pear",
	&"dried_fruit", &"ration",
	&"mead", &"cordial",
	&"jam", &"cheese", &"ale", &"cider",
]
const ITEM_LABELS: Array[String] = [
	"Radish", "Turnip", "Carrot", "Beetroot", "Parsnip", "Onion",
	"Cabbage", "Lettuce", "Spinach", "Leek", "Celery",
	"Pea", "Broad bean",
	"Wheat", "Barley", "Oats",
	"Trout", "Dace", "Salmon", "Perch", "Carp", "Whitefish",
	"Dried fish", "Flour",
	"Potato", "Honey",
	"Nuts", "Mushrooms", "Herbs", "Berries",
	"Apple", "Pear",
	"Dried fruit", "Rations",
	"Mead", "Cordial",
	"Berry jam", "Nut cheese", "Ale", "Cider",
]
const ITEM_LEAVES: Array[String] = [
	"LEAF_radish", "LEAF_turnip", "LEAF_carrot", "LEAF_beetroot", "LEAF_parsnip", "LEAF_onion",
	"LEAF_cabbage", "LEAF_lettuce", "LEAF_spinach", "LEAF_leek", "LEAF_celery",
	"LEAF_pea", "LEAF_broad_bean",
	"LEAF_wheat", "LEAF_barley", "LEAF_oats",
]
const ITEM_CROP: Array[int] = [
	FarmingScript.CROP_ROOTS, FarmingScript.CROP_ROOTS, FarmingScript.CROP_ROOTS,
	FarmingScript.CROP_ROOTS, FarmingScript.CROP_ROOTS, FarmingScript.CROP_ROOTS,
	FarmingScript.CROP_CABBAGE, FarmingScript.CROP_CABBAGE, FarmingScript.CROP_CABBAGE,
	FarmingScript.CROP_CABBAGE, FarmingScript.CROP_CABBAGE,
	FarmingScript.CROP_BEANS, FarmingScript.CROP_BEANS,
	FarmingScript.CROP_GRAIN, FarmingScript.CROP_GRAIN, FarmingScript.CROP_GRAIN,
]
const ITEM_COUNT: int = 16

## THE PANTRY'S OTHER GOODS (decision 0431, water part B): what the water and the stations put in the pantry beside the
## crops, each an item of `data/item_definitions.json` with its §5.7 row's shelf life:
##   * the six freshwater species the demo's water holds -- the stream's trout, dace and salmon (the river habitat)
##     and the pond's perch, carp and whitefish (the lake) -- each its OWN item, never a generic "fish" (BAL-CAT-004;
##     SET-AMEND-001's whitelist). §5.7: "All fish species except mussel | 1400 | No | 48". Herring, mackerel and
##     mussel are the coast's: the demo has no coast, so none is ever caught and none has a pantry item. Eel and pike
##     are hazards, never food (REQ-SET-056); shrimp is not a game fish.
##   * dried fish, §5.7's `dry_fish` output: 720 h, directly edible ("Dried/salted fish ... are directly edible").
##   * flour, §5.7's `flour` output: "Grain/flour | 1200 | No | 720/240" -- 240 h, not eaten raw.
## Their CATEGORY (what a recipe asks for) extends the §5.6 crop rows past FarmingScript's five: CAT_FISH is §5.7's
## `fish` selector over the species (BAL-CAT-004), CAT_DRIED_FISH and CAT_FLOUR their own items.
##   * potato and honey (decision 0603, DEC-045): ingredients of the kitchen's dishes that the demo has NO SOURCE for
##     yet -- defined so a dish can name them and a source lane can fill them. Potato (pantry LEAF_potato) is a tuber,
##     so it is in the §5.6 roots row, as the onion is (240 h; the GDD's roots are raw-edible -- the crops lane plants it
##     and may revisit that); honey (LEAF_honey) is §5.7's `Honey | 1200 | Yes | 1440` (CAT_HONEY), the hives' output.
## THE WOODS' FORAGE (decision 0681, foraging trips): four of §5.5's five forage items, gathered by a foraging trip from
## the woods' forage basin (demo/forage/) -- each the compiled catalogue's own key (`data/item_definitions.json`, the
## keys scripts/core/forage.gd PATCH_KEYS names), never a generic "forage" item:
##   * nuts       §5.7 "Nuts | 1600 | Yes | 720" -- raw edible, keeps 720 h;
##   * mushrooms  §5.7 "Mushrooms | 600 | No | 72" -- not eaten raw, keeps 72 h;
##   * herb       §5.7 "Herb | 0 | No | 480 | Care ingredient; no nutritional replacement" -- keeps 480 h;
##   * berries    §5.7 "Berries | 700 | Yes | 48" -- raw edible, keeps 48 h (added at the dishes lane's request: its
##                cordial's raspberries are forage; the catalogue's key is `berries`).
## Each is its own category (CAT_NUTS, CAT_MUSHROOMS, CAT_HERB, CAT_BERRIES): §5.7's recipes name them as inputs. Roots,
## §5.5's fifth patch, are not gathered (the farm grows its roots). The dishes lane's hazelnut, mushroom and raspberry
## are these nuts, mushrooms and berries (dish_book.gd; batch 7 integration, decision 0902), the items after potato and
## honey.
## THE ORCHARD'S FRUIT (decision 0671; demo/orchard/): the orchard trees' `apple` and `pear`, each the content library's
## own LEAF key (LEAF_apple, LEAF_pear -- "a radish is a radish") and §5.7's `fruit` row ("Fruit | 900 | Yes | 144",
## CAT_FRUIT -- §5.6's two orchard species, scripts/core/orchard_hive.gd SPECIES_KEYS), the items after the forage. The
## hedge's raspberries, blackberries and strawberries are the ONE generic `berries` item above, the foraging lane's
## (Brendan's ruling of 2026-10-01, decision 0676; batch 8 integration, decision 0903). A recipe that names `fruit` or
## `berries` takes them by category, as `fish` takes the species.
## THE PRESERVES (decision 1611, PRESERVE #18): §5.7's two preserving rows the demo can make, after the fruit --
##   * dried_fruit  §5.7 `dry_fruit`'s output, fruit 4 -> 3 x 1400 NP at the Dryer (the smoking rack: decision 0434),
##                  720 h, directly edible ("dried fruit is directly edible") -- CAT_DRIED_FRUIT;
##   * ration       §5.7 `ration`'s output, flour 2 + dried fish 1 + nuts 1 + water 1 -> 3 x 2400 NP at the kitchen's
##                  preserving table, 1440 h, directly edible ("rations are directly edible") -- CAT_RATION.
## Salt fish waits for a coast (salt is coastal brine only); jam, pickles and cheese have no GDD row (Q-D5).
## THE DRINKS (decision 1621, BREW #19), after the preserves -- kept for feasts, never eaten as a meal:
##   * mead     §5.7 `mead`'s output, honey 3 + water 3 -> mead 4 at the brewery (72 h in a vat), "Mead | 0 | No | 1440 |
##              Feast ingredient only; no intoxication subsystem" -- CAT_MEAD;
##   * cordial  Brendan's DEC-045 raspberry cordial (dish_book.gd `cordial`: berries 2 + honey 0.5 + water 2 -> 4, 72 h),
##              made at the brewery's bench and kept as a drink -- CAT_CORDIAL.
## THE NEW RECIPES (decision 1625; Brendan's "Approve and build Q-d5 and dec-007", 2026-10-07), after the drinks -- each
## a content-library dish drafted as a recipe row with PROVISIONAL numbers (preserve_rules.gd):
##   * jam     berries cooked with honey and water (the library's honey-sweetened fruit jams) -- CAT_JAM, eaten as it is;
##   * cheese  the library's salt-free nut cheese (taggerung TAG_recipe_nut_cheese) -- CAT_CHEESE, eaten as it is;
##   * ale     barley and water brewed (the library's October ale) -- CAT_ALE, a drink only, like mead;
##   * cider   apples and water (the library's pale cider) -- CAT_CIDER, a drink only, like mead.
## Pickles are not built: every library pickle takes salt, and the demo has none (decision 1625).
const PANTRY_ITEM_COUNT: int = 40
const FIRST_CATCH: int = 16
const CATCH_COUNT: int = 6
const ITEM_DRIED_FISH: int = 22
const ITEM_FLOUR: int = 23
const ITEM_POTATO: int = 24
const ITEM_HONEY: int = 25
const ITEM_NUTS: int = 26
const ITEM_MUSHROOMS: int = 27
const ITEM_HERB: int = 28
const ITEM_BERRIES: int = 29
const FIRST_FORAGE: int = 26
const FORAGE_COUNT: int = 4
const ITEM_APPLE: int = 30
const ITEM_PEAR: int = 31
const ITEM_DRIED_FRUIT: int = 32
const ITEM_RATION: int = 33
const ITEM_MEAD: int = 34
const ITEM_CORDIAL: int = 35
const ITEM_JAM: int = 36
const ITEM_CHEESE: int = 37
const ITEM_ALE: int = 38
const ITEM_CIDER: int = 39
## The crops and fruit the new recipes name by item (decision 1625).
const ITEM_BARLEY: int = 14
const FIRST_FRUIT: int = 30
const FRUIT_COUNT: int = 2
## Every item the orchard and the hedge yield (a list, not a range: the hedge's `berries` is the forage item, numbered
## away from the fruit).
const ORCHARD_ITEMS: PackedInt32Array = [ITEM_APPLE, ITEM_PEAR, ITEM_BERRIES]
const CAT_FISH: int = 5
const CAT_DRIED_FISH: int = 6
const CAT_FLOUR: int = 7
const CAT_HONEY: int = 8
const CAT_NUTS: int = 9
const CAT_MUSHROOMS: int = 10
const CAT_HERB: int = 11
const CAT_BERRIES: int = 12
const CAT_FRUIT: int = 13
const CAT_DRIED_FRUIT: int = 14
const CAT_RATION: int = 15
const CAT_MEAD: int = 16
const CAT_CORDIAL: int = 17
const CAT_JAM: int = 18
const CAT_CHEESE: int = 19
const CAT_ALE: int = 20
const CAT_CIDER: int = 21
## The goods' categories and §5.7 shelf hours, from FIRST_CATCH on.
const GOODS_CATEGORY: Array[int] = [CAT_FISH, CAT_FISH, CAT_FISH, CAT_FISH, CAT_FISH, CAT_FISH, CAT_DRIED_FISH, CAT_FLOUR,
	FarmingScript.CROP_ROOTS, CAT_HONEY, CAT_NUTS, CAT_MUSHROOMS, CAT_HERB, CAT_BERRIES, CAT_FRUIT, CAT_FRUIT,
	CAT_DRIED_FRUIT, CAT_RATION, CAT_MEAD, CAT_CORDIAL, CAT_JAM, CAT_CHEESE, CAT_ALE, CAT_CIDER]
const GOODS_SHELF_HOURS: Array[int] = [48, 48, 48, 48, 48, 48, 720, 240, 240, 1440, 720, 72, 480, 48, 144, 144, 720,
	1440, 1440, 72, 720, 480, 1440, 1440]
## scripts/core/forage.gd PATCH_KEYS row (berries, nuts, mushrooms, herb, roots) -> pantry item (NO_ITEM: not gathered).
const PATCH_ITEM: Array[int] = [ITEM_BERRIES, ITEM_NUTS, ITEM_MUSHROOMS, ITEM_HERB, NO_ITEM]
## scripts/core/orchard_hive.gd SPECIES_KEYS row (apple, pear) -> pantry item.
const ORCHARD_SPECIES_ITEM: Array[int] = [ITEM_APPLE, ITEM_PEAR]
## scripts/core/fishing.gd SPECIES_KEYS row -> pantry item (NO_ITEM: the coast's three, which the demo cannot catch).
const SPECIES_ITEM: Array[int] = [16, 17, 18, 19, 20, 21, NO_ITEM, NO_ITEM, NO_ITEM]

## §5.7's base shelf hours by §5.6 crop row (beans, cabbage, flax, grain, roots). Flax is 0: an
## unlimited-shelf material, and never farmed here.
const CROP_SHELF_HOURS: Array[int] = [480, 144, 0, 720, 240]
## The `data/item_definitions.json` ids the same rows store as (for the cross-check).
const CROP_ITEM_ID: Array[StringName] = [&"beans", &"cabbage", &"flax", &"grain", &"roots"]
const FAMILY_NAMES: Array[String] = ["cereal", "fibre", "leaf", "legume", "root"]

## PRESENTATION. Which plant a bed of each item shows (farm_assets.gd loads them), the model it is
## carried and shelved as, and its icon's fallback colour. Decision 0196.
##
## VISUAL KINDS. The twelve library plants (tools/make_demo_props.py: one plant each, rendered to
## alpha cards) give eleven farmed items their OWN plant; strawberry is staged but not farmed (see
## EXCLUDED). The other five have no plant of their own and show the best visual there is: wheat its
## grain cards (crop_grain_ripe, make_demo_crop_cards.py); parsnip the roots bed's carrot cards (a
## carrot-family root, feathery top and a shoulder at the soil, as before); cabbage and spinach the
## roots bed's turnip cards while growing (a leafy rosette) and the staged cabbage bed's heads when
## ripe, as before; and broad bean the PEA plant, darkened -- it used to borrow the carrot cards, whose
## orange shoulders read as carrots in a bean bed, and the pea is the other upright legume.
const VIS_WHEAT: int = 0
const VIS_TURNIP: int = 1
const VIS_CARROT: int = 2
## The plant kinds follow, one per PLANT_KEYS entry: VIS_PLANT_FIRST + its index.
const VIS_PLANT_FIRST: int = 3
const PLANT_KEYS: Array[StringName] = [
	&"plant_radish", &"plant_turnip", &"plant_carrot", &"plant_beetroot", &"plant_onion", &"plant_leek",
	&"plant_lettuce", &"plant_celery", &"plant_peas", &"plant_barley", &"plant_oats",
]
const VIS_COUNT: int = 14
## Each plant's drawn height when ripe, soil to top (metres; DEMO-ONLY, judged against a 1.00 m mouse
## and the old cards: the roots bed's plants stood ~0.5 m, its wheat ~0.68 m). NOT a sizing policy.
const PLANT_HEIGHT_M: Array[float] = [0.38, 0.48, 0.5, 0.5, 0.5, 0.66, 0.34, 0.62, 0.95, 0.74, 0.74]
## How far apart each plant stands, as a share of its card's width (farm_assets.gd plant_grid): the
## rosettes and heads a little closer than their width, as a sown row's leaves overlap; the pea a
## little closer still; the cereals -- each card a clump of a few stalks -- close enough to read as a
## stand, as the wheat's narrow clumps do.
const PLANT_SPACING: Array[float] = [0.62, 0.62, 0.62, 0.62, 0.62, 0.62, 0.62, 0.62, 0.5, 0.34, 0.34]
## Where a rosette's top-down card lies, as a share of its standing card's height, and how much larger
## than the standing cards it is drawn. The leafy rosettes lie at 0.55 (their leaves' mean height);
## the lettuce is a squat head whose three standing cards read as a triangle of flat discs from the
## camera, so its top lies near the head's crown and covers them.
const PLANT_TOP_LIFT: Array[float] = [0.55, 0.55, 0.55, 0.55, 0.55, 0.55, 0.8, 0.55, 0.55, 0.55, 0.55]
const PLANT_TOP_SCALE: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 1.0, 1.0, 1.0, 1.0]
## Plants drawn as their close-up MESH (the plant's 580-triangle L0) once filled out and when ripe,
## rather than as cards: the lettuce, a solid head its cards cannot draw from the camera's height.
## The leafy plants' meshes shatter at that budget (their leaves are too thin), so they stay cards.
const PLANT_HEAD_MESH: Array[bool] = [false, false, false, false, false, false, true, false, false, false, false]
const ITEM_VISUAL: Array[int] = [
	VIS_PLANT_FIRST + 0, VIS_PLANT_FIRST + 1, VIS_PLANT_FIRST + 2, VIS_PLANT_FIRST + 3, VIS_CARROT, VIS_PLANT_FIRST + 4,
	VIS_TURNIP, VIS_PLANT_FIRST + 6, VIS_TURNIP, VIS_PLANT_FIRST + 5, VIS_PLANT_FIRST + 7,
	VIS_PLANT_FIRST + 8, VIS_PLANT_FIRST + 8,
	VIS_WHEAT, VIS_PLANT_FIRST + 9, VIS_PLANT_FIRST + 10,
]
## The leaf crops without a plant of their own show the staged cabbage bed when ripe (its heads).
const ITEM_RIPE_HEADS: Array[bool] = [
	false, false, false, false, false, false,
	true, false, true, false, false,
	false, false,
	false, false, false,
]
## A tint laid over the borrowed cards so a borrowing item reads apart from the item it borrows
## from; an item on its own plant is drawn in the plant's own colours (white) -- but for the onion,
## whose rendered leaves read cyan under the demo's sky light: a little blue is taken out.
const ITEM_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(1.06, 1.05, 0.88), Color(0.94, 1.05, 0.74),
	Color(1.16, 1.0, 0.95), Color(1.0, 1.0, 1.0), Color(0.78, 0.95, 0.8),
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(1.0, 1.0, 1.0), Color(0.84, 1.0, 0.84),
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
]
## The harvested item's model (demo/props/demo_props.gd), carried to the store, shelved and drawn
## as its pantry icon; &"" for the five with none (they carry and shelve nothing, and their icon is
## a roundel in ITEM_SWATCH).
const ITEM_PROP: Array[StringName] = [
	&"item_radish", &"item_turnip", &"item_carrot", &"item_beetroot", &"", &"item_onion",
	&"", &"item_lettuce", &"", &"item_leek", &"item_celery",
	&"item_peas", &"",
	&"", &"item_barley", &"item_oats",
	&"item_trout", &"", &"", &"item_perch", &"", &"",
	&"", &"",
	&"", &"",
	&"", &"", &"", &"item_strawberry",
	&"", &"",
	&"", &"",
	&"", &"",
	&"", &"", &"", &"",
]
## The fallback icon's colour: the item's own, from its produce (parsnip cream, spinach dark leaf).
const ITEM_SWATCH: Array[Color] = [
	Color(0.78, 0.2, 0.24), Color(0.66, 0.38, 0.62), Color(0.9, 0.5, 0.16), Color(0.5, 0.12, 0.22),
	Color(0.88, 0.82, 0.62), Color(0.78, 0.55, 0.3),
	Color(0.42, 0.6, 0.48), Color(0.62, 0.78, 0.4), Color(0.2, 0.4, 0.22), Color(0.5, 0.66, 0.44),
	Color(0.52, 0.72, 0.36),
	Color(0.48, 0.68, 0.3), Color(0.58, 0.7, 0.4),
	Color(0.86, 0.7, 0.36), Color(0.82, 0.68, 0.4), Color(0.84, 0.74, 0.5),
	Color(0.62, 0.6, 0.5), Color(0.66, 0.7, 0.72), Color(0.86, 0.5, 0.42), Color(0.5, 0.6, 0.36),
	Color(0.7, 0.58, 0.32), Color(0.84, 0.84, 0.8),
	Color(0.56, 0.36, 0.22), Color(0.94, 0.9, 0.8),
	Color(0.72, 0.6, 0.4), Color(0.9, 0.66, 0.22),
	Color(0.62, 0.42, 0.22), Color(0.8, 0.7, 0.56), Color(0.44, 0.6, 0.34), Color(0.72, 0.16, 0.3),
	Color(0.74, 0.22, 0.18), Color(0.74, 0.74, 0.34),
	Color(0.6, 0.34, 0.16), Color(0.7, 0.6, 0.42),
	Color(0.86, 0.66, 0.26), Color(0.7, 0.12, 0.24),
	Color(0.58, 0.1, 0.26), Color(0.9, 0.82, 0.58), Color(0.66, 0.42, 0.16), Color(0.86, 0.72, 0.32),
]

## The beds: the six first FIELD beds are world crop ids (BED_IDS); then the SOUTH FIELD's six (see THE SOUTH FIELD); then
## the KITCHEN GARDEN's sites (see THE KITCHEN GARDEN'S SITES). One FarmPlot each, their demo soils.
const BED_IDS: Array[StringName] = [
	&"bed_cabbage_w", &"bed_cabbage_e", &"bed_roots_w", &"bed_roots_e", &"bed_grain_w", &"bed_grain_e",
]
const FIELD_BED_COUNT: int = 12
const BED_COUNT: int = 16
const BED_SOILS: Array[int] = [
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_SAND,
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_LOAM,
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_LOAM,
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_LOAM,
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_LOAM, FarmingScript.SOIL_LOAM, FarmingScript.SOIL_LOAM,
]
## THE SOUTH FIELD (Brendan's balance ruling E5, 2026-10-01: "12-18 farm beds instead of 6"; decision 0886). Six more
## field beds, laid from the start, as ONE rectangular field of six §5.6 tiles -- three across, two deep, 2 m x 2 m each
## (GDD §5.6: "field designation is 4-256 tiles, rectangular or painted connected area") -- on the open grass south of
## the covered store, east of the workbench and north of the boulder. Every tile has an outer edge to work it from; the
## tiles are not walking obstacles (the six world beds are). Checked clear of every obstacle (test_demo_sowing.gd).
const SOUTH_FIRST: int = 6
const SOUTH_BEDS: int = 6
const SOUTH_AT: Array[Vector2] = [Vector2(12.6, 12.3), Vector2(14.6, 12.3), Vector2(16.6, 12.3), Vector2(12.6, 14.3),
	Vector2(14.6, 14.3), Vector2(16.6, 14.3)]
## THE KITCHEN GARDEN'S SITES (review ECO-004 and feature #48; decision 0883). Four places for small garden beds on the
## open ground across the east road from the kitchen, between the square and the covered store, around a cross of
## garden paths: the player LAYS OUT a bed on any of them (farm_garden.gd), and a site nobody has laid out grows
## nothing. A garden bed is ONE §5.6 tile, 2 m x 2 m (GDD §5.6: "Fields use 2 m x 2 m tiles"), drawn at that size -- a
## field bed is the same one plot drawn 3 m wide (BED_HALF_M). The four are authored, BOUNDED modules (the review:
## "bounded modules plus grouping before arbitrary polygon simulation"); where they stand is a demo layout, checked
## clear of every obstacle and footprint (test_demo_garden.gd). Free placement is decision 0883's proposal.
const GARDEN_FIRST: int = 12
const GARDEN_SITES: int = 4
const GARDEN_AT: Array[Vector2] = [Vector2(5.4, 5.4), Vector2(8.0, 5.4), Vector2(5.4, 8.0), Vector2(8.0, 8.0)]
const GARDEN_HALF_M: float = 1.0
## The garden's work shelf (GDD §5.9's Shelf furniture) stands at the north end of the middle path, toward the kitchen.
const GARDEN_SHELF_AT: Vector2 = Vector2(6.7, 3.9)
const SOIL_NAMES: Array[String] = ["loam", "clay", "sand"]
## The demo's opening history (demo values): what already stands in each bed at 06:00 of day 1,
## sown and grown that many hours at spring's baseline before the demo opens -- carrots near ripe,
## a young radish row and a wheat bed; the rest empty for the player.
const BED_START_ITEM: Array[int] = [NO_ITEM, NO_ITEM, 2, 0, NO_ITEM, 13, NO_ITEM, NO_ITEM, NO_ITEM, NO_ITEM, NO_ITEM,
	NO_ITEM, NO_ITEM, NO_ITEM, NO_ITEM, NO_ITEM]
const BED_START_HOURS: Array[int] = [0, 0, 96, 36, 0, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
## Two beds are neighbours (blight spreads between them) when their centres are this close.
const NEIGHBOUR_M: float = 4.0
## A bed's half-width on the ground: every bed is drawn 3 m wide (world_sizes.gd CROP_BED_WIDTH_M).
const BED_HALF_M: float = 1.5


static func is_plant_kind(kind: int) -> bool:
	"""Whether a visual kind is one of the library plants (with stage cells), not an old atlas."""
	return kind >= VIS_PLANT_FIRST and kind < VIS_COUNT


static func plant_key_of(kind: int) -> StringName:
	"""The library plant a plant kind draws."""
	return PLANT_KEYS[kind - VIS_PLANT_FIRST]


static func is_item(item: int) -> bool:
	"""Whether `item` names one of the farmed ingredients."""
	return item >= 0 and item < ITEM_COUNT


static func is_pantry_item(item: int) -> bool:
	"""Whether `item` is anything the pantry keeps: a farmed ingredient or one of THE PANTRY'S OTHER GOODS."""
	return item >= 0 and item < PANTRY_ITEM_COUNT


static func category_of(item: int) -> int:
	"""What a recipe calls a pantry item: a crop's §5.6 row, else its goods category (CAT_*); -1 for no item."""
	if is_item(item):
		return ITEM_CROP[item]
	if is_pantry_item(item):
		return GOODS_CATEGORY[item - ITEM_COUNT]
	return -1


static func item_of_patch(patch_kind: int) -> int:
	"""The pantry item a forage.gd patch kind is gathered as (NO_ITEM: one the demo does not gather)."""
	return PATCH_ITEM[patch_kind] if patch_kind >= 0 and patch_kind < PATCH_ITEM.size() else NO_ITEM


static func is_orchard_item(item: int) -> bool:
	"""Whether `item` is the orchard's fruit or the hedge's berries (decision 0671)."""
	return ORCHARD_ITEMS.has(item)


static func item_of_orchard_species(species_id: int) -> int:
	"""The pantry item an orchard_hive.gd species row is picked as (NO_ITEM for none)."""
	return ORCHARD_SPECIES_ITEM[species_id] if species_id >= 0 and species_id < ORCHARD_SPECIES_ITEM.size() else NO_ITEM


static func item_of_species(species_row: int) -> int:
	"""The pantry item a fishing.gd species row lands as (NO_ITEM: one the demo cannot catch)."""
	return SPECIES_ITEM[species_row] if species_row >= 0 and species_row < SPECIES_ITEM.size() else NO_ITEM


static func is_bed(bed: int) -> bool:
	"""Whether `bed` names one of the beds (the field's twelve and the kitchen garden's four sites)."""
	return bed >= 0 and bed < BED_COUNT


static func crop_of(item: int) -> int:
	"""The §5.6 crop row an ingredient grows by."""
	return ITEM_CROP[item]


static func family_of(item: int) -> int:
	"""The rotation family (catalog CropFamily id) an ingredient belongs to."""
	return FarmingScript.CROP_FAMILY[ITEM_CROP[item]]


static func shelf_hours_of(item: int) -> int:
	"""§5.7's base shelf life of a pantry item: a crop's by its crop row, the other goods' their own."""
	if is_item(item):
		return CROP_SHELF_HOURS[ITEM_CROP[item]]
	return GOODS_SHELF_HOURS[item - ITEM_COUNT]


static func is_garden(bed: int) -> bool:
	"""Whether `bed` is one of the kitchen garden's sites (THE KITCHEN GARDEN'S SITES), not a field bed."""
	return bed >= GARDEN_FIRST and bed < GARDEN_FIRST + GARDEN_SITES


static func is_south_field(bed: int) -> bool:
	"""Whether `bed` is one of the south field's beds (THE SOUTH FIELD)."""
	return bed >= SOUTH_FIRST and bed < SOUTH_FIRST + SOUTH_BEDS


static func bed_half_m(bed: int) -> float:
	"""A bed's half-width on the ground: a garden or south-field bed's one 2 m tile, a first-field bed's 3 m drawing."""
	return GARDEN_HALF_M if is_garden(bed) or is_south_field(bed) else BED_HALF_M


static func bed_centre_m(bed: int) -> Vector2:
	"""A bed's centre on the ground (x, z), in metres: a field bed's from the world layout, a garden site's from
	GARDEN_AT. Every BED_IDS entry is a world crop id (test_demo_farm.gd checks), so an unknown one is a programming
	error."""
	if is_garden(bed):
		return GARDEN_AT[bed - GARDEN_FIRST]
	if is_south_field(bed):
		return SOUTH_AT[bed - SOUTH_FIRST]
	for entry: Dictionary in Layout.CROPS:
		if entry["id"] == BED_IDS[bed]:
			return entry["at"]
	assert(false, "farm bed %s is not a world crop" % BED_IDS[bed])
	return Vector2.INF


static func neighbours_of(bed: int) -> PackedInt32Array:
	"""The beds whose centres lie within NEIGHBOUR_M of this one's (blight's reach)."""
	var out := PackedInt32Array()
	var here: Vector2 = bed_centre_m(bed)
	for other: int in BED_COUNT:
		if other != bed and bed_centre_m(other).distance_to(here) <= NEIGHBOUR_M:
			out.append(other)
	return out


static func bed_at_into(point: Vector2, out: IntMath.IntResult) -> bool:
	"""The bed whose square footprint holds this ground point (x, z), into `out`; refuses
	NO_BED_THERE when the point is on no bed. Presentation input: a click's ground point."""
	for bed: int in BED_COUNT:
		var d: Vector2 = (point - bed_centre_m(bed)).abs()
		var half: float = bed_half_m(bed)
		if d.x <= half and d.y <= half:
			return out.succeed(bed)
	return out.refuse(REFUSE_NO_BED)
