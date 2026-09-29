extends "res://test/framework/test_case.gd"
## The live demo's tunnel extensions in motion (decision 0196): residents walking in the weather,
## through lit bores and queues, driven by tasks; the works joining weather, digs, crews, finds,
## hazards, jobs and threats on the demo clock; the player's orders; the panel; and the drawings.
##
## No scene tree and no staged assets: brains are stepped at a fixed 60 Hz on hand-built circles, the
## works are stepped by hand with whole demo microseconds, and nodes are built out of the tree and
## freed after each test.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
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
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const BurrowViewScript := preload("res://demo/burrow/burrow_view.gd")
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

const DT: float = 1.0 / 60.0
const SEED: int = 9091
const BODY_M: float = 0.25
const WALK_M_S: float = 1.0
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)

var _nodes: Array[Node] = []
var _notices: PackedStringArray = PackedStringArray()
## The demo's shared weather, water and notice feed, fresh for every test.
var _services: ServicesScript = ServicesScript.new()


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


func _open_tunnel(space: CastSpaceScript, points: Array[Vector2i]) -> int:
	"""Add a tunnel along these points and dig it to the end; returns its slot."""
	var flat := PackedInt32Array()
	for p in points:
		flat.append(p.x)
		flat.append(p.y)
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(flat, points.size(), 0, ref), "fixture tunnel stored")
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	return ref[0]


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


func _bore_speed(lit: bool, permille: int) -> float:
	"""Metres a second a walker covers in a 10 m tunnel's bore (lit or not) in weather at `permille`."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	if lit:
		space.tunnels.set_lit(slot)
	space.tunnels.surface_permille = permille
	var brain := _brain(space, Vector2(0.0, -6.0), true)
	brain.order_move(Vector2(0.0, 7.0))
	_until(brain, func() -> bool: return brain.underground and brain.bore_along_m() > 1.0, 20.0)
	var from := brain.bore_along_m()
	_step([brain], 2.0)
	return (brain.bore_along_m() - from) / 2.0


func test_tunnel_travel_ignores_the_weather_and_lanterns_quicken_it() -> void:
	"""1.0 m/s below in snow as in the sun; 1.1 m/s in a lit bore."""
	assert_near(_bore_speed(false, 600), 1.0, 0.001, "snow above, full pace below")
	assert_near(_bore_speed(true, 1000), 1.1, 0.001, "lit")


func test_a_second_walker_waits_in_line_at_a_busy_mouth_and_both_get_through() -> void:
	"""Two ordered through one tunnel together: the one behind waits in the mouth's line (QUEUE,
	shown as waiting) instead of crowding the hole, then follows; both come out."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var a := _brain(space, Vector2(0.0, -3.4), true)
	var b := _brain(space, Vector2(-1.2, -4.6), true)
	a.order_move(Vector2(0.0, 4.0))
	b.order_move(Vector2(-1.0, 4.0))
	var queued := false
	var shown := false
	for f in 60 * 30:
		a.step(DT)
		b.step(DT)
		queued = queued or b.state == BrainScript.State.QUEUE
		shown = shown or b.activity() == BrainScript.ACTIVITY_QUEUE
	assert_true(queued, "B waited in line")
	assert_true(shown, "and was shown waiting")
	assert_true(a.position.distance_to(Vector2(0.0, 4.0)) < 0.2, "A through (%s)" % a.position)
	assert_true(b.position.distance_to(Vector2(-1.0, 4.0)) < 0.2, "B through (%s)" % b.position)
	assert_equal(space.tunnels.queue.count[0], 0, "the line is empty")
	assert_equal(space.tunnels.queue.grant[0], -1, "no grant held")


