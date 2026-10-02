extends RefCounted
## THE STANDING ORDERS (decision 0711; feature #38, approved by Brendan 2026-10-01): goals the player sets -- "keep 20 U
## of planks", "keep 3 days of meals" -- for which the village queues the work itself, so the player manages goals
## rather than tasks. Presentation only: the demo's jobs, never the simulation's. Session only (the demo cannot save).
##
## AN ORDER is a row of packed columns (MAX_ORDERS rows, sized once): its KIND and ITEM (the good, standing_kinds.gd),
## its AMOUNT (milli-U or milli-days), its PRIORITY (REQ-SET-026's 1..4), ON or off, and what it holds: up to MAX_JOBS
## jobs it queued on the owners' boards (source, row and the job's serial -- a reused row is another job). Each kind's
## GOAL (order_goal.gd) measures the good and opens the work: GDD REQ-SET-097's MAINTAIN_STOCK with "an explicit
## target", the demo's form of it.
##
## KEEPING AN ORDER (`keep`), on the game hour (`on_hour`) and at once when the player changes it:
##   1. its jobs no longer on their board are let go (done, cancelled);
##   2. the good is MEASURED, and what its jobs will still bring in is added up (REQ-SET-098: "count unreserved
##      inventory plus committed in-progress outputs against the target before issuing another batch");
##   3. THE LATCH (hysteresis): the order starts WORKING when the good falls BELOW its amount, and is SATISFIED again
##      only once the good reaches the amount plus its kind's BAND -- so it does not flap at the line;
##   4. while working it opens jobs, one at a time, while the good plus the committed output is under the amount plus
##      the band and it holds fewer than its kind's jobs; a job it opens takes the order's PRIORITY on the work board
##      (a job it adopts that the player gave a priority of its own keeps it);
##   5. its jobs are marked URGENT -- the board's bucket 2, systems_architecture.md's food/fuel bucket -- while its goal
##      says the reserve is short (fuel-days or food-days under two: REQ-SET-113), written only when that changes, so a
##      mark the player sets on a task holds in between (decision 0571's rule).
## A goal with its OWN RULE (the winter's Firewood, decision 0571) says itself whether work is wanted, holds one job, and
## is kept by its owner on its owner's hour (BUILT IN: listed, switched on or off, never edited or removed).
##
## STATE: OFF; SATISFIED; WORKING (it holds jobs, or is about to); BLOCKED -- working, but it could open no job and
## holds none (the goal's words: "not enough wood to saw ..."), or every job it holds is blocked on the board (the
## board's words). An order that becomes blocked RAISES A NOTICE (an incident, `set_reporter`), resolved when it is not
## blocked any more; NOTHING else an order does is announced. The winter's Firewood raises none: the winter's own fuel
## incidents speak for it.
##
## Removing an order, or switching it off, leaves the jobs it queued on the board as they are (the player's Work
## screen can cancel them): work in hand is never thrown away by a change of goal.

const Kinds := preload("res://demo/orders/standing_kinds.gd")
const GoalScript := preload("res://demo/orders/order_goal.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")

const MAX_ORDERS: int = 12
## The most jobs any kind holds (standing_kinds.gd MAX_JOBS).
const MAX_JOBS: int = 3
const FREE: int = -1
const UNWRITTEN: int = 2
const STATE_OFF: int = 0
const STATE_SATISFIED: int = 1
const STATE_WORKING: int = 2
const STATE_BLOCKED: int = 3
const STATE_NAMES: Array[String] = ["Off", "Satisfied", "Working", "Blocked"]
## The incidents' states the notice's watch answers.
const INCIDENT_OPEN: int = IncidentsScript.STATE_NEEDS_DECISION
const INCIDENT_RESOLVED: int = IncidentsScript.STATE_RESOLVED
const KEY_BLOCKED: String = "orders:blocked:%d"
const NOTICE: String = "Standing order blocked: %s — %s."
const REFUSE_FULL: String = "Twelve standing orders already: remove one first."
const REFUSE_SAME: String = "An order already keeps %s: change its amount instead."
const REFUSE_KIND: String = "That cannot be kept by a standing order."
const REFUSE_AMOUNT: String = "The amount must be above zero and at most %s."
const REFUSE_NO_GOAL: String = "Nothing in this village can make %s."
const REFUSE_BUILT_IN: String = "The winter keeps its Firewood order itself: it can only be switched off or on."
const REFUSE_NO_ORDER: String = "That order is no longer there."
const REFUSE_PRIORITY: String = "Priority runs from 1 (highest) to 4 (low)."

