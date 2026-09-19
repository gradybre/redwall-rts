extends "res://test/framework/test_case.gd"
## Suite for STOCK-C4-LIFETIME-R01: the BORROWED seed-expiry authority in `inventory.gd`.
##
## `settlement_system.gd` owns both collaborators. `stock_age.gd` holds this store strongly
## because it reads and mutates it; the store only ever ASKS a predicate, so it borrows. These
## tests pin the four halves of that repair: the retention really disappears, a live binding is
## still consulted and still guarded against re-entry, `clear()` still keeps the wiring, and a
## binding whose object has been released is a REFUSAL rather than a quiet return to the
## never-bound case that enforces nothing.
##
## Capacities are deliberately tiny -- two containers, four lots -- because nothing here is
## about capacity, and a spec-sized store would allocate megabytes per test for no evidence.

const InventoryScript := preload("res://scripts/core/inventory.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")

## GDD §5.7 raw food, 250 g/U, in category 0. Any registered item does; the guard never asks
## this module what a seed is.
const ITEM_GRAIN: int = 0
const CATEGORY_FOOD: int = 0
const BIG_MASS: int = 1000000
const OWNER: Vector2i = Vector2i(3, 1)

var _inv: InventoryScript = null
var _box: Vector2i = InventoryScript.NULL_REF
var _lot: Vector2i = InventoryScript.NULL_REF


class SeedGuard extends RefCounted:
	"""A stand-in seed-expiry authority whose verdict and question count are both controllable."""
	var refuses: bool = true
	var queries: int = 0

	func refuses_seed_consumption(_lot_ref: Vector2i) -> bool:
		"""The predicate `inventory.gd` calls on every seed-consuming admission."""
		queries += 1
		return refuses


class ReentrantGuard extends RefCounted:
	"""An authority that tries to mutate the store from inside its own predicate."""
	var inventory: Variant = null
	var target: Vector2i = Vector2i(-1, 0)
	var reentry_error: StringName = &"NOT_ATTEMPTED"

	func refuses_seed_consumption(_lot_ref: Vector2i) -> bool:
		"""Answer honestly, but try to sink the lot being validated on the way through."""
		reentry_error = inventory.sink_lot_quantity(target, 1).error
		return false


func before_each() -> void:
	"""A two-container, four-lot store holding one registered item in one lot."""
	_inv = InventoryScript.new(2, 4)
	_inv.register_item(ITEM_GRAIN, 250, CATEGORY_FOOD)
	_box = _inv.create_container(OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true).ref
	_lot = _inv.create_lot(_box, ITEM_GRAIN, 4000, 0, 0, 0, 0, 0).ref


func _bind_then_release_guard() -> void:
	"""Bind a real guard and then drop the only external reference to it.

	With the binding borrowed, the object is reclaimed as this helper returns, which is exactly
	the state a shutdown -- or any owner dropping the aging stage -- produces.
	"""
	var guard: SeedGuard = SeedGuard.new()
	assert_true(_inv.set_seed_expiry_authority(guard).ok, "the guard binds")
	guard = null


func test_the_bound_pair_is_released_once_external_references_are_dropped() -> void:
	"""The actual retention, with the real `stock_age.gd` and the real catalog.

	The stage holds the store; the store borrows the stage's predicate. Dropping both externals
	must free BOTH, which it cannot do while the second edge is strong. This proves one ownership
	cycle is gone -- not that every shutdown warning in the project had the same cause.
	"""
	var inventory: InventoryScript = InventoryScript.new(2, 4)
	var definitions: ItemDefinitionsScript = ItemDefinitionsScript.new()
	definitions.load_default(inventory)
	var age: StockAgeScript = StockAgeScript.new(inventory, definitions)
	assert_true(inventory.set_seed_expiry_authority(age).ok, "the real predicate binds")
	assert_true(inventory.has_seed_expiry_authority(), "and is live while somebody holds it")
	var inventory_ref: WeakRef = weakref(inventory)
	var age_ref: WeakRef = weakref(age)
	inventory = null
	age = null
	definitions = null
	assert_null(age_ref.get_ref(), "the aging stage is released, not retained by the store")
	assert_null(inventory_ref.get_ref(), "and the store falls with it: no ownership cycle")


func test_a_live_binding_is_still_consulted_on_every_admission() -> void:
	"""Borrowing changed nothing about enforcement: each admission asks the live object again."""
	var guard: SeedGuard = SeedGuard.new()
	assert_true(_inv.set_seed_expiry_authority(guard).ok, "the guard binds")
	assert_true(_inv.has_seed_expiry_authority(), "and reports itself live")
	var refused: InventoryScript.OpResult = _inv.reserve_lot(_lot, 1000)
	assert_false(refused.ok, "an expired seed is refused a claim")
	assert_equal(refused.error, InventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "by name")
	assert_equal(_inv.lot_reserved_milli(_lot), 0, "and nothing was claimed")
	guard.refuses = false
	assert_true(_inv.reserve_lot(_lot, 1000).ok, "a usable seed is admitted")
	assert_equal(_inv.lot_reserved_milli(_lot), 1000, "and the claim really applied")
	assert_equal(guard.queries, 2, "no verdict was cached between the two admissions")


