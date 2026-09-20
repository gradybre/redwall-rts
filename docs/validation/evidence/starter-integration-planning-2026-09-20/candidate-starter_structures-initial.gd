extends RefCounted
## CANDIDATE for godot/scripts/core/starter_structures.gd -- INIT-C-PREP-R01v1.
##
## Compact, deterministic preparation of the exact GDD §5.9 starter refuge: seven buildings, the
## four dormitory/kitchen/common/pantry rooms and their 80 interior tiles, 31 floor furniture
## instances, 8 undirected partition/door edges, every candidate access tile, the three-part
## south exit and the bed allocation order. This is one INIT-C dependency, per
## docs/planning/starter_structures_preparation_contract.md and decision 0184. It creates or
## mutates NO Buildings/EntityDirectory/SpatialWorld/Inventory/Navigation/Movement/settlement
## owner, publishes no live EntityRefs, and asserts nothing about body fit, room validity, heat,
## exterior reachability or a real measured service contact. Tile connectivity here is authored
## data only.
##
## SOURCE PINS. Every id used below is read through `Catalog`'s protected/compiled dictionaries
## and `BuildingDefinitions`' immutable fact tables and named field constants -- never hand
## numbered as a row ordinal, and never obtained by instantiating BuildingDefinitions (its facts
## are script-level consts, readable without `.new()`). `_validate_source_metadata()` checks
## every dictionary with `has()`/`typeof()` before any indexing, and runs before any
## source-derived expected value is constructed.
##
## THE Plan. Exactly ten `PackedInt32Array` payloads, column-major (`column * row_count + row`),
## sized and documented by the named constants below, totalling 2480 logical bytes (under the
## 2560 byte cap). `Plan._init()` is the only allocation site; every entry starts at -1 except
## the header, which starts at 0. One staged Plan plus one caller Plan is the whole footprint of
## a `prepare_into()` call.
##
## TRANSACTIONAL OUTPUT. `prepare_into(out)` validates source metadata, builds ONE internal
## staged Plan, validates it with `plan_refusal()`, and publishes all ten arrays into `out` only
## on success. A refusal leaves `out` untouched -- callers MUST inspect the returned bool. There
## is no validity flag and no serial/generation on Plan; repeated successful preparation is
## byte-identical, which a serial would break.
##
## REFUSAL ORDER. Shape is checked before any indexing; scalar/range/type/footprint ownership is
## checked before any graph work; invalid indices never reach array access. The final
## STARTER_AUTHORED_LAYOUT gate compares every remaining value against the frozen fixture only
## after every structural gate above it has independently passed, so a malformed plan is caught
## by its own gate rather than by exact-match alone.

const Catalog := preload("res://scripts/core/catalog.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")

# --- refusal codes, in the contract's exact order -------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_PLAN_NULL: StringName = &"STARTER_PLAN_NULL"
const REFUSE_SOURCE_METADATA: StringName = &"STARTER_SOURCE_METADATA"
const REFUSE_PLAN_SHAPE: StringName = &"STARTER_PLAN_SHAPE"
const REFUSE_BUILDING_LAYOUT: StringName = &"STARTER_BUILDING_LAYOUT"
const REFUSE_ROOM_LAYOUT: StringName = &"STARTER_ROOM_LAYOUT"
const REFUSE_FURNITURE_LAYOUT: StringName = &"STARTER_FURNITURE_LAYOUT"
const REFUSE_EDGE_LAYOUT: StringName = &"STARTER_EDGE_LAYOUT"
const REFUSE_EXIT_INTERIOR: StringName = &"STARTER_EXIT_INTERIOR"
const REFUSE_EXIT_WALL: StringName = &"STARTER_EXIT_WALL"
const REFUSE_EXIT_EXTERIOR: StringName = &"STARTER_EXIT_EXTERIOR"
const REFUSE_WALK_DISCONNECTED: StringName = &"STARTER_WALK_DISCONNECTED"
const REFUSE_ACCESS_CANDIDATES: StringName = &"STARTER_ACCESS_CANDIDATES"
const REFUSE_AUTHORED_LAYOUT: StringName = &"STARTER_AUTHORED_LAYOUT"

# --- exterior tile grid geometry, GDD §5.1/§5.9 -----------------------------------------------

const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128

## Hall interior origin is exterior origin + (1,1) (GDD §5.9).
const INTERIOR_INSET_TILES: int = 1
const INTERIOR_WIDTH: int = 10
const INTERIOR_HEIGHT: int = 8
const INTERIOR_TILE_COUNT: int = INTERIOR_WIDTH * INTERIOR_HEIGHT

const HALL_KEY: String = "hall"
const OPEN_STOCKPILE_KEY: String = "open_stockpile"
const WELL_KEY: String = "well"
const WORKBENCH_KEY: String = "workbench"

const BED_KEY: String = "bed"
const SEAT_KEY: String = "seat"
const SHELF_KEY: String = "shelf"
const KITCHEN_BENCH_KEY: String = "kitchen_bench"
const HEARTH_KEY: String = "hearth"
const INTERIOR_PARTITION_KEY: String = "interior_partition"
const INTERIOR_DOOR_KEY: String = "interior_door"

const ROOM_DORMITORY_KEY: String = "DORMITORY"
const ROOM_KITCHEN_KEY: String = "KITCHEN"
const ROOM_COMMON_KEY: String = "COMMON"
const ROOM_PANTRY_KEY: String = "PANTRY"
const BUILDING_STATE_ACTIVE_KEY: String = "ACTIVE"

const MIN_TIER: int = 1


