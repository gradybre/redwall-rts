extends CanvasLayer
## "Village news (demo)": the newest demo notices, readable at a glance. Decision 0196 (live demo).
## DEMO UI. It shows the demo's ONE notice feed (demo_notices.gd) and nothing else.
##
## WHAT: the newest LINES entries still fresh -- a NOTE for NOTE_MSEC and a WARNING for WARNING_MSEC of
## REAL time (UI §7 gives INFO 12 real seconds; a demo warning gets longer, and the bed and tunnel
## panels keep their own source's lines for good) -- newest on top, each "<demo date> · Warning: <what>"
## with the date the HUD shows, warnings in clay AND worded (colour never says it alone). An entry's
## authored short summary is shown when it has one. Nothing fresh: the strip hides.
##
## WHERE: bottom centre, over the world, between the minimap and the right column and just above the
## command strip -- the one band UI §1.2 leaves free at every profile -- no wider than MAX_W. Geometry
## is the HUD's own (`scripts/ui/ui_layout.gd`, read, never modified) in LOGICAL pixels at the HUD's
## scale. It ignores the mouse, so a click through it still reaches the world; it draws below the HUD.
##
## Refreshed a few times a second on real time (it must read while the village is paused); it
## rebuilds nothing, only rewrites LINES labels.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const TITLE: String = "Village news (demo)"
const LINES: int = 3
const NOTE_MSEC: int = 12000
const WARNING_MSEC: int = 30000
const MAX_W: float = 640.0
const GAP: float = 12.0
const TITLE_PX: int = 13
const LINE_PX: int = 14
const REFRESH_S: float = 0.25
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 8.0, 14.0, 10.0]

var _notices: NoticesScript = null
var _frame: PanelContainer = null
var _lines: Array[Label] = []
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _refresh_in: float = 0.0
var _seen_revision: int = -1
var _shown: int = 0


func configure(notices: NoticesScript) -> void:
	"""Show this feed, and build."""
	_notices = notices
	build()


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The frame, its title and LINES lines (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = 0
	name = "DemoNewsStrip"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL_TIGHT, CONTENT_MARGINS))
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(column)
	column.add_child(_label(TITLE, TITLE_PX, Palette.UMBER, Styles.heading_font()))
	for k: int in LINES:
		_lines.append(_label("", LINE_PX, Palette.INK, null))
		column.add_child(_lines[k])


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped, mouse-transparent line."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	"""Refresh a few times a second (real time)."""
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh(Time.get_ticks_msec())


func refresh(now_msec: int) -> int:
	"""Show the fresh entries as of `now_msec` (real milliseconds); returns how many are shown."""
	if _notices == null or _frame == null:
		return 0
	var shown: int = 0
	for k: int in _notices.count():
		if shown >= LINES:
			break
		var life: int = WARNING_MSEC if _notices.level(k) == NoticesScript.LEVEL_WARNING else NOTE_MSEC
		if _notices.age_msec(k, now_msec) > life:
			continue
		_show_line(shown, k)
		shown += 1
	for rest: int in range(shown, LINES):
		_lines[rest].visible = false
	if shown != _shown or _notices.revision != _seen_revision:
		_shown = shown
		_seen_revision = _notices.revision
		_frame.visible = shown > 0
		_place.call_deferred()
	return shown


func _show_line(slot: int, k: int) -> void:
	"""Write entry `k` into line `slot`: its short form, clay when it is a warning."""
	var label: Label = _lines[slot]
	var text: String = _notices.short_line(k)
	if label.text != text:
		label.text = text
	var warning: bool = _notices.level(k) == NoticesScript.LEVEL_WARNING
	label.add_theme_color_override(&"font_color", Palette.CLAY if warning else Palette.INK)
	label.visible = true


func line_text(slot: int) -> String:
	"""Line `slot`'s text ("" when hidden; checks)."""
	return _lines[slot].text if _lines[slot].visible else ""


func is_shown() -> bool:
	"""Whether the strip is drawn."""
	return _frame != null and _frame.visible


func _place() -> void:
	"""Bottom centre, between the minimap and the right column, above the command strip (see WHERE)."""
	if not is_inside_tree() or _frame == null:
		return
	var size_px: Vector2 = get_viewport().get_visible_rect().size
	var band: Rect2 = band_placement(int(size_px.x), int(size_px.y), _layout, _geometry)
	for label: Label in _lines:
		label.custom_minimum_size.x = band.size.x - CONTENT_MARGINS[0] - CONTENT_MARGINS[2]
	var height: float = _frame.get_combined_minimum_size().y
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.custom_minimum_size = Vector2(band.size.x, 0.0)
	_frame.size = Vector2(band.size.x, 0.0)
	_frame.position = Vector2(band.position.x, band.end.y - height) * _geometry.scale


static func band_placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The band the strip may fill, in the HUD's logical pixels: between the minimap and the right
	column, no wider than MAX_W and centred, from the top of the minimap down to just above the command
	strip (the strip sits on its bottom edge, as tall as its lines). Fills `geometry`."""
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			UiLayout.USER_SCALE_100, false, geometry):
		geometry.scale = 1.0
	var left: float = geometry.minimap.end.x + GAP
	var right: float = geometry.detail.position.x - GAP
	var band_w: float = minf(MAX_W, right - left)
	var top: float = geometry.minimap.position.y
	return Rect2((left + right - band_w) / 2.0, top, band_w, geometry.commands.position.y - GAP - top)


func frame_rect() -> Rect2:
	"""Where the strip is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
