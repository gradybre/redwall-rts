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
## the soil moisture as a band and a percentage over a banded meter (farm_moisture_meter.gd) and the
## crop's suitable range, the soil, its fertility and that fertility's effect on the yield, the crop's
## health, what has been done to the ground, ONE expected harvest, and the jobs on it; then "Details",
## which shows the harvest's multiplication and the raw 0..10000 readings (decision 0251, F34); then the
## verbs, each enabled one's tooltip saying its effect in points (Rest: "+0.5 fertility points a day").
## A harvest waiting for store room (farm_crew.gd CONSERVATION, decision 0222) adds a clay line saying
## how much has nowhere to go and a "Make room…" button that opens the Pantry.
## EVERY VERB'S TOOLTIP IS ITS ACTION CARD (decision 0332, review F33/F44; demo/ui/action_card.gd): the result, the
## cost as have / need, the work in game hours, who will do it (the crew's own `decide`: the nearest free selected
## resident, else the field crew's queue), what that resident stops and whether it goes back to it, what the verb
## needs -- and, disabled, the exact refusal the order would give and how to put it right. The same `decide` runs
## the order, so the card and the answer to pressing agree. "Plant…" opens the PICKER:
## every ingredient, those sowable now first, each with its row's growth hours, yield, family and its
## rotation effect IN THIS BED (the same family again shows the penalty; legumes say they feed the
## soil), the rest disabled with the reason -- soil or planting window.
##
## The panel only shows and asks: pressing emits a signal and demo_farm.gd orders the work.

