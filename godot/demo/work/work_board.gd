extends RefCounted
## THE WORK BOARD: the village's one common owner of who does what (decision 0411; review F22, F32, F44's remainder,
## SOC-004, UX-001, UX-002, UX-007). Presentation only: the demo's jobs, never the simulation's.
##
## It owns no job. Each job owner keeps its own board (the farm's, the woods', the bridges', the tunnels', the fit-out,
## the spoil crew's); the work board reads them through one adapter each (work_source.gd) and is the ONE place that:
##   * CLAIMS waiting work for idle residents (THE CLAIM), in place of the hidden fixed crews;
##   * keeps the player's per-task PRIORITY and URGENT marks;
##   * carries the Work screen's per-task commands -- Pause, Cancel this task, Reassign -- to the owner's own function,
##     and "Cancel all work" with its scope counted first;
##   * appends to a resident's ORDER LIST (resident_brain.gd THE ORDER LIST; order_list.gd), and reads every list for
##     each task's RESUME INTENT ("X comes back to it").
##
## THE CLAIM (GDD §5.3, its demo simplification recorded in decision 0411). Every CLAIM_PERIOD_USEC of cast time each
## resident is reconsidered, the residents staggered evenly over the period (the GDD's "staggered by resident ID"). One
## that is IDLE -- wandering on its own, on the surface, not resting, not in the water nor held by its rescue, not
## crossing, not on a queued walk, and not kept for its needs (`set_needs_gate`: the meals when they land) -- takes the
## best task it is ELIGIBLE for from the CANDIDATE INDEX: the waiting tasks, rebuilt once a period (never a scan of
## every board per frame), at most MAX_CANDIDATES of them looked at per resident per pass from its saved cursor.
## Eligibility is the source's (skills and physical fit, never a species lock, LORE-P12), the resident's crew priority
## for the task's activity must not be 0 (forbidden), and a task another resident's order list promises to come back to
## is left to that resident. Candidates sort by (urgency bucket, the resident's crew priority, the task's priority,
## distance in cm, the task's key, source): a task the player marked URGENT is bucket 2, any other 3 (the GDD's buckets
## 0-1 -- rescue, a resident's own critical needs -- never reach the board: they are emergencies that take the resident
## off its work first). Safety and needs therefore always come before work: nothing is claimed for a resident the night
## routine has in bed (decision 0210), the rescue holds, an evacuation leads (a task), or its needs keep.

