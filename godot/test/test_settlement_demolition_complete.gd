extends "res://test/framework/test_case.gd"
## DEMO-CONTAIN-R01 step D5 (decision 0535): the composed completion, `complete_demolition()`.
##
## #6's one no-yield commit: prove everything (the coordinator's own admitted project, its work
## done, its claim held; the gate's stages 2-5 again; the furniture rule; the return's placement),
## then destroy the affected containers, remove rooms, remove the building, place the 50% return
## and retire the project. Every refusal is byte-identical across Building, Room, Furniture,
## Construction, Inventory, StockAge, the directory and the admission record, and leaves the
## project PHASE_WORK_DONE so a retry costs nothing.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DemolitionAdmissionsScript := preload("res://scripts/core/demolition_admissions.gd")

const HALL_X: int = 20
const HALL_Z: int = 20
const HALL_TILE: int = HALL_Z * 128 + HALL_X
## Two tiles inside the hall's 12 x 10 footprint and its interior.
const INSIDE_TILE: int = (HALL_Z + 4) * 128 + HALL_X + 5
const INSIDE_TILE_2: int = (HALL_Z + 4) * 128 + HALL_X + 7
## GDD §5.9's hall door, outside the footprint: origin + (6, 10).
const DOOR_TILE: int = (HALL_Z + 10) * 128 + HALL_X + 6
const WELL_TILE: int = 50 * 128 + 30
const DEPOT_TILE: int = 60 * 128 + 90
const START_MASK: int = 1
## The hall's 50% return: wood 50 U and stone 30 U at 5000 g/U, cloth 6 U at 250 g/U.
const HALL_RETURN_G: int = 250000 + 150000 + 1500
## The well's: wood 5 U and stone 10 U.
const WELL_RETURN_G: int = 25000 + 50000

var _settlement: SettlementSystemScript = null


func before_each() -> void:
	"""A bare settlement outside the tree: no world, so no World row unless a test makes one."""
	_settlement = SettlementSystemScript.new()


func after_each() -> void:
	"""Free it."""
	if _settlement != null:
		_settlement.free()
		_settlement = null


# --- fixtures --------------------------------------------------------------------------------

func _place_active(key: String, tile: int) -> Vector2i:
	"""Place one building of `key` at `tile` and make it ACTIVE."""
	var placed: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION[key]), tile, 0, START_MASK)
	assert_true(placed.ok, "%s places (%s)" % [key, placed.error])
	assert_true(_settlement.buildings().set_building_state(placed.ref,
		ConstructionScript.STATE_ACTIVE).ok, "%s is ACTIVE" % key)
	return placed.ref


func _store(owner_ref: Vector2i, anchor: int, mass_g: int = 500000) -> Vector2i:
	"""One accept-all container keyed to `owner_ref` and anchored at `anchor`."""
	var made: InventoryScript.OpResult = _settlement.inventory().create_container(owner_ref,
		mass_g, InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, anchor)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _depot_store(mass_g: int = 500000) -> Vector2i:
	"""A store owned by another ACTIVE building away from the demolition."""
	return _store(_place_active("covered_store", DEPOT_TILE), DEPOT_TILE, mass_g)


func _bind_world() -> Vector2i:
	"""Create the World row and bind the ground-pile composer to it, as INIT-C does."""
	var world: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_WORLD)
	assert_true(_settlement.ground_piles().bind_world(world), "the composer binds the World")
	return world


func _room(building: Vector2i, tile: int) -> Vector2i:
	"""Designate a one-tile dormitory on `tile`."""
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(building,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([tile]))
	assert_true(room.ok, "a room is designated (%s)" % room.error)
	return room.ref


func _bed(room: Vector2i, tile: int) -> Vector2i:
	"""Place one bed in `room` on `tile`."""
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), tile, 0)
	assert_true(bed.ok, "a bed is placed (%s)" % bed.error)
	return bed.ref


func _admitted(building: Vector2i) -> SettlementSystemScript.DemolitionReport:
	"""Admit a demolition of `building` through the coordinator."""
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(building)
	assert_true(report.ok, "the demolition is admitted (%s)" % report.error)
	return report


func _finish_work(project: Vector2i) -> void:
	"""Begin and complete a demolition's work: it is then PHASE_WORK_DONE, commit-pending."""
	var remaining: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().begin_work(project).ok, "work begins")
	assert_true(_settlement.construction().remaining_mwu_into(project, remaining), "remainder")
	assert_true(_settlement.construction().add_work_mwu(project, remaining.value).ok, "work done")