class Plan:
	extends RefCounted
	## The exact ten packed integer arrays of one authored starter-refuge preparation.
	##
	## No live refs, no room-valid flags, no measured contact objects and no save-schema fields
	## live here. Column-major: `array[column * row_count + row]`. Every array is allocated once
	## in `_init()`; nothing here is ever resized afterwards.

	# buildings: type_id, global_origin_tile, rotation, tier, desired_state, footprint_x,
	# footprint_z, required_unlock -- 8 columns x 7 rows = 224 bytes.
	const BUILDING_COL_TYPE_ID: int = 0
	const BUILDING_COL_GLOBAL_ORIGIN_TILE: int = 1
	const BUILDING_COL_ROTATION: int = 2
	const BUILDING_COL_TIER: int = 3
	const BUILDING_COL_DESIRED_STATE: int = 4
	const BUILDING_COL_FOOTPRINT_X: int = 5
	const BUILDING_COL_FOOTPRINT_Z: int = 6
	const BUILDING_COL_REQUIRED_UNLOCK: int = 7
	const BUILDING_COLUMN_COUNT: int = 8
	const BUILDING_ROW_COUNT: int = 7

	# rooms: room_type_id, tile_offset, tile_count -- 3 columns x 4 rows = 48 bytes.
	const ROOM_COL_TYPE_ID: int = 0
	const ROOM_COL_TILE_OFFSET: int = 1
	const ROOM_COL_TILE_COUNT: int = 2
	const ROOM_COLUMN_COUNT: int = 3
	const ROOM_ROW_COUNT: int = 4

	# room_tiles: global_tile -- 1 column x 80 rows = 320 bytes.
	const ROOM_TILES_COLUMN_COUNT: int = 1
	const ROOM_TILES_ROW_COUNT: int = 80

	# furniture: type_id, room_ordinal, origin_local, rotation, footprint_offset,
	# footprint_count, candidate_offset, candidate_count -- 8 columns x 31 rows = 992 bytes.
	const FURNITURE_COL_TYPE_ID: int = 0
	const FURNITURE_COL_ROOM_ORDINAL: int = 1
	const FURNITURE_COL_ORIGIN_LOCAL: int = 2
	const FURNITURE_COL_ROTATION: int = 3
	const FURNITURE_COL_FOOTPRINT_OFFSET: int = 4
	const FURNITURE_COL_FOOTPRINT_COUNT: int = 5
	const FURNITURE_COL_CANDIDATE_OFFSET: int = 6
	const FURNITURE_COL_CANDIDATE_COUNT: int = 7
	const FURNITURE_COLUMN_COUNT: int = 8
	const FURNITURE_ROW_COUNT: int = 31

	# footprints: local_tile -- 1 column x 33 rows = 132 bytes.
	const FOOTPRINTS_COLUMN_COUNT: int = 1
	const FOOTPRINTS_ROW_COUNT: int = 33

	# candidate_access_tiles: local_tile -- 1 column x 132 rows = 528 bytes.
	const CANDIDATE_COLUMN_COUNT: int = 1
	const CANDIDATE_ROW_COUNT: int = 132
	const CANDIDATE_USED_COUNT: int = 51

	# edges: local_tile_a, local_tile_b, kind_id, room_ordinal_a, room_ordinal_b --
	# 5 columns x 8 rows = 160 bytes.
	const EDGE_COL_TILE_A: int = 0
	const EDGE_COL_TILE_B: int = 1
	const EDGE_COL_KIND_ID: int = 2
	const EDGE_COL_ROOM_A: int = 3
	const EDGE_COL_ROOM_B: int = 4
	const EDGE_COLUMN_COUNT: int = 5
	const EDGE_ROW_COUNT: int = 8

	# exit_tiles: interior_local, wall_band_global, exterior_global -- 3 columns x 1 row = 12 bytes.
	const EXIT_COL_INTERIOR: int = 0
	const EXIT_COL_WALL: int = 1
	const EXIT_COL_EXTERIOR: int = 2
	const EXIT_COLUMN_COUNT: int = 3
	const EXIT_ROW_COUNT: int = 1

	# bed_furniture_ordinals: furniture_ordinal -- 1 column x 12 rows = 48 bytes.
	const BED_COLUMN_COUNT: int = 1
	const BED_ROW_COUNT: int = 12

	# header: version, candidate_used, footprint_used, walk_tile_count -- 4 columns x 1 row = 16 bytes.
	const HEADER_COL_VERSION: int = 0
	const HEADER_COL_CANDIDATE_USED: int = 1
	const HEADER_COL_FOOTPRINT_USED: int = 2
	const HEADER_COL_WALK_TILE_COUNT: int = 3
	const HEADER_COLUMN_COUNT: int = 4
	const HEADER_ROW_COUNT: int = 1

	const PLAN_VERSION: int = 1
	const PLAN_TOTAL_BYTES: int = 2480
	const PLAN_BYTE_CAP: int = 2560
	const NO_VALUE: int = -1

	var buildings: PackedInt32Array = PackedInt32Array()
	var rooms: PackedInt32Array = PackedInt32Array()
	var room_tiles: PackedInt32Array = PackedInt32Array()
	var furniture: PackedInt32Array = PackedInt32Array()
	var footprints: PackedInt32Array = PackedInt32Array()
	var candidate_access_tiles: PackedInt32Array = PackedInt32Array()
	var edges: PackedInt32Array = PackedInt32Array()
	var exit_tiles: PackedInt32Array = PackedInt32Array()
	var bed_furniture_ordinals: PackedInt32Array = PackedInt32Array()
	var header: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate every array once and fill it with -1, then zero the header."""
		buildings.resize(BUILDING_COLUMN_COUNT * BUILDING_ROW_COUNT)
		buildings.fill(NO_VALUE)
		rooms.resize(ROOM_COLUMN_COUNT * ROOM_ROW_COUNT)
		rooms.fill(NO_VALUE)
		room_tiles.resize(ROOM_TILES_COLUMN_COUNT * ROOM_TILES_ROW_COUNT)
		room_tiles.fill(NO_VALUE)
		furniture.resize(FURNITURE_COLUMN_COUNT * FURNITURE_ROW_COUNT)
		furniture.fill(NO_VALUE)
		footprints.resize(FOOTPRINTS_COLUMN_COUNT * FOOTPRINTS_ROW_COUNT)
		footprints.fill(NO_VALUE)
		candidate_access_tiles.resize(CANDIDATE_COLUMN_COUNT * CANDIDATE_ROW_COUNT)
		candidate_access_tiles.fill(NO_VALUE)
		edges.resize(EDGE_COLUMN_COUNT * EDGE_ROW_COUNT)
		edges.fill(NO_VALUE)
		exit_tiles.resize(EXIT_COLUMN_COUNT * EXIT_ROW_COUNT)
		exit_tiles.fill(NO_VALUE)
		bed_furniture_ordinals.resize(BED_COLUMN_COUNT * BED_ROW_COUNT)
		bed_furniture_ordinals.fill(NO_VALUE)
		header.resize(HEADER_COLUMN_COUNT * HEADER_ROW_COUNT)
		header.fill(0)

	func total_logical_bytes() -> int:
		"""The fixed 2480-byte logical payload size, for tests to assert against."""
		return PLAN_TOTAL_BYTES

	# --- column-major field accessors ---------------------------------------------------------

	func building_field(row: int, column: int) -> int:
		return buildings[column * BUILDING_ROW_COUNT + row]

	func set_building_field(row: int, column: int, value: int) -> void:
		buildings[column * BUILDING_ROW_COUNT + row] = value

	func room_field(row: int, column: int) -> int:
		return rooms[column * ROOM_ROW_COUNT + row]

	func set_room_field(row: int, column: int, value: int) -> void:
		rooms[column * ROOM_ROW_COUNT + row] = value

	func furniture_field(row: int, column: int) -> int:
		return furniture[column * FURNITURE_ROW_COUNT + row]

	func set_furniture_field(row: int, column: int, value: int) -> void:
		furniture[column * FURNITURE_ROW_COUNT + row] = value

	func edge_field(row: int, column: int) -> int:
		return edges[column * EDGE_ROW_COUNT + row]

	func set_edge_field(row: int, column: int, value: int) -> void:
		edges[column * EDGE_ROW_COUNT + row] = value

	func exit_field(column: int) -> int:
		return exit_tiles[column * EXIT_ROW_COUNT]

	func set_exit_field(column: int, value: int) -> void:
		exit_tiles[column * EXIT_ROW_COUNT] = value

	func header_field(column: int) -> int:
		return header[column * HEADER_ROW_COUNT]

	func set_header_field(column: int, value: int) -> void:
		header[column * HEADER_ROW_COUNT] = value


# --- producer instance state ---------------------------------------------------------------

var _last_refusal: StringName = REFUSE_NONE


func last_refusal() -> StringName:
	"""The refusal code of the most recent `prepare_into()` call, or REFUSE_NONE on success.

	Belongs to this producer instance, never to Plan: Plan carries no validity flag.
	"""
	return _last_refusal


func prepare_into(out: Plan) -> bool:
	"""Build the exact authored starter-refuge plan into `out`, or refuse without touching it.

	Source validation, then staged-plan validation, then publish -- only on full success. A
	refused call leaves `out` byte-for-byte as it was; the caller MUST inspect the returned
	bool and `last_refusal()`. Repeated successful preparation always produces an identical
	payload; there is no serial to protect a caller that ignores the return value, and none is
	added.
	"""
	if out == null:
		_last_refusal = REFUSE_PLAN_NULL
		return false
	var metadata_refusal: StringName = _validate_source_metadata()
	if metadata_refusal != REFUSE_NONE:
		_last_refusal = metadata_refusal
		return false
	var staged: Plan = Plan.new()
	_fill_authored_plan(staged)
	var staged_refusal: StringName = plan_refusal(staged)
	if staged_refusal != REFUSE_NONE:
		_last_refusal = staged_refusal
		return false
	_publish(staged, out)
	_last_refusal = REFUSE_NONE
	return true


func _publish(staged: Plan, out: Plan) -> void:
	"""Overwrite every one of `out`'s ten arrays with `staged`'s, completely and atomically
	relative to the caller: this runs only after `staged` has already passed `plan_refusal()`.
	"""
	out.buildings = staged.buildings.duplicate()
	out.rooms = staged.rooms.duplicate()
	out.room_tiles = staged.room_tiles.duplicate()
	out.furniture = staged.furniture.duplicate()
	out.footprints = staged.footprints.duplicate()
	out.candidate_access_tiles = staged.candidate_access_tiles.duplicate()
	out.edges = staged.edges.duplicate()
	out.exit_tiles = staged.exit_tiles.duplicate()
	out.bed_furniture_ordinals = staged.bed_furniture_ordinals.duplicate()
	out.header = staged.header.duplicate()


# --- source metadata validation (Catalog / BuildingDefinitions only, no instantiation) -------

func _validate_source_metadata() -> StringName:
	"""Confirm every compiled id, protected ordinal and immutable fact this plan depends on
	exists with the expected shape, using only `has()`/`typeof()` checks before any indexing.
	Never instantiates BuildingDefinitions; its fact tables and field constants are read as
	script-level consts.
	"""
	for key: String in [HALL_KEY, OPEN_STOCKPILE_KEY, WELL_KEY, WORKBENCH_KEY]:
		if not Catalog.BUILDING_DEFINITION.has(key):
			return REFUSE_SOURCE_METADATA
		if typeof(Catalog.BUILDING_DEFINITION[key]) != TYPE_INT:
			return REFUSE_SOURCE_METADATA
	for key: String in [BED_KEY, SEAT_KEY, SHELF_KEY, KITCHEN_BENCH_KEY, HEARTH_KEY,
			INTERIOR_PARTITION_KEY, INTERIOR_DOOR_KEY]:
		if not Catalog.FURNITURE_DEFINITION.has(key):
			return REFUSE_SOURCE_METADATA
		if typeof(Catalog.FURNITURE_DEFINITION[key]) != TYPE_INT:
			return REFUSE_SOURCE_METADATA
	for key: String in [ROOM_DORMITORY_KEY, ROOM_KITCHEN_KEY, ROOM_COMMON_KEY, ROOM_PANTRY_KEY]:
		if not Catalog.ROOM_TYPE.has(key):
			return REFUSE_SOURCE_METADATA
		if typeof(Catalog.ROOM_TYPE[key]) != TYPE_INT:
			return REFUSE_SOURCE_METADATA
	if not Catalog.BUILDING_STATE.has(BUILDING_STATE_ACTIVE_KEY):
		return REFUSE_SOURCE_METADATA
	if typeof(Catalog.BUILDING_STATE[BUILDING_STATE_ACTIVE_KEY]) != TYPE_INT:
		return REFUSE_SOURCE_METADATA
	var building_footprints: Dictionary = {
		HALL_KEY: [12, 10], OPEN_STOCKPILE_KEY: [4, 4], WELL_KEY: [2, 2], WORKBENCH_KEY: [3, 3],
	}
	for key: String in building_footprints.keys():
		if not BuildingDefinitions.BUILDING_FACTS.has(key):
			return REFUSE_SOURCE_METADATA
		var row: Array = BuildingDefinitions.BUILDING_FACTS[key]
		if row.size() != BuildingDefinitions.B_FIELD_COUNT:
			return REFUSE_SOURCE_METADATA
		var expected: Array = building_footprints[key]
		if int(row[BuildingDefinitions.B_FOOTPRINT_X]) != int(expected[0]):
			return REFUSE_SOURCE_METADATA
		if int(row[BuildingDefinitions.B_FOOTPRINT_Z]) != int(expected[1]):
			return REFUSE_SOURCE_METADATA
		if int(row[BuildingDefinitions.B_UNLOCK]) != 0:
			return REFUSE_SOURCE_METADATA
	for key: String in [BED_KEY, SEAT_KEY, SHELF_KEY, KITCHEN_BENCH_KEY, HEARTH_KEY,
			INTERIOR_PARTITION_KEY, INTERIOR_DOOR_KEY]:
		if not BuildingDefinitions.FURNITURE_FACTS.has(key):
			return REFUSE_SOURCE_METADATA
		var frow: Array = BuildingDefinitions.FURNITURE_FACTS[key]
		if frow.size() != BuildingDefinitions.F_FIELD_COUNT:
			return REFUSE_SOURCE_METADATA
	if BuildingDefinitions.BUILDING_DEFINITION_COUNT <= 0:
		return REFUSE_SOURCE_METADATA
	if BuildingDefinitions.FURNITURE_DEFINITION_COUNT <= 0:
		return REFUSE_SOURCE_METADATA
	return REFUSE_NONE


static func _catalog_int(dict: Dictionary, key: String) -> int:
	"""A safe int lookup: -1 (never a valid id here) when absent or of the wrong type."""
	if not dict.has(key):
		return -1
	if typeof(dict[key]) != TYPE_INT:
		return -1
	return int(dict[key])


# --- interior local <-> exterior global tile conversion ---------------------------------------

static func _local_to_global(local_tile: int, hall_origin_tile: int) -> int:
	"""Convert one interior-local tile (0..79, `z_local*10+x_local`) to its exterior global tile,
	using the hall's own origin (interior origin = exterior origin + (1,1), GDD §5.9)."""
	var hall_x: int = hall_origin_tile % MAP_TILES_X
	var hall_z: int = hall_origin_tile / MAP_TILES_X
	var interior_origin_x: int = hall_x + INTERIOR_INSET_TILES
	var interior_origin_z: int = hall_z + INTERIOR_INSET_TILES
	var lx: int = local_tile % INTERIOR_WIDTH
	var lz: int = local_tile / INTERIOR_WIDTH
	return (interior_origin_z + lz) * MAP_TILES_X + (interior_origin_x + lx)


