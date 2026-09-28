extends RefCounted
## One demo resident's wandering: which POI next, the route there, walking it, and what to do on
## arrival. Decision 0196. Pure logic -- no nodes -- so the tests drive it without a scene tree; the
## actor node reads `position`, `yaw`, `clip` and `clip_speed` back each frame and draws them.
##
## The cycle:  IDLE -> (pick a POI, plan) -> TURN -> WALK -> FACE -> ACT -> IDLE -> ACT ... -> IDLE -> TURN
##   * TURN   turns on the spot toward the route before setting off (stepping in place past
##            SHUFFLE_ANGLE, standing otherwise), so a walker never pivots sharply at speed.
##   * WALK   moves along `yaw` at the creature's measured walk speed with the walk clip at 1.0,
##            which is what keeps the planted foot from sliding (tools/stage_demo_assets.py). The yaw
##            turns toward the route at a limited rate; a demand past STOP_TO_TURN_ANGLE stops the
##            walker and hands back to TURN rather than skating round a tight corner.
##   * A trip away from a stockpile may carry: the carry clip plays at clip_root_motion's playback
##            rate for the chosen speed, and each frame's step follows the clip's own recorded root
##            path key by key -- its uneven pace AND its sideways weave (up to +-0.24 m over a loop on
##            the badger) -- so a planted foot stays planted there too (decision 0195).
##
## Yaw 0 faces +Z, the way the models face: forward is Vector2(sin(yaw), cos(yaw)) in (x, z).
## Deterministic: every random choice comes from this resident's own seeded generator.

const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")

enum State { IDLE, TURN, WALK, FACE, ACT }

const CLIP_IDLE: StringName = &"idle"
const CLIP_WALK: StringName = &"walk"
const CLIP_CARRY: StringName = &"carry_heavy_object_walk"

const WALK_TURN_RATE: float = 1.75          ## rad/s while walking (~100 deg/s)
const SPOT_TURN_RATE: float = 1.9           ## rad/s turning on the spot (~110 deg/s)
const STOP_TO_TURN_ANGLE: float = 1.31      ## ~75 deg: stop and turn on the spot instead
const START_WALK_ANGLE: float = 0.21        ## ~12 deg: close enough to set off
const FACE_DONE_ANGLE: float = 0.035        ## ~2 deg
const SHUFFLE_ANGLE: float = 0.44           ## ~25 deg: a turn this big steps in place
const SHUFFLE_CLIP_SPEED: float = 0.75
const WAYPOINT_REACH_M: float = 0.3
const ARRIVE_RADIUS_M: float = 0.12
const SEPARATION_WEIGHT: float = 1.2
const STUCK_AFTER_S: float = 2.5
const BLOCKED_AFTER_S: float = 0.35         ## held back this long by someone -> plan round them
const BLOCKED_FRACTION: float = 0.3         ## a frame moving less than this share of its step is held back
const STUCK_PROGRESS_M: float = 0.05
const MAX_REPLANS: int = 4
const IDLE_MIN_S: float = 1.2
const IDLE_MAX_S: float = 3.2
const ACT_MIN_S: float = 4.0
const ACT_MAX_S: float = 8.0
const RETRY_S: float = 1.5
const CARRY_CHANCE: float = 0.5
const CARRY_MAX_TRIP_M: float = 14.0
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
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

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
var _carry_velocity: PackedVector2Array = PackedVector2Array()
var _carry_key_s: float = 1.0
var _carry_rate: float = 1.0


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
	if keys.size() < 2 or mean < ClipRootMotionScript.MIN_SPEED_M_S or not has_clip(CLIP_CARRY):
		return
	_carry_key_s = float(motion.get("period_s", 1.0)) / float(keys.size() - 1)
	_carry_velocity.resize(keys.size() - 1)
	for k in keys.size() - 1:
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		_carry_velocity[k] = Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])) / _carry_key_s
	var carry_speed := clampf(walk_speed * CARRY_WALK_FRACTION, mean * CARRY_MIN_RATE, mean * CARRY_MAX_RATE)
	_carry_rate = ClipRootMotionScript.playback_rate(motion, carry_speed)


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
	_space.set_walking(index, state == State.WALK)
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
	if _bouts_left > 0 and poi >= 0:
		_enter_act()
	else:
		_depart()


func _enter_act() -> void:
	"""Play one of this POI's activities for a whole number of its loops, about ACT_MIN..MAX seconds."""
	state = State.ACT
	_bouts_left -= 1
	var activity := _pick_activity()
	var length := float(_clip_lengths.get(activity, DEFAULT_CLIP_S))
	var loops := maxi(1, roundi(rng.randf_range(ACT_MIN_S, ACT_MAX_S) / maxf(length, 0.1)))
	_timer = length * loops
	_set_clip(activity, 1.0)


