extends "res://test/framework/test_case.gd"
## Coverage for GameManager as a thin adapter over `scripts/core/sim_clock.gd`.
##
## The clock's own rules are covered by `test_sim_clock.gd`; this suite covers only what the
## adapter adds: the BOOT/PLAYING/PAUSED projection, the PLAYER pause reason, speed selection,
## and the calendar/day readouts the HUD binds to.
##
## RETIRED with ARCH-MIG-006 step 4 (see docs/tasks/02_test_migration_ledger.md):
##   * `test_cycle_speed_wraps_through_multipliers` asserted a 3-speed cycle including 3x,
##     which REQ-SET-003 forbids. Replaced by test_speed_cycle_is_one_two_four.
##   * `test_cycle_speed_drives_the_engine_clock` asserted `Engine.time_scale` carries
##     simulation time. Authoritative time is integer fixed ticks and host scaling is a
##     scheduler input only, so the contract is inverted in
##     test_engine_time_scale_is_never_written.
## The two elapsed-time tests are not retired: their contracts (paused frames advance no
## simulation, restart resets the clock) survive and are re-expressed in completed ticks.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")

## 40000 us is 1/25 of a real second. 25 such frames are exactly one real second, and at every
## selectable speed a frame stays under the clock's 8-tick drain cap, so no frame is clipped.
const FRAME_USEC: int = 40000
const FRAMES_PER_REAL_SECOND: int = 25
## 100000 us at 2x is exactly 6 ticks with no remainder: the cheapest way to reach a boundary.
const SIX_TICK_FRAME_USEC: int = 100000
## 300000 us at 1x is 9 whole ticks owed against the clock's 8-tick drain cap, so one such frame
## is guaranteed to consider a ninth tick and cannot end merely because it ran out of debt.
const NINE_TICK_FRAME_USEC: int = 300000
## One real second at 1x is 30 ticks owed against the same cap: 8 run, 22 stay owed, and
## 4 * 22000000 > 30000000 is strictly more than the quarter-second REQ-SET-008 backlog.
const OVERLOAD_FRAME_USEC: int = 1000000
const OVERLOAD_TICKS_LEFT_OWED: int = 22

var _game: GameManagerScript = null
var _states: Array[int] = []
var _speeds: Array[int] = []
var _days: Array[int] = []
var _diagnostics: Array[String] = []
## Recorded by the fake simulation bound in the ARCH-MIG-006 step 6 tests below.
var _sim_ticks: Array[int] = []
var _sim_days: Array[int] = []
var _sim_seasons: Array[int] = []
var _order: Array[String] = []
## Reused by the scheduler-queue tests so no test path allocates a result per submission.
var _submit: SchedulerEventsScript.SubmitResult = SchedulerEventsScript.SubmitResult.new()
## Tick index at which `_on_sim_tick_that_holds_critical` submits its hold; 0 disables it.
var _hold_on_tick: int = 0
## Tick index at which `_on_sim_tick_that_pauses` calls `pause_game()`; 0 disables it.
var _pause_on_tick: int = 0


func before_each() -> void:
	"""Build a fresh game manager outside the scene tree and record its UI signals."""
	_game = GameManagerScript.new()
	_states = []
	_speeds = []
	_days = []
	_diagnostics = []
	_sim_ticks = []
	_sim_days = []
	_sim_seasons = []
	_order = []
	_hold_on_tick = 0
	_pause_on_tick = 0
	_game.state_changed.connect(_on_state_changed)
	_game.speed_changed.connect(_on_speed_changed)
	_game.day_advanced.connect(_on_day_advanced)
	_game.clock_diagnostic.connect(_on_clock_diagnostic)


func after_each() -> void:
	"""Free the manager built for the test."""
	if _game != null:
		_game.free()
		_game = null


func _run_frames(count: int, frame_usec: int) -> int:
	"""Feed `count` host frames of `frame_usec` into the adapter. Returns total ticks run."""
	var ticks: int = 0
	for index: int in count:
		ticks += _game.advance_host_time(frame_usec)
	return ticks


