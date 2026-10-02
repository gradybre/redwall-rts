extends "res://test/framework/test_case.gd"
## The sowing policy and the south field (Brendan's balance ruling E5, decision 0886; farm_sowing.gd, farm_tending.gd
## POLICY_SOW, farm_catalog.gd THE EAST FIELD, farm_rotation_box.gd): twelve field beds, laid from the start and clear of
## everything; each bed's rotation by its soil (GDD §5.6's default cycle where the soil allows); the cursor advancing
## once its crop has been in the bed (R06-JOB-005); the policy sowing empty beds in season within its budget, the
## player's choice first, a refused order putting the choice back, a wait said once.

const SowingScript := preload("res://demo/farm/farm_sowing.gd")
const TendingScript := preload("res://demo/farm/farm_tending.gd")
const RotationBox := preload("res://demo/farm/farm_rotation_box.gd")
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
const Layout := preload("res://demo/world/world_layout.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const FIELD: int = TendingScript.GROUP_FIELD
const RADISH: int = 0
const TURNIP: int = 1
const CARROT: int = 2
const PEA: int = 11
const WHEAT: int = 13
const BARLEY: int = 14
const BED_LOAM: int = 0
const BED_CLAY: int = 1
const BED_SAND: int = 2
const BED_WHEAT: int = 5
const SOUTH_1: int = Catalog.SOUTH_FIRST

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
	"""Policies over `sim` with a crew on the placeholder cast; what they say collected in `_said`."""
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


func _sow_jobs(tending: TendingScript) -> PackedInt32Array:
	"""The beds with a sowing on the board, in bed order."""
	var out := PackedInt32Array()
	for bed: int in Catalog.BED_COUNT:
		if tending._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, bed, _read):
			out.append(bed)
	return out


# --- the south field ----------------------------------------------------------------------------------------------------

func test_the_south_field_is_six_more_beds_laid_from_the_start() -> void:
	"""Twelve field beds: the six world beds and the south field's six 2 m tiles, laid at once, loam and clay, empty."""
	assert_equal(Catalog.FIELD_BED_COUNT, 12, "twelve field beds (E5: 12-18)")
	assert_equal(Catalog.GARDEN_FIRST, Catalog.FIELD_BED_COUNT, "the garden's sites after them")
	var sim := SimScript.new()
	for k: int in Catalog.SOUTH_BEDS:
		var bed: int = Catalog.SOUTH_FIRST + k
		assert_true(Catalog.is_south_field(bed) and not Catalog.is_garden(bed), "bed %d: south field" % (bed + 1))
		assert_true(sim.is_laid(bed), "laid from the start")
		assert_equal(sim.stage_of(bed), SimScript.STAGE_EMPTY, "empty")
		assert_equal(Catalog.bed_half_m(bed), Catalog.GARDEN_HALF_M, "a 2 m tile")
		assert_true(Catalog.BED_SOILS[bed] != FarmingScript.SOIL_SAND, "loam or clay: grain grows there")
		assert_equal(sim.sow_refusal(bed, WHEAT), SimScript.REFUSE_NONE, "wheat sows there on spring 1")
	assert_false(Catalog.is_south_field(Catalog.SOUTH_FIRST - 1) or Catalog.is_south_field(Catalog.GARDEN_FIRST), "the ends")


func test_the_south_field_is_one_rectangle_clear_of_everything() -> void:
	"""The six tiles make one 6 m x 4 m rectangle (three across, two deep, edge to edge: every tile on an outer edge),
	clear of every layout obstacle and far from the first field, inside the village."""
	var circles: Array[Vector3] = Layout.obstacles_for(Layout.placements())
	var rect := Rect2(Catalog.SOUTH_AT[0] - Vector2.ONE, Vector2.ZERO)
	for k: int in Catalog.SOUTH_BEDS:
		var at: Vector2 = Catalog.SOUTH_AT[k]
		rect = rect.expand(at - Vector2.ONE).expand(at + Vector2.ONE)
		for circle: Vector3 in circles:
			var near: Vector2 = Vector2(clampf(circle.x, at.x - 1.0, at.x + 1.0), clampf(circle.y, at.y - 1.0, at.y + 1.0))
			assert_true(near.distance_to(Vector2(circle.x, circle.y)) > circle.z, "south bed %d clear of %s" % [k, circle])
		assert_true(absf(at.x) < Layout.PLAY_HALF_EXTENT_M and absf(at.y) < Layout.PLAY_HALF_EXTENT_M, "inside")
		for field: int in Catalog.SOUTH_FIRST:
			assert_true(Catalog.bed_centre_m(field).distance_to(at) > 10.0, "far from the first field's bed %d" % (field + 1))
	assert_almost_equal(rect.size.x, 6.0, "three tiles across")
	assert_almost_equal(rect.size.y, 4.0, "two deep: every tile on an outer edge")


