extends CanvasLayer
## The bed panel: one crop bed's readout and every verb the player has for it, and the crop picker.
## Decision 0196. DEMO UI in the woodland skin, in the HUD's right column (UI §1.2's detail zone,
## "Bottom-right: Context info panel"), drawn below the HUD's own layer so a true modal covers it. It
## shares that zone with the tunnels panel, ONE AT A TIME: demo/ui/demo_detail_zone.gd shows it or
## hides it, and places it below its tab strip (`set_zone`).
##
## With no bed selected it shows the demo calendar's date -- the very date the HUD shows -- and how to
## start, nothing else: the farm's notices are the HUD news strip's (demo/ui/demo_news_strip.gd), not
## repeated here (playtest 2026-09-29). With a bed, ONLY that bed: its title; one NEEDS line naming
## its most pressing condition and the verb that answers it (farm_text.gd -- hidden when nothing
## presses, clay only for a warning); its crop and stage with the hours to ripe or to withering,
## moisture against the crop's band, soil fertility and health, what has been done to the ground, the
## expected yield, and the jobs on it; then the verbs. A harvest waiting for store room (farm_crew.gd
## CONSERVATION, decision 0222) adds a clay line saying how much has nowhere to go and a "Make room…"
## button that opens the Pantry.
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
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")

signal verb_requested(kind: int)
signal crop_picked(item: int)
signal fallow_toggled
signal cancel_requested
signal close_requested
signal pantry_requested

const HINT: String = "Click a crop bed to tend it · right-click it with residents selected to set them to its most pressing work · V: map overlays (moisture, ripeness, water) · K: pantry"
## The verbs with a button of their own, in order (sowing is "Plant…"): with Plant… and the two
## moisture verbs on the first row, four rows of three.
const VERB_KINDS: Array[int] = [JobsScript.KIND_WATER, JobsScript.KIND_DRAIN, JobsScript.KIND_HARVEST,
	JobsScript.KIND_CLEAR, JobsScript.KIND_COMPOST, JobsScript.KIND_COVER, JobsScript.KIND_RAISE,
	JobsScript.KIND_BANK]
const VERB_LABELS: Array[String] = ["Water", "Drain", "Harvest", "Clear", "Compost", "Cover", "Raise", "Bank"]
const PICKER_MAX_H: float = 520.0
## An order's answer stays under the readout this long (real time), then goes.
const MESSAGE_MSEC: int = 8000
const COLUMNS: int = 3

var bed: int = -1
var picking: bool = false

var _sim: SimScript = null
var _crew: CrewScript = null
var _zone_shown: bool = true
var _zone_inset: float = 0.0
var _frame: PanelContainer = null
## The content scrolls inside the frame when the zone is shorter than it (1280x720).
var _body: ScrollContainer = null
var _column: VBoxContainer = null
var _title: Label = null
var _clock: Label = null
var _needs: Label = null
var _lines: Array[Label] = []
var _message: Label = null
var _shortage: Label = null
var _make_room: Button = null
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
var _goods: GoodsScript = null


func configure(sim: SimScript, crew: CrewScript) -> void:
	"""Read this farm and its crew, and build."""
	_sim = sim
	_crew = crew
	layer = 0
	name = "FarmBedPanel"
	_build()
	show_nothing()


func set_goods(goods: GoodsScript) -> void:
	"""Show each ingredient's icon in the crop picker (farm_goods.gd)."""
	_goods = goods


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Frame, header, the date (no bed), the Needs line, readout lines, message, verbs, the picker."""
	var column: VBoxContainer = _build_frame()
	column.add_child(_header())
	_clock = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_clock)
	_needs = FarmUi.label("", FarmUi.BODY_PX, Palette.CLAY)
	_needs.visible = false
	column.add_child(_needs)
	for k: int in 6:
		_lines.append(FarmUi.label("", FarmUi.BODY_PX, Palette.INK))
		column.add_child(_lines[k])
	_message = FarmUi.label("", FarmUi.BODY_PX, Palette.CLAY)
	_message.visible = false
	column.add_child(_message)
	_build_shortage(column)
	_actions = _build_actions()
	column.add_child(_actions)
	_picker = _build_picker()
	column.add_child(_picker)
	_hint = FarmUi.label(HINT, FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_hint)


func _build_shortage(column: VBoxContainer) -> void:
	"""The storage shortage line and its "Make room…" button, both hidden until a harvest waits."""
	_shortage = FarmUi.label("", FarmUi.BODY_PX, Palette.CLAY)
	_shortage.visible = false
	column.add_child(_shortage)
	_make_room = FarmUi.button("Make room… (Pantry, K)")
	_make_room.visible = false
	_make_room.pressed.connect(func() -> void: pantry_requested.emit())
	column.add_child(_make_room)


func _build_frame() -> VBoxContainer:
	"""The carved frame, the scroll its content sits in when the zone is short, and the column."""
	_frame = FarmUi.frame()
	add_child(_frame)
	_body = ScrollContainer.new()
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_body)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_column)
	return _column


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


func show_message(text: String) -> void:
	"""One line under the readout: what an order did, or why it could not."""
	_message.text = text
	_message.visible = not text.is_empty()
	_message_since = Time.get_ticks_msec()


func refresh() -> void:
	"""Rewrite every line and button state from the sim."""
	if _sim == null:
		return
	if _message.visible and Time.get_ticks_msec() - _message_since > MESSAGE_MSEC:
		_message.visible = false
	var has_bed: bool = Catalog.is_bed(bed)
	_title.text = _bed_title() if has_bed else "Farm"
	_clock.text = Text.clock_line(_sim)
	_clock.visible = not has_bed
	for label: Label in _lines:
		label.visible = has_bed and not picking
	_needs.visible = false
	_shortage.visible = false
	_make_room.visible = false
	_actions.visible = has_bed and not picking
	_picker.visible = has_bed and picking
	_hint.visible = not has_bed
	if has_bed and not picking:
		_fill_needs()
		_fill_lines()
		_fill_buttons()
	_place.call_deferred()


func _bed_title() -> String:
	"""'Bed 3 · Carrot'."""
	var item: int = _sim.item_of(bed)
	var what: String = Catalog.ITEM_LABELS[item] if Catalog.is_item(item) else "empty"
	return "Bed %d · %s" % [bed + 1, what]


func _fill_needs() -> void:
	"""The Needs line: the bed's most pressing condition and its verb, clay for a warning, else ink;
	hidden when nothing presses."""
	if not Text.need_of_into(_sim, bed, _read):
		return
	var need: int = _read.value
	_needs.text = Text.need_text(_sim, bed, need, _read)
	_needs.add_theme_color_override(&"font_color", Palette.CLAY if Text.need_is_warning(need) else Palette.INK)
	_needs.visible = true


func needs_text() -> String:
	"""The Needs line as shown ('' when hidden; tests)."""
	return _needs.text if _needs.visible else ""


func needs_colour() -> Color:
	"""The Needs line's colour (tests)."""
	return _needs.get_theme_color(&"font_color")


