extends "res://test/framework/test_case.gd"
## Coverage for the live demo's RTS camera rig (`godot/demo/camera/demo_camera.gd`).
##
## The rig's arithmetic is checked against values this file computes itself: focus clamping to
## the AABB, the zoom and pitch limits, frame-rate-independent damping, the orbit geometry that
## keeps the camera looking at its focus, and view-relative panning. Input is driven through the
## project's OWN action map -- every event bound to `camera_zoom_in` in `project.godot` is fed to
## the rig -- so a rebinding in the input map is exercised rather than restated here.
##
## Everything runs off-tree: the runner executes suites before the scene tree is live, so `step()`
## is called by hand in place of `_process()`.

const DemoCamera := preload("res://demo/camera/demo_camera.gd")

## A 40 m square village on the ground at y = 0, as the demo lays it out.
const VILLAGE: AABB = AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 0.0, 40.0))
const EPSILON: float = 0.0001
## Long enough for the exponential damp to settle to within EPSILON.
const SETTLE_SECONDS: float = 5.0
const FRAME: float = 1.0 / 60.0

var _rig: DemoCamera = null


func before_each() -> void:
	"""A fresh rig configured over the village, centred on the origin."""
	_rig = DemoCamera.new()
	_rig.configure(VILLAGE, Vector3.ZERO)


func after_each() -> void:
	"""Free the rig and its camera."""
	if _rig != null:
		_rig.free()
		_rig = null


# --- the pure math --------------------------------------------------------------------------------

func test_clamp_focus_keeps_inside_points_and_clamps_outside_ones() -> void:
	"""A point inside the box is unchanged; one outside lands on the nearest face."""
	var inside: Vector3 = Vector3(5.0, 0.0, -7.0)
	assert_equal(DemoCamera.clamp_focus(inside, VILLAGE), inside, "inside point unchanged")
	assert_equal(DemoCamera.clamp_focus(Vector3(100.0, 3.0, -100.0), VILLAGE),
		Vector3(20.0, 0.0, -20.0), "outside point clamped to the corner, on the ground")


func test_zoom_steps_are_multiplicative_and_limited() -> void:
	"""One notch in is 12% closer; enough notches stop at the near and far limits."""
	assert_almost_equal(DemoCamera.zoomed_distance(40.0, 1), 40.0 * 0.88, "one notch in")
	assert_almost_equal(DemoCamera.zoomed_distance(40.0, -1), 40.0 / 0.88, "one notch out")
	assert_almost_equal(DemoCamera.zoomed_distance(40.0, 100), DemoCamera.DISTANCE_MIN, "near limit")
	assert_almost_equal(DemoCamera.zoomed_distance(40.0, -100), DemoCamera.DISTANCE_MAX, "far limit")


func test_pitch_is_held_between_its_limits() -> void:
	"""Pitch clamps to 30..75 degrees."""
	assert_almost_equal(DemoCamera.clamp_pitch(deg_to_rad(10.0)), deg_to_rad(30.0), "low clamp")
	assert_almost_equal(DemoCamera.clamp_pitch(deg_to_rad(89.0)), deg_to_rad(75.0), "high clamp")
	assert_almost_equal(DemoCamera.clamp_pitch(deg_to_rad(50.0)), deg_to_rad(50.0), "unchanged")


func test_damping_is_frame_rate_independent() -> void:
	"""Two half-frames close the same gap as one whole frame; zero time closes nothing."""
	var whole: float = DemoCamera.damp_factor(DemoCamera.DAMPING, 0.1)
	var half: float = DemoCamera.damp_factor(DemoCamera.DAMPING, 0.05)
	assert_almost_equal(1.0 - (1.0 - half) * (1.0 - half), whole, "two halves equal one whole")
	assert_almost_equal(DemoCamera.damp_factor(DemoCamera.DAMPING, 0.0), 0.0, "no time, no motion")
	assert_true(DemoCamera.damp_factor(DemoCamera.DAMPING, 10.0) > 0.9999, "long time settles")


# --- the rig --------------------------------------------------------------------------------------