static func _global_to_local(global_tile: int, hall_origin_tile: int) -> int:
	"""Inverse of `_local_to_global()`; returns -1 when the global tile is outside the interior."""
	var hall_x: int = hall_origin_tile % MAP_TILES_X
	var hall_z: int = hall_origin_tile / MAP_TILES_X
	var interior_origin_x: int = hall_x + INTERIOR_INSET_TILES
	var interior_origin_z: int = hall_z + INTERIOR_INSET_TILES
	var gx: int = global_tile % MAP_TILES_X
	var gz: int = global_tile / MAP_TILES_X
	var lx: int = gx - interior_origin_x
	var lz: int = gz - interior_origin_z
	if lx < 0 or lx >= INTERIOR_WIDTH or lz < 0 or lz >= INTERIOR_HEIGHT:
		return -1
	return lz * INTERIOR_WIDTH + lx


# --- authored data tables (interior-local space unless noted) ---------------------------------

const BUILD_KEYS: Array[String] = [
	HALL_KEY, OPEN_STOCKPILE_KEY, OPEN_STOCKPILE_KEY, OPEN_STOCKPILE_KEY, OPEN_STOCKPILE_KEY,
	WELL_KEY, WORKBENCH_KEY,
]
const BUILD_ORIGIN_X: Array[int] = [58, 50, 50, 70, 70, 64, 58]
const BUILD_ORIGIN_Z: Array[int] = [59, 60, 65, 60, 65, 54, 54]

