extends "res://test/framework/test_case.gd"
## The live demo's tunnel extensions in motion (decision 0196): residents walking in the weather,
## through lit bores and queues, driven by tasks; the works joining weather, digs, crews, finds,
## hazards, jobs and threats on the demo clock; the player's orders; the panel; and the drawings.
##
## No scene tree and no staged assets: brains are stepped at a fixed 60 Hz on hand-built circles, the
## works are stepped by hand with whole demo microseconds, and nodes are built out of the tree and
## freed after each test.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ActionsScript := preload("res://demo/tunnel/tunnel_actions.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const PanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const ExtScript := preload("res://demo/tunnel/tunnel_ext.gd")
const MarksScript := preload("res://demo/tunnel/tunnel_marks.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomViewScript := preload("res://demo/burrow/room_view.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const EventsViewScript := preload("res://demo/events/events_view.gd")
const EvacuateTaskScript := preload("res://demo/events/evacuate_task.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const PartyPanelScript := preload("res://demo/control/demo_party_panel.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Contrast := preload("res://demo/ui/woodland_contrast.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CoreWeather := preload("res://scripts/core/weather.gd")
const Layers := preload("res://demo/demo_layers.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")

const DT: float = 1.0 / 60.0
const SEED: int = 9091
const BODY_M: float = 0.25
const WALK_M_S: float = 1.0
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)

var _nodes: Array[Node] = []
var _notices: PackedStringArray = PackedStringArray()
## The demo's shared weather, water and notice feed, fresh for every test.
var _services: ServicesScript = ServicesScript.new()


func tolerates_outside_tree() -> bool:
	"""Its node fixtures are never inside the scene tree (test_case.gd ENGINE DIAGNOSTICS)."""
	return true


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built, and forget what was said."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_notices.clear()


# --- fixtures -------------------------------------------------------------------------------

func _lengths() -> Dictionary:
	"""Every clip the actor stages, 2 s long."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _wall() -> Array[Vector3]:
	"""Overlapping 0.9 m circles across x = -6..6 at z = 0: the straight line is blocked."""
	var wall: Array[Vector3] = []
	for x in [-6.0, -4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5, 6.0]:
		wall.append(Vector3(x, 0.9, 0.0))
	return wall


func _space(obstacles: Array[Vector3]) -> CastSpaceScript:
	"""A CastSpace over these circles, with no POIs."""
	var space := CastSpaceScript.new()
	space.setup([], obstacles)
	return space


func _open_tunnel(space: CastSpaceScript, points: Array[Vector2i]) -> PackedInt32Array:
	"""Add a mouth-to-mouth tunnel along these points and dig every segment of it to the end; returns its
	segments in dig order (underground_graph.gd PIECES: a 4 m ramp from each mouth, the bore between)."""
	var flat := PackedInt32Array()
	for p in points:
		flat.append(p.x)
		flat.append(p.y)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(flat, points.size(), 0, ref), "fixture tunnel stored")
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	for slot in chain:
		space.tunnels.start_dig(slot, space.tunnels.generation[slot], 0)
		space.tunnels.advance(slot, space.tunnels.generation[slot], 1000000000)
	return chain


func _brain(space: CastSpaceScript, at: Vector2, fits: bool) -> BrainScript:
	"""A resident standing at `at`, holding no slot, fitting the bore or not."""
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_fit(brain.index, fits)
	return brain


func _step(brains: Array, seconds: float) -> void:
	"""Step these brains together for `seconds`."""
	for f in roundi(seconds / DT):
		for b: BrainScript in brains:
			b.step(DT)


func _until(brain: BrainScript, cond: Callable, seconds: float) -> bool:
	"""Step `brain` until `cond()` holds (at most `seconds`); whether it did."""
	for f in roundi(seconds / DT):
		if bool(cond.call()):
			return true
		brain.step(DT)
	return bool(cond.call())


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	"""`actual` within `tolerance` of `expected`."""
	assert_true(absf(actual - expected) <= tolerance, "%s (expected %.4f +- %.4f, got %.4f)" % [message, expected, tolerance, actual])


static func _same_colour(a: Color, b: Color) -> bool:
	"""Whether two colours agree to within one 8-bit step in every channel."""
	return absf(a.r - b.r) <= 0.0040 and absf(a.g - b.g) <= 0.0040 and absf(a.b - b.b) <= 0.0040 and absf(a.a - b.a) <= 0.0040


func _say(text: String) -> void:
	"""A notice callable."""
	_notices.append(text)


func _warned(summary: String) -> bool:
	"""Whether the demo's notice feed holds a WARNING with this short summary."""
	return _posted(summary, NoticesScript.LEVEL_WARNING)


func _noted(summary: String) -> bool:
	"""Whether the demo's notice feed holds a NOTE with this short summary."""
	return _posted(summary, NoticesScript.LEVEL_NOTE)


func _posted(summary: String, level: int) -> bool:
	"""Whether the feed holds an entry with this summary at this level."""
	for k in _services.notices.count():
		if _services.notices.summary(k) == summary and _services.notices.level(k) == level:
			return true
	return false


func _rain(works: WorksScript) -> void:
	"""Make the one weather read an hour of spring heavy rain (the entry point its sync uses)."""
	works.weather.observe(0, 3, 12, 90, 3200, CoreWeather.EVENT_HEAVY_RAIN)


func _works(space: CastSpaceScript, brains: Array[BrainScript], species: PackedStringArray) -> WorksScript:
	"""Tunnel works over this cast (out of the tree; stepped by hand)."""
	var works := WorksScript.new()
	_nodes.append(works)
	works.setup(space, brains, species, BOUNDS_U, _say, _services)
	return works


# --- residents: weather, lanterns, queues, tasks --------------------------------------------

func _walk_speed_at(permille: int) -> Array:
	"""A resident's ground covered in one second of steady walking, and its walk clip's speed, with
	the weather's surface speed at `permille`."""
	var space := _space([])
	space.tunnels.surface_permille = permille
	var brain := _brain(space, Vector2.ZERO, false)
	brain.order_move(Vector2(0.0, 20.0))
	_step([brain], 1.0)
	var from := brain.position
	_step([brain], 1.0)
	return [brain.position.distance_to(from), brain.clip_speed, brain.state]


func test_bad_weather_slows_surface_walking_and_the_walk_clip() -> void:
	"""1.0 m a second in the sun; 0.8 in rain, the walk clip slowed to 0.8 so the feet stay planted."""
	var sun := _walk_speed_at(1000)
	var rain := _walk_speed_at(800)
	assert_equal(sun[2], BrainScript.State.WALK, "walking")
	assert_near(sun[0], 1.0, 0.01, "sun")
	assert_near(rain[0], 0.8, 0.01, "rain")
	assert_near(rain[1], 0.8, 0.0001, "the clip slowed with it")


func _bore_speed(lit: bool, permille: int, clip_out: Array = []) -> float:
	"""Metres a second a walker covers along the level bore (8 m, slot 1) of a 16 m tunnel, past its
	entrance ramp (the bore lit or not), in weather at `permille`; its walk clip's speed then is appended
	to `clip_out`."""
	var space := _space(_wall())
	var chain := _open_tunnel(space, [Vector2i(0, -8192), Vector2i(0, 8192)])
	var bore := chain[1]
	if lit:
		space.tunnels.set_lit(bore)
	space.tunnels.surface_permille = permille
	var brain := _brain(space, Vector2(0.0, -9.0), true)
	brain.order_move(Vector2(0.0, 10.0))
	_until(brain, func() -> bool: return brain.is_in_bore(bore) and brain.bore_along_m() > 0.5, 30.0)
	var from := brain.bore_along_m()
	_step([brain], 2.0)
	assert_true(brain.is_in_bore(bore), "still in the level bore")
	clip_out.append(brain.clip_speed)
	return (brain.bore_along_m() - from) / 2.0


func test_tunnel_travel_ignores_the_weather_and_lanterns_quicken_it() -> void:
	"""1.0 m/s below in snow as in the sun; 1.1 m/s in a lit bore."""
	assert_near(_bore_speed(false, 600), 1.0, 0.001, "snow above, full pace below")
	assert_near(_bore_speed(true, 1000), 1.1, 0.001, "lit")


func test_the_walk_clip_plays_at_ground_speed_in_a_bore() -> void:
	"""The walk clip's rate is ground speed over walk speed: 1.0 in an unlit bore in snow (the weather
	does not reach it), 1.1 in a lit one -- so the pinned feet do not slide (decision 0202)."""
	var unlit: Array = []
	var lit: Array = []
	_bore_speed(false, 600, unlit)
	_bore_speed(true, 1000, lit)
	assert_near(unlit[0], 1.0, 0.0001, "unlit, in snow: 1.0")
	assert_near(lit[0], 1.1, 0.0001, "lit: 1.1, as the ground goes by")


func test_a_second_walker_waits_in_line_at_a_busy_mouth_and_both_get_through() -> void:
	"""Two ordered through one 8 m tunnel under the wall together: the one behind waits in the mouth's line
	(QUEUE, shown as waiting) instead of crowding the hole, then follows; both come out."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -4096), Vector2i(0, 4096)])
	var a := _brain(space, Vector2(0.0, -5.4), true)
	var b := _brain(space, Vector2(-1.2, -6.6), true)
	a.order_move(Vector2(0.0, 6.0))
	b.order_move(Vector2(-1.0, 6.0))
	var queued := false
	var shown := false
	for f in 60 * 30:
		a.step(DT)
		b.step(DT)
		queued = queued or b.state == BrainScript.State.QUEUE
		shown = shown or b.activity() == BrainScript.ACTIVITY_QUEUE
	assert_true(queued, "B waited in line")
	assert_true(shown, "and was shown waiting")
	assert_true(a.position.distance_to(Vector2(0.0, 6.0)) < 0.2, "A through (%s)" % a.position)
	assert_true(b.position.distance_to(Vector2(-1.0, 6.0)) < 0.2, "B through (%s)" % b.position)
	assert_equal(space.tunnels.queue.count[0], 0, "the line is empty")
	assert_equal(space.tunnels.queue.grant[0], -1, "no grant held")


func test_a_mouth_is_clear_only_with_nobody_near_it_below_or_on_it() -> void:
	"""A 10 m tunnel (mouth row 0 at (0, -5), row 1 at (0, 5)): someone in a mouth's ramp within the hold of
	its hole -- measured from the mouth's end of that ramp -- or standing on the hole, blocks it."""
	var space := _space(_wall())
	var chain := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var walker := space.add_resident(Vector2(0.0, -8.0), BODY_M)
	var other := space.add_resident(Vector2(0.0, -4.5), BODY_M)
	space.set_underground(other, true)
	space.set_in_bore(other, chain[0], 0.5, 1)
	assert_false(space.mouth_clear(walker, 0, 1.2), "someone just below")
	assert_true(space.mouth_clear(walker, 1, 1.2), "the other mouth is clear")
	space.set_in_bore(other, chain[0], 2.0, 1)
	assert_true(space.mouth_clear(walker, 0, 1.2), "further down")
	space.set_in_bore(other, chain[2], 3.5, 1)
	assert_false(space.mouth_clear(walker, 1, 1.2), "0.5 m below the exit, its ramp measured from its mouth end (4 m)")
	assert_true(space.mouth_clear(walker, 0, 1.2), "and not the entrance")
	space.set_underground(other, false)
	space.move_resident(other, Vector2(0.0, -5.0))
	assert_false(space.mouth_clear(walker, 0, 1.2), "someone standing on the hole")


func test_a_walker_is_routed_only_through_a_bore_it_fits() -> void:
	"""Two 8 m tunnels under the wall -- a standard one straight ahead (slots 0, 1: legs 0, 2) and one
	widened end to end 3 m aside (slots 2, 3: legs 4, 6): the badger takes the wide one; a mouse the
	straight one."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -4096), Vector2i(0, 4096)])
	for slot in _open_tunnel(space, [Vector2i(3072, -4096), Vector2i(3072, 4096)]):
		space.tunnels.set_bore(slot, Rules.BORE_WIDE)
	var badger := _brain(space, Vector2(0.0, -5.0), true)
	space.tunnels.set_body(badger.index, 2611, 574)
	var mouse := _brain(space, Vector2(0.5, -5.0), true)
	badger.order_move(Vector2(0.0, 5.0))
	mouse.order_move(Vector2(0.5, 5.0))
	assert_true(badger.path_tunnel.has(4) and badger.path_tunnel.has(6), "the badger through the wide tunnel (%s)" % badger.path_tunnel)
	assert_false(badger.path_tunnel.has(0), "not the standard one")
	assert_true(mouse.path_tunnel.has(0) and mouse.path_tunnel.has(2), "the mouse the straight one (%s)" % mouse.path_tunnel)


func test_a_carrier_never_hauls_through_a_bore_its_load_does_not_fit() -> void:
	"""The badger fits a wide bore but not with a load: leaving the stockpile it never carries below."""
	var points: Array[Dictionary] = [
		{"name": &"stockpile", "position": Vector3(0.0, 0.0, -5.0), "face": Vector3.FORWARD, "activities": [&"collect_object"], "capacity": 1},
		{"name": &"north", "position": Vector3(0.0, 0.0, 5.0), "face": Vector3.BACK, "activities": [&"idle"], "capacity": 1}]
	var keys: Array = []
	for k in 31:
		keys.append([0.0, 0.02 * float(k)])
	var below := 0
	var crossed := 0
	for attempt in 12:
		var space := CastSpaceScript.new()
		space.setup(points, _wall())
		for slot in _open_tunnel(space, [Vector2i(0, -4096), Vector2i(0, 4096)]):
			space.tunnels.set_bore(slot, Rules.BORE_WIDE)
		var brain := BrainScript.new()
		brain.configure(space, WALK_M_S, BODY_M, SEED + attempt, _lengths())
		brain.set_carry_motion({"period_s": 3.0, "mean_speed_m_s": 0.2, "keys_xz": keys})
		space.tunnels.set_body(brain.index, 2611, 574)
		space.reserve(0, 0)
		brain.start_at(space.slot_position(0, 0), 0.0, 0, 0)
		_until(brain, func() -> bool: return brain.poi == 1, 90.0)
		crossed += 1 if brain.crosses_tunnel() else 0
		for f in 60 * 20:
			brain.step(DT)
			below += 1 if brain.underground and brain.carrying else 0
	assert_equal(crossed, 12, "every trip still goes through, unloaded")
	assert_equal(below, 0, "never carrying below")


func test_a_worker_standing_in_a_bore_is_passed_not_queued_behind() -> void:
	"""A task's worker standing in a 10 m tunnel's bore (slot 1, 1 m in: 5 m along the tunnel) heads neither
	way: a walker coming up behind steps aside and passes it, and comes out."""
	var space := _space(_wall())
	var chain := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var worker := _brain(space, Vector2(3.0, -8.0), true)
	worker.task_stand_in_bore(chain[1], 1.0, true)
	assert_equal(space.resident_heading[worker.index], 0, "heading neither way")
	var walker := _brain(space, Vector2(0.0, -6.0), true)
	walker.order_move(Vector2(0.0, 7.0))
	assert_true(walker.crosses_tunnel(), "through the tunnel")
	assert_true(_until(walker, func() -> bool: return walker.position.distance_to(Vector2(0.0, 7.0)) < 0.2, 30.0),
		"passed the worker and came out (%s)" % walker.position)


func test_a_walker_gives_up_a_line_that_does_not_move() -> void:
	"""Held in line behind a grant nobody gives up, a walker waits 25 s and then walks round instead."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -4096), Vector2i(0, 4096)])
	var b := _brain(space, Vector2(-1.2, -6.6), true)
	space.tunnels.queue.grant[0] = 99
	b.order_move(Vector2(-1.0, 6.0))
	assert_true(_until(b, func() -> bool: return b.state == BrainScript.State.QUEUE, 10.0), "in line")
	_step([b], 24.0)
	assert_equal(b.state, BrainScript.State.QUEUE, "still waiting at 24 s")
	_step([b], 1.5)
	assert_false(b.state == BrainScript.State.QUEUE, "gave up by 25.5 s")
	assert_false(b.crosses_tunnel(), "walking round")


func test_a_released_walker_leaves_the_line() -> void:
	"""Released while waiting in line, a walker's place is given up."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -4096), Vector2i(0, 4096)])
	var b := _brain(space, Vector2(-1.2, -6.6), true)
	space.tunnels.queue.grant[0] = 99
	b.order_move(Vector2(-1.0, 6.0))
	assert_true(_until(b, func() -> bool: return b.state == BrainScript.State.QUEUE, 10.0), "in line behind a held grant")
	assert_true(space.tunnels.queue.is_queued(0, b.index), "queued")
	b.release()
	assert_false(space.tunnels.queue.is_queued(0, b.index), "left the line")


func test_a_bare_task_ends_at_once_and_the_resident_goes_back_to_its_routine() -> void:
	"""A task that has nothing to do: the resident arrives where it stands, the task ends, it wanders."""
	var space := _space([])
	var brain := _brain(space, Vector2(1.0, 1.0), false)
	brain.order_task(TaskScript.new())
	assert_equal(brain.activity(), BrainScript.ACTIVITY_TASK, "on the task")
	assert_equal(brain.task_label(), "on an errand", "its words")
	_step([brain], 0.1)
	assert_equal(brain.order, BrainScript.ORDER_NONE, "back to its routine")
	assert_true(brain.task == null, "no task held")


func test_a_walker_in_a_tunnel_that_closes_turns_back_to_its_mouth() -> void:
	"""A 10 m tunnel: half way along it (1 m into its 2 m bore), the bore closes: the walker walks back and
	comes up at the entrance, and plans no more through the closed bore."""
	var space := _space(_wall())
	var chain := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var brain := _brain(space, Vector2(0.0, -6.0), true)
	brain.order_move(Vector2(0.0, 7.0))
	_until(brain, func() -> bool: return brain.is_in_bore(chain[1]) and brain.bore_along_m() > 1.0, 20.0)
	assert_true(brain.is_in_bore(chain[1]), "in the bore")
	space.tunnels.close(chain[1], GraphScript.CLOSED_FLOODED, 0, 2048)
	brain.turn_back(chain[1], 0.0)
	assert_true(_until(brain, func() -> bool: return not brain.underground, 10.0), "came up")
	assert_true(brain.position.distance_to(Vector2(0.0, -5.0)) < 0.01, "at the entrance (%s)" % brain.position)
	assert_false(brain.crosses_tunnel(), "and does not plan through the closed tunnel")


# --- the works -------------------------------------------------------------------------------

func _cast_of(space: CastSpaceScript, spots: Array[Vector2], species: PackedStringArray) -> Array[BrainScript]:
	"""Residents at these spots, of these species, with bodies recorded (1 m mice, a 0.9 m mole,
	a 2.55 m badger)."""
	var brains: Array[BrainScript] = []
	for i in spots.size():
		var brain := _brain(space, spots[i], true)
		var tall := 2611 if species[i] == "Badger" else (922 if species[i] == "Mole" else 1024)
		space.tunnels.set_body(brain.index, tall, 574 if species[i] == "Badger" else 225)
		brains.append(brain)
	return brains


func test_the_weather_sets_the_planners_surface_speed_each_frame() -> void:
	"""The works read the demo's one weather every frame (a paused one too): once it rains, the
	network's surface speed is the weather's 800. They never run or announce the weather themselves."""
	var space := _space([])
	var works := _works(space, _cast_of(space, [Vector2.ZERO], PackedStringArray(["Mouse"])), PackedStringArray(["Mouse"]))
	assert_true(works.weather == _services.weather, "the shared weather, not one of their own")
	assert_equal(space.tunnels.surface_permille, 1000, "spring, 06:00: clear")
	works.step(45000000)
	assert_equal(space.tunnels.surface_permille, 1000, "a long frame does not change the weather")
	_rain(works)
	works.step(0)
	assert_equal(space.tunnels.surface_permille, 800, "heavy rain")
	assert_equal(_services.notices.count(), 0, "and the works say nothing of it")


func test_nothing_moves_while_paused_and_speed_scales_exactly() -> void:
	"""A paused frame (0 usec) changes neither weather nor threats; two 1 s frames equal one 2 s."""
	var space := _space([])
	var brains := _cast_of(space, [Vector2.ZERO], PackedStringArray(["Mouse"]))
	var works := _works(space, brains, PackedStringArray(["Mouse"]))
	works.step(0)
	assert_equal(works.weather.revision, 0, "the weather untouched")
	assert_equal(works.events.next_auto_usec, EventsScript.FIRST_AUTO_USEC, "threats paused")
	works.step(1000000)
	works.step(1000000)
	var other := _works(space, brains, PackedStringArray(["Mouse"]))
	other.step(2000000)
	assert_equal(works.events.next_auto_usec, other.events.next_auto_usec, "threat schedule")


func test_a_crew_member_at_the_face_sets_the_dig_rate() -> void:
	"""The mole leads at its level 3 skill factor, 1150 (dig_skills.gd): alone the dig runs at 1150; with a
	member below at its post, at 1506 x 1150 / 1000 = 1731. The entrance ramp (x 0..4 m on row 20) is
	loam."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.0), Vector2(-3.0, 2.0)], species)
	var works := _works(space, brains, species)
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	works.step(1)
	assert_equal(space.tunnels.rate_permille[0], 1150, "alone")
	works.crew.join(1, 0)
	works.crew.set_present(1, true)
	works.step(1)
	assert_equal(space.tunnels.rate_permille[0], 1731, "a finisher behind")


## The village's T1 route through the rock pocket and on into the clay (the dig tool's test lays it too):
## (3.0, 2.8) -> (9.6, -2.48) m, 8654 u (8.45 m). Its entrance ramp cuts cells (23, 22) twice (loam),
## (24, 21) twice and (25, 20) (rock); its 0.45 m bore (26, 20) (rock); its exit ramp runs through clay
## from (26, 19) to (29, 17), where its exit shaft breaks out. Each cell is rolled once in the bore layer:
## flints in (23, 22), (24, 21) and (26, 20), the relic in (25, 20), clay in (29, 17) (tunnel_finds.gd
## rolls 192, 1351, 742, 2545 and 491; the exit ramp's other clay cells roll nothing).
const T1_ROUTE: Array[int] = [3072, 2867, 9830, -2540]


func test_digging_through_the_rock_pocket_finds_a_relic_and_yields_stone() -> void:
	"""The village's T1 route dug through: three flints, the relic in cell (25, 20) and a clay find, 3.2 U of
	stone from four rock quanta, and the relic's alert."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(0.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(PackedInt32Array(T1_ROUTE), 2, 0, ref), "T1 laid")
	var chain := PackedInt32Array()
	space.tunnels.piece_segments_into(ref[2], chain)
	for slot in chain:
		space.tunnels.start_dig(slot, space.tunnels.generation[slot], 0)
		space.tunnels.advance(slot, space.tunnels.generation[slot], 1000000000)
	works.step(1)
	assert_equal(works.stores.finds[FindsScript.FIND_FLINT], 3, "flints")
	assert_equal(works.stores.finds[FindsScript.FIND_RELIC], 1, "the relic")
	assert_equal(works.stores.finds[FindsScript.FIND_CLAY], 1, "clay")
	assert_equal(works.stores.stone_milli_u, 23200, "20 U and four rock quanta's 800")
	assert_true(_noted("A relic dug up — see the tunnel panel"), "posted")
	assert_true(_services.notices.has_text(FindsScript.relic_story(1)), "its story told")


func _wet_tunnel(works: WorksScript, space: CastSpaceScript) -> PackedInt32Array:
	"""An open 12 m tunnel along z = 0.5 m from x = 0.5 m whose bore's (slot 1, 4.5..8.5 m) middle two metres
	(cells 26, 27 of row 20) are wet sand (the works' ground overwritten); its segments."""
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [26, 27]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND | GroundScript.WET_BIT
	var chain := _open_tunnel(space, [Vector2i(512, 512), Vector2i(12800, 512)])
	works.step(1)
	return chain


func test_rain_floods_an_unbraced_wet_tunnel_with_warning_and_everyone_turns_back() -> void:
	"""In rain: a warning at 20 s, a flood at 40 s -- alerted, naming the bore (tunnel 2); a walker in the
	bore turns back; the flooded bore is marked closed until pumped, its ramps are not."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	var bore := _wet_tunnel(works, space)[1]
	_rain(works)
	works.step(1)
	brains[0].order_move(Vector2(14.0, 0.5))
	assert_true(brains[0].crosses_tunnel(), "in the rain the tunnel is quicker (3.75 + 12 = 15.75 against 18.75)")
	_until(brains[0], func() -> bool: return brains[0].is_in_bore(bore) and brains[0].bore_along_m() > 1.0, 20.0)
	works.step(20000000)
	assert_true(_warned("Tunnel 2 is seeping — brace it"), "warned")
	works.step(20000000)
	assert_true(_warned("Tunnel 2 flooded — pump it out"), "flooded")
	assert_equal(space.tunnels.closed[bore], GraphScript.CLOSED_FLOODED, "closed")
	assert_equal(space.tunnels.closed[bore - 1], GraphScript.CLOSED_NONE, "the dry ramp is not")
	var surfaced := Vector2.INF
	for f in 60 * 10:
		brains[0].step(DT)
		if not brains[0].underground:
			surfaced = brains[0].position
			break
	assert_true(surfaced.distance_to(Vector2(0.5, 0.5)) < 0.01, "came up back at the entrance (%s)" % surfaced)


func test_a_roof_holds_while_someone_is_under_it() -> void:
	"""A collapse falls due while a walker stands under the bore's sand: the roof creaks and holds; once
	nobody is under it, it falls."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [26, 27]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var bore := _open_tunnel(space, [Vector2i(512, 512), Vector2i(12800, 512)])[1]
	works.step(1)
	brains[0].task_stand_in_bore(bore, 2.0, true)
	works.hazards.strain_usec[bore] = HazardsScript.STRAIN_FULL_USEC - 1
	works._act_on(bore, works.hazards.add_crossing(bore))
	assert_equal(space.tunnels.closed[bore], GraphScript.CLOSED_NONE, "holds")
	assert_true(_warned("Tunnel 2 holds while someone is under"), "creaks")
	brains[0].task_surface_at(space.tunnels.mouth_node[0])
	assert_false(brains[0].underground, "up at the entrance")
	works._act_on(bore, HazardsScript.EVENT_COLLAPSE_DUE)
	assert_equal(space.tunnels.closed[bore], GraphScript.CLOSED_COLLAPSED, "falls once clear")


func test_a_crew_follows_the_foremole_s_work() -> void:
	"""While a segment is dug the crew's work goes on, at the entrance during the entry shaft and at the face
	after; the next segment of the piece taken up, the work goes on there, from its start (no shaft); a
	mole job's crew follows the worker below; with nothing going on, it ends."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(-3.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	assert_true(works.crew_active(0), "digging")
	assert_equal(works.crew_along(0), 0.0, "the entrance shaft: at the surface")
	@warning_ignore("integer_division") space.tunnels.dig_usec[0] = 200 * 1000000 / 30
	assert_true(works.crew_along(0) > 0.0, "the ramp: at the face (%.3f)" % works.crew_along(0))
	space.tunnels.advance(0, ref[1], 1000000000)
	assert_false(works.crew_active(0), "open: nothing going on there")
	assert_false(works.crew_active(1), "the bore not taken up yet")
	space.tunnels.start_dig(1, space.tunnels.generation[1], 0)
	assert_true(works.crew_active(1), "the bore is dug on")
	assert_equal(works.crew_along(1), 0.0, "from its start")
	works.jobs.post(0, JobsScript.JOB_WIDEN, 0, 0, 4096)
	assert_true(works.crew_active(0), "a widening")
	assert_equal(works.crew_along(0), 0.0, "its worker not yet below")
	works.jobs.pause(0)
	assert_false(works.crew_active(0), "paused: the crew stands down")


func test_a_walker_under_a_fall_s_far_side_turns_to_the_exit() -> void:
	"""A collapse closes the sand (1.5..2.5 m along the 8 m bore of a 16 m tunnel): a walker already past it
	-- though nearer the bore's start than its end -- walks on and out at the exit; one short of it turns
	back to the entrance."""
	var space := _space([])
	var species := PackedStringArray(["Mouse", "Mouse"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.5), Vector2(-3.0, 1.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [26, 27]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var bore := _open_tunnel(space, [Vector2i(512, 512), Vector2i(16896, 512)])[1]
	_rain(works)
	works.step(1)
	brains[0].order_move(Vector2(18.0, 0.5))
	brains[1].order_move(Vector2(18.0, 1.5))
	_until(brains[0], func() -> bool: return brains[0].is_in_bore(bore) and brains[0].bore_along_m() > 3.3, 30.0)
	assert_true(brains[0].bore_along_m() < 4.0, "past the fall and its half-metre margin (1.0..3.0 m), short of the middle (%.3f)" % brains[0].bore_along_m())
	_until(brains[1], func() -> bool: return brains[1].is_in_bore(bore) and brains[1].bore_along_m() > 0.3, 30.0)
	assert_false(works.hazards.in_fall(bore, brains[1].bore_along_m()), "the other short of it (%.3f)" % brains[1].bore_along_m())
	works._act_on(bore, HazardsScript.EVENT_COLLAPSE_DUE)
	assert_equal(space.tunnels.closed[bore], GraphScript.CLOSED_COLLAPSED, "fallen")
	var up := [Vector2.INF, Vector2.INF]
	for f in 60 * 15:
		for k in 2:
			brains[k].step(DT)
			if not brains[k].underground and up[k] == Vector2.INF:
				up[k] = brains[k].position
	assert_true((up[0] as Vector2).distance_to(Vector2(16.5, 0.5)) < 0.01, "past it: out at the exit (%s)" % up[0])
	assert_true((up[1] as Vector2).distance_to(Vector2(0.5, 0.5)) < 0.01, "short of it: back to the entrance (%s)" % up[1])


func test_walking_into_a_weak_bore_strains_it() -> void:
	"""The works count a walker going down an unbraced sand bore as a crossing: 8 s of strain -- once, on
	the bore; its loam ramps take none."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [26, 27]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var chain := _open_tunnel(space, [Vector2i(512, 512), Vector2i(12800, 512)])
	_rain(works)
	works.step(1)
	var strain := works.hazards.strain_usec[chain[1]]
	brains[0].order_move(Vector2(14.0, 0.5))
	assert_true(brains[0].crosses_tunnel(), "through the tunnel")
	for f in 60 * 8:
		brains[0].step(DT)
		works.step(0)
	assert_true(brains[0].is_in_bore(chain[1]), "in the bore by now")
	assert_equal(works.hazards.strain_usec[chain[1]] - strain, HazardsScript.CROSSING_STRAIN_USEC, "one crossing")
	assert_equal(works.hazards.strain_usec[chain[0]], 0, "the ramp takes none")


func test_the_foremole_speaks_up_at_rock() -> void:
	"""A dig whose face reaches rock with no badger on the crew -- T1's ramp, its third quantum in cell
	(24, 21), from 226 ticks: the Foremole says so, as a warning in the demo's notice feed carrying the
	short line."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(0.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array(T1_ROUTE), 2, 0, ref)
	for k in 3:
		@warning_ignore("integer_division") space.tunnels.dig_usec[0] = k * 100 * 1000000 / 30
		works.step(1)
	assert_false(_services.notices.has_text(CrewScript.LINE_ROCK_ALONE), "not in loam (200 ticks)")
	@warning_ignore("integer_division") space.tunnels.dig_usec[0] = 300 * 1000000 / 30
	works.step(1)
	assert_true(_services.notices.has_text(CrewScript.LINE_ROCK_ALONE), "said, in the notice feed")
	assert_true(_warned("Rock! The Foremole needs the badger"), "a warning, with its short line")
	assert_equal(space.tunnels.rate_permille[0], 287, "and it crawls: 1150 x 250 / 1000")


func test_a_widening_crew_works_side_by_side() -> void:
	"""A widening offers five faces: the Foremole (the mole, factor 1150) and one member below dig at
	2000 x 1150 / 1000 = 2300; a room's crew of four (three faces and a finisher, 3506) digs its body at 4031
	(decision 0209: a room is a piece whose body is worked at ROOM_FACES faces)."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse", "Mouse", "Mouse"])
	var works := _works(space, _cast_of(space, [Vector2.ZERO, Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)], species), species)
	works.ground.cells.fill(GroundScript.LOAM)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])[1]
	works.jobs.post(slot, JobsScript.JOB_WIDEN, 0, 0, 4096)
	works.crew.join(1, slot)
	works.crew.set_present(1, true)
	works.step(1)
	assert_equal(works.jobs.rate_permille[slot], 2300, "two faces")
	works.jobs.clear(slot)
	works.crew.disband(slot)
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(space.tunnels.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(6144, 8192), 2, 0, room), "a home")
	var body: int = space.tunnels.rooms.body[room[0]]
	space.tunnels.start_dig(body, space.tunnels.generation[body], 0)
	for i in [1, 2, 3]:
		works.crew.join(i, body)
		works.crew.set_present(i, true)
	works.step(1)
	assert_equal(space.tunnels.rate_permille[body], 4031, "a room's four")


