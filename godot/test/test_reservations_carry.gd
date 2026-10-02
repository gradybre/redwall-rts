extends "res://test/framework/test_case.gd"
## Suite for the reservation pool's carry doors (task 06.4 H1, decision 1022): `carry_claim()`,
## `load_claim_into_new_satchel()`, `deliver_claim()` and `repurpose_claim()`.
##
## The pool's invariant -- `lot.reserved_milli == sum(rows on the lot) <= quantity` -- is the
## oracle after every success, and byte-identity of both stores after every refusal.

const HaulWorld := preload("res://test/fixtures/haul_world.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SOURCE: int = ReservationsScript.PURPOSE_HAUL_SOURCE
const CARRIED: int = ReservationsScript.PURPOSE_HAUL_DESTINATION
const JOB: Vector2i = Vector2i(2, 1)
const OTHER_JOB: Vector2i = Vector2i(3, 1)
const STONE: int = HaulWorld.ITEM_STONE

var _w: HaulWorld = null
var _owner: Vector2i = Vector2i(-1, 0)
var _a: Vector2i = Vector2i(-1, 0)
var _b: Vector2i = Vector2i(-1, 0)
var _stones: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""Two stores of one building; 10 stone in the first, 4 of them claimed by JOB."""
	_w = HaulWorld.new()
	_owner = _w.place_active("open_stockpile", 40, 40)
	_a = _w.store(_owner, 400000, HaulWorld.tile(40, 40))
	_b = _w.store(_owner, 400000, HaulWorld.tile(41, 40))
	_stones = _w.lot(_a, STONE, 10000)
	assert_true(_w.claim(JOB, _stones, SOURCE, 4000, 77), "the claim")


func test_carrying_a_part_moves_it_and_keeps_it_claimed_with_its_lease() -> void:
	"""4 of 10 move to B; the row follows them under the carried purpose and expiry 77."""
	var carried: InventoryScript.OpResult = _w.pool.carry_claim(JOB, _stones, SOURCE, _b, CARRIED,
		_w.inventory)
	assert_true(carried.ok, "carried: %s" % carried.error)
	assert_equal(_w.inventory.lot_container(carried.ref), _b, "in B")
	assert_equal(_w.inventory.lot_quantity_milli(_stones), 6000, "6 stayed")
	assert_equal(_w.inventory.lot_reserved_milli(_stones), 0, "unreserved where it was")
	assert_equal(_w.pool.claim_quantity_milli(JOB, carried.ref, CARRIED), 4000, "claimed where it is")
	var expiry: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_w.pool.claim_expiry_into(JOB, carried.ref, CARRIED, expiry), "a lease")
	assert_equal(expiry.value, 77, "the same lease")
	assert_equal(_w.pool.active_row_count(), 1, "one row, not two")
	assert_true(_w.audits_pass(), "the invariant holds")


func test_carrying_a_whole_lot_keeps_its_identity() -> void:
	"""A claim on the entire lot moves the lot itself, row and all."""
	var whole: Vector2i = _w.lot(_a, HaulWorld.ITEM_GRAIN, 3000)
	assert_true(_w.claim(JOB, whole, SOURCE, 3000), "claimed whole")
	var carried: InventoryScript.OpResult = _w.pool.carry_claim(JOB, whole, SOURCE, _b, CARRIED,
		_w.inventory)
	assert_equal(carried.ref, whole, "same lot")
	assert_equal(_w.inventory.lot_container(whole), _b, "now in B")
	assert_true(_w.pool.has_claim(JOB, whole, CARRIED), "re-keyed")
	assert_false(_w.pool.has_claim(JOB, whole, SOURCE), "not twice")
	assert_true(_w.audits_pass(), "the invariant holds")


func test_carry_refusals_change_neither_store() -> void:
	"""No claim, an open transaction, a bad purpose, and Inventory's own refusal."""
	var small: Vector2i = _w.store(_owner, 1000, HaulWorld.tile(42, 40))
	var before: PackedByteArray = _w.state()
	assert_equal(_w.pool.carry_claim(OTHER_JOB, _stones, SOURCE, _b, CARRIED, _w.inventory).error,
		ReservationsScript.REFUSE_NO_SUCH_CLAIM, "no claim")
	assert_equal(_w.pool.carry_claim(JOB, _stones, SOURCE, _b, 1 << 40, _w.inventory).error,
		ReservationsScript.REFUSE_INVALID_PURPOSE, "purpose out of int32")
	assert_equal(_w.pool.carry_claim(JOB, _stones, SOURCE, _b, CARRIED, null).error,
		ReservationsScript.REFUSE_NO_INVENTORY, "no inventory")
	assert_equal(_w.pool.carry_claim(JOB, _stones, SOURCE, small, CARRIED, _w.inventory).error,
		InventoryScript.REFUSE_CAPACITY_EXCEEDED, "no room")
	_w.inventory.begin()
	assert_equal(_w.pool.carry_claim(JOB, _stones, SOURCE, _b, CARRIED, _w.inventory).error,
		ReservationsScript.REFUSE_INVENTORY_TRANSACTION_OPEN, "an open transaction")
	_w.inventory.abort()
	assert_equal(_w.state(), before, "byte-identical")


func test_a_satchel_minted_by_a_refused_load_is_rolled_back() -> void:
	"""The load's satchel lives in the move's transaction: a refusal leaves none behind."""
	var tight: HaulWorld = HaulWorld.new(64, 1)
	var owner: Vector2i = tight.place_active("open_stockpile", 40, 40)
	var stones: Vector2i = tight.lot(tight.store(owner, 400000, HaulWorld.tile(40, 40)), STONE, 9000)
	assert_true(tight.claim(JOB, stones, SOURCE, 1000), "a part")
	var before: PackedByteArray = tight.state()
	var loaded: InventoryScript.OpResult = tight.pool.load_claim_into_new_satchel(JOB, stones,
		SOURCE, owner, 12000, CARRIED, tight.inventory)
	assert_equal(loaded.error, InventoryScript.REFUSE_CAPACITY_INVENTORY_LOT, "no lot row for the part")
	assert_equal(tight.state(), before, "byte-identical, no satchel")
	assert_equal(tight.pool.load_claim_into_new_satchel(JOB, stones, SOURCE, Vector2i(-1, 0), 12000,
		CARRIED, tight.inventory).error, InventoryScript.REFUSE_INVALID_OWNER_REF, "a bad owner")


func test_delivering_ends_the_claim_and_releases_the_reserved_room() -> void:
	"""Deliver to B with 4000 g reserved there: the goods arrive free and the room is released."""
	assert_true(_w.inventory.reserve_container_mass(_b, 4000).ok, "room held")
	var delivered: InventoryScript.OpResult = _w.pool.deliver_claim(JOB, _stones, SOURCE, _b, 4000,
		_w.inventory)
	assert_true(delivered.ok, "delivered: %s" % delivered.error)
	assert_equal(_w.inventory.lot_reserved_milli(delivered.ref), 0, "free on arrival")
	assert_equal(_w.inventory.container_reserved_mass_g(_b), 0, "room released")
	assert_equal(_w.pool.active_row_count(), 0, "no row")
	assert_true(_w.audits_pass(), "the invariant holds")


func test_deliver_refuses_a_negative_release_and_more_than_was_reserved() -> void:
	"""A negative release is the caller's error; releasing unheld room is Inventory's refusal."""
	var before: PackedByteArray = _w.state()
	assert_equal(_w.pool.deliver_claim(JOB, _stones, SOURCE, _b, -1, _w.inventory).error,
		ReservationsScript.REFUSE_INVALID_QUANTITY, "negative")
	assert_equal(_w.pool.deliver_claim(JOB, _stones, SOURCE, _b, 1, _w.inventory).error,
		InventoryScript.REFUSE_INSUFFICIENT_RESERVED, "nothing was held")
	assert_equal(_w.state(), before, "byte-identical")


func test_a_delivery_that_empties_a_satchel_destroys_it() -> void:
	"""'Destroyed when empty': the satchel goes in the same transaction as its last lot."""
	var loaded: InventoryScript.OpResult = _w.pool.load_claim_into_new_satchel(JOB, _stones, SOURCE,
		_owner, 12000, CARRIED, _w.inventory)
	var satchel: Vector2i = _w.inventory.lot_container(loaded.ref)
	assert_true(_w.inventory.is_satchel(satchel), "loaded into a satchel")
	assert_true(_w.pool.deliver_claim(JOB, loaded.ref, CARRIED, _b, 0, _w.inventory).ok, "delivered")
	assert_false(_w.inventory.is_container_valid(satchel), "destroyed")
	assert_true(_w.audits_pass(), "audits pass")


func test_a_partial_delivery_leaves_the_store_alone() -> void:
	"""Delivering part of a lot from an ordinary store neither empties nor destroys it."""
	assert_true(_w.pool.deliver_claim(JOB, _stones, SOURCE, _b, 0, _w.inventory).ok, "delivered")
	assert_true(_w.inventory.is_container_valid(_a), "the store stays")
	assert_equal(_w.inventory.lot_quantity_milli(_stones), 6000, "with the rest")


func test_repurposing_re_keys_in_place_and_coalesces() -> void:
	"""Same lot, quantity and lease; a second row of the new purpose merges with the first."""
	assert_true(_w.pool.repurpose_claim(JOB, _stones, SOURCE, CARRIED).ok, "re-keyed")
	assert_equal(_w.pool.claim_quantity_milli(JOB, _stones, CARRIED), 4000, "same quantity")
	var expiry: IntMath.IntResult = IntMath.IntResult.new()
	_w.pool.claim_expiry_into(JOB, _stones, CARRIED, expiry)
	assert_equal(expiry.value, 77, "same lease")
	assert_true(_w.claim(JOB, _stones, SOURCE, 1000, 90), "another source claim")
	assert_true(_w.pool.repurpose_claim(JOB, _stones, SOURCE, CARRIED).ok, "coalesced")
	assert_equal(_w.pool.claim_quantity_milli(JOB, _stones, CARRIED), 5000, "one row of 5")
	_w.pool.claim_expiry_into(JOB, _stones, CARRIED, expiry)
	assert_equal(expiry.value, 90, "the later lease wins on coalescing")
	assert_equal(_w.pool.active_row_count(), 1, "one row")
	assert_equal(_w.pool.repurpose_claim(JOB, _stones, SOURCE, CARRIED).error,
		ReservationsScript.REFUSE_NO_SUCH_CLAIM, "nothing left to re-key")
	assert_equal(_w.pool.repurpose_claim(JOB, _stones, CARRIED, -(1 << 40)).error,
		ReservationsScript.REFUSE_INVALID_PURPOSE, "out of int32")
	assert_true(_w.audits_pass(), "the invariant holds")


func test_a_stale_row_on_the_arriving_slot_aborts_the_carry() -> void:
	"""A retired lot's undropped rows block its slot's next lot: the carry aborts cleanly."""
	var doomed: Vector2i = _w.lot(_a, HaulWorld.ITEM_GRAIN, 1000)
	assert_true(_w.claim(OTHER_JOB, doomed, SOURCE, 1000), "claimed")
	assert_true(_w.inventory.consume_reserved(doomed, 1000).ok, "consumed to zero: the lot retires")
	var before: PackedByteArray = _w.state()
	var carried: InventoryScript.OpResult = _w.pool.carry_claim(JOB, _stones, SOURCE, _b, CARRIED,
		_w.inventory)
	assert_equal(carried.error, ReservationsScript.REFUSE_LOT_GENERATION_CONFLICT,
		"the arriving lot reuses the stale slot")
	assert_equal(_w.state(), before, "byte-identical")
