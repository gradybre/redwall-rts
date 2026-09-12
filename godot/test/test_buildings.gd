extends "res://test/framework/test_case.gd"
## Coverage for the packed Building/Room/Furniture stores and R-BUILD-DOM-003's presence mask.
##
## THE STARTER FIXTURE IS GDD §5.9's OWN DIAGRAM, transcribed here and not read out of any
## module. §5.9: "place the hall at (58,59) ... all rotation 0. Hall interior origin is exterior
## origin+(1,1)", with the 10x8 interior
##
##     BBBB..KKHH      row 0    B=bed  K=kitchen bench  H=hearth
##     .........S      row 1    S=shelf  T=seat  .=walk
##     BBBB..TTTT      row 2
##     ..........      row 3
##     BBBB..TTTT      row 4
##     ......TTTT      row 5
##     ..........      row 6
##     ......SSSS      row 7
##
## and its four rooms: "The left 5 columns form a 40-tile dormitory with 12 beds; the right 5
## columns form kitchen on rows 0-1 (10 tiles), common room on rows 2-6 (25 tiles), and pantry on
## row 7 (5 tiles)." 40+10+25+5 = 80, which is §4.1's `room_tiles` for the hall.
##
## The expected mask values are R-BUILD-DOM-003's own acceptance vectors: empty=0,
## bed+hearth+shelf=261, kitchen_bench+hearth+shelf=292, all nine=511. The starter kitchen is
## exactly the 292 case, because §5.9 puts a bench, a hearth and the fifth shelf in it.

const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Milestones := preload("res://scripts/core/milestones.gd")

## §5.9's authored hall placement, and the interior origin it derives.
const HALL_ORIGIN_X: int = 58
const HALL_ORIGIN_Z: int = 59
const INTERIOR_ORIGIN_X: int = 59
const INTERIOR_ORIGIN_Z: int = 60
const INTERIOR_WIDTH: int = 10
const INTERIOR_DEPTH: int = 8

## R-BUILD-DOM-003's acceptance vectors, written as sums of the published bit values.
const MASK_EMPTY: int = 0
const MASK_BED_HEARTH_SHELF: int = 261
const MASK_BENCH_HEARTH_SHELF: int = 292
const MASK_ALL_NINE: int = 511

## R-BUILD-DOM-004: "4 x 50000 = 200000 g".
const PANTRY_CAPACITY_G: int = 200000

## The starter world's milestone mask: M0 earned and nothing else (GDD §5.11).
const START_MASK: int = 1

var _store: Buildings = null
var _hall: Vector2i = Vector2i(-1, 0)
var _dormitory: Vector2i = Vector2i(-1, 0)
var _kitchen: Vector2i = Vector2i(-1, 0)
var _common: Vector2i = Vector2i(-1, 0)
var _pantry: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""A fresh store per test. Each test that needs the starter hall builds it explicitly."""
	_store = Buildings.new()
	_hall = Vector2i(-1, 0)
	_dormitory = Vector2i(-1, 0)
	_kitchen = Vector2i(-1, 0)
	_common = Vector2i(-1, 0)
	_pantry = Vector2i(-1, 0)


func _building_id(key: String) -> int:
	"""The compiled BuildingDefinition id of one key."""
	return int(CatalogScript.BUILDING_DEFINITION[key])


func _furniture_id(key: String) -> int:
	"""The compiled FurnitureDefinition id of one key."""
	return int(CatalogScript.FURNITURE_DEFINITION[key])


func _room_type(key: String) -> int:
	"""The protected §4.3 RoomType ordinal of one key."""
	return int(CatalogScript.ROOM_TYPE[key])


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's exterior tile index, `z*128+x`, computed here and not asked of the store."""
	return z * 128 + x


func _interior_tile(ix: int, iz: int) -> int:
	"""One interior cell of the starter hall, in §5.9's zero-based interior coordinates."""
	return _tile(INTERIOR_ORIGIN_X + ix, INTERIOR_ORIGIN_Z + iz)


func _rect_tiles(min_ix: int, min_iz: int, max_ix: int, max_iz: int) -> PackedInt32Array:
	"""Every interior tile of an inclusive rectangle, ascending."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for iz: int in range(min_iz, max_iz + 1):
		for ix: int in range(min_ix, max_ix + 1):
			tiles.append(_interior_tile(ix, iz))
	return tiles


func _place_hall() -> void:
	"""Place §5.9's starter hall at (58,59), rotation 0, on a world that has earned only M0."""
	var placed: Buildings.OpResult = _store.place_building(
		_building_id("hall"), _tile(HALL_ORIGIN_X, HALL_ORIGIN_Z), 0, START_MASK)
	assert_true(placed.ok, "the hall must place at the authored origin (%s)" % placed.error)
	_hall = placed.ref


func _designate_starter_rooms() -> void:
	"""§5.9's four rooms: dormitory 40, kitchen 10, common 25, pantry 5. Total 80."""
	_dormitory = _designate("DORMITORY", _rect_tiles(0, 0, 4, 7))
	_kitchen = _designate("KITCHEN", _rect_tiles(5, 0, 9, 1))
	_common = _designate("COMMON", _rect_tiles(5, 2, 9, 6))
	_pantry = _designate("PANTRY", _rect_tiles(5, 7, 9, 7))


func _designate(type_key: String, tiles: PackedInt32Array) -> Vector2i:
	"""Designate one room of the hall and assert it published."""
	var room: Buildings.OpResult = _store.designate_room(_hall, _room_type(type_key), tiles)
	assert_true(room.ok, "the %s must designate (%s)" % [type_key, room.error])
	return room.ref


func _furnish_starter() -> void:
	"""Place §5.9's diagram: 12 beds, one bench, one hearth, twelve seats, five shelves."""
	for iz: int in [0, 2, 4]:
		for ix: int in range(0, 4):
			_place(_dormitory, "bed", _interior_tile(ix, iz))
	_place(_kitchen, "kitchen_bench", _interior_tile(6, 0))
	_place(_kitchen, "hearth", _interior_tile(8, 0))
	_place(_kitchen, "shelf", _interior_tile(9, 1))
	for iz: int in [2, 4, 5]:
		for ix: int in range(6, 10):
			_place(_common, "seat", _interior_tile(ix, iz))
	for ix: int in range(6, 10):
		_place(_pantry, "shelf", _interior_tile(ix, 7))


func _place(room: Vector2i, key: String, tile: int) -> Vector2i:
	"""Place one furniture instance and assert it published."""
	var result: Buildings.OpResult = _store.place_furniture(room, _furniture_id(key), tile, 0)
	assert_true(result.ok, "'%s' must place at tile %d (%s)" % [key, tile, result.error])
	return result.ref


func _validate_starter_rooms() -> void:
	"""Mark the four authored rooms valid; §5.9's topology half is not this store's to decide."""
	for room: Vector2i in [_dormitory, _kitchen, _common, _pantry]:
		assert_true(_store.set_room_valid(room, true).ok, "a live room accepts its validity")


func _starter_world() -> void:
	"""The whole §5.9 starter interior: hall, four rooms, all furniture, all rooms valid."""
	_place_hall()
	_designate_starter_rooms()
	_furnish_starter()
	_validate_starter_rooms()


# --- capacities and construction ------------------------------------------------------------------