const ROOM_KEYS: Array[String] = [ROOM_DORMITORY_KEY, ROOM_KITCHEN_KEY, ROOM_COMMON_KEY, ROOM_PANTRY_KEY]
const ROOM_TILE_COUNTS: Array[int] = [40, 10, 25, 5]
const ROOM_TILE_OFFSETS: Array[int] = [0, 40, 50, 75]
## Inclusive local (min_x, max_x, min_z, max_z) per room ordinal.
const ROOM_LOCAL_BOUNDS: Array = [
	[0, 4, 0, 7], [5, 9, 0, 1], [5, 9, 2, 6], [5, 9, 7, 7],
]

## [symbol_key, origin_local, room_ordinal, footprint_local(Array[int]), candidates_local(Array[int])]
const FURNITURE_ENTRIES: Array = [
	[BED_KEY, 0, 0, [0], [10]],
	[BED_KEY, 1, 0, [1], [11]],
	[BED_KEY, 2, 0, [2], [12]],
	[BED_KEY, 3, 0, [3], [4, 13]],
	[KITCHEN_BENCH_KEY, 6, 1, [6, 7], [5, 16, 17]],
	[HEARTH_KEY, 8, 1, [8, 9], [18]],
	[SHELF_KEY, 19, 1, [19], [18]],
	[BED_KEY, 20, 0, [20], [10, 30]],
	[BED_KEY, 21, 0, [21], [11, 31]],
	[BED_KEY, 22, 0, [22], [12, 32]],
	[BED_KEY, 23, 0, [23], [13, 24, 33]],
	[SEAT_KEY, 26, 2, [26], [16, 25, 36]],
	[SEAT_KEY, 27, 2, [27], [17, 37]],
	[SEAT_KEY, 28, 2, [28], [18, 38]],
	[SEAT_KEY, 29, 2, [29], [39]],
	[BED_KEY, 40, 0, [40], [30, 50]],
	[BED_KEY, 41, 0, [41], [31, 51]],
	[BED_KEY, 42, 0, [42], [32, 52]],
	[BED_KEY, 43, 0, [43], [33, 44, 53]],
	[SEAT_KEY, 46, 2, [46], [36, 45]],
	[SEAT_KEY, 47, 2, [47], [37]],
	[SEAT_KEY, 48, 2, [48], [38]],
	[SEAT_KEY, 49, 2, [49], [39]],
	[SEAT_KEY, 56, 2, [56], [55, 66]],
	[SEAT_KEY, 57, 2, [57], [67]],
	[SEAT_KEY, 58, 2, [58], [68]],
	[SEAT_KEY, 59, 2, [59], [69]],
	[SHELF_KEY, 76, 3, [76], [66, 75]],
	[SHELF_KEY, 77, 3, [77], [67]],
	[SHELF_KEY, 78, 3, [78], [68]],
	[SHELF_KEY, 79, 3, [79], [69]],
]

## [local_a, local_b, kind_key, room_ordinal_a, room_ordinal_b], sorted ascending by local_a.
const EDGE_ENTRIES: Array = [
	[4, 5, INTERIOR_PARTITION_KEY, 0, 1],
	[14, 15, INTERIOR_PARTITION_KEY, 0, 1],
	[24, 25, INTERIOR_PARTITION_KEY, 0, 2],
	[34, 35, INTERIOR_PARTITION_KEY, 0, 2],
	[44, 45, INTERIOR_DOOR_KEY, 0, 2],
	[54, 55, INTERIOR_PARTITION_KEY, 0, 2],
	[64, 65, INTERIOR_PARTITION_KEY, 0, 2],
	[74, 75, INTERIOR_PARTITION_KEY, 0, 3],
]

const EXIT_INTERIOR_LOCAL: int = 75
const EXIT_WALL_GLOBAL: int = 68 * MAP_TILES_X + 64
const EXIT_EXTERIOR_GLOBAL: int = 69 * MAP_TILES_X + 64


# --- authored plan construction ----------------------------------------------------------------

