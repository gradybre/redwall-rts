extends CanvasLayer
## THE WORK SCREEN: the village's one authoritative view of its work (decision 0411, review F32 and P1's "Work /
## production" row; F22, SOC-004, UX-001/002/007). The HUD's Jobs command (UI-SET-029, J) opens it; DEMO UI in the
## woodland skin, in the HUD's modal rectangle above the HUD (as the Pantry), a modal of the input gate (Esc, J and its
## × close it; Tab and Enter work inside it -- decision 0261).
##
## THREE VIEWS of the work board (work_board.gd):
##   Tasks      every task of every source -- farm, woods, bridges, tunnels, rooms' fit-out, spoil heaps -- blocked
##              first, then under way, queued and paused: target and action, who, its state and why it waits (the
##              owners' own refusal words and the routing desk's "finding a route" / "can't reach it"), the work
##              left, and who means to come back to it; each with Go to, Pause / Resume, Cancel this task,
##              Reassign (a picker: every resident with its eligibility), priority up and down, Urgent.
##   Residents  the CREWS (work_crews.gd): each crew's preferred activity and fallbacks, its members with their status
##              (available, occupied, resting, absent), what each is doing now and its ORDER LIST (Now -> Next ->
##              then its routine; entries removable and movable), and buttons moving a member between crews. The
##              work PRESETS -- Normal, Harvest week, Winter stores -- above, each previewed (the changes it makes)
##              before it is applied.
##   Projects   the same tasks grouped by where they are: the farm, the woods, each bridge, each tunnel, each room.
## CANCEL ALL WORK stays separate and explicit: its button only shows its scope, counted per source, with Cancel them /
## Keep working; deliveries, paid tunnel jobs and bridges go on. An empty board says so ("No work waiting") with how to
## make some; while the village is paused the header says the work waits with it, so a paused village never reads as
## blocked labour.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const TaskRowScript := preload("res://demo/work/work_task_row.gd")
const ResidentRowScript := preload("res://demo/work/work_resident_row.gd")
const SourceScript := preload("res://demo/work/work_source.gd")

signal close_requested

const TITLE: String = "Work"
const VIEW_TASKS: int = 0
const VIEW_RESIDENTS: int = 1
const VIEW_PROJECTS: int = 2
const VIEW_NAMES: Array[String] = ["Tasks", "Residents and crews", "Projects"]
const EMPTY: String = "No work waiting. Order some: right-click a bed, a tree or a heap with residents selected, use a tunnel's or the Water panel's buttons, or plant from a bed's panel."
const PAUSED_NOTE: String = " · the village is paused: the work waits with it"
const CANCEL_ALL: String = "Cancel all work…"
const CANCEL_SCOPE: String = "Cancel all work: %d tasks — %s. Loads in hand are still delivered; deliveries, paid tunnel jobs and bridges go on."
const NOTHING_TO_CANCEL: String = "Nothing to cancel: every task here goes on (deliveries, paid tunnel jobs, bridges)."
const PRESET_HEAD: String = "Work preset:"
const PRESET_NOW: String = "In force: %s — %s. Hover or focus a preset to see what it would change."
const PRESET_CUSTOM_NOTE: String = "edited by hand since the last preset"
const CHANGED: String = "That task has changed since the list was drawn — look again."
const NOTE_PX: int = 14
const TARGET_PX: float = 32.0
const REFRESH_S: float = 0.25
const MIN_BODY_H: float = 150.0
## The order the Tasks view lists states in (blocked first; paused last).
const STATE_ORDER: Array[int] = [WorkIds.STATE_BLOCKED, WorkIds.STATE_WORKING, WorkIds.STATE_HAULING,
	WorkIds.STATE_TRAVELLING, WorkIds.STATE_ASSIGNED, WorkIds.STATE_QUEUED, WorkIds.STATE_PAUSED]
const LAYER: int = 2

var view: int = VIEW_TASKS

