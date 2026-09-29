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
## BEDS. The six world crop beds (world/world_layout.gd CROPS), one FarmPlot row each. §5.1's soil
## bands belong to the unbuilt world generator, so each bed's soil is a DEMO value, varied so the
## soil filter means something: sand refuses the loam/clay rows, clay refuses roots.

const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Layout := preload("res://demo/world/world_layout.gd")

const REFUSE_NO_BED: String = "NO_BED_THERE"

const NO_ITEM: int = -1

## The farmed ingredients: key, label, pantry LEAF id and the §5.6 crop row each grows by.
const ITEM_KEYS: Array[StringName] = [
	&"radish", &"turnip", &"carrot", &"beetroot", &"parsnip", &"onion",
	&"cabbage", &"lettuce", &"spinach", &"leek", &"celery",
	&"pea", &"broad_bean",
	&"wheat", &"barley", &"oats",
]
const ITEM_LABELS: Array[String] = [
	"Radish", "Turnip", "Carrot", "Beetroot", "Parsnip", "Onion",
	"Cabbage", "Lettuce", "Spinach", "Leek", "Celery",
	"Pea", "Broad bean",
	"Wheat", "Barley", "Oats",
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

## §5.7's base shelf hours by §5.6 crop row (beans, cabbage, flax, grain, roots). Flax is 0: an
## unlimited-shelf material, and never farmed here.
const CROP_SHELF_HOURS: Array[int] = [480, 144, 0, 720, 240]
## The `data/item_definitions.json` ids the same rows store as (for the cross-check).
const CROP_ITEM_ID: Array[StringName] = [&"beans", &"cabbage", &"flax", &"grain", &"roots"]
const FAMILY_NAMES: Array[String] = ["cereal", "fibre", "leaf", "legume", "root"]

## PRESENTATION. Which plant cards a bed of each item shows (the staged atlases of
## tools/make_demo_crop_cards.py), and the tint laid over them when ripe.
const VIS_WHEAT: int = 0
const VIS_TURNIP: int = 1
const VIS_CARROT: int = 2
const ITEM_VISUAL: Array[int] = [
	VIS_TURNIP, VIS_TURNIP, VIS_CARROT, VIS_TURNIP, VIS_CARROT, VIS_CARROT,
	VIS_TURNIP, VIS_TURNIP, VIS_TURNIP, VIS_CARROT, VIS_CARROT,
	VIS_CARROT, VIS_CARROT,
	VIS_WHEAT, VIS_WHEAT, VIS_WHEAT,
]
## The leaf crops show the staged cabbage bed when ripe (its heads), tinted per item.
const ITEM_RIPE_HEADS: Array[bool] = [
	false, false, false, false, false, false,
	true, true, true, false, false,
	false, false,
	false, false, false,
]
const ITEM_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.12, 0.78, 0.8),
	Color(1.06, 1.05, 0.88), Color(0.86, 1.0, 1.06),
	Color(1.16, 1.0, 0.95), Color(1.28, 1.22, 0.78), Color(0.78, 0.95, 0.8),
	Color(0.84, 1.0, 1.1), Color(1.12, 1.16, 0.9),
	Color(0.95, 1.12, 0.85), Color(0.84, 1.0, 0.84),
	Color(1.0, 1.0, 1.0), Color(1.06, 1.0, 0.84), Color(1.06, 1.06, 0.96),
]

## The beds: world crop ids, one FarmPlot each, their demo soils.
const BED_IDS: Array[StringName] = [
	&"bed_cabbage_w", &"bed_cabbage_e", &"bed_roots_w", &"bed_roots_e", &"bed_grain_w", &"bed_grain_e",
]
const BED_COUNT: int = 6
const BED_SOILS: Array[int] = [
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_SAND,
	FarmingScript.SOIL_LOAM, FarmingScript.SOIL_CLAY, FarmingScript.SOIL_LOAM,
]
const SOIL_NAMES: Array[String] = ["loam", "clay", "sand"]
## The demo's opening history (demo values): what already stands in each bed at 06:00 of day 1,
## sown and grown that many hours at spring's baseline before the demo opens -- carrots near ripe,
## a young radish row and a wheat bed; the rest empty for the player.
const BED_START_ITEM: Array[int] = [NO_ITEM, NO_ITEM, 2, 0, NO_ITEM, 13]
const BED_START_HOURS: Array[int] = [0, 0, 96, 36, 0, 60]
## Two beds are neighbours (blight spreads between them) when their centres are this close.
const NEIGHBOUR_M: float = 4.0
## A bed's half-width on the ground: every bed is drawn 3 m wide (world_sizes.gd CROP_BED_WIDTH_M).
const BED_HALF_M: float = 1.5


static func is_item(item: int) -> bool:
	"""Whether `item` names one of the farmed ingredients."""
	return item >= 0 and item < ITEM_COUNT


static func is_bed(bed: int) -> bool:
	"""Whether `bed` names one of the six beds."""
	return bed >= 0 and bed < BED_COUNT


static func crop_of(item: int) -> int:
	"""The §5.6 crop row an ingredient grows by."""
	return ITEM_CROP[item]


static func family_of(item: int) -> int:
	"""The rotation family (catalog CropFamily id) an ingredient belongs to."""
	return FarmingScript.CROP_FAMILY[ITEM_CROP[item]]


static func shelf_hours_of(item: int) -> int:
	"""§5.7's base shelf life of an ingredient, by its crop row."""
	return CROP_SHELF_HOURS[ITEM_CROP[item]]


static func bed_centre_m(bed: int) -> Vector2:
	"""A bed's centre on the ground (x, z), in metres, from the world layout. Every BED_IDS entry is
	a world crop id (test_demo_farm.gd checks), so an unknown one is a programming error."""
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
		if d.x <= BED_HALF_M and d.y <= BED_HALF_M:
			return out.succeed(bed)
	return out.refuse(REFUSE_NO_BED)