func test_a_mouth_is_clear_only_with_nobody_near_it_below_or_on_it() -> void:
	"""Someone in the bore within 1.2 m of the entrance, or standing on its hole, blocks it."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var walker := space.add_resident(Vector2(0.0, -8.0), BODY_M)
	var other := space.add_resident(Vector2(0.0, -4.5), BODY_M)
	space.set_underground(other, true)
	space.set_in_bore(other, slot, 0.5, 1)
	assert_false(space.mouth_clear(walker, slot, false, 1.2), "someone just below")
	space.set_in_bore(other, slot, 2.0, 1)
	assert_true(space.mouth_clear(walker, slot, false, 1.2), "further down")
	assert_false(space.mouth_clear(walker, slot, true, 9.0), "near the exit, measured from it")
	space.set_underground(other, false)
	space.move_resident(other, Vector2(0.0, -5.0))
	assert_false(space.mouth_clear(walker, slot, false, 1.2), "someone standing on the hole")


func test_a_walker_is_routed_only_through_a_bore_it_fits() -> void:
	"""Two tunnels under the wall -- a standard one straight ahead and a wide one 3 m aside: the badger
	takes the wide one; a mouse the straight one."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var wide := _open_tunnel(space, [Vector2i(3072, -2048), Vector2i(3072, 2048)])
	space.tunnels.set_bore(wide, Rules.BORE_WIDE)
	var badger := _brain(space, Vector2(0.0, -4.0), true)
	space.tunnels.set_body(badger.index, 2611, 574)
	var mouse := _brain(space, Vector2(0.5, -4.0), true)
	badger.order_move(Vector2(0.0, 4.0))
	mouse.order_move(Vector2(0.5, 4.0))
	assert_true(badger.path_tunnel.has(2), "the badger through the wide tunnel (slot 1, a to b)")
	assert_false(badger.path_tunnel.has(0), "not the standard one")
	assert_true(mouse.path_tunnel.has(0), "the mouse the straight one")


func test_a_carrier_never_hauls_through_a_bore_its_load_does_not_fit() -> void:
	"""The badger fits a wide bore but not with a load: leaving the stockpile it never carries below."""
	var points: Array[Dictionary] = [
		{"name": &"stockpile", "position": Vector3(0.0, 0.0, -3.0), "face": Vector3.FORWARD, "activities": [&"collect_object"], "capacity": 1},
		{"name": &"north", "position": Vector3(0.0, 0.0, 3.0), "face": Vector3.BACK, "activities": [&"idle"], "capacity": 1}]
	var keys: Array = []
	for k in 31:
		keys.append([0.0, 0.02 * float(k)])
	var below := 0
	var crossed := 0
	for attempt in 12:
		var space := CastSpaceScript.new()
		space.setup(points, _wall())
		var slot := _open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
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
	"""A task's worker standing in the bore heads neither way: a walker coming up behind steps aside
	and passes it, and comes out."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var worker := _brain(space, Vector2(3.0, -8.0), true)
	worker.task_stand_in_bore(slot, 5.0, true)
	assert_equal(space.resident_heading[worker.index], 0, "heading neither way")
	var walker := _brain(space, Vector2(0.0, -6.0), true)
	walker.order_move(Vector2(0.0, 7.0))
	assert_true(walker.crosses_tunnel(), "through the tunnel")
	assert_true(_until(walker, func() -> bool: return walker.position.distance_to(Vector2(0.0, 7.0)) < 0.2, 30.0),
		"passed the worker and came out (%s)" % walker.position)


func test_a_walker_gives_up_a_line_that_does_not_move() -> void:
	"""Held in line behind a grant nobody gives up, a walker waits 25 s and then walks round instead."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var b := _brain(space, Vector2(-1.2, -4.6), true)
	space.tunnels.queue.grant[0] = 99
	b.order_move(Vector2(-1.0, 4.0))
	assert_true(_until(b, func() -> bool: return b.state == BrainScript.State.QUEUE, 10.0), "in line")
	_step([b], 24.0)
	assert_equal(b.state, BrainScript.State.QUEUE, "still waiting at 24 s")
	_step([b], 1.5)
	assert_false(b.state == BrainScript.State.QUEUE, "gave up by 25.5 s")
	assert_false(b.crosses_tunnel(), "walking round")


