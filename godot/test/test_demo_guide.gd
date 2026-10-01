extends "res://test/framework/test_case.gd"
## The first-village guide (decision 0481; review F49, P7, UX-017): each of the four objectives completing ONLY on its
## real outcome in the village's own models -- never an order, a cut, a plan, a call or a timer; an objective done
## before its card came up recognised as "Already done"; no softlock when a target is lost (another valid target, or a
## reason and a next action, always); skip and reopen granting and losing nothing; a pause completing nothing; the
## completion chronicled once. The card's words and the world marker's target come from guide_status.gd.
##
## No scene tree and no staged assets: real farm, pantry, kitchen (with real brains walking a hand-made village),
## bridges over the authored water, and brains for the walkers.

const FactsScript := preload("res://demo/guide/guide_facts.gd")
const StepsScript := preload("res://demo/guide/guide_steps.gd")
const StatusScript := preload("res://demo/guide/guide_status.gd")
const WorldScript := preload("res://demo/guide/guide_world.gd")
const Text := preload("res://demo/guide/guide_text.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const TunnelJobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GuideScript := preload("res://demo/guide/demo_guide.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const CARROT: int = 2
const OATS: int = 15
const CARROT_BED: int = 2
const DT: float = 1.0 / 30.0
const FRAMES_PER_HOUR: int = SimClock.TICKS_PER_HOUR

static var _map: RefCounted = null

var _read: IntMath.IntResult = IntMath.IntResult.new()
var _selection: PackedInt32Array = PackedInt32Array()


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of `day` (day 0 is spring 1)."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


func _world() -> WorldScript:
	"""A world over a fresh farm and pantry, the test's own selection, and a calendar at the demo's opening."""
	var world := WorldScript.new()
	_selection = PackedInt32Array()
	world.selected = func() -> PackedInt32Array: return _selection
	world.sim = SimScript.new()
	world.pantry = PantryScript.new(StorageScript.new(Vector2.ZERO))
	world.calendar = world.sim.calendar
	world.jobs = JobsScript.new()
	return world


func _brain(at: Vector2) -> BrainScript:
	"""A resident's brain standing at `at` on the surface (its fields are what the guide reads)."""
	var brain := BrainScript.new()
	brain.position = at
	return brain


func _ripen(sim: SimScript, bed: int) -> void:
	"""Run the farm's own calendar until `bed` is ripe."""
	for hour: int in 400:
		if sim.stage_of(bed) == SimScript.STAGE_RIPE:
			return
		sim.advance_usec(CalendarScript.HOUR_USEC)


func _deliver(pantry: PantryScript, item: int, milli: int) -> int:
	"""A real delivery: reserve room, shelve against the hold. Returns what was stored."""
	assert_true(pantry.reserve_near_into(item, milli, Vector2.ZERO, _read), "room reserved")
	var hold: int = _read.value
	pantry.hold_location_into(hold, _read)
	pantry.store_upto_into(item, milli, _read.value, hold, _read)
	pantry.release(hold)
	return _read.value


# --- 1: meet a villager ------------------------------------------------------------------------------

func test_meeting_completes_on_a_selection_only() -> void:
	"""Nothing selected: not done, and the card points at the resident nearest the camera with the next action. A
	resident selected: done, and its confirmation names it."""
	var world := _world()
	world.brains.append(_brain(Vector2(10.0, 0.0)))
	world.brains.append(_brain(Vector2(1.0, 1.0)))
	world.name_of = func(i: int) -> String: return "Resident %d" % i
	var facts := FactsScript.new()
	facts.observe(world)
	assert_false(StepsScript.is_done(StepsScript.STEP_MEET, facts), "not done unselected")
	var status := StatusScript.Status.new()
	StatusScript.resolve_into(StepsScript.STEP_MEET, world, facts, status)
	assert_equal(status.target_kind, NoticesScript.TARGET_RESIDENT, "the marker is on a resident")
	assert_equal(status.target_id, 1, "the one nearest the camera's focus")
	assert_equal(status.next, Text.NEXT_SELECT, "the next legal action")
	_selection = PackedInt32Array([0])
	facts.observe(world)
	assert_true(StepsScript.is_done(StepsScript.STEP_MEET, facts), "done once selected")
	assert_true(StatusScript.confirm_text(StepsScript.STEP_MEET, world, facts).begins_with("Resident 0 is selected"),
		"the confirmation names the resident")


func test_meeting_with_everyone_indoors_offers_the_roster() -> void:
	"""Nobody on the surface (asleep, below): no marker, and the roster is the way (never a dead end)."""
	var world := _world()
	var below := _brain(Vector2.ZERO)
	below.underground = true
	var asleep := _brain(Vector2(2.0, 0.0))
	asleep.lying = true
	world.brains.append(below)
	world.brains.append(asleep)
	var status := StatusScript.Status.new()
	StatusScript.resolve_into(StepsScript.STEP_MEET, world, FactsScript.new(), status)
	assert_equal(status.target_point, Vector3.INF, "no marker")
	assert_equal(status.next, Text.NEXT_SELECT_LIST, "Residents (L) instead")


# --- 2: bring in a harvest ---------------------------------------------------------------------------

func test_a_harvest_counts_only_once_it_is_shelved() -> void:
	"""The order on the board, the crop cut, food stocked by hand: none is a harvest in store. The delivery is."""
	var world := _world()
	var facts := FactsScript.new()
	_ripen(world.sim, CARROT_BED)
	assert_true(world.jobs.open_into(JobsScript.KIND_HARVEST, CARROT_BED, 0, _read), "a harvest ordered")
	facts.observe(world)
	assert_false(StepsScript.is_done(StepsScript.STEP_HARVEST, facts), "an order is not a harvest")
	var cut: int = world.sim.harvest(CARROT_BED).value
	assert_true(cut > 0, "the crop is cut")
	facts.observe(world)
	assert_false(StepsScript.is_done(StepsScript.STEP_HARVEST, facts), "a cut crop in hand is not in store")
	assert_true(world.pantry.add_into(OATS, 5000, 0, _read), "food stocked by hand")
	facts.observe(world)
	assert_false(StepsScript.is_done(StepsScript.STEP_HARVEST, facts), "stocking is not a delivery")
	assert_equal(_deliver(world.pantry, CARROT, cut), cut, "the load shelved")
	facts.observe(world)
	assert_true(StepsScript.is_done(StepsScript.STEP_HARVEST, facts), "done once shelved")
	assert_equal(facts.harvested_milli, cut, "the amount shelved")
	assert_true(StatusScript.confirm_text(StepsScript.STEP_HARVEST, world, facts).contains("of carrot came into store"),
		"the confirmation names the crop")


func test_the_harvest_card_follows_the_beds() -> void:
	"""Opening farm (nothing ripe): the soonest bed with its hours; ripe: that bed and the order; a harvest on the board:
	who has it; the store full: make room."""
	var world := _world()
	var status := StatusScript.Status.new()
	var facts := FactsScript.new()
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_equal(status.target_id, CARROT_BED, "the carrot bed ripens soonest")
	assert_true(status.state.begins_with("Nothing is ripe yet: the carrot bed ripens in about"), status.state)
	_ripen(world.sim, CARROT_BED)
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_equal(status.state, Text.RIPE_BED % "carrot bed", "ripe")
	assert_equal(status.next, Text.NEXT_HARVEST, "the order")
	world.jobs.open_into(JobsScript.KIND_HARVEST, CARROT_BED, 0, _read)
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_true(status.state.begins_with("Under way: the field crew"), status.state)
	world.pantry.add_into(OATS, StorageScript.STORE_CAPACITY_U * 1000, 0, _read)
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_equal(status.state, Text.STORE_FULL, "no room")
	assert_equal(status.next, Text.NEXT_MAKE_ROOM, "make room")


func test_a_lost_harvest_target_never_softlocks() -> void:
	"""The ripe carrot is harvested by someone else and the bed is empty; then every bed is empty; then every crop is
	lost: each time the card names another target and a legal next action."""
	var world := _world()
	var status := StatusScript.Status.new()
	var facts := FactsScript.new()
	_ripen(world.sim, CARROT_BED)
	world.sim.harvest(CARROT_BED)
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_true(status.target_id != CARROT_BED and status.target_kind == NoticesScript.TARGET_BED,
		"another bed (%d)" % status.target_id)
	assert_false(status.next.is_empty(), "a next action")
	for bed: int in Catalog.BED_COUNT:
		_uproot(world.sim, bed)
	StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, facts, status)
	assert_equal(status.state, Text.NOTHING_GROWING, "nothing growing")
	assert_true(status.next.begins_with("Click bed 1 and press Plant"), status.next)
	assert_equal(status.target_kind, NoticesScript.TARGET_BED, "an empty bed to plant")


