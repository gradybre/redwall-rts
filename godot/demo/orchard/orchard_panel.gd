extends CanvasLayer
## The "Orchard (demo)" panel (decisions 0671-0677): the right column's fifth panel, with no tab of its own (decision
## 0671: the strip holds four at 1280x720) -- clicking an orchard tree, a planting site, a hedge bush, a basket stand,
## the nursery or the grove brings it, and any tab takes the zone back. DEMO UI: titled so; presentation only -- its
## buttons emit `action` with a name (ACTION_*) and demo_orchard.gd decides.
##
## PLACEMENT is the woods panel's (forest_panel.gd): the HUD's DETAIL ZONE below the tab strip, shown or hidden by
## demo/ui/demo_detail_zone.gd (`set_zone`), yielding to the resident journal, at the HUD's scale, scrolling inside
## when the zone is short (1280x720).
##
## WHAT IT SHOWS: the orchard's standing line (the date, the picking windows, what has been picked); the SELECTED thing
## and its verbs, each with its action card as tooltip (the reason it is refused, when it is); its GROUP's policy
## (ECO-010: timing, destination, the nursery's share); the NURSERY (ECO-009: saplings and plans, each plan's first
## fruiting season); the GROVE (ECO-015: protected or not, its record); and the board's orchard jobs.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")

signal action(name: StringName)

const TITLE: String = "Orchard (demo)"
const BUTTON_TEXT: Dictionary = {
	&"tend": "Tend", &"harvest": "Harvest", &"pick": "Pick berries", &"plant_apple": "Plant apple",
	&"plant_pear": "Plant pear", &"plan_apple": "Plan an apple", &"plan_pear": "Plan a pear",
	&"drop_plan": "Drop the plan", &"haul": "Send baskets on", &"timing": "Timing", &"dest": "Send to",
	&"keep": "Keep for nursery", &"protect": "Protected", &"observe": "Observe now",
	&"service": "Tend the bees", &"feed": "Feed the bees", &"recolonize": "Recolonise",
}
const SELECTION_ACTIONS: Array[StringName] = [&"tend", &"harvest", &"pick", &"plant_apple", &"plant_pear",
	&"plan_apple", &"plan_pear", &"drop_plan", &"haul", &"observe", &"service", &"feed", &"recolonize"]
const GROUP_ACTIONS: Array[StringName] = [&"timing", &"dest", &"keep"]
const GROVE_ACTIONS: Array[StringName] = [&"protect"]
const NOTHING: String = "Click an orchard tree, a site's pegs, a hedge bush, the baskets, the nursery, the grove or the skep."
const DETAIL_NAME: String = "UI-SET-036"
const FRAME_EXPAND: float = 10.0
const TITLE_PX: int = 19
const BODY_PX: int = 14
const SMALL_PX: int = 14
const BUTTON_H: float = 32.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [8.0, 5.0, 8.0, 6.0]

var _frame: PanelContainer = null
var _body: ScrollContainer = null
var _column: VBoxContainer = null
var _lines: Dictionary = {}
var _buttons: Dictionary = {}
var _group_box: VBoxContainer = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _detail: Control = null
var _detail_open: bool = false
var _width: float = 316.0
var _zone_shown: bool = false
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
	name = "OrchardPanel"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	add_child(_frame)
	_body = DemoScroll.new()
	_frame.add_child(_body)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 5)
	_body.add_child(_column)
	_column.add_child(_label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font()))
	_add_line(&"status", BODY_PX, Palette.INK)
	_section(&"title", &"text", SELECTION_ACTIONS)
	_group_box = _section(&"group_title", &"group", GROUP_ACTIONS)
	_section(&"nursery_title", &"nursery", [])
	_section(&"grove_title", &"grove", GROVE_ACTIONS)
	_add_line(&"jobs", SMALL_PX, Palette.UMBER)
	_frame.visible = false


func _add_line(key: StringName, px: int, colour: Color) -> void:
	"""One standing line."""
	_lines[key] = _label("", px, colour, null)
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
	if not keys.is_empty():
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
	var made := Button.new()
	made.text = BUTTON_TEXT[key]
	Styles.focusable(made, BUTTON_MARGINS)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.custom_minimum_size.y = BUTTON_H
	made.clip_text = true
	made.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	made.add_theme_font_size_override(&"font_size", SMALL_PX)
	made.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	made.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		made.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	made.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	made.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	made.pressed.connect(func() -> void: action.emit(key))
	_buttons[key] = made
	return made


func button(key: StringName) -> Button:
	"""The button for an action (checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text: status, title, text, group_title, group, nursery_title, nursery, grove_title, grove or jobs."""
	return (_lines[key] as Label).text


func show_status(status: String, jobs: String) -> void:
	"""The panel's standing lines."""
	_set_line(&"status", status)
	_set_line(&"jobs", jobs)


func show_selection(title: String, text: String, shown: Array[StringName]) -> void:
	"""The selected thing ("" title: nothing) and which of its verbs are shown (each one's card says whether it can be
	pressed: `set_card`)."""
	_set_line(&"title", title if not title.is_empty() else NOTHING)
	_set_line(&"text", text)
	(_lines[&"text"] as Label).visible = not text.is_empty()
	for key: StringName in SELECTION_ACTIONS:
		(_buttons[key] as Button).visible = shown.has(key)


func show_group(title: String, text: String, timing: String, dest: String, keep: String) -> void:
	"""The selected thing's group and its policy ("" title: none; the section hides)."""
	_group_box.visible = not title.is_empty()
	_set_line(&"group_title", title)
	_set_line(&"group", text)
	(_buttons[&"timing"] as Button).text = "Timing: %s" % timing
	(_buttons[&"dest"] as Button).text = "To: %s" % dest
	(_buttons[&"keep"] as Button).text = "Keep: %s" % keep


func show_nursery(title: String, text: String) -> void:
	"""The nursery: its saplings and plans."""
	_set_line(&"nursery_title", title)
	_set_line(&"nursery", text)


func show_grove(title: String, text: String, protected: bool) -> void:
	"""The grove: protected or not, and its record."""
	_set_line(&"grove_title", title)
	_set_line(&"grove", text)
	(_buttons[&"protect"] as Button).text = "Protected: %s" % ("yes" if protected else "no")


func set_card(key: StringName, card_text: String, enabled: bool) -> void:
	"""An action's card (decision 0332, demo/ui/action_card.gd) as its button's tooltip, pressable only when it may."""
	var b := _buttons[key] as Button
	CardScript.dress(b)
	if b.tooltip_text != card_text:
		b.tooltip_text = card_text
	b.disabled = not enabled


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
	"""The detail zone's owner (demo_detail_zone.gd): show this panel or not, `top_inset` logical pixels below the
	zone's top -- and fit it again once its content has laid out."""
	_zone_shown = shown
	_zone_inset = top_inset
	_place()
	_place.call_deferred()


func _place() -> void:
	"""Lay the frame out in the detail zone at the HUD's scale (the woods panel's rule)."""
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
