extends RefCounted
## Clearing a spoil heap: residents dig it out a basketful at a time and haul it to the farm's compost
## store. Decision 0205 (the playtest of 2026-09-29: "Ability to select dirt piles, and have workers dig
## and remove the dirt piles"). Presentation over the farm's real spoil accounting; nothing here
## feeds the simulation.
##
## WHERE IT GOES. The spoil has one use in the demo already: the farm's Compost job digs it off a heap
## as a bed's compost (farm_jobs.gd COMPOST_FROM_SPOIL_PLAN), and planting a sapling spends the farm's
## compost store. So a cleared heap's spoil goes into that store (`deliver(milli)`, the farm's
## compost_milli), carried to the drop spot by the open stockpile. Every milli-U taken off the heap
## (farm_tunnels.gd `take_spoil_into`, the same books Raise and Bank take from) is delivered, or is in a
## worker's basket: `in_hand_milli()`. Nothing is made or lost.
##
## ONE ROW PER WORKER, cycling GO (to a spot beside the heap) -> DIG (DIG_USEC a load, the dig clip) ->
## CARRY (the carry walk, a basket in hand) -> DROP (DROP_USEC) -> GO, until the heap is empty; the
## last load out retires the heap: it stops being an obstacle and is no longer drawn. A worker taken
## off by another order leaves its load where the row keeps it (delivered when the row is ended) and
## keeps the job to come back to (resident_brain.gd RESUMING). Only a finished tunnel's heaps are
## cleared: a heap still growing under a dig is refused.
##
## ARRIVING IS EXPLICIT (decision 0361, the review's F05). A worker holding is not a worker arrived: one whose walk was
## given up holds too, its goal unchanged. A walk step ends only when the brain's trip ARRIVED and the worker stands
## within ARRIVE_M of its spot (resident_brain.gd `arrived_near`), and the dig and the drop recheck that every frame. A
## walk that failed PAUSES the row -- nothing dug, nothing delivered, a basket kept in hand -- and it is tried again
## after RETRY_USEC (`blocked`: the party panel says the worker can't reach it); a worker found off its spot while
## working walks back to it before any more work is done.

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const FarmTunnels := preload("res://demo/farm/farm_tunnels.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## A basketful: the farm's own load off a heap (farm_jobs.gd SPOIL_PER_JOB_MILLI, the §5.6 compost dose).
const LOAD_MILLI: int = FarmJobs.SPOIL_PER_JOB_MILLI
## Digging a load out and tipping it: the farm's dig and drop work (WU) at its demo rate.
const DIG_USEC: int = FarmJobs.WORK_WU[FarmJobs.WORK_DIG] * FarmJobs.DEMO_USEC_PER_WU
const DROP_USEC: int = FarmJobs.WORK_WU[FarmJobs.WORK_DROP] * FarmJobs.DEMO_USEC_PER_WU
## At most this many work one heap at once (demo value: round a heap of a metre or two).
const MAX_PER_HEAP: int = 4
const MAX_ROWS: int = 8
const STEP_GO: int = 0
const STEP_DIG: int = 1
const STEP_CARRY: int = 2
const STEP_DROP: int = 3
const NOBODY: int = -1
## Standing: HEAP_STAND_M beyond the heap's rim, then rings RING_GAP_M apart (farm_crew.gd's values).
const HEAP_STAND_M: float = 0.55
const RING_GAP_M: float = 0.45
const RINGS: int = 4
const RING_SPOTS: int = 12
const ARRIVE_M: float = 0.4
## A row whose walk failed waits this long before it tries again (see ARRIVING IS EXPLICIT; demo value).
const RETRY_USEC: int = 3000000
const BASKET_KEY: StringName = &"basket"
const DIG_CLIP_FALLBACK: StringName = &"collect_object"

var heap: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var step: PackedInt32Array = PackedInt32Array()
var load_milli: PackedInt64Array = PackedInt64Array()
var work_usec: PackedInt64Array = PackedInt64Array()
var issued: PackedByteArray = PackedByteArray()
var goal: PackedVector2Array = PackedVector2Array()
## Per row: 1 while its walk failed and it waits to try again, and how much longer (see ARRIVING IS EXPLICIT).
var blocked: PackedByteArray = PackedByteArray()
var wait_usec: PackedInt64Array = PackedInt64Array()
## Spoil delivered to the compost store by clearing, milli-U (the books' other side).
var delivered_milli: int = 0
## Heaps emptied and taken off the obstacles (checks).
var retired_heaps: int = 0
var revision: int = 0

var _cast: DemoCastScript = null
var _network: GraphScript = null
var _tunnels: FarmTunnels = null
var _props: PropsScript = null
var _deliver: Callable = Callable()
var _drop_at: Vector2 = Vector2.ZERO
var _found: Vector2 = Vector2.ZERO
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _no_taken: PackedVector2Array = PackedVector2Array()
## 1 for a heap cleared and taken off the obstacles (until it takes spoil again).
var _retired: PackedByteArray = PackedByteArray()


func _init() -> void:
	"""An empty board (packed columns are values: each is sized by name)."""
	heap.resize(MAX_ROWS)
	worker.resize(MAX_ROWS)
	step.resize(MAX_ROWS)
	load_milli.resize(MAX_ROWS)
	work_usec.resize(MAX_ROWS)
	issued.resize(MAX_ROWS)
	goal.resize(MAX_ROWS)
	blocked.resize(MAX_ROWS)
	wait_usec.resize(MAX_ROWS)
	worker.fill(NOBODY)
	heap.fill(-1)
	_retired.resize(FarmTunnels.HEAPS)


func configure(cast: DemoCastScript, network: GraphScript, tunnels: FarmTunnels, props: PropsScript,
		deliver: Callable, drop_at: Vector2) -> void:
	"""Work this cast on this network's heaps, taking spoil through the farm's books (`tunnels`) and
	delivering it by `deliver(milli: int)` at `drop_at` (metres, x z)."""
	_cast = cast
	_network = network
	_tunnels = tunnels
	_props = props
	_deliver = deliver
	_drop_at = drop_at


# --- the heaps ----------------------------------------------------------------------------------

func spoil_left(h: int) -> int:
	"""The spoil still on heap `h` (a mouth row of the network), milli-U (0 for none or a bad heap)."""
	if h < 0 or h >= FarmTunnels.HEAPS or _network.heap_radius_m[h] <= 0.0:
		return 0
	return _tunnels.spoil_left(_network, h)


func refusal(h: int) -> String:
	"""Why heap `h` cannot be cleared now, in words ("" when it can)."""
	if spoil_left(h) <= 0:
		return "there is no spoil there"
	if _network.mouth_growing(h):
		return "its tunnel is still being dug"
	return ""


func workers_on(h: int) -> int:
	"""How many work heap `h`."""
	var n: int = 0
	for row: int in MAX_ROWS:
		if worker[row] != NOBODY and heap[row] == h:
			n += 1
	return n


func row_of(who: int) -> int:
	"""The row resident `who` works, or -1."""
	for row: int in MAX_ROWS:
		if worker[row] == who:
			return row
	return -1


func in_hand_milli() -> int:
	"""Spoil taken off heaps and not yet delivered (in baskets), milli-U."""
	var total: int = 0
	for row: int in MAX_ROWS:
		if worker[row] != NOBODY:
			total += load_milli[row]
	return total


# --- ordering -----------------------------------------------------------------------------------

func order(h: int, members: PackedInt32Array) -> String:
	"""Set `members` who can carry to clearing heap `h` (at most MAX_PER_HEAP on it). Says what happened."""
	var why: String = refusal(h)
	if not why.is_empty():
		return "Can't clear the spoil: " + why
	var sent := PackedStringArray()
	for who: int in members:
		if workers_on(h) >= MAX_PER_HEAP:
			break
		if _take(h, who):
			sent.append((_cast.actor(who) as DemoActorScript).display_name)
	if sent.is_empty():
		return "Can't clear the spoil: nobody selected can carry it"
	return "Clearing the spoil heap (%.1f U): %s" % [spoil_left(h) / 1000.0, ", ".join(sent)]


func _take(h: int, who: int) -> bool:
	"""Give resident `who` a row on heap `h` (ending any row it had). False when it cannot carry, or the
	board is full."""
	if who < 0 or who >= _cast.actor_count() or not _brain(who).can_carry():
		return false
	var had: int = row_of(who)
	if had >= 0:
		_deliver_load(had)
		_hold_basket(who, false)
		_close(had)
	for row: int in MAX_ROWS:
		if worker[row] == NOBODY:
			_open_row(row, h, who)
			return true
	return false


func _open_row(row: int, h: int, who: int) -> void:
	"""A fresh row: `who` on heap `h`, walking to it first."""
	heap[row] = h
	worker[row] = who
	step[row] = STEP_GO
	load_milli[row] = 0
	work_usec[row] = 0
	issued[row] = 0
	blocked[row] = 0
	revision += 1


func take_back(brain: RefCounted, h: int) -> bool:
	"""Give heap `h` back to the resident taken off it (resident_brain.gd RESUMING), while it has spoil,
	its tunnel is finished and there is room on it."""
	if not refusal(h).is_empty() or workers_on(h) >= MAX_PER_HEAP:
		return false
	return _take(h, int(brain.get(&"index")))


# --- the work -----------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""One frame of every row, `usec` microseconds of demo time (0 while paused)."""
	_restore_regrown()
	for row: int in MAX_ROWS:
		if worker[row] == NOBODY:
			continue
		if step[row] == STEP_GO or step[row] == STEP_CARRY:
			_step_walk(row, usec)
		else:
			_step_work(row, usec)


func _step_walk(row: int, usec: int) -> void:
	"""Issue the walk, then wait for the worker to ARRIVE at its spot; a walk given up pauses the row (see ARRIVING IS
	EXPLICIT). Taken off by another order, the row ends and the worker keeps the job to come back to."""
	var brain: BrainScript = _brain(worker[row])
	if issued[row] == 0:
		_issue_walk(row, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != goal[row]:
		_called_away(row, brain)
		return
	if blocked[row] == 1:
		_wait_to_retry(row, usec)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if brain.arrived_near(goal[row], ARRIVE_M):
		step[row] += 1
		issued[row] = 0
		work_usec[row] = 0
		return
	_pause(row, brain)


func _pause(row: int, brain: BrainScript) -> void:
	"""The walk failed: wait RETRY_USEC where it stands (its basket kept), then try again (see ARRIVING IS EXPLICIT)."""
	blocked[row] = 1
	wait_usec[row] = RETRY_USEC
	issued[row] = 1
	goal[row] = brain.goal()
	revision += 1


func _wait_to_retry(row: int, usec: int) -> void:
	"""Count a paused row down; then issue its walk afresh."""
	wait_usec[row] -= usec
	if wait_usec[row] > 0:
		return
	blocked[row] = 0
	issued[row] = 0
	revision += 1


func _issue_walk(row: int, brain: BrainScript) -> void:
	"""Send the worker beside the heap, or with its basket to the drop spot."""
	var carry: bool = step[row] == STEP_CARRY
	var target: Vector2 = _drop_at if carry else _network.heap_at[heap[row]]
	var first: float = 0.0 if carry else _network.heap_radius_m[heap[row]] + HEAP_STAND_M
	if not _spot_near(target, first, brain):
		if carry:
			_pause(row, brain)  # nowhere reachable to tip: the basket is kept, never delivered from here
		else:
			_end_row(row)
		return
	goal[row] = _found
	issued[row] = 1
	if carry:
		brain.order_carry(_found, target)
		_hold_basket(worker[row], true)
	else:
		brain.order_move(_found, target)


func _step_work(row: int, usec: int) -> void:
	"""Dig a load (then carry it) or tip it into the store (then go back for more, or finish)."""
	var brain: BrainScript = _brain(worker[row])
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_called_away(row, brain)
		return
	if not brain.arrived_near(goal[row], ARRIVE_M):
		step[row] -= 1  # off its spot: back to it before any more work (see ARRIVING IS EXPLICIT)
		issued[row] = 0
		work_usec[row] = 0
		return
	brain.play_in_place(_dig_clip(brain) if step[row] == STEP_DIG else BrainScript.CLIP_IDLE)
	work_usec[row] += usec
	if step[row] == STEP_DIG and work_usec[row] >= DIG_USEC:
		_dig_load(row)
	elif step[row] == STEP_DROP and work_usec[row] >= DROP_USEC:
		_tip_load(row)


func _dig_load(row: int) -> void:
	"""Take a basketful (or what is left) off the heap and set off with it; an emptied heap retires."""
	var h: int = heap[row]
	var milli: int = mini(LOAD_MILLI, spoil_left(h))
	if milli <= 0 or not _tunnels.take_spoil_into(_network, h, milli, _read):
		_end_row(row)
		return
	load_milli[row] = milli
	step[row] = STEP_CARRY
	issued[row] = 0
	revision += 1
	if spoil_left(h) <= 0:
		_retire(h)


func _tip_load(row: int) -> void:
	"""Deliver the basket into the compost store; back for more while the heap has any."""
	_deliver_load(row)
	_hold_basket(worker[row], false)
	if spoil_left(heap[row]) > 0:
		step[row] = STEP_GO
		issued[row] = 0
		return
	_end_row(row)


func _deliver_load(row: int) -> void:
	"""Put the row's basket into the store (all of it: the books balance)."""
	if load_milli[row] <= 0:
		return
	if _deliver.is_valid():
		_deliver.call(int(load_milli[row]))
	delivered_milli += int(load_milli[row])
	load_milli[row] = 0
	revision += 1


func _called_away(row: int, brain: BrainScript) -> void:
	"""The worker was ordered away: its basket goes into the store (nothing is lost), the row ends, and
	it keeps the heap to come back to while there is spoil on it -- unless the player released it (R)."""
	var h: int = heap[row]
	_deliver_load(row)
	_hold_basket(worker[row], false)
	_close(row)
	if spoil_left(h) > 0 and brain.order != BrainScript.ORDER_NONE:
		brain.remember_unfinished(UnfinishedScript.new(take_back.bind(h), "Clear spoil heap"))


func _end_row(row: int) -> void:
	"""The row is done: deliver any basket, and send the worker back to what it was doing before."""
	var who: int = worker[row]
	_deliver_load(row)
	_hold_basket(who, false)
	_close(row)
	var brain: BrainScript = _brain(who)
	brain.play_in_place(BrainScript.CLIP_IDLE)
	brain.work_done()


func _close(row: int) -> void:
	"""Free the row."""
	worker[row] = NOBODY
	heap[row] = -1
	load_milli[row] = 0
	revision += 1


func _retire(h: int) -> void:
	"""An emptied heap is no longer an obstacle (the farm's view already stops drawing a heap with nothing
	left, farm_view.gd `_shrink_heaps`). Its spot stays in the network, where a widening re-heaps."""
	_set_circle(h)
	_retired[h] = 1
	retired_heaps += 1


func _restore_regrown() -> void:
	"""A retired heap that took spoil again (a fall cleared or a chamber dug off its tunnel) is an
	obstacle again."""
	for h: int in FarmTunnels.HEAPS:
		if _retired[h] == 1 and spoil_left(h) > 0:
			_retired[h] = 0
			_set_circle(h)


func _set_circle(h: int) -> void:
	"""Heap `h` as an obstacle: at its placed radius while it holds spoil, none when it is empty."""
	var r: float = _network.heap_radius_m[h] if spoil_left(h) > 0 else 0.0
	_cast.space().set_heap(h, Vector3(_network.heap_at[h].x, r, _network.heap_at[h].y) if r > 0.0 else Vector3.ZERO)


# --- helpers ------------------------------------------------------------------------------------

func _brain(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _dig_clip(brain: BrainScript) -> StringName:
	"""The creature's digging clip, else its collecting one."""
	var clip: StringName = brain.dig_clip()
	return clip if brain.has_clip(clip) else DIG_CLIP_FALLBACK


func _hold_basket(who: int, on: bool) -> void:
	"""A basket in the worker's arms while it carries (none without staged props)."""
	var actor := _cast.actor(who) as DemoActorScript
	if not on:
		if actor.holding():
			actor.drop_held()
		return
	if _props == null:
		return
	var bound: AABB = _props.drawn_bound(BASKET_KEY)
	actor.hold(_props.mesh_of(BASKET_KEY), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(BASKET_KEY))


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript) -> bool:
	"""The standable, reachable spot nearest the worker on rings round `target`, clear of anyone
	standing (cast_orders.spot_ok), into `_found`. False when no ring has one."""
	var from: Vector2 = brain.surface_point()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(_cast.space(), members)
	for ring: int in RINGS:
		var radius: float = first_ring + RING_GAP_M * ring
		var found: bool = false
		for k: int in (1 if radius <= 0.0 else RING_SPOTS):
			var spot: Vector2 = target + Vector2.from_angle(TAU * k / RING_SPOTS) * radius
			if found and spot.distance_squared_to(from) >= _found.distance_squared_to(from):
				continue
			if CastOrdersScript.spot_ok(_cast.space(), spot, brain.radius, _cast.bounds(), avoid, _no_taken, from):
				_found = spot
				found = true
		if found:
			return true
	return false
