extends "res://test/framework/test_case.gd"
## The village's work board (decision 0411; review F22, F32, F44's remainder, SOC-004, UX-001/002/007): the claim of
## waiting work by idle eligible residents, the named crews, the player's per-task commands and priorities, the order
## lists, and the same outcome at 1x, 2x and 4x. Every test runs the real owners -- the farm crew, the woods, the water's
## bridges -- on the placeholder cast in the real village layout, stepped in the live order (the cast, then the farm,
## the woods, the water, then the board), and asserts where residents end up, who owns each job and what was credited.
## No staged assets.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const RescueTasks := preload("res://demo/waterplay/rescue_tasks.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const LinksScript := preload("res://demo/waterplay/water_links.gd")
const WaterPlayTest := preload("res://test/test_demo_water_play.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const TaskScript := preload("res://demo/work/work_task.gd")
const OrderList := preload("res://demo/work/order_list.gd")
const FarmWork := preload("res://demo/work/farm_work.gd")
const WoodsWork := preload("res://demo/work/woods_work.gd")
const BridgeWork := preload("res://demo/work/bridge_work.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const SourceScript := preload("res://demo/work/work_source.gd")

const DT: float = 0.1
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const BED_CARROTS: int = 2
const CARROT: int = 2
const CARROT_YIELD: int = 5100
const WOOD: int = 60
const WEST_OAK: int = 33
const NORTH_OAK: int = 32

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _borrowed: WaterPlayTest = null
## Every rig a test built: its farm crew holds a lambda that holds the rig, a cycle after_each breaks.
var _rigs: Array[Rig] = []


## The whole rig: one cast in the village layout, the farm crew, the woods and the water over it, and the board.
class Rig:
	var cast: DemoCastScript = null
	var sim: SimScript = null
	var pantry: PantryScript = null
	var farm: FarmCrewScript = null
	var forestry: ForestryScript = null
	var play: WaterplayScript = null
	var board: BoardScript = null
	var notices: PackedStringArray = PackedStringArray()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()
	_borrowed = WaterPlayTest.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()
	for rig: Rig in _rigs:
		rig.farm = null
		rig.board = null
	_rigs.clear()
	_borrowed = null


# --- fixtures -----------------------------------------------------------------------------------------

func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _rig(manager: GameManagerScript = null) -> Rig:
	"""The placeholder cast in the village layout, walking round the water's band, with the farm (the carrot bed
	ripe), the woods and the water's bridges over it, and the work board claiming for all three (as demo_work.gd wires
	it). `manager`: the clock's speed source (none: 1x)."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links: LinksScript = WaterplayScript.make_links(WaterPlayTest._map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	_rigs.append(rig)
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	if manager != null:
		rig.cast.clock.bind(manager)
	rig.sim = SimScript.new()
	rig.sim.advance_usec(24 * HOUR_USEC)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.farm = FarmCrewScript.new()
	rig.farm.configure(rig.cast, rig.sim, rig.pantry, TunnelsScript.new(), DemoFarmScript.well_position(),
		func(text: String) -> void: rig.notices.append(text))
	rig.forestry = _keep(ForestryScript.new()) as ForestryScript
	rig.forestry.configure(world, rig.cast, null, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	rig.play = _keep(WaterplayScript.new()) as WaterplayScript
	rig.play.configure(rig.cast, null, null, _services, WaterPlayTest._map(), links)
	_bind_board(rig)
	return rig


func _bind_board(rig: Rig) -> void:
	"""The board over the rig's three owners, their routine hand-outs stood down."""
	rig.board = BoardScript.new()
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in rig.cast.actor_count():
		var actor := rig.cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		keys.append(actor.creature_key)
	rig.board.bind(brains, names, keys)
	rig.board.add_source(FarmWork.new(rig.farm))
	rig.board.add_source(WoodsWork.new(rig.forestry.crew))
	rig.board.add_source(BridgeWork.new(rig.play.crew, rig.play.bridges))
	rig.farm.set_claimer(rig.board.queue_words)
	rig.forestry.crew.set_claimer(rig.board.queue_words)
	rig.play.crew.set_claimer()


func _crews(rig: Rig, of: PackedInt32Array) -> void:
	"""Put resident k on crew of[k]."""
	for who: int in of.size():
		rig.board.crews.set_crew(who, of[who])


func _frame(rig: Rig) -> void:
	"""One frame in the live order: the cast, the farm, the woods, the water, the board."""
	rig.cast.advance(DT)
	var usec: int = rig.cast.clock.frame_usec
	rig.farm.update(usec)
	rig.forestry.step(usec)
	rig.play.step(usec)
	rig.board.update(usec)


func _run(rig: Rig, seconds: float, done: Callable, each: Callable = Callable()) -> bool:
	"""Frames until `done()` or `seconds` of real time pass; `each()` after every frame."""
	for f: int in roundi(seconds / DT):
		if bool(done.call()):
			return true
		_frame(rig)
		if each.is_valid():
			each.call()
	return bool(done.call())


func _brain(rig: Rig, who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (rig.cast.actor(who) as DemoActorScript).brain


func _farm_row(rig: Rig, kind: int, bed: int) -> int:
	"""The farm job of `kind` on `bed` (-1: none)."""
	return _read.value if rig.farm.jobs.job_on_bed_into(kind, bed, _read) else -1


func _woods_row(rig: Rig, kind: int, target: int) -> int:
	"""The woods job of `kind` on `target` (-1: none)."""
	return _read.value if rig.forestry.crew.jobs.find_into(kind, target, _read) else -1


func _second_farm_task(rig: Rig) -> Vector2i:
	"""A second farm job the board may hand out now, on another bed: (kind, bed)."""
	for bed: int in Catalog.BED_COUNT:
		if bed == BED_CARROTS:
			continue
		for kind: int in [FarmJobs.KIND_WATER, FarmJobs.KIND_COVER, FarmJobs.KIND_CLEAR, FarmJobs.KIND_COMPOST]:
			if FarmJobs.refusal_for(rig.sim, kind, bed, 0) == &"":
				return Vector2i(kind, bed)
	return Vector2i(-1, -1)


func _plank_bridge(rig: Rig) -> void:
	"""A footbridge planned at the first site, paid from planks put in the stores, nobody selected."""
	_services.stores.add_planks(20000)
	rig.play.select_candidate(0)
	var said: String = rig.play.build(SwimRules.KIND_PLANK, PackedInt32Array())
	assert_true(rig.play.bridges.is_planned(0), "the bridge planned: %s" % said)


func _carrots(rig: Rig) -> int:
	"""Carrots standing, carried and stored."""
	var standing: int = 0
	if rig.sim.stage_of(BED_CARROTS) == SimScript.STAGE_RIPE and rig.sim.expected_yield_into(BED_CARROTS, _read):
		standing = _read.value
	var carried: int = 0
	for row: int in FarmJobs.MAX_JOBS:
		if rig.farm.jobs.is_live(row) and rig.farm.jobs.load_item[row] == CARROT:
			carried += rig.farm.jobs.load_milli[row]
	return standing + carried + rig.pantry.milli_of(CARROT)


# --- THE CLAIM: queued work goes to the right eligible residents ----------------------------------------

func test_six_queued_tasks_with_nobody_selected_go_to_the_right_eligible_residents() -> void:
	"""Two farm, three woods and a bridge job, all ordered with nobody selected. The board hands every one out within
	the claim period, each to a resident whose crew prefers it: the Field crew both farm jobs, the Woods crew felling
	and sawing, the Builders the bridge, the Haulers the haul. Nobody wanders while eligible work waits."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([CrewsScript.CREW_FIELD, CrewsScript.CREW_FIELD, CrewsScript.CREW_WOODS,
		CrewsScript.CREW_WOODS, CrewsScript.CREW_BUILDERS, CrewsScript.CREW_HAULERS]))
	var second := _second_farm_task(rig)
	assert_true(second.x >= 0, "a second farm job to queue")
	var none := PackedInt32Array()
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, none, FarmJobs.ORIGIN_PLAYER)
	rig.farm.order(second.x, second.y, none, FarmJobs.ORIGIN_PLAYER)
	rig.forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	rig.forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, none)
	rig.forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, none, ForestJobs.ORIGIN_PLAYER)
	rig.forestry.order_on(PickScript.KIND_SAW, -1, none)
	_plank_bridge(rig)
	var rows: Array[Vector2i] = [Vector2i(WorkIds.SOURCE_FARM, _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)),
		Vector2i(WorkIds.SOURCE_FARM, _farm_row(rig, second.x, second.y)),
		Vector2i(WorkIds.SOURCE_WOODS, _woods_row(rig, ForestJobs.KIND_HAUL, WEST_OAK)),
		Vector2i(WorkIds.SOURCE_WOODS, _woods_row(rig, ForestJobs.KIND_FELL, NORTH_OAK)),
		Vector2i(WorkIds.SOURCE_WOODS, _woods_row(rig, ForestJobs.KIND_SAW, ForestJobs.NO_TARGET)),
		Vector2i(WorkIds.SOURCE_BRIDGES, 0)]
	var claimed := func() -> bool:
		for task: Vector2i in rows:
			if rig.board.source(task.x).worker(task.y) < 0:
				return false
		return true
	assert_true(_run(rig, 1.0, claimed), "all six claimed within a claim period")
	var who := PackedInt32Array()
	for task: Vector2i in rows:
		who.append(rig.board.source(task.x).worker(task.y))
	assert_equal([who[0] in [0, 1], who[1] in [0, 1], who[0] != who[1]], [true, true, true], "the Field crew farms: %s" % who)
	assert_equal(who[2], 5, "the Hauler hauls")
	assert_equal([who[3] in [2, 3], who[4] in [2, 3], who[3] != who[4]], [true, true, true], "the Woods crew fells and saws")
	assert_equal(who[5], 4, "the Builder builds the bridge")
	assert_equal(rig.board.claims, 6, "six claims")


func test_an_idle_resident_takes_any_eligible_work_its_crew_allows() -> void:
	"""Everybody on the Field crew and only a woods job waiting: it is still taken (woods is a fallback) -- nobody
	wanders while eligible work waits. With the crew's woods priority FORBIDDEN, the next woods job waits."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var none := PackedInt32Array()
	rig.forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, none, ForestJobs.ORIGIN_PLAYER)
	var fell: int = _woods_row(rig, ForestJobs.KIND_FELL, NORTH_OAK)
	assert_true(_run(rig, 1.0, func() -> bool: return rig.forestry.crew.jobs.worker[fell] >= 0), "taken by a Field member")
	assert_true(rig.board.crews.set_priority(CrewsScript.CREW_FIELD, WorkIds.ACT_WOODS, WorkIds.PRIORITY_FORBIDDEN),
		"woods forbidden to the Field crew")
	rig.forestry.order_on(PickScript.KIND_SAW, -1, none)
	var saw: int = _woods_row(rig, ForestJobs.KIND_SAW, ForestJobs.NO_TARGET)
	_run(rig, 2.0, func() -> bool: return false)
	assert_equal(rig.forestry.crew.jobs.worker[saw], ForestJobs.NOBODY, "forbidden: nobody takes it")
	assert_equal(rig.board.crews.preset, CrewsScript.PRESET_CUSTOM, "a deviation from the preset")
	rig.board.crews.apply_preset(CrewsScript.PRESET_NORMAL)
	assert_true(_run(rig, 1.0, func() -> bool: return rig.forestry.crew.jobs.worker[saw] >= 0), "allowed again: taken")


func test_safety_rest_and_needs_come_before_work() -> void:
	"""A resident the night routine has in bed, one the water's rescue holds and one whose needs come first (the
	meals' gate) are never given work; the one left free takes it."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	for who: int in 6:
		_brain(rig, who).resting = who != 3
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	_brain(rig, 3).water_hold = true
	_run(rig, 1.5, func() -> bool: return false)
	assert_equal(rig.farm.jobs.worker[row], FarmJobs.NOBODY, "resting and held: nobody taken")
	_brain(rig, 3).water_hold = false
	rig.board.set_needs_gate(func(who: int) -> bool: return who == 3)
	_run(rig, 1.5, func() -> bool: return false)
	assert_equal(rig.farm.jobs.worker[row], FarmJobs.NOBODY, "its needs first: not taken")
	rig.board.set_needs_gate(Callable())
	assert_true(_run(rig, 1.0, func() -> bool: return rig.farm.jobs.worker[row] == 3), "free: it takes the harvest")
	for who: int in 6:
		_brain(rig, who).resting = false


func test_a_rescue_interrupts_hauling_and_the_haul_resumes_exactly_once() -> void:
	"""A swimmer hauling logs is sent to a resident in difficulty in the stream: it leaves the haul (the load kept with
	the job, promised to it on its order list, nobody else taking it), rescues, and takes the haul back up exactly once.
	Wood is conserved throughout and every load reaches the log stack."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([3, 3, 3, 3, 3, 3]))
	rig.play.state.swim_mm_s[2] = 1100
	rig.forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	var total: int = _services.stores.wood_milli_u + rig.forestry.stand.trunk_milli[WEST_OAK]
	rig.forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([2]))
	var jobs: ForestJobs = rig.forestry.crew.jobs
	var row: int = _woods_row(rig, ForestJobs.KIND_HAUL, WEST_OAK)
	var serial: int = jobs.serial[row]
	assert_true(_run(rig, 120.0, func() -> bool: return jobs.load_milli[row] > 0 and jobs.issued[row] == 1), "hauling")
	var victim := _brain(rig, 0)
	victim.water_place(WaterPlayTest.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var hauler := _brain(rig, 2)
	assert_true(hauler.task is RescueTasks.SwimRescue, "the swimmer goes to the rescue")
	_frame(rig)
	assert_equal(jobs.worker[row], ForestJobs.NOBODY, "the haul waits")
	assert_true(hauler.promises(WorkIds.SOURCE_WOODS, serial), "promised to the hauler")
	var watch := {"taken": 0, "others": false, "was": ForestJobs.NOBODY, "conserved": true}
	var conserve := func() -> void:
		var live: bool = jobs.is_live(row) and jobs.serial[row] == serial
		var now: int = jobs.worker[row] if live else ForestJobs.NOBODY
		if now != watch["was"] and now == 2:
			watch["taken"] = int(watch["taken"]) + 1
		watch["others"] = bool(watch["others"]) or (now >= 0 and now != 2)
		watch["was"] = now
		var carried: int = 0
		for r: int in ForestJobs.MAX_JOBS:
			carried += jobs.load_milli[r] if jobs.is_live(r) else 0
		watch["conserved"] = bool(watch["conserved"]) and _services.stores.wood_milli_u \
			+ rig.forestry.stand.trunk_milli[WEST_OAK] + carried == total
	assert_true(_run(rig, 300.0, func() -> bool: return not (jobs.is_live(row) and jobs.serial[row] == serial), conserve),
		"the rescue done and the haul finished")
	assert_equal(rig.play.rescue.rescued, 1, "one rescue")
	assert_equal(watch["taken"], 1, "the haul taken back up exactly once")
	assert_false(watch["others"], "nobody else took the promised haul")
	assert_true(watch["conserved"], "wood conserved every frame")
	assert_equal(_services.stores.wood_milli_u, total, "every load stacked")
	assert_equal(hauler.queue_size(), 0, "nothing left on its list")


# --- the player's commands at every phase ----------------------------------------------------------------

func _harvest_to(rig: Rig, who: int) -> int:
	"""The carrot harvest ordered to `who`; its row."""
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([who]), FarmJobs.ORIGIN_PLAYER)
	return _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)


