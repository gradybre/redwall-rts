extends "res://test/framework/test_case.gd"
## The live demo farm's hands and faces (decision 0196): the crew carrying out jobs with the demo
## cast (sowing, harvesting and hauling to the store, fetching water, raising a bed with tunnel spoil,
## a worker called away and the work kept), the farm's own routine jobs, the brain's two farm orders,
## the command layer's farm hooks, the bed visuals and view, the words (farm_look / farm_text), the
## alerts, the recipe index, the HUD's Food command, the bed panel and its crop picker,
## the Pantry, and demo_farm.gd's verbs and keys.
##
## No scene tree and no staged assets: the cast is the placeholder cast in the real village layout
## (plus the farm's pond), stepped at a fixed 60 Hz; the shell is the real HUD shell built off-tree.
## Expected values are literals from the cited constants (§5.6 yields, the demo WU and walk values).

const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
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
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = 2500000
const CARROT: int = 2
const RADISH: int = 0
const PEA: int = 11
const WHEAT: int = 13
## The frost warning for the night into spring day 11 (02:00-05:59), named by its calendar date.
const FROST_SPRING_11: String = "Frost tonight (Spring 11, 02:00–05:59)! Cover growing beds (or raise them with spoil) and harvest what is ripe"
## Spring 10, 12:00 -- when that frost is announced -- in farm hours from the opening 06:00.
const SPRING_10_NOON_H: int = 24 * 9 + 6
const BED_LOAM: int = 0
const BED_CLAY: int = 1
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_CLAY_2: int = 4
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


func _sow(sim: SimScript, bed: int, item: int) -> void:
	"""Choose and sow `item` in `bed` now (both halves of the sowing)."""
	sim.choose(bed, item)
	assert_true(sim.sow_start(bed).ok and sim.sow_finish(bed).ok, "sown in bed %d" % bed)


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


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
	var stored := func() -> bool: return pantry.total_milli() > 0
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


func test_a_resident_drains_a_waterlogged_bed() -> void:
	"""The radish waterlogged (9800): the worker walks there and digs 6 WU; the bed drops to its band's
	top (7000), is ditched, and the job says so."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_set_moisture(sim, BED_RADISH, 9800)
	assert_equal(crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER),
		"Drain: Placeholder 1 is on it", "who took it")
	assert_equal(crew.task_text(1), "Draining the radish bed", "what the panel says")
	var ditched := func() -> bool: return sim.is_ditched(BED_RADISH)
	assert_true(_run(cast, crew, 90.0, ditched), "ditched")
	assert_equal(sim.moisture_of(BED_RADISH), 7000, "down to the band's top")
	assert_equal(crew.jobs.live_count(), 0, "the job closed")
	assert_true(_notices.has("Drain done: the radish bed"), "said so")
	assert_equal(crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER),
		"Can't drain: the bed is not too wet", "a drained bed refuses")


func test_a_drain_ends_if_the_bed_dried_on_the_way() -> void:
	"""The bed was wet when ordered and good when the worker got there: the job ends saying why."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_set_moisture(sim, BED_RADISH, 7500)
	crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	_set_moisture(sim, BED_RADISH, 6000)
	var ended := func() -> bool: return crew.jobs.live_count() == 0
	assert_true(_run(cast, crew, 90.0, ended), "ended")
	assert_false(sim.is_ditched(BED_RADISH), "no ditch dug")
	assert_true(_notices.has("Can't drain: the bed is not too wet"), "said why")


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
		"Can't harvest: the crop is not ripe yet", "not ripe")
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_LOAM, PackedInt32Array(), JobsScript.ORIGIN_PLAYER),
		"Can't water: nothing is growing to water", "empty bed")
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
	assert_equal(crew.task_text(3), "Carrying 5.1 U of carrot to the covered store", "says so, and how much")


func _dig_tunnel(network: GraphScript, from_m: Vector2, to_m: Vector2) -> PackedInt32Array:
	"""Lay a straight mouth-to-mouth tunnel (at least 8 m: two 4 m ramps) as a piece and dig every segment
	of it to the end; returns [entrance mouth row, exit mouth row] -- its two heaps."""
	var route := PackedInt32Array([Rules.to_u(from_m.x), Rules.to_u(from_m.y), Rules.to_u(to_m.x), Rules.to_u(to_m.y)])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(route, 2, 0, ref), "a tunnel")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot: int in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 3600 * Rules.USEC_PER_SECOND)
	assert_true(network.piece_done(ref[2]), "dug")
	return PackedInt32Array([network.mouth_of_end(chain[0], false), network.mouth_of_end(chain[chain.size() - 1], true)])


