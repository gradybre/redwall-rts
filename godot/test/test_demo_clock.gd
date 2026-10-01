extends "res://test/framework/test_case.gd"
## The live demo's presentation clock (demo/demo_clock.gd, decision 0196): the village follows the
## game's pause and 1x / 2x / 4x -- residents, their digging, their clips and the mound -- while
## nothing it computes is ever fed back into the simulation.
##
## No scene tree and no staged assets. Each test drives its OWN GameManager instance (never the
## autoload, whose state the next suite would inherit), stepping the placeholder cast by hand at a
## fixed 60 Hz through DemoCast.advance(), exactly as its _process does.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

const DT: float = 1.0 / 60.0
## One 60 Hz frame, rounded to whole microseconds once.
const FRAME_USEC: int = 16667

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- fixtures -------------------------------------------------------------------------------

func _manager() -> GameManagerScript:
	"""A started GameManager of the test's own, running at 1x."""
	var manager := GameManagerScript.new()
	_nodes.append(manager)
	assert_true(manager.start_game(), "the test's clock starts")
	return manager


func _cast(manager: GameManagerScript) -> DemoCastScript:
	"""The placeholder cast on eight POIs round a square, its clock bound to `manager`."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	var points: Array[Dictionary] = []
	for i in 8:
		var angle := TAU * float(i) / 8.0
		points.append({"name": StringName("p%d" % i), "position": Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0),
			"face": Vector3(cos(angle), 0.0, sin(angle)), "activities": [&"collect_object"], "capacity": 1})
	var circles: Array[Vector3] = [Vector3(0.0, 1.5, 0.0)]
	cast.build({"world": {}, "cast": {}}, points, circles)
	cast.clock.bind(manager)
	return cast


func _frames(cast: DemoCastScript, count: int) -> void:
	"""Advance the cast `count` frames of DT real seconds."""
	for f in count:
		cast.advance(DT)


func _poses(cast: DemoCastScript) -> PackedVector3Array:
	"""Every resident's (x, z, yaw)."""
	var out := PackedVector3Array()
	for i in cast.actor_count():
		var brain := (cast.actor(i) as DemoActorScript).brain
		out.append(Vector3(brain.position.x, brain.position.y, brain.yaw))
	return out


func _walker(cast: DemoCastScript) -> BrainScript:
	"""Resident 0, ordered 4 m straight out into the open from where it stands and set walking."""
	var brain := (cast.actor(0) as DemoActorScript).brain
	brain.order_move(brain.position + brain.position.normalized() * 4.0)
	for f in 600:
		if brain.state == BrainScript.State.WALK:
			break
		brain.step(DT)
	return brain


# --- the clock itself -----------------------------------------------------------------------

func test_the_clock_reads_the_game_s_effective_speed() -> void:
	"""Unbound: 1x. Bound: 1 at the start, 0 paused, the requested speed again once resumed."""
	var clock := DemoClockScript.new()
	clock.advance(DT)
	assert_equal(clock.speed, 1, "unbound, the demo runs at 1x")
	assert_equal(clock.frame_usec, FRAME_USEC, "a 60 Hz frame is 16667 us")
	var manager := _manager()
	clock.bind(manager)
	clock.advance(DT)
	assert_equal(clock.speed, 1, "started at 1x")
	assert_true(manager.pause_game(), "paused")
	clock.advance(DT)
	assert_equal(clock.speed, 0, "paused: speed 0")
	assert_equal(clock.frame_usec, 0, "and no demo time passes")
	assert_equal(clock.steps(), 0, "in no steps")
	assert_true(manager.set_speed(4), "4x requested while paused")
	clock.advance(DT)
	assert_equal(clock.speed, 0, "still paused at 4x")
	assert_true(manager.resume_game(), "resumed")
	clock.advance(DT)
	assert_equal(clock.speed, 4, "resumed at the 4x asked for")
	assert_equal(clock.frame_usec, 4 * FRAME_USEC, "four frames' worth")


func test_a_frame_is_split_into_exact_sub_steps() -> void:
	"""66668 us at 4x is two steps of 33334; 50001 us is 25001 + 25000, and the shares add up exactly."""
	var manager := _manager()
	var clock := DemoClockScript.new()
	clock.bind(manager)
	manager.set_speed(4)
	clock.advance(DT)
	assert_equal(clock.steps(), 2, "66668 us in 33334 us steps")
	assert_equal(clock.step_usec(0) + clock.step_usec(1), 66668, "the shares add up")
	assert_equal(clock.step_usec(0), 33334, "an even split")
	clock.bind(null)
	clock.advance(0.050001)
	assert_equal(clock.steps(), 2, "50001 us is two steps")
	assert_equal(clock.step_usec(0), 25001, "the odd microsecond goes first")
	assert_equal(clock.step_usec(1), 25000, "then the rest")
	assert_almost_equal(clock.delta_s(), 0.050001, "the frame in seconds")


# --- the village follows it -----------------------------------------------------------------

func test_paused_no_resident_moves_turns_or_changes_clip() -> void:
	"""Paused for 240 frames, every resident keeps its place, its yaw and its clip."""
	var manager := _manager()
	var cast := _cast(manager)
	_frames(cast, 30)
	manager.pause_game()
	var before := _poses(cast)
	var clips: Array[StringName] = []
	for i in cast.actor_count():
		clips.append((cast.actor(i) as DemoActorScript).brain.clip)
	_frames(cast, 240)
	assert_equal(_poses(cast), before, "nobody moved or turned")
	for i in cast.actor_count():
		assert_equal((cast.actor(i) as DemoActorScript).brain.clip, clips[i], "resident %d keeps its clip" % i)