func test_a_job_done_takes_effect_and_is_announced() -> void:
	"""A brace on a bore (tunnel 2: 4 quanta) worked to its end: the works finish it -- braced -- and raise
	its short alert."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var works := _works(space, _cast_of(space, [Vector2.ZERO], species), species)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])[1]
	works.jobs.post(slot, JobsScript.JOB_BRACE, 0, 0, 4096)
	works.jobs.start(slot)
	works.jobs.work(slot, 5000000)
	works.step(1)
	assert_equal(space.tunnels.braced[slot], 1, "braced")
	assert_true(_noted("Tunnel 2 braced"), "announced")
	assert_equal(works.stores.wood_milli_u, 39000, "paid for: 4 x 250")


func test_a_flood_by_the_stream_sends_residents_through_a_tunnel_and_home_again() -> void:
	"""The test event (a flood of the real stream at the ford) sends the resident on the east road down
	the 8 m tunnel out of the disc (in at mouth row 0, up at row 1); the one on the square stays put; when
	the water goes down the evacuee's task ends."""
	var space := _space([])
	var species := PackedStringArray(["Mouse", "Mouse"])
	var brains := _cast_of(space, [Vector2(16.0, -0.9), Vector2(0.0, -1.0)], species)
	var works := _works(space, brains, species)
	_open_tunnel(space, [Vector2i(17408, -922), Vector2i(9216, -922)])
	assert_true(works.start_test_event(), "the flood comes")
	assert_false(works.start_test_event(), "one at a time")
	assert_true(brains[0].task is EvacuateTaskScript, "the east-road mouse evacuates")
	assert_true((brains[0].task as EvacuateTaskScript).through_tunnel, "through the tunnel")
	assert_true(brains[1].task == null, "the square mouse does not")
	assert_true(_warned("Flood by the stream — evacuating"), "alerted")
	var below := false
	for f in 60 * 18:
		brains[0].step(DT)
		below = below or brains[0].underground
	assert_true(below, "went through the tunnel")
	assert_true(brains[0].position.x < 9.0, "came out beyond it (%s)" % brains[0].position)
	assert_false(brains[0].underground, "and is on the surface, not walking the ground from below")
	works.step(EventsScript.DURATION_USEC)
	assert_true(_noted("The flood has gone down"), "the all-clear")
	_step([brains[0]], 0.1)
	assert_true(brains[0].task == null, "home again: the task is over")


