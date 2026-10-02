extends "res://test/framework/test_case.gd"
## Decision 0536 (Brendan's P2 ruling): one piece of furniture taken out of a standing building.
##
## `preview_furniture_removal()`, `request_furniture_removal()` (preview + admit),
## `complete_furniture_removal()` and `cancel_furniture_removal()` reuse D4's admit and D5's commit
## with the piece as subject. The piece's return is 50% of its type's bill (P1), its work a quarter
## of its WU, and a shelf in a pantry room takes its 50000 g out of the building's pantry store
## (DEMO-CONTAIN-R01 #3b), refusing when the contents and claims would no longer fit. Every refusal
## is byte-identical across every store the coordinator composes.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DemolitionAdmissionsScript := preload("res://scripts/core/demolition_admissions.gd")

const HALL_X: int = 20
const HALL_Z: int = 20
const HALL_TILE: int = HALL_Z * 128 + HALL_X
const INSIDE_TILE: int = (HALL_Z + 4) * 128 + HALL_X + 5
const INSIDE_TILE_2: int = (HALL_Z + 4) * 128 + HALL_X + 7
## Four tiles of one pantry row inside the hall.
const PANTRY_TILES: Array[int] = [
	(HALL_Z + 6) * 128 + HALL_X + 2, (HALL_Z + 6) * 128 + HALL_X + 3,
	(HALL_Z + 6) * 128 + HALL_X + 4, (HALL_Z + 6) * 128 + HALL_X + 5,
]
const DOOR_TILE: int = (HALL_Z + 10) * 128 + HALL_X + 6
const DEPOT_TILE: int = 60 * 128 + 90
const START_MASK: int = 1
## A bed's 50%: 1 U of wood (5000 g) and 0.5 U of cloth (125 g).
const BED_RETURN_G: int = 5000 + 125

var _settlement: SettlementSystemScript = null


func before_each() -> void:
	"""A bare settlement outside the tree."""
	_settlement = SettlementSystemScript.new()


func after_each() -> void:
	"""Free it."""
	if _settlement != null:
		_settlement.free()
		_settlement = null


# --- fixtures --------------------------------------------------------------------------------

func _place_active(key: String, tile: int) -> Vector2i:
	"""Place one ACTIVE building of `key` at `tile`."""
	var placed: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION[key]), tile, 0, START_MASK)
	assert_true(placed.ok, "%s places (%s)" % [key, placed.error])
	assert_true(_settlement.buildings().set_building_state(placed.ref,
		ConstructionScript.STATE_ACTIVE).ok, "%s is ACTIVE" % key)
	return placed.ref


func _store(owner_ref: Vector2i, anchor: int, mass_g: int = 500000) -> Vector2i:
	"""One accept-all container keyed to `owner_ref`, anchored at `anchor`."""
	var made: InventoryScript.OpResult = _settlement.inventory().create_container(owner_ref,
		mass_g, InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, anchor)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _depot_store() -> Vector2i:
	"""A store owned by another ACTIVE building."""
	return _store(_place_active("covered_store", DEPOT_TILE), DEPOT_TILE)


func _piece(room: Vector2i, key: String, tile: int) -> Vector2i:
	"""Place one piece of `key` in `room` on `tile`."""
	var made: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room,
		int(CatalogScript.FURNITURE_DEFINITION[key]), tile, 0)
	assert_true(made.ok, "a %s is placed (%s)" % [key, made.error])
	return made.ref