func test_the_column_lengths_are_the_specified_capacities() -> void:
	"""GDD §4.2's "At most 1024 exterior structures" and architecture §2.2's 16384 / 81920."""
	assert_equal(Buildings.BUILDING_CAPACITY, 1024, "1024 Building rows")
	assert_equal(Buildings.ROOM_CAPACITY, 16384, "16384 Room rows")
	assert_equal(Buildings.FURNITURE_CAPACITY, 81920, "81920 Furniture rows")
	assert_equal(Buildings.MAX_ROOMS_PER_BUILDING, 16, "up to 16 rooms per managed building")
	assert_equal(Buildings.ROOM_TILE_LINK_CAPACITY, 16384, "16384 RoomTileLinks entries")
	assert_equal(Buildings.TILE_COUNT, 16384, "a 128x128 exterior grid")
	assert_equal(_store.live_building_count(), 0, "a new store is empty")
	assert_equal(_store.live_room_count(), 0, "a new store is empty")
	assert_equal(_store.live_furniture_count(), 0, "a new store is empty")


func test_a_building_publishes_a_blueprint_at_tier_one() -> void:
	"""REQ-SET-124: a blueprint exists before its materials are delivered."""
	_place_hall()
	assert_true(_store.is_live_building(_hall), "the hall reference is live")
	assert_equal(_store.state_of_building(_hall).value,
		int(CatalogScript.BUILDING_STATE["BLUEPRINT"]), "a new building is a BLUEPRINT")
	assert_equal(_store.tier_of_building(_hall).value, 1, "and starts at tier 1")
	assert_equal(_store.type_id_of_building(_hall).value, _building_id("hall"), "its type id")
	assert_equal(_store.rotation_of_building(_hall).value, 0, "§5.9: all rotation 0")
	assert_equal(_store.interior_id_of_building(_hall).value, -1, "no indoor kit is bound")
	assert_equal(_store.construction_ref_of_building(_hall), Vector2i(-1, 0),
		"and no Construction project exists to bind")
	assert_equal(_store.live_building_count(), 1, "one live structure")


func test_the_footprint_claims_its_tiles_and_refuses_an_overlap() -> void:
	"""REQ-SET-122's tile half: "in-bounds nonoverlapping tiles"."""
	_place_hall()
	assert_equal(_store.building_at_tile(_tile(HALL_ORIGIN_X, HALL_ORIGIN_Z)), _hall,
		"the origin tile is the hall's")
	assert_equal(_store.building_at_tile(_tile(HALL_ORIGIN_X + 11, HALL_ORIGIN_Z + 9)), _hall,
		"and so is the far corner of its 12x10 footprint")
	assert_equal(_store.building_at_tile(_tile(HALL_ORIGIN_X + 12, HALL_ORIGIN_Z)),
		Vector2i(-1, 0), "one tile past the footprint is free")
	var overlap: Buildings.OpResult = _store.place_building(
		_building_id("well"), _tile(HALL_ORIGIN_X + 1, HALL_ORIGIN_Z + 1), 0, START_MASK)
	assert_false(overlap.ok, "a well inside the hall's footprint must refuse")
	assert_equal(overlap.error, Buildings.REFUSE_FOOTPRINT_OCCUPIED, "with the overlap code")
	assert_equal(_store.live_building_count(), 1, "and the refusal creates nothing")


func test_rotation_swaps_the_two_extents() -> void:
	"""§5.9's "rotation in 90 degree steps" applied to the weir's asymmetric 4x2 footprint."""
	var weir: int = _building_id("weir")
	assert_equal(_store.extent_x_of(4, 2, 0), 4, "rotation 0 keeps 4 across")
	assert_equal(_store.extent_z_of(4, 2, 0), 2, "and 2 deep")
	assert_equal(_store.extent_x_of(4, 2, 1), 2, "rotation 1 swaps them")
	assert_equal(_store.extent_z_of(4, 2, 1), 4, "to 2 across and 4 deep")
	var placed: Buildings.OpResult = _store.place_building(weir, _tile(20, 20), 1, 31)
	assert_true(placed.ok, "a rotated weir places (%s)" % placed.error)
	assert_equal(_store.building_at_tile(_tile(21, 23)), placed.ref, "its rotated corner is held")
	assert_equal(_store.building_at_tile(_tile(23, 20)), Vector2i(-1, 0),
		"and the unrotated corner is not")


func test_a_footprint_off_the_grid_refuses() -> void:
	"""The 128x128 grid is the bound; a 12x10 hall cannot start at x=120."""
	var off: Buildings.OpResult = _store.place_building(
		_building_id("hall"), _tile(120, 60), 0, START_MASK)
	assert_false(off.ok, "a hall running off the east edge must refuse")
	assert_equal(off.error, Buildings.REFUSE_FOOTPRINT_OFF_GRID, "with the off-grid code")
	var bad_tile: Buildings.OpResult = _store.place_building(
		_building_id("well"), 16384, 0, START_MASK)
	assert_false(bad_tile.ok, "tile 16384 is past the last tile")


func test_an_unknown_type_or_rotation_refuses() -> void:
	"""A type id outside the thirty compiled rows is not a building."""
	for bad_type: int in [-1, 30, 1000]:
		var refused: Buildings.OpResult = _store.place_building(bad_type, _tile(10, 10), 0, 31)
		assert_false(refused.ok, "type %d must refuse" % bad_type)
		assert_equal(refused.error, Buildings.REFUSE_UNKNOWN_BUILDING_TYPE, "with its code")
	for bad_rotation: int in [-1, 4]:
		var refused: Buildings.OpResult = _store.place_building(
			_building_id("well"), _tile(10, 10), bad_rotation, 31)
		assert_false(refused.ok, "rotation %d must refuse" % bad_rotation)
		assert_equal(refused.error, Buildings.REFUSE_INVALID_ROTATION, "with its code")


# --- the milestone gate ----------------------------------------------------------------------------

func test_placement_is_gated_on_the_definitions_own_earned_bit() -> void:
	"""R-BUILD-DOM-001: unlocked exactly when `(mask & (1 << unlock)) != 0`."""
	var locked: Buildings.OpResult = _store.place_building(
		_building_id("mill"), _tile(10, 10), 0, START_MASK)
	assert_false(locked.ok, "the mill is an M1 row and M1 is not earned at mask 1")
	assert_equal(locked.error, Buildings.REFUSE_LOCKED_BY_MILESTONE, "with the lock code")
	assert_equal(_store.live_building_count(), 0, "and a locked placement creates nothing")
	var earned: Buildings.OpResult = _store.place_building(
		_building_id("mill"), _tile(10, 10), 0, START_MASK | 2)
	assert_true(earned.ok, "with M1 earned the mill places (%s)" % earned.error)