func test_spoil_from_a_heap_raises_a_bed_and_the_heap_shrinks() -> void:
	"""A finished 8 m tunnel's entrance heap: two 4 m ramps, every cut but the exit shaft heaped at the
	entrance -- 9 x 2 U = 18 U. Raising the loam bed takes 2 U off it."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	var network: GraphScript = cast.space().tunnels
	var heaps: PackedInt32Array = _dig_tunnel(network, Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	network.set_heap(heaps[0], Vector2(2.0, 9.4), 0.7, Vector2(0.0, 1.0))
	network.set_heap(heaps[1], Vector2(10.0, 9.4), 0.3, Vector2(0.0, 1.0))
	assert_equal(crew.max_heap_spoil(), 18000, "18 U at the entrance")
	crew.order(JobsScript.KIND_RAISE, BED_LOAM, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var raised := func() -> bool: return sim.is_raised(BED_LOAM)
	assert_true(_run(cast, crew, 120.0, raised), "raised")
	assert_equal(crew.max_heap_spoil(), 16000, "2 U taken")


func test_cancelling_a_bed_lets_a_harvest_in_hand_finish_its_delivery() -> void:
	"""Decision 0222 (the review's F24): a harvest carried when its jobs are cancelled is not put in store
	at the cancel -- it becomes its delivery, carried on and stored at the store."""
	var cast := _cast()
	var sim := SimScript.new()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry)
	sim.advance_usec(24 * HOUR_USEC)
	crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var cut := func() -> bool: return crew.jobs.current_step(0) == JobsScript.STEP_CARRY_STORE
	assert_true(_run(cast, crew, 90.0, cut), "cut and carrying")
	assert_equal(crew.cancel_bed(BED_CARROTS), 1, "one job")
	assert_equal(pantry.milli_of(CARROT), 0, "not credited at the cancel")
	assert_equal(crew.jobs.kind[0], JobsScript.KIND_DELIVER, "now its delivery")
	assert_true(_run(cast, crew, 90.0, func() -> bool: return crew.jobs.live_count() == 0), "delivered")
	assert_equal(pantry.milli_of(CARROT), 5100, "stored at the store")


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
	assert_equal(Text.rotation_text(850), "same family again: harvest −15%", "second")
	assert_equal(Text.rotation_text(1100), "legume after a change: harvest +10%", "legume")
	assert_equal(Text.rotation_text(1000), "fresh rotation: no change to the harvest", "fresh")
	var sim := SimScript.new()
	assert_equal(Text.pick_row(sim, BED_LOAM, PEA), "legume crop · matures in 6 days · this bed: about 5.9 U (base 7.0 U) · "
		+ "fresh rotation: no change to the harvest · feeds the soil: +8 fertility points", "a legume says it feeds the soil")
	assert_equal(Text.pick_reason(sim, BED_CLAY, RADISH), "needs loam or sand (this bed is clay)", "soil")
	assert_equal(Text.pick_reason(sim, BED_LOAM, PEA), "sow in Spring 5–10; Summer 1–3", "window")
	assert_equal(Text.pick_reason(sim, BED_LOAM, WHEAT), "", "sowable")
	assert_equal(Text.clock_line(sim), "Y1 Spring 1, 06:00 · 12 °C", "the demo calendar's date, as the HUD prints it")
	assert_equal(Text.moisture_line(sim, BED_CARROTS), "Soil moisture: Good · 60%", "moisture")
	assert_equal(Text.range_line(sim, BED_CARROTS), "Suitable for this crop: 25–70%", "its range")
	assert_equal(Text.soil_line(sim, BED_CARROTS), "Soil: Sand", "soil")
	assert_equal(Text.fertility_line(sim, BED_CARROTS), "Fertility: 70%", "fertility")
	assert_equal(Text.fertility_effect_line(sim, BED_CARROTS), "Fertility effect on yield: −15%", "its effect")
	assert_equal(Text.health_line(sim, BED_CARROTS), "Crop health: 100%", "health")
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Growing 80% — ripe in about 24 h", "growing")
	assert_equal(Text.yield_line(sim, BED_CARROTS, _read), "Expected harvest: 5.1 U of carrot", "yield")
	assert_equal(Text.works_line(sim, BED_CARROTS), "Ground: as dug", "untouched")
	sim.advance_usec(24 * HOUR_USEC)
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Ripe — full yield for 48 h more, withers in 120 h", "just ripe")
	sim.advance_usec(50 * HOUR_USEC)
	assert_equal(Text.stage_line(sim, BED_CARROTS, _read), "Ripe — losing 10% a day, withers in 70 h", "past the grace")


# --- alerts, recipes, HUD --------------------------------------------------------------------------

func test_alerts_warn_once_with_the_response() -> void:
	"""Frost is announced from 12:00 the day before (spring 10), once; a ripening is a harvest call;
	the answers to a bed out of its band follow."""
	var sim := SimScript.new()
	_sow(sim, BED_CLAY, WHEAT)
	_sow(sim, BED_CLAY_2, WHEAT)
	var alerts := AlertsScript.new()
	var lines := PackedStringArray()
	sim.advance_usec(24 * HOUR_USEC)
	var events := PackedInt32Array()
	sim.take_events_into(events)
	alerts.collect_into(sim, events, PackedInt32Array(), lines)
	assert_true(lines.has("Bed 3 (carrot) is ripe — harvest it within 2 days"), "ripe")
	lines.clear()
	sim.advance_usec((SPRING_10_NOON_H - 24 - 1) * HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_false(lines.has(FROST_SPRING_11), "not at 11:00")
	sim.advance_usec(HOUR_USEC)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has(FROST_SPRING_11), "frost")
	lines.clear()
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_false(lines.has(FROST_SPRING_11), "once")


func test_alerts_name_the_answer_to_a_bed_out_of_its_band() -> void:
	"""A waterlogged growing bed: Drain it; a parched one: water it; a worn-out empty one: compost or
	rest it."""
	var sim := SimScript.new()
	_sow(sim, BED_CLAY, WHEAT)
	_sow(sim, BED_CLAY_2, WHEAT)
	var alerts := AlertsScript.new()
	var lines := PackedStringArray()
	_set_moisture(sim, BED_CLAY, 10000)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 2 (wheat) is waterlogged and has stopped growing — Drain it"), "wet: names Drain")
	_set_moisture(sim, BED_CLAY_2, 0)
	sim.farming()._set_tile_fertility(sim.farming().tile_of(sim.slot_of(BED_LOAM)).value, 3900)
	alerts.collect_into(sim, PackedInt32Array(), PackedInt32Array(), lines)
	assert_true(lines.has("Bed 5 (wheat) is too dry to grow — water it"), "dry")
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
	assert_equal(food.tooltip_text, "Food (K) — " + HudScript.FOOD_TOOLTIP, "says what it is, and its key")


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
	visual.show_works(true, true, true, true)
	assert_true(visual.ring.visible and visual.straw.visible and visual.raised_frame.visible and visual.bank.visible
		and visual.ditch.visible, "all shown")
	assert_equal(visual.position, Vector3(-12.6, 0.0, 9.2), "at its bed")


func test_wet_soil_darkens_and_a_waterlogged_bed_shows_puddles() -> void:
	"""Good soil: no film, no puddles. Wet: a dark, glossy film, no puddles. Waterlogged: a darker,
	glossier film and the puddles. Neither is blue (blue under red and green would be a tint)."""
	var visual := BedVisualScript.new()
	_nodes.append(visual)
	visual.build(BED_RADISH, AssetsScript.new())
	visual.show_state(SimScript.STAGE_GROWING, RADISH, 500, SimScript.BAND_GOOD, 0, "Radish", "50%")
	assert_false(visual.showing_puddles(), "good: no puddles")
	assert_equal(visual.sheen_colour().a, 0.0, "good: no film")
	visual.show_state(SimScript.STAGE_GROWING, RADISH, 500, SimScript.BAND_WET, 0, "Radish", "50%")
	assert_false(visual.showing_puddles(), "wet: no puddles")
	var wet: Color = visual.sheen_colour()
	visual.show_state(SimScript.STAGE_GROWING, RADISH, 500, SimScript.BAND_WATERLOGGED, 0, "Radish", "50%")
	assert_true(visual.showing_puddles(), "waterlogged: puddles")
	var logged: Color = visual.sheen_colour()
	assert_true(logged.a > wet.a and wet.a > 0.0, "waterlogged darkens more than wet")
	for film: Color in [wet, logged]:
		assert_true(film.get_luminance() < 0.1, "a dark film, not a pale one")
		assert_true(film.b <= film.r, "not blue")
	assert_true(Look.sheen_roughness(SimScript.BAND_WATERLOGGED) < Look.sheen_roughness(SimScript.BAND_WET),
		"glossier the wetter")
	assert_true(Look.PUDDLE_COLOR.get_luminance() < 0.3, "the puddles are dark water, not bright")
	var tint: Color = Look.BAND_OVERLAY[SimScript.BAND_WATERLOGGED]
	assert_true(tint.a < 0.5 and tint.b - tint.r < 0.3, "the overlay's waterlogged tint is calm")


func test_the_ground_works_are_built_once_and_shown_when_done() -> void:
	"""Raised: 2 planks a side and 4 posts round the lifted soil (no slab), the posts standing proud of
	the planks; banked: 4 rounded berms; ditched: 4 trench strips and 4 lips. None shown until done."""
	var visual := BedVisualScript.new()
	_nodes.append(visual)
	visual.build(BED_LOAM, AssetsScript.new())
	visual.show_works(false, false, false, false)
	assert_false(visual.raised_frame.visible or visual.bank.visible or visual.ditch.visible, "nothing yet")
	assert_equal(visual.raised_frame.get_child_count(), 12, "8 planks and 4 posts")
	var tallest_board: float = 0.0
	var tones := {}
	for k: int in 8:
		var board := visual.raised_frame.get_child(k) as MeshInstance3D
		var box := board.mesh as BoxMesh
		tallest_board = maxf(tallest_board, board.position.y + box.size.y * 0.5)
		tones[box.material] = true
	var post := visual.raised_frame.get_child(8) as MeshInstance3D
	assert_true(post.get_aabb().size.y > 0.0 and post.position.y * 2.0 > tallest_board, "posts stand proud")
	assert_true(tones.size() >= 2, "the planks vary in tone")
	assert_true(tallest_board > BedVisualScript.RAISE_LIFT_M, "the planks cover the lift")
	assert_true(visual.bank.get_child(0) is MeshInstance3D and (visual.bank.get_child(0) as MeshInstance3D).mesh is CapsuleMesh,
		"a rounded berm")
	assert_equal(visual.ditch.get_child_count(), 8, "four trench strips, four lips")
	visual.show_works(false, true, false, true)
	assert_true(visual.raised_frame.visible and visual.ditch.visible, "raised and ditched")
	assert_false(visual.bank.visible or visual.straw.visible, "not banked or covered")


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
	_set_moisture(sim, BED_LOAM, 9000)
	assert_true(sim.drain_bed(BED_LOAM).ok, "the loam bed drained")
	view.refresh()
	assert_true(view.beds[BED_LOAM].ditch.visible, "its ditch drawn")
	assert_false(view.beds[BED_CLAY].ditch.visible, "not the others'")


func test_the_view_s_key_covers_the_ditch_alone() -> void:
	"""A bed redraws when only its ditch changes (the view's state key carries it, not just the band a
	drain also moves): the ditch flag set with the moisture untouched still draws the ditch."""
	var sim := SimScript.new()
	var view := ViewScript.new()
	_nodes.append(view)
	view.build({}, sim)
	var band: int = sim.band_of(BED_CLAY)
	sim._ditched[BED_CLAY] = 1
	sim.revision += 1
	view.refresh()
	assert_equal(sim.band_of(BED_CLAY), band, "the band did not move")
	assert_true(view.beds[BED_CLAY].ditch.visible, "the ditch is drawn")


func test_heaps_are_drawn_at_what_is_left_after_spoil_is_taken() -> void:
	"""The tunnel overlay draws the 8 m tunnel's entrance heap for 18 U; with 2 U taken the farm view
	redraws it for 16 U; emptied, it is hidden; the untouched exit heap is left as the overlay drew it."""
	var cast := _cast()
	var network: GraphScript = cast.space().tunnels
	var heaps: PackedInt32Array = _dig_tunnel(network, Vector2(2.0, 8.0), Vector2(10.0, 8.0))
	var overlay := OverlayScript.new()
	_nodes.append(overlay)
	overlay.configure(network, cast.space(), DemoClockScript.new())
	overlay.refresh()
	var tunnels := TunnelsScript.new()
	var view := ViewScript.new()
	_nodes.append(view)
	view.build({}, SimScript.new())
	view.follow_tunnels(tunnels, network, overlay)
	var r0: float = OverlayScript.heap_radius_m(18000)
	assert_almost_equal(overlay.heap(heaps[0]).scale.x, r0, "drawn for 18 U")
	var exit_scale: Vector3 = overlay.heap(heaps[1]).scale
	assert_true(tunnels.take_spoil_into(network, heaps[0], 2000, _read), "2 U taken")
	view._process(0.0)
	var r: float = OverlayScript.heap_radius_m(16000)
	assert_almost_equal(overlay.heap(heaps[0]).scale.x, r, "16 U wide")
	assert_almost_equal(overlay.heap(heaps[0]).scale.y, r * OverlayScript.HEAP_ASPECT, "and tall")
	assert_equal(overlay.heap(heaps[1]).scale, exit_scale, "the exit heap untouched")
	assert_true(tunnels.take_spoil_into(network, heaps[0], 16000, _read), "the rest taken")
	view._process(0.0)
	assert_false(overlay.heap(heaps[0]).visible, "emptied: gone")


func test_the_bed_panel_offers_only_what_the_bed_can_take() -> void:
	"""An empty loam bed: Plant on, Water and Harvest off (with reasons); the picker lists all sixteen,
	wheat sowable, peas not; picking emits the item."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, crew)
	panel.show_bed(BED_LOAM)
	assert_false(panel.verb_button(JobsScript.KIND_SOW).disabled, "plant")
	assert_true(panel.verb_button(JobsScript.KIND_WATER).disabled, "water")
	assert_true(panel.verb_button(JobsScript.KIND_WATER).tooltip_text.contains("Can't now: nothing is growing to water"),
		"why: its action card (decision 0332)")
	assert_true(panel.verb_button(JobsScript.KIND_HARVEST).disabled, "harvest")
	assert_equal(panel.line_text(1), "Soil moisture: Good · 60%", "readout")
	assert_equal(panel.line_text(2), "Suitable for an empty bed: 40–80%", "the range it is judged by")
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


func test_the_bed_panel_shows_only_its_bed_not_the_feed() -> void:
	"""The farm's notices are the news strip's: posted to the feed, none of them shows in the bed panel,
	with a bed or without; without one it shows the title, the date and the hint only."""
	var cast := _cast()
	var sim := SimScript.new()
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	var notices := NoticesScript.new()
	panel.configure(sim, _crew(cast, sim, _pantry(cast)))
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Bed 3 (carrot) is ripe")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Frost tonight!")
	panel.refresh()
	assert_equal(panel.shown_texts(), PackedStringArray(["Farm", Text.clock_line(sim), BedPanelScript.HINT]),
		"no bed: the title, the date and the hint")
	panel.show_bed(BED_CARROTS)
	var shown: String = "\n".join(panel.shown_texts())
	assert_false(shown.contains("Frost tonight!") or shown.contains("is ripe"), "no feed lines with a bed")
	assert_false(shown.contains(Text.clock_line(sim)), "the date is the HUD's once a bed is open")
	assert_true(shown.begins_with("Bed 3 · Carrot\nGrowing 80%"), "the title, then (nothing pressing) the stage")