var _board: BoardScript = null
## `activity(who) -> String`: what a resident is doing now (demo_command.gd `activity_text`).
var _activity: Callable = Callable()
## `is_paused() -> bool`: the village's clock.
var _is_paused: Callable = Callable()
## `selection() -> PackedInt32Array`: who is selected.
var _selection: Callable = Callable()
var _frame: PanelContainer = null
var _summary: Label = null
var _cancel_all: Button = null
var _close: Button = null
var _confirm: VBoxContainer = null
var _confirm_text: Label = null
var _confirm_yes: Button = null
var _confirm_no: Button = null
var _tabs: Array[Button] = []
var _answer: Label = null
var _presets: VBoxContainer = null
var _preset_buttons: Array[Button] = []
var _preset_note: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _task_rows: Array[TaskRowScript] = []
var _resident_rows: Array[ResidentRowScript] = []
var _headers: Array[Label] = []
var _task: TaskScript = TaskScript.new()
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()
var _refresh_in: float = 0.0
## The tasks this refresh lists (source, row), their states, in listing order.
var _sources: PackedInt32Array = PackedInt32Array()
var _rows: PackedInt32Array = PackedInt32Array()
var _states: PackedInt32Array = PackedInt32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _members: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
## The preset whose preview shows (-1: none; the line says the preset in force).
var _previewing: int = -1


func configure(board: BoardScript, activity: Callable, is_paused: Callable) -> void:
	"""Show this board; `activity(who)` says what a resident is doing, `is_paused()` whether the village is. Built
	hidden."""
	_board = board
	_activity = activity
	_is_paused = is_paused
	layer = LAYER
	name = "WorkScreen"
	_build()
	visible = false


func set_readouts(activity: Callable, is_paused: Callable, selection: Callable = Callable()) -> void:
	"""`activity(who)` says what a resident is doing, `is_paused()` whether the village is, `selection()` who is selected
	(a group's preview under a Reassign picker, member by member -- UX-001)."""
	_activity = activity
	_is_paused = is_paused
	_selection = selection


func _selected() -> PackedInt32Array:
	"""Who is selected (none without a selection source)."""
	return _selection.call() if _selection.is_valid() else PackedInt32Array()


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""Header, the Cancel all strip, the view tabs, the answer line, the presets and the scrolling list."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_header())
	column.add_child(_build_confirm())
	column.add_child(_build_tabs())
	_answer = FarmUi.label("", NOTE_PX, Palette.UMBER)
	column.add_child(_answer)
	column.add_child(_build_presets())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = MIN_BODY_H
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	_scroll.add_child(_list)


func _header() -> HBoxContainer:
	"""Title, the counts, Cancel all work… and ×."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var title: Label = FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	_summary = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_summary)
	_cancel_all = FarmUi.button(CANCEL_ALL, NOTE_PX)
	_cancel_all.custom_minimum_size.y = TARGET_PX
	_cancel_all.tooltip_text = "Shows what it would cancel first; nothing is cancelled until you confirm"
	_cancel_all.pressed.connect(show_cancel_scope)
	row.add_child(_cancel_all)
	_close = FarmUi.button("×")
	_close.tooltip_text = "Close the Work screen (J or Esc)"
	_close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(_close)
	return row


func _build_confirm() -> VBoxContainer:
	"""Cancel all work's scope, the whole width, and its two answers under it (hidden until asked)."""
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override(&"separation", 4)
	_confirm_text = FarmUi.label("", NOTE_PX, Palette.CLAY)
	_confirm.add_child(_confirm_text)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override(&"separation", 8)
	_confirm_yes = FarmUi.button("Cancel them", NOTE_PX)
	_confirm_yes.custom_minimum_size.y = TARGET_PX
	_confirm_yes.pressed.connect(confirm_cancel_all)
	answers.add_child(_confirm_yes)
	_confirm_no = FarmUi.button("Keep working", NOTE_PX)
	_confirm_no.custom_minimum_size.y = TARGET_PX
	_confirm_no.pressed.connect(hide_cancel_scope)
	answers.add_child(_confirm_no)
	_confirm.add_child(answers)
	_confirm.visible = false
	return _confirm


