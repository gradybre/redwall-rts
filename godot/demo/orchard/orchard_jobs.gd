extends RefCounted
## THE ORCHARD'S WORK (decisions 0671-0677): one board of jobs, its rows packed columns, each job a short PROGRAM of
## steps -- walk to its place, work there, carry what it made -- that a resident is driven through by orchard_task.gd.
## The work board (demo/work/orchard_work.gd, source SOURCE_ORCHARD) lists and claims them; this owner decides every
## outcome. Presentation only.
##
## THE KINDS and their places:
##   TEND       the tree's §5.6 care, 20 WU a day in spring and summer (water 2 U from the butt during a drought).
##   HARVEST    pick the tree (BAL-CAT-010: 80 WU for a mature block; decision 0672's early harvest in its share),
##              then carry the fruit to the group's basket stand (ECO-010's gathering point).
##   PICK       pick a basket from the hedge (§5.5: 4 WU a U) and carry it to the east orchard's stand.
##   HAUL       load a basket at the stand (2 WU), carry it on to the group's destination store, unload it (2 WU).
##   PLANT      plant a sapling on its site (BAL-CAT-010: 40 WU), with compost 4 U (§5.6).
##   PROPAGATE  the nursery's 120 WU for a plan (§5.6: fruit 4 + compost 2 + water 2), then its 12-day wait.
##   OBSERVE    the grove's seasonal observation (ECO-015).
##
## CONSERVATION (decision 0222's rules, as the farm's and the fishery's): ROOM FIRST -- a harvest or a picking reserves
## room at its stand before anything is cut, and a haul reserves room at its destination before it loads; with none it
## waits, saying so. A load in hand is a DELIVERY: Cancel refuses it, the night waits for it, and a carrier called away
## sets it down where it stands for the next to carry on. A haul moves food from its lot at the stand to the store
## (farm_pantry.gd `move_upto_into`): the food keeps its age and the ledger counts it once. Planting, propagating and
## drought tending check their inputs when the work starts and take them when it is done, so a cancelled job owes
## nothing back (a PROPOSAL of decision 0671: §5.7 production takes its inputs at the start).
##
## ROUTINE (`plan_work`, each game hour): a tending for every tree that needs it, a harvest for every tree that may be
## picked (by its group's TIMING), a picking while the hedge has fruit above its floor, a haul while a stand holds more
## than its group keeps, a planting for every plan whose sapling is ready, a propagation for every plan waiting, and the
## grove's observation once a season. A job the player cancels is not raised again that day.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const TaskScript := preload("res://demo/orchard/orchard_task.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MAX_JOBS: int = 16
const NONE: int = -1
const K_TEND: int = Rules.K_TEND
const K_HARVEST: int = Rules.K_HARVEST
const K_PICK: int = Rules.K_PICK
const K_HAUL: int = Rules.K_HAUL
const K_PLANT: int = Rules.K_PLANT
const K_PROPAGATE: int = Rules.K_PROPAGATE
const K_OBSERVE: int = Rules.K_OBSERVE
const KIND_COUNT: int = Rules.KIND_COUNT
const S_GO: int = 0
const S_WORK: int = 1
const S_CARRY: int = 2
const S_UNLOAD: int = 3
## Each kind's program, PROGRAM_STRIDE steps a kind (NONE: past its end): tend, harvest, pick, haul, plant, propagate,
## observe.
const PROGRAM_STRIDE: int = 4
const PROGRAMS: PackedInt32Array = [
	S_GO, S_WORK, NONE, NONE,
	S_GO, S_WORK, S_CARRY, NONE,
	S_GO, S_WORK, S_CARRY, NONE,
	S_GO, S_WORK, S_CARRY, S_UNLOAD,
	S_GO, S_WORK, NONE, NONE,
	S_GO, S_WORK, NONE, NONE,
	S_GO, S_WORK, NONE, NONE,
]
const ORIGIN_ROUTINE: int = 0
const ORIGIN_PLAYER: int = 1
## Targets a kind has at most (sites 4, bushes 3, groups 2, plans 6, the grove 1): the cancelled-today table's stride.
const MAX_TARGETS: int = 8
const ARRIVE_M: float = 0.6
## Where a worker stands to work a tree: this far from its trunk, toward its stand.
const TRUNK_REACH_M: float = 1.5
const FREE_SPOT_RINGS: int = 4
const FREE_SPOT_STEP_M: float = 0.45
const MAX_TRIES: int = 3
const CLIP_PICK: StringName = &"collect_object"
const CLIP_DIG: StringName = &"pull_radish"
const CLIP_WATCH: StringName = &"idle"

var model: ModelScript = null
var pantry: PantryScript = null
var stores: StoresScript = null
var calendar: CalendarScript = null
var weather: DemoWeatherScript = null
## `say(text, warning)`: the village news (demo_orchard.gd posts it to the feed, place Farm).
var say: Callable = Callable()
## `grove_trees() -> int`: the woods' trees standing in the grove (the observation's count).
var grove_trees: Callable = Callable()
var revision: int = 0

# The rows.
var live: PackedByteArray = PackedByteArray()
var serial: PackedInt32Array = PackedInt32Array()
var kind: PackedInt32Array = PackedInt32Array()
var target: PackedInt32Array = PackedInt32Array()
var origin: PackedInt32Array = PackedInt32Array()
var worker: PackedInt32Array = PackedInt32Array()
var paused: PackedByteArray = PackedByteArray()
var wait_usec: PackedInt64Array = PackedInt64Array()
var pos: PackedInt32Array = PackedInt32Array()
var goal: PackedVector2Array = PackedVector2Array()
## 0: not walking; 1: walking; 2: arrived (handled on its next frame).
var issued: PackedByteArray = PackedByteArray()
var at_work: PackedByteArray = PackedByteArray()
var need_mwu: PackedInt32Array = PackedInt32Array()
var done_mwu: PackedInt32Array = PackedInt32Array()
var num: PackedInt64Array = PackedInt64Array()
var species: PackedInt32Array = PackedInt32Array()
var load_item: PackedInt32Array = PackedInt32Array()
var load_milli: PackedInt64Array = PackedInt64Array()
## Where a load was set down (INF: in hand, or none).
var load_at: PackedVector2Array = PackedVector2Array()
var hold: PackedInt32Array = PackedInt32Array()
var lot: PackedInt32Array = PackedInt32Array()
var lot_serial: PackedInt32Array = PackedInt32Array()
## 1 while the job waits for room (a full store or a full reservation table), not for want of work.
var room_wait: PackedByteArray = PackedByteArray()
## The serial of the plan a propagation works (a dropped plan's row reused by another is not this one).
var target_serial: PackedInt32Array = PackedInt32Array()
var tries: PackedInt32Array = PackedInt32Array()
var words: PackedStringArray = PackedStringArray()

