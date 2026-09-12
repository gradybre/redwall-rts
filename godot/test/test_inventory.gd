extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/inventory.gd` (task 2.5).
##
## Covers the three acceptance criteria of task 2.5 -- all-or-nothing under partial failure,
## conservation across arbitrary operation sequences, explicit capacity refusal, and per-lot
## `ceil_div` mass debits -- plus the reservation behavior that GDD §4.2 does specify
## (`reserved_milli <= quantity_milli` and exact cancellation). The Reservation row store is
## blocked by U4/U5 and is deliberately untested because it is deliberately unbuilt.
##
## Item masses under test are GDD §5.7 verbatim: raw food 250 g/U, prepared meals and rations
## 500 g/U, water 1000 g/U, wood 5000 g, stone 5000 g, iron 2000 g, rope 500 g, cloth 250 g,
## tool 1000 g.

const InventoryScript := preload("res://scripts/core/inventory.gd")
## Preloaded for the drift guard only: ARCH-STATE-004's 256 item keys are written down in
## both modules and nothing but that test keeps the two copies agreeing.
const CatalogScript := preload("res://scripts/core/catalog.gd")

const ITEM_GRAIN: int = 0
const ITEM_MEAL: int = 1
const ITEM_WATER: int = 2
const ITEM_WOOD: int = 3
const ITEM_STONE: int = 4
const ITEM_IRON: int = 5
const ITEM_ROPE: int = 6
const ITEM_CLOTH: int = 7
const ITEM_TOOL: int = 8

const CATEGORY_FOOD: int = 0
const CATEGORY_PREPARED: int = 1
const CATEGORY_WATER: int = 2
const CATEGORY_MATERIAL: int = 3
const CATEGORY_GEAR: int = 4

## GDD §5.7 tool mass, restated: "tool 1000g". Used by the equipped-lot suite below.
const TOOL_MASS: int = 1000

const BIG_MASS: int = 100000000
## Opaque catalog enum stand-ins. GDD §4.3 numbers neither provenance nor container policy, so
## these are arbitrary in-range int32 values chosen by this suite, NOT catalog IDs and NOT
## constants the module publishes; the module only ever compares these columns for equality.
const TEST_PROVENANCE: int = 3
const TEST_POLICY: int = 0
const INT64_MAX: int = 9223372036854775807
const OWNER_A: Vector2i = Vector2i(7, 1)
const OWNER_B: Vector2i = Vector2i(8, 1)

var _inv: InventoryScript = null
var _rng_state: int = 0
## Successful-operation census for the randomised sequence, so a run in which everything
## refused cannot pass the conservation check vacuously.
var _successes: Dictionary = {}


func before_each() -> void:
	"""Build a small inventory with the GDD §5.7 item masses registered."""
	_inv = _make_inventory(8, 64)
	_rng_state = 20260906


func _make_inventory(containers: int, lots: int) -> InventoryScript:
	"""Create an inventory of the given capacities with every test item registered."""
	var inv: InventoryScript = InventoryScript.new(containers, lots)
	inv.register_item(ITEM_GRAIN, 250, CATEGORY_FOOD)
	inv.register_item(ITEM_MEAL, 500, CATEGORY_PREPARED)
	inv.register_item(ITEM_WATER, 1000, CATEGORY_WATER)
	inv.register_item(ITEM_WOOD, 5000, CATEGORY_MATERIAL)
	inv.register_item(ITEM_STONE, 5000, CATEGORY_MATERIAL)
	inv.register_item(ITEM_IRON, 2000, CATEGORY_MATERIAL)
	inv.register_item(ITEM_ROPE, 500, CATEGORY_MATERIAL)
	inv.register_item(ITEM_CLOTH, 250, CATEGORY_MATERIAL)
	inv.register_item(ITEM_TOOL, 1000, CATEGORY_GEAR)
	return inv


func _container(max_mass_g: int = BIG_MASS, owner: Vector2i = OWNER_A) -> Vector2i:
	"""Create an accept-everything container and return its ref."""
	var result: InventoryScript.OpResult = _inv.create_container(owner, max_mass_g, InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true)
	return result.ref


func _lot(container: Vector2i, item_id: int, quantity_milli: int, quality: int = 0, provenance: int = TEST_PROVENANCE, recipe_id: int = 0, age: int = 0, remainder: int = 0) -> Vector2i:
	"""Create a lot in a container and return its ref."""
	var result: InventoryScript.OpResult = _inv.create_lot(container, item_id, quantity_milli, quality, provenance, recipe_id, age, remainder)
	return result.ref


func _next_random(bound: int) -> int:
	"""Deterministic LCG draw in [0, bound). Same seed always replays the same sequence."""
	_rng_state = (_rng_state * 1103515245 + 12345) & 0x3FFFFFFF
	return (_rng_state >> 8) % bound


# --- Item registry -------------------------------------------------------------------------

func test_item_masses_match_gdd_5_7() -> void:
	"""Registered unit masses reproduce GDD §5.7 exactly."""
	assert_equal(_inv.item_mass_g(ITEM_GRAIN), 250, "raw food is 250 g/U")
	assert_equal(_inv.item_mass_g(ITEM_MEAL), 500, "prepared meals and rations are 500 g/U")
	assert_equal(_inv.item_mass_g(ITEM_WATER), 1000, "water is 1000 g/U")
	assert_equal(_inv.item_mass_g(ITEM_WOOD), 5000, "wood is 5000 g")
	assert_equal(_inv.item_mass_g(ITEM_STONE), 5000, "stone is 5000 g")
	assert_equal(_inv.item_mass_g(ITEM_IRON), 2000, "iron is 2000 g")
	assert_equal(_inv.item_mass_g(ITEM_ROPE), 500, "rope is 500 g")
	assert_equal(_inv.item_mass_g(ITEM_CLOTH), 250, "cloth is 250 g")
	assert_equal(_inv.item_mass_g(ITEM_TOOL), 1000, "tool is 1000 g")


func test_item_id_space_does_not_drift_from_the_catalog() -> void:
	"""DRIFT GUARD. ARCH-STATE-004 caps the compiled ItemDefinition domain at 256 keys, and
	that 256 is written down twice: `catalog.gd`'s ITEM_DEFINITION_MAX_KEYS, which refuses a
	larger domain, and this module's ITEM_CAPACITY, which sizes the mass, category and
	conservation-ledger columns an item id indexes. If the catalog ever compiled more keys
	than the inventory has columns for, every id past the smaller bound would be refused as
	INVALID_ITEM_ID with a perfectly valid catalog entry behind it. Nothing enforces the
	agreement, so this test does; giving one module ownership of the number is a cross-module
	refactor this suite deliberately does not perform.
	"""
	assert_equal(InventoryScript.ITEM_CAPACITY, CatalogScript.ITEM_DEFINITION_MAX_KEYS, "item id space agrees with the catalog")
	assert_equal(InventoryScript.ITEM_CAPACITY, 256, "ARCH-STATE-004's compiled key cap")
	assert_false(_inv.is_item_registered(InventoryScript.ITEM_CAPACITY), "the id one past the cap is not registrable")
	var refused: InventoryScript.OpResult = _inv.register_item(InventoryScript.ITEM_CAPACITY, 250, CATEGORY_FOOD)
	assert_false(refused.ok, "registering past the cap refuses")
	assert_equal(refused.error, InventoryScript.REFUSE_INVALID_ITEM_ID, "the refusal names the id")
	assert_true(_inv.register_item(InventoryScript.ITEM_CAPACITY - 1, 250, CATEGORY_FOOD).ok, "the last id in range registers")


func test_unregistered_item_is_refused() -> void:
	"""Creating a lot of an item with no compiled mass refuses instead of assuming one."""
	var container: Vector2i = _container()
	var result: InventoryScript.OpResult = _inv.create_lot(container, 99, 1000, 0, 0, 0, 0, 0)
	assert_false(result.ok, "unknown item refuses")
	assert_equal(result.error, InventoryScript.REFUSE_UNKNOWN_ITEM, "refusal names the unknown item")


# --- Per-lot mass rounding -----------------------------------------------------------------

func test_capacity_debit_uses_per_lot_ceiling() -> void:
	"""A lot's charged mass is ceil_div(quantity_milli*mass_g, 1000), not a truncation."""
	var container: Vector2i = _container()
	_lot(container, ITEM_GRAIN, 4)
	assert_equal(_inv.container_used_mass_g(container), 1, "4 milli-U of 250 g food charges ceil(1000/1000)=1 g")
	_lot(container, ITEM_GRAIN, 1)
	assert_equal(_inv.container_used_mass_g(container), 2, "1 milli-U charges a whole gram, not 0")


func test_per_lot_rounding_differs_from_summed_total_rounding() -> void:
	"""Splitting charges each child on its own, which a summed-total ceiling would not.

	One 4 milli-U lot of 250 g/U raw food charges ceil(4*250/1000) = 1 g. Split into 1 and 3
	it charges ceil(250/1000) + ceil(750/1000) = 1 + 1 = 2 g. A ceiling taken once on the
	summed total 4*250 = 1000 would still say 1 g, so 2 g proves the per-lot rule is in force
	and that splitting cannot manufacture free capacity (BAL-NUM-001, BAL-SAFE-016).
	"""
	var split_container: Vector2i = _container()
	var parent: Vector2i = _lot(split_container, ITEM_GRAIN, 4)
	var parent_debit: int = _inv.container_used_mass_g(split_container)
	var child: InventoryScript.OpResult = _inv.split_lot(parent, 1)
	assert_true(child.ok, "split of unreserved quantity succeeds")
	var split_debit: int = _inv.container_used_mass_g(split_container)
	# The comparison charge is the module's own, for the same 4 milli-U held as one lot --
	# not a number this test computed, which would hold whatever the module did.
	var whole_container: Vector2i = _container(BIG_MASS, OWNER_B)
	_lot(whole_container, ITEM_GRAIN, 4)
	var summed_total_debit: int = _inv.container_used_mass_g(whole_container)
	assert_equal(summed_total_debit, 1, "the same quantity held whole charges one ceiling: 1 g")
	assert_equal(split_debit, 2, "per-lot ceiling charges 1 g + 1 g")
	assert_true(split_debit > summed_total_debit, "per-lot rounding charges strictly more than summed-total rounding")
	assert_equal(parent_debit, summed_total_debit, "the parent charged the whole-lot debit before the split")
	assert_equal(_inv.lot_quantity_milli(parent) + _inv.lot_quantity_milli(child.ref), 4, "split conserves quantity exactly")


func test_merge_recovers_rounding_slack_without_changing_quantity() -> void:
	"""Merging may recover the per-lot rounding slack but never alters quantity (BAL-SAFE-016)."""
	var container: Vector2i = _container()
	var first: Vector2i = _lot(container, ITEM_GRAIN, 1)
	var second: Vector2i = _lot(container, ITEM_GRAIN, 1)
	assert_equal(_inv.container_used_mass_g(container), 2, "two 1 milli-U lots charge 1 g each")
	var merged: InventoryScript.OpResult = _inv.merge_lots(first, second)
	assert_true(merged.ok, "identical-attribute merge succeeds")
	assert_equal(_inv.container_used_mass_g(container), 1, "merged 2 milli-U charges ceil(500/1000)=1 g")
	assert_equal(_inv.lot_quantity_milli(first), 2, "merge conserves quantity")
	assert_false(_inv.is_lot_valid(second), "the merged-away row is retired")


# --- Explicit capacity refusal ----------------------------------------------------------------

func test_capacity_refusal_is_explicit_and_changes_nothing() -> void:
	"""An over-capacity create refuses by name and leaves the container untouched."""
	var container: Vector2i = _container(4999)
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0)
	assert_false(result.ok, "5000 g of wood does not fit in 4999 g")
	assert_equal(result.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is named, not a clamp")
	assert_equal(_inv.container_lot_count(container), 0, "no partial lot was placed")
	assert_equal(_inv.container_used_mass_g(container), 0, "no mass was charged")
	assert_true(_inv.state_bytes() == before, "a refused create leaves state byte-identical")


func test_capacity_is_never_silently_clamped() -> void:
	"""A quantity that does not fit is refused whole; no reduced amount is placed instead."""
	var container: Vector2i = _container(5000)
	var first: InventoryScript.OpResult = _inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0)
	assert_true(first.ok, "the first 5000 g fills the container exactly")
	var second: InventoryScript.OpResult = _inv.create_lot(container, ITEM_GRAIN, 1, 0, 0, 0, 0, 0)
	assert_false(second.ok, "one more gram does not fit")
	assert_equal(_inv.container_used_mass_g(container), 5000, "the container holds exactly what fit")


func test_split_refused_when_per_lot_ceiling_would_exceed_capacity() -> void:
	"""A split whose extra rounded gram exceeds the container refuses rather than overfilling."""
	var container: Vector2i = _container(1)
	var parent: Vector2i = _lot(container, ITEM_GRAIN, 4)
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.split_lot(parent, 1)
	assert_false(result.ok, "the split would charge 2 g against a 1 g container")
	assert_equal(result.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is explicit")
	assert_true(_inv.state_bytes() == before, "the refused split changed nothing")


func test_reserved_container_mass_counts_against_capacity() -> void:
	"""BAL-SAFE-002 charges sum(per-lot ceil) + reserved_mass against max_mass."""
	var container: Vector2i = _container(5000)
	assert_true(_inv.reserve_container_mass(container, 4000).ok, "committing output headroom succeeds")
	var blocked: InventoryScript.OpResult = _inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0)
	assert_false(blocked.ok, "committed headroom blocks incoming mass")
	assert_equal(blocked.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is explicit")
	assert_true(_inv.release_container_mass(container, 4000).ok, "releasing the commitment succeeds")
	assert_true(_inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0).ok, "the mass fits once released")


func test_lot_row_capacity_refusal_is_explicit() -> void:
	"""Exhausting the lot store refuses by name instead of dropping a lot silently."""
	_inv = _make_inventory(4, 3)
	var container: Vector2i = _container()
	for i: int in range(3):
		assert_true(_inv.create_lot(container, ITEM_GRAIN, 1000, i, 0, 0, 0, 0).ok, "lot %d fits the store" % i)
	var overflow: InventoryScript.OpResult = _inv.create_lot(container, ITEM_GRAIN, 1000, 9, 0, 0, 0, 0)
	assert_false(overflow.ok, "the fourth lot exceeds a 3-row store")
	assert_equal(overflow.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_LOT, "refusal names the lot store")


func test_container_row_capacity_refusal_is_explicit() -> void:
	"""Exhausting the container store refuses by name."""
	_inv = _make_inventory(2, 8)
	assert_true(_inv.create_container(OWNER_A, BIG_MASS, -1, 0, true).ok, "container 1 fits")
	assert_true(_inv.create_container(OWNER_A, BIG_MASS, -1, 0, true).ok, "container 2 fits")
	var overflow: InventoryScript.OpResult = _inv.create_container(OWNER_A, BIG_MASS, -1, 0, true)
	assert_false(overflow.ok, "the third container exceeds a 2-row store")
	assert_equal(overflow.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_CONTAINER, "refusal names the container store")


func test_filters_refuse_a_disallowed_category() -> void:
	"""A container admits only the categories in its 64-bit filter mask (ARCH-STATE-004)."""
	var result: InventoryScript.OpResult = _inv.create_container(OWNER_A, BIG_MASS, _inv.category_mask(CATEGORY_FOOD), 0, true)
	var pantry: Vector2i = result.ref
	assert_true(_inv.create_lot(pantry, ITEM_GRAIN, 1000, 0, 0, 0, 0, 0).ok, "food is admitted")
	var refused: InventoryScript.OpResult = _inv.create_lot(pantry, ITEM_WOOD, 1000, 0, 0, 0, 0, 0)
	assert_false(refused.ok, "a material is not admitted")
	assert_equal(refused.error, InventoryScript.REFUSE_ITEM_FILTERED, "refusal names the filter")


# --- Split and merge attribute rules -----------------------------------------------------------

func test_merge_refuses_each_differing_attribute() -> void:
	"""GDD §4.2 and BAL-SAFE-003: merge only on identical item, quality, provenance, recipe."""
	var container: Vector2i = _container()
	var base: Vector2i = _lot(container, ITEM_GRAIN, 1000, 1, 5, 3, 0, 0)
	_assert_merge_refused(base, _lot(container, ITEM_CLOTH, 1000, 1, 5, 3, 0, 0), InventoryScript.REFUSE_ATTRIBUTE_MISMATCH, "item")
	_assert_merge_refused(base, _lot(container, ITEM_GRAIN, 1000, 2, 5, 3, 0, 0), InventoryScript.REFUSE_ATTRIBUTE_MISMATCH, "quality")
	_assert_merge_refused(base, _lot(container, ITEM_GRAIN, 1000, 1, 6, 3, 0, 0), InventoryScript.REFUSE_ATTRIBUTE_MISMATCH, "provenance")
	_assert_merge_refused(base, _lot(container, ITEM_GRAIN, 1000, 1, 5, 4, 0, 0), InventoryScript.REFUSE_ATTRIBUTE_MISMATCH, "recipe")
	_assert_merge_refused(base, _lot(container, ITEM_GRAIN, 1000, 1, 5, 3, 1500, 0), InventoryScript.REFUSE_AGE_MISMATCH, "rounded age")


func _assert_merge_refused(dest: Vector2i, source: Vector2i, code: StringName, attribute: String) -> void:
	"""Assert that merging two lots differing in one attribute refuses with the given code."""
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.merge_lots(dest, source)
	assert_false(result.ok, "merge refuses on differing %s" % attribute)
	assert_equal(result.error, code, "refusal names the mismatch for %s" % attribute)
	assert_true(_inv.state_bytes() == before, "the refused merge on %s changed nothing" % attribute)


func test_merge_refuses_across_containers() -> void:
	"""Merging is an in-container operation; crossing containers is a transfer, not a merge."""
	var first: Vector2i = _container()
	var second: Vector2i = _container(BIG_MASS, OWNER_B)
	var a: Vector2i = _lot(first, ITEM_GRAIN, 1000)
	var b: Vector2i = _lot(second, ITEM_GRAIN, 1000)
	var result: InventoryScript.OpResult = _inv.merge_lots(a, b)
	assert_false(result.ok, "a cross-container merge refuses")
	assert_equal(result.error, InventoryScript.REFUSE_DIFFERENT_CONTAINER, "refusal names the container mismatch")


func test_merge_adopts_the_older_rounded_age() -> void:
	"""BAL-SAFE-003: merged age is the shared rounded age; the remainder is the older lot's."""
	var container: Vector2i = _container()
	var younger: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, TEST_PROVENANCE, 0, 1500, 7)
	var older: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, TEST_PROVENANCE, 0, 1900, 3)
	assert_true(_inv.merge_lots(younger, older).ok, "equal rounded ages merge")
	assert_equal(_inv.lot_age_milli_hours(younger), 2000, "merged age is the shared rounded hour")
	assert_equal(_inv.lot_age_remainder(younger), 3, "remainder comes from the older lot, never the younger")


func test_split_refuses_degenerate_quantities() -> void:
	"""A split of zero or of the whole lot is refused; it would create or destroy a row for free."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	assert_equal(_inv.split_lot(lot, 0).error, InventoryScript.REFUSE_INVALID_QUANTITY, "zero split refuses")
	assert_equal(_inv.split_lot(lot, 1000).error, InventoryScript.REFUSE_INVALID_QUANTITY, "whole-lot split refuses")
	assert_equal(_inv.split_lot(lot, 1001).error, InventoryScript.REFUSE_INVALID_QUANTITY, "oversized split refuses")


func test_split_preserves_every_attribute() -> void:
	"""The child of a split carries the parent's item, quality, provenance, recipe and age."""
	var container: Vector2i = _container()
	var parent: Vector2i = _lot(container, ITEM_MEAL, 4000, 2, 5, 11, 2500, 9)
	var child: InventoryScript.OpResult = _inv.split_lot(parent, 1000)
	assert_true(child.ok, "the split succeeds")
	assert_equal(_inv.lot_item_id(child.ref), ITEM_MEAL, "item carries over")
	assert_equal(_inv.lot_quality(child.ref), 2, "quality carries over")
	assert_equal(_inv.lot_provenance(child.ref), 5, "provenance carries over")
	assert_equal(_inv.lot_recipe_id(child.ref), 11, "recipe carries over")
	assert_equal(_inv.lot_age_milli_hours(child.ref), 2500, "age is not reset by a split")
	assert_equal(_inv.lot_age_remainder(child.ref), 9, "the aging remainder is not reset by a split")


# --- Moves and transfers -----------------------------------------------------------------------

func test_transfer_conserves_quantity_between_containers() -> void:
	"""A transfer debits the source and credits the destination by exactly the same amount."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var result: InventoryScript.OpResult = _inv.transfer(lot, dest, 1500)
	assert_true(result.ok, "the transfer succeeds")
	assert_equal(_inv.lot_quantity_milli(lot), 2500, "the source keeps the remainder")
	assert_equal(_inv.lot_quantity_milli(result.ref), 1500, "the destination receives exactly the amount")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 4000, "total quantity is unchanged")
	assert_true(_inv.audit().ok, "every invariant still holds")


func test_transfer_merges_into_a_compatible_destination_lot() -> void:
	"""Arriving quantity folds into an identical-attribute lot rather than cloning a row."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var sibling: Vector2i = _lot(dest, ITEM_GRAIN, 1000)
	var result: InventoryScript.OpResult = _inv.transfer(lot, dest, 1000)
	assert_true(result.ok, "the transfer succeeds")
	assert_equal(_inv.container_lot_count(dest), 1, "no second row is created in the destination")
	assert_equal(_inv.lot_quantity_milli(sibling), 2000, "the destination lot absorbed the arrival")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 5000, "total quantity is unchanged")


func test_whole_lot_transfer_retires_the_source_row() -> void:
	"""Transferring everything empties the source lot, whose row is retired rather than kept."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var result: InventoryScript.OpResult = _inv.transfer(lot, dest, 4000)
	assert_true(result.ok, "the whole-lot transfer succeeds")
	assert_false(_inv.is_lot_valid(lot), "the emptied source row is retired, voiding its ref")
	assert_equal(_inv.container_lot_count(source), 0, "the source container is empty")
	assert_equal(_inv.container_used_mass_g(source), 0, "the source is charged nothing")
	assert_equal(_inv.lot_quantity_milli(result.ref), 4000, "the destination holds the whole quantity")


func test_transfer_refuses_an_over_capacity_destination() -> void:
	"""A destination that cannot take the mass refuses; the source is not debited."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(2000, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_WOOD, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.transfer(lot, dest, 1000)
	assert_false(result.ok, "5000 g does not fit a 2000 g destination")
	assert_equal(result.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is explicit")
	assert_true(_inv.state_bytes() == before, "the refused transfer left both containers untouched")


func test_move_lot_carries_its_reservation() -> void:
	"""A whole-lot move keeps the lot's identity, so its claims stay attached (GDD §5.8)."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	assert_true(_inv.reserve_lot(lot, 1500).ok, "the claim is accepted")
	assert_true(_inv.move_lot(lot, dest).ok, "the move succeeds")
	assert_equal(_inv.lot_container(lot), dest, "the lot now sits in the destination")
	assert_equal(_inv.lot_reserved_milli(lot), 1500, "the claim moved with the lot")
	assert_equal(_inv.container_used_mass_g(source), 0, "the source was debited")
	assert_equal(_inv.container_used_mass_g(dest), 1000, "the destination was credited the same mass")


# --- Reservations (the specified part; see U4/U5) ------------------------------------------------

func test_reserved_never_exceeds_quantity() -> void:
	"""GDD §4.2's per-lot bound is enforced by refusal, not by clamping the claim down."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	assert_true(_inv.reserve_lot(lot, 600).ok, "a claim within the quantity is accepted")
	var over: InventoryScript.OpResult = _inv.reserve_lot(lot, 500)
	assert_false(over.ok, "a claim past the quantity refuses")
	assert_equal(over.error, InventoryScript.REFUSE_RESERVED_EXCEEDS_QUANTITY, "refusal is explicit")
	assert_equal(_inv.lot_reserved_milli(lot), 600, "the refused claim did not partially apply")
	assert_true(_inv.lot_reserved_milli(lot) <= _inv.lot_quantity_milli(lot), "reserved <= quantity holds")
	assert_true(_inv.audit().ok, "the audit confirms the bound across every lot")


func test_reservation_cancellation_restores_available_exactly() -> void:
	"""Releasing a claim returns exactly the amount it withheld -- no more and no less."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	assert_equal(_inv.lot_available_milli(lot), 4000, "an unclaimed lot is fully available")
	assert_true(_inv.reserve_lot(lot, 2500).ok, "the claim is accepted")
	assert_equal(_inv.lot_available_milli(lot), 1500, "the claim withholds exactly 2500")
	assert_true(_inv.release_reservation(lot, 1000).ok, "a partial release is accepted")
	assert_equal(_inv.lot_available_milli(lot), 2500, "the partial release returns exactly 1000")
	assert_true(_inv.release_all_reservations(lot).ok, "cancelling the rest is accepted")
	assert_equal(_inv.lot_available_milli(lot), 4000, "cancellation restores the original available amount")
	assert_equal(_inv.lot_quantity_milli(lot), 4000, "cancellation never changes the quantity itself")


func test_reserved_quantity_cannot_be_transferred_away() -> void:
	"""Only unreserved quantity may be split off, so a claim cannot be stolen by a haul."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 1000)
	assert_true(_inv.reserve_lot(lot, 600).ok, "the claim is accepted")
	var too_much: InventoryScript.OpResult = _inv.transfer(lot, dest, 500)
	assert_false(too_much.ok, "500 exceeds the 400 unreserved")
	assert_equal(too_much.error, InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED, "refusal is explicit")
	assert_true(_inv.transfer(lot, dest, 400).ok, "the unreserved remainder transfers")
	assert_equal(_inv.lot_reserved_milli(lot), 600, "the claim survives the transfer intact")


func test_consume_reserved_reduces_claim_and_quantity_together() -> void:
	"""Consuming through a claim lowers reserved and quantity by the same amount."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	assert_true(_inv.reserve_lot(lot, 2400).ok, "the claim is accepted")
	assert_true(_inv.consume_reserved(lot, 1000).ok, "the consumption is accepted")
	assert_equal(_inv.lot_quantity_milli(lot), 3000, "quantity fell by the consumed amount")
	assert_equal(_inv.lot_reserved_milli(lot), 1400, "the claim fell by the same amount")
	assert_equal(_inv.total_sunk_milli(ITEM_GRAIN), 1000, "the consumption is counted as a sink")
	assert_true(_inv.audit().ok, "conservation still holds after a sink")


func test_sink_refuses_to_consume_claimed_quantity() -> void:
	"""An unclaimed sink cannot eat into another owner's reservation."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	assert_true(_inv.reserve_lot(lot, 900).ok, "the claim is accepted")
	var result: InventoryScript.OpResult = _inv.sink_lot_quantity(lot, 200)
	assert_false(result.ok, "200 exceeds the 100 unreserved")
	assert_equal(result.error, InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED, "refusal is explicit")


# --- All-or-nothing --------------------------------------------------------------------------

func test_failed_single_operation_leaves_state_byte_identical() -> void:
	"""A refusal from one operation writes nothing at all, not even an allocated row."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(1, OWNER_B)
	_lot(source, ITEM_GRAIN, 4000)
	var lot: Vector2i = _inv.container_first_lot(source)
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.transfer(lot, dest, 1000)
	assert_false(result.ok, "the transfer cannot fit the destination")
	assert_true(_inv.state_bytes() == before, "state is byte-identical after the refusal")
	assert_false(_inv.is_transaction_open(), "the implicit transaction closed itself")


func test_all_or_nothing_under_mid_sequence_failure() -> void:
	"""A multi-step transaction that fails at step three restores every earlier step exactly.

	This is the central invariant of task 2.5: the first two operations really did apply, the
	third refuses, and commit() reports that first refusal after rolling the whole sequence
	back to the byte image taken before begin().
	"""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_true(_inv.transfer(lot, dest, 1000).ok, "step 1 applies")
	assert_true(_inv.split_lot(lot, 500).ok, "step 2 applies")
	var failure: InventoryScript.OpResult = _inv.reserve_lot(lot, 999999)
	assert_false(failure.ok, "step 3 refuses")
	assert_true(_inv.is_transaction_poisoned(), "the refusal poisoned the transaction")
	var commit: InventoryScript.OpResult = _inv.commit()
	assert_false(commit.ok, "commit refuses a poisoned transaction")
	assert_equal(commit.error, InventoryScript.REFUSE_RESERVED_EXCEEDS_QUANTITY, "commit reports the first refusal")
	assert_true(_inv.state_bytes() == before, "state is byte-identical to before begin()")


func test_operations_after_a_poisoned_step_refuse_without_writing() -> void:
	"""Once poisoned, later operations refuse immediately instead of building on bad state."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_false(_inv.reserve_lot(lot, 999999).ok, "the first step refuses")
	var later: InventoryScript.OpResult = _inv.split_lot(lot, 1000)
	assert_false(later.ok, "the later step refuses too")
	assert_equal(later.error, InventoryScript.REFUSE_TRANSACTION_POISONED, "refusal names the poisoned transaction")
	assert_false(_inv.commit().ok, "commit refuses")
	assert_true(_inv.state_bytes() == before, "nothing was written by either step")


func test_committed_transaction_is_durable() -> void:
	"""A clean commit keeps every step; only a poisoned or aborted transaction rolls back."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_true(_inv.transfer(lot, dest, 1000).ok, "step 1 applies")
	assert_true(_inv.split_lot(lot, 500).ok, "step 2 applies")
	assert_true(_inv.commit().ok, "the clean commit succeeds")
	assert_equal(_inv.container_lot_count(source), 2, "the split survived the commit")
	assert_equal(_inv.container_lot_count(dest), 1, "the transfer survived the commit")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 4000, "quantity is conserved across the commit")


func test_abort_restores_state_exactly() -> void:
	"""abort() discards an open transaction whether or not anything refused."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_true(_inv.transfer(lot, dest, 1000).ok, "a successful step applies")
	assert_true(_inv.create_lot(dest, ITEM_WOOD, 2000, 0, 0, 0, 0, 0).ok, "another successful step applies")
	assert_true(_inv.state_bytes() != before, "the steps really did change state")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "abort restored the pre-transaction bytes exactly")
	assert_false(_inv.is_transaction_open(), "the transaction closed")


func test_nested_begin_is_refused() -> void:
	"""Nesting is refused rather than silently joined, so commit boundaries stay unambiguous."""
	assert_true(_inv.begin().ok, "the first begin opens")
	var nested: InventoryScript.OpResult = _inv.begin()
	assert_false(nested.ok, "the second begin refuses")
	assert_equal(nested.error, InventoryScript.REFUSE_NESTED_TRANSACTION, "refusal is explicit")
	_inv.abort()
	assert_false(_inv.commit().ok, "committing with no open transaction refuses")


func test_journal_exhaustion_refuses_and_rolls_back() -> void:
	"""A transaction too large for the fixed undo arena refuses; it never half-applies."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	var code: StringName = InventoryScript.REFUSE_NONE
	for i: int in range(6000):
		var step: InventoryScript.OpResult = _inv.reserve_lot(lot, 1) if i % 2 == 0 else _inv.release_reservation(lot, 1)
		if not step.ok:
			code = step.error
			break
	assert_equal(code, InventoryScript.REFUSE_JOURNAL_FULL, "the oversized transaction refuses by name")
	assert_false(_inv.commit().ok, "commit refuses the poisoned transaction")
	assert_true(_inv.state_bytes() == before, "the oversized transaction rolled back completely")


func test_poisoning_does_not_outlive_the_transaction_that_caused_it() -> void:
	"""is_transaction_poisoned() describes the OPEN transaction, so a closed one reports false.

	The flag self-heals at the next begin(), which makes a stale `true` cosmetic rather than
	dangerous -- but it is a public predicate, and between the close and the next begin it
	answered a question about a transaction that no longer existed.
	"""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_false(_inv.reserve_lot(lot, 999999).ok, "a step refuses")
	assert_true(_inv.is_transaction_poisoned(), "the open transaction reports itself poisoned")
	assert_false(_inv.commit().ok, "commit reports the refusal")
	assert_false(_inv.is_transaction_open(), "the transaction closed")
	assert_false(_inv.is_transaction_poisoned(), "no open transaction, so nothing is poisoned")
	assert_true(_inv.begin().ok, "a second transaction opens")
	assert_false(_inv.reserve_lot(lot, 999999).ok, "a step refuses again")
	_inv.abort()
	assert_false(_inv.is_transaction_poisoned(), "abort clears the poison too")
	assert_false(_inv.sink_lot_quantity(lot, -1).ok, "an implicit operation refuses")
	assert_false(_inv.is_transaction_poisoned(), "an implicit operation leaves no poison behind")
	assert_true(_inv.reserve_lot(lot, 1000).ok, "a valid operation still applies afterwards")


func test_refusal_names_the_cause_that_actually_blocked_the_operation() -> void:
	"""A claim far past the lot must report the claim, not a wrapped sum's phantom shortfall.

	Deciding on `held + delta` means a delta near INT64_MAX wraps the sum negative, and a
	negative sum reads as "released more than was held" -- the opposite of what the caller
	asked for. Both bounds are therefore tested against the delta itself.
	"""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 4000)
	assert_true(_inv.reserve_lot(lot, 1000).ok, "a modest claim applies")
	var wrapped: InventoryScript.OpResult = _inv.reserve_lot(lot, INT64_MAX)
	assert_false(wrapped.ok, "a claim past the lot refuses")
	assert_equal(wrapped.error, InventoryScript.REFUSE_RESERVED_EXCEEDS_QUANTITY, "the refusal names the claim, not a shortfall")
	var shortfall: InventoryScript.OpResult = _inv.release_reservation(lot, 2000)
	assert_false(shortfall.ok, "releasing more than is held refuses")
	assert_equal(shortfall.error, InventoryScript.REFUSE_INSUFFICIENT_RESERVED, "and that one really is a shortfall")
	assert_equal(_inv.lot_reserved_milli(lot), 1000, "neither refusal moved the claim")


func test_container_mass_refusals_name_capacity_and_shortfall_separately() -> void:
	"""INVALID_MASS means a zero delta only; the other two causes have their own codes."""
	var container: Vector2i = _container(5000)
	assert_true(_inv.reserve_container_mass(container, 1000).ok, "a commitment that fits applies")
	var over: InventoryScript.OpResult = _inv.reserve_container_mass(container, 9000)
	assert_false(over.ok, "a commitment past the container refuses")
	assert_equal(over.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "over capacity is named as capacity")
	var under: InventoryScript.OpResult = _inv.release_container_mass(container, 4000)
	assert_false(under.ok, "releasing more than is committed refuses")
	assert_equal(under.error, InventoryScript.REFUSE_INSUFFICIENT_RESERVED, "under-release is named as a shortfall")
	assert_equal(_inv.container_reserved_mass_g(container), 1000, "neither refusal moved the commitment")
	var zero: InventoryScript.OpResult = _inv.reserve_container_mass(container, 0)
	assert_false(zero.ok, "a zero commitment refuses")
	assert_equal(zero.error, InventoryScript.REFUSE_INVALID_MASS, "a zero delta is what INVALID_MASS now means")


# --- Stale refs -------------------------------------------------------------------------------

func test_clear_does_not_let_a_pre_clear_ref_alias_a_rebuilt_row() -> void:
	"""Refs taken before clear() must stay dead once the same slots are handed out again.

	Emptying the store is not rewinding it. With both generation columns refilled with 1, the
	first lot and container created after a clear are issued the identical `(slot, generation)`
	pairs the caller was holding beforehand, and a stale ref then reads a quantity, charges
	mass against, and retires a row it has nothing to do with.
	"""
	var stale_container: Vector2i = _container()
	var stale_lot: Vector2i = _lot(stale_container, ITEM_GRAIN, 4000)
	_inv.clear()
	_inv.register_item(ITEM_WOOD, 5000, CATEGORY_MATERIAL)
	var rebuilt_container: Vector2i = _container()
	var rebuilt_lot: Vector2i = _lot(rebuilt_container, ITEM_WOOD, 2000)
	assert_equal(rebuilt_container.x, stale_container.x, "the container slot is handed back")
	assert_equal(rebuilt_lot.x, stale_lot.x, "the lot slot is handed back")
	assert_true(rebuilt_container.y > stale_container.y, "the container generation moved forward")
	assert_true(rebuilt_lot.y > stale_lot.y, "the lot generation moved forward")
	assert_false(_inv.is_container_valid(stale_container), "the pre-clear container ref does not validate")
	assert_false(_inv.is_lot_valid(stale_lot), "the pre-clear lot ref does not validate")
	assert_equal(_inv.lot_quantity_milli(stale_lot), 0, "it cannot read the rebuilt lot's quantity")
	assert_false(_inv.sink_lot_quantity(stale_lot, 1000).ok, "and it cannot consume from it")
	assert_equal(_inv.lot_quantity_milli(rebuilt_lot), 2000, "the rebuilt lot is untouched")


func test_stale_lot_ref_is_rejected_after_retirement() -> void:
	"""A ref to a retired lot never validates again, even once its slot is reused."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	assert_true(_inv.sink_lot_quantity(lot, 1000).ok, "consuming the lot to zero retires it")
	assert_false(_inv.is_lot_valid(lot), "the stale ref is rejected")
	var reused: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	assert_equal(reused.x, lot.x, "the slot is reused")
	assert_true(reused.y != lot.y, "the generation advanced, so the stale ref stays invalid")
	assert_false(_inv.is_lot_valid(lot), "the stale ref is still rejected after slot reuse")
	assert_false(_inv.split_lot(lot, 100).ok, "operations on a stale ref refuse")


func test_destroy_container_refuses_while_it_holds_lots() -> void:
	"""A container holding lots cannot be retired; that would delete resources silently."""
	var container: Vector2i = _container()
	var lot: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	var refused: InventoryScript.OpResult = _inv.destroy_container(container)
	assert_false(refused.ok, "a non-empty container refuses destruction")
	assert_equal(refused.error, InventoryScript.REFUSE_CONTAINER_NOT_EMPTY, "refusal is explicit")
	assert_true(_inv.sink_lot_quantity(lot, 1000).ok, "emptying the container succeeds")
	assert_true(_inv.destroy_container(container).ok, "the empty container is retired")
	assert_false(_inv.is_container_valid(container), "the stale container ref is rejected")


# --- Conservation over a long randomised sequence ------------------------------------------------

func test_conservation_across_long_deterministic_random_sequence() -> void:
	"""Quantity is conserved across 600 pseudo-random moves, splits, merges, sinks and claims.

	The sequence is randomised in shape but deterministic in replay: one seeded LCG drives it,
	so a failure reproduces exactly. Totals are tracked independently of the module's own
	ledger -- the test sums the live lots by walking the public container iteration -- so the
	check cannot pass merely because a running total agrees with itself.
	"""
	var containers: Array[Vector2i] = _build_random_world()
	var sourced: int = 0
	var sunk: int = 0
	var failure: String = ""
	for step: int in range(600):
		var delta: Vector2i = _random_step(containers)
		sourced += delta.x
		sunk += delta.y
		if not _inv.audit().ok:
			failure = "audit failed at step %d with %s" % [step, _inv.audit().error]
			break
	assert_equal(failure, "", "every intermediate state satisfies every invariant")
	for family: String in ["create", "split", "merge", "transfer", "sink", "reserve"]:
		assert_true(int(_successes.get(family, 0)) > 0, "the sequence performed at least one successful %s" % family)
	assert_equal(_walk_live_total(containers), sourced - sunk, "live quantity equals sources minus sinks")


func _build_random_world() -> Array[Vector2i]:
	"""Create the four containers the randomised sequence operates on.

	The lot store is roomy relative to the step count so the sequence is not dominated by
	capacity refusals, and generated lots draw from a narrow attribute space so that merges
	genuinely find compatible partners. Refusals still occur in quantity; they simply are not
	the only thing being measured.
	"""
	_inv = _make_inventory(4, 256)
	_successes = {}
	var containers: Array[Vector2i] = []
	for i: int in range(4):
		containers.append(_container(2000000, Vector2i(i, 1)))
	return containers


func _tally(family: String, ok: bool) -> bool:
	"""Record whether one operation of a family succeeded, and pass the flag back through."""
	if ok:
		_successes[family] = int(_successes.get(family, 0)) + 1
	return ok


func _random_step(containers: Array[Vector2i]) -> Vector2i:
	"""Perform one pseudo-random operation. Returns (sourced_milli, sunk_milli) for that step."""
	var lots: Array[Vector2i] = _collect_lots(containers)
	var choice: int = _next_random(7)
	if choice == 0 or lots.is_empty():
		return _random_create(containers)
	var lot: Vector2i = lots[_next_random(lots.size())]
	match choice:
		1:
			_random_transfer(containers, lot)
		2:
			_tally("split", _inv.split_lot(lot, 1 + _next_random(maxi(1, _inv.lot_available_milli(lot)))).ok)
		3:
			_random_merge(lot)
		4:
			return _random_sink(lot)
		5:
			_tally("reserve", _inv.reserve_lot(lot, 1 + _next_random(maxi(1, _inv.lot_available_milli(lot)))).ok)
		6:
			_random_release(lot)
	return Vector2i.ZERO


func _random_create(containers: Array[Vector2i]) -> Vector2i:
	"""Create one randomised lot. Returns the sourced/sunk pair for the step."""
	var items: PackedInt32Array = PackedInt32Array([ITEM_GRAIN, ITEM_MEAL, ITEM_WOOD])
	var item_id: int = items[_next_random(items.size())]
	var quantity: int = 1 + _next_random(5000)
	var container: Vector2i = containers[_next_random(containers.size())]
	var result: InventoryScript.OpResult = _inv.create_lot(container, item_id, quantity, _next_random(2), TEST_PROVENANCE, _next_random(2), 0, 0)
	return Vector2i(result.value, 0) if _tally("create", result.ok) else Vector2i.ZERO


func _random_sink(lot: Vector2i) -> Vector2i:
	"""Consume a random unreserved amount. Returns the sourced/sunk pair for the step."""
	var available: int = _inv.lot_available_milli(lot)
	if available <= 0:
		return Vector2i.ZERO
	var result: InventoryScript.OpResult = _inv.sink_lot_quantity(lot, 1 + _next_random(available))
	return Vector2i(0, result.value) if _tally("sink", result.ok) else Vector2i.ZERO


func _random_transfer(containers: Array[Vector2i], lot: Vector2i) -> void:
	"""Transfer a random unreserved amount into a random other container."""
	var available: int = _inv.lot_available_milli(lot)
	if available <= 0:
		return
	_tally("transfer", _inv.transfer(lot, containers[_next_random(containers.size())], 1 + _next_random(available)).ok)


func _random_merge(lot: Vector2i) -> void:
	"""Attempt to merge a random sibling into `lot`. A refusal is a legitimate outcome.

	Partners are drawn from the lot's own container, the only place a merge is legal at all,
	so the sequence exercises successful merges rather than only cross-container refusals.
	"""
	var owning: Array[Vector2i] = [_inv.lot_container(lot)]
	var siblings: Array[Vector2i] = []
	for candidate: Vector2i in _collect_lots(owning):
		if candidate != lot:
			siblings.append(candidate)
	if siblings.is_empty():
		return
	_tally("merge", _inv.merge_lots(lot, siblings[_next_random(siblings.size())]).ok)


func _random_release(lot: Vector2i) -> void:
	"""Release a random part of a lot's claim, or all of it."""
	var reserved: int = _inv.lot_reserved_milli(lot)
	if reserved <= 0:
		return
	if _next_random(2) == 0:
		_inv.release_all_reservations(lot)
	else:
		_inv.release_reservation(lot, 1 + _next_random(reserved))


func _collect_lots(containers: Array[Vector2i]) -> Array[Vector2i]:
	"""Every live lot ref, gathered by walking the containers' public lot iteration."""
	var lots: Array[Vector2i] = []
	for container: Vector2i in containers:
		var lot: Vector2i = _inv.container_first_lot(container)
		while lot != InventoryScript.NULL_REF:
			lots.append(lot)
			lot = _inv.container_next_lot(lot)
	return lots


func _walk_live_total(containers: Array[Vector2i]) -> int:
	"""Total live quantity across every container, summed independently of the module ledger."""
	var total: int = 0
	for lot: Vector2i in _collect_lots(containers):
		total += _inv.lot_quantity_milli(lot)
	return total


func test_random_sequence_keeps_reserved_within_quantity() -> void:
	"""Across the same randomised sequence, no lot ever holds a claim above its quantity."""
	var containers: Array[Vector2i] = _build_random_world()
	var violations: int = 0
	for step: int in range(400):
		_random_step(containers)
		for lot: Vector2i in _collect_lots(containers):
			if _inv.lot_reserved_milli(lot) > _inv.lot_quantity_milli(lot):
				violations += 1
	assert_equal(violations, 0, "reserved_milli never exceeds quantity_milli at any step")


func test_random_sequence_keeps_container_mass_within_capacity() -> void:
	"""No container ever exceeds max_mass_g, and its cached charged mass matches a fresh walk."""
	var containers: Array[Vector2i] = _build_random_world()
	var violations: int = 0
	for step: int in range(400):
		_random_step(containers)
		for container: Vector2i in containers:
			var committed: int = _inv.container_used_mass_g(container) + _inv.container_reserved_mass_g(container)
			if committed > _inv.container_max_mass_g(container):
				violations += 1
	assert_equal(violations, 0, "committed mass never exceeds capacity")
	assert_true(_inv.audit().ok, "the cached used mass matches a fresh per-lot recomputation")


# --- Checked arithmetic at the storage boundary -------------------------------------------------

func test_capacity_check_refuses_overflow_instead_of_wrapping() -> void:
	"""A commitment near INT64_MAX must refuse, not wrap the capacity sum negative and "fit".

	BAL-SAFE-002's bound is `used + reserved <= max`. With max at INT64_MAX and almost all of
	it reserved, a raw addition of the next lot's debit wraps to a large negative number, which
	compares as fitting and admits mass the container cannot hold.
	"""
	var container: Vector2i = _container(INT64_MAX)
	assert_true(_inv.reserve_container_mass(container, INT64_MAX - 1000).ok, "the reservation itself fits")
	var result: InventoryScript.OpResult = _inv.create_lot(container, ITEM_WOOD, 1000000000000, 0, 0, 0, 0, 0)
	assert_false(result.ok, "a debit that cannot be added to the commitment refuses")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_equal(_inv.live_lot_count(), 0, "no lot was created behind the wrapped comparison")
	assert_equal(_inv.container_used_mass_g(container), 0, "used mass never went negative")
	assert_true(_inv.audit().ok, "the refused operation leaves an auditable state")


func test_reserving_more_than_int64_holds_refuses() -> void:
	"""Two reservations whose sum overflows int64 refuse rather than wrapping the running total."""
	var container: Vector2i = _container(INT64_MAX)
	assert_true(_inv.reserve_container_mass(container, INT64_MAX - 10).ok, "the first reservation fits")
	var result: InventoryScript.OpResult = _inv.reserve_container_mass(container, 1000)
	assert_false(result.ok, "the second reservation cannot be represented")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_equal(_inv.container_reserved_mass_g(container), INT64_MAX - 10, "the first reservation is untouched")


func test_audit_detects_a_container_over_its_capacity() -> void:
	"""audit() re-derives BAL-SAFE-002 itself instead of only re-deriving the used mass.

	Checking the cached used mass against a lot walk says nothing about whether the container
	is over its limit, so the breach is planted directly in the column audit() must re-check.
	"""
	var container: Vector2i = _container(10000)
	_lot(container, ITEM_WOOD, 1000)
	assert_equal(_inv.container_used_mass_g(container), 5000, "the honest lot charges 5000 g")
	assert_true(_inv.audit().ok, "the honest state audits clean")
	_inv._c_reserved_mass_g[container.x] = 6000
	var result: InventoryScript.OpResult = _inv.audit()
	assert_false(result.ok, "used + reserved above max is a breach audit must see")
	assert_equal(result.error, InventoryScript.REFUSE_AUDIT_CAPACITY, "the refusal names the capacity invariant")


func test_audit_scans_through_to_the_highest_row_ever_allocated() -> void:
	"""audit() walks occupancy rather than capacity, so its bound must include the last slot.

	The bound is one past the highest slot either store has handed out. Off by one, or reset
	while rows are still live, and a breach in the newest container or the newest lot is
	never looked at -- audit() would return clean over broken state, which is worse than not
	auditing at all. The breaches below are planted in the LAST row of each store.
	"""
	var containers: Array[Vector2i] = []
	for index: int in range(4):
		containers.append(_container(10000, OWNER_A))
	var last_container: Vector2i = containers[containers.size() - 1]
	assert_equal(last_container.x, 3, "the fourth container took the highest slot")
	var last_lot: Vector2i = _lot(last_container, ITEM_WOOD, 1000)
	assert_true(_inv.audit().ok, "the honest state audits clean")
	_inv._c_reserved_mass_g[last_container.x] = 6000
	var breach: InventoryScript.OpResult = _inv.audit()
	assert_false(breach.ok, "the breach in the highest container row is found")
	assert_equal(breach.error, InventoryScript.REFUSE_AUDIT_CAPACITY, "the refusal names the capacity invariant")
	_inv._c_reserved_mass_g[last_container.x] = 0
	_inv._l_reserved_milli[last_lot.x] = 9000
	var lot_breach: InventoryScript.OpResult = _inv.audit()
	assert_false(lot_breach.ok, "the breach in the highest lot row is found")
	assert_equal(lot_breach.error, InventoryScript.REFUSE_AUDIT_RESERVED, "the refusal names the reservation bound")


func test_audit_detects_a_negative_reserved_mass() -> void:
	"""Negative reserved mass is free capacity conjured from nothing, and audit must see it.

	The lot walk cannot catch this: it re-derives used mass only, and used mass here is
	correct. Only a re-check of BAL-SAFE-002's own operands finds it.
	"""
	var container: Vector2i = _container(10000)
	_lot(container, ITEM_WOOD, 1000)
	_inv._c_reserved_mass_g[container.x] = -9223372036854775000
	var result: InventoryScript.OpResult = _inv.audit()
	assert_false(result.ok, "a negative reserved mass is a breach")
	assert_equal(result.error, InventoryScript.REFUSE_AUDIT_CAPACITY, "the refusal names the capacity invariant")


func test_out_of_range_lot_int32_fields_are_refused_not_truncated() -> void:
	"""ARCH-AUTH-003: quality, provenance and recipe_id are int32 columns and must never wrap.

	2^32 + 1 truncates to 1 in an int32 column, which is a different, entirely plausible
	catalog member -- exactly the silent narrowing the module header says it never performs.
	"""
	var container: Vector2i = _container()
	var over_int32: int = 4294967297
	_assert_lot_field_refused(container, over_int32, 0, 0, "quality")
	_assert_lot_field_refused(container, 0, over_int32, 0, "provenance")
	_assert_lot_field_refused(container, 0, 0, over_int32, "recipe_id")
	_assert_lot_field_refused(container, 0, -4294967297, 0, "negative provenance")
	assert_equal(_inv.live_lot_count(), 0, "no truncated row was stored")


func _assert_lot_field_refused(container: Vector2i, quality: int, provenance: int, recipe_id: int, field: String) -> void:
	"""Assert that an int32 lot column given an out-of-range value refuses without storing."""
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.create_lot(container, ITEM_GRAIN, 1000, quality, provenance, recipe_id, 0, 0)
	assert_false(result.ok, "an out-of-range %s refuses" % field)
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the %s refusal names the overflow" % field)
	assert_true(_inv.state_bytes() == before, "the refused %s wrote nothing" % field)


func test_out_of_range_container_policy_is_refused_not_truncated() -> void:
	"""A container policy outside int32 refuses; 2^32 would otherwise be stored as 0."""
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.create_container(OWNER_A, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL, 4294967296, true)
	assert_false(result.ok, "an out-of-range policy refuses")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_equal(_inv.live_container_count(), 0, "no container was created")
	assert_true(_inv.state_bytes() == before, "the refused create wrote nothing")


func test_int32_boundary_values_are_stored_verbatim() -> void:
	"""The int32 extremes are legal opaque values and must round-trip, not be refused."""
	var high: int = 2147483647
	var low: int = -2147483648
	var created: InventoryScript.OpResult = _inv.create_container(OWNER_A, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL, low, true)
	assert_true(created.ok, "a policy at INT32_MIN is accepted")
	assert_equal(_inv.container_policy(created.ref), low, "the policy round-trips exactly")
	var lot: Vector2i = _lot(created.ref, ITEM_GRAIN, 1000, high, high, high)
	assert_equal(_inv.lot_quality(lot), high, "quality round-trips at INT32_MAX")
	assert_equal(_inv.lot_provenance(lot), high, "provenance round-trips at INT32_MAX")
	assert_equal(_inv.lot_recipe_id(lot), high, "recipe_id round-trips at INT32_MAX")


# --- Ages that cannot be rounded ----------------------------------------------------------------

func test_unroundable_age_is_refused_at_lot_creation() -> void:
	"""An age within 999 of INT64_MAX cannot be rounded up, so the lot is refused up front."""
	var container: Vector2i = _container()
	var result: InventoryScript.OpResult = _inv.create_lot(container, ITEM_GRAIN, 1000, 0, 0, 0, INT64_MAX - 500, 0)
	assert_false(result.ok, "an age that ceil_div cannot round refuses")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_equal(_inv.live_lot_count(), 0, "no unroundable age reached a lot row")
	var legal: InventoryScript.OpResult = _inv.create_lot(container, ITEM_GRAIN, 1000, 0, 0, 0, InventoryScript.MAX_AGE_MILLI_HOURS, 0)
	assert_true(legal.ok, "the largest still-roundable age is accepted")


func test_merge_refuses_unroundable_ages_instead_of_calling_them_equal() -> void:
	"""Two lots whose ages cannot be rounded are not "equally aged"; the merge refuses.

	A -1 sentinel from the rounding would make both lots compare equal, pass the AGE_MISMATCH
	gate, and write a merged age of -1000 -- which inverts every `age >= shelf_hours * 1000`
	spoilage test in GDD §5.8. The ages are planted directly, because creation now refuses them.
	"""
	var container: Vector2i = _container()
	var dest: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, TEST_PROVENANCE, 0, 1000, 0)
	var source: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, TEST_PROVENANCE, 0, 1000, 0)
	_inv._l_age_milli_hours[dest.x] = INT64_MAX - 100
	_inv._l_age_milli_hours[source.x] = INT64_MAX - 200
	var result: InventoryScript.OpResult = _inv.merge_lots(dest, source)
	assert_false(result.ok, "a merge whose ages cannot be rounded refuses")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_true(_inv.lot_age_milli_hours(dest) > 0, "no negative age was written to the destination")
	assert_true(_inv.is_lot_valid(source), "the source lot was not retired by a half-applied merge")


func test_transfer_refuses_when_a_merge_candidate_age_cannot_be_rounded() -> void:
	"""The transfer-side merge search refuses on an unroundable age rather than matching on -1."""
	var source_container: Vector2i = _container()
	var dest_container: Vector2i = _container(BIG_MASS, OWNER_B)
	var resident: Vector2i = _lot(dest_container, ITEM_GRAIN, 1000, 0, TEST_PROVENANCE, 0, 1000, 0)
	var incoming: Vector2i = _lot(source_container, ITEM_GRAIN, 2000, 0, TEST_PROVENANCE, 0, 1000, 0)
	_inv._l_age_milli_hours[resident.x] = INT64_MAX - 100
	_inv._l_age_milli_hours[incoming.x] = INT64_MAX - 200
	var before: PackedByteArray = _inv.state_bytes()
	var result: InventoryScript.OpResult = _inv.transfer(incoming, dest_container, 1000)
	assert_false(result.ok, "the transfer refuses instead of merging on a sentinel")
	assert_equal(result.error, InventoryScript.REFUSE_OVERFLOW, "the refusal names the overflow")
	assert_true(_inv.lot_age_milli_hours(resident) > 0, "no negative age was written to the resident lot")
	assert_true(_inv.state_bytes() == before, "the refused transfer changed nothing")


# --- Rollback of the free stacks ----------------------------------------------------------------

func test_abort_restores_the_lot_free_stack_after_an_allocation_and_a_retirement() -> void:
	"""A rollback must restore the free stack cells, not merely the row columns.

	Retiring a lot pushes its slot back over the cell the next allocation would hand out.
	Without that cell's journaled pre-image, an abort leaves the retired slot present twice
	while its lot is live again, and the next create_lot() overwrites a live row.
	"""
	var container: Vector2i = _container()
	var live: Vector2i = _lot(container, ITEM_GRAIN, 1000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_true(_inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0).ok, "the allocation applies")
	assert_true(_inv.sink_lot_quantity(live, 1000).ok, "the retirement applies")
	assert_false(_inv.is_lot_valid(live), "the lot really was retired inside the transaction")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "abort restored the lot free stack byte for byte")
	assert_true(_inv.is_lot_valid(live), "the retired lot is live again")
	var fresh: InventoryScript.OpResult = _inv.create_lot(container, ITEM_WOOD, 1000, 0, 0, 0, 0, 0)
	assert_true(fresh.ok, "the next allocation succeeds")
	assert_true(fresh.ref.x != live.x, "and takes a fresh slot, not the restored live row")
	assert_equal(_inv.lot_quantity_milli(live), 1000, "the restored lot kept its quantity")


func test_abort_restores_the_container_free_stack_after_a_destroy() -> void:
	"""The same pre-image restore is required for the container free stack."""
	var keep: Vector2i = _container()
	var doomed: Vector2i = _container(BIG_MASS, OWNER_B)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "the transaction opens")
	assert_true(_inv.create_container(OWNER_A, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ok, "the allocation applies")
	assert_true(_inv.destroy_container(doomed).ok, "the retirement applies")
	assert_false(_inv.is_container_valid(doomed), "the container really was destroyed inside the transaction")
	_inv.abort()
	assert_true(_inv.state_bytes() == before, "abort restored the container free stack byte for byte")
	assert_true(_inv.is_container_valid(doomed), "the destroyed container is live again")
	var fresh: InventoryScript.OpResult = _inv.create_container(OWNER_A, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true)
	assert_true(fresh.ok, "the next allocation succeeds")
	assert_true(fresh.ref.x != doomed.x, "and takes a fresh slot, not the restored container")
	assert_true(fresh.ref.x != keep.x, "and not the other live container either")


# --- Opaque catalog enums -----------------------------------------------------------------------

func test_module_publishes_no_provenance_or_policy_catalog_numbers() -> void:
	"""BAL-CAT-001 compiles provenance and policy from sorted catalog keys, not from this module.

	GDD §4.3 numbers neither enumeration, so inventory must not name a member and assert its
	value; STARTER in particular is very unlikely to compile to 1. Only unset-field sentinels
	are published, and the columns are compared for equality alone.
	"""
	var constants: Dictionary = _inv.get_script().get_script_constant_map()
	assert_false(constants.has("PROVENANCE_STARTER"), "no STARTER provenance number is invented here")
	assert_false(constants.has("PROVENANCE_UNKNOWN"), "no UNKNOWN provenance number is invented here")
	assert_false(constants.has("POLICY_DEFAULT"), "no default policy number is invented here")
	assert_true(constants.has("UNSET_PROVENANCE"), "an unset-field sentinel is published instead")
	assert_true(constants.has("UNSET_POLICY"), "an unset-field sentinel is published instead")


func test_provenance_is_compared_only_for_equality() -> void:
	"""Any two distinct int32 provenance values block a merge; none is privileged over another."""
	var container: Vector2i = _container()
	var a: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, 2147483647)
	var b: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, -2147483648)
	var mismatch: InventoryScript.OpResult = _inv.merge_lots(a, b)
	assert_false(mismatch.ok, "two different opaque provenance values never merge")
	assert_equal(mismatch.error, InventoryScript.REFUSE_ATTRIBUTE_MISMATCH, "the refusal names the attribute mismatch")
	var c: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, 2147483647)
	assert_true(_inv.merge_lots(a, c).ok, "equal opaque provenance values merge")
	assert_equal(_inv.lot_provenance(a), 2147483647, "the merged lot keeps the value verbatim")


# --- Allocation and result-scratch discipline (task 2.7, decision 0015) --------------------------

func test_a_transfer_produces_exactly_one_surviving_object_per_call() -> void:
	"""Task 2.7: one OpResult escapes a transfer and the module retains nothing else.

	Scope, stated honestly: a live-object census cannot see a transient RefCounted, because a
	result built and dropped inside the operation is freed before the count is read. What this
	does catch is the leak class -- a transfer that caches a result, a plan or a Calendar on the
	inventory, or that builds more than one object the caller keeps. Whether the INTERNALS
	allocate is a timing property, measured with the task 2.7 benchmark, not asserted here.
	"""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lots: Array[Vector2i] = []
	for _index: int in 20:
		lots.append(_lot(source, ITEM_GRAIN, 4000))
	var held: Array = []
	var before: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	for index: int in 20:
		held.append(_inv.transfer(lots[index], dest, 1000))
	var after: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_equal(held.size(), 20, "20 transfers ran")
	assert_true(held[0].ok, "the first transfer succeeded")
	assert_equal(after - before, 20, "20 transfers allocated exactly 20 objects")


func test_a_refusal_never_carries_the_previous_operations_ref_or_value() -> void:
	"""The internal ref/value scratch must not leak a successful result into a later refusal.

	This is the H4 rule applied to the new signalling: a refusal's value channel must be empty,
	never a plausible looking leftover a caller could act on.
	"""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var good: InventoryScript.OpResult = _inv.transfer(lot, dest, 1000)
	assert_true(good.ok, "the seeding transfer succeeded")
	assert_true(good.value > 0, "the seeding transfer carried a real quantity")
	var refused: InventoryScript.OpResult = _inv.transfer(lot, dest, 999999999)
	assert_false(refused.ok, "an over-quantity transfer refuses")
	assert_equal(refused.error, InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED, "named refusal")
	assert_equal(refused.value, 0, "the refusal carries no value")
	assert_equal(refused.ref, InventoryScript.NULL_REF, "the refusal carries the null ref")


func test_every_refusing_operation_returns_the_null_ref_and_zero() -> void:
	"""Sweep the refusal paths that follow a success, so none of them can echo it."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	assert_true(_inv.reserve_lot(lot, 1000).ok, "seed a successful reservation result")
	var refusals: Array[InventoryScript.OpResult] = [
		_inv.split_lot(lot, 0),
		_inv.merge_lots(lot, lot),
		_inv.move_lot(lot, source),
		_inv.sink_lot_quantity(lot, -1),
		_inv.consume_reserved(lot, 999999),
		_inv.reserve_lot(lot, 999999),
		_inv.release_reservation(lot, 999999),
		_inv.create_lot(dest, 99, 1000, 0, TEST_PROVENANCE, 0, 0, 0),
		_inv.destroy_container(source),
		_inv.reserve_container_mass(dest, -1),
	]
	for result: InventoryScript.OpResult in refusals:
		assert_false(result.ok, "refused: %s" % result.error)
		assert_equal(result.value, 0, "refusal %s carries no value" % result.error)
		assert_equal(result.ref, InventoryScript.NULL_REF, "refusal %s carries the null ref" % result.error)


func test_a_poisoned_transaction_refuses_later_operations_with_the_first_code() -> void:
	"""A refusal inside an open transaction must poison it and survive the StringName plumbing."""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "transaction opens")
	assert_true(_inv.transfer(lot, dest, 1000).ok, "the first step applies")
	assert_false(_inv.sink_lot_quantity(lot, -5).ok, "an invalid quantity refuses")
	var later: InventoryScript.OpResult = _inv.transfer(lot, dest, 500)
	assert_false(later.ok, "a poisoned transaction refuses every later operation")
	assert_equal(later.error, InventoryScript.REFUSE_TRANSACTION_POISONED, "poisoned code")
	assert_equal(later.value, 0, "the poisoned refusal carries no value")
	var commit: InventoryScript.OpResult = _inv.commit()
	assert_false(commit.ok, "commit reports the first refusal")
	assert_equal(commit.error, InventoryScript.REFUSE_INVALID_QUANTITY, "first refusal code")
	assert_equal(_inv.state_bytes(), before, "rollback restored state byte for byte")


func test_audit_reuses_its_conservation_tally_across_repeated_calls() -> void:
	"""ARCH-MEM-005: the per-item tally is allocated once, so repeat audits must not drift.

	A refilled buffer that was not actually cleared would double-count on the second call and
	report AUDIT_CONSERVATION_BROKEN.
	"""
	var source: Vector2i = _container()
	var dest: Vector2i = _container(BIG_MASS, OWNER_B)
	var lot: Vector2i = _lot(source, ITEM_GRAIN, 4000)
	assert_true(_inv.transfer(lot, dest, 1500).ok, "transfer applies")
	assert_true(_inv.split_lot(lot, 500).ok, "split applies")
	for index: int in 5:
		var result: InventoryScript.OpResult = _inv.audit()
		assert_true(result.ok, "audit pass %d holds (error: %s)" % [index, result.error])
	assert_true(_inv.sink_lot_quantity(lot, 500).ok, "sink applies")
	assert_true(_inv.audit().ok, "audit still holds after a sink")
# --- Equipped lots: the null-container amendment (decision 0061, ruling §4) --------------------
#
# The contract these pin: a lot may carry `container = NULL_REF` ONLY when a bound authority
# proves it is an equipped record with a live owner, it is then excluded from loose-stock
# availability and from container mass, it is never cloned, merged, split or re-aged, and it can
# never be counted once as equipped and again in storage.


class StubAuthority extends RefCounted:
	"""A stand-in equipment authority: it attests for exactly the lots it was told to.

	`gear.gd` is the real one. This exists so `inventory.gd`'s half of the contract can be tested
	without the gear store deciding what the answer is.
	"""
	var attested: Dictionary = {}

	func attest(lot_ref: Vector2i) -> void:
		"""Start attesting for one lot."""
		attested[lot_ref] = true

	func withdraw(lot_ref: Vector2i) -> void:
		"""Stop attesting for one lot, as a dead owner would."""
		attested.erase(lot_ref)

	func is_equipped_record(lot_ref: Vector2i) -> bool:
		"""The attestation `inventory.gd` calls."""
		return attested.has(lot_ref)


class ReentrantAuthority extends RefCounted:
	"""An authority that tries to mutate the inventory from inside its own attestation."""
	var inventory: Variant = null
	var lot_ref: Vector2i = Vector2i(-1, 0)
	var container_ref: Vector2i = Vector2i(-1, 0)
	var reentry_error: StringName = &"NOT_ATTEMPTED"

	func is_equipped_record(p_lot_ref: Vector2i) -> bool:
		"""Attest, but try to sink the very lot being validated on the way through."""
		reentry_error = inventory.sink_lot_quantity(lot_ref, 1).error
		return p_lot_ref == lot_ref


class MissingMethodAuthority extends RefCounted:
	"""An object that publishes no attestation at all."""
	var unrelated: int = 0


func _equip_fixture(authority: StubAuthority, box: Vector2i) -> Vector2i:
	"""Bind `authority`, create one 1000-milli tool lot, attest for it and detach it."""
	var bound: InventoryScript.OpResult = _inv.set_equipment_authority(authority)
	assert_true(bound.ok, "binding an authority must succeed: %s" % bound.error)
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	authority.attest(lot)
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_true(detached.ok, "a proved equipped lot must detach: %s" % detached.error)
	return lot


func test_a_null_container_lot_refuses_with_no_authority_bound() -> void:
	"""With nothing able to prove an equipped record, no lot may leave its container."""
	var box: Vector2i = _container()
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	var before: PackedByteArray = _inv.state_bytes()
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_false(detached.ok, "a null container needs a proof, not permission")
	assert_equal(detached.error, InventoryScript.REFUSE_NO_EQUIPMENT_AUTHORITY,
		"and the refusal names the missing authority")
	assert_equal(_inv.state_bytes(), before, "the refusal wrote nothing at all")
	assert_equal(_inv.lot_container(lot), box, "the lot keeps its container")


func test_a_null_container_lot_refuses_when_the_authority_does_not_attest() -> void:
	"""An authority is bound, but this lot is not an equipped record. That is still a refusal."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	var before: PackedByteArray = _inv.state_bytes()
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_false(detached.ok, "an unattested lot may not become an orphan")
	assert_equal(detached.error, InventoryScript.REFUSE_NOT_AN_EQUIPPED_RECORD,
		"and the refusal says exactly why")
	assert_equal(_inv.state_bytes(), before, "nothing was written")


func test_an_object_without_an_attestation_method_cannot_be_the_authority() -> void:
	"""The binding is checked at bind time, not discovered at the first detach."""
	var bound: InventoryScript.OpResult = _inv.set_equipment_authority(MissingMethodAuthority.new())
	assert_false(bound.ok, "an object that cannot attest cannot be the authority")
	assert_equal(bound.error, InventoryScript.REFUSE_INVALID_EQUIPMENT_AUTHORITY,
		"and the refusal names the reason")
	assert_false(_inv.has_equipment_authority(), "so nothing is bound")


func test_unbinding_the_authority_refuses_while_equipped_lots_live() -> void:
	"""Unbinding would strand exactly the orphan lots the proof exists to prevent."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	var unbound: InventoryScript.OpResult = _inv.set_equipment_authority(null)
	assert_false(unbound.ok, "an authority holding live equipped lots may not walk away")
	assert_equal(unbound.error, InventoryScript.REFUSE_EQUIPPED_LOTS_LIVE, "named explicitly")
	assert_true(_inv.has_equipment_authority(), "the authority is still bound after the refusal")
	authority.withdraw(lot)
	assert_true(_inv.attach_equipped_lot(lot, box, false).ok, "shelving it again is the way out")
	assert_true(_inv.set_equipment_authority(null).ok, "and only then may the authority unbind")
	assert_false(_inv.has_equipment_authority(), "leaving no authority bound")


func test_an_equipped_lot_is_excluded_from_container_mass() -> void:
	"""GDD §5.7: equipped tools are outside satchel capacity. The container gets its grams back."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	var loaded: int = _inv.container_used_mass_g(box)
	assert_equal(loaded, TOOL_MASS, "one tool charges its own mass while stored")
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "the proved lot detaches")
	assert_equal(_inv.container_used_mass_g(box), 0,
		"an equipped lot charges no container mass")
	assert_equal(_inv.container_lot_count(box), 0, "and is in no container's lot list")


func test_an_equipped_lot_is_excluded_from_loose_stock_availability() -> void:
	"""Loose stock is what can be claimed. Equipment is not loose stock."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var stored: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "the proved lot detaches")
	assert_equal(_inv.total_loose_milli(ITEM_TOOL), 1000, "only the stored tool is loose stock")
	assert_equal(_inv.total_equipped_milli(ITEM_TOOL), 1000, "and the other is equipment")
	assert_equal(_inv.total_live_milli(ITEM_TOOL), 2000, "both are still live and conserved")
	assert_true(_inv.is_lot_valid(stored), "the stored lot is untouched")


func test_loose_and_equipped_always_partition_the_live_quantity() -> void:
	"""THE DOUBLE COUNT. One lot may never be both loose stock and equipment.

	Walked over every arrangement the operations can reach -- nothing equipped, some equipped,
	all equipped, then shelved again -- and at each step the two must sum to the live total with
	nothing over. A lot counted twice makes this sum exceed `live`; a lot lost makes it fall
	short. There is no arrangement in between.
	"""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lots: Array[Vector2i] = []
	for index: int in range(4):
		lots.append(_inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref)
	_assert_partitioned(4000, 0)
	for index: int in range(4):
		authority.attest(lots[index])
		assert_true(_inv.detach_lot_to_equipment(lots[index]).ok, "detach %d" % index)
		_assert_partitioned(4000, (index + 1) * 1000)
	for index: int in range(4):
		authority.withdraw(lots[index])
		assert_true(_inv.attach_equipped_lot(lots[index], box, false).ok, "attach")
		_assert_partitioned(4000, 3000 - index * 1000)


func _assert_partitioned(live: int, equipped: int) -> void:
	"""Loose plus equipped is exactly live, and equipped is exactly what was expected."""
	assert_equal(_inv.total_live_milli(ITEM_TOOL), live, "live quantity is conserved")
	assert_equal(_inv.total_equipped_milli(ITEM_TOOL), equipped, "equipped quantity is exact")
	assert_equal(_inv.total_loose_milli(ITEM_TOOL) + _inv.total_equipped_milli(ITEM_TOOL),
		live, "loose plus equipped is the live total: nothing counted twice, nothing lost")
	assert_equal(_inv.equipped_lot_count(), equipped / 1000, "and the lot count agrees")


func test_every_lot_mutator_refuses_an_equipped_lot() -> void:
	"""Never clone it, merge it, split it, move it, sink it or reserve it while it is equipped."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	var other: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	var before: PackedByteArray = _inv.state_bytes()
	assert_equal(_inv.split_lot(lot, 500).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no split")
	assert_equal(_inv.merge_lots(other, lot).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no merge in")
	assert_equal(_inv.merge_lots(lot, other).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no merge out")
	assert_equal(_inv.move_lot(lot, box).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no move")
	assert_equal(_inv.transfer(lot, box, 1000).error, InventoryScript.REFUSE_LOT_EQUIPPED,
		"no transfer")
	assert_equal(_inv.sink_lot_quantity(lot, 1000).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no sink")
	assert_equal(_inv.reserve_lot(lot, 1000).error, InventoryScript.REFUSE_LOT_EQUIPPED, "no reserve")
	assert_equal(_inv.state_bytes(), before, "and not one of those refusals wrote a byte")


func test_detach_refuses_a_lot_that_still_carries_a_reservation() -> void:
	"""A reserved lot is promised to a job. It cannot quietly leave for a resident's hands."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	assert_true(_inv.reserve_lot(lot, 1000).ok, "the lot is reserved")
	authority.attest(lot)
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_false(detached.ok, "a reserved lot may not be detached")
	assert_equal(detached.error, InventoryScript.REFUSE_LOT_HAS_RESERVATION, "named explicitly")


func test_attach_refuses_while_the_authority_still_calls_the_lot_equipped() -> void:
	"""The door that would otherwise admit a lot charging mass AND counting as equipment."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	var before: PackedByteArray = _inv.state_bytes()
	var attached: InventoryScript.OpResult = _inv.attach_equipped_lot(lot, box, false)
	assert_false(attached.ok, "a still-attested lot may not be shelved")
	assert_equal(attached.error, InventoryScript.REFUSE_STILL_AN_EQUIPPED_RECORD, "named explicitly")
	assert_equal(_inv.state_bytes(), before, "and the refusal wrote nothing")
	assert_equal(_inv.container_used_mass_g(box), 0, "the container took no mass")


func test_unequip_lands_in_a_reserved_destination_without_losing_its_space() -> void:
	"""Ruling §4: unequip places the same lot into a VALID RESERVED destination.

	The reserved grams become used grams in one step, so a container filled to the brim by
	somebody else in between still has exactly this lot's space waiting.
	"""
	var authority: StubAuthority = StubAuthority.new()
	var small: Vector2i = _inv.create_container(OWNER_A, TOOL_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, 0, true).ref
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(small, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "the proved lot detaches")
	assert_true(_inv.reserve_container_mass(small, TOOL_MASS).ok, "its space is reserved")
	assert_equal(_inv.container_free_mass_g(small), 0, "so the container admits nothing else")
	authority.withdraw(lot)
	var attached: InventoryScript.OpResult = _inv.attach_equipped_lot(lot, small, true)
	assert_true(attached.ok, "the reserved destination takes it back: %s" % attached.error)
	assert_equal(_inv.container_used_mass_g(small), TOOL_MASS, "as used mass now")
	assert_equal(_inv.container_reserved_mass_g(small), 0, "and the reservation was spent once")


func test_attach_from_reserved_mass_refuses_without_enough_reserved() -> void:
	"""Spending grams that were never reserved would manufacture capacity. It refuses."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	authority.withdraw(lot)
	var before: PackedByteArray = _inv.state_bytes()
	var attached: InventoryScript.OpResult = _inv.attach_equipped_lot(lot, box, true)
	assert_false(attached.ok, "there is no reserved mass to spend")
	assert_equal(attached.error, InventoryScript.REFUSE_INSUFFICIENT_RESERVED_MASS, "named explicitly")
	assert_equal(_inv.state_bytes(), before, "and nothing was written")


func test_a_detach_and_attach_round_trip_preserves_the_whole_lot_row() -> void:
	"""The SAME lot: same reference, quantity, quality, provenance, recipe and age."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 4, 7, 9, 12345, 678).ref
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "detach")
	assert_true(_inv.is_lot_valid(lot), "the very same reference is still valid while equipped")
	assert_equal(_inv.lot_container(lot), InventoryScript.NULL_REF, "its container is the null ref")
	authority.withdraw(lot)
	assert_true(_inv.attach_equipped_lot(lot, box, false).ok, "attach")
	assert_equal(_inv.lot_quantity_milli(lot), 1000, "quantity is unchanged")
	assert_equal(_inv.lot_quality(lot), 4, "quality is unchanged")
	assert_equal(_inv.lot_provenance(lot), 7, "provenance is unchanged")
	assert_equal(_inv.lot_recipe_id(lot), 9, "recipe id is unchanged")
	assert_equal(_inv.lot_age_milli_hours(lot), 12345, "age is not reset")
	assert_equal(_inv.lot_age_remainder(lot), 678, "and neither is its remainder")


func test_audit_refuses_an_orphaned_null_container_lot() -> void:
	"""An owner who dies withdraws the proof. The lot is then an orphan, and audit says so."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	assert_true(_inv.audit().ok, "a proved equipped lot audits clean")
	authority.withdraw(lot)
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "an unattested null-container lot is an orphan")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_ORPHAN_LOT, "named explicitly")


func test_audit_refuses_a_shelved_lot_the_authority_still_calls_equipped() -> void:
	"""The other half of the biconditional: equipment that is also charging container mass."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	assert_true(_inv.audit().ok, "a plain stored lot audits clean")
	authority.attest(lot)
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "a lot cannot be equipment and stored stock at once")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_ORPHAN_LOT, "named explicitly")


func test_an_authority_that_re_enters_the_inventory_is_refused() -> void:
	"""An attestation is a pure read. One that mutates is refused, not half-applied."""
	var box: Vector2i = _container()
	var authority: ReentrantAuthority = ReentrantAuthority.new()
	authority.inventory = _inv
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	authority.lot_ref = lot
	var detached: InventoryScript.OpResult = _inv.detach_lot_to_equipment(lot)
	assert_equal(authority.reentry_error, InventoryScript.REFUSE_ATTESTATION_REENTRY,
		"the re-entrant mutation was refused inside the attestation")
	assert_equal(_inv.lot_quantity_milli(lot), 1000, "so it removed nothing")
	assert_true(detached.ok, "and the honest attestation still completed: %s" % detached.error)


func test_a_rolled_back_detach_restores_the_state_byte_for_byte() -> void:
	"""An aborted transaction puts the lot, its list links, the mass and the count back."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "the authority binds")
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 0, 1, 0, 0, 0).ref
	authority.attest(lot)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "open a transaction")
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "detach inside it")
	assert_equal(_inv.equipped_lot_count(), 1, "which counts an equipped lot")
	_inv.abort()
	assert_equal(_inv.state_bytes(), before, "abort restores every column byte for byte")
	assert_equal(_inv.equipped_lot_count(), 0, "including the equipped-lot count")
	assert_equal(_inv.lot_container(lot), box, "and the lot is back in its container")


func test_a_rolled_back_attach_restores_the_state_byte_for_byte() -> void:
	"""The same on the way home: an aborted unequip leaves the lot equipped and the mass off."""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	authority.withdraw(lot)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "open a transaction")
	assert_true(_inv.attach_equipped_lot(lot, box, false).ok, "attach inside it")
	_inv.abort()
	assert_equal(_inv.state_bytes(), before, "abort restores every column byte for byte")
	assert_equal(_inv.equipped_lot_count(), 1, "the lot is equipped again")
	assert_equal(_inv.container_used_mass_g(box), 0, "and charges no container mass")


func test_create_lot_still_demands_a_real_container() -> void:
	"""Nothing was weakened: the amendment adds a door, it does not open the front wall."""
	var made: InventoryScript.OpResult = _inv.create_lot(InventoryScript.NULL_REF, ITEM_TOOL, 1000, 0, 1,
		0, 0, 0)
	assert_false(made.ok, "a lot is never created with a null container")
	assert_equal(made.error, InventoryScript.REFUSE_INVALID_CONTAINER, "named explicitly")
	assert_equal(_inv.equipped_lot_count(), 0, "and no equipped record appeared")




func test_audit_re_derives_the_equipped_lot_count_instead_of_trusting_it() -> void:
	"""MUTATION GAP. The maintained count is a cache, and audit() exists to distrust caches.

	Every operation that moves the count also moves the column it summarises, so no public call
	can put the two out of step -- which is why the check needs the same private-column access
	`test_reservations.gd` and `test_gear.gd` use to observe an allocator. The invariant is real:
	`equipped_lot_count()` is published, and a cache nobody re-derives is a cache that drifts.
	"""
	var box: Vector2i = _container()
	var authority: StubAuthority = StubAuthority.new()
	var lot: Vector2i = _equip_fixture(authority, box)
	assert_equal(_inv.equipped_lot_count(), 1, "one lot is equipped")
	assert_true(_inv.audit().ok, "and the audit is clean")
	_inv.set("_equipped_lot_count", 4)
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "a count that disagrees with the rows is refused")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_EQUIPPED_COUNT, "named explicitly")
	_inv.set("_equipped_lot_count", 1)
	assert_true(_inv.audit().ok, "and putting the count back makes it clean again")
	assert_true(_inv.is_lot_valid(lot), "the lot itself was never touched by any of this")


func test_audit_refuses_a_cyclic_lot_list_instead_of_walking_it_forever() -> void:
	"""A corrupted `_l_next` must make audit() refuse, not hang.

	No public operation can build a cycle, so the column is corrupted directly -- the same
	private-column access `test_gear.gd` and `test_reservations.gd` use to observe an allocator.
	The reason this branch exists at all is concrete: a mutation that left a detached lot linked
	turned this walk into a process that had to be killed by hand.
	"""
	var box: Vector2i = _container()
	var first: Vector2i = _lot(box, ITEM_TOOL, 1000)
	var second: Vector2i = _lot(box, ITEM_TOOL, 1000)
	assert_true(_inv.audit().ok, "two honestly linked lots audit clean")
	var next_column: PackedInt32Array = _inv.get("_l_next")
	next_column[second.x] = first.x
	next_column[first.x] = second.x
	_inv.set("_l_next", next_column)
	var audited: InventoryScript.OpResult = _inv.audit()
	assert_false(audited.ok, "a cycle is refused rather than walked forever")
	assert_equal(audited.error, InventoryScript.REFUSE_AUDIT_LOT_CYCLE, "named explicitly")
# --- ARCH-SYS-004's two mutators (GDD §5.8 REQ-SET-107–108) -------------------------------------

func test_one_aged_hour_is_the_floor_of_the_two_factors_over_a_thousand() -> void:
	"""§5.8: "Effective age per hour=floor(store_factor*temperature_factor/1000)"."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_GRAIN, 4000)
	var aged: InventoryScript.OpResult = _inv.advance_lot_age_hour(lot, 350, 500)
	assert_true(aged.ok, "a cellar hour in winter is a legal step")
	assert_equal(aged.value, 175, "floor(350*500/1000) milli-hours")
	assert_equal(_inv.lot_age_milli_hours(lot), 175, "written onto the row")
	assert_equal(_inv.lot_age_remainder(lot), 0, "with no fraction outstanding")


func test_a_negative_aging_factor_refuses_instead_of_ageing_backwards() -> void:
	"""§5.8's tables hold no negative factor, and a negative one would un-age stored food."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_GRAIN, 4000, 0, TEST_PROVENANCE, 0, 5000, 0)
	var refused: InventoryScript.OpResult = _inv.advance_lot_age_hour(lot, -1, 1000)
	assert_false(refused.ok, "a negative store factor refuses")
	assert_equal(refused.error, InventoryScript.REFUSE_INVALID_AGE_FACTOR, "and is named")
	assert_false(_inv.advance_lot_age_hour(lot, 1000, -1).ok, "so does a negative temperature")
	assert_equal(_inv.lot_age_milli_hours(lot), 5000, "and the stored age is untouched")


func test_an_aged_hour_rolls_back_with_the_transaction_that_refused() -> void:
	"""Aging is journaled like everything else here: a poisoned sequence restores both columns."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_GRAIN, 4000, 0, TEST_PROVENANCE, 0, 2000, 0)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "a transaction opens")
	assert_true(_inv.advance_lot_age_hour(lot, 1500, 1500).ok, "one hour is applied")
	assert_false(_inv.sink_lot_quantity(lot, 99999).ok, "then a step refuses and poisons it")
	assert_false(_inv.commit().ok, "so the commit reports the refusal")
	assert_equal(_inv.lot_age_milli_hours(lot), 2000, "the age rolled back")
	assert_equal(_inv.state_bytes(), before, "and the whole store is byte identical")


func test_a_transformed_lot_keeps_its_row_and_moves_both_conservation_ledgers() -> void:
	"""§5.8's conversion is in place, and both halves are declared rather than silently relabelled."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_MEAL, 2000)
	var generation: int = lot.y
	assert_true(_inv.transform_lot_item(lot, ITEM_GRAIN, 4000).ok, "the conversion commits")
	assert_equal(_inv.lot_item_id(lot), ITEM_GRAIN, "the same row now holds the new item")
	assert_equal(lot.y, generation, "at the same generation, so every held ref still resolves")
	assert_equal(_inv.lot_quantity_milli(lot), 4000, "at the caller's quantity")
	assert_equal(_inv.total_sunk_milli(ITEM_MEAL), 2000, "the old item is sunk in full")
	assert_equal(_inv.total_sourced_milli(ITEM_GRAIN), 4000, "the new one is sourced in full")
	assert_true(_inv.audit().ok, "so `live + sunk == sourced` still closes on both")


func test_an_equal_mass_transformation_moves_the_containers_charged_mass_by_nothing() -> void:
	"""2000 milli-U at 500 g and 4000 milli-U at 250 g are the same grams and the same debit."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_MEAL, 2000)
	var before_g: int = _inv.container_used_mass_g(box)
	assert_equal(before_g, 1000, "2000 milli-U of 500 g meals is 1000 g")
	assert_true(_inv.transform_lot_item(lot, ITEM_GRAIN, 4000).ok, "the conversion commits")
	assert_equal(_inv.container_used_mass_g(box), before_g, "and charges the same grams")


func test_a_transformation_resets_the_age_so_the_new_item_starts_its_own_shelf_life() -> void:
	"""Spoiled_food "lasts 240h" from the moment it becomes spoiled_food, not from before it."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_MEAL, 2000, 0, TEST_PROVENANCE, 0, 36000, 250)
	assert_equal(_inv.lot_age_milli_hours(lot), 36000, "the meal is well past its shelf life")
	assert_true(_inv.transform_lot_item(lot, ITEM_GRAIN, 4000).ok, "the conversion commits")
	assert_equal(_inv.lot_age_milli_hours(lot), 0, "and the row starts again at zero")
	assert_equal(_inv.lot_age_remainder(lot), 0, "remainder included")


func test_a_transformation_refuses_a_reserved_lot_rather_than_carrying_the_claim() -> void:
	"""REQ-SET-108 INVALIDATES the claims; carrying one across an item change would not."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_MEAL, 2000)
	assert_true(_inv.reserve_lot(lot, 500).ok, "a job claims part of it")
	var refused: InventoryScript.OpResult = _inv.transform_lot_item(lot, ITEM_GRAIN, 4000)
	assert_false(refused.ok, "the conversion refuses while the claim stands")
	assert_equal(refused.error, InventoryScript.REFUSE_LOT_HAS_RESERVATION, "and is named")
	assert_equal(_inv.lot_item_id(lot), ITEM_MEAL, "the lot is untouched")
	assert_true(_inv.release_all_reservations(lot).ok, "releasing the claim first")
	assert_true(_inv.transform_lot_item(lot, ITEM_GRAIN, 4000).ok, "then lets it through")


func test_a_transformation_refuses_an_unknown_item_the_same_item_and_an_empty_quantity() -> void:
	"""Every precondition refuses explicitly; none of them clamps into a plausible success."""
	var box: Vector2i = _container()
	var lot: Vector2i = _lot(box, ITEM_MEAL, 2000)
	assert_equal(_inv.transform_lot_item(lot, 200, 4000).error,
		InventoryScript.REFUSE_UNKNOWN_ITEM, "an unregistered item id refuses")
	assert_equal(_inv.transform_lot_item(lot, ITEM_MEAL, 4000).error,
		InventoryScript.REFUSE_SAME_ITEM, "a conversion into the same item is not a conversion")
	assert_equal(_inv.transform_lot_item(lot, ITEM_GRAIN, 0).error,
		InventoryScript.REFUSE_INVALID_QUANTITY, "and an empty result refuses")
	assert_equal(_inv.lot_item_id(lot), ITEM_MEAL, "after all three the row is unchanged")
	assert_equal(_inv.lot_quantity_milli(lot), 2000, "at its original quantity")


func test_a_transformation_that_would_overflow_the_container_refuses_and_changes_nothing() -> void:
	"""BAL-SAFE-002 is charged on the conversion too; nothing is clamped to fit."""
	var box: Vector2i = _container(1000)
	var lot: Vector2i = _lot(box, ITEM_GRAIN, 4000)
	assert_equal(_inv.container_used_mass_g(box), 1000, "the container is exactly full")
	var refused: InventoryScript.OpResult = _inv.transform_lot_item(lot, ITEM_WOOD, 4000)
	assert_false(refused.ok, "20000 g of wood does not fit a 1000 g store")
	assert_equal(refused.error, InventoryScript.REFUSE_CAPACITY_EXCEEDED, "and says so")
	assert_equal(_inv.lot_item_id(lot), ITEM_GRAIN, "the lot is still grain")
	assert_equal(_inv.container_used_mass_g(box), 1000, "at the mass it already charged")


func test_neither_mutator_will_touch_an_equipped_lot() -> void:
	"""An equipped lot is in no store: §5.8 gives it no factor and no container to charge."""
	var authority: StubAuthority = StubAuthority.new()
	var box: Vector2i = _container()
	var lot: Vector2i = _equip_fixture(authority, box)
	var aged: InventoryScript.OpResult = _inv.advance_lot_age_hour(lot, 1000, 1000)
	assert_false(aged.ok, "aging an equipped lot refuses")
	assert_equal(aged.error, InventoryScript.REFUSE_LOT_EQUIPPED, "and is named")
	var changed: InventoryScript.OpResult = _inv.transform_lot_item(lot, ITEM_GRAIN, 1000)
	assert_false(changed.ok, "and so does converting one")
	assert_equal(changed.error, InventoryScript.REFUSE_LOT_EQUIPPED, "with the same reason")
	assert_equal(_inv.lot_item_id(lot), ITEM_TOOL, "the equipped lot is untouched")
