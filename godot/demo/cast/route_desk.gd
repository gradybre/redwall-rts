extends RefCounted
## The routing desk: route planning spread over frames. Decision 0361 (the review's F06). Presentation only -- it
## schedules the demo cast's route planning, never the simulation's.
##
## WHY. A route is planned synchronously (cast_nav.gd, tunnel_router.gd), and a plan through the village costs real
## time: a nine-resident group order ran 5-26 ms on the command's frame, more than a 16.67 ms frame by itself. So every
## plan's time is CHARGED to the current frame's window (`charge`, from resident_brain.gd `_plan_trip`, and from the
## formation search in cast_orders.gd), and a resident starting a trip asks first (`may_plan`): while the window's
## BUDGET lasts and nobody waits before it, it plans at once; else it WAITS (`wait`) -- standing, "finding a route" --
## and is served on a later frame, first come first served (`serve`, from DemoCast each frame, paused or not). The desk
## looks ahead before a plan it cannot cut: one is let start only when the window has spent nothing yet or the spend so
## far plus a typical plan (`estimate_usec`, a running mean of the plans charged) stays inside the budget.
##
## THE JOB: A PLAN CUT ACROSS FRAMES (decision 1001, the 2026-10-02 review's R07). A resident's trip on the surface
## alone -- no tunnel, no crossing -- is planned by the desk's own planner (`worker`, a second cast_nav.gd over the
## space's circles and graphs) through `plan_surface`, a slice of SLICE_EXPANSIONS expansions at a time while the
## window lasts. A plan the window cannot finish is the JOB: its resident stands in ROUTE, the next windows carry the
## job on first (`serve`), and when it is done the resident's turn is called, and its plan picks the finished route up.
## A job's resident given another goal meanwhile drops the job and waits its turn like anyone (`wait`). So a window
## spends at most its budget and one expansion -- never one whole plan, however long -- and the frame no longer pays for
## a plan that grows with the village. One job at a time: while one is under way, nobody else starts a plan (`may_plan`
## cannot tell a plan the desk could cut from one it could not before it is made), they wait; a plan the desk cannot cut
## (through a tunnel, a crossing, a formation's search) runs whole, as before.
##
## ONE FIELD PER SHARED GOAL (decision 1002). A resident who waits says where it is going (`wait`'s goal). When a job
## begins and SHARED_MIN or more others wait for the same spot, the job is GUIDED by that spot's field (cast_nav.gd ONE
## FIELD PER SHARED GOAL): the field is searched once, as part of the first such job, and every plan to that spot after
## it expands little more than its route.
##
## THE WINDOW is from one frame's cast step to the next (`end_window`, after it): the player's orders, which arrive as
## input before the frame's processing, share the window with that frame's stepping and serving.
##
## NO BUDGET (`budget_usec` 0, the default): every plan runs at once and whole, nobody waits -- a CastSpace out of the
## live scene (the suites' hand-stepped brains) behaves exactly as before. DemoCast gives the live scene its budget.
##
## A waiting resident is served through the callable it registered (`register`: the brain's `route_turn`); a Callable
## does not keep its object alive, so the desk never holds a brain. Nothing here allocates per frame: the queue and
## the callables are sized by `register`, once per resident.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")

## Expansions a job takes between looks at the clock (see THE JOB): one, since one expansion in a crowd -- dozens
## standing within a link's reach -- can cost a millisecond or two (4 a slice let a window run to 7 ms at 100 residents,
## 16 to 14 ms at 50; one keeps it near its budget).
const SLICE_EXPANSIONS: int = 1
## How many others must wait for the same spot before a job is guided by its field (see ONE FIELD PER SHARED GOAL): a
## field costs a search of the whole graph, a few plans' worth, so only a crowd's goal earns one.
const SHARED_MIN: int = 3

