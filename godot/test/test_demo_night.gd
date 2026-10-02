extends "res://test/framework/test_case.gd"
## The night (decision 0210, the underground revamp's P4; Brendan's ruling: residents sleep at home at night): beds
## allocated in REQ-SET-132's order, dusk and dawn on the demo calendar, the walk home and into bed, parking the job in
## hand and taking it up in the morning, waking on an order, on the alarm, and the bedless in the hall (REQ-SET-133);
## and the fit-out's crew walking in to put a fixture in.
##
## No scene tree and no staged assets: hand-built spaces, a burrow home laid straight on the network and dug, and real
## brains walking it at DT a step.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const CrewScript := preload("res://demo/burrow/fixture_crew.gd")
const InstallTaskScript := preload("res://demo/burrow/install_task.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DT: float = 1.0 / 60.0
const WALK_M_S: float = 1.0
const BODY_M: float = 0.25
const MOUSE_U: int = 1024
const BADGER_U: int = 2611
## Bed sizes (bed_allocation.gd): a burrow bed, a large bed.
const S: int = AllocationScript.SIZE_SMALL
const B: int = AllocationScript.SIZE_BIG
const HOME_AT: Vector2i = Vector2i(0, 8192)
const HALL_AT: Vector2 = Vector2(0.0, -6.0)
## Calendar ticks at hours of the first day (tick 0 is 06:00): the hour before dusk (19:00), dusk at 20:00
## (night_routine.gd DUSK_HOUR, decision 0421), and dawn at 06:00 the next morning.
const TICK_EVENING: int = (NightScript.DUSK_HOUR - 7) * 750
const TICK_DUSK: int = (NightScript.DUSK_HOUR - 6) * 750
const TICK_MORNING: int = 24 * 750
## The slowest resident's walk (decision 0205: the mole digger, 0.72 m/s), and what it covers in a game hour at 25 s.
const MOLE_WALK_M_S: float = 0.72
const MOLE_M_PER_HOUR: float = 18.0


## A task that runs `frames` steps and ends; called away, it is kept and taken back by ordering it again.
class CountedTask extends "res://demo/tunnel/tunnel_task.gd":
	var frames: int = 0
	var emergency: bool = false

	func _init(steps: int, is_urgent: bool = false) -> void:
		"""A task that lasts `steps` steps (an emergency when `is_urgent`)."""
		frames = steps
		emergency = is_urgent

	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Count down; over at zero."""
		frames -= 1
		return frames > 0

	func unfinished() -> RefCounted:
		"""Itself, taken back by ordering it again."""
		return UnfinishedScript.new(func(brain: RefCounted) -> bool:
			(brain as BrainScript).order_task(self)
			return true, "the counted job")

	func urgent() -> bool:
		"""An emergency, when made one."""
		return emergency


## One village: a space (a hall's steps, a work spot), a dug home, residents, a calendar and the night.
class Village extends RefCounted:
	var space: CastSpaceScript = null
	var graph: GraphScript = null
	var brains: Array[BrainScript] = []
	var calendar: CalendarScript = CalendarScript.new()
	var notices: NoticesScript = NoticesScript.new()
	var night: NightScript = NightScript.new()
	var home: int = -1
	## The alarm, as a one-element array the night's callable reads (capturing the village would be a cycle).
	var alarm: Array[bool] = [false]


func _lengths() -> Dictionary:
	"""Every clip the cast knows, sleep included, with round lengths."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _village(heights: Array[int], beds: int, hall: bool = true) -> Village:
	"""A village of residents this tall (u), standing in a row south of a dug home with `beds` beds in, at 19:00."""
	var v := Village.new()
	v.space = CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": NightScript.HALL_POI, "position": Vector3(HALL_AT.x, 0.0, HALL_AT.y),
		"capacity": 4}, {"name": &"here", "position": Vector3(4.0, 0.0, -2.0), "activities": [&"collect_object"] as Array[StringName],
		"capacity": 1}]
	v.space.setup(points, [] as Array[Vector3])
	v.graph = v.space.tunnels
	v.home = _home(v.graph, beds)
	var names := PackedStringArray()
	for i in heights.size():
		var brain := BrainScript.new()
		brain.configure(v.space, WALK_M_S, BODY_M, 7 + i, _lengths())
		brain.start_at(Vector2(-1.5 + 1.0 * float(i), -1.0), 0.0, -1, -1)
		v.graph.set_body(brain.index, heights[i], 256)
		v.brains.append(brain)
		names.append("resident %d" % i)
	v.calendar.tick = TICK_EVENING
	v.night.configure(v.graph, v.brains, names, PackedInt32Array(heights), v.calendar, v.notices)
	var alarm := v.alarm
	v.night.set_alarm(func() -> bool: return alarm[0])
	if hall:
		v.night.set_hall(HALL_AT)
	return v


