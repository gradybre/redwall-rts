extends "res://test/framework/test_case.gd"
## ADR1141 lower-owner tests. Spatial/handling permission is explicitly synthetic here;
## actual Inventory, Pool, journal, generations, satchels, quantities and claims are exercised.

const Inventory := preload("res://scripts/core/inventory.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Contract := preload("res://scripts/core/haul_transfer_contract.gd")
const SpatialFixture := preload("res://test/test_inventory_spatial.gd")

const JOB: Vector2i = Vector2i(2, 1)
const NEXT_JOB: Vector2i = Vector2i(3, 1)
const WORKER: Vector2i = Vector2i(8, 1)
const OWNER: Vector2i = Vector2i(12, 1)
const WOOD: int = 3
const GRAMS: int = 5000
const CARRY: int = 12000
const NULL_REF: Vector2i = Vector2i(-1, 0)

class Guard extends Contract:
	var inventory: Inventory = null
	var pool: Pool = null
	var mode: int = 0
	var calls: int = 0
	var handling_current: bool = true
	var saw_staged_cargo: bool = false
	var last_action: int = -1
	var packet_field: StringName = &"quantity_milli"
	var saved: Pool.ReservationColumns = null
	var arm_tail: bool = false

	func final_transfer_refusal(t: Contract.Transfer, inv: RefCounted, p: RefCounted) -> StringName:
		"""Synthetic physical permission plus concrete original scope and staged Inventory proof."""
		calls += 1
		if inv != inventory or p != pool or not inventory._attesting \
			or Contract.scope_refusal(inv, p, self, t) != &"":
			return Contract.REFUSE_SCOPE
		last_action = t.action
		_attack(t)
		if mode == 1 or (not handling_current and t.action != Contract.CANCEL):
			return &"TEST_HANDLING_REFUSED"
		if t.action == Contract.LOAD:
			saw_staged_cargo = Contract.satchel_matches(inv, t.staged_satchel, t.worker) \
				and t.original_satchel == NULL_REF and inventory.lot_container(t.arrived_lot) == t.staged_satchel
		elif t.action == Contract.UNLOAD:
			saw_staged_cargo = inventory.lot_container(t.arrived_lot) == t.destination \
				and (Contract.container_live(inv, t.original_satchel) == (t.staged_satchel != NULL_REF))
		if arm_tail:
			inventory.tail_armed = true
		return &""

	func _attack(t: Contract.Transfer) -> void:
		"""Public API attacks must refuse without closing/replacing the original journal or Pool."""
		match mode:
			2: inventory.commit()
			3: inventory.abort()
			4: inventory.clear()
			5: pool.clear()
			6: pool.restore_reservation_columns(saved, inventory)
			7: pool.renew_claim(t.job, t.source_lot, t.from_purpose, 900)
			8: pool.transfer_haul_guarded(Contract.CANCEL, t.job, NULL_REF, NULL_REF,
				t.destination, NULL_REF, t.reserved_mass_g, 0, self, inventory)
			9:
				var current: Variant = t.get(packet_field)
				t.set(packet_field, current + Vector2i(0, 1) if current is Vector2i else current + 1)
			10:
				inventory.audit()
				inventory.abort()
			11: pool.drop_retired_lot_claims(t.source_lot, inventory)

class SeedObserver extends RefCounted:
	var pool: Pool = null
	var guard: Guard = null
	var armed: bool = false
	var calls: int = 0
	var mode: int = 0

	func refuses_seed_consumption(_lot: Vector2i) -> bool:
		"""Actual Inventory observer, invoked while staging reserve/move operations."""
		calls += 1
		if not armed:
			return false
		armed = false
		if mode == 1:
			pool.clear()
		elif mode == 2:
			guard.handling_current = false
		return mode == 0

class ObservedPool extends Pool:
	var armed: bool = false
	var tail_calls: int = 0

	func _free_row(row: int) -> void:
		"""The new committed spatial tail must never dispatch this overridable ordinary helper."""
		if armed:
			tail_calls += 1
		super._free_row(row)

	func _upsert_row(job: Vector2i, lot: Vector2i, purpose: int, amount: int, expiry: int) -> int:
		"""Existing public callers still work; spatial publication uses the concrete static kernel."""
		if armed:
			tail_calls += 1
		return super._upsert_row(job, lot, purpose, amount, expiry)

	func _ok(ref: Vector2i, value: int) -> Inventory.OpResult:
		"""The successful result also belongs to the callback-free committed tail."""
		if armed and _haul_active and not _haul_inventory._tx_open:
			tail_calls += 1
		return super._ok(ref, value)

class ObservedInventory extends Inventory:
	var tail_armed: bool = false
	var tail_calls: int = 0
	var permission: WeakRef = null

	func _tail_probe() -> void:
		"""A real subclass can invalidate current handling without touching Inventory's guarded API."""
		if tail_armed and not _attesting:
			tail_calls += 1
			permission.get_ref().handling_current = false

	func _reclaim_empty_piles() -> void:
		"""No such observer can follow the new path's last physical proof."""
		_tail_probe()
		super._reclaim_empty_piles()

	func commit_haul_transfer(guard: Contract, packet: Contract.Transfer, pool: RefCounted) -> Inventory.OpResult:
		"""Even a successful outer super call must not give a late observer another opportunity."""
		var result: Inventory.OpResult = super.commit_haul_transfer(guard, packet, pool)
		_tail_probe()
		return result

	func _haul_attestation(guard: Contract, packet: Contract.Transfer, pool: RefCounted) -> StringName:
		"""An overridden internal attestation can otherwise invalidate facts just proved by super."""
		var code: StringName = super._haul_attestation(guard, packet, pool)
		_tail_probe()
		return code

	func _close_transaction() -> void:
		"""Closing the original journal also belongs to the direct tail."""
		_tail_probe()
		super._close_transaction()

	func _clear_spatial_endpoint(row: int, journaled: bool) -> void:
		"""Nested reclamation cannot invoke an observer after the successful guard."""
		if not journaled:
			_tail_probe()
		super._clear_spatial_endpoint(row, journaled)

	func _free_container_slot(slot: int, journaled: bool = true) -> void:
		"""The postcommit allocator follows the same direct rule."""
		if not journaled:
			_tail_probe()
		super._free_container_slot(slot, journaled)

var _inventory: ObservedInventory = null
var _pool: ObservedPool = null
var _guard: Guard = null
var _source: Vector2i = NULL_REF
var _destination: Vector2i = NULL_REF
var _lot: Vector2i = NULL_REF
var _claims: PackedInt64Array = PackedInt64Array()


func before_each() -> void:
	"""Small actual stores use canonical production quantities and capacities, without spatial grants."""
	_inventory = ObservedInventory.new(8, 16)
	_inventory.register_item(WOOD, GRAMS, 3)
	_pool = ObservedPool.new(16, 16, 16)
	_pool.bind_inventory(_inventory)
	_source = _inventory.create_container(OWNER, 100000, -1, 0, true).ref
	_destination = _inventory.create_container(Vector2i(13, 1), 100000, -1, 0, true).ref
	_lot = _inventory.create_lot(_source, WOOD, 1000, 2, 0, 0, 400, 0).ref
	_guard = Guard.new()
	_guard.inventory = _inventory
	_guard.pool = _pool
	_inventory.permission = weakref(_guard)
	_guard.saved = Pool.ReservationColumns.new(16, 16, 16)
	_pool.copy_reservation_columns_into(_guard.saved)
	_claims.resize(Pool.CLAIM_STRIDE)


func _admit(job: Vector2i = JOB, lot: Vector2i = NULL_REF, quantity: int = 1000) -> Inventory.OpResult:
	"""Explicitly synthetic handling guard; all accounting occurs in the real lower owners."""
	return _pool.admit_haul_guarded(job, WORKER, _lot if lot == NULL_REF else lot,
		quantity, 500, _destination, quantity * 5, _guard, _inventory)


func _transfer(action: int, job: Vector2i = JOB, lot: Vector2i = NULL_REF,
		satchel: Vector2i = NULL_REF, grams: int = GRAMS) -> Inventory.OpResult:
	"""Use the exact same original owner tuple for both transfer directions and cancellation."""
	return _pool.transfer_haul_guarded(action, job, WORKER, _lot if lot == NULL_REF else lot,
		_destination, satchel, grams, CARRY, _guard, _inventory)


func _sound() -> void:
	"""Conservation and derived indexes must agree after every completed transaction."""
	assert_true(_inventory.audit().ok, "Inventory conservation")
	assert_true(_pool.audit(_inventory).ok, "Pool/Inventory reservations")
	assert_false(_inventory._tx_open, "journal closed")
	assert_false(_pool._haul_active, "scope released")
	assert_true(_pool._haul_inventory == null and _pool._haul_guard == null, "borrowed owners released")


func _unchanged(inventory_before: PackedByteArray, pool_before: PackedByteArray) -> void:
	"""Refusal restores real goods, mass, allocator and claim bytes."""
	assert_equal(_inventory.state_bytes(), inventory_before, "Inventory unchanged")
	assert_equal(_pool.state_bytes(), pool_before, "Pool unchanged")
	_sound()


func test_admission_reserves_goods_and_destination_in_one_guarded_journal() -> void:
	"""The guard sees staging, and only success publishes the existing HAUL_SOURCE row."""
	var result: Inventory.OpResult = _admit()
	assert_true(result.ok, String(result.error))
	assert_equal(_guard.calls, 1, "one final observation")
	assert_equal(_guard.last_action, Contract.ADMIT, "admission action")
	assert_equal(_inventory.container_reserved_mass_g(_destination), GRAMS, "exact destination grams")
	assert_equal(_pool.claim_quantity_milli(JOB, _lot, Pool.PURPOSE_HAUL_SOURCE), 1000, "actual claim")
	assert_equal(_pool._haul_original.claim_row, 0, "lowest free row pinned")
	_sound()


func test_load_and_unload_validate_expected_staged_satchel_and_pure_tail() -> void:
	"""The same full lot moves; creation and retirement precede the caller's satchel-pointer write."""
	assert_true(_admit().ok, "admit")
	_pool.armed = true
	var loaded: Inventory.OpResult = _transfer(Contract.LOAD)
	assert_true(loaded.ok, String(loaded.error))
	assert_equal(loaded.ref, _lot, "whole lot full identity retained")
	assert_true(_guard.saw_staged_cargo, "new staged worker satchel")
	var satchel: Vector2i = _inventory.lot_container(loaded.ref)
	assert_true(_inventory.is_satchel(satchel), "real satchel")
	var unloaded: Inventory.OpResult = _transfer(Contract.UNLOAD, JOB, loaded.ref, satchel)
	assert_true(unloaded.ok, String(unloaded.error))
	assert_true(_guard.saw_staged_cargo, "old satchel retired before pointer tail")
	assert_false(_inventory.is_container_valid(satchel), "empty satchel retired")
	assert_equal(_inventory.lot_container(_lot), _destination, "arrived in actual destination")
	assert_equal(_inventory.container_reserved_mass_g(_destination), 0, "grams released once")
	assert_equal(_pool.active_row_count(), 0, "claim ended")
	assert_equal(_pool.tail_calls, 0, "no ordinary virtual row helper after commit")
	_sound()


func test_partial_shipment_preserves_source_and_material_attributes() -> void:
	"""One delivered bill may arrive in multiple real shipments, without a whole-assembly carry rule."""
	var extra: Inventory.OpResult = _inventory.create_lot(_source, WOOD, 3000, 2, 0, 0, 400, 0)
	assert_true(extra.ok and _inventory.merge_lots(_lot, extra.ref).ok, "actual additional source goods")
	assert_true(_admit().ok, "one partial load admitted")
	var loaded: Inventory.OpResult = _transfer(Contract.LOAD)
	assert_true(loaded.ok, String(loaded.error))
	assert_true(loaded.ref != _lot, "split creates actual different lot")
	assert_equal(_inventory.lot_quantity_milli(_lot), 3000, "undelivered source remains")
	var satchel: Vector2i = _inventory.lot_container(loaded.ref)
	assert_true(_transfer(Contract.UNLOAD, JOB, loaded.ref, satchel).ok, "partial shipment delivered")
	assert_equal(_inventory.total_live_milli(WOOD), 4000, "conserved total")
	assert_equal(_inventory.lot_quality(loaded.ref), 2, "quality preserved")
	assert_equal(_inventory.lot_age_milli_hours(loaded.ref), 1000, "source's real merged age preserved")
	_sound()


func test_final_refusal_keeps_goods_capacity_claim_and_allocator_then_retry() -> void:
	"""Every action remains atomic at the last observation."""
	_guard.mode = 1
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	assert_false(_admit().ok, "late admission refusal")
	_unchanged(ib, pb)
	_guard.mode = 0
	assert_true(_admit().ok, "same admission retries")
	ib = _inventory.state_bytes()
	pb = _pool.state_bytes()
	_guard.mode = 1
	assert_false(_transfer(Contract.LOAD).ok, "late load refusal")
	_unchanged(ib, pb)
	_guard.mode = 0
	var loaded: Inventory.OpResult = _transfer(Contract.LOAD)
	assert_true(loaded.ok, "same load retries")
	_assert_terminal_refusal(loaded.ref, _inventory.lot_container(loaded.ref))


func _assert_terminal_refusal(lot: Vector2i, satchel: Vector2i) -> void:
	"""Both release paths use the same final boundary, without touching the carried quantity."""
	for action: int in [Contract.UNLOAD, Contract.CANCEL]:
		var ib: PackedByteArray = _inventory.state_bytes()
		var pb: PackedByteArray = _pool.state_bytes()
		_guard.mode = 1
		assert_false(_transfer(action, JOB, lot, satchel).ok, "late terminal refusal")
		_unchanged(ib, pb)
	_guard.mode = 0
	assert_true(_transfer(Contract.UNLOAD, JOB, lot, satchel).ok, "unload retry")
	_sound()


func test_cancel_after_worker_release_preserves_carried_goods_and_allows_repost() -> void:
	"""Cancellation grants no work; its own original ledger can settle without the old Project/worker."""
	assert_true(_admit().ok, "admit")
	var loaded: Inventory.OpResult = _transfer(Contract.LOAD)
	var satchel: Vector2i = _inventory.lot_container(loaded.ref)
	_guard.handling_current = false
	var cancel: Inventory.OpResult = _pool.transfer_haul_guarded(Contract.CANCEL, JOB,
		NULL_REF, NULL_REF, _destination, NULL_REF, GRAMS, 0, _guard, _inventory)
	assert_true(cancel.ok, String(cancel.error))
	assert_equal(_inventory.lot_container(loaded.ref), satchel, "goods stay in real satchel")
	assert_equal(_inventory.lot_reserved_milli(loaded.ref), 0, "claim released")
	_guard.handling_current = true
	assert_true(_admit(NEXT_JOB, loaded.ref).ok, "fresh haul claims existing goods")
	var ib: PackedByteArray = _inventory.state_bytes()
	var repost: Inventory.OpResult = _transfer(Contract.REPOST, NEXT_JOB, loaded.ref, satchel)
	assert_true(repost.ok, String(repost.error))
	assert_equal(_inventory.state_bytes(), ib, "reposting rekeys only existing claim")
	assert_equal(_pool.claim_quantity_milli(NEXT_JOB, loaded.ref, Pool.PURPOSE_HAUL_DESTINATION), 1000, "new carried claim")
	_sound()


func test_original_inventory_barrier_and_all_pool_mutation_doors_refuse_reentry() -> void:
	"""Successful malicious callbacks cannot commit, abort, clear, restore, renew or recurse early."""
	for mode: int in [2, 3, 4, 5, 6, 7, 8, 10, 11]:
		before_each()
		assert_true(_admit().ok, "admit before attack")
		var ib: PackedByteArray = _inventory.state_bytes()
		var pb: PackedByteArray = _pool.state_bytes()
		_guard.mode = mode
		var result: Inventory.OpResult = _transfer(Contract.LOAD)
		assert_false(result.ok, "attack refused %d" % mode)
		_unchanged(ib, pb)
		_guard.mode = 0
		assert_true(_transfer(Contract.LOAD).ok, "retry after attack %d" % mode)
		_sound()


func test_every_callback_packet_field_is_pinned() -> void:
	"""All eight full references and nineteen integers are independently compared after callbacks."""
	var fields: Array[StringName] = []
	for field: Dictionary in _pool._haul_view.get_property_list():
		if field.type == TYPE_INT or field.type == TYPE_VECTOR2I:
			fields.append(field.name)
	assert_equal(fields.size(), 27, "exact216-byte packet schema")
	assert_true(_admit().ok, "admit")
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	for field: StringName in fields:
		_guard.mode = 9
		_guard.packet_field = field
		assert_equal(_transfer(Contract.LOAD).error, Contract.REFUSE_PACKET, "mutated pin: " + String(field))
		_unchanged(ib, pb)
	_guard.mode = 0
	assert_true(_transfer(Contract.LOAD).ok, "same untouched packet retry")


func test_actual_seed_observer_can_refuse_or_invalidate_final_handling_before_admit() -> void:
	"""The destination reserve is rolled back when a real reserve_lot observer runs later."""
	var observer: SeedObserver = SeedObserver.new()
	observer.pool = _pool
	observer.guard = _guard
	assert_true(_inventory.set_seed_expiry_authority(observer).ok, "bind actual Inventory observer")
	for mode: int in [0, 1, 2]:
		var ib: PackedByteArray = _inventory.state_bytes()
		var pb: PackedByteArray = _pool.state_bytes()
		observer.mode = mode
		observer.armed = true
		_guard.handling_current = true
		assert_false(_admit().ok, "late seed observer mode %d" % mode)
		assert_true(observer.calls > 0, "actual observer executed")
		_unchanged(ib, pb)
	_guard.handling_current = true
	assert_true(_admit().ok, "original tuple retries after observer")
	_sound()


func test_wrong_full_generations_foreign_inventory_and_fail_closed_guard_preserve_state() -> void:
	"""Coincident numeric slots in another world do not own this claim or destination."""
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	var foreign: Inventory = Inventory.new(8, 16)
	assert_false(_pool.admit_haul_guarded(JOB, WORKER, _lot, 1000, 500,
		_destination, GRAMS, _guard, foreign).ok, "foreign Inventory")
	assert_false(_pool.admit_haul_guarded(JOB, WORKER, _lot + Vector2i(0, 1), 1000, 500,
		_destination, GRAMS, _guard, _inventory).ok, "source generation")
	assert_false(_pool.admit_haul_guarded(JOB, WORKER, _lot, 1000, 500,
		_destination + Vector2i(0, 1), GRAMS, _guard, _inventory).ok, "destination generation")
	assert_false(_pool.admit_haul_guarded(JOB, WORKER, _lot, 1000, 500,
		_destination, GRAMS, Contract.new(), _inventory).ok, "base protocol refuses")
	_unchanged(ib, pb)


func test_empty_expired_claim_cleanup_still_releases_only_original_destination_grams() -> void:
	"""An expired claim is not a reason to strand the existing Planner reservation."""
	assert_true(_admit().ok, "admit")
	assert_true(_pool.release_expired_for_job(JOB, 500, _inventory).ok, "real expiry releases claim")
	var result: Inventory.OpResult = _transfer(Contract.CANCEL)
	assert_true(result.ok, String(result.error))
	assert_equal(result.value, 0, "no fabricated released claim")
	assert_equal(_inventory.container_reserved_mass_g(_destination), 0, "original grams returned")
	assert_equal(_inventory.lot_container(_lot), _source, "goods unmoved")
	_sound()


func test_capacity_and_original_satchel_owner_refusals_preserve_real_goods() -> void:
	"""A real capacity refusal and a same-slot wrong worker cannot publish a transfer."""
	var destination: Vector2i = _destination
	_destination = _inventory.create_container(Vector2i(14, 1), 100, -1, 0, true).ref
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	assert_false(_admit().ok, "actual destination capacity")
	_unchanged(ib, pb)
	_destination = destination
	assert_true(_admit().ok, "normal admission")
	ib = _inventory.state_bytes()
	pb = _pool.state_bytes()
	assert_false(_pool.transfer_haul_guarded(Contract.LOAD, JOB, WORKER, _lot,
		_destination, NULL_REF, GRAMS, 100, _guard, _inventory).ok, "actual carry capacity")
	_unchanged(ib, pb)
	var loaded: Inventory.OpResult = _transfer(Contract.LOAD)
	var satchel: Vector2i = _inventory.lot_container(loaded.ref)
	ib = _inventory.state_bytes()
	pb = _pool.state_bytes()
	assert_false(_pool.transfer_haul_guarded(Contract.UNLOAD, JOB, WORKER + Vector2i(0, 1),
		loaded.ref, _destination, satchel, GRAMS, CARRY, _guard, _inventory).ok, "full satchel owner")
	_unchanged(ib, pb)
	assert_true(_transfer(Contract.UNLOAD, JOB, loaded.ref, satchel).ok, "original owner retries")
	_sound()


func test_cancellation_releases_exact_multiple_claims_and_grams_together() -> void:
	"""Real additional claims share the same original job chain; a final refusal preserves all rows."""
	assert_true(_admit().ok, "admitted first row")
	var extra: Inventory.OpResult = _inventory.create_lot(_source, WOOD, 1000, 1, 0, 0, 0, 0)
	_claims[0] = extra.ref.x
	_claims[1] = extra.ref.y
	_claims[2] = Pool.PURPOSE_HAUL_SOURCE
	_claims[3] = 500
	_claims[4] = 1000
	assert_true(_pool.claim_batch(JOB, _claims, 1, _inventory).ok, "actual second row")
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	_guard.mode = 1
	assert_false(_transfer(Contract.CANCEL).ok, "late cancellation refusal")
	_unchanged(ib, pb)
	_guard.mode = 0
	var cancelled: Inventory.OpResult = _transfer(Contract.CANCEL)
	assert_true(cancelled.ok, String(cancelled.error))
	assert_equal(cancelled.value, 2, "both original claims released once")
	assert_equal(_inventory.container_reserved_mass_g(_destination), 0, "original grams released once")
	assert_equal(_inventory.lot_quantity_milli(extra.ref), 1000, "no goods consumed")
	_sound()


func test_admission_checks_both_real_inventory_and_pool_lot_namespaces_before_journal() -> void:
	"""A larger Inventory cannot make a valid lot index into a smaller configured Pool."""
	var extra: Inventory.OpResult = _inventory.create_lot(_source, WOOD, 1000, 1, 0, 0, 0, 0)
	assert_true(extra.ok and extra.ref.x >= 1, "real additional full lot")
	_pool = ObservedPool.new(16, 16, 1)
	assert_true(_pool.bind_inventory(_inventory).ok, "actual smaller Pool bound")
	_guard.pool = _pool
	var ib: PackedByteArray = _inventory.state_bytes()
	var pb: PackedByteArray = _pool.state_bytes()
	assert_equal(_admit(JOB, extra.ref).error, Pool.REFUSE_LOT_OUT_OF_RANGE, "Pool namespace refuses")
	assert_equal(_guard.calls, 0, "no final observer or journal before range refusal")
	_unchanged(ib, pb)
	assert_true(_admit().ok, "original in-range tuple still admits")
	_sound()


func test_inventory_commit_tail_cannot_observe_after_final_handling_proof() -> void:
	"""The physical guard succeeds; no later override may invalidate that permission before return."""
	_guard.arm_tail = true
	assert_true(_admit().ok, "current original handling admitted")
	assert_equal(_inventory.tail_calls, 0, "no post-guard reclaim/close observer")
	assert_true(_guard.handling_current, "handling remained current through publication")
	_inventory.tail_armed = false
	_sound()


func test_spatial_ground_reclamation_uses_direct_endpoint_and_allocator_tail() -> void:
	"""Loading a whole real pile retires its exact endpoint/generation without nested callbacks."""
	var authority: SpatialFixture.GeometryFixture = SpatialFixture.GeometryFixture.new()
	authority.inventory = weakref(_inventory)
	authority.directory = SpatialFixture.Directory.new()
	authority.world = authority.directory.create(SpatialFixture.Directory.KIND_WORLD)
	assert_true(_inventory.bind_spatial_locations(authority, 2).ok, "synthetic geometry; actual sparse Inventory")
	_source = _inventory.create_spatial_ground_staging(SpatialFixture.LOWER).ref
	assert_true(_inventory.begin().ok, "actual output transaction")
	_lot = _inventory.create_lot(_source, WOOD, 1000, 2, 0, 0, 400, 0).ref
	assert_true(_inventory.promote_to_spatial_ground_pile(_source, SpatialFixture.LOWER).ok, "real pile")
	assert_true(_inventory.commit().ok, "actual output publication")
	assert_true(_admit().ok, "real source reserved")
	_guard.arm_tail = true
	assert_true(_transfer(Contract.LOAD).ok, "all goods loaded")
	assert_equal(_inventory.tail_calls, 0, "no nested post-guard override")
	assert_true(_guard.handling_current, "handling permission remains current")
	assert_false(_inventory.is_container_valid(_source), "empty original full pile retired")
	assert_false(_inventory.has_spatial_location(SpatialFixture.LOWER, 1), "exact sparse endpoint cleared")
	_inventory.tail_armed = false
	_sound()


func test_successful_inventory_super_call_cannot_add_a_later_handling_observer() -> void:
	"""Pool calls the concrete commit and attestation, bypassing both outer after-super overrides."""
	_guard.arm_tail = true
	var result: Inventory.OpResult = _admit()
	assert_true(result.ok, "actual transfer succeeds with current handling")
	assert_equal(_inventory.tail_calls, 0, "no outer or attestation after-super callback")
	assert_true(_guard.handling_current, "physical fact remains current at successful return")
	_inventory.tail_armed = false
	_sound()
