extends RefCounted
## The woods' hands: residents carrying out the woods' job board. Decision 0196 (live demo). The
## walking, carrying and the work clip go through the cast's own brains, as the farm's crew does
## (demo/farm/farm_crew.gd); the EFFECT of each piece of work is a call on the real ResourceNode rows
## (forest_stand.gd), the deadfall, the skills or the demo stores at the step it belongs to.
##
## WHO WORKS. An order given with residents selected goes to the nearest of them; felling with several
## selected, the others wait by the tree to haul it. Anything left on the board -- queued from the
## Woods panel with nobody selected, a storm's fallen tree to clear, an auto-fell zone's next tree --
## is CLAIMED: in the live demo by the village's work board (demo/work/work_board.gd, decision 0411: any idle eligible
## resident, the Woods crew first) through `claim`; without one (a suite's crew alone) by the ROUTINE forestry crew
## (CREW_KEYS: the squirrel forester and the beaver) when one of them is wandering on its own. Anybeast can do any of
## it (LORE-P12); skill only changes how long it takes (forest_skills.gd).
##
## HOW A STEP RUNS. A walk is `order_move()` -- or `order_carry()`, the carry walk, for logs, planks and
## a sapling basket -- to a standable spot beside its target, facing it; it is done when the brain has ARRIVED there
## (decision 0361's `arrived_near`; a walk given up holds too, and is a failed try). Every frame of work rechecks it: a
## worker no longer at its spot credits nothing and walks back first (decision 0411, closing 0361's open woods case of
## the review's F05). A work step plays its clip in place for its WU (forest_rules.gd `work_usec`: skill,
## season and weather), the axe in hand for felling (the beaver gnaws, with none) and the spade for
## grubbing and planting, and applies its effect at the end. A resident ordered elsewhere drops the
## job back on the board where it had got to, load and all, and comes back to it (resident_brain.gd
## RESUMING).
##
## CONSERVATION (decision 0222; the farm's own rule, demo/farm/farm_crew.gd CONSERVATION). Wood and planks
## reach the stores only where they are stacked. Cancelling a job with a load in hand turns it into that
## load's DELIVERY (forest_jobs.gd): the hauler walks it on to the log stack (logs a sawyer had taken go
## back there), the sawyer's planks on to the plank stack, and the stores are credited on arrival --
## never at the cancel (the review's F24). A job is never closed holding a load: one that cannot get
## through waits on the board with it, tried again at the next hour. Planting's compost is paid ONCE per
## job (`paid`, F25): a planter called away, a new planter, a retry -- none pays it again.

