extends "res://test/underground_paid_assembly_case.gd"
## Paid L0 start and install on the real source and original owners: the pre-stage context, the install's piece and
## refund, and the productive terrain observers (fixture: underground_paid_assembly_case.gd; decision 2044, CI time).


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
	assert_equal(_probe._accepted_work_mwu, 16920, "only the four actual completed excavation cubes earned work")


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
