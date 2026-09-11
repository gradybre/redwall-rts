extends "res://test/framework/test_case.gd"
## Coverage for the ARCH-PATH-001 ground map and the 05.1a ground location identity.
##
## The map is derived from `world_init.gd`'s authored terrain masks, so these tests assert against
## the GDD 5.1 estuary itself -- the coast band, the river, the lake and the natural ford -- rather
## than against a synthetic grid that could agree with a broken derivation.
##
## Building the map costs one 128x128 mask pass plus one 262144-cell clearance pass, so the
## READ-ONLY tests share one instance. Any test that calls `override_static_legality()` builds its
## own, because that call mutates legality and advances the revision.

const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

## A land tile well west of the river and south of the coast: (64, 64) is GDD 5.1's own anchor.
const LAND_TILE_X: int = 64
const LAND_TILE_Z: int = 64

static var _shared: SpatialWorldScript = null

var _world: SpatialWorldScript = null
var _result: IntMathScript.IntResult = null


func before_each() -> void:
	"""Point the test at the shared read-only map and allocate one scratch result."""
	if _shared == null:
		_shared = SpatialWorldScript.new()
	_world = _shared
	_result = IntMathScript.IntResult.new()


func after_each() -> void:
	"""Drop the per-test references; the shared map outlives them deliberately."""
	_world = null
	_result = null


func _private_world() -> SpatialWorldScript:
	"""Build a map this test may mutate without disturbing the shared read-only instance."""
	_world = SpatialWorldScript.new()
	return _world


func _cell(x: int, z: int) -> int:
	"""The cell index of a grid coordinate, asserted to be in range."""
	assert_true(_world.cell_index_into(x, z, _result), "cell (%d,%d) must be in range" % [x, z])
	return _result.value


# --- geometry ---------------------------------------------------------------------------------

func test_grid_is_512_squared_half_metre_cells() -> void:
	"""ARCH-PATH-001: 256 m square at 1/2 m gives 512x512=262144 cells of 512 position units."""
	assert_equal(SpatialWorldScript.CELLS_X, 512, "grid is 512 cells wide")
	assert_equal(SpatialWorldScript.CELL_COUNT, 262144, "grid holds 262144 cells")
	assert_equal(SpatialWorldScript.CELL_SIZE_UNITS, 512, "a 1/2 m cell is 512 units of 1/1024 m")
	assert_equal(
		SpatialWorldScript.CELLS_X * SpatialWorldScript.CELL_SIZE_UNITS, 256 * 1024,
		"512 cells of 512 units span exactly 256 m")


func test_cell_index_is_z_times_512_plus_x() -> void:
	"""ARCH-PATH-001 fixes `cell ID = z*512+x`; the inverse readers must agree with it."""
	assert_true(_world.cell_index_into(7, 9, _result), "an in-range coordinate resolves")
	assert_equal(_result.value, 9 * 512 + 7, "cell id is z*512+x")
	assert_equal(SpatialWorldScript.cell_x_of(_result.value), 7, "x is recovered")
	assert_equal(SpatialWorldScript.cell_z_of(_result.value), 9, "z is recovered")


func test_cell_index_refuses_off_grid_coordinates() -> void:
	"""An out-of-grid coordinate refuses explicitly instead of wrapping into a plausible cell."""
	assert_false(_world.cell_index_into(512, 0, _result), "x=512 is off the grid")
	assert_equal(_world.last_refusal(), SpatialWorldScript.REFUSE_INVALID_COORD, "refusal is named")
	assert_equal(_result.value, 0, "a refused result carries no value")
	assert_false(_world.cell_index_into(-1, 5, _result), "negative x is off the grid")
	assert_false(_world.cell_index_into(5, 512, _result), "z=512 is off the grid")


func test_cell_centres_and_position_lookup_round_trip() -> void:
	"""A cell's centre position must map back to that same cell."""
	var cell: int = _cell(300, 200)
	var x: int = SpatialWorldScript.cell_centre_x_units(cell)
	var z: int = SpatialWorldScript.cell_centre_z_units(cell)
	assert_equal(x, 300 * 512 + 256, "centre x is the cell origin plus half a cell")
	assert_equal(z, 200 * 512 + 256, "centre z is the cell origin plus half a cell")
	assert_true(_world.cell_of_position_into(x, z, _result), "the centre resolves to a cell")
	assert_equal(_result.value, cell, "the centre resolves back to its own cell")