func test_rig_owns_a_perspective_camera_at_forty_degrees() -> void:
	"""The rig creates its own Camera3D: perspective, 40 degree vertical FOV, 50 degree pitch."""
	var camera: Camera3D = _rig.camera()
	assert_not_null(camera, "a camera child")
	assert_true(camera.get_parent() == _rig, "owned by the rig")
	assert_equal(camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "perspective")
	assert_equal(camera.keep_aspect, Camera3D.KEEP_HEIGHT, "fov is vertical")
	assert_almost_equal(camera.fov, 40.0, "40 degree fov")
	assert_almost_equal(float(_rig.pitch_degrees()), 50.0, "50 degree pitch")


func test_camera_looks_at_its_focus() -> void:
	"""The camera's forward axis passes through the focus, at the configured distance."""
	_rig.configure(VILLAGE, Vector3(6.0, 0.0, -4.0))
	var camera: Camera3D = _rig.camera()
	var world: Transform3D = _rig.transform * camera.transform
	var focus: Vector3 = _rig.focus()
	var to_focus: Vector3 = focus - world.origin
	var forward: Vector3 = -world.basis.z.normalized()
	assert_almost_equal(to_focus.length(), DemoCamera.DISTANCE_DEFAULT, "eye at the distance")
	assert_true(forward.dot(to_focus.normalized()) > 1.0 - EPSILON, "forward points at focus")
	assert_true(world.origin.y > 0.0, "the eye is above the ground")


func test_configure_clamps_the_start_focus() -> void:
	"""A start point outside the box is pulled inside it."""
	_rig.configure(VILLAGE, Vector3(90.0, 0.0, 0.0))
	assert_equal(_rig.focus(), Vector3(20.0, 0.0, 0.0), "clamped to the east edge")


func test_make_current_off_tree_marks_the_camera_current() -> void:
	"""Off-tree, make_current() leaves the camera flagged current for when it enters."""
	_rig.make_current()
	assert_true(_rig.camera().current, "current")


# --- input ----------------------------------------------------------------------------------------

func test_every_bound_zoom_event_zooms() -> void:
	"""Each event project.godot binds to camera_zoom_in moves the target distance inward."""
	var events: Array[InputEvent] = InputMap.action_get_events(DemoCamera.ACTION_ZOOM_IN)
	assert_true(events.size() > 0, "camera_zoom_in has bindings")
	for bound: InputEvent in events:
		_rig.reset_view()
		var event: InputEvent = _pressed(bound)
		assert_true(_rig.handle_input(event), "%s is a camera action" % event.as_text())
		assert_almost_equal(float(_rig.target_distance()),
			DemoCamera.DISTANCE_DEFAULT * (1.0 - DemoCamera.ZOOM_STEP), "%s zooms in" % event.as_text())


func test_zoom_out_and_its_limit() -> void:
	"""Zooming out stops at the far limit however many notches arrive."""
	for notch: int in 60:
		_rig.handle_input(_action(DemoCamera.ACTION_ZOOM_OUT, true))
	assert_almost_equal(float(_rig.target_distance()), DemoCamera.DISTANCE_MAX, "far limit")


func test_held_pan_moves_toward_the_view_and_stops_on_release() -> void:
	"""Holding forward at heading 0 moves the focus toward -Z; releasing stops it."""
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, true))
	_rig.step(0.2)
	var moved: Vector3 = _rig.target_focus()
	assert_true(moved.z < -EPSILON and absf(moved.x) < EPSILON, "moved north, got %s" % moved)
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, false))
	_rig.step(0.2)
	assert_equal(_rig.target_focus(), moved, "release stops the pan")


func test_pan_is_clamped_to_the_bounds() -> void:
	"""Holding right long enough parks the focus on the box's east face, never beyond."""
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_RIGHT, true))
	for frame: int in 600:
		_rig.step(FRAME)
	var focus: Vector3 = _rig.target_focus()
	assert_almost_equal(focus.x, VILLAGE.end.x, "parked on the east face")


func test_view_eases_toward_the_target() -> void:
	"""After a zoom the drawn distance moves partway in one frame and settles in time."""
	_rig.handle_input(_action(DemoCamera.ACTION_ZOOM_IN, true))
	var target: float = float(_rig.target_distance())
	_rig.step(FRAME)
	var partway: float = float(_rig.distance())
	assert_true(partway < DemoCamera.DISTANCE_DEFAULT and partway > target, "partway after a frame")
	_rig.step(SETTLE_SECONDS)
	assert_true(absf(float(_rig.distance()) - target) < EPSILON, "settled on the target")


