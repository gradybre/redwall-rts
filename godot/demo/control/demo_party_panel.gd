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
## readout is clicked -- so while it is open the panel moves below it, or, where there is no room for
## its header and actions below it (1280x720), stays where it is under the ledger (which draws over it
## until it closes). The rectangle comes from the HUD's own equations (`scripts/ui/ui_layout.gd`,
## read, never modified) in LOGICAL pixels, and the panel draws at the HUD's effective scale S -- the
## interface scale included (demo_ui_scale.gd) -- recomputed on every viewport resize. It draws on a
## canvas layer BELOW the HUD's, so a true modal (which can span this column at 1280x720) covers it.
##
## THE FRAME NEVER HIDES (decision 0391, review F20 and F31). It is three parts, top to bottom:
##   * the HEADER: the title and the selected count ("6 selected");
##   * the SUMMARY: one line saying who and what -- one resident's name and what it is doing, or a
##     group's common activity ("Holding ×3 · Walking to the well ×2") -- cut with an ellipsis where it
##     is too long, whole in its tooltip; and the ACTIONS, always shown: Release (R) for any selection, and
##     Dig tunnel (B), Burrow home (H) and Root cellar (C) with a digger in it;
##   * the INSPECTOR, a vertical scroll filling the rest of the column: first the notice line (the
##     selection's own prompts and refusals, demo_command.gd `say`; a new one scrolls back to it), then for
##     one resident its species,
##     what it is doing now, the progress or the step of that (the words after " — "), what it will go
##     back to -- a row a job -- its skills, its orders IN FULL (each with what to right-click: never
##     folded away) and the hint; for a group, one row per member (every member: no "+ n more"), each a
##     button that selects that resident alone and centres the camera on it (`member_picked`).
## Where the column is too short for the header, summary and actions and a useful inspector (125 % and
## 150 % at 1280x720), the summary and actions move to the top of the inspector -- reached by scrolling,
## never hidden.
##
## STYLE. The woodland skin's own pieces (demo/ui/): carved-wood panel with parchment face, Noto
## Serif title, ink and umber text -- both >= 4.5:1 on the parchment (test_demo_command.gd checks).
## The panel stops the mouse, so a click on it never selects or orders anything in the world. Text is at
## least 14 logical px (UI §2.1) and every button at least 32 px tall (UX-T03).
##
## TUNNELS (demo/tunnel/). With a digger in the party -- anybeast who fits a bore (decision 0208) -- "Dig
## tunnel (B)" shows (emits `dig_requested`, the same as B), and beside it "Burrow home (H)" and "Root cellar
## (C)" (emit `room_requested` with the room's template: decision 0209). They take keyboard focus only from Tab
## and F7 (decision 0261), so Enter while laying a piece digs rather than pressing one again.