func test_a_sparse_mask_does_not_unlock_an_earlier_milestones_building() -> void:
	"""THE RULING'S CENTRAL CASE, AT THE STORE BOUNDARY. Mask 9 is M0+M3, highest 3.

	A `highest >= unlock` gate would place the mill here, because 3 >= 1. The earned-bit gate
	refuses it and still places the M3 nursery, which is the whole distinction."""
	var sparse: int = 9
	var mill: Buildings.OpResult = _store.place_building(
		_building_id("mill"), _tile(10, 10), 0, sparse)
	assert_false(mill.ok, "an M1 mill must stay locked at mask 9")
	assert_equal(mill.error, Buildings.REFUSE_LOCKED_BY_MILESTONE, "with the lock code")
	var brewery: Buildings.OpResult = _store.place_building(
		_building_id("brewery"), _tile(20, 20), 0, sparse)
	assert_false(brewery.ok, "an M2 brewery must stay locked at mask 9")
	var nursery: Buildings.OpResult = _store.place_building(
		_building_id("nursery"), _tile(30, 30), 0, sparse)
	assert_true(nursery.ok, "an M3 nursery places, because bit 3 IS earned (%s)" % nursery.error)
	assert_equal(_store.live_building_count(), 1, "exactly one of the three was built")


func test_an_illegal_mask_places_nothing_at_all() -> void:
	"""An unbound or malformed Progress store is unavailable, not a fabricated M0 world."""
	for bad_mask: int in [0, -1, 32, 63]:
		var refused: Buildings.OpResult = _store.place_building(
			_building_id("hall"), _tile(HALL_ORIGIN_X, HALL_ORIGIN_Z), 0, bad_mask)
		assert_false(refused.ok, "mask %d must place nothing" % bad_mask)
	assert_equal(_store.live_building_count(), 0, "no structure was created by any of them")


# --- rooms ------------------------------------------------------------------------------------------

func test_the_starter_rooms_have_section_5_9s_tile_counts() -> void:
	"""§5.9: "left 5 columns ... 40-tile dormitory ... kitchen on rows 0-1 (10 tiles), common
	room on rows 2-6 (25 tiles), and pantry on row 7 (5 tiles)", summing to §4.1's 80."""
	_place_hall()
	_designate_starter_rooms()
	assert_equal(_store.tile_count_of_room(_dormitory).value, 40, "40-tile dormitory")
	assert_equal(_store.tile_count_of_room(_kitchen).value, 10, "10-tile kitchen")
	assert_equal(_store.tile_count_of_room(_common).value, 25, "25-tile common room")
	assert_equal(_store.tile_count_of_room(_pantry).value, 5, "5-tile pantry")
	assert_equal(_store.room_tile_links_used(), 80, "80 RoomTileLinks entries, §4.1's room_tiles")
	assert_equal(_store.room_count_of_building(_hall).value, 4, "four rooms")
	assert_equal(_store.live_room_count(), 4, "four live rooms")


func test_one_tile_belongs_to_exactly_one_room() -> void:
	"""§5.9: "One tile belongs to exactly one room"."""
	_place_hall()
	_designate_starter_rooms()
	assert_equal(_store.room_at_tile(_interior_tile(0, 0)), _dormitory, "interior (0,0)")
	assert_equal(_store.room_at_tile(_interior_tile(9, 1)), _kitchen, "interior (9,1)")
	assert_equal(_store.room_at_tile(_interior_tile(9, 7)), _pantry, "interior (9,7)")
	var clash: Buildings.OpResult = _store.designate_room(
		_hall, _room_type("DINING"), _rect_tiles(9, 7, 9, 7))
	assert_false(clash.ok, "a tile already owned by the pantry must refuse")
	assert_equal(clash.error, Buildings.REFUSE_TILE_IN_OTHER_ROOM, "with its code")
	assert_equal(_store.live_room_count(), 4, "and the refusal creates nothing")


func test_a_room_must_lie_inside_its_buildings_interior() -> void:
	"""§5.9's interior is the footprint inset by one tile on every side."""
	_place_hall()
	var outside: PackedInt32Array = PackedInt32Array()
	outside.append(_tile(HALL_ORIGIN_X, HALL_ORIGIN_Z))
	var refused: Buildings.OpResult = _store.designate_room(
		_hall, _room_type("PANTRY"), outside)
	assert_false(refused.ok, "the exterior wall tile is not interior")
	assert_equal(refused.error, Buildings.REFUSE_TILE_OUTSIDE_INTERIOR, "with its code")
	var far: PackedInt32Array = PackedInt32Array()
	far.append(_tile(0, 0))
	assert_false(_store.designate_room(_hall, _room_type("PANTRY"), far).ok,
		"a tile on the other side of the map is not interior either")


func test_only_a_managed_building_accepts_rooms() -> void:
	"""§4.1's managed_interior column: a well is a black box with no interior."""
	var well: Buildings.OpResult = _store.place_building(
		_building_id("well"), _tile(64, 54), 0, START_MASK)
	assert_true(well.ok, "the authored starter well places (%s)" % well.error)
	var tiles: PackedInt32Array = PackedInt32Array()
	tiles.append(_tile(64, 54))
	var refused: Buildings.OpResult = _store.designate_room(
		well.ref, _room_type("PANTRY"), tiles)
	assert_false(refused.ok, "a well has no managed interior")
	assert_equal(refused.error, Buildings.REFUSE_NOT_MANAGED_INTERIOR, "with its code")


func test_a_seventeenth_room_refuses() -> void:
	"""GDD §4.2: "Up to 16 rooms/managed building"."""
	_place_hall()
	for index: int in 16:
		var tiles: PackedInt32Array = PackedInt32Array()
		tiles.append(_interior_tile(index % INTERIOR_WIDTH, index / INTERIOR_WIDTH))
		assert_true(_store.designate_room(_hall, _room_type("CORRIDOR"), tiles).ok,
			"room %d of sixteen designates" % index)
	var tiles: PackedInt32Array = PackedInt32Array()
	tiles.append(_interior_tile(6, 1))
	var refused: Buildings.OpResult = _store.designate_room(_hall, _room_type("CORRIDOR"), tiles)
	assert_false(refused.ok, "a seventeenth room must refuse")
	assert_equal(refused.error, Buildings.REFUSE_ROOM_LIMIT, "with the per-building cap code")
	assert_equal(_store.room_count_of_building(_hall).value, 16, "and sixteen remain")


func test_an_empty_or_duplicated_tile_list_refuses() -> void:
	"""A room with no tiles would pass every count rule vacuously."""
	_place_hall()
	assert_equal(_store.designate_room(_hall, _room_type("PANTRY"), PackedInt32Array()).error,
		Buildings.REFUSE_EMPTY_TILE_LIST, "an empty list refuses")
	var doubled: PackedInt32Array = PackedInt32Array()
	doubled.append(_interior_tile(0, 0))
	doubled.append(_interior_tile(0, 0))
	assert_equal(_store.designate_room(_hall, _room_type("PANTRY"), doubled).error,
		Buildings.REFUSE_DUPLICATE_TILE, "a repeated tile refuses")
	assert_equal(_store.live_room_count(), 0, "neither created a room")


func test_removing_a_room_releases_its_tiles_and_compacts_the_arena() -> void:
	"""The arena is bump-allocated and compacted, so later rooms keep addressing their own runs."""
	_place_hall()
	_designate_starter_rooms()
	assert_equal(_store.room_tile_links_used(), 80, "80 entries in use")
	assert_true(_store.remove_room(_kitchen).ok, "the empty kitchen removes")
	assert_equal(_store.room_tile_links_used(), 70, "its ten entries are released")
	assert_equal(_store.room_at_tile(_interior_tile(9, 1)), Vector2i(-1, 0), "its tiles are free")
	assert_equal(_store.tile_count_of_room(_pantry).value, 5, "the pantry still has five tiles")
	for index: int in 5:
		var tile: Buildings.OpResult = _store.room_tile_at(_pantry, index)
		assert_true(tile.ok, "the pantry's run is still addressable")
		assert_equal(tile.value, _interior_tile(5 + index, 7), "and still names its own tiles")
	assert_equal(_store.room_at_tile(_interior_tile(9, 7)), _pantry, "and the map agrees")


