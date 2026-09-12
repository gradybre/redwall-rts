extends RefCounted
## REQ-SET-009 world generation: the terrain and ecology half of GDD §5.1's fixed initialization
## contract, staged as prepare -> validate -> publish.
##
## WHAT THIS IS FOR. Task 03 built and tested every ecology store and left them EMPTY: a
## DESIGNATE_ZONE command had no basin to target, the ecology boundary had no patch to advance and
## no stock to recover, and no FORAGE or FISH job could reference anything. This module is the
## world-generation operation decisions 0026 (R05-BASIN-001) and 0037 (§8B) reserve for exactly
## that: the ONLY authorised creator of ecological stock basins. After `generate()` succeeds, a
## player DESIGNATE_ZONE targeting one of the four forest basins designates real forest.
##
## ---------------------------------------------------------------------------------------
## ALLOCATE BEFORE CONSUME, AT WORLD SCALE (decision 0024). Task 04.3: "Failed initialization
## retains the previous valid world and reports the exact failed assertion."
##
## Every refusal this module can produce is decided in `_prepare()` or `_validate()`, and BOTH run
## entirely inside this object: the terrain plan is written into STAGED columns, the collaborating
## stores are only read. `_publish()` is reached only once the request, the collaborator set, the
## directory's free rows, every store capacity and all of §5.1's generator guarantees have been
## proved, and it is the first statement that mutates anything outside this object. A refused
## generation therefore leaves every store byte-identical because NOTHING WROTE TO THEM, not
## because a rollback undid the writes.
##
## `_publish()` still inspects every OpResult it gets back and asserts on a refusal. That assert is
## a drift guard on the preflight above it, not an error path: a store refusing there means the
## preflight is wrong, and the world at that point is already cleared.
##
## THE PUBLISHED MAP IS DOUBLE-BUFFERED for the same reason. `_staged_*` and the published columns
## are two allocations made once in `_init()`; publishing SWAPS the references. A failed
## generation cannot have touched the published map, and no `resize()` happens outside `_init()`.
##
## ---------------------------------------------------------------------------------------
## EVERY NUMBER BELOW IS TRANSCRIBED FROM GDD §5.1. None is derived from a rounder-looking one.
## The two paragraphs it comes from are quoted in the constant blocks that carry each value.
##
## SEEDING IS WORLD GENERATION'S JOB. `settlement_system.gd` composes `rng.gd` unseeded, which is
## why the second season's first midnight refuses `RNG_NOT_SEEDED` (task 03 increment 10 found it).
## §5.1 gives the fixed-seed tutorial seed 20260905 and rules that "Invalid seeds are rejected and
## regenerated with seed+1"; `generate()` seeds the RNG as part of publishing, so a generated world
## reaches its season handover with nine live streams.
##
## ---------------------------------------------------------------------------------------
## WHAT IS BLOCKED, NAMED RATHER THAN INVENTED (AGENTS.md: "do not invent a constant").
##
##   * THE 12-RESIDENT FIXTURE, THE STARTER BUILDINGS, BEDS, CONTAINERS AND EQUIPPED TOOLS ARE NOT
##     BUILT HERE. Task 04.3 is explicit: pull forward task 06's building/furniture/container
##     contracts "if the contracts remain open, mark full initialization blocked; do not substitute
##     unlimited piles, fictional beds, duplicated tools or unregistered inventory owners". NO
##     Building, Furniture or Container store exists in `scripts/core/`. FULL INITIALIZATION IS
##     THEREFORE BLOCKED and this module generates terrain, resource nodes and ecology only.
##     UPDATED 2026-09-11 (decision 0064): THE COHORT HALF IS NO LONGER MISSING FROM THE GAME, only
##     from THIS module. `settlement_system.gd`'s `create_generated_settlement()` calls `generate()`
##     and then `residents.gd`'s §5.1 cohort as one all-or-nothing operation, so generating a world
##     now produces a world with somebody in it. The ORDER IS FORCED BY THIS MODULE: `_publish()`
##     clears the directory, so residents must be spawned AFTER it -- and that costs §5.1's
##     "IDs 1-12", because §4.2's one id space is consumed by 1713 world entities first. Decision
##     0064 records the arithmetic. The buildings, beds and containers remain genuinely absent.
##   * CORRECTED 2026-09-11 (READY_07 §7.1), TWICE, and both corrections are kept dated rather
##     than deleted.
##     (1) The original claim said the building footprints are "authored NOWHERE as tile
##     coordinates". That was WRONG. GDD §5.9 states "place the hall at (58,59), stockpiles at
##     (50,60),(50,65),(70,60),(70,65), well at (64,54), and workbench at (58,54), all rotation 0.
##     Clear these footprints before resource placement." With §5.9's building-table extents that
##     is hall 12x10, four open stockpiles 4x4, well 2x2, workbench shelter 3x3.
##     (2) The first correction then said "THE CONSEQUENCE IS NOT YET IMPLEMENTED". It IS now:
##     `is_cleared_tile()` clears all seven footprints and §5.1's one-tile apron alongside the
##     loam rectangle, and `_stage_tree_plan()` consults the staged mask, so no tree centre and no
##     grove node can land on cleared ground. Decision 0058 records the recalculated census.
##     THE 1695-NODE FIXTURE IS RETIRED as a fixture: the count is now derived from the geometry
##     (see `test_generated_node_count_is_centres_plus_grove_less_replaced_plus_ore`) and it
##     recomputes to the SAME 1695 by arithmetic, not by protection. The apron's only intersection
##     with a forest mask is the odd column x=49, which carries no even/even tree centre, and the
##     five grove tiles it does take at (49,59..63) are replaced one-for-one inside §5.1's
##     replacement window. Nothing was left standing inside the well, workbench or apron to hold
##     the total up; the COMPOSITION changed and the total happens not to.
##     Shared aprons may overlap as cleared ground; building footprints may not, which
##     `_assert_footprints_dont_overlap()` guards and the suite asserts against the authored
##     coordinates. None of GDD §5.9's seven footprints overlaps another.
##     §5.1's own sentence is the other half: "Clear initial building footprints, a one-tile
##     apron, and the loam rectangle x=58..65,z=46..53 before placing resource nodes".
##     STILL NOT BUILT HERE: clearing ground is GEOMETRY. No Building, Furniture or Room store is
##     created by this module -- READY_07 §7.2 step 2 owns those -- so nothing here knows that the
##     hall footprint will one day hold a hall.
##   * NO FarmPlot, OrchardPlot OR Hive IS CREATED. §5.1's initial conditions list buildings,
##     inventory and residents; they list no farm plot, orchard block or apiary, and §5.6/§5.7 reach
##     both through player designation (orchards additionally behind milestone M3). `farming.gd` and
##     `orchard_hive.gd` are therefore RESET by this module and populated by it with nothing. A FARM
##     job still has nothing to reference until a FARM designation creates a plot; that is task
##     04.4/05, not REQ-SET-009.
##   * NO JOB IS CREATED AND `job_planner.gd` IS NOT CALLED. `JOB_STATE_WORK` is never written here.
##   * THE RENEWABLE BEDROCK ACCESS AT (48,70) IS NOT PLACED. §5.1 names it and decision 0029
##     confirms it is in neither ore total, but no document gives it a quantity, a regrow period or
##     a footprint. Its coordinates are recorded below as constants and its tile is left empty.
##   * THE ARRIVAL/DEPARTURE EXIT (64,126) IS RECORDED AS A CONSTANT AND NOT MODELLED. §5.1 joins it
##     to the hall "by ordinary land navigation"; there is no navigation graph (ARCH-SYS-011) and no
##     hall.
##   * REACHABILITY-BASED TOPOLOGY ASSERTIONS ARE BLOCKED ON TASK 05. Task 04.3: "Validate ...
##     reachability ... using task 05's topology once available. Before that mark topology
##     assertions blocked." STRAIGHT-LINE DISTANCE is what `_validate()` checks; see the
##     `Measurements` class for exactly which guarantee is measured how.
##   * THE SAVE ROUND TRIP IS BLOCKED. Task 09 owns the codec; nothing here serialises.
##
## ---------------------------------------------------------------------------------------
## THE VALIDATION ANCHOR IS DERIVED FROM §5.1's OWN NUMBERS, NOT CHOSEN. §5.1's generator
## guarantees are distances ("one river edge within 24 m") from an origin it names only as "map
## center" ("The starter hall and resource placement fit a 32 m radius of map center"). Two
## readings of "map center" exist on a 128x128 grid, and they disagree:
##
##   * the geometric mid-POINT of the map, 131072 units, which lies on the seam between tiles 63
##     and 64. The nearest river tile x=76 has center 156672, which is 25600 units = 25 m away, and
##     25 m FAILS the 24 m river guarantee.
##   * the center of TILE (64,64). The nearest river tile is then 12 tiles away, which is exactly
##     24576 units = 24 m, and satisfies the guarantee at equality.
##
## Only the second reading makes §5.1's own guarantee satisfiable on §5.1's own geometry, so the
## anchor is tile (64,64) and distances are measured tile-center to tile-center. That is a
## derivation from the authored numbers, and it is recorded in decision 0048 with this arithmetic.
## The starter HALL's exact footprint remains task 06's; §5.1 constrains it to within 32 m of this
## anchor and does not place it.
##
## ---------------------------------------------------------------------------------------
## INTERPRETATIONS THIS MODULE MAKES, each recorded in decision 0048 with its alternative:
##
##   1. "FOREST MASKS" ARE THE FOREST ECOLOGY BASINS. §5.1 places tree centers "in forest masks"
##      and never defines a forest mask in tiles except through "Forest ecology basins are west
##      x=8..49,z=20..105 and east x=82..119,z=20..105 excluding water". The macro map's F cells are
##      explicitly overridden ("Exact tile masks and coordinates above override this coarse
##      overview"). The reading is confirmed by construction: BOTH ore footprints fall inside the
##      west rectangle and each covers exactly four tree centers, which is what makes §5.1's "Ore
##      footprints replace tree nodes" have anything to replace.
##   2. "EVERY SECOND x / EVERY SECOND z" IS EVEN x AND EVEN z. The mask-relative reading (count
##      from each mask's first column/row) and the global-parity reading COINCIDE here, because all
##      four mask bounds -- x=8, x=82, z=20 for both -- start on even coordinates. The ambiguity is
##      therefore not load-bearing on this map.
##   3. THE GROVE PLACES EXACTLY 100 NEW NODES. §5.1: "Add a guaranteed grove of 100 trees ...
##      skipping duplicate centers and all cleared aprons; replace any skipped center at the lowest
##      unused land tile inside x=36..49,z=50..67 until exactly 100 guaranteed nodes exist." A
##      skipped tile already carries a center node, so counting it toward the 100 would make
##      "replace any skipped center" do nothing. 25 of the 100 grove tiles are centers and, since
##      the 2026-09-11 footprint clearing, 5 more at (49,59..63) fall in a stockpile apron -- so 70
##      land in the grove and 30 relocate. The grove is still exactly 100.
##   4. THE BASINS SPLIT NORTH = z < 62, SOUTH = z >= 62. §5.1 says "each is split at z=62 into
##      north/south migration partners" and the macro map's "N is decreasing Z" fixes which side is
##      north. The alternative -- an even 43/43 split at z<=62 / z>=63 -- is the rounder-looking one
##      and is NOT what the text says. The partnership itself has no live representation:
##      `migration_link` is a `FaunaStockReserved` column and REQ-SET-059 keeps that store
##      canonically empty, so nothing here writes a partner reference.
##   5. A BASIN'S CENTER IS ITS BOUNDING-BOX CENTER, used only to band §5.5's natural danger. §5.5
##      fixes danger "at generation" as "the basin center's distance category" and never defines
##      the center of a basin with a hole in it. All seven basins land well inside their band (see
##      `_basin_danger_band()`), so the choice changes no shipped value.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS OWNS AND WHAT IT DOES NOT.
##   * `entity_directory.gd` owns slots, refs and generations. `publish()` calls its `clear()`,
##     which resets the free heaps, the persistent-ID counter and every row -- and DELIBERATELY
##     DOES NOT reset `_generation` (ARCH-ID-002: generations only ever move forward). So two
##     worlds generated into two FRESH directories agree on every reference; a world regenerated
##     into a used directory agrees on everything except the generation halves. That is the
##     directory's contract, not a defect here.
##   * `resource_nodes.gd` owns node placement AND both guaranteed ore deposits (decisions 0029 and
##     0031). `place_stone_deposit()`/`place_iron_deposit()` are CALLED, never reimplemented.
##   * `forage.gd` owns HarvestZone rows and the five patches per basin, including §5.1's
##     "forage stocks are floor(0.8xcapacity)" -- `create_patch()` already applies it to every kind,
##     dormant ones included.
##   * `fishing.gd` owns `generate_initial_estuary()`, decision 0037 §8B's three habitats and nine
##     stocks. It is CALLED, never reimplemented, and this module only binds each habitat to the
##     FISH basin zone it creates for it.
##   * `rng.gd` owns stream derivation; this module supplies the seed and the seed+1 retry.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Rng := preload("res://scripts/core/rng.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResourceCatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")