func test_a_job_the_stores_cannot_pay_for_sends_its_worker_home() -> void:
	"""Arriving at a brace on the entrance ramp (its node A the mouth, on the surface) with the stores emptied
	meanwhile: nothing is paid, no work is done, and the worker goes back to its routine."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.0)], species)
	var works := _works(space, brains, species)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])[0]
	works.jobs.post(slot, JobsScript.JOB_BRACE, 0, 0, 4096)
	brains[0].order_task(JobTaskScript.new(works.jobs, space.tunnels, slot))
	works.stores.wood_milli_u = 0
	_step([brains[0]], 5.0)
	assert_equal(works.jobs.paid[slot], 0, "unpaid")
	assert_equal(works.jobs.done_ticks(slot), 0, "no work")
	assert_true(brains[0].task == null, "sent home")
	assert_false(brains[0].underground, "never went down")


func _crew_of_two(space: CastSpaceScript, slot: int) -> Array:
	"""Two mice on segment `slot`'s crew, each standing 0.2 m into it: [crew, member, second]."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	crew.set_resident(1, "Mouse")
	var member := _brain(space, Vector2(0.0, 0.0), true)
	var second := _brain(space, Vector2(0.0, 1.0), true)
	for b: BrainScript in [member, second]:
		crew.join(b.index, slot)
		b.task_stand_in_bore(slot, 0.2, true)
	return [crew, member, second]


func test_a_crew_member_works_a_gap_behind_the_foremole() -> void:
	"""The first member below stands 0.9 m behind the Foremole's place along the piece, the second 1.8 m:
	with the Foremole 3.0 m into the entrance ramp, at 2.1 and 1.2 m in it (the first step takes each in);
	with it 0.5 m into the bore (4.5 m along the piece), both still in the ramp, at 3.6 and 2.7 m."""
	var space := _space([])
	var chain := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	var site := _crew_of_two(space, chain[0])
	var crew: CrewScript = site[0]
	var member: BrainScript = site[1]
	var second: BrainScript = site[2]
	var lead := [chain[0], 3.0]
	var task := CrewTaskScript.new(crew, space.tunnels, chain[0], true, Vector2(-1.0, 0.0),
		func(_s: int) -> bool: return true, func(s: int) -> float: return lead[1] if s == lead[0] else 0.0)
	for k in 2:
		assert_true(task.step(member, DT) and task.step(second, DT), "working")
	assert_near(member.bore_along_m(), 2.1, 0.0001, "0.9 m behind")
	assert_near(second.bore_along_m(), 1.2, 0.0001, "1.8 m behind")
	assert_equal(crew.member_present[0], 1, "at its post")
	crew.move_site(chain[0], chain[1])
	lead[0] = chain[1]
	lead[1] = 0.5
	assert_true(task.step(member, DT) and task.step(second, DT), "working on")
	assert_true(member.is_in_bore(chain[0]) and second.is_in_bore(chain[0]), "still in the ramp")
	assert_near(member.bore_along_m(), 3.6, 0.0001, "4.5 - 0.9 along the piece")
	assert_near(second.bore_along_m(), 2.7, 0.0001, "4.5 - 1.8")