var _cast: DemoCastScript = null
var _compost_left: Callable = Callable()
var _take_compost: Callable = Callable()
var _tasks: Array = []
var _next_serial: int = 1
var _driving: int = NONE
var _cancelled_day: PackedInt32Array = PackedInt32Array()
var _hour_seen: int = -1
var _pick_turn: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _no_spots: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	"""An empty board."""
	for column: PackedByteArray in [live, paused, issued, at_work, room_wait]:
		column.resize(MAX_JOBS)
	for column: PackedInt32Array in [serial, kind, target, origin, worker, pos, need_mwu, done_mwu, species, load_item,
			hold, lot, lot_serial, target_serial, tries]:
		column.resize(MAX_JOBS)
	for column: PackedInt64Array in [wait_usec, num, load_milli]:
		column.resize(MAX_JOBS)
	goal.resize(MAX_JOBS)
	load_at.resize(MAX_JOBS)
	words.resize(MAX_JOBS)
	_tasks.resize(MAX_JOBS)
	_cancelled_day.resize(KIND_COUNT * MAX_TARGETS)
	worker.fill(NONE)


func configure(p_model: ModelScript, p_cast: DemoCastScript, p_pantry: PantryScript, p_stores: StoresScript,
		p_calendar: CalendarScript, p_weather: DemoWeatherScript) -> void:
	"""Work `p_model`'s orchard with `p_cast`'s residents, into `p_pantry`, paying water from `p_stores`, on the one calendar
	and weather (any may be null in a check: no worker, no store)."""
	model = p_model
	_cast = p_cast
	pantry = p_pantry
	stores = p_stores
	calendar = p_calendar
	weather = p_weather


func set_compost(left: Callable, take: Callable) -> void:
	"""The farm's compost store: `left() -> int` milli-U, `take(milli) -> bool` all or none (demo_village.gd)."""
	_compost_left = left
	_take_compost = take


# --- the rows ---------------------------------------------------------------------------------------------------------

func is_job(j: int, job_serial: int) -> bool:
	"""Whether row `j` still holds the job opened with `job_serial`."""
	return j >= 0 and j < MAX_JOBS and live[j] == 1 and serial[j] == job_serial


func is_live(j: int) -> bool:
	"""Whether row `j` holds a job."""
	return j >= 0 and j < MAX_JOBS and live[j] == 1


func find(job_kind: int, job_target: int) -> int:
	"""The live job of `job_kind` on `job_target` (NONE: none)."""
	for j: int in MAX_JOBS:
		if live[j] == 1 and kind[j] == job_kind and target[j] == job_target:
			return j
	return NONE


func count_of(job_kind: int, job_target: int) -> int:
	"""How many live jobs of `job_kind` there are on `job_target` (NONE: on any)."""
	var n: int = 0
	for j: int in MAX_JOBS:
		if live[j] == 1 and kind[j] == job_kind and (job_target == NONE or target[j] == job_target):
			n += 1
	return n


func open_into(job_kind: int, job_target: int, job_origin: int, out: IntMath.IntResult) -> bool:
	"""Open a job of `job_kind` on `job_target`; its row into `out`. One job of a kind on a target at a time (a second
	is the first: `out` holds it and the answer is true); refuses a full board."""
	var have: int = find(job_kind, job_target)
	if have != NONE:
		origin[have] = maxi(origin[have], job_origin)
		return out.succeed(have)
	var j: int = Array(live).find(0)
	if j < 0:
		return out.refuse("ORCHARD_BOARD_FULL")
	_clear_row(j)
	live[j] = 1
	serial[j] = _next_serial
	_next_serial += 1
	kind[j] = job_kind
	target[j] = job_target
	origin[j] = job_origin
	revision += 1
	return out.succeed(j)


func _clear_row(j: int) -> void:
	"""Row `j` emptied."""
	live[j] = 0
	worker[j] = NONE
	paused[j] = 0
	wait_usec[j] = 0
	pos[j] = 0
	issued[j] = 0
	at_work[j] = 0
	need_mwu[j] = 0
	done_mwu[j] = 0
	num[j] = 0
	species[j] = NONE
	load_item[j] = NONE
	load_milli[j] = 0
	load_at[j] = Vector2.INF
	hold[j] = NONE
	lot[j] = NONE
	lot_serial[j] = 0
	room_wait[j] = 0
	target_serial[j] = 0
	tries[j] = 0
	words[j] = ""
	goal[j] = Vector2.ZERO


func _end_job(j: int) -> void:
	"""Close job `j`: its held room released, its worker sent back to its routine (from outside its own frame)."""
	var who: int = worker[j]
	if pantry != null and pantry.is_hold(hold[j]):
		pantry.release(hold[j])
	_tasks[j] = null
	_clear_row(j)
	if who != NONE and j != _driving and _cast != null:
		brain_of(who).work_done()
	revision += 1


func step_of(j: int) -> int:
	"""Job `j`'s current step (NONE: past its program)."""
	return PROGRAMS[kind[j] * PROGRAM_STRIDE + pos[j]] if pos[j] < PROGRAM_STRIDE else NONE


static func program_length(job_kind: int) -> int:
	"""How many steps `job_kind`'s program has."""
	var n: int = 0
	while n < PROGRAM_STRIDE and PROGRAMS[job_kind * PROGRAM_STRIDE + n] != NONE:
		n += 1
	return n


func carrying(j: int) -> bool:
	"""Whether job `j` has a load cut and not yet delivered (harvested fruit, picked berries, a basket loaded)."""
	return live[j] == 1 and load_milli[j] > 0


func in_hand(j: int) -> bool:
	"""Whether that load is in its worker's hands (not set down)."""
	return carrying(j) and worker[j] != NONE and not load_at[j].is_finite()


# --- the board's view -----------------------------------------------------------------------------------------------------

func waiting(j: int) -> bool:
	"""Whether job `j` waits for a resident and may be taken now."""
	return live[j] == 1 and worker[j] == NONE and paused[j] == 0 and wait_usec[j] <= 0