func _hall_with_bed() -> Vector2i:
	"""A hall with one dormitory holding one bed; returns the bed."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE, INSIDE_TILE + 1]))
	assert_true(room.ok, "a dormitory (%s)" % room.error)
	return _piece(room.ref, "bed", INSIDE_TILE)


func _pantry(hall: Vector2i, valid: bool) -> Vector2i:
	"""A four-tile PANTRY room in `hall`, set valid or not, holding four shelves; the room."""
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["PANTRY"]), PackedInt32Array(PANTRY_TILES))
	assert_true(room.ok, "a pantry (%s)" % room.error)
	for tile: int in PANTRY_TILES:
		_piece(room.ref, "shelf", tile)
	assert_true(_settlement.buildings().set_room_valid(room.ref, valid).ok, "validity set")
	return room.ref


func _first_shelf(room: Vector2i) -> Vector2i:
	"""The first shelf in a room's chain."""
	var buildings: BuildingsScript = _settlement.buildings()
	return buildings.furniture_ref_of_row(buildings.furniture_rows_in_room(room)[0])


func _fill(store: Vector2i, grams: int) -> void:
	"""Put `grams` of grain (1 g per milli at 1000 g/U) into `store`."""
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var mass: int = _settlement.inventory().item_mass_g(grain)
	@warning_ignore("integer_division") var milli: int = grams * 1000 / mass
	assert_true(_settlement.inventory().create_lot(store, grain, milli, 0, 0, 0, 0, 0).ok, "filled")


func _bind_world() -> void:
	"""The World row, bound to the ground-pile composer."""
	var world: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_WORLD)
	assert_true(_settlement.ground_piles().bind_world(world), "the composer binds the World")


func _admitted(piece: Vector2i) -> SettlementSystemScript.DemolitionReport:
	"""Admit a piece's removal through the coordinator."""
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_furniture_removal(piece)
	assert_true(report.ok, "the removal is admitted (%s)" % report.error)
	return report


func _finish_work(project: Vector2i) -> void:
	"""Begin and complete a removal's work."""
	var remaining: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().begin_work(project).ok, "work begins")
	assert_true(_settlement.construction().remaining_mwu_into(project, remaining), "remainder")
	assert_true(_settlement.construction().add_work_mwu(project, remaining.value).ok, "work done")


func _admit_and_finish(piece: Vector2i) -> Vector2i:
	"""Admit, then finish; the project."""
	var project: Vector2i = _admitted(piece).project_ref
	_finish_work(project)
	return project


func _milli_of(container: Vector2i, item_key: StringName) -> int:
	"""Total milli-U of one item in one container."""
	var item: int = _settlement.item_definitions().compiled_id(item_key)
	var inventory: InventoryScript = _settlement.inventory()
	var total: int = 0
	var lot: Vector2i = inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		total += inventory.lot_quantity_milli(lot) if inventory.lot_item_id(lot) == item else 0
		lot = inventory.container_next_lot(lot)
	return total


func _snapshot() -> PackedByteArray:
	"""Every store a removal could write, furniture and rooms included."""
	var out: PackedByteArray = _settlement.construction().state_bytes()
	out.append_array(_settlement.inventory().state_bytes())
	out.append_array(_settlement.directory().state_bytes())
	out.append_array(_settlement.demolition_admissions().state_bytes())
	var buildings: BuildingsScript = _settlement.buildings()
	out.append_array(var_to_bytes(PackedInt64Array([buildings.live_building_count(),
		buildings.live_room_count(), buildings.live_furniture_count(),
		_settlement.stock_age().declared_container_count()])))
	for tile: int in BuildingsScript.TILE_COUNT:
		var occupant: Vector2i = buildings.building_at_tile(tile)
		if occupant != EntityDirectoryScript.NULL_REF:
			out.append_array(var_to_bytes(PackedInt64Array([tile, occupant.x,
				buildings.state_of_building(occupant).value, buildings.furniture_at_tile(tile).x])))
	return out


# --- the success paths ---------------------------------------------------------------------------

