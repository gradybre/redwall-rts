extends RefCounted
## The woods' hands: residents carrying out the woods' job board. Decision 0196 (live demo). The
## walking, carrying and the work clip go through the cast's own brains, as the farm's crew does
## (demo/farm/farm_crew.gd); the EFFECT of each piece of work is a call on the real ResourceNode rows
## (forest_stand.gd), the deadfall, the skills or the demo stores at the step it belongs to.
##
## WHO WORKS. An order given with residents selected goes to the nearest of them; felling with several
## selected, the others wait by the tree to haul it. Anything left on the board -- queued from the
## Woods panel with nobody selected, a storm's fallen tree to clear, an auto-fell zone's next tree --
## is taken by the ROUTINE forestry crew (CREW_KEYS: the squirrel forester and the beaver) when one of
## them is wandering on its own. Anybeast can do any of it (LORE-P12); skill only changes how long it
## takes (forest_skills.gd).
##
## HOW A STEP RUNS. A walk is `order_move()` -- or `order_carry()`, the carry walk, for logs, planks and
## a sapling basket -- to a standable spot beside its target, facing it; it is done when the brain
## holds there. A work step plays its clip in place for its WU (forest_rules.gd `work_usec`: skill,
## season and weather), the axe in hand for felling (the beaver gnaws, with none) and the spade for
## grubbing and planting, and applies its effect at the end. A resident ordered elsewhere drops the
## job back on the board where it had got to, load and all; a job closed with a load in hand puts the
## load in store, so no wood is lost.

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
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")

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
	"""Queue `kind` on `target` and, with `members`, give it to the nearest of them now (felling: the
	others wait to haul it). Returns what to tell the player."""
	if kind != JobsScript.KIND_SAW and kind != JobsScript.KIND_HAUL and jobs.find_into(kind, target, _read):
		return _join_queued(_read.value, members)
	var code: String = refusal_for(kind, target, gen)
	if not code.is_empty():
		return "Can't %s: %s" % [JobsScript.KIND_NAMES[kind].to_lower(), reason_text(code, target)]
	if not jobs.open_into(kind, target, gen, origin, _read):
		return "Can't %s: %s" % [JobsScript.KIND_NAMES[kind].to_lower(), reason_text(_read.error, target)]
	var row: int = _read.value
	if not _nearest_free_into(members, target_point(row), _read):
		return "%s queued: the forestry crew will see to it" % JobsScript.KIND_NAMES[kind]
	var who: int = _read.value
	jobs.assign(row, who)
	var said: String = "%s: %s is on it" % [JobsScript.KIND_NAMES[kind], name_of(who)]
	if kind == JobsScript.KIND_FELL:
		said += _haulers_join(target, members)
	return said


func _join_queued(row: int, members: PackedInt32Array) -> String:
	"""The same job is already on the board: a free selected resident takes it if nobody has it;
	otherwise say who is on it."""
	var what: String = JobsScript.KIND_NAMES[jobs.kind[row]]
	if jobs.worker[row] != JobsScript.NOBODY:
		return "%s is already under way: %s is on it" % [what, worker_name(row)]
	if not _nearest_free_into(members, target_point(row), _busy):
		return "%s is already queued for the forestry crew" % what
	jobs.assign(row, _busy.value)
	return "%s: %s is on it" % [what, name_of(_busy.value)]


func order_haul(t: int, members: PackedInt32Array) -> String:
	"""Every free selected resident (up to MAX_HAULERS a trunk) hauls tree `t`'s trunk; with nobody
	selected, one haul is queued for the crew."""
	var code: String = refusal_for(JobsScript.KIND_HAUL, t, 0)
	if not code.is_empty():
		return "Can't haul logs: %s" % reason_text(code, t)
	if members.is_empty():
		return order(JobsScript.KIND_HAUL, t, 0, members, JobsScript.ORIGIN_PLAYER)
	var joined: int = _add_haulers(t, members)
	if joined > 0:
		return "Haul logs: %d on it" % joined
	if jobs.on_target(JobsScript.KIND_HAUL, t) >= JobsScript.MAX_HAULERS:
		return "Can't haul logs: the trunk has all the haulers it can take"
	return "Can't haul logs: everyone selected is busy"


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
	match jobs.kind[row]:
		JobsScript.KIND_GATHER:
			return _deadfall.at[jobs.target[row]]
		JobsScript.KIND_SAW:
			return Yard.log_stack_at()
	return _stand.at[jobs.target[row]]


func cancel_target(kind: int, target: int) -> int:
	"""Take every job of `kind` off `target` (loads in hand go into store). Returns how many."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.kind[row] == kind and jobs.target[row] == target:
			finish(row, "")
			cancelled += 1
	return cancelled


func cancel_all() -> int:
	"""Take every job off the board. Returns how many."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row):
			finish(row, "")
			cancelled += 1
	return cancelled


