extends Control
## One §3 layer-80 modal: SCRIM, the UI-SET-051 MODAL frame, its title, a header line, a scrolling
## body and the fixed 60 px confirmation footer (§2.2), plus UI-SET-093's close button.
##
## The save browser (UI-SET-076) and the game menu (UI-SET-078) are built on this. It is laid out
## from the HUD shell's own §1.2 geometry (`layout()`): the frame is centred inside the modal
## rectangle `min(960, Lw-32)` by `min(720, Lh-32)` at the shell's scale S, so it moves with every
## resolution from 1280x720 to 3840x2160 exactly as the HUD does. Inside the frame, containers
## place the parts, so wrapped text (a refusal in the status line) grows its row instead of
## overlapping the next one, and the body alone scrolls (§1.3 "Large text").
##
## INPUT. The SCRIM is MOUSE_FILTER_STOP over the whole viewport, so nothing below takes a click
## while the modal shows; focus is held in a ring of the modal's own controls (`set_focus_ring()`),
## and Escape asks the owner to dismiss exactly one layer (`dismiss_requested`). This node holds no
## game state. Presentation only: layout reads the shell's presentation geometry.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

signal dismiss_requested

const THEME_PATH: String = "res://ui/theme/woodland_theme.tres"
const LOCK_ICON_PATH: String = "res://ui/icons/lock.svg"
const CLOSE_ICON_PATH: String = "res://ui/icons/cancel.svg"
const FOOTER_HEIGHT: float = UiRegistry.CONFIRMATION_FOOTER_PX
const PADDING: int = 12
const GAP: int = 8
const CLOSE_SIZE: float = 44.0
const BUTTON_HEIGHT: float = 44.0
const SHOW_SECONDS: float = UiTheme.SHOW_SECONDS

var _frame: Panel = null
var _column: VBoxContainer = null
var _title: Label = null
var _header: VBoxContainer = null
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null
var _footer: HBoxContainer = null
var _close: Button = null
var _preferred: Vector2 = Vector2(480.0, 320.0)
var _fit_height: bool = false
var _ring: Array[Control] = []
## The last `layout()` arguments, so a change of content can re-fit the frame (`relayout()`).
var _logical: Rect2 = Rect2()
var _modal: Rect2 = Rect2()
var _scale: float = 0.0


func build(title: String, frame_key: String, preferred: Vector2, fit_height: bool = false) -> void:
	"""Create the scrim, the frame and its fixed parts. `preferred` is the §4 maximum size; with
	`fit_height` the frame is only as tall as its content (the game menu)."""
	name = frame_key
	theme = load(THEME_PATH) as Theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preferred = preferred
	_fit_height = fit_height
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiTheme.color_of(UiTheme.TOKEN_SCRIM)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.theme_type_variation = &"WoodlandModal"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.accessibility_name = title
	add_child(_frame)
	_build_column()
	_build_title(title)
	_build_body()
	visible = false


func _build_column() -> void:
	"""The padded column every part sits in."""
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, PADDING)
	_frame.add_child(margin)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override(&"separation", GAP)
	margin.add_child(_column)


func _build_title(title: String) -> void:
	"""The 28/700 title beside UI-SET-093's close button, and the header line under them."""
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "Top"
	_column.add_child(top)
	_title = Label.new()
	_title.name = "Title"
	_title.text = title
	_title.theme_type_variation = &"WoodlandPageTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_title)
	_close = new_button("UI-SET-093_close", "", "Close %s" % title)
	_close.icon = load(CLOSE_ICON_PATH) as Texture2D
	_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	_close.pressed.connect(func() -> void: dismiss_requested.emit())
	top.add_child(_close)
	_header = VBoxContainer.new()
	_header.name = "Header"
	_header.add_theme_constant_override(&"separation", GAP)
	_column.add_child(_header)


func _build_body() -> void:
	"""The scrolling body column and the fixed footer row."""
	_scroll = ScrollContainer.new()
	_scroll.name = "Body"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.name = "Content"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", GAP)
	_scroll.add_child(_body)
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.custom_minimum_size = Vector2(0.0, FOOTER_HEIGHT - PADDING)
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override(&"separation", GAP)
	_column.add_child(_footer)


