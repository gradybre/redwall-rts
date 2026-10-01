extends CanvasLayer
## THE VILLAGE TAPESTRY'S PANEL (decision 0771): the village's history as a woven timeline, opened from the hall's
## panel. DEMO UI in the woodland skin (farm_ui.gd's frame, type and buttons), drawn at the HUD's scale.
##
## THE WEAVE. The timeline lies on a cloth (`_cloth`, a PanelContainer whose own draw adds the threads under its rows):
## a fine warp and weft over an oat ground, a border band of alternating clay and brass stitches top and bottom, and
## one umber THREAD down the left that every entry is knotted to -- a diamond knot in its kind's colour
## (tapestry.gd KIND_COLOURS). Each entry: its date (in the knot's colour), its title, its text; oldest first, as a
## tapestry is woven. The weave is drawn only when the cloth is resized or an entry is added -- never per frame.
## An ORIGINAL community tapestry (LORE-R07): its words are the village's own (tapestry.gd).
##
## WHERE: the same place as the hall's panel, which it stands in for while open ("Back to the hall" returns). Not modal;
## Esc or x closes it. Rows are pooled and only grow.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const TapestryScript := preload("res://demo/hall/tapestry.gd")

const LAYER: int = 1
const MAX_W: float = 560.0
const MAX_H: float = 640.0
const GAP: float = 10.0
const TITLE: String = "The village tapestry"
const NOTE: String = "Woven in the hall by the village itself: its own history, stitch by stitch."
const EMPTY: String = "Nothing woven yet."
const REFRESH_S: float = 0.5
## The weave (logical px): thread spacing, the border band, the timeline thread's x and width, a knot's half size.
const WEAVE_STEP: float = 7.0
const BAND_H: float = 10.0
const STITCH_W: float = 14.0
const THREAD_X: float = 22.0
const THREAD_W: float = 3.0
const KNOT_R: float = 7.0
const ROW_INDENT: float = 44.0
const CLOTH_MARGINS: PackedFloat32Array = [0.0, 18.0, 12.0, 18.0]
const GROUND: Color = Palette.OAT
const WARP: Color = Color(0.35, 0.26, 0.2, 0.07)
const WEFT: Color = Color(0.35, 0.26, 0.2, 0.05)

var _tapestry: TapestryScript = null
var _back: Callable = Callable()
var _frame: PanelContainer = null
var _cloth: PanelContainer = null
var _rows: VBoxContainer = null
var _empty: Label = null
var _entries: Array[VBoxContainer] = []
var _drawn: int = -1
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(tapestry: TapestryScript, back_to_hall: Callable) -> void:
	"""Show this tapestry; "Back to the hall" calls `back_to_hall()`."""
	_tapestry = tapestry
	_back = back_to_hall
	build()


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden window: header, note and the cloth in its scroll (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "TapestryPanel"
	_frame = FarmUi.frame()
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	_build_header(column)
	column.add_child(FarmUi.label(NOTE, FarmUi.SMALL_PX, Palette.UMBER))
	_build_cloth(column)


func _build_cloth(column: VBoxContainer) -> void:
	"""The cloth in its scroll: the woven ground, its rows and the "nothing woven" line."""
	var scroll := DemoScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_cloth = PanelContainer.new()
	_cloth.name = "Cloth"
	_cloth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cloth.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cloth.add_theme_stylebox_override(&"panel", _ground_box())
	_cloth.draw.connect(_draw_weave)
	_cloth.resized.connect(_cloth.queue_redraw)
	scroll.add_child(_cloth)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 14)
	_rows.resized.connect(_cloth.queue_redraw)
	_cloth.add_child(_rows)
	_empty = FarmUi.label(EMPTY, FarmUi.BODY_PX, Palette.UMBER)
	_rows.add_child(_empty)


func _build_header(column: VBoxContainer) -> void:
	"""The title, Back to the hall and the close."""
	var row := HBoxContainer.new()
	column.add_child(row)
	var title: Label = FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.UMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var back: Button = FarmUi.button("Back to the hall")
	back.name = "Back"
	back.pressed.connect(back_to_hall)
	row.add_child(back)
	var close: Button = FarmUi.button("×", FarmUi.BODY_PX + 2)
	close.name = "Close"
	close.tooltip_text = "Close the tapestry (Esc)"
	close.pressed.connect(close_window)
	row.add_child(close)


func _ground_box() -> StyleBoxFlat:
	"""The cloth's ground: oat, the rows inset past the thread and inside the border bands."""
	var box := StyleBoxFlat.new()
	box.bg_color = GROUND
	box.border_color = Palette.UMBER
	box.set_border_width_all(1)
	box.content_margin_left = ROW_INDENT
	box.content_margin_top = CLOTH_MARGINS[1]
	box.content_margin_right = CLOTH_MARGINS[2]
	box.content_margin_bottom = CLOTH_MARGINS[3]
	return box


# --- opening ----------------------------------------------------------------------------------------------------

func open() -> void:
	"""Show the tapestry, current."""
	build()
	_frame.visible = true
	_drawn = -1
	refresh()
	_place.call_deferred()


func close_window() -> void:
	"""Hide the tapestry."""
	if _frame != null:
		_frame.visible = false


func back_to_hall() -> void:
	"""Close, and show the hall's panel again."""
	close_window()
	if _back.is_valid():
		_back.call()


func is_open() -> bool:
	"""Whether the tapestry is shown."""
	return _frame != null and _frame.visible