func test_starts_in_boot_state() -> void:
	"""Before start_game() the manager reports the boot state."""
	assert_equal(_game.get_state(), GameManagerScript.GameState.BOOT, "state is BOOT")
	assert_equal(_game.get_state_name(), "BOOT", "state name matches the enum")


func test_start_game_enters_play() -> void:
	"""start_game() moves to PLAYING at 1x and signals the transition once."""
	_game.start_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "state is PLAYING")
	assert_equal(_game.get_speed(), SimClockScript.SPEED_NORMAL, "speed starts at 1x")
	assert_equal(_states.size(), 1, "the transition was signalled once")
	assert_equal(_speeds, [1] as Array[int], "the starting speed was published once")


func test_pause_and_resume() -> void:
	"""Pausing and resuming move between PAUSED and PLAYING."""
	_game.start_game()
	_game.pause_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "state is PAUSED")
	assert_equal(_game.get_effective_speed(), SimClockScript.SPEED_PAUSED, "effective speed is 0")
	_game.resume_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "state is PLAYING again")


func test_toggle_pause_flips_state() -> void:
	"""toggle_pause() alternates the PLAYER pause reason."""
	_game.start_game()
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "first toggle pauses")
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "second toggle resumes")


func test_pause_does_nothing_during_boot() -> void:
	"""Pause controls are inert until the game has started."""
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.BOOT, "still in BOOT")
	assert_equal(_states.size(), 0, "no transition was signalled")


func test_resume_does_nothing_while_playing() -> void:
	"""Resuming an unpaused game is a no-op, not a duplicate transition."""
	_game.start_game()
	_game.resume_game()
	assert_equal(_states.size(), 1, "only the start transition was signalled")


func test_speed_cycle_is_one_two_four() -> void:
	"""The cycle is exactly 1x, 2x, 4x and wraps. REQ-SET-003 has no 3x."""
	_game.start_game()
	var seen: Array[int] = []
	for index: int in 4:
		seen.append(_game.cycle_speed())
	assert_equal(seen, [2, 4, 1, 2] as Array[int], "the cycle is 1 -> 2 -> 4 -> 1")
	assert_false(SimClockScript.SELECTABLE_SPEEDS.has(3), "3x is not a selectable speed")


func test_three_times_speed_is_refused() -> void:
	"""set_speed(3) is refused outright and leaves the current speed untouched."""
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_DOUBLE)
	assert_false(_game.set_speed(3), "3x is refused")
	assert_equal(_game.get_speed(), SimClockScript.SPEED_DOUBLE, "the speed did not change")


func test_zero_speed_is_not_requestable_without_a_pause_reason() -> void:
	"""Pause is authoritative through the reason mask, so speed 0 cannot be requested."""
	_game.start_game()
	assert_false(_game.set_speed(SimClockScript.SPEED_PAUSED), "speed 0 is refused")
	assert_false(_game.is_paused(), "the refusal did not pause the game")


func test_engine_time_scale_is_never_written() -> void:
	"""Host scaling is a scheduler input, not the clock: the adapter never touches it."""
	var before: float = Engine.time_scale
	_game.start_game()
	_game.cycle_speed()
	_game.cycle_speed()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	_game.pause_game()
	assert_almost_equal(Engine.time_scale, before, "Engine.time_scale is untouched")


func test_one_real_second_runs_thirty_ticks_at_one_times() -> void:
	"""REQ-SET-002: the fixed step is 30 ticks per real second at 1x."""
	_game.start_game()
	var ticks: int = _run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	assert_equal(ticks, 30, "one real second is 30 ticks")
	assert_equal(_game.get_completed_tick(), 30, "the completed tick count agrees")


func test_double_and_quadruple_run_exactly_two_and_four_times_the_ticks() -> void:
	"""REQ-SET-003: speed multiplies identical ticks per real second, it never changes a tick."""
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_DOUBLE)
	assert_equal(_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC), 60, "2x runs 60 ticks per second")
	_game.set_speed(SimClockScript.SPEED_QUADRUPLE)
	assert_equal(_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC), 120, "4x runs 120 ticks per second")


