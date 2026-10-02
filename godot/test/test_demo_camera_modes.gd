extends "res://test/framework/test_case.gd"
## Coverage for the camera's modes (decision 0801, feature #60): the bookmarks (camera_bookmarks.gd), follow, orbit and
## the cutaway angle (camera_modes.gd), the edge pan (edge_pan.gd) and the strip (camera_strip.gd), over a real rig
## (demo_camera.gd) off the tree. The village is stood in for by Callables: a resident who stands where the test says,
## a U view the test switches, a network extent the test gives. `_process` and the rig's `step` are called by hand.

const DemoCamera := preload("res://demo/camera/demo_camera.gd")
const Modes := preload("res://demo/camera/camera_modes.gd")
const Bookmarks := preload("res://demo/camera/camera_bookmarks.gd")
const EdgePan := preload("res://demo/camera/edge_pan.gd")
const Strip := preload("res://demo/camera/camera_strip.gd")
const Graph := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Access := preload("res://demo/access/demo_access.gd")
const SettingsUi := preload("res://demo/access/access_settings_ui.gd")
const PartyPanel := preload("res://demo/control/demo_party_panel.gd")
const NewsStrip := preload("res://demo/ui/demo_news_strip.gd")
const Services := preload("res://demo/demo_services.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Sizes := preload("res://demo/world/world_sizes.gd")

const VILLAGE: AABB = AABB(Vector3(-30.0, 0.0, -30.0), Vector3(60.0, 0.0, 60.0))
const FRAME: float = 1.0 / 60.0
const SETTLE: float = 5.0
const HALL: Vector3 = Vector3(0.0, 0.0, -13.0)
const SIZE_720: Vector2 = Vector2(1280.0, 720.0)
const SIZE_1080: Vector2 = Vector2(1920.0, 1080.0)
const SIZE_4K: Vector2 = Vector2(3840.0, 2160.0)

var _rig: DemoCamera = null
var _modes: Modes = null
var _selected: int = -1
var _at: Vector3 = Vector3(5.0, 0.0, 5.0)
var _under: bool = false
var _modal: bool = false
var _extent: Rect2 = Rect2(0.0, 0.0, -1.0, -1.0)


func before_each() -> void:
	"""A rig over the village and the modes on it, with nobody selected, the surface shown and no modal."""
	Bookmarks.clear()
	Access.reset()
	DemoMotion.reduced = false
	DemoUiScale.percent = 100
	_selected = -1
	_at = Vector3(5.0, 0.0, 5.0)
	_under = false
	_modal = false
	_extent = Rect2(0.0, 0.0, -1.0, -1.0)
	_rig = DemoCamera.new()
	_rig.configure(VILLAGE, Vector3.ZERO)
	_modes = Modes.new()
	_modes.primary = func() -> int: return _selected
	_modes.resident_point = func(who: int) -> Vector3: return _at if who == 3 else Vector3.INF
	_modes.resident_name = func(who: int) -> String: return "Wenna Tallowby" if who == 3 else ""
	_modes.modal_open = func() -> bool: return _modal
	_modes.underground = func() -> bool: return _under
	_modes.set_underground = func(on: bool) -> void: _under = on
	_modes.tunnel_extent = func() -> Rect2: return _extent
	_modes.configure(_rig)


func after_each() -> void:
	"""Free the modes and the rig; leave the statics as found."""
	_modes.free()
	_rig.free()
	Bookmarks.clear()
	Access.reset()
	DemoMotion.reduced = false


# --- helpers --------------------------------------------------------------------------------------------------

func _key(code: Key, shift: bool = false, ctrl: bool = false, alt: bool = false) -> InputEventKey:
	"""A pressed key (physical), with modifiers."""
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt
	return event


func _held(action: StringName, pressed: bool) -> InputEventAction:
	"""An action press or release for the rig."""
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _frames(seconds: float) -> void:
	"""Run the modes then the rig for `seconds`, a frame at a time (the modes run first, as in the tree)."""
	for k: int in int(seconds / FRAME):
		_modes._process(FRAME)
		_rig.step(FRAME)


func _end() -> InputEventKey:
	"""End, as the project binds camera_follow."""
	return _key(KEY_END)


# --- bookmarks ------------------------------------------------------------------------------------------------

func test_the_slots_are_one_to_four() -> void:
	"""Slots 1..4 only; a save to any other is refused."""
	assert_false(Bookmarks.is_slot(0), "0 is not one")
	assert_true(Bookmarks.is_slot(1) and Bookmarks.is_slot(Bookmarks.SLOTS), "1 and 4 are")
	assert_false(Bookmarks.is_slot(Bookmarks.SLOTS + 1), "5 is not")
	assert_false(Bookmarks.save(0, Vector3.ONE, 0.0, 50.0, 20.0), "refused")
	assert_false(Bookmarks.save(5, Vector3.ONE, 0.0, 50.0, 20.0), "refused")
	assert_equal(Bookmarks.count(), 0, "nothing kept")


func test_a_slot_keeps_its_view_until_cleared() -> void:
	"""What is saved is read back; an empty slot reads nothing; clear forgets every one."""
	assert_false(Bookmarks.has(2), "empty")
	assert_equal(Bookmarks.focus_of(2), Vector3.INF, "no centre")
	assert_almost_equal(Bookmarks.yaw_of(2) + Bookmarks.pitch_of(2) + Bookmarks.distance_of(2), 0.0, "no view")
	assert_true(Bookmarks.save(2, Vector3(3.0, 7.0, -4.0), 45.0, 60.0, 30.0), "saved")
	assert_true(Bookmarks.has(2), "held")
	assert_equal(Bookmarks.focus_of(2), Vector3(3.0, 0.0, -4.0), "centre, on the ground")
	assert_almost_equal(Bookmarks.yaw_of(2), 45.0, "heading")
	assert_almost_equal(Bookmarks.pitch_of(2), 60.0, "pitch")
	assert_almost_equal(Bookmarks.distance_of(2), 30.0, "distance")
	assert_equal(Bookmarks.count(), 1, "one")
	Bookmarks.clear()
	assert_false(Bookmarks.has(2), "forgotten")


func test_ctrl_shift_digit_saves_and_shift_digit_goes_back() -> void:
	"""Ctrl+Shift+2 keeps the view the camera is going to; after moving away, Shift+2 eases back to it."""
	_rig.aim(Vector3(6.0, 0.0, -2.0), 30.0, 55.0, 18.0)
	assert_true(_modes.handle_key(_key(KEY_2, true, true)), "Ctrl+Shift+2 is the modes'")
	assert_true(Bookmarks.has(2), "saved")
	assert_equal(_modes.strip.text(), Modes.SAVED_TEXT % [2, 2], "and said")
	_rig.aim(Vector3(-8.0, 0.0, 9.0), 200.0, 40.0, 40.0)
	_rig.step(SETTLE)
	assert_true(_modes.handle_key(_key(KEY_2, true)), "Shift+2 is the modes'")
	_rig.step(FRAME)
	assert_true(_rig.focus().distance_to(Vector3(6.0, 0.0, -2.0)) > 0.1, "eased, not jumped")
	_rig.step(SETTLE)
	assert_true(_rig.focus().is_equal_approx(Vector3(6.0, 0.0, -2.0)), "back at its centre")
	assert_almost_equal(fposmod(_rig.yaw_degrees(), 360.0), 30.0, "its heading")
	assert_almost_equal(_rig.pitch_degrees(), 55.0, "its pitch")
	assert_almost_equal(_rig.distance(), 18.0, "its distance")
	assert_equal(_modes.strip.text(), Modes.RECALL_TEXT % 2, "said")


func test_an_empty_slot_says_how_to_fill_it() -> void:
	"""Shift+3 with nothing in 3 moves nothing and says Ctrl+Shift+3 saves one."""
	var before: Vector3 = _rig.target_focus()
	assert_true(_modes.handle_key(_key(KEY_3, true)), "the modes' key still")
	assert_equal(_rig.target_focus(), before, "nothing moved")
	assert_equal(_modes.strip.text(), Modes.EMPTY_TEXT % [3, 3], "says how")


func test_with_reduced_motion_a_bookmark_lands_at_once() -> void:
	"""Reduced motion: the first frame is at the bookmark (no easing)."""
	Bookmarks.save(1, Vector3(9.0, 0.0, 9.0), 90.0, 60.0, 25.0)
	DemoMotion.reduced = true
	_modes.handle_key(_key(KEY_1, true))
	_rig.step(FRAME)
	assert_true(_rig.focus().is_equal_approx(Vector3(9.0, 0.0, 9.0)), "there at once")
	assert_almost_equal(_rig.pitch_degrees(), 60.0, "pitch at once")


func test_other_digit_chords_are_not_bookmarks() -> void:
	"""Plain digits (the groups' recall), Ctrl+digit (their assign), Alt or Cmd with Shift, digit 5 and 0, and a key
	repeat are left alone."""
	assert_false(_modes.handle_key(_key(KEY_1)), "1 is group recall")
	assert_false(_modes.handle_key(_key(KEY_1, false, true)), "Ctrl+1 is group assign")
	assert_false(_modes.handle_key(_key(KEY_1, true, false, true)), "Alt+Shift+1")
	var meta := _key(KEY_1, true)
	meta.meta_pressed = true
	assert_false(_modes.handle_key(meta), "Cmd+Shift+1")
	assert_false(_modes.handle_key(_key(KEY_5, true)), "Shift+5")
	assert_false(_modes.handle_key(_key(KEY_0, true)), "Shift+0")
	var echo := _key(KEY_1, true, true)
	echo.echo = true
	assert_false(_modes.handle_key(echo), "a repeat")
	assert_equal(Bookmarks.count(), 0, "nothing saved")


func test_no_key_works_behind_a_modal() -> void:
	"""With a modal open none of the modes' keys does anything."""
	_modal = true
	_selected = 3
	for event: InputEventKey in [_end(), _key(KEY_1, true, true), _key(KEY_O, true), _key(KEY_U, true)]:
		assert_false(_modes.handle_key(event), "%s blocked" % event.as_text())
	assert_equal(_modes.mode, Modes.MODE_FREE, "no mode")
	assert_false(_under, "no U view")


# --- follow ---------------------------------------------------------------------------------------------------

func test_end_with_nobody_selected_says_so() -> void:
	"""End with no resident selected follows nobody and says how."""
	assert_true(_modes.handle_key(_end()), "End is the modes'")
	assert_equal(_modes.mode, Modes.MODE_FREE, "no follow")
	assert_equal(_modes.strip.text(), Modes.FOLLOW_NONE, "says how")


func test_end_follows_the_selected_resident_as_they_walk() -> void:
	"""End follows the primary selected resident: the centre eases after them as they move; the strip names them."""
	_selected = 3
	_modes.handle_key(_end())
	assert_equal(_modes.followed(), 3, "following 3")
	assert_equal(_modes.strip.text(), Modes.FOLLOW_TEXT % "Wenna Tallowby", "named")
	_frames(SETTLE)
	assert_true(_rig.focus().is_equal_approx(_at), "over them")
	_at = Vector3(-6.0, 0.0, 2.0)
	_frames(FRAME)
	assert_true(_rig.focus().distance_to(_at) > 0.1, "eases after them")
	_frames(SETTLE)
	assert_true(_rig.focus().is_equal_approx(_at), "caught up")


func test_with_reduced_motion_the_follow_holds_them_without_easing() -> void:
	"""Reduced motion: each frame's centre is the resident's place that frame."""
	DemoMotion.reduced = true
	_selected = 3
	_modes.handle_key(_end())
	_frames(FRAME)
	assert_true(_rig.focus().is_equal_approx(_at), "on them")
	_at = Vector3(1.0, 0.0, -9.0)
	_frames(FRAME)
	assert_true(_rig.focus().is_equal_approx(_at), "still on them, no lag")


func test_a_pan_breaks_the_follow_and_turning_zooming_do_not() -> void:
	"""Q, the wheel and a tilt leave the follow on; a held pan ends it, where the view is, and says so."""
	_selected = 3
	_modes.handle_key(_end())
	_rig.handle_input(_held(DemoCamera.ACTION_ROTATE_LEFT, true))
	_frames(0.2)
	_rig.handle_input(_held(DemoCamera.ACTION_ROTATE_LEFT, false))
	_rig.handle_input(_held(DemoCamera.ACTION_ZOOM_IN, true))
	_rig.handle_input(_held(DemoCamera.ACTION_PITCH_UP, true))
	_frames(0.2)
	assert_equal(_modes.mode, Modes.MODE_FOLLOW, "still following")
	_rig.handle_input(_held(DemoCamera.ACTION_PAN_LEFT, true))
	_frames(0.2)
	assert_equal(_modes.mode, Modes.MODE_FREE, "the pan ended it")
	assert_equal(_modes.strip.text(), Modes.FOLLOW_STOPPED % "Wenna Tallowby", "and said so")
	_rig.handle_input(_held(DemoCamera.ACTION_PAN_LEFT, false))
	var left: Vector3 = _rig.target_focus()
	_at = Vector3(10.0, 0.0, 10.0)
	_frames(0.5)
	assert_equal(_rig.target_focus(), left, "no longer after them")


func test_a_go_to_breaks_the_follow() -> void:
	"""centre_on (the minimap, the roster, a Go to) is the player's pan: the follow ends."""
	_selected = 3
	_modes.handle_key(_end())
	_frames(FRAME)
	_rig.centre_on(Vector3(-10.0, 0.0, -10.0))
	_frames(FRAME)
	assert_equal(_modes.mode, Modes.MODE_FREE, "ended")


func test_end_on_a_resident_who_is_nowhere_says_so() -> void:
	"""A selected resident who stands nowhere (gone) is not followed; End says how, as with nobody selected."""
	_selected = 3
	_at = Vector3.INF
	assert_false(_modes.toggle_follow(), "no follow")
	assert_equal(_modes.strip.text(), Modes.FOLLOW_NONE, "says how")


func test_end_again_stops_and_a_vanished_resident_ends_it() -> void:
	"""End toggles the follow off; a resident who is no longer anywhere ends it too."""
	_selected = 3
	_modes.handle_key(_end())
	assert_false(_modes.toggle_follow(), "End again: off")
	assert_equal(_modes.followed(), -1, "nobody")
	_modes.handle_key(_end())
	_at = Vector3.INF
	_frames(FRAME)
	assert_equal(_modes.mode, Modes.MODE_FREE, "gone: ended")


# --- orbit ----------------------------------------------------------------------------------------------------

func test_shift_o_orbits_the_building_in_view() -> void:
	"""Near the hall, Shift+O frames the hall at the orbit's pitch and a distance fitted to it, names it, and turns
	round it at the orbit's rate."""
	_rig.aim(HALL + Vector3(3.0, 0.0, 2.0), 0.0, 50.0, 22.0)
	assert_true(_modes.handle_key(_key(KEY_O, true)), "Shift+O is the modes'")
	assert_equal(_modes.mode, Modes.MODE_ORBIT, "orbiting")
	assert_equal(_modes.orbit_name(), "the hall", "the hall")
	assert_equal(_modes.strip.text(), Modes.ORBIT_TEXT % "the hall", "said")
	assert_equal(_rig.target_focus(), HALL, "centred on it")
	assert_almost_equal(_rig.target_pitch_degrees(), Modes.ORBIT_PITCH_DEGREES, "low and cinematic")
	var buildings := PackedVector3Array()
	Modes.village_buildings(buildings, PackedStringArray())
	assert_almost_equal(_rig.target_distance(), Modes.orbit_distance(buildings[0].z), "fitted to it")
	var yaw: float = _rig.target_yaw_degrees()
	_frames(1.0)
	assert_almost_equal(_rig.target_yaw_degrees() - yaw, Modes.ORBIT_DEGREES_PER_SECOND * float(int(1.0 / FRAME)) * FRAME,
		"six degrees a second")


func test_far_from_any_building_the_orbit_turns_round_the_centre() -> void:
	"""Out in the woods the orbit keeps the centre and the distance, and says so."""
	_rig.aim(Vector3(-28.0, 0.0, 28.0), 0.0, 50.0, 22.0)
	_modes.toggle_orbit()
	assert_equal(_modes.orbit_name(), Modes.CENTRE_WORDS, "the view's centre")
	assert_equal(_rig.target_focus(), Vector3(-28.0, 0.0, 28.0), "where it was")
	assert_almost_equal(_rig.target_distance(), 22.0, "as far")


func test_esc_shift_o_a_pan_or_a_turn_stops_the_orbit_and_zoom_does_not() -> void:
	"""Zoom and tilt -- the keys or a middle drag straight up -- adjust the orbit; Esc stops it (the command layer's
	input hook takes it), as do Shift+O, a pan and a turn."""
	_modes.toggle_orbit()
	_rig.handle_input(_held(DemoCamera.ACTION_ZOOM_OUT, true))
	_rig.handle_input(_held(DemoCamera.ACTION_PITCH_DOWN, true))
	var up := InputEventMouseMotion.new()
	up.relative = Vector2(0.0, -40.0)
	up.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	_rig.handle_input(middle)
	_rig.handle_input(up)
	_frames(0.2)
	assert_equal(_modes.mode, Modes.MODE_ORBIT, "zoom and tilt keep it")
	assert_true(_modes.escape_hook(_key(KEY_ESCAPE)), "Esc is taken")
	assert_equal(_modes.mode, Modes.MODE_FREE, "Esc")
	assert_equal(_modes.strip.text(), Modes.ORBIT_STOPPED, "said")
	_modes.toggle_orbit()
	_modes.handle_key(_key(KEY_O, true))
	assert_equal(_modes.mode, Modes.MODE_FREE, "Shift+O")
	_modes.toggle_orbit()
	_rig.handle_input(_held(DemoCamera.ACTION_ROTATE_RIGHT, true))
	_frames(0.1)
	assert_equal(_modes.mode, Modes.MODE_FREE, "a turn")
	_rig.handle_input(_held(DemoCamera.ACTION_ROTATE_RIGHT, false))
	_modes.toggle_orbit()
	_rig.handle_input(_held(DemoCamera.ACTION_PAN_BACK, true))
	_frames(0.1)
	assert_equal(_modes.mode, Modes.MODE_FREE, "a pan")


func test_esc_without_an_orbit_is_left_for_the_ladder() -> void:
	"""Esc with no orbit (or behind a modal), and any other key during one, is not the modes': the hook leaves it for
	the selection or the menu."""
	assert_false(_modes.escape_hook(_key(KEY_ESCAPE)), "nothing to stop: left")
	_modes.toggle_orbit()
	assert_false(_modes.escape_hook(_key(KEY_A)), "another key: left")
	var echo := _key(KEY_ESCAPE)
	echo.echo = true
	assert_false(_modes.escape_hook(echo), "a repeat: left")
	_modal = true
	assert_false(_modes.escape_hook(_key(KEY_ESCAPE)), "behind a modal: left")
	assert_equal(_modes.mode, Modes.MODE_ORBIT, "still orbiting")


func test_follow_and_orbit_replace_each_other() -> void:
	"""Starting one ends the other; a bookmark ends either."""
	_selected = 3
	_modes.handle_key(_end())
	_modes.toggle_orbit()
	assert_equal(_modes.mode, Modes.MODE_ORBIT, "the orbit took over")
	assert_equal(_modes.followed(), -1, "no follow")
	_modes.handle_key(_end())
	assert_equal(_modes.mode, Modes.MODE_FOLLOW, "the follow took over")
	assert_equal(_modes.orbit_name(), "", "no orbit")
	Bookmarks.save(4, Vector3.ZERO, 0.0, 50.0, 22.0)
	_modes.recall_view(4)
	assert_equal(_modes.mode, Modes.MODE_FREE, "the bookmark ended it")
	_frames(FRAME)
	assert_equal(_modes.mode, Modes.MODE_FREE, "and stays ended")


# --- the cutaway angle ----------------------------------------------------------------------------------------

func test_shift_u_turns_the_u_view_on_at_the_cutaway_angle_over_the_network() -> void:
	"""From the surface, Shift+U shows the U view, at the cutaway pitch, over the network's middle, at a distance
	that fits it; the heading is kept."""
	_extent = Rect2(-10.0, 2.0, 16.0, 8.0)
	_rig.aim(Vector3(4.0, 0.0, 4.0), 30.0, 50.0, 22.0)
	assert_true(_modes.handle_key(_key(KEY_U, true)), "Shift+U is the modes'")
	assert_true(_under, "the U view is on")
	assert_true(_modes.cutaway(), "the cutaway angle is on")
	assert_almost_equal(_rig.target_pitch_degrees(), Modes.CUTAWAY_PITCH_DEGREES, "steep")
	assert_equal(_rig.target_focus(), Vector3(-2.0, 0.0, 6.0), "the network's middle")
	assert_almost_equal(_rig.target_distance(), Modes.cutaway_distance(_extent), "fits it")
	assert_almost_equal(_rig.target_yaw_degrees(), 30.0, "heading kept")
	assert_equal(_modes.strip.text(), Modes.CUTAWAY_TEXT, "said")


func test_shift_u_again_gives_your_angle_back() -> void:
	"""Shift+U again restores the pitch and distance from before, where the view is now; the U view stays."""
	_under = true
	_extent = Rect2(-20.0, -20.0, 40.0, 40.0)
	_rig.aim(Vector3.ZERO, 0.0, 44.0, 27.0)
	_modes.toggle_cutaway()
	assert_false(is_equal_approx(_rig.target_distance(), 27.0), "the cutaway moved the distance")
	assert_false(_modes.toggle_cutaway(), "off")
	assert_almost_equal(_rig.target_pitch_degrees(), 44.0, "pitch back")
	assert_almost_equal(_rig.target_distance(), 27.0, "distance back")
	assert_true(_under, "still underground")
	assert_equal(_modes.strip.text(), Modes.CUTAWAY_BACK, "said")


func test_leaving_the_u_view_gives_your_angle_back() -> void:
	"""U (the view off) with the cutaway on: the angle comes back by itself."""
	_rig.aim(Vector3.ZERO, 0.0, 44.0, 27.0)
	_modes.toggle_cutaway()
	_under = false
	_frames(FRAME)
	assert_false(_modes.cutaway(), "off")
	assert_almost_equal(_rig.target_pitch_degrees(), 44.0, "pitch back")
	assert_equal(_modes.strip.text(), "", "nothing to say")


func test_a_one_node_network_is_still_framed() -> void:
	"""A network of one point (a mouth just laid) is centred on, from the cutaway's least distance."""
	_extent = Rect2(7.0, -3.0, 0.0, 0.0)
	_modes.toggle_cutaway()
	assert_equal(_rig.target_focus(), Vector3(7.0, 0.0, -3.0), "centred on it")
	assert_almost_equal(_rig.target_distance(), Modes.CUTAWAY_MIN_M, "the least distance")


func test_with_no_network_the_cutaway_keeps_the_centre_and_distance() -> void:
	"""No tunnel on the level: only the pitch changes."""
	_rig.aim(Vector3(3.0, 0.0, 3.0), 0.0, 50.0, 25.0)
	_modes.toggle_cutaway()
	assert_equal(_rig.target_focus(), Vector3(3.0, 0.0, 3.0), "centre kept")
	assert_almost_equal(_rig.target_distance(), 25.0, "distance kept")


func test_a_refused_u_view_takes_no_angle() -> void:
	"""When the U view does not come on (it refuses while prewarming), the angle is not taken."""
	_modes.set_underground = func(_on: bool) -> void: pass
	assert_false(_modes.toggle_cutaway(), "nothing")
	assert_almost_equal(_rig.target_pitch_degrees(), DemoCamera.PITCH_DEFAULT_DEGREES, "pitch untouched")


func test_the_cutaway_keeps_a_follow_and_ends_an_orbit() -> void:
	"""Following a resident into the tunnels keeps the follow at the cutaway angle; an orbit gives way to it."""
	_selected = 3
	_modes.handle_key(_end())
	_modes.toggle_cutaway()
	assert_equal(_modes.mode, Modes.MODE_FOLLOW, "still following")
	assert_equal(_modes.strip.text(), Modes.FOLLOW_TEXT % "Wenna Tallowby", "the follow's line first")
	_modes.toggle_cutaway()
	_modes.toggle_orbit()
	_modes.toggle_cutaway()
	assert_equal(_modes.mode, Modes.MODE_FREE, "the orbit gave way")


# --- the pure parts -------------------------------------------------------------------------------------------

func test_every_village_building_is_listed_with_words_and_a_radius() -> void:
	"""Nine buildings in the layout's order, each named and with a framing radius over a metre."""
	var buildings := PackedVector3Array()
	var words := PackedStringArray()
	Modes.village_buildings(buildings, words)
	assert_equal(buildings.size(), Layout.BUILDINGS.size(), "every building")
	assert_equal(words.size(), buildings.size(), "every one named")
	assert_equal(words[0], "the hall", "the hall first")
	for row: int in buildings.size():
		var key: StringName = Layout.BUILDINGS[row]["key"]
		assert_true(buildings[row].z > 1.0, "%s has a radius" % words[row])
		assert_true(buildings[row].z >= Sizes.target_height_m(key) - 0.001, "%s: at least its height" % words[row])
		assert_true(buildings[row].z >= Sizes.scaled_rect(key, 1.0).size.length() * 0.5 - 0.001,
			"%s: at least half its footprint" % words[row])
		assert_false(words[row] == "the building", "%s has its own words" % words[row])


func test_the_nearest_building_is_within_reach_only() -> void:
	"""The nearest centre wins; one exactly at the reach counts; beyond it, none."""
	var rows := PackedVector3Array([Vector3(0.0, 0.0, 2.0), Vector3(10.0, 0.0, 2.0)])
	assert_equal(Modes.nearest_building(rows, Vector3(6.0, 0.0, 0.0), 12.0), 1, "the nearer")
	assert_equal(Modes.nearest_building(rows, Vector3(-12.0, 0.0, 0.0), 12.0), 0, "at the reach")
	assert_equal(Modes.nearest_building(rows, Vector3(-12.01, 0.0, 0.0), 12.0), -1, "beyond it")
	assert_equal(Modes.nearest_building(PackedVector3Array(), Vector3.ZERO, 12.0), -1, "no buildings")


func test_the_orbit_and_cutaway_distances_are_held_in_their_bands() -> void:
	"""Small things are framed from the band's near end, large ones from its far end."""
	assert_almost_equal(Modes.orbit_distance(0.5), Modes.ORBIT_MIN_M, "a small building")
	assert_almost_equal(Modes.orbit_distance(100.0), Modes.ORBIT_MAX_M, "a huge one")
	var mid: float = 5.0 * Modes.ORBIT_FIT / tan(deg_to_rad(DemoCamera.FOV_DEGREES * 0.5))
	assert_almost_equal(Modes.orbit_distance(5.0), mid, "between: fitted")
	assert_almost_equal(Modes.cutaway_distance(Rect2(0.0, 0.0, 0.0, 0.0)), Modes.CUTAWAY_MIN_M, "one point")
	var fitted: float = 15.0 * Modes.CUTAWAY_FIT / tan(deg_to_rad(DemoCamera.FOV_DEGREES * 0.5))
	assert_almost_equal(Modes.cutaway_distance(Rect2(-20.0, 5.0, 30.0, 0.0)), fitted, "30 m across: half of it fitted")
	assert_almost_equal(Modes.cutaway_distance(Rect2(0.0, 0.0, 400.0, 400.0)), DemoCamera.DISTANCE_MAX, "huge")


func test_the_network_extent_is_the_shown_levels_nodes() -> void:
	"""The box round the live nodes on the level asked for; another level's nodes and freed rows are not in it; an
	empty level has a negative size."""
	var network := Graph.new()
	assert_true(Modes.network_extent(network, Rules.LEVEL_1).size.x < 0.0, "empty")
	_node(network, 0, Vector2(-4.0, 2.0), Rules.LEVEL_1)
	_node(network, 1, Vector2(6.0, 9.0), Rules.LEVEL_1)
	_node(network, 2, Vector2(30.0, 30.0), Rules.LEVEL_2)
	var one: Rect2 = Modes.network_extent(network, Rules.LEVEL_1)
	assert_true(one.position.is_equal_approx(Vector2(-4.0, 2.0)) and one.size.is_equal_approx(Vector2(10.0, 7.0)),
		"level 1's box, got %s" % one)
	var two: Rect2 = Modes.network_extent(network, Rules.LEVEL_2)
	assert_true(two.position.is_equal_approx(Vector2(30.0, 30.0)) and two.size == Vector2.ZERO, "level 2's one node")
	network.node_kind[1] = Graph.NODE_FREE
	assert_true(Modes.network_extent(network, Rules.LEVEL_1).size == Vector2.ZERO, "a freed node is not in it")


func _node(network: Graph, row: int, at: Vector2, level: int) -> void:
	"""Write one live junction into the network's node columns."""
	network.node_kind[row] = Graph.NODE_JUNCTION
	network.node_level[row] = level
	network.node_x_u[row] = Rules.to_u(at.x)
	network.node_z_u[row] = Rules.to_u(at.y)


func test_the_key_reading_helpers() -> void:
	"""key_of prefers the physical key; shift_only is Shift alone; is_escape is a fresh Esc press."""
	var logical := InputEventKey.new()
	logical.keycode = KEY_O
	assert_equal(Modes.key_of(logical), KEY_O, "logical when no physical")
	assert_true(Modes.shift_only(_key(KEY_O, true)), "Shift")
	assert_false(Modes.shift_only(_key(KEY_O, true, true)), "Ctrl+Shift")
	assert_false(Modes.shift_only(_key(KEY_O)), "none")
	assert_true(Modes.is_escape(_key(KEY_ESCAPE)), "Esc")
	var echo := _key(KEY_ESCAPE)
	echo.echo = true
	assert_false(Modes.is_escape(echo), "a repeat")
	assert_false(Modes.is_escape(_held(&"ui_cancel", true)), "not a key")


func test_plain_o_and_u_are_left_to_their_owners() -> void:
	"""O is Objectives and U the U view's switch: without Shift they are not the modes'."""
	assert_false(_modes.handle_key(_key(KEY_O)), "O")
	assert_false(_modes.handle_key(_key(KEY_U)), "U")
	assert_false(_modes.handle_key(_key(KEY_U, true, true)), "Ctrl+Shift+U")
	assert_false(_modes.handle_key(_held(&"camera_follow", true)), "an action event is not a key press")


func test_the_follow_key_is_the_projects_camera_follow() -> void:
	"""The modes read UI §5's camera_follow (End), which the project binds."""
	assert_true(InputMap.has_action(Modes.FOLLOW_ACTION), "bound")
	var bound: bool = false
	for event: InputEvent in InputMap.action_get_events(Modes.FOLLOW_ACTION):
		bound = bound or (event is InputEventKey and (event as InputEventKey).keycode == KEY_END)
	assert_true(bound, "to End")


func test_a_frame_of_the_modes_creates_no_object() -> void:
	"""500 frames of follow and of orbit create no Object (OBJECT_COUNT: Strings and Callables are not counted)."""
	_selected = 3
	_modes.handle_key(_end())
	_frames(FRAME)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_frames(250.0 * FRAME)
	_modes.toggle_orbit()
	_frames(250.0 * FRAME)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "no object retained")


