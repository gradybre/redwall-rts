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
## and one mouse gesture no action names (the playtest of 2026-09-29, decision 0205):
##   middle-button drag                   turns the view: across is yaw (right turns it right, as E),
##                                        up and down is pitch (up looks toward the horizon)
## Everything arrives through `_unhandled_input`, so a click or key the HUD consumed never moves
## the camera; the middle button's PRESS arrives the same way (a press on the HUD starts nothing), and
## while it is held its drag is read in `_input`, before anything else can take the motion (the
## tunnel tool follows the pointer). Held keys are tracked from their own press and release events rather than polled,
## for the same reason. Zoom is matched EXACTLY (no extra modifiers), because Alt+PgUp is pitch
## and would otherwise also zoom.
##
## MOTION. Input moves TARGET values; `_process` eases the shown values toward them with an
## exponential damp, so the camera glides and stops softly. The focus is clamped to the AABB
## given to `configure()`, distance and pitch to fixed ranges. `_process` allocates nothing.
##
## CLEARANCE (decision 0301, review F53). A clearance provider (`set_clearance`: canopy_clear.gd's
## `allowed_distance`) may move the drawn eye along its own line, nearer or farther than the zoom asks,
## so it never sits inside a tree crown. The move is made AT ONCE (no frame is drawn inside the crown) and
## the eye eases back with the ordinary damp once the way is clear; the zoom TARGET is never changed, so
## the player's zoom comes back by itself.
##
## REDUCED MOTION (decision 0471, UI §6 "Reduced motion: camera smoothing off"): the shown values take their targets
## at once -- no easing -- while movement stays continuous and the player's own.
##
## THE MODES' HOOKS (decision 0801, camera_modes.gd). The follow, the orbit, the bookmarks and the cutaway angle move
## the targets through `track` and `aim` (and the orbit through `turn_target`), which the player's own moves are told
## apart from by two REVISIONS: `pan_revision` counts every frame the player moved the view's centre (a held pan, the
## edge pan, `centre_on` -- the minimap, the roster, a "Go to" -- and Home), `turn_revision` every frame they turned it
## (Q / E, the middle drag across; a drag up or down only tilts). A follow ends when the first moves, an orbit when
## either does (UI §5: "manual camera movement cancels follow"). The EDGE PAN (edge_pan.gd) pushes through `set_edge_push`, added to the held keys; a
## diagonal is normalised (UI §5: "diagonal normalized"), so W+D is no faster than W. The middle drag turns per LOGICAL
## pixel (UI §1.2's S, as UI §6's drag-pan is "divided by S"), so the same sweep turns as far at 720p as at 4K.