func _panel_on(sim: SimScript) -> BedPanelScript:
	"""A bed panel over this farm (placeholder cast and crew)."""
	var cast := _cast()
	var panel := BedPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, _crew(cast, sim, _pantry(cast)))
	return panel


func test_the_needs_line_names_each_bed_s_most_pressing_verb() -> void:
	"""Nothing pressing (or merely low): hidden. Waterlogged: Drain, in clay; parched: Water; blighted:
	Clear. The stage line says why growth stopped."""
	var sim := SimScript.new()
	var panel := _panel_on(sim)
	panel.show_bed(BED_RADISH)
	assert_equal(panel.needs_text(), "", "a good growing bed: nothing")
	_set_moisture(sim, BED_RADISH, 9800)
	panel.refresh()
	assert_equal(panel.needs_text(), "Needs: Drain — waterlogged, not growing", "waterlogged")
	assert_equal(panel.needs_colour(), Palette.CLAY, "a warning")
	assert_equal(panel.line_text(0), "Growing 30% — stalled, waterlogged", "the stage says why it stopped")
	_set_moisture(sim, BED_RADISH, 100)
	panel.refresh()
	assert_equal(panel.needs_text(), "Needs: Water — too dry to grow", "parched")
	assert_equal(panel.line_text(0), "Growing 30% — stalled, too dry", "stalled dry")
	_set_moisture(sim, BED_RADISH, 1000)
	panel.refresh()
	assert_equal(panel.needs_text(), "", "merely low: not pressing")
	sim.infect_for_test(BED_RADISH)
	panel.refresh()
	assert_equal(panel.needs_text(), "Needs: Clear — blighted, spreads at midnight", "blighted")