func test_a_released_walker_leaves_the_line() -> void:
	"""Released while waiting in line, a walker's place is given up."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var b := _brain(space, Vector2(-1.2, -4.6), true)
	space.tunnels.queue.grant[0] = 99
	b.order_move(Vector2(-1.0, 4.0))
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
	"""Half way down, the tunnel closes: the walker walks back and comes up at the entrance."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var brain := _brain(space, Vector2(0.0, -6.0), true)
	brain.order_move(Vector2(0.0, 7.0))
	_until(brain, func() -> bool: return brain.underground and brain.bore_along_m() > 3.0, 20.0)
	space.tunnels.close(slot, NetworkScript.CLOSED_FLOODED, 0, 10240)
	brain.turn_back(slot, 0.0)
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
	"""With the Foremole alone the dig runs at 1000; with a member below at its post, at 1506."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.0), Vector2(-3.0, 2.0)], species)
	var works := _works(space, brains, species)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([0, 0, 4096, 0]), 2, 0, ref)
	works.step(1)
	assert_equal(space.tunnels.rate_permille[0], 1000, "alone")
	works.crew.join(1, 0)
	works.crew.set_present(1, true)
	works.step(1)
	assert_equal(space.tunnels.rate_permille[0], 1506, "a finisher behind")


func test_digging_through_the_rock_pocket_finds_a_relic_and_yields_stone() -> void:
	"""The village's T1 route through the rock pocket: three flints and the relic in cell (25, 20), 3.2 U
	of stone from four rock quanta, and the relic's alert."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(0.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([3072, 2867, 8192, -1229]), 2, 0, ref)
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	works.step(1)
	assert_equal(works.stores.finds[FindsScript.FIND_FLINT], 3, "flints")
	assert_equal(works.stores.finds[FindsScript.FIND_RELIC], 1, "the relic")
	assert_equal(works.stores.stone_milli_u, 23200, "20 U and four rock quanta's 800")
	assert_true(_noted("A relic dug up — see the tunnel panel"), "posted")
	assert_true(Array(works.log_lines).has(FindsScript.relic_story(1)), "its story told")


func _wet_tunnel(works: WorksScript, space: CastSpaceScript) -> int:
	"""An open 4 m tunnel whose middle two metres are wet sand (the works' ground overwritten)."""
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [22, 23]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND | GroundScript.WET_BIT
	var slot := _open_tunnel(space, [Vector2i(512, 512), Vector2i(4608, 512)])
	works.step(1)
	return slot


func test_rain_floods_an_unbraced_wet_tunnel_with_warning_and_everyone_turns_back() -> void:
	"""In rain: a warning at 20 s, a flood at 40 s -- alerted; a walker in the bore turns back; the
	flooded tunnel is marked closed until pumped."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	var slot := _wet_tunnel(works, space)
	_rain(works)
	works.step(1)
	brains[0].order_move(Vector2(6.0, 0.5))
	assert_true(brains[0].crosses_tunnel(), "in the rain the tunnel is quicker (7.75 against 8.75)")
	_until(brains[0], func() -> bool: return brains[0].underground and brains[0].bore_along_m() > 1.0, 10.0)
	works.step(20000000)
	assert_true(_warned("Tunnel 1 is seeping — brace it"), "warned")
	works.step(20000000)
	assert_true(_warned("Tunnel 1 flooded — pump it out"), "flooded")
	assert_equal(space.tunnels.closed[slot], NetworkScript.CLOSED_FLOODED, "closed")
	var surfaced := Vector2.INF
	for f in 60 * 10:
		brains[0].step(DT)
		if not brains[0].underground:
			surfaced = brains[0].position
			break
	assert_true(surfaced.distance_to(Vector2(0.5, 0.5)) < 0.01, "came up back at the entrance (%s)" % surfaced)


func test_a_roof_holds_while_someone_is_under_it() -> void:
	"""A collapse falls due while a walker stands under the sand: the roof creaks and holds; once
	nobody is under it, it falls."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [22, 23]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var slot := _open_tunnel(space, [Vector2i(512, 512), Vector2i(4608, 512)])
	works.step(1)
	brains[0].task_stand_in_bore(slot, 2.0, true)
	works.hazards.strain_usec[slot] = HazardsScript.STRAIN_FULL_USEC - 1
	works._act_on(slot, works.hazards.add_crossing(slot))
	assert_equal(space.tunnels.closed[slot], NetworkScript.CLOSED_NONE, "holds")
	assert_true(_warned("Tunnel 1 holds while someone is under"), "creaks")
	space.set_in_bore(brains[0].index, slot, 0.2, 0)
	brains[0].task_surface(slot, false)
	works._act_on(slot, HazardsScript.EVENT_COLLAPSE_DUE)
	assert_equal(space.tunnels.closed[slot], NetworkScript.CLOSED_COLLAPSED, "falls once clear")


