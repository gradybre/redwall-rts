extends "res://test/framework/test_case.gd"
## Tending policies with work budgets (review ECO-007, decision 0885; farm_tending.gd, farm_tending_page.gd): off at the
## start; each policy orders the bed panel's own job on a growing crop that wants it, within the group's daily budget;
## what it could not do is said once a day; Avoid waterlogging only moves a fitted outlet; the next day's most is
## shown; the budget comes back at midnight; the hourly run allocates nothing when there is nothing to do. The opening
## farm has three growing beds: the carrots (bed 3), the radish (bed 4) and the wheat (bed 6).

const TendingScript := preload("res://demo/farm/farm_tending.gd")
const TendingPage := preload("res://demo/farm/farm_tending_page.gd")
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
const Sluice := preload("res://demo/water/weir_sluice.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const FIELD: int = TendingScript.GROUP_FIELD
const GARDEN: int = TendingScript.GROUP_GARDEN
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_WHEAT: int = 5
const BED_LOAM: int = 0
## Spring 10, 12:00 -- the frost for the night into spring 11 is announced -- in hours from the opening 06:00.
const SPRING_10_NOON_H: int = 24 * 9 + 6

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


func _tending(sim: SimScript) -> TendingScript:
	"""Policies over `sim` with a crew on the placeholder cast; exceptions collected in `_said`."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	var crew := CrewScript.new()
	crew.configure(cast, sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast))), TunnelsScript.new(),
		DemoFarmScript.well_position(), func(_text: String) -> void: pass)
	var tending := TendingScript.new()
	tending.configure(sim, crew, func(text: String) -> void: _said.append(text))
	return tending


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func _job(tending: TendingScript, kind: int, bed: int) -> bool:
	"""Whether a job of `kind` is on `bed`'s board."""
	return tending._crew.jobs.job_on_bed_into(kind, bed, _read)


func test_everything_is_off_at_the_start() -> void:
	"""No policy on (the GDD's FieldPolicy default; the live village turns the field's sowing on), the default budget
	(16 WU), and an hour orders nothing even with a dry bed and empty beds in season."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	for group: int in TendingScript.GROUP_COUNT:
		for policy: int in TendingScript.POLICY_COUNT:
			assert_false(tending.is_on(group, policy), "%s: %s off" % [TendingScript.GROUP_NAMES[group],
				TendingScript.POLICY_NAMES[policy]])
		assert_equal(tending.budget_wu(group), 16, "the default budget: four sowings a day")
	_set_moisture(sim, BED_RADISH, 1000)
	tending.run_hour()
	assert_equal(tending._crew.jobs.live_count(), 0, "nothing ordered")


func test_water_below_the_band_orders_a_watering_within_the_budget() -> void:
	"""The radish (roots, 2500-7000) at 2000: watered (2 WU: fetch and tend); not twice; not a bed in its band."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_WATER, true)
	_set_moisture(sim, BED_RADISH, 2000)
	tending.run_hour()
	assert_true(_job(tending, JobsScript.KIND_WATER, BED_RADISH), "the radish watered")
	assert_false(_job(tending, JobsScript.KIND_WATER, BED_CARROTS), "the carrots are in their band")
	assert_equal(tending.spent_wu[FIELD], 2, "2 WU spent")
	tending.run_hour()
	assert_equal(tending.spent_wu[FIELD], 2, "not ordered twice")
	assert_true(_said.is_empty(), "nothing to say")
	assert_equal(TendingScript.job_wu(JobsScript.KIND_WATER), 2, "fetch 1 + tend 1")
	assert_equal(TendingScript.job_wu(JobsScript.KIND_COVER), 2, "cover 2")


func test_a_spent_budget_is_an_exception_said_once_and_refilled_at_midnight() -> void:
	"""A 4 WU budget and three dry beds: two watered, one left -- said once, kept on the page; at midnight the budget
	and the exceptions are fresh."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_WATER, true)
	tending.set_budget_step(FIELD, 1)
	assert_equal(tending.budget_wu(FIELD), 4, "4 WU")
	for bed: int in [BED_CARROTS, BED_RADISH, BED_WHEAT]:
		_set_moisture(sim, bed, 500)
	tending.run_hour()
	assert_equal(tending.spent_wu[FIELD], 4, "spent")
	assert_true(_job(tending, JobsScript.KIND_WATER, BED_CARROTS) and _job(tending, JobsScript.KIND_WATER, BED_RADISH),
		"the first two in bed order")
	assert_false(_job(tending, JobsScript.KIND_WATER, BED_WHEAT), "the wheat left")
	assert_equal(_said.size(), 1, "said once")
	assert_equal(_said[0], "Tending: Field beds: Bed 6 left dry — the day's tending budget (4 WU) is spent", "its words")
	tending.run_hour()
	assert_equal(_said.size(), 1, "not again today")
	assert_equal(tending.left_wu(FIELD), 0, "nothing left")
	sim.advance_usec(18 * HOUR_USEC)
	tending.run_hour()
	assert_equal(tending.exception_text[FIELD * TendingScript.POLICY_COUNT + TendingScript.POLICY_WATER], "", "a new day")
	assert_true(_job(tending, JobsScript.KIND_WATER, BED_WHEAT) or tending.spent_wu[FIELD] > 0, "the budget is back")


func _spring_crops(sim: SimScript) -> void:
	"""Spring 8, 06:00: the opening crops have ripened; radish sown in the loam bed 1 and peas in the clay beds 2 and 5
	(the windows: roots spring 1-8, beans spring 5-10), bed 5 raised with earth."""
	sim.advance_usec(24 * 7 * HOUR_USEC)
	for pair: Vector2i in [Vector2i(BED_LOAM, 0), Vector2i(1, 11), Vector2i(4, 11)]:
		sim.choose(pair.x, pair.y)
		assert_true(sim.sow_start(pair.x).ok and sim.sow_finish(pair.x).ok, "sown in bed %d" % (pair.x + 1))
	assert_true(sim.raise_bed(4).ok, "bed 5 raised")


func test_protect_from_frost_covers_growing_beds_not_raised() -> void:
	"""Spring 10 noon, the frost announced: the radish and the first peas covered; the raised peas, not; a ripe bed
	never; at 11:00, before the announcement, nothing."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_FROST, true)
	tending.set_budget_step(FIELD, 4)
	_spring_crops(sim)
	sim.advance_usec((SPRING_10_NOON_H - 24 * 7 - 1) * HOUR_USEC)
	tending.run_hour()
	assert_false(_job(tending, JobsScript.KIND_COVER, BED_LOAM), "11:00: not yet announced")
	sim.advance_usec(HOUR_USEC)
	tending.run_hour()
	assert_true(_job(tending, JobsScript.KIND_COVER, BED_LOAM), "the radish covered")
	assert_true(_job(tending, JobsScript.KIND_COVER, 1), "the peas covered")
	assert_false(_job(tending, JobsScript.KIND_COVER, 4), "the raised peas are warm enough")
	assert_false(_job(tending, JobsScript.KIND_COVER, BED_CARROTS), "a ripe bed is never covered")
	assert_equal(tending.spent_wu[FIELD], 4, "two covers, 2 WU each")
	assert_true(tending.frost_in_next_day(), "a frost night in the next day")


func test_avoid_waterlogging_opens_a_fitted_drain_and_says_the_rest() -> void:
	"""On growing crops only: a waterlogged bed with an outlet over a dry tunnel is set to Drain (no work); a Feed outlet
	on a wet bed is shut; a wet bed with no dry tunnel names its structural answers; an empty wet bed is left alone; a bed
	the leat waters names the sluice."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_WATERLOG, true)
	sim.set_tunnel_water(BED_RADISH, true, false)
	assert_true(sim.fit_outlet(BED_RADISH).ok, "an outlet fitted, shut")
	sim.set_tunnel_water(BED_WHEAT, false, true)
	assert_true(sim.fit_outlet(BED_WHEAT).ok and sim.set_outlet(BED_WHEAT, SimScript.OUTLET_FEED).ok, "a Feed outlet")
	for bed: int in [BED_RADISH, BED_WHEAT, BED_CARROTS, BED_LOAM]:
		_set_moisture(sim, bed, 9900)
	tending.run_hour()
	assert_equal(sim.outlet_of(BED_RADISH), SimScript.OUTLET_DRAIN, "opened to Drain")
	assert_equal(sim.outlet_of(BED_WHEAT), SimScript.OUTLET_SHUT, "the feed shut")
	assert_equal(tending.spent_wu[FIELD], 0, "boards moved: no work")
	assert_equal(_said.size(), 1, "the rest said")
	assert_true(_said[0].contains("Bed 3 and Bed 6 too wet with no dry tunnel to drain into"), _said[0])
	assert_false(_said[0].contains("Bed 1"), "an empty bed is not the policy's")
	var leat := SimScript.new()
	var by_leat := _tending(leat)
	by_leat.set_policy(FIELD, TendingScript.POLICY_WATERLOG, true)
	leat.set_leat_service(BED_RADISH, Sluice.SERVICE_WET)
	_set_moisture(leat, BED_RADISH, 9900)
	by_leat.run_hour()
	assert_true(_said[1].contains("turn the weir's sluice down"), "the leat's bed names the sluice: %s" % _said[1])


func test_the_next_day_s_most_is_shown_before_anything_is_spent() -> void:
	"""Water on, three growing beds: 6 WU and 0.75 U of well water within the 16 WU budget; frost on with a frost due adds
	6 WU, capped at a smaller budget; the line says so."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	assert_equal(tending.tomorrow_wu(FIELD), 0, "nothing on, nothing spent")
	tending.set_policy(FIELD, TendingScript.POLICY_WATER, true)
	assert_equal(tending.growing_beds(FIELD), 3, "three growing")
	assert_equal(tending.tomorrow_wu(FIELD), 6, "three waterings")
	assert_equal(tending.tomorrow_water_milli(FIELD), 750, "0.25 U each")
	assert_equal(tending.tomorrow_text(FIELD),
		"In the next day: at most 6 WU of work and 3 cups of water from the well (budget 16 WU a day; 0 WU used today)",
		"said: 0.75 U of water is 3 cups (0.25 U each)")
	tending.set_policy(FIELD, TendingScript.POLICY_FROST, true)
	_spring_crops(sim)
	sim.advance_usec((SPRING_10_NOON_H - 24 * 7) * HOUR_USEC)
	assert_equal(tending.growing_beds(FIELD), 3, "three sown beds growing")
	assert_equal(tending.tomorrow_wu(FIELD), 12, "6 + 6 WU within 16")
	tending.set_budget_step(FIELD, 2)
	assert_equal(tending.tomorrow_wu(FIELD), 8, "capped at an 8 WU budget")
	assert_equal(tending.tomorrow_wu(GARDEN), 0, "no garden bed grows")


func test_groups_and_words() -> void:
	"""A bed's group; names of beds in a sentence; settings out of range ignored."""
	assert_equal(TendingScript.group_of(0), FIELD, "a field bed")
	assert_equal(TendingScript.group_of(Catalog.GARDEN_FIRST), GARDEN, "a garden site")
	assert_equal(TendingScript.group_of(Catalog.BED_COUNT), TendingScript.NO_GROUP, "no bed")
	assert_equal(TendingScript.beds_words(PackedInt32Array([1])), "Bed 2", "one")
	assert_equal(TendingScript.beds_words(PackedInt32Array([1, 3, 6])), "Bed 2, Bed 4 and Bed 7", "three")
	var tending := TendingScript.new()
	tending.set_policy(5, 0, true)
	tending.set_policy(0, 9, true)
	tending.set_budget_step(0, 99)
	assert_equal(tending.budget_step[0], TendingScript.BUDGET_STEPS.size() - 1, "clamped to the top step")
	tending.set_budget_step(7, 0)
	assert_equal(tending.policy_on.count(1), 0, "nothing turned on out of range")


func test_an_idle_hour_allocates_nothing() -> void:
	"""Every policy on and nothing wanted: fifty hourly runs keep the object count."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	for group: int in TendingScript.GROUP_COUNT:
		for policy: int in TendingScript.POLICY_COUNT:
			tending.set_policy(group, policy, true)
	tending.run_hour()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 50:
		tending.run_hour()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object made")


func test_the_tending_tab_sets_and_shows_the_policies() -> void:
	"""A policy's toggle and a budget step act; the next-day line and today's exceptions show."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	var page := TendingPage.new()
	_nodes.append(page)
	page.bind(tending)
	page.policy_button(FIELD, TendingScript.POLICY_WATER).pressed.emit()
	assert_true(tending.is_on(FIELD, TendingScript.POLICY_WATER), "on")
	assert_true(page.policy_button(FIELD, TendingScript.POLICY_WATER).button_pressed, "shown pressed")
	page.budget_button(FIELD, 1).pressed.emit()
	assert_equal(tending.budget_wu(FIELD), 4, "4 WU")
	assert_true(page.tomorrow_line(FIELD).contains("at most 4 WU"), page.tomorrow_line(FIELD))
	for bed: int in [BED_CARROTS, BED_RADISH, BED_WHEAT]:
		_set_moisture(sim, bed, 500)
	tending.run_hour()
	page.refresh()
	assert_true(page.exceptions_line(FIELD).begins_with("Today: Field beds: Bed 6 left dry"), page.exceptions_line(FIELD))
	assert_equal(page.exceptions_line(GARDEN), "", "the garden has none")


func test_water_skips_a_bed_tended_today() -> void:
	"""§5.6's tending is once a day: a dry radish already watered today is not ordered again."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_WATER, true)
	_set_moisture(sim, BED_RADISH, 500)
	assert_true(sim.water(BED_RADISH).ok, "watered by hand")
	assert_true(sim.band_of(BED_RADISH) <= SimScript.BAND_LOW, "still below its band")
	tending.run_hour()
	assert_false(_job(tending, JobsScript.KIND_WATER, BED_RADISH), "not again today")


func test_a_refused_order_is_said() -> void:
	"""With the farm's board full, a policy's watering is refused: the bed is said with the order's answer."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_WATER, true)
	_fill_board(tending)
	_set_moisture(sim, BED_RADISH, 500)
	tending.run_hour()
	assert_false(_job(tending, JobsScript.KIND_WATER, BED_RADISH), "no job")
	assert_equal(tending.spent_wu[FIELD], 0, "nothing spent")
	assert_true(_said.size() == 1 and _said[0].contains("Bed 4 left dry — Can't water: the farm's job board is full"),
		str(_said))


func _fill_board(tending: TendingScript) -> void:
	"""Fill the farm's job board with composts on every bed that takes one, then harvests on any bed (opened directly)."""
	var jobs: JobsScript = tending._crew.jobs
	for kind: int in [JobsScript.KIND_COMPOST, JobsScript.KIND_COVER, JobsScript.KIND_RAISE]:
		for bed: int in Catalog.FIELD_BED_COUNT:
			if jobs.live_count() < JobsScript.MAX_JOBS:
				jobs.open_into(kind, bed, JobsScript.ORIGIN_PLAYER, _read)
	assert_equal(jobs.live_count(), JobsScript.MAX_JOBS, "the board is full")
