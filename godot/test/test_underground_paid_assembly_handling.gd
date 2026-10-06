extends "res://test/framework/test_case.gd"
## Real source and original paid owners. Diagnostic publication is explicit; no synthetic productive permission.

const SourcePhases := preload("res://test/test_underground_entry_source_phases.gd")
const WorkArea := preload("res://test/test_underground_entry_work_area.gd")
const PaidPhaseFixture := preload("res://test/test_underground_entry_world_bindings.gd")
const PaidGroundTests := preload("res://test/test_underground_surface_anchor.gd")
const Prefix := preload("res://test/test_underground_first_prefix.gd")
const Workpieces := preload("res://scripts/core/underground_connector_workpieces.gd")
const PaidConstruction := preload("res://scripts/core/construction.gd")
const PaidContract := preload("res://scripts/core/modular_project_contract.gd")
const PaidRoutes := preload("res://scripts/core/underground_routes.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Retirement := preload("res://scripts/core/underground_entry_contact_retirement.gd")
const Foreman := preload("res://scripts/core/underground_entry_foreman.gd")
const WorkAreaTests := preload("res://test/test_underground_entry_work_area.gd")
const Assembly := preload("res://data/underground/mole-worker/qualified-assembly-v1/source_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)


class ObservedPaidTerrain extends PaidGroundTests.CountedTerrain:
	var source_probe: Callable = Callable()

	func local_facts_refusal(bounds: PackedInt32Array, purpose: int, expected_revision: int) -> StringName:
		"""Run the full original local query before the caller closes its exact source/lease scope."""
		var code: StringName = super.local_facts_refusal(bounds, purpose, expected_revision)
		if code == &"" and source_probe.is_valid():
			var callback: Callable = source_probe
			source_probe = Callable()
			callback.call()
		return code


class ObservedPaidContacts extends PaidPhaseFixture.ObservedContacts:
	var release_probe: Callable = Callable()
	var handling_probe: Callable = Callable()

	func release_observation_refusal(placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i) -> StringName:
		"""An actual successful source/body observation may be followed by a hostile late callback."""
		var code: StringName = super.release_observation_refusal(placement, project, worker, job)
		if code == &"" and release_probe.is_valid():
			var callback: Callable = release_probe
			release_probe = Callable()
			callback.call()
		return code

	func handling_observation_refusal(placement: Vector2i, project: Vector2i, worker: Vector2i, job: Vector2i) -> StringName:
		"""Promotion must reprove its original current tuple after the final observation returns."""
		var code: StringName = super.handling_observation_refusal(placement, project, worker, job)
		if code == &"" and handling_probe.is_valid():
			var callback: Callable = handling_probe
			handling_probe = Callable()
			callback.call()
		return code


class PaidWorld extends WorkArea.SourceWorld:
	func _actual_catalog(domain: Prefix.Space.Domain) -> void:
		"""Install the observing Terrain before any graph/Anchor/paid owner borrows it; no live owner is rebound."""
		_terrain = ObservedPaidTerrain.new()
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "original observing Terrain")
		super._actual_catalog(domain)


class PaidProbe extends WorkArea.Probe:
	var pieces: Workpieces = null
	var handled_l0: bool = false
	var installed_l0: bool = false

	func _make_world() -> Prefix.ActualWorld:
		"""Select the complete immutable bank before binding any original owner."""
		return PaidWorld.new()

	func _make_contacts() -> Contacts:
		"""Retain the actual source implementation and its explicit pre-final observation seam."""
		return ObservedPaidContacts.new()

	func before_each() -> void:
		"""Bind one actual paid workpiece owner before any live entry or Project is created."""
		super.before_each()
		if not failures.is_empty(): return
		pieces = Workpieces.new()
		assert_equal(pieces.configure(4, 2, Workpieces.required_bytes(4, 2)), &"", "original finite banks")
		assert_equal(pieces.bind_actual(_placements, _router, _paid), &"", "original paid source tuple")
		assert_equal(pieces.load_file(WorkArea.Bundle.WORKPIECES_PATH, WorkArea.Bundle.WORKPIECES_SHA, WorkArea.Bundle.WORKPIECES_REVISION), &"", "exact two source-derived workpieces")
		assert_equal(_paid.bind_workpieces(pieces), &"", "actual reciprocal activation")

	func after_each() -> void:
		"""Release only this fixture's original graph after checking synchronous lease ownership."""
		if pieces != null: assert_true(pieces.is_quiescent(), "no escaped piece transaction")
		pieces = null
		super.after_each()

	func _installation_job(project: Vector2i, endpoint: Vector2i) -> int:
		"""A real BUILD Job and equipped tool travel to the supported station before selecting handling READY."""
		var quote: Modular.Quote = Modular.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual complete bill")
		var made: Jobs.OpResult = _world._jobs.create_job(quote.job_kind, 0, 0, quote.remaining_mwu, 0)
		assert_true(made.ok, "actual assembly Job")
		if not made.ok: return -1
		assert_true(_world._jobs.set_requester(made.value, project).ok, "actual Project requester")
		assert_true(_world._jobs.set_tool_gate(made.value, Jobs.GATE_SATISFIED).ok, "actual tool gate")
		assert_true(_router.bind_job(project, made.ref).ok, "exact primary Job")
		var worker: int = _world._residents.directory().get_typed_row(_world._worker)
		assert_true(_world._jobs.assign_worker(worker, made.value).ok, "same actual worker")
		assert_true(_world._work.claim_tool_for_work(worker, _tool).ok, "same equipped tool")
		_move_to_handling_station(made.value, endpoint)
		if not failures.is_empty(): return -1
		assert_equal(_world._routes.refresh_work_actor(_world._worker, made.ref, 29, 1, WorkArea.Bundle.CONTENT_REVISION, 0, -1, _tool), &"", "actual pre-funded handling READY")
		return made.value if failures.is_empty() else -1

	func _move_to_handling_station(job: int, endpoint: Vector2i) -> void:
		"""ADR1191: all-yaw source12 reaches material M; only the narrow same-heading source2 approaches H."""
		var ref: Vector2i = _world._jobs.ref_of(job)
		assert_equal(_world._routes.refresh_travel_actor(_world._worker, ref, 12, 1, WorkArea.Bundle.CONTENT_REVISION, 0, -1, _tool), &"", "actual source WALK handoff")
		_travel_to(ref, _endpoints[1], 12, "material endpoint")
		if not failures.is_empty(): return
		var profiles: Profiles = _world._profiles
		assert_equal(profiles._field(profiles._live, 2, Profiles.F_YAW_KIND), Profiles.YAW_EXACT, "source2 is a fixed-heading approach")
		var heading: int = profiles._field(profiles._live, 2, Profiles.F_YAW)
		assert_equal(WorldRoutes.turn_actor(_world._binding, _world._worker, ref, heading, Space.MAX_CHECKS), &"", "all-yaw turn to the source2 heading at M")
		assert_equal(_world._routes.refresh_travel_actor(_world._worker, ref, 2, 1, WorkArea.Bundle.CONTENT_REVISION, 0, -1, _tool), &"", "narrow approach source at M")
		_travel_to(ref, endpoint, 2, "handling station")
		if not failures.is_empty(): return
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_world._routes.read_actor_into(_world._worker, actor), &"", "actor at H")
		assert_equal(actor.yaw, profiles._field(profiles._live, 29, Profiles.F_YAW), "same-heading approach arrives at the handling yaw; H admits no turn")

	func _travel_to(ref: Vector2i, endpoint: Vector2i, profile: int, label: String) -> void:
		"""Advance real route ticks until the actor stands source-ready at the exact endpoint."""
		assert_equal(_world._routes.request_route(_world._worker, endpoint, _tick), &"", "actual %s itinerary" % label)
		if not failures.is_empty(): return
		var actor: Routes.Actor = Routes.Actor.new()
		for step: int in 600:
			_world._routes.advance_tick(_tick); _tick += 1
			assert_equal(_world._routes.read_actor_into(_world._worker, actor), &"", "actual travel actor")
			if actor.phase == Routes.PHASE_HELD:
				assert_true(false, "actual %s travel held" % label)
				return
			if actor.location == endpoint and Routes.source_ready_leaf_refusal(_world._routes, _world._worker,
					ref, profile, 1, WorkArea.Bundle.CONTENT_REVISION) == &"": break
		assert_equal(actor.location, endpoint, "real %s reached" % label)

	func prepare_l0() -> Vector2i:
		"""All actual excavation and source travel precede the still-unfunded handling Job."""
		execute_l0_cubes()
		if not completed_l0: return NULL_REF
		var project: Vector2i = _open_installation(0)
		if project == NULL_REF: return NULL_REF
		var job: int = _installation_job(project, _endpoints[0])
		return project if job >= 0 and failures.is_empty() else NULL_REF

	func handle_l0() -> Vector2i:
		"""Real four-cube payment precedes timber payment, sixty positioning ticks and the only state1→2 promotion."""
		var project: Vector2i = prepare_l0()
		if project == NULL_REF: return NULL_REF
		var job: int = _router._primary_row(project)
		deliver_installation_inputs(project, job)
		retire_first_pair(project, job)
		if not failures.is_empty(): return NULL_REF
		var started: Construction.OpResult = _router.start_work(project, 0)
		assert_true(started.ok, "actual paid installation START: %s" % started.error)
		if not started.ok: return NULL_REF
		var placement: Vector2i = _world._construction.subject_ref_of(project)
		assert_equal(pieces._live.present[placement.x], Workpieces.PENDING_HANDLING, "START is pending only")
		assert_equal(_world._inventory.lot_quantity_milli(_wood), 1500, "one whole L0 bill paid")
		assert_equal(_world._routes.begin_assembly_handling(_world._worker, _world._jobs.ref_of(job)), &"", "actual handling entry")
		if not failures.is_empty(): return NULL_REF
		var work_before: PackedByteArray = _world._work.state_bytes()
		var jobs_before: PackedByteArray = _world._jobs.state_bytes()
		var inventory_before: PackedByteArray = _world._inventory.state_bytes()
		for step: int in 60:
			assert_false(Routes.assembly_handled_ready_leaf_refusal(_world._routes, _world._worker,
				_world._jobs.ref_of(job), 29, 1, WorkArea.Bundle.CONTENT_REVISION) == &"", "no premature handling completion")
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.assembly_handled_ready_leaf_refusal(_world._routes, _world._worker,
			_world._jobs.ref_of(job), 29, 1, WorkArea.Bundle.CONTENT_REVISION), &"", "exact thirty entry plus thirty recovery ticks")
		assert_equal(_world._work.state_bytes(), work_before, "handling earns no WU or XP")
		assert_equal(_world._jobs.state_bytes(), jobs_before, "no productive progress")
		assert_equal(_world._inventory.state_bytes(), inventory_before, "no repeated material payment")
		assert_equal(_paid.complete_handling(placement, project, _world._worker, _world._jobs.ref_of(job)), &"", "actual observed promotion")
		assert_equal(pieces._live.present[placement.x], Workpieces.HANDLED, "only complete positioning promotes")
		handled_l0 = failures.is_empty()
		return project if handled_l0 else NULL_REF

	func retire_first_pair(project: Vector2i, job: int) -> void:
		"""ADR1191: the worker is READY at H and the bill unpaid; only then the first dig pair retires."""
		var owners: Retirement.Owners = Retirement.Owners.new()
		owners.contacts = _contacts
		owners.locations = _world._locations
		owners.binding = _world._binding
		owners.routes = _world._routes
		owners.budget = _world._budget
		owners.placement = _world._construction.subject_ref_of(project)
		owners.project = project
		owners.worker = _world._worker
		owners.job = _world._jobs.ref_of(job)
		owners.first = _endpoints[3]
		owners.second = _endpoints[4]
		var locations_before: int = _world._locations._live.count
		assert_equal(Retirement.retire_completed_pair(owners), &"", "completed first dig pair retires")
		assert_equal(_world._locations._live.count, locations_before - 2, "exactly two Locations leave")
		assert_false(_world._locations.is_live_location(_endpoints[3]) or _world._locations.is_live_location(_endpoints[4]), "retired handles are gone")

	func deliver_installation_inputs(project: Vector2i, job: int) -> void:
		"""Existing Inventory claims make the complete real bill READY before the separate unfunded worker observation."""
		var quote: Modular.Quote = Modular.Quote.new()
		assert_equal(_router.project_facts_into(project, quote), &"", "actual delivery quote")
		assert_equal(quote.input_count, 1, "actual wood-only assembly")
		assert_true(_router.bind_material_container(project, _storage).ok, "actual material destination")
		var batch: PackedInt64Array = PackedInt64Array([_wood.x, _wood.y, Reservations.PURPOSE_MODULAR_INPUT,
			quote.input_milli[0], 100000])
		assert_true(_world._pool.claim_batch(_world._jobs.ref_of(job), batch, 1, _world._inventory).ok, "actual complete wood claim")
		assert_true(_router.record_deliveries(project).ok, "actual complete delivery makes Project READY")

	func install_l0() -> void:
		"""Canonical handling READY hands off to the unchanged INSTALL source; only real Work earns fastening."""
		var project: Vector2i = handle_l0()
		if project == NULL_REF: return
		var job: int = _router._primary_row(project)
		begin_install(job)
		if failures.is_empty(): finish_install(job)

	func begin_install(job: int) -> void:
		"""Handled READY normalizes, then the unchanged INSTALL source reaches WORK without earning anything."""
		assert_equal(_world._routes.request_source_ready(_world._worker, _world._jobs.ref_of(job)), &"", "handled state normalizes to READY")
		assert_equal(_world._routes.refresh_work_actor(_world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION, 0, -1, _tool), &"", "actual unchanged INSTALL source")
		for step: int in 240:
			if Routes.source_work_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION) == &"": break
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.source_work_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION), &"", "actual INSTALL WORK")

	func finish_install(job: int) -> void:
		"""Earn all fastening work, recover the INSTALL source and commit the one whole group."""
		var project: Vector2i = _router_project(job)
		_earn_actual_phase(job)
		if not failures.is_empty(): return
		assert_equal(_world._routes.request_source_ready(_world._worker, _world._jobs.ref_of(job)), &"", "actual INSTALL recovery")
		for step: int in 240:
			if Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION) == &"": break
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION), &"", "INSTALL full recovery before release")
		if not failures.is_empty(): return
		var completed: Construction.OpResult = _router.complete_order(project)
		assert_true(completed.ok, "actual paid L0 commit: %s" % completed.error)
		installed_l0 = completed.ok and failures.is_empty()

	func recover_install(job: int) -> void:
		"""A paused worker finishes the real INSTALL recovery before any cancellation may settle."""
		assert_equal(_world._routes.request_source_ready(_world._worker, _world._jobs.ref_of(job)), &"", "INSTALL recovery requested")
		for step: int in 240:
			if Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION) == &"": break
			_world._routes.advance_tick(_tick); _tick += 1
		assert_equal(Routes.source_ready_leaf_refusal(_world._routes, _world._worker, _world._jobs.ref_of(job), 16, 1, WorkArea.Bundle.CONTENT_REVISION), &"", "INSTALL recovered")

	func _router_project(job: int) -> Vector2i:
		"""The Job's requester is the exact paid Project."""
		return Vector2i(_world._jobs._requester_slot[job], _world._jobs._requester_generation[job])


