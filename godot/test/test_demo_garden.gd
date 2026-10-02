extends "res://test/framework/test_case.gd"
## The kitchen garden (review ECO-004 and feature #48, decision 0883; farm_garden.gd, farm_garden_box.gd,
## farm_garden_page.gd, farm_garden_view.gd, the garden sites in farm_catalog.gd and farm_sim.gd): the sites stand clear,
## a bed is laid out and taken up, a bare site grows nothing and takes no job, the work shelf is a §5.9 pantry store from
## the first bed on, the walking is said, the group's one plan sows every empty bed, and the cook is kept the garden's
## jobs between meals. Expected values are the cited constants' (§5.9 Shelf 50000 g, §5.7 250 g, §5.8 pantry 750).

const GardenScript := preload("res://demo/farm/farm_garden.gd")
const GardenBox := preload("res://demo/farm/farm_garden_box.gd")
const GardenPage := preload("res://demo/farm/farm_garden_page.gd")
const GardenView := preload("res://demo/farm/farm_garden_view.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const BedVisualScript := preload("res://demo/farm/farm_bed_visual.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const SITE_1: int = Catalog.GARDEN_FIRST
const SITE_2: int = Catalog.GARDEN_FIRST + 1
const SITE_4: int = Catalog.GARDEN_FIRST + 3
const LETTUCE: int = 7
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


func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	return cast


func _farm() -> DemoFarmScript:
	"""The farm over the placeholder village, off-tree, with a command layer and no HUD."""
	var cast := _cast()
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


func _garden(sim: SimScript) -> GardenScript:
	"""A garden over `sim` with a crew on the placeholder cast, the cook placeholder COOK."""
	var cast := _cast()
	var crew := CrewScript.new()
	crew.configure(cast, sim, PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast))), TunnelsScript.new(),
		DemoFarmScript.well_position(), func(_text: String) -> void: pass)
	var garden := GardenScript.new()
	garden.configure(sim, crew, DemoFarmScript.well_position())
	garden.bind_cook(func() -> int: return COOK)
	return garden


# --- the sites ---------------------------------------------------------------------------------------------------------

func test_the_sites_stand_clear_of_every_obstacle_and_bed() -> void:
	"""Each site's 2 m square, and the shelf, clear of every layout obstacle circle and every field bed, inside the play
	area and dry of the stream; four sites after the six field beds."""
	assert_equal(Catalog.BED_COUNT, Catalog.FIELD_BED_COUNT + Catalog.GARDEN_SITES, "six beds and four sites")
	assert_equal(Catalog.GARDEN_FIRST, Catalog.FIELD_BED_COUNT, "the sites come after the field")
	var circles: Array[Vector3] = Layout.obstacles_for(Layout.placements())
	for k: int in Catalog.GARDEN_SITES:
		var bed: int = Catalog.GARDEN_FIRST + k
		var at: Vector2 = Catalog.bed_centre_m(bed)
		assert_true(Catalog.is_garden(bed) and Catalog.bed_half_m(bed) == Catalog.GARDEN_HALF_M, "site %d is a 2 m tile" % k)
		for circle: Vector3 in circles:
			var near: Vector2 = Vector2(clampf(circle.x, at.x - 1.0, at.x + 1.0), clampf(circle.y, at.y - 1.0, at.y + 1.0))
			assert_true(near.distance_to(Vector2(circle.x, circle.y)) > circle.z, "site %d clear of %s" % [k, circle])
		for field: int in Catalog.FIELD_BED_COUNT:
			assert_true(Catalog.bed_centre_m(field).distance_to(at) > 4.0, "site %d apart from bed %d" % [k, field + 1])
		assert_true(absf(at.x) < Layout.PLAY_HALF_EXTENT_M and absf(at.y) < Layout.PLAY_HALF_EXTENT_M, "in the village")
	for circle: Vector3 in circles:
		assert_true(Catalog.GARDEN_SHELF_AT.distance_to(Vector2(circle.x, circle.y)) > circle.z + 0.4, "the shelf clear")
	assert_false(Catalog.is_garden(5) or Catalog.is_garden(Catalog.BED_COUNT), "the field and past the end are no sites")
	assert_equal(Catalog.bed_half_m(0), Catalog.BED_HALF_M, "a field bed keeps its 3 m drawing")


