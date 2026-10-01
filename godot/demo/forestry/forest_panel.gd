extends CanvasLayer
## The "Woods (demo)" panel: the right column's third tab. Decision 0196 (live demo). DEMO UI: it is
## not a game panel and is titled so. Presentation only -- its buttons order the demo cast, never the
## simulation.
##
## PLACEMENT is the tunnel panel's (demo/tunnel/tunnel_panel.gd): the HUD's DETAIL ZONE below the tab
## strip, shown or hidden by demo/ui/demo_detail_zone.gd (`set_zone`), yielding to the resident journal
## (UI-SET-036), at the HUD's scale, scrolling inside when the zone is short (1280x720).
##
## WHAT IT SHOWS: the demo stores' wood and planks (the one stock the tunnels' bracing and lanterns
## spend; the HUD's Wood is the settlement's); the woods' counts -- mature, young, stumps, cleared,
## trunks lying and deadfall; the season's and the weather's effect on the work; the selected tree and
## its zone's floor, with the verbs that tree takes; the selected zone and its settings; the zone tools;
## the queue; and the woods' latest news. Its buttons emit `action` with a name (ACTION_*); nothing
## here decides anything. Each job verb's tooltip is its ACTION CARD (decision 0332, `set_card`): result, cost as
## have / need, work, who will do it and what they stop, and -- disabled -- the exact refusal and its fix.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

signal action(name: StringName)

const TITLE: String = "Woods (demo)"
const ACTION_FELL: StringName = &"fell"
const ACTION_HAUL: StringName = &"haul"
const ACTION_GRUB: StringName = &"grub"
const ACTION_PLANT: StringName = &"plant"
const ACTION_FORESTRY_ZONE: StringName = &"forestry_zone"
const ACTION_CONSERVATION_ZONE: StringName = &"conservation_zone"
const ACTION_INTENSIVE: StringName = &"intensive"
const ACTION_AUTO: StringName = &"auto"
const ACTION_REMOVE_ZONE: StringName = &"remove_zone"
const ACTION_GATHER: StringName = &"gather"
const ACTION_SAW: StringName = &"saw"
const ACTION_STORM: StringName = &"storm"
const ACTION_CANCEL: StringName = &"cancel"
const BUTTON_TEXT: Dictionary = {
	&"fell": "Fell", &"haul": "Haul logs", &"grub": "Grub out stump", &"plant": "Plant sapling",
	&"forestry_zone": "Mark forestry zone", &"conservation_zone": "Mark conservation zone",
	&"intensive": "Intensive: off", &"auto": "Auto-fell", &"remove_zone": "Unmark zone",
	&"gather": "Gather deadfall", &"saw": "Saw planks", &"cancel": "Cancel woods jobs",
}
const TREE_ACTIONS: Array[StringName] = [&"fell", &"haul", &"grub", &"plant"]
const ZONE_ACTIONS: Array[StringName] = [&"intensive", &"auto", &"remove_zone"]
const TOOL_ACTIONS: Array[StringName] = [&"forestry_zone", &"conservation_zone"]
## ACTION_STORM is a test trigger: its button is the Demo Lab's (demo/ui/demo_lab.gd, decision 0261).
const WORK_ACTIONS: Array[StringName] = [&"gather", &"saw", &"cancel"]
const LINE_KEYS: Array[StringName] = [&"stores", &"counts", &"season"]
const NO_TREE: String = "Click a tree, a stump or a cleared spot in the woods."
const DETAIL_NAME: String = "UI-SET-036"
const FRAME_EXPAND: float = 10.0
const TITLE_PX: int = 19
const BODY_PX: int = 14
## UI §2.1's minimum rendered text (12 px before decision 0391).
const SMALL_PX: int = 14
## UX-T03: every button at least 32 logical px tall (decision 0391).
const BUTTON_H: float = 32.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [8.0, 5.0, 8.0, 6.0]

var _frame: PanelContainer = null
var _body: ScrollContainer = null
var _column: VBoxContainer = null
var _lines: Dictionary = {}
var _buttons: Dictionary = {}
var _tree_box: VBoxContainer = null
var _zone_box: VBoxContainer = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _detail: Control = null
var _detail_open: bool = false
var _width: float = 316.0
var _zone_shown: bool = true
var _zone_inset: float = 0.0


