extends "res://test/framework/test_case.gd"
## REQ-SET-009: GDD §5.1's authored estuary, its ecology basins, and the prepare/validate/publish
## transaction around them.
##
## Every expected number here is transcribed from §5.1 or computed from it in the test itself, not
## copied out of `world_init.gd`. Where a count could only be confirmed by running the generator --
## the 1571 qualifying tree centres, for instance -- the test ALSO derives it independently from
## the section's own rule, so a mutation to the production predicate cannot move both.

const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResourceCatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")
const CatalogIdsScript := preload("res://scripts/core/catalog_ids.gd")

class ShortGroveWorld extends WorldInit:
	"""A generator whose grove planner always falls one node short of §5.1's hundred."""

	func _collect_grove_tiles_into(out: PackedInt32Array) -> int:
		"""Plan the real grove, then drop its last node so the completeness guard is reachable."""
		return super(out) - 1


var _residents: ResidentsScript = null
var _directory: EntityDirectory = null
var _jobs: JobsScript = null
var _nodes: ResourceNodesScript = null
var _forage: ForageScript = null
var _fishing: FishingScript = null
var _rng: RngScript = null
var _world: WorldInit = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _inventory: InventoryScript = null
var _items: ItemDefinitionsScript = null
var _binding: ResourceCatalogBinding = null
var _tree_item: int = ResourceCatalogBinding.ABSENT_ITEM_ID
var _stone_item: int = ResourceCatalogBinding.ABSENT_ITEM_ID
var _iron_item: int = ResourceCatalogBinding.ABSENT_ITEM_ID


func before_each() -> void:
	"""Compose one fresh settlement per test, every store sharing a single entity directory.

	The chain is the runtime's own: `jobs.gd` takes its directory from `residents.gd`, so the
	directory this generator is handed is the one every other store already validates against.
	"""
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	_directory = _jobs.directory()
	_nodes = ResourceNodesScript.new(_directory)
	_forage = ForageScript.new(_directory, _jobs)
	_fishing = FishingScript.new(_directory, _forage, _jobs)
	_rng = RngScript.new()
	_world = WorldInit.new(_directory, _nodes, _forage, _fishing, _rng, null, null, _jobs)
	_open_binding()


func _open_binding() -> void:
	"""Open READY_07 §2's catalog boundary, so every request in this suite is bound BY KEY.

	The three scalar ids below are read back out of the boundary rather than written here: a test
	that hardcoded 59, 52 and 19 would keep passing after the catalog renumbered them.
	"""
	_inventory = InventoryScript.new()
	_items = ItemDefinitionsScript.new()
	if not _items.load_default(_inventory).ok:
		fail("the shipped item catalog must load")
		return
	var opened: ResourceCatalogBinding.OpenResult = ResourceCatalogBinding.open(_items)
	if not opened.ok:
		fail("the catalog binding must open (error: %s)" % opened.error)
		return
	_binding = opened.boundary as ResourceCatalogBinding
	_tree_item = _binding.compiled_item_id_of(ResourceCatalogBinding.TREE_ITEM_KEY).id
	_stone_item = _binding.compiled_item_id_of(ResourceCatalogBinding.STONE_ITEM_KEY).id
	_iron_item = _binding.compiled_item_id_of(ResourceCatalogBinding.IRON_ITEM_KEY).id


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_world = null
	_rng = null
	_fishing = null
	_forage = null
	_nodes = null
	_jobs = null
	_residents = null
	_queue = null
	_clock = null
	_binding = null
	_items = null
	_inventory = null


func _request() -> WorldInit.Request:
	"""A valid estuary request whose seventeen item ids were resolved by key, never invented.

	READY_07 §2 changed this fixture: it used to carry 1, 2, 3 and 10..28, which are storable
	int32s and not catalog ids. `make_request()` is the checked construction boundary, so every
	test below now runs against the ids the shipped catalog actually compiles.
	"""
	var built: WorldInit.RequestResult = WorldInit.make_request(_binding)
	if not built.ok:
		fail("the bound request must build (error: %s)" % built.error)
		return WorldInit.Request.new()
	return built.request


func _generate() -> WorldInit.GenerateResult:
	"""Generate the shipping world and fail loudly rather than let a later assertion misreport."""
	var result: WorldInit.GenerateResult = _world.generate(_request())
	if not result.ok:
		fail("generation refused with %s" % result.error)
	return result


# --- the tile primitive -------------------------------------------------------------------------

func test_tile_index_is_z_times_128_plus_x() -> void:
	"""GDD §5.1: "Exterior tile index is `z*128+x`"."""
	assert_equal(WorldInit.tile_index_of(0, 0), 0, "tile (0,0)")
	assert_equal(WorldInit.tile_index_of(5, 3), 389, "tile (5,3) is 3*128+5")
	assert_equal(WorldInit.tile_index_of(127, 127), 16383, "the last tile")
	assert_equal(WorldInit.tile_index_of(128, 0), -1, "x off the grid has no tile")
	assert_equal(WorldInit.tile_index_of(0, 128), -1, "z off the grid has no tile")
	assert_equal(WorldInit.tile_index_of(-1, 0), -1, "negative x has no tile")


func test_tile_coordinates_invert_the_index() -> void:
	"""`tile_x_of`/`tile_z_of` recover §5.1's coordinates, and refuse an off-grid index."""
	assert_equal(WorldInit.tile_x_of(389), 5, "x of tile 389")
	assert_equal(WorldInit.tile_z_of(389), 3, "z of tile 389")
	assert_equal(WorldInit.tile_x_of(16384), -1, "no x past the grid")
	assert_equal(WorldInit.tile_z_of(-1), -1, "no z before the grid")
	assert_true(WorldInit.is_tile_index(16383), "the last tile index is on the grid")
	assert_false(WorldInit.is_tile_index(16384), "one past the last is not")


func test_tile_centre_is_2048x_plus_1024() -> void:
	"""GDD §5.1: "tile center in simulation units is `(2048*x+1024,0,2048*z+1024)`"."""
	assert_equal(WorldInit.tile_center_x_units(0), 1024, "centre of column 0")
	assert_equal(WorldInit.tile_center_z_units(64), 132096, "centre of row 64")
	assert_equal(WorldInit.tile_center_x_units(127), 261120, "centre of the last column")


func test_distance_is_squared_in_simulation_units() -> void:
	"""Distances are compared squared so no root and no float reaches an authoritative decision."""
	assert_equal(WorldInit.distance_sq_units(0, 0, 1, 0), 2048 * 2048, "one tile east")
	assert_equal(WorldInit.distance_sq_units(3, 4, 0, 0), 25 * 2048 * 2048, "a 3-4-5 triangle")
	assert_equal(WorldInit.metres_sq_units(24), 24576 * 24576, "24 m is 24576 units")
	assert_equal(WorldInit.anchor_distance_sq(64, 64), 0, "the anchor is tile (64,64)")


func test_the_validation_anchor_puts_the_river_at_exactly_24_metres() -> void:
	"""The header's derivation: only the tile-(64,64) reading satisfies §5.1's 24 m river guarantee.

	The geometric mid-point of the map is 131072 units; the nearest river tile's centre is 156672,
	which is 25600 units -- 25 m -- and fails. From tile (64,64) it is exactly 24576 units.
	"""
	var nearest_river_centre: int = WorldInit.tile_center_x_units(WorldInit.RIVER_FIRST_X)
	var midpoint_units: int = WorldInit.MAP_TILES_X * WorldInit.TILE_SIZE_UNITS / 2
	assert_equal(nearest_river_centre - midpoint_units, 25600, "25 m from the map mid-point")
	assert_true(25600 > WorldInit.RIVER_EDGE_MAX_METRES * WorldInit.UNITS_PER_METRE,
		"the mid-point reading fails the 24 m guarantee")
	assert_equal(WorldInit.anchor_distance_sq(WorldInit.RIVER_FIRST_X, WorldInit.ANCHOR_TILE_Z),
		WorldInit.metres_sq_units(WorldInit.RIVER_EDGE_MAX_METRES),
		"from tile (64,64) the nearest river tile is exactly 24 m")


# --- terrain masks and their stated priority ----------------------------------------------------

func test_mask_precedence_is_coast_river_lake_land() -> void:
	"""GDD §5.1: "Apply terrain masks in this priority: coast, river, lake, land."

	All eight membership combinations, including the ones the authored estuary never produces: on
	the shipping map the three masks are disjoint, so a reordering is invisible from the map alone.
	"""
	assert_equal(WorldInit.resolve_terrain(true, true, true), WorldInit.TERRAIN_COAST,
		"coast outranks everything")
	assert_equal(WorldInit.resolve_terrain(true, true, false), WorldInit.TERRAIN_COAST,
		"coast outranks river")
	assert_equal(WorldInit.resolve_terrain(true, false, true), WorldInit.TERRAIN_COAST,
		"coast outranks lake")
	assert_equal(WorldInit.resolve_terrain(true, false, false), WorldInit.TERRAIN_COAST,
		"coast alone")
	assert_equal(WorldInit.resolve_terrain(false, true, true), WorldInit.TERRAIN_RIVER,
		"a tile in both river and lake resolves to river")
	assert_equal(WorldInit.resolve_terrain(false, true, false), WorldInit.TERRAIN_RIVER,
		"river alone")
	assert_equal(WorldInit.resolve_terrain(false, false, true), WorldInit.TERRAIN_LAKE,
		"lake alone")
	assert_equal(WorldInit.resolve_terrain(false, false, false), WorldInit.TERRAIN_LAND,
		"land is what is left")


func test_coast_band_boundary() -> void:
	"""GDD §5.1: "Coast is z=0..15", for every x."""
	assert_true(WorldInit.is_coast_mask(0, 0), "z=0 is coast")
	assert_true(WorldInit.is_coast_mask(127, 15), "z=15 is still coast at the far column")
	assert_false(WorldInit.is_coast_mask(0, 16), "z=16 is not coast")
	assert_equal(WorldInit.terrain_of(50, 15), WorldInit.TERRAIN_COAST, "coast at z=15")
	assert_equal(WorldInit.terrain_of(50, 16), WorldInit.TERRAIN_LAND, "land at z=16")


func test_river_mask_boundary() -> void:
	"""GDD §5.1: "river is x=76..78 and z=16..127"."""
	assert_false(WorldInit.is_river_mask(75, 64), "x=75 is not river")
	assert_true(WorldInit.is_river_mask(76, 64), "x=76 is river")
	assert_true(WorldInit.is_river_mask(78, 127), "x=78, z=127 is the river's last tile")
	assert_false(WorldInit.is_river_mask(79, 64), "x=79 is not river")
	assert_false(WorldInit.is_river_mask(77, 15), "z=15 is above the river's range")
	assert_true(WorldInit.is_river_mask(77, 16), "z=16 is the river's first row")
	assert_equal(WorldInit.terrain_of(77, 16), WorldInit.TERRAIN_RIVER,
		"and it resolves to river, because coast has already ended at z=15")
	assert_equal(WorldInit.terrain_of(77, 15), WorldInit.TERRAIN_COAST,
		"the river's northern neighbour is coast, not river")


func test_lake_mask_is_the_stated_circle() -> void:
	"""GDD §5.1: "lake is `(x-100)^2+(z-66)^2<=14^2`", inclusive at the radius."""
	assert_true(WorldInit.is_lake_mask(100, 66), "the lake centre")
	assert_true(WorldInit.is_lake_mask(114, 66), "exactly 14 east is inside")
	assert_false(WorldInit.is_lake_mask(115, 66), "15 east is outside")
	assert_true(WorldInit.is_lake_mask(100, 52), "exactly 14 north is inside")
	assert_false(WorldInit.is_lake_mask(100, 51), "15 north is outside")
	assert_false(WorldInit.is_lake_mask(90, 76),
		"10 west and 10 south is 200, past the squared radius of 196")
	assert_true(WorldInit.is_lake_mask(91, 76),
		"9 west and 10 south is 181, inside it -- the test is Euclidean, not a bounding box")


func test_lake_area_matches_the_stated_circle() -> void:
	"""Independently count the circle §5.1 states and compare with the generated LAKE tiles."""
	var counted: int = 0
	for z: int in WorldInit.MAP_TILES_Z:
		for x: int in WorldInit.MAP_TILES_X:
			if (x - 100) * (x - 100) + (z - 66) * (z - 66) <= 196:
				counted += 1
	assert_equal(counted, 613, "the authored lake covers 613 tiles")
	_generate()
	var published: int = 0
	for tile: int in WorldInit.TILE_COUNT:
		if _world.terrain_at(tile).value == WorldInit.TERRAIN_LAKE:
			published += 1
	assert_equal(published, counted, "every lake tile is published as LAKE")


func test_the_ford_is_walkable_and_not_a_fishing_work_tile() -> void:
	"""GDD §5.1: the ford at "river tiles z=48..51 is walkable, y=-128 units, and is not a fishing
	work tile"."""
	assert_false(WorldInit.is_ford(77, 47), "z=47 is river, not ford")
	assert_true(WorldInit.is_ford(76, 48), "z=48 is the ford's first row")
	assert_true(WorldInit.is_ford(78, 51), "z=51 is the ford's last row")
	assert_false(WorldInit.is_ford(77, 52), "z=52 is river again")
	assert_false(WorldInit.is_ford(75, 50), "the ford is river tiles only")
	assert_equal(WorldInit.elevation_y_units_of(77, 50), -128, "the ford sits at y=-128")
	assert_true(WorldInit.is_walkable(77, 50), "the ford is walkable")
	assert_false(WorldInit.is_walkable(77, 47), "ordinary river water is not")


func test_published_ford_tiles_are_not_fishing_work_tiles() -> void:
	"""The ford's exclusion survives publication: it belongs to no fish basin."""
	_generate()
	for z: int in range(48, 52):
		for x: int in range(76, 79):
			var tile: int = WorldInit.tile_index_of(x, z)
			assert_false(_world.is_fishing_work_tile(tile), "ford tile %d is not fishable" % tile)
			assert_equal(_world.basin_index_at(tile).value, WorldInit.NO_BASIN,
				"ford tile %d belongs to no basin" % tile)
	assert_true(_world.is_fishing_work_tile(WorldInit.tile_index_of(77, 47)),
		"the river tile above the ford is a work tile")
	assert_true(_world.is_fishing_work_tile(WorldInit.tile_index_of(77, 52)),
		"the river tile below the ford is a work tile")