func test_a_room_holding_furniture_refuses_removal() -> void:
	"""Dropping the room would strand a furniture row whose owner resolves to nothing."""
	_starter_world()
	var refused: Buildings.OpResult = _store.remove_room(_pantry)
	assert_false(refused.ok, "a furnished pantry must refuse removal")
	assert_equal(refused.error, Buildings.REFUSE_ROOM_HAS_FURNITURE, "with its code")
	assert_equal(_store.furniture_mask_of(_pantry).value, 256, "and its mask is untouched")
	assert_equal(_store.live_room_count(), 4, "and the room is still there")


func test_a_building_holding_rooms_refuses_demolition() -> void:
	"""Cascading would destroy rows the caller never named."""
	_place_hall()
	_designate_starter_rooms()
	var refused: Buildings.OpResult = _store.demolish_building(_hall)
	assert_false(refused.ok, "a hall with rooms must refuse demolition")
	assert_equal(refused.error, Buildings.REFUSE_BUILDING_HAS_ROOMS, "with its code")
	assert_equal(_store.live_building_count(), 1, "the hall is still there")
	assert_equal(_store.building_at_tile(_tile(HALL_ORIGIN_X, HALL_ORIGIN_Z)), _hall,
		"and still holds its tiles")


func test_demolition_releases_the_footprint_and_the_reference() -> void:
	"""A demolished structure frees its tiles and its reference goes stale."""
	_place_hall()
	assert_true(_store.demolish_building(_hall).ok, "an empty hall demolishes")
	assert_false(_store.is_live_building(_hall), "the reference is stale")
	assert_equal(_store.building_at_tile(_tile(HALL_ORIGIN_X, HALL_ORIGIN_Z)), Vector2i(-1, 0),
		"and its tiles are free")
	assert_equal(_store.live_building_count(), 0, "no live structures")
	assert_equal(_store.state_of_building(_hall).error, Buildings.REFUSE_STALE_BUILDING_REF,
		"every accessor refuses the stale reference")


# --- the furniture presence mask (R-BUILD-DOM-003) -------------------------------------------------

func test_an_empty_room_has_mask_zero() -> void:
	"""The ruling's first vector."""
	_place_hall()
	_designate_starter_rooms()
	for room: Vector2i in [_dormitory, _kitchen, _common, _pantry]:
		assert_equal(_store.furniture_mask_of(room).value, MASK_EMPTY, "an empty room is 0")


func test_the_starter_kitchen_is_the_rulings_292_vector() -> void:
	"""kitchen_bench(32) + hearth(4) + shelf(256) = 292, which §5.9's kitchen row contains."""
	_starter_world()
	assert_equal(_store.furniture_mask_of(_kitchen).value, MASK_BENCH_HEARTH_SHELF,
		"the starter kitchen's mask")
	assert_equal(_store.furniture_mask_of(_dormitory).value, 1, "the dormitory holds beds only")
	assert_equal(_store.furniture_mask_of(_common).value, 128, "the common room holds seats only")
	assert_equal(_store.furniture_mask_of(_pantry).value, 256, "the pantry holds shelves only")


func test_bed_hearth_shelf_is_261() -> void:
	"""The ruling's second vector, built as three rows in one room."""
	_place_hall()
	var room: Vector2i = _designate("DORMITORY", _rect_tiles(0, 0, 4, 3))
	_place(room, "bed", _interior_tile(0, 0))
	_place(room, "hearth", _interior_tile(2, 0))
	_place(room, "shelf", _interior_tile(0, 1))
	assert_equal(_store.furniture_mask_of(room).value, MASK_BED_HEARTH_SHELF, "1 + 4 + 256")


func test_all_nine_kinds_make_mask_511() -> void:
	"""The ruling's fourth vector: every published bit, and no tenth."""
	_place_hall()
	var room: Vector2i = _designate("COMMON", _rect_tiles(0, 0, 9, 3))
	_place(room, "bed", _interior_tile(0, 0))
	_place(room, "decoration", _interior_tile(1, 0))
	_place(room, "hearth", _interior_tile(2, 0))
	_place(room, "kitchen_bench", _interior_tile(4, 0))
	_place(room, "patient_bed", _interior_tile(6, 0))
	_place(room, "seat", _interior_tile(7, 0))
	_place(room, "shelf", _interior_tile(8, 0))
	_place(room, "interior_door", _interior_tile(0, 1))
	_place(room, "interior_partition", _interior_tile(1, 1))
	assert_equal(_store.furniture_mask_of(room).value, MASK_ALL_NINE, "all nine bits are 511")
	assert_equal(_store.definitions().known_furniture_mask(), MASK_ALL_NINE, "and 511 is the max")


func test_two_beds_still_yield_one_bit_and_removing_one_keeps_it() -> void:
	"""R-BUILD-DOM-003: "Two beds still yield bit value 1; adding/removing one cannot clear that
	bit while the other remains. When the final instance is removed or reassigned, clear it."""
	_place_hall()
	var room: Vector2i = _designate("DORMITORY", _rect_tiles(0, 0, 4, 3))
	var first: Vector2i = _place(room, "bed", _interior_tile(0, 0))
	var second: Vector2i = _place(room, "bed", _interior_tile(1, 0))
	assert_equal(_store.furniture_mask_of(room).value, 1, "two beds are still bit value 1")
	assert_equal(_store.count_furniture_of_kind(room, _furniture_id("bed")).value, 2,
		"but the row count is two, which the mask cannot tell you")
	assert_true(_store.remove_furniture(first).ok, "the first bed removes")
	assert_equal(_store.furniture_mask_of(room).value, 1, "the bed bit survives the removal")
	assert_true(_store.remove_furniture(second).ok, "the last bed removes")
	assert_equal(_store.furniture_mask_of(room).value, MASK_EMPTY, "and now the bit clears")


func test_a_damaged_row_still_contributes_its_bit() -> void:
	"""R-BUILD-DOM-003: "A damaged bed still has a presence bit"."""
	_place_hall()
	var room: Vector2i = _designate("DORMITORY", _rect_tiles(0, 0, 4, 3))
	var bed: Vector2i = _place(room, "bed", _interior_tile(0, 0))
	assert_true(_store.set_furniture_condition(bed, 0).ok, "condition 0 is storable")
	assert_equal(_store.condition_of_furniture(bed).value, 0, "and stored")
	assert_equal(_store.furniture_mask_of(room).value, 1, "presence is structural, not usability")
	assert_false(_store.set_furniture_condition(bed, -1).ok, "a negative condition refuses")