var kind: PackedInt32Array = PackedInt32Array()
var item: PackedInt32Array = PackedInt32Array()
var amount: PackedInt64Array = PackedInt64Array()
var priority: PackedInt32Array = PackedInt32Array()
var enabled: PackedByteArray = PackedByteArray()
var built_in: PackedByteArray = PackedByteArray()
var latch: PackedByteArray = PackedByteArray()
var state: PackedInt32Array = PackedInt32Array()
var value: PackedInt64Array = PackedInt64Array()
var committed: PackedInt64Array = PackedInt64Array()
## The order's identity for its whole life (never reused): the notice's key.
var serial: PackedInt64Array = PackedInt64Array()
var reason: PackedStringArray = PackedStringArray()
var notified: PackedByteArray = PackedByteArray()
## Its jobs, order-major (MAX_JOBS slots an order): the board source, the owner's row, its serial; FREE when empty.
var job_source: PackedInt32Array = PackedInt32Array()
var job_row: PackedInt32Array = PackedInt32Array()
var job_key: PackedInt64Array = PackedInt64Array()
## The urgency last written on the board for the job (0, 1; UNWRITTEN for a job not yet marked).
var job_urgent: PackedByteArray = PackedByteArray()
## Bumped on every change the Work screen shows.
var revision: int = 0
## The row the last successful `add` filled.
var last_added: int = -1

var _goals: Array[GoalScript] = []
var _board: BoardScript = null
## `report(key, text, watch)`: an incident (demo_incidents.gd `report`, bound by the owner).
var _report: Callable = Callable()
var _next_serial: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _task: TaskScript = TaskScript.new()


func _init() -> void:
	"""Size every column once; every row free."""
	for column: PackedInt32Array in [kind, item, priority, state]:
		column.resize(MAX_ORDERS)
	for column: PackedInt64Array in [amount, value, committed, serial]:
		column.resize(MAX_ORDERS)
	for column: PackedByteArray in [enabled, built_in, latch, notified]:
		column.resize(MAX_ORDERS)
	reason.resize(MAX_ORDERS)
	kind.fill(FREE)
	job_source.resize(MAX_ORDERS * MAX_JOBS)
	job_row.resize(MAX_ORDERS * MAX_JOBS)
	job_key.resize(MAX_ORDERS * MAX_JOBS)
	job_urgent.resize(MAX_ORDERS * MAX_JOBS)
	job_source.fill(FREE)
	_goals.resize(Kinds.KIND_COUNT)


func bind_board(board: BoardScript) -> void:
	"""The work board its jobs' priority and urgency are written on (null: none)."""
	_board = board


func set_goal(goal: GoalScript) -> void:
	"""The goal for its kind (one per kind)."""
	_goals[goal.kind] = goal


func goal_of(of_kind: int) -> GoalScript:
	"""The goal bound for a kind (null: none)."""
	return _goals[of_kind] if Kinds.is_kind(of_kind) else null


func set_reporter(report: Callable) -> void:
	"""`report(key, text, watch)`: how a blocked order raises its notice."""
	_report = report


func is_live(o: int) -> bool:
	"""Whether row `o` holds an order."""
	return o >= 0 and o < MAX_ORDERS and kind[o] != FREE


func count() -> int:
	"""How many orders there are."""
	return MAX_ORDERS - kind.count(FREE)


func find(of_kind: int, of_item: int) -> int:
	"""The order keeping that good (-1: none)."""
	for o: int in MAX_ORDERS:
		if kind[o] == of_kind and item[o] == of_item:
			return o
	return -1


# --- the player's changes ------------------------------------------------------------------------------------

func add(of_kind: int, of_item: int, of_amount: int, of_priority: int = WorkIds.PRIORITY_NORMAL) -> String:
	"""A new order ("" when added: `last_added` is its row, kept at once), else why not."""
	var why: String = _add_refusal(of_kind, of_item, of_amount)
	if not why.is_empty():
		return why
	var o: int = _open(of_kind, of_item, of_amount, clampi(of_priority, WorkIds.PRIORITY_HIGHEST, WorkIds.PRIORITY_LOW))
	last_added = o
	keep(o)
	return ""


