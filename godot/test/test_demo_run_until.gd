extends "res://test/framework/test_case.gd"
## "Run until..." (decision 0471, review UX-022): each target firing at the right game time under the ten-minute day
## (decision 0421: 25 s a game hour at 1x), exactly on the calendar's tick at 1x, 2x and 4x and with ragged frames,
## through the demo clock's frame cap; the event targets (a project, a harvest window, a warning) firing on the frame
## their system reports; and cancellation -- a pause, a critical incident, Stop, a removed project -- through the real
## time control and GameManager script.

const RunScript := preload("res://demo/session/run_until.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ClockScript := preload("res://demo/demo_clock.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const TimeControlScript := preload("res://demo/session/time_control.gd")
const LedgerScript := preload("res://demo/session/pause_ledger.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")

## A 60 Hz frame, and a ragged frame series (seconds), cycled.
const FRAME_S: float = 1.0 / 60.0
const RAGGED_S: Array[float] = [0.0161, 0.0333, 0.0049, 0.0712, 0.0167, 0.0251]
## A day's ticks at most: a run must arrive within this many frames at 60 Hz and 1x (a day is 600 s = 36000 frames).
const MAX_FRAMES: int = 40000

var _calendar: CalendarScript = null
var _run: RunScript = null
var _clock: ClockScript = null
var _game: GameManagerScript = null
var _nodes: Array[Node] = []
var _ripe: int = 0
var _warnings: int = 0
var _project: int = RunScript.PROJECT_UNFINISHED


func before_each() -> void:
	"""A calendar at 06:00 on spring 1 and a run on it, with a demo clock that runs unbound at the speed set."""
	_calendar = CalendarScript.new()
	_run = RunScript.new()
	_run.calendar = _calendar
	_run.ripe_mask = func() -> int: return _ripe
	_run.growing = func() -> bool: return true
	_run.warnings = func() -> int: return _warnings
	_clock = ClockScript.new()
	_ripe = 0
	_warnings = 0
	_project = RunScript.PROJECT_UNFINISHED


func after_each() -> void:
	"""Free any clock or node a test built, and drop the run: its lambdas capture this suite, which holds it (a
	cycle)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _game != null:
		_game.free()
	_game = null
	_run = null


func _frame(real_s: float, speed: int) -> void:
	"""One frame as the village runs it: the run caps the clock, the clock passes its demo time (unbound it runs at
	1x, so `speed` times the real time is handed it), the farm advances the calendar by it (demo_farm.gd)."""
	_clock.limit_usec = _run.usec_limit()
	_clock.advance(real_s * float(speed))
	_calendar.tick += _calendar.ticks_for_usec(_clock.frame_usec)


func _run_frames(speed: int, ragged: bool) -> int:
	"""Frames until the run arrives (or MAX_FRAMES); returns how many."""
	for k: int in MAX_FRAMES:
		_frame(RAGGED_S[k % RAGGED_S.size()] if ragged else FRAME_S, speed)
		if _run.check():
			return k + 1
	return MAX_FRAMES


# --- the calendar targets ------------------------------------------------------------------------------------

func test_next_hour_tick_is_strictly_after_now() -> void:
	"""Dawn from 06:00 (tick 0) is the next day's 06:00, not now; dusk is 20:00 today."""
	assert_equal(RunScript.next_hour_tick(0, NightScript.DAWN_HOUR), SimClock.TICKS_PER_DAY, "dawn: tomorrow")
	assert_equal(RunScript.next_hour_tick(0, NightScript.DUSK_HOUR), 14 * SimClock.TICKS_PER_HOUR, "dusk: 14 h on")
	assert_equal(RunScript.next_hour_tick(14 * SimClock.TICKS_PER_HOUR - 1, NightScript.DUSK_HOUR),
		14 * SimClock.TICKS_PER_HOUR, "a tick before dusk: dusk")
	assert_equal(RunScript.next_hour_tick(14 * SimClock.TICKS_PER_HOUR, NightScript.DUSK_HOUR),
		14 * SimClock.TICKS_PER_HOUR + SimClock.TICKS_PER_DAY, "at dusk: tomorrow's")


func test_the_next_meal_is_the_kitchens_next_call() -> void:
	"""From 06:00 breakfast's call at 07:00; from 07:00 supper's at 17:00; from 17:00 tomorrow's breakfast."""
	var breakfast: int = (MealRules.CALL_HOUR[MealRules.MEAL_BREAKFAST] - 6) * SimClock.TICKS_PER_HOUR
	var supper: int = (MealRules.CALL_HOUR[MealRules.MEAL_SUPPER] - 6) * SimClock.TICKS_PER_HOUR
	assert_equal(RunScript.next_meal_tick(0), breakfast, "breakfast")
	assert_equal(RunScript.next_meal_tick(breakfast), supper, "supper")
	assert_equal(RunScript.next_meal_tick(supper), breakfast + SimClock.TICKS_PER_DAY, "tomorrow's breakfast")


func test_usec_to_tick_lands_on_the_tick_exactly() -> void:
	"""The cap is the fewest microseconds that bring the calendar to the tick, whatever its carried remainder."""
	var twin := CalendarScript.new()
	assert_equal(_calendar.ticks_for_usec(12345), 0, "a part tick carried")
	twin.ticks_for_usec(12345)
	var usec: int = RunScript.usec_to_tick(_calendar, 37)
	assert_equal(_calendar.ticks_for_usec(usec), 37, "exactly enough reaches it")
	assert_equal(twin.ticks_for_usec(usec - 1), 36, "one microsecond fewer falls a tick short")
	assert_equal(RunScript.usec_to_tick(_calendar, 0), 0, "there already: nothing")


func test_dawn_fires_at_six_exactly_at_one_two_and_four_x() -> void:
	"""Under the ten-minute day, a run until dawn stops with the calendar on 06:00:00 the next day, at every speed."""
	for speed: int in [1, 2, 4]:
		before_each()
		assert_true(_run.start(RunScript.TARGET_DAWN), "started at %dx" % speed)
		var frames: int = _run_frames(speed, false)
		assert_true(frames < MAX_FRAMES, "%dx: arrived" % speed)
		assert_equal(_calendar.tick, SimClock.TICKS_PER_DAY, "%dx: on tomorrow's 06:00 to the tick" % speed)
		var at := SimClock.Calendar.new(_calendar.tick)
		assert_equal([at.hour, at.minute, at.season_day], [6, 0, 2], "%dx: 06:00 on spring 2" % speed)
		assert_equal(_run.ended, RunScript.END_REACHED, "%dx: reached" % speed)
		assert_equal(_run.end_text, "Reached dawn: Y1 Spring 2, 06:00", "%dx: its words" % speed)


func test_dawn_takes_ten_real_minutes_at_one_x() -> void:
	"""A whole game day at 1x is 600 real seconds: 36000 frames of a 60th of a second (the last one capped)."""
	_run.start(RunScript.TARGET_DAWN)
	var frames: int = _run_frames(1, false)
	assert_true(frames >= 35999 and frames <= 36001, "about 36000 frames: %d" % frames)


func test_dusk_fires_at_twenty_exactly_with_ragged_frames() -> void:
	"""Ragged frames at 4x still land on 20:00 to the tick."""
	_run.start(RunScript.TARGET_DUSK)
	_run_frames(4, true)
	assert_equal(_calendar.tick, 14 * SimClock.TICKS_PER_HOUR, "20:00 to the tick")
	assert_equal(SimClock.Calendar.new(_calendar.tick).hour, NightScript.DUSK_HOUR, "dusk's hour")


func test_the_next_meal_fires_at_the_call() -> void:
	"""From 08:30, the next meal is supper's call, 17:00."""
	@warning_ignore("integer_division") _calendar.tick = 2 * SimClock.TICKS_PER_HOUR + SimClock.TICKS_PER_HOUR / 2
	_run.start(RunScript.TARGET_MEAL)
	_run_frames(2, true)
	var at := SimClock.Calendar.new(_calendar.tick)
	assert_equal([at.hour, at.minute], [MealRules.CALL_HOUR[MealRules.MEAL_SUPPER], 0], "17:00")
	assert_true(_run.end_text.begins_with("Reached the next meal"), _run.end_text)


func test_without_the_cap_a_frame_would_overshoot() -> void:
	"""The cap is what makes it exact: an uncapped 4x frame crossing dusk passes it (mutation guard)."""
	_calendar.tick = 14 * SimClock.TICKS_PER_HOUR - 1
	_run.start(RunScript.TARGET_DUSK)
	_calendar.tick += _calendar.ticks_for_usec(roundi(0.0712 * 1000000.0) * 4)
	assert_true(_calendar.tick > 14 * SimClock.TICKS_PER_HOUR, "uncapped: past 20:00")
	_calendar = CalendarScript.new()
	_calendar.tick = 14 * SimClock.TICKS_PER_HOUR - 1
	_run.calendar = _calendar
	_run.start(RunScript.TARGET_DUSK)
	_frame(0.0712, 4)
	assert_equal(_calendar.tick, 14 * SimClock.TICKS_PER_HOUR, "capped: on 20:00")
	assert_true(_run.check(), "and it fires")


func test_the_clock_cap_limits_a_frame_and_minus_one_does_not() -> void:
	"""demo_clock.gd `limit_usec`: a frame passes at most the cap; -1 caps nothing."""
	_clock.limit_usec = 1000
	_clock.advance(0.5)
	assert_equal(_clock.frame_usec, 1000, "capped")
	_clock.limit_usec = -1
	_clock.advance(0.5)
	assert_equal(_clock.frame_usec, 500000, "uncapped")


func test_an_event_target_has_no_cap() -> void:
	"""A project, a harvest or a warning has no tick known ahead: no cap."""
	_run.set_project("Tunnel 1", func() -> int: return _project)
	_run.start(RunScript.TARGET_PROJECT)
	assert_equal(_run.usec_limit(), -1, "no cap")


# --- the event targets ------------------------------------------------------------------------------------------

func test_a_project_fires_when_its_watch_says_done() -> void:
	"""Until the selected tunnel is dug: nothing while unfinished, REACHED the frame it is done."""
	_run.set_project("Tunnel 3", func() -> int: return _project)
	assert_true(_run.start(RunScript.TARGET_PROJECT), "started")
	assert_false(_run.check(), "unfinished")
	_project = RunScript.PROJECT_DONE
	assert_true(_run.check(), "done: arrived")
	assert_true(_run.end_text.begins_with("Reached Tunnel 3 is done"), _run.end_text)


func test_a_removed_project_cancels_the_run() -> void:
	"""A project gone before it is done ends the run GONE, not reached."""
	_run.set_project("Tunnel 3", func() -> int: return _project)
	_run.start(RunScript.TARGET_PROJECT)
	_project = RunScript.PROJECT_GONE
	assert_false(_run.check(), "no arrival")
	assert_false(_run.is_running(), "ended")
	assert_equal(_run.ended, RunScript.END_GONE, "gone")


func test_no_project_selected_refuses() -> void:
	"""With nothing selected (or a finished one) the project target is refused, saying why."""
	assert_equal(_run.refusal(RunScript.TARGET_PROJECT), RunScript.NO_PROJECT, "none selected")
	assert_false(_run.start(RunScript.TARGET_PROJECT), "refused")
	_run.set_project("Tunnel 1", func() -> int: return RunScript.PROJECT_DONE)
	assert_equal(_run.refusal(RunScript.TARGET_PROJECT), RunScript.NO_PROJECT, "already done: refused")


func test_a_harvest_window_fires_on_a_bed_newly_ripe() -> void:
	"""A bed ripe already does not fire it; another coming ripe does."""
	_ripe = 0b1
	_run.start(RunScript.TARGET_HARVEST)
	assert_false(_run.check(), "bed 1 was ripe already")
	_ripe = 0b0
	assert_false(_run.check(), "bed 1 harvested")
	_ripe = 0b100
	assert_true(_run.check(), "bed 3 ripe: the next window")


func test_nothing_growing_refuses_the_harvest() -> void:
	"""No bed growing toward a harvest: refused, saying so."""
	_run.growing = func() -> bool: return false
	assert_equal(_run.refusal(RunScript.TARGET_HARVEST), RunScript.NOTHING_GROWING, "nothing growing")


func test_the_next_warning_fires_on_a_new_one() -> void:
	"""Warnings already said do not fire it; the next one does."""
	_warnings = 4
	_run.start(RunScript.TARGET_WARNING)
	assert_false(_run.check(), "nothing new")
	_warnings = 5
	assert_true(_run.check(), "a new warning")


# --- cancellation, through the time control --------------------------------------------------------------------

func _control() -> TimeControlScript:
	"""A time control on a started GameManager at 2x, its run on this calendar and clock."""
	_game = GameManagerScript.new()
	_game.start_game()
	_game.set_speed(2)
	var control := TimeControlScript.new()
	_nodes.append(control)
	var notices := NoticesScript.new()
	var incidents := IncidentsScript.new()
	incidents.bind(notices, null, null)
	control.configure(_game, _clock, notices, incidents)
	control.run.calendar = _calendar
	control.set_meta(&"notices", notices)
	control.set_meta(&"incidents", incidents)
	return control


func test_a_pause_cancels_the_run_and_says_so() -> void:
	"""The player pauses before dawn: the run is cancelled, saying it was paused, and the cap is lifted."""
	var control := _control()
	assert_true(control.start_run(RunScript.TARGET_DAWN), "started")
	control._process(0.0)
	assert_true(_clock.limit_usec >= 0, "capped while running")
	control.ledger.pause_player()
	control._process(0.0)
	assert_false(control.run.is_running(), "cancelled")
	assert_equal(control.run.ended, RunScript.END_PAUSED, "by a pause")
	assert_equal(control.run_note(), "Run until dawn cancelled: paused (you paused)", "the card's line")
	assert_equal(_clock.limit_usec, -1, "no cap")


func test_arrival_pauses_as_the_player_with_the_arrival() -> void:
	"""The calendar reaches dawn: the time control pauses (PLAYER) with the arrival as the reason."""
	var control := _control()
	control.start_run(RunScript.TARGET_DAWN)
	_calendar.tick = SimClock.TICKS_PER_DAY
	control._process(0.0)
	assert_equal(_game.get_pause_reason_names(), ["PLAYER"] as Array[String], "paused as the player")
	assert_equal(control.ledger.player_note(), "Reached dawn: Y1 Spring 2, 06:00", "saying where")
	assert_equal(control.run_note(), "", "no cancel line on an arrival")


func test_a_critical_incident_cancels_a_run_even_with_auto_pause_off() -> void:
	"""A critical incident ends a run to dawn; with its auto-pause off the village runs on."""
	var control := _control()
	control.ledger.auto_critical = false
	control.start_run(RunScript.TARGET_DAWN)
	var incidents: IncidentsScript = control.get_meta(&"incidents")
	incidents.raise("water:rescue:1", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "Mouse keeper is in difficulty")
	assert_equal(control.run.ended, RunScript.END_CRITICAL, "cancelled by the critical incident")
	assert_true(control.run.end_text.contains("Mouse keeper is in difficulty"), control.run.end_text)
	assert_false(_game.is_paused(), "auto-pause off: still running")


func test_a_run_to_the_next_warning_takes_a_critical_incident_as_its_arrival() -> void:
	"""Waiting for exactly that: the incident is the arrival, not a cancellation."""
	var control := _control()
	control.start_run(RunScript.TARGET_WARNING)
	var incidents: IncidentsScript = control.get_meta(&"incidents")
	incidents.raise("water:rescue:1", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL, "Mouse keeper is in difficulty")
	control._process(0.0)
	assert_equal(control.run.ended, RunScript.END_REACHED, "reached")


func test_a_warning_line_in_the_feed_is_the_next_warning() -> void:
	"""A new warning row in the notice feed counts; a note does not."""
	var control := _control()
	control.start_run(RunScript.TARGET_WARNING)
	var notices: NoticesScript = control.get_meta(&"notices")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "The beans are up")
	control._process(0.0)
	assert_true(control.run.is_running(), "a note: still running")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight")
	control._process(0.0)
	assert_equal(control.run.ended, RunScript.END_REACHED, "a warning: arrived")