const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const SkillsScript := preload("res://demo/forestry/forest_skills.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const ForestCard := preload("res://demo/forestry/forest_card.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")

## THE DECISION (decision 0332, review F33/F44). `decide` answers what an order would do now -- the same job already
## on the board (joined), the refusal, who takes it and how many wait to haul -- and is the ONE function both the
## orders (`order`, `order_haul`) and the Woods panel's action cards (`preview_into`) read.
class Decision:
	## The refusal (empty: the order goes ahead).
	var code: String = ""
	## The same job already on the board (-1: a new one).
	var row: int = -1
	## Who takes it now (-1: it waits for the forestry crew).
	var worker: int = -1
	## The same job is under way with `worker` already.
	var busy: bool = false
	## Selected residents free of woods work, and how many are selected.
	var free: int = 0
	var selected: int = 0
	## Felling: the others who will wait to haul; hauling with a selection: how many haul.
	var helpers: int = 0


const CREW_KEYS: Array[StringName] = SkillsScript.SKILLED_KEYS
const CLIP_CHOP: StringName = &"pull_radish"
const CLIP_WORK: StringName = &"collect_object"
const AXE_KEY: StringName = &"axe"
const SPADE_KEY: StringName = &"spade"
const PLANK_KEY: StringName = &"bridge_plank"
const BASKET_KEY: StringName = &"sapling_basket"
## The axe in the right hand bone's frame: the model stands handle-down along +Y; turned so the handle
## runs across the fist and the head stands up, gripped this share of its height from the handle's end.
const AXE_GRIP_SHARE: float = 0.12
const AXE_EULER_DEG: Vector3 = Vector3(0.0, 0.0, 90.0)
## A walk is done when the brain holds this close to its spot.
const ARRIVE_M: float = 0.4
## Rings tried round a target for a standable spot, and spots per ring.
const RING_GAP_M: float = 0.45
const RINGS: int = 4
const RING_SPOTS: int = 12
## Beyond a trunk's obstacle circle a feller first tries to stand this far off (m).
const TREE_STAND_M: float = 0.35
## A hauler loads beside the lying trunk's middle, this far from it (m, demo).
const TRUNK_STAND_M: float = 1.9
const PILE_STAND_M: float = 0.9
const SITE_STAND_M: float = 0.9
## A haul waiting on a standing tree waits this much further out than the feller (m).
const WAIT_EXTRA_M: float = 1.4
## The routine crew looks at the board this often (cast time).
const PICKUP_USEC: int = 500000
## The sawing plan's saw step (forest_jobs.gd PLANS): a load past it is planks, before it logs.
const SAW_WORK_STEP: int = 3
## A selected haul with every selected resident busy in the woods (`decide`).
const REFUSE_ALL_BUSY: String = "EVERYONE_SELECTED_BUSY"

var jobs: JobsScript = JobsScript.new()
var skills: SkillsScript = SkillsScript.new()

var _cast: DemoCastScript = null
var _stand: StandScript = null
var _zones: ZonesScript = null
var _deadfall: DeadfallScript = null
var _stores: StoresScript = null
var _calendar: CalendarScript = null
var _weather: WeatherScript = null
var _props: PropsScript = null
var _notice: Callable = Callable()
var _compost_left: Callable = Callable()
var _compost_take: Callable = Callable()
var _crew: PackedInt32Array = PackedInt32Array()
var _reach: Rect2 = Rect2(-Rules.REACH_M, -Rules.REACH_M, 2.0 * Rules.REACH_M, 2.0 * Rules.REACH_M)
## Where the crew may be sent to stand: the reach and the margin beyond it.
var _walk: Rect2 = _reach.grow(Rules.WORK_MARGIN_M)
var _pickup_usec: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _busy: IntMath.IntResult = IntMath.IntResult.new()
## `_nearest_free_into`'s own scratch: its `out` may be `_read` or `_busy`, never this.
var _probe: IntMath.IntResult = IntMath.IntResult.new()
var _no_taken: PackedVector2Array = PackedVector2Array()
var _idle: PackedInt32Array = PackedInt32Array()
var _found: Vector2 = Vector2.ZERO
## `decide`'s answer and scratch (reused).
var _decision: Decision = Decision.new()
var _pick: IntMath.IntResult = IntMath.IntResult.new()
## The crew whose names `_names_of_crew` holds (_crew_names).
var _named_crew: PackedInt32Array = PackedInt32Array()
var _names_of_crew: PackedStringArray = PackedStringArray()
## Per job row: the serial of the job the player paused there (0: none) -- a reused row is never paused.
var _paused_serial: PackedInt64Array = PackedInt64Array()
## The work board claims the waiting jobs (decision 0411): the routine crew's own hand-out stands down.
var _claimed_outside: bool = false
## The board's "who" for a job left on the board, for the action card (`func(activity, selected) -> String`).
var _queue_words: Callable = Callable()


func _init() -> void:
	"""Size the crew's own per-row column."""
	_paused_serial.resize(JobsScript.MAX_JOBS)


func configure(cast: DemoCastScript, stand: StandScript, zones: ZonesScript, deadfall: DeadfallScript,
		stores: StoresScript, calendar: CalendarScript, weather: WeatherScript, props: PropsScript) -> void:
	"""Work with this cast on these trees, zones, deadfall and stores, on this calendar and weather."""
	_cast = cast
	_stand = stand
	_zones = zones
	_deadfall = deadfall
	_stores = stores
	_calendar = calendar
	_weather = weather
	_props = props
	var keys: Array[StringName] = []
	var species := PackedStringArray()
	_crew.clear()
	for i: int in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		keys.append(actor.creature_key)
		species.append(actor.species)
		if CREW_KEYS.has(actor.creature_key):
			_crew.append(i)
	skills.setup(keys, species)


func set_notice(notice: Callable) -> void:
	"""`notice(text)` reports what happened (the demo's notice feed, source Woods)."""
	_notice = notice


func set_compost(left: Callable, take: Callable) -> void:
	"""Where planting's compost comes from: `left() -> int` milli-U, `take(milli: int) -> bool` all or
	nothing (the farm's compost store, demo_village.gd; none: planting refuses NO_COMPOST)."""
	_compost_left = left
	_compost_take = take


func set_crew(members: PackedInt32Array) -> void:
	"""Replace the routine crew (a test's placeholder cast has no forester)."""
	_crew = members.duplicate()


func crew() -> PackedInt32Array:
	"""The routine crew's actor indices."""
	return _crew


# --- ordering -----------------------------------------------------------------------------------

func order(kind: int, target: int, gen: int, members: PackedInt32Array, origin: int) -> String:
	"""Queue `kind` on `target` and, with `members`, give it to the nearest free of them now (felling: the others wait
	to haul it) -- as `decide` says. Returns what to tell the player."""
	var d: Decision = decide(kind, target, gen, members)
	var what: String = JobsScript.KIND_NAMES[kind]
	if d.row >= 0:
		return _join_queued(d, what)
	if not d.code.is_empty():
		return "Can't %s: %s" % [what.to_lower(), reason_text(d.code, target)]
	if not jobs.open_into(kind, target, gen, origin, _read):
		return "Can't %s: %s" % [what.to_lower(), reason_text(_read.error, target)]
	var row: int = _read.value
	var who: int = d.worker
	if who < 0 and _claimed_outside:
		return "%s queued: the first free resident who can takes it" % what
	if who < 0:
		return "%s queued: the forestry crew will see to it" % what
	jobs.assign(row, who)
	var said: String = "%s: %s is on it" % [what, name_of(who)]
	if kind == JobsScript.KIND_FELL:
		said += _haulers_join(target, members)
	return said


func _join_queued(d: Decision, what: String) -> String:
	"""The same job is already on the board: the free selected resident `decide` chose takes it if nobody has it;
	otherwise say who is on it."""
	if d.busy:
		return "%s is already under way: %s is on it" % [what, name_of(d.worker)]
	if d.worker < 0:
		return ("%s is already queued" if _claimed_outside else "%s is already queued for the forestry crew") % what
	jobs.assign(d.row, d.worker)
	return "%s: %s is on it" % [what, name_of(d.worker)]


func order_haul(t: int, members: PackedInt32Array) -> String:
	"""Every free selected resident (up to MAX_HAULERS a trunk) hauls tree `t`'s trunk; with nobody
	selected, one haul is queued for the crew."""
	if members.is_empty():
		return order(JobsScript.KIND_HAUL, t, 0, members, JobsScript.ORIGIN_PLAYER)
	var d: Decision = decide(JobsScript.KIND_HAUL, t, 0, members)
	if not d.code.is_empty():
		return "Can't haul logs: %s" % reason_text(d.code, t)
	return "Haul logs: %d on it" % _add_haulers(t, members)


func decide(kind: int, target: int, gen: int, members: PackedInt32Array) -> Decision:
	"""What ordering `kind` on `target` with `members` selected would do now (see THE DECISION). Changes nothing; the
	answer is reused -- read it before the next call."""
	var d: Decision = _decision
	d.code = ""
	d.row = -1
	d.worker = -1
	d.busy = false
	d.helpers = 0
	d.selected = members.size()
	d.free = 0
	for who: int in members:
		d.free += 1 if _is_free(who) else 0
	if kind != JobsScript.KIND_SAW and kind != JobsScript.KIND_HAUL and jobs.find_into(kind, target, _pick):
		d.row = _pick.value
		d.busy = jobs.worker[d.row] != JobsScript.NOBODY
		if d.busy:
			d.worker = jobs.worker[d.row]
		elif _nearest_free_into(members, target_point(d.row), _pick):
			d.worker = _pick.value
		return d
	d.code = refusal_for(kind, target, gen)
	if d.code.is_empty():
		d.code = _open_refusal(kind, target, members)
	if d.code.is_empty() and _nearest_free_into(members, point_of(kind, target), _pick):
		d.worker = _pick.value
		d.helpers = _helpers_for(kind, target, d.free)
	return d


func _open_refusal(kind: int, target: int, members: PackedInt32Array) -> String:
	"""Why the board cannot take the job (forest_jobs.gd `open_into`'s refusals; a selected haul: none free)."""
	var hands: int = jobs.on_target(JobsScript.KIND_HAUL, target) + jobs.on_target(JobsScript.KIND_FELL, target)
	if kind == JobsScript.KIND_HAUL and hands >= JobsScript.MAX_HAULERS:
		return JobsScript.REFUSE_ENOUGH_HANDS
	if jobs.live_count() >= JobsScript.MAX_JOBS:
		return JobsScript.REFUSE_FULL
	if kind == JobsScript.KIND_HAUL and not members.is_empty() and _free_count(members) == 0:
		return REFUSE_ALL_BUSY
	return ""


func _helpers_for(kind: int, target: int, free: int) -> int:
	"""How many more of the free selection `order` puts on the trunk: felling's haulers after the feller, or every
	hauler of a selected haul -- up to MAX_HAULERS hands on it and the board's free rows."""
	var hands: int = jobs.on_target(JobsScript.KIND_HAUL, target) + jobs.on_target(JobsScript.KIND_FELL, target)
	var rows: int = JobsScript.MAX_JOBS - jobs.live_count()
	if kind == JobsScript.KIND_FELL:
		return maxi(mini(free - 1, mini(JobsScript.MAX_HAULERS - hands - 1, rows - 1)), 0)
	if kind == JobsScript.KIND_HAUL:
		return maxi(mini(free, mini(JobsScript.MAX_HAULERS - hands, rows)), 0)
	return 0


func _is_free(who: int) -> bool:
	"""Whether resident `who` exists and has no woods job (`_nearest_free_into`'s test)."""
	return who >= 0 and who < _cast.actor_count() and not jobs.of_worker_into(who, _probe)


func _free_count(members: PackedInt32Array) -> int:
	"""How many of `members` are free of woods work."""
	var n: int = 0
	for who: int in members:
		n += 1 if _is_free(who) else 0
	return n


func _haulers_join(t: int, members: PackedInt32Array) -> String:
	"""The rest of a felling's party wait by the tree to haul it. Says how many."""
	var joined: int = _add_haulers(t, members)
	return "" if joined == 0 else "; %d waiting to haul" % joined


func _add_haulers(t: int, members: PackedInt32Array) -> int:
	"""A haul for each free member, nearest first, until the trunk has MAX_HAULERS. Returns how many."""
	var joined: int = 0
	while _nearest_free_into(members, _stand.at[t], _busy):
		if not jobs.open_into(JobsScript.KIND_HAUL, t, 0, JobsScript.ORIGIN_PLAYER, _read):
			break
		jobs.assign(_read.value, _busy.value)
		joined += 1
	return joined


func refusal_for(kind: int, target: int, gen: int) -> String:
	"""Why `kind` cannot be done on `target` now ("" when it can)."""
	match kind:
		JobsScript.KIND_FELL:
			return _fell_refusal(target)
		JobsScript.KIND_HAUL:
			var standing: bool = _stand.state_of(target) == StandScript.STATE_MATURE and jobs.on_target(JobsScript.KIND_FELL, target) > 0
			return "" if _stand.is_tree(target) and (_stand.trunk_milli[target] > 0 or standing) else StandScript.REFUSE_NO_TRUNK
		JobsScript.KIND_GATHER:
			return "" if _deadfall.is_live(target, gen) else DeadfallScript.REFUSE_NO_PILE
		JobsScript.KIND_SAW:
			return "" if _stores.wood_milli_u >= Rules.SAW_BATCH_MILLI else "NOT_ENOUGH_WOOD"
		JobsScript.KIND_PLANT:
			return _plant_refusal(target)
		JobsScript.KIND_GRUB:
			return "" if _stand.state_of(target) == StandScript.STATE_STUMP else StandScript.REFUSE_NO_STUMP
	return JobsScript.REFUSE_BAD_KIND


func _fell_refusal(t: int) -> String:
	"""A tree may be felled when it is mature, within reach, and its zone allows it."""
	if _stand.state_of(t) != StandScript.STATE_MATURE:
		return StandScript.REFUSE_NOT_MATURE
	if not _reach.has_point(_stand.at[t]):
		return "BEYOND_REACH"
	return _zones.fell_refusal(_stand, t, pending_fells_in_zone(t))


func _plant_refusal(t: int) -> String:
	"""A sapling goes on a cleared spot within reach, with 0.25 U of compost to hand."""
	if _stand.state_of(t) != StandScript.STATE_CLEARED or not _stand.is_tree(t):
		return StandScript.REFUSE_NOT_CLEARED
	if not _compost_left.is_valid() or int(_compost_left.call()) < Rules.PLANT_COMPOST_MILLI:
		return "NO_COMPOST"
	return "" if _reach.has_point(_stand.at[t]) else "BEYOND_REACH"


func pending_fells_in_zone(t: int) -> int:
	"""Fells already on the board in tree `t`'s zone, other than on `t` itself."""
	if not _zones.zone_at_tile_into(_stand.tile[t], _busy):
		return 0
	var zone: int = _busy.value
	var n: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.kind[row] != JobsScript.KIND_FELL or jobs.target[row] == t:
			continue
		if _zones.zone_at_tile_into(_stand.tile[jobs.target[row]], _busy) and _busy.value == zone:
			n += 1
	return n


func reason_text(code: String, target: int) -> String:
	"""A refusal code in words, naming the zone where it is the zone's rule."""
	match code:
		ZonesScript.REFUSE_PROTECTED:
			return "%s is a conservation zone — never cut" % _zone_name(target)
		ZonesScript.REFUSE_FLOOR:
			return "%s must keep %s" % [_zone_name(target), _floor_words(target)]
		"BEYOND_REACH":
			return "it stands beyond the village's reach (%d m)" % int(Rules.REACH_M)
		"NO_COMPOST":
			return "no compost to plant with (0.25 U needed)"
		"NOT_ENOUGH_WOOD":
			return "the demo stores hold under %s of wood" % Rules.units_text(Rules.SAW_BATCH_MILLI)
		JobsScript.REFUSE_ENOUGH_HANDS:
			return "the trunk has all the haulers it can take"
		REFUSE_ALL_BUSY:
			return "everyone selected is busy"
	return code.to_lower().replace("_", " ")


func _zone_name(t: int) -> String:
	"""The name of tree `t`'s zone."""
	return _zones.names[_busy.value] if _zones.zone_at_tile_into(_stand.tile[t], _busy) else "the woods"


func _floor_words(t: int) -> String:
	"""e.g. "2 of its 6 trees standing (20%)"."""
	if not _zones.zone_at_tile_into(_stand.tile[t], _busy):
		return ""
	var zone: int = _busy.value
	var tally := PackedInt32Array()
	_zones.tally_into(_stand, zone, tally)
	var total: int = tally[StandScript.STATE_MATURE] + tally[StandScript.STATE_YOUNG] + tally[StandScript.STATE_STUMP]
	var percent: int = _zones.retain_percent(zone)
	return "%d of its %d trees standing (%d%%)" % [Rules.floor_mature(total, percent), total, percent]


func _nearest_free_into(members: PackedInt32Array, to: Vector2, out: IntMath.IntResult) -> bool:
	"""The member nearest `to` with no woods job, into `out`; refuses NO_ONE_FREE."""
	var found: bool = false
	var best_d: float = INF
	for who: int in members:
		if who < 0 or who >= _cast.actor_count() or jobs.of_worker_into(who, _probe):
			continue
		var d: float = brain_of(who).surface_point().distance_squared_to(to)
		if not found or d < best_d:
			best_d = d
			found = out.succeed(who)
	return found or out.refuse("NO_ONE_FREE")


func target_point(row: int) -> Vector2:
	"""Where job `row`'s target stands (a tree, a pile, or the log stack for sawing)."""
	return point_of(jobs.kind[row], jobs.target[row])


func point_of(kind: int, target: int) -> Vector2:
	"""Where a job of `kind` on `target` is: the pile, the log stack for sawing and carrying logs, the plank stack for
	carrying planks, else the tree."""
	match kind:
		JobsScript.KIND_GATHER:
			return _deadfall.at[target]
		JobsScript.KIND_SAW, JobsScript.KIND_CARRY_LOGS:
			return Yard.log_stack_at()
		JobsScript.KIND_CARRY_PLANKS:
			return Yard.at(Yard.PLANK_STACK)
	return _stand.at[target]


func cancel_target(kind: int, target: int) -> int:
	"""Take every job of `kind` off `target` (a load in hand is delivered, see CONSERVATION). Returns how
	many."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.kind[row] == kind and jobs.target[row] == target:
			_cancel(row)
			cancelled += 1
	return cancelled


func cancel_all() -> int:
	"""Take every job off the board -- but a delivery, which carries on (see CONSERVATION). Returns how
	many were cancelled."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and not jobs.is_delivery(row):
			_cancel(row)
			cancelled += 1
	return cancelled


func _cancel(row: int) -> void:
	"""Cancel job `row`'s work: with nothing in hand it closes; with a load it becomes that load's
	delivery, walked on to its stack."""
	var milli: int = jobs.load_milli[row]
	if milli <= 0:
		finish(row, "")
		return
	var planks: bool = jobs.kind[row] == JobsScript.KIND_SAW and jobs.step[row] > SAW_WORK_STEP
	jobs.become_delivery(row, JobsScript.KIND_CARRY_PLANKS if planks else JobsScript.KIND_CARRY_LOGS)
	var who: String = worker_name(row)
	_say("%s carries the %s of %s on to the %s" % [who if not who.is_empty() else "The crew", Rules.units_text(milli),
		"planks" if planks else "logs", "plank stack" if planks else "log stack"])


# --- per frame ----------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance every assigned job by `usec` of the cast's time; hand waiting jobs to the idle crew."""
	if usec <= 0:
		return
	_pickup_usec += usec
	if _pickup_usec >= PICKUP_USEC:
		_pickup_usec = 0
		if not _claimed_outside:
			_hand_out()
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.worker[row] != JobsScript.NOBODY:
			_step(row, usec)


func _hand_out() -> void:
	"""Give each waiting job, oldest row first, to the nearest crew member wandering on its own (no work board)."""
	for row: int in JobsScript.MAX_JOBS:
		if not waiting(row):
			continue
		_idle.clear()
		for who: int in _crew:
			var brain: BrainScript = brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.underground and not brain.resting:
				_idle.append(who)
		if _nearest_free_into(_idle, target_point(row), _read):
			jobs.assign(row, _read.value)


func _step(row: int, usec: int) -> void:
	"""Run one frame of job `row`'s current step."""
	var code: int = jobs.current_step(row)
	if code >= JobsScript.STEP_WORK:
		_step_work(row, code - JobsScript.STEP_WORK, usec)
	else:
		_step_walk(row, code)


func _step_walk(row: int, code: int) -> void:
	"""Issue the walk, then wait for the brain to hold at its spot (or give the job back)."""
	var brain: BrainScript = brain_of(jobs.worker[row])
	if jobs.issued[row] == 0:
		_issue_walk(row, code, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != jobs.goal[row]:
		_drop(row)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if brain.arrived_near(jobs.goal[row], ARRIVE_M):
		jobs.advance(row)
		return
	jobs.tries[row] += 1
	jobs.issued[row] = 0
	if jobs.tries[row] >= JobsScript.MAX_TRIES:
		finish(row, "%s: %s couldn't get there" % [JobsScript.KIND_NAMES[jobs.kind[row]], name_of(jobs.worker[row])])


func _issue_walk(row: int, code: int, brain: BrainScript) -> void:
	"""Send the worker to a spot beside this step's target, on the carry walk when it carries."""
	var target: Vector2 = _walk_target(row, code)
	if not _spot_near(target, _stand_of(row, code, brain), brain, _prefer(row, code, brain)):
		finish(row, "%s: no way through to it" % JobsScript.KIND_NAMES[jobs.kind[row]])
		return
	jobs.goal[row] = _found
	jobs.issued[row] = 1
	_hold_for_carry(row, code)
	if code >= JobsScript.STEP_CARRY_STACK:
		brain.order_carry(_found, target)
	else:
		brain.order_move(_found, target)


func _walk_target(row: int, code: int) -> Vector2:
	"""Where a walk step goes: the tree (a lying trunk's middle, for a haul), the pile, the log stack,
	the sawhorse, the plank stack, the baskets or the planting spot."""
	match code:
		JobsScript.STEP_GO_PILE:
			return _deadfall.at[jobs.target[row]]
		JobsScript.STEP_GO_STACK, JobsScript.STEP_CARRY_STACK:
			return Yard.log_stack_at()
		JobsScript.STEP_GO_YARD:
			return Yard.at(Yard.BASKETS)
		JobsScript.STEP_CARRY_SAW:
			return Yard.at(Yard.SAWHORSE)
		JobsScript.STEP_CARRY_PLANKS:
			return Yard.at(Yard.PLANK_STACK)
	var t: int = jobs.target[row]
	if jobs.kind[row] == JobsScript.KIND_HAUL and _stand.trunk_milli[t] > 0:
		return Roots.trunk_middle(_stand, t)
	return _stand.at[t]


func _stand_of(row: int, code: int, brain: BrainScript) -> float:
	"""How far from a walk's target the worker first tries to stand."""
	var retry: float = RING_GAP_M * jobs.tries[row]
	match code:
		JobsScript.STEP_GO_PILE:
			return PILE_STAND_M + retry
		JobsScript.STEP_GO_STACK, JobsScript.STEP_CARRY_STACK:
			return Yard.STAND_M[Yard.SAWHORSE] + retry
		JobsScript.STEP_GO_YARD:
			return Yard.STAND_M[Yard.BASKETS] + retry
		JobsScript.STEP_CARRY_SAW:
			return Yard.STAND_M[Yard.SAWHORSE] + retry
		JobsScript.STEP_CARRY_PLANKS:
			return Yard.STAND_M[Yard.PLANK_STACK] + retry
		JobsScript.STEP_CARRY_SITE:
			return _stand.radius_m[jobs.target[row]] + SITE_STAND_M + retry
	var t: int = jobs.target[row]
	var at_tree: float = maxf(_stand.radius_m[t] + brain.radius + TREE_STAND_M, Roots.stand_m(_stand.look[t], _stand.size[t]))
	if jobs.kind[row] == JobsScript.KIND_HAUL:
		return (TRUNK_STAND_M if _stand.trunk_milli[t] > 0 else at_tree + WAIT_EXTRA_M) + retry
	return at_tree + retry


func _prefer(row: int, code: int, brain: BrainScript) -> Vector2:
	"""Which side of its target a walk should end on: a load is taken up on the log stack's side of the
	trunk or pile, so the carry walk sets off away from it rather than through it; anything else ends
	on the walker's own side."""
	var loads: bool = code == JobsScript.STEP_GO_PILE or (code == JobsScript.STEP_GO_TREE and jobs.kind[row] == JobsScript.KIND_HAUL
		and _stand.trunk_milli[jobs.target[row]] > 0)
	return Yard.log_stack_at() if loads else brain.surface_point()


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript, prefer: Vector2) -> bool:
	"""The standable, reachable spot nearest `prefer` on rings round `target`, clear of anyone
	standing, into `_found`. False when no ring has one. The rings may reach into the woods: the
	forestry reach and its margin, not the village square, bound them."""
	var from: Vector2 = brain.surface_point()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(_cast.space(), members)
	for ring: int in RINGS:
		var radius: float = first_ring + RING_GAP_M * ring
		var found: bool = false
		for k: int in RING_SPOTS:
			var spot: Vector2 = target + Vector2.from_angle(TAU * k / RING_SPOTS) * radius
			if found and spot.distance_squared_to(prefer) >= _found.distance_squared_to(prefer):
				continue
			if CastOrdersScript.spot_ok(_cast.space(), spot, brain.radius, _walk, avoid, _no_taken, from):
				_found = spot
				found = true
		if found:
			return true
	return false


func _hold_for_carry(row: int, code: int) -> void:
	"""What a carry holds in its arms: planks, a sapling basket, else the actor's own log."""
	var actor := _cast.actor(jobs.worker[row]) as DemoActorScript
	if code == JobsScript.STEP_CARRY_PLANKS:
		actor.hold(_props.mesh_of(PLANK_KEY), _hand_fit(PLANK_KEY))
	elif code == JobsScript.STEP_CARRY_SITE:
		actor.hold(_props.mesh_of(BASKET_KEY), _hand_fit(BASKET_KEY))
	elif actor.holding():
		actor.drop_held()


func _hand_fit(key: StringName) -> Transform3D:
	"""A carried model centred between the hands (demo_actor.gd `hold`)."""
	var bound: AABB = _props.drawn_bound(key)
	return Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key)