func _uproot(sim: SimScript, bed: int) -> void:
	"""Leave `bed` empty whatever stood in it: a ripe crop harvested, a growing one blighted and cleared (the Clear
	verb's uprooting)."""
	if sim.stage_of(bed) == SimScript.STAGE_RIPE:
		sim.harvest(bed)
	elif sim.stage_of(bed) != SimScript.STAGE_EMPTY:
		sim.infect_for_test(bed)
		sim.clear(bed)


func test_every_farm_state_has_a_next_action() -> void:
	"""Whatever the six beds hold, the harvest card has a cause and a next action (REQ-SET-167)."""
	var world := _world()
	var status := StatusScript.Status.new()
	for hours: int in [0, 20, 60, 140, 300]:
		world.sim.advance_usec(CalendarScript.HOUR_USEC * hours)
		StatusScript.resolve_into(StepsScript.STEP_HARVEST, world, FactsScript.new(), status)
		assert_false(status.state.is_empty() or status.next.is_empty(), "after %d h: %s / %s" % [hours, status.state,
			status.next])


# --- 3: serve the first supper -----------------------------------------------------------------------

## A kitchen over real brains in a hand-made village (test_demo_kitchen.gd's proportions).
class Village extends RefCounted:
	var space: CastSpaceScript = CastSpaceScript.new()
	var brains: Array[BrainScript] = []
	var calendar: CalendarScript = CalendarScript.new()
	var pantry: PantryScript = PantryScript.new(StorageScript.new(Vector2(8.5, 0.5)))
	var stores: StoresScript = StoresScript.new()
	var kitchen: KitchenScript = KitchenScript.new()
	var places: PlacesScript = PlacesScript.new()


