extends SceneTree
## The camera's modes (decision 0801, feature #60) on the REAL scene with REAL Viewport input: bookmarks saved and
## recalled by their keys, End following a selected resident and a pan breaking it, Shift+O orbiting the hall and Esc
## stopping it (and nothing else), Shift+U's cutaway angle in the U view and back, the edge pan (over the world, not
## over the HUD, after its dwell, its band in logical pixels), the middle drag per logical pixel, and the same framing
## at this size as at 4K. Not discovered by the runner: test/test_demo_camera_live.gd runs it in its own process, as
## the other live harnesses are (decision 0261), because only an in-tree scene takes Viewport input.
##
##     godot --headless --path godot --script res://test/live/demo_camera_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves a frame of each mode as a PNG)
##
## Prints `LIVE <size> <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any
## failure.

const Bookmarks := preload("res://demo/camera/camera_bookmarks.gd")
const DemoCamera := preload("res://demo/camera/demo_camera.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
const HALL: Vector3 = Vector3(0.0, 0.0, -13.0)
## A frame cap for a wait on real time (a loaded machine runs few frames a second).
const WAIT_CAP_FRAMES: int = 600
## For the frames only: tunnels to lay (start, end, m) and the 4x frames to dig them in, so the cutaway has a network.
const DIG_ROUTES: Array[Vector4] = [Vector4(6.0, 9.5, -2.0, 9.5), Vector4(-8.0, 4.5, -8.0, -3.0)]
const DIG_FRAMES: int = 2400

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0
## camera_modes.gd's constants, read from the village's node at run time: its script preloads the HUD shell, which
## names the GameManager autoload, so a main-loop script cannot preload it.
var _mode_consts: Dictionary = {}


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
	Bookmarks.clear()
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_run.call_deferred()


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	_manager().call(&"pause_game")
	_mode_consts = (_modes().get_script() as GDScript).get_script_constant_map()
	await _bookmarks()
	await _follow()
	await _orbit()
	await _cutaway()
	await _follow_button()
	await _strip_clear_of_the_news()
	await _edge_pan()
	await _drag_turn()
	await _same_framing_at_4k()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------------

func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _seconds(seconds: float) -> void:
	"""Wait at least `seconds` of real time (capped in frames)."""
	var start: int = Time.get_ticks_msec()
	var frames: int = 0
	while Time.get_ticks_msec() - start < int(seconds * 1000.0) and frames < WAIT_CAP_FRAMES:
		await _frames(1)
		frames += 1


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless), without the pause card over the world."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var card: CanvasLayer = _village.get("_card")
	card.visible = false
	await _frames(3)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	card.visible = true
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _c(constant: StringName) -> Variant:
	"""One of camera_modes.gd's constants."""
	return _mode_consts[constant]


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _modes() -> Node:
	"""The camera's modes."""
	return _village.call(&"camera_modes")


func _rig() -> Node3D:
	"""The camera rig."""
	return _village.get("_camera")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _tool() -> Node:
	"""The Dig tool (the U view's owner)."""
	return _command().call(&"tunnels")


func _strip_text() -> String:
	"""What the camera strip says."""
	return _modes().get("strip").call(&"text")


func _key(code: Key, shift: bool = false, ctrl: bool = false) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event)


func _hold(code: Key, down: bool) -> void:
	"""Press or release one key."""
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event)