func test_a_bed_is_removed_and_its_half_lands_in_another_buildings_store() -> void:
	"""Admit reserves the bed's 50%; the commit takes the bed out and places the return."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var depot: Vector2i = _depot_store()
	var revision: int = _settlement.demolition_admissions().destination_revision_of(hall)
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(bed)
	assert_equal(admitted.output_container, depot, "into the other building's store")
	assert_equal(admitted.output_reserved_g, BED_RETURN_G, "reserving the bed's half")
	assert_equal(admitted.destination_revision, revision + 1, "the hall's revision advanced")
	var remaining: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().remaining_mwu_into(admitted.project_ref, remaining), "")
	@warning_ignore("integer_division") var quarter: int = _settlement.building_definitions().furniture_work_mwu_of(
		int(CatalogScript.FURNITURE_DEFINITION["bed"])) / 4
	assert_equal(remaining.value, quarter, "a quarter of the bed's WU")
	_finish_work(admitted.project_ref)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_furniture_removal(bed)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_false(_settlement.buildings().is_live_furniture(bed), "the bed is gone")
	assert_true(_settlement.buildings().is_live_building(hall), "the hall stands")
	assert_equal(_settlement.buildings().state_of_building(hall).value,
		ConstructionScript.STATE_ACTIVE, "ACTIVE")
	assert_equal(_settlement.buildings().live_room_count(), 1, "its room stays")
	assert_equal(report.removed_furniture_count, 1, "one piece")
	assert_equal(_milli_of(depot, &"wood"), 1000, "half the bed's wood")
	assert_equal(_milli_of(depot, &"cloth"), 500, "half its cloth")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")
	assert_equal(_settlement.construction().live_project_count(), 0, "the project retired")
	assert_equal(report.destination_revision, revision + 2, "and the revision advanced again")
	assert_true(_settlement.inventory().audit().ok, "audits")


func test_with_no_store_the_pieces_half_lands_on_ground_piles_at_the_door() -> void:
	"""The building's refund seeds; storage class 1500 after the commit."""
	var bed: Vector2i = _hall_with_bed()
	_bind_world()
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(bed)
	assert_true(admitted.output_to_ground_piles, "onto piles")
	_finish_work(admitted.project_ref)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_furniture_removal(bed)
	assert_true(report.ok, "completes (%s)" % report.error)
	var pile: Vector2i = _settlement.inventory().ground_pile_at_tile(DOOR_TILE)
	assert_true(_settlement.inventory().is_ground_pile(pile), "outside the hall's door")
	assert_equal(_settlement.stock_age().storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE,
		"declared 1500")
	assert_equal(_milli_of(pile, &"wood"), 1000, "half the bed's wood")


func test_a_piece_owned_store_is_destroyed_with_it() -> void:
	"""(1) for one piece: its own empty store goes."""
	var bed: Vector2i = _hall_with_bed()
	var chest: Vector2i = _store(bed, INSIDE_TILE)
	_depot_store()
	_admit_and_finish(bed)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_furniture_removal(bed)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_false(_settlement.inventory().is_container_valid(chest), "the bed's store is gone")
	assert_equal(report.destroyed_container_count, 1, "exactly one")


# --- #3b: the pantry shelf ------------------------------------------------------------------------

func test_a_shelf_in_a_valid_pantry_takes_its_capacity_with_it() -> void:
	"""#3b: 200000 g with four shelves becomes 150000 g once one goes."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var pantry: Vector2i = _store(hall, HALL_TILE, 200000)
	var room: Vector2i = _pantry(hall, true)
	_fill(pantry, 150000)
	_depot_store()
	var shelf: Vector2i = _first_shelf(room)
	_admit_and_finish(shelf)
	assert_equal(_settlement.inventory().container_max_mass_g(pantry), 200000, "not yet reduced")
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_furniture_removal(shelf)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_equal(_settlement.inventory().container_max_mass_g(pantry), 150000, "reduced at commit")
	assert_true(_settlement.inventory().audit().ok, "and the full store still audits")


func test_a_shelf_whose_removal_would_overfill_the_pantry_refuses() -> void:
	"""#3b's refusal, by name, naming the store, writing nothing."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var pantry: Vector2i = _store(hall, HALL_TILE, 200000)
	var room: Vector2i = _pantry(hall, true)
	_fill(pantry, 150000)
	assert_true(_settlement.inventory().reserve_container_mass(pantry, 1).ok, "one gram claimed")
	_depot_store()
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_furniture_removal(
		_first_shelf(room))
	assert_equal(report.error, SettlementSystemScript.REFUSE_REMOVAL_PANTRY_OVER_CAPACITY,
		"150001 g would not fit 150000 g")
	assert_equal(report.blocking_container, pantry, "naming the pantry store")
	assert_true(_snapshot() == before, "byte-identical")


