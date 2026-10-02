extends VBoxContainer
## THE GROUP PANEL (decision 0791): with two or more residents selected, their combined status and the group's actions, as
## a section of the Demo party panel's inspector (demo_party_panel.gd `add_section`, right after the notice line). DEMO UI;
## it draws what group_select.gd hands it (`show_group`) and emits what is pressed -- it reads no resident itself.
##
##   Doing: Holding ×3 · Walking to the well ×2      the party panel's own activity words, tallied, whole (never cut)
##   Needs attention:                                 the WARNING rows the members hold (group_status.gd), a line each:
##   Hungry ×1 — Tobit                                "word ×n — first names"; "Needs attention: none" when none
##   No bed ×2 — Hulda, Elstan                        then the NOTE rows, in umber
##   Idle ×2 — Wenna, Jory                            who is idle (the Work screen's "available"), or "Idle: nobody"
##   [tile][tile][tile]                               a TILE per member: its colour, first name, and its first warning --
##                                                    else its activity's first word; click: centre the view on it (the
##                                                    group stays selected); Shift+click: drop it from the selection
##   Crews: Field ×2 · Haulers ×1 — put them all on:
##   [Field][Woods][Diggers][Haulers][Builders]       one press moves every member (a crew all are on already: disabled)
##   [Send to…]                                       then a left click on the world orders the group there (Esc cancels)
##   Kept as group 3 · Ctrl+0–9 keeps …              the control groups, and their keys
##
## Its TOP ROW (`top_row`, under the party panel's actions, always in view) holds "Select idle (n)", shown with any
## selection or none. Each tile is the resident's colour -- the same as its party-panel chip and minimap dot.
##
## PORTRAITS (art pass 2, decision 0951; docs/art-reference/art_pass2_mapping.md "Resident portraits"). When the props
## table stages any portrait (`set_portraits`: the shared props table and how a cast index maps to its cast key), the
## tiles run PORTRAIT_COLUMNS across, so the name and tag keep their room beside a medallion (three 88 px tiles would
## leave them ~30 px), and each tile whose resident has a portrait draws its 48 px medallion at PORTRAIT_DRAW px beside
## the colour bar; a tile whose resident has none keeps its words at the margin. A portrait is its own slot: the species
## emblems stay species marks (ART-UI-06). With no portrait staged at all (CI, a fresh clone) the tiles are exactly as
## before: three across, no portrait.
## Text is at least 14 px and every button at least 32 px tall (UI §2.1, UX-T03); every button takes keyboard focus
## (decision 0261), so F7 and Tab reach them in the party panel's region. Pools are re-worded in place, never rebuilt, so a
## focus or a tooltip survives a refresh.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## A tile was pressed: centre on resident `actor_index` (`shift`: drop it from the selection instead).
signal tile_pressed(actor_index: int, shift: bool)
## A crew button was pressed: every member onto `crew` (work_crews.gd CREW_*).
signal crew_pressed(crew: int)
## "Send to…" was pressed (arm or disarm the next world click as the group's destination).
signal send_pressed
## "Select idle" was pressed.
signal idle_pressed

const BODY_PX: int = 15
const SMALL_PX: int = 14
const TILE_COLUMNS: int = 3
const TILE_H: float = 46.0
const TILE_GAP: int = 6
const CHIP_W: float = 6.0
const TILE_MARGINS: PackedFloat32Array = [12.0, 3.0, 4.0, 3.0]
const HOVER_ALPHA: float = 0.10
const PRESSED_ALPHA: float = 0.18
const WARN_BORDER: int = 2
## The portrait medallion's staged size, its drawn size in a tile, and the tiles across while portraits show.
const PORTRAIT_PX: int = 48
const PORTRAIT_DRAW: float = 40.0
const PORTRAIT_COLUMNS: int = 2
## The portrait's left edge in a tile: just right of the colour bar.
const PORTRAIT_X: float = 2.0 + CHIP_W + 2.0
const ATTENTION: String = "Needs attention:"
const SEND: String = "Send to…"
const SEND_TIP: String = "Send to… — then left-click a spot: the selected residents go there (a work spot: they work it), as a right-click would. Esc cancels"
const IDLE_BUTTON: String = "Select idle (%d)"
const IDLE_TIP: String = "Select idle — select every resident with nothing to do (the Work screen's \"available\"): %s"
const IDLE_NONE: String = "Nobody is idle: everyone is working, resting or in the water"

