extends Control
## A lacquered banner drawn BEHIND a free-standing HUD label, sized to the words it holds.
##
## The pause line (UI-SET-086) is a bare Label on the world. The concept seats it on a small
## green banner. A StyleBox on the Label itself would draw across the label's whole 240 px
## rectangle, and would keep drawing an empty bar while the game runs and the line is blank.
## So the banner is a child that sits `show_behind_parent`, measures the label's CURRENT text
## with the label's own font, and hides itself when there is nothing to hold.
##
## The label's rectangle, text, alignment and mouse filter are not touched. The banner ignores
## the mouse and focus and has no accessibility node: it is decoration under text the label
## already announces.

const Styles := preload("res://demo/ui/woodland_styles.gd")

## Space between the words and the banner's ends, and above and below the line.
const PAD_X: float = 16.0
const PAD_Y: float = 5.0

var _label: Label = null
var _style: StyleBox = null
## The text the banner was last fitted to. Compared each frame; refitting happens only on change.
var _fitted_text: String = ""


func _init() -> void:
	"""A decorative node: no click, no focus, drawn under its parent label."""
	name = "WoodlandBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	accessibility_name = ""
	show_behind_parent = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style = Styles.box(Styles.PIECE_NOTICE, PackedFloat32Array())


static func attach(label: Label) -> Control:
	"""Seat a banner under `label`. Returns the banner, already fitted to the current text."""
	var script: GDScript = load("res://demo/ui/woodland_banner.gd") as GDScript
	var banner: Control = script.new() as Control
	label.add_child(banner)
	banner.call(&"bind", label)
	return banner


func bind(label: Label) -> void:
	"""Follow one label, and fit to whatever it says now."""
	_label = label
	if not _label.resized.is_connected(_fit):
		_label.resized.connect(_fit)
	_fit()


func _process(_delta: float) -> void:
	"""Refit only when the label's words change; otherwise do nothing."""
	if _label != null and _label.text != _fitted_text:
		_fit()


func _fit() -> void:
	"""Size the banner to the label's text, or hide it when the label is blank."""
	_fitted_text = _label.text
	visible = not _fitted_text.is_empty()
	if not visible:
		return
	var font: Font = _label.get_theme_font(&"font")
	var font_size: int = _label.get_theme_font_size(&"font_size")
	if font == null:
		return
	var width: float = font.get_string_size(_fitted_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size).x
	var height: float = font.get_height(font_size)
	position = _text_origin(width, height) - Vector2(PAD_X, PAD_Y)
	size = Vector2(width + 2.0 * PAD_X, height + 2.0 * PAD_Y)
	queue_redraw()


func _text_origin(width: float, height: float) -> Vector2:
	"""Where the label draws its first glyph, honouring its own alignment."""
	var origin: Vector2 = Vector2.ZERO
	if _label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		origin.x = (_label.size.x - width) * 0.5
	elif _label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		origin.x = _label.size.x - width
	if _label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		origin.y = (_label.size.y - height) * 0.5
	elif _label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		origin.y = _label.size.y - height
	return origin


func _draw() -> void:
	"""The lacquered, brass-rimmed banner across the banner's own rectangle."""
	draw_style_box(_style, Rect2(Vector2.ZERO, size))


func fitted_text() -> String:
	"""The text the banner is currently sized to."""
	return _fitted_text