func test_a_crew_follows_the_foremole_s_work() -> void:
	"""While a tunnel is dug the crew's work goes on, at the entrance during the shaft and at the face
	after; a mole job's crew follows the worker below; with nothing going on, it ends."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(-3.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([0, 0, 4096, 0]), 2, 0, ref)
	assert_true(works.crew_active(0), "digging")
	assert_equal(works.crew_along(0), 0.0, "the entrance shaft: at the surface")
	space.tunnels.dig_usec[0] = 200 * 1000000 / 30
	assert_true(works.crew_along(0) > 0.0, "the bore: at the face (%.3f)" % works.crew_along(0))
	space.tunnels.advance(0, ref[1], 1000000000)
	assert_false(works.crew_active(0), "open: nothing going on")
	works.jobs.post(0, JobsScript.JOB_WIDEN, 0, 0, 4096)
	assert_true(works.crew_active(0), "a widening")
	assert_equal(works.crew_along(0), 0.0, "its worker not yet below")
	works.jobs.pause(0)
	assert_false(works.crew_active(0), "paused: the crew stands down")


func test_a_walker_under_a_fall_s_far_side_turns_to_the_exit() -> void:
	"""A collapse closes the sand (1.5..2.5 m along an 8 m bore): a walker already past it -- though
	nearer the entrance than the exit -- walks on to the exit; one short of it turns back."""
	var space := _space([])
	var species := PackedStringArray(["Mouse", "Mouse"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.5), Vector2(-3.0, 1.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [22, 23]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var slot := _open_tunnel(space, [Vector2i(512, 512), Vector2i(8704, 512)])
	_rain(works)
	works.step(1)
	brains[0].order_move(Vector2(10.0, 0.5))
	brains[1].order_move(Vector2(10.0, 1.5))
	_until(brains[0], func() -> bool: return brains[0].underground and brains[0].bore_along_m() > 3.3, 20.0)
	assert_true(brains[0].bore_along_m() < 4.0, "past the fall and its half-metre margin (1.0..3.0 m), short of the middle (%.3f)" % brains[0].bore_along_m())
	assert_false(works.hazards.in_fall(slot, brains[1].bore_along_m()), "the other short of it (%.3f)" % brains[1].bore_along_m())
	_until(brains[1], func() -> bool: return brains[1].underground and brains[1].bore_along_m() > 0.3, 20.0)
	works._act_on(slot, HazardsScript.EVENT_COLLAPSE_DUE)
	assert_equal(space.tunnels.closed[slot], NetworkScript.CLOSED_COLLAPSED, "fallen")
	var up := [Vector2.INF, Vector2.INF]
	for f in 60 * 12:
		for k in 2:
			brains[k].step(DT)
			if not brains[k].underground and up[k] == Vector2.INF:
				up[k] = brains[k].position
	assert_true((up[0] as Vector2).distance_to(Vector2(8.5, 0.5)) < 0.01, "past it: out at the exit (%s)" % up[0])
	assert_true((up[1] as Vector2).distance_to(Vector2(0.5, 0.5)) < 0.01, "short of it: back to the entrance (%s)" % up[1])


func test_walking_into_a_weak_bore_strains_it() -> void:
	"""The works count a walker going down an unbraced sand bore as a crossing: 8 s of strain."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.5)], species)
	var works := _works(space, brains, species)
	works.ground.cells.fill(GroundScript.LOAM)
	for c in [22, 23]:
		works.ground.cells[20 * works.ground.columns + c] = GroundScript.SAND
	var slot := _open_tunnel(space, [Vector2i(512, 512), Vector2i(4608, 512)])
	_rain(works)
	works.step(1)
	var strain := works.hazards.strain_usec[slot]
	brains[0].order_move(Vector2(6.0, 0.5))
	for f in 60 * 3:
		brains[0].step(DT)
		works.step(0)
	assert_true(brains[0].crosses_tunnel(), "through the tunnel")
	assert_equal(works.hazards.strain_usec[slot] - strain, HazardsScript.CROSSING_STRAIN_USEC, "one crossing")


func test_the_foremole_speaks_up_at_rock() -> void:
	"""A dig whose face reaches rock with no badger on the crew: the Foremole says so, as a warning in the
	demo's notice feed carrying the short line."""
	var space := _space([])
	var species := PackedStringArray(["Mole"])
	var works := _works(space, _cast_of(space, [Vector2(0.0, 0.0)], species), species)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([3072, 2867, 8192, -1229]), 2, 0, ref)
	for k in 12:
		space.tunnels.dig_usec[0] = k * 100 * 1000000 / 30
		works.step(1)
	assert_true(_services.notices.has_text(CrewScript.LINE_ROCK_ALONE), "said, in the notice feed")
	assert_true(_warned("Rock! The Foremole needs the badger"), "a warning, with its short line")