const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const PickRow := preload("res://demo/ui/demo_pick_row.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

signal dig_requested
signal room_requested(kind: int)
## A member's row was pressed: select that resident alone and centre on it (demo_command.gd `pick_member`).
signal member_picked(actor_index: int)
## Release (R) was pressed: hand the selection back to its routine (demo_command.gd `release_selection`).
signal release_requested

const TITLE: String = "Demo party"
const HINT: String = "Click or drag: select · Shift: add · Right-click: move / work · R: release · Esc: clear · B: dig tool · U: underground"
const DIG_BUTTON: String = "Dig tunnel (B)"
## The Dig button's hover tip (decision 0205: every action button says what it does and its key).
const DIG_TIP: String = "Dig tunnel (B) — the Dig tool: drag a tunnel from where it starts to where it ends (start on a tunnel to branch off it), or click its points and press Enter; Esc drops it, B closes the tool"
## The room tools' buttons (decision 0209): text, tip, and the template each asks for (underground_rooms.gd).
const ROOM_BUTTONS: Array[String] = ["Burrow home (H)", "Root cellar (C)"]
const ROOM_TIPS: Array[String] = [
	"Burrow home (H) — a round home with its own front door, dug beside the tunnels: move it, R turns it, click to dig it with a passage to the nearest tunnel (Shift+click: none)",
	"Root cellar (C) — a stone-lined cellar with a hatch, where the pantry stores harvests: move it, R turns it, click to dig it with a passage to the nearest tunnel (Shift+click: none)"]
const ROOM_TEMPLATES: Array[int] = [RoomsScript.TEMPLATE_HOME, RoomsScript.TEMPLATE_CELLAR]
const RELEASE_BUTTON: String = "Release (R)"
const RELEASE_TIP: String = "Release (R) — hand the selected residents back to their own routine; they stay selected"
const DIGGING: String = "Digging tunnel — %d%%"
## A room being dug names itself (decision 0209), e.g. "Digging Burrow home 1 — 43%".
const DIGGING_ROOM: String = "Digging %s — %d%%"
const DIG_SITE: String = "dig site"
const IN_TUNNEL: String = "Using tunnel"
## The tunnel extensions' states (demo/tunnel/): hauling a load below, waiting in a mouth's line.
const HAULING: String = "Hauling through tunnel"
const IN_QUEUE: String = "Waiting at a tunnel mouth"
const BUTTON_MARGINS: PackedFloat32Array = [12.0, 6.0, 12.0, 7.0]
const NOBODY: String = "No one selected"
const COUNT: String = "%d selected"
const GROUP: String = "%d residents"
## Where a state's progress or step starts ("Digging tunnel — 43%": the command, then "43%").
const STEP_MARK: String = " — "
const PROGRESS: String = "Progress: %s"
## The unfinished jobs a resident will go back to (resident_brain.gd RESUMING), latest first: a row each.
const THEN_HEAD: String = "Then back to:"
## A resident waiting for its route to be planned (resident_brain.gd ROUTING), and one holding where a trip it could not
## finish left it, with why (ARRIVAL AND REFUSAL; decision 0361).
const FINDING_ROUTE: String = "finding a route"
const HOLDING_REFUSED: String = "holding — %s"
const BULLET: String = "• "
## A group's common activity: each activity and how many are at it, most first.
const TALLY: String = "%s ×%d"
const WIDTH: float = 320.0
## The carved frame draws this far outside the panel rectangle (woodland_styles PIECE_PANEL).
const FRAME_EXPAND: float = 10.0
const MINIMAP_GAP: float = 8.0
const TITLE_PX: int = 20
const BODY_PX: int = 15
## UI §2.1's minimum rendered text (was 13 px before decision 0391).
const SMALL_PX: int = 14
const BUTTON_H: float = 32.0
const CHIP_PX: float = 12.0
const CONTENT_MARGINS: PackedFloat32Array = [14.0, 10.0, 14.0, 12.0]
const SEPARATION: int = 6
## A wrapped line's least width leaves this much for the inspector's scroll bar.
const SCROLLBAR_ALLOWANCE: float = 16.0
## Below this much inspector the summary and actions move into it (see THE FRAME NEVER HIDES).
const MIN_INSPECTOR_H: float = 72.0
## The HUD surface this panel yields to (see PLACEMENT).
const LEDGER_NAME: String = "UI-SET-009"
const LEDGER_GAP: float = 8.0

var _frame: PanelContainer = null
var _column: VBoxContainer = null
var _count: Label = null
var _top: VBoxContainer = null
var _summary: Label = null
var _chip: ColorRect = null
var _notice: Label = null
var _actions: HFlowContainer = null
var _release: Button = null
var _dig: Button = null
var _room_buttons: Array[Button] = []
var _inspector: DemoScroll = null
var _detail: VBoxContainer = null
var _rows: VBoxContainer = null
## One resident's lines and a group's member rows, each a pool re-worded in place (never rebuilt: a click, a
## keyboard focus or a tooltip on a row survives the panel's refresh).
var _line_box: VBoxContainer = null
var _line_labels: Array[Label] = []
var _member_box: VBoxContainer = null
var _member_rows: Array[Button] = []
## The cast index each member row selects, and how many rows are in use.
var _member_index: PackedInt32Array = PackedInt32Array()
var _member_count: int = 0
var _abilities: Label = null
var _hint: Label = null
var _docked: bool = true
var _pending_notice: String = ""
var _place_queued: bool = false
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
	if _frame != null:
		return
	layer = 0
	name = "DemoPartyPanel"
	_build()
	show_party([])
	show_notice(_pending_notice)


func dig_button() -> Button:
	"""The "Dig tunnel" button (null before build)."""
	return _dig


func release_button() -> Button:
	"""The "Release (R)" button (null before build)."""
	return _release


func notice_label() -> Label:
	"""The notice line (null before build)."""
	return _notice


func _build() -> void:
	"""Frame; header; summary, notice and actions; the inspector."""
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL, CONTENT_MARGINS))
	_frame.theme = CardScript.tooltip_theme()
	add_child(_frame)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", SEPARATION)
	_frame.add_child(_column)
	_column.add_child(_build_header())
	_top = _build_top()
	_column.add_child(_top)
	_inspector = DemoScroll.new()
	_inspector.name = "Inspector"
	_column.add_child(_inspector)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override(&"separation", SEPARATION)
	_inspector.add_child(_detail)
	_build_detail()
	_top.minimum_size_changed.connect(_queue_place)
	_detail.minimum_size_changed.connect(_queue_place)


