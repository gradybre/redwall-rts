extends "res://test/underground_host_case.gd"
## The uninterrupted live entry chain: the flight to its last sill (decision 2044: the M2 interim's two modules), and
## the whole entry restored along the way. Split from test_underground_host.gd so CI can shard it apart (decision 1243);
## fixture: underground_host_case.gd. Decision 2044 (CI time): the prefix restored every tick is
## test_underground_host_prefix_restored.gd; the suite flies the uninterrupted whole entry once (see
## `_plain_whole_entry`), and the restored whole entry at the same time in its own process (test/live/
## whole_entry_restored.gd), so the suite takes about one flight.

const StairPath := preload("res://scripts/core/underground_entry_stair_path.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Frontier := preload("res://scripts/core/underground_entry_frontier.gd")

## Decision 2044 (CI time): `_whole_entry(false)`'s result, kept by the descent test (which flies exactly that run) for
## the restore comparison, so the suite flies the uninterrupted whole entry once; empty until then.
var _plain_whole_entry: Array = []
## DEC-059 (P1): ticks of the last `_whole_entry` run, after T1 and before module 0's sill, on which the crew stood at M.
var _ticks_at_m: int = 0
## Runtime replacements by its record in the last `_whole_entry` run (none when uninterrupted).
var _entry_restores: int = 0
## Decision 2044 (CI time): the script that flies the restored whole entry (`_whole_entry(true)`) in its own process.
const RESTORED_FLIGHT: String = "res://test/live/whole_entry_restored.gd"
## Its wall-clock limit, seconds: one flight is about 5 minutes on Brendan's Mac and about 16 in CI, whose shard job
## stops at 30, so a hung child is named here first.
const RESTORED_LIMIT_SECONDS: int = 1500
## The restored flight's process, started by the descent test and joined by the restore comparison; -1 when none runs.
var _restored_pid: int = -1
var _restored_out: String = ""


func test_the_live_chain_builds_the_descent_down_the_stair_to_the_sill() -> void:
	"""ADR1229 increment 6b: past the prefix the crew cuts the descent's cubes from the surface, then installs T1-T6,
	each from the tread above: it walks from M to the crossing arrival, down the stair (walk-in, step forward, one
	descent per tread, step back onto the station), funds and fits the tread. DEC-059 (P1): T1 hauls every tread's
	wood to M, and each later tread follows straight down from the one before (step forward, one descent, step back).
	Decision 2044 (M2): then module 1 from landing 1 (T0' to T6'). Each group is installed exactly once; the foreman
	ends with G9 at the Kitchen (DEC-054), and a finished entry re-raises it. The crew's needs and R's stock are
	sustained (see DESCENT_DONE_TICK). Decision 2044 (CI time): this is `_whole_entry(false)`, kept for the restore
	comparison below, whose restored flight starts first and runs beside it in its own process."""
	_start_restored_flight()
	_plain_whole_entry = _whole_entry(false)
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	assert_equal(_ticks_at_m, 0, "DEC-059 (P1): after T1 the fitter never goes back to M; T2-T6 follow straight down")
	assert_equal(entry.step(), Settlement.UndergroundEntryRuntime.STEP_DONE, "the runtime finished the flight")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "and stopped at the Kitchen")
	assert_true(Settlement.UndergroundEntryRuntime.gap_of(entry.error()).begins_with("G9"), "named gap row G9")
	assert_true(entry._foreman.is_done() and entry._foreman.error() == &"", "every planned task done")
	assert_equal(_done_ledger(o, entry._foreman), DESCENT_LEDGER, "fifteen groups and every cut with their exact Work, once")
	assert_equal(o.construction.live_project_count(), 0, "every Project retired")
	assert_equal(_plain_whole_entry[0], DESCENT_DONE_TICK, "the finishing tick")
	assert_false(_host.begin_underground_entry(Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)), "a finished entry")
	assert_equal(_host.last_refusal(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "re-raises G9")
	_assert_stair_carry_published(o, entry)


func _assert_stair_carry_published(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime) -> void:
	"""Decision 1972: once module 0's sill is in, its stops A/U stand and the stair carry H <-> T6 is published (17
	CARRY edges, all EARTH_TIMBER, beside the ground hauls' two). Decision 2044 (M2): the carry stays module 0's
	(module 1's treads are fitted from the flight, P-2044-16 (a)); landing 1's floor stops stand below that sill and
	the last landing's floor stops are the lowest installed stops."""
	var stops: StairPath.Stops = entry._foreman._stops()
	assert_true(stops.at(StairPath.KIND_H, -1) != StairPath.NULL_REF, "H stands on L0")
	assert_true(stops.at(StairPath.KIND_A, StairPath.SILL_LEVEL) != StairPath.NULL_REF
		and stops.at(StairPath.KIND_U, StairPath.SILL_LEVEL) != StairPath.NULL_REF, "module 0's sill's A and U stand")
	assert_true(stops.at(StairPath.KIND_F, 1) != StairPath.NULL_REF and stops.at(StairPath.KIND_FP, 1) != StairPath.NULL_REF,
		"landing 1's F and F' stand")
	var frontier: RefCounted = entry._foreman._owners.frontier
	var endpoint: PackedInt32Array = PackedInt32Array()
	endpoint.resize(Frontier.row_fields(Frontier.ENDPOINT))
	var lowest: int = 0
	for selector: int in frontier.row_count(Frontier.ENDPOINT, frontier.content_revision()):
		if frontier.endpoint_into(selector, endpoint) == &"" and endpoint[0] == Frontier.INSTALLED_CONTACT:
			lowest = mini(lowest, endpoint[5])
	assert_equal(lowest, -1024 * StairPath.MODULES, "the last landing's floor stops are the lowest installed stops")
	var edge: Session.Retirement.Routes.Edge = Session.Retirement.Routes.Edge.new()
	var carry: PackedInt32Array = PackedInt32Array([0, 0])
	for row: int in o.routes._edge_capacity:
		if o.routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, o.routes._live.fields[Session.Retirement.Routes.E_GENERATION \
			* o.routes._edge_capacity + row])
		if o.routes.edge_metadata_into(ref, edge) != &"" or edge.mode != Profiles.MODE_CARRY: continue
		carry[0 if edge.family == 0 else 1] += 1
	assert_equal(carry, PackedInt32Array([17, 2]), "the stair carry H <-> T6 (17 EARTH_TIMBER), the ground hauls' 2")


