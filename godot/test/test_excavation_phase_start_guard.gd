extends "res://test/framework/test_case.gd"
## Actual paid-phase accounting; geometry is the explicitly synthetic economic fixture.

const Fixture := preload("res://test/test_excavation_physical.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class SeedObserver extends RefCounted:
	var probe: Callable = Callable()
	var calls: int = 0

	func refuses_seed_consumption(_lot: Vector2i) -> bool:
		"""The real Inventory owner calls this after early phase preflight and before commit."""
		calls += 1
		if probe.is_valid():
			var current: Callable = probe
			probe = Callable()
			current.call()
		return false

var _fx: Fixture = null
var _observer: SeedObserver = null
var _nested_refusal: StringName = &""


func before_each() -> void:
	"""Every case uses real Jobs, Work, Gear, Inventory, Reservations, Construction and Sites."""
	_fx = Fixture.new()
	_fx.before_each()
	_observer = SeedObserver.new()
	assert_equal(_fx.failures.size(), 0, "fixture setup: %s" % _fx.failures)


func after_each() -> void:
	"""Drop callback scopes and check both real accounting owners before releasing the fixture."""
	_fx._inventory.set_seed_expiry_authority(null)
	_observer.probe = Callable()
	_fx._space.start_probe = Callable()
	assert_true(_fx._inventory.audit().ok, "real Inventory audit")
	assert_true(_fx._pool.audit(_fx._inventory).ok, "real Reservation audit")
	assert_false(_fx._sites._starting, "no START scope escapes")
	assert_false(_fx._sites._start_poisoned, "no reentry poison escapes")
	assert_equal(_fx._sites._funding._settling_project, NULL_REF, "no Funding project scope escapes")
	assert_equal(_fx._sites._funding._settling_job, NULL_REF, "no Funding Job scope escapes")
	_fx.after_each()
	assert_equal(_fx.failures.size(), 0, "fixture checks: %s" % _fx.failures)
	_fx = null
	_observer = null


func _ready_brace() -> Vector2i:
	"""Prepare a real complete bill and assigned equipped worker without seeding progress."""
	var job: int = _fx._open(Contract.OP_BRACE)
	_fx._deliver(Contract.OP_BRACE, job)
	assert_true(_fx._sites.bind_worker(_fx._site).ok, "actual worker binds")
	return _fx._sites.project_of(_fx._site)


func _unchanged_start(before: PackedByteArray, claims: PackedByteArray, project: Vector2i) -> void:
	"""Refusal rolls back goods/claims and leaves no paid work, WIP or prepared geometry."""
	assert_equal(_fx._inventory.state_bytes(), before, "all staged Inventory writes rolled back")
	assert_equal(_fx._pool.state_bytes(), claims, "all claims retained")
	assert_false(_fx._sites._funding.is_funded(project), "no WIP published")
	assert_false(_fx._construction.has_work_begun(project), "no work begun")
	assert_equal(_fx._space.pending_stage, -1, "prepared synthetic geometry discarded")


func test_late_inventory_contact_change_aborts_then_clean_retry_pays_once() -> void:
	"""A successful Inventory observer cannot make its later-invalid contact pass payment."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_observer.probe = _block_contact
	assert_true(_fx._inventory.set_seed_expiry_authority(_observer).ok, "real observer binds")
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error, &"SYNTHETIC_LATE_START", "late contact refuses")
	assert_true(_observer.calls > 0, "actual reserved material observer ran")
	_unchanged_start(before, claims, project)
	_fx._space.start_leaf_block = &""
	assert_true(_fx._sites.begin_phase_work(_fx._site, 0).ok, "fresh exact contact retries")
	assert_true(_fx._sites._funding.is_funded(project), "one actual WIP receipt")
	assert_false(_fx._sites.begin_phase_work(_fx._site, 0).ok, "duplicate start cannot pay again")


func _block_contact() -> void:
	"""Change only the isolated fixture's final contact, inside actual Inventory consumption."""
	_fx._space.start_leaf_block = &"SYNTHETIC_LATE_START"


func test_late_project_pause_refuses_before_payment() -> void:
	"""An actual Construction pause after early preflight must retain every input claim."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_observer.probe = _pause_project
	assert_true(_fx._inventory.set_seed_expiry_authority(_observer).ok, "real observer binds")
	assert_false(_fx._sites.begin_phase_work(_fx._site, 0).ok, "paused project cannot start")
	_unchanged_start(before, claims, project)
	assert_true(_fx._construction.is_paused(project), "actual pause remains")


func _pause_project() -> void:
	"""Use the ordinary actual player pause operation, without changing any receipt bytes."""
	assert_true(_fx._construction.set_paused(_fx._sites.project_of(_fx._site), true).ok, "late pause applies")


func test_last_spatial_observer_cannot_release_worker_then_charge_materials() -> void:
	"""The final pure economic leaf catches actual worker changes made by the last observer."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_fx._space.start_probe = _release_worker
	assert_false(_fx._sites.begin_phase_work(_fx._site, 0).ok, "changed assigned worker refuses")
	_unchanged_start(before, claims, project)


func _release_worker() -> void:
	"""Release the real current worker after all earlier worker/contact observations succeeded."""
	assert_true(_fx._jobs.release_worker(_fx._resident).ok, "actual late worker release")


func test_last_observer_cannot_commit_the_staged_inventory_journal() -> void:
	"""A final spatial callback cannot publish debits before the outer proof has finished."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_fx._space.start_probe = _commit_during_final_observation
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error,
		Inventory.REFUSE_ATTESTATION_REENTRY, "commit reentry poisons the outer journal")
	_unchanged_start(before, claims, project)


func _commit_during_final_observation() -> void:
	"""The actual Inventory API must keep the caller's journal open and mark it for rollback."""
	assert_true(_fx._inventory._attesting, "final observer runs under the Inventory barrier")
	assert_equal(_fx._inventory.commit().error, Inventory.REFUSE_ATTESTATION_REENTRY, "nested commit refuses")
	assert_true(_fx._inventory.is_transaction_open(), "original journal remains open")
	assert_true(_fx._inventory.is_transaction_poisoned(), "outer transaction is poisoned")


func test_last_observer_cannot_abort_the_callers_inventory_journal() -> void:
	"""Even a void-returning abort cannot erase the pending transaction beneath its caller."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_fx._space.start_probe = _abort_during_final_observation
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error,
		Inventory.REFUSE_ATTESTATION_REENTRY, "abort reentry poisons the outer journal")
	_unchanged_start(before, claims, project)


func _abort_during_final_observation() -> void:
	"""Abort must refuse before closing or changing the caller's staged writes."""
	_fx._inventory.abort()
	assert_true(_fx._inventory.is_transaction_open(), "original journal remains open after abort reentry")
	assert_true(_fx._inventory.is_transaction_poisoned(), "outer abort attempt poisons transaction")


func test_nested_inventory_audit_cannot_lower_the_outer_mutation_barrier() -> void:
	"""The actual public audit invokes Gear attestation without enabling a subsequent commit."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_fx._space.start_probe = _audit_then_commit
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error,
		Inventory.REFUSE_ATTESTATION_REENTRY, "audit preserves the outer guarded scope")
	_unchanged_start(before, claims, project)


func _audit_then_commit() -> void:
	"""Real equipped tools ensure audit traverses Inventory._attests, the former guard escape."""
	assert_true(_fx._inventory._equipped_lot_count > 0, "actual equipped-lot attestation is exercised")
	assert_true(_fx._inventory.audit().ok, "read-only nested audit is consistent")
	_commit_during_final_observation()


func test_last_observer_cannot_change_required_physical_support_then_charge() -> void:
	"""A stale BRACE phase must refuse even if a synthetic spatial adapter permits the room."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_fx._space.start_probe = _change_physical_support
	assert_false(_fx._sites.begin_phase_work(_fx._site, 0).ok, "changed physical phase refuses")
	_unchanged_start(before, claims, project)
	_fx._sites._installed[_fx._site.x] = 0


func _change_physical_support() -> void:
	"""Adversarial fixture mutation isolates the pure leaf's retained-support check."""
	_fx._sites._installed[_fx._site.x] = 1


func test_start_cannot_steal_a_preexisting_commit_candidate_or_action_scope() -> void:
	"""An occupied outer scope refuses before START can discard or overwrite it."""
	var project: Vector2i = _ready_brace()
	_fx._sites._candidate_row = _fx._site.x
	_fx._sites._candidate_stage = Contract.STAGE_COMMIT
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error, Contract.REFUSE_AUTHORITY, "COMMIT candidate retained")
	assert_equal(_fx._sites._candidate_row, _fx._site.x, "original candidate untouched")
	assert_equal(_fx._sites._candidate_stage, Contract.STAGE_COMMIT, "original stage untouched")
	assert_equal(_fx._space.discard_count, 0, "no foreign candidate discarded")
	_fx._sites._candidate_row = -1
	_fx._sites._candidate_stage = -1
	_fx._sites._permit_project = project
	_fx._sites._permit_action = Contract.ACTION_BEGIN_WORK
	assert_equal(_fx._sites.begin_phase_work(_fx._site, 0).error, Contract.REFUSE_AUTHORITY, "existing action scope retained")
	assert_equal(_fx._sites._permit_project, project, "original project permission untouched")
	_fx._sites._disallow()
	assert_true(_fx._sites.begin_phase_work(_fx._site, 0).ok, "fresh start works after original scope ends")


