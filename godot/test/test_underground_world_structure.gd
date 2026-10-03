extends "res://test/framework/test_case.gd"
## Real World structural dispatch and paid phases. Body/contact/service qualification stays explicitly synthetic.

const NaturalFixture := preload("res://test/test_underground_phase_structure.gd")
const PaidFixture := preload("res://test/test_underground_space_authority.gd")
const Scope := preload("res://scripts/core/underground_world_structure_scope.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Structure := preload("res://scripts/core/underground_phase_structure.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Authority := preload("res://scripts/core/underground_space_authority.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")


class ReleasingScope extends Scope:
	## A real identity observation may release external owners before the outer bind returns.
	var release_hook: Callable

	func exact_binding(owner: Owner, terrain: Terrain, levels: Levels, sites: Sites,
			budget: Budget) -> bool:
		"""Keep the normal actual proof, then release only this test's explicitly registered retainers."""
		var result: bool = super.exact_binding(owner, terrain, levels, sites, budget)
		if release_hook.is_valid():
			var callback: Callable = release_hook
			release_hook = Callable()
			callback.call()
		return result


class ObservedStructure extends NaturalFixture.ObservedStructure:
	## Real structural checks precede each adversarial post-callback condition.
	var composer: WeakRef = null
	var arena: Budget = null
	var mode: int = 0
	var nested: StringName = &""
	var replacement: int = 0
	var nested_query: int = 0
	var survey: Space.Snapshot = Space.Snapshot.new()
	var mask: PackedInt32Array = PackedInt32Array([7, 8, 9])
	var bounds: PackedInt32Array = PackedInt32Array([0, 0, 0, 1024, 1024, 1024])

	func _walk_claims() -> StringName:
		"""The real provider has retained query handles when the adversarial nested allocation is attempted."""
		if nested_query > 0:
			_attempt_nested(composer.get_ref() as WorldBindings)
		return super._walk_claims()

	func _attempt_nested(world: WorldBindings) -> void:
		"""Every nested entry uses the same exact valid original token, not an obviously foreign lease."""
		var action: int = nested_query
		nested_query = 0
		if action == 1:
			nested = world.composed_snapshot_into(bounds, survey, _cold_token)
		elif action == 2:
			nested = world.finish_mask_into(_site, _room, _cold_token, 64, mask)
		elif action == 3:
			world.floor_section(_site, _room)
		elif action == 4:
			world.begin_cold_operation(_actual_owner(), _site, _operation, _stage)
		elif action == 5:
			world.bind_room_bindings(null)

	func structure_refusal(site: Vector2i, operation: int, stage: int, room: Vector2i,
			token: int) -> StringName:
		"""A delegate's success cannot conceal an expired phase or nested attempt at its outer World owner."""
		var code: StringName = super.structure_refusal(site, operation, stage, room, token)
		var world: WorldBindings = composer.get_ref() as WorldBindings
		var action: int = mode
		mode = 0
		if action == 1:
			nested = world.structural_refusal(site, operation, stage, room)
		elif action == 2:
			world.end_cold_operation(token)
			replacement = arena.acquire(Budget.COLD_BYTES)
		return code


class BoundPhases extends NaturalFixture.StructuralBindings:
	## The old fixture keeps synthetic body/reach only; World owns real scope and structural dispatch.
	func begin_cold_operation(store: Owner, site: Vector2i, operation: int, stage: int) -> int:
		"""Observe actual phase identity without the old synthetic Scope's operation/stage fields."""
		cold_active = composer.begin_cold_operation(store, site, operation, stage)
		if cold_active == 0:
			return 0
		cold_opened += 1
		held_site = site
		held_room = sites.room_of(site)
		held_operation = operation
		held_stage = stage
		last_plan = null
		(owner as PaidFixture.ObservedSpace).last_snapshot = null
		(owner as PaidFixture.ObservedSpace).observed_token = cold_active
		return cold_active

	func phase_qualification_refusal(domain: Space.Domain, snapshot: Space.Snapshot,
			plan: Space.Plan, site: Vector2i, operation: int, stage: int) -> StringName:
		"""Keep the explicit synthetic body fixture, then independently require actual World structural dispatch."""
		var code: StringName = super.phase_qualification_refusal(domain, snapshot, plan, site, operation, stage)
		return composer.structural_refusal(site, operation, stage, sites.room_of(site)) if code == &"" else code

	func stage_physical_geometry(store: Owner, token: int, site: Vector2i,
			operation: int, stage: int, room: Vector2i, plan: Space.Plan) -> StringName:
		"""The real World delegates to its configured actual provider before the Authority seals anything."""
		held_owner_token = token
		last_structure_code = composer.stage_physical_geometry(store, token, site, operation, stage, room, plan)
		return last_structure_code

	func prepare_companions(token: int, site: Vector2i, operation: int,
			stage: int, room: Vector2i, _plan: Space.Plan) -> int:
		"""Only services/routes remain a test companion; actual future structure must pass World dispatch."""
		last_structure_code = composer.prepared_structure_refusal(token, site, operation, stage, room)
		pending = last_structure_code == &""
		return 1 if pending else 0

	func prepared_refusal(token: int) -> StringName:
		"""Repeat the actual sealed-future proof before physical payment commits."""
		if token != 1 or not pending:
			return &"FIXTURE_NO_COMPANION"
		return composer.prepared_structure_refusal(held_owner_token, held_site, held_operation, held_stage, held_room)


class ActualHarness extends NaturalFixture.ActualHarness:
	var actual_scope: Scope = null

	func _bind_space() -> void:
		"""Keep all real paid stores and replace only the structural dispatch portion of the fixture."""
		var bindings: BoundPhases = BoundPhases.new()
		_bindings = bindings
		bindings.source_reader = _sources
		bindings.owner = _owner
		bindings.buildings = _buildings
		bindings.jobs = _jobs
		bindings.inventory = _inventory
		bindings.floor_ref = _floor
		bindings.composer = composer
		_authority = Authority.new()
		assert_equal(_authority.configure(_owner, bindings, 1), &"", "actual paid authority")
		_sites = Sites.new(_construction, _inventory, _pool, _items, _jobs, _work, _authority, 512, 8)
		bindings.sites = _sites
		assert_equal(_sites.initialization_refusal(), &"", "actual Sites")
		assert_equal(_authority.bind_sites(_sites), &"", "actual Site namespace")
		var claimed: Construction.OpResult = _sites.claim_quantum(NaturalFixture.ORIGIN, _room)
		assert_true(claimed.ok, "actual physical quantum")
		_site = claimed.ref
		_configure_structure(bindings)

	func _configure_structure(bindings: NaturalFixture.StructuralBindings) -> void:
		"""Concrete Scope attests the real World/Level/Site; no caller boolean stands in for that adapter."""
		actual_scope = Scope.new()
		assert_equal(actual_scope.configure(composer, levels, budget), &"", "actual World Scope")
		var observed: ObservedStructure = ObservedStructure.new()
		observed.composer = weakref(composer)
		observed.arena = budget
		structure = observed
		assert_equal(structure.configure(actual_scope, _owner, terrain, levels, _sites, budget), &"", "actual provider")
		assert_equal(composer.bind_phase_structure(structure, levels), &"", "actual World structural binding")
		bindings.structure = structure

	func after_each() -> void:
		"""The actual adapter references its World weakly and cannot create a fixture ownership cycle."""
		actual_scope = null
		super.after_each()


var _h: ActualHarness = null


func before_each() -> void:
	"""Build real World, Level, Terrain, economic owners, sparse structure and the concrete Scope."""
	_h = ActualHarness.new()
	_h.before_each()
	assert_true(_h.failures.is_empty(), "actual composed setup")


func after_each() -> void:
	"""Release only the test-created replacement lease before normal actual-owner cleanup."""
	var observed: ObservedStructure = _h.structure as ObservedStructure
	if observed != null and observed.replacement > 0:
		assert_equal(_h.budget.release(observed.replacement), &"", "test releases its replacement")
	_h.after_each()
	assert_true(_h.failures.is_empty(), "actual paid and cleanup assertions")
	_h = null


func _query() -> StringName:
	"""One real synchronous World scope wraps the structural observation and releases after its images drop."""
	var token: int = _h._bindings.begin_cold_operation(_h._owner, _h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT)
	assert_true(token > 0, "actual cold lifetime")
	var code: StringName = _h.composer.structural_refusal(_h._site, Contract.OP_BRACE, Contract.STAGE_ADMIT, _h._room)
	_h._bindings.end_cold_operation(token)
	return code


func test_actual_structure_query_remains_separate_from_full_work_qualification() -> void:
	"""Natural earth can be proven without pretending the actual body, route or output contact is implemented."""
	var before: PackedByteArray = _h._owner.state_bytes()
	assert_equal(_query(), &"", "actual natural structural observation")
	assert_equal(_h._owner.state_bytes(), before, "query publishes no geometry")
	assert_equal(_h.composer.qualification_revision(), 0, "remaining actual composition stays closed")
	assert_true(_h.composer.structural_refusal(_h._site, Contract.OP_BRACE,
		Contract.STAGE_ADMIT, _h._room) != &"", "no scope after cleanup")
	assert_true(_h.composer.bind_phase_structure(_h.structure, _h.levels) != &"", "no rebinding")


func test_real_paid_brace_cut_finish_use_the_actual_world_structural_delegates() -> void:
	"""Funding, input consumption, work and geometry remain real while unsupported contact fixtures stay explicit."""
	_h._complete(Contract.OP_BRACE)
	_h._complete(Contract.OP_CUT)
	_h._complete(Contract.OP_FINISH)
	assert_true(_h._sites.installed_support(_h._site), "actual paid brace retained")
	assert_equal(_h._sites.earth_conservation_refusal(), &"", "earth conserved")
	assert_equal(_h._sites.support_conservation_refusal(), &"", "paid inputs conserved")
	assert_equal((_h._bindings as BoundPhases).last_structure_code, &"", "actual World dispatch")
	assert_equal(_h.composer.qualification_revision(), 0, "test bodies do not activate production")


func test_reentrant_delegate_cannot_hide_behind_outer_success() -> void:
	"""The production structural observer is real; only the callback ordering is adversarial."""
	var observed: ObservedStructure = _h.structure as ObservedStructure
	observed.mode = 1
	assert_equal(_query(), WorldBindings.REFUSE_BUSY, "outer read poisoned")
	assert_equal(observed.nested, WorldBindings.REFUSE_BUSY, "nested read refused")
	assert_equal(_query(), &"", "clean later scope remains usable")


func test_delegate_replacing_phase_lease_preserves_foreign_token() -> void:
	"""Even correct actual support cannot grant permission after its original cold context expires."""
	var observed: ObservedStructure = _h.structure as ObservedStructure
	observed.mode = 2
	assert_true(_query() != &"", "lost original scope refuses")
	assert_true(_h.budget.covers(observed.replacement, Budget.COLD_BYTES), "replacement remains owned by test")
	assert_false(_h._sites.installed_support(_h._site), "no free structural publication")


func _release_owner_retainers() -> void:
	"""These are fixture-owned references; no process or unrelated World is touched."""
	_h._authority._owner = null
	(_h._bindings as BoundPhases).owner = null
	_h._owner = null


func test_bind_holds_actual_owner_until_all_reciprocal_callbacks_finish() -> void:
	"""A success-returning Scope cannot make the public binding frame dereference an expired Owner."""
	var composer: WorldBindings = WorldBindings.new()
	assert_equal(composer.configure(_h.world_map, _h.terrain, _h._owner, _h._sources, _h.budget),
		&"", "second actual observer, no publication")
	var scope: ReleasingScope = ReleasingScope.new()
	assert_equal(scope.configure(composer, _h.levels, _h.budget), &"", "actual scoped observer")
	var provider: Structure = Structure.new()
	assert_equal(provider.configure(scope, _h._owner, _h.terrain, _h.levels, _h._sites, _h.budget),
		&"", "actual natural provider")
	var weak_owner: WeakRef = weakref(_h._owner)
	scope.release_hook = _release_owner_retainers
	assert_equal(composer.bind_phase_structure(provider, _h.levels), &"", "owner survives the complete synchronous bind")
	assert_null(weak_owner.get_ref(), "no new permanent Owner retention")
	assert_false(composer._structure_reading, "public guard always released")
	assert_equal(composer.binding_refusal(), WorldBindings.REFUSE_BINDING, "later query sees actual expired Owner")


func test_structural_callbacks_cannot_overlap_other_world_scratch() -> void:
	"""Refuse before clearing caller output or entering another allocating operation in the same arena."""
	var observed: ObservedStructure = _h.structure as ObservedStructure
	observed.survey.revision = 321
	for action: int in range(1, 6):
		observed.nested_query = action
		assert_equal(_query(), WorldBindings.REFUSE_BUSY, "outer structural read poisoned for operation%d" % action)
		assert_equal(observed.survey.revision, 321, "nested survey output unchanged")
		assert_equal(observed.mask, PackedInt32Array([7, 8, 9]), "nested finish-mask output unchanged")
		if action <= 2:
			assert_equal(observed.nested, WorldBindings.REFUSE_BUSY, "allocating entry explicitly refused")
	assert_equal(_query(), &"", "normal structural observation can retry after cleanup")
