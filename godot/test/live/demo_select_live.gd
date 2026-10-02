extends SceneTree
## The demo's group selection (decision 0791) on the REAL scene with REAL Viewport input: the box's "Selecting residents:
## n", control groups by key (Ctrl+digit, digit, the digit twice), a double click's residents of a kind in view, Select
## idle, the group section (its lines, tiles, a status row added by data, crews, Send to...) and the per-refresh
## allocation check. Not discovered by the runner: test/test_demo_select_live.gd runs it in its own process, as the input
## and people harnesses are (decisions 0261, 0491), because only an in-tree scene lays its Controls out and takes Viewport
## input. A click meant for the world goes where no HUD control or card covers it (`_world_near`).
##
##     godot --headless --path godot --script res://test/live/demo_select_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const CrewsScript := preload("res://demo/work/work_crews.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const GroupSelectScript := preload("res://demo/control/group_select.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const BOX_HALF: Vector2 = Vector2(140.0, 100.0)
const REFRESHES: int = 50

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
	root.get_node(^"GameManager").call(&"pause_game")
	_village.call(&"guide").call(&"skip")
	await _the_box_counts()
	await _control_groups()
	await _a_double_click_selects_its_kind()
	await _select_idle()
	await _the_group_section()
	await _built_in_statuses()
	await _a_crew_for_all()
	await _send_to()
	await _no_allocation_per_refresh()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _group() -> Node:
	"""The group selection."""
	return _village.call(&"group_select")


func _cast() -> Node:
	"""The cast."""
	return _village.get("_cast")


func _camera() -> Node:
	"""The demo camera."""
	return _village.get("_camera")


func _selected() -> PackedInt32Array:
	"""Who is selected."""
	return _command().call(&"selected")


func _notice() -> String:
	"""The party panel's notice line."""
	return String(_command().call(&"notice_for_selection"))


func _settle() -> void:
	"""Let the panels refresh."""
	_group().set("_refresh_in", 0.0)
	await _frames(SETTLE_FRAMES)


func _screen_of(who: int) -> Vector2:
	"""Where resident `who`'s middle is on screen."""
	var actor: Node3D = _cast().call(&"actor", who)
	var camera: Camera3D = _camera().call(&"camera")
	return camera.unproject_position(actor.global_position + Vector3(0.0, float(actor.get("height_m")) * 0.5, 0.0))


func _look_at(who: int) -> void:
	"""Centre the camera on resident `who` at once."""
	var at: Vector2 = (_cast().call(&"actor", who) as Node).get("brain").call(&"surface_point")
	_camera().call(&"centre_on", Vector3(at.x, 0.0, at.y))
	_camera().call(&"snap")
	await _frames(SETTLE_FRAMES)


func _uncovered(at: Vector2) -> bool:
	"""Whether a press at `at` reaches the world (no HUD control or card over it)."""
	_move(at, false)
	await _frames(1)
	return root.gui_get_hovered_control() == null


func _world_near(at: Vector2) -> Vector2:
	"""The point nearest `at` (on a 24 px spiral of tries) that no HUD control or card covers: where a press reaches the
	world. `at` itself when none is found."""
	for ring: int in 12:
		for step: int in maxi(1, ring * 8):
			var angle: float = TAU * float(step) / float(maxi(1, ring * 8))
			var probe: Vector2 = at + Vector2(cos(angle), sin(angle)) * 24.0 * float(ring)
			if await _uncovered(probe):
				return probe
	return at


func _mouse(at: Vector2, down: bool, shift: bool = false) -> void:
	"""A left button press or release at `at`."""
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = down
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)


func _move(at: Vector2, held: bool) -> void:
	"""Move the mouse to `at` (the left button held when `held`)."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(motion, true)


func _click_at(at: Vector2, shift: bool = false) -> void:
	"""A left click at `at`."""
	_move(at, false)
	_mouse(at, true, shift)
	_mouse(at, false, shift)


func _click(control: Control, shift: bool = false) -> void:
	"""A left click at `control`'s centre."""
	_click_at(control.get_global_transform_with_canvas() * (control.size / 2.0), shift)