# --- the edge pan ---------------------------------------------------------------------------------------------

func test_the_band_is_twelve_logical_pixels_at_every_size() -> void:
	"""12 px at 720p and 1080p, 24 at 4K (S = 2), 15 at 1080p with the interface at 125 %."""
	assert_almost_equal(EdgePan.band_px(SIZE_720), 12.0, "720p")
	assert_almost_equal(EdgePan.band_px(SIZE_1080), 12.0, "1080p")
	assert_almost_equal(EdgePan.band_px(SIZE_4K), 24.0, "4K")
	DemoUiScale.percent = 125
	assert_almost_equal(EdgePan.band_px(SIZE_1080), 15.0, "125 %")
	DemoUiScale.percent = 100


func test_the_push_by_edge_and_corner() -> void:
	"""Left and right push across, top forward and bottom back; a corner both; inside the band's edge nothing; a
	pointer off the window nothing."""
	var size := SIZE_1080
	assert_equal(EdgePan.edge_push(Vector2(0.0, 500.0), size, 12.0), Vector2(-1.0, 0.0), "left edge")
	assert_equal(EdgePan.edge_push(Vector2(11.9, 500.0), size, 12.0), Vector2(-1.0, 0.0), "in the band")
	assert_equal(EdgePan.edge_push(Vector2(12.0, 500.0), size, 12.0), Vector2.ZERO, "just past it")
	assert_equal(EdgePan.edge_push(Vector2(1908.0, 500.0), size, 12.0), Vector2(1.0, 0.0), "right")
	assert_equal(EdgePan.edge_push(Vector2(1907.9, 500.0), size, 12.0), Vector2.ZERO, "short of the right band")
	assert_equal(EdgePan.edge_push(Vector2(900.0, 3.0), size, 12.0), Vector2(0.0, 1.0), "top: forward")
	assert_equal(EdgePan.edge_push(Vector2(900.0, 1079.0), size, 12.0), Vector2(0.0, -1.0), "bottom: back")
	assert_equal(EdgePan.edge_push(Vector2(1.0, 1.0), size, 12.0), Vector2(-1.0, 1.0), "a corner")
	assert_equal(EdgePan.edge_push(Vector2(-1.0, 500.0), size, 12.0), Vector2.ZERO, "off the window")
	assert_equal(EdgePan.edge_push(Vector2(900.0, 1081.0), size, 12.0), Vector2.ZERO, "below it")


