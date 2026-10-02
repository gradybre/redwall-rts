extends "res://test/framework/test_case.gd"
## DEMO-CONTAIN-R01 step D4 (decision 0534): stage 5's success path and the *admit* step.
##
## Stage 5: the owner scan and the tile scan must agree (#3a, #3c), an anchored ownerless
## container refuses (#7), a ground pile on the footprint is counted, satchels are excluded (#3d).
## Admit: every check before the first write; the return's capacity reserved in one surviving
## store or proved placeable in ground piles; the project published with BUILD-C4-R01's snapshot;
## the building's destination revision advanced; any refusal byte-identical across every store.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HALL_X: int = 20
const HALL_Z: int = 20
const HALL_TILE: int = HALL_Z * 128 + HALL_X
## A tile inside the hall's 12 x 10 footprint, and one well outside it.
const INSIDE_TILE: int = (HALL_Z + 4) * 128 + HALL_X + 5
const OUTSIDE_TILE: int = (HALL_Z + 30) * 128 + HALL_X + 30
const DEPOT_TILE: int = 60 * 128 + 90
const START_MASK: int = 1
## The hall's 50% return charge: wood 50 U and stone 30 U at 5000 g/U, cloth 6 U at 250 g/U.
const HALL_RETURN_G: int = 250000 + 150000 + 1500

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


func _store(owner_ref: Vector2i, anchor: int, mass_g: int = 500000,
		filters: int = InventoryScript.FILTERS_ACCEPT_ALL) -> Vector2i:
	"""One container keyed to `owner_ref` and anchored at `anchor`."""
	var made: InventoryScript.OpResult = _settlement.inventory().create_container(owner_ref,
		mass_g, filters, InventoryScript.UNSET_POLICY, true, anchor)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _depot() -> Vector2i:
	"""Another ACTIVE building away from the hall, to own a surviving store."""
	return _place_active("covered_store", DEPOT_TILE)


func _snapshot() -> PackedByteArray:
	"""Every store admit could write: Construction, Inventory, directory, Buildings, admissions."""
	var out: PackedByteArray = _settlement.construction().state_bytes()
	out.append_array(_settlement.inventory().state_bytes())
	out.append_array(_settlement.directory().state_bytes())
	out.append_array(_settlement.demolition_admissions().state_bytes())
	var buildings: BuildingsScript = _settlement.buildings()
	for row: int in BuildingsScript.BUILDING_CAPACITY:
		var ref: Vector2i = buildings.building_ref_of_row(row)
		if ref != EntityDirectoryScript.NULL_REF:
			out.append_array(var_to_bytes(PackedInt64Array([ref.x, ref.y,
				buildings.state_of_building(ref).value, buildings.tier_of_building(ref).value])))
	return out


func _bind_world() -> Vector2i:
	"""Create the World row and bind the ground-pile composer to it, as INIT-C does."""
	var world: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_WORLD)
	assert_true(_settlement.ground_piles().bind_world(world), "the composer binds the World")
	return world


func _restore_with(container: Vector2i, owner_ref: Vector2i, anchor: int, policy: int) -> void:
	"""Rewrite one live container's owner, anchor and policy through section 7's restore door.

	The only way such a row exists now that `create_container()` refuses an ownerless owner and
	the site rule keeps piles off standing footprints (decision 0533's Consequences).
	"""
	var inventory: InventoryScript = _settlement.inventory()
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(
		InventoryScript.CONTAINER_CAPACITY, InventoryScript.LOT_CAPACITY)
	assert_true(inventory.copy_canonical_columns_into(columns), "the store projects")
	columns.c_owner_slot[container.x] = owner_ref.x
	columns.c_owner_generation[container.x] = owner_ref.y
	columns.c_anchor_tile[container.x] = anchor
	columns.c_policy[container.x] = policy
	assert_true(inventory.restore_canonical_columns(columns),
		"the rewritten projection restores (%s)" % inventory.canonical_detail())


# --- stage 5: the two scans agree ------------------------------------------------------------