func _admit_and_finish(building: Vector2i) -> Vector2i:
	"""Admit, then finish the work; return the project."""
	var project: Vector2i = _admitted(building).project_ref
	_finish_work(project)
	return project


func _phase_of(project: Vector2i) -> int:
	"""A live project's phase."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().phase_into(project, out), "the phase reads")
	return out.value


func _milli_of(container: Vector2i, item_key: StringName) -> int:
	"""Total milli-U of one item in one container's lots."""
	var item: int = _settlement.item_definitions().compiled_id(item_key)
	var inventory: InventoryScript = _settlement.inventory()
	var total: int = 0
	var lot: Vector2i = inventory.container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		total += inventory.lot_quantity_milli(lot) if inventory.lot_item_id(lot) == item else 0
		lot = inventory.container_next_lot(lot)
	return total


func _snapshot() -> PackedByteArray:
	"""Every store the commit could write, rooms and furniture included."""
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
			out.append_array(var_to_bytes(PackedInt64Array([tile, occupant.x, occupant.y,
				buildings.state_of_building(occupant).value, buildings.room_at_tile(tile).x,
				buildings.furniture_at_tile(tile).x])))
	return out


# --- the success path ------------------------------------------------------------------------

func test_a_finished_well_goes_and_its_return_lands_in_the_reserved_store() -> void:
	"""#6 end to end with a store: its container destroyed, the claim released into real lots."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	var depot: Vector2i = _depot_store()
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(well)
	var revision: int = admitted.destination_revision
	var project: Vector2i = admitted.project_ref
	_finish_work(project)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(well)
	assert_true(report.ok, "the demolition completes (%s)" % report.error)
	assert_false(_settlement.buildings().is_live_building(well), "(4) the well is gone")
	assert_equal(_settlement.buildings().building_at_tile(WELL_TILE), EntityDirectoryScript.NULL_REF,
		"its footprint is free")
	assert_false(_settlement.inventory().is_container_valid(own), "(1) its store was destroyed")
	assert_equal(report.destroyed_container_count, 1, "exactly one")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "the claim released")
	assert_equal(_settlement.inventory().container_used_mass_g(depot), WELL_RETURN_G,
		"(5) into exactly the grams it held")
	assert_equal(_milli_of(depot, &"wood"), 5000, "half the well's wood")
	assert_equal(_milli_of(depot, &"stone"), 10000, "half its stone")
	assert_equal(report.returned_lot_count, 2, "as two lots")
	assert_false(_settlement.construction().is_live_project(project), "(6) the project retired")
	assert_equal(_settlement.construction().live_project_count(), 0, "no live project")
	assert_equal(report.project_ref, project, "the report names it")
	assert_equal(report.output_container, depot, "and the store")
	assert_equal(report.output_reserved_g, WELL_RETURN_G, "and the grams released")
	assert_equal(report.destination_revision, revision + 1, "the revision advanced at release")
	assert_true(_settlement.inventory().audit().ok, "Inventory audits")


func test_a_hall_with_rooms_and_no_furniture_takes_its_rooms_and_their_stores() -> void:
	"""(3): every room goes, and a room's own container on the footprint is destroyed in (1)."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(hall, HALL_TILE)
	var room: Vector2i = _room(hall, INSIDE_TILE)
	_room(hall, INSIDE_TILE_2)
	var cupboard: Vector2i = _store(room, INSIDE_TILE)
	var depot: Vector2i = _depot_store()
	_admit_and_finish(hall)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(hall)
	assert_true(report.ok, "the hall completes (%s)" % report.error)
	assert_equal(report.removed_room_count, 2, "both rooms removed")
	assert_equal(_settlement.buildings().live_room_count(), 0, "none survives")
	assert_equal(_settlement.buildings().room_at_tile(INSIDE_TILE), EntityDirectoryScript.NULL_REF,
		"their tiles are released")
	assert_false(_settlement.inventory().is_container_valid(cupboard), "the room's store is gone")
	assert_equal(report.destroyed_container_count, 2, "with the hall's own")
	assert_equal(_settlement.inventory().container_used_mass_g(depot), HALL_RETURN_G, "returned")
	assert_equal(_milli_of(depot, &"cloth"), 6000, "cloth included")
	assert_equal(report.returned_lot_count, 3, "as three lots: wood, stone, cloth")


