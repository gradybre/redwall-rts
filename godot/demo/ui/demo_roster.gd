extends Node
## THE RESIDENTS COMMAND LISTS THE VILLAGE'S RESIDENTS. Decision 0251 (review group E, finding F14). Presentation
## only: it reads the cast and the command layer and writes nothing into the simulation.
##
## THE PROBLEM. The shell's Residents command (UI-SET-031, L) opens the roster rows (UI-SET-069), which UIManager
## fills from the SETTLEMENT's residents -- "Warden Rowan" and eleven "Unnamed resident" rows the demo never shows
## -- and a click on one opened that settlement resident, while the Demo party panel said "No one selected".
##
## THE ADAPTER. The same rows, the same workspace, filled from the demo's cast, one row per resident in cast order
## (`actor_of(row)` is that row's cast index):
##   line 1   name -- species, trade · where it is (on the surface, in the water, indoors, underground and on
##            which level)
##   line 2   what it is doing now (the party panel's own words, demo_command.gd `activity_text`) and the saved
##            work it will go back to ("Then back to: ...", the party panel's line)
## The workspace's title says "Residents". Rows refresh twice a second while the roster is open, and only when a
## row's words changed (the shell relays out on every `set_roster`).
##
## A ROW CLICKED selects that resident alone (the Demo party panel shows it), centres the camera on it and closes
## the roster so the resident is in view. The shell's `resident_row_picked` answers the demo now: UIManager's
## settlement lookup -- and only UIManager's; any other listener is kept -- is disconnected from THIS shell, because
## its rows are no longer settlement rows and resolving one would open someone the player never saw. UIManager binds
## the shell when the HUD registers, at the game's boot, before the demo is built; the demo never registers a HUD
## again (a second `register_hud` would reconnect it). UIManager still refreshes its own rows on the Residents
## action; this adapter's handler, connected after it, writes the demo's over them in the same call.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const CameraScript := preload("res://demo/camera/demo_camera.gd")

const TITLE: String = "Residents"
const REFRESH_S: float = 0.5
const THEN: String = "Then back to: %s"
const ON_SURFACE: String = "On the surface"
const IN_WATER: String = "In the water"
const INDOORS: String = "Indoors"
const UNDERGROUND: String = "Underground, level %d"
## A row's text starts this far in from its left edge (UI §1.2's 12 px panel padding).
const ROW_INSET_PX: float = 12.0
const ROW_SLOTS: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled", &"hover_pressed"]

var _shell: UiShell = null
var _cast: DemoCastScript = null
## The command layer: the selection and each resident's activity words.
var _command: CommandScript = null
## The camera rig: `centre_on`.
var _rig: CameraScript = null
var _rows: PackedStringArray = PackedStringArray()
var _refresh_in: float = 0.0


func configure(shell: UiShell, cast: DemoCastScript, command: CommandScript, rig: CameraScript) -> void:
	"""List this cast on this shell's roster; select through `command` and centre `rig`. Takes the shell's row
	picks (see THE ADAPTER)."""
	name = "DemoRoster"
	_shell = shell
	_cast = cast
	_command = command
	_rig = rig
	if _shell == null:
		return
	for connection: Dictionary in _shell.resident_row_picked.get_connections():
		if (connection["callable"] as Callable).get_object() == UIManager:
			_shell.resident_row_picked.disconnect(connection["callable"])
	_shell.resident_row_picked.connect(pick_row)
	_shell.shell_action.connect(_on_shell_action)


func _on_shell_action(element_id: int) -> void:
	"""The Residents command or the Residents counter: fill the rows with the cast (after UIManager's own)."""
	if element_id == UiShell.ID_RESIDENTS or element_id == UiShell.ID_POPULATION:
		refresh()


func _process(delta: float) -> void:
	"""While the roster is open: its title every frame (a relayout writes the shell's back), its rows twice a
	second when their words changed."""
	if not is_open():
		return
	var title: Label = _shell.workspace_title()
	if title.text != TITLE:
		title.text = TITLE
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_S
		refresh()


func is_open() -> bool:
	"""Whether the shell's workspace is showing the roster page."""
	if _shell == null or not is_instance_valid(_shell):
		return false
	return _shell.workspace_page() == UiRegistry.ROSTER_ID and _shell.control_for(UiShell.ID_WORKSPACE).visible


