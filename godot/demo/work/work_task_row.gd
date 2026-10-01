extends VBoxContainer
## One task on the Work screen (decision 0411, review F32): what it is and who has it, its phase and why it waits, the
## work left and who means to come back to it -- and its own commands: Go to, Pause / Resume, Cancel this task,
## Reassign (a picker of every resident, each with its eligibility in the one assignment grammar), priority up and
## down, Urgent. A disabled command says why in its tooltip. Reused (the screen pools rows): `show_task` repaints it.
## DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

## A command on this row: "go", "pause", "cancel", "pick", "up", "down", "urgent", "assign" (with the resident).
signal command(row: Control, what: StringName, who: int)

const NOTE_PX: int = 14
const TARGET_PX: float = 32.0
const LEFT: String = "%s left"
const DONE: String = "%d%% done"
const NOBODY_ON_IT: String = "nobody yet"
const URGENT_TAG: String = " · URGENT"
const PRIORITY_TAG: String = " · priority %s"
const PICK_HEAD: String = "Give it to:"
const PICK_NOTE: String = "the one picked is taken off what it is doing (that work is kept to come back to)"

## The task this row shows: source, row and key (a command checks the key still matches).
var task_source: int = -1
var task_row: int = -1
var task_key: int = 0

var _title: Label = null
var _detail: Label = null
var _buttons: HFlowContainer = null
var _go: Button = null
var _pause: Button = null
var _cancel: Button = null
var _pick: Button = null
var _up: Button = null
var _down: Button = null
var _urgent: Button = null
var _picker: HFlowContainer = null
var _picker_note: Label = null
var _who: Array[Button] = []
## The selection's preview, member by member, under the picker ("" with fewer than two selected).
var _group: String = ""


func _init() -> void:
	"""Build the row's lines, buttons and its (hidden) Reassign picker."""
	add_theme_constant_override(&"separation", 3)
	_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	add_child(_title)
	_detail = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_detail)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override(&"h_separation", 6)
	_buttons.add_theme_constant_override(&"v_separation", 4)
	add_child(_buttons)
	_go = _button("Go to", &"go")
	_pause = _button("Pause", &"pause")
	_cancel = _button("Cancel this task", &"cancel")
	_pick = _button("Reassign…", &"pick")
	_up = _button("▲ Priority", &"up")
	_down = _button("▼ Priority", &"down")
	_urgent = _button("Urgent", &"urgent")
	_picker = HFlowContainer.new()
	_picker.add_theme_constant_override(&"h_separation", 6)
	_picker.visible = false
	add_child(_picker)
	_picker_note = FarmUi.label("", NOTE_PX, Palette.UMBER)
	_picker_note.visible = false
	add_child(_picker_note)


func _button(text: String, what: StringName) -> Button:
	"""A command button on the row."""
	var made: Button = FarmUi.button(text, NOTE_PX)
	made.custom_minimum_size.y = TARGET_PX
	made.pressed.connect(func() -> void: command.emit(self, what, -1))
	_buttons.add_child(made)
	return made


func show_task(task: TaskScript, board: BoardScript) -> void:
	"""Paint the row for `task` (its record just filled) and its commands' states."""
	task_source = task.source
	task_row = task.row
	task_key = task.key
	_title.text = title_text(task, board)
	_detail.text = detail_text(task, board)
	_enable(_go, task.point != Vector2.ZERO or task.target_kind != 0, "")
	_pause.text = "Resume" if task.paused else "Pause"
	_enable(_pause, task.pause_refusal.is_empty(), task.pause_refusal)
	_enable(_cancel, task.cancel_refusal.is_empty(), task.cancel_refusal)
	_enable(_pick, task.reassign_refusal.is_empty(), task.reassign_refusal)
	var priority: int = board.task_priority(task.source, task.row)
	_enable(_up, priority > WorkIds.PRIORITY_HIGHEST, "it is at the highest priority already")
	_enable(_down, priority < WorkIds.PRIORITY_LOW, "it is at the lowest priority already")
	_urgent.text = "Not urgent" if board.is_urgent(task.source, task.row) else "Urgent"
	if _picker.visible:
		show_picker(board, true)


