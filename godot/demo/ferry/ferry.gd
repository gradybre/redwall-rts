extends "res://demo/boats/boat_service.gd"
## THE FERRY: one fixed two-landing cargo ferry from the ferry stage on the run to the far stage at the stream's mouth,
## with a staffed timetable, a departure threshold and weather closure; cargo first -- the far copse's windfall wood --
## and a passenger seat the router may choose. Decision 0437 (review ECO-041; water part B lane 3; Brendan's approval of
## ferries, recorded in decision 0439). Numbers in ferry_rules.gd. Presentation over integer rules; nothing here writes
## into the settlement simulation.
##
## THE BOAT. The ferry boat is the boat core's third row (boat_routes.gd FERRY_BOAT, its berth off the ferry stage and its
## fixed route to the far stage). A crossing TAKES it at boarding (`fleet.take` under the crossing's serial) and GIVES IT
## BACK once moored at the ferry stage again (`give_back`): between crossings it is free, so the boat rescue may take it
## (boat_rescue.gd; decision 0432's note), and a crossing due while a rescue has it waits for it. No free sailing: the
## course is always the fixed route, out and back the same way.
##
## A CROSSING is a round trip (one at a time): posted for the scheduled departure when anything waits to be carried, or
## at once when the far stack reaches the threshold; a crew job on the work board (the helm, FISH >= 1 -- the boat
## core's helm rule, never a species: LORE-P12). The crew walks to the stage the boat lies at, rechecks (closed: it stands
## down and the crossing waits, said once), boards, LOADS what that stage holds for the far side (the far stack, up to
## BOAT_CARGO_MILLI) while passengers board, rows, UNLOADS onto the other stage's stack while passengers step off, and
## back the same way; at the ferry stage it steps off and gives the boat back. Closed at the far stage it does not load:
## the crew steps ashore there and the crossing HOLDS, the boat still the crossing's, until the ferry opens again and a
## crew (anyone eligible) walks round to bring it back.
##
## THE BOOKS (conservation, milli-U of wood): everything that ever fell in the far copse is lying there, in a hand (or
## set down for the next to fetch), on a stage's stack, aboard, or in the stores --
##   fallen == lying + in_hand + far_stack + aboard + near_stack + stored        (`books_balance`)
## at every moment, through cancel, closure mid-crossing and interruption. A load moves between two of them in one
## step, never through a third, and never both ways.
##
## WHO. Every job is a work-board task (work/ferry_work.gd, decision 0411): gathering a pile (the Woods crew's), hauling
## the ferry stage's stack to the log stack, and crewing a crossing (hauling work). Any resident may gather or haul; a
## crew needs a helm. A resident doing a job is driven by a thin task (ferry_task.gd), so the night, a meal call or an
## order takes it off cleanly -- except on a stage's deck or afloat (`water_hold`, MOVE-REQ-007).
##
## PASSENGERS (the router's crossing row: boat row 0, water_crossings.gd FERRY_ROW; decision 1821). The ferry is a boat
## row's service (boat_service.gd): for each trip over the water it lists, at each stage, its next boardings with the
## seat free (`fill_boat_row`: the one in sight now, then the timetable's) and its ride (both decks and the row), all in
## integer ticks, nothing while closed or unstaffed; the router prices the wait from when the walker REACHES the stage,
## at most MAX_WAIT_TICKS (it was priced from now, before 1821). A passenger walks to the stage's land end, waits, boards
## the second seat when the boat loads there, rides, and steps off at the other stage. Any refusal ends the leg where it
## stands -- closed, the wait too long, the seat taken, an order given meanwhile -- and it plans again by land.