func _build_tabs() -> HBoxContainer:
	"""The three views, one pressed at a time."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var group := ButtonGroup.new()
	for k: int in VIEW_NAMES.size():
		var made: Button = FarmUi.button(VIEW_NAMES[k])
		made.custom_minimum_size.y = TARGET_PX
		made.toggle_mode = true
		made.button_group = group
		made.button_pressed = k == view
		made.pressed.connect(show_view.bind(k))
		row.add_child(made)
		_tabs.append(made)
	return row


func _build_presets() -> VBoxContainer:
	"""The work presets, each previewed on hover and keyboard focus before it is applied: a row of buttons, and under it
	the preview (or the preset in force)."""
	_presets = VBoxContainer.new()
	_presets.add_theme_constant_override(&"separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var head: Label = FarmUi.label(PRESET_HEAD, NOTE_PX, Palette.INK, true)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(head)
	for k: int in CrewsScript.PRESET_COUNT:
		var made: Button = FarmUi.button(CrewsScript.PRESET_NAMES[k], NOTE_PX)
		made.custom_minimum_size.y = TARGET_PX
		made.pressed.connect(apply_preset.bind(k))
		made.focus_entered.connect(preview_preset.bind(k))
		made.mouse_entered.connect(preview_preset.bind(k))
		made.focus_exited.connect(end_preview)
		made.mouse_exited.connect(end_preview)
		row.add_child(made)
		_preset_buttons.append(made)
	_presets.add_child(row)
	_preset_note = FarmUi.label("", NOTE_PX, Palette.UMBER)
	_presets.add_child(_preset_note)
	_presets.visible = false
	return _presets


# --- opening, views and refresh ----------------------------------------------------------------------

func toggle() -> bool:
	"""Open or close; returns whether it is now open. It opens on the view it last showed, the answer line cleared."""
	visible = not visible
	if visible:
		_answer.text = ""
		_confirm.visible = false
		refresh()
	return visible


func open() -> void:
	"""Open (if closed)."""
	if not visible:
		toggle()


func close() -> void:
	"""Close (the gate's Esc, J and the ×)."""
	visible = false


func show_view(which: int) -> void:
	"""Show view `which` (VIEW_*)."""
	view = clampi(which, VIEW_TASKS, VIEW_PROJECTS)
	for k: int in _tabs.size():
		_tabs[k].set_pressed_no_signal(k == view)
	_presets.visible = view == VIEW_RESIDENTS
	refresh()


func _process(delta: float) -> void:
	"""While open, repaint a few times a second (percentages, states, who is where)."""
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_S
		refresh()


func refresh() -> void:
	"""Repaint the header and the current view, in place (pooled rows)."""
	if _board == null:
		return
	_collect()
	_summary.text = summary_text()
	for header: Label in _headers:
		header.visible = false
	for row: TaskRowScript in _task_rows:
		row.visible = false
	for row: ResidentRowScript in _resident_rows:
		row.visible = false
	if view == VIEW_RESIDENTS:
		_fill_residents()
	elif _sources.is_empty():
		_put_header(0, EMPTY)
	else:
		_fill_tasks(view == VIEW_PROJECTS)
	_place.call_deferred()


func _collect() -> void:
	"""Every live task (source, row) and its state, and the listing order: by state for Tasks, by source for
	Projects."""
	_sources.clear()
	_rows.clear()
	_states.clear()
	for id: int in WorkIds.SOURCE_COUNT:
		var src: SourceScript = _board.source(id)
		if src == null:
			continue
		for row: int in src.capacity():
			if _board.fill(id, row, _task):
				_sources.append(id)
				_rows.append(row)
				_states.append(_task.state)
	_order.clear()
	if view == VIEW_PROJECTS:
		for k: int in _sources.size():
			_order.append(k)
		return
	for state: int in STATE_ORDER:
		for k: int in _states.size():
			if _states[k] == state:
				_order.append(k)


func summary_text() -> String:
	"""'5 tasks: 1 blocked · 2 under way · 1 queued · 1 paused' (and the village's pause)."""
	if _sources.is_empty():
		return "No work waiting" + (PAUSED_NOTE if _paused() else "")
	var blocked: int = _states.count(WorkIds.STATE_BLOCKED)
	var queued: int = _states.count(WorkIds.STATE_QUEUED)
	var paused: int = _states.count(WorkIds.STATE_PAUSED)
	var active: int = _states.size() - blocked - queued - paused
	return "%d tasks: %d blocked · %d under way · %d queued · %d paused%s" % [_states.size(), blocked, active, queued,
		paused, PAUSED_NOTE if _paused() else ""]


func _paused() -> bool:
	"""Whether the village is paused."""
	return _is_paused.is_valid() and bool(_is_paused.call())


func _fill_tasks(by_project: bool) -> void:
	"""The task rows in `_order`; the Projects view puts each source's name over its tasks."""
	var at: int = 0
	var header: int = 0
	var last_source: int = -1
	for n: int in _order.size():
		var k: int = _order[n]
		if by_project and _sources[k] != last_source:
			last_source = _sources[k]
			_put_header(header, "%s — %d" % [WorkIds.SOURCE_NAMES[last_source], _sources.count(last_source)], at)
			header += 1
			at += 1
		_board.fill(_sources[k], _rows[k], _task)
		var row: TaskRowScript = _task_row(n)
		row.show_task(_task, _board)
		row.visible = true
		_list.move_child(row, at)
		at += 1


func _fill_residents() -> void:
	"""Each crew's header (its activities and members' count), then its members' rows."""
	var at: int = 0
	var shown: int = 0
	for crew: int in CrewsScript.CREW_COUNT:
		var count: int = _board.crews.members_into(crew, _members)
		_put_header(crew, "%s crew — %s · %d %s" % [CrewsScript.CREW_NAMES[crew], _board.crews.describe(crew), count,
			"member" if count == 1 else "members"], at)
		at += 1
		for who: int in _members:
			var row: ResidentRowScript = _resident_row(shown)
			row.show_resident(who, _board, String(_activity.call(who)) if _activity.is_valid() else "", _board.has_job(who))
			row.visible = true
			_list.move_child(row, at)
			at += 1
			shown += 1
	if _previewing >= 0:
		preview_preset(_previewing)
	else:
		_preset_note.text = preset_now_text()


func _put_header(k: int, text: String, at: int = 0) -> void:
	"""Show pooled header `k` with `text` at list place `at`."""
	while _headers.size() <= k:
		var made: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.LEAF, true)
		_list.add_child(made)
		_headers.append(made)
	_headers[k].text = text
	_headers[k].visible = true
	_list.move_child(_headers[k], at)


