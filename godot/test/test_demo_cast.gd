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
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")

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
	assert_true(first_walk_error[0] <= BrainScript.BLEND_WALK_ANGLE + 0.05, "within the blend angle of the route before setting off (%.2f rad)" % first_walk_error[0])
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
	var books_wrong := 0
	var trips := 0
	for f in 60 * 120:
		for b in brains:
			var before := b.poi
			b.step(DT)
			trips += 1 if b.poi != before else 0
		for p in points.size():
			over += 1 if space.occupancy(p) > space.poi_capacity[p] else 0
		slot_clash += _slot_clashes(brains)
		books_wrong += 0 if _reservations_match(space, brains) else 1
	assert_true(trips >= 8, "residents actually moved between POIs (%d trips)" % trips)
	assert_equal(over, 0, "no POI ever holds more reservation bits than its capacity")
	assert_equal(slot_clash, 0, "no two residents ever hold the same slot")
	assert_equal(books_wrong, 0, "the reservation bits are exactly the slots residents hold")


func _reservations_match(space: CastSpaceScript, brains: Array[BrainScript]) -> bool:
	"""Whether the set bits in poi_used are exactly the (poi, slot) pairs the brains hold."""
	var expected := PackedInt32Array()
	expected.resize(space.poi_used.size())
	for b in brains:
		if b.poi >= 0:
			expected[b.poi] = expected[b.poi] | (1 << b.slot)
	return expected == space.poi_used


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
		for f in 60 * 60:
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
	"""Build the placeholder cast, step it 40 s through the cast's clock, and return where everyone is."""
	var cast: Node3D = DemoCastScript.new()
	var circles: Array[Vector3] = [Vector3(0.0, 1.5, 0.0)]
	cast.build({"world": {}, "cast": {}}, _village(), circles)
	for f in 60 * 40:
		cast.advance(DT)
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


# --- review fixes: the constraint -----------------------------------------------------------

func test_a_body_cannot_squeeze_through_a_gap_narrower_than_itself() -> void:
	"""Two radius-1 circles 0.4 m apart; a 0.3 m body pushing through for ten seconds stays out of both."""
	var circles: Array[Vector3] = [Vector3(-1.2, 1.0, 0.0), Vector3(1.2, 1.0, 0.0)]
	var space := _space([], circles)
	var index := space.add_resident(Vector2(0.0, -2.0), 0.3)
	var at := Vector2(0.0, -2.0)
	var worst := INF
	for f in 600:
		at = space.constrain(index, at, at + Vector2(0.0, WALK_M_S * DT), Vector2(0.0, 5.0))
		space.move_resident(index, at)
		for c in circles:
			worst = minf(worst, Vector2(c.x, c.z).distance_to(at) - c.y - 0.3)
	assert_true(worst >= -EPS, "never inside radius + body (worst %.4f m)" % worst)
	assert_true(at.y < 0.0, "still on the near side of the gap (z %.3f)" % at.y)


func test_the_constraint_lets_a_body_right_up_to_a_goal_tucked_against_a_circle() -> void:
	"""A goal 0.1 m off a circle's edge is reachable: the reach shrinks to leave the goal outside."""
	var space := _space([], [Vector3(0.0, 1.0, 0.0)])
	var index := space.add_resident(Vector2(0.0, -3.0), BODY_M)
	var goal := Vector2(0.0, -1.1)
	assert_equal(space.constrain(index, Vector2(0.0, -1.3), goal, goal), goal, "stands on the goal")
	var elsewhere := space.constrain(index, Vector2(0.0, -1.3), goal, Vector2(0.0, 9.0))
	assert_almost_equal(elsewhere.length(), 1.0 + BODY_M, "but not when the goal is elsewhere")


func test_a_step_into_a_resident_stops_at_contact() -> void:
	"""The resident push: a step into someone ends exactly touching them, not back at the start."""
	var space := _space([], [])
	var me := space.add_resident(Vector2(0.0, -2.0), BODY_M)
	space.add_resident(Vector2.ZERO, BODY_M)
	var at := space.constrain(me, Vector2(0.0, -2.0), Vector2(0.0, -0.3), Vector2(0.0, 5.0))
	assert_almost_equal(at.y, -2.0 * BODY_M, "touching, radius + radius from their centre")
	assert_almost_equal(at.x, 0.0, "straight on")


