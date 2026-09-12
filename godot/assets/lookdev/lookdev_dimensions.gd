extends RefCounted
## ART-GAP-R01..R05 numerical metadata, bound as integer columns the engine can read.
##
## Source of every number here: `docs/planning/asset_dimensions_and_budgets.md` and its
## JSON sibling, adopted by the 2026-09-11 asset/save/movement ruling and recorded in
## decision 0082. Nothing in this file is measured; it is a specification binding. A value
## that is measured -- an actual triangle count, an actual mesh bound -- comes from the
## file being validated and is compared against these ceilings, never sourced from them.
##
## ---------------------------------------------------------------------------------------
## THE CREATURE HEIGHTS ARE COMPARISON CANDIDATES, NOT PRODUCTION APPROVAL.
##
## `SPECIES_HEIGHT_U` carries the ruling's anatomical-height comparison candidates. The
## ruling is explicit that they are "not bulk-production approval": decision 0002 requires
## mouse / hare-or-otter / badger beside the same door, table and workbench, judged by eye,
## before bulk proportions are approved. `proportion_comparison.gd` builds exactly that
## scene. Until Brendan rules on it, every consumer of these numbers must present them as
## candidates. Bulk creature generation does not start from this file.
##
## ---------------------------------------------------------------------------------------
## UNITS.
##
## The project's authoritative length unit is 1/1024 m (AGENTS.md: "Positions are int32 in
## 1/1024 m units"), and the `*_U` columns carry it. The `*_MM` columns are the integer
## millimetre authoring column the art brief asks for, produced by `millimetres_from_units`
## with half-up rounding. They are DERIVED. Where the two disagree the `_U` column wins,
## and `units_convert_to_millimetres_exactly()` says which rows disagree: at the time of
## writing exactly one does -- `dirt_path` at 64 u is 62.5 mm and cannot be an integer
## millimetre. That is recorded rather than rounded away silently.
##
## Floats appear nowhere in this file. The render-pixel thresholds, the residence time and
## the roughness targets are all stored as integer tenths / milliseconds / permille, and
## they are presentation inputs in any case.

const IntMath := preload("res://scripts/core/int_math.gd")

# --- unit conversion --------------------------------------------------------------------

const UNITS_PER_METRE: int = 1024
const MILLIMETRES_PER_METRE: int = 1000

## GAP-06: the inherited cutaway cut line, "walls ... hide down to 1 m height"
## (`docs/ui_ux_controls.md` §6). One metre in project units.
const CUTAWAY_CUT_HEIGHT_U: int = 1024

# --- GAP-01/02 species comparison candidates ---------------------------------------------

const SPECIES_KEY: Array[StringName] = [
	&"mouse", &"mole", &"squirrel", &"otter", &"badger",
]

## Anatomical comparison heights in 1/1024 m. COMPARISON CANDIDATES -- see the file header.
const SPECIES_HEIGHT_U: Array[int] = [1024, 922, 1024, 1526, 2611]

## The same heights in the integer millimetre authoring column. DERIVED from `_U`.
const SPECIES_HEIGHT_MM: Array[int] = [1000, 900, 1000, 1490, 2550]

## `mouse` inherits crowd §9.1's sourced 1.0 m gameplay anchor; the other four are the
## ruling's authored comparison candidates. Neither status is production approval, because
## the relative proportions of all five are what decision 0002's review judges.
const SPECIES_STATUS: Array[StringName] = [
	&"ANCHOR_SOURCED_COMPARISON_INPUT",
	&"COMPARISON_CANDIDATE",
	&"COMPARISON_CANDIDATE",
	&"COMPARISON_CANDIDATE",
	&"COMPARISON_CANDIDATE",
]

# --- GAP-03 building exterior vertical envelopes ------------------------------------------
#
# Maximum visual height above the building's placed ground datum, covering shell, roof,
# fixed chimney and signs. Local Y = 0 is the placed base. Rotation affects X/Z only.
# These do NOT set underground depth, navigation clearance, service reach or step height.