func _watch_store(rig: Rig, seen: Dictionary) -> void:
	"""Each frame: conservation, and a credit to the store only by a carrier standing there."""
	var stored: int = rig.pantry.milli_of(CARROT)
	if stored != int(seen["stored"]):
		var at_store: bool = false
		for who: int in rig.cast.actor_count():
			at_store = at_store or _brain(rig, who).position.distance_to(DemoFarmScript.store_position(rig.cast)) < 3.0
		seen["remote"] = bool(seen["remote"]) or not at_store
		seen["credits"] = int(seen["credits"]) + 1
		seen["stored"] = stored
	seen["conserved"] = bool(seen["conserved"]) and _carrots(rig) == CARROT_YIELD


func test_a_harvest_reassigned_at_each_phase_is_stored_once_by_its_carrier() -> void:
	"""The carrot harvest, given to resident 3, is reassigned while queued, while travelling and while being cut (the
	work done kept: GDD §5.3 "changing workers retains progress"); with the crop in hand Reassign and Pause are refused
	in words (no load changes hands from afar). It is stored once, all of it, by the carrier at the store."""
	var rig := _rig()
	var row: int = _harvest_to(rig, 3)
	var seen := {"stored": 0, "remote": false, "credits": 0, "conserved": true}
	var watch := func() -> void: _watch_store(rig, seen)
	assert_equal(rig.board.reassign(WorkIds.SOURCE_FARM, row, 4), "", "reassigned before it set off")
	assert_equal(rig.farm.jobs.worker[row], 4, "now resident 4's")
	assert_true(_run(rig, 5.0, func() -> bool: return _brain(rig, 4).state == BrainScript.State.WALK, watch), "travelling")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_FARM, row, 5), "", "reassigned while travelling")
	assert_equal([rig.farm.jobs.worker[row], _brain(rig, 4).order], [5, BrainScript.ORDER_NONE], "4 let go, 5 on it")
	var cutting := func() -> bool: return rig.farm.jobs.current_step(row) == FarmJobs.STEP_WORK + FarmJobs.WORK_HARVEST \
		and rig.farm.jobs.elapsed_usec[row] > 0
	assert_true(_run(rig, 90.0, cutting, watch), "being cut")
	var done_before: int = rig.farm.jobs.elapsed_usec[row]
	assert_equal(rig.board.reassign(WorkIds.SOURCE_FARM, row, 1), "", "reassigned while being cut")
	assert_true(rig.farm.jobs.elapsed_usec[row] >= done_before, "the work done kept with the job")
	var carrying := func() -> bool: return rig.farm.holds_load(row)
	assert_true(_run(rig, 120.0, carrying, watch), "cut and carried by resident 1")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_FARM, row, 4), WorkIds.CARRYING % _name(rig, 1), "refused in hand")
	assert_equal(rig.board.pause(WorkIds.SOURCE_FARM, row, true), WorkIds.CARRYING % _name(rig, 1), "pause refused too")
	assert_true(_run(rig, 120.0, func() -> bool: return not rig.farm.jobs.is_live(row), watch), "stored")
	assert_equal(rig.pantry.milli_of(CARROT), CARROT_YIELD, "all of it")
	assert_equal([seen["credits"], seen["remote"], seen["conserved"]], [1, false, true], "once, at the store, conserved")