## What the panel shows for a group (group_select.gd builds it).
class GroupView extends RefCounted:
	## Whether the section shows (two or more selected).
	var shown: bool = false
	var doing: String = ""
	## Warning lines, then note lines ("Hungry ×1 — Tobit"), and the idle line.
	var attention: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	var idle_line: String = ""
	## One per tile: its cast index, colour, first name, tag, tooltip and whether it carries a warning.
	var index: PackedInt32Array = PackedInt32Array()
	var colour: PackedColorArray = PackedColorArray()
	var first_name: PackedStringArray = PackedStringArray()
	var tag: PackedStringArray = PackedStringArray()
	var tip: PackedStringArray = PackedStringArray()
	var warn: PackedByteArray = PackedByteArray()
	var crew_line: String = ""
	## Per crew: its button's tooltip, and "" when it may be pressed, else why not.
	var crew_tip: PackedStringArray = PackedStringArray()
	var crew_why: PackedStringArray = PackedStringArray()
	var group_line: String = ""

var _width: float = 0.0
var _top: HFlowContainer = null
var _idle_button: Button = null
var _doing: Label = null
var _lines: VBoxContainer = null
var _line_labels: Array[Label] = []
var _tiles: GridContainer = null
var _tile_buttons: Array[Button] = []
var _tile_index: PackedInt32Array = PackedInt32Array()
var _tile_shift: PackedByteArray = PackedByteArray()
var _crew_line: Label = null
var _crew_buttons: Array[Button] = []
var _send: Button = null
var _group_line: Label = null
## The tiles' faces, made once: plain and warned, each at rest, hovered and pressed.
var _faces: Array[StyleBoxFlat] = []
## The portraits' source (null: none) and `key_of(actor_index) -> StringName` (its cast key); per tile, the resident
## whose portrait it holds (-1: not looked up yet), so a refresh looks a portrait up only when its tile's resident changes.
var _props: PropsScript = null
var _key_of: Callable = Callable()
var _tile_portrait_of: PackedInt32Array = PackedInt32Array()


func build(width: float) -> void:
	"""Build the section (hidden) and its top row, `width` logical px wide."""
	if _doing != null:
		return
	name = "GroupPanel"
	_width = width
	visible = false
	for warned: bool in [false, true]:
		for alpha: float in [0.0, HOVER_ALPHA, PRESSED_ALPHA]:
			_faces.append(_tile_style(alpha, warned))
	add_theme_constant_override(&"separation", 4)
	_doing = _line(BODY_PX, Palette.INK)
	add_child(_doing)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 2)
	add_child(_lines)
	_tiles = GridContainer.new()
	_tiles.name = "Tiles"
	_tiles.columns = columns()
	_tiles.add_theme_constant_override(&"h_separation", TILE_GAP)
	_tiles.add_theme_constant_override(&"v_separation", TILE_GAP)
	add_child(_tiles)
	_build_actions()
	_build_top()


func _build_actions() -> void:
	"""The crew line and buttons, Send to… and the control groups' line."""
	_crew_line = _line(SMALL_PX, Palette.UMBER)
	add_child(_crew_line)
	var crews := HFlowContainer.new()
	crews.name = "Crews"
	crews.add_theme_constant_override(&"h_separation", TILE_GAP)
	crews.add_theme_constant_override(&"v_separation", TILE_GAP)
	for crew: int in CrewsScript.CREW_COUNT:
		var button: Button = FarmUi.button(CrewsScript.CREW_NAMES[crew], SMALL_PX)
		button.pressed.connect(func() -> void: crew_pressed.emit(crew))
		_crew_buttons.append(button)
		crews.add_child(button)
	add_child(crews)
	_send = FarmUi.button(SEND, SMALL_PX)
	_send.toggle_mode = true
	_send.tooltip_text = SEND_TIP
	_send.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_send.pressed.connect(func() -> void: send_pressed.emit())
	add_child(_send)
	_group_line = _line(SMALL_PX, Palette.UMBER)
	add_child(_group_line)


