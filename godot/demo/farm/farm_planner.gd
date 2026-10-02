extends CanvasLayer
## THE SEASONAL PLANNER (decision 0451; review F45, UX-008's overview half, ECO-005, P1's "Seasonal forecast" row, P4):
## the village's answer to "what threatens tonight's meal or next season?" -- exceptions first, not another wall of
## numbers. DEMO UI in the woodland skin, in the HUD's modal rectangle above the HUD (as the Work screen and the Pantry),
## a modal of the input gate (decision 0261: T, Esc and its × close it; Tab and Enter work inside it; focus comes back
## where it was). T opens it (UI §5's calendar key; decision 0492), and so does the Farm panel's "Planner (T)". It
## follows the interface scale (DemoUiScale, decision 0391) and is laid out for 1280x720.
##
## FOUR TABS, each a view of the farm's real state through one pure module:
##   Farm overview    one row a bed -- crop, stage, when and how much it harvests, its soil moisture in the bed panel's
##                    words, the work on it and who has it, its next sowing (farm_plan_rows.gd) -- with the Needs
##                    attention and Harvest soon filters. A row (click, or Enter on it) closes the planner, opens that
##                    bed's panel and centres the camera on it (`bed_wanted`, the village news' own "Go to"). The bed
##                    panel keeps the detail; the overview never repeats it.
##   Season calendar  this season (or the next) as a compact timeline (farm_timeline.gd) or, the accessible alternative,
##                    a table of the same entries in words (farm_season.gd): planting windows and when their crops would
##                    ripen, the season's baseline, the frost and blight schedule, the announced weather event, each
##                    day's weather already rolled, the beds' harvests, the kitchen's planned meals and how long the food
##                    in store lasts -- every entry marked Scheduled, Recorded, Now or Estimate. Today is the HUD's date.
##   Soil plans       ECO-005: compost, a legume or fallow for one bed over one season, side by side
##                    (farm_soil_plans.gd). Presentation only; the bed's own buttons act.
##   Record           the after-action record (farm_record.gd): yesterday's line, this season's days as a table, the
##                    season's totals -- committed outcomes only; each closed day is also posted to the village news.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const SeasonScript := preload("res://demo/farm/farm_season.gd")
const Plans := preload("res://demo/farm/farm_soil_plans.gd")
const PlanText := preload("res://demo/farm/farm_soil_plan_text.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const RecordText := preload("res://demo/farm/farm_record_text.gd")
const TableScript := preload("res://demo/farm/farm_planner_table.gd")
const TimelineScript := preload("res://demo/farm/farm_timeline.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")

signal close_requested
## A bed's row (or a plan's "Open bed") was pressed: show that bed and centre the camera on it.
signal bed_wanted(bed: int)

const TITLE: String = "Seasonal planner"
## The planner's key: free in the input map and in the demo (UI §5's calendar key T is the Dig tool's here; decision 0451).
const KEY: Key = KEY_T
const TAB_OVERVIEW: int = 0
const TAB_CALENDAR: int = 1
const TAB_PLANS: int = 2
const TAB_RECORD: int = 3
const TAB_NAMES: Array[String] = ["Farm overview", "Season calendar", "Soil plans", "Record"]
const LAYER: int = 2
const REFRESH_S: float = 0.25
const NOTE_PX: int = 14
const MIN_BODY_H: float = 150.0
const OVERVIEW_RATIOS: PackedFloat32Array = [0.5, 0.8, 1.0, 2.4, 0.9, 1.3, 1.6]
const CALENDAR_RATIOS: PackedFloat32Array = [0.9, 1.5, 0.75, 3.6]
const RECORD_RATIOS: PackedFloat32Array = [0.9, 0.9, 0.9, 0.9, 1.4, 0.9, 0.8]
const OVERVIEW_NOTE: String = ("≈ marks an estimate at this hour's growth rate: a frost night, rain or a change of season "
	+ "moves it; amounts are at today's health and fertility. A row opens its bed and centres the camera on it.")
const LEGEND: String = ("Scheduled (solid bar): a rule or an announcement, it will happen · Recorded (small square): "
	+ "already happened · Now (ringed diamond): today's conditions · Estimate (outlined bar): at today's rate, it may "
	+ "move · the clay line is now")
const PLANS_NOTE: String = ("Presentation only: §5.6's own rules, nothing changed. Act with the bed's own buttons — "
	+ "Compost, Plant…, Rest.")
const RECORD_NOTE: String = ("Committed outcomes only: food credited into store, taken by the kitchen, spoiled in store "
	+ "or on the table; residents who went without at a meal; crops that withered. Each day's record is also in the "
	+ "village news (N).")
const NO_DAY_YET: String = "No day has closed yet: the first record is made at midnight."

var view: int = TAB_OVERVIEW
var filter: int = Rows.FILTER_ALL
var next_season: bool = false
var table_view: bool = false
var plan_bed: int = 0

var _sim: SimScript = null
var _crew: CrewScript = null
var _record: RecordScript = null
var _kitchen: KitchenScript = null
var _frame: PanelContainer = null
var _date: Label = null
var _close: Button = null
var _tabs: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _scroll: DemoScroll = null
var _filters: Array[Button] = []
var _overview: TableScript = null
var _overview_empty: Label = null
var _season_buttons: Array[Button] = []
var _view_buttons: Array[Button] = []
var _calendar_title: Label = null
var _timeline: TimelineScript = null
var _calendar_table: TableScript = null
var _notes: Label = null
var _season: SeasonScript = SeasonScript.new()
## What the calendar was last built for: the hour, the record's, the farm's and the kitchen's revisions, the season.
var _season_key: PackedInt64Array = PackedInt64Array([-1, 0, 0, 0, 0, 0])
var _season_now: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
## What the soil plans were last drawn for (the farm's revision and hour, the bed, the compost store).
var _plans_key: PackedInt64Array = PackedInt64Array([-1, 0, 0, 0])
var _plans_now: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var _bed_buttons: Array[Button] = []
var _compared: Label = null
var _plan_columns: Array[Label] = []
var _plan_warnings: Array[Label] = []
var _open_bed: Button = null
var _yesterday: Label = null
var _season_line: Label = null
var _record_table: TableScript = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _cells: PackedStringArray = PackedStringArray()
var _refresh_in: float = 0.0
var _wide_lines: Array[Label] = []


func configure(sim: SimScript, crew: CrewScript, record: RecordScript) -> void:
	"""Plan over this farm, its crew and its record; built hidden."""
	_sim = sim
	_crew = crew
	_record = record
	layer = LAYER
	name = "FarmPlanner"
	_build()
	visible = false


func set_kitchen(kitchen: KitchenScript) -> void:
	"""The kitchen whose planned meals and food in store the calendar shows (none: said so)."""
	_kitchen = kitchen
	_season_key[0] = -1


func set_fuel(fuel: FuelScript) -> void:
	"""The hearths' fuel the calendar's Fuel lane shows (decision 0571; farm_season.gd THE FUEL LANE)."""
	_season.fuel = fuel
	_season_key[0] = -1


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


# --- building ---------------------------------------------------------------------------------------------------------

func _build() -> void:
	"""Header, tabs, and the four pages in one scroll."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_header())
	column.add_child(_button_row(TAB_NAMES, _tabs, show_tab))
	_scroll = DemoScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = MIN_BODY_H
	column.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	for page: VBoxContainer in [_build_overview(), _build_calendar(), _build_plans(), _build_record()]:
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override(&"separation", 6)
		pages.add_child(page)
		_pages.append(page)
	_press(_tabs, view)


func _header() -> HBoxContainer:
	"""Title, today's date (the HUD's) and ×."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var title: Label = FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_date = FarmUi.label("", FarmUi.BODY_PX, Palette.UMBER)
	_date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_date)
	_close = FarmUi.button("×")
	_close.tooltip_text = "Close the planner (T or Esc)"
	_close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close)
	return row