func test_position_lookup_refuses_outside_the_map() -> void:
	"""A position beyond the 256 m square refuses rather than clamping to an edge cell."""
	assert_false(_world.cell_of_position_into(-1, 0, _result), "negative x is off the map")
	assert_equal(
		_world.last_refusal(), SpatialWorldScript.REFUSE_INVALID_POSITION, "refusal is named")
	assert_false(_world.cell_of_position_into(262144, 0, _result), "256 m is one past the last cell")
	assert_true(_world.cell_of_position_into(262143, 262143, _result), "the last unit is on the map")
	assert_equal(_result.value, SpatialWorldScript.CELL_COUNT - 1, "it is the last cell")


func test_macro_cells_are_16_by_16_and_tile_the_grid() -> void:
	"""ARCH-PATH-003's macro cells: 16x16 navigation cells, 32x32 of them over the map."""
	assert_equal(SpatialWorldScript.MACRO_CELLS, 16, "a macro is 16 cells on a side")
	assert_equal(SpatialWorldScript.MACRO_COUNT, 1024, "the map holds 1024 macro cells")
	assert_equal(SpatialWorldScript.macro_of(0), 0, "cell 0 is in macro 0")
	assert_equal(SpatialWorldScript.macro_of(262143), 1023, "the last cell is in the last macro")
	assert_equal(SpatialWorldScript.macro_of(_cell(16, 0)), 1, "x=16 is the second macro column")
	assert_equal(SpatialWorldScript.macro_of(_cell(0, 16)), 32, "z=16 is the second macro row")
	assert_equal(SpatialWorldScript.macro_first_cell(33), _cell(16, 16), "macro 33 starts at (16,16)")


# --- legality derived from the authored terrain ------------------------------------------------

func test_walkability_follows_world_init_terrain_tile_for_tile() -> void:
	"""Every cell's legality must be its 2 m tile's, four cells across and four down."""
	var mismatches: int = 0
	for tile_z: int in WorldInitScript.MAP_TILES_Z:
		for tile_x: int in WorldInitScript.MAP_TILES_X:
			var expected: bool = WorldInitScript.is_walkable(tile_x, tile_z)
			var cell: int = _cell(tile_x * 4 + 2, tile_z * 4 + 1)
			if _world.is_walkable_cell(cell) != expected:
				mismatches += 1
	assert_equal(mismatches, 0, "no cell disagrees with the tile it sits in")
	assert_equal(
		_world.walkable_cell_count(), 214384, "the authored estuary leaves 214384 walkable cells")


func test_the_ford_is_walkable_river() -> void:
	"""GDD 5.1: the natural ford at river tiles z=48..51 is walkable, and it is river, not land."""
	for tile_z: int in range(WorldInitScript.FORD_FIRST_Z, WorldInitScript.FORD_LAST_Z + 1):
		for tile_x: int in range(WorldInitScript.RIVER_FIRST_X, WorldInitScript.RIVER_LAST_X + 1):
			var cell: int = _cell(tile_x * 4 + 1, tile_z * 4 + 2)
			assert_true(_world.is_walkable_cell(cell), "ford tile (%d,%d) walks" % [tile_x, tile_z])
			assert_true(_world.is_ford_cell(cell), "the ford predicate agrees")
			assert_true(_world.terrain_into(cell, _result), "terrain reads")
			assert_equal(_result.value, WorldInitScript.TERRAIN_RIVER, "the ford is still river")


func test_the_ford_is_not_a_fishing_work_tile() -> void:
	"""READY_07 1.2 is explicit: walkable, and NOT a fishing tile. `world_init.gd` owns both halves."""
	var ford_x: int = WorldInitScript.RIVER_FIRST_X
	for tile_z: int in range(WorldInitScript.FORD_FIRST_Z, WorldInitScript.FORD_LAST_Z + 1):
		assert_true(WorldInitScript.is_ford(ford_x, tile_z), "the tile is the ford")
		assert_equal(
			WorldInitScript.fish_basin_of(ford_x, tile_z), WorldInitScript.NO_BASIN,
			"ford tile z=%d belongs to no fish basin, so no fishing contact can sit on it" % tile_z)
	assert_equal(
		WorldInitScript.fish_basin_of(ford_x, WorldInitScript.FORD_LAST_Z + 1),
		WorldInitScript.BASIN_FISH_RIVER,
		"the river one tile south of the ford IS river fishery, so the exclusion is the ford's own")


