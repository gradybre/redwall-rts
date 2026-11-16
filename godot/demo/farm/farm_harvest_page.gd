extends VBoxContainer
## The seasonal planner's HARVEST PLAN tab (review ECO-003, decision 0882; farm_harvest_plan.gd): the strategy, every
## laid bed's sowing and ripening under it, each harvest day's work against the field crew's hands and its food against
## the room and the kitchen, the suggestions for an overloaded day, the custom Earlier / Later for a picked bed, and
## "Book this plan" -- one farm order. DEMO UI in the woodland skin; rows re-worded in place (farm_planner_table.gd).

const PlanScript := preload("res://demo/farm/farm_harvest_plan.gd")
const TableScript := preload("res://demo/farm/farm_planner_table.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const NOTE_PX: int = 14
const BED_RATIOS: PackedFloat32Array = [0.5, 1.5, 0.9, 0.9, 0.7, 1.4]
const DAY_RATIOS: PackedFloat32Array = [0.8, 1.2, 0.7, 1.1, 2.4]
const BED_TITLES: Array[String] = ["Bed", "Crop (role)", "Sow", "Ripens ≈", "Harvest ≈", "Booked / note"]
const DAY_TITLES: Array[String] = ["Harvest day", "Beds", "Harvest ≈", "Work · hands", "Room and keeping"]
const ROW_WORDS: Array[String] = ["standing", "planned", "no crop chosen (Plant…)", "no sowing day ahead", "resting"]
const NOTE: String = "≈ estimates at a full growth rate: cold, a dry or waterlogged bed, frost and blight slow or spoil a crop. Work is each harvest's own cutting and drop (the walks not counted); hands are the field crew's ten work hours a day. Keeping is what the kitchen eats of a crop before it spoils in the slowest store. Nothing changes until you book: a bed planned for today is sown now, a later one when its day comes; a crop is never changed for you."
const NO_BED: int = -1

var picked_bed: int = NO_BED
var wide: Array[Label] = []

var _plan: PlanScript = null
var _strategy_buttons: Array[Button] = []
var _strategy_note: Label = null
var _beds: TableScript = null
var _days: TableScript = null
var _suggestions: Label = null
var _picked: Label = null
var _earlier: Button = null
var _later: Button = null
var _book: Button = null
var _answer: Label = null
var _cells: PackedStringArray = PackedStringArray()
## What the shown tables were computed for: the plan's revision, the farm's, the hour and the pick (`refresh`).
var _seen: PackedInt64Array = PackedInt64Array([-1, 0, 0, 0])
var _now: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])


func _init() -> void:
	"""Built at once; filled by `refresh` once a plan is bound."""
	name = "HarvestPlanPage"
	add_theme_constant_override(&"separation", 6)
	add_child(_strategy_row())
	_strategy_note = _note("", Palette.UMBER)
	_beds = TableScript.new()
	_beds.configure(PackedStringArray(BED_TITLES), BED_RATIOS, true)
	_beds.row_pressed.connect(pick_bed)
	add_child(_beds)
	add_child(_shift_row())
	_days = TableScript.new()
	_days.configure(PackedStringArray(DAY_TITLES), DAY_RATIOS, false)
	add_child(_days)
	_suggestions = _note("", Palette.CLAY)
	_book = FarmUi.button("Book this plan", NOTE_PX)
	_book.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_book.tooltip_text = "One farm order: the beds planned for today are sown now, the rest on their days"
	_book.pressed.connect(book)
	add_child(_book)
	_answer = _note("", Palette.INK)
	_note(NOTE, Palette.UMBER)


func _strategy_row() -> HFlowContainer:
	"""The three strategies, one pressed."""
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 8)
	var group := ButtonGroup.new()
	for k: int in PlanScript.STRATEGY_COUNT:
		var made: Button = FarmUi.button(PlanScript.STRATEGY_NAMES[k], NOTE_PX)
		made.toggle_mode = true
		made.button_group = group
		made.tooltip_text = PlanScript.STRATEGY_NOTES[k]
		made.pressed.connect(set_strategy.bind(k))
		row.add_child(made)
		_strategy_buttons.append(made)
	return row


func _shift_row() -> HBoxContainer:
	"""The picked bed and its Earlier / Later (custom dates)."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_picked = FarmUi.label("", NOTE_PX, Palette.INK)
	_picked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_picked)
	_earlier = FarmUi.button("Sow a day earlier", NOTE_PX)
	_earlier.pressed.connect(shift.bind(-1))
	row.add_child(_earlier)
	_later = FarmUi.button("Sow a day later", NOTE_PX)
	_later.pressed.connect(shift.bind(1))
	row.add_child(_later)
	return row


func _note(text: String, colour: Color) -> Label:
	"""A full-width wrapping line (the planner widens it: `wide`)."""
	var line: Label = FarmUi.label(text, NOTE_PX, colour)
	add_child(line)
	wide.append(line)
	return line


func bind(plan: PlanScript) -> void:
	"""Show this harvest plan."""
	_plan = plan
	refresh()


# --- the player's choices --------------------------------------------------------------------------------------------

func set_strategy(which: int) -> void:
	"""Choose a strategy (farm_harvest_plan.gd STRATEGY_*)."""
	if _plan != null:
		_plan.set_strategy(which)
	_seen[0] = -1
	refresh()


func pick_bed(bed: int) -> void:
	"""A bed row was pressed: Earlier / Later act on it (a bed with no planned sowing is no pick)."""
	picked_bed = bed if _plan != null and _plan.is_planned(bed) else NO_BED
	refresh()


func shift(days: int) -> String:
	"""Move the picked bed's sowing `days` (custom dates). Returns the answer shown."""
	var said: String = _plan.shift(picked_bed, days) if _plan != null and picked_bed != NO_BED else "Pick a bed's row first"
	_answer.text = said
	_seen[0] = -1
	refresh()
	return said