func _button_row(names: Array[String], into: Array[Button], pressed: Callable) -> HFlowContainer:
	"""A row of toggle buttons, one pressed at a time, each calling `pressed(index)` (wrapping when narrow)."""
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"h_separation", 8)
	row.add_theme_constant_override(&"v_separation", 4)
	var group := ButtonGroup.new()
	for k: int in names.size():
		var made: Button = FarmUi.button(names[k], NOTE_PX)
		made.toggle_mode = true
		made.button_group = group
		made.pressed.connect(pressed.bind(k))
		row.add_child(made)
		into.append(made)
	return row


func _note(page: VBoxContainer, text: String, colour: Color = Palette.UMBER) -> Label:
	"""A full-width wrapping line on a page."""
	var line: Label = FarmUi.label(text, NOTE_PX, colour)
	page.add_child(line)
	_wide_lines.append(line)
	return line


func _build_overview() -> VBoxContainer:
	"""The filters, the table of beds and its footnote."""
	var page := VBoxContainer.new()
	var names: Array[String] = []
	names.assign(Rows.FILTER_NAMES)
	page.add_child(_button_row(names, _filters, set_filter))
	_press(_filters, filter)
	_overview = TableScript.new()
	_overview.configure(PackedStringArray(Rows.COLUMN_TITLES), OVERVIEW_RATIOS, true)
	_overview.row_pressed.connect(func(bed: int) -> void: bed_wanted.emit(bed))
	page.add_child(_overview)
	_overview_empty = _note(page, "", Palette.INK)
	_note(page, OVERVIEW_NOTE)
	return page