func test_an_obstacle_push_never_shoves_a_body_into_a_resident() -> void:
	"""A step the obstacle deflects sideways into a neighbour is refused whole."""
	var space := _space([], [Vector3(0.0, 1.0, 0.0)])
	var me := space.add_resident(Vector2(0.7, 1.05), BODY_M)
	var other := Vector2(0.45, 1.55)
	space.add_resident(other, BODY_M)
	var from := Vector2(0.7, 1.05)
	var at := space.constrain(me, from, Vector2(0.48, 1.15), Vector2(0.0, 9.0))
	var limit := minf(2.0 * BODY_M, other.distance_to(from))
	assert_true(other.distance_to(at) >= limit - EPS, "not pushed into the neighbour (%.4f m)" % other.distance_to(at))
	assert_true(at.length() >= minf(1.0 + BODY_M, from.length()) - EPS, "nor into the obstacle")


func test_a_circle_without_a_positive_radius_is_refused() -> void:
	"""setup() drops (and reports) a circle whose radius is not positive: the wrong axis order."""
	var space := _space([], [Vector3(0.0, -1.0, 0.0), Vector3(3.0, 0.0, 3.0), Vector3(5.0, 1.0, 5.0)])
	assert_equal(space.obstacles.size(), 1, "only the real circle is kept")
	assert_equal(space.obstacles[0], Vector3(5.0, 1.0, 5.0), "and it is the positive one")


# --- review fixes: planning and replanning --------------------------------------------------

func test_a_plan_reaches_a_goal_tucked_behind_a_wall() -> void:
	"""The goal sits 0.2 m off a wall of circles; the plan still detours to it rather than giving up."""
	var wall: Array[Vector3] = []
	for x in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		wall.append(Vector3(x, 0.9, 0.0))
	var space := _space([], wall)
	var path := PackedVector2Array()
	space.plan_path(-1, Vector2(0.0, -4.0), Vector2(0.0, 1.1), BODY_M, path)
	assert_true(space.nav.last_found, "a route exists")
	assert_true(path.size() >= 2, "round the end of the wall (%d waypoints)" % path.size())
	assert_equal(path[path.size() - 1], Vector2(0.0, 1.1), "to the goal itself")


func test_line_clear_sees_open_ground_and_not_through_a_circle() -> void:
	"""The per-frame sight test used to skip waypoints."""
	var space := _space([], [Vector3(0.0, 1.0, 0.0)])
	var me := space.add_resident(Vector2(-4.0, 0.0), BODY_M)
	assert_true(space.line_clear(me, Vector2(-4.0, -3.0), Vector2(4.0, -3.0), BODY_M, Vector2(4.0, -3.0)), "open ground")
	assert_false(space.line_clear(me, Vector2(-4.0, 0.0), Vector2(4.0, 0.0), BODY_M, Vector2(4.0, 0.0)), "through the circle")
	space.add_resident(Vector2(0.0, -3.0), 0.4)
	assert_false(space.line_clear(me, Vector2(-4.0, -3.0), Vector2(4.0, -3.0), BODY_M, Vector2(4.0, -3.0)), "through someone standing")


func test_a_brain_marks_itself_walking_only_while_it_walks() -> void:
	"""Standing residents are planned round; the brain tells the space which it is, every step."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var seen := {}
	var mismatches := 0
	for f in 60 * 90:
		brain.step(DT)
		var flag := space.resident_walking[brain.index]
		mismatches += 0 if (flag == 1) == (brain.state == BrainScript.State.WALK) else 1
		seen[brain.state * 2 + flag] = true
	assert_equal(mismatches, 0, "the flag matches the state after every step")
	assert_true(seen.has(BrainScript.State.WALK * 2 + 1), "walking was seen, flagged")
	assert_true(seen.has(BrainScript.State.IDLE * 2), "idling was seen, not flagged")


func test_a_walker_asked_to_turn_back_stops_and_turns() -> void:
	"""Mid-walk, a target behind the walker stops it and turns it on the spot."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	for f in 60 * 30:
		brain.step(DT)
		if brain.state == BrainScript.State.WALK:
			break
	assert_equal(brain.state, BrainScript.State.WALK, "walking")
	brain.path[brain.path_index] = brain.position - brain.forward() * 3.0
	var before := brain.position
	brain.step(DT)
	assert_equal(brain.state, BrainScript.State.TURN, "stops to turn")
	assert_equal(brain.position, before, "without stepping")