# --- the exterior grid (GDD §5.1: "Exterior tile index is `z*128+x`") ---------------------------

const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z

## §5.1: "tile center in simulation units is `(2048*x+1024,0,2048*z+1024)`". AGENTS.md fixes
## positions at 1/1024 m, so one tile is exactly 2 m and one metre is 1024 units.
const TILE_SIZE_UNITS: int = 2048
const TILE_CENTER_OFFSET_UNITS: int = 1024
const UNITS_PER_METRE: int = 1024

# --- terrain masks, in §5.1's stated PRIORITY order --------------------------------------------
## §5.1: "Apply terrain masks in this priority: coast, river, lake, land." The four ordinals below
## ARE that priority, and `resolve_terrain()` is the only place it is applied.

const TERRAIN_COAST: int = 0
const TERRAIN_RIVER: int = 1
const TERRAIN_LAKE: int = 2
const TERRAIN_LAND: int = 3
const TERRAIN_COUNT: int = 4
const TERRAIN_KEYS: Array[StringName] = [&"coast", &"river", &"lake", &"land"]

## §5.1: "Coast is z=0..15".
const COAST_FIRST_Z: int = 0
const COAST_LAST_Z: int = 15

## §5.1: "river is x=76..78 and z=16..127".
const RIVER_FIRST_X: int = 76
const RIVER_LAST_X: int = 78
const RIVER_FIRST_Z: int = 16
const RIVER_LAST_Z: int = 127

## §5.1: "lake is `(x-100)^2+(z-66)^2<=14^2`".
const LAKE_CENTER_X: int = 100
const LAKE_CENTER_Z: int = 66
const LAKE_RADIUS_TILES: int = 14

## §5.1: "The natural ford at river tiles z=48..51 is walkable, y=-128 units, and is not a fishing
## work tile."
const FORD_FIRST_Z: int = 48
const FORD_LAST_Z: int = 51

## §5.1: "Water surface is y=0; navigable land y=512 units." Plus the ford's own y=-128.
const WATER_SURFACE_Y_UNITS: int = 0
const LAND_Y_UNITS: int = 512
const FORD_Y_UNITS: int = -128

# --- soil bands (GDD §5.1, applied in the order the sentence states them) -----------------------
## §5.1: "Land soil is LOAM for x=40..74,z=40..88, SAND within 4 tiles of coast or x>=112, CLAY
## otherwise." §4.3's ordinals come from the catalog, never renumbered here.

const SOIL_LOAM: int = Catalog.SOIL["LOAM"]
const SOIL_CLAY: int = Catalog.SOIL["CLAY"]
const SOIL_SAND: int = Catalog.SOIL["SAND"]
## Absence, not a refusal channel: water tiles have no soil. `soil_at()` REFUSES for them rather
## than returning this, exactly as §4.2's `-1` means "no catalog id" and never "error".
const SOIL_NONE: int = 255

const LOAM_FIRST_X: int = 40
const LOAM_LAST_X: int = 74
const LOAM_FIRST_Z: int = 40
const LOAM_LAST_Z: int = 88
const SAND_COAST_DISTANCE_TILES: int = 4
const SAND_FIRST_X: int = 112

## §5.1: "the loam rectangle x=58..65,z=46..53" cleared "before placing resource nodes".
const CLEARED_LOAM_FIRST_X: int = 58
const CLEARED_LOAM_LAST_X: int = 65
const CLEARED_LOAM_FIRST_Z: int = 46
const CLEARED_LOAM_LAST_Z: int = 53

# --- the authored starter building footprints (GDD §5.9) ---------------------------------------
## §5.9, verbatim: "On the 128x128 exterior tile grid, place the hall at (58,59), stockpiles at
## (50,60),(50,65),(70,60),(70,65), well at (64,54), and workbench at (58,54), all rotation 0.
## Clear these footprints before resource placement. Hall interior origin is exterior origin+(1,1)."
## The SIZES are transcribed from §5.9's own building table, not from that sentence: "Refuge/
## community hall |12x10", "Open stockpile |4x4", "Well |2x2", "Workbench shelter |3x3".
##
## THE FIRST NUMBER IS THE X EXTENT, and that is proved by §5.9 rather than assumed: the hall's
## "Interior 10x8" with "interior origin is exterior origin+(1,1)" only closes as 12-2=10 across
## and 10-2=8 down, and §5.9's interior ASCII block is ten columns by eight rows.
##
## "All rotation 0" is why no rotation is stored: every authored footprint is axis aligned with its
## table extents, so a rotation column would have exactly one value. Rotation belongs to the
## building store READY_07 §7.2 step 2 creates, and NO Building, Furniture or Room store is created
## here -- this module clears GROUND, which is geometry.
const STARTER_FOOTPRINT_COUNT: int = 7

const HALL_ORIGIN_X: int = 58
const HALL_ORIGIN_Z: int = 59
const HALL_SIZE_X: int = 12
const HALL_SIZE_Z: int = 10
## §5.9: "Hall interior origin is exterior origin+(1,1)." Recorded because §5.9 states it; the
## interior itself is not modelled here (no Room store -- READY_07 §7.2 step 2 owns it).
const HALL_INTERIOR_OFFSET: int = 1

const STOCKPILE_A_ORIGIN_X: int = 50
const STOCKPILE_A_ORIGIN_Z: int = 60
const STOCKPILE_B_ORIGIN_X: int = 50
const STOCKPILE_B_ORIGIN_Z: int = 65
const STOCKPILE_C_ORIGIN_X: int = 70
const STOCKPILE_C_ORIGIN_Z: int = 60
const STOCKPILE_D_ORIGIN_X: int = 70
const STOCKPILE_D_ORIGIN_Z: int = 65
const STOCKPILE_SIZE_X: int = 4
const STOCKPILE_SIZE_Z: int = 4

const WELL_ORIGIN_X: int = 64
const WELL_ORIGIN_Z: int = 54
const WELL_SIZE_X: int = 2
const WELL_SIZE_Z: int = 2

const WORKBENCH_ORIGIN_X: int = 58
const WORKBENCH_ORIGIN_Z: int = 54
const WORKBENCH_SIZE_X: int = 3
const WORKBENCH_SIZE_Z: int = 3

## The roster, in the order §5.9's sentence names them. The index is a position in this roster and
## nothing else: it is not an entity id, and it outlives no world.
const STARTER_FOOTPRINT_KEYS: Array[StringName] = [
	&"refuge_hall", &"open_stockpile_a", &"open_stockpile_b", &"open_stockpile_c",
	&"open_stockpile_d", &"well", &"workbench_shelter",
]
const STARTER_FOOTPRINT_ORIGIN_X: Array[int] = [
	HALL_ORIGIN_X, STOCKPILE_A_ORIGIN_X, STOCKPILE_B_ORIGIN_X, STOCKPILE_C_ORIGIN_X,
	STOCKPILE_D_ORIGIN_X, WELL_ORIGIN_X, WORKBENCH_ORIGIN_X,
]
const STARTER_FOOTPRINT_ORIGIN_Z: Array[int] = [
	HALL_ORIGIN_Z, STOCKPILE_A_ORIGIN_Z, STOCKPILE_B_ORIGIN_Z, STOCKPILE_C_ORIGIN_Z,
	STOCKPILE_D_ORIGIN_Z, WELL_ORIGIN_Z, WORKBENCH_ORIGIN_Z,
]
const STARTER_FOOTPRINT_SIZE_X: Array[int] = [
	HALL_SIZE_X, STOCKPILE_SIZE_X, STOCKPILE_SIZE_X, STOCKPILE_SIZE_X,
	STOCKPILE_SIZE_X, WELL_SIZE_X, WORKBENCH_SIZE_X,
]
const STARTER_FOOTPRINT_SIZE_Z: Array[int] = [
	HALL_SIZE_Z, STOCKPILE_SIZE_Z, STOCKPILE_SIZE_Z, STOCKPILE_SIZE_Z,
	STOCKPILE_SIZE_Z, WELL_SIZE_Z, WORKBENCH_SIZE_Z,
]

## §5.1: "Clear initial building footprints, a one-tile apron, and the loam rectangle
## x=58..65,z=46..53 before placing resource nodes." ONE tile, stated, not chosen.
const FOOTPRINT_APRON_TILES: int = 1
## Margin 0 is the footprint itself; the two are the only margins this module ever clears.
const FOOTPRINT_NO_APRON: int = 0

# --- ecology basins (GDD §5.1 and decision 0026's "four regions, not two") ----------------------
## §5.1: "Forest ecology basins are west x=8..49,z=20..105 and east x=82..119,z=20..105 excluding
## water; each is split at z=62 into north/south migration partners." §5.5 confirms the partition
## is retained: "The retained forest basin partition supports forage and resource zones without a
## game-animal population."

const WEST_BASIN_FIRST_X: int = 8
const WEST_BASIN_LAST_X: int = 49
const EAST_BASIN_FIRST_X: int = 82
const EAST_BASIN_LAST_X: int = 119
const FOREST_BASIN_FIRST_Z: int = 20
const FOREST_BASIN_LAST_Z: int = 105
const BASIN_SPLIT_Z: int = 62

const BASIN_FOREST_WEST_NORTH: int = 0
const BASIN_FOREST_WEST_SOUTH: int = 1
const BASIN_FOREST_EAST_NORTH: int = 2
const BASIN_FOREST_EAST_SOUTH: int = 3
const BASIN_FISH_COAST: int = 4
const BASIN_FISH_LAKE: int = 5
const BASIN_FISH_RIVER: int = 6
const BASIN_COUNT: int = 7
const FOREST_BASIN_COUNT: int = 4
const FISH_BASIN_COUNT: int = 3
## Absence in `_basin`: this tile belongs to no ecology basin. The ford is the interesting case.
const NO_BASIN: int = 255

const BASIN_KEYS: Array[StringName] = [
	&"forest_west_north", &"forest_west_south", &"forest_east_north", &"forest_east_south",
	&"fish_coast", &"fish_lake", &"fish_river",
]

## §5.5's danger bands: "1 remaining land within 64 m of the central hall; 2 at 64-96 m; 3 beyond
## 96 m". Band 0 needs a STAFFED LOOKOUT, of which a freshly generated world has none. Distances
## are compared in HALF-TILE units so a bounding-box center never needs rounding: 64 m is 32 tiles
## is 64 half-tiles, 96 m is 48 tiles is 96 half-tiles.
const HALF_TILES_PER_METRE_NUMERATOR: int = 1
const DANGER_BAND_NEAR_HALF_TILES: int = 64
const DANGER_BAND_MID_HALF_TILES: int = 96
const DANGER_NEAR: int = 1
const DANGER_MID: int = 2
const DANGER_FAR: int = 3

# --- trees (GDD §5.1) --------------------------------------------------------------------------
## §5.1: "Tree centers occupy every second x/every second z in forest masks. If more than 3000
## centers qualify, retain the lowest tile indices. Each mature node contains 12 wood U."

const TREE_CENTER_STRIDE: int = 2
const TREE_CENTER_CAP: int = 3000
const TREE_WOOD_U: int = 12
const MILLI_PER_UNIT: int = 1000
const TREE_WOOD_MILLI: int = TREE_WOOD_U * MILLI_PER_UNIT
## §5.9: "Trees regrow after 48 days when their stumps remain and no building occupies the tile".
const TREE_REGROW_DAYS: int = 48

## §5.1: "Add a guaranteed grove of 100 trees at x=40..49,z=54..63, one per tile ... replace any
## skipped center at the lowest unused land tile inside x=36..49,z=50..67 until exactly 100
## guaranteed nodes exist."
const GROVE_FIRST_X: int = 40
const GROVE_LAST_X: int = 49
const GROVE_FIRST_Z: int = 54
const GROVE_LAST_Z: int = 63
const GROVE_NODE_COUNT: int = 100
const GROVE_REPLACEMENT_FIRST_X: int = 36
const GROVE_REPLACEMENT_LAST_X: int = 49
const GROVE_REPLACEMENT_FIRST_Z: int = 50
const GROVE_REPLACEMENT_LAST_Z: int = 67

## §5.9 states a regrow period for trees and NONE for stone or iron, and §5.9 says surface stone
## deposits "can exhaust". `resource_nodes.gd` documents 0 as "never regrows"; that encoding is its
## contract, and the separately named renewable bedrock access is what an ore node with a period
## would be. No period is invented for either deposit.
const ORE_REGROW_DAYS: int = 0

