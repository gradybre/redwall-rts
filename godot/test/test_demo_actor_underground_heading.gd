extends "res://test/framework/test_case.gd"
## Actual actor/brain behavior with synthetic route geometry; no movement-profile qualification.

const Actor := preload("res://demo/cast/demo_actor.gd")
const Brain := preload("res://demo/cast/resident_brain.gd")
const Space := preload("res://demo/cast/cast_space.gd")
const Clock := preload("res://demo/demo_clock.gd")
const Graph := preload("res://demo/tunnel/underground_graph.gd")
const Router := preload("res://demo/tunnel/tunnel_router.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const Tail := preload("res://scripts/presentation/tail_rig.gd")
const Stoop := preload("res://demo/cast/stoop_modifier.gd")
const EPS: float = 0.00001

class TailObservation extends Tail:
	var direction: Vector3 = Vector3.ZERO

	func set_water(_water: bool, backward: Vector3 = Vector3.ZERO) -> void:
		"""Observe the actual caller's direction without constructing an out-of-tree native spring."""
		direction = backward

	func set_floor(_height: float) -> void:
		"""The fixture records heading only; native spring behavior has its own asset capture."""
		return

var _actors: Array[Actor] = []


func after_each() -> void:
	"""Free every Node fixture and release its real brain/space references."""
	for actor: Actor in _actors:
		actor.free()
	_actors.clear()


func _actor() -> Actor:
	"""A real actor and actual brain over an empty, explicitly synthetic presentation space."""
	var space: Space = Space.new()
	space.setup([], [])
	var actor: Actor = Actor.new()
	actor.setup_placeholder(0, space, 1729)
	_actors.append(actor)
	actor.brain.start_at(Vector2.ZERO, 0.0, -1, -1)
	return actor


func _clock(seconds: float) -> Clock:
	"""Use the actual microsecond presentation clock rather than an invented per-frame delta."""
	var clock: Clock = Clock.new()
	clock.advance(seconds)
	return clock


func _draw_change(actor: Actor, yaw: float, pitch: float, clock: Clock) -> void:
	"""Change only fixture intent, then exercise the real actor draw path."""
	actor.brain.yaw = yaw
	actor.brain.pitch = pitch
	actor.draw(clock)


func test_first_pose_and_explicit_replacement_initialize_without_a_turn() -> void:
	"""Spawn/teleport copies the real supplied pose, including when no game time has elapsed."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	_draw_change(actor, 1.2, 0.2, _clock(0.0))
	assert_almost_equal(actor.rotation.y, 1.2, "initial actual heading")
	assert_almost_equal(actor.rotation.x, 0.2, "initial actual slope")
	actor.place(Vector2(3.0, 4.0), -1.3, -1, -1)
	assert_almost_equal(actor.rotation.y, -1.3, "explicit replacement resets visual history")
	assert_equal(actor.brain.position, Vector2(3.0, 4.0), "actual supplied placement retained")
	actor.draw(_clock(0.0))
	assert_almost_equal(actor.rotation.y, -1.3, "paused replacement stays initialized")


func test_surface_heading_keeps_its_existing_brain_turn_behavior() -> void:
	"""No underground transition means no extra surface delay or new turn-rate authority."""
	var actor: Actor = _actor()
	actor.draw(_clock(0.0))
	_draw_change(actor, 1.0, 0.0, _clock(1.0 / 30.0))
	assert_almost_equal(actor.rotation.y, actor.brain.yaw, "ordinary surface pose remains exact")


func test_bore_reversal_uses_shortest_arc_existing_rate_and_shared_pitch_progress() -> void:
	"""Mesh yaw is bounded while actual brain intent remains immediately reversed."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	_draw_change(actor, 0.0, 0.3, _clock(0.0))
	var clock: Clock = _clock(1.0 / 30.0)
	_draw_change(actor, PI, -0.3, clock)
	var turned: float = absf(angle_difference(0.0, actor.rotation.y))
	assert_almost_equal(turned, Brain.SPOT_TURN_RATE * clock.delta_s(), "same authored turn rate")
	assert_almost_equal(actor.brain.yaw, PI, "source heading untouched")
	assert_almost_equal(actor.brain.pitch, -0.3, "source slope untouched")
	assert_almost_equal(actor.rotation.x, lerpf(0.3, -0.3, turned / PI), "slope uses the same turn progress")
	assert_true(turned < PI, "no one-frame half turn")


func test_pause_keeps_an_in_progress_visible_turn_and_pitch_still() -> void:
	"""Repeated draws on a stopped real clock cannot advance the visual turn."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	_draw_change(actor, 0.0, 0.3, _clock(0.0))
	_draw_change(actor, PI, -0.3, _clock(0.1))
	var before: Vector3 = actor.rotation
	for frame: int in 20:
		actor.draw(_clock(0.0))
	assert_equal(actor.rotation, before, "yaw and pitch remain frozen")
	assert_almost_equal(actor.brain.yaw, PI, "pause did not rewind brain intent")


func test_pending_reversal_finishes_after_leaving_the_bore_without_an_exit_snap() -> void:
	"""The mouth transition does not discard unfinished presentation history."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	actor.draw(_clock(0.0))
	var clock: Clock = _clock(1.0 / 30.0)
	_draw_change(actor, PI, -0.3, clock)
	actor.brain.underground = false
	for frame: int in 35:
		var before: float = actor.rotation.y
		actor.draw(clock)
		assert_true(absf(angle_difference(before, actor.rotation.y)) <= Brain.SPOT_TURN_RATE * clock.delta_s() + EPS,
			"each surface-exit turn step is bounded")
	assert_true(absf(angle_difference(actor.rotation.y, actor.brain.yaw)) < EPS, "the actual exit heading is reached")
	assert_almost_equal(actor.rotation.x, actor.brain.pitch, "slope catches up exactly")


func test_wrap_and_retarget_do_not_choose_the_long_arc_or_overshoot() -> void:
	"""A new direction during recovery starts from the visible pose rather than a stale starting angle."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	_draw_change(actor, PI - 0.02, 0.0, _clock(0.0))
	var clock: Clock = _clock(0.01)
	_draw_change(actor, -PI + 0.02, 0.0, clock)
	assert_true(absf(angle_difference(PI - 0.02, actor.rotation.y)) <= Brain.SPOT_TURN_RATE * clock.delta_s() + EPS,
		"wrap follows the short arc")
	var before: float = actor.rotation.y
	_draw_change(actor, PI - 0.01, 0.0, clock)
	assert_true(absf(angle_difference(before, actor.rotation.y)) <= Brain.SPOT_TURN_RATE * clock.delta_s() + EPS,
		"interrupted reversal remains bounded")
	assert_true(absf(angle_difference(actor.rotation.y, actor.brain.yaw)) < EPS, "near target is reached without overshoot")


func test_tail_pull_follows_the_rendered_heading_during_recovery() -> void:
	"""A water transition during the pending turn cannot pull the tail toward the instantly reversed brain."""
	var actor: Actor = _actor()
	actor.brain.underground = true
	actor.draw(_clock(0.0))
	var observed: TailObservation = TailObservation.new()
	actor.set("_tail", observed)
	actor.brain.in_water = true
	_draw_change(actor, PI, 0.0, _clock(0.1))
	assert_true(observed.direction.is_equal_approx(Vector3(-sin(actor.rotation.y), 0.0, -cos(actor.rotation.y))),
		"tail uses the current visible orientation")
	assert_false(observed.direction.is_equal_approx(Vector3(-sin(actor.brain.yaw), 0.0, -cos(actor.brain.yaw))),
		"pending turn is not skipped by attachment direction")


func test_stoop_counterlean_uses_the_same_rendered_pitch_during_the_turn() -> void:
	"""Spine counterlean cannot jump to the reversed ramp pitch before the visible root turns."""
	var actor: Actor = _actor()
	var stoop: Stoop = Stoop.new()
	actor.add_child(stoop)
	actor.set("_stoop", stoop)
	actor.brain.underground = true
	_draw_change(actor, 0.0, 0.3, _clock(0.0))
	_draw_change(actor, PI, -0.3, _clock(0.1))
	assert_almost_equal(stoop.lean_rad, -actor.rotation.x * Actor.LEAN_BACK_SHARE, "same visible slope")
	assert_true(absf(stoop.lean_rad + actor.brain.pitch * Actor.LEAN_BACK_SHARE) > EPS,
		"reversed source pitch is not applied early")


func _route(actor: Actor) -> int:
	"""Build a completed synthetic three-part route through actual Graph methods."""
	var graph: Graph = actor.brain.space().tunnels
	var half: int = Rules.RAMP_RUN_U + Rules.MIN_LENGTH_U
	var ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(PackedInt32Array([0, -half, 0, half]), 2, 0, ref), "actual synthetic route")
	var chain: PackedInt32Array = PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	assert_equal(chain.size(), 3, "two mouths and central bore")
	for slot: int in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.set_bore(slot, Rules.BORE_WIDE)
		graph.advance(slot, graph.generation[slot], 1000000000)
		assert_equal(graph.phase[slot], Graph.PHASE_OPEN, "fixture actually complete")
	var bore: int = chain[1]
	actor.brain.path = PackedVector2Array([graph.node_m(graph.node_b[bore])])
	actor.brain.path_tunnel = PackedInt32Array([Router.leg_code(bore, false)])
	actor.brain.path_index = 0
	actor.brain._start_travel(bore, graph.length_m(bore) * 0.25, graph.length_m(bore))
	actor._apply_transform()
	return bore


func _same_brains(first: Brain, second: Brain) -> void:
	"""Compare future-affecting route behavior after one twin was drawn and the other only stepped."""
	assert_equal(first.position, second.position, "actual position unchanged by drawing")
	assert_equal(first.yaw, second.yaw, "actual heading unchanged by drawing")
	assert_equal(first.pitch, second.pitch, "actual slope unchanged by drawing")
	assert_equal(first.bore_along_m(), second.bore_along_m(), "exact committed progress retained")
	assert_equal(first.state, second.state, "same actual state")
	assert_equal(first.path, second.path, "same retained route")
	assert_equal(first.path_tunnel, second.path_tunnel, "same segment directions")
	assert_equal(first.space().tunnels.queue.grant, second.space().tunnels.queue.grant, "same mouth grants")


func _twin_reversal(retreat: bool) -> void:
	"""Run actual turn_back or nearest-exit logic for twin worlds, drawing exactly one of them."""
	var drawn: Actor = _actor()
	var baseline: Actor = _actor()
	var bore: int = _route(drawn)
	assert_equal(_route(baseline), bore, "identical initial graph")
	if retreat:
		drawn.brain._walk_out()
		baseline.brain._walk_out()
	else:
		drawn.brain.turn_back(bore, 0.0)
		baseline.brain.turn_back(bore, 0.0)
	var clock: Clock = _clock(1.0 / 30.0)
	for frame: int in 360:
		var previous: float = drawn.rotation.y
		drawn.advance(clock)
		baseline.step_brain(clock)
		_same_brains(drawn.brain, baseline.brain)
		assert_true(absf(angle_difference(previous, drawn.rotation.y)) <= Brain.SPOT_TURN_RATE * clock.delta_s() + EPS,
			"actual underground reversal has no visible snap")
		if not drawn.brain.underground:
			break
	assert_false(drawn.brain.underground, "the actual route reaches the surface")


func test_actual_reversal_does_not_change_progress_route_or_grants() -> void:
	"""A closed-ahead turn preserves every twin route observation while the body eases around."""
	_twin_reversal(false)


func test_actual_nearest_exit_retreat_does_not_change_progress_route_or_grants() -> void:
	"""Nearest-exit retreat retains actual committed progress rather than restarting the segment."""
	_twin_reversal(true)
