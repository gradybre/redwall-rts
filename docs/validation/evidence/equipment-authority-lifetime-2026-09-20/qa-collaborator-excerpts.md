# Equipment lifetime test author: immutable collaborator excerpts

Exact source excerpts, not substitute implementations. Full-file hashes bind each extraction.

## godot/test/test_inventory.gd
Full SHA256: d8728e970d3aaf4aa4eeae25a42c483fd502aaa3574576122488ea3a38b3de02

Lines 1-125:
```gdscript
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
## STOCK-SEED-R01 end-to-end only. Most of the seed-guard suite drives a stand-in authority,
## because enforcement here must not depend on what a seed is; these three run the real
## predicate, the real catalog and the real hourly pass over it.
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## `docs/gameplay_balance.md`'s item table, transcribed: seed_grain is 100 g/U with a 1440-hour
## shelf life, and GDD §5.8 expires a lot at `shelf_hours * 1000` milli-hours.
const SEED_SHELF_MILLI: int = 1440 * 1000
## Day 3, hour 9 under ARCH-TICK-002's offset calendar -- an ordinary hour crossing in spring.
## `(d-1)*18000 + h*750 - 4500`, the inverse of `(tick + 4500) mod 18000`.
const EXPIRY_HOUR_TICK: int = 2 * SimClockScript.TICKS_PER_DAY \
	+ 9 * SimClockScript.TICKS_PER_HOUR - SimClockScript.CALENDAR_OFFSET_TICKS

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
## PROV-R01 (decision 0113) CLOSED the provenance domain. These were both arbitrary in-range
## int32 stand-ins until 2026-09-12; provenance is now one of exactly six published members and
## an arbitrary value is refused, so the fixtures below name members. Container policy is still
## genuinely opaque -- no ruling has closed it -- so TEST_POLICY remains an arbitrary value.
##
## Transcribed from the ruling table rather than read out of catalog.gd, so a renumbering there
## fails here instead of being followed.
const PROV_ORDINARY: int = 0
const PROV_STARTER: int = 1
const PROV_COASTAL_BRINE: int = 2
const PROV_EXCAVATION: int = 3
const PROV_BACKFILL_RECLAIM: int = 4
const PROV_SPOIL_RECLAIM: int = 5
## The six members as a list, for the tests that must cover every one.
const PROVENANCE_MEMBERS: Array[int] = [0, 1, 2, 3, 4, 5]
## Values that fit an int32 perfectly and still name no origin.
const NON_MEMBER_PROVENANCE: Array[int] = [-1, 6, 7, 42, 2147483647, -2147483648]
const TEST_PROVENANCE: int = PROV_EXCAVATION
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
```

Lines 1170-1645:
```gdscript
		assert_true(_inv.state_bytes() == before, "the refused %d wrote nothing" % value)
	assert_equal(_inv.live_lot_count(), 0, "no row was stored for any of them")


func test_provenance_is_compared_for_equality_across_the_whole_domain() -> void:
	"""Merging requires identical attributes INCLUDING provenance: every unequal pair refuses."""
	var container: Vector2i = _container()
	var rows: Array[Vector2i] = []
	for member: int in PROVENANCE_MEMBERS:
		rows.append(_lot(container, ITEM_GRAIN, 1000, 0, member))
	for i: int in PROVENANCE_MEMBERS.size():
		for j: int in PROVENANCE_MEMBERS.size():
			if i == j:
				continue
			var refused: InventoryScript.OpResult = _inv.merge_lots(rows[i], rows[j])
			assert_false(refused.ok, "%d and %d are different origins" % [i, j])
			assert_equal(refused.error, InventoryScript.REFUSE_ATTRIBUTE_MISMATCH,
				"the refusal names the attribute mismatch for %d vs %d" % [i, j])
	var twin: Vector2i = _lot(container, ITEM_GRAIN, 1000, 0, PROV_COASTAL_BRINE)
	assert_true(_inv.merge_lots(rows[PROV_COASTAL_BRINE], twin).ok, "equal origins merge")
	assert_equal(_inv.lot_provenance(rows[PROV_COASTAL_BRINE]), PROV_COASTAL_BRINE,
		"and the merged lot keeps the member verbatim")


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
	var lot: Vector2i = _inv.create_lot(box, ITEM_TOOL, 1000, 4, PROV_STARTER, 9, 12345, 678).ref
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "detach")
	assert_true(_inv.is_lot_valid(lot), "the very same reference is still valid while equipped")
	assert_equal(_inv.lot_container(lot), InventoryScript.NULL_REF, "its container is the null ref")
	authority.withdraw(lot)
	assert_true(_inv.attach_equipped_lot(lot, box, false).ok, "attach")
	assert_equal(_inv.lot_quantity_milli(lot), 1000, "quantity is unchanged")
	assert_equal(_inv.lot_quality(lot), 4, "quality is unchanged")
	assert_equal(_inv.lot_provenance(lot), PROV_STARTER, "provenance is unchanged")
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
```