func test_a_refused_placement_leaves_the_mask_untouched() -> void:
	"""Rollback: "a refusal leaves every collaborating store byte-identical"."""
	_place_hall()
	var room: Vector2i = _designate("KITCHEN", _rect_tiles(5, 0, 9, 1))
	_place(room, "hearth", _interior_tile(8, 0))
	var before: int = _store.furniture_mask_of(room).value
	assert_equal(before, 4, "a hearth alone is bit 4")
	var overlap: Buildings.OpResult = _store.place_furniture(
		room, _furniture_id("shelf"), _interior_tile(8, 0), 0)
	assert_false(overlap.ok, "a shelf on the hearth's tile must refuse")
	assert_equal(overlap.error, Buildings.REFUSE_FURNITURE_OVERLAP, "with the overlap code")
	assert_equal(_store.furniture_mask_of(room).value, before, "and the mask did not move")
	assert_equal(_store.live_furniture_count(), 1, "and no row was created")


func test_furniture_outside_its_room_refuses() -> void:
	"""A floor piece is where its tiles are; the whole footprint must be in the owning room."""
	_place_hall()
	_designate_starter_rooms()
	var wrong_room: Buildings.OpResult = _store.place_furniture(
		_pantry, _furniture_id("shelf"), _interior_tile(0, 0), 0)
	assert_false(wrong_room.ok, "a dormitory tile is not the pantry's")
	assert_equal(wrong_room.error, Buildings.REFUSE_TILE_NOT_IN_ROOM, "with its code")
	var straddle: Buildings.OpResult = _store.place_furniture(
		_kitchen, _furniture_id("hearth"), _interior_tile(9, 0), 0)
	assert_false(straddle.ok, "a 2x1 hearth at the east wall runs out of the room")
	assert_equal(_store.furniture_mask_of(_kitchen).value, MASK_EMPTY, "and nothing was created")


func test_a_stale_room_reference_cannot_place_or_be_read() -> void:
	"""R-BUILD-DOM-003: reject "stale/wrong-owner references before publication"."""
	_place_hall()
	var room: Vector2i = _designate("CORRIDOR", _rect_tiles(0, 0, 0, 0))
	assert_true(_store.remove_room(room).ok, "the empty corridor removes")
	var refused: Buildings.OpResult = _store.place_furniture(
		room, _furniture_id("bed"), _interior_tile(0, 0), 0)
	assert_false(refused.ok, "a removed room accepts no furniture")
	assert_equal(refused.error, Buildings.REFUSE_STALE_ROOM_REF, "with the stale-reference code")
	assert_equal(_store.furniture_mask_of(room).error, Buildings.REFUSE_STALE_ROOM_REF,
		"and reading its mask refuses too")


func test_a_reused_room_slot_cannot_inherit_the_old_rooms_bits() -> void:
	"""R-BUILD-DOM-003: "Reuse of a room slot cannot inherit old bits"."""
	_place_hall()
	var first: Vector2i = _designate("PANTRY", _rect_tiles(5, 7, 9, 7))
	var shelf: Vector2i = _place(first, "shelf", _interior_tile(6, 7))
	assert_equal(_store.furniture_mask_of(first).value, 256, "the first room holds a shelf")
	assert_true(_store.remove_furniture(shelf).ok, "the shelf removes")
	assert_true(_store.remove_room(first).ok, "and then the room does")
	var second: Vector2i = _designate("PANTRY", _rect_tiles(5, 7, 9, 7))
	assert_true(second != first, "the new room carries a new generation")
	assert_equal(_store.furniture_mask_of(second).value, MASK_EMPTY, "and starts empty")
	assert_equal(_store.furniture_mask_of(first).error, Buildings.REFUSE_STALE_ROOM_REF,
		"while the old reference resolves to nothing at all")


func test_an_edge_piece_contributes_to_its_declared_owner_only() -> void:
	"""R-BUILD-DOM-003: "Edge furniture contributes to its explicit `Furniture.room` owner only;
	do not fabricate a duplicate instance to set both adjoining rooms' bits"."""
	_place_hall()
	_designate_starter_rooms()
	var door: Vector2i = _place(_dormitory, "interior_door", _interior_tile(4, 4))
	assert_equal(_store.furniture_mask_of(_dormitory).value, 8, "the dormitory has the door bit")
	assert_equal(_store.furniture_mask_of(_kitchen).value, MASK_EMPTY,
		"and the adjoining room does NOT")
	assert_equal(_store.room_ref_of_furniture(door), _dormitory, "its owner is declared")
	assert_equal(_store.furniture_at_tile(_interior_tile(4, 4)), Vector2i(-1, 0),
		"an edge piece claims no floor tile, so a bed can still stand there")
	assert_true(_store.place_furniture(_dormitory, _furniture_id("bed"),
		_interior_tile(4, 4), 0).ok, "and one does")


func test_reassigning_an_edge_piece_moves_the_bit_between_both_masks() -> void:
	"""Both masks update in one call, so no observer sees the door twice or not at all."""
	_place_hall()
	_designate_starter_rooms()
	var door: Vector2i = _place(_dormitory, "interior_door", _interior_tile(4, 4))
	assert_equal(_store.furniture_mask_of(_dormitory).value, 8, "the dormitory owns it")
	var moved: Buildings.OpResult = _store.reassign_furniture(door, _kitchen)
	assert_true(moved.ok, "an edge piece may change owner within one building (%s)" % moved.error)
	assert_equal(_store.furniture_mask_of(_dormitory).value, MASK_EMPTY, "the source bit clears")
	assert_equal(_store.furniture_mask_of(_kitchen).value, 8, "and the destination gains it")
	assert_equal(_store.room_ref_of_furniture(door), _kitchen, "the owner reference moved too")
	assert_equal(_store.count_furniture_of_kind(_kitchen, _furniture_id("interior_door")).value, 1,
		"exactly one instance exists, not a duplicate in each room")


func test_reassigning_a_floor_piece_out_of_its_tiles_refuses() -> void:
	"""A bed is where its tile is; reassignment cannot teleport it into another room."""
	_place_hall()
	_designate_starter_rooms()
	var bed: Vector2i = _place(_dormitory, "bed", _interior_tile(0, 0))
	var refused: Buildings.OpResult = _store.reassign_furniture(bed, _pantry)
	assert_false(refused.ok, "the pantry does not own the bed's tile")
	assert_equal(refused.error, Buildings.REFUSE_TILE_NOT_IN_ROOM, "with its code")
	assert_equal(_store.furniture_mask_of(_dormitory).value, 1, "the source mask is unchanged")
	assert_equal(_store.furniture_mask_of(_pantry).value, MASK_EMPTY, "and so is the target's")
	assert_equal(_store.furniture_at_tile(_interior_tile(0, 0)), bed,
		"and the refused piece still holds its tile")


func test_reassigning_to_the_same_room_refuses() -> void:
	"""A no-op that recomputed a mask would look like a successful move."""
	_place_hall()
	_designate_starter_rooms()
	var door: Vector2i = _place(_dormitory, "interior_door", _interior_tile(4, 4))
	var refused: Buildings.OpResult = _store.reassign_furniture(door, _dormitory)
	assert_false(refused.ok, "reassigning to the current owner refuses")
	assert_equal(refused.error, Buildings.REFUSE_SAME_ROOM, "with its code")