const BUILDING_KEY: Array[StringName] = [
	&"apiary", &"boathouse", &"brewery", &"cellar", &"composter", &"covered_store",
	&"dirt_path", &"dryer", &"fence", &"fisher_shelter", &"forester_lodge", &"gate",
	&"hall", &"infirmary", &"kitchen", &"lookout", &"memorial_garden", &"mill",
	&"nursery", &"open_stockpile", &"paved_path", &"preserver", &"quarry_shed",
	&"residence", &"saltpan", &"stone_wall", &"weir", &"well", &"workbench", &"workshop",
]

const BUILDING_MAX_Y_U: Array[int] = [
	2048, 5120, 5120, 2048, 1280, 5120,
	64, 3072, 1536, 3584, 4608, 3584,
	7168, 5632, 5120, 8192, 2048, 7168,
	3072, 2560, 128, 5120, 4096,
	6144, 512, 2560, 1536, 3072, 3584, 5120,
]

## Derived millimetre column. `dirt_path` is the one row that is not exact: 64 u is 62.5 mm.
const BUILDING_MAX_Y_MM: Array[int] = [
	2000, 5000, 5000, 2000, 1250, 5000,
	63, 3000, 1500, 3500, 4500, 3500,
	7000, 5500, 5000, 8000, 2000, 7000,
	3000, 2500, 125, 5000, 4000,
	6000, 500, 2500, 1500, 3000, 3500, 5000,
]

# --- GAP-03 shared enclosed-building authoring values -------------------------------------

## Minimum clear internal height for a shared enclosed surface building.
const MIN_CLEAR_INTERNAL_HEIGHT_U: int = 3072
## Ordinary common-access door opening. A model brief, NOT proof that any body or gear
## profile passes it -- the movement profile qualifies actual clearances independently.
const DOOR_OPENING_WIDTH_U: int = 1536
const DOOR_OPENING_HEIGHT_U: int = 3072
## Table / work-surface top height for the proportion comparison. An EXPLICIT CANDIDATE,
## not a universal work-contact policy for every species.
const WORK_SURFACE_TOP_U: int = 640

# --- GAP-04 non-creature production ceilings ----------------------------------------------

const FAMILY_BUILDING_ASSEMBLY: int = 0
const FAMILY_FURNITURE_INSTANCE: int = 1
const FAMILY_SMALL_PROP: int = 2
const FAMILY_TREE_LARGE_VEGETATION: int = 3
const FAMILY_GROUND_COVER_CLUSTER: int = 4
const FAMILY_COUNT: int = 5

const FAMILY_KEY: Array[StringName] = [
	&"building_assembly", &"furniture_instance", &"small_prop",
	&"tree_large_vegetation", &"ground_cover_cluster",
]

## Static geometry tiers, not creature animation L0-L3. Index by FAMILY_* then LOD 0/1/2.
const FAMILY_TRIANGLE_CEILING: Array[int] = [
	32000, 10000, 2500,
	2000, 700, 180,
	1200, 400, 100,
	6000, 2000, 500,
	600, 180, 40,
]
const STATIC_LOD_COUNT: int = 3

const FAMILY_SURFACE_CEILING: Array[int] = [16, 2, 1, 2, 1]
const FAMILY_TEXTURE_EDGE_CEILING: Array[int] = [2048, 1024, 1024, 2048, 1024]

## Buildings only: at most four distinct shared materials, at most sixteen draw surfaces at
## near/mid and four at far. Material count is not draw-surface count.
const BUILDING_MATERIAL_CEILING: int = 4
const BUILDING_SURFACE_CEILING_BY_LOD: Array[int] = [16, 16, 4]
const SHARED_ATLAS_EDGE_CEILING: int = 2048

## Static admission, in TENTHS of a render-target pixel so the contract stays integral.
## Initial near at >= 180 px, mid at >= 48 px; 10% hysteresis, 0.20 s residence.
const STATIC_INITIAL_NEAR_TENTHS_PX: int = 1800
const STATIC_INITIAL_MID_TENTHS_PX: int = 480
const STATIC_PROMOTE_NEAR_TENTHS_PX: int = 1980
const STATIC_DEMOTE_NEAR_BELOW_TENTHS_PX: int = 1620
const STATIC_PROMOTE_MID_TENTHS_PX: int = 528
const STATIC_DEMOTE_MID_BELOW_TENTHS_PX: int = 432
const STATIC_RESIDENCE_MS: int = 200

