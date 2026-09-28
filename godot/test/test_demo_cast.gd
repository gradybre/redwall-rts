extends "res://test/framework/test_case.gd"
## The live demo's cast (decision 0196): the wandering brain, the shared CastSpace, and the
## placeholder cast CI builds when nothing is staged.
##
## The runner executes suites before the scene tree is live and CI has no staged assets, so this
## drives the pure logic -- brains stepped at a fixed 60 Hz on hand-built POIs and circles -- and
## builds the placeholder cast out of the tree. Each walk is bounded by a frame budget and every
## invariant is checked on every frame of it, not just at the end.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")

const DT: float = 1.0 / 60.0
const BODY_M: float = 0.25
const WALK_M_S: float = 0.8
const SEED: int = 4242
const EPS: float = 1e-4

var _cast: Node3D = null


func after_each() -> void:
	"""Free any cast a test built."""
	if _cast != null:
		_cast.free()
	_cast = null


# --- fixtures -------------------------------------------------------------------------------

func _poi(name: StringName, at: Vector3, face: Vector3, activities: Array[StringName], capacity: int) -> Dictionary:
	"""One POI in the world's shape."""
	return {"name": name, "position": at, "face": face, "activities": activities, "capacity": capacity}


func _lengths() -> Dictionary:
	"""Every clip the brain knows, with round lengths."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _space(points: Array[Dictionary], obstacles: Array[Vector3]) -> CastSpaceScript:
	"""A CastSpace over these POIs and circles."""
	var space := CastSpaceScript.new()
	space.setup(points, obstacles)
	return space


func _brain(space: CastSpaceScript, at_poi: int, seed: int) -> BrainScript:
	"""A resident standing in slot 0 of `at_poi`, facing its face direction."""
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, seed, _lengths())
	var slot := space.free_slot(at_poi)
	space.reserve(at_poi, slot)
	brain.start_at(space.slot_position(at_poi, slot), BrainScript.yaw_of(space.poi_face[at_poi]), at_poi, slot)
	return brain


func _two_ends(obstacles: Array[Vector3]) -> CastSpaceScript:
	"""POI 0 at z = -4 and POI 1 at z = +4, one slot each, with `obstacles` between."""
	var points: Array[Dictionary] = [
		_poi(&"south", Vector3(0.0, 0.0, -4.0), Vector3(0.0, 0.0, -1.0), [&"collect_object"], 1),
		_poi(&"north", Vector3(0.0, 0.0, 4.0), Vector3(0.0, 0.0, 1.0), [&"stand_and_drink"], 1)]
	return _space(points, obstacles)


func _run_until_poi(brain: BrainScript, target: int, frames: int, each: Callable) -> bool:
	"""Step until `brain` is working at `target` (FACE done, ACT begun), calling
	each(brain, yaw_before, state_before) after every step."""
	for f in frames:
		var yaw_before := brain.yaw
		var state_before := brain.state
		brain.step(DT)
		each.call(brain, yaw_before, state_before)
		if brain.poi == target and brain.state == BrainScript.State.ACT:
			return true
	return false


# --- obstacles ------------------------------------------------------------------------------

func test_walking_round_a_circle_never_enters_it() -> void:
	"""A walker routed round a circle stays outside radius + body on every frame, and arrives."""
	## A 1 m circle sits squarely between the two POIs, so the straight line is blocked.
	var circle := Vector3(0.0, 1.0, 0.0)
	var space := _two_ends([circle])
	var brain := _brain(space, 0, SEED)
	var closest := [INF]
	var arrived := _run_until_poi(brain, 1, 60 * 60, func(b: BrainScript, _y: float, _s: int) -> void:
		closest[0] = minf(closest[0], b.position.length() - circle.y - b.radius))
	assert_true(arrived, "arrives at the far POI")
	assert_true(closest[0] >= -EPS, "never closer than radius + body (closest %.4f m)" % closest[0])


func test_a_step_aimed_into_a_circle_is_stopped_at_its_edge() -> void:
	"""constrain() stops a step at radius + body and leaves a step away alone."""
	var space := _space([], [Vector3(0.0, 1.0, 0.0)])
	var index := space.add_resident(Vector2(0.0, -2.0), BODY_M)
	var at := space.constrain(index, Vector2(0.0, -2.0), Vector2(0.0, -0.5), Vector2(0.0, 5.0))
	assert_almost_equal(at.length(), 1.0 + BODY_M, "held at radius + body")
	var away := space.constrain(index, Vector2(0.0, -2.0), Vector2(0.0, -2.5), Vector2(0.0, 5.0))
	assert_equal(away, Vector2(0.0, -2.5), "a step away is untouched")


func test_the_constraint_never_pushes_anyone_out_who_started_closer() -> void:
	"""The constraint is monotone: no deeper, but no pop outward either."""
	## Monotone: already inside radius + body (spawned there), a resident may not go deeper, and is
	## not popped out either.
	var space := _space([], [Vector3(0.0, 1.0, 0.0)])
	var index := space.add_resident(Vector2(0.0, -1.1), BODY_M)
	var still := space.constrain(index, Vector2(0.0, -1.1), Vector2(0.0, -1.05), Vector2(0.0, -9.0))
	assert_almost_equal(still.length(), 1.1, "held at its own distance")
	var out := space.constrain(index, Vector2(0.0, -1.1), Vector2(0.0, -1.2), Vector2(0.0, -9.0))
	assert_almost_equal(out.length(), 1.2, "moving out is allowed")


func test_a_plan_threads_a_wall_of_overlapping_circles_without_crossing_one() -> void:
	"""The visibility-graph plan goes round a wall of overlapping circles, clearing each by the body."""
	## Five overlapping circles form a wall across x = -3..3 at z = 0; the route must go round an end.
	var wall: Array[Vector3] = []
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		wall.append(Vector3(x, 0.9, 0.0))
	var space := _space([], wall)
	var path := PackedVector2Array()
	var from := Vector2(0.0, -4.0)
	space.plan_path(-1, from, Vector2(0.0, 4.0), BODY_M, path)
	assert_true(path.size() >= 2, "a detour, not the straight line (%d waypoints)" % path.size())
	assert_equal(path[path.size() - 1], Vector2(0.0, 4.0), "ends at the goal")
	var worst := INF
	var at := from
	for point in path:
		for c in wall:
			worst = minf(worst, CastSpaceScript.distance_to_segment(Vector2(c.x, c.z), at, point) - c.y - BODY_M)
		at = point
	assert_true(worst >= 0.0, "every leg clears every circle by the body radius (%.3f m)" % worst)


func test_a_standing_resident_is_planned_round_but_a_walker_is_not() -> void:
	"""Standing residents are planning circles; walking ones are left to separation."""
	var space := _space([], [])
	var other := space.add_resident(Vector2(0.0, 0.0), 0.5)
	var path := PackedVector2Array()
	space.plan_path(-1, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path)
	assert_true(path.size() >= 2, "round someone standing in the way")
	space.set_walking(other, true)
	space.plan_path(-1, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path)
	assert_equal(path.size(), 1, "straight past someone who is walking")


# --- separation -----------------------------------------------------------------------------

func test_two_residents_crossing_paths_never_overlap() -> void:
	"""Two walkers meeting mid-route keep their circles apart and both arrive."""
	## Two-slot POIs facing the same way, so each resident's route to the other's free slot is a
	## diagonal and the two diagonals cross at the centre.
	var points: Array[Dictionary] = [
		_poi(&"south", Vector3(0.0, 0.0, -4.0), Vector3(0.0, 0.0, -1.0), [&"idle"], 2),
		_poi(&"north", Vector3(0.0, 0.0, 4.0), Vector3(0.0, 0.0, -1.0), [&"idle"], 2)]
	var space := _space(points, [])
	## The same seed, so both idle, work and set off on the same frame and meet in the middle.
	var a := _brain(space, 0, SEED)
	var b := _brain(space, 1, SEED)
	var closest := INF
	var done := [false, false]
	for f in 60 * 90:
		a.step(DT)
		b.step(DT)
		closest = minf(closest, a.position.distance_to(b.position) - a.radius - b.radius)
		done[0] = done[0] or (a.poi == 1 and a.state == BrainScript.State.ACT)
		done[1] = done[1] or (b.poi == 0 and b.state == BrainScript.State.ACT)
	assert_true(done[0] and done[1], "both reach the other's POI")
	assert_true(closest >= -EPS, "their circles never overlap (closest %.4f m)" % closest)


func test_separation_pushes_away_and_passes_on_the_right() -> void:
	"""The soft separation push points away from a neighbour and to the right of travel."""
	var space := _space([], [])
	var me := space.add_resident(Vector2.ZERO, BODY_M)
	space.add_resident(Vector2(0.0, 0.6), BODY_M)
	var push := space.separation(me, Vector2.ZERO, Vector2(0.0, 1.0))
	assert_true(push.y < 0.0, "pushed back from someone ahead")
	assert_true(push.x < 0.0, "and to the right of travel (+Z forward, right is -X)")
	var none := space.separation(me, Vector2(0.0, -5.0), Vector2(0.0, 1.0))
	assert_equal(none, Vector2.ZERO, "nobody near, no push")


# --- turning --------------------------------------------------------------------------------

func test_turning_is_rate_limited_and_happens_before_setting_off() -> void:
	"""Yaw turns at a bounded rate, on the spot before setting off, without moving."""
	## The walker starts facing away from its destination (its POI faces south, the target is north).
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var worst := [0.0, 0.0]
	var first_walk_error := [-1.0]
	var moved_while_turning := [0.0]
	var arrived := _run_until_poi(brain, 1, 60 * 60, func(b: BrainScript, yaw_before: float, state_before: int) -> void:
		var turn := absf(angle_difference(yaw_before, b.yaw))
		if state_before == BrainScript.State.WALK:
			worst[1] = maxf(worst[1], turn)
			if first_walk_error[0] < 0.0:
				first_walk_error[0] = absf(angle_difference(b.yaw, BrainScript.yaw_of(b.path[b.path_index] - b.position)))
		else:
			worst[0] = maxf(worst[0], turn)
		if b.state == BrainScript.State.TURN and b.poi == 1:
			moved_while_turning[0] = maxf(moved_while_turning[0], b.position.distance_to(space.slot_position(0, 0))))
	assert_true(arrived, "arrives")
	assert_true(worst[0] <= BrainScript.SPOT_TURN_RATE * DT + EPS, "on-the-spot turn rate (%.4f rad/frame)" % worst[0])
	assert_true(worst[1] <= BrainScript.WALK_TURN_RATE * DT + EPS, "walking turn rate (%.4f rad/frame)" % worst[1])
	assert_true(first_walk_error[0] <= BrainScript.START_WALK_ANGLE + 0.05, "faces the route before setting off")
	assert_almost_equal(moved_while_turning[0], 0.0, "turning on the spot does not move")


func test_turn_toward_goes_the_short_way_across_the_seam() -> void:
	"""turn_toward and yaw_of use the short way round and +Z as yaw 0."""
	var turned := BrainScript.turn_toward(deg_to_rad(170.0), deg_to_rad(-170.0), deg_to_rad(5.0))
	assert_almost_equal(rad_to_deg(turned), 175.0, "170 -> -170 turns +5, not -340")
	assert_almost_equal(BrainScript.turn_toward(0.0, 0.1, 1.0), 0.1, "a small turn completes")
	assert_almost_equal(BrainScript.yaw_of(Vector2(0.0, 1.0)), 0.0, "yaw 0 faces +Z")
	assert_almost_equal(BrainScript.yaw_of(Vector2(1.0, 0.0)), PI * 0.5, "+X is a quarter turn")


# --- points of interest ---------------------------------------------------------------------

func test_choosing_a_poi_skips_full_ones_and_the_current_one() -> void:
	"""choose_poi never offers a full POI or the current one; release frees a slot."""
	var points: Array[Dictionary] = [
		_poi(&"a", Vector3.ZERO, Vector3.FORWARD, [], 1),
		_poi(&"b", Vector3(5, 0, 0), Vector3.FORWARD, [], 2),
		_poi(&"c", Vector3(-5, 0, 0), Vector3.FORWARD, [], 1)]
	var space := _space(points, [])
	space.reserve(2, space.free_slot(2))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in 50:
		assert_equal(space.choose_poi(0, rng), 1, "only b is open that is not a")
	space.reserve(1, space.free_slot(1))
	space.reserve(1, space.free_slot(1))
	assert_equal(space.free_slot(1), -1, "b's two slots are taken")
	assert_equal(space.choose_poi(0, rng), -1, "nothing open")
	space.release(1, 0)
	assert_equal(space.free_slot(1), 0, "a released slot is free again")


func test_many_residents_never_overfill_a_poi() -> void:
	"""Four residents wandering two minutes never overfill a POI or share a slot."""
	var points: Array[Dictionary] = [
		_poi(&"a", Vector3(0, 0, 0), Vector3.FORWARD, [&"collect_object"], 1),
		_poi(&"b", Vector3(6, 0, 0), Vector3.FORWARD, [&"wave_one_hand"], 2),
		_poi(&"c", Vector3(0, 0, 6), Vector3.FORWARD, [&"stand_and_drink"], 1),
		_poi(&"d", Vector3(6, 0, 6), Vector3.FORWARD, [&"idle"], 1)]
	var space := _space(points, [Vector3(3, 0.6, 3)])
	var brains: Array[BrainScript] = []
	for i in 4:
		brains.append(_brain(space, i if i < 3 else 1, SEED + i))
	var over := 0
	var slot_clash := 0
	var trips := 0
	for f in 60 * 120:
		for b in brains:
			var before := b.poi
			b.step(DT)
			trips += 1 if b.poi != before else 0
		for p in points.size():
			over += 1 if space.occupancy(p) > space.poi_capacity[p] else 0
		slot_clash += _slot_clashes(brains)
	assert_true(trips >= 8, "residents actually moved between POIs (%d trips)" % trips)
	assert_equal(over, 0, "no POI ever holds more than its capacity")
	assert_equal(slot_clash, 0, "no two residents ever hold the same slot")


func _slot_clashes(brains: Array[BrainScript]) -> int:
	"""How many pairs of residents claim the same POI slot right now."""
	var clashes := 0
	for i in brains.size():
		for j in range(i + 1, brains.size()):
			if brains[i].poi >= 0 and brains[i].poi == brains[j].poi and brains[i].slot == brains[j].slot:
				clashes += 1
	return clashes


func test_slots_line_up_across_the_face_direction() -> void:
	"""A POI's slots sit side by side across its face direction."""
	var space := _space([_poi(&"bench", Vector3(2, 0, 3), Vector3(0, 0, 1), [], 3)], [])
	assert_equal(space.slot_position(0, 1), Vector2(2.0, 3.0), "the middle slot is the POI itself")
	assert_almost_equal(space.slot_position(0, 0).distance_to(space.slot_position(0, 2)), 2.0 * CastSpaceScript.SLOT_SPACING_M, "outer slots are two spacings apart")
	assert_almost_equal(space.slot_position(0, 0).y, 3.0, "slots sit across the face, not along it")


