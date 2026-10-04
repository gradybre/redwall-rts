extends "res://test/framework/test_case.gd"
## Real Inventory/Reservations transactions for paid physical excavation, decision 1056.

const Inventory := preload("res://scripts/core/inventory.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Funding := preload("res://scripts/core/excavation_inventory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const JOB: Vector2i = Vector2i(3, 1)
const INPUT: int = Reservations.PURPOSE_EXCAVATION_INPUT
const OTHER: int = Reservations.PURPOSE_HAUL_SOURCE

class SyntheticPileSite extends RefCounted:
	var refusal: StringName = &""

	func ground_pile_tile_refusal(_tile: int) -> StringName:
		"""Synthetic geometry fixture only; actual Inventory pile rules still apply."""
		return refusal

	func ground_pile_owner_ref() -> Vector2i:
		"""Return the fixture's stable World owner."""
		return Vector2i(0, 1)

class SyntheticPaidSite extends Contract:
	func is_live_site(site: Vector2i) -> bool:
		"""Explicit synthetic accounting site, never used by production spatial admission."""
		return site == Vector2i(1, 1) or site == Vector2i(2, 1)

	func project_open_refusal(_site: Vector2i, _operation: int) -> StringName:
		"""Only this labeled fixture supplies synthetic physical admission."""
		return &""

	func remaining_work_into(_site: Vector2i, operation: int, out: IntMath.IntResult) -> bool:
		"""The fixture uses the full actual authored operation work."""
		return out.succeed(Contract.work_mwu(operation))

	func attach_project(_site: Vector2i, _operation: int, _project: Vector2i) -> void:
		"""No physical world is published by this accounting-only fixture."""
		pass

	func mutation_refusal(_project: Vector2i, _action: int) -> StringName:
		"""This labeled accounting fixture has no production physical transaction to attest."""
		return &""

	func excavation_inputs_refusal(_project: Vector2i, _job: Vector2i,
			_inventory: RefCounted, _pool: RefCounted) -> StringName:
		"""Accounting-only fixture supplies synthetic scope, never actual world/worker admission."""
		return &""

	func final_input_refusal(_project: Vector2i, _job: Vector2i, _inventory: RefCounted,
			_pool: RefCounted, _output: Vector2i, _mass: int) -> StringName:
		"""Explicit synthetic site proof isolates the real Inventory/WIP transaction in this suite."""
		return &""

var _inventory: Inventory = null
var _pool: Reservations = null
var _items: Items = null
var _store: Vector2i = NULL_REF
var _output: Vector2i = NULL_REF
var _construction: Construction = null
var _paid_site: SyntheticPaidSite = null
var _funding: Funding = null


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
	_funding = null
	_paid_site = null
	_construction = null
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


func _staging(tile: int) -> Vector2i:
	"""Allocate actual bounded material capacity at the fixture's reserved output contact."""
	var made: Inventory.OpResult = _inventory.create_container(Vector2i(0, 1),
		Inventory.GROUND_PILE_MAX_MASS_G, Inventory.FILTERS_ACCEPT_ALL, Inventory.UNSET_POLICY, true)
	assert_true(made.ok, "finite staging container creates")
	assert_true(_inventory.set_container_anchor(made.ref, tile).ok, "staging has a real output anchor")
	assert_true(_inventory.reserve_container_mass(made.ref, 2000).ok, "cut capacity reserved before work")
	return made.ref


func _post_cut_output(container: Vector2i) -> void:
	"""Publish the exact authored fresh cut output inside a caller-owned transaction."""
	assert_true(_inventory.release_container_mass(container, 2000).ok, "owned output reservation released")
	assert_true(_inventory.create_lot(container, _items.compiled_id(&"excavated_earth"),
		2000, 1, Catalog.PROVENANCE_EXCAVATION, -1, 0, 0).ok, "actual finite earth lot created")


func test_first_cut_promotes_same_finite_nonempty_staging_row_atomically() -> void:
	"""Reservation survives work without a phantom pile; cut commit publishes a real pile."""
	var site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(site).ok, "explicit site binds")
	var staging: Vector2i = _staging(30)
	assert_false(_inventory.is_ground_pile(staging), "reserved empty capacity is a material container")
	assert_equal(_inventory.ground_pile_at_tile(30), NULL_REF, "no phantom ground pile published")
	var containers: int = _inventory.live_container_count()
	assert_true(_inventory.begin().ok, "paid cut transaction begins")
	_post_cut_output(staging)
	assert_true(_inventory.promote_to_ground_pile(staging, 30).ok, "the same nonempty container promotes")
	assert_true(_inventory.commit().ok, "cut lot and pile map commit together")
	assert_true(_inventory.is_ground_pile(staging), "actual output now is a ground pile")
	assert_equal(_inventory.ground_pile_at_tile(30), staging, "map keeps the same generation-qualified row")
	assert_equal(_inventory.live_container_count(), containers, "promotion allocates no second container")
	assert_equal(_inventory.container_reserved_mass_g(staging), 0, "claim converted into real goods once")
	assert_equal(_inventory.container_used_mass_g(staging), 2000, "actual earth occupies finite capacity")
	_sound()