func test_a_building_store_anchored_at_its_origin_agrees_with_both_scans() -> void:
	"""#3a: owner scan and tile scan find the same store, and the preview passes."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(hall, HALL_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_true(report.ok, "the preview passes (%s)" % report.error)
	assert_equal(report.scanned_container_count, 1, "the owner scan found it")
	assert_equal(report.anchored_container_count, 1, "and so did the tile scan")


func test_an_unplaced_building_store_refuses_as_off_the_footprint() -> void:
	"""#3a: a building-owned container the tile scan cannot see is a disagreement."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var store: Vector2i = _store(hall, InventoryScript.UNPLACED_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_OFF_FOOTPRINT,
		"an unplaced building store refuses")
	assert_equal(report.blocking_container, store, "and the report names it")


func test_a_building_store_anchored_elsewhere_refuses_as_off_the_footprint() -> void:
	"""#3a's own words: "a building-owned container whose anchor is off the footprint"."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var store: Vector2i = _store(hall, OUTSIDE_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_OFF_FOOTPRINT, "refuses")
	assert_equal(report.blocking_container, store, "naming the store")


func test_a_projects_material_handle_off_the_footprint_refuses() -> void:
	"""#3c: the project container is reached by handle and must also stand on the footprint."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(hall,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([INSIDE_TILE]))
	assert_true(room.ok, "a room is designated (%s)" % room.error)
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(room.ref,
		int(CatalogScript.FURNITURE_DEFINITION["bed"]), INSIDE_TILE, 0)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(bed.ref)
	var carrier: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	var handle: Vector2i = _store(carrier, OUTSIDE_TILE)
	assert_true(_settlement.construction().set_material_container(project.ref, handle).ok,
		"the project names it")
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_OFF_FOOTPRINT, "refuses")
	assert_equal(report.blocking_container, handle, "naming the handle's container")


func test_a_container_on_the_footprint_owned_by_somebody_else_refuses() -> void:
	"""The other disagreement: the tile scan finds a container the owner scan did not reach."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var stranger: Vector2i = _store(_depot(), INSIDE_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_FOREIGN_CONTAINER,
		"a foreign container on the footprint refuses")
	assert_equal(report.blocking_container, stranger, "and is named")


func test_an_anchored_ownerless_container_refuses() -> void:
	"""#7: an ANCHORED NULL_REF container on the footprint is a refusal."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var orphan: Vector2i = _store(_depot(), OUTSIDE_TILE)
	_restore_with(orphan, EntityDirectoryScript.NULL_REF, INSIDE_TILE, InventoryScript.UNSET_POLICY)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_ANCHORED_ORPHAN,
		"the ownerless container refuses by its own name")
	assert_equal(report.blocking_container, orphan, "and is named")


func test_an_unanchored_ownerless_container_sits_outside_every_footprint() -> void:
	"""#7's other half: unanchored, it is outside every footprint and blocks nothing."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var orphan: Vector2i = _store(_depot(), OUTSIDE_TILE)
	_restore_with(orphan, EntityDirectoryScript.NULL_REF, InventoryScript.UNPLACED_TILE,
		InventoryScript.UNSET_POLICY)
	assert_true(_settlement.preview_demolition(hall).ok, "the preview passes")


func test_a_satchel_is_excluded_and_its_goods_do_not_block() -> void:
	"""#3d: a resident's unplaced satchel is the occupant gate's, not the footprint's."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var resident: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	var satchel: Vector2i = _store(resident, InventoryScript.UNPLACED_TILE)
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	assert_true(_settlement.inventory().create_lot(satchel, grain, 1000, 0, 0, 0, 0, 0).ok, "lot")
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_true(report.ok, "the satchel blocks nothing (%s)" % report.error)
	assert_equal(report.anchored_container_count, 0, "and is on no tile")