func test_a_click_finds_a_site_by_its_own_square() -> void:
	"""A 2 m site answers within 1 m of its centre, not at 1.4 m (a field bed's 1.5 m would)."""
	var at: Vector2 = Catalog.bed_centre_m(SITE_1)
	assert_true(Catalog.bed_at_into(at + Vector2(0.9, -0.9), _read) and _read.value == SITE_1, "inside")
	assert_false(Catalog.bed_at_into(at + Vector2(1.3, 0.0), _read) and _read.value == SITE_1, "outside its tile")


func test_a_tunnel_runs_under_a_garden_bed_within_its_tile() -> void:
	"""farm_tunnels.gd's reach is the bed's half-width: 1 m for a garden bed, 1.5 m for a field bed."""
	var tunnels := TunnelsScript.new()
	assert_equal(tunnels._bed_reach[SITE_1], Rules.to_u(1.0), "a garden bed's reach")
	assert_equal(tunnels._bed_reach[0], TunnelsScript.UNDER_REACH_U, "a field bed's, as before")


# --- laying out ----------------------------------------------------------------------------------------------------------

func test_a_bare_site_grows_nothing_and_takes_no_job() -> void:
	"""Not laid out: sowing refused NOT_LAID_OUT, every orderable kind refused, no outlet; laid out, it sows."""
	var sim := SimScript.new()
	assert_false(sim.is_laid(SITE_1), "bare at the start")
	assert_true(sim.is_laid(0), "a field bed is laid")
	assert_false(sim.is_laid(-1) or sim.is_laid(Catalog.BED_COUNT), "nothing past the ends")
	assert_equal(sim.sow_refusal(SITE_1, LETTUCE), SimScript.REFUSE_NOT_LAID, "no sowing")
	for kind: int in JobsScript.KIND_COUNT:
		assert_equal(JobsScript.refusal_for(sim, kind, SITE_1, 99999), SimScript.REFUSE_NOT_LAID, "%s refused" %
			JobsScript.KIND_NAMES[kind])
	assert_true(sim.lay_out(SITE_1).ok, "laid out")
	assert_equal(sim.sow_refusal(SITE_1, RADISH), SimScript.REFUSE_NONE, "radish sows in its loam in spring")


func test_laying_out_and_taking_up_keep_the_soil() -> void:
	"""Lay out refuses a field bed and a laid site; take up refuses a bare site and one with a crop; taken up, the
	site's fertility and choice: the fertility stays (BAL-SAFE-014), the choice goes."""
	var sim := SimScript.new()
	assert_equal(sim.lay_out(0).error, SimScript.REFUSE_NOT_A_SITE, "a field bed is no site")
	assert_equal(sim.take_up_refusal(SITE_1), SimScript.REFUSE_NOT_LAID, "nothing to take up")
	assert_true(sim.lay_out(SITE_1).ok, "laid out")
	assert_equal(sim.lay_out(SITE_1).error, SimScript.REFUSE_ALREADY, "laid already")
	assert_true(sim.compost(SITE_1).ok, "composted: fertility 8500")
	sim.choose(SITE_1, RADISH)
	assert_true(sim.sow_start(SITE_1).ok, "sown")
	assert_equal(sim.take_up(SITE_1).error, SimScript.REFUSE_IN_USE, "not with a crop in it")
	var fresh := SimScript.new()
	assert_true(fresh.lay_out(SITE_2).ok and fresh.compost(SITE_2).ok, "another, composted")
	fresh.choose(SITE_2, RADISH)
	assert_true(fresh.take_up(SITE_2).ok, "taken up")
	assert_false(fresh.is_laid(SITE_2), "bare again")
	assert_equal(fresh.fertility_of(SITE_2), 8500, "its soil kept")
	assert_equal(fresh.chosen_of(SITE_2), Catalog.NO_ITEM, "its choice forgotten")
	assert_equal(fresh.take_up(0).error, SimScript.REFUSE_NOT_A_SITE, "a field bed is never taken up")