func test_the_river_blocks_everywhere_except_the_ford() -> void:
	"""Without the ford the authored river would cut the settlement in two; the ford is the crossing."""
	var blocked: int = 0
	for tile_z: int in range(WorldInitScript.RIVER_FIRST_Z, WorldInitScript.RIVER_LAST_Z + 1):
		var cell: int = _cell(WorldInitScript.RIVER_FIRST_X * 4 + 1, tile_z * 4)
		if not _world.is_walkable_cell(cell):
			blocked += 1
	var river_tiles: int = WorldInitScript.RIVER_LAST_Z - WorldInitScript.RIVER_FIRST_Z + 1
	var ford_tiles: int = WorldInitScript.FORD_LAST_Z - WorldInitScript.FORD_FIRST_Z + 1
	assert_equal(blocked, river_tiles - ford_tiles, "every river tile but the ford's four blocks")


func test_heights_are_the_three_authored_surfaces() -> void:
	"""GDD 5.1: land 512 units, the ford -128, other water 0. Movement reads these, not a guess."""
	var land: int = _cell(LAND_TILE_X * 4, LAND_TILE_Z * 4)
	assert_true(_world.height_units_into(land, _result), "land height reads")
	assert_equal(_result.value, WorldInitScript.LAND_Y_UNITS, "navigable land is y=512")
	var ford: int = _cell(WorldInitScript.RIVER_FIRST_X * 4, WorldInitScript.FORD_FIRST_Z * 4)
	assert_true(_world.height_units_into(ford, _result), "ford height reads")
	assert_equal(_result.value, WorldInitScript.FORD_Y_UNITS, "the ford sits at y=-128")
	var lake: int = _cell(WorldInitScript.LAKE_CENTER_X * 4, WorldInitScript.LAKE_CENTER_Z * 4)
	assert_true(_world.height_units_into(lake, _result), "lake height reads")
	assert_equal(_result.value, WorldInitScript.WATER_SURFACE_Y_UNITS, "open water is y=0")


func test_readers_refuse_an_out_of_range_cell() -> void:
	"""Every cell reader refuses explicitly; none of them reports a default as if it were data."""
	assert_false(_world.terrain_into(-1, _result), "terrain refuses a negative cell")
	assert_equal(_world.last_refusal(), SpatialWorldScript.REFUSE_INVALID_CELL, "refusal is named")
	assert_false(_world.height_units_into(SpatialWorldScript.CELL_COUNT, _result), "height refuses")
	assert_false(_world.clearance_into(SpatialWorldScript.CELL_COUNT, _result), "clearance refuses")
	assert_false(_world.is_walkable_cell(-1), "walkability of a bad cell is false, not an error")
	assert_equal(_world.layer_of(-1), -1, "layer of a bad cell is absent")


# --- clearance --------------------------------------------------------------------------------

func test_clearance_is_the_largest_open_square_at_the_cell() -> void:
	"""Clearance is map geometry: the side of the largest all-passable square anchored at the cell."""
	var open_land: int = _cell(200, 300)
	assert_true(_world.clearance_into(open_land, _result), "clearance reads")
	assert_true(_result.value >= 8, "open inland has room for a large synthetic body")
	var water: int = _cell(
		WorldInitScript.LAKE_CENTER_X * 4, WorldInitScript.LAKE_CENTER_Z * 4)
	assert_true(_world.clearance_into(water, _result), "clearance reads on water too")
	assert_equal(_result.value, 0, "a blocked cell has zero clearance")


func test_clearance_class_is_a_caller_input_not_a_published_profile() -> void:
	"""A bigger synthetic class must be refused where a smaller one passes. No profile is declared."""
	var narrow: int = _cell((WorldInitScript.RIVER_LAST_X + 1) * 4, 300)
	assert_true(_world.cell_passes_clearance(narrow, 1), "the east riverbank admits a 1-cell class")
	assert_false(_world.cell_passes_clearance(narrow, 200), "it cannot admit a 200-cell class")
	assert_false(_world.cell_passes_clearance(narrow, 0), "class 0 is not a class")
	assert_equal(
		SpatialWorldScript.MIN_CLEARANCE_CLASS, 1, "the smallest class a caller may ask for is 1")


func test_clearance_shrinks_beside_a_blocked_cell() -> void:
	"""Blocking one cell must reduce the clearance of the cells whose open square contained it."""
	var world: SpatialWorldScript = _private_world()
	var target: int = _cell(200, 300)
	assert_true(world.clearance_into(target, _result), "clearance reads before the edit")
	var before: int = _result.value
	assert_true(world.override_static_legality(_cell(203, 303), false), "carve a hole at +3,+3")
	assert_true(world.clearance_into(target, _result), "clearance reads after the edit")
	assert_equal(_result.value, 3, "the open square can now only reach the blocked cell's corner")
	assert_true(before > 3, "and it was larger before")