var _probe: PaidProbe = null


func after_each() -> void:
	"""Nested helper assertions stay visible without inflating the outer framework count."""
	if _probe != null:
		_probe.after_each()
		assert_true(_probe.failures.is_empty(), "actual source fixture: %s" % _probe.failures)
	_probe = null


func test_real_l0_requires_paid_handling_before_unchanged_productive_install() -> void:
	"""One real worker digs four cubes, pays the actual whole bill, handles, fastens and publishes one prefix."""
	_probe = PaidProbe.new()
	_probe.before_each()
	_probe.install_l0()
	assert_true(_probe.failures.is_empty(), "actual paid handling: %s" % _probe.failures)
	assert_true(_probe.handled_l0, "actual positioning completed")
	assert_true(_probe.installed_l0, "actual whole L0 installed")
	assert_equal(_probe._accepted_work_mwu, 68000, "only36000 excavation plus32000 fastening work")


func test_actual_prefunded_ready_pause_releases_worker_without_handling_or_payment() -> void:
	"""A real READY source need not manipulate or pay a bearer merely to pause its unstarted Project."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unstarted assembly exists: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	var job: int = _probe._router._primary_row(project)
	var inventory: PackedByteArray = _probe._world._inventory.state_bytes()
	var geometry: PackedByteArray = _probe._world._owner.state_bytes()
	var pieces: PackedByteArray = _probe.pieces._live.present.duplicate()
	var paused: PaidConstruction.OpResult = _probe._router.set_paused(project, true)
	assert_true(paused.ok, "actual pre-funded pause: %s" % paused.error)
	assert_equal(_probe._world._jobs.worker_of(job), Prefix.NULL_REF, "safe READY worker released")
	assert_equal(_probe._world._inventory.state_bytes(), inventory, "no payment")
	assert_equal(_probe._world._owner.state_bytes(), geometry, "no obstacle or installed geometry")
	assert_equal(_probe.pieces._live.present, pieces, "no handling state")
	assert_equal(_probe._accepted_work_mwu, 36000, "only prior excavation work")
	assert_true(_probe._router.set_paused(project, true).ok, "repeat pause keeps the same safe terminal state")


func test_actual_unfunded_handling_worker_observation_does_not_mint_start() -> void:
	"""The actual READY worker may be observed before START; altered payment, phase or clock cannot inherit it."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unfunded handling station: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	var placement: Vector2i = _probe._world._construction.subject_ref_of(project)
	var job: Vector2i = _probe._world._jobs.ref_of(_probe._router._primary_row(project))
	var worker: Vector2i = _probe._world._worker
	var row: int = _probe._world._residents.directory().get_typed_row(project)
	var resident: int = _probe._world._residents.directory().get_typed_row(worker)
	_probe.deliver_installation_inputs(project, _probe._router._primary_row(project))
	assert_true(_probe.failures.is_empty(), "real input delivery: %s" % _probe.failures)
	assert_equal(_probe._world._construction._phase[row], PaidConstruction.PHASE_READY, "actual complete bill made economic READY")
	var inventory: PackedByteArray = _probe._world._inventory.state_bytes()
	var funding: PackedByteArray = _probe._router._funding.state_bytes()
	var geometry: PackedByteArray = _probe._world._owner.state_bytes()
	assert_equal(_probe._paid._stage_action, -1, "no owner transition prepared")
	assert_equal(_probe._contacts.worker_refusal(placement, project, 0, job, worker), &"", "actual source29 READY before START")
	assert_equal(_probe._paid._stage_action, -1, "observation cannot mint START")
	assert_equal(Workpieces._assigned_worker_leaf(_probe.pieces, project, worker, job), &"", "actual RESERVED full assignment")
	assert_false(Workpieces._handling_worker_leaf(_probe.pieces, project, worker, job) == &"", "assignment alone grants no active handling")
	_probe._world._construction._work_begun[row] = 1
	assert_false(_probe._contacts.worker_refusal(placement, project, 0, job, worker) == &"", "changed work-begun refuses")
	_probe._world._construction._work_begun[row] = 0
	_probe._world._construction._phase[row] = PaidConstruction.PHASE_WORKING
	assert_false(_probe._contacts.worker_refusal(placement, project, 0, job, worker) == &"", "changed economic phase refuses")
	_probe._world._construction._phase[row] = PaidConstruction.PHASE_READY
	_probe._router._funding._project_slot[row] = project.x
	_probe._router._funding._project_generation[row] = project.y
	assert_false(_probe._contacts.worker_refusal(placement, project, 0, job, worker) == &"", "unexpected receipt cannot inherit unfunded observation")
	_probe._router._funding._project_slot[row] = -1
	_probe._router._funding._project_generation[row] = 0
	var word_index: int = PaidRoutes.R_PHASE * PaidRoutes.RESIDENT_CAPACITY + resident
	var original_word: int = _probe._world._routes._motion.resident[word_index]
	_probe._world._routes._motion.resident[word_index] = Assembly.word(PaidRoutes.PHASE_IDLE, Assembly.Clock.ENTRY)
	assert_false(_probe._contacts.worker_refusal(placement, project, 0, job, worker) == &"", "non-READY source refuses")
	_probe._world._routes._motion.resident[word_index] = original_word
	assert_equal(_probe._contacts.worker_refusal(placement, project, 0, job, worker), &"", "restored original READY tuple observes again")
	assert_false(_probe._paid.final_funding_refusal(project, PaidContract.ACTION_WIP) == &"", "observation never substitutes for prepared START")
	assert_equal(_probe._paid._stage_action, -1, "no retained transition")
	assert_equal(_probe._world._inventory.state_bytes(), inventory, "no payment or claims written")
	assert_equal(_probe._router._funding.state_bytes(), funding, "receipt unchanged")
	assert_equal(_probe._world._owner.state_bytes(), geometry, "no prospective obstacle published")
	assert_equal(_probe.pieces._live.present[placement.x], Workpieces.EMPTY, "no workpiece state published")