func _task_row(k: int) -> TaskRowScript:
	"""Pooled task row `k`."""
	while _task_rows.size() <= k:
		var made := TaskRowScript.new()
		made.command.connect(_on_task_command)
		_list.add_child(made)
		_task_rows.append(made)
	return _task_rows[k]


func _resident_row(k: int) -> ResidentRowScript:
	"""Pooled resident row `k`."""
	while _resident_rows.size() <= k:
		var made := ResidentRowScript.new()
		made.command.connect(_on_resident_command)
		_list.add_child(made)
		_resident_rows.append(made)
	return _resident_rows[k]


# --- commands --------------------------------------------------------------------------------------

func _on_task_command(row: Control, what: StringName, who: int) -> void:
	"""A task row's command: carried to the board for the task the row shows (if it is still that task)."""
	var task_row := row as TaskRowScript
	if not _board.fill(task_row.task_source, task_row.task_row, _task) or _task.key != task_row.task_key:
		say(CHANGED)
		refresh()
		return
	if what == &"pick":
		task_row.toggle_picker(_board)
		task_row.show_group(_board.members_words(task_row.task_source, task_row.task_row, _selected()))
		return
	say(run_task_command(task_row.task_source, task_row.task_row, what, who))
	if what == &"assign":
		task_row.close_picker()
	if what == &"go" and _answer.text.is_empty():
		close_requested.emit()
		return
	refresh()


func run_task_command(task_source: int, row: int, what: StringName, who: int) -> String:
	"""Run one task command on the board (`_task` holds its record); the answer in words ("" for a quiet success)."""
	match what:
		&"go":
			return "" if _board.jump(task_source, row) else "Nowhere to go to: its target has gone"
		&"pause":
			return _said("Resumed" if _task.paused else "Paused", _board.pause(task_source, row, not _task.paused))
		&"cancel":
			return _said("Cancelled", _board.cancel(task_source, row))
		&"assign":
			return _said("Given to %s" % _board.name_of(who), _board.reassign(task_source, row, who))
		&"up":
			_board.raise_priority(task_source, row, -1)
		&"down":
			_board.raise_priority(task_source, row, 1)
		&"urgent":
			_board.set_urgent(task_source, row, not _board.is_urgent(task_source, row))
	return ""


func _said(done: String, why: String) -> String:
	"""'Paused: Harvest — the carrot bed', or "Can't: <why>"."""
	if why.is_empty():
		return "%s: %s — %s" % [done, _task.action, _task.target]
	return "Can't: %s" % why


func _on_resident_command(row: Control, what: StringName, k: int) -> void:
	"""A resident row's command: its crew, its "Go to", or an order-list entry's."""
	var who: int = (row as ResidentRowScript).who
	match what:
		&"crew_back":
			_board.crews.step_crew(who, -1)
		&"crew_on":
			_board.crews.step_crew(who, 1)
		&"sooner":
			_board.move_entry(who, k, -1)
		&"later":
			_board.move_entry(who, k, 1)
		&"remove":
			_board.remove_entry(who, k)
		&"go":
			if _board.go_to_resident(who):
				close_requested.emit()
				return
	refresh()


func preset_now_text() -> String:
	"""The preset in force, in words."""
	var preset: int = _board.crews.preset
	var note: String = CrewsScript.PRESET_NOTES[preset] if preset < CrewsScript.PRESET_COUNT else PRESET_CUSTOM_NOTE
	return PRESET_NOW % [CrewsScript.PRESET_NAMES[preset], note]