func test_nested_start_poison_preserves_outer_goods_and_candidate() -> void:
	"""Nested entry refuses without borrowing or publishing the outer prepared START."""
	var project: Vector2i = _ready_brace()
	var before: PackedByteArray = _fx._inventory.state_bytes()
	var claims: PackedByteArray = _fx._pool.state_bytes()
	_observer.probe = _reenter_start
	assert_true(_fx._inventory.set_seed_expiry_authority(_observer).ok, "actual observer binds")
	assert_false(_fx._sites.begin_phase_work(_fx._site, 0).ok, "outer poisoned start refuses")
	assert_equal(_nested_refusal, Contract.REFUSE_AUTHORITY, "nested start refuses")
	_unchanged_start(before, claims, project)
	assert_equal(_fx._space.discard_count, 1, "outer candidate discarded exactly once")


func _reenter_start() -> void:
	"""A real reentrant call cannot consume twice or replace the outer original candidate."""
	_nested_refusal = _fx._sites.begin_phase_work(_fx._site, 0).error


func test_base_guards_and_public_preflighted_start_cannot_bypass_owner() -> void:
	"""Fail-closed bases and pure-tail entry points supply no ambient payment authority."""
	var base: Contract = Contract.new()
	var space: Contract.SpatialAuthority = Contract.SpatialAuthority.new()
	assert_equal(base.excavation_inputs_refusal(NULL_REF, NULL_REF, null, null), Contract.REFUSE_AUTHORITY, "base scope refuses")
	assert_equal(base.final_input_refusal(NULL_REF, NULL_REF, null, null, NULL_REF, 0), Contract.REFUSE_AUTHORITY, "base payment refuses")
	assert_true(space.final_start_observation_refusal(Vector3i.ZERO, 1, NULL_REF) != &"", "base observer refuses")
	assert_true(space.final_start_leaf_refusal(Vector3i.ZERO, 1, NULL_REF) != &"", "base leaf refuses")
	assert_false(Construction.begin_excavation_work_preflighted(null, base, NULL_REF, NULL_REF).ok, "null tail refuses safely")
	var project: Vector2i = _ready_brace()
	assert_false(Construction.begin_excavation_work_preflighted(_fx._construction, _fx._sites,
		project, _fx._sites.job_of(_fx._site)).ok, "ordinary caller has no original START scope")