func _queue_place() -> void:
	"""Place the frame again at the end of this frame, once (a content change re-measures its parts)."""
	if not _place_queued:
		_place_queued = true
		_place.call_deferred()


func _build_header() -> HBoxContainer:
	"""The title and, at its right, how many are selected."""
	var header := HBoxContainer.new()
	var title := _label(TITLE, TITLE_PX, Palette.INK, Styles.heading_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_count = _label("", SMALL_PX, Palette.UMBER, null)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_count)
	return header


func _build_top() -> VBoxContainer:
	"""The summary line (a chip and an ellipsis-cut line) and the actions."""
	var top := VBoxContainer.new()
	top.name = "Summary"
	top.add_theme_constant_override(&"separation", SEPARATION)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	_chip = ColorRect.new()
	_chip.custom_minimum_size = Vector2(CHIP_PX, CHIP_PX)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_chip)
	_summary = _label("", BODY_PX, Palette.INK, null)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.clip_text = true
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(_summary)
	top.add_child(line)
	_actions = _build_actions()
	top.add_child(_actions)
	return top


func _build_actions() -> HFlowContainer:
	"""Release (R) always; the Dig tool and the room tools, hidden until a digger is in the party."""
	var row := HFlowContainer.new()
	row.name = "Actions"
	row.add_theme_constant_override(&"h_separation", SEPARATION)
	row.add_theme_constant_override(&"v_separation", SEPARATION)
	_release = _wood_button(RELEASE_BUTTON, RELEASE_TIP, func() -> void: release_requested.emit())
	row.add_child(_release)
	_dig = _wood_button(DIG_BUTTON, DIG_TIP, func() -> void: dig_requested.emit())
	row.add_child(_dig)
	for k in ROOM_BUTTONS.size():
		var room := _wood_button(ROOM_BUTTONS[k], ROOM_TIPS[k], room_requested.emit.bind(ROOM_TEMPLATES[k]))
		_room_buttons.append(room)
		row.add_child(room)
	return row