func test_the_needs_line_times_a_ripe_bed() -> void:
	"""Ripe: Harvest with the time before it spoils (ink, not a warning), then before it withers
	(clay); withered: Clear."""
	var sim := SimScript.new()
	var panel := _panel_on(sim)
	sim.advance_usec(24 * HOUR_USEC)
	panel.show_bed(BED_CARROTS)
	assert_equal(panel.needs_text(), "Needs: Harvest — ripe, 2 days before it spoils", "just ripe")
	assert_equal(panel.needs_colour(), Palette.INK, "in its grace: not a warning")
	sim.advance_usec(50 * HOUR_USEC)
	panel.refresh()
	assert_equal(panel.needs_text(), "Needs: Harvest — spoiling, withers in 70 h", "past the grace")
	assert_equal(panel.needs_colour(), Palette.CLAY, "a warning")
	sim.farming().apply_health_loss(sim.slot_of(BED_WHEAT), 10000)
	panel.show_bed(BED_WHEAT)
	assert_equal(panel.needs_text(), "Needs: Clear — withered, gives compost", "withered")


func test_the_needs_line_calls_for_straw_when_a_frost_is_announced() -> void:
	"""Wheat sown on spring 1: at 11:00 of spring 10 nothing; at 12:00 Cover; covered, or raised,
	nothing; the panel without a bed shows no Needs line at all."""
	var sim := SimScript.new()
	_sow(sim, BED_CLAY, WHEAT)
	_sow(sim, BED_CLAY_2, WHEAT)
	var panel := _panel_on(sim)
	sim.advance_usec((SPRING_10_NOON_H - 1) * HOUR_USEC)
	panel.show_bed(BED_CLAY)
	assert_equal(panel.needs_text(), "", "not announced yet")
	sim.advance_usec(HOUR_USEC)
	panel.refresh()
	assert_equal(panel.needs_text(), "Needs: Cover — frost tonight", "frost tonight")
	sim.cover(BED_CLAY)
	panel.refresh()
	assert_equal(panel.needs_text(), "", "covered")
	sim.raise_bed(BED_CLAY_2)
	panel.show_bed(BED_CLAY_2)
	assert_equal(panel.needs_text(), "", "raised: frost-free")
	panel.show_nothing()
	assert_equal(panel.needs_text(), "", "no bed, no needs")