func _late_release_move(point: Vector3i, called: PackedInt32Array) -> void:
	"""The external observer's real pose change is retained; the paused release must refuse around it."""
	called[0] += 1
	assert_true(_probe._world._transforms.place(_probe._world._worker, point.x + 1, point.y, point.z, 0), "late actual pose mutation")


func _late_release_reenter(project: Vector2i, called: PackedInt32Array) -> void:
	"""A nested pause cannot reuse its caller's final publication window."""
	called[0] += 1
	assert_false(_probe._router.set_paused(project, true).ok, "nested real Router call refuses")


func test_actual_prefunded_pause_closes_late_pose_and_reentrant_observers() -> void:
	"""Pause takes effect immediately, but neither a stale physical proof nor nested release loses the Job/tool."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unfunded READY: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	var job: int = _probe._router._primary_row(project)
	var worker: Vector2i = _probe._world._worker
	var point: Vector3i = Vector3i(_probe._world._routes._selection.x, _probe._world._routes._selection.y,
		_probe._world._routes._selection.z)
	var jobs: PackedByteArray = _probe._world._jobs.state_bytes()
	var work: PackedByteArray = _probe._world._work.state_bytes()
	var inventory: PackedByteArray = _probe._world._inventory.state_bytes()
	var geometry: PackedByteArray = _probe._world._owner.state_bytes()
	var called: PackedInt32Array = PackedInt32Array([0])
	(_probe._contacts as ObservedPaidContacts).release_probe = _late_release_move.bind(point, called)
	assert_false(_probe._router.set_paused(project, true).ok, "late successful observer cannot publish stale release")
	assert_equal(called[0], 1, "actual late boundary was reached")
	assert_true(_probe._world._construction.is_paused(project), "pause is immediate despite pending safe release")
	assert_equal(_probe._world._jobs.state_bytes(), jobs, "same complete Job and worker mirrors")
	assert_equal(_probe._world._work.state_bytes(), work, "same actual tool claim")
	assert_equal(_probe._world._inventory.state_bytes(), inventory, "no resource mutation")
	assert_equal(_probe._world._owner.state_bytes(), geometry, "no physical publication")
	assert_true(_probe._world._transforms.place(worker, point.x, point.y, point.z, 0), "restore actual original pose for fresh retry")
	(_probe._contacts as ObservedPaidContacts).release_probe = _late_release_reenter.bind(project, called)
	assert_false(_probe._router.set_paused(project, true).ok, "nested real pause poisons outer final window")
	assert_equal(called[0], 2, "actual reentry boundary was reached")
	assert_equal(_probe._world._jobs.state_bytes(), jobs, "no nested release")
	assert_equal(_probe._world._work.state_bytes(), work, "tool remains through reentry refusal")
	assert_true(_probe._router.set_paused(project, true).ok, "fresh original READY retry releases safely")
	assert_equal(_probe._world._jobs.worker_of(job), Prefix.NULL_REF, "release follows final original physical proof")


func _late_release_drop_tool_lot(resident: int, lot: Vector2i, job: Vector2i, called: PackedInt32Array) -> void:
	"""A late independent Gear release must not hide a half-cleared Work binding from the final crew leaf."""
	called[0] += 1
	assert_true(_probe._world._gear.cancel_claim(lot, job).ok, "actual Gear claim released by the late observer")
	_probe._world._work._tool_lot_slot[resident] = -1
	_probe._world._work._tool_lot_generation[resident] = 0


func test_actual_prefunded_pause_refuses_unpaired_tool_job_with_or_without_gear_claim() -> void:
	"""The actual release must preserve assignment when Work's lot disappears but its original Job pair remains."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unfunded READY: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	var resident: int = _probe._world._residents.directory().get_typed_row(_probe._world._worker)
	var job: Vector2i = _probe._world._jobs.ref_of(_probe._router._primary_row(project))
	var lot: Vector2i = _probe._world._work.tool_lot_of(resident)
	var jobs: PackedByteArray = _probe._world._jobs.state_bytes()
	var inventory: PackedByteArray = _probe._world._inventory.state_bytes()
	_probe._world._work._tool_lot_slot[resident] = -1
	_probe._world._work._tool_lot_generation[resident] = 0
	assert_false(_probe._router.set_paused(project, true).ok, "retained actual Gear claim closes the original whole-path refusal")
	assert_equal(_probe._world._jobs.state_bytes(), jobs, "original worker retained with live Gear claim")
	assert_equal(_probe._world._work.tool_job_of(resident), job, "refusal does not erase the inconsistent observer state")
	_probe._world._work._tool_lot_slot[resident] = lot.x
	_probe._world._work._tool_lot_generation[resident] = lot.y
	var called: PackedInt32Array = PackedInt32Array([0])
	(_probe._contacts as ObservedPaidContacts).release_probe = _late_release_drop_tool_lot.bind(resident, lot, job, called)
	assert_false(_probe._router.set_paused(project, true).ok, "final paired binding refuses even after actual Gear claim disappears")
	assert_equal(called[0], 1, "the actual successful physical observer was reached before mutation")
	assert_equal(_probe._world._jobs.state_bytes(), jobs, "no worker release can strand the original Work Job binding")
	assert_equal(_probe._world._work.tool_job_of(resident), job, "late observer mutation alone remains visible")
	assert_equal(_probe._world._inventory.state_bytes(), inventory, "no paid or loose stock changes")


