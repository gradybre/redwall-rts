extends RefCounted
## One demo resident's wandering: which POI next, the route there, walking it, and what to do on
## arrival. Decision 0196. Pure logic -- no nodes -- so the tests drive it without a scene tree; the
## actor node reads `position`, `yaw`, `clip` and `clip_speed` back each frame and draws them.
##
## The cycle:  IDLE -> (pick a POI, plan) -> TURN -> WALK -> FACE -> ACT -> IDLE -> ACT ... -> IDLE -> TURN
##   * TURN   turns on the spot toward the route before setting off, stepping in place (the
##            shuffle) past SHUFFLE_ANGLE. It hands over to WALK as soon as the route is within
##            BLEND_WALK_ANGLE and the ground ahead is clear, so a big turn finishes on a walking
##            curve; only a walker boxed in (facing a wall, say) turns all the way on the spot.
##   * WALK   moves along `yaw` at the creature's measured walk speed with the walk clip at 1.0,
##            which is what keeps the planted foot from sliding (tools/stage_demo_assets.py). The yaw
##            turns toward the route at a limited rate; a demand past STOP_TO_TURN_ANGLE stops the
##            walker and hands back to TURN rather than skating round a tight corner.
##   * ACT    plays the POI's activities in bouts (BOUTS_MIN..MAX of them, each a different activity
##            from the last where there is a choice), and keeps adding bouts until it has worked
##            WORK_PER_WALK times as long as the trip there took.
##   * A trip away from a stockpile may carry: the carry clip plays at clip_root_motion's playback
##            rate for the chosen speed, and each frame's step follows the clip's own recorded root
##            path key by key -- its uneven pace AND its sideways weave (up to +-0.24 m over a loop on
##            the badger) -- so a planted foot stays planted there too (decision 0195).
##
## Getting unstuck, all bounded: someone standing across the current leg -> replan at once; held back
## by the constraint for BLOCKED_AFTER_S, no headway (or turning) for STUCK_AFTER_S, or more than
## MAX_FLIPS walk -> turn flips on one leg -> replan; more than MAX_REPLANS -> give the trip up and
## release the slot.
##
## ORDERS (the demo's select-and-command layer, demo/control/). `order_move()` gives up any POI slot,
## walks to a point and HOLDs there -- idle, facing the way it came, never wandering. `order_work()`
## takes a given free slot at a POI and works there, bout after bout, until released. A trip an order
## cannot finish ends in HOLD where the walker stands, never in wandering. `release()` hands the
## resident back: a holder or an ordered walker stops, idles a moment and wanders on; an ordered
## worker finishes its bout and wanders on from there.
##
## TUNNELS (demo/tunnel/). A route may cross a finished tunnel: `path_tunnel` holds, per waypoint,
## the leg code of the tunnel crossed to reach it (or SURFACE_LEG). The walker must reach the mouth
## itself -- no corner is cut into or past one -- then TUNNEL walks it underground at walk speed,
## off the surface (CastSpace.set_underground), and comes up at the far mouth to go on. A tunnel
## entered is always finished (MOVE-REQ-007): an order given underground is carried out from the
## mouth it comes up at. `order_dig()` walks a mole to a tunnel's entrance and DIGs: the tunnel's
## own integer clock advances while it works (tunnel_network.gd), and the mole follows the dig face
## underground and comes up at the exit when it opens, stepping clear of the hole -- the first of
## STEP_OUT_TURNS that stays inside the village and clear of obstacles, holes and residents -- and
## holding there. Called away while digging, it leaves the tunnel paused and backs out through what
## it dug to the entrance first. A mole that cannot REACH the entrance leaves the tunnel paused as a
## plan (tunnel_network.hold_unreached), never deleted.
##
## SHARING A BORE. Inside a tunnel a walker keeps BORE_GAP_M behind anyone ahead going its way
## (following, never overlapping), and steps PASS_OFFSET_M to its right while someone comes the
## other way within PASS_WINDOW_M -- two walkers pass side by side inside the one-metre bore. At the
## far mouth it waits below while someone on the surface stands on the hole, for at most
## EMERGE_WAIT_S, rather than coming up into them.
##
## WEATHER AND LANTERNS (demo/weather/, demo/tunnel/). On the surface a walker covers ground at its
## walk speed times the weather's surface speed (tunnel_network.surface_permille), its clip slowed
## to match so the feet stay planted; in a bore, at walk speed times the bore's own speed (faster
## when lit), whatever the weather.
##
## HAULING (demo/tunnel/). A carrier may take a tunnel whose bore fits it WITH its load
## (tunnel_network.fits_tunnel, loaded): its trip is planned loaded, it walks the bore at the carry's
## own pace and clip, and only the surface part of its trip counts toward CARRY_MAX_TRIP_M.
##
## QUEUES (tunnel_queue.gd). Heading down a tunnel, a walker within JOIN_M of a busy mouth joins its
## line (QUEUE) instead of crowding it, stands at its place facing the hole, moves up as the line
## does, and walks on once it holds the mouth's grant; after QUEUE_GIVE_UP_S it plans a walk instead.
##
## TASKS (tunnel_task.gd). `order_task()` hands the resident to a task -- a tunnel job, a dig crew's
## place, an evacuation: it walks to the task's site, then the task drives it (TASK) through the
## task_* functions until it is done, and the resident goes back to its routine. A new order or a
## release cancels the task first; one standing in a bore walks out to the nearest mouth.
##
## Yaw 0 faces +Z, the way the models face: forward is Vector2(sin(yaw), cos(yaw)) in (x, z).
## Deterministic: every random choice comes from this resident's own seeded generator.

const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")
const TunnelRouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const TunnelQueueScript := preload("res://demo/tunnel/tunnel_queue.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")

enum State { IDLE, TURN, WALK, FACE, ACT, HOLD, TUNNEL, DIG, QUEUE, TASK }

const ORDER_NONE: int = 0
const ORDER_MOVE: int = 1
const ORDER_WORK: int = 2
const ORDER_DIG: int = 3
const ORDER_TASK: int = 4

## What the command layer shows a resident doing (activity()).
const ACTIVITY_WANDERING: int = 0
const ACTIVITY_WALKING: int = 1
const ACTIVITY_WORKING: int = 2
const ACTIVITY_HOLDING: int = 3
const ACTIVITY_TUNNEL: int = 4
const ACTIVITY_DIGGING: int = 5
const ACTIVITY_TASK: int = 6
const ACTIVITY_QUEUE: int = 7

const CLIP_IDLE: StringName = &"idle"
const CLIP_WALK: StringName = &"walk"
const CLIP_CARRY: StringName = &"carry_heavy_object_walk"
## Digging plays the first of these the creature has: pulling up from the ground, else collecting.
const DIG_CLIPS: Array[StringName] = [&"pull_radish", &"collect_object"]
## Out of a finished tunnel, the digger steps this far on (demo) so the exit is left clear, when the
## ground there keeps this much clear of every obstacle beyond its body.
const STEP_OUT_M: float = 1.0
const STEP_OUT_CLEAR_M: float = 0.12
## The step-out directions tried in order, as turns (radians) from straight on out of the exit.
const STEP_OUT_TURNS: Array[float] = [0.0, 0.785398, -0.785398, 1.570796, -1.570796, 2.356194, -2.356194]
## Sharing a bore (see SHARING A BORE); demo values.
const BORE_GAP_M: float = 0.15
const PASS_OFFSET_M: float = 0.25
const PASS_WINDOW_M: float = 1.6
const SIDE_STEP_M_S: float = 0.6
const EMERGE_WAIT_S: float = 6.0
const EMERGE_CLEAR_M: float = 0.05
## Waiting in a mouth's line (see QUEUES): give up after this, and shuffle up within this of a place.
const QUEUE_GIVE_UP_S: float = 25.0
const QUEUE_PLACE_M: float = 0.06