func test_the_bed_panel_s_drain_button() -> void:
	"""Disabled on a good bed with the reason in words; enabled on a waterlogged one, and pressing it
	asks for the Drain job."""
	var sim := SimScript.new()
	var panel := _panel_on(sim)
	panel.show_bed(BED_RADISH)
	var drain: Button = panel.verb_button(JobsScript.KIND_DRAIN)
	assert_equal(drain.text, "Drain", "labelled")
	assert_true(drain.disabled, "a good bed")
	assert_true(drain.tooltip_text.contains("Can't now: the bed is not too wet"), "why: its action card (decision 0332)")
	_set_moisture(sim, BED_RADISH, 9800)
	panel.refresh()
	assert_false(drain.disabled, "waterlogged: drain it")
	var asked: Array = []
	panel.verb_requested.connect(func(kind: int) -> void: asked.append(kind))
	drain.pressed.emit()
	assert_equal(asked, [JobsScript.KIND_DRAIN], "the Drain job asked for")


func test_the_bed_panel_s_close_clears_the_farm_s_bed() -> void:
	"""The × emits close_requested; the farm answers it by clearing the selected bed."""
	var farm := _farm()
	farm.select_bed(BED_RADISH)
	var closed: Array = [0]
	farm.bed_panel.close_requested.connect(func() -> void: closed[0] += 1)
	var close: Button = null
	for node: Node in farm.bed_panel.find_children("*", "Button", true, false):
		if (node as Button).text == "×":
			close = node as Button
	close.pressed.emit()
	assert_equal(closed[0], 1, "close_requested")
	assert_equal(farm.selected_bed, DemoFarmScript.NO_BED, "no bed selected")
	assert_equal(farm.bed_panel.bed, -1, "the panel shows no bed")