func test_stop_cancels_the_run() -> void:
	"""The player's Stop."""
	var control := _control()
	control.start_run(RunScript.TARGET_DUSK)
	control.stop_run()
	assert_equal(control.run.ended, RunScript.END_STOPPED, "stopped")
	assert_equal(_clock.limit_usec, -1, "no cap")


func test_starting_while_paused_resumes_first_and_the_menu_refuses() -> void:
	"""Paused by the player: starting resumes; with the game menu's pause the run is refused, saying why."""
	var control := _control()
	control.ledger.pause_player()
	assert_true(control.start_run(RunScript.TARGET_DUSK), "resumed and started")
	assert_false(_game.is_paused(), "running")
	control.stop_run()
	control.ledger.hold_menu(true)
	assert_false(control.start_run(RunScript.TARGET_DUSK), "refused under the menu")
	assert_equal(control.run.end_text, "Cannot run: " + LedgerScript.RESUME_MENU, "saying why")


func test_the_preview_says_when_and_how_long() -> void:
	"""A calendar target's menu line: its hour, the game time to it and the real time at the speed."""
	assert_equal(_run.preview(RunScript.TARGET_DUSK, 4), "Dusk: 20:00, in 14 h 0 min (about 1 min 27 s at 4x)",
		"14 game hours at 4x: 87.5 real seconds")
	assert_equal(_run.preview(RunScript.TARGET_PROJECT, 1), "Project done: " + RunScript.NO_PROJECT, "a refusal")