func _key(code: Key, ctrl: bool = false) -> void:
	"""Press and release one key (Ctrl held when `ctrl`)."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event, true)


func _reveal(control: Control) -> void:
	"""Scroll `control`'s scroll to it, and wait for it to move."""
	var at: Node = control.get_parent()
	while at != null and not at is ScrollContainer:
		at = at.get_parent()
	if at != null:
		(at as ScrollContainer).ensure_control_visible(control)
	await _frames(2)


func _fraction(control: Control) -> float:
	"""How much of `control` is on screen: its rect cut by the window and every clipping ancestor."""
	if control == null or not control.is_visible_in_tree():
		return 0.0
	var rect: Rect2 = control.get_global_rect()
	var clip := Rect2(Vector2.ZERO, Vector2(_size))
	var at: Node = control.get_parent()
	while at != null:
		if at is Control and (at as Control).clip_contents:
			clip = clip.intersection((at as Control).get_global_rect())
		at = at.get_parent()
	return rect.intersection(clip).get_area() / maxf(rect.get_area(), 0.0001)


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


# --- the steps ------------------------------------------------------------------------------------------------

func _the_box_counts() -> void:
	"""A box dragged round resident 0: "Selecting residents: n" beside it, n what the box would select; released, those
	n selected."""
	_command().call(&"clear_selection")
	await _look_at(0)
	var centre: Vector2 = _screen_of(0)
	var start: Vector2 = await _world_near(centre - BOX_HALF)
	var end: Vector2 = centre + BOX_HALF
	_move(start, false)
	_mouse(start, true)
	_move(start.lerp(end, 0.5), true)
	_move(end, true)
	await _frames(2)
	var expected := PackedInt32Array()
	var count: int = int(_command().call(&"box_into", start, end, expected))
	var label: Label = _group().call(&"box_label")
	_check("the box says how many it holds", label.is_visible_in_tree() and label.text == "Selecting residents: %d" % count,
		"%s (expected %d)" % [label.text, count])
	var scale: float = float(_group().call(&"hud_scale"))
	_check("the count is drawn at the HUD's scale", scale >= 1.0 and (label.get_parent() as Control).scale.x == scale,
		"%.2f" % scale)
	_check("the box holds resident 0", count >= 1 and expected.slice(0, count).has(0), "%d" % count)
	await _capture("select_box")
	_mouse(end, false)
	await _frames(2)
	_check("released, the count shown is the count selected", _selected().size() == count, "%d" % _selected().size())
	_check("and the label goes", not label.is_visible_in_tree())


func _control_groups() -> void:
	"""Ctrl+1 keeps three; 1 selects them again from nothing; 1 twice centres on their middle; an empty group and Ctrl
	with nobody selected change nothing."""
	var three := PackedInt32Array([0, 1, 2])
	_command().call(&"select", three)
	_key(KEY_1, true)
	await _frames(2)
	_check("Ctrl+1 keeps the group", int(_group().get("groups").call(&"size_of", 1)) == 3, _notice())
	_check("and says so", _notice().begins_with("Group 1:"), _notice())
	_command().call(&"clear_selection")
	_camera().call(&"centre_on", Vector3.ZERO)
	var before: Vector3 = _camera().get("_target_focus")
	await _frames(20)
	_key(KEY_1)
	await _frames(2)
	_check("1 selects them again", _selected() == three, str(_selected()))
	_check("once, without moving the view", _camera().get("_target_focus") == before, str(_camera().get("_target_focus")))
	await _frames(20)
	_key(KEY_1)
	_key(KEY_1)
	await _frames(2)
	var middle: Vector3 = _group().call(&"middle_of", three)
	var focus: Vector3 = _camera().get("_target_focus")
	_check("1 twice goes to their middle", Vector2(focus.x - middle.x, focus.z - middle.z).length() < 0.05,
		"%s vs %s" % [focus, middle])
	await _empty_groups(three)