func test_elevations_are_the_three_stated_heights() -> void:
	"""GDD §5.1: "Water surface is y=0; navigable land y=512 units", ford y=-128."""
	assert_equal(WorldInit.elevation_y_units_of(0, 0), 0, "coast water")
	assert_equal(WorldInit.elevation_y_units_of(100, 66), 0, "lake water")
	assert_equal(WorldInit.elevation_y_units_of(77, 20), 0, "river water")
	assert_equal(WorldInit.elevation_y_units_of(64, 64), 512, "navigable land")


# --- soil bands ---------------------------------------------------------------------------------

func test_soil_precedence_is_loam_then_sand_then_clay() -> void:
	"""GDD §5.1's soil sentence in its stated order: LOAM, SAND, "CLAY otherwise"."""
	assert_equal(WorldInit.resolve_soil(true, true), WorldInit.SOIL_LOAM,
		"a tile in both bands is LOAM, because LOAM is stated first")
	assert_equal(WorldInit.resolve_soil(true, false), WorldInit.SOIL_LOAM, "loam alone")
	assert_equal(WorldInit.resolve_soil(false, true), WorldInit.SOIL_SAND, "sand alone")
	assert_equal(WorldInit.resolve_soil(false, false), WorldInit.SOIL_CLAY, "clay otherwise")


func test_loam_rectangle_boundaries() -> void:
	"""GDD §5.1: "LOAM for x=40..74,z=40..88"."""
	assert_equal(WorldInit.soil_of(40, 40), WorldInit.SOIL_LOAM, "the low corner is loam")
	assert_equal(WorldInit.soil_of(74, 88), WorldInit.SOIL_LOAM, "the high corner is loam")
	assert_equal(WorldInit.soil_of(39, 64), WorldInit.SOIL_CLAY, "one column west is clay")
	assert_equal(WorldInit.soil_of(75, 64), WorldInit.SOIL_CLAY, "one column east is clay")
	assert_equal(WorldInit.soil_of(64, 39), WorldInit.SOIL_CLAY, "one row north is clay")
	assert_equal(WorldInit.soil_of(64, 89), WorldInit.SOIL_CLAY, "one row south is clay")


func test_sand_bands_at_their_boundaries() -> void:
	"""GDD §5.1: "SAND within 4 tiles of coast or x>=112". Coast ends at z=15, so sand reaches z=19."""
	assert_equal(WorldInit.soil_of(50, 19), WorldInit.SOIL_SAND, "four tiles below the coast")
	assert_equal(WorldInit.soil_of(50, 20), WorldInit.SOIL_CLAY, "five tiles below is clay")
	assert_equal(WorldInit.soil_of(112, 100), WorldInit.SOIL_SAND, "x=112 is sand")
	assert_equal(WorldInit.soil_of(111, 100), WorldInit.SOIL_CLAY, "x=111 is clay")
	assert_equal(WorldInit.soil_of(112, 64), WorldInit.SOIL_NONE,
		"x=112 at z=64 is inside the lake, so the water mask wins before soil is asked")
	assert_equal(WorldInit.soil_of(127, 127), WorldInit.SOIL_SAND, "the far south-east is sand")


func test_water_tiles_have_no_soil_and_refuse_explicitly() -> void:
	"""Soil applies to land. A water tile REFUSES rather than reporting a fabricated soil."""
	assert_equal(WorldInit.soil_of(77, 64), WorldInit.SOIL_NONE, "river water has no soil")
	assert_equal(WorldInit.soil_of(100, 66), WorldInit.SOIL_NONE, "lake water has no soil")
	assert_equal(WorldInit.soil_of(10, 5), WorldInit.SOIL_NONE, "coast water has no soil")
	_generate()
	var refused: IntMath.IntResult = _world.soil_at(WorldInit.tile_index_of(77, 64))
	assert_false(refused.ok, "the published reader refuses on water")
	assert_equal(refused.error, "WORLD_NO_SOIL_ON_WATER", "and names why")


func test_cleared_loam_rectangle_boundaries() -> void:
	"""GDD §5.1: "the loam rectangle x=58..65,z=46..53" is cleared before resource placement.

	UPDATED 2026-09-11 (READY_07 §7.1): the last two assertions used to ask `is_cleared_tile()`
	whether one row north/south of the rectangle is cleared. `is_cleared_tile()` now answers for
	all three of §5.1's cleared parts, and (60,54) is the workbench shelter's own footprint, so the
	RECTANGLE's boundary is asked of `is_cleared_loam_tile()` and the change of answer at (60,54)
	is asserted rather than dropped.
	"""
	assert_true(WorldInit.is_cleared_loam_tile(58, 46), "the low corner is cleared")
	assert_true(WorldInit.is_cleared_loam_tile(65, 53), "the high corner is cleared")
	assert_false(WorldInit.is_cleared_loam_tile(57, 50), "one column west is not")
	assert_false(WorldInit.is_cleared_loam_tile(66, 50), "one column east is not")
	assert_false(WorldInit.is_cleared_loam_tile(60, 45), "one row north is not")
	assert_false(WorldInit.is_cleared_loam_tile(60, 54), "one row south is not")
	assert_false(WorldInit.is_cleared_tile(60, 45), "and nothing else clears the row north")
	assert_true(WorldInit.is_cleared_tile(60, 54),
		"but the row south is GDD 5.9's workbench shelter at (58,54), so it IS cleared")


func test_cleared_rectangle_is_published_and_is_64_loam_tiles() -> void:
	"""The cleared rectangle is 8x8 and every tile of it is LOAM, so clearing frees farmland.

	UPDATED 2026-09-11: the census over EVERY published cleared tile moved to
	`test_the_published_cleared_census_is_376_tiles`, because §5.1's footprints and apron are now
	cleared too. This test keeps the rectangle's own 64 and additionally proves each is published.
	"""
	_generate()
	var cleared: int = 0
	for tile: int in WorldInit.TILE_COUNT:
		if not WorldInit.is_cleared_loam_tile(WorldInit.tile_x_of(tile), WorldInit.tile_z_of(tile)):
			continue
		cleared += 1
		assert_true(_world.is_cleared_at(tile), "rectangle tile %d is published cleared" % tile)
		assert_equal(_world.soil_at(tile).value, WorldInit.SOIL_LOAM,
			"cleared tile %d is loam" % tile)
	assert_equal(cleared, 64, "the cleared rectangle is 64 tiles")


# --- GDD §5.9's starter building footprints and §5.1's one-tile apron ---------------------------
## READY_07 §7.1: "Clear all building footprints and the GDD one-tile apron plus the authored loam
## rectangle before placing resources ... Shared aprons may overlap as cleared ground; building
## footprints may not."

func _authored_footprints() -> Array[Vector4i]:
	"""Re-transcribe §5.9's seven starter footprints here, independently of production constants.

	§5.9 places them: "the hall at (58,59), stockpiles at (50,60),(50,65),(70,60),(70,65), well at
	(64,54), and workbench at (58,54)". §5.9's building table gives the extents: hall 12x10, open
	stockpile 4x4, well 2x2, workbench shelter 3x3. Each entry is (origin_x, origin_z, size_x,
	size_z).
	"""
	var authored: Array[Vector4i] = [
		Vector4i(58, 59, 12, 10),
		Vector4i(50, 60, 4, 4),
		Vector4i(50, 65, 4, 4),
		Vector4i(70, 60, 4, 4),
		Vector4i(70, 65, 4, 4),
		Vector4i(64, 54, 2, 2),
		Vector4i(58, 54, 3, 3),
	]
	return authored


func test_the_seven_starter_footprints_are_transcribed_from_5_9() -> void:
	"""Production's roster must equal the independent transcription, position by position."""
	var authored: Array[Vector4i] = _authored_footprints()
	assert_equal(WorldInit.STARTER_FOOTPRINT_COUNT, 7, "§5.9 names seven starter buildings")
	assert_equal(authored.size(), WorldInit.STARTER_FOOTPRINT_COUNT, "the transcription has seven")
	assert_equal(WorldInit.STARTER_FOOTPRINT_KEYS.size(), 7, "one key per footprint")
	for index: int in authored.size():
		var rect: Vector4i = authored[index]
		assert_equal(WorldInit.STARTER_FOOTPRINT_ORIGIN_X[index], rect.x,
			"footprint %d origin x" % index)
		assert_equal(WorldInit.STARTER_FOOTPRINT_ORIGIN_Z[index], rect.y,
			"footprint %d origin z" % index)
		assert_equal(WorldInit.STARTER_FOOTPRINT_SIZE_X[index], rect.z, "footprint %d size x" % index)
		assert_equal(WorldInit.STARTER_FOOTPRINT_SIZE_Z[index], rect.w, "footprint %d size z" % index)
	assert_equal(WorldInit.FOOTPRINT_APRON_TILES, 1, "§5.1 authors a ONE-tile apron")


func test_the_hall_footprint_closes_against_its_authored_interior() -> void:
	"""§5.9: hall footprint 12x10, "Interior 10x8", "interior origin is exterior origin+(1,1)"."""
	assert_equal(WorldInit.HALL_INTERIOR_OFFSET, 1, "§5.9's +(1,1)")
	assert_equal(WorldInit.HALL_SIZE_X - 2 * WorldInit.HALL_INTERIOR_OFFSET, 10,
		"12 across less a tile each side is §5.9's interior width")
	assert_equal(WorldInit.HALL_SIZE_Z - 2 * WorldInit.HALL_INTERIOR_OFFSET, 8,
		"10 down less a tile each side is §5.9's interior depth")
	assert_equal(WorldInit.HALL_ORIGIN_X + WorldInit.HALL_INTERIOR_OFFSET, 59,
		"so the interior origin x is 59")
	assert_equal(WorldInit.HALL_ORIGIN_Z + WorldInit.HALL_INTERIOR_OFFSET, 60,
		"exterior origin+(1,1) on the z axis")


func test_each_authored_footprint_is_cleared_at_its_exact_tiles() -> void:
	"""Every tile of every §5.9 footprint is cleared, and the predicate's extent is exact."""
	var authored: Array[Vector4i] = _authored_footprints()
	var covered: int = 0
	for index: int in authored.size():
		var rect: Vector4i = authored[index]
		for z: int in range(rect.y, rect.y + rect.w):
			for x: int in range(rect.x, rect.x + rect.z):
				covered += 1
				assert_true(WorldInit.is_starter_footprint_tile(x, z),
					"(%d,%d) is under footprint %d" % [x, z, index])
				assert_true(WorldInit.is_cleared_tile(x, z), "(%d,%d) is cleared" % [x, z])
				assert_false(WorldInit.is_starter_apron_tile(x, z),
					"(%d,%d) is footprint, so it is not apron" % [x, z])
		_assert_footprint_stops_at_its_extent(index, rect)
	assert_equal(covered, 12 * 10 + 4 * 4 * 4 + 2 * 2 + 3 * 3, "197 authored footprint tiles")
	assert_equal(covered, 197, "which is 120 hall + 64 stockpiles + 4 well + 9 workbench")


func _assert_footprint_stops_at_its_extent(index: int, rect: Vector4i) -> void:
	"""One footprint covers origin..origin+size-1 on both axes and not one tile more."""
	assert_false(WorldInit.footprint_covers_tile(index, rect.x - 1, rect.y, 0),
		"footprint %d starts at its origin column" % index)
	assert_false(WorldInit.footprint_covers_tile(index, rect.x + rect.z, rect.y, 0),
		"footprint %d ends at origin_x+size_x-1" % index)
	assert_false(WorldInit.footprint_covers_tile(index, rect.x, rect.y - 1, 0),
		"footprint %d starts at its origin row" % index)
	assert_false(WorldInit.footprint_covers_tile(index, rect.x, rect.y + rect.w, 0),
		"footprint %d ends at origin_z+size_z-1" % index)
	assert_true(WorldInit.footprint_covers_tile(index, rect.x + rect.z - 1, rect.y + rect.w - 1, 0),
		"and its far corner is inside it")


func test_the_one_tile_apron_is_cleared_around_each_footprint() -> void:
	"""§5.1's "one-tile apron": the ring one tile out is cleared; two tiles out is not, by itself."""
	var authored: Array[Vector4i] = _authored_footprints()
	for index: int in authored.size():
		var rect: Vector4i = authored[index]
		for z: int in range(rect.y - 1, rect.y + rect.w + 1):
			for x: int in range(rect.x - 1, rect.x + rect.z + 1):
				assert_true(WorldInit.is_cleared_tile(x, z),
					"apron tile (%d,%d) of footprint %d is cleared" % [x, z, index])
				assert_true(WorldInit.footprint_covers_tile(index, x, z, 1),
					"(%d,%d) is inside footprint %d grown by one" % [x, z, index])
		assert_false(WorldInit.footprint_covers_tile(index, rect.x - 2, rect.y, 1),
			"footprint %d's apron is one tile wide, not two, to the west" % index)
		assert_false(WorldInit.footprint_covers_tile(index, rect.x + rect.z + 1, rect.y, 1),
			"nor two to the east of footprint %d" % index)
		assert_false(WorldInit.footprint_covers_tile(index, rect.x, rect.y - 2, 1),
			"nor two to the north of footprint %d" % index)
		assert_false(WorldInit.footprint_covers_tile(index, rect.x, rect.y + rect.w + 1, 1),
			"nor two to the south of footprint %d" % index)


func test_two_tiles_out_from_every_footprint_is_untouched_ground() -> void:
	"""The apron does not bleed: a tile two out from the whole roster is cleared by nothing."""
	assert_false(WorldInit.is_cleared_tile(48, 61), "two west of the (50,60) stockpile")
	assert_false(WorldInit.is_cleared_tile(75, 62), "two east of the (70,60) stockpile")
	assert_false(WorldInit.is_cleared_tile(56, 61), "two west of the hall")
	assert_false(WorldInit.is_cleared_tile(62, 71), "two south of the hall")
	assert_true(WorldInit.is_cleared_tile(49, 61), "while ONE west of the stockpile is apron")
	assert_true(WorldInit.is_cleared_tile(74, 62), "and one east of the (70,60) stockpile is too")


func test_authored_building_footprints_never_overlap() -> void:
	"""READY_07 §7.1: "building footprints may not" overlap. All 21 distinct pairs are disjoint."""
	var authored: Array[Vector4i] = _authored_footprints()
	var pairs: int = 0
	for first: int in authored.size():
		for second: int in range(first + 1, authored.size()):
			pairs += 1
			assert_false(WorldInit.starter_footprints_overlap(first, second),
				"§5.9 footprints %d and %d are disjoint" % [first, second])
	assert_equal(pairs, 21, "seven footprints make 21 distinct pairs")
	assert_true(WorldInit.starter_footprints_overlap(0, 0),
		"the predicate does detect an overlap: every footprint overlaps itself")
	assert_equal(_tiles_under_two_footprints(), 0, "and no grid tile lies under two footprints")