func test_ticks_only_accumulate_while_playing() -> void:
	"""Paused host frames advance no simulation ticks."""
	_game.start_game()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	_game.pause_game()
	var paused_ticks: int = _run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	assert_equal(paused_ticks, 0, "no tick ran while paused")
	assert_equal(_game.get_completed_tick(), 30, "the tick count did not move")


func test_paused_host_time_does_not_burst_on_resume() -> void:
	"""Paused wall time accrues no debt, so resuming does not replay the pause."""
	_game.start_game()
	_game.pause_game()
	_run_frames(FRAMES_PER_REAL_SECOND * 10, FRAME_USEC)
	_game.resume_game()
	assert_equal(_run_frames(1, FRAME_USEC), 1, "the first resumed frame runs one ordinary tick")


func test_restarting_resets_the_tick_clock() -> void:
	"""A second start_game() does not inherit the previous run's ticks."""
	_game.start_game()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	_game.start_game()
	assert_equal(_game.get_completed_tick(), 0, "the clock restarted at tick 0")
	assert_equal(_game.get_calendar_text(), "Y1 spring 1", "the calendar restarted too")


func test_calendar_starts_at_six_am_of_year_one() -> void:
	"""GDD §5.1: tick 0 is 06:00 of year 1, spring, day 1 under the offset calendar."""
	_game.start_game()
	assert_equal(_game.get_calendar_text(), "Y1 spring 1", "date reads year 1 spring day 1")
	assert_equal(_game.get_clock_text(), "06:00", "tick 0 is 06:00, not midnight")
	assert_equal(_game.get_absolute_day(), 1, "the first day is day 1")


func test_first_midnight_raises_one_day_boundary() -> void:
	"""The first 00:00 crossing is tick 13500, and it is published exactly once."""
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_DOUBLE)
	_run_frames(SimClockScript.FIRST_MIDNIGHT_TICK / 6, SIX_TICK_FRAME_USEC)
	assert_equal(_game.get_completed_tick(), SimClockScript.FIRST_MIDNIGHT_TICK, "reached tick 13500")
	assert_equal(_days, [2] as Array[int], "one boundary, into absolute day 2")
	assert_equal(_game.get_clock_text(), "00:00", "the boundary tick reads midnight")


func test_player_resume_cannot_clear_another_pause_reason() -> void:
	"""Pause reasons compose: releasing PLAYER leaves a CRITICAL pause standing."""
	_game.start_game()
	_game.clock().apply_overload()
	_game.advance_host_time(FRAME_USEC)
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "the clock paused itself")
	_game.resume_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "still paused for CRITICAL")
	assert_equal(_game.get_pause_reason_names(), ["CRITICAL"] as Array[String], "CRITICAL is the reason")


func test_acknowledging_overload_clears_the_diagnostic_pause() -> void:
	"""The explicit recovery path is the only way out of a REQ-SET-008 diagnostic pause."""
	_game.start_game()
	_game.clock().apply_overload()
	_game.advance_host_time(FRAME_USEC)
	_game.acknowledge_overload()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "play resumed")
	assert_equal(_game.clock().acknowledged_catchup_resets(), 1, "the drop was counted, not hidden")


func test_overload_step_down_is_published_to_the_ui() -> void:
	"""A ladder step from 4x to 2x reaches the HUD as a speed change and a diagnostic."""
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_QUADRUPLE)
	_speeds = []
	_game.clock().apply_overload()
	assert_equal(_game.get_speed(), SimClockScript.SPEED_DOUBLE, "4x stepped down to 2x")
	assert_equal(_speeds, [2] as Array[int], "the reduced speed was published once")
	assert_equal(_diagnostics.size(), 1, "the reason was published once")


func test_no_simulation_is_bound_by_default() -> void:
	"""A bare GameManager runs the clock and drives no simulation, which is what a test wants."""
	_game.start_game()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	assert_false(_game.has_simulation(), "nothing is bound")
	assert_equal(_sim_ticks, [] as Array[int], "no tick reached a simulation")
	assert_true(_game.get_completed_tick() > 0, "the clock still ran")