func _empty_groups(three: PackedInt32Array) -> void:
	"""An empty group leaves the selection; Ctrl+1 with nobody selected keeps group 1."""
	_key(KEY_7)
	await _frames(2)
	_check("an empty group leaves the selection", _selected() == three and _notice().contains("Group 7 is empty"), _notice())
	_command().call(&"clear_selection")
	_key(KEY_1, true)
	await _frames(2)
	_check("Ctrl+1 with nobody selected keeps group 1", int(_group().get("groups").call(&"size_of", 1)) == 3, _notice())


func _a_double_click_selects_its_kind() -> void:
	"""A double click on a resident selects every resident of its species in view (and only those)."""
	var who: int = _first_with_kin()
	_check("a resident with kin to click", who >= 0)
	if who < 0:
		return
	var species: String = (_cast().call(&"actor", who) as Node).get("species")
	var kin: int = _kin_of(who)
	var middle: Vector3 = _group().call(&"middle_of", PackedInt32Array([who, kin]))
	_camera().call(&"centre_on", middle)
	_camera().call(&"snap")
	await _frames(SETTLE_FRAMES)
	var in_view := PackedInt32Array()
	var count: int = int(_command().call(&"box_into", Vector2.ZERO, Vector2(_size), in_view))
	var expected := PackedInt32Array()
	for k: int in count:
		if (_cast().call(&"actor", in_view[k]) as Node).get("species") == species:
			expected.append(in_view[k])
	expected.sort()
	var at: Vector2 = await _point_on_one_of(who, kin)
	_click_at(at)
	_click_at(at)
	await _frames(2)
	_check("a double click selects its kind in view", _selected() == expected and expected.has(who),
		"%s vs %s (%s)" % [_selected(), expected, species])
	_check("both of its kind were in view", expected.size() >= 2, str(expected))
	await _not_a_double_click(at)


func _point_on_one_of(who: int, kin: int) -> Vector2:
	"""Where to click so the click lands on `who` or `kin`: its screen point, uncovered by any panel and with no other
	resident drawn in front of it there (the pick says who is under it) -- `who`'s first. Batch 7 integration: the merged
	village opens with another resident standing in front of the first mouse at 1280x720 and 1920x1080."""
	for one: int in [who, kin]:
		var at: Vector2 = _screen_of(one)
		if await _uncovered(at) and int(_command().call(&"pick", at)) == one:
			return at
	return _screen_of(who)


func _not_a_double_click(at: Vector2) -> void:
	"""Two clicks further apart than the drag threshold select the one clicked, not its kind; a Shift double click
	toggles twice and leaves the selection as it was."""
	_click_at(at)
	_click_at(at + Vector2(7.0, 0.0))
	await _frames(2)
	var alone: PackedInt32Array = _selected()
	_check("two clicks 7 px apart (past the 6 px threshold) are not a double click", alone.size() <= 1, str(alone))
	var who: int = int(_command().call(&"pick", at))
	var other: int = _not_kin_of(who)
	if other < 0:
		# The unstaged cast (CI) is one placeholder species: any other resident will do (batch 7 integration).
		other = (who + 1) % int(_cast().call(&"actor_count"))
	var before: PackedInt32Array = PackedInt32Array([who, other])
	before.sort()
	_command().call(&"select", before)
	_click_at(at, true)
	_click_at(at, true)
	await _frames(2)
	_check("a Shift double click toggles twice", _selected() == before, "%s, before %s, at %s" % [_selected(), before, at])


func _not_kin_of(who: int) -> int:
	"""A resident of another species than `who`'s (-1: none)."""
	for other: int in int(_cast().call(&"actor_count")):
		if (_cast().call(&"actor", other) as Node).get("species") != (_cast().call(&"actor", who) as Node).get("species"):
			return other
	return -1