func _input(event: InputEvent) -> void:
	"""Esc closes the open tapestry before any world handler reads it."""
	if is_open() and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_window()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	"""Pick up new entries a couple of times a second while open."""
	if not is_open():
		return
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


# --- the entries --------------------------------------------------------------------------------------------------

func refresh() -> bool:
	"""Rewrite the entries when the tapestry changed. Whether it did."""
	if _tapestry == null or _rows == null or _tapestry.revision == _drawn:
		return false
	_drawn = _tapestry.revision
	var n: int = _tapestry.count()
	_empty.visible = n == 0
	for i: int in n:
		_entry(i)
	for i: int in range(n, _entries.size()):
		_entries[i].visible = false
	_cloth.queue_redraw()
	return true


func _entry(i: int) -> void:
	"""Write entry `i` into its pooled row (made when first needed)."""
	while _entries.size() <= i:
		_entries.append(_new_entry())
	var row: VBoxContainer = _entries[i]
	var colour: Color = TapestryScript.KIND_COLOURS[_tapestry.kind_of(i)]
	var date := row.get_child(0) as Label
	date.text = "%s · %s" % [_tapestry.date_of(i), TapestryScript.KIND_NAMES[_tapestry.kind_of(i)]]
	date.add_theme_color_override(&"font_color", colour.darkened(0.25))
	(row.get_child(1) as Label).text = _tapestry.title_of(i)
	var text := row.get_child(2) as Label
	text.text = _tapestry.text_of(i)
	text.visible = not text.text.is_empty()
	row.visible = true


func _new_entry() -> VBoxContainer:
	"""A pooled entry: its date, title and text."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.add_child(FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER))
	row.add_child(FarmUi.label("", FarmUi.BODY_PX + 1, Palette.INK, true))
	row.add_child(FarmUi.label("", FarmUi.BODY_PX, Palette.INK))
	_rows.add_child(row)
	return row


# --- the weave (drawn on the cloth, under its rows) ---------------------------------------------------------------

func _draw_weave() -> void:
	"""The cloth's threads, its border bands, the timeline thread and a knot at each shown entry (see THE WEAVE)."""
	var size: Vector2 = _cloth.size
	_draw_threads(size)
	_draw_band(BAND_H * 0.5 + 2.0, size.x)
	_draw_band(size.y - BAND_H * 0.5 - 2.0, size.x)
	_cloth.draw_line(Vector2(THREAD_X, BAND_H + 4.0), Vector2(THREAD_X, size.y - BAND_H - 4.0), Palette.UMBER, THREAD_W)
	for i: int in _entries.size():
		if _entries[i].visible:
			_draw_knot(i)


func _draw_threads(size: Vector2) -> void:
	"""The fine warp (down) and weft (across)."""
	var warp := PackedVector2Array()
	var x: float = WEAVE_STEP
	while x < size.x:
		warp.append_array([Vector2(x, 0.0), Vector2(x, size.y)])
		x += WEAVE_STEP
	var weft := PackedVector2Array()
	var y: float = WEAVE_STEP
	while y < size.y:
		weft.append_array([Vector2(0.0, y), Vector2(size.x, y)])
		y += WEAVE_STEP
	if not warp.is_empty():
		_cloth.draw_multiline(warp, WARP, 1.0)
	if not weft.is_empty():
		_cloth.draw_multiline(weft, WEFT, 1.0)


func _draw_band(y: float, width: float) -> void:
	"""A border band of alternating clay and brass stitches across the cloth at `y`."""
	var x: float = 4.0
	var k: int = 0
	while x + STITCH_W < width - 4.0:
		var colour: Color = Palette.CLAY if k % 2 == 0 else Palette.BRASS
		_cloth.draw_line(Vector2(x, y - BAND_H * 0.3), Vector2(x + STITCH_W, y + BAND_H * 0.3), colour, 3.0)
		x += STITCH_W + 2.0
		k += 1


func _draw_knot(i: int) -> void:
	"""Entry `i`'s knot on the thread, level with its date: a diamond in its kind's colour, ringed in umber."""
	var row: VBoxContainer = _entries[i]
	var y: float = _rows.position.y + row.position.y + (row.get_child(0) as Control).size.y * 0.5
	var c := Vector2(THREAD_X, y)
	var diamond := PackedVector2Array([c + Vector2(0.0, -KNOT_R), c + Vector2(KNOT_R, 0.0), c + Vector2(0.0, KNOT_R),
		c + Vector2(-KNOT_R, 0.0)])
	_cloth.draw_colored_polygon(diamond, TapestryScript.KIND_COLOURS[_tapestry.kind_of(i)])
	diamond.append(diamond[0])
	_cloth.draw_polyline(diamond, Palette.UMBER, 1.5)


# --- placing ------------------------------------------------------------------------------------------------------

func _place() -> void:
	"""Where the hall's panel stands: top centre under the alert zone, down to just above the command strip."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var width: float = minf(MAX_W, _geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(_geometry.alerts.get_center().x - width / 2.0, GAP, _geometry.logical_width - GAP - width)
	var top: float = _geometry.alerts.end.y + GAP
	var height: float = minf(MAX_H, _geometry.commands.position.y - GAP - top)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = Vector2(x, top) * _geometry.scale
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)


func frame_rect() -> Rect2:
	"""Where the tapestry is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func shown_entries() -> int:
	"""How many entries are drawn (checks)."""
	var n: int = 0
	for row: VBoxContainer in _entries:
		n += 1 if row.visible else 0
	return n


func entry_title(i: int) -> String:
	"""Drawn entry `i`'s title (checks)."""
	return (_entries[i].get_child(1) as Label).text