func test_promotion_geometry_refusal_rolls_back_cut_lot_and_capacity_release() -> void:
	"""A newly blocked work contact leaves the earned cut ready, with no half-published spoil."""
	var site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(site).ok, "explicit site binds")
	var staging: Vector2i = _staging(30)
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "output retry transaction begins")
	_post_cut_output(staging)
	site.refusal = &"SYNTHETIC_CONTACT_BLOCKED"
	assert_equal(_inventory.promote_to_ground_pile(staging, 30).error, site.refusal, "spatial refusal propagates")
	assert_false(_inventory.commit().ok, "poisoned output transaction cannot commit")
	assert_equal(_inventory.state_bytes(), before, "lot, generation, capacity and map all roll back")
	_sound()


func test_empty_staging_cancellation_releases_capacity_and_retires_only_own_row() -> void:
	"""An abandoned first cut leaves no empty ground pile or stranded staging reservation."""
	var staging: Vector2i = _staging(30)
	var containers: int = _inventory.live_container_count()
	assert_true(_inventory.begin().ok, "cancellation begins")
	assert_true(_inventory.release_container_mass(staging, 2000).ok, "own output claim released")
	assert_true(_inventory.destroy_container(staging).ok, "now-empty staging row retires")
	assert_true(_inventory.commit().ok, "cancellation commits")
	assert_false(_inventory.is_container_valid(staging), "old staging identity no longer live")
	assert_equal(_inventory.live_container_count(), containers - 1, "exactly one allocated row released")
	assert_equal(_inventory.ground_pile_at_tile(30), NULL_REF, "ground-pile map never held the empty row")
	_sound()


func test_promotion_never_admits_an_empty_container_or_implicit_transaction() -> void:
	"""The new path preserves fixed pile capacity and the no-lotless-pile invariant."""
	var site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(site).ok, "explicit site binds")
	var staging: Vector2i = _staging(30)
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "empty promotion transaction begins")
	assert_equal(_inventory.promote_to_ground_pile(staging, 30).error,
		Inventory.REFUSE_GROUND_PILE_STAGING, "empty staging cannot publish a pile")
	_inventory.abort()
	assert_equal(_inventory.state_bytes(), before, "empty promotion preserves all state")
	assert_equal(_inventory.promote_to_ground_pile(staging, 30).error,
		Inventory.REFUSE_GROUND_PILE_NEEDS_TRANSACTION, "promotion always requires explicit atomic composition")
	_sound()


func _paid_phase(operation: int, receipt_capacity: int = 64) -> Vector2i:
	"""Compose real Construction and WIP owners over an explicitly synthetic site authority."""
	_construction = Construction.new()
	_paid_site = SyntheticPaidSite.new()
	assert_true(_construction.bind_excavation_authority(_paid_site).ok, "synthetic authority binds")
	var phase: Vector2i = _construction.open_excavation_phase(Vector2i(1, 1), operation).ref
	assert_true(_construction.set_material_container(phase, _store).ok, "real material container binds")
	_funding = Funding.new(_construction, _inventory, _pool, _items, receipt_capacity)
	return phase


