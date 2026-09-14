extends "res://test/framework/test_case.gd"
## R-WORLD-S1-001 §6: the seven section-1 owners' own capture, domain and cross-owner validators.
##
## `test_save_section_01.gd` owns the WIRE. This suite owns the MEANING: what each store will hand
## over, what it refuses to take back, and what its inverse maps must agree about. Every scenario
## below is built by driving the LIVE stores through their real mutators -- a real rotated
## footprint, a real room tile run, a real forage chain, a real published estuary -- because a
## validator exercised only against hand-written columns is a validator nobody has pointed at the
## code it is supposed to be judging.
##
## Numeric bounds are transcribed from the ruling, not read back out of the module under test.

const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResourceCatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const MilestonesScript := preload("res://scripts/core/milestones.gd")

## R-WORLD-S1-001 §6 S1-WEATHER's reachable outer bounds, transcribed from the ruling.
const RULING_TEMPERATURE_MIN: int = -120
const RULING_TEMPERATURE_MAX: int = 300
const RULING_RAIN_MIN: int = 0
const RULING_RAIN_MAX: int = 3200

## §6's compiled present-event tuples, in blight..ideal_spell order.
const RULING_START_DAYS: Array[int] = [6, 6, 6, 10, 6, 6, 6]
const RULING_DURATIONS: Array[int] = [3, 2, 4, 2, 3, 2, 3]

var _residents: ResidentsScript = null
var _jobs: JobsScript = null
var _directory: EntityDirectory = null
var _buildings: BuildingsScript = null
var _farming: FarmingScript = null
var _forage: ForageScript = null
var _nodes: ResourceNodesScript = null
var _spatial: SpatialWorldScript = null
var _weather: WeatherScript = null


func before_each() -> void:
	"""One fresh settlement per test, every store sharing a single entity directory."""
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	_directory = _jobs.directory()
	_buildings = BuildingsScript.new(_directory)
	_farming = FarmingScript.new(_directory)
	_forage = ForageScript.new(_directory, _jobs)
	_nodes = ResourceNodesScript.new(_directory)
	_spatial = SpatialWorldScript.new()
	_weather = WeatherScript.new()


# --- resource_nodes: the one field that survived the correction --------------------------------

func _fingerprint(column: PackedInt32Array) -> String:
	"""SHA-256 hex of an i32 column, so a failed comparison reports 64 characters, not 16384.

	`assert_equal` prints both operands; on a full tile map that is a wall of integers nobody
	reads, and it has already produced a multi-megabyte log once in this lane.
	"""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(column.to_byte_array())
	return context.finish().hex_encode()


func _tile_map() -> PackedInt32Array:
	"""A TILE_COUNT-long buffer for `resource_nodes.copy_section_1_columns_into()`."""
	var column: PackedInt32Array = PackedInt32Array()
	column.resize(ResourceNodesScript.TILE_COUNT)
	return column


func test_the_resource_tile_map_captures_and_cross_checks_against_the_live_nodes() -> void:
	"""A real placement, then both directions of the inverse against the component rows."""
	var placed: ResourceNodesScript.OpResult = _nodes.create_at_tile(500, 1, 12000, 0, 1)
	assert_true(placed.ok, "a node places: %s" % placed.error)
	var column: PackedInt32Array = _tile_map()
	assert_true(_nodes.copy_section_1_columns_into(column), "capture: %s" % _nodes.section_1_detail())
	assert_equal(column[500], 0, "tile 500 names the first typed row")
	assert_equal(_nodes.section_1_local_refusal(column), ResourceNodesScript.COLUMN_REFUSE_NONE,
		"the captured column is in domain")
	assert_equal(_nodes.section_1_cross_check_refusal(), ResourceNodesScript.COLUMN_REFUSE_NONE,
		"and both directions of the inverse hold")


func test_a_tile_naming_a_row_that_is_not_present_is_refused() -> void:
	"""The forward direction: an occupied tile must name a live component row."""
	var column: PackedInt32Array = _tile_map()
	column.fill(-1)
	column[7] = 3
	assert_true(_nodes.restore_section_1_columns(column), "the column is in domain")
	assert_equal(_nodes.section_1_cross_check_refusal(),
		ResourceNodesScript.COLUMN_REFUSE_NO_COMPONENT, "but names no present node")


func test_a_live_node_with_no_inverse_entry_is_refused() -> void:
	"""The reverse direction: a present row's tile must name it back."""
	assert_true(_nodes.create_at_tile(64, 1, 12000, 0, 1).ok, "a node places")
	var column: PackedInt32Array = _tile_map()
	column.fill(-1)
	assert_true(_nodes.restore_section_1_columns(column), "an all-empty map is in domain")
	assert_equal(_nodes.section_1_cross_check_refusal(),
		ResourceNodesScript.COLUMN_REFUSE_MISSING_INVERSE, "but the live node is unmapped")


func test_a_row_outside_the_node_capacity_is_refused_by_the_local_domain() -> void:
	"""-1 or 0..4095, checked before anything is published."""
	var column: PackedInt32Array = _tile_map()
	column.fill(-1)
	column[0] = ResourceNodesScript.RESOURCE_NODE_CAPACITY
	assert_equal(_nodes.section_1_local_refusal(column),
		ResourceNodesScript.COLUMN_REFUSE_ROW_RANGE, "4096 is out of range")
	column[0] = -2
	assert_equal(_nodes.section_1_local_refusal(column),
		ResourceNodesScript.COLUMN_REFUSE_ROW_RANGE, "and so is -2, which is not the null")