func shown_texts() -> PackedStringArray:
	"""Every line of words the panel draws now, in order (tests: what the player reads)."""
	var out := PackedStringArray()
	for node: Node in _column.find_children("*", "Label", true, false):
		var label := node as Label
		if _shown_in_column(label):
			out.append(label.text)
	return out


func _shown_in_column(control: Control) -> bool:
	"""Whether `control` and every parent up to the column is visible (works off-tree too, where
	is_visible_in_tree is always false)."""
	var node: Node = control
	while node != null and node != _column:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return true


func _fill_lines() -> void:
	"""The readout lines."""
	var texts: PackedStringArray = [Text.stage_line(_sim, bed, _read), Text.moisture_line(_sim, bed),
		Text.soil_line(_sim, bed), Text.works_line(_sim, bed), Text.yield_line(_sim, bed, _read), _jobs_line()]
	for k: int in _lines.size():
		_lines[k].text = texts[k]
		_lines[k].visible = not texts[k].is_empty()
	_shortage.text = _crew.shortage_text(bed)
	_shortage.visible = not _shortage.text.is_empty()
	_make_room.visible = _shortage.visible


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
	if _goods != null:
		FarmUi.set_icon(pick, _goods.icon_of(item))
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


func shortage_line() -> String:
	"""The storage shortage line as shown ('' when hidden; tests)."""
	return _shortage.text if _shortage.visible else ""


func make_room_button() -> Button:
	"""The "Make room…" button (tests)."""
	return _make_room


func line_text(k: int) -> String:
	"""Readout line `k` (tests)."""
	return _lines[k].text


# --- placement --------------------------------------------------------------------------------

func set_zone(shown: bool, top_inset: float) -> void:
	"""The detail zone's owner (demo_detail_zone.gd): show this panel or not, starting `top_inset`
	logical pixels below the zone's top -- and fit it again once its content has laid out (a panel
	shown for the first time still carries a hidden-state height)."""
	_zone_shown = shown
	_zone_inset = top_inset
	_place()
	_place.call_deferred()


func is_shown() -> bool:
	"""Whether the panel is drawn."""
	return _frame != null and _frame.visible


func _place() -> void:
	"""In the right column (the HUD's detail zone, below the zone's tab strip), at the HUD's scale."""
	if _frame == null:
		return
	_frame.visible = _zone_shown
	if not is_inside_tree():
		return
	var rect: Rect2 = placement(get_viewport().get_visible_rect().size, _zone_inset, _layout, _geometry)
	_scroll.custom_minimum_size.y = clampf(rect.size.y - 140.0, 120.0, PICKER_MAX_H)
	_body.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y,
		maxf(rect.size.y - FarmUi.CONTENT_MARGINS[1] - FarmUi.CONTENT_MARGINS[3], 0.0))
	FarmUi.place(_frame, rect, _geometry.scale)


static func placement(viewport_size: Vector2, top_inset: float, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The panel's rectangle in the HUD's logical pixels: the detail zone below `top_inset` (the zone's
	tab strip), inset by the carved frame, above the command strip where they overlap -- the zone's
	own rule (demo_detail_zone.gd `panel_placement`). Fills `geometry`."""
	return DetailZone.panel_placement(int(viewport_size.x), int(viewport_size.y), FarmUi.FRAME_EXPAND, top_inset,
		layout, geometry)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks and the demo's click routing)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
