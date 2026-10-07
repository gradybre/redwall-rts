extends "res://test/framework/test_case.gd"
## The time controls' speed keys and the season skip in the speed area (decision 1653; feature #59, TIME): F1/F2/F3
## request 1x/2x/4x through GameManager without clearing a pause; "Skip to next season" in the "Run until…" menu says
## where it lands, asks first, does nothing on Cancel, calls the host's skip once on Skip and closes, and is not offered
## while a run is under way. Off-tree; no staged assets.

const TimeControlScript := preload("res://demo/session/time_control.gd")
const RunScript := preload("res://demo/session/run_until.gd")
const RunMenuScript := preload("res://demo/ui/demo_run_menu.gd")
const SkipScript := preload("res://demo/winter/season_skip.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ClockScript := preload("res://demo/demo_clock.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

var _nodes: Array[Node] = []
var _game: GameManagerScript = null
var _skips: Array[int] = []


func after_each() -> void:
	"""Free what a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _game != null:
		_game.free()
	_game = null
	_skips.clear()


func _control() -> TimeControlScript:
	"""A time control on a started GameManager at 1x."""
	_game = GameManagerScript.new()
	_game.start_game()
	var control := TimeControlScript.new()
	_nodes.append(control)
	var notices := NoticesScript.new()
	var incidents := IncidentsScript.new()
	incidents.bind(notices, null, null)
	control.configure(_game, ClockScript.new(), notices, incidents)
	control.run.calendar = CalendarScript.new()
	return control


static func _key(code: Key, shift: bool = false) -> InputEventKey:
	"""A key press."""
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	key.shift_pressed = shift
	return key


static func _ctrl_key(code: Key) -> InputEventKey:
	"""A key press with Ctrl held."""
	var key: InputEventKey = _key(code)
	key.ctrl_pressed = true
	return key


func _skip() -> int:
	"""The host's skip, counted."""
	_skips.append(1)
	return 24


func _menu(calendar: CalendarScript, run: RunScript) -> RunMenuScript:
	"""A run menu over `run` with this suite's skip and `calendar` bound."""
	var menu := RunMenuScript.new()
	_nodes.append(menu)
	_nodes.append(menu.button_layer())
	menu.configure(run, Callable(), Callable())
	menu.on_skip = _skip
	menu.calendar = calendar
	return menu


# --- the speed keys ----------------------------------------------------------------------------------------------------

func test_the_speed_keys_are_the_input_tables() -> void:
	"""F1, F2, F3 request 1, 2, 4 (UI §5); no other key requests a speed, and there is no 3x."""
	assert_equal([TimeControlScript.speed_of(_key(KEY_F1)), TimeControlScript.speed_of(_key(KEY_F2)),
		TimeControlScript.speed_of(_key(KEY_F3))], [1, 2, 4], "F1 F2 F3")
	for code: Key in [KEY_F4, KEY_F7, KEY_F8, KEY_SPACE, KEY_G, KEY_1]:
		assert_equal(TimeControlScript.speed_of(_key(code)), 0, "key %d requests no speed" % code)
	assert_false(TimeControlScript.SPEED_VALUES.has(3), "no 3x")
	assert_equal([TimeControlScript.speed_of(_key(KEY_F3, true)), TimeControlScript.speed_of(_ctrl_key(KEY_F1))], [0, 0],
		"exactly the key: Shift+F3 and Ctrl+F1 request nothing")


func test_the_speed_keys_do_nothing_while_typing() -> void:
	"""A pop-up's text field takes every key but Enter, so an F-key reaches the time controls: in a text field it does
	nothing (review M1); on a button or with no focus it works."""
	var field := LineEdit.new()
	var editor := TextEdit.new()
	var button := Button.new()
	_nodes.append_array([field, editor, button])
	assert_true(TimeControlScript.is_typing(field) and TimeControlScript.is_typing(editor), "text fields")
	assert_false(TimeControlScript.is_typing(button) or TimeControlScript.is_typing(null), "a button, or no focus")
	var control: TimeControlScript = _control()
	assert_false(control.take_key(_key(KEY_F3), field), "F3 in a text field: not taken")
	assert_equal(_game.get_speed(), 1, "the speed unchanged")
	assert_true(control.take_key(_key(KEY_F3), button), "F3 on a button: taken")
	assert_equal(_game.get_speed(), 4, "4x")


func test_f3_and_f1_set_the_requested_speed_through_the_game() -> void:
	"""F3 then F1: the game's requested speed follows, the keys taken."""
	var control: TimeControlScript = _control()
	assert_true(control.handle_key(_key(KEY_F3)), "F3 taken")
	assert_equal([_game.get_speed(), _game.get_effective_speed()], [4, 4], "4x")
	assert_true(control.handle_key(_key(KEY_F2)), "F2 taken")
	assert_equal(_game.get_speed(), 2, "2x")
	control.handle_key(_key(KEY_F1))
	assert_equal(_game.get_speed(), 1, "1x")


func test_a_speed_key_while_paused_does_not_resume() -> void:
	"""UI-SET-015-017: setting a speed does not clear a pause reason -- paused, F2 sets 2x and the village stays
	paused; Resume then runs it at 2x."""
	var control: TimeControlScript = _control()
	control.ledger.pause_player()
	control.handle_key(_key(KEY_F2))
	assert_true(_game.is_paused(), "still paused")
	assert_equal(_game.get_speed(), 2, "2x requested")
	control.resume()
	assert_equal(_game.get_effective_speed(), 2, "resumed at 2x")


func test_a_released_or_repeated_key_is_not_taken() -> void:
	"""Only a fresh press is taken: a speed request, or G."""
	var control: TimeControlScript = _control()
	var up: InputEventKey = _key(KEY_F3)
	up.pressed = false
	assert_false(control.handle_key(up), "a release")
	var echo: InputEventKey = _key(KEY_F3)
	echo.echo = true
	assert_false(control.handle_key(echo), "a repeat")
	assert_equal(_game.get_speed(), 1, "unchanged")
	control.run_menu = _menu(CalendarScript.new(), control.run)
	var held_g: InputEventKey = _key(KEY_G)
	held_g.echo = true
	assert_false(control.handle_key(held_g), "G held down: a repeat")
	assert_false(control.run_menu.is_open(), "the menu not toggled by a repeat")
	assert_true(control.handle_key(_key(KEY_G)) and control.run_menu.is_open(), "a fresh G opens it")


# --- the season skip in the speed area ---------------------------------------------------------------------------------

func test_the_skip_says_where_it_lands() -> void:
	"""From spring 1 it lands on summer 1, 06:00; from the last hour of winter on spring 1 of the next year."""
	var calendar := CalendarScript.new()
	assert_equal(SkipScript.target_words(calendar), "Y1 Summer 1, 06:00", "spring to summer")
	calendar.tick = SkipScript.tick_of_hour(SimClock.DAYS_PER_YEAR * SimClock.HOURS_PER_DAY - 1)
	assert_equal(SkipScript.target_words(calendar), "Y2 Spring 1, 06:00", "winter to the next spring")


func test_the_skip_asks_first_and_cancel_does_nothing() -> void:
	"""The skip's line names the landing and says in its tooltip what is not lived; a click asks; Cancel: no skip, the
	question gone, the menu still open."""
	var menu: RunMenuScript = _menu(CalendarScript.new(), RunScript.new())
	menu.open()
	assert_true(menu.skip_button().visible and not menu.skip_button().disabled, "offered")
	assert_equal(menu.skip_button().text, RunMenuScript.SKIP_TEXT, "its words")
	var tip: String = menu.skip_button().tooltip_text
	assert_true(tip.begins_with("Lands on Y1 Summer 1, 06:00") and tip.contains("not lived"), tip)
	assert_false(menu.skip_asked(), "not asked yet")
	menu.skip_button().pressed.emit()
	assert_true(menu.skip_asked(), "asked")
	assert_true(menu.skip_question().begins_with("Skip to Y1 Summer 1, 06:00?"), menu.skip_question())
	assert_false(menu.target_button(RunScript.TARGET_DAWN).visible, "the question takes the targets' place")
	assert_true(menu.skip_button().disabled, "the line waits on the answer")
	menu.skip_no_button().pressed.emit()
	assert_equal(_skips.size(), 0, "no skip")
	assert_false(menu.skip_asked(), "the question gone")
	assert_true(menu.target_button(RunScript.TARGET_DAWN).visible, "the targets back")
	assert_true(menu.is_open(), "the menu still open")


func test_a_landing_that_moved_on_asks_again() -> void:
	"""Asked on the last hour of spring, answered after the season turned (review M2): nothing is skipped and the
	question names the new landing; answered again, it skips."""
	var calendar := CalendarScript.new()
	calendar.tick = SkipScript.tick_of_hour(SimClock.DAYS_PER_SEASON * SimClock.HOURS_PER_DAY - 1)
	var menu: RunMenuScript = _menu(calendar, RunScript.new())
	menu.open()
	menu.arm_skip()
	assert_true(menu.skip_question().begins_with("Skip to Y1 Summer 1"), menu.skip_question())
	calendar.tick += SimClock.TICKS_PER_HOUR
	menu.confirm_skip()
	assert_equal(_skips.size(), 0, "nothing skipped")
	assert_true(menu.skip_asked() and menu.skip_question().begins_with("Skip to Y1 Autumn 1"), menu.skip_question())
	menu.confirm_skip()
	assert_equal(_skips.size(), 1, "skipped once the question was current")


func test_skip_confirmed_calls_the_hosts_skip_once_and_closes() -> void:
	"""Skip: the host's skip (the Lab's own), once, and the menu closed; a second Skip without asking does nothing;
	reopened, the question starts unasked."""
	var menu: RunMenuScript = _menu(CalendarScript.new(), RunScript.new())
	menu.open()
	menu.skip_button().pressed.emit()
	menu.skip_yes_button().pressed.emit()
	assert_equal(_skips.size(), 1, "skipped once")
	assert_false(menu.is_open(), "closed")
	menu.confirm_skip()
	assert_equal(_skips.size(), 1, "not again without asking")
	menu.arm_skip()
	menu.close()
	menu.open()
	assert_false(menu.skip_asked(), "reopened unasked")


func test_the_skip_waits_while_a_run_is_under_way_and_needs_a_host() -> void:
	"""A run under way: the skip is disabled, saying to stop the run first, and cannot be asked; with no host or no
	calendar it is not offered."""
	var calendar := CalendarScript.new()
	var run := RunScript.new()
	run.calendar = calendar
	assert_true(run.start(RunScript.TARGET_DUSK), "a run under way")
	var menu: RunMenuScript = _menu(calendar, run)
	menu.open()
	assert_true(menu.skip_button().disabled, "disabled")
	assert_equal(menu.skip_button().tooltip_text, RunMenuScript.SKIP_RUNNING, "saying why")
	run.cancel(RunScript.END_STOPPED, "stopped")
	menu.refresh()
	menu.arm_skip()
	assert_true(run.start(RunScript.TARGET_DUSK) and menu.skip_asked(), "a run started under a standing question")
	menu.confirm_skip()
	assert_equal(_skips.size(), 0, "Skip refused while the run is under way")
	menu.arm_skip()
	assert_false(menu.skip_asked(), "not asked while running")
	var bare: RunMenuScript = _menu(null, RunScript.new())
	bare.open()
	assert_false(bare.skip_button().visible, "no calendar: not offered")
	bare.calendar = calendar
	bare.on_skip = Callable()
	bare.refresh()
	assert_false(bare.skip_button().visible, "no host: not offered")