# --- the rotations -----------------------------------------------------------------------------------------------------

func test_each_bed_starts_on_the_cycle_its_soil_can_follow() -> void:
	"""Loam: §5.6's grain → beans → roots (wheat, pea, carrot); clay: grain → beans → grain; sand: roots only."""
	var sowing := SowingScript.new()
	assert_equal(sowing.rotation[BED_LOAM], SowingScript.ROTATION_GDD, "loam: the GDD's cycle")
	assert_equal(sowing.rotation[BED_CLAY], SowingScript.ROTATION_NO_ROOTS, "clay refuses roots")
	assert_equal(sowing.rotation[BED_SAND], SowingScript.ROTATION_ROOTS, "sand takes only roots")
	assert_equal([SowingScript.item_at(0, 0), SowingScript.item_at(0, 1), SowingScript.item_at(0, 2)], [WHEAT, PEA, CARROT],
		"wheat, pea, carrot")
	for bed: int in Catalog.BED_COUNT:
		assert_true(SowingScript.follows(sowing.rotation[bed], Catalog.BED_SOILS[bed]), "bed %d can follow it" % (bed + 1))
	assert_false(SowingScript.follows(SowingScript.ROTATION_GDD, FarmingScript.SOIL_CLAY), "not the GDD's on clay")
	assert_equal(sowing.rotation_words(BED_LOAM), "Grain → beans → roots (wheat, pea, carrot) · next: wheat", "in words")


func test_stepping_a_rotation_offers_only_what_the_soil_takes() -> void:
	"""Loam steps through all three; clay between its two; sand stays on roots; each step starts at the first entry."""
	var sowing := SowingScript.new()
	assert_equal(sowing.step_rotation(BED_LOAM), "Bed 1's rotation: Grain → beans → grain (wheat, pea, barley) · next: wheat",
		"loam: the next")
	sowing.step_rotation(BED_LOAM)
	assert_equal(sowing.rotation[BED_LOAM], SowingScript.ROTATION_ROOTS, "then roots only")
	sowing.step_rotation(BED_LOAM)
	assert_equal(sowing.rotation[BED_LOAM], SowingScript.ROTATION_GDD, "and round")
	sowing.step_rotation(BED_CLAY)
	assert_equal(sowing.rotation[BED_CLAY], SowingScript.ROTATION_NO_ROOTS, "clay has only the one it can follow")
	sowing.cursor[BED_SAND] = 2
	sowing.step_rotation(BED_SAND)
	assert_equal(sowing.cursor[BED_SAND], 0, "a step starts the cycle again")
	assert_equal(sowing.step_rotation(Catalog.BED_COUNT), "", "no bed")


func test_the_cursor_moves_once_its_crop_has_been_in_the_bed() -> void:
	"""The wheat bed (its cycle's first entry standing) moves to peas once harvested; a bed whose crop was the player's
	other choice does not move; an empty bed watched again does not move."""
	var sim := SimScript.new()
	var sowing := SowingScript.new()
	for bed: int in Catalog.BED_COUNT:
		sowing.observe(sim, bed)
	_until_ripe(sim, 3)
	assert_true(sim.harvest(3).ok, "the radish in a loam bed harvested")
	sowing.observe(sim, 3)
	_until_ripe(sim, BED_WHEAT)
	assert_true(sim.harvest(BED_WHEAT).ok, "the wheat harvested")
	sowing.observe(sim, BED_WHEAT)
	assert_equal(sowing.entry_item(BED_WHEAT), PEA, "next: peas")
	sowing.observe(sim, BED_WHEAT)
	assert_equal(sowing.cursor[BED_WHEAT], 1, "once only")
	assert_equal(sowing.entry_item(3), WHEAT, "radish was not its cycle's crop: still wheat")
	assert_equal(sowing.crop_to_sow(sim, 3), WHEAT, "the cycle's")
	sim.choose(3, CARROT)
	assert_equal(sowing.crop_to_sow(sim, 3), CARROT, "the player's choice first")


func test_a_wait_is_said_once_a_bed_and_entry() -> void:
	"""Summer: a loam bed's wheat waits for spring -- said once; a sowable bed says nothing."""
	var sim := SimScript.new()
	var sowing := SowingScript.new()
	sim.advance_usec(24 * 12 * HOUR_USEC)
	assert_equal(sowing.wait_words(sim, BED_LOAM), "Bed 1's wheat waits: sow in Spring 1–4", "said")
	assert_equal(sowing.wait_words(sim, BED_LOAM), "", "once")


