extends CanvasLayer
## The Demo Lab: the demo's test triggers in one clearly labelled drawer. Decision 0261 (review F50).
## DEMO UI in the woodland skin.
##
## "Next weather", "Test event", "Storm gust" and "Cramp" made things happen at once for trying the demo;
## they sat among the Tunnels, Woods and Water panels' ordinary choices, where a player had to tell a
## debug cause from a decision the village makes. They live here now, and only here: each is the host's
## Callable (`add_trigger`) -- the same `on_action` its panel's button called, so what it does is
## unchanged. The panels keep their player-facing forecast, preparedness, rescue and recovery controls.
##
## Opened by F8 or the game menu's "Demo Lab"; a modal (demo_input_gate.gd): Esc, F8 or Close shut it.
## It does not pause: a trigger's result shows in Village news and its panel as the village runs.
## A trigger that cannot act now (Cramp with no selected swimmer) is disabled with the reason.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

const LAYER: int = 2
const WIDTH: float = 460.0
const TITLE: String = "Demo Lab"
const NOTE: String = "Test triggers for trying the demo. They make something happen at once; none is a choice the village makes."
const DONE: String = "Sent: %s. Its result shows in Village news and the %s panel."
const CLOSE_TEXT: String = "Close (F8 or Esc)"
## The hotkey that opens and closes the Lab.
const KEY: Key = KEY_F8

var _frame: PanelContainer = null
var _column: VBoxContainer = null
var _buttons: Array[Button] = []
var _labels: PackedStringArray = PackedStringArray()
var _panels: PackedStringArray = PackedStringArray()
var _actions: Array[Callable] = []
var _available: Array[Callable] = []
var _why: PackedStringArray = PackedStringArray()
var _status: Label = null
var _close: Button = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "DemoLab"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	add_child(_frame)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 8)
	_frame.add_child(_column)
	_column.add_child(FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true))
	_column.add_child(_wrapped(NOTE, FarmUi.BODY_PX))
	_status = _wrapped("", FarmUi.SMALL_PX)
	_column.add_child(_status)
	_close = FarmUi.button(CLOSE_TEXT)
	_close.pressed.connect(close)
	_column.add_child(_close)


func _wrapped(text: String, px: int) -> Label:
	"""An umber line wrapping at the frame's inner width from the start, so the frame is as tall as its
	lines (a wrapping label with no width yet asks for a line per word)."""
	var line: Label = FarmUi.label(text, px, Palette.UMBER)
	line.custom_minimum_size.x = WIDTH - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	return line


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func add_trigger(label: String, tip: String, panel_name: String, action: Callable,
		available: Callable = Callable(), why: String = "") -> Button:
	"""One trigger: its button `label` (tooltip `tip`), the panel whose news it makes, what it does, and
	optionally when it can act (`available() -> bool`, else disabled with `why`)."""
	var button: Button = FarmUi.button(label)
	button.tooltip_text = tip
	button.pressed.connect(trigger.bind(_buttons.size()))
	_column.add_child(button)
	_column.move_child(button, _column.get_child_count() - 3)
	_buttons.append(button)
	_labels.append(label)
	_panels.append(panel_name)
	_actions.append(action)
	_available.append(available)
	_why.append(why)
	return button


func trigger(index: int) -> void:
	"""Fire trigger `index` (when it can act) and say it was sent (its owner says what came of it)."""
	if index < 0 or index >= _actions.size() or not can_fire(index):
		return
	_actions[index].call()
	_status.text = DONE % [_labels[index], _panels[index]]
	refresh()


func can_fire(index: int) -> bool:
	"""Whether trigger `index` can act now."""
	return not _available[index].is_valid() or bool(_available[index].call())


func open() -> void:
	"""Show the Lab with each trigger's availability read now."""
	if visible:
		return
	_status.text = ""
	refresh()
	visible = true
	_place.call_deferred()


func close() -> void:
	"""Hide the Lab."""
	visible = false


func toggle() -> void:
	"""F8: open, or close."""
	if visible:
		close()
	else:
		open()


func refresh() -> void:
	"""Enable each trigger that can act, disable the rest with their reason."""
	for k: int in _buttons.size():
		FarmUi.set_enabled(_buttons[k], can_fire(k), _why[k])


func trigger_count() -> int:
	"""How many triggers the Lab holds."""
	return _buttons.size()


func trigger_button(index: int) -> Button:
	"""Trigger `index`'s button (checks)."""
	return _buttons[index]


func trigger_labels() -> PackedStringArray:
	"""Every trigger's label, in order (checks)."""
	return _labels


func status_text() -> String:
	"""The line saying what was last done."""
	return _status.text


func close_button() -> Button:
	"""The Lab's Close."""
	return _close


func frame() -> PanelContainer:
	"""The carved frame (the gate's focus trap root)."""
	return _frame


func _place() -> void:
	"""Centred at the top of the HUD's modal rectangle, at the HUD's scale."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(WIDTH, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	var rect := Rect2(zone.position + Vector2((zone.size.x - width) / 2.0, FarmUi.FRAME_EXPAND),
		Vector2(width, zone.size.y - 2.0 * FarmUi.FRAME_EXPAND))
	FarmUi.place(_frame, rect, _geometry.scale)