## Per resident index: its turn callable (resident_brain.gd `route_turn`), and where it waits to go (INF: not said).
var _turns: Array[Callable] = []
var _goal_of: PackedVector2Array = PackedVector2Array()
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
## The desk's own planner (see THE JOB), told the space's circles by the space (cast_space.gd `share_world`).
var worker: CastNavScript = CastNavScript.new()
## The resident whose plan is the job (-1: none; see THE JOB); and whether it began in a turn `serve` gave (so it is
## counted served already), and whether `serve` is giving one now.
var job_owner: int = -1
var _job_served: bool = false
var _in_turn: bool = false
## Measurement: what the last finished window spent, the most any window has, how many plans were served late, how
## many windows ended with a job still under way, and the slices jobs took.
var last_window_usec: int = 0
var max_window_usec: int = 0
var served: int = 0
var jobs_carried: int = 0
var job_slices: int = 0
## Measurement, off by default (the scale test, decision 0561): with `tally` on, each resident's plans finished and
## their microseconds, by resident index (a job's slices count to its resident).
var tally: bool = false
var plans_of: PackedInt32Array = PackedInt32Array()
var plan_usec_of: PackedInt64Array = PackedInt64Array()


func register(index: int, turn: Callable) -> void:
	"""Resident `index` is served through `turn` when it waits (setup: the columns grow here)."""
	if _turns.size() <= index:
		_turns.resize(index + 1)
		_queue.resize(index + 1)
		_goal_of.resize(index + 1)
	_turns[index] = turn
	_goal_of[index] = Vector2.INF


func may_plan(index: int) -> bool:
	"""Whether resident `index` may plan a trip now: no budget, or some left in this window, nobody waiting before it,
	and no job but its own under way."""
	if budget_usec <= 0:
		return true
	return _plan_fits() and (_count == 0 or _queue[0] == index) and (job_owner < 0 or job_owner == index)


func has_budget() -> bool:
	"""Whether this window may start another plan (always, with no budget set)."""
	return budget_usec <= 0 or _plan_fits()


func _plan_fits() -> bool:
	"""Whether a typical plan fits what is left of the window -- or the window has spent nothing yet."""
	return _spent_usec == 0 or _spent_usec + estimate_usec <= budget_usec


func wait(index: int, goal: Vector2 = Vector2.INF) -> void:
	"""Resident `index` waits for its turn, going to `goal` (INF: not said); a resident already waiting keeps its place,
	and the job's owner is waited for already -- unless it now goes somewhere else: then its job is dropped and it waits
	its turn like anyone (an order given while its plan was carried over)."""
	if index < _goal_of.size():
		_goal_of[index] = goal
	if index == job_owner:
		if worker.plan_goal() == goal:
			return
		job_owner = -1
	if _find(index) >= 0:
		return
	_queue[_count] = index
	_count += 1


func is_waiting(index: int) -> bool:
	"""Whether resident `index` waits for a route (in the queue, or its plan the job)."""
	return index == job_owner or _find(index) >= 0


func waiting() -> int:
	"""How many residents wait (the job's owner among them)."""
	return _count + (1 if job_owner >= 0 else 0)


func charge(index: int, usec: int, finished: bool = true) -> void:
	"""A plan took `usec` of this window (resident `index`'s -- served, it waits no longer in the queue; -1: no
	resident's, a formation's search). `finished` false: the plan is the job, to be carried on (see THE JOB)."""
	_spent_usec += maxi(usec, 0)
	_charged = index
	if tally and index >= 0:
		_tally(index, maxi(usec, 0), 1 if finished else 0)
	if index >= 0:
		if finished:
			@warning_ignore("integer_division") estimate_usec = (3 * estimate_usec + maxi(usec, 0)) / 4
		forget(index)


func _tally(index: int, usec: int, plans: int) -> void:
	"""Count `plans` plans and `usec` of resident `index` (see `tally`); the columns grow on first use."""
	if plans_of.size() <= index:
		plans_of.resize(index + 1)
		plan_usec_of.resize(index + 1)
	plans_of[index] += plans
	plan_usec_of[index] += usec