const WALK_TURN_RATE: float = 1.75          ## rad/s while walking (~100 deg/s)
const SPOT_TURN_RATE: float = 3.2           ## rad/s turning on the spot (~185 deg/s)
const STOP_TO_TURN_ANGLE: float = 1.31      ## ~75 deg: stop and turn on the spot instead
const START_WALK_ANGLE: float = 0.21        ## ~12 deg: close enough to set off whatever is ahead
const BLEND_WALK_ANGLE: float = 1.05        ## ~60 deg: set off and finish the turn walking, if clear
const BLEND_CLEAR_M: float = 0.7            ## how far ahead must be clear to finish a turn walking
const FACE_DONE_ANGLE: float = 0.035        ## ~2 deg
const SHUFFLE_ANGLE: float = 0.79           ## ~45 deg: a turn this big steps in place
const SHUFFLE_CLIP_SPEED: float = 0.75
const WAYPOINT_REACH_M: float = 0.3
const ARRIVE_RADIUS_M: float = 0.12
const SEPARATION_WEIGHT: float = 1.2
const STUCK_AFTER_S: float = 2.5
const BLOCKED_AFTER_S: float = 0.35         ## held back this long by someone -> plan round them
const BLOCKED_FRACTION: float = 0.3         ## a frame moving less than this share of its step is held back
const STANDING_TOLERANCE_M: float = 0.08    ## how deep a leg may graze someone standing before replanning
const STUCK_PROGRESS_M: float = 0.05
const MAX_REPLANS: int = 4
const MAX_FLIPS: int = 4                    ## walk -> stop-and-turn flips on one leg before replanning
const IDLE_MIN_S: float = 1.2
const IDLE_MAX_S: float = 3.2
const ACT_MIN_S: float = 8.0
const ACT_MAX_S: float = 20.0
## A walker slower than SLOW_WALK_M_S works proportionally longer (up to SLOW_WORK_MAX times), so
## the mole's day is not mostly walking.
const SLOW_WALK_M_S: float = 0.75
const SLOW_WORK_MAX: float = 1.6
const BOUTS_MIN: int = 1
const BOUTS_MAX: int = 3
## A wandering resident works at a POI at least this many times as long as it spent walking and
## turning to get there, adding bouts until it has -- so no one's day is mostly walking, whatever
## its speed or however far its homes lie apart (walking stays under 1 / (1 + WORK_PER_WALK)).
const WORK_PER_WALK: float = 2.0
const RETRY_S: float = 1.5
const CARRY_CHANCE: float = 0.5
## A carry walks at the clip's own (slow) pace -- a squirrel forester covers 0.25 m/s -- so only
## short trips carry; a long one would read as a resident crawling across the village.
const CARRY_MAX_TRIP_M: float = 8.0
const CARRY_WALK_FRACTION: float = 0.5
const CARRY_MIN_RATE: float = 1.0
const CARRY_MAX_RATE: float = 1.6
const DEFAULT_CLIP_S: float = 3.0

var index: int = -1
var position: Vector2 = Vector2.ZERO
var yaw: float = 0.0
var state: State = State.IDLE
var clip: StringName = CLIP_IDLE
var clip_speed: float = 1.0
var walk_speed: float = 0.8
var radius: float = 0.25
var poi: int = -1
var slot: int = -1
var carrying: bool = false
## ORDER_NONE while wandering on its own; ORDER_MOVE / ORDER_WORK while under a player's order.
var order: int = ORDER_NONE
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## This resident's routine (cast_routines.gd): its home POIs and the village's social ones. Empty
## homes means "anywhere, nearer preferred".
var homes: PackedInt32Array = PackedInt32Array()
var socials: PackedInt32Array = PackedInt32Array()
## Per waypoint of `path`: the tunnel leg crossed to reach it, or SURFACE_LEG (see TUNNELS).
var path_tunnel: PackedInt32Array = PackedInt32Array()
## Inside a tunnel, and how far below the ground its feet are (presentation: 0 on the surface).
var underground: bool = false
var ground_y_m: float = 0.0
## The tunnel this resident is ordered to dig, as an EntityRef (slot, generation); null (-1, 0).
var dig_tunnel: int = -1
var dig_generation: int = 0
## The task driving this resident under ORDER_TASK (null otherwise).
var task: TaskScript = null

var _space: CastSpaceScript = null
var _clip_lengths: Dictionary = {}
var _timer: float = 0.0
var _bouts_left: int = 0
var _turn_clip: StringName = CLIP_IDLE
var _turn_clip_speed: float = 1.0
var _clip_time: float = 0.0
var _goal: Vector2 = Vector2.ZERO
var _best_distance: float = INF
var _stuck_time: float = 0.0
var _blocked_time: float = 0.0
var _replans: int = 0
var _flips: int = 0
var _last_activity: StringName = &""
## Seconds spent turning and walking on the current trip, and working since arriving (WORK_PER_WALK).
var _trip_s: float = 0.0
var _worked_s: float = 0.0
## Where an ordered holder turns to face on arrival, when _faces_on_hold (else it keeps facing the
## way it came).
var _hold_face: Vector2 = Vector2.ZERO
var _faces_on_hold: bool = false
var _carry_velocity: PackedVector2Array = PackedVector2Array()
var _carry_key_s: float = 1.0
var _carry_rate: float = 1.0
## Walking a tunnel: which, from where to where along it (metres), and whether toward the dig face.
var _travel_slot: int = 0
var _travel_m: float = 0.0
var _travel_end_m: float = 0.0
var _travel_forward: bool = true
var _travel_to_face: bool = false
## Released while underground: idle once up, rather than going on.
var _idle_on_surface: bool = false
## Inside a bore: how far it has stepped to its right to let someone pass, and how long it has waited
## at the far mouth for the hole to clear.
var _side_m: float = 0.0
var _emerge_waited: float = 0.0
## The carry's own pace (m/s at its playback rate), walked in a bore while carrying.
var _carry_speed: float = 0.0
## Waiting in a line: which mouth (2 x slot + end) and for how long; whether it holds a grant.
var _queue_mouth: int = 0
var _queue_waited: float = 0.0
var _holds_grant: bool = false
var _travel_start_m: float = 0.0
## A task's walk in a bore: at its end the task resumes, still underground.
var _travel_for_task: bool = false


func configure(space: CastSpaceScript, speed_m_s: float, body_radius: float, seed: int, clip_lengths: Dictionary) -> void:
	"""Join `space` as a new resident. `clip_lengths` maps each playable clip to its length in seconds."""
	_space = space
	walk_speed = speed_m_s
	radius = body_radius
	rng.seed = seed
	_clip_lengths = clip_lengths
	index = space.add_resident(position, radius)


