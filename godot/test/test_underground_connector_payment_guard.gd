extends "res://test/framework/test_case.gd"
## Real purpose8 payment and actual Contacts; the inherited fixture's source motion/installation geometry remain synthetic.

const ContactTests := preload("res://test/test_underground_connector_contacts.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _fx: ContactTests.ContactFixture = null


func before_each() -> void:
	"""Admit one real ConnectorWork order with actual reserved wood and an arrived equipped worker."""
	_fx = ContactTests.ContactFixture.new()
	_fx.before_each()
	_fx.open_order()
	_fx.assign_worker()
	_fx.deliver()
	assert_true(_fx.failures.is_empty(), "actual fixture and delivered order: %s" % _fx.failures)


func after_each() -> void:
	"""No transient permit, payment scope, Inventory transaction or observer survives cleanup."""
	assert_false(_fx._f._inventory.is_transaction_open(), "actual payment journal closed")
	assert_false(_fx._f._inventory._attesting, "actual observation barrier restored")
	assert_equal(_fx._router._funding._settling_project, NULL_REF, "Funding Project scope cleared")
	assert_equal(_fx._router._funding._settling_job, NULL_REF, "Funding Job scope cleared")
	_fx.after_each()
	assert_true(_fx.failures.is_empty(), "fixture conservation and cleanup: %s" % _fx.failures)
	_fx = null


func _payment_image() -> Array[PackedByteArray]:
	"""The real paid stores must be byte-identical after a refused observer attempts to close the journal."""
	return [_fx._f._inventory.state_bytes(), _fx._f._pool.state_bytes(),
		_fx._router._funding.state_bytes(), _fx._f._work.state_bytes(),
		_fx._f._gear.state_bytes(), _fx._f._residents.state_bytes()]


func _refuse_then_retry(probe: Callable) -> void:
	"""Verify rolled-back claims and no WIP, then consume those same actual materials exactly once."""
	var before: Array[PackedByteArray] = _payment_image()
	(_fx.contacts as ContactTests.ActualContacts).final_probe = probe
	assert_equal(_fx.start().error, Inventory.REFUSE_ATTESTATION_REENTRY, "outer payment refuses reentry")
	var after: Array[PackedByteArray] = _payment_image()
	for index: int in before.size():
		assert_true(after[index] == before[index], "real paid owner %d unchanged" % index)
	assert_false(_fx._router._funding.is_funded(_fx.project), "no paid receipt")
	assert_false(_fx._f._construction.has_work_begun(_fx.project), "no construction start")
	assert_true(_fx.start().ok, "same actual stock and claims retry")
	assert_true(_fx._router._funding.is_funded(_fx.project), "one receipt after clean retry")
	assert_false(_fx.start().ok, "duplicate start cannot consume again")


func test_connector_final_observer_cannot_commit_the_inventory_journal() -> void:
	"""Final contact proof runs inside the original Inventory mutation barrier."""
	_refuse_then_retry(_commit_inside_observation)


func _commit_inside_observation() -> void:
	"""A real commit attempt poisons the original still-open transaction instead of publishing its debit."""
	assert_true(_fx._f._inventory._attesting, "Inventory owns final observation")
	assert_equal(_fx._f._inventory.commit().error, Inventory.REFUSE_ATTESTATION_REENTRY, "nested commit refuses")
	assert_true(_fx._f._inventory.is_transaction_open(), "original journal remains open")
	assert_true(_fx._f._inventory.is_transaction_poisoned(), "outer journal poisoned")


func test_connector_final_observer_cannot_abort_the_inventory_journal() -> void:
	"""A void-returning abort cannot invalidate Funding's pending original transaction."""
	_refuse_then_retry(_abort_inside_observation)


func _abort_inside_observation() -> void:
	"""The actual abort API refuses before changing or closing the caller's debit journal."""
	_fx._f._inventory.abort()
	assert_true(_fx._f._inventory.is_transaction_open(), "original journal remains open")
	assert_true(_fx._f._inventory.is_transaction_poisoned(), "outer abort attempt poisons journal")


func test_connector_nested_equipment_audit_cannot_enable_a_commit() -> void:
	"""The public read may attest actual equipped Gear without lowering an outer payment barrier."""
	_refuse_then_retry(_audit_then_commit)


func _audit_then_commit() -> void:
	"""Use an actual equipped tool so Inventory's nested attestation path is exercised."""
	assert_true(_fx._f._inventory._equipped_lot_count > 0, "real equipped tool present")
	assert_equal(_fx._f._inventory.audit().error, Inventory.REFUSE_SPATIAL_BINDING,
		"audit visits equipped lots, then refuses nested spatial-provider observation")
	_commit_inside_observation()


func test_paid_connector_refund_cannot_publish_goods_through_a_nested_commit() -> void:
	"""Refused cancellation preserves original WIP and produces no duplicate refund goods."""
	_settlement_refuse_then_retry(_commit_inside_observation, true)


func test_paid_connector_refund_cannot_abort_its_original_journal() -> void:
	"""A cancellation observer cannot replace its caller's payment lifetime."""
	_settlement_refuse_then_retry(_abort_inside_observation, true)


func test_completed_connector_cannot_publish_after_nested_commit() -> void:
	"""Even a no-output timber assembly must guard its final paid-to-installed transition."""
	_settlement_refuse_then_retry(_commit_inside_observation, false)


func test_completed_connector_cannot_abort_its_original_journal() -> void:
	"""A completion observer cannot clear the transaction beneath the actual installed-prefix proof."""
	_settlement_refuse_then_retry(_abort_inside_observation, false)


func _settlement_refuse_then_retry(probe: Callable, refund: bool) -> void:
	"""Retain goods, claims, WIP and physical Space on refusal; one clean terminal retry settles them."""
	assert_true(_fx.start().ok, "real purpose8 inputs funded")
	if not refund:
		_fx.finish_work()
	var before: Array[PackedByteArray] = _payment_image()
	var geometry: PackedByteArray = _fx._f._owner.state_bytes()
	(_fx.contacts as ContactTests.ActualContacts).final_probe = probe
	assert_false(_settle(refund), "reentrant final settlement refuses")
	var after: Array[PackedByteArray] = _payment_image()
	for index: int in 3:
		assert_true(after[index] == before[index], "Inventory/claims/WIP owner %d unchanged" % index)
	assert_true(_fx._f._owner.state_bytes() == geometry, "no physical prefix or cancellation publication")
	assert_true(_fx._router._funding.is_funded(_fx.project), "original earned WIP retained")
	assert_true(_settle(refund), "fresh terminal settlement retries")
	assert_false(_fx._router._funding.is_funded(_fx.project), "receipt retired exactly once")
	assert_false(_settle(refund), "duplicate terminal settlement refuses")


func _settle(refund: bool) -> bool:
	"""Use only the actual public coordinator doors for cancellation or completed installation."""
	return _fx._router.cancel_order(_fx.project, _fx.storage).ok if refund \
		else _fx._router.complete_order(_fx.project).ok