func _village(count: int, tick: int) -> Village:
	"""`count` mice at the square, the kitchen's places, the calendar at `tick`, the butt full."""
	var v := Village.new()
	v.space.setup([{"name": NightScript.HALL_POI, "position": Vector3(-2.0, 0.0, -7.0), "capacity": 4}] as Array[Dictionary],
		[] as Array[Vector3])
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var names := PackedStringArray()
	var kinds := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in count:
		var brain := BrainScript.new()
		brain.configure(v.space, 1.0, 0.25, 11 + i, lengths)
		brain.start_at(Vector2(-2.0 + 1.2 * float(i), 1.0), 0.0, -1, -1)
		v.space.tunnels.set_body(brain.index, 1024, 256)
		v.brains.append(brain)
		names.append("resident %d" % i)
		kinds.append("mouse")
		keys.append(&"mouse_keeper" if i == 0 else StringName("mouse_%d" % i))
	v.calendar.tick = tick
	v.stores.water_milli_u = StoresScript.WATER_CAP_MILLI_U
	v.places.set_points(Vector2(6.0, 0.0), Vector2(3.0, -3.0), Vector2(0.0, 4.0), Vector2(1.5, 4.5))
	v.places.add_table_seats(Vector2(3.0, -3.0), PlacesScript.SEATS_PER_TABLE)
	v.set_meta(&"who", [names, kinds, keys])
	return v


func _open(v: Village) -> void:
	"""The kitchen open over the village as stocked."""
	var who: Array = v.get_meta(&"who")
	v.kitchen.configure(v.brains, who[0], who[1], who[2], v.pantry, v.stores, v.calendar, v.places)


func _run_until(v: Village, world: WorldScript, facts: FactsScript, hour: int) -> void:
	"""Step the village a frame at a time until the calendar's hour of the day reaches `hour`, the facts looking on."""
	for f: int in 24 * FRAMES_PER_HOUR:
		if v.calendar.now().hour == hour:
			return
		v.calendar.tick += 1
		for brain: BrainScript in v.brains:
			brain.step(DT)
		v.kitchen.update()
		facts.observe(world)


