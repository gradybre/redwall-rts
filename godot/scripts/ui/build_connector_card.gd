extends Panel
## UI-BUILD-012, THE CONNECTOR CARD (docs/ui_ux_controls.md; decision 2021, Brendan's ruling P-D1-3 (a)): opened when
## a way's ghost is placed. It names the way, offers Down and Up (the impossible one disabled, its reason said on the
## card and in its tooltip: "No level above the surface", "No level below level 4"), states the result in words --
## "✓ Connects to Underground level 2", or "! Blocked: ..." / "X Not possible: ..." -- with the placeholder's note
## (P-D1-2 (a): "Placeholder: sizes and costs await review"; a hatch's "Climbers only: ..."; the proof of concept's
## "free; not yet a qualified descent"), and "Add to plan" (disabled on "X") and Cancel.
##
##   +--------------------------------------+
##   | Hatch with ladder        [Down] [Up]  |
##   | ✓ Connects to Underground level 2    |
##   | Placeholder: sizes and costs ...     |   (scrolls when the words outgrow it: never cut short)
##   | [ Add to plan              ] [Cancel]|
##   +--------------------------------------+
##
## Placed by build_layout.gd `connector_rect`: above the panel's top-right edge, or in NARROW inside its content row.
## Game UI: it only says what was pressed (`direction_chosen`, `add_pressed`, `cancel_pressed`); the panel acts.

const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const PAD: float = 8.0
const ROW: float = 32.0
const TOGGLE_WIDTH: float = 60.0
const CANCEL_WIDTH: float = 84.0
const TITLE_PX: int = 16
const TEXT_PX: int = 14
const DIRECTION_WORDS: Array[String] = ["Down", "Up"]
const ACCESSIBLE: String = "Connector card: %s; %s"

## Down (false) or Up (true) pressed.
signal direction_chosen(up: bool)
signal add_pressed
signal cancel_pressed

var _title: Label = null
var _toggles: Array[Button] = []
var _scroll: ScrollContainer = null
var _words: Label = null
var _add: Button = null
var _cancel: Button = null


func _init() -> void:
	"""Named and hidden until a way is placed."""
	name = "UI-BUILD-012"
	visible = false
	theme_type_variation = &"WoodlandPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	"""Every control (also off-tree, for checks)."""
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", TITLE_PX)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	add_child(_title)
	for up: int in 2:
		var button: Button = _new_button(DIRECTION_WORDS[up], direction_chosen.emit.bind(up == 1))
		button.toggle_mode = true
		button.theme_type_variation = &"WoodlandToggle"
		_toggles.append(button)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_theme_font_size_override(&"font_size", TEXT_PX)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_words)
	_add = _new_button("Add to plan", add_pressed.emit)
	_cancel = _new_button("Cancel", cancel_pressed.emit)


func _new_button(text: String, pressed: Callable) -> Button:
	"""A focusable WoodlandButton on the card, its text at the 14 px floor."""
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = &"WoodlandButton"
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override(&"font_size", TEXT_PX)
	button.pressed.connect(pressed)
	add_child(button)
	return button


func place_in(rect: Rect2) -> void:
	"""Lay the card out in `rect` (logical px, the panel's frame of reference)."""
	position = rect.position
	size = rect.size
	var inner: float = rect.size.x - 2.0 * PAD
	_title.position = Vector2(PAD, PAD)
	_title.size = Vector2(maxf(inner - 2.0 * TOGGLE_WIDTH - 4.0, 0.0), ROW)
	for up: int in 2:
		_toggles[up].position = Vector2(rect.size.x - PAD - (2 - up) * TOGGLE_WIDTH - (1 - up) * 4.0, PAD)
		_toggles[up].size = Vector2(TOGGLE_WIDTH, ROW)
	var foot: float = rect.size.y - PAD - ROW
	_scroll.position = Vector2(PAD, PAD + ROW + 4.0)
	_scroll.size = Vector2(inner, maxf(foot - 4.0 - _scroll.position.y, 0.0))
	_words.custom_minimum_size.x = inner - 12.0
	_add.position = Vector2(PAD, foot)
	_add.size = Vector2(inner - CANCEL_WIDTH - 4.0, ROW)
	_cancel.position = Vector2(rect.size.x - PAD - CANCEL_WIDTH, foot)
	_cancel.size = Vector2(CANCEL_WIDTH, ROW)


func show_way(way_name: String, reasons: PackedStringArray, up: bool, kind: int, result: String, notes: String) -> void:
	"""Show a way: its name; `reasons[0]` / `reasons[1]` why Down / Up is impossible ("" when it is possible); the
	direction chosen; the result (`kind`, and `result` its line in words); the notes under it."""
	_title.text = way_name
	for side: int in 2:
		var why: String = reasons[side]
		_toggles[side].disabled = not why.is_empty()
		_toggles[side].set_pressed_no_signal(side == (1 if up else 0))
		_toggles[side].tooltip_text = Validity.line(Validity.KIND_NOT_POSSIBLE, why) if not why.is_empty() \
			else "Connect %s" % DIRECTION_WORDS[side].to_lower()
		_toggles[side].accessibility_description = _toggles[side].tooltip_text
	var lines: PackedStringArray = PackedStringArray([result])
	for side: int in 2:
		if not reasons[side].is_empty():
			lines.append("%s: %s" % [DIRECTION_WORDS[side], Validity.line(Validity.KIND_NOT_POSSIBLE, reasons[side])])
	lines.append(notes)
	_words.text = "\n".join(lines)
	_words.add_theme_color_override(&"font_color", UiTheme.color_of(Validity.token(kind)))
	_add.disabled = kind == Validity.KIND_NOT_POSSIBLE
	accessibility_name = ACCESSIBLE % [way_name, result]
	visible = true


func words() -> String:
	"""What the card says under its title (checks)."""
	return _words.text


func title() -> String:
	"""The way named (checks)."""
	return _title.text


func toggle(up: bool) -> Button:
	"""The Down or Up toggle."""
	return _toggles[1 if up else 0]


func add_button() -> Button:
	"""Add to plan."""
	return _add


func cancel_button() -> Button:
	"""Cancel."""
	return _cancel