func _corridors() -> CastSpaceScript:
	"""Two corridors, west (shorter) and east, between a central column and two outer walls, from a
	POI at z = -6 to one at z = +6."""
	var circles: Array[Vector3] = []
	for z in range(-2, 3):
		circles.append(Vector3(0.3, 1.0, float(z)))
	for z in range(-4, 5):
		circles.append(Vector3(-3.2, 1.0, float(z)))
		circles.append(Vector3(3.8, 1.0, float(z)))
	var points: Array[Dictionary] = [
		_poi(&"south", Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, -1.0), [&"idle"], 1),
		_poi(&"north", Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, 1.0), [&"idle"], 1)]
	return _space(points, circles)


func test_a_walker_blocked_by_someone_who_stops_in_its_way_replans_promptly() -> void:
	"""After the plan, someone stops in the west corridor; the walker replans as soon as its current
	leg runs into them -- before it touches them -- and arrives by the east corridor."""
	var space := _corridors()
	var brain := _brain(space, 0, SEED)
	var placed_frame := -1
	var replan_frame := -1
	var first_path := PackedVector2Array()
	var closest_before_replan := INF
	var gave_up := false
	for f in 60 * 90:
		var before := brain.poi
		brain.step(DT)
		gave_up = gave_up or (before == 1 and brain.poi != 1)
		if placed_frame >= 0 and replan_frame < 0:
			closest_before_replan = minf(closest_before_replan, brain.position.distance_to(Vector2(-1.45, 0.0)))
		if placed_frame < 0 and brain.state == BrainScript.State.WALK:
			first_path = brain.path.duplicate()
			space.add_resident(Vector2(-1.45, 0.0), 0.6)
			placed_frame = f
		if placed_frame >= 0 and replan_frame < 0 and brain.path != first_path:
			replan_frame = f
		if brain.poi == 1 and brain.state == BrainScript.State.ACT:
			break
	assert_true(first_path.size() > 0 and first_path[0].x < 0.0, "the first plan went west")
	assert_true(replan_frame >= 0, "replanned")
	assert_true(closest_before_replan > 0.6 + BODY_M + 0.1, "before touching the blocker (closest %.2f m)" % closest_before_replan)
	assert_true(_goes_east(brain.path) or brain.position.y > 0.0, "the new route goes east")
	assert_true(brain.poi == 1 and brain.state == BrainScript.State.ACT, "and arrived")
	assert_false(gave_up, "on the same trip, without giving it up")


func _goes_east(path: PackedVector2Array) -> bool:
	"""Whether a route passes east of the central column."""
	for point in path:
		if point.x > 1.3:
			return true
	return false


func test_a_walker_jammed_in_a_lane_gives_up_within_seconds() -> void:
	"""A lane just wide enough for one, plugged by someone flagged as walking (so neither the plan nor
	the standing check sees them): the constraint holds the walker, it notices within BLOCKED_AFTER_S,
	replans MAX_REPLANS times and gives the trip up in a few seconds rather than tens."""
	var circles: Array[Vector3] = []
	for z in range(-3, 4):
		circles.append(Vector3(-1.1, 0.7, float(z)))
		circles.append(Vector3(1.1, 0.7, float(z)))
	var points: Array[Dictionary] = [
		_poi(&"south", Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, 1.0), [&"idle"], 1),
		_poi(&"north", Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, 1.0), [&"idle"], 1)]
	var space := _space(points, circles)
	var brain := _brain(space, 0, SEED)
	var plug := space.add_resident(Vector2.ZERO, 0.3)
	space.set_walking(plug, true)
	var contact := -1
	var gave_up := -1
	for f in 60 * 60:
		var before := brain.poi
		brain.step(DT)
		if contact < 0 and brain.position.distance_to(Vector2.ZERO) < 0.3 + BODY_M + 0.01:
			contact = f
		if before == 1 and brain.poi == -1:
			gave_up = f
			break
	assert_true(contact >= 0, "the walker reached the plug")
	assert_true(gave_up >= 0 and gave_up - contact < 60 * 5, "gave up within 5 s of reaching it (%.1f s)" % (float(gave_up - contact) / 60.0))