func test_goods_that_arrive_after_admission_can_block_the_shelfs_commit() -> void:
	"""#3b again at the commit: commit-pending until the pantry has room again."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var pantry: Vector2i = _store(hall, HALL_TILE, 200000)
	var room: Vector2i = _pantry(hall, true)
	_depot_store()
	var shelf: Vector2i = _first_shelf(room)
	var project: Vector2i = _admit_and_finish(shelf)
	_fill(pantry, 160000)
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_furniture_removal(shelf).error,
		SettlementSystemScript.REFUSE_REMOVAL_PANTRY_OVER_CAPACITY, "refused")
	assert_true(_snapshot() == before, "byte-identical")
	var phase: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().phase_into(project, phase), "phase")
	assert_equal(phase.value, ConstructionScript.PHASE_WORK_DONE, "commit-pending")


func test_a_shelf_in_a_pantry_not_yet_valid_carries_its_capacity_too() -> void:
	"""#3b's words: a shelf in a PANTRY room carries 50000 g, valid or not (review H2, 0536)."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var pantry: Vector2i = _store(hall, HALL_TILE, 200000)
	var room: Vector2i = _pantry(hall, false)
	_fill(pantry, 150001)
	_depot_store()
	var shelf: Vector2i = _first_shelf(room)
	assert_equal(_settlement.request_furniture_removal(shelf).error,
		SettlementSystemScript.REFUSE_REMOVAL_PANTRY_OVER_CAPACITY, "150001 g would not fit 150000")


func test_a_kitchen_shelf_and_a_pantry_seat_carry_no_pantry_capacity() -> void:
	"""R-BUILD-DOM-004: the kitchen's shelf adds nothing; a seat is not a shelf. 200000 g stays."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var pantry: Vector2i = _store(hall, HALL_TILE, 200000)
	var room: Vector2i = _pantry(hall, true)
	_fill(pantry, 150000)
	_depot_store()
	var kitchen: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["KITCHEN"]), PackedInt32Array([INSIDE_TILE_2]))
	assert_true(kitchen.ok, "a kitchen (%s)" % kitchen.error)
	var kitchen_shelf: Vector2i = _piece(kitchen.ref, "shelf", INSIDE_TILE_2)
	_admit_and_finish(kitchen_shelf)
	assert_true(_settlement.complete_furniture_removal(kitchen_shelf).ok, "the kitchen shelf goes")
	assert_equal(_settlement.inventory().container_max_mass_g(pantry), 200000, "unchanged")
	var shelf: Vector2i = _first_shelf(room)
	var freed: int = _settlement.buildings().origin_tile_of_furniture(shelf).value
	_admit_and_finish(shelf)
	assert_true(_settlement.complete_furniture_removal(shelf).ok, "a pantry shelf goes")
	var seat: Vector2i = _piece(room, "seat", freed)
	_admit_and_finish(seat)
	assert_true(_settlement.complete_furniture_removal(seat).ok, "a seat goes")
	assert_equal(_settlement.inventory().container_max_mass_g(pantry), 150000,
		"only the pantry shelf took capacity")


func test_a_valid_pantry_with_no_single_main_store_refuses() -> void:
	"""The reduction needs THE building's main store: none, or two at its origin, refuse."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: Vector2i = _pantry(hall, true)
	_depot_store()
	assert_equal(_settlement.preview_furniture_removal(_first_shelf(room)).error,
		SettlementSystemScript.REFUSE_REMOVAL_PANTRY_STORE, "none")
	_store(hall, INSIDE_TILE, 200000)
	assert_equal(_settlement.preview_furniture_removal(_first_shelf(room)).error,
		SettlementSystemScript.REFUSE_REMOVAL_PANTRY_STORE, "one off the origin is not the main store")
	_store(hall, HALL_TILE, 200000)
	assert_true(_settlement.preview_furniture_removal(_first_shelf(room)).ok,
		"exactly one at the origin passes, the other store notwithstanding")
	_store(hall, HALL_TILE, 200000)
	assert_equal(_settlement.preview_furniture_removal(_first_shelf(room)).error,
		SettlementSystemScript.REFUSE_REMOVAL_PANTRY_STORE, "two at the origin")