func _kin_of(who: int) -> int:
	"""Another resident of `who`'s species (-1: none)."""
	for other: int in int(_cast().call(&"actor_count")):
		if other != who and (_cast().call(&"actor", other) as Node).get("species") == (_cast().call(&"actor", who) as Node).get("species"):
			return other
	return -1


func _first_with_kin() -> int:
	"""The first resident sharing its species with another (-1: none)."""
	var count: int = int(_cast().call(&"actor_count"))
	for a: int in count:
		for b: int in count:
			if a != b and (_cast().call(&"actor", a) as Node).get("species") == (_cast().call(&"actor", b) as Node).get("species"):
				return a
	return -1


func _select_idle() -> void:
	"""Select idle: shown with nobody selected; pressed, it selects exactly the idle (or, nobody idle, is disabled)."""
	_command().call(&"clear_selection")
	await _settle()
	var button: Button = _group().get("panel").call(&"idle_button")
	_check("Select idle shows with nobody selected", _fraction(button) > 0.99, "%.2f" % _fraction(button))
	var idle := PackedInt32Array()
	var board: Object = _village.call(&"work").get("board")
	for who: int in int(_cast().call(&"actor_count")):
		var brain: Object = (_cast().call(&"actor", who) as Node).get("brain")
		if CrewsScript.status_of(brain, bool(board.call(&"has_job", who))) == CrewsScript.STATUS_AVAILABLE:
			idle.append(who)
	_check("its count is the idle's", button.text == "Select idle (%d)" % idle.size(), button.text)
	if idle.is_empty():
		_check("nobody idle: disabled", button.disabled)
		return
	_click(button)
	await _frames(2)
	_check("pressed, the idle are selected", _selected() == idle, "%s vs %s" % [_selected(), idle])
	await _capture("select_idle")


func _the_group_section() -> void:
	"""Five selected: the section's lines and a tile each, in view, text and buttons at their floors; a tile centres on
	its resident, the group kept; Shift on a tile drops it."""
	var five := PackedInt32Array([0, 1, 2, 3, 4])
	_command().call(&"select", five)
	await _settle()
	var panel: Control = _group().get("panel")
	_check("the group section shows", panel.is_visible_in_tree())
	_check("a tile each", int(panel.call(&"tile_count")) == 5, str(panel.call(&"tile_count")))
	var text: String = panel.call(&"lines_text")
	for part: String in ["Doing: ", "Needs attention:", "Idle", "Crews: ", "Ctrl+0–9"]:
		_check("the section says %s" % part, text.contains(part), text.replace("\n", " | "))
	var tile: Button = panel.call(&"tile", 2)
	await _reveal(tile)
	_check("tile 2 is in view", _fraction(tile) > 0.99, "%.2f" % _fraction(tile))
	_floors(panel)
	await _a_status_by_data(panel)
	await _capture("group_section")
	_camera().call(&"centre_on", Vector3.ZERO)
	_click(tile)
	await _frames(2)
	var at: Vector2 = (_cast().call(&"actor", 2) as Node).get("brain").call(&"surface_point")
	var focus: Vector3 = _camera().get("_target_focus")
	_check("a tile centres on its resident", Vector2(focus.x - at.x, focus.z - at.y).length() < 0.05, "%s vs %s" % [focus, at])
	_check("and keeps the group", _selected() == five, str(_selected()))
	_click(panel.call(&"tile", 0), true)
	await _frames(2)
	_check("Shift on a tile drops it", _selected() == PackedInt32Array([1, 2, 3, 4]), str(_selected()))