const Rules := preload("res://demo/ferry/ferry_rules.gd")
const TaskScript := preload("res://demo/ferry/ferry_task.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const SkillsScript := preload("res://demo/fishery/fish_skills.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const BoatRows := preload("res://demo/routes/boat_rows.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

const NONE: int = -1
const MAX_JOBS: int = 12
## Said when every job row is live and a crossing cannot be posted (ARCH-AUTH-003: refused, never overwritten).
const JOBS_FULL_WORDS: String = "the ferry's job list is full — a crossing waits for a free row"
## Crew steps (each a cast simulation step, several to a frame) a crew loading at a stage holds for a passenger waiting
## there to start boarding: a passenger's leg is stepped by its own brain, so it may not see the boat loading until a
## step after the crew does (with nothing to load, the crew would otherwise push off the step it sat down, leaving the
## waiting passenger on the stage -- seen live).
const BOARD_GRACE_STEPS: int = 30
## The slowest walk a crew's walk to the stage is reckoned at (mm a second; the old 0.1 m/s floor).
const MIN_WALK_MM_S: int = 100
## The two stages: the ferry stage on the village side (the boat's home) and the far stage.
const NEAR: int = 0
const FAR: int = 1
const STAGE_JETTY: Array[int] = [1, 2]
## Job kinds.
const KIND_GATHER: int = 0
const KIND_HAUL: int = 1
const KIND_CREW: int = 2
const KIND_WORDS: Array[String] = ["Gather windfall", "Haul wood", "Ferry crossing"]
## Steps: a gatherer's, a hauler's, a crew's (walks are WALK_STEPS).
const S_TO_PILE: int = 0
const S_GATHER: int = 1
const S_TO_FAR_STACK: int = 2
const S_TO_NEAR_STACK: int = 3
const S_PICK: int = 4
const S_TO_LOG_STACK: int = 5
const S_TO_STAGE: int = 6
const S_BOARD: int = 7
const S_LOAD: int = 8
const S_ROW: int = 9
const S_UNLOAD: int = 10
const S_ALIGHT: int = 11
const S_DONE: int = 12
const WALK_STEPS: Array[int] = [S_TO_PILE, S_TO_FAR_STACK, S_TO_NEAR_STACK, S_TO_LOG_STACK, S_TO_STAGE]
const WORK_STEPS: Array[int] = [S_GATHER, S_PICK, S_LOAD, S_UNLOAD]
const DECK_STEPS: Array[int] = [S_BOARD, S_LOAD, S_ROW, S_UNLOAD, S_ALIGHT]
## The crossing's state.
const X_NONE: int = 0
const X_WAITING: int = 1
const X_LOADING: int = 2
const X_ROWING: int = 3
const X_UNLOADING: int = 4
const X_HELD: int = 5
const X_HOMING: int = 6
const X_WORDS: Array[String] = ["", "waiting for its crew", "loading", "rowing", "unloading", "holding at the far stage",
	"coming ashore"]
## A passenger's state.
const P_NONE: int = 0
const P_WAITING: int = 1
const P_BOARDING: int = 2
const P_ABOARD: int = 3
const P_ALIGHTING: int = 4
## Boarded at a stage the ferry then closed at before pushing off: back up that stage's deck, its leg ended there.
const P_RETURNING: int = 5
## A worker counts as at its place within this (m; the fishery's ARRIVE_M).
const ARRIVE_M: float = 0.45
## A crew's or a passenger's seat sits this far below the deck (the fishery's afloat placement).
const SEAT_DROP_M: float = 0.1
## Places are snapped for the widest resident (the fishery's SPOT_BODY_M), on rings this far apart.
const SPOT_BODY_M: float = 0.56
const SPOT_RING_M: float = 0.3
const SPOT_RINGS: int = 12
const CLIP_WORK: StringName = &"collect_object"
const CLIP_ROW: StringName = &"pull_radish"
const CLIP_WAIT: StringName = &"idle"
## The model a carrier holds (the woods' stock log).
const LOG_KEY: StringName = &"bridge_log"

## The village's parts.
var fleet: FleetScript = null
var skills: SkillsScript = null
var ice: IceScript = null
var stores: StoresScript = null
var calendar: CalendarScript = null
var weather: DemoWeatherScript = null
var map: WaterMapScript = null
## `() -> bool`: whether the tunnels' flood is on the stream (none: never).
var flooded: Callable = Callable()
## `say(text, warning)`: the notice feed (the Water source).
var say: Callable = Callable()
## Bumped whenever anything a panel shows changes.
var revision: int = 0

## THE BOOKS (milli-U of wood).
var fallen_milli: int = 0
var far_stack_milli: int = 0
var aboard_milli: int = 0
var near_stack_milli: int = 0
var stored_milli: int = 0
## Tallies: crossings completed, wood landed at the ferry stage, passengers carried.
var crossings_done: int = 0
var ferried_milli: int = 0
var passengers_carried: int = 0

## The far copse: each spot's pile (0: none) and where the spots stand.
var copse_milli: PackedInt64Array = PackedInt64Array()
var copse_at: PackedVector2Array = PackedVector2Array()

## The crossing (one at a time): its serial (0: none), state, the stage the boat lies at or rows to, its crew job, why
## it waits, and why it was posted; the next scheduled departure. (A crew job's `j_pile` holds the load it is putting
## aboard while it loads: `j_load` is wood in a hand, which the books count.)
var x_serial: int = 0
var x_state: int = X_NONE
var x_stage: int = NEAR
var x_job: int = NONE
## The board's words while no helm lives in the village (built once: never formatted per frame).
var _unstaffed_words: String = "unstaffed: nobody in the village can take the helm (fishing %d)" % FisheryRules.HELM_MIN_LEVEL
var x_words: String = ""
var x_why: String = ""
var next_departure: int = 0

## The job rows (structure of arrays).
var j_live: PackedByteArray = PackedByteArray()
var j_serial: PackedInt32Array = PackedInt32Array()
var j_kind: PackedInt32Array = PackedInt32Array()
var j_step: PackedInt32Array = PackedInt32Array()
var j_worker: PackedInt32Array = PackedInt32Array()
var j_pile: PackedInt32Array = PackedInt32Array()
var j_load: PackedInt64Array = PackedInt64Array()
var j_load_at: PackedVector2Array = PackedVector2Array()
var j_goal: PackedVector2Array = PackedVector2Array()
var j_issued: PackedByteArray = PackedByteArray()
var j_at: PackedByteArray = PackedByteArray()
var j_num: PackedInt64Array = PackedInt64Array()
var j_mwu: PackedInt64Array = PackedInt64Array()
var j_need: PackedInt64Array = PackedInt64Array()
var j_wait_usec: PackedInt64Array = PackedInt64Array()
var j_tries: PackedInt32Array = PackedInt32Array()
## The last resident who could not reach the job's place: not handed the same job again (another may get there).
var j_failed: PackedInt32Array = PackedInt32Array()
var j_sub: PackedInt32Array = PackedInt32Array()
var j_paused: PackedByteArray = PackedByteArray()
var j_words: PackedStringArray = PackedStringArray()

## Each resident as a passenger: its state, the stage it boards at, the goal and path it set out with, and its deck
## sub-step.
var p_state: PackedInt32Array = PackedInt32Array()
var p_from: PackedInt32Array = PackedInt32Array()
var p_goal: PackedVector2Array = PackedVector2Array()
var p_path: PackedInt32Array = PackedInt32Array()
var p_sub: PackedInt32Array = PackedInt32Array()

var _cast: DemoCastScript = null
var _tasks: Array = []
var _next_serial: int = 1
var _driving: int = NONE
var _hour_seen: int = -1
var _stage_land: PackedVector2Array = PackedVector2Array()
var _stack_at: PackedVector2Array = PackedVector2Array()
var _wait_at: PackedVector2Array = PackedVector2Array()
var _log_drop: Vector2 = Vector2.ZERO
var _closed_said: int = Rules.OPEN
## The row's and the ride's calendar ticks, worked out on first use (-1: not yet; the route and stages are fixed).
var _row_t: int = -1
var _ride_t: int = -1


func configure(p_cast: DemoCastScript, p_fleet: FleetScript, p_skills: SkillsScript, p_ice: IceScript,
		p_stores: StoresScript, p_calendar: CalendarScript, p_weather: DemoWeatherScript, water_map: WaterMapScript) -> void:
	"""Wire the ferry into the village: its cast, the boat core's fleet, the fishery's FISH skills (the helm) and the
	pond's ice, the stores, the calendar, the weather and the water map. The far copse opens with its first piles."""
	_cast = p_cast
	fleet = p_fleet
	skills = p_skills
	ice = p_ice
	stores = p_stores
	calendar = p_calendar
	weather = p_weather
	map = water_map
	_size_rows(p_cast.actor_count() if p_cast != null else 0)
	_find_places()
	for k: int in Rules.COPSE_OPENING.size():
		_fall(k, Rules.COPSE_OPENING[k])
	_hour_seen = calendar.hour_index() if calendar != null else 0
	next_departure = Rules.departure_tick_at_or_after(now_tick())


func _size_rows(residents: int) -> void:
	"""Every column sized once."""
	for column: PackedInt32Array in [j_serial, j_kind, j_step, j_worker, j_pile, j_tries, j_sub, j_failed]:
		column.resize(MAX_JOBS)
	for column: PackedInt64Array in [j_load, j_num, j_mwu, j_need, j_wait_usec]:
		column.resize(MAX_JOBS)
	for column: PackedByteArray in [j_live, j_issued, j_at, j_paused]:
		column.resize(MAX_JOBS)
	j_load_at.resize(MAX_JOBS)
	j_goal.resize(MAX_JOBS)
	j_words.resize(MAX_JOBS)
	j_worker.fill(NONE)
	_tasks.resize(MAX_JOBS)
	for column: PackedInt32Array in [p_state, p_from, p_path, p_sub]:
		column.resize(residents)
	p_goal.resize(residents)
	copse_milli.resize(Rules.COPSE_SPOTS.size())


func _find_places() -> void:
	"""Each fixed place snapped to standable ground the village reaches: the stages' land ends, the stacks, the waits,
	the copse's spots, and the woods' log stack (the stores' drop)."""
	_stage_land = PackedVector2Array([_standable(Routes.jetty_land_m(STAGE_JETTY[NEAR])),
		_standable(Routes.jetty_land_m(STAGE_JETTY[FAR]))])
	_stack_at = PackedVector2Array([_standable(Rules.NEAR_STACK_AT), _standable(Rules.FAR_STACK_AT)])
	_wait_at = PackedVector2Array([_standable(Rules.NEAR_WAIT_AT), _standable(Rules.FAR_WAIT_AT)])
	copse_at.clear()
	for spot: Vector2 in Rules.COPSE_SPOTS:
		copse_at.append(_standable(spot, copse_at))
	_log_drop = _standable(Yard.log_stack_at() + Vector2(0.0, 1.4))


func _standable(target: Vector2, taken: PackedVector2Array = PackedVector2Array()) -> Vector2:
	"""The spot nearest `target` on rings round it that the widest resident may stand at and reaches from where the first
	resident stands (the fishery's rule; the target itself without a cast)."""
	if _cast == null or _cast.actor_count() == 0:
		return target
	var space: CastSpaceScript = _cast.space()
	var from: Vector2 = brain_of(0).surface_point()
	var none := PackedVector3Array()
	for ring: int in SPOT_RINGS:
		for k: int in (1 if ring == 0 else 12):
			var at: Vector2 = target + Vector2.from_angle(TAU * k / 12.0) * SPOT_RING_M * ring
			if CastOrdersScript.spot_ok(space, at, SPOT_BODY_M, _cast.bounds(), none, taken, from):
				return at
	return target


func stage_land(stage: int) -> Vector2:
	"""Where a stage is walked to (its land end, snapped), metres."""
	return _stage_land[stage] if _stage_land.size() > stage else Routes.jetty_land_m(STAGE_JETTY[stage])


func stack_at(stage: int) -> Vector2:
	"""Where a stage's stack lies, metres."""
	return _stack_at[stage] if _stack_at.size() > stage else (Rules.NEAR_STACK_AT if stage == NEAR else Rules.FAR_STACK_AT)


func wait_at(stage: int) -> Vector2:
	"""Where a passenger waits by a stage, metres."""
	return _wait_at[stage] if _wait_at.size() > stage else stage_land(stage)


func log_drop() -> Vector2:
	"""Where a hauler puts the wood down: the woods' log stack."""
	return _log_drop


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func name_of(who: int) -> String:
	"""Resident `who`'s name."""
	return (_cast.actor(who) as DemoActorScript).display_name if who >= 0 else "nobody"


func cast() -> DemoCastScript:
	"""The cast."""
	return _cast


func now_tick() -> int:
	"""The calendar tick (0 with no calendar)."""
	return calendar.tick if calendar != null else 0


func _note(text: String, warning: bool) -> void:
	"""Post to the notice feed (Water)."""
	if say.is_valid():
		say.call(text, warning)


# --- the books -------------------------------------------------------------------------------------

func lying_milli() -> int:
	"""Windfall lying in the far copse, milli-U."""
	var total: int = 0
	for milli: int in copse_milli:
		total += milli
	return total


func in_hand_milli() -> int:
	"""Wood in a gatherer's or hauler's hands, or set down for the next to fetch, milli-U."""
	var total: int = 0
	for j: int in MAX_JOBS:
		total += j_load[j] if j_live[j] == 1 else 0
	return total


func books_balance() -> bool:
	"""THE BOOKS: everything that fell is somewhere, once."""
	return fallen_milli == lying_milli() + in_hand_milli() + far_stack_milli + aboard_milli + near_stack_milli + stored_milli


func pile_count() -> int:
	"""How many piles lie in the far copse."""
	var count: int = 0
	for milli: int in copse_milli:
		count += 1 if milli > 0 else 0
	return count


func _fall(spot: int, milli: int) -> void:
	"""A pile of `milli` falls on spot `spot` (an empty one)."""
	copse_milli[spot] = milli
	fallen_milli += milli
	revision += 1


# --- closure and the timetable -------------------------------------------------------------------------

func closure() -> int:
	"""Why the ferry is closed now (Rules.OPEN: it is not; see CLOSURE in ferry_rules.gd)."""
	if weather != null:
		match weather.event():
			WeatherScript.EVENT_HEAVY_RAIN:
				return Rules.CLOSED_STORM
			WeatherScript.EVENT_HARD_FREEZE:
				return Rules.CLOSED_FREEZE
	if flooded.is_valid() and bool(flooded.call()):
		return Rules.CLOSED_FLOOD
	if ice != null and ice.frozen():
		return Rules.CLOSED_ICE
	return Rules.OPEN


func is_open() -> bool:
	"""Whether the ferry is open."""
	return closure() == Rules.OPEN


func closed_words() -> String:
	"""'closed: a storm' ('' when open)."""
	var why: int = closure()
	return "" if why == Rules.OPEN else "closed: %s" % Rules.CLOSED_WORDS[why]


func staffed() -> bool:
	"""Whether anyone in the village could take the helm (FISH >= 1)."""
	if _cast == null or skills == null:
		return false
	for who: int in _cast.actor_count():
		if skills.can_helm(who):
			return true
	return false


func update(usec: int) -> void:
	"""Advance the ferry by `usec` demo microseconds: the copse's midnights, the timetable, the crossing's postings, the
	hauls, the work and the retries. (The boat itself is rowed with the fleet: fishery.gd steps every row.)"""
	_follow_hours()
	_follow_timetable()
	_follow_hauls()
	_credit_work(usec)
	for j: int in MAX_JOBS:
		if j_live[j] == 1 and j_wait_usec[j] > 0:
			j_wait_usec[j] = maxi(0, j_wait_usec[j] - usec)
	_say_closure()


func _follow_hours() -> void:
	"""Each midnight crossed, one windfall pile falls on the copse's next empty spot (in turn by day)."""
	if calendar == null:
		return
	var hour: int = calendar.hour_index()
	while _hour_seen < hour:
		_hour_seen += 1
		if posmod(_hour_seen, SimClock.HOURS_PER_DAY) == 0:
			@warning_ignore("integer_division") _windfall(_hour_seen / SimClock.HOURS_PER_DAY)


func _windfall(day: int) -> void:
	"""The day's pile on the first empty spot from the day's turn (none when every spot holds one)."""
	var count: int = copse_milli.size()
	for k: int in count:
		var spot: int = posmod(day + k, count)
		if copse_milli[spot] == 0:
			_fall(spot, Rules.pile_milli(day))
			_note("Windfall is down in %s: %s" % [Rules.COPSE_NAME, Rules.units_text(copse_milli[spot])], false)
			return


func _follow_timetable() -> void:
	"""Post a crossing when one is due (THE TIMETABLE), bring a held one home once open, and keep the next departure."""
	var now: int = now_tick()
	if now >= next_departure:
		if x_serial == 0 and is_open() and _anything_to_carry():
			_post_crossing("the %s departure" % hour_words(next_departure))
		next_departure = Rules.departure_tick_at_or_after(now + 1)
	if x_serial == 0 and far_stack_milli >= Rules.THRESHOLD_MILLI and is_open() and _day_now() and staffed():
		_post_crossing("the far stage's stack reached %s" % Rules.units_text(Rules.THRESHOLD_MILLI))
	if x_state == X_HELD and x_job == NONE and is_open():
		var j: int = _open_job(KIND_CREW)
		if j == NONE:
			return
		x_job = j
		j_step[j] = S_TO_STAGE
		_note("The ferry is open again: a crew goes round to bring the boat back from %s" % Routes.FAR_STAGE_NAME, false)


func _day_now() -> bool:
	"""Whether it is the ferry's working day now."""
	return calendar == null or Rules.is_day_hour(calendar.now().hour)


func _anything_to_carry() -> bool:
	"""Cargo at either stage, or a passenger waiting at one."""
	if far_stack_milli > 0:
		return true
	for who: int in p_state.size():
		if p_state[who] == P_WAITING:
			return true
	return false


func _post_crossing(why: String) -> void:
	"""A crossing on the work board, its crew job waiting for a helm."""
	if not staffed():
		x_words = _unstaffed_words
		return
	var j: int = _open_job(KIND_CREW)
	if j == NONE:
		x_words = JOBS_FULL_WORDS
		return
	x_serial = _next_serial
	_next_serial += 1
	x_state = X_WAITING
	x_stage = NEAR
	x_why = why
	x_words = ""
	x_job = j
	j_step[j] = S_TO_STAGE
	_note("The ferry is called for %s" % why, false)
	revision += 1


func hour_words(tick: int) -> String:
	"""'10:00' for a tick."""
	var at: SimClock.Calendar = calendar.calendar_at(tick) if calendar != null else SimClock.Calendar.new(tick)
	return "%02d:%02d" % [at.hour, at.minute]


func _say_closure() -> void:
	"""The closure said once each time it changes (the panel and the Routes layer keep showing it)."""
	var why: int = closure()
	if why == _closed_said:
		return
	_closed_said = why
	revision += 1
	if why == Rules.OPEN:
		_note("The ferry is open again", false)
	else:
		_note("The ferry is closed: %s — a crossing under way finishes its leg, then holds" % Rules.CLOSED_WORDS[why], true)


func _follow_hauls() -> void:
	"""Wood on the ferry stage's stack goes on the board as hauls to the log stack: one a load, two at most at once."""
	if near_stack_milli <= 0:
		return
	var live: int = 0
	var spoken: int = 0
	for j: int in MAX_JOBS:
		if j_live[j] == 1 and j_kind[j] == KIND_HAUL:
			live += 1
			spoken += Rules.HAUL_LOAD_MILLI if j_step[j] <= S_PICK else 0
	if live < 2 and near_stack_milli > spoken:
		var j: int = _open_job(KIND_HAUL)
		if j != NONE:
			j_step[j] = S_TO_NEAR_STACK


# --- the player's orders (the Water panel's Ferry section; each card runs the same decision) -----------

func gather_refusal() -> String:
	"""Why Gather the far copse may not be ordered now ("" when it may): a pile not yet on the board, and a free row."""
	if pile_count() == 0:
		return "no windfall lies in %s (one falls each midnight)" % Rules.COPSE_NAME
	if _unclaimed_piles() == 0:
		return "every pile in %s is on the work board already" % Rules.COPSE_NAME
	if job_count() >= MAX_JOBS:
		return "the ferry's job list is full"
	return ""


func order_gather(members: PackedInt32Array) -> String:
	"""Every lying pile without a job goes on the work board, to the selected residents first. "" when ordered."""
	var why: String = gather_refusal()
	if not why.is_empty():
		return why
	var given := PackedInt32Array()
	for spot: int in copse_milli.size():
		if copse_milli[spot] <= 0 or _job_on_pile(spot) != NONE:
			continue
		var j: int = _open_job(KIND_GATHER)
		if j == NONE:
			break
		j_pile[j] = spot
		j_step[j] = S_TO_PILE
		for who: int in members:
			if not given.has(who) and eligibility(j, who).is_empty() and claim(j, who):
				given.append(who)
				break
	revision += 1
	return ""


func _unclaimed_piles() -> int:
	"""Lying piles no job is on."""
	var count: int = 0
	for spot: int in copse_milli.size():
		count += 1 if copse_milli[spot] > 0 and _job_on_pile(spot) == NONE else 0
	return count


func _job_on_pile(spot: int) -> int:
	"""The gather job on pile `spot` (NONE: none)."""
	for j: int in MAX_JOBS:
		if j_live[j] == 1 and j_kind[j] == KIND_GATHER and j_pile[j] == spot and j_step[j] <= S_GATHER:
			return j
	return NONE


func send_refusal() -> String:
	"""Why Send the ferry may not be ordered now ("" when it may): open, staffed, no crossing out, something to carry."""
	if not is_open():
		return "the ferry is %s" % closed_words()
	if x_serial != 0:
		return "a crossing is out already (%s)" % X_WORDS[x_state]
	if not staffed():
		return "nobody in the village can take the helm (fishing %d)" % FisheryRules.HELM_MIN_LEVEL
	if not _anything_to_carry():
		return "nothing waits to be carried at either stage"
	return ""


func order_send(members: PackedInt32Array) -> String:
	"""A crossing now, ahead of the timetable (the player's call), its crew the first selected helm. "" when sent."""
	var why: String = send_refusal()
	if not why.is_empty():
		return why
	_post_crossing("your call")
	if x_serial == 0:
		return x_words
	for who: int in members:
		if eligibility(x_job, who).is_empty() and claim(x_job, who):
			break
	return ""


func cancel_crossing() -> String:
	"""Call the crossing off before its crew is aboard: "" when called off (nothing is aboard: cargo stays on its stack;
	a passenger waiting plans again), else why not."""
	if x_serial == 0:
		return "no crossing is out"
	if x_job != NONE and DECK_STEPS.has(j_step[x_job]):
		return "the ferry is on the water — it finishes the crossing"
	if x_state == X_HELD:
		return "the boat is held at %s — it is brought back when the ferry opens" % Routes.FAR_STAGE_NAME
	if x_job != NONE:
		_end_job(x_job)
	_end_crossing("called off")
	return ""


func _boat_home() -> bool:
	"""Whether the crossing's boat is moored at home (or not the crossing's): only then may the crossing end -- one
	ended with the boat out would leave it owned by a crossing that is gone (`give_back` refuses a boat afloat)."""
	return fleet == null or fleet.owner[Routes.FERRY_BOAT] != x_serial or fleet.phase[Routes.FERRY_BOAT] == FleetScript.PHASE_MOORED


func _end_crossing(why: String) -> void:
	"""The crossing is over: the boat given back (moored at home), the record cleared, the feed told."""
	if fleet != null and fleet.owner[Routes.FERRY_BOAT] == x_serial:
		fleet.give_back(Routes.FERRY_BOAT, x_serial)
	_note("The ferry crossing is %s" % why, false)
	x_serial = 0
	x_state = X_NONE
	x_stage = NEAR
	x_job = NONE
	revision += 1


# --- the jobs: opening, claiming and releasing (work/ferry_work.gd reads these) -------------------------

func job_count() -> int:
	"""Live job rows."""
	return j_live.count(1)


func is_job(j: int, serial: int) -> bool:
	"""Whether row `j` still holds the job opened with `serial`."""
	return j >= 0 and j < MAX_JOBS and j_live[j] == 1 and j_serial[j] == serial


func _open_job(kind: int) -> int:
	"""A fresh job row of `kind` (NONE: the table is full)."""
	var j: int = j_live.find(0)
	if j < 0:
		return NONE
	j_live[j] = 1
	j_serial[j] = _next_serial
	_next_serial += 1
	j_kind[j] = kind
	j_worker[j] = NONE
	j_pile[j] = NONE
	j_load[j] = 0
	j_load_at[j] = Vector2.INF
	for column: PackedInt64Array in [j_num, j_mwu, j_need, j_wait_usec]:
		column[j] = 0
	for column: PackedByteArray in [j_issued, j_at, j_paused]:
		column[j] = 0
	j_tries[j] = 0
	j_failed[j] = NONE
	j_sub[j] = 0
	j_words[j] = ""
	revision += 1
	return j


func job_of_worker(who: int) -> int:
	"""The job `who` is on (NONE)."""
	for j: int in MAX_JOBS:
		if j_live[j] == 1 and j_worker[j] == who:
			return j
	return NONE


func waiting(j: int) -> bool:
	"""Whether job `j` waits for a resident and may be taken now."""
	return j_live[j] == 1 and j_worker[j] == NONE and j_paused[j] == 0 and j_wait_usec[j] <= 0


func eligibility(j: int, who: int) -> String:
	"""Why `who` may not take job `j` ("" when it may): one ferry job at a time, on land and free of the rescue, and a
	crew's helm needs FISH >= 1. Never a species (LORE-P12)."""
	if job_of_worker(who) != NONE and j_worker[j] != who:
		return "has another ferry job"
	if who == j_failed[j] and j_worker[j] != who:
		return "could not reach %s last time" % place_words(j)
	var brain: BrainScript = brain_of(who)
	if brain.water_hold or brain.in_water:
		return "in the water"
	if brain.underground:
		return "is below ground"
	if j_kind[j] == KIND_CREW and not skills.can_helm(who):
		return "can't take the ferry's helm yet (fishing %d; needs %d)" % [skills.level_of(who), FisheryRules.HELM_MIN_LEVEL]
	return ""


func claim(j: int, who: int) -> bool:
	"""Hand waiting job `j` to `who`, who sets off at once. False when it may not."""
	if not waiting(j) or not eligibility(j, who).is_empty():
		return false
	var task := TaskScript.new(self, j, j_serial[j])
	j_worker[j] = who
	j_issued[j] = 1
	j_at[j] = 0
	_tasks[j] = task
	var brain: BrainScript = brain_of(who)
	brain.order_task(task)
	if brain.task != task:
		j_worker[j] = NONE
		return false
	revision += 1
	return true


func _end_job(j: int) -> void:
	"""Close job `j`: its worker free (from outside `drive`, sent back to its routine); a crossing's crew link cleared."""
	var who: int = j_worker[j]
	j_live[j] = 0
	j_worker[j] = NONE
	_tasks[j] = null
	if x_job == j:
		x_job = NONE
	if who != NONE and j != _driving:
		_free_worker(who)
	revision += 1


func _free_worker(who: int) -> void:
	"""A worker whose job ended outside its own frame: off the deck, and back to its routine."""
	var brain: BrainScript = brain_of(who)
	brain.water_hold = false
	brain.work_done()


func _let_go(j: int) -> void:
	"""Job `j` loses its worker but stays on the board: a load in hand is set down where it is (for the next to fetch)."""
	var who: int = j_worker[j]
	j_worker[j] = NONE
	j_issued[j] = 0
	j_at[j] = 0
	_tasks[j] = null
	if j_load[j] > 0 and not j_load_at[j].is_finite() and who != NONE:
		j_load_at[j] = brain_of(who).surface_point()
	if j_kind[j] == KIND_CREW and (j_step[j] == S_BOARD or not DECK_STEPS.has(j_step[j])):
		j_step[j] = S_TO_STAGE
	revision += 1


# --- the task's callbacks (ferry_task.gd) ------------------------------------------------------------

func first_site(j: int, serial: int) -> Vector2:
	"""Where a new worker of job `j` walks first: its current step's place (or a set-down load's)."""
	if not is_job(j, serial):
		return Vector2.ZERO
	j_goal[j] = _goal_of(j)
	return j_goal[j]


func goal_point(j: int) -> Vector2:
	"""Where job `j` is now (the board's distance)."""
	return j_goal[j] if j_worker[j] != NONE else _goal_of(j)


func arrived(j: int, serial: int, brain: BrainScript) -> void:
	"""The worker reached where it was sent: handled on its next frame (`drive`)."""
	if is_job(j, serial) and j_worker[j] == brain.index:
		j_issued[j] = 2


func drive(j: int, serial: int, brain: BrainScript, delta: float) -> bool:
	"""One frame of job `j` for its worker: an arrival handled, then the step's frame. False once its part is over."""
	if not is_job(j, serial) or j_worker[j] != brain.index:
		return false
	_driving = j
	if j_issued[j] == 2:
		j_issued[j] = 0
		_on_arrival(j, brain)
	if is_job(j, serial) and j_worker[j] == brain.index:
		_frame(j, brain, delta)
	_driving = NONE
	return is_job(j, serial) and j_worker[j] == brain.index


func called_away(j: int, serial: int, brain: BrainScript) -> void:
	"""The brain gave the task up: a walk it could not finish, or an order, the night or a release."""
	if not is_job(j, serial) or j_worker[j] != brain.index:
		return
	if brain.trip_failed() and WALK_STEPS.has(j_step[j]):
		_unreached(j, brain)
		return
	_let_go(j)


func must_finish(j: int, serial: int) -> bool:
	"""Whether the night must wait: a load in hand, or on a deck or afloat."""
	if not is_job(j, serial):
		return false
	return DECK_STEPS.has(j_step[j]) or (j_load[j] > 0 and not j_load_at[j].is_finite())


func _unreached(j: int, brain: BrainScript) -> void:
	"""The worker could not get to its place: the job waits RETRY_USEC and tries again; after MAX_TRIES it is given up
	(a gather left for later, a crew's crossing called off; a load in hand is set down where it is)."""
	j_tries[j] += 1
	j_failed[j] = brain.index
	j_words[j] = "can't reach %s — %s" % [place_words(j), brain.route_refusal()]
	_let_go(j)
	j_wait_usec[j] = Rules.RETRY_USEC
	if j_tries[j] < Rules.MAX_TRIES:
		return
	_note("%s could not reach %s: given up" % [name_of(brain.index), place_words(j)], true)
	if j_load[j] > 0:
		return
	if j_kind[j] == KIND_CREW and x_job == j:
		if not _boat_home():
			j_tries[j] = 0
			x_words = "held at %s: waiting for a crew who can reach it" % Routes.FAR_STAGE_NAME
			return
		_end_job(j)
		_end_crossing("called off: its crew could not reach %s" % place_words(j))
	else:
		_end_job(j)


# --- the steps ---------------------------------------------------------------------------------------

func _goal_of(j: int) -> Vector2:
	"""Where job `j`'s current step is (a set-down load first: it must be picked up)."""
	if j_load[j] > 0 and j_load_at[j].is_finite():
		return j_load_at[j]
	match j_step[j]:
		S_TO_PILE, S_GATHER:
			return copse_at[j_pile[j]] if j_pile[j] >= 0 else stage_land(FAR)
		S_TO_FAR_STACK:
			return stack_at(FAR)
		S_TO_NEAR_STACK, S_PICK:
			return stack_at(NEAR)
		S_TO_LOG_STACK:
			return _log_drop
	return stage_land(x_stage)


func _begin_step(j: int, brain: BrainScript) -> void:
	"""Start job `j`'s current step: a walk ordered (loaded when it carries), or a work or deck step from where it is."""
	j_at[j] = 0
	j_sub[j] = 0
	j_mwu[j] = 0
	j_num[j] = 0
	if WALK_STEPS.has(j_step[j]):
		j_goal[j] = _goal_of(j)
		j_issued[j] = 1
		if j_load[j] > 0 and not j_load_at[j].is_finite():
			brain.task_carry_to(j_goal[j])
		else:
			brain.task_walk_to(j_goal[j])
		return
	j_issued[j] = 0


func _on_arrival(j: int, brain: BrainScript) -> void:
	"""The worker is where it was sent (only if it stands there): a set-down load picked up, or the walk's arrival."""
	if not brain.arrived_near(j_goal[j], ARRIVE_M):
		_unreached(j, brain)
		return
	j_tries[j] = 0
	j_words[j] = ""
	if j_load[j] > 0 and j_load_at[j].is_finite():
		j_load_at[j] = Vector2.INF
		_begin_step(j, brain)
		return
	match j_step[j]:
		S_TO_PILE:
			_at_pile(j, brain)
		S_TO_FAR_STACK:
			_consign(j, brain)
		S_TO_NEAR_STACK:
			_go(j, brain, S_PICK)
			j_need[j] = Rules.HANDLE_MWU_PER_U
		S_TO_LOG_STACK:
			_store(j, brain)
		S_TO_STAGE:
			_go(j, brain, S_BOARD)


func _go(j: int, brain: BrainScript, step: int) -> void:
	"""On to `step`."""
	j_step[j] = step
	_begin_step(j, brain)


func _frame(j: int, brain: BrainScript, delta: float) -> void:
	"""One frame of a step that is not a planner walk (a lapsed walk re-ordered)."""
	match j_step[j]:
		S_GATHER, S_PICK:
			_work_frame(j, brain, delta)
		S_BOARD:
			_board_frame(j, brain, delta)
		S_LOAD:
			_load_frame(j, brain)
		S_ROW:
			_row_frame(j, brain)
		S_UNLOAD:
			_unload_frame(j, brain)
		S_ALIGHT:
			_alight_frame(j, brain, delta)
		_:
			if j_issued[j] == 0 and j_wait_usec[j] <= 0:
				_begin_step(j, brain)


func _work_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""At its work: standing at its place (off it, it walks back and nothing is credited), facing it, the clip playing."""
	if not brain.arrived_near(j_goal[j], ARRIVE_M):
		j_at[j] = 0
		j_step[j] = S_TO_PILE if j_step[j] == S_GATHER else S_TO_NEAR_STACK
		_begin_step(j, brain)
		return
	j_at[j] = 1
	brain.task_face(j_goal[j] + Vector2(0.6, 0.0), delta)
	brain.task_play(CLIP_WORK)


func _credit_work(usec: int) -> void:
	"""Every worker at its work does §5.2's work at the base rate (FISH-free: fishery_rules.gd's step-rate arithmetic at
	level 0); a step completes at its need."""
	for j: int in MAX_JOBS:
		if j_live[j] == 0 or j_at[j] == 0 or j_worker[j] == NONE or not WORK_STEPS.has(j_step[j]):
			continue
		j_num[j] += FisheryRules.mwu_numerator(usec, 0)
		@warning_ignore("integer_division") var done: int = j_num[j] / FisheryRules.MWU_DENOMINATOR
		j_num[j] -= done * FisheryRules.MWU_DENOMINATOR
		j_mwu[j] += done
		if j_mwu[j] >= j_need[j]:
			j_at[j] = 0
			_work_done(j)


func _work_done(j: int) -> void:
	"""A work step finished: a pile gathered into the hand, a load picked off the stack, a boat loaded or unloaded."""
	var who: int = j_worker[j]
	match j_step[j]:
		S_GATHER:
			_gathered(j)
		S_PICK:
			_picked(j)
		S_LOAD:
			_loaded()
		S_UNLOAD:
			_unloaded()
	if who != NONE and j_live[j] == 1 and WALK_STEPS.has(j_step[j]):
		_begin_step(j, brain_of(who))


# --- gathering and hauling -----------------------------------------------------------------------------

func _at_pile(j: int, brain: BrainScript) -> void:
	"""At its pile: gather it (the woods' rate), or -- gone (gathered by another) -- the job is over."""
	if j_pile[j] < 0 or copse_milli[j_pile[j]] <= 0:
		_end_job(j)
		return
	_go(j, brain, S_GATHER)
	j_need[j] = Rules.gather_mwu(copse_milli[j_pile[j]])


func _gathered(j: int) -> void:
	"""The pile into the gatherer's hands (lying -> in hand), and on to the far stage's stack."""
	var spot: int = j_pile[j]
	j_load[j] = copse_milli[spot]
	copse_milli[spot] = 0
	j_step[j] = S_TO_FAR_STACK
	revision += 1


func _consign(j: int, brain: BrainScript) -> void:
	"""The wood put down on the far stage's stack (in hand -> far stack): the job is done."""
	far_stack_milli += j_load[j]
	_note("%s brought %s of windfall to %s" % [name_of(brain.index), Rules.units_text(j_load[j]), Routes.FAR_STAGE_NAME], false)
	j_load[j] = 0
	_end_job(j)


func _picked(j: int) -> void:
	"""A load off the ferry stage's stack (near stack -> in hand), up to a hauler's; with nothing left, the job is over."""
	var take: int = mini(Rules.HAUL_LOAD_MILLI, near_stack_milli)
	if take <= 0:
		_end_job(j)
		return
	near_stack_milli -= take
	j_load[j] = take
	j_step[j] = S_TO_LOG_STACK
	revision += 1


func _store(j: int, brain: BrainScript) -> void:
	"""The load onto the log stack (in hand -> the stores' wood): the job is done."""
	var milli: int = j_load[j]
	stores.add_wood(milli)
	stored_milli += milli
	j_load[j] = 0
	_note("%s stacked %s of ferried wood: the stores hold %s" % [name_of(brain.index), Rules.units_text(milli),
		Rules.units_text(stores.wood_milli_u)], false)
	_end_job(j)


# --- the crew: boarding, loading, rowing, unloading, alighting ---------------------------------------

func _board_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""At the stage: recheck (closed -- stand down, the crossing waits), take the boat at home, then down the deck into
	the helm (held on the water from the first plank: `water_hold`)."""
	if j_sub[j] == 0:
		var why: String = _board_refusal()
		if not why.is_empty():
			_stand_down(j, why)
			return
		j_sub[j] = 1
	brain.water_hold = true
	var target: Vector2 = _step_m(x_stage) if j_sub[j] == 1 else fleet.seat_m(Routes.FERRY_BOAT, FleetScript.HELM)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M, delta):
		return
	if j_sub[j] == 1:
		j_sub[j] = 2
		return
	fleet.seat(Routes.FERRY_BOAT, FleetScript.HELM, brain.index)
	_start_loading(j)


func _board_refusal() -> String:
	"""Why the crew may not board now ("" when it may): the ferry closed, or -- at home -- the boat not free for it."""
	if not is_open():
		return closed_words()
	if x_stage == NEAR and fleet.owner[Routes.FERRY_BOAT] != x_serial:
		if not fleet.is_free(Routes.FERRY_BOAT):
			return "the ferry boat is out (a rescue has it)"
		fleet.set_course(Routes.FERRY_BOAT, Routes.route(Routes.FERRY_BOAT), map)
		fleet.take(Routes.FERRY_BOAT, x_serial)
	return ""


func _stand_down(j: int, why: String) -> void:
	"""A refusal at the stage ends the crew's part where it stands (the crossing kept, checked again after RECHECK_USEC):
	said once until the reason changes."""
	if x_words != why:
		x_words = why
		_note("The ferry waits at %s: %s" % [Routes.JETTY_NAMES[STAGE_JETTY[x_stage]], why], false)
	var who: int = j_worker[j]
	_let_go(j)
	j_wait_usec[j] = Rules.RECHECK_USEC
	if who != NONE and j != _driving:
		_free_worker(who)
	elif who != NONE:
		brain_of(who).water_hold = false


func _start_loading(j: int) -> void:
	"""Aboard at a stage: load what it holds for the far side (the far stack, up to the boat's cargo), passengers board."""
	j_step[j] = S_LOAD
	x_state = X_LOADING
	x_words = ""
	var cargo: int = mini(far_stack_milli, Rules.BOAT_CARGO_MILLI - aboard_milli) if x_stage == FAR else 0
	j_need[j] = Rules.handle_mwu(cargo) if cargo > 0 else 0
	j_load[j] = 0
	j_mwu[j] = 0
	j_at[j] = 1 if cargo > 0 else 0
	j_pile[j] = cargo
	j_sub[j] = 0
	revision += 1


func _load_frame(j: int, brain: BrainScript) -> void:
	"""Loading at the stage (the work credited in `update`); done and nobody still boarding, it rows -- unless the ferry
	closed meanwhile: at home it stands down (the boat given back), at the far stage it holds."""
	_sit(brain, FleetScript.HELM)
	brain.task_play(CLIP_WORK if j_at[j] == 1 else CLIP_WAIT)
	if j_at[j] == 1 or boarding_count() > 0:
		return
	if is_open() and seat_free() and _waiting_at(x_stage) and j_sub[j] < BOARD_GRACE_STEPS:
		j_sub[j] += 1
		return
	if not is_open():
		_closed_aboard(j)
		return
	_set_out(j)


func _loaded() -> void:
	"""The load aboard (far stack -> aboard), in one step."""
	var cargo: int = j_pile[x_job] if x_job != NONE else 0
	cargo = mini(cargo, far_stack_milli)
	far_stack_milli -= cargo
	aboard_milli += cargo
	revision += 1


func _set_out(j: int) -> void:
	"""Push off: from home along the fixed route, or from the far stage back the same way."""
	var boat: int = Routes.FERRY_BOAT
	if x_stage == NEAR:
		fleet.set_off(boat)
		x_stage = FAR
	else:
		fleet.row_back(boat)
		x_stage = NEAR
	x_state = X_ROWING
	j_step[j] = S_ROW
	revision += 1


func _closed_aboard(j: int) -> void:
	"""Closed before pushing off: at home the crew steps off and the boat is given back (end a leg on any refusal); at
	the far stage the crossing holds. Either way a passenger who boarded there steps back ashore, its leg ended."""
	x_words = closed_words()
	j_step[j] = S_ALIGHT
	j_sub[j] = 0
	x_state = X_HELD if x_stage == FAR else X_HOMING
	for who: int in p_state.size():
		if (p_state[who] == P_ABOARD or p_state[who] == P_BOARDING) and p_from[who] == x_stage:
			if fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT) == who:
				fleet.seat(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT, FleetScript.NOBODY)
			p_state[who] = P_RETURNING
			p_sub[who] = 0
	revision += 1


func _row_frame(j: int, brain: BrainScript) -> void:
	"""Afloat at the helm, pulling; arrived (on station at the far stage, moored at home), unload."""
	_sit(brain, FleetScript.HELM)
	var boat: int = Routes.FERRY_BOAT
	brain.task_play(CLIP_ROW if fleet.moving(boat) else CLIP_WAIT)
	var there: bool = fleet.phase[boat] == (FleetScript.PHASE_ON_STATION if x_stage == FAR else FleetScript.PHASE_MOORED)
	if not there:
		return
	j_step[j] = S_UNLOAD
	x_state = X_UNLOADING
	j_need[j] = Rules.handle_mwu(aboard_milli) if aboard_milli > 0 and x_stage == NEAR else 0
	j_mwu[j] = 0
	j_at[j] = 1 if j_need[j] > 0 else 0
	revision += 1


func _unload_frame(j: int, brain: BrainScript) -> void:
	"""Unloading (credited in `update`) while passengers step off; then home: ashore; far: load, or hold if closed."""
	_sit(brain, FleetScript.HELM)
	brain.task_play(CLIP_WORK if j_at[j] == 1 else CLIP_WAIT)
	if j_at[j] == 1 or riders_for(x_stage) > 0:
		return
	if x_stage == NEAR:
		j_step[j] = S_ALIGHT
		j_sub[j] = 0
		x_state = X_HOMING
		return
	if not is_open():
		_closed_aboard(j)
		return
	_start_loading(j)


func _unloaded() -> void:
	"""The cargo onto the ferry stage's stack (aboard -> near stack), in one step."""
	near_stack_milli += aboard_milli
	ferried_milli += aboard_milli
	if aboard_milli > 0:
		_note("The ferry landed %s of wood at %s" % [Rules.units_text(aboard_milli), Routes.FERRY_STAGE_NAME], false)
	aboard_milli = 0
	revision += 1


func _alight_frame(j: int, brain: BrainScript, delta: float) -> void:
	"""Out of the helm, up the deck to the land end; off the water there. At home the boat is given back and the crossing
	is over; at the far stage it holds (the boat still the crossing's)."""
	if j_sub[j] == 0:
		fleet.seat(Routes.FERRY_BOAT, FleetScript.HELM, FleetScript.NOBODY)
		j_sub[j] = 1
	var target: Vector2 = _step_m(x_stage) if j_sub[j] == 1 else stage_land(x_stage)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M if j_sub[j] == 1 else 0.0, delta):
		return
	if j_sub[j] == 1:
		j_sub[j] = 2
		return
	brain.water_hold = false
	_ashore(j)