## §5.1: "renewable bedrock access (48,70)". Recorded, deliberately NOT placed -- see the header.
const BEDROCK_ACCESS_X: int = 48
const BEDROCK_ACCESS_Z: int = 70

## §5.1: "Arrival/departure exit is (64,126)". Recorded, not modelled -- there is no navigation.
const MAP_EXIT_X: int = 64
const MAP_EXIT_Z: int = 126

# --- seeding and the generation contract (GDD §5.1) --------------------------------------------

## §5.1: "A fixed-seed tutorial uses seed 20260905."
const TUTORIAL_WORLD_SEED: int = 20260905
## §5.1: "A failed topology assertion rejects generation after at most 16 seed attempts".
const MAX_SEED_ATTEMPTS: int = 16
## §5.1: "Invalid seeds are rejected and regenerated with seed+1."
const SEED_RETRY_STEP: int = 1
## §5.1: "starting at year 1/spring/day 1/06:00" -- every node generated here is planted on day 1.
const OPENING_CALENDAR_DAY: int = 1

## Task 04.3: "Scenario identity is an explicit versioned initialization input." One preset exists:
## §5.1's "deterministic authored estuary preset". An unknown version refuses rather than falling
## back to the estuary's values, which is exactly what 04.3 forbids.
const SCENARIO_ESTUARY_V1: int = 1

const FORAGE_PATCH_KINDS: int = 5
const FISH_SPECIES_COUNT: int = 9

# --- §5.1's generator guarantees, as measured thresholds ---------------------------------------
## "Terrain generator validation guarantees: one river edge within 24 m, one forest zone within
## 32 m, 64 loam tiles within 24 m, a 1200 U wood stock and 1200 U stone deposit within 48 m,
## renewable saplings, and an iron deposit within 80 m."

const ANCHOR_TILE_X: int = 64
const ANCHOR_TILE_Z: int = 64
const RIVER_EDGE_MAX_METRES: int = 24
const FOREST_ZONE_MAX_METRES: int = 32
const LOAM_MAX_METRES: int = 24
const LOAM_MIN_TILES: int = 64
const WOOD_MAX_METRES: int = 48
const WOOD_MIN_U: int = 1200
const STONE_MAX_METRES: int = 48
const STONE_MIN_U: int = 1200
const IRON_MAX_METRES: int = 80

# --- refusal codes ------------------------------------------------------------------------------
## Every one names the exact thing that failed. No sentinel value ever signals failure.

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_SCENARIO: StringName = &"WORLD_UNKNOWN_SCENARIO_VERSION"
const REFUSE_SEED_NOT_INT32: StringName = &"WORLD_SEED_NOT_INT32"
const REFUSE_SEED_ADVANCE_OVERFLOW: StringName = &"WORLD_SEED_ADVANCE_OVERFLOW"
const REFUSE_ITEM_SET_SIZE: StringName = &"WORLD_ITEM_SET_SIZE"
const REFUSE_INVALID_ITEM_ID: StringName = &"WORLD_INVALID_ITEM_ID"
## READY_07 §2: a request whose item ids were never resolved against the compiled catalog. The
## binding boundary's own codes (ITEM_BINDING_*) are propagated unchanged when one IS supplied.
const REFUSE_UNBOUND_ITEM_CATALOG: StringName = &"WORLD_UNBOUND_ITEM_CATALOG"
const REFUSE_MISSING_STORE: StringName = &"WORLD_MISSING_STORE"
const REFUSE_SHARED_DIRECTORY: StringName = &"WORLD_STORE_DIRECTORY_MISMATCH"
const REFUSE_FOREIGN_LIVE_ROWS: StringName = &"WORLD_FOREIGN_LIVE_ROWS"
const REFUSE_CAPACITY_RESOURCE_NODE: StringName = &"CAPACITY_RESOURCE_NODE"
const REFUSE_CAPACITY_HARVEST_ZONE: StringName = &"CAPACITY_HARVEST_ZONE"
const REFUSE_CAPACITY_FISH_HABITAT: StringName = &"CAPACITY_FISH_HABITAT"
const REFUSE_CAPACITY_DIRECTORY: StringName = &"CAPACITY_DIRECTORY"
const REFUSE_GROVE_INCOMPLETE: StringName = &"WORLD_GROVE_INCOMPLETE"
const REFUSE_NOT_PUBLISHED: StringName = &"WORLD_NOT_PUBLISHED"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_NO_SOIL_ON_WATER: StringName = &"WORLD_NO_SOIL_ON_WATER"

## §5.1's generator guarantees, one code each, evaluated in this order.
const ASSERT_RIVER_EDGE: StringName = &"ASSERT_RIVER_EDGE_WITHIN_24M"
const ASSERT_FOREST_ZONE: StringName = &"ASSERT_FOREST_ZONE_WITHIN_32M"
const ASSERT_LOAM_TILES: StringName = &"ASSERT_64_LOAM_TILES_WITHIN_24M"
const ASSERT_WOOD_STOCK: StringName = &"ASSERT_1200U_WOOD_WITHIN_48M"
const ASSERT_STONE_DEPOSIT: StringName = &"ASSERT_1200U_STONE_WITHIN_48M"
const ASSERT_RENEWABLE_SAPLINGS: StringName = &"ASSERT_RENEWABLE_SAPLINGS"
const ASSERT_IRON_DEPOSIT: StringName = &"ASSERT_IRON_DEPOSIT_WITHIN_80M"
const ASSERT_GROVE_COUNT: StringName = &"ASSERT_GUARANTEED_GROVE_IS_100"

## REQ-SET-059 / GDD §4.2: "FaunaStockReserved ... Reserved allocation only: all numeric fields 0,
## refs (-1,0), no active rows or updates." systems_architecture.md §2.2 sizes it at 384 rows, eight
## I32 columns and one I64. It is ALLOCATED here and has NO mutator anywhere: SET-AMEND-001 §3
## retired hunting, so a live fauna row is not a feature waiting to be written, and §5.1's
## north/south "migration partners" therefore have no stored link -- `migration_link` is one of the
## numeric fields REQ-SET-059 pins at 0.
const FAUNA_STOCK_ROWS: int = 384
const FAUNA_I32_COLUMNS: int = 8
const FAUNA_I64_COLUMNS: int = 1

const BYTES_PER_BYTE_COLUMN: int = 1
const BYTES_PER_INT32: int = 4
const BYTES_PER_INT64: int = 8


class Request:
	"""Task 04.3's "explicit versioned initialization input": everything generation cannot derive.

	`scenario_version` is checked against SCENARIO_ESTUARY_V1 before anything else, so no other
	scenario can inherit the estuary's values by fallback.

	THE SEVENTEEN ITEM IDS ARE NO LONGER "THE CALLER'S". READY_07 §2 ruled that
	`ResourceNode.resource_id`, `ForagePatch.item_id` and each fish stock's item-id field all name
	compiled `ItemDefinition` ids, so the five fields below are three scalars plus arrays of five
	and nine -- seventeen bindings, resolved by key in `resource_catalog_binding.gd` and nowhere
	else. `binding` is the boundary that resolved them; `_refuse_request()` re-proves every
	position against it, so an id that merely LOOKS storable, a sorted array, two exchanged arrays
	or a foreign catalog's id refuses before a store is touched. `make_request()` and
	`bound_request()` below build a correct one; nothing in this module invents an id.
	"""
	var scenario_version: int = SCENARIO_ESTUARY_V1
	var world_seed: int = TUTORIAL_WORLD_SEED
	var binding: ResourceCatalogBinding = null
	var tree_resource_id: int = ResourceCatalogBinding.ABSENT_ITEM_ID
	var stone_resource_id: int = ResourceCatalogBinding.ABSENT_ITEM_ID
	var iron_resource_id: int = ResourceCatalogBinding.ABSENT_ITEM_ID
	var forage_item_ids: PackedInt32Array = PackedInt32Array()
	var fish_species_item_ids: PackedInt32Array = PackedInt32Array()


class RequestResult:
	"""Outcome of the checked request construction. `.ok` MUST be inspected first.

	A refusal carries the binding boundary's own StringName code and a null `request`: there is no
	half-bound `Request`, no fallback id and no substituted free resource to mistake for one.
	"""
	var ok: bool
	var error: StringName
	var detail: String
	var request: Request

	func _init(p_ok: bool, p_error: StringName, p_detail: String, p_request: Request) -> void:
		"""Store the outcome fields for one request-construction attempt."""
		ok = p_ok
		error = p_error
		detail = p_detail
		request = p_request


class Measurements:
	"""The straight-line quantities §5.1's generator guarantees are stated in.

	Distances are SQUARED, in simulation units, so no square root and no float ever enters an
	authoritative comparison. Task 04.3 blocks the reachability half of these guarantees on task
	05's topology: a tile 24 m away in a straight line may have no route, and `validate()` does not
	claim otherwise.
	"""
	var river_edge_distance_sq: int = -1
	var forest_zone_distance_sq: int = -1
	var loam_tiles_in_range: int = 0
	var wood_milli_in_range: int = 0
	var stone_milli_in_range: int = 0
	var renewable_tree_nodes: int = 0
	var iron_distance_sq: int = -1
	var grove_nodes: int = 0


class GenerateResult:
	"""Outcome of one world generation: the accepted seed, or the exact assertion that failed.

	`.ok` MUST be inspected before any other field. A refusal carries the failing code and leaves
	every collaborating store byte-identical, because a refusal is decided before any of them is
	written. `attempts` counts §5.1's seed attempts, at most MAX_SEED_ATTEMPTS.
	"""
	var ok: bool = false
	var error: StringName = REFUSE_NONE
	var attempts: int = 0
	var accepted_seed: int = 0
	var resource_nodes_created: int = 0
	var basins_created: int = 0
	var fish_stocks_created: int = 0


# --- collaborators ------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _nodes: ResourceNodesScript = null
var _forage: ForageScript = null
var _fishing: FishingScript = null
var _rng: Rng = null
var _farming: FarmingScript = null
var _orchards: OrchardHiveScript = null
var _jobs: JobsScript = null
var _commands: CommandsScript = null

# --- published world map (ARCH-MEM-001: packed columns, allocated once) -------------------------

var _terrain: PackedByteArray = PackedByteArray()
var _soil: PackedByteArray = PackedByteArray()
var _basin: PackedByteArray = PackedByteArray()
var _cleared: PackedByteArray = PackedByteArray()
var _basin_ref_slot: PackedInt32Array = PackedInt32Array()
var _basin_ref_generation: PackedInt32Array = PackedInt32Array()
var _basin_danger: PackedInt32Array = PackedInt32Array()
var _published: bool = false
var _published_seed: int = 0

# --- staged world map: the same allocation again, swapped in at publish -------------------------

var _staged_terrain: PackedByteArray = PackedByteArray()
var _staged_soil: PackedByteArray = PackedByteArray()
var _staged_basin: PackedByteArray = PackedByteArray()
var _staged_cleared: PackedByteArray = PackedByteArray()
var _staged_used: PackedByteArray = PackedByteArray()
var _staged_danger: PackedInt32Array = PackedInt32Array()
var _staged_centres: PackedInt32Array = PackedInt32Array()
var _staged_centre_count: int = 0
var _staged_grove: PackedInt32Array = PackedInt32Array()
var _staged_grove_count: int = 0
## The nine fish item ids re-addressed from §5.4 SPECIES ROW order into `fishing.gd`'s habitat-
## major argument order. Allocated once in `_init()`; see `_habitat_major_fish_item_ids()`.
var _staged_fish_item_ids: PackedInt32Array = PackedInt32Array()

# --- FaunaStockReserved: canonical empty allocation, no mutator (REQ-SET-059) -------------------

var _fauna_zone_slot: PackedInt32Array = PackedInt32Array()
var _fauna_zone_generation: PackedInt32Array = PackedInt32Array()
var _fauna_species_id: PackedInt32Array = PackedInt32Array()
var _fauna_population: PackedInt32Array = PackedInt32Array()
var _fauna_capacity: PackedInt32Array = PackedInt32Array()
var _fauna_tracks: PackedInt32Array = PackedInt32Array()
var _fauna_harvest_today: PackedInt32Array = PackedInt32Array()
var _fauna_migration_link: PackedInt32Array = PackedInt32Array()
var _fauna_birth_remainder: PackedInt64Array = PackedInt64Array()

# --- scratch (not simulation state) -------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()
var _measured: Measurements = Measurements.new()
var _foreign_kind: int = EntityDirectory.KIND_ANY