func test_bind_simulation_refuses_an_invalid_callable() -> void:
	"""An empty step or day-boundary callable is refused by name and binds nothing."""
	assert_false(_game.bind_simulation(Callable(), _on_sim_day_boundary), "an empty step refuses")
	assert_equal(_game.last_refusal(), &"INVALID_SIMULATION_STEP", "the step refusal is named")
	assert_false(_game.bind_simulation(_on_sim_tick, Callable()), "an empty boundary refuses")
	assert_equal(_game.last_refusal(), &"INVALID_SIMULATION_DAY_BOUNDARY", "that refusal is named")
	assert_false(_game.has_simulation(), "nothing was bound")


func test_bind_simulation_refuses_a_second_binding() -> void:
	"""Two simulations may not share one clock: the second bind is refused, not silently swapped."""
	assert_true(_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary), "the first bind holds")
	assert_false(_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary), "the second is refused")
	assert_equal(_game.last_refusal(), &"SIMULATION_ALREADY_BOUND", "the reason is named")
	assert_true(_game.has_simulation(), "the first binding survives")


func test_the_bound_step_receives_every_completed_tick_index_in_order() -> void:
	"""The simulation is called once per completed tick, with indices ascending from 1."""
	_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary)
	_game.start_game()
	_run_frames(4, FRAME_USEC)
	assert_equal(_sim_ticks, [1, 2, 3, 4] as Array[int], "one call per completed tick, in order")
	assert_equal(_sim_ticks.size(), _game.get_completed_tick(), "as many calls as completed ticks")


func test_a_paused_clock_calls_the_bound_simulation_not_at_all() -> void:
	"""REQ-SET-004: a paused clock accumulates no debt, so no tick reaches the simulation."""
	_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary)
	_game.start_game()
	_game.pause_game()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	assert_equal(_sim_ticks, [] as Array[int], "no tick ran while paused")
	assert_equal(_game.get_completed_tick(), 0, "and none was completed")


func test_unbind_simulation_stops_the_calls_without_stopping_the_clock() -> void:
	"""Releasing the binding leaves the clock running and drives nothing."""
	_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary)
	_game.start_game()
	_run_frames(2, FRAME_USEC)
	var before: int = _sim_ticks.size()
	_game.unbind_simulation()
	_run_frames(2, FRAME_USEC)
	assert_true(before > 0, "the simulation ran while bound")
	assert_equal(_sim_ticks.size(), before, "no further tick reached it")
	assert_true(_game.get_completed_tick() > before, "the clock kept running")


func test_the_day_boundary_runs_the_simulation_before_the_ui_signal() -> void:
	"""REQ-SET-007's daily work runs first; the HUD then observes a committed day."""
	_game.bind_simulation(_on_sim_tick, _on_sim_day_boundary)
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_DOUBLE)
	_run_frames(SimClockScript.FIRST_MIDNIGHT_TICK / 6, SIX_TICK_FRAME_USEC)
	assert_equal(_sim_days, [2] as Array[int], "the simulation saw absolute day 2")
	assert_equal(_sim_seasons, [0] as Array[int], "and the new day's season, spring")
	assert_equal(_order, ["simulation", "signal"] as Array[String], "simulation first, UI second")


# --- R07-SCHED-001: the scheduler-event queue in the running game (decision 0084) ---------------

func test_the_queue_is_bound_to_the_clock_the_manager_reports() -> void:
	"""The queue applies drained events to the clock this node hands out, never a second one."""
	_game.start_game()
	assert_not_null(_game.scheduler_events(), "the manager owns a scheduler-event queue")
	assert_true(_game.scheduler_events().clock() == _game.clock(), "one clock, not two")


func test_restarting_clears_the_queue_before_rebinding_it_to_the_new_clock() -> void:
	"""Decision 0054 open item 2: `clear()` must precede `rebind_clock()`, which refuses otherwise.

	A raw submission leaves the queue holding a record stamped against the OLD clock's numbering.
	`rebind_clock()` refuses a non-empty queue by design, so a restart that rebound first would be
	refused and would leave the queue pointing at a dead clock.
	"""
	_game.start_game()
	assert_true(_game.scheduler_events().submit_speed_into(SimClockScript.SPEED_DOUBLE, _submit),
		"the raw submission is admitted")
	assert_equal(_game.scheduler_events().pending_count(), 1, "the queue holds it undrained")
	assert_true(_game.start_game(), "the restart is not refused by that pending record")
	assert_equal(_game.scheduler_events().pending_count(), 0, "the restart cleared the queue")
	assert_true(_game.scheduler_events().clock() == _game.clock(), "and rebound to the new clock")
	assert_equal(_game.get_speed(), SimClockScript.SPEED_NORMAL, "the stale event reached nothing")