func eligibility(j: int, who: int) -> String:
	"""Why `who` may not take job `j` ("" when it may): one orchard job a resident, on land, above ground. Anybeast may
	tend, pick, haul and plant (LORE-P12): never a species lock."""
	if job_of_worker(who) != NONE and job_of_worker(who) != j:
		return Text.OTHER_JOB
	if _cast == null:
		return ""
	var brain: BrainScript = brain_of(who)
	if brain.water_hold or brain.in_water:
		return "in the water"
	return "is below ground" if brain.underground else ""


func job_of_worker(who: int) -> int:
	"""The job `who` works (NONE: none)."""
	for j: int in MAX_JOBS:
		if live[j] == 1 and worker[j] == who:
			return j
	return NONE


func claim(j: int, who: int) -> bool:
	"""Hand waiting job `j` to `who`, who sets off at once (the board's claim, or an order with residents selected)."""
	if not waiting(j) or not eligibility(j, who).is_empty() or _cast == null:
		return false
	var task := TaskScript.new(self, j, serial[j])
	worker[j] = who
	issued[j] = 1
	at_work[j] = 0
	_tasks[j] = task
	var brain: BrainScript = brain_of(who)
	brain.order_task(task)
	if brain.task != task:
		worker[j] = NONE
		_tasks[j] = null
		return false
	revision += 1
	return true


func activity_is_haul(j: int) -> bool:
	"""Whether job `j` is a haul (the Haulers' work); the rest are field work."""
	return kind[j] == K_HAUL


func point(j: int) -> Vector2:
	"""Where job `j` is now: its worker's goal, else where it starts (a set-down load's spot first)."""
	if worker[j] != NONE:
		return goal[j]
	return load_at[j] if load_at[j].is_finite() else place_of(j, step_of(j))


func remaining_usec(j: int) -> int:
	"""Demo microseconds of work left in job `j`'s current work step (its whole need before it starts)."""
	var need: int = need_mwu[j] if need_mwu[j] > 0 else _need_of(j, S_WORK)
	return Rules.work_usec(maxi(0, need - done_mwu[j]))


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name if _cast != null and who >= 0 else "a resident"


func cast() -> DemoCastScript:
	"""The cast the jobs are worked by."""
	return _cast


# --- places ---------------------------------------------------------------------------------------------------------------

func place_of(j: int, step: int) -> Vector2:
	"""Where job `j`'s `step` happens: at its target for S_GO and S_WORK, at its drop for S_CARRY and S_UNLOAD."""
	if step == S_CARRY or step == S_UNLOAD:
		return drop_of(j)
	match kind[j]:
		K_TEND, K_HARVEST, K_PLANT:
			return tree_spot(target[j])
		K_PICK:
			return Rules.BUSH_AT[target[j]] + Vector2(-1.0, 0.0)
		K_HAUL:
			return stand_at(target[j])
		K_PROPAGATE:
			return Rules.NURSERY_AT + Vector2(0.0, 1.0)
	return Rules.GROVE_AT


func tree_spot(site: int) -> Vector2:
	"""Where a worker stands at `site`'s tree: TRUNK_REACH_M from its trunk, toward its group's stand."""
	var centre: Vector2 = Rules.site_centre_m(site)
	var toward: Vector2 = (Rules.STAND_AT[Rules.SITE_GROUP[site]] - centre).normalized()
	return centre + toward * TRUNK_REACH_M


func drop_of(j: int) -> Vector2:
	"""Where job `j`'s load goes: its group's stand (a harvest, a picking), or its destination store (a haul)."""
	match kind[j]:
		K_HARVEST:
			return stand_at(Rules.SITE_GROUP[target[j]])
		K_PICK:
			return stand_at(Rules.BUSH_GROUP)
		K_HAUL:
			var at: int = destination(j)
			return pantry.storage.position_of(at) if at >= 0 else stand_at(target[j])
	return place_of(j, S_GO)


func destination(j: int) -> int:
	"""Where haul `j` unloads: its held room's store, read at the time of use -- a store's index moves when the
	pantry's stores change (a cellar dug or filled in) and the hold follows its store by id (NONE: none held)."""
	if pantry == null or not pantry.is_hold(hold[j]):
		return NONE
	return _hold_place(hold[j])


func stand_at(group: int) -> Vector2:
	"""Group `group`'s basket stand (its gathering point)."""
	return Rules.STAND_AT[group]


func stand_location(group: int) -> int:
	"""The pantry location of group `group`'s stand (NONE: the pantry has none -- a check without the village's)."""
	if pantry == null or not pantry.storage.index_of_id_into(Rules.STAND_IDS[group], _read):
		return NONE
	return _read.value


func _free_spot(at: Vector2, who: int) -> Vector2:
	"""A spot at `at` resident `who` can stand on and reach -- `at`, else the nearest on rings round it clear of anyone
	standing still (the fishery's rule, decision 0361); `at` when none is free."""
	if who == NONE or _cast == null:
		return at
	var brain: BrainScript = brain_of(who)
	var space: CastSpaceScript = _cast.space()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(space, members)
	for from: Vector2 in [brain.surface_point(), at]:
		for ring: int in FREE_SPOT_RINGS:
			for k: int in (1 if ring == 0 else 8):
				var spot: Vector2 = at + Vector2.from_angle(TAU * k / 8.0) * FREE_SPOT_STEP_M * ring
				if CastOrdersScript.spot_ok(space, spot, brain.radius, _cast.bounds(), avoid, _no_spots, from):
					return spot
	return at


# --- the task's callbacks (orchard_task.gd) ----------------------------------------------------------------------------------

func first_site(j: int, job_serial: int) -> Vector2:
	"""Where a new worker of job `j` walks first: a set-down load's spot, else its current step's place."""
	if not is_job(j, job_serial):
		return Vector2.ZERO
	var at: Vector2 = load_at[j] if load_at[j].is_finite() else place_of(j, step_of(j))
	goal[j] = _free_spot(at, worker[j])
	return goal[j]


func arrived(j: int, job_serial: int, brain: BrainScript) -> void:
	"""The worker reached where it was sent: handled on its next frame (`drive`)."""
	if is_job(j, job_serial) and worker[j] == brain.index:
		issued[j] = 2