func test_pitch_steps_and_home_resets() -> void:
	"""Pitch up adds one step; camera_home returns to the configured view."""
	_rig.handle_input(_action(DemoCamera.ACTION_PITCH_UP, true))
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(float(_rig.pitch_degrees()),
		DemoCamera.PITCH_DEFAULT_DEGREES + DemoCamera.PITCH_STEP_DEGREES, "one pitch step")
	_rig.handle_input(_action(DemoCamera.ACTION_HOME, true))
	assert_almost_equal(float(_rig.pitch_degrees()), DemoCamera.PITCH_DEFAULT_DEGREES,
		"home restores the pitch")


func test_rotation_turns_the_heading() -> void:
	"""Holding rotate-right turns the view clockwise from above: the heading decreases."""
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_RIGHT, true))
	_rig.step(0.5)
	assert_true(float(_rig.yaw_degrees()) < 0.0, "turned right")


func test_alt_page_up_pitches_and_does_not_zoom() -> void:
	"""Alt+PgUp is camera_pitch_up; it also contains PgUp, but zoom is matched exactly."""
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_PAGEUP
	key.alt_pressed = true
	key.pressed = true
	assert_true(_rig.handle_input(key), "a camera action")
	assert_almost_equal(_rig.target_distance(), DemoCamera.DISTANCE_DEFAULT, "distance unchanged")
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.pitch_degrees(),
		DemoCamera.PITCH_DEFAULT_DEGREES + DemoCamera.PITCH_STEP_DEGREES, "pitched up one step")


func test_focus_loss_releases_every_held_key() -> void:
	"""After the window loses focus a key whose release never arrived no longer pans or turns."""
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_LEFT, true))
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_LEFT, true))
	_rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_rig.step(0.5)
	assert_equal(_rig.target_focus(), Vector3.ZERO, "no pan after focus loss")
	assert_almost_equal(_rig.yaw_degrees(), 0.0, "no turn after focus loss")


func test_unrelated_input_is_left_alone() -> void:
	"""A non-camera action is not consumed, so the HUD and the game still receive it."""
	assert_false(_rig.handle_input(_action(&"select_primary", true)), "not a camera action")


func test_every_action_the_rig_reads_exists_in_the_project() -> void:
	"""The rig invents no binding: each action it reads is defined in project.godot."""
	var actions: Array[StringName] = [DemoCamera.ACTION_ZOOM_IN, DemoCamera.ACTION_ZOOM_OUT,
		DemoCamera.ACTION_PITCH_UP, DemoCamera.ACTION_PITCH_DOWN, DemoCamera.ACTION_HOME]
	actions.append_array(DemoCamera.HELD_ACTIONS)
	for action: StringName in actions:
		assert_true(InputMap.has_action(action), "%s is defined" % action)


# --- helpers --------------------------------------------------------------------------------------

func _action(action: StringName, pressed: bool) -> InputEventAction:
	"""An action event, as Input.parse_input_event would deliver it."""
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _pressed(bound: InputEvent) -> InputEvent:
	"""A pressed copy of a bound event from the input map."""
	var event: InputEvent = bound.duplicate() as InputEvent
	if event is InputEventKey:
		(event as InputEventKey).pressed = true
		if (event as InputEventKey).keycode == KEY_NONE:
			(event as InputEventKey).keycode = (event as InputEventKey).physical_keycode
	elif event is InputEventMouseButton:
		(event as InputEventMouseButton).pressed = true
	return event


func test_the_rig_reports_its_distance_for_the_shadow_fit() -> void:
	"""distance() is the eye-to-focus distance the demo fits the sun's shadow range to."""
	assert_almost_equal(_rig.distance(), 22.0, "the 22 m default")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_rig.handle_input(wheel)
	for i: int in int(SETTLE_SECONDS / FRAME):
		_rig.step(FRAME)
	assert_true(_rig.distance() < 22.0, "zooming in shortens it")


# --- the middle-button drag (decision 0205) -------------------------------------------------------