func test_supper_counts_only_once_a_resident_has_eaten_it() -> void:
	"""Carrots in store at 14:00: the plan, the cooking, the call and the pot on the table do not complete it -- frame by
	frame, until the first supper portion is finished; then it is done, naming who ate first."""
	var v := _village(3, tick_at(1, 14))
	assert_true(v.pantry.add_into(CARROT, 12000, 0, _read), "carrots in store")
	_open(v)
	var world := WorldScript.new()
	world.kitchen = v.kitchen
	world.calendar = v.calendar
	world.name_of = func(i: int) -> String: return "resident %d" % i
	var facts := FactsScript.new()
	var early: int = 0
	for f: int in 6 * FRAMES_PER_HOUR:
		v.calendar.tick += 1
		for brain: BrainScript in v.brains:
			brain.step(DT)
		v.kitchen.update()
		facts.observe(world)
		if v.kitchen.portions_eaten == 0 and facts.supper_eaten:
			early += 1
		if v.kitchen.portions_eaten > 0:
			break
	assert_equal(early, 0, "never done before a portion was eaten")
	assert_true(v.kitchen.batches_cooked > 0 and v.kitchen.portions_eaten > 0, "supper cooked and eaten")
	assert_true(StepsScript.is_done(StepsScript.STEP_SUPPER, facts), "done once a portion was eaten")
	assert_true(facts.supper_line.begins_with("Supper, day 2 was eaten (resident "), facts.supper_line)
	assert_equal(facts.suppers_eaten, 1, "one supper eaten")
	assert_true(StatusScript.confirm_text(StepsScript.STEP_SUPPER, world, facts).ends_with("The village ate what it grew."),
		"the confirmation")


func test_a_portion_held_or_raw_food_is_not_a_supper_eaten() -> void:
	"""The record says how each resident's last meal went: a supper missed, or eaten raw, is not a supper served; a
	breakfast eaten is not supper; a cooked supper finished is."""
	var world := WorldScript.new()
	world.kitchen = KitchenScript.new()
	world.kitchen.fed.configure(PackedStringArray(["mouse", "mouse"]))
	var facts := FactsScript.new()
	var supper: int = Rules.meal_key(1, Rules.MEAL_SUPPER)
	world.kitchen.fed.missed(0, supper)
	world.kitchen.fed.ate_raw(1, supper, 800)
	facts.observe(world)
	assert_false(facts.supper_eaten, "missed and raw")
	world.kitchen.fed.ate_meal(0, Rules.meal_key(2, Rules.MEAL_BREAKFAST), Rules.DISH_PORRIDGE, 0)
	facts.observe(world)
	assert_false(facts.supper_eaten, "breakfast")
	world.kitchen.fed.ate_meal(1, Rules.meal_key(2, Rules.MEAL_SUPPER), Rules.DISH_SOUP, 0)
	facts.observe(world)
	assert_true(facts.supper_eaten, "a cooked supper finished")


func test_meals_are_still_seen_after_the_log_is_full() -> void:
	"""Forty days of tallies through the kitchen's own record (its log keeps the latest 64) and forty suppers eaten:
	every missed supper is still seen on day 40, and every supper eaten counted -- the log read by meal key, the
	eating by each resident's record."""
	var world := WorldScript.new()
	world.kitchen = KitchenScript.new()
	world.kitchen.fed.configure(PackedStringArray(["mouse"]))
	var facts := FactsScript.new()
	for day: int in 40:
		for meal: int in 2:
			world.kitchen.call(&"_record_meal", Rules.meal_key(day, meal), 1)
			facts.observe(world)
		world.kitchen.fed.ate_meal(0, Rules.meal_key(day, Rules.MEAL_SUPPER), Rules.DISH_SOUP, 0)
		facts.observe(world)
	assert_true(world.kitchen.meal_keys.size() <= KitchenScript.MAX_MEAL_LOG, "the log was trimmed")
	assert_equal(facts.supper_missed_day, 40, "the latest missed supper, day 40")
	assert_equal(facts.suppers_eaten, 40, "forty suppers eaten")


func test_breakfast_or_a_supper_nobody_ate_is_not_the_supper() -> void:
	"""Two residents and one batch of oats, from 02:00: breakfast is eaten (a different meal) and supper finds nothing to
	cook -- the card says so in the kitchen's words, and the missed supper is remembered with when the next is."""
	var v := _village(2, tick_at(1, 2))
	v.pantry.add_into(OATS, Rules.INPUT_MILLI[Rules.DISH_PORRIDGE], 0, _read)
	_open(v)
	var world := WorldScript.new()
	world.kitchen = v.kitchen
	world.calendar = v.calendar
	var facts := FactsScript.new()
	_run_until(v, world, facts, 20)
	assert_true(v.kitchen.portions_eaten > 0, "breakfast was eaten")
	assert_false(StepsScript.is_done(StepsScript.STEP_SUPPER, facts), "breakfast is not supper")
	assert_equal(facts.supper_missed_day, 2, "supper, day 2 was missed")
	var status := StatusScript.Status.new()
	StatusScript.resolve_into(StepsScript.STEP_SUPPER, world, facts, status)
	assert_true(status.state.begins_with("Can't now:") or status.state == Text.SUPPER_MISSED % 2, status.state)
	assert_false(status.next.is_empty(), "a next action")