func test_a_removed_project_pauses_the_village_saying_so() -> void:
	"""Review H2: the run's project gone, the village is not left running at the run's speed: paused, with why."""
	var control := _control()
	control.run.set_project("Tunnel 3", func() -> int: return _project)
	assert_true(control.start_run(RunScript.TARGET_PROJECT), "started")
	_project = RunScript.PROJECT_GONE
	control._process(0.0)
	assert_equal(control.run.ended, RunScript.END_GONE, "ended: gone")
	assert_true(_game.is_paused(), "paused")
	assert_equal(control.ledger.player_note(), "Run until Tunnel 3 is done cancelled: the project was removed", "saying so")


func test_an_unavailable_target_changes_nothing() -> void:
	"""Review M2: refused before Resume -- the player's pause stays."""
	var control := _control()
	control.ledger.pause_player()
	assert_false(control.start_run(RunScript.TARGET_PROJECT), "no project: refused")
	assert_true(_game.is_paused(), "still paused")


func test_a_warning_posted_before_the_start_is_in_the_baseline() -> void:
	"""Review M4: a warning said before G (and before the frame counted it) does not end the run at once."""
	var control := _control()
	var notices: NoticesScript = control.get_meta(&"notices")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight")
	control.start_run(RunScript.TARGET_WARNING)
	control._process(0.0)
	assert_true(control.run.is_running(), "still waiting for the next one")


func test_a_bed_harvested_and_ripe_again_is_a_new_window() -> void:
	"""The ripe memory follows the beds: bed 1 ripe at the start, harvested, then ripe again, fires."""
	_ripe = 0b1
	_run.start(RunScript.TARGET_HARVEST)
	_ripe = 0b0
	assert_false(_run.check(), "harvested")
	_ripe = 0b1
	assert_true(_run.check(), "ripe again: a new window")


func test_a_merged_repeat_is_not_a_new_incident() -> void:
	"""The incidents count a new or recurring incident once; the same one said again does not count."""
	var incidents := IncidentsScript.new()
	incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 1 is waterlogged")
	incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 1 is waterlogged")
	assert_equal(incidents.occurrences, 1, "one")
	incidents.resolve("farm:wet:1")
	incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 1 is waterlogged")
	assert_equal(incidents.occurrences, 2, "a recurrence counts")