func set_carry_motion(motion: Dictionary) -> void:
	"""The carry clip's recorded root motion (clip_root_motion.read). Without it, nobody carries."""
	var keys: Array = motion.get("keys_xz", [])
	var mean := float(motion.get("mean_speed_m_s", 0.0))
	var period := float(motion.get("period_s", 0.0))
	if keys.size() < 2 or mean < ClipRootMotionScript.MIN_SPEED_M_S or period <= 0.0 or not has_clip(CLIP_CARRY):
		return
	_carry_key_s = period / float(keys.size() - 1)
	_carry_velocity.resize(keys.size() - 1)
	for k in keys.size() - 1:
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		_carry_velocity[k] = Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])) / _carry_key_s
	var carry_speed := clampf(walk_speed * CARRY_WALK_FRACTION, mean * CARRY_MIN_RATE, mean * CARRY_MAX_RATE)
	_carry_rate = ClipRootMotionScript.playback_rate(motion, carry_speed)
	_carry_speed = carry_speed


func trip_seconds() -> float:
	"""Seconds spent turning, walking and in tunnels on the current trip (what WORK_PER_WALK weighs)."""
	return _trip_s


func clip_time() -> float:
	"""Seconds of clip played since the current clip began (at its playback speed)."""
	return _clip_time


func can_carry() -> bool:
	"""Whether this resident has a carry clip with recorded root motion."""
	return not _carry_velocity.is_empty()


func has_clip(name: StringName) -> bool:
	"""Whether `name` is one of this resident's clips."""
	return _clip_lengths.has(name)


func start_at(at: Vector2, face_yaw: float, start_poi: int, start_slot: int) -> void:
	"""Stand at `at` facing `face_yaw`, holding `start_poi`'s slot, and idle a staggered moment first."""
	position = at
	yaw = face_yaw
	poi = start_poi
	slot = start_slot
	_space.move_resident(index, at)
	_bouts_left = rng.randi_range(1, 2) if poi >= 0 else 0
	_enter_idle(rng.randf_range(0.2, IDLE_MAX_S))


func step(delta: float) -> void:
	"""Advance this resident by `delta` seconds."""
	_clip_time += delta * clip_speed
	match state:
		State.IDLE:
			_step_idle(delta)
		State.TURN:
			_step_turn(delta)
		State.WALK:
			_step_walk(delta)
		State.FACE:
			_step_face(delta)
		State.ACT:
			_step_act(delta)
		State.HOLD:
			pass
		State.TUNNEL:
			_step_tunnel(delta)
		State.DIG:
			_step_dig(delta)
		State.QUEUE:
			_step_queue(delta)
		State.TASK:
			_step_task(delta)
	if state == State.TURN or state == State.WALK or state == State.TUNNEL:
		_trip_s += delta
	_space.set_walking(index, state == State.WALK)


func forward() -> Vector2:
	"""The unit direction this resident faces, in (x, z)."""
	return Vector2(sin(yaw), cos(yaw))


static func yaw_of(direction: Vector2) -> float:
	"""The yaw that faces `direction` (x, z)."""
	return atan2(direction.x, direction.y)


static func turn_toward(from_yaw: float, to_yaw: float, max_step: float) -> float:
	"""`from_yaw` turned the short way toward `to_yaw` by at most `max_step` radians."""
	return from_yaw + clampf(angle_difference(from_yaw, to_yaw), -max_step, max_step)


# --- states ---------------------------------------------------------------------------------

func _set_clip(name: StringName, speed: float) -> void:
	"""Ask for a clip; its clock restarts only when the clip itself changes."""
	if name != clip:
		_clip_time = 0.0
	clip = name
	clip_speed = speed


func _enter_idle(seconds: float) -> void:
	"""Stand and idle for `seconds`."""
	state = State.IDLE
	_timer = seconds
	_set_clip(CLIP_IDLE, 1.0)


func _step_idle(delta: float) -> void:
	"""Idle out the timer, then either another activity bout here or a trip elsewhere."""
	_timer -= delta
	if _timer > 0.0:
		return
	if poi >= 0 and (_bouts_left > 0 or order == ORDER_WORK or owes_work()):
		_bouts_left = maxi(_bouts_left, 1)
		_enter_act()
	elif order != ORDER_NONE:
		_enter_hold()
	else:
		_depart()


func _enter_act() -> void:
	"""Play one of this POI's activities for a whole number of its loops, about ACT_MIN..MAX seconds."""
	state = State.ACT
	_bouts_left -= 1
	var activity := _pick_activity(_last_activity)
	_last_activity = activity
	var length := float(_clip_lengths.get(activity, DEFAULT_CLIP_S))
	var seconds := rng.randf_range(ACT_MIN_S, ACT_MAX_S) * clampf(SLOW_WALK_M_S / walk_speed, 1.0, SLOW_WORK_MAX)
	var loops := maxi(1, roundi(seconds / maxf(length, 0.1)))
	_timer = length * loops
	_set_clip(activity, 1.0)


func owes_work() -> bool:
	"""Whether a wandering resident has not yet worked WORK_PER_WALK times its last trip here."""
	return order == ORDER_NONE and _worked_s < WORK_PER_WALK * _trip_s


func _pick_activity(last: StringName) -> StringName:
	"""A random one of the POI's activities this resident can play -- a different one from `last` when
	there is a choice, so bouts cycle -- else idle."""
	var activities := _space.poi_activities[poi]
	var playable := 0
	for activity in activities:
		if has_clip(activity) and activity != last:
			playable += 1
	if playable == 0:
		return last if has_clip(last) and activities.has(last) else CLIP_IDLE
	var pick := rng.randi_range(0, playable - 1)
	for activity in activities:
		if has_clip(activity) and activity != last:
			if pick == 0:
				return activity
			pick -= 1
	return CLIP_IDLE


func _step_act(delta: float) -> void:
	"""Hold the activity until its loops are done, then idle between bouts."""
	_timer -= delta
	_worked_s += delta
	if _timer <= 0.0:
		_enter_idle(rng.randf_range(IDLE_MIN_S, IDLE_MAX_S))


func _depart() -> void:
	"""Pick the next POI with room, plan the route, swap reservations and start turning toward it. When
	no route exists -- someone standing across the only way out of a tight slot -- it stays put and
	tries again after RETRY_S, rather than walking the planner's straight-line fallback into a wall."""
	var next := _choose_next()
	if next < 0:
		_enter_idle(RETRY_S)
		return
	var next_slot := _space.free_slot(next)
	_space.plan_path(index, position, _space.slot_position(next, next_slot), radius, path, path_tunnel)
	if not _space.nav.last_found:
		_enter_idle(RETRY_S)  # boxed in by residents standing across every way out: wait, then retry
		return
	_space.reserve(next, next_slot)
	var leaving_stockpile := poi >= 0 and _space.poi_stockpile[poi] == 1
	_space.release(poi, slot)
	poi = next
	slot = next_slot
	_goal = _space.slot_position(next, next_slot)
	carrying = leaving_stockpile and can_carry() and _surface_length() <= CARRY_MAX_TRIP_M \
			and rng.randf() < CARRY_CHANCE
	if carrying and crosses_tunnel():
		_plan_loaded(CARRY_MAX_TRIP_M)
	_replans = 0
	_trip_s = 0.0
	_begin_leg()