func test_macro_anchor_is_the_lowest_passable_cell_of_the_macro() -> void:
	"""ARCH-PATH-003: "Choose the lowest passable cell in the macro as anchor"."""
	var land_macro: int = SpatialWorldScript.macro_of(_cell(160, 160))
	assert_equal(
		_world.lowest_passable_cell_in_macro(land_macro, 1),
		SpatialWorldScript.macro_first_cell(land_macro),
		"on open land the anchor is the macro's north-west corner")
	var coast_macro: int = SpatialWorldScript.macro_of(_cell(160, 0))
	assert_equal(
		_world.lowest_passable_cell_in_macro(coast_macro, 1), -1,
		"a macro entirely under the coast band has no passable cell at all")
	assert_equal(
		_world.lowest_passable_cell_in_macro(-1, 1), -1, "an out-of-range macro has no anchor")


func test_the_macro_anchor_skips_cells_that_fail_the_clearance_class() -> void:
	""""Lowest PASSABLE cell" means passable for the class asked for, not merely walkable.

	Added after a mutation survived: dropping the clearance test from the anchor scan left every
	existing test green, because on open land the macro's north-west corner passes every class the
	suite used. One blocked cell at the corner's south-east shrinks its open square to 1, and the
	anchor for class 2 must then move along.
	"""
	var world: SpatialWorldScript = _private_world()
	var corner: int = _cell(192, 288)
	var macro_id: int = SpatialWorldScript.macro_of(corner)
	assert_equal(SpatialWorldScript.macro_first_cell(macro_id), corner, "the corner starts the macro")
	assert_true(world.override_static_legality(_cell(193, 289), false), "carve its diagonal")
	assert_true(world.clearance_into(corner, _result), "the corner's clearance reads")
	assert_equal(_result.value, 1, "the corner now admits only a 1-cell class")
	assert_equal(
		world.lowest_passable_cell_in_macro(macro_id, 1), corner,
		"a 1-cell class still anchors on the corner")
	assert_equal(
		world.lowest_passable_cell_in_macro(macro_id, 2), _cell(194, 288),
		"a 2-cell class skips the corner and its eastern neighbour, which is also pinched")


# --- ground location identity ------------------------------------------------------------------

func test_a_ground_location_carries_domain_layer_revision_and_owner() -> void:
	"""READY_07 1.2: a ground location ID is a cell PLUS its spatial context and contact owner."""
	var location: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_false(location.is_bound(), "a fresh record names nothing")
	var owner: Vector2i = Vector2i(41, 7)
	assert_true(_world.bind_ground_location(location, _cell(100, 100), owner), "binding succeeds")
	assert_equal(location.domain, SpatialWorldScript.DOMAIN_GROUND, "the domain is declared")
	assert_equal(location.layer, SpatialWorldScript.LAYER_SURFACE, "the layer is declared")
	assert_equal(location.revision, _world.current_map_revision(), "the world revision is recorded")
	assert_equal(location.cell, _cell(100, 100), "the baseline cell index is recorded")
	assert_equal(location.owner_ref(), owner, "both halves of the contact owner are recorded")
	assert_true(location.is_bound(), "the record now names a place")


func test_a_location_requires_a_generation_safe_owner() -> void:
	"""The null reference is not a contact owner; X/Z alone may not identify a destination."""
	var location: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_false(
		_world.bind_ground_location(location, _cell(100, 100), Vector2i(-1, 0)),
		"the null reference is refused as an owner")
	assert_equal(_world.last_refusal(), SpatialWorldScript.REFUSE_NULL_OWNER, "refusal is named")
	assert_false(location.is_bound(), "and nothing was written into the record")
	assert_false(
		_world.bind_ground_location(location, SpatialWorldScript.CELL_COUNT, Vector2i(1, 1)),
		"an out-of-grid cell is refused too")
	assert_equal(_world.last_refusal(), SpatialWorldScript.REFUSE_INVALID_CELL, "refusal is named")


