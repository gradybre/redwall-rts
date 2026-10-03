extends "res://test/framework/test_case.gd"
## Real Inventory/Reservations transactions for paid physical excavation, decision 1056.

const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const JOB: Vector2i = Vector2i(3, 1)
const INPUT: int = Reservations.PURPOSE_EXCAVATION_INPUT
const OTHER: int = Reservations.PURPOSE_HAUL_SOURCE

class SyntheticPileSite extends RefCounted:
	func ground_pile_tile_refusal(_tile: int) -> StringName:
		"""Synthetic geometry fixture only; actual Inventory pile rules still apply."""
		return &""

	func ground_pile_owner_ref() -> Vector2i:
		"""Return the fixture's stable World owner."""
		return Vector2i(0, 1)

var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF


func before_each() -> void:
	"""Every fixture uses the real compiled material catalog and finite physical containers."""
	_inventory = Inventory.new(16, 64)
	_pool = Reservations.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "authored item catalog loads")
	_store = _inventory.create_container(Vector2i(7, 1), 100000,
		Inventory.FILTERS_ACCEPT_ALL, 0, true).ref
	_output = _inventory.create_container(Vector2i(8, 1), 10000,
		Inventory.FILTERS_ACCEPT_ALL, 0, true).ref


func after_each() -> void:
	"""Release all collaborators so transaction fixtures cannot retain a store graph."""
	_items = null
	_pool = null
	_inventory = null


func _lot(key: StringName, quantity: int, quality: int = 1,
		age: int = 0, remainder: int = 0) -> Vector2i:
	"""Create a real authored material lot with observable source metadata."""
	var created: Inventory.OpResult = _inventory.create_lot(_store, _items.compiled_id(key),
		quantity, quality, Catalog.PROVENANCE_ORDINARY, 23, age, remainder)
	assert_true(created.ok, "material lot creates: %s" % created.error)
	return created.ref


func _claim(lot: Vector2i, quantity: int, purpose: int = INPUT,
		expiry: int = 900, job: Vector2i = JOB) -> void:
	"""Claim through the reservation owner; the fixture never writes Inventory reservations."""
	var batch: PackedInt64Array = PackedInt64Array([lot.x, lot.y, purpose, quantity, expiry])
	assert_true(_pool.claim_batch(job, batch, 1, _inventory).ok, "actual input claim reserves")


func _consume(output: Vector2i = NULL_REF, mass: int = 0, now_tick: int = 100,
		job: Vector2i = JOB) -> Inventory.OpResult:
	"""Exercise the same pool API that moves a paid phase's inputs into WIP."""
	return _pool.consume_job_inputs(job, INPUT, now_tick, output, mass, _inventory)


func _sound() -> void:
	"""Both canonical owners must agree on all remaining quantities and reservations."""
	assert_true(_inventory.audit().ok, "Inventory conservation and finite capacity audit")
	assert_true(_pool.audit(_inventory).ok, "Reservation ownership audit")


func test_input_consumption_and_output_reservation_commit_together() -> void:
	"""One phase consumes only its owned purpose and reserves real finite output mass."""
	var wood: Vector2i = _lot(&"wood", 500, 2, 4321, 19)
	var stone: Vector2i = _lot(&"stone", 250)
	_claim(wood, 250)
	_claim(wood, 100, OTHER)
	_claim(stone, 250)
	var consumed: Inventory.OpResult = _consume(_output, 2000)
	assert_true(consumed.ok, "claimed input/output transaction commits: %s" % consumed.error)
	assert_equal(consumed.value, 2, "exactly two input claim rows retire")
	assert_equal(_inventory.lot_quantity_milli(wood), 250, "only actual wood input consumed")
	assert_equal(_inventory.lot_reserved_milli(wood), 100, "other purpose remains claimed")
	assert_equal(_inventory.lot_quality(wood), 2, "remaining source quality unchanged")
	assert_equal(_inventory.lot_recipe_id(wood), 23, "remaining source recipe unchanged")
	assert_equal(_inventory.lot_age_milli_hours(wood), 4321, "remaining source age unchanged")
	assert_equal(_inventory.lot_age_remainder(wood), 19, "remaining source age remainder unchanged")
	assert_false(_inventory.is_lot_valid(stone), "fully consumed lot identity retires")
	assert_equal(_pool.job_claim_count(JOB), 1, "unrelated claim stays owned")
	assert_equal(_inventory.container_reserved_mass_g(_output), 2000, "real finite output capacity reserved")
	_sound()


func test_input_transaction_capacity_refusal_keeps_all_claims_and_stock() -> void:
	"""An output failure cannot consume inputs or partially free the pool rows."""
	var wood: Vector2i = _lot(&"wood", 250)
	_claim(wood, 250)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var pool_before: PackedByteArray = _pool.state_bytes()
	assert_equal(_consume(_output, 10001).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "finite output refuses")
	assert_equal(_inventory.state_bytes(), inventory_before, "Inventory byte-identical on capacity refusal")
	assert_equal(_pool.state_bytes(), pool_before, "claims byte-identical on capacity refusal")
	_sound()


