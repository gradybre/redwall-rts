extends "res://test/framework/test_case.gd"
## Harvest plans for the hands available (review ECO-003, decision 0882; farm_harvest_plan.gd, farm_harvest_page.gd):
## each strategy's sowing days inside the windows, the projection's ripening and food, each harvest day's work against
## the field crew, its food against the room and the kitchen, the suggestion for an overloaded day, and booking -- now,
## later, dropped, waiting. Nine residents (the placeholder village); the GDD's numbers: roots 120 h and 240 h shelf,
## soup roots 3 U a 2-portion batch, porridge grain 2 U, §5.8 covered store 1000 and summer 1500.

const PlanScript := preload("res://demo/farm/farm_harvest_plan.gd")
const PageScript := preload("res://demo/farm/farm_harvest_page.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HOUR_USEC: int = CalendarScript.HOUR_USEC
const RESIDENTS: int = 9
const RADISH: int = 0
const LETTUCE: int = 7
const WHEAT: int = 13
const BED_LOAM: int = 0
const BED_CARROTS: int = 2
const SITE_1: int = Catalog.GARDEN_FIRST
const SITE_2: int = Catalog.GARDEN_FIRST + 1
const SITE_3: int = Catalog.GARDEN_FIRST + 2

var _nodes: Array[Node] = []
var _said: PackedStringArray = PackedStringArray()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_said.clear()


func _plan(sim: SimScript) -> PlanScript:
	"""A plan over `sim` with a crew of two (the placeholder village's first two) and a covered store only."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	var pantry := PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast)))
	var crew := CrewScript.new()
	crew.configure(cast, sim, pantry, TunnelsScript.new(), DemoFarmScript.well_position(), func(_text: String) -> void: pass)
	crew.set_crew(PackedInt32Array([0, 1]))
	var plan := PlanScript.new()
	plan.configure(sim, crew, pantry, func() -> int: return RESIDENTS, func(text: String) -> void: _said.append(text))
	return plan


func _choose(sim: SimScript, beds: Array[int], item: int) -> void:
	"""Lay out any garden site among `beds` and choose `item` for each."""
	for bed: int in beds:
		if Catalog.is_garden(bed):
			sim.lay_out(bed)
		assert_true(sim.choose(bed, item).ok, "chosen in bed %d" % (bed + 1))


func test_the_rows_show_each_laid_bed_as_it_stands() -> void:
	"""Standing crops ripen when the bed panel says; an empty bed with no crop says so; a resting one too; a bare site
	is no row."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	sim.set_fallow(4, true)
	var rows: Array[PlanScript.Row] = plan.rows()
	assert_equal(rows.size(), Catalog.FIELD_BED_COUNT, "the twelve field beds (no garden site is laid out)")
	assert_equal(rows[BED_CARROTS].state, PlanScript.ROW_STANDING, "the carrots stand")
	assert_equal(rows[BED_CARROTS].ripe_day, 2, "the carrots (96 of 120 h grown) ripen on spring 2")
	assert_true(rows[BED_CARROTS].milli > 0, "with a harvest")
	assert_equal(rows[BED_LOAM].state, PlanScript.ROW_NO_CROP, "bed 1: no crop chosen")
	assert_equal(rows[4].state, PlanScript.ROW_RESTING, "bed 5 resting")
	assert_equal(PlanScript.ripen_days(RADISH), 5, "roots: 120 h")
	assert_equal(PlanScript.ripen_days(WHEAT), 8, "grain: 192 h")
	assert_equal(PlanScript.ripen_days(11), 6, "beans: 144 h")


func test_steady_spreads_a_crop_s_beds_and_preserving_sows_them_together() -> void:
	"""Three radish beds on spring 1: steady sows them a day apart (5 days shared by 3, at least 1); preserving, all on
	spring 1, ripening together on spring 6."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	_choose(sim, [BED_LOAM, SITE_1, SITE_2] as Array[int], RADISH)
	var steady: PackedInt32Array = plan.sow_days()
	assert_equal([steady[BED_LOAM], steady[SITE_1], steady[SITE_2]], [1, 2, 3], "a day apart")
	plan.set_strategy(PlanScript.STRATEGY_PRESERVE)
	var together: PackedInt32Array = plan.sow_days()
	assert_equal([together[BED_LOAM], together[SITE_1], together[SITE_2]], [1, 1, 1], "together")
	var days: Array[PlanScript.Day] = plan.days()
	var last: PlanScript.Day = days[days.size() - 1]
	assert_equal(last.day, 6, "ripe on spring 6")
	for bed: int in [BED_LOAM, SITE_1, SITE_2]:
		assert_true(last.beds.has(bed), "bed %d ripens that day" % (bed + 1))
	assert_equal(last.work_usec, last.beds.size() * PlanScript.harvest_usec(), "a harvest's work a bed (the wheat too)")
	assert_equal(plan.day_text(6), "Spring 6", "named as the HUD does")


func test_a_window_closing_holds_the_days_inside_it() -> void:
	"""On spring 7, three radish beds steady: spring 7, 8, then spring 8 again (roots sow until spring 8); custom later
	stops there too; earlier never goes before today."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	sim.advance_usec(24 * 6 * HOUR_USEC)
	_choose(sim, [BED_LOAM, SITE_1, SITE_2] as Array[int], RADISH)
	var days: PackedInt32Array = plan.sow_days()
	assert_equal([days[BED_LOAM], days[SITE_1], days[SITE_2]], [7, 8, 8], "held inside the window")
	assert_equal(plan.shift(BED_LOAM, 5), "Bed 1: sown Spring 8", "later: to the window's last day")
	assert_equal(plan.strategy, PlanScript.STRATEGY_CUSTOM, "now custom")
	assert_equal(plan.shift(BED_LOAM, -9), "Bed 1: sown Spring 7", "earlier: never before today")
	assert_true(plan.shift(BED_CARROTS, 1).begins_with("Bed 3 has no planned sowing"), "a standing crop is not planned")


func test_the_kitchen_s_use_and_the_keeping() -> void:
	"""Nine mouths: 5 batches a meal -- roots 15 U a day (the soup's 3 U), grain 10 U (porridge's 2 U), lettuce none.
	Roots keep 10 days in the covered store in spring, 6 in summer (×1.5)."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	assert_equal(plan.daily_use_milli(FarmingScript.CROP_ROOTS), 15000, "roots")
	assert_equal(plan.daily_use_milli(FarmingScript.CROP_GRAIN), 10000, "grain")
	assert_equal(plan.daily_use_milli(FarmingScript.CROP_CABBAGE), 0, "no dish takes the leaf row")
	assert_equal(plan.keep_days(FarmingScript.CROP_ROOTS, 1), 10, "240 h in spring")
	assert_equal(plan.keep_days(FarmingScript.CROP_ROOTS, 13), 6, "160 h in summer")
	assert_equal(plan.eaten_before_spoiling_milli(FarmingScript.CROP_ROOTS, 1), 150000, "150 U eaten before it spoils")
	assert_equal(plan.hands(), 2, "the field crew's two")
	assert_equal(plan.hands_usec(), 2 * 10 * HOUR_USEC, "ten work hours each")
	assert_equal(plan.room_milli(), StorageScript.STORE_CAPACITY_U * 1000, "the covered store's room")


func test_an_overloaded_day_is_said_with_a_later_sowing() -> void:
	"""Lettuce, which no dish takes, in three garden beds on summer 5 together: spoiling before it is eaten -- the last
	bed sown later is suggested; steady spreads it but each day still risks spoiling."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	sim.advance_usec((24 * 16) * HOUR_USEC)
	_choose(sim, [SITE_1, SITE_2, SITE_3] as Array[int], LETTUCE)
	plan.set_strategy(PlanScript.STRATEGY_PRESERVE)
	var days: Array[PlanScript.Day] = plan.days()
	var day: PlanScript.Day = days[0]
	assert_equal(day.beds.size(), 3, "together")
	assert_true(day.over & PlanScript.OVER_KEEPING, "at risk of spoiling")
	assert_equal(day.at_risk_milli, day.milli, "all of it: no dish takes lettuce")
	assert_false(day.over & PlanScript.OVER_WORK, "two hands do three harvests easily")
	assert_true(plan.over_words(day).contains("would spoil before the kitchen eats it"), plan.over_words(day))
	assert_true(plan.suggestion(day).begins_with("Sow Bed 15 on"), plan.suggestion(day))
	var easy := PlanScript.Day.new()
	assert_equal(plan.suggestion(easy), "", "an easy day has none")
	assert_equal(plan.over_words(easy), "", "nor words")


func test_booking_orders_today_and_books_the_rest() -> void:
	"""Steady, three radish beds: bed 1's sowing is ordered now; the two sites are booked for spring 2 and 3, and
	ordered when their day comes; the bookings are said in the rows."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	_choose(sim, [BED_LOAM, SITE_1, SITE_2] as Array[int], RADISH)
	var said: String = plan.book()
	assert_equal(said, "Booked: sowing now on Bed 1; Bed 13 on Spring 2, Bed 14 on Spring 3", "one order")
	assert_true(plan._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "bed 1 ordered now")
	assert_false(plan._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "the site waits")
	assert_equal(plan.booking_text(SITE_1), "booked: radish on Spring 2", "in words")
	sim.advance_usec(18 * HOUR_USEC)
	plan.run_hour()
	assert_true(plan._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "spring 2: ordered")
	assert_equal(plan.booking_text(SITE_1), "", "the booking done")
	assert_equal(plan.booked_day[SITE_2], 3, "the other still booked")


func test_a_changed_crop_drops_its_booking_and_a_missed_window_waits() -> void:
	"""A booked bed whose crop the player changes is dropped, said once; one whose day comes outside its window waits,
	warned once, and is not sown with another crop."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	_choose(sim, [BED_LOAM, SITE_1] as Array[int], RADISH)
	plan.set_strategy(PlanScript.STRATEGY_CUSTOM)
	plan.shift(SITE_1, 2)
	plan.book()
	sim.choose(SITE_1, WHEAT)
	sim.advance_usec(18 * HOUR_USEC + 24 * 2 * HOUR_USEC)
	plan.run_hour()
	assert_true(_said.has("Bed 13's booked sowing is dropped: its crop was changed"), "dropped: %s" % _said)
	assert_equal(plan.booked_day[SITE_1], PlanScript.NO_DAY, "forgotten")
	sim.choose(SITE_1, RADISH)
	plan.booked_day[SITE_1] = 3
	plan.booked_item[SITE_1] = RADISH
	sim.set_fallow(SITE_1, true)
	plan.run_hour()
	plan.run_hour()
	var waits: int = 0
	for line: String in _said:
		waits += 1 if line.begins_with("Bed 13's booked radish waits") else 0
	assert_equal(waits, 1, "said once")
	assert_equal(plan.booked_day[SITE_1], 3, "still booked")
	assert_false(plan._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "not sown")


func test_an_hour_with_no_booking_allocates_nothing() -> void:
	"""Fifty hourly runs with nothing booked keep the object count."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	plan.run_hour()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 50:
		plan.run_hour()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object made")


func test_the_harvest_tab_shows_the_plan_and_books_it() -> void:
	"""The strategy pressed, a row a laid bed, a row a harvest day, a picked bed moved later, and Book this plan."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	var page := PageScript.new()
	_nodes.append(page)
	page.bind(plan)
	assert_true(page.strategy_button(PlanScript.STRATEGY_STEADY).button_pressed, "steady at first")
	assert_equal(page.bed_table().shown_rows(), Catalog.FIELD_BED_COUNT, "the twelve field beds")
	_choose(sim, [BED_LOAM] as Array[int], RADISH)
	page.refresh()
	assert_equal(page.bed_table().row_texts(BED_LOAM)[1], "Radish (keeping root)", "its crop and role")
	assert_equal(page.bed_table().row_texts(BED_LOAM)[2], "Spring 1", "sown today")
	assert_true(page.day_table().shown_rows() >= 1, "harvest days listed")
	page.pick_bed(BED_LOAM)
	assert_equal(page.shift(1), "Bed 1: sown Spring 2", "later by a day")
	assert_equal(page.bed_table().row_texts(BED_LOAM)[2], "Spring 2", "shown")
	assert_true(page.strategy_button(PlanScript.STRATEGY_CUSTOM).button_pressed, "now custom")
	assert_equal(page.book(), "Booked: Bed 1 on Spring 2", "booked")
	assert_equal(page.bed_table().row_texts(BED_LOAM)[5], "booked: radish on Spring 2", "its booking shown")
	page.set_strategy(PlanScript.STRATEGY_PRESERVE)
	assert_equal(plan.strategy, PlanScript.STRATEGY_PRESERVE, "set")


func test_keeping_reads_the_slowest_store_and_a_bare_site_is_never_planned() -> void:
	"""With a cellar-cool store (350) beside the covered store, roots keep 28 days in spring (240 h × 1000 / 350); a bare
	garden site with a crop chosen is no plan."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	plan._pantry.storage.add_provider(func() -> Array: return [{StorageScript.KEY_ID: &"cool", StorageScript.KEY_POSITION:
		Vector2.ZERO, StorageScript.KEY_CAPACITY_U: 10, StorageScript.KEY_PERMILLE: 350}])
	assert_equal(plan.keep_days(FarmingScript.CROP_ROOTS, 1), 28, "the slowest store's keeping")
	sim.choose(SITE_3, RADISH)
	assert_equal(plan.sow_days()[SITE_3], PlanScript.NO_DAY, "a bare site is not planned")


func test_a_day_over_the_stores_room_is_said() -> void:
	"""The covered store full: any harvest day is over the room, in clay words."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	assert_true(plan._pantry.add_into(WHEAT, StorageScript.STORE_CAPACITY_U * 1000, 0, _read), "the store filled")
	assert_equal(plan.room_milli(), 0, "no room")
	var days: Array[PlanScript.Day] = plan.days()
	assert_true(days[0].over & PlanScript.OVER_ROOM, "over the room")
	assert_true(plan.over_words(days[0]).contains("more than the stores' free room"), plan.over_words(days[0]))


func test_a_booking_refused_by_a_full_board_stays_booked() -> void:
	"""The farm's board full on the booked day: the order is refused, the booking stays, said once; room on the board,
	the next hour orders it."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	_choose(sim, [BED_LOAM] as Array[int], RADISH)
	plan.shift(BED_LOAM, 1)
	plan.book()
	var jobs: JobsScript = plan._crew.jobs
	for bed: int in Catalog.FIELD_BED_COUNT:
		for kind: int in [JobsScript.KIND_COMPOST, JobsScript.KIND_RAISE]:
			if jobs.live_count() < JobsScript.MAX_JOBS:
				jobs.open_into(kind, bed, JobsScript.ORIGIN_PLAYER, _read)
	sim.advance_usec(18 * HOUR_USEC)
	plan.run_hour()
	plan.run_hour()
	assert_equal(plan.booked_day[BED_LOAM], 2, "still booked")
	assert_equal(_said, PackedStringArray(["Bed 1's booked radish waits: Can't sow: the farm's job board is full"]),
		"said once")
	jobs.close(0)
	plan.run_hour()
	assert_true(jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "ordered once there is room")
	assert_equal(plan.booked_day[BED_LOAM], PlanScript.NO_DAY, "the booking done")


func test_shifting_with_no_sowing_day_ahead_is_refused() -> void:
	"""Summer 5: radish's windows have closed for the season; Earlier and Later say so and change nothing."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	sim.advance_usec(24 * 16 * HOUR_USEC)
	_choose(sim, [BED_LOAM] as Array[int], RADISH)
	assert_equal(plan.shift(BED_LOAM, 1), "Bed 1: radish has no sowing day this season ahead (sow in Spring 1–8; Summer 1–4)",
		"refused")
	assert_equal(plan.strategy, PlanScript.STRATEGY_STEADY, "nothing changed")


func test_a_booking_on_a_bed_taken_up_is_dropped() -> void:
	"""A garden bed booked for spring 2 and taken up before: on spring 2 the booking is dropped, said so."""
	var sim := SimScript.new()
	var plan := _plan(sim)
	_choose(sim, [SITE_1] as Array[int], RADISH)
	plan.shift(SITE_1, 1)
	assert_equal(plan.book(), "Booked: Bed 13 on Spring 2", "booked")
	assert_true(sim.take_up(SITE_1).ok, "taken up")
	sim.advance_usec(18 * HOUR_USEC)
	plan.run_hour()
	assert_true(_said.has("Bed 13's booked sowing is dropped: the bed was taken up"), str(_said))
	assert_equal(plan.booked_day[SITE_1], PlanScript.NO_DAY, "forgotten")