func _tiles_under_two_footprints() -> int:
	"""How many exterior tiles lie under more than one authored footprint. READY_07 §7.1: none."""
	var shared: int = 0
	for z: int in WorldInit.MAP_TILES_Z:
		for x: int in WorldInit.MAP_TILES_X:
			var under: int = 0
			for index: int in WorldInit.STARTER_FOOTPRINT_COUNT:
				if WorldInit.footprint_covers_tile(index, x, z, 0):
					under += 1
			if under > 1:
				shared += 1
	return shared


func test_shared_aprons_are_permitted_to_overlap() -> void:
	"""READY_07 §7.1: "Shared aprons may overlap as cleared ground". They do, and it is legal."""
	var shared: int = 0
	for z: int in WorldInit.MAP_TILES_Z:
		for x: int in WorldInit.MAP_TILES_X:
			if not WorldInit.is_starter_apron_tile(x, z):
				continue
			var aprons: int = 0
			for index: int in WorldInit.STARTER_FOOTPRINT_COUNT:
				if WorldInit.footprint_covers_tile(index, x, z, 1):
					aprons += 1
			if aprons > 1:
				shared += 1
	assert_equal(shared, 14, "fourteen apron tiles belong to two footprints at once")
	assert_true(WorldInit.is_starter_apron_tile(49, 64),
		"(49,64) is the apron of both stockpiles at x=50")
	assert_true(WorldInit.footprint_covers_tile(1, 49, 64, 1), "shared with the (50,60) stockpile")
	assert_true(WorldInit.footprint_covers_tile(2, 49, 64, 1), "and the (50,65) stockpile")
	_generate()
	assert_true(_world.is_cleared_at(WorldInit.tile_index_of(49, 64)),
		"and the overlap is cleared exactly once: the mask is a boolean, not a count")


func test_a_footprint_may_lie_inside_another_footprints_apron() -> void:
	"""An apron over a NEIGHBOUR'S footprint is cleared ground, not a forbidden overlap."""
	assert_true(WorldInit.is_starter_footprint_tile(70, 60), "(70,60) is a stockpile footprint")
	assert_true(WorldInit.footprint_covers_tile(0, 70, 60, 1), "and sits in the hall's apron")
	assert_false(WorldInit.starter_footprints_overlap(0, 3),
		"yet the hall and that stockpile share no tile")
	assert_false(WorldInit.is_starter_apron_tile(70, 60),
		"a footprint tile is never reported as apron, so the two sets never double-count")


func test_footprint_covers_tile_answers_the_empty_set_outside_the_roster() -> void:
	"""An index naming no footprint contains no tile. That is emptiness, not a failure sentinel."""
	assert_false(WorldInit.footprint_covers_tile(-1, 58, 59, 0), "index -1 names no footprint")
	assert_false(WorldInit.footprint_covers_tile(7, 58, 59, 0), "nor does one past the roster")
	assert_false(WorldInit.starter_footprints_overlap(-1, 0), "nor can it overlap one")
	assert_false(WorldInit.starter_footprints_overlap(0, 7), "in either position")
	assert_true(WorldInit.footprint_covers_tile(0, 58, 59, 0), "while a real index answers")


func test_the_published_cleared_census_is_376_tiles() -> void:
	"""376 = 197 footprint tiles + 122 apron-ring tiles + 57 loam-rectangle tiles no apron takes.

	The three parts are counted separately here, so no single production predicate can move the
	total on its own. All 376 are LOAM, which is why §5.1 clears them for a settlement at all.
	"""
	_generate()
	var footprint_tiles: int = 0
	var apron_tiles: int = 0
	var loam_only: int = 0
	var cleared: int = 0
	for tile: int in WorldInit.TILE_COUNT:
		if not _world.is_cleared_at(tile):
			continue
		var x: int = WorldInit.tile_x_of(tile)
		var z: int = WorldInit.tile_z_of(tile)
		cleared += 1
		assert_equal(_world.soil_at(tile).value, WorldInit.SOIL_LOAM, "cleared tile %d is loam" % tile)
		if WorldInit.is_starter_footprint_tile(x, z):
			footprint_tiles += 1
		elif WorldInit.is_starter_apron_tile(x, z):
			apron_tiles += 1
		else:
			loam_only += 1
	assert_equal(footprint_tiles, 197, "§5.9's seven footprints")
	assert_equal(apron_tiles, 122, "§5.1's one-tile apron ring around them")
	assert_equal(loam_only, 64 - 7, "the loam rectangle less the 7 tiles two aprons already reach")
	assert_equal(cleared, 197 + 122 + 57, "the published cleared census")
	assert_equal(cleared, 376, "which is 376 tiles")


func test_the_clearing_takes_no_tree_centre_because_its_forest_overlap_is_odd() -> void:
	"""Why the recalculated census still reads 1695: no even/even centre is cleared.

	§5.1's west forest mask ends at x=49 and the nearest footprint starts at x=50, so the ONLY
	cleared column inside a forest mask is x=49 -- odd, and a tree centre needs even x and even z.
	Asserted over the whole grid rather than argued.
	"""
	var cleared_in_forest: int = 0
	var cleared_centres: int = 0
	for z: int in WorldInit.MAP_TILES_Z:
		for x: int in WorldInit.MAP_TILES_X:
			if WorldInit.forest_basin_of(x, z) == WorldInit.NO_BASIN:
				continue
			if not WorldInit.is_starter_footprint_tile(x, z) \
					and not WorldInit.is_starter_apron_tile(x, z):
				continue
			cleared_in_forest += 1
			assert_equal(x, 49, "the only forest column the buildings clear is x=49")
			if x % 2 == 0 and z % 2 == 0:
				cleared_centres += 1
	assert_equal(cleared_in_forest, 11, "x=49, z=59..69 -- eleven forest tiles")
	assert_equal(cleared_centres, 0, "and not one of them is a tree centre")


func test_a_cleared_tile_is_never_a_tree_centre() -> void:
	"""§5.1's centre rule refuses a cleared tile even when stride and forest mask both accept it.

	The authored map never reaches this branch -- its only cleared forest column is the odd x=49 --
	so the rule is exercised directly rather than left to a geometry that cannot express it.
	"""
	assert_true(WorldInit.is_centre_candidate(8, 20, false),
		"(8,20) is even/even inside the west forest mask, so it is a centre")
	assert_false(WorldInit.is_centre_candidate(8, 20, true),
		"and the same tile is NOT a centre once the clearing stage has marked it")
	assert_true(WorldInit.is_centre_candidate(118, 104, false), "the east mask's high even corner")
	assert_false(WorldInit.is_centre_candidate(118, 104, true), "cleared, it is refused too")
	assert_false(WorldInit.is_centre_candidate(9, 20, false), "odd x is never a centre")
	assert_false(WorldInit.is_centre_candidate(8, 21, false), "nor is odd z")
	assert_false(WorldInit.is_centre_candidate(64, 64, false), "nor an even tile outside a mask")


func test_the_grove_plants_only_on_unused_uncleared_ground() -> void:
	"""§5.1: the grove skips "duplicate centers and all cleared aprons" -- one gate, both passes.

	Proved through the published world: every planted grove tile is uncleared and distinct, and
	every cleared tile of the grove rectangle carries no node at all.
	"""
	_generate()
	var seen: Dictionary = {}
	for index: int in _world.planned_grove_count():
		var tile: int = _world.planned_grove_at(index).value
		assert_false(_world.is_cleared_at(tile), "grove node %d is on uncleared ground" % index)
		assert_false(seen.has(tile), "grove tile %d is planted once, so no tile is used twice" % tile)
		seen[tile] = true
	var cleared_in_rectangle: int = 0
	for z: int in range(54, 64):
		for x: int in range(40, 50):
			var tile: int = WorldInit.tile_index_of(x, z)
			if not _world.is_cleared_at(tile):
				continue
			cleared_in_rectangle += 1
			assert_false(_nodes.has_node_at_tile(tile), "cleared grove tile (%d,%d) is bare" % [x, z])
	assert_equal(cleared_in_rectangle, 5, "five grove tiles are cleared apron")


func test_the_guaranteed_grove_is_still_exactly_100_after_the_apron_clears_five_tiles() -> void:
	"""§5.1: "until exactly 100 guaranteed nodes exist", after the clearing forces five moves."""
	_generate()
	assert_equal(_world.planned_grove_count(), 100, "the grove is still exactly 100 nodes")
	for z: int in range(59, 64):
		var tile: int = WorldInit.tile_index_of(49, z)
		assert_true(_world.is_cleared_at(tile), "(49,%d) is cleared stockpile apron" % z)
		assert_false(_nodes.has_node_at_tile(tile), "so no grove node stands on it")
	var relocated: int = 0
	for index: int in _world.planned_grove_count():
		var tile: int = _world.planned_grove_at(index).value
		var x: int = WorldInit.tile_x_of(tile)
		var z: int = WorldInit.tile_z_of(tile)
		if x < 40 or x > 49 or z < 54 or z > 63:
			relocated += 1
	assert_equal(relocated, 30, "25 duplicate centres plus the 5 apron tiles are relocated")


func test_no_resource_node_stands_inside_a_footprint_or_its_apron() -> void:
	"""READY_07 §7.1: no tree, stone or iron node may sit on cleared building ground."""
	_generate()
	var inspected: int = 0
	for index: int in _nodes.count():
		var slot: int = _nodes.live_slot_at(index).value
		var tile: int = _nodes.tile_of(slot).value
		var x: int = WorldInit.tile_x_of(tile)
		var z: int = WorldInit.tile_z_of(tile)
		inspected += 1
		assert_false(WorldInit.is_starter_footprint_tile(x, z),
			"node at (%d,%d) stands in a building footprint" % [x, z])
		assert_false(WorldInit.is_starter_apron_tile(x, z),
			"node at (%d,%d) stands in a one-tile apron" % [x, z])
		assert_false(_world.is_cleared_at(tile), "node at (%d,%d) stands on cleared ground" % [x, z])
	assert_equal(inspected, 1695, "every published node was inspected")


func test_the_well_and_workbench_ground_holds_no_node() -> void:
	"""The two smallest footprints are the ones an obsolete count would be tempted to protect."""
	_generate()
	for z: int in range(53, 57):
		for x: int in range(63, 67):
			assert_false(_nodes.has_node_at_tile(WorldInit.tile_index_of(x, z)),
				"the well at (64,54) and its apron are clear at (%d,%d)" % [x, z])
	for z: int in range(53, 58):
		for x: int in range(57, 62):
			assert_false(_nodes.has_node_at_tile(WorldInit.tile_index_of(x, z)),
				"the workbench at (58,54) and its apron are clear at (%d,%d)" % [x, z])


func test_clearing_happens_before_placement_across_a_regeneration() -> void:
	"""§5.1: clear "before placing resource nodes" -- an order, re-proved on the second world."""
	_generate()
	assert_true(_world.generate(_request()).ok, "the world regenerates")
	assert_equal(_nodes.count(), 1695, "with the same census")
	for index: int in _nodes.count():
		var slot: int = _nodes.live_slot_at(index).value
		var tile: int = _nodes.tile_of(slot).value
		assert_false(_world.is_cleared_at(tile),
			"the regenerated world still places no node on cleared tile %d" % tile)


# --- ecology basins -----------------------------------------------------------------------------

func test_forest_basins_split_at_z_62() -> void:
	"""GDD §5.1: west x=8..49 and east x=82..119, z=20..105, "split at z=62 into north/south"."""
	assert_equal(WorldInit.forest_basin_of(8, 20), WorldInit.BASIN_FOREST_WEST_NORTH,
		"the west basin's low corner is north")
	assert_equal(WorldInit.forest_basin_of(49, 61), WorldInit.BASIN_FOREST_WEST_NORTH,
		"z=61 is still north")
	assert_equal(WorldInit.forest_basin_of(49, 62), WorldInit.BASIN_FOREST_WEST_SOUTH,
		"z=62 is the first southern row")
	assert_equal(WorldInit.forest_basin_of(8, 105), WorldInit.BASIN_FOREST_WEST_SOUTH,
		"z=105 is the last southern row")
	assert_equal(WorldInit.forest_basin_of(82, 20), WorldInit.BASIN_FOREST_EAST_NORTH,
		"the east basin's low corner")
	assert_equal(WorldInit.forest_basin_of(119, 62), WorldInit.BASIN_FOREST_EAST_SOUTH,
		"the east basin splits at the same row")


func test_forest_basins_stop_at_their_stated_bounds() -> void:
	"""One tile outside each edge belongs to no forest basin."""
	assert_equal(WorldInit.forest_basin_of(7, 40), WorldInit.NO_BASIN, "west of x=8")
	assert_equal(WorldInit.forest_basin_of(50, 40), WorldInit.NO_BASIN, "east of x=49")
	assert_equal(WorldInit.forest_basin_of(81, 40), WorldInit.NO_BASIN, "west of x=82")
	assert_equal(WorldInit.forest_basin_of(120, 40), WorldInit.NO_BASIN, "east of x=119")
	assert_equal(WorldInit.forest_basin_of(20, 19), WorldInit.NO_BASIN, "north of z=20")
	assert_equal(WorldInit.forest_basin_of(20, 106), WorldInit.NO_BASIN, "south of z=105")


func test_forest_basins_exclude_water() -> void:
	"""GDD §5.1: the two rectangles are "excluding water", which is the lake inside the east one."""
	assert_equal(WorldInit.forest_basin_of(100, 66), WorldInit.NO_BASIN,
		"the lake centre is inside the east rectangle and is not forest")
	assert_equal(WorldInit.fish_basin_of(100, 66), WorldInit.BASIN_FISH_LAKE,
		"it belongs to the lake fish basin instead")
	assert_equal(WorldInit.forest_basin_of(86, 66), WorldInit.NO_BASIN, "the lake's west edge")
	assert_equal(WorldInit.forest_basin_of(85, 66), WorldInit.BASIN_FOREST_EAST_SOUTH,
		"one tile further west is forest again")