func book() -> String:
	"""Book the plan as one farm order. Returns the answer shown."""
	var said: String = _plan.book() if _plan != null else ""
	_answer.text = said
	_seen[0] = -1
	refresh()
	return said


# --- filling ---------------------------------------------------------------------------------------------------------

func refresh() -> void:
	"""Rewrite the strategy, the beds, the days and the suggestions from the plan as it stands -- recomputed only when the
	plan, the farm or the hour changed (`_seen`), so the planner's quarter-second repaint costs a comparison."""
	if _plan == null:
		return
	_now[0] = _plan.revision
	_now[1] = _plan.farm_revision()
	_now[2] = _plan.hour_index()
	_now[3] = picked_bed
	if _now == _seen:
		return
	_seen = _now.duplicate()
	if picked_bed != NO_BED and not _plan.is_planned(picked_bed):
		picked_bed = NO_BED
	for k: int in _strategy_buttons.size():
		_strategy_buttons[k].set_pressed_no_signal(k == _plan.strategy)
	_strategy_note.text = "%s: %s." % [PlanScript.STRATEGY_NAMES[_plan.strategy], PlanScript.STRATEGY_NOTES[_plan.strategy]]
	_fill_beds()
	_fill_days()
	_picked.text = "Picked: Bed %d" % (picked_bed + 1) if picked_bed != NO_BED else "Pick a planned bed's row to sow it earlier or later"
	for button: Button in [_earlier, _later]:
		FarmUi.set_enabled(button, picked_bed != NO_BED, "Pick a bed's row first")


func _fill_beds() -> void:
	"""One row a laid bed (farm_harvest_plan.gd `rows`)."""
	var rows: Array[PlanScript.Row] = _plan.rows()
	_beds.set_row_count(rows.size())
	for k: int in rows.size():
		bed_cells_into(_plan, rows[k], _cells)
		_beds.set_row(k, _cells, rows[k].bed, Palette.LEAF if rows[k].bed == picked_bed else Palette.INK,
			"Pick Bed %d to sow it earlier or later" % (rows[k].bed + 1))


static func bed_cells_into(plan: PlanScript, row: PlanScript.Row, out: PackedStringArray) -> void:
	"""A bed row's cells: bed, crop and role, sowing, ripening, harvest, booking or what the row is."""
	out.resize(BED_TITLES.size())
	out[0] = "Bed %d" % (row.bed + 1)
	out[1] = PlanScript.role_words(row.item) if Catalog.is_item(row.item) else "—"
	out[2] = plan.day_text(row.sow_day) if row.state == PlanScript.ROW_PLANNED else ("sown" if row.state == PlanScript.ROW_STANDING else "—")
	out[3] = plan.day_text(row.ripe_day) if row.ripe_day != PlanScript.NO_DAY else "—"
	out[4] = Rows.harvest_cell(row.item, row.milli) if row.milli > 0 else "—"
	var booked: String = plan.booking_text(row.bed)
	out[5] = booked if not booked.is_empty() else ROW_WORDS[row.state]


func _fill_days() -> void:
	"""One row a harvest day; an overloaded one in clay, its suggestion below."""
	var days: Array[PlanScript.Day] = _plan.days()
	_days.set_row_count(days.size())
	var tips := PackedStringArray()
	for k: int in days.size():
		day_cells_into(_plan, days[k], _cells)
		_days.set_row(k, _cells, days[k].day, Palette.CLAY if days[k].over != 0 else Palette.INK)
		if days[k].over != 0:
			tips.append("%s: %s. %s." % [_plan.day_text(days[k].day), _plan.over_words(days[k]), _plan.suggestion(days[k])])
	_suggestions.text = "\n".join(tips)
	_suggestions.visible = not tips.is_empty()


static func day_cells_into(plan: PlanScript, day: PlanScript.Day, out: PackedStringArray) -> void:
	"""A harvest day's cells: the day, its beds, its food, its work against the hands, its room and keeping."""
	out.resize(DAY_TITLES.size())
	out[0] = plan.day_text(day.day)
	var beds := PackedStringArray()
	for bed: int in day.beds:
		beds.append("Bed %d" % (bed + 1))
	out[1] = ", ".join(beds)
	out[2] = Rows.harvest_cell(Catalog.NO_ITEM, day.milli)
	out[3] = "%s of %s (%d hands)" % [_minutes(day.work_usec), _minutes(plan.hands_usec()), plan.hands()]
	out[4] = plan.over_words(day) if day.over != 0 else "fits: %s free; eaten before it spoils" % Rows.harvest_cell(
		Catalog.NO_ITEM, plan.room_milli())


static func _minutes(usec: int) -> String:
	"""Demo time as game hours and minutes on the one calendar: '25 min', '1 h 15 min', '20 h'."""
	@warning_ignore("integer_division") var minutes: int = usec * 60 / CalendarScript.HOUR_USEC
	if minutes < 60:
		return "%d min" % minutes
	@warning_ignore("integer_division") return "%d h" % (minutes / 60) if minutes % 60 == 0 else "%d h %d min" % [minutes / 60, minutes % 60]


func bed_table() -> TableScript:
	"""The beds' table (checks)."""
	return _beds


func day_table() -> TableScript:
	"""The harvest days' table (checks)."""
	return _days


func suggestions_text() -> String:
	"""The suggestions as shown ('' hidden; checks)."""
	return _suggestions.text if _suggestions.visible else ""


func book_button() -> Button:
	"""'Book this plan' (checks)."""
	return _book


func strategy_button(which: int) -> Button:
	"""Strategy `which`'s button (checks)."""
	return _strategy_buttons[which]