func test_the_edge_pans_after_the_dwell_and_stops_off_the_band() -> void:
	"""The pointer resting at the left edge pans the rig after 250 ms (not before), and moving off the band stops it
	and starts the dwell again."""
	var edge := _edge_on()
	_move(edge, Vector2(2.0, 500.0))
	edge.step(0.2, SIZE_1080)
	assert_equal(edge.push(), Vector2.ZERO, "not yet")
	edge.step(0.06, SIZE_1080)
	assert_equal(edge.push(), Vector2(-1.0, 0.0), "after the dwell")
	var pans: int = _rig.pan_revision()
	_rig.step(0.5)
	assert_true(_rig.target_focus().x < -0.1, "panned west")
	assert_true(_rig.pan_revision() > pans, "a pan the player made")
	_move(edge, Vector2(600.0, 500.0))
	edge.step(FRAME, SIZE_1080)
	assert_equal(edge.push(), Vector2.ZERO, "off the band")
	_move(edge, Vector2(2.0, 500.0))
	edge.step(0.1, SIZE_1080)
	assert_equal(edge.push(), Vector2.ZERO, "the dwell again")
	edge.free()


func test_the_edge_pan_ends_a_follow() -> void:
	"""An edge pan is a pan: it breaks the follow."""
	var edge := _edge_on()
	_selected = 3
	_modes.handle_key(_end())
	_move(edge, Vector2(1919.0, 500.0))
	edge.step(0.3, SIZE_1080)
	_frames(0.1)
	assert_equal(_modes.mode, Modes.MODE_FREE, "ended")
	edge.free()