func test_a_restart_resets_the_queue_sequence_and_spends_one_on_the_opening_resume() -> void:
	"""Each restart begins at sequence 1 and consumes it releasing the fresh clock's PLAYER pause."""
	_game.start_game()
	_run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	_game.pause_game()
	_game.start_game()
	assert_equal(_game.scheduler_events().next_sequence_low(), 2, "sequence 1 was spent, next is 2")
	assert_equal(_game.scheduler_events().next_sequence_high(), 0, "the high word is still zero")
	assert_equal(_game.scheduler_events().last_applied_sequence_low(), 1, "and it was applied")
	assert_false(_game.is_paused(), "the opening resume released the new clock's PLAYER pause")


func test_every_speed_and_pause_control_consumes_exactly_one_sequence() -> void:
	"""Four controls, four admissions, four applications, and an empty queue between frames."""
	_game.start_game()
	_game.pause_game()
	_game.resume_game()
	_game.set_speed(SimClockScript.SPEED_QUADRUPLE)
	var events: SchedulerEventsScript = _game.scheduler_events()
	assert_equal(events.admitted_count(), 4, "the opening resume, pause, resume and speed change")
	assert_equal(events.applied_count(), 4, "every one of them was drained and applied")
	assert_equal(events.next_sequence_low(), 5, "four sequences were spent from 1")
	assert_equal(events.pending_count(), 0, "nothing is left queued between frames")
	assert_equal(_game.get_speed(), SimClockScript.SPEED_QUADRUPLE, "the speed event landed")


func test_a_refused_speed_leaves_the_queue_byte_identical_and_names_its_code() -> void:
	"""Allocate before consume: 3x is refused by the queue, spends no sequence and pauses nothing."""
	_game.start_game()
	var events: SchedulerEventsScript = _game.scheduler_events()
	var admitted_before: int = events.admitted_count()
	var sequence_before: int = events.next_sequence_low()
	assert_false(_game.set_speed(3), "3x is refused")
	assert_equal(_game.last_refusal(), &"SCHEDULER_SPEED_NOT_SELECTABLE", "by the queue's own code")
	assert_equal(events.admitted_count(), admitted_before, "no record was written")
	assert_equal(events.next_sequence_low(), sequence_before, "and no sequence was consumed")
	assert_equal(events.pending_count(), 0, "the queue is still empty")


func test_speed_zero_is_refused_by_the_queue_rather_than_pausing_through_it() -> void:
	"""SPEED_PAUSED is not a selectable speed, so it cannot reach the clock as a speed event."""
	_game.start_game()
	assert_false(_game.set_speed(SimClockScript.SPEED_PAUSED), "speed 0 is refused")
	assert_equal(_game.last_refusal(), &"SCHEDULER_SPEED_NOT_SELECTABLE", "the queue named it")
	assert_false(_game.is_paused(), "and nothing paused")


func test_controls_refuse_before_start_game_by_name() -> void:
	"""Pause controls are inert during BOOT and say so instead of queueing against a dead clock."""
	assert_false(_game.pause_game(), "pause refuses during boot")
	assert_equal(_game.last_refusal(), &"GAME_NOT_STARTED", "the refusal is named")
	assert_false(_game.resume_game(), "resume refuses during boot")
	assert_false(_game.toggle_pause(), "toggle refuses during boot")
	assert_equal(_game.scheduler_events().pending_count(), 0, "nothing was queued")