func _ashore(j: int) -> void:
	"""The crew ashore: the crossing over at home (counted), or held at the far stage."""
	var held: bool = x_state == X_HELD
	_end_job(j)
	if held:
		x_job = NONE
		_note("The ferry holds at %s: %s" % [Routes.FAR_STAGE_NAME, x_words], true)
		return
	if x_words.is_empty():
		crossings_done += 1
		_end_crossing("done (%d so far)" % crossings_done)
	else:
		_end_crossing("stood down: %s" % x_words)


func _sit(brain: BrainScript, seat: int) -> void:
	"""In seat `seat` of the ferry boat wherever it is."""
	var boat: int = Routes.FERRY_BOAT
	brain.water_place(fleet.seat_m(boat, seat), Routes.JETTY_DECK_Y_M - SEAT_DROP_M, fleet.yaw(boat))


func _step_m(stage: int) -> Vector2:
	"""Where the boat is stepped into from a stage's deck: the ferry stage's end, or the far stage's north edge."""
	return Routes.m_of(Routes.BERTH_STEP_U[Routes.FERRY_BOAT] if stage == NEAR else Routes.FAR_STEP_U)


func _deck_walk(brain: BrainScript, target: Vector2, y_m: float, delta: float) -> bool:
	"""A straight walk on a deck at its height (presentation: the planner never routes over water). True once there."""
	var to: Vector2 = target - brain.position
	if to.length() <= 0.05:
		brain.water_place(target, y_m, brain.yaw)
		brain.task_play(CLIP_WAIT)
		return true
	brain.water_place(brain.position + to.normalized() * minf(Rules.DECK_WALK_M_S * delta, to.length()), y_m,
		atan2(to.x, to.y))
	brain.task_play(BrainScript.CLIP_WALK)
	return false