# --- work ---------------------------------------------------------------------------------------

func _step_work(row: int, work: int, usec: int) -> void:
	"""Start the work (its opening check, its length, the clip and tool), count it, and apply its
	effect at the end. A haul's loading waits, uncounted, while its tree still stands."""
	var brain: BrainScript = brain_of(jobs.worker[row])
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_drop(row)
		return
	if _off_spot(row, brain):
		return
	if jobs.issued[row] == 0:
		if work == JobsScript.WORK_LOAD and _waiting_for_fall(row):
			return
		var refused: String = _begin_work(row, work)
		if not refused.is_empty():
			finish(row, refused)
			return
		_show_work(row, work, brain)
		jobs.issued[row] = 1
	jobs.elapsed_usec[row] += usec
	if jobs.elapsed_usec[row] < jobs.work_usec[row]:
		return
	_stop_work(row, brain)
	var ended: String = _end_work(row, work)
	if not ended.is_empty():
		finish(row, ended)
	elif work == JobsScript.WORK_FELL:
		return  # the feller turned hauler (`_end_fell`), from its first step
	elif not jobs.advance(row):
		_plan_done(row)


func _off_spot(row: int, brain: BrainScript) -> bool:
	"""ARRIVAL, rechecked every frame of work (decision 0411): a worker no longer ARRIVED at its spot credits nothing
	there -- its tool put away, the job back to its walk. True when it was off its spot."""
	if brain.arrived_near(jobs.goal[row], ARRIVE_M):
		return false
	_stop_work(row, brain)
	jobs.rewind_to_walk(row)
	return true