func _brace_inputs(phase: Vector2i) -> void:
	"""A paid brace has both full actual claimed lots and matching Construction delivery rows."""
	_claim(_lot(&"wood", 250, 2, 4321, 19), 250)
	_claim(_lot(&"stone", 250, 3, 2468, 31), 250)
	assert_true(_construction.deliver_material(phase, 0, 250).ok, "real wood delivery records")
	assert_true(_construction.deliver_material(phase, 1, 250).ok, "real stone delivery records")


func test_wip_refund_preserves_every_input_attribute_and_per_item_loss() -> void:
	"""Work-start consumption creates real WIP; cancellation returns aged source metadata."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE)
	_brace_inputs(phase)
	assert_true(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).ok, "actual paid WIP consumes")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 0, "wood no longer loose inventory")
	assert_equal(_funding.wip_milli(phase, _items.compiled_id(&"wood")), 250, "exact wood WIP retained")
	assert_true(_construction.begin_work(phase).ok, "fully consumed phase starts")
	assert_true(_construction.add_work_mwu(phase, 700).ok, "real phase retains partial labor")
	assert_true(_construction.begin_refund(phase).ok, "cancellation freezes phase")
	assert_true(_funding.refund_wip(phase, _output).ok, "exact refunds commit")
	_assert_refunded_metadata(&"wood", 2, 4321, 19)
	_assert_refunded_metadata(&"stone", 3, 2468, 31)
	assert_equal(_funding.cancellation_loss_milli(_items.compiled_id(&"wood")), 50, "wood loss is exactly 20 percent")
	assert_equal(_funding.cancellation_loss_milli(_items.compiled_id(&"stone")), 50, "stone loss is exactly 20 percent")
	assert_false(_funding.is_funded(phase), "committed cancellation empties funding once")
	var before: PackedByteArray = _inventory.state_bytes()
	assert_false(_funding.refund_wip(phase, _output).ok, "second refund has no paid inputs")
	assert_equal(_inventory.state_bytes(), before, "duplicate refund creates nothing")
	_sound()


func _assert_refunded_metadata(key: StringName, quality: int, age: int, remainder: int) -> void:
	"""Inspect real returned lots, not a coordinator counter or receipt claim."""
	var lot: Vector2i = _inventory.container_first_lot(_output)
	while lot != NULL_REF and _inventory.lot_item_id(lot) != _items.compiled_id(key):
		lot = _inventory.container_next_lot(lot)
	assert_true(_inventory.is_lot_valid(lot), "real refund lot exists")
	assert_equal(_inventory.lot_quantity_milli(lot), 200, "actual returned quantity is 200")
	assert_equal(_inventory.lot_quality(lot), quality, "refund preserves source quality")
	assert_equal(_inventory.lot_provenance(lot), Catalog.PROVENANCE_ORDINARY, "refund preserves source provenance")
	assert_equal(_inventory.lot_recipe_id(lot), 23, "refund preserves source recipe")
	assert_equal(_inventory.lot_age_milli_hours(lot), age, "refund preserves source effective age")
	assert_equal(_inventory.lot_age_remainder(lot), remainder, "refund preserves source age remainder")


func test_blocked_refund_retains_wip_and_retry_returns_only_once() -> void:
	"""An output-capacity failure preserves all receipts, losses, Inventory and Construction."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE)
	_brace_inputs(phase)
	assert_true(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).ok, "paid WIP consumes")
	assert_true(_construction.begin_work(phase).ok, "work begins")
	assert_true(_construction.begin_refund(phase).ok, "cancel waits for returned-goods capacity")
	var tiny: Vector2i = _inventory.create_container(Vector2i(9, 1), 1, -1, 0, true).ref
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var funding_before: PackedByteArray = _funding.state_bytes()
	var construction_before: PackedByteArray = _construction.state_bytes()
	assert_equal(_funding.refund_wip(phase, tiny).error, Inventory.REFUSE_CAPACITY_EXCEEDED, "refund output is truly finite")
	assert_equal(_inventory.state_bytes(), inventory_before, "no partial returned lot")
	assert_equal(_funding.state_bytes(), funding_before, "funding/loss remains byte-identical")
	assert_equal(_construction.state_bytes(), construction_before, "earned work and pending cancellation remain")
	assert_true(_funding.refund_wip(phase, _output).ok, "same pending cancellation retries successfully")
	_sound()