func _fill_authored_plan(plan: Plan) -> void:
	"""Fill every array of `plan` with the exact GDD §5.9 starter geometry."""
	var active_state: int = _catalog_int(Catalog.BUILDING_STATE, BUILDING_STATE_ACTIVE_KEY)
	var hall_origin_tile: int = -1
	for row: int in Plan.BUILDING_ROW_COUNT:
		var key: String = BUILD_KEYS[row]
		var type_id: int = _catalog_int(Catalog.BUILDING_DEFINITION, key)
		var origin_tile: int = BUILD_ORIGIN_Z[row] * MAP_TILES_X + BUILD_ORIGIN_X[row]
		if key == HALL_KEY:
			hall_origin_tile = origin_tile
		var facts: Array = BuildingDefinitions.BUILDING_FACTS[key]
		plan.set_building_field(row, Plan.BUILDING_COL_TYPE_ID, type_id)
		plan.set_building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE, origin_tile)
		plan.set_building_field(row, Plan.BUILDING_COL_ROTATION, 0)
		plan.set_building_field(row, Plan.BUILDING_COL_TIER, MIN_TIER)
		plan.set_building_field(row, Plan.BUILDING_COL_DESIRED_STATE, active_state)
		plan.set_building_field(row, Plan.BUILDING_COL_FOOTPRINT_X, int(facts[BuildingDefinitions.B_FOOTPRINT_X]))
		plan.set_building_field(row, Plan.BUILDING_COL_FOOTPRINT_Z, int(facts[BuildingDefinitions.B_FOOTPRINT_Z]))
		plan.set_building_field(row, Plan.BUILDING_COL_REQUIRED_UNLOCK, int(facts[BuildingDefinitions.B_UNLOCK]))

	for room_ordinal: int in Plan.ROOM_ROW_COUNT:
		var room_type_id: int = _catalog_int(Catalog.ROOM_TYPE, ROOM_KEYS[room_ordinal])
		plan.set_room_field(room_ordinal, Plan.ROOM_COL_TYPE_ID, room_type_id)
		plan.set_room_field(room_ordinal, Plan.ROOM_COL_TILE_OFFSET, ROOM_TILE_OFFSETS[room_ordinal])
		plan.set_room_field(room_ordinal, Plan.ROOM_COL_TILE_COUNT, ROOM_TILE_COUNTS[room_ordinal])
		var bounds: Array = ROOM_LOCAL_BOUNDS[room_ordinal]
		var write_index: int = ROOM_TILE_OFFSETS[room_ordinal]
		for z: int in range(int(bounds[2]), int(bounds[3]) + 1):
			for x: int in range(int(bounds[0]), int(bounds[1]) + 1):
				var local_tile: int = z * INTERIOR_WIDTH + x
				plan.room_tiles[write_index] = _local_to_global(local_tile, hall_origin_tile)
				write_index += 1

	var footprint_write: int = 0
	var candidate_write: int = 0
	var bed_ordinal_index: int = 0
	for furniture_row: int in Plan.FURNITURE_ROW_COUNT:
		var entry: Array = FURNITURE_ENTRIES[furniture_row]
		var symbol_key: String = String(entry[0])
		var origin_local: int = int(entry[1])
		var room_ordinal: int = int(entry[2])
		var footprint_locals: Array = entry[3]
		var candidate_locals: Array = entry[4]
		var type_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, symbol_key)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_TYPE_ID, type_id)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_ROOM_ORDINAL, room_ordinal)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_ORIGIN_LOCAL, origin_local)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_ROTATION, 0)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_FOOTPRINT_OFFSET, footprint_write)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_FOOTPRINT_COUNT, footprint_locals.size())
		for tile: int in footprint_locals:
			plan.footprints[footprint_write] = int(tile)
			footprint_write += 1
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_CANDIDATE_OFFSET, candidate_write)
		plan.set_furniture_field(furniture_row, Plan.FURNITURE_COL_CANDIDATE_COUNT, candidate_locals.size())
		for tile: int in candidate_locals:
			plan.candidate_access_tiles[candidate_write] = int(tile)
			candidate_write += 1
		if symbol_key == BED_KEY:
			plan.bed_furniture_ordinals[bed_ordinal_index] = furniture_row
			bed_ordinal_index += 1

	for edge_row: int in Plan.EDGE_ROW_COUNT:
		var edge: Array = EDGE_ENTRIES[edge_row]
		var kind_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, String(edge[2]))
		plan.set_edge_field(edge_row, Plan.EDGE_COL_TILE_A, int(edge[0]))
		plan.set_edge_field(edge_row, Plan.EDGE_COL_TILE_B, int(edge[1]))
		plan.set_edge_field(edge_row, Plan.EDGE_COL_KIND_ID, kind_id)
		plan.set_edge_field(edge_row, Plan.EDGE_COL_ROOM_A, int(edge[3]))
		plan.set_edge_field(edge_row, Plan.EDGE_COL_ROOM_B, int(edge[4]))

	plan.set_exit_field(Plan.EXIT_COL_INTERIOR, EXIT_INTERIOR_LOCAL)
	plan.set_exit_field(Plan.EXIT_COL_WALL, EXIT_WALL_GLOBAL)
	plan.set_exit_field(Plan.EXIT_COL_EXTERIOR, EXIT_EXTERIOR_GLOBAL)

	var occupied: Dictionary = {}
	for value: int in plan.footprints:
		occupied[value] = true
	plan.set_header_field(Plan.HEADER_COL_VERSION, Plan.PLAN_VERSION)
	plan.set_header_field(Plan.HEADER_COL_CANDIDATE_USED, candidate_write)
	plan.set_header_field(Plan.HEADER_COL_FOOTPRINT_USED, footprint_write)
	plan.set_header_field(Plan.HEADER_COL_WALK_TILE_COUNT, INTERIOR_TILE_COUNT - occupied.size())


# --- pure, read-only fixed-plan validator -------------------------------------------------------

static func plan_refusal(plan: Plan) -> StringName:
	"""Validate a complete Plan against every structural rule and, finally, the exact authored
	fixture. Never repairs; never mutates `plan`. Checks shape and ranges before any indexed
	access, and independently re-derives room/edge/exit/adjacency structure from `plan`'s own
	arrays before the final exact-match gate.
	"""
	if plan == null:
		return REFUSE_PLAN_NULL
	if not _shape_ok(plan):
		return REFUSE_PLAN_SHAPE
	var building_refusal: StringName = _check_building_layout(plan)
	if building_refusal != REFUSE_NONE:
		return building_refusal
	var room_refusal: StringName = _check_room_layout(plan)
	if room_refusal != REFUSE_NONE:
		return room_refusal
	var furniture_refusal: StringName = _check_furniture_layout(plan)
	if furniture_refusal != REFUSE_NONE:
		return furniture_refusal
	var edge_refusal: StringName = _check_edge_layout(plan)
	if edge_refusal != REFUSE_NONE:
		return edge_refusal
	var hall_origin_tile: int = _find_hall_origin(plan)
	var exit_refusal: StringName = _check_exit(plan, hall_origin_tile)
	if exit_refusal != REFUSE_NONE:
		return exit_refusal
	var occupied: Dictionary = _occupied_locals(plan)
	if not _flood_reachable(plan, occupied):
		return REFUSE_WALK_DISCONNECTED
	var candidate_refusal: StringName = _check_access_candidates(plan, occupied)
	if candidate_refusal != REFUSE_NONE:
		return candidate_refusal
	if not _matches_authored_fixture(plan):
		return REFUSE_AUTHORED_LAYOUT
	return REFUSE_NONE