func _move(at: Vector2, mask: int = 0, relative: Vector2 = Vector2.ZERO) -> void:
	"""Move the pointer to `at` (with buttons `mask` held, by `relative`)."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.relative = relative
	motion.button_mask = mask
	root.push_input(motion)


func _go(at: Vector3, distance: float = DemoCamera.DISTANCE_DEFAULT) -> void:
	"""Put the camera over `at` at once (a step's starting view)."""
	_rig().call(&"aim", at, 0.0, DemoCamera.PITCH_DEFAULT_DEGREES, distance)
	_rig().call(&"snap")
	await _frames(2)


# --- the steps ----------------------------------------------------------------------------------------------

func _bookmarks() -> void:
	"""Ctrl+Shift+1 saves the view; away from it, Shift+1 eases back; Shift+3 (empty) says how to fill it."""
	await _go(Vector3(6.0, 0.0, 4.0))
	_key(KEY_1, true, true)
	await _frames(SETTLE_FRAMES)
	_check("bookmark: Ctrl+Shift+1 saved the view", Bookmarks.has(1) and Bookmarks.focus_of(1).is_equal_approx(
		Vector3(6.0, 0.0, 4.0)), str(Bookmarks.focus_of(1)))
	_check("bookmark: the strip says so", _strip_text() == _c(&"SAVED_TEXT") % [1, 1], _strip_text())
	await _capture("camera_bookmark_saved")
	await _go(Vector3(-12.0, 0.0, -10.0), 40.0)
	_key(KEY_1, true)
	await _seconds(1.0)
	var at: Vector3 = _rig().call(&"focus")
	_check("bookmark: Shift+1 went back", at.distance_to(Vector3(6.0, 0.0, 4.0)) < 0.2, str(at))
	_check("bookmark: at its distance", absf(float(_rig().call(&"distance")) - DemoCamera.DISTANCE_DEFAULT) < 0.5,
		str(_rig().call(&"distance")))
	_key(KEY_3, true)
	await _frames(SETTLE_FRAMES)
	_check("bookmark: an empty one says how", _strip_text() == _c(&"EMPTY_TEXT") % [3, 3], _strip_text())
	_key(KEY_1)
	await _frames(SETTLE_FRAMES)
	_check("bookmark: plain 1 is not a bookmark", _strip_text() == _c(&"EMPTY_TEXT") % [3, 3], _strip_text())


func _follow() -> void:
	"""Resident 0 selected, End follows them while the village runs; a held pan breaks it."""
	_command().call(&"select", PackedInt32Array([0]))
	await _frames(SETTLE_FRAMES)
	_key(KEY_END)
	await _frames(SETTLE_FRAMES)
	_check("follow: End follows the selected resident", int(_modes().call(&"followed")) == 0)
	_check("follow: the strip names them", _strip_text().begins_with("Following "), _strip_text())
	_manager().call(&"resume_game")
	await _seconds(1.5)
	_manager().call(&"pause_game")
	var feet: Vector3 = _village.call(&"resident_point", 0)
	var aim: Vector3 = _rig().call(&"target_focus")
	_check("follow: the view's centre is on them", Vector2(aim.x - feet.x, aim.z - feet.z).length() < 0.5,
		"%s vs %s" % [aim, feet])
	await _seconds(1.0)
	await _capture("camera_follow")
	_hold(KEY_A, true)
	await _frames(SETTLE_FRAMES)
	_hold(KEY_A, false)
	await _frames(SETTLE_FRAMES)
	_check("follow: a pan breaks it", int(_modes().call(&"followed")) == -1)
	_check("follow: and says so", _strip_text().begins_with("Stopped following"), _strip_text())


func _orbit() -> void:
	"""Over the hall, Shift+O orbits it; the view turns; Esc stops it and does nothing else."""
	await _go(HALL + Vector3(2.0, 0.0, 2.0))
	_key(KEY_O, true)
	await _frames(SETTLE_FRAMES)
	_check("orbit: Shift+O orbits the hall", String(_modes().call(&"orbit_name")) == "the hall",
		String(_modes().call(&"orbit_name")))
	var yaw: float = _rig().call(&"target_yaw_degrees")
	await _seconds(1.5)
	var turned: float = float(_rig().call(&"target_yaw_degrees")) - yaw
	_check("orbit: the view turns round it, slowly", turned > 3.0 and turned < 30.0, "%.1f degrees" % turned)
	await _capture("camera_orbit_a")
	await _seconds(3.0)
	await _capture("camera_orbit_b")
	await _esc_ladder_with_a_dig_piece()
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("orbit: Esc stops it", int(_modes().get("mode")) == _c(&"MODE_FREE"))
	_check("orbit: the selection is kept", _command().call(&"selected") == PackedInt32Array([0]),
		str(_command().call(&"selected")))
	_check("orbit: the game menu did not open", not bool(_village.call(&"menu").get("visible")))
	await _esc_with_no_orbit()


func _esc_ladder_with_a_dig_piece() -> void:
	"""During the orbit, with the Dig tool open and a point laid: Esc drops the point and a second closes the tool --
	the tool's rungs of the ladder come before the orbit's -- and the orbit turns on."""
	var tool: Node = _tool()
	tool.call(&"begin_plan")
	await _frames(2)
	tool.call(&"lay_ground", Vector2(6.0, 9.5))
	await _frames(2)
	_check("ladder: a point laid in the Dig tool", int(tool.get("plan").get("count")) >= 1)
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("ladder: Esc drops the tool's point first", int(tool.get("plan").get("count")) == 0
		and int(_modes().get("mode")) == _c(&"MODE_ORBIT"))
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("ladder: then closes the tool, still orbiting", not bool(tool.get("planning"))
		and int(_modes().get("mode")) == _c(&"MODE_ORBIT"))


func _esc_with_no_orbit() -> void:
	"""With no orbit, Esc keeps its ladder: it clears the selection, then opens the game menu, then closes it."""
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("ladder: no orbit, Esc clears the selection", (_command().call(&"selected") as PackedInt32Array).is_empty())
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	var menu: Node = _village.call(&"menu")
	_check("ladder: then opens the game menu", bool(menu.get("visible")))
	_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("ladder: and Esc closes it", not bool(menu.get("visible")))
	_manager().call(&"pause_game")
	_command().call(&"select", PackedInt32Array([0]))


func _cutaway() -> void:
	"""Shift+U shows the U view at the cutaway angle; Shift+U again gives the angle back; U leaves the view."""
	if not _capture_dir.is_empty():
		await _dig_for_the_frames()
	await _go(Vector3(0.0, 0.0, 4.0))
	var pitch: float = _rig().call(&"target_pitch_degrees")
	_key(KEY_U, true)
	await _frames(SETTLE_FRAMES)
	_check("cutaway: the U view is on", bool(_tool().get("view").get("on")))
	_check("cutaway: at the cutaway pitch", is_equal_approx(float(_rig().call(&"target_pitch_degrees")),
		_c(&"CUTAWAY_PITCH_DEGREES")), str(_rig().call(&"target_pitch_degrees")))
	await _seconds(1.0)
	await _capture("camera_cutaway")
	_key(KEY_U, true)
	await _frames(SETTLE_FRAMES)
	_check("cutaway: Shift+U again, your angle back", is_equal_approx(float(_rig().call(&"target_pitch_degrees")),
		pitch), str(_rig().call(&"target_pitch_degrees")))
	_check("cutaway: the U view stays", bool(_tool().get("view").get("on")))
	_key(KEY_U)
	await _frames(SETTLE_FRAMES)
	_check("cutaway: U leaves the view", not bool(_tool().get("view").get("on")))


func _follow_button() -> void:
	"""The party panel's Follow (End): a real click follows the selected resident and the button says Stop following;
	a second click stops it."""
	_command().call(&"select", PackedInt32Array([0]))
	_command().call(&"_refresh_panel")
	await _frames(SETTLE_FRAMES)
	var button: Button = _command().call(&"panel").call(&"follow_button")
	_check("follow button: shown with a resident selected", button != null and button.is_visible_in_tree())
	if button == null:
		return
	_click(button.get_global_rect().get_center())
	await _frames(SETTLE_FRAMES)
	_check("follow button: a click follows them", int(_modes().call(&"followed")) == 0)
	_check("follow button: and says Stop following", button.text.begins_with("Stop following"), button.text)
	_click(button.get_global_rect().get_center())
	await _frames(SETTLE_FRAMES)
	_check("follow button: a second click stops", int(_modes().call(&"followed")) == -1 and button.text.begins_with(
		"Follow"), button.text)


func _strip_clear_of_the_news() -> void:
	"""Following, with three news lines up: the news stands on top of the strip's row, never over it -- on the surface
	and in the U view."""
	var notices: Object = _village.get("_services").get("notices")
	var consts: Dictionary = (notices.get_script() as GDScript).get_script_constant_map()
	for k: int in 3:
		notices.call(&"post", consts["SOURCE_FARM"], consts["LEVEL_WARNING"], "A long warning line %d for the frame" % k)
	_key(KEY_END)
	await _seconds(0.8)
	_check_strip_clear("surface")
	await _capture("camera_strip_and_news")
	_key(KEY_U)
	await _seconds(0.8)
	_check_strip_clear("U view")
	await _capture("camera_strip_and_news_u")
	_key(KEY_U)
	_key(KEY_END)
	await _frames(SETTLE_FRAMES)
	await _long_line_at_125()


func _long_line_at_125() -> void:
	"""With the interface at 125 %, a long line stays inside the gap between the minimap and the right column: cut to it
	at 1280x720 (500 logical px), whole at 1920x1080."""
	DemoUiScale.apply(125, root)
	var strip: Node = _modes().get("strip")
	strip.call(&"set_mode_text", "Following Wenna Tallowby-Highbough-Whitethorn of the Long Name · End or a pan stops")
	await _frames(SETTLE_FRAMES)
	var at: Rect2 = strip.call(&"rect")
	var geometry: Object = strip.get("_geometry")
	var s: float = float(geometry.get("scale"))
	var low: float = ((geometry.get("minimap") as Rect2).end.x + 6.0) * s
	var high: float = ((geometry.get("detail") as Rect2).position.x - 6.0) * s
	var cut: bool = bool(strip.call(&"clipped"))
	_check("long line: inside the gap between the minimap and the right column, cut only where it must be",
		at.position.x >= low - 0.5 and at.end.x <= high + 0.5 and cut == (_size.y < 1080),
		"%s in %.0f..%.0f, cut %s" % [at, low, high, cut])
	strip.call(&"set_mode_text", "")
	DemoUiScale.apply(100, root)
	await _frames(SETTLE_FRAMES)


func _check_strip_clear(where: String) -> void:
	"""The camera strip shows, the news shows, and the news ends above the strip's top."""
	var strip: Rect2 = _modes().get("strip").call(&"rect")
	var news: CanvasLayer = _village.get("_news")
	var frame: Rect2 = news.call(&"frame_rect")
	_check("strip and news (%s): both shown" % where, bool(_modes().get("strip").call(&"shown"))
		and bool(news.call(&"is_shown")))
	_check("strip and news (%s): the news stands above the strip" % where, frame.end.y <= strip.position.y + 0.5
		and not frame.intersects(strip), "news %s, strip %s" % [frame, strip])


func _click(at: Vector2) -> void:
	"""A left click at `at` through the Viewport."""
	_move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)


