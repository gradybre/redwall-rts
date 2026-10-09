extends VBoxContainer
## One standing order on the Work screen's Standing orders view (decision 0711): its title (the good, the amount, the
## priority, on or off), its state with the good now and what is coming -- or why it is blocked -- and the work it has
## queued, with − / + Amount, ▲ / ▼ Priority, Switch off / on and Remove. A built-in order (the winter's Firewood) can
## only be switched; its other buttons are disabled saying why. Reused (the view pools rows): `show_order` repaints it.
## DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const BookScript := preload("res://demo/orders/standing_orders.gd")
const Text := preload("res://demo/orders/standing_text.gd")
const Kinds := preload("res://demo/orders/standing_kinds.gd")

## A command on the order this row shows: "less", "more", "up", "down", "toggle", "remove".
signal command(row: Control, what: StringName)

const NOTE_PX: int = 14
const TARGET_PX: float = 32.0
const BUILT_IN_WHY: String = "built in: the winter keeps it — switch it off or on"

## The order (book row) this row shows, and its serial when painted (a reused book row is another order).
var order: int = -1
var order_serial: int = -1

var _title: Label = null
var _state: Label = null
var _jobs: Label = null
var _less: Button = null
var _more: Button = null
var _up: Button = null
var _down: Button = null
var _toggle: Button = null
var _remove: Button = null


func _init() -> void:
	"""Build the row's three lines and its buttons."""
	add_theme_constant_override(&"separation", 3)
	_title = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	add_child(_title)
	_state = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_state)
	_jobs = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_jobs)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override(&"h_separation", 6)
	add_child(buttons)
	_less = _button(buttons, "− Amount", &"less")
	_more = _button(buttons, "+ Amount", &"more")
	_up = _button(buttons, "▲ Priority", &"up")
	_down = _button(buttons, "▼ Priority", &"down")
	_toggle = _button(buttons, "Switch off", &"toggle")
	_remove = _button(buttons, "✕ Remove", &"remove")


func _button(parent: Control, text: String, what: StringName) -> Button:
	"""A command button."""
	var made: Button = FarmUi.button(text, NOTE_PX)
	made.custom_minimum_size.y = TARGET_PX
	made.pressed.connect(func() -> void: command.emit(self, what))
	parent.add_child(made)
	return made


func show_order(book: BookScript, o: int, board: BoardScript, task: TaskScript) -> void:
	"""Paint the row for book row `o` (read through `task`, the view's reused record)."""
	order = o
	order_serial = int(book.serial[o])
	_title.text = Text.title_line(book, o)
	_state.text = Text.state_line(book, o)
	_state.add_theme_color_override(&"font_color", Palette.CLAY if book.state[o] == BookScript.STATE_BLOCKED
		else Palette.UMBER)
	_jobs.text = Text.job_lines(book, o, board, task)
	_toggle.text = "Switch off" if book.enabled[o] == 1 else "Switch on"
	_toggle.tooltip_text = "Off: it queues nothing (its work under way goes on)" if book.enabled[o] == 1 \
		else "On: it queues work whenever the good falls below its amount"
	var editable: bool = book.built_in[o] == 0
	var k: int = book.kind[o]
	var step: String = Kinds.target_text(k, Kinds.STEP[k], book.item[o]) if editable else ""
	FarmUi.set_enabled(_less, editable and book.amount[o] > Kinds.STEP[k], BUILT_IN_WHY if not editable
		else "it is at its least")
	FarmUi.set_enabled(_more, editable and book.amount[o] < Kinds.MAX_AMOUNT[k], BUILT_IN_WHY if not editable
		else "it is at its most")
	if not _less.disabled:
		_less.tooltip_text = "Keep %s less" % step
	if not _more.disabled:
		_more.tooltip_text = "Keep %s more" % step
	FarmUi.set_enabled(_up, editable and book.priority[o] > WorkIds.PRIORITY_HIGHEST, BUILT_IN_WHY if not editable
		else "it is Highest already")
	FarmUi.set_enabled(_down, editable and book.priority[o] < WorkIds.PRIORITY_LOW, BUILT_IN_WHY if not editable
		else "it is Low already")
	FarmUi.set_enabled(_remove, editable, BUILT_IN_WHY)


func shows(o: int, of_serial: int) -> bool:
	"""Whether this row last showed that very order."""
	return order == o and order_serial == of_serial


func button(what: StringName) -> Button:
	"""The row's button for `what` (checks)."""
	match what:
		&"less":
			return _less
		&"more":
			return _more
		&"up":
			return _up
		&"down":
			return _down
		&"toggle":
			return _toggle
	return _remove


func texts() -> PackedStringArray:
	"""The row's three lines (checks)."""
	return PackedStringArray([_title.text, _state.text, _jobs.text])
