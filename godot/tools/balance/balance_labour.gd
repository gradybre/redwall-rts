extends RefCounted
## THE BALANCE HARNESS'S LABOUR AND WORK-BOARD WATCH (decision 0571). Measurement only: it reads the work board, the
## kitchen and each resident's brain and writes nothing back.
##
## LABOUR. At every sample each resident is put in ONE class, first match wins:
##   REST   in bed or on its way there (the night routine's sleep task), or lying down;
##   MEAL   the kitchen has it as a diner (walking to the table, waiting, eating, or eating raw);
##   WORK   it holds a task on some work-board source, the kitchen has it cooking or drawing water, or it is on a
##          player's order;
##   OTHER  driven by some other task (an evacuation, a rescue, a crossing) or in the water;
##   IDLE   none of these: wandering on its own, available to the board.
## A classification covers the calendar ticks since the previous one, so a class's total is resident-TICKS (750 a game
## hour). The board is scanned every frame (`scan`), the residents classified every few (`classify`).
##
## THE WORK BOARD. Every waiting row of every source is counted (the queue length, time-weighted) and timed from the
## sample it was first seen waiting to the sample it stopped: CLAIMED when a worker holds the same task then, DROPPED
## otherwise (blocked, paused, cancelled or done without a worker). A row reused for a new task is a new task (its key).

const BoardScript := preload("res://demo/work/work_board.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")

const C_WORK: int = 0
const C_IDLE: int = 1
const C_MEAL: int = 2
const C_REST: int = 3
const C_OTHER: int = 4
const CLASS_COUNT: int = 5
const CLASS_NAMES: Array[String] = ["work", "idle", "meal", "rest", "other"]
## A task's identity in the wait table: source, row and the row's task key packed into one int.
const SOURCE_SHIFT: int = 48
const ROW_SHIFT: int = 32
const KEY_MASK: int = 0xFFFFFFFF

var _board: BoardScript = null
var _kitchen: KitchenScript = null
var _count: int = 0
var _last_tick: int = -1
var _last_scan: int = -1
var _sample: int = 0
## Per resident, per class: resident-ticks this day (row-major, CLASS_COUNT a resident).
var _ticks: PackedInt64Array = PackedInt64Array()
## Per resident: whether a board task's worker is that resident this sample.
var _working: PackedByteArray = PackedByteArray()
## The open waits: task id -> the tick it was first seen waiting, and the sample it was last seen.
var _since: Dictionary = {}
var _seen: Dictionary = {}
var _ended: PackedInt64Array = PackedInt64Array()
## This day's queue and waits.
var _queue_ticks: int = 0
var _queue_weighted: int = 0
var _queue_max: int = 0
var _claimed: int = 0
var _dropped: int = 0
var _wait_sum: int = 0
var _wait_max: int = 0
var _claimed_by_source: PackedInt32Array = PackedInt32Array()


func bind(board: BoardScript, kitchen: KitchenScript) -> void:
	"""Watch `board` and `kitchen` for every resident the board knows."""
	_board = board
	_kitchen = kitchen
	_count = board.resident_count()
	_ticks.resize(_count * CLASS_COUNT)
	_working.resize(_count)
	_claimed_by_source.resize(WorkIds.SOURCE_COUNT)
	reset_day()


func scan(tick: int) -> void:
	"""The board at calendar tick `tick` (every frame: a claim inside half a second must not be missed): the queue
	length since the last scan, each waiting row's wait, who works."""
	var dt: int = tick - _last_scan if _last_scan >= 0 else 0
	_last_scan = tick
	_sample += 1
	_working.fill(0)
	var waiting: int = _scan_board(tick)
	_close_waits(tick)
	_queue_ticks += dt
	_queue_weighted += waiting * dt
	_queue_max = maxi(_queue_max, waiting)


func classify(tick: int) -> void:
	"""Each resident's class now, charged with the calendar ticks since the last classification (after a `scan`)."""
	var dt: int = tick - _last_tick if _last_tick >= 0 else 0
	_last_tick = tick
	if dt <= 0:
		return
	for who: int in _count:
		_ticks[who * CLASS_COUNT + class_of(who)] += dt