func test_a_harvest_cancelled_in_hand_is_delivered_by_its_carrier_not_credited_at_the_cancel() -> void:
	"""Cancel this task with the crop in hand: decision 0222's rule -- it becomes its delivery, carried on and credited
	at the store; a second Cancel is refused (a delivery always finishes). Cancelled before the cut: nothing is cut."""
	var rig := _rig()
	var row: int = _harvest_to(rig, 3)
	var seen := {"stored": 0, "remote": false, "credits": 0, "conserved": true}
	var watch := func() -> void: _watch_store(rig, seen)
	assert_true(_run(rig, 120.0, func() -> bool: return rig.farm.holds_load(row), watch), "carrying")
	assert_equal(rig.board.cancel(WorkIds.SOURCE_FARM, row), "", "cancelled")
	assert_equal(rig.pantry.milli_of(CARROT), 0, "nothing at the cancel")
	assert_equal(rig.farm.jobs.kind[row], FarmJobs.KIND_DELIVER, "now its delivery")
	assert_equal(rig.board.cancel(WorkIds.SOURCE_FARM, row), WorkIds.DELIVERY_GOES_ON, "a delivery goes on")
	assert_true(_run(rig, 120.0, func() -> bool: return not rig.farm.jobs.is_live(row), watch), "delivered")
	assert_equal([rig.pantry.milli_of(CARROT), seen["credits"], seen["remote"]], [CARROT_YIELD, 1, false], "once, there")
	var other := _rig()
	var before: int = _harvest_to(other, 3)
	assert_true(_run(other, 5.0, func() -> bool: return _brain(other, 3).state == BrainScript.State.WALK), "on its way")
	assert_equal(other.board.cancel(WorkIds.SOURCE_FARM, before), "", "cancelled before the cut")
	_run(other, 5.0, func() -> bool: return false)
	assert_equal([other.sim.stage_of(BED_CARROTS), _brain(other, 3).order], [SimScript.STAGE_RIPE, BrainScript.ORDER_NONE],
		"the crop stands, the worker let go")


