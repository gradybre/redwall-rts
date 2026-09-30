extends "res://test/framework/test_case.gd"
## The demo cast's pace (decision 0205: the playtest found every creature too slow, the mole "way too
## slow with a log"). Every creature walks at WALK_PACE times its walk clip's recorded gait speed
## (decision 0202), the clip sped by the same factor so the pinned feet keep their ground; a carrier
## walks at CARRY_WALK_FRACTION of that, its carry clip at that pace over the clip's own root speed.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")

const DT: float = 1.0 / 60.0
const SEED: int = 777
## The staged mole's recorded gait (manifest walk_speed_m_s) and its carry clip's mean root speed.
const MOLE_GAIT_M_S: float = 0.5165
const MOLE_CARRY_MEAN_M_S: float = 0.1203


func _lengths() -> Dictionary:
	"""Every clip the brain knows."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _space() -> CastSpaceScript:
	"""An open space with one POI."""
	var space := CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": &"here", "position": Vector3.ZERO, "face": Vector3(0, 0, 1),
		"activities": [&"collect_object"] as Array[StringName], "capacity": 1}]
	space.setup(points, [] as Array[Vector3])
	return space


func _mole(space: CastSpaceScript) -> BrainScript:
	"""A brain paced as the staged mole: gait 0.5165 m/s, walking WALK_PACE times it."""
	var brain := BrainScript.new()
	brain.configure(space, MOLE_GAIT_M_S * DemoActorScript.WALK_PACE, 0.2, SEED, _lengths())
	brain.set_gait_speed(MOLE_GAIT_M_S)
	brain.start_at(Vector2.ZERO, 0.0, -1, -1)
	return brain


func _carry_motion(mean: float) -> Dictionary:
	"""A straight carry root motion at `mean` m/s over 6.5 s."""
	var keys: Array = []
	for k: int in 66:
		keys.append([0.0, mean * 6.5 * k / 65.0])
	return {"keys_xz": keys, "mean_speed_m_s": mean, "period_s": 6.5}


func test_the_pace_is_raised_and_the_walk_clip_follows_it() -> void:
	"""WALK_PACE 1.4; the mole walks 0.72 m/s, not its gait's 0.52, the walk clip at 1.4 so the feet keep
	their ground; without a gait speed (the suites' bare brains) the clip plays at 1."""
	assert_almost_equal(DemoActorScript.WALK_PACE, 1.4, "the pace")
	var mole := _mole(_space())
	assert_almost_equal(mole.walk_speed, 0.7231, "the mole's pace")
	assert_almost_equal(mole.gait_rate(), 1.4, "its walk clip's rate")
	assert_almost_equal(mole.stride_rate(), 1.4, "unloaded: the walk's")
	var bare := BrainScript.new()
	bare.configure(_space(), 0.8, 0.2, SEED, _lengths())
	assert_almost_equal(bare.gait_rate(), 1.0, "no gait: as recorded")
	bare.set_gait_speed(-1.0)
	assert_almost_equal(bare.gait_rate(), 1.0, "a nonsense gait is none")


func test_a_walker_covers_its_pace_with_the_clip_at_its_rate() -> void:
	"""Walking the open ground for a second in clear weather: 0.72 m, the walk clip at 1.4 throughout."""
	var space := _space()
	var mole := _mole(space)
	mole.order_move(Vector2(0.0, 10.0))
	var walked: float = 0.0
	var rates: Array[float] = []
	for f: int in 180:
		var before: Vector2 = mole.position
		mole.step(DT)
		if mole.state == BrainScript.State.WALK:
			walked += before.distance_to(mole.position)
			rates.append(mole.clip_speed)
	assert_true(rates.size() > 60, "it walked")
	assert_almost_equal(rates[-1], 1.4, "the clip at the pace's rate")
	assert_less_than(absf(walked / (rates.size() * DT) - 0.7231), 0.02, "0.72 m/s on the ground")


func test_a_carry_is_most_of_the_walk_and_its_clip_matches() -> void:
	"""The mole with a load: 65% of its 0.72 (0.47 m/s, was 0.19), the carry clip at that over its own
	0.12 m/s (3.9), inside [CARRY_MIN_RATE, CARRY_MAX_RATE]; a clip too slow to reach it is capped."""
	assert_almost_equal(BrainScript.CARRY_WALK_FRACTION, 0.65, "the fraction")
	var mole := _mole(_space())
	mole.set_carry_motion(_carry_motion(MOLE_CARRY_MEAN_M_S))
	var pace: float = MOLE_GAIT_M_S * DemoActorScript.WALK_PACE * BrainScript.CARRY_WALK_FRACTION
	assert_less_than(absf(mole._carry_speed - pace), 0.0001, "65% of the walk")
	assert_less_than(absf(mole._carry_rate - pace / MOLE_CARRY_MEAN_M_S), 0.001, "the clip at pace over its own")
	assert_less_than(mole._carry_rate, BrainScript.CARRY_MAX_RATE, "within the cap")
	var slow := _mole(_space())
	slow.set_carry_motion(_carry_motion(0.05))
	assert_almost_equal(slow._carry_speed, 0.05 * BrainScript.CARRY_MAX_RATE, "a slow clip is capped at its limit")


func test_the_placeholder_cast_walks_at_the_pace() -> void:
	"""A placeholder actor walks WALK_PACE times its nominal gait, its clip at WALK_PACE."""
	var actor := DemoActorScript.new()
	actor.setup_placeholder(0, _space(), SEED)
	assert_almost_equal(actor.brain.walk_speed, DemoActorScript.PLACEHOLDER_WALK_SPEED_M_S * DemoActorScript.WALK_PACE,
		"the placeholder's pace")
	assert_almost_equal(actor.brain.gait_rate(), DemoActorScript.WALK_PACE, "its clip's rate")
	actor.free()