func _add_refusal(of_kind: int, of_item: int, of_amount: int) -> String:
	"""Why an order for that good and amount cannot be added ("" when it can)."""
	if not Kinds.addable(of_kind) or (of_kind == Kinds.KIND_CROP) != (of_item >= 0):
		return REFUSE_KIND
	if _goals[of_kind] == null:
		return REFUSE_NO_GOAL % Kinds.good_name(of_kind, of_item)
	if find(of_kind, of_item) >= 0:
		return REFUSE_SAME % Kinds.good_name(of_kind, of_item)
	if count() >= MAX_ORDERS:
		return REFUSE_FULL
	return _amount_refusal(of_kind, of_amount)


func _amount_refusal(of_kind: int, of_amount: int) -> String:
	"""Why `of_amount` is no amount for the kind ("" when it is)."""
	if of_amount <= 0 or of_amount > Kinds.MAX_AMOUNT[of_kind]:
		return REFUSE_AMOUNT % Kinds.amount_text(of_kind, Kinds.MAX_AMOUNT[of_kind])
	return ""


func _open(of_kind: int, of_item: int, of_amount: int, of_priority: int) -> int:
	"""Fill the first free row: on, not yet working, no jobs."""
	var o: int = kind.find(FREE)
	kind[o] = of_kind
	item[o] = of_item
	amount[o] = of_amount
	priority[o] = of_priority
	enabled[o] = 1
	built_in[o] = 0
	latch[o] = 0
	state[o] = STATE_SATISFIED
	value[o] = 0
	committed[o] = 0
	reason[o] = ""
	notified[o] = 0
	_next_serial += 1
	serial[o] = _next_serial
	for k: int in MAX_JOBS:
		job_source[o * MAX_JOBS + k] = FREE
	revision += 1
	return o


func add_builtin(goal: GoalScript) -> int:
	"""A BUILT-IN order for a goal with its own rule (the winter's Firewood): kept by its owner (`keep`), listed, only
	switched off or on. Its row (-1: no free row)."""
	set_goal(goal)
	if count() >= MAX_ORDERS:
		return -1
	var o: int = _open(goal.kind, Kinds.NO_ITEM, 0, WorkIds.PRIORITY_NORMAL)
	built_in[o] = 1
	return o


func remove(o: int) -> String:
	"""Remove order `o` ("" when done): the jobs it queued stay on the board as they are (see the header)."""
	if not is_live(o):
		return REFUSE_NO_ORDER
	if built_in[o] == 1:
		return REFUSE_BUILT_IN
	kind[o] = FREE
	item[o] = FREE
	for k: int in MAX_JOBS:
		job_source[o * MAX_JOBS + k] = FREE
	revision += 1
	return ""


func set_amount(o: int, of_amount: int) -> String:
	"""Change order `o`'s amount ("" when done; kept at once)."""
	if not is_live(o):
		return REFUSE_NO_ORDER
	if built_in[o] == 1:
		return REFUSE_BUILT_IN
	var why: String = _amount_refusal(kind[o], of_amount)
	if not why.is_empty():
		return why
	amount[o] = of_amount
	revision += 1
	keep(o)
	return ""


func step_amount(o: int, steps: int) -> String:
	"""Move order `o`'s amount by `steps` of its kind's step (the − and + buttons), kept within its bounds."""
	if not is_live(o):
		return REFUSE_NO_ORDER
	if built_in[o] == 1:
		return REFUSE_BUILT_IN
	var step: int = Kinds.STEP[kind[o]]
	return set_amount(o, clampi(int(amount[o]) + steps * step, step, Kinds.MAX_AMOUNT[kind[o]]))


func set_priority(o: int, of_priority: int) -> String:
	"""Change order `o`'s priority (1..4); its live jobs still at the order's old priority take the new one now (a task
	the player has set otherwise keeps its own)."""
	if not is_live(o):
		return REFUSE_NO_ORDER
	if built_in[o] == 1:
		return REFUSE_BUILT_IN
	if of_priority < WorkIds.PRIORITY_HIGHEST or of_priority > WorkIds.PRIORITY_LOW:
		return REFUSE_PRIORITY
	var was: int = priority[o]
	priority[o] = of_priority
	if _goals[kind[o]] != null:
		_prune(o, _goals[kind[o]])
	for k: int in MAX_JOBS:
		if job_source[o * MAX_JOBS + k] != FREE:
			_write_priority(o, k, was)
	revision += 1
	return ""


