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

func after_each() -> void:
	_store = null
func test_zero_catalog_user_slots_do_not_gate_current_user_binding() -> void:
	_place_hall()
	_dormitory = _designate("DORMITORY",_rect_tiles(0,0,4,7))
	var resident: Vector2i = _store.directory().create(EntityDirectory.KIND_RESIDENT)
	for key: String in ["decoration","interior_partition"]:
		var id: int = _furniture_id(key)
		assert_equal(_store.definitions().user_slots_of(id),0,"catalog publishes no user slot")
		var furniture: Vector2i = _place(_dormitory,key,_interior_tile(0,0))
		assert_true(_store.set_furniture_user(furniture,resident).ok,"current setter accepts user on "+key)
		assert_equal(_store.user_ref_of_furniture(furniture),resident,"reference retained")
		assert_false(_store.remove_furniture(furniture).ok,"in-use check still protects reference")
		assert_true(_store.set_furniture_user(furniture,Vector2i(-1,0)).ok,"clear user")
		assert_true(_store.remove_furniture(furniture).ok,"remove after clearing")