func _built_in_statuses() -> void:
	"""The built-in rows through their owners' own state: resident 0 hungry, 1 peckish, 2 stuck after a refused trip, 3
	given a bed -- each listed where it belongs and named on the tiles."""
	var rules: Dictionary = (load("res://demo/kitchen/meal_rules.gd") as GDScript).get_script_constant_map()
	var fed: Object = _village.call(&"kitchen").get("kitchen").get("fed")
	var night: Object = _command().call(&"tunnels").get("ext").get("night")
	var brain: Object = (_cast().call(&"actor", 2) as Node).get("brain")
	var hunger: PackedInt32Array = fed.get("hunger")
	var kept: Array = [hunger[0], hunger[1], night.get("bed_of")[3], brain.get("state"), brain.get("trip_outcome")]
	_set_column(fed, "hunger", 0, 0)
	_set_column(fed, "hunger", 1, int(rules["URGENT_AT"]) + 1)
	_set_column(night, "bed_of", 3, 0)
	brain.set("state", BrainScript.State.HOLD)
	brain.set("trip_outcome", BrainScript.TRIP_FAILED)
	_command().call(&"select", PackedInt32Array([0, 1, 2, 3]))
	await _settle()
	_statuses_read()
	_set_column(fed, "hunger", 0, int(kept[0]))
	_set_column(fed, "hunger", 1, int(kept[1]))
	_set_column(night, "bed_of", 3, int(kept[2]))
	brain.set("state", kept[3])
	brain.set("trip_outcome", kept[4])
	_owners_rows()


func _owners_rows() -> void:
	"""The rows the village's owners add where they are wired (demo_village.gd, decision 0902): the winter's Chilled and
	the infirmary's Injured."""
	var statuses: Object = _group().get("statuses")
	_check("the winter's Chilled is a row", int(statuses.call(&"find", &"chilled")) >= 0)
	_check("the infirmary's Injured is a row", int(statuses.call(&"find", &"injured")) >= 0)


func _set_column(owner: Object, column: String, k: int, value: int) -> void:
	"""Set one cell of an owner's packed column (copied out and back: a packed array is a value here)."""
	var cells: PackedInt32Array = owner.get(column)
	cells[k] = value
	owner.set(column, cells)


func _statuses_read() -> void:
	"""The checks for `_built_in_statuses`."""
	var panel: Control = _group().get("panel")
	var text: String = panel.call(&"lines_text")
	var attention: int = text.find("Needs attention:")
	var hungry: int = text.find("Hungry ×1 — %s" % _first_name(0))
	var stuck: int = text.find("Can't get there ×1 — %s" % _first_name(2))
	var peckish: int = text.find("Peckish ×1 — %s" % _first_name(1))
	_check("Hungry is a warning", hungry > attention and attention >= 0 and hungry < peckish, text.replace("\n", " | "))
	_check("Can't get there is a warning", stuck > attention and stuck < peckish, text.replace("\n", " | "))
	_check("Peckish is a note", peckish > 0)
	var beds: String = text.substr(text.find("No bed"))
	beds = beds.left(beds.find("\n"))
	_check("No bed names the bedless, not the one given a bed", beds.contains(_line_name(0))
		and not beds.contains(_line_name(3)), beds)
	var tags := PackedStringArray()
	for k: int in 3:
		tags.append(((panel.call(&"tile", k) as Node).get_node(^"Lines/Tag") as Label).text)
	_check("the tiles name the warnings", tags[0] == "Hungry" and tags[2] == "Can't get there" and tags[1] != "Peckish",
		str(tags))


func _a_status_by_data(panel: Control) -> void:
	"""A status row added by data (as the winter fuel's Chilled will be): the section lists it under Needs attention
	and the member's tile names it with a clay edge -- no panel code for it."""
	var statuses: Object = _group().get("statuses")
	var chilled: Array[bool] = [true]
	statuses.call(&"add", &"live_chilled", "Chilled", 1, func(who: int) -> bool: return chilled[0] and who == 0)
	await _settle()
	var text: String = panel.call(&"lines_text")
	var line: String = "Chilled ×1 — %s" % _first_name(0)
	var at: int = text.find(line)
	_check("a status added by data is listed", at >= 0, text.replace("\n", " | "))
	var note: int = text.find("No bed")
	_check("under Needs attention, before the notes", text.contains("Needs attention:\n" + line)
		and at < text.find("\nIdle") and (note < 0 or at < note),
		text.replace("\n", " | "))
	var tag: Label = (panel.call(&"tile", 0) as Node).get_node(^"Lines/Tag")
	_check("and tags its member's tile", tag.text == "Chilled", tag.text)
	chilled[0] = false
	await _settle()
	_check("when it passes, the tile says so on the next refresh", tag.text != "Chilled", tag.text)