## DEC-059: the whole-entry restore variant replaces the runtime by its record this often (ticks; prime), and
## cold-restores the route owners every ROUTE_RESTORE_EVERY ticks.
const ENTRY_RESTORE_EVERY: int = 11


func _whole_entry(restoring: bool) -> Array:
	"""[finish tick, error, ledger..., owner images..., final record, route and entry owner images] of the whole
	entry on the default schedule, uninterrupted or with its runtime and route owners restored along the way. Counts
	`_ticks_at_m` as it goes (reads only)."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var session: Session = _host.underground_session()
	var row: int = o.residents.directory().get_typed_row(live[2])
	var tick: int = 1
	_ticks_at_m = 0
	_entry_restores = 0
	while _host.underground_entry().is_running() and tick < FLIGHT_TICK_LIMIT:
		_sustain(o, _host.underground_entry(), tick)
		if restoring and tick % ENTRY_RESTORE_EVERY == 0:
			if not _replace_entry_with_its_record(session, tick): return []
			_entry_restores += 1
		if restoring and tick % ROUTE_RESTORE_EVERY == 0 and not _cold_restore_routes(o, tick): return []
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		if _at_m_past_t1(o, _host.underground_entry(), row): _ticks_at_m += 1
		tick += 1
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var record: PackedByteArray = PackedByteArray()
	assert_equal(entry.capture(record), &"", "final record")
	return [tick - 1, entry.error()] + _done_ledger(o, entry._foreman) + _snapshot() + [record] \
		+ RouteFixture.route_images(o.routes, o.world_routes, o.budget) \
		+ RouteFixture.entry_owner_images(o.contacts, o.delivery, o.budget)


func _at_m_past_t1(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, row: int) -> bool:
	"""DEC-059 (P1): after T1 is installed and before module 0's sill, the crew `row` stands at M."""
	var installed: int = _installed_groups(entry) if entry._foreman != null else 0
	return installed > PREFIX_INSTALLS and installed < MODULE_ZERO_INSTALLS \
		and o.routes._resident_pair(Session.Retirement.Routes.R_LOCATION_SLOT, row) == entry._published.endpoints[1]