func test_claimed_delivery_cannot_be_replaced_by_a_construction_counter() -> void:
	"""Bookkeeping alone never supplies the real input ownership required to consume WIP."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE)
	assert_true(_construction.deliver_material(phase, 0, 250).ok, "fixture counter says wood delivered")
	assert_true(_construction.deliver_material(phase, 1, 250).ok, "fixture counter says stone delivered")
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	assert_equal(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).error,
		Funding.REFUSE_INPUTS, "missing real claims refuse")
	assert_equal(_inventory.state_bytes(), inventory_before, "counter-only delivery changes no stock")
	assert_false(_funding.is_funded(phase), "no free physical funding account")
	_sound()


func test_receipt_capacity_refusal_does_not_truncate_input_metadata() -> void:
	"""An explicitly exhausted receipt budget refuses before either input lot is consumed."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE, 1)
	_brace_inputs(phase)
	var inventory_before: PackedByteArray = _inventory.state_bytes()
	var pool_before: PackedByteArray = _pool.state_bytes()
	assert_equal(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).error,
		Funding.REFUSE_RECEIPTS, "all source metadata must fit before consumption")
	assert_equal(_inventory.state_bytes(), inventory_before, "no input disappeared")
	assert_equal(_pool.state_bytes(), pool_before, "both claims remain intact")
	_sound()


func test_promotion_refuses_wrong_sized_nonempty_staging_without_changing_maps() -> void:
	"""Ordinary smaller storage cannot turn into extra implicit ground-pile capacity."""
	var site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(site).ok, "explicit site binds")
	var container: Vector2i = _inventory.create_container(Vector2i(0, 1), 10000,
		Inventory.FILTERS_ACCEPT_ALL, Inventory.UNSET_POLICY, true).ref
	assert_true(_inventory.set_container_anchor(container, 30).ok, "candidate contact anchors")
	assert_true(_inventory.create_lot(container, _items.compiled_id(&"excavated_earth"),
		2000, 1, Catalog.PROVENANCE_EXCAVATION, -1, 0, 0).ok, "candidate is genuinely nonempty")
	var before: PackedByteArray = _inventory.state_bytes()
	assert_true(_inventory.begin().ok, "promotion transaction opens")
	assert_equal(_inventory.promote_to_ground_pile(container, 30).error,
		Inventory.REFUSE_GROUND_PILE_STAGING, "wrong finite capacity refuses")
	_inventory.abort()
	assert_equal(_inventory.state_bytes(), before, "container, claims and ground map unchanged")
	_sound()