func _build_top() -> void:
	"""The top row: Select idle."""
	_top = HFlowContainer.new()
	_top.name = "GroupTop"
	_idle_button = FarmUi.button(IDLE_BUTTON % 0, SMALL_PX)
	_idle_button.pressed.connect(func() -> void: idle_pressed.emit())
	_top.add_child(_idle_button)


func _line(px: int, colour: Color) -> Label:
	"""A wrapped line at the section's width."""
	var label: Label = FarmUi.label("", px, colour)
	label.custom_minimum_size.x = _width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func set_portraits(props: PropsScript, key_of: Callable) -> void:
	"""Draw the residents' portraits from `props` (null: none), `key_of(actor_index)` giving a resident's cast key. With
	any portrait staged the tiles run PORTRAIT_COLUMNS across; the tiles already made are re-laid, and those shown are
	looked up again at once."""
	_props = props
	_key_of = key_of
	var across: int = columns()
	var wide: float = tile_width(_width, across)
	if _tiles != null:
		_tiles.columns = across
	for k: int in _tile_buttons.size():
		_tile_buttons[k].custom_minimum_size.x = wide
		_tile_portrait_of[k] = -1
		if k < _tile_index.size():
			_fit_portrait(k, _tile_index[k])


func has_portraits() -> bool:
	"""Whether portraits are staged (the props table names any): then the tiles carry them."""
	if _props == null or not _key_of.is_valid():
		return false
	var portraits: Variant = _props.ui_row("portraits")
	return portraits is Dictionary and not (portraits as Dictionary).is_empty()


func columns() -> int:
	"""Tiles across: PORTRAIT_COLUMNS while portraits are staged, else TILE_COLUMNS."""
	return PORTRAIT_COLUMNS if has_portraits() else TILE_COLUMNS


func top_row() -> HFlowContainer:
	"""The row the party panel keeps under its actions (null before build)."""
	return _top


func idle_button() -> Button:
	"""The "Select idle" button (null before build)."""
	return _idle_button


func send_button() -> Button:
	"""The "Send to…" button (null before build)."""
	return _send


func crew_button(crew: int) -> Button:
	"""Crew `crew`'s button (null for none)."""
	return _crew_buttons[crew] if crew >= 0 and crew < _crew_buttons.size() else null


func show_idle(count: int, names: String) -> void:
	"""The top row's button: "Select idle (n)", disabled with why when nobody is idle."""
	var text: String = IDLE_BUTTON % count
	if _idle_button.text != text:
		_idle_button.text = text
	FarmUi.set_card(_idle_button, count > 0, IDLE_TIP % names if count > 0 else IDLE_NONE)


func set_armed(on: bool) -> void:
	"""Show "Send to…" pressed while the next world click is the group's destination."""
	if _send.button_pressed != on:
		_send.set_pressed_no_signal(on)


func show_group(view: GroupView) -> void:
	"""Show `view` (see the header); hidden when it is not `shown`."""
	visible = view.shown
	if not view.shown:
		return
	_set_text(_doing, view.doing)
	_fill_lines(view)
	_fill_tiles(view)
	_set_text(_crew_line, view.crew_line)
	for crew: int in _crew_buttons.size():
		var why: String = view.crew_why[crew] if crew < view.crew_why.size() else ""
		var tip: String = view.crew_tip[crew] if crew < view.crew_tip.size() else ""
		FarmUi.set_card(_crew_buttons[crew], why.is_empty(), tip if why.is_empty() else why)
	_set_text(_group_line, view.group_line)


