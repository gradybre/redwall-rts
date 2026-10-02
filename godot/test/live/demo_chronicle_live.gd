extends SceneTree
## The village chronicle (decision 0631) on the REAL scene with real input: a season run to its end on the one calendar,
## its page written once the farm's record has closed spring 12, the book opened from Village news' "Chronicle" button
## and from the village guide's, paged by its tabs and Earlier, the season under way shown, Esc closing it -- the book a
## modal of the input gate, inside the window, its type at the floors. Not discovered by the runner:
## test/test_demo_chronicle_live.gd runs it in its own process, as the other live harnesses are (decisions 0261, 0391).
##
##     godot --headless --path godot --script res://test/live/demo_chronicle_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## The season's facts are the village's own (its weather, its record) plus three a test cannot wait a season for, written
## where their owners write them: a "Chronicle:" Village line (as the regatta's feast writes it), a bridge built and a
## rescue in the people's ledger (as people_taps.gd records them). Prints `LIVE <name>: PASS|FAIL <detail>` per check
## and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const Text := preload("res://demo/chronicle/chronicle_text.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")

const BOOT_FRAMES: int = 14
const STEP_FRAMES: int = 3
const SEASON_DAYS: int = 12
const GATHERING: String = "Chronicle: the village gathered at the run to race two boats"

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _checks: int = 0
var _failures: int = 0
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == "--size":
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture":
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_steps = [_pause, _the_season_s_facts, _no_page_yet]
	for day: int in SEASON_DAYS:
		_steps.append(_a_day_passes)
	_steps.append_array([_the_next_hour, _the_page_is_written, _n_opens_the_news, _chronicle_from_the_news, _the_book_reads,
		_the_season_under_way, _earlier_page, _esc_closes_it, _o_opens_the_guide, _chronicle_from_the_guide,
		_esc_closes_it])


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last (the root's size held: decision 0261's note)."""
	if root.size != _size:
		root.size = _size
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	step.call()
	_wait = STEP_FRAMES
	return false


# --- helpers ------------------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _key(code: Key) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)


func _click(control: Control) -> void:
	"""A left click at `control`'s centre, through the Viewport."""
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only with --capture, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the read-back's time (docs/ENVIRONMENT.md's stall note)."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _chronicle() -> Node:
	"""The village chronicle."""
	return _village.call(&"chronicle")


func _book() -> CanvasLayer:
	"""The chronicle's book."""
	return _village.call(&"chronicle_window")


func _gate() -> GateScript:
	"""The village's input gate."""
	return _village.call(&"input_gate")


func _screen_rect(control: Control) -> Rect2:
	"""Where `control` is drawn, in window pixels (its frame's scale applied)."""
	var xf: Transform2D = control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


func _book_on_screen(how: String) -> void:
	"""The book is open, the top modal, focus inside it, inside the window, and its shown type at least 14 px drawn."""
	_check("%s: the book is open" % how, bool(_book().call(&"is_open")))
	_check("%s: the book is the top modal" % how, _gate().top_layer() == _book())
	_check("%s: focus inside the book" % how, _gate().in_top_modal(root.gui_get_focus_owner()),
		str(root.gui_get_focus_owner()))
	var frame: Control = _book().call(&"frame")
	var rect: Rect2 = _screen_rect(frame)
	_check("%s: the book fits the window" % how, Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect), str(rect))
	var small: PackedStringArray = PackedStringArray()
	var scale: float = frame.get_global_transform_with_canvas().get_scale().y
	for node: Node in frame.find_children("*", "Control", true, false):
		var control := node as Control
		if (control is Label or control is Button) and control.is_visible_in_tree():
			if control.get_theme_font_size(&"font_size") * scale < 13.99:
				small.append(control.name)
	_check("%s: type at least 14 px drawn" % how, small.is_empty(), ", ".join(small))


# --- the steps ----------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player (the frames are of a still village; the calendar is run on by the farm's own step)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _the_season_s_facts() -> void:
	"""The three facts written where their owners write them (see the header)."""
	var services: Object = _village.get("_services")
	(services.get("notices") as NoticesScript).post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, GATHERING)
	var ledger: Ledger = _village.call(&"people").get("ledger")
	ledger.record(Ledger.KIND_BRIDGE, 8, 100, 0, Ledger.NOBODY, 0, -1, "neck bridge")
	ledger.record(Ledger.KIND_RESCUE, 5, 200, 0, 6)
	_check("the chronicle is built", _chronicle() != null and _book() != null)


