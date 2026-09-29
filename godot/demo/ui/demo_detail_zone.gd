extends CanvasLayer
## Who holds the HUD's right column: ONE demo panel at a time. Decision 0196 (live demo). DEMO UI.
##
## Two demo panels want UI §1.2's DETAIL ZONE (the right column below the time controls): the farm's
## bed panel (demo/farm/farm_bed_panel.gd) and the "Tunnels & burrows (demo)" panel
## (demo/tunnel/tunnel_panel.gd). Drawn together they overlapped. So this owns the zone:
##   * a TAB STRIP along its top -- "Farm" and "Tunnels & burrows", the shown one in brass -- that
##     switches by click;
##   * below it, exactly one panel, placed by the panel itself in the zone minus the strip
##     (`set_zone(shown, top_inset)`), so each keeps its own layout and scale;
##   * SWITCHING ON INTENT: clicking a crop bed brings the farm panel, and selecting a tunnel, laying
##     a route or placing a chamber brings the tunnels panel (demo_village.gd connects the two panels'
##     owners to `show_panel`);
##   * the zone belongs to UI-SET-036, the resident journal, when it opens: then the strip and both
##     panels hide, and come back as they were when it closes.
## Geometry is the HUD's own (`scripts/ui/ui_layout.gd`, read, never modified) in LOGICAL pixels, drawn
## at the HUD's scale and recomputed on every resize, so 1280x720 and 1920x1080 line up. It draws on
## the demo panels' layer, below the HUD's, so a true modal covers it. No tab takes focus.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const PANEL_FARM: int = 0
const PANEL_TUNNELS: int = 1
const TAB_TEXT: Array[String] = ["Farm", "Tunnels & burrows"]
const TAB_TIPS: Array[String] = ["The farm: the calendar, a clicked bed and its work",
	"Tunnels & burrows (demo): the weather, the demo stores, a clicked tunnel and its jobs"]
## The strip's height, and the gap under it, in logical pixels (the panels start below both).
const STRIP_H: float = 34.0
const STRIP_GAP: float = 8.0
const TAB_PX: int = 14
const TAB_MARGINS: PackedFloat32Array = [10.0, 4.0, 10.0, 5.0]
## The HUD surface the zone yields to.
const DETAIL_NAME: String = "UI-SET-036"

## The panel shown (PANEL_*).
var shown: int = PANEL_FARM

var _panels: Array[Object] = [null, null]
var _tabs: Array[Button] = []
var _strip: HBoxContainer = null
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _journal: Control = null
var _journal_open: bool = false


func _ready() -> void:
	"""Build, place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The tab strip (also out of the tree, for checks)."""
	if _strip != null:
		return
	layer = 0
	name = "DemoDetailZone"
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override(&"separation", 6)
	add_child(_strip)
	for k: int in TAB_TEXT.size():
		_tabs.append(_tab(k))
		_strip.add_child(_tabs[k])
	_paint_tabs()


func _tab(k: int) -> Button:
	"""One wood tab: brass while its panel is shown; never takes focus."""
	var tab := Button.new()
	tab.text = TAB_TEXT[k]
	tab.tooltip_text = TAB_TIPS[k]
	tab.focus_mode = Control.FOCUS_NONE
	tab.toggle_mode = true
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_font_size_override(&"font_size", TAB_PX)
	tab.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, TAB_MARGINS))
	tab.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, TAB_MARGINS))
	tab.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, TAB_MARGINS))
	tab.add_theme_stylebox_override(&"hover_pressed", Styles.box(Styles.PIECE_BRASS, TAB_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		tab.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	for item: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
		tab.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_BRASS))
	tab.pressed.connect(func() -> void: show_panel(k))
	return tab


func add_panel(key: int, panel: Object) -> void:
	"""Hand the zone a panel (PANEL_*): anything with `set_zone(shown: bool, top_inset: float)`."""
	_panels[key] = panel
	_apply()


func show_panel(key: int) -> void:
	"""Show panel `key` in the zone (the other hides)."""
	if key < PANEL_FARM or key > PANEL_TUNNELS:
		return
	shown = key
	_apply()


func tab(key: int) -> Button:
	"""A tab (checks and the scripted run)."""
	return _tabs[key]


func top_inset() -> float:
	"""How far below the zone's top the panels start, logical pixels."""
	return STRIP_H + STRIP_GAP


func watch_hud(hud_root: Control) -> void:
	"""Yield the zone to the HUD's resident journal (found by its UI id under `hud_root`)."""
	_hud_root = hud_root


func _process(_delta: float) -> void:
	"""Hide the zone while the journal is open (a pointer and a visibility read per frame)."""
	if _journal == null and _hud_root != null and is_instance_valid(_hud_root):
		_journal = _hud_root.find_child(DETAIL_NAME, true, false) as Control
	var open: bool = _journal != null and is_instance_valid(_journal) and _journal.is_visible_in_tree()
	if open != _journal_open:
		_journal_open = open
		_apply()


func journal_open() -> bool:
	"""Whether the zone is yielded to the resident journal."""
	return _journal_open


func _apply() -> void:
	"""Show exactly one panel (none while the journal is open), and paint the tabs."""
	for key: int in _panels.size():
		if _panels[key] != null:
			_panels[key].call(&"set_zone", key == shown and not _journal_open, top_inset())
	_paint_tabs()
	if _strip != null:
		_strip.visible = not _journal_open


func _paint_tabs() -> void:
	"""The shown panel's tab in brass."""
	for k: int in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == shown)


func _place() -> void:
	"""The strip along the detail zone's top, at the HUD's scale."""
	if not is_inside_tree() or _strip == null:
		return
	var size_px: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = strip_placement(int(size_px.x), int(size_px.y), _layout, _geometry)
	_strip.scale = Vector2(_geometry.scale, _geometry.scale)
	_strip.position = rect.position * _geometry.scale
	_strip.custom_minimum_size = rect.size
	_strip.size = rect.size


static func strip_placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The strip's rectangle in the HUD's logical pixels: the detail zone's top STRIP_H. Fills `geometry`
	(scale 1 below the supported floor)."""
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			UiLayout.USER_SCALE_100, false, geometry):
		geometry.scale = 1.0
	return Rect2(geometry.detail.position, Vector2(geometry.detail.size.x, STRIP_H))


func strip_rect() -> Rect2:
	"""Where the strip is drawn, in viewport pixels (checks)."""
	return Rect2(_strip.position, _strip.size * _strip.scale)