func set_enabled(o: int, on: bool) -> String:
	"""Switch order `o` on (kept at once) or off ("" when done)."""
	if not is_live(o):
		return REFUSE_NO_ORDER
	enabled[o] = 1 if on else 0
	latch[o] = 0
	revision += 1
	keep(o)
	return ""


# --- keeping (see KEEPING AN ORDER) ---------------------------------------------------------------------------

func on_hour() -> void:
	"""The game hour: keep every order but the built-in ones (their owners keep them on their own hour)."""
	for o: int in MAX_ORDERS:
		if kind[o] != FREE and built_in[o] == 0:
			keep(o)


func keep(o: int) -> void:
	"""KEEP order `o` (see the header): let go of finished jobs, measure, latch, open what is wanted, mark urgency,
	settle its state and its notice."""
	if not is_live(o) or _goals[kind[o]] == null:
		return
	var goal: GoalScript = _goals[kind[o]]
	_prune(o, goal)
	_measure(o, goal)
	if enabled[o] == 0:
		_settle(o, "")
		return
	latch[o] = 1 if _wanted(o, goal) else 0
	var refusal: String = _raise(o, goal) if latch[o] == 1 else ""
	_mark_urgency(o, goal)
	_settle(o, refusal)


func observe(o: int) -> void:
	"""Re-read order `o` without opening anything or moving its latch (the Work screen's repaint): finished jobs let go,
	the good and the committed output measured, the state settled."""
	if not is_live(o) or _goals[kind[o]] == null:
		return
	var goal: GoalScript = _goals[kind[o]]
	_prune(o, goal)
	_measure(o, goal)
	_settle(o, reason[o] if state[o] == STATE_BLOCKED else "")


func _measure(o: int, goal: GoalScript) -> void:
	"""The good now, and what its jobs will still bring (REQ-SET-098)."""
	value[o] = goal.measure(item[o])
	var total: int = 0
	for k: int in MAX_JOBS:
		var slot: int = o * MAX_JOBS + k
		if job_source[slot] != FREE:
			total += goal.output_of(job_row[slot], item[o])
	committed[o] = total


func _wanted(o: int, goal: GoalScript) -> bool:
	"""THE LATCH: on below the amount, off at the amount plus the band, else as it was; a goal's own rule instead."""
	if goal.own_rule():
		return goal.wanted(item[o])
	if value[o] < amount[o]:
		return true
	if value[o] >= amount[o] + Kinds.BAND[kind[o]]:
		return false
	return latch[o] == 1


func _needs_more(o: int, goal: GoalScript) -> bool:
	"""Whether another job is wanted: room for one, and (by amount) the good plus the committed output short of the
	amount plus the band."""
	if jobs_of(o) >= Kinds.MAX_JOBS[kind[o]]:
		return false
	if goal.own_rule():
		return true
	return value[o] + committed[o] < amount[o] + Kinds.BAND[kind[o]]


func _raise(o: int, goal: GoalScript) -> String:
	"""Open jobs while more are wanted; the goal's refusal when it could not ("" otherwise)."""
	for _attempt: int in MAX_JOBS:
		if not _needs_more(o, goal):
			return ""
		var why: String = goal.raise_into(item[o], tracked, _read)
		if not why.is_empty():
			return why
		_adopt(o, goal, _read.value)
		_measure(o, goal)
	return ""


func _adopt(o: int, goal: GoalScript, row: int) -> void:
	"""Hold the job on `row`: its slot, its serial, its urgency not yet written, and the order's priority on the board
	(a task the player has given a priority of its own keeps it: `_write_priority`)."""
	for k: int in MAX_JOBS:
		var slot: int = o * MAX_JOBS + k
		if job_source[slot] != FREE:
			continue
		job_source[slot] = goal.source
		job_row[slot] = row
		job_key[slot] = goal.key_of(row)
		job_urgent[slot] = UNWRITTEN
		_write_priority(o, k, WorkIds.PRIORITY_NORMAL)
		revision += 1
		return


func _write_priority(o: int, k: int, was: int) -> void:
	"""The order's priority on job slot `k`'s task -- only while the task is at `was`, the priority the order left it at
	(NORMAL for a job it has just taken), so a priority the player gave the task holds; a NORMAL order writes nothing on
	a NORMAL task."""
	var slot: int = o * MAX_JOBS + k
	if _board == null:
		return
	var now: int = _board.task_priority(job_source[slot], job_row[slot])
	if now == was and now != priority[o]:
		_board.set_task_priority(job_source[slot], job_row[slot], priority[o])


