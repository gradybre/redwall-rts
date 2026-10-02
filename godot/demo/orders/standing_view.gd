extends VBoxContainer
## THE STANDING ORDERS VIEW of the Work screen (decision 0711; work_screen.gd VIEW_ORDERS, behind the HUD's Jobs
## command, J -- no new key): what a standing order is, the ADD ROW (◀ good ▶ from the goods list, standing_kinds.gd
## `goods_into`; − amount +; Add order), the answer line, and one row per order (standing_row.gd): its target, the good
## now, its state (satisfied, working, blocked: why) and the work it has queued, with its edits, its switch and Remove.
## Repainted by the screen while it shows (four times a second): each order is OBSERVED (book `observe`: finished jobs
## let go, re-measured, nothing opened). DEMO UI.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const BookScript := preload("res://demo/orders/standing_orders.gd")
const RowScript := preload("res://demo/orders/standing_row.gd")
const Text := preload("res://demo/orders/standing_text.gd")
const Kinds := preload("res://demo/orders/standing_kinds.gd")

const NOTE_PX: int = 14
const TARGET_PX: float = 32.0
const GOOD_W: float = 120.0
const AMOUNT_W: float = 84.0
const EMPTY: String = "No standing orders yet: choose a good and an amount above, then Add order."
const CHANGED: String = "That order has changed since the list was drawn — look again."
const ADDED: String = "Added: %s. It is kept every game hour."

var _book: BookScript = null
var _board: BoardScript = null
var _task: TaskScript = TaskScript.new()
var _intro: Label = null
var _good_label: Label = null
var _amount_label: Label = null
var _prev: Button = null
var _next: Button = null
var _less: Button = null
var _more: Button = null
var _add: Button = null
var _answer: Label = null
var _empty: Label = null
var _rows_box: VBoxContainer = null
var _rows: Array[RowScript] = []
var _good_kinds: PackedInt32Array = PackedInt32Array()
var _good_items: PackedInt32Array = PackedInt32Array()
## The good the Add row offers (an index into the goods), and the amount it offers for it.
var _good: int = 0
var _amount: int = 0


func configure(book: BookScript, board: BoardScript) -> void:
	"""Show this book over this board; build the view."""
	_book = book
	_board = board
	name = "StandingOrdersView"
	Kinds.goods_into(_good_kinds, _good_items)
	_build()
	pick_good(0)


func _build() -> void:
	"""The intro, the Add row, the answer line, the empty note and the rows' box."""
	add_theme_constant_override(&"separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro = FarmUi.label(Text.intro(), NOTE_PX, Palette.UMBER)
	add_child(_intro)
	add_child(_build_add_row())
	_answer = FarmUi.label("", NOTE_PX, Palette.UMBER)
	add_child(_answer)
	_empty = FarmUi.label(EMPTY, FarmUi.BODY_PX, Palette.LEAF, true)
	add_child(_empty)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override(&"separation", 10)
	add_child(_rows_box)


func _build_add_row() -> HFlowContainer:
	"""'Add an order: ◀ planks ▶ − 20.0 U + Add order'."""
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 6)
	var head: Label = FarmUi.label("Add an order: keep", NOTE_PX, Palette.INK, true)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(head)
	_less = _button(row, "−", step_amount.bind(-1), "Less")
	_amount_label = _value_label(row, AMOUNT_W)
	_more = _button(row, "+", step_amount.bind(1), "More")
	var of: Label = FarmUi.label("of", NOTE_PX, Palette.INK, true)
	of.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(of)
	_prev = _button(row, "◀", pick_good.bind(-1), "The good before")
	_good_label = _value_label(row, GOOD_W)
	_next = _button(row, "▶", pick_good.bind(1), "The next good")
	_add = _button(row, "Add order", func() -> void: add_order(), "Add this standing order")
	return row


func _button(parent: Control, text: String, action: Callable, tip: String) -> Button:
	"""A button of the Add row."""
	var made: Button = FarmUi.button(text, NOTE_PX)
	made.custom_minimum_size = Vector2(TARGET_PX, TARGET_PX)
	made.tooltip_text = tip
	made.pressed.connect(action)
	parent.add_child(made)
	return made


func _value_label(parent: Control, width: float) -> Label:
	"""A centred readout of the Add row."""
	var made: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	made.autowrap_mode = TextServer.AUTOWRAP_OFF
	made.custom_minimum_size = Vector2(width, TARGET_PX)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(made)
	return made


# --- the Add row -----------------------------------------------------------------------------------