func test_a_widening_crew_works_side_by_side() -> void:
	"""A widening offers five faces: the Foremole and one member below dig at 2000; a chamber's crew
	of four (three faces and a finisher) at 3506."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse", "Mouse", "Mouse"])
	var works := _works(space, _cast_of(space, [Vector2.ZERO, Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)], species), species)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(2048, 0)])
	works.jobs.post(slot, JobsScript.JOB_WIDEN, 0, 0, 2048)
	works.crew.join(1, slot)
	works.crew.set_present(1, true)
	works.step(1)
	assert_equal(works.jobs.rate_permille[slot], 2000, "two faces")
	works.jobs.clear(slot)
	works.jobs.post_chamber(slot, 0, 0, 1024, GroundScript.LOAM)
	for i in [2, 3]:
		works.crew.join(i, slot)
		works.crew.set_present(i, true)
	works.step(1)
	assert_equal(works.jobs.rate_permille[slot], 3506, "a chamber's four")


func test_a_job_done_takes_effect_and_is_announced() -> void:
	"""A brace worked to its end: the works finish it -- braced -- and raise its short alert."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var works := _works(space, _cast_of(space, [Vector2.ZERO], species), species)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(2048, 0)])
	works.jobs.post(slot, JobsScript.JOB_BRACE, 0, 0, 2048)
	works.jobs.start(slot)
	works.jobs.work(slot, 5000000)
	works.step(1)
	assert_equal(space.tunnels.braced[slot], 1, "braced")
	assert_true(_noted("Tunnel 1 braced"), "announced")
	assert_equal(works.stores.wood_milli_u, 39000, "paid for")


func test_a_flood_by_the_stream_sends_residents_through_a_tunnel_and_home_again() -> void:
	"""The test event (a flood of the real stream at the ford) sends the resident on the east road down
	the tunnel out of the disc; the one on the square stays put; when the water goes down the
	evacuee's task ends."""
	var space := _space([])
	var species := PackedStringArray(["Mouse", "Mouse"])
	var brains := _cast_of(space, [Vector2(16.0, -0.9), Vector2(0.0, -1.0)], species)
	var works := _works(space, brains, species)
	_open_tunnel(space, [Vector2i(17408, -922), Vector2i(11264, -922)])
	assert_true(works.start_test_event(), "the flood comes")
	assert_false(works.start_test_event(), "one at a time")
	assert_true(brains[0].task is EvacuateTaskScript, "the east-road mouse evacuates")
	assert_true((brains[0].task as EvacuateTaskScript).through_tunnel, "through the tunnel")
	assert_true(brains[1].task == null, "the square mouse does not")
	assert_true(_warned("Flood by the stream — evacuating"), "alerted")
	var below := false
	for f in 60 * 15:
		brains[0].step(DT)
		below = below or brains[0].underground
	assert_true(below, "went through the tunnel")
	assert_true(brains[0].position.x < 11.0, "came out beyond it (%s)" % brains[0].position)
	assert_false(brains[0].underground, "and is on the surface, not walking the ground from below")
	works.step(EventsScript.DURATION_USEC)
	assert_true(_noted("The flood has gone down"), "the all-clear")
	_step([brains[0]], 0.1)
	assert_true(brains[0].task == null, "home again: the task is over")


func test_a_job_the_stores_cannot_pay_for_sends_its_worker_home() -> void:
	"""Arriving at a brace with the stores emptied meanwhile: nothing is paid, no work is done, and the
	worker goes back to its routine."""
	var space := _space([])
	var species := PackedStringArray(["Mouse"])
	var brains := _cast_of(space, [Vector2(-1.0, 0.0)], species)
	var works := _works(space, brains, species)
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(2048, 0)])
	works.jobs.post(slot, JobsScript.JOB_BRACE, 0, 0, 2048)
	brains[0].order_task(JobTaskScript.new(works.jobs, space.tunnels, slot))
	works.stores.wood_milli_u = 0
	_step([brains[0]], 5.0)
	assert_equal(works.jobs.paid[slot], 0, "unpaid")
	assert_equal(works.jobs.done_ticks(slot), 0, "no work")
	assert_true(brains[0].task == null, "sent home")
	assert_false(brains[0].underground, "never went down")