func test_the_garden_lays_out_puts_up_its_shelf_and_keeps_it() -> void:
	"""The first bed puts the shelf up (a §5.9 Shelf: 200 U at the pantry's 750); a second says nothing of it; taking
	every bed up leaves the shelf standing."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	assert_true(garden.shelf_entries().is_empty(), "no shelf before a bed")
	assert_true(garden.lay_out(SITE_1).ends_with("the garden's work shelf is up"), "the first bed: the shelf")
	assert_false(garden.lay_out(SITE_2).contains("shelf"), "the second says nothing of it")
	assert_equal(garden.lay_out(SITE_2), "Can't lay out a bed: a bed is laid out there already", "refused in words")
	var entry: Dictionary = garden.shelf_entries()[0]
	assert_equal(entry[StorageScript.KEY_ID], GardenScript.SHELF_ID, "its id")
	assert_equal(entry[StorageScript.KEY_CAPACITY_U], 200, "50000 g at 250 g a unit")
	assert_equal(entry[StorageScript.KEY_PERMILLE], 750, "the pantry's factor")
	assert_equal(entry[StorageScript.KEY_POSITION], Catalog.GARDEN_SHELF_AT, "where it stands")
	assert_equal(garden.laid_beds(), PackedInt32Array([SITE_1, SITE_2]), "two beds")
	assert_true(garden.take_up(SITE_1).begins_with("Bed 13 taken up"), "taken up")
	assert_true(garden.take_up(SITE_2).begins_with("Bed 14 taken up"), "and the other")
	assert_false(garden.shelf_entries().is_empty(), "the shelf stays")
	assert_true(garden.take_up(SITE_2).begins_with("Can't take the bed up"), "a bare site is refused")


func test_the_walking_each_place_costs() -> void:
	"""Straight distances to the shelf and the well, worded; a round of the laid beds there and back."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var shelf: float = Catalog.bed_centre_m(SITE_1).distance_to(Catalog.GARDEN_SHELF_AT)
	var well: float = Catalog.bed_centre_m(SITE_1).distance_to(DemoFarmScript.well_position())
	assert_almost_equal(garden.shelf_metres(SITE_1), shelf, "to the shelf")
	assert_almost_equal(garden.well_metres(SITE_1), well, "to the well")
	assert_equal(garden.walking_text(SITE_1), "about %.1f m to the shelf · about %.1f m to the well" % [shelf, well], "said")
	assert_equal(garden.round_metres(), 0, "no bed, no round")
	garden.lay_out(SITE_1)
	garden.lay_out(SITE_4)
	var round_m: float = 2.0 * (shelf + well + garden.shelf_metres(SITE_4) + garden.well_metres(SITE_4))
	assert_equal(garden.round_metres(), roundi(round_m), "both beds there and back")
	assert_true(garden.well_metres(SITE_4) > garden.well_metres(SITE_1), "the far corner walks further")
	assert_equal(garden.site_title(SITE_1), "Bed 13 · kitchen garden", "a laid bed")
	assert_equal(garden.site_title(SITE_2), "Garden site 2", "a bare site")


func test_one_plan_sows_every_empty_garden_bed() -> void:
	"""No crop: said; with radish, each laid empty bed chosen and ordered; one standing is skipped with its reason."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	assert_equal(garden.sow_all(), "Choose the garden's crop first", "no crop")
	garden.set_plan_item(RADISH)
	assert_equal(garden.sow_all(), "No garden bed is laid out yet", "no bed")
	garden.lay_out(SITE_1)
	garden.lay_out(SITE_2)
	sim.choose(SITE_2, RADISH)
	assert_true(sim.sow_start(SITE_2).ok, "one already sown")
	var said: String = garden.sow_all()
	assert_true(said.begins_with("Sowing the garden with radish"), said)
	assert_true(said.contains("Bed 14: the bed is not empty"), "the sown one skipped, why")
	assert_equal(sim.chosen_of(SITE_1), RADISH, "chosen")
	assert_true(garden._crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "its sowing on the board")
	garden.set_plan_item(-5)
	assert_equal(garden.plan_item, Catalog.NO_ITEM, "an unknown crop is none")


func test_the_cook_is_kept_the_garden_between_meals() -> void:
	"""09:00-15:00, the cook free: a garden job is kept from anyone else; not from the cook, not a field bed's, not at
	08:00 or 15:00, not with the cook asleep, not with the garden hours off."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var garden_row: int = _sow_job(garden, SITE_1)
	var field_row: int = _sow_job(garden, 0)
	assert_false(garden.is_kept(garden_row, OTHER), "06:00: breakfast's hours, anyone's")
	sim.advance_usec(3 * HOUR_USEC)
	assert_false(GardenScript.in_cook_window(8), "breakfast is still served at 08:00")
	assert_true(GardenScript.in_cook_window(9) and GardenScript.in_cook_window(14), "09:00 to 14:59")
	assert_false(GardenScript.in_cook_window(15), "supper is cooked from 15:00")
	assert_equal(garden.kept_from(garden_row, OTHER), GardenScript.KEPT_WORDS, "09:00: kept for the cook")
	assert_equal(garden.kept_from(garden_row, COOK), "", "the cook may take it")
	assert_equal(garden.kept_from(field_row, OTHER), "", "a field bed's job is anyone's")
	garden.set_cook_tends(false)
	assert_false(garden.is_kept(garden_row, OTHER), "the garden hours off")
	garden.set_cook_tends(true)
	var brain: Variant = garden._crew.brain_of(COOK)
	brain.resting = true
	assert_false(garden.is_kept(garden_row, OTHER), "the cook asleep: anyone")
	brain.resting = false
	brain.indoors = true
	assert_false(garden.is_kept(garden_row, OTHER), "the cook indoors: anyone")
	brain.indoors = false
	sim.advance_usec(6 * HOUR_USEC)
	assert_false(garden.is_kept(garden_row, OTHER), "15:00: anyone")