func test_a_tier_two_hall_returns_half_of_base_plus_upgrade() -> void:
	"""BUILD-C4-R01 at the commit: the lots carry the snapshot's totals, floored once."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	assert_true(_settlement.buildings().set_building_tier(hall, BuildingDefinitions.TIER_TWO).ok,
		"tier 2")
	var depot: Vector2i = _depot_store(1000000)
	_admit_and_finish(hall)
	assert_true(_settlement.complete_demolition(hall).ok, "completes")
	assert_equal(_milli_of(depot, &"wood"), 60000, "(100000 + 20000) / 2")
	assert_equal(_milli_of(depot, &"stone"), 50000, "(60000 + 40000) / 2")
	assert_equal(_milli_of(depot, &"cloth"), 10000, "(12000 + 8000) / 2")
	assert_equal(_settlement.inventory().container_reserved_mass_g(depot), 0, "claim released")


func test_with_no_store_the_return_is_placed_on_ground_piles_from_the_door() -> void:
	"""#9 at the commit: piles outside the door, declared storage class 1500, none on the footprint."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_bind_world()
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(hall)
	assert_true(admitted.output_to_ground_piles, "admitted onto piles")
	_finish_work(admitted.project_ref)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(hall)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_true(report.output_to_ground_piles, "onto piles")
	var inventory: InventoryScript = _settlement.inventory()
	var pile: Vector2i = inventory.ground_pile_at_tile(DOOR_TILE)
	assert_true(inventory.is_ground_pile(pile), "the first pile stands outside the door")
	assert_equal(_settlement.stock_age().storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE,
		"declared storage class 1500 after the commit")
	var wood: int = _settlement.item_definitions().compiled_id(&"wood")
	assert_equal(inventory.total_live_milli(wood), 50000, "the whole wood return")
	assert_true(report.returned_lot_count >= 3, "at least one lot per item")
	var on_footprint: int = 0
	for dz: int in 10:
		for dx: int in 12:
			var tile: int = (HALL_Z + dz) * 128 + HALL_X + dx
			on_footprint += 0 if inventory.ground_pile_at_tile(tile) == InventoryScript.NULL_REF else 1
	assert_equal(on_footprint, 0, "no pile on the destroyed footprint")
	assert_true(inventory.audit().ok, "audits")


func test_a_dirt_path_with_an_empty_bill_completes_returning_nothing() -> void:
	"""§4.1's literal `[]`: no reservation, no pile, no lot -- the building simply goes."""
	var path: Vector2i = _place_active("dirt_path", WELL_TILE)
	var admitted: SettlementSystemScript.DemolitionReport = _admitted(path)
	assert_false(admitted.output_to_ground_piles, "nothing to place at admit")
	_finish_work(admitted.project_ref)
	var lots: int = _settlement.inventory().live_lot_count()
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(path)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_false(_settlement.buildings().is_live_building(path), "the path is gone")
	assert_equal(report.returned_lot_count, 0, "nothing returned")
	assert_false(report.output_to_ground_piles, "and no pile placed")
	assert_equal(_settlement.inventory().live_lot_count(), lots, "no lot created")


func test_a_store_sized_exactly_to_the_return_takes_it_through_the_released_claim() -> void:
	"""The claim is released BEFORE the lots are created, so a store with no other room fits."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store(WELL_RETURN_G)
	_admit_and_finish(well)
	assert_equal(_settlement.inventory().container_free_mass_g(depot), 0, "no free room but the claim")
	assert_true(_settlement.complete_demolition(well).ok, "completes")
	assert_equal(_settlement.inventory().container_used_mass_g(depot), WELL_RETURN_G, "full")


func test_a_project_material_container_reached_twice_is_destroyed_once() -> void:
	"""Reached through its owner and by handle: destroyed in the first visit, skipped in the second."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_depot_store()
	var project: Vector2i = _admitted(well).project_ref
	var handle: Vector2i = _store(project, WELL_TILE)
	assert_true(_settlement.construction().set_material_container(project, handle).ok, "bound")
	_finish_work(project)
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(well)
	assert_true(report.ok, "completes (%s)" % report.error)
	assert_false(_settlement.inventory().is_container_valid(handle), "the handle's store is gone")
	assert_equal(report.destroyed_container_count, 1, "destroyed exactly once")