func _arm_pre_stage_probe(kind: int, observed: PackedInt64Array) -> void:
	"""The actual local Terrain query precedes the concrete source and occupancy leaves."""
	var terrain: ObservedPaidTerrain = _probe._world._terrain as ObservedPaidTerrain
	terrain.source_probe = _mutate_pre_stage_scope.bind(kind, observed)


func _mutate_pre_stage_scope(kind: int, observed: PackedInt64Array) -> void:
	"""The original callback may alter its visible context or replace its lease, never grant a physical result."""
	if not _probe._placements._busy or _probe._placements._prepared_action != PaidContract.START:
		_arm_pre_stage_probe(kind, observed)
		return
	assert_true(_probe._placements._busy, "original Placement is synchronously preparing")
	assert_equal(_probe._placements._prepared_action, PaidContract.START, "exact original START action")
	assert_equal(_probe._placements._space_token, 0, "original pre-copy boundary reached")
	assert_equal(_probe._placements._location_token, 0, "no endpoint candidate exists")
	assert_equal(_probe._placements._route_token, 0, "no route candidate exists")
	observed[0] += 1
	if kind == 0:
		_probe._placements._context.project = Prefix.NULL_REF
	elif kind == 1:
		_probe._placements._context.space_token = 1
	else:
		var budget: Prefix.Budget = _probe._world._budget
		assert_equal(budget.release(_probe._placements._cold_token), &"", "observer releases only the original lease")
		observed[1] = budget.acquire(Prefix.Budget.COLD_BYTES)
		assert_true(observed[1] > 0, "actual different owner acquires an equal-sized lease")


