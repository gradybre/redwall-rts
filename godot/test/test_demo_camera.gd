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