# --- passengers (water_crossings.gd's FERRY_ROW) -------------------------------------------------------

func boarding_count() -> int:
	"""Passengers walking the deck into the boat now."""
	return p_state.count(P_BOARDING)


func _waiting_at(stage: int) -> bool:
	"""Whether a passenger waits at `stage` for the next boarding."""
	for who: int in p_state.size():
		if p_state[who] == P_WAITING and p_from[who] == stage:
			return true
	return false


func riders_for(stage: int) -> int:
	"""Passengers aboard who step off at `stage` (still in the boat)."""
	var count: int = 0
	for who: int in p_state.size():
		if p_state[who] == P_ABOARD and 1 - p_from[who] == stage:
			count += 1
	return count


func seat_free() -> bool:
	"""Whether the passenger seat is free."""
	return fleet != null and fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT) == FleetScript.NOBODY \
		and p_state.count(P_BOARDING) == 0


func wait_ticks(from: int) -> int:
	"""Calendar ticks a passenger at stage `from` waits to board (NONE: no boarding in sight -- closed, unstaffed, or the
	boat held): a crossing posted and waiting for its crew, the crew's walk to the ferry stage (plus the row out, for the
	far stage); at once where this crossing's boat loads (the far stage: or is rowing to, its row; at home it loads only
	setting out -- rowing home it only unloads); else its next call there -- the next scheduled departure from home, plus
	its row out for the far stage."""
	return _wait_when_boardable(from) if boardable() else NONE


