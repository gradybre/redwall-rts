extends SceneTree
## The better notices (decision 0591, feature #39) on the REAL scene with REAL Viewport input. Not discovered by the
## runner: test/test_demo_notices_live.gd runs it in its own process, as the input and people harnesses are (decisions
## 0261, 0491), because only an in-tree scene lays its Controls out and takes Viewport input.
##
##     godot --headless --path godot --script res://test/live/demo_notices_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Paused as the player pauses (the news clock stands still, so nothing ages between steps), it posts a flood of reports
## (past the info budget), an info note, crows at a bed three times with news between, and an urgent notice; then checks
## the strip draws the urgent line in its weight (and the grouped crows where two lines fit), counts what it held back,
## keeps to its band clear of the Map layer picker; that a click on the urgent line's × dismisses it and a click on the
## crows' Go to then selects the bed; N opens the village news, a click on its Urgent filter shows the urgent alone, a
## click on Snooze quiets the crows and names them. Prints `LIVE <name>: PASS|FAIL <detail>` per check and
## `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const NoticesScript := preload("res://demo/demo_notices.gd")
const StripScript := preload("res://demo/ui/demo_news_strip.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const CROWS: StringName = &"crows"
const BED: int = 2
const FLOOD: int = 8

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and run the checks."""
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
	_run.call_deferred()


func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	_out_of_the_way()
	await _frames(SETTLE_FRAMES)
	_post_the_news()
	await _frames(SETTLE_FRAMES)
	await _the_strip()
	await _go_to_and_dismiss()
	await _the_history()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _out_of_the_way() -> void:
	"""Hide the pause card for this harness. It is drawn far taller than its one row (over the top centre and the
	village news, as on another review branch's frames), and its frame takes the mouse, so it ate
	the clicks this harness makes on the news. Reported separately; this harness is about the news, not the card."""
	var card: CanvasLayer = _village.call(&"pause_card")
	(card.get(&"hide_while") as Array).append(func() -> bool: return true)
	card.call(&"refresh")


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _feed() -> NoticesScript:
	"""The village's one notice feed."""
	return _village.get("_services").get("notices") as NoticesScript


func _strip() -> StripScript:
	"""The news strip."""
	return _village.get("_news") as StripScript


func _history() -> CanvasLayer:
	"""The village news window."""
	return _village.get("_history") as CanvasLayer


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


func _key(code: Key) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)


func _floors(what: String, layer: Node, wide: bool = false) -> void:
	"""Every shown label with text at least 14 px; every shown button with text at least 14 px and 32 px tall, and one
	with text or an icon at least 32 px wide too where `wide` (UI §2.1's 32×32 hitbox: the strip's × and Go to)."""
	var bad := PackedStringArray()
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		var worded: bool = not String(control.get(&"text")).is_empty()
		if wide and control is Button and (control as Button).icon != null and control.size.x < 32.0 - 0.01:
			bad.append("%s %.0f wide" % [control.name, control.size.x])
		if not worded:
			continue
		if control.get_theme_font_size(&"font_size") < 14 or (control is Button and control.size.y < 32.0 - 0.01):
			bad.append("%s %dpx %.0f" % [control.name, control.get_theme_font_size(&"font_size"), control.size.y])
		elif wide and control is Button and control.size.x < 32.0 - 0.01:
			bad.append("%s %.0f wide" % [control.name, control.size.x])
	_check("%s: text 14 px, buttons 32 px" % what, bad.is_empty(), ", ".join(bad))


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _slot_of(words: String) -> int:
	"""The strip line whose text contains `words` (-1: none shown)."""
	for slot: int in StripScript.LINES:
		if _strip().line_text(slot).contains(words):
			return slot
	return -1


# --- the steps ----------------------------------------------------------------------------------------

func _post_the_news() -> void:
	"""A flood of reports first (held back past the budget), an info note, crows at a bed, an urgent notice, news, and
	the crows twice more: the crows grouped are the newest line, the urgent one under them."""
	var feed := _feed()
	for k: int in FLOOD:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Crew report %d" % k)
	feed.notify(NoticesScript.SOURCE_VILLAGE, NoticesScript.TIER_INFO, &"chilled", "Bramble came in chilled")
	feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, "Crows at the barley", "", "",
		NoticesScript.TARGET_BED, BED)
	feed.notify(NoticesScript.SOURCE_EVENTS, NoticesScript.TIER_URGENT, &"fox", "A fox at the hen run — call the guard")
	feed.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, "The wind is getting up")
	for k: int in 2:
		feed.notify(NoticesScript.SOURCE_FARM, NoticesScript.TIER_NORMAL, CROWS, "Crows at the barley", "", "",
			NoticesScript.TARGET_BED, BED)