## godot/scripts/core/gear.gd
Full SHA256: 73da2f20963c40747790efb8484cec451698c8ebf12a289db1e1307025a5ac8f

Lines 700-920:
```gdscript
	_write_new_row(row, lot_ref, compiled_item_id, out.value, manufacture)
	if not _publish_row(row):
		_return_unpublished_row(row)
		return _refuse(REFUSE_ROW_NOT_INITIALISED)
	return _ok(lot_ref, out.value)


func _check_create(inventory: Inventory, definitions: ItemDefinitions, lot_ref: Vector2i,
		manufacture: int) -> StringName:
	"""Validate a create_gear() call completely before a single byte is written."""
	if inventory == null:
		return REFUSE_NO_INVENTORY
	if inventory.is_transaction_open():
		# A gear row written against an uncommitted lot would survive a rollback that erases the
		# lot, leaving an instance pointing at a reference that never existed. Refuse instead.
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	if lot_ref.x < 0 or lot_ref.x >= LOT_CAPACITY:
		return REFUSE_LOT_OUT_OF_RANGE
	if not inventory.is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	var preflight: Inventory.OpResult = preflight_create(definitions,
		inventory.lot_item_id(lot_ref), manufacture)
	if not preflight.ok:
		return preflight.error
	if inventory.lot_quantity_milli(lot_ref) != GEAR_LOT_QUANTITY_MILLI:
		return REFUSE_LOT_NOT_INDIVISIBLE
	return _check_lot_slot_free(lot_ref)


func _check_lot_slot_free(lot_ref: Vector2i) -> StringName:
	"""Refuse when this lot slot already carries a gear record, live or stale.

	A stale record -- same slot, older generation -- means a previous lot retired without its
	instance being destroyed. Refusing here forces the caller to clean it up explicitly rather
	than letting two rows quietly share one lot slot.
	"""
	var existing: int = _resolve_row_by_lot_slot(lot_ref.x)
	if existing == NULL_ROW:
		return REFUSE_NONE
	if _lot_generation[existing] == lot_ref.y:
		return REFUSE_GEAR_ALREADY_EXISTS
	return REFUSE_GEAR_STALE_RECORD


func _write_new_row(row: int, lot_ref: Vector2i, compiled_item_id: int, cap: int,
		manufacture: int) -> void:
	"""Write EVERY field of a freshly taken row. Runs strictly before `_publish_row()`."""
	_lot_slot[row] = lot_ref.x
	_lot_generation[row] = lot_ref.y
	_item_id[row] = compiled_item_id
	_durability[row] = cap
	_durability_cap[row] = cap
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	_manufacture_recipe[row] = manufacture
	_equipped[row] = 0
	_claim_job_slot[row] = NULL_SLOT
	_claim_job_generation[row] = NULL_GENERATION


func _publish_row(row: int) -> bool:
	"""Publish a fully initialised row, or refuse to publish it at all.

	The ruling requires every field to be initialised BEFORE occupancy is published. That order is
	enforced here rather than merely followed: publishing a row whose identity columns are still
	blank would make a half-written row visible to `_resolve_row()`, so this checks and returns
	false instead. A caller that gets false must return the row unpublished; there is no path that
	leaves an unpublished row marked occupied.
	"""
	if _item_id[row] < 0 or _lot_slot[row] == NULL_SLOT or _lot_generation[row] <= NULL_GENERATION:
		return false
	_occupied[row] = 1
	_active_count += 1
	return true


func _return_unpublished_row(row: int) -> void:
	"""Blank and re-heap a row that was taken but never published, leaving the live count alone."""
	_blank_row(row)
	_push_free(row)
	_free_count += 1


func destroy_gear(inventory: Inventory, definitions: ItemDefinitions,
		lot_ref: Vector2i) -> Inventory.OpResult:
	"""Destroy the gear record of a lot that has already retired. `.value` is 1 on success.

	Gear records die with their lot: while the lot is still live this refuses LOT_STILL_LIVE, so
	the call cannot be used to strip durability off a piece of gear somebody is still holding.
	A claimed record refuses too -- releasing a Job's claim is that Job's business.
	`definitions` is accepted for signature symmetry with the rest of the store and is not read.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if inventory.is_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if inventory.is_lot_valid(lot_ref):
		return _refuse(REFUSE_LOT_STILL_LIVE)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	_free_row(row)
	return _ok(lot_ref, 1)


# --- Ownership --------------------------------------------------------------------------------

func set_owner(directory: EntityDirectory, lot_ref: Vector2i,
		owner_ref: Vector2i) -> Inventory.OpResult:
	"""Bind a gear instance to a live resident. Refused while the gear is claimed.

	§5.4's "worker owns net while trap/weir/boat owns installed gear" needs two owner kinds, and
	only the resident half is settled: the installed-owner discriminator belongs to the
	expedition/installed-gear contract (named next increment 2), so a non-resident reference is
	refused OWNER_KIND_UNSUPPORTED rather than guessed at. This changes no inventory container:
	the equipped-lot amendment is a separate increment.
	"""
	if directory == null:
		return _refuse(REFUSE_NO_DIRECTORY)
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		# The owner of an equipped record is what `inventory.gd` validates its null container
		# against. Re-pointing it here would strand that lot; `unequip()` is the way out.
		return _refuse(REFUSE_GEAR_EQUIPPED)
	if not directory.is_valid(owner_ref):
		return _refuse(REFUSE_INVALID_OWNER)
	if not directory.is_valid_of_kind(owner_ref, EntityDirectory.KIND_RESIDENT):
		return _refuse(REFUSE_OWNER_KIND_UNSUPPORTED)
	_owner_slot[row] = owner_ref.x
	_owner_generation[row] = owner_ref.y
	return _ok(lot_ref, 1)


func clear_owner(lot_ref: Vector2i) -> Inventory.OpResult:
	"""Return a gear instance to unowned stock. Refused while claimed, and while equipped."""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_GEAR)
	if _claim_job_slot[row] != NULL_SLOT:
		return _refuse(REFUSE_GEAR_CLAIMED)
	if _equipped[row] == 1:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	_owner_slot[row] = NULL_SLOT
	_owner_generation[row] = NULL_GENERATION
	return _ok(lot_ref, 1)


func owner_of(lot_ref: Vector2i) -> Vector2i:
	"""The recorded owner EntityRef, or NULL_REF when the gear is unowned or unknown.

	NULL_REF here is the GDD's own null reference, not a failure code: `has_gear()` distinguishes
	"no such gear" from "gear with no owner".
	"""
	var row: int = _resolve_row(lot_ref)
	if row == NULL_ROW:
		return NULL_REF
	return Vector2i(_owner_slot[row], _owner_generation[row])


func has_live_owner(directory: EntityDirectory, lot_ref: Vector2i) -> bool:
	"""True when the gear's recorded owner reference still resolves in the directory.

	A stale owner handle -- a resident who has died and whose slot was reused -- fails here,
	because the recorded generation no longer matches the directory's.
	"""
	if directory == null:
		return false
	var recorded: Vector2i = owner_of(lot_ref)
	if recorded == NULL_REF:
		return false
	return directory.is_valid(recorded)


# --- Equipped gear (ruling §4; READY_07 §7.2 step 5; decision 0061) ---------------------------

func bind_equipment(inventory: Inventory, directory: EntityDirectory,
		residents: Residents) -> Inventory.OpResult:
	"""Wire the three stores an equip needs, and register this store as inventory's authority.

	Refused while any row is equipped: the bindings are what `is_equipped_record()` answers from,
	so swapping them under a live equipped record would change the answer to a proof
	`inventory.gd` has already accepted. `.value` is the equipped-row count.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if directory == null:
		return _refuse(REFUSE_NO_DIRECTORY)
	if residents == null:
		return _refuse(REFUSE_NO_RESIDENTS)
	if _equipped_count > 0:
		return _refuse(REFUSE_GEAR_EQUIPPED)
	var registered: Inventory.OpResult = inventory.set_equipment_authority(self)
	if not registered.ok:
		return registered
	_inventory = inventory
	_directory_binding = directory
	_residents = residents
	return _ok(NULL_REF, _equipped_count)


func is_equipment_bound() -> bool:
	"""True when all three equip collaborators are wired."""
	return _inventory != null and _directory_binding != null and _residents != null


func equipped_count() -> int:
	"""Number of live gear rows currently equipped by a resident."""
	return _equipped_count


func is_equipped_record(lot_ref: Vector2i) -> bool:
	"""THE PROOF `inventory.gd` demands before it will let a lot carry a null container.

```