func _middle(pressed: bool) -> InputEventMouseButton:
	"""A middle-button press or release."""
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.pressed = pressed
	return event


func _drag(relative: Vector2, held: bool) -> InputEventMouseMotion:
	"""A pointer move by `relative` pixels, with the middle button held or not."""
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE if held else 0
	return event


func test_a_middle_drag_turns_the_view() -> void:
	"""Held, a drag across turns the heading (right turns it right, as E) and up and down pitch it (up
	toward the horizon), by the rig's per-pixel rates; the pitch stays within its limits."""
	assert_true(_rig.handle_input(_middle(true)), "the press is the camera's")
	assert_true(_rig.is_drag_turning(), "turning")
	assert_true(_rig.handle_input(_drag(Vector2(100.0, 0.0), true)), "the drag is the camera's")
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.yaw_degrees(), -100.0 * DemoCamera.DRAG_YAW_DEGREES_PER_PX, "turned right")
	_rig.handle_input(_drag(Vector2(0.0, -50.0), true))
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.pitch_degrees(),
		DemoCamera.PITCH_DEFAULT_DEGREES - 50.0 * DemoCamera.DRAG_PITCH_DEGREES_PER_PX, "up: toward the horizon")
	_rig.handle_input(_drag(Vector2(0.0, 5000.0), true))
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.pitch_degrees(), DemoCamera.PITCH_MAX_DEGREES, "held at the limit")


func test_the_drag_ends_on_release_or_a_lost_button() -> void:
	"""A release ends the drag; so does a move that arrives with the button no longer held (a release
	the rig never saw); a move without a drag is not the camera's."""
	_rig.handle_input(_middle(true))
	assert_true(_rig.handle_input(_middle(false)), "the release is the camera's")
	assert_false(_rig.is_drag_turning(), "stopped")
	assert_false(_rig.handle_input(_drag(Vector2(100.0, 0.0), true)), "no drag: not the camera's")
	_rig.handle_input(_middle(true))
	assert_false(_rig.handle_input(_drag(Vector2(100.0, 0.0), false)), "button gone: not turned")
	assert_false(_rig.is_drag_turning(), "stopped")
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.yaw_degrees(), 0.0, "nothing turned")


func test_focus_loss_ends_the_drag() -> void:
	"""Losing the window's focus mid-drag ends it."""
	_rig.handle_input(_middle(true))
	_rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(_rig.is_drag_turning(), "stopped")


func test_other_buttons_do_not_start_a_drag() -> void:
	"""The left and right buttons are the command layer's, never the camera's."""
	for index: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var event := InputEventMouseButton.new()
		event.button_index = index
		event.pressed = true
		assert_false(_rig.handle_input(event), "button %d is not the camera's" % index)
	assert_false(_rig.is_drag_turning(), "no drag")


# --- the modes' hooks (decision 0801) ------------------------------------------------------------------

func test_a_diagonal_pan_is_no_faster_than_a_straight_one() -> void:
	"""W+D moves the centre as far as W alone in the same time (UI §5: "diagonal normalized")."""
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, true))
	_rig.step(0.5)
	var straight: float = _rig.target_focus().length()
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, false))
	_rig.configure(VILLAGE, Vector3.ZERO)
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, true))
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_RIGHT, true))
	_rig.step(0.5)
	var diagonal: Vector3 = _rig.target_focus()
	assert_almost_equal(diagonal.length(), straight, "as far")
	assert_almost_equal(diagonal.x, -diagonal.z, "north-east, evenly")


func test_the_players_pans_count_and_the_modes_moves_do_not() -> void:
	"""A held pan, centre_on and Home move the pan revision; track and aim do not; neither touches the turn
	revision."""
	var pans: int = _rig.pan_revision()
	_rig.track(Vector3(3.0, 0.0, 4.0))
	_rig.aim(Vector3(1.0, 0.0, 1.0), 30.0, 40.0, 15.0)
	_rig.turn_target(0.5)
	_rig.step(FRAME)
	assert_equal(_rig.pan_revision(), pans, "the modes' own moves are not the player's")
	_rig.centre_on(Vector3(2.0, 0.0, 2.0))
	assert_equal(_rig.pan_revision(), pans + 1, "centre_on is a pan (the minimap, the roster, a Go to)")
	_rig.handle_input(_action(DemoCamera.ACTION_HOME, true))
	assert_equal(_rig.pan_revision(), pans + 2, "Home is a pan")
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_LEFT, true))
	_rig.step(FRAME)
	_rig.step(FRAME)
	assert_equal(_rig.pan_revision(), pans + 4, "each held frame counts")
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_LEFT, false))
	_rig.step(FRAME)
	assert_equal(_rig.pan_revision(), pans + 4, "released: no more")
	assert_equal(_rig.turn_revision(), 0, "no turn")