func _build_detail() -> void:
	"""The inspector's content: the notice, the rows, the orders and the hint."""
	_notice = _wrapped("", BODY_PX, Palette.INK)
	_notice.visible = false
	_detail.add_child(_notice)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 3)
	_detail.add_child(_rows)
	_line_box = VBoxContainer.new()
	_line_box.add_theme_constant_override(&"separation", 3)
	_rows.add_child(_line_box)
	_member_box = VBoxContainer.new()
	_member_box.add_theme_constant_override(&"separation", 1)
	_rows.add_child(_member_box)
	_abilities = _wrapped("", SMALL_PX, Palette.UMBER)
	_abilities.visible = false
	_detail.add_child(_abilities)
	_hint = _wrapped(HINT, SMALL_PX, Palette.UMBER)
	_detail.add_child(_hint)


func room_button(k: int) -> Button:
	"""The room tool's button `k` (0 Burrow home, 1 Root cellar; null before build)."""
	return _room_buttons[k] if k >= 0 and k < _room_buttons.size() else null


func _wood_button(text: String, tip: String, pressed: Callable) -> Button:
	"""A wood button: cream on wood, brass when pressed, at least BUTTON_H tall; takes keyboard focus
	(decision 0261)."""
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	Styles.focusable(button, BUTTON_MARGINS)
	button.custom_minimum_size.y = BUTTON_H
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override(&"font_size", BODY_PX)
	button.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	button.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		button.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	button.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	button.pressed.connect(pressed)
	return button


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String, px: int, colour: Color) -> Label:
	"""A label that wraps at the column's width (never cut)."""
	var label := _label(text, px, colour, null)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = inner_width() - SCROLLBAR_ALLOWANCE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func inner_width() -> float:
	"""The column's width inside the frame's margins, logical px."""
	return WIDTH - CONTENT_MARGINS[0] - CONTENT_MARGINS[2]


# --- what it shows ----------------------------------------------------------------------------------

func show_party(entries: Array[Dictionary]) -> void:
	"""Show these residents: [{"index", "name", "species", "state", "colour", "skills", "then", "abilities",
	"digger"}] ("index" is the cast index a member's row selects)."""
	_count.text = count_text(entries.size())
	_summary.text = summary_text(entries)
	_summary.tooltip_text = _summary.text
	_chip.color = entries[0].get("colour", Palette.SAGE) if entries.size() == 1 else Color(0, 0, 0, 0)
	_chip.visible = entries.size() == 1
	_release.visible = not entries.is_empty()
	_dig.visible = has_digger(entries)
	for room: Button in _room_buttons:
		room.visible = _dig.visible
	_actions.visible = _release.visible
	_fill_rows(entries)
	var abilities: PackedStringArray = entries[0].get("abilities", PackedStringArray()) if entries.size() == 1 \
			else PackedStringArray()
	_abilities.text = "\n".join(abilities)
	_abilities.visible = not abilities.is_empty()
	_queue_place()


func _fill_rows(entries: Array[Dictionary]) -> void:
	"""The inspector's rows: one resident's lines (after its name, which the summary says), or a member row
	each (`member_picked` on press) -- from the pools, re-worded in place, the rows not wanted hidden."""
	var lines := party_lines(entries)
	var group: bool = entries.size() > 1
	_member_count = entries.size() if group else 0
	_member_index.resize(_member_count)
	for k: int in _member_count:
		_member_index[k] = int(entries[k]["index"])
		var row: Button = _member_row_at(k)
		PickRow.set_text(row, lines[k + 1])
		PickRow.set_chip(row, entries[k].get("colour", Palette.SAGE))
	for k: int in _member_rows.size():
		_member_rows[k].visible = k < _member_count
	var shown: int = 0 if group else maxi(lines.size() - 1, 0)
	for k: int in shown:
		var label: Label = _line_at(k)
		if label.text != lines[k + 1]:
			label.text = lines[k + 1]
	for k: int in _line_labels.size():
		_line_labels[k].visible = k < shown


func _member_row_at(k: int) -> Button:
	"""Member row `k` of the pool (made, and connected once, when missing)."""
	while _member_rows.size() <= k:
		var row: Button = PickRow.make("", Palette.SAGE, SMALL_PX, Palette.INK)
		row.pressed.connect(_on_member_pressed.bind(_member_rows.size()))
		_member_rows.append(row)
		_member_box.add_child(row)
	return _member_rows[k]