func test_stockpiles_are_recognised_by_name_or_carry_activity() -> void:
	"""A stockpile is known by its name or by offering the carry clip."""
	assert_true(CastSpaceScript.is_stockpile_name(&"open_stockpile"), "open_stockpile")
	assert_true(CastSpaceScript.is_stockpile_name(&"Covered_Store"), "covered_store, any case")
	assert_false(CastSpaceScript.is_stockpile_name(&"well"), "well")
	var space := _space([_poi(&"yard", Vector3.ZERO, Vector3.FORWARD, [&"carry_heavy_object_walk", &"collect_object"], 1)], [])
	assert_equal(space.poi_stockpile[0], 1, "a POI offering the carry is a stockpile")
	assert_equal(space.poi_activities[0].size(), 1, "the carry is not played standing still")
	assert_equal(space.poi_activities[0][0], &"collect_object", "the stationary activity is kept")


# --- the state machine ----------------------------------------------------------------------

func test_a_trip_runs_idle_turn_walk_face_act_in_order() -> void:
	"""One trip runs through the states in order, with the walk clip at 1.0 and the POI facing honoured."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var seen: Array[int] = [brain.state]
	var clips := {}
	var faced := [INF]
	for f in 60 * 60:
		brain.step(DT)
		if brain.state != seen[seen.size() - 1]:
			seen.append(brain.state)
			if brain.state == BrainScript.State.ACT and brain.poi == 1:
				faced[0] = absf(angle_difference(brain.yaw, 0.0))
		clips[brain.state] = clips.get(brain.state, {})
		clips[brain.state][brain.clip] = brain.clip_speed
		if brain.poi == 1 and brain.state == BrainScript.State.IDLE:
			break
	var expected: Array[int] = [BrainScript.State.IDLE, BrainScript.State.ACT, BrainScript.State.IDLE,
		BrainScript.State.TURN, BrainScript.State.WALK, BrainScript.State.FACE, BrainScript.State.ACT,
		BrainScript.State.IDLE]
	assert_equal(_without_repeat_bouts(seen), expected, "idle, work, idle, turn, walk, face, work, idle")
	assert_equal(clips[BrainScript.State.WALK], {&"walk": 1.0}, "walks with the walk clip at 1.0 only")
	assert_true((clips[BrainScript.State.ACT] as Dictionary).has(&"stand_and_drink"), "works with the POI's activity")
	assert_true(faced[0] <= BrainScript.FACE_DONE_ANGLE + EPS, "faces the POI's face direction (+Z) before working")


func _without_repeat_bouts(states: Array[int]) -> Array[int]:
	"""The state sequence with any second ACT, IDLE bout at the same POI folded away."""
	var out: Array[int] = []
	for s in states:
		var n := out.size()
		if n >= 2 and s == BrainScript.State.ACT and out[n - 1] == BrainScript.State.IDLE and out[n - 2] == BrainScript.State.ACT:
			out.pop_back()
			continue
		out.append(s)
	return out


func test_an_activity_lasts_whole_loops_of_its_clip() -> void:
	"""Each activity bout lasts a whole number of its clip's loops."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var act_frames := 0
	var bouts := 0
	for f in 60 * 30:
		var was := brain.state
		brain.step(DT)
		if brain.state == BrainScript.State.ACT:
			act_frames += 1
		elif was == BrainScript.State.ACT:
			bouts += 1
			var loops := float(act_frames) * DT / 2.0
			assert_true(absf(loops - roundf(loops)) < 0.02, "an activity of %.2f loops" % loops)
			assert_true(float(act_frames) * DT >= BrainScript.ACT_MIN_S - 1.0, "at least a few seconds")
			act_frames = 0
	assert_true(bouts >= 1, "at least one activity finished")