func test_an_occupied_piece_refuses_removal() -> void:
	"""`Furniture.user` is a live reference; dropping the row would strand it."""
	_place_hall()
	_designate_starter_rooms()
	var bed: Vector2i = _place(_dormitory, "bed", _interior_tile(0, 0))
	var resident: Vector2i = _store.directory().create(EntityDirectory.KIND_RESIDENT)
	assert_true(resident != Vector2i(-1, 0), "the directory allocates a resident row")
	assert_true(_store.set_furniture_user(bed, resident).ok, "the bed accepts its user")
	assert_equal(_store.user_ref_of_furniture(bed), resident, "and stores the reference")
	assert_false(_store.remove_furniture(bed).ok, "an occupied bed refuses removal")
	assert_true(_store.set_furniture_user(bed, Vector2i(-1, 0)).ok, "clearing the user works")
	assert_true(_store.remove_furniture(bed).ok, "and then it removes")


func test_a_user_reference_must_name_a_live_resident() -> void:
	"""A bed cannot be occupied by a building, a room, or a stale row."""
	_place_hall()
	_designate_starter_rooms()
	var bed: Vector2i = _place(_dormitory, "bed", _interior_tile(0, 0))
	assert_false(_store.set_furniture_user(bed, _hall).ok, "a building is not a resident")
	assert_false(_store.set_furniture_user(bed, Vector2i(0, 99)).ok, "nor a stale reference")
	assert_equal(_store.user_ref_of_furniture(bed), Vector2i(-1, 0), "the bed is still empty")


func test_verify_room_masks_agrees_with_every_live_room() -> void:
	"""R-BUILD-DOM-003's load rule: recompute, compare, and refuse rather than repair.

	The MISMATCH branch cannot be reached through this store's own API -- `_r_furniture_mask` is
	written only by `_recompute_mask_row()`, which is the same function the check runs -- and that
	is the property, not a gap in the test. Its caller is the save decoder, which writes masks
	directly from a file and is the one thing that can disagree; no decoder exists yet."""
	_starter_world()
	var clean: Buildings.OpResult = _store.verify_room_masks()
	assert_true(clean.ok, "a consistent store verifies (%s)" % clean.error)
	assert_equal(clean.value, 4, "and reports the four rooms it checked")
	var shelf: Vector2i = _place(_pantry, "decoration", _interior_tile(5, 7))
	assert_equal(_store.furniture_mask_of(_pantry).value, 256 + 2, "shelf plus decoration")
	assert_true(_store.remove_furniture(shelf).ok, "the decoration removes")
	assert_equal(_store.furniture_mask_of(_pantry).value, 256, "and its bit goes with it")
	assert_true(_store.verify_room_masks().ok, "the store is still consistent")


func test_recompute_furniture_mask_is_the_same_answer() -> void:
	"""The stored mask and a fresh recomputation must never disagree on a live store."""
	_starter_world()
	for room: Vector2i in [_dormitory, _kitchen, _common, _pantry]:
		var stored: int = _store.furniture_mask_of(room).value
		var recomputed: Buildings.OpResult = _store.recompute_furniture_mask(room)
		assert_true(recomputed.ok, "a live room recomputes (%s)" % recomputed.error)
		assert_equal(recomputed.value, stored, "and agrees with the stored mask")


func test_count_furniture_of_kind_reads_rows_and_not_the_mask() -> void:
	"""The mask says "at least one"; only the rows say how many."""
	_starter_world()
	assert_equal(_store.count_furniture_of_kind(_dormitory, _furniture_id("bed")).value, 12,
		"§5.9's twelve starter beds")
	assert_equal(_store.count_furniture_of_kind(_common, _furniture_id("seat")).value, 12,
		"§5.9's twelve seat places")
	assert_equal(_store.count_furniture_of_kind(_pantry, _furniture_id("shelf")).value, 4,
		"the four pantry shelves")
	assert_equal(_store.count_furniture_of_kind(_kitchen, _furniture_id("shelf")).value, 1,
		"and the fifth, kitchen-owned shelf")
	assert_equal(_store.count_furniture_of_kind(_dormitory, _furniture_id("shelf")).value, 0,
		"a kind the room does not hold counts zero")
	assert_false(_store.count_furniture_of_kind(_dormitory, 9).ok, "an unknown kind refuses")


func test_live_furniture_of_kind_counts_the_whole_settlement() -> void:
	"""The HUD bed counter's source: a maintained total, not an 81920-row scan."""
	_starter_world()
	assert_equal(_store.live_furniture_of_kind(_furniture_id("bed")), 12, "twelve beds")
	assert_equal(_store.live_furniture_of_kind(_furniture_id("shelf")), 5,
		"R-BUILD-DOM-004: all FIVE starter shelf rows are instantiated")
	assert_equal(_store.live_furniture_of_kind(_furniture_id("hearth")), 1, "one hearth")
	assert_equal(_store.live_furniture_of_kind(_furniture_id("kitchen_bench")), 1, "one bench")
	assert_equal(_store.live_furniture_of_kind(_furniture_id("patient_bed")), 0, "no patient beds")
	assert_equal(_store.live_furniture_count(), 12 + 1 + 1 + 12 + 5, "31 furniture rows in total")


# --- services measured from real rows ---------------------------------------------------------------

func test_the_starter_pantry_is_exactly_200000_grams() -> void:
	"""R-BUILD-DOM-004: five shelf rows exist, but only the four pantry ones supply capacity."""
	_starter_world()
	var pantry: Buildings.OpResult = _store.pantry_capacity_g_of_room(_pantry)
	assert_true(pantry.ok, "the valid pantry reports a capacity (%s)" % pantry.error)
	assert_equal(pantry.value, PANTRY_CAPACITY_G, "4 x 50000 = 200000 g")
	var kitchen: Buildings.OpResult = _store.pantry_capacity_g_of_room(_kitchen)
	assert_false(kitchen.ok, "the kitchen is not a pantry and must refuse, not answer 0")
	assert_equal(kitchen.error, Buildings.REFUSE_NOT_A_PANTRY, "with its own code")
	assert_equal(_store.furniture_mask_of(_kitchen).value & 256, 256,
		"even though the kitchen carries the shelf-presence bit")


func test_an_invalid_pantry_supplies_no_capacity() -> void:
	"""R-BUILD-DOM-004 says "the valid PANTRY room"; validity is a separate gate from presence."""
	_place_hall()
	_designate_starter_rooms()
	for ix: int in range(6, 10):
		_place(_pantry, "shelf", _interior_tile(ix, 7))
	var before_validation: Buildings.OpResult = _store.pantry_capacity_g_of_room(_pantry)
	assert_false(before_validation.ok, "an unvalidated pantry refuses")
	assert_equal(before_validation.error, Buildings.REFUSE_ROOM_NOT_VALID, "with its code")
	assert_true(_store.set_room_valid(_pantry, true).ok, "the owning system validates it")
	assert_equal(_store.pantry_capacity_g_of_room(_pantry).value, PANTRY_CAPACITY_G,
		"and now it reports 200000 g")


func test_the_hall_bench_supplies_one_kitchen_slot_and_no_double_count() -> void:
	"""R-BUILD-DOM-002: "The starter hall's one bench gives one slot; do not add hall's catalog
	slots again or invent two exterior-kitchen slots for it"."""
	_starter_world()
	var kitchen_service: int = int(CatalogScript.STATION["kitchen"])
	var slots: Buildings.OpResult = _store.station_slots_in_building(_hall, kitchen_service)
	assert_true(slots.ok, "the hall answers about the kitchen service (%s)" % slots.error)
	assert_equal(slots.value, 1, "one bench, one slot -- the hall's two Keeper slots are not added")
	assert_equal(_store.kitchen_bench_slots_of_room(_kitchen).value, 1,
		"and the room itself reports the same one slot")