func _until_ripe(sim: SimScript, bed: int) -> void:
	"""Run the farm an hour at a time until `bed` is ripe (at most twelve days)."""
	for hour: int in 24 * 12:
		if sim.stage_of(bed) == SimScript.STAGE_RIPE:
			return
		sim.advance_usec(HOUR_USEC)
	assert_equal(sim.stage_of(bed), SimScript.STAGE_RIPE, "bed %d ripened" % (bed + 1))


# --- the policy --------------------------------------------------------------------------------------------------------

func test_the_policy_sows_empty_beds_in_season_within_its_budget() -> void:
	"""Spring 1, the field's sowing on, 16 WU: four sowings (4 WU each), the empty field beds in bed order, each with its
	cycle's crop; the next hour nothing more; the next day four more."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_SOW, true)
	assert_equal(tending.sowable_beds(FIELD), 9, "bed 1, 2, 5 and the six south beds")
	assert_equal(tending.tomorrow_wu(FIELD), 16, "36 WU capped at 16")
	tending.run_hour()
	assert_equal(_sow_jobs(tending), PackedInt32Array([0, 1, 4, SOUTH_1]), "four sowings, in bed order")
	assert_equal(sim.chosen_of(0), WHEAT, "the loam bed's cycle: wheat")
	assert_equal(sim.chosen_of(1), WHEAT, "the clay bed's cycle: wheat")
	assert_equal(tending.spent_wu[FIELD], 16, "16 WU")
	tending.run_hour()
	assert_equal(_sow_jobs(tending).size(), 4, "the budget spent: no more today")
	assert_true(_said.size() == 1 and _said[0].contains("left unsown — the day's tending budget (16 WU) is spent"),
		str(_said))
	sim.advance_usec(24 * HOUR_USEC)
	tending.run_hour()
	assert_equal(_sow_jobs(tending).size(), 8, "four more the next day")


func test_a_refused_sowing_puts_the_choice_back() -> void:
	"""With the farm's board full, a sowing is refused: the bed's choice is what it was, and the bed is said."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_SOW, true)
	var jobs: JobsScript = tending._crew.jobs
	for bed: int in Catalog.FIELD_BED_COUNT:
		for kind: int in [JobsScript.KIND_COMPOST, JobsScript.KIND_RAISE]:
			if jobs.live_count() < JobsScript.MAX_JOBS:
				jobs.open_into(kind, bed, JobsScript.ORIGIN_PLAYER, _read)
	assert_equal(jobs.live_count(), JobsScript.MAX_JOBS, "the board is full")
	tending.run_hour()
	assert_equal(sim.chosen_of(0), Catalog.NO_ITEM, "no choice left behind")
	assert_true(_said.size() >= 1 and _said[0].contains("left unsown — Can't sow: the farm's job board is full"), str(_said))


func test_the_policy_waits_for_a_window_and_says_so_once() -> void:
	"""Summer 1: wheat's window has closed; the loam beds' wheat waits, each said once, nothing sown there."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_SOW, true)
	sim.advance_usec(24 * 12 * HOUR_USEC)
	sim.set_fallow(4, true)
	tending.run_hour()
	assert_false(_sow_jobs(tending).has(0), "bed 1 waits")
	for line: String in _said:
		assert_false(line.contains("left unsown"), "a wait is no refused order: %s" % line)
		assert_false(line.contains("Bed 5'"), "a resting bed is not the policy's: %s" % line)
	var first: int = _said.size()
	assert_true(_said.has("Tending: Field beds: Bed 1's wheat waits: sow in Spring 1–4"), str(_said))
	tending.run_hour()
	assert_equal(_said.size(), first, "not again")


func test_the_rotation_line_in_the_panel() -> void:
	"""The bed's rotation and its next crop; hidden with no bed."""
	var box := RotationBox.new()
	_nodes.append(box)
	var sowing := SowingScript.new()
	box.bind(sowing)
	box.refresh(BED_LOAM)
	assert_true(box.visible, "shown")
	assert_equal(box.line(), "Rotation: Grain → beans → roots (wheat, pea, carrot) · next: wheat", "its words")
	box.refresh(-1)
	assert_false(box.visible, "no bed: hidden")


func test_an_idle_hour_with_sowing_on_allocates_nothing() -> void:
	"""Summer, every bed waiting or growing and every wait said: fifty hourly runs keep the object count."""
	var sim := SimScript.new()
	var tending := _tending(sim)
	tending.set_policy(FIELD, TendingScript.POLICY_SOW, true)
	sim.advance_usec(24 * 12 * HOUR_USEC)
	tending.run_hour()
	tending.run_hour()
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 50:
		tending.run_hour()
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object made")
