extends CanvasLayer
## The bed panel: one crop bed's readout and every verb the player has for it, and the crop picker.
## Decision 0196. DEMO UI in the woodland skin, in the HUD's right column (UI §1.2's detail zone,
## "Bottom-right: Context info panel"), drawn below the HUD's own layer so a true modal covers it.
##
## With no bed selected it shows the farm's calendar -- which runs apart from the HUD's date -- and
## how to start. With a bed: its crop and stage with the hours to ripe or to withering, moisture
## against the crop's band, soil fertility and health, what has been done to the ground (drained,
## irrigated, raised, banked, covered), the expected yield, and the jobs on it; then the verbs.
## A verb that cannot be done now is disabled, its reason in its tooltip. "Plant…" opens the PICKER:
## every ingredient, those sowable now first, each with its row's growth hours, yield, family and its
## rotation effect IN THIS BED (the same family again shows the penalty; legumes say they feed the
## soil), the rest disabled with the reason -- soil or planting window.
##
## The panel only shows and asks: pressing emits a signal and demo_farm.gd orders the work.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

signal verb_requested(kind: int)
signal crop_picked(item: int)
signal fallow_toggled
signal cancel_requested
signal close_requested

const HINT: String = "Click a crop bed to tend it · right-click it with residents selected to set them to its most pressing work · V: moisture / ripeness map · K: pantry"
## The verbs with a button of their own, in order (sowing is "Plant…").
const VERB_KINDS: Array[int] = [JobsScript.KIND_WATER, JobsScript.KIND_HARVEST, JobsScript.KIND_CLEAR,
	JobsScript.KIND_COMPOST, JobsScript.KIND_COVER, JobsScript.KIND_RAISE, JobsScript.KIND_BANK]
const VERB_LABELS: Array[String] = ["Water", "Harvest", "Clear", "Compost", "Cover", "Raise", "Bank"]
const PICKER_MAX_H: float = 520.0
## The farm's latest warnings, newest first, always shown under the calendar.
const NEWS_LINES: int = 3
## An order's answer stays under the readout this long (real time), then goes.
const MESSAGE_MSEC: int = 8000
const COLUMNS: int = 3

var bed: int = -1
var picking: bool = false

var _sim: SimScript = null
var _crew: CrewScript = null
var _frame: PanelContainer = null
var _title: Label = null
var _clock: Label = null
var _news: Array[Label] = []
var _lines: Array[Label] = []
var _message: Label = null
var _hint: Label = null
var _message_since: int = 0
var _actions: GridContainer = null
var _verb_buttons: Array[Button] = []
var _plant: Button = null
var _fallow: Button = null
var _cancel: Button = null
var _picker: VBoxContainer = null
var _picker_rows: VBoxContainer = null
var _picker_title: Label = null
var _scroll: ScrollContainer = null
var _pick_buttons: Array[Button] = []
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func configure(sim: SimScript, crew: CrewScript) -> void:
	"""Read this farm, and build."""
	_sim = sim
	_crew = crew
	layer = 0
	name = "FarmBedPanel"
	_build()
	show_nothing()


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Frame, header, readout lines, message, verbs and the picker."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_frame.add_child(column)
	column.add_child(_header())
	_clock = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_clock)
	for k: int in NEWS_LINES:
		_news.append(FarmUi.label("", FarmUi.SMALL_PX, Palette.CLAY))
		_news[k].visible = false
		column.add_child(_news[k])
	for k: int in 6:
		_lines.append(FarmUi.label("", FarmUi.BODY_PX, Palette.INK))
		column.add_child(_lines[k])
	_message = FarmUi.label("", FarmUi.BODY_PX, Palette.CLAY)
	_message.visible = false
	column.add_child(_message)
	_actions = _build_actions()
	column.add_child(_actions)
	_picker = _build_picker()
	column.add_child(_picker)
	_hint = FarmUi.label(HINT, FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_hint)


func _header() -> HBoxContainer:
	"""The title and the close button."""
	var row := HBoxContainer.new()
	_title = FarmUi.label("Farm", FarmUi.TITLE_PX, Palette.INK, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	var close := FarmUi.button("×", FarmUi.BODY_PX)
	close.tooltip_text = "Close the bed panel (Esc)"
	close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close)
	return row