func test_a_present_but_exhausted_node_is_not_rejected() -> void:
	"""R-WORLD-S1-001 §6: a zero quantity is depletion, not absence."""
	assert_true(_nodes.create_at_tile(900, 1, 1000, 5, 1).ok, "a node places")
	var taken: ResourceNodesScript.OpResult = _nodes.harvest_all(0, 1)
	assert_true(taken.ok, "it is emptied: %s" % taken.error)
	assert_equal(_nodes.section_1_cross_check_refusal(), ResourceNodesScript.COLUMN_REFUSE_NONE,
		"an exhausted node still holds its tile")


func test_a_refused_restore_leaves_the_live_tile_map_untouched() -> void:
	"""Validation runs before installation, so a bad column cannot land half-written."""
	assert_true(_nodes.create_at_tile(500, 1, 12000, 0, 1).ok, "a node places")
	var before: PackedInt32Array = _tile_map()
	assert_true(_nodes.copy_section_1_columns_into(before), "capture succeeds")
	var broken: PackedInt32Array = _tile_map()
	broken.fill(-1)
	broken[1] = 999999
	assert_false(_nodes.restore_section_1_columns(broken), "the restore refuses")
	var after: PackedInt32Array = _tile_map()
	assert_true(_nodes.copy_section_1_columns_into(after), "capture succeeds again")
	assert_equal(_fingerprint(after), _fingerprint(before), "and the live map is byte-identical")


# --- buildings: three grids, three namespaces, three footprint shapes ---------------------------

func _building_columns() -> Array[PackedInt32Array]:
	"""Three TILE_COUNT buffers for `buildings.copy_section_1_columns_into()`."""
	var maps: Array[PackedInt32Array] = []
	for _which: int in 3:
		var column: PackedInt32Array = PackedInt32Array()
		column.resize(BuildingsScript.TILE_COUNT)
		maps.append(column)
	return maps


func _placed_hall() -> Vector2i:
	"""Place the authored hall and return its reference, failing loudly if it refuses."""
	var placed: BuildingsScript.OpResult = _buildings.place_building(
		CatalogScript.BUILDING_DEFINITION["hall"], WorldInitScript.tile_index_of(58, 59), 0, MilestonesScript.ALLOWED_MASK)
	if not placed.ok:
		fail("the hall must place (error: %s)" % placed.error)
	return placed.ref


func test_a_real_rotated_footprint_cross_checks_tile_by_tile() -> void:
	"""Every tile of the whole extent, not just the origin, and the occupied total must match."""
	var hall: Vector2i = _placed_hall()
	assert_true(hall != BuildingsScript.NULL_REF, "the hall exists")
	var maps: Array[PackedInt32Array] = _building_columns()
	assert_true(_buildings.copy_section_1_columns_into(maps[0], maps[1], maps[2]),
		"capture: %s" % _buildings.section_1_detail())
	var claimed: int = 0
	for tile: int in BuildingsScript.TILE_COUNT:
		if maps[0][tile] != -1:
			claimed += 1
	assert_equal(claimed, 12 * 10, "the 12x10 hall claims 120 tiles")
	assert_equal(_buildings.section_1_cross_check_refusal(),
		BuildingsScript.COLUMN_REFUSE_NONE, "and every one of them maps back")


func test_dropping_one_footprint_tile_is_caught_and_the_origin_alone_is_not_enough() -> void:
	"""Checking an origin would pass this; checking the extent does not."""
	var hall: Vector2i = _placed_hall()
	assert_true(hall != BuildingsScript.NULL_REF, "the hall exists")
	var maps: Array[PackedInt32Array] = _building_columns()
	assert_true(_buildings.copy_section_1_columns_into(maps[0], maps[1], maps[2]), "capture")
	var origin: int = WorldInitScript.tile_index_of(58, 59)
	maps[0][origin + 5] = -1
	assert_equal(_buildings.section_1_local_refusal(maps[0], maps[1], maps[2]),
		BuildingsScript.COLUMN_REFUSE_NONE, "the column is still in domain")
	assert_true(_buildings.restore_section_1_columns(maps[0], maps[1], maps[2]), "and installs")
	assert_equal(_buildings.section_1_cross_check_refusal(),
		BuildingsScript.COLUMN_REFUSE_FOOTPRINT, "but the footprint no longer covers its tile")


func test_a_stray_occupied_tile_no_live_row_claims_is_caught() -> void:
	"""The reverse direction, proved by total rather than by a second quadratic walk."""
	var hall: Vector2i = _placed_hall()
	assert_true(hall != BuildingsScript.NULL_REF, "the hall exists")
	var maps: Array[PackedInt32Array] = _building_columns()
	assert_true(_buildings.copy_section_1_columns_into(maps[0], maps[1], maps[2]), "capture")
	maps[0][0] = 0
	assert_true(_buildings.restore_section_1_columns(maps[0], maps[1], maps[2]), "it installs")
	assert_equal(_buildings.section_1_cross_check_refusal(),
		BuildingsScript.COLUMN_REFUSE_STRAY_TILE, "one tile too many is refused")


