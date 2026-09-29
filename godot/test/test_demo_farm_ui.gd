extends "res://test/framework/test_case.gd"
## The live demo farm's hands and faces (decision 0196): the crew carrying out jobs with the demo
## cast (sowing, harvesting and hauling to the store, fetching water, raising a bed with tunnel spoil,
## a worker called away and the work kept), the farm's own routine jobs, the brain's two farm orders,
## the command layer's farm hooks, the bed visuals and view, the words (farm_look / farm_text), the
## alerts, the recipe index, the HUD's Food cell and Food command, the bed panel and its crop picker,
## the Pantry, and demo_farm.gd's verbs and keys.
##
## No scene tree and no staged assets: the cast is the placeholder cast in the real village layout
## (plus the farm's pond), stepped at a fixed 60 Hz; the shell is the real HUD shell built off-tree.
## Expected values are literals from the cited constants (§5.6 yields, the demo WU and walk values).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")
const RecipesScript := preload("res://demo/farm/farm_recipes.gd")
const HudScript := preload("res://demo/farm/farm_hud.gd")
const AssetsScript := preload("res://demo/farm/farm_assets.gd")
const BedVisualScript := preload("res://demo/farm/farm_bed_visual.gd")
const ViewScript := preload("res://demo/farm/farm_view.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = 2500000
const CARROT: int = 2
const RADISH: int = 0
const PEA: int = 11
const WHEAT: int = 13
## The frost warning for the night into spring day 4 (02:00-05:59), named by its calendar date.
const FROST_SPRING_4: String = "Frost tonight (Spring 4, 02:00–05:59)! Cover growing beds (or raise them with spoil) and harvest what is ripe"
const BED_LOAM: int = 0
const BED_CLAY: int = 1
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_WHEAT: int = 5

var _nodes: Array[Node] = []
var _notices: PackedStringArray = PackedStringArray()
var _read: IntMath.IntResult = IntMath.IntResult.new()
## The demo's shared calendar, weather, water and feed, fresh for every test.
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
	_notices.clear()


# --- fixtures -----------------------------------------------------------------------------------

func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var circles: Array[Vector3] = world.obstacles()
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	return cast


func _crew(cast: DemoCastScript, sim: SimScript, pantry: PantryScript) -> CrewScript:
	"""A crew on this farm whose notices are collected; placeholder 0 is the routine crew."""
	var crew := CrewScript.new()
	crew.configure(cast, sim, pantry, TunnelsScript.new(), DemoFarmScript.well_position(),
		func(text: String) -> void: _notices.append(text))
	crew.set_crew(PackedInt32Array([0]))
	return crew


func _pantry(cast: DemoCastScript) -> PantryScript:
	"""A pantry with only the covered store, at its work spot."""
	return PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast)))


func _run(cast: DemoCastScript, crew: CrewScript, seconds: float, done: Callable) -> bool:
	"""Step the cast and the crew at 60 Hz until `done()` or `seconds` of demo time pass."""
	for frame: int in roundi(seconds / DT):
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
		if done.call():
			return true
	return false


func _brain(cast: DemoCastScript, i: int) -> BrainScript:
	"""Placeholder `i`'s brain."""
	return (cast.actor(i) as DemoActorScript).brain


# --- the crew -------------------------------------------------------------------------------------