func _home(graph: GraphScript, beds: int) -> int:
	"""A home at HOME_AT, turned 0 (its door south), dug, with `beds` beds put in."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, HOME_AT, 0, 0, ref), "a home laid")
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)
	for f in beds:
		graph.fit.phase_of(graph, ref[0], f)
		graph.fit.phase[ref[0] * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.fit.revision += 1
	return ref[0]


func _run(v: Village, frames: int, until: Callable = Callable()) -> int:
	"""Step the night and every brain; stop early once `until() -> bool`. Returns the frames run."""
	for f in frames:
		v.night.step()
		for brain in v.brains:
			brain.step(DT)
		if until.is_valid() and bool(until.call()):
			return f + 1
	return frames


func _all_asleep(v: Village, count: int) -> bool:
	"""Whether the first `count` residents lie asleep."""
	for i in count:
		if not v.brains[i].lying:
			return false
	return true


# --- beds: REQ-SET-132 -----------------------------------------------------------------------------

func test_a_resident_keeps_its_bed_then_takes_the_nearest_free_one() -> void:
	"""Beds 3 at x = 0 and 9 at x = 10 m: resident 0 at 1 m takes bed 3; resident 1 at 2 m, nearer bed 3 too, takes
	bed 9; kept the next time even from beside bed 3 -- its current valid bed first."""
	var beds := PackedInt32Array([3, 0, 0, S, 9, 10240, 0, S])
	var out := PackedInt32Array()
	AllocationScript.allocate(PackedInt32Array([-1, -1]), PackedInt32Array([1024, 0, 2048, 0]), PackedByteArray([1, 1]), beds, out)
	assert_equal(out, PackedInt32Array([3, 9]), "nearest free, in resident order")
	AllocationScript.allocate(PackedInt32Array([9, 3]), PackedInt32Array([0, 0, 10240, 0]), PackedByteArray([1, 1]), beds, out)
	assert_equal(out, PackedInt32Array([9, 3]), "each keeps its own, wherever it stands")


func test_a_tie_goes_to_the_lower_room_then_the_lower_place() -> void:
	"""A resident exactly between two beds takes the lower ID -- room first (ids are room * 8 + place), then place;
	the squared distance is exact, so a unit nearer wins."""
	var out := PackedInt32Array()
	var beds := PackedInt32Array([2, -5120, 0, S, 9, 5120, 0, S])
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, 0]), PackedByteArray([1]), beds, out)
	assert_equal(out[0], 2, "room 0's place 2 over room 1's place 1")
	var places := PackedInt32Array([8, 0, 3072, S, 10, 0, -3072, S])
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, 0]), PackedByteArray([1]), places, out)
	assert_equal(out[0], 8, "the same room: the lower place")
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, -1]), PackedByteArray([1]), places, out)
	assert_equal(out[0], 10, "a unit nearer the other wins")


func test_a_bed_gone_or_not_permitted_is_no_bed() -> void:
	"""A current bed no longer standing is not kept (the nearest free one instead); a resident not permitted a bed
	gets none, though beds are free; more residents than beds leaves the last without."""
	var out := PackedInt32Array()
	var one := PackedInt32Array([4, 0, 0, S])
	AllocationScript.allocate(PackedInt32Array([7]), PackedInt32Array([0, 0]), PackedByteArray([1]), one, out)
	assert_equal(out[0], 4, "bed 7 has gone: bed 4")
	AllocationScript.allocate(PackedInt32Array([4, -1]), PackedInt32Array([0, 0, 0, 0]), PackedByteArray([0, 1]), one, out)
	assert_equal(out, PackedInt32Array([-1, 4]), "not permitted, not even its own: the other takes it")
	AllocationScript.allocate(PackedInt32Array([-1, -1]), PackedInt32Array([0, 0, 0, 0]), PackedByteArray([1, 1]), one, out)
	assert_equal(out, PackedInt32Array([4, -1]), "one bed for two")
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, 0]), PackedByteArray([1]), PackedInt32Array(), out)
	assert_equal(out[0], -1, "no beds at all")


func test_each_body_is_sized_for_its_bed() -> void:
	"""Decision 0211: up to BIG_BODY_U a body is SMALL (a burrow bed: the moles, mice and squirrels), past it BIG (a large
	bed: the beaver, the otters, the badger), up to LARGE_BED_LENGTH_U; past that, no bed. The large bed is long enough
	for the badger, the burrow bed only for the small."""
	assert_equal(AllocationScript.size_of(AllocationScript.BIG_BODY_U), AllocationScript.SIZE_SMALL, "exactly the limit: small")
	assert_equal(AllocationScript.size_of(AllocationScript.BIG_BODY_U + 1), AllocationScript.SIZE_BIG, "a unit more: big")
	assert_equal(AllocationScript.size_of(Rules.to_u(1.15)), AllocationScript.SIZE_SMALL, "a squirrel")
	assert_equal(AllocationScript.size_of(Rules.to_u(1.40)), AllocationScript.SIZE_BIG, "the beaver")
	assert_equal(AllocationScript.size_of(Rules.to_u(1.49)), AllocationScript.SIZE_BIG, "an otter")
	assert_equal(AllocationScript.size_of(BADGER_U), AllocationScript.SIZE_BIG, "the badger")
	assert_equal(AllocationScript.size_of(AllocationScript.LARGE_BED_LENGTH_U), AllocationScript.SIZE_BIG, "the large bed's length")
	assert_equal(AllocationScript.size_of(AllocationScript.LARGE_BED_LENGTH_U + 1), AllocationScript.SIZE_NONE, "longer: none")
	assert_true(BADGER_U <= AllocationScript.LARGE_BED_LENGTH_U, "the badger fits a large bed")
	assert_true(AllocationScript.BIG_BODY_U < AllocationScript.BED_LENGTH_U, "a small body fits a burrow bed")
	assert_true(AllocationScript.fits(Rules.to_u(1.0)) and not AllocationScript.fits(Rules.to_u(1.49)), "fits: burrow beds are the small's")


func test_big_residents_take_large_beds_and_small_ones_burrow_beds() -> void:
	"""Decision 0211: a big resident is matched to a large bed and a small one to a burrow bed, still by REQ-SET-132 --
	the badger, nearer the burrow bed, walks past it to the large one; the mouse is never given the large bed, even
	with its own taken; a big resident with no large bed free has none, though burrow beds are."""
	var beds := PackedInt32Array([1, 0, 0, S, 2, 10240, 0, B])
	var out := PackedInt32Array()
	AllocationScript.allocate(PackedInt32Array([-1, -1]), PackedInt32Array([0, 0, 1024, 0]), PackedByteArray([B, S]), beds, out)
	assert_equal(out, PackedInt32Array([2, 1]), "the badger the large bed, the mouse the burrow bed")
	AllocationScript.allocate(PackedInt32Array([-1, -1]), PackedInt32Array([0, 0, 0, 0]), PackedByteArray([S, S]), beds, out)
	assert_equal(out, PackedInt32Array([1, -1]), "two mice: the second has none, the large bed stands empty")
	AllocationScript.allocate(PackedInt32Array([-1, -1]), PackedInt32Array([10240, 0, 10240, 0]), PackedByteArray([B, B]), beds, out)
	assert_equal(out, PackedInt32Array([2, -1]), "two big: the one large bed to the first")
	AllocationScript.allocate(PackedInt32Array([1]), PackedInt32Array([0, 0]), PackedByteArray([B]), beds, out)
	assert_equal(out[0], 2, "a big resident's burrow bed is no valid bed of its: the large one")
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, 0]), PackedByteArray([AllocationScript.SIZE_NONE]), beds, out)
	assert_equal(out[0], -1, "a body too big for any bed: none")


func test_the_night_allocates_the_home_s_beds_by_place() -> void:
	"""Three mice, three beds in the home: each has one, all in the home, none twice; the routine re-allocates when a
	bed goes (its sleeper without), and says whose bed in the panel."""
	var v := _village([MOUSE_U, MOUSE_U, MOUSE_U] as Array[int], 3)
	v.night.step()
	var got := PackedInt32Array()
	for i in 3:
		@warning_ignore("integer_division") assert_true(v.night.bed_of[i] / FixturesScript.PLACES == v.home, "resident %d has a bed in the home" % i)
		assert_false(got.has(v.night.bed_of[i]), "not shared")
		got.append(v.night.bed_of[i])
	assert_equal(v.night.home_text(0, true), "Bed: Burrow home %d · comfort 4000 (plain)" % (v.home + 1), "the panel's line")
	assert_equal(v.night.home_text(0, false), "", "nothing in a list")
	var lost := v.night.bed_of[2]
	v.graph.fit.phase[lost] = FixturesScript.EMPTY
	v.graph.fit.revision += 1
	v.night.step()
	assert_equal(v.night.bed_of[2], -1, "its bed taken out: without")
	assert_equal(v.night.home_text(2, true), "No bed: sleeps on the hall's floor", "said so")
	assert_equal(v.night.home_text(2, false), "no bed", "short in a list")


# --- the hours --------------------------------------------------------------------------------------

func test_night_runs_from_dusk_to_dawn_and_the_hearths_from_evening() -> void:
	"""Night is 20:00 to 05:59 (decision 0421: a walk home fits an hour, so dusk is the GDD schedule's 20:00); the
	hearths burn 19:00 to 06:59."""
	var night: Array[bool] = []
	var hearth: Array[bool] = []
	for hour: int in [5, 6, 18, 19, 20, 23, 0]:
		night.append(NightScript.is_night_hour(hour))
	for hour: int in [6, 7, 18, 19]:
		hearth.append(NightScript.is_hearth_hour(hour))
	assert_equal(night, [true, false, false, false, true, true, true] as Array[bool], "night")
	assert_equal(hearth, [true, false, false, true] as Array[bool], "hearths")


func _run_timed(v: Village, frames: int, until: Callable) -> int:
	"""Step the night and every brain on a 1x demo clock, the calendar advancing by the frame's demo time as the farm
	advances it (decision 0421: 30 ticks a second); stop once `until() -> bool`. Returns the calendar ticks run."""
	var clock := DemoClockScript.new()
	var start: int = v.calendar.tick
	for f in frames:
		clock.advance(DT)
		v.calendar.tick += v.calendar.ticks_for_usec(clock.frame_usec)
		v.night.step()
		for brain in v.brains:
			brain.step(clock.delta_s())
		if bool(until.call()):
			break
	return v.calendar.tick - start


func test_a_walk_of_18_m_takes_about_a_game_hour() -> void:
	"""Decision 0421: at 25 s a game hour the slowest walker (0.72 m/s) covers 18 m in a game hour -- the walk takes
	about 750 calendar ticks, give or take its start and its route (on the old day of a minute it took ten hours)."""
	var v := _village([MOUSE_U] as Array[int], 1)
	var brain: BrainScript = v.brains[0]
	brain.walk_speed = MOLE_WALK_M_S
	brain.start_at(Vector2(-9.0, -2.5), 0.0, -1, -1)
	var goal := Vector2(-9.0 + MOLE_M_PER_HOUR, -2.5)
	brain.order_move(goal)
	var ticks: int = _run_timed(v, 60 * 60, func() -> bool: return brain.position.distance_to(goal) < 0.3)
	assert_true(brain.position.distance_to(goal) < 0.3, "arrived: %s" % brain.position)
	assert_true(ticks >= 720 and ticks <= 810, "about a game hour of calendar ticks: %d" % ticks)


func test_a_resident_15_m_from_home_is_in_bed_within_an_hour_of_dusk() -> void:
	"""Decision 0421: sent home at dusk (20:00) from the square, about 15 m of walk to its bed (to the home's door and
	through the room) at the slowest pace, a resident lies down before 21:00 -- before the GDD schedule's 22:00 sleep,
	far short of deep night. (On the old day of a minute this walk took six game hours.)"""
	var v := _village([MOUSE_U] as Array[int], 1)
	var brain: BrainScript = v.brains[0]
	brain.walk_speed = MOLE_WALK_M_S
	brain.start_at(Vector2(-6.0, -4.0), 0.0, -1, -1)
	v.calendar.tick = TICK_DUSK
	var ticks: int = _run_timed(v, 60 * 120, func() -> bool: return brain.lying)
	assert_true(brain.lying, "in bed")
	assert_true(ticks < SimClock.TICKS_PER_HOUR, "before 21:00: %d ticks after dusk" % ticks)


func test_residents_rest_all_night_and_only_then() -> void:
	"""`resting` is set at dusk (20:00) for everyone and cleared at dawn (06:00)."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.night.step()
	assert_false(v.brains[0].resting or v.night.is_night(), "19:00: up")
	v.calendar.tick = TICK_DUSK
	v.night.step()
	assert_true(v.brains[0].resting and v.night.is_night(), "20:00: resting")
	v.calendar.tick = TICK_MORNING
	v.night.step()
	assert_false(v.brains[0].resting or v.night.is_night(), "06:00: up")


# --- home to bed ------------------------------------------------------------------------------------

func test_at_dusk_they_walk_home_and_lie_down_in_their_beds() -> void:
	"""At dusk three mice go home through the front door and each lies down in its own bed: underground, the
	mattress under it, its body's middle on the bed's, head to the pillow; the panel says so; the feed says dusk."""
	var v := _village([MOUSE_U, MOUSE_U, MOUSE_U] as Array[int], 3)
	_run(v, 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	for i in 3:
		assert_true(v.brains[i].task is SleepTaskScript, "resident %d sent to bed" % i)
		assert_equal(v.brains[i].task_label(), "Going home to bed (Burrow home %d)" % (v.home + 1), "on the way")
	var took := _run(v, 2400, _all_asleep.bind(v, 3))
	assert_true(_all_asleep(v, 3), "all asleep after %d frames" % took)
	for i in 3:
		var brain := v.brains[i]
		var task := brain.task as SleepTaskScript
		assert_true(brain.underground, "resident %d below" % i)
		assert_equal(brain.lie_top_y_m, Layers.FLOOR_Y_M + NightScript.DEFAULT_BED_TOP_M, "on its mattress")
		assert_true((brain.position + brain.lie_middle_m.rotated(-brain.yaw)).distance_to(task._bed) < 0.01, "its middle on the bed's")
		assert_equal(brain.clip, BrainScript.CLIP_SLEEP, "asleep")
		assert_equal(brain.task_label(), "Asleep in Burrow home %d" % (v.home + 1), "said")
	assert_true(v.notices.has_text(NightScript.DUSK_NOTE), "dusk in the feed")


func test_in_the_morning_they_get_up_and_take_up_the_parked_job() -> void:
	"""A resident on a job at dusk parks it (kept to come back to), goes to bed, and in the morning gets up, walks out
	and is on the same job again."""
	var v := _village([MOUSE_U] as Array[int], 1)
	var job := CountedTask.new(1000000)
	v.brains[0].order_task(job)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_true(v.brains[0].task is SleepTaskScript, "to bed")
	assert_equal(v.brains[0].unfinished_labels(), PackedStringArray(["the counted job"]), "the job parked")
	_run(v, 2400, _all_asleep.bind(v, 1))
	assert_true(v.brains[0].lying, "asleep")
	v.calendar.tick = TICK_MORNING
	var took := _run(v, 3000, func() -> bool: return v.brains[0].task == job)
	assert_true(v.brains[0].task == job, "back on its job after %d frames" % took)
	assert_false(v.brains[0].lying or v.brains[0].underground, "up and out")


func test_at_dawn_one_still_on_the_way_home_turns_back_to_its_job() -> void:
	"""Parked at dusk and still walking home at dawn, it does not go to bed to get up: it is back on its job at once."""
	var v := _village([MOUSE_U] as Array[int], 1)
	var job := CountedTask.new(1000000)
	v.brains[0].order_task(job)
	v.calendar.tick = TICK_DUSK
	_run(v, 3)
	assert_equal((v.brains[0].task as SleepTaskScript).stage, SleepTaskScript.STAGE_GOING, "on its way")
	v.calendar.tick = TICK_MORNING
	_run(v, 1)
	assert_true(v.brains[0].task == job, "back on its job")


func test_a_work_order_at_a_spot_is_parked_and_taken_up() -> void:
	"""Ordered to work at a spot, at dusk its work there is kept ("Work at here"); in the morning it goes back to it."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.brains[0].order_work(1, 0)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_equal(v.brains[0].unfinished_labels(), PackedStringArray(["Work at here"]), "kept")
	_run(v, 2400, _all_asleep.bind(v, 1))
	v.calendar.tick = TICK_MORNING
	_run(v, 3000, func() -> bool: return v.brains[0].order == BrainScript.ORDER_WORK)
	assert_equal(v.brains[0].order, BrainScript.ORDER_WORK, "back at work")
	assert_equal(v.brains[0].poi, 1, "at its spot")


func test_an_order_wakes_a_sleeper_and_once_free_it_goes_back_to_bed() -> void:
	"""An order to a sleeper gets it up and away (no longer lying, the sleep over, nothing kept); released at night,
	it is sent to bed again."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 2400, _all_asleep.bind(v, 1))
	var brain := v.brains[0]
	brain.order_move(Vector2(3.0, -3.0))
	assert_false(brain.lying, "up")
	assert_false(brain.task is SleepTaskScript, "the sleep is over")
	assert_equal(brain.unfinished_labels().size(), 0, "nothing to come back to")
	_run(v, 60)
	assert_equal(brain.order, BrainScript.ORDER_MOVE, "carrying out the order")
	brain.release()
	_run(v, 2)
	assert_false(brain.task is SleepTaskScript, "not sent again within RESEND_TICKS")
	v.calendar.tick += NightScript.RESEND_TICKS
	_run(v, 2)
	assert_true(brain.task is SleepTaskScript, "free at night: back to bed")


func test_the_alarm_gets_sleepers_up_until_it_clears() -> void:
	"""While a threat is under way a sleeper stands by its bed ("Up by the bed: the alarm"); once it clears, it lies
	down again."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 2400, _all_asleep.bind(v, 1))
	v.alarm[0] = true
	_run(v, 2)
	assert_false(v.brains[0].lying, "up")
	assert_equal(v.brains[0].task_label(), "Up by the bed: the alarm", "said")
	assert_true(v.brains[0].position.distance_to((v.brains[0].task as SleepTaskScript).bedside()) < 0.01, "by the bed")
	v.alarm[0] = false
	_run(v, 2)
	assert_true(v.brains[0].lying, "back to sleep")


func test_emergencies_and_the_water_are_left_alone_at_dusk() -> void:
	"""At dusk an evacuee or a rescuer (an urgent task), a resident held by the rescue and one in the water are not
	sent to bed; one on an ordinary job is."""
	var v := _village([MOUSE_U, MOUSE_U, MOUSE_U, MOUSE_U] as Array[int], 3)
	var urgent := CountedTask.new(1000000, true)
	v.brains[0].order_task(urgent)
	v.brains[1].water_hold = true
	v.brains[2].in_water = true
	v.brains[3].order_task(CountedTask.new(1000000))
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_true(v.brains[0].task == urgent, "the emergency goes on")
	assert_false(v.brains[1].task is SleepTaskScript or v.brains[2].task is SleepTaskScript, "the water's are left")
	assert_true(v.brains[3].task is SleepTaskScript, "the ordinary job is parked")


func test_the_bedless_sleep_in_the_hall_and_come_out_in_the_morning() -> void:
	"""Two mice and the badger, one bed: the nearer mouse has it; the other mouse and the badger (a big resident, with
	no large bed) walk to the hall's door and go in (not drawn); the feed names who has no bed; in the morning they come
	out."""
	var v := _village([MOUSE_U, MOUSE_U, BADGER_U] as Array[int], 1)
	v.brains[1].start_at(Vector2(6.0, -4.0), 0.0, -1, -1)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_true(v.night.bed_of[0] >= 0 and v.night.bed_of[1] == -1 and v.night.bed_of[2] == -1, "one bed")
	assert_true(v.notices.has_text(NightScript.NO_BED_WARNING % "resident 1, resident 2"), "the housing deficit said")
	assert_equal(v.night.home_text(2, true), "No large bed (a big resident: fit one in a home's alcove): sleeps on the hall's floor",
		"the badger: a big resident with no large bed (decision 0211)")
	_run(v, 2400, func() -> bool: return v.brains[1].indoors and v.brains[2].indoors)
	assert_true(v.brains[1].indoors and v.brains[2].indoors, "in the hall")
	assert_equal(v.brains[2].task_label(), "Asleep in the hall (no bed)", "said")
	v.calendar.tick = TICK_MORNING
	_run(v, 2)
	assert_false(v.brains[1].indoors or v.brains[2].indoors, "out in the morning")


func test_the_badger_sleeps_in_the_large_bed_in_its_nook() -> void:
	"""A home with a large bed in its back alcove and a burrow bed beside it: the badger takes the large bed and the
	mouse the burrow bed, though the badger stands nearer the burrow bed; each walks home and lies down, the badger out
	in the nook along the large bed; the badger's panel names its bed."""
	var v := _village([BADGER_U, MOUSE_U] as Array[int], 0)
	var stores := StoresScript.new()
	stores.add_planks(6000)
	assert_equal(v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_BIG_BED, stores), FixturesScript.REFUSE_NONE, "planned")
	assert_equal(v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_BED, stores), FixturesScript.REFUSE_NONE, "and a bed")
	for f in 2:
		v.graph.fit.phase[v.home * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	v.graph.fit.revision += 1
	v.calendar.tick = TICK_DUSK
	var took := _run(v, 60 * 120, func() -> bool: return _all_asleep(v, 2))
	assert_equal(v.night.bed_of[0], v.home * FixturesScript.PLACES, "the badger: the large bed")
	assert_equal(v.night.bed_of[1], v.home * FixturesScript.PLACES + 1, "the mouse: the burrow bed")
	assert_true(_all_asleep(v, 2), "both asleep after %d frames" % took)
	var middle := v.graph.fit.bed_middle_u(v.graph, v.home, 0)
	var lies := v.brains[0].position.distance_to(Vector2(Rules.to_m(middle.x), Rules.to_m(middle.y)))
	assert_true(lies < 1.4, "along the large bed in its nook (%.2f m from its middle)" % lies)
	assert_true(v.night.home_text(0, true).begins_with("Bed: "), "its bed named")


func test_without_a_hall_the_bedless_stay_up() -> void:
	"""With no hall and no bed a resident is not sent anywhere, and the deficit is not said."""
	var v := _village([MOUSE_U] as Array[int], 0, false)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_null(v.brains[0].task, "stays up")
	assert_false(v.night.send(0), "nowhere to send it")
	assert_false(v.notices.has_text(NightScript.NO_BED_WARNING % "resident 0"), "not said")


func test_a_bed_it_cannot_reach_is_no_bed_tonight() -> void:
	"""A short, broad resident permitted a bed but fitting no bore cannot reach its home: it sleeps in the hall."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.graph.set_body(v.brains[0].index, MOUSE_U, 1400)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_true(v.night.bed_of[0] >= 0, "it has a bed")
	var task := v.brains[0].task as SleepTaskScript
	assert_true(task != null and not task.has_bed(), "but sleeps in the hall")


# --- the fit-out's crew -------------------------------------------------------------------------------

func test_the_nearest_free_resident_walks_in_and_puts_a_fixture_in() -> void:
	"""A table planned: handed out to the nearest resident wandering on its own, who walks into the home, works its 8
	WU there and is done -- the table in, and it back out. Not at night."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 0)
	v.brains[1].start_at(Vector2(9.0, -9.0), 0.0, -1, -1)
	var crew := CrewScript.new()
	crew.configure(v.graph, v.brains)
	var stores := StoresScript.new()
	stores.add_planks(2000)
	assert_equal(v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, stores), FixturesScript.REFUSE_NONE, "planned")
	for brain in v.brains:
		brain.resting = true
	assert_equal(crew.hand_out(), 0, "nobody at night")
	for brain in v.brains:
		brain.resting = false
	assert_equal(crew.hand_out(), 1, "handed out")
	assert_true(v.brains[0].task is InstallTaskScript, "to the nearer")
	assert_equal(crew.installers(), 1, "one at it")
	var table := 4
	var took := _run_brains(v, 4000, func() -> bool: return v.graph.fit.phase_of(v.graph, v.home, table) == FixturesScript.INSTALLED)
	assert_equal(v.graph.fit.phase_of(v.graph, v.home, table), FixturesScript.INSTALLED, "in after %d frames" % took)
	_run_brains(v, 3000, func() -> bool: return not v.brains[0].underground)
	assert_null(v.brains[0].task, "done")
	assert_false(v.brains[0].underground, "and out")