func _dig_for_the_frames() -> void:
	"""Lay the tunnels the Dig tool takes and dig them at 4x, so the cutaway's frame shows a network (frames only). The
	village runs while they are laid: a resident standing on a new entrance steps off it (the tool refuses it till then)."""
	var tool: Node = _tool()
	_manager().call(&"resume_game")
	for route: Vector4 in DIG_ROUTES:
		tool.call(&"begin_plan")
		await _frames(2)
		tool.call(&"lay_ground", Vector2(route.x, route.y))
		tool.call(&"lay_ground", Vector2(route.z, route.w))
		await _frames(2)
		for attempt: int in 300:
			if bool(tool.call(&"confirm")):
				break
			await _frames(1)
		tool.get("plan").call(&"clear")
		tool.call(&"cancel_plan")
	_manager().call(&"set_speed", 4)
	await _frames(DIG_FRAMES)
	_manager().call(&"set_speed", 1)
	_manager().call(&"pause_game")


func _edge_pan() -> void:
	"""Over the world at an edge the view pans after its dwell; over the HUD at an edge it does not; the band is 12
	logical pixels."""
	var edge: Node = _modes().get("edge")
	edge.set("focused", func() -> bool: return true)
	await _go(Vector3.ZERO)
	var spot: Vector2 = _free_edge_spot()
	_check("edge: a spot at an edge over the world", spot.x >= 0.0, str(spot))
	if spot.x < 0.0:
		return
	_move(spot)
	await _seconds(0.6)
	var moved: Vector3 = _rig().call(&"target_focus")
	_check("edge: resting there pans the view", moved.length() > 0.2, str(moved))
	var hud: Vector2 = _grid_spot(true)
	_move(hud)
	await _frames(1)
	_check("edge: off over the HUD", hud.x >= 0.0 and not bool(edge.call(&"allowed")), "at %s" % hud)
	_move(_grid_spot(false))
	await _frames(1)
	_check("edge: on over the world", bool(edge.call(&"allowed")))
	var field := LineEdit.new()
	field.position = Vector2(_size) * 0.5
	root.add_child(field)
	field.grab_focus()
	await _frames(1)
	_check("edge: off while a text field has the focus", not bool(edge.call(&"allowed")))
	field.queue_free()
	await _frames(1)
	var band: float = edge.call(&"band_px", Vector2(_size))
	_check("edge: the band is 12 logical px", is_equal_approx(band, 12.0 * DemoUiScale.effective_scale(Vector2(_size))),
		"%.1f px" % band)
	edge.set("focused", Callable())
	if DisplayServer.get_name() == "headless":
		_move(spot)
		_check("edge: never in a headless run on its own word", not bool(edge.call(&"allowed")))
	_move(Vector2(_size) * 0.5)
	await _frames(SETTLE_FRAMES)