## Aggregate non-creature allocations, charged alongside creature/crowd allocations inside
## the existing 2.5 GiB loaded-graphics ceiling. Not additions to it, not simulation memory.
const NONCREATURE_MESH_BYTES: int = 134217728
const NONCREATURE_TEXTURE_BYTES: int = 268435456

# --- GAP-04 crop, terrain and repeated-pile accounting -------------------------------------

## Per 2 m crop tile, near/mid/far.
const CROP_MODULE_TRIANGLE_CEILING: Array[int] = [256, 96, 16]
const CROP_MODULE_SURFACE_CEILING: int = 1
## GDD §4.2 permits 4096 active farm tiles.
const CROP_ACTIVE_TILE_LIMIT: int = 4096

const TERRAIN_TEXELS_PER_METRE: int = 256
const STRUCTURE_TEXELS_PER_METRE: int = 128
const PROP_TEXELS_PER_METRE: int = 256
## "+/-25% within a family unless a documented focal detail uses a separate budgeted region."
const TEXEL_DENSITY_TOLERANCE_PERCENT: int = 25

## One container's whole pile assembly, near/mid/far. If an 8x8 m container uses sixteen
## decorative submodules their SUM stays within this, because a container is one container.
const PILE_ASSEMBLY_TRIANGLE_CEILING: Array[int] = [1200, 400, 100]
const PILE_ASSEMBLY_SURFACE_CEILING: int = 1
## Nonempty fill variants at occupied mass <= 1/3, <= 2/3, > 2/3 of ACTUAL capacity, plus
## empty. Quality, age and reservation do not duplicate visible quantity.
const PILE_FILL_VARIANT_COUNT: int = 4

# --- GAP-05 settlement skeletal admission ---------------------------------------------------
#
# Settlement-specific override to crowd §2.7. Battle stays 180 px / cap 48. The default
# ~26 px orbit legitimately admits nobody; a pool with zero skeletal actors is correct there.

const SETTLEMENT_L0_NOMINAL_TENTHS_PX: int = 640
const SETTLEMENT_L0_PROMOTE_TENTHS_PX: int = 704
const SETTLEMENT_L0_DEMOTE_BELOW_TENTHS_PX: int = 576
const SETTLEMENT_L0_POOL_CAP: int = 24
const SETTLEMENT_L0_RESIDENCE_MS: int = 200
const BATTLE_L0_NOMINAL_TENTHS_PX: int = 1800
const BATTLE_L0_POOL_CAP: int = 48

# --- GAP-09 material authoring baseline -------------------------------------------------
#
# Standard metallic/roughness PBR, opaque except declared foliage and cutaway effects.
# Shared ORM stores occlusion R, roughness G, metallic B. Look-development STARTING values,
# not physical measurements; authored spatial variation stays allowed.

const MATERIAL_KEY: Array[StringName] = [
	&"linen", &"dry_timber", &"stone", &"leather", &"forged_iron",
]
const MATERIAL_ROUGHNESS_PERMILLE: Array[int] = [900, 800, 850, 650, 500]
## Nonmetal cloth/wood/stone/fur are metallic 0; clean exposed metal is 1000 permille;
## grime and rust remain nonmetal.
const MATERIAL_METALLIC_PERMILLE: Array[int] = [0, 0, 0, 0, 1000]

# --- lookups ------------------------------------------------------------------------------


static func species_count() -> int:
	"""How many species the ruling supplies a comparison-candidate height for."""
	return SPECIES_KEY.size()


static func has_species(key: StringName) -> bool:
	"""Whether this file declares a comparison-candidate height for `key`."""
	return SPECIES_KEY.has(key)


static func has_building(key: StringName) -> bool:
	"""Whether this file declares an exterior vertical envelope for `key`."""
	return BUILDING_KEY.has(key)


