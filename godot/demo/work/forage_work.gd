extends "res://demo/work/work_source.gd"
## The foraging trips' seats as the work board reads them (decision 0681, with 0411; see work_source.gd): each forager's
## seat on an authorised trip -- walking to its spot in the woods, gathering its share, carrying the haul home -- the
## Woods crew's work. The board CLAIMS them -- an idle resident takes the best one it may -- and every command is the
## trips' own (forage_trips.gd): a haul in hand is delivered before its forager is stopped or swapped, and Cancel calls
## off a seat not yet carrying.

const TripsScript := preload("res://demo/forage/forage_trips.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")

var _trips: TripsScript = null


func _init(trips: TripsScript) -> void:
	"""Read these trips' seats."""
	id = WorkIds.SOURCE_FORAGE
	_trips = trips


func capacity() -> int:
	"""The trips' seat rows."""
	return Rules.MAX_JOBS


func live(row: int) -> bool:
	"""Whether the row holds a seat."""
	return _trips.j_live[row] == 1


func key(row: int) -> int:
	"""The seat's serial (a reused row is a new task)."""
	return _trips.j_serial[row]


func worker(row: int) -> int:
	"""Who forages it (-1: nobody yet)."""
	return _trips.j_worker[row]


func activity(_row: int) -> int:
	"""Foraging is woods work."""
	return WorkIds.ACT_WOODS


func point(row: int) -> Vector2:
	"""Where the seat is now."""
	return _trips.goal_point(row)


func waiting(row: int) -> bool:
	"""Whether it waits for a forager and may be taken now."""
	return _trips.waiting(row)


func eligibility(row: int, who: int) -> String:
	"""Why `who` may not take it ("" when it may): the trips' own test."""
	return _trips.eligibility(row, who)


func claim(row: int, who: int) -> bool:
	"""Hand it to `who`, who sets off at once."""
	return _trips.claim(row, who)


func fill(task: TaskScript, row: int) -> void:
	"""The Work screen's record of seat `row`."""
	task.reset(id, row)
	task.key = _trips.j_serial[row]
	task.action = _trips.task_words(row)
	task.target = _trips.place_words(row)
	task.worker = _trips.j_worker[row]
	task.activity = WorkIds.ACT_WOODS
	task.carrying = _trips.j_load[row] > 0
	task.point = _trips.goal_point(row)
	task.remaining_usec = _trips.remaining_usec(row)
	var hold: String = _trips.hold_refusal(row)
	task.pause_refusal = hold
	task.reassign_refusal = hold
	task.cancel_refusal = WorkIds.DELIVERY_GOES_ON if _trips.j_load[row] > 0 else ""
	if task.worker >= 0:
		task.target_kind = NoticesScript.TARGET_RESIDENT
		task.target_id = task.worker
		worker_state_into(task, _trips.brain_of(task.worker), _trips.is_walking(row), _trips.j_issued[row] != 0)
		return
	var why: String = _trips.j_words[row] if _trips.j_wait_usec[row] > 0 else ""
	waiting_state_into(task, _trips.j_paused[row] == 1, why)


func pause(row: int, on: bool) -> String:
	"""Pause or resume the seat."""
	return _trips.pause_job(row, on)


func cancel(row: int) -> String:
	"""Cancel the seat (not while its haul is in hand)."""
	return _trips.cancel_job(row)


func reassign(row: int, who: int) -> String:
	"""Give the seat to `who`."""
	return _trips.reassign_job(row, who)
