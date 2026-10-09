extends "res://test/underground_host_case.gd"
## The uninterrupted live entry chain: restored every tick to the prefix, the descent to the sill, and
## the whole entry restored along the way. Split from test_underground_host.gd so CI can shard it
## apart (decision 1243); fixture: underground_host_case.gd.


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
		assert_true(o.jobs._dispatch_owns.get_object() == _host.underground_entry(), "the restored runtime dispatches")
	var record: PackedByteArray = PackedByteArray()
	assert_equal(_host.underground_entry().capture(record), &"", "final record")
	return [counts[0], counts[1], tick, _host.underground_entry().error()] + _snapshot() + [record] \
		+ RouteFixture.route_images(o.routes, o.world_routes, o.budget) \
		+ RouteFixture.entry_owner_images(o.contacts, o.delivery, o.budget)


func _cold_restore_routes(o: Session.Retirement.Owners, tick: int) -> bool:
	"""ADR1221: the Session's Routes, WorldRoutes, Contacts, Delivery, arena and the host Planner captured, blanked
	as a fresh Session's and cold-restored."""
	var code: StringName = RouteFixture.cold_restore_route_owners(o.routes, o.world_routes, o.space, o.budget)
	assert_equal(code, &"", "route owners cold-restore before tick %d" % tick)
	if code == &"":
		code = o.connector.save_quiescence_refusal()
		assert_equal(code, &"", "ConnectorWork quiescent before tick %d" % tick)
	if code == &"":
		code = RouteFixture.cold_restore_entry_owners(o.contacts, o.delivery, o.budget)
		assert_equal(code, &"", "Contacts, Delivery, arena and Planner cold-restore before tick %d" % tick)
	return code == &""


func test_the_live_chain_builds_the_descent_down_the_stair_to_the_sill() -> void:
	"""ADR1229 increment 6b: past the prefix the crew cuts the descent's eight cubes from the surface, then installs
	T1-T6, each from the tread above: it walks from M to the crossing arrival, down the stair (walk-in, step forward,
	one descent per tread, step back onto the station), funds and fits the tread. DEC-059 (P1): T1 hauls every tread's wood to M,
	and each later tread follows straight down from the one before (step forward, one descent, step back). Each group is installed exactly once; the foreman ends with G9 at the
	Kitchen (DEC-054), and a finished entry re-raises it."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	_stage(o, entry._output, &"wood", 13000)
	_stage(o, entry._output, &"stone", 2000)
	var tick: int = 1
	var at_m: int = 0
	var row: int = o.residents.directory().get_typed_row(live[2])
	while entry.is_running() and tick < 20000:
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		if entry._foreman._index > FIRST_TREAD_TASK and o.routes._resident_pair(Session.Retirement.Routes.R_LOCATION_SLOT, row) \
				== entry._published.endpoints[1]: at_m += 1
		tick += 1
	assert_equal(at_m, 0, "DEC-059 (P1): after T1 the fitter never goes back to M; T2-T6 follow straight down")
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_DONE, "the runtime finished the descent")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "and stopped at the Kitchen")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G9"), "named gap row G9")
	assert_true(entry._foreman.is_done() and entry._foreman.error() == &"", "every planned task done")
	assert_equal(_done_ledger(o, entry._foreman), DESCENT_LEDGER, "eight groups and every cut with their exact Work, once")
	assert_equal(o.construction.live_project_count(), 0, "every Project retired")
	assert_equal(tick - 1, DESCENT_DONE_TICK, "the finishing tick")
	assert_true(tick - 1 < WORK_BLOCK_END, "DEC-059: the whole entry is built inside the first work block")
	var needs: RefCounted = o.jobs.needs()
	assert_true(needs.need_of(row, 0).value > SEEK_HUNGER and needs.need_of(row, 1).value > SEEK_REST,
		"and the crew never reached a seek threshold (no shift change was needed)")
	assert_false(_host.begin_underground_entry(Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)), "a finished entry")
	assert_equal(_host.last_refusal(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "re-raises G9")


## DEC-059: the whole-entry restore variant replaces the runtime by its record this often (ticks; prime), and
## cold-restores the route owners every ROUTE_RESTORE_EVERY ticks.
const ENTRY_RESTORE_EVERY: int = 11


func _whole_entry(restoring: bool) -> Array:
	"""[finish tick, error, ledger..., owner images..., final record, route and entry owner images] of the whole
	entry on the default schedule, uninterrupted or with its runtime and route owners restored along the way."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	_stage(o, live[1]._output, &"wood", 13000)
	_stage(o, live[1]._output, &"stone", 2000)
	var session: Session = _host.underground_session()
	var tick: int = 1
	while _host.underground_entry().is_running() and tick < 20000:
		if restoring and tick % ENTRY_RESTORE_EVERY == 0 and not _replace_entry_with_its_record(session, tick): return []
		if restoring and tick % ROUTE_RESTORE_EVERY == 0 and not _cold_restore_routes(o, tick): return []
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var record: PackedByteArray = PackedByteArray()
	assert_equal(entry.capture(record), &"", "final record")
	return [tick - 1, entry.error()] + _done_ledger(o, entry._foreman) + _snapshot() + [record] \
		+ RouteFixture.route_images(o.routes, o.world_routes, o.budget) \
		+ RouteFixture.entry_owner_images(o.contacts, o.delivery, o.budget)


func test_the_whole_entry_restored_along_the_way_ends_byte_identical() -> void:
	"""DEC-059: the whole entry (prefix, descent cuts with one claw entry a cube, T1 and the chained treads) on the
	default schedule, uninterrupted and again with its runtime replaced by its record every ENTRY_RESTORE_EVERY
	ticks and its route owners cold-restored every ROUTE_RESTORE_EVERY ticks: the same finish, ledger and images."""
	var plain: Array = _whole_entry(false)
	if plain.is_empty(): return
	assert_equal(plain.slice(0, 2), [DESCENT_DONE_TICK, Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT],
		"the uninterrupted entry ends at the Kitchen gap")
	assert_equal(plain.slice(2, 7), DESCENT_LEDGER, "with the whole descent's ledger")
	after_each()
	before_each()
	var restored: Array = _whole_entry(true)
	if restored.is_empty(): return
	for index: int in plain.size():
		assert_equal(restored[index], plain[index], "whole-entry image %d is byte-identical after restores" % index)
