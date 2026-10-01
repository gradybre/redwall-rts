extends "res://test/framework/test_case.gd"
## Explicit arrival for the farm's and the woods' crews (decision 0411, closing decision 0361's open F05 cases): a
## job's work and deliveries are credited only to a worker whose trip ARRIVED and who still stands within reach of its
## spot -- holding is no evidence of arrival -- and that is rechecked every frame of work. Each test runs the real crew
## on the placeholder cast in the real village layout, with a physical block (a ring of obstacles) or the worker
## displaced, and asserts what was cut, felled or stored and where the worker stood. No staged assets.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const ForestCrewScript := preload("res://demo/forestry/forest_crew.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const BED_CARROTS: int = 2
const CARROT: int = 2
const WOOD: int = 60
const NORTH_OAK: int = 32

var _nodes: Array[Object] = []
var _services: ServicesScript = null


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


# --- fixtures --------------------------------------------------------------------------------------

func _farm() -> Array:
	"""The placeholder cast in the village layout and a farm crew over it, the carrot bed ripe. [cast, sim, pantry,
	crew]."""
	var world: DemoWorldScript = DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	var sim := SimScript.new()
	sim.advance_usec(24 * HOUR_USEC)
	var pantry := PantryScript.new(StorageScript.new(DemoFarmScript.store_position(cast)))
	var crew := FarmCrewScript.new()
	crew.configure(cast, sim, pantry, TunnelsScript.new(), DemoFarmScript.well_position(), func(_t: String) -> void: pass)
	crew.set_crew(PackedInt32Array())
	return [cast, sim, pantry, crew]


func _woods() -> ForestryScript:
	"""The woods over the placeholder cast in the village layout, no routine crew."""
	var world: DemoWorldScript = DemoWorldScript.new()
	_nodes.append(world)
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(ForestryScript.extra_obstacles(world))
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	var forestry := ForestryScript.new()
	_nodes.append(forestry)
	forestry.configure(world, cast, null, null, _services, IntMath.IntResult.new(true, WOOD, ""))
	forestry.crew.set_crew(PackedInt32Array())
	return forestry


func _wall_round(space: CastSpaceScript, at: Vector2) -> void:
	"""Twelve 0.45 m circles 1 m round `at`, overlapping: nobody gets in (the hand-offs suite's wall)."""
	for r: int in 3:
		var circles := PackedVector3Array()
		for k: int in 4:
			var angle: float = TAU * float(r * 4 + k) / 12.0
			circles.append(Vector3(at.x + cos(angle), 0.45, at.y + sin(angle)))
		space.set_mound(r, circles)


