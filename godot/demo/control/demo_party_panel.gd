extends CanvasLayer
## The demo party panel: who is selected and what they are doing. Decision 0196. DEMO UI -- it is
## not the game's selection panel (UI §3 owns that, unbuilt) and it is titled "Demo party" so.
##
## ---------------------------------------------------------------------------------------
## PLACEMENT. It sits in the HUD's LEFT COLUMN: x at the safe inset, from `management_top` (below
## the resource cluster and the reserved band) down to just above the minimap. UI §1.2's permanent
## zones leave that column empty at every supported profile: alerts and the workspace are centred,
## time and detail are on the right, the command strip starts right of the minimap. ONE transient
## HUD surface opens there -- UI-SET-009, the resource ledger, dropped under the resources when a
## readout is clicked -- so while it is open the panel moves below it, or hides when there is no
## room (1280x720). The rectangle comes from the HUD's own equations (`scripts/ui/ui_layout.gd`,
## read, never modified) in LOGICAL pixels, and the panel draws at the HUD's effective scale S,
## recomputed on every viewport resize -- so 1280x720, 1920x1080 and a HiDPI full screen line up.
## It draws on a canvas layer BELOW the HUD's, so a true modal (which can span this column at
## 1280x720) always covers it.
##
## STYLE. The woodland skin's own pieces (demo/ui/): carved-wood panel with parchment face, Noto
## Serif title, ink and umber text -- both >= 4.5:1 on the parchment (test_demo_command.gd checks).
## The panel stops the mouse, so a click on it never selects or orders anything in the world.
##
## TUNNELS (demo/tunnel/). With a mole in the party a "Dig tunnel" button shows (emits
## `dig_requested`, the same as T); it never takes focus, so Enter while laying a route digs rather
## than pressing it again. A NOTICE line under the party carries the tunnel tool's prompts, lengths
## and refusals. The wood button's cream text and the notice's ink are checked for contrast
## (test_demo_tunnel.gd).

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

signal dig_requested

const TITLE: String = "Demo party"
const HINT: String = "Click or drag: select · Shift: add · Right-click: move / work · R: release · Esc: clear · T: dig tunnel (mole) · U: underground"
const DIG_BUTTON: String = "Dig tunnel (T)"
const DIGGING: String = "Digging tunnel — %d%%"
const IN_TUNNEL: String = "Using tunnel"
const BUTTON_MARGINS: PackedFloat32Array = [12.0, 6.0, 12.0, 7.0]
const NOBODY: String = "No one selected"
const WIDTH: float = 320.0
## The carved frame draws this far outside the panel rectangle (woodland_styles PIECE_PANEL).
const FRAME_EXPAND: float = 10.0
const MINIMAP_GAP: float = 8.0
const MAX_ROWS: int = 6
const TITLE_PX: int = 20
const BODY_PX: int = 15
const HINT_PX: int = 13
const CHIP_PX: float = 12.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
## The HUD surface this panel yields to (see PLACEMENT).
const LEDGER_NAME: String = "UI-SET-009"
const LEDGER_GAP: float = 8.0

var _frame: PanelContainer = null
var _rows: VBoxContainer = null
var _notice: Label = null
var _dig: Button = null
var _pending_notice: String = ""
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _ledger: Control = null
var _ledger_open: bool = false