func test_a_kept_job_follows_the_board_and_is_released_after_an_hour() -> void:
	"""With the board's claim test bound, a job is kept only while the board could give the cook farm work; kept a full
	hour unclaimed, it is anyone's; a new job starts its own hour."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var row: int = _sow_job(garden, SITE_1)
	sim.advance_usec(3 * HOUR_USEC)
	var claimable: Array[bool] = [false]
	garden.bind_claim_check(func(_who: int) -> bool: return claimable[0])
	assert_false(garden.is_kept(row, OTHER), "the board could not give the cook farm work: anyone's")
	claimable[0] = true
	assert_true(garden.is_kept(row, OTHER), "now it could: kept")
	sim.advance_usec(HOUR_USEC)
	assert_true(garden.is_kept(row, OTHER), "kept for its whole hour")
	@warning_ignore("integer_division") sim.advance_usec(HOUR_USEC / 30)
	assert_false(garden.is_kept(row, OTHER), "past the hour: released to anyone")
	garden._crew.jobs.close(row)
	var again: int = _sow_job(garden, SITE_1)
	assert_true(garden.is_kept(again, OTHER), "a new job starts its own hour")


func _sow_job(garden: GardenScript, bed: int) -> int:
	"""A waiting sowing on `bed` (laid out and chosen first), its row."""
	if Catalog.is_garden(bed):
		garden._sim.lay_out(bed)
	garden._sim.choose(bed, RADISH)
	assert_true(garden._crew.jobs.open_into(JobsScript.KIND_SOW, bed, JobsScript.ORIGIN_PLAYER, _read), "a sowing")
	return _read.value


# --- in the village ----------------------------------------------------------------------------------------------------

func test_a_site_s_panel_lays_out_a_bed_and_the_shelf_stands() -> void:
	"""Clicking a bare site shows 'Garden site 1' with its walking and Lay out; pressing it lays the bed out, the panel
	turns into the bed's, the shelf becomes a store and is drawn, the paths show and the overview lists the bed."""
	var farm := _farm()
	farm.select_bed(SITE_1)
	var panel := farm.bed_panel
	var box: GardenBox = panel.garden_box()
	assert_true(box.visible and box.lay_out_button().visible, "the site's box")
	assert_true(panel.shown_texts().has("Garden site 1"), "titled as a site")
	assert_true(box.walk_line().begins_with("Walking: about"), "its walking")
	assert_false(panel._actions.visible, "no verbs on a bare site")
	assert_false(panel.outlet_box().visible, "no outlet box either")
	box.lay_out_button().pressed.emit()
	assert_true(farm.sim.is_laid(SITE_1), "laid out")
	assert_true(panel._actions.visible, "a bed's verbs now")
	assert_true(box.take_up_button().visible, "and Take up")
	assert_true(farm.storage.index_of_id_into(GardenScript.SHELF_ID, _read), "the shelf is a store")
	farm.view.stock.refresh()
	farm.garden_view.refresh()
	assert_true(farm.view.stock.extra_shelf(0).visible, "the shelf drawn")
	assert_true(farm.garden_view.paths_shown(), "the paths drawn")
	farm.view.refresh()
	assert_false(farm.view.beds[SITE_1].showing_site(), "drawn as a bed")
	assert_true(farm.view.beds[SITE_2].showing_site(), "the others still sites")
	assert_almost_equal(farm.view.beds[SITE_1].scale.x, 2.0 / 3.0, "a 2 m bed")
	assert_true(farm.planner.overview() != null, "the planner is built")