func test_an_activity_the_creature_lacks_plays_idle() -> void:
	"""An activity with no matching clip plays as idle."""
	var space := _space([_poi(&"stage", Vector3.ZERO, Vector3.FORWARD, [&"juggle"], 1)], [])
	var brain := _brain(space, 0, SEED)
	for f in 60 * 5:
		brain.step(DT)
		if brain.state == BrainScript.State.ACT:
			break
	assert_equal(brain.state, BrainScript.State.ACT, "working")
	assert_equal(brain.clip, &"idle", "an unknown activity plays as idle")


func test_with_nowhere_to_go_a_resident_waits_in_place() -> void:
	"""With every other POI full (here: none), a resident waits where it is."""
	var space := _space([_poi(&"only", Vector3.ZERO, Vector3.FORWARD, [&"idle"], 1)], [])
	var brain := _brain(space, 0, SEED)
	for f in 60 * 20:
		brain.step(DT)
	assert_true(brain.state == BrainScript.State.IDLE or brain.state == BrainScript.State.ACT, "never walks")
	assert_equal(brain.position, space.slot_position(0, 0), "never moves")


# --- carrying -------------------------------------------------------------------------------

func _carry_motion() -> Dictionary:
	"""A recorded root path: 0.2 m/s forward with a sideways weave, 31 keys over 3 s."""
	var keys: Array = []
	for k in 31:
		var t := float(k) * 0.1
		keys.append([0.05 * sin(TAU * t / 3.0), 0.2 * t])
	return {"period_s": 3.0, "travel_m": [0.0, 0.6], "mean_speed_m_s": 0.2, "window_s": 1.0, "keys_xz": keys}