func test_a_haul_reassigned_paused_and_cancelled_at_each_phase_conserves_its_wood() -> void:
	"""The woods: a haul paused while its hauler walks to the trunk (let go; nobody claims it while paused), resumed and
	reassigned; with logs in hand Reassign and Pause are refused, Cancel makes it a delivery to the log stack. Wood is
	conserved every frame and reaches the stores only at the stack."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([3, 3, 3, 3, 3, 3]))
	rig.forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	var jobs: ForestJobs = rig.forestry.crew.jobs
	var total: int = _services.stores.wood_milli_u + rig.forestry.stand.trunk_milli[WEST_OAK]
	rig.forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([2]))
	var row: int = _woods_row(rig, ForestJobs.KIND_HAUL, WEST_OAK)
	var seen := {"conserved": true, "remote": false, "stores": _services.stores.wood_milli_u}
	var watch := func() -> void:
		var carried: int = 0
		for r: int in ForestJobs.MAX_JOBS:
			carried += jobs.load_milli[r] if jobs.is_live(r) else 0
		seen["conserved"] = bool(seen["conserved"]) and _services.stores.wood_milli_u + rig.forestry.stand.trunk_milli[WEST_OAK] \
			+ carried == total
		if _services.stores.wood_milli_u != int(seen["stores"]):
			var near: bool = false
			for who: int in rig.cast.actor_count():
				near = near or _brain(rig, who).position.distance_to(Yard.log_stack_at()) < 4.0
			seen["remote"] = bool(seen["remote"]) or not near
			seen["stores"] = _services.stores.wood_milli_u
	_frame(rig)
	assert_equal(rig.board.pause(WorkIds.SOURCE_WOODS, row, true), "", "paused on the way")
	assert_equal([jobs.worker[row], _brain(rig, 2).order], [ForestJobs.NOBODY, BrainScript.ORDER_NONE], "its hauler let go")
	_run(rig, 2.0, func() -> bool: return false, watch)
	assert_equal(jobs.worker[row], ForestJobs.NOBODY, "paused: nobody claims it")
	assert_equal(rig.board.pause(WorkIds.SOURCE_WOODS, row, false), "", "resumed")
	assert_true(_run(rig, 1.0, func() -> bool: return jobs.worker[row] >= 0, watch), "claimed again")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_WOODS, row, 4), "", "reassigned before the load")
	assert_true(_run(rig, 120.0, func() -> bool: return jobs.load_milli[row] > 0, watch), "logs in hand")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_WOODS, row, 5), WorkIds.CARRYING % _name(rig, 4), "refused in hand")
	assert_equal(rig.board.pause(WorkIds.SOURCE_WOODS, row, true), WorkIds.CARRYING % _name(rig, 4), "not paused in hand")
	assert_equal(rig.board.cancel(WorkIds.SOURCE_WOODS, row), "", "cancelled: a delivery now")
	assert_true(jobs.is_delivery(row), "carried on to the stack")
	assert_true(_run(rig, 120.0, func() -> bool: return not jobs.is_live(row), watch), "stacked")
	assert_equal([seen["conserved"], seen["remote"]], [true, false], "conserved, credited only at the stack")


func test_a_bridge_reassigned_while_its_material_is_carried_is_built_once() -> void:
	"""The bridge's builder let go with the planks in its arms (reassigned): the material goes back to its source, the
	new builder fetches it, and the bridge is built once -- opened once, its work credited to 100%."""
	var rig := _rig()
	_plank_bridge(rig)
	var crew: BridgeCrewScript = rig.play.crew
	assert_equal(rig.board.reassign(WorkIds.SOURCE_BRIDGES, 0, 1), "", "given to resident 1")
	assert_true(_run(rig, 120.0, func() -> bool: return crew.step[0] == BridgeCrewScript.STEP_CARRY and crew.issued[0] == 1),
		"carrying the planks")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_BRIDGES, 0, 3), "", "reassigned in transit")
	assert_equal([crew.builder[0], crew.step[0]], [3, BridgeCrewScript.STEP_GO_SOURCE], "the new builder fetches it afresh")
	assert_equal(rig.board.cancel(WorkIds.SOURCE_BRIDGES, 0), BridgeWork.NO_CANCEL, "a bridge is not cancelled")
	assert_true(_run(rig, 600.0, func() -> bool: return rig.play.bridges.is_open(0)), "built")
	assert_equal(rig.play.bridges.percent(0), 100, "once, all of it")


# --- priority ---------------------------------------------------------------------------------------------

func test_urgent_and_priority_order_what_an_idle_resident_takes() -> void:
	"""Two farm jobs and one free Field resident: the one marked URGENT is taken first; without urgency, the one with
	the higher task priority; each task's priority is kept for its own job only."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 3, 3, 3, 3, 3]))
	for who: int in range(1, 6):
		_brain(rig, who).resting = true
	var second := _second_farm_task(rig)
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	rig.farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var harvest: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var other: int = _farm_row(rig, second.x, second.y)
	var far: int = harvest if _brain(rig, 0).position.distance_to(Catalog.bed_centre_m(BED_CARROTS)) \
		> _brain(rig, 0).position.distance_to(Catalog.bed_centre_m(second.y)) else other
	assert_true(rig.board.set_urgent(WorkIds.SOURCE_FARM, far, true), "the farther one urgent")
	assert_true(_run(rig, 1.0, func() -> bool: return rig.farm.jobs.worker[far] == 0), "the urgent one first")
	assert_equal(rig.farm.jobs.worker[harvest + other - far], FarmJobs.NOBODY, "the other waits")
	assert_true(rig.board.is_urgent(WorkIds.SOURCE_FARM, far), "kept while it is the same job")
	assert_true(rig.board.raise_priority(WorkIds.SOURCE_FARM, other, -1), "raised")
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_FARM, other), WorkIds.PRIORITY_HIGH, "high")
	assert_false(rig.board.set_task_priority(WorkIds.SOURCE_FARM, other, 9), "not a priority")
	for who: int in range(1, 6):
		_brain(rig, who).resting = false