func _start_spatial_image() -> Array[PackedByteArray]:
	"""Capture complete coupled live payloads and allocation metadata, not just counts or visible geometry."""
	var locations: Prefix.Locations.Bank = _probe._world._locations._live
	var graph: PaidRoutes.EdgeBank = _probe._world._routes._live
	var masks: Prefix.WorldRoutes.Certificates = _probe._world._binding._live
	var motion: PaidRoutes.MotionBank = _probe._world._routes._motion
	var placement: Prefix.Placements.Bank = _probe._placements._live
	return [_probe._world._owner.state_bytes(),
		var_to_bytes([locations.header, locations.i32, locations.i64, locations.present, locations.retired,
			locations.free_rows, locations.ordered, locations.free_count, locations.count]),
		var_to_bytes([graph.fields, graph.longs, graph.present, graph.retired, graph.free_rows, graph.ordered,
			graph.vertices, graph.free_count, graph.edge_count, graph.vertex_count, graph.revision]),
		var_to_bytes([masks.masks, masks.generations, masks.geometry, masks.content]),
		var_to_bytes([motion.resident, motion.resident_long, motion.links, motion.free_links, motion.free_count]),
		var_to_bytes([placement.header, placement.digests, placement.i32, placement.i64, placement.present,
			placement.retired, placement.openings, placement.opening_revision, placement.free_rows,
			placement.free_openings, placement.free_count, placement.opening_free_count]),
		var_to_bytes([_probe.pieces._live.fields, _probe.pieces._live.present])]