const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
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
const MeterScript := preload("res://demo/farm/farm_moisture_meter.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

signal verb_requested(kind: int)
signal crop_picked(item: int)
signal fallow_toggled
signal cancel_requested
signal close_requested
signal pantry_requested

const HINT: String = "Click a crop bed to tend it · right-click it with residents selected to set them to its most pressing work · V or the Map layer picker: map layers · K: pantry"
## The verbs with a button of their own, in order (sowing is "Plant…"): with Plant… and the two
## moisture verbs on the first row, four rows of three.
const VERB_KINDS: Array[int] = [JobsScript.KIND_WATER, JobsScript.KIND_DRAIN, JobsScript.KIND_HARVEST,
	JobsScript.KIND_CLEAR, JobsScript.KIND_COMPOST, JobsScript.KIND_COVER, JobsScript.KIND_RAISE,
	JobsScript.KIND_BANK]
const VERB_LABELS: Array[String] = ["Water", "Drain", "Harvest", "Clear", "Compost", "Cover", "Raise", "Bank"]
## An order's answer stays under the readout this long (real time), then goes.
const MESSAGE_MSEC: int = 8000
const COLUMNS: int = 3
## The readout lines, in order (see `_fill_lines`); the meter sits under LINE_MOISTURE.
const LINE_COUNT: int = 10
const LINE_MOISTURE: int = 1
const DETAILS_SHOW: String = "Details ▸"
const DETAILS_HIDE: String = "Details ▾"
const CANCEL_TIP: String = "Cancel every job on this bed only (a harvest in hand goes into store; earth in hand goes back to its heap)"
const NO_JOBS_TIP: String = "no jobs"

var bed: int = -1
var picking: bool = false

var _sim: SimScript = null
var _crew: CrewScript = null
var _zone_shown: bool = true
var _zone_inset: float = 0.0
var _frame: PanelContainer = null
## The frame's three parts: the fixed head (title, ×, the picker's title), the ONE scrolling body, the fixed foot
## (the picker's Back) -- decision 0391, review F12's crop-picker overflow.
var _outer: VBoxContainer = null
var _head: VBoxContainer = null
var _foot: VBoxContainer = null
## The content scrolls inside the frame when the zone is shorter than it (1280x720).
var _body: DemoScroll = null
var _column: VBoxContainer = null
var _title: Label = null
var _clock: Label = null
var _needs: Label = null
var _lines: Array[Label] = []
var _meter: MeterScript = null
var _details_button: Button = null
var _details: Label = null
var _details_open: bool = false
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
var _back: Button = null
var _pick_buttons: Array[Button] = []
## Each crop's line under its button in the open picker (by item), re-worded in place (refresh_picker).
var _pick_details: Array[Label] = []
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _goods: GoodsScript = null
## The action cards' inputs (set_preview): who is selected, and what an order would interrupt.
var _members: Callable = Callable()
var _interrupt: Callable = Callable()
var _card: CardScript = CardScript.new()
var _no_members: PackedInt32Array = PackedInt32Array()
var _place_queued: bool = false


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


func set_preview(members: Callable, interrupt: Callable) -> void:
	"""The action cards' inputs: `members() -> PackedInt32Array` the selected residents (demo_command.gd `selected`),
	`interrupt(who) -> String` what an order would interrupt (demo_command.gd `interrupt_text`)."""
	_members = members
	_interrupt = interrupt


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Frame, header, the date (no bed), the Needs line, readout lines, message, verbs, the picker."""
	var column: VBoxContainer = _build_frame()
	_head.add_child(_header())
	_clock = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	column.add_child(_clock)
	_needs = FarmUi.label("", FarmUi.BODY_PX, Palette.CLAY)
	_needs.visible = false
	column.add_child(_needs)
	for k: int in LINE_COUNT:
		_lines.append(FarmUi.label("", FarmUi.BODY_PX, Palette.INK))
		column.add_child(_lines[k])
		if k == LINE_MOISTURE:
			_meter = MeterScript.new()
			column.add_child(_meter)
	_build_details(column)
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
func _build_details(column: VBoxContainer) -> void:
	"""The Details toggle and what it shows: the harvest's breakdown and the raw readings."""
	_details_button = FarmUi.button(DETAILS_SHOW, FarmUi.SMALL_PX + 1)
	_details_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_details_button.tooltip_text = "How the expected harvest is worked out, and the raw readings"
	_details_button.pressed.connect(toggle_details)
	column.add_child(_details_button)
	_details = FarmUi.label("", FarmUi.SMALL_PX + 1, Palette.UMBER)
	_details.visible = false
	column.add_child(_details)


func toggle_details() -> void:
	"""Show or hide the Details (the choice holds from bed to bed)."""
	_details_open = not _details_open
	refresh()


func details_text() -> String:
	"""The Details as shown ('' while hidden; tests)."""
	return _details.text if _details.visible else ""


func meter() -> MeterScript:
	"""The moisture meter (tests)."""
	return _meter


func _build_frame() -> VBoxContainer:
	"""The carved frame: its fixed head, the ONE scroll its content sits in when the zone is short, and its fixed
	foot. Returns the scroll's column."""
	_frame = FarmUi.frame()
	add_child(_frame)
	_outer = VBoxContainer.new()
	_outer.add_theme_constant_override(&"separation", 5)
	_frame.add_child(_outer)
	_head = VBoxContainer.new()
	_head.add_theme_constant_override(&"separation", 3)
	_outer.add_child(_head)
	_body = DemoScroll.new()
	_outer.add_child(_body)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_column)
	_foot = VBoxContainer.new()
	_foot.visible = false
	_outer.add_child(_foot)
	for part: Control in [_head, _column, _foot] as Array[Control]:
		part.minimum_size_changed.connect(_queue_place)
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
	"""The crop picker's list of every ingredient, in the panel's one scroll (its title is in the head, Back in the
	foot: neither scrolls away)."""
	var box := VBoxContainer.new()
	box.visible = false
	_picker_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	_picker_title.visible = false
	_head.add_child(_picker_title)
	_back = FarmUi.button("Back")
	_back.tooltip_text = "Back to the bed's verbs"
	_back.pressed.connect(close_picker)
	_foot.add_child(_back)
	_picker_rows = VBoxContainer.new()
	_picker_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_rows.add_theme_constant_override(&"separation", 4)
	box.add_child(_picker_rows)
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
	_meter.visible = has_bed and not picking
	_details_button.visible = has_bed and not picking
	_details.visible = has_bed and not picking and _details_open
	_needs.visible = false
	_shortage.visible = false
	_make_room.visible = false
	_actions.visible = has_bed and not picking
	_picker.visible = has_bed and picking
	_picker_title.visible = _picker.visible
	_foot.visible = _picker.visible
	_hint.visible = not has_bed
	if has_bed and not picking:
		_fill_needs()
		_fill_lines()
		_fill_buttons()
	elif has_bed:
		refresh_picker()
	_queue_place()


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
	for node: Node in _outer.find_children("*", "Label", true, false):
		var label := node as Label
		if _shown_in_frame(label):
			out.append(label.text)
	return out


func _shown_in_frame(control: Control) -> bool:
	"""Whether `control` and every parent up to the frame's head, scroll and foot is visible (works off-tree too,
	where is_visible_in_tree is always false)."""
	var node: Node = control
	while node != null and node != _outer:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return true