func test_a_crew_member_works_a_gap_behind_the_foremole() -> void:
	"""The first member below stands 0.9 m behind the Foremole's place, the second 1.8 m."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(8192, 0)])
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	crew.set_resident(1, "Mouse")
	var member := _brain(space, Vector2(0.0, 0.0), true)
	var second := _brain(space, Vector2(0.0, 1.0), true)
	crew.join(0, slot)
	crew.join(1, slot)
	member.task_stand_in_bore(slot, 0.2, true)
	second.task_stand_in_bore(slot, 0.2, true)
	var task := CrewTaskScript.new(crew, space.tunnels, slot, true, Vector2(-1.0, 0.0),
		func(_s: int) -> bool: return true, func(_s: int) -> float: return 3.0)
	assert_true(task.step(member, DT), "working")
	assert_true(task.step(second, DT), "working")
	assert_near(member.bore_along_m(), 2.1, 0.0001, "0.9 m behind")
	assert_near(second.bore_along_m(), 1.2, 0.0001, "1.8 m behind")
	assert_equal(crew.member_present[0], 1, "at its post")


func test_a_crew_member_stands_down_when_the_work_stops() -> void:
	"""Once the Foremole's work is over, the member's place ends (and it leaves the crew)."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(4096, 0)])
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
	"""A mole, two mice and a badger by an open 2 m tunnel: [space, brains, works, actions]."""
	var space := _space([])
	var species := PackedStringArray(["Mole", "Mouse", "Mouse", "Badger"])
	var brains := _cast_of(space, [Vector2(-3.0, 0.0), Vector2(-1.0, 1.0), Vector2(6.0, 6.0), Vector2(-2.0, -2.0)], species)
	var works := _works(space, brains, species)
	_open_tunnel(space, [Vector2i(0, 0), Vector2i(2048, 0)])
	works.step(1)
	var actions := ActionsScript.new(works, space, PackedByteArray([1, 0, 0, 0]),
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
	space.tunnels.set_braced(0)
	assert_false(actions.order(JobsScript.JOB_BRACE, PackedInt32Array()), "already braced")
	assert_equal(works.log_lines[-1], "Can't: tunnel 1 is already braced", "said")
	space.tunnels.close(0, NetworkScript.CLOSED_FLOODED, 0, 2048)
	assert_false(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array()), "closed")
	assert_equal(works.log_lines[-1], "Can't: tunnel 1 is closed — repair it first", "said")
	space.tunnels.reopen(0)
	works.stores.wood_milli_u = 499
	assert_false(actions.order(JobsScript.JOB_LANTERNS, PackedInt32Array()), "short")
	assert_equal(works.log_lines[-1], "Can't: the demo stores are short (need wood 0.5 U, stone 0.0 U)", "said")


func test_a_job_goes_to_the_selected_resident_else_the_nearest_free_one() -> void:
	"""Brace with a mouse selected: that mouse; with nobody selected: the nearest free mouse (never the
	mole, never the badger, who does not fit the bore)."""
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


func test_mole_work_takes_the_foremole_and_the_rest_as_crew() -> void:
	"""Widen with a mouse and the badger selected: the mole works it and both join its crew; with the
	mole digging a tunnel, it is refused."""
	var site := _order_site()
	var brains: Array[BrainScript] = site[1]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	actions.select_at(Vector2(1.0, 0.3))
	assert_true(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array([1, 3])), "ordered")
	assert_equal(works.jobs.worker[0], 0, "the Foremole")
	assert_equal(works.crew.count_of(0), 2, "a crew of two")
	assert_equal(brains[3].task_label(), "Dig crew — surface hand", "the badger works the surface")
	works.jobs.clear(0)
	brains[0].order = BrainScript.ORDER_DIG
	assert_false(actions.order(JobsScript.JOB_WIDEN, PackedInt32Array()), "the Foremole is digging")
	assert_equal(works.log_lines[-1], "Can't: the Foremole is busy digging", "said")