func test_a_selected_resident_sows_a_bed_and_goes_back_to_its_routine() -> void:
	"""Wheat chosen for the loam bed, sowing ordered to placeholder 2: it walks there, commits the seed
	(SOWN), works 4 WU at 1.5 s and the wheat grows; the job closes and it wanders again."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	sim.choose(BED_LOAM, WHEAT)
	assert_equal(crew.order(JobsScript.KIND_SOW, BED_LOAM, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER),
		"Sow: Placeholder 2 is on it", "who took it")
	assert_equal(crew.task_text(2), "Sowing bed 1", "what the panel says")
	var sown := func() -> bool: return sim.stage_of(BED_LOAM) == SimScript.STAGE_SOWN
	assert_true(_run(cast, crew, 60.0, sown), "seed committed on arrival")
	assert_equal(crew.task_text(2), "Sowing the wheat bed", "the bed is named by its crop now")
	var grown := func() -> bool: return sim.stage_of(BED_LOAM) == SimScript.STAGE_SPROUTING
	assert_true(_run(cast, crew, 7.0, grown), "sowing completed within its 6 s")
	assert_equal(crew.jobs.live_count(), 0, "the job closed")
	assert_equal(_brain(cast, 2).order, BrainScript.ORDER_NONE, "back to its routine")
	assert_true(_notices.has("Sow done: the wheat bed"), "said so")


func test_a_harvest_is_carried_to_the_store_as_its_own_item() -> void:
	"""Ripe carrots: the harvest (5.1 U by §5.6's formula) goes into the pantry at the covered store
	as carrots; the bed is empty and waits for a new choice."""
	var cast := _cast()
	var sim := SimScript.new()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry)
	sim.advance_usec(24 * HOUR_USEC)
	crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var stored := func() -> bool: return pantry.total_units() > 0
	assert_true(_run(cast, crew, 180.0, stored), "delivered")
	assert_equal(pantry.milli_of(CARROT), 5100, "5.1 U of carrots")
	assert_equal(pantry.milli_at(CARROT, 0), 5100, "in the covered store")
	assert_equal(pantry.units_of(CARROT), 5, "counted as 5 carrots")
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_EMPTY, "the bed is empty")
	assert_equal(sim.chosen_of(BED_CARROTS), SimScript.NO_ITEM, "and asks for a new crop")
	assert_true(_notices.has("Harvested 5.1 U of carrot into the covered store"), "said how much")


func test_watering_fetches_water_at_the_well_first() -> void:
	"""The radish bed made dry (moisture 900): the worker goes to the well, fetches, carries it to the
	bed and tends it -- +1000 moisture and tended today."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	sim.farming().apply_moisture_delta(sim.slot_of(BED_RADISH), 900 - sim.moisture_of(BED_RADISH))
	crew.order(JobsScript.KIND_WATER, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var row: int = 0
	var fetched := func() -> bool: return crew.jobs.current_step(row) == JobsScript.STEP_CARRY_BED
	assert_true(_run(cast, crew, 90.0, fetched), "fetched at the well")
	assert_true(_brain(cast, 1).position.distance_to(DemoFarmScript.well_position()) < 3.0, "beside the well")
	var tended := func() -> bool: return sim.is_tended_today(BED_RADISH)
	assert_true(_run(cast, crew, 90.0, tended), "watered")
	assert_equal(sim.moisture_of(BED_RADISH), 1900, "900 + 1000")


func test_a_worker_called_away_keeps_the_work_done_for_the_next() -> void:
	"""Mid-sowing the player moves the worker: the job goes back on the board at the walk, with the
	seed already committed and the work kept; the routine crew (placeholder 0) finishes it."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	sim.choose(BED_LOAM, WHEAT)
	crew.order(JobsScript.KIND_SOW, BED_LOAM, PackedInt32Array([4]), JobsScript.ORIGIN_PLAYER)
	var working := func() -> bool: return crew.jobs.elapsed_usec[0] >= 3000000
	assert_true(_run(cast, crew, 60.0, working), "half-sown")
	_brain(cast, 4).order_move(Vector2(0.0, 5.0))
	crew.update(1)
	assert_equal(crew.jobs.worker[0], JobsScript.NOBODY, "back on the board")
	assert_equal(crew.jobs.current_step(0), JobsScript.STEP_GO_BED, "at the walk")
	assert_true(crew.jobs.elapsed_usec[0] >= 3000000, "the work kept")
	assert_equal(sim.stage_of(BED_LOAM), SimScript.STAGE_SOWN, "the seed stays committed")
	var grown := func() -> bool: return sim.stage_of(BED_LOAM) == SimScript.STAGE_SPROUTING
	assert_true(_run(cast, crew, 90.0, grown), "the crew finished it")
	assert_true(_notices.has("Placeholder 4 left the sow job"), "said so")


func test_the_farm_raises_harvest_and_clearing_jobs_for_the_crew() -> void:
	"""REQ-SET-073 / 085: a ripe bed gets a harvest job, a withered one a clearing job, each once; the
	routine crew member takes the harvest while wandering."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	sim.advance_usec(24 * HOUR_USEC)
	sim.farming().apply_health_loss(sim.slot_of(BED_WHEAT), 10000)
	crew.raise_routine_jobs()
	crew.raise_routine_jobs()
	assert_equal(crew.jobs.live_count(), 2, "one harvest, one clearing")
	assert_true(crew.jobs.job_on_bed_into(JobsScript.KIND_HARVEST, BED_CARROTS, _read), "harvest")
	assert_true(crew.jobs.job_on_bed_into(JobsScript.KIND_CLEAR, BED_WHEAT, _read), "clearing")
	var taken := func() -> bool: return crew.jobs.worker[0] == 0 or crew.jobs.worker[1] == 0
	assert_true(_run(cast, crew, 5.0, taken), "the crew took one")


func test_orders_explain_refusals_and_queues() -> void:
	"""Not ripe; nothing growing; queued with nobody selected; a second order for the same job."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	assert_equal(crew.order(JobsScript.KIND_HARVEST, BED_WHEAT, PackedInt32Array(), JobsScript.ORIGIN_PLAYER),
		"Can't harvest: not ripe", "not ripe")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_LOAM, PackedInt32Array(), JobsScript.ORIGIN_PLAYER),
		"Can't water: nothing growing", "empty bed")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array(), JobsScript.ORIGIN_PLAYER),
		"Water queued: the field crew will see to it", "queued")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array(), JobsScript.ORIGIN_PLAYER),
		"Water is already queued for the field crew", "not twice")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array([5]), JobsScript.ORIGIN_PLAYER),
		"Water: Placeholder 5 is on it", "a selected resident takes the queued job")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER),
		"Water is already under way: Placeholder 5 is on it", "already under way")
	assert_equal(crew.worker_name(0), "Placeholder 5", "who has it")
	assert_equal(crew.order(JobsScript.KIND_COVER, BED_WHEAT, PackedInt32Array([5]), JobsScript.ORIGIN_PLAYER),
		"Cover queued: the field crew will see to it", "a resident busy on the farm is not taken off its job")


func test_the_routine_crew_takes_work_only_when_wandering() -> void:
	"""The crew member under a player's move order leaves a queued job on the board."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_brain(cast, 0).order_move(Vector2(0.0, 5.0))
	crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array(), JobsScript.ORIGIN_PLAYER)
	crew.update(CrewScript.PICKUP_USEC)
	assert_equal(crew.jobs.worker[0], JobsScript.NOBODY, "not taken")
	_brain(cast, 0).release()
	crew.update(CrewScript.PICKUP_USEC)
	assert_equal(crew.jobs.worker[0], 0, "taken once it wanders")


func test_a_worker_ordered_elsewhere_on_the_way_drops_the_job() -> void:
	"""Re-ordered during the walk: the job goes back on the board."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	crew.update(16667)
	_brain(cast, 2).order_move(Vector2(0.0, 5.0))
	crew.update(16667)
	assert_equal(crew.jobs.worker[0], JobsScript.NOBODY, "dropped")


func test_a_blocked_walk_is_tried_again_before_giving_up() -> void:
	"""A walk the brain gives up on is re-issued; the job ends only after MAX_TRIES (3) such tries."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	crew.order(JobsScript.KIND_WATER, BED_WHEAT, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	for attempt: int in JobsScript.MAX_TRIES:
		crew.update(16667)
		assert_true(crew.jobs.is_live(0), "still on, try %d" % attempt)
		var brain := _brain(cast, 2)
		brain._abandon_trip()
		for frame: int in 60:
			brain.step(DT)
		crew.update(16667)
	assert_false(crew.jobs.is_live(0), "given up")
	assert_true(_notices.has("Water: Placeholder 2 couldn't get there"), "said so")


func test_a_harvest_is_hauled_with_the_carry_walk() -> void:
	"""A resident with a carry clip carries the harvest to the store."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_brain(cast, 3).set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 0.2]], "mean_speed_m_s": 0.2, "period_s": 1.0})
	sim.advance_usec(24 * HOUR_USEC)
	crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var hauling := func() -> bool: return crew.jobs.current_step(0) == JobsScript.STEP_CARRY_STORE \
		and crew.jobs.issued[0] == 1
	assert_true(_run(cast, crew, 120.0, hauling), "hauling")
	cast.advance(DT)
	assert_true(_brain(cast, 3).carrying, "with the carry walk")
	assert_equal(crew.task_text(3), "Carrying the carrot harvest to store", "says so")


func test_spoil_from_a_heap_raises_a_bed_and_the_heap_shrinks() -> void:
	"""A finished tunnel's entrance heap (16 U): raising the loam bed takes 2 U off it."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	var network: NetworkScript = cast.space().tunnels
	var route := PackedInt32Array([Rules.to_u(2.0), Rules.to_u(8.0), Rules.to_u(9.0), Rules.to_u(8.0)])
	var ref := PackedInt32Array([-1, 0])
	assert_true(network.add_into(route, 2, 0, ref), "a tunnel")
	network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	network.set_heap(ref[0], false, Vector2(2.0, 9.4), 0.7)
	network.set_heap(ref[0], true, Vector2(9.0, 9.4), 0.3)
	assert_equal(crew.max_heap_spoil(), 16000, "16 U at the entrance")
	crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var raised := func() -> bool: return sim.is_raised(BED_LOAM)
	assert_true(_run(cast, crew, 120.0, raised), "raised")
	assert_equal(crew.max_heap_spoil(), 14000, "2 U taken")


func test_cancelling_a_bed_stores_a_harvest_in_hand() -> void:
	"""A harvest carried when its jobs are cancelled goes into store as it is."""
	var cast := _cast()
	var sim := SimScript.new()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry)
	sim.advance_usec(24 * HOUR_USEC)
	crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var cut := func() -> bool: return crew.jobs.current_step(0) == JobsScript.STEP_CARRY_STORE
	assert_true(_run(cast, crew, 90.0, cut), "cut and carrying")
	assert_equal(crew.cancel_bed(BED_CARROTS), 1, "one job")
	assert_equal(pantry.milli_of(CARROT), 5100, "stored anyway")
	assert_equal(crew.jobs.live_count(), 0, "gone")