const DemoMotion := preload("res://demo/access/demo_motion.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

const FOV_DEGREES: float = 40.0
const NEAR_PLANE: float = 0.1
const FAR_PLANE: float = 500.0

const PITCH_DEFAULT_DEGREES: float = 50.0
const PITCH_MIN_DEGREES: float = 30.0
const PITCH_MAX_DEGREES: float = 75.0
const PITCH_STEP_DEGREES: float = 4.0

## Distance from the focus to the eye, in metres. 22 m frames the village square with its residents readable: at 38 m (the whole clearing) a
## 1 m mouse is a few pixels tall at 1080p. Zoom out for the whole village.
const DISTANCE_DEFAULT: float = 22.0
const DISTANCE_MIN: float = 7.0
const DISTANCE_MAX: float = 70.0
## Each zoom notch multiplies the distance by (1 - ZOOM_STEP) inward, or divides by it outward.
const ZOOM_STEP: float = 0.12

## Pan speed in metres per second per metre of distance, so a zoomed-out pan covers more ground.
const PAN_SPEED_PER_METRE: float = 0.75
const ROTATE_SPEED_DEGREES: float = 90.0
## Middle-button drag: degrees of yaw and of pitch per pixel the pointer moves (demo values, 0205).
const DRAG_YAW_DEGREES_PER_PX: float = 0.3
const DRAG_PITCH_DEGREES_PER_PX: float = 0.2
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
## True while a middle-button drag is turning the view.
var _drag_turning: bool = false
## Scratch for the eye's local position, reused every frame.
var _eye: Vector3 = Vector3.ZERO
## `clearance(focus, yaw, pitch, distance) -> float`: where the eye may sit (see CLEARANCE).
var _clearance: Callable = Callable()
## Frames the player moved the view's centre, and turned it (see THE MODES' HOOKS).
var _pan_revision: int = 0
var _turn_revision: int = 0
## The edge pan's push this frame, -1..1 across (right +) and along (forward +) the view.
var _edge_strafe: float = 0.0
var _edge_advance: float = 0.0


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
	_pan_revision += 1
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


func centre_on(point: Vector3) -> void:
	"""Ease the view to look at `point` (x, z; held inside the ground box), keeping yaw, pitch and zoom: the
	Residents roster's and the minimap's "go there" (decision 0251), and the news's "Go to" (decision 0331)."""
	_target_focus.x = point.x
	_target_focus.z = point.z
	_clamp_target_focus()
	_pan_revision += 1


func track(point: Vector3) -> void:
	"""Ease the view's centre over `point` (x, z) as the follow does, each frame: not the player's pan."""
	_target_focus.x = point.x
	_target_focus.z = point.z
	_clamp_target_focus()


func aim(point: Vector3, yaw_deg: float, pitch_deg: float, metres: float) -> void:
	"""Ease to a whole view -- a bookmark, the orbit's framing, the cutaway angle: the centre (x, z, in the ground box),
	the heading by the shorter way round, the pitch and the distance inside their limits. Not the player's pan."""
	_target_focus.x = point.x
	_target_focus.z = point.z
	_clamp_target_focus()
	_target_yaw = nearest_turn(_target_yaw, deg_to_rad(yaw_deg))
	_target_pitch = clamp_pitch(deg_to_rad(pitch_deg))
	_target_distance = clampf(metres, DISTANCE_MIN, DISTANCE_MAX)


func turn_target(radians: float) -> void:
	"""Turn the target heading by `radians` (positive turns left, as Q): the orbit's turn, not the player's."""
	_target_yaw += radians


func set_edge_push(strafe: float, advance: float) -> void:
	"""The edge pan's push for the frames to come, each -1, 0 or 1 (edge_pan.gd): right and forward are positive. Added
	to the held keys, the sum held to -1..1 (`_pan_by_held`)."""
	_edge_strafe = strafe
	_edge_advance = advance


func snap() -> void:
	"""Jump the drawn view straight to its targets, skipping the easing."""
	_focus = _target_focus
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_clear_view()
	_apply_pose()


func set_clearance(clearance: Callable) -> void:
	"""Place the drawn eye where `clearance(focus, yaw, pitch, distance) -> float` allows (see CLEARANCE)."""
	_clearance = clearance


func _clear_view() -> void:
	"""Move the drawn distance to where the clearance provider allows (nothing without one, nor for an
	answer that is not a finite distance)."""
	if not _clearance.is_valid():
		return
	var allowed: float = float(_clearance.call(_focus, _yaw, _pitch, _distance))
	if is_finite(allowed):
		_distance = allowed


func _unhandled_input(event: InputEvent) -> void:
	"""Camera input the HUD did not consume. Marks what it uses as handled."""
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	"""While a middle-button drag turns the view, its motion and its release are the camera's."""
	if _drag_turning and drag_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	"""Apply one input event to the targets. Returns true when the event was a camera action."""
	if _track_held(event):
		return true
	if drag_input(event):
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


func drag_input(event: InputEvent) -> bool:
	"""The middle-button drag: its press starts turning, its release (or motion with the button no
	longer held) stops, and motion between turns the target yaw and pitch. True when used."""
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_MIDDLE:
		_drag_turning = button.pressed
		return true
	var motion := event as InputEventMouseMotion
	if motion == null or not _drag_turning:
		return false
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
		_drag_turning = false
		return false
	var logical: float = _pixel_scale()
	_target_yaw -= deg_to_rad(DRAG_YAW_DEGREES_PER_PX) * motion.relative.x / logical
	_target_pitch = clamp_pitch(_target_pitch + deg_to_rad(DRAG_PITCH_DEGREES_PER_PX) * motion.relative.y / logical)
	if motion.relative.x != 0.0:
		_turn_revision += 1
	return true


func _pixel_scale() -> float:
	"""Physical pixels per logical pixel in this rig's viewport (UI §1.2's S; 1.0 off-tree)."""
	if not is_inside_tree():
		return 1.0
	return maxf(DemoUiScale.effective_scale(get_viewport().get_visible_rect().size), 0.01)


func is_drag_turning() -> bool:
	"""Whether a middle-button drag is turning the view."""
	return _drag_turning


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
		_drag_turning = false


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
	_turn_by_held(delta)
	_pan_by_held(delta)
	var blend: float = 1.0 if DemoMotion.reduced else damp_factor(DAMPING, delta)
	_focus.x = lerpf(_focus.x, _target_focus.x, blend)
	_focus.y = lerpf(_focus.y, _target_focus.y, blend)
	_focus.z = lerpf(_focus.z, _target_focus.z, blend)
	_yaw = lerpf(_yaw, _target_yaw, blend)
	_pitch = lerpf(_pitch, _target_pitch, blend)
	_distance = lerpf(_distance, _target_distance, blend)
	_clear_view()
	_apply_pose()


func _turn_by_held(delta: float) -> void:
	"""Q / E held turn the target heading (a turn the player made)."""
	var turn: float = float(_held[HELD_ROTATE_LEFT]) - float(_held[HELD_ROTATE_RIGHT])
	if turn != 0.0:
		_target_yaw += deg_to_rad(ROTATE_SPEED_DEGREES) * turn * delta
		_turn_revision += 1


func _pan_by_held(delta: float) -> void:
	"""The held pan keys and the edge pan move the target centre along the view, a diagonal no faster than a
	straight pan (a pan the player made)."""
	var strafe: float = clampf(float(_held[HELD_RIGHT]) - float(_held[HELD_LEFT]) + _edge_strafe, -1.0, 1.0)
	var advance: float = clampf(float(_held[HELD_FORWARD]) - float(_held[HELD_BACK]) + _edge_advance, -1.0, 1.0)
	if strafe == 0.0 and advance == 0.0:
		return
	var length: float = maxf(sqrt(strafe * strafe + advance * advance), 1.0)
	var metres: float = PAN_SPEED_PER_METRE * _target_distance * delta / length
	_target_focus.x += (strafe * cos(_target_yaw) - advance * sin(_target_yaw)) * metres
	_target_focus.z += (-strafe * sin(_target_yaw) - advance * cos(_target_yaw)) * metres
	_clamp_target_focus()
	_pan_revision += 1


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


static func nearest_turn(from: float, to: float) -> float:
	"""A heading equal to `to` (radians, modulo a whole turn) no more than half a turn from `from`."""
	return from + wrapf(to - from, -PI, PI)


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


func target_pitch_degrees() -> float:
	"""The pitch input has asked for, in degrees."""
	return rad_to_deg(_target_pitch)


func target_yaw_degrees() -> float:
	"""The heading input has asked for, in degrees (not wrapped)."""
	return rad_to_deg(_target_yaw)


func pan_revision() -> int:
	"""How many frames the player has moved the view's centre (see THE MODES' HOOKS)."""
	return _pan_revision


func turn_revision() -> int:
	"""How many frames the player has turned the view (see THE MODES' HOOKS)."""
	return _turn_revision


func pitch_degrees() -> float:
	"""The downward tilt this frame, in degrees."""
	return rad_to_deg(_pitch)


func yaw_degrees() -> float:
	"""The heading this frame, in degrees; 0 looks toward -Z."""
	return rad_to_deg(_yaw)


func bounds() -> AABB:
	"""The ground box the focus is held inside."""
	return _bounds