func _init(p_directory: EntityDirectory, p_nodes: ResourceNodesScript,
		p_forage: ForageScript, p_fishing: FishingScript, p_rng: Rng,
		p_farming: FarmingScript = null, p_orchards: OrchardHiveScript = null,
		p_jobs: JobsScript = null, p_commands: CommandsScript = null) -> void:
	"""Adopt the stores this generator populates and allocate both map buffers exactly once."""
	_directory = p_directory
	_nodes = p_nodes
	_forage = p_forage
	_fishing = p_fishing
	_rng = p_rng
	_farming = p_farming
	_orchards = p_orchards
	_jobs = p_jobs
	_commands = p_commands
	_allocate_columns()
	_assert_authored_constants()
	_stage_masks()


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_terrain.resize(TILE_COUNT)
	_soil.resize(TILE_COUNT)
	_basin.resize(TILE_COUNT)
	_cleared.resize(TILE_COUNT)
	_staged_terrain.resize(TILE_COUNT)
	_staged_soil.resize(TILE_COUNT)
	_staged_basin.resize(TILE_COUNT)
	_staged_cleared.resize(TILE_COUNT)
	_staged_used.resize(TILE_COUNT)
	_basin_ref_slot.resize(BASIN_COUNT)
	_basin_ref_generation.resize(BASIN_COUNT)
	_basin_danger.resize(BASIN_COUNT)
	_staged_danger.resize(BASIN_COUNT)
	_staged_centres.resize(TREE_CENTER_CAP)
	_staged_grove.resize(GROVE_NODE_COUNT)
	_staged_fish_item_ids.resize(FISH_SPECIES_COUNT)
	_allocate_fauna_columns()
	_reset_published()


func _allocate_fauna_columns() -> void:
	"""Allocate REQ-SET-059's reserved fauna rows once, canonically empty, and never write again."""
	_fauna_zone_slot.resize(FAUNA_STOCK_ROWS)
	_fauna_zone_generation.resize(FAUNA_STOCK_ROWS)
	_fauna_species_id.resize(FAUNA_STOCK_ROWS)
	_fauna_population.resize(FAUNA_STOCK_ROWS)
	_fauna_capacity.resize(FAUNA_STOCK_ROWS)
	_fauna_tracks.resize(FAUNA_STOCK_ROWS)
	_fauna_harvest_today.resize(FAUNA_STOCK_ROWS)
	_fauna_migration_link.resize(FAUNA_STOCK_ROWS)
	_fauna_birth_remainder.resize(FAUNA_STOCK_ROWS)
	_fauna_zone_slot.fill(EntityDirectory.NULL_SLOT)
	_fauna_zone_generation.fill(EntityDirectory.NULL_GENERATION)
	_fauna_species_id.fill(0)
	_fauna_population.fill(0)
	_fauna_capacity.fill(0)
	_fauna_tracks.fill(0)
	_fauna_harvest_today.fill(0)
	_fauna_migration_link.fill(0)
	_fauna_birth_remainder.fill(0)


func _assert_authored_constants() -> void:
	"""Drift guard on the transcribed §5.1 relationships this module cannot restate elsewhere."""
	assert(TERRAIN_COAST < TERRAIN_RIVER and TERRAIN_RIVER < TERRAIN_LAKE
			and TERRAIN_LAKE < TERRAIN_LAND,
		"terrain ordinals must be GDD 5.1's mask priority: coast, river, lake, land")
	assert(TILE_SIZE_UNITS == 2 * UNITS_PER_METRE, "one exterior tile is exactly 2 m")
	assert(GROVE_NODE_COUNT
			== (GROVE_LAST_X - GROVE_FIRST_X + 1) * (GROVE_LAST_Z - GROVE_FIRST_Z + 1),
		"the guaranteed grove is one tree per tile of GDD 5.1's 10x10 rectangle")
	assert(TREE_WOOD_MILLI * (WOOD_MIN_U / TREE_WOOD_U) == WOOD_MIN_U * MILLI_PER_UNIT,
		"1200 U of wood must be a whole number of 12 U tree nodes")
	assert(BASIN_COUNT == FOREST_BASIN_COUNT + FISH_BASIN_COUNT,
		"the basin roster is four forest partitions plus decision 0037's three fish habitats")
	assert(HALL_SIZE_X - 2 * HALL_INTERIOR_OFFSET == 10 and HALL_SIZE_Z - 2 * HALL_INTERIOR_OFFSET == 8,
		"GDD 5.9's hall interior 10x8 must close against its 12x10 footprint at origin+(1,1)")
	_assert_footprints_dont_overlap()


func _assert_footprints_dont_overlap() -> void:
	"""Drift guard on READY_07 §7.1: "building footprints may not" overlap, and all fit the grid.

	Authored constants cannot vary at runtime, so a failure here is a transcription error in this
	file, not a world that could be refused. 21 distinct pairs, checked once per generator.
	"""
	for first: int in STARTER_FOOTPRINT_COUNT:
		assert(STARTER_FOOTPRINT_ORIGIN_X[first] >= 0
				and STARTER_FOOTPRINT_ORIGIN_X[first] + STARTER_FOOTPRINT_SIZE_X[first] <= MAP_TILES_X
				and STARTER_FOOTPRINT_ORIGIN_Z[first] >= 0
				and STARTER_FOOTPRINT_ORIGIN_Z[first] + STARTER_FOOTPRINT_SIZE_Z[first] <= MAP_TILES_Z,
			"authored footprint %d leaves the 128x128 exterior grid" % first)
		for second: int in range(first + 1, STARTER_FOOTPRINT_COUNT):
			assert(not starter_footprints_overlap(first, second),
				"authored footprints %d and %d overlap; GDD 5.9 places none on another" % [first, second])


func _reset_published() -> void:
	"""Return the published map to its empty state without reallocating one of its columns."""
	_terrain.fill(TERRAIN_LAND)
	_soil.fill(SOIL_NONE)
	_basin.fill(NO_BASIN)
	_cleared.fill(0)
	_basin_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_basin_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_basin_danger.fill(0)
	_published = false
	_published_seed = 0


# --- the tile primitive (GDD §5.1) --------------------------------------------------------------

static func is_tile_index(tile: int) -> bool:
	"""True when `tile` names an exterior tile of the 128x128 grid."""
	return tile >= 0 and tile < TILE_COUNT


static func tile_index_of(x: int, z: int) -> int:
	"""GDD §5.1's `z*128+x`, or -1 when either coordinate leaves the grid.

	-1 is the absence of a tile, never a refusal: `is_tile_index()` is the predicate a caller
	tests, and every public reader below refuses explicitly on an off-grid argument.
	"""
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return -1
	return z * MAP_TILES_X + x


static func tile_x_of(tile: int) -> int:
	"""The x of an exterior tile index, or -1 when it is off the grid."""
	return tile % MAP_TILES_X if is_tile_index(tile) else -1


static func tile_z_of(tile: int) -> int:
	"""The z of an exterior tile index, or -1 when it is off the grid."""
	return tile / MAP_TILES_X if is_tile_index(tile) else -1


static func tile_center_x_units(x: int) -> int:
	"""GDD §5.1's `2048*x+1024`."""
	return TILE_SIZE_UNITS * x + TILE_CENTER_OFFSET_UNITS


static func tile_center_z_units(z: int) -> int:
	"""GDD §5.1's `2048*z+1024`."""
	return TILE_SIZE_UNITS * z + TILE_CENTER_OFFSET_UNITS


static func distance_sq_units(x: int, z: int, other_x: int, other_z: int) -> int:
	"""Squared tile-center distance in simulation units. Squared so no root and no float appears."""
	var dx: int = TILE_SIZE_UNITS * (x - other_x)
	var dz: int = TILE_SIZE_UNITS * (z - other_z)
	return dx * dx + dz * dz


static func metres_sq_units(metres: int) -> int:
	"""The squared unit distance of a whole-metre threshold, for comparison against the above."""
	var units: int = metres * UNITS_PER_METRE
	return units * units


static func anchor_distance_sq(x: int, z: int) -> int:
	"""Squared distance from a tile to §5.1's validation anchor, tile (64,64). See the header."""
	return distance_sq_units(x, z, ANCHOR_TILE_X, ANCHOR_TILE_Z)


# --- terrain masks ------------------------------------------------------------------------------

static func is_coast_mask(_x: int, z: int) -> bool:
	"""GDD §5.1: "Coast is z=0..15"; x is unconstrained, so the whole northern band is coast."""
	return z >= COAST_FIRST_Z and z <= COAST_LAST_Z


static func is_river_mask(x: int, z: int) -> bool:
	"""GDD §5.1: "river is x=76..78 and z=16..127"."""
	return x >= RIVER_FIRST_X and x <= RIVER_LAST_X \
		and z >= RIVER_FIRST_Z and z <= RIVER_LAST_Z


static func is_lake_mask(x: int, z: int) -> bool:
	"""GDD §5.1: "lake is `(x-100)^2+(z-66)^2<=14^2`"."""
	var dx: int = x - LAKE_CENTER_X
	var dz: int = z - LAKE_CENTER_Z
	return dx * dx + dz * dz <= LAKE_RADIUS_TILES * LAKE_RADIUS_TILES


static func resolve_terrain(in_coast: bool, in_river: bool, in_lake: bool) -> int:
	"""GDD §5.1's mask PRIORITY -- "coast, river, lake, land" -- and the only place it is applied.

	Taking the three memberships rather than a coordinate is deliberate: on the authored estuary
	the three masks never overlap, so the precedence is unobservable from the map alone and a
	reordering here would pass every map-shaped test. This form is testable at all eight
	combinations.
	"""
	if in_coast:
		return TERRAIN_COAST
	if in_river:
		return TERRAIN_RIVER
	if in_lake:
		return TERRAIN_LAKE
	return TERRAIN_LAND


static func terrain_of(x: int, z: int) -> int:
	"""The terrain kind of one tile under §5.1's mask priority."""
	return resolve_terrain(is_coast_mask(x, z), is_river_mask(x, z), is_lake_mask(x, z))


static func is_ford(x: int, z: int) -> bool:
	"""GDD §5.1's natural ford: the river tiles z=48..51, which are walkable and not fishable."""
	return is_river_mask(x, z) and z >= FORD_FIRST_Z and z <= FORD_LAST_Z


static func elevation_y_units_of(x: int, z: int) -> int:
	"""GDD §5.1's three surface heights: land 512, ford -128, every other water tile 0."""
	if is_ford(x, z):
		return FORD_Y_UNITS
	if terrain_of(x, z) == TERRAIN_LAND:
		return LAND_Y_UNITS
	return WATER_SURFACE_Y_UNITS


static func is_walkable(x: int, z: int) -> bool:
	"""GDD §5.1: land is navigable and the ford is "walkable"; all other water blocks residents.

	SET-MOVE-001 supersedes the blocking half as a release-wide swimming exclusion; this is the
	baseline-fixture answer §5.1 states, and it decides no movement here because no movement
	system exists.
	"""
	return terrain_of(x, z) == TERRAIN_LAND or is_ford(x, z)


# --- soil bands ---------------------------------------------------------------------------------

static func is_loam_band(x: int, z: int) -> bool:
	"""GDD §5.1: "LOAM for x=40..74,z=40..88"."""
	return x >= LOAM_FIRST_X and x <= LOAM_LAST_X and z >= LOAM_FIRST_Z and z <= LOAM_LAST_Z


static func is_sand_band(x: int, z: int) -> bool:
	"""GDD §5.1: "SAND within 4 tiles of coast or x>=112".

	Coast is the full band z=0..15, so "within 4 tiles of coast" is z<=19 for every x under any
	metric: the nearest coast tile of a land tile at (x,z) is always (x,15).
	"""
	return z <= COAST_LAST_Z + SAND_COAST_DISTANCE_TILES or x >= SAND_FIRST_X


static func resolve_soil(in_loam: bool, in_sand: bool) -> int:
	"""GDD §5.1's soil sentence IN ITS STATED ORDER: LOAM, then SAND, then CLAY otherwise.

	Like `resolve_terrain()`, this takes memberships rather than coordinates so the ORDER is
	testable: on the authored map the loam rectangle and the sand bands do not overlap, so
	swapping the two branches changes no tile and would survive any map-shaped test.
	"""
	if in_loam:
		return SOIL_LOAM
	if in_sand:
		return SOIL_SAND
	return SOIL_CLAY


static func soil_of(x: int, z: int) -> int:
	"""The soil of one LAND tile, or SOIL_NONE where §5.1 puts water and soil does not apply."""
	if terrain_of(x, z) != TERRAIN_LAND:
		return SOIL_NONE
	return resolve_soil(is_loam_band(x, z), is_sand_band(x, z))