static func _shape_ok(plan: Plan) -> bool:
	"""True when every one of the ten arrays has exactly its contracted size."""
	if plan.buildings.size() != Plan.BUILDING_COLUMN_COUNT * Plan.BUILDING_ROW_COUNT:
		return false
	if plan.rooms.size() != Plan.ROOM_COLUMN_COUNT * Plan.ROOM_ROW_COUNT:
		return false
	if plan.room_tiles.size() != Plan.ROOM_TILES_COLUMN_COUNT * Plan.ROOM_TILES_ROW_COUNT:
		return false
	if plan.furniture.size() != Plan.FURNITURE_COLUMN_COUNT * Plan.FURNITURE_ROW_COUNT:
		return false
	if plan.footprints.size() != Plan.FOOTPRINTS_COLUMN_COUNT * Plan.FOOTPRINTS_ROW_COUNT:
		return false
	if plan.candidate_access_tiles.size() != Plan.CANDIDATE_COLUMN_COUNT * Plan.CANDIDATE_ROW_COUNT:
		return false
	if plan.edges.size() != Plan.EDGE_COLUMN_COUNT * Plan.EDGE_ROW_COUNT:
		return false
	if plan.exit_tiles.size() != Plan.EXIT_COLUMN_COUNT * Plan.EXIT_ROW_COUNT:
		return false
	if plan.bed_furniture_ordinals.size() != Plan.BED_COLUMN_COUNT * Plan.BED_ROW_COUNT:
		return false
	if plan.header.size() != Plan.HEADER_COLUMN_COUNT * Plan.HEADER_ROW_COUNT:
		return false
	return true


static func _building_extent(footprint_x: int, footprint_z: int, rotation: int) -> Vector2i:
	"""Footprint extent after a 90-degree-step rotation: swapped on an odd rotation."""
	if rotation % 2 == 0:
		return Vector2i(footprint_x, footprint_z)
	return Vector2i(footprint_z, footprint_x)


static func _check_building_layout(plan: Plan) -> StringName:
	"""Range/type checks on every building row, then pairwise footprint disjointness."""
	var rects: Array = []
	for row: int in Plan.BUILDING_ROW_COUNT:
		var type_id: int = plan.building_field(row, Plan.BUILDING_COL_TYPE_ID)
		var origin_tile: int = plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
		var rotation: int = plan.building_field(row, Plan.BUILDING_COL_ROTATION)
		var tier: int = plan.building_field(row, Plan.BUILDING_COL_TIER)
		var desired_state: int = plan.building_field(row, Plan.BUILDING_COL_DESIRED_STATE)
		var footprint_x: int = plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_X)
		var footprint_z: int = plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_Z)
		var required_unlock: int = plan.building_field(row, Plan.BUILDING_COL_REQUIRED_UNLOCK)
		if type_id < 0 or type_id >= BuildingDefinitions.BUILDING_DEFINITION_COUNT:
			return REFUSE_BUILDING_LAYOUT
		if origin_tile < 0 or origin_tile >= MAP_TILES_X * MAP_TILES_Z:
			return REFUSE_BUILDING_LAYOUT
		if rotation < 0 or rotation > 3:
			return REFUSE_BUILDING_LAYOUT
		if tier < MIN_TIER:
			return REFUSE_BUILDING_LAYOUT
		if desired_state < 0 or desired_state >= Catalog.BUILDING_STATE.size():
			return REFUSE_BUILDING_LAYOUT
		if footprint_x <= 0 or footprint_z <= 0:
			return REFUSE_BUILDING_LAYOUT
		if required_unlock < 0 or required_unlock >= Catalog.MILESTONE.size():
			return REFUSE_BUILDING_LAYOUT
		var extent: Vector2i = _building_extent(footprint_x, footprint_z, rotation)
		var min_x: int = origin_tile % MAP_TILES_X
		var min_z: int = origin_tile / MAP_TILES_X
		var max_x: int = min_x + extent.x
		var max_z: int = min_z + extent.y
		if max_x > MAP_TILES_X or max_z > MAP_TILES_Z:
			return REFUSE_BUILDING_LAYOUT
		rects.append([min_x, min_z, max_x, max_z])
	for a: int in rects.size():
		for b in range(a + 1, rects.size()):
			var ra: Array = rects[a]
			var rb: Array = rects[b]
			var overlap_x: bool = int(ra[0]) < int(rb[2]) and int(rb[0]) < int(ra[2])
			var overlap_z: bool = int(ra[1]) < int(rb[3]) and int(rb[1]) < int(ra[3])
			if overlap_x and overlap_z:
				return REFUSE_BUILDING_LAYOUT
	return REFUSE_NONE


static func _find_hall_origin(plan: Plan) -> int:
	"""The building row's global origin tile whose footprint is 12x10 (the hall), or -1."""
	for row: int in Plan.BUILDING_ROW_COUNT:
		if plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_X) == 12 \
				and plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_Z) == 10:
			return plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
	return -1


static func _check_room_layout(plan: Plan) -> StringName:
	"""Room ordinals own a contiguous, gapless, nonoverlapping partition of all 80 tiles."""
	var seen_types: Dictionary = {}
	var expected_offset: int = 0
	for room_ordinal: int in Plan.ROOM_ROW_COUNT:
		var room_type_id: int = plan.room_field(room_ordinal, Plan.ROOM_COL_TYPE_ID)
		var tile_offset: int = plan.room_field(room_ordinal, Plan.ROOM_COL_TILE_OFFSET)
		var tile_count: int = plan.room_field(room_ordinal, Plan.ROOM_COL_TILE_COUNT)
		if room_type_id < 0 or room_type_id >= Catalog.ROOM_TYPE.size():
			return REFUSE_ROOM_LAYOUT
		if seen_types.has(room_type_id):
			return REFUSE_ROOM_LAYOUT
		seen_types[room_type_id] = true
		if tile_count <= 0 or tile_offset != expected_offset:
			return REFUSE_ROOM_LAYOUT
		if tile_offset + tile_count > Plan.ROOM_TILES_ROW_COUNT:
			return REFUSE_ROOM_LAYOUT
		expected_offset += tile_count
	if expected_offset != Plan.ROOM_TILES_ROW_COUNT:
		return REFUSE_ROOM_LAYOUT
	var seen_tiles: Dictionary = {}
	for tile: int in plan.room_tiles:
		if tile < 0 or tile >= MAP_TILES_X * MAP_TILES_Z:
			return REFUSE_ROOM_LAYOUT
		if seen_tiles.has(tile):
			return REFUSE_ROOM_LAYOUT
		seen_tiles[tile] = true
	return REFUSE_NONE