func _free_edge_spot() -> Vector2:
	"""A point just inside an edge's band that no HUD control takes (-1, -1: none found)."""
	var w: float = float(_size.x)
	var h: float = float(_size.y)
	var candidates: Array[Vector2] = []
	for f: float in [0.45, 0.55, 0.35, 0.65, 0.25, 0.75]:
		candidates.append(Vector2(w * f, 2.0))
		candidates.append(Vector2(w * f, h - 2.0))
		candidates.append(Vector2(2.0, h * f))
		candidates.append(Vector2(w - 2.0, h * f))
	for at: Vector2 in candidates:
		_move(at)
		if root.gui_get_hovered_control() == null:
			return at
	return Vector2(-1.0, -1.0)


func _grid_spot(over_hud: bool) -> Vector2:
	"""A point on a coarse grid over the window, away from its edges, that a HUD control takes (or that none does);
	(-1, -1): none found."""
	for row: int in range(1, 10):
		for column: int in range(1, 10):
			var at := Vector2(float(_size.x) * float(column) / 10.0, float(_size.y) * float(row) / 10.0)
			_move(at)
			if (root.gui_get_hovered_control() != null) == over_hud:
				return at
	return Vector2(-1.0, -1.0)


func _drag_turn() -> void:
	"""A middle drag of 100 physical px turns the view by 100 logical px' worth: S at this size, with the interface at
	125 % (so S is never 1 here)."""
	DemoUiScale.apply(125, root)
	await _go(Vector3.ZERO)
	var spot: Vector2 = _grid_spot(false)
	_move(spot)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = spot
	press.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(press)
	var yaw: float = _rig().call(&"target_yaw_degrees")
	_move(spot + Vector2(100.0, 0.0), MOUSE_BUTTON_MASK_MIDDLE, Vector2(100.0, 0.0))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.position = spot + Vector2(100.0, 0.0)
	root.push_input(release)
	await _frames(SETTLE_FRAMES)
	var turned: float = yaw - float(_rig().call(&"target_yaw_degrees"))
	var expected: float = 100.0 * DemoCamera.DRAG_YAW_DEGREES_PER_PX / DemoUiScale.effective_scale(Vector2(_size))
	_check("drag: per logical pixel", absf(turned - expected) < 0.01 and expected < 30.0,
		"%.2f vs %.2f degrees" % [turned, expected])
	DemoUiScale.apply(100, root)
	await _frames(SETTLE_FRAMES)


func _same_framing_at_4k() -> void:
	"""The hall's door, seen from the same view, sits at the same place on the screen (as a fraction of it) here
	and at 3840x2160: one vertical field of view, KEEP_HEIGHT, at both."""
	await _go(Vector3.ZERO)
	var camera: Camera3D = root.get_camera_3d()
	var here: Vector2 = camera.unproject_position(HALL) / Vector2(_size)
	var size: Vector2i = _size
	_size = Vector2i(3840, 2160)
	await _frames(2)
	var there: Vector2 = camera.unproject_position(HALL) / Vector2(_size)
	_size = size
	await _frames(2)
	_check("feel: the same framing at 4K", here.distance_to(there) < 0.002, "%s vs %s" % [here, there])
