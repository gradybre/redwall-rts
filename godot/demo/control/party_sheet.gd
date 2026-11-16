extends CanvasLayer
## THE PARTY SHEET: the Demo party panel's inspector laid over the world beside a short column (decision 1891; decision
## 1871 P-B8, Brendan's ruling "Compact panel, next"). DEMO UI, owned by demo_party_panel.gd.
##
## Where the left column is too short for the party panel's header, summary, actions AND a useful inspector (1280x720,
## where the level bar UI-BUILD-013 stands above the minimap), the panel takes its compact form and its "Open" action
## shows this sheet: a frame beside the column, from the column's top to the level bar's foot, holding
##   * a head: the title, the selected count and × (Close, Esc);
##   * the summary, on up to SUMMARY_LINES lines (whole in its tooltip);
##   * the inspector itself (the party panel moves its scroll here while compact: `slot`).
## It is a MODAL of the demo's input gate (demo/ui/demo_input_gate.gd `watch_modal`, wired by demo_village.gd): while it
## shows, the gate lays its scrim under it, world keys wait, Tab stays inside it and Esc folds it. A CLICK AWAY folds it
## too: a clear catcher over the whole view, above the gate's scrim and below the frame, takes any press outside the
## frame and folds the sheet on its release (neither does anything else, as a modal's scrim would).
##
## PLACEMENT (`placement`), in the HUD's logical pixels, drawn at its scale S: left edge GAP right of the column's
## carved frame; width the column's inner width with this frame's margins (so the inspector's rows keep their width);
## top the column frame's top; foot the level bar's foot. The thin carving (PIECE_PANEL_TIGHT) is held inside the
## rectangle, so at 125 % on 1280x720 the sheet ends GAP short of the right column. The frame is as tall as its
## content, up to that.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

## Above the HUD's CanvasLayer (1), with the demo's other modals; the stall banner (3) draws over it.
const LAYER: int = 2
const TITLE: String = "Demo party"
## The demo panels' close mark (the Farm panel's ×), its key in the tooltip: the head keeps its room for the title.
const CLOSE_BUTTON: String = "×"
const CLOSE_TIP: String = "Close (Esc) — fold the party's details; a click anywhere outside them folds them too"
## Between the column's carved frame and the sheet, logical px.
const GAP: float = 8.0
## The sheet's content margins (l, t, r, b) inside its thin carving.
const MARGINS: PackedFloat32Array = [12.0, 8.0, 12.0, 8.0]
const SEPARATION: int = 6
## The summary wraps to at most this many lines, then is cut with an ellipsis (whole in its tooltip; a group's tally is
## whole in the group panel's "Doing:" line too), so a big group's tally leaves the inspector its room at 125 %.
const SUMMARY_LINES: int = 2
const TITLE_PX: int = 20
const BODY_PX: int = 15
const SMALL_PX: int = 14
const BUTTON_H: float = 32.0
const BUTTON_MARGINS: PackedFloat32Array = [12.0, 6.0, 12.0, 7.0]

var _catcher: Control = null
var _frame: PanelContainer = null
var _head: HBoxContainer = null
var _count: Label = null
var _close: Button = null
var _summary: Label = null
var _slot: VBoxContainer = null
## The button pressed on the catcher, whose release folds the sheet (MOUSE_BUTTON_NONE: none).
var _pressed_away: MouseButton = MOUSE_BUTTON_NONE


func build(inner_width: float) -> void:
	"""Build the catcher, the frame, its head and summary, and the empty slot -- folded. `inner_width`: the party
	column's inner width, which the frame keeps."""
	if _frame != null:
		return
	name = "PartySheet"
	layer = LAYER
	_catcher = Control.new()
	_catcher.name = "ClickAway"
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	_frame = PanelContainer.new()
	_frame.name = "Sheet"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL_TIGHT, MARGINS))
	_frame.theme = CardScript.tooltip_theme()
	_frame.custom_minimum_size.x = width_for(inner_width)
	add_child(_frame)
	_frame.add_child(_build_column())
	fold()