func _prune(o: int, goal: GoalScript) -> void:
	"""Let go of every job no longer on its board (the same serial)."""
	for k: int in MAX_JOBS:
		var slot: int = o * MAX_JOBS + k
		if job_source[slot] != FREE and not goal.live(job_row[slot], job_key[slot]):
			job_source[slot] = FREE
			revision += 1


func _mark_urgency(o: int, goal: GoalScript) -> void:
	"""Each job URGENT while the goal says the reserve is short, written only when it changes (see the header). A job
	taken while the reserve is not short is not written at all: a mark the player set on it (an adopted harvest) holds."""
	if _board == null:
		return
	var urgent: int = 1 if goal.urgent(item[o]) else 0
	for k: int in MAX_JOBS:
		var slot: int = o * MAX_JOBS + k
		if job_source[slot] == FREE or job_urgent[slot] == urgent:
			continue
		if job_urgent[slot] != UNWRITTEN or urgent == 1:
			_board.set_urgent(job_source[slot], job_row[slot], urgent == 1)
		job_urgent[slot] = urgent


func tracked(of_source: int, of_key: int) -> bool:
	"""Whether some order holds the job (source, serial)."""
	for slot: int in job_source.size():
		if job_source[slot] == of_source and job_key[slot] == of_key:
			return true
	return false


func jobs_of(o: int) -> int:
	"""How many jobs order `o` holds."""
	var n: int = 0
	for k: int in MAX_JOBS:
		n += 1 if job_source[o * MAX_JOBS + k] != FREE else 0
	return n


# --- the state and its notice (see STATE) -----------------------------------------------------------------

func _settle(o: int, refusal: String) -> void:
	"""Order `o`'s state from its switch, latch, jobs and `refusal`; a newly blocked order's notice."""
	var was: int = state[o]
	var why: String = ""
	if enabled[o] == 0:
		state[o] = STATE_OFF
	elif latch[o] == 0:
		state[o] = STATE_SATISFIED
	elif jobs_of(o) == 0 and not refusal.is_empty():
		state[o] = STATE_BLOCKED
		why = refusal
	else:
		why = _all_blocked_words(o)
		state[o] = STATE_WORKING if why.is_empty() else STATE_BLOCKED
	if state[o] != was or reason[o] != why:
		reason[o] = why
		revision += 1
	_keep_notice(o)


func _all_blocked_words(o: int) -> String:
	"""The board's words when every job order `o` holds is blocked there ("" otherwise, or with no jobs)."""
	if _board == null or jobs_of(o) == 0:
		return ""
	var words: String = ""
	for k: int in MAX_JOBS:
		var slot: int = o * MAX_JOBS + k
		if job_source[slot] == FREE:
			continue
		if not _board.fill(job_source[slot], job_row[slot], _task) or _task.state != WorkIds.STATE_BLOCKED:
			return ""
		if words.is_empty():
			words = _task.reason
	return words


func _keep_notice(o: int) -> void:
	"""A notice when order `o` becomes blocked (once, until it is not); never for a built-in order."""
	if state[o] != STATE_BLOCKED:
		notified[o] = 0
		return
	if notified[o] == 1 or built_in[o] == 1 or not _report.is_valid():
		return
	notified[o] = 1
	_report.call(KEY_BLOCKED % serial[o], NOTICE % [title_of(o), reason[o]], incident_state.bind(serial[o]))


func incident_state(of_serial: int) -> int:
	"""The blocked notice's watch: open while the order with that serial is blocked; resolved once it is not, or gone."""
	for o: int in MAX_ORDERS:
		if kind[o] != FREE and serial[o] == of_serial:
			return INCIDENT_OPEN if state[o] == STATE_BLOCKED else INCIDENT_RESOLVED
	return INCIDENT_RESOLVED


func title_of(o: int) -> String:
	"""The order as given: "Keep 20.0 U of planks"."""
	return Kinds.title(kind[o], item[o], amount[o]) if is_live(o) else ""


func target_of(o: int) -> int:
	"""What the order keeps the good at: its amount (the Firewood: the winter's projection)."""
	if not is_live(o) or _goals[kind[o]] == null:
		return 0
	return _goals[kind[o]].target(int(amount[o]))