func test_a_carry_trip_follows_the_clips_root_path_at_its_playback_rate() -> void:
	"""A carry trip plays the carry clip at playback_rate() and steps along its root path."""
	## Leaving a stockpile, a carrier walks the recorded root velocity (weave included) scaled by the
	## playback rate clip_root_motion gives for its ground speed, turned into its heading.
	var points: Array[Dictionary] = [_poi(&"stockpile", Vector3.ZERO, Vector3.BACK, [&"collect_object"], 1),
		_poi(&"hut", Vector3(0, 0, 6), Vector3.BACK, [&"idle"], 1)]
	var carried := false
	for attempt in 20:
		var space := _space(points, [])
		var brain := _brain(space, 0, SEED + attempt)
		brain.set_carry_motion(_carry_motion())
		for f in 60 * 12:
			brain.step(DT)
			if brain.state == BrainScript.State.WALK and brain.carrying:
				carried = true
				_check_carry_step(brain)
				break
		if carried:
			break
	assert_true(carried, "some seed carries within 20 tries (CARRY_CHANCE %.2f)" % BrainScript.CARRY_CHANCE)


func _check_carry_step(brain: BrainScript) -> void:
	"""The carry clip at the rate for its speed, and one frame's step equal to the rotated root velocity."""
	var speed := clampf(WALK_M_S * BrainScript.CARRY_WALK_FRACTION, 0.2 * BrainScript.CARRY_MIN_RATE, 0.2 * BrainScript.CARRY_MAX_RATE)
	var rate := ClipRootMotionScript.playback_rate(_carry_motion(), speed)
	assert_equal(brain.clip, BrainScript.CLIP_CARRY, "the carry clip")
	assert_almost_equal(brain.clip_speed, rate, "at playback_rate(motion, speed)")
	var key := int(fposmod(brain.clip_time(), 2.0) / 0.1)
	var keys: Array = _carry_motion()["keys_xz"]
	var local := Vector2(keys[key + 1][0] - keys[key][0], keys[key + 1][1] - keys[key][1]) / 0.1 * rate * DT
	var expected := Vector2(cos(brain.yaw), -sin(brain.yaw)) * local.x + brain.forward() * local.y
	assert_true(brain.ground_step(DT).distance_to(expected) < 1e-6, "the step is the clip's root velocity, turned to the heading")