# --- 4: ready the village for the frost --------------------------------------------------------------

func _bridges(open: bool) -> BridgesScript:
	"""A plank footbridge planned at the neck over the authored water, built when `open`."""
	if _map == null:
		_map = WaterLayout.make_map()
	var bridges := BridgesScript.new()
	bridges.configure(_map, [] as Array[Vector3], Rect2(-80.0, -80.0, 160.0, 160.0))
	var survey := BridgesScript.Survey.new()
	assert_true(bridges.survey_candidate_into(0, SwimRules.KIND_PLANK, survey), "the neck surveys")
	assert_true(bridges.plan_into(survey, "neck bridge", _read), "planned")
	while open and not bridges.is_open(_read.value):
		bridges.add_work(_read.value, 100)
	return bridges


func test_a_bridge_counts_once_built_and_walked_over() -> void:
	"""Planned (or being built) and walked onto: no. Open, a resident beside the deck, or swimming under it: no.
	Open and crossed over the middle of the deck: done, the bridge way."""
	var world := _world()
	world.bridges = _bridges(false)
	var middle: Vector2 = (world.bridges.deck_end(0, false) + world.bridges.deck_end(0, true)) * 0.5
	var walker := _brain(middle)
	walker.state = BrainScript.State.CROSS
	world.brains.append(walker)
	var facts := FactsScript.new()
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "a planned bridge is not crossed")
	world.bridges = _bridges(true)
	walker.state = BrainScript.State.WALK
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "standing there, not crossing")
	walker.state = BrainScript.State.CROSS
	walker.in_water = true
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "swimming under it")
	walker.in_water = false
	facts.observe(world)
	assert_true(facts.done_choice(FactsScript.CHOICE_BRIDGE), "crossed")
	assert_equal(facts.choice, FactsScript.CHOICE_BRIDGE, "the first way done")
	assert_true(StepsScript.is_done(StepsScript.STEP_SEASON, facts), "objective 4 done")


func test_a_tunnel_counts_once_walked_through_to_somewhere_else() -> void:
	"""Down and up at the same mouth (a dig crew, a home's door): no. Digging below, then up far away: no. Below at
	one place and up at another WALKED_THROUGH_M away, not digging: done, the tunnel way."""
	var world := _world()
	var walker := _brain(Vector2.ZERO)
	world.brains.append(walker)
	var facts := FactsScript.new()
	_go_below(facts, world, walker, Vector2(0.5, 0.0), false)
	assert_false(facts.done_choice(FactsScript.CHOICE_TUNNEL), "up where it went down")
	_go_below(facts, world, walker, Vector2(12.0, 0.0), true)
	assert_false(facts.done_choice(FactsScript.CHOICE_TUNNEL), "a digger coming up is not a walker")
	walker.order = BrainScript.ORDER_TASK
	walker.task = CrewTaskScript.new(null, null, 0, true, Vector2.ZERO, Callable(), Callable())
	_go_below(facts, world, walker, Vector2(-12.0, 0.0), false)
	assert_false(facts.done_choice(FactsScript.CHOICE_TUNNEL), "a dig crew's member coming up is not a walker")
	var network := GraphScript.new()
	walker.task = JobTaskScript.new(TunnelJobsScript.new(network, StoresScript.new()), network, 0)
	_go_below(facts, world, walker, Vector2(12.0, 0.0), false)
	assert_false(facts.done_choice(FactsScript.CHOICE_TUNNEL), "a tunnel job's worker is not a walker")
	walker.order = BrainScript.ORDER_NONE
	walker.task = null
	walker.position = Vector2.ZERO
	_go_below(facts, world, walker, Vector2(0.0, FactsScript.WALKED_THROUGH_M + 1.0), false)
	assert_true(facts.done_choice(FactsScript.CHOICE_TUNNEL), "walked through")


func _go_below(facts: FactsScript, world: WorldScript, walker: BrainScript, up_at: Vector2, digging: bool) -> void:
	"""`walker` goes below where it stands, walks (or digs) there, and comes up at `up_at`."""
	walker.underground = true
	walker.state = BrainScript.State.DIG if digging else BrainScript.State.TUNNEL
	facts.observe(world)
	walker.position = up_at
	facts.observe(world)
	walker.underground = false
	walker.state = BrainScript.State.WALK
	facts.observe(world)