func test_a_crew_member_stands_down_when_the_work_stops() -> void:
	"""Once the Foremole's work is over, the member's place ends (and it leaves the crew)."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])[0]
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, Vector2(-1.0, 0.0), true)
	crew.join(0, slot)
	var going := [true]
	var task := CrewTaskScript.new(crew, space.tunnels, slot, false, Vector2(-1.0, 0.0),
		func(_s: int) -> bool: return going[0], func(_s: int) -> float: return 0.0)
	member.order_task(task)
	_step([member], 0.2)
	assert_equal(member.task_label(), "Dig crew — surface hand", "at its post")
	going[0] = false
	_step([member], 0.2)
	assert_true(member.task == null, "stood down")
	assert_equal(crew.member_site[0], -1, "off the crew")


# --- the player's orders ----------------------------------------------------------------------

func _order_site() -> Array:
	"""A mole, two mice and a badger by an open 12 m tunnel along x from the origin (tunnel 1 its entrance
	ramp, slot 0; 2 its bore; 3 its exit ramp): [space, brains, works, actions]. Who can dig is who fits a
	standard bore (tunnel_ext.gd diggers_of, decision 0208): the mole and the mice, not the badger."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse", "Mouse", "Badger"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.0), Vector2(-1.0, 1.0), Vector2(6.0, 6.0), Vector2(-2.0, -2.0)], species)
	var works := _works(space, brains, species)
	_open_tunnel(space, [Vector2i(0, 0), Vector2i(12288, 0)])
	works.step(1)
	var actions := ActionsScript.new(works, space, PackedByteArray([1, 1, 1, 0]),
		PackedStringArray(["Mole digger", "Mouse keeper", "Mouse fieldworker", "Badger"]), BOUNDS_U)
	return [space, brains, works, actions]


func test_orders_are_refused_with_their_reasons() -> void:
	"""No tunnel selected; an upgrade already done; a closed tunnel; stores too short."""
	var site := _order_site()
	var space: CastSpaceScript = site[0]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	assert_false(actions.order(JobsScript.JOB_BRACE, PackedInt32Array()), "nothing selected")
	assert_equal(works.log_lines[-1], "Can't: select a finished tunnel first (click its mouth or route)", "said")
	assert_true(actions.select_at(Vector2(1.0, 0.3)), "picked by its route")
	assert_equal(actions.selected, 0, "the entrance ramp")
	space.tunnels.set_braced(0)
	assert_false(actions.order(JobsScript.JOB_BRACE, PackedInt32Array()), "already braced")
	assert_equal(works.log_lines[-1], "Can't: tunnel 1 is already braced", "said")
	space.tunnels.close(0, GraphScript.CLOSED_FLOODED, 0, 4096)
	assert_false(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array()), "closed")
	assert_equal(works.log_lines[-1], "Can't: tunnel 1 is closed — repair it first", "said")
	space.tunnels.reopen(0)
	works.stores.wood_milli_u = 499
	assert_false(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array()), "short")
	assert_equal(works.log_lines[-1], "Can't: the demo stores are short (need wood 0.5 U, stone 0.0 U)", "said")


func test_a_job_goes_to_the_selected_resident_else_the_nearest_free_one() -> void:
	"""Brace with a mouse selected: that mouse; with nobody selected: the nearest free mouse to the tunnel's
	way in (never the mole, a skilled digger kept for digging; never the badger, who does not fit)."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_BRACE, PackedInt32Array([2])), "ordered")
	assert_equal(works.jobs.worker[0], 2, "the selected mouse")
	assert_true(brains[2].task is JobTaskScript, "sent")
	assert_equal(works.log_lines[-1], "Brace: Mouse fieldworker is on the way to tunnel 1", "said")
	brains[2].release()
	works.jobs.clear(0)
	assert_true(actions.order(JobsScript.JOB_BRACE, PackedInt32Array()), "ordered again")
	assert_equal(works.jobs.worker[0], 1, "the nearer free mouse")


func test_a_job_never_goes_to_one_who_does_not_fit_or_to_the_mole_unasked() -> void:
	"""The badger selected for a brace does not fit the bore: the nearest free mouse is sent instead;
	with the mole standing nearest, still the mouse."""
	var site := _order_site()
	var space: CastSpaceScript = site[0]
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	brains[0].position = Vector2(0.3, -0.3)
	space.move_resident(0, brains[0].position)
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_BRACE, PackedInt32Array([3])), "ordered")
	assert_equal(works.jobs.worker[0], 1, "the nearest free mouse, not the badger nor the mole")


func test_nobody_digging_joins_a_crew() -> void:
	"""A resident under a dig order is left off a crew."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	brains[1].order = BrainScript.ORDER_DIG
	assert_equal(actions.add_crew(0, PackedInt32Array([1, 2]), 0), 1, "one joined")
	assert_equal(works.crew.member_site[1], -1, "not the digger")
	assert_equal(works.crew.member_site[2], 0, "the other")


func _stand_down(site: Array) -> void:
	"""Everyone on the order site back to their routine, and tunnel 1's job cleared."""
	for b: BrainScript in site[1]:
		b.release()
	(site[2] as WorksScript).jobs.clear(0)


func test_dig_work_takes_a_foremole_and_the_rest_as_crew() -> void:
	"""Widen with the mole, a mouse and the badger selected: the first selected who can dig (the mole)
	works it and both others join its crew, the badger (too big for the bore) at the surface. With a mouse
	and the badger selected, the mouse leads (anybeast who fits a bore digs, decision 0208)."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array([0, 1, 3])), "ordered")
	assert_equal(works.jobs.worker[0], 0, "the mole leads")
	assert_equal(works.crew.count_of(0), 2, "a crew of two")
	assert_equal(brains[3].task_label(), "Dig crew — surface hand", "the badger works the surface")
	_stand_down(site)
	assert_true(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array([2, 3])), "ordered again")
	assert_equal(works.jobs.worker[0], 2, "the selected mouse leads")
	assert_equal(works.crew.count_of(0), 1, "the badger its crew")


func test_dig_work_unasked_goes_to_the_most_skilled_free_digger() -> void:
	"""With nobody selected, the village's most skilled free digger leads: the mole (level 3); with the mole
	digging a tunnel, a mouse (level 0, the lower index on the tie); with every digger digging, refused."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array()), "ordered")
	assert_equal(works.jobs.worker[0], 0, "the mole")
	_stand_down(site)
	brains[0].order = BrainScript.ORDER_DIG
	assert_true(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array()), "ordered again")
	assert_equal(works.jobs.worker[0], 1, "mouse 1")
	_stand_down(site)
	for i in 3:
		brains[i].order = BrainScript.ORDER_DIG
	assert_false(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array()), "every digger is digging")
	assert_equal(works.log_lines[-1], "Can't: nobody free who fits a bore can dig it", "said")


# --- the extensions, wired into the tunnel tool -------------------------------------------------

func _tool(selection: PackedInt32Array) -> ControlScript:
	"""The tunnel tool on the placeholder cast (placeholder 0 a mole) in the demo's bounds, with the
	extensions it builds; `selection` is what is selected."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var tool := ControlScript.new()
	_nodes.append(tool)
	var camera := Camera3D.new()
	_nodes.append(camera)
	tool.configure(cast, camera, func() -> PackedInt32Array: return selection,
		func(_at: Vector3, _ok: bool) -> void: pass, _say)
	return tool


func test_a_laid_route_names_its_ground() -> void:
	"""Through the rock pocket east of the well: loam, clay and rock, and the badger's needed."""
	var tool := _tool(PackedInt32Array([0]))
	var route := PackedInt32Array([3072, 2867, 8192, -1229])
	assert_equal(tool.ext.route_ground(route, 2), "through loam 1 m, clay 2 m, rock 3 m — rock needs the badger", "T1")
	tool.begin_plan()
	assert_true(tool.ext.ground_view.plan_tint().visible, "the ground map tints the village while planning")
	tool.ext.refresh_panel()
	assert_equal(tool.ext.panel.line(&"tunnel_title"), "Laying a tunnel", "the panel says so")
	assert_equal(tool.ext.panel.line(&"tunnel"), GroundViewScript.LEGEND, "with the ground's legend")
	assert_false(tool.ext.panel.button(PanelScript.ACTION_WIDEN).visible, "and no tunnel actions")
	tool.cancel_plan()
	assert_false(tool.ext.ground_view.plan_tint().visible, "and not after")


func test_a_dig_s_cost_is_told_through_its_ground() -> void:
	"""T1 through the rock pocket and on into the clay, 8654 u (8.5 m; long enough for its ramps, decision
	0207), laid as a piece: an entrance ramp of RAMP_RUN_U (4096 u: its shaft and 4 quanta), a 0.45 m bore
	(1) and an exit ramp of RAMP_RUN_U (4 and its shaft) -- 11 quanta, as the uniform rule's shaft + 9 +
	shaft: two of loam, five of clay (147 ticks) and four of rock -- 1413 ticks, 47 s -- and
	2 x 2000 + 5 x 2400 + 4 x 1200 = 20.8 U of spoil. (Fails while underground_graph.gd rounds the exit
	ramp's foot so the ramp is stored 4097 u long and cuts a fifth bore quantum: 12 m³, 23 U, 52 s.)"""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_plan()
	assert_true(tool.lay_ground(Vector2(3.0, 2.8)), "entrance")
	assert_true(tool.lay_ground(Vector2(9.6, -2.48)), "exit")
	assert_true(tool.confirm(), "dug")
	assert_equal(_notices[-1], "Digging a 8.5 m tunnel: 11 m³ to cut, 20 U of spoil, about 47 s", "told")


func test_the_panel_shows_the_selected_tunnel_and_its_repair() -> void:
	"""A selected open segment (the entrance ramp of a 12 m tunnel: tunnel 1, 4 m): its length, bore, fit and
	hazard lines; flooded, the repair button reads
	"Pump out" and is the only one enabled; the panel's Repair orders the pump."""
	var tool := _tool(PackedInt32Array())
	var slot := _open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])[0]
	tool.ext.works.step(1)
	assert_true(tool.ext.actions.select_at(Vector2(1.0, 5.2)), "selected by its route")
	assert_equal(tool.ext.actions.selected, slot, "the entrance ramp")
	tool.ext.refresh_panel()
	assert_true(tool.ext.panel.button(PanelScript.ACTION_REPAIR).disabled, "nothing to repair")
	assert_false(tool.ext.panel.button(PanelScript.ACTION_BRACE).disabled, "brace enabled")
	assert_equal(tool.ext.panel.line(&"tunnel_title"), "Tunnel 1 — ramp, 4.0 m", "title")
	assert_equal(tool.ext.panel.line(&"tunnel"), "standard bore (1 m) · unbraced · unlit\nFits: mice, moles, squirrels, hauling too (otters and the badger need it widened)\nSafe ground (no wet or sandy stretch)", "state")
	tool.network.close(slot, GraphScript.CLOSED_FLOODED, 0, 4096)
	tool.ext.refresh_panel()
	assert_equal(tool.ext.panel.button(PanelScript.ACTION_REPAIR).text, "Pump out", "the repair")
	assert_false(tool.ext.panel.button(PanelScript.ACTION_REPAIR).disabled, "enabled")
	assert_true(tool.ext.panel.button(PanelScript.ACTION_BRACE).disabled, "the rest are not")
	tool.ext.on_action(PanelScript.ACTION_REPAIR)
	assert_equal(tool.ext.works.jobs.kind[slot], JobsScript.JOB_PUMP, "a pump ordered")


func _space_of(tool: ControlScript) -> CastSpaceScript:
	"""The cast space under a tool's network."""
	return tool._space