func test_the_words_for_a_ditch_and_a_span_of_hours() -> void:
	"""A ditched bed's ground says so; hours read as whole days when whole."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_RADISH, 9800)
	sim.drain_bed(BED_RADISH)
	assert_equal(Text.works_line(sim, BED_RADISH), "Ground: ditched", "ditched")
	sim.raise_bed(BED_RADISH)
	assert_equal(Text.works_line(sim, BED_RADISH), "Ground: ditched, raised", "and raised")
	assert_equal(Text.span_text(48), "2 days", "two days")
	assert_equal(Text.span_text(24), "1 day", "one day")
	assert_equal(Text.span_text(47), "47 h", "hours")
	assert_equal(Text.span_text(70), "70 h", "not whole days")
	assert_equal(Text._stall_reason(SimScript.BAND_GOOD), "too cold", "moisture fine: the cold stopped it")
	assert_equal(Text.needs_line(sim, BED_LOAM, _read), "", "an empty bed needs nothing")


func test_the_pantry_panel_breaks_the_food_out_by_item() -> void:
	"""Stocks: a row per ingredient per store (with a fixture cellar) and each store as a row; Recipe
	ideas: the picked ingredient's dishes (decision 0292)."""
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
	assert_equal(panel.stock_row_count(), 1, "one row: the carrots in the cellar")
	assert_equal(panel.shown_stock_row(0), PackedStringArray(["Carrot", "5.1 U", "—", "Root cellar", "all in 22d 23h"]),
		"carrots: 281 spring hours at ×0.35, then 270 at summer's ×0.525 = 551 h")
	assert_equal(panel.store_row_cells(0), PackedStringArray(["Covered store", "0 U", "0 U", "400.0 U", "400.0 U", "×1.00"]), "store")
	assert_equal(panel.store_row_cells(1), PackedStringArray(["Root cellar", "5.1 U", "0 U", "54.9 U", "60.0 U", "×0.35"]), "cellar")
	panel.show_tab(PantryPanelScript.TAB_RECIPES)
	panel.select_item(CARROT)
	assert_equal(panel.dish_title(), "Carrot feeds 109 dishes (and 15 more through prepared parts)", "dishes")
	assert_equal(panel.item_button(CARROT).text, "Carrot · 5.1 U in store", "its stock on its button")
	assert_equal(panel.item_button(RADISH).text, "Radish · none in store", "none")
	assert_true(panel.total_text().begins_with("5.1 U of food in store"), "total")
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


