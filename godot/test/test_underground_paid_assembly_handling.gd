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
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Progress := preload("res://scripts/core/underground_entry_progress.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
const RouteFixture := preload("res://test/test_underground_world_routes.gd")
## ADR1218: the hauled prefix is captured and restored into a fresh foreman this often (ticks).
const RESTORE_EVERY: int = 1
## ADR1221: and its route owners are captured, blanked and cold-restored this often (ticks; prime, so the saves
## fall on every phase of the 30 Hz motion fractions).
const ROUTE_RESTORE_EVERY: int = 41
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




func test_entry_foreman_runs_the_complete_prefix_from_the_confirmed_prefix() -> void:
	"""ADR1202/1207: only Foreman.advance(tick) runs six cubes, the paid L0 (split landing), the crossing survey,
	which now re-proves only the Locations it touches, and the paid T0, each group INSTALLED exactly once."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman()
	if foreman == null: return
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 120000:
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal on the whole prefix")
	assert_true(foreman.is_done(), "every planned task finished")
	assert_true(_probe._anchor._last_checks < 600000,
		"the crossing survey carries the untouched Locations: %d of 1048576 checks" % _probe._anchor._last_checks)
	_assert_complete_prefix_ledger(foreman)
	_assert_split_landing()
	_assert_crossing_reachability()


func _assert_complete_prefix_ledger(foreman: Foreman) -> void:
	"""Both groups installed once; every adopted input spent; spoil, work and conservation exact; no live Project."""
	var world: RefCounted = _probe._world
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, 0), 2,
		"L0 and T0 each installed exactly once")
	assert_equal(world._inventory.lot_quantity_milli(_probe._wood), 0, "all adopted wood spent")
	assert_equal(world._inventory.lot_quantity_milli(_probe._stone), 0, "all 1500 adopted brace stone spent")
	assert_equal(_probe._sites.virgin_sourced_milli(), 12000, "six 2000 spoil outputs")
	assert_equal(foreman.accepted_mwu(), 54000, "six cubes x 9000 phase work")
	assert_equal(foreman.accepted_mwu() + foreman.install_mwu(), 98000, "cuts plus both installations' fastening")
	assert_equal(_probe._sites.earth_conservation_refusal(), &"", "complete spoil conservation")
	assert_equal(_probe._sites.support_conservation_refusal(), &"", "complete brace conservation")
	assert_true(world._inventory.audit().ok and world._pool.audit(world._inventory).ok, "real conservation audits")
	assert_equal(world._construction.live_project_count(), 0, "every Project retired")


func _assert_crossing_reachability() -> void:
	"""The published crossing joins M and the arrival; the narrow contact admits only its backward/forward sources."""
	var arrival: Vector2i = _installed_l0_arrival()
	var contact: Vector2i = _probe._installed_l0_contact()
	assert_equal(_reach(_probe._endpoints[1], arrival, 12), &"", "source12 reaches the arrival from M")
	assert_equal(_reach(arrival, _probe._endpoints[1], 12), &"", "source12 returns to M")
	assert_equal(_reach(arrival, contact, 2), &"", "source2 steps onto the contact")
	assert_equal(_reach(contact, arrival, 6), &"", "source6 backs off the contact")
	assert_true(_reach(arrival, contact, 12) != &"", "source12 is refused onto the narrow contact")


func test_entry_foreman_hauls_every_input_of_the_complete_prefix() -> void:
	"""ADR1210 (G4): all inputs start as surface stock staged at R. Only Foreman.advance(tick) runs; every unit
	reaches M by a real tool-free Delivery haul between the tooled cuts, and the same prefix installs once."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman(true)
	if foreman == null: return
	var peaks: PackedInt64Array = PackedInt64Array([0, 0])
	var tick: int = _probe._tick
	while not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 200000:
		foreman.advance(tick)
		peaks[0] = maxi(peaks[0], _probe._world._binding._proof_checks)
		peaks[1] = maxi(peaks[1], _probe._anchor._last_checks)
		tick += 1
	assert_equal(foreman.error(), &"", "no refusal on the hauled prefix")
	assert_true(foreman.is_done(), "every planned task finished")
	print("HAULED-PREFIX ticks=%d trips=%d haul_mwu=%d route_peak=%d location_peak=%d" % [tick - _probe._tick,
		foreman.haul_trips(), foreman.haul_mwu(), peaks[0], peaks[1]])
	assert_true(peaks[0] < Prefix.Space.MAX_CHECKS and peaks[1] < Prefix.Space.MAX_CHECKS, "both check budgets hold")
	_assert_hauled_ledger(foreman)


func _assert_hauled_ledger(foreman: Foreman) -> void:
	"""Exact bills spent from hauled stock; R's staging emptied; whole-unit trips leave 500 of each at M."""
	var world: RefCounted = _probe._world
	var wood: int = world._items.compiled_id(&"wood")
	var stone: int = world._items.compiled_id(&"stone")
	assert_equal(_probe._placements._get32(_probe._placements._live, Prefix.Placements.INSTALLED, 0), 2, "L0 and T0 once each")
	assert_equal(foreman.haul_trips(), 9, "seven wood and two stone whole-unit trips")
	assert_equal(foreman.haul_mwu(), 9 * 2 * HaulPlanner.HAUL_LOAD_MILLI_WU, "one lift and one set-down per trip")
	for item: int in [wood, stone]:
		assert_equal(Hauler.free_milli(world._inventory, _probe._output, item), 0, "R's staging fully hauled")
		assert_equal(Hauler.free_milli(world._inventory, _probe._storage, item), 500, "whole-unit remainder at M")
	assert_equal(_probe._sites.virgin_sourced_milli(), 12000, "six 2000 spoil outputs")
	assert_equal(foreman.accepted_mwu() + foreman.install_mwu(), 98000, "cuts plus both installations' fastening")
	assert_equal(_probe._sites.earth_conservation_refusal(), &"", "complete spoil conservation")
	assert_equal(_probe._sites.support_conservation_refusal(), &"", "complete brace conservation")
	assert_true(world._inventory.audit().ok and world._pool.audit(world._inventory).ok, "real conservation audits")
	assert_equal(world._construction.live_project_count(), 0, "every Project retired")
	assert_true(world._inventory.is_lot_equipped(_probe._tool), "the tool is back in the worker's hands")


func _stage_surface_stock() -> void:
	"""Move the finite wood and stone to R's staging and top each up to whole units (7000 wood, 2000 stone)."""
	var world: RefCounted = _probe._world
	for at: int in 2:
		var lot: Vector2i = [_probe._wood, _probe._stone][at]
		assert_true(world._inventory.move_lot(lot, _probe._output).ok, "surface stock staged at R")
		var top: RefCounted = world._inventory.create_lot(_probe._output, world._inventory.lot_item_id(lot), 500, 1,
			Prefix.Provenance.PROVENANCE_ORDINARY, -1, 0, 0)
		assert_true(top.ok and world._inventory.merge_lots(lot, top.ref).ok, "one whole-unit staged lot")


func _bind_delivery(owners: Foreman.Owners) -> void:
	"""The real Planner and one Delivery over the probe's owners; the foreman also borrows Gear."""
	var world: RefCounted = _probe._world
	var planner: HaulPlanner = HaulPlanner.new()
	assert_true(planner.bind(world._inventory, world._pool, world._residents, world._buildings, world._piles,
		StorePolicy.new(world._buildings, world._inventory)), "actual Planner")
	var delivery: Delivery = Delivery.new()
	assert_equal(delivery.configure(_probe._placements, _probe._source, planner, world._binding, world._work,
		SimClock.new(), Delivery.RESERVED_BYTES), &"", "one bounded Delivery")
	owners.delivery = delivery
	owners.gear = world._gear


func _complete_prefix_foreman(hauled: bool = false) -> Foreman:
	"""Worker at the first station; cuts, L0 and T0 planned from the Frontier with the real SurfaceAnchor."""
	if _probe._confirm_prefix() == NULL_REF: return null
	if hauled: _stage_surface_stock()
	var first: Vector3i = _probe._surface_point(3)
	assert_true(_probe._world._transforms.place(_probe._world._worker, first.x, first.y, first.z, 49152),
		"worker physically stands at the first authored station")
	var foreman: Foreman = Foreman.new()
	var placement: Vector2i = Vector2i(0, _probe._placements._get32(_probe._placements._live, Prefix.Placements.GENERATION, 0))
	var owners: Foreman.Owners = WorkAreaTests.foreman_owners(_probe)
	owners.anchor = _probe._anchor
	if hauled: _bind_delivery(owners)
	assert_equal(foreman.configure(owners, WorkAreaTests.foreman_crew(_probe), placement), &"", "L0 cut plan")
	var paid: Foreman.Installer.Paid = Foreman.Installer.Paid.new()
	paid.router = _probe._router; paid.connector = _probe._paid; paid.contacts = _probe._contacts; paid.budget = _probe._world._budget
	assert_equal(foreman.configure_installation(paid, 0), &"", "L0 installation from Frontier install row 0")
	assert_equal(foreman.configure_installation(paid, 1), &"", "T0 cuts and installation from install row 1")
	assert_equal(foreman.task_count(), 18, "six cubes x BRACE/CUT/FINISH")
	return foreman if failures.is_empty() else null


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


func test_entry_progress_restores_exactly_through_the_hauled_prefix() -> void:
	"""ADR1218 (G10): the hauled prefix runs uninterrupted, then again with the foreman captured and replaced by a
	fresh restore every RESTORE_EVERY ticks, and (ADR1221) Routes and WorldRoutes captured, blanked as a fresh
	Session's and cold-restored every ROUTE_RESTORE_EVERY ticks. Every stage of the foreman, installer and hauler is
	crossed, and the final owner ledgers, route images, the finishing tick and the terminal record are
	byte-identical to the uninterrupted run."""
	var started: int = Time.get_ticks_usec()
	var plain: Array[PackedByteArray] = _hauled_run(0, PackedInt64Array([0, 0, 0, 0]))
	if plain.is_empty(): return
	after_each()
	var middle: int = Time.get_ticks_usec()
	var seen: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	var restored: Array[PackedByteArray] = _hauled_run(RESTORE_EVERY, seen)
	if restored.is_empty(): return
	var spans: PackedInt64Array = PackedInt64Array([middle - started, Time.get_ticks_usec() - middle])
	print("ENTRY-PROGRESS restores=%d foreman_stages=%x installer_stages=%x hauler_stages=%x plain_us=%d restored_us=%d"
		% [seen[3], seen[0], seen[1], seen[2], spans[0], spans[1]])
	for index: int in plain.size():
		assert_equal(restored[index], plain[index], "ledger image %d is byte-identical after restores" % index)
	_assert_stages_seen(seen)


func _assert_stages_seen(seen: PackedInt64Array) -> void:
	"""Every resting stage of each dispatcher was captured and restored at least once."""
	var expected: Array = [
		[Foreman.STAGE_OPEN, Foreman.STAGE_TRAVEL, Foreman.STAGE_ENTER, Foreman.STAGE_EARN, Foreman.STAGE_RECOVER,
			Foreman.STAGE_INSTALL, Foreman.STAGE_HAUL],
		# Every hauled installation walks to M inside its haul, so LEG_MATERIAL never rests at a tick boundary here.
		[Installer.STAGE_HAUL, Installer.STAGE_LEG_ARRIVAL, Installer.STAGE_LEG_STATION, Installer.STAGE_HANDLE,
			Installer.STAGE_INSTALL_ENTER, Installer.STAGE_EARN, Installer.STAGE_RECOVER],
		[Hauler.STAGE_APPROACH, Hauler.STAGE_TO_SOURCE, Hauler.STAGE_LIFT, Hauler.STAGE_CARRY, Hauler.STAGE_SET_DOWN,
			Hauler.STAGE_HOME]]
	for level: int in 3:
		var mask: int = 0
		for stage: int in expected[level]:
			mask |= 1 << stage
		assert_equal(seen[level] & mask, mask, "restored in every resting stage of dispatcher level %d" % level)


func _hauled_run(every: int, seen: PackedInt64Array) -> Array[PackedByteArray]:
	"""One hauled prefix; with `every` > 0 the foreman is replaced by its own restored record on that period."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman(true)
	if foreman == null: return []
	var tick: int = _probe._tick
	while foreman != null and not foreman.is_done() and foreman.error() == &"" and tick < _probe._tick + 200000:
		if every > 0 and (tick - _probe._tick) % every == 0: foreman = _round_trip(foreman, seen)
		if every > 0 and (tick - _probe._tick) % ROUTE_RESTORE_EVERY == 0 and not _cold_route_round_trip(tick):
			return []
		if foreman != null: foreman.advance(tick)
		tick += 1
	if foreman == null: return []
	assert_equal(foreman.error(), &"", "no refusal on the hauled prefix")
	assert_true(foreman.is_done(), "every planned task finished")
	_assert_hauled_ledger(foreman)
	return _ledger_image(foreman, tick - _probe._tick)


func _cold_route_round_trip(tick: int) -> bool:
	"""ADR1221: Routes and WorldRoutes captured, blanked as a fresh Session's and restored before this tick."""
	var world: RefCounted = _probe._world
	var code: StringName = RouteFixture.cold_restore_route_owners(world._routes, world._binding, world._owner,
		world._budget)
	assert_equal(code, &"", "route owners cold-restore before tick %d" % tick)
	return code == &""


func _round_trip(foreman: Foreman, seen: PackedInt64Array) -> Foreman:
	"""Capture, restore into a fresh foreman over the same restored owners, and re-capture the same bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	var fresh: Foreman = Foreman.new()
	var code: StringName = foreman.capture(bytes)
	if code == &"": code = fresh.restore(bytes, foreman._owners, foreman._paid)
	var again: PackedByteArray = PackedByteArray()
	if code == &"": code = fresh.capture(again)
	if code != &"" or again != bytes:
		assert_equal(code, &"", "round trip at foreman stage %d" % foreman._stage)
		assert_equal(again, bytes, "a restored foreman writes back its record")
		return null
	seen[0] |= 1 << fresh._stage
	if fresh._installer != null: seen[1] |= 1 << fresh._installer._stage
	var hauler: Hauler = fresh._hauler if fresh._hauler != null else (fresh._installer._hauler if fresh._installer != null else null)
	if hauler != null: seen[2] |= 1 << hauler._stage
	seen[3] += 1
	return fresh


func _ledger_image(foreman: Foreman, ticks: int) -> Array[PackedByteArray]:
	"""Every owner ledger the prefix writes, the Placement bank, the terminal record and the finishing tick."""
	var world: RefCounted = _probe._world
	var record: PackedByteArray = PackedByteArray()
	assert_equal(foreman.capture(record), &"", "terminal record")
	var images: Array[PackedByteArray] = [world._inventory.state_bytes(), world._pool.state_bytes(),
		world._construction.state_bytes(), world._jobs.state_bytes(), world._work.state_bytes(), world._gear.state_bytes(),
		world._transforms.state_bytes(), _probe._sites.state_bytes(), _probe._router.state_bytes(),
		world._owner.state_bytes(), var_to_bytes(_probe._placements._live.i32), record,
		var_to_bytes(PackedInt64Array([ticks, foreman.accepted_mwu(), foreman.install_mwu(), foreman.haul_mwu(),
			foreman.haul_trips()]))]
	images.append_array(RouteFixture.route_images(world._routes, world._binding, world._budget)) # ADR1221
	return images


## ADR1218 wire offsets of a 20-task foreman record (header 12, crew 40, two flags, content, Placement, count).
const AT_DELIVERY_FLAG: int = 52
const AT_CONTENT: int = 54
const AT_TASKS: int = 74
const AT_CURSOR: int = AT_TASKS + 20 * Progress.TASK_BYTES # index, stage, stage ticks, Job slot, Job ref, code
const AT_INSTALLER: int = AT_CURSOR + 24 + Progress.CODE_BYTES + 88 + 32 + 1 # ledgers, ADR1219 arrival, presence flag
const AT_INSTALLER_PROJECT: int = AT_INSTALLER + 108 + 8 + 4
const AT_INSTALLER_JOB_REF: int = AT_INSTALLER_PROJECT + 8 + 4


func test_entry_progress_refuses_every_corrupt_or_stale_record_exactly() -> void:
	"""ADR1218: a record captured mid-haul inside the L0 installation restores; every corruption or stale handle is
	refused with its exact code, the refused foreman holds that code, and no owner changes."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var foreman: Foreman = _complete_prefix_foreman(true)
	if foreman == null: return
	var tick: int = _probe._tick
	while foreman.error() == &"" and tick < _probe._tick + 20000 and not (foreman._stage == Foreman.STAGE_INSTALL
			and foreman._installer._hauler != null and foreman._installer._hauler._stage == Hauler.STAGE_CARRY):
		foreman.advance(tick)
		tick += 1
	assert_equal(foreman._stage, Foreman.STAGE_INSTALL, "paused inside an installation's haul")
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(foreman.capture(bytes), &"", "mid-haul capture")
	_assert_record_layout(foreman, bytes)
	var world: RefCounted = _probe._world
	var before: Array[PackedByteArray] = [world._inventory.state_bytes(), world._jobs.state_bytes(),
		world._construction.state_bytes(), world._pool.state_bytes()]
	for case: Array in _corruptions(bytes):
		_expect_refusal(foreman, case[0], case[1], case[2])
	_expect_owner_refusals(foreman, bytes)
	assert_equal([world._inventory.state_bytes(), world._jobs.state_bytes(), world._construction.state_bytes(),
		world._pool.state_bytes()], before, "no refused restore touched an owner")
	var fresh: Foreman = Foreman.new()
	assert_equal(fresh.restore(bytes, foreman._owners, foreman._paid), &"", "the intact record still restores")
	assert_equal(fresh.restore(bytes, foreman._owners, foreman._paid), Progress.REFUSE_TARGET, "only into a fresh foreman")


func _assert_record_layout(foreman: Foreman, bytes: PackedByteArray) -> void:
	"""The test's offsets and the codec's declared block sizes are the encoder's own."""
	assert_equal(bytes.decode_s32(AT_CURSOR + 4), Foreman.STAGE_INSTALL, "cursor offset")
	assert_equal(bytes.decode_s32(AT_INSTALLER_PROJECT), foreman._installer._project.x, "installer Project offset")
	assert_equal(bytes.decode_s32(AT_INSTALLER_JOB_REF - 4), foreman._installer._job, "installer Job offset")
	var haul: Hauler = foreman._installer._hauler
	assert_equal(bytes.size(), Progress.HEADER_BYTES + Progress.CREW_BYTES + Progress.FOREMAN_FIXED_BYTES
		+ 20 * Progress.TASK_BYTES + Progress.INSTALLER_FIXED_BYTES + foreman._installer._quote.input_count
		* Progress.QUOTE_LINE_BYTES + Progress.HAULER_FIXED_BYTES + 4 * haul._queue.size() + Progress.LEG_BYTES
		* haul._legs.size(), "the declared block sizes are the encoder's")
	assert_true(bytes.size() <= Progress.MAX_WIRE_BYTES, "inside the charged bound")


func _corruptions(bytes: PackedByteArray) -> Array:
	"""(label, corrupted record, exact refusal) for each kind of damage."""
	var cases: Array = []
	cases.append(["truncated", bytes.slice(0, bytes.size() - 1), Progress.REFUSE_SHAPE])
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	cases.append(["trailing byte", longer, Progress.REFUSE_SHAPE])
	cases.append(["magic", _with_i32(bytes, 0, 0x50544E46), Progress.REFUSE_VERSION])
	cases.append(["version", _with_i32(bytes, 4, Progress.VERSION + 1), Progress.REFUSE_VERSION])
	cases.append(["runtime kind", _with_i32(bytes, 8, Progress.KIND_RUNTIME), Progress.REFUSE_VERSION])
	var flag: PackedByteArray = bytes.duplicate()
	flag[AT_DELIVERY_FLAG] = 2
	cases.append(["flag byte 2", flag, Progress.REFUSE_SHAPE])
	var padding: PackedByteArray = bytes.duplicate()
	padding[AT_CURSOR + 24 + 5] = 0x41
	cases.append(["code padding", padding, Progress.REFUSE_SHAPE])
	cases.append(["null spelling", _with_i32(bytes, AT_TASKS + 12 * Progress.TASK_BYTES + 8, 7), Progress.REFUSE_SHAPE])
	cases.append(["stage out of range", _with_i32(bytes, AT_CURSOR + 4, 99), Progress.REFUSE_SHAPE])
	cases.append(["content pin", _with_i64(bytes, AT_CONTENT, bytes.decode_s64(AT_CONTENT) + 1), Progress.REFUSE_CONTENT])
	var station: int = AT_TASKS + 18 * Progress.TASK_BYTES + 20
	cases.append(["stale future station", _with_i32(bytes, station, bytes.decode_s32(station) + 1), Progress.REFUSE_LOCATION])
	cases.append(["stale Job", _with_i32(bytes, AT_INSTALLER_JOB_REF + 4, bytes.decode_s32(AT_INSTALLER_JOB_REF + 4) + 1),
		Progress.REFUSE_JOB])
	cases.append(["stale Project", _with_i32(bytes, AT_INSTALLER_PROJECT + 4, bytes.decode_s32(AT_INSTALLER_PROJECT + 4) + 1),
		Progress.REFUSE_PROJECT])
	return cases


func _expect_owner_refusals(foreman: Foreman, bytes: PackedByteArray) -> void:
	"""Wiring that disagrees with the record, and a capture during an open route operation."""
	var owners: Foreman.Owners = foreman._owners
	var delivery: RefCounted = owners.delivery
	owners.delivery = null
	_expect_refusal(foreman, "no Delivery bound", bytes, Progress.REFUSE_OWNERS)
	owners.delivery = delivery
	var fresh: Foreman = Foreman.new()
	assert_equal(fresh.restore(bytes, owners, null), Progress.REFUSE_OWNERS, "no paid owners bound")
	owners.routes._token = 1
	var out: PackedByteArray = PackedByteArray([1])
	assert_equal(foreman.capture(out), Progress.REFUSE_BUSY, "no capture inside a synchronous route operation")
	assert_true(out.is_empty(), "a refused capture writes nothing")
	owners.routes._token = 0


func _expect_refusal(foreman: Foreman, label: String, bytes: PackedByteArray, code: StringName) -> void:
	"""A fresh foreman refuses the record with exactly `code` and holds it as its error."""
	var fresh: Foreman = Foreman.new()
	assert_equal(fresh.restore(bytes, foreman._owners, foreman._paid), code, label)
	assert_equal(fresh.error(), code, "%s: the refused foreman holds its refusal" % label)


static func _with_i32(bytes: PackedByteArray, at: int, value: int) -> PackedByteArray:
	"""A copy with one 32-bit field replaced."""
	var out: PackedByteArray = bytes.duplicate()
	out.encode_s32(at, value)
	return out


static func _with_i64(bytes: PackedByteArray, at: int, value: int) -> PackedByteArray:
	"""A copy with one 64-bit field replaced."""
	var out: PackedByteArray = bytes.duplicate()
	out.encode_s64(at, value)
	return out