## godot/test/test_gear.gd
Full SHA256: a65de86810092f58c43cb5c3c957eaf3a66d13048e836cf1c597778dfbdef146

Lines 1-125:
```gdscript
extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/gear.gd` — the GearInstance store and its lowest-free-row allocator.
##
## Every acceptance item ruling §4 names is a test below, under its own name:
##   * allocation reaches row 16383 (`test_allocates_through_slot_16383`);
##   * a full pool refuses atomically, before anything is consumed
##     (`test_full_pool_creation_refuses_atomically`);
##   * the lowest freed row is reused deterministically
##     (`test_lowest_freed_row_is_reused_deterministically`);
##   * stale lot, owner and job handles fail (`test_stale_*_handle_fails`);
##   * two Jobs cannot claim one gear object (`test_two_jobs_cannot_claim_one_gear_object`);
##   * exact wear starts and one below refuses (`test_exact_wear_starts_and_one_below_refuses`);
##   * repeated completion and cancellation cannot double-debit or double-release;
##   * repair clamps to the correct cap, per wear model, and is not a reset.
##
## Two structural cases go beyond the list because the ruling's wording depends on them:
## `test_eligibility_predicate_is_not_the_gear_category` pins `candle` -- category GEAR, NOT
## instance-required -- as the counter-example that makes the broad category test wrong, and
## `test_no_row_is_published_before_it_is_initialised` walks the private columns to prove that a
## live row is never half-written and a freed row is never half-blanked.
##
## Where a test must observe the ALLOCATOR rather than the gear, it reads the store's private
## columns through `get()`, exactly as `test_reservations.gd` does. That is deliberate: the row
## index is not part of the public surface -- no raw gear-row index may escape as a durable
## handle -- so the only honest way to assert which row was reused is to look at the column.
##
## Item ids and masses come from the real compiled catalog through `item_definitions.gd`, never
## from a hand-written second copy of §3.1.