func _first_name(who: int) -> String:
	"""Resident `who`'s first name, as a line naming it alone prints it."""
	return String((_cast().call(&"actor", who) as Node).get("display_name")).get_slice(" ", 0)


func _line_name(who: int) -> String:
	"""Resident `who`'s name as a line naming several prints it: its first word, or its whole name where another of the
	cast shares that word (group_select.gd `short_names`: the unstaged cast's "Placeholder 0", "Placeholder 1"... in
	CI; batch 7 integration)."""
	var full := PackedStringArray()
	for k: int in int(_cast().call(&"actor_count")):
		full.append(String((_cast().call(&"actor", k) as Node).get("display_name")))
	return GroupSelectScript.short_names(full)[who]


func _floors(panel: Control) -> void:
	"""Every shown label and button in the section at least 14 px; every shown button at least 32 px tall."""
	var bad := PackedStringArray()
	for node: Node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		if control.get_theme_font_size(&"font_size") < 14 or (control is Button and control.size.y < 32.0 - 0.01):
			bad.append("%s %dpx %.0f" % [control.name, control.get_theme_font_size(&"font_size"), control.size.y])
	_check("the section's text 14 px, buttons 32 px", bad.is_empty(), ", ".join(bad))


func _a_crew_for_all() -> void:
	"""Two selected, one already on the Woods crew, put on it by one press: both on it, the notice says who joined and
	who was on it; the button is then disabled (all on it already)."""
	var two := PackedInt32Array([0, 1])
	_command().call(&"select", two)
	var crews: Object = _village.call(&"work").get("board").get("crews")
	var target: int = CrewsScript.CREW_WOODS
	crews.call(&"set_crew", 0, CrewsScript.CREW_FIELD)
	crews.call(&"set_crew", 1, target)
	await _settle()
	var button: Button = _group().get("panel").call(&"crew_button", target)
	await _reveal(button)
	_click(button)
	await _settle()
	var on: PackedInt32Array = crews.get("crew_of")
	_check("one press puts both on the Woods crew", on[0] == target and on[1] == target, "%d %d" % [on[0], on[1]])
	_check("the notice names the crew and who was on it", _notice().begins_with("Woods crew")
		and _notice().contains("%s joins; %s already on it" % [_line_name(0), _line_name(1)]), _notice())
	_check("then the Woods button is disabled", button.disabled, button.tooltip_text)
	await _capture("group_crew")


func _send_to() -> void:
	"""Send to… waits for a click (Esc cancels it, the selection kept); the click orders the two there."""
	var two := PackedInt32Array([0, 1])
	_command().call(&"select", two)
	await _settle()
	var send: Button = _group().get("panel").call(&"send_button")
	await _reveal(send)
	_click(send)
	await _frames(2)
	_check("Send to… waits", bool(_group().call(&"is_armed")) and send.button_pressed, _notice())
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("Esc cancels it and keeps the selection", not bool(_group().call(&"is_armed")) and _selected() == two, _notice())
	await _reveal(send)
	_click(send)
	await _frames(2)
	await _look_at(0)
	var spot: Vector2 = await _world_near(_screen_of(0) + Vector2(60.0, 40.0))
	_click_at(spot)
	await _frames(2)
	var brain: Object = (_cast().call(&"actor", 1) as Node).get("brain")
	_check("the click sends them", not bool(_group().call(&"is_armed")) and int(brain.get("order")) != BrainScript.ORDER_NONE,
		"order %d, %s" % [int(brain.get("order")), _notice()])
	_check("and they stay selected", _selected() == two, str(_selected()))
	_check("and the prompt is gone", not _notice().begins_with("Click where"), _notice())
	await _send_ends(send, spot)


