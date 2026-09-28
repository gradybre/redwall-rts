extends Node3D
## The live demo's RTS camera: an orbit rig over the village, driven by the project's own actions.
##
##     var rig: Node3D = DemoCamera.new()
##     add_child(rig)
##     rig.configure(AABB(Vector3(-20, 0, -20), Vector3(40, 4, 40)), Vector3.ZERO)
##     rig.make_current()
##
## PRESENTATION ONLY. Every value here is a float and none of it reaches the simulation. The
## settlement's own camera contract (UI §6) is not built -- `ui_availability.gd` still names
## REASON_NO_WORLD_CAMERA -- and this rig does not claim to be it.
##
## ---------------------------------------------------------------------------------------
## THE RIG. This node sits ON the ground at the focus point and turns about Y (yaw); the
## Camera3D it creates is its child, lifted back along the rig's +Z and up by the pitch, and
## tilted down by the same pitch, so it always looks at the focus without a `look_at()` call.
## Perspective, 40 degree vertical field of view, 50 degree default pitch.
##
## INPUT. Only the actions `project.godot` already defines are read; none is invented:
##   camera_pan_left/right/forward/back   WASD and arrows  -- held, relative to the view
##   camera_rotate_left/right             Q / E            -- held; right turns the view right
##   camera_zoom_in/out                   wheel, PgUp/PgDn -- one step per notch or repeat
##   camera_pitch_up/down                 Alt+PgUp/PgDn    -- one step per press or repeat
##   camera_home                          Home             -- back to the configured view
## Everything arrives through `_unhandled_input`, so a click or key the HUD consumed never moves
## the camera. Held keys are tracked from their own press and release events rather than polled,
## for the same reason. Zoom is matched EXACTLY (no extra modifiers), because Alt+PgUp is pitch
## and would otherwise also zoom.
##
## MOTION. Input moves TARGET values; `_process` eases the shown values toward them with an
## exponential damp, so the camera glides and stops softly. The focus is clamped to the AABB
## given to `configure()`, distance and pitch to fixed ranges. `_process` allocates nothing.

const FOV_DEGREES: float = 40.0
const NEAR_PLANE: float = 0.1
const FAR_PLANE: float = 500.0

const PITCH_DEFAULT_DEGREES: float = 50.0
const PITCH_MIN_DEGREES: float = 30.0
const PITCH_MAX_DEGREES: float = 75.0
const PITCH_STEP_DEGREES: float = 4.0

## Distance from the focus to the eye, in metres. The default frames a 40 m village.
const DISTANCE_DEFAULT: float = 38.0
const DISTANCE_MIN: float = 7.0
const DISTANCE_MAX: float = 70.0
## Each zoom notch multiplies the distance by (1 - ZOOM_STEP) inward, or divides by it outward.
const ZOOM_STEP: float = 0.12

## Pan speed in metres per second per metre of distance, so a zoomed-out pan covers more ground.
const PAN_SPEED_PER_METRE: float = 0.75
const ROTATE_SPEED_DEGREES: float = 90.0
## Exponential damping rate, per second: higher settles faster.
const DAMPING: float = 9.0

const ACTION_PAN_LEFT: StringName = &"camera_pan_left"
const ACTION_PAN_RIGHT: StringName = &"camera_pan_right"
const ACTION_PAN_FORWARD: StringName = &"camera_pan_forward"
const ACTION_PAN_BACK: StringName = &"camera_pan_back"
const ACTION_ROTATE_LEFT: StringName = &"camera_rotate_left"
const ACTION_ROTATE_RIGHT: StringName = &"camera_rotate_right"
const ACTION_ZOOM_IN: StringName = &"camera_zoom_in"
const ACTION_ZOOM_OUT: StringName = &"camera_zoom_out"
const ACTION_PITCH_UP: StringName = &"camera_pitch_up"
const ACTION_PITCH_DOWN: StringName = &"camera_pitch_down"
const ACTION_HOME: StringName = &"camera_home"