func _run_brains(v: Village, frames: int, until: Callable) -> int:
	"""Step the brains only (no night); stop once `until() -> bool`."""
	for f in frames:
		for brain in v.brains:
			brain.step(DT)
		if bool(until.call()):
			return f + 1
	return frames


func test_the_selected_take_the_fixtures_and_called_away_keep_them() -> void:
	"""Ordered with two residents selected, the suggested layout's first two places go to them at once; one called
	away leaves its place waiting (its work kept) and keeps it to come back to."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 0)
	var crew := CrewScript.new()
	crew.configure(v.graph, v.brains)
	var stores := StoresScript.new()
	stores.add_planks(10000)
	stores.add_wood(3000)
	assert_equal(v.graph.fit.suggest(v.graph, v.home, stores), FixturesScript.REFUSE_NONE, "planned")
	assert_equal(crew.give_selected(v.home, PackedInt32Array([1, 0])), 2, "two given")
	assert_true(v.brains[1].task is InstallTaskScript and (v.brains[1].task as InstallTaskScript).place == 0, "the first bed to resident 1")
	assert_true(v.brains[0].task is InstallTaskScript and (v.brains[0].task as InstallTaskScript).place == 1, "the second to resident 0")
	_run_brains(v, 2000, func() -> bool: return v.graph.fit.work_usec[v.home * FixturesScript.PLACES + 1] > 0)
	v.brains[0].order_move(Vector2(3.0, -3.0))
	var row := v.home * FixturesScript.PLACES + 1
	assert_equal(v.graph.fit.worker[row], -1, "its place waits")
	assert_true(v.graph.fit.work_usec[row] > 0, "its work kept")
	assert_equal(v.graph.fit.asked[row], 0, "kept for it")
	assert_equal(v.brains[0].unfinished_labels(), PackedStringArray(["Put in the bed, Burrow home %d" % (v.home + 1)]), "kept to come back to")


func test_a_kept_place_waits_for_its_resident_then_lapses() -> void:
	"""A place kept for a resident busy elsewhere is given to no one else, however free; given to it once it is free;
	and after KEEP_USEC of waiting kept, to the nearest free resident."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 0)
	var crew := CrewScript.new()
	crew.configure(v.graph, v.brains)
	var stores := StoresScript.new()
	stores.add_planks(2000)
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, stores)
	var row := v.home * FixturesScript.PLACES + 4
	v.graph.fit.asked[row] = 1
	v.brains[1].order_move(Vector2(-3.0, -3.0))
	assert_equal(crew.taker(row), -1, "kept for resident 1, who is busy: nobody")
	crew.update(CrewScript.KEEP_USEC - 1)
	assert_equal(crew.taker(row), -1, "still kept a microsecond before it lapses")
	v.brains[1].release()
	assert_equal(crew.taker(row), 1, "free: resident 1 takes it")
	v.brains[1].order_move(Vector2(-3.0, -3.0))
	crew.update(1)
	assert_equal(v.graph.fit.asked[row], -1, "lapsed")
	assert_equal(crew.taker(row), 0, "the nearest free resident may take it")


