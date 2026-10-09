extends "res://test/framework/test_case.gd"
## Actual World/Level/Site binding only. The inherited fixture's initial Room/Site permission is synthetic.

const Scope := preload("res://scripts/core/underground_world_structure_scope.gd")
const Fixture := preload("res://test/test_underground_room_bindings.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const LEVEL_PACK: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_HASH: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"


class ObservedLevels extends Levels:
	var binding_reads: int = 0

	func binding_matches(domain: Space.Domain, directory: Directory, version: int) -> bool:
		"""Count the real descriptor/identity allocation boundary without replacing its actual proof."""
		binding_reads += 1
		return super.binding_matches(domain, directory, version)


class ObservedWorld extends WorldBindings:
	## Preserve real World checks while injecting one callback at an actual scope boundary.
	var scope: WeakRef = null
	var levels: Levels = null
	var arena: Budget = null
	var mode: int = 0
	var replacement: int = 0
	var nested: StringName = &""
	var delayed_calls: int = 0

	func binding_refusal() -> StringName:
		"""The outer adapter must detect reentry or token replacement even when this callback returns success."""
		var code: StringName = super.binding_refusal()
		if delayed_calls > 0:
			delayed_calls -= 1
			return code
		var action: int = mode
		mode = 0
		if action == 1:
			nested = (scope.get_ref() as Scope).configure(self, levels, arena)
		elif action == 2:
			nested = arena.release(_phase_token)
			replacement = arena.acquire(Budget.COLD_BYTES)
		elif action == 3:
			nested = (scope.get_ref() as Scope).phase_refusal(_phase_token, _phase_site,
				_phase_operation, _phase_stage, _phase_room)
		elif action == 4:
			replacement = arena.acquire(Budget.COLD_BYTES)
		return code


var _actual: Fixture = null
var _world: ObservedWorld = null
var _levels: Levels = null
var _scope: Scope = null


func before_each() -> void:
	"""Use the actual generated World and immutable Level pack with the same full Directory and Domain."""
	_actual = Fixture.new()
	_actual.before_each()
	_actual._world_bindings.end_cold_operation(_actual._lease)
	_actual._lease = 0
	_world = ObservedWorld.new()
	assert_equal(_world.configure(_actual._world, _actual._terrain, _actual._owner,
		_actual._sources, _actual._budget), &"", "same actual World composition")
	_actual._world_bindings = _world
	_levels = _load_levels()
	_scope = Scope.new()
	_world.scope = weakref(_scope)
	_world.levels = _levels
	_world.arena = _actual._budget
	assert_true(_actual.failures.is_empty(), "actual fixture setup")


func _load_levels() -> Levels:
	"""A second equal catalog remains a distinct object and never replaces the configured one."""
	var levels: Levels = ObservedLevels.new()
	assert_equal(levels.load_file(LEVEL_PACK, LEVEL_HASH, 1), &"", "actual source-pinned pack")
	var domain: Space.Domain = _actual._owner.domain_copy()
	assert_equal(levels.bind_domain(domain, _actual._jobs.directory(), domain.descriptor(), Space.VERSION),
		&"", "actual Level identity")
	return levels


func after_each() -> void:
	"""Drop exact test-owned scope and replacement lease; all production references remain acyclic."""
	_world.mode = 0
	if _world.replacement > 0:
		assert_equal(_actual._budget.release(_world.replacement), &"", "release only test-created replacement")
	_scope = null
	_world = null
	_levels = null
	_actual.after_each()
	assert_true(_actual.failures.is_empty(), "actual fixture cleanup")
	_actual = null


func _bind() -> void:
	"""Bind the adapter while actual space and the single cold arena are quiescent."""
	assert_equal(_scope.configure(_world, _levels, _actual._budget), &"", "actual structural scope")


func _matches() -> bool:
	"""Read the exact configured owner tuple, without nominating alternate permission."""
	return _scope.exact_binding(_actual._owner, _actual._terrain, _levels, _actual._sites, _actual._budget)


func _phase() -> StringName:
	"""Present the actual admitted Site/Room and operation/stage together."""
	return _scope.phase_refusal(_actual._lease, _actual._site, Contract.OP_BRACE,
		Contract.STAGE_ADMIT, _actual._room)


func test_actual_binding_and_phase_match_without_granting_work() -> void:
	"""An exact actual tuple is observable, but the production contacts and complete qualification stay closed."""
	_bind()
	assert_true(_matches(), "all actual identities")
	assert_equal(_scope.phase_world_owner(), _world, "exact borrowed composer")
	assert_true(_phase() != &"", "quiescence supplies no cold phase")
	_actual._open_scope()
	assert_equal(_phase(), &"", "actual live phase")
	assert_equal(_world.qualification_revision(), 0, "identity is not physical qualification")
	assert_equal(_scope.configure(_world, _levels, _actual._budget), Scope.REFUSE_BINDING, "once-only binding")


func test_foreign_catalog_budget_and_missing_actual_owners_refuse() -> void:
	"""Equal authored data never makes another object the configured World collaborator."""
	_bind()
	assert_false(_scope.exact_binding(_actual._owner, _actual._terrain, _load_levels(),
		_actual._sites, _actual._budget), "equal Level data but another exact catalog")
	assert_false(_scope.exact_binding(_actual._owner, _actual._terrain, _levels,
		_actual._sites, Budget.new()), "another arena")
	assert_false(_scope.exact_binding(null, _actual._terrain, _levels,
		_actual._sites, _actual._budget), "missing Owner")
	assert_false(_scope.exact_binding(_actual._owner, null, _levels,
		_actual._sites, _actual._budget), "missing Terrain")
	assert_false(_scope.exact_binding(_actual._owner, _actual._terrain, _levels,
		null, _actual._budget), "missing physical ledger")
	assert_true(_matches(), "bad queries never replace configured identities")


func test_wrong_phase_tuple_and_released_token_refuse() -> void:
	"""The same exact Site has distinct boundaries; no stale stage or numeric generation substitutes."""
	_bind()
	_actual._open_scope()
	assert_true(_scope.phase_refusal(_actual._lease, _actual._site, Contract.OP_CUT,
		Contract.STAGE_ADMIT, _actual._room) != &"", "wrong operation")
	assert_true(_scope.phase_refusal(_actual._lease, _actual._site, Contract.OP_BRACE,
		Contract.STAGE_COMMIT, _actual._room) != &"", "wrong stage")
	assert_true(_scope.phase_refusal(_actual._lease, Vector2i(_actual._site.x, _actual._site.y + 1),
		Contract.OP_BRACE, Contract.STAGE_ADMIT, _actual._room) != &"", "stale Site")
	assert_true(_scope.phase_refusal(_actual._lease, _actual._site, Contract.OP_BRACE,
		Contract.STAGE_ADMIT, Vector2i(_actual._room.x, _actual._room.y + 1)) != &"", "stale Room")
	assert_equal(_phase(), &"", "original tuple still current")
	_world.end_cold_operation(_actual._lease)
	assert_true(_phase() != &"", "closed lease")
	_actual._lease = 0


func test_binding_requires_quiescence_and_rejects_nested_configuration() -> void:
	"""Failed and nested configuration cannot retain a partially accepted provider or Domain."""
	var token: int = _actual._budget.acquire(Budget.COLD_BYTES)
	assert_true(_scope.configure(_world, _levels, _actual._budget) != &"", "busy actual arena")
	assert_null(_scope.phase_world_owner(), "failed configuration retains no provider")
	assert_equal(_actual._budget.release(token), &"", "test releases own token")
	_world.mode = 1
	assert_equal(_scope.configure(_world, _levels, _actual._budget), Scope.REFUSE_BUSY, "outer reentry refused")
	assert_equal(_world.nested, Scope.REFUSE_BUSY, "nested reentry refused")
	assert_null(_scope.phase_world_owner(), "no partial configuration")
	_bind()
	assert_true(_matches(), "clean retry can bind")


func test_reentrant_observation_invalidates_outer_success_and_recovers() -> void:
	"""A success-returning actual callback cannot hide a nested attempt to borrow the same observer."""
	_bind()
	_actual._open_scope()
	_world.mode = 3
	assert_equal(_phase(), Scope.REFUSE_BUSY, "outer operation cannot hide reentry")
	assert_equal(_world.nested, Scope.REFUSE_BUSY, "nested observation refuses")
	assert_equal(_phase(), &"", "the observer can be used after cleanup")


func test_replacement_lease_is_detected_without_releasing_it() -> void:
	"""Even a full-size replacement token cannot inherit this phase's actual scope."""
	_bind()
	_actual._open_scope()
	_world.mode = 2
	assert_true(_phase() != &"", "lease lost inside actual callback")
	assert_equal(_world.nested, &"", "test released its exact active token")
	assert_true(_actual._budget.covers(_world.replacement, Budget.COLD_BYTES), "foreign replacement left intact")
	_world.end_cold_operation(_actual._lease)
	_actual._lease = 0
	assert_true(_actual._budget.covers(_world.replacement, Budget.COLD_BYTES), "cleanup cannot release replacement")


func test_catalog_revision_and_actual_world_retirement_are_rechecked() -> void:
	"""Immutable source/content lifetime is necessary on every observation, not just at configuration."""
	_bind()
	_actual._open_scope()
	_levels._revision += 1
	assert_false(_matches(), "changed Level content")
	assert_true(_phase() != &"", "changed content cannot attest phase")
	_levels._revision -= 1
	assert_equal(_phase(), &"", "original content identity restored")
	_actual._world.clear()
	assert_false(_matches(), "actual World retired")
	assert_true(_phase() != &"", "retired World cannot attest phase")


func test_inner_identity_callback_cannot_allocate_levels_under_replaced_phase() -> void:
	"""The first cold check succeeds; a later binding callback loses the lease before Level scratch."""
	_bind()
	_actual._open_scope()
	var before: int = (_levels as ObservedLevels).binding_reads
	_world.delayed_calls = 1
	_world.mode = 2
	assert_true(_phase() != &"", "second callback replaced original lease")
	assert_equal((_levels as ObservedLevels).binding_reads, before, "no Level allocation after inner revoke")
	assert_equal(_world.nested, &"", "test revoked its exact token")
	assert_true(_actual._budget.covers(_world.replacement, Budget.COLD_BYTES), "replacement preserved")


func test_exact_binding_pins_token_before_first_callback_and_configuration_checks_quiescence() -> void:
	"""Both cold observation and initial configuration refuse before their next allocating identity read."""
	var before: int = (_levels as ObservedLevels).binding_reads
	_world.mode = 4
	assert_true(_scope.configure(_world, _levels, _actual._budget) != &"", "configuration lost quiescence")
	assert_equal((_levels as ObservedLevels).binding_reads, before, "no initial Level allocation")
	assert_equal(_actual._budget.release(_world.replacement), &"", "test releases its own allocation")
	_world.replacement = 0
	_bind()
	_actual._open_scope()
	before = (_levels as ObservedLevels).binding_reads
	_world.mode = 2
	assert_false(_matches(), "exact identity read lost its original token")
	assert_equal((_levels as ObservedLevels).binding_reads, before, "no cold Level allocation after revoke")
