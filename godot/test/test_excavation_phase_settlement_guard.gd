extends "res://test/framework/test_case.gd"
## Actual paid excavation settlement with explicitly synthetic geometry and late spatial observers.

const Fixture := preload("res://test/test_excavation_physical.gd")
const LocationFixture := preload("res://test/test_inventory_spatial.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class LateLocation extends Fixture.SpatialOutputFixture:

	var after_goods: Callable = Callable()

	func storage_endpoint_refusal(location: Vector2i) -> StringName:
		"""A successful actual Inventory observer changes another owner after output/refund lot creation."""
		var actual: Inventory = inventory.get_ref() as Inventory
		if after_goods.is_valid() and actual.container_lot_count(watched_output) > 0:
			var probe: Callable = after_goods
			after_goods = Callable()
			probe.call()
		return super.storage_endpoint_refusal(location)

var _fx: Fixture = null
var _locations: LateLocation = null


func before_each() -> void:
	"""Use actual finite goods, Jobs, Work, Gear, Construction, Sites and shared WIP receipts."""
	_fx = Fixture.new()
	_fx.before_each()
	_locations = LateLocation.new()
	_locations.inventory = weakref(_fx._inventory)
	_locations.directory = _fx._residents.directory()
	_locations.world = _fx._world
	assert_true(_fx._inventory.bind_spatial_locations(_locations, 4).ok, "actual Inventory adapter binds")
	assert_true(_fx.failures.is_empty(), "actual fixture prepared")


func after_each() -> void:
	"""Every owner must remain conserved and all callbacks and journals must be released."""
	_locations.after_goods = Callable()
	_fx._space.settlement_probe = Callable()
	_fx._space.room_generation = 1
	assert_false(_fx._inventory.is_transaction_open(), "no escaped Inventory transaction")
	assert_false(_fx._inventory._attesting, "Inventory barrier restored")
	assert_false(_fx._sites._settling, "terminal scope released")
	assert_false(_fx._sites._settlement_poisoned, "no terminal poison escapes")
	assert_true(_fx._inventory.audit().ok, "actual goods conservation")
	assert_true(_fx._pool.audit(_fx._inventory).ok, "actual claim ownership")
	assert_equal(_fx._sites.earth_conservation_refusal(), &"", "actual earth account")
	assert_equal(_fx._sites.support_conservation_refusal(), &"", "actual support account")
	_fx.after_each()
	assert_true(_fx.failures.is_empty(), "actual fixture checks")
	_fx = null
	_locations = null


func _late_room_change() -> void:
	"""The material endpoint remains valid while the independently owned room generation changes."""
	_fx._space.room_generation = 2


func _accounting_image() -> Array[PackedByteArray]:
	"""No output/refund, reservation or WIP receipt may publish after its prepared scope went stale."""
	return [_fx._inventory.state_bytes(), _fx._pool.state_bytes(), _fx._sites._funding.state_bytes()]


func _assert_unchanged(before: Array[PackedByteArray]) -> void:
	"""Use compact equality failures rather than printing the owners' entire binary images."""
	var after: Array[PackedByteArray] = _accounting_image()
	for index: int in before.size():
		assert_true(before[index] == after[index], "paid owner %d unchanged" % index)


func test_cut_output_observer_cannot_publish_after_the_room_changes() -> void:
	"""Exact paid output stays reserved until the final retained physical scope remains valid."""
	_fx._complete(Contract.OP_BRACE)
	_fx._output = _fx._inventory.create_spatial_ground_staging(LocationFixture.LOWER).ref
	_locations.watched_output = _fx._output
	var job: int = _fx._start(Contract.OP_CUT)
	_fx._finish_work(job)
	var project: Vector2i = _fx._sites.project_of(_fx._site)
	var before: Array[PackedByteArray] = _accounting_image()
	_locations.after_goods = _late_room_change
	assert_false(_fx._sites.settle_phase(_fx._site).ok, "late room change refuses output settlement")
	assert_false(_locations.after_goods.is_valid(), "actual post-output observer ran")
	_assert_unchanged(before)
	assert_true(_fx._sites._funding.is_funded(project), "earned WIP retained")
	assert_equal(_fx._sites.virgin_sourced_milli(), 0, "no geological output committed")
	_fx._space.room_generation = 1
	assert_true(_fx._sites.settle_phase(_fx._site).ok, "worker-free terminal retry settles once")
	assert_false(_fx._sites.settle_phase(_fx._site).ok, "duplicate terminal settlement refuses")


func test_paid_refund_observer_cannot_publish_after_the_room_changes() -> void:
	"""Returned lots cannot escape while their cancelled physical scope became stale."""
	_fx._start(Contract.OP_BRACE)
	var destination: Vector2i = _fx._inventory.create_spatial_ground_staging(LocationFixture.LOWER).ref
	_locations.watched_output = destination
	var project: Vector2i = _fx._sites.project_of(_fx._site)
	var before: Array[PackedByteArray] = _accounting_image()
	_locations.after_goods = _late_room_change
	assert_false(_fx._sites.cancel_phase(_fx._site, destination).ok, "late room change refuses paid refund")
	assert_false(_locations.after_goods.is_valid(), "actual post-refund observer ran")
	_assert_unchanged(before)
	assert_true(_fx._sites._funding.is_funded(project), "original WIP retained")
	_fx._space.room_generation = 1
	assert_true(_fx._sites.cancel_phase(_fx._site, destination).ok, "fresh refund retries")
	assert_false(_fx._sites.cancel_phase(_fx._site, destination).ok, "duplicate refund refuses")


func _guard_then_retry(probe: Callable, refund: bool) -> void:
	"""The final observer may not publish goods or clear WIP beneath an original terminal transaction."""
	var job: int = _fx._start(Contract.OP_BRACE)
	if not refund:
		_fx._finish_work(job)
	var project: Vector2i = _fx._sites.project_of(_fx._site)
	var before: Array[PackedByteArray] = _accounting_image()
	_fx._space.settlement_probe = probe
	assert_false(_settle(refund), "original terminal settlement refuses")
	_assert_unchanged(before)
	assert_true(_fx._sites._funding.is_funded(project), "real WIP retained")
	assert_equal(_fx._sites._installed[_fx._site.x], 0, "no support published")
	assert_true(_settle(refund), "clean terminal retry succeeds")
	assert_false(_settle(refund), "no repeated output or refund")


func _settle(refund: bool) -> bool:
	"""Use the actual public Sites coordinator, including ordinary freeze/release behavior."""
	return _fx._sites.cancel_phase(_fx._site, _fx._store).ok if refund else _fx._sites.settle_phase(_fx._site).ok


func _nested_commit() -> void:
	"""The journal remains open and poisoned when a final external observer attempts to close it."""
	assert_true(_fx._inventory._attesting, "Inventory owns final scope")
	assert_equal(_fx._inventory.commit().error, Inventory.REFUSE_ATTESTATION_REENTRY, "nested commit refuses")
	assert_true(_fx._inventory.is_transaction_open(), "original journal remains open")
	assert_true(_fx._inventory.is_transaction_poisoned(), "original journal poisoned")


func _nested_abort() -> void:
	"""Void abort must not erase the original transaction beneath its Funding caller."""
	_fx._inventory.abort()
	assert_true(_fx._inventory.is_transaction_open(), "original journal remains open after abort")
	assert_true(_fx._inventory.is_transaction_poisoned(), "original journal poisoned by abort")


func _nested_phase() -> void:
	"""A nested terminal operation cannot replace/discard the outer candidate or its action permit."""
	var stage: int = _fx._sites._candidate_stage
	var project: Vector2i = _fx._sites._permit_project
	assert_equal(_fx._sites.settle_phase(_fx._site).error, Contract.REFUSE_AUTHORITY, "nested settlement refuses")
	assert_equal(_fx._sites._candidate_stage, stage, "original stage retained")
	assert_equal(_fx._sites._permit_project, project, "original permit retained")


func test_completed_output_guard_refuses_nested_inventory_commit() -> void:
	"""An output-free brace still needs atomic paid-to-installed publication."""
	_guard_then_retry(_nested_commit, false)


func test_completed_output_guard_refuses_nested_inventory_abort() -> void:
	"""An output-free phase cannot retire through an aborted original journal."""
	_guard_then_retry(_nested_abort, false)


func test_paid_refund_guard_refuses_nested_inventory_commit() -> void:
	"""Refund lots stay abortable until the last actual candidate proof finishes."""
	_guard_then_retry(_nested_commit, true)


func test_paid_refund_guard_refuses_nested_inventory_abort() -> void:
	"""Refund staging remains owned by its original Inventory transaction."""
	_guard_then_retry(_nested_abort, true)


func test_final_output_observer_cannot_steal_the_outer_phase_scope() -> void:
	"""Reentry poisons one attempt without losing the original candidate or a later retry."""
	_guard_then_retry(_nested_phase, false)


func test_final_refund_observer_cannot_steal_the_outer_phase_scope() -> void:
	"""A paid cancellation cannot recurse into the same active COMMIT/CANCEL slot."""
	_guard_then_retry(_nested_phase, true)
