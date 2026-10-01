extends RefCounted
## Building the demo's bridges: one builder a bridge, fetching the material and working the stages.
## Decision 0196 (live demo). The walking and carrying go through the cast's brains (order_move,
## order_carry, play_in_place -- the woods' crew's way, demo/forestry/forest_crew.gd); the EFFECT of the
## work is `bridges.add_work`, credited as the demo clock runs.
##
## THE STEPS. To the material -- the plank stack in the wood yard, the log stack, or (a log bridge) the
## felled trunk the log was cut from -- then LOAD there (planks: LOAD_WU; a log is shaped where it lies:
## the first LOG_SHAPE_WU of its "log" stage, gnawed by a beaver), CARRY it on the carry walk to the
## bridge's near end (the one nearer the material; loads cannot swim, so the carrier walks round, wades
## the ford or crosses a bridge), and WORK the stages there -- piers, beams (the log), deck.
##
## WHO. An order given with residents selected goes to the nearest of them; with nobody selected the
## bridge waits to be CLAIMED: in the live demo by the village's work board (demo/work/work_board.gd, decision 0411:
## any idle resident on land, the Builders crew -- the bridgewright's -- first) through `claim`; without one by the
## routine BRIDGEWRIGHT (the beaver, DEC-041) while wandering. Anybeast
## can build (LORE-P12); SKILL changes only how long each WU takes: bridge building is a demo skill
## (like felling; §4.3 names none), §5.3's arithmetic -- 10 XP a WU, the level curve, a work time
## divided by 1000 + 50 x level -- shown in the party panel. The beaver starts at level 6. A storm day
## slows outdoor work to 80% (§5.10). A builder ordered away leaves the bridge where it got to.
##
## ARRIVING IS EXPLICIT (decision 0361, the review's F05). A builder holding is not a builder arrived: one whose walk was
## given up holds too. Each step at the source or the site starts only when the brain's trip ARRIVED and the builder
## stands within ARRIVE_M of its spot (resident_brain.gd `arrived_near`), and loading and building recheck it every
## frame: a builder who could not get there -- or is no longer there -- loads and builds nothing; the bridge waits for
## a builder again, its material where it was, and the feed names who could not get where. The builder is let go (its
## work done: back to a saved job or its routine), and the routine crew does not take that bridge up again for
## UNREACHED_WAIT_USEC.

const Rules := preload("res://demo/waterplay/swim_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")

const NOBODY: int = -1
const STEP_WAITING: int = 0
const STEP_GO_SOURCE: int = 1
const STEP_LOAD: int = 2
const STEP_CARRY: int = 3
const STEP_WORK: int = 4
const STEP_WORDS: Array[String] = ["waiting for a builder", "going for the material", "loading the material",
	"carrying the material to the site", "building"]
const SOURCE_PLANKS: int = 0
const SOURCE_LOG_STACK: int = 1
const SOURCE_TRUNK: int = 2
const SOURCE_WORDS: Array[String] = ["the plank stack", "the log stack", "the felled trunk"]
## Loading planks at the stack (demo, forestry's LOAD_WU).
const LOAD_WU: int = ForestRules.LOAD_WU
const PICKUP_USEC: int = 500000
## A bridge its builder could not get to waits this long before the routine crew takes it up again (demo value).
const UNREACHED_WAIT_USEC: int = 10000000
const ARRIVE_M: float = 0.45
const RING_GAP_M: float = 0.45
const RINGS: int = 4
const RING_SPOTS: int = 12
const SOURCE_STAND_M: float = 1.3
const SITE_STAND_M: float = 0.4
## By a trunk the builder stands on its work point (beside the trunk) or as near it as it can.
const TRUNK_STAND_M: float = 0.0
const CLIP_WORK: StringName = &"collect_object"
const CLIP_HEAVY: StringName = &"pull_radish"
const PLANK_KEY: StringName = &"bridge_plank"
const LOG_KEY: StringName = &"bridge_log"
const GNAWED_KEY: StringName = &"gnawed_log"
const GNAWING_SPECIES: Array[String] = ["beaver"]
## A bridge its builder could not get to, while the routine crew leaves it (see ARRIVING IS EXPLICIT): `job_text`.
const UNREACHED_WAITING: String = "waiting — can't reach it; the crew tries again in %d s"
## How a resident index that names nobody is worded (see `name_of`).
const UNNAMED: String = "nobody"