func test_the_edge_pan_is_off_when_it_should_be() -> void:
	"""Off: before the pointer has entered, after it left, with a button held, behind a modal, without the window's
	focus, or when not enabled."""
	var edge := _edge_on()
	assert_false(edge.allowed(), "no pointer yet")
	_move(edge, Vector2(2.0, 500.0))
	assert_true(edge.allowed(), "pointer in, focused, nothing open")
	edge.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	assert_false(edge.allowed(), "the pointer left")
	_move(edge, Vector2(2.0, 500.0), MOUSE_BUTTON_MASK_LEFT)
	assert_false(edge.allowed(), "a drag")
	_move(edge, Vector2(2.0, 500.0))
	_modal = true
	assert_false(edge.allowed(), "a modal")
	_modal = false
	edge.focused = func() -> bool: return false
	assert_false(edge.allowed(), "no focus")
	edge.focused = func() -> bool: return true
	Access.set_flag(Access.SET_EDGE_SCROLL, false)
	assert_false(edge.allowed(), "Edge scroll off in Settings")
	Access.set_flag(Access.SET_EDGE_SCROLL, true)
	assert_true(edge.allowed(), "and on again")
	edge.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(edge.allowed(), "the app lost focus")
	edge.step(1.0, SIZE_1080)
	assert_equal(edge.push(), Vector2.ZERO, "and nothing pushed")
	edge.free()


