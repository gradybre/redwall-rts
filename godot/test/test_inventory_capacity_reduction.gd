extends "res://test/framework/test_case.gd"
## `inventory.gd::reduce_container_capacity()`: DEMO-CONTAIN-R01 #3b's recompute (decision 0536).
##
## A pantry shelf adds 50000 g to its building's pantry container; removing one lowers that
## container's capacity. The door refuses, writing nothing, a dead container, a ground pile, a
## non-positive or oversized reduction, and -- #3b's rule -- a capacity the contents plus the
## reservations would exceed. Inside a transaction it is journaled and rolled back like any write.

const InventoryScript := preload("res://scripts/core/inventory.gd")

const ITEM_GRAIN: int = 0
const GRAIN_MASS_G: int = 1000
const OWNER: Vector2i = Vector2i(3, 1)

var _inv: InventoryScript = null


func before_each() -> void:
	"""A small inventory with one registered item."""
	_inv = InventoryScript.new(16, 16)
	assert_true(_inv.register_item(ITEM_GRAIN, GRAIN_MASS_G, 0).ok, "grain registers")


func _container(max_mass_g: int) -> Vector2i:
	"""One accept-all container of `max_mass_g`."""
	var made: InventoryScript.OpResult = _inv.create_container(OWNER, max_mass_g,
		InventoryScript.FILTERS_ACCEPT_ALL, InventoryScript.UNSET_POLICY, true, 5)
	assert_true(made.ok, "a container (%s)" % made.error)
	return made.ref


func test_a_reduction_lowers_the_capacity_and_reports_it() -> void:
	"""200000 g less one shelf is 150000 g."""
	var store: Vector2i = _container(200000)
	var reduced: InventoryScript.OpResult = _inv.reduce_container_capacity(store, 50000)
	assert_true(reduced.ok, "reduced (%s)" % reduced.error)
	assert_equal(reduced.value, 150000, "the new capacity")
	assert_equal(_inv.container_max_mass_g(store), 150000, "stored")
	assert_true(_inv.audit().ok, "audits")


func test_contents_plus_reservations_must_still_fit() -> void:
	"""#3b: refuse when used + reserved would exceed the reduced capacity; exactly full is fine."""
	var store: Vector2i = _container(200000)
	assert_true(_inv.create_lot(store, ITEM_GRAIN, 140000, 0, 0, 0, 0, 0).ok, "140000 g used")
	assert_true(_inv.reserve_container_mass(store, 10001).ok, "10001 g reserved")
	var before: PackedByteArray = _inv.state_bytes()
	assert_equal(_inv.reduce_container_capacity(store, 50000).error,
		InventoryScript.REFUSE_CAPACITY_EXCEEDED, "150001 g would not fit 150000")
	assert_true(_inv.state_bytes() == before, "nothing written")
	assert_true(_inv.release_container_mass(store, 1).ok, "one gram less reserved")
	assert_true(_inv.reduce_container_capacity(store, 50000).ok, "exactly full fits")


func test_bad_inputs_refuse_by_name_writing_nothing() -> void:
	"""A dead container, a zero or negative reduction, and one larger than the capacity."""
	var store: Vector2i = _container(40000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_equal(_inv.reduce_container_capacity(Vector2i(9, 1), 1).error,
		InventoryScript.REFUSE_INVALID_CONTAINER, "dead")
	assert_equal(_inv.reduce_container_capacity(store, 0).error,
		InventoryScript.REFUSE_INVALID_MASS, "zero")
	assert_equal(_inv.reduce_container_capacity(store, -5).error,
		InventoryScript.REFUSE_INVALID_MASS, "negative")
	assert_equal(_inv.reduce_container_capacity(store, 40001).error,
		InventoryScript.REFUSE_INVALID_MASS, "more than it has")
	assert_true(_inv.state_bytes() == before, "nothing written")
	assert_true(_inv.reduce_container_capacity(store, 40000).ok, "down to zero is allowed")


func test_a_ground_pile_keeps_its_fixed_capacity() -> void:
	"""#9's 400000 g is not recomputed: GROUND_PILE_CAPACITY_FIXED."""
	var columns: InventoryScript.CanonicalColumns = InventoryScript.CanonicalColumns.new(16, 16)
	var store: Vector2i = _container(InventoryScript.GROUND_PILE_MAX_MASS_G)
	assert_true(_inv.create_lot(store, ITEM_GRAIN, 1000, 0, 0, 0, 0, 0).ok, "a lot keeps it")
	assert_true(_inv.copy_canonical_columns_into(columns), "projects")
	columns.c_policy[store.x] = InventoryScript.POLICY_GROUND_PILE
	columns.c_owner_slot[store.x] = 0
	columns.c_owner_generation[store.x] = 1
	assert_true(_inv.restore_canonical_columns(columns), "now a pile (%s)" % _inv.canonical_detail())
	assert_equal(_inv.reduce_container_capacity(store, 1).error,
		InventoryScript.REFUSE_GROUND_PILE_CAPACITY_FIXED, "refused")


func test_an_aborted_transaction_restores_the_capacity() -> void:
	"""Journaled: the caller's abort brings the old capacity back."""
	var store: Vector2i = _container(200000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "a transaction")
	assert_true(_inv.reduce_container_capacity(store, 50000).ok, "reduced inside it")
	assert_equal(_inv.container_max_mass_g(store), 150000, "visible inside")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "the abort restored it")