func _no_page_yet() -> void:
	"""Spring under way: nothing written."""
	_check("no page before the season ends", int(_chronicle().get("pages_written")) == 0)


func _a_day_passes() -> void:
	"""The calendar run on a day at once by the farm (the kitchen tallies its meals on its next frame)."""
	_village.get("_farm").call(&"advance_calendar", 24 * CalendarScript.HOUR_USEC)


func _the_next_hour() -> void:
	"""One farm hour more, so spring 12 has surely closed (the chronicle reads it on its next frames)."""
	_village.get("_farm").call(&"advance_calendar", CalendarScript.HOUR_USEC)


func _the_page_is_written() -> void:
	"""Spring's page, once, with its Village line."""
	var notices: NoticesScript = _village.get("_services").get("notices")
	_check("spring's page is written", int(_chronicle().get("pages_written")) == 1,
		str(_chronicle().get("pages_written")))
	_check("the page says so in the news", notices.has_text(Text.PAGE_NOTICE % "Spring, year 1"))


func _n_opens_the_news() -> void:
	"""N opens Village news, with its Chronicle button."""
	_key(KEY_N)
	var history: CanvasLayer = _village.call(&"news_history")
	_check("N opens the village news", bool(history.call(&"is_open")))
	var button := history.find_child("Chronicle", true, false) as Button
	_check("the news has a Chronicle button", button != null and button.is_visible_in_tree())


func _chronicle_from_the_news() -> void:
	"""Its Chronicle button closes the news and opens the book on spring's page."""
	var history: CanvasLayer = _village.call(&"news_history")
	_click(history.find_child("Chronicle", true, false) as Button)
	_check("the news closed", not bool(history.call(&"is_open")))
	_check("the book opened on spring's page", int(_book().call(&"page_shown")) == 0)


func _the_book_reads() -> void:
	"""On screen as a modal; the page tells the gathering and the deeds, best first."""
	_book_on_screen("from the news")
	var text: String = _book().call(&"shown_text")
	_check("the page's title", text.begins_with(Text.page_title(0, false)), text.left(60))
	_check("the gathering", text.contains("The village gathered at the run to race two boats."))
	_check("the rescue before the bridge", text.find("Corra Netley brought Tuppen Clayholm ashore") >= 0
		and text.find("Corra Netley brought") < text.find("Elstan Weirholt built the neck bridge"), text)
	_check("spring's weather from the record", text.contains("fine growing weather"), text)
	_capture("chronicle_page")


func _the_season_under_way() -> void:
	"""The season under way's tab: summer, being written."""
	_click(_book().call(&"tab_button", 1))
	var text: String = _book().call(&"shown_text")
	_check("the season under way", text.begins_with(Text.page_title(1, true)), text.left(80))
	_capture("chronicle_draft")


func _earlier_page() -> void:
	"""Earlier goes back to spring."""
	_click(_book().call(&"earlier_button"))
	_check("Earlier shows spring again", int(_book().call(&"page_shown")) == 0)


func _esc_closes_it() -> void:
	"""Esc closes the book."""
	_key(KEY_ESCAPE)
	_check("Esc closes the book", not bool(_book().call(&"is_open")))


func _o_opens_the_guide() -> void:
	"""O opens the village guide, with its Chronicle button."""
	_key(KEY_O)
	var guide: CanvasLayer = _village.call(&"guide").get("window")
	_check("O opens the village guide", guide.visible)
	_check("the guide has a Chronicle button", (guide.call(&"chronicle_button") as Button).is_visible_in_tree())


func _chronicle_from_the_guide() -> void:
	"""Its Chronicle button closes the guide (its pause let go) and opens the book."""
	var guide: CanvasLayer = _village.call(&"guide").get("window")
	_click(guide.call(&"chronicle_button"))
	_check("the guide closed", not guide.visible)
	_check("its pause let go", not bool(guide.call(&"is_holding_pause")))
	_book_on_screen("from the guide")
	_capture("chronicle_from_guide")