func _waiting_for_fall(row: int) -> bool:
	"""A hauler waiting for its tree to come down: idle beside it while it stands being felled."""
	var t: int = jobs.target[row]
	return _stand.trunk_milli[t] <= 0 and _stand.state_of(t) == StandScript.STATE_MATURE \
		and jobs.on_target(JobsScript.KIND_FELL, t) > 0


func _begin_work(row: int, work: int) -> String:
	"""The work step's opening check and its length in demo time ("" to go ahead)."""
	var who: int = jobs.worker[row]
	var t: int = jobs.target[row]
	jobs.work_usec[row] = step_usec(work, t, who)
	match work:
		JobsScript.WORK_FELL:
			var code: String = _fell_refusal(t)
			return "" if code.is_empty() else "Can't fell: %s" % reason_text(code, t)
		JobsScript.WORK_LOAD:
			return "" if _stand.trunk_milli[t] > 0 else "The %s is hauled in" % _tree_name(t)
		JobsScript.WORK_GATHER:
			return "" if _deadfall.is_live(t, jobs.target_gen[row]) else "The deadfall was gone"
		JobsScript.WORK_FETCH_LOGS:
			return "" if _stores.wood_milli_u >= Rules.SAW_BATCH_MILLI else "Can't saw: not enough wood in the stores"
		JobsScript.WORK_PLANT:
			return _begin_planting(row)
		JobsScript.WORK_GRUB:
			return "" if _stand.state_of(t) == StandScript.STATE_STUMP else "The stump was gone"
	return ""