func test_each_of_the_three_grids_is_bounded_by_its_own_capacity() -> void:
	"""Room rows go to 16383 and furniture rows to 81919; neither range is the grid size."""
	var maps: Array[PackedInt32Array] = _building_columns()
	for which: int in 3:
		maps[which].fill(-1)
	maps[0][0] = BuildingsScript.BUILDING_CAPACITY - 1
	maps[1][1] = BuildingsScript.ROOM_CAPACITY - 1
	maps[2][2] = BuildingsScript.FURNITURE_CAPACITY - 1
	assert_equal(_buildings.section_1_local_refusal(maps[0], maps[1], maps[2]),
		BuildingsScript.COLUMN_REFUSE_NONE, "the highest legal row of each store is accepted")
	maps[0][0] = BuildingsScript.BUILDING_CAPACITY
	assert_equal(_buildings.section_1_local_refusal(maps[0], maps[1], maps[2]),
		BuildingsScript.COLUMN_REFUSE_ROW_RANGE, "one past the building capacity is not")
	maps[0][0] = BuildingsScript.ROOM_CAPACITY - 1
	assert_equal(_buildings.section_1_local_refusal(maps[0], maps[1], maps[2]),
		BuildingsScript.COLUMN_REFUSE_ROW_RANGE,
		"and a legal ROOM row is still illegal in the BUILDING grid")


func test_a_room_tile_run_and_its_furniture_cross_check_together() -> void:
	"""A room claims its saved run; an edge piece claims no floor tile and is not asked to."""
	var hall: Vector2i = _placed_hall()
	var tiles: PackedInt32Array = PackedInt32Array()
	for offset: int in 6:
		tiles.append(WorldInitScript.tile_index_of(60 + offset, 61))
	var room: BuildingsScript.OpResult = _buildings.designate_room(hall,
		BuildingsScript.ROOM_TYPE_PANTRY, tiles)
	assert_true(room.ok, "a pantry is designated: %s" % room.error)
	assert_equal(_buildings.section_1_cross_check_refusal(),
		BuildingsScript.COLUMN_REFUSE_NONE, "the room's run maps back tile for tile")
	var maps: Array[PackedInt32Array] = _building_columns()
	assert_true(_buildings.copy_section_1_columns_into(maps[0], maps[1], maps[2]), "capture")
	var claimed: int = 0
	for tile: int in BuildingsScript.TILE_COUNT:
		if maps[1][tile] != -1:
			claimed += 1
	assert_equal(claimed, 6, "exactly the six designated tiles are in the room grid")


# --- farming: absolute history that a load must not normalize away ------------------------------

func _tile_history() -> FarmingScript.SavedTileHistory:
	"""A carrier sized for `farming.copy_section_1_columns_into()`."""
	return FarmingScript.SavedTileHistory.new()


func test_the_farming_orchard_bound_mirrors_the_orchard_stores_own_capacity() -> void:
	"""`farming.gd` cannot preload `orchard_hive.gd` (that module preloads it), so this is the gate.

	R-WORLD-S1-001 §6 bounds an orchard row at 0..1023. The defining constant lives in the orchard
	store, and this equality is what stops the mirrored copy from drifting away from it.
	"""
	assert_equal(FarmingScript.ORCHARD_ROW_CAPACITY, OrchardHiveScript.ORCHARD_CAPACITY,
		"the mirrored orchard row capacity")
	assert_equal(OrchardHiveScript.ORCHARD_CAPACITY, 1024, "and the ruling's stated 0..1023")


func test_a_tile_with_no_live_plot_keeps_its_ripe_tick_and_tending() -> void:
	"""`destroy()` preserves history, so absence of a plot is not permission to zero it."""
	var plot: FarmingScript.OpResult = _farming.create_plot_at_tile(700, FarmingScript.SOIL_LOAM, 1)
	assert_true(plot.ok, "a plot is designated: %s" % plot.error)
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture with the plot live")
	assert_equal(history.active_plot_row[700], 0, "the tile names its plot row")
	assert_true(_farming.destroy(plot.ref).ok, "the designation is removed")
	assert_true(_farming.copy_section_1_columns_into(history), "capture after removal")
	assert_equal(history.active_plot_row[700], -1, "the inverse entry is cleared")
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_NONE,
		"and the retained history is still in domain")


func test_a_family_without_its_streak_is_refused_by_the_stores_own_predicate() -> void:
	"""READY_06 §7's pair rule, reached through `is_history_pair_consistent()` and not a copy."""
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture")
	history.last_family[3] = FarmingScript.FAMILY_LEGUME
	history.family_streak[3] = 0
	assert_equal(_farming.section_1_local_refusal(history),
		FarmingScript.COLUMN_REFUSE_HISTORY_PAIR, "a populated family with a zero streak refuses")
	history.family_streak[3] = 1
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_NONE,
		"and the same family with a count of one is accepted")


func test_each_tile_history_domain_is_bounded_where_the_ruling_says() -> void:
	"""Fertility, the growth remainder, the tending flag and both typed row columns."""
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture")
	history.fertility[0] = 10001
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_FERTILITY,
		"fertility stops at 10000")
	history.fertility[0] = 10000
	history.growth_remainder[0] = 1000000
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_REMAINDER,
		"the growth remainder is a modulo-1000000 residue")
	history.growth_remainder[0] = 999999
	history.tended_today[0] = 2
	assert_equal(_farming.section_1_local_refusal(history),
		FarmingScript.COLUMN_REFUSE_TENDED_FLAG, "the tending flag is 0 or 1")
	history.tended_today[0] = 1
	history.active_plot_row[0] = FarmingScript.FARM_PLOT_CAPACITY
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_PLOT_ROW,
		"a plot row stops at 4095")
	history.active_plot_row[0] = -1
	history.orchard_row[0] = FarmingScript.ORCHARD_ROW_CAPACITY
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_ORCHARD_ROW,
		"and an orchard row stops at 1023")


func test_a_negative_ripe_tick_below_the_null_is_refused_but_minus_one_is_not() -> void:
	"""-1 means "no ripe tick"; -2 is not a second null."""
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture")
	history.ripe_tick[9] = -1
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_NONE,
		"-1 is the declared absence")
	history.ripe_tick[9] = -2
	assert_equal(_farming.section_1_local_refusal(history), FarmingScript.COLUMN_REFUSE_RIPE_TICK,
		"and -2 is refused")