func test_task_priority_breaks_ties_before_distance() -> void:
	"""Same crew priority, neither urgent: the task at HIGHEST is taken before a nearer one at NORMAL."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 3, 3, 3, 3, 3]))
	for who: int in range(1, 6):
		_brain(rig, who).resting = true
	var second := _second_farm_task(rig)
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	rig.farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var harvest: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var other: int = _farm_row(rig, second.x, second.y)
	var far: int = harvest if _brain(rig, 0).position.distance_to(Catalog.bed_centre_m(BED_CARROTS)) \
		> _brain(rig, 0).position.distance_to(Catalog.bed_centre_m(second.y)) else other
	assert_true(rig.board.set_task_priority(WorkIds.SOURCE_FARM, far, WorkIds.PRIORITY_HIGHEST), "the far one highest")
	assert_true(_run(rig, 1.0, func() -> bool: return rig.farm.jobs.worker[far] == 0), "taken first")
	for who: int in range(1, 6):
		_brain(rig, who).resting = false


# --- crews -----------------------------------------------------------------------------------------------

func test_crews_start_by_trade_and_the_player_edits_them() -> void:
	"""Each of the demo's nine starts on its trade's crew; a resident moved between crews, stepped round them; the
	presets' tables and previews; a member's status."""
	var crews := CrewsScript.new()
	var keys: Array[StringName] = [&"mouse_keeper", &"mouse_fieldworker", &"squirrel_gatherer", &"squirrel_forester",
		&"otter_boatwright", &"otter_fisher", &"mole_digger", &"badger_quarryman", &"beaver_bridgewright"]
	crews.setup(keys)
	assert_equal(crews.crew_of, PackedInt32Array([3, 0, 0, 1, 4, 3, 2, 2, 4]), "by trade")
	var members := PackedInt32Array()
	assert_equal(crews.members_into(CrewsScript.CREW_FIELD, members), 2, "two on the Field crew")
	assert_equal(members, PackedInt32Array([1, 2]), "the fieldworker and the gatherer")
	var revision: int = crews.revision
	assert_true(crews.set_crew(0, CrewsScript.CREW_WOODS), "moved")
	assert_true(crews.revision > revision, "a change is a revision")
	assert_equal(crews.priority_of(0, WorkIds.ACT_WOODS), WorkIds.PRIORITY_HIGHEST, "its new crew's priority")
	assert_true(crews.step_crew(0, -2), "stepped back two")
	assert_equal(crews.crew_of[0], CrewsScript.CREW_BUILDERS, "round the five")
	assert_false(crews.set_crew(0, 7), "no such crew")
	assert_false(crews.set_crew(12, 0), "no such resident")
	assert_equal(crews.priority_of(1, WorkIds.ACT_FARM), 1, "preferred")
	assert_equal(crews.priority_of(1, WorkIds.ACT_HAUL), 2, "first fallback")
	assert_equal(crews.priority_of(1, WorkIds.ACT_WOODS), 3, "second fallback")
	assert_equal(crews.priority_of(1, WorkIds.ACT_DIG), 4, "anything else, low")
	assert_equal(crews.describe(CrewsScript.CREW_FIELD), "prefers Farm; then Hauling, Woods", "in words")


func test_presets_preview_their_changes_and_apply_whole_tables() -> void:
	"""Harvest week raises farm work and hauling to at least HIGH for every crew; Winter stores raises woods and hauling
	and lowers farm work for all but the Field crew. Each is previewed as its changes before it is applied; Normal
	after an edit shows the edit undone."""
	var crews := CrewsScript.new()
	var lines: PackedStringArray = crews.preview_preset(CrewsScript.PRESET_HARVEST)
	assert_true(lines.size() > 0 and lines[0].begins_with("Woods: Farm low → high"), "previewed: %s" % lines)
	assert_equal(crews.crew_priority(CrewsScript.CREW_WOODS, WorkIds.ACT_FARM), WorkIds.PRIORITY_LOW, "not yet applied")
	assert_true(crews.apply_preset(CrewsScript.PRESET_HARVEST), "applied")
	for crew: int in CrewsScript.CREW_COUNT:
		assert_true(crews.crew_priority(crew, WorkIds.ACT_FARM) <= WorkIds.PRIORITY_HIGH, "farm raised for crew %d" % crew)
	assert_equal(crews.preview_preset(CrewsScript.PRESET_HARVEST), PackedStringArray(), "no change from itself")
	crews.apply_preset(CrewsScript.PRESET_WINTER)
	assert_equal(crews.crew_priority(CrewsScript.CREW_HAULERS, WorkIds.ACT_FARM), WorkIds.PRIORITY_LOW, "farm waits")
	assert_equal(crews.crew_priority(CrewsScript.CREW_FIELD, WorkIds.ACT_FARM), WorkIds.PRIORITY_HIGHEST, "but not the Field crew's own")
	assert_equal(crews.crew_priority(CrewsScript.CREW_DIGGERS, WorkIds.ACT_WOODS), WorkIds.PRIORITY_HIGH, "woods raised")
	assert_equal(crews.preset, CrewsScript.PRESET_WINTER, "the preset applied")
	assert_false(crews.apply_preset(CrewsScript.PRESET_CUSTOM), "custom is not a preset to apply")


func test_a_members_status_reads_its_brain() -> void:
	"""Resting, absent (in the water or held), occupied (an order or a job), else available."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	assert_equal(CrewsScript.status_of(brain, false), CrewsScript.STATUS_AVAILABLE, "available")
	assert_equal(CrewsScript.status_of(brain, true), CrewsScript.STATUS_OCCUPIED, "a job")
	brain.water_hold = true
	assert_equal(CrewsScript.status_of(brain, false), CrewsScript.STATUS_ABSENT, "held by the rescue")
	brain.water_hold = false
	brain.resting = true
	assert_equal(CrewsScript.status_of(brain, false), CrewsScript.STATUS_RESTING, "in bed")
	brain.resting = false
	brain.order_move(brain.position + Vector2(1.0, 0.0))
	assert_equal(CrewsScript.status_of(brain, false), CrewsScript.STATUS_OCCUPIED, "under an order")


# --- the order list ---------------------------------------------------------------------------------------

func _entry(words: String, taken: Array) -> UnfinishedScript:
	"""An entry that records being taken up."""
	return UnfinishedScript.new(func(_b: RefCounted) -> bool:
		taken.append(words)
		return true, words)