func _pick_activity() -> StringName:
	"""A random one of the POI's activities that this resident can play, else idle."""
	var activities := _space.poi_activities[poi]
	var playable := 0
	for activity in activities:
		if has_clip(activity):
			playable += 1
	if playable == 0:
		return CLIP_IDLE
	var pick := rng.randi_range(0, playable - 1)
	for activity in activities:
		if has_clip(activity):
			if pick == 0:
				return activity
			pick -= 1
	return CLIP_IDLE


func _step_act(delta: float) -> void:
	"""Hold the activity until its loops are done, then idle between bouts."""
	_timer -= delta
	if _timer <= 0.0:
		_enter_idle(rng.randf_range(IDLE_MIN_S, IDLE_MAX_S))


func _depart() -> void:
	"""Pick the next POI with room, swap reservations, plan the route and start turning toward it."""
	var next := _space.choose_poi(poi, rng)
	if next < 0:
		_enter_idle(RETRY_S)
		return
	var next_slot := _space.free_slot(next)
	_space.reserve(next, next_slot)
	var leaving_stockpile := poi >= 0 and _space.poi_stockpile[poi] == 1
	_space.release(poi, slot)
	poi = next
	slot = next_slot
	_goal = _space.slot_position(next, next_slot)
	_space.plan_path(index, position, _goal, radius, path)
	carrying = leaving_stockpile and can_carry() and _trip_length() <= CARRY_MAX_TRIP_M \
			and rng.randf() < CARRY_CHANCE
	_replans = 0
	_begin_leg()


func _trip_length() -> float:
	"""Length of the planned route from here."""
	var total := 0.0
	var at := position
	for point in path:
		total += at.distance_to(point)
		at = point
	return total


func _begin_leg() -> void:
	"""Start following `path` from its first waypoint: turn on the spot first."""
	path_index = 0
	_reset_progress()
	_enter_turn(yaw_of(path[0] - position), _locomotion_clip())


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
	"""Turn toward the current waypoint; set off once facing it."""
	var target_yaw := yaw_of(path[path_index] - position)
	yaw = turn_toward(yaw, target_yaw, SPOT_TURN_RATE * delta)
	if absf(angle_difference(yaw, target_yaw)) <= START_WALK_ANGLE:
		state = State.WALK
		_set_clip(_locomotion_clip(), _carry_rate if carrying else 1.0)


func _step_face(delta: float) -> void:
	"""Turn to the POI's face direction, then start working."""
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
	"""Steer toward the route (and away from neighbours) at a limited yaw rate, and step forward."""
	_advance_waypoint()
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
		_enter_turn(yaw_of(desired), _locomotion_clip())
		return
	yaw = turn_toward(yaw, yaw + error, WALK_TURN_RATE * delta)
	var moved := _space.constrain(index, position, position + step, _goal)
	var held := moved.distance_to(position) < step.length() * BLOCKED_FRACTION
	position = moved
	_space.move_resident(index, moved)
	_watch_progress(distance, held, delta)


func _advance_waypoint() -> void:
	"""Move on past a waypoint once near it, or as soon as the one after it is in clear sight."""
	while path_index < path.size() - 1:
		var near := position.distance_to(path[path_index]) < WAYPOINT_REACH_M
		if near or _space.line_clear(index, position, path[path_index + 1], radius, _goal):
			path_index += 1
			_reset_progress()
		else:
			return


func ground_step(delta: float) -> Vector2:
	"""This frame's step on the ground: straight ahead at walk speed, or while carrying the clip's own
	recorded root velocity at this key (sideways weave included), sped up by the playback rate."""
	if not carrying:
		return forward() * (walk_speed * delta)
	var length := float(_clip_lengths.get(CLIP_CARRY, DEFAULT_CLIP_S))
	var key := mini(int(fposmod(_clip_time, length) / _carry_key_s), _carry_velocity.size() - 1)
	var local := _carry_velocity[key] * (_carry_rate * delta)
	return Vector2(cos(yaw), -sin(yaw)) * local.x + forward() * local.y


func _arrive() -> void:
	"""At the slot: turn to the POI's face direction, and plan one or two bouts of work."""
	carrying = false
	_bouts_left = rng.randi_range(1, 2)
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
	_replans += 1
	if _replans > MAX_REPLANS:
		_abandon_trip()
		return
	_space.plan_path(index, position, _goal, radius, path)
	_begin_leg()


func _abandon_trip() -> void:
	"""Give the slot back and stand a moment before choosing somewhere else."""
	_space.release(poi, slot)
	poi = -1
	slot = -1
	carrying = false
	_enter_idle(RETRY_S)