static func _check_furniture_layout(plan: Plan) -> StringName:
	"""Range/ownership checks, footprint arena bounds and global footprint-tile uniqueness."""
	var footprint_used: int = plan.header_field(Plan.HEADER_COL_FOOTPRINT_USED)
	if footprint_used != Plan.FOOTPRINTS_ROW_COUNT:
		return REFUSE_FURNITURE_LAYOUT
	var seen_footprint_tiles: Dictionary = {}
	var candidate_used: int = plan.header_field(Plan.HEADER_COL_CANDIDATE_USED)
	var accounted_candidates: int = 0
	for row: int in Plan.FURNITURE_ROW_COUNT:
		var type_id: int = plan.furniture_field(row, Plan.FURNITURE_COL_TYPE_ID)
		var room_ordinal: int = plan.furniture_field(row, Plan.FURNITURE_COL_ROOM_ORDINAL)
		var origin_local: int = plan.furniture_field(row, Plan.FURNITURE_COL_ORIGIN_LOCAL)
		var rotation: int = plan.furniture_field(row, Plan.FURNITURE_COL_ROTATION)
		var footprint_offset: int = plan.furniture_field(row, Plan.FURNITURE_COL_FOOTPRINT_OFFSET)
		var footprint_count: int = plan.furniture_field(row, Plan.FURNITURE_COL_FOOTPRINT_COUNT)
		var candidate_offset: int = plan.furniture_field(row, Plan.FURNITURE_COL_CANDIDATE_OFFSET)
		var candidate_count: int = plan.furniture_field(row, Plan.FURNITURE_COL_CANDIDATE_COUNT)
		if type_id < 0 or type_id >= BuildingDefinitions.FURNITURE_DEFINITION_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		if room_ordinal < 0 or room_ordinal >= Plan.ROOM_ROW_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		if origin_local < 0 or origin_local >= INTERIOR_TILE_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		if rotation < 0 or rotation > 3:
			return REFUSE_FURNITURE_LAYOUT
		if footprint_count <= 0 or footprint_offset < 0 \
				or footprint_offset + footprint_count > Plan.FOOTPRINTS_ROW_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		if candidate_count <= 0 or candidate_offset < 0 \
				or candidate_offset + candidate_count > Plan.CANDIDATE_ROW_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		accounted_candidates += candidate_count
		for index: int in footprint_count:
			var tile: int = plan.footprints[footprint_offset + index]
			if tile < 0 or tile >= INTERIOR_TILE_COUNT:
				return REFUSE_FURNITURE_LAYOUT
			if seen_footprint_tiles.has(tile):
				return REFUSE_FURNITURE_LAYOUT
			seen_footprint_tiles[tile] = true
	if seen_footprint_tiles.size() != Plan.FOOTPRINTS_ROW_COUNT:
		return REFUSE_FURNITURE_LAYOUT
	if accounted_candidates != candidate_used:
		return REFUSE_FURNITURE_LAYOUT
	for tail_index in range(candidate_used, Plan.CANDIDATE_ROW_COUNT):
		if plan.candidate_access_tiles[tail_index] != Plan.NO_VALUE:
			return REFUSE_FURNITURE_LAYOUT
	var seen_bed_ordinals: Dictionary = {}
	var bed_type_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, BED_KEY)
	for bed_index: int in Plan.BED_ROW_COUNT:
		var ordinal: int = plan.bed_furniture_ordinals[bed_index]
		if ordinal < 0 or ordinal >= Plan.FURNITURE_ROW_COUNT:
			return REFUSE_FURNITURE_LAYOUT
		if seen_bed_ordinals.has(ordinal):
			return REFUSE_FURNITURE_LAYOUT
		seen_bed_ordinals[ordinal] = true
		if plan.furniture_field(ordinal, Plan.FURNITURE_COL_TYPE_ID) != bed_type_id:
			return REFUSE_FURNITURE_LAYOUT
	return REFUSE_NONE


static func _check_edge_layout(plan: Plan) -> StringName:
	"""Every edge names two distinct adjacent local tiles, a known kind, two distinct rooms,
	and the rows are sorted ascending by their first tile."""
	var door_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, INTERIOR_DOOR_KEY)
	var partition_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, INTERIOR_PARTITION_KEY)
	var previous_a: int = -1
	var door_count: int = 0
	for row: int in Plan.EDGE_ROW_COUNT:
		var tile_a: int = plan.edge_field(row, Plan.EDGE_COL_TILE_A)
		var tile_b: int = plan.edge_field(row, Plan.EDGE_COL_TILE_B)
		var kind_id: int = plan.edge_field(row, Plan.EDGE_COL_KIND_ID)
		var room_a: int = plan.edge_field(row, Plan.EDGE_COL_ROOM_A)
		var room_b: int = plan.edge_field(row, Plan.EDGE_COL_ROOM_B)
		if tile_a < 0 or tile_a >= INTERIOR_TILE_COUNT or tile_b < 0 or tile_b >= INTERIOR_TILE_COUNT:
			return REFUSE_EDGE_LAYOUT
		if tile_a >= tile_b or tile_a <= previous_a:
			return REFUSE_EDGE_LAYOUT
		var horizontal: bool = tile_b == tile_a + 1 and tile_a / INTERIOR_WIDTH == tile_b / INTERIOR_WIDTH
		var vertical: bool = tile_b == tile_a + INTERIOR_WIDTH
		if not (horizontal or vertical):
			return REFUSE_EDGE_LAYOUT
		if kind_id != door_id and kind_id != partition_id:
			return REFUSE_EDGE_LAYOUT
		if kind_id == door_id:
			door_count += 1
		if room_a < 0 or room_a >= Plan.ROOM_ROW_COUNT or room_b < 0 or room_b >= Plan.ROOM_ROW_COUNT:
			return REFUSE_EDGE_LAYOUT
		if room_a == room_b:
			return REFUSE_EDGE_LAYOUT
		previous_a = tile_a
	if door_count != 1:
		return REFUSE_EDGE_LAYOUT
	return REFUSE_NONE


static func _check_exit(plan: Plan, hall_origin_tile: int) -> StringName:
	"""Interior/wall/exterior exit gates, checked in that order with distinct refusal codes."""
	var interior_local: int = plan.exit_field(Plan.EXIT_COL_INTERIOR)
	var wall_global: int = plan.exit_field(Plan.EXIT_COL_WALL)
	var exterior_global: int = plan.exit_field(Plan.EXIT_COL_EXTERIOR)
	if hall_origin_tile < 0:
		return REFUSE_EXIT_INTERIOR
	if interior_local < 0 or interior_local >= INTERIOR_TILE_COUNT:
		return REFUSE_EXIT_INTERIOR
	if not _local_owned_by_some_room(plan, interior_local):
		return REFUSE_EXIT_INTERIOR
	var occupied: Dictionary = _occupied_locals(plan)
	if occupied.has(interior_local):
		return REFUSE_EXIT_INTERIOR
	var interior_global: int = _local_to_global(interior_local, hall_origin_tile)
	if not _orthogonally_adjacent_global(interior_global, wall_global):
		return REFUSE_EXIT_WALL
	if _global_to_local(wall_global, hall_origin_tile) != -1:
		return REFUSE_EXIT_WALL
	if not _inside_building_footprint(plan, wall_global, hall_origin_tile):
		return REFUSE_EXIT_WALL
	if not _orthogonally_adjacent_global(wall_global, exterior_global):
		return REFUSE_EXIT_EXTERIOR
	if _inside_any_building_footprint(plan, exterior_global):
		return REFUSE_EXIT_EXTERIOR
	return REFUSE_NONE


static func _local_owned_by_some_room(plan: Plan, local_tile: int) -> bool:
	"""True when `local_tile` falls within one of the four rooms' declared local bounds."""
	var lx: int = local_tile % INTERIOR_WIDTH
	var lz: int = local_tile / INTERIOR_WIDTH
	for bounds: Array in ROOM_LOCAL_BOUNDS:
		if lx >= int(bounds[0]) and lx <= int(bounds[1]) and lz >= int(bounds[2]) and lz <= int(bounds[3]):
			return true
	return false