const GearScript := preload("res://scripts/core/gear.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const CONTAINER_OWNER: Vector2i = Vector2i(7, 1)
const BIG_MASS: int = 9000000000
const TEST_PROVENANCE: int = 3
const TEST_POLICY: int = 0
const SMALL_POOL: int = 64
## GDD §5.7, restated: "tool 1000g". The mass an equipped tool stops charging its container.
const TOOL_MASS_G: int = 1000

## Job references. Job liveness lives in the Job store, which `gear.gd` deliberately does not
## depend on, so these are plain in-range `(slot, generation)` pairs.
const JOB_A: Vector2i = Vector2i(3, 1)
const JOB_B: Vector2i = Vector2i(9, 2)
## Same slot as JOB_A, later generation: the stale-handle case.
const JOB_A_STALE: Vector2i = Vector2i(3, 2)

var _inv: InventoryScript = null
var _defs: ItemDefinitionsScript = null
var _store: GearScript = null
var _container: Vector2i = Vector2i(-1, 0)
var _out: IntMathScript.IntResult = null
var _wear: GearScript.WearOutcome = null
## Built only by the equipped-gear tests below; every other test leaves it null.
var _residents: ResidentsScript = null


func before_each() -> void:
	"""Build a small inventory with the real catalog loaded and a 64-row gear store."""
	_inv = InventoryScript.new(8, 256)
	_defs = ItemDefinitionsScript.new()
	var loaded: ItemDefinitionsScript.LoadResult = _defs.load_default(_inv)
	assert_true(loaded.ok, "the real item catalog must load: %s" % loaded.error)
	_store = GearScript.new(SMALL_POOL)
	_container = _inv.create_container(CONTAINER_OWNER, BIG_MASS,
		InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref
	_out = IntMathScript.IntResult.new()
	_wear = GearScript.WearOutcome.new()
	_residents = null


func _id(key: StringName) -> int:
	"""Compiled catalog id of an item key."""
	return _defs.compiled_id(key)


func _lot(key: StringName, quantity_milli: int = GearScript.GEAR_LOT_QUANTITY_MILLI) -> Vector2i:
	"""Create one indivisible lot of `key` in the shared container."""
	return _inv.create_lot(_container, _id(key), quantity_milli, 0, TEST_PROVENANCE, 0, 0, 0).ref


func _gear(key: StringName,
		manufacture: int = GearScript.MANUFACTURE_BASIC) -> Vector2i:
	"""Create a lot of `key` and its gear instance; return the lot reference."""
	var lot_ref: Vector2i = _lot(key)
	var made: InventoryScript.OpResult = _store.create_gear(_inv, _defs, lot_ref, manufacture)
	assert_true(made.ok, "creating %s gear must succeed: %s" % [key, made.error])
	return lot_ref


func _durability(lot_ref: Vector2i) -> int:
	"""Current durability of a gear instance, asserting the read itself succeeded."""
	assert_true(_store.durability_into(lot_ref, _out), "durability must be readable")
	return _out.value


func _run_cycle(lot_ref: Vector2i, job_ref: Vector2i) -> int:
	"""Claim, complete one fishing cycle, and return the wear that was applied."""
	var claimed: InventoryScript.OpResult = _store.claim_for_job(lot_ref, job_ref)
	assert_true(claimed.ok, "cycle claim must succeed: %s" % claimed.error)
	var done: InventoryScript.OpResult = _store.complete_cycle(lot_ref, job_ref)
	assert_true(done.ok, "cycle completion must succeed: %s" % done.error)
	return done.value


func _retire_lot(lot_ref: Vector2i) -> void:
	"""Consume a lot to zero so its slot retires and its generation advances."""
	var sunk: InventoryScript.OpResult = _inv.sink_lot_quantity(lot_ref,
		_inv.lot_quantity_milli(lot_ref))
	assert_true(sunk.ok, "sinking a lot to zero must succeed: %s" % sunk.error)
	assert_false(_inv.is_lot_valid(lot_ref), "a fully consumed lot must retire")


# --- Budget ------------------------------------------------------------------------------------

func test_allocator_and_claim_bytes_match_the_ruling() -> void:
	"""The three ledger figures are re-derived from the columns actually allocated."""
	var full: GearScript = GearScript.new()
	assert_equal(full.allocator_bytes(), GearScript.BUDGET_ALLOCATOR_BYTES,
		"allocator payload must be 81924 bytes")
	assert_equal(full.claim_bytes(), GearScript.BUDGET_CLAIM_BYTES,
```