func test_a_readied_field_counts_only_with_a_crop_standing() -> void:
	"""Covering an empty bed protects nothing: no. A bed with its crop raised: done, the field way."""
	var world := _world()
	var facts := FactsScript.new()
	assert_equal(world.sim.stage_of(0), SimScript.STAGE_EMPTY, "bed 1 opens empty")
	world.sim.cover(0)
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_FIELD), "an empty bed covered")
	world.sim.raise_bed(CARROT_BED)
	facts.observe(world)
	assert_true(facts.done_choice(FactsScript.CHOICE_FIELD), "the carrot bed raised")
	assert_equal(facts.field_how, "raised", "how")
	assert_true(StatusScript.confirm_text(StepsScript.STEP_SEASON, world, facts).contains("carrot bed is ready"),
		StatusScript.confirm_text(StepsScript.STEP_SEASON, world, facts))


func test_the_season_card_names_the_frost_and_all_three_ways() -> void:
	"""At the opening the frost is the night into spring 11; each way has a line; with no bridge site bound the bridge
	line still says what to do, so no way is a dead end."""
	var world := _world()
	var status := StatusScript.Status.new()
	StatusScript.resolve_into(StepsScript.STEP_SEASON, world, FactsScript.new(), status)
	assert_true(status.state.begins_with("Frost comes on the night into Spring 11"), status.state)
	assert_equal(status.choices.size(), 3, "three ways")
	for line: String in status.choices:
		assert_true(line.length() > 20, line)
	assert_equal(status.target_kind, NoticesScript.TARGET_BED, "the marker on a bed to ready")
	world.bridge_refusal = func(_kind: int) -> String: return "Can't build: it needs 4.7 U planks"
	StatusScript.resolve_into(StepsScript.STEP_SEASON, world, FactsScript.new(), status)
	assert_true(status.choices[0].contains("it needs 4.7 U planks"), "the bridge's own refusal: " + status.choices[0])


# --- progress: one at a time, already done, skip and reopen, pause, completion ------------------------

func _all_done(world: WorldScript, facts: FactsScript) -> void:
	"""Latch every objective's fact through the real models."""
	_selection = PackedInt32Array([0])
	world.brains.append(_brain(Vector2.ZERO))
	_deliver(world.pantry, CARROT, 3000)
	world.sim.raise_bed(CARROT_BED)
	facts.observe(world)
	facts.supper_eaten = true
	facts.revision += 1


func test_one_objective_at_a_time_in_order_with_its_confirmation() -> void:
	"""The first not done is current; done, it confirms for CONFIRM_S of unpaused time (a pause holds it), then the
	next. Paused for a long time, nothing moves."""
	var world := _world()
	world.brains.append(_brain(Vector2.ZERO))
	var facts := FactsScript.new()
	var steps := StepsScript.new()
	steps.update(facts, 0.1)
	assert_equal([steps.current, steps.phase], [StepsScript.STEP_MEET, StepsScript.PHASE_TRY], "teaching 1")
	_selection = PackedInt32Array([0])
	facts.observe(world)
	steps.update(facts, 0.1)
	assert_equal(steps.phase, StepsScript.PHASE_CONFIRM, "confirming 1")
	assert_false(steps.already, "done while it was current")
	steps.update(facts, 0.0)
	steps.update(facts, 0.0)
	assert_equal(steps.phase, StepsScript.PHASE_CONFIRM, "a pause counts nothing down")
	steps.update(facts, StepsScript.CONFIRM_S + 0.1)
	assert_equal([steps.current, steps.phase], [StepsScript.STEP_HARVEST, StepsScript.PHASE_TRY], "on to 2")
	for k: int in 50:
		steps.update(facts, 0.0)
	assert_equal(steps.current, StepsScript.STEP_HARVEST, "paused: still 2, nothing granted")


func test_an_objective_done_before_its_card_is_recognised() -> void:
	"""The harvest is shelved before the resident is met: when 2 comes up it confirms at once, 'Already done'."""
	var world := _world()
	world.brains.append(_brain(Vector2.ZERO))
	var facts := FactsScript.new()
	var steps := StepsScript.new()
	steps.update(facts, 0.1)
	_deliver(world.pantry, CARROT, 3000)
	facts.observe(world)
	steps.update(facts, 0.1)
	assert_equal(steps.current, StepsScript.STEP_MEET, "still 1: one at a time")
	_selection = PackedInt32Array([0])
	facts.observe(world)
	steps.update(facts, 0.1)
	steps.next()
	steps.update(facts, 0.1)
	assert_equal([steps.current, steps.phase], [StepsScript.STEP_HARVEST, StepsScript.PHASE_CONFIRM], "2 confirmed")
	assert_true(steps.already, "as already done")
	assert_equal(steps.confirm_left_s, StepsScript.ALREADY_S, "a short confirmation")