func _scan_board(tick: int) -> int:
	"""Mark every board task's worker as working and every waiting row as seen; the rows waiting."""
	var waiting: int = 0
	for s: int in WorkIds.SOURCE_COUNT:
		var src: SourceScript = _board.source(s)
		if src == null:
			continue
		for row: int in src.capacity():
			if not src.live(row):
				continue
			var who: int = src.worker(row)
			if who >= 0 and who < _count:
				_working[who] = 1
			if src.waiting(row):
				waiting += 1
				_note_waiting(task_id(s, row, src.key(row)), tick)
	return waiting


func _note_waiting(id: int, tick: int) -> void:
	"""A row seen waiting this sample: its wait starts now if it was not already waiting."""
	if not _since.has(id):
		_since[id] = tick
	_seen[id] = _sample


static func task_id(s: int, row: int, key: int) -> int:
	"""One int naming a source's row and the task on it."""
	return (s << SOURCE_SHIFT) | (row << ROW_SHIFT) | (key & KEY_MASK)


func _close_waits(tick: int) -> void:
	"""Every wait not seen this sample has ended: claimed (a worker holds the same task now) or dropped."""
	_ended.clear()
	for id: int in _since:
		if int(_seen[id]) != _sample:
			_ended.append(id)
	for id: int in _ended:
		var s: int = id >> SOURCE_SHIFT
		var row: int = (id >> ROW_SHIFT) & 0xFFFF
		var src: SourceScript = _board.source(s)
		var same: bool = src != null and src.live(row) and (src.key(row) & KEY_MASK) == (id & KEY_MASK)
		if same and src.worker(row) >= 0:
			var wait: int = tick - int(_since[id])
			_claimed += 1
			_claimed_by_source[s] += 1
			_wait_sum += wait
			_wait_max = maxi(_wait_max, wait)
		else:
			_dropped += 1
		_since.erase(id)
		_seen.erase(id)


func class_of(who: int) -> int:
	"""Resident `who`'s labour class now (see LABOUR)."""
	var brain: BrainScript = _board.brain_of(who)
	if brain == null:
		return C_OTHER
	if brain.resting or brain.lying or brain.task is SleepTaskScript:
		return C_REST
	var role: int = _kitchen.role_of(who) if _kitchen != null else KitchenScript.ROLE_NONE
	if role == KitchenScript.ROLE_EAT:
		return C_MEAL
	if _working[who] == 1 or role == KitchenScript.ROLE_COOK or role == KitchenScript.ROLE_DRAW \
			or brain.order != BrainScript.ORDER_NONE:
		return C_WORK
	if brain.task != null or brain.in_water or brain.water_hold:
		return C_OTHER
	return C_IDLE


func close_day() -> Dictionary:
	"""This day's labour and board figures (resident-ticks; the queue time-weighted in task-ticks), then reset."""
	var per_resident: Array = []
	var totals: Dictionary = {}
	for c: int in CLASS_COUNT:
		totals[CLASS_NAMES[c]] = 0
	for who: int in _count:
		var row: Dictionary = {}
		for c: int in CLASS_COUNT:
			var t: int = _ticks[who * CLASS_COUNT + c]
			row[CLASS_NAMES[c]] = t
			totals[CLASS_NAMES[c]] = int(totals[CLASS_NAMES[c]]) + t
		per_resident.append(row)
	var day: Dictionary = {"labour_ticks": totals, "labour_ticks_by_resident": per_resident, "board": _board_day()}
	reset_day()
	return day


func _board_day() -> Dictionary:
	"""The board's day: queue (task-ticks over ticks; the max), waits claimed and dropped, and claims by source."""
	var by_source: Dictionary = {}
	for s: int in WorkIds.SOURCE_COUNT:
		if _claimed_by_source[s] > 0:
			by_source[WorkIds.SOURCE_NAMES[s]] = _claimed_by_source[s]
	return {"queue_task_ticks": _queue_weighted, "queue_ticks": _queue_ticks, "queue_max": _queue_max,
		"claimed": _claimed, "dropped": _dropped, "wait_ticks_sum": _wait_sum, "wait_ticks_max": _wait_max,
		"claimed_by_source": by_source, "open_waits_end": _since.size()}


func reset_day() -> void:
	"""Zero the day's tallies (open waits carry over: a wait spanning midnight ends on the day it ends)."""
	_ticks.fill(0)
	_queue_ticks = 0
	_queue_weighted = 0
	_queue_max = 0
	_claimed = 0
	_dropped = 0
	_wait_sum = 0
	_wait_max = 0
	_claimed_by_source.fill(0)


func resident_count() -> int:
	"""How many residents are watched."""
	return _count