## Per bridge row: the builder (actor index), the step, whether it was issued, where it walks to, work
## done in this step (demo usec), the material's source and point.
var builder: PackedInt32Array = PackedInt32Array()
var step: PackedByteArray = PackedByteArray()
var issued: PackedByteArray = PackedByteArray()
var goal: PackedVector2Array = PackedVector2Array()
var elapsed_usec: PackedInt64Array = PackedInt64Array()
var source: PackedByteArray = PackedByteArray()
var source_at: PackedVector2Array = PackedVector2Array()
## Whether the material has been carried to the site.
var at_site: PackedByteArray = PackedByteArray()
## How long a bridge its builder could not get to still waits before the routine crew takes it up (see ARRIVING IS
## EXPLICIT; demo usec).
var unreached_usec: PackedInt64Array = PackedInt64Array()
## Bridge-building XP per resident (actor index).
var xp: PackedInt64Array = PackedInt64Array()
var revision: int = 0

var _cast: DemoCastScript = null
var _bridges: BridgesScript = null
var _weather: WeatherScript = null
var _props: PropsScript = null
var _say: Callable = Callable()
var _crew: PackedInt32Array = PackedInt32Array()
var _pickup_usec: int = 0
var _found: Vector2 = Vector2.ZERO
var _pick: IntMath.IntResult = IntMath.IntResult.new()
## `builder_for`'s own answer (never `_pick`, which `start` reads).
var _probe: IntMath.IntResult = IntMath.IntResult.new()
var _no_taken: PackedVector2Array = PackedVector2Array()
## Per bridge row: the generation of the bridge the player paused there (-1: none).
var _paused_gen: PackedInt32Array = PackedInt32Array()
## The work board claims the waiting bridges (decision 0411): the routine bridgewright's own hand-out stands down.
var _claimed_outside: bool = false


func configure(cast: DemoCastScript, bridges: BridgesScript, weather: WeatherScript, props: PropsScript,
		say: Callable) -> void:
	"""Build `bridges` with this cast, on this weather, carrying these props; `say(text)` reports."""
	_cast = cast
	_bridges = bridges
	_weather = weather
	_props = props
	_say = say
	builder.resize(BridgesScript.MAX_BRIDGES)
	builder.fill(NOBODY)
	at_site.resize(BridgesScript.MAX_BRIDGES)
	unreached_usec.resize(BridgesScript.MAX_BRIDGES)
	step.resize(BridgesScript.MAX_BRIDGES)
	issued.resize(BridgesScript.MAX_BRIDGES)
	goal.resize(BridgesScript.MAX_BRIDGES)
	elapsed_usec.resize(BridgesScript.MAX_BRIDGES)
	source.resize(BridgesScript.MAX_BRIDGES)
	source_at.resize(BridgesScript.MAX_BRIDGES)
	_paused_gen.resize(BridgesScript.MAX_BRIDGES)
	_paused_gen.fill(-1)
	xp.resize(cast.actor_count())
	_crew.clear()
	for who: int in cast.actor_count():
		var actor := cast.actor(who) as DemoActorScript
		if actor.creature_key == Rules.BRIDGEWRIGHT_KEY:
			xp[who] = Rules.BRIDGEWRIGHT_XP
			_crew.append(who)


func set_crew(members: PackedInt32Array) -> void:
	"""Replace the routine crew (a placeholder cast has no bridgewright)."""
	_crew = members.duplicate()


func crew() -> PackedInt32Array:
	"""The routine crew's actor indices."""
	return _crew


