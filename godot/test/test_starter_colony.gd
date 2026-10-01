extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/starter_colony.gd`: INIT-C live apply (DEMO-CONTAIN-R01 D3, decision
## 0533) against a standalone `buildings.gd` store.
##
## Every expected position is restated from GDD §5.9's text and diagram -- the hall at (58,59),
## stockpiles at (50,60), (50,65), (70,60), (70,65), the well at (64,54), the workbench at
## (58,54), interior origin = hall + (1,1) -- and never read back from the plan producer. Each
## refusal is asserted with the store's directory and live counts unchanged, because a preflight
## that half-applied a colony is exactly what it exists to prevent.

const StarterColony := preload("res://scripts/core/starter_colony.gd")
const StarterStructures := preload("res://scripts/core/starter_structures.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Milestones := preload("res://scripts/core/milestones.gd")
const GroundPiles := preload("res://scripts/core/ground_piles.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")

const START_MASK: int = 1
## [catalog key, origin x, origin z, footprint x, footprint z], GDD §5.9 in authored order.
const BUILDINGS_ORACLE: Array = [
	["hall", 58, 59, 12, 10], ["open_stockpile", 50, 60, 4, 4], ["open_stockpile", 50, 65, 4, 4],
	["open_stockpile", 70, 60, 4, 4], ["open_stockpile", 70, 65, 4, 4], ["well", 64, 54, 2, 2],
	["workbench", 58, 54, 3, 3],
]
## Room type keys with their tile counts: left 5 columns 40, kitchen rows 0-1, common rows 2-6,
## pantry row 7 (§5.9's "Default starter interior").
const ROOMS_ORACLE: Array = [["DORMITORY", 40], ["KITCHEN", 10], ["COMMON", 25], ["PANTRY", 5]]
## Floor furniture per kind, counted off §5.9's diagram: 12 B, one K pair, one H pair, 5 S, 12 T.
const FURNITURE_KIND_ORACLE: Dictionary = {
	"bed": 12, "kitchen_bench": 1, "hearth": 1, "shelf": 5, "seat": 12,
}

var _store: Buildings = null
var _plan: StarterStructures.Plan = null
var _applied: StarterColony.Applied = null


func before_each() -> void:
	"""A fresh standalone store, the authored plan, and an empty apply record."""
	_store = Buildings.new()
	_plan = StarterStructures.Plan.new()
	assert_true(StarterStructures.new().prepare_into(_plan), "the authored plan prepares")
	_applied = StarterColony.Applied.new()


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's `z*128+x`."""
	return z * 128 + x


func _interior(local_x: int, local_z: int) -> int:
	"""§5.9: interior origin is the hall's exterior origin plus (1,1)."""
	return _tile(58 + 1 + local_x, 59 + 1 + local_z)


func _apply() -> StringName:
	"""Apply the authored plan into `_store` under the start mask."""
	return StarterColony.apply_into(_store, _plan, START_MASK, _applied)


func _snapshot() -> PackedInt32Array:
	"""Live counts and the directory's live total: what a refusal must leave unchanged."""
	return PackedInt32Array([_store.live_building_count(), _store.live_room_count(),
		_store.live_furniture_count(), _store.directory().total_live_count()])


# --- the colony stands where §5.9 puts it -------------------------------------------------------

func test_the_seven_buildings_stand_active_at_their_authored_tiles() -> void:
	"""Every structure at its §5.9 origin, rotation 0, tier 1, ACTIVE, covering its footprint."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_equal(_store.live_building_count(), 7, "seven structures")
	for row: int in BUILDINGS_ORACLE.size():
		var entry: Array = BUILDINGS_ORACLE[row]
		var ref: Vector2i = _store.building_at_tile(_tile(entry[1], entry[2]))
		assert_equal(ref, _applied.building_ref(row), "row %d is the structure at its origin" % row)
		assert_equal(_store.type_id_of_building(ref).value, int(Catalog.BUILDING_DEFINITION[entry[0]]),
			"row %d is a %s" % [row, entry[0]])
		assert_equal(_store.state_of_building(ref).value, int(Catalog.BUILDING_STATE["ACTIVE"]),
			"and ACTIVE, not a blueprint")
		assert_equal(_store.tier_of_building(ref).value, 1, "at tier 1")
		assert_equal(_store.rotation_of_building(ref).value, 0, "at rotation 0")
		var far: int = _tile(int(entry[1]) + int(entry[3]) - 1, int(entry[2]) + int(entry[4]) - 1)
		assert_equal(_store.building_at_tile(far), ref, "its far corner is its own footprint")


func test_the_hall_holds_four_rooms_over_its_eighty_interior_tiles() -> void:
	"""Dormitory 40, kitchen 10, common 25, pantry 5 -- one room per tile, all in the hall."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	var hall: Vector2i = _store.building_at_tile(_tile(58, 59))
	assert_equal(_store.live_room_count(), 4, "four rooms")
	for ordinal: int in ROOMS_ORACLE.size():
		var room: Vector2i = _applied.room_ref(ordinal)
		assert_equal(_store.room_building_ref_of(room), hall, "room %d is the hall's" % ordinal)
		assert_equal(_store.type_of_room(room).value, int(Catalog.ROOM_TYPE[ROOMS_ORACLE[ordinal][0]]),
			"room %d is the %s" % [ordinal, ROOMS_ORACLE[ordinal][0]])
		assert_equal(_store.tile_count_of_room(room).value, ROOMS_ORACLE[ordinal][1],
			"with %d tiles" % ROOMS_ORACLE[ordinal][1])
		assert_false(_store.room_is_valid(room), "and no validity is claimed for it")
	assert_equal(_store.room_at_tile(_interior(0, 0)), _applied.room_ref(0), "(0,0) is dormitory")
	assert_equal(_store.room_at_tile(_interior(4, 7)), _applied.room_ref(0), "(4,7) is dormitory")
	assert_equal(_store.room_at_tile(_interior(9, 1)), _applied.room_ref(1), "(9,1) is kitchen")
	assert_equal(_store.room_at_tile(_interior(5, 2)), _applied.room_ref(2), "(5,2) is common")
	assert_equal(_store.room_at_tile(_interior(9, 7)), _applied.room_ref(3), "(9,7) is pantry")
	assert_equal(_store.room_at_tile(_tile(58, 59)), EntityDirectory.NULL_REF,
		"the wall tile is in no room")


func test_thirty_one_floor_furniture_stand_on_the_diagram_and_no_edge_piece_is_placed() -> void:
	"""Counts per kind off the §5.9 diagram, spot positions, and no partition or door row."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_equal(_store.live_furniture_count(), 31, "thirty-one pieces")
	for key: String in FURNITURE_KIND_ORACLE:
		assert_equal(_store.live_furniture_of_kind(int(Catalog.FURNITURE_DEFINITION[key])),
			FURNITURE_KIND_ORACLE[key], "%d %s" % [FURNITURE_KIND_ORACLE[key], key])
	assert_equal(_store.live_furniture_of_kind(int(Catalog.FURNITURE_DEFINITION["interior_partition"])),
		0, "no partition: edge placement has no defined encoding (decision 0533)")
	assert_equal(_store.live_furniture_of_kind(int(Catalog.FURNITURE_DEFINITION["interior_door"])),
		0, "and no interior door")
	_assert_piece_at(0, 0, "bed", 0)
	_assert_piece_at(6, 0, "kitchen_bench", 1)
	_assert_piece_at(7, 0, "kitchen_bench", 1)
	_assert_piece_at(9, 0, "hearth", 1)
	_assert_piece_at(9, 1, "shelf", 1)
	_assert_piece_at(6, 2, "seat", 2)
	_assert_piece_at(3, 4, "bed", 0)
	_assert_piece_at(9, 7, "shelf", 3)
	assert_equal(_store.furniture_at_tile(_interior(5, 7)), EntityDirectory.NULL_REF,
		"the pantry's walk tile at x5 is clear")
	assert_equal(_store.count_furniture_of_kind(_applied.room_ref(3),
		int(Catalog.FURNITURE_DEFINITION["shelf"])).value, 4, "four shelves in the pantry")


func _assert_piece_at(local_x: int, local_z: int, key: String, room_ordinal: int) -> void:
	"""The piece covering interior tile (x, z) is a `key` in room `room_ordinal`."""
	var piece: Vector2i = _store.furniture_at_tile(_interior(local_x, local_z))
	assert_true(_store.is_live_furniture(piece), "a piece covers (%d,%d)" % [local_x, local_z])
	assert_equal(_store.type_id_of_furniture(piece).value, int(Catalog.FURNITURE_DEFINITION[key]),
		"(%d,%d) is a %s" % [local_x, local_z, key])
	assert_equal(_store.room_ref_of_furniture(piece), _applied.room_ref(room_ordinal),
		"(%d,%d) stands in room %d" % [local_x, local_z, room_ordinal])


func test_the_applied_colony_matches_its_plan_and_a_changed_row_does_not() -> void:
	"""`plan_mismatch_refusal()` passes the apply and catches each kind of drift."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_NONE, "the live rows are the plan")
	var well: Vector2i = _applied.building_ref(5)
	assert_true(_store.set_building_state(well, int(Catalog.BUILDING_STATE["PAUSED"])).ok, "pause")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "a building state drift is caught")
	assert_true(_store.set_building_state(well, int(Catalog.BUILDING_STATE["ACTIVE"])).ok, "restore")
	var hall: Vector2i = _applied.building_ref(0)
	assert_true(_store.set_building_tier(hall, 2).ok, "the hall is upgraded")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "a tier drift is caught")
	assert_true(_store.set_building_tier(hall, 1).ok, "and back")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_NONE, "which matches again")
	assert_true(_store.demolish_building(well).ok, "the well goes")
	var turned: Buildings.OpResult = _store.place_building(int(Catalog.BUILDING_DEFINITION["well"]),
		_tile(64, 54), 1, START_MASK)
	assert_true(turned.ok, "and returns turned a quarter on the same square footprint")
	assert_true(_store.set_building_state(turned.ref, int(Catalog.BUILDING_STATE["ACTIVE"])).ok,
		"ACTIVE")
	_applied.building_slot[5] = turned.ref.x
	_applied.building_generation[5] = turned.ref.y
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "a rotation drift is caught")
	assert_true(_store.remove_furniture(_applied.furniture_ref(30)).ok, "remove the last shelf")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "a missing piece is caught")


func test_room_and_furniture_drift_are_caught() -> void:
	"""A room re-designated over other tiles, or a piece in another room, is not the plan."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	var swapped: StarterColony.Applied = StarterColony.Applied.new()
	swapped.building_slot = _applied.building_slot.duplicate()
	swapped.building_generation = _applied.building_generation.duplicate()
	swapped.room_slot = _applied.room_slot.duplicate()
	swapped.room_generation = _applied.room_generation.duplicate()
	swapped.furniture_slot = _applied.furniture_slot.duplicate()
	swapped.furniture_generation = _applied.furniture_generation.duplicate()
	swapped.room_slot[1] = _applied.room_slot[2]
	swapped.room_generation[1] = _applied.room_generation[2]
	swapped.room_slot[2] = _applied.room_slot[1]
	swapped.room_generation[2] = _applied.room_generation[1]
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, swapped),
		StarterColony.REFUSE_PLAN_MISMATCH, "kitchen and common swapped is caught")
	var moved: StarterColony.Applied = StarterColony.Applied.new()
	moved.building_slot = _applied.building_slot.duplicate()
	moved.building_generation = _applied.building_generation.duplicate()
	moved.room_slot = _applied.room_slot.duplicate()
	moved.room_generation = _applied.room_generation.duplicate()
	moved.furniture_slot = _applied.furniture_slot.duplicate()
	moved.furniture_generation = _applied.furniture_generation.duplicate()
	moved.furniture_slot[0] = _applied.furniture_slot[1]
	moved.furniture_generation[0] = _applied.furniture_generation[1]
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, moved),
		StarterColony.REFUSE_PLAN_MISMATCH, "a bed one tile over is caught")


func test_the_apply_is_deterministic_over_a_fresh_store() -> void:
	"""Same plan, same empty directory: identical refs, identical tile maps."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the first colony applies")
	var other: Buildings = Buildings.new()
	var other_applied: StarterColony.Applied = StarterColony.Applied.new()
	assert_equal(StarterColony.apply_into(other, _plan, START_MASK, other_applied),
		StarterColony.REFUSE_NONE, "the second applies")
	assert_equal(other_applied.building_slot, _applied.building_slot, "building slots agree")
	assert_equal(other_applied.room_slot, _applied.room_slot, "room slots agree")
	assert_equal(other_applied.furniture_generation, _applied.furniture_generation,
		"furniture generations agree")
	var maps: Array[PackedInt32Array] = _maps(_store)
	var other_maps: Array[PackedInt32Array] = _maps(other)
	for index: int in 3:
		assert_true(maps[index] == other_maps[index], "tile map %d is byte-identical" % index)


func _maps(store: Buildings) -> Array[PackedInt32Array]:
	"""The three section 1 tile maps of `store`."""
	var building_slot: PackedInt32Array = PackedInt32Array()
	var room_slot: PackedInt32Array = PackedInt32Array()
	var furniture_slot: PackedInt32Array = PackedInt32Array()
	building_slot.resize(Buildings.TILE_COUNT)
	room_slot.resize(Buildings.TILE_COUNT)
	furniture_slot.resize(Buildings.TILE_COUNT)
	assert_true(store.copy_section_1_columns_into(building_slot, room_slot, furniture_slot), "copy")
	return [building_slot, room_slot, furniture_slot]


func test_interior_tiles_map_to_the_exterior_grid() -> void:
	"""Local `z*10+x` plus the (1,1) inset: local 0 -> (59,60), local 79 -> (68,67)."""
	var hall: int = _tile(58, 59)
	assert_equal(StarterColony.interior_to_global(0, hall), _tile(59, 60), "the first cell")
	assert_equal(StarterColony.interior_to_global(9, hall), _tile(68, 60), "the end of row 0")
	assert_equal(StarterColony.interior_to_global(10, hall), _tile(59, 61), "the start of row 1")
	assert_equal(StarterColony.interior_to_global(79, hall), _tile(68, 67), "the last cell")
	assert_equal(StarterColony.hall_row_of(_plan), 0, "the plan's hall is building row 0")
	var reordered: StarterStructures.Plan = StarterStructures.Plan.new()
	reordered.set_building_field(3, StarterStructures.Plan.BUILDING_COL_TYPE_ID,
		int(Catalog.BUILDING_DEFINITION["hall"]))
	assert_equal(StarterColony.hall_row_of(reordered), 3, "and is found by type, not by position")
	assert_equal(StarterColony.hall_row_of(StarterStructures.Plan.new()), -1,
		"a plan with no hall has no hall row")


# --- refusals change nothing --------------------------------------------------------------------

func test_an_occupied_footprint_refuses_before_anything_is_placed() -> void:
	"""A well inside the LAST building's footprint stops the whole apply before the first row.

	The workbench is plan row 6, so an apply that placed as it went would leave six buildings
	behind before meeting the conflict; the preflight must find it first.
	"""
	assert_true(_store.place_building(int(Catalog.BUILDING_DEFINITION["well"]), _tile(59, 55), 0,
		START_MASK).ok, "a stray well stands inside the workbench's footprint")
	var before: PackedInt32Array = _snapshot()
	assert_equal(_apply(), Buildings.REFUSE_FOOTPRINT_OCCUPIED, "the apply refuses")
	assert_equal(_snapshot(), before, "and placed nothing")


func test_a_locked_mask_and_missing_inputs_refuse_without_writing() -> void:
	"""No mask, no store, no plan, a malformed plan: each refused, the store untouched."""
	var before: PackedInt32Array = _snapshot()
	var locked: StringName = StarterColony.preflight_refusal(_store, _plan, Milestones.EMPTY_MASK)
	assert_true(locked != StarterColony.REFUSE_NONE, "an empty milestone mask places nothing")
	assert_equal(StarterColony.apply_into(_store, _plan, Milestones.EMPTY_MASK, _applied), locked,
		"and the apply returns the preflight's own refusal")
	assert_equal(StarterColony.preflight_refusal(null, _plan, START_MASK),
		StarterColony.REFUSE_STORE_NULL, "no store")
	assert_equal(StarterColony.preflight_refusal(_store, null, START_MASK),
		StarterColony.REFUSE_PLAN_NULL, "no plan")
	var bent: StarterStructures.Plan = StarterStructures.Plan.new()
	assert_true(StarterStructures.new().prepare_into(bent), "a second plan")
	bent.set_building_field(5, StarterStructures.Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE, _tile(64, 53))
	assert_equal(StarterColony.preflight_refusal(_store, bent, START_MASK),
		StarterStructures.REFUSE_AUTHORED_LAYOUT, "a moved well is not the authored refuge")
	assert_equal(_snapshot(), before, "nothing was written by any of them")


func test_a_full_building_directory_refuses_by_capacity_before_placing() -> void:
	"""With six building rows left, the seventh cannot be had, so none is placed."""
	var well: int = int(Catalog.BUILDING_DEFINITION["well"])
	var placed: int = 0
	while placed < Buildings.BUILDING_CAPACITY - 6:
		@warning_ignore("integer_division")
		var z: int = (placed / 64) * 2
		assert_true(_store.place_building(well, _tile((placed % 64) * 2, z), 0, START_MASK).ok,
			"filler well %d" % placed)
		placed += 1
	var before: PackedInt32Array = _snapshot()
	assert_equal(_apply(), StarterColony.REFUSE_DIRECTORY_CAPACITY, "the apply refuses")
	assert_equal(_snapshot(), before, "and placed nothing")


func test_a_footprint_over_a_live_ground_pile_refuses_through_the_placement_authority() -> void:
	"""Decision 0532 M4: a pile on a hall tile refuses the whole colony by name."""
	var inventory: Inventory = Inventory.new(16, 16)
	inventory.register_item(1, 1000, 0)
	var piles: GroundPiles = GroundPiles.new()
	assert_true(piles.bind_stores(inventory, _store, StockAge.new(inventory, null)), "bind stores")
	assert_true(piles.bind_world(_store.directory().create(EntityDirectory.KIND_WORLD)), "a World")
	assert_true(_store.set_placement_authority(piles).ok, "the composer guards placement")
	var out: GroundPiles.PlaceResult = GroundPiles.PlaceResult.new()
	assert_true(piles.place_lots_into_piles(_tile(59, 55), PackedByteArray(),
		PackedInt64Array([1, 1000, 0, 0, 0, 0, 0]), out), "a pile lands on the workbench's site")
	var before: PackedInt32Array = _snapshot()
	assert_equal(_apply(), GroundPiles.REFUSE_BUILDING_OVER_PILE, "the apply refuses by name")
	assert_equal(_snapshot(), before, "and placed nothing")


# --- the store binding --------------------------------------------------------------------------

func test_the_binding_names_the_hall_and_the_four_stockpiles_at_their_origins() -> void:
	"""#7's owners and #3a's anchors, read back from the live rows in plan order."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	var binding: StarterColony.StoreBinding = StarterColony.StoreBinding.new()
	assert_equal(StarterColony.store_binding_into(_store, _plan, binding), StarterColony.REFUSE_NONE,
		"the binding reads back")
	assert_equal(binding.pantry_owner, _store.building_at_tile(_tile(58, 59)), "the hall")
	assert_equal(binding.pantry_anchor_tile, _tile(58, 59), "at the hall's origin")
	var origins: Array[int] = [_tile(50, 60), _tile(50, 65), _tile(70, 60), _tile(70, 65)]
	for index: int in StarterColony.STOCKPILE_COUNT:
		assert_equal(binding.stockpile_owner(index), _store.building_at_tile(origins[index]),
			"stockpile %d" % index)
		assert_equal(binding.stockpile_anchor_tile[index], origins[index], "at its origin")
	assert_true(binding.is_complete(), "and the binding is complete")


func test_no_binding_without_the_colony_standing() -> void:
	"""An empty store, or one with a stockpile demolished, binds nothing and clears the output."""
	var binding: StarterColony.StoreBinding = StarterColony.StoreBinding.new()
	binding.pantry_anchor_tile = 5
	assert_equal(StarterColony.store_binding_into(_store, _plan, binding),
		StarterColony.REFUSE_NOT_PLACED, "an empty store binds nothing")
	assert_equal(binding.pantry_anchor_tile, -1, "and the output is cleared")
	assert_equal(StarterColony.store_binding_into(null, _plan, binding),
		StarterColony.REFUSE_NOT_PLACED, "nor does a missing store")
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_true(_store.demolish_building(_applied.building_ref(4)).ok, "the last stockpile goes")
	assert_equal(StarterColony.store_binding_into(_store, _plan, binding),
		StarterColony.REFUSE_NOT_PLACED, "three stockpiles are not four")
	assert_false(binding.is_complete(), "and the binding is left incomplete")


func test_an_impostor_at_a_planned_origin_does_not_bind() -> void:
	"""A building of another type on a stockpile's origin is not that stockpile."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_true(_store.demolish_building(_applied.building_ref(4)).ok, "the last stockpile goes")
	var impostor: Buildings.OpResult = _store.place_building(int(Catalog.BUILDING_DEFINITION["well"]),
		_tile(70, 65), 0, START_MASK)
	assert_true(impostor.ok, "a well stands on the fourth stockpile's origin")
	var binding: StarterColony.StoreBinding = StarterColony.StoreBinding.new()
	assert_equal(StarterColony.store_binding_into(_store, _plan, binding),
		StarterColony.REFUSE_NOT_PLACED, "it does not bind as a stockpile")


func test_a_building_of_another_type_on_a_planned_origin_is_caught() -> void:
	"""Same origin, rotation, tier and state, another type: still not the plan."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_true(_store.demolish_building(_applied.building_ref(5)).ok, "the well goes")
	var other: Buildings.OpResult = _store.place_building(
		int(Catalog.BUILDING_DEFINITION["workbench"]), _tile(64, 54), 0, START_MASK)
	assert_true(other.ok, "a workbench takes the well's origin")
	assert_true(_store.set_building_state(other.ref, int(Catalog.BUILDING_STATE["ACTIVE"])).ok,
		"and is ACTIVE")
	_applied.building_slot[5] = other.ref.x
	_applied.building_generation[5] = other.ref.y
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the type drift is caught")


func test_a_piece_of_another_type_or_rotation_on_a_planned_tile_is_caught() -> void:
	"""A shelf where a seat was planned, or a bed turned a quarter, is not the plan."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	var seat_tile: int = _interior(6, 2)
	assert_true(_store.remove_furniture(_applied.furniture_ref(11)).ok, "the first seat goes")
	var shelf: Buildings.OpResult = _store.place_furniture(_applied.room_ref(2),
		int(Catalog.FURNITURE_DEFINITION["shelf"]), seat_tile, 0)
	assert_true(shelf.ok, "a shelf takes its tile")
	_applied.furniture_slot[11] = shelf.ref.x
	_applied.furniture_generation[11] = shelf.ref.y
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the type drift is caught")
	assert_true(_store.remove_furniture(shelf.ref).ok, "the shelf goes")
	var seat: Buildings.OpResult = _store.place_furniture(_applied.room_ref(2),
		int(Catalog.FURNITURE_DEFINITION["seat"]), seat_tile, 1)
	assert_true(seat.ok, "a seat turned a quarter takes the tile")
	_applied.furniture_slot[11] = seat.ref.x
	_applied.furniture_generation[11] = seat.ref.y
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the rotation drift is caught")


func test_a_plan_naming_a_fifth_stockpile_does_not_bind() -> void:
	"""The binding has four stockpile cells; a fifth planned stockpile refuses, it never overflows."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	var five: StarterStructures.Plan = StarterStructures.Plan.new()
	assert_true(StarterStructures.new().prepare_into(five), "a second plan")
	five.set_building_field(5, StarterStructures.Plan.BUILDING_COL_TYPE_ID,
		int(Catalog.BUILDING_DEFINITION["open_stockpile"]))
	var binding: StarterColony.StoreBinding = StarterColony.StoreBinding.new()
	assert_equal(StarterColony.store_binding_into(_store, five, binding),
		StarterColony.REFUSE_NOT_PLACED, "five planned stockpiles are not four")
	assert_false(binding.is_complete(), "and the binding is left cleared")


func test_a_room_whose_tiles_run_in_another_order_is_caught() -> void:
	"""Same type, same count, same tile SET, another order: the saved run is not the plan's.

	The pantry is re-designated over its five tiles back to front and its four shelves are put
	back, so only the room's tile run differs; designating it again in plan order matches.
	"""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	_redesignate_pantry(true, "PANTRY")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the reversed run is caught")
	_redesignate_pantry(false, "PANTRY")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_NONE, "the plan-order run matches again")
	_redesignate_pantry(false, "COMMON")
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the same run under another room type is caught")


func _redesignate_pantry(reverse: bool, room_key: String) -> void:
	"""Remove the pantry's shelves and room, then rebuild both, updating `_applied`."""
	var hall: Vector2i = _applied.building_ref(0)
	for row: int in range(27, 31):
		assert_true(_store.remove_furniture(_applied.furniture_ref(row)).ok, "shelf %d goes" % row)
	assert_true(_store.remove_room(_applied.room_ref(3)).ok, "the pantry room goes")
	var tiles: PackedInt32Array = PackedInt32Array()
	for local_x: int in range(5, 10):
		tiles.append(_interior(local_x, 7))
	if reverse:
		tiles.reverse()
	var room: Buildings.OpResult = _store.designate_room(hall, int(Catalog.ROOM_TYPE[room_key]), tiles)
	assert_true(room.ok, "the pantry is designated again")
	_applied.room_slot[3] = room.ref.x
	_applied.room_generation[3] = room.ref.y
	for row: int in range(27, 31):
		var shelf: Buildings.OpResult = _store.place_furniture(room.ref,
			int(Catalog.FURNITURE_DEFINITION["shelf"]), _interior(row - 21, 7), 0)
		assert_true(shelf.ok, "shelf %d returns" % row)
		_applied.furniture_slot[row] = shelf.ref.x
		_applied.furniture_generation[row] = shelf.ref.y


func test_a_stockpile_covering_a_planned_origin_from_elsewhere_does_not_bind() -> void:
	"""A stockpile whose footprint covers the planned origin but starts elsewhere is not the one."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_true(_store.demolish_building(_applied.building_ref(4)).ok, "the last stockpile goes")
	var shifted: Buildings.OpResult = _store.place_building(
		int(Catalog.BUILDING_DEFINITION["open_stockpile"]), _tile(70, 64), 0, START_MASK)
	assert_true(shifted.ok, "a stockpile from (70,64) covers (70,65)")
	assert_equal(_store.building_at_tile(_tile(70, 65)), shifted.ref, "it stands on the origin")
	var binding: StarterColony.StoreBinding = StarterColony.StoreBinding.new()
	assert_equal(StarterColony.store_binding_into(_store, _plan, binding),
		StarterColony.REFUSE_NOT_PLACED, "but its origin is not the plan's, so it does not bind")


func test_a_building_covering_its_planned_origin_from_elsewhere_is_caught() -> void:
	"""Same type and tile ownership at the origin, but another origin: not the planned building."""
	assert_equal(_apply(), StarterColony.REFUSE_NONE, "the colony applies")
	assert_true(_store.demolish_building(_applied.building_ref(4)).ok, "the last stockpile goes")
	var shifted: Buildings.OpResult = _store.place_building(
		int(Catalog.BUILDING_DEFINITION["open_stockpile"]), _tile(70, 64), 0, START_MASK)
	assert_true(shifted.ok, "a stockpile from (70,64) covers (70,65)")
	assert_true(_store.set_building_state(shifted.ref, int(Catalog.BUILDING_STATE["ACTIVE"])).ok,
		"ACTIVE")
	_applied.building_slot[4] = shifted.ref.x
	_applied.building_generation[4] = shifted.ref.y
	assert_equal(StarterColony.plan_mismatch_refusal(_store, _plan, _applied),
		StarterColony.REFUSE_PLAN_MISMATCH, "the origin drift is caught")