func test_a_second_completion_finds_no_building() -> void:
	"""Retry after success cannot place the return twice."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store()
	_admit_and_finish(well)
	assert_true(_settlement.complete_demolition(well).ok, "completes once")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STALE_BUILDING, "the retry refuses")
	assert_true(_snapshot() == before, "writing nothing")
	assert_equal(_settlement.inventory().container_used_mass_g(depot), WELL_RETURN_G, "once only")


# --- refusals before the work is done or without an admission ---------------------------------

func test_completion_refuses_until_the_work_is_done() -> void:
	"""WRONG_PHASE (construction's own code) while the work is unbegun or under way."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_depot_store()
	var project: Vector2i = _admitted(well).project_ref
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error, ConstructionScript.REFUSE_WRONG_PHASE,
		"unbegun")
	assert_true(_snapshot() == before, "byte-identical")
	assert_true(_settlement.construction().begin_work(project).ok, "work begins")
	assert_equal(_settlement.complete_demolition(well).error, ConstructionScript.REFUSE_WRONG_PHASE,
		"under way")


func test_completion_refuses_a_demolition_the_coordinator_did_not_admit() -> void:
	"""NOT_ADMITTED for an ACTIVE building and for a store-level demolition; STALE for a stale ref."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_ADMITTED, "nothing to complete")
	assert_true(_snapshot() == before, "byte-identical")
	var opened: ConstructionScript.OpResult = _settlement.construction().open_demolition(well)
	assert_true(opened.ok, "a store-level demolition")
	_finish_work(opened.ref)
	var finished: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_ADMITTED, "is not the coordinator's")
	assert_true(_snapshot() == finished, "byte-identical")
	assert_equal(_settlement.complete_demolition(EntityDirectoryScript.NULL_REF).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STALE_BUILDING, "a stale ref")


func test_completion_refuses_inside_a_callers_transaction_and_a_missing_claim() -> void:
	"""TRANSACTION and RESERVATION_NOT_HELD, cancellation's own claim proof, byte-identical."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store()
	_admit_and_finish(well)
	assert_true(_settlement.inventory().begin().ok, "a caller holds a transaction")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_TRANSACTION, "refused")
	assert_true(_settlement.inventory().is_transaction_open(), "the caller's stays open")
	_settlement.inventory().abort()
	assert_true(_snapshot() == before, "byte-identical")
	assert_true(_settlement.inventory().release_container_mass(depot, 1).ok, "a gram goes astray")
	var short: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_CLAIM_MISSING, "the claim is not fully held")
	assert_true(_snapshot() == short, "byte-identical")


# --- the gate runs again at the commit --------------------------------------------------------

func test_goods_that_arrive_after_admission_block_the_commit_until_moved() -> void:
	"""Stage 3 again: stranded lots are named, the project stays WORK_DONE, the retry is free."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	_depot_store()
	var project: Vector2i = _admit_and_finish(well)
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var lot: InventoryScript.OpResult = _settlement.inventory().create_lot(own, grain, 2000,
		0, 0, 0, 0, 0)
	assert_true(lot.ok, "goods arrive")
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(well)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS, "refused")
	assert_equal(report.stranded_lot_at(0), lot.ref, "naming the lot")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_phase_of(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")
	assert_true(_settlement.inventory().sink_lot_quantity(lot.ref, 2000).ok, "the goods leave")
	assert_true(_settlement.complete_demolition(well).ok, "and the retry completes")


func test_occupants_after_admission_block_the_commit() -> void:
	"""Stage 4 again, re-raising construction's own occupant code."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: Vector2i = _room(hall, INSIDE_TILE)
	_depot_store()
	_admit_and_finish(hall)
	assert_true(_settlement.buildings().set_room_occupants(room, 1).ok, "somebody walks in")
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(hall)
	assert_equal(report.error, ConstructionScript.REFUSE_OCCUPANTS_PRESENT, "refused")
	assert_equal(report.occupant_count, 1, "counting them")
	assert_true(_snapshot() == before, "byte-identical")