func test_a_walled_in_walker_gives_up_and_frees_its_slot() -> void:
	"""The pocket's only gap is closed behind a walker already on its way out (someone steps into it):
	the walker replans, then abandons the trip and releases the slot it reserved at the destination.
	(This test used to wall the walker in from the start; a resident with no route at all now never
	sets off -- test_a_resident_boxed_in_waits_for_the_way_out_instead_of_walking_into_it.)"""
	var space := _pocket_space()
	var brain := _brain(space, 0, SEED)
	var blocker := -1
	var abandoned := false
	var freed := false
	for f in 60 * 120:
		var before := brain.poi
		brain.step(DT)
		if blocker < 0 and brain.poi == 1 and brain.state == BrainScript.State.WALK:
			blocker = space.add_resident(Vector2(-7.0, 0.0), 0.3)
		if before == 1 and brain.poi == -1:
			abandoned = true
			freed = space.poi_used[1] == 0
			break
	assert_true(blocker >= 0, "set off through the gap before it closed")
	assert_true(abandoned, "the trip was given up")
	assert_true(freed, "and the destination's slot released")
	assert_true(brain.position.distance_to(Vector2(-10.0, 0.0)) < 3.0, "still inside the ring")


func test_the_real_village_is_well_formed_for_the_cast() -> void:
	"""DemoWorld's published circles and POIs, fed to CastSpace: sane radii, every POI and slot clear of
	every circle, and a route between every pair of POIs for every body the cast uses."""
	var world: Node3D = DemoWorldScript.new()
	var space := _space(world.points_of_interest(), world.obstacles())
	world.free()
	# 192: the water (demo/water/) keeps trees and logs out of the stream and off its banks.
	assert_equal(space.obstacles.size(), 192, "all 192 circles kept (none refused)")
	var bad_radius := 0
	for circle in space.obstacles:
		bad_radius += 0 if circle.y > 0.0 and circle.y < 3.0 else 1
	assert_equal(bad_radius, 0, "every radius is positive and under 3 m")
	var tight := 0
	for poi in space.poi_position.size():
		tight += 1 if space.obstacle_clearance(space.poi_position[poi]) < DemoActorScript.MIN_RADIUS_M else 0
		for slot in space.poi_capacity[poi]:
			tight += 1 if space.obstacle_clearance(space.slot_position(poi, slot)) < DemoActorScript.MIN_RADIUS_M else 0
	assert_equal(tight, 0, "every POI and slot stands clear of every circle by the smallest body")
	assert_equal(_unroutable(space), 0, "every POI reaches every other, for every body")


func _unroutable(space: CastSpaceScript) -> int:
	"""How many (body, from, to) plans between POIs find no route or cross a circle."""
	var path := PackedVector2Array()
	var bad := 0
	for body: float in [0.2, 0.22, 0.253, 0.328, 0.56]:
		for a in space.poi_position.size():
			for b in space.poi_position.size():
				if a != b:
					var from := space.slot_position(a, 0)
					space.plan_path(-1, from, space.slot_position(b, 0), body, path)
					bad += 0 if space.nav.last_found and _route_clear(space, from, path) else 1
	return bad


func _route_clear(space: CastSpaceScript, from: Vector2, path: PackedVector2Array) -> bool:
	"""Whether no leg of a route passes inside any obstacle circle."""
	var at := from
	for point in path:
		for circle in space.obstacles:
			if CastSpaceScript.distance_to_segment(Vector2(circle.x, circle.z), at, point) < circle.y:
				return false
		at = point
	return true