func test_off_the_tree_the_window_has_no_focus() -> void:
	"""Without a harness's word, a node off the tree has no window, so no focus: no edge pan."""
	var edge := EdgePan.new()
	_move(edge, Vector2(2.0, 500.0))
	assert_false(edge.allowed(), "no window")
	edge.free()


func test_a_button_release_ends_a_drag_for_the_edge() -> void:
	"""A button event updates the held buttons (a release lets the edge pan again)."""
	var edge := _edge_on()
	_move(edge, Vector2(2.0, 500.0))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = Vector2(2.0, 500.0)
	edge.note_event(press)
	assert_false(edge.allowed(), "held")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(2.0, 500.0)
	edge.note_event(release)
	assert_true(edge.allowed(), "released")
	edge.free()


func _edge_on() -> EdgePan:
	"""An edge pan on the rig, focused, no modal."""
	var edge := EdgePan.new()
	edge.configure(_rig)
	edge.focused = func() -> bool: return true
	edge.modal_open = func() -> bool: return _modal
	return edge


func _move(edge: EdgePan, at: Vector2, mask: int = 0) -> void:
	"""The pointer moves to `at` with the buttons `mask` held."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.button_mask = mask
	edge.note_event(motion)


func test_the_modes_own_an_edge_pan_off_behind_a_modal() -> void:
	"""The strip and the edge pan are the modes' children from the start (freed with them, configured or not);
	configure starts the edge pan on the rig, reading the modes' modal check."""
	var bare := Modes.new()
	assert_true(bare.strip.get_parent() == bare and bare.edge.get_parent() == bare, "children before configure")
	bare.free()
	assert_true(_modes.edge.get_parent() == _modes, "a child")
	assert_true(_modes.edge.modal_open.is_valid(), "wired")
	_modal = true
	assert_true(bool(_modes.edge.modal_open.call()), "reads the modal")