func test_a_player_resume_through_the_queue_clears_player_only() -> void:
	"""The queue's ordinary-Resume path cannot express clearing MENU, so a menu pause survives."""
	_game.start_game()
	_game.pause_game()
	assert_true(_game.scheduler_events().submit_pause_into(SchedulerEventsScript.PRODUCER_MENU,
		SimClockScript.MENU, SchedulerEventsScript.VALUE_HOLD, _submit), "a menu hold is admitted")
	_game.advance_host_time(FRAME_USEC)
	_game.resume_game()
	assert_true(_game.is_paused(), "the game is still paused")
	assert_equal(_game.get_pause_reason_names(), ["MENU"] as Array[String], "MENU alone still holds")


func test_an_event_submitted_inside_a_tick_is_applied_by_the_barrier_before_the_next_tick() -> void:
	"""ARCH-CMD-002's barrier: a hold produced during tick 2 stops tick 3 of the SAME frame.

	This is what `advance_frame()` buys and a bare `advance()` cannot: the record is stamped
	boundary 2 while `completed_tick()` still reads 1, so no drain between frames can apply it,
	and only the per-tick `before_tick` pump reaches it before the frame considers tick 3.
	"""
	_hold_on_tick = 2
	_game.bind_simulation(_on_sim_tick_that_holds_critical, _on_sim_day_boundary)
	_game.start_game()
	var ran: int = _game.advance_host_time(NINE_TICK_FRAME_USEC)
	assert_equal(ran, 2, "the frame stopped at tick 2 instead of draining its eight-tick cap")
	assert_equal(_sim_ticks, [1, 2] as Array[int], "and the simulation saw exactly those two")
	assert_true(_game.is_paused(), "the hold produced inside tick 2 took effect")
	assert_equal(_game.get_pause_reason_names(), ["CRITICAL"] as Array[String], "as CRITICAL")
	assert_equal(_game.clock().owed_ticks(), 7, "the seven undrained ticks stay owed, not skipped")


func test_pausing_from_inside_a_tick_stops_the_frame_without_pausing_midway_through_it() -> void:
	"""The production control path re-entered from a simulation step: tick 2 still completes."""
	_pause_on_tick = 2
	_game.bind_simulation(_on_sim_tick_that_pauses, _on_sim_day_boundary)
	_game.start_game()
	var ran: int = _game.advance_host_time(NINE_TICK_FRAME_USEC)
	assert_equal(ran, 2, "tick 2 committed and tick 3 never started")
	assert_equal(_game.get_completed_tick(), 2, "the committed count agrees")
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "the state followed")


func test_the_overload_rung_is_queued_and_not_applied_inside_the_overloaded_frame() -> void:
	"""Decision 0054's behaviour change, now reached in play: the ladder crosses the barrier.

	At 1x the rung is the CRITICAL diagnostic hold. It is admitted during the overloaded frame and
	is NOT applied inside it; the next frame's opening pump applies it before any tick of that
	frame, so no tick ever runs at the superseded rung either way.
	"""
	_game.start_game()
	var ran: int = _game.advance_host_time(OVERLOAD_FRAME_USEC)
	assert_equal(ran, SimClockScript.MAX_TICKS_PER_FRAME, "the frame drained its eight-tick cap")
	assert_equal(_game.scheduler_events().pending_count(), 1, "the rung is queued, not applied")
	assert_false(_game.is_paused(), "so the overloaded frame itself did not pause the clock")
	assert_equal(_game.clock().diagnostic_pause_count(), 1, "the clock still counted the rung")
	assert_equal(_diagnostics.size(), 1, "and still published it once")


func test_the_queued_overload_rung_lands_before_the_next_frame_runs_a_tick() -> void:
	"""The opening pump is what a fully paused frame still performs; here it is what pauses it."""
	_game.start_game()
	_game.advance_host_time(OVERLOAD_FRAME_USEC)
	var ran: int = _game.advance_host_time(FRAME_USEC)
	assert_equal(ran, 0, "no tick of the next frame ran")
	assert_equal(_game.scheduler_events().pending_count(), 0, "the opening pump drained the rung")
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "CRITICAL now holds")
	assert_equal(_game.clock().owed_ticks(), OVERLOAD_TICKS_LEFT_OWED,
		"and every owed tick is retained: the ladder slows and stops, it never skips")