func test_a_foreign_container_on_the_footprint_after_admission_blocks_the_commit() -> void:
	"""Stage 5 again: the tile scan finds somebody else's container on the footprint."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store()
	_admit_and_finish(well)
	var stranger: Vector2i = _store(_settlement.inventory().container_owner(depot), WELL_TILE)
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(well)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FOREIGN_CONTAINER, "refused")
	assert_equal(report.blocking_container, stranger, "naming it")
	assert_true(_snapshot() == before, "byte-identical")


# --- the furniture rule --------------------------------------------------------------------------

func test_admit_refuses_a_building_with_furniture_and_names_the_first_piece() -> void:
	"""No piece carries a paid package, so admit cannot reserve its 50%: every piece refuses."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var bed: Vector2i = _bed(_room(hall, INSIDE_TILE), INSIDE_TILE)
	var other: Vector2i = _bed(_room(hall, INSIDE_TILE_2), INSIDE_TILE_2)
	_depot_store()
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNPAID,
		"the furniture rule refuses")
	assert_equal(report.unpaid_furniture_count, 2, "counting every piece")
	var buildings: BuildingsScript = _settlement.buildings()
	var first_room: Vector2i = buildings.room_ref_of_row(buildings.rooms_of_building(hall)[0])
	var first: Vector2i = buildings.furniture_ref_of_row(buildings.furniture_rows_in_room(first_room)[0])
	assert_true(first == bed or first == other, "(the walk's first piece is one of the two)")
	assert_equal(report.blocking_furniture, first, "and naming the first piece the walk reaches")
	assert_true(_snapshot() == before, "byte-identical: no reservation, no project")


func test_a_piece_with_a_live_furniture_project_refuses_the_same() -> void:
	"""A piece still being built is not completed capital: the same refusal, by name."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var bed: Vector2i = _bed(_room(hall, INSIDE_TILE), INSIDE_TILE)
	assert_true(_settlement.construction().open_furniture(bed).ok, "its project is live")
	_depot_store()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNPAID, "refused")
	assert_equal(report.blocking_furniture, bed, "naming the bed")


func test_furniture_placed_after_admission_blocks_the_commit_until_removed() -> void:
	"""The furniture rule runs again at the commit; removing the piece lets the retry through."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: Vector2i = _room(hall, INSIDE_TILE)
	_depot_store()
	var project: Vector2i = _admit_and_finish(hall)
	var bed: Vector2i = _bed(room, INSIDE_TILE)
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNPAID, "refused")
	assert_equal(report.blocking_furniture, bed, "naming the bed")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_phase_of(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")
	assert_true(_settlement.buildings().remove_furniture(bed).ok, "the bed is taken out")
	assert_true(_settlement.complete_demolition(hall).ok, "and the retry completes")


func test_the_preview_applies_the_furniture_rule_too() -> void:
	"""Review M3: a preview that passes is one admit can act on, so it refuses furniture as well."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var bed: Vector2i = _bed(_room(hall, INSIDE_TILE), INSIDE_TILE)
	_depot_store()
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FURNITURE_UNPAID,
		"the preview refuses")
	assert_equal(report.blocking_furniture, bed, "naming the bed")
	assert_equal(report.unpaid_furniture_count, 1, "once, not twice")
	assert_true(_snapshot() == before, "and writes nothing")


# --- the return's placement can fail at the commit (stay commit-pending) ----------------------

func test_recorded_grams_that_differ_from_the_snapshots_charge_refuse() -> void:
	"""Review L5: the claim released must equal what the lots will debit, or the commit refuses."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admit_and_finish(well)
	var admissions: DemolitionAdmissionsScript = _settlement.demolition_admissions()
	assert_equal(admissions.release(well), &"", "the record is cleared around the coordinator")
	assert_equal(admissions.record(well, project, depot, WELL_RETURN_G - 1), &"",
		"and re-recorded one gram short")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_RESERVATION_MISMATCH, "refused by name")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_phase_of(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")
	assert_equal(admissions.release(well), &"", "cleared again")
	assert_true(_settlement.inventory().reserve_container_mass(depot, 1).ok, "one gram more held")
	assert_equal(admissions.record(well, project, depot, WELL_RETURN_G + 1), &"",
		"and re-recorded one gram over")
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_RESERVATION_MISMATCH, "over refuses too")