func _check_pre_stage_refusal(project: Vector2i, kind: int) -> void:
	"""Each actual rejected START preserves original goods, paid owners, actor and every coupled live bank."""
	var economic: Array[PackedByteArray] = _probe._economic_image()
	var spatial: Array[PackedByteArray] = _start_spatial_image()
	var observed: PackedInt64Array = PackedInt64Array([0, 0])
	_arm_pre_stage_probe(kind, observed)
	var result: PaidConstruction.OpResult = _probe._router.start_work(project, 0)
	(_probe._world._terrain as ObservedPaidTerrain).source_probe = Callable()
	assert_false(result.ok, "changed original pre-stage context or lease refuses")
	assert_equal(observed[0], 1, "actual source observer ran inside the original pre-copy START")
	_probe._assert_economic_image(economic)
	assert_equal(_start_spatial_image(), spatial, "all live spatial/actor/paid-piece bytes remain unchanged")
	assert_equal(_probe._world._owner._stage_token, 0, "original Space candidate cleaned")
	assert_equal(_probe._world._locations._token, 0, "original Location candidate cleaned")
	assert_equal(_probe._world._routes._token, 0, "original Routes candidate cleaned")
	if kind == 2:
		assert_true(_probe._world._budget.covers(observed[1], Prefix.Budget.COLD_BYTES), "cleanup preserves the new unrelated owner")
		assert_equal(_probe._world._budget.release(observed[1]), &"", "only the replacement caller releases its lease")
	assert_true(_probe._world._budget.is_quiescent(), "all original transaction controls are available for retry")


func test_actual_start_refuses_changed_pre_stage_context_and_original_cold_lease() -> void:
	"""Real paid excavation and source29 READY do not excuse changed context, partial tokens or a replaced cold owner."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unfunded READY: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	_probe.deliver_installation_inputs(project, _probe._router._primary_row(project))
	assert_true(_probe.failures.is_empty(), "original Inventory delivery: %s" % _probe.failures)
	for kind: int in 3:
		_check_pre_stage_refusal(project, kind)
	assert_equal(_probe._accepted_work_mwu, 36000, "only the four actual completed excavation cubes earned work")


func _installing_probe() -> Vector2i:
	"""Real L0 through handling and the INSTALL source handoff, before any fastening work is earned."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.handle_l0()
	if project == NULL_REF: return NULL_REF
	_probe.begin_install(_probe._router._primary_row(project))
	return project if _probe.failures.is_empty() else NULL_REF


func test_real_install_removes_piece_before_retiring_project_and_installs_once() -> void:
	"""Moved from the synthetic workpieces suite (ADR1183): the genuine receipt becomes one complete installed L0."""
	var project: Vector2i = _installing_probe()
	if project == NULL_REF: return
	var placement: Vector2i = _probe._world._construction.subject_ref_of(project)
	var region: Vector2i = _probe.pieces.workpiece_region(placement, project)
	_probe.finish_install(_probe._router._primary_row(project))
	assert_true(_probe.installed_l0, "actual paid completion")
	if not _probe.installed_l0: return
	assert_equal(_probe.pieces._live.present.count(Workpieces.PENDING_HANDLING) + _probe.pieces._live.present.count(Workpieces.HANDLED),
		0, "no WIP row remains")
	assert_equal(Workpieces._removed_leaf(_probe.pieces, project, region), &"", "exact Region and Project source removed")
	assert_false(_probe._world._construction._directory.is_valid(project), "Project retires only after physical cleanup")
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, placement.x), 1,
		"one whole billed group, no partial installed bearer")
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._wood), 1500, "wood charged once including temporary bearer")


func test_real_blocked_refund_keeps_piece_and_receipt_then_partial_work_refunds_exactly() -> void:
	"""Moved from the synthetic workpieces suite: a refused destination cannot delete paid WIP."""
	var project: Vector2i = _installing_probe()
	if project == NULL_REF: return
	var placement: Vector2i = _probe._world._construction.subject_ref_of(project)
	var region: Vector2i = _probe.pieces.workpiece_region(placement, project)
	assert_true(_probe._world._work.tick_solo(_probe._router._primary_row(project)).ok, "actual partial useful work")
	var refund: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_probe._world._construction.cancellation_refund_milli_into(project, 0, refund), "actual refund policy")
	assert_true(refund.value > 0 and refund.value < 4000, "partial progress incurs actual material loss")
	assert_true(_probe._world._construction.set_paused(project, true).ok, "paused cancellation remains legal")
	_probe.recover_install(_probe._router._primary_row(project))
	assert_true(_probe._world._inventory.set_container_reachable(_probe._storage, false).ok, "real destination blocked")
	var funding: PackedByteArray = _probe._router._funding.state_bytes()
	var geometry: PackedByteArray = _probe._world._owner.state_bytes()
	assert_false(_probe._router.cancel_order(project, _probe._storage).ok, "refused physical refund")
	assert_equal(_probe.pieces.workpiece_region(placement, project), region, "the same full obstacle stays live")
	assert_equal(_probe._router._funding.state_bytes(), funding, "same actual receipt")
	assert_equal(_probe._world._owner.state_bytes(), geometry, "no partial spatial removal")
	assert_true(_probe._world._inventory.set_container_reachable(_probe._storage, true).ok, "real destination restored")
	var item: int = _probe._world._items.compiled_id(&"wood")
	var before: int = _probe._world._inventory.total_live_milli(item)
	var result: PaidConstruction.OpResult = _probe._router.cancel_order(project, _probe._storage)
	assert_true(result.ok, "actual paid cancellation: %s" % result.error)
	if not result.ok: return
	assert_equal(_probe._world._inventory.total_live_milli(item), before + refund.value, "only actual refund enters Inventory")
	assert_equal(_probe._router._funding.purpose_cancellation_loss_milli(PaidConstruction.PURPOSE_CONNECTOR_INSTALL, item),
		4000 - refund.value, "actual shared loss domain, no duplicate escrow")
	assert_equal(Workpieces._removed_leaf(_probe.pieces, project, region), &"", "physical and source retirement before Project")
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, placement.x), 0,
		"cancel preserves the original installed prefix")
	assert_false(_probe._world._construction._directory.is_valid(project), "paid Project retired")


