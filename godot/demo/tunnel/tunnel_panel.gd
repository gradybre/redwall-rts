extends CanvasLayer
## The "Tunnels & burrows (demo)" panel. Decision 0196 (live demo). DEMO UI: it is not a game panel
## and is titled so. Presentation only -- its buttons order the demo cast, never the simulation.
##
## ---------------------------------------------------------------------------------------
## PLACEMENT. It sits in the HUD's DETAIL ZONE, the right column below the time controls (UI §1.2),
## which it shares with the farm's bed panel ONE AT A TIME: demo/ui/demo_detail_zone.gd shows it or
## hides it and places it below its tab strip (`set_zone`). From there, as tall as its content, never
## past the zone's bottom. That zone belongs to UI-SET-036, the resident journal, when it opens -- so while it is
## open this panel hides. The zone comes from the HUD's own equations (`scripts/ui/ui_layout.gd`,
## read, never modified) in LOGICAL pixels, drawn at the HUD's scale, recomputed on every resize --
## so 1280x720, 1920x1080 and a HiDPI screen line up (the party panel does the same on the left).
##
## WHAT IT SHOWS: the weather and what it does to walking; the demo stores (the HUD's Wood and Stone
## are the simulation's, and the demo never spends them); the demo's burrow homes, their beds and
## root cellars (the HUD's Beds counter is the simulation's); the finds tally; the selected tunnel,
## its state and the jobs that can be ordered on it; and the last few things said. Its buttons emit
## `action` with a name (ACTION_*); nothing here decides anything.
##
## STYLE: the woodland skin's carved-wood frame with a parchment face, ink and umber text, wood
## buttons with cream text -- the party panel's pieces. The frame stops the mouse; no button takes
## focus (Enter while laying a tunnel must never press one).

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")

signal action(name: StringName)

const TITLE: String = "Tunnels & burrows (demo)"
const ACTION_NEXT_WEATHER: StringName = &"next_weather"
const ACTION_WIDEN: StringName = &"widen"
const ACTION_BRACE: StringName = &"brace"
const ACTION_LANTERNS: StringName = &"lanterns"
const ACTION_REPAIR: StringName = &"repair"
const ACTION_HOME: StringName = &"home"
const ACTION_CELLAR: StringName = &"cellar"
const ACTION_EVENT: StringName = &"event"
const BUTTON_TEXT: Dictionary = {
	&"next_weather": "Next weather (demo)", &"widen": "Widen", &"brace": "Brace",
	&"lanterns": "Hang lanterns", &"repair": "Repair", &"home": "Burrow home",
	&"cellar": "Root cellar", &"event": "Test event (demo)",
}
const TUNNEL_ACTIONS: Array[StringName] = [&"widen", &"brace", &"lanterns", &"repair", &"home", &"cellar"]
const NO_TUNNEL: String = "Click a finished tunnel's mouth or route to select it."
const PLANNING: String = "Laying a tunnel"
## The HUD surface this panel yields to (see PLACEMENT).
const DETAIL_NAME: String = "UI-SET-036"
const FRAME_EXPAND: float = 10.0
const TITLE_PX: int = 19
const BODY_PX: int = 14
const SMALL_PX: int = 12
## The finds shelf under the finds line: an icon per kind of find with its count, then one per relic.
const FIND_SLOTS: int = 10
const FIND_ICON_PX: float = 30.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const BUTTON_MARGINS: PackedFloat32Array = [10.0, 5.0, 10.0, 6.0]

var _frame: PanelContainer = null
## The content scrolls inside the frame when the zone is shorter than it (1280x720).
var _body: ScrollContainer = null
var _column: VBoxContainer = null
var _lines: Dictionary = {}
var _buttons: Dictionary = {}
var _tunnel_box: VBoxContainer = null
var _find_icons: Array[TextureRect] = []
var _find_counts: Array[Label] = []
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
	name = "TunnelPanel"
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	add_child(_frame)
	_body = ScrollContainer.new()
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 5)
	_body.add_child(column)
	_column = column
	column.add_child(_label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font()))
	for key: StringName in [&"weather", &"stores", &"housing", &"finds"]:
		_lines[key] = _label("", BODY_PX, Palette.INK, null)
		column.add_child(_lines[key])
	column.add_child(_build_finds_row())
	column.add_child(_button(ACTION_NEXT_WEATHER))
	_build_tunnel_box(column)
	_lines[&"log"] = _label("", SMALL_PX, Palette.UMBER, null)
	column.add_child(_lines[&"log"])
	column.add_child(_button(ACTION_EVENT))


func _build_finds_row() -> HFlowContainer:
	"""The finds shelf: FIND_SLOTS icons, each with a count beside it, all hidden until shown."""
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 4)
	for k: int in FIND_SLOTS:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2.ONE * FIND_ICON_PX
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.visible = false
		row.add_child(icon)
		_find_icons.append(icon)
		var count := _label("", SMALL_PX, Palette.UMBER, null)
		count.custom_minimum_size.x = 0.0
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.visible = false
		row.add_child(count)
		_find_counts.append(count)
	return row