func _on_member_pressed(k: int) -> void:
	"""Member row `k` was pressed: the resident it lists now."""
	if k < _member_count:
		member_picked.emit(_member_index[k])


func _line_at(k: int) -> Label:
	"""One resident's line `k` (after its name) from the pool: what it is doing in body ink, the rest in umber."""
	while _line_labels.size() <= k:
		var lead: bool = _line_labels.size() == 1
		var label: Label = _wrapped("", BODY_PX if lead else SMALL_PX, Palette.INK if lead else Palette.UMBER)
		_line_labels.append(label)
		_line_box.add_child(label)
	return _line_labels[k]


func member_row(k: int) -> Button:
	"""A group's member row `k` (null when there is none: one resident, or nobody)."""
	return _member_rows[k] if k >= 0 and k < _member_count else null


func member_row_count() -> int:
	"""How many member rows the inspector lists (0 unless a group is selected)."""
	return _member_count


func summary() -> String:
	"""The summary line as shown."""
	return _summary.text if _summary != null else ""


func count_shown() -> String:
	"""The header's count ("6 selected"; "" for nobody)."""
	return _count.text if _count != null else ""


func abilities_text() -> String:
	"""The orders list as shown ("" when hidden: nobody, or a group)."""
	return _abilities.text if _abilities != null and _abilities.visible else ""


static func has_digger(entries: Array[Dictionary]) -> bool:
	"""Whether any of these residents digs tunnels (an entry's "digger")."""
	for entry in entries:
		if bool(entry.get("digger", false)):
			return true
	return false


func show_notice(text: String) -> void:
	"""The selection's notice line -- a prompt, a length or a refusal ("" hides it) -- first in the inspector,
	which a new notice scrolls back to. Before the panel is built (out of the tree) the text waits for it."""
	_pending_notice = text
	if _notice == null:
		return
	if _notice.text != text and not text.is_empty():
		_inspector.scroll_vertical = 0
	_notice.text = text
	_notice.visible = not text.is_empty()
	_queue_place()


func notice() -> String:
	"""The notice line's text ("" when hidden)."""
	return _pending_notice


# --- the words ----------------------------------------------------------------------------------------

static func count_text(selected: int) -> String:
	"""The header's count: "6 selected" ("" for nobody)."""
	return "" if selected == 0 else COUNT % selected


static func summary_text(entries: Array[Dictionary]) -> String:
	"""The summary line: nobody; one resident's name and what it is doing; or a group's common activity."""
	if entries.is_empty():
		return NOBODY
	if entries.size() == 1:
		return "%s — %s" % [entries[0]["name"], entries[0]["state"]]
	return activity_tally(entries)


static func activity_tally(entries: Array[Dictionary]) -> String:
	"""What a group is doing, each command (a state before its progress) with how many, most first, ties in
	selection order: "Holding ×3 · Walking to the well ×2 · Wandering ×1"."""
	var names := PackedStringArray()
	var counts := PackedInt32Array()
	for entry: Dictionary in entries:
		var what: String = first_up(command_of(String(entry["state"])))
		var at: int = names.find(what)
		if at < 0:
			names.append(what)
			counts.append(1)
		else:
			counts[at] += 1
	var parts := PackedStringArray()
	for most: int in range(entries.size(), 0, -1):
		for k: int in names.size():
			if counts[k] == most:
				parts.append(TALLY % [names[k], most])
	return " · ".join(parts)


static func command_of(state: String) -> String:
	"""A state's command: its words before the first " — " ("Digging tunnel — 43%": "Digging tunnel")."""
	var at: int = state.find(STEP_MARK)
	return state if at < 0 else state.left(at)