func step_usec(work: int, target: int, who: int) -> int:
	"""How long work step `work` on `target` takes resident `who` now (-1: nobody known, at base skill), in demo
	microseconds: its WU at `who`'s skill when the step trains one, this season's and today's weather's pace -- the
	ONE timing the work and the action card's work share."""
	var season_pm: int = Rules.season_permille(_calendar.now().season, work == JobsScript.WORK_FELL)
	var speed_pm: int = Rules.weather_permille(_weather.event())
	var skill: int = Rules.SKILL_SAWING if work == JobsScript.WORK_SAW else Rules.SKILL_FELLING
	var level: int = skills.level_of(who, skill) if _trains(work) and who >= 0 else 0
	return Rules.work_usec(work_wu(work, target), level, season_pm, speed_pm)


func work_wu(work: int, target: int) -> int:
	"""A work step's WU: §5.9's felling and planting, the demo's for the rest (a deadfall pile's by its size)."""
	match work:
		JobsScript.WORK_FELL:
			return Rules.FELL_WU
		JobsScript.WORK_GATHER:
			return Rules.deadfall_wu(_deadfall.milli[target])
		JobsScript.WORK_SAW:
			return Rules.SAW_WU
		JobsScript.WORK_PLANT:
			return Rules.PLANT_WU
		JobsScript.WORK_GRUB:
			return Rules.GRUB_WU
		JobsScript.WORK_DROP, JobsScript.WORK_STACK_PLANKS:
			return Rules.DROP_WU
	return Rules.LOAD_WU


static func _trains(work: int) -> bool:
	"""Whether a work step is felling or sawing (the two skills)."""
	return work == JobsScript.WORK_FELL or work == JobsScript.WORK_SAW


func _begin_planting(row: int) -> String:
	"""Planting's compost is spent as the job's work first starts (§5.9's cost) -- once for the job, not
	again when a planter called away, or another, starts it again (see CONSERVATION); refuses a spot no
	longer clear."""
	if _stand.state_of(jobs.target[row]) != StandScript.STATE_CLEARED:
		return "Can't plant: the spot is not clear"
	if jobs.paid[row] == 1:
		return ""
	if not _compost_take.is_valid() or not bool(_compost_take.call(Rules.PLANT_COMPOST_MILLI)):
		return "Can't plant: no compost to plant with (0.25 U needed)"
	jobs.paid[row] = 1
	return ""


func _show_work(row: int, work: int, brain: BrainScript) -> void:
	"""The work's clip, and its tool in hand: the axe to fell (the beaver gnaws, with none), the spade
	to grub and plant."""
	var who: int = jobs.worker[row]
	var gnawing: bool = work == JobsScript.WORK_FELL and skills.gnaws_wood(who)
	var chops: bool = (work == JobsScript.WORK_FELL and not gnawing) or work == JobsScript.WORK_GRUB
	brain.play_in_place(CLIP_CHOP if chops else CLIP_WORK)
	var actor := _cast.actor(who) as DemoActorScript
	if work == JobsScript.WORK_FELL and not gnawing:
		actor.set_work_tool(_props.mesh_of(AXE_KEY), axe_fit(_props))
	elif work == JobsScript.WORK_GRUB or work == JobsScript.WORK_PLANT:
		actor.set_work_tool(_props.mesh_of(SPADE_KEY), axe_fit(_props, SPADE_KEY))


func _stop_work(row: int, brain: BrainScript) -> void:
	"""The work is over: idle, tool away."""
	brain.play_in_place(BrainScript.CLIP_IDLE)
	(_cast.actor(jobs.worker[row]) as DemoActorScript).clear_work_tool()


func _end_work(row: int, work: int) -> String:
	"""The work step's effect ("" when it took)."""
	match work:
		JobsScript.WORK_FELL:
			return _end_fell(row)
		JobsScript.WORK_LOAD:
			return _end_load(row)
		JobsScript.WORK_GATHER:
			return _end_gather(row)
		JobsScript.WORK_DROP:
			return _end_drop(row)
		JobsScript.WORK_FETCH_LOGS:
			return "" if _take_logs(row) else "Can't saw: not enough wood in the stores"
		JobsScript.WORK_SAW:
			_credit(row, Rules.SKILL_SAWING, Rules.SAW_WU)
			return ""
		JobsScript.WORK_STACK_PLANKS:
			return _end_stack_planks(row)
		JobsScript.WORK_PLANT:
			return _end_plant(row)
		JobsScript.WORK_GRUB:
			return _end_grub(row)
	return ""


func _end_fell(row: int) -> String:
	"""REQ-SET-138: the store debits the tree's wood once; it falls away from the feller and lies as
	its trunk; the feller turns hauler."""
	var who: int = jobs.worker[row]
	var t: int = jobs.target[row]
	var away: Vector2 = (_stand.at[t] - brain_of(who).position).normalized()
	if not _stand.fell_into(t, _calendar.now().absolute_day, away, skills.gnaws_wood(who), _read):
		return "Can't fell: %s" % reason_text(_read.error, t)
	_credit(row, Rules.SKILL_FELLING, Rules.FELL_WU)
	_say("%s %s the %s %s: %s of wood lie ready to haul" % [name_of(who), "gnawed down" if skills.gnaws_wood(who) else "felled",
		_tree_name(t), _where(t), Rules.units_text(_read.value)])
	jobs.become(row, JobsScript.KIND_HAUL)
	return ""


func _end_load(row: int) -> String:
	"""A load off the trunk into the hauler's arms."""
	if not _stand.take_trunk_into(jobs.target[row], Rules.CARRY_LOAD_MILLI, _read):
		return "The %s is hauled in" % _tree_name(jobs.target[row])
	jobs.load_milli[row] = _read.value
	return ""