static func _orthogonally_adjacent_global(a: int, b: int) -> bool:
	"""True when two global tiles are exactly one step apart on the exterior grid."""
	var ax: int = a % MAP_TILES_X
	var az: int = a / MAP_TILES_X
	var bx: int = b % MAP_TILES_X
	var bz: int = b / MAP_TILES_X
	var dx: int = absi(ax - bx)
	var dz: int = absi(az - bz)
	return (dx == 1 and dz == 0) or (dx == 0 and dz == 1)


static func _inside_building_footprint(plan: Plan, global_tile: int, origin_tile: int) -> bool:
	"""True when `global_tile` lies inside the building whose origin tile is `origin_tile`."""
	for row: int in Plan.BUILDING_ROW_COUNT:
		if plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE) != origin_tile:
			continue
		var footprint_x: int = plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_X)
		var footprint_z: int = plan.building_field(row, Plan.BUILDING_COL_FOOTPRINT_Z)
		var rotation: int = plan.building_field(row, Plan.BUILDING_COL_ROTATION)
		var extent: Vector2i = _building_extent(footprint_x, footprint_z, rotation)
		var min_x: int = origin_tile % MAP_TILES_X
		var min_z: int = origin_tile / MAP_TILES_X
		var gx: int = global_tile % MAP_TILES_X
		var gz: int = global_tile / MAP_TILES_X
		return gx >= min_x and gx < min_x + extent.x and gz >= min_z and gz < min_z + extent.y
	return false


static func _inside_any_building_footprint(plan: Plan, global_tile: int) -> bool:
	"""True when `global_tile` lies inside ANY of the seven authored building footprints."""
	for row: int in Plan.BUILDING_ROW_COUNT:
		var origin_tile: int = plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
		if _inside_building_footprint(plan, global_tile, origin_tile):
			return true
	return false


static func _occupied_locals(plan: Plan) -> Dictionary:
	"""The set of interior-local tiles any furniture footprint occupies."""
	var occupied: Dictionary = {}
	for tile: int in plan.footprints:
		if tile >= 0:
			occupied[tile] = true
	return occupied


static func _local_neighbors(local_tile: int) -> Array[int]:
	"""The up-to-four orthogonal in-bounds neighbors of one interior-local tile."""
	var neighbors: Array[int] = []
	var lx: int = local_tile % INTERIOR_WIDTH
	var lz: int = local_tile / INTERIOR_WIDTH
	if lx > 0:
		neighbors.append(local_tile - 1)
	if lx < INTERIOR_WIDTH - 1:
		neighbors.append(local_tile + 1)
	if lz > 0:
		neighbors.append(local_tile - INTERIOR_WIDTH)
	if lz < INTERIOR_HEIGHT - 1:
		neighbors.append(local_tile + INTERIOR_WIDTH)
	return neighbors


static func _edge_blocks(plan: Plan, a: int, b: int) -> bool:
	"""True when a solid (non-door) authored edge separates local tiles `a` and `b`."""
	var door_id: int = _catalog_int(Catalog.FURNITURE_DEFINITION, INTERIOR_DOOR_KEY)
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	for row: int in Plan.EDGE_ROW_COUNT:
		if plan.edge_field(row, Plan.EDGE_COL_TILE_A) == low \
				and plan.edge_field(row, Plan.EDGE_COL_TILE_B) == high:
			return plan.edge_field(row, Plan.EDGE_COL_KIND_ID) != door_id
	return false


static func _flood_reachable(plan: Plan, occupied: Dictionary) -> bool:
	"""True when every non-occupied interior-local tile is reachable from the exit's interior
	tile by four-neighbor movement, honoring the authored solid partition edges."""
	var start: int = plan.exit_field(Plan.EXIT_COL_INTERIOR)
	if start < 0 or start >= INTERIOR_TILE_COUNT or occupied.has(start):
		return false
	var visited: Dictionary = {}
	var frontier: Array[int] = [start]
	visited[start] = true
	while not frontier.is_empty():
		var current: int = frontier.pop_back()
		for neighbor: int in _local_neighbors(current):
			if occupied.has(neighbor) or visited.has(neighbor):
				continue
			if _edge_blocks(plan, current, neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	var declared_walk_count: int = plan.header_field(Plan.HEADER_COL_WALK_TILE_COUNT)
	var expected_walk_count: int = INTERIOR_TILE_COUNT - occupied.size()
	if declared_walk_count != expected_walk_count:
		return false
	return visited.size() == expected_walk_count


static func _check_access_candidates(plan: Plan, occupied: Dictionary) -> StringName:
	"""Every used candidate tile is a real, unblocked, walkable orthogonal neighbor of a
	footprint tile of its own furniture instance."""
	for row: int in Plan.FURNITURE_ROW_COUNT:
		var footprint_offset: int = plan.furniture_field(row, Plan.FURNITURE_COL_FOOTPRINT_OFFSET)
		var footprint_count: int = plan.furniture_field(row, Plan.FURNITURE_COL_FOOTPRINT_COUNT)
		var candidate_offset: int = plan.furniture_field(row, Plan.FURNITURE_COL_CANDIDATE_OFFSET)
		var candidate_count: int = plan.furniture_field(row, Plan.FURNITURE_COL_CANDIDATE_COUNT)
		var footprint_tiles: Array[int] = []
		for index: int in footprint_count:
			footprint_tiles.append(plan.footprints[footprint_offset + index])
		for index: int in candidate_count:
			var candidate: int = plan.candidate_access_tiles[candidate_offset + index]
			if candidate < 0 or candidate >= INTERIOR_TILE_COUNT:
				return REFUSE_ACCESS_CANDIDATES
			if occupied.has(candidate):
				return REFUSE_ACCESS_CANDIDATES
			var reaches_footprint: bool = false
			for footprint_tile: int in footprint_tiles:
				if _local_neighbors(footprint_tile).has(candidate) \
						and not _edge_blocks(plan, footprint_tile, candidate):
					reaches_footprint = true
					break
			if not reaches_footprint:
				return REFUSE_ACCESS_CANDIDATES
	return REFUSE_NONE


static func _matches_authored_fixture(plan: Plan) -> bool:
	"""Final gate: compare every array against a freshly built authored reference plan."""
	var reference: Plan = Plan.new()
	var producer: StarterStructures = StarterStructures.new()
	producer._fill_authored_plan(reference)
	if plan.buildings != reference.buildings:
		return false
	if plan.rooms != reference.rooms:
		return false
	if plan.room_tiles != reference.room_tiles:
		return false
	if plan.furniture != reference.furniture:
		return false
	if plan.footprints != reference.footprints:
		return false
	if plan.candidate_access_tiles != reference.candidate_access_tiles:
		return false
	if plan.edges != reference.edges:
		return false
	if plan.exit_tiles != reference.exit_tiles:
		return false
	if plan.bed_furniture_ordinals != reference.bed_furniture_ordinals:
		return false
	if plan.header != reference.header:
		return false
	return true
