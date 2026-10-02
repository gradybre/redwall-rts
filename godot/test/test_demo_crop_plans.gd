extends "res://test/framework/test_case.gd"
## The crop plans in the live farm (decisions 0881-0885; demo_farm.gd THE CROP PLANS): the farm hour runs the tending
## policies and the bookings, a bed panel fits and sets a tunnel outlet through the crew, the routine crew leaves the
## kitchen garden's jobs to the cook between meals, the work board's farm source says why, and the planner has its
## three new tabs. The placeholder village, off-tree, stepped at 60 Hz.

const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const TendingScript := preload("res://demo/farm/farm_tending.gd")
const PlannerScript := preload("res://demo/farm/farm_planner.gd")
const FarmWorkScript := preload("res://demo/work/farm_work.gd")
const GardenScript := preload("res://demo/farm/farm_garden.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const BED_LOAM: int = 0
const BED_RADISH: int = 3
const SITE_1: int = Catalog.GARDEN_FIRST
const RADISH: int = 0
const WHEAT: int = 13
const COOK: int = 1
const OTHER: int = 0

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _services: ServicesScript = ServicesScript.new()


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _farm() -> DemoFarmScript:
	"""The farm over the placeholder village, off-tree, with a command layer and no HUD."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null, _services)
	var farm := DemoFarmScript.new()
	_nodes.append(farm)
	var providers: Array[Callable] = []
	farm.configure({}, null, cast, command, camera, null, providers, _services)
	return farm


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func _run(farm: DemoFarmScript, seconds: float, done: Callable) -> bool:
	"""Step the cast and the farm's crew at 60 Hz until `done()` or `seconds` of demo time pass."""
	for frame: int in roundi(seconds / DT):
		farm._cast.advance(DT)
		farm.crew.update(farm._cast.clock.frame_usec)
		if done.call():
			return true
	return false


func test_the_farm_hour_runs_the_tending_policies() -> void:
	"""With Water on, a farm hour orders the dry radish's watering, as the policy says (no one pressed Water)."""
	var farm := _farm()
	farm.tending.set_policy(TendingScript.GROUP_FIELD, TendingScript.POLICY_WATER, true)
	_set_moisture(farm.sim, BED_RADISH, 1500)
	farm.advance_calendar(HOUR_USEC)
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_WATER, BED_RADISH, _read), "watering ordered")
	assert_equal(farm.crew.jobs.origin[_read.value], JobsScript.ORIGIN_ROUTINE, "by the policy, not the player")


func test_the_farm_hour_orders_a_booked_sowing_on_its_day() -> void:
	"""A radish booked in bed 1 for spring 2 (custom): ordered on spring 2's first farm hour."""
	var farm := _farm()
	farm.sim.choose(BED_LOAM, RADISH)
	farm.harvest_plan.shift(BED_LOAM, 1)
	assert_equal(farm.harvest_plan.book(), "Booked: Bed 1 on Spring 2", "booked")
	farm.advance_calendar(17 * HOUR_USEC)
	assert_false(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "spring 1: not yet")
	farm.advance_calendar(HOUR_USEC)
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "spring 2: ordered")


func test_an_outlet_is_fitted_by_the_crew_and_set_from_the_panel() -> void:
	"""A dry tunnel under bed 1: the panel's outlet box offers Fit outlet; the order goes to the field crew, who fits it
	(6 WU at the bed); then Drain from the box drains the bed, said on the panel."""
	var farm := _farm()
	farm.crew.set_crew(PackedInt32Array([OTHER]))
	farm.sim.set_tunnel_water(BED_LOAM, true, false)
	farm.select_bed(BED_LOAM)
	var box: Variant = farm.bed_panel.outlet_box()
	assert_true(box.visible and box.fit_button().visible, "Fit outlet offered")
	assert_false(box.fit_button().disabled, "its card allows it")
	box.fit_button().pressed.emit()
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_FIT_OUTLET, BED_LOAM, _read), "on the board")
	assert_true(_run(farm, 90.0, func() -> bool: return farm.sim.has_outlet(BED_LOAM)), "fitted by the crew")
	box.setting_button(SimScript.OUTLET_DRAIN).pressed.emit()
	assert_equal(farm.sim.outlet_of(BED_LOAM), SimScript.OUTLET_DRAIN, "set to drain")
	assert_true(farm.sim.is_drained(BED_LOAM), "draining")
	assert_true(farm.bed_panel.shown_texts().has("Bed 1's outlet: drain"), "said on the panel")
	assert_equal(farm.set_outlet(SimScript.OUTLET_DRAIN), "Can't set the outlet: it is set so already",
		"the same setting refused in words")