func _plan_loaded(max_surface_m: float) -> void:
	"""A carrier's trip crossing a tunnel: plan it again with the load, so only bores that fit the
	load are taken (see HAULING). With no loaded route, or more than `max_surface_m` of it on the
	surface, it goes unloaded on the first plan. (The routine's carries and the farm's ordered carries
	both come through here: one hauling rule.)"""
	var legs := path_tunnel.duplicate()
	var route := path.duplicate()
	_space.plan_path(index, position, _goal, radius, path, path_tunnel, true, true)
	if _space.nav.last_found and _surface_length() <= max_surface_m:
		return
	carrying = false
	path = route
	path_tunnel = legs


func _choose_next() -> int:
	"""The next POI: usually one of the homes, sometimes a social spot, nearer ones preferred."""
	if homes.is_empty():
		return _space.choose_poi_from(homes, poi, position, rng)
	var social := not socials.is_empty() and rng.randf() < CastRoutinesScript.SOCIAL_CHANCE
	var next := _space.choose_poi_from(socials if social else homes, poi, position, rng)
	if next < 0:
		next = _space.choose_poi_from(homes if social else socials, poi, position, rng)
	return next if next >= 0 else _space.choose_poi_from(PackedInt32Array(), poi, position, rng)


func _trip_length() -> float:
	"""Length of the planned route from here."""
	var total := 0.0
	var at := position
	for point in path:
		total += at.distance_to(point)
		at = point
	return total


func _surface_length() -> float:
	"""Length of the planned route from here that lies on the surface (tunnel legs excluded)."""
	var total := 0.0
	var at := position
	for k in path.size():
		if _leg(k) == TunnelRouterScript.SURFACE_LEG:
			total += at.distance_to(path[k])
		at = path[k]
	return total


func _begin_leg() -> void:
	"""Start following `path` from its first waypoint: turn on the spot first -- or, standing at a
	tunnel's mouth already, go straight down it."""
	_leave_line()
	path_index = 0
	_flips = 0
	_reset_progress()
	while path_index < path.size() - 1 and _leg(path_index + 1) != TunnelRouterScript.SURFACE_LEG \
			and position.distance_to(path[path_index]) < WAYPOINT_REACH_M:
		path_index += 1
	if _leg(path_index) != TunnelRouterScript.SURFACE_LEG:
		_enter_tunnel_leg()
		return
	_enter_turn(yaw_of(path[path_index] - position), _locomotion_clip())


func _locomotion_clip() -> StringName:
	"""The clip this trip walks with."""
	return CLIP_CARRY if carrying else CLIP_WALK


func _enter_turn(target_yaw: float, shuffle_clip: StringName) -> void:
	"""Turn on the spot; a big turn steps in place with `shuffle_clip`, a small one stands idle."""
	state = State.TURN
	var big := absf(angle_difference(yaw, target_yaw)) > SHUFFLE_ANGLE
	_turn_clip = shuffle_clip if big else CLIP_IDLE
	_turn_clip_speed = SHUFFLE_CLIP_SPEED if big else 1.0
	if shuffle_clip == CLIP_CARRY and big:
		_turn_clip_speed = SHUFFLE_CLIP_SPEED * _carry_rate
	_set_clip(_turn_clip, _turn_clip_speed)


func _step_turn(delta: float) -> void:
	"""Turn toward the current waypoint; set off once facing it. Time spent turning counts toward
	being stuck, so a walker flipping between walking and turning cannot stall for ever."""
	_stuck_time += delta
	if _stuck_time >= STUCK_AFTER_S:
		_replan_or_abandon()
		return
	var target_yaw := yaw_of(path[path_index] - position)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	var error := absf(angle_difference(yaw, target_yaw))
	if error <= START_WALK_ANGLE or (error <= BLEND_WALK_ANGLE and _clear_ahead()):
		state = State.WALK
		_set_clip(_locomotion_clip(), _walk_clip_speed())


func _face_hold(delta: float) -> void:
	"""An ordered holder turning to face its point, then holding."""
	var target_yaw := yaw_of(_hold_face - position)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, target_yaw)) <= FACE_DONE_ANGLE:
		_enter_hold()


func _clear_ahead() -> bool:
	"""Whether the next BLEND_CLEAR_M straight ahead is clear of obstacles and standing residents."""
	return _space.line_clear(index, position, position + forward() * BLEND_CLEAR_M, radius, _goal)


func _step_face(delta: float) -> void:
	"""Turn to the POI's face direction, then start working -- or, holding, toward _hold_face."""
	if poi < 0:
		_face_hold(delta)
		return
	var face := _space.poi_face[poi]
	if face == Vector2.ZERO:
		_enter_act()
		return
	var target_yaw := yaw_of(face)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, target_yaw)) <= FACE_DONE_ANGLE:
		_enter_act()


# --- walking --------------------------------------------------------------------------------

func _step_walk(delta: float) -> void:
	"""Steer toward the route (and away from neighbours) at a limited yaw rate, and step forward. Someone
	who has stopped in the way of the current leg means a new plan round them, straight away."""
	if _leg_handled():
		return
	var to_target := path[path_index] - position
	var distance := to_target.length()
	var step := ground_step(delta)
	if path_index == path.size() - 1 and distance <= maxf(ARRIVE_RADIUS_M, step.length()):
		_arrive()
		return
	var facing := forward()
	var desired := to_target / maxf(distance, 1e-6) \
			+ _space.separation(index, position, facing) * SEPARATION_WEIGHT
	var error := angle_difference(yaw, yaw_of(desired))
	if absf(error) > STOP_TO_TURN_ANGLE:
		_flips += 1
		if _flips > MAX_FLIPS:
			_replan_or_abandon()
		else:
			_enter_turn(yaw_of(desired), _locomotion_clip())
		return
	yaw = turn_toward(yaw, yaw + error, WALK_TURN_RATE * delta)
	clip_speed = _walk_clip_speed()
	var moved := _space.constrain(index, position, position + step, _goal)
	var held := moved.distance_to(position) < step.length() * BLOCKED_FRACTION
	position = moved
	_space.move_resident(index, moved)
	_watch_progress(distance, held, delta)


func _leg_handled() -> bool:
	"""Pass the waypoints reached; then at a tunnel's mouth go down it, or with someone standing across
	the leg plan round them. True when either happened, so this frame's walking is done."""
	_advance_waypoint()
	if _leg(path_index) != TunnelRouterScript.SURFACE_LEG:
		_enter_tunnel_leg()
		return true
	if _nearing_mouth() and _wait_for_mouth():
		return true
	if _blocked_by_standing(path[path_index]):
		_replan_or_abandon()
		return true
	return false


func _advance_waypoint() -> void:
	"""Move on past a waypoint as soon as the one after it is in clear sight, or once near it -- but not
	while near would start the next leg through someone standing (the plan's leg began at the
	waypoint itself; cutting the corner could clip them and trigger a needless replan). A tunnel's
	mouth is never cut: it is passed only on reaching it, and nothing past it is skipped to."""
	while path_index < path.size() - 1 and _leg(path_index) == TunnelRouterScript.SURFACE_LEG:
		var next := path[path_index + 1]
		var d := position.distance_to(path[path_index])
		if _leg(path_index + 1) != TunnelRouterScript.SURFACE_LEG:
			if d < WAYPOINT_REACH_M:
				path_index += 1
				_reset_progress()
			return
		var near := d < ARRIVE_RADIUS_M or (d < WAYPOINT_REACH_M and not _blocked_by_standing(next))
		if near or _space.line_clear(index, position, next, radius, _goal):
			path_index += 1
			_reset_progress()
		else:
			return