static func is_cleared_tile(x: int, z: int) -> bool:
	"""All three things GDD §5.1 clears before resource placement, as one predicate.

	§5.1: "Clear initial building footprints, a one-tile apron, and the loam rectangle
	x=58..65,z=46..53 before placing resource nodes." CORRECTED 2026-09-11 (READY_07 §7.1): an
	earlier revision cleared only the loam rectangle and recorded the footprints as unimplemented.
	They are implemented here from §5.9's authored coordinates and table extents.

	The three parts may overlap freely -- the workbench apron reaches z=53 inside the loam
	rectangle, and neighbouring aprons share tiles -- because clearing is idempotent: a tile is
	cleared or it is not. READY_07 §7.1: "Shared aprons may overlap as cleared ground; building
	footprints may not", and the footprint half of that is asserted in `_assert_footprints_dont_overlap()`.
	"""
	return is_cleared_loam_tile(x, z) or is_starter_footprint_tile(x, z) \
		or is_starter_apron_tile(x, z)


static func is_cleared_loam_tile(x: int, z: int) -> bool:
	"""GDD §5.1's authored loam rectangle x=58..65,z=46..53, cleared before resource placement."""
	return x >= CLEARED_LOAM_FIRST_X and x <= CLEARED_LOAM_LAST_X \
		and z >= CLEARED_LOAM_FIRST_Z and z <= CLEARED_LOAM_LAST_Z


static func is_starter_footprint_tile(x: int, z: int) -> bool:
	"""True when (x,z) lies under one of §5.9's seven authored starter building footprints."""
	for index: int in STARTER_FOOTPRINT_COUNT:
		if footprint_covers_tile(index, x, z, FOOTPRINT_NO_APRON):
			return true
	return false


static func is_starter_apron_tile(x: int, z: int) -> bool:
	"""True when (x,z) is in §5.1's one-tile apron of some footprint and under no footprint.

	The apron is the RING outside its footprint, so `is_starter_footprint_tile()` and this one
	partition the cleared building ground and never double-count a tile. A tile shared by two
	aprons answers true once, which is READY_07 §7.1's permitted overlap.
	"""
	if is_starter_footprint_tile(x, z):
		return false
	for index: int in STARTER_FOOTPRINT_COUNT:
		if footprint_covers_tile(index, x, z, FOOTPRINT_APRON_TILES):
			return true
	return false


static func footprint_covers_tile(index: int, x: int, z: int, margin: int) -> bool:
	"""True when (x,z) lies inside starter footprint `index` grown by `margin` tiles on every side.

	`margin` 0 asks about the footprint, `FOOTPRINT_APRON_TILES` about the footprint plus §5.1's
	apron. An `index` outside the roster names no footprint, so no tile lies inside it; that is an
	empty set, not a failure signal, and the roster is a compile-time constant that cannot vary.
	"""
	if index < 0 or index >= STARTER_FOOTPRINT_COUNT:
		return false
	var origin_x: int = STARTER_FOOTPRINT_ORIGIN_X[index]
	var origin_z: int = STARTER_FOOTPRINT_ORIGIN_Z[index]
	return x >= origin_x - margin and x <= origin_x + STARTER_FOOTPRINT_SIZE_X[index] - 1 + margin \
		and z >= origin_z - margin and z <= origin_z + STARTER_FOOTPRINT_SIZE_Z[index] - 1 + margin


static func starter_footprints_overlap(first: int, second: int) -> bool:
	"""True when authored footprints `first` and `second` share at least one tile.

	READY_07 §7.1: "building footprints may not" overlap. Two ranges overlap exactly when each
	starts at or before the other one ends, on both axes at once. A footprint trivially overlaps
	itself, so callers compare distinct roster positions.
	"""
	if first < 0 or first >= STARTER_FOOTPRINT_COUNT:
		return false
	if second < 0 or second >= STARTER_FOOTPRINT_COUNT:
		return false
	var first_x: int = STARTER_FOOTPRINT_ORIGIN_X[first]
	var second_x: int = STARTER_FOOTPRINT_ORIGIN_X[second]
	var first_z: int = STARTER_FOOTPRINT_ORIGIN_Z[first]
	var second_z: int = STARTER_FOOTPRINT_ORIGIN_Z[second]
	return first_x <= second_x + STARTER_FOOTPRINT_SIZE_X[second] - 1 \
		and second_x <= first_x + STARTER_FOOTPRINT_SIZE_X[first] - 1 \
		and first_z <= second_z + STARTER_FOOTPRINT_SIZE_Z[second] - 1 \
		and second_z <= first_z + STARTER_FOOTPRINT_SIZE_Z[first] - 1


# --- ecology basin membership -------------------------------------------------------------------

static func forest_basin_of(x: int, z: int) -> int:
	"""The forest ecology basin of a LAND tile, or NO_BASIN.

	§5.1's two rectangles "excluding water", each "split at z=62 into north/south migration
	partners", with north the decreasing-z side the macro map declares.
	"""
	if terrain_of(x, z) != TERRAIN_LAND:
		return NO_BASIN
	if z < FOREST_BASIN_FIRST_Z or z > FOREST_BASIN_LAST_Z:
		return NO_BASIN
	var south: int = 1 if z >= BASIN_SPLIT_Z else 0
	if x >= WEST_BASIN_FIRST_X and x <= WEST_BASIN_LAST_X:
		return BASIN_FOREST_WEST_NORTH + south
	if x >= EAST_BASIN_FIRST_X and x <= EAST_BASIN_LAST_X:
		return BASIN_FOREST_EAST_NORTH + south
	return NO_BASIN


static func fish_basin_of(x: int, z: int) -> int:
	"""The fish ecology basin of a water tile, or NO_BASIN.

	Decision 0037 §8B: exactly one coast, one lake and one river basin. The ford is river water and
	is deliberately excluded -- §5.1 says it "is not a fishing work tile" -- so it belongs to no
	basin and `is_fishing_work_tile()` is false there.
	"""
	if is_ford(x, z):
		return NO_BASIN
	match terrain_of(x, z):
		TERRAIN_COAST:
			return BASIN_FISH_COAST
		TERRAIN_LAKE:
			return BASIN_FISH_LAKE
		TERRAIN_RIVER:
			return BASIN_FISH_RIVER
	return NO_BASIN


static func basin_of(x: int, z: int) -> int:
	"""The ecology basin owning one tile's stock, forest or fish, or NO_BASIN."""
	var forest: int = forest_basin_of(x, z)
	if forest != NO_BASIN:
		return forest
	return fish_basin_of(x, z)


static func is_fish_basin(basin_index: int) -> bool:
	"""True for decision 0037's three fish habitats' basins."""
	return basin_index >= BASIN_FISH_COAST and basin_index < BASIN_COUNT


static func basin_bounds(basin_index: int) -> Rect2i:
	"""The bounding box of one basin, inclusive of both corners. Used only to band §5.5's danger."""
	match basin_index:
		BASIN_FOREST_WEST_NORTH:
			return _inclusive_rect(WEST_BASIN_FIRST_X, FOREST_BASIN_FIRST_Z,
				WEST_BASIN_LAST_X, BASIN_SPLIT_Z - 1)
		BASIN_FOREST_WEST_SOUTH:
			return _inclusive_rect(WEST_BASIN_FIRST_X, BASIN_SPLIT_Z,
				WEST_BASIN_LAST_X, FOREST_BASIN_LAST_Z)
		BASIN_FOREST_EAST_NORTH:
			return _inclusive_rect(EAST_BASIN_FIRST_X, FOREST_BASIN_FIRST_Z,
				EAST_BASIN_LAST_X, BASIN_SPLIT_Z - 1)
		BASIN_FOREST_EAST_SOUTH:
			return _inclusive_rect(EAST_BASIN_FIRST_X, BASIN_SPLIT_Z,
				EAST_BASIN_LAST_X, FOREST_BASIN_LAST_Z)
		BASIN_FISH_COAST:
			return _inclusive_rect(0, COAST_FIRST_Z, MAP_TILES_X - 1, COAST_LAST_Z)
		BASIN_FISH_LAKE:
			return _inclusive_rect(LAKE_CENTER_X - LAKE_RADIUS_TILES,
				LAKE_CENTER_Z - LAKE_RADIUS_TILES, LAKE_CENTER_X + LAKE_RADIUS_TILES,
				LAKE_CENTER_Z + LAKE_RADIUS_TILES)
		BASIN_FISH_RIVER:
			return _inclusive_rect(RIVER_FIRST_X, RIVER_FIRST_Z, RIVER_LAST_X, RIVER_LAST_Z)
	return Rect2i(0, 0, 0, 0)


static func _inclusive_rect(first_x: int, first_z: int, last_x: int, last_z: int) -> Rect2i:
	"""A Rect2i covering both corners inclusively. Presentation-free: these are tile indices."""
	return Rect2i(first_x, first_z, last_x - first_x + 1, last_z - first_z + 1)


static func danger_band_of_half_tiles(distance_sq_half_tiles: int) -> int:
	"""§5.5's fixed-at-generation danger band from a squared HALF-TILE distance to the anchor.

	Band 0 is unreachable at generation: it requires a STAFFED LOOKOUT and a new world has none.
	Half-tile units remove the only rounding decision -- a bounding-box center can land on a half
	tile -- so no "basin center" rounding rule has to be invented.
	"""
	if distance_sq_half_tiles <= DANGER_BAND_NEAR_HALF_TILES * DANGER_BAND_NEAR_HALF_TILES:
		return DANGER_NEAR
	if distance_sq_half_tiles <= DANGER_BAND_MID_HALF_TILES * DANGER_BAND_MID_HALF_TILES:
		return DANGER_MID
	return DANGER_FAR


static func basin_danger_band(basin_index: int) -> int:
	"""§5.5's natural danger for one basin: its bounding-box center's distance category.

	"Natural danger is the basin center's distance category before lookout reductions, fixed at
	generation." The anchor is the header's derived map-center tile; §5.5 names the CENTRAL HALL,
	whose footprint is task 06's and which §5.1 places within 32 m of that anchor. All seven basins
	sit 39-113 half-tiles from it and none is within 5 half-tiles of a band edge, so this band is
	stable for any hall within about 4 tiles of the anchor and is NOT proved for the full 16-tile
	latitude §5.1 allows. That residual is recorded in decision 0048.
	"""
	var bounds: Rect2i = basin_bounds(basin_index)
	var dx: int = 2 * bounds.position.x + bounds.size.x - 1 - 2 * ANCHOR_TILE_X
	var dz: int = 2 * bounds.position.y + bounds.size.y - 1 - 2 * ANCHOR_TILE_Z
	return danger_band_of_half_tiles(dx * dx + dz * dz)


# --- published-world readers --------------------------------------------------------------------

func directory() -> EntityDirectory:
	"""The allocator this generator clears and publishes every world entity out of.

	Published so a composing system can PROVE, at composition time, that the generator shares its
	one directory rather than discovering a second allocator when `WORLD_STORE_DIRECTORY_MISMATCH`
	refuses a generation. It hands back the same object the constructor was given; it creates none.
	"""
	return _directory


func clear() -> void:
	"""Discard the published map so this generator reports no world, reallocating nothing.

	The COMPANION to `_reset_stores()`, and deliberately NOT the same thing. `_reset_stores()`
	empties the collaborating stores, which this does not touch: a caller that has just emptied
	them itself -- `settlement_system.gd`'s `reset()` -- would otherwise be left holding a
	generator still answering `is_published()` true over terrain whose resource nodes, basins and
	habitats no longer exist. That inconsistency is exactly the half-settlement decision 0059
	forbids, so the settlement's reset calls this and the two halves stay in step.

	No column is resized; `_reset_published()` refills the published buffers in place.
	"""
	_reset_published()


func is_published() -> bool:
	"""True once a generation has published a world, and false before the first one succeeds."""
	return _published


func published_seed() -> IntMath.IntResult:
	"""The accepted world seed of the published world, or an explicit refusal while none exists."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _published:
		out.refuse(String(REFUSE_NOT_PUBLISHED))
		return out
	out.succeed(_published_seed)
	return out


func terrain_at(tile: int) -> IntMath.IntResult:
	"""The published terrain kind of one tile, or an explicit refusal."""
	return _read_tile(tile, _terrain)


func soil_at(tile: int) -> IntMath.IntResult:
	"""The published soil of one LAND tile; a water tile REFUSES rather than returning SOIL_NONE."""
	var out: IntMath.IntResult = _read_tile(tile, _soil)
	if out.ok and out.value == SOIL_NONE:
		out.refuse(String(REFUSE_NO_SOIL_ON_WATER))
	return out


func basin_index_at(tile: int) -> IntMath.IntResult:
	"""The published ecology basin index of one tile, or NO_BASIN, or an explicit refusal."""
	return _read_tile(tile, _basin)


func is_cleared_at(tile: int) -> bool:
	"""True when the published map has this tile cleared before resource placement."""
	return _published and is_tile_index(tile) and _cleared[tile] == 1


func is_fishing_work_tile(tile: int) -> bool:
	"""True when the published map lets a FISH job work this tile. False on the ford (§5.1)."""
	if not _published or not is_tile_index(tile):
		return false
	return is_fish_basin(_basin[tile])


func _read_tile(tile: int, column: PackedByteArray) -> IntMath.IntResult:
	"""One byte of a published tile column, refusing off-grid indices and an unpublished world."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _published:
		out.refuse(String(REFUSE_NOT_PUBLISHED))
		return out
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(column[tile])
	return out