## The held actions, in `_held` index order.
const HELD_ACTIONS: Array[StringName] = [
	ACTION_PAN_LEFT, ACTION_PAN_RIGHT, ACTION_PAN_FORWARD, ACTION_PAN_BACK,
	ACTION_ROTATE_LEFT, ACTION_ROTATE_RIGHT,
]
const HELD_LEFT: int = 0
const HELD_RIGHT: int = 1
const HELD_FORWARD: int = 2
const HELD_BACK: int = 3
const HELD_ROTATE_LEFT: int = 4
const HELD_ROTATE_RIGHT: int = 5

var _camera: Camera3D = null
var _bounds: AABB = AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 0.0, 40.0))
## The configured view, for camera_home.
var _home_focus: Vector3 = Vector3.ZERO
## Where input has asked the camera to be, and where it is drawn this frame.
var _target_focus: Vector3 = Vector3.ZERO
var _focus: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _yaw: float = 0.0
var _target_pitch: float = deg_to_rad(PITCH_DEFAULT_DEGREES)
var _pitch: float = deg_to_rad(PITCH_DEFAULT_DEGREES)
var _target_distance: float = DISTANCE_DEFAULT
var _distance: float = DISTANCE_DEFAULT
## 1 while the matching HELD_ACTIONS entry is down, from its own press/release events.
var _held: PackedByteArray = PackedByteArray()
## Scratch for the eye's local position, reused every frame.
var _eye: Vector3 = Vector3.ZERO


func _init() -> void:
	"""Create the Camera3D this rig owns, and size the held-key table once."""
	name = "DemoCamera"
	_held.resize(HELD_ACTIONS.size())
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = FOV_DEGREES
	_camera.near = NEAR_PLANE
	_camera.far = FAR_PLANE
	add_child(_camera)
	_apply_pose()


func configure(bounds: AABB, focus: Vector3) -> void:
	"""Set the ground box the focus may roam and the point to start over, and snap there."""
	_bounds = bounds.abs()
	_home_focus = clamp_focus(focus, _bounds)
	reset_view()


func reset_view() -> void:
	"""Return to the configured focus, facing north, at the default pitch and distance."""
	_target_focus = _home_focus
	_target_yaw = 0.0
	_target_pitch = deg_to_rad(PITCH_DEFAULT_DEGREES)
	_target_distance = DISTANCE_DEFAULT
	snap()


func make_current() -> void:
	"""Make this rig's camera the viewport's active camera."""
	if _camera.is_inside_tree():
		_camera.make_current()
	else:
		_camera.current = true


func snap() -> void:
	"""Jump the drawn view straight to its targets, skipping the easing."""
	_focus = _target_focus
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_apply_pose()


func _unhandled_input(event: InputEvent) -> void:
	"""Camera input the HUD did not consume. Marks what it uses as handled."""
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	"""Apply one input event to the targets. Returns true when the event was a camera action."""
	if _track_held(event):
		return true
	if event.is_action_pressed(ACTION_PITCH_UP, true):
		return _pitch_by(PITCH_STEP_DEGREES)
	if event.is_action_pressed(ACTION_PITCH_DOWN, true):
		return _pitch_by(-PITCH_STEP_DEGREES)
	if event.is_action_pressed(ACTION_ZOOM_IN, true, true):
		return _zoom_by(1)
	if event.is_action_pressed(ACTION_ZOOM_OUT, true, true):
		return _zoom_by(-1)
	if event.is_action_pressed(ACTION_HOME):
		reset_view()
		return true
	return false


func _track_held(event: InputEvent) -> bool:
	"""Record a press, repeat or release of one of the held actions."""
	for index: int in HELD_ACTIONS.size():
		if event.is_action(HELD_ACTIONS[index]):
			_held[index] = 1 if event.is_pressed() else 0
			return true
	return false


func _notification(what: int) -> void:
	"""Drop every held key when the window loses focus, so no release is missed."""
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_held.fill(0)


func _zoom_by(notches: int) -> bool:
	"""Move the target distance by whole zoom notches; positive is inward."""
	_target_distance = zoomed_distance(_target_distance, notches)
	return true


func _pitch_by(degrees: float) -> bool:
	"""Tilt the target pitch by some degrees, within the pitch limits."""
	_target_pitch = clamp_pitch(_target_pitch + deg_to_rad(degrees))
	return true


func _process(delta: float) -> void:
	"""Advance the held pan and rotation, then ease the drawn view toward its targets."""
	step(delta)