# --- the brain's farm orders and the command layer's hooks -----------------------------------------

func test_order_carry_carries_only_with_a_carry_clip() -> void:
	"""A placeholder has no carry motion: it walks. play_in_place works only while holding."""
	var cast := _cast()
	var brain := _brain(cast, 0)
	brain.order_carry(brain.position + Vector2(3.0, 0.0))
	assert_false(brain.carrying, "no carry clip, no carrying")
	assert_false(brain.play_in_place(&"collect_object"), "not holding")
	brain.order_move(brain.position)
	for frame: int in 120:
		brain.step(DT)
	assert_equal(brain.state, BrainScript.State.HOLD, "holding")
	assert_true(brain.play_in_place(&"collect_object"), "works in place")
	assert_equal(brain.clip, &"collect_object", "the work clip")
	assert_true(brain.play_in_place(&"no_such_clip"), "a missing clip")
	assert_equal(brain.clip, BrainScript.CLIP_IDLE, "idles")


func test_the_command_layer_hands_ground_clicks_and_orders_to_the_farm() -> void:
	"""A ground click the farm takes keeps the selection; a right click it takes gives no move order;
	the farm's task text replaces a resident's state in the panel."""
	var cast := _cast()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera)
	command.select(PackedInt32Array([1]))
	var clicks: Array = []
	command.set_ground_handlers(func(at: Vector2) -> bool: clicks.append(at); return true,
		func(at: Vector2) -> bool: clicks.append(-at); return true)
	command._pressing = true
	command._finish_select(Vector2(-5000.0, -5000.0))
	assert_equal(command.selection_count(), 1, "kept")
	assert_true(command.order_at(Vector2(10.0, 20.0)), "taken")
	assert_equal(clicks, [Vector2(-5000.0, -5000.0), Vector2(-10.0, -20.0)], "both went to the farm")
	assert_equal(_brain(cast, 1).order, BrainScript.ORDER_NONE, "no move order")
	command.set_task_text(func(i: int) -> String: return "Sowing bed %d" % i)
	assert_equal(command.party_entries()[0]["state"], "Sowing bed 1", "the farm's words")


