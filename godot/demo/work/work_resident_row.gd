extends VBoxContainer
## One resident on the Work screen's Residents view (decision 0411; review F22, SOC-004, UX-002): its name, crew and
## status (available, occupied, resting, absent), what it is doing now and its ORDER LIST (Now -> Next -> then its
## routine), with the list's entries removable and movable, and buttons that move it to the crew before or after its
## own. Reused (the screen pools rows): `show_resident` repaints it. DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const OrderList := preload("res://demo/work/order_list.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

## A command on this row: "crew_back", "crew_on", "go"; or on order-list entry `k`: "sooner", "later", "remove".
signal command(row: Control, what: StringName, k: int)

const NOTE_PX: int = 14
const TARGET_PX: float = 32.0
const NOW: String = "Now: %s"
const EMPTY_LIST: String = "Next: nothing queued — then its routine"

## The resident this row shows.
var who: int = -1

var _title: Label = null
var _now: Label = null
var _buttons: HFlowContainer = null
var _back: Button = null
var _on: Button = null
var _go: Button = null
var _list_note: Label = null
var _entries: VBoxContainer = null
var _entry_rows: Array[HBoxContainer] = []
var _items: PackedStringArray = PackedStringArray()


func _init() -> void:
	"""Build the row's lines, crew buttons and its order list's pool."""
	add_theme_constant_override(&"separation", 3)
	_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	add_child(_title)
	_now = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_now)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override(&"h_separation", 6)
	add_child(_buttons)
	_back = _button(_buttons, "◀ Crew", &"crew_back", -1)
	_on = _button(_buttons, "Crew ▶", &"crew_on", -1)
	_go = _button(_buttons, "Go to", &"go", -1)
	_list_note = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_list_note)
	_entries = VBoxContainer.new()
	_entries.add_theme_constant_override(&"separation", 2)
	add_child(_entries)


func _button(parent: Control, text: String, what: StringName, k: int) -> Button:
	"""A command button."""
	var made: Button = FarmUi.button(text, NOTE_PX)
	made.custom_minimum_size.y = TARGET_PX
	made.pressed.connect(func() -> void: command.emit(self, what, k))
	parent.add_child(made)
	return made


func show_resident(resident: int, board: BoardScript, now_words: String, has_job: bool) -> void:
	"""Paint the row for `resident`: `now_words` is what it is doing (the party panel's words), `has_job` whether it
	holds a job on some board."""
	who = resident
	var brain: BrainScript = board.brain_of(resident)
	var crews: CrewsScript = board.crews
	var crew: int = crews.crew_of[resident]
	var status: int = CrewsScript.status_of(brain, has_job)
	_title.text = "%s — %s crew · %s" % [board.label_of(resident), CrewsScript.CREW_NAMES[crew],
		CrewsScript.STATUS_NAMES[status]]
	_now.text = NOW % now_words
	_back.tooltip_text = "Move to the %s crew" % CrewsScript.CREW_NAMES[posmod(crew - 1, CrewsScript.CREW_COUNT)]
	_on.tooltip_text = "Move to the %s crew" % CrewsScript.CREW_NAMES[posmod(crew + 1, CrewsScript.CREW_COUNT)]
	OrderList.items_into(brain, _items)
	_list_note.text = EMPTY_LIST if _items.is_empty() else "%s → %s" % [OrderList.ribbon(_items), OrderList.THEN_ROUTINE]
	_show_entries(brain)


func _show_entries(brain: BrainScript) -> void:
	"""One line per order-list entry: its place and words, Sooner, Later, Remove."""
	while _entry_rows.size() < brain.queue_size():
		_entry_rows.append(_entry_row(_entry_rows.size()))
	for k: int in _entry_rows.size():
		var line: HBoxContainer = _entry_rows[k]
		line.visible = k < brain.queue_size()
		if not line.visible:
			continue
		(line.get_child(0) as Label).text = "%d. %s" % [k + 1, _items[k]]
		FarmUi.set_enabled(line.get_child(1) as Button, k > 0, "it is next already")
		FarmUi.set_enabled(line.get_child(2) as Button, k < brain.queue_size() - 1, "it is last already")


func _entry_row(k: int) -> HBoxContainer:
	"""A pooled order-list line for entry `k`."""
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 6)
	var words: Label = FarmUi.label("", NOTE_PX, Palette.INK)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	_button(line, "▲ Sooner", &"sooner", k)
	_button(line, "▼ Later", &"later", k)
	_button(line, "✕ Remove", &"remove", k)
	_entries.add_child(line)
	return line


func entry_button(k: int, what: StringName) -> Button:
	"""Order-list entry `k`'s Sooner, Later or Remove button (null when not built)."""
	if k < 0 or k >= _entry_rows.size():
		return null
	match what:
		&"sooner":
			return _entry_rows[k].get_child(1) as Button
		&"later":
			return _entry_rows[k].get_child(2) as Button
	return _entry_rows[k].get_child(3) as Button


func button_of(what: StringName) -> Button:
	"""The crew_back, crew_on or go button (checks)."""
	match what:
		&"crew_back":
			return _back
		&"crew_on":
			return _on
	return _go


func title() -> String:
	"""The row's first line (checks)."""
	return _title.text


func list_text() -> String:
	"""The row's order-list line (checks)."""
	return _list_note.text
