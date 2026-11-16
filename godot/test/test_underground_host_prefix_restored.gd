extends "res://test/underground_host_case.gd"
## The uninterrupted live entry chain to the end of the prefix, then again restored every tick: the same finish and
## byte-identical images. Split from test_underground_host_whole_chain.gd so CI can shard it apart from the whole
## flight (decision 2044, CI time); fixture: underground_host_case.gd.


func test_fixed_ticks_with_the_entry_restored_every_tick_end_byte_identical() -> void:
	"""ADR1218/1219: the live run_tick chain from the surface walk, through arrival and registration on H, the
	retreat, both hauls and (ADR1223) the walk home under the crew's reserved BUILD Job, to the end of the prefix (ADR1227), runs
	uninterrupted, then again with the whole entry runtime captured and replaced by its restored record (which rebinds
	the Jobs dispatcher) before every tick and (ADR1221) Routes and WorldRoutes cold-restored into blanked banks every
	ROUTE_RESTORE_EVERY ticks; the finish, every owner image and both route images are byte-identical."""
	var plain: Array = _live_chain(false)
	if plain.is_empty(): return
	after_each()
	before_each()
	var restored: Array = _live_chain(true)
	if restored.is_empty(): return
	print("LIVE-ENTRY-PROGRESS walk_restores=%d registered_restores=%d finish_tick=%d" % restored.slice(0, 3))
	assert_true(restored[0] > 0 and restored[1] > 0, "restored mid-walk (%d) and after registration (%d)" % restored.slice(0, 2))
	for index: int in range(2, plain.size()):
		assert_equal(restored[index], plain[index], "live image %d is byte-identical after restores" % index)


func _live_chain(restoring: bool) -> Array:
	"""[walk restores, registered restores, finish tick, error, owner images..., final record] of one live chain."""
	var session: Session = _generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")
	var near: Vector3i = Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)
	var o: Session.Retirement.Owners = session._retirement_owners
	var worker: Vector2i = _first_mole(o)
	assert_true(_host.begin_underground_entry(near), "foreman planned and the walk begun: %s" % _host.last_refusal())
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	_stage(o, entry._output, &"wood", 7000)
	_stage(o, entry._output, &"stone", 2000)
	var counts: PackedInt64Array = PackedInt64Array([0, 0])
	var tick: int = 1
	while _host.underground_entry().is_running() and not _prefix_done(_host.underground_entry()) and tick < 8000:
		if restoring:
			counts[0 if _host.underground_entry().walk_ticks_left() > 0 else 1] += 1
			if not _replace_entry_with_its_record(session, tick): return []
			if tick % ROUTE_RESTORE_EVERY == 0 and not _cold_restore_routes(o, tick): return []
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	_assert_prefix_done(o, _host.underground_entry(), worker)
	assert_equal(tick - 1, DONE_TICK, "the finishing tick")
	if restoring:
		assert_true(preload("res://scripts/core/underground_dispatch.gd").bound_to(o.jobs)
			and _host._underground_dispatch.reserves_resident(o.residents.directory().get_typed_row(worker)) \
			== _host.underground_entry().reserves_resident(o.residents.directory().get_typed_row(worker)),
			"the restored runtime answers through the host's composite dispatcher (decision 1936)")
	var record: PackedByteArray = PackedByteArray()
	assert_equal(_host.underground_entry().capture(record), &"", "final record")
	return [counts[0], counts[1], tick, _host.underground_entry().error()] + _snapshot() + [record] \
		+ RouteFixture.route_images(o.routes, o.world_routes, o.budget) \
		+ RouteFixture.entry_owner_images(o.contacts, o.delivery, o.budget)