func boardable() -> bool:
	"""Whether anyone may be offered a boarding: open, staffed and not held at the far stage."""
	return is_open() and staffed() and x_state != X_HELD


func _wait_when_boardable(from: int) -> int:
	"""`wait_ticks` once `boardable` holds."""
	if x_serial != 0 and x_state == X_WAITING:
		return _crew_walk_ticks() + (_row_ticks() if from == FAR else 0)
	if x_serial != 0 and x_stage == from and (from == FAR or x_state == X_LOADING):
		return _row_ticks() if x_state == X_ROWING else 0
	var depart: int = maxi(next_departure - now_tick(), 0)
	if x_serial != 0:
		depart = maxi(depart, _row_ticks())
	if from == FAR:
		depart += _row_ticks()
	return depart


func _row_ticks() -> int:
	"""Calendar ticks the ferry's row takes, one way (rounded up; its route is fixed, so worked out once)."""
	if _row_t < 0:
		_row_t = BoatRows.ticks_to_cover(Routes.route_length_u(Routes.FERRY_BOAT), FleetScript.ROW_SPEED_U_S)
	return _row_t


func _crew_walk_ticks() -> int:
	"""A crossing posted at home still waiting for its crew boards when the crew is there: its walk to the stage (straight,
	a lower bound); unclaimed, no sooner than the next scheduled departure."""
	var who: int = j_worker[x_job] if x_job != NONE else NONE
	if who == NONE:
		return maxi(next_departure - now_tick(), 0)
	var brain: BrainScript = brain_of(who)
	var mm: int = roundi(brain.position.distance_to(stage_land(NEAR)) * float(BoatRows.MM_PER_M))
	return BoatRows.ticks_to_cover(mm, maxi(roundi(brain.walk_speed * float(BoatRows.MM_PER_M)), MIN_WALK_MM_S))


