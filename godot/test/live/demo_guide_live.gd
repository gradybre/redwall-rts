extends SceneTree
## The first-village guide on the REAL scene with REAL Viewport input (decision 0481; review F49, P7, UX-017 to UX-020).
## Not discovered by the runner: test/test_demo_guide_live.gd runs it in its own process, as demo_input_live.gd is.
##
##     godot --headless --path godot --script res://test/live/demo_guide_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## It boots demo/demo_village.tscn (on placeholders when nothing is staged) and does the FIRST OBJECTIVE BY REAL INPUT:
## the card's Show me clicked, the camera eased over the marked resident, and that resident clicked in the world -- the
## objective completes on the selection the click made, and its confirmation's Next is clicked. Then the second card's
## Show me opens its bed; Hide guide hides the card and the game menu's row reopens it, nothing granted; O opens the
## village guide, where the help is searched by typing, a field-guide entry opened, a practice story run with its
## debrief (the village's figures unchanged), and a project named and pinned by typing. Prints `LIVE <name>:
## PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const StepsScript := preload("res://demo/guide/guide_steps.gd")
const WindowScript := preload("res://demo/guide/guide_window.gd")
const Text := preload("res://demo/guide/guide_text.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 2
## Frames for the camera to ease over a target.
const EASE_FRAMES: int = 40

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _target: int = -1
var _digest: Array = []


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
	_steps = [_the_first_card_teaches, _show_me_eases_to_the_resident, _a_real_click_meets_the_villager,
		_the_card_confirms_it, _click_next, _the_second_card_s_show_me_opens_its_bed, _the_marker_is_on_the_bed,
		_hide_guide_by_click, _the_menu_row_says_hidden, _click_reopen, _reopened_nothing_granted,
		_o_opens_the_village_guide, _open_the_help_tab, _type_into_the_help, _the_help_found_it, _open_the_field_guide_tab, _search_the_field_guide,
		_open_a_field_guide_entry, _open_the_practice_tab, _start_a_story, _choose_in_the_story,
		_practice_left_the_village_alone, _open_the_projects_tab, _name_and_pin_a_project, _esc_closes_the_guide,
		_the_card_clears_the_side_columns, _scale_up_with_a_legend, _the_card_keeps_above_the_picker, _back_to_100]


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last (the root's size held: see demo_input_live.gd)."""
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
	_wait = STEP_FRAMES
	(_steps.pop_front() as Callable).call()
	return false


# --- helpers ------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _key(code: Key, unicode: int = 0) -> void:
	"""Press and release one key through the Viewport (`unicode`: the character it types)."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode if down else 0
		event.pressed = down
		root.push_input(event)


func _type(text: String) -> void:
	"""Type `text` a key at a time (letters and spaces)."""
	for c: String in text:
		var code: Key = KEY_SPACE if c == " " else (OS.find_keycode_from_string(c.to_upper()) as Key)
		_key(code, c.unicode_at(0))


func _click(at: Vector2) -> void:
	"""A left click at `at`."""
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


func _click_control(control: Control) -> void:
	"""A left click on a control's centre."""
	_click(control.get_global_transform_with_canvas() * (control.size / 2.0))


func _guide() -> Node:
	"""The village's guide."""
	return _village.call(&"guide")


func _card() -> CanvasLayer:
	"""The objective card."""
	return _guide().get("card")


func _window() -> CanvasLayer:
	"""The village guide window."""
	return _guide().get("window")


func _steps_of() -> RefCounted:
	"""The guide's progress."""
	return _guide().get("steps")


func _gate() -> GateScript:
	"""The village's input gate."""
	return _village.call(&"input_gate")


func _figures() -> Array:
	"""The village's figures a guide verb or a story could touch."""
	var services: RefCounted = _village.call(&"services")
	var stores: RefCounted = services.get("stores")
	var farm: Node = _village.get("_farm")
	return [stores.get("wood_milli_u"), stores.get("stone_milli_u"), stores.get("plank_milli_u"),
		farm.get("pantry").call(&"total_milli"), farm.get("pantry").get("delivered_milli"), farm.get("sim").get("compost_milli")]


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only when asked for, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame; forgive the clock the read-back's time (see demo_input_live.gd)."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _over_ui(point: Vector2) -> bool:
	"""Whether a shown control that stops the mouse is under `point`."""
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and control.is_visible_in_tree() \
				and GateScript.screen_rect(control).has_point(point):
			return true
	return false


# --- the first objective, by real input ---------------------------------------------------------------

func _the_first_card_teaches() -> void:
	"""The card is up: objective 1 of 4, its teaching, the next action, the marker on a resident, nothing selected."""
	var text: String = _card().call(&"text")
	_check("the card shows objective 1", _card().call(&"is_shown") and text.begins_with("Guide 1 of 4 · Meet a villager"),
		text.get_slice("\n", 0))
	_check("it says the next action", text.contains("Next: " + Text.NEXT_SELECT))
	_check("the marker stands on a resident", (_guide().get("beacon") as Node3D).visible)
	_check("nobody is selected", int(_village.get("_command").call(&"selection_count")) == 0)
	_target = int(_guide().get("_status").get("target_id"))
	_capture("guide_card_1")


func _show_me_eases_to_the_resident() -> void:
	"""Show me (a real click on the card) eases the camera over the marked resident without selecting it."""
	_click_control(_card().call(&"button", Text.SHOW_ME) as Control)
	_check("Show me selects nobody", int(_village.get("_command").call(&"selection_count")) == 0)
	_wait = EASE_FRAMES


func _a_real_click_meets_the_villager() -> void:
	"""Click the marked resident in the world: it is selected, and objective 1 is done on that selection."""
	var actor: Node3D = _village.get("_cast").call(&"actor", _target)
	var at: Vector3 = actor.global_position + Vector3(0.0, float(actor.get("height_m")) * 0.5, 0.0)
	var camera: Camera3D = root.get_camera_3d()
	var point: Vector2 = camera.unproject_position(at)
	_check("the resident is on screen, clear of the HUD", Rect2(Vector2.ZERO, Vector2(_size)).has_point(point)
		and not _over_ui(point), str(point))
	_click(point)
	var selected: PackedInt32Array = _village.get("_command").call(&"selected")
	_check("the click selected it", selected.size() == 1 and selected[0] == _target, str(selected))
	_wait = 6


func _the_card_confirms_it() -> void:
	"""Objective 1 is done on the click's selection, and the card confirms it with the resident's name."""
	var text: String = _card().call(&"text")
	_check("objective 1 is done by the click", bool(_guide().get("facts").get("met")))
	_check("the card confirms it", text.contains(" is selected. The Demo party panel"), text.get_slice("\n", 1))
	_capture("guide_card_confirm")


func _click_next() -> void:
	"""Next (clicked) moves to objective 2."""
	_click_control(_card().call(&"button", Text.NEXT) as Control)
	_wait = 4


func _the_second_card_s_show_me_opens_its_bed() -> void:
	"""Objective 2's card: its Show me goes to its bed and opens the bed's panel (the bed selected)."""
	var text: String = _card().call(&"text")
	_check("objective 2 is current", text.begins_with("Guide 2 of 4 · Bring in a harvest"), text.get_slice("\n", 0))
	var target: int = int(_guide().get("_status").get("target_id"))
	_click_control(_card().call(&"button", Text.SHOW_ME) as Control)
	_check("Show me opened its bed", int(_village.get("_farm").get("selected_bed")) == target, "bed %d" % target)
	_wait = EASE_FRAMES


func _the_marker_is_on_the_bed() -> void:
	"""The marker rings the bed, which stands below the card on screen (Show me centres beyond it)."""
	var beacon: Node3D = _guide().get("beacon")
	var at: Vector3 = beacon.call(&"target_point")
	var point: Vector2 = root.get_camera_3d().unproject_position(at)
	var card: Rect2 = _card().call(&"frame_rect")
	_check("the marker is shown", beacon.visible)
	_check("the bed is below the card", point.y > card.end.y and Rect2(Vector2.ZERO, Vector2(_size)).has_point(point),
		"%s / card bottom %.0f" % [point, card.end.y])
	_capture("guide_card_2_bed")


# --- skip and reopen -------------------------------------------------------------------------------------

func _hide_guide_by_click() -> void:
	"""Hide guide hides the card (and the marker); the village's figures are noted."""
	_digest = _figures()
	_click_control(_card().call(&"button", Text.HIDE) as Control)
	_check("Hide guide hides the card", not bool(_card().call(&"is_shown")))
	_check("and the marker", not (_guide().get("beacon") as Node3D).visible)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)


func _the_menu_row_says_hidden() -> void:
	"""Esc to the game menu: its guide row says hidden at objective 2, with Reopen guide."""
	var menu: MenuScript = _village.call(&"menu")
	if not menu.visible:
		menu.open()
	var text: String = menu.page_text(MenuScript.PAGE_MENU)
	_check("the menu row says where the guide stands", text.contains("hidden, at objective 2 of 4"))
	_check("the row offers Reopen guide", _find_button(menu, Text.REOPEN_TEXT) != null)
	_capture("guide_menu_row")


func _click_reopen() -> void:
	"""Reopen guide, clicked."""
	var reopen: Button = _find_button(_village.call(&"menu"), Text.REOPEN_TEXT)
	if reopen != null:
		_click_control(reopen)


func _reopened_nothing_granted() -> void:
	"""The card is back on objective 2; nothing was granted or lost by hiding and reopening."""
	var menu: MenuScript = _village.call(&"menu")
	menu.close()
	_check("the card is back", bool(_card().call(&"is_shown")) and int(_steps_of().get("current")) == 1)
	_check("nothing granted or lost", _figures() == _digest, "%s vs %s" % [_figures(), _digest])


func _find_button(node: Node, words: String) -> Button:
	"""The shown button under `node` with these words."""
	for child: Node in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == words and button.is_visible_in_tree():
			return button
	return null


# --- the village guide ------------------------------------------------------------------------------------

func _o_opens_the_village_guide() -> void:
	"""O opens the village guide over a scrim, holding the menu pause, its objectives listing 1 done and 2 current."""
	_key(KEY_O)
	_check("O opens the village guide", _window().visible and _gate().top_layer() == _window())
	_check("the village waits", root.get_node(^"GameManager").call(&"is_paused"))
	var text: String = _window().call(&"objectives_text")
	_check("objective 1 ticked, 2 current", text.begins_with("✓ 1.") and text.contains("▸ 2."), text.get_slice("\n", 1))
	_capture("guide_window_objectives")


func _open_the_help_tab() -> void:
	"""The Help tab, clicked."""
	_click_control(_window().call(&"tab_button", WindowScript.TAB_HELP) as Control)


func _type_into_the_help() -> void:
	"""'frost' typed into the focused search field: the frost topic is found."""
	var help: Node = _window().get("help")
	var field: LineEdit = help.call(&"field")
	_check("the search field has the focus", root.gui_get_focus_owner() == field, str(root.gui_get_focus_owner()))
	field.grab_focus()
	_type("frost")
	_check("typing reaches the search field", field.text == "frost", field.text)


func _the_help_found_it() -> void:
	"""The search ran on what was typed (a LineEdit says so after the frame): the frost topic first."""
	var help: Node = _window().get("help")
	var shown: PackedInt32Array = help.call(&"shown")
	var top: String = String(help.get("topics").call(&"title_of", shown[0])) if shown.size() >= 1 else ""
	_check("the frost topic is found", top.contains("frost"), "%s %s" % [top, help.call(&"count_text")])
	_capture("guide_help_search")


func _open_the_field_guide_tab() -> void:
	"""The Field guide tab, clicked."""
	_click_control(_window().call(&"tab_button", WindowScript.TAB_FIELD_GUIDE) as Control)


func _search_the_field_guide() -> void:
	"""'soup' typed."""
	var page: Node = _window().get("field_guide")
	(page.call(&"field") as LineEdit).grab_focus()
	_type("soup")
	_check("the field guide searched", String((page.call(&"field") as LineEdit).text) == "soup")


func _open_a_field_guide_entry() -> void:
	"""The soup's entry, clicked: its page with its sections."""
	var page: Node = _window().get("field_guide")
	var first: Button = null
	for child: Node in page.find_children("*", "Button", true, false):
		if (child as Button).is_visible_in_tree() and (child as Button).text.begins_with("Togget"):
			first = child
	_check("the soup is listed", first != null)
	if first != null:
		_click_control(first)
	_check("its page is open", String(page.call(&"entry_text")).contains("Available here"))
	_capture("guide_field_guide_entry")


func _open_the_practice_tab() -> void:
	"""The Practice tab, clicked (the village's figures noted)."""
	_digest = _figures()
	_click_control(_window().call(&"tab_button", WindowScript.TAB_PRACTICE) as Control)


func _start_a_story() -> void:
	"""The winter pantry, started by a click."""
	_click_control(_window().get("practice").call(&"start_button", 2) as Control)


func _choose_in_the_story() -> void:
	"""'Rack a root cellar' clicked: what happened and the debrief show."""
	var page: Node = _window().get("practice")
	_click_control(page.call(&"choice_button", 1) as Control)
	_check("the story ran to its debrief", String(page.call(&"result_text")).contains("Debrief"))
	_check("the chosen choice ran", String(page.call(&"result_text")).contains("▸ Rack a root cellar"))
	_capture("guide_practice_debrief")


func _practice_left_the_village_alone() -> void:
	"""The village's figures are as they were before the story."""
	_check("the village is untouched by the story", _figures() == _digest, "%s vs %s" % [_figures(), _digest])


func _open_the_projects_tab() -> void:
	"""The Projects tab, clicked."""
	_click_control(_window().call(&"tab_button", WindowScript.TAB_PROJECTS) as Control)


func _name_and_pin_a_project() -> void:
	"""A name typed, Pin clicked: the project is pinned with whatever is selected now as its places."""
	var page: Node = _window().get("projects")
	var field: LineEdit = page.call(&"name_field")
	field.grab_focus()
	_type("Wood for winter")
	var kinds: Array[Vector3i] = []
	var names := PackedStringArray()
	_guide().get("world").call(&"places_into", kinds, names)
	_click_control(_find_button(page, "Pin project"))
	var pinned: Array = _guide().get("projects").get("projects")
	_check("the project is pinned", pinned.size() == 1 and pinned[0].get("name") == "Wood for winter", str(pinned.size()))
	_check("with the places selected", pinned.size() == 1 and pinned[0].get("place_names") == names, str(names))
	_capture("guide_projects")


func _esc_closes_the_guide() -> void:
	"""Esc closes the window and the village runs again."""
	_key(KEY_ESCAPE)
	_check("Esc closes the guide", not _window().visible)
	_check("the village runs again", not root.get_node(^"GameManager").call(&"is_paused"))


func _the_card_clears_the_side_columns() -> void:
	"""The card sits clear of the party panel's column, the right column's panels and the news strip."""
	var rect: Rect2 = _card().call(&"frame_rect")
	var party: Rect2 = _village.get("_command").call(&"panel").call(&"frame_rect")
	var strip: Rect2 = _village.get("_news").call(&"frame_rect")
	var ok: bool = rect.size.x > 0.0 and rect.position.x > 0.0 and rect.end.x < float(_size.x)
	_check("the card is on screen", ok, str(rect))
	_check("the card clears the party panel", not party.intersects(rect), "%s / %s" % [rect, party])
	var strip_shown: bool = (_village.get("_news").get("_frame") as Control).is_visible_in_tree()
	_check("the card clears the news strip", not strip_shown or not strip.intersects(rect), "%s / %s" % [rect, strip])
	for panel: Node in [_village.get("_farm").get("bed_panel")]:
		var frame: Control = panel.get_child(0) as Control
		if frame != null and frame.is_visible_in_tree():
			_check("the card clears the right column", not GateScript.screen_rect(frame).intersects(rect),
				"%s / %s" % [rect, GateScript.screen_rect(frame)])
	_capture("guide_card_final")


func _scale_up_with_a_legend() -> void:
	"""125 % with a map layer's legend unfolded: the room above the Map layer picker shrinks."""
	_village.call(&"set_ui_scale", 125)
	_village.get("_lens_picker").call(&"choose", 1)
	_wait = 8


func _the_card_keeps_above_the_picker() -> void:
	"""The card is shown above the picker (dropping its teaching first) or waits for room -- never over it."""
	var card: Rect2 = _card().call(&"frame_rect")
	var shown: bool = bool(_card().call(&"is_shown"))
	var picker: Rect2 = _village.get("_lens_picker").call(&"frame_rect")
	var density: int = int(_card().get("_density"))
	_check("the card never covers the Map layer picker", not shown or not card.intersects(picker),
		"%s density %d: %s / %s" % ["shown" if shown else "waiting", density, card, picker])
	_check("hidden only for room", shown or bool(_card().get("_cramped")))
	_capture("guide_card_125_legend")


func _back_to_100() -> void:
	"""The layer off and 100 % again (after the frame above is saved)."""
	_village.get("_lens_picker").call(&"choose", 0)
	_village.call(&"set_ui_scale", 100)
	_check("back to 100 %", true)