func start(row: int, from_source: int, at: Vector2, members: PackedInt32Array) -> String:
	"""A planned (paid) bridge `row` is to be built from material at `at` (SOURCE_*): the nearest of
	`members` takes it, or it waits for the routine crew. Says what happened."""
	source[row] = from_source
	source_at[row] = at
	at_site[row] = 0
	step[row] = STEP_WAITING
	builder[row] = NOBODY
	revision += 1
	if not _nearest_into(members, at, _pick):
		return "%s planned: waiting for the bridgewright" % _title(row)
	var who: int = _pick.value
	_assign(row, who)
	return "%s: %s goes for %s" % [_title(row), name_of(who), SOURCE_WORDS[from_source]]


func _nearest_into(members: PackedInt32Array, to: Vector2, out: IntMath.IntResult) -> bool:
	"""The member standing nearest `to` who is on land and free of the water's rescue, into `out`;
	refuses when none is."""
	var best_d: float = INF
	for who: int in members:
		var brain: BrainScript = brain_of(who)
		if brain.water_hold or brain.in_water:
			continue
		if brain.surface_point().distance_to(to) < best_d:
			best_d = brain.surface_point().distance_to(to)
			out.value = who
	if best_d == INF:
		return out.refuse("NO_FREE_BUILDER")
	return out.succeed(out.value)


func builder_for(members: PackedInt32Array, at: Vector2) -> int:
	"""Who `start` gives a bridge with its material at `at` to: the nearest of `members` on land and free of the
	rescue (-1: it waits for the bridgewright) -- `start`'s own choice, for an action card (decision 0332)."""
	return _probe.value if _nearest_into(members, at, _probe) else NOBODY


func able_count(members: PackedInt32Array) -> int:
	"""How many of `members` could take a bridge now (on land, free of the rescue)."""
	var n: int = 0
	for who: int in members:
		n += 0 if brain_of(who).water_hold or brain_of(who).in_water else 1
	return n


func build_usec(kind: int, deck_u: int, piers: int, who: int) -> int:
	"""The building work of a bridge for resident `who` (-1: base skill), in demo microseconds: every stage's WU
	(swim_rules.gd `stage_wu`; a log's shaping is its beams' first WU) and a plank load's LOAD_WU, each at `who`'s
	`_usec_per_wu` -- the rate the work is credited at."""
	var wu: int = LOAD_WU if kind == Rules.KIND_PLANK else 0
	for stage: int in Rules.STAGE_COUNT:
		wu += Rules.stage_wu(kind, stage, deck_u, piers)
	return wu * _usec_per_wu(level_of(who) if who >= 0 else 0)


func resume_rule(who: int) -> int:
	"""demo_command.gd `add_resume_rule`: a builder ordered away leaves its bridge waiting for a builder (`_drop`
	does not keep it on the resident's resume list)."""
	return InterruptScript.DROPS_BRIDGE if builder.has(who) else InterruptScript.NOT_MINE


func _assign(row: int, who: int) -> void:
	"""`who` takes bridge `row`, from its first step (or the site, when the material is already there)."""
	builder[row] = who
	step[row] = STEP_GO_SOURCE if _needs_material(row) else STEP_WORK
	issued[row] = 0
	elapsed_usec[row] = 0
	revision += 1


func _needs_material(row: int) -> bool:
	"""Whether the material still has to be fetched to the site."""
	return at_site[row] == 0


func update(usec: int) -> void:
	"""Advance every assigned bridge by `usec` demo microseconds; hand waiting ones to the idle crew."""
	if usec <= 0:
		return
	_pickup_usec += usec
	for row: int in BridgesScript.MAX_BRIDGES:
		unreached_usec[row] = maxi(unreached_usec[row] - usec, 0)
	if _pickup_usec >= PICKUP_USEC:
		_pickup_usec = 0
		if not _claimed_outside:
			_hand_out()
	for row: int in BridgesScript.MAX_BRIDGES:
		if _bridges.is_planned(row) and builder[row] != NOBODY:
			_step_row(row, usec)