func ride_ticks() -> int:
	"""A passenger's ride, stage to stage, in calendar ticks: down one stage's deck and up the other's at
	Rules.DECK_WALK_MM_S, and the row between them (each rounded up; worked out once)."""
	if _ride_t >= 0:
		return _ride_t
	var decks_u: int = 0
	for stage: int in 2:
		var jetty: int = STAGE_JETTY[stage]
		decks_u += Routes.leg_length_u(Routes.JETTY_LANDS_U[jetty], Routes.JETTY_ENDS_U[jetty])
	@warning_ignore("integer_division") var decks_mm: int = decks_u * BoatRows.MM_PER_M / WaterRules.UNITS_PER_M
	_ride_t = BoatRows.ticks_to_cover(decks_mm, Rules.DECK_WALK_MM_S) + _row_ticks()
	return _ride_t


func fill_boat_row(rows: BoatRows, r: int, walker: int, _from: Vector2, _carrying: bool) -> void:
	"""The ferry's boat row for `walker` (see PASSENGERS): open between the two stages with its ride and its longest
	wait, and at each stage its boardings with the seat free -- none while closed, unstaffed or held."""
	if walker < 0 or walker >= p_state.size() or fleet == null or not boardable():
		return
	rows.open_row(r, stage_land(NEAR), stage_land(FAR), ride_ticks(), Rules.MAX_WAIT_TICKS)
	for stage: int in 2:
		_list_boardings(rows, r, stage, walker)