func test_a_chamber_is_placed_beside_the_tunnel_clicked() -> void:
	"""Armed, a click 1.5 m south of the tunnel plans a burrow home on that side for the Foremole; a
	click far away is refused and placement stays armed."""
	var site := _order_site()
	var space: CastSpaceScript = site[0]
	var works: WorksScript = site[2]
	var actions: ActionsScript = site[3]
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([-8192, 8192, 0, 8192]), 2, 0, ref)
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	works.step(1)
	actions.select_at(Vector2(-4.0, 8.2))
	assert_true(actions.begin_chamber(ChambersScript.KIND_HOME, PackedInt32Array()), "armed")
	assert_equal(works.log_lines[-1], "Click along tunnel 2 where the burrow home should open (Esc: cancel)", "prompted")
	assert_false(actions.place_chamber(Vector2(-4.0, 16.0), PackedInt32Array()), "too far")
	assert_equal(actions.placing, ChambersScript.KIND_HOME, "still armed")
	assert_true(actions.place_chamber(Vector2(-4.0, 9.5), PackedInt32Array()), "placed")
	assert_equal(works.chambers.chamber_point_u(0), Vector2i(-4096, 10240), "2 m to the clicked side")
	assert_equal(works.jobs.kind[ref[0]], JobsScript.JOB_CHAMBER, "a chamber job")
	assert_equal(works.jobs.worker[ref[0]], 0, "for the Foremole")
	assert_equal(actions.placing, ChambersScript.KIND_NONE, "disarmed")


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
	"""T1 through the rock pocket: 9 quanta, three of clay (147 ticks) and four of rock -- 1119 ticks,
	37 s -- and 2 x 2000 + 3 x 2400 + 4 x 1200 = 16 U of spoil."""
	var tool := _tool(PackedInt32Array([0]))
	tool.begin_plan()
	assert_true(tool.lay_ground(Vector2(3.0, 2.8)), "entrance")
	assert_true(tool.lay_ground(Vector2(8.0, -1.2)), "exit")
	assert_true(tool.confirm(), "dug")
	assert_equal(_notices[-1], "Digging a 6.4 m tunnel: 9 m³ to cut, 16 U of spoil, about 37 s", "told")


func test_the_panel_shows_the_selected_tunnel_and_its_repair() -> void:
	"""A selected open tunnel: its length, bore, fit and hazard lines; flooded, the repair button reads
	"Pump out" and is the only one enabled; the panel's Repair orders the pump."""
	var tool := _tool(PackedInt32Array())
	var slot := _open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(2048, 5120)])
	tool.ext.works.step(1)
	assert_true(tool.ext.actions.select_at(Vector2(1.0, 5.2)), "selected by its route")
	tool.ext.refresh_panel()
	assert_true(tool.ext.panel.button(PanelScript.ACTION_REPAIR).disabled, "nothing to repair")
	assert_false(tool.ext.panel.button(PanelScript.ACTION_BRACE).disabled, "brace enabled")
	assert_equal(tool.ext.panel.line(&"tunnel_title"), "Tunnel 1 — 2.0 m", "title")
	assert_equal(tool.ext.panel.line(&"tunnel"), "standard bore (1 m) · unbraced · unlit\nFits: mice, moles, squirrels, hauling too (otters and the badger need it widened)\nSafe ground (no wet or sandy stretch)", "state")
	tool.network.close(slot, NetworkScript.CLOSED_FLOODED, 0, 2048)
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
		tool.ext.works.weather.observe(0, 1, 12, 120, 1200, CoreWeather.EVENT_NONE)
		return 6)
	tool.ext.on_action(PanelScript.ACTION_NEXT_WEATHER)
	assert_equal(skips.size(), 1, "the hook ran once")
	assert_equal(_notices[-1], "Skipped 6 h ahead on the demo calendar: Rain — Spring 1, 12.0 °C · rain 12:00–17:59 · walking outdoors at 80%, tunnels unaffected", "said")
	tool.ext.on_action(PanelScript.ACTION_EVENT)
	assert_true(tool.ext.works.events.active, "a threat")
	tool.ext.on_action(PanelScript.ACTION_EVENT)
	assert_equal(_notices[-1], "A demo event is already under way", "one at a time")


func test_placing_a_chamber_takes_clicks_and_esc_cancels() -> void:
	"""Armed, the tool hands the extension the events: Esc disarms and says so."""
	var tool := _tool(PackedInt32Array([0]))
	_open_tunnel(_space_of(tool), [Vector2i(0, 5120), Vector2i(4096, 5120)])
	tool.ext.works.step(1)
	tool.ext.actions.select_at(Vector2(2.0, 5.1))
	tool.ext.on_action(PanelScript.ACTION_HOME)
	assert_equal(tool.ext.actions.placing, ChambersScript.KIND_HOME, "armed")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(tool.handle_input(esc), "taken")
	assert_equal(tool.ext.actions.placing, ChambersScript.KIND_NONE, "disarmed")
	assert_equal(_notices[-1], "Chamber placement cancelled", "said")


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
	assert_equal(panel.button(PanelScript.ACTION_EVENT).focus_mode, Control.FOCUS_NONE, "never takes focus")