# --- a carrier walks into a cellar (farm_cellars.gd CARRIED IN) ----------------------------------------

func test_a_carrier_walks_its_load_into_a_cellar_and_out_again() -> void:
	"""Ordered down to a cellar's middle, a mouse with a carry walks in carrying (loaded through the hatch's wide
	ramp), holds below facing its rack, and released walks out to the surface and wanders on."""
	var v := _village([MOUSE_U] as Array[int], 0)
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(v.graph.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(-10240, 2048), 0, 0, ref), "a cellar laid")
	var chain := PackedInt32Array()
	v.graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		v.graph.start_dig(slot, v.graph.generation[slot], 0)
		v.graph.advance(slot, v.graph.generation[slot], 1000000000)
	var brain := v.brains[0]
	brain.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.4], [0.0, 0.8]], "mean_speed_m_s": 0.4, "period_s": 2.0})
	var middle: int = v.graph.rooms.middle[ref[0]]
	assert_true(brain.can_haul_below(middle), "it can carry a load down")
	var rack := Vector2(-11.0, 1.0)
	brain.order_carry_below(middle, rack)
	assert_true(brain.carrying, "carrying")
	var loaded_below := false
	for f in 3000:
		brain.step(DT)
		loaded_below = loaded_below or (brain.underground and brain.carrying)
		if brain.state == BrainScript.State.HOLD:
			break
	assert_true(loaded_below, "carried below")
	assert_equal(brain.state, BrainScript.State.HOLD, "holds")
	assert_true(brain.underground, "below, in the cellar")
	assert_true(brain.position.distance_to(v.graph.node_m(middle)) < 0.05, "at its middle")
	assert_true(absf(angle_difference(brain.yaw, BrainScript.yaw_of(rack - brain.position))) < 0.05, "facing the rack")
	brain.release()
	var up := _run_brains(v, 3000, func() -> bool: return not brain.underground and brain.state == BrainScript.State.IDLE)
	assert_false(brain.underground, "out after %d frames" % up)
	assert_equal(brain.order, BrainScript.ORDER_NONE, "on its own again")