# --- refusals ---------------------------------------------------------------------------------

func test_the_preview_refuses_by_name_writing_nothing() -> void:
	"""Stale, a building not ACTIVE, a piece under construction, in use, its goods, its claim."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.preview_furniture_removal(Vector2i(7, 1)).error,
		SettlementSystemScript.REFUSE_REMOVAL_STALE_PIECE, "stale")
	assert_true(_snapshot() == before, "byte-identical")
	var resident: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_settlement.buildings().set_furniture_user(bed, resident).ok, "in use")
	before = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_furniture_removal(bed)
	assert_equal(report.error, ConstructionScript.REFUSE_FURNITURE_IN_USE, "in use")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(report.furniture_user_count, 1, "counted")
	assert_true(_settlement.buildings().set_furniture_user(bed, EntityDirectoryScript.NULL_REF).ok, "")
	var chest: Vector2i = _store(bed, INSIDE_TILE)
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var lot: InventoryScript.OpResult = _settlement.inventory().create_lot(chest, grain, 1000,
		0, 0, 0, 0, 0)
	report = _settlement.preview_furniture_removal(bed)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS, "its goods")
	assert_equal(report.stranded_lot_at(0), lot.ref, "named")
	assert_true(_settlement.inventory().sink_lot_quantity(lot.ref, 1000).ok, "goods gone")
	assert_true(_settlement.inventory().reserve_container_mass(chest, 5).ok, "a claim")
	assert_equal(_settlement.preview_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_DEMOLITION_CAPACITY_CLAIM, "its claim")
	assert_true(_settlement.buildings().set_building_state(hall,
		ConstructionScript.STATE_DEMOLISHING).ok, "the hall is coming down")
	before = _snapshot()
	assert_equal(_settlement.preview_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_REMOVAL_BUILDING_NOT_ACTIVE, "not ACTIVE")
	assert_true(_snapshot() == before, "byte-identical")


func test_a_piece_under_construction_refuses() -> void:
	"""Its own FURNITURE project is live: not completed capital (0536)."""
	var bed: Vector2i = _hall_with_bed()
	assert_true(_settlement.construction().open_furniture(bed).ok, "its project")
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_furniture_removal(bed)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNDER_CONSTRUCTION,
		"refused")
	assert_equal(report.blocking_furniture, bed, "naming it")


func test_one_admission_per_building() -> void:
	"""A piece's removal blocks a second piece's and the building's own demolition, and back."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var seat: Vector2i = _piece(_settlement.buildings().room_ref_of_furniture(bed), "seat",
		INSIDE_TILE + 1)
	_depot_store()
	_admitted(bed)
	assert_equal(_settlement.request_furniture_removal(seat).error,
		DemolitionAdmissionsScript.REFUSE_ALREADY_ADMITTED, "a second piece waits")
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNDER_CONSTRUCTION,
		"the hall's demolition waits for the bed's removal")
	assert_equal(_settlement.cancel_furniture_removal(bed), &"", "the removal is cancelled")
	assert_true(_settlement.request_furniture_removal(seat).ok, "now the seat may go")