func test_an_exterior_kitchen_supplies_its_two_slots() -> void:
	"""BAL-CAT-011's first provider: "one exterior kitchen's 2 cooking slots"."""
	var placed: Buildings.OpResult = _store.place_building(
		_building_id("kitchen"), _tile(40, 40), 0, START_MASK)
	assert_true(placed.ok, "an exterior kitchen is a Start building (%s)" % placed.error)
	var kitchen_service: int = int(CatalogScript.STATION["kitchen"])
	var slots: Buildings.OpResult = _store.station_slots_in_building(placed.ref, kitchen_service)
	assert_true(slots.ok, "it answers about its own service")
	assert_equal(slots.value, 2, "two cooking slots")
	assert_equal(_store.station_slots_in_building(placed.ref,
		int(CatalogScript.STATION["mill"])).value, 0, "and no mill slots")


func test_two_benches_bind_separately() -> void:
	"""R-BUILD-DOM-002: "multiple benches separately bound"; each 2x1 bench is one slot."""
	_place_hall()
	var kitchen: Vector2i = _designate("KITCHEN", _rect_tiles(5, 0, 9, 1))
	_place(kitchen, "kitchen_bench", _interior_tile(5, 0))
	_place(kitchen, "kitchen_bench", _interior_tile(7, 0))
	_place(kitchen, "hearth", _interior_tile(5, 1))
	assert_true(_store.set_room_valid(kitchen, true).ok, "the kitchen validates")
	assert_equal(_store.kitchen_bench_slots_of_room(kitchen).value, 2, "two benches, two slots")
	assert_equal(_store.count_furniture_of_kind(kitchen, _furniture_id("kitchen_bench")).value, 2,
		"and two real instances back them")
	assert_equal(_store.furniture_mask_of(kitchen).value, 32 + 4, "still one bench bit, and 4")


func test_an_invalid_room_provides_no_station_slots() -> void:
	"""R-BUILD-DOM-002: "invalid room/stale refs/blocked access cannot provide ready work"."""
	_place_hall()
	var kitchen: Vector2i = _designate("KITCHEN", _rect_tiles(5, 0, 9, 1))
	_place(kitchen, "kitchen_bench", _interior_tile(6, 0))
	var kitchen_service: int = int(CatalogScript.STATION["kitchen"])
	assert_equal(_store.station_slots_in_building(_hall, kitchen_service).value, 0,
		"an unvalidated kitchen provides nothing")
	assert_false(_store.kitchen_bench_slots_of_room(kitchen).ok, "and the room call refuses")
	assert_true(_store.set_room_valid(kitchen, true).ok, "once it validates")
	assert_equal(_store.station_slots_in_building(_hall, kitchen_service).value, 1,
		"the bench supplies its slot")
	assert_true(_store.set_room_valid(kitchen, false).ok, "and when validity is withdrawn")
	assert_equal(_store.station_slots_in_building(_hall, kitchen_service).value, 0,
		"the slot goes with it")


func test_station_slots_refuse_an_unknown_service() -> void:
	"""A wrong-domain integer must not index the eleven-key table."""
	_place_hall()
	for bad: int in [-1, 11, 30]:
		var refused: Buildings.OpResult = _store.station_slots_in_building(_hall, bad)
		assert_false(refused.ok, "service %d does not exist" % bad)
		assert_equal(refused.error, Buildings.REFUSE_UNKNOWN_STATION, "with its code")


# --- the countable half of §5.9's room validity ------------------------------------------------------

func test_the_authored_starter_rooms_pass_their_countable_rules() -> void:
	"""§5.9's own diagram must satisfy its own counting rules, or the diagram or the rules is wrong."""
	_starter_world()
	for room: Vector2i in [_dormitory, _kitchen, _common, _pantry]:
		var result: Buildings.OpResult = _store.room_meets_countable_rules(room)
		assert_true(result.ok, "a live room answers (%s)" % result.error)
		assert_equal(result.value, 1, "the authored room passes its countable rules")