func test_the_plot_inverse_and_its_mirrors_cross_check_in_both_directions() -> void:
	"""Fertility and the rotation pair are written to plot and tile together, so they are equal."""
	var plot: FarmingScript.OpResult = _farming.create_plot_at_tile(300, FarmingScript.SOIL_LOAM, 1)
	assert_true(plot.ok, "a plot is designated: %s" % plot.error)
	assert_equal(_farming.section_1_cross_check_refusal(), FarmingScript.COLUMN_REFUSE_NONE,
		"the live inverse holds")
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture")
	history.fertility[300] = history.fertility[300] - 1
	assert_true(_farming.restore_section_1_columns(history), "the edited history installs")
	assert_equal(_farming.section_1_cross_check_refusal(), FarmingScript.COLUMN_REFUSE_MIRROR,
		"and the plot's mirrored fertility no longer agrees")


func test_a_live_plot_with_no_tile_entry_is_caught_by_the_reverse_walk() -> void:
	"""The direction a forward-only check misses."""
	assert_true(_farming.create_plot_at_tile(301, FarmingScript.SOIL_LOAM, 1).ok, "a plot exists")
	var history: FarmingScript.SavedTileHistory = _tile_history()
	assert_true(_farming.copy_section_1_columns_into(history), "capture")
	history.active_plot_row[301] = -1
	assert_true(_farming.restore_section_1_columns(history), "the edited history installs")
	assert_equal(_farming.section_1_cross_check_refusal(),
		FarmingScript.COLUMN_REFUSE_MISSING_INVERSE, "the live plot is unmapped")


# --- forage: heads, chains, cycles and the free list ---------------------------------------------

func _head_column() -> PackedInt32Array:
	"""A TILE_COUNT buffer for `forage.copy_section_1_columns_into()`."""
	var column: PackedInt32Array = PackedInt32Array()
	column.resize(ForageScript.TILE_COUNT)
	return column


func _zone_with_tiles(tiles: Array[int]) -> Vector2i:
	"""Create a FORAGE zone and link `tiles` to it in the order given, head-first as the store does."""
	var zone: ForageScript.OpResult = _forage.create_zone(ForageScript.ZONE_TYPE_FORAGE, 1, 0,
		false, false)
	if not zone.ok:
		fail("a zone must be created (error: %s)" % zone.error)
		return ForageScript.NULL_REF
	for tile: int in tiles:
		var linked: ForageScript.OpResult = _forage.add_tile(zone.ref, tile)
		if not linked.ok:
			fail("tile %d must link (error: %s)" % [tile, linked.error])
	return zone.ref


func test_the_head_column_captures_and_the_two_chain_directions_agree() -> void:
	"""Tile chains and zone chains must reach the same links, and `_link_used` of them."""
	var zone: Vector2i = _zone_with_tiles([10, 11, 12] as Array[int])
	assert_true(zone != ForageScript.NULL_REF, "the zone exists")
	var column: PackedInt32Array = _head_column()
	assert_true(_forage.copy_section_1_columns_into(column), "capture: %s" % _forage.section_1_detail())
	assert_equal(column[10], 0, "tile 10 heads the first link handed out")
	assert_equal(column[13], -1, "an unlinked tile carries NO_LINK")
	assert_equal(_forage.section_1_local_refusal(column), ForageScript.COLUMN_REFUSE_NONE,
		"the captured heads are in domain")
	assert_equal(_forage.section_1_cross_check_refusal(), ForageScript.COLUMN_REFUSE_NONE,
		"and both chain directions agree")


func test_two_tiles_of_one_zone_share_a_chain_the_walk_follows() -> void:
	"""A zone chain of two, reached from two different tile heads."""
	var zone: Vector2i = _zone_with_tiles([20, 21] as Array[int])
	assert_true(zone != ForageScript.NULL_REF, "the zone exists")
	var column: PackedInt32Array = _head_column()
	assert_true(_forage.copy_section_1_columns_into(column), "capture")
	assert_true(column[20] != column[21], "the two tiles hold different links")
	assert_equal(_forage.section_1_cross_check_refusal(), ForageScript.COLUMN_REFUSE_NONE,
		"and the zone chain holds exactly those two")


func test_a_head_pointing_at_a_freed_link_is_refused_not_walked() -> void:
	"""The free list threads through the SAME next column, so this is the confusion to catch."""
	var zone: Vector2i = _zone_with_tiles([30, 31] as Array[int])
	assert_true(zone != ForageScript.NULL_REF, "the zone exists")
	assert_true(_forage.remove_tile(zone, 31).ok, "one tile is unlinked, freeing its link")
	var column: PackedInt32Array = _head_column()
	assert_true(_forage.copy_section_1_columns_into(column), "capture")
	assert_equal(column[31], -1, "the unlinked tile holds NO_LINK")
	column[32] = 1
	assert_true(_forage.restore_section_1_columns(column), "a head of 1 is in domain")
	assert_equal(_forage.section_1_cross_check_refusal(), ForageScript.COLUMN_REFUSE_WRONG_TILE,
		"but link 1 is on the free list and records no tile")