static func title_text(task: TaskScript, board: BoardScript) -> String:
	"""'Harvest — the carrot bed · Mouse fieldworker · priority high'."""
	var who: String = board.name_of(task.worker) if task.worker >= 0 else NOBODY_ON_IT
	var tag: String = ""
	if board.is_urgent(task.source, task.row):
		tag = URGENT_TAG
	elif board.task_priority(task.source, task.row) != WorkIds.PRIORITY_NORMAL:
		tag = PRIORITY_TAG % WorkIds.PRIORITY_NAMES[board.task_priority(task.source, task.row)].to_lower()
	return "%s — %s · %s%s" % [task.action, task.target, who, tag]


static func detail_text(task: TaskScript, board: BoardScript) -> String:
	"""'Working 40% · about 1.2 game hours left · Mouse keeper comes back to it (next)' -- the state, why it waits,
	the work left and the resume intent."""
	var parts := PackedStringArray()
	var state: String = WorkIds.STATE_NAMES[task.state]
	if task.percent >= 0 and task.state == WorkIds.STATE_WORKING:
		state += " %d%%" % task.percent
	if not task.reason.is_empty():
		state += ": " + task.reason
	parts.append(state)
	if task.remaining_usec >= 0:
		parts.append(LEFT % CardScript.hours_text(task.remaining_usec))
	elif task.percent >= 0:
		parts.append(DONE % task.percent)
	var intent: String = board.resume_words(task.source, task.key)
	if not intent.is_empty():
		parts.append(intent)
	return " · ".join(parts)


static func _enable(button: Button, enabled: bool, why: String) -> void:
	"""Enable a command, or disable it saying why (its tooltip, read on hover and on keyboard focus)."""
	FarmUi.set_enabled(button, enabled, why)


func toggle_picker(board: BoardScript) -> void:
	"""Open or close the Reassign picker."""
	_picker.visible = not _picker.visible
	_picker_note.visible = _picker.visible
	if _picker.visible:
		show_picker(board, false)


func picker_open() -> bool:
	"""Whether the Reassign picker shows."""
	return _picker.visible


func show_picker(board: BoardScript, keep_focus: bool) -> void:
	"""Every resident as a button: enabled when it could take the task now, else disabled saying why (the board's
	`eligibility_words`, the one grammar a group order's preview uses too)."""
	while _who.size() < board.resident_count():
		var who: int = _who.size()
		var made: Button = FarmUi.button("", NOTE_PX)
		made.custom_minimum_size.y = TARGET_PX
		made.pressed.connect(func() -> void: command.emit(self, &"assign", who))
		_picker.add_child(made)
		_who.append(made)
	for who: int in _who.size():
		var why: String = board.eligibility_words(task_source, task_row, who)
		_who[who].text = board.name_of(who)
		_enable(_who[who], why.is_empty(), why)
	_picker_note.text = "%s %s%s" % [PICK_HEAD, PICK_NOTE, "\n" + _group if not _group.is_empty() else ""]
	if not keep_focus and not _who.is_empty():
		_who[0].grab_focus.call_deferred()


func show_group(words: String) -> void:
	"""The selection's eligibility for this task, member by member (the board's `members_words`), under the picker."""
	_group = words
	if _picker.visible:
		_picker_note.text = "%s %s%s" % [PICK_HEAD, PICK_NOTE, "\n" + _group if not _group.is_empty() else ""]


func close_picker() -> void:
	"""Close the Reassign picker."""
	_picker.visible = false
	_picker_note.visible = false


func button_of(what: StringName) -> Button:
	"""A command's button (checks): go, pause, cancel, pick, up, down, urgent."""
	match what:
		&"go":
			return _go
		&"pause":
			return _pause
		&"cancel":
			return _cancel
		&"pick":
			return _pick
		&"up":
			return _up
		&"down":
			return _down
	return _urgent


func resident_button(who: int) -> Button:
	"""The Reassign picker's button for resident `who` (null before the picker was opened)."""
	return _who[who] if who >= 0 and who < _who.size() else null


func title() -> String:
	"""The row's first line (checks)."""
	return _title.text


func detail() -> String:
	"""The row's second line (checks)."""
	return _detail.text
