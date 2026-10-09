extends CanvasLayer
## THE HEATING FUEL BREAKDOWN (UI-SET-003: the Fuel counter "opens fuel breakdown"). Decision 0571. DEMO UI in the
## woodland skin, a modal of the input gate (decision 0261: Esc and Close shut it) in the HUD's modal rectangle, opened
## by clicking the top bar's Heating fuel cell (and the help topic's button).
##
## WHAT IT SAYS, every figure the winter's (demo_winter.gd, hearth_fuel.gd): the fuel-days in the cell's own words and
## state, the wood in store, today's demand (each hearth's rate and the cooking mean), REQ-SET-147's last heated hour,
## in autumn and winter REQ-SET-114's twelve-day projection with its progress, the Firewood order, each hearth -- its
## state and its room's temperature -- and who is Chilled.
##
## THE EMERGENCY ACTIONS (GDD §5.10; never taken by themselves): CONSOLIDATE -- its effect previewed on the button's
## tooltip -- and, per hearth, LET IT GO OUT / LIGHT IT AGAIN. Each says what it did on the status line.

const Text := preload("res://demo/winter/winter_text.gd")
const Rules := preload("res://demo/winter/winter_rules.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const WinterScript := preload("res://demo/winter/demo_winter.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const LAYER: int = 2
const WIDTH: float = 520.0
const REFRESH_S: float = 0.25
## A hearth row's words wrap at this width (logical px), its button beside them: a wrapping label with no width asks for
## a line a word and stretches the frame.
const ROW_TEXT_W: float = 340.0
const TITLE: String = "Heating fuel"
const CLOSE_TEXT: String = "Close (Esc)"
const CONSOLIDATE: String = "Consolidate sleepers into heated homes"
const LET_OUT: String = "Let it go out"
const RELIGHT: String = "Light it again"
const NOBODY_CHILLED: String = "Nobody is Chilled."
const NO_FIREWOOD: String = "Firewood: no order needed now."
const CONSOLIDATED: String = "Consolidated: %d %s moved, %d %s let go out."

var _winter: WinterScript = null
var _frame: PanelContainer = null
var _column: VBoxContainer = null
var _headline: Label = null
var _lines: Label = null
var _progress: ProgressBar = null
var _firewood: Label = null
var _chilled: Label = null
var _status: Label = null
var _consolidate: Button = null
var _close: Button = null
var _rows: Array[Label] = []
var _row_boxes: Array[HBoxContainer] = []
var _toggles: Array[Button] = []
var _shown_revision: int = -1
var _refresh_in: float = 0.0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "FuelPanel"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	add_child(_frame)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(_column)
	_column.add_child(FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true))
	_headline = _wrapped("", FarmUi.BODY_PX, Palette.INK)
	_lines = _wrapped("", FarmUi.SMALL_PX, Palette.UMBER)
	_progress = ProgressBar.new()
	_progress.max_value = Rules.FULL_PERMILLE
	_progress.custom_minimum_size.y = 14.0
	_progress.show_percentage = false
	_column.add_child(_progress)
	_firewood = _wrapped("", FarmUi.SMALL_PX, Palette.UMBER)
	_build_hearth_rows()
	_chilled = _wrapped("", FarmUi.SMALL_PX, Palette.UMBER)
	_consolidate = FarmUi.button(CONSOLIDATE, FarmUi.SMALL_PX)
	_consolidate.pressed.connect(consolidate)
	_column.add_child(_consolidate)
	_status = _wrapped("", FarmUi.SMALL_PX, Palette.LEAF)
	_close = FarmUi.button(CLOSE_TEXT)
	_close.pressed.connect(close)
	_column.add_child(_close)


func _wrapped(text: String, px: int, colour: Color) -> Label:
	"""A wrapping line at the frame's inner width, added to the column."""
	var line: Label = FarmUi.label(text, px, colour)
	line.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	_column.add_child(line)
	return line


func _build_hearth_rows() -> void:
	"""A row per hearth source: its line and its let-go-out / light-again button (hidden without a hearth)."""
	for s: int in FuelScript.SOURCES:
		var row := HBoxContainer.new()
		var line: Label = FarmUi.label("", FarmUi.SMALL_PX, Palette.INK)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.custom_minimum_size.x = ROW_TEXT_W
		row.add_child(line)
		var button: Button = FarmUi.button(LET_OUT, FarmUi.SMALL_PX)
		button.pressed.connect(toggle_banked.bind(s))
		row.add_child(button)
		_column.add_child(row)
		_rows.append(line)
		_row_boxes.append(row)
		_toggles.append(button)


