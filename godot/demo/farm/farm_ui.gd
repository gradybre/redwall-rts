extends RefCounted
## Shared pieces of the farm's panels, in the woodland skin (demo/ui/) the demo party panel uses:
## a carved-wood frame with a parchment face, Noto Serif headings, ink and umber text, wood buttons.
## Decision 0196. Panels are laid out in the HUD's LOGICAL pixels (scripts/ui/ui_layout.gd, read,
## never modified) and drawn at its scale, so they line up with the HUD from 1280x720 to 4K.

const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const TITLE_PX: int = 20
const BODY_PX: int = 15
const SMALL_PX: int = 13
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [10.0, 5.0, 10.0, 6.0]
## The carved frame draws this far outside the panel rectangle (woodland_styles PIECE_PANEL).
const FRAME_EXPAND: float = 10.0


static func frame() -> PanelContainer:
	"""The carved panel, stopping the mouse (a click on it never reaches the world)."""
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	return panel


static func label(text: String, px: int, colour: Color, heading: bool = false) -> Label:
	"""A line in the panel's type (wrapping)."""
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override(&"font_size", px)
	line.add_theme_color_override(&"font_color", colour)
	if heading:
		line.add_theme_font_override(&"font", Styles.heading_font())
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func button(text: String, px: int = BODY_PX) -> Button:
	"""A wood button: cream on wood, brass when pressed, muted when disabled; never takes focus."""
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_size_override(&"font_size", px)
	made.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		made.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	made.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	made.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	return made


static func set_enabled(control: Button, enabled: bool, why: String) -> void:
	"""Enable a button, or disable and dim it with `why` as its tooltip (the woodland disabled wood
	alone reads as strongly as the enabled one)."""
	control.disabled = not enabled
	control.tooltip_text = "" if enabled else why
	control.modulate.a = 1.0 if enabled else 0.5


static func geometry_for(viewport_size: Vector2, layout: UiLayout, geometry: UiLayout.Geometry) -> void:
	"""Fill `geometry` for this viewport (scale 1 below the supported floor)."""
	if not layout.compute_into(maxi(int(viewport_size.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(viewport_size.y), UiLayout.SUPPORTED_MIN_HEIGHT), UiLayout.USER_SCALE_100, false, geometry):
		geometry.scale = 1.0


static func place(panel: Control, rect: Rect2, scale: float) -> void:
	"""Lay `panel` out at logical `rect` (height: as tall as its content, at most the rect's) drawn at
	`scale`."""
	panel.scale = Vector2(scale, scale)
	panel.position = rect.position * scale
	panel.custom_minimum_size = Vector2(rect.size.x, 0.0)
	panel.size = Vector2(rect.size.x, 0.0)
