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

## 40000 us is 1/25 of a real second. 25 such frames are exactly one real second, and at every
## selectable speed a frame stays under the clock's 8-tick drain cap, so no frame is clipped.
const FRAME_USEC: int = 40000
const FRAMES_PER_REAL_SECOND: int = 25
## 100000 us at 2x is exactly 6 ticks with no remainder: the cheapest way to reach a boundary.
const SIX_TICK_FRAME_USEC: int = 100000

var _game: GameManagerScript = null
var _states: Array[int] = []
var _speeds: Array[int] = []
var _days: Array[int] = []
var _diagnostics: Array[String] = []


func before_each() -> void:
	"""Build a fresh game manager outside the scene tree and record its UI signals."""
	_game = GameManagerScript.new()
	_states = []
	_speeds = []
	_days = []
	_diagnostics = []
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


func _on_state_changed(new_state: int) -> void:
	"""Record a state transition for assertion."""
	_states.append(new_state)


func _on_speed_changed(speed: int) -> void:
	"""Record a speed change for assertion."""
	_speeds.append(speed)


func _on_day_advanced(absolute_day: int) -> void:
	"""Record a calendar day boundary for assertion."""
	_days.append(absolute_day)


func _on_clock_diagnostic(message: String) -> void:
	"""Record a scheduler diagnostic for assertion."""
	_diagnostics.append(message)
