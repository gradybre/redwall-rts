extends VBoxContainer
## UX-008's "COMPARE SIMILAR" for the beds (decision 0451): the bed panel's Compare view, a sortable table of every bed
## -- the six are one kind of thing -- with the open bed marked, and each bed ringed and ranked on the map while it
## shows (farm_view.gd `set_compare`). DEMO UI, inside the bed panel's one scroll (farm_bed_panel.gd shows it in place of
## the readout and the verbs, its title in the panel's head and Back in its foot, as the crop picker).
##
## A row is the bed and its figures on one line (farm_plan_rows.gd `compare_line`: ready, the expected harvest, soil
## moisture in the panel's words, fertility); pressing it opens that bed, and the view stays open on it so the player can
## step from bed to bed. SORTS: biggest harvest, soonest ripe, furthest from its moisture range, most worn soil, bed
## number. THE ORDER IS SET WHEN A SORT IS CHOSEN (or the view opens) and HELD while it shows: figures change in place
## and no row moves under the pointer or the keyboard's focus (the review's formatting rule) until a sort is pressed again.
## There is no bulk order for beds to preview: each bed's verbs are its own (the record in decision 0451).

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const TableScript := preload("res://demo/farm/farm_planner_table.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## A row was pressed: show this bed.
signal bed_picked(bed: int)
## The order or the sort changed: the map's marks should follow (`marks`).
signal marks_changed

const SORTS: Array[int] = [Rows.SORT_HARVEST, Rows.SORT_READY, Rows.SORT_MOISTURE, Rows.SORT_FERTILITY, Rows.SORT_BED]

var sort: int = Rows.SORT_HARVEST
var order: PackedInt32Array = PackedInt32Array()

var _sim: SimScript = null
var _sort_buttons: Array[Button] = []
var _note: Label = null
var _table: TableScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _cells: PackedStringArray = PackedStringArray()


func configure(sim: SimScript) -> void:
	"""Compare this farm's beds; built hidden."""
	_sim = sim
	add_theme_constant_override(&"separation", 5)
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 6)
	row.add_theme_constant_override(&"v_separation", 4)
	var group := ButtonGroup.new()
	for k: int in SORTS.size():
		var made: Button = FarmUi.button(Rows.SORT_NAMES[SORTS[k]], FarmUi.SMALL_PX)
		made.toggle_mode = true
		made.button_group = group
		made.tooltip_text = "Sort: %s" % Rows.SORT_WORDS[SORTS[k]]
		made.pressed.connect(set_sort.bind(SORTS[k]))
		row.add_child(made)
		_sort_buttons.append(made)
	add_child(row)
	_note = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_note)
	_table = TableScript.new()
	_table.configure(PackedStringArray(["Bed — ready · harvest · soil moisture · fertility"]), PackedFloat32Array([1.0]), true)
	_table.row_pressed.connect(func(bed: int) -> void: bed_picked.emit(bed))
	add_child(_table)
	visible = false


func set_sort(which: int) -> void:
	"""Sort by `which` (farm_plan_rows.gd SORT_*), setting the order anew."""
	sort = which
	for k: int in SORTS.size():
		_sort_buttons[k].set_pressed_no_signal(SORTS[k] == sort)
	order = Rows.sorted_beds(_sim, sort, _read)
	marks_changed.emit()


func open() -> void:
	"""Show, its order set now by the current sort."""
	visible = true
	set_sort(sort)


func close() -> void:
	"""Hide (the map's marks go with it)."""
	visible = false
	marks_changed.emit()


func refresh(open_bed: int) -> void:
	"""Re-word every row in place, in the held order, the open bed marked."""
	if not visible or _sim == null:
		return
	_note.text = "Sorted: %s. The order holds while this shows; press a sort to sort again." % Rows.SORT_WORDS[sort]
	_table.set_row_count(order.size())
	for n: int in order.size():
		var bed: int = order[n]
		var heading: String = "%d. Bed %d · %s%s" % [n + 1, bed + 1, Rows.crop_text(_sim, bed),
			" (this bed)" if bed == open_bed else ""]
		_cells.resize(1)
		_cells[0] = "%s\n%s" % [heading, Rows.compare_line(_sim, bed, _read)]
		_table.set_row(n, _cells, bed, Palette.INK, "Open bed %d" % (bed + 1))


func marks() -> PackedStringArray:
	"""Each bed's mark on the map while this shows: '#2 by harvest' ('' for every bed when hidden)."""
	var out := PackedStringArray()
	out.resize(Catalog.BED_COUNT)
	if not visible:
		return out
	for n: int in order.size():
		out[order[n]] = "#%d by %s" % [n + 1, Rows.SORT_NAMES[sort].to_lower()]
	return out


func title() -> String:
	"""The view's title in the panel's head."""
	return "Compare beds — %s" % Rows.SORT_WORDS[sort]


func table() -> TableScript:
	"""The rows (checks)."""
	return _table


func sort_button(which: int) -> Button:
	"""The button for SORT_* `which` (checks)."""
	return _sort_buttons[SORTS.find(which)]