func _build_calendar() -> VBoxContainer:
	"""This season or the next, as a timeline or a table, the legend and what is not known."""
	var page := VBoxContainer.new()
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override(&"separation", 24)
	controls.add_child(_button_row(["This season", "Next season"] as Array[String], _season_buttons, set_next_season))
	controls.add_child(_button_row(["Timeline", "Table"] as Array[String], _view_buttons, set_table_view))
	page.add_child(controls)
	_press(_season_buttons, 0)
	_press(_view_buttons, 0)
	_calendar_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	page.add_child(_calendar_title)
	_timeline = TimelineScript.new()
	page.add_child(_timeline)
	_calendar_table = TableScript.new()
	_calendar_table.configure(PackedStringArray(["When", "What", "Kind", "Detail"]), CALENDAR_RATIOS, false)
	page.add_child(_calendar_table)
	_note(page, LEGEND)
	_notes = _note(page, "", Palette.INK)
	return page


func _build_plans() -> VBoxContainer:
	"""A bed picker, what the plans compare, the three plan columns and their note."""
	var page := VBoxContainer.new()
	var names: Array[String] = []
	for bed: int in Catalog.BED_COUNT:
		names.append("Bed %d" % (bed + 1))
	page.add_child(_button_row(names, _bed_buttons, set_plan_bed))
	_press(_bed_buttons, plan_bed)
	_compared = _note(page, "", Palette.INK)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 14)
	for k: int in Plans.PLAN_COUNT:
		columns.add_child(_plan_column(k))
	page.add_child(columns)
	_open_bed = FarmUi.button("", NOTE_PX)
	_open_bed.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_open_bed.pressed.connect(func() -> void: bed_wanted.emit(plan_bed))
	page.add_child(_open_bed)
	_note(page, PLANS_NOTE)
	return page


func _plan_column(k: int) -> VBoxContainer:
	"""One plan's column: its name, its lines and what stands in its way."""
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(FarmUi.label(Plans.PLAN_NAMES[k], FarmUi.BODY_PX, Palette.INK, true))
	var lines: Label = FarmUi.label("", NOTE_PX, Palette.INK)
	column.add_child(lines)
	_plan_columns.append(lines)
	var warning: Label = FarmUi.label("", NOTE_PX, Palette.CLAY)
	column.add_child(warning)
	_plan_warnings.append(warning)
	return column


func _build_record() -> VBoxContainer:
	"""Yesterday, the season's totals, its days as a table, and where the figures come from."""
	var page := VBoxContainer.new()
	page.add_child(FarmUi.label("Yesterday", FarmUi.BODY_PX, Palette.INK, true))
	_yesterday = _note(page, "", Palette.INK)
	page.add_child(FarmUi.label("This season", FarmUi.BODY_PX, Palette.INK, true))
	_season_line = _note(page, "", Palette.INK)
	_record_table = TableScript.new()
	_record_table.configure(PackedStringArray(RecordText.TABLE_TITLES), RECORD_RATIOS, false)
	page.add_child(_record_table)
	_note(page, RECORD_NOTE)
	return page


static func _press(buttons: Array[Button], which: int) -> void:
	"""Show button `which` of a toggle row pressed, the rest not, without pressing them."""
	for k: int in buttons.size():
		buttons[k].set_pressed_no_signal(k == which)


# --- opening, tabs and choices ----------------------------------------------------------------------------------------

func toggle() -> bool:
	"""Open or close; returns whether it is now open. It opens on the tab it last showed."""
	visible = not visible
	if visible:
		_season_key[0] = -1
		_plans_key[0] = -1
		refresh()
		_place.call_deferred()
	return visible


func open() -> void:
	"""Open (if closed)."""
	if not visible:
		toggle()


func close() -> void:
	"""Close (the gate's Esc and T, and the ×)."""
	visible = false


func show_tab(which: int) -> void:
	"""Show tab `which` (TAB_*)."""
	view = clampi(which, TAB_OVERVIEW, TAB_RECORD)
	_press(_tabs, view)
	refresh()