func test_a_head_naming_a_link_never_handed_out_is_refused() -> void:
	"""Bounded by `_link_bump`, so an in-range but unallocated index is still refused."""
	var column: PackedInt32Array = _head_column()
	column.fill(-1)
	column[40] = ForageScript.ZONE_LINK_CAPACITY - 1
	assert_equal(_forage.section_1_local_refusal(column), ForageScript.COLUMN_REFUSE_NONE,
		"16383 is a legal arena index")
	assert_true(_forage.restore_section_1_columns(column), "and installs")
	assert_equal(_forage.section_1_cross_check_refusal(), ForageScript.COLUMN_REFUSE_UNALLOCATED,
		"but the arena has never handed it out")


func test_a_head_outside_the_arena_is_refused_by_the_local_domain() -> void:
	"""-1 or 0..16383, checked before publication."""
	var column: PackedInt32Array = _head_column()
	column.fill(-1)
	column[0] = ForageScript.ZONE_LINK_CAPACITY
	assert_equal(_forage.section_1_local_refusal(column), ForageScript.COLUMN_REFUSE_HEAD_RANGE,
		"16384 is out of the arena")


func test_saved_head_order_survives_a_restore_unchanged() -> void:
	"""The source inserts at the head, so sorting on load would change stored traversal order."""
	var zone: Vector2i = _zone_with_tiles([50, 51, 52] as Array[int])
	assert_true(zone != ForageScript.NULL_REF, "the zone exists")
	var before: PackedInt32Array = _head_column()
	assert_true(_forage.copy_section_1_columns_into(before), "capture")
	assert_true(_forage.restore_section_1_columns(before), "restore the very same heads")
	var after: PackedInt32Array = _head_column()
	assert_true(_forage.copy_section_1_columns_into(after), "capture again")
	assert_equal(_fingerprint(after), _fingerprint(before), "and nothing was reordered")


# --- spatial_world: stored legality, rebuilt derivation ------------------------------------------

func _cell_columns() -> Array:
	"""Four CELL_COUNT buffers for `spatial_world.copy_section_1_columns_into()`."""
	var walkable: PackedByteArray = PackedByteArray()
	var layer: PackedByteArray = PackedByteArray()
	var terrain: PackedInt32Array = PackedInt32Array()
	var height: PackedInt32Array = PackedInt32Array()
	walkable.resize(SpatialWorldScript.CELL_COUNT)
	layer.resize(SpatialWorldScript.CELL_COUNT)
	terrain.resize(SpatialWorldScript.CELL_COUNT)
	height.resize(SpatialWorldScript.CELL_COUNT)
	return [walkable, layer, terrain, height]


func test_a_legality_override_survives_the_round_trip_and_is_not_rebuilt_away() -> void:
	"""`rebuild_static_legality()` would restore the AUTHORED answer and discard the edit."""
	var cell: int = 0
	while cell < SpatialWorldScript.CELL_COUNT and not _spatial.is_walkable_cell(cell):
		cell += 1
	assert_true(cell < SpatialWorldScript.CELL_COUNT, "the authored map has a passable cell")
	assert_true(_spatial.override_static_legality(cell, false), "it is carved blocked")
	var revision: int = _spatial.current_map_revision()
	assert_true(revision > SpatialWorldScript.FIRST_MAP_REVISION, "the revision advanced")
	var columns: Array = _cell_columns()
	assert_true(_spatial.copy_section_1_columns_into(columns[0], columns[1], columns[2],
		columns[3]), "capture: %s" % _spatial.section_1_detail())
	assert_equal(columns[0][cell], 0, "the stored column carries the EDITED legality")
	var target: SpatialWorldScript = SpatialWorldScript.new()
	assert_true(target.is_walkable_cell(cell), "a fresh map has the authored legality")
	assert_true(target.restore_section_1_columns(revision, columns[0], columns[1], columns[2],
		columns[3]), "the restore lands: %s" % target.section_1_detail())
	assert_false(target.is_walkable_cell(cell), "and the edit survived the reload")
	assert_equal(target.current_map_revision(), revision, "with its revision")


func test_a_restore_rebuilds_the_walkable_count_and_the_clearance_column() -> void:
	"""Neither is persisted; both are derived, and the cross check is what proves they were run."""
	var columns: Array = _cell_columns()
	assert_true(_spatial.copy_section_1_columns_into(columns[0], columns[1], columns[2],
		columns[3]), "capture")
	var expected: int = _spatial.walkable_cell_count()
	var target: SpatialWorldScript = SpatialWorldScript.new()
	assert_true(target.restore_section_1_columns(SpatialWorldScript.FIRST_MAP_REVISION, columns[0],
		columns[1], columns[2], columns[3]), "the restore lands")
	assert_equal(target.walkable_cell_count(), expected, "the walkable count was recounted")
	assert_equal(target.section_1_cross_check_refusal(), SpatialWorldScript.COLUMN_REFUSE_NONE,
		"and clearance agrees with the installed legality, cell for cell")


func test_the_spatial_domains_are_the_baselines_and_the_revision_stays_i32() -> void:
	"""Revision 1..2147483647, walkable 0/1, layer exactly 0, terrain 0..3."""
	var columns: Array = _cell_columns()
	assert_true(_spatial.copy_section_1_columns_into(columns[0], columns[1], columns[2],
		columns[3]), "capture")
	assert_equal(_spatial.section_1_local_refusal(1, columns[0], columns[1], columns[2],
		columns[3]), SpatialWorldScript.COLUMN_REFUSE_NONE, "revision 1 is the first legal one")
	assert_equal(_spatial.section_1_local_refusal(0, columns[0], columns[1], columns[2],
		columns[3]), SpatialWorldScript.COLUMN_REFUSE_REVISION, "revision 0 is not")
	assert_equal(_spatial.section_1_local_refusal(2147483648, columns[0], columns[1], columns[2],
		columns[3]), SpatialWorldScript.COLUMN_REFUSE_REVISION,
		"and the domain is not silently widened past i32")
	var walkable: PackedByteArray = columns[0] as PackedByteArray
	walkable[5] = 2
	assert_equal(_spatial.section_1_local_refusal(1, walkable, columns[1], columns[2],
		columns[3]), SpatialWorldScript.COLUMN_REFUSE_WALKABLE_FLAG, "walkable is 0 or 1")
	walkable[5] = 1
	var layer: PackedByteArray = columns[1] as PackedByteArray
	layer[5] = 1
	assert_equal(_spatial.section_1_local_refusal(1, walkable, layer, columns[2], columns[3]),
		SpatialWorldScript.COLUMN_REFUSE_LAYER, "only the surface layer is contracted")


