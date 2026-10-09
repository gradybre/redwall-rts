extends Node
## THE GROUP SELECTION (decision 0791): what the live demo does with SEVERAL residents selected, on top of the select-and-
## command layer (demo_command.gd, decision 0196), which still owns picking, the box, Shift and every order. DEMO UI and
## demo input; presentation only -- the orders move the demo cast, the crews are the demo's (work_crews.gd), and nothing
## here is saved (GDD §4: selection is outside saved gameplay truth).
##
## WHAT IT ADDS, each from UI §5's input table or the brief, and nothing the documents do not name:
##   * CONTROL GROUPS (UI §5 `group_assign_N` Ctrl+0..9, `group_recall_N` 0..9, `group_center_N` the same digit twice
##     within 300 ms; §5.2 "announces remaining count"): Ctrl+digit keeps the selection as that group, the digit selects
##     it again, twice goes to it too (the camera eases to the middle of its members' bounding box). control_groups.gd.
##   * SELECT VISIBLE SIMILAR (UI §5 `select_similar`: a double left click within 250 ms on a resident selects every
##     resident of its species in view, capped at 256): the second click replaces the first's result (§5's "a double-click
##     replaces its result"), and orders nothing.
##   * "SELECTING RESIDENTS: n" beside the box while it is dragged (UI-SET-025's accessible value).
##   * THE GROUP PANEL (group_panel.gd) in the party panel's inspector for two or more: what they are doing, the
##     warnings and notes they hold (group_status.gd, rows added by data), who is idle, a tile per member (centre on it;
##     Shift: drop it), put them all on one crew, Send to…, and their control group.
##   * SELECT IDLE: a button above the inspector, with any selection or none, selecting every resident the Work screen
##     calls "available" (work_crews.gd `status_of`). UI §5 binds no key to it, so it has none.
## INPUT is a hook on the command layer (`add_input_hook`): it sees each world event after the Dig tool and before
## selection, so a click the HUD or a panel took never reaches it, a pop-up's gate still swallows its keys, and a text
## field still types digits. Keys need no selection: a digit recalls from nothing selected.