func test_cancel_releases_the_claim_and_the_piece_stays() -> void:
	"""Free (R5): the claim released, the project retired, the bed still there, revision +1."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var depot: Vector2i = _depot_store()
	assert_equal(_settlement.cancel_furniture_removal(bed),
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_ADMITTED, "nothing to cancel yet")
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(bed)
	assert_equal(_settlement.cancel_furniture_removal(bed), &"", "cancelled")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")
	assert_true(_settlement.buildings().is_live_furniture(bed), "the bed stays")
	assert_equal(_settlement.construction().live_project_count(), 0, "retired")
	assert_equal(_settlement.demolition_admissions().destination_revision_of(hall),
		admitted.destination_revision + 1, "revision +1")
	assert_equal(_settlement.cancel_furniture_removal(Vector2i(7, 1)),
		SettlementSystemScript.REFUSE_REMOVAL_STALE_PIECE, "a stale piece")


func test_completion_refuses_until_done_and_without_the_coordinators_admission() -> void:
	"""WRONG_PHASE; NOT_ADMITTED for a store-level removal; STALE; all byte-identical."""
	var bed: Vector2i = _hall_with_bed()
	_depot_store()
	var project: Vector2i = _admitted(bed).project_ref
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		ConstructionScript.REFUSE_WRONG_PHASE, "not done")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_settlement.cancel_furniture_removal(bed), &"", "cancelled")
	var opened: ConstructionScript.OpResult = _settlement.construction().open_furniture_removal(bed)
	assert_true(opened.ok, "a store-level removal")
	_finish_work(opened.ref)
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_ADMITTED, "is not the coordinator's")
	assert_equal(_settlement.complete_furniture_removal(Vector2i(7, 1)).error,
		SettlementSystemScript.REFUSE_REMOVAL_STALE_PIECE, "stale")
	assert_false(project == opened.ref, "(two different projects)")


func test_completion_rechecks_users_goods_and_the_callers_transaction() -> void:
	"""The preview's checks run again at the commit, and a caller's transaction refuses."""
	var bed: Vector2i = _hall_with_bed()
	var chest: Vector2i = _store(bed, INSIDE_TILE)
	_depot_store()
	_admit_and_finish(bed)
	assert_true(_settlement.inventory().begin().ok, "a caller's transaction")
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_DEMOLITION_TRANSACTION, "refused")
	_settlement.inventory().abort()
	var resident: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_settlement.buildings().set_furniture_user(bed, resident).ok, "somebody lies down")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		ConstructionScript.REFUSE_FURNITURE_IN_USE, "in use")
	assert_true(_snapshot() == before, "byte-identical")
	assert_true(_settlement.buildings().set_furniture_user(bed, EntityDirectoryScript.NULL_REF).ok, "")
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var lot: InventoryScript.OpResult = _settlement.inventory().create_lot(chest, grain, 1000,
		0, 0, 0, 0, 0)
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS, "goods")
	assert_true(_settlement.inventory().sink_lot_quantity(lot.ref, 1000).ok, "gone again")
	assert_true(_settlement.complete_furniture_removal(bed).ok, "and the retry completes")


# --- review M1: a piece removed around the coordinator ------------------------------------------

func test_a_removal_orphaned_around_the_coordinator_is_released_through_the_stranded_door() -> void:
	"""The bed removed by the store door: nothing could complete or cancel; the stranded door can."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admitted(bed).project_ref
	assert_equal(_settlement.release_stranded_reservation(hall),
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_STRANDED, "not while the bed stands")
	assert_true(_settlement.buildings().remove_furniture(bed).ok, "the bed goes around it")
	assert_equal(_settlement.complete_furniture_removal(bed).error,
		SettlementSystemScript.REFUSE_REMOVAL_STALE_PIECE, "the coordinator's own door cannot")
	assert_equal(_settlement.release_stranded_reservation(hall), &"", "the stranded door can")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")
	assert_false(_settlement.construction().is_live_project(project), "the removal retired")
	assert_equal(_milli_of(depot, &"wood"), 0, "and nothing was returned for a piece nobody took")
	assert_true(_settlement.request_demolition(hall).ok, "the hall may be admitted again")