func refresh() -> bool:
	"""Write the cast's rows into the shell (only when a row's words changed); true when written."""
	if _shell == null or _cast == null:
		return false
	var rows: PackedStringArray = row_texts()
	var drawn: bool = _shell.roster_shown() == rows.size() and (rows.is_empty() or _shell.roster_row(0).text == rows[0])
	if rows == _rows and drawn:
		return false
	_rows = rows
	_shell.set_roster(rows, _cast.actor_count())
	for k: int in _shell.roster_shown():
		_shape_row(_shell.roster_row(k))
	if is_open():
		_shell.workspace_title().text = TITLE
	return true


static func _shape_row(row: Button) -> void:
	"""A row that shows both of its lines: left-aligned with its text inset ROW_INSET_PX from the edge (a copy of
	the skinned row's own boxes, made once per row), and wrapped, never cropped."""
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = false
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for slot: StringName in ROW_SLOTS:
		var box: StyleBox = row.get_theme_stylebox(slot)
		if box == null or row.has_theme_stylebox_override(slot) or box.content_margin_left >= ROW_INSET_PX:
			continue
		var inset: StyleBox = box.duplicate() as StyleBox
		inset.content_margin_left = ROW_INSET_PX
		inset.content_margin_right = maxf(box.content_margin_right, ROW_INSET_PX)
		row.add_theme_stylebox_override(slot, inset)


func row_texts() -> PackedStringArray:
	"""Every resident's row, in cast order."""
	var out := PackedStringArray()
	for i: int in _cast.actor_count():
		out.append(row_text(i))
	return out


func row_text(i: int) -> String:
	"""Resident `i`'s two lines (see THE ADAPTER)."""
	var actor := _cast.actor(i) as DemoActorScript
	var brain: BrainScript = actor.brain
	var doing: String = _command.activity_text(i) if _command != null else ""
	return row_words(actor.display_name, actor.species, trade_of(actor.creature_key), location_text(brain), doing,
		brain.unfinished_labels())


static func row_words(who: String, species: String, trade: String, where: String, doing: String,
		then: PackedStringArray) -> String:
	"""'Mole digger — Mole, digger · Underground, level 1' over 'Digging tunnel — 43% · Then back to: ...'."""
	var first: String = "%s — %s%s · %s" % [who, species, ", " + trade if not trade.is_empty() else "", where]
	var second: String = doing.left(1).to_upper() + doing.substr(1)
	if not then.is_empty():
		second += (" · " if not second.is_empty() else "") + THEN % ", ".join(then)
	return first if second.is_empty() else first + "\n" + second


static func trade_of(creature_key: StringName) -> String:
	"""A cast member's trade from its key: `otter_boatwright` -> "boatwright"; a placeholder has none ("")."""
	var key: String = String(creature_key)
	if key.begins_with("placeholder") or not key.contains("_"):
		return ""
	return key.substr(key.find("_") + 1).replace("_", " ")


static func location_text(brain: BrainScript) -> String:
	"""Where a resident is: in the water, indoors, underground on a level, or on the surface."""
	if brain.in_water:
		return IN_WATER
	if brain.indoors:
		return INDOORS
	if brain.underground:
		return UNDERGROUND % level_at_depth_u(Rules.to_u(-brain.ground_y_m))
	return ON_SURFACE


static func level_at_depth_u(depth_u: int) -> int:
	"""The tunnel level a floor this deep (u) belongs to: level 1 down to halfway to level 2's floor, then level
	2. A ramp between the surface and level 1 is level 1 (it is underground, and leads there)."""
	var between: int = (Rules.level_floor_depth_u(Rules.LEVEL_1) + Rules.level_floor_depth_u(Rules.LEVEL_2)) / 2
	return Rules.LEVEL_1 if depth_u <= between else Rules.LEVEL_2


func actor_of(row: int) -> int:
	"""The cast index row `row` lists (rows are in cast order), or -1 for a row that lists no one."""
	return row if _cast != null and row >= 0 and row < mini(_rows.size(), _cast.actor_count()) else -1


func pick_row(row: int) -> void:
	"""A roster row was chosen: select that resident alone, centre the camera on it, and close the roster."""
	var i: int = actor_of(row)
	if i < 0 or _command == null:
		return
	_command.select(PackedInt32Array([i]))
	var at: Vector2 = (_cast.actor(i) as DemoActorScript).brain.position
	if _rig != null:
		_rig.centre_on(Vector3(at.x, 0.0, at.y))
	var back := _shell.control_for(UiShell.ID_BACK) as Button
	if back != null and is_open():
		back.pressed.emit()
