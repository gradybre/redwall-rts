extends CanvasLayer
## The "Water (demo)" panel: the right column's fourth tab. Decision 0196 (live demo). DEMO UI -- not a
## game panel, and titled so. Its buttons order the demo cast, never the simulation.
##
## PLACEMENT is the woods panel's (demo/forestry/forest_panel.gd): the HUD's detail zone below the tab
## strip, shown or hidden by demo/ui/demo_detail_zone.gd (`set_zone`), yielding to the resident journal
## (UI-SET-036), at the HUD's scale, scrolling when the zone is short (1280x720).
##
## WHAT IT SHOWS: the water today (flow, cold, flood) and any rescue under way, in clay; every
## resident's swimming -- what it can do, what the water is doing to it, its breath and stamina; the
## dive and swim verbs; the bridge site chosen (a candidate, or two banks) with its span, deck, piers
## and cost, and the build buttons; every bridge planned or open with its stage and builder; the demo
## stores' planks and wood; and the water's latest news. Buttons emit `action(name)` (ACTION_*);
## nothing here decides anything.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")

signal action(name: StringName)

const TITLE: String = "Water (demo)"
const ACTION_PREV_SITE: StringName = &"prev_site"
const ACTION_NEXT_SITE: StringName = &"next_site"
const ACTION_SPAN_TOOL: StringName = &"span_tool"
const ACTION_BUILD_PLANK: StringName = &"build_plank"
const ACTION_BUILD_LOG: StringName = &"build_log"
const ACTION_DIVE: StringName = &"dive"
const ACTION_CONSENT: StringName = &"consent"
const ACTION_CRAMP: StringName = &"cramp"
const BUTTON_TEXT: Dictionary = {
	&"prev_site": "◀ Site", &"next_site": "Site ▶", &"span_tool": "Span two banks…",
	&"build_plank": "Build plank footbridge", &"build_log": "Build log bridge",
	&"dive": "Dive in the pond", &"consent": "Swim shortcuts: on", &"cramp": "Cramp (demo)",
}
const SITE_ACTIONS: Array[StringName] = [&"prev_site", &"next_site", &"span_tool", &"build_plank", &"build_log"]
const SWIM_ACTIONS: Array[StringName] = [&"dive", &"consent", &"cramp"]
const LINE_KEYS: Array[StringName] = [&"conditions", &"alert", &"swimmers_title", &"swimmers"]
const DETAIL_NAME: String = "UI-SET-036"
const FRAME_EXPAND: float = 10.0
const TITLE_PX: int = 19
const BODY_PX: int = 14
const SMALL_PX: int = 12
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [8.0, 5.0, 8.0, 6.0]

var _frame: PanelContainer = null
var _body: ScrollContainer = null
var _column: VBoxContainer = null
var _lines: Dictionary = {}
var _buttons: Dictionary = {}
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
	name = "WaterPanel"
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
	_add_line(&"conditions", BODY_PX, Palette.INK, null)
	_add_line(&"alert", BODY_PX, Palette.CLAY, null)
	_add_line(&"swimmers_title", BODY_PX + 1, Palette.INK, Styles.heading_font())
	_add_line(&"swimmers", SMALL_PX, Palette.UMBER, null)
	_column.add_child(_grid(SWIM_ACTIONS))
	_add_line(&"site_title", BODY_PX + 1, Palette.INK, Styles.heading_font())
	_add_line(&"site", BODY_PX, Palette.UMBER, null)
	_column.add_child(_grid(SITE_ACTIONS))
	_add_line(&"bridges", SMALL_PX, Palette.UMBER, null)
	_add_line(&"stores", SMALL_PX, Palette.INK, null)
	_add_line(&"log", SMALL_PX, Palette.UMBER, null)


func _add_line(key: StringName, px: int, colour: Color, font: Font) -> void:
	"""A wrapped line of text kept under `key`."""
	_lines[key] = _label("", px, colour, font)
	_column.add_child(_lines[key])


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
	"""A wood button that emits `action(key)` and never takes focus."""
	var button := Button.new()
	button.text = BUTTON_TEXT[key]
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override(&"font_size", SMALL_PX + 1)
	button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	button.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	button.pressed.connect(func() -> void: action.emit(key))
	_buttons[key] = button
	return button


func button(key: StringName) -> Button:
	"""The button for an action (checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text: conditions, alert, swimmers_title, swimmers, site_title, site, bridges, stores or log."""
	return (_lines[key] as Label).text


func show_water(conditions: String, alert: String, swimmers_title: String, swimmers: String) -> void:
	"""The water today, any rescue, and the swimmers."""
	_set_line(&"conditions", conditions)
	_set_line(&"alert", alert)
	(_lines[&"alert"] as Label).visible = not alert.is_empty()
	_set_line(&"swimmers_title", swimmers_title)
	_set_line(&"swimmers", swimmers)


func show_site(title: String, text: String, enabled: Dictionary) -> void:
	"""The bridge site chosen, and which of the site buttons can be pressed ({action: bool})."""
	_set_line(&"site_title", title)
	_set_line(&"site", text)
	for key: StringName in SITE_ACTIONS:
		(_buttons[key] as Button).disabled = not bool(enabled.get(key, true))


func show_status(bridges: String, stores: String, log: String) -> void:
	"""The bridges planned and open, the stores and the water's news."""
	_set_line(&"bridges", bridges)
	_set_line(&"stores", stores)
	_set_line(&"log", log)


func set_swim_buttons(consent_on: bool, enabled: Dictionary) -> void:
	"""The swim verbs: consent's state on its button, and which can be pressed."""
	(_buttons[ACTION_CONSENT] as Button).text = "Swim shortcuts: %s" % ("on" if consent_on else "off")
	for key: StringName in SWIM_ACTIONS:
		(_buttons[key] as Button).disabled = not bool(enabled.get(key, true))


func set_tool_armed(on: bool) -> void:
	"""Show the span tool armed (its button says how to finish)."""
	(_buttons[ACTION_SPAN_TOOL] as Button).text = "Click the far bank… (Esc)" if on else BUTTON_TEXT[ACTION_SPAN_TOOL]


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