# --- the strip ------------------------------------------------------------------------------------------------

func test_the_strip_shows_a_mode_and_flashes_over_it() -> void:
	"""A mode's line stays; a flash shows over it for FLASH_SECONDS of real time, then the mode's line is back; with
	neither the strip hides."""
	var strip := Strip.new()
	assert_false(strip.shown(), "hidden at first")
	strip.set_mode_text("Following X")
	assert_equal(strip.text(), "Following X", "the mode")
	strip.flash("View 1")
	assert_equal(strip.text(), "View 1", "the flash over it")
	strip._process(Strip.FLASH_SECONDS - 0.1)
	assert_equal(strip.text(), "View 1", "still")
	strip._process(0.2)
	assert_equal(strip.text(), "Following X", "back to the mode")
	strip.flash("Stopped")
	strip.set_mode_text("")
	assert_equal(strip.text(), "Stopped", "a mode ending keeps the flash that says so")
	strip._process(Strip.FLASH_SECONDS)
	assert_false(strip.shown(), "nothing: hidden")
	assert_equal(strip.text(), "", "and says nothing")
	strip.flash("No view 3 yet")
	strip.set_mode_text("Orbiting the hall")
	assert_equal(strip.text(), "Orbiting the hall", "a mode starting replaces a flash")
	strip.free()