func _blocked_by_standing(to: Vector2) -> bool:
	"""Whether someone standing still is plainly in the way from here to `to`: their radius plus ours,
	less STANDING_TOLERANCE_M, so a leg the plan passed (at a wider margin) never trips it."""
	return _space.standing_blocks(index, position, to, radius, _goal, -STANDING_TOLERANCE_M)


# --- queues at mouths -----------------------------------------------------------------------

func _leave_line() -> void:
	"""Out of any mouth's line, and any grant given up (a new plan or order starts afresh)."""
	if _holds_grant or state == State.QUEUE:
		_space.tunnels.queue.leave(index)
	_holds_grant = false


func _nearing_mouth() -> bool:
	"""Whether the waypoint ahead is a mouth this walk goes down, within JOIN_M, without its grant."""
	if path_index >= path.size() - 1 or _leg(path_index + 1) == TunnelRouterScript.SURFACE_LEG:
		return false
	return not _holds_grant and position.distance_to(path[path_index]) < TunnelQueueScript.JOIN_M


func _mouth_clear(mouth: int) -> bool:
	"""Whether mouth `mouth` (2 x slot + end) is clear for this resident to step into."""
	return _space.mouth_clear(index, mouth >> 1, mouth & 1 == 1, TunnelQueueScript.HOLD_M)


func _wait_for_mouth() -> bool:
	"""At a mouth ahead: take its grant and walk on, or join its line (true: this frame is spent
	waiting). A full line sends the walker the long way round, on the surface."""
	var mouth := _leg(path_index + 1)
	var queue := _space.tunnels.queue
	if queue.may_take(mouth, index, _mouth_clear(mouth)):
		queue.take(mouth, index)
		_holds_grant = true
		return false
	if not queue.join(mouth, index):
		_space.plan_path(index, position, _goal, radius, path, path_tunnel, false, carrying)
		_begin_leg()
		return true
	state = State.QUEUE
	_queue_mouth = mouth
	_queue_waited = 0.0
	return true


func _step_queue(delta: float) -> void:
	"""Wait in a mouth's line: shuffle to its place, facing the hole; walk on holding the grant once at
	the head and the mouth is clear; give up after QUEUE_GIVE_UP_S and walk instead."""
	var queue := _space.tunnels.queue
	_queue_waited += delta
	if queue.may_take(_queue_mouth, index, _mouth_clear(_queue_mouth)):
		queue.take(_queue_mouth, index)
		_holds_grant = true
		state = State.WALK
		_reset_progress()
		_set_clip(_locomotion_clip(), _walk_clip_speed())
		return
	if _queue_waited >= QUEUE_GIVE_UP_S or not queue.is_queued(_queue_mouth, index):
		queue.leave(index)
		_space.plan_path(index, position, _goal, radius, path, path_tunnel, false, carrying)
		_begin_leg()
		return
	_shuffle_to(queue.place(_queue_mouth, queue.position_of(_queue_mouth, index)), delta)


func _shuffle_to(place: Vector2, delta: float) -> void:
	"""Step toward a place in a line (never through anyone); there, stand facing the mouth."""
	var to := place - position
	if to.length() <= QUEUE_PLACE_M:
		_set_clip(CLIP_CARRY if carrying else CLIP_IDLE, 0.0 if carrying else 1.0)
		yaw = turn_toward(yaw, yaw_of(path[path_index] - position), SPOT_TURN_RATE * delta)
		return
	yaw = turn_toward(yaw, yaw_of(to), SPOT_TURN_RATE * delta)
	_set_clip(_locomotion_clip(), _walk_clip_speed())
	var step := to.limit_length(walk_speed * _surface_factor() * delta)
	position = _space.constrain(index, position, position + step, place)
	_space.move_resident(index, position)


func ground_step(delta: float) -> Vector2:
	"""This frame's step on the ground: straight ahead at walk speed, or while carrying the clip's own
	recorded root velocity at this key (sideways weave included), sped up by the playback rate."""
	var surface := _surface_factor()
	if not carrying:
		return forward() * (walk_speed * delta * surface)
	var length := float(_clip_lengths.get(CLIP_CARRY, DEFAULT_CLIP_S))
	var key := mini(int(fposmod(_clip_time, length) / _carry_key_s), _carry_velocity.size() - 1)
	var local := _carry_velocity[key] * (_carry_rate * delta * surface)
	return Vector2(cos(yaw), -sin(yaw)) * local.x + forward() * local.y


func _surface_factor() -> float:
	"""The weather's surface walking speed as a fraction of walk speed (see WEATHER AND LANTERNS)."""
	return float(_space.tunnels.surface_permille) / float(TunnelRules.PERMILLE)


func _walk_clip_speed() -> float:
	"""The walking (or carrying) clip's playback speed on the surface, slowed with the weather."""
	return (_carry_rate if carrying else 1.0) * _surface_factor()


func _arrive() -> void:
	"""At the slot: turn to the POI's face direction, and plan one or two bouts of work. At an ordered
	point with no POI, hold instead, facing the way it came. At a dig site, start digging."""
	carrying = false
	if order == ORDER_TASK:
		state = State.TASK
		task.arrived(self)
		return
	if order == ORDER_DIG:
		_begin_dig()
		return
	if poi < 0:
		_hold_here()
		return
	_bouts_left = rng.randi_range(BOUTS_MIN, BOUTS_MAX)
	_last_activity = &""
	_worked_s = 0.0
	var face := _space.poi_face[poi]
	_enter_turn(yaw_of(face) if face != Vector2.ZERO else yaw, CLIP_WALK)
	state = State.FACE  # _enter_turn chose the clip; this turn ends in work, not a walk


func _reset_progress() -> void:
	"""Start measuring progress toward a new waypoint."""
	_best_distance = INF
	_stuck_time = 0.0
	_blocked_time = 0.0


func _watch_progress(distance: float, held: bool, delta: float) -> void:
	"""Replan when held back by someone for BLOCKED_AFTER_S, or when no progress is made for
	STUCK_AFTER_S; give the trip up after MAX_REPLANS."""
	_blocked_time = _blocked_time + delta if held else 0.0
	if distance < _best_distance - STUCK_PROGRESS_M:
		_best_distance = distance
		_stuck_time = 0.0
	else:
		_stuck_time += delta
	if _stuck_time < STUCK_AFTER_S and _blocked_time < BLOCKED_AFTER_S:
		return
	_replan_or_abandon()


func _replan_or_abandon() -> void:
	"""Plan the trip again from here, or give it up after MAX_REPLANS."""
	_replans += 1
	if _replans > MAX_REPLANS:
		_abandon_trip()
		return
	_space.plan_path(index, position, _goal, radius, path, path_tunnel, true, carrying)
	_begin_leg()


func _abandon_trip() -> void:
	"""Give the slot back and stand a moment before choosing somewhere else -- or, under an order,
	hold right here. A dig it could not walk to is left paused as a plan (tunnel_network
	.hold_unreached), never deleted."""
	_leave_dig(true)
	_leave_line()
	if order == ORDER_TASK:
		_drop_task()
	_space.release(poi, slot)
	poi = -1
	slot = -1
	carrying = false
	if order != ORDER_NONE:
		order = ORDER_MOVE
		_hold_here()
	else:
		_enter_idle(RETRY_S)


# --- orders ---------------------------------------------------------------------------------