func test_refund_captures_age_after_delivery_and_before_actual_consumption() -> void:
	"""Time passing after reservation must not restore a younger delivered lot on cancellation."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE)
	var wood: Vector2i = _lot(&"wood", 250, 2, 4321, 19)
	var stone: Vector2i = _lot(&"stone", 250, 3, 2468, 31)
	_claim(wood, 250)
	_claim(stone, 250)
	assert_true(_construction.deliver_material(phase, 0, 250).ok, "wood delivered")
	assert_true(_construction.deliver_material(phase, 1, 250).ok, "stone delivered")
	assert_true(_inventory.advance_lot_age_hour(wood, 1001, 601).ok, "wood ages while claimed")
	assert_true(_inventory.advance_lot_age_hour(stone, 1001, 601).ok, "stone ages while claimed")
	assert_true(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).ok, "aged materials become WIP")
	assert_true(_construction.begin_work(phase).ok, "paid work begins")
	assert_true(_construction.begin_refund(phase).ok, "cancellation enters refund")
	assert_true(_funding.refund_wip(phase, _output).ok, "refund returns actual captured ages")
	_assert_refunded_metadata(&"wood", 2, 4922, 620)
	_assert_refunded_metadata(&"stone", 3, 3069, 632)
	_sound()


func test_fragmented_single_milli_inputs_preserve_whole_phase_refund_rounding() -> void:
	"""Five hundred real lots still refund 200 wood and 200 stone, never floor each lot to zero."""
	_inventory = Inventory.new(4, 600)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "fragmented fixture catalog loads")
	_store = _inventory.create_container(Vector2i(7, 1), 100000, -1, 0, true).ref
	_output = _inventory.create_container(Vector2i(8, 1), 10000, -1, 0, true).ref
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE, 500)
	for index: int in 250:
		_claim(_lot(&"wood", 1), 1)
		_claim(_lot(&"stone", 1), 1)
	assert_true(_construction.deliver_material(phase, 0, 250).ok, "all fragmented wood delivered")
	assert_true(_construction.deliver_material(phase, 1, 250).ok, "all fragmented stone delivered")
	assert_true(_funding.consume_to_wip(phase, JOB, 100, NULL_REF).ok, "every actual receipt retained")
	assert_true(_construction.begin_work(phase).ok, "paid work starts")
	assert_true(_construction.begin_refund(phase).ok, "phase cancels")
	assert_true(_funding.refund_wip(phase, _output).ok, "aggregate integer rounding refunds")
	for key: StringName in [&"wood", &"stone"]:
		assert_equal(_inventory.total_live_milli(_items.compiled_id(key)), 200, "exact per-item refund")
		assert_equal(_funding.cancellation_loss_milli(_items.compiled_id(key)), 50, "exact per-item loss")
	_sound()


func _ready_output(phase: Vector2i, operation: int, output: Vector2i, job: Vector2i = JOB) -> void:
	"""Synthetic authority exercises real phase WIP; actual worker composition is tested separately."""
	assert_true(_funding.consume_to_wip(phase, job, 100, output).ok, "actual input/output funding commits")
	assert_true(_construction.begin_work(phase).ok, "funded accounting phase begins")
	assert_true(_construction.add_work_mwu(phase, Contract.work_mwu(operation)).ok, "fixture accounts full adopted work")


func test_material_free_cancellation_needs_no_refund_destination() -> void:
	"""CUT/FINISH and never-opened closure return no goods and require no invented refund storage."""
	for operation: int in [Contract.OP_CUT, Contract.OP_FINISH, Contract.OP_UNOPENED_SUPPORT_CLOSE]:
		var phase: Vector2i = _paid_phase(operation)
		var output: Vector2i = NULL_REF if operation == Contract.OP_FINISH else _output
		assert_true(_funding.consume_to_wip(phase, JOB, 100, output).ok, "material-free actual funding")
		assert_true(_construction.begin_work(phase).ok, "real accounting work starts")
		assert_true(_construction.begin_refund(phase).ok, "phase cancellation freezes")
		assert_true(_funding.refund_wip(phase, NULL_REF).ok, "no returned goods need no destination")
		assert_equal(_inventory.container_reserved_mass_g(_output), 0, "owned output reservation releases")
		assert_false(_funding.is_funded(phase), "empty funding clears exactly once")
	_sound()


func test_material_free_cancel_retires_its_empty_pending_pile_atomically() -> void:
	"""A cut cancelled before output removes its real temporary capacity without minting earth."""
	var phase: Vector2i = _paid_phase(Contract.OP_CUT)
	var staging: Vector2i = _inventory.create_container(Vector2i(0, 1),
		Inventory.GROUND_PILE_MAX_MASS_G, -1, 0, true, 30).ref
	assert_true(_funding.consume_to_wip(phase, JOB, 100, staging).ok, "real cut output reserved")
	assert_true(_construction.begin_work(phase).ok, "cut starts")
	assert_true(_construction.begin_refund(phase).ok, "cut cancels")
	assert_true(_funding.refund_wip(phase, NULL_REF, 30).ok, "empty pending pile removed with output release")
	assert_false(_inventory.is_container_valid(staging), "old staging generation retires")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 0, "no premature output")
	assert_equal(_inventory.ground_pile_at_tile(30), NULL_REF, "no empty ground-pile entry")
	_sound()


func test_output_owner_posts_exact_fresh_or_reclaimed_earth_and_refuses_duplicate() -> void:
	"""Call the actual output coordinator for both source branches, including duplicate retry."""
	for provenance: int in [Catalog.PROVENANCE_EXCAVATION, Catalog.PROVENANCE_BACKFILL_RECLAIM]:
		var phase: Vector2i = _paid_phase(Contract.OP_CUT)
		_ready_output(phase, Contract.OP_CUT, _output)
		assert_true(_funding.commit_outputs(phase, provenance).ok, "real earth output commits")
		var lot: Vector2i = _inventory.container_first_lot(_output)
		assert_equal(_inventory.lot_quantity_milli(lot), 2000, "one exact earth quantity")
		assert_equal(_inventory.lot_provenance(lot), provenance, "actual geological/reclaimed branch")
		assert_equal(_inventory.lot_recipe_id(lot), -1, "earth has no recipe origin")
		assert_equal(_inventory.lot_age_milli_hours(lot), 0, "new output age is zero")
		var before: PackedByteArray = _inventory.state_bytes()
		assert_false(_funding.commit_outputs(phase, provenance).ok, "no second committed source")
		assert_equal(_inventory.state_bytes(), before, "duplicate preserves actual output")
	_sound()


func test_actual_output_promotion_refusal_retains_wip_then_retries_once() -> void:
	"""The real coordinator, not a manually recreated transaction, owns first-cut rollback."""
	var pile_site: SyntheticPileSite = SyntheticPileSite.new()
	assert_true(_inventory.set_ground_pile_authority(pile_site).ok, "real pile owner interface binds")
	var phase: Vector2i = _paid_phase(Contract.OP_CUT)
	var staging: Vector2i = _inventory.create_container(Vector2i(0, 1),
		Inventory.GROUND_PILE_MAX_MASS_G, -1, 0, true, 30).ref
	_ready_output(phase, Contract.OP_CUT, staging)
	pile_site.refusal = &"SYNTHETIC_CONTACT_OCCUPIED"
	var before: PackedByteArray = _inventory.state_bytes()
	var wip_before: PackedByteArray = _funding.state_bytes()
	assert_equal(_funding.commit_outputs(phase, Catalog.PROVENANCE_EXCAVATION, 30).error,
		pile_site.refusal, "real final contact revalidation refuses")
	assert_equal(_inventory.state_bytes(), before, "output/released reservation/pile map roll back")
	assert_equal(_funding.state_bytes(), wip_before, "funding and receipts remain identical")
	pile_site.refusal = &""
	assert_true(_funding.commit_outputs(phase, Catalog.PROVENANCE_EXCAVATION, 30).ok, "same earned output retries")
	assert_equal(_inventory.ground_pile_at_tile(30), staging, "same real container becomes ground pile")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 2000, "exactly one output")
	_sound()


func test_two_phase_output_claims_in_same_container_remain_independently_owned() -> void:
	"""Settling one work-ready cut preserves the other cut's real finite headroom."""
	var first: Vector2i = _paid_phase(Contract.OP_CUT)
	var second: Vector2i = _construction.open_excavation_phase(Vector2i(2, 1), Contract.OP_CUT).ref
	_ready_output(first, Contract.OP_CUT, _output)
	_ready_output(second, Contract.OP_CUT, _output, Vector2i(4, 1))
	assert_equal(_inventory.container_reserved_mass_g(_output), 4000, "two real finite reservations")
	assert_true(_funding.commit_outputs(first, Catalog.PROVENANCE_EXCAVATION).ok, "first exact reservation settles")
	assert_equal(_inventory.container_reserved_mass_g(_output), 2000, "second ownership remains")
	assert_true(_funding.is_funded(second), "other phase remains funded")
	assert_true(_funding.commit_outputs(second, Catalog.PROVENANCE_BACKFILL_RECLAIM).ok, "second independently settles")
	assert_equal(_inventory.container_reserved_mass_g(_output), 0, "only the two owned claims released")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"excavated_earth")), 4000, "two exact committed outputs")
	_sound()