func _end_gather(row: int) -> String:
	"""The deadfall pile into the gatherer's arms."""
	if not _deadfall.take_into(jobs.target[row], jobs.target_gen[row], _read):
		return "The deadfall was gone"
	jobs.load_milli[row] = _read.value
	return ""


func _end_drop(row: int) -> String:
	"""The load onto the log stack: into the demo stores' one wood stock."""
	var milli: int = jobs.load_milli[row]
	jobs.load_milli[row] = 0
	_stores.add_wood(milli)
	if jobs.kind[row] == JobsScript.KIND_CARRY_LOGS:
		_say("%s stacked %s of logs: the demo stores hold %s of wood" % [name_of(jobs.worker[row]), Rules.units_text(milli),
			Rules.units_text(_stores.wood_milli_u)])
	elif jobs.kind[row] == JobsScript.KIND_GATHER:
		_say("%s gathered %s of deadfall into the stores" % [name_of(jobs.worker[row]), Rules.units_text(milli)])
	elif _stand.trunk_milli[jobs.target[row]] <= 0 and jobs.on_target(JobsScript.KIND_HAUL, jobs.target[row]) == 1:
		_say("The %s's logs are all stacked: the demo stores hold %s of wood" % [_tree_name(jobs.target[row]),
			Rules.units_text(_stores.wood_milli_u)])
	return ""


func _take_logs(row: int) -> bool:
	"""A batch of logs off the stock for the sawhorse."""
	if not _stores.take_wood(Rules.SAW_BATCH_MILLI):
		return false
	jobs.load_milli[row] = Rules.SAW_BATCH_MILLI
	return true


func _end_stack_planks(row: int) -> String:
	"""The sawn planks onto the plank stack."""
	var milli: int = jobs.load_milli[row]
	jobs.load_milli[row] = 0
	_stores.add_planks(milli)
	_say("%s sawed %s of planks: the stack holds %s" % [name_of(jobs.worker[row]), Rules.units_text(milli),
		Rules.units_text(_stores.plank_milli_u)])
	return ""


func _end_plant(row: int) -> String:
	"""§5.9: the sapling goes in; it matures in 48 days."""
	var t: int = jobs.target[row]
	var day: int = _calendar.now().absolute_day
	if not _stand.plant_into(t, day, _read):
		return "Can't plant: %s" % reason_text(_read.error, t)
	_say("%s planted a young oak %s: it matures on day %d" % [name_of(jobs.worker[row]), _where(t), _read.value])
	return ""


func _end_grub(row: int) -> String:
	"""The stump dug out: a cleared spot, ready to replant."""
	var t: int = jobs.target[row]
	if not _stand.grub_into(t, _read):
		return "The stump was gone"
	_say("%s grubbed out the stump %s: the spot can be replanted" % [name_of(jobs.worker[row]), _where(t)])
	return ""


func _credit(row: int, skill: int, wu: int) -> void:
	"""The worker's XP for the WU done; a new level is announced."""
	var who: int = jobs.worker[row]
	if skills.add_work(who, skill, wu):
		_say("%s is now a level %d %s" % [name_of(who), skills.level_of(who, skill),
			"feller" if skill == Rules.SKILL_FELLING else "sawyer"])


func _plan_done(row: int) -> void:
	"""The plan ran out: a hauler goes back while wood lies there; anything else is over."""
	if jobs.kind[row] == JobsScript.KIND_HAUL and _stand.trunk_milli[jobs.target[row]] > 0:
		jobs.restart(row)
		return
	finish(row, "")


func preview_into(card: CardScript, kind: int, target: int, gen: int, members: PackedInt32Array) -> void:
	"""The action card for `kind` on `target` with `members` selected (decision 0332): `decide`'s refusal and
	assignment, the job's result, cost and needs (forest_card.gd), and its work at the named resident's skill."""
	var d: Decision = decide(kind, target, gen, members)
	card.reset(ForestCard.verb_text(kind, _tree_label(kind, target)))
	ForestCard.fill(card, kind, _result_amount(kind, target), _stores.wood_milli_u, _compost())
	if d.row >= 0 and kind == JobsScript.KIND_PLANT and jobs.paid[d.row] == 1:
		ForestCard.compost_paid(card)
	if not d.code.is_empty() and d.row < 0:
		card.refuse(d.code, reason_text(d.code, target), ForestCard.fix_for(d.code))
		return
	card.work_usec = plan_usec(kind, target, d.worker if not d.busy else -1)
	if kind == JobsScript.KIND_FELL:
		card.work_note = ForestCard.FELL_NOTE % ForestCard.trips(Rules.TREE_WOOD_MILLI)
	elif kind == JobsScript.KIND_HAUL:
		card.work_note = ForestCard.HAUL_NOTE
	_preview_who(card, kind, d)
	card.members = members_line(members)


func members_line(members: PackedInt32Array) -> String:
	"""A group order's preview, member by member (decision 0411, review UX-001): who of the selection could take a woods
	job -- not one with a woods job already, nor one the water's rescue holds (it takes no order)."""
	if members.size() <= 1:
		return ""
	var names := PackedStringArray()
	var why := PackedStringArray()
	for who: int in members:
		if who < 0 or who >= _cast.actor_count():
			continue
		names.append(name_of(who))
		why.append(WorkIds.OTHER_WOODS_JOB if not _is_free(who) else (WorkIds.HELD if brain_of(who).water_hold else ""))
	return CardScript.each_member(names, why)


func _preview_who(card: CardScript, kind: int, d: Decision) -> void:
	"""The card's assignment in the one command grammar (action_card.gd)."""
	if d.busy:
		card.who = CardScript.under_way(name_of(d.worker))
		return
	if d.worker < 0 and _queue_words.is_valid():
		card.who = String(_queue_words.call(activity_of(kind), d.selected))
		return
	if d.worker < 0:
		card.who = CardScript.queue_for("the forestry crew", _crew_names(), d.selected)
		return
	card.worker = d.worker
	if kind == JobsScript.KIND_FELL:
		card.who = CardScript.lead_with(name_of(d.worker), d.free, d.selected, d.helpers, "waiting to haul")
	elif kind == JobsScript.KIND_HAUL and d.selected > 0:
		card.who = CardScript.lead_with(name_of(d.worker), d.free, d.selected, d.helpers - 1, "more hauling")
	else:
		card.who = CardScript.assign_selected(name_of(d.worker), d.free, d.selected)


func plan_usec(kind: int, target: int, who: int) -> int:
	"""The work of a job's plan for resident `who` (-1: base skill): its work steps' `step_usec`; a haul's loading
	and stacking once a trip, for every trip the trunk's wood takes."""
	var plan: Array = JobsScript.PLANS[kind]
	var usec: int = 0
	for code: Variant in plan:
		if int(code) >= JobsScript.STEP_WORK:
			usec += step_usec(int(code) - JobsScript.STEP_WORK, target, who)
	if kind == JobsScript.KIND_HAUL:
		usec *= ForestCard.trips(_trunk_or_tree(target))
	return usec


func _trunk_or_tree(t: int) -> int:
	"""The wood a haul will carry: the trunk lying, or a whole tree's while it still stands to be felled."""
	return _stand.trunk_milli[t] if _stand.trunk_milli[t] > 0 else Rules.TREE_WOOD_MILLI


func _result_amount(kind: int, target: int) -> int:
	"""The milli-U a job brings in: a tree's or a trunk's wood, a pile's, a sawing batch (0: none)."""
	match kind:
		JobsScript.KIND_FELL:
			return Rules.TREE_WOOD_MILLI
		JobsScript.KIND_HAUL:
			return _trunk_or_tree(target) if _stand.is_tree(target) else 0
		JobsScript.KIND_GATHER:
			return _deadfall.milli[target] if target >= 0 and target < _deadfall.milli.size() else 0
		JobsScript.KIND_SAW:
			return Rules.SAW_BATCH_MILLI
	return 0