func end_preview() -> void:
	"""The pointer or the focus left a preset: the line says the preset in force again."""
	_previewing = -1
	_preset_note.text = preset_now_text()


func preview_preset(which: int) -> void:
	"""Say what preset `which` would change, before it is applied (its button's tooltip says the same)."""
	_previewing = which
	var lines: PackedStringArray = _board.crews.preview_preset(which)
	var text: String = "%s — %s: %s" % [CrewsScript.PRESET_NAMES[which], CrewsScript.PRESET_NOTES[which],
		"no change from now" if lines.is_empty() else "; ".join(lines)]
	_preset_note.text = text
	_preset_buttons[which].tooltip_text = text


func apply_preset(which: int) -> void:
	"""Apply preset `which` to every crew."""
	var lines: PackedStringArray = _board.crews.preview_preset(which)
	_board.crews.apply_preset(which)
	say("Work preset: %s (%s)" % [CrewsScript.PRESET_NAMES[which], "no change" if lines.is_empty() else "; ".join(lines)])
	refresh()


func show_cancel_scope() -> void:
	"""CANCEL ALL WORK's first press: its scope, counted per source, and the two answers."""
	var total: int = _board.cancel_all_counts_into(_counts)
	if total == 0:
		say(NOTHING_TO_CANCEL)
		return
	var parts := PackedStringArray()
	for id: int in _counts.size():
		if _counts[id] > 0:
			parts.append("%s %d" % [WorkIds.SOURCE_NAMES[id], _counts[id]])
	_confirm_text.text = CANCEL_SCOPE % [total, ", ".join(parts)]
	_confirm.visible = true
	_confirm_no.grab_focus.call_deferred()
	_place.call_deferred()


func hide_cancel_scope() -> void:
	"""Keep working: the scope goes, nothing cancelled."""
	_confirm.visible = false
	_place.call_deferred()


func confirm_cancel_all() -> void:
	"""CANCEL ALL WORK, confirmed."""
	var done: int = _board.cancel_all()
	hide_cancel_scope()
	say("Cancelled %d tasks" % done)
	refresh()


func say(text: String) -> void:
	"""The answer line."""
	_answer.text = text


# --- placement and readouts -------------------------------------------------------------------------

func _place() -> void:
	"""The whole of the HUD's modal rectangle, at the HUD's scale: the header, tabs and lines above take what they need
	and the list scrolls in the rest. The full-width lines are given the frame's width outright: a wrapping label laid
	out before its container would otherwise wrap a word to a line and stretch the frame past the window."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var rect := Rect2(zone.position + Vector2(FarmUi.FRAME_EXPAND, FarmUi.FRAME_EXPAND),
		zone.size - Vector2(2.0, 2.0) * FarmUi.FRAME_EXPAND)
	var inner: float = rect.size.x - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2]
	for line: Label in [_answer, _confirm_text, _preset_note]:
		line.custom_minimum_size.x = inner
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = rect.position * _geometry.scale
	_frame.custom_minimum_size = rect.size
	_frame.size = rect.size


func close_button() -> Button:
	"""The header's × (the gate's last focus stop)."""
	return _close


func cancel_all_button() -> Button:
	"""Cancel all work… (checks)."""
	return _cancel_all


func confirm_buttons() -> Array[Button]:
	"""Cancel them, Keep working (checks)."""
	return [_confirm_yes, _confirm_no]


func tab_button(which: int) -> Button:
	"""View `which`'s tab (checks)."""
	return _tabs[which]


func preset_button(which: int) -> Button:
	"""Preset `which`'s button (checks)."""
	return _preset_buttons[which]


func task_rows_shown() -> Array[TaskRowScript]:
	"""The task rows showing, in list order (checks)."""
	var out: Array[TaskRowScript] = []
	for child: Node in _list.get_children():
		if child is TaskRowScript and (child as Control).visible:
			out.append(child as TaskRowScript)
	return out


func resident_rows_shown() -> Array[ResidentRowScript]:
	"""The resident rows showing, in list order (checks)."""
	var out: Array[ResidentRowScript] = []
	for child: Node in _list.get_children():
		if child is ResidentRowScript and (child as Control).visible:
			out.append(child as ResidentRowScript)
	return out


func answer() -> String:
	"""The answer line (checks)."""
	return _answer.text


func confirm_text() -> String:
	"""Cancel all work's scope line (checks; "" while hidden)."""
	return _confirm_text.text if _confirm.visible else ""


func frame_rect() -> Rect2:
	"""The frame's rectangle on screen (checks)."""
	return _frame.get_global_rect()