func bind(winter: WinterScript) -> void:
	"""Read and act on this winter."""
	_winter = winter


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _process(delta: float) -> void:
	"""While open, a few times a second: redraw when the winter changed."""
	if not visible or _winter == null:
		return
	_refresh_in -= delta
	if _refresh_in > 0.0 and _winter.revision == _shown_revision:
		return
	_refresh_in = REFRESH_S
	refresh()


func open() -> void:
	"""Show the breakdown, read now."""
	_status.text = ""
	refresh()
	visible = true
	_place.call_deferred()


func close() -> void:
	"""Hide it."""
	visible = false


func toggle() -> void:
	"""Open, or close."""
	if visible:
		close()
	else:
		open()


func refresh() -> void:
	"""Every line from the winter (see WHAT IT SAYS)."""
	if _winter == null:
		return
	_shown_revision = _winter.revision
	var fuel: FuelScript = _winter.fuel
	var days: int = fuel.fuel_days_hundredths()
	_headline.text = Text.hud_line(days)
	_headline.add_theme_color_override(&"font_color", Palette.CLAY if Text.is_warning(days) else Palette.INK)
	_lines.text = "\n".join(PackedStringArray(["Wood in the village stores: %s" % Measures.amount_cell(&"wood", fuel.wood_milli())])
		+ _winter.detail_lines())
	var target: int = fuel.projection_milli()
	_progress.visible = _winter.projection_shown()
	_progress.value = Rules.permille_of(fuel.wood_milli(), target)
	_firewood.text = _firewood_text()
	_fill_hearths(fuel)
	_chilled.text = _chilled_text()
	FarmUi.set_card(_consolidate, true, _winter.consolidate_preview())


func _firewood_text() -> String:
	"""The Firewood order: none, waiting, urgent, or taken."""
	var row: int = _winter.firewood_row()
	if row < 0:
		return NO_FIREWOOD if not _winter.firewood_wanted() else "Firewood: wanted, but the woods offer no deadfall or tree to fell in a forestry zone now"
	var how: String = "URGENT (under 2 days of fuel)" if _winter.firewood_urgent() else "on the woods' board"
	return "Firewood: %s — %s" % [how, "someone is on it" if _winter.firewood_taken() else "waiting for a free resident (Work, J)"]


func _fill_hearths(fuel: FuelScript) -> void:
	"""Each hearth's row and its button (see THE EMERGENCY ACTIONS)."""
	for s: int in FuelScript.SOURCES:
		var has: bool = fuel.hearth[s] == 1
		_row_boxes[s].visible = has
		if not has:
			continue
		_rows[s].text = Text.state_line(fuel, s)
		_rows[s].add_theme_color_override(&"font_color", Palette.CLAY if fuel.is_out(s) else Palette.INK)
		_toggles[s].text = RELIGHT if fuel.banked[s] == 1 else LET_OUT


func _chilled_text() -> String:
	"""Who is Chilled, by name."""
	var names := PackedStringArray()
	for i: int in _winter.cold.count():
		if _winter.cold.is_chilled(i):
			names.append(_winter.resident_name(i))
	return NOBODY_CHILLED if names.is_empty() else "Chilled: %s" % ", ".join(names)


func toggle_banked(source: int) -> void:
	"""Let hearth `source` go out, or light it again (from the next hour)."""
	var on: bool = _winter.fuel.banked[source] == 0
	_winter.set_banked(source, on)
	_status.text = "%s: %s from the next hour." % [Text.source_title(source), "let go out" if on else "lit again"]
	refresh()


func consolidate() -> void:
	"""The emergency consolidation, now, and what it did."""
	var done: PackedInt32Array = _winter.consolidate()
	_status.text = CONSOLIDATED % [done[0], "sleeper" if done[0] == 1 else "sleepers", done[1],
		"hearth" if done[1] == 1 else "hearths"]
	refresh()


func status_text() -> String:
	"""The status line (checks)."""
	return _status.text


func headline_text() -> String:
	"""The headline (checks)."""
	return _headline.text


func close_button() -> Button:
	"""Close (the gate's)."""
	return _close


func consolidate_button() -> Button:
	"""Consolidate (checks)."""
	return _consolidate


func frame() -> PanelContainer:
	"""The carved frame (the gate's focus trap root)."""
	return _frame


func _place() -> void:
	"""Centred at the top of the HUD's modal rectangle, at the HUD's scale (the Demo Lab's placement)."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(WIDTH, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	var rect := Rect2(zone.position + Vector2((zone.size.x - width) / 2.0, FarmUi.FRAME_EXPAND),
		Vector2(width, zone.size.y - 2.0 * FarmUi.FRAME_EXPAND))
	FarmUi.place(_frame, rect, _geometry.scale)