func _build_actions() -> GridContainer:
	"""Plant…, the verbs, Fallow and Cancel jobs."""
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	_plant = FarmUi.button("Plant…")
	_plant.pressed.connect(open_picker)
	grid.add_child(_plant)
	for k: int in VERB_KINDS.size():
		var made: Button = FarmUi.button(VERB_LABELS[k])
		made.pressed.connect(func() -> void: verb_requested.emit(VERB_KINDS[k]))
		grid.add_child(made)
		_verb_buttons.append(made)
	_fallow = FarmUi.button("Rest")
	_fallow.pressed.connect(func() -> void: fallow_toggled.emit())
	grid.add_child(_fallow)
	_cancel = FarmUi.button("Cancel jobs")
	_cancel.pressed.connect(func() -> void: cancel_requested.emit())
	grid.add_child(_cancel)
	for child: Node in grid.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


func _build_picker() -> VBoxContainer:
	"""The crop picker: a title, a scrolling list of every ingredient, and Back."""
	var box := VBoxContainer.new()
	box.visible = false
	_picker_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	box.add_child(_picker_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = PICKER_MAX_H
	box.add_child(_scroll)
	_picker_rows = VBoxContainer.new()
	_picker_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_rows.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_picker_rows)
	var back := FarmUi.button("Back")
	back.pressed.connect(close_picker)
	box.add_child(back)
	return box


# --- what it shows ------------------------------------------------------------------------------

func show_nothing() -> void:
	"""No bed: the farm calendar and how to start."""
	bed = -1
	picking = false
	refresh()


func show_bed(p_bed: int) -> void:
	"""Show one bed (its verbs; the picker closed)."""
	bed = p_bed
	picking = false
	show_message("")
	refresh()


func push_news(text: String) -> void:
	"""A farm warning (farm_alerts.gd): shown at the top, newest first; the oldest of NEWS_LINES goes."""
	for k: int in range(NEWS_LINES - 1, 0, -1):
		_news[k].text = _news[k - 1].text
		_news[k].visible = _news[k - 1].visible
	_news[0].text = "• " + text
	_news[0].visible = true
	_place.call_deferred()


func news_text(k: int) -> String:
	"""News line `k`, newest first (tests)."""
	return _news[k].text if _news[k].visible else ""


func show_message(text: String) -> void:
	"""One line under the readout: what an order did, or why it could not."""
	_message.text = text
	_message.visible = not text.is_empty()
	_message_since = Time.get_ticks_msec()


func refresh() -> void:
	"""Rewrite every line and button state from the sim."""
	if _sim == null:
		return
	_clock.text = Text.clock_line(_sim)
	if _message.visible and Time.get_ticks_msec() - _message_since > MESSAGE_MSEC:
		_message.visible = false
	var has_bed: bool = Catalog.is_bed(bed)
	_title.text = _bed_title() if has_bed else "Farm"
	for label: Label in _lines:
		label.visible = has_bed and not picking
	_actions.visible = has_bed and not picking
	_picker.visible = has_bed and picking
	_hint.visible = not has_bed
	if has_bed and not picking:
		_fill_lines()
		_fill_buttons()
	_place.call_deferred()


func _bed_title() -> String:
	"""'Bed 3 · Carrot'."""
	var item: int = _sim.item_of(bed)
	var what: String = Catalog.ITEM_LABELS[item] if Catalog.is_item(item) else "empty"
	return "Bed %d · %s" % [bed + 1, what]


func _fill_lines() -> void:
	"""The readout lines."""
	var texts: PackedStringArray = [Text.stage_line(_sim, bed, _read), Text.moisture_line(_sim, bed),
		Text.soil_line(_sim, bed), Text.works_line(_sim, bed), Text.yield_line(_sim, bed, _read), _jobs_line()]
	for k: int in _lines.size():
		_lines[k].text = texts[k]
		_lines[k].visible = not texts[k].is_empty()


func _jobs_line() -> String:
	"""The jobs on this bed and who has them ('' for none)."""
	var parts := PackedStringArray()
	var jobs: JobsScript = _crew.jobs
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.bed[row] == bed:
			var who: String = _crew.worker_name(row)
			parts.append("%s (%s)" % [JobsScript.KIND_NAMES[jobs.kind[row]], who if who != "" else "waiting"])
	return ("Jobs: " + ", ".join(parts)) if not parts.is_empty() else ""