func set_filter(which: int) -> void:
	"""The overview's filter (farm_plan_rows.gd FILTER_*)."""
	filter = clampi(which, Rows.FILTER_ALL, Rows.FILTER_SOON)
	_press(_filters, filter)
	refresh()


func set_next_season(which: int) -> void:
	"""The calendar shows this season (0) or the next (1)."""
	next_season = which == 1
	_press(_season_buttons, which)
	_season_key[0] = -1
	refresh()


func set_table_view(which: int) -> void:
	"""The calendar as a timeline (0) or a table (1)."""
	table_view = which == 1
	_press(_view_buttons, which)
	refresh()


func set_plan_bed(bed: int) -> void:
	"""The bed the soil plans are for."""
	plan_bed = clampi(bed, 0, Catalog.BED_COUNT - 1)
	_press(_bed_buttons, plan_bed)
	refresh()


func _process(delta: float) -> void:
	"""While open, repaint a few times a second."""
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_S
		refresh()


func refresh() -> void:
	"""Repaint the header and the shown tab, in place."""
	if _sim == null:
		return
	_date.text = "Today: %s" % _sim.calendar.date_text()
	for k: int in _pages.size():
		_pages[k].visible = k == view
	match view:
		TAB_OVERVIEW:
			_fill_overview()
		TAB_CALENDAR:
			_fill_calendar()
		TAB_PLANS:
			_fill_plans()
		TAB_RECORD:
			_fill_record()


# --- the tabs' contents -----------------------------------------------------------------------------------------------

func _fill_overview() -> void:
	"""The filters' counts and the beds that pass the filter, in bed order."""
	for k: int in _filters.size():
		var label: String = Rows.FILTER_NAMES[k]
		_filters[k].text = label if k == Rows.FILTER_ALL else "%s (%d)" % [label, Rows.count_matching(_sim, _crew, k, _read)]
	var shown: int = 0
	_overview.set_row_count(Rows.count_matching(_sim, _crew, filter, _read))
	for bed: int in Catalog.BED_COUNT:
		if not Rows.matches(_sim, _crew, bed, filter, _read):
			continue
		Rows.cells_into(_sim, _crew, bed, _read, _cells)
		var warn: bool = Rows.needs_attention(_sim, _crew, bed, _read)
		_overview.set_row(shown, _cells, bed, Palette.CLAY if warn else Palette.INK,
			"Open bed %d and centre the camera on it" % (bed + 1))
		shown += 1
	_overview_empty.text = Rows.FILTER_EMPTY[filter] if shown == 0 else ""
	_overview_empty.visible = shown == 0


func _fill_calendar() -> void:
	"""Rebuild the season's entries when anything they read changed, then the timeline or the table."""
	@warning_ignore("integer_division") var now_season: int = (_sim.calendar.now().absolute_day - 1) / SimClock.DAYS_PER_SEASON
	_season_now[0] = _sim.calendar.hour_index()
	_season_now[1] = _record.revision if _record != null else 0
	_season_now[2] = _sim.revision
	_season_now[3] = _kitchen.revision if _kitchen != null else 0
	_season_now[4] = 1 if next_season else 0
	_season_now[5] = _season.fuel.revision if _season.fuel != null else 0
	if _season_now != _season_key:
		_season_key = _season_now.duplicate()
		_season.build(_sim, _record, _kitchen, now_season + (1 if next_season else 0))
		_timeline.show_season(_season)
		_fill_calendar_table()
	_calendar_title.text = _season.title() + ("" if next_season else " — today is %s" % _sim.calendar.date_text())
	_timeline.visible = not table_view
	_calendar_table.visible = table_view
	_notes.text = "\n".join(_season.notes)
	_notes.visible = not _season.notes.is_empty()


func _fill_calendar_table() -> void:
	"""Every entry in words, by day: when, what, its kind of knowing and its detail."""
	var order: PackedInt32Array = _season.order()
	_calendar_table.set_row_count(order.size())
	for n: int in order.size():
		var k: int = order[n]
		_cells.resize(4)
		_cells[0] = _season.when_text(k)
		_cells[1] = _season.label[k]
		_cells[2] = SeasonScript.KNOWING_NAMES[_season.knowing[k]]
		_cells[3] = _season.detail[k]
		_calendar_table.set_row(n, _cells, k, Palette.INK)