# --- looks and words ------------------------------------------------------------------------------

func test_plants_grow_with_the_crop() -> void:
	"""None bare or sown; 0.14 at 0; 0.57 at half; full ripe; shrunk withered."""
	assert_equal(Look.plant_scale(SimScript.STAGE_EMPTY, 0), 0.0, "bare")
	assert_equal(Look.plant_scale(SimScript.STAGE_SOWN, 0), 0.0, "sown")
	assert_almost_equal(Look.plant_scale(SimScript.STAGE_SPROUTING, 0), 0.14, "seedlings")
	assert_almost_equal(Look.plant_scale(SimScript.STAGE_GROWING, 500), 0.57, "half grown")
	assert_equal(Look.plant_scale(SimScript.STAGE_RIPE, 1000), 1.0, "ripe")
	assert_almost_equal(Look.plant_scale(SimScript.STAGE_WITHERED, 1000), 0.72, "withered")
	assert_equal(Look.droop(SimScript.STAGE_WITHERED), 0.55, "withered plants droop")
	assert_equal(Look.droop(SimScript.STAGE_RIPE), 0.0, "ripe ones stand")
	assert_equal(Look.plant_tint(SimScript.STAGE_GROWING, CARROT, 0), Look.YOUNG_TINT, "young green")
	assert_equal(Look.plant_tint(SimScript.STAGE_GROWING, CARROT, 400), Look.YOUNG_TINT, "still green at 40%")
	assert_equal(Look.plant_tint(SimScript.STAGE_BLIGHTED, CARROT, 400), Look.BLIGHT_TINT, "blighted")
	assert_true(Look.shows_heads(SimScript.STAGE_RIPE, 6), "ripe cabbage shows heads")
	assert_false(Look.shows_heads(SimScript.STAGE_GROWING, 6), "not before")
	assert_false(Look.shows_heads(SimScript.STAGE_RIPE, CARROT), "not carrots")


func test_the_label_says_what_the_bed_needs() -> void:
	"""Status and urgency by stage and band."""
	assert_equal(Look.status(SimScript.STAGE_EMPTY, SimScript.NO_ITEM, 0, SimScript.BAND_GOOD, 0), "choose a crop", "empty")
	assert_equal(Look.status(SimScript.STAGE_EMPTY, WHEAT, 0, SimScript.BAND_GOOD, 0), "waiting to be sown", "chosen")
	assert_equal(Look.status(SimScript.STAGE_GROWING, WHEAT, 455, SimScript.BAND_WATERLOGGED, 0), "45% · waterlogged", "wet")
	assert_equal(Look.status(SimScript.STAGE_GROWING, WHEAT, 455, SimScript.BAND_DRY, 0), "45% · too dry", "parched")
	assert_equal(Look.status(SimScript.STAGE_GROWING, WHEAT, 455, SimScript.BAND_LOW, 0), "45% · dry", "dry")
	assert_equal(Look.status(SimScript.STAGE_RIPE, WHEAT, 1000, SimScript.BAND_GOOD, 47), "RIPE — harvest", "in grace")
	assert_equal(Look.status(SimScript.STAGE_RIPE, WHEAT, 1000, SimScript.BAND_GOOD, 48), "RIPE — spoiling", "decaying")
	assert_equal(Look.status(SimScript.STAGE_RIPE, WHEAT, 1000, SimScript.BAND_GOOD, 96), "RIPE — withers soon!", "last day")
	assert_equal(Look.urgency(SimScript.STAGE_RIPE, SimScript.BAND_GOOD, 47), Look.LABEL_ATTENTION, "attention")
	assert_equal(Look.urgency(SimScript.STAGE_RIPE, SimScript.BAND_GOOD, 48), Look.LABEL_URGENT, "urgent")
	assert_equal(Look.urgency(SimScript.STAGE_GROWING, SimScript.BAND_GOOD, 0), Look.LABEL_CALM, "calm")
	assert_equal(Look.urgency(SimScript.STAGE_GROWING, SimScript.BAND_WET, 0), Look.LABEL_ATTENTION, "wet")
	assert_equal(Look.title(SimScript.NO_ITEM, WHEAT, SimScript.STAGE_EMPTY), "Wheat (to sow)", "title")