func test_the_order_list_adds_removes_and_reorders_up_to_eight() -> void:
	"""Queued orders go to the end (taken after everything on the list), a job kept from an interruption to the front;
	at most eight in all and three kept from interruptions; one removed, one moved; taken up in that order."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	var taken: Array = []
	for k: int in 7:
		assert_true(brain.append_queued(_entry("q%d" % k, taken)), "queued %d" % k)
	assert_false(brain.append_queued(_entry("q3", taken)), "the same words twice: refused")
	brain.remember_unfinished(_entry("back", taken))
	assert_true(brain.append_queued(_entry("q7", taken)), "an eighth queued order")
	assert_false(brain.append_queued(_entry("q8", taken)), "a ninth refused")
	assert_false(brain.can_queue(), "the queue is full")
	brain.remember_unfinished(_entry("back again", taken))
	assert_equal(brain.queue_size(), 10, "eight queued and two kept from interruptions: a full queue pushes none out")
	assert_true(brain.remove_queued(0), "the latest interruption dropped by the player")
	assert_true(brain.remove_queued(8), "and q7")
	assert_equal(OrderList.entry_words(brain, 0), "back to back", "the interrupted job first")
	assert_equal(OrderList.entry_words(brain, 1), "q0", "then the queue in order")
	assert_true(brain.remove_queued(2), "q1 removed")
	assert_true(brain.move_queued(5, -4), "q5 moved up four")
	assert_false(brain.move_queued(0, -1), "the first cannot go sooner")
	assert_false(brain.move_queued(6, 1), "the last cannot go later")
	var words := PackedStringArray()
	OrderList.items_into(brain, words)
	assert_equal(words, PackedStringArray(["back to back", "q5", "q0", "q2", "q3", "q4", "q6"]), "the list")
	assert_equal(OrderList.ribbon(words).left(20), "Next: back to back →", "its line")
	while brain.queue_size() > 0:
		brain.take_up_unfinished()
		brain.work_done()
	assert_equal(taken, ["back", "q5", "q0", "q2", "q3", "q4", "q6"], "taken up in that order")


func test_interruptions_keep_three_and_never_push_out_the_players_queue() -> void:
	"""Five interruptions with two queued orders: the three latest interruptions are kept, both queued orders stay."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	var taken: Array = []
	brain.append_queued(_entry("mine 1", taken))
	brain.append_queued(_entry("mine 2", taken))
	for k: int in 5:
		brain.remember_unfinished(_entry("job %d" % k, taken))
	var words := PackedStringArray()
	OrderList.items_into(brain, words)
	assert_equal(words, PackedStringArray(["back to job 4", "back to job 3", "back to job 2", "mine 1", "mine 2"]), "kept")
	brain.release()
	assert_equal(brain.queue_size(), 0, "R forgets them all")


func test_a_queued_task_is_left_to_its_resident_and_taken_up_when_its_work_is_done() -> void:
	"""A harvest queued for resident 0 while it is in bed: the board's claims leave it alone (promised) though everyone
	else is free; up again, resident 0 takes it up -- its own list before the board's claim. A queued walk goes first
	when appended to an idle resident's list, then the next."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var brain := _brain(rig, 0)
	brain.resting = true
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	assert_equal(rig.board.queue_task(WorkIds.SOURCE_FARM, row, 0), "", "queued for 0")
	assert_true(brain.promises(WorkIds.SOURCE_FARM, rig.farm.jobs.serial[row]), "promised")
	assert_true(rig.board.resume_words(WorkIds.SOURCE_FARM, rig.farm.jobs.serial[row]).begins_with("queued for"), "said")
	_run(rig, 2.0, func() -> bool: return false)
	assert_equal(rig.farm.jobs.worker[row], FarmJobs.NOBODY, "nobody else takes it")
	brain.resting = false
	assert_true(_run(rig, 1.0, func() -> bool: return rig.farm.jobs.worker[row] == 0), "taken up by 0, up again")
	var walker := _brain(rig, 1)
	var goal: Vector2 = walker.position + Vector2(2.0, 0.0)
	assert_equal(rig.board.queue_walk(1, goal), "", "a walk queued")
	assert_equal([walker.order, walker.goal()], [BrainScript.ORDER_MOVE, goal], "taken up at once: it was idle")
	assert_true(_run(rig, 20.0, func() -> bool: return walker.order == BrainScript.ORDER_NONE), "arrived: back to its routine")


# --- the same schedule at 1x, 2x and 4x --------------------------------------------------------------------

func _schedule_outcome(speed: int) -> Array:
	"""The same command schedule (cast time) at `speed`: a harvest and two woods jobs queued at the start, the harvest
	reassigned 6 s in; the outcome after 150 s of cast time -- who did each job, what was stored and stacked."""
	var manager := _keep(GameManagerScript.new()) as GameManagerScript
	assert_true(manager.start_game() and manager.set_speed(speed), "running at %dx" % speed)
	var rig := _rig(manager)
	_crews(rig, PackedInt32Array([0, 0, 1, 1, 3, 3]))
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	rig.forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	rig.forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array())
	rig.forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array())
	var harvest: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	var takers := PackedInt32Array([-1, -1, -1])
	var usec: int = 0
	var reassigned: bool = false
	while usec < 150000000:
		_frame(rig)
		usec += rig.cast.clock.frame_usec
		if not reassigned and usec >= 6000000:
			reassigned = true
			rig.board.reassign(WorkIds.SOURCE_FARM, harvest, 4)
		_note_takers(rig, harvest, takers)
	return [takers, rig.pantry.milli_of(CARROT), _services.stores.wood_milli_u, _services.stores.plank_milli_u,
		rig.farm.jobs.live_count(), rig.forestry.crew.jobs.live_count()]


func _note_takers(rig: Rig, harvest: int, takers: PackedInt32Array) -> void:
	"""The first resident seen on the harvest (before the reassign: its claimant), the haul and the sawing."""
	if takers[0] < 0 and rig.farm.jobs.is_live(harvest):
		takers[0] = rig.farm.jobs.worker[harvest]
	var jobs: ForestJobs = rig.forestry.crew.jobs
	for row: int in ForestJobs.MAX_JOBS:
		if not jobs.is_live(row) or jobs.worker[row] < 0:
			continue
		if jobs.kind[row] == ForestJobs.KIND_HAUL and takers[1] < 0:
			takers[1] = jobs.worker[row]
		elif jobs.kind[row] == ForestJobs.KIND_SAW and takers[2] < 0:
			takers[2] = jobs.worker[row]


func test_the_same_schedule_has_the_same_outcome_at_one_two_and_four_times() -> void:
	"""Who took each job, what was stored and stacked, and what is left: equal at 1x, 2x and 4x."""
	var one: Array = _schedule_outcome(1)
	_services = ServicesScript.new()
	var two: Array = _schedule_outcome(2)
	_services = ServicesScript.new()
	var four: Array = _schedule_outcome(4)
	assert_equal(two, one, "2x as 1x")
	assert_equal(four, one, "4x as 1x")
	assert_equal(one[1], CARROT_YIELD, "the harvest stored")


# --- the one assignment grammar (F44's remainder, UX-001) ---------------------------------------------------

func test_a_card_left_on_the_board_names_the_crew_first_then_anyone() -> void:
	"""The action card's "who" for an order with nobody selected is the board's: the crew preferring its activity,
	then anyone free who can."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 1, 3, 3, 3]))
	var card := CardScript.new()
	rig.farm.preview_into(card, FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array())
	assert_equal(card.who, "Queue for the Field crew: %s or %s, then anyone free who can" % [_name(rig, 0), _name(rig, 1)],
		"the farm's card")
	rig.forestry.crew.preview_into(card, ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array())
	assert_equal(card.who, "Queue for the Woods crew: %s, then anyone free who can" % _name(rig, 2), "the woods' card")
	rig.board.crews.set_crew(2, CrewsScript.CREW_HAULERS)
	assert_equal(rig.board.queue_words(WorkIds.ACT_WOODS, 0), "Queue for the Woods crew: nobody is on it — anyone free who can takes it",
		"an empty crew")