func _ready() -> void:
	"""Build, place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""Build the widgets (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = 0
	name = "ForestPanel"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	add_child(_frame)
	_body = ScrollContainer.new()
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_body)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_body.add_child(_column)
	_column.add_child(_label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font()))
	for key: StringName in LINE_KEYS:
		_lines[key] = _label("", BODY_PX, Palette.INK, null)
		_column.add_child(_lines[key])
	_tree_box = _section(&"tree_title", &"tree", TREE_ACTIONS)
	_zone_box = _section(&"zone_title", &"zone", ZONE_ACTIONS)
	_column.add_child(_grid(TOOL_ACTIONS))
	_column.add_child(_grid(WORK_ACTIONS))
	for key: StringName in [&"queue", &"log"]:
		_lines[key] = _label("", SMALL_PX, Palette.UMBER, null)
		_column.add_child(_lines[key])


func _section(title_key: StringName, text_key: StringName, keys: Array[StringName]) -> VBoxContainer:
	"""A titled block with a line of text and a grid of its buttons."""
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_column.add_child(box)
	_lines[title_key] = _label("", BODY_PX + 1, Palette.INK, Styles.heading_font())
	box.add_child(_lines[title_key])
	_lines[text_key] = _label("", BODY_PX, Palette.UMBER, null)
	box.add_child(_lines[text_key])
	box.add_child(_grid(keys))
	return box


func _grid(keys: Array[StringName]) -> GridContainer:
	"""Two columns of wood buttons."""
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	for key: StringName in keys:
		grid.add_child(_button(key))
	return grid


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = _width - CONTENT_MARGINS[0] - CONTENT_MARGINS[2]
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(key: StringName) -> Button:
	"""A wood button that emits `action(key)`; takes keyboard focus (decision 0261)."""
	var new_button := Button.new()
	new_button.text = BUTTON_TEXT[key]
	Styles.focusable(new_button, BUTTON_MARGINS)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_button.custom_minimum_size.y = BUTTON_H
	new_button.clip_text = true
	new_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	new_button.add_theme_font_size_override(&"font_size", SMALL_PX)
	new_button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	new_button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	new_button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	new_button.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		new_button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	new_button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	new_button.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	new_button.pressed.connect(func() -> void: action.emit(key))
	_buttons[key] = new_button
	return new_button


func button(key: StringName) -> Button:
	"""The button for an action (checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text: stores, counts, season, tree_title, tree, zone_title, zone, queue or log."""
	return (_lines[key] as Label).text


func show_status(stores: String, counts: String, season: String, queue: String, log_line: String) -> void:
	"""The panel's standing lines."""
	_set_line(&"stores", stores)
	_set_line(&"counts", counts)
	_set_line(&"season", season)
	_set_line(&"queue", queue)
	_set_line(&"log", log_line)


func show_tree(title: String, text: String, enabled: Dictionary) -> void:
	"""The selected tree ("" title: none) and which of its verbs can be pressed ({action: bool})."""
	_set_line(&"tree_title", title if not title.is_empty() else NO_TREE)
	_set_line(&"tree", text)
	(_lines[&"tree"] as Label).visible = not text.is_empty()
	_enable(TREE_ACTIONS, enabled, not title.is_empty())


func show_zone(title: String, text: String, enabled: Dictionary, intensive: bool, auto_on: bool) -> void:
	"""The selected zone ("" title: none; the section hides), its settings shown on its toggles."""
	_zone_box.visible = not title.is_empty()
	_set_line(&"zone_title", title)
	_set_line(&"zone", text)
	(_buttons[ACTION_INTENSIVE] as Button).tooltip_text = "Intensive: the zone keeps 10% of its trees mature, not 20% (GDD §5.9)"
	(_buttons[ACTION_INTENSIVE] as Button).text = "Intensive: %s" % ("on" if intensive else "off")
	(_buttons[ACTION_AUTO] as Button).text = "Auto-fell: %s" % ("on" if auto_on else "off")
	_enable(ZONE_ACTIONS, enabled, not title.is_empty())


func _enable(keys: Array[StringName], enabled: Dictionary, shown: bool) -> void:
	"""Show these buttons (or not), each pressable only when `enabled` says so."""
	for key: StringName in keys:
		var b := _buttons[key] as Button
		b.visible = shown
		b.disabled = not bool(enabled.get(key, false))


func set_card(key: StringName, card_text: String, enabled: bool) -> void:
	"""An action's card (decision 0332, demo/ui/action_card.gd) as its button's tooltip, the button pressable only
	when the card allows it (its visibility is the section's)."""
	var b := _buttons[key] as Button
	CardScript.dress(b)
	if b.tooltip_text != card_text:
		b.tooltip_text = card_text
	b.disabled = not enabled


func set_tool_armed(key: StringName) -> void:
	"""Show which zone tool is armed (its button pressed-looking; &"": none)."""
	for tool: StringName in TOOL_ACTIONS:
		(_buttons[tool] as Button).text = ("Drag on the ground… (Esc)" if tool == key else BUTTON_TEXT[tool])


func _set_line(key: StringName, text: String) -> void:
	"""Set a line when its text changed, and re-place the frame (its height may have changed)."""
	var label := _lines[key] as Label
	if label.text == text:
		return
	label.text = text
	_place.call_deferred()


func watch_hud(hud_root: Control) -> void:
	"""Yield to the HUD's resident journal (found by its UI id under `hud_root`)."""
	_hud_root = hud_root


func follow_hud() -> void:
	"""Hide while the journal is open; show again once it closes. Cheap; call a few times a second."""
	if _detail == null and _hud_root != null and is_instance_valid(_hud_root):
		_detail = _hud_root.find_child(DETAIL_NAME, true, false) as Control
	var open := _detail != null and is_instance_valid(_detail) and _detail.is_visible_in_tree()
	if open != _detail_open:
		_detail_open = open
		_place()


func set_zone(shown: bool, top_inset: float) -> void:
	"""The detail zone's owner (demo_detail_zone.gd): show this panel or not, `top_inset` logical pixels
	below the zone's top -- and fit it again once its content has laid out."""
	_zone_shown = shown
	_zone_inset = top_inset
	_place()
	_place.call_deferred()


func _place() -> void:
	"""Lay the frame out in the detail zone at the HUD's scale (the tunnel panel's rule)."""
	if _frame == null:
		return
	if not is_inside_tree():
		_frame.visible = _zone_shown and not _detail_open
		return
	var size_px := get_viewport().get_visible_rect().size
	var rect := DetailZone.panel_placement(int(size_px.x), int(size_px.y), FRAME_EXPAND, _zone_inset, _layout, _geometry)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	_frame.size = Vector2(rect.size.x, 0.0)
	_body.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y,
		maxf(rect.size.y - CONTENT_MARGINS[1] - CONTENT_MARGINS[3], 0.0))
	_frame.visible = _zone_shown and not _detail_open


func is_shown() -> bool:
	"""Whether the frame is drawn."""
	return _frame != null and _frame.visible


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