func _tree_label(kind: int, target: int) -> String:
	"""What the card's verb names: the tree's kind ("the oak"), the spot, or nothing for sawing and gathering."""
	if kind == JobsScript.KIND_SAW or kind == JobsScript.KIND_GATHER or not _stand.is_tree(target):
		return ""
	if kind == JobsScript.KIND_FELL or kind == JobsScript.KIND_HAUL:
		return "the " + _tree_name(target)
	return _stand.label_of(target).to_lower()


func _compost() -> int:
	"""The compost planting would draw on (milli-U; 0 with none wired)."""
	return int(_compost_left.call()) if _compost_left.is_valid() else 0


func _crew_names() -> PackedStringArray:
	"""The routine forestry crew's names (made again only when the crew changed; read, never kept)."""
	if _named_crew != _crew:
		_named_crew = _crew.duplicate()
		_names_of_crew.clear()
		for who: int in _crew:
			_names_of_crew.append(name_of(who))
	return _names_of_crew


func resume_rule(who: int) -> int:
	"""demo_command.gd `add_resume_rule`: a resident with a woods job goes back to it after another order (`_drop`)."""
	return InterruptScript.RESUMES if jobs.of_worker_into(who, _probe) else InterruptScript.NOT_MINE


func _drop(row: int) -> void:
	"""The worker was ordered away: the job waits on the board where it had got to."""
	var who: int = jobs.worker[row]
	(_cast.actor(who) as DemoActorScript).clear_work_tool()
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	if brain_of(who).order != BrainScript.ORDER_NONE:
		brain_of(who).remember_unfinished(unfinished_of(row))
	_say("%s left the %s job" % [name_of(who), JobsScript.KIND_NAMES[jobs.kind[row]].to_lower()])


func finish(row: int, text: String) -> void:
	"""Close job `row`, send its worker back to its routine, and say how it ended. A job with a load in
	hand is not closed: it waits on the board with it, for a way there, tried again next hour."""
	var who: int = jobs.worker[row]
	if jobs.load_milli[row] > 0:
		jobs.unassign(row)
		jobs.rewind_to_walk(row)
		jobs.blocked[row] = 1
	else:
		jobs.close(row)
	_free_worker(who)
	if not text.is_empty():
		_say(text)


func _free_worker(who: int) -> void:
	"""A worker done with its job: tool away, hands empty, idle, back to its routine."""
	if who < 0 or who >= _cast.actor_count():
		return
	var actor := _cast.actor(who) as DemoActorScript
	actor.clear_work_tool()
	if actor.holding():
		actor.drop_held()
	actor.brain.play_in_place(BrainScript.CLIP_IDLE)
	actor.brain.work_done()


func take_back(brain: RefCounted, row: int, serial: int) -> bool:
	"""Give woods job `row` back to the resident it was taken from (resident_brain.gd RESUMING), if it is
	still the same job (its serial: a haul become a delivery still is), waiting for someone and not for a
	way there."""
	var who: int = int(brain.get(&"index"))
	if not jobs.is_live(row) or jobs.serial[row] != serial or is_paused(row):
		return false
	if jobs.worker[row] != JobsScript.NOBODY or jobs.blocked[row] == 1 or jobs.of_worker_into(who, _probe):
		return false
	jobs.assign(row, who)
	return true


func unfinished_of(row: int) -> UnfinishedScript:
	"""Job `row` as an order-list entry: taken back by `take_back` while it is still the same job, naming the work
	board task it is (decision 0411)."""
	return UnfinishedScript.new(take_back.bind(row, jobs.serial[row]), job_words(row), WorkIds.SOURCE_WOODS,
		jobs.serial[row])


func job_words(row: int) -> String:
	"""A job in a few words, as the order list says it: "Fell (woods)"."""
	return "%s (woods)" % JobsScript.KIND_NAMES[jobs.kind[row]]


# --- the work board's hands (decision 0411) ---------------------------------------------------------

func set_claimer(queue_words: Callable) -> void:
	"""The village's work board claims the waiting jobs from now on (the routine crew's hand-out stands down);
	`queue_words(activity, selected) -> String` is its "who" for a job left on the board, the action card's."""
	_claimed_outside = true
	_queue_words = queue_words


func claims_outside() -> bool:
	"""Whether the work board claims the waiting jobs."""
	return _claimed_outside


func waiting(row: int) -> bool:
	"""Whether job `row` waits on the board for a worker and could be handed out now (not paused, not waiting for a
	way)."""
	return jobs.is_live(row) and jobs.worker[row] == JobsScript.NOBODY and jobs.blocked[row] == 0 and not is_paused(row)


func claim(row: int, who: int) -> bool:
	"""The work board hands waiting job `row` to resident `who`, who sets off at once. False when the job is not
	waiting or `who` has a woods job already."""
	if not waiting(row) or not _is_free(who):
		return false
	jobs.assign(row, who)
	_step(row, 0)
	return true


func is_paused(row: int) -> bool:
	"""Whether the player paused job `row`."""
	return jobs.is_live(row) and _paused_serial[row] == jobs.serial[row]


func pause(row: int, on: bool) -> String:
	"""The player pauses job `row` (its worker let go; nobody takes it until it is resumed) or resumes it. A load in
	hand is never paused: its carrier finishes the delivery first. "" when done, else why not."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if not on:
		_paused_serial[row] = 0
		return ""
	if is_paused(row):
		return WorkIds.PAUSED_ALREADY
	if jobs.load_milli[row] > 0:
		return WorkIds.CARRYING % _carrier_words(row)
	_paused_serial[row] = jobs.serial[row]
	_let_job_go(row)
	return ""


func cancel_row(row: int) -> String:
	"""The player cancels job `row` alone (`_cancel`: a load in hand becomes its delivery, carried on; see
	CONSERVATION). A delivery is not cancelled. "" when done."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if jobs.is_delivery(row):
		return WorkIds.DELIVERY_GOES_ON
	_paused_serial[row] = 0
	_cancel(row)
	return ""


func reassign(row: int, who: int) -> String:
	"""The player gives job `row` to resident `who` instead, taken off whatever it was doing; the one on it is let go --
	AFTER the job is `who`'s, so it cannot take it straight back up from its own order list. A load in hand stays with
	its carrier (no load changes hands from afar). "" when done, else why not."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if who < 0 or who >= _cast.actor_count():
		return "nobody to give it to"
	if jobs.load_milli[row] > 0:
		return WorkIds.CARRYING % _carrier_words(row)
	if jobs.of_worker_into(who, _probe) and _probe.value != row:
		return WorkIds.OTHER_WOODS_JOB
	var old: int = jobs.worker[row]
	if old == who:
		return ""
	if old != JobsScript.NOBODY:
		jobs.unassign(row)
		jobs.rewind_to_walk(row)
	_paused_serial[row] = 0
	jobs.assign(row, who)
	_step(row, 0)
	_free_worker(old)
	return ""


func _let_job_go(row: int) -> void:
	"""Job `row`'s worker, if any, is let go (back to its order list or routine); the job waits where it had got to."""
	var who: int = jobs.worker[row]
	if who == JobsScript.NOBODY:
		return
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	_free_worker(who)


static func activity_of(job_kind: int) -> int:
	"""Which crew activity a woods job is (decision 0411): carrying and gathering wood is HAULING, the rest WOODS."""
	match job_kind:
		JobsScript.KIND_HAUL, JobsScript.KIND_GATHER, JobsScript.KIND_CARRY_LOGS, JobsScript.KIND_CARRY_PLANKS:
			return WorkIds.ACT_HAUL
	return WorkIds.ACT_WOODS