func test_the_panel_words_come_from_the_rules() -> void:
	"""Windows, soils, rotation and a picker row, from §5.6's tables."""
	assert_equal(Text.window_text(FarmingScript.CROP_ROOTS), "Spring 1–8; Summer 1–4", "roots")
	assert_equal(Text.window_text(FarmingScript.CROP_GRAIN), "Spring 1–4", "grain")
	assert_equal(Text.soils_text(FarmingScript.CROP_ROOTS), "loam or sand", "roots' soils")
	assert_equal(Text.rotation_text(850), "same family again: yield ×0.85", "second")
	assert_equal(Text.rotation_text(1100), "legume after a change: yield ×1.10", "legume")
	var sim := SimScript.new()
	assert_equal(Text.pick_row(sim, BED_LOAM, PEA), "legume · 144 h · 7 U · fresh rotation: yield ×1.00 · feeds the soil +8",
		"a legume says it feeds the soil")
	assert_equal(Text.pick_reason(sim, BED_CLAY, RADISH), "needs loam or sand (this bed is clay)", "soil")
	assert_equal(Text.pick_reason(sim, BED_LOAM, PEA), "sow in Spring 5–10; Summer 1–3", "window")
	assert_equal(Text.pick_reason(sim, BED_LOAM, WHEAT), "", "sowable")
	assert_equal(Text.clock_line(sim), "Y1 Spring 1, 06:00 · 12 °C", "the demo calendar's date, as the HUD prints it")
	assert_equal(Text.moisture_line(sim, BED_CARROTS), "Moisture 6000 — good (2500–7000)", "moisture")
	assert_equal(Text.soil_line(sim, BED_CARROTS), "Sand · fertility 70% (yield ×0.85) · health 100%", "soil")
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Growing 80% — ripe in about 24 h", "growing")
	assert_equal(Text.yield_line(sim, BED_CARROTS, _read), "Expected yield: 5.1 U of carrot", "yield")
	assert_equal(Text.works_line(sim, BED_CARROTS), "Ground: as dug", "untouched")
	sim.advance_usec(24 * HOUR_USEC)
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Ripe — full yield for 48 h more, withers in 120 h", "just ripe")
	sim.advance_usec(50 * HOUR_USEC)
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Ripe — losing 10% a day, withers in 70 h", "past the grace")


# --- alerts, recipes, HUD --------------------------------------------------------------------------