func test_the_panel_s_demo_buttons() -> void:
	"""Next weather runs the demo calendar through the hook it is given and says how far -- and says
	why not without one; a second test event while one runs is refused."""
	var tool := _tool(PackedInt32Array())
	tool.ext.on_action(PanelScript.ACTION_NEXT_WEATHER)
	assert_equal(_notices[-1], ExtScript.NO_SKIP, "no calendar here")
	var skips: Array[int] = []
	tool.ext.set_weather_skip(func() -> int:
		skips.append(1)
		tool.ext.works.weather.observe(0, 2, 12, 120, 1200, CoreWeather.EVENT_NONE)
		return 30)
	tool.ext.on_action(PanelScript.ACTION_NEXT_WEATHER)
	assert_equal(skips.size(), 1, "the hook ran once")
	assert_equal(_notices[-1], "Skipped 30 h ahead on the demo calendar: Rain — Spring 2, 12.0 °C · rain 06:00–23:59 · walking outdoors at 80%, tunnels unaffected", "said")
	tool.ext.on_action(PanelScript.ACTION_EVENT)
	assert_true(tool.ext.works.events.active, "a threat")
	tool.ext.on_action(PanelScript.ACTION_EVENT)
	assert_equal(_notices[-1], "A demo event is already under way", "one at a time")


func _key_event(code: Key, shift: bool = false) -> InputEventKey:
	"""A key press."""
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.shift_pressed = shift
	key.pressed = true
	return key


func test_the_room_tool_lays_a_home_with_its_passage() -> void:
	"""In the Dig tool, H opens the home tool; R turns the ghost; north of a tunnel's bore (z 5 m) the ghost
	offers its passage to its south socket; a click lays the room and the passage -- the room first in the
	mole's job list -- and the mole goes to dig; Esc goes back to laying tunnels (decision 0209)."""
	var tool := _tool(PackedInt32Array([0]))
	var chain := _open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])
	tool.ext.works.step(1)
	assert_true(tool.begin_plan(), "the Dig tool")
	assert_true(tool.handle_input(_key_event(KEY_H)), "H")
	assert_true(tool.room.active and tool.room.plan.kind == RoomsScript.TEMPLATE_HOME, "the home tool")
	tool.room.move_to(Vector2(6.0, 10.0))
	for k in 2:
		assert_true(tool.handle_input(_key_event(KEY_R)), "R")
	assert_equal(tool.room.plan.turns, 2, "turned twice: its door north")
	assert_equal(tool.room.plan.refusal, RoomsScript.REFUSE_NONE, "may be dug")
	assert_true(tool.room.words().contains("passage 3.0 m to Tunnel %d" % (chain[1] + 1)), "its passage: %s" % tool.room.words())
	assert_true(tool.room.place(false), "laid")
	var network: GraphScript = tool.network
	assert_true(network.rooms.is_room(0), "room 0")
	var list := PackedInt32Array()
	network.job_list_into(list)
	assert_equal(list.size(), 2, "the room and its passage")
	assert_equal(network.piece_room[list[0]], 0, "the room first")
	assert_equal(tool._brain(0).dig_tunnel, network.rooms.ramp[0], "the mole goes to dig its door ramp")
	assert_true(_notices[-1].begins_with("Burrow home 1 laid:") and _notices[-1].contains("then its passage"), "said: %s" % _notices[-1])
	assert_true(tool.handle_input(_key_event(KEY_ESCAPE)), "Esc")
	assert_false(tool.room.active, "back to tunnels")
	assert_true(tool.planning, "the Dig tool still open")


func test_the_panel_names_the_room_being_placed() -> void:
	"""While the room tool is out the panel's heading names its template; back to tunnels, or the Dig tool
	closed, it says tunnels again."""
	var tool := _tool(PackedInt32Array([0]))
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	assert_equal(tool.ext._planning_heading(), "Placing a burrow home", "named")
	tool.end_room()
	assert_equal(tool.ext._planning_heading(), "Laying a tunnel", "back to tunnels")
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_CELLAR), "the cellar tool")
	assert_equal(tool.ext._planning_heading(), "Placing a root cellar", "named")
	tool.cancel_plan()
	assert_equal(tool.ext.placing_room, RoomsScript.TEMPLATE_NONE, "closing the Dig tool forgets the room")


func test_room_blueprint_review_and_discard_never_order_work() -> void:
	"""Holding, rotating and cancelling a blueprint leave all existing graph, worker and stock state intact."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(-10.0, -10.0))
	var revision := tool.network.revision
	var stock := tool.ext.works.stores.stock_line()
	var work := tool._brain(0).dig_tunnel
	assert_true(tool.room.stage(true), "valid room held for review")
	assert_true(tool.room.pending, "a draft, not a project")
	tool.room.turn(1)
	tool.room.move_to(Vector2(10.0, 10.0))
	assert_equal(tool.room.plan.centre_u, Vector2i(-10240, -10240), "hover cannot move a held blueprint")
	assert_equal(tool.network.revision, revision, "no world mutation")
	assert_equal(tool._brain(0).dig_tunnel, work, "no worker interrupted")
	assert_equal(tool.ext.works.stores.stock_line(), stock, "no materials spent")
	assert_true(tool.ext.panel.button(PanelScript.ACTION_ROOM_CONFIRM).visible, "explicit confirm action")
	tool.ext.panel.action.emit(PanelScript.ACTION_ROOM_DISCARD)
	assert_false(tool.room.pending, "discard resolves the draft")
	assert_true(tool.room.active, "only one Escape level")
	assert_equal(tool.network.revision, revision, "discard is also pure")
	assert_false(tool.room.confirm(), "discarded blueprint cannot be submitted")
	var drawn := tool.room.ghost_draws
	tool.room.move_to(Vector2(-10.0, -10.0))
	assert_equal(tool.room.ghost_draws, drawn + 1, "the same site redraws after discard instead of staying invisible")
	assert_true(tool.room._fill_below.visible, "the clipped grid is visible again")


func test_room_blueprint_confirmation_orders_once_and_completes_empty() -> void:
	"""One explicit confirmation starts the existing excavation; repeat confirmation creates no duplicate."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(6.0, 10.0))
	assert_false(tool.room.confirm(), "hover alone is not a held blueprint")
	assert_true(tool.room.stage(true), "held")
	assert_true(tool.handle_input(_key_event(KEY_ENTER)), "Enter reaches the room tool")
	assert_true(tool.network.rooms.is_room(0), "room ordered: %s" % tool.notice())
	assert_false(tool.room.pending, "confirmation consumed the draft")
	assert_false(tool.room.confirm(), "a second confirmation has nothing to order")
	assert_equal(tool.network.rooms.template.count(RoomsScript.TEMPLATE_HOME), 1, "exactly one room")
	assert_false(tool.network.rooms.is_done(tool.network, 0), "ordering does not complete excavation")
	assert_equal(tool._brain(0).dig_tunnel, tool.network.rooms.ramp[0], "worker assigned to the actual entrance")
	var chain := PackedInt32Array()
	tool.network.piece_segments_into(tool.network.rooms.piece[0], chain)
	for slot in chain:
		if not tool.network.is_open(slot):
			tool.network.start_dig(slot, tool.network.generation[slot], 0)
			tool.network.advance(slot, tool.network.generation[slot], 1000000000)
	assert_true(tool.network.rooms.is_done(tool.network, 0), "existing work completes the shell")
	for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
		assert_equal(tool.network.fit.phase_of(tool.network, 0, f), 0, "no furnishing orders inherited from the blueprint")


func test_room_blueprint_rechecks_a_new_obstacle_and_retains_the_draft() -> void:
	"""An intervening obstruction refuses confirmation without losing the draft or dispatching its worker."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(-10.0, -10.0))
	assert_true(tool.room.stage(true), "initially valid")
	_space_of(tool).set_heap(0, Vector3(-10.0, 1.0, -10.0))
	assert_false(tool.room.confirm(), "fresh obstacle blocks the order")
	assert_true(tool.room.pending, "draft survives a refusal")
	assert_false(tool.network.rooms.is_room(0), "no partial room")
	assert_equal(tool._brain(0).dig_tunnel, -1, "no worker dispatched")
	assert_true(tool.ext.panel.button(PanelScript.ACTION_ROOM_CONFIRM).disabled, "visible refusal disables confirm")
	tool.ext.panel.action.emit(PanelScript.ACTION_ROOM_MOVE)
	assert_false(tool.room.pending, "Move resumes positioning")
	assert_true(tool.room.active, "same room tool")
	tool.room.move_to(Vector2(10.0, 10.0))
	assert_equal(tool.room.plan.centre_u, Vector2i(10240, 10240), "position can now change")


func test_room_blueprint_cannot_silently_change_type_or_level() -> void:
	"""Type/view changes cannot retarget a held blueprint; explicit cancel unwinds one layer."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(-10.0, -10.0))
	tool.room.stage(true)
	tool.begin_room(RoomsScript.TEMPLATE_CELLAR)
	tool.show_level(Rules.LEVEL_2)
	assert_equal(tool.room.plan.kind, RoomsScript.TEMPLATE_HOME, "type unchanged")
	assert_equal(tool.view.level, Rules.TOP_LEVEL, "view stays with the draft")
	assert_equal(tool.room.plan.level, Rules.TOP_LEVEL, "draft stays on its level")
	tool.cancel_plan()
	assert_false(tool.room.pending, "B discards the held draft first")
	assert_true(tool.planning and tool.room.active, "room tool remains open")
	tool.cancel_plan()
	assert_false(tool.planning, "next B closes it")
	assert_false(tool.ext.panel.blueprint_shown(), "no abandoned review controls")


func test_room_blueprint_changed_auto_passage_requires_a_second_review() -> void:
	"""A new nearby tunnel must not silently change the connection that confirmation orders."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(6.0, 10.0))
	tool.room.turn(2)
	assert_true(tool.room.stage(false), "room held before any tunnel exists")
	assert_equal(tool.room.plan.passage.count, 0, "initially standalone")
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])
	assert_false(tool.room.confirm(), "new passage first needs review")
	assert_true(tool.room.pending, "updated blueprint still held")
	assert_equal(tool.room.plan.passage.count, 2, "new passage is displayed")
	assert_false(tool.network.rooms.is_room(0), "nothing ordered before the player reviews it")
	assert_true(tool.room.confirm(), "the reviewed connection can now be ordered")
	var pieces := PackedInt32Array()
	tool.network.job_list_into(pieces)
	assert_equal(pieces.size(), 2, "room plus passage queued together")


func test_room_blueprint_connection_generation_is_part_of_its_review() -> void:
	"""Reusing a connection row at the same point does not bypass the new-connection review."""
	var tool := _tool(PackedInt32Array([0]))
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.move_to(Vector2(6.0, 10.0))
	tool.room.turn(2)
	assert_true(tool.room.stage(false), "held with a valid passage")
	var ref: int = tool.room.plan.passage.snap_ref[0]
	assert_true(ref >= 0, "a real network connection")
	tool.network.generation[ref] += 1
	assert_false(tool.room.confirm(), "changed generation requires another review")
	assert_false(tool.network.rooms.is_room(0), "no room dispatched against the old reference")
	assert_true(tool.room.pending, "draft remains reviewable")


func test_lower_room_blueprint_is_not_retargeted_by_hiding_the_underground_view() -> void:
	"""Even an invalid lower-level draft keeps its level until explicitly discarded."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.show_level(Rules.LEVEL_2)
	tool.room.move_to(Vector2(6.0, 10.0))
	assert_false(tool.room.stage(false), "no lower-level approach exists yet")
	tool.toggle_view()
	assert_true(tool.view.on, "U cannot silently turn a lower draft into a surface entrance")
	assert_equal(tool.room.plan.level, Rules.LEVEL_2, "lower draft preserved")
	assert_true(tool.room.pending, "draft retained")
	tool.room.discard_blueprint()
	tool.toggle_view()
	assert_false(tool.view.on, "explicit discard permits returning to the surface")


func test_the_room_tool_says_why_a_room_may_not_go() -> void:
	"""Over a tunnel's bore the ghost is refused in words, and a click lays nothing and says why; Shift+click
	lays a standalone room; C switches to the cellar tool and C again goes back to tunnels."""
	var tool := _tool(PackedInt32Array([0]))
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])
	tool.ext.works.step(1)
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool, opening the Dig tool")
	tool.room.move_to(Vector2(6.0, 6.0))
	assert_equal(tool.room.plan.refusal, RoomsScript.REFUSE_NEAR_TUNNEL, "too near the tunnel")
	assert_equal(tool.room.words(), RoomsScript.reason_text(RoomsScript.REFUSE_NEAR_TUNNEL), "said beside the pointer")
	assert_false(tool.room.place(false), "refused")
	assert_equal(_notices[-1], "Can't dig a room there: " + RoomsScript.reason_text(RoomsScript.REFUSE_NEAR_TUNNEL), "and said")
	assert_false(tool.network.rooms.is_room(0), "nothing laid")
	tool.room.move_to(Vector2(-10.0, -10.0))
	assert_true(tool.room.place(true), "a standalone home")
	var list := PackedInt32Array()
	tool.network.job_list_into(list)
	assert_equal(list.size(), 1, "no passage")
	assert_true(tool.handle_input(_key_event(KEY_C)), "C")
	assert_equal(tool.room.plan.kind, RoomsScript.TEMPLATE_CELLAR, "the cellar tool")
	assert_true(tool.handle_input(_key_event(KEY_C)), "C again")
	assert_false(tool.room.active, "back to tunnels")