func test_skip_and_reopen_grant_and_lose_nothing() -> void:
	"""Hidden at 2: the pantry, the stores and the facts are unchanged by hiding and reopening; hidden, the guide keeps
	up with what happens (no confirmations); reopened, it lands on the first objective not done."""
	var world := _world()
	world.stores = StoresScript.new()
	world.brains.append(_brain(Vector2.ZERO))
	var facts := FactsScript.new()
	var steps := StepsScript.new()
	_selection = PackedInt32Array([0])
	facts.observe(world)
	steps.update(facts, 0.1)
	steps.next()
	var before: Array = [world.pantry.total_milli(), world.pantry.delivered_milli, world.stores.wood_milli_u,
		world.stores.plank_milli_u, facts.revision, steps.done_count(facts)]
	steps.hide_guide()
	steps.update(facts, 100.0)
	steps.reopen()
	steps.hide_guide()
	var after: Array = [world.pantry.total_milli(), world.pantry.delivered_milli, world.stores.wood_milli_u,
		world.stores.plank_milli_u, facts.revision, steps.done_count(facts)]
	assert_equal(after, before, "nothing granted or lost")
	assert_equal(steps.current, StepsScript.STEP_HARVEST, "still at 2")
	_deliver(world.pantry, CARROT, 3000)
	facts.observe(world)
	steps.update(facts, 0.1)
	assert_equal([steps.current, steps.phase], [StepsScript.STEP_SUPPER, StepsScript.PHASE_TRY], "hidden: passed 2")
	steps.reopen()
	steps.update(facts, 0.1)
	assert_false(steps.hidden, "shown")
	assert_equal(steps.current, StepsScript.STEP_SUPPER, "on the first not done")


func test_completion_is_announced_once() -> void:
	"""All four done and confirmed: complete, and the completion taken once."""
	var world := _world()
	var facts := FactsScript.new()
	var steps := StepsScript.new()
	_all_done(world, facts)
	for k: int in 12:
		steps.update(facts, StepsScript.CONFIRM_S + 1.0)
	assert_true(steps.is_complete(), "complete")
	assert_true(steps.take_completion(), "announced")
	assert_false(steps.take_completion(), "once")


func test_a_hidden_guide_completes_quietly_and_is_still_chronicled() -> void:
	"""Hidden from the start, every objective done: complete, with its completion to chronicle."""
	var world := _world()
	var facts := FactsScript.new()
	var steps := StepsScript.new()
	steps.hide_guide()
	_all_done(world, facts)
	steps.update(facts, 0.1)
	assert_true(steps.is_complete(), "complete while hidden")
	assert_true(steps.take_completion(), "and to chronicle")


func test_watching_an_unchanged_village_latches_nothing() -> void:
	"""Looked at again and again with nothing happening, the ledger stays as it was (no redraw asked for)."""
	var world := _world()
	world.brains.append(_brain(Vector2.ZERO))
	var facts := FactsScript.new()
	facts.observe(world)
	var revision: int = facts.revision
	for k: int in 5:
		facts.observe(world)
	assert_equal(facts.revision, revision, "nothing latched")
	assert_equal(facts.harvested_milli, 0, "no harvest")


func test_the_first_way_done_is_the_one_kept() -> void:
	"""A bed readied first, a bridge crossed after: objective 4 was done by the field way."""
	var world := _world()
	world.bridges = _bridges(true)
	var facts := FactsScript.new()
	world.sim.raise_bed(CARROT_BED)
	facts.observe(world)
	var middle: Vector2 = (world.bridges.deck_end(0, false) + world.bridges.deck_end(0, true)) * 0.5
	var walker := _brain(middle)
	walker.state = BrainScript.State.CROSS
	world.brains.append(walker)
	facts.observe(world)
	assert_true(facts.done_choice(FactsScript.CHOICE_BRIDGE), "the bridge was crossed too")
	assert_equal(facts.choice, FactsScript.CHOICE_FIELD, "the field way kept, the first done")