func target_words(row: int) -> String:
	"""A job's target as the Work screen names it: "the oak in the North stand", "the sawhorse", "the log stack"."""
	var t: int = jobs.target[row]
	match jobs.kind[row]:
		JobsScript.KIND_FELL, JobsScript.KIND_HAUL:
			return "the %s %s" % [_tree_name(t), _where(t)]
		JobsScript.KIND_SAW:
			return "the sawhorse"
		JobsScript.KIND_GATHER:
			return "a deadfall pile"
		JobsScript.KIND_CARRY_LOGS:
			return "the log stack"
		JobsScript.KIND_CARRY_PLANKS:
			return "the plank stack"
	return "%s %s" % [_stand.label_of(t).to_lower(), _where(t)]


func remaining_usec(row: int) -> int:
	"""The work left in job `row`'s plan from its current step (a haul's: this trip's), at its worker's skill -- the
	work steps' `step_usec`, the walks not counted."""
	var plan: Array = JobsScript.PLANS[jobs.kind[row]]
	var usec: int = 0
	for k: int in range(jobs.step[row], plan.size()):
		if int(plan[k]) >= JobsScript.STEP_WORK:
			usec += step_usec(int(plan[k]) - JobsScript.STEP_WORK, jobs.target[row], jobs.worker[row])
	return maxi(usec - jobs.elapsed_usec[row], 0)


func _carrier_words(row: int) -> String:
	"""Who carries job `row`'s load ("the crew" while it waits on the board)."""
	var who: String = worker_name(row)
	return who if not who.is_empty() else "the crew"


# --- routine work -------------------------------------------------------------------------------

func raise_routine_jobs() -> void:
	"""The crew's own work: haul every trunk lying with nobody on it (a storm's blow-down, a felled tree
	left), and fell the next tree in each auto-fell zone that has none on the board."""
	for t: int in _stand.count():
		if _stand.trunk_milli[t] > 0 and jobs.on_target(JobsScript.KIND_HAUL, t) == 0:
			jobs.open_into(JobsScript.KIND_HAUL, t, 0, JobsScript.ORIGIN_ROUTINE, _read)
	jobs.blocked.fill(0)
	for zone: int in ZonesScript.MAX_ZONES:
		if _zones.is_zone(zone) and _zones.auto_fell[zone] == 1 and not _zone_has_fell(zone):
			_raise_zone_fell(zone)


func _zone_has_fell(zone: int) -> bool:
	"""Whether a fell is on the board in `zone`."""
	for row: int in JobsScript.MAX_JOBS:
		if jobs.kind[row] == JobsScript.KIND_FELL and _zones.zone_at_tile_into(_stand.tile[jobs.target[row]], _busy) \
				and _busy.value == zone:
			return true
	return false


func _raise_zone_fell(zone: int) -> void:
	"""Queue a fell on the zone's mature tree nearest the log stack, if its floor allows one."""
	var best: int = StandScript.NO_SLOT
	var best_d: float = INF
	var stack: Vector2 = Yard.log_stack_at()
	for t: int in _stand.count():
		if not _zones.zone_at_tile_into(_stand.tile[t], _busy) or _busy.value != zone:
			continue
		if _fell_refusal(t).is_empty() and _stand.at[t].distance_squared_to(stack) < best_d:
			best_d = _stand.at[t].distance_squared_to(stack)
			best = t
	if best != StandScript.NO_SLOT:
		jobs.open_into(JobsScript.KIND_FELL, best, 0, JobsScript.ORIGIN_ROUTINE, _read)


# --- readouts -----------------------------------------------------------------------------------

func task_text(who: int) -> String:
	"""What resident `who` is doing in the woods, for the party panel ("" when nothing)."""
	if not jobs.of_worker_into(who, _read):
		return ""
	var row: int = _read.value
	var code: int = jobs.current_step(row)
	match code:
		JobsScript.STEP_CARRY_STACK:
			return "Carrying %s of logs to the log stack" % Rules.units_text(jobs.load_milli[row])
		JobsScript.STEP_CARRY_SAW:
			return "Carrying logs to the sawhorse"
		JobsScript.STEP_CARRY_PLANKS:
			return "Carrying planks to the stack"
		JobsScript.STEP_CARRY_SITE:
			return "Carrying a sapling basket"
	if jobs.kind[row] == JobsScript.KIND_HAUL and _waiting_for_fall(row):
		return "Waiting to haul %s" % _where(jobs.target[row])
	return "%s %s%s" % [JobsScript.KIND_DOING[jobs.kind[row]], _object_of(row), _percent_text(row, code)]


func _object_of(row: int) -> String:
	"""The words for a job's target in the "doing" line."""
	match jobs.kind[row]:
		JobsScript.KIND_GATHER, JobsScript.KIND_SAW, JobsScript.KIND_CARRY_LOGS, JobsScript.KIND_CARRY_PLANKS:
			return ""
		JobsScript.KIND_FELL, JobsScript.KIND_GRUB:
			return "the " + _stand.label_of(jobs.target[row]).to_lower()
	return _where(jobs.target[row])


func _percent_text(row: int, code: int) -> String:
	"""The " — 40%" after a timed step's words, while it is being worked."""
	if code < JobsScript.STEP_WORK or jobs.issued[row] == 0 or jobs.work_usec[row] <= 0:
		return ""
	return " — %d%%" % mini(100, int(jobs.elapsed_usec[row] * 100 / jobs.work_usec[row]))


func _where(t: int) -> String:
	"""A tree's place in words: "in the North stand", "by the woods' edge"."""
	if _zones.zone_at_tile_into(_stand.tile[t], _busy):
		return "in the %s" % _zones.names[_busy.value]
	return "at the woods' edge"


func _tree_name(t: int) -> String:
	"""A tree's kind in words ("oak", "beech"), whatever now stands there."""
	return StandScript.LOOK_NAMES[_stand.look[t]].to_lower()


func worker_name(row: int) -> String:
	"""Whoever has job `row` ("" while it waits on the board)."""
	var who: int = jobs.worker[row]
	return name_of(who) if who >= 0 and who < _cast.actor_count() else ""


func job_line(row: int) -> String:
	"""One line of the Woods panel's job queue."""
	var who: String = worker_name(row)
	var what: String = JobsScript.KIND_NAMES[jobs.kind[row]]
	var t: int = jobs.target[row]
	if jobs.kind[row] == JobsScript.KIND_FELL or jobs.kind[row] == JobsScript.KIND_HAUL:
		what += " — the %s %s" % [_tree_name(t), _where(t)]
	elif jobs.kind[row] != JobsScript.KIND_SAW and jobs.kind[row] != JobsScript.KIND_GATHER and not jobs.is_delivery(row):
		what += " — %s %s" % [_stand.label_of(t).to_lower(), _where(t)]
	return "%s: %s" % [what, who if not who.is_empty() else "waiting for the crew"]


static func axe_fit(props: PropsScript, key: StringName = AXE_KEY) -> Transform3D:
	"""A hand tool standing along +Y (the axe, the spade) in the right hand bone's frame: gripped
	AXE_GRIP_SHARE of its height from the bottom, turned by AXE_EULER_DEG."""
	var bound: AABB = props.drawn_bound(key)
	var grip := Vector3(bound.get_center().x, bound.position.y + bound.size.y * AXE_GRIP_SHARE, bound.get_center().z)
	var turn := Basis.from_euler(AXE_EULER_DEG * (PI / 180.0))
	return Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -grip) * props.fit_of(key)


func _say(text: String) -> void:
	"""Pass a line to the notice callback, if any."""
	if _notice.is_valid():
		_notice.call(text)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s display name."""
	return (_cast.actor(who) as DemoActorScript).display_name