func test_alerts_warn_once_with_the_response() -> void:
	"""Frost is announced from 12:00 the day before (spring 3), once; a ripening is a harvest call;
	a waterlogged growing bed says drain or raise."""
	var sim := SimScript.new()
	var alerts := AlertsScript.new()
	var lines := PackedStringArray()
	sim.advance_usec(24 * HOUR_USEC)
	var events := PackedInt32Array()
	sim.take_events_into(events)
	alerts.collect_into(sim, events, PackedInt32Array(), lines)
	assert_true(lines.has("Bed 3 (carrot) is ripe — harvest it within 2 days"), "ripe")
	lines.clear()
	sim.advance_usec(26 * HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_false(lines.has(FROST_SPRING_4), "not at 08:00")
	sim.advance_usec(4 * HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has(FROST_SPRING_4), "frost")
	lines.clear()
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_false(lines.has(FROST_SPRING_4), "once")
	sim.farming().apply_moisture_delta(sim.slot_of(BED_RADISH), 10000)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 4 (radish) is waterlogged and has stopped growing — drain it with a tunnel or raise it"), "wet")
	sim.farming().apply_moisture_delta(sim.slot_of(BED_WHEAT), -10000)
	sim.farming()._set_tile_fertility(sim.farming().tile_of(sim.slot_of(BED_LOAM)).value, 3900)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 6 (wheat) is too dry to grow — water it"), "dry")
	assert_true(lines.has("Bed 1 is worn out (fertility 39%) — compost it or rest it fallow"), "worn out")


func test_a_ripe_bed_past_its_grace_is_called_out() -> void:
	"""Carrots ripe at 24 h: at 72 h they are losing 10% a day; at 120 h - 24 they wither within a day."""
	var sim := SimScript.new()
	var alerts := AlertsScript.new()
	var lines := PackedStringArray()
	sim.advance_usec((24 + 48) * HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 3 (carrot) is losing 10% a day — harvest it"), "past the grace")
	sim.advance_usec(48 * HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 3 (carrot) withers within a day — harvest now!"), "last day")


func test_the_recipe_index_loads_in_the_catalog_s_order() -> void:
	"""Carrots feed 109 dishes directly and 15 more through prepared parts; a bad path loads nothing."""
	var recipes := RecipesScript.new()
	assert_true(recipes.load_index(), "loaded")
	assert_equal(recipes.direct_count(CARROT), 109, "direct")
	assert_equal(recipes.component_count(CARROT), 15, "through components")
	assert_equal(recipes.dishes_of(RADISH)[0], "Carrot-radish spring salad", "first dish, alphabetical")
	assert_equal(recipes.dishes_of(CARROT).size(), 40, "at most 40 listed")
	assert_equal(recipes.dishes_of(RADISH)[17], "Cold hodgepodge pie (in a prepared part)", "a use inside a component")
	var broken := RecipesScript.new()
	assert_false(broken.load_index("res://demo/farm/no_such_index.json"), "missing")
	assert_false(broken.is_loaded(), "not loaded")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RecipesScript.INDEX_PATH))
	var items: Array = index["items"]
	var swapped: Dictionary = index.duplicate(true)
	(swapped["items"] as Array)[0] = items[1]
	(swapped["items"] as Array)[1] = items[0]
	assert_false(broken.load_index(_fixture("user://farm_index_swapped.json", swapped)), "out of the catalog's order")
	var short: Dictionary = index.duplicate(true)
	(short["items"] as Array).pop_back()
	assert_false(broken.load_index(_fixture("user://farm_index_short.json", short)), "an ingredient missing")
	assert_false(broken.is_loaded(), "still not loaded")


func _fixture(path: String, data: Dictionary) -> String:
	"""Write a JSON fixture and return its path."""
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return path


func test_the_food_cell_shows_the_pantry_total_and_takes_it_back() -> void:
	"""The Food cell reads "7 U"; when UIManager writes its own figure the next sync paints the total
	back; an unchanged frame paints nothing."""
	var shell := UiShell.new()
	_nodes.append(shell)
	shell.build()
	var hud := HudScript.new()
	hud.bind(shell)
	assert_true(hud.sync(7), "painted")
	assert_equal(shell.counter_value_label(UiShell.ID_FOOD).text, "7 U", "the pantry total")
	assert_false(hud.sync(7), "nothing changed")
	shell.set_counter_display(UiShell.ID_FOOD, "5.48")
	assert_true(hud.sync(7), "painted back")
	assert_equal(shell.counter_value_label(UiShell.ID_FOOD).text, "7 U", "ours again")
	assert_true(hud.sync(8), "a new total")


func test_the_food_command_opens_the_pantry() -> void:
	"""UI-SET-030 is unlocked, wears the food icon and calls the Pantry."""
	var shell := UiShell.new()
	_nodes.append(shell)
	shell.build()
	var hud := HudScript.new()
	hud.bind(shell)
	var opened: Array = [0]
	assert_true(hud.unlock_food_command(func() -> void: opened[0] += 1), "unlocked")
	var food := shell.control_for(UiShell.ID_FOOD_ORDERS) as Button
	assert_false(food.disabled, "enabled")
	food.pressed.emit()
	assert_equal(opened[0], 1, "opened the pantry")
	assert_equal(food.tooltip_text, HudScript.FOOD_TOOLTIP, "says what it is")


# --- the visuals and panels -----------------------------------------------------------------------

func test_a_bed_visual_draws_each_stage() -> void:
	"""Placeholder art: no plants bare; plants at half growth scaled 0.57; furrows while sowing; the
	outline, straw, raised base and bank when asked."""
	var visual := BedVisualScript.new()
	_nodes.append(visual)
	visual.build(BED_LOAM, AssetsScript.new())
	visual.show_state(SimScript.STAGE_EMPTY, SimScript.NO_ITEM, 0, SimScript.BAND_GOOD, 0, "Empty bed", "choose a crop")
	assert_equal(visual.plant_count(), 0, "bare")
	visual.show_state(SimScript.STAGE_GROWING, WHEAT, 500, SimScript.BAND_GOOD, 0, "Wheat", "50%")
	assert_equal(visual.plant_count(), 196, "a 14 x 14 wheat stand")
	assert_almost_equal(visual.shown_scale, 0.57, "half grown")
	assert_almost_equal(visual.plant_transform(0, 0.57, 0.0).basis.get_scale().x, 0.57 * visual.layout_scale(0),
		"each plant at 0.57 of its own size")
	assert_equal(visual.label.text, "Wheat\n50%", "the label")
	var parsnip: int = Catalog.ITEM_KEYS.find(&"parsnip")
	visual.show_state(SimScript.STAGE_GROWING, parsnip, 500, SimScript.BAND_GOOD, 0, "Parsnip", "50%")
	assert_equal(visual.plant_count(), 40, "parsnip keeps the roots bed's carrot cards: 5 rows of 8")
	visual.show_state(SimScript.STAGE_GROWING, CARROT, 500, SimScript.BAND_GOOD, 0, "Carrot", "50%")
	assert_equal(visual.plant_count(), 36, "carrots on their own plant: the unstaged plant grid, 6 x 6")
	visual.show_state(SimScript.STAGE_SOWN, WHEAT, 0, SimScript.BAND_GOOD, 0, "Wheat", "sowing")
	assert_equal(visual.plant_count(), 0, "sown: furrows only")
	visual.set_selected(true)
	visual.show_works(true, true, true)
	assert_true(visual.ring.visible and visual.straw.visible and visual.raised_base.visible and visual.bank.visible, "all shown")
	assert_equal(visual.position, Vector3(-12.6, 0.0, 9.2), "at its bed")


func test_the_view_hides_the_world_beds_and_redraws_on_change() -> void:
	"""Six world crop pieces hidden; a bed redrawn only when the sim's revision moves."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	assert_equal(ViewScript.hide_world_beds(world.get_node("Village")), 6, "the six beds")
	var sim := SimScript.new()
	var view := ViewScript.new()
	_nodes.append(view)
	view.build({}, sim)
	assert_equal(view.beds.size(), 6, "six beds drawn")
	assert_equal(view.beds[BED_CARROTS].label.text, "Carrot\n80%", "carrots at 80%")
	sim.advance_usec(24 * HOUR_USEC)
	view.refresh()
	assert_equal(view.beds[BED_CARROTS].label.text, "Carrot\nRIPE — harvest", "redrawn ripe")
	view.select_bed(BED_CARROTS)
	view.refresh()
	assert_true(view.beds[BED_CARROTS].ring.visible, "outlined")
	assert_equal(view.cycle_overlay(), ViewScript.OVERLAY_MOISTURE, "moisture")
	view.refresh()
	assert_true(view.beds[BED_LOAM].overlay.visible, "overlay shown")
	assert_equal(view.cycle_overlay(), ViewScript.OVERLAY_RIPENESS, "ripeness")
	assert_equal(view.cycle_overlay(), ViewScript.OVERLAY_OFF, "off")


func test_heaps_are_drawn_at_what_is_left_after_spoil_is_taken() -> void:
	"""The tunnel overlay draws the entrance heap for 16 U; with 2 U taken the farm view redraws it for
	14 U; emptied, it is hidden; the untouched exit heap is left as the overlay drew it."""
	var cast := _cast()
	var network: NetworkScript = cast.space().tunnels
	var route := PackedInt32Array([Rules.to_u(2.0), Rules.to_u(8.0), Rules.to_u(9.0), Rules.to_u(8.0)])
	var ref := PackedInt32Array([-1, 0])
	network.add_into(route, 2, 0, ref)
	network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	var overlay := OverlayScript.new()
	_nodes.append(overlay)
	overlay.configure(network, cast.space(), DemoClockScript.new())
	overlay.refresh()
	var tunnels := TunnelsScript.new()
	var view := ViewScript.new()
	_nodes.append(view)
	view.build({}, SimScript.new())
	view.follow_tunnels(tunnels, network, overlay, Callable())
	var exit_scale: Vector3 = overlay.heap(ref[0], true).scale
	tunnels.take_spoil_into(network, 2 * ref[0], 2000, _read)
	view._process(0.0)
	var r: float = OverlayScript.heap_radius_m(14000)
	assert_almost_equal(overlay.heap(ref[0], false).scale.x, r, "14 U wide")
	assert_almost_equal(overlay.heap(ref[0], false).scale.y, r * OverlayScript.HEAP_ASPECT, "and tall")
	assert_equal(overlay.heap(ref[0], true).scale, exit_scale, "the exit heap untouched")
	tunnels.take_spoil_into(network, 2 * ref[0], 14000, _read)
	view._process(0.0)
	assert_false(overlay.heap(ref[0], false).visible, "emptied: gone")


func test_the_bed_panel_offers_only_what_the_bed_can_take() -> void:
	"""An empty loam bed: Plant on, Water and Harvest off (with reasons); the picker lists all sixteen,
	wheat sowable, peas not; picking emits the item."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, crew, NoticesScript.new())
	panel.show_bed(BED_LOAM)
	assert_false(panel.verb_button(JobsScript.KIND_SOW).disabled, "plant")
	assert_true(panel.verb_button(JobsScript.KIND_WATER).disabled, "water")
	assert_equal(panel.verb_button(JobsScript.KIND_WATER).tooltip_text, "nothing growing", "why")
	assert_true(panel.verb_button(JobsScript.KIND_HARVEST).disabled, "harvest")
	assert_equal(panel.line_text(1), "Moisture 6000 — good (4000–8000)", "readout")
	panel.show_bed(BED_CARROTS)
	assert_true(panel.verb_button(JobsScript.KIND_SOW).disabled, "no planting over a crop")
	panel.show_bed(BED_CLAY)
	panel.open_picker()
	assert_equal((panel._picker_rows.get_child(0).get_child(0) as Button).text, "Wheat", "sowable first: grain on clay")
	panel.show_bed(BED_LOAM)
	panel.open_picker()
	assert_equal(panel.picker_row_count(), 16, "every ingredient")
	assert_false(panel.picker_button(WHEAT).disabled, "wheat sowable")
	assert_true(panel.picker_button(PEA).disabled, "peas wait for spring 5")
	var picked: Array = []
	panel.crop_picked.connect(func(item: int) -> void: picked.append(item))
	panel.picker_button(WHEAT).pressed.emit()
	assert_equal(picked, [WHEAT], "wheat picked")


func test_the_bed_panel_shows_the_farm_s_news_from_the_feed() -> void:
	"""Under the date, the farm's latest notices from the demo's one feed, newest first; another
	source's are not the farm's."""
	var cast := _cast()
	var sim := SimScript.new()
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	var notices := NoticesScript.new()
	panel.configure(sim, _crew(cast, sim, _pantry(cast)), notices)
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Bed 3 (carrot) is ripe")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight!")
	notices.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_NOTE, "Tunnel 1 widened.")
	panel.refresh()
	assert_equal(panel.news_text(0), "• — · Warning: Frost tonight!", "the newest farm notice first")
	assert_equal(panel.news_text(1), "• — · Bed 3 (carrot) is ripe", "then the older")
	assert_equal(panel.news_text(2), "", "the tunnels' news is not the farm's")


