extends CanvasLayer
## THE OBJECT LIST (F6): every interactive thing in the village as a keyboard list. Decision 0471 (review UX-023, P9;
## UI §8.2's world list, on its own F6 `open_world_list`). DEMO UI in the woodland skin.
##
## A modal (demo_input_gate.gd: Esc, F6 or Close shut it; Tab and the arrows move through it). It lists
## world_targets.gd's targets -- residents, crop beds, trees, bridges, tunnel mouths, rooms -- as they stand when it
## opens, filtered by kind ("All" or one kind; the filter row comes first). Pressing a row (Enter, or a click) SELECTS
## that thing as a click on it in the world does -- its panel comes forward -- CENTRES the camera over it, and closes
## the list. A thing gone since the list was drawn says so instead.
##
## Rows are pooled buttons, made as the list first needs them and reused; the list scrolls in its own pixels at any
## interface scale (demo_scroll.gd).

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const TargetsScript := preload("res://demo/access/world_targets.gd")

const LAYER: int = 2
const WIDTH: float = 520.0
const TITLE: String = "Objects in the village"
const NOTE: String = "Enter on a row selects it and centres the view on it. F6 or Esc closes."
const ALL_TEXT: String = "All"
const CLOSE_TEXT: String = "Close (F6 or Esc)"
const EMPTY_TEXT: String = "Nothing of this kind in the village now."
const GONE_TEXT: String = "%s is no longer there."
const COUNT_TEXT: String = "%d listed"
## The scroll's height: the modal rectangle less this (title, note, filters, Close, margins).
const LIST_RESERVE_H: float = 200.0
## The key that opens and closes the list (UI §8.2's F6).
const ACTION: StringName = &"open_world_list"

## The targets it lists (the host's; while it is open it is a planning surface, time_control.gd).
var targets: TargetsScript = null

var _frame: PanelContainer = null
var _filters: Array[Button] = []
var _status: Label = null
var _scroll: DemoScroll = null
var _rows: VBoxContainer = null
var _row_buttons: Array[Button] = []
var _close: Button = null
var _mask: int = TargetsScript.ALL_KINDS
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "ObjectList"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_frame.add_child(column)
	column.add_child(FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true))
	column.add_child(_wrapped(NOTE))
	column.add_child(_build_filters())
	_status = _wrapped("")
	column.add_child(_status)
	_scroll = DemoScroll.new()
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(_rows)
	_close = FarmUi.button(CLOSE_TEXT)
	_close.pressed.connect(close)
	column.add_child(_close)


func _wrapped(text: String) -> Label:
	"""An umber line wrapping at the frame's inner width."""
	var line: Label = FarmUi.label(text, FarmUi.SMALL_PX, Palette.UMBER)
	line.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	return line


func _build_filters() -> HFlowContainer:
	"""All, then one toggle per kind."""
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	for k: int in TargetsScript.KIND_COUNT + 1:
		var button: Button = FarmUi.button(ALL_TEXT if k == 0 else TargetsScript.KIND_TITLES[k - 1], FarmUi.SMALL_PX)
		button.toggle_mode = true
		button.pressed.connect(set_filter.bind(TargetsScript.ALL_KINDS if k == 0 else 1 << (k - 1)))
		flow.add_child(button)
		_filters.append(button)
	return flow


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func open() -> void:
	"""Show the list as the village stands now."""
	if visible:
		return
	visible = true
	refresh()
	_place.call_deferred()


func close() -> void:
	"""Hide the list."""
	visible = false


func toggle() -> void:
	"""F6: open, or close."""
	if visible:
		close()
	else:
		open()


func set_filter(mask: int) -> void:
	"""Show the kinds in `mask` (KIND bits; ALL_KINDS: everything)."""
	_mask = mask
	refresh()


func refresh() -> void:
	"""List what exists now under the filter, the filter row lit to match."""
	for k: int in _filters.size():
		_filters[k].set_pressed_no_signal(_mask == (TargetsScript.ALL_KINDS if k == 0 else 1 << (k - 1)))
	var listed: int = targets.collect(_mask) if targets != null else 0
	while _row_buttons.size() < listed:
		_add_row()
	for k: int in _row_buttons.size():
		_row_buttons[k].visible = k < listed
		if k < listed:
			_row_buttons[k].text = targets.row_text(k)
	_status.text = EMPTY_TEXT if listed == 0 else COUNT_TEXT % listed
	_place.call_deferred()


func _add_row() -> void:
	"""One more pooled row (its index is its place in the list)."""
	var button: Button = FarmUi.button("", FarmUi.SMALL_PX)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(choose.bind(_row_buttons.size()))
	_rows.add_child(button)
	_row_buttons.append(button)


func choose(k: int) -> bool:
	"""Row `k`: select its thing and centre on it, then close; a thing gone since says so and stays open."""
	if targets == null or k < 0 or k >= targets.count():
		return false
	if not targets.pick(k):
		_status.text = GONE_TEXT % targets.label_of(k)
		return false
	close()
	return true


# --- checks -----------------------------------------------------------------------------------------------

func frame() -> PanelContainer:
	"""The carved frame (the gate's focus trap root)."""
	return _frame


func close_button() -> Button:
	"""The list's Close."""
	return _close


func row_button(k: int) -> Button:
	"""Row `k`'s button."""
	return _row_buttons[k]


func filter_button(k: int) -> Button:
	"""Filter `k` (0: All; then KIND_TITLES' order)."""
	return _filters[k]


func shown_rows() -> int:
	"""How many rows are listed."""
	return targets.count() if targets != null else 0


func status_text() -> String:
	"""The count line, or what went wrong."""
	return _status.text


func _place() -> void:
	"""Centred in the HUD's modal rectangle at the HUD's scale; the rows scroll in what is left."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(WIDTH, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	_scroll.custom_minimum_size = Vector2(0.0, minf(_rows.get_combined_minimum_size().y,
		maxf(120.0, zone.size.y - LIST_RESERVE_H)))
	_frame.reset_size()
	var height: float = minf(_frame.get_combined_minimum_size().y, zone.size.y - 2.0 * FarmUi.FRAME_EXPAND)
	var rect := Rect2(zone.position + Vector2((zone.size.x - width) / 2.0, (zone.size.y - height) / 2.0),
		Vector2(width, height))
	FarmUi.place(_frame, rect, _geometry.scale)