func order_move(goal: Vector2, face_toward: Vector2 = Vector2.INF) -> void:
	"""Give up any POI slot, walk to `goal` and hold there until ordered again or released. Given a
	finite `face_toward`, it turns to face that point on arrival (a queue facing its POI)."""
	release_slot()
	_leave_dig()
	_drop_task()
	order = ORDER_MOVE
	_faces_on_hold = face_toward.is_finite()
	_hold_face = face_toward if _faces_on_hold else Vector2.ZERO
	_start_ordered_trip(goal)


func order_work(work_poi: int, work_slot: int) -> void:
	"""Walk to `work_slot` at `work_poi` and work there until released. The caller has checked the
	slot is free (or is this resident's own); any other slot held is given up first."""
	_leave_dig()
	_drop_task()
	if work_poi != poi or work_slot != slot:
		release_slot()
		_space.reserve(work_poi, work_slot)
		poi = work_poi
		slot = work_slot
	order = ORDER_WORK
	_start_ordered_trip(_space.slot_position(work_poi, work_slot))


func release_slot() -> void:
	"""Give back any POI slot this resident holds."""
	_space.release(poi, slot)
	poi = -1
	slot = -1


func release() -> void:
	"""Back to wandering. Holding or walking under a move order, it stops and idles a moment first;
	working under an order, it finishes the bout in hand."""
	if order == ORDER_NONE:
		return
	var was_move := order == ORDER_MOVE or state == State.HOLD or order == ORDER_TASK
	_drop_task()
	_leave_line()
	order = ORDER_NONE
	_leave_dig()
	if underground:
		_release_underground(was_move)
		return
	if was_move or poi < 0:
		release_slot()
		carrying = false
		_bouts_left = 0
		_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))
	else:
		_bouts_left = mini(_bouts_left, 1)
		_trip_s = 0.0


func _release_underground(was_move: bool) -> void:
	"""Released inside a tunnel. From a move (or with no POI) it comes up at the far mouth and idles
	there; from a work order it keeps its slot and carries on to the POI, as on the surface, and
	works the bout in hand."""
	if was_move or poi < 0:
		release_slot()
		_idle_on_surface = true
		_finish_tunnel_then_stop()
		return
	_bouts_left = mini(_bouts_left, 1)
	_trip_s = 0.0


func _start_ordered_trip(goal: Vector2) -> void:
	"""Plan to `goal` and set off (turning first); an order never carries. Underground, it finishes
	the tunnel first and plans from the mouth it comes up at. A new order overrides an earlier
	release's idling on the surface."""
	_idle_on_surface = false
	_leave_line()
	carrying = false
	_bouts_left = 0
	_goal = goal
	_replans = 0
	if underground:
		_finish_tunnel_then_stop()
		return
	if position.distance_to(goal) <= ARRIVE_RADIUS_M:
		_arrive()
		return
	_space.plan_path(index, position, _goal, radius, path, path_tunnel)
	_begin_leg()


func _hold_here() -> void:
	"""Hold where it stands -- after turning to face _hold_face, when the order gave one."""
	if _faces_on_hold and _hold_face.distance_to(position) > 0.05:
		_enter_turn(yaw_of(_hold_face - position), CLIP_WALK)
		state = State.FACE
	else:
		_enter_hold()


func _enter_hold() -> void:
	"""Stand still, idling, facing the way it came; only an order or release moves it on."""
	state = State.HOLD
	carrying = false
	_set_clip(CLIP_IDLE, 1.0)


# --- farm tasks (demo/farm/) ------------------------------------------------------------------

func order_carry(goal: Vector2, face_toward: Vector2 = Vector2.INF) -> void:
	"""order_move(), walking with the carry clip when this resident has one -- the farm's harvest to
	the store, and water or spoil to a bed. A route through a tunnel is planned again LOADED (HAULING:
	the routine's own rule, `_plan_loaded`), so the load goes below only through a bore it fits, and
	on the surface otherwise. Arriving drops the load."""
	order_move(goal, face_toward)
	carrying = can_carry() and not underground and (state == State.TURN or state == State.WALK)
	if carrying and crosses_tunnel():
		_plan_loaded(INF)
		_begin_leg()


func play_in_place(name: StringName) -> bool:
	"""While holding, play clip `name` where it stands (the farm's work at a bed, well or heap) --
	task_play()'s clip rule. False, changing nothing, when it is not holding."""
	if state != State.HOLD:
		return false
	task_play(name)
	return true


func activity() -> int:
	"""ACTIVITY_*: digging, in a tunnel, holding, wandering on its own, walking under an order, or
	working under one."""
	if order == ORDER_TASK:
		return ACTIVITY_TASK
	if state == State.QUEUE:
		return ACTIVITY_QUEUE
	if state == State.DIG or (state == State.TUNNEL and _travel_to_face):
		return ACTIVITY_DIGGING
	if state == State.TUNNEL:
		return ACTIVITY_TUNNEL
	if state == State.HOLD or (order == ORDER_MOVE and state == State.FACE):
		return ACTIVITY_HOLDING
	if order == ORDER_NONE:
		return ACTIVITY_WANDERING
	if state == State.WALK or state == State.TURN:
		return ACTIVITY_WALKING
	return ACTIVITY_WORKING


func goal() -> Vector2:
	"""Where the current trip is going (meaningful while walking or turning)."""
	return _goal


func surface_point() -> Vector2:
	"""Where this resident stands on the surface -- or, underground, the mouth it will come up at."""
	if not underground:
		return position
	if state == State.DIG or _travel_to_face:
		return _space.tunnels.mouth(dig_tunnel, false)
	if order == ORDER_TASK:
		return _space.tunnels.point_at(_travel_slot, _nearest_end_m(_travel_slot, _travel_m))
	return _space.tunnels.point_at(_travel_slot, _travel_end_m)


func crosses_tunnel() -> bool:
	"""Whether the current route goes through a tunnel."""
	return path_tunnel.count(TunnelRouterScript.SURFACE_LEG) != path_tunnel.size()


# --- tunnels --------------------------------------------------------------------------------

func _leg(k: int) -> int:
	"""The leg code into waypoint `k`: SURFACE_LEG, or the tunnel crossed to reach it."""
	return path_tunnel[k] if k < path_tunnel.size() else TunnelRouterScript.SURFACE_LEG


func _set_underground(below: bool) -> void:
	"""Go below the surface, or come back up onto it."""
	underground = below
	_space.set_underground(index, below)
	if not below:
		ground_y_m = 0.0


func _enter_tunnel_leg() -> void:
	"""At a mouth: go down and cross the tunnel the leg into path[path_index] names."""
	var code := path_tunnel[path_index]
	var slot_index := TunnelRouterScript.leg_slot(code)
	var length := _space.tunnels.length_m(slot_index)
	_space.tunnels.queue.take(code, index)
	_holds_grant = true
	if TunnelRouterScript.leg_reversed(code):
		_start_travel(slot_index, length, 0.0)
	else:
		_start_travel(slot_index, 0.0, length)


func _start_travel(slot_index: int, from_m: float, to_m: float) -> void:
	"""Walk tunnel `slot_index` underground from `from_m` to `to_m` metres along it."""
	_travel_slot = slot_index
	_travel_m = from_m
	_travel_start_m = from_m
	_travel_end_m = to_m
	_travel_forward = to_m >= from_m
	_side_m = 0.0
	_emerge_waited = 0.0
	state = State.TUNNEL
	_set_underground(true)
	_set_clip(CLIP_CARRY if carrying else CLIP_WALK, _carry_rate if carrying else 1.0)
	_place_in_tunnel()


