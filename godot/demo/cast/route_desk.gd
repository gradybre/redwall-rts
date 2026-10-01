extends RefCounted
## The routing desk: route planning spread over frames. Decision 0361 (the review's F06). Presentation only -- it
## schedules the demo cast's route planning, never the simulation's.
##
## WHY. A route is planned synchronously (cast_nav.gd, tunnel_router.gd), and a plan through the village costs real
## time: a nine-resident group order ran 5-26 ms on the command's frame, more than a 16.67 ms frame by itself. So every
## plan's time is CHARGED to the current frame's window (`charge`, from resident_brain.gd `_plan_trip`, and from the
## formation search in cast_orders.gd), and a resident starting a trip asks first (`may_plan`): while the window's
## BUDGET lasts and nobody waits before it, it plans at once; else it WAITS (`wait`) -- standing, "finding a route" --
## and is served on a later frame, first come first served (`serve`, from DemoCast each frame, paused or not). A plan
## is never cut in two, so the desk looks ahead: a plan is let start only when the window has spent nothing yet or the
## spend so far plus a typical plan (`estimate_usec`, a running mean of the plans charged) stays inside the budget. So
## a window spends at most its budget, or one plan's time when that plan alone is longer.
##
## THE WINDOW is from one frame's cast step to the next (`end_window`, after it): the player's orders, which arrive as
## input before the frame's processing, share the window with that frame's stepping and serving.
##
## NO BUDGET (`budget_usec` 0, the default): every plan runs at once, nobody waits -- a CastSpace out of the live
## scene (the suites' hand-stepped brains) behaves exactly as before. DemoCast gives the live scene its budget.
##
## A waiting resident is served through the callable it registered (`register`: the brain's `route_turn`); a Callable
## does not keep its object alive, so the desk never holds a brain. Nothing here allocates per frame: the queue and
## the callables are sized by `register`, once per resident.

## Per resident index: its turn callable (resident_brain.gd `route_turn`).
var _turns: Array[Callable] = []
## The residents waiting for a route, first come first served.
var _queue: PackedInt32Array = PackedInt32Array()
var _count: int = 0
## The routing budget a window may spend (microseconds; 0: none -- every plan at once), and what this one has.
var budget_usec: int = 0
var _spent_usec: int = 0
## A typical plan's time: the running mean (weight a quarter to the newest) of the plans charged to a resident.
var estimate_usec: int = 0
## The resident the last plan was charged to (-1: none, or a formation's): `serve` tells a turn that planned from one that
## did not by it.
var _charged: int = -1
## Measurement: what the last finished window spent, the most any window has, and how many plans were served late.
var last_window_usec: int = 0
var max_window_usec: int = 0
var served: int = 0


func register(index: int, turn: Callable) -> void:
	"""Resident `index` is served through `turn` when it waits (setup: the columns grow here)."""
	if _turns.size() <= index:
		_turns.resize(index + 1)
		_queue.resize(index + 1)
	_turns[index] = turn


func may_plan(index: int) -> bool:
	"""Whether resident `index` may plan a trip now: no budget, or some left in this window and nobody waiting before
	it."""
	if budget_usec <= 0:
		return true
	return _plan_fits() and (_count == 0 or _queue[0] == index)


func has_budget() -> bool:
	"""Whether this window may start another plan (always, with no budget set)."""
	return budget_usec <= 0 or _plan_fits()


func _plan_fits() -> bool:
	"""Whether a typical plan fits what is left of the window -- or the window has spent nothing yet."""
	return _spent_usec == 0 or _spent_usec + estimate_usec <= budget_usec


func wait(index: int) -> void:
	"""Resident `index` waits for its turn (a resident already waiting keeps its place)."""
	if _find(index) >= 0:
		return
	_queue[_count] = index
	_count += 1


func is_waiting(index: int) -> bool:
	"""Whether resident `index` waits for a route."""
	return _find(index) >= 0


func waiting() -> int:
	"""How many residents wait."""
	return _count


func charge(index: int, usec: int) -> void:
	"""A plan took `usec` of this window (resident `index`'s -- served, it waits no longer; -1: no resident's, a
	formation's search)."""
	_spent_usec += maxi(usec, 0)
	_charged = index
	if index >= 0:
		@warning_ignore("integer_division") estimate_usec = (3 * estimate_usec + maxi(usec, 0)) / 4
		forget(index)


func forget(index: int) -> void:
	"""Resident `index` waits no longer (it planned, or another order or a release took it off the trip)."""
	var at := _find(index)
	if at < 0:
		return
	for k in range(at, _count - 1):
		_queue[k] = _queue[k + 1]
	_count -= 1


func serve() -> void:
	"""Serve the waiting residents in turn while this window's budget lasts (DemoCast, each frame). Each turn either
	plans (and is charged, which takes it off the queue) or finds its resident no longer waiting and gives the place up;
	a turn that does neither is dropped, so the loop always ends. One that planned and then waits again (a second trip
	started in its turn) keeps the place it took. At most two turns a resident a call: a turn that keeps waiting again
	cannot hold the frame."""
	for guard in 2 * _turns.size():
		if _count == 0 or not has_budget():
			return
		var who := _queue[0]
		var turn: Callable = _turns[who]
		_charged = -1
		if turn.is_valid():
			turn.call()
			served += 1
		if _charged != who and _count > 0 and _queue[0] == who:
			forget(who)


func end_window() -> void:
	"""The frame's window is over (DemoCast, after the cast's step): what it spent is kept for measurement, and the
	next window starts with its whole budget."""
	last_window_usec = _spent_usec
	max_window_usec = maxi(max_window_usec, _spent_usec)
	_spent_usec = 0


func spent_usec() -> int:
	"""What this window has spent so far."""
	return _spent_usec


func _find(index: int) -> int:
	"""Where resident `index` waits in the queue (-1: it does not)."""
	for k in _count:
		if _queue[k] == index:
			return k
	return -1