func test_a_garden_harvest_goes_to_the_shelf() -> void:
	"""The pantry sends a harvest to the slowest-spoiling store with room, the nearest on a tie: from a garden bed, the
	garden's shelf (750) before the covered store (1000)."""
	var farm := _farm()
	farm.garden.lay_out(SITE_1)
	farm.pantry.refresh_locations()
	assert_true(farm.storage.index_of_id_into(GardenScript.SHELF_ID, _read), "the shelf")
	var shelf: int = _read.value
	assert_true(farm.pantry.reserve_near_into(RADISH, 6000, Catalog.bed_centre_m(SITE_1), _read), "room reserved")
	assert_true(farm.pantry.hold_location_into(_read.value, _read), "where")
	assert_equal(_read.value, shelf, "at the garden's shelf")


func test_the_garden_tab_lists_the_sites_and_runs_the_plan() -> void:
	"""Four rows, bare then laid; ◀ ▶ choose the crop; Sow every empty garden bed orders it; the cook's toggle; a row
	opens its site."""
	var farm := _farm()
	var page: GardenPage = farm.planner.garden_page()
	page.refresh()
	assert_equal(page.site_table().shown_rows(), Catalog.GARDEN_SITES, "four sites")
	assert_equal(page.site_table().row_texts(0)[1], "bare (lay out)", "bare")
	assert_true(page.sow_all_button().disabled, "nothing to sow yet")
	farm.garden.lay_out(SITE_1)
	page.step_crop(1)
	assert_equal(farm.garden.plan_item, 0, "the first crop: radish")
	page.step_crop(-1)
	assert_equal(farm.garden.plan_item, Catalog.ITEM_COUNT - 1, "back round to the last")
	page.step_crop(1)
	assert_true(page.crop_text().begins_with("Garden crop: Radish — keeps 10 days"), "the crop and its role's traits")
	assert_false(page.sow_all_button().disabled, "now it can")
	assert_true(page.sow_all().begins_with("Sowing the garden with radish"), "sown")
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, SITE_1, _read), "ordered")
	assert_equal(page.site_table().row_texts(0)[1], "Bed 13", "laid")
	assert_true(page.cook_button().button_pressed, "the cook tends it")
	page.toggle_cook()
	assert_false(farm.garden.cook_tends, "off")
	var wanted: Array[int] = []
	page.bed_wanted.connect(func(bed: int) -> void: wanted.append(bed))
	page.site_table().row(1).pressed.emit()
	assert_equal(wanted, [SITE_2] as Array[int], "a row opens its site")


func test_a_worker_stands_off_a_garden_bed_by_its_own_edge() -> void:
	"""The first stand is the same clearance from the bed's edge: 1.0 + 0.85 m for a garden bed, 1.5 + 0.85 m (the
	field's 2.35 m) for a field bed."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var crew: CrewScript = garden._crew
	sim.lay_out(SITE_1)
	sim.choose(SITE_1, RADISH)
	sim.choose(0, RADISH)
	assert_true(crew.jobs.open_into(JobsScript.KIND_SOW, SITE_1, JobsScript.ORIGIN_PLAYER, _read), "a garden job")
	assert_almost_equal(crew._stand_of(_read.value, JobsScript.STEP_GO_BED), 1.0 + CrewScript.BED_CLEAR_M, "1.85 m")
	assert_true(crew.jobs.open_into(JobsScript.KIND_SOW, 0, JobsScript.ORIGIN_PLAYER, _read), "a field job")
	assert_almost_equal(crew._stand_of(_read.value, JobsScript.STEP_GO_BED), CrewScript.BED_STAND_M, "2.35 m")


func test_a_refused_garden_sowing_keeps_the_bed_s_own_choice() -> void:
	"""The farm's board full: sowing the garden is refused bed by bed, and each bed keeps the choice it had."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	garden.lay_out(SITE_1)
	sim.choose(SITE_1, WHEAT)
	var jobs: JobsScript = garden._crew.jobs
	for bed: int in Catalog.FIELD_BED_COUNT:
		for kind: int in [JobsScript.KIND_COMPOST, JobsScript.KIND_RAISE]:
			if jobs.live_count() < JobsScript.MAX_JOBS:
				jobs.open_into(kind, bed, JobsScript.ORIGIN_PLAYER, _read)
	garden.set_plan_item(RADISH)
	assert_true(garden.sow_all().contains("Can't sow: the farm's job board is full"), "refused, said")
	assert_equal(sim.chosen_of(SITE_1), WHEAT, "its own choice kept")