const CommandScript := preload("res://demo/control/demo_command.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const GroupPanel := preload("res://demo/control/group_panel.gd")
const GroupStatus := preload("res://demo/control/group_status.gd")
const ControlGroups := preload("res://demo/control/control_groups.gd")
const PickScript := preload("res://demo/control/demo_pick.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## The panel's refresh, real seconds (and at once when the selection changes).
const REFRESH_S: float = 0.25
## UI §5: "Double left click within 250 ms".
const SIMILAR_USEC: int = 250000
## UI §5: "cap 256".
const SIMILAR_CAP: int = 256
const BOX_LABEL_PX: int = 14
const BOX_LABEL_GAP: float = 8.0
const BOX_LABEL_MARGINS: PackedFloat32Array = [8.0, 3.0, 8.0, 4.0]

const BOX_COUNT: String = "Selecting residents: %d"
const TALLY: String = "%s ×%d"
const NAMES_LINE: String = "%s ×%d — %s"
const DOING: String = "Doing: %s"
const IDLE_NOBODY: String = "Idle: nobody"
const CREW_LINE: String = "Crews: %s — put them all on:"
const CREW_ALREADY: String = "All %d are on the %s crew already"
const CREW_JOIN: String = "%s crew (%s): %s join%s%s"
const CREW_STAYS: String = "; %s already on it"
const TILE_TIP: String = "%s — %s%s · %s crew. Click: centre the view on them (the group stays selected); Shift+click: drop them from the selection"
const GROUP_KEPT: String = "Kept as group %d — %d selects it again, %d twice goes to it"
const GROUP_KEYS: String = "Ctrl+0–9 keeps this group; 0–9 selects it again, twice goes to it"
const ASSIGNED: String = "Group %d: %s — press %d to select them again, %d twice to go to them"
const ASSIGN_NOBODY: String = "Nobody selected: group %d is kept as it was"
const RECALLED: String = "Group %d: %d selected"
const RECALLED_LOST: String = "Group %d: %d selected (%d no longer here)"
const RECALL_EMPTY: String = "Group %d is empty — select residents and press Ctrl+%d to keep them as group %d"
const IDLE_SELECTED: String = "Selected the %d idle: %s"
const IDLE_NONE: String = "Nobody is idle: everyone is working, resting or in the water"
const SIMILAR: String = "Selected every %s in view: %d"
const SEND_ARMED: String = "Click where to send the %d selected (a work spot: they work it) — Esc cancels"
const SEND_CANCELLED: String = "Send to… cancelled"
const SEND_BELOW: String = "Underground: right-click where to send them"
const DROPPED: String = "%s left the selection"

## The input map's control-group actions (UI §5), by digit.
const ASSIGN_ACTIONS: Array[StringName] = [&"group_assign_0", &"group_assign_1", &"group_assign_2", &"group_assign_3",
	&"group_assign_4", &"group_assign_5", &"group_assign_6", &"group_assign_7", &"group_assign_8", &"group_assign_9"]
const RECALL_ACTIONS: Array[StringName] = [&"group_recall_0", &"group_recall_1", &"group_recall_2", &"group_recall_3",
	&"group_recall_4", &"group_recall_5", &"group_recall_6", &"group_recall_7", &"group_recall_8", &"group_recall_9"]

## The statuses the group panel shows (see group_status.gd: an owner adds its rows here).
var statuses: GroupStatus = GroupStatus.new()
var groups: ControlGroups = ControlGroups.new()
var panel: GroupPanel = null

var _command: CommandScript = null
var _cast: DemoCastScript = null
var _board: BoardScript = null
var _centre: Callable = Callable()
var _armed: bool = false
var _everyone: PackedInt32Array = PackedInt32Array()
var _members: PackedInt32Array = PackedInt32Array()
var _scratch: PackedInt32Array = PackedInt32Array()
## The box test's hits (`box_into`: sized to the cast, the first n valid) -- never shared with `_scratch`.
var _box_hits: PackedInt32Array = PackedInt32Array()
var _idle: PackedInt32Array = PackedInt32Array()
var _signature: PackedInt64Array = PackedInt64Array()
var _shown: PackedInt64Array = PackedInt64Array()
var _view: GroupPanel.GroupView = GroupPanel.GroupView.new()
var _refresh_in: float = 0.0
var _seen_revision: int = -1
var _press_usec: int = -SIMILAR_USEC - 1
var _press_at: Vector2 = Vector2.INF
var _box_frame: PanelContainer = null
var _box_label: Label = null
var _box_count: int = -1
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(command: CommandScript, cast: DemoCastScript, board: BoardScript, centre: Callable) -> void:
	"""Over this command layer, cast and work board; `centre(point: Vector3)` eases the camera (demo_camera.gd
	`centre_on`). Puts the group panel and Select idle in the party panel, the input hook on the command layer, and the
	two statuses every village has: Idle and Can't get there."""
	name = "GroupSelect"
	_command = command
	_cast = cast
	_board = board
	_centre = centre
	for who: int in cast.actor_count():
		_everyone.append(who)
	_build_panel(command.panel())
	command.add_input_hook(handle_input)
	statuses.add(GroupStatus.IDLE, "Idle", GroupStatus.SEVERITY_NOTE, is_idle)
	statuses.add(&"stuck", "Can't get there", GroupStatus.SEVERITY_WARN, is_stuck)
	_build_box_label()


func _build_panel(party: PanelScript) -> void:
	"""The group panel, as the party panel's section and top row, its signals connected."""
	party.build()
	panel = GroupPanel.new()
	panel.build(PanelScript.inner_width() - PanelScript.SCROLLBAR_ALLOWANCE)
	party.add_section(panel)
	party.add_top_row(panel.top_row())
	panel.tile_pressed.connect(_on_tile)
	panel.crew_pressed.connect(put_on_crew)
	panel.send_pressed.connect(func() -> void: arm_send(not _armed))
	panel.idle_pressed.connect(select_idle)


func bind_needs(fed_word: Callable, night: NightScript) -> void:
	"""The needs every village shows, read through their owners' existing queries: Hungry and Peckish from the kitchen's
	`fed_word(i)` (meal_rules.gd FED_WORDS), and No bed from the night's `bed_of` column (night_routine.gd, read when
	asked, so its later allocations count; null: no such row)."""
	var hungry: String = Rules.FED_WORDS[Rules.HUNGRY]
	var peckish: String = Rules.FED_WORDS[Rules.PECKISH]
	statuses.add(&"hungry", "Hungry", GroupStatus.SEVERITY_WARN,
		func(who: int) -> bool: return String(fed_word.call(who)) == hungry)
	statuses.add(&"peckish", "Peckish", GroupStatus.SEVERITY_NOTE,
		func(who: int) -> bool: return String(fed_word.call(who)) == peckish)
	if night != null:
		statuses.add(&"no_bed", "No bed", GroupStatus.SEVERITY_NOTE, func(who: int) -> bool:
			return who >= 0 and who < night.bed_of.size() and night.bed_of[who] == AllocationScript.NO_BED)


func _build_box_label() -> void:
	"""The drag box's count: a parchment tag beside the box, on the box's own canvas layer, ignoring the mouse."""
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_box_frame = PanelContainer.new()
	_box_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color = Palette.OAT
	face.border_color = Palette.DEEP_SHADE
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = BOX_LABEL_MARGINS[0]
	face.content_margin_top = BOX_LABEL_MARGINS[1]
	face.content_margin_right = BOX_LABEL_MARGINS[2]
	face.content_margin_bottom = BOX_LABEL_MARGINS[3]
	_box_frame.add_theme_stylebox_override(&"panel", face)
	_box_label = Label.new()
	_box_label.add_theme_font_size_override(&"font_size", BOX_LABEL_PX)
	_box_label.add_theme_color_override(&"font_color", Palette.INK)
	_box_frame.add_child(_box_label)
	_box_frame.visible = false
	layer.add_child(_box_frame)


# --- the statuses' own queries ---------------------------------------------------------------------------

func is_idle(who: int) -> bool:
	"""Whether resident `who` has nothing to do: the Work screen's "available" (work_crews.gd `status_of` -- not resting,
	not in the water, under no order, task or job)."""
	if _cast == null or who < 0 or who >= _cast.actor_count():
		return false
	var brain: BrainScript = (_cast.actor(who) as DemoActorScript).brain
	return CrewsScript.status_of(brain, _board != null and _board.has_job(who)) == CrewsScript.STATUS_AVAILABLE


func is_stuck(who: int) -> bool:
	"""Whether resident `who` is holding where a trip it gave up left it (the party panel's "holding — can't find a way
	there": resident_brain.gd ARRIVAL AND REFUSAL)."""
	if _cast == null or who < 0 or who >= _cast.actor_count():
		return false
	var brain: BrainScript = (_cast.actor(who) as DemoActorScript).brain
	return brain.activity() == BrainScript.ACTIVITY_HOLDING and brain.trip_failed()


# --- input -----------------------------------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	"""The command layer's hook (see INPUT): control-group keys, Esc while Send to… waits, the click Send to… waits for,
	and a double click's select-similar. True when taken."""
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and _on_key(key)
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return false
	if _armed:
		return _on_armed_click(button)
	if button.button_index == MOUSE_BUTTON_LEFT and not button.shift_pressed:
		return _on_left_press(button.position, Time.get_ticks_usec())
	return false


func _on_key(key: InputEventKey) -> bool:
	"""Esc cancels a waiting Send to…; Ctrl+digit keeps a group; a digit selects one (twice quickly: and goes to it)."""
	if _armed and key.is_action_pressed(&"selection_clear"):
		arm_send(false)
		_command.say(SEND_CANCELLED)
		return true
	for slot: int in ControlGroups.GROUP_COUNT:
		if key.is_action_pressed(ASSIGN_ACTIONS[slot], false, true):
			assign_group(slot)
			return true
		if key.is_action_pressed(RECALL_ACTIONS[slot], false, true):
			recall_group(slot, groups.tap(slot, Time.get_ticks_usec()))
			return true
	return false


func _on_armed_click(button: InputEventMouseButton) -> bool:
	"""While Send to… waits: a left click sends the selection there (taken); a right click gives its own order as ever
	(not taken), and either ends the wait. The wheel and any other button leave it waiting (not taken)."""
	if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
		return false
	arm_send(false)
	if button.button_index != MOUSE_BUTTON_LEFT:
		return false
	_command.order_at(button.position)
	return true


func _on_left_press(at: Vector2, usec: int) -> bool:
	"""A left press: the second of a double click (within SIMILAR_USEC and the drag threshold of the first) on a resident
	selects the residents of its species in view (taken); any other is left to selection and remembered."""
	var double: bool = usec - _press_usec <= SIMILAR_USEC and not PickScript.is_drag(_press_at, at)
	_press_usec = -SIMILAR_USEC - 1 if double else usec
	_press_at = at
	return double and select_similar(at) > 0


# --- what it does ----------------------------------------------------------------------------------------

func assign_group(slot: int) -> bool:
	"""Ctrl+digit: keep the selection as group `slot`, and say so. False with nobody selected (the group is kept)."""
	var members: PackedInt32Array = _command.selected()
	if not groups.assign(slot, members):
		_command.say(ASSIGN_NOBODY % slot)
		return false
	_command.say(ASSIGNED % [slot, ", ".join(_short_names(members)), slot, slot])
	_refresh_in = 0.0
	return true


func recall_group(slot: int, go_to: bool) -> int:
	"""A digit: select group `slot`'s members still here and say how many (§5.2); `go_to` (the digit twice): centre the
	view on them too. An empty group leaves the selection as it was and says how to fill it. How many are selected."""
	var stored: int = groups.size_of(slot)
	var count: int = groups.recall_into(slot, _cast.actor_count(), _scratch)
	if count == 0:
		_command.say(RECALL_EMPTY % [slot, slot, slot])
		return 0
	_command.select(_scratch)
	_command.say(RECALLED % [slot, count] if count == stored else RECALLED_LOST % [slot, count, stored - count])
	if go_to and _centre.is_valid():
		_centre.call(middle_of(_scratch))
	_refresh_in = 0.0
	return count


func middle_of(members: PackedInt32Array) -> Vector3:
	"""The middle of these residents' bounding box on the surface (UI §5's "bounding-box centroid"), at ground level."""
	var box := Rect2()
	for k: int in members.size():
		var at: Vector2 = (_cast.actor(members[k]) as DemoActorScript).brain.surface_point()
		box = Rect2(at, Vector2.ZERO) if k == 0 else box.expand(at)
	var middle: Vector2 = box.get_center()
	return Vector3(middle.x, 0.0, middle.y)


func select_idle() -> int:
	"""Select every idle resident (the IDLE row), and say who; with nobody idle, say so and keep the selection."""
	var count: int = statuses.members_into(statuses.find(GroupStatus.IDLE), _everyone, _scratch)
	if count == 0:
		_command.say(IDLE_NONE)
		return 0
	_command.select(_scratch)
	_command.say(IDLE_SELECTED % [count, ", ".join(_short_names(_scratch))])
	_refresh_in = 0.0
	return count


func select_similar(at: Vector2) -> int:
	"""Select every resident in view of the species of the one at screen point `at` (UI §5 `select_similar`, at most
	SIMILAR_CAP); how many (0, and nothing changed, with no resident there)."""
	var who: int = _command.pick(at)
	if who < 0:
		return 0
	var species: String = (_cast.actor(who) as DemoActorScript).species
	var size: Vector2 = _command.get_viewport().get_visible_rect().size if _command.is_inside_tree() else Vector2.ZERO
	var count: int = _command.box_into(Vector2.ZERO, size, _box_hits)
	var kept := PackedInt32Array([who])
	for k: int in count:
		var other: int = _box_hits[k]
		if other != who and kept.size() < SIMILAR_CAP and (_cast.actor(other) as DemoActorScript).species == species:
			kept.append(other)
	kept.sort()
	_command.select(kept)
	_command.say(SIMILAR % [species, kept.size()])
	_refresh_in = 0.0
	return kept.size()


func put_on_crew(crew: int) -> int:
	"""Put every selected resident on `crew` (work_crews.gd `set_crew`) and say who joined; how many moved."""
	var crews: CrewsScript = _board.crews
	var members: PackedInt32Array = _command.selected()
	if not CrewsScript.is_crew(crew) or members.is_empty():
		return 0
	var words: String = crew_words(crew, members)
	var moved: int = 0
	for who: int in members:
		if crews.crew_of[who] != crew and crews.set_crew(who, crew):
			moved += 1
	_command.say(words)
	_refresh_in = 0.0
	return moved


func arm_send(on: bool) -> bool:
	"""Make the next left click on the world the group's destination (`on`, with two or more selected -- the group's own
	button -- on the surface: Underground gives its clicks to the tunnels, so there it says to right-click; the notice says
	so), or stop waiting (its prompt cleared). Whether it now waits."""
	var count: int = _command.selection_count()
	var below: bool = on and _command.underground_view()
	var was: bool = _armed
	_armed = on and count >= 2 and not below
	panel.set_armed(_armed)
	if _armed:
		_command.say(SEND_ARMED % count)
	elif below:
		_command.say(SEND_BELOW)
	elif was and not on:
		_command.say("")
	return _armed


func is_armed() -> bool:
	"""Whether Send to… waits for its click."""
	return _armed


func _on_tile(who: int, shift: bool) -> void:
	"""A member's tile: centre the view on it, the group kept -- or, Shift, drop it from the selection."""
	if not shift:
		if _centre.is_valid():
			var at: Vector2 = (_cast.actor(who) as DemoActorScript).brain.surface_point()
			_centre.call(Vector3(at.x, 0.0, at.y))
		return
	var members: PackedInt32Array = _command.selected()
	if members.has(who):
		members.remove_at(members.find(who))
	_command.select(members)
	if members.size() < 2:
		arm_send(false)
	_command.say(DROPPED % (_cast.actor(who) as DemoActorScript).display_name)
	_refresh_in = 0.0


# --- the words -------------------------------------------------------------------------------------------

func crew_words(crew: int, members: PackedInt32Array) -> String:
	"""What putting `members` on `crew` does: "Woods crew (prefers Woods; then Hauling, Building): Wenna, Jory join;
	Tobit already on it" -- or, all on it, that they are."""
	var joining := PackedStringArray()
	var staying := PackedStringArray()
	var names: PackedStringArray = _short_names(members)
	for k: int in members.size():
		if _board.crews.crew_of[members[k]] == crew:
			staying.append(names[k])
		else:
			joining.append(names[k])
	if joining.is_empty():
		return CREW_ALREADY % [members.size(), CrewsScript.CREW_NAMES[crew]]
	return CREW_JOIN % [CrewsScript.CREW_NAMES[crew], _board.crews.describe(crew), ", ".join(joining),
		"s" if joining.size() == 1 else "", "" if staying.is_empty() else CREW_STAYS % ", ".join(staying)]


func _short_names(members: PackedInt32Array) -> PackedStringArray:
	"""These residents' short names (short_names)."""
	var full := PackedStringArray()
	for who: int in members:
		full.append((_cast.actor(who) as DemoActorScript).display_name)
	return short_names(full)


static func short_names(full: PackedStringArray) -> PackedStringArray:
	"""Each name's first word ("Wenna Tallowby": "Wenna") -- or the whole name where another in the list shares that
	first word (two placeholders "Mouse keeper", "Mouse fieldworker" stay whole)."""
	var firsts := PackedStringArray()
	for name_full: String in full:
		firsts.append(name_full.get_slice(" ", 0))
	var out := PackedStringArray()
	for k: int in full.size():
		out.append(firsts[k] if firsts.count(firsts[k]) == 1 else full[k])
	return out


static func names_line(word: String, names: PackedStringArray) -> String:
	"""A status line: "Hungry ×2 — Tobit, Corra"."""
	return NAMES_LINE % [word, names.size(), ", ".join(names)]


static func tally(words: PackedStringArray) -> String:
	"""Each word with how many times it comes, most first, ties in first-seen order: "Field ×2 · Haulers ×1"."""
	var seen := PackedStringArray()
	var counts := PackedInt32Array()
	for word: String in words:
		var at: int = seen.find(word)
		if at < 0:
			seen.append(word)
			counts.append(1)
		else:
			counts[at] += 1
	var parts := PackedStringArray()
	for most: int in range(words.size(), 0, -1):
		for k: int in seen.size():
			if counts[k] == most:
				parts.append(TALLY % [seen[k], most])
	return " · ".join(parts)


static func tile_tag(warning: String, idle: bool, activity: String) -> String:
	"""A tile's tag: its first warning, else "Idle", else its activity's first word, capitalised ("walking to the well":
	"Walking")."""
	if not warning.is_empty():
		return warning
	if idle:
		return "Idle"
	return PanelScript.first_up(PanelScript.command_of(activity).get_slice(" ", 0))


# --- per frame and the refresh ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	"""The box's count while a box is dragged; the panel a few times a second, and at once when the selection moved."""
	if _command == null:
		return
	_follow_box()
	_refresh_in -= delta
	if _refresh_in > 0.0 and _command.selection_revision() == _seen_revision:
		return
	_refresh_in = REFRESH_S
	_seen_revision = _command.selection_revision()
	refresh()


func _follow_box() -> void:
	"""Show "Selecting residents: n" beside the box being dragged (re-worded only when n changes); hide it else."""
	var box: Rect2 = _command.drag_rect()
	if box.size == Vector2.ZERO:
		_box_frame.visible = false
		_box_count = -1
		return
	if _box_count < 0:
		_box_frame.scale = Vector2.ONE * hud_scale()
	var count: int = _command.box_into(box.position, box.end, _box_hits)
	if count != _box_count:
		_box_count = count
		_box_label.text = BOX_COUNT % count
		_box_frame.reset_size()
	_box_frame.position = label_at(box, _box_frame.size * _box_frame.scale, _command.get_viewport().get_visible_rect().size)
	_box_frame.visible = true


static func label_at(box: Rect2, label_size: Vector2, view: Vector2) -> Vector2:
	"""Where the box's count goes: just past the box's lower right corner, kept inside the view (a box dragged to the
	view's edge puts it inside the box's corner instead)."""
	var at: Vector2 = box.end + Vector2(BOX_LABEL_GAP, BOX_LABEL_GAP)
	return Vector2(clampf(at.x, 0.0, maxf(view.x - label_size.x, 0.0)), clampf(at.y, 0.0, maxf(view.y - label_size.y, 0.0)))


func hud_scale() -> float:
	"""The HUD's effective scale S now (UI §1.2, the interface scale included), as the party panel draws at: the box's
	count is drawn at it, read once a drag starts (never per frame)."""
	var size: Vector2 = _command.get_viewport().get_visible_rect().size if _command.is_inside_tree() else Vector2.ZERO
	PanelScript.placement(int(size.x), int(size.y), _layout, _geometry)
	return _geometry.scale


func box_label() -> Label:
	"""The box's count label (checks)."""
	return _box_label


func refresh() -> bool:
	"""Re-read the selection and the statuses; re-draw the panel only when what it shows changed. True when re-drawn."""
	var count: int = _command.selected_into(_members)
	if _armed and (count < 2 or _command.underground_view()):
		arm_send(false)
	var idle_count: int = statuses.members_into(statuses.find(GroupStatus.IDLE), _everyone, _idle)
	_sign(count)
	if _signature == _shown:
		return false
	_shown = _signature.duplicate()
	panel.show_idle(idle_count, ", ".join(_short_names(_idle)))
	_fill_view(count)
	panel.show_group(_view)
	return true


func _sign(count: int) -> void:
	"""The change check: the rows' revision, the idle, the group's slot, and per member its index, words, statuses and
	crew."""
	_signature.resize(0)
	_signature.append(statuses.revision)
	_signature.append(_idle.size())
	for who: int in _idle:
		_signature.append(who)
	_signature.append(groups.slot_holding(_members))
	if count < 2:
		return
	for who: int in _members:
		_signature.append(who)
		_signature.append(_command.activity_text(who).hash())
		_signature.append(statuses.bits_of(who))
		_signature.append(_board.crews.crew_of[who])


func _fill_view(count: int) -> void:
	"""What the group panel shows for the selection (see group_panel.gd)."""
	_view.shown = count >= 2
	if not _view.shown:
		return
	var states := PackedStringArray()
	var entries: Array[Dictionary] = []
	for who: int in _members:
		states.append(_command.activity_text(who))
		entries.append({"state": states[states.size() - 1]})
	_view.doing = DOING % PanelScript.activity_tally(entries)
	_fill_status_lines()
	_fill_tiles(states)
	_fill_crews()
	var slot: int = groups.slot_holding(_members)
	_view.group_line = GROUP_KEPT % [slot, slot, slot] if slot >= 0 else GROUP_KEYS


func _fill_status_lines() -> void:
	"""The warning and note lines (every row the members hold but Idle, in the rows' order) and the idle line."""
	_view.attention.resize(0)
	_view.notes.resize(0)
	_view.idle_line = IDLE_NOBODY
	for k: int in statuses.shown_order():
		if statuses.members_into(k, _members, _scratch) == 0:
			continue
		var line: String = names_line(statuses.word_of(k), _short_names(_scratch))
		if statuses.id_of(k) == GroupStatus.IDLE:
			_view.idle_line = line
		elif statuses.severity_of(k) == GroupStatus.SEVERITY_WARN:
			_view.attention.append(line)
		else:
			_view.notes.append(line)


func _fill_tiles(states: PackedStringArray) -> void:
	"""A tile per member: its index, colour, short name, tag, tooltip and whether it carries a warning."""
	var names: PackedStringArray = _short_names(_members)
	var idle_row: int = statuses.find(GroupStatus.IDLE)
	_view.index = _members.duplicate()
	_view.colour.resize(_members.size())
	_view.first_name = names
	_view.tag.resize(_members.size())
	_view.tip.resize(_members.size())
	_view.warn.resize(_members.size())
	for k: int in _members.size():
		var actor := _cast.actor(_members[k]) as DemoActorScript
		var warning: int = statuses.first_warning(_members[k])
		var word: String = statuses.word_of(warning)
		_view.colour[k] = actor.chip_colour
		_view.tag[k] = tile_tag(word, statuses.holds(idle_row, _members[k]), states[k])
		_view.warn[k] = 1 if warning >= 0 else 0
		_view.tip[k] = TILE_TIP % [actor.display_name, states[k], "" if word.is_empty() else " · " + word,
			CrewsScript.CREW_NAMES[_board.crews.crew_of[_members[k]]]]


func _fill_crews() -> void:
	"""The crew line ("Crews: Field ×2 · Haulers ×1 — put them all on:") and each crew button's card or why not."""
	var words := PackedStringArray()
	for who: int in _members:
		words.append(CrewsScript.CREW_NAMES[_board.crews.crew_of[who]])
	_view.crew_line = CREW_LINE % tally(words)
	_view.crew_tip.resize(CrewsScript.CREW_COUNT)
	_view.crew_why.resize(CrewsScript.CREW_COUNT)
	for crew: int in CrewsScript.CREW_COUNT:
		var all_on: bool = words.count(CrewsScript.CREW_NAMES[crew]) == words.size()
		_view.crew_tip[crew] = crew_words(crew, _members)
		_view.crew_why[crew] = _view.crew_tip[crew] if all_on else ""