func test_generation_creates_exactly_seven_basins() -> void:
	"""Four forest partitions (decision 0026) plus decision 0037 §8B's one river, lake and coast."""
	var result: WorldInit.GenerateResult = _generate()
	assert_equal(result.basins_created, 7, "seven HarvestZone basins")
	assert_equal(_forage.zone_count(), 7, "and the store agrees")
	var forage_basins: int = 0
	var fish_basins: int = 0
	for index: int in _forage.zone_count():
		var slot: int = _forage.live_zone_slot_at(index).value
		if _forage.zone_type_of(slot).value == ForageScript.ZONE_TYPE_FORAGE:
			forage_basins += 1
		elif _forage.zone_type_of(slot).value == ForageScript.ZONE_TYPE_FISH:
			fish_basins += 1
		assert_true(_forage.basin_ref_of(slot) == _forage.zone_ref_of(slot),
			"a generated basin owns itself")
	assert_equal(forage_basins, 4, "four FORAGE basins")
	assert_equal(fish_basins, 3, "three FISH basins")


func test_every_forest_basin_carries_five_patches_at_80_percent() -> void:
	"""GDD §5.1: "forage stocks are floor(0.8xcapacity), including dormant stocks."

	MUSHROOMS and HERB are dormant in winter and ROOTS in summer (§5.5); all five are stocked here
	regardless, which is what "including dormant stocks" requires.
	"""
	_generate()
	for basin_index: int in WorldInit.FOREST_BASIN_COUNT:
		var ref: Vector2i = _world.basin_ref_of(basin_index)
		var slot: int = _forage.zone_slot_of(ref).value
		assert_equal(_forage.patch_count_of(slot).value, 5, "basin %d has five patches" % basin_index)
		for kind: int in ForageScript.PATCHES_PER_ZONE:
			var row: int = _forage.patch_row_for_zone(ref, kind).value
			var capacity: int = ForageScript.PATCH_CAPACITY_U[kind] * 1000
			assert_equal(_forage.patch_capacity_milli_of(row).value, capacity,
				"patch kind %d capacity" % kind)
			assert_equal(_forage.stock_milli_of(row).value, capacity * 8 / 10,
				"patch kind %d is stocked at floor(0.8 x capacity)" % kind)


func test_dormant_patches_are_stocked_too() -> void:
	"""The two kinds §5.5 makes dormant in winter still carry their 80% stock at generation."""
	_generate()
	var ref: Vector2i = _world.basin_ref_of(WorldInit.BASIN_FOREST_WEST_NORTH)
	assert_true(_forage.is_dormant(ForageScript.PATCH_BERRIES, ForageScript.SEASON_SPRING),
		"§5.5 makes berries dormant in spring, the season a new world starts in")
	assert_true(_forage.is_dormant(ForageScript.PATCH_NUTS, ForageScript.SEASON_SPRING),
		"and nuts too")
	assert_true(_forage.is_dormant(ForageScript.PATCH_MUSHROOMS, ForageScript.SEASON_WINTER),
		"mushrooms are dormant in winter")
	var berries_row: int = _forage.patch_row_for_zone(ref, ForageScript.PATCH_BERRIES).value
	var nuts_row: int = _forage.patch_row_for_zone(ref, ForageScript.PATCH_NUTS).value
	assert_equal(_forage.stock_milli_of(berries_row).value, 240000,
		"berries carry 240 U of their 300 U capacity despite being dormant on day 1")
	assert_equal(_forage.stock_milli_of(nuts_row).value, 192000,
		"nuts carry 192 U of their 240 U capacity, also while dormant")


func test_basin_danger_bands_come_from_the_distance_rule() -> void:
	"""GDD §5.5: danger is "the basin center's distance category", fixed at generation.

	Band 0 needs a staffed lookout and cannot occur in a new world.
	"""
	assert_equal(WorldInit.danger_band_of_half_tiles(0), 1, "the anchor itself is band 1")
	assert_equal(WorldInit.danger_band_of_half_tiles(64 * 64), 1, "64 m exactly is band 1")
	assert_equal(WorldInit.danger_band_of_half_tiles(64 * 64 + 1), 2, "just past 64 m is band 2")
	assert_equal(WorldInit.danger_band_of_half_tiles(96 * 96), 2, "96 m exactly is band 2")
	assert_equal(WorldInit.danger_band_of_half_tiles(96 * 96 + 1), 3, "past 96 m is band 3")
	_generate()
	assert_equal(_world.basin_danger_of(WorldInit.BASIN_FOREST_WEST_NORTH).value, 2,
		"the west-north forest basin is band 2")
	assert_equal(_world.basin_danger_of(WorldInit.BASIN_FISH_COAST).value, 3,
		"the coast is band 3")
	assert_equal(_world.basin_danger_of(WorldInit.BASIN_FISH_RIVER).value, 1,
		"the river runs past the settlement at band 1")


func test_every_land_tile_of_a_basin_maps_back_to_its_zone() -> void:
	"""`basin_ref_for_tile()` is R05-BASIN-003's map side: geometry still constrains binding."""
	_generate()
	var west_tile: int = WorldInit.tile_index_of(20, 30)
	assert_equal(_world.basin_ref_for_tile(west_tile),
		_world.basin_ref_of(WorldInit.BASIN_FOREST_WEST_NORTH), "a west-north tile")
	var east_tile: int = WorldInit.tile_index_of(110, 100)
	assert_equal(_world.basin_ref_for_tile(east_tile),
		_world.basin_ref_of(WorldInit.BASIN_FOREST_EAST_SOUTH), "an east-south tile")
	assert_equal(_world.basin_ref_for_tile(WorldInit.tile_index_of(64, 64)),
		EntityDirectory.NULL_REF, "a tile in no basin has no basin reference")


# --- tree centres -------------------------------------------------------------------------------

func _qualifying_centres() -> PackedInt32Array:
	"""Re-derive §5.1's tree centres from the section's own rule, independently of production."""
	var centres: PackedInt32Array = PackedInt32Array()
	for z: int in WorldInit.MAP_TILES_Z:
		for x: int in WorldInit.MAP_TILES_X:
			if x % 2 != 0 or z % 2 != 0:
				continue
			if WorldInit.is_cleared_tile(x, z):
				continue
			if WorldInit.forest_basin_of(x, z) == WorldInit.NO_BASIN:
				continue
			centres.append(z * 128 + x)
	return centres


func test_tree_centres_are_every_second_x_and_z_of_the_forest_masks() -> void:
	"""GDD §5.1: "Tree centers occupy every second x/every second z in forest masks"."""
	var expected: PackedInt32Array = _qualifying_centres()
	assert_equal(expected.size(), 1571, "the authored estuary qualifies 1571 tree centres")
	var produced: PackedInt32Array = PackedInt32Array()
	produced.resize(WorldInit.TREE_CENTER_CAP)
	var written: int = _world.collect_tree_centres_into(WorldInit.TREE_CENTER_CAP, produced)
	assert_equal(written, expected.size(), "production finds the same centres")
	assert_equal(produced.slice(0, written), expected, "and in the same ascending order")


func test_qualifying_centres_stay_under_the_3000_cap() -> void:
	"""§5.1's cap is conditional: "If more than 3000 centers qualify". This map qualifies 1571."""
	assert_true(_qualifying_centres().size() < WorldInit.TREE_CENTER_CAP,
		"the authored geometry never reaches the cap, so no centre is discarded")
	assert_equal(WorldInit.retained_centre_count(1571, 3000), 1571, "nothing is truncated")


func test_the_cap_retains_the_lowest_tile_indices() -> void:
	"""GDD §5.1: "If more than 3000 centers qualify, retain the lowest tile indices."

	Exercised at a cap of five, because the authored map never reaches three thousand.
	"""
	assert_equal(WorldInit.retained_centre_count(3001, 3000), 3000, "a surplus truncates to the cap")
	assert_equal(WorldInit.retained_centre_count(3000, 3000), 3000, "exactly the cap is kept whole")
	assert_equal(WorldInit.retained_centre_count(2999, 3000), 2999, "below the cap keeps all")
	var expected: PackedInt32Array = _qualifying_centres()
	var produced: PackedInt32Array = PackedInt32Array()
	produced.resize(5)
	var written: int = _world.collect_tree_centres_into(5, produced)
	assert_equal(written, 5, "the cap bounds what is written")
	assert_equal(produced, expected.slice(0, 5),
		"the retained five are the five LOWEST tile indices, not the highest or an arbitrary five")
	var roomy: PackedInt32Array = PackedInt32Array()
	roomy.resize(WorldInit.TREE_CENTER_CAP)
	assert_equal(_world.collect_tree_centres_into(5, roomy), 5,
		"the CAP stops the scan, not the size of the destination buffer")
	assert_equal(roomy.slice(0, 5), expected.slice(0, 5),
		"and the same lowest five are the ones kept")


func test_the_first_and_last_retained_centres_are_the_extremes() -> void:
	"""The ascending enumeration is what makes "lowest tile indices" mean the first ones."""
	var expected: PackedInt32Array = _qualifying_centres()
	assert_equal(expected[0], WorldInit.tile_index_of(8, 20),
		"the lowest centre is the west basin's low corner")
	assert_equal(expected[expected.size() - 1], WorldInit.tile_index_of(118, 104),
		"the highest centre is the east basin's high even corner")


func test_ore_footprints_sit_on_tree_centres() -> void:
	"""§5.1's "Ore footprints replace tree nodes" needs trees there; both footprints hold four."""
	var stone: int = 0
	var iron: int = 0
	for dz: int in 4:
		for dx: int in 4:
			if (44 + dx) % 2 == 0 and (70 + dz) % 2 == 0:
				stone += 1
			if (32 + dx) % 2 == 0 and (60 + dz) % 2 == 0:
				iron += 1
	assert_equal(stone, 4, "four stone-footprint tiles are tree centres")
	assert_equal(iron, 4, "four iron-footprint tiles are tree centres")
	assert_true(WorldInit.forest_basin_of(44, 70) != WorldInit.NO_BASIN,
		"the stone footprint is inside the west forest mask")
	assert_true(WorldInit.forest_basin_of(32, 60) != WorldInit.NO_BASIN,
		"the iron footprint is inside the west forest mask")


# --- the guaranteed grove -----------------------------------------------------------------------

func test_the_guaranteed_grove_is_exactly_100_nodes() -> void:
	"""GDD §5.1: "until exactly 100 guaranteed nodes exist"."""
	_generate()
	var written: int = _world.planned_grove_count()
	assert_equal(written, 100, "the grove places exactly 100 new nodes")
	var seen: Dictionary = {}
	for index: int in written:
		var tile: int = _world.planned_grove_at(index).value
		assert_false(seen.has(tile), "grove tile %d is placed once" % tile)
		seen[tile] = true
	assert_equal(seen.size(), 100, "one hundred distinct tiles")
	assert_false(_world.planned_grove_at(100).ok, "index 100 refuses; there is no 101st node")


func test_grove_skips_duplicate_centres_and_relocates_them() -> void:
	"""25 grove tiles carry a centre and 5 more fall in an apron, so 70 stay and 30 relocate.

	UPDATED 2026-09-11 (READY_07 §7.1): 75/25 before the footprint clearing. §5.1 already said the
	grove skips "all cleared aprons"; the stockpile at (50,60) puts its one-tile apron over
	(49,59..63), five grove tiles, and none of them is an even/even centre. Derived below from the
	geometry, not read back from production.
	"""
	var apron_tiles_in_grove: int = 0
	for z: int in range(54, 64):
		if WorldInit.is_starter_apron_tile(49, z):
			apron_tiles_in_grove += 1
	assert_equal(apron_tiles_in_grove, 5, "the stockpile apron reaches five grove tiles at x=49")
	assert_equal(5 * 5 + apron_tiles_in_grove, 30, "25 centres plus 5 apron tiles are skipped")
	_generate()
	var written: int = _world.planned_grove_count()
	var inside: int = 0
	for index: int in written:
		var tile: int = _world.planned_grove_at(index).value
		var x: int = WorldInit.tile_x_of(tile)
		var z: int = WorldInit.tile_z_of(tile)
		if x >= 40 and x <= 49 and z >= 54 and z <= 63:
			inside += 1
			assert_false(x % 2 == 0 and z % 2 == 0,
				"an in-grove node never doubles a centre at (%d,%d)" % [x, z])
	assert_equal(inside, 70, "70 of the 100 land inside the grove rectangle")
	assert_equal(written - inside, 30, "and 30 replace the skipped tiles")


func test_grove_replacements_are_the_lowest_unused_tiles_of_the_window() -> void:
	"""GDD §5.1: "replace any skipped center at the lowest unused land tile inside x=36..49,z=50..67".

	UPDATED 2026-09-11 (READY_07 §7.1): 25 replacements before the footprint clearing, 30 after.
	The expected 30 are derived here from the window, the centre rule and the clearing, not read
	from production: the seven odd columns of z=50, all fourteen of z=51, the seven odd columns of
	z=52, then the first two of z=53. The apron's cleared column x=49 does not reach z<=53, so it
	removes no candidate from the rows the scan actually reaches.
	"""
	var expected: PackedInt32Array = PackedInt32Array()
	for z: int in range(50, 68):
		for x: int in range(36, 50):
			if expected.size() >= 30:
				break
			if x % 2 == 0 and z % 2 == 0:
				continue
			if WorldInit.is_cleared_tile(x, z):
				continue
			expected.append(z * 128 + x)
	assert_equal(expected.size(), 30, "the derivation yields thirty replacement tiles")
	_generate()
	var produced: PackedInt32Array = PackedInt32Array()
	for index: int in range(_world.planned_grove_count() - 30, _world.planned_grove_count()):
		produced.append(_world.planned_grove_at(index).value)
	assert_equal(produced, expected,
		"the 30 replacements are the lowest unused window tiles, in ascending order")
	assert_equal(expected[0], WorldInit.tile_index_of(37, 50), "the first replacement")
	assert_equal(expected[24], WorldInit.tile_index_of(43, 52),
		"the first 25 are unchanged: the clearing lengthens the tail, it does not reorder it")
	assert_equal(expected[27], WorldInit.tile_index_of(49, 52), "z=52's odd columns run out here")
	assert_equal(expected[29], WorldInit.tile_index_of(37, 53), "the last replacement")


# --- resource nodes -----------------------------------------------------------------------------

