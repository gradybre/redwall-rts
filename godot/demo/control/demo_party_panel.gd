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
## `dig_requested`, the same as T: pressed while a route is being laid, it cancels it); it never
## takes focus, so Enter while laying a route digs rather than pressing it again. A NOTICE line under the party carries the tunnel tool's prompts, lengths
## and refusals. The wood button's cream text and the notice's ink are checked for contrast
## (test_demo_tunnel.gd).
##
## ORDERS (decision 0205, the playtest of 2026-09-29). With one resident selected, the panel lists what
## it can be ordered to do (control/resident_abilities.gd, an entry's "abilities"): a line a kind of
## work, the skill-gated ones saying why not. The notice line is the SELECTED residents' own (the
## command layer keeps one per resident, demo_command.gd `say`). Where the column is too short for all
## of it (1280x720), the hint goes first and then the orders, before the panel itself would.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

signal dig_requested

const TITLE: String = "Demo party"
const HINT: String = "Click or drag: select · Shift: add · Right-click: move / work · R: release · Esc: clear · T: dig tunnel (mole) · U: underground"
const DIG_BUTTON: String = "Dig tunnel (T)"
## The Dig button's hover tip (decision 0205: every action button says what it does and its key).
const DIG_TIP: String = "Dig tunnel (T) — the selected mole lays out a tunnel: click points on the ground, Enter digs it, Esc cancels"
const DIGGING: String = "Digging tunnel — %d%%"
const IN_TUNNEL: String = "Using tunnel"
## The tunnel extensions' states (demo/tunnel/): hauling a load below, waiting in a mouth's line.
const HAULING: String = "Hauling through tunnel"
const IN_QUEUE: String = "Waiting at a tunnel mouth"
const BUTTON_MARGINS: PackedFloat32Array = [12.0, 6.0, 12.0, 7.0]
const NOBODY: String = "No one selected"
## fit's levels, fullest first (see fit).
const FIT_LEVELS: int = 4
## The unfinished jobs a resident will go back to (resident_brain.gd RESUMING), latest first.
const THEN: String = "Then back to: %s"
## The orders list folded for a short column (fit), e.g. at 1280x720.
const COMPACT: String = "Orders (right-click): %s"
const BULLET: String = "• "
## One resident's species line: folded with the skills (its name already says it, "Mole digger").
const SPECIES_ROW: int = 1
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
var _abilities: Label = null
var _abilities_wanted: bool = false
var _abilities_full: String = ""
var _abilities_compact: String = ""
var _skill_rows: Array[Control] = []
var _hint: Label = null
var _dig: Button = null
var _pending_notice: String = ""
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _hud_root: Control = null
var _ledger: Control = null
var _ledger_open: bool = false


func _ready() -> void:
	"""Build the frame, place it, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""Build the widgets and show what is waiting: nobody, and any notice given before this was built."""
	layer = 0
	name = "DemoPartyPanel"
	_build()
	show_party([])
	show_notice(_pending_notice)


func dig_button() -> Button:
	"""The "Dig tunnel" button (null before build)."""
	return _dig


func notice_label() -> Label:
	"""The notice line (null before build)."""
	return _notice


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
	_abilities = _label("", HINT_PX, Palette.UMBER, null)
	_abilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_abilities.visible = false
	column.add_child(_abilities)
	_notice = _label("", BODY_PX, Palette.INK, null)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	column.add_child(_notice)
	_dig = _build_dig_button()
	column.add_child(_dig)
	_hint = _label(HINT, HINT_PX, Palette.UMBER, null)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)


func _build_dig_button() -> Button:
	"""The wood "Dig tunnel" button: cream on wood, brass when pressed; never takes focus."""
	var button := Button.new()
	button.text = DIG_BUTTON
	button.tooltip_text = DIG_TIP
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
	"""Show these residents: [{"name", "species", "state", "colour", "skills", "then", "abilities"}]."""
	_fill_rows(entries)
	_dig.visible = has_digger(entries)
	var abilities: PackedStringArray = entries[0].get("abilities", PackedStringArray()) if entries.size() == 1 \
			else PackedStringArray()
	_abilities_full = "\n".join(abilities)
	_abilities_compact = compact_orders(abilities)
	_abilities.text = _abilities_full
	_abilities_wanted = not abilities.is_empty()
	_abilities.visible = _abilities_wanted
	_place.call_deferred()


func _fill_rows(entries: Array[Dictionary]) -> void:
	"""The party's lines, a chip on each resident's; one resident's skill lines and species line are kept
	apart (fit may fold them away first)."""
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_skill_rows.clear()
	var lines := party_lines(entries)
	var skills: int = String(entries[0].get("skills", "")).split("\n", false).size() if entries.size() == 1 else 0
	for i in lines.size():
		var chip: Color = Color(0, 0, 0, 0)
		if entries.size() == 1 and i == 0:
			chip = entries[0].get("colour", Palette.SAGE)
		elif entries.size() > 1 and i > 0 and i - 1 < entries.size():
			chip = entries[i - 1].get("colour", Palette.SAGE)
		var row: Control = _row(lines[i], chip, i == 0)
		_rows.add_child(row)
		if i >= lines.size() - skills or (skills > 0 and i == SPECIES_ROW):
			_skill_rows.append(row)