func _fill_plans() -> void:
	"""The three plans for the chosen bed, redrawn only when the farm, the hour, the bed or the compost store changed."""
	_plans_now[0] = _sim.revision
	_plans_now[1] = _sim.calendar.hour_index()
	_plans_now[2] = plan_bed
	_plans_now[3] = _sim.compost_milli
	if _plans_now == _plans_key:
		return
	_plans_key = _plans_now.duplicate()
	var start: Plans.Start = Plans.start_of(_sim, plan_bed, _read)
	var plans: Array[Plans.Plan] = Plans.plans_for(_sim, plan_bed, _read)
	_compared.text = "Bed %d (%s): %s" % [plan_bed + 1, Rows.crop_text(_sim, plan_bed).to_lower(),
		PlanText.compared_for(Plans.reference_crop(_sim, plan_bed), start)]
	for k: int in plans.size():
		_plan_columns[k].text = "\n".join(PlanText.lines(plans[k], _sim.fertility_of(plan_bed)))
		_plan_warnings[k].text = PlanText.warning(plans[k])
		_plan_warnings[k].visible = not _plan_warnings[k].text.is_empty()
	_open_bed.text = "Open bed %d" % (plan_bed + 1)


func _fill_record() -> void:
	"""Yesterday's line, this season's totals and days, and the last season's totals."""
	var days: int = _record.day_count() if _record != null else 0
	_yesterday.text = RecordText.day_line(_record, days - 1) if days > 0 else NO_DAY_YET
	@warning_ignore("integer_division") var now_season: int = (_sim.calendar.now().absolute_day - 1) / SimClock.DAYS_PER_SEASON
	var lines := PackedStringArray([RecordText.season_line(_record, now_season)])
	if now_season > 0 and _record.season_days(now_season - 1) > 0:
		lines.append("Last season — " + RecordText.season_line(_record, now_season - 1))
	_season_line.text = "\n".join(lines)
	var shown: int = 0
	_record_table.set_row_count(_record.season_days(now_season))
	for k: int in days:
		@warning_ignore("integer_division") if _record.value(k, RecordScript.F_DAY) / SimClock.DAYS_PER_SEASON == now_season:
			RecordText.table_cells_into(_record, k, _cells)
			var short: bool = _record.value(k, RecordScript.F_WITHOUT) > 0 or _record.value(k, RecordScript.F_LOST) > 0
			_record_table.set_row(shown, _cells, k, Palette.CLAY if short else Palette.INK)
			shown += 1


# --- placement and readouts -------------------------------------------------------------------------------------------

func _place() -> void:
	"""The whole of the HUD's modal rectangle at the HUD's scale (the Work screen's rule): the header and tabs take what
	they need and the page scrolls in the rest; the full-width lines are given the frame's width outright."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var rect := Rect2(zone.position + Vector2(FarmUi.FRAME_EXPAND, FarmUi.FRAME_EXPAND),
		zone.size - Vector2(2.0, 2.0) * FarmUi.FRAME_EXPAND)
	var inner: float = rect.size.x - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2] - 16.0
	for line: Label in _wide_lines:
		line.custom_minimum_size.x = inner
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = rect.size
	_frame.size = rect.size


func close_button() -> Button:
	"""The header's × (the gate's last focus stop)."""
	return _close


func tab_button(which: int) -> Button:
	"""Tab `which`'s button (checks)."""
	return _tabs[which]


func filter_button(which: int) -> Button:
	"""Filter `which`'s button (checks)."""
	return _filters[which]


func overview() -> TableScript:
	"""The overview's table (checks)."""
	return _overview


func calendar_table() -> TableScript:
	"""The calendar's table (checks)."""
	return _calendar_table


func timeline() -> TimelineScript:
	"""The calendar's timeline (checks)."""
	return _timeline


func season() -> SeasonScript:
	"""The season the calendar shows (checks)."""
	return _season


func record_table() -> TableScript:
	"""The record's table (checks)."""
	return _record_table


func plan_texts(k: int) -> String:
	"""Plan column `k`'s lines as shown (checks)."""
	return _plan_columns[k].text


func plan_warning(k: int) -> String:
	"""Plan column `k`'s warning as shown ('' hidden; checks)."""
	return _plan_warnings[k].text if _plan_warnings[k].visible else ""


func yesterday_text() -> String:
	"""The Record tab's first line (checks)."""
	return _yesterday.text


func date_text() -> String:
	"""The header's date line (checks)."""
	return _date.text


func open_bed_button() -> Button:
	"""The Soil plans tab's "Open bed N" (checks)."""
	return _open_bed


func frame_rect() -> Rect2:
	"""Where the planner is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