func test_a_walker_at_2x_covers_twice_the_ground_of_1x() -> void:
	"""The same walker, the same 20 frames straight ahead: 2x covers exactly twice 1x's ground."""
	var slow_cast := _cast(_manager())
	var slow := _walker(slow_cast)
	var from_slow := slow.position
	var two := _manager()
	var fast_cast := _cast(two)
	var fast := _walker(fast_cast)
	var from_fast := fast.position
	two.set_speed(2)
	_frames(slow_cast, 20)
	_frames(fast_cast, 20)
	var ratio := from_fast.distance_to(fast.position) / from_slow.distance_to(slow.position)
	assert_true(from_slow.distance_to(slow.position) > 0.2, "1x walked (%.3f m)" % from_slow.distance_to(slow.position))
	assert_true(absf(ratio - 2.0) < 1e-3, "2x covers twice the ground (ratio %.5f)" % ratio)


func test_resuming_continues_exactly_where_it_paused() -> void:
	"""600 frames at 1x, against 200 at 1x, 300 paused and 400 at 1x: every resident ends in exactly
	the same place, facing the same way -- a pause loses and adds nothing."""
	var straight := _cast(_manager())
	_frames(straight, 600)
	var manager := _manager()
	var paused := _cast(manager)
	_frames(paused, 200)
	manager.pause_game()
	_frames(paused, 300)
	manager.resume_game()
	_frames(paused, 400)
	assert_equal(_poses(paused), _poses(straight), "the paused run ends where the straight run does")


func _dig_cast(manager: GameManagerScript) -> Array:
	"""The placeholder cast with resident 0 a mole digging a 12 m tunnel (the shortest is 8 m: two 4 m ramps) from right beside it, already
	in the ground: [cast, network, slot]."""
	var cast := _cast(manager)
	var mole := (cast.actor(0) as DemoActorScript).brain
	var network := cast.space().tunnels
	var ref := PackedInt32Array([-1, 0])
	var at := mole.position
	var route := PackedInt32Array([roundi(at.x * 1024.0), roundi(at.y * 1024.0), roundi(at.x * 1024.0) + 12288,
		roundi(at.y * 1024.0)])
	assert_true(network.add_into(route, 2, mole.index, ref), "planned")
	mole.order_dig(ref[0], ref[1])
	for f in 60:
		if mole.state == BrainScript.State.DIG:
			break
		mole.step(DT)
	assert_equal(mole.state, BrainScript.State.DIG, "digging")
	return [cast, network, ref[0]]


func test_digging_stops_while_paused_and_runs_twice_as_fast_at_2x() -> void:
	"""Paused, the dig clock does not move; 60 frames at 2x credit exactly twice 60 frames at 1x."""
	var manager := _manager()
	var site := _dig_cast(manager)
	var cast: DemoCastScript = site[0]
	var network: GraphScript = site[1]
	var slot: int = site[2]
	manager.pause_game()
	var held := network.dig_usec[slot]
	_frames(cast, 120)
	assert_equal(network.dig_usec[slot], held, "no digging while paused")
	manager.resume_game()
	var start := network.dig_usec[slot]
	_frames(cast, 60)
	var at_one := network.dig_usec[slot] - start
	manager.set_speed(2)
	start = network.dig_usec[slot]
	_frames(cast, 60)
	# No tunnel crew here, so the segment's rate stays Rules.PERMILLE (no skill factor): one F1000 worker.
	assert_equal(at_one, 60 * FRAME_USEC, "60 frames at 1x")
	assert_equal(network.dig_usec[slot] - start, 2 * at_one, "60 frames at 2x: exactly twice")


func test_clips_freeze_paused_and_play_faster_at_speed() -> void:
	"""The AnimationPlayer's speed is the clip's own times the game's: 0 paused, doubled at 2x."""
	var manager := _manager()
	var cast := _cast(manager)
	var actor := cast.actor(1) as DemoActorScript
	var player := AnimationPlayer.new()
	actor.add_child(player)
	actor._player = player
	_frames(cast, 1)
	var own := actor.brain.clip_speed
	assert_almost_equal(player.speed_scale, own, "1x: the clip's own speed")
	manager.set_speed(2)
	_frames(cast, 1)
	assert_almost_equal(player.speed_scale, 2.0 * actor.brain.clip_speed, "2x: twice")
	manager.pause_game()
	_frames(cast, 1)
	assert_almost_equal(player.speed_scale, 0.0, "paused: a frozen pose")


func test_the_mound_holds_still_while_paused() -> void:
	"""Over a digging mole the mound bobs on the demo clock: paused, its bob stops. (Its clods are the warren's pooled
	particles since decision 0211; that they hold on a paused clock is test_demo_theatre.gd's.)"""
	var manager := _manager()
	var site := _dig_cast(manager)
	var cast: DemoCastScript = site[0]
	var network: GraphScript = site[1]
	var overlay := OverlayScript.new()
	_nodes.append(overlay)
	overlay.configure(network, cast.space(), cast.clock)
	for f in 600:
		cast.advance(DT)
		overlay._process(DT)
		if overlay.mound(site[2]).visible:
			break
	assert_true(overlay.mound(site[2]).visible, "the mole is under its mound")
	manager.pause_game()
	cast.advance(DT)
	overlay._process(DT)
	var bob := (overlay.mound(site[2]).get_child(0) as Node3D).scale.y
	for f in 30:
		cast.advance(DT)
		overlay._process(DT)
	assert_equal((overlay.mound(site[2]).get_child(0) as Node3D).scale.y, bob, "the bob holds")
	assert_equal(overlay.mound(site[2]).get_child_count(), 1, "its clods are the warren's pool's (test_demo_theatre.gd)")