func test_expired_or_stale_input_owner_never_consumes_other_claims() -> void:
	"""Absolute lease expiry and generation validation are checked before any Inventory write."""
	var wood: Vector2i = _lot(&"wood", 250)
	_claim(wood, 250, INPUT, 100)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var pool_before: PackedByteArray = _pool.state_bytes()
	assert_equal(_consume().error, Reservations.REFUSE_INPUT_CLAIM_EXPIRED, "at expiry is expired")
	assert_equal(_consume(NULL_REF, 0, 99, Vector2i(JOB.x, 2)).error,
		Reservations.REFUSE_JOB_GENERATION_CONFLICT, "reused job slot cannot take previous inputs")
	assert_equal(_inventory.state_bytes(), inventory_before, "expiry/generation refusal preserves inventory")
	assert_equal(_pool.state_bytes(), pool_before, "expiry/generation refusal preserves ownership")
	assert_true(_consume(NULL_REF, 0, 99).ok, "the live claim works before its expiry")
	_sound()


func test_material_free_phase_still_needs_real_output_capacity() -> void:
	"""A cut has no input claims; its pre-work output reservation is still finite and atomic."""
	assert_true(_consume(_output, 2000).ok, "material-free output reserves")
	assert_equal(_inventory.container_reserved_mass_g(_output), 2000, "reservation is owned physical capacity")
	assert_equal(_pool.active_row_count(), 0, "no phantom input rows minted")
	assert_equal(_consume(_output, 0).error, Reservations.REFUSE_INVALID_QUANTITY,
		"a meaningless output pair is rejected rather than silently ignored")
	_sound()


func test_journal_exhaustion_rolls_back_every_consumed_input_and_output_claim() -> void:
	"""A late journal refusal restores retired lot generations, pool links and reserved mass."""
	_inventory = Inventory.new(4, 1400)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "large fragmented fixture catalog loads")
	_store = _inventory.create_container(Vector2i(7, 1), 100000,
		Inventory.FILTERS_ACCEPT_ALL, 0, true).ref
	_output = _inventory.create_container(Vector2i(8, 1), 10000,
		Inventory.FILTERS_ACCEPT_ALL, 0, true).ref
	for index: int in 1200:
		_claim(_lot(&"wood", 1), 1)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var pool_before: PackedByteArray = _pool.state_bytes()
	assert_equal(_consume(_output, 2000).error, Inventory.REFUSE_JOURNAL_FULL, "late journal limit refuses explicitly")
	assert_equal(_inventory.state_bytes(), inventory_before, "all Inventory journal writes roll back")
	assert_equal(_pool.state_bytes(), pool_before, "no claim retires before Inventory commits")
	assert_equal(_pool.job_claim_count(JOB), 1200, "all fragmented claims remain")
	_sound()


func test_consumption_preserves_another_jobs_claim_on_the_same_lot() -> void:
	"""A phase may consume its claim without cancelling another worker's owned stock."""
	var wood: Vector2i = _lot(&"wood", 500)
	var other_job: Vector2i = Vector2i(4, 1)
	_claim(wood, 250)
	_claim(wood, 125, INPUT, 900, other_job)
	assert_true(_consume().ok, "this job's input commits")
	assert_equal(_inventory.lot_quantity_milli(wood), 250, "only the selected job quantity consumed")
	assert_equal(_pool.claim_quantity_milli(other_job, wood, INPUT), 125, "other job still owns its exact claim")
	assert_equal(_inventory.lot_reserved_milli(wood), 125, "Inventory agrees with the surviving owner")
	_sound()


func test_commit_time_empty_ground_pile_refusal_rolls_back_both_owners() -> void:
	"""ARCH-MEM-002's commit-only rejection must undo consumed inputs and output reservation."""
	var site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(site).ok, "explicit synthetic site binds")
	assert_true(_inventory.begin().ok, "pile creation transaction starts")
	var pile: Vector2i = _inventory.create_ground_pile(30).ref
	var lot: Vector2i = _inventory.create_lot(pile, _items.compiled_id(&"wood"),
		250, 1, Catalog.PROVENANCE_ORDINARY, -1, 0, 0).ref
	assert_true(_inventory.commit().ok, "real nonempty finite ground pile commits")
	_claim(lot, 250)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var pool_before: PackedByteArray = _pool.state_bytes()
	assert_equal(_consume(pile, 2000).error, Inventory.REFUSE_GROUND_PILE_EMPTY_WITH_CLAIM,
		"consuming the last lot while retaining output mass fails at commit")
	assert_equal(_inventory.state_bytes(), inventory_before, "commit refusal restores pile, lot, mass and generations")
	assert_equal(_pool.state_bytes(), pool_before, "claim rows still intact after commit refusal")
	_sound()