static func step_of(state: String) -> String:
	"""A state's progress or step: its words after the first " — " ("" when it has none)."""
	var at: int = state.find(STEP_MARK)
	return "" if at < 0 else state.substr(at + STEP_MARK.length())


static func first_up(words: String) -> String:
	"""`words` with a capital first letter."""
	return words.left(1).to_upper() + words.substr(1)


static func party_lines(entries: Array[Dictionary]) -> PackedStringArray:
	"""What the panel says, in reading order. Nobody: NOBODY. One resident: its name (the summary's lead),
	species, what it is doing, the progress or step of that (when its state has one), "Then back to:" and a
	row per unfinished job, then its skills, a line for each line of them. A group: "n residents", then a line
	per member -- every member -- with its short skills after its state."""
	var lines := PackedStringArray()
	if entries.is_empty():
		lines.append(NOBODY)
	elif entries.size() == 1:
		_one_lines(entries[0], lines)
	else:
		lines.append(GROUP % entries.size())
		for entry: Dictionary in entries:
			var skills: String = String(entry.get("skills", ""))
			lines.append("%s — %s%s" % [entry["name"], entry["state"], "" if skills.is_empty() else " · " + skills])
	return lines


static func _one_lines(entry: Dictionary, lines: PackedStringArray) -> void:
	"""One resident's lines (see party_lines)."""
	var state: String = String(entry["state"])
	lines.append(String(entry["name"]))
	lines.append(String(entry["species"]))
	lines.append(command_of(state))
	if not step_of(state).is_empty():
		lines.append(PROGRESS % step_of(state))
	var then: PackedStringArray = entry.get("then", PackedStringArray())
	if not then.is_empty():
		lines.append(THEN_HEAD)
		for job: String in then:
			lines.append(BULLET + job)
	for skill: String in String(entry.get("skills", "")).split("\n", false):
		lines.append(skill)


static func state_text(activity: int, clip: StringName, place: String, dug_percent: int = 0) -> String:
	"""What a resident is doing, in words: wandering / walking to X / working: collect / holding /
	Digging tunnel — 43% (with `dug_percent`; a room's `place` names it: Digging Burrow home 1 — 43%) / Using
	tunnel / Hauling through tunnel / Waiting at a tunnel mouth / a task's own words (`place`)."""
	if activity == BrainScript.ACTIVITY_DIGGING:
		return DIGGING % dug_percent if place.is_empty() or place == DIG_SITE else DIGGING_ROOM % [place, dug_percent]
	if activity == BrainScript.ACTIVITY_TASK:
		return place
	if activity == BrainScript.ACTIVITY_QUEUE:
		return IN_QUEUE
	if activity == BrainScript.ACTIVITY_TUNNEL:
		return HAULING if clip == BrainScript.CLIP_CARRY else IN_TUNNEL
	if activity == BrainScript.ACTIVITY_CROSSING:
		return "crossing the water"
	if activity == BrainScript.ACTIVITY_ROUTING:
		return FINDING_ROUTE
	if activity == BrainScript.ACTIVITY_HOLDING:
		return "holding"
	if activity == BrainScript.ACTIVITY_WALKING:
		return "walking to " + (place if place != "" else "marker")
	if activity == BrainScript.ACTIVITY_WORKING:
		if clip == BrainScript.CLIP_IDLE or clip == BrainScript.CLIP_WALK:
			return "working at " + place
		return "working: " + String(clip).replace("_", " ")
	return "wandering"