func test_the_players_turns_count() -> void:
	"""A held rotate and a middle drag move the turn revision, a frame or an event at a time; a pan does not."""
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_LEFT, true))
	_rig.step(FRAME)
	assert_equal(_rig.turn_revision(), 1, "held Q")
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_LEFT, false))
	_rig.step(FRAME)
	assert_equal(_rig.turn_revision(), 1, "released")
	_rig.handle_input(_middle(true))
	_rig.handle_input(_drag(Vector2(10.0, 0.0), true))
	assert_equal(_rig.turn_revision(), 2, "a drag across")
	_rig.handle_input(_drag(Vector2(0.0, 25.0), true))
	assert_equal(_rig.turn_revision(), 2, "a drag straight up or down only tilts")


func test_track_moves_only_the_centre_and_is_held_in_the_box() -> void:
	"""The follow's track sets the target centre's x and z (clamped), nothing else."""
	_rig.track(Vector3(5.0, 9.0, -6.0))
	assert_equal(_rig.target_focus(), Vector3(5.0, 0.0, -6.0), "x and z, on the ground")
	_rig.track(Vector3(500.0, 0.0, 0.0))
	assert_almost_equal(_rig.target_focus().x, VILLAGE.end.x, "held in the box")
	assert_almost_equal(_rig.target_distance(), DemoCamera.DISTANCE_DEFAULT, "zoom untouched")
	assert_almost_equal(_rig.target_pitch_degrees(), DemoCamera.PITCH_DEFAULT_DEGREES, "pitch untouched")


func test_aim_sets_a_whole_view_inside_the_limits() -> void:
	"""aim sets centre, heading, pitch and distance; pitch and distance are held in their limits and the
	view eases there."""
	_rig.aim(Vector3(4.0, 0.0, -3.0), 90.0, 60.0, 30.0)
	assert_equal(_rig.target_focus(), Vector3(4.0, 0.0, -3.0), "centre")
	assert_almost_equal(_rig.target_yaw_degrees(), 90.0, "heading")
	assert_almost_equal(_rig.target_pitch_degrees(), 60.0, "pitch")
	assert_almost_equal(_rig.target_distance(), 30.0, "distance")
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.yaw_degrees(), 90.0, "eased there")
	_rig.aim(Vector3.ZERO, 0.0, 10.0, 1000.0)
	assert_almost_equal(_rig.target_pitch_degrees(), DemoCamera.PITCH_MIN_DEGREES, "pitch limit")
	assert_almost_equal(_rig.target_distance(), DemoCamera.DISTANCE_MAX, "zoom limit")
	_rig.aim(Vector3.ZERO, 0.0, 89.0, 0.1)
	assert_almost_equal(_rig.target_pitch_degrees(), DemoCamera.PITCH_MAX_DEGREES, "steep limit")
	assert_almost_equal(_rig.target_distance(), DemoCamera.DISTANCE_MIN, "near limit")


func test_aim_turns_the_shorter_way_round() -> void:
	"""From a heading of 350 degrees, aiming at 10 turns 20 degrees on, not 340 back; from 0, aiming at 350 turns 10
	back."""
	_rig.aim(Vector3.ZERO, 350.0, 50.0, 22.0)
	assert_almost_equal(_rig.target_yaw_degrees(), -10.0, "10 back, not 350 on")
	_rig.turn_target(deg_to_rad(360.0))
	_rig.aim(Vector3.ZERO, 10.0, 50.0, 22.0)
	assert_almost_equal(_rig.target_yaw_degrees(), 370.0, "on round")
	_rig.aim(Vector3.ZERO, 200.0, 50.0, 22.0)
	assert_almost_equal(_rig.target_yaw_degrees(), 200.0, "170 back, not 190 on")
	assert_almost_equal(DemoCamera.nearest_turn(0.0, deg_to_rad(181.0)), deg_to_rad(-179.0), "past half a turn")


