extends RefCounted
## The standing orders' words (decision 0711): what an order's row on the Work screen says -- its title, its state with
## the good now and what is coming, why it is blocked, and the work it has queued. Pure functions of the book and the
## board, so the suite reads them without a scene. Presentation only.

const Kinds := preload("res://demo/orders/standing_kinds.gd")
const BookScript := preload("res://demo/orders/standing_orders.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const BUILT_IN: String = " (built in: the winter keeps it while wood is short of the twelve-day projection)"
const NO_WORK: String = "No work queued by it now."
const JOB_LINE: String = "· %s — %s: %s"
const NOBODY: String = "waiting for a free resident"


static func title_line(book: BookScript, o: int) -> String:
	"""'Keep 20 planks · priority Normal · On' (a built-in order says so)."""
	var words: String = "%s · priority %s · %s" % [book.title_of(o), WorkIds.PRIORITY_NAMES[book.priority[o]],
		"On" if book.enabled[o] == 1 else "Off"]
	return words + (BUILT_IN if book.built_in[o] == 1 else "")


static func have_text(book: BookScript, o: int) -> String:
	"""The good now and what its jobs will still bring: '12 planks in store, 2 planks coming', '2.4 days of meals
	ready'."""
	var k: int = book.kind[o]
	var item: int = book.item[o]
	var now: String = Kinds.amount_text(k, int(book.value[o]), item)
	now += " of meals ready" if Kinds.UNITS[k] == Kinds.UNIT_MILLI_DAYS else " in store"
	if k == Kinds.KIND_FIREWOOD:
		now += " (the projection: %s)" % Measures.need(Kinds.good_key(k, item), book.target_of(o))
	if book.committed[o] > 0:
		now += ", %s coming" % Kinds.amount_text(k, int(book.committed[o]), item)
	return now


static func state_line(book: BookScript, o: int) -> String:
	"""'Working: 12 planks in store, 2 planks coming — by sawing at the sawhorse (Woods)'; 'Blocked: <why>'; 'Satisfied: ...';
	'Off: nothing is queued for it'."""
	match book.state[o]:
		BookScript.STATE_OFF:
			return "Off: it queues nothing until it is switched on"
		BookScript.STATE_BLOCKED:
			return "Blocked: %s (%s)" % [book.reason[o], have_text(book, o)]
		BookScript.STATE_WORKING:
			return "Working: %s — by %s" % [have_text(book, o), Kinds.WORK_WORDS[book.kind[o]]]
	return "Satisfied: %s" % have_text(book, o)


static func job_lines(book: BookScript, o: int, board: BoardScript, task: TaskScript) -> String:
	"""Each job it holds: '· Saw planks — the sawhorse: Working (Wenna Tallowby)', one a line; or that there is none."""
	var lines := PackedStringArray()
	for k: int in BookScript.MAX_JOBS:
		var slot: int = o * BookScript.MAX_JOBS + k
		if book.job_source[slot] == BookScript.FREE or board == null:
			continue
		if not board.fill(book.job_source[slot], book.job_row[slot], task):
			continue
		var who: String = board.name_of(task.worker) if task.worker >= 0 else NOBODY
		lines.append(JOB_LINE % [task.action, task.target, "%s (%s)" % [WorkIds.STATE_NAMES[task.state], who]])
	return NO_WORK if lines.is_empty() else "\n".join(lines)


static func intro() -> String:
	"""The section's first line: what a standing order is."""
	return ("A standing order keeps a good stocked: when it falls below the amount the village queues the work itself, "
		+ "and stops once it is back up with a little over (so it does not start and stop at the line). Only a blocked "
		+ "order raises a notice.")