# --- the panel --------------------------------------------------------------------------------

func _panel() -> PanelScript:
	"""The tunnel panel, built out of the tree."""
	var panel := PanelScript.new()
	_nodes.append(panel)
	panel.build()
	return panel


func test_the_panel_sits_in_the_detail_zone() -> void:
	"""Inset 10 px inside the HUD's detail zone, ending 8 px above the command strip, which runs under
	the zone's foot at both sizes (journal closed): 996 - 8 - 10 - 138 = 840 tall at 1080p (the strip
	reaches x 1552, the zone starts at 1520), 636 - 8 - 10 - 138 = 480 at 720p."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	assert_equal(PanelScript.placement(1920, 1080, layout, geometry), Rect2(1530.0, 138.0, 364.0, 840.0), "1080p")
	assert_equal(PanelScript.placement(1280, 720, layout, geometry), Rect2(938.0, 138.0, 316.0, 480.0), "720p")


func test_the_panel_shows_and_enables_what_it_is_told() -> void:
	"""Standing lines; no tunnel: its prompt and no actions; a tunnel: its lines and enabled actions."""
	var panel := _panel()
	panel.show_status("w", "s", "h", "f", "l")
	assert_equal(panel.line(&"weather"), "w", "weather")
	assert_equal(panel.line(&"log"), "l", "log")
	panel.show_tunnel("", "", "", {})
	assert_equal(panel.line(&"tunnel_title"), PanelScript.NO_TUNNEL, "the prompt")
	assert_false(panel.button(PanelScript.ACTION_BRACE).visible, "no actions without a tunnel")
	panel.show_tunnel("Tunnel 1 — 2.0 m", "x", "Pump out", {PanelScript.ACTION_REPAIR: true})
	assert_true(panel.button(PanelScript.ACTION_BRACE).visible, "actions shown")
	assert_true(panel.button(PanelScript.ACTION_BRACE).disabled, "brace not enabled")
	assert_false(panel.button(PanelScript.ACTION_REPAIR).disabled, "repair enabled")
	assert_equal(panel.button(PanelScript.ACTION_REPAIR).text, "Pump out", "its words")
	assert_equal(panel.button(PanelScript.ACTION_WIDEN).focus_mode, Control.FOCUS_ALL, "takes keyboard focus (decision 0261)")
	assert_false(panel.has_button(PanelScript.ACTION_EVENT), "the test event is the Demo Lab's, not the panel's")


func test_the_panel_s_buttons_emit_their_action() -> void:
	"""Pressing a button emits its action's name."""
	var panel := _panel()
	var heard: Array[StringName] = []
	panel.action.connect(func(name: StringName) -> void: heard.append(name))
	panel.button(PanelScript.ACTION_BRACE).pressed.emit()
	panel.button(PanelScript.ACTION_WIDEN).pressed.emit()
	assert_equal(heard, [&"brace", &"widen"] as Array[StringName], "heard")


func test_the_panel_s_text_is_legible() -> void:
	"""Ink and umber on parchment, cream on wood: each clears 4.5:1."""
	var parchment := PackedColorArray([Palette.face_dark(Palette.SURFACE_PARCHMENT), Palette.face_light(Palette.SURFACE_PARCHMENT)])
	var wood := PackedColorArray([Palette.face_dark(Palette.SURFACE_WOOD), Palette.face_light(Palette.SURFACE_WOOD)])
	assert_true(Contrast.worst_ratio(Palette.INK, parchment) >= 4.5, "ink on parchment")
	assert_true(Contrast.worst_ratio(Palette.UMBER, parchment) >= 4.5, "umber on parchment")
	assert_true(Contrast.worst_ratio(Palette.text_on(Palette.SURFACE_WOOD), wood) >= 4.5, "cream on wood")


func test_the_party_panel_words_the_new_states() -> void:
	"""Hauling below, waiting in a line, and a task's own words."""
	assert_equal(PartyPanelScript.state_text(BrainScript.ACTIVITY_TUNNEL, BrainScript.CLIP_CARRY, ""), "Hauling through tunnel", "hauling")
	assert_equal(PartyPanelScript.state_text(BrainScript.ACTIVITY_TUNNEL, BrainScript.CLIP_WALK, ""), "Using tunnel", "walking")
	assert_equal(PartyPanelScript.state_text(BrainScript.ACTIVITY_QUEUE, BrainScript.CLIP_IDLE, ""), "Waiting at a tunnel mouth", "queue")
	assert_equal(PartyPanelScript.state_text(BrainScript.ACTIVITY_TASK, BrainScript.CLIP_IDLE, "Dig crew"), "Dig crew", "task")


# --- the drawings -----------------------------------------------------------------------------

func test_the_ground_map_image() -> void:
	"""Rock grey, clay rust, wet ground tinted blue; plain loam left clear in the planning tint."""
	var ground := GroundScript.new()
	var tint := GroundViewScript.image_of(ground, 0.0)
	var strata := GroundViewScript.image_of(ground, 1.0)
	assert_equal(tint.get_width(), 40, "a pixel a cell")
	assert_true(_same_colour(tint.get_pixel(25, 21), GroundViewScript.COLOURS[GroundScript.ROCK]), "rock, to 8 bits")
	assert_almost_equal(tint.get_pixel(20, 20).a, 0.0, "plain loam clear in the tint")
	assert_almost_equal(strata.get_pixel(20, 20).a, 1.0, "and opaque as strata")
	var wet := GroundViewScript.colour_of(GroundScript.SAND | GroundScript.WET_BIT)
	assert_true(wet.is_equal_approx(GroundViewScript.COLOURS[GroundScript.SAND].lerp(GroundViewScript.WET_TINT, 0.45)), "wet sand")


func test_the_ground_view_shows_where_it_should() -> void:
	"""The tint while planning, on the surface's marks layer (the U view shows the ground as its cap's
	strata instead: decision 0206); nothing otherwise."""
	var view := GroundViewScript.new()
	_nodes.append(view)
	view.configure(GroundScript.new())
	assert_false(view.plan_tint().visible, "nothing to start")
	view.set_planning(true)
	assert_true(view.plan_tint().visible, "tint while planning")
	assert_equal(view.plan_tint().layers, Layers.SURFACE_MARKS, "a surface mark: the U view never draws it")
	view.set_planning(false)
	assert_false(view.plan_tint().visible, "and not after")


func _marked_tunnel() -> Array:
	"""An open 16 m tunnel along x from the origin -- ramp 0..4 m (slot 0), level bore 4..12 m (slot 1),
	ramp 12..16 m (slot 2) -- its hazards and its marks: [network, marks]."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([0, 0, 16384, 0]), 2, 0, ref), "stored")
	var hazards := HazardsScript.new(network)
	for slot in 3:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
		hazards.survey(slot)
	var marks := MarksScript.new()
	_nodes.append(marks)
	marks.configure(network, hazards)
	return [network, marks]


func test_the_marks_follow_the_tunnel_s_state() -> void:
	"""Per segment: selected, a brass line; flooded, water; collapsed, fallen earth over the section's
	middle (the bore's 3072..5120 u: 4096 u in, x 8 m); nothing on a plain one."""
	var site := _marked_tunnel()
	var network: GraphScript = site[0]
	var marks: MarksScript = site[1]
	marks.refresh()
	assert_false(marks.line(1).visible or marks.water(1).visible or marks.fall(1).visible, "plain")
	marks.select(1)
	marks.refresh()
	assert_true(marks.line(1).visible, "selected")
	assert_false(marks.line(0).visible, "only the selected segment")
	assert_true(marks.line_below(1).visible and marks.line_below(1).mesh == marks.line(1).mesh, "in the U view too, the same line")
	assert_almost_equal(marks.line_below(1).position.y, Layers.FLOOR_Y_M, "on the level's floor")
	network.close(1, GraphScript.CLOSED_FLOODED, 0, 8192)
	marks.refresh()
	assert_true(marks.water(1).visible, "water")
	assert_false(marks.water(0).visible, "not in the ramp")
	network.close(1, GraphScript.CLOSED_COLLAPSED, 3072, 5120)
	marks.refresh()
	assert_false(marks.water(1).visible, "no water now")
	assert_true(marks.fall(1).visible, "fallen earth")
	assert_true(marks.fall(1).position.is_equal_approx(Vector3(8.0, -0.02, 0.0)), "over the section's middle (%s)" % marks.fall(1).position)


func test_braces_and_lanterns_show_underground() -> void:
	"""Braced and lit, a frame every metre where a segment is wholly under the ground and a lantern every
	started 4 m, placed when it is braced and lit and drawn on the underground layer only (decisions 0206,
	0207): the level bore's metres 0..8 (nine frames, two lanterns); a ramp only past its open cutting (its
	first 2.94 m from the mouth): the entrance ramp's metres 3 and 4, the exit ramp's 0 and 1, and one
	lantern each."""
	var site := _marked_tunnel()
	var network: GraphScript = site[0]
	var marks: MarksScript = site[1]
	marks.refresh()
	assert_false(marks.frames(1).visible, "none before it is braced")
	for slot in 3:
		network.set_braced(slot)
		network.set_lit(slot)
	marks.refresh()
	assert_true(marks.frames(1).visible, "frames below")
	assert_equal(marks.frames(1).layers, Layers.UNDERGROUND, "on the underground layer")
	var frames: Array[int] = []
	var lanterns: Array[int] = []
	for slot in 3:
		frames.append(marks.frames(slot).multimesh.visible_instance_count)
		lanterns.append(marks.lanterns(slot).multimesh.visible_instance_count)
	assert_equal(frames, [2, 8, 1] as Array[int], "ramps past their cutting, the bore every metre, none doubled at a foot")
	assert_equal(lanterns, [1, 2, 1] as Array[int], "one per started 4 m")


func _room_view(space: CastSpaceScript) -> RoomViewScript:
	"""The rooms' drawing over `space`'s network, with its own marks (out of the tree)."""
	var marks := MarksScript.new()
	_nodes.append(marks)
	marks.configure(space.tunnels, null, PropsScript.new())
	var view := RoomViewScript.new()
	_nodes.append(view)
	view.configure(space.tunnels, PropsScript.new(), space, marks)
	return view


func test_the_room_drawings() -> void:
	"""A laid root cellar is outlined and named "(planned)" in both views, with no shell; dug part way its
	shell is built at a stage; dug, it names itself, its shell is built once more with its fit-out, its frames
	(its door and two sockets) under a ring beam and its lantern below, its mound, earth face and hatch
	above. Its mound stands as obstacles from the moment it is laid, and wears the village ground's material.
	Another room laid rebuilds nothing of it; neither does a second refresh."""
	var space := _space([])
	var view := _room_view(space)
	var turf := StandardMaterial3D.new()
	view.set_turf(turf)
	var network := space.tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	var obstacles := space.obstacles.size()
	assert_true(network.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(2048, 4096), 0, 0, ref), "a cellar")
	view.refresh()
	_check_planned_cellar(view, space, obstacles + 3)
	var body: int = network.rooms.body[ref[0]]
	_dig_ramp_and_half_the_body(network, ref, body)
	view.refresh()
	assert_equal(view.shell_builds, 1, "a stage built")
	assert_equal(view.furniture(0).get_child_count(), 0, "no fit-out while it is dug")
	assert_false(view.above(0).visible, "nor a mound yet")
	assert_true(view.below(0).visible and view.label(0).text.contains("digging"), "digging: %s" % view.label(0).text)
	network.advance(body, network.generation[body], 1000000000)
	view.refresh()
	_check_dug_cellar(view, space, obstacles + 3, turf)
	var other := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-8192, 4096), 0, 0, other)
	view.refresh()
	view.refresh()
	assert_equal(view.shell_builds, 2, "nothing rebuilt")


