extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/store_policy.gd`: REQ-SET-117's per-item store filters and minimum
## reserves, stored as ARCH-STATE-004's BuildingItemAllow and BuildingItemMinimum (decision 1031).
##
## THE NUMBERS ARE TRANSCRIBED FROM THE DOCUMENTS, not read back out of the module: 1024 exterior
## structures (GDD §4.2), 256 compiled item keys (ARCH-STATE-004) and §3's 262144-row arena, whose
## two rows are 262144 B and 2097152 B. The 4096-byte stamp is decision 1031's.

const Buildings := preload("res://scripts/core/buildings.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")

const BUILDING_ROWS: int = 1024
const ITEM_KEYS: int = 256
const POLICY_ROWS: int = 262144
const ALLOW_BYTES: int = 262144
const MINIMUM_BYTES: int = 2097152
const STAMP_BYTES: int = 4096

## Three registered items in two filter categories, and one id that is never registered.
const ITEM_GRAIN: int = 10
const ITEM_ROOTS: int = 11
const ITEM_WOOD: int = 20
const ITEM_UNREGISTERED: int = 99
const CATEGORY_FOOD: int = 0
const CATEGORY_MATERIAL: int = 1
const MASK_FOOD_ONLY: int = 1

## GDD §5.9: an open stockpile is 4x4, 400000 g, unlocked at Start (milestone bit 0).
const STOCKPILE_G: int = 400000
const START_MASK: int = 1
const STOCKPILE_ORIGIN_X: int = 20
const STOCKPILE_ORIGIN_Z: int = 30
const OTHER_ORIGIN_X: int = 40

var _buildings: Buildings = null
var _inventory: InventoryScript = null
var _policy: StorePolicy = null
var _stockpile: Vector2i = Vector2i(-1, 0)
var _store: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""One stockpile building with its main store, over an inventory with three registered items."""
	_buildings = Buildings.new()
	_inventory = InventoryScript.new()
	assert_true(_inventory.register_item(ITEM_GRAIN, 1000, CATEGORY_FOOD).ok, "grain registers")
	assert_true(_inventory.register_item(ITEM_ROOTS, 1000, CATEGORY_FOOD).ok, "roots register")
	assert_true(_inventory.register_item(ITEM_WOOD, 2000, CATEGORY_MATERIAL).ok, "wood registers")
	_policy = StorePolicy.new(_buildings, _inventory)
	_stockpile = _place_stockpile(STOCKPILE_ORIGIN_X)
	_store = _container(_stockpile, _origin(STOCKPILE_ORIGIN_X), InventoryScript.FILTERS_ACCEPT_ALL)


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_policy = null
	_inventory = null
	_buildings = null


# --- fixture helpers ------------------------------------------------------------------------------

func _origin(x: int) -> int:
	"""GDD §5.1's tile index `z*128+x` on the stockpile row."""
	return STOCKPILE_ORIGIN_Z * 128 + x


func _place_stockpile(x: int) -> Vector2i:
	"""Place one open stockpile at (x, 30), rotation 0."""
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["open_stockpile"]), _origin(x), 0, START_MASK)
	assert_true(placed.ok, "the stockpile places (%s)" % placed.error)
	return placed.ref


func _container(owner: Vector2i, anchor: int, filters: int) -> Vector2i:
	"""One reachable container of `owner` anchored at `anchor`."""
	var made: InventoryScript.OpResult = _inventory.create_container(owner, STOCKPILE_G, filters,
		InventoryScript.UNSET_POLICY, true, anchor)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _lot(container: Vector2i, item: int, quantity_milli: int) -> Vector2i:
	"""One ordinary lot placed into `container`."""
	var made: InventoryScript.OpResult = _inventory.create_lot(container, item, quantity_milli, 0,
		CatalogScript.PROVENANCE_ORDINARY, 0, 0, 0)
	assert_true(made.ok, "the lot is created (%s)" % made.error)
	return made.ref


# --- the budget -----------------------------------------------------------------------------------

func test_the_arena_is_sections_3_budget_plus_the_binding_stamp() -> void:
	"""§3's two rows at 1024 x 256, plus decision 1031's per-building stamp, and nothing else."""
	assert_equal(StorePolicy.BUILDING_CAPACITY, BUILDING_ROWS, "1024 exterior structures")
	assert_equal(StorePolicy.ITEM_CAPACITY, ITEM_KEYS, "256 compiled item keys")
	assert_equal(StorePolicy.POLICY_CELLS, POLICY_ROWS, "262144 policy rows")
	assert_equal(_policy.ledger_bytes(), ALLOW_BYTES + MINIMUM_BYTES + STAMP_BYTES,
		"262144 + 2097152 + 4096 bytes")


# --- defaults --------------------------------------------------------------------------------------

func test_an_unconfigured_store_admits_by_its_category_mask_alone() -> void:
	"""A store nobody filtered restricts nothing beyond its container's category mask."""
	for item: int in [ITEM_GRAIN, ITEM_ROOTS, ITEM_WOOD]:
		assert_true(_policy.store_admits(_store, item), "item %d is admitted" % item)
		assert_true(_policy.is_allowed(_stockpile, item), "its byte reads allowed")
		assert_equal(_policy.minimum_milli_of(_stockpile, item), 0, "with no minimum")
	assert_false(_policy.is_policy_bound(_stockpile), "and the building owns no policy row yet")


func test_the_category_mask_still_decides_without_any_policy() -> void:
	"""A main store whose mask excludes a category admits nothing of it, configured or not."""
	var food_only: Vector2i = _container(_place_stockpile(OTHER_ORIGIN_X), _origin(OTHER_ORIGIN_X),
		MASK_FOOD_ONLY)
	assert_true(_policy.store_admits(food_only, ITEM_GRAIN), "food is in the mask")
	assert_false(_policy.store_admits(food_only, ITEM_WOOD), "material is not")


# --- the allow byte -------------------------------------------------------------------------------

func test_disallowing_an_item_refuses_exactly_that_item() -> void:
	"""REQ-SET-117's per-item filter: one item out, its category neighbour and the rest still in."""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, StorePolicy.DISALLOWED),
		StorePolicy.REFUSE_NONE, "the byte is written")
	assert_false(_policy.store_admits(_store, ITEM_GRAIN), "grain is no longer admitted")
	assert_true(_policy.store_admits(_store, ITEM_ROOTS), "roots, same category, still are")
	assert_true(_policy.store_admits(_store, ITEM_WOOD), "and so is wood")
	assert_false(_policy.is_allowed(_stockpile, ITEM_GRAIN), "the byte reads disallowed")
	assert_true(_policy.is_policy_bound(_stockpile), "and the building now owns its row")
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, StorePolicy.ALLOWED),
		StorePolicy.REFUSE_NONE, "allowing it again is written")
	assert_true(_policy.store_admits(_store, ITEM_GRAIN), "and grain is admitted again")


func test_the_allow_byte_only_restricts_the_category_mask() -> void:
	"""ARCH-STATE-004: the byte "further restricts" the mask; allowing cannot admit a masked item."""
	var building: Vector2i = _place_stockpile(OTHER_ORIGIN_X)
	var food_only: Vector2i = _container(building, _origin(OTHER_ORIGIN_X), MASK_FOOD_ONLY)
	assert_equal(_policy.set_allowed(building, ITEM_WOOD, StorePolicy.ALLOWED),
		StorePolicy.REFUSE_NONE, "the byte is written allowed")
	assert_false(_policy.store_admits(food_only, ITEM_WOOD), "and wood is still not admitted")


func test_only_the_buildings_main_store_carries_its_policy() -> void:
	"""DEMO-CONTAIN-R01 #3a: owned AND anchored at the origin tile. Every other container: mask only."""
	var off_origin: Vector2i = _container(_stockpile, _origin(STOCKPILE_ORIGIN_X) + 1,
		InventoryScript.FILTERS_ACCEPT_ALL)
	var unplaced: Vector2i = _container(_stockpile, InventoryScript.UNPLACED_TILE,
		InventoryScript.FILTERS_ACCEPT_ALL)
	var resident: Vector2i = _buildings.directory().create(EntityDirectory.KIND_RESIDENT)
	var satchel: Vector2i = _container(resident, _origin(STOCKPILE_ORIGIN_X),
		InventoryScript.FILTERS_ACCEPT_ALL)
	var other: Vector2i = _place_stockpile(OTHER_ORIGIN_X)
	var foreign: Vector2i = _container(other, _origin(STOCKPILE_ORIGIN_X),
		InventoryScript.FILTERS_ACCEPT_ALL)
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, StorePolicy.DISALLOWED),
		StorePolicy.REFUSE_NONE, "grain is filtered out of the stockpile")
	assert_false(_policy.store_admits(_store, ITEM_GRAIN), "the main store refuses grain")
	assert_true(_policy.store_admits(off_origin, ITEM_GRAIN), "an owned store off the origin does not")
	assert_true(_policy.store_admits(unplaced, ITEM_GRAIN), "nor does an unplaced owned store")
	assert_true(_policy.store_admits(satchel, ITEM_GRAIN), "nor a non-building owner's store there")
	assert_true(_policy.store_admits(foreign, ITEM_GRAIN), "nor another building's store there")


func test_a_dead_container_or_an_unknown_item_admits_nothing() -> void:
	"""Absence is false, never the default: a selector must not route goods to a missing store."""
	assert_false(_policy.store_admits(Vector2i(-1, 0), ITEM_GRAIN), "the null container")
	assert_false(_policy.store_admits(Vector2i(_store.x, _store.y + 1), ITEM_GRAIN),
		"a stale generation")
	assert_false(_policy.store_admits(_store, ITEM_UNREGISTERED), "an unregistered item")
	assert_false(_policy.store_admits(_store, -1), "a negative item id")
	assert_false(_policy.store_admits(_store, ITEM_KEYS), "an id past the 256-key envelope")


# --- refusals write nothing ------------------------------------------------------------------------

func test_every_writer_refusal_is_named_and_writes_nothing() -> void:
	"""Each refusal has its own code and leaves the policy and its binding exactly as they were."""
	var dead: Vector2i = Vector2i(_stockpile.x, _stockpile.y + 1)
	assert_equal(_policy.set_allowed(dead, ITEM_GRAIN, 0), StorePolicy.REFUSE_STALE_BUILDING,
		"a stale building")
	assert_equal(_policy.set_allowed(_stockpile, ITEM_UNREGISTERED, 0),
		StorePolicy.REFUSE_UNKNOWN_ITEM, "an unregistered item")
	assert_equal(_policy.set_allowed(_stockpile, ITEM_KEYS, 0), StorePolicy.REFUSE_UNKNOWN_ITEM,
		"an id past the envelope")
	assert_equal(_policy.set_allowed(_stockpile, -1, 0), StorePolicy.REFUSE_UNKNOWN_ITEM,
		"a negative id")
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 2), StorePolicy.REFUSE_ALLOWED_DOMAIN,
		"an allow byte of 2")
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, -1),
		StorePolicy.REFUSE_ALLOWED_DOMAIN, "an allow byte of -1")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, -1),
		StorePolicy.REFUSE_NEGATIVE_MINIMUM, "a negative minimum")
	assert_equal(_policy.set_minimum(dead, ITEM_GRAIN, 5), StorePolicy.REFUSE_STALE_BUILDING,
		"a minimum on a stale building")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_UNREGISTERED, 5),
		StorePolicy.REFUSE_UNKNOWN_ITEM, "a minimum on an unknown item")
	assert_false(_policy.is_policy_bound(_stockpile), "no refusal bound the row")
	assert_true(_policy.is_allowed(_stockpile, ITEM_GRAIN), "grain is still allowed")
	assert_equal(_policy.minimum_milli_of(_stockpile, ITEM_GRAIN), 0, "with no minimum")


func test_the_boundary_values_are_accepted() -> void:
	"""The edges of every legal domain: item 0 and 255, both allow values, minimum 0 and int64 max."""
	assert_true(_inventory.register_item(0, 1, CATEGORY_FOOD).ok, "item 0 registers")
	assert_true(_inventory.register_item(ITEM_KEYS - 1, 1, CATEGORY_FOOD).ok, "item 255 registers")
	for item: int in [0, ITEM_KEYS - 1]:
		assert_equal(_policy.set_allowed(_stockpile, item, StorePolicy.DISALLOWED),
			StorePolicy.REFUSE_NONE, "item %d takes a byte" % item)
		assert_false(_policy.store_admits(_store, item), "and is refused by the store")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE,
		"a zero minimum")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 9223372036854775807),
		StorePolicy.REFUSE_NONE, "the int64 maximum")
	assert_equal(_policy.minimum_milli_of(_stockpile, ITEM_GRAIN), 9223372036854775807, "is stored")
	assert_equal(_policy.allowed_refusal(_stockpile, ITEM_GRAIN, StorePolicy.ALLOWED),
		StorePolicy.REFUSE_NONE, "the predicate agrees with the writer")
	assert_equal(_policy.minimum_refusal(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE,
		"for both kinds")


# --- the minimum -----------------------------------------------------------------------------------

func test_ordinary_production_may_not_draw_below_the_minimum() -> void:
	"""REQ-SET-117: the minimum holds unreserved stock back from ordinary production."""
	_lot(_store, ITEM_GRAIN, 7000)
	var reserved: Vector2i = _lot(_store, ITEM_GRAIN, 5000)
	_lot(_store, ITEM_WOOD, 9000)
	assert_true(_inventory.reserve_lot(reserved, 2000).ok, "2 U of the second grain lot is claimed")
	assert_equal(_policy.ordinary_withdrawable_milli(_store, ITEM_GRAIN), 10000,
		"with no minimum: 12 U held less 2 U claimed, and no wood counted")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 4000), StorePolicy.REFUSE_NONE,
		"a 4 U minimum is set")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_GRAIN), 4000, "the store reports it")
	assert_equal(_policy.ordinary_withdrawable_milli(_store, ITEM_GRAIN), 6000,
		"10 U unreserved less the 4 U minimum")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 10000), StorePolicy.REFUSE_NONE,
		"the minimum rises to exactly the unreserved stock")
	assert_equal(_policy.ordinary_withdrawable_milli(_store, ITEM_GRAIN), 0, "nothing may be drawn")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 50000), StorePolicy.REFUSE_NONE,
		"and past it")
	assert_equal(_policy.ordinary_withdrawable_milli(_store, ITEM_GRAIN), 0, "never below zero")
	assert_equal(_policy.ordinary_withdrawable_milli(_store, ITEM_WOOD), 9000,
		"wood keeps its own, unset minimum")


func test_a_minimum_binds_only_the_main_store() -> void:
	"""Another container of the same building holds nothing back for the building's minimum."""
	var off_origin: Vector2i = _container(_stockpile, _origin(STOCKPILE_ORIGIN_X) + 1,
		InventoryScript.FILTERS_ACCEPT_ALL)
	_lot(off_origin, ITEM_GRAIN, 3000)
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 2000), StorePolicy.REFUSE_NONE,
		"the stockpile keeps 2 U")
	assert_equal(_policy.store_minimum_milli(off_origin, ITEM_GRAIN), 0, "not in the other store")
	assert_equal(_policy.ordinary_withdrawable_milli(off_origin, ITEM_GRAIN), 3000,
		"all of whose grain is drawable")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_UNREGISTERED), 0, "an unknown item has none")
	assert_equal(_policy.store_minimum_milli(Vector2i(-1, 0), ITEM_GRAIN), 0, "nor a dead store")
	assert_equal(_policy.ordinary_withdrawable_milli(Vector2i(-1, 0), ITEM_GRAIN), 0,
		"and a dead store has nothing to draw")


# --- reuse -----------------------------------------------------------------------------------------

func test_a_reused_building_row_inherits_nothing() -> void:
	"""A demolished building's filter and minimum never surface on the building reusing its row."""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "filtered")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_ROOTS, 3000), StorePolicy.REFUSE_NONE, "kept")
	var row: int = _buildings.directory().get_typed_row(_stockpile)
	assert_true(_inventory.destroy_container(_store).ok, "the empty store is retired")
	assert_true(_buildings.demolish_building(_stockpile).ok, "the stockpile is demolished")
	var successor: Vector2i = _place_stockpile(STOCKPILE_ORIGIN_X)
	assert_equal(_buildings.directory().get_typed_row(successor), row, "the row is reused")
	var store: Vector2i = _container(successor, _origin(STOCKPILE_ORIGIN_X),
		InventoryScript.FILTERS_ACCEPT_ALL)
	assert_false(_policy.is_policy_bound(successor), "the successor owns no row yet")
	assert_true(_policy.store_admits(store, ITEM_GRAIN), "and admits grain")
	assert_equal(_policy.minimum_milli_of(successor, ITEM_ROOTS), 0, "with no inherited minimum")
	assert_equal(_policy.set_allowed(successor, ITEM_WOOD, 0), StorePolicy.REFUSE_NONE,
		"its first write binds the row")
	assert_true(_policy.store_admits(store, ITEM_GRAIN), "and resets grain, not just reads past it")
	assert_equal(_policy.minimum_milli_of(successor, ITEM_ROOTS), 0, "and the roots minimum")
	assert_false(_policy.store_admits(store, ITEM_WOOD), "while its own write holds")
	assert_false(_policy.is_allowed(_stockpile, ITEM_GRAIN), "the dead ref shows no policy at all")


func test_a_new_world_inherits_nothing_only_because_the_store_is_cleared_with_it() -> void:
	"""Review H1: persistent IDs restart with the directory, so the stamp is unique per world only.

	Without `clear()` a new world's first stockpile, at the same row with the same persistent ID,
	reads the old world's filter -- which is why every reset path must clear this store too
	(decision 1031). With it, nothing is inherited.
	"""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "filtered")
	_buildings.clear()
	var unreset: Vector2i = _place_stockpile(STOCKPILE_ORIGIN_X)
	assert_true(_policy.is_policy_bound(unreset), "an unreset store mistakes the newcomer")
	assert_false(_policy.is_allowed(unreset, ITEM_GRAIN), "and hands it the old filter")
	assert_true(_inventory.is_item_registered(ITEM_GRAIN), "while grain is still a known item")
	_buildings.clear()
	_policy.clear()
	var fresh: Vector2i = _place_stockpile(STOCKPILE_ORIGIN_X)
	assert_false(_policy.is_policy_bound(fresh), "a cleared store binds nothing")
	assert_true(_policy.is_allowed(fresh, ITEM_GRAIN), "and the new world's stockpile admits grain")


func test_two_owned_stores_at_the_origin_both_carry_the_policy() -> void:
	"""Decision 1031 P8 (a): the policy is not withheld from a second store at the origin."""
	var second: Vector2i = _container(_stockpile, _origin(STOCKPILE_ORIGIN_X),
		InventoryScript.FILTERS_ACCEPT_ALL)
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "filtered")
	assert_false(_policy.store_admits(_store, ITEM_GRAIN), "the first store refuses grain")
	assert_false(_policy.store_admits(second, ITEM_GRAIN), "and so does the second")


func test_clear_returns_every_row_to_the_defaults() -> void:
	"""`clear()` unbinds and resets without reallocating."""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "filtered")
	assert_equal(_policy.set_minimum(_stockpile, ITEM_GRAIN, 1), StorePolicy.REFUSE_NONE, "kept")
	_policy.clear()
	assert_false(_policy.is_policy_bound(_stockpile), "unbound")
	assert_true(_policy.store_admits(_store, ITEM_GRAIN), "admitting again")
	assert_equal(_policy.minimum_milli_of(_stockpile, ITEM_GRAIN), 0, "with no minimum")
	assert_equal(_policy.ledger_bytes(), ALLOW_BYTES + MINIMUM_BYTES + STAMP_BYTES, "same size")


func test_the_per_building_reads_refuse_absence() -> void:
	"""A stale building or an unknown item has no policy to show: false and 0, never a default."""
	var dead: Vector2i = Vector2i(_stockpile.x, _stockpile.y + 1)
	assert_false(_policy.is_allowed(dead, ITEM_GRAIN), "a stale building shows nothing allowed")
	assert_false(_policy.is_allowed(_stockpile, ITEM_UNREGISTERED), "nor an unknown item")
	assert_false(_policy.is_policy_bound(dead), "and binds nothing")
	assert_equal(_policy.minimum_milli_of(dead, ITEM_GRAIN), 0, "its minimum reads 0")
	assert_equal(_policy.building_refusal(_stockpile), StorePolicy.REFUSE_NONE, "the live one is live")
	assert_equal(_policy.item_refusal(ITEM_GRAIN), StorePolicy.REFUSE_NONE, "grain is an item")
	assert_true(_policy.directory() == _buildings.directory(), "one shared directory")


func test_a_bound_building_still_has_no_cell_for_an_unknown_item() -> void:
	"""Binding a row does not make an unregistered id readable: it is absent, not defaulted."""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "bound")
	assert_false(_policy.is_allowed(_stockpile, ITEM_UNREGISTERED), "an unknown item reads false")
	assert_equal(_policy.minimum_milli_of(_stockpile, ITEM_UNREGISTERED), 0, "with no minimum")
	assert_equal(_policy.minimum_milli_of(_stockpile, ITEM_KEYS + 5), 0, "nor one past the envelope")
	assert_equal(_policy.store_minimum_milli(_store, ITEM_UNREGISTERED), 0, "and the store agrees")


func test_the_origin_accessor_refuses_a_stale_building() -> void:
	"""`buildings.origin_tile_or_none()`: the origin for a live building, -1 once it is gone."""
	assert_equal(_buildings.origin_tile_or_none(_stockpile), _origin(STOCKPILE_ORIGIN_X),
		"a live building answers its origin")
	assert_true(_inventory.destroy_container(_store).ok, "its store is retired")
	assert_true(_buildings.demolish_building(_stockpile).ok, "it is demolished")
	assert_equal(_buildings.origin_tile_or_none(_stockpile), -1, "a stale reference answers -1")
	assert_equal(_buildings.origin_tile_or_none(Vector2i(-1, 0)), -1, "and so does the null ref")


# --- allocation ------------------------------------------------------------------------------------

func _creation_mark() -> int:
	"""A counter that rises by one for every object Godot creates: the instance-ID validator.

	`OBJECT_COUNT` is a LIVE census and cannot see a RefCounted built and dropped inside a loop
	(`test_jobs.gd` records that trap). An ObjectID's bits above the low 24 slot bits hold a
	validator taken from a global counter that advances once per created object, so the difference
	between two marks, less the second mark's own probe, is the number of objects created between
	them -- live or already freed.
	"""
	return RefCounted.new().get_instance_id() >> 24


func test_the_creation_mark_sees_a_transient_object() -> void:
	"""The probe below is only evidence if it can see what the census cannot."""
	var before: int = _creation_mark()
	for _pass: int in 10:
		RefCounted.new()
	assert_equal(_creation_mark() - before - 1, 10, "ten dropped temporaries are counted")


func test_the_published_queries_allocate_nothing() -> void:
	"""`store_admits()` and the minimum reads run on a selector's path, so they create no object."""
	assert_equal(_policy.set_allowed(_stockpile, ITEM_GRAIN, 0), StorePolicy.REFUSE_NONE, "filtered")
	_lot(_store, ITEM_ROOTS, 4000)
	var answered: int = 0
	var before: int = _creation_mark()
	for _pass: int in 100:
		answered += 1 if _policy.store_admits(_store, ITEM_ROOTS) else 0
		answered += 1 if _policy.store_admits(_store, ITEM_GRAIN) else 0
		answered += _policy.ordinary_withdrawable_milli(_store, ITEM_ROOTS)
		answered += _policy.store_minimum_milli(_store, ITEM_GRAIN)
	var created: int = _creation_mark() - before - 1
	assert_equal(answered, 100 + 100 * 4000, "the reads answered")
	assert_equal(created, 0, "and created no object, not even a transient one")