func test_generated_node_count_is_centres_plus_grove_less_replaced_plus_ore() -> void:
	"""1571 centres + 100 grove - 8 centres under the ore footprints + 32 ore nodes.

	RECALCULATED 2026-09-11 (READY_07 §7.1), which retires the previous 1695 as a FIXTURE: the
	number below is now re-derived from the geometry on every run by `_qualifying_centres()` and
	§5.1's grove rule, with the footprint clearing applied. It recomputes to the same 1695, and the
	reason is asserted rather than assumed -- the clearing takes no even/even tree centre, because
	the only cleared column inside a forest mask is the odd x=49 (see
	`test_the_clearing_takes_no_tree_centre_because_its_forest_overlap_is_odd`), and the five grove
	tiles it does take are replaced one for one inside §5.1's window. Nothing was left standing in
	the well, the workbench or an apron to hold the total up.
	"""
	var centres: int = _qualifying_centres().size()
	assert_equal(centres, 1571, "the re-derived centre count")
	var result: WorldInit.GenerateResult = _generate()
	assert_equal(result.resource_nodes_created, centres + 100 - 8 + 32, "the node census")
	assert_equal(centres + 100 - 8 + 32, 1695, "which evaluates to 1695 after the clearing")
	assert_equal(_nodes.count(), 1695, "and the store agrees")
	assert_true(_nodes.count() <= ResourceNodesScript.RESOURCE_NODE_CAPACITY,
		"the world fits §4.2's 4096 rows")


func test_every_tree_node_holds_12_wood_u_and_regrows_in_48_days() -> void:
	"""GDD §5.1: "Each mature node contains 12 wood U"; §5.9: trees regrow after 48 days."""
	_generate()
	var trees: int = 0
	for index: int in _nodes.count():
		var slot: int = _nodes.live_slot_at(index).value
		if _nodes.resource_id_of(slot).value != _tree_item:
			continue
		trees += 1
		assert_equal(_nodes.quantity_milli_of(slot).value, 12000, "12 U in milli")
		assert_equal(_nodes.capacity_milli_of(slot).value, 12000, "a mature node starts full")
		assert_equal(_nodes.regrow_days_of(slot).value, 48, "§5.9's 48-day regrowth")
		assert_equal(_nodes.planted_day_of(slot).value, 1, "planted on day 1")
	assert_equal(trees, 1663, "1571 centres plus 100 grove less the 8 replaced by ore")


func test_the_two_deposits_are_decision_0029s_sixteen_nodes_each() -> void:
	"""Decision 0029: stone x=44..47,z=70..73 at 75000 milli each; iron x=32..35,z=60..63 at 18750."""
	_generate()
	var stone_total: int = 0
	var iron_total: int = 0
	for dz: int in 4:
		for dx: int in 4:
			var stone_slot: int = _nodes.slot_at_tile(WorldInit.tile_index_of(44 + dx, 70 + dz)).value
			assert_equal(_nodes.resource_id_of(stone_slot).value, _stone_item, "a stone node")
			assert_equal(_nodes.quantity_milli_of(stone_slot).value, 75000, "75 U per stone node")
			stone_total += _nodes.quantity_milli_of(stone_slot).value
			var iron_slot: int = _nodes.slot_at_tile(WorldInit.tile_index_of(32 + dx, 60 + dz)).value
			assert_equal(_nodes.resource_id_of(iron_slot).value, _iron_item, "an iron node")
			assert_equal(_nodes.quantity_milli_of(iron_slot).value, 18750, "18.75 U per iron node")
			iron_total += _nodes.quantity_milli_of(iron_slot).value
	assert_equal(stone_total, 1200000, "§5.1's 1200 U stone total")
	assert_equal(iron_total, 300000, "§5.1's 300 U iron total")


func test_ore_nodes_do_not_regrow_and_replaced_trees_are_gone() -> void:
	"""§5.9 states no regrow period for stone or iron; the replaced trees are destroyed, not moved."""
	_generate()
	var stone_slot: int = _nodes.slot_at_tile(WorldInit.tile_index_of(44, 70)).value
	assert_equal(_nodes.regrow_days_of(stone_slot).value, 0, "stone never regrows")
	assert_equal(_nodes.resource_id_of(stone_slot).value, _stone_item,
		"the tree centre at (44,70) was replaced by ore")
	var iron_slot: int = _nodes.slot_at_tile(WorldInit.tile_index_of(32, 60)).value
	assert_equal(_nodes.regrow_days_of(iron_slot).value, 0, "iron never regrows")
	assert_equal(_nodes.resource_id_of(iron_slot).value, _iron_item,
		"the tree centre at (32,60) was replaced by ore")


func test_no_renewable_bedrock_node_is_invented_at_48_70() -> void:
	"""§5.1 names (48,70) and gives it no quantity, period or footprint, so nothing is placed."""
	_generate()
	var tile: int = WorldInit.tile_index_of(48, 70)
	assert_true(_nodes.has_node_at_tile(tile),
		"(48,70) is an even/even forest tile, so it carries an ordinary tree centre")
	assert_equal(_nodes.resource_id_of(_nodes.slot_at_tile(tile).value).value, _tree_item,
		"a tree, not an invented renewable bedrock node with a fabricated quantity")
	assert_equal(_nodes.quantity_milli_of(_nodes.slot_at_tile(tile).value).value, 12000,
		"holding §5.1's ordinary 12 wood U")


func test_no_node_stands_on_a_cleared_tile() -> void:
	"""GDD §5.1 clears before placing: no resource node may stand on the cleared rectangle."""
	_generate()
	for index: int in _nodes.count():
		var slot: int = _nodes.live_slot_at(index).value
		var tile: int = _nodes.tile_of(slot).value
		assert_false(_world.is_cleared_at(tile), "node on tile %d is outside the clearing" % tile)


# --- fish habitats ------------------------------------------------------------------------------

func test_three_habitats_nine_stocks_with_the_ruled_capacities() -> void:
	"""Decision 0037 §8B: one river, one lake and one coast, nine FishStock rows, 2100/2200/3100 U."""
	var result: WorldInit.GenerateResult = _generate()
	assert_equal(_fishing.habitat_count(), 3, "exactly three habitats")
	assert_equal(result.fish_stocks_created, 9, "nine FishStock rows")
	var totals: PackedInt64Array = PackedInt64Array([0, 0, 0])
	for index: int in _fishing.habitat_count():
		var slot: int = _fishing.live_habitat_slot_at(index).value
		var habitat_type: int = _fishing.habitat_type_of(slot).value
		for species_index: int in FishingScript.SPECIES_PER_HABITAT:
			var row: int = slot * FishingScript.SPECIES_PER_HABITAT + species_index
			assert_true(_fishing.is_stock_present(row), "stock row %d exists" % row)
			totals[habitat_type] += _fishing.stock_capacity_milli_of(row).value
	assert_equal(totals[CatalogScript.HABITAT_TYPE["RIVER"]], 2100000, "river capacity 2100 U")
	assert_equal(totals[CatalogScript.HABITAT_TYPE["LAKE"]], 2200000, "lake capacity 2200 U")
	assert_equal(totals[CatalogScript.HABITAT_TYPE["COAST"]], 3100000, "coast capacity 3100 U")


func test_fish_stocks_start_at_80_percent() -> void:
	"""GDD §5.4: "Initial stocks are 80% of capacity", per species row, not per habitat total."""
	_generate()
	for index: int in _fishing.habitat_count():
		var slot: int = _fishing.live_habitat_slot_at(index).value
		for species_index: int in FishingScript.SPECIES_PER_HABITAT:
			var row: int = slot * FishingScript.SPECIES_PER_HABITAT + species_index
			var capacity: int = _fishing.stock_capacity_milli_of(row).value
			assert_equal(_fishing.population_milli_of(row).value, capacity * 8 / 10,
				"stock row %d starts at 80%%" % row)


func test_every_fish_stock_carries_its_own_species_item_id() -> void:
	"""READY_07 §2: each stock's item id must be the id of the species THAT STOCK HOLDS.

	The stock's §5.4 species row comes from `fishing.gd`'s own HABITAT_SPECIES_ROWS binding, and
	the expected id is that row's key compiled through the catalog. Before the binding landed the
	request array was passed straight into a habitat-major argument, which gave the coast the
	river's three ids and the river the coast's; the lake coincides under both orders, so a test
	that checked only one habitat would have passed straight over it.
	"""
	_generate()
	for index: int in _fishing.habitat_count():
		var slot: int = _fishing.live_habitat_slot_at(index).value
		var habitat_type: int = _fishing.habitat_type_of(slot).value
		for species_index: int in FishingScript.SPECIES_PER_HABITAT:
			var row: int = slot * FishingScript.SPECIES_PER_HABITAT + species_index
			var species: int = FishingScript.HABITAT_SPECIES_ROWS[
				habitat_type * FishingScript.SPECIES_PER_HABITAT + species_index]
			var key: StringName = FishingScript.SPECIES_KEYS[species]
			assert_equal(_fishing.species_id_of(row).value, _items.compiled_id(key),
				"stock row %d holds '%s'" % [row, key])


func test_the_coast_and_river_stocks_are_not_each_others_species() -> void:
	"""The exact misassignment the habitat-major re-addressing exists to prevent."""
	_generate()
	var coast: int = _fishing.habitat_ref_for_basin(
		_world.basin_ref_of(WorldInit.BASIN_FISH_COAST)).value
	var river: int = _fishing.habitat_ref_for_basin(
		_world.basin_ref_of(WorldInit.BASIN_FISH_RIVER)).value
	var coast_row: int = coast * FishingScript.SPECIES_PER_HABITAT
	var river_row: int = river * FishingScript.SPECIES_PER_HABITAT
	assert_equal(_fishing.species_id_of(coast_row).value, _items.compiled_id(&"herring"),
		"the coast's first stock is herring, not trout")
	assert_equal(_fishing.species_id_of(river_row).value, _items.compiled_id(&"trout"),
		"the river's first stock is trout, not herring")
	assert_false(_fishing.species_id_of(coast_row).value
		== _fishing.species_id_of(river_row).value, "and the two are different items")


func test_every_forage_patch_carries_its_own_kind_item_id() -> void:
	"""The five patch rows are addressed by patch kind, which IS `PATCH_KEYS` order."""
	_generate()
	for zone_index: int in _forage.zone_count():
		var slot: int = _forage.live_zone_slot_at(zone_index).value
		if _forage.zone_type_of(slot).value != ForageScript.ZONE_TYPE_FORAGE:
			continue
		for kind: int in ForageScript.PATCHES_PER_ZONE:
			var row: int = slot * ForageScript.PATCHES_PER_ZONE + kind
			var key: StringName = ForageScript.PATCH_KEYS[kind]
			assert_equal(_forage.patch_item_id_of(row).value, _items.compiled_id(key),
				"patch row %d holds '%s'" % [row, key])


func test_each_habitat_is_bound_to_its_own_fish_basin() -> void:
	"""Decision 0037: a designation resolves designation -> basin -> the unique habitat on it."""
	_generate()
	for basin_index: int in range(WorldInit.BASIN_FISH_COAST, WorldInit.BASIN_COUNT):
		var basin_ref: Vector2i = _world.basin_ref_of(basin_index)
		var found: FishingScript.OpResult = _fishing.habitat_ref_for_basin(basin_ref)
		assert_true(found.ok, "basin %d owns exactly one habitat" % basin_index)
		assert_equal(_fishing.habitat_type_of(found.value).value,
			basin_index - WorldInit.BASIN_FISH_COAST, "the habitat type matches its basin")


# --- reserved fauna -----------------------------------------------------------------------------

func test_fauna_stock_reserved_is_allocated_and_canonically_empty() -> void:
	"""REQ-SET-059 and GDD §4.2: "Reserved allocation only: all numeric fields 0, refs (-1,0)"."""
	assert_equal(_world.fauna_row_capacity(), 384,
		"systems_architecture.md §2.2 sizes the reserved allocation at 384 rows")
	assert_equal(_world.fauna_reserved_bytes(), 384 * (8 * 4 + 8), "12288 I32 plus 3072 I64 bytes")
	assert_true(_world.fauna_is_canonically_empty(), "every reserved row is empty before generation")
	assert_equal(_world.fauna_zone_ref_of(0), EntityDirectory.NULL_REF, "row 0 holds (-1,0)")
	assert_equal(_world.fauna_zone_ref_of(383), EntityDirectory.NULL_REF, "so does the last row")
	_generate()
	assert_true(_world.fauna_is_canonically_empty(),
		"generation creates no herd proxy and writes no reserved fauna field")


func test_generation_creates_live_rows_of_only_three_kinds() -> void:
	"""No directory entry may reference a live reserved fauna row, and none of any other kind."""
	_generate()
	for kind: int in EntityDirectory.KIND_COUNT:
		var expected: bool = kind == EntityDirectory.KIND_RESOURCE_NODE \
			or kind == EntityDirectory.KIND_HARVEST_ZONE \
			or kind == EntityDirectory.KIND_FISH_HABITAT
		if expected:
			assert_true(_directory.live_count(kind) > 0, "kind %d is populated" % kind)
		else:
			assert_equal(_directory.live_count(kind), 0, "kind %d stays empty" % kind)


func test_generation_creates_no_farm_plot_orchard_or_hive() -> void:
	"""§5.1's initial conditions author no FarmPlot, OrchardPlot or Hive; none is invented here."""
	var farming: FarmingScript = FarmingScript.new(_directory)
	var orchards: OrchardHiveScript = OrchardHiveScript.new(_directory)
	var world: WorldInit = WorldInit.new(_directory, _nodes, _forage, _fishing, _rng,
		farming, orchards, _jobs)
	assert_true(world.generate(_request()).ok, "generation succeeds with both stores bound")
	assert_equal(_directory.live_count(EntityDirectory.KIND_FARM_PLOT), 0, "no farm plot")
	assert_equal(_directory.live_count(EntityDirectory.KIND_ORCHARD_PLOT), 0, "no orchard block")
	assert_equal(_directory.live_count(EntityDirectory.KIND_HIVE), 0, "no apiary")


# --- seeding ------------------------------------------------------------------------------------

func test_generation_seeds_the_world_rng() -> void:
	"""GDD §5.1's fixed-seed tutorial uses 20260905, and seeding is world generation's job."""
	assert_false(_rng.is_seeded(), "a freshly composed RNG is unseeded")
	var result: WorldInit.GenerateResult = _generate()
	assert_true(_rng.is_seeded(), "generation seeds every stream")
	assert_equal(result.accepted_seed, 20260905, "the authored tutorial seed")
	assert_equal(_rng.world_seed_value().value, 20260905, "and the RNG records it")
	assert_equal(_world.published_seed().value, 20260905, "as does the published world")
	assert_equal(result.attempts, 1, "the authored geometry needs one attempt")