func _the_strip() -> void:
	"""The strip shows the urgent notice in its weight (kept first when the band holds few lines), the crows grouped ×3
	with Go to when there is room for them, counts what it held back, and keeps to its band."""
	var strip := _strip()
	strip.call(&"refresh", _feed().now_msec())
	await _frames(SETTLE_FRAMES)
	_check("the strip shows", strip.is_shown())
	var urgent: int = _slot_of("Urgent: A fox")
	_check("the urgent notice shows, worded", urgent >= 0, strip.line_text(0))
	_check("drawn urgent", urgent >= 0 and strip.line_tier(urgent) == NoticesScript.TIER_URGENT)
	var crows: int = _slot_of("Crows at the barley")
	_check("the crows grouped, newest, where two lines fit", (crows == 0 and strip.line_text(0).ends_with("(×3)"))
		or (crows < 0 and strip.lines_fitting() < 2), "%s; %d lines" % [strip.line_text(0), strip.lines_fitting()])
	_check("held back counted in the title", strip.held_shown() > 0 and _title().ends_with("more (N)"), _title())
	var rect: Rect2 = strip.frame_rect()
	_check("the strip inside the window", Rect2(Vector2.ZERO, Vector2(_size)).encloses(rect), str(rect))
	var picker: Rect2 = (_village.get("_lens_picker").get("_frame") as Control).get_global_rect()
	_check("the strip keeps to its band, clear of the Map layer picker", not rect.intersects(picker),
		"%s / %s, %d lines" % [rect, picker, strip.lines_fitting()])
	var frame: Control = strip.get("_frame")
	_check("no empty room under the lines (measured at the width drawn)", absf(frame.size.y
		- frame.get_combined_minimum_size().y) < 1.0, "%s / %s" % [frame.size, frame.get_combined_minimum_size()])
	_floors("the strip", strip, true)
	await _capture("notices_strip")


func _title() -> String:
	"""The strip's title line."""
	return (_strip().get("_title") as Label).text


func _go_to_and_dismiss() -> void:
	"""A click on the urgent line's × takes it off the strip, kept and dismissed; then a click on the crows' Go to
	selects bed BED and centres it."""
	var strip := _strip()
	var urgent: int = _slot_of("Urgent: A fox")
	if urgent < 0:
		return
	_click(strip.line_button(urgent, true))
	await _frames(SETTLE_FRAMES)
	_check("a click on × takes it off the strip", _slot_of("Urgent: A fox") < 0)
	var feed := _feed()
	var dismissed: bool = false
	for k: int in feed.count():
		dismissed = dismissed or (feed.text(k).begins_with("A fox") and feed.is_dismissed(k))
	_check("and keeps it, dismissed", dismissed)
	strip.call(&"refresh", feed.now_msec())
	await _frames(SETTLE_FRAMES)
	var crows: int = _slot_of("Crows at the barley")
	_check("the crows show now, with Go to", crows >= 0 and strip.line_can_go(crows), strip.line_text(0))
	await _capture("notices_after_dismiss")
	if crows < 0:
		return
	var jump: RefCounted = _village.get("_jump")
	var jumps: int = int(jump.get("jumps"))
	_click(strip.line_button(crows, false))
	await _frames(SETTLE_FRAMES)
	_check("a click on Go to jumps", int(jump.get("jumps")) == jumps + 1, "%d" % int(jump.get("jumps")))
	_check("and selects the bed", int(_village.get("_farm").get("selected_bed")) == BED,
		"%d" % int(_village.get("_farm").get("selected_bed")))


func _the_history() -> void:
	"""N opens the village news; its Urgent filter shows the urgent alone; Snooze on the crows names them snoozed."""
	var history := _history()
	_key(KEY_N)
	await _frames(SETTLE_FRAMES)
	_check("N opens the village news", bool(history.call(&"is_open")))
	await _capture("notices_history")
	var urgent: Button = _filter_button("Urgent")
	_check("the tier filter is there", urgent != null)
	if urgent == null:
		return
	_click(urgent)
	await _frames(SETTLE_FRAMES)
	_check("Urgent alone", int(history.call(&"history_count")) == 1 and String(history.call(&"history_text", 0))
		.contains("Urgent: A fox"), String(history.call(&"history_text", 0)))
	await _capture("notices_history_urgent")
	_click(_filter_button("All"))
	await _frames(SETTLE_FRAMES)
	var crows: int = _history_row_of("Crows at the barley")
	_check("the crows in the history", crows >= 0)
	if crows < 0:
		return
	_click(history.call(&"history_verb", crows, 2) as Button)
	await _frames(SETTLE_FRAMES)
	_check("Snooze quiets the crows", _feed().is_kind_snoozed(CROWS))
	_check("and the window names them", String(history.call(&"snoozed_text")).contains("Crows at the barley (6 h)"),
		String(history.call(&"snoozed_text")))
	_floors("the village news", history)
	await _capture("notices_history_snoozed")


func _filter_button(words: String) -> Button:
	"""The tier filter's button with these words (the second row of filters; null: none)."""
	var found: Button = null
	for node: Node in _history().find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == words and button.toggle_mode:
			found = button
	return found


func _history_row_of(words: String) -> int:
	"""The history row whose line contains `words` (-1: none)."""
	for slot: int in int(_history().call(&"drawn_count")):
		if String(_history().call(&"history_text", slot)).contains(words):
			return slot
	return -1