func test_every_cell_including_the_blocked_ones_is_represented() -> void:
	"""262144 cells, not a sparse list of the passable ones."""
	var columns: Array = _cell_columns()
	assert_true(_spatial.copy_section_1_columns_into(columns[0], columns[1], columns[2],
		columns[3]), "capture")
	assert_equal((columns[0] as PackedByteArray).size(), 262144, "_walkable is the whole grid")
	assert_equal((columns[3] as PackedInt32Array).size(), 262144, "and so is _height_units")
	var blocked: int = 0
	for cell: int in SpatialWorldScript.CELL_COUNT:
		if (columns[0] as PackedByteArray)[cell] == 0:
			blocked += 1
	assert_true(blocked > 0, "the authored estuary really does block cells")
	assert_equal(blocked + _spatial.walkable_cell_count(), 262144, "and they are all accounted for")


# --- weather: one aggregate row, two version namespaces, no RNG on restore ----------------------

func _weather_rows() -> Array:
	"""An eight-element i32 row and a two-element i64 row, at their declared extents."""
	var row: PackedInt32Array = PackedInt32Array()
	var row64: PackedInt64Array = PackedInt64Array()
	row.resize(WeatherScript.ROW_COLUMN_COUNT)
	row64.resize(WeatherScript.ROW64_COLUMN_COUNT)
	return [row, row64]


func test_the_temperature_and_rain_bounds_are_derived_and_equal_the_rulings() -> void:
	"""Walked out of §5.10's own tables, then checked against the numbers the ruling states."""
	assert_equal(WeatherScript.section_1_temperature_minimum(), RULING_TEMPERATURE_MIN,
		"the lowest reachable temperature")
	assert_equal(WeatherScript.section_1_temperature_maximum(), RULING_TEMPERATURE_MAX,
		"the highest reachable temperature")
	assert_equal(WeatherScript.section_1_rain_minimum(), RULING_RAIN_MIN, "the lowest rain")
	assert_equal(WeatherScript.section_1_rain_maximum(), RULING_RAIN_MAX, "the highest rain")


func test_every_present_event_tuple_must_be_the_compiled_one() -> void:
	"""§6's start days [6,6,6,10,6,6,6] and durations [3,2,4,2,3,2,3], event by event."""
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_NONE
	row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_NONE
	row64[0] = -1
	row64[1] = -1
	for event: int in WeatherScript.EVENT_COUNT:
		assert_equal(WeatherScript.EVENT_START_DAY[event], RULING_START_DAYS[event],
			"start day of event %d" % event)
		assert_equal(WeatherScript.EVENT_DURATION_DAYS[event], RULING_DURATIONS[event],
			"duration of event %d" % event)
		row[WeatherScript.COL_EVENT] = event
		row[WeatherScript.COL_START_DAY] = RULING_START_DAYS[event] + 1
		row[WeatherScript.COL_DURATION_DAYS] = RULING_DURATIONS[event]
		assert_equal(_weather.section_1_local_refusal(row, row64),
			WeatherScript.COLUMN_REFUSE_TUPLE, "a wrong start day for event %d refuses" % event)


func test_an_absent_tuple_is_exactly_minus_one_zero_zero() -> void:
	"""Not "close enough to empty": the absent tuple has one spelling."""
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_NONE
	row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_NONE
	row64[0] = -1
	row64[1] = -1
	assert_equal(_weather.section_1_local_refusal(row, row64), WeatherScript.COLUMN_REFUSE_NONE,
		"(-1,0,0) twice is the cleared row")
	row[WeatherScript.COL_START_DAY] = 6
	assert_equal(_weather.section_1_local_refusal(row, row64), WeatherScript.COLUMN_REFUSE_TUPLE,
		"an absent event with a start day refuses")


func test_a_present_event_needs_its_identity_and_that_season_must_admit_it() -> void:
	"""Hard freeze is a winter event; no other season's identity may carry it."""
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_HARD_FREEZE
	row[WeatherScript.COL_START_DAY] = WeatherScript.EVENT_START_DAY[WeatherScript.EVENT_HARD_FREEZE]
	row[WeatherScript.COL_DURATION_DAYS] = \
		WeatherScript.EVENT_DURATION_DAYS[WeatherScript.EVENT_HARD_FREEZE]
	row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_NONE
	row64[0] = WeatherScript.ABSOLUTE_SEASON_NONE
	row64[1] = WeatherScript.ABSOLUTE_SEASON_NONE
	assert_equal(_weather.section_1_local_refusal(row, row64),
		WeatherScript.COLUMN_REFUSE_MISSING_IDENTITY, "a present event with no identity refuses")
	row64[0] = 0
	assert_equal(_weather.section_1_local_refusal(row, row64),
		WeatherScript.COLUMN_REFUSE_NOT_ELIGIBLE, "absolute season 0 is a spring, not a winter")
	row64[0] = 3
	assert_equal(_weather.section_1_local_refusal(row, row64), WeatherScript.COLUMN_REFUSE_NONE,
		"absolute season 3 is a winter and admits it")


