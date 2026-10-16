extends "res://test/framework/test_case.gd"
## Decision 1951: the room-loop dig benchmark. ADR 1213's whole-Kitchen loop (8 cubes, one builder, content 6) with
## every owner call it makes timed: `Routes.advance_tick` and `Work.tick_solo` per fixed tick, and the one-tick
## events (contact selection, phase open, START, settlement, route handoffs). Run by tools/benchmark_dig_tick.gd,
## never by the suite. With REDWALL_DIG_TRACE set it also writes a per-tick state trace of every owner the loop
## drives, so two revisions can be compared tick for tick (decision 1951 "Behaviour proof").

const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Meter := preload("res://test/bench/dig_bench_meter.gd")
const Routes := StationTests.Routes
const Planner := StationTests.Planner
const Contract := StationTests.Contract
const Space := StationTests.Space
const Budget := StationTests.Budget
const Frontier := StationTests.Frontier
const Face := StationTests.Face
const Publication := StationTests.Publication
const NULL_REF: Vector2i = Vector2i(-1, 0)


class TimedFixture extends StationTests.StepFixture:
	## The ADR 1213 loop with each owner call wrapped in Time.get_ticks_usec(); behaviour is the parent's exactly.
	var meter: Meter = Meter.new()
	var _tick_cost: int = 0
	var _earning: bool = false

	func _timed_advance() -> int:
		"""One fixed tick of Routes, timed into the open tick sample."""
		var started: int = Time.get_ticks_usec()
		var moved: int = _routes.advance_tick(tick)
		var spent: int = Time.get_ticks_usec() - started
		meter.add(&"routes_advance_earning" if _earning else &"routes_advance_travel", spent)
		_tick_cost += spent
		return moved

	func _close_tick() -> void:
		"""Record the summed owner cost of the tick just run, then its trace line."""
		meter.add(&"tick_earning" if _earning else &"tick_travel", _tick_cost)
		_tick_cost = 0
		if meter.tracing(): meter.trace(tick, owner_images())

	func owner_images() -> Array[PackedByteArray]:
		"""Every owner the loop drives, as its own capture or state bytes."""
		var images: Array[PackedByteArray] = [sites.state_bytes(), _work.state_bytes(), _jobs.state_bytes(),
			_inventory.state_bytes(), _construction.state_bytes()]
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		for owner: Object in [_routes, _binding, endpoints]:
			var image: PackedByteArray = PackedByteArray()
			if cold != 0: owner.call(&"capture_state_into", cold, image)
			images.append(image)
		if cold != 0: _budget.release(cold)
		return images

	func _timed_event(series: StringName, started: int) -> void:
		"""One single-tick event's cost."""
		meter.add(series, Time.get_ticks_usec() - started)

	func face_for(job: Vector2i, profile: int) -> void:
		"""The parent's turn, with its one tick timed."""
		var stride: int = _profiles._profile_capacity
		if _profiles._live.fields[StationTests.Profiles.F_YAW_KIND * stride + profile] != StationTests.Profiles.YAW_EXACT: return
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual actor")
		var yaw: int = _profiles._live.fields[StationTests.Profiles.F_YAW * stride + profile]
		if actor.yaw == yaw: return
		var started: int = Time.get_ticks_usec()
		assert_equal(StationTests.Phase.WorldFixture.Binding.turn_actor(_binding, _worker, job, yaw, Space.MAX_CHECKS), &"", "turn")
		_timed_event(&"event_turn", started)
		tick += 1
		_timed_advance(); _close_tick()

	func walk_leg(job: Vector2i, to: Vector2i, profile: int) -> void:
		"""The parent's leg, with the handoff and the route request timed as one event."""
		face_for(job, profile)
		var started: int = Time.get_ticks_usec()
		assert_equal(_routes.refresh_travel_actor(_worker, job, profile, 1, StationTests.CONTENT, 0, -1, tool), &"", "handoff")
		assert_equal(_routes.request_route(_worker, to, tick), &"", "route on %d" % profile)
		_timed_event(&"event_handoff_route", started)
		wait_on(job, profile)

	func wait_on(job: Vector2i, profile: int) -> void:
		"""Canonical 30 Hz ticks until the source reports READY, each timed."""
		var end: int = tick + 400
		while Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, StationTests.CONTENT) != &"" and tick < end:
			tick += 1
			assert_equal(_timed_advance(), 1, "actual headless tick")
			_close_tick()
			if not failures.is_empty(): return
		assert_equal(Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, StationTests.CONTENT), &"", "READY")

	func enter_source_work(job: Vector2i) -> void:
		"""READY to WORK on the contact's row, each tick timed."""
		var started: int = Time.get_ticks_usec()
		assert_equal(_routes.refresh_work_actor(_worker, job, work_profile, 1, StationTests.CONTENT, 0, -1, tool), &"", "work handoff")
		_timed_event(&"event_handoff_work", started)
		var end: int = tick + 100
		while Routes.source_work_leaf_refusal(_routes, _worker, job, work_profile, 1, StationTests.CONTENT) != &"" and tick < end:
			tick += 1
			assert_equal(_timed_advance(), 1, "actual source entry tick")
			_close_tick()
		assert_equal(Routes.source_work_leaf_refusal(_routes, _worker, job, work_profile, 1, StationTests.CONTENT), &"", "WORK")

	func earn(job: Vector2i) -> void:
		"""Each earning tick is Routes then Work, both timed into one sample."""
		var remaining: StationTests.Phase.IntMath.IntResult = StationTests.Phase.IntMath.IntResult.new()
		var row: int = _residents.directory().get_typed_row(job)
		var end: int = tick + 1000
		_earning = true
		while _jobs.remaining_mwu_into(row, remaining) and remaining.value > 0 and tick < end and failures.is_empty():
			tick += 1
			assert_equal(_timed_advance(), 1, "actual WORK tick")
			var started: int = Time.get_ticks_usec()
			var worked: StationTests.Phase.WorldFixture.Work.TickResult = _work.tick_solo(row)
			var spent: int = Time.get_ticks_usec() - started
			meter.add(&"work_tick_solo", spent); _tick_cost += spent
			_close_tick()
			assert_true(worked.ok, "actual paid Work: %s" % worked.error)
			accepted_mwu += worked.accepted_mwu if worked.ok else 0
		_earning = false
		assert_equal(_routes.request_source_ready(_worker, job), &"", "loop-boundary recovery")
		wait_on(job, work_profile)

	func open_phase_job(site: Vector2i, operation: int) -> Vector2i:
		"""Phase admission with its Job, timed as one event."""
		var started: int = Time.get_ticks_usec()
		var job: Vector2i = super.open_phase_job(site, operation)
		_timed_event(&"event_open_phase", started)
		meter.trace_event("open %d %d %s" % [site.x, operation, job])
		return job

	func start_phase(site: Vector2i, operation: int, job: Vector2i) -> void:
		"""Claims, deliveries, worker binding and START, timed as one event."""
		var started: int = Time.get_ticks_usec()
		super.start_phase(site, operation, job)
		_timed_event(&"event_start", started)

	func work_phase(site: Vector2i, operation: int) -> bool:
		"""The parent's phase with its settlement timed (the parent's own call is replaced, not repeated)."""
		var job: Vector2i = open_phase_job(site, operation)
		if job == NULL_REF or not failures.is_empty(): return false
		if operation == Contract.OP_BRACE: approach(job)
		if failures.is_empty(): enter_source_work(job)
		if failures.is_empty(): start_phase(site, operation, job)
		if failures.is_empty(): earn(job)
		if not failures.is_empty(): return false
		var started: int = Time.get_ticks_usec()
		var settled: StationTests.Phase.WorldFixture.Construction.OpResult = sites.settle_phase(site)
		_timed_event(&"event_settle", started)
		meter.trace_event("settle %d %d %s %s" % [site.x, operation, settled.ok, settled.error])
		assert_true(settled.ok, "actual settlement %d: %s" % [operation, settled.error])
		return settled.ok and failures.is_empty()

	func loop_step(room: Vector2i, after: int) -> StringName:
		"""Contact selection and publication, timed as one event."""
		var started: int = Time.get_ticks_usec()
		var code: StringName = super.loop_step(room, after)
		_timed_event(&"event_next_contact", started)
		meter.trace_event("step %d %s %d" % [after, code, last_key])
		return code

	func sample(_at: int) -> void:
		"""The parent prints its proof peaks; the benchmark does not."""
		return


var _h: TimedFixture = null


func after_each() -> void:
	"""Propagate fixture assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func test_room_loop_one_builder() -> void:
	"""The whole clamped Kitchen with one builder; the loop still pays all eight cubes exactly."""
	Meter.time_answered_caches()
	_h = TimedFixture.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return
	var started: int = Time.get_ticks_usec()
	_h.room_loop(room)
	var wall: int = Time.get_ticks_usec() - started
	assert_equal(_h.completed.size(), StationTests.KITCHEN_SITES, "all eight cubes paid")
	assert_equal(_h.accepted_mwu, StationTests.KITCHEN_SITES * (Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU
		+ Contract.FINISH_WORK_MWU), "exact Work")
	_h.meter.trace_event("final tick=%d mwu=%d completed=%s" % [_h.tick, _h.accepted_mwu, _h.completed])
	_h.meter.emit("room1", "ticks=%d cubes=%d wall_us=%d load=%s" % [_h.tick, _h.completed.size(), wall,
		OS.get_environment("REDWALL_DIG_LOAD")])
	_h.meter.write_trace("room1")
