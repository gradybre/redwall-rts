extends CanvasLayer
## FOCUS HINTS: where the keyboard's focus is, one line says what it is and which keys work there. Decision 0471
## (review UX-023, the Keyboard planner preset). DEMO UI.
##
## Shown only for a DRAWN focus -- the keyboard's (Tab, F7, a modal's first control; Godot 4.7 `has_focus(true)`),
## never a click's -- and only with "Focus hints" on. The line sits just under the focused control (above it when there
## is no room below), at the HUD's scale, and never takes the mouse. It names the control (its text, else its
## tooltip's first line) and the keys the input gate gives it: Enter presses, Tab and Shift+Tab move, F7 changes
## region, Esc leaves (demo_input_gate.gd). It is re-placed only when the focus or its rectangle changed.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")

## Above the modals (2) and the stall banner (3): a hint is about whatever holds the focus.
const LAYER: int = 4
const KEYS: String = "Enter: press · Tab / Shift+Tab: next / previous · F7: next region · Esc: back"
const KEYS_TOGGLE: String = "Enter: switch · Tab / Shift+Tab: next / previous · F7: next region · Esc: back"
## In a pop-up F7 does nothing (the gate keeps focus inside); Esc closes it.
const KEYS_MODAL: String = "Enter: press · Tab / Shift+Tab: next / previous · Esc: close"
const KEYS_MODAL_TOGGLE: String = "Enter: switch · Tab / Shift+Tab: next / previous · Esc: close"
const MAX_W: float = 420.0
const GAP: float = 6.0
const PX: int = 14
const MARGINS: PackedFloat32Array = [10.0, 5.0, 10.0, 6.0]

var enabled: bool = false
## `() -> bool`: whether a pop-up holds the focus (its keys differ: no F7, Esc closes).
var modal_open: Callable = Callable()

var _frame: PanelContainer = null
var _line: Label = null
var _for: Control = null
var _rect: Rect2 = Rect2()
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Hidden; one small frame with one line."""
	name = "FocusHint"
	layer = LAYER
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_MAP, MARGINS))
	_frame.visible = false
	add_child(_frame)
	_line = FarmUi.label("", PX, Palette.INK)
	_line.custom_minimum_size.x = MAX_W - MARGINS[0] - MARGINS[2]
	_frame.add_child(_line)


func _process(_delta: float) -> void:
	"""Follow the keyboard's focus."""
	var owner: Control = get_viewport().gui_get_focus_owner() if enabled else null
	if owner != null and not owner.has_focus(true):
		owner = null
	if owner == null:
		_for = null
		_frame.visible = false
		return
	var rect: Rect2 = GateScript.screen_rect(owner)
	if owner == _for and rect == _rect and _frame.visible:
		return
	_for = owner
	_rect = rect
	_line.text = hint_text(owner, modal_open.is_valid() and bool(modal_open.call()))
	_frame.visible = true
	_place(rect)


static func hint_text(control: Control, in_modal: bool = false) -> String:
	"""'Resume — Enter: press · Tab ...' -- what the control is, then its keys (in a pop-up: its own)."""
	var what: String = ""
	var button := control as BaseButton
	if control is Button:
		what = (control as Button).text
	if what.strip_edges().is_empty():
		what = control.tooltip_text.get_slice("\n", 0)
	if what.strip_edges().is_empty():
		what = String(control.name)
	var toggle: bool = button != null and button.toggle_mode
	var keys: String = (KEYS_MODAL_TOGGLE if toggle else KEYS_MODAL) if in_modal else (KEYS_TOGGLE if toggle else KEYS)
	return "%s — %s" % [what.strip_edges(), keys]


func _place(rect: Rect2) -> void:
	"""Under the control, or above it near the bottom, held on screen, at the HUD's scale."""
	var view: Vector2 = get_viewport().get_visible_rect().size
	FarmUi.geometry_for(view, _layout, _geometry)
	var scale: float = _geometry.scale
	_frame.scale = Vector2(scale, scale)
	_frame.reset_size()
	var size: Vector2 = _frame.get_combined_minimum_size() * scale
	var at := Vector2(rect.position.x, rect.end.y + GAP * scale)
	if at.y + size.y > view.y:
		at.y = rect.position.y - GAP * scale - size.y
	at.x = clampf(at.x, 0.0, maxf(view.x - size.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.y - size.y, 0.0))
	_frame.position = at


func shown_text() -> String:
	"""The hint shown now ("" when none)."""
	return _line.text if _frame.visible else ""