static func species_height_units_into(key: StringName, out: IntMath.IntResult) -> bool:
	"""Write the comparison-candidate height of `key` in 1/1024 m. Refuses on an unknown key."""
	var row: int = SPECIES_KEY.find(key)
	if row < 0:
		return out.refuse("lookdev_dimensions: no comparison height for species '%s'" % key)
	return out.succeed(SPECIES_HEIGHT_U[row])


static func species_height_millimetres_into(key: StringName, out: IntMath.IntResult) -> bool:
	"""Write the derived integer-millimetre height of `key`. Refuses on an unknown key."""
	var row: int = SPECIES_KEY.find(key)
	if row < 0:
		return out.refuse("lookdev_dimensions: no comparison height for species '%s'" % key)
	return out.succeed(SPECIES_HEIGHT_MM[row])


static func building_count() -> int:
	"""How many BuildingDefinition keys carry an exterior vertical envelope. All 30."""
	return BUILDING_KEY.size()


static func building_max_y_units_into(key: StringName, out: IntMath.IntResult) -> bool:
	"""Write the maximum local Y of `key` in 1/1024 m above its placed base. Refuses if unknown.

	It refuses rather than returning 0, because 0 is a legal authored height for a flat
	surface and an absent envelope must not read as "this building is a decal".
	"""
	var row: int = BUILDING_KEY.find(key)
	if row < 0:
		return out.refuse("lookdev_dimensions: no vertical envelope for building '%s'" % key)
	return out.succeed(BUILDING_MAX_Y_U[row])


static func millimetres_from_units(units: int) -> int:
	"""Convert 1/1024 m to integer millimetres, half up. Derived column only; `_U` is authority."""
	if units < 0:
		return -((-units * MILLIMETRES_PER_METRE + UNITS_PER_METRE / 2) / UNITS_PER_METRE)
	return (units * MILLIMETRES_PER_METRE + UNITS_PER_METRE / 2) / UNITS_PER_METRE


static func units_convert_to_millimetres_exactly(units: int) -> bool:
	"""True when `units` is a whole number of millimetres, so the derived column loses nothing."""
	return (units * MILLIMETRES_PER_METRE) % UNITS_PER_METRE == 0


static func family_triangle_ceiling_into(family: int, lod: int, out: IntMath.IntResult) -> bool:
	"""Write the triangle ceiling for one static family at one static tier. Refuses out of range."""
	if family < 0 or family >= FAMILY_COUNT:
		return out.refuse("lookdev_dimensions: no static family %d" % family)
	if lod < 0 or lod >= STATIC_LOD_COUNT:
		return out.refuse("lookdev_dimensions: no static tier %d" % lod)
	return out.succeed(FAMILY_TRIANGLE_CEILING[family * STATIC_LOD_COUNT + lod])


static func family_surface_ceiling_into(family: int, lod: int, out: IntMath.IntResult) -> bool:
	"""Write the draw-surface ceiling for one static family at one tier. Refuses out of range.

	Buildings carry a per-tier surface contract (16/16/4) so the required roof and per-side
	wall parts survive at far; the other families carry one number across all three tiers.
	"""
	if family < 0 or family >= FAMILY_COUNT:
		return out.refuse("lookdev_dimensions: no static family %d" % family)
	if lod < 0 or lod >= STATIC_LOD_COUNT:
		return out.refuse("lookdev_dimensions: no static tier %d" % lod)
	if family == FAMILY_BUILDING_ASSEMBLY:
		return out.succeed(BUILDING_SURFACE_CEILING_BY_LOD[lod])
	return out.succeed(FAMILY_SURFACE_CEILING[family])


static func crop_whole_field_triangles_into(lod: int, out: IntMath.IntResult) -> bool:
	"""Write the worst-case triangle count for all 4096 permitted farm tiles at one tier.

	A count, not a measured GPU time. Refuses on an unknown tier rather than reporting zero
	crops, which would read as a passing budget.
	"""
	if lod < 0 or lod >= STATIC_LOD_COUNT:
		return out.refuse("lookdev_dimensions: no crop tier %d" % lod)
	return IntMath.checked_mul_into(
		CROP_MODULE_TRIANGLE_CEILING[lod], CROP_ACTIVE_TILE_LIMIT, out)