static func compact_orders(lines: PackedStringArray) -> String:
	"""The orders list folded into one wrapped paragraph for a short column: its lines after the heading,
	each without what to right-click, joined ("Orders (right-click): • Move or work · • Farm: sow, ...")."""
	if lines.size() <= 1:
		return ""
	var parts := PackedStringArray()
	for k: int in range(1, lines.size()):
		parts.append(lines[k].get_slice(" —", 0).trim_prefix(BULLET))
	return COMPACT % " · ".join(parts)


func abilities_text() -> String:
	"""The orders list as shown ("" when hidden: nobody, a group, or no room)."""
	return _abilities.text if _abilities != null and _abilities.visible else ""


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
	"""Lay the frame out in the HUD's logical space and draw it at the HUD's scale (in the tree only:
	built for a check out of it, there is no viewport to fit)."""
	if not is_inside_tree():
		return
	var size_px := get_viewport().get_visible_rect().size
	var rect := placement(int(size_px.x), int(size_px.y), _layout, _geometry)
	if _ledger_open:
		var below := _ledger.get_global_rect().end.y / _geometry.scale + LEDGER_GAP + FRAME_EXPAND
		rect = Rect2(rect.position.x, below, rect.size.x, rect.end.y - below)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	_frame.visible = fit(rect.size.y)
	_frame.size = Vector2(rect.size.x, 0.0)
	_shrink.call_deferred(rect.size.x)


func _shrink(width: float) -> void:
	"""Once the column has measured what `fit` left shown (a frame later), take the frame down to it."""
	if _frame != null:
		_frame.size = Vector2(width, 0.0)


func fit(height: float) -> bool:
	"""Make the frame fit `height` logical pixels, giving up the least useful first: everything; else no
	hint; else no skill lines either; else the orders folded into one paragraph; else no orders. False
	when even that is too tall (the panel then hides)."""
	for level: int in range(FIT_LEVELS - 1, -1, -1):
		_show_extras(level)
		if needed_height() <= height:
			return true
	_abilities.visible = false
	return needed_height() <= height


func _show_extras(level: int) -> void:
	"""What `fit` shows at `level` (see fit): 3 all, 2 no hint, 1 no skills, 0 folded orders."""
	_hint.visible = level >= 3
	for row: Control in _skill_rows:
		row.visible = level >= 2
	_abilities.visible = _abilities_wanted
	_abilities.text = _abilities_full if level >= 1 else _abilities_compact


func needed_height() -> float:
	"""The frame's height with what is shown now, summed from its column's visible children (the
	containers' cached minimum sizes follow a visibility change only a frame later)."""
	var box: StyleBox = _frame.get_theme_stylebox(&"panel")
	return stack_height(_hint.get_parent() as VBoxContainer) + (box.get_minimum_size().y if box != null else 0.0)


static func _own_height(control: Control) -> float:
	"""A control's height from its own measure now (a label re-shapes on a text change at once; its cached
	combined size may not have caught up)."""
	return maxf(control.get_minimum_size().y, control.custom_minimum_size.y)


static func stack_height(stack: VBoxContainer) -> float:
	"""A column's height from its visible children, each measured by itself now, and its separation
	between them."""
	var total: float = 0.0
	var shown: int = 0
	for child: Node in stack.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		total += _own_height(control)
		shown += 1
	return total + float(stack.get_theme_constant(&"separation") * maxi(shown - 1, 0))


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
	"""The panel's body lines: nobody; one resident's name, species, state and -- when it has any
	(an entry's "skills", demo/forestry/ and demo/waterplay/) -- its skills, a line for each line of them; or a count and a line per resident, its short
	skills after its state (at most MAX_ROWS, then "+ n more")."""
	var lines := PackedStringArray()
	if entries.is_empty():
		lines.append(NOBODY)
	elif entries.size() == 1:
		lines.append(String(entries[0]["name"]))
		lines.append(String(entries[0]["species"]))
		lines.append(String(entries[0]["state"]))
		var then: PackedStringArray = entries[0].get("then", PackedStringArray())
		if not then.is_empty():
			lines.append(THEN % ", ".join(then))
		for skill: String in String(entries[0].get("skills", "")).split("\n", false):
			lines.append(skill)
	else:
		lines.append("%d residents" % entries.size())
		for i in mini(entries.size(), MAX_ROWS):
			var skills: String = String(entries[i].get("skills", ""))
			lines.append("%s — %s%s" % [entries[i]["name"], entries[i]["state"], "" if skills.is_empty() else " · " + skills])
		if entries.size() > MAX_ROWS:
			lines.append("+ %d more" % (entries.size() - MAX_ROWS))
	return lines


static func state_text(activity: int, clip: StringName, place: String, dug_percent: int = 0) -> String:
	"""What a resident is doing, in words: wandering / walking to X / working: collect / holding /
	Digging tunnel — 43% (with `dug_percent`) / Using tunnel / Hauling through tunnel / Waiting at a
	tunnel mouth / a task's own words (`place`)."""
	if activity == BrainScript.ACTIVITY_DIGGING:
		return DIGGING % dug_percent
	if activity == BrainScript.ACTIVITY_TASK:
		return place
	if activity == BrainScript.ACTIVITY_QUEUE:
		return IN_QUEUE
	if activity == BrainScript.ACTIVITY_TUNNEL:
		return HAULING if clip == BrainScript.CLIP_CARRY else IN_TUNNEL
	if activity == BrainScript.ACTIVITY_CROSSING:
		return "crossing the water"
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
