extends "res://test/underground_paid_assembly_case.gd"
## Paid L0 handling on the real source and original owners: the paid install, the prefunded pause and the unfunded
## observation (fixture: underground_paid_assembly_case.gd; split four ways so CI can shard it, decision 2044, CI time).


func test_real_l0_requires_paid_handling_before_unchanged_productive_install() -> void:
	"""One real worker digs four cubes, pays the actual whole bill, handles, fastens and publishes one prefix."""
	_probe = PaidProbe.new()
	_probe.before_each()
	_probe.install_l0()
	assert_true(_probe.failures.is_empty(), "actual paid handling: %s" % _probe.failures)
	assert_true(_probe.handled_l0, "actual positioning completed")
	assert_true(_probe.installed_l0, "actual whole L0 installed")
	assert_equal(_probe._accepted_work_mwu, 48920, "only16920 excavation plus32000 fastening work")


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
	assert_equal(_probe._accepted_work_mwu, 16920, "only prior excavation work")
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


func test_actual_prefunded_pause_refuses_a_stray_tool_binding_on_the_paw_order() -> void:
	"""DEC-052: the paw order's Job needs no tool and holds no claim; a Work tool binding written onto that Job (with no
	Gear claim behind it) is inconsistent, so the release refuses and keeps the worker, then succeeds once it is gone."""
	_probe = PaidProbe.new()
	_probe.before_each()
	var project: Vector2i = _probe.prepare_l0()
	assert_true(project != Prefix.NULL_REF, "actual unfunded READY: %s" % _probe.failures)
	if project == Prefix.NULL_REF: return
	var resident: int = _probe._world._residents.directory().get_typed_row(_probe._world._worker)
	var job: Vector2i = _probe._world._jobs.ref_of(_probe._router._primary_row(project))
	assert_equal(_probe._world._work.tool_lot_of(resident), NULL_REF, "the paw crew claims no tool")
	var jobs: PackedByteArray = _probe._world._jobs.state_bytes()
	_probe._world._work._tool_lot_slot[resident] = 0
	_probe._world._work._tool_lot_generation[resident] = 1
	_probe._world._work._tool_job_slot[resident] = job.x
	_probe._world._work._tool_job_generation[resident] = job.y
	assert_false(_probe._router.set_paused(project, true).ok, "a stray tool binding refuses the release")
	assert_equal(_probe._world._jobs.state_bytes(), jobs, "the worker is retained")
	_probe._world._work._tool_lot_slot[resident] = -1
	_probe._world._work._tool_lot_generation[resident] = 0
	_probe._world._work._tool_job_slot[resident] = -1
	_probe._world._work._tool_job_generation[resident] = 0
	assert_true(_probe._router.set_paused(project, true).ok, "the tool-free crew is released")
	assert_equal(_probe._world._jobs.worker_of(_probe._router._primary_row(project)), NULL_REF, "released")