func test_a_room_s_mound_stands_as_obstacles_from_laying_to_release() -> void:
	"""A laid cellar's mound is two circles along its length and its hood a third, set once (one rebuild of the
	obstacles); another room laid rebuilds them once more for its own mound only, and a dig begun and paused none; the
	cellar's row released takes its circles away."""
	var space := _space([])
	var view := _room_view(space)
	var network := space.tunnels
	var obstacles := space.obstacles.size()
	var builds := space.obstacle_builds
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(2048, 4096), 0, 0, ref)
	view.refresh()
	assert_equal(space.obstacle_builds, builds + 1, "set once")
	var circles := view.mound_circles(0)
	var half := RoomViewScript.mound_half(RoomsScript.TEMPLATE_CELLAR, 0)
	assert_almost_equal(absf(circles[1].z - circles[0].z), 2.0 * (half.y - half.x), "two circles along its 4 m")
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-8192, 4096), 0, 0, PackedInt32Array([0, 0, 0, 0, 0]))
	view.refresh()
	assert_equal(space.obstacle_builds, builds + 2, "the other's mound only")
	network.start_dig(ref[3], ref[4], 0)
	network.advance(ref[3], ref[4], 2000000)
	network.stop_digging(ref[3], ref[4])
	view.refresh()
	assert_true(view.room_key(0) != -1 and network.phase[ref[3]] == GraphScript.PHASE_PAUSED, "paused: redrawn")
	assert_equal(space.obstacle_builds, builds + 2, "its dig begun and paused moves no obstacle")
	network.rooms.release(0)
	view.refresh()
	assert_equal(space.obstacles.size(), obstacles + 2, "released, only the home's mound and hood stand")


func test_a_room_s_shell_grows_while_it_is_dug() -> void:
	"""Its body dug a hundredth of the way, a room is at its first stage (not none) and built once; dug on to half
	way with no other change to the network it is built again at its third stage, its name counting."""
	var space := _space([])
	var view := _room_view(space)
	var network := space.tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(2048, 4096), 0, 0, ref)
	var body: int = network.rooms.body[ref[0]]
	network.start_dig(ref[3], ref[4], 0)
	network.advance(ref[3], ref[4], 1000000000)
	network.start_dig(body, network.generation[body], 0)
	@warning_ignore("integer_division") network.advance(body, network.generation[body], network.total_ticks(body) * Rules.USEC_PER_SECOND / 3000)
	view.refresh()
	assert_true(network.rooms.dug_permille(network, ref[0]) in range(1, 50), "a little dug")
	assert_equal([view.stage(0), view.shell_builds], [1, 1], "its first stage, built")
	var revision := network.revision
	@warning_ignore("integer_division") network.advance(body, network.generation[body], network.total_ticks(body) * Rules.USEC_PER_SECOND / 60)
	view.refresh()
	assert_equal(network.revision, revision, "digging moved no revision")
	assert_equal([view.stage(0), view.shell_builds], [3, 2], "half dug: built again at its third stage")
	var ramp_ticks := network.total_ticks(ref[3])
	@warning_ignore("integer_division") var percent := (ramp_ticks + network.done(body)) * 100 / (ramp_ticks + network.total_ticks(body))
	assert_equal(view.percent_dug(0), percent, "its ramp and body dug, of both")
	assert_equal(view.label(0).text, "Burrow home 1 (digging %d%%)" % percent, "counting")


func test_the_ghost_names_a_ramp_s_foot_and_sits_its_words_over_its_middle() -> void:
	"""Over an 8 m tunnel (two ramps, no bore) the home's passage joins the ramps' foot, and the ghost says so;
	its words stand over the ghost's middle, not the pointer's side."""
	var tool := _tool(PackedInt32Array([0]))
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(8192, 5120)])
	tool.ext.works.step(1)
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	tool.room.turn(2)
	tool.room.move_to(Vector2(4.0, 10.0))
	assert_true(tool.room.words().contains("passage 3.0 m to a ramp's foot"), "said: %s" % tool.room.words())
	var at := tool.room.label().position
	assert_equal(Vector2(at.x, at.z), Vector2(4.0, 10.0), "over its middle")


func test_the_ghost_is_drawn_only_when_it_moves_turns_or_its_site_changes() -> void:
	"""Hovering on within one lattice point draws nothing new; a step to the next, a turn, or a heap set on the
	ground (the site taken afresh, with the heap in it) draws it again."""
	var tool := _tool(PackedInt32Array([0]))
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	tool.room.move_to(Vector2(6.0, 10.0))
	var drawn := tool.room.ghost_draws
	tool.room.move_to(Vector2(6.05, 10.05))
	assert_equal(tool.room.ghost_draws, drawn, "the same lattice point: not drawn again")
	tool.room.move_to(Vector2(6.25, 10.0))
	tool.room.turn(1)
	assert_equal(tool.room.ghost_draws, drawn + 2, "moved, then turned")
	var circles := tool.room.site().circles_u.size()
	_space_of(tool).set_heap(0, Vector3(-9.0, 1.0, -9.0))
	tool.room.move_to(Vector2(6.25, 10.0))
	assert_equal(tool.room.ghost_draws, drawn + 3, "a heap set: drawn again")
	assert_equal(tool.room.site().circles_u.size(), circles + 3, "against a site holding the heap")


func test_a_mound_faces_its_door_and_the_prewarm_stands_under_the_view() -> void:
	"""A home turned once has its door east: its mound's way out (-Z) points east. The prewarm's samples stand
	3 m under the ground 12 m ahead of the camera."""
	var space := _space([])
	var view := _room_view(space)
	var network := space.tunnels
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(2048, 4096), 1, 0, ref)
	for slot: int in [ref[3], network.rooms.body[ref[0]]]:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	view.refresh()
	var out := -(view.above(0).get_child(0) as Node3D).transform.basis.z
	assert_true(out.is_equal_approx(Vector3.RIGHT), "its way out east: %s" % out)
	var camera := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.0, 20.0, 2.0))
	assert_true(RoomViewScript.under_view(camera).is_equal_approx(Vector3(-11.0, -3.0, 2.0)), "under the view")


func test_a_room_dug_out_says_so_once_and_its_walks_say_nothing() -> void:
	"""A home and a cellar laid and dug through: each says once that it is dug -- the room's own words, not a
	tunnel's -- and its walks, opened with its body, add nothing."""
	var tool := _tool(PackedInt32Array([0]))
	var network: GraphScript = tool.network
	for spec: Array in [[RoomsScript.TEMPLATE_HOME, Vector2i(2048, 8192)], [RoomsScript.TEMPLATE_CELLAR, Vector2i(-8192, 8192)]]:
		var ref := PackedInt32Array([0, 0, 0, 0, 0])
		assert_true(network.add_room(spec[0], spec[1], 0, 0, ref), "laid")
		tool._process(0.016)
		var before := _notices.size()
		for slot: int in [ref[3], network.rooms.body[ref[0]]]:
			network.start_dig(slot, network.generation[slot], 0)
			network.advance(slot, network.generation[slot], 1000000000)
		tool._process(0.016)
		assert_equal(Array(_notices.slice(before)), [ControlScript.ROOM_OPEN[spec[0]]], "%s: said once, in its words" % RoomsScript.NAMES[spec[0]])


func test_a_room_is_checked_against_a_heap_set_under_a_still_pointer() -> void:
	"""The ghost may go; a heap set on its mound without the pointer moving: the click refuses it."""
	var tool := _tool(PackedInt32Array([0]))
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	tool.room.move_to(Vector2(6.0, 10.0))
	assert_equal(tool.room.plan.refusal, RoomsScript.REFUSE_NONE, "may go")
	_space_of(tool).set_heap(0, Vector3(6.0, 1.0, 10.0))
	assert_false(tool.room.place(true), "refused at the click")
	assert_equal(tool.room.plan.refusal, RoomsScript.REFUSE_SURFACE_BLOCKED, "on the heap")


func test_the_room_tool_takes_its_site_afresh_after_a_room_is_laid() -> void:
	"""With the home tool open, a home laid standalone: the next check is against a site holding its door (a
	mouth to keep clear), not the one the tool opened with."""
	var tool := _tool(PackedInt32Array([0]))
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	tool.room.move_to(Vector2(6.0, 10.0))
	var before := tool.room.site().spots_u.size()
	assert_true(tool.room.place(true), "laid standalone")
	tool.room.move_to(Vector2(-6.0, 10.0))
	var hole := tool.network.rooms.mouth_u(0)
	var spots := tool.room.site().spots_u
	assert_true(spots.size() > before, "more to keep clear")
	var found := false
	@warning_ignore("integer_division") for i in spots.size() / 3:
		found = found or (spots[3 * i] == hole.x and spots[3 * i + 2] == hole.y)
	assert_true(found, "its door among them")


func test_a_room_whose_reviewed_passage_fails_is_not_partly_ordered() -> void:
	"""Six node rows free: the home and its proposed passage each fit alone, but once the home takes them the
	passage has no row for its junction: refuse the whole room, with no worker sent or standalone fallback."""
	var tool := _tool(PackedInt32Array([0]))
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(12288, 5120)])
	tool.ext.works.step(1)
	var network: GraphScript = tool.network
	var free := network.node_kind.count(GraphScript.NODE_FREE)
	for n in network.node_kind.size():
		if network.node_kind[n] == GraphScript.NODE_FREE and free > 6:
			network.node_kind[n] = GraphScript.NODE_JUNCTION
			free -= 1
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_HOME), "the home tool")
	tool.room.move_to(Vector2(6.0, 10.0))
	tool.room.turn(2)
	assert_true(tool.room.plan.passage.count == 2, "a passage proposed: %s" % tool.room.words())
	assert_true(tool.room.stage(false), "the proposed passage is reviewed")
	assert_false(tool.room.confirm(), "no capacity for the whole order")
	assert_true(_notices[-1].contains("the room was not ordered"), "said: %s" % _notices[-1])
	assert_false(network.rooms.is_room(0), "room allocation rolled back")
	assert_equal(tool._brain(0).dig_tunnel, -1, "no worker sent")
	assert_true(tool.room.pending, "blueprint retained for correction")


func test_the_rooms_pieces_on_the_ground_are_sampled_for_the_prewarm() -> void:
	"""Eight samples on the surface layer -- the mound in the ground's material, its earth face, a board in the
	doors' timber, and the fit-out's chimney (its stone collar, clay pot and rim, its soot) and a puff of its smoke
	(decision 0210) -- under the ground, and gone after."""
	var space := _space([])
	var view := _room_view(space)
	var turf := StandardMaterial3D.new()
	view.set_turf(turf)
	view.begin_surface_prewarm()
	var samples := view.surface_samples()
	assert_equal(samples.get_child_count(), 8, "eight samples")
	assert_true(samples.position.y < -2.0, "under the ground")
	for sample: Node in samples.get_children():
		assert_equal((sample as VisualInstance3D).layers, Layers.SURFACE, "%s on the surface" % sample.name)
	assert_true((samples.get_child(0) as GeometryInstance3D).material_override == turf, "the mound in the ground's material")
	view.end_surface_prewarm()
	assert_true(view.surface_samples() == null and samples.is_queued_for_deletion(), "gone, and freed")


static func _dig_ramp_and_half_the_body(network: GraphScript, ref: PackedInt32Array, body: int) -> void:
	"""Dig a room's ramp open and half its body."""
	network.start_dig(ref[3], ref[4], 0)
	network.advance(ref[3], ref[4], 1000000000)
	network.start_dig(body, network.generation[body], 0)
	@warning_ignore("integer_division") network.advance(body, network.generation[body], network.total_ticks(body) * Rules.USEC_PER_SECOND / 60)


func _check_planned_cellar(view: RoomViewScript, space: CastSpaceScript, obstacles: int) -> void:
	"""Room 0, a root cellar just laid (see `test_the_room_drawings`)."""
	assert_equal(space.obstacles.size(), obstacles, "its mound (two circles) and its hood, as soon as it is laid")
	assert_equal(view.label(0).text, "Root cellar 1 (planned)", "planned")
	assert_equal(view.label_below(0).layers, Layers.UNDERGROUND_MARKS, "named in the U view on its marks layer")
	assert_true(view.outline_below(0).visible and view.outline_below(0).layers == Layers.UNDERGROUND_MARKS, "outlined below")
	assert_equal(view.shell_builds, 0, "no shell yet")


func _check_dug_cellar(view: RoomViewScript, space: CastSpaceScript, obstacles: int, turf: Material) -> void:
	"""Room 0, a root cellar just dug (see `test_the_room_drawings`), its mound and hood in `turf`."""
	assert_equal(view.label(0).text, "Root cellar 1", "dug")
	assert_equal(view.shell_builds, 2, "built again, whole")
	assert_false(view.outline_below(0).visible, "no outline once dug")
	assert_equal(view.furniture(0).get_child_count(), 2, "bare (decision 0210): its own lantern and its glow")
	for piece: Node in view.furniture(0).get_children():
		assert_equal((piece as VisualInstance3D).layers, Layers.UNDERGROUND, "%s below" % piece.name)
	assert_equal(view.frames(0).multimesh.visible_instance_count, 3, "frames at its door and two sockets")
	assert_true(view.beam(0).visible and view.beam(0).mesh.get_surface_count() == 1, "and its ring beam over them")
	assert_equal(view.shell(0).layers, Layers.UNDERGROUND, "the shell below")
	assert_true(view.above(0).visible and view.above(0).get_child_count() == 3, "its mound, earth face and hatch above")
	for piece: Node in view.above(0).find_children("*", "VisualInstance3D", true, false):
		assert_equal((piece as VisualInstance3D).layers, Layers.SURFACE, "%s on the surface" % piece.name)
	assert_equal(space.obstacles.size(), obstacles, "its mound's obstacles still, not doubled")
	assert_true((view.above(0).get_child(0) as GeometryInstance3D).material_override == turf, "its mound in the ground's turf")