func test_turn_target_turns_without_counting() -> void:
	"""The orbit's turn adds to the target heading; the drawn heading eases after it."""
	_rig.turn_target(deg_to_rad(12.0))
	assert_almost_equal(_rig.target_yaw_degrees(), 12.0, "turned left")
	_rig.step(SETTLE_SECONDS)
	assert_almost_equal(_rig.yaw_degrees(), 12.0, "eased")
	assert_equal(_rig.turn_revision(), 0, "not the player's")


func test_the_edge_push_pans_like_a_held_key_and_is_clamped() -> void:
	"""set_edge_push moves the centre as the held keys do (and counts as the player's pan); a push and a key the
	same way are no faster than one, along the view or across it."""
	_rig.set_edge_push(0.0, 1.0)
	_rig.step(0.5)
	var edge: Vector3 = _rig.target_focus()
	assert_true(edge.z < -EPSILON, "forward is north")
	assert_equal(_rig.pan_revision(), 2, "configure, then one pushed frame")
	_rig.configure(VILLAGE, Vector3.ZERO)
	_rig.set_edge_push(0.0, 5.0)
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, true))
	_rig.step(0.5)
	assert_almost_equal(_rig.target_focus().z, edge.z, "a key and the edge together: no faster")
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, false))
	_rig.configure(VILLAGE, Vector3.ZERO)
	_rig.set_edge_push(1.0, 0.0)
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_RIGHT, true))
	_rig.step(0.5)
	assert_almost_equal(_rig.target_focus().x, -edge.z, "across too: no faster")
	_rig.configure(VILLAGE, Vector3.ZERO)
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, true))
	_rig.step(0.5)
	var diagonal: Vector3 = _rig.target_focus()
	assert_almost_equal(diagonal.x, -diagonal.z, "the edge and two keys: still due north-east")
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_FORWARD, false))
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_RIGHT, false))
	_rig.set_edge_push(0.0, 0.0)
	var held: Vector3 = _rig.target_focus()
	_rig.step(0.5)
	assert_equal(_rig.target_focus(), held, "no push, no pan")


func test_the_drag_turns_per_logical_pixel_off_the_tree() -> void:
	"""Off the tree there is no window, so a pixel is a logical pixel (S = 1): the rate is the 0205 one."""
	_rig.handle_input(_middle(true))
	_rig.handle_input(_drag(Vector2(10.0, 0.0), true))
	assert_almost_equal(_rig.target_yaw_degrees(), -10.0 * DemoCamera.DRAG_YAW_DEGREES_PER_PX, "S = 1")


func test_the_targets_read_back() -> void:
	"""target_pitch_degrees and target_yaw_degrees give what input asked for, before the ease."""
	_rig.handle_input(_action(DemoCamera.ACTION_PITCH_UP, true))
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_LEFT, true))
	_rig.step(0.5)
	assert_almost_equal(_rig.target_pitch_degrees(), DemoCamera.PITCH_DEFAULT_DEGREES + DemoCamera.PITCH_STEP_DEGREES,
		"pitch asked for")
	assert_almost_equal(_rig.target_yaw_degrees(), DemoCamera.ROTATE_SPEED_DEGREES * 0.5, "heading asked for")
	assert_true(_rig.yaw_degrees() < _rig.target_yaw_degrees(), "the drawn heading lags it")


func test_a_frame_of_motion_retains_nothing() -> void:
	"""500 frames of held pan, turn, edge push and tracking create no object (the rig's step is per frame)."""
	_rig.handle_input(_action(DemoCamera.ACTION_PAN_LEFT, true))
	_rig.handle_input(_action(DemoCamera.ACTION_ROTATE_LEFT, true))
	_rig.set_edge_push(1.0, -1.0)
	_rig.step(FRAME)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for frame: int in 500:
		_rig.track(Vector3(float(frame % 7), 0.0, 1.0))
		_rig.step(FRAME)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "no object retained")