func test_the_pantry_panel_breaks_the_food_out_by_item() -> void:
	"""Per-item rows, the stores line (with a fixture cellar) and the dishes of the picked item."""
	var sim := SimScript.new()
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [{"id": &"c", "position": Vector2.ZERO, "capacity_u": 60,
		"spoilage_permille": 350, "label": "Root cellar"}])
	var pantry := PantryScript.new(storage)
	pantry.add_into(CARROT, 5100, 1, _read)
	var recipes := RecipesScript.new()
	recipes.load_index()
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, pantry, recipes)
	assert_true(panel.toggle(), "open")
	assert_equal(panel.item_row_text(CARROT), "Carrot — 5 U · 100% fresh, spoils in 240 h", "carrots")
	assert_equal(panel.item_row_text(RADISH), "Radish — none", "no radish")
	assert_equal(panel.stores_text(), "Stores: Covered store 0/400 U (ages ×1.00) · Root cellar 5/60 U (ages ×0.35)", "stores")
	panel.select_item(CARROT)
	assert_equal(panel.dish_title(), "Carrot feeds 109 dishes (and 15 more through prepared parts)", "dishes")
	assert_true(panel.total_text().begins_with("5 U of food in store"), "total")
	assert_false(panel.toggle(), "closed")


# --- demo_farm.gd ----------------------------------------------------------------------------------

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