func test_without_root_motion_nobody_carries() -> void:
	"""No usable root motion means no carry trips."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	brain.set_carry_motion({})
	assert_false(brain.can_carry(), "no recorded path, no carry")
	brain.set_carry_motion({"mean_speed_m_s": 0.0, "keys_xz": [[0, 0], [0, 0]], "period_s": 1.0})
	assert_false(brain.can_carry(), "a path that does not travel, no carry")


# --- the cast node --------------------------------------------------------------------------

func _village() -> Array[Dictionary]:
	"""Eight POIs round a square."""
	var points: Array[Dictionary] = []
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append(_poi(StringName("p%d" % i), Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0),
			Vector3(cos(angle), 0.0, sin(angle)), [&"collect_object", &"wave_one_hand"], 1))
	return points


func test_with_nothing_staged_six_placeholders_stand_at_distinct_pois() -> void:
	"""An empty manifest builds six capsule placeholders, each on its own POI slot."""
	_cast = DemoCastScript.new()
	var circles: Array[Vector3] = [Vector3(0.0, 1.5, 0.0)]
	_cast.build({"world": {}, "cast": {}}, _village(), circles)
	var actors: Array[Node3D] = _cast.actors()
	assert_equal(actors.size(), DemoCastScript.PLACEHOLDER_COUNT, "six placeholders")
	var pois := {}
	for actor in actors:
		var a: DemoActorScript = actor
		assert_true(a.is_placeholder, "%s is a placeholder" % a.name)
		assert_true(a.find_children("*", "MeshInstance3D", true, false).size() >= 1, "%s has a shape" % a.name)
		pois[a.brain.poi] = true
		assert_equal(Vector2(a.position.x, a.position.z), _cast.space().slot_position(a.brain.poi, a.brain.slot), "stands on its slot")
	assert_equal(pois.size(), actors.size(), "each at its own POI")


func test_a_cast_built_twice_moves_identically() -> void:
	"""Seeded per resident: two fixed-step runs end identically."""
	var first := _soaked_positions()
	var second := _soaked_positions()
	assert_equal(first, second, "seeded per resident, so a fixed-step run repeats exactly")
	assert_true(first.size() == DemoCastScript.PLACEHOLDER_COUNT, "one position per resident")


func _soaked_positions() -> PackedVector2Array:
	"""Build the placeholder cast, step it 40 s through its actors, and return where everyone is."""
	var cast: Node3D = DemoCastScript.new()
	var circles: Array[Vector3] = [Vector3(0.0, 1.5, 0.0)]
	cast.build({"world": {}, "cast": {}}, _village(), circles)
	for f in 60 * 40:
		for actor in cast.actors():
			actor._process(DT)
	var out := PackedVector2Array()
	for actor in cast.actors():
		out.append(Vector2(actor.position.x, actor.position.z))
	cast.free()
	return out


func test_a_creature_whose_body_cannot_load_becomes_a_placeholder() -> void:
	"""A manifest row whose body is missing falls back to a placeholder."""
	_cast = DemoCastScript.new()
	var row := {"species": "mouse", "height_m": 1.0, "body": "res://demo/assets/cast/nobody/body.glb", "clips": {}, "walk_speed_m_s": 0.7}
	var none: Array[Vector3] = []
	_cast.build({"world": {}, "cast": {"nobody": row}}, _village(), none)
	var actor: DemoActorScript = _cast.actors()[0]
	assert_true(actor.is_placeholder, "falls back instead of failing")
	assert_not_null(actor.brain, "and still wanders")


func test_body_radius_scales_with_height_within_bounds() -> void:
	"""body_radius scales with height and is clamped."""
	assert_almost_equal(DemoActorScript.body_radius(1.0), 0.22, "a 1 m mouse")
	assert_almost_equal(DemoActorScript.body_radius(0.5), DemoActorScript.MIN_RADIUS_M, "clamped below")
	assert_almost_equal(DemoActorScript.body_radius(5.0), DemoActorScript.MAX_RADIUS_M, "clamped above")