func _fill_buttons() -> void:
	"""Enable each verb that can be done now; a disabled one says why in its tooltip."""
	var spoil: int = _crew.max_heap_spoil()
	for k: int in VERB_KINDS.size():
		_set_state(_verb_buttons[k], JobsScript.refusal_for(_sim, VERB_KINDS[k], bed, spoil))
	var empty: bool = _sim.stage_of(bed) == SimScript.STAGE_EMPTY
	_set_state(_plant, &"" if empty and not _sim.is_fallow(bed) else &"BED_NOT_EMPTY_OR_RESTING")
	_fallow.text = "Unrest" if _sim.is_fallow(bed) else "Rest"
	_fallow.tooltip_text = "Rest the bed fallow: nothing is sown; it regains 50 fertility a day"
	_set_state(_cancel, &"" if _jobs_line() != "" else &"NO_JOBS")


static func _set_state(button: Button, refusal: StringName) -> void:
	"""Enable a button, or disable (and dim) it with the refusal in words as its tooltip."""
	FarmUi.set_enabled(button, refusal == &"", String(refusal).to_lower().replace("_", " "))


# --- the picker ---------------------------------------------------------------------------------

func open_picker() -> void:
	"""List every ingredient for this bed (see the header)."""
	if not Catalog.is_bed(bed):
		return
	picking = true
	_picker_title.text = "Plant bed %d (%s) — %s" % [bed + 1, Text.SOILS[Catalog.BED_SOILS[bed]], Text.clock_line(_sim)]
	for child: Node in _picker_rows.get_children():
		_picker_rows.remove_child(child)
		child.queue_free()
	_pick_buttons.resize(Catalog.ITEM_COUNT)
	for pass_index: int in 2:
		for item: int in Catalog.ITEM_COUNT:
			var reason: String = Text.pick_reason(_sim, bed, item)
			if (reason == "") == (pass_index == 0):
				_picker_rows.add_child(_pick_row(item, reason))
	refresh()


func _pick_row(item: int, reason: String) -> Control:
	"""One ingredient: a button (disabled with a reason) over its rotation / soil effect."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var pick: Button = FarmUi.button(Catalog.ITEM_LABELS[item], FarmUi.BODY_PX)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	FarmUi.set_enabled(pick, reason == "", reason)
	pick.pressed.connect(func() -> void: crop_picked.emit(item))
	row.add_child(pick)
	_pick_buttons[item] = pick
	var detail: String = Text.pick_row(_sim, bed, item)
	if reason != "":
		detail = "%s — can't: %s" % [detail, reason]
	row.add_child(FarmUi.label(detail, FarmUi.SMALL_PX, Palette.UMBER if reason != "" else Palette.INK))
	return row


func close_picker() -> void:
	"""Back to the bed's verbs."""
	picking = false
	refresh()


func picker_row_count() -> int:
	"""How many ingredients the picker lists (tests)."""
	return _picker_rows.get_child_count()


func verb_button(kind: int) -> Button:
	"""The button for a verb (tests and the scripted check)."""
	if kind == JobsScript.KIND_SOW:
		return _plant
	return _verb_buttons[VERB_KINDS.find(kind)]


func picker_button(item: int) -> Button:
	"""The open picker's button for an ingredient (every ingredient is listed; tests and the check)."""
	return _pick_buttons[item]


func line_text(k: int) -> String:
	"""Readout line `k` (tests)."""
	return _lines[k].text


# --- placement --------------------------------------------------------------------------------

func _place() -> void:
	"""In the right column (the HUD's detail zone), at the HUD's scale."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.detail
	var rect := Rect2(zone.position + Vector2(FarmUi.FRAME_EXPAND, FarmUi.FRAME_EXPAND),
		zone.size - Vector2(2.0, 2.0) * FarmUi.FRAME_EXPAND)
	_scroll.custom_minimum_size.y = clampf(rect.size.y - 140.0, 120.0, PICKER_MAX_H)
	FarmUi.place(_frame, rect, _geometry.scale)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks and the demo's click routing)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