func test_a_tunnel_passes_under_a_garden_bed_only_within_its_tile() -> void:
	"""A dug tunnel 1.2 m off a garden site's centre is not under it (its 2 m tile), but 1.2 m off a field bed's centre
	is under it (3 m); 0.8 m off the site it is."""
	var farm := _farm()
	var network: Variant = farm._cast.space().tunnels
	var site: Vector2 = Catalog.bed_centre_m(SITE_1)
	var slots: PackedInt32Array = _dig_straight(network, site + Vector2(-5.0, 1.2), site + Vector2(5.0, 1.2))
	assert_false(_under(farm, network, slots, SITE_1), "1.2 m off a 2 m tile: not under")
	var near: PackedInt32Array = _dig_straight(network, site + Vector2(-5.0, -0.8), site + Vector2(5.0, -0.8))
	assert_true(_under(farm, network, near, SITE_1), "0.8 m off: under")
	var field: Vector2 = Catalog.bed_centre_m(0)
	var by_field: PackedInt32Array = _dig_straight(network, field + Vector2(-5.0, 1.2), field + Vector2(5.0, 1.2))
	assert_true(_under(farm, network, by_field, 0), "1.2 m off a 3 m field bed: under")


func _dig_straight(network: Variant, from_m: Vector2, to_m: Vector2) -> PackedInt32Array:
	"""Lay and dig a straight tunnel piece; its segment rows."""
	var route := PackedInt32Array([Rules.to_u(from_m.x), Rules.to_u(from_m.y), Rules.to_u(to_m.x), Rules.to_u(to_m.y)])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(route, 2, 0, ref), "a tunnel")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot: int in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 3600 * Rules.USEC_PER_SECOND)
	return chain


func _under(farm: DemoFarmScript, network: Variant, slots: PackedInt32Array, bed: int) -> bool:
	"""Whether any of `slots` runs under `bed` (farm_tunnels.gd `passes_under`)."""
	for slot: int in slots:
		if farm.tunnels.passes_under(network, slot, bed):
			return true
	return false


func test_a_bed_taken_up_draws_no_works() -> void:
	"""A garden bed raised, then taken up: its site draws pegs and no raised frame; laid again, the frame is back (its
	soil kept its history)."""
	var farm := _farm()
	farm.garden.lay_out(SITE_1)
	assert_true(farm.sim.raise_bed(SITE_1).ok, "raised")
	farm.view.refresh()
	assert_true(farm.view.beds[SITE_1].raised_frame.visible, "the frame drawn")
	farm.garden.take_up(SITE_1)
	farm.view.refresh()
	assert_true(farm.view.beds[SITE_1].showing_site(), "a bare site")
	assert_false(farm.view.beds[SITE_1].raised_frame.visible, "no frame on a bare site")
	farm.garden.lay_out(SITE_1)
	farm.view.refresh()
	assert_true(farm.view.beds[SITE_1].raised_frame.visible, "laid again: the frame is back")


func test_a_load_in_hand_is_never_kept_for_the_cook() -> void:
	"""Between meals a garden sowing is kept for the cook, but a harvest's delivery on a garden bed is anyone's: a load in
	hand is carried home by whoever can (farm_crew.gd `kept_from`)."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var row: int = _sow_job(garden, SITE_1)
	sim.advance_usec(3 * HOUR_USEC)
	assert_equal(garden._crew.kept_from(row, OTHER), GardenScript.KEPT_WORDS, "a sowing: kept")
	garden._crew.jobs.kind[row] = JobsScript.KIND_HARVEST
	garden._crew.jobs.become_delivery(row)
	assert_equal(garden._crew.kept_from(row, OTHER), "", "a delivery: anyone's")


func test_a_bed_with_a_job_is_not_taken_up() -> void:
	"""A laid, empty garden bed with a sowing on its board is refused Take up until its jobs are cancelled."""
	var sim := SimScript.new()
	var garden := _garden(sim)
	var row: int = _sow_job(garden, SITE_1)
	assert_equal(garden.take_up(SITE_1), "Can't take the bed up: a job is on it — cancel its jobs first", "refused")
	garden._crew.jobs.close(row)
	assert_true(garden.take_up(SITE_1).begins_with("Bed 13 taken up"), "then taken up")