func test_same_x_and_z_does_not_identify_a_destination_across_domains() -> void:
	"""The identity boundary later domains extend: a cell is qualified, never universal."""
	var ground: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var other: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(_world.bind_ground_location(ground, _cell(100, 100), Vector2i(1, 1)), "ground binds")
	assert_true(_world.bind_ground_location(other, _cell(100, 100), Vector2i(2, 1)), "so does other")
	assert_true(ground.same_place_as(other), "the same cell in the same domain IS the same place")
	other.layer = SpatialWorldScript.LAYER_SURFACE + 1
	assert_false(ground.same_place_as(other), "the same cell on another layer is NOT the same place")
	other.layer = SpatialWorldScript.LAYER_SURFACE
	other.domain = SpatialWorldScript.DOMAIN_GROUND + 1
	assert_false(ground.same_place_as(other), "nor is the same cell in another domain")


func test_uncontracted_domains_and_layers_refuse_by_name() -> void:
	"""Diving, canopy and underground each need their own completed contract, not a default."""
	assert_true(_world.domain_is_contracted(SpatialWorldScript.DOMAIN_GROUND), "ground is contracted")
	assert_false(_world.domain_is_contracted(1), "no second domain is contracted by this slice")
	assert_equal(
		_world.refuse_uncontracted(1, SpatialWorldScript.LAYER_SURFACE),
		SpatialWorldScript.REFUSE_DOMAIN, "an unknown domain refuses by name")
	assert_equal(
		_world.refuse_uncontracted(SpatialWorldScript.DOMAIN_GROUND, 1),
		SpatialWorldScript.REFUSE_LAYER, "an unknown layer refuses by name")
	assert_equal(
		_world.refuse_uncontracted(SpatialWorldScript.DOMAIN_GROUND, SpatialWorldScript.LAYER_SURFACE),
		SpatialWorldScript.REFUSE_NONE, "the contracted pair refuses nothing")
	assert_equal(SpatialWorldScript.DOMAIN_COUNT, 1, "exactly one domain is contracted")


func test_a_location_minted_before_an_edit_is_no_longer_current() -> void:
	"""Revision invalidation: an edit advances the revision, so old handles stop being current."""
	var world: SpatialWorldScript = _private_world()
	var location: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(world.bind_ground_location(location, _cell(100, 100), Vector2i(1, 1)), "binds")
	assert_true(world.location_is_current(location), "it is current when minted")
	var before: int = world.current_map_revision()
	assert_true(world.override_static_legality(_cell(150, 150), false), "one cell is carved")
	assert_equal(world.current_map_revision(), before + 1, "the revision advanced exactly once")
	assert_false(world.location_is_current(location), "the old handle is no longer current")
	assert_true(world.bind_ground_location(location, _cell(100, 100), Vector2i(1, 1)), "rebinds")
	assert_true(world.location_is_current(location), "a freshly minted handle is current again")


func test_revisions_start_positive_and_are_bounded_not_wrapped() -> void:
	"""SET-MOVE-001 2: a positive revision that refuses exhaustion rather than wrapping."""
	assert_equal(SpatialWorldScript.FIRST_MAP_REVISION, 1, "the first revision is positive")
	assert_true(_world.current_map_revision() >= 1, "the live revision is positive")
	assert_equal(
		SpatialWorldScript.MAX_MAP_REVISION, IntMathScript.INT32_MAX,
		"the baseline identity record bounds the revision at int32 rather than wrapping it")


func test_legality_override_refuses_an_out_of_range_cell() -> void:
	"""The one legality mutator refuses a bad cell without advancing the revision."""
	var world: SpatialWorldScript = _private_world()
	var before: int = world.current_map_revision()
	assert_false(world.override_static_legality(-1, false), "a negative cell is refused")
	assert_equal(world.last_refusal(), SpatialWorldScript.REFUSE_INVALID_CELL, "refusal is named")
	assert_equal(world.current_map_revision(), before, "and no revision was spent on the refusal")


func test_legality_override_updates_walkability_and_the_walkable_count() -> void:
	"""An override must change what the map reports, in both the cell and the aggregate."""
	var world: SpatialWorldScript = _private_world()
	var cell: int = _cell(220, 320)
	var before: int = world.walkable_cell_count()
	assert_true(world.is_walkable_cell(cell), "the cell starts walkable")
	assert_true(world.override_static_legality(cell, false), "block it")
	assert_false(world.is_walkable_cell(cell), "it is no longer walkable")
	assert_equal(world.walkable_cell_count(), before - 1, "the count fell by exactly one")
	assert_true(world.override_static_legality(cell, true), "open it again")
	assert_equal(world.walkable_cell_count(), before, "and the count returned")