func test_backfill_second_salvage_output_failure_rolls_back_first_and_all_wip() -> void:
	"""A scarce lot row may admit wood but refuse stone; closure must preserve both materials."""
	_inventory = Inventory.new(4, 2)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "small real lot budget binds")
	_store = _inventory.create_container(Vector2i(7, 1), 100000, -1, 0, true).ref
	_output = _inventory.create_container(Vector2i(8, 1), 10000, -1, 0, true).ref
	var phase: Vector2i = _paid_phase(Contract.OP_BACKFILL_CLOSE)
	_claim(_lot(&"excavated_earth", 2000), 2000)
	assert_true(_construction.deliver_material(phase, 0, 2000).ok, "actual backfill input delivered")
	_ready_output(phase, Contract.OP_BACKFILL_CLOSE, _output)
	var obstruction: Vector2i = _lot(&"wood", 1)
	var before: PackedByteArray = _inventory.state_bytes()
	var wip_before: PackedByteArray = _funding.state_bytes()
	assert_equal(_funding.commit_outputs(phase, Catalog.PROVENANCE_ORDINARY).error,
		Inventory.REFUSE_CAPACITY_INVENTORY_LOT, "second actual salvage lot cannot fit")
	assert_equal(_inventory.state_bytes(), before, "first salvage lot and mass release roll back")
	assert_equal(_funding.state_bytes(), wip_before, "paid earth WIP and output claim remain")
	assert_true(_inventory.sink_lot_quantity(obstruction, 1).ok, "other owner frees its real row")
	assert_true(_funding.commit_outputs(phase, Catalog.PROVENANCE_ORDINARY).ok, "same ready closure output retries")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"wood")), 125, "exact half wood salvage")
	assert_equal(_inventory.total_live_milli(_items.compiled_id(&"stone")), 125, "exact half stone salvage")
	_sound()