func test_a_seeded_world_draws_where_an_unseeded_one_refuses() -> void:
	"""The concrete symptom task 03 hit: an unseeded stream refuses RNG_NOT_SEEDED."""
	var unseeded: IntMath.IntResult = _rng.draw(RngScript.STREAM_WEATHER)
	assert_false(unseeded.ok, "an unseeded weather stream refuses")
	assert_equal(unseeded.error, "RNG_NOT_SEEDED", "with the exact code")
	_generate()
	var seeded: IntMath.IntResult = _rng.draw(RngScript.STREAM_WEATHER)
	assert_true(seeded.ok, "after generation the weather stream draws")
	assert_true(_rng.draw(RngScript.STREAM_ECOLOGY).ok, "so does ecology")
	assert_true(_rng.draw(RngScript.STREAM_QUALITY).ok, "and quality")


func test_an_invalid_seed_is_regenerated_with_seed_plus_one() -> void:
	"""GDD §5.1: "Invalid seeds are rejected and regenerated with seed+1"."""
	var request: WorldInit.Request = _request()
	request.world_seed = -2147483649
	var result: WorldInit.GenerateResult = _world.generate(request)
	assert_true(result.ok, "the second attempt succeeds")
	assert_equal(result.attempts, 2, "after exactly one rejection")
	assert_equal(result.accepted_seed, -2147483648, "the accepted seed is the rejected one plus 1")
	assert_equal(_rng.world_seed_value().value, -2147483648, "and the RNG uses it")


func test_sixteen_attempts_bound_the_retry_and_return_the_failing_code() -> void:
	"""GDD §5.1: "rejects generation after at most 16 seed attempts and returns the explicit failed
	assertion"."""
	var request: WorldInit.Request = _request()
	request.world_seed = 2147483648
	var result: WorldInit.GenerateResult = _world.generate(request)
	assert_false(result.ok, "sixteen invalid seeds in a row refuse")
	assert_equal(result.attempts, 16, "and stop at sixteen attempts")
	assert_equal(result.error, "WORLD_SEED_NOT_INT32", "reporting the exact failure")
	assert_false(_rng.is_seeded(), "no stream was seeded")
	assert_false(_world.is_published(), "no world was published")


func test_the_sixteenth_attempt_returns_without_a_seventeenth_advance() -> void:
	"""§5.1 bounds the retry at sixteen ATTEMPTS, so the sixteenth must not advance the seed again.

	Started fifteen below the int64 ceiling, the sixteenth attempt sits exactly on it: advancing
	once more would overflow. §5.1's contract is that the sixteenth attempt "returns the explicit
	failed assertion", which is the seed refusal -- not the overflow of an advance it never needs.
	"""
	var request: WorldInit.Request = _request()
	request.world_seed = 9223372036854775807 - 15
	var result: WorldInit.GenerateResult = _world.generate(request)
	assert_false(result.ok, "sixteen unusable seeds refuse")
	assert_equal(result.attempts, 16, "after the full sixteen attempts")
	assert_equal(result.error, "WORLD_SEED_NOT_INT32",
		"reporting the SEED failure, not the overflow of an advance it never needed to make")
	assert_false(_world.is_published(), "and nothing is published")


func test_an_advance_overflow_inside_the_retry_is_its_own_refusal() -> void:
	"""An advance that cannot be made refuses explicitly instead of wrapping the seed."""
	var request: WorldInit.Request = _request()
	request.world_seed = 9223372036854775807 - 3
	var result: WorldInit.GenerateResult = _world.generate(request)
	assert_false(result.ok, "four seeds from the int64 ceiling still refuses")
	assert_equal(result.error, "WORLD_SEED_ADVANCE_OVERFLOW",
		"and names the advance, because seed+1 has nowhere left to go")
	assert_equal(result.attempts, 4, "on the attempt whose successor does not exist")


func test_a_short_grove_refuses_before_anything_is_cleared() -> void:
	"""§5.1 requires "exactly 100 guaranteed nodes"; a plan that cannot reach it refuses.

	The authored geometry always reaches 100, so the guard is reached here through a subclass that
	changes exactly one behaviour -- the same device `test_command_dispatch.gd`'s RefusingTileForage
	and `test_forage.gd`'s CorruptibleForage use.
	"""
	var short: ShortGroveWorld = ShortGroveWorld.new(_directory, _nodes, _forage, _fishing, _rng,
		null, null, _jobs)
	var refused: WorldInit.GenerateResult = short.generate(_request())
	assert_false(refused.ok, "a 99-node grove refuses")
	assert_equal(refused.error, "WORLD_GROVE_INCOMPLETE", "naming the exact shortfall")
	assert_false(short.is_published(), "and no world is published")
	assert_equal(_nodes.count(), 0, "not one resource node was created")
	assert_equal(_forage.zone_count(), 0, "and not one basin")


# --- §5.1's generator guarantees ----------------------------------------------------------------

func test_every_stated_guarantee_holds_on_the_generated_world() -> void:
	"""GDD §5.1's generator guarantee list, measured in a straight line from the anchor."""
	_generate()
	assert_true(_world.is_published(), "the world published, so every guarantee passed")
	var nearest_river: int = WorldInit.anchor_distance_sq(76, 64)
	assert_true(nearest_river <= WorldInit.metres_sq_units(24), "a river edge within 24 m")
	assert_true(WorldInit.anchor_distance_sq(49, 64) <= WorldInit.metres_sq_units(32),
		"a forest zone within 32 m")
	assert_true(WorldInit.anchor_distance_sq(47, 70) <= WorldInit.metres_sq_units(48),
		"the stone deposit within 48 m")
	assert_true(WorldInit.anchor_distance_sq(35, 63) <= WorldInit.metres_sq_units(80),
		"the iron deposit within 80 m")


func test_validate_measurements_accepts_a_satisfying_world() -> void:
	"""The pure validator returns no refusal when every guarantee is met."""
	assert_equal(WorldInit.validate_measurements(_passing_measurements()), &"",
		"a satisfying measurement set passes")


func _passing_measurements() -> WorldInit.Measurements:
	"""A measurement set that satisfies every §5.1 guarantee with room to spare."""
	var measured: WorldInit.Measurements = WorldInit.Measurements.new()
	measured.river_edge_distance_sq = 0
	measured.forest_zone_distance_sq = 0
	measured.loam_tiles_in_range = 64
	measured.wood_milli_in_range = 1200000
	measured.stone_milli_in_range = 1200000
	measured.renewable_tree_nodes = 1
	measured.iron_distance_sq = 0
	measured.grove_nodes = 100
	return measured


func test_each_guarantee_reports_its_own_assertion() -> void:
	"""Every §5.1 guarantee fails under its own explicit name -- never a generic refusal."""
	var spoiled: WorldInit.Measurements = _passing_measurements()
	spoiled.river_edge_distance_sq = WorldInit.metres_sq_units(24) + 1
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_RIVER_EDGE_WITHIN_24M",
		"one metre past the river guarantee")
	spoiled = _passing_measurements()
	spoiled.forest_zone_distance_sq = WorldInit.metres_sq_units(32) + 1
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_FOREST_ZONE_WITHIN_32M",
		"past the forest guarantee")
	spoiled = _passing_measurements()
	spoiled.loam_tiles_in_range = 63
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_64_LOAM_TILES_WITHIN_24M",
		"63 loam tiles is one short")
	spoiled = _passing_measurements()
	spoiled.wood_milli_in_range = 1199999
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_1200U_WOOD_WITHIN_48M",
		"one milli short of 1200 U of wood")


func test_the_remaining_guarantees_report_their_own_assertion() -> void:
	"""The second half of the guarantee list, each under its own name."""
	var spoiled: WorldInit.Measurements = _passing_measurements()
	spoiled.stone_milli_in_range = 1199999
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_1200U_STONE_WITHIN_48M",
		"one milli short of 1200 U of stone")
	spoiled = _passing_measurements()
	spoiled.renewable_tree_nodes = 0
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_RENEWABLE_SAPLINGS",
		"no renewable tree node")
	spoiled = _passing_measurements()
	spoiled.iron_distance_sq = WorldInit.metres_sq_units(80) + 1
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_IRON_DEPOSIT_WITHIN_80M",
		"past the iron guarantee")
	spoiled = _passing_measurements()
	spoiled.grove_nodes = 99
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_GUARANTEED_GROVE_IS_100",
		"99 grove nodes is not exactly 100")


func test_a_missing_feature_is_never_within_range() -> void:
	"""A negative distance means "none of that kind exists" and can never satisfy a guarantee."""
	var spoiled: WorldInit.Measurements = _passing_measurements()
	spoiled.river_edge_distance_sq = -1
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_RIVER_EDGE_WITHIN_24M",
		"no river at all fails the river guarantee")
	spoiled = _passing_measurements()
	spoiled.iron_distance_sq = -1
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_IRON_DEPOSIT_WITHIN_80M",
		"no iron at all fails the iron guarantee")


func test_guarantees_are_reported_in_the_sections_own_order() -> void:
	"""When several guarantees fail at once, the first one §5.1 lists is the one reported."""
	var spoiled: WorldInit.Measurements = WorldInit.Measurements.new()
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_RIVER_EDGE_WITHIN_24M",
		"an empty world reports the river guarantee first")
	spoiled = _passing_measurements()
	spoiled.forest_zone_distance_sq = -1
	spoiled.loam_tiles_in_range = 0
	assert_equal(WorldInit.validate_measurements(spoiled), &"ASSERT_FOREST_ZONE_WITHIN_32M",
		"forest is listed before loam")


func test_boundary_distances_are_inclusive() -> void:
	""""within 24 m" includes exactly 24 m, which the river guarantee needs at equality."""
	var edge: WorldInit.Measurements = _passing_measurements()
	edge.river_edge_distance_sq = WorldInit.metres_sq_units(24)
	edge.forest_zone_distance_sq = WorldInit.metres_sq_units(32)
	edge.iron_distance_sq = WorldInit.metres_sq_units(80)
	assert_equal(WorldInit.validate_measurements(edge), &"",
		"every threshold is satisfied at equality")


# --- prepare/validate/publish as a transaction --------------------------------------------------

func _world_fingerprint() -> String:
	"""A digest of everything a published world owns, INCLUDING its entity references.

	Hashed rather than compared as a 64 KB array so a failure prints one line instead of the map.
	"""
	return Marshalls.raw_to_base64(_world_image(true)).sha256_text()


func _content_fingerprint() -> String:
	"""The same digest WITHOUT directory generations.

	`EntityDirectory.clear()` deliberately never resets a generation (ARCH-ID-002), so a world
	regenerated into a USED directory holds the same content under newer references. This digest is
	what "the same world" means in that case; `_world_fingerprint()` is what byte-identity means.
	"""
	return Marshalls.raw_to_base64(_world_image(false)).sha256_text()


func _world_image(with_references: bool) -> PackedByteArray:
	"""A byte image of everything a published world owns, for a before/after comparison."""
	var image: PackedByteArray = PackedByteArray()
	for tile: int in WorldInit.TILE_COUNT:
		image.append(_world.terrain_at(tile).value)
		image.append(_world.basin_index_at(tile).value)
		image.append(1 if _world.is_cleared_at(tile) else 0)
	for index: int in _nodes.count():
		var slot: int = _nodes.live_slot_at(index).value
		image.append_array(var_to_bytes([_nodes.tile_of(slot).value,
			_nodes.resource_id_of(slot).value, _nodes.quantity_milli_of(slot).value,
			_nodes.regrow_days_of(slot).value]))
	for index: int in _forage.zone_count():
		var slot: int = _forage.live_zone_slot_at(index).value
		image.append_array(var_to_bytes([_forage.zone_type_of(slot).value,
			_forage.zone_danger_of(slot).value, _forage.patch_count_of(slot).value]))
		if with_references:
			image.append_array(var_to_bytes([_forage.zone_ref_of(slot),
				_forage.basin_ref_of(slot)]))
	for row: int in ForageScript.FORAGE_PATCH_CAPACITY:
		if _forage.is_patch_present(row):
			image.append_array(var_to_bytes([row, _forage.stock_milli_of(row).value]))
	return image


func test_a_refused_generation_leaves_the_previous_world_byte_identical() -> void:
	"""Task 04.3: "Failed initialization retains the previous valid world and reports the exact
	failed assertion"."""
	_generate()
	var before: String = _world_fingerprint()
	var seed_before: int = _world.published_seed().value
	var bad: WorldInit.Request = _request()
	bad.scenario_version = 99
	var refused: WorldInit.GenerateResult = _world.generate(bad)
	assert_false(refused.ok, "an unknown scenario refuses")
	assert_equal(refused.error, "WORLD_UNKNOWN_SCENARIO_VERSION", "and names the exact failure")
	assert_true(_world.is_published(), "the previous world is still published")
	assert_equal(_world.published_seed().value, seed_before, "under its original seed")
	assert_equal(_world_fingerprint(), before, "and byte for byte unchanged")


func test_an_invalid_item_id_refuses_before_anything_is_cleared() -> void:
	"""A bad catalog id is caught in prepare, so no store is touched and no row is destroyed."""
	_generate()
	var before: String = _world_fingerprint()
	var node_count: int = _nodes.count()
	var bad: WorldInit.Request = _request()
	bad.forage_item_ids = PackedInt32Array([10, 11, -1, 13, 14])
	var refused: WorldInit.GenerateResult = _world.generate(bad)
	assert_false(refused.ok, "a negative item id refuses")
	assert_equal(refused.error, "WORLD_INVALID_ITEM_ID", "with the exact code")
	assert_equal(_nodes.count(), node_count, "not one node was destroyed")
	assert_equal(_world_fingerprint(), before, "the world is byte-identical")


func test_an_unbound_request_refuses_before_anything_is_cleared() -> void:
	"""READY_07 §2: a request whose ids were never resolved against the catalog cannot be proved."""
	_generate()
	var before: String = _world_fingerprint()
	var node_count: int = _nodes.count()
	var unbound: WorldInit.Request = _request()
	unbound.binding = null
	var refused: WorldInit.GenerateResult = _world.generate(unbound)
	assert_false(refused.ok, "an unbound request refuses")
	assert_equal(refused.error, "WORLD_UNBOUND_ITEM_CATALOG", "with the exact code")
	assert_equal(_nodes.count(), node_count, "not one node was destroyed")
	assert_equal(_world_fingerprint(), before, "and the world is byte-identical")