func _brain(cast: DemoCastScript, who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (cast.actor(who) as DemoActorScript).brain


func _farm_frames(f: Array, seconds: float, each: Callable) -> void:
	"""Every brain, then the farm crew, for `seconds`."""
	var cast: DemoCastScript = f[0]
	var crew: FarmCrewScript = f[3]
	for frame: int in roundi(seconds / DT):
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
		each.call()


func _cut(sim: SimScript) -> bool:
	"""Whether the carrots have been cut."""
	return sim.stage_of(BED_CARROTS) != SimScript.STAGE_RIPE


# --- the farm --------------------------------------------------------------------------------------

func test_a_harvester_walled_off_from_its_spot_cuts_nothing_from_afar() -> void:
	"""F05 for the farm: the spot by the bed walled round after the walk was given. The brain gives the trip up and
	holds where it stands; the crew takes that for a failed try, never arrival: the crop is cut only by a worker that
	arrived at its own spot (a later try may find a reachable one)."""
	var f := _farm()
	var cast: DemoCastScript = f[0]
	var crew: FarmCrewScript = f[3]
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	crew.update(16667)
	assert_equal(crew.jobs.issued[0], 1, "the walk given")
	_wall_round(cast.space(), crew.jobs.goal[0])
	var brain := _brain(cast, 3)
	var seen := {"failed": false, "remote": false, "elapsed_off": false}
	_farm_frames(f, 60.0, func() -> void:
		seen["failed"] = bool(seen["failed"]) or brain.trip_failed()
		var at_work: bool = crew.jobs.is_live(0) and crew.jobs.current_step(0) >= FarmJobs.STEP_WORK \
			and crew.jobs.elapsed_usec[0] > 0
		if at_work and not brain.arrived_near(crew.jobs.goal[0], FarmCrewScript.ARRIVE_M):
			seen["elapsed_off"] = true
		if _cut(f[1]) and not bool(seen["remote"]):
			seen["remote"] = not brain.arrived_near(crew.jobs.goal[0], FarmCrewScript.ARRIVE_M))
	assert_true(seen["failed"], "the walk was given up")
	assert_false(seen["elapsed_off"], "no work counted away from its spot")
	assert_false(seen["remote"], "never cut from afar")


func test_a_walk_given_up_at_the_spot_is_not_arrival() -> void:
	"""Holding at the very spot is not arriving: a trip marked given up there is a failed try, the walk issued afresh,
	and nothing is begun -- the decision-0361 test, not the old distance-while-holding one."""
	var f := _farm()
	var cast: DemoCastScript = f[0]
	var crew: FarmCrewScript = f[3]
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	crew.update(16667)
	var brain := _brain(cast, 3)
	for frame: int in roundi(60.0 / DT):
		cast.advance(DT)
		if brain.state == BrainScript.State.HOLD and brain.position.distance_to(crew.jobs.goal[0]) <= FarmCrewScript.ARRIVE_M:
			break
	assert_equal(brain.state, BrainScript.State.HOLD, "holding at the spot")
	brain.trip_outcome = BrainScript.TRIP_FAILED
	crew.update(16667)
	assert_equal([crew.jobs.current_step(0), crew.jobs.tries[0]], [FarmJobs.STEP_GO_BED, 1], "a failed try, not arrival")
	brain.trip_outcome = BrainScript.TRIP_ARRIVED
	var arrived := [false]
	_farm_frames(f, 30.0, func() -> void:
		if crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_HARVEST and not arrived[0]:
			arrived[0] = brain.arrived_near(crew.jobs.goal[0], FarmCrewScript.ARRIVE_M))
	assert_true(arrived[0], "the walk issued afresh, and on to the work only once it arrived")


func test_a_harvester_pushed_off_its_spot_stops_cutting_and_walks_back() -> void:
	"""Rechecked every frame of work: a worker cutting the crop who is no longer at its spot credits nothing there and
	goes back to its walk, the work it did kept with the job (farm_jobs.gd `rewind_to_walk`)."""
	var f := _farm()
	var cast: DemoCastScript = f[0]
	var crew: FarmCrewScript = f[3]
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var cutting := func() -> bool: return crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_HARVEST \
		and crew.jobs.elapsed_usec[0] > 0
	for frame: int in roundi(90.0 / DT):
		if cutting.call():
			break
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
	assert_true(cutting.call(), "cutting")
	var done: int = crew.jobs.elapsed_usec[0]
	var brain := _brain(cast, 3)
	brain.position += (crew.jobs.goal[0] - Catalog.bed_centre_m(BED_CARROTS)).normalized() * 3.0
	cast.space().move_resident(brain.index, brain.position)
	crew.update(FarmJobs.work_usec_of(FarmJobs.WORK_HARVEST))
	assert_equal(crew.jobs.elapsed_usec[0], done, "nothing credited from three metres off")
	assert_equal(crew.jobs.current_step(0), FarmJobs.STEP_GO_BED, "back to the walk")
	assert_equal((f[1] as SimScript).stage_of(BED_CARROTS), SimScript.STAGE_RIPE, "the crop stands")
	assert_true(_cut_by_arrival(f, brain), "walked back and cut it there")


func _cut_by_arrival(f: Array, brain: BrainScript) -> bool:
	"""Run on until the crop is cut; whether the cutter had arrived at its spot when it was."""
	var crew: FarmCrewScript = f[3]
	var arrived := [false]
	_farm_frames(f, 60.0, func() -> void:
		if not _cut(f[1]):
			arrived[0] = crew.jobs.is_live(0) and brain.arrived_near(crew.jobs.goal[0], FarmCrewScript.ARRIVE_M))
	return _cut(f[1]) and arrived[0]


func test_a_carrier_pushed_off_the_store_spot_stores_nothing_from_there() -> void:
	"""The drop at the store rechecks arrival too: the carrier moved off its spot mid-drop stores nothing, walks back
	and puts the harvest down there -- credited once, at the store."""
	var f := _farm()
	var cast: DemoCastScript = f[0]
	var crew: FarmCrewScript = f[3]
	var pantry: PantryScript = f[2]
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var dropping := func() -> bool: return crew.jobs.is_live(0) \
		and crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_DROP and crew.jobs.issued[0] == 1
	for frame: int in roundi(180.0 / DT):
		if dropping.call():
			break
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
	assert_true(dropping.call(), "putting it down at the store")
	var brain := _brain(cast, 3)
	brain.position += Vector2(0.0, 3.0)
	cast.space().move_resident(brain.index, brain.position)
	crew.update(FarmJobs.work_usec_of(FarmJobs.WORK_DROP))
	assert_equal(pantry.milli_of(CARROT), 0, "nothing stored from three metres off")
	assert_equal(crew.jobs.current_step(0), FarmJobs.STEP_CARRY_STORE, "carried back to the spot")
	_farm_frames(f, 60.0, func() -> void: pass)
	assert_true(pantry.milli_of(CARROT) > 0, "stored on arrival")


# --- the woods ---------------------------------------------------------------------------------------

func test_a_feller_pushed_off_its_spot_fells_nothing_from_there() -> void:
	"""F05 for the woods: a feller moved off its spot mid-felling credits no felling there and walks back first; the
	tree stands until a feller standing at its own spot fells it."""
	var forestry := _woods()
	var cast: DemoCastScript = forestry._cast
	var crew: ForestCrewScript = forestry.crew
	crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([2]), ForestJobs.ORIGIN_PLAYER)
	var felling := func() -> bool: return crew.jobs.current_step(0) == ForestJobs.STEP_WORK + ForestJobs.WORK_FELL \
		and crew.jobs.issued[0] == 1
	for frame: int in roundi(120.0 / DT):
		if felling.call():
			break
		cast.advance(DT)
		forestry.step(cast.clock.frame_usec)
	assert_true(felling.call(), "felling")
	var brain := crew.brain_of(2)
	brain.position += Vector2(3.0, 0.0)
	cast.space().move_resident(brain.index, brain.position)
	forestry.step(crew.jobs.work_usec[0] + 1)
	assert_equal(forestry.stand.state_of(NORTH_OAK), StandScript.STATE_MATURE, "not felled from three metres off")
	assert_equal(crew.jobs.current_step(0), ForestJobs.STEP_GO_TREE, "walking back first")
	assert_equal(brain.clip, BrainScript.CLIP_IDLE, "the axe put away")