func _step_tunnel(delta: float) -> void:
	"""Walk on along the tunnel at walk speed, keeping its distance from anyone ahead and stepping
	aside for anyone coming (see SHARING A BORE); at the end, come up once the hole is clear (or reach
	the dig face)."""
	var step := minf(_bore_speed() * delta, _space.room_ahead(index, BORE_GAP_M))
	_travel_m = move_toward(_travel_m, _travel_end_m, step)
	var side_target := PASS_OFFSET_M if _space.oncoming(index, PASS_WINDOW_M) else 0.0
	_side_m = move_toward(_side_m, side_target, SIDE_STEP_M_S * delta)
	_place_in_tunnel()
	if _holds_grant and absf(_travel_m - _travel_start_m) > TunnelQueueScript.HOLD_M:
		_space.tunnels.queue.release_grant(index)
		_holds_grant = false
	if _travel_m != _travel_end_m:
		return
	if not _travel_to_face and not _travel_for_task and _emerge_blocked():
		_emerge_waited += delta
		return
	_end_travel()


func _bore_speed() -> float:
	"""Walking speed in the bore being walked: the carry's own pace with a load, else walk speed, times
	the bore's speed (faster when lit; see WEATHER AND LANTERNS)."""
	var base := _carry_speed if carrying and _carry_speed > 0.0 else walk_speed
	return base * float(_space.tunnels.speed_permille(_travel_slot)) / float(TunnelRules.PERMILLE)


func _emerge_blocked() -> bool:
	"""Whether someone on the surface stands on the mouth this walk comes up at, and the wait for them
	(EMERGE_WAIT_S) is not yet over."""
	return _emerge_waited < EMERGE_WAIT_S \
			and _space.surface_occupied(index, _space.tunnels.point_at(_travel_slot, _travel_end_m), EMERGE_CLEAR_M)


func _place_in_tunnel() -> void:
	"""Stand on the bore floor at the current distance along the tunnel, facing the way it walks,
	stepped `_side_m` to its right; and record its place in the bore."""
	var tunnels := _space.tunnels
	var ahead := tunnels.direction_at(_travel_slot, _travel_m)
	var facing := ahead if _travel_forward else -ahead
	position = tunnels.point_at(_travel_slot, _travel_m) + Vector2(-facing.y, facing.x) * _side_m
	yaw = yaw_of(facing)
	ground_y_m = tunnels.floor_y_at(_travel_slot, _travel_m)
	_space.move_resident(index, position)
	_space.set_in_bore(index, _travel_slot, _travel_m, 1 if _travel_forward else -1)


func _end_travel() -> void:
	"""At the end of a tunnel walk: start digging at the face, or come up and go on (idle, arrive
	or replan when the route ended at the mouth)."""
	if _holds_grant:
		_space.tunnels.queue.release_grant(index)
		_holds_grant = false
	if _travel_to_face:
		_travel_to_face = false
		_enter_dig_state()
		return
	if _travel_for_task:
		_travel_for_task = false
		state = State.TASK
		return
	_set_underground(false)
	if _idle_on_surface:
		_idle_on_surface = false
		_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))
		return
	if path_index < path.size() - 1:
		path_index += 1
		_flips = 0
		_reset_progress()
		_enter_turn(yaw_of(path[path_index] - position), _locomotion_clip())
	elif position.distance_to(_goal) <= ARRIVE_RADIUS_M:
		_arrive()
	else:
		_space.plan_path(index, position, _goal, radius, path, path_tunnel, true, carrying)
		_begin_leg()


func turn_back(slot_index: int, to_m: float) -> void:
	"""The tunnel this resident is walking has closed ahead (tunnel_hazards.gd): walk to `to_m` along
	it instead -- a mouth on its side -- come up there and plan the trip again, round the closure (the
	route is cut at this leg, so the walk ends at the mouth). Anyone not walking that tunnel is left
	alone."""
	if state != State.TUNNEL or _travel_slot != slot_index or _travel_for_task or _travel_to_face:
		return
	_travel_end_m = to_m
	_travel_forward = to_m >= _travel_m
	path.resize(path_index + 1)
	path_tunnel.resize(path_index + 1)


func is_in_bore(slot_index: int) -> bool:
	"""Whether this resident is walking or standing in tunnel `slot_index`'s bore."""
	return underground and _space.resident_tunnel[index] == slot_index


func bore_along_m() -> float:
	"""How far along the bore it is in (meaningful underground)."""
	return _travel_m


func _finish_tunnel_then_stop() -> void:
	"""Underground under a new order: keep walking to the far mouth (the route ends there), then
	plan the order from it. Committed progress is never undone mid-tunnel (MOVE-REQ-007)."""
	path.resize(path_index + 1)
	path_tunnel.resize(path_index + 1)


# --- digging --------------------------------------------------------------------------------

func order_dig(tunnel_slot: int, tunnel_generation: int) -> void:
	"""Walk to tunnel (slot, generation)'s entrance and dig until it opens, then hold at its exit.
	The caller has added (or resumed) the tunnel with this resident as its digger."""
	release_slot()
	_leave_dig()
	_drop_task()
	dig_tunnel = tunnel_slot
	dig_generation = tunnel_generation
	order = ORDER_DIG
	_faces_on_hold = false
	_start_ordered_trip(_space.tunnels.mouth(tunnel_slot, false))


func dig_clip() -> StringName:
	"""The clip digging plays: the first of DIG_CLIPS this creature has, else idle."""
	for name in DIG_CLIPS:
		if has_clip(name):
			return name
	return CLIP_IDLE


func _begin_dig() -> void:
	"""At the entrance: dig the entrance shaft here, or -- a paused tunnel resumed -- walk down to its
	face first. A tunnel that no longer exists leaves the mole holding."""
	var tunnels := _space.tunnels
	if not tunnels.is_ref(dig_tunnel, dig_generation):
		_forget_dig()
		order = ORDER_MOVE
		_enter_hold()
		return
	yaw = yaw_of(tunnels.direction_at(dig_tunnel, 0.0))
	if tunnels.stage(dig_tunnel) == TunnelRules.STAGE_ENTRANCE:
		_enter_dig_state()
		return
	_travel_to_face = true
	_start_travel(dig_tunnel, 0.0, tunnels.face_m(dig_tunnel))


func _enter_dig_state() -> void:
	"""Dig, playing the dig clip."""
	state = State.DIG
	_set_clip(dig_clip(), 1.0)


func _step_dig(delta: float) -> void:
	"""Work the tunnel's clock; follow its face underground once the entrance shaft is through; come
	up at the exit when it opens."""
	var tunnels := _space.tunnels
	tunnels.advance(dig_tunnel, dig_generation, roundi(delta * float(TunnelRules.USEC_PER_SECOND)))
	if tunnels.is_open(dig_tunnel):
		_finish_dig()
		return
	if tunnels.stage(dig_tunnel) == TunnelRules.STAGE_ENTRANCE:
		return
	if not underground:
		_set_underground(true)
	var face := tunnels.face_m(dig_tunnel)
	position = tunnels.point_at(dig_tunnel, face)
	yaw = yaw_of(tunnels.direction_at(dig_tunnel, face))
	ground_y_m = tunnels.floor_y_at(dig_tunnel, face)
	_space.move_resident(index, position)