func forget(index: int) -> void:
	"""Resident `index` waits no longer in the queue (it planned, or another order or a release took it off the trip)."""
	var at := _find(index)
	if at < 0:
		return
	for k in range(at, _count - 1):
		_queue[k] = _queue[k + 1]
	_count -= 1


func serve() -> void:
	"""Carry the job on, then serve the waiting residents in turn while this window's budget lasts (DemoCast, each
	frame). Each turn either plans (and is charged, which takes it off the queue) or finds its resident no longer
	waiting and gives the place up; a turn that does neither is dropped, so the loop always ends. One that planned and
	then waits again (a second trip started in its turn) keeps the place it took. At most two turns a resident a call:
	a turn that keeps waiting again cannot hold the frame."""
	for guard in 2 * _turns.size() + 1:
		if job_owner >= 0:
			if not _serve_job():
				return
			continue
		if _count == 0 or not has_budget():
			return
		var who := _queue[0]
		var turn: Callable = _turns[who]
		_charged = -1
		if turn.is_valid():
			_in_turn = true
			turn.call()
			_in_turn = false
			served += 1
		if _charged != who and _count > 0 and _queue[0] == who:
			forget(who)


func _serve_job() -> bool:
	"""Carry the job on while the window lasts; once it is done, its resident's turn picks the route up (a turn that does
	not -- its resident taken off the trip meanwhile -- leaves it, and it is dropped; a turn that begins another plan
	makes that the job). False while it is still under way."""
	var since := Time.get_ticks_usec()
	var done := _advance_job(since)
	var spent := Time.get_ticks_usec() - since
	_spent_usec += spent
	if tally:
		_tally(job_owner, spent, 0)
	if not done:
		jobs_carried += 1
		return false
	var who := job_owner
	var turn: Callable = _turns[who]
	served += 0 if _job_served or not turn.is_valid() else 1
	if turn.is_valid():
		_in_turn = true
		turn.call()
		_in_turn = false
	if job_owner == who and worker.plan_state() != CastNavScript.PLAN_PENDING:
		job_owner = -1
	return true


func plan_surface(index: int, from: Vector2, to: Vector2, body: float, standing: PackedVector3Array,
		standing_count: int, out: PackedVector2Array) -> bool:
	"""Resident `index`'s trip on the surface, planned by the desk (see THE JOB): its finished job's route, or a plan
	begun now and carried while the window lasts. True with the route in `out` (and `worker.last_found` set); false
	when it is the job, to be carried on -- the resident waits."""
	var since := Time.get_ticks_usec()
	if not holds_job(index, from, to, body):
		var guided := _sharing(index, to) >= SHARED_MIN
		worker.begin_plan(from, to, body, standing, standing_count, guided)
		job_owner = index
		_job_served = _in_turn
	if not _advance_job(since):
		return false
	worker.finish_plan(out)
	job_owner = -1
	return true


func holds_job(index: int, from: Vector2, to: Vector2, body: float) -> bool:
	"""Whether the job is resident `index`'s plan from `from` to `to` for a body of radius `body` (see THE JOB)."""
	return job_owner == index and worker.plan_matches(from, to, body)


func may_divide(index: int) -> bool:
	"""Whether resident `index`'s plan may be the desk's (see THE JOB): no job, or its own."""
	return job_owner < 0 or job_owner == index


func _advance_job(since: int) -> bool:
	"""Carry the job on a slice at a time until it is done or this window -- with what was spent since `since`, not yet
	charged -- is spent (never, with no budget); at least one slice. True once it is done."""
	while true:
		job_slices += 1
		if worker.step_plan(SLICE_EXPANSIONS) != CastNavScript.PLAN_PENDING:
			return true
		if budget_usec > 0 and _spent_usec + Time.get_ticks_usec() - since >= budget_usec:
			return false
	return false


func _sharing(index: int, goal: Vector2) -> int:
	"""How many others wait to go to `goal` (see ONE FIELD PER SHARED GOAL)."""
	var n := 0
	for k in _count:
		var who := _queue[k]
		if who != index and _goal_of[who] == goal:
			n += 1
	return n


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