func _list_boardings(rows: BoatRows, r: int, stage: int, walker: int) -> void:
	"""Stage `stage`'s boardings, in ticks from now (see boat_rows.gd A ROW): the one in sight (`wait_ticks`; skipped
	when another passenger has booked its seat), then each later scheduled departure from home (the far stage a row
	later, and none due before the crossing under way is home again), MAX_BOARDINGS at most. A crossing under way comes
	whenever the walker gets there (ready by its boarding); a scheduled one is posted only for a passenger already waiting
	when it leaves home (ready by its departure)."""
	var first: int = _wait_when_boardable(stage)
	var offset: int = _row_ticks() if stage == FAR else 0
	var now: int = now_tick()
	if not _booked(stage, walker):
		rows.add_boarding(r, stage, first if x_serial != 0 else maxi(first - offset, 0), first)
	var depart: int = maxi(now + first - offset, _home_again(now) - 1)
	for k: int in BoatRows.MAX_BOARDINGS * 2:
		depart = Rules.departure_tick_at_or_after(depart + 1)
		rows.add_boarding(r, stage, depart - now, depart + offset - now)


func _home_again(now: int) -> int:
	"""The earliest tick the crossing under way can be home to take a scheduled departure: its far stage's boarding and
	the row back (none under way: `now`). A departure due while it is out is not posted (`_follow_timetable`)."""
	return now + _wait_when_boardable(FAR) + _row_ticks() if x_serial != 0 else now


func _booked(stage: int, walker: int) -> bool:
	"""Whether another passenger already waits for the next boarding at `stage` (one seat a crossing)."""
	for who: int in p_state.size():
		if who != walker and p_state[who] != P_NONE and p_from[who] == stage:
			return true
	return false


func end_point(far: bool) -> Vector2:
	"""The crossing row's land ends: the ferry stage's (end a), the far stage's (end b)."""
	return stage_land(FAR if far else NEAR)


func begin_passenger(brain: BrainScript, reverse: bool) -> void:
	"""`brain` arrives to cross by ferry from the ferry stage (or, `reverse`, from the far stage): it waits there."""
	var who: int = brain.index
	p_state[who] = P_WAITING
	p_from[who] = FAR if reverse else NEAR
	p_goal[who] = brain.goal()
	p_path[who] = brain.path.size()
	p_sub[who] = 0
	revision += 1


func step_passenger(brain: BrainScript, delta: float) -> bool:
	"""One step of a passenger's leg; true once it stands at the other stage's land end -- or, refused while it waits,
	where it waits (its route then ends there and it plans again)."""
	var who: int = brain.index
	match p_state[who]:
		P_WAITING:
			return _wait_frame(brain, delta)
		P_BOARDING:
			_boarding_frame(brain, delta)
		P_ABOARD:
			_riding_frame(brain)
		P_ALIGHTING:
			return _alighting_frame(brain, delta)
		P_RETURNING:
			return _returning_frame(brain, delta)
	return false


func passenger_refusal(who: int) -> String:
	"""Why passenger `who`, waiting, gives up the ferry now ("" while it may wait): an order meanwhile, the ferry closed,
	no boarding within MAX_WAIT_TICKS, or another passenger first."""
	var brain: BrainScript = brain_of(who)
	if brain.goal() != p_goal[who] or brain.path.size() != p_path[who]:
		return "given another order"
	if not is_open():
		return "the ferry is %s" % closed_words()
	var wait: int = wait_ticks(p_from[who])
	if wait == NONE or wait > Rules.MAX_WAIT_TICKS:
		return "no boat within %d game hours" % Rules.MAX_WAIT_HOURS
	return ""


func _wait_frame(brain: BrainScript, delta: float) -> bool:
	"""Waiting by the stage: refused, the leg ends here; the boat loading there with the seat free, it boards."""
	var who: int = brain.index
	var why: String = passenger_refusal(who)
	if not why.is_empty():
		_end_leg_here(brain)
		if not why.begins_with("given"):
			_note("%s won't wait for the ferry: %s — going by land" % [name_of(who), why], false)
		return true
	if x_state == X_LOADING and x_stage == p_from[who] and seat_free():
		p_state[who] = P_BOARDING
		p_sub[who] = 0
		brain.water_hold = true
		revision += 1
		return false
	if not _deck_walk(brain, wait_at(p_from[who]), 0.0, delta):
		return false
	brain.water_clip(CLIP_WAIT, 1.0)
	return false