func _fill_lines() -> void:
	"""The readout lines."""
	var texts: PackedStringArray = [Text.stage_line(_sim, bed, _read), Text.moisture_line(_sim, bed),
		Text.range_line(_sim, bed), Text.soil_line(_sim, bed), Text.fertility_line(_sim, bed),
		Text.fertility_effect_line(_sim, bed), Text.health_line(_sim, bed), Text.works_line(_sim, bed),
		Text.yield_line(_sim, bed, _read), _jobs_line()]
	for k: int in _lines.size():
		_lines[k].text = texts[k]
		_lines[k].visible = not texts[k].is_empty()
	_shortage.text = _crew.shortage_text(bed)
	_shortage.visible = not _shortage.text.is_empty()
	_make_room.visible = _shortage.visible
	_meter.show_reading(_sim.moisture_of(bed), _sim.band_min_of(bed), _sim.band_max_of(bed),
		FarmingScript.MOISTURE_NEAR_MARGIN)
	_meter.accessibility_description = "%s. %s" % [texts[LINE_MOISTURE], texts[LINE_MOISTURE + 1]]
	_details_button.text = DETAILS_HIDE if _details_open else DETAILS_SHOW
	if _details_open:
		var breakdown: String = Text.harvest_breakdown(_sim, bed, _read)
		_details.text = (breakdown + "\n" if not breakdown.is_empty() else "") + Text.raw_line(_sim, bed)


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
	"""Each verb enabled when its card allows it, its card as its tooltip either way (see EVERY VERB'S TOOLTIP)."""
	var members: PackedInt32Array = _selected()
	for k: int in VERB_KINDS.size():
		_crew.preview_into(_card, VERB_KINDS[k], bed, members)
		_show_card(_verb_buttons[k])
	_fill_plant(members)
	_fallow.text = "Unrest" if _sim.is_fallow(bed) else "Rest"
	_fallow.tooltip_text = Text.rest_tip()
	var jobs: bool = _jobs_line() != ""
	FarmUi.set_card(_cancel, jobs, CANCEL_TIP if jobs else NO_JOBS_TIP)


func _fill_plant(members: PackedInt32Array) -> void:
	"""Plant…'s card: sowing as the first crop sowable here now would be ordered (who, work); refused for a bed that
	is not empty or is resting -- the picker then shows each crop's own card."""
	var first: int = Catalog.NO_ITEM
	for item: int in Catalog.ITEM_COUNT:
		if _sim.sow_refusal(bed, item) == &"":
			first = item
			break
	_crew.preview_into(_card, JobsScript.KIND_SOW, bed, members, first)
	_card.verb = "Plant… " + _crew.bed_label(bed)
	_card.result = "Choose a crop from the list; then it is sown" if first != Catalog.NO_ITEM \
		else "No crop can be sown here now: the list says why for each"
	var code: StringName = SimScript.REFUSE_FALLOW if _sim.is_fallow(bed) else &""
	if code == &"" and _sim.stage_of(bed) != SimScript.STAGE_EMPTY:
		code = FarmingScript.REFUSE_NOT_EMPTY
	if code != &"":
		_card.refuse(String(code), CrewScript.reason_text(code), FarmCard.fix_for(code))
	elif first == Catalog.NO_ITEM:
		_card.clear_refusal()
		_card.who = ""
	_show_card(_plant)


func _show_card(button: Button) -> void:
	"""Enable `button` as the card allows, with the card -- and what its resident would stop -- as its tooltip."""
	if _card.worker >= 0 and _interrupt.is_valid():
		_card.interrupts = String(_interrupt.call(_card.worker))
	FarmUi.set_card(button, _card.is_ok(), _card.text())


func _selected() -> PackedInt32Array:
	"""The selected residents (none without a command layer)."""
	return _members.call() as PackedInt32Array if _members.is_valid() else _no_members


func card() -> CardScript:
	"""The last card filled (tests)."""
	return _card


static func _set_state(button: Button, refusal: StringName) -> void:
	"""Enable a button, or disable (and dim) it with the refusal in words as its tooltip."""
	FarmUi.set_enabled(button, refusal == &"", String(refusal).to_lower().replace("_", " "))


# --- the picker ---------------------------------------------------------------------------------

func open_picker() -> void:
	"""List every ingredient for this bed (see the header), those sowable now first. The order is set here only: a
	crop that becomes sowable while the picker is open is enabled where it stands (refresh_picker)."""
	if not Catalog.is_bed(bed):
		return
	picking = true
	for child: Node in _picker_rows.get_children():
		_picker_rows.remove_child(child)
		child.queue_free()
	_pick_buttons.resize(Catalog.ITEM_COUNT)
	_pick_details.resize(Catalog.ITEM_COUNT)
	for pass_index: int in 2:
		for item: int in Catalog.ITEM_COUNT:
			if (Text.pick_reason(_sim, bed, item) == "") == (pass_index == 0):
				_picker_rows.add_child(_pick_row(item))
	_body.scroll_vertical = 0
	refresh()


