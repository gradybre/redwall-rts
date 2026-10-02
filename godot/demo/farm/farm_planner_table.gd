extends VBoxContainer
## One TABLE of the seasonal planner (decision 0451): a header row and pooled rows of cells, columns at stable relative
## widths, re-worded in place (decision 0391's rule: rows are pools, never rebuilt while shown, so a focus, a hover or a
## click between press and release is never dropped). A PRESSABLE table's rows are whole-row buttons -- a click or Enter
## anywhere on the row -- in the parchment's own look with a faint wash on hover and the HUD's focus ring (decision
## 0261); a plain table's rows are text. The planner's farm overview, its calendar table and its record use it. DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

## A pressable row was pressed: the id its row was given (`set_row`).
signal row_pressed(id: int)

const CELL_PX: int = 14
const ROW_MARGINS: PackedFloat32Array = [6.0, 4.0, 6.0, 4.0]
const CELL_MIN_W: float = 24.0
const HOVER_ALPHA: float = 0.1
const PRESSED_ALPHA: float = 0.2

var _ratios: PackedFloat32Array = PackedFloat32Array()
var _pressable: bool = false
var _header: HBoxContainer = null
var _rows: Array[Control] = []
var _cells: Array[Array] = []
var _ids: PackedInt32Array = PackedInt32Array()
## Each row's colour and accessible description as last written (written again only when they change).
var _colours: PackedColorArray = PackedColorArray()
var _descriptions: PackedStringArray = PackedStringArray()
var _shown: int = 0


func configure(titles: PackedStringArray, ratios: PackedFloat32Array, pressable: bool) -> void:
	"""The columns' titles and relative widths, and whether a row is a button."""
	_ratios = ratios
	_pressable = pressable
	add_theme_constant_override(&"separation", 2)
	_header = _cell_row(titles.size(), true)
	for k: int in titles.size():
		(_header.get_child(k) as Label).text = titles[k]
	add_child(_header)


func _cell_row(columns: int, heading: bool) -> HBoxContainer:
	"""An HBox of `columns` wrapping labels at the table's relative widths."""
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: int in columns:
		var cell: Label = FarmUi.label("", CELL_PX, Palette.INK, heading)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_stretch_ratio = _ratios[k] if k < _ratios.size() else 1.0
		cell.custom_minimum_size.x = CELL_MIN_W
		line.add_child(cell)
	return line


func set_row_count(count: int) -> void:
	"""Show `count` rows (the pool grows to it once; rows past it are hidden, not freed)."""
	while _rows.size() < count:
		_add_row()
	for k: int in _rows.size():
		_rows[k].visible = k < count
	_shown = count


func _add_row() -> void:
	"""One more pooled row."""
	var cells: HBoxContainer = _cell_row(_header.get_child_count(), false)
	var line: Control = cells
	if _pressable:
		line = _row_button(cells)
	_rows.append(line)
	_ids.append(-1)
	_colours.append(Color.TRANSPARENT)
	_descriptions.append("")
	var labels: Array = []
	for child: Node in cells.get_children():
		labels.append(child)
	_cells.append(labels)
	add_child(line)


func _row_button(cells: HBoxContainer) -> Button:
	"""A whole-row button holding the cells: parchment, a wash on hover and press, the focus ring."""
	var button := Button.new()
	Styles.focusable(button, ROW_MARGINS)
	button.add_theme_stylebox_override(&"normal", Styles.clear(ROW_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.wash(HOVER_ALPHA, ROW_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.wash(PRESSED_ALPHA, ROW_MARGINS))
	button.add_theme_stylebox_override(&"hover_pressed", Styles.wash(PRESSED_ALPHA, ROW_MARGINS))
	button.custom_minimum_size.y = FarmUi.BUTTON_H
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cells.offset_left = ROW_MARGINS[0]
	cells.offset_top = ROW_MARGINS[1]
	cells.offset_right = -ROW_MARGINS[2]
	cells.offset_bottom = -ROW_MARGINS[3]
	button.add_child(cells)
	cells.minimum_size_changed.connect(_fit_row.bind(button, cells))
	var index: int = _rows.size()
	button.pressed.connect(func() -> void: row_pressed.emit(_ids[index]))
	return button


func _fit_row(button: Button, cells: HBoxContainer) -> void:
	"""A row button as tall as its tallest wrapped cell."""
	button.custom_minimum_size.y = maxf(FarmUi.BUTTON_H, cells.get_combined_minimum_size().y + ROW_MARGINS[1]
		+ ROW_MARGINS[3])


func set_row(k: int, cells: PackedStringArray, id: int, colour: Color = Palette.INK, tooltip: String = "") -> void:
	"""Row `k`'s words, the id it reports when pressed, its text colour and its tooltip (written only when changed)."""
	_ids[k] = id
	var recolour: bool = _colours[k] != colour
	_colours[k] = colour
	var labels: Array = _cells[k]
	var changed: bool = false
	for c: int in labels.size():
		var cell := labels[c] as Label
		var text: String = cells[c] if c < cells.size() else ""
		if cell.text != text:
			cell.text = text
			changed = true
		if recolour:
			cell.add_theme_color_override(&"font_color", colour)
	if _rows[k].tooltip_text != tooltip:
		_rows[k].tooltip_text = tooltip
	if _pressable and (changed or _descriptions[k].is_empty()):
		_descriptions[k] = " · ".join(cells)
		_rows[k].accessibility_description = _descriptions[k]


func shown_rows() -> int:
	"""How many rows show."""
	return _shown


func row(k: int) -> Control:
	"""Row `k` (a Button in a pressable table; checks)."""
	return _rows[k]


func row_id(k: int) -> int:
	"""The id row `k` reports."""
	return _ids[k]


func row_colour(k: int) -> Color:
	"""Row `k`'s text colour as written (checks)."""
	return _colours[k]


func row_texts(k: int) -> PackedStringArray:
	"""Row `k`'s cells as shown (checks)."""
	var out := PackedStringArray()
	for cell: Variant in _cells[k]:
		out.append((cell as Label).text)
	return out


func header_texts() -> PackedStringArray:
	"""The column titles (checks)."""
	var out := PackedStringArray()
	for cell: Node in _header.get_children():
		out.append((cell as Label).text)
	return out