func test_an_expired_event_keeps_its_scheduled_identity_and_its_forecast() -> void:
	"""Never force the latch to -1 because the event is gone, and never erase a disclosed forecast."""
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_NONE
	row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_CALM_DAYS
	row[WeatherScript.COL_FORECAST_1] = WeatherScript.EVENT_START_DAY[WeatherScript.EVENT_CALM_DAYS]
	row[WeatherScript.COL_FORECAST_2] = \
		WeatherScript.EVENT_DURATION_DAYS[WeatherScript.EVENT_CALM_DAYS]
	row64[0] = 3
	row64[1] = 4
	assert_equal(_weather.section_1_local_refusal(row, row64), WeatherScript.COLUMN_REFUSE_NONE,
		"an expired event with a retained latch and a live forecast is valid")
	assert_true(_weather.restore_section_1_columns(row, row64), "it restores")
	assert_equal(_weather.scheduled_absolute_season(), 3, "the latch survived")
	assert_equal(_weather.forecast_absolute_season(), 4, "and so did the forecast's season")
	assert_false(_weather.is_event_scheduled(), "with no event running")


func test_a_restore_consumes_no_weather_draw() -> void:
	"""Routing a restore through the scheduler would consume a WEATHER roll and diverge the RNG."""
	var rng: RngScript = RngScript.new()
	rng.seed_world(20260914)
	var counted: IntMathScript.IntResult = rng.draw_count_of(RngScript.STREAM_WEATHER)
	assert_true(counted.ok, "the weather stream reports its draw count")
	var before: int = counted.value
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_NONE
	row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_NONE
	row64[0] = -1
	row64[1] = -1
	assert_true(_weather.restore_section_1_columns(row, row64), "the restore lands")
	assert_equal(rng.draw_count_of(RngScript.STREAM_WEATHER).value, before,
		"and drew nothing at all")


func test_the_cleared_fixture_is_reported_and_not_promoted() -> void:
	"""§4.3: zero-filled weather is not valid opening weather, but it IS a saveable state."""
	var rows: Array = _weather_rows()
	var row: PackedInt32Array = rows[0] as PackedInt32Array
	var row64: PackedInt64Array = rows[1] as PackedInt64Array
	assert_true(_weather.copy_section_1_columns_into(row, row64), "a fresh store captures")
	assert_true(_weather.section_1_is_cleared_fixture(row, row64),
		"and reports itself as the cleared fixture")
	assert_equal(_weather.section_1_local_refusal(row, row64), WeatherScript.COLUMN_REFUSE_NONE,
		"which still passes the local bounds, because it is real state")


func test_the_owner_wrapper_version_is_not_the_stores_snapshot_version() -> void:
	"""Two version namespaces the ruling forbids conflating: the wrapper is 1, the payload is 2."""
	assert_equal(WeatherScript.SECTION_1_OWNER_SCHEMA_VERSION, 1, "the §1 owner wrapper version")
	assert_equal(WeatherScript.SCHEMA_VERSION, 2, "the store's own snapshot-identity version")
	assert_equal(WeatherScript.SECTION_1_PRIMARY_COUNT, 1, "one aggregate weather row")


# --- world_init: the empty state, the published state and the seven basins ----------------------

func _generated_world() -> WorldInitScript:
	"""Generate the shipping estuary through the real transaction, or fail loudly."""
	var inventory: InventoryScript = InventoryScript.new()
	var items: ItemDefinitionsScript = ItemDefinitionsScript.new()
	if not items.load_default(inventory).ok:
		fail("the shipped item catalog must load")
		return null
	var opened: ResourceCatalogBinding.OpenResult = ResourceCatalogBinding.open(items)
	if not opened.ok:
		fail("the catalog binding must open (error: %s)" % opened.error)
		return null
	var world: WorldInitScript = WorldInitScript.new(_directory, _nodes, _forage,
		FishingScript.new(_directory, _forage, _jobs), RngScript.new(), _farming)
	var built: WorldInitScript.RequestResult = WorldInitScript.make_request(
		opened.boundary as ResourceCatalogBinding)
	if not built.ok:
		fail("the bound request must build (error: %s)" % built.error)
		return null
	var generated: WorldInitScript.GenerateResult = world.generate(built.request)
	if not generated.ok:
		fail("generation refused with %s" % generated.error)
		return null
	return world


func test_an_unpublished_map_must_be_the_sources_exact_reset_state() -> void:
	"""Land everywhere, soil 255, basin 255, cleared 0, seven null refs, seven zero dangers."""
	var world: WorldInitScript = WorldInitScript.new(_directory, _nodes, _forage,
		FishingScript.new(_directory, _forage, _jobs), RngScript.new(), _farming)
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	assert_true(world.copy_section_1_columns_into(state), "capture: %s" % world.section_1_detail())
	assert_false(world.section_1_is_published(), "nothing has been published")
	assert_equal(world.section_1_published_seed(), 0, "and the seed is zero")
	assert_equal(state.terrain[0], WorldInitScript.TERRAIN_LAND, "terrain resets to LAND")
	assert_equal(state.soil[0], WorldInitScript.SOIL_NONE, "soil resets to the 255 sentinel")
	assert_equal(state.basin[0], WorldInitScript.NO_BASIN, "basin resets to the 255 sentinel")
	assert_equal(world.section_1_local_refusal(0, 0, state), WorldInitScript.COLUMN_REFUSE_NONE,
		"the reset state validates as unpublished")
	state.cleared[9] = 1
	assert_equal(world.section_1_local_refusal(0, 0, state),
		WorldInitScript.COLUMN_REFUSE_NOT_EMPTY, "a half-built map behind that flag does not")