# --- per frame ----------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance every assigned job by `usec` of the cast's time; hand waiting jobs to the idle crew."""
	if usec <= 0:
		return
	_pickup_usec += usec
	if _pickup_usec >= PICKUP_USEC:
		_pickup_usec = 0
		_hand_out()
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.worker[row] != JobsScript.NOBODY:
			_step(row, usec)


func _hand_out() -> void:
	"""Give each waiting job, oldest row first, to the nearest crew member wandering on its own."""
	for row: int in JobsScript.MAX_JOBS:
		if not jobs.is_live(row) or jobs.worker[row] != JobsScript.NOBODY:
			continue
		_idle.clear()
		for who: int in _crew:
			var brain: BrainScript = brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.underground:
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
	if brain.position.distance_to(jobs.goal[row]) <= ARRIVE_M:
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


func _waiting_for_fall(row: int) -> bool:
	"""A hauler waiting for its tree to come down: idle beside it while it stands being felled."""
	var t: int = jobs.target[row]
	return _stand.trunk_milli[t] <= 0 and _stand.state_of(t) == StandScript.STATE_MATURE \
		and jobs.on_target(JobsScript.KIND_FELL, t) > 0


func _begin_work(row: int, work: int) -> String:
	"""The work step's opening check and its length in demo time ("" to go ahead)."""
	var who: int = jobs.worker[row]
	var t: int = jobs.target[row]
	var season_pm: int = Rules.season_permille(_calendar.now().season, work == JobsScript.WORK_FELL)
	var speed_pm: int = Rules.weather_permille(_weather.event())
	var wu: int = _work_wu(row, work)
	var skill: int = Rules.SKILL_SAWING if work == JobsScript.WORK_SAW else Rules.SKILL_FELLING
	var level: int = skills.level_of(who, skill) if _trains(work) else 0
	jobs.work_usec[row] = Rules.work_usec(wu, level, season_pm, speed_pm)
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
			return _begin_planting(t)
		JobsScript.WORK_GRUB:
			return "" if _stand.state_of(t) == StandScript.STATE_STUMP else "The stump was gone"
	return ""


func _work_wu(row: int, work: int) -> int:
	"""A work step's WU: §5.9's felling and planting, the demo's for the rest."""
	match work:
		JobsScript.WORK_FELL:
			return Rules.FELL_WU
		JobsScript.WORK_GATHER:
			return Rules.deadfall_wu(_deadfall.milli[jobs.target[row]])
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


func _begin_planting(t: int) -> String:
	"""Planting's compost is spent as the work starts (§5.9's cost); refuses a spot no longer clear."""
	if _stand.state_of(t) != StandScript.STATE_CLEARED:
		return "Can't plant: the spot is not clear"
	if not _compost_take.is_valid() or not bool(_compost_take.call(Rules.PLANT_COMPOST_MILLI)):
		return "Can't plant: no compost to plant with (0.25 U needed)"
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
	if jobs.kind[row] == JobsScript.KIND_GATHER:
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


func _drop(row: int) -> void:
	"""The worker was ordered away: the job waits on the board where it had got to."""
	var who: int = jobs.worker[row]
	(_cast.actor(who) as DemoActorScript).clear_work_tool()
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	_say("%s left the %s job" % [name_of(who), JobsScript.KIND_NAMES[jobs.kind[row]].to_lower()])


func finish(row: int, text: String) -> void:
	"""Close job `row` -- putting any load in hand into store, so no wood is lost -- send its worker back
	to its routine, and say how it ended."""
	_deliver_load(row)
	var who: int = jobs.worker[row]
	jobs.close(row)
	if who >= 0 and who < _cast.actor_count():
		var actor := _cast.actor(who) as DemoActorScript
		actor.clear_work_tool()
		if actor.holding():
			actor.drop_held()
		actor.brain.play_in_place(BrainScript.CLIP_IDLE)
		actor.brain.release()
	if not text.is_empty():
		_say(text)


func _deliver_load(row: int) -> void:
	"""A load still in hand goes into store as what it is: planks once sawn, else wood."""
	var milli: int = jobs.load_milli[row]
	if milli <= 0:
		return
	jobs.load_milli[row] = 0
	if jobs.kind[row] == JobsScript.KIND_SAW and jobs.step[row] > SAW_WORK_STEP:
		_stores.add_planks(milli)
	else:
		_stores.add_wood(milli)


# --- routine work -------------------------------------------------------------------------------

func raise_routine_jobs() -> void:
	"""The crew's own work: haul every trunk lying with nobody on it (a storm's blow-down, a felled tree
	left), and fell the next tree in each auto-fell zone that has none on the board."""
	for t: int in _stand.count():
		if _stand.trunk_milli[t] > 0 and jobs.on_target(JobsScript.KIND_HAUL, t) == 0:
			jobs.open_into(JobsScript.KIND_HAUL, t, 0, JobsScript.ORIGIN_ROUTINE, _read)
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
		JobsScript.KIND_GATHER, JobsScript.KIND_SAW:
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
	elif jobs.kind[row] != JobsScript.KIND_SAW and jobs.kind[row] != JobsScript.KIND_GATHER:
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