func test_the_flood_rises_on_the_demo_clock_and_holds_while_paused() -> void:
	"""1.5 s of demo time raises the water half way (3 s to full) and hands the real stream that level;
	a paused frame raises nothing and hands nothing."""
	var events := EventsScript.new()
	var clock := DemoClockScript.new()
	var view := EventsViewScript.new()
	_nodes.append(view)
	view.configure(events, clock)
	var risen: Array[float] = []
	view.set_flood_rise(func(level: float) -> void: risen.append(level))
	events.trigger()
	assert_equal(events.kind, EventsScript.KIND_FLOOD, "the first threat is the flood")
	clock.advance(1.5)
	view._process(0.0)
	assert_near(view.water_level(), 0.5, 0.0001, "half way")
	assert_equal(risen.size(), 1, "the stream told once")
	assert_near(risen[0], 0.5, 0.0001, "half way up its banks")
	assert_near(view.film_radius_m(), EventsViewScript.FILM_M * 0.5, 0.0001, "the spill's film half spread")
	clock.speed = 0
	clock.frame_usec = 0
	view._process(0.0)
	assert_near(view.water_level(), 0.5, 0.0001, "held while paused")
	assert_equal(risen.size(), 1, "nothing new to tell")


func test_the_weather_view_falls_and_dims_on_the_demo_clock() -> void:
	"""Rain falls while it rains; the sun eases toward 75% (a light shower, decision 0205) over 3 s of demo
	time, not while paused."""
	var weather := WeatherScript.new()
	var clock := DemoClockScript.new()
	var view := WeatherViewScript.new()
	_nodes.append(view)
	view.configure(weather, clock, null)
	weather.observe(0, 3, 12, 90, 3200, CoreWeather.EVENT_HEAVY_RAIN)
	clock.speed = 0
	clock.frame_usec = 0
	view._process(0.0)
	assert_true(view.raining(), "rain falls")
	assert_near(view.sun_share(), 1.0, 0.0001, "paused: the light holds")
	clock.advance(1.5)
	view._process(0.0)
	assert_near(view.sun_share(), 0.875, 0.0001, "half way to 0.75")
	weather.observe(2, 11, 15, -30, 700, CoreWeather.EVENT_EARLY_FROST)
	view._process(0.0)
	assert_true(view.snowing(), "snow falls")
	assert_false(view.raining(), "rain stops")


func test_a_tunnel_job_called_away_is_taken_back_when_the_other_work_is_done() -> void:
	"""The playtest's mole (decision 0205): given Hang lanterns, then called to other work (the farm's
	walks are move orders like this one), it leaves the job paused and keeps it; when that work is done
	(work_done, as the farm's and the woods' crews end a job) it takes the same job back up, progress and
	paid inputs kept. Given to someone else meanwhile, it is not taken back; the player's R forgets it."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array([2])), "lanterns ordered")
	assert_true(works.jobs.start(0), "paid")
	works.jobs.work(0, 200000)
	var done_before: int = works.jobs.done_ticks(0)
	assert_true(done_before > 0 and not works.jobs.is_done(0), "part done: %d of %d" % [done_before, works.jobs.total[0]])
	brains[2].order_move(Vector2(6.0, 6.0))
	assert_equal(works.jobs.worker[0], -1, "the job waits, paused")
	assert_equal(brains[2].unfinished_labels(), PackedStringArray(["Hang lanterns, tunnel 1"]), "kept")
	brains[2].work_done()
	assert_true(brains[2].task is JobTaskScript, "back on the lanterns")
	assert_equal(works.jobs.worker[0], 2, "the job is its again")
	assert_equal(works.jobs.kind[0], JobsScript.JOB_LANTERNS, "the same job")
	assert_equal(works.jobs.done_ticks(0), done_before, "its progress kept")
	assert_equal(works.jobs.paid[0], 1, "paid once, not again")
	brains[2].order_move(Vector2(6.0, 6.0))
	works.jobs.post(0, JobsScript.JOB_LANTERNS, 1, 0, 0)
	brains[1].order_task(JobTaskScript.new(works.jobs, (site[0] as CastSpaceScript).tunnels, 0))
	brains[2].work_done()
	assert_equal(works.jobs.worker[0], 1, "someone else has it: not taken back")
	assert_equal(brains[2].order, BrainScript.ORDER_NONE, "so it goes back to its routine")
	brains[1].order_move(Vector2(-1.0, 1.0))
	assert_equal(brains[1].unfinished_labels().size(), 1, "the keeper kept it")
	brains[1].release()
	assert_equal(brains[1].unfinished_labels().size(), 0, "R forgets it")
	works.jobs.work(0, 1000000000)
	assert_true(works.jobs.is_done(0), "the job's work all done")
	brains[1].order_task(JobTaskScript.new(works.jobs, (site[0] as CastSpaceScript).tunnels, 0))
	brains[1].order_move(Vector2(-1.0, 1.0))
	assert_equal(brains[1].unfinished_labels().size(), 0, "a job with its work all done is not kept")


func test_a_job_taken_back_after_work_that_ended_underground_starts_from_the_surface() -> void:
	"""Review H1 (decision 0205): lanterns on tunnel 1, called away to brace tunnel 4 (another tunnel's
	entrance ramp). When the brace ends in its bore the worker walks out first and only then takes the
	lanterns back up -- walking to them and paying for them on arrival, never appearing in their bore."""
	var site := _order_site()
	var space: CastSpaceScript = site[0]
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	var second := _open_tunnel(space, [Vector2i(0, 4096), Vector2i(12288, 4096)])
	works.step(1)
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array([2])), "lanterns on tunnel 1")
	assert_true(actions.select_at(Vector2(1.0, 4.0)) and actions.selected == second[0], "tunnel 4, its entrance ramp, picked")
	assert_true(actions.order(JobsScript.JOB_BRACE, PackedInt32Array([2])), "then a brace on tunnel 4")
	assert_equal(brains[2].unfinished_labels(), PackedStringArray(["Hang lanterns, tunnel 1"]), "the lanterns kept")
	var back_on_it: Array[bool] = [false, false]
	for frame: int in 60 * 240:
		for brain: BrainScript in brains:
			brain.step(DT)
		works.step(roundi(DT * 1000000.0))
		var on_lanterns: bool = brains[2].task is JobTaskScript and (brains[2].task as JobTaskScript).slot == 0
		if on_lanterns and not back_on_it[0]:
			back_on_it[0] = true
			back_on_it[1] = brains[2].underground
		if back_on_it[0] and works.jobs.paid[0] == 1:
			break
	assert_true(works.jobs.is_done(second[0]) or works.jobs.kind[second[0]] == JobsScript.JOB_NONE, "the brace was done")
	assert_true(back_on_it[0], "back on the lanterns")
	assert_false(back_on_it[1], "taken up on the surface, not inside a bore")
	assert_equal(works.jobs.paid[0], 1, "it walked to them and paid on arrival")


# --- the fit-out from the panel (decision 0210) -------------------------------------------------------

func test_a_room_is_selected_and_fitted_out_from_the_panel() -> void:
	"""A dug home under a point is found and selected (a tunnel let go); the panel shows it bare with its palette; a
	bed ordered with a resident selected is paid, said and handed to that resident; one taken out is refunded; the
	suggested layout a plank short is refused in words; nowhere near a room, nothing is found."""
	var tool := _tool(PackedInt32Array([1]))
	var ext := tool.ext
	var network := tool.network
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-8192, 8192), 0, 0, ref), "a home")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	assert_equal(ext.room_at(Vector2(-8.5, 8.5)), ref[0], "found under a point in it")
	assert_equal(ext.room_at(Vector2(4.0, 4.0)), -1, "nothing elsewhere")
	ext.select_room(ref[0])
	assert_true(ext.has_room_selected() and not ext.actions.has_selection(), "the room selected")
	ext.works.stores.plank_milli_u = 2000
	ext.refresh_panel()
	assert_true(ext.panel.room_shown(), "the panel shows the room")
	assert_equal(ext.panel.line(&"room_title"), "Burrow home %d — bare" % (ref[0] + 1), "bare")
	var name := "Burrow home %d" % (ref[0] + 1)
	assert_equal(ext.fit_action(&"fit:add:0", PackedInt32Array([1])), 0, "a bed ordered")
	assert_equal(ext.works.log_lines[-1], "%s: a bed planned (2 planks paid) -- a resident will put it in" % name, "said")
	assert_equal(ext.works.brain(1).task_label(), "Fitting out %s: the bed" % name, "resident 1 puts it in")
	assert_equal(ext.fit_action(&"fit:suggest", PackedInt32Array()), 4, "the layout: the stores are short")
	assert_true(ext.works.log_lines[-1].begins_with("Can't: the demo stores are short: the suggested layout needs"), "said")
	assert_equal(ext.fit_action(&"fit:take:0", PackedInt32Array()), 0, "the bed taken out")
	assert_equal(ext.works.stores.plank_milli_u, 2000, "its planks back")
	assert_equal(ext.fit_action(&"fit:take:0", PackedInt32Array()), 6, "none left to take")
	assert_equal(ext.works.log_lines[-1], "Can't: %s has no bed to take out" % name, "said")
	ext.set_stored(func(_room_row: int) -> int: return 3)
	ext.fit_action(&"fit:add:0", PackedInt32Array())
	network.fit.phase[ref[0] * RoomsScript.MAX_PLACES] = 2
	assert_equal(ext.fit_action(&"fit:take:0", PackedInt32Array()), 0, "a home's bed holds no food")
	ext.actions.select(1)
	ext.refresh_panel()
	assert_false(ext.panel.room_shown(), "a tunnel selected: the room gives way")
	ext.select_room(ref[0])
	network.rooms.release(ref[0])
	assert_false(ext.has_room_selected(), "its row gone: no room selected")


func test_a_cellar_s_racks_are_not_taken_out_below_its_food_from_the_panel() -> void:
	"""The panel asks the farm how much a cellar holds (set_stored): a rack holding it stays, said in words."""
	var tool := _tool(PackedInt32Array())
	var ext := tool.ext
	var network := tool.network
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(-8192, 8192), 0, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	network.fit.phase_of(network, ref[0], 2)
	network.fit.phase[ref[0] * RoomsScript.MAX_PLACES + 2] = 2
	ext.select_room(ref[0])
	ext.set_stored(func(_room_row: int) -> int: return 12)
	assert_equal(ext.fit_action(&"fit:take:5", PackedInt32Array()), 7, "refused")
	assert_equal(ext.works.log_lines[-1], "Can't: Root cellar %d holds 12 U of food: its racks cannot drop below that" % (ref[0] + 1),
		"said")


func test_a_room_is_let_go_and_a_take_out_hands_nothing_to_the_selected() -> void:
	"""Taking a fixture out with residents selected gives them nothing to do; deselecting the room hides it."""
	var tool := _tool(PackedInt32Array([1]))
	var ext := tool.ext
	var network := tool.network
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	network.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-8192, 8192), 0, 0, ref)
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	ext.select_room(ref[0])
	ext.works.stores.plank_milli_u = 4000
	ext.fit_action(&"fit:add:0", PackedInt32Array())
	ext.fit_action(&"fit:add:0", PackedInt32Array())
	assert_equal(ext.fit_action(&"fit:take:0", PackedInt32Array([1])), 0, "one taken out")
	assert_equal(ext.works.brain(1).task_label(), "", "the selected given nothing")
	ext.deselect_room()
	ext.refresh_panel()
	assert_false(ext.has_room_selected() or ext.panel.room_shown(), "let go")


func test_a_resident_asleep_in_the_hall_cannot_be_picked() -> void:
	"""Not drawn indoors, so no pick proxy either."""
	var space := _space([])
	var brain := BrainScript.new()
	brain.configure(space, 1.0, 0.25, 1, {})
	brain.start_at(Vector2.ZERO, 0.0, -1, -1)
	var out := PackedFloat32Array([0, 0, 0, 0, 0])
	DemoCommandScript.proxy_into(brain, Vector3.ZERO, 1.0, false, Vector3(0, 10, 10), out)
	assert_true(out[4] > 0.0, "outdoors: pickable")
	brain.task_go_indoors(true, BrainScript.INTERIOR_HALL)
	DemoCommandScript.proxy_into(brain, Vector3.ZERO, 1.0, false, Vector3(0, 10, 10), out)
	assert_equal(out[4], 0.0, "indoors: not")