func test_a_carry_motion_without_a_period_is_refused() -> void:
	"""period_s <= 0 would index the root path at infinity; no carry instead."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var motion := _carry_motion()
	motion["period_s"] = 0.0
	brain.set_carry_motion(motion)
	assert_false(brain.can_carry(), "a zero period is refused")


func _walking_brain(space: CastSpaceScript) -> BrainScript:
	"""A resident from POI 0 of `space` that has just set off for POI 1."""
	var brain := _brain(space, 0, SEED)
	for f in 60 * 30:
		brain.step(DT)
		if brain.state == BrainScript.State.WALK:
			break
	return brain


func test_walk_turn_flips_are_bounded_by_a_replan() -> void:
	"""A walker whose target keeps jumping just past STOP_TO_TURN_ANGLE flips walk -> turn; the fifth
	flip on one leg is replaced by a fresh plan. Each forced target is nearer than the last and the
	walker makes headway in between, so being stuck is never what ends it."""
	var space := _two_ends([])
	var brain := _walking_brain(space)
	var goal := space.slot_position(1, 0)
	var flips := 0
	var walked := 0
	var replanned_at := -1
	for f in 60 * 60:
		if brain.state == BrainScript.State.WALK:
			walked += 1
			if flips > 0 and brain.path[0] == goal:
				replanned_at = flips
				break
			if flips == 0 or walked >= 20:
				var aside := brain.forward().rotated(deg_to_rad(80.0))
				brain.path = PackedVector2Array([brain.position + aside * (4.0 - 0.5 * float(flips))])
				brain.path_index = 0
				flips += 1
				walked = 0
		brain.step(DT)
	assert_equal(replanned_at, BrainScript.MAX_FLIPS + 1, "replanned on flip MAX_FLIPS + 1")


func test_a_turn_that_never_finishes_counts_as_stuck() -> void:
	"""Time spent turning counts toward STUCK_AFTER_S, so a turn chasing a target that stays behind is
	ended by a replan."""
	var space := _two_ends([])
	var brain := _walking_brain(space)
	brain.path = PackedVector2Array([brain.position - brain.forward() * 3.0])
	brain.path_index = 0
	brain.step(DT)
	assert_equal(brain.state, BrainScript.State.TURN, "turning")
	var goal := space.slot_position(1, 0)
	var frames := 0
	while brain.path[0] != goal and frames < 60 * 10:
		brain.path[0] = brain.position - brain.forward() * 3.0
		brain.step(DT)
		frames += 1
	assert_equal(brain.path[0], goal, "the chase ended in a fresh plan to the goal")
	assert_true(float(frames) * DT <= BrainScript.STUCK_AFTER_S + 0.1, "after about STUCK_AFTER_S (%.2f s)" % (float(frames) * DT))


# --- pathing review: departures, turning, routines ------------------------------------------

func _tight_slot_space() -> CastSpaceScript:
	"""A POI 0.35 m off a 1 m circle (inside radius + body, like the village's tight slots), facing
	it, and a destination 6 m behind the POI."""
	var points: Array[Dictionary] = [
		_poi(&"bench", Vector3(0.0, 0.0, -1.35), Vector3(0.0, 0.0, 1.0), [&"idle"], 1),
		_poi(&"away", Vector3(0.0, 0.0, -7.5), Vector3(0.0, 0.0, -1.0), [&"idle"], 1)]
	return _space(points, [Vector3(0.0, 1.0, 0.0)])


func test_leaving_a_tight_slot_never_stalls() -> void:
	"""Setting off from a slot tight against a building: the walker turns and is 0.5 m clear within
	1.5 s of starting to turn, and never goes 1 s without moving 0.15 m while walking or turning."""
	var space := _tight_slot_space()
	var brain := _brain(space, 0, SEED)
	var started := -1
	var cleared := -1
	var anchor := brain.position
	var worst := 0.0
	var still := 0.0
	for f in 60 * 60:
		brain.step(DT)
		var moving := brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK
		if moving and started < 0:
			started = f
		if started >= 0 and cleared < 0 and brain.position.distance_to(space.slot_position(0, 0)) >= 0.5:
			cleared = f
		if moving and brain.position.distance_to(anchor) < 0.15:
			still += DT
			worst = maxf(worst, still)
		else:
			still = 0.0
			anchor = brain.position
		if brain.poi == 1 and brain.state == BrainScript.State.ACT:
			break
	assert_true(started >= 0 and cleared >= 0 and cleared - started <= 90, "clear of the slot within 1.5 s (%d frames)" % (cleared - started))
	assert_true(worst < 1.0, "no 1 s without headway while leaving (worst %.2f s)" % worst)
	assert_true(brain.poi == 1 and brain.state == BrainScript.State.ACT, "and reached the destination")


func test_a_big_turn_finishes_walking_when_the_way_is_clear() -> void:
	"""In the open, an about-face hands over to WALK within BLEND_WALK_ANGLE, before it is squared up."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	var first_walk_error := -1.0
	for f in 60 * 60:
		var was := brain.state
		brain.step(DT)
		if was == BrainScript.State.TURN and brain.state == BrainScript.State.WALK:
			first_walk_error = absf(angle_difference(brain.yaw, BrainScript.yaw_of(brain.path[brain.path_index] - brain.position)))
			break
	assert_true(first_walk_error > BrainScript.START_WALK_ANGLE, "set off before squaring up (%.2f rad)" % first_walk_error)
	assert_true(first_walk_error <= BrainScript.BLEND_WALK_ANGLE + 1e-3, "but within the blend angle")


func test_a_turn_facing_a_wall_does_not_set_off_early() -> void:
	"""Facing into a building 0.3 m away with the route 50 degrees off: inside the blend angle, but the
	way ahead is blocked, so it keeps turning on the spot. The same turn in the open sets off."""
	var blocked := _turning_at(Vector2(0.0, -1.3), [Vector3(0.0, 1.0, 0.0)])
	var open := _turning_at(Vector2(0.0, -1.3), [])
	assert_equal(blocked, BrainScript.State.TURN, "boxed in: still turning")
	assert_equal(open, BrainScript.State.WALK, "in the open: walking")


func _turning_at(at: Vector2, circles: Array[Vector3]) -> int:
	"""The state after one step of a resident at `at` facing +Z, turning toward a point 50 degrees
	to its left, with these circles about."""
	var space := _space([_poi(&"spot", Vector3(at.x, 0.0, at.y), Vector3(0.0, 0.0, 1.0), [&"idle"], 1)], circles)
	var brain := _brain(space, 0, SEED)
	brain.yaw = 0.0
	brain.path = PackedVector2Array([at + Vector2(sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * 3.0])
	brain.path_index = 0
	brain._goal = brain.path[0]
	brain._enter_turn(deg_to_rad(50.0), BrainScript.CLIP_WALK)
	brain.step(DT)
	return brain.state


func test_a_big_turn_on_the_spot_uses_the_shuffle() -> void:
	"""A turn over SHUFFLE_ANGLE steps in place with the walk clip; a small one stands idle."""
	var space := _two_ends([])
	var brain := _brain(space, 0, SEED)
	brain._enter_turn(brain.yaw + PI, BrainScript.CLIP_WALK)
	assert_equal(brain.clip, BrainScript.CLIP_WALK, "an about-face shuffles")
	brain._enter_turn(brain.yaw + 0.3, BrainScript.CLIP_WALK)
	assert_equal(brain.clip, BrainScript.CLIP_IDLE, "a small turn does not")


func test_routines_resolve_homes_and_socials_by_name() -> void:
	"""A creature's homes are its routine's POIs that this world has; unknown names are skipped."""
	var names: Array[StringName] = [&"well_drink", &"stockpile", &"cauldron", &"square_east"]
	var homes := CastRoutinesScript.homes_for(&"badger_quarryman", names)
	assert_equal(homes, PackedInt32Array([1, 2]), "stockpile and cauldron (no hall steps here)")
	assert_equal(CastRoutinesScript.socials_for(names), PackedInt32Array([3, 0]), "square east and the well")
	assert_true(CastRoutinesScript.homes_for(&"placeholder_0", names).is_empty(), "no routine, no homes")


func test_choosing_from_a_pool_prefers_near_and_respects_capacity() -> void:
	"""choose_poi_from stays in its pool, skips the current and full POIs, and favours nearer ones."""
	var points: Array[Dictionary] = [
		_poi(&"here", Vector3.ZERO, Vector3.FORWARD, [], 1),
		_poi(&"near", Vector3(3, 0, 0), Vector3.FORWARD, [], 1),
		_poi(&"far", Vector3(30, 0, 0), Vector3.FORWARD, [], 1),
		_poi(&"outside", Vector3(1, 0, 0), Vector3.FORWARD, [], 1)]
	var space := _space(points, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var counts := PackedInt32Array([0, 0, 0, 0])
	var pool := PackedInt32Array([0, 1, 2])
	for i in 2000:
		counts[space.choose_poi_from(pool, 0, Vector2.ZERO, rng)] += 1
	assert_equal(counts[0] + counts[3], 0, "never the current POI, never outside the pool")
	assert_true(counts[1] > counts[2] * 2, "the near one far more often (%d vs %d)" % [counts[1], counts[2]])
	space.reserve(1, 0)
	assert_equal(space.choose_poi_from(pool, 0, Vector2.ZERO, rng), 2, "a full POI is skipped")


func test_work_bouts_cycle_through_a_pois_activities() -> void:
	"""With two activities at a POI, consecutive bouts there alternate (an ordered worker, so it stays)."""
	var space := _space([_poi(&"bench", Vector3.ZERO, Vector3.FORWARD, [&"collect_object", &"wave_one_hand"], 1)], [])
	var brain := _brain(space, 0, SEED)
	brain.order_work(0, 0)
	var bouts: Array[StringName] = []
	for f in 60 * 120:
		var was := brain.state
		brain.step(DT)
		if brain.state == BrainScript.State.ACT and was != BrainScript.State.ACT:
			bouts.append(brain.clip)
	var repeats := 0
	for i in range(1, bouts.size()):
		repeats += 1 if bouts[i] == bouts[i - 1] else 0
	var idle := bouts.count(&"idle")
	assert_true(bouts.size() >= 3, "several bouts (%d)" % bouts.size())
	assert_equal(repeats, 0, "no activity repeated back to back")
	assert_equal(idle, 0, "every bout is one of the POI's activities")


func test_ten_minutes_on_the_real_village_never_stall_away_from_residents() -> void:
	"""The placeholder cast on DemoWorld's real layout for 10 minutes: no walking/turning streak of
	1.5 s or more with under 0.15 m of headway, unless another resident was within 1 m."""
	var world: Node3D = DemoWorldScript.new()
	var cast: Node3D = DemoCastScript.new()
	cast.build({"world": {}, "cast": {}}, world.points_of_interest(), world.obstacles())
	world.free()
	var bad := _unexplained_streaks(cast, 60 * 600)
	cast.free()
	assert_equal(bad, 0, "stalls away from any resident")


func _unexplained_streaks(cast: Node3D, frames: int) -> int:
	"""Count no-headway streaks >= 1.5 s with nobody within 1 m, over `frames` fixed steps."""
	var n: int = cast.actor_count()
	var anchor := PackedVector2Array()
	var still := PackedFloat32Array()
	anchor.resize(n)
	still.resize(n)
	var bad := 0
	for f in frames:
		for i in n:
			var brain: BrainScript = cast.actor(i).brain
			brain.step(DT)
			var moving := brain.state == BrainScript.State.WALK or brain.state == BrainScript.State.TURN
			if moving and brain.position.distance_to(anchor[i]) < 0.15:
				still[i] += DT
				continue
			if still[i] >= 1.5 and _nearest_other(cast, i) > 1.0:
				bad += 1
			still[i] = 0.0
			anchor[i] = brain.position
	return bad


func _nearest_other(cast: Node3D, i: int) -> float:
	"""Distance from actor i to the nearest other actor."""
	var best := INF
	for j in cast.actor_count():
		if j != i:
			best = minf(best, cast.actor(i).brain.position.distance_to(cast.actor(j).brain.position))
	return best


func test_a_routine_keeps_a_resident_to_its_homes() -> void:
	"""With homes 1 and 2 (and no social spots), five minutes of wandering only ever visits them,
	although POIs 0 and 3 are open and nearer."""
	var points: Array[Dictionary] = [
		_poi(&"start", Vector3.ZERO, Vector3.FORWARD, [&"idle"], 1),
		_poi(&"home_a", Vector3(6, 0, 0), Vector3.FORWARD, [&"idle"], 1),
		_poi(&"home_b", Vector3(-6, 0, 0), Vector3.FORWARD, [&"idle"], 1),
		_poi(&"elsewhere", Vector3(0, 0, 3), Vector3.FORWARD, [&"idle"], 1)]
	var space := _space(points, [])
	var brain := _brain(space, 0, SEED)
	brain.homes = PackedInt32Array([1, 2])
	var visited := {}
	for f in 60 * 300:
		var before := brain.poi
		brain.step(DT)
		if brain.poi != before and brain.poi >= 0:
			visited[brain.poi] = true
	assert_true(visited.has(1) and visited.has(2), "both homes visited (%s)" % [visited.keys()])
	assert_false(visited.has(0) or visited.has(3), "and nowhere else")


func test_a_slow_walker_works_longer() -> void:
	"""Same seed, same POI: a 0.5 m/s walker's first bout lasts SLOW_WALK_M_S / 0.5 times longer."""
	var fast := _first_bout_seconds(0.8)
	var slow := _first_bout_seconds(0.5)
	assert_true(slow > fast * 1.3, "slow %.1f s vs fast %.1f s" % [slow, fast])


func _first_bout_seconds(speed: float) -> float:
	"""How long the first work bout lasts for a resident of this walking speed."""
	var space := _space([_poi(&"bench", Vector3.ZERO, Vector3.FORWARD, [&"collect_object"], 1)], [])
	var brain := BrainScript.new()
	brain.configure(space, speed, BODY_M, SEED, _lengths())
	space.reserve(0, 0)
	brain.start_at(space.slot_position(0, 0), 0.0, 0, 0)
	var frames := 0
	for f in 60 * 120:
		brain.step(DT)
		if brain.state == BrainScript.State.ACT:
			frames += 1
		elif frames > 0:
			break
	return float(frames) * DT


func test_a_resident_works_twice_as_long_as_it_walked_to_get_there() -> void:
	"""After a 40 m trip (about 50 s at 0.8 m/s -- more than BOUTS_MAX bouts of ACT_MAX_S could fill
	on their own), the resident keeps adding bouts until it has worked WORK_PER_WALK times the trip."""
	var points: Array[Dictionary] = [
		_poi(&"west", Vector3(-20.0, 0.0, 0.0), Vector3.FORWARD, [&"collect_object"], 1),
		_poi(&"east", Vector3(20.0, 0.0, 0.0), Vector3.FORWARD, [&"collect_object"], 1)]
	var brain := _brain(_space(points, []), 0, SEED)
	var trip := 0.0
	var worked := 0.0
	for f in 60 * 400:
		var was := brain.state
		brain.step(DT)
		var travelling := brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK
		if brain.poi == 1 and travelling and worked > 0.0:
			break
		if brain.poi == 1 and travelling:
			trip += DT
		elif brain.poi == 1 and brain.state == BrainScript.State.ACT:
			worked += DT
	assert_true(trip > 40.0, "a long trip (%.1f s)" % trip)
	assert_true(worked >= BrainScript.WORK_PER_WALK * trip - 0.1, "worked %.1f s for a %.1f s trip" % [worked, trip])
	assert_true(worked > float(BrainScript.BOUTS_MAX) * BrainScript.ACT_MAX_S, "more than the random bouts alone")


func _pocket_space() -> CastSpaceScript:
	"""A closed ring of 15 circles round (-10, 0) whose one gap faces +X, a POI at its centre and
	another 10 m outside the gap."""
	var ring: Array[Vector3] = []
	for k in range(1, 16):
		var angle := TAU * float(k) / 16.0
		ring.append(Vector3(cos(angle) * 3.0 - 10.0, 0.8, sin(angle) * 3.0))
	var points: Array[Dictionary] = [
		_poi(&"inside", Vector3(-10.0, 0.0, 0.0), Vector3.FORWARD, [&"collect_object"], 1),
		_poi(&"outside", Vector3(0.0, 0.0, 0.0), Vector3.FORWARD, [&"collect_object"], 1)]
	return _space(points, ring)


func test_a_resident_boxed_in_waits_for_the_way_out_instead_of_walking_into_it() -> void:
	"""Someone standing in the pocket's only gap: the resident inside never sets off (no straight-line
	fallback into the blocker) and never takes the outside POI's slot. Once the gap clears it leaves."""
	var space := _pocket_space()
	var brain := _brain(space, 0, SEED)
	var blocker := space.add_resident(Vector2(-7.0, 0.0), 0.3)
	var walked := false
	for f in 60 * 90:
		brain.step(DT)
		walked = walked or brain.state == BrainScript.State.WALK
	assert_false(walked, "never walked while boxed in")
	assert_equal(brain.poi, 0, "still holds its own slot")
	assert_equal(space.poi_used[1], 0, "and never reserved the outside one")
	space.move_resident(blocker, Vector2(20.0, 20.0))
	var left := false
	for f in 60 * 30:
		brain.step(DT)
		left = left or (brain.poi == 1 and brain.state == BrainScript.State.WALK)
	assert_true(left, "sets off once the gap is clear")