func test_a_mixed_group_previews_each_members_eligibility() -> void:
	"""A group order's card says, member by member, who can take it and why not the others -- the Reassign picker's
	words (`eligibility_words`)."""
	var rig := _rig()
	var card := CardScript.new()
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([1]), FarmJobs.ORIGIN_PLAYER)
	_brain(rig, 2).water_hold = true
	rig.farm.preview_into(card, FarmJobs.KIND_COMPOST, 0, PackedInt32Array([0, 1, 2]))
	assert_equal(card.members, "Of 3 selected: %s can; %s can't (has another farm job); %s can't (held by the rescue)" % [
		_name(rig, 0), _name(rig, 1), _name(rig, 2)], "member by member")
	var row: int = _farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)
	assert_equal(rig.board.members_words(WorkIds.SOURCE_FARM, row, PackedInt32Array([0, 2])),
		"Of 2 selected: %s can; %s can't (%s)" % [_name(rig, 0), _name(rig, 2), BoardScript.HELD], "the board's words")
	assert_equal(CardScript.each_member(PackedStringArray(["a"]), PackedStringArray([""])), "", "one: no preview")
	_brain(rig, 2).water_hold = false


func _name(rig: Rig, who: int) -> String:
	"""Resident `who`'s name."""
	return (rig.cast.actor(who) as DemoActorScript).display_name


# --- the board's edges -------------------------------------------------------------------------------------

func test_with_the_board_claiming_the_old_routine_crews_stand_down() -> void:
	"""The farm's, the woods' and the bridges' own routine crews hand nothing out once the board claims: a crew member
	whose board crew forbids the work is never given it by the old hand-out."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([3, 3, 3, 3, 3, 3]))
	for crew: int in CrewsScript.CREW_COUNT:
		rig.board.crews.set_priority(crew, WorkIds.ACT_FARM, WorkIds.PRIORITY_FORBIDDEN)
	rig.farm.set_crew(PackedInt32Array([0, 1, 2, 3, 4, 5]))
	rig.play.crew.set_crew(PackedInt32Array([0]))
	rig.farm.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	for crew: int in CrewsScript.CREW_COUNT:
		rig.board.crews.set_priority(crew, WorkIds.ACT_BUILD, WorkIds.PRIORITY_FORBIDDEN)
	_plank_bridge(rig)
	_run(rig, 2.0, func() -> bool: return false)
	assert_equal(rig.farm.jobs.worker[_farm_row(rig, FarmJobs.KIND_HARVEST, BED_CARROTS)], FarmJobs.NOBODY, "no farm hand-out")
	assert_equal(rig.play.crew.builder[0], BridgeCrewScript.NOBODY, "no bridgewright hand-out")
	assert_true(rig.farm.claims_outside() and rig.forestry.crew.claims_outside() and rig.play.crew.claims_outside(), "stood down")


func test_a_farm_job_left_for_another_order_is_promised_to_its_worker() -> void:
	"""Called away from a farm job, its worker keeps it on its list naming the task: nobody else is given it, and the
	worker takes it back when its order is done."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var row: int = _harvest_to(rig, 3)
	assert_true(_run(rig, 5.0, func() -> bool: return _brain(rig, 3).state == BrainScript.State.WALK), "on its way")
	var brain := _brain(rig, 3)
	brain.order_move(brain.position + Vector2(-1.5, 0.0))
	_frame(rig)
	assert_true(brain.promises(WorkIds.SOURCE_FARM, rig.farm.jobs.serial[row]), "promised")
	_run(rig, 2.0, func() -> bool: return false)
	assert_equal(rig.farm.jobs.worker[row], FarmJobs.NOBODY, "nobody else took it")
	brain.work_done()
	assert_equal(rig.farm.jobs.worker[row], 3, "back to it")


func test_a_paused_job_is_not_taken_back_by_its_worker_either() -> void:
	"""A worker called away keeps the job on its list; paused meanwhile, the job is not taken back when the worker's
	order is done -- it waits for Resume. (The farm, the woods and a bridge alike.)"""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 0, 0, 0, 0, 0]))
	var row: int = _harvest_to(rig, 3)
	rig.forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([4]), ForestJobs.ORIGIN_PLAYER)
	_frame(rig)
	for who: int in [3, 4]:
		_brain(rig, who).order_move(_brain(rig, who).position + Vector2(-1.0, 0.0))
	_frame(rig)
	assert_equal(rig.board.pause(WorkIds.SOURCE_FARM, row, true), "", "the harvest paused")
	assert_equal(rig.board.pause(WorkIds.SOURCE_WOODS, 0, true), "", "the felling paused")
	_brain(rig, 3).work_done()
	_brain(rig, 4).work_done()
	assert_equal([rig.farm.jobs.worker[row], rig.forestry.crew.jobs.worker[0]], [FarmJobs.NOBODY, ForestJobs.NOBODY],
		"neither taken back while paused")
	_plank_bridge(rig)
	assert_equal(rig.board.pause(WorkIds.SOURCE_BRIDGES, 0, true), "", "the bridge paused")
	_run(rig, 2.0, func() -> bool: return false)
	assert_equal(rig.play.crew.builder[0], BridgeCrewScript.NOBODY, "a paused bridge is not claimed")
	assert_equal(rig.board.pause(WorkIds.SOURCE_BRIDGES, 0, false), "", "resumed")
	assert_true(_run(rig, 1.0, func() -> bool: return rig.play.crew.builder[0] >= 0), "claimed again")