func basin_ref_of(basin_index: int) -> Vector2i:
	"""The HarvestZone reference of one published ecology basin, or the null reference."""
	if not _published or basin_index < 0 or basin_index >= BASIN_COUNT:
		return EntityDirectory.NULL_REF
	return Vector2i(_basin_ref_slot[basin_index], _basin_ref_generation[basin_index])


func basin_ref_for_tile(tile: int) -> Vector2i:
	"""The basin owning one tile's ecological stock, or the null reference.

	R05-BASIN-003 requires a designation's binding to "agree with the actual harvesting location";
	this is the map side of that check, and it costs no HarvestZone tile link.
	"""
	if not _published or not is_tile_index(tile):
		return EntityDirectory.NULL_REF
	return basin_ref_of(_basin[tile])


func basin_danger_of(basin_index: int) -> IntMath.IntResult:
	"""§5.5's natural danger stored for one published basin, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _published or basin_index < 0 or basin_index >= BASIN_COUNT:
		out.refuse(String(REFUSE_NOT_PUBLISHED))
		return out
	out.succeed(_basin_danger[basin_index])
	return out


func foreign_kind() -> int:
	"""The directory kind whose live rows blocked the last REFUSE_FOREIGN_LIVE_ROWS, or KIND_ANY."""
	return _foreign_kind


func fauna_row_capacity() -> int:
	"""Rows of REQ-SET-059's reserved fauna allocation. Never any of them live."""
	return _fauna_zone_slot.size()


func fauna_zone_ref_of(row: int) -> Vector2i:
	"""The reserved fauna row's zone reference, which REQ-SET-059 pins at the null reference."""
	if row < 0 or row >= FAUNA_STOCK_ROWS:
		return EntityDirectory.NULL_REF
	return Vector2i(_fauna_zone_slot[row], _fauna_zone_generation[row])


func fauna_is_canonically_empty() -> bool:
	"""True while every reserved fauna row still holds §4.2's "all numeric fields 0, refs (-1,0)".

	Nothing in this repository writes these columns, so this is a guard against a future one, not a
	check on this module's own behaviour.
	"""
	for row: int in FAUNA_STOCK_ROWS:
		if fauna_zone_ref_of(row) != EntityDirectory.NULL_REF:
			return false
		if _fauna_species_id[row] != 0 or _fauna_population[row] != 0 \
				or _fauna_capacity[row] != 0 or _fauna_tracks[row] != 0:
			return false
		if _fauna_harvest_today[row] != 0 or _fauna_migration_link[row] != 0 \
				or _fauna_birth_remainder[row] != 0:
			return false
	return true


func fauna_reserved_bytes() -> int:
	"""Bytes of REQ-SET-059's reserved fauna allocation, for the ARCH-MEM-009 ledger."""
	return FAUNA_STOCK_ROWS * (FAUNA_I32_COLUMNS * BYTES_PER_INT32
		+ FAUNA_I64_COLUMNS * BYTES_PER_INT64)


func planned_tree_centre_count() -> int:
	"""How many §5.1 tree centres the current plan holds, after the 3000 cap."""
	return _staged_centre_count


func planned_tree_centre_at(index: int) -> IntMath.IntResult:
	"""The tile of one planned tree centre, in ascending tile order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _staged_centre_count:
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_staged_centres[index])
	return out


func planned_grove_count() -> int:
	"""How many guaranteed grove nodes the current plan holds. §5.1 requires exactly 100."""
	return _staged_grove_count


func planned_grove_at(index: int) -> IntMath.IntResult:
	"""The tile of one planned grove node -- in-grove first, then the replacements, both ascending."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _staged_grove_count:
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_staged_grove[index])
	return out


func map_payload_bytes() -> int:
	"""Bytes of packed world-map storage this module owns, for the ARCH-MEM-009 ledger."""
	var tile_columns: int = 9 * TILE_COUNT * BYTES_PER_BYTE_COLUMN
	var basin_columns: int = 4 * BASIN_COUNT * BYTES_PER_INT32
	var plan_columns: int = (TREE_CENTER_CAP + GROVE_NODE_COUNT) * BYTES_PER_INT32
	return tile_columns + basin_columns + plan_columns


# --- checked request construction (READY_07 §2) -------------------------------------------------

static func make_request(binding: ResourceCatalogBinding,
		world_seed: int = TUTORIAL_WORLD_SEED) -> RequestResult:
	"""Build a fully bound estuary request from an opened binding boundary, or refuse.

	This is the construction half of READY_07 §2's boundary: the seventeen ids are resolved BY KEY
	and copied straight into the request, so the forage and fish arrays are in `PATCH_KEYS` and
	`SPECIES_KEYS` row order by construction and no caller ever chooses an id.
	"""
	if binding == null:
		return RequestResult.new(false, REFUSE_UNBOUND_ITEM_CATALOG,
			"no catalog binding boundary was supplied", null)
	if not IntMath.fits_int32(world_seed):
		return RequestResult.new(false, REFUSE_SEED_NOT_INT32,
			"seed %d is not an int32" % world_seed, null)
	var bound: ResourceCatalogBinding.BindResult = binding.resolve()
	if not bound.ok:
		return RequestResult.new(false, bound.error, bound.detail, null)
	var request: Request = Request.new()
	request.scenario_version = SCENARIO_ESTUARY_V1
	request.world_seed = world_seed
	request.binding = binding
	request.tree_resource_id = bound.binding.tree_resource_id
	request.stone_resource_id = bound.binding.stone_resource_id
	request.iron_resource_id = bound.binding.iron_resource_id
	request.forage_item_ids = bound.binding.forage_item_ids.duplicate()
	request.fish_species_item_ids = bound.binding.fish_species_item_ids.duplicate()
	return RequestResult.new(true, REFUSE_NONE, "", request)


static func bound_request(items: ItemDefinitionsScript,
		world_seed: int = TUTORIAL_WORLD_SEED,
		artifact_path: String = ResourceCatalogBinding.DEFAULT_ARTIFACT_PATH) -> RequestResult:
	"""Open the binding boundary against a loaded item registry and build the request, or refuse.

	The entry point for a caller that knows only the catalog: it names no item key and no numeric
	id. Verifying the committed artifact is part of opening, so a stale catalog refuses here.
	"""
	var opened: ResourceCatalogBinding.OpenResult = ResourceCatalogBinding.open(
		items, artifact_path)
	if not opened.ok:
		return RequestResult.new(false, opened.error, opened.detail, null)
	return make_request(opened.boundary as ResourceCatalogBinding, world_seed)


# --- generation: the seed-attempt loop (GDD §5.1) -----------------------------------------------

func generate(request: Request) -> GenerateResult:
	"""Generate and publish one world, retrying with seed+1 for at most 16 attempts.

	§5.1: "Invalid seeds are rejected and regenerated with seed+1" and "A failed topology assertion
	rejects generation after at most 16 seed attempts and returns the explicit failed assertion".
	The authored geometry is seed-independent, so a repeated topology failure is an implementation
	error rather than bad luck -- every attempt then returns the same assertion, which is what the
	caller sees. A refusal leaves the previous published world and every store untouched.
	"""
	var result: GenerateResult = GenerateResult.new()
	var attempt_seed: int = request.world_seed
	for attempt: int in MAX_SEED_ATTEMPTS:
		result.attempts = attempt + 1
		var code: StringName = _try_seed(request, attempt_seed)
		if code == REFUSE_NONE:
			return _succeed_generation(result, attempt_seed)
		result.error = code
		if attempt + 1 == MAX_SEED_ATTEMPTS:
			return result
		if not IntMath.checked_add_into(attempt_seed, SEED_RETRY_STEP, _math):
			result.error = REFUSE_SEED_ADVANCE_OVERFLOW
			return result
		attempt_seed = _math.value
	return result


func _try_seed(request: Request, world_seed: int) -> StringName:
	"""Prepare and validate one candidate seed, publishing it when every assertion holds.

	Nothing outside this object is written until `_publish()`, so a refusal from either stage is
	the failed assertion AND the guarantee that the previous world is byte-identical.
	"""
	var code: StringName = _prepare(request, world_seed)
	if code != REFUSE_NONE:
		return code
	code = _validate()
	if code != REFUSE_NONE:
		return code
	_publish(request, world_seed)
	return REFUSE_NONE


func _succeed_generation(result: GenerateResult, world_seed: int) -> GenerateResult:
	"""Fill the successful outcome from the freshly published stores."""
	result.ok = true
	result.error = REFUSE_NONE
	result.accepted_seed = world_seed
	result.resource_nodes_created = _nodes.count()
	result.basins_created = _forage.zone_count()
	result.fish_stocks_created = _fishing.habitat_count() * FishingScript.SPECIES_PER_HABITAT
	return result


# --- stage 1: prepare ---------------------------------------------------------------------------

func _prepare(request: Request, world_seed: int) -> StringName:
	"""Build the whole world plan into the STAGED columns and prove every store can accept it.

	Task 04.3's prepare stage. It writes only this object's staging buffers; the collaborating
	stores are read for capacity and never mutated, which is what makes a later refusal free.
	"""
	var code: StringName = _refuse_request(request, world_seed)
	if code != REFUSE_NONE:
		return code
	code = _refuse_collaborators()
	if code != REFUSE_NONE:
		return code
	_stage_masks()
	_stage_tree_plan()
	code = _refuse_capacity()
	if code != REFUSE_NONE:
		return code
	return REFUSE_NONE


func _refuse_request(request: Request, world_seed: int) -> StringName:
	"""The code blocking this scenario request, or REFUSE_NONE when all seventeen ids are bound.

	The shape checks come first so a wrong-length or negative-id request reports what it actually
	is, then `_refuse_binding()` proves every position against the compiled catalog. Both run
	before any store is read for capacity, let alone written.
	"""
	if request.scenario_version != SCENARIO_ESTUARY_V1:
		return REFUSE_UNKNOWN_SCENARIO
	if not IntMath.fits_int32(world_seed):
		return REFUSE_SEED_NOT_INT32
	if request.forage_item_ids.size() != FORAGE_PATCH_KINDS:
		return REFUSE_ITEM_SET_SIZE
	if request.fish_species_item_ids.size() != FISH_SPECIES_COUNT:
		return REFUSE_ITEM_SET_SIZE
	if not _item_id_is_storable(request.tree_resource_id) \
			or not _item_id_is_storable(request.stone_resource_id) \
			or not _item_id_is_storable(request.iron_resource_id):
		return REFUSE_INVALID_ITEM_ID
	for item_id: int in request.forage_item_ids:
		if not _item_id_is_storable(item_id):
			return REFUSE_INVALID_ITEM_ID
	for item_id: int in request.fish_species_item_ids:
		if not _item_id_is_storable(item_id):
			return REFUSE_INVALID_ITEM_ID
	return _refuse_binding(request)


func _item_id_is_storable(item_id: int) -> bool:
	"""True for a non-negative int32 id: the shape a column can hold, NOT proof of a right id.

	READY_07 §2 named this exact weakness -- "accepts an arbitrary valid-looking integer, so it
	cannot prove correct catalogs". It is kept as the cheap shape precondition that gives a
	malformed id its own code; `_refuse_binding()` is what proves the id is the right one.
	"""
	return item_id >= 0 and IntMath.fits_int32(item_id)


func _refuse_binding(request: Request) -> StringName:
	"""Prove all seventeen ids are the compiled ids their required keys carry, in consumer order.

	READY_07 §2's checked binding boundary. A request with no boundary cannot be proved at all and
	refuses rather than being trusted; otherwise the boundary's own StringName code is propagated
	unchanged, so the caller sees which of missing key, retired key, wrong key, exchanged arrays,
	wrong length or stale artifact stopped it.
	"""
	if request.binding == null:
		return REFUSE_UNBOUND_ITEM_CATALOG
	var proved: ResourceCatalogBinding.BindResult = request.binding.verify_ids(
		request.tree_resource_id, request.stone_resource_id, request.iron_resource_id,
		request.forage_item_ids, request.fish_species_item_ids)
	if not proved.ok:
		return proved.error
	return REFUSE_NONE