func _ready() -> void:
	"""Build the frame, place it, and follow the viewport's size."""
	layer = 0
	name = "DemoPartyPanel"
	_build()
	show_party([])
	show_notice(_pending_notice)
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Frame, title, rows and hint."""
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font()))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 3)
	column.add_child(_rows)
	_notice = _label("", BODY_PX, Palette.INK, null)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	column.add_child(_notice)
	_dig = _build_dig_button()
	column.add_child(_dig)
	var hint := _label(HINT, HINT_PX, Palette.UMBER, null)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)


func _build_dig_button() -> Button:
	"""The wood "Dig tunnel" button: cream on wood, brass when pressed; never takes focus."""
	var button := Button.new()
	button.text = DIG_BUTTON
	button.focus_mode = Control.FOCUS_NONE
	button.visible = false
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override(&"font_size", BODY_PX)
	button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	button.pressed.connect(func() -> void: dig_requested.emit())
	return button


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = WIDTH - CONTENT_MARGINS[0] - CONTENT_MARGINS[2]
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func show_party(entries: Array[Dictionary]) -> void:
	"""Show these residents: [{"name", "species", "state", "colour"}]."""
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var lines := party_lines(entries)
	var colours: Array[Color] = []
	for entry in entries:
		colours.append(entry.get("colour", Palette.SAGE))
	for i in lines.size():
		var chip: Color = Color(0, 0, 0, 0)
		if entries.size() == 1 and i == 0:
			chip = colours[0]
		elif entries.size() > 1 and i > 0 and i - 1 < colours.size():
			chip = colours[i - 1]
		_rows.add_child(_row(lines[i], chip, i == 0))
	_dig.visible = has_digger(entries)
	_place.call_deferred()


static func has_digger(entries: Array[Dictionary]) -> bool:
	"""Whether any of these residents digs tunnels (an entry's "digger")."""
	for entry in entries:
		if bool(entry.get("digger", false)):
			return true
	return false


func show_notice(text: String) -> void:
	"""One line under the party for the tunnel tool: a prompt, a length or a refusal ("" hides it).
	Before the panel is built (out of the tree) the text waits for it."""
	_pending_notice = text
	if _notice == null:
		return
	_notice.text = text
	_notice.visible = not text.is_empty()
	_place.call_deferred()


func notice() -> String:
	"""The notice line's text ("" when hidden)."""
	return _pending_notice


func _row(text: String, chip: Color, lead: bool) -> Control:
	"""A chip (when coloured) and a line of text."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if chip.a > 0.0:
		var swatch := ColorRect.new()
		swatch.color = chip
		swatch.custom_minimum_size = Vector2(CHIP_PX, CHIP_PX)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	var label := _label(text, BODY_PX, Palette.INK if lead else Palette.UMBER, null)
	label.custom_minimum_size.x = 0.0
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func watch_hud(hud_root: Control) -> void:
	"""Yield to the HUD's resource ledger (found by its UI id under `hud_root`), if it has one."""
	_hud_root = hud_root
	_find_ledger()


func _find_ledger() -> void:
	"""Look the ledger up (the HUD may build it after the demo starts)."""
	if _hud_root != null and is_instance_valid(_hud_root):
		_ledger = _hud_root.find_child(LEDGER_NAME, true, false) as Control


func follow_hud() -> void:
	"""Re-place the panel when the ledger opens or closes. Cheap; call a few times a second."""
	if _ledger == null:
		_find_ledger()
	var open := _ledger != null and is_instance_valid(_ledger) and _ledger.is_visible_in_tree()
	if open != _ledger_open:
		_ledger_open = open
		_place()


func _place() -> void:
	"""Lay the frame out in the HUD's logical space and draw it at the HUD's scale."""
	var size_px := get_viewport().get_visible_rect().size
	var rect := placement(int(size_px.x), int(size_px.y), _layout, _geometry)
	if _ledger_open:
		var below := _ledger.get_global_rect().end.y / _geometry.scale + LEDGER_GAP + FRAME_EXPAND
		rect = Rect2(rect.position.x, below, rect.size.x, rect.end.y - below)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	_frame.size = Vector2(rect.size.x, 0.0)
	_frame.visible = _frame.get_combined_minimum_size().y <= rect.size.y


static func placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The panel's rectangle in the HUD's logical pixels: the left column between the reserved band
	and the minimap, inset by the carved frame. Fills `geometry` (scale 1 when the viewport is
	below the supported floor and the HUD refuses to lay out)."""
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			UiLayout.USER_SCALE_100, false, geometry):
		geometry.scale = 1.0
	var top := geometry.management_top + FRAME_EXPAND
	var bottom := geometry.minimap.position.y - MINIMAP_GAP - FRAME_EXPAND
	return Rect2(UiLayout.SAFE_INSET + FRAME_EXPAND, top, WIDTH, maxf(bottom - top, 0.0))


static func party_lines(entries: Array[Dictionary]) -> PackedStringArray:
	"""The panel's body lines: nobody; one resident's name, species and state; or a count and a
	line per resident (at most MAX_ROWS, then "+ n more")."""
	var lines := PackedStringArray()
	if entries.is_empty():
		lines.append(NOBODY)
	elif entries.size() == 1:
		lines.append(String(entries[0]["name"]))
		lines.append(String(entries[0]["species"]))
		lines.append(String(entries[0]["state"]))
	else:
		lines.append("%d residents" % entries.size())
		for i in mini(entries.size(), MAX_ROWS):
			lines.append("%s — %s" % [entries[i]["name"], entries[i]["state"]])
		if entries.size() > MAX_ROWS:
			lines.append("+ %d more" % (entries.size() - MAX_ROWS))
	return lines


static func state_text(activity: int, clip: StringName, place: String, dug_percent: int = 0) -> String:
	"""What a resident is doing, in words: wandering / walking to X / working: collect / holding /
	Digging tunnel — 43% (with `dug_percent`) / Using tunnel."""
	if activity == BrainScript.ACTIVITY_DIGGING:
		return DIGGING % dug_percent
	if activity == BrainScript.ACTIVITY_TUNNEL:
		return IN_TUNNEL
	if activity == BrainScript.ACTIVITY_HOLDING:
		return "holding"
	if activity == BrainScript.ACTIVITY_WALKING:
		return "walking to " + (place if place != "" else "marker")
	if activity == BrainScript.ACTIVITY_WORKING:
		if clip == BrainScript.CLIP_IDLE or clip == BrainScript.CLIP_WALK:
			return "working at " + place
		return "working: " + String(clip).replace("_", " ")
	return "wandering"


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