func _fill_lines(view: GroupView) -> void:
	"""The status lines: "Needs attention:" and its warnings (or that there are none), the notes, the idle line."""
	var texts := PackedStringArray()
	texts.append(ATTENTION + (" none" if view.attention.is_empty() else ""))
	texts.append_array(view.attention)
	texts.append_array(view.notes)
	texts.append(view.idle_line)
	var warn_end: int = 1 + view.attention.size()
	for k: int in texts.size():
		var label: Label = _line_at(k)
		_set_text(label, texts[k])
		var colour: Color = Palette.INK if k < warn_end else Palette.UMBER
		var px: int = BODY_PX if k > 0 and k < warn_end else SMALL_PX
		if label.get_theme_color(&"font_color") != colour:
			label.add_theme_color_override(&"font_color", colour)
		if label.get_theme_font_size(&"font_size") != px:
			label.add_theme_font_size_override(&"font_size", px)
	for k: int in _line_labels.size():
		_line_labels[k].visible = k < texts.size()


func _line_at(k: int) -> Label:
	"""Status line `k` from the pool."""
	while _line_labels.size() <= k:
		var label: Label = _line(SMALL_PX, Palette.UMBER)
		_line_labels.append(label)
		_lines.add_child(label)
	return _line_labels[k]


func _fill_tiles(view: GroupView) -> void:
	"""A tile per member, re-worded in place; the tiles not wanted hidden."""
	_tile_index = view.index.duplicate()
	for k: int in view.index.size():
		var shown: Button = _tile_at(k)
		_set_text(shown.get_node(^"Lines/Name") as Label, view.first_name[k])
		_set_text(shown.get_node(^"Lines/Tag") as Label, view.tag[k])
		(shown.get_node(^"Chip") as ColorRect).color = view.colour[k]
		_fit_portrait(k, view.index[k])
		if shown.tooltip_text != view.tip[k]:
			shown.tooltip_text = view.tip[k]
		_dress_tile(shown, view.warn[k] == 1)
	for k: int in _tile_buttons.size():
		_tile_buttons[k].visible = k < view.index.size()


func _tile_at(k: int) -> Button:
	"""Tile `k` from the pool (made, and connected once, when missing)."""
	while _tile_buttons.size() <= k:
		var made: Button = _make_tile(_tile_buttons.size())
		_tile_buttons.append(made)
		_tile_shift.append(0)
		_tile_portrait_of.append(-1)
		_tiles.add_child(made)
	return _tile_buttons[k]


func _make_tile(k: int) -> Button:
	"""One tile: a flat button with the resident's colour bar, its first name and its tag."""
	var made := Button.new()
	made.name = "Tile%d" % k
	made.custom_minimum_size = Vector2(tile_width(_width, columns()), TILE_H)
	made.clip_contents = true
	Styles.focusable(made, TILE_MARGINS)
	_dress_tile(made, false)
	made.add_child(_tile_chip())
	made.add_child(_tile_portrait())
	made.add_child(_tile_lines())
	made.gui_input.connect(_on_tile_input.bind(k))
	made.mouse_exited.connect(func() -> void: _tile_shift[k] = 0)
	made.pressed.connect(_on_tile_pressed.bind(k))
	return made


func _tile_chip() -> ColorRect:
	"""A tile's colour bar down its left edge."""
	var chip := ColorRect.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.anchor_bottom = 1.0
	chip.offset_left = 2.0
	chip.offset_top = 4.0
	chip.offset_right = 2.0 + CHIP_W
	chip.offset_bottom = -4.0
	return chip


func _tile_portrait() -> TextureRect:
	"""A tile's portrait slot beside its colour bar: PORTRAIT_DRAW px square, centred down the tile, hidden while empty."""
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.position = Vector2(PORTRAIT_X, (TILE_H - PORTRAIT_DRAW) * 0.5)
	portrait.size = Vector2(PORTRAIT_DRAW, PORTRAIT_DRAW)
	portrait.visible = false
	return portrait