func test_a_live_binding_that_re_enters_the_store_is_still_refused() -> void:
	"""The predicate is a pure read. One that mutates is refused, not half-applied."""
	var guard: ReentrantGuard = ReentrantGuard.new()
	guard.inventory = _inv
	guard.target = _lot
	assert_true(_inv.set_seed_expiry_authority(guard).ok, "the guard binds")
	assert_true(_inv.reserve_lot(_lot, 1000).ok, "the honest verdict still admits the lot")
	assert_equal(guard.reentry_error, InventoryScript.REFUSE_ATTESTATION_REENTRY,
		"while its re-entrant mutation was refused inside the call")
	assert_equal(_inv.lot_quantity_milli(_lot), 4000, "so it removed nothing")


func test_clear_preserves_a_live_binding() -> void:
	"""`clear()` empties the store; the wiring is not state and survives it, exactly as before."""
	var guard: SeedGuard = SeedGuard.new()
	assert_true(_inv.set_seed_expiry_authority(guard).ok, "the guard binds")
	_inv.clear()
	assert_true(_inv.has_seed_expiry_authority(), "the binding survives the clear")
	_inv.register_item(ITEM_GRAIN, 250, CATEGORY_FOOD)
	var box: Vector2i = _inv.create_container(OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true).ref
	var lot: Vector2i = _inv.create_lot(box, ITEM_GRAIN, 1000, 0, 0, 0, 0, 0).ref
	var refused: InventoryScript.OpResult = _inv.reserve_lot(lot, 500)
	assert_false(refused.ok, "and is still enforced against a rebuilt store")
	assert_equal(refused.error, InventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "by name")
	assert_equal(guard.queries, 1, "having asked the same surviving object")


func test_an_explicit_unbind_enforces_nothing() -> void:
	"""Null is a deliberate wiring decision: with no authority this store cannot identify a seed,
	so it has no lots to refuse rather than every lot."""
	var guard: SeedGuard = SeedGuard.new()
	assert_true(_inv.set_seed_expiry_authority(guard).ok, "the guard binds")
	assert_true(_inv.set_seed_expiry_authority(null).ok, "and is explicitly unbound")
	assert_false(_inv.has_seed_expiry_authority(), "so nothing is bound")
	assert_true(_inv.reserve_lot(_lot, 1000).ok, "and no admission is refused for seed age")
	assert_equal(guard.queries, 0, "the unbound object is never asked")


func test_an_expired_binding_refuses_instead_of_admitting() -> void:
	"""FAIL CLOSED. A predicate that was bound and is now gone cannot answer, so nothing passes.

	The refusal carries the EXISTING INVALID_SEED_EXPIRY_AUTHORITY code -- not the shelf-life
	one, which would claim a verdict nobody gave -- and writes nothing.
	"""
	_bind_then_release_guard()
	assert_false(_inv.has_seed_expiry_authority(), "a released object is not a live authority")
	var before: PackedByteArray = _inv.state_bytes()
	var refused: InventoryScript.OpResult = _inv.reserve_lot(_lot, 1000)
	assert_false(refused.ok, "a consumer is refused rather than admitted")
	assert_equal(refused.error, InventoryScript.REFUSE_INVALID_SEED_EXPIRY_AUTHORITY,
		"with the authority code, not a shelf-life verdict")
	assert_equal(refused.value, 0, "the refusal carries no value")
	assert_equal(_inv.lot_reserved_milli(_lot), 0, "nothing was claimed")
	assert_true(_inv.state_bytes() == before, "and the store is byte identical")
	assert_true(_inv.release_all_reservations(_lot).ok,
		"while the store's own cleanup path is never blocked by the guard")


func test_an_expired_binding_is_distinguishable_from_an_explicit_unbind() -> void:
	"""The two states differ on every admission path, and the difference is observable."""
	_bind_then_release_guard()
	var before: PackedByteArray = _inv.state_bytes()
	assert_equal(_inv.sink_lot_quantity(_lot, 1000).error,
		InventoryScript.REFUSE_INVALID_SEED_EXPIRY_AUTHORITY, "a withdrawal refuses")
	assert_equal(_inv.split_lot(_lot, 1000).error,
		InventoryScript.REFUSE_INVALID_SEED_EXPIRY_AUTHORITY, "and so does seed selection")
	assert_true(_inv.state_bytes() == before, "neither refusal wrote a byte")
	assert_true(_inv.set_seed_expiry_authority(null).ok, "an explicit unbind clears the binding")
	assert_false(_inv.has_seed_expiry_authority(), "leaving nothing enforced")
	assert_true(_inv.sink_lot_quantity(_lot, 1000).ok, "after which the withdrawal is admitted")
	assert_equal(_inv.lot_quantity_milli(_lot), 3000, "and really did apply")


func test_rebinding_a_live_authority_restores_enforcement() -> void:
	"""An expired binding is not a latch: the owner may bind a fresh predicate over it."""
	_bind_then_release_guard()
	assert_equal(_inv.reserve_lot(_lot, 1000).error,
		InventoryScript.REFUSE_INVALID_SEED_EXPIRY_AUTHORITY, "the expired binding refuses")
	var fresh: SeedGuard = SeedGuard.new()
	fresh.refuses = false
	assert_true(_inv.set_seed_expiry_authority(fresh).ok, "a fresh predicate binds over it")
	assert_true(_inv.has_seed_expiry_authority(), "and is live")
	assert_true(_inv.reserve_lot(_lot, 1000).ok, "so its verdict decides the admission")
	assert_equal(fresh.queries, 1, "having actually been asked")
	assert_true(_inv.audit().ok, "and the store still satisfies every invariant")