func test_real_productive_terrain_observer_moving_worker_refuses_then_retry_earns() -> void:
	"""Moved from the synthetic workpieces suite: an ordinary terrain observation cannot credit a moved worker."""
	var project: Vector2i = _installing_probe()
	if project == NULL_REF: return
	var actor: PaidRoutes.Actor = PaidRoutes.Actor.new()
	assert_equal(_probe._world._routes.read_actor_into(_probe._world._worker, actor), &"", "actual installing actor")
	var terrain: ObservedPaidTerrain = _probe._world._terrain as ObservedPaidTerrain
	var fired: Array[int] = [0]
	terrain.source_probe = func() -> void:
		fired[0] += 1
		_probe._world._transforms.place(_probe._world._worker, actor.point.x, actor.point.y, actor.point.z + 512, actor.yaw)
	_assert_refused_tick(project)
	assert_equal(fired[0], 1, "one ordinary local terrain observation ran")
	assert_true(_probe._world._transforms.place(_probe._world._worker, actor.point.x, actor.point.y, actor.point.z, actor.yaw),
		"restore actual arrived pose")
	assert_true(_probe._world._work.tick_solo(_probe._router._primary_row(project)).ok, "exact real retry earns work")


func test_real_productive_terrain_observer_cannot_replace_actual_binding() -> void:
	"""Moved from the synthetic workpieces suite: an equal fresh Terrain is not the original once-bound reader."""
	var project: Vector2i = _installing_probe()
	if project == NULL_REF: return
	var world: PaidWorld = _probe._world as PaidWorld
	var replacement: ObservedPaidTerrain = ObservedPaidTerrain.new()
	assert_equal(replacement.configure(world._world, world._nodes, world._owner, world._sources, world._items, world._budget),
		&"", "valid equal foreign reader")
	var terrain: ObservedPaidTerrain = world._terrain as ObservedPaidTerrain
	var fired: Array[int] = [0]
	terrain.source_probe = func() -> void:
		fired[0] += 1
		world._binding._terrain = replacement
	_assert_refused_tick(project)
	assert_equal(fired[0], 1, "late valid reader replacement happened")
	world._binding._terrain = terrain
	assert_true(world._work.tick_solo(_probe._router._primary_row(project)).ok, "original binding retry succeeds")


func _assert_refused_tick(project: Vector2i) -> void:
	"""An observer can mutate its own facts, but cannot earn WU, XP, wear or change the paid receipt."""
	var work: PackedByteArray = _probe._world._work.state_bytes()
	var gear: PackedByteArray = _probe._world._gear.state_bytes()
	var payment: PackedByteArray = _probe._router._funding.state_bytes()
	var inventory: PackedByteArray = _probe._world._inventory.state_bytes()
	assert_false(_probe._world._work.tick_solo(_probe._router._primary_row(project)).ok, "changed final facts refuse work")
	assert_equal(_probe._world._work.state_bytes(), work, "no WU or XP")
	assert_equal(_probe._world._gear.state_bytes(), gear, "no durability or wear")
	assert_equal(_probe._router._funding.state_bytes(), payment, "same paid receipt")
	assert_equal(_probe._world._inventory.state_bytes(), inventory, "no inventory change")


func test_entry_foreman_drives_cuts_retirement_paid_handling_and_install() -> void:
	"""ADR1196: only Foreman.advance(tick) runs twelve phases and the whole paid L0; ledgers match the hand path."""
	_probe = PaidProbe.new()
	_probe.before_each()
	if _probe._confirm_prefix() == NULL_REF: return
	var first: Vector3i = _probe._surface_point(3)
	assert_true(_probe._world._transforms.place(_probe._world._worker, first.x, first.y, first.z, 49152),
		"worker physically stands at the first authored station")
	var foreman: Foreman = Foreman.new()
	var placement: Vector2i = Vector2i(0, _probe._placements._get32(_probe._placements._live, Prefix.Placements.GENERATION, 0))
	assert_equal(foreman.configure(WorkAreaTests.foreman_owners(_probe), WorkAreaTests.foreman_crew(_probe), placement),
		&"", "cut plan")
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = _probe._router; paid.connector = _probe._paid; paid.contacts = _probe._contacts; paid.budget = _probe._world._budget
	assert_equal(foreman.configure_installation(paid, 0), &"", "installation plan from the Frontier install row")
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 40000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal")
	assert_true(foreman.is_done(), "cuts, retirement, handling, fastening and commit all completed")
	assert_equal(foreman.accepted_mwu() + foreman.install_mwu(), 68000, "36000 excavation plus 32000 fastening")
	assert_equal(_probe._world._inventory.lot_quantity_milli(_probe._wood), 1500, "one whole L0 bill paid once")
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, 0), 1, "L0 installed")
	assert_equal(_probe._world._construction.live_project_count(), 0, "every Project retired")