func test_a_badger_cannot_haul_below() -> void:
	"""Too big to carry through any bore: can_haul_below is false (the farm then leaves the load at the hatch)."""
	var v := _village([BADGER_U] as Array[int], 0)
	v.graph.set_body(v.brains[0].index, BADGER_U, 560)
	v.brains[0].set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.4], [0.0, 0.8]], "mean_speed_m_s": 0.4, "period_s": 2.0})
	assert_false(v.brains[0].can_haul_below(v.graph.rooms.middle[v.home]), "no bore takes the badger loaded")


# --- edges ---------------------------------------------------------------------------------------------

func test_a_sleeper_or_one_on_a_crossing_is_not_sent_again() -> void:
	"""Already asleep (a sleep task), or on a crossing: may not be sent."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_false(v.night.may_send(0), "in bed already")
	v.brains[1].release()
	v.brains[1].state = BrainScript.State.CROSS
	assert_false(v.night.may_send(1), "on a crossing")


func test_the_alarm_leaves_the_hall_s_sleepers_inside() -> void:
	"""Asleep in the hall, the alarm does not get it up (a threat there evacuates it instead)."""
	var v := _village([MOUSE_U] as Array[int], 0)
	v.calendar.tick = TICK_DUSK
	_run(v, 1200, func() -> bool: return v.brains[0].indoors)
	v.alarm[0] = true
	_run(v, 2)
	assert_true(v.brains[0].indoors, "still inside")
	assert_equal(v.brains[0].task_label(), "Asleep in the hall (no bed)", "asleep")
	assert_equal(v.space.resident_underground[v.brains[0].index], 1, "off the walking surface")


func test_in_the_morning_a_sleeper_walks_to_the_middle_before_its_night_ends() -> void:
	"""Its night ends at the room's middle (from there the brain walks it out), not where it rose."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 2400, _all_asleep.bind(v, 1))
	var task := v.brains[0].task as SleepTaskScript
	v.calendar.tick = TICK_MORNING
	_run(v, 600, func() -> bool: return v.brains[0].task != task)
	assert_true(v.brains[0].position.distance_to(task._middle) < 0.5, "at the middle when it ended")