func _refuse_collaborators() -> StringName:
	"""Prove the store set is complete, shares one directory, and owns every live row in it.

	Publishing clears the DIRECTORY, so a row owned by a store this generator was not given would
	be silently orphaned. Refusing here is the difference between an explicit
	WORLD_FOREIGN_LIVE_ROWS and a settlement whose residents lose their identities.
	"""
	_foreign_kind = EntityDirectory.KIND_ANY
	if _directory == null or _nodes == null or _forage == null or _fishing == null \
			or _rng == null:
		return REFUSE_MISSING_STORE
	if _nodes.directory() != _directory or _forage.directory() != _directory \
			or _fishing.directory() != _directory:
		return REFUSE_SHARED_DIRECTORY
	for kind: int in EntityDirectory.KIND_COUNT:
		if _directory.live_count(kind) == 0 or _owns_kind(kind):
			continue
		_foreign_kind = kind
		return REFUSE_FOREIGN_LIVE_ROWS
	return REFUSE_NONE


func _owns_kind(kind: int) -> bool:
	"""True when a store this generator was given owns every live row of `kind` and will clear it."""
	match kind:
		EntityDirectory.KIND_RESOURCE_NODE, EntityDirectory.KIND_HARVEST_ZONE, \
		EntityDirectory.KIND_FISH_HABITAT:
			return true
		EntityDirectory.KIND_FARM_PLOT:
			return _farming != null
		EntityDirectory.KIND_ORCHARD_PLOT, EntityDirectory.KIND_HIVE:
			return _orchards != null
		EntityDirectory.KIND_JOB:
			return _jobs != null
	return false


func _refuse_capacity() -> StringName:
	"""Prove every allocator can accept the staged plan before a single row is cleared or written.

	The counts are the staged plan's own, not estimates: tree centres plus grove nodes plus
	decision 0029's 32 ore nodes less the centres those footprints replace.
	"""
	var zones: int = BASIN_COUNT
	var nodes: int = _staged_centre_count + _staged_grove_count + _ore_node_total()
	if nodes > ResourceNodesScript.RESOURCE_NODE_CAPACITY:
		return REFUSE_CAPACITY_RESOURCE_NODE
	if zones > ForageScript.HARVEST_ZONE_CAPACITY:
		return REFUSE_CAPACITY_HARVEST_ZONE
	if FISH_BASIN_COUNT > FishingScript.FISH_HABITAT_CAPACITY:
		return REFUSE_CAPACITY_FISH_HABITAT
	if nodes + zones + FISH_BASIN_COUNT > EntityDirectory.DIRECTORY_CAPACITY:
		return REFUSE_CAPACITY_DIRECTORY
	if _staged_grove_count != GROVE_NODE_COUNT:
		return REFUSE_GROVE_INCOMPLETE
	return REFUSE_NONE


func _ore_node_total() -> int:
	"""Decision 0029's two deposits: sixteen independently exhaustible nodes each."""
	return 2 * ResourceNodesScript.DEPOSIT_NODE_COUNT


# --- stage 1a: the terrain, soil, cleared and basin masks ---------------------------------------

func _stage_masks() -> void:
	"""Write §5.1's four per-tile masks into the staged columns, in the order the section states.

	Terrain first because soil and basin membership both read it: soil exists only on land, and
	§5.1's forest basins are rectangles "excluding water".

	The cleared column written here is what `_stage_tree_plan()` then CONSULTS, which is how §5.1's
	"before placing resource nodes" is executed as an order rather than restated as a coincidence.
	"""
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			var tile: int = z * MAP_TILES_X + x
			_staged_terrain[tile] = terrain_of(x, z)
			_staged_soil[tile] = soil_of(x, z)
			_staged_cleared[tile] = 1 if is_cleared_tile(x, z) else 0
			_staged_basin[tile] = basin_of(x, z)
	for basin_index: int in BASIN_COUNT:
		_staged_danger[basin_index] = basin_danger_band(basin_index)


# --- stage 1b: the tree plan --------------------------------------------------------------------

func _stage_tree_plan() -> void:
	"""Plan every tree node: §5.1's capped centres first, then the guaranteed grove on top of them.

	Order is §5.1's own: the grove skips "duplicate centers", so the centres must exist first for a
	grove tile to be a duplicate of anything. `_stage_masks()` must have run first -- every tile
	test below reads the STAGED CLEARED COLUMN, so running this stage before the clearing plants
	trees on ground §5.1 clears.
	"""
	_staged_used.fill(0)
	_staged_centre_count = collect_tree_centres_into(TREE_CENTER_CAP, _staged_centres)
	for index: int in _staged_centre_count:
		_staged_used[_staged_centres[index]] = 1
	_staged_grove_count = _collect_grove_tiles_into(_staged_grove)


static func retained_centre_count(qualifying: int, cap: int) -> int:
	"""GDD §5.1: "If more than 3000 centers qualify, retain the lowest tile indices."

	The retention is a COUNT because the qualifying centres are enumerated in ascending tile-index
	order, so the lowest `cap` of them are the first `cap` of them.
	"""
	return cap if qualifying > cap else qualifying


func collect_tree_centres_into(cap: int, out: PackedInt32Array) -> int:
	"""Fill `out` with the forest-mask tree centres in ascending tile order, retaining the lowest
	`cap` of them, and return how many were written.

	§5.1's "every second x/every second z in forest masks", where the forest mask is the forest
	ecology basins (see the header). `out` is caller-owned and is never resized here; a `cap`
	larger than it refuses nothing, it simply cannot be reached. Two passes because the retention
	rule is stated in terms of how many QUALIFY.
	"""
	var qualifying: int = 0
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			if _is_tree_centre(x, z):
				qualifying += 1
	var keep: int = retained_centre_count(qualifying, mini(cap, out.size()))
	var written: int = 0
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			if written >= keep:
				return written
			if _is_tree_centre(x, z):
				out[written] = z * MAP_TILES_X + x
				written += 1
	return written


static func is_centre_candidate(x: int, z: int, cleared: bool) -> bool:
	"""§5.1's tree-centre rule: even stride, inside a forest mask, and spared by the clearing.

	`cleared` is an ARGUMENT rather than a recomputation so that the clearing STAGE decides it --
	§5.1's "before placing resource nodes" as an executed order. Pure, so the rule is testable on
	its own; on the authored map the `cleared` branch is never taken, because the only cleared
	column inside a forest mask is the odd x=49 and a centre needs even x.
	"""
	if x % TREE_CENTER_STRIDE != 0 or z % TREE_CENTER_STRIDE != 0:
		return false
	if cleared:
		return false
	return forest_basin_of(x, z) != NO_BASIN


func _is_tree_centre(x: int, z: int) -> bool:
	"""§5.1's centre rule applied to one tile, with the STAGED clearing mask supplying `cleared`.

	KNOWN SURVIVING MUTANT, recorded rather than hidden (decision 0060): replacing the mask read
	below with a literal `false` leaves the whole suite green, because on the AUTHORED map no
	cleared tile is ever an even/even forest tile. That is not an untested line, it is a proved
	one: `test_the_clearing_takes_no_tree_centre_because_its_forest_overlap_is_odd` asserts over
	all 16384 tiles that the buildings clear exactly eleven forest tiles and all of them sit in the
	odd column x=49. The read stays because it is the correct rule for any footprint that is ever
	moved into a forest mask, and `is_centre_candidate()` is tested against both values directly.
	"""
	return is_centre_candidate(x, z, _staged_cleared[z * MAP_TILES_X + x] == 1)


func _is_plantable_tile(tile: int) -> bool:
	"""True when no centre or earlier grove node holds `tile` and §5.1's clearing spared it.

	The single gate BOTH grove passes use, so §5.1's "skipping duplicate centers and all cleared
	aprons" is stated once and cannot drift between the two.
	"""
	return _staged_used[tile] == 0 and _staged_cleared[tile] == 0


func _collect_grove_tiles_into(out: PackedInt32Array) -> int:
	"""Fill `out` with §5.1's guaranteed grove: 100 tiles carrying 100 NEW tree nodes.

	"one per tile, skipping duplicate centers and all cleared aprons; replace any skipped center at
	the lowest unused land tile inside x=36..49,z=50..67 until exactly 100 guaranteed nodes exist".
	Requires the centre plan to already be marked in `_staged_used`. Returns the count written,
	which is below GROVE_NODE_COUNT only if the replacement window runs out -- `_refuse_capacity()`
	turns that into WORLD_GROVE_INCOMPLETE rather than a short grove.
	"""
	var written: int = 0
	for z: int in range(GROVE_FIRST_Z, GROVE_LAST_Z + 1):
		for x: int in range(GROVE_FIRST_X, GROVE_LAST_X + 1):
			var tile: int = z * MAP_TILES_X + x
			if not _is_plantable_tile(tile):
				continue
			if written >= out.size():
				return written
			out[written] = tile
			_staged_used[tile] = 1
			written += 1
	return _append_grove_replacements(out, written)


func _append_grove_replacements(out: PackedInt32Array, from: int) -> int:
	"""Append the lowest unused land tiles of §5.1's replacement window until the grove is 100.

	The window is scanned in ascending tile-index order, so "the lowest unused land tile" is simply
	the first one this scan reaches that no centre, no earlier grove node and no clearing holds.
	Each accepted tile is marked used as it is taken, so the window can overlap the grove itself --
	as §5.1's x=36..49,z=50..67 does -- without a tile being planted twice.
	"""
	var written: int = from
	for z: int in range(GROVE_REPLACEMENT_FIRST_Z, GROVE_REPLACEMENT_LAST_Z + 1):
		for x: int in range(GROVE_REPLACEMENT_FIRST_X, GROVE_REPLACEMENT_LAST_X + 1):
			if written >= GROVE_NODE_COUNT or written >= out.size():
				return written
			var tile: int = z * MAP_TILES_X + x
			if not _is_plantable_tile(tile):
				continue
			if terrain_of(x, z) != TERRAIN_LAND:
				continue
			out[written] = tile
			_staged_used[tile] = 1
			written += 1
	return written


# --- stage 2: validate --------------------------------------------------------------------------

func _validate() -> StringName:
	"""Check §5.1's generator guarantees against the staged plan, in the order the section lists.

	This is the STRAIGHT-LINE half. Task 04.3 blocks the reachability half on task 05's topology,
	so nothing here claims a route exists to any of these tiles.
	"""
	_measure_into(_measured)
	return validate_measurements(_measured)


static func validate_measurements(measured: Measurements) -> StringName:
	"""The first §5.1 guarantee `measured` fails, or REFUSE_NONE when every one of them holds.

	Pure, so every assertion and the ORDER they are reported in is testable without a map.
	"""
	if not _within(measured.river_edge_distance_sq, RIVER_EDGE_MAX_METRES):
		return ASSERT_RIVER_EDGE
	if not _within(measured.forest_zone_distance_sq, FOREST_ZONE_MAX_METRES):
		return ASSERT_FOREST_ZONE
	if measured.loam_tiles_in_range < LOAM_MIN_TILES:
		return ASSERT_LOAM_TILES
	if measured.wood_milli_in_range < WOOD_MIN_U * MILLI_PER_UNIT:
		return ASSERT_WOOD_STOCK
	if measured.stone_milli_in_range < STONE_MIN_U * MILLI_PER_UNIT:
		return ASSERT_STONE_DEPOSIT
	if measured.renewable_tree_nodes <= 0:
		return ASSERT_RENEWABLE_SAPLINGS
	if not _within(measured.iron_distance_sq, IRON_MAX_METRES):
		return ASSERT_IRON_DEPOSIT
	if measured.grove_nodes != GROVE_NODE_COUNT:
		return ASSERT_GROVE_COUNT
	return REFUSE_NONE


static func _within(distance_sq: int, metres: int) -> bool:
	"""True when a measured squared distance is at or inside a whole-metre threshold.

	A negative distance means "nothing of that kind was found at all" and is never within range.
	"""
	return distance_sq >= 0 and distance_sq <= metres_sq_units(metres)


func _measure_into(out: Measurements) -> void:
	"""Measure the staged plan into `out`. Allocates nothing; `out` is caller-owned."""
	out.river_edge_distance_sq = _nearest_terrain_distance_sq(TERRAIN_RIVER)
	out.forest_zone_distance_sq = _nearest_forest_distance_sq()
	out.loam_tiles_in_range = _loam_tiles_within(LOAM_MAX_METRES)
	out.wood_milli_in_range = _wood_milli_within(WOOD_MAX_METRES)
	out.stone_milli_in_range = _deposit_milli_within(ResourceNodesScript.STONE_DEPOSIT_ORIGIN_X,
		ResourceNodesScript.STONE_DEPOSIT_ORIGIN_Z,
		ResourceNodesScript.STONE_DEPOSIT_NODE_MILLI, STONE_MAX_METRES)
	out.renewable_tree_nodes = 0 if TREE_REGROW_DAYS <= 0 \
		else _staged_centre_count + _staged_grove_count
	out.iron_distance_sq = _deposit_distance_sq(ResourceNodesScript.IRON_DEPOSIT_ORIGIN_X,
		ResourceNodesScript.IRON_DEPOSIT_ORIGIN_Z)
	out.grove_nodes = _staged_grove_count