func test_stepping_onto_a_deck_is_not_yet_crossing() -> void:
	"""On its crossing leg but still at the deck's end (over the bank): not yet; over the water's middle: crossed."""
	var world := _world()
	world.bridges = _bridges(true)
	var a: Vector2 = world.bridges.deck_end(0, false)
	var b: Vector2 = world.bridges.deck_end(0, true)
	var walker := _brain(a.lerp(b, 0.05))
	walker.state = BrainScript.State.CROSS
	world.brains.append(walker)
	var facts := FactsScript.new()
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "at the deck's end")
	walker.position = a.lerp(b, 0.95)
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "at its other end")
	walker.position = a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * 3.0
	facts.observe(world)
	assert_false(facts.done_choice(FactsScript.CHOICE_BRIDGE), "beside the deck, off it")
	walker.position = a.lerp(b, 0.5)
	facts.observe(world)
	assert_true(facts.done_choice(FactsScript.CHOICE_BRIDGE), "over the middle")


func test_an_empty_pantry_says_the_kitchen_s_own_blocker() -> void:
	"""Nothing in store at 10:00: the supper card says why in the kitchen's words, and what to do."""
	var v := _village(3, tick_at(1, 10))
	_open(v)
	var world := WorldScript.new()
	world.kitchen = v.kitchen
	world.calendar = v.calendar
	var status := StatusScript.Status.new()
	StatusScript.resolve_into(StepsScript.STEP_SUPPER, world, FactsScript.new(), status)
	var d: KitchenScript.Decision = v.kitchen.decide_meal()
	assert_equal(d.code, KitchenScript.NO_FOOD, "the kitchen has no food")
	assert_equal(status.state, Text.SUPPER_CANT % d.reason, "its reason")
	assert_equal(status.next, Text.NEXT_SUPPER_FIX % d.fix, "its fix")


func test_a_partial_delivery_counts_what_was_shelved() -> void:
	"""A load bigger than the room left: the pantry's delivered total grows by what fitted, not the load."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(OATS, StorageScript.STORE_CAPACITY_U * 1000 - 2000, 0, _read)
	assert_true(pantry.store_upto_into(CARROT, 5000, 0, -1, _read), "a delivery")
	assert_equal(_read.value, 2000, "2.0 U fitted")
	assert_equal(pantry.delivered_milli, 2000, "and only that is counted")


func _owner(world: WorldScript, notices: NoticesScript, manager: GameManagerScript) -> GuideScript:
	"""The guide's owner over `world`, off-tree (no camera, no jump)."""
	var guide := GuideScript.new()
	guide.configure(world, notices, null, null, manager)
	return guide


func test_the_owner_counts_confirmations_in_unpaused_time_and_chronicles_once() -> void:
	"""The owner's frame: paused, a confirmation never runs out; running, it does; all four done and confirmed, the
	completion goes into the history once, under the Village source."""
	var manager := GameManagerScript.new()
	manager.start_game()
	var world := _world()
	var notices := NoticesScript.new()
	var guide := _owner(world, notices, manager)
	_all_done(world, guide.facts)
	assert_true(manager.pause_game(), "paused")
	for k: int in 50:
		guide._process(1.0)
	assert_equal(guide.steps.phase, StepsScript.PHASE_CONFIRM, "paused: the first confirmation holds")
	assert_equal(guide.steps.current, StepsScript.STEP_MEET, "on objective 1")
	manager.resume_game()
	for k: int in 12:
		guide._process(StepsScript.CONFIRM_S)
	assert_true(guide.steps.is_complete(), "running: complete")
	var village: int = 0
	for k: int in notices.count():
		village += 1 if notices.source(k) == NoticesScript.SOURCE_VILLAGE else 0
	assert_equal(village, 1, "chronicled once")
	guide._process(1.0)
	assert_equal(notices.count(), village, "and only once")
	guide.free()
	manager.free()


func test_hiding_the_finished_guide_card_hides_it() -> void:
	"""Complete and shown, the Show/Hide toggle hides the card (and shows it again)."""
	var manager := GameManagerScript.new()
	manager.start_game()
	var world := _world()
	var guide := _owner(world, NoticesScript.new(), manager)
	_all_done(world, guide.facts)
	for k: int in 12:
		guide._process(StepsScript.CONFIRM_S)
	assert_true(guide.steps.is_complete() and not guide.steps.hidden, "complete, shown")
	guide.toggle_guide()
	assert_true(guide.steps.hidden, "hidden")
	guide.toggle_guide()
	assert_false(guide.steps.hidden, "shown again")
	guide.free()
	manager.free()
