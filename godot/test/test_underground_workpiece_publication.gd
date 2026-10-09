extends "res://test/framework/test_case.gd"
## Actual payment/Jobs/Work; explicit synthetic physical owner only observes the new START window.

const BaseFixture := preload("res://test/test_modular_projects.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const Contract := preload("res://scripts/core/modular_project_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

class StartOwner extends BaseFixture.SyntheticOwner:
	var starts: int = 0
	var paid_observers: int = 0
	var closed_journal: bool = false
	var paid_and_begun: bool = false
	var ready_job: bool = false
	var intact_stage: bool = false
	var nested_error: StringName = &""

	func purpose() -> int:
		"""Detect a forbidden virtual owner lookup between actual payment and its prepared publication."""
		if project != NULL_REF and funding != null and funding.is_funded(project):
			paid_observers += 1
		return super.purpose()

	func project_facts_into(candidate: Vector2i, out: Contract.Quote) -> StringName:
		"""The actual bill is still read before payment; a later observer must not run in the pure tail."""
		if funding != null and funding.is_funded(candidate):
			paid_observers += 1
		return super.project_facts_into(candidate, out)

	func publish_start(candidate: Vector2i) -> void:
		"""Observe only the exact actual Router window, without inventing a physical workpiece permission."""
		var router: Router = route.get_ref() as Router if route != null else null
		if router == null or not router._busy or router._publishing_owner != self \
				or router._publishing_project != candidate or router._publishing_action != Contract.START:
			return
		starts += 1
		closed_journal = not router._inventory.is_transaction_open()
		paid_and_begun = funding.is_funded(candidate) and construction.has_work_begun(candidate)
		intact_stage = stage == Contract.START and stage_project == candidate
		var row: int = router._construction._directory.get_typed_row(candidate)
		paid_and_begun = paid_and_begun and construction._phase[row] == Construction.PHASE_WORKING
		var job_row: int = router._jobs.directory().get_typed_row(router.job_of(candidate))
		ready_job = router._jobs.state_into(job_row, math) and math.value == Jobs.JOB_STATE_WORK
		nested_error = router.start_work(candidate, 100).error
		super.publish_start(candidate)

class Fixture extends BaseFixture:

	func _new_owner() -> BaseFixture.SyntheticOwner:
		"""Reuse the actual accounting bootstrap, changing only the explicit physical observer fixture."""
		var owner: StartOwner = StartOwner.new()
		owner.construction = _construction
		owner.world = _world
		owner.route = weakref(_router)
		owner.funding = _funding
		return owner

var _fixture: Fixture = null
var _owner: StartOwner = null
var _project: Vector2i = NULL_REF


func before_each() -> void:
	"""Create real shared stores and one prepared connector with claimed delivered goods."""
	_fixture = Fixture.new()
	_fixture.before_each()
	_owner = _fixture._new_connector() as StartOwner
	_project = _fixture._open(_owner)
	_fixture._job(_project)
	_fixture._deliver(_project)
	assert_true(_fixture.failures.is_empty(), "actual store setup: %s" % _fixture.failures)


func after_each() -> void:
	"""Retain actual Inventory/claims audits and release the test-only physical observer."""
	assert_false(_fixture._router._busy, "no publication window survives")
	assert_equal(_fixture._router._publishing_project, NULL_REF, "Project window cleared")
	assert_equal(_fixture._router._publishing_action, -1, "action window cleared")
	assert_true(_fixture._router._publishing_owner == null, "strong owner released")
	_owner = null
	_fixture.after_each()
	assert_true(_fixture.failures.is_empty(), "actual cleanup: %s" % _fixture.failures)
	_fixture = null


func test_start_publication_follows_payment_construction_and_worker_state_once() -> void:
	"""The original prepared owner receives one closed-journal paid START, with no late bill observer."""
	assert_true(_fixture._router.start_work(_project, 100).ok, "actual paid start")
	assert_equal(_owner.starts, 1, "one prepared publication")
	assert_true(_owner.closed_journal and _owner.paid_and_begun, "receipt/start committed before publication")
	assert_true(_owner.ready_job and _owner.intact_stage, "ready Job and original START candidate")
	assert_equal(_owner.paid_observers, 0, "no virtual purpose/bill observer after payment")
	assert_equal(_owner.nested_error, Router.REFUSE_BUSY, "reentrant start cannot publish or pay again")
	assert_equal(_owner.discards, 1, "compatibility tail discards original preparation once")
	assert_false(_fixture._router.start_work(_project, 100).ok, "duplicate start refuses")
	assert_equal(_owner.starts, 1, "duplicate cannot republish")


func test_refused_final_contact_never_publishes_or_spends_before_clean_retry() -> void:
	"""The existing Inventory-owned final guard remains ahead of both payment and physical START."""
	var inventory: PackedByteArray = _fixture._inventory.state_bytes()
	var claims: PackedByteArray = _fixture._pool.state_bytes()
	var funding: PackedByteArray = _fixture._funding.state_bytes()
	_owner.final_block = &"SYNTHETIC_UNPREPARED_WORKPIECE"
	assert_equal(_fixture._router.start_work(_project, 100).error, _owner.final_block, "final physical refusal")
	assert_equal(_owner.starts, 0, "no physical publication")
	assert_true(inventory == _fixture._inventory.state_bytes(), "goods byte-identical")
	assert_true(claims == _fixture._pool.state_bytes(), "claims byte-identical")
	assert_true(funding == _fixture._funding.state_bytes(), "receipt byte-identical")
	assert_false(_fixture._construction.has_work_begun(_project), "no paid work began")
	_owner.final_block = &""
	assert_true(_fixture._router.start_work(_project, 100).ok, "same exact goods retry")
	assert_equal(_owner.starts, 1, "one successful retry publication")


func test_manual_stale_and_foreign_owner_calls_cannot_borrow_start_window() -> void:
	"""A manually called observer does not acquire authority from coincident Project numbers."""
	_owner.publish_start(_project)
	_owner.publish_start(_project + Vector2i(0, 1))
	assert_equal(_owner.starts, 0, "no Router publication window")
	assert_true(_fixture._router.start_work(_project, 100).ok, "actual start")
	_owner.publish_start(_project)
	var foreign: StartOwner = _fixture._new_owner() as StartOwner
	foreign.publish_start(_project)
	assert_equal(_owner.starts, 1, "completed window cannot replay")
	assert_equal(foreign.starts, 0, "foreign owner cannot publish")


func test_nonconnector_start_retains_existing_discard_without_new_window() -> void:
	"""The existing spoil purpose does not receive a connector workpiece publication."""
	var tip: StartOwner = _fixture._owner as StartOwner
	var project: Vector2i = _fixture._open(tip)
	_fixture._job(project, false, _fixture._spawn_worker())
	_fixture._deliver(project)
	assert_true(_fixture._router.start_work(project, 100).ok, "ordinary paid purpose starts")
	assert_equal(tip.starts, 0, "no connector START callback")
	assert_equal(tip.discards, 1, "original preparation discarded once")