func test_a_ground_pile_on_the_footprint_is_counted_as_stranded_goods() -> void:
	"""A pile on the footprint counts toward demolition; its lots block it."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var world: Vector2i = _bind_world()
	var pile: Vector2i = _store(_depot(), OUTSIDE_TILE, InventoryScript.GROUND_PILE_MAX_MASS_G)
	var wood: int = _settlement.item_definitions().compiled_id(&"wood")
	assert_true(_settlement.inventory().create_lot(pile, wood, 2000, 0, 0, 0, 0, 0).ok, "lot")
	_restore_with(pile, world, INSIDE_TILE, InventoryScript.POLICY_GROUND_PILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"the pile's goods block the demolition")
	assert_equal(report.stranded_quantity_milli, 2000, "at their exact quantity")
	assert_equal(report.blocking_container, InventoryScript.NULL_REF, "a pile is no disagreement")


func test_a_pile_outside_the_footprint_survives_and_does_not_block() -> void:
	"""#5: containers on the outside access tiles are reported as surviving, not blocking."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_bind_world()
	var outside_door: int = (HALL_Z + 10) * 128 + HALL_X + 6
	var inventory: InventoryScript = _settlement.inventory()
	assert_true(inventory.begin().ok, "a transaction opens, as #9's door requires")
	var pile: InventoryScript.OpResult = inventory.create_ground_pile(outside_door)
	assert_true(pile.ok, "a pile outside the door (%s)" % pile.error)
	var wood: int = _settlement.item_definitions().compiled_id(&"wood")
	assert_true(inventory.create_lot(pile.ref, wood, 1000, 0, 0, 0, 0, 0).ok, "holding wood")
	assert_true(inventory.commit().ok, "and commits")
	var report: SettlementSystemScript.DemolitionReport = _settlement.preview_demolition(hall)
	assert_true(report.ok, "the preview still passes (%s)" % report.error)
	assert_equal(report.anchored_container_count, 0, "the pile is not on the footprint")


# --- admit ----------------------------------------------------------------------------------

func test_admit_reserves_the_return_in_a_surviving_store_and_publishes_the_project() -> void:
	"""Blocker 1 end to end: reserve, publish, snapshot, record, revision."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var depot: Vector2i = _depot()
	var store: Vector2i = _store(depot, DEPOT_TILE)
	var revision: int = _settlement.demolition_admissions().destination_revision_of(hall)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_true(report.ok, "the demolition is admitted (%s)" % report.error)
	assert_equal(report.output_container, store, "into the surviving store")
	assert_equal(report.output_reserved_g, HALL_RETURN_G, "reserving the whole return's charge")
	assert_equal(_settlement.inventory().container_reserved_mass_g(store), HALL_RETURN_G,
		"as real headroom in Inventory")
	assert_equal(_settlement.construction().project_of_building(hall), report.project_ref,
		"the project is published")
	assert_equal(_settlement.buildings().state_of_building(hall).value,
		ConstructionScript.STATE_DEMOLISHING, "the hall is DEMOLISHING")
	assert_equal(report.destination_revision, revision + 1, "its revision advanced by one")
	var admissions: Object = _settlement.demolition_admissions()
	assert_equal(admissions.project_of(hall), report.project_ref, "the record names the project")
	assert_equal(admissions.output_container_of(hall), store, "and the store")
	assert_equal(admissions.output_reserved_g_of(hall), HALL_RETURN_G, "and the grams")


func test_a_second_request_is_refused_as_already_in_progress() -> void:
	"""Retry cannot reserve twice or publish a second project."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var store: Vector2i = _store(_depot(), DEPOT_TILE)
	assert_true(_settlement.request_demolition(hall).ok, "admitted once")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_IN_PROGRESS, "the retry refuses")
	assert_true(_snapshot() == before, "and writes nothing")
	assert_equal(_settlement.inventory().container_reserved_mass_g(store), HALL_RETURN_G,
		"the reservation was not taken twice")


func test_admit_snapshots_a_tier_two_hall_and_reserves_for_both_packages() -> void:
	"""BUILD-C4-R01 through the coordinator: the reservation covers base plus upgrade."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	assert_true(_settlement.buildings().set_building_tier(hall, BuildingDefinitions.TIER_TWO).ok,
		"the hall stands at tier 2")
	var store: Vector2i = _store(_depot(), DEPOT_TILE, 1000000)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_true(report.ok, "admitted (%s)" % report.error)
	var upgrade_g: int = 10 * 5000 + 20 * 5000 + 4 * 250
	assert_equal(_settlement.inventory().container_reserved_mass_g(store),
		HALL_RETURN_G + upgrade_g, "half of the upgrade's wood, stone and cloth is reserved too")
	var mask: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.construction().paid_upgrade_mask_into(report.project_ref, mask), "mask")
	assert_equal(mask.value, ConstructionScript.UPGRADE_TIER_TWO_BIT, "the snapshot holds it")


func test_the_lowest_eligible_store_is_chosen_and_ineligible_ones_skipped() -> void:
	"""Food-only, too small, unreachable and DEMOLISHING-owned stores are passed over."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	var depot: Vector2i = _depot()
	_store(depot, DEPOT_TILE, 500000, 0)
	_store(depot, DEPOT_TILE, HALL_RETURN_G - 1)
	var unreachable: Vector2i = _store(depot, DEPOT_TILE)
	assert_true(_settlement.inventory().set_container_reachable(unreachable, false).ok, "unreachable")
	var doomed: Vector2i = _place_active("well", 80 * 128 + 20)
	_store(doomed, 80 * 128 + 20)
	assert_true(_settlement.buildings().set_building_state(doomed,
		ConstructionScript.STATE_DEMOLISHING).ok, "the well is DEMOLISHING")
	var chosen: Vector2i = _store(depot, DEPOT_TILE)
	_store(depot, DEPOT_TILE)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_true(report.ok, "admitted (%s)" % report.error)
	assert_equal(report.output_container, chosen, "the lowest eligible store")