func test_the_strip_stands_in_its_own_row_above_the_commands() -> void:
	"""Bottom centre, its bottom STACK_GAP above the command strip, centred on the news' band where it fits, inside the
	gap between the minimap and the right column; twice the size at 4K; following the journal."""
	var strip := Strip.new()
	strip.set_mode_text("Cutaway angle")
	for size: Vector2 in [SIZE_720, SIZE_1080, SIZE_4K]:
		strip.place_for(size)
		var layout := UiLayout.new()
		var geometry := UiLayout.Geometry.new()
		var band: Rect2 = NewsStrip.band_placement(int(size.x), int(size.y), layout, geometry, false)
		var s: float = geometry.scale
		var at: Rect2 = strip.rect()
		assert_almost_equal(at.end.y, (geometry.commands.position.y - Strip.STACK_GAP) * s, "%s: above the commands" % size)
		assert_almost_equal(at.get_center().x, band.get_center().x * s, "%s: centred on the news' band" % size)
		assert_true(at.position.x >= geometry.minimap.end.x * s and at.end.x <= geometry.detail.position.x * s,
			"%s: between the minimap and the right column" % size)
	strip.place_for(SIZE_1080)
	var small: Rect2 = strip.rect()
	strip.place_for(SIZE_4K)
	assert_almost_equal(strip.rect().size.y, small.size.y * 2.0, "twice the size at 4K")
	strip.journal_open = func() -> bool: return true
	strip.place_for(SIZE_1080)
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	var band: Rect2 = NewsStrip.band_placement(1920, 1080, layout, geometry, true)
	assert_almost_equal(strip.rect().get_center().x, band.get_center().x, "the journal open: follows the commands")
	strip.free()