func _arm(send: Button) -> void:
	"""Select residents 0 and 1 and press Send to…."""
	_command().call(&"select", PackedInt32Array([0, 1]))
	await _settle()
	await _reveal(send)
	_click(send)
	await _frames(2)


func _send_ends(send: Button, spot: Vector2) -> void:
	"""Send to… ends when the group drops below two or the U view opens, cannot start in the U view, outlasts the wheel,
	and passes a right click on as its own order."""
	await _arm(send)
	var tile: Button = _group().get("panel").call(&"tile", 0)
	await _reveal(tile)
	_click(tile, true)
	await _settle()
	_check("dropping to one ends Send to…", not bool(_group().call(&"is_armed")), str(_selected()))
	await _arm(send)
	_key(KEY_U)
	await _settle()
	_check("the U view ends Send to…", not bool(_group().call(&"is_armed")))
	await _reveal(send)
	_click(send)
	await _frames(2)
	_check("and it cannot start there", not bool(_group().call(&"is_armed")) and _notice().contains("right-click"), _notice())
	_key(KEY_U)
	await _settle()
	await _arm(send)
	_wheel(spot)
	await _frames(2)
	_check("the wheel leaves it waiting", bool(_group().call(&"is_armed")))
	await _right_click_passes(spot)


func _wheel(at: Vector2) -> void:
	"""A Shift+wheel tick and a sideways wheel tick at `at` (the camera takes neither)."""
	for index: MouseButton in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		var event := InputEventMouseButton.new()
		event.button_index = index
		event.position = at
		event.shift_pressed = index == MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		root.push_input(event, true)


func _right_click_passes(spot: Vector2) -> void:
	"""While armed, a right click ends the wait and gives its own order to the two, who stay selected."""
	var brain: Object = (_cast().call(&"actor", 0) as Node).get("brain")
	_cast().call(&"release", PackedInt32Array([0, 1]))
	await _frames(2)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = spot
	for down: bool in [true, false]:
		event.pressed = down
		root.push_input(event.duplicate() as InputEvent, true)
	await _frames(2)
	_check("a right click ends it and orders them itself", not bool(_group().call(&"is_armed"))
		and int(brain.get("order")) != BrainScript.ORDER_NONE and _selected() == PackedInt32Array([0, 1]),
		"order %d" % int(brain.get("order")))


func _no_allocation_per_refresh() -> void:
	"""With nothing changed, the refresh re-draws nothing and leaves no object behind, a box frame too."""
	_command().call(&"select", PackedInt32Array([0, 1, 2]))
	await _settle()
	var group: Node = _group()
	var redrawn: int = 0
	group.call(&"refresh")
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in REFRESHES:
		redrawn += 1 if bool(group.call(&"refresh")) else 0
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_check("an unchanged refresh re-draws nothing", redrawn == 0, "%d of %d" % [redrawn, REFRESHES])
	_check("and makes no object", after == objects, "%d -> %d" % [objects, after])
	await _no_allocation_while_dragging()


func _no_allocation_while_dragging() -> void:
	"""While a box is held, following it frame after frame makes no object."""
	var start: Vector2 = await _world_near(Vector2(_size) * 0.5)
	_move(start, false)
	_mouse(start, true)
	_move(start + BOX_HALF, true)
	await _frames(2)
	var label: Label = _group().call(&"box_label")
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in REFRESHES:
		_group().call(&"_follow_box")
	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_check("a held box is followed", label.is_visible_in_tree(), label.text)
	_check("and following it makes no object", after == objects, "%d -> %d" % [objects, after])
	_mouse(start + BOX_HALF, false)
	await _frames(2)