func test_a_pile_fallback_that_no_longer_places_stays_commit_pending_and_retries() -> void:
	"""Decision 0534's R2: proved at admit, it can fail now; NO_OUTPUT, byte-identical, retry free."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var world: Vector2i = _bind_world()
	var project: Vector2i = _admit_and_finish(hall)
	assert_true(_settlement.directory().destroy(world), "the World row goes")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NO_OUTPUT, "no pile can be placed now")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_phase_of(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")
	_bind_world()
	assert_true(_settlement.complete_demolition(hall).ok, "the retry completes")


func test_a_store_that_can_no_longer_take_the_return_stays_commit_pending() -> void:
	"""The store return is proved by a rolled-back release-and-create: a store refusing it is NO_OUTPUT."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admit_and_finish(well)
	var inventory: InventoryScript = _settlement.inventory()
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(
		InventoryScript.CONTAINER_CAPACITY, InventoryScript.LOT_CAPACITY)
	assert_true(inventory.copy_canonical_columns_into(columns), "the store projects")
	columns.c_filters[depot.x] = 0
	assert_true(inventory.restore_canonical_columns(columns), "the depot now accepts nothing (%s)"
		% inventory.canonical_detail())
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.complete_demolition(well).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NO_OUTPUT, "the store cannot take it")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_phase_of(project), ConstructionScript.PHASE_WORK_DONE, "commit-pending")


# --- review M2: the guard after the record's release ----------------------------------------------

func _abandon_after_first_block(building: Vector2i, project: Vector2i, store: Vector2i,
		grams: int) -> void:
	"""Run the commit's first block, then the guard that follows an unreachable later refusal."""
	assert_equal(_settlement._open_commit(building, store, grams), &"", "the first block runs")
	assert_equal(_settlement.demolition_admissions().project_of(building),
		EntityDirectoryScript.NULL_REF, "and released the record")
	expect_diagnostic("a proved demolition commit refused a write")
	_settlement._abandon_commit(building, project, store, grams, &"TEST_FAULT")


func test_an_abandoned_store_commit_restores_inventory_and_re_records_the_admission() -> void:
	"""The abort restores every store and the claim; the record returns; the retry completes."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	var own: Vector2i = _store(well, WELL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admit_and_finish(well)
	var inventory_before: PackedByteArray = _settlement.inventory().state_bytes()
	_abandon_after_first_block(well, project, depot, WELL_RETURN_G)
	var admissions: DemolitionAdmissionsScript = _settlement.demolition_admissions()
	assert_true(_settlement.inventory().state_bytes() == inventory_before, "Inventory restored")
	assert_true(_settlement.inventory().is_container_valid(own), "the well's store is back")
	assert_equal(admissions.project_of(well), project, "the admission is recorded again")
	assert_equal(admissions.output_container_of(well), depot, "with its store")
	assert_equal(admissions.output_reserved_g_of(well), WELL_RETURN_G, "and its grams")
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(well)
	assert_true(report.ok, "the retry completes (%s)" % report.error)
	assert_equal(report.destroyed_container_count, 1, "destroying the store once")


func test_an_abandoned_pile_commit_re_records_the_fallback_shape() -> void:
	"""Store null, grams 0: the pile-fallback record shape is re-recorded too; counters are zeroed."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_bind_world()
	var project: Vector2i = _admit_and_finish(hall)
	_abandon_after_first_block(hall, project, InventoryScript.NULL_REF, 0)
	var admissions: DemolitionAdmissionsScript = _settlement.demolition_admissions()
	assert_equal(admissions.project_of(hall), project, "recorded again")
	assert_equal(admissions.unreleased_reserved_g_of(hall), 0, "with no grams")
	var report: SettlementSystemScript.DemolitionReport = _settlement.complete_demolition(hall)
	assert_true(report.ok, "the retry completes (%s)" % report.error)
	assert_true(report.output_to_ground_piles, "onto piles")


func test_the_abandon_guard_zeroes_the_reports_counters_and_rereads_the_revision() -> void:
	"""Review L-b: nothing the abort undid is still reported as done."""
	var well: Vector2i = _place_active("well", WELL_TILE)
	_store(well, WELL_TILE)
	var depot: Vector2i = _depot_store()
	var project: Vector2i = _admit_and_finish(well)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(
		_place_active("covered_store", 80 * 128 + 80))
	report.destroyed_container_count = 9
	report.removed_room_count = 9
	report.returned_lot_count = 9
	_abandon_after_first_block(well, project, depot, WELL_RETURN_G)
	assert_equal(report.destroyed_container_count, 0, "destroyed reset")
	assert_equal(report.removed_room_count, 0, "rooms reset")
	assert_equal(report.returned_lot_count, 0, "lots reset")
	assert_equal(report.destination_revision,
		_settlement.demolition_admissions().destination_revision_of(well), "the row's revision")