# --- placement ----------------------------------------------------------------------------------------

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
	built for a check out of it, there is no viewport to fit). A content change queues it again once its parts
	have measured themselves (`_queue_place`)."""
	_place_queued = false
	if not is_inside_tree() or _frame == null:
		return
	var size_px := get_viewport().get_visible_rect().size
	var rect := placement(int(size_px.x), int(size_px.y), _layout, _geometry)
	if _ledger_open:
		rect = below_ledger(rect, _ledger.get_global_rect().end.y / _geometry.scale, fixed_height())
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = Vector2(rect.size.x, 0.0)
	fit(rect.size.y)
	_frame.size = Vector2(rect.size.x, 0.0)
	_frame.visible = true


static func below_ledger(column: Rect2, ledger_bottom: float, least: float) -> Rect2:
	"""The column below an open ledger whose foot is at `ledger_bottom` (logical px) -- or, where that leaves
	less than `least` (the header, summary and actions), the column as it was (the ledger draws over it until it
	closes: the panel is never hidden)."""
	var top: float = ledger_bottom + LEDGER_GAP + FRAME_EXPAND
	if column.end.y - top < least:
		return column
	return Rect2(column.position.x, top, column.size.x, column.end.y - top)


func fit(height: float) -> bool:
	"""Fit the frame to `height` logical px: the header, summary and actions fixed above an inspector as tall as
	its content or the rest of the column -- or, where that would leave the inspector less than
	MIN_INSPECTOR_H, the summary and actions at the inspector's top (`docked` false). True when docked."""
	var box: StyleBox = _frame.get_theme_stylebox(&"panel")
	var frame_h: float = box.get_minimum_size().y if box != null else 0.0
	var header_h: float = (_column.get_child(0) as Control).get_combined_minimum_size().y
	var top_h: float = _top.get_combined_minimum_size().y
	var rest_h: float = _detail.get_combined_minimum_size().y - (0.0 if _docked else top_h + SEPARATION)
	var room_docked: float = height - frame_h - header_h - top_h - 2.0 * SEPARATION
	_dock(room_docked >= MIN_INSPECTOR_H or room_docked >= rest_h)
	var room: float = room_docked if _docked else height - frame_h - header_h - SEPARATION
	var content: float = rest_h if _docked else rest_h + top_h + SEPARATION
	_inspector.custom_minimum_size.y = clampf(content, 0.0, maxf(room, 0.0))
	return _docked


func _dock(docked: bool) -> void:
	"""Put the summary and actions above the inspector (`docked`) or at its top; a button of theirs that had the
	focus keeps it (moving a node drops its focus)."""
	if docked == _docked:
		return
	_docked = docked
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var keyboard: bool = focused != null and _top.is_ancestor_of(focused) and focused.has_focus(true)
	_top.get_parent().remove_child(_top)
	if docked:
		_column.add_child(_top)
		_column.move_child(_top, 1)
	else:
		_detail.add_child(_top)
		_detail.move_child(_top, 0)
	if focused != null and _top.is_ancestor_of(focused) and focused.is_inside_tree():
		focused.grab_focus(not keyboard)


func docked() -> bool:
	"""Whether the summary and actions sit above the inspector (false: at its top, see fit)."""
	return _docked


func fixed_height() -> float:
	"""The header, summary and actions' height with the frame's margins, logical px."""
	var box: StyleBox = _frame.get_theme_stylebox(&"panel")
	return (box.get_minimum_size().y if box != null else 0.0) + (_column.get_child(0) as Control).get_combined_minimum_size().y \
		+ _top.get_combined_minimum_size().y + SEPARATION


func inspector() -> ScrollContainer:
	"""The scrolling inspector (checks)."""
	return _inspector


static func placement(width: int, height: int, layout: UiLayout, geometry: UiLayout.Geometry) -> Rect2:
	"""The panel's rectangle in the HUD's logical pixels: the left column between the reserved band
	and the minimap, inset by the carved frame. Fills `geometry` (scale 1 when the viewport is
	below the supported floor and the HUD refuses to lay out)."""
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			DemoUiScale.percent, false, geometry):
		geometry.scale = 1.0
	var top := geometry.management_top + FRAME_EXPAND
	var bottom := geometry.minimap.position.y - MINIMAP_GAP - FRAME_EXPAND
	return Rect2(UiLayout.SAFE_INSET + FRAME_EXPAND, top, WIDTH, maxf(bottom - top, 0.0))


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (for checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)