func step(delta: float) -> void:
	"""One frame of motion: held input moves the targets, the view eases after them.

	Written component by component so a frame builds no new vectors."""
	var strafe: float = float(_held[HELD_RIGHT]) - float(_held[HELD_LEFT])
	var advance: float = float(_held[HELD_FORWARD]) - float(_held[HELD_BACK])
	var turn: float = float(_held[HELD_ROTATE_LEFT]) - float(_held[HELD_ROTATE_RIGHT])
	_target_yaw += deg_to_rad(ROTATE_SPEED_DEGREES) * turn * delta
	if strafe != 0.0 or advance != 0.0:
		var metres: float = PAN_SPEED_PER_METRE * _target_distance * delta
		_target_focus.x += (strafe * cos(_target_yaw) - advance * sin(_target_yaw)) * metres
		_target_focus.z += (-strafe * sin(_target_yaw) - advance * cos(_target_yaw)) * metres
		_clamp_target_focus()
	var blend: float = damp_factor(DAMPING, delta)
	_focus.x = lerpf(_focus.x, _target_focus.x, blend)
	_focus.y = lerpf(_focus.y, _target_focus.y, blend)
	_focus.z = lerpf(_focus.z, _target_focus.z, blend)
	_yaw = lerpf(_yaw, _target_yaw, blend)
	_pitch = lerpf(_pitch, _target_pitch, blend)
	_distance = lerpf(_distance, _target_distance, blend)
	_apply_pose()


func _clamp_target_focus() -> void:
	"""Hold the target focus inside the ground box, in place."""
	var low: Vector3 = _bounds.position
	_target_focus.x = clampf(_target_focus.x, low.x, low.x + _bounds.size.x)
	_target_focus.y = clampf(_target_focus.y, low.y, low.y + _bounds.size.y)
	_target_focus.z = clampf(_target_focus.z, low.z, low.z + _bounds.size.z)


func _apply_pose() -> void:
	"""Place the rig at the focus, turned by yaw, and its camera back and up by the pitch."""
	position = _focus
	rotation.y = _yaw
	_eye.x = 0.0
	_eye.y = sin(_pitch) * _distance
	_eye.z = cos(_pitch) * _distance
	_camera.position = _eye
	_camera.rotation.x = -_pitch


# --- the pure math, public so the suite can check it without a tree -------------------------------

static func clamp_focus(point: Vector3, bounds: AABB) -> Vector3:
	"""A focus point held inside the ground box on every axis."""
	var low: Vector3 = bounds.position
	var high: Vector3 = bounds.end
	return Vector3(clampf(point.x, low.x, high.x), clampf(point.y, low.y, high.y),
		clampf(point.z, low.z, high.z))


static func zoomed_distance(distance: float, notches: int) -> float:
	"""The distance after some zoom notches (positive inward), inside the zoom limits."""
	return clampf(distance * pow(1.0 - ZOOM_STEP, float(notches)), DISTANCE_MIN, DISTANCE_MAX)


static func clamp_pitch(pitch: float) -> float:
	"""A pitch in radians held inside the pitch limits."""
	return clampf(pitch, deg_to_rad(PITCH_MIN_DEGREES), deg_to_rad(PITCH_MAX_DEGREES))


static func damp_factor(rate: float, delta: float) -> float:
	"""How far to close the gap to a target this frame: frame-rate independent, 0..1."""
	return 1.0 - exp(-maxf(rate, 0.0) * maxf(delta, 0.0))


# --- read-back ------------------------------------------------------------------------------------

func camera() -> Camera3D:
	"""The Camera3D this rig owns."""
	return _camera


func focus() -> Vector3:
	"""The ground point the view is centred on this frame."""
	return _focus


func target_focus() -> Vector3:
	"""The ground point input has asked for."""
	return _target_focus


func distance() -> float:
	"""The eye's distance from the focus this frame, in metres."""
	return _distance


func target_distance() -> float:
	"""The distance input has asked for."""
	return _target_distance


func pitch_degrees() -> float:
	"""The downward tilt this frame, in degrees."""
	return rad_to_deg(_pitch)


func yaw_degrees() -> float:
	"""The heading this frame, in degrees; 0 looks toward -Z."""
	return rad_to_deg(_yaw)


func bounds() -> AABB:
	"""The ground box the focus is held inside."""
	return _bounds