func test_with_no_store_the_return_falls_back_to_ground_piles() -> void:
	"""#9 is the fallback: proved placeable now, placed at D5's commit, nothing reserved."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_bind_world()
	var piles_before: PackedByteArray = _settlement.inventory().state_bytes()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_true(report.ok, "admitted (%s)" % report.error)
	assert_true(report.output_to_ground_piles, "onto ground piles")
	assert_equal(report.output_container, InventoryScript.NULL_REF, "with no store")
	assert_equal(report.output_reserved_g, 0, "and nothing reserved")
	assert_true(_settlement.inventory().state_bytes() == piles_before,
		"the placement was a rolled-back preflight: Inventory is byte-identical")
	assert_equal(_settlement.inventory().ground_pile_at_tile((HALL_Z + 10) * 128 + HALL_X + 6),
		InventoryScript.NULL_REF, "and no pile was left behind")


func test_an_open_inventory_transaction_refuses_before_any_write() -> void:
	"""Admit never joins or closes a transaction it did not open."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(_depot(), DEPOT_TILE)
	assert_true(_settlement.inventory().begin().ok, "a caller holds a transaction")
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_TRANSACTION, "admit refuses")
	assert_true(_settlement.inventory().is_transaction_open(), "the caller's stays open")
	_settlement.inventory().abort()
	assert_true(_snapshot() == before, "and nothing was written")


func test_an_admit_refusal_is_byte_identical_across_every_store() -> void:
	"""Decision 0059 across Building, Construction, Inventory, directory and the record."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(_depot(), DEPOT_TILE, HALL_RETURN_G - 1)
	var before: PackedByteArray = _snapshot()
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NO_OUTPUT, "no store fits and no World exists")
	assert_true(_snapshot() == before, "nothing changed")


func test_a_preview_publishes_nothing_even_when_it_passes() -> void:
	"""Preview is the read-only half."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(_depot(), DEPOT_TILE)
	var before: PackedByteArray = _snapshot()
	assert_true(_settlement.preview_demolition(hall).ok, "the preview passes")
	assert_true(_snapshot() == before, "and wrote nothing")


func test_a_full_construction_kind_refuses_in_admit_before_any_write() -> void:
	"""`demolition_open_refusal()` proves the directory row before the reservation is taken."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(_depot(), DEPOT_TILE)
	var directory: EntityDirectoryScript = _settlement.directory()
	while directory.free_row_count(EntityDirectoryScript.KIND_CONSTRUCTION) > 0:
		directory.create(EntityDirectoryScript.KIND_CONSTRUCTION)
	var before: PackedByteArray = _snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error,
		EntityDirectoryScript.KIND_CAPACITY_REFUSAL[EntityDirectoryScript.KIND_CONSTRUCTION],
		"the directory's own capacity code")
	assert_true(_snapshot() == before, "and the reservation was never taken")


func test_reset_forgets_admissions_and_restarts_revisions() -> void:
	"""The record is settlement state: `reset()` clears it with everything else."""
	var hall: Vector2i = _place_active("hall", HALL_TILE)
	_store(_depot(), DEPOT_TILE)
	assert_true(_settlement.request_demolition(hall).ok, "admitted")
	_settlement.reset()
	var again: Vector2i = _place_active("hall", HALL_TILE)
	assert_equal(_settlement.demolition_admissions().destination_revision_of(again),
		1, "the revision restarts at FIRST_DESTINATION_REVISION")
	assert_equal(_settlement.demolition_admissions().project_of(again), EntityDirectoryScript.NULL_REF,
		"and no admission survives")