func test_a_valid_but_wrong_item_id_refuses_and_leaves_every_store_byte_identical() -> void:
	"""tree -> stone: both ids are real catalog ids, so only a key check can catch it.

	This is the case the old "non-negative int32" guard let straight through, and it is proved
	against the STORES, not just the return code: allocate-before-consume means the refusal is
	decided before a row is cleared.
	"""
	_generate()
	var before: String = _world_fingerprint()
	var node_count: int = _nodes.count()
	var zone_count: int = _forage.zone_count()
	var habitat_count: int = _fishing.habitat_count()
	var wrong: WorldInit.Request = _request()
	wrong.tree_resource_id = wrong.stone_resource_id
	var refused: WorldInit.GenerateResult = _world.generate(wrong)
	assert_false(refused.ok, "the wrong key refuses")
	assert_equal(refused.error, "ITEM_BINDING_ID_NOT_BOUND", "with the binding's own code")
	assert_equal(_nodes.count(), node_count, "not one resource node changed")
	assert_equal(_forage.zone_count(), zone_count, "not one harvest zone changed")
	assert_equal(_fishing.habitat_count(), habitat_count, "not one fish habitat changed")
	assert_equal(_world_fingerprint(), before, "and the world is byte-identical")


func test_a_sorted_forage_array_refuses_and_leaves_every_store_byte_identical() -> void:
	"""Sorting the patch ids by compiled id would misassign every quota; it never reaches a store."""
	_generate()
	var before: String = _world_fingerprint()
	var node_count: int = _nodes.count()
	var sorted_request: WorldInit.Request = _request()
	var sorted_ids: PackedInt32Array = sorted_request.forage_item_ids.duplicate()
	sorted_ids.sort()
	assert_false(sorted_ids == sorted_request.forage_item_ids, "sorting really reorders them")
	sorted_request.forage_item_ids = sorted_ids
	var refused: WorldInit.GenerateResult = _world.generate(sorted_request)
	assert_false(refused.ok, "the sorted patch ids refuse")
	assert_equal(refused.error, "ITEM_BINDING_ID_NOT_BOUND", "with the binding's own code")
	assert_equal(_nodes.count(), node_count, "not one node was destroyed")
	assert_equal(_world_fingerprint(), before, "and the world is byte-identical")


func test_a_bound_request_carries_the_seventeen_compiled_ids_the_catalog_reports() -> void:
	"""The checked construction boundary: every field is resolved by key, none is chosen here."""
	var built: WorldInit.RequestResult = WorldInit.make_request(_binding)
	assert_true(built.ok, "the request builds (error: %s)" % built.error)
	var request: WorldInit.Request = built.request
	assert_equal(request.scenario_version, WorldInit.SCENARIO_ESTUARY_V1, "the estuary scenario")
	assert_equal(request.tree_resource_id, _items.compiled_id(&"wood"), "wood")
	assert_equal(request.stone_resource_id, _items.compiled_id(&"stone"), "stone")
	assert_equal(request.iron_resource_id, _items.compiled_id(&"iron"), "iron")
	assert_equal(request.forage_item_ids.size(), 5, "five patch rows")
	assert_equal(request.fish_species_item_ids.size(), 9, "nine species rows")
	for index: int in ForageScript.PATCH_KEYS.size():
		assert_equal(request.forage_item_ids[index],
			_items.compiled_id(ForageScript.PATCH_KEYS[index]), "patch row %d" % index)
	for index: int in FishingScript.SPECIES_KEYS.size():
		assert_equal(request.fish_species_item_ids[index],
			_items.compiled_id(FishingScript.SPECIES_KEYS[index]), "species row %d" % index)


func test_a_caller_that_knows_only_the_catalog_can_build_the_request() -> void:
	"""`bound_request()` names no item key and no numeric id, and generates a real world."""
	var built: WorldInit.RequestResult = WorldInit.bound_request(_items)
	assert_true(built.ok, "the request binds from the registry alone (error: %s)" % built.error)
	assert_equal(built.request.world_seed, WorldInit.TUTORIAL_WORLD_SEED, "§5.1's tutorial seed")
	assert_true(_world.generate(built.request).ok, "and the world generates from it")
	assert_true(_world.is_published(), "publishing a real estuary")


func test_a_stale_catalog_artifact_refuses_the_request_and_generates_nothing() -> void:
	"""`bound_request()` opens the boundary, so a stale artifact stops it before a Request exists.

	The fixture moves one recorded id, which is exactly the "the committed catalog no longer
	describes this build" case. Nothing is generated and no store is touched.
	"""
	var text: String = FileAccess.get_file_as_string(CatalogIdsScript.ARTIFACT_PATH)
	var entry: String = '"wood":%d' % _items.compiled_id(&"wood")
	assert_true(text.contains(entry), "the artifact records wood's id")
	var path: String = "user://world_init_stale_artifact.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "the fixture file opens for writing")
	file.store_string(text.replace(entry, '"wood":%d' % (_items.compiled_id(&"wood") - 1)))
	file.close()
	var built: WorldInit.RequestResult = WorldInit.bound_request(
		_items, WorldInit.TUTORIAL_WORLD_SEED, path)
	assert_false(built.ok, "the stale catalog refuses")
	assert_equal(built.error, "ITEM_BINDING_CATALOG_ARTIFACT", "with the binding's artifact code")
	assert_null(built.request, "and no request is produced")
	assert_false(_world.is_published(), "so no world was ever generated")


func test_bound_request_refuses_an_unloaded_registry() -> void:
	"""The other half of the open path: no catalog means no request, and no default ids."""
	var built: WorldInit.RequestResult = WorldInit.bound_request(ItemDefinitionsScript.new())
	assert_false(built.ok, "an unloaded registry refuses")
	assert_equal(built.error, "ITEM_BINDING_REGISTRY_NOT_LOADED", "with the binding's own code")
	assert_null(built.request, "and no request is produced")


func test_building_a_request_without_a_binding_refuses() -> void:
	"""There is no default binding and no fallback id to fall back on."""
	var built: WorldInit.RequestResult = WorldInit.make_request(null)
	assert_false(built.ok, "no boundary means no request")
	assert_equal(built.error, "WORLD_UNBOUND_ITEM_CATALOG", "with the exact code")
	assert_null(built.request, "and no half-bound request is produced")


func test_a_wrong_sized_item_set_refuses() -> void:
	"""Five forage kinds and nine fish species: a short set refuses rather than being padded."""
	var short_forage: WorldInit.Request = _request()
	short_forage.forage_item_ids = PackedInt32Array([10, 11, 12, 13])
	assert_equal(_world.generate(short_forage).error, "WORLD_ITEM_SET_SIZE", "four forage ids")
	var short_fish: WorldInit.Request = _request()
	short_fish.fish_species_item_ids = PackedInt32Array([20, 21, 22])
	assert_equal(_world.generate(short_fish).error, "WORLD_ITEM_SET_SIZE", "three species ids")
	assert_false(_world.is_published(), "neither refusal published a world")


func test_a_foreign_live_row_refuses_rather_than_being_orphaned() -> void:
	"""`generate()`'s reset clears the DIRECTORY, so a row owned by a store this generator was not
	given would lose its identity. It refuses instead, naming the kind.

	The composed initializer is the reason this is a refusal rather than a licence: R-INIT-ID-001
	has it allocate twelve residents before publication, and publication must not be able to take
	them away. The check runs in `preflight()`, before the reset it protects."""
	var stray: Vector2i = _directory.create(EntityDirectory.KIND_RESIDENT)
	assert_true(_directory.is_valid(stray), "a resident row exists")
	var refused: WorldInit.GenerateResult = _world.generate(_request())
	assert_false(refused.ok, "generation refuses")
	assert_equal(refused.error, "WORLD_FOREIGN_LIVE_ROWS", "with the exact code")
	assert_equal(_world.foreign_kind(), EntityDirectory.KIND_RESIDENT, "naming the blocking kind")
	assert_true(_directory.is_valid(stray), "and the resident row survives untouched")


func test_a_store_on_another_directory_refuses() -> void:
	"""Every reference crossing a store boundary is validated in one directory, so they must agree."""
	var other: EntityDirectory = EntityDirectory.new()
	var foreign_nodes: ResourceNodesScript = ResourceNodesScript.new(other)
	var world: WorldInit = WorldInit.new(_directory, foreign_nodes, _forage, _fishing, _rng,
		null, null, _jobs)
	var refused: WorldInit.GenerateResult = world.generate(_request())
	assert_false(refused.ok, "a mismatched directory refuses")
	assert_equal(refused.error, "WORLD_STORE_DIRECTORY_MISMATCH", "with the exact code")


func test_a_missing_store_refuses() -> void:
	"""A null required collaborator is an explicit refusal, never a partially generated world."""
	var world: WorldInit = WorldInit.new(_directory, _nodes, _forage, _fishing, null,
		null, null, _jobs)
	var refused: WorldInit.GenerateResult = world.generate(_request())
	assert_false(refused.ok, "a missing RNG refuses")
	assert_equal(refused.error, "WORLD_MISSING_STORE", "with the exact code")
	assert_false(world.is_published(), "and nothing is published")


func test_readers_refuse_before_the_first_world_is_published() -> void:
	"""No sentinel stands in for "there is no world yet"."""
	assert_false(_world.is_published(), "nothing published yet")
	assert_false(_world.published_seed().ok, "the seed reader refuses")
	assert_equal(_world.terrain_at(0).error, "WORLD_NOT_PUBLISHED", "so does terrain")
	assert_equal(_world.basin_danger_of(0).error, "WORLD_NOT_PUBLISHED", "so does danger")
	assert_equal(_world.basin_ref_of(0), EntityDirectory.NULL_REF, "and the basin ref is null")
	assert_false(_world.is_fishing_work_tile(0), "no tile is fishable")


func test_an_off_grid_tile_refuses_on_a_published_world() -> void:
	"""The published readers validate their tile argument rather than indexing past the column."""
	_generate()
	assert_equal(_world.terrain_at(16384).error, "INVALID_TILE", "one past the last tile")
	assert_equal(_world.basin_index_at(-1).error, "INVALID_TILE", "before the first tile")
	assert_false(_world.is_cleared_at(16384), "and the boolean readers answer false")


func test_regeneration_reproduces_the_same_world() -> void:
	"""Two worlds from the same scenario, seed and catalog agree on every generated field."""
	_generate()
	var first: String = _content_fingerprint()
	assert_true(_world.generate(_request()).ok, "the world regenerates")
	assert_equal(_content_fingerprint(), first, "and holds identical content")
	assert_equal(_nodes.count(), 1695, "with the same node census")
	assert_true(_forage.zone_ref_of(0).y > 1,
		"its references carry NEWER generations: ARCH-ID-002 never resets one")


func test_two_independent_worlds_agree() -> void:
	"""An independently composed store set generates the same world from the same request."""
	_generate()
	var first: String = _world_fingerprint()
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	var directory: EntityDirectory = _jobs.directory()
	_nodes = ResourceNodesScript.new(directory)
	_forage = ForageScript.new(directory, _jobs)
	_fishing = FishingScript.new(directory, _forage, _jobs)
	_rng = RngScript.new()
	_world = WorldInit.new(directory, _nodes, _forage, _fishing, _rng, null, null, _jobs)
	assert_true(_world.generate(_request()).ok, "the second world generates")
	assert_equal(_world_fingerprint(), first, "and matches the first byte for byte")


func test_publishing_resets_job_and_command_state() -> void:
	"""Task 04.3: reset "job and command state before exposing an active world"."""
	var clock: SimClockScript = SimClockScript.new()
	var commands: CommandsScript = CommandsScript.new(clock, _directory)
	var world: WorldInit = WorldInit.new(_directory, _nodes, _forage, _fishing, _rng,
		null, null, _jobs, commands)
	var created: JobsScript.OpResult = _jobs.create_job(CatalogScript.JOB_KIND["HAUL"], 3, 0,
		1000, 0)
	assert_true(created.ok, "a job exists before generation")
	assert_equal(_jobs.job_count(), 1, "the job store is populated")
	assert_true(world.generate(_request()).ok, "generation succeeds")
	assert_equal(_jobs.job_count(), 0, "the job store is reset")
	assert_equal(commands.pending_count(), 0, "so is the command queue")
	assert_equal(_directory.live_count(EntityDirectory.KIND_JOB), 0, "and its directory rows")


func test_map_payload_is_the_declared_size() -> void:
	"""The ARCH-MEM-009 ledger row: nine tile byte columns, four basin I32 columns, the tree plan."""
	assert_equal(_world.map_payload_bytes(), 9 * 16384 + 4 * 7 * 4 + 3100 * 4,
		"159968 bytes of world-map storage")
	assert_equal(_world.map_payload_bytes(), 159968, "stated as one number")


# --- the whole point: a designation can now designate real forest -------------------------------

func test_designate_zone_designates_real_forest_after_generation() -> void:
	"""Task 03's premise -- "There is nothing in the world for a FARM, FORAGE or FISH job to
	reference" -- closed for FORAGE: a DESIGNATE_ZONE command targeting a generated basin commits."""
	_generate()
	var dispatch: CommandDispatchScript = _wire_commands()
	var basin: Vector2i = _world.basin_ref_of(WorldInit.BASIN_FOREST_WEST_NORTH)
	var tiles: PackedInt32Array = PackedInt32Array([WorldInit.tile_index_of(20, 30),
		WorldInit.tile_index_of(21, 30), WorldInit.tile_index_of(22, 30)])
	assert_equal(_designate(dispatch, basin, tiles), CommandDispatchScript.RESULT_COMMITTED,
		"the designation commits against a generated forest basin")
	assert_equal(_forage.zone_count(), 8, "a new player zone joins the seven basins")
	var designation: int = _forage.live_zone_slot_at(7).value
	assert_true(_forage.is_designation(designation), "it is bound to a basin, not self-owning")
	assert_equal(_forage.basin_ref_of(designation), basin, "the generated forest basin")
	assert_equal(_forage.tile_count_of(designation).value, 3, "carrying its three forest tiles")


