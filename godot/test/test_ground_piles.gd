extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/ground_piles.gd`: DEMO-CONTAIN-R01 #9's site rule, the breadth-first
## all-or-nothing placement and the refund origin (decision 0532).
##
## The fixture is the real composition -- Buildings with its own directory and a live World row,
## Inventory, StockAge -- so every refusal here is the one production will see. The 16384-tile cap
## test swaps passability for "everywhere" through a subclass, because GDD §5.1's coast, river and
## lake make the real map's eligible component smaller than the cap.

const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const StarterStructures := preload("res://scripts/core/starter_structures.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Section := preload("res://scripts/core/save_section_inventories.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

const ITEM_STONE: int = 3
const STONE_MASS_G: int = 1000
const ITEM_IRON: int = 4
## A 400000 g item: one unit fills a pile, so the cap fixture needs one lot per pile.
const ITEM_BOULDER: int = 5
const IRON_MASS_G: int = 3000
## One full pile of stone: 400000 g at 1000 g per unit.
const PILE_OF_STONE: int = 400000
const START_MASK: int = 1


class EverywherePassable:
	extends "res://scripts/core/ground_piles.gd"
	## Passability answered "yes" for every tile, so the whole 128 x 128 grid is one component.

	func is_tile_passable(tile: int) -> bool:
		"""Every placement cell is passable in this fixture."""
		return tile >= 0 and tile < TILE_COUNT


var _buildings: BuildingsScript = null
var _inv: InventoryScript = null
var _age: StockAgeScript = null
var _piles: GroundPilesScript = null
var _world: Vector2i = EntityDirectory.NULL_REF
var _out: GroundPilesScript.PlaceResult = GroundPilesScript.PlaceResult.new()


func before_each() -> void:
	"""Buildings with a World row, a 64-row inventory, a stock-age store, and the bound composer."""
	_compose(InventoryScript.new(64, 64), GroundPilesScript.new())


func _compose(inventory: InventoryScript, piles: GroundPilesScript) -> void:
	"""Wire one composition around `inventory`, binding a fresh World row."""
	_buildings = BuildingsScript.new()
	_world = _buildings.directory().create(EntityDirectory.KIND_WORLD)
	_inv = inventory
	_inv.register_item(ITEM_STONE, STONE_MASS_G, 0)
	_inv.register_item(ITEM_IRON, IRON_MASS_G, 0)
	_age = StockAgeScript.new(_inv, null)
	_piles = piles
	assert_true(_piles.bind_stores(_inv, _buildings, _age), "the composer binds")
	assert_true(_piles.bind_world(_world), "the World row binds")


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's `z*128+x`."""
	return z * 128 + x


func _spec(item: int, quantity: int) -> PackedInt64Array:
	"""One spec row: plain quality, ordinary provenance, no recipe, age 0."""
	return PackedInt64Array([item, quantity, 0, 0, 0, 0, 0])


func _place(start: int, specs: PackedInt64Array,
		mask: PackedByteArray = PackedByteArray()) -> bool:
	"""Place through the composer into `_out`."""
	return _piles.place_lots_into_piles(start, mask, specs, _out)


func _used(x: int, z: int) -> int:
	"""Grams held by the pile on (x, z), or -1 when there is none."""
	var pile: Vector2i = _inv.ground_pile_at_tile(_tile(x, z))
	return -1 if pile == InventoryScript.NULL_REF else _inv.container_used_mass_g(pile)


func _place_building(key: String, x: int, z: int, rotation: int = 0) -> Vector2i:
	"""Place one building of catalog `key` with its origin at (x, z)."""
	var made: BuildingsScript.OpResult = _buildings.place_building(
		int(Catalog.BUILDING_DEFINITION[key]), _tile(x, z), rotation, START_MASK)
	assert_true(made.ok, "the %s is placed: %s" % [key, made.error])
	return made.ref


func _empty_mask() -> PackedByteArray:
	"""A zeroed 16384-byte tile mask."""
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(GroundPilesScript.TILE_COUNT)
	mask.fill(0)
	return mask


# --- constants and binding ----------------------------------------------------------------------

func test_the_tile_domain_and_cap_are_the_approved_values() -> void:
	"""The grid is Inventory's anchor domain, and the cap is #9's 16384."""
	assert_equal(GroundPilesScript.TILE_COUNT, InventoryScript.ANCHOR_TILE_COUNT, "one domain")
	assert_equal(GroundPilesScript.SPILL_TILE_CAP, 16384, "the approved spill cap")
	assert_equal(InventoryScript.GROUND_PILE_MAX_MASS_G, 400000, "the approved capacity")


func test_bind_world_accepts_only_a_live_world_row() -> void:
	"""A building ref, the null ref and a destroyed World are all refused."""
	var piles: GroundPilesScript = GroundPilesScript.new()
	assert_false(piles.bind_world(_world), "nothing can be checked before the stores bind")
	assert_true(piles.bind_stores(_inv, _buildings, _age), "bind")
	var hall: Vector2i = _place_building("hall", 10, 30)
	assert_false(piles.bind_world(hall), "a Building is not the World")
	assert_false(piles.bind_world(EntityDirectory.NULL_REF), "nor is the null ref")
	assert_equal(piles.ground_pile_owner_ref(), EntityDirectory.NULL_REF, "no owner yet")
	assert_equal(piles.ground_pile_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_NO_WORLD,
		"and no tile is admitted without one")
	assert_true(piles.bind_world(_world), "the World row binds")
	assert_equal(piles.ground_pile_owner_ref(), _world, "and owns piles")
	_buildings.directory().destroy(_world)
	assert_equal(piles.ground_pile_owner_ref(), EntityDirectory.NULL_REF, "a destroyed World owns none")


func test_bind_stores_refuses_a_missing_store() -> void:
	"""Every required store must be present; the spatial map is optional."""
	var piles: GroundPilesScript = GroundPilesScript.new()
	assert_false(piles.bind_stores(null, _buildings, _age), "no inventory")
	assert_false(piles.bind_stores(_inv, null, _age), "no buildings")
	assert_false(piles.bind_stores(_inv, _buildings, null), "no stock age")
	assert_true(piles.bind_stores(_inv, _buildings, _age, null), "no spatial map is fine")


# --- the site rule ------------------------------------------------------------------------------

func test_out_of_bounds_tiles_refuse() -> void:
	"""-1 and 16384 are no tiles."""
	for tile: int in [-1, 16384, 99999]:
		assert_equal(_piles.ground_pile_tile_refusal(tile), GroundPilesScript.REFUSE_OUT_OF_BOUNDS,
			"tile %d" % tile)
	assert_false(_piles.is_tile_passable(-1), "nor is it passable")


func test_open_land_is_admitted_and_water_is_impassable() -> void:
	"""GDD §5.1: land and the ford admit a pile; river, lake and coast do not."""
	assert_equal(_piles.ground_pile_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_NONE,
		"open land")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(77, 49)), GroundPilesScript.REFUSE_NONE,
		"the ford is walkable")
	for water: Vector2i in [Vector2i(77, 30), Vector2i(100, 66), Vector2i(40, 5)]:
		assert_equal(_piles.ground_pile_tile_refusal(_tile(water.x, water.y)),
			GroundPilesScript.REFUSE_IMPASSABLE, "water at %s" % water)


func test_a_bound_ground_map_blocks_a_tile_with_one_unwalkable_cell() -> void:
	"""Every one of the tile's 16 navigation cells must be walkable at the current revision."""
	var spatial: SpatialWorldScript = SpatialWorldScript.new()
	assert_true(_piles.bind_stores(_inv, _buildings, _age, spatial), "bind the ground map")
	assert_true(_piles.is_tile_passable(_tile(40, 40)), "passable before the edit")
	var last_cell: int = (40 * 4 + 3) * SpatialWorldScript.CELLS_X + 40 * 4 + 3
	assert_true(spatial.override_static_legality(last_cell, false), "block the tile's last cell")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_IMPASSABLE,
		"one blocked cell blocks the tile")
	assert_true(_piles.is_tile_passable(_tile(41, 40)), "the neighbour is untouched")


func test_a_demolishing_footprint_refuses_by_name_through_inventory_too() -> void:
	"""#9: never on a DEMOLISHING footprint -- and Inventory's door returns the same code."""
	var well: Vector2i = _place_building("well", 40, 40)
	assert_true(_buildings.set_building_state(well,
		Catalog.BUILDING_STATE["DEMOLISHING"]).ok, "the well is being demolished")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(41, 41)),
		GroundPilesScript.REFUSE_DEMOLISHING_FOOTPRINT, "every footprint tile refuses")
	var before: PackedByteArray = _inv.state_bytes()
	_inv.begin()
	assert_equal(_inv.create_ground_pile(_tile(40, 40)).error,
		GroundPilesScript.REFUSE_DEMOLISHING_FOOTPRINT, "through the one door")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "byte-identical")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(42, 40)), GroundPilesScript.REFUSE_NONE,
		"the tile beside the 2 x 2 footprint is free")


func test_every_other_live_footprint_is_inaccessible() -> void:
	"""No contract proves a footprint tile accessible, so BLUEPRINT and ACTIVE both refuse."""
	var well: Vector2i = _place_building("well", 40, 40)
	assert_equal(_piles.ground_pile_tile_refusal(_tile(40, 40)),
		GroundPilesScript.REFUSE_INACCESSIBLE_FOOTPRINT, "a blueprint's footprint")
	assert_true(_buildings.set_building_state(well, Catalog.BUILDING_STATE["ACTIVE"]).ok, "active")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(41, 41)),
		GroundPilesScript.REFUSE_INACCESSIBLE_FOOTPRINT, "an active building's footprint")


func test_a_destroyed_footprint_refuses_while_its_mask_is_in_force() -> void:
	"""The caller's mask refuses a tile even once the Building row is gone."""
	var mask: PackedByteArray = _empty_mask()
	mask[_tile(40, 40)] = 1
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 1000), mask), "refused")
	assert_equal(_out.error, GroundPilesScript.REFUSE_DESTROYED_FOOTPRINT, "as destroyed")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_NONE,
		"and the mask is released when the call ends")
	assert_true(_place(_tile(41, 40), _spec(ITEM_STONE, 1000), mask), "a placement beside it")
	assert_equal(_piles.ground_pile_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_NONE,
		"releases the mask after a commit too")


func test_an_existing_pile_on_a_tile_that_became_illegal_is_not_topped_up() -> void:
	"""A pile left on a footprint now DEMOLISHING refuses the start, rather than taking more goods."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), "a pile on open ground")
	var well: Vector2i = _place_building("well", 40, 40)
	assert_true(_buildings.set_building_state(well,
		Catalog.BUILDING_STATE["DEMOLISHING"]).ok, "a well now stands there, being demolished")
	var before: PackedByteArray = _inv.state_bytes()
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), "refused")
	assert_equal(_out.error, GroundPilesScript.REFUSE_DEMOLISHING_FOOTPRINT, "by name")
	assert_true(_inv.state_bytes() == before, "the old pile was not topped up")


# --- placement ----------------------------------------------------------------------------------

func test_a_placement_creates_a_world_pile_declared_at_storage_class_1500() -> void:
	"""The pile is the World's, and §5.8's open-pile factor 1500 applies to it."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 5000)), "placed: %s" % _out.error)
	assert_equal(_out.piles_created, 1, "one pile")
	assert_equal(_out.lots_created, 1, "one lot")
	assert_equal(_out.tiles_visited, 1, "one tile")
	var pile: Vector2i = _inv.ground_pile_at_tile(_tile(40, 40))
	assert_equal(_inv.container_owner(pile), _world, "World-owned")
	assert_equal(_age.storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE, "open pile")
	var factor: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(StockAgeScript.store_factor_into(_age.storage_class_of(pile), factor), "a factor")
	assert_equal(factor.value, 1500, "storage class 1500")
	assert_equal(_inv.lot_quantity_milli(_inv.container_first_lot(pile)), 5000, "the goods")
	assert_true(_inv.audit().ok, "audits")


func test_spill_is_breadth_first_north_east_south_west() -> void:
	"""5.5 piles of stone: start, N, E, S, W full, then N's own north takes the half."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 5 * PILE_OF_STONE + 200000)),
		"placed: %s" % _out.error)
	assert_equal(_used(40, 40), 400000, "the start tile fills first")
	assert_equal(_used(40, 39), 400000, "then north (-Z)")
	assert_equal(_used(41, 40), 400000, "then east")
	assert_equal(_used(40, 41), 400000, "then south")
	assert_equal(_used(39, 40), 400000, "then west")
	assert_equal(_used(40, 38), 200000, "then the first unvisited neighbour of north, its north")
	assert_equal(_used(41, 39), -1, "and nothing further")
	assert_equal(_out.piles_created, 6, "six piles")
	assert_equal(_out.tiles_visited, 6, "six tiles visited")


func test_spill_skips_impassable_and_footprint_tiles_but_keeps_the_order() -> void:
	"""Start beside the river: east is water, north is a well; south then west take the spill."""
	_place_building("well", 74, 28)
	assert_true(_place(_tile(75, 30), _spec(ITEM_STONE, 3 * PILE_OF_STONE)), _out.error)
	assert_equal(_used(75, 30), 400000, "start")
	assert_equal(_used(75, 29), -1, "north is the well's footprint")
	assert_equal(_used(76, 30), -1, "east is the river")
	assert_equal(_used(75, 31), 400000, "south is next")
	assert_equal(_used(74, 30), 400000, "then west")


func test_an_existing_pile_is_topped_up_before_spilling() -> void:
	"""Goods go into the start tile's pile until it is full, and only then to the north."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 300000)), "seed 300 units")
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 200000)), "add 200 more")
	assert_equal(_used(40, 40), 400000, "the existing pile is filled")
	assert_equal(_used(40, 39), 100000, "and the rest spills north")
	assert_equal(_out.piles_created, 1, "the second call created only the northern pile")


func test_a_pile_is_filled_to_the_per_lot_ceiling_exactly() -> void:
	"""3000 g iron: floor(400000*1000/3000) = 133333 milli is 399999 g; the rest spills."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_IRON, 200000)), _out.error)
	var first: Vector2i = _inv.ground_pile_at_tile(_tile(40, 40))
	assert_equal(_inv.lot_quantity_milli(_inv.container_first_lot(first)), 133333,
		"the largest quantity whose ceiling fits")
	assert_equal(_used(40, 40), 399999, "charged ceil(133333 * 3000 / 1000)")
	assert_equal(_used(40, 39), 200001, "the remaining 66667 milli spill north")


func test_several_spec_rows_keep_their_attributes_and_order() -> void:
	"""Each row is placed in order, carrying its own quality, provenance, recipe and age."""
	var specs: PackedInt64Array = PackedInt64Array([
		ITEM_STONE, 300000, 2, Catalog.PROVENANCE_STARTER, 7, 5000, 3,
		ITEM_STONE, 200000, 0, 0, 0, 0, 0,
	])
	assert_true(_place(_tile(40, 40), specs), _out.error)
	var start: Vector2i = _inv.ground_pile_at_tile(_tile(40, 40))
	var lot: Vector2i = _inv.container_first_lot(start)
	var found_tagged: bool = false
	while lot != InventoryScript.NULL_REF:
		if _inv.lot_quality(lot) == 2:
			found_tagged = true
			assert_equal(_inv.lot_provenance(lot), Catalog.PROVENANCE_STARTER, "provenance kept")
			assert_equal(_inv.lot_recipe_id(lot), 7, "recipe kept")
			assert_equal(_inv.lot_age_milli_hours(lot), 5000, "age kept")
			assert_equal(_inv.lot_age_remainder(lot), 3, "remainder kept")
		lot = _inv.container_next_lot(lot)
	assert_true(found_tagged, "the first row went to the start tile")
	assert_equal(_used(40, 39), 100000, "the second row's overflow spilled north")
	assert_equal(_out.lots_created, 3, "three lots: row 1, row 2's two parts")


func test_no_reachable_capacity_refuses_and_changes_nothing() -> void:
	"""Only two tiles reachable (the rest masked): 900 units refuse NO_CAPACITY, byte-identical."""
	var mask: PackedByteArray = _empty_mask()
	mask.fill(1)
	mask[_tile(40, 40)] = 0
	mask[_tile(40, 39)] = 0
	var before: PackedByteArray = _inv.state_bytes()
	var declared: int = _age.declared_container_count()
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 900000), mask), "refused")
	assert_equal(_out.error, GroundPilesScript.REFUSE_NO_CAPACITY, "explicitly")
	assert_equal(_out.piles_created, 0, "a refusal reports no counts")
	assert_true(_inv.state_bytes() == before, "inventory byte-identical")
	assert_equal(_age.declared_container_count(), declared, "nothing declared")
	assert_false(_inv.is_transaction_open(), "and no transaction is left open")
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 800000), mask), "800 fits exactly")


func test_a_refusal_midway_rolls_every_pile_back() -> void:
	"""Two lot rows, three needed: the third create_lot refuses and the first two are undone."""
	_compose(InventoryScript.new(64, 2), GroundPilesScript.new())
	var before: PackedByteArray = _inv.state_bytes()
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 3 * PILE_OF_STONE)), "refused")
	assert_equal(_out.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_LOT, "the lot store is full")
	assert_true(_inv.state_bytes() == before, "every pile and lot rolled back")
	assert_equal(_inv.ground_pile_at_tile(_tile(40, 40)), InventoryScript.NULL_REF, "no pile")


func test_preflight_answers_without_changing_anything() -> void:
	"""The dry run reports the same outcome and always rolls back."""
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_piles.preflight_lots_into_piles(_tile(40, 40), PackedByteArray(),
		_spec(ITEM_STONE, 2 * PILE_OF_STONE), _out), "it would fit")
	assert_equal(_out.piles_created, 2, "in two piles")
	assert_true(_inv.state_bytes() == before, "and nothing was written")
	assert_equal(_age.declared_container_count(), 0, "or declared")


func test_input_refusals_are_named_and_write_nothing() -> void:
	"""Open transaction, mask shape, spec shape and spec values all refuse before any write."""
	var before: PackedByteArray = _inv.state_bytes()
	var short_mask: PackedByteArray = PackedByteArray([0, 0])
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 1000), short_mask), "short mask")
	assert_equal(_out.error, GroundPilesScript.REFUSE_MASK_SHAPE, "mask shape")
	assert_false(_place(_tile(40, 40), PackedInt64Array([ITEM_STONE, 1000])), "short spec")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SPEC_SHAPE, "spec shape")
	assert_false(_place(_tile(40, 40), PackedInt64Array()), "empty spec")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SPEC_SHAPE, "an empty spec is malformed")
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 0)), "zero quantity")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SPEC_VALUE, "spec value")
	assert_false(_place(_tile(40, 40), _spec(99, 1000)), "unregistered item")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SPEC_VALUE, "spec value")
	assert_false(_place(_tile(77, 30), _spec(ITEM_STONE, 1000)), "start on water")
	assert_equal(_out.error, GroundPilesScript.REFUSE_IMPASSABLE, "the start tile's own refusal")
	_inv.begin()
	assert_false(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), "inside a transaction")
	assert_equal(_out.error, GroundPilesScript.REFUSE_TRANSACTION_OPEN, "refused")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "byte-identical throughout")
	var unbound: GroundPilesScript = GroundPilesScript.new()
	assert_false(unbound.place_lots_into_piles(0, PackedByteArray(), _spec(ITEM_STONE, 1), _out),
		"an unbound composer")
	assert_equal(_out.error, GroundPilesScript.REFUSE_NOT_BOUND, "refuses NOT_BOUND")


func test_reclaim_on_commit_drops_the_pile_and_its_declaration() -> void:
	"""Hauling the last lot out of a placed pile reclaims it; its storage class goes stale."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 5000)), _out.error)
	var pile: Vector2i = _inv.ground_pile_at_tile(_tile(40, 40))
	assert_true(_inv.sink_lot_quantity(_inv.container_first_lot(pile), 5000).ok, "haul it all")
	assert_false(_inv.is_container_valid(pile), "the empty pile is reclaimed at commit")
	assert_equal(_age.storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE,
		"the declaration still names the old generation")
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), "a new pile on the same tile")
	var reborn: Vector2i = _inv.ground_pile_at_tile(_tile(40, 40))
	assert_false(reborn == pile, "a different generation")
	assert_equal(_age.storage_class_of(reborn), StockAgeScript.STORAGE_OPEN_PILE,
		"the new pile is declared afresh")


# --- the 16384-tile cap -------------------------------------------------------------------------

func _bfs_order_from(start: int) -> PackedInt32Array:
	"""An independent N, E, S, W breadth-first order over the whole open grid."""
	var order: PackedInt32Array = PackedInt32Array()
	var seen: PackedByteArray = _empty_mask()
	order.append(start)
	seen[start] = 1
	var head: int = 0
	while head < order.size():
		var tile: int = order[head]
		head += 1
		for step: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var x: int = tile % 128 + step.x
			@warning_ignore("integer_division") var z: int = tile / 128 + step.y
			if x < 0 or x >= 128 or z < 0 or z >= 128 or seen[z * 128 + x] == 1:
				continue
			seen[z * 128 + x] = 1
			order.append(z * 128 + x)
	return order


func _fill_every_tile_but(free_tile: int) -> void:
	"""A full pile on every tile except `free_tile`: one 400000 g boulder lot each, 500 per transaction.

	A pile at rest must hold a lot (ARCH-MEM-002), so fullness is a real lot, not a claim.
	"""
	var made: int = 0
	_inv.begin()
	for tile: int in GroundPilesScript.TILE_COUNT:
		if tile == free_tile:
			continue
		var pile: Vector2i = _inv.create_ground_pile(tile).ref
		_inv.create_lot(pile, ITEM_BOULDER, 1000, 0, 0, 0, 0, 0)
		made += 1
		if made % 500 == 0:
			assert_true(_inv.commit().ok, "a batch of full piles commits")
			_inv.begin()
	assert_true(_inv.commit().ok, "the last batch commits")


func test_the_spill_reaches_the_16384th_tile() -> void:
	"""Every tile full but the one breadth-first visits last: the goods land there, visit 16384."""
	_compose(InventoryScript.new(16384, 16384), EverywherePassable.new())
	_inv.register_item(ITEM_BOULDER, InventoryScript.GROUND_PILE_MAX_MASS_G, 0)
	var start: int = _tile(64, 64)
	var order: PackedInt32Array = _bfs_order_from(start)
	assert_equal(order.size(), 16384, "the open grid is one 16384-tile component")
	var last: int = order[order.size() - 1]
	_fill_every_tile_but(last)
	assert_true(_place(start, _spec(ITEM_BOULDER, 1000)), "placed: %s" % _out.error)
	assert_equal(_out.tiles_visited, 16384, "after visiting exactly the cap")
	assert_equal(_inv.container_used_mass_g(_inv.ground_pile_at_tile(last)), 400000,
		"on the last tile in N, E, S, W breadth-first order")
	var before: PackedByteArray = _inv.state_bytes()
	assert_false(_place(start, _spec(ITEM_STONE, PILE_OF_STONE)), "a full map refuses")
	assert_equal(_out.error, GroundPilesScript.REFUSE_NO_CAPACITY, "with NO_CAPACITY")
	assert_true(_inv.state_bytes() == before, "byte-identical")


# --- the refund origin --------------------------------------------------------------------------

func _seeds() -> PackedInt32Array:
	"""A caller-owned seed buffer of exactly REFUND_SEED_CAPACITY cells, prefilled with a marker."""
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(GroundPilesScript.REFUND_SEED_CAPACITY)
	buffer.fill(-7)
	return buffer


func _origin(building: Vector2i, mask: PackedByteArray, seeds: PackedInt32Array) -> int:
	"""Derive a building's refund seeds, failing the test on refusal; returns the seed count."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_piles.refund_seeds_into(building, mask, seeds, out), "seeds: %s" % out.error)
	return out.value


func test_the_halls_outside_door_tile_is_the_starter_layouts_exit() -> void:
	"""GDD §5.9's south door at interior x5: the starter hall's one seed is (64, 69)."""
	var hall: Vector2i = _place_building("hall", 58, 59)
	var mask: PackedByteArray = _empty_mask()
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(hall, mask, seeds), 1, "one seed: the door")
	assert_equal(seeds[0], StarterStructures.EXIT_EXTERIOR_GLOBAL, "the authored exterior exit")
	assert_equal(seeds[0], _tile(64, 69), "one tile south of the wall row")
	assert_equal(seeds[1], -7, "and nothing else is written")
	var marked: int = 0
	for tile: int in mask.size():
		marked += mask[tile]
	assert_equal(marked, 120, "the 12 x 10 footprint is marked")
	assert_equal(mask[StarterStructures.EXIT_WALL_GLOBAL], 1, "the door's wall tile included")
	assert_equal(mask[seeds[0]], 0, "and the outside tile is not")


func test_a_hall_elsewhere_keeps_the_same_door_offset() -> void:
	"""The door is the layout's offset from the origin, not a fixed tile."""
	var hall: Vector2i = _place_building("hall", 10, 30)
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(hall, _empty_mask(), seeds), 1, "one seed")
	assert_equal(seeds[0], _tile(16, 40), "origin + (6, 10)")


func test_a_doorless_building_seeds_its_edge_ring_front_first() -> void:
	"""DEC-043: a 2 x 2 well at (40, 40), rotation 0, front south, ring nearest the front first."""
	var well: Vector2i = _place_building("well", 40, 40)
	var mask: PackedByteArray = _empty_mask()
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(well, mask, seeds), 8, "the eight edge tiles, no corners")
	var expected: PackedInt32Array = PackedInt32Array([
		_tile(40, 42), _tile(41, 42),
		_tile(39, 41), _tile(42, 41),
		_tile(40, 39), _tile(41, 39),
		_tile(39, 40), _tile(42, 40),
	])
	for index: int in expected.size():
		assert_equal(seeds[index], expected[index], "seed %d" % index)
	assert_equal(seeds[8], -7, "nothing past the ring is written")
	assert_equal(mask[_tile(41, 41)], 1, "the footprint is marked")
	assert_equal(mask[_tile(40, 42)], 0, "the ring is not")


func test_the_front_turns_clockwise_with_the_rotation() -> void:
	"""Rotations 1, 2, 3 face west, north, east: each one's first seed is on that side."""
	var expectations: Array[Vector2i] = [Vector2i(39, 40), Vector2i(40, 39), Vector2i(42, 40)]
	for rotation: int in [1, 2, 3]:
		_compose(InventoryScript.new(64, 64), GroundPilesScript.new())
		var well: Vector2i = _place_building("well", 40, 40, rotation)
		var seeds: PackedInt32Array = _seeds()
		_origin(well, _empty_mask(), seeds)
		var first: Vector2i = expectations[rotation - 1]
		assert_equal(seeds[0], _tile(first.x, first.y), "rotation %d's first seed" % rotation)


func test_a_rotated_hall_has_no_authored_door_and_uses_its_ring() -> void:
	"""Only rotation 0 authors the hall's door; a rotated hall is doorless (DEC-043)."""
	assert_true(GroundPilesScript.has_authored_door(
		int(Catalog.BUILDING_DEFINITION["hall"]), 0), "the rotation-0 hall has a door")
	assert_false(GroundPilesScript.has_authored_door(
		int(Catalog.BUILDING_DEFINITION["hall"]), 1), "a rotated one does not")
	assert_false(GroundPilesScript.has_authored_door(
		int(Catalog.BUILDING_DEFINITION["well"]), 0), "nor does a well")
	var turned: Vector2i = _place_building("hall", 10, 60, 1)
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(turned, _empty_mask(), seeds), 44, "10 x 12 footprint: 2 x (10 + 12)")
	assert_equal(seeds[0] % 128, 9, "front west: the first seed is in the column west of x=10")


func test_a_ring_clipped_by_the_grid_edge_keeps_only_in_grid_tiles() -> void:
	"""A well in the north-west corner has no ring to its north or west."""
	var well: Vector2i = _place_building("well", 0, 0)
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(well, _empty_mask(), seeds), 4, "south and east sides only")
	assert_equal(seeds[0], _tile(0, 2), "nearest the south front first")


func test_the_refund_origin_refuses_bad_inputs_without_writing() -> void:
	"""An off-grid door, a stale ref, a short mask and a short seed buffer all refuse."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var mask: PackedByteArray = _empty_mask()
	var seeds: PackedInt32Array = _seeds()
	var low: Vector2i = _place_building("hall", 10, 118)
	assert_false(_piles.refund_seeds_into(low, mask, seeds, out), "door off the grid")
	assert_equal(StringName(out.error), GroundPilesScript.REFUSE_DOOR_OFF_GRID, "named")
	assert_false(_piles.refund_seeds_into(Vector2i(900, 9), mask, seeds, out), "stale")
	assert_equal(StringName(out.error), GroundPilesScript.REFUSE_STALE_BUILDING, "named")
	var hall: Vector2i = _place_building("hall", 58, 59)
	assert_false(_piles.refund_seeds_into(hall, PackedByteArray([0]), seeds, out), "short mask")
	assert_equal(StringName(out.error), GroundPilesScript.REFUSE_MASK_SHAPE, "named")
	var short: PackedInt32Array = PackedInt32Array([0, 0])
	assert_false(_piles.refund_seeds_into(hall, mask, short, out), "short seed buffer")
	assert_equal(StringName(out.error), GroundPilesScript.REFUSE_SEED_SHAPE, "named")
	assert_true(mask == _empty_mask(), "no refusal marked the mask")
	assert_true(seeds == _seeds(), "or wrote a seed")


func test_refunds_spill_from_the_door_and_never_onto_the_destroyed_footprint() -> void:
	"""After the hall is removed its footprint is excluded by mask: north of the door is skipped."""
	var hall: Vector2i = _place_building("hall", 58, 59)
	var mask: PackedByteArray = _empty_mask()
	var seeds: PackedInt32Array = _seeds()
	var count: int = _origin(hall, mask, seeds)
	assert_true(_buildings.demolish_building(hall).ok, "the hall is removed")
	assert_true(_piles.place_lots_from_seeds(seeds, count, mask,
		_spec(ITEM_STONE, 3 * PILE_OF_STONE), _out), _out.error)
	assert_equal(_used(64, 69), 400000, "the door's outside tile fills first")
	assert_equal(_used(64, 68), -1, "north is the destroyed footprint")
	assert_equal(_used(65, 69), 400000, "east")
	assert_equal(_used(64, 70), 400000, "south")
	for tile: int in mask.size():
		if mask[tile] == 1:
			assert_equal(_inv.ground_pile_at_tile(tile), InventoryScript.NULL_REF,
				"no pile on footprint tile %d" % tile)


func test_a_doorless_refund_fills_the_ring_front_first_then_spills_outward() -> void:
	"""Ten piles from a removed well: the eight ring tiles in front-first order, then outward."""
	var well: Vector2i = _place_building("well", 40, 40)
	var mask: PackedByteArray = _empty_mask()
	var seeds: PackedInt32Array = _seeds()
	var count: int = _origin(well, mask, seeds)
	assert_true(_buildings.demolish_building(well).ok, "the well is removed")
	assert_true(_piles.place_lots_from_seeds(seeds, count, mask,
		_spec(ITEM_STONE, 9 * PILE_OF_STONE + 1000), _out), _out.error)
	for index: int in 8:
		assert_equal(_inv.container_used_mass_g(_inv.ground_pile_at_tile(seeds[index])), 400000,
			"ring seed %d is full" % index)
	assert_equal(_used(40, 43), 400000, "then the first seed's own neighbours: its south")
	assert_equal(_used(39, 42), 1000, "and its west, the ring corner, takes the remainder")
	for tile: int in [_tile(40, 40), _tile(41, 40), _tile(40, 41), _tile(41, 41)]:
		assert_equal(_inv.ground_pile_at_tile(tile), InventoryScript.NULL_REF, "footprint clear")


func test_a_ring_at_the_south_east_corner_never_wraps_onto_the_next_row() -> void:
	"""A well at (126, 126): its ring is only the north and west sides, all on the grid."""
	var well: Vector2i = _place_building("well", 126, 126)
	var seeds: PackedInt32Array = _seeds()
	assert_equal(_origin(well, _empty_mask(), seeds), 4, "north and west sides only")
	for index: int in 4:
		var x: int = seeds[index] % 128
		@warning_ignore("integer_division") var z: int = seeds[index] / 128
		assert_true(x == 125 or z == 125, "seed %d (%d, %d) touches the footprint" % [index, x, z])


func test_a_repeated_seed_is_visited_once() -> void:
	"""Two copies of one start tile: 1.5 piles need exactly two tiles, the start and its north."""
	var seeds: PackedInt32Array = PackedInt32Array([_tile(40, 40), _tile(40, 40)])
	assert_true(_piles.place_lots_from_seeds(seeds, 2, PackedByteArray(),
		_spec(ITEM_STONE, PILE_OF_STONE + 200000), _out), _out.error)
	assert_equal(_out.tiles_visited, 2, "the duplicate is not a second visit")
	assert_equal(_used(40, 39), 200000, "the spill went north")


func test_seeds_skip_ineligible_tiles_and_refuse_when_none_is_left() -> void:
	"""An impassable seed is skipped; with every seed refused, the first seed's code is returned."""
	var seeds: PackedInt32Array = PackedInt32Array([_tile(77, 30), _tile(40, 40)])
	assert_true(_piles.place_lots_from_seeds(seeds, 2, PackedByteArray(),
		_spec(ITEM_STONE, 1000), _out), _out.error)
	assert_equal(_used(40, 40), 1000, "the eligible seed takes it")
	var before: PackedByteArray = _inv.state_bytes()
	seeds = PackedInt32Array([_tile(77, 30), -5])
	assert_false(_piles.place_lots_from_seeds(seeds, 2, PackedByteArray(),
		_spec(ITEM_STONE, 1000), _out), "no seed is eligible")
	assert_equal(_out.error, GroundPilesScript.REFUSE_IMPASSABLE, "the first seed's refusal")
	assert_false(_piles.place_lots_from_seeds(seeds, 3, PackedByteArray(),
		_spec(ITEM_STONE, 1000), _out), "a count past the buffer")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SEED_SHAPE, "refuses the shape")
	assert_false(_piles.place_lots_from_seeds(seeds, 0, PackedByteArray(),
		_spec(ITEM_STONE, 1000), _out), "no seeds at all")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SEED_SHAPE, "refuses the shape")
	assert_true(_inv.state_bytes() == before, "byte-identical")


# --- save round trip ----------------------------------------------------------------------------

func _record_for(store: InventoryScript) -> Section.Record:
	"""A section 7 record shaped to `store`, the other runtime owners shrunk to 8 rows."""
	var record: Section.Record = Section.Record.new()
	record.owners[Section.OWNER_GEAR] = Section.OwnerRecord.new(
		Section.OWNER_GEAR, 8, PackedInt64Array())
	record.owners[Section.OWNER_RESERVATIONS] = Section.OwnerRecord.new(
		Section.OWNER_RESERVATIONS, 8, PackedInt64Array())
	var caps: Vector2i = store.canonical_capacities()
	record.owners[Section.OWNER_INVENTORY] = Section.OwnerRecord.new(
		Section.OWNER_INVENTORY, caps.x, PackedInt64Array([caps.y]))
	Section.fill_empty(record)
	return record


func _encoded(store: InventoryScript) -> PackedByteArray:
	"""Capture and encode one store's section 7, failing the test on any refusal."""
	var record: Section.Record = _record_for(store)
	var columns: InventoryScript.CanonicalColumns = Section.inventory_columns_for(record)
	var captured: SaveHeader.Refusal = Section.capture_inventory_into(record, store, columns)
	assert_true(captured.is_ok(), "capture: %s %s" % [captured.code, captured.detail])
	var result: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_record(record, result), "encode: %s" % result.detail)
	return result.bytes


func test_piles_round_trip_through_section_7_and_the_map_is_rebuilt() -> void:
	"""Piles are ordinary containers on the wire: policy, owner, capacity and anchor persist."""
	_compose(InventoryScript.new(8, 4), GroundPilesScript.new())
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, PILE_OF_STONE + 1000)), _out.error)
	var bytes: PackedByteArray = _encoded(_inv)
	var parsed: Section.Record = Section.Record.new()
	var decoded: SaveHeader.Refusal = Section.decode_into_versioned(bytes, 0, bytes.size(),
		Section.SECTION_SCHEMA_VERSION, parsed)
	assert_equal(decoded.code, Section.REFUSE_NONE, "decodes: %s" % decoded.detail)
	var restored: InventoryScript = InventoryScript.new(8, 4)
	restored.register_item(ITEM_STONE, STONE_MASS_G, 0)
	restored.register_item(ITEM_IRON, IRON_MASS_G, 0)
	var applied: SaveHeader.Refusal = Section.apply_inventory(parsed, restored,
		Section.inventory_columns_for(parsed))
	assert_equal(applied.code, Section.REFUSE_NONE, "publishes: %s" % applied.detail)
	assert_true(restored._pile_at_tile == _inv._pile_at_tile, "the rebuilt map equals the live one")
	for tile: int in [_tile(40, 40), _tile(40, 39)]:
		var pile: Vector2i = restored.ground_pile_at_tile(tile)
		assert_true(restored.is_ground_pile(pile), "tile %d still holds a pile" % tile)
		assert_equal(restored.container_owner(pile), _world, "World-owned")
		assert_equal(restored.container_max_mass_g(pile), 400000, "400000 g")
	assert_true(restored.audit().ok, "the restored store audits")
	assert_equal(_encoded(restored), bytes, "save -> load -> save is byte-identical")


# --- decision 0533: the composer as Buildings' placement authority (0532's M4) ------------------

func test_the_composer_refuses_a_footprint_tile_that_holds_a_live_pile() -> void:
	"""`building_tile_refusal()`: a pile tile refuses by name, a clear tile does not."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), _out.error)
	assert_equal(_piles.building_tile_refusal(_tile(40, 40)), GroundPilesScript.REFUSE_BUILDING_OVER_PILE,
		"the pile tile is refused")
	assert_equal(_piles.building_tile_refusal(_tile(41, 40)), GroundPilesScript.REFUSE_NONE,
		"its neighbour is not")
	assert_equal(GroundPilesScript.new().building_tile_refusal(_tile(41, 40)),
		GroundPilesScript.REFUSE_NOT_BOUND, "an unbound composer waves nothing through")


func test_bound_as_placement_authority_the_composer_stops_a_building_over_a_pile() -> void:
	"""Bound through `set_placement_authority()`, every footprint tile is shown to the composer."""
	assert_true(_place(_tile(40, 40), _spec(ITEM_STONE, 1000)), _out.error)
	var well: int = int(Catalog.BUILDING_DEFINITION["well"])
	assert_true(_buildings.set_placement_authority(_piles).ok, "the composer binds")
	var refused: BuildingsScript.OpResult = _buildings.place_building(well, _tile(39, 39), 0,
		START_MASK)
	assert_equal(refused.error, GroundPilesScript.REFUSE_BUILDING_OVER_PILE,
		"the well's far corner covers the pile")
	assert_equal(_buildings.live_building_count(), 0, "and nothing was placed")
	assert_true(_buildings.place_building(well, _tile(42, 40), 0, START_MASK).ok,
		"the tile beside the pile is free")
	assert_true(_buildings.set_placement_authority(null).ok, "unbinding is allowed")
	assert_false(_buildings.has_placement_authority(), "and leaves no authority")
	assert_true(_buildings.place_building(well, _tile(39, 39), 0, START_MASK).ok,
		"an unguarded store places over the pile, which is why the settlement binds it")