func _finish_dig() -> void:
	"""The tunnel is open: come up at the exit facing on out of it, step clear of the hole (where the
	ground allows) and hold there."""
	var tunnels := _space.tunnels
	var outward := tunnels.direction_at(dig_tunnel, tunnels.length_m(dig_tunnel))
	position = tunnels.mouth(dig_tunnel, true)
	yaw = yaw_of(outward)
	_forget_dig()
	_set_underground(false)
	_space.move_resident(index, position)
	for turn in STEP_OUT_TURNS:
		var clear := position + outward.rotated(turn) * STEP_OUT_M
		if step_out_ok(clear):
			order_move(clear)
			return
	order = ORDER_MOVE
	_faces_on_hold = false
	_enter_hold()


func step_out_ok(at: Vector2) -> bool:
	"""Whether a mole up out of an exit may step to `at`: inside the village by its radius, clear of
	every obstacle by STEP_OUT_CLEAR_M, off every tunnel's hole and nobody standing there."""
	if not _space.bounds.grow(-radius).has_point(at):
		return false
	if _space.obstacle_clearance(at) < radius + STEP_OUT_CLEAR_M:
		return false
	if _space.on_mouth(at, radius):
		return false
	return not _space.surface_occupied(index, at, STEP_OUT_CLEAR_M)


func _forget_dig() -> void:
	"""Hold no dig reference: the null EntityRef (-1, 0)."""
	dig_tunnel = -1
	dig_generation = 0


func _leave_dig(unreached: bool = false) -> void:
	"""Stop digging, if it was: the tunnel is paused with its progress (or dropped, if nothing was
	dug) -- or, `unreached`, kept paused as it stands. Underground, the mole backs out through what
	it dug to the entrance."""
	if dig_tunnel < 0:
		return
	var slot_index := dig_tunnel
	if unreached:
		_space.tunnels.hold_unreached(slot_index, dig_generation)
	else:
		_space.tunnels.stop_digging(slot_index, dig_generation)
	_forget_dig()
	if state == State.DIG and underground:
		_back_out(slot_index, _space.tunnels.face_m(slot_index))
	elif state == State.TUNNEL and _travel_to_face:
		_back_out(slot_index, _travel_m)


func _back_out(slot_index: int, from_m: float) -> void:
	"""Walk back from `from_m` along tunnel `slot_index` to its entrance: a one-waypoint route whose
	only leg is that tunnel, reversed."""
	_travel_to_face = false
	path.resize(1)
	path[0] = _space.tunnels.mouth(slot_index, false)
	path_tunnel.resize(1)
	path_tunnel[0] = TunnelRouterScript.leg_code(slot_index, true)
	path_index = 0
	_start_travel(slot_index, from_m, 0.0)


# --- tasks ----------------------------------------------------------------------------------

func order_task(new_task: TaskScript) -> void:
	"""Hand this resident to `new_task` (see TASKS): give up any slot, dig, line or earlier task, walk
	to the task's site and let it drive from there."""
	release_slot()
	_leave_dig()
	_drop_task()
	task = new_task
	order = ORDER_TASK
	_faces_on_hold = false
	_start_ordered_trip(new_task.site(self))


func task_label() -> String:
	"""What the task driving this resident is doing, in words ("" with none)."""
	return task.label() if task != null else ""


func _step_task(delta: float) -> void:
	"""Let the task drive; when it is done, go back to the routine."""
	if task == null or not task.step(self, delta):
		_finish_task()


func _finish_task() -> void:
	"""The task is over: back to wandering -- from the nearest mouth, when it ended underground."""
	var done_task := task
	task = null
	order = ORDER_NONE
	if done_task != null:
		done_task.finish(self)
	if underground:
		_idle_on_surface = true
		_walk_out()
	else:
		_enter_idle(rng.randf_range(IDLE_MIN_S * 0.5, IDLE_MIN_S))


func _drop_task() -> void:
	"""Another order or a release takes this resident from its task: the task is told, and one standing
	in a bore walks out to the nearest mouth first."""
	if task == null:
		return
	var dropped := task
	task = null
	_travel_for_task = false
	dropped.cancel(self)
	if underground:
		_walk_out()


func _nearest_end_m(slot_index: int, along_m: float) -> float:
	"""The distance along tunnel `slot_index` of the mouth nearest `along_m`."""
	var length := _space.tunnels.length_m(slot_index)
	return 0.0 if along_m <= length * 0.5 else length


func _walk_out() -> void:
	"""Walk from where it stands in its bore to the nearest mouth: a one-waypoint route whose only leg
	is that stretch of tunnel."""
	var slot_index := _space.resident_tunnel[index]
	var to_m := _nearest_end_m(slot_index, _travel_m)
	_travel_to_face = false
	_travel_for_task = false
	path.resize(1)
	path[0] = _space.tunnels.point_at(slot_index, to_m)
	path_tunnel.resize(1)
	path_tunnel[0] = TunnelRouterScript.leg_code(slot_index, to_m < _travel_m)
	path_index = 0
	_start_travel(slot_index, _travel_m, to_m)


func task_walk_to(point: Vector2) -> void:
	"""For a task: walk (on the surface, through tunnels if quicker) to `point`; the task's arrived()
	is called there."""
	_goal = point
	_replans = 0
	if position.distance_to(point) <= ARRIVE_RADIUS_M:
		_arrive()
		return
	_space.plan_path(index, position, point, radius, path, path_tunnel)
	_begin_leg()


func task_enter_bore(slot_index: int, from_m: float, to_m: float) -> void:
	"""For a task: go down tunnel `slot_index` at `from_m` and walk to `to_m` in it, where the task
	takes over again (TASK), still underground."""
	_travel_for_task = true
	_start_travel(slot_index, from_m, to_m)


func task_stand_in_bore(slot_index: int, along_m: float, facing_forward: bool) -> void:
	"""For a task: stand in tunnel `slot_index`'s bore `along_m` from its entrance, facing its exit
	(or its entrance). Standing, it heads neither way in the bore (heading 0), so walkers never queue
	up behind it: they step aside and pass, as for someone coming the other way."""
	_travel_slot = slot_index
	_travel_m = along_m
	_travel_forward = facing_forward
	_side_m = 0.0
	if not underground:
		_set_underground(true)
	_place_in_tunnel()
	_space.set_in_bore(index, slot_index, along_m, 0)


func task_surface(slot_index: int, exit: bool) -> void:
	"""For a task: come up out of tunnel `slot_index` at its entrance (or exit)."""
	_travel_m = _space.tunnels.length_m(slot_index) if exit else 0.0
	position = _space.tunnels.mouth(slot_index, exit)
	_set_underground(false)
	_space.move_resident(index, position)


func task_play(clip_name: StringName) -> void:
	"""For a task: play this clip (idle when the creature lacks it) at its own speed."""
	_set_clip(clip_name if has_clip(clip_name) else CLIP_IDLE, 1.0)


func task_face(point: Vector2, delta: float) -> void:
	"""For a task: turn toward `point` at the on-the-spot rate."""
	if point.distance_to(position) > 1e-3:
		yaw = turn_toward(yaw, yaw_of(point - position), SPOT_TURN_RATE * delta)