func test_the_whole_entry_restored_along_the_way_ends_byte_identical() -> void:
	"""DEC-059: the whole entry (prefix, descent cuts with one claw entry a cube, T1 and the chained treads; decision
	2044: and module 1) on the default schedule, sustained (see DESCENT_DONE_TICK), uninterrupted and again with its
	runtime replaced by its record every ENTRY_RESTORE_EVERY ticks and its route owners cold-restored every
	ROUTE_RESTORE_EVERY ticks: the same finish, ledger and images. Decision 2044 (CI time): the uninterrupted run is
	the descent test's (`_plain_whole_entry`), flown here only when that test has not run it; the restored run is
	`_whole_entry(true)` flown by this suite's own fixture in the process the descent test started (or this test, when
	that one did not), with every assertion it made carried back here and any engine error, script error or leak it
	prints charged to this suite by the runner, as its own would be."""
	var plain: Array = _plain_whole_entry
	_plain_whole_entry = []
	if plain.is_empty():
		_start_restored_flight()
		plain = _whole_entry(false)
	assert_equal(plain.slice(0, 2), [DESCENT_DONE_TICK, Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT],
		"the uninterrupted entry ends at the Kitchen gap")
	assert_equal(plain.slice(2, 7), DESCENT_LEDGER, "with the whole flight's ledger")
	var restored: Array = _joined_restored_flight()
	if restored.is_empty(): return
	assert_equal(restored.size(), plain.size(), "the restored entry's result has the same shape")
	for index: int in plain.size():
		assert_equal(restored[index], plain[index], "whole-entry image %d is byte-identical after restores" % index)


func _start_restored_flight() -> void:
	"""Decision 2044 (CI time): start `_whole_entry(true)` in its own process (test/live/whole_entry_restored.gd), once.
	It inherits this worker's output, so the runner audits what it prints as this suite's own."""
	if _restored_pid > 0: return
	_restored_out = ProjectSettings.globalize_path("user://whole_entry_restored_%d.bin" % OS.get_process_id())
	DirAccess.remove_absolute(_restored_out)
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
		RESTORED_FLIGHT, "--", "--out", _restored_out]
	_restored_pid = OS.create_process(OS.get_executable_path(), args)
	assert_true(_restored_pid > 0, "the restored whole entry's process started")


func _joined_restored_flight() -> Array:
	"""Wait for the restored flight's process and return `_whole_entry(true)`'s result, its failures recorded here and
	its assertions counted here; [] when it did not finish or wrote no record."""
	if _restored_pid <= 0: return []
	var began: int = Time.get_ticks_msec()
	while OS.is_process_running(_restored_pid) and Time.get_ticks_msec() - began < RESTORED_LIMIT_SECONDS * 1000:
		OS.delay_msec(200)
	var finished: bool = not OS.is_process_running(_restored_pid)
	if not finished: OS.kill(_restored_pid)
	assert_true(finished, "the restored whole entry finished within %d s" % RESTORED_LIMIT_SECONDS)
	assert_equal(OS.get_process_exit_code(_restored_pid) if finished else -1, 0, "and its process exited 0")
	_restored_pid = -1
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_restored_out)
	DirAccess.remove_absolute(_restored_out)
	var record: Variant = bytes_to_var(bytes) if not bytes.is_empty() else null
	assert_true(record is Dictionary, "the restored whole entry wrote its record")
	if not record is Dictionary: return []
	assert_true(record["checks"], "it ran with the runtime-cache checks on (decision 1952)")
	assert_true(record["assertions"] > DESCENT_DONE_TICK, "it asserted every tick (%d)" % record["assertions"])
	@warning_ignore("integer_division") var restores: int = DESCENT_DONE_TICK / ENTRY_RESTORE_EVERY
	assert_equal(record["restores"], restores, "it was the restored flight: its runtime replaced every %d ticks"
		% ENTRY_RESTORE_EVERY)
	assert_equal(record["at_m"], 0, "DEC-059 (P1) on the restored flight too: never back at M after T1")
	# test_case.gd's counter is the framework's; this only adds the child's own assertions, made in that process
	# through the same assert_* calls, so the totals stay comparable with the in-process run it replaced.
	assertions += record["assertions"]
	for failure: String in record["failures"]:
		failures.append("restored whole entry: %s" % failure)
	return record["result"]