func _hand_out() -> void:
	"""Give each waiting bridge to the nearest crew member wandering on its own (no work board)."""
	for row: int in BridgesScript.MAX_BRIDGES:
		if not waiting(row):
			continue
		var idle := PackedInt32Array()
		for who: int in _crew:
			if brain_of(who).order == BrainScript.ORDER_NONE and not brain_of(who).underground and not brain_of(who).resting \
					and not _busy(who):
				idle.append(who)
		if _nearest_into(idle, source_at[row], _pick):
			_assign(row, _pick.value)
			_note("%s takes up the %s" % [name_of(_pick.value), _bridges.names[row]])


func _busy(who: int) -> bool:
	"""Whether `who` builds another bridge already."""
	return builder.has(who)


# --- the work board's hands (decision 0411) ---------------------------------------------------------

func set_claimer() -> void:
	"""The village's work board claims the waiting bridges from now on (the routine bridgewright's hand-out stands
	down)."""
	_claimed_outside = true


func claims_outside() -> bool:
	"""Whether the work board claims the waiting bridges."""
	return _claimed_outside


func waiting(row: int) -> bool:
	"""Whether bridge `row` is planned and waits for a builder now (not paused, not left after a failed walk)."""
	return _bridges.is_planned(row) and builder[row] == NOBODY and unreached_usec[row] <= 0 and not is_paused(row)


func can_build(who: int) -> bool:
	"""Whether `who` could take a bridge now: on land, free of the water's rescue, building no other bridge."""
	var brain: BrainScript = brain_of(who)
	return not brain.water_hold and not brain.in_water and not _busy(who)


func claim(row: int, who: int) -> bool:
	"""The work board hands waiting bridge `row` to resident `who`, who sets off at once."""
	if not waiting(row) or who < 0 or who >= _cast.actor_count() or not can_build(who):
		return false
	_assign(row, who)
	_step_row(row, 0)
	_note("%s takes up the %s" % [name_of(who), _bridges.names[row]])
	return true


func is_paused(row: int) -> bool:
	"""Whether the player paused bridge `row`."""
	return _bridges.is_planned(row) and _paused_gen[row] == _bridges.generation[row]


func pause(row: int, on: bool) -> String:
	"""The player pauses bridge `row` (its builder let go, a load back at its source, the work done kept) or resumes
	it. "" when done, else why not."""
	if not _bridges.is_planned(row):
		return WorkIds.NOT_FOUND
	if not on:
		_paused_gen[row] = -1
		return ""
	if is_paused(row):
		return WorkIds.PAUSED_ALREADY
	_paused_gen[row] = _bridges.generation[row]
	_let_go_of(row)
	return ""


func reassign(row: int, who: int) -> String:
	"""The player gives bridge `row` to resident `who` instead (taken off whatever it was doing); the builder on it is
	let go, a load it carried put back at its source. "" when done, else why not."""
	if not _bridges.is_planned(row):
		return WorkIds.NOT_FOUND
	if who < 0 or who >= _cast.actor_count():
		return "nobody to give it to"
	if builder[row] == who:
		return ""
	if brain_of(who).water_hold or brain_of(who).in_water:
		return "in the water"
	if _busy(who):
		return "builds another bridge"
	_let_go_of(row)
	_paused_gen[row] = -1
	unreached_usec[row] = 0
	_assign(row, who)
	_step_row(row, 0)
	return ""


func remaining_usec(row: int) -> int:
	"""The building work left on bridge `row` at its builder's skill (base skill with nobody on it): every stage's WU
	still to do, and a plank load's LOAD_WU while the material is not at the site -- `build_usec`'s arithmetic."""
	var wu: int = LOAD_WU if _bridges.kind[row] == Rules.KIND_PLANK and at_site[row] == 0 else 0
	for stage: int in Rules.STAGE_COUNT:
		wu += _bridges.stage_left_wu(row, stage)
	return wu * _usec_per_wu(level_of(builder[row]) if builder[row] != NOBODY else 0)


