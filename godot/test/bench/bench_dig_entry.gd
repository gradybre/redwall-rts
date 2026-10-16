extends "res://test/underground_host_case.gd"
## Decision 1951: the first-entry dig benchmark. The live settlement (generated world, mounted underground) runs
## `run_tick` from the surface walk to the end of the entry prefix (ADR 1227, DONE_TICK), with the planned
## foreman's own tick (`UndergroundEntryRuntime.advance`, which `_advance_underground_entry` calls) timed apart from
## the whole settlement tick. Run by tools/benchmark_dig_tick.gd, never by the suite; REDWALL_DIG_TRACE adds a
## per-tick state trace (decision 1951 "Behaviour proof").

const Meter := preload("res://test/bench/dig_bench_meter.gd")
## A foreman tick at or over this many microseconds is listed as a stall.
const STALL_US: int = 20000


class TimedRuntime extends Settlement.UndergroundEntryRuntime:
	## The production runtime with its tick timed; behaviour is the parent's exactly.
	var meter: Meter = null

	func advance(tick: int) -> StringName:
		"""The parent's tick, timed as `foreman_advance`, and named as a stall when it is one."""
		var started: int = Time.get_ticks_usec()
		var code: StringName = super.advance(tick)
		var spent: int = Time.get_ticks_usec() - started
		meter.add(&"foreman_advance", spent)
		if spent >= STALL_US: meter.add(&"foreman_stall", spent)
		return code


func test_entry_prefix_one_crew() -> void:
	"""The whole entry prefix with its one crew mole; the prefix finishes on its pinned tick and ledger."""
	var meter: Meter = Meter.new()
	var o: Session.Retirement.Owners = _begin_timed(meter)
	if o == null: return
	var entry: Settlement.UndergroundEntryRuntime = _host.underground_entry()
	var tick: int = 1
	var started: int = Time.get_ticks_usec()
	while entry.is_running() and not _prefix_done(entry) and tick < 8000:
		var before: int = Time.get_ticks_usec()
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		meter.add(&"settlement_run_tick", Time.get_ticks_usec() - before)
		if meter.tracing(): meter.trace(tick, _images(o, entry))
		tick += 1
	var wall: int = Time.get_ticks_usec() - started
	assert_equal(tick - 1, DONE_TICK, "the finishing tick")
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER, "the exact prefix ledger")
	meter.trace_event("final tick=%d ledger=%s" % [tick - 1, _done_ledger(o, entry._foreman)])
	meter.emit("entry1", "ticks=%d residents=%d wall_us=%d load=%s" % [tick - 1, o.residents.living_count(), wall,
		OS.get_environment("REDWALL_DIG_LOAD")])
	meter.write_trace("entry1")


func _begin_timed(meter: Meter) -> Session.Retirement.Owners:
	"""`_begin_live_entry()` with the timed runtime adopted before the entry begins."""
	_generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")
	var runtime: TimedRuntime = TimedRuntime.new()
	runtime.meter = meter
	_host._underground_entry = runtime
	assert_true(_host.begin_underground_entry(Vector3i(60 * 2048 + 512, 512, 50 * 2048 + 512)),
		"foreman planned and the walk begun: %s" % _host.last_refusal())
	if not failures.is_empty(): return null
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	_stage(o, runtime._output, &"wood", 7000)
	_stage(o, runtime._output, &"stone", 2000)
	return o


func _images(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime) -> Array[PackedByteArray]:
	"""Every settlement store `_snapshot()` covers, both route owners and the entry runtime's own record."""
	var images: Array[PackedByteArray] = _snapshot()
	images.append(o.sites.state_bytes())
	images.append(o.work.state_bytes())
	images.append_array(RouteFixture.route_images(o.routes, o.world_routes, o.budget))
	var record: PackedByteArray = PackedByteArray()
	entry.capture(record)
	images.append(record)
	return images