func _pick_row(item: int) -> Control:
	"""One ingredient: a button over its rotation / soil effect line, both filled by refresh_picker."""
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 1)
	var pick: Button = FarmUi.button(Catalog.ITEM_LABELS[item], FarmUi.BODY_PX)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _goods != null:
		FarmUi.set_icon(pick, _goods.icon_of(item))
	pick.pressed.connect(func() -> void: crop_picked.emit(item))
	row.add_child(pick)
	_pick_buttons[item] = pick
	_pick_details[item] = FarmUi.label("", FarmUi.SMALL_PX, Palette.INK)
	row.add_child(_pick_details[item])
	return row


func refresh_picker() -> void:
	"""The open picker as the calendar and the bed stand NOW (review F36): its title's date, and each crop's
	button -- enabled by its sowing card, disabled with the picker's reason (its sow_refusal, the code the card and
	the order share) -- and line, re-worded IN PLACE: no row is rebuilt or moved, so the focused crop and the scroll
	stay where they are."""
	if _picker_rows.get_child_count() == 0:
		return
	_picker_title.text = picker_title()
	var members: PackedInt32Array = _selected()
	for item: int in Catalog.ITEM_COUNT:
		var reason: String = Text.pick_reason(_sim, bed, item)
		_crew.preview_into(_card, JobsScript.KIND_SOW, bed, members, item)
		if not _card.is_ok() and reason != "":
			_card.reason = reason
		_show_card(_pick_buttons[item])
		var detail: String = Text.pick_row(_sim, bed, item)
		if reason != "":
			detail = "%s — can't: %s" % [detail, reason]
		var line: Label = _pick_details[item]
		if line.text != detail:
			line.text = detail
		var colour: Color = Palette.UMBER if reason != "" else Palette.INK
		if line.get_theme_color(&"font_color") != colour:
			line.add_theme_color_override(&"font_color", colour)


func picker_title() -> String:
	"""The picker's title: the bed, its soil and the date now ("Plant bed 1 (Loam) — Y1 Spring 5, 06:00 · 12 °C")."""
	return "Plant bed %d (%s) — %s" % [bed + 1, Text.SOILS[Catalog.BED_SOILS[bed]], Text.clock_line(_sim)]


func picker_title_text() -> String:
	"""The picker's title as shown ('' while it is closed; tests)."""
	return _picker_title.text if _picker_title.visible else ""


func picker_detail(item: int) -> String:
	"""A crop's line in the open picker (tests)."""
	return _pick_details[item].text


func back_button() -> Button:
	"""The picker's Back (tests and the scripted check)."""
	return _back


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
	_queue_place()


func is_shown() -> bool:
	"""Whether the panel is drawn."""
	return _frame != null and _frame.visible


func _queue_place() -> void:
	"""Place the frame again at the end of this frame, once (a content change re-measures its parts)."""
	if not _place_queued:
		_place_queued = true
		_place.call_deferred()


func _place() -> void:
	"""In the right column (the HUD's detail zone, below the zone's tab strip), at the HUD's scale: the head and
	foot as tall as they are, the one scroll in what is left."""
	_place_queued = false
	if _frame == null:
		return
	_frame.visible = _zone_shown
	if not is_inside_tree():
		return
	var rect: Rect2 = placement(get_viewport().get_visible_rect().size, _zone_inset, _layout, _geometry)
	var fixed: float = _head.get_combined_minimum_size().y + _outer.get_theme_constant(&"separation")
	if _foot.visible:
		fixed += _foot.get_combined_minimum_size().y + _outer.get_theme_constant(&"separation")
	_body.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y,
		maxf(rect.size.y - FarmUi.CONTENT_MARGINS[1] - FarmUi.CONTENT_MARGINS[3] - fixed, 0.0))
	FarmUi.place(_frame, rect, _geometry.scale)


func body() -> ScrollContainer:
	"""The panel's one scroll (checks)."""
	return _body


static func placement(viewport_size: Vector2, top_inset: float, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The panel's rectangle in the HUD's logical pixels: the detail zone below `top_inset` (the zone's
	tab strip), inset by the carved frame, above the command strip where they overlap -- the zone's
	own rule (demo_detail_zone.gd `panel_placement`). Fills `geometry`."""
	return DetailZone.panel_placement(int(viewport_size.x), int(viewport_size.y), FarmUi.FRAME_EXPAND, top_inset,
		layout, geometry)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks and the demo's click routing)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