func test_the_panel_s_buttons_emit_their_action() -> void:
	"""Pressing a button emits its action's name."""
	var panel := _panel()
	var heard: Array[StringName] = []
	panel.action.connect(func(name: StringName) -> void: heard.append(name))
	panel.button(PanelScript.ACTION_EVENT).pressed.emit()
	panel.button(PanelScript.ACTION_WIDEN).pressed.emit()
	assert_equal(heard, [&"event", &"widen"] as Array[StringName], "heard")


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
	"""The tint while planning above ground; the strata underground; neither otherwise."""
	var view := GroundViewScript.new()
	_nodes.append(view)
	view.configure(GroundScript.new())
	assert_false(view.plan_tint().visible or view.strata().visible, "nothing to start")
	view.set_planning(true)
	assert_true(view.plan_tint().visible, "tint while planning")
	view.set_underground_view(true)
	assert_false(view.plan_tint().visible, "no tint underground")
	assert_true(view.strata().visible, "strata underground")


func _marked_tunnel() -> Array:
	"""An open 8 m tunnel, its hazards and its marks: [network, marks]."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([0, 0, 8192, 0]), 2, 0, ref)
	network.advance(0, ref[1], 1000000000)
	var hazards := HazardsScript.new(network)
	hazards.survey(0)
	var marks := MarksScript.new()
	_nodes.append(marks)
	marks.configure(network, hazards)
	return [network, marks]


func test_the_marks_follow_the_tunnel_s_state() -> void:
	"""Selected: a brass line; flooded: water; collapsed: fallen earth; nothing on a plain tunnel."""
	var site := _marked_tunnel()
	var network: NetworkScript = site[0]
	var marks: MarksScript = site[1]
	marks.refresh()
	assert_false(marks.line(0).visible or marks.water(0).visible or marks.fall(0).visible, "plain")
	marks.select(0)
	marks.refresh()
	assert_true(marks.line(0).visible, "selected")
	network.close(0, NetworkScript.CLOSED_FLOODED, 0, 8192)
	marks.refresh()
	assert_true(marks.water(0).visible, "water")
	network.close(0, NetworkScript.CLOSED_COLLAPSED, 3072, 5120)
	marks.refresh()
	assert_false(marks.water(0).visible, "no water now")
	assert_true(marks.fall(0).visible, "fallen earth")
	assert_true(marks.fall(0).position.is_equal_approx(Vector3(4.0, -0.02, 0.0)), "over the section's middle")


func test_braces_and_lanterns_show_underground() -> void:
	"""Braced and lit, underground: a frame every metre where the floor is a trough deep (1..7 of 0..8)
	and two lanterns; above ground, none."""
	var site := _marked_tunnel()
	var network: NetworkScript = site[0]
	var marks: MarksScript = site[1]
	network.set_braced(0)
	network.set_lit(0)
	marks.refresh()
	assert_false(marks.frames(0).visible, "not above ground")
	marks.set_underground_view(true)
	marks.refresh()
	assert_true(marks.frames(0).visible, "frames below")
	assert_equal(marks.frames(0).multimesh.visible_instance_count, 7, "metres 1..7")
	assert_equal(marks.lanterns(0).multimesh.visible_instance_count, 2, "8 m: two lanterns")


func test_the_chamber_drawings() -> void:
	"""A planned chamber is outlined and named "(digging)"; a done one names itself and, underground,
	shows its room."""
	var chambers := ChambersScript.new()
	var view := BurrowViewScript.new()
	_nodes.append(view)
	view.configure(chambers)
	var ref := PackedInt32Array([0, 0])
	chambers.add_into(ChambersScript.KIND_CELLAR, NetworkScript.new(), 0, 0, Vector2i(2048, 4096), ref)
	view.refresh()
	assert_equal(view.label(0).text, "Root cellar (digging)", "planned")
	assert_true(view.label(0).position.is_equal_approx(Vector3(2.0, 0.6, 4.0)), "over it")
	chambers.set_done(0)
	view.set_underground_view(true)
	view.refresh()
	assert_equal(view.label(0).text, "Root cellar", "done")
	assert_true(view.room(0).visible, "the room below")
	assert_equal(view.room(0).get_child_count(), 4, "a floor and three crates")


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
	"""Rain falls while it rains; the sun eases toward 45% over 3 s of demo time, not while paused."""
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
	assert_near(view.sun_share(), 0.725, 0.0001, "half way to 0.45")
	weather.observe(2, 10, 15, -30, 700, CoreWeather.EVENT_EARLY_FROST)
	view._process(0.0)
	assert_true(view.snowing(), "snow falls")
	assert_false(view.raining(), "rain stops")