func test_a_long_step_ages_each_hour_at_its_own_season() -> void:
	"""Decision 0222: a step crossing many hours -- spring's first morning to summer's first hour, in one
	call -- ages the pantry hour by hour at each crossing's season (281 spring hours at ×1.0, then one
	summer hour at ×1.5), the very sum the Pantry's forecast counts on."""
	var farm := _farm()
	assert_true(farm.pantry.add_into(WHEAT, 1000, 0, _read), "wheat in store")
	var lot: int = _read.value
	assert_equal(farm.advance_calendar(282 * HOUR_USEC), 282, "282 hours crossed")
	assert_equal(farm.sim.calendar.hour_index(), 288, "summer's first hour")
	assert_equal(farm.pantry.lot_age(lot), 282500, "281 h at 1000 and 1 h at 1500")


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
	"""Wheat sown on spring 1: at 11:00 of spring 10 nothing is announced and it is watered; from 12:00
	(frost tonight) it is covered; a parched one is watered first; a raised one needs no straw."""
	var farm := _farm()
	_sow(farm.sim, BED_CLAY, WHEAT)
	_sow(farm.sim, BED_CLAY_2, WHEAT)
	farm.sim.advance_usec((SPRING_10_NOON_H - 1) * HOUR_USEC)
	assert_true(farm.pressing_kind_into(BED_CLAY, _read), "11:00")
	assert_equal(_read.value, JobsScript.KIND_WATER, "not announced yet: tend it")
	farm.sim.advance_usec(HOUR_USEC)
	_set_moisture(farm.sim, BED_CLAY_2, 0)
	assert_true(farm.pressing_kind_into(BED_CLAY, _read), "wheat")
	assert_equal(_read.value, JobsScript.KIND_COVER, "cover")
	assert_true(farm.pressing_kind_into(BED_CLAY_2, _read), "parched wheat")
	assert_equal(_read.value, JobsScript.KIND_WATER, "water first")
	farm.sim.raise_bed(BED_CLAY)
	assert_true(farm.pressing_kind_into(BED_CLAY, _read), "raised wheat")
	assert_equal(_read.value, JobsScript.KIND_WATER, "a raised bed is frost-free: no straw")


func test_a_waterlogged_bed_s_most_pressing_work_is_drain() -> void:
	"""The growing radish waterlogged: Drain (before watering); a waterlogged ripe bed is harvested
	first; a blighted waterlogged one cleared first."""
	var farm := _farm()
	_set_moisture(farm.sim, BED_RADISH, 9800)
	assert_true(farm.pressing_kind_into(BED_RADISH, _read), "radish")
	assert_equal(_read.value, JobsScript.KIND_DRAIN, "drain it")
	farm.sim.advance_usec(24 * HOUR_USEC)
	_set_moisture(farm.sim, BED_CARROTS, 10000)
	assert_true(farm.pressing_kind_into(BED_CARROTS, _read), "ripe carrots")
	assert_equal(_read.value, JobsScript.KIND_HARVEST, "harvest first")
	farm.sim.infect_for_test(BED_RADISH)
	_set_moisture(farm.sim, BED_RADISH, 9800)
	assert_true(farm.pressing_kind_into(BED_RADISH, _read), "blighted radish")
	assert_equal(_read.value, JobsScript.KIND_CLEAR, "clear the blight first")


func test_a_farm_hour_ages_the_pantry_and_reads_the_tunnels() -> void:
	"""A step of one farm hour ages every lot 1000 milli-hours and marks beds a finished tunnel runs
	under as drained."""
	var farm := _farm()
	farm.pantry.add_into(CARROT, 1000, 0, _read)
	var network: GraphScript = farm._cast.space().tunnels
	# 8 m along z 12.8 (the shortest tunnel: two 4 m ramps), under both roots beds (x -12.6 and -9.4).
	_dig_tunnel(network, Vector2(-6.9, 12.8), Vector2(-14.9, 12.8))
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
	"""V: moisture, ripeness, then a layer the village added (the water's range), then off -- each shown
	alone, so no two layers share the map (decision 0292: the same one active layer the picker shows)."""
	var farm := _farm()
	var water_shown: Array[bool] = []
	farm.add_overlay("Getting there", "Water range", "Where?", func(on: bool) -> void: water_shown.append(on))
	var names: Array[String] = []
	for press: int in 4:
		names.append(farm.cycle_overlays())
	assert_equal(names, ["Growing: Soil moisture", "Growing: Ripeness", "Getting there: Water range", "Off"] as Array[String],
		"the cycle")
	assert_equal(water_shown, [false, false, true, false] as Array[bool], "the water shown only on its step")
	assert_equal(farm.view.overlay_mode, ViewScript.OVERLAY_OFF, "and the farm's off again")


func test_planting_from_the_picker_orders_the_sowing() -> void:
	"""The picker's choice is chosen and its sowing queued for the crew (nobody selected)."""
	var farm := _farm()
	farm.select_bed(BED_LOAM)
	assert_equal(farm.plant(WHEAT), "Sow queued: the field crew will see to it", "queued")
	assert_equal(farm.sim.chosen_of(BED_LOAM), WHEAT, "chosen")
	assert_true(farm.crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, BED_LOAM, _read), "on the board")


