extends "res://test/framework/test_case.gd"
## The care desk on real brains (decision 0622): a hurt resident sent to rest -- in the sickbay, in its own bed or at
## its field-care spot -- the best healer sent to it and the treatment done beside it; the news and the
## incident; supplies short and the herbalist gathering; the water's hazards as injuries; the sickbay's rules and its
## kept beds; and who may not be taken. No scene tree: hand-built spaces, a burrow home laid on the network and dug.

const Rules := preload("res://demo/infirmary/care_rules.gd")
const DeskScript := preload("res://demo/infirmary/care_desk.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")
const Tasks := preload("res://demo/infirmary/care_tasks.gd")
const Text := preload("res://demo/infirmary/care_text.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const Injury := preload("res://scripts/core/injury.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const DT: float = 1.0 / 30.0
const WALK_M_S: float = 1.0
const BODY_M: float = 0.25
const MOUSE_U: int = 1024
const HOME_AT: Vector2i = Vector2i(0, 8192)
const HALL_AT: Vector2 = Vector2(0.0, -6.0)
const PATCH: Vector2 = Vector2(6.0, -3.0)
## The herb shelf's delivery spot, clear of the hall's steps where wanderers stand.
const SHELF_AT: Vector2 = Vector2(3.0, -5.0)
## 09:00 on the first day (tick 0 is 06:00): daytime.
const MORNING: int = 3 * SimClock.TICKS_PER_HOUR
## The home's places (underground_rooms.gd FIXTURES): beds 0-2, the hearth 3, the hanging stores 7.
const HEARTH_PLACE: int = 3
const HANGING_PLACE: int = 7
const FED: int = 9000


class Village extends RefCounted:
	var space: CastSpaceScript = null
	var graph: GraphScript = null
	var brains: Array[BrainScript] = []
	var calendar: CalendarScript = CalendarScript.new()
	var notices: NoticesScript = NoticesScript.new()
	var incidents: IncidentsScript = IncidentsScript.new()
	var night: NightScript = null
	var desk: DeskScript = DeskScript.new()
	var home: int = -1
	var hunger: PackedInt32Array = PackedInt32Array()
	var rest: PackedInt32Array = PackedInt32Array()


func _lengths() -> Dictionary:
	"""Every clip the cast knows, with round lengths."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _village(count: int, beds: int = -1) -> Village:
	"""`count` mice in a row at the square; resident 1 the herbalist. With `beds` >= 0, a dug home with that many beds
	and the night over it (the hall's floor for the bedless at night)."""
	var v := Village.new()
	v.space = CastSpaceScript.new()
	var points: Array[Dictionary] = [{"name": NightScript.HALL_POI, "position": Vector3(HALL_AT.x, 0.0, HALL_AT.y),
		"capacity": 4}]
	v.space.setup(points, [] as Array[Vector3])
	v.graph = v.space.tunnels
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i in count:
		var brain := BrainScript.new()
		brain.configure(v.space, WALK_M_S, BODY_M, 31 + i, _lengths())
		brain.start_at(Vector2(-3.0 + 1.5 * float(i), -1.0), 0.0, -1, -1)
		v.graph.set_body(brain.index, MOUSE_U, 256)
		v.brains.append(brain)
		names.append("resident %d" % i)
		keys.append(Rules.HERBALIST_KEY if i == 1 else StringName("mouse_%d" % i))
	v.calendar.tick = MORNING
	if beds >= 0:
		_night_over(v, names, beds)
	_open_desk(v, names, keys, beds >= 0)
	return v


func _open_desk(v: Village, names: PackedStringArray, keys: Array[StringName], rooms: bool) -> void:
	"""The desk over the village (its rooms when it has them), its news bound, every resident fed and rested."""
	var count: int = v.brains.size()
	var sizes := PackedByteArray()
	sizes.resize(count)
	v.desk.configure(v.brains, names, keys, sizes, v.night, v.graph if rooms else null)
	v.notices.bind_calendar(v.calendar)
	v.incidents.bind(v.notices, v.calendar, NewsClockScript.new())
	v.desk.bind_news(v.notices, v.incidents)
	v.desk.set_places(PATCH, SHELF_AT)
	v.desk.start_at(MORNING, 1)
	for column: PackedInt32Array in [v.hunger, v.rest]:
		column.resize(count)
		column.fill(FED)


func _night_over(v: Village, names: PackedStringArray, beds: int) -> void:
	"""A dug home with `beds` beds, and the night over the village's residents (the hall's floor for the bedless)."""
	v.home = _home(v.graph, beds)
	v.night = NightScript.new()
	var heights := PackedInt32Array()
	for i in v.brains.size():
		heights.append(MOUSE_U)
	v.night.configure(v.graph, v.brains, names, heights, v.calendar, v.notices)
	v.night.set_hall(HALL_AT)


func _home(graph: GraphScript, beds: int) -> int:
	"""A home at HOME_AT, dug, with `beds` beds put in (test_demo_night.gd's own way)."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, HOME_AT, 0, 0, ref), "a home laid")
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)
	for f in beds:
		_install(graph, ref[0], f)
	return ref[0]


func _install(graph: GraphScript, r: int, f: int) -> void:
	"""The fixture place `f` of room `r` takes, put in."""
	graph.fit.phase_of(graph, r, f)
	graph.fit.phase[r * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.fit.revision += 1


func _run(v: Village, frames: int, until: Callable = Callable()) -> int:
	"""Step the calendar (a tick a frame), the night, every brain and the desk; stop early once `until() -> bool`."""
	for f in frames:
		v.calendar.tick += 1
		if v.night != null:
			v.night.step()
		for brain in v.brains:
			brain.step(DT)
		var now := v.calendar.now()
		v.desk.update(v.calendar.tick, now.absolute_day, now.season, v.hunger, v.rest,
			v.night != null and v.night.is_night())
		v.incidents.sweep()
		if until.is_valid() and bool(until.call()):
			return f + 1
	return frames


func _treated(v: Village, i: int) -> bool:
	"""Whether resident `i` is no longer hurt."""
	return not v.desk.state.is_hurt(i)


# --- the loop -----------------------------------------------------------------------------------------------------

func test_a_hurt_resident_rests_and_the_herbalist_treats_it_where_it_stands() -> void:
	"""No beds: the patient lies down where it stands; the herbalist (HEAL 2), not the nearer resident 2, comes,
	tends it for 60 WU at factor 1100 and it is well again; said in the news; the incident resolves."""
	var v := _village(3)
	v.brains[1].start_at(Vector2(6.0, -1.0), 0.0, -1, -1)
	assert_equal(v.desk.test_hurt(PackedInt32Array([0]), false), 1, "bitten")
	_run(v, 2)
	assert_true(v.brains[0].task is Tasks.BedRest, "resting")
	assert_equal((v.brains[0].task as Tasks.BedRest).where, Tasks.WHERE_FIELD, "no bed: the field-care spot")
	assert_equal(v.desk.healer_of(0), 1, "the herbalist")
	assert_true(v.brains[1].task is Tasks.Treat, "on its way")
	var serial: int = v.incidents.serial_of(DeskScript.INCIDENT_KEY % 0)
	assert_true(serial > 0, "an incident")
	assert_true(v.notices.has_summary(Text.hurt_summary("resident 0", Injury.KIND_BITE)), "in the news")
	var took := _run(v, 4000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "treated within %d frames" % took)
	var health: int = v.desk.state.health(0)
	assert_true(health >= 90 and health <= 92, "80, +1 an hour fed and rested while untreated, then +10: %d" % health)
	assert_equal([v.desk.state.herb_milli, v.desk.state.cloth_milli], [11000, 23500], "paid once")
	assert_true(v.notices.has_text(Text.treated_notice("resident 1", "resident 0", Injury.KIND_BITE, health)), "said")
	assert_equal(v.desk.state.heal_xp[1], Rules.xp_of_level(2) + 600, "the herbalist's 600 XP")
	_run(v, 30)
	assert_equal(v.incidents.state_of(serial), IncidentsScript.STATE_RESOLVED, "resolved: up again")
	assert_false(v.brains[0].task is Tasks.BedRest, "up")
	assert_false(v.brains[1].task is Tasks.Treat, "the healer free")


func test_the_patient_rests_in_its_own_bed_and_the_healer_comes_down_to_it() -> void:
	"""With a home and its beds, the patient goes to its own bed (the night's allocation) and lies in it; the healer
	walks in, stands beside it and works only while it lies there."""
	var v := _village(2, 2)
	v.night.allocate()
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 2)
	var rest := v.brains[0].task as Tasks.BedRest
	assert_not_null(rest, "resting")
	assert_equal([rest.where, rest.bed, rest.sickbay], [Tasks.WHERE_BED, v.night.bed_of[0], false], "its own bed")
	var took := _run(v, 6000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "treated within %d frames" % took)
	assert_true(v.brains[1].underground, "the healer came down")


func test_without_a_bed_the_patient_lies_at_its_field_care_spot() -> void:
	"""No bed: it walks to its field-care spot and lies on the ground there; the healer tends it beside it; up again,
	it stands."""
	var v := _village(2, 0)
	v.desk.set_field_spot(func(i: int) -> Vector2: return Vector2(1.0 + float(i), 2.0))
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 2)
	var rest := v.brains[0].task as Tasks.BedRest
	assert_equal(rest.where, Tasks.WHERE_FIELD, "the field-care spot")
	_run(v, 600, func() -> bool: return rest.in_place())
	assert_true(v.brains[0].lying, "lying down")
	assert_true(v.brains[0].position.distance_to(Vector2(1.0, 2.0)) < 0.6, "at its spot")
	assert_true(v.brains[0].task_label().begins_with("Resting at the field-care spot"), "said")
	var took := _run(v, 6000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "treated within %d frames" % took)
	_run(v, 20)
	assert_false(v.brains[0].lying, "up again")


func test_a_serious_injury_keeps_the_patient_in_bed_until_seventy() -> void:
	"""P4: exposure (−35) and a bite (−20) leave 45; treated (+10) it is still under 70, so it rests on until it is back
	at 70, then gets up."""
	var v := _village(2)
	v.desk.test_hurt(PackedInt32Array([0]), true)
	v.desk.hurt(0, Injury.KIND_BITE, 1, 20, NoticesScript.SOURCE_CREW)
	assert_equal(v.desk.state.health(0), 45, "100 − 35 − 20")
	_run(v, 6000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "treated")
	assert_true(v.desk.state.health(0) < Rules.UP_HEALTH, "still under 70")
	assert_true(v.desk.resting(0), "resting on")
	assert_true(v.desk.card_text(0, true).begins_with("Recovering · health"), "the card says it")
	_run(v, 20 * SimClock.TICKS_PER_HOUR, func() -> bool: return not v.desk.resting(0))
	assert_true(v.desk.state.health(0) >= Rules.UP_HEALTH, "up at 70")
	assert_false(v.desk.resting(0), "up")


# --- supplies and herbs -------------------------------------------------------------------------------------------

func test_no_herbs_the_patient_waits_and_the_herbalist_gathers_then_treats() -> void:
	"""Herbs 0: a minor patient is not kept in bed (UP AND ABOUT), nobody is sent, the incident needs a decision and the
	card says why; the herbalist gathers a trip at the patch and carries it to the shelf; then the patient rests and is
	treated."""
	var v := _village(3)
	v.desk.state.herb_milli = 0
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 20)
	assert_false(v.desk.resting(0), "up and about: the shelf cannot pay")
	assert_equal(v.desk.healer_of(0), DeskScript.NOBODY, "nobody sent")
	assert_true(v.desk.card_text(0, true).contains("Waiting: " + Text.WAIT_NO_HERB), "the card says why")
	var serial: int = v.incidents.serial_of(DeskScript.INCIDENT_KEY % 0)
	assert_equal(v.incidents.state_of(serial), IncidentsScript.STATE_NEEDS_DECISION, "needs a decision")
	assert_not_null(v.desk.gatherer(), "the herbalist gathers")
	assert_true(v.brains[1].task is Tasks.Gather, "it is gathering")
	var patch_before: int = v.desk.state.patch_milli
	_run(v, 20000, func() -> bool: return v.desk.state.herb_milli > 0)
	assert_equal(v.desk.state.herb_milli, Rules.HERB_TRIP_MILLI, "a trip's load on the shelf")
	assert_equal(v.desk.state.patch_milli, patch_before - Rules.HERB_TRIP_MILLI, "taken from the patch")
	assert_true(v.notices.has_text("resident 1 brought 4.0 U of herbs to the shelf (4.0 U)"), "said")
	_run(v, 8000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "then treated")


func test_the_herbalist_does_not_gather_at_night_or_with_the_shelf_full() -> void:
	"""At the target (12 U) nobody gathers; short of it by night, nobody either."""
	var v := _village(2, 0)
	_run(v, 5)
	assert_null(v.desk.gatherer(), "the shelf is full")
	v.desk.state.herb_milli = 0
	v.calendar.tick = 15 * SimClock.TICKS_PER_HOUR
	_run(v, 5)
	assert_true(v.night.is_night(), "21:00")
	assert_null(v.desk.gatherer(), "not by night")


# --- the water ----------------------------------------------------------------------------------------------------

func test_an_exhausted_swimmer_is_hurt_and_an_airless_one_exposed() -> void:
	"""HAZ-003: the water's exhausted latch is an EXHAUSTION injury, said from the water; HAZ-002: below with no air an
	EXPOSURE one; the re-arm follows the water's own."""
	var v := _village(3)
	var swim := SwimStateScript.new()
	var species := PackedStringArray(["mouse", "otter", "mouse"])
	swim.setup(species, PackedInt32Array([MOUSE_U, MOUSE_U, MOUSE_U]))
	swim.exhausted_latch[0] = 1
	swim.mode[2] = SwimStateScript.MODE_DISTRESS_UNDER
	swim.air[2] = 0
	v.desk.watch_water(swim)
	assert_equal([v.desk.state.kind(0), v.desk.state.severity(0)], [Injury.KIND_EXHAUSTION, 1], "exhaustion")
	assert_equal([v.desk.state.kind(2), v.desk.state.severity(2)], [Injury.KIND_EXPOSURE, 2], "exposure")
	assert_true(v.desk.state.is_airless(2), "airless")
	_run(v, 1)
	assert_true(v.notices.has_text(Text.hurt_notice("resident 0", Injury.KIND_EXHAUSTION, 1, 0, "in the water")), "said")
	swim.mode[2] = SwimStateScript.MODE_LAND
	swim.air[2] = 600
	swim.exhausted_latch[0] = 0
	swim.rest[0] = 4000
	v.desk.watch_water(swim)
	assert_false(v.desk.state.is_airless(2), "breathing")
	assert_false(v.desk.state.exhaustion_latched(0), "re-armed")


# --- who may be taken ---------------------------------------------------------------------------------------------

func test_the_player_s_order_and_an_emergency_are_left_alone() -> void:
	"""A hurt resident under the player's move order is not taken until it is free; nor a healer in an emergency."""
	var v := _village(2)
	v.brains[0].order_move(Vector2(3.0, 3.0))
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 2)
	assert_false(v.desk.may_take(0), "under the player's order")
	assert_false(v.brains[0].task is Tasks.BedRest, "left alone")
	v.brains[0].release()
	_run(v, 40)
	assert_true(v.desk.resting(0), "free: resting")
	var w := _village(3)
	w.brains[1].in_water = true
	w.desk.test_hurt(PackedInt32Array([0]), false)
	_run(w, 2)
	assert_equal(w.desk.healer_of(0), 2, "the herbalist in the water: the other one")


# --- the sickbay --------------------------------------------------------------------------------------------------

func test_a_home_becomes_the_sickbay_only_when_whole() -> void:
	"""A bed, a hearth (warm) and hanging stores (the herb shelf): each missing piece is the refusal in words."""
	var v := _village(2, 0)
	assert_equal(v.desk.sickbay_refusal(v.home), DeskScript.NEEDS_BED, "no bed")
	_install(v.graph, v.home, 0)
	assert_equal(v.desk.sickbay_refusal(v.home), DeskScript.NEEDS_HEARTH, "no hearth")
	_install(v.graph, v.home, HEARTH_PLACE)
	assert_equal(v.desk.set_sickbay(v.home), DeskScript.NEEDS_SHELF, "no shelf")
	assert_false(v.desk.is_designated(), "not made")
	_install(v.graph, v.home, HANGING_PLACE)
	assert_equal(v.desk.set_sickbay(v.home), "", "made")
	assert_true(v.desk.sickbay_valid(), "valid")
	assert_equal(v.desk.sickbay_refusal(5), DeskScript.NOT_A_HOME, "no such room")
	assert_true(v.desk.home_lines(v.home).begins_with("This home is the sickbay"), "said")


func test_the_sickbay_s_beds_are_kept_for_the_sick_who_mend_twice_as_fast() -> void:
	"""Made the sickbay, its beds leave the night's allocation; a patient lies in one and recovers at +4 an hour."""
	var v := _village(2, 2)
	_install(v.graph, v.home, HEARTH_PLACE)
	_install(v.graph, v.home, HANGING_PLACE)
	v.night.allocate()
	assert_true(v.night.bed_of[0] != AllocationScript.NO_BED, "a bed before")
	assert_equal(v.desk.set_sickbay(v.home), "", "the sickbay")
	assert_equal([v.night.bed_of[0], v.night.bed_of[1]], [AllocationScript.NO_BED, AllocationScript.NO_BED], "kept")
	v.desk.test_hurt(PackedInt32Array([0]), true)
	v.desk.hurt(0, Injury.KIND_BITE, 1, 20, NoticesScript.SOURCE_CREW)
	_run(v, 2)
	var rest := v.brains[0].task as Tasks.BedRest
	assert_true(rest.sickbay and rest.room == v.home, "to the sickbay")
	_run(v, 4000, func() -> bool: return v.desk.state.in_infirmary(0))
	assert_true(v.desk.state.in_infirmary(0), "lying in it: the infirmary's rate")
	assert_equal(v.desk.state.rate_per_hour(0), -4, "serious: no recovery yet")
	_run(v, 6000, _treated.bind(v, 0))
	assert_equal(v.desk.state.rate_per_hour(0), 4, "treated: +4 an hour")
	v.desk.clear_sickbay()
	assert_true(v.night.bed_of[1] != AllocationScript.NO_BED, "its beds the night's again")


# --- the card -----------------------------------------------------------------------------------------------------

func test_the_card_lines() -> void:
	"""Alone: the injury, its untreated hours and rate, its care; the herbalist's skill; in a group a short word."""
	var v := _village(3)
	assert_equal(v.desk.card_text(0, true), "", "well: nothing")
	assert_equal(v.desk.card_text(1, true), "Healing · Level 2", "the herbalist's skill")
	v.desk.test_hurt(PackedInt32Array([0]), false)
	var lines: PackedStringArray = v.desk.card_text(0, true).split("\n")
	assert_equal(lines[0], "Hurt: a bite (minor) · health 80", "the injury")
	assert_equal(lines[1], "Untreated 0 h · health +1 an hour", "the rate (fed, rested: −1 untreated, +2 recovering)")
	assert_equal(lines[2], "Waiting: " + Text.WAIT_GOING, "on the way to a bed")
	assert_equal(v.desk.card_text(0, false), "hurt (bite)", "the group's word")
	assert_false(v.desk.card_text(0, true).contains("Work at"), "80 health: full pace")
	v.desk.test_hurt(PackedInt32Array([2]), true)
	assert_true(v.desk.card_text(2, true).contains("Work at 85% (health 85%)"), "65 health: the pace slowed")
	assert_equal(v.desk.patients_line(), "Patients: resident 0 (hurt (bite)), resident 2 (hurt (exposure))", "the patients")
	assert_equal(v.desk.test_hurt(PackedInt32Array([7]), false), 0, "nobody by that number")


# --- choosing (mutation testing) ------------------------------------------------------------------------------------

class UrgentTask extends "res://demo/tunnel/tunnel_task.gd":
	func step(_brain: RefCounted, _delta: float) -> bool:
		"""Holds the resident."""
		return true

	func urgent() -> bool:
		"""An emergency."""
		return true


func test_equal_healers_the_nearer_goes_and_one_not_up_does_not() -> void:
	"""Equal HEAL levels: the nearer; a resident under 70 health (not hurt) is not sent; nor one in an emergency."""
	var v := _village(4)
	v.desk.state.heal_xp[1] = 0
	v.desk.test_hurt(PackedInt32Array([0]), false)
	assert_equal(v.desk.choose_healer(0), 1, "resident 1 nearer than 2 and 3")
	v.desk.state.hurt(1, Injury.KIND_CUT, 1, 45)
	v.desk.state.pay_treatment(1)
	v.desk.state.care(1, 3, 750, 1000)
	assert_true(v.desk.state.health(1) < Rules.UP_HEALTH and not v.desk.state.is_hurt(1), "resident 1 recovering")
	assert_equal(v.desk.choose_healer(0), 2, "not one under 70")
	v.brains[2].order_task(UrgentTask.new())
	assert_false(v.desk.may_take(2), "an emergency is left alone")
	assert_equal(v.desk.choose_healer(0), 3, "nor one in an emergency")


func test_a_resting_patient_is_not_sent_again() -> void:
	"""Each dispatch leaves a resting patient's rest as it is."""
	var v := _village(2)
	v.desk.state.herb_milli = 0
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 2)
	var rest: Object = v.brains[0].task
	_run(v, 4 * DeskScript.DISPATCH_TICKS)
	assert_true(v.brains[0].task == rest, "the same rest")


func test_treatment_counts_only_while_the_patient_lies_in_place() -> void:
	"""Beside the bed but the patient not yet lying: no work counts."""
	var rest := Tasks.BedRest.new(0, func() -> bool: return false, func() -> bool: return false)
	rest.in_field(Vector2.ZERO)
	var treat := Tasks.Treat.new(1, rest, BrainScript.new(), func() -> bool: return true, func() -> String: return "",
		Callable())
	treat.stage = Tasks.Treat.STAGE_WORKING
	assert_false(treat.working(), "the patient not lying yet")


func test_a_patient_ordered_away_lets_its_healer_go() -> void:
	"""The player orders the patient off its rest: the healer stops; the care work done stays the patient's; free
	again, it rests and a healer comes again."""
	var v := _village(2)
	v.desk.test_hurt(PackedInt32Array([0]), false)
	_run(v, 6000, func() -> bool: return v.desk.state.care_mwu(0) > 10000)
	var done: int = v.desk.state.care_mwu(0)
	assert_true(done > 10000, "part treated")
	v.brains[0].order_move(Vector2(4.0, 4.0))
	_run(v, 60)
	assert_equal(v.desk.healer_of(0), DeskScript.NOBODY, "the healer stood down")
	assert_false(v.brains[1].task is Tasks.Treat, "and is free")
	assert_true(v.desk.state.care_mwu(0) >= done, "the work kept")
	v.brains[0].release()
	_run(v, 8000, _treated.bind(v, 0))
	assert_true(_treated(v, 0), "treated in the end")


# --- the review's cases (decision 0622) ------------------------------------------------------------------------------

func test_one_treatment_s_herbs_send_one_healer_and_a_short_shelf_stands_one_down() -> void:
	"""H1: herb for one treatment and two serious patients: one healer is sent. A healer beside a patient whose shelf
	then runs short is sent back, and the patient says why."""
	var v := _village(4)
	v.desk.state.herb_milli = 1000
	v.desk.test_hurt(PackedInt32Array([0, 2]), true)
	_run(v, 40)
	var sent: int = (1 if v.desk.healer_of(0) != DeskScript.NOBODY else 0) + (1 if v.desk.healer_of(2) != DeskScript.NOBODY else 0)
	assert_equal(sent, 1, "one healer for one treatment's herbs")
	var w := _village(3)
	w.desk.test_hurt(PackedInt32Array([0]), true)
	_run(w, 100, func() -> bool: return w.desk.healer_of(0) != DeskScript.NOBODY)
	assert_true(w.desk.healer_of(0) != DeskScript.NOBODY and not w.desk.state.is_paid(0), "on the way, not yet paid")
	w.desk.state.herb_milli = 0
	_run(w, 6000, func() -> bool: return w.desk.healer_of(0) == DeskScript.NOBODY)
	assert_false(w.desk.state.is_paid(0), "never paid")
	assert_equal(w.desk.healer_of(0), DeskScript.NOBODY, "stood down")
	assert_true(w.desk.card_text(0, true).contains("Waiting: " + Text.WAIT_NO_HERB), "the patient says why: "
		+ w.desk.card_text(0, true))


func test_a_patient_gets_up_to_eat_and_when_it_cannot_recover() -> void:
	"""H2: hungry (3500 or lower), a hurt minor patient is not kept in bed; treated, a patient under 70 whose hunger is
	under 4000 gets up (it cannot recover lying there); a serious one with no herbs rests on."""
	var v := _village(3)
	v.desk.test_hurt(PackedInt32Array([0]), false)
	v.hunger[0] = 3500
	_run(v, 40)
	assert_false(v.desk.resting(0), "hungry: up to eat")
	v.hunger[0] = 9000
	_run(v, 40)
	assert_true(v.desk.resting(0), "fed: resting")
	v.desk.state.hurt(2, Injury.KIND_CUT, 1, 45)
	v.desk.state.pay_treatment(2)
	v.desk.state.care(2, 1, 750, 1000)
	v.hunger[2] = 3900
	_run(v, 2)
	assert_true(v.desk.may_get_up(2), "treated at 65 but hungry: may get up")
	var w := _village(2)
	w.desk.state.herb_milli = 0
	w.desk.test_hurt(PackedInt32Array([0]), true)
	_run(w, 40)
	assert_true(w.desk.resting(0), "serious, no herbs: rests on")


func test_a_suspended_sickbay_keeps_its_beds_and_stops_its_rate() -> void:
	"""REQ-SET-129: the sickbay's hearth taken out, its care is suspended (no +4) though it stays the sickbay; two patients
	lie in two different beds."""
	var v := _village(3, 2)
	_install(v.graph, v.home, HEARTH_PLACE)
	_install(v.graph, v.home, HANGING_PLACE)
	v.desk.set_sickbay(v.home)
	v.desk.test_hurt(PackedInt32Array([0, 2]), false)
	_run(v, 4000, func() -> bool: return v.desk.state.in_infirmary(0) and v.desk.state.in_infirmary(2))
	assert_true(v.desk.state.in_infirmary(0) and v.desk.state.in_infirmary(2), "both in")
	var r0 := v.brains[0].task as Tasks.BedRest
	var r2 := v.brains[2].task as Tasks.BedRest
	assert_true(r0.bed != r2.bed, "two beds")
	assert_equal(v.night.sleepers_of(v.home), NightScript.KEPT_WORDS, "the room says its beds are kept")
	v.graph.fit.phase[v.home * FixturesScript.PLACES + HEARTH_PLACE] = FixturesScript.EMPTY
	v.graph.fit.revision += 1
	_run(v, 2)
	assert_true(v.desk.is_designated() and not v.desk.sickbay_valid(), "suspended")
	assert_false(v.desk.state.in_infirmary(0), "no +4")
	assert_true(v.desk.home_lines(v.home).contains("Its care is suspended"), "said")


func test_the_incident_recovers_then_resolves() -> void:
	"""Treated under 70, the incident is Recovering; up again, Resolved."""
	var v := _village(2)
	v.desk.test_hurt(PackedInt32Array([0]), true)
	v.desk.hurt(0, Injury.KIND_BITE, 1, 20, NoticesScript.SOURCE_CREW)
	_run(v, 6000, _treated.bind(v, 0))
	var serial: int = v.incidents.serial_of(DeskScript.INCIDENT_KEY % 0)
	assert_equal(v.incidents.state_of(serial), IncidentsScript.STATE_RECOVERING, "recovering")
	assert_equal(v.desk.incident_state(0), IncidentsScript.STATE_RECOVERING, "the watch")


func test_a_patient_under_treatment_stays_and_a_cleared_sickbay_keeps_its_patient_s_bed() -> void:
	"""Hungry while a healer tends it, a patient stays for the treatment; the sickbay cleared while a patient lies in its
	bed, that bed stays the patient's (resident 2: the lower ones are allocated first) and no sleeper is given it."""
	var v := _village(3, 2)
	_install(v.graph, v.home, HEARTH_PLACE)
	_install(v.graph, v.home, HANGING_PLACE)
	v.desk.set_sickbay(v.home)
	v.desk.test_hurt(PackedInt32Array([2]), true)
	_run(v, 6000, func() -> bool: return v.desk.healer_of(2) != DeskScript.NOBODY)
	v.hunger[2] = 3000
	_run(v, 2)
	assert_false(v.desk.may_get_up(2), "a healer on it: it stays")
	v.hunger[2] = 9000
	_run(v, 4000, func() -> bool: return v.desk.state.in_infirmary(2))
	var bed: int = (v.brains[2].task as Tasks.BedRest).bed
	v.desk.clear_sickbay()
	assert_equal(v.night.bed_of[2], bed, "its bed stays its own")
	assert_false(v.night.bed_of[0] == bed or v.night.bed_of[1] == bed, "no sleeper is given it")