func test_a_dormitory_needs_three_tiles_per_bed() -> void:
	"""§5.9: "dormitory>=3 tiles/bed, at least 1 bed"."""
	_place_hall()
	var room: Vector2i = _designate("DORMITORY", _rect_tiles(0, 0, 2, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "no bed fails outright")
	_place(room, "bed", _interior_tile(0, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 1, "3 tiles carry 1 bed")
	_place(room, "bed", _interior_tile(1, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "3 tiles cannot carry 2 beds")


func test_a_kitchen_needs_six_tiles_a_bench_and_a_hearth() -> void:
	"""§5.9: "kitchen>=6 tiles,>=1 bench,>=1 hearth"."""
	_place_hall()
	var room: Vector2i = _designate("KITCHEN", _rect_tiles(5, 0, 9, 1))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "an empty kitchen fails")
	_place(room, "kitchen_bench", _interior_tile(6, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "a bench alone is not enough")
	_place(room, "hearth", _interior_tile(8, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 1, "bench plus hearth passes")
	var small: Vector2i = _designate("KITCHEN", _rect_tiles(0, 0, 4, 0))
	_place(small, "kitchen_bench", _interior_tile(0, 0))
	_place(small, "hearth", _interior_tile(2, 0))
	assert_equal(_store.room_meets_countable_rules(small).value, 0, "5 tiles is below the six")


func test_a_pantry_needs_four_tiles_and_a_shelf() -> void:
	"""§5.9: "pantry>=4 tiles,>=1 shelf"."""
	_place_hall()
	var small: Vector2i = _designate("PANTRY", _rect_tiles(0, 0, 2, 0))
	_place(small, "shelf", _interior_tile(0, 0))
	assert_equal(_store.room_meets_countable_rules(small).value, 0, "3 tiles is below the four")
	var room: Vector2i = _designate("PANTRY", _rect_tiles(5, 7, 9, 7))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "5 tiles with no shelf fails")
	_place(room, "shelf", _interior_tile(6, 7))
	assert_equal(_store.room_meets_countable_rules(room).value, 1, "5 tiles and a shelf passes")


func test_a_private_room_takes_exactly_one_bed() -> void:
	"""§5.9: "private room>=6 tiles, exactly 1 bed"."""
	_place_hall()
	var room: Vector2i = _designate("PRIVATE_ROOM", _rect_tiles(0, 0, 3, 1))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "no bed fails")
	_place(room, "bed", _interior_tile(0, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 1, "8 tiles and one bed passes")
	_place(room, "bed", _interior_tile(1, 0))
	assert_equal(_store.room_meets_countable_rules(room).value, 0, "a second bed fails "
		+ "\"exactly 1\"")


func test_dining_and_common_seat_rules() -> void:
	"""§5.9: "dining>=2 tiles/seat and>=4 seats"; "common>=8 tiles,>=4 seats"."""
	_place_hall()
	var dining: Vector2i = _designate("DINING", _rect_tiles(0, 0, 3, 1))
	for ix: int in range(0, 4):
		_place(dining, "seat", _interior_tile(ix, 0))
	assert_equal(_store.room_meets_countable_rules(dining).value, 1, "8 tiles carry 4 seats")
	_place(dining, "seat", _interior_tile(0, 1))
	assert_equal(_store.room_meets_countable_rules(dining).value, 0, "8 tiles cannot carry 5")
	var common: Vector2i = _designate("COMMON", _rect_tiles(5, 0, 9, 1))
	for ix: int in range(5, 8):
		_place(common, "seat", _interior_tile(ix, 0))
	assert_equal(_store.room_meets_countable_rules(common).value, 0, "three seats is below four")
	_place(common, "seat", _interior_tile(8, 0))
	assert_equal(_store.room_meets_countable_rules(common).value, 1, "four seats passes")


func test_an_infirmary_counts_patient_beds_and_a_shelf() -> void:
	"""§5.9: "infirmary>=3 tiles/patient bed,>=1 bed,>=1 shelf, heated". Heated is not counted."""
	var infirmary: Buildings.OpResult = _store.place_building(
		_building_id("infirmary"), _tile(20, 20), 0, 3)
	assert_true(infirmary.ok, "an M1 infirmary places once M1 is earned (%s)" % infirmary.error)
	var tiles: PackedInt32Array = PackedInt32Array()
	for iz: int in range(21, 27):
		for ix: int in range(21, 27):
			tiles.append(_tile(ix, iz))
	var room: Buildings.OpResult = _store.designate_room(
		infirmary.ref, _room_type("INFIRMARY"), tiles)
	assert_true(room.ok, "its 6x6 interior designates (%s)" % room.error)
	assert_equal(_store.room_meets_countable_rules(room.ref).value, 0, "empty fails")
	assert_true(_store.place_furniture(room.ref, _furniture_id("patient_bed"),
		_tile(21, 21), 0).ok, "a patient bed places")
	assert_equal(_store.room_meets_countable_rules(room.ref).value, 0, "a bed with no shelf fails")
	assert_true(_store.place_furniture(room.ref, _furniture_id("shelf"),
		_tile(22, 21), 0).ok, "a shelf places")
	assert_equal(_store.room_meets_countable_rules(room.ref).value, 1, "bed plus shelf passes")


# --- column setters and their bounds -----------------------------------------------------------------

func test_state_tier_condition_and_interior_id_validate_their_inputs() -> void:
	"""Every setter refuses rather than clamping, and a refusal stores nothing."""
	_place_hall()
	assert_true(_store.set_building_state(_hall, int(CatalogScript.BUILDING_STATE["ACTIVE"])).ok,
		"ACTIVE is a legal state")
	assert_false(_store.set_building_state(_hall, 6).ok, "there is no state 6")
	assert_false(_store.set_building_state(_hall, -1).ok, "nor a state -1")
	assert_equal(_store.state_of_building(_hall).value,
		int(CatalogScript.BUILDING_STATE["ACTIVE"]), "the refusals stored nothing")
	assert_true(_store.set_building_tier(_hall, 2).ok, "the hall accepts tier 2")
	assert_false(_store.set_building_tier(_hall, 3).ok, "but not tier 3")
	assert_equal(_store.tier_of_building(_hall).value, 2, "and the refusal stored nothing")
	assert_true(_store.set_building_condition(_hall, 1000).ok, "a non-negative condition stores")
	assert_false(_store.set_building_condition(_hall, -1).ok, "a negative one refuses")
	assert_true(_store.set_building_interior_id(_hall, -1).ok, "-1 is the empty catalog id")
	assert_false(_store.set_building_interior_id(_hall, -2).ok, "-2 is not")


func test_a_mill_refuses_tier_two() -> void:
	"""BAL-CAT-006: only residence, hall, covered_store and workshop have a tier-2 package."""
	var mill: Buildings.OpResult = _store.place_building(_building_id("mill"), _tile(10, 10), 0, 3)
	assert_true(mill.ok, "the mill places at M1 (%s)" % mill.error)
	var refused: Buildings.OpResult = _store.set_building_tier(mill.ref, 2)
	assert_false(refused.ok, "there is no tier-2 mill")
	assert_equal(refused.error, Buildings.REFUSE_INVALID_TIER, "with its code")
	assert_equal(_store.tier_of_building(mill.ref).value, 1, "and it stays at tier 1")


func test_occupancy_and_temperature_validate_their_bounds() -> void:
	"""Occupancy cannot exceed the 256 living-population cap; temperature may be negative."""
	_place_hall()
	_designate_starter_rooms()
	assert_true(_store.set_room_occupants(_common, 12).ok, "twelve residents fit")
	assert_equal(_store.occupants_of_room(_common).value, 12, "and are stored")
	assert_false(_store.set_room_occupants(_common, -1).ok, "a negative count refuses")
	assert_false(_store.set_room_occupants(_common, 257).ok, "and so does one past the cap")
	assert_equal(_store.occupants_of_room(_common).value, 12, "the refusals stored nothing")
	assert_true(_store.set_room_temperature_tenths(_common, -50).ok, "-5.0C is a real temperature")
	assert_equal(_store.temperature_tenths_of_room(_common).value, -50, "and is stored signed")


func test_a_construction_reference_must_be_a_live_construction_row() -> void:
	"""No Construction store exists, so the directory is the only thing that can attest one."""
	_place_hall()
	var project: Vector2i = _store.directory().create(EntityDirectory.KIND_CONSTRUCTION)
	assert_true(project != Vector2i(-1, 0), "the directory allocates a construction row")
	assert_true(_store.set_building_construction(_hall, project).ok, "the hall binds it")
	assert_equal(_store.construction_ref_of_building(_hall), project, "and stores the reference")
	assert_false(_store.set_building_construction(_hall, _hall).ok, "a building is not a project")
	assert_true(_store.set_building_construction(_hall, Vector2i(-1, 0)).ok, "the null ref clears")
	assert_equal(_store.construction_ref_of_building(_hall), Vector2i(-1, 0), "and it is cleared")


func test_clear_empties_every_store_and_releases_the_directory() -> void:
	"""A cleared store leaks no directory allocation and keeps its columns allocated."""
	_starter_world()
	assert_true(_store.directory().total_live_count() > 0, "the directory holds the rows")
	_store.clear()
	assert_equal(_store.live_building_count(), 0, "no buildings")
	assert_equal(_store.live_room_count(), 0, "no rooms")
	assert_equal(_store.live_furniture_count(), 0, "no furniture")
	assert_equal(_store.room_tile_links_used(), 0, "no room tile links")
	assert_equal(_store.directory().total_live_count(), 0, "and the directory is empty again")
	assert_equal(_store.live_furniture_of_kind(_furniture_id("bed")), 0, "the counters reset")
	assert_true(_store.place_building(_building_id("hall"),
		_tile(HALL_ORIGIN_X, HALL_ORIGIN_Z), 0, START_MASK).ok, "and the store still works")


func test_a_shared_directory_is_not_cleared_by_this_store() -> void:
	"""A directory passed in belongs to its owner; only this store's own rows are released."""
	var directory: EntityDirectory = EntityDirectory.new()
	var outsider: Vector2i = directory.create(EntityDirectory.KIND_RESIDENT)
	var shared: Buildings = Buildings.new(directory)
	assert_true(shared.place_building(_building_id("well"), _tile(64, 54), 0, START_MASK).ok,
		"the shared store places a well")
	shared.clear()
	assert_true(directory.is_valid(outsider), "the outsider's row survives the clear")
	assert_equal(directory.live_count(EntityDirectory.KIND_BUILDING), 0,
		"while every building row was released")