func _let_go_of(row: int) -> void:
	"""Bridge `row`'s builder, if any, is let go (back to its order list or routine); the bridge waits where it got to."""
	var who: int = builder[row]
	if who == NOBODY:
		return
	_drop(row, false)
	var brain: BrainScript = brain_of(who)
	brain.play_in_place(BrainScript.CLIP_IDLE)
	brain.work_done()

func _step_row(row: int, usec: int) -> void:
	"""One frame of bridge `row`'s current step."""
	var brain: BrainScript = brain_of(builder[row])
	if issued[row] == 1 and (brain.order != BrainScript.ORDER_MOVE or brain.goal() != goal[row]):
		_drop(row)
		return
	if issued[row] == 0:
		_issue(row, brain)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if not brain.arrived_near(goal[row], ARRIVE_M):
		_unreached(row, step[row] == STEP_GO_SOURCE or step[row] == STEP_LOAD)
		return
	match step[row]:
		STEP_GO_SOURCE:
			step[row] = STEP_LOAD
			elapsed_usec[row] = 0
			brain.play_in_place(_load_clip(row))
		STEP_LOAD:
			_step_load(row, brain, usec)
		STEP_CARRY:
			_arrive_site(row, brain)
		STEP_WORK:
			_step_work(row, brain, usec)


func _issue(row: int, brain: BrainScript) -> void:
	"""Send the builder to its step's spot (on the carry walk with the material)."""
	var target: Vector2 = source_at[row] if step[row] == STEP_GO_SOURCE or step[row] == STEP_LOAD else site_point(row)
	var first: float = SITE_STAND_M
	if target == source_at[row]:
		first = TRUNK_STAND_M if source[row] == SOURCE_TRUNK else SOURCE_STAND_M
	if not _spot_near(target, first, brain):
		_unreached(row, target == source_at[row])
		return
	goal[row] = _found
	issued[row] = 1
	if step[row] == STEP_CARRY:
		var actor := _cast.actor(builder[row]) as DemoActorScript
		var key: StringName = carry_key(row)
		actor.hold(_props.mesh_of(key), _hand_fit(key))
		brain.order_carry(_found, _face_point(row))
	elif step[row] == STEP_WORK:
		brain.order_move(_found, _face_point(row))
	else:
		brain.order_move(_found, target)


func _step_load(row: int, brain: BrainScript, usec: int) -> void:
	"""Load the planks, or shape the log where it lies (crediting the log's first WU), then carry."""
	brain.play_in_place(_load_clip(row))
	elapsed_usec[row] += usec
	var level: int = level_of(builder[row])
	if _bridges.kind[row] == Rules.KIND_LOG:
		_credit(row, _whole_wu(row, level), Rules.LOG_SHAPE_WU)
		if _bridges.stage_done_wu[row * Rules.STAGE_COUNT + Rules.STAGE_BEAMS] < Rules.LOG_SHAPE_WU:
			return
	elif elapsed_usec[row] < _usec_per_wu(level) * LOAD_WU:
		return
	step[row] = STEP_CARRY
	issued[row] = 0
	elapsed_usec[row] = 0


func _arrive_site(row: int, brain: BrainScript) -> void:
	"""At the site with the material: put it down and start work."""
	var actor := _cast.actor(builder[row]) as DemoActorScript
	if actor.holding():
		actor.drop_held()
	at_site[row] = 1
	step[row] = STEP_WORK
	issued[row] = 1
	elapsed_usec[row] = 0
	goal[row] = brain.goal()
	brain.play_in_place(stage_clip(_bridges.stage_of(row)))


func _step_work(row: int, brain: BrainScript, usec: int) -> void:
	"""Work the stages at the site; the bridge opens with the deck's last WU."""
	brain.play_in_place(stage_clip(_bridges.stage_of(row)))
	elapsed_usec[row] += usec
	_credit(row, _whole_wu(row, level_of(builder[row])), 1 << 30)
	if _bridges.is_open(row):
		_finish(row)


func _whole_wu(row: int, level: int) -> int:
	"""Whole WU in the step's elapsed time at `level` (the remainder is kept)."""
	var per: int = _usec_per_wu(level)
	var wu: int = elapsed_usec[row] / per
	elapsed_usec[row] -= wu * per
	return wu