func _boarding_frame(brain: BrainScript, delta: float) -> void:
	"""Down the deck and into the passenger seat."""
	var who: int = brain.index
	var stage: int = p_from[who]
	var target: Vector2 = _step_m(stage) if p_sub[who] == 0 else fleet.seat_m(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M, delta):
		return
	if p_sub[who] == 0:
		p_sub[who] = 1
		return
	fleet.seat(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT, who)
	p_state[who] = P_ABOARD
	revision += 1


func _riding_frame(brain: BrainScript) -> void:
	"""In the seat wherever the boat is; at its stage, unloading, it steps off."""
	var who: int = brain.index
	_sit(brain, Rules.PASSENGER_SEAT)
	brain.water_clip(CLIP_WAIT, 1.0)
	if x_state == X_UNLOADING and x_stage == 1 - p_from[who]:
		fleet.seat(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT, FleetScript.NOBODY)
		p_state[who] = P_ALIGHTING
		p_sub[who] = 0
		revision += 1


func _alighting_frame(brain: BrainScript, delta: float) -> bool:
	"""Out of the boat, up the other stage's deck to its land end: the leg done."""
	var who: int = brain.index
	var stage: int = 1 - p_from[who]
	var target: Vector2 = _step_m(stage) if p_sub[who] == 0 else stage_land(stage)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M if p_sub[who] == 0 else 0.0, delta):
		return false
	if p_sub[who] == 0:
		p_sub[who] = 1
		return false
	brain.water_hold = false
	p_state[who] = P_NONE
	passengers_carried += 1
	_note("%s crossed by ferry to %s" % [name_of(who), Routes.JETTY_NAMES[STAGE_JETTY[stage]]], false)
	revision += 1
	return true


func _returning_frame(brain: BrainScript, delta: float) -> bool:
	"""Back out of the boat and up its own stage's deck: the leg ends where it began."""
	var who: int = brain.index
	var stage: int = p_from[who]
	var target: Vector2 = _step_m(stage) if p_sub[who] == 0 else stage_land(stage)
	if not _deck_walk(brain, target, Routes.JETTY_DECK_Y_M if p_sub[who] == 0 else 0.0, delta):
		return false
	if p_sub[who] == 0:
		p_sub[who] = 1
		return false
	_end_leg_here(brain)
	_note("%s stepped back ashore: the ferry is %s — going by land" % [name_of(who), closed_words()], false)
	return true


func _end_leg_here(brain: BrainScript) -> void:
	"""A passenger's leg ended by a refusal (water_crossings.gd's bank recheck does the same): the route cut where it
	stands, so it plans again from land -- where the ferry, refused, is not offered."""
	var who: int = brain.index
	p_state[who] = P_NONE
	brain.water_hold = false
	brain.path.resize(brain.path_index + 1)
	brain.path_tunnel.resize(brain.path_index + 1)
	brain.path[brain.path_index] = brain.position
	revision += 1


func abandon_passenger(brain: BrainScript) -> void:
	"""Forget a passenger's leg (an emergency took it off where it stands): its seat freed."""
	var who: int = brain.index
	if fleet != null and fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT) == who:
		fleet.seat(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT, FleetScript.NOBODY)
	p_state[who] = P_NONE
	brain.water_hold = false
	revision += 1


func passenger_text(who: int) -> String:
	"""What a passenger is doing, in words."""
	match p_state[who]:
		P_WAITING:
			return "waiting for the ferry at %s" % Routes.JETTY_NAMES[STAGE_JETTY[p_from[who]]]
		P_BOARDING:
			return "boarding the ferry"
		P_ABOARD:
			return "on the ferry to %s" % Routes.JETTY_NAMES[STAGE_JETTY[1 - p_from[who]]]
		P_ALIGHTING:
			return "stepping off the ferry"
	return "crossing by ferry"


func is_passenger(who: int) -> bool:
	"""Whether `who` is on a ferry leg."""
	return who >= 0 and who < p_state.size() and p_state[who] != P_NONE


# --- words and the board's commands ---------------------------------------------------------------------

func place_words(j: int) -> String:
	"""Where job `j`'s current step is, in words."""
	match j_step[j]:
		S_TO_PILE, S_GATHER:
			return Rules.COPSE_NAME
		S_TO_FAR_STACK:
			return "the far stage's stack"
		S_TO_NEAR_STACK, S_PICK:
			return "the ferry stage's stack"
		S_TO_LOG_STACK:
			return "the log stack"
	return Routes.JETTY_NAMES[STAGE_JETTY[x_stage]]


func doing_text(j: int, serial: int) -> String:
	"""What the worker of job `j` is doing, for the party panel and the roster."""
	if not is_job(j, serial):
		return ""
	match j_step[j]:
		S_GATHER:
			return "gathering windfall in %s" % Rules.COPSE_NAME
		S_TO_FAR_STACK, S_TO_LOG_STACK:
			return "carrying %s of wood to %s" % [Rules.units_text(j_load[j]), place_words(j)]
		S_PICK:
			return "taking up ferried wood"
		S_BOARD:
			return "boarding the ferry boat"
		S_LOAD:
			return "loading the ferry at %s" % place_words(j)
		S_ROW:
			return "rowing the ferry to %s" % Routes.JETTY_NAMES[STAGE_JETTY[x_stage]]
		S_UNLOAD:
			return "unloading the ferry at %s" % place_words(j)
		S_ALIGHT:
			return "stepping ashore from the ferry"
	return "%s: going to %s" % [KIND_WORDS[j_kind[j]], place_words(j)]


func hold_refusal(j: int) -> String:
	"""Why job `j`'s worker may not be stopped or swapped now ("" when it may): a load in hand is delivered (decision
	0222), and one on a deck or afloat finishes the crossing first (MOVE-REQ-007)."""
	var who: int = j_worker[j]
	if who == NONE:
		return ""
	if j_load[j] > 0 and not j_load_at[j].is_finite():
		return "%s is carrying the load — it finishes the delivery first" % name_of(who)
	if DECK_STEPS.has(j_step[j]):
		return "%s is on the ferry — it finishes the crossing first" % name_of(who)
	return ""


func pause_job(j: int, on: bool) -> String:
	"""Pause job `j` (its worker stood down, the job kept) or resume it: "" when done, else why not."""
	if not on:
		j_paused[j] = 0
		revision += 1
		return ""
	if j_paused[j] == 1:
		return "it is paused already"
	var why: String = hold_refusal(j)
	if not why.is_empty():
		return why
	var who: int = j_worker[j]
	_let_go(j)
	j_paused[j] = 1
	if who != NONE:
		_free_worker(who)
	return ""


func reassign_job(j: int, who: int) -> String:
	"""Give job `j` to `who` instead: "" when done, else why not."""
	var why: String = hold_refusal(j)
	if why.is_empty():
		why = eligibility(j, who)
	if not why.is_empty():
		return why
	var was: int = j_worker[j]
	if was != NONE:
		_let_go(j)
		_free_worker(was)
	j_paused[j] = 0
	j_wait_usec[j] = 0
	return "" if claim(j, who) else "it could not be handed over"


func cancel_job(j: int) -> String:
	"""Cancel job `j`: a gather or haul not yet carrying, or a crossing before its crew is aboard. "" when done."""
	if j_load[j] > 0:
		return "a delivery always finishes: its wood is already gathered"
	if j_kind[j] == KIND_CREW:
		return cancel_crossing()
	_end_job(j)
	return ""


func remaining_usec(j: int) -> int:
	"""Demo microseconds of work job `j`'s current work step has left (-1: not working)."""
	if not WORK_STEPS.has(j_step[j]):
		return -1
	return FisheryRules.work_usec(maxi(j_need[j] - j_mwu[j], 0), 0)


func is_walking(j: int) -> bool:
	"""Whether job `j`'s worker is on a planner walk."""
	return WALK_STEPS.has(j_step[j])


func held_key_of_job(j: int) -> StringName:
	"""The model job `j`'s worker carries (&"": nothing): a log while it carries wood."""
	return LOG_KEY if j_load[j] > 0 and not j_load_at[j].is_finite() else &""


func status_line() -> String:
	"""'Ferry: open · next departure 10:00', 'Ferry: open · crossing: rowing', 'Ferry: closed: a storm · crossing:
	holding at the far stage'."""
	var parts := PackedStringArray(["Ferry: " + (closed_words() if not is_open() else "open")])
	if x_serial != 0:
		parts.append("crossing: %s" % X_WORDS[x_state])
		if not x_words.is_empty() and is_open():
			parts.append(x_words)
	elif not x_words.is_empty():
		parts.append(x_words)
	if x_serial == 0 and is_open():
		parts.append("next departure %s" % hour_words(next_departure))
	return " · ".join(parts)