func _build_column() -> VBoxContainer:
	"""The head, the summary and the slot, top to bottom."""
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", SEPARATION)
	_head = HBoxContainer.new()
	var title := _label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_head.add_child(title)
	_count = _label("", SMALL_PX, Palette.UMBER, null)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_count)
	_close = _button(CLOSE_BUTTON, CLOSE_TIP)
	_close.pressed.connect(fold)
	_head.add_child(_close)
	column.add_child(_head)
	_summary = _label("", BODY_PX, Palette.INK, null)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.max_lines_visible = SUMMARY_LINES
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_summary)
	_slot = VBoxContainer.new()
	_slot.name = "Slot"
	column.add_child(_slot)
	return column


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One label in the sheet's type."""
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, tip: String) -> Button:
	"""A wood button like the party panel's: at least BUTTON_H tall, takes keyboard focus (decision 0261)."""
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	Styles.focusable(button, BUTTON_MARGINS)
	button.custom_minimum_size.y = BUTTON_H
	button.add_theme_font_size_override(&"font_size", BODY_PX)
	button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	return button


# --- open and fold ------------------------------------------------------------------------------------

func open() -> void:
	"""Show the sheet (the input gate, watching this layer, makes it the top modal)."""
	_set_shown(true)


func fold() -> void:
	"""Hide the sheet (the gate gives the focus back where it was); a press on the catcher is forgotten."""
	_pressed_away = MOUSE_BUTTON_NONE
	_set_shown(false)


func is_open() -> bool:
	"""Whether the sheet shows."""
	return visible


func _set_shown(on: bool) -> void:
	"""The layer, the catcher and the frame together: a hidden frame is no focus stop for F7 and Tab, which do not
	look through a CanvasLayer's own visibility (demo_input_gate.gd `_collect`)."""
	_catcher.visible = on
	_frame.visible = on
	visible = on


func _on_catcher_input(event: InputEvent) -> void:
	"""A click outside the frame folds the sheet: the press is taken here, and the sheet folds on its matching release,
	so neither reaches the world (nothing goes past the catcher's MOUSE_FILTER_STOP, and Godot sends a press's release
	to the control that took the press). A wheel or a move is only stopped."""
	var click := event as InputEventMouseButton
	if click == null or not folds_on(click.button_index):
		return
	if click.pressed:
		_pressed_away = click.button_index
	elif click.button_index == _pressed_away:
		fold()


static func folds_on(button: MouseButton) -> bool:
	"""Whether a press of `button` away from the sheet folds it: the left, right and middle buttons, not the wheel."""
	return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT or button == MOUSE_BUTTON_MIDDLE


# --- what it shows --------------------------------------------------------------------------------------

func show_words(count: String, summary: String) -> void:
	"""The head's count ("6 selected"; "" for nobody) and the summary (whole in its tooltip)."""
	if _count.text != count:
		_count.text = count
	if _summary.text != summary:
		_summary.text = summary
		_summary.tooltip_text = summary


func slot() -> VBoxContainer:
	"""Where the party panel puts its inspector while compact."""
	return _slot


func frame() -> PanelContainer:
	"""The sheet's frame (the input gate's focus trap)."""
	return _frame


func close_button() -> Button:
	"""The × (Close, Esc)."""
	return _close


func catcher() -> Control:
	"""The click-away catcher (checks)."""
	return _catcher


func count_text() -> String:
	"""The head's count as shown."""
	return _count.text


func summary_label() -> Label:
	"""The whole summary (checks)."""
	return _summary


# --- placement ------------------------------------------------------------------------------------------

static func width_for(inner_width: float) -> float:
	"""The frame's width for a content width of `inner_width` logical px."""
	return inner_width + MARGINS[0] + MARGINS[2]


static func placement(geometry: UiLayout.Geometry, column_right: float, inner_width: float) -> Rect2:
	"""The sheet's rectangle in logical px: GAP right of `column_right` (the column's carved frame's right edge), as
	wide as `inner_width` with the margins, from the management top to the level bar's foot (UI-BUILD-013)."""
	var bar: Rect2 = BuildLayout.level_bar_rect(geometry, true)
	var top: float = geometry.management_top
	return Rect2(column_right + GAP, top, width_for(inner_width), maxf(bar.end.y - top, 0.0))


func slot_room(height: float) -> float:
	"""How tall the slot may be in a sheet `height` logical px tall: what the margins, the head and the summary
	leave."""
	var used: float = MARGINS[1] + MARGINS[3] + _head.get_combined_minimum_size().y \
		+ _summary.get_combined_minimum_size().y + 2.0 * SEPARATION
	return maxf(height - used, 0.0)


func place(rect: Rect2, scale_s: float) -> void:
	"""Draw the frame at `rect` (logical px) at the HUD's scale; it is as tall as its content (the slot sized by the
	party panel within `slot_room`)."""
	_frame.scale = Vector2(scale_s, scale_s)
	_frame.position = rect.position * scale_s
	_frame.size = Vector2(rect.size.x, 0.0)


func frame_rect() -> Rect2:
	"""Where the frame is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