func show_finds(icons: Array[Texture2D], counts: PackedInt32Array) -> void:
	"""The finds shelf: icon k with its count (a count below 1 shows no number); the rest hidden."""
	for k: int in FIND_SLOTS:
		var shown: bool = k < icons.size()
		_find_icons[k].visible = shown
		_find_counts[k].visible = shown and counts[k] > 0
		if shown:
			_find_icons[k].texture = icons[k]
			_find_counts[k].text = "×%d" % counts[k]
	_place.call_deferred()


func finds_shown() -> int:
	"""How many finds icons show (for checks)."""
	var count: int = 0
	for icon: TextureRect in _find_icons:
		count += 1 if icon.visible else 0
	return count


func _build_tunnel_box(column: VBoxContainer) -> void:
	"""The selected tunnel: its title, its state, and a grid of its jobs."""
	_tunnel_box = VBoxContainer.new()
	_tunnel_box.add_theme_constant_override(&"separation", 4)
	column.add_child(_tunnel_box)
	_lines[&"tunnel_title"] = _label("", BODY_PX + 2, Palette.INK, Styles.heading_font())
	_tunnel_box.add_child(_lines[&"tunnel_title"])
	_lines[&"tunnel"] = _label("", BODY_PX, Palette.UMBER, null)
	_tunnel_box.add_child(_lines[&"tunnel"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	_tunnel_box.add_child(grid)
	for key in TUNNEL_ACTIONS:
		grid.add_child(_button(key))


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
	button.add_theme_font_size_override(&"font_size", BODY_PX)
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
	"""The button for an action (for checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text: weather, stores, housing, finds, tunnel_title, tunnel or log."""
	return (_lines[key] as Label).text


func show_status(weather: String, stores: String, housing: String, finds: String, log: String) -> void:
	"""The panel's standing lines."""
	_set_line(&"weather", weather)
	_set_line(&"stores", stores)
	_set_line(&"housing", housing)
	_set_line(&"finds", finds)
	_set_line(&"log", log)


func show_tunnel(title: String, text: String, repair: String, enabled: Dictionary) -> void:
	"""The selected tunnel ("" title: none selected) -- its state, the repair button's words, and which
	actions are enabled ({action: bool}; empty: no actions shown)."""
	_set_line(&"tunnel_title", title if not title.is_empty() else NO_TUNNEL)
	_set_line(&"tunnel", text)
	(_lines[&"tunnel"] as Label).visible = not text.is_empty()
	(_buttons[ACTION_REPAIR] as Button).text = repair if not repair.is_empty() else BUTTON_TEXT[ACTION_REPAIR]
	for key in TUNNEL_ACTIONS:
		var b := _buttons[key] as Button
		b.visible = not enabled.is_empty()
		b.disabled = not bool(enabled.get(key, false))


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
	_find_detail()


func _find_detail() -> void:
	"""Look the journal up (the HUD may build it after the demo starts)."""
	if _hud_root != null and is_instance_valid(_hud_root):
		_detail = _hud_root.find_child(DETAIL_NAME, true, false) as Control


func follow_hud() -> void:
	"""Hide while the journal is open; show again once it closes. Cheap; call a few times a second."""
	if _detail == null:
		_find_detail()
	var open := _detail != null and is_instance_valid(_detail) and _detail.is_visible_in_tree()
	if open != _detail_open:
		_detail_open = open
		_place()


func set_zone(shown: bool, top_inset: float) -> void:
	"""The detail zone's owner (demo_detail_zone.gd): show this panel or not, starting `top_inset`
	logical pixels below the zone's top -- and fit it again once its content has laid out (a panel
	shown for the first time still carries a hidden-state height)."""
	_zone_shown = shown
	_zone_inset = top_inset
	_place()
	_place.call_deferred()


func _place() -> void:
	"""Lay the frame out in the detail zone at the HUD's scale (see PLACEMENT)."""
	if _frame == null:
		return
	if not is_inside_tree():
		_frame.visible = _zone_shown and not _detail_open
		return
	var size_px := get_viewport().get_visible_rect().size
	var rect := placement(int(size_px.x), int(size_px.y), _layout, _geometry, _zone_inset)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	_frame.size = Vector2(rect.size.x, 0.0)
	_body.custom_minimum_size.y = minf(_column.get_combined_minimum_size().y,
		maxf(rect.size.y - CONTENT_MARGINS[1] - CONTENT_MARGINS[3], 0.0))
	_frame.visible = _zone_shown and not _detail_open


static func placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry,
		top_inset: float = 0.0) -> Rect2:
	"""The panel's rectangle in the HUD's logical pixels: the detail zone below `top_inset` (the zone's
	tab strip), inset by the carved frame, above the command strip where they overlap -- the zone's
	own rule (demo_detail_zone.gd `panel_placement`). Fills `geometry`."""
	return DetailZone.panel_placement(width, height, FRAME_EXPAND, top_inset, layout, geometry)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func is_shown() -> bool:
	"""Whether the frame is drawn."""
	return _frame != null and _frame.visible