func _fit_portrait(k: int, who: int) -> void:
	"""Tile `k` shows resident `who`: its portrait, and its lines past it -- looked up only when the resident changed."""
	if _tile_portrait_of[k] == who:
		return
	_tile_portrait_of[k] = who
	var tile_k: Button = _tile_buttons[k]
	var portrait := tile_k.get_node(^"Portrait") as TextureRect
	portrait.texture = portrait_of(who)
	portrait.visible = portrait.texture != null
	var lines := tile_k.get_node(^"Lines") as Control
	lines.offset_left = PORTRAIT_X + PORTRAIT_DRAW + 4.0 if portrait.visible else TILE_MARGINS[0]


func portrait_of(who: int) -> Texture2D:
	"""Resident `who`'s staged PORTRAIT_PX medallion, or null (none staged, or no cast key)."""
	if not has_portraits():
		return null
	var key: StringName = _key_of.call(who)
	return _props.portrait(key, PORTRAIT_PX) if key != &"" else null


func _tile_lines() -> VBoxContainer:
	"""A tile's name and tag, inside its margins, cut with an ellipsis where too long."""
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = TILE_MARGINS[0]
	lines.offset_top = TILE_MARGINS[1]
	lines.offset_right = -TILE_MARGINS[2]
	lines.offset_bottom = -TILE_MARGINS[3]
	lines.add_theme_constant_override(&"separation", 0)
	for part: Array in [["Name", Palette.INK], ["Tag", Palette.UMBER]]:
		var label: Label = FarmUi.label("", SMALL_PX, part[1] as Color)
		label.name = String(part[0])
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lines.add_child(label)
	return lines


func _dress_tile(face_of: Button, warned: bool) -> void:
	"""Give a tile its faces: with a clay edge when its resident carries a warning (set only when it changed)."""
	var at: int = 3 if warned else 0
	if face_of.get_theme_stylebox(&"normal") == _faces[at]:
		return
	face_of.add_theme_stylebox_override(&"normal", _faces[at])
	face_of.add_theme_stylebox_override(&"hover", _faces[at + 1])
	face_of.add_theme_stylebox_override(&"pressed", _faces[at + 2])
	face_of.add_theme_stylebox_override(&"hover_pressed", _faces[at + 2])


static func _tile_style(alpha: float, warned: bool) -> StyleBoxFlat:
	"""A tile's face: an umber wash at `alpha`, a clay edge when the resident carries a warning, a faint one else."""
	var style: StyleBoxFlat = Styles.wash(alpha, TILE_MARGINS)
	style.set_border_width_all(WARN_BORDER if warned else 1)
	style.border_color = Palette.CLAY if warned else Color(Palette.UMBER, 0.35)
	return style


static func tile_width(width: float, across: int = TILE_COLUMNS) -> float:
	"""A tile's width: `across` tiles (TILE_COLUMNS unless said) across `width` with their gaps."""
	return floorf((width - float(TILE_GAP * (across - 1))) / float(across))


func _on_tile_input(event: InputEvent, k: int) -> void:
	"""Note whether Shift is held by the press that will press tile `k` (forgotten when the mouse leaves the tile, so a
	press released elsewhere never turns a later keyboard press into a drop)."""
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_tile_shift[k] = 1 if button.shift_pressed else 0


func _on_tile_pressed(k: int) -> void:
	"""Tile `k` was pressed: the resident it shows now (Shift as noted; a key press never holds it)."""
	var shift: bool = _tile_shift[k] == 1
	_tile_shift[k] = 0
	if k < _tile_index.size():
		tile_pressed.emit(_tile_index[k], shift)


func tile(k: int) -> Button:
	"""Tile `k` while shown (null otherwise)."""
	return _tile_buttons[k] if k >= 0 and k < _tile_buttons.size() and _tile_buttons[k].visible else null


func tile_count() -> int:
	"""How many tiles show."""
	return _tile_index.size() if visible else 0


func lines_text() -> String:
	"""Every shown line of the section, a line each (checks)."""
	var out := PackedStringArray([_doing.text])
	for label: Label in _line_labels:
		if label.visible:
			out.append(label.text)
	out.append(_crew_line.text)
	out.append(_group_line.text)
	return "\n".join(out)


static func _set_text(label: Label, text: String) -> void:
	"""Re-word a label only when its words changed."""
	if label.text != text:
		label.text = text