func test_a_long_line_is_moved_in_to_stay_in_the_gap() -> void:
	"""Centred where it fits; pushed in from the right column; from the minimap; wider than the gap: at its start."""
	assert_almost_equal(Strip.row_left(500.0, 200.0, 100.0, 900.0), 400.0, "centred")
	assert_almost_equal(Strip.row_left(850.0, 200.0, 100.0, 900.0), 700.0, "in from the right")
	assert_almost_equal(Strip.row_left(150.0, 200.0, 100.0, 900.0), 100.0, "in from the left")
	assert_almost_equal(Strip.row_left(500.0, 900.0, 100.0, 900.0), 100.0, "too wide: at the gap's start")
	assert_almost_equal(Strip.row_left(800.0, 200.0, 100.0, 1000.0), 700.0, "exactly at the right edge")


func test_the_strip_reserves_its_row_only_while_shown() -> void:
	"""reserved_height is the strip's height and gap while it shows, 0 while hidden; the news stands on it."""
	var strip := Strip.new()
	assert_almost_equal(strip.reserved_height(), 0.0, "hidden: nothing kept")
	strip.set_mode_text("Following Wenna Tallowby")
	var kept: float = strip.reserved_height()
	strip.place_for(SIZE_1080)
	assert_almost_equal(kept, strip.rect().size.y + Strip.STACK_GAP, "shown: its height and its gap (at 1080p, S = 1)")
	strip.set_mode_text("")
	assert_almost_equal(strip.reserved_height(), 0.0, "hidden again")
	var news := NewsStrip.new()
	news.configure(Services.new().notices)
	news.lift = func() -> float: return 41.0
	news.refresh(0)
	assert_almost_equal(news.lifted_by(), 41.0, "the news takes the row it is given")
	news.lift = Callable()
	news.refresh(0)
	assert_almost_equal(news.lifted_by(), 0.0, "and none without one")
	news.free()
	strip.free()


# --- the Settings toggle and the Follow button (Brendan's rulings P6, P8) -----------------------------------------

func test_edge_scroll_is_a_setting_on_by_default_under_camera() -> void:
	"""UI §8.1 `edge_scroll`: a setting, on by default; Settings show its toggle in words; Restore defaults turns it
	back on."""
	assert_true(Access.is_on(Access.SET_EDGE_SCROLL), "on by default")
	assert_equal(Access.SET_NAMES[Access.SET_EDGE_SCROLL], "Edge scroll", "named")
	assert_true(SettingsUi.CAMERA_SETTINGS.has(Access.SET_EDGE_SCROLL), "under Camera")
	var section := SettingsUi.new()
	assert_equal(section.toggle_button(Access.SET_EDGE_SCROLL).text, "Edge scroll: on", "in words")
	section.toggle_button(Access.SET_EDGE_SCROLL).button_pressed = false
	assert_false(Access.is_on(Access.SET_EDGE_SCROLL), "the toggle turns it off")
	assert_equal(section.toggle_button(Access.SET_EDGE_SCROLL).text, "Edge scroll: off", "and says so")
	section.restore_defaults()
	assert_true(Access.is_on(Access.SET_EDGE_SCROLL), "Restore defaults: on again")
	section.free()


func test_the_party_panel_follow_button() -> void:
	"""Shown with anyone selected; pressing it asks for the follow; worded for whether the camera follows."""
	var panel := PartyPanel.new()
	panel.build()
	assert_false(panel.follow_button().visible, "nobody selected: hidden")
	var one: Array[Dictionary] = [{"index": 3, "name": "Wenna Tallowby", "species": "Mouse", "state": "holding"}]
	panel.show_party(one)
	assert_true(panel.follow_button().visible, "shown")
	assert_equal(panel.follow_button().text, PartyPanel.FOLLOW_BUTTON, "Follow (End)")
	var asked: Array[int] = [0]
	panel.follow_requested.connect(func() -> void: asked[0] += 1)
	panel.follow_button().pressed.emit()
	assert_equal(asked[0], 1, "asks for the follow")
	panel.set_following(true)
	assert_equal(panel.follow_button().text, PartyPanel.FOLLOW_STOP, "Stop following (End)")
	panel.set_following(false)
	assert_equal(panel.follow_button().text, PartyPanel.FOLLOW_BUTTON, "back")
	panel.free()


func test_the_modes_tell_whether_a_follow_is_on() -> void:
	"""follow_changed hears on when End starts a follow, off when a pan, End or another mode ends it."""
	var heard: Array[bool] = []
	_modes.follow_changed = func(on: bool) -> void: heard.append(on)
	_selected = 3
	_modes.toggle_follow()
	assert_equal(heard.back(), true, "on")
	_modes.toggle_follow()
	assert_equal(heard.back(), false, "End: off")
	_modes.toggle_follow()
	_modes.toggle_orbit()
	assert_equal(heard.back(), false, "the orbit took over: off")
	_modes.toggle_follow()
	_rig.centre_on(Vector3(-9.0, 0.0, 9.0))
	_frames(FRAME)
	assert_equal(heard.back(), false, "a pan: off")