func test_a_night_lost_on_the_way_goes_back_to_the_routine() -> void:
	"""A sleep task whose walk is given up leaves the resident on its own (not holding as under an order), so the
	night sends it again; an ordinary task given up holds."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	v.brains[0]._abandon_trip()
	assert_equal(v.brains[0].order, BrainScript.ORDER_NONE, "on its own again")
	v.brains[1].order_task(CountedTask.new(100))
	v.brains[1]._abandon_trip()
	assert_equal(v.brains[1].order, BrainScript.ORDER_MOVE, "an order holds")


func test_a_placeholder_lies_down_procedurally_and_hides_indoors() -> void:
	"""With no sleep clip a body is tipped onto its back and lifted by LIE_BACK_LIFT of its height over what it lies
	on; indoors it is not drawn."""
	var space := CastSpaceScript.new()
	space.setup([] as Array[Dictionary], [] as Array[Vector3])
	var actor := DemoActorScript.new()
	actor.setup_placeholder(0, space, 3)
	assert_false(actor.lies_by_clip(), "no sleep clip: procedural")
	actor.brain.task_lie(Vector2(1.0, 2.0), 0.0, 0.5)
	actor._apply_transform()
	assert_almost_equal(actor.position.y, 0.5 + DemoActorScript.PLACEHOLDER_HEIGHT_M * DemoActorScript.LIE_BACK_LIFT, "lifted onto it")
	assert_almost_equal(actor.rotation.x, DemoActorScript.LIE_BACK_RAD, "on its back")
	assert_almost_equal(actor.position.z, 2.0 + DemoActorScript.PLACEHOLDER_HEIGHT_M * 0.5, "its middle, not its feet, at the spot")
	actor.brain.task_lie(Vector2(1.0, 2.0), PI * 0.5, 0.5)
	actor._apply_transform()
	assert_almost_equal(actor.position.x, 1.0 + DemoActorScript.PLACEHOLDER_HEIGHT_M * 0.5, "turned: its middle still on the spot")
	assert_almost_equal(actor.position.z, 2.0, "on the spot's line")
	actor.brain.task_rise(Vector2(1.0, 2.0))
	actor.brain.task_go_indoors(true, BrainScript.INTERIOR_HALL)
	actor._apply_transform()
	assert_false(actor.visible, "indoors: not drawn")
	assert_almost_equal(actor.rotation.x, 0.0, "up again")
	actor.free()


func test_the_squared_distance_decides_not_the_steps() -> void:
	"""From the origin, a bed at (3, 3) m is nearer (18 m² against 25) than one at (0, 5) m, though fewer steps away
	along the axes."""
	var out := PackedInt32Array()
	var beds := PackedInt32Array([1, 3072, 3072, S, 2, 0, 5120, S])
	AllocationScript.allocate(PackedInt32Array([-1]), PackedInt32Array([0, 0]), PackedByteArray([1]), beds, out)
	assert_equal(out[0], 1, "the diagonal bed")


func test_a_planned_bed_is_no_bed_yet() -> void:
	"""One bed in and one only planned: only the one in is allocated."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 1)
	var stores := StoresScript.new()
	stores.add_planks(2000)
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_BED, stores)
	v.night.step()
	assert_equal((1 if v.night.bed_of[0] >= 0 else 0) + (1 if v.night.bed_of[1] >= 0 else 0), 1, "one bed")


func test_a_player_s_order_at_night_is_carried_out_not_undone() -> void:
	"""A resident ordered to move at night keeps its order however long the night runs; only free ones are sent."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	v.brains[0].order_move(Vector2(3.0, -3.0))
	v.calendar.tick += NightScript.RESEND_TICKS * 3
	_run(v, 30)
	assert_equal(v.brains[0].order, BrainScript.ORDER_MOVE, "still on its order")


func test_one_held_by_the_rescue_is_not_parked() -> void:
	"""Held by the rescue at dusk: nothing of its work is parked, and it is not sent."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.brains[0].order_work(1, 0)
	v.brains[0].water_hold = true
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_equal(v.brains[0].unfinished_labels().size(), 0, "nothing parked")
	assert_equal(v.brains[0].order, BrainScript.ORDER_WORK, "still at work")


func test_the_bedless_go_in_at_the_hall_side_by_side() -> void:
	"""Resident 0 has the bed; residents 1 and 2 go in at the hall's door, the first bedless two steps left of it, the
	next one step."""
	var v := _village([MOUSE_U, MOUSE_U, MOUSE_U] as Array[int], 1)
	v.night.bed_of = PackedInt32Array([v.home * FixturesScript.PLACES, -1, -1])
	assert_equal(v.night.hall_spot(1), HALL_AT + Vector2(-2.0 * NightScript.HALL_SPACING_M, 0.0), "the first bedless")
	assert_equal(v.night.hall_spot(2), HALL_AT + Vector2(-NightScript.HALL_SPACING_M, 0.0), "the next")