func drive(j: int, job_serial: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of job `j` for its worker: an arrival handled, then the step's frame. False once its part is over."""
	if not is_job(j, job_serial) or worker[j] != brain.index:
		return false
	_driving = j
	if issued[j] == 2:
		issued[j] = 0
		_on_arrival(j, brain)
	if is_job(j, job_serial) and worker[j] == brain.index:
		_frame(j, brain, delta)
	_driving = NONE
	return is_job(j, job_serial) and worker[j] == brain.index


func called_away(j: int, job_serial: int, brain: BrainScript) -> void:
	"""The brain gave the task up: a walk it could not finish (it waits RETRY_USEC and is offered again; after MAX_TRIES
	the routine's job is dropped), or an order, the night or a release (back on the board; a load in hand set down)."""
	if not is_job(j, job_serial) or worker[j] != brain.index:
		return
	if brain.trip_failed():
		_unreached(j, brain)
	else:
		_let_go(j, brain)


func _unreached(j: int, brain: BrainScript) -> void:
	"""The worker could not get to its place: the job waits RETRY_USEC and is offered again (with anyone); after
	MAX_TRIES a job with nothing in hand is given up, and the feed says where it could not get."""
	tries[j] += 1
	words[j] = Text.CANT_REACH % brain.route_refusal()
	_let_go(j, brain)
	wait_usec[j] = Rules.RETRY_USEC
	if tries[j] >= MAX_TRIES and not carrying(j):
		_note(Text.gave_up(self, j), true)
		_end_job(j)


func must_finish(j: int, job_serial: int) -> bool:
	"""Whether the night must wait: a load in the worker's hands (a delivery always finishes)."""
	return is_job(j, job_serial) and in_hand(j)


func _let_go(j: int, brain: BrainScript) -> void:
	"""Job `j` loses its worker but stays on the board: a harvest's or a picking's load is set down where it stands for
	the next to carry on; a haul not yet delivered starts again from its stand (its basket never left the lot)."""
	worker[j] = NONE
	issued[j] = 0
	at_work[j] = 0
	_tasks[j] = null
	if kind[j] == K_HAUL:
		_restart_haul(j)
	elif carrying(j) and not load_at[j].is_finite():
		load_at[j] = brain.surface_point()
	elif not carrying(j):
		pos[j] = 0
	revision += 1


func _restart_haul(j: int) -> void:
	"""A haul let go before its delivery: its room released and its basket left in its lot, to start again."""
	if pantry != null and pantry.is_hold(hold[j]):
		pantry.release(hold[j])
	hold[j] = NONE
	load_milli[j] = 0
	load_item[j] = NONE
	lot[j] = NONE
	pos[j] = 0
	need_mwu[j] = 0
	done_mwu[j] = 0


# --- the steps --------------------------------------------------------------------------------------------------------------

func _begin_step(j: int, brain: BrainScript) -> void:
	"""Start job `j`'s current step: a walk ordered (loaded when it carries), a work step opened (its inputs and room
	checked the first time), or the job over."""
	var step: int = step_of(j)
	if step == NONE:
		_end_job(j)
		return
	at_work[j] = 0
	if step == S_GO or step == S_CARRY:
		goal[j] = _free_spot(place_of(j, step), brain.index)
		issued[j] = 1
		if step == S_CARRY:
			brain.task_carry_to(goal[j])
		else:
			brain.task_walk_to(goal[j])
		return
	if step == S_UNLOAD:
		need_mwu[j] = Rules.HAUL_UNLOAD_MWU
		done_mwu[j] = 0
		at_work[j] = 1
		return
	if need_mwu[j] == 0 and not _open_work(j):
		return
	at_work[j] = 1


func _open_work(j: int) -> bool:
	"""Job `j`'s work step starts for the first time: its check (`start_refusal`) and its room or load, its need set.
	False when it may not: the job waits (no room) or ends (nothing to do), saying why."""
	room_wait[j] = 0
	var why: String = start_refusal(j)
	if why.is_empty():
		why = _reserve(j)
	if why.is_empty():
		need_mwu[j] = _need_of(j, S_WORK)
		done_mwu[j] = 0
		words[j] = ""
		return true
	words[j] = why
	if _waits_for_room(j):
		var who: int = worker[j]
		_let_go(j, brain_of(who))
		wait_usec[j] = Rules.RETRY_USEC
		if j != _driving:
			brain_of(who).work_done()
	else:
		if origin[j] == ORIGIN_PLAYER:
			_note(Text.cannot(self, j, why), false)
		_end_job(j)
	return false


func _waits_for_room(j: int) -> bool:
	"""Whether job `j`'s refusal is a full store or reservation table (it waits) rather than nothing to do (it ends)."""
	return room_wait[j] == 1


func _need_of(j: int, step: int) -> int:
	"""Milli-WU job `j`'s work `step` takes."""
	if step == S_UNLOAD:
		return Rules.HAUL_UNLOAD_MWU
	match kind[j]:
		K_TEND:
			return Rules.CARE_MWU
		K_HARVEST:
			return Rules.HARVEST_MWU if model.is_mature(target[j]) else Rules.EARLY_HARVEST_MWU
		K_PICK:
			return Rules.pick_mwu(maxi(load_milli[j], hold_size(j)))
		K_HAUL:
			return Rules.HAUL_LOAD_MWU
		K_PLANT:
			return Rules.PLANT_MWU
		K_PROPAGATE:
			return Rules.PROPAGATE_MWU
	return Rules.OBSERVE_MWU


func hold_size(j: int) -> int:
	"""The room job `j` holds, milli-U (0: none)."""
	return pantry.hold_milli(hold[j]) if pantry != null else 0


func _on_arrival(j: int, brain: BrainScript) -> void:
	"""The worker is where it was sent (only standing there: decision 0361): a set-down load picked up, a work place
	reached, or a load put down at its drop."""
	if not brain.arrived_near(goal[j], ARRIVE_M):
		_unreached(j, brain)
		return
	tries[j] = 0
	if carrying(j) and load_at[j].is_finite():
		load_at[j] = Vector2.INF
		_begin_step(j, brain)
		return
	if step_of(j) == S_CARRY:
		_deliver(j, brain)
		return
	if step_of(j) == S_WORK or step_of(j) == S_UNLOAD:
		at_work[j] = 1
		return
	_advance(j, brain)


func _advance(j: int, brain: BrainScript) -> void:
	"""Job `j` finished its step: on to the next."""
	pos[j] += 1
	_begin_step(j, brain)


func _frame(j: int, brain: BrainScript, delta: float) -> void:
	"""One frame: a worker at its work faces it and plays its clip (the work is credited in `update`); a walk that
	lapsed is ordered again."""
	if at_work[j] == 1:
		_work_frame(j, brain, delta)
	elif issued[j] == 0 and wait_usec[j] <= 0:
		_begin_step(j, brain)


func _work_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""At the work: standing at its place (off it, it walks back and nothing is credited), facing it, its clip on."""
	if not brain.arrived_near(goal[j], ARRIVE_M):
		at_work[j] = 0
		goal[j] = _free_spot(place_of(j, step_of(j)), brain.index)
		issued[j] = 1
		brain.task_walk_to(goal[j])
		return
	brain.task_face(_face_of(j), delta)
	brain.task_play(_clip_of(j))


func _face_of(j: int) -> Vector2:
	"""What a worker faces: the tree's trunk, the bush, the stand, the nursery, the grove's heart."""
	if step_of(j) == S_UNLOAD:
		return drop_of(j) + Vector2(0.0, -1.0)
	match kind[j]:
		K_TEND, K_HARVEST, K_PLANT:
			return Rules.site_centre_m(target[j])
		K_PICK:
			return Rules.BUSH_AT[target[j]]
		K_HAUL:
			return stand_at(target[j]) + Vector2(0.0, -1.0)
		K_PROPAGATE:
			return Rules.NURSERY_AT
	return Rules.GROVE_AT


func _clip_of(j: int) -> StringName:
	"""The work's clip: digging for planting, watching for the grove, else handling."""
	match kind[j]:
		K_PLANT:
			return CLIP_DIG
		K_OBSERVE:
			return CLIP_WATCH
	return CLIP_PICK


# --- the work's credit (on the cast's clock) -------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""`usec` demo microseconds: each worker at its work does §5.2's work at the base rate; waits count down; on each new
	game hour the routine's work is raised (`plan_work`)."""
	for j: int in MAX_JOBS:
		if live[j] == 0:
			continue
		if wait_usec[j] > 0:
			wait_usec[j] = maxi(0, wait_usec[j] - usec)
		if at_work[j] == 1 and worker[j] != NONE:
			_credit(j, usec)
	if calendar != null and calendar.hour_index() != _hour_seen:
		_hour_seen = calendar.hour_index()
		plan_work()


func _credit(j: int, usec: int) -> void:
	"""Job `j`'s worker does `usec` of work (no fraction of a milli-WU is lost between frames); its step completes at
	its need."""
	num[j] += FisheryRules.mwu_numerator(usec, 0)
	@warning_ignore("integer_division") var done: int = num[j] / FisheryRules.MWU_DENOMINATOR
	num[j] -= done * FisheryRules.MWU_DENOMINATOR
	done_mwu[j] += done
	if done_mwu[j] >= need_mwu[j]:
		at_work[j] = 0
		_work_done(j)


func _work_done(j: int) -> void:
	"""A work step finished: its outcome, then the next step (or the job's end)."""
	var who: int = worker[j]
	if step_of(j) == S_UNLOAD:
		_move_basket(j)
		_end_job(j)
		return
	var outcome: String = _complete(j)
	if not outcome.is_empty():
		_note(outcome, false)
	need_mwu[j] = 0
	done_mwu[j] = 0
	if live[j] == 1 and who != NONE:
		_advance(j, brain_of(who))


# --- the outcomes -----------------------------------------------------------------------------------------------------------

func today() -> int:
	"""The calendar's absolute day (1 without a calendar)."""
	return calendar.now().absolute_day if calendar != null else Hive.MIN_CALENDAR_DAY


func season_now() -> int:
	"""The calendar's season (0 spring .. 3 winter)."""
	return Hive.season_of_day(today())


func drought() -> bool:
	"""Whether today is a §5.10 drought day (the one weather's event)."""
	return weather != null and weather.event() == WeatherCore.EVENT_DROUGHT


func start_refusal(j: int) -> String:
	"""Why job `j`'s work cannot start now, in words ("" when it can): the rules each kind checks before it begins."""
	var t: int = target[j]
	match kind[j]:
		K_TEND:
			return Text.tend_refusal(model, t, season_now(), drought(), stores)
		K_HARVEST:
			return _harvest_refusal(t, today())
		K_PICK:
			return Text.NO_BERRIES if _berries_free() <= 0 else ""
		K_HAUL:
			return "" if _haul_lot(t) != NONE else Text.NOTHING_TO_HAUL
		K_PLANT:
			return _plant_inputs_refusal(j)
		K_PROPAGATE:
			return _propagate_inputs_refusal(t)
	return ""


func _harvest_refusal(site: int, day: int) -> String:
	"""A harvest's check in words: the model's (its window, its age, once a year), and a tree too spent to bear."""
	var why: String = Text.harvest_words(model.harvest_refusal(site, day))
	if why.is_empty() and model.expected_yield_milli(site) <= 0:
		return Text.BEARS_NOTHING
	return why


func _plant_inputs_refusal(j: int) -> String:
	"""A planting's checks: the site, its sapling (the site's ready plan, else a free one) and compost 4 U (§5.6)."""
	var why: String = model.plant_refusal(target[j], species[j], today(), _from_plan(j))
	if not why.is_empty():
		return Text.plant_words(why)
	if _compost() < Hive.PLANT_COMPOST_MILLI:
		return Text.NO_COMPOST % Text.units(Hive.PLANT_COMPOST_MILLI)
	return ""


func _from_plan(j: int) -> bool:
	"""Whether planting job `j` plants its site's ready plan's sapling (else a free one)."""
	var plan: int = model.plan_for_site(target[j])
	return plan != NONE and model.plan_state[plan] == ModelScript.PLAN_READY and model.plan_species[plan] == species[j]


func _propagate_inputs_refusal(plan: int) -> String:
	"""A propagation's checks: the plan still waits, and §5.6's fruit 4 of its species, compost 2 and water 2 are
	there."""
	if model.plan_state[plan] != ModelScript.PLAN_WAITING:
		return Text.PLAN_GONE
	var j: int = find(K_PROPAGATE, plan)
	if j != NONE and target_serial[j] != 0 and target_serial[j] != model.plan_serial[plan]:
		return Text.PLAN_GONE
	var item: int = Catalog.item_of_orchard_species(model.plan_species[plan])
	if pantry == null or _at_stands(item) < Hive.NURSERY_FRUIT_MILLI:
		return Text.NO_FRUIT % [Text.units(Hive.NURSERY_FRUIT_MILLI), Catalog.ITEM_LABELS[item].to_lower()]
	if _compost() < Hive.NURSERY_COMPOST_MILLI:
		return Text.NO_COMPOST % Text.units(Hive.NURSERY_COMPOST_MILLI)
	if stores == null or stores.water_milli_u < Hive.NURSERY_WATER_MILLI:
		return Text.NO_WATER % Text.units(Hive.NURSERY_WATER_MILLI)
	return ""


func _compost() -> int:
	"""The farm's compost store, milli-U (0 without one)."""
	return int(_compost_left.call()) if _compost_left.is_valid() else 0


func _berries_free() -> int:
	"""Berries the hedge offers now, less what other pickings have room held for."""
	var free: int = model.berries_available_milli(season_now())
	for j: int in MAX_JOBS:
		if live[j] == 1 and kind[j] == K_PICK and load_milli[j] == 0:
			free -= hold_size(j)
	return free


func _reserve(j: int) -> String:
	"""ROOM FIRST: a harvest's or a picking's room at its stand, a haul's at its destination ("" when held)."""
	match kind[j]:
		K_HARVEST:
			var item: int = Catalog.item_of_orchard_species(model.species_of(target[j]))
			return _hold_at_stand(j, item, model.expected_yield_milli(target[j]), Rules.SITE_GROUP[target[j]])
		K_PICK:
			var berries: int = mini(Rules.PICK_LOAD_MILLI, _berries_free())
			return _hold_at_stand(j, Rules.BERRY_ITEM, berries, Rules.BUSH_GROUP)
		K_HAUL:
			return _hold_destination(j)
	return ""


func _hold_at_stand(j: int, item: int, milli: int, group: int) -> String:
	"""Room for `milli` of `item` held at group `group`'s stand for job `j`, or why not."""
	if milli <= 0:
		return Text.NOTHING_TO_PICK
	var at: int = stand_location(group)
	if at == NONE or not pantry.reserve_at_into(item, milli, at, _read):
		return _room_refusal(j, milli, item, Rules.STAND_LABELS[group])
	hold[j] = _read.value
	return ""


func _room_refusal(j: int, milli: int, item: int, where: String) -> String:
	"""A reservation refused: job `j` waits; in words, a full reservation table (the pantry's holds all in use) or a
	full store (make room in the Pantry)."""
	room_wait[j] = 1
	if _read.error == PantryScript.REFUSE_NO_HOLD:
		return Text.HOLDS_FULL
	return Text.no_room(milli, item, where)


func _hold_destination(j: int) -> String:
	"""A haul's basket chosen (the stand's oldest lot above what the group keeps) and room held for it where the
	group's policy sends it -- the kitchen's pantry, or the store that keeps it longest."""
	var group: int = target[j]
	var chosen: int = _haul_lot(group)
	if chosen == NONE:
		return Text.NOTHING_TO_HAUL
	var item: int = pantry.lot_item(chosen)
	var milli: int = mini(Rules.HAUL_LOAD_MILLI, _above_keep(group, item))
	var held: bool
	if model.group_dest[group] == Rules.DEST_KITCHEN and pantry.storage.index_of_id_into(Rules.KITCHEN_STORE_ID, _read):
		held = pantry.reserve_at_into(item, milli, _read.value, _read)
	else:
		held = pantry.reserve_near_into(item, milli, stand_at(group), _read)
	if not held:
		return _room_refusal(j, milli, item, Text.DEST_WORDS[model.group_dest[group]])
	hold[j] = _read.value
	lot[j] = chosen
	lot_serial[j] = pantry.lot_serial(chosen)
	load_item[j] = item
	return ""


func _hold_place(held: int) -> int:
	"""Where hold `held` keeps its room (NONE: nowhere)."""
	return _read.value if pantry.hold_location_into(held, _read) else NONE


func _haul_lot(group: int) -> int:
	"""The lot at group `group`'s stand a haul should take: the oldest of an item the stand holds more of than the group
	keeps, not already being hauled (NONE: none)."""
	var at: int = stand_location(group)
	if at == NONE:
		return NONE
	var best: int = NONE
	for row: int in PantryScript.MAX_LOTS:
		var item: int = pantry.lot_item(row)
		if item == PantryScript.FREE or pantry.lot_location(row) != at or _hauled(row):
			continue
		if _above_keep(group, item) <= 0:
			continue
		if best == NONE or pantry.lot_age(row) > pantry.lot_age(best):
			best = row
	return best


func _hauled(row: int) -> bool:
	"""Whether a live haul has taken lot `row`."""
	for j: int in MAX_JOBS:
		if live[j] == 1 and kind[j] == K_HAUL and lot[j] == row and lot_serial[j] == pantry.lot_serial(row):
			return true
	return false


func _above_keep(group: int, item: int) -> int:
	"""How much of `item` at group `group`'s stand is beyond what the group keeps back for the nursery (fruit only:
	ECO-010's "seedling" share)."""
	var at: int = stand_location(group)
	if at == NONE:
		return 0
	var keep: int = model.group_keep[group] if Catalog.category_of(item) == Catalog.CAT_FRUIT else 0
	return maxi(0, pantry.milli_at(item, at) - keep)


func _complete(j: int) -> String:
	"""Job `j`'s work is done: its outcome, in the news's words ("" for none)."""
	var t: int = target[j]
	match kind[j]:
		K_TEND:
			return _tended(t)
		K_HARVEST:
			_take_load(j, Catalog.item_of_orchard_species(model.species_of(t)), model.pick_tree(t, today()))
			return Text.picked(model, t, load_milli[j])
		K_PICK:
			_take_load(j, Rules.BERRY_ITEM, model.pick_berries(hold_size(j), season_now()))
		K_HAUL:
			_load_basket(j)
		K_PLANT:
			return _planted(j)
		K_PROPAGATE:
			return _propagated(t)
		K_OBSERVE:
			return _observed()
	return ""


func _load_basket(j: int) -> void:
	"""A haul's basket loaded at the stand: as much of its lot as is still there, up to its held room (its lot gone --
	spoiled or eaten meanwhile -- it has nothing to carry and ends)."""
	var still: bool = pantry.lot_serial(lot[j]) == lot_serial[j] and pantry.lot_item(lot[j]) == load_item[j]
	_take_load(j, load_item[j], mini(pantry.lot_milli(lot[j]), hold_size(j)) if still else 0)


func _take_compost_milli(milli: int) -> bool:
	"""Take `milli` of the farm's compost, all or none (false without a store)."""
	return _take_compost.is_valid() and bool(_take_compost.call(milli))


func _tended(site: int) -> String:
	"""A tree tended: §5.6's care recorded for today, a drought's 2 U of water paid from the butt."""
	if drought() and stores != null and not stores.take_water(Hive.CARE_DROUGHT_WATER_MILLI):
		return Text.DROUGHT_DRY % Text.tree_name(model, site)
	model.record_tending(site)
	return ""


func _take_load(j: int, item: int, milli: int) -> void:
	"""What job `j`'s worker picked is in its hands; its held room shrinks to it (never grows)."""
	load_item[j] = item
	load_milli[j] = milli
	if milli > 0 and pantry != null and pantry.is_hold(hold[j]):
		pantry.resize_hold(hold[j], mini(milli, hold_size(j)))
	if milli <= 0:
		pos[j] = program_length(kind[j]) - 1


func _planted(j: int) -> String:
	"""A planting done: its sapling and compost taken now (all or none), the tree a new §5.6 row."""
	var site: int = target[j]
	var why: String = _plant_inputs_refusal(j)
	if not why.is_empty() or not _take_compost_milli(Hive.PLANT_COMPOST_MILLI):
		return Text.cannot(self, j, why if not why.is_empty() else Text.NO_COMPOST % Text.units(Hive.PLANT_COMPOST_MILLI))
	model.take_sapling(site, species[j], _from_plan(j))
	model.plant(site, species[j], today())
	return Text.planted(model, site, today())


func _propagated(plan: int) -> String:
	"""A propagation done: §5.6's fruit 4, compost 2 and water 2 taken now (all or none), the sapling growing."""
	var why: String = _propagate_inputs_refusal(plan)
	if not why.is_empty():
		return why
	var item: int = Catalog.item_of_orchard_species(model.plan_species[plan])
	if not _take_compost_milli(Hive.NURSERY_COMPOST_MILLI):
		return Text.NO_COMPOST % Text.units(Hive.NURSERY_COMPOST_MILLI)
	stores.take_water(Hive.NURSERY_WATER_MILLI)
	_withdraw(item, Hive.NURSERY_FRUIT_MILLI)
	model.start_growing(plan, today())
	return Text.propagated(model, plan)


func _at_stands(item: int) -> int:
	"""How much of `item` waits at the stands (the nursery's fruit: never food the kitchen has reserved in a store)."""
	var total: int = 0
	for group: int in Rules.GROUP_COUNT:
		var at: int = stand_location(group)
		total += pantry.milli_at(item, at) if at != NONE else 0
	return total


func _withdraw(item: int, milli: int) -> void:
	"""Take `milli` of `item` from the stands' lots, oldest first (checked to be there)."""
	var left: int = milli
	while left > 0:
		var oldest: int = NONE
		for row: int in PantryScript.MAX_LOTS:
			if pantry.lot_item(row) != item or not pantry.storage.is_staging(pantry.lot_location(row)):
				continue
			if oldest == NONE or pantry.lot_age(row) > pantry.lot_age(oldest):
				oldest = row
		if oldest == NONE:
			return
		var take: int = mini(left, pantry.lot_milli(oldest))
		pantry.withdraw_into(oldest, pantry.lot_serial(oldest), take, _read)
		left -= take


func _observed() -> String:
	"""The grove observed this season: its record's line (ECO-015)."""
	var day: int = today()
	var standing: int = int(grove_trees.call()) if grove_trees.is_valid() else 0
	var line: String = Text.observation(Hive.season_of_day(day), standing, model.grove_protected)
	model.record_observation(ModelScript.season_index_of_day(day), Text.dated(calendar, line))
	return line


func _deliver(j: int, brain: BrainScript) -> void:
	"""A load at its drop (only standing there): a harvest or a picking stored at the stand against its hold (its
	group's stand when the hold is spent) -- what fits; the rest kept in hand and tried again until there is room
	(decision 0222) -- or a haul on to its unloading."""
	if kind[j] == K_HAUL:
		_advance(j, brain)
		return
	var group: int = Rules.SITE_GROUP[target[j]] if kind[j] == K_HARVEST else Rules.BUSH_GROUP
	var at: int = _hold_place(hold[j]) if pantry.is_hold(hold[j]) else stand_location(group)
	var stored: int = 0
	if at != NONE and pantry.store_upto_into(load_item[j], load_milli[j], at, hold[j], _read):
		stored = _read.value
	load_milli[j] -= stored
	if load_milli[j] <= 0:
		_end_job(j)
		return
	words[j] = Text.no_room(load_milli[j], load_item[j], Text.THE_STAND)
	issued[j] = 0
	wait_usec[j] = Rules.RETRY_USEC


func _move_basket(j: int) -> void:
	"""A haul unloaded: its basket moves from its lot at the stand to the store (farm_pantry.gd `move_upto_into`: the
	food keeps its age; the ledger counts it once)."""
	if pantry == null or load_milli[j] <= 0:
		return
	var at: int = destination(j)
	var moved: int = _read.value if at >= 0 and pantry.move_upto_into(lot[j], lot_serial[j], load_milli[j], at, hold[j],
		_read) else 0
	if moved < load_milli[j]:
		_note(Text.short_haul(load_milli[j] - moved, load_item[j]), false)


# --- the routine (each game hour) ---------------------------------------------------------------------------------------------

func plan_work() -> void:
	"""Raise the routine's work (see ROUTINE): tending, harvests by each group's timing, a picking, hauls, plantings,
	propagations and the grove's observation. A job the player cancelled today is not raised again today."""
	if model == null:
		return
	var day: int = today()
	for site: int in Rules.SITE_COUNT:
		if model.has_tree(site) and Text.tend_refusal(model, site, season_now(), drought(), stores).is_empty():
			_raise(K_TEND, site)
		if _harvest_refusal(site, day).is_empty() and _timing_allows(site, day):
			_raise(K_HARVEST, site)
	if _berries_free() >= Rules.PICK_LOAD_MILLI and count_of(K_PICK, NONE) == 0:
		_raise(K_PICK, _pick_turn % Rules.BUSH_COUNT)
		_pick_turn += 1
	for group: int in Rules.GROUP_COUNT:
		if _haul_lot(group) != NONE and count_of(K_HAUL, group) == 0:
			_raise(K_HAUL, group)
	_plan_nursery_work()
	if model.grove_seen_season != ModelScript.season_index_of_day(day):
		_raise(K_OBSERVE, 0)


func _plan_nursery_work() -> void:
	"""A propagation for each waiting plan whose inputs are there, a planting for each ready plan."""
	for plan: int in Rules.MAX_PLANS:
		match model.plan_state[plan]:
			ModelScript.PLAN_WAITING:
				if _propagate_inputs_refusal(plan).is_empty():
					_raise(K_PROPAGATE, plan)
			ModelScript.PLAN_READY:
				var site: int = model.plan_site[plan]
				if not model.has_tree(site) and find(K_PLANT, site) == NONE:
					_raise(K_PLANT, site, model.plan_species[plan])


func _raise(job_kind: int, job_target: int, job_species: int = NONE) -> int:
	"""A routine job of `job_kind` on `job_target` (NONE: the board is full, or the player cancelled it today)."""
	if _cancelled_day[job_kind * MAX_TARGETS + job_target] == today():
		return NONE
	if not open_into(job_kind, job_target, ORIGIN_ROUTINE, _read):
		return NONE
	if job_species != NONE:
		species[_read.value] = job_species
	_note_target(_read.value)
	return _read.value


func _note_target(j: int) -> void:
	"""A propagation notes its plan's serial when it is opened (its row reused by a new plan is not its plan)."""
	if kind[j] == K_PROPAGATE and target_serial[j] == 0:
		target_serial[j] = model.plan_serial[target[j]]


func _timing_allows(site: int, day: int) -> bool:
	"""ECO-010's group timing: STAGGERED picks each tree as its window opens; TOGETHER waits until every tree of the
	group that bears this year may be picked the same day -- or a tree's window is closing."""
	var group: int = Rules.SITE_GROUP[site]
	if model.group_timing[group] == Rules.TIMING_STAGGERED:
		return true
	if day == model.store.last_harvest_window_day_of_year(model.species_of(site), Hive.year_of_day(day)).value:
		return true
	for other: int in Rules.SITE_COUNT:
		if Rules.SITE_GROUP[other] != group or other == site or not model.has_tree(other):
			continue
		var next: int = model.next_harvest_day(other, day)
		if next > day and Hive.year_of_day(next) == Hive.year_of_day(day):
			return false
	return true


# --- the player's orders ---------------------------------------------------------------------------------------------------------

func order(job_kind: int, job_target: int, job_species: int, members: PackedInt32Array) -> String:
	"""The player orders `job_kind` on `job_target` (a planting of `job_species`): its check first, then the job --
	given to the nearest of `members` who may take it, or left for the board. "" when ordered, else why not."""
	var why: String = order_refusal(job_kind, job_target, job_species)
	if not why.is_empty():
		return why
	if not open_into(job_kind, job_target, ORIGIN_PLAYER, _read):
		return Text.BOARD_FULL
	var j: int = _read.value
	if job_species != NONE:
		species[j] = job_species
	_note_target(j)
	_cancelled_day[job_kind * MAX_TARGETS + job_target] = 0
	if worker[j] == NONE and not members.is_empty():
		var who: int = _nearest_free(j, members)
		if who != NONE:
			claim(j, who)
	revision += 1
	return ""


func order_refusal(job_kind: int, job_target: int, job_species: int) -> String:
	"""Why the player's order would be refused now ("" when it would be taken): the same checks the work makes."""
	match job_kind:
		K_TEND:
			return Text.tend_refusal(model, job_target, season_now(), drought(), stores)
		K_HARVEST:
			return _harvest_refusal(job_target, today())
		K_PICK:
			return Text.NO_BERRIES if _berries_free() <= 0 else ""
		K_PLANT:
			var plan: int = model.plan_for_site(job_target)
			var from_plan: bool = plan != NONE and model.plan_state[plan] == ModelScript.PLAN_READY
			var why: String = Text.plant_words(model.plant_refusal(job_target, job_species, today(), from_plan))
			return why if not why.is_empty() or _compost() >= Hive.PLANT_COMPOST_MILLI \
				else Text.NO_COMPOST % Text.units(Hive.PLANT_COMPOST_MILLI)
		K_HAUL:
			return "" if _haul_lot(job_target) != NONE else Text.NOTHING_TO_HAUL
		K_PROPAGATE:
			return _propagate_inputs_refusal(job_target)
	return ""


func _nearest_free(j: int, members: PackedInt32Array) -> int:
	"""The member nearest job `j` who may take it (NONE: none)."""
	var best: int = NONE
	var best_d: float = INF
	for who: int in members:
		if not eligibility(j, who).is_empty():
			continue
		var d: float = brain_of(who).surface_point().distance_squared_to(point(j))
		if d < best_d:
			best_d = d
			best = who
	return best


# --- the board's commands ----------------------------------------------------------------------------------------------------------

func pause(j: int, on: bool) -> String:
	"""Pause job `j` (its worker let go) or resume it: "" when done, else why not (a load in hand is delivered first)."""
	if not is_live(j):
		return Text.GONE
	if on and in_hand(j):
		return Text.CARRYING % name_of(worker[j])
	if on and worker[j] != NONE:
		var who: int = worker[j]
		_let_go(j, brain_of(who))
		brain_of(who).work_done()
	paused[j] = 1 if on else 0
	revision += 1
	return ""


func cancel(j: int) -> String:
	"""Cancel job `j` alone: "" when done, else why not (a harvest or a picking already cut is a delivery: it always
	finishes). A cancelled routine job is not raised again today."""
	if not is_live(j):
		return Text.GONE
	if carrying(j) and kind[j] != K_HAUL:
		return Text.DELIVERY_GOES_ON
	_cancelled_day[kind[j] * MAX_TARGETS + target[j]] = today()
	var who: int = worker[j]
	if who != NONE:
		_let_go(j, brain_of(who))
		brain_of(who).work_done()
	_end_job(j)
	return ""


func reassign(j: int, who: int) -> String:
	"""Give job `j` to `who` instead: "" when done, else why not."""
	if not is_live(j):
		return Text.GONE
	if in_hand(j):
		return Text.CARRYING % name_of(worker[j])
	var why: String = eligibility(j, who)
	if not why.is_empty():
		return why
	if worker[j] != NONE:
		var was: int = worker[j]
		_let_go(j, brain_of(was))
		brain_of(was).work_done()
	paused[j] = 0
	wait_usec[j] = 0
	return "" if claim(j, who) else Text.GONE


func _note(text: String, warning: bool) -> void:
	"""A line in the village news (nothing without a feed)."""
	if not text.is_empty() and say.is_valid():
		say.call(text, warning)


func doing_text(j: int, job_serial: int) -> String:
	"""What job `j`'s worker is doing, in words (orchard_task.gd `label`)."""
	return Text.doing(self, j) if is_job(j, job_serial) else ""