static func new_button(key: String, text: String, accessible: String) -> Button:
	"""A §2.2 BUTTON-profile control with a stable registry key and an accessible name."""
	var button: Button = Button.new()
	button.name = key
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = &"WoodlandButton"
	button.custom_minimum_size = Vector2(96.0, BUTTON_HEIGHT)
	button.accessibility_name = "%s %s" % [key.get_slice("_", 0), accessible]
	return button


static func make_unavailable(button: Button, reason: String) -> void:
	"""§2.2's disabled BUTTON: MUTED text, the lock icon, and the reason for eye and screen reader."""
	button.disabled = true
	button.icon = load(LOCK_ICON_PATH) as Texture2D
	button.tooltip_text = reason
	button.accessibility_description = reason


func header() -> VBoxContainer:
	"""The line under the title (the browser's development-only note and its tabs)."""
	return _header


func body() -> VBoxContainer:
	"""The scrolling content column."""
	return _body


func footer() -> HBoxContainer:
	"""The fixed confirmation footer row."""
	return _footer


func close_button() -> Button:
	"""UI-SET-093."""
	return _close


func layout(logical: Rect2, modal: Rect2, scale_factor: float) -> void:
	"""Place the frame centred in the shell's modal rectangle, at the shell's scale."""
	_logical = logical
	_modal = modal
	_scale = scale_factor
	scale = Vector2(scale_factor, scale_factor)
	position = Vector2.ZERO
	size = logical.size
	var width: float = minf(_preferred.x, modal.size.x)
	var height: float = minf(_preferred.y, modal.size.y)
	if _fit_height:
		height = minf(height, _content_height())
	_frame.position = modal.position + Vector2((modal.size.x - width) / 2.0,
		(modal.size.y - height) / 2.0)
	_frame.size = Vector2(width, height)


func relayout() -> void:
	"""Lay out again on the last geometry (a fitted frame whose content changed)."""
	if _scale > 0.0:
		layout(_logical, _modal, _scale)


func _content_height() -> float:
	"""The column's height with the body unscrolled: every part's minimum plus the body content."""
	return _column.get_combined_minimum_size().y + _body.get_combined_minimum_size().y \
		+ 2.0 * PADDING


func set_focus_ring(controls: Array[Control]) -> void:
	"""Hold keyboard focus inside this modal: Tab and Shift+Tab cycle through `controls`."""
	_ring = controls.filter(func(control: Control) -> bool:
		return control != null and control.visible and control.focus_mode != Control.FOCUS_NONE)
	for index: int in _ring.size():
		var here: Control = _ring[index]
		var after: Control = _ring[(index + 1) % _ring.size()]
		var before: Control = _ring[(index - 1 + _ring.size()) % _ring.size()]
		here.focus_next = here.get_path_to(after)
		here.focus_previous = here.get_path_to(before)


func ring() -> Array[Control]:
	"""The controls focus cycles through, in order."""
	return _ring


func show_modal(first_focus: Control) -> void:
	"""Show with §2.2's 120 ms alpha, and focus `first_focus`."""
	visible = true
	modulate.a = 0.0
	if is_inside_tree():
		create_tween().tween_property(self, "modulate:a", 1.0, SHOW_SECONDS)
		if first_focus != null and first_focus.is_visible_in_tree():
			first_focus.grab_focus()
	else:
		modulate.a = 1.0


static func focus_later(control: Control) -> void:
	"""Move keyboard focus to `control` after the current input event, when it is in the tree."""
	if control != null and control.is_inside_tree():
		control.grab_focus.call_deferred()


func hide_modal() -> void:
	"""Hide at once (the owner returns focus to the opener)."""
	visible = false
	modulate.a = 1.0


func _gui_input(event: InputEvent) -> void:
	"""Escape dismisses exactly one layer."""
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		dismiss_requested.emit()