func _credit(row: int, wu: int, cap_stage_wu: int) -> void:
	"""Credit `wu` to the bridge (for a log's shaping, no further than `cap_stage_wu` of its stage) and
	the builder's XP (§5.3: 10 a WU)."""
	if wu <= 0:
		return
	var k: int = row * Rules.STAGE_COUNT + Rules.STAGE_BEAMS
	if cap_stage_wu < (1 << 30):
		wu = mini(wu, maxi(cap_stage_wu - _bridges.stage_done_wu[k], 0))
	var credited: int = _bridges.add_work(row, wu)
	if credited > 0:
		xp[builder[row]] += credited * ForestRules.XP_PER_WU
		revision += 1


func _usec_per_wu(level: int) -> int:
	"""Demo microseconds one WU takes at `level`, slowed on a storm day (§5.10)."""
	var event: int = _weather.event() if _weather != null else -1
	return Rules.work_usec(1, level) * Rules.PERMILLE / ForestRules.weather_permille(event)


func _finish(row: int) -> void:
	"""The bridge is open: the builder goes back to its routine."""
	var who: int = builder[row]
	builder[row] = NOBODY
	revision += 1
	var brain: BrainScript = brain_of(who)
	brain.play_in_place(BrainScript.CLIP_IDLE)
	brain.work_done()
	_note("The %s is open: %s built it; anyone may cross it now, carrying or not" % [_bridges.names[row], name_of(who)])


func _unreached(row: int, to_source: bool) -> void:
	"""The builder could not get to the material (`to_source`) or the site, or is no longer there: nothing is loaded or
	built from afar; the bridge waits for a builder again, and the feed names who could not get where (the name read
	before the row lets the builder go -- the review's F15)."""
	var who: int = builder[row]
	_drop(row, false)
	unreached_usec[row] = UNREACHED_WAIT_USEC
	_note("%s: %s can't get to %s" % [_title(row), name_of(who), "the material" if to_source else "the site"])
	var brain: BrainScript = brain_of(who)
	if brain.order == BrainScript.ORDER_MOVE:
		brain.work_done()


func _drop(row: int, say_left: bool = true) -> void:
	"""The builder was ordered away: the bridge waits where it got to (a load goes back to its source)."""
	var who: int = builder[row]
	var actor := _cast.actor(who) as DemoActorScript
	if actor.holding():
		actor.drop_held()
	builder[row] = NOBODY
	step[row] = STEP_WAITING
	issued[row] = 0
	revision += 1
	if say_left:
		_note("%s left the %s" % [name_of(who), _bridges.names[row]])


# --- places, looks and words ---------------------------------------------------------------------

func site_far(row: int) -> bool:
	"""Whether bridge `row` is built from its end b: the end nearer its material."""
	return _bridges.approach(row, true).distance_to(source_at[row]) < _bridges.approach(row, false).distance_to(source_at[row])


func site_point(row: int) -> Vector2:
	"""Where the builder works: the near end's approach."""
	return _bridges.approach(row, site_far(row))


func _face_point(row: int) -> Vector2:
	"""What the builder faces at the site: the near footing."""
	return _bridges.deck_end(row, site_far(row))


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript) -> bool:
	"""The standable, reachable spot nearest the builder on rings round `target` into `_found` (the
	woods' crew's search, bounded by the cast's walkable area)."""
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(_cast.space(), members)
	var from: Vector2 = brain.surface_point()
	for ring: int in RINGS:
		var radius: float = first_ring + RING_GAP_M * ring
		var found: bool = false
		for k: int in RING_SPOTS:
			var spot: Vector2 = target + Vector2.from_angle(TAU * k / RING_SPOTS) * radius
			if found and spot.distance_squared_to(from) >= _found.distance_squared_to(from):
				continue
			if CastOrdersScript.spot_ok(_cast.space(), spot, brain.radius, _cast.bounds(), avoid, _no_taken, from):
				_found = spot
				found = true
		if found:
			return true
	return false


