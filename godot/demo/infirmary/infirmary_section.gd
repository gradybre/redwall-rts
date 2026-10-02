extends VBoxContainer
## The INFIRMARY SECTION in the "Tunnels & burrows (demo)" panel, under its housing line (tunnel_panel.gd
## `add_section`). Decision 0623. DEMO UI: it shows what the infirmary (demo_care.gd) hands it and presses back through
## one callable; nothing here decides anything.
##
## Its heading ("Infirmary"), its lines -- the building's state (none, being fetched for or built, built and its beds),
## the care supplies, the herb patch and the patients -- and one wood button: "Build the infirmary…" (arms the placing
## tool), "Cancel the infirmary" (REQ-SET-126, saying what it returns) or, built, disabled. The panel's own type and
## wood button, so it reads as part of the panel; the button takes keyboard focus.

const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const HEADING: String = "Infirmary"
const BODY_PX: int = 14
const BUTTON_H: float = 32.0
const BUTTON_MARGINS: PackedFloat32Array = [10.0, 5.0, 10.0, 6.0]

var _heading: Label = null
var _lines: Label = null
var _button: Button = null
var _pressed: Callable = Callable()


func _init() -> void:
	"""Build the heading, the lines and the button."""
	name = "InfirmarySection"
	add_theme_constant_override(&"separation", 4)
	_heading = _label(HEADING, BODY_PX + 2, Palette.INK, Styles.heading_font())
	add_child(_heading)
	_lines = _label("", BODY_PX, Palette.UMBER, null)
	add_child(_lines)
	_button = _wood_button()
	add_child(_button)


func on_press(pressed: Callable) -> void:
	"""`pressed()` is called when the button is pressed."""
	_pressed = pressed


func show_lines(lines: String, button_text: String, enabled: bool, tip: String) -> void:
	"""Show the section: its lines, the button's words, whether it can be pressed and its tooltip."""
	if _lines.text != lines:
		_lines.text = lines
	_button.text = button_text
	_button.disabled = not enabled
	_button.tooltip_text = tip


func lines_text() -> String:
	"""The lines shown (checks)."""
	return _lines.text


func button() -> Button:
	"""The button (checks, and keyboard focus)."""
	return _button


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wood_button() -> Button:
	"""The panel's wood button (tunnel_panel.gd `_button`), pressing through `on_press`."""
	var b := Button.new()
	Styles.focusable(b, BUTTON_MARGINS)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = BUTTON_H
	b.add_theme_font_size_override(&"font_size", BODY_PX)
	b.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		b.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	b.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	b.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	b.pressed.connect(func() -> void:
		if _pressed.is_valid():
			_pressed.call())
	return b