func test_the_pantry_close_button_closes_it_and_is_drawn_above_the_hud() -> void:
	"""Playtest 2026-09-29: at 1280x720 the HUD's time cluster lay over the pantry's "×" and ate the
	click. The pantry is drawn above the HUD's layer now, and its "×", pressed, closes it."""
	var farm := _farm()
	farm.toggle_pantry()
	assert_true(farm.pantry_panel.visible, "open")
	var close: Button = farm.pantry_panel.close_button()
	assert_equal(close.text, "×", "the header's ×")
	close.pressed.emit()
	assert_false(farm.pantry_panel.visible, "the × closed it")
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var hud_layer: int = hud.layer
	hud.free()
	assert_true(farm.pantry_panel.layer > hud_layer, "drawn (and clicked) above the HUD's layer %d" % hud_layer)


func test_a_farm_job_called_away_is_taken_back_when_the_other_work_is_done() -> void:
	"""Decision 0205 (resident_brain.gd RESUMING): a worker ordered away mid-job leaves it on the board
	and keeps it; its next work done gives the same job back to it, not to the crew. A job someone else
	took meanwhile, or one closed, is not taken back."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_set_moisture(sim, BED_RADISH, 9800)
	crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	var walking := func() -> bool: return _brain(cast, 1).order == BrainScript.ORDER_MOVE
	assert_true(_run(cast, crew, 5.0, walking), "on its way")
	_brain(cast, 1).order_move(Vector2(-6.0, -6.0))
	_run(cast, crew, 0.1, func() -> bool: return false)
	assert_true(_notices.has("Placeholder 1 left the drain job"), "left it")
	assert_equal(_brain(cast, 1).unfinished_labels(), PackedStringArray(["Drain, bed %d" % (BED_RADISH + 1)]), "kept")
	_brain(cast, 1).work_done()
	assert_equal(crew.task_text(1), "Draining the radish bed", "back on the drain")
	var ditched := func() -> bool: return sim.is_ditched(BED_RADISH)
	assert_true(_run(cast, crew, 90.0, ditched), "and it finished it")
	_set_moisture(sim, BED_RADISH, 1500)
	assert_equal(crew.order(JobsScript.KIND_WATER, BED_RADISH, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER),
		"Water: Placeholder 2 is on it", "a second job")
	_run(cast, crew, 1.0, func() -> bool: return false)
	_brain(cast, 2).order_move(Vector2(6.0, -6.0))
	_run(cast, crew, 0.1, func() -> bool: return false)
	crew.cancel_bed(BED_RADISH)
	_brain(cast, 2).work_done()
	assert_equal(crew.task_text(2), "", "a cancelled job is not taken back")
	assert_equal(_brain(cast, 2).order, BrainScript.ORDER_NONE, "so it goes back to its routine")


func test_a_farm_job_given_to_another_is_not_taken_back_and_r_forgets() -> void:
	"""Decision 0205 with review H2: a job someone else took meanwhile is theirs; and a worker the player
	releases (R) mid-job keeps nothing -- the crew notices a frame later and must not keep it for it."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	_set_moisture(sim, BED_RADISH, 9800)
	crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	_run(cast, crew, 1.0, func() -> bool: return false)
	_brain(cast, 1).order_move(Vector2(-6.0, -6.0))
	_run(cast, crew, 0.1, func() -> bool: return false)
	crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([2]), JobsScript.ORIGIN_PLAYER)
	assert_equal(crew.task_text(2), "Draining the radish bed", "given to another")
	_brain(cast, 1).work_done()
	assert_equal(crew.task_text(1), "", "not taken back from it")
	assert_equal(crew.task_text(2), "Draining the radish bed", "it keeps it")
	assert_true(_run(cast, crew, 5.0, func() -> bool: return _brain(cast, 2).order == BrainScript.ORDER_MOVE), "walking to it")
	_brain(cast, 2).release()
	_run(cast, crew, 0.1, func() -> bool: return false)
	assert_equal(crew.task_text(2), "", "the crew saw it go")
	assert_equal(_brain(cast, 2).unfinished_labels().size(), 0, "released: nothing kept")


func test_a_farm_job_done_takes_up_the_job_it_interrupted() -> void:
	"""A crew ending its job calls work_done: the worker goes back to the job the farm took it from."""
	var cast := _cast()
	var sim := SimScript.new()
	var crew := _crew(cast, sim, _pantry(cast))
	var resumed: Array[int] = [0]
	_brain(cast, 1).remember_unfinished(UnfinishedScript.new(func(_b: RefCounted) -> bool:
		resumed[0] += 1
		return true, "lanterns"))
	_set_moisture(sim, BED_RADISH, 9800)
	crew.order(JobsScript.KIND_DRAIN, BED_RADISH, PackedInt32Array([1]), JobsScript.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, func() -> bool: return sim.is_ditched(BED_RADISH)), "drained")
	assert_equal(resumed[0], 1, "then back to the lanterns")