func test_at_dawn_a_sleeper_gets_up_and_walks_across_its_floor() -> void:
	"""A frame after dawn a sleeper is up (not lying) but its night not over: it walks to the room's middle first."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 2400, _all_asleep.bind(v, 1))
	var task := v.brains[0].task as SleepTaskScript
	v.calendar.tick = TICK_MORNING
	_run(v, 1)
	assert_true(v.brains[0].task == task, "still its night")
	assert_equal(task.stage, SleepTaskScript.STAGE_UP, "getting up")
	assert_false(v.brains[0].lying, "up")
	assert_equal(v.brains[0].task_label(), "Getting up", "said")


func test_a_sleeper_crosses_the_floor_before_lying_down() -> void:
	"""Arrived in the home, it walks to its bedside first; it gets in only there -- FOOT_M off the bed's foot."""
	var v := _village([MOUSE_U] as Array[int], 1)
	v.calendar.tick = TICK_DUSK
	_run(v, 2400, func() -> bool: return (v.brains[0].task as SleepTaskScript).stage == SleepTaskScript.STAGE_TO_BED)
	var task := v.brains[0].task as SleepTaskScript
	assert_equal(task.stage, SleepTaskScript.STAGE_TO_BED, "arrived")
	_run(v, 1)
	assert_false(v.brains[0].lying, "not yet in bed: crossing the floor")
	assert_equal(v.brains[0].task_label(), "Getting into bed", "said")
	assert_almost_equal(task.bedside().distance_to(task._bed), SleepTaskScript.FOOT_M, "its bedside off the foot")


func test_each_home_lists_its_own_sleepers() -> void:
	"""Two homes: a home's panel names only those whose beds are in it."""
	var v := _village([MOUSE_U, MOUSE_U] as Array[int], 1)
	var other := _home_at(v.graph, Vector2i(10240, 8192))
	v.night.bed_of = PackedInt32Array([v.home * FixturesScript.PLACES, other * FixturesScript.PLACES])
	assert_equal(v.night.sleepers_of(v.home), "resident 0", "the first home")
	assert_equal(v.night.sleepers_of(other), "resident 1", "the second")


func _home_at(graph: GraphScript, at: Vector2i) -> int:
	"""Another home at `at`, dug, one bed in."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, at, 0, 0, ref), "a home laid")
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)
	graph.fit.phase_of(graph, ref[0], 0)
	graph.fit.phase[ref[0] * FixturesScript.PLACES] = FixturesScript.INSTALLED
	return ref[0]


# --- the crew and the installer, closer ---------------------------------------------------------------

func _crew_village(heights: Array[int]) -> Array:
	"""A village with a crew and two tables' worth of planks: [village, crew, stores]."""
	var v := _village(heights, 0)
	var crew := CrewScript.new()
	crew.configure(v.graph, v.brains)
	var stores := StoresScript.new()
	stores.add_planks(20000)
	stores.add_wood(10000)
	stores.add_stone(10000)
	return [v, crew, stores]


func test_the_installer_stands_before_the_place_and_walks_back_after() -> void:
	"""It stands STAND_OFF_M before the place while it works, registered in its bore heading neither way; the frame the
	fixture is in it is still on the task, walking back to the middle; once out of it, nothing to come back to."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_BED, pack[2])
	assert_true((pack[1] as CrewScript).give(v.home * FixturesScript.PLACES, 0), "given: a bed, 1.1 m from the middle to stand")
	var task := v.brains[0].task as InstallTaskScript
	_run_brains(v, 4000, func() -> bool: return task.stage == InstallTaskScript.STAGE_WORKING)
	assert_true(v.brains[0].position.distance_to(task.stand_at()) <= BrainScript.ARRIVE_RADIUS_M, "at its stand")
	assert_true(absf(task.stand_at().distance_to(task._at) - InstallTaskScript.STAND_OFF_M) < 0.001, "STAND_OFF_M before the place")
	assert_equal(v.space.resident_heading[v.brains[0].index], 0, "heading neither way in its bore")
	_run_brains(v, 4000, func() -> bool: return task.stage == InstallTaskScript.STAGE_BACK)
	_run_brains(v, 1, func() -> bool: return false)
	assert_true(v.brains[0].task == task, "in: still on the task, walking back")
	assert_null(task.unfinished(), "nothing to come back to once it is in")
	assert_false(task.take_back(v.brains[0]), "an installed fixture is not taken back")


func test_an_install_lost_on_the_way_goes_back_to_the_routine() -> void:
	"""An installer whose walk is given up goes back to its own routine (the crew hands the place out again)."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	(pack[1] as CrewScript).give(v.home * FixturesScript.PLACES + 4, 0)
	v.brains[0]._abandon_trip()
	assert_equal(v.brains[0].order, BrainScript.ORDER_NONE, "on its own again")


func test_the_crew_hands_out_on_time_three_at_most() -> void:
	"""Nothing before PICKUP_USEC, a hand-out at exactly it; five free residents and five waiting fixtures: three are
	put to it; the nearest first, the lower index on a tie."""
	var pack := _crew_village([MOUSE_U, MOUSE_U, MOUSE_U, MOUSE_U, MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var crew: CrewScript = pack[1]
	for k in 3:
		v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_BED, pack[2])
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_RUG, pack[2])
	for i in 5:
		v.brains[i].start_at(Vector2(float(i) * 0.5, -4.0) if i >= 2 else Vector2(-1.0 + 2.0 * float(i), -1.0), 0.0, -1, -1)
	crew.update(CrewScript.PICKUP_USEC - 1)
	assert_equal(crew.installers(), 0, "not yet")
	crew.update(1)
	assert_equal(crew.installers(), CrewScript.MAX_INSTALLERS, "three at most")
	assert_true(v.brains[0].task is InstallTaskScript and v.brains[1].task is InstallTaskScript, "the two nearest")
	assert_equal((v.brains[0].task as InstallTaskScript).place, 0, "the lower index on the tie takes the first")