func test_a_woods_walk_given_up_at_the_spot_is_not_arrival() -> void:
	"""A woods walk marked given up while holding at its spot is a failed try: nothing begun there."""
	var forestry := _woods()
	var cast: DemoCastScript = forestry._cast
	var crew: ForestCrewScript = forestry.crew
	crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([2]), ForestJobs.ORIGIN_PLAYER)
	crew.update(16667)
	var brain := crew.brain_of(2)
	for frame: int in roundi(90.0 / DT):
		cast.advance(DT)
		if brain.state == BrainScript.State.HOLD and brain.position.distance_to(crew.jobs.goal[0]) <= ForestCrewScript.ARRIVE_M:
			break
	assert_equal(brain.state, BrainScript.State.HOLD, "holding at the spot")
	brain.trip_outcome = BrainScript.TRIP_FAILED
	crew.update(16667)
	assert_equal([crew.jobs.current_step(0), crew.jobs.tries[0]], [ForestJobs.STEP_GO_TREE, 1], "a failed try")


func test_a_feller_walled_off_from_the_tree_fells_nothing_from_afar() -> void:
	"""The tree's spot walled round after the walk was given: the felling is credited only by a feller arrived at its
	own spot."""
	var forestry := _woods()
	var cast: DemoCastScript = forestry._cast
	var crew: ForestCrewScript = forestry.crew
	crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array([2]), ForestJobs.ORIGIN_PLAYER)
	crew.update(16667)
	_wall_round(cast.space(), crew.jobs.goal[0])
	var brain := crew.brain_of(2)
	var seen := {"failed": false, "remote": false}
	for frame: int in roundi(90.0 / DT):
		cast.advance(DT)
		forestry.step(cast.clock.frame_usec)
		seen["failed"] = bool(seen["failed"]) or brain.trip_failed()
		var working: bool = crew.jobs.is_live(0) and crew.jobs.current_step(0) == ForestJobs.STEP_WORK + ForestJobs.WORK_FELL \
			and crew.jobs.elapsed_usec[0] > 0
		if working and not brain.arrived_near(crew.jobs.goal[0], ForestCrewScript.ARRIVE_M):
			seen["remote"] = true
	assert_true(seen["failed"], "the walk was given up")
	assert_false(seen["remote"], "no felling counted away from its spot")