func gnaws(who: int) -> bool:
	"""Whether `who` shapes a log by gnawing (DEC-041's beaver: the same work, its own look)."""
	return GNAWING_SPECIES.has((_cast.actor(who) as DemoActorScript).species.to_lower())


func carry_key(row: int) -> StringName:
	"""The model carried to the site: planks, or the log (gnawed, by a beaver)."""
	if _bridges.kind[row] == Rules.KIND_PLANK:
		return PLANK_KEY
	return GNAWED_KEY if builder[row] != NOBODY and gnaws(builder[row]) else LOG_KEY


func _hand_fit(key: StringName) -> Transform3D:
	"""A carried model centred between the hands (demo_actor.gd `hold`)."""
	var bound: AABB = _props.drawn_bound(key)
	return Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key)


func _load_clip(row: int) -> StringName:
	"""Loading planks is gathering them up; a log is worked where it lies (gnawed, by a beaver)."""
	return CLIP_HEAVY if _bridges.kind[row] == Rules.KIND_LOG else CLIP_WORK


static func stage_clip(stage: int) -> StringName:
	"""The clip a stage is worked with: beams (and a log) are hauled into place."""
	return CLIP_HEAVY if stage == Rules.STAGE_BEAMS else CLIP_WORK


func level_of(who: int) -> int:
	"""A resident's bridge-building level (§5.3's curve)."""
	return ForestRules.level_of(xp[who]) if who >= 0 and who < xp.size() else 0


func line_of(who: int) -> String:
	"""The party panel's line: "Bridging 6 · XP 180000/245000"."""
	var level: int = level_of(who)
	if level >= ForestRules.SKILL_LEVEL_MAX:
		return "Bridging %d" % level
	return "Bridging %d · XP %d/%d" % [level, xp[who], ForestRules.xp_of_level(level + 1)]


func short_of(who: int) -> String:
	"""The multi-selection form: "bridge 6"."""
	return "bridge %d" % level_of(who)


func job_text(row: int) -> String:
	"""Bridge `row`'s job in words, for the Water panel."""
	if builder[row] == NOBODY:
		if unreached_usec[row] > 0:
			return UNREACHED_WAITING % ceili(float(unreached_usec[row]) / 1000000.0)
		return STEP_WORDS[STEP_WAITING]
	return "%s — %s" % [name_of(builder[row]), STEP_WORDS[step[row]]]


func task_text(who: int) -> String:
	"""What `who` is doing for a bridge ("" for nothing), for the party panel."""
	for row: int in BridgesScript.MAX_BRIDGES:
		if builder[row] == who and _bridges.is_planned(row):
			var stage: int = _bridges.stage_of(row)
			var what: String = STEP_WORDS[step[row]]
			if step[row] == STEP_WORK and stage < Rules.STAGE_COUNT:
				what = "building the %s's %s (%d%%)" % [_bridges.names[row], _stage_word(row, stage), _bridges.percent(row)]
			return what
	return ""


func _stage_word(row: int, stage: int) -> String:
	"""A stage's name for this kind of bridge."""
	return (Rules.LOG_STAGE_NAMES if _bridges.kind[row] == Rules.KIND_LOG else Rules.STAGE_NAMES)[stage]


func _title(row: int) -> String:
	"""Bridge `row`'s name with a capital, to begin a line."""
	var name: String = _bridges.names[row]
	return name.left(1).to_upper() + name.substr(1)


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain (`who` a resident of the cast: DemoCast.actor refuses any other index)."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name; an index that names nobody is refused (an error) and named as nobody -- NOBODY must never
	be read as the cast's last (the review's F15)."""
	if who < 0 or who >= _cast.actor_count():
		push_error("bridge crew: no resident %d to name" % who)
		return UNNAMED
	return (_cast.actor(who) as DemoActorScript).display_name


func _note(text: String) -> void:
	"""Report to the feed."""
	if _say.is_valid():
		_say.call(text)