func test_a_designation_shares_the_generated_basins_stock() -> void:
	"""Decision 0026: a designation binds to existing stock and never creates or multiplies it."""
	_generate()
	var dispatch: CommandDispatchScript = _wire_commands()
	var basin: Vector2i = _world.basin_ref_of(WorldInit.BASIN_FOREST_WEST_NORTH)
	var basin_row: int = _forage.patch_row_for_zone(basin, ForageScript.PATCH_BERRIES).value
	var before: int = _forage.stock_milli_of(basin_row).value
	assert_equal(_designate(dispatch, basin,
		PackedInt32Array([WorldInit.tile_index_of(20, 30)])),
		CommandDispatchScript.RESULT_COMMITTED, "the designation commits")
	var designation: Vector2i = _forage.zone_ref_of(_forage.live_zone_slot_at(7).value)
	assert_equal(_forage.patch_row_for_zone(designation, ForageScript.PATCH_BERRIES).value,
		basin_row, "the designation resolves to the basin's own patch row")
	assert_equal(_forage.stock_milli_of(basin_row).value, before,
		"and designating created no new stock")
	assert_equal(_forage.zone_count(), 8, "one designation, not a second basin")


func test_a_designated_forest_zone_publishes_a_real_forage_job() -> void:
	"""The end of the chain: generated basin -> player designation -> one ARCH-SYS-009 FORAGE job."""
	_generate()
	var planner: JobPlannerScript = JobPlannerScript.new(null, _jobs, _forage)
	var dispatch: CommandDispatchScript = _wire_commands(planner)
	assert_equal(_jobs.job_count(), 0, "generation itself creates no job")
	assert_equal(_designate(dispatch, _world.basin_ref_of(WorldInit.BASIN_FOREST_WEST_NORTH),
		PackedInt32Array([WorldInit.tile_index_of(20, 30)])),
		CommandDispatchScript.RESULT_COMMITTED, "the designation commits")
	assert_equal(_jobs.job_count(), 0, "committing the command alone still creates no work")
	assert_true(planner.run_tick(1).ok, "the planner tick runs")
	assert_equal(_jobs.job_count(), 1, "and one FORAGE harvest exists")
	var designation: int = _forage.live_zone_slot_at(7).value
	var harvest: Vector2i = EntityDirectory.NULL_REF
	for patch_kind: int in ForageScript.PATCHES_PER_ZONE:
		var found: Vector2i = planner.forage_demand_job_of(designation, patch_kind)
		if found != EntityDirectory.NULL_REF:
			harvest = found
	assert_true(harvest != EntityDirectory.NULL_REF, "the planner names the published harvest")
	assert_equal(_jobs.kind_of(_directory.get_typed_row(harvest)).value,
		CatalogScript.JOB_KIND["FORAGE"], "against the generated forest")


func _wire_commands(planner: JobPlannerScript = null) -> CommandDispatchScript:
	"""Compose the ARCH-SYS-002 command stage over this test's stores, with ecology bound."""
	_clock = SimClockScript.new()
	_queue = CommandsScript.new(_clock, _directory)
	var dispatch: CommandDispatchScript = CommandDispatchScript.new(_queue, _residents, null,
		null, _jobs, _forage, planner if planner != null \
			else JobPlannerScript.new(null, _jobs, _forage))
	return dispatch


func _designate(dispatch: CommandDispatchScript, basin: Vector2i,
		tiles: PackedInt32Array) -> int:
	"""Submit and commit one DESIGNATE_ZONE over `basin`, returning its deterministic result id."""
	var submission: CommandsScript.Command = CommandsScript.Command.new()
	submission.reset()
	submission.kind = CatalogScript.COMMAND_KIND["DESIGNATE_ZONE"]
	submission.target_slot = basin.x
	submission.target_generation = basin.y
	submission.arg0 = ForageScript.ZONE_TYPE_FORAGE
	submission.arg1 = 1
	submission.payload = _tile_payload(tiles)
	var accepted: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	if not _queue.submit_into(submission, accepted):
		fail("admission refused with %s" % accepted.error)
		return -1
	var report: CommandDispatchScript.TickReport = CommandDispatchScript.TickReport.new()
	if not dispatch.commit_tick_into(1, report):
		fail("the commit stage refused with %s" % report.error)
		return -1
	var row: CommandDispatchScript.ResultRow = CommandDispatchScript.ResultRow.new()
	if not dispatch.last_result_into(row):
		fail("the result ledger holds no outcome")
		return -1
	return row.code_id


func _tile_payload(tiles: PackedInt32Array) -> PackedByteArray:
	"""GDD §8.1's "zone tiles": an i32 count followed by that many ascending i32 tile indices."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 4 * tiles.size())
	bytes.encode_s32(0, tiles.size())
	for index: int in tiles.size():
		bytes.encode_s32(4 + index * 4, tiles[index])
	return bytes


# --- the composition surface a settlement bootstrap needs (decision 0064) -----------------------

func test_the_generator_publishes_the_directory_it_was_composed_over() -> void:
	"""A composing system proves it shares one allocator instead of waiting for a refusal."""
	assert_true(_world.directory() == _directory, "the generator hands back its own directory")
	assert_true(_world.directory() == _residents.directory(),
		"which is the same directory every settlement store validates against")


func test_clear_discards_the_published_map_without_touching_the_stores() -> void:
	"""`clear()` is the map half of a settlement reset; emptying the stores is the caller's."""
	assert_true(_generate().ok, "a world is published")
	assert_true(_world.is_published(), "and reports so")
	var nodes_before: int = _nodes.count()
	_world.clear()
	assert_false(_world.is_published(), "clear() discards the published map")
	assert_equal(_nodes.count(), nodes_before,
		"and deliberately does NOT clear the stores, which the caller owns")
	assert_false(_world.published_seed().ok, "the accepted seed is gone with the map")
	assert_false(_world.terrain_at(WorldInit.tile_index_of(64, 64)).ok,
		"and every tile reader refuses again, exactly as before the first generation")


func test_a_cleared_generator_generates_the_same_world_again() -> void:
	"""Clearing must leave the generator usable, not merely quiet."""
	assert_true(_generate().ok, "the first world publishes")
	var first_seed: int = _world.published_seed().value
	_world.clear()
	_nodes.clear()
	_forage.clear()
	_fishing.clear()
	_directory.clear()
	assert_true(_generate().ok, "and the same generator publishes a second world")
	assert_equal(_world.published_seed().value, first_seed, "on the same accepted seed")
	assert_equal(_nodes.count(), 1695, "with the same node census")


# --- R-INIT-ID-001: preflight / seed / publish as three steps -----------------------------------
#
# The ruling relocated the reset that used to live inside publication: it is a reset BEFORE
# new-world allocation, not a second one after a cohort has been allocated. `generate()` keeps it
# as the standalone isolated-control wrapper, and the three public steps below are what a composed
# initializer drives so that GDD §5.1's twelve residents can hold persistent ids 1-12.

func test_preflight_accepts_a_plan_without_creating_anything() -> void:
	"""Ruling step 1: preflight "without changing the prior valid world"."""
	var planned: WorldInit.GenerateResult = _world.preflight(_request())
	assert_true(planned.ok, "the plan is accepted (error: %s)" % planned.error)
	assert_equal(planned.accepted_seed, WorldInit.TUTORIAL_WORLD_SEED, "on §5.1's own seed")
	assert_true(_world.has_prepared_plan(), "and is held for publication")
	assert_equal(planned.resource_nodes_created, 0, "no node was created by preflighting")
	assert_equal(planned.basins_created, 0, "no basin either")
	assert_equal(_nodes.count(), 0, "the node store is untouched")
	assert_equal(_directory.total_live_count(), 0, "no directory row was allocated")
	assert_false(_world.is_published(), "and nothing is published")
	assert_false(_rng.is_seeded(), "preflight does not seed either")


func test_a_refused_preflight_holds_no_plan() -> void:
	"""A refusal leaves nothing staged, or a later publish creates a world nobody asked for."""
	var bad: WorldInit.Request = _request()
	bad.scenario_version = 99
	var planned: WorldInit.GenerateResult = _world.preflight(bad)
	assert_false(planned.ok, "an unknown scenario refuses")
	assert_equal(planned.error, WorldInit.REFUSE_UNKNOWN_SCENARIO, "with its own code")
	assert_false(_world.has_prepared_plan(), "and no plan is held")
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(published.ok, "so publication refuses")
	assert_equal(published.error, WorldInit.REFUSE_NO_PREPARED_PLAN, "naming the missing plan")


func test_the_three_steps_publish_the_same_world_the_wrapper_does() -> void:
	"""Preflight, seed, publish must produce exactly what `generate()` produces.

	The composed path uses the three steps; the isolated controls use the wrapper. A difference
	between them would mean the settlement's world is not the world this suite tests.
	"""
	assert_true(_generate().ok, "the wrapper publishes first")
	var wrapper: String = _content_fingerprint()
	_world.clear()
	_nodes.clear()
	_forage.clear()
	_fishing.clear()
	_jobs.clear()
	_rng.clear()
	_directory.clear()
	assert_true(_world.preflight(_request()).ok, "the plan is staged")
	assert_equal(_world.seed_prepared_streams(), WorldInit.REFUSE_NONE, "the streams are seeded")
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_true(published.ok, "and the plan publishes (error: %s)" % published.error)
	assert_equal(_content_fingerprint(), wrapper, "the same world, to the byte")
	assert_equal(published.resource_nodes_created, _nodes.count(), "reporting its real census")


func test_publication_keeps_directory_rows_it_did_not_create() -> void:
	"""The whole ruling in one test: rows allocated BEFORE publication survive it.

	A row of the resident kind stands in for the twelve the composed initializer allocates first.
	Under the old `_publish()` it was destroyed by the directory clear inside publication; it must
	now keep its reference, its persistent id, and its place at the FRONT of the id space.
	"""
	assert_true(_world.preflight(_request()).ok, "a plan is staged first")
	assert_equal(_world.seed_prepared_streams(), WorldInit.REFUSE_NONE, "and the streams seeded")
	var first: Vector2i = _directory.create(EntityDirectory.KIND_RESIDENT)
	assert_equal(_directory.get_persistent_id(first), 1, "the pre-publication row takes id 1")
	assert_true(_world.publish_prepared().ok, "the world publishes over it")
	assert_true(_directory.is_valid(first), "and the row is still live")
	assert_equal(_directory.get_persistent_id(first), 1, "still holding id 1")
	assert_equal(_directory.live_count(EntityDirectory.KIND_RESIDENT), 1, "still the only one")
	var lowest_world_id: int = 0
	for index: int in _nodes.count():
		var id: int = _directory.get_persistent_id(
			_nodes.ref_of(_nodes.live_slot_at(index).value))
		if lowest_world_id == 0 or id < lowest_world_id:
			lowest_world_id = id
	assert_true(lowest_world_id > 1, "and every world entity follows it in the same id space")


func test_publication_refuses_a_world_the_caller_never_reset() -> void:
	"""`publish_prepared()` clears nothing, so it proves the caller's single reset happened."""
	assert_true(_generate().ok, "a world already stands")
	assert_true(_world.preflight(_request()).ok, "and a second plan is staged")
	assert_equal(_world.seed_prepared_streams(), WorldInit.REFUSE_NONE, "and seeded")
	var before: String = _content_fingerprint()
	var nodes_before: int = _nodes.count()
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(published.ok, "publishing on top of it refuses")
	assert_equal(published.error, WorldInit.REFUSE_WORLD_NOT_RESET, "with the exact reason")
	assert_equal(_nodes.count(), nodes_before, "not one node was added")
	assert_equal(_content_fingerprint(), before, "and the standing world is unchanged")


func test_publication_refuses_streams_that_carry_another_seed() -> void:
	"""A world published over a different seed's streams would be deterministic in name only."""
	assert_true(_world.preflight(_request()).ok, "a plan is staged")
	var other: RngScript.OpResult = _rng.seed_world(WorldInit.TUTORIAL_WORLD_SEED + 1)
	assert_true(other.ok, "the streams are seeded from somewhere else")
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(published.ok, "publication refuses")
	assert_equal(published.error, WorldInit.REFUSE_SEED_NOT_APPLIED, "naming the mismatch")
	assert_equal(_nodes.count(), 0, "and creates nothing")


func test_publication_refuses_unseeded_streams() -> void:
	"""§5.10's second season would refuse RNG_NOT_SEEDED over a world nobody seeded."""
	assert_true(_world.preflight(_request()).ok, "a plan is staged")
	assert_false(_rng.is_seeded(), "and the streams are not seeded")
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(published.ok, "publication refuses")
	assert_equal(published.error, WorldInit.REFUSE_SEED_NOT_APPLIED, "naming the missing seed")


func test_seeding_refuses_without_a_prepared_plan() -> void:
	"""The seed belongs to an accepted plan; there is no default seed to fall back on."""
	assert_equal(_world.seed_prepared_streams(), WorldInit.REFUSE_NO_PREPARED_PLAN,
		"no plan, no seed")
	assert_false(_rng.is_seeded(), "and the streams stay unseeded")


func test_a_published_plan_cannot_be_published_twice() -> void:
	"""Publishing consumes the plan, so a repeated call cannot double the world."""
	assert_true(_world.preflight(_request()).ok, "a plan is staged")
	assert_equal(_world.seed_prepared_streams(), WorldInit.REFUSE_NONE, "and seeded")
	assert_true(_world.publish_prepared().ok, "it publishes once")
	assert_false(_world.has_prepared_plan(), "and is consumed")
	var again: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(again.ok, "a second publication refuses")
	assert_equal(again.error, WorldInit.REFUSE_NO_PREPARED_PLAN, "with no plan left to publish")
	assert_equal(_nodes.count(), 1695, "and the census did not double")


func test_discarding_a_plan_makes_publication_refuse() -> void:
	"""The abandon path a composed initializer takes when its transaction fails."""
	assert_true(_world.preflight(_request()).ok, "a plan is staged")
	_world.discard_prepared_plan()
	assert_false(_world.has_prepared_plan(), "and dropped")
	var published: WorldInit.GenerateResult = _world.publish_prepared()
	assert_false(published.ok, "publication refuses")
	assert_equal(published.error, WorldInit.REFUSE_NO_PREPARED_PLAN, "naming the dropped plan")


func test_a_foreign_live_row_still_refuses_at_preflight() -> void:
	"""The orphan guard moved earlier, not away: the wrapper's reset still cannot strand a row."""
	var stray: Vector2i = _directory.create(EntityDirectory.KIND_BUILDING)
	assert_true(stray != EntityDirectory.NULL_REF, "a row of an unowned kind exists")
	var planned: WorldInit.GenerateResult = _world.preflight(_request())
	assert_false(planned.ok, "preflight refuses")
	assert_equal(planned.error, WorldInit.REFUSE_FOREIGN_LIVE_ROWS, "with the orphan guard's code")
	assert_true(_directory.is_valid(stray), "and the foreign row is untouched")