const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const SourceScript := preload("res://demo/work/work_source.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const OrderList := preload("res://demo/work/order_list.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const PeopleBook := preload("res://demo/people/people_book.gd")

## How often each resident is reconsidered (cast time): the crews' old pick-up interval.
const CLAIM_PERIOD_USEC: int = 500000
## GDD §5.3: "A worker evaluates at most 32 indexed candidate jobs per pass".
const MAX_CANDIDATES: int = 32
## The urgency buckets the board uses (see THE CLAIM).
const BUCKET_URGENT: int = 2
const BUCKET_ORDINARY: int = 3
## Why a resident cannot take work now, as the Reassign picker and the group preview say it.
const RESTING: String = "asleep — the night routine has it in bed"
const IN_WATER: String = WorkIds.IN_WATER
const HELD: String = WorkIds.HELD
const UNKNOWN: String = "nobody by that number"
const WALK_DONE_M: float = 0.45
const LIST_FULL: String = "%s's order list is full (%d queued) or holds it already"

var crews: CrewsScript = CrewsScript.new()
## Claims made since the board began, and the evaluations and candidates looked at (the profile's counts).
var claims: int = 0
var evaluations: int = 0
var candidates_seen: int = 0
var index_rebuilds: int = 0
## Real time spent in `update` (microseconds): the total, and the most one call took; and of that, the claim's own
## scan -- rebuilding the candidate index and choosing among candidates, not the chosen job's first walk -- in a frame.
var update_usec_total: int = 0
var update_usec_max: int = 0
var updates: int = 0
var scan_usec_total: int = 0
var scan_usec_max: int = 0
var _scan_usec: int = 0
## Bumped on every change the Work screen shows (a claim, a command, a priority).
var revision: int = 0

var _sources: Array[SourceScript] = []
var _brains: Array[BrainScript] = []
var _names: PackedStringArray = PackedStringArray()
## Each resident's name with its species and role ("Wenna Tallowby (mouse keeper)"; decision 0491), for the rows where
## the role helps choose (the Work screen's residents).
var _labels: PackedStringArray = PackedStringArray()
var _clock_usec: int = 0
var _due_usec: PackedInt64Array = PackedInt64Array()
var _cursor: PackedInt32Array = PackedInt32Array()
var _next_index_usec: int = 0
## THE CANDIDATE INDEX: the waiting tasks, one entry each, and who (if anyone) means to come back to it.
var _idx_source: PackedInt32Array = PackedInt32Array()
var _idx_row: PackedInt32Array = PackedInt32Array()
var _idx_promised: PackedInt32Array = PackedInt32Array()
var _idx_taken: PackedByteArray = PackedByteArray()
## The promises read at the last rebuild: (source, key, resident) a promise.
var _promise_source: PackedInt32Array = PackedInt32Array()
var _promise_key: PackedInt64Array = PackedInt64Array()
var _promise_who: PackedInt32Array = PackedInt32Array()
## The player's per-task priority and urgency, per source per row, kept for the task whose key it was set for.
var _priority: Array[PackedInt32Array] = []
var _priority_key: Array[PackedInt64Array] = []
var _urgent: Array[PackedByteArray] = []
## Each resident's queued walk under way (see order_list.gd QueuedWalk).
var _walking: PackedByteArray = PackedByteArray()
var _walk_goal: PackedVector2Array = PackedVector2Array()
var _needs_gate: Callable = Callable()
## `jump(kind, id, point) -> bool`: the village's "Go to".
var _jump: Callable = Callable()
var _task: TaskScript = TaskScript.new()
var _rank: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
var _best: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
var _members: PackedInt32Array = PackedInt32Array()


func bind(brains: Array[BrainScript], names: PackedStringArray, keys: Array[StringName]) -> void:
	"""Work with these residents (by actor index), named so, each starting on its trade's crew (work_crews.gd)."""
	_brains = brains
	_names = names
	_labels = PackedStringArray()
	for who: int in names.size():
		_labels.append(PeopleBook.with_role(names[who], keys[who] if who < keys.size() else &""))
	crews.setup(keys)
	var count: int = brains.size()
	_due_usec.resize(count)
	_cursor.resize(count)
	_walking.resize(count)
	_walk_goal.resize(count)
	for who: int in count:
		@warning_ignore("integer_division") _due_usec[who] = CLAIM_PERIOD_USEC * (who + 1) / maxi(count, 1)
	_sources.resize(WorkIds.SOURCE_COUNT)
	_priority.resize(WorkIds.SOURCE_COUNT)
	_priority_key.resize(WorkIds.SOURCE_COUNT)
	_urgent.resize(WorkIds.SOURCE_COUNT)


func add_source(adapter: SourceScript) -> void:
	"""List and command this owner's tasks (one adapter per WorkIds.SOURCE_*)."""
	_sources[adapter.id] = adapter
	var rows: int = adapter.capacity()
	_priority[adapter.id] = PackedInt32Array()
	_priority[adapter.id].resize(rows)
	_priority[adapter.id].fill(WorkIds.PRIORITY_NORMAL)
	_priority_key[adapter.id] = PackedInt64Array()
	_priority_key[adapter.id].resize(rows)
	_urgent[adapter.id] = PackedByteArray()
	_urgent[adapter.id].resize(rows)


func source(id: int) -> SourceScript:
	"""The adapter for WorkIds.SOURCE_* `id` (null when none is bound)."""
	return _sources[id] if WorkIds.is_source(id) and id < _sources.size() else null


func set_needs_gate(gate: Callable) -> void:
	"""`gate(who) -> bool`: true while a resident's needs come first (its meal); the board claims nothing for it then."""
	_needs_gate = gate


func set_jump(jump_to: Callable) -> void:
	"""`jump_to(kind, id, point) -> bool`: the village's "Go to" (demo_news_jump.gd, else the camera on the point)."""
	_jump = jump_to


func resident_count() -> int:
	"""How many residents the board works with."""
	return _brains.size()


func name_of(who: int) -> String:
	"""Resident `who`'s name (UNKNOWN out of range)."""
	return _names[who] if who >= 0 and who < _names.size() else UNKNOWN


func label_of(who: int) -> String:
	"""Resident `who`'s name with its species and role ("Wenna Tallowby (mouse keeper)"; UNKNOWN out of range)."""
	return _labels[who] if who >= 0 and who < _labels.size() else UNKNOWN


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return _brains[who]


# --- the claim (see THE CLAIM) ------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance `usec` of cast time: end any queued walk that has arrived, rebuild the candidate index once a period, and
	reconsider each resident whose turn it is."""
	if usec <= 0:
		return
	var started: int = Time.get_ticks_usec()
	_scan_usec = 0
	_clock_usec += usec
	_run_walks()
	if _clock_usec >= _next_index_usec:
		rebuild_index()
		_next_index_usec = _clock_usec + CLAIM_PERIOD_USEC
		_scan_usec += Time.get_ticks_usec() - started
	for who: int in _brains.size():
		if _due_usec[who] > _clock_usec:
			continue
		while _due_usec[who] <= _clock_usec:
			_due_usec[who] += CLAIM_PERIOD_USEC
		consider(who)
	var spent: int = Time.get_ticks_usec() - started
	update_usec_total += spent
	update_usec_max = maxi(update_usec_max, spent)
	scan_usec_total += _scan_usec
	scan_usec_max = maxi(scan_usec_max, _scan_usec)
	updates += 1


func rebuild_index() -> void:
	"""THE CANDIDATE INDEX: every waiting task of every source, with the resident (if any) whose order list promises to
	come back to it."""
	index_rebuilds += 1
	_read_promises()
	_idx_source.clear()
	_idx_row.clear()
	_idx_promised.clear()
	_idx_taken.clear()
	for src: SourceScript in _sources:
		if src == null:
			continue
		for row: int in src.capacity():
			if src.waiting(row):
				_idx_source.append(src.id)
				_idx_row.append(row)
				_idx_promised.append(_promised_to(src.id, src.key(row)))
				_idx_taken.append(0)


func _read_promises() -> void:
	"""Every order-list entry that names a board task (see THE ORDER LIST)."""
	_promise_source.clear()
	_promise_key.clear()
	_promise_who.clear()
	for who: int in _brains.size():
		var brain: BrainScript = _brains[who]
		for k: int in brain.queue_size():
			var entry: UnfinishedScript = brain.queue_entry(k)
			if WorkIds.is_source(entry.source):
				_promise_source.append(entry.source)
				_promise_key.append(entry.key)
				_promise_who.append(who)


func _promised_to(task_source: int, task_key: int) -> int:
	"""Who means to come back to that task (-1: nobody)."""
	for k: int in _promise_source.size():
		if _promise_source[k] == task_source and _promise_key[k] == task_key:
			return _promise_who[k]
	return -1


func index_size() -> int:
	"""How many tasks the candidate index holds."""
	return _idx_source.size()


func consider(who: int) -> bool:
	"""THE CLAIM for one resident: if it is idle, the best eligible indexed task it may take, claimed. True when one
	was."""
	if not idle(who):
		return false
	if _brains[who].queue_size() > 0 and _brains[who].take_up_unfinished():
		return true
	if _idx_source.is_empty():
		return false
	evaluations += 1
	var scan_from: int = Time.get_ticks_usec()
	var best: int = _best_candidate(who)
	_scan_usec += Time.get_ticks_usec() - scan_from
	if best < 0:
		return false
	var src: SourceScript = _sources[_idx_source[best]]
	if not src.claim(_idx_row[best], who):
		_idx_taken[best] = 1
		return false
	_idx_taken[best] = 1
	claims += 1
	revision += 1
	return true


func _best_candidate(who: int) -> int:
	"""The index entry `who` should take (-1: none), looking at MAX_CANDIDATES entries from its saved cursor."""
	var count: int = _idx_source.size()
	var start: int = _cursor[who] % count
	var looked: int = mini(count, MAX_CANDIDATES)
	var best: int = -1
	for n: int in looked:
		var k: int = (start + n) % count
		candidates_seen += 1
		if not _candidate_ok(k, who):
			continue
		_rank_into(k, who, _rank)
		if best < 0 or _less(_rank, _best):
			best = k
			for f: int in _rank.size():
				_best[f] = _rank[f]
	_cursor[who] = (start + looked) % count if looked < count else 0
	return best


func _candidate_ok(k: int, who: int) -> bool:
	"""Whether index entry `k` is still waiting, not promised to someone else, allowed by `who`'s crew, and `who` is
	eligible for it."""
	if _idx_taken[k] == 1 or (_idx_promised[k] >= 0 and _idx_promised[k] != who):
		return false
	var src: SourceScript = _sources[_idx_source[k]]
	var row: int = _idx_row[k]
	if not src.live(row) or src.worker(row) >= 0:
		_idx_taken[k] = 1
		return false
	if crews.priority_of(who, src.activity(row)) == WorkIds.PRIORITY_FORBIDDEN:
		return false
	return src.eligibility(row, who).is_empty()


func _rank_into(k: int, who: int, out: PackedInt64Array) -> void:
	"""Index entry `k`'s sort key for `who` (see THE CLAIM): bucket, crew priority, task priority, distance (cm), key,
	source."""
	var src: SourceScript = _sources[_idx_source[k]]
	var row: int = _idx_row[k]
	out[0] = BUCKET_URGENT if is_urgent(src.id, row) else BUCKET_ORDINARY
	out[1] = crews.priority_of(who, src.activity(row))
	out[2] = task_priority(src.id, row)
	out[3] = int(_brains[who].surface_point().distance_to(src.point(row)) * 100.0)
	out[4] = src.key(row)
	out[5] = src.id


static func _less(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	"""Whether sort key `a` comes before `b` (compared field by field)."""
	for k: int in a.size():
		if a[k] != b[k]:
			return a[k] < b[k]
	return false


func idle(who: int) -> bool:
	"""Whether resident `who` may be given work by the board now (see THE CLAIM)."""
	if who < 0 or who >= _brains.size() or _walking[who] == 1:
		return false
	var brain: BrainScript = _brains[who]
	if brain.order != BrainScript.ORDER_NONE or brain.underground or brain.resting or brain.lying or brain.indoors:
		return false
	if brain.water_hold or brain.in_water or brain.state == BrainScript.State.CROSS:
		return false
	return not (_needs_gate.is_valid() and bool(_needs_gate.call(who)))


func busy_reason(who: int) -> String:
	"""Why `who` cannot be given work by the player now ("" when it can: a direct order takes it off what it does, and
	wakes a sleeper as any order does -- decision 0210)."""
	if who < 0 or who >= _brains.size():
		return UNKNOWN
	var brain: BrainScript = _brains[who]
	if brain.water_hold:
		return HELD
	if brain.in_water:
		return IN_WATER
	return ""


# --- the player's priorities ------------------------------------------------------------------------------

func task_priority(task_source: int, row: int) -> int:
	"""The task's priority (REQ-SET-026; NORMAL until the player sets one)."""
	if not _known(task_source, row):
		return WorkIds.PRIORITY_NORMAL
	return _priority[task_source][row]


func is_urgent(task_source: int, row: int) -> bool:
	"""Whether the player marked the task URGENT."""
	return _known(task_source, row) and _urgent[task_source][row] == 1


func _known(task_source: int, row: int) -> bool:
	"""Whether the priority kept on that row is the current task's (a reused row starts NORMAL again)."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= _priority_key[task_source].size() or not src.live(row):
		return false
	return _priority_key[task_source][row] == src.key(row)


func set_task_priority(task_source: int, row: int, value: int) -> bool:
	"""Set the task's priority (1 highest .. 4 low). False for no such task or priority."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row) or value < WorkIds.PRIORITY_HIGHEST \
			or value > WorkIds.PRIORITY_LOW:
		return false
	_adopt(task_source, row)
	_priority[task_source][row] = value
	revision += 1
	return true


func raise_priority(task_source: int, row: int, by: int) -> bool:
	"""Move the task's priority `by` steps (negative: up, toward highest), clamped to 1..4."""
	var value: int = clampi(task_priority(task_source, row) + by, WorkIds.PRIORITY_HIGHEST, WorkIds.PRIORITY_LOW)
	return set_task_priority(task_source, row, value)


func set_urgent(task_source: int, row: int, on: bool) -> bool:
	"""Mark the task URGENT (taken before every ordinary task: bucket 2), or not."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row):
		return false
	_adopt(task_source, row)
	_urgent[task_source][row] = 1 if on else 0
	revision += 1
	return true


func _adopt(task_source: int, row: int) -> void:
	"""Make the row's priority the current task's, starting it afresh for a new task."""
	var current: int = _sources[task_source].key(row)
	if _priority_key[task_source][row] != current:
		_priority_key[task_source][row] = current
		_priority[task_source][row] = WorkIds.PRIORITY_NORMAL
		_urgent[task_source][row] = 0


# --- the per-task commands ----------------------------------------------------------------------------------

func fill(task_source: int, row: int, task: TaskScript) -> bool:
	"""The task's record for the Work screen. False when there is no such task."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row):
		return false
	src.fill(task, row)
	return true


func pause(task_source: int, row: int, on: bool) -> String:
	"""Pause the task, or resume it (the owner's own function): "" when done, else why not."""
	return _done(_command_source(task_source, row), func(src: SourceScript) -> String: return src.pause(row, on))


func cancel(task_source: int, row: int) -> String:
	"""Cancel this task alone (the owner's own function: a load in hand is still delivered): "" when done."""
	return _done(_command_source(task_source, row), func(src: SourceScript) -> String: return src.cancel(row))


func reassign(task_source: int, row: int, who: int) -> String:
	"""Give the task to `who` instead, taken off whatever it was doing: "" when done, else why not."""
	var why: String = eligibility_words(task_source, row, who)
	if not why.is_empty():
		return why
	var said: String = _done(_command_source(task_source, row),
		func(src: SourceScript) -> String: return src.reassign(row, who))
	if said.is_empty():
		_brains[who].forget_task(task_source, _sources[task_source].key(row))
	return said


func _command_source(task_source: int, row: int) -> SourceScript:
	"""The adapter a command on (source, row) goes to (null: no such task)."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row):
		return null
	return src


func _done(src: SourceScript, command: Callable) -> String:
	"""Run a command on a task's adapter; a success changes what the Work screen shows."""
	if src == null:
		return WorkIds.NOT_FOUND
	var said: String = String(command.call(src))
	if said.is_empty():
		revision += 1
		_next_index_usec = _clock_usec
	return said


func eligibility_words(task_source: int, row: int, who: int) -> String:
	"""Whether `who` could take the task now, in words ("" when it could): the player's grammar for the Reassign
	picker and a group order's preview -- the resident's own state, then the source's rule."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row):
		return WorkIds.NOT_FOUND
	var why: String = busy_reason(who)
	if not why.is_empty():
		return why
	return src.eligibility(row, who)


func has_job(who: int) -> bool:
	"""Whether resident `who` holds a task on some board."""
	for src: SourceScript in _sources:
		if src == null:
			continue
		for row: int in src.capacity():
			if src.live(row) and src.worker(row) == who:
				return true
	return false


func go_to_resident(who: int) -> bool:
	"""Select resident `who` and centre the camera on it (the village's "Go to")."""
	if who < 0 or who >= _brains.size() or not _jump.is_valid():
		return false
	return bool(_jump.call(NoticesScript.TARGET_RESIDENT, who, _brains[who].surface_point()))


func jump(task_source: int, row: int) -> bool:
	"""Go to the task's target: select it and centre the camera on it (the village's "Go to")."""
	if not fill(task_source, row, _task) or not _jump.is_valid():
		return false
	return bool(_jump.call(_task.target_kind, _task.target_id, _task.point))


func cancel_all_counts_into(counts: PackedInt32Array) -> int:
	"""CANCEL ALL WORK's scope, before it is pressed: how many tasks it would cancel per source (counts, by
	WorkIds.SOURCE_*) and in all. A task whose own Cancel refuses (a delivery, a paid tunnel job, a bridge) is not
	counted: it goes on."""
	counts.resize(WorkIds.SOURCE_COUNT)
	counts.fill(0)
	var total: int = 0
	for src: SourceScript in _sources:
		if src == null:
			continue
		for row: int in src.capacity():
			if src.live(row) and _cancellable(src, row):
				counts[src.id] += 1
				total += 1
	return total


func _cancellable(src: SourceScript, row: int) -> bool:
	"""Whether the task's own Cancel would take it."""
	src.fill(_task, row)
	return _task.cancel_refusal.is_empty()


func cancel_all() -> int:
	"""CANCEL ALL WORK: every task whose own Cancel takes it (see `cancel_all_counts_into`). How many were cancelled."""
	var done: int = 0
	for src: SourceScript in _sources:
		if src == null:
			continue
		for row: int in src.capacity():
			if src.live(row) and _cancellable(src, row) and src.cancel(row).is_empty():
				done += 1
	if done > 0:
		revision += 1
	return done


# --- the order lists (see resident_brain.gd THE ORDER LIST) -----------------------------------------------

func queue_task(task_source: int, row: int, who: int) -> String:
	"""Append the task to `who`'s order list (Shift+right-click): it is left to `who` until it takes it up -- now, when
	`who` is idle. "" when queued, else why not."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row):
		return WorkIds.NOT_FOUND
	src.fill(_task, row)
	var words: String = "%s, %s" % [_task.action, _task.target]
	var entry: UnfinishedScript = OrderList.task_entry(self, task_source, row, src.key(row), words)
	return _append(who, entry)


func queue_walk(who: int, to: Vector2) -> String:
	"""Append a walk to `to` to `who`'s order list. "" when queued, else why not."""
	return _append(who, OrderList.walk_entry(self, to))


func _append(who: int, entry: UnfinishedScript) -> String:
	"""Append `entry` to `who`'s list and take it up at once when `who` has nothing else to do."""
	if who < 0 or who >= _brains.size():
		return UNKNOWN
	var brain: BrainScript = _brains[who]
	if not brain.append_queued(entry):
		return LIST_FULL % [name_of(who), BrainScript.QUEUE_MAX]
	revision += 1
	_next_index_usec = _clock_usec
	_start_list(who, brain)
	return ""


func _start_list(who: int, brain: BrainScript) -> void:
	"""A queued order's turn as `who` stands now: taken up at once when it has nothing to do (or works at a spot -- an
	order with no end of its own); after a plain move, once the move arrives (`track_walk`). Any other work -- a job,
	a task -- hands it on when it is done."""
	if brain.resting or brain.water_hold or brain.in_water:
		return
	if brain.order == BrainScript.ORDER_NONE or brain.order == BrainScript.ORDER_WORK:
		brain.take_up_unfinished()
	elif brain.order == BrainScript.ORDER_MOVE and _walking[who] == 0 and not has_job(who):
		track_walk(who, brain.goal())


func take_back_task(brain: RefCounted, task_source: int, row: int, task_key: int) -> bool:
	"""A queued task's turn (order_list.gd QueuedTask): give it to this resident if it is still the same task and
	still waits."""
	var src: SourceScript = source(task_source)
	if src == null or row < 0 or row >= src.capacity() or not src.live(row) or src.key(row) != task_key:
		return false
	var who: int = (brain as BrainScript).index
	if not src.waiting(row) or not src.eligibility(row, who).is_empty():
		return false
	if not src.claim(row, who):
		return false
	revision += 1
	return true


func track_walk(who: int, goal: Vector2) -> void:
	"""A queued walk has begun (order_list.gd QueuedWalk): end it when `who` arrives there or gives it up."""
	if who < 0 or who >= _walking.size():
		return
	_walking[who] = 1
	_walk_goal[who] = goal


func _run_walks() -> void:
	"""End each queued walk whose resident arrived (or gave the walk up): on to its next entry (`work_done`). One taken
	off its walk by another order is simply no longer watched."""
	for who: int in _walking.size():
		if _walking[who] == 0:
			continue
		var brain: BrainScript = _brains[who]
		if brain.order != BrainScript.ORDER_MOVE or brain.goal() != _walk_goal[who]:
			_walking[who] = 0
			continue
		if brain.state != BrainScript.State.HOLD:
			continue
		if brain.arrived_near(_walk_goal[who], WALK_DONE_M) or brain.trip_failed():
			_walking[who] = 0
			brain.work_done()


func remove_entry(who: int, k: int) -> bool:
	"""Remove entry `k` (take order) from `who`'s order list."""
	if who < 0 or who >= _brains.size() or not _brains[who].remove_queued(k):
		return false
	revision += 1
	_next_index_usec = _clock_usec
	return true


func move_entry(who: int, k: int, by: int) -> bool:
	"""Move entry `k` (take order) of `who`'s order list `by` places later (negative: sooner)."""
	if who < 0 or who >= _brains.size() or not _brains[who].move_queued(k, by):
		return false
	revision += 1
	return true


func resume_words(task_source: int, task_key: int) -> String:
	"""The task's RESUME INTENT: who means to come back to it or has it queued ("" for nobody) -- every order list
	read, so it is right the moment a list changes."""
	for who: int in _brains.size():
		var brain: BrainScript = _brains[who]
		for k: int in brain.queue_size():
			var entry: UnfinishedScript = brain.queue_entry(k)
			if entry.names_task(task_source, task_key):
				return ("queued for %s (%s)" if entry.queued else "%s comes back to it (%s)") % [name_of(who),
					_ordinal(k + 1)]
	return ""


static func _ordinal(n: int) -> String:
	"""1st, 2nd, 3rd, 4th ... (the place in the list)."""
	if n == 1:
		return "next"
	var suffix: String = "th"
	if n % 10 == 2 and n % 100 != 12:
		suffix = "nd"
	elif n % 10 == 3 and n % 100 != 13:
		suffix = "rd"
	return "%d%s" % [n, suffix]


# --- the one assignment grammar (decision 0332's, review F44's remainder and UX-001) -----------------------

func queue_words(activity: int, selected: int) -> String:
	"""The action card's "who" for an order left on the board: the crew that prefers its activity first, then anyone
	free who can -- "Queue for the Field crew: Mouse fieldworker or Squirrel gatherer, then anyone free who can"."""
	var crew: int = CrewsScript.PREFERRED.find(activity)
	var names := PackedStringArray()
	crews.members_into(crew, _members)
	for who: int in _members:
		names.append(name_of(who))
	var head: String = "Queue for the %s crew" % CrewsScript.CREW_NAMES[crew]
	if selected > 0:
		head += " (no selected resident is free for it)"
	if names.is_empty():
		return head + ": nobody is on it — anyone free who can takes it"
	return "%s: %s, then anyone free who can" % [head, " or ".join(names)]


func members_words(task_source: int, row: int, members: PackedInt32Array) -> String:
	"""A group order's preview, member by member (UX-001): "Of 3 selected: Mouse keeper, Mole digger can; Badger
	quarryman can't (does not fit this tunnel's bore)" -- each member's own eligibility for the task (empty for one
	selected or none)."""
	var names := PackedStringArray()
	var refusals := PackedStringArray()
	for who: int in members:
		names.append(name_of(who))
		refusals.append(eligibility_words(task_source, row, who))
	return CardScript.each_member(names, refusals)