func test_nobody_who_cannot_reach_the_room_is_given_a_fixture() -> void:
	"""The nearest resident fits no bore: the next nearest is given it; given straight to the one who cannot, refused."""
	var pack := _crew_village([MOUSE_U, MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var crew: CrewScript = pack[1]
	v.graph.set_body(v.brains[0].index, MOUSE_U, 1400)
	v.brains[1].start_at(Vector2(8.0, -8.0), 0.0, -1, -1)
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	var row := v.home * FixturesScript.PLACES + 4
	assert_false(crew.give(row, 0), "refused: it cannot reach it")
	assert_equal(crew.nearest_free(v.home), 1, "the next nearest")


func test_the_selected_take_only_the_room_s_own_fixtures() -> void:
	"""Fixtures waiting in two homes: the selection given one home's takes only that home's."""
	var pack := _crew_village([MOUSE_U, MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var other := _home_at(v.graph, Vector2i(10240, 8192))
	v.graph.fit.order(v.graph, other, RoomsScript.FIX_TABLE, pack[2])
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	assert_equal((pack[1] as CrewScript).give_selected(v.home, PackedInt32Array([0, 1])), 1, "only its own")
	assert_equal((v.brains[0].task as InstallTaskScript).room, v.home, "in its room")


func test_a_stroll_turns_on_the_spot_and_stops_short() -> void:
	"""A point behind it: the first step turns on the spot (no step taken); a point within ARRIVE_RADIUS_M: there
	already, not a step taken."""
	var v := _village([MOUSE_U] as Array[int], 0)
	var brain := v.brains[0]
	brain.yaw = 0.0
	var at := brain.position
	assert_false(brain.task_stroll_to(at + Vector2(0.0, -3.0), DT), "not there")
	assert_equal(brain.position, at, "turned on the spot, no step")
	assert_true(brain.task_stroll_to(at + Vector2(0.1, 0.0), DT), "near enough")
	assert_equal(brain.position, at, "no step taken")


# --- the review's cases (decision 0210 Review) ---------------------------------------------------------

func test_an_evacuee_home_at_night_goes_to_bed_and_keeps_its_job_for_morning() -> void:
	"""An emergency that ends at night (here an urgent task) does not put the resident back on its parked day job: it
	is sent to bed, the job kept; in the morning it is back on it."""
	var v := _village([MOUSE_U] as Array[int], 1)
	var job := CountedTask.new(1000000)
	v.brains[0].order_task(job)
	v.brains[0].order_task(CountedTask.new(3, true))
	assert_equal(v.brains[0].unfinished_labels(), PackedStringArray(["the counted job"]), "parked by the emergency")
	v.calendar.tick = TICK_DUSK
	_run(v, 1)
	assert_false(v.brains[0].task is SleepTaskScript, "an emergency is left be at dusk")
	v.calendar.tick += NightScript.RESEND_TICKS
	_run(v, 10)
	assert_true(v.brains[0].task is SleepTaskScript, "over at night: to bed, not back to the job")
	assert_equal(v.brains[0].unfinished_labels(), PackedStringArray(["the counted job"]), "the job kept for morning")
	_run(v, 2400, _all_asleep.bind(v, 1))
	v.calendar.tick = TICK_MORNING
	_run(v, 3000, func() -> bool: return v.brains[0].task == job)
	assert_true(v.brains[0].task == job, "back on it in the morning")


func test_an_installer_whose_fixture_is_taken_out_gives_up_and_goes() -> void:
	"""Working a fixture the player takes out, the installer walks back and out -- no longer an installer, nothing
	kept to come back to."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var crew: CrewScript = pack[1]
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_HEARTH, pack[2])
	crew.give(v.home * FixturesScript.PLACES + 3, 0)
	var task := v.brains[0].task as InstallTaskScript
	_run_brains(v, 4000, func() -> bool: return task.stage == InstallTaskScript.STAGE_WORKING)
	v.graph.fit.take_out(v.graph, v.home, RoomsScript.FIX_HEARTH, pack[2])
	_run_brains(v, 1, func() -> bool: return false)
	assert_equal(task.stage, InstallTaskScript.STAGE_BACK, "gives up")
	assert_null(task.unfinished(), "nothing to come back to")
	_run_brains(v, 3000, func() -> bool: return v.brains[0].task != task)
	assert_equal(crew.installers(), 0, "no installer left")


func test_one_held_by_the_rescue_is_given_no_fixture() -> void:
	"""The rescue holds it: give refuses before claiming, so the place still waits for another; nor is it free."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var crew: CrewScript = pack[1]
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	v.brains[0].water_hold = true
	assert_false(crew.give(v.home * FixturesScript.PLACES + 4, 0), "refused")
	assert_equal(v.graph.fit.worker[v.home * FixturesScript.PLACES + 4], -1, "not claimed")
	assert_false(crew.is_free(0), "held: not free")
	v.brains[0].water_hold = false
	v.brains[0].in_water = true
	assert_false(crew.is_free(0), "in the water: not free")


func test_a_keeper_that_takes_its_place_back_keeps_it_afresh_when_called_away() -> void:
	"""Kept, then taken back (the keep ends), then called away again: kept anew, its wait counted from then."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	var crew: CrewScript = pack[1]
	var row := v.home * FixturesScript.PLACES + 4
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	v.graph.fit.asked[row] = 0
	v.brains[0].order_move(Vector2(3.0, -3.0))
	crew.update(CrewScript.KEEP_USEC - 10)
	v.brains[0].release()
	assert_true(crew.give(row, 0), "taken back")
	assert_equal(v.graph.fit.asked[row], -1, "the keep ended")
	v.brains[0].order_move(Vector2(3.0, -3.0))
	assert_equal(v.graph.fit.asked[row], 0, "kept again")
	crew.update(20)
	assert_equal(v.graph.fit.asked[row], 0, "not lapsed: counted afresh")


func test_a_carrier_holding_in_a_cellar_lets_others_pass() -> void:
	"""Holding below after a carry, it is registered in its bore heading neither way."""
	var v := _village([MOUSE_U] as Array[int], 0)
	var brain := v.brains[0]
	brain.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.4], [0.0, 0.8]], "mean_speed_m_s": 0.4, "period_s": 2.0})
	brain.order_carry_below(v.graph.rooms.middle[v.home], Vector2(0.0, 9.0))
	_run_brains(v, 3000, func() -> bool: return brain.state == BrainScript.State.HOLD)
	assert_true(brain.underground, "below")
	assert_equal(v.space.resident_heading[brain.index], 0, "heading neither way")


func test_a_fixture_taken_out_before_its_installer_arrives_leaves_nothing_to_come_back_to() -> void:
	"""Taken out while its installer is still on the way: called away then, it keeps nothing."""
	var pack := _crew_village([MOUSE_U] as Array[int])
	var v: Village = pack[0]
	v.graph.fit.order(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	(pack[1] as CrewScript).give(v.home * FixturesScript.PLACES + 4, 0)
	var task := v.brains[0].task as InstallTaskScript
	v.graph.fit.take_out(v.graph, v.home, RoomsScript.FIX_TABLE, pack[2])
	assert_null(task.unfinished(), "nothing to come back to")


func test_a_kept_place_outlasts_the_night() -> void:
	"""Decision 0421: a fixture place kept for a resident called to bed waits a game day of demo time -- the calendar's
	own -- so it outlasts the night (20:00-05:59) and its installer comes back to it in the morning (at the old 60 s it
	would have lapsed at about 02:00)."""
	assert_equal(CrewScript.KEEP_USEC, CalendarScript.DAY_USEC, "a game day")
	var night_hours: int = SimClock.HOURS_PER_DAY - NightScript.DUSK_HOUR + NightScript.DAWN_HOUR
	assert_true(CrewScript.KEEP_USEC > night_hours * CalendarScript.HOUR_USEC, "longer than the night")