func test_entry_foreman_splits_the_l0_landing_then_the_crossing_survey_exceeds_the_anchor_check_budget() -> void:
	"""ADR1202 split landing: only Foreman.advance(tick) runs six cubes and the paid L0, which now creates a narrow
	WORK contact and one arrival; publishing the T0 contact path then refuses on SurfaceAnchor's check budget."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman()
	if foreman == null: return
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 80000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"SURFACE_ANCHOR_CHECK_CAPACITY",
		"the crossing survey refreshes one more live Location (the arrival) than the World check budget covers")
	assert_true(foreman._installer == null, "the T0 order was never opened")
	_assert_t0_cut_ledger(foreman)
	_assert_split_landing()


func _complete_prefix_foreman() -> Foreman:
	"""Worker at the first station; cuts, L0 and T0 planned from the Frontier with the real SurfaceAnchor."""
	if _probe._confirm_prefix() == NULL_REF: return null
	var first: Vector3i = _probe._surface_point(3)
	assert_true(_probe._world._transforms.place(_probe._world._worker, first.x, first.y, first.z, 49152),
		"worker physically stands at the first authored station")
	var foreman: Foreman = Foreman.new()
	var placement: Vector2i = Vector2i(0, _probe._placements._get32(_probe._placements._live, Prefix.Placements.GENERATION, 0))
	var owners: Foreman.Owners = WorkAreaTests.foreman_owners(_probe)
	owners.anchor = _probe._anchor
	assert_equal(foreman.configure(owners, WorkAreaTests.foreman_crew(_probe), placement), &"", "L0 cut plan")
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = _probe._router; paid.connector = _probe._paid; paid.contacts = _probe._contacts; paid.budget = _probe._world._budget
	assert_equal(foreman.configure_installation(paid, 0), &"", "L0 installation from Frontier install row 0")
	assert_equal(foreman.configure_installation(paid, 1), &"", "T0 cuts and installation from install row 1")
	assert_equal(foreman.task_count(), 18, "six cubes x BRACE/CUT/FINISH")
	return foreman if failures.is_empty() else null


func _assert_t0_cut_ledger(foreman: Foreman) -> void:
	"""All six cubes and the whole L0 are paid exactly once; nothing of the T0 group is admitted or spent."""
	var world: RefCounted = _probe._world
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, 0), 1, "only L0 installed")
	assert_equal(world._inventory.lot_quantity_milli(_probe._wood), 1000, "only the T0 assembly wood remains")
	assert_equal(world._inventory.lot_quantity_milli(_probe._stone), 0, "all 1500 adopted brace stone spent")
	assert_equal(_probe._sites.virgin_sourced_milli(), 12000, "six 2000 spoil outputs")
	assert_equal(foreman.accepted_mwu(), 54000, "six cubes x 9000 phase work")
	assert_equal(foreman.install_mwu(), 32000, "L0 landing fastening only")
	assert_equal(_probe._sites.earth_conservation_refusal(), &"", "complete spoil conservation")
	assert_equal(_probe._sites.support_conservation_refusal(), &"", "complete brace conservation")
	assert_true(world._inventory.audit().ok and world._pool.audit(world._inventory).ok, "real conservation audits")
	assert_equal(world._construction.live_project_count(), 0, "every Project retired; no T0 Project admitted")


func _assert_split_landing() -> void:
	"""The L0 contact has H's narrow shape; one arrival Location sized for source12 stands clear of the T0 bearer."""
	var record: Prefix.Locations.Record = _record(_probe._installed_l0_contact())
	assert_equal(_relative(record.envelope, record.point), PackedInt32Array([-445, 0, -732, 910, 1036, 346]),
		"contact air: the source2/6/16 union, exactly the endpoint certificate's words")
	assert_equal(_relative(record.support, record.point), PackedInt32Array([-274, -1, -274, 299, 0, 249]),
		"contact footing: the source2/16 stance union")
	var bearer: PackedInt32Array = PackedInt32Array()
	bearer.resize(Foreman.Frontier.row_fields(Foreman.Frontier.BEARING))
	assert_equal(_probe._source.bearing_into(1, bearer), &"", "T0 bearer footprint (install row 1's bearing)")
	var contact: PackedInt32Array = PackedInt32Array()
	contact.resize(Foreman.Frontier.row_fields(Foreman.Frontier.ENDPOINT))
	assert_equal(_probe._source.endpoint_into(3, contact), &"", "contact selector")
	var bearer_far_z: int = record.point.z + bearer[8] - contact[6]
	var arrival: Vector2i = _installed_l0_arrival()
	record = _record(arrival)
	assert_equal(_relative(record.envelope, record.point), PackedInt32Array([-1256, 0, -1256, 1256, 1036, 1256]),
		"arrival air: the whole source12 body and turn sweep")
	assert_equal(_relative(record.support, record.point), PackedInt32Array([-406, -1, -406, 406, 0, 406]),
		"arrival footing: the source12 stance on the deck")
	assert_equal(record.envelope[2], bearer_far_z, "arrival air ends exactly at the T0 bearer's far face")
	assert_true(_reach(_probe._endpoints[1], arrival, 12) != &"", "no ground path yet: the survey refused")
	var row: PackedInt32Array = PackedInt32Array()
	row.resize(Foreman.Frontier.row_fields(Foreman.Frontier.INSTALL))
	assert_equal(_probe._source.installation_into(1, row), &"", "successor T0 install row")
	assert_equal(row[7], 10, "T0 material stays M's all-yaw selector")
	assert_equal(row[8], 13, "T0 retreats to the arrival on backward source6")


func _record(ref: Vector2i) -> Prefix.Locations.Record:
	"""One complete live Location record."""
	var record: Prefix.Locations.Record = Prefix.Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	assert_equal(_probe._world._locations.read_location_into(ref, record), &"", "live Location record")
	return record


func _relative(box: PackedInt32Array, point: Vector3i) -> PackedInt32Array:
	"""A world box relative to its Location's root point."""
	var out: PackedInt32Array = PackedInt32Array()
	for axis: int in 6: out.append(box[axis] - point[axis % 3])
	return out


func _reach(first: Vector2i, last: Vector2i, profile: int) -> StringName:
	"""Static WorldRoutes reachability on one source profile at revision 1."""
	var remaining: PackedInt32Array = PackedInt32Array([0])
	return Foreman.WorldRoutes.profile_reachability_refusal(_probe._world._binding, first, last, profile, 1,
		WorkArea.Bundle.CONTENT_REVISION, _probe._world._owner._domain._checks, remaining)


func _installed_l0_arrival() -> Vector2i:
	"""The one TRANSIT Location the paid L0 created behind its contact for both arrival selectors (12 and 13)."""
	var selector: PackedInt32Array = PackedInt32Array()
	selector.resize(Foreman.Frontier.row_fields(Foreman.Frontier.ENDPOINT))
	var held: PackedInt32Array = selector.duplicate()
	assert_equal(_probe._source.endpoint_into(12, selector), &"", "arrival selector")
	assert_equal(_probe._source.endpoint_into(3, held), &"", "contact selector")
	var contact: Prefix.Locations.Record = _record(_probe._installed_l0_contact())
	var point: Vector3i = contact.point + Vector3i(selector[4] - held[4], selector[5] - held[5], selector[6] - held[6])
	var found: Vector2i = NULL_REF
	for row: int in _probe._world._locations._capacity:
		if _probe._world._locations._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, _probe._world._locations._live.i32[row])
		var record: Prefix.Locations.Record = _record(ref)
		if record.point != point or record.role != Prefix.Locations.ROLE_TRANSIT: continue
		assert_equal(found, NULL_REF, "one Location for both arrival selectors")
		found = ref
	assert_true(found != NULL_REF, "the installed arrival exists")
	return found