func test_only_one_overload_rung_is_produced_per_host_frame() -> void:
	"""The contract's at-most-one downgrade per frame; `begin_host_frame()` restores the budget."""
	_game.start_game()
	_game.set_speed(SimClockScript.SPEED_QUADRUPLE)
	_game.advance_host_time(OVERLOAD_FRAME_USEC)
	assert_equal(_game.scheduler_events().pending_count(), 1, "one rung was queued, not several")
	assert_equal(_game.clock().fallback_count(), 1, "and the clock recorded exactly one step")


func test_acknowledging_overload_drains_the_pending_rung_before_clearing_it() -> void:
	"""Otherwise the rung the player just acknowledged would re-pause them one pump later."""
	_game.start_game()
	_game.advance_host_time(OVERLOAD_FRAME_USEC)
	var dropped: int = _game.acknowledge_overload()
	assert_equal(dropped, OVERLOAD_TICKS_LEFT_OWED, "the owed ticks were dropped explicitly")
	assert_equal(_game.scheduler_events().pending_count(), 0, "no rung is left queued")
	assert_false(_game.is_paused(), "the player is out of the diagnostic pause")
	_game.advance_host_time(FRAME_USEC)
	assert_false(_game.is_paused(), "and the next frame does not put them back into it")


func test_acknowledging_overload_is_still_the_only_counted_path_that_drops_owed_ticks() -> void:
	"""Blocker U3's conservative rule survives the wiring: nothing else discards a whole tick."""
	_game.start_game()
	_game.advance_host_time(OVERLOAD_FRAME_USEC)
	_game.advance_host_time(FRAME_USEC)
	assert_equal(_game.clock().acknowledged_catchup_resets(), 0, "no implicit acknowledgement")
	_game.acknowledge_overload()
	assert_equal(_game.clock().acknowledged_catchup_resets(), 1, "the explicit one is counted")
	assert_equal(_game.clock().acknowledged_ticks_discarded(), OVERLOAD_TICKS_LEFT_OWED,
		"with the exact number of ticks it dropped")


func test_a_paused_frame_still_pumps_so_a_queued_resume_never_waits_on_a_tick() -> void:
	"""Point 5/6 of decision 0054: the drain at a repeated boundary is how an unpause arrives."""
	_game.start_game()
	_game.pause_game()
	var pumps_before: int = _game.scheduler_events().pump_count()
	_run_frames(3, FRAME_USEC)
	assert_true(_game.scheduler_events().pump_count() > pumps_before,
		"paused host frames still drained the queue")
	assert_equal(_game.get_completed_tick(), 0, "while running no simulation tick at all")


func _on_sim_tick_that_holds_critical(tick_index: int) -> void:
	"""Stand-in simulation that submits an internal safety hold from inside `_hold_on_tick`."""
	_sim_ticks.append(tick_index)
	if tick_index != _hold_on_tick:
		return
	_game.scheduler_events().submit_safety_hold_into(SimClockScript.CRITICAL, _submit)


func _on_sim_tick_that_pauses(tick_index: int) -> void:
	"""Stand-in simulation that calls the production pause control from inside `_pause_on_tick`."""
	_sim_ticks.append(tick_index)
	if tick_index != _pause_on_tick:
		return
	_game.pause_game()


func _on_sim_tick(tick_index: int) -> void:
	"""Stand-in simulation step: record the tick index the adapter supplied."""
	_sim_ticks.append(tick_index)


func _on_sim_day_boundary(absolute_day: int, season: int) -> bool:
	"""Stand-in simulation day boundary: record the day, the season and the call order."""
	_sim_days.append(absolute_day)
	_sim_seasons.append(season)
	_order.append("simulation")
	return true


func _on_state_changed(new_state: int) -> void:
	"""Record a state transition for assertion."""
	_states.append(new_state)


func _on_speed_changed(speed: int) -> void:
	"""Record a speed change for assertion."""
	_speeds.append(speed)


func _on_day_advanced(absolute_day: int) -> void:
	"""Record a calendar day boundary for assertion."""
	_days.append(absolute_day)
	_order.append("signal")


func _on_clock_diagnostic(message: String) -> void:
	"""Record a scheduler diagnostic for assertion."""
	_diagnostics.append(message)