func test_receipt_configuration_refuses_huge_or_pool_exceeding_budget_before_allocation() -> void:
	"""The existing reservation envelope bounds allocation without silently truncating requested WIP."""
	var phase: Vector2i = _paid_phase(Contract.OP_BRACE)
	for requested: int in [-1, 0, Funding.MAX_RECEIPT_CAPACITY + 1, 9223372036854775807]:
		var refused: Funding = Funding.new(_construction, _inventory, _pool, _items, requested)
		assert_equal(refused.initialization_refusal(), Funding.REFUSE_RECEIPTS, "invalid engineering budget refuses")
		assert_equal(refused.state_bytes().size(), 16, "only fixed scalar image exists; no packed arena allocated")
		assert_false(refused.is_funded(phase), "refused configuration cannot own a paid project")
		assert_equal(refused.consume_to_wip(phase, JOB, 0, NULL_REF).error,
			Funding.REFUSE_RECEIPTS, "no fallback to a truncated usable budget")
	var small_pool: Reservations = Reservations.new(4)
	var small_refusal: Funding = Funding.new(_construction, _inventory, small_pool, _items, 5)
	assert_equal(small_refusal.initialization_refusal(), Funding.REFUSE_RECEIPTS, "actual smaller reservation owner also bounds receipts")
	assert_equal(small_refusal.state_bytes().size(), 16, "smaller-owner refusal precedes all packed allocation")