func pick_good(by: int) -> void:
	"""Step the offered good `by` places (0: just repaint), its amount reset to the kind's first amount."""
	_good = posmod(_good + by, _good_kinds.size())
	_amount = Kinds.FIRST_AMOUNT[_good_kinds[_good]]
	_paint_add_row()


func step_amount(by: int) -> void:
	"""Step the offered amount `by` of its kind's steps, within its bounds."""
	var kind: int = _good_kinds[_good]
	_amount = clampi(_amount + by * Kinds.STEP[kind], Kinds.STEP[kind], Kinds.MAX_AMOUNT[kind])
	_paint_add_row()


func offered() -> Vector3i:
	"""The good and amount the Add row offers: (kind, item, amount) (checks)."""
	return Vector3i(_good_kinds[_good], _good_items[_good], _amount)


func add_order() -> String:
	"""Add the offered order; the answer said and returned."""
	var why: String = _book.add(_good_kinds[_good], _good_items[_good], _amount)
	var said: String = why if not why.is_empty() else ADDED % _book.title_of(_book.last_added)
	say(said)
	refresh()
	return said


func _paint_add_row() -> void:
	"""The offered good and amount, and the buttons' limits."""
	var kind: int = _good_kinds[_good]
	_good_label.text = Kinds.good_name(kind, _good_items[_good])
	_amount_label.text = Kinds.amount_text(kind, _amount)
	FarmUi.set_enabled(_less, _amount > Kinds.STEP[kind], "it is at its least")
	FarmUi.set_enabled(_more, _amount < Kinds.MAX_AMOUNT[kind], "it is at its most")
	var why: String = "" if _book.find(kind, _good_items[_good]) < 0 else BookScript.REFUSE_SAME % _good_label.text
	if why.is_empty() and _book.count() >= BookScript.MAX_ORDERS:
		why = BookScript.REFUSE_FULL
	FarmUi.set_enabled(_add, why.is_empty(), why)
	if why.is_empty():
		_add.tooltip_text = "Add: %s" % Kinds.title(kind, _good_items[_good], _amount)


# --- the orders -------------------------------------------------------------------------------------

func refresh() -> void:
	"""Observe every order and repaint its row, in book order; the Add row's limits."""
	if _book == null:
		return
	var shown: int = 0
	for o: int in BookScript.MAX_ORDERS:
		if not _book.is_live(o):
			continue
		_book.observe(o)
		var row: RowScript = _row(shown)
		row.show_order(_book, o, _board, _task)
		row.visible = true
		shown += 1
	for k: int in range(shown, _rows.size()):
		_rows[k].visible = false
	_empty.visible = shown == 0
	_paint_add_row()


func _row(k: int) -> RowScript:
	"""Pooled order row `k`."""
	while _rows.size() <= k:
		var made := RowScript.new()
		made.command.connect(_on_command)
		_rows_box.add_child(made)
		_rows.append(made)
	return _rows[k]


func _on_command(row: Control, what: StringName) -> void:
	"""A row's command, for the order it shows (if it is still that order)."""
	var order_row := row as RowScript
	if not _book.is_live(order_row.order) or not order_row.shows(order_row.order, int(_book.serial[order_row.order])):
		say(CHANGED)
		refresh()
		return
	say(run_command(order_row.order, what))
	refresh()


func run_command(o: int, what: StringName) -> String:
	"""One order command on the book; the answer in words ("" for a quiet success)."""
	var title: String = _book.title_of(o)
	var why: String = ""
	match what:
		&"less":
			why = _book.step_amount(o, -1)
		&"more":
			why = _book.step_amount(o, 1)
		&"up":
			why = _book.set_priority(o, _book.priority[o] - 1)
		&"down":
			why = _book.set_priority(o, _book.priority[o] + 1)
		&"toggle":
			why = _book.set_enabled(o, _book.enabled[o] == 0)
		&"remove":
			why = _book.remove(o)
			return "Removed: %s (the work it queued goes on)" % title if why.is_empty() else "Can't: %s" % why
	return "" if why.is_empty() else "Can't: %s" % why


func say(text: String) -> void:
	"""The answer line."""
	_answer.text = text


func answer() -> String:
	"""The answer line (checks)."""
	return _answer.text


func rows_shown() -> Array[RowScript]:
	"""The order rows showing, in list order (checks)."""
	var out: Array[RowScript] = []
	for row: RowScript in _rows:
		if row.visible:
			out.append(row)
	return out


func add_button() -> Button:
	"""Add order (checks)."""
	return _add


func set_line_width(width: float) -> void:
	"""The wrapping lines' width (the screen gives them the frame's: see work_screen.gd `_place`)."""
	for line: Label in [_intro, _answer, _empty]:
		line.custom_minimum_size.x = width