func test_an_orphaned_pile_removal_releases_its_record_too() -> void:
	"""A pile-fallback removal holds no grams; its record is still released."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	_bind_world()
	_admitted(bed)
	assert_true(_settlement.buildings().remove_furniture(bed).ok, "the bed goes around it")
	assert_equal(_settlement.release_stranded_reservation(hall), &"", "released")
	assert_equal(_settlement.demolition_admissions().project_of(hall),
		EntityDirectoryScript.NULL_REF, "no admission is left")


func test_an_abandoned_piece_commit_is_recovered_through_the_stranded_door() -> void:
	"""Review M1 (second pass): after the piece went, the guard re-records the admission on the
	building row, which is exactly the orphaned shape the stranded door releases."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admit_and_finish(bed)
	var charge: int = _settlement.demolition_admissions().admitted_charge_g_of(hall)
	assert_equal(_settlement._open_commit(hall, bed, depot, BED_RETURN_G), &"", "first block")
	assert_equal(_settlement.construction().remove_demolished_subject(project).error, &"",
		"the piece is gone")
	expect_diagnostic("a proved demolition commit refused a write")
	_settlement._abandon_commit(hall, project, depot, BED_RETURN_G, charge, &"TEST_FAULT")
	assert_equal(_settlement.demolition_admissions().project_of(hall), project, "re-recorded")
	assert_equal(_settlement.release_stranded_reservation(hall), &"", "and the stranded door frees it")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")
	assert_false(_settlement.construction().is_live_project(project), "the orphan retired")


func test_an_orphaned_removal_already_refunding_is_released_too() -> void:
	"""The orphan may already be in PHASE_REFUNDING; it is closed without a second begin_refund."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admitted(bed).project_ref
	assert_true(_settlement.construction().begin_refund(project).ok, "refunding around it")
	assert_true(_settlement.buildings().remove_furniture(bed).ok, "and the bed goes around it")
	assert_equal(_settlement.release_stranded_reservation(hall), &"", "released")
	assert_false(_settlement.construction().is_live_project(project), "retired")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")


func test_a_piece_project_opened_after_admission_blocks_the_buildings_commit() -> void:
	"""Review M2 (second pass): the commit re-runs the furniture-project refusal."""
	var bed: Vector2i = _hall_with_bed()
	var hall: Vector2i = _settlement.buildings().building_at_tile(HALL_TILE)
	_depot_store()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_true(report.ok, "admitted (%s)" % report.error)
	_finish_work(report.project_ref)
	assert_true(_settlement.construction().open_furniture(bed).ok, "a store-level piece project")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNDER_CONSTRUCTION, "refused")
	assert_true(_snapshot() == before, "byte-identical")


func test_an_admission_in_between_does_not_move_a_pieces_piles() -> void:
	"""Review M2 (second pass): the commit rebuilds the refund seeds for the piece's own building."""
	var bed: Vector2i = _hall_with_bed()
	_bind_world()
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(bed)
	assert_true(admitted.output_to_ground_piles, "onto piles")
	_finish_work(admitted.project_ref)
	assert_true(_settlement.request_demolition(_place_active("well", 50 * 128 + 30)).ok,
		"another building is admitted in between")
	assert_true(_settlement.complete_furniture_removal(bed).ok, "completes")
	var pile: Vector2i = _settlement.inventory().ground_pile_at_tile(DOOR_TILE)
	assert_equal(_milli_of(pile, &"wood"), 1000, "half the bed's wood, at the hall's own door")