func test_the_most_pressing_work_on_a_bed() -> void:
	"""Ripe -> harvest; blighted -> clear; empty with a sowable choice -> sow; growing -> water; empty
	with nothing chosen -> nothing."""
	var farm := _farm()
	farm.sim.advance_usec(24 * HOUR_USEC)
	assert_true(farm.pressing_kind_into(BED_CARROTS, _read), "carrots")
	assert_equal(_read.value, JobsScript.KIND_HARVEST, "harvest")
	farm.sim.infect_for_test(BED_WHEAT)
	assert_true(farm.pressing_kind_into(BED_WHEAT, _read), "wheat")
	assert_equal(_read.value, JobsScript.KIND_CLEAR, "clear the blight")
	farm.sim.choose(BED_LOAM, WHEAT)
	assert_true(farm.pressing_kind_into(BED_LOAM, _read), "loam")
	assert_equal(_read.value, JobsScript.KIND_SOW, "sow")
	assert_true(farm.pressing_kind_into(BED_RADISH, _read), "radish")
	assert_equal(_read.value, JobsScript.KIND_WATER, "tend")
	assert_false(farm.pressing_kind_into(BED_CLAY, _read), "nothing chosen")


func test_before_a_frost_night_cover_comes_first_unless_the_bed_is_dry() -> void:
	"""Spring 3 12:00, frost tonight: the growing wheat gets covered; a dry growing radish is watered."""
	var farm := _farm()
	farm.sim.advance_usec(54 * HOUR_USEC)
	farm.sim.farming().apply_moisture_delta(farm.sim.slot_of(BED_RADISH), -10000)
	assert_true(farm.pressing_kind_into(BED_WHEAT, _read), "wheat")
	assert_equal(_read.value, JobsScript.KIND_COVER, "cover")
	assert_true(farm.pressing_kind_into(BED_RADISH, _read), "radish")
	assert_equal(_read.value, JobsScript.KIND_WATER, "water first")


func test_a_farm_hour_ages_the_pantry_and_reads_the_tunnels() -> void:
	"""A step of one farm hour ages every lot 1000 milli-hours and marks beds a finished tunnel runs
	under as drained."""
	var farm := _farm()
	farm.pantry.add_into(CARROT, 1000, 0, _read)
	var network: NetworkScript = farm._cast.space().tunnels
	var route := PackedInt32Array([Rules.to_u(-6.9), Rules.to_u(12.8), Rules.to_u(-14.0), Rules.to_u(12.8)])
	var ref := PackedInt32Array([-1, 0])
	network.add_into(route, 2, 0, ref)
	network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	farm.step(HOUR_USEC)
	assert_equal(farm.pantry.lot_age(0), 1000, "an hour older")
	assert_true(farm.sim.is_drained(BED_CARROTS), "drained")
	assert_true(farm.sim.is_drained(BED_RADISH), "drained")
	assert_false(farm.sim.is_drained(BED_LOAM), "not under")


func test_keys_cycle_the_overlay_and_open_the_pantry() -> void:
	"""V cycles the overlay; K opens and closes the Pantry; Esc closes it, then the bed panel."""
	var farm := _farm()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_V
	assert_true(farm.handle_key(key), "V")
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_MOISTURE, "moisture")
	key.physical_keycode = KEY_K
	assert_true(farm.handle_key(key), "K")
	assert_true(farm.pantry_panel.visible, "open")
	farm.select_bed(BED_LOAM)
	key.physical_keycode = KEY_ESCAPE
	assert_true(farm.handle_key(key), "Esc")
	assert_false(farm.pantry_panel.visible, "pantry closed first")
	assert_true(farm.handle_key(key), "Esc again")
	assert_equal(farm.selected_bed, DemoFarmScript.NO_BED, "bed panel closed")
	assert_false(farm.handle_key(key), "nothing left to close")
	key.physical_keycode = KEY_J
	assert_false(farm.handle_key(key), "other keys pass")


func test_one_key_cycles_every_map_overlay() -> void:
	"""V: moisture, ripeness, then an overlay the village added (the water's zones), then off -- each
	shown alone, so no two overlays share V."""
	var farm := _farm()
	var water_shown: Array[bool] = []
	farm.add_overlay("water zones", func(on: bool) -> void: water_shown.append(on))
	var names: Array[String] = []
	for press: int in 4:
		names.append(farm.cycle_overlays())
	assert_equal(names, ["moisture", "ripeness", "water zones", "off"] as Array[String], "the cycle")
	assert_equal(water_shown, [false, false, true, false] as Array[bool], "the water shown only on its step")
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_OFF, "and the farm's off again")


func test_planting_from_the_picker_orders_the_sowing() -> void:
	"""The picker's choice is chosen and its sowing queued for the crew (nobody selected)."""
	var farm := _farm()
	farm.select_bed(BED_LOAM)
	assert_equal(farm.plant(WHEAT), "Sow queued: the field crew will see to it", "queued")
	assert_equal(farm.sim.chosen_of(BED_LOAM), WHEAT, "chosen")
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "on the board")