func _nearest_terrain_distance_sq(terrain: int) -> int:
	"""Squared anchor distance of the nearest staged tile of one terrain kind, or -1 if none."""
	var best: int = -1
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			if _staged_terrain[z * MAP_TILES_X + x] != terrain:
				continue
			var measured: int = anchor_distance_sq(x, z)
			if best < 0 or measured < best:
				best = measured
	return best


func _nearest_forest_distance_sq() -> int:
	"""Squared anchor distance of the nearest staged forest-basin tile, or -1 when none exists."""
	var best: int = -1
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			if _staged_basin[z * MAP_TILES_X + x] >= BASIN_FISH_COAST:
				continue
			var measured: int = anchor_distance_sq(x, z)
			if best < 0 or measured < best:
				best = measured
	return best


func _loam_tiles_within(metres: int) -> int:
	"""How many staged LOAM tiles lie within a whole-metre straight-line range of the anchor."""
	var limit: int = metres_sq_units(metres)
	var found: int = 0
	for z: int in MAP_TILES_Z:
		for x: int in MAP_TILES_X:
			if _staged_soil[z * MAP_TILES_X + x] != SOIL_LOAM:
				continue
			if anchor_distance_sq(x, z) <= limit:
				found += 1
	return found


func _wood_milli_within(metres: int) -> int:
	"""Staged wood stock within range: §5.1's 12 U per mature node, centres and grove together."""
	var limit: int = metres_sq_units(metres)
	var total: int = 0
	for index: int in _staged_centre_count:
		if _tile_within(_staged_centres[index], limit):
			total += TREE_WOOD_MILLI
	for index: int in _staged_grove_count:
		if _tile_within(_staged_grove[index], limit):
			total += TREE_WOOD_MILLI
	return total


func _tile_within(tile: int, limit_sq: int) -> bool:
	"""True when a tile index lies within a squared anchor distance."""
	return anchor_distance_sq(tile % MAP_TILES_X, tile / MAP_TILES_X) <= limit_sq


func _deposit_milli_within(origin_x: int, origin_z: int, per_node_milli: int, metres: int) -> int:
	"""Ore quantity of one 4x4 deposit whose footprint tiles lie within range of the anchor."""
	var limit: int = metres_sq_units(metres)
	var total: int = 0
	for dz: int in ResourceNodesScript.DEPOSIT_FOOTPRINT_SIZE:
		for dx: int in ResourceNodesScript.DEPOSIT_FOOTPRINT_SIZE:
			if anchor_distance_sq(origin_x + dx, origin_z + dz) <= limit:
				total += per_node_milli
	return total


func _deposit_distance_sq(origin_x: int, origin_z: int) -> int:
	"""Squared anchor distance of the nearest tile of one 4x4 ore footprint."""
	var best: int = -1
	for dz: int in ResourceNodesScript.DEPOSIT_FOOTPRINT_SIZE:
		for dx: int in ResourceNodesScript.DEPOSIT_FOOTPRINT_SIZE:
			var measured: int = anchor_distance_sq(origin_x + dx, origin_z + dz)
			if best < 0 or measured < best:
				best = measured
	return best


# --- stage 3: publish ---------------------------------------------------------------------------

func _publish(request: Request, world_seed: int) -> void:
	"""Reset every store, seed the RNG, swap in the staged map and create the world's rows.

	Task 04.3: "Explicitly reset RNG, generation/free-slot state, child arenas, job and command
	state before exposing an active world." Reached only after `_prepare()` and `_validate()` have
	proved every refusal away, so each OpResult below is asserted rather than handled: a refusal
	here means the preflight is wrong, and there is nothing left to roll back to.
	"""
	_reset_stores()
	var seeded: Rng.OpResult = _rng.seed_world(world_seed)
	assert(seeded.ok, "prepare proved the seed is an int32")
	_swap_staged_map()
	_published = true
	_published_seed = world_seed
	_publish_forest_basins(request)
	_publish_fish_basins(request)
	_publish_tree_nodes(request)
	_publish_ore_deposits(request)


func _reset_stores() -> void:
	"""Clear every store this generator owns, then the directory's generation/free-slot state.

	Stores first: each releases its own directory rows, so clearing the directory afterwards resets
	the free heaps and the persistent-ID counter with nothing stranded. `EntityDirectory.clear()`
	deliberately does NOT reset generations (ARCH-ID-002); that is its contract, not an omission.
	"""
	_nodes.clear()
	_forage.clear()
	_fishing.clear()
	if _farming != null:
		_farming.clear()
	if _orchards != null:
		_orchards.clear()
	if _jobs != null:
		_jobs.clear()
	if _commands != null:
		_commands.clear()
	_rng.clear()
	_directory.clear()
	_reset_published()


func _swap_staged_map() -> void:
	"""Exchange the staged and published map buffers. O(1), and neither array is reallocated."""
	var terrain: PackedByteArray = _terrain
	var soil: PackedByteArray = _soil
	var basin: PackedByteArray = _basin
	var cleared: PackedByteArray = _cleared
	var danger: PackedInt32Array = _basin_danger
	_terrain = _staged_terrain
	_soil = _staged_soil
	_basin = _staged_basin
	_cleared = _staged_cleared
	_basin_danger = _staged_danger
	_staged_terrain = terrain
	_staged_soil = soil
	_staged_basin = basin
	_staged_cleared = cleared
	_staged_danger = danger


func _publish_forest_basins(request: Request) -> void:
	"""Create §5.1's four forest ecology basins and their five §5.5 patches each.

	R05-BASIN-001: a stock-owning basin is created by world generation alone. `create_zone()` makes
	the zone its own basin, and `create_patch_set()` fills all five patches -- including the
	seasonally dormant ones -- to §5.1's "floor(0.8xcapacity)", which `forage.gd` applies itself.

	`quota_milli` 0, `protected` false and `enabled` false are §5.1's own closing rule -- "All other
	initial fields follow the registry zero/null defaults unless a catalog specifies a different
	value" -- and no catalog specifies a HarvestZone default. All three are inert on a BASIN under
	every current reader: `job_planner.gd`'s enabled/protected gate and `forage.gd`'s harvest gate
	both read the DESIGNATION's row, and a basin fails `is_designation()` before either matters.
	The hazard, recorded in decision 0048, is that a future reader could treat a disabled basin as
	a closure; the literal transcription is kept rather than a friendlier invented `true`.
	"""
	for basin_index: int in FOREST_BASIN_COUNT:
		var created: ForageScript.OpResult = _forage.create_zone(ForageScript.ZONE_TYPE_FORAGE,
			_basin_danger[basin_index], 0, false, false)
		assert(created.ok, "prepare proved a HarvestZone row and a directory slot are free")
		_record_basin_ref(basin_index, created.ref)
		var patches: ForageScript.OpResult = _forage.create_patch_set(created.ref,
			request.forage_item_ids)
		assert(patches.ok, "prepare proved every forage item id is storable")


func _publish_fish_basins(request: Request) -> void:
	"""Create decision 0037 §8B's three FISH basins, its nine stocks, and bind each habitat.

	`fishing.generate_initial_estuary()` is the ruled ecology-creation operation and owns the
	capacities and the 80% stocks; this only supplies the species item ids and points each habitat
	at the basin zone that owns it, so a later FISH designation can resolve designation -> basin ->
	habitat without any of them creating stock.
	"""
	for basin_index: int in range(BASIN_FISH_COAST, BASIN_COUNT):
		var created: ForageScript.OpResult = _forage.create_zone(ForageScript.ZONE_TYPE_FISH,
			_basin_danger[basin_index], 0, false, false)
		assert(created.ok, "prepare proved a HarvestZone row and a directory slot are free")
		_record_basin_ref(basin_index, created.ref)
	var estuary: FishingScript.OpResult = _fishing.generate_initial_estuary(
		_habitat_major_fish_item_ids(request))
	assert(estuary.ok, "prepare proved three habitat rows and nine species ids")
	_bind_habitats()


func _habitat_major_fish_item_ids(request: Request) -> PackedInt32Array:
	"""Re-address the request's nine item ids from §5.4 SPECIES ROW order into habitat-major order.

	TWO DIFFERENT INDEXES, AND THEY DISAGREE. READY_07 §2 fixes `fish_species_item_ids` in
	`Fishing.SPECIES_KEYS` order -- trout, dace, salmon, perch, carp, whitefish, herring, mackerel,
	mussel -- which is §5.4's RIVER, LAKE, COAST table order. `generate_initial_estuary()` takes
	its argument addressed `habitat_type * 3 + species_index` under the COMPILED HabitatType
	ordinals COAST=0, LAKE=1, RIVER=2, and writes `species_ids[species_index]` into the stock whose
	§5.4 row is `HABITAT_SPECIES_ROWS[habitat_type * 3 + species_index]`.

	Passing the request array straight through therefore gave the coast the river's three item ids
	and the river the coast's -- silently, because the lake's middle triple coincides under both
	orders and every fixture used opaque integers. The permutation below is read from `fishing.gd`'s
	OWN explicit binding table, so neither order is retyped here and neither module's contract
	moves. Decision 0052 records the defect and why the adapter belongs on this side.
	"""
	for position: int in FISH_SPECIES_COUNT:
		_staged_fish_item_ids[position] = request.fish_species_item_ids[
			FishingScript.HABITAT_SPECIES_ROWS[position]]
	return _staged_fish_item_ids


func _bind_habitats() -> void:
	"""Bind each generated habitat to the FISH basin zone of the same habitat type."""
	for index: int in _fishing.habitat_count():
		var slot: IntMath.IntResult = _fishing.live_habitat_slot_at(index)
		assert(slot.ok, "the habitat count and the live list agree")
		var habitat_type: IntMath.IntResult = _fishing.habitat_type_of(slot.value)
		assert(habitat_type.ok, "a live habitat has a type")
		var bound: FishingScript.OpResult = _fishing.bind_habitat_zone(
			_fishing.habitat_ref_of(slot.value), basin_ref_of(_basin_for_habitat(habitat_type.value)))
		assert(bound.ok, "each FISH basin was created self-owning and is claimed once")


static func _basin_for_habitat(habitat_type: int) -> int:
	"""The basin index owning one compiled habitat type's stock."""
	return BASIN_FISH_COAST + habitat_type


func _record_basin_ref(basin_index: int, ref: Vector2i) -> void:
	"""Store the HarvestZone reference of one published basin."""
	_basin_ref_slot[basin_index] = ref.x
	_basin_ref_generation[basin_index] = ref.y


func _publish_tree_nodes(request: Request) -> void:
	"""Place every planned tree node: the capped centres first, then the guaranteed grove."""
	for index: int in _staged_centre_count:
		_create_tree(request, _staged_centres[index])
	for index: int in _staged_grove_count:
		_create_tree(request, _staged_grove[index])


func _create_tree(request: Request, tile: int) -> void:
	"""Create one mature tree node: §5.1's 12 wood U, §5.9's 48-day regrowth, planted on day 1."""
	var created: ResourceNodesScript.OpResult = _nodes.create_at_tile(tile,
		request.tree_resource_id, TREE_WOOD_MILLI, TREE_REGROW_DAYS, OPENING_CALENDAR_DAY)
	assert(created.ok, "prepare proved the node capacity and every planned tile is unique")


func _publish_ore_deposits(request: Request) -> void:
	"""Place §5.1's two guaranteed deposits through `resource_nodes.gd`, never reimplemented here.

	Decision 0029 owns the sixteen-node split and the ascending tile order; decision 0031 owns the
	declared replaceable occupant, which is the tree id because §5.1 says "Ore footprints replace
	tree nodes" and nothing else may be destroyed. Stone before iron, as §5.1 lists them.
	"""
	var stone: ResourceNodesScript.OpResult = _nodes.place_stone_deposit(request.stone_resource_id,
		ORE_REGROW_DAYS, OPENING_CALENDAR_DAY, request.tree_resource_id)
	assert(stone.ok, "the stone footprint holds only planned tree nodes")
	var iron: ResourceNodesScript.OpResult = _nodes.place_iron_deposit(request.iron_resource_id,
		ORE_REGROW_DAYS, OPENING_CALENDAR_DAY, request.tree_resource_id)
	assert(iron.ok, "the iron footprint holds only planned tree nodes")
