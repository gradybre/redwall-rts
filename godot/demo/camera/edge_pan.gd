extends Node
## EDGE PAN (decision 0801; UI §6 "Edge-scroll band: 12 logical pixels; 250 ms dwell", §6's paragraph on when it is
## off). Resting the pointer in the band along a window edge, for the dwell, pans the camera that way at the rig's own
## pan speed, as a held key does (demo_camera.gd `set_edge_push`; a corner pans diagonally, normalised). PRESENTATION.
##
## THE BAND is 12 LOGICAL pixels -- 12 physical at 1280x720 and 1920x1080, 24 at 3840x2160 (UI §1.2's S, with the
## interface scale) -- so it is the same reach for the hand at every size the demo supports.
##
## IT IS OFF when the menu's Settings turn Edge scroll off (UI §8.1 `edge_scroll`, on by default; demo_access.gd), and
## (UI §6: "disabled while pointer is over any visible UI hit rectangle, during a modal, text editing,
## placement drag, or when the application lacks focus"):
##   * over any HUD or demo control that takes the pointer (`gui_get_hovered_control`);
##   * while a modal is open (`modal_open`, the input gate's);
##   * while a text field has the focus;
##   * while any mouse button is held -- a placement or box drag, the middle drag's turn;
##   * while the window does not have the focus, or the pointer has left it (`focused`); never in a headless run (whose
##     root reports the focus), so the suites' live harnesses do not pan by accident unless they say so;
##   * until the pointer has moved inside the window at all (no pointer: no edge).
## Leaving the band resets the dwell. The pointer is read from the motion events this node sees in `_input` (it never
## consumes one), so `_process` allocates nothing.

const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Access := preload("res://demo/access/demo_access.gd")

const BAND_LOGICAL_PX: float = 12.0
const DWELL_SECONDS: float = 0.25

## `modal_open() -> bool`: whether a modal holds the input (demo_input_gate.gd `modal_open`).
var modal_open: Callable = Callable()
## `focused() -> bool`: whether the window has the focus (the window's own, unless a harness says otherwise).
var focused: Callable = Callable()

var _rig: Node3D = null
var _viewport: Viewport = null
var _pointer: Vector2 = Vector2.ZERO
var _inside: bool = false
var _buttons: int = 0
var _dwell: float = 0.0
## The push this frame (x across, y forward), for the checks.
var _push: Vector2 = Vector2.ZERO


func _init() -> void:
	"""Named for the scene tree."""
	name = "EdgePan"


func configure(rig: Node3D) -> void:
	"""Push `rig` (demo_camera.gd) from the window's edges."""
	_rig = rig


func _ready() -> void:
	"""Keep the viewport, read every frame."""
	_viewport = get_viewport()


func _input(event: InputEvent) -> void:
	"""Where the pointer is, and which buttons are down (never consumed)."""
	note_event(event)


func note_event(event: InputEvent) -> void:
	"""Take the pointer's place and buttons from one event."""
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
		_inside = true
		_buttons = motion.button_mask
		return
	var button := event as InputEventMouseButton
	if button != null:
		_pointer = button.position
		_buttons = button.button_mask


func _notification(what: int) -> void:
	"""The pointer leaving the window, or the window its focus, ends the edge pan until the pointer moves in again."""
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_inside = false
		_dwell = 0.0


func _process(delta: float) -> void:
	"""One frame: push the rig while the pointer has rested in the band long enough."""
	if _viewport == null or _rig == null:
		return
	step(delta, _viewport.get_visible_rect().size)


func step(delta: float, size_px: Vector2) -> void:
	"""Advance the dwell and set the rig's push for a window of `size_px` (real seconds; the checks call it)."""
	var pushing: Vector2 = Vector2.ZERO
	if allowed():
		pushing = edge_push(_pointer, size_px, band_px(size_px))
	_dwell = _dwell + delta if pushing != Vector2.ZERO else 0.0
	_push = pushing if _dwell >= DWELL_SECONDS else Vector2.ZERO
	if _rig != null:
		_rig.call(&"set_edge_push", _push.x, _push.y)


func allowed() -> bool:
	"""Whether nothing turns the edge pan off now (see IT IS OFF)."""
	if not Access.is_on(Access.SET_EDGE_SCROLL) or not _inside or _buttons != 0:
		return false
	if modal_open.is_valid() and bool(modal_open.call()):
		return false
	if not _has_focus():
		return false
	if _viewport == null:
		return true
	var typing: Control = _viewport.gui_get_focus_owner()
	if typing is LineEdit or typing is TextEdit:
		return false
	return _viewport.gui_get_hovered_control() == null


func _has_focus() -> bool:
	"""The window's focus (or the harness's word for it)."""
	if focused.is_valid():
		return bool(focused.call())
	if DisplayServer.get_name() == "headless":
		return false
	return is_inside_tree() and get_window().has_focus()


func push() -> Vector2:
	"""The push this frame: x across (right +), y along the view (forward +), each -1, 0 or 1."""
	return _push


static func band_px(size_px: Vector2) -> float:
	"""The band's depth in physical pixels for a window of `size_px`: 12 logical pixels at the interface's S."""
	return BAND_LOGICAL_PX * DemoUiScale.effective_scale(size_px)


static func edge_push(pointer: Vector2, size_px: Vector2, band: float) -> Vector2:
	"""Which way a pointer at `pointer` in a `size_px` window pushes: x -1 at the left edge, +1 at the right; y +1
	(forward) at the top, -1 at the bottom; zero outside the band (and for a pointer off the window)."""
	if pointer.x < 0.0 or pointer.y < 0.0 or pointer.x > size_px.x or pointer.y > size_px.y:
		return Vector2.ZERO
	var across: float = -1.0 if pointer.x < band else (1.0 if pointer.x >= size_px.x - band else 0.0)
	var along: float = 1.0 if pointer.y < band else (-1.0 if pointer.y >= size_px.y - band else 0.0)
	return Vector2(across, along)