func test_the_two_sentinels_are_255_and_not_a_signed_minus_one() -> void:
	"""A signed conversion would turn both into -1 and then fail every domain test."""
	assert_equal(WorldInitScript.SOIL_NONE, 255, "no soil is byte 255")
	assert_equal(WorldInitScript.NO_BASIN, 255, "no basin is byte 255")
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	state.terrain.fill(WorldInitScript.TERRAIN_LAND)
	state.soil.fill(WorldInitScript.SOIL_NONE)
	state.basin.fill(WorldInitScript.NO_BASIN)
	state.basin_ref_slot.fill(-1)
	var world: WorldInitScript = WorldInitScript.new(_directory, _nodes, _forage,
		FishingScript.new(_directory, _forage, _jobs), RngScript.new(), _farming)
	assert_equal(world.section_1_local_refusal(0, 0, state), WorldInitScript.COLUMN_REFUSE_NONE,
		"255 is accepted in both columns")
	state.soil[3] = 3
	assert_equal(world.section_1_local_refusal(0, 0, state), WorldInitScript.COLUMN_REFUSE_SOIL,
		"but 3 is neither a soil id nor the sentinel")


func test_a_published_map_binds_seven_live_basins_of_the_right_kinds() -> void:
	"""Indices 0..3 are FORAGE zones and 4..6 are FISH, each agreeing with its stored danger band."""
	var world: WorldInitScript = _generated_world()
	assert_not_null(world, "the estuary generated")
	if world == null:
		return
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	assert_true(world.copy_section_1_columns_into(state), "capture: %s" % world.section_1_detail())
	assert_true(world.section_1_is_published(), "the map is published")
	assert_equal(world.section_1_local_refusal(1, world.section_1_published_seed(), state),
		WorldInitScript.COLUMN_REFUSE_NONE, "the published columns are in domain")
	assert_equal(world.section_1_cross_check_refusal(), WorldInitScript.COLUMN_REFUSE_NONE,
		"and every basin resolves to a live zone of the intended type")
	for index: int in WorldInitScript.BASIN_COUNT:
		assert_true(world.basin_ref_of(index) != EntityDirectory.NULL_REF,
			"basin %d is bound" % index)


func test_two_basins_naming_one_directory_slot_are_refused() -> void:
	"""Seven owners, seven zones; a duplicate would give one zone two masters."""
	var world: WorldInitScript = _generated_world()
	assert_not_null(world, "the estuary generated")
	if world == null:
		return
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	assert_true(world.copy_section_1_columns_into(state), "capture")
	state.basin_ref_slot[1] = state.basin_ref_slot[0]
	assert_equal(world.section_1_local_refusal(1, world.section_1_published_seed(), state),
		WorldInitScript.COLUMN_REFUSE_DUPLICATE_BASIN, "a duplicate slot refuses")


func test_a_half_null_basin_reference_is_refused_and_not_coerced_to_null() -> void:
	"""R-WORLD-S1-001 §5: reject a half-null reference; do not quietly complete it."""
	var world: WorldInitScript = _generated_world()
	assert_not_null(world, "the estuary generated")
	if world == null:
		return
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	assert_true(world.copy_section_1_columns_into(state), "capture")
	state.basin_ref_generation[2] = 0
	assert_equal(world.section_1_local_refusal(1, world.section_1_published_seed(), state),
		WorldInitScript.COLUMN_REFUSE_HALF_NULL_REF, "slot without generation refuses")
	assert_true(world.copy_section_1_columns_into(state), "recapture")
	state.basin_ref_slot[2] = -1
	assert_equal(world.section_1_local_refusal(1, world.section_1_published_seed(), state),
		WorldInitScript.COLUMN_REFUSE_HALF_NULL_REF, "and generation without a slot refuses too")


func test_a_published_map_may_not_leave_any_basin_unbound() -> void:
	"""All seven, because a tile basin index resolves through that table and only that table."""
	var world: WorldInitScript = _generated_world()
	assert_not_null(world, "the estuary generated")
	if world == null:
		return
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	assert_true(world.copy_section_1_columns_into(state), "capture")
	state.basin_ref_slot[6] = -1
	state.basin_ref_generation[6] = 0
	assert_equal(world.section_1_local_refusal(1, world.section_1_published_seed(), state),
		WorldInitScript.COLUMN_REFUSE_NULL_BASIN_REF, "a published map leaves no basin unbound")


func test_the_danger_band_domain_is_zero_to_three() -> void:
	"""§5.5's bands; band 0 needs a staffed lookout a fresh world does not have."""
	var world: WorldInitScript = WorldInitScript.new(_directory, _nodes, _forage,
		FishingScript.new(_directory, _forage, _jobs), RngScript.new(), _farming)
	var state: WorldInitScript.SavedMap = WorldInitScript.SavedMap.new()
	state.terrain.fill(WorldInitScript.TERRAIN_LAND)
	state.soil.fill(WorldInitScript.SOIL_NONE)
	state.basin.fill(WorldInitScript.NO_BASIN)
	state.basin_ref_slot.fill(-1)
	state.basin_danger[4] = 4
	assert_equal(world.section_1_local_refusal(0, 0, state), WorldInitScript.COLUMN_REFUSE_DANGER,
		"danger band 4 refuses")
	state.basin_danger[4] = -1
	assert_equal(world.section_1_local_refusal(0, 0, state), WorldInitScript.COLUMN_REFUSE_DANGER,
		"and so does -1")