func test_the_routine_crew_leaves_a_garden_job_to_the_cook_between_meals() -> void:
	"""09:00, the cook (placeholder 1) idle: a garden sowing on the board is not handed to the routine crew (placeholder
	0); the work board's farm source says why; with the garden hours off, it is handed out."""
	var farm := _farm()
	farm.garden.bind_cook(func() -> int: return COOK)
	farm.crew.set_crew(PackedInt32Array([OTHER]))
	farm.select_bed(SITE_1)
	farm.lay_out_garden_bed()
	farm.sim.choose(SITE_1, RADISH)
	farm.advance_calendar(3 * HOUR_USEC)
	farm.crew.order(JobsScript.KIND_SOW, SITE_1, PackedInt32Array(), JobsScript.ORIGIN_PLAYER)
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "on the board")
	var row: int = _read.value
	_run(farm, 1.0, func() -> bool: return false)
	assert_equal(farm.crew.jobs.worker[row], JobsScript.NOBODY, "not handed to the routine crew")
	var source := FarmWorkScript.new(farm.crew)
	assert_equal(source.eligibility(row, OTHER), GardenScript.KEPT_WORDS, "the board's reason")
	assert_equal(source.eligibility(row, COOK), "", "the cook may take it")
	farm.garden.set_cook_tends(false)
	_run(farm, 1.0, func() -> bool: return false)
	assert_equal(farm.crew.jobs.worker[row], OTHER, "the garden hours off: handed out")


func test_the_planner_has_the_three_new_tabs() -> void:
	"""Harvest plan, Kitchen garden and Tending after the four; each shows its own page."""
	var farm := _farm()
	var planner: PlannerScript = farm.planner
	assert_equal(PlannerScript.TAB_NAMES.size(), 7, "seven tabs")
	planner.toggle()
	for tab: int in [PlannerScript.TAB_HARVEST, PlannerScript.TAB_GARDEN, PlannerScript.TAB_TENDING]:
		planner.tab_button(tab).pressed.emit()
		assert_equal(planner.view, tab, "%s shown" % PlannerScript.TAB_NAMES[tab])
	assert_true(planner.tending_page().visible, "the tending page")
	assert_false(planner.harvest_page().visible, "the others hidden")
	planner.show_tab(99)
	assert_equal(planner.view, PlannerScript.TAB_TENDING, "clamped to the last")


func test_a_right_click_on_a_bare_site_says_to_lay_it_out() -> void:
	"""Nothing pressing on a bare garden site: lay out a bed there first; on a field bed: choose a crop."""
	var farm := _farm()
	assert_equal(farm.nothing_to_do_text(SITE_1), "Nothing grows on garden site 1 yet — lay out a bed there first (its panel)",
		"a bare site")
	assert_equal(farm.nothing_to_do_text(BED_LOAM), "Nothing to do on bed 1 now — choose a crop with Plant…", "a field bed")
	assert_false(farm.pressing_kind_into(SITE_1, _read), "and nothing is pressing there")


func test_the_soil_plans_offer_a_garden_bed_only_once_laid() -> void:
	"""The Soil plans tab's bed buttons: the six field beds, and a garden bed once it is laid out."""
	var farm := _farm()
	var planner: PlannerScript = farm.planner
	planner.toggle()
	planner.show_tab(PlannerScript.TAB_PLANS)
	assert_true(planner._bed_buttons[0].visible, "bed 1")
	assert_false(planner._bed_buttons[SITE_1].visible, "a bare site: no button")
	farm.garden.lay_out(SITE_1)
	planner._plans_key[0] = -1
	planner.refresh()
	assert_true(planner._bed_buttons[SITE_1].visible, "laid out: its button")


func test_the_crew_reaches_every_south_field_tile_and_a_garden_bed() -> void:
	"""Each tile of the south field (and a laid garden bed) is sown by the routine crew walking there: none is boxed in."""
	var farm := _farm()
	farm.crew.set_crew(PackedInt32Array([OTHER]))
	farm.select_bed(SITE_1)
	farm.lay_out_garden_bed()
	var beds: Array[int] = [SITE_1]
	for k: int in Catalog.SOUTH_BEDS:
		beds.append(Catalog.SOUTH_FIRST + k)
	for bed: int in beds:
		farm.sim.choose(bed, WHEAT)
		farm.crew.order(JobsScript.KIND_SOW, bed, PackedInt32Array([OTHER]), JobsScript.ORIGIN_PLAYER)
		assert_true(_run(farm, 60.0, func() -> bool: return farm.sim.stage_of(bed) != SimScript.STAGE_EMPTY),
			"bed %d sown" % (bed + 1))