func test_a_resident_looks_at_most_thirty_two_candidates_a_pass_and_goes_on_from_its_cursor() -> void:
	"""GDD §5.3's budget: over 32 waiting jobs, only the last of them (a haul) allowed to the one free resident: the
	first pass looks at 32 and finds nothing; the next goes on from the saved cursor and takes the haul."""
	var rig := _rig()
	_crews(rig, PackedInt32Array([0, 3, 3, 3, 3, 3]))
	for who: int in range(1, 6):
		_brain(rig, who).resting = true
	var none := PackedInt32Array()
	var farm_jobs: int = 0
	for bed: int in Catalog.BED_COUNT:
		for kind: int in FarmJobs.KIND_COUNT:
			if not rig.farm.order(kind, bed, none, FarmJobs.ORIGIN_PLAYER).begins_with("Can't"):
				farm_jobs += 1
	for t: int in rig.forestry.stand.count():
		if rig.forestry.crew.refusal_for(ForestJobs.KIND_FELL, t, 0).is_empty() and rig.forestry.crew.jobs.live_count() < 23:
			rig.forestry.crew.order(ForestJobs.KIND_FELL, t, 0, none, ForestJobs.ORIGIN_PLAYER)
	while rig.forestry.crew.jobs.live_count() < 23:
		rig.forestry.crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, none, ForestJobs.ORIGIN_PLAYER)
	rig.forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	rig.forestry.crew.order(ForestJobs.KIND_HAUL, WEST_OAK, 0, none, ForestJobs.ORIGIN_PLAYER)
	var haul: int = _woods_row(rig, ForestJobs.KIND_HAUL, WEST_OAK)
	assert_equal(haul, 23, "the haul in the woods' last row")
	assert_true(farm_jobs + 23 >= BoardScript.MAX_CANDIDATES, "the haul past the first 32: %d farm jobs" % farm_jobs)
	rig.board.crews.set_priority(CrewsScript.CREW_FIELD, WorkIds.ACT_FARM, WorkIds.PRIORITY_FORBIDDEN)
	rig.board.crews.set_priority(CrewsScript.CREW_FIELD, WorkIds.ACT_WOODS, WorkIds.PRIORITY_FORBIDDEN)
	rig.board.rebuild_index()
	var seen: int = rig.board.candidates_seen
	assert_false(rig.board.consider(0), "the first pass: none of its 32 is allowed")
	assert_equal(rig.board.candidates_seen - seen, BoardScript.MAX_CANDIDATES, "32 looked at")
	assert_true(rig.board.consider(0), "the next pass, from the cursor: the haul")
	assert_equal(rig.forestry.crew.jobs.worker[haul], 0, "taken")
	for who: int in range(1, 6):
		_brain(rig, who).resting = false


func test_a_stale_queued_entry_does_not_take_a_new_job_in_the_same_row() -> void:
	"""A task queued for a busy resident is cancelled and its row reused by a new job: the entry, naming the old job,
	takes nothing when its turn comes."""
	var rig := _rig()
	var brain := _brain(rig, 0)
	brain.order_move(brain.position + Vector2(1.0, 0.0))
	rig.forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_equal(rig.board.queue_task(WorkIds.SOURCE_WOODS, 0, 0), "", "queued")
	assert_equal(rig.board.cancel(WorkIds.SOURCE_WOODS, 0), "", "cancelled")
	rig.forestry.crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_equal(rig.forestry.crew.jobs.kind[0], ForestJobs.KIND_SAW, "the row reused")
	brain.work_done()
	assert_equal(rig.forestry.crew.jobs.worker[0], ForestJobs.NOBODY, "the stale entry took nothing")


func test_a_tasks_priority_is_its_own_not_its_rows() -> void:
	"""Priority and urgency set on a job go with it: a new job in the same row starts NORMAL, not urgent."""
	var rig := _rig()
	rig.forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	rig.board.set_task_priority(WorkIds.SOURCE_WOODS, 0, WorkIds.PRIORITY_HIGHEST)
	rig.board.set_urgent(WorkIds.SOURCE_WOODS, 0, true)
	rig.board.cancel(WorkIds.SOURCE_WOODS, 0)
	rig.forestry.crew.order(ForestJobs.KIND_SAW, ForestJobs.NO_TARGET, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_WOODS, 0), WorkIds.PRIORITY_NORMAL, "normal")
	assert_false(rig.board.is_urgent(WorkIds.SOURCE_WOODS, 0), "not urgent")
	rig.board.raise_priority(WorkIds.SOURCE_WOODS, 0, -1)
	assert_equal(rig.board.task_priority(WorkIds.SOURCE_WOODS, 0), WorkIds.PRIORITY_HIGH, "its own raise")


func test_a_tasks_state_says_finding_a_route_and_cant_reach_it() -> void:
	"""The records' phase words: TRAVELLING "finding a route" while the routing desk keeps a worker waiting, BLOCKED
	"can't reach it" while a walk it gave up holds, ASSIGNED before a walk is issued, HAULING with a load."""
	var rig := _rig()
	var task := TaskScript.new()
	var brain := _brain(rig, 0)
	brain.state = BrainScript.State.ROUTE
	SourceScript.worker_state_into(task, brain, true, true)
	assert_equal([task.state, task.reason], [WorkIds.STATE_TRAVELLING, SourceScript.FINDING_ROUTE], "finding a route")
	task.reason = ""
	brain.state = BrainScript.State.HOLD
	brain.trip_outcome = BrainScript.TRIP_FAILED
	brain.set(&"_refusal", BrainScript.REFUSED_NO_ROUTE)
	SourceScript.worker_state_into(task, brain, true, true)
	assert_equal([task.state, task.reason], [WorkIds.STATE_BLOCKED, SourceScript.CANT_REACH % BrainScript.REFUSED_NO_ROUTE],
		"can't reach it")
	brain.trip_outcome = BrainScript.TRIP_ARRIVED
	task.reason = ""
	SourceScript.worker_state_into(task, brain, true, false)
	assert_equal(task.state, WorkIds.STATE_ASSIGNED, "assigned")
	task.carrying = true
	SourceScript.worker_state_into(task, brain, true, true)
	assert_equal(task.state, WorkIds.STATE_HAULING, "hauling")
	SourceScript.worker_state_into(task, brain, false, true)
	assert_equal(task.state, WorkIds.STATE_WORKING, "at work")


func test_one_farm_job_a_resident_in_the_picker_and_the_command_alike() -> void:
	"""A resident with a farm job is not eligible for another (the picker's words are the command's refusal)."""
	var rig := _rig()
	_harvest_to(rig, 3)
	var second := _second_farm_task(rig)
	rig.farm.order(second.x, second.y, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var row: int = _farm_row(rig, second.x, second.y)
	assert_equal(rig.board.eligibility_words(WorkIds.SOURCE_FARM, row, 3), FarmWork.OTHER_JOB, "the picker's words")
	assert_equal(rig.board.reassign(WorkIds.SOURCE_FARM, row, 3), FarmWork.OTHER_JOB, "the command's")
