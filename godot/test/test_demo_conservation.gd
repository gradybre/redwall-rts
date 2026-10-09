extends "res://test/framework/test_case.gd"
## Conservation in the live demo's farm and woods (decision 0222, the review's F19, F24, F25, F27 and
## F28): a harvest is never cut without somewhere to put it, a store that fills keeps the rest in the
## carrier's arms, cancelling production lets a carrier finish its walk and credits the store only on
## arrival, a carrier called away keeps its load and comes back to it, sapling compost is paid once per
## job, and the Pantry's forecast and figures are the authoritative milli-units, read truthfully.
##
## Real process order throughout: the production `order()` / `order_on()` verbs, the cast and crews
## stepped frame by frame, the brains' own orders for interruptions -- no private payment or delivery
## call. Placeholder cast in the real village layout: no staged assets.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const FarmCrewScript := preload("res://demo/farm/farm_crew.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const HudScript := preload("res://demo/farm/farm_hud.gd")
const PantryPanelScript := preload("res://demo/farm/farm_pantry_panel.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const PickScript := preload("res://demo/forestry/forest_pick.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ActionCard := preload("res://demo/ui/action_card.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = preload("res://demo/demo_calendar.gd").HOUR_USEC
const CARROT: int = 2
const WHEAT: int = 13
const BED_CARROTS: int = 2
## §5.6's ripe carrot yield in this bed (test_demo_farm_ui.gd's harvest test).
const CARROT_YIELD: int = 5100
## The woods' fixture: the compiled wood id, the real layout's west oak, and a bounded run.
const WOOD: int = 60
const WEST_OAK: int = 33
## A mature tree of the North stand, within reach (test_demo_forestry.gd NORTH_TREES).
const NORTH_OAK: int = 32
const WOODS_DT: float = 0.1
const WOODS_FRAMES: int = 6000
## §5.8's summer: an hour index on summer day 1 (day_zero 12 x 24 h).
const SUMMER_HOUR: int = 288
## Spring with 100 game hours left before summer.
const LATE_SPRING_HOUR: int = 187

var _nodes: Array[Object] = []
var _notices: PackedStringArray = PackedStringArray()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _services: ServicesScript = null
## A test store's capacity, U -- read by its provider on every refresh.
var _cellar_u: PackedInt32Array = PackedInt32Array([0, 0])
## Where the test stores are delivered to (INF: where the covered store is).
var _cellar_at: Vector2 = Vector2.INF


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()
	_cellar_u = PackedInt32Array([0, 0])
	_cellar_at = Vector2.INF


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			if (node as Node).is_inside_tree():
				(node as Node).get_parent().remove_child(node)
			node.free()
	_nodes.clear()
	_notices.clear()


# --- farm fixtures ------------------------------------------------------------------------------

func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), world.obstacles())
	cast.set_bounds(world.bounds())
	return cast


func _crew(cast: DemoCastScript, sim: SimScript, pantry: PantryScript, routine: PackedInt32Array) -> FarmCrewScript:
	"""A farm crew whose notices are collected; `routine` is its routine crew."""
	var crew := FarmCrewScript.new()
	crew.configure(cast, sim, pantry, TunnelsScript.new(), DemoFarmScript.well_position(),
		func(text: String) -> void: _notices.append(text))
	crew.set_crew(routine)
	return crew


func _pantry(cast: DemoCastScript) -> PantryScript:
	"""The covered store, plus two test stores (at the GDD's cellar factor, so preferred) whose capacities
	`_cellar_u` sets (0: not there)."""
	var storage := StorageScript.new(DemoFarmScript.store_position(cast))
	storage.add_provider(_test_stores.bind(DemoFarmScript.store_position(cast)))
	return PantryScript.new(storage)


func _test_stores(near: Vector2) -> Array:
	"""The test stores that have a capacity, delivered to where the covered store is (a spot the cast can
	reach; which store is which is the pantry's business, not the walk's)."""
	var out: Array = []
	for k: int in _cellar_u.size():
		if _cellar_u[k] > 0:
			out.append({"id": StringName("test_store_%d" % k), "position": near if _cellar_at == Vector2.INF else _cellar_at,
				"capacity_u": _cellar_u[k], "spoilage_permille": 350, "label": "Test store %d" % k})
	return out


func _run(cast: DemoCastScript, crew: FarmCrewScript, seconds: float, done: Callable) -> bool:
	"""Step the cast and the crew at 60 Hz until `done()` or `seconds` pass."""
	for frame: int in roundi(seconds / DT):
		cast.advance(DT)
		crew.update(cast.clock.frame_usec)
		if done.call():
			return true
	return false


func _ripe_carrots() -> SimScript:
	"""A farm a day in: the carrot bed ripe, 5.1 U standing."""
	var sim := SimScript.new()
	sim.advance_usec(24 * HOUR_USEC)
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_RIPE, "ripe")
	return sim


func _standing(sim: SimScript) -> int:
	"""The carrots still standing on their bed, milli-U."""
	if sim.stage_of(BED_CARROTS) != SimScript.STAGE_RIPE or not sim.expected_yield_into(BED_CARROTS, _read):
		return 0
	return _read.value


func _carried(crew: FarmCrewScript) -> int:
	"""Carrots carried by every farm job, milli-U."""
	var held: int = 0
	for row: int in FarmJobs.MAX_JOBS:
		if crew.jobs.is_live(row) and crew.jobs.load_item[row] == CARROT:
			held += crew.jobs.load_milli[row]
	return held


func _all_carrots(sim: SimScript, crew: FarmCrewScript, pantry: PantryScript) -> int:
	"""Standing + carried + stored: what conservation keeps at the one harvest."""
	return _standing(sim) + _carried(crew) + pantry.milli_of(CARROT)


func _walking_it(crew: FarmCrewScript) -> bool:
	"""Whether job 0's carrier is under way on its carry walk."""
	return crew.jobs.is_live(0) and crew.jobs.load_milli[0] > 0 and crew.jobs.issued[0] == 1 \
		and crew.jobs.current_step(0) == FarmJobs.STEP_CARRY_STORE


func _count_said(fragment: String) -> int:
	"""How many collected notices contain `fragment`."""
	var n: int = 0
	for line: String in _notices:
		n += 1 if line.contains(fragment) else 0
	return n


func _brain(cast: DemoCastScript, i: int) -> BrainScript:
	"""Resident `i`'s brain."""
	return (cast.actor(i) as DemoActorScript).brain


func _said(fragment: String) -> bool:
	"""Whether any collected notice contains `fragment`."""
	for line: String in _notices:
		if line.contains(fragment):
			return true
	return false


# --- F19: a full store never destroys a harvest ------------------------------------------------------

func test_a_full_store_leaves_the_crop_standing_until_there_is_room() -> void:
	"""399 U of wheat in the 400 U store: the harvest is not cut, the shortage is shown with the way to
	the Pantry, and nothing moves until room appears -- then the routine crew cuts and stores it all."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array([0]))
	assert_true(pantry.add_into(WHEAT, 399000, 0, _read), "the store nearly full")
	var said: String = crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(said.contains("no store has room for 6 bunches of carrots"), "the order says why: " + said)
	assert_true(said.contains("Pantry"), "and where to make room")
	_run(cast, crew, 30.0, func() -> bool: return false)
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_RIPE, "not cut")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "every carrot still standing")
	assert_equal(crew.jobs.live_count(), 1, "the harvest waits on the board")
	assert_true(crew.shortage_text(BED_CARROTS).contains("make room in the Pantry"), "the bed's farm text shows it")
	assert_false(_said("left the harvest standing"), "nobody walked out to a harvest with nowhere to go")
	_cellar_u[0] = 10
	pantry.refresh_locations()
	assert_true(_run(cast, crew, 180.0, func() -> bool: return crew.jobs.live_count() == 0), "harvested once there is room")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it stored")
	assert_equal(pantry.milli_at(CARROT, 1), CARROT_YIELD, "in the store with room")
	assert_equal(crew.shortage_text(BED_CARROTS), "", "no shortage left")


func test_a_store_filling_en_route_keeps_the_rest_carried_and_reroutes() -> void:
	"""The harvest reserved a 10 U store, whose racks come out (3 U) while it is carried: the store takes
	3 U, the carrier keeps 2.1 U and waits with it, and carries it on to a second store once one is
	there. Nothing is lost at any step."""
	var cast := _cast()
	var sim := _ripe_carrots()
	_cellar_u[0] = 10
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	assert_true(pantry.add_into(WHEAT, 400000, 0, _read), "the covered store full")
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, func() -> bool: return _carried(crew) > 0), "cut and carried")
	_cellar_u[0] = 3
	pantry.refresh_locations()
	assert_true(_run(cast, crew, 90.0, func() -> bool: return pantry.milli_of(CARROT) > 0), "a part stored")
	assert_equal(pantry.milli_at(CARROT, 1), 3000, "what fitted")
	assert_equal(_carried(crew), 2100, "the rest still carried")
	assert_true(crew.jobs.job_of_worker_into(3, _read), "by the same carrier")
	_run(cast, crew, 5.0, func() -> bool: return false)
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "conserved while it waits")
	assert_true(crew.shortage_text(BED_CARROTS).contains("3 bunches of carrots"), "the bed shows what waits for room")
	assert_true(_said("store has room for the rest (3 bunches of carrots)"), "the shortage is said")
	_cellar_u[1] = 10
	pantry.refresh_locations()
	var walking_on := func() -> bool: return crew.jobs.is_live(0) and crew.jobs.current_step(0) == FarmJobs.STEP_CARRY_STORE
	assert_true(_run(cast, crew, 10.0, walking_on), "the rest is walked on, not put down from afar")
	assert_equal(crew.jobs.location[0], 2, "to the second store")
	assert_true(_run(cast, crew, 90.0, func() -> bool: return crew.jobs.live_count() == 0), "the rest delivered")
	assert_equal(pantry.milli_at(CARROT, 2), 2100, "to the second store")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it")


func test_a_reservation_keeps_its_room_from_everyone_else() -> void:
	"""The pantry's own rule: room a reservation keeps is not free to another delivery, and the delivery
	that reserved it stores into it in full."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [{"id": &"c", "position": Vector2.ZERO, "capacity_u": _cellar_u[0],
		"spoilage_permille": 350}])
	_cellar_u[0] = 10
	storage.refresh()
	var pantry := PantryScript.new(storage)
	assert_true(pantry.add_into(WHEAT, 400000, 0, _read), "the covered store full")
	assert_true(pantry.reserve_near_into(CARROT, 5100, Vector2.ZERO, _read), "reserved")
	var hold: int = _read.value
	assert_true(pantry.hold_location_into(hold, _read), "held")
	assert_equal(_read.value, 1, "in the cellar")
	assert_false(pantry.add_into(CARROT, 5000, 1, _read), "the reserved room is not free")
	assert_true(pantry.add_into(CARROT, 4900, 1, _read), "the rest is")
	assert_true(pantry.store_upto_into(CARROT, 5100, 1, hold, _read), "delivered")
	assert_equal(_read.value, 5100, "the reservation takes all of it")
	pantry.release(hold)
	assert_false(pantry.reserve_near_into(CARROT, 1, Vector2.ZERO, _read), "full")
	assert_false(pantry.store_upto_into(CARROT, 100, 7, hold, _read), "no such store")
	assert_equal(_read.error, PantryScript.REFUSE_NO_LOCATION, "says so, not 'nothing fitted'")


func test_a_store_whose_lot_table_is_full_is_not_offered() -> void:
	"""Every lot row taken -- one carrot lot in the covered store, radish in the cellar: the cellar has
	room but nowhere to keep a carrot lot, so a carrot delivery is not sent (or reserved) there but merges
	in the covered store; a radish one, merging, still goes to the cellar."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [{"id": &"c", "position": Vector2.ZERO, "capacity_u": 400,
		"spoilage_permille": 350}])
	storage.refresh()
	var pantry := PantryScript.new(storage)
	assert_true(pantry.add_into(CARROT, 10, 0, _read), "a carrot lot")
	for lot: int in PantryScript.MAX_LOTS - 1:
		assert_true(pantry.add_into(0, 10, 1, _read), "a radish lot")
	assert_equal(pantry.lot_count(), PantryScript.MAX_LOTS, "every row taken")
	assert_true(pantry.location_for_into(1000, _read), "room in plenty")
	assert_true(pantry.location_for_item_into(0, 1000, _read) and _read.value == 1, "radish merges in the cellar")
	assert_true(pantry.location_for_item_into(CARROT, 1000, _read), "carrots merge in the covered store")
	assert_equal(_read.value, 0, "not the cellar")
	assert_true(pantry.reserve_near_into(CARROT, 1000, Vector2.ZERO, _read), "reserved")
	assert_true(pantry.hold_location_into(_read.value, _read) and _read.value == 0, "in the covered store")


# --- F24: cancelling lets the carrier finish its delivery --------------------------------------------

func test_cancelling_a_harvest_mid_carry_credits_the_store_on_arrival() -> void:
	"""Cancelled while its carrier walks: nothing is credited at the cancel; the carrier walks on and
	the store holds the 5.1 U once it gets there."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var hauling := func() -> bool: return crew.jobs.current_step(0) == FarmJobs.STEP_CARRY_STORE and crew.jobs.issued[0] == 1
	assert_true(_run(cast, crew, 90.0, hauling), "carrying")
	var store: Vector2 = pantry.storage.position_of(0)
	assert_true(_brain(cast, 3).position.distance_to(store) > 5.0, "far from the store")
	assert_equal(crew.cancel_bed(BED_CARROTS), 1, "the harvest cancelled")
	assert_equal(pantry.milli_of(CARROT), 0, "nothing credited at the cancel")
	assert_equal(_carried(crew), CARROT_YIELD, "still carried")
	assert_equal(crew.cancel_bed(BED_CARROTS), 0, "a delivery is not production: nothing more to cancel")
	assert_true(_run(cast, crew, 90.0, func() -> bool: return pantry.milli_of(CARROT) > 0), "delivered")
	assert_true(_brain(cast, 3).position.distance_to(store) < 3.0, "by the carrier, at the store")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it")
	_run(cast, crew, 2.0, func() -> bool: return false)
	assert_equal(crew.jobs.live_count(), 0, "and the job is over")


func test_an_order_mid_delivery_keeps_the_load_and_the_carrier_comes_back() -> void:
	"""A cancelled harvest's carrier ordered away: the load stays with the job, nothing is credited, and
	the carrier's resume queue brings it back to finish the walk."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, _walking_it.bind(crew)), "carrying")
	crew.cancel_bed(BED_CARROTS)
	var brain := _brain(cast, 3)
	brain.order_move(brain.position + Vector2(-2.0, 0.0))
	assert_true(_run(cast, crew, 5.0, func() -> bool: return not brain.unfinished_labels().is_empty()), "left the job")
	assert_equal(crew.jobs.worker[0], FarmJobs.NOBODY, "the delivery waits")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "the load kept")
	assert_equal(pantry.milli_of(CARROT), 0, "nothing credited")
	brain.work_done()
	assert_equal(crew.jobs.worker[0], 3, "taken back by the same carrier")
	assert_true(_run(cast, crew, 90.0, func() -> bool: return crew.jobs.live_count() == 0), "delivered")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it, once")


func test_a_delivery_left_on_the_board_goes_to_the_routine_crew() -> void:
	"""Reassignment: the carrier released (forgetting its jobs), the routine crew takes the waiting
	delivery and finishes it. Conserved throughout."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array([0]))
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, _walking_it.bind(crew)), "carrying")
	_brain(cast, 3).release()
	assert_true(_run(cast, crew, 5.0, func() -> bool: return crew.jobs.worker[0] == 0), "the routine crew took it")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "the load went with the job")
	assert_true(_run(cast, crew, 120.0, func() -> bool: return crew.jobs.live_count() == 0), "delivered")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it")


func test_cancelling_before_the_cut_frees_its_reservation() -> void:
	"""A harvest cancelled while it is being cut: the crop stands, and the room it had reserved is free
	again."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	assert_true(pantry.add_into(WHEAT, 394000, 0, _read), "room for one harvest")
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var cutting := func() -> bool: return crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_HARVEST \
		and crew.jobs.issued[0] == 1
	assert_true(_run(cast, crew, 60.0, cutting), "cutting")
	assert_false(pantry.location_for_into(1000, _read), "its room reserved")
	assert_equal(crew.cancel_bed(BED_CARROTS), 1, "cancelled")
	assert_true(pantry.location_for_into(5100, _read), "the room free again")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "the crop stands")


# --- F24 in the woods -------------------------------------------------------------------------------

func _forestry() -> ForestryScript:
	"""The woods over the placeholder cast in the real layout, no routine crew."""
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


func _woods_run(forestry: ForestryScript, done: Callable) -> bool:
	"""Step the cast and the woods until `done()` (bounded)."""
	var cast: DemoCastScript = forestry._cast
	for frame: int in WOODS_FRAMES:
		if bool(done.call()):
			return true
		cast.advance(WOODS_DT)
		forestry.step(cast.clock.frame_usec)
	return bool(done.call())


func _wood_carried(forestry: ForestryScript) -> int:
	"""Wood and planks in every woods job's arms, milli-U."""
	var held: int = 0
	for row: int in ForestJobs.MAX_JOBS:
		if forestry.crew.jobs.is_live(row):
			held += forestry.crew.jobs.load_milli[row]
	return held


func test_cancelling_a_haul_mid_carry_stacks_it_on_arrival() -> void:
	"""A blown-down oak's haul cancelled with a load in hand: the stores are not credited at the cancel;
	the hauler carries it to the log stack, and does not go back for another."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	var stores: int = _services.stores.wood_milli_u
	var trunk: int = forestry.stand.trunk_milli[WEST_OAK]
	forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([2]))
	var carrying := func() -> bool: return forestry.crew.jobs.load_milli[0] > 0 \
		and forestry.crew.jobs.current_step(0) == ForestJobs.STEP_CARRY_STACK and forestry.crew.jobs.issued[0] == 1
	assert_true(_woods_run(forestry, carrying), "a load on its way")
	var carried_milli: int = forestry.crew.jobs.load_milli[0]
	assert_equal(forestry.crew.cancel_all(), 1, "the haul cancelled")
	assert_equal(forestry.crew.cancel_all(), 0, "a delivery is not cancelled")
	assert_equal(_services.stores.wood_milli_u, stores, "nothing credited at the cancel")
	assert_equal(_wood_carried(forestry), carried_milli, "still carried")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u, stores + carried_milli, "on arrival")
	assert_equal(forestry.stand.trunk_milli[WEST_OAK], trunk - carried_milli, "no second load taken")
	var brain: BrainScript = forestry.crew.brain_of(2)
	assert_true(brain.position.distance_to(Yard.log_stack_at()) < 4.0, "at the log stack")


func test_a_sawing_cancelled_with_logs_carries_them_back_and_planks_on() -> void:
	"""Logs in hand: carried back to the log stack, credited there. Planks in hand: carried on to the
	plank stack, credited there. Neither at the cancel."""
	var forestry := _forestry()
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.load_milli[0] > 0), "logs in hand")
	forestry.crew.cancel_all()
	assert_equal(_services.stores.wood_milli_u, 38000, "not back at the cancel")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "carried back")
	assert_equal(_services.stores.wood_milli_u, 40000, "the logs went back")
	assert_equal(_services.stores.plank_milli_u, 0, "no planks")
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	var planks := func() -> bool: return forestry.crew.jobs.current_step(0) == ForestJobs.STEP_CARRY_PLANKS
	assert_true(_woods_run(forestry, planks), "planks in hand")
	forestry.crew.cancel_all()
	assert_equal(_services.stores.plank_milli_u, 0, "not stacked at the cancel")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "carried on")
	assert_equal(_services.stores.wood_milli_u, 38000, "the logs were sawn")
	assert_equal(_services.stores.plank_milli_u, 2000, "the planks stacked on arrival")


func test_a_hauler_called_away_keeps_its_load_and_comes_back() -> void:
	"""A hauler with logs ordered away: the load waits with the job and the hauler's resume queue brings
	it back to stack them. Wood is conserved: trunk + carried + stores."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	var total: int = _services.stores.wood_milli_u + forestry.stand.trunk_milli[WEST_OAK]
	forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([2]))
	var carrying := func() -> bool: return forestry.crew.jobs.load_milli[0] > 0 and forestry.crew.jobs.issued[0] == 1
	assert_true(_woods_run(forestry, carrying), "loaded and walking")
	forestry.crew.cancel_all()
	var brain: BrainScript = forestry.crew.brain_of(2)
	brain.order_move(brain.position + Vector2(-2.0, 0.0))
	assert_true(_woods_run(forestry, func() -> bool: return not brain.unfinished_labels().is_empty()), "left it")
	assert_equal(_services.stores.wood_milli_u + forestry.stand.trunk_milli[WEST_OAK] + _wood_carried(forestry), total,
		"conserved while it waits")
	brain.work_done()
	assert_equal(forestry.crew.jobs.worker[0], 2, "taken back")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u + forestry.stand.trunk_milli[WEST_OAK], total, "all of it")


# --- F25: sapling compost is paid once per job --------------------------------------------------------

func test_planting_interrupted_and_transferred_pays_its_compost_once() -> void:
	"""Planting starts (0.25 U paid), its planter is ordered away, another resident takes the job, is
	itself ordered away, and a third finishes: one sapling, 0.25 U spent."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	forestry.stand.take_trunk_into(WEST_OAK, 12000, _read)
	var compost := PackedInt64Array([1000])
	forestry.crew.set_compost(func() -> int: return compost[0], func(milli: int) -> bool:
		if compost[0] < milli:
			return false
		compost[0] -= milli
		return true)
	forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	for who: int in [0, 1]:
		assert_true(_woods_run(forestry, func() -> bool: return compost[0] < 1000 and _planting(forestry)), "planting")
		var brain: BrainScript = forestry.crew.brain_of(who)
		brain.order_move(brain.position + Vector2(-3.0, 0.0))
		assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.worker[0] == ForestJobs.NOBODY), "left")
		brain.release()
		assert_equal(compost[0], 750, "paid once so far")
		forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([who + 1]))
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "planted")
	assert_equal(compost[0], 750, "0.25 U in all")
	assert_equal(forestry.stand.state_of(WEST_OAK), StandScript.STATE_YOUNG, "one sapling")
	forestry.stand.blow_down_into(NORTH_OAK, 1, Vector2.UP, _read)
	forestry.stand.take_trunk_into(NORTH_OAK, 12000, _read)
	forestry.order_on(PickScript.KIND_TREE, NORTH_OAK, PackedInt32Array([3]))
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "a second planting")
	assert_equal(compost[0], 500, "a new job in the same row pays its own")


func test_planting_with_only_its_own_compost_can_be_resumed() -> void:
	"""Exactly 0.25 U to hand: paid at the start, the planter called away, the job taken up again --
	it is not refused for want of compost it already paid."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	forestry.stand.take_trunk_into(WEST_OAK, 12000, _read)
	var compost := PackedInt64Array([250])
	forestry.crew.set_compost(func() -> int: return compost[0], func(milli: int) -> bool:
		if compost[0] < milli:
			return false
		compost[0] -= milli
		return true)
	forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	assert_true(_woods_run(forestry, func() -> bool: return compost[0] == 0 and _planting(forestry)), "paid, planting")
	var brain: BrainScript = forestry.crew.brain_of(0)
	brain.order_move(brain.position + Vector2(-3.0, 0.0))
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.worker[0] == ForestJobs.NOBODY), "left")
	var said: String = forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([1]))
	assert_equal(said, "Plant a sapling: Placeholder 1 is on it", "taken up again")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "planted")
	assert_equal(forestry.stand.state_of(WEST_OAK), StandScript.STATE_YOUNG, "one sapling")
	assert_equal(compost[0], 0, "no second payment")


func test_a_harvest_card_waits_for_room_as_its_order_does() -> void:
	"""The harvest's action card (decision 0332) reads the order's own room test (decision 0222): with no store room
	it names nobody and says the harvest waits and how much has nowhere to go -- the order's words; the order then
	queues it waiting; once there is room the card names the resident the order sends."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array([0]))
	assert_true(pantry.add_into(WHEAT, 399000, 0, _read), "the store nearly full")
	var card := ActionCard.new()
	crew.preview_into(card, FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]))
	assert_true(card.is_ok(), "not refused: the order queues it")
	assert_equal(card.worker, ActionCard.NOBODY, "nobody is sent")
	assert_true(card.who.contains("no store has room for 6 bunches of carrots"), "it waits for room: " + card.who)
	var said: String = crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(said.contains(FarmCrewScript.room_words(CARROT_YIELD, CARROT)), "the order's words are the card's: " + said)
	assert_equal(crew.jobs.worker[0], FarmJobs.NOBODY, "the order sent nobody either")
	crew.preview_into(card, FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]))
	assert_true(card.who.contains("no store has room"), "queued, still waiting: " + card.who)
	assert_true(crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]),
		FarmJobs.ORIGIN_PLAYER).begins_with("Harvest waits: no store has room"), "ordered again: it waits")
	_cellar_u[0] = 10
	pantry.refresh_locations()
	crew.preview_into(card, FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]))
	assert_equal(card.worker, 3, "room now: the card names the resident")
	assert_equal(crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER),
		"Harvest: %s is on it" % crew.worker_name(0), "and the order sends it")
	assert_equal(crew.jobs.worker[0], 3, "resident 3")


func test_a_paid_plantings_card_needs_no_compost() -> void:
	"""Joining a planting that has paid its compost (decision 0222) takes none: its card's compost row needs 0."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	forestry.stand.take_trunk_into(WEST_OAK, 12000, _read)
	var compost := PackedInt64Array([250])
	forestry.crew.set_compost(func() -> int: return compost[0], func(milli: int) -> bool:
		if compost[0] < milli:
			return false
		compost[0] -= milli
		return true)
	var card := ActionCard.new()
	forestry.crew.preview_into(card, ForestJobs.KIND_PLANT, WEST_OAK, 0, PackedInt32Array([0]))
	assert_equal([card.cost_have[0], card.cost_need[0]], [250, Rules.PLANT_COMPOST_MILLI], "unpaid: 0.25 U needed")
	forestry.order_on(PickScript.KIND_TREE, WEST_OAK, PackedInt32Array([0]))
	assert_true(_woods_run(forestry, func() -> bool: return compost[0] == 0 and _planting(forestry)), "paid, planting")
	var brain: BrainScript = forestry.crew.brain_of(0)
	brain.order_move(brain.position + Vector2(-3.0, 0.0))
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.worker[0] == ForestJobs.NOBODY), "left")
	forestry.crew.preview_into(card, ForestJobs.KIND_PLANT, WEST_OAK, 0, PackedInt32Array([1]))
	assert_true(card.is_ok(), "joinable")
	assert_equal([card.cost_have[0], card.cost_need[0]], [0, 0], "paid already: nothing needed")
	assert_true(card.result.contains("paid already"), card.result)


func _planting(forestry: ForestryScript) -> bool:
	"""Whether job 0 is at its planting work, begun."""
	return forestry.crew.jobs.is_live(0) and forestry.crew.jobs.issued[0] == 1 \
		and forestry.crew.jobs.current_step(0) == ForestJobs.STEP_WORK + ForestJobs.WORK_PLANT


# --- F27: the forecast is in calendar hours ---------------------------------------------------------

func _store_pantry() -> PantryScript:
	"""A pantry with the covered store and a 60 U cellar at the GDD's cellar factor."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [{"id": &"c", "position": Vector2.ZERO, "capacity_u": 60,
		"spoilage_permille": 350, "label": "Root cellar"}])
	return PantryScript.new(storage)


func test_the_spoil_forecast_counts_calendar_hours_at_the_seasons_rate() -> void:
	"""Roots (240 h shelf) in the covered store in summer (×1.5): 160 calendar hours, and ageing 160
	summer hours does spoil them -- 159 does not."""
	var pantry := _store_pantry()
	pantry.add_into(CARROT, 5100, 0, _read)
	assert_true(pantry.next_spoil_into(CARROT, SUMMER_HOUR, _read), "a forecast")
	assert_equal(_read.value, 160, "160 h in summer")
	for hour: int in 159:
		pantry.age_hour(1)
	assert_equal(pantry.milli_of(CARROT), 5100, "not yet at 159 h")
	pantry.age_hour(1)
	assert_equal(pantry.milli_of(CARROT), 0, "spoiled at the 160th")


func test_the_spoil_forecast_crosses_a_season_change() -> void:
	"""100 spring hours (×1.0) take 100 h of shelf; the 140 h left go at summer's ×1.5: 94 more hours.
	Ageing hour by hour at each crossing's own season spoils them at the 194th."""
	var pantry := _store_pantry()
	pantry.add_into(CARROT, 5100, 0, _read)
	assert_true(pantry.next_spoil_into(CARROT, LATE_SPRING_HOUR, _read), "a forecast")
	assert_equal(_read.value, 194, "100 + 94")
	for crossing: int in range(1, 194):
		pantry.age_hour(PantryScript.season_of_hour(LATE_SPRING_HOUR + crossing))
	assert_equal(pantry.milli_of(CARROT), 5100, "still there after 193")
	pantry.age_hour(PantryScript.season_of_hour(LATE_SPRING_HOUR + 194))
	assert_equal(pantry.milli_of(CARROT), 0, "spoiled at the 194th")


func test_the_pantry_row_names_the_next_lot_to_spoil() -> void:
	"""Two carrot lots, a young one in the cellar (×0.35) and an older one in the covered store: a row per
	store (decision 0292), each naming its own next lot to spoil and its hours."""
	var sim := SimScript.new()
	var pantry := _store_pantry()
	pantry.add_into(CARROT, 2000, 0, _read)
	for hour: int in 40:
		pantry.age_hour(0)
	pantry.add_into(CARROT, 3100, 1, _read)
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, pantry, null)
	panel.toggle()
	assert_true(pantry.next_spoil_into(CARROT, sim.calendar.hour_index(), _read), "a forecast")
	assert_equal(_read.value, 200, "the covered store's lot: 200 spring hours")
	assert_equal(panel.shown_stock_row(0), PackedStringArray(["Carrot", "2 bunches", "—", "Covered store", "all in 8d 8h"]),
		"the covered store's lot: 200 h")
	assert_equal(panel.shown_stock_row(1), PackedStringArray(["Carrot", "3 bunches", "—", "Root cellar", "all in 22d 23h"]),
		"the cellar's: 281 spring hours at ×0.35, then 270 at summer's ×0.525 = 551 h")


# --- F28: figures sum milli-units, and read the same everywhere ----------------------------------------

func test_units_read_with_one_decimal_and_never_hide_a_little() -> void:
	"""The one formatter: tenths, floored; nothing is '0 U'; below a tenth is '<0.1 U'."""
	assert_equal(Text.units_text(0), "0 U", "none")
	assert_equal(Text.units_text(50), "<0.1 U", "a little")
	assert_equal(Text.units_text(100), "0.1 U", "a tenth")
	assert_equal(Text.units_text(900), "0.9 U", "under one")
	assert_equal(Text.units_text(5100), "5.1 U", "a harvest")
	assert_equal(Text.units_text(400000), "400.0 U", "a capacity")
	assert_equal(HudScript.food_text(14400), "14.4 U", "the HUD's Food cell")
	assert_equal(HudScript.food_text(400), "0.4 U", "a nearly empty pantry is not 0")


func test_fractional_stock_sums_before_it_is_rounded() -> void:
	"""0.9 U of each of the 16 ingredients: 14.4 U in the header, 0.9 U on each row, 14.4 U stored of
	400.0 U on the store's row -- the same figure three ways."""
	var sim := SimScript.new()
	var pantry := PantryScript.new(StorageScript.new())
	for item: int in Catalog.ITEM_COUNT:
		assert_true(pantry.add_into(item, 900, 0, _read), "stocked")
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, pantry, null)
	panel.toggle()
	assert_equal(pantry.total_milli(), 14400, "the authoritative total")
	assert_true(panel.total_text().begins_with("2½ baskets of food in store"), "header: " + panel.total_text())
	assert_equal(panel.stock_row_count(), Catalog.ITEM_COUNT, "a row each")
	assert_equal(panel.shown_stock_row(CARROT).slice(0, 2), PackedStringArray(["Carrot", "225 g"]), "row: 0.9 U of carrots is under a bunch, so its weight")
	assert_equal(panel.store_row_cells(0), PackedStringArray(["Covered store", "2½ baskets", "none", "77 baskets", "80 baskets", "×1.00"]),
		"store row")


func test_a_delivery_that_cannot_get_through_waits_with_its_load() -> void:
	"""The only store with room stands where nobody can reach: the harvest is cut (its room is there) but
	the carry walk finds no way. The job is not closed -- it waits on the board with the load, passed over
	by the routine crew until the next hour lifts the block."""
	var cast := _cast()
	var sim := _ripe_carrots()
	_cellar_u[0] = 10
	_cellar_at = Vector2(500.0, 500.0)
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array([0]))
	assert_true(pantry.add_into(WHEAT, 400000, 0, _read), "the covered store full")
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, func() -> bool: return _said("no way through")), "no way to the store")
	assert_equal(crew.jobs.live_count(), 1, "the job kept")
	assert_equal(crew.jobs.worker[0], FarmJobs.NOBODY, "its worker free")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "the load kept with it")
	var tries: int = _count_said("no way through")
	_run(cast, crew, 3.0, func() -> bool: return false)
	assert_equal(_count_said("no way through"), tries, "passed over until the hour")
	crew.raise_routine_jobs()
	assert_true(_run(cast, crew, 3.0, func() -> bool: return _count_said("no way through") > tries), "tried again after it")
	assert_equal(_all_carrots(sim, crew, pantry), CARROT_YIELD, "and still kept")


func test_a_stale_resume_does_not_take_a_new_job_in_the_same_row() -> void:
	"""A resume is bound to its job's serial: once that job is over and its row holds another, the old
	resume gives nothing back."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	var old: int = crew.jobs.serial[0]
	crew.cancel_bed(BED_CARROTS)
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array(), FarmJobs.ORIGIN_PLAYER)
	assert_true(crew.jobs.is_live(0) and crew.jobs.serial[0] != old, "a new job in row 0")
	assert_false(crew.take_back(_brain(cast, 3), 0, old), "not taken by the old resume")
	assert_true(crew.take_back(_brain(cast, 3), 0, crew.jobs.serial[0]), "taken by its own")


func test_cancelling_during_the_drop_keeps_the_drop() -> void:
	"""A harvest cancelled while it is being put down stays at its drop (no walk again) and is stored."""
	var cast := _cast()
	var sim := _ripe_carrots()
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	var dropping := func() -> bool: return crew.jobs.current_step(0) == FarmJobs.STEP_WORK + FarmJobs.WORK_DROP \
		and crew.jobs.issued[0] == 1
	assert_true(_run(cast, crew, 120.0, dropping), "putting it down")
	crew.cancel_bed(BED_CARROTS)
	assert_equal(crew.jobs.current_step(0), FarmJobs.STEP_WORK + FarmJobs.WORK_DROP, "still at the drop")
	assert_equal(crew.jobs.issued[0], 1, "not walked again")
	assert_true(_run(cast, crew, 10.0, func() -> bool: return crew.jobs.live_count() == 0), "stored")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it")


func test_a_reservation_follows_its_store_and_knows_when_it_has_gone() -> void:
	"""Holds are kept by store id across a refresh: the first test store removed, a hold at the second
	moves with it to its new index; the second removed, the hold answers STORAGE_LOCATION_GONE."""
	var storage := StorageScript.new()
	storage.add_provider(_test_stores.bind(Vector2.ZERO))
	var pantry := PantryScript.new(storage)
	_cellar_u[0] = 10
	_cellar_u[1] = 10
	pantry.refresh_locations()
	assert_true(pantry.add_into(WHEAT, 400000, 0, _read), "the covered store full")
	assert_true(pantry.add_into(WHEAT, 10000, 1, _read), "the first test store full")
	assert_true(pantry.reserve_near_into(CARROT, 4000, Vector2.ZERO, _read), "reserved")
	var hold: int = _read.value
	assert_true(pantry.hold_location_into(hold, _read) and _read.value == 2, "at the second test store")
	_cellar_u[0] = 0
	pantry.refresh_locations()
	assert_true(pantry.hold_location_into(hold, _read), "still standing")
	assert_equal(_read.value, 1, "followed its store to index 1")
	assert_equal(pantry.room_milli_of(1), 6000, "and still keeps its room there")
	_cellar_u[1] = 0
	pantry.refresh_locations()
	assert_false(pantry.hold_location_into(hold, _read), "its store has gone")
	assert_equal(_read.error, PantryScript.REFUSE_GONE, "says so")


func test_the_forecast_matches_ageing_hour_by_hour() -> void:
	"""Odd store factors (a half-milli-hour remainder), lots already part-aged, starts in every season and
	across the year's end: the forecast is exactly the crossing at which `age_hour` spoils the lot. (625
	from summer hour 300 is a case where the carried half milli-hour decides the crossing.)"""
	for permille: int in [333, 1000, 351, 625]:
		for start: int in [6, 280, 300, 1100, 861]:
			var storage := StorageScript.new()
			storage.add_provider(func() -> Array: return [{"id": &"odd", "position": Vector2.ZERO, "capacity_u": 60,
				"spoilage_permille": permille}])
			var pantry := PantryScript.new(storage)
			pantry.add_into(CARROT, 1000, 1, _read)
			for hour: int in 3:
				pantry.age_hour(PantryScript.season_of_hour(start - 2 + hour))
			assert_true(pantry.next_spoil_into(CARROT, start, _read), "a forecast")
			var forecast: int = _read.value
			var crossing: int = 0
			while pantry.milli_of(CARROT) > 0 and crossing < 5000:
				crossing += 1
				pantry.age_hour(PantryScript.season_of_hour(start + crossing))
			assert_equal(crossing, forecast, "permille %d from hour %d" % [permille, start])


func test_a_sawing_cancelled_at_the_sawhorse_carries_the_logs_back() -> void:
	"""Cancelled while the logs are being sawn: they are still logs, carried back to the log stack."""
	var forestry := _forestry()
	forestry.order_on(PickScript.KIND_SAW, -1, PackedInt32Array([3]))
	var sawing := func() -> bool: return forestry.crew.jobs.current_step(0) == ForestJobs.STEP_WORK + ForestJobs.WORK_SAW \
		and forestry.crew.jobs.issued[0] == 1
	assert_true(_woods_run(forestry, sawing), "sawing")
	forestry.crew.cancel_all()
	assert_equal(forestry.crew.jobs.kind[0], ForestJobs.KIND_CARRY_LOGS, "logs, carried back")
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.live_count() == 0), "stacked")
	assert_equal(_services.stores.wood_milli_u, 40000, "the logs went back")
	assert_equal(_services.stores.plank_milli_u, 0, "no planks")


func test_a_woods_job_that_cannot_get_through_keeps_its_load() -> void:
	"""A hauler's job ended for want of a way while it carries logs: not closed -- it waits on the board
	with the load, passed over by the crew until the next hour, and nothing is credited."""
	var forestry := _forestry()
	forestry.stand.blow_down_into(WEST_OAK, 1, Vector2.UP, _read)
	var stores: int = _services.stores.wood_milli_u
	forestry.order_on(PickScript.KIND_TRUNK, WEST_OAK, PackedInt32Array([2]))
	var carrying := func() -> bool: return forestry.crew.jobs.load_milli[0] > 0 and forestry.crew.jobs.issued[0] == 1
	assert_true(_woods_run(forestry, carrying), "carrying")
	var carried_milli: int = forestry.crew.jobs.load_milli[0]
	forestry.crew.set_crew(PackedInt32Array([1]))
	forestry.crew.finish(0, "Haul logs: no way through to it")
	assert_true(forestry.crew.jobs.is_live(0), "the job kept")
	assert_equal(forestry.crew.jobs.load_milli[0], carried_milli, "with its load")
	assert_equal(_services.stores.wood_milli_u, stores, "nothing credited")
	assert_false(forestry.crew.take_back(forestry.crew.brain_of(2), 0, forestry.crew.jobs.serial[0]),
		"nor taken back before the hour")
	var frames: Array[int] = [0]
	_woods_run(forestry, func() -> bool:
		frames[0] += 1
		return frames[0] > 30)
	assert_equal(forestry.crew.jobs.worker[0], ForestJobs.NOBODY, "passed over until the hour")
	forestry.crew.raise_routine_jobs()
	assert_true(_woods_run(forestry, func() -> bool: return forestry.crew.jobs.worker[0] == 1), "tried again after it")


func test_a_waiting_carrier_called_away_resumes_toward_the_store_with_room() -> void:
	"""A carrier waiting with the rest of a load at a full store is called away; room appears in another
	store; taking the delivery back, it walks straight to the store with room, not back to the full one."""
	var cast := _cast()
	var sim := _ripe_carrots()
	_cellar_u[0] = 10
	var pantry := _pantry(cast)
	var crew := _crew(cast, sim, pantry, PackedInt32Array())
	assert_true(pantry.add_into(WHEAT, 400000, 0, _read), "the covered store full")
	crew.order(FarmJobs.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), FarmJobs.ORIGIN_PLAYER)
	assert_true(_run(cast, crew, 90.0, func() -> bool: return _carried(crew) > 0), "cut and carried")
	_cellar_u[0] = 3
	pantry.refresh_locations()
	assert_true(_run(cast, crew, 90.0, func() -> bool: return _said("store has room for the rest")), "waiting")
	var brain := _brain(cast, 3)
	brain.order_move(brain.position + Vector2(-2.0, 0.0))
	assert_true(_run(cast, crew, 5.0, func() -> bool: return crew.jobs.worker[0] == FarmJobs.NOBODY), "called away")
	_cellar_u[1] = 10
	pantry.refresh_locations()
	brain.work_done()
	assert_equal(crew.jobs.worker[0], 3, "taken back once there is room")
	assert_true(_run(cast, crew, 5.0, _walking_it.bind(crew)), "walking")
	assert_equal(crew.jobs.location[0], 2, "straight to the store with room")
	assert_true(_run(cast, crew, 90.0, func() -> bool: return crew.jobs.live_count() == 0), "delivered")
	assert_equal(pantry.milli_of(CARROT), CARROT_YIELD, "all of it")


func test_a_stale_woods_resume_does_not_take_a_new_job_in_the_same_row() -> void:
	"""The woods' resume is bound to its job's serial too."""
	var forestry := _forestry()
	var brain: BrainScript = forestry.crew.brain_of(1)
	forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	var old: int = forestry.crew.jobs.serial[0]
	forestry.crew.cancel_all()
	forestry.crew.order(ForestJobs.KIND_FELL, NORTH_OAK, 0, PackedInt32Array(), ForestJobs.ORIGIN_PLAYER)
	assert_true(forestry.crew.jobs.is_live(0) and forestry.crew.jobs.serial[0] != old, "a new job in row 0")
	assert_false(forestry.crew.take_back(brain, 0, old), "not taken by the old resume")
	assert_true(forestry.crew.take_back(brain, 0, forestry.crew.jobs.serial[0]), "taken by its own")


func test_the_first_to_spoil_is_not_the_oldest() -> void:
	"""An older lot in the cellar (×0.35) and a fresh one in the covered store: the fresh one spoils
	first -- 240 h against the cellar lot's hundreds -- and its store's row says so."""
	var sim := SimScript.new()
	var pantry := _store_pantry()
	pantry.add_into(CARROT, 3000, 1, _read)
	for hour: int in 40:
		pantry.age_hour(0)
	pantry.add_into(CARROT, 2000, 0, _read)
	assert_true(pantry.first_to_spoil_into(CARROT, sim.calendar.hour_index(), _read), "a lot")
	assert_equal(pantry.lot_location(_read.value), 0, "the covered store's, though it is the younger")
	var panel := PantryPanelScript.new()
	_nodes.append(panel)
	panel.configure(sim, pantry, null)
	panel.toggle()
	assert_equal(panel.shown_stock_row(0), PackedStringArray(["Carrot", "2 bunches", "—", "Covered store", "all in 10d"]),
		"the covered store's row: 240 h")
	assert_true(pantry.first_to_spoil_at_into(CARROT, 1, sim.calendar.hour_index(), _read), "the cellar's lot")
	assert_true(pantry.lot_spoil_hours(_read.value, sim.calendar.hour_index()) > 240, "spoils later")
	assert_equal(panel.shown_stock_row(1)[3], "Root cellar", "on its own row")


func test_a_delivery_without_a_reservation_never_borrows_anothers() -> void:
	"""A drop with no reservation of its own (FREE) gets only the free room: every hold row taken, the
	last one at the covered store, the store otherwise full -- nothing fits, and that hold keeps its room."""
	var pantry := PantryScript.new(StorageScript.new())
	assert_true(pantry.add_into(WHEAT, 400000 - PantryScript.MAX_HOLDS * 1000, 0, _read), "nearly full")
	for hold: int in PantryScript.MAX_HOLDS:
		assert_true(pantry.reserve_near_into(CARROT, 1000, Vector2.ZERO, _read), "a hold")
	assert_true(pantry.store_upto_into(CARROT, 1000, 0, FarmJobs.FREE, _read), "a drop")
	assert_equal(_read.value, 0, "nothing fits without a reservation")
	assert_equal(pantry.hold_milli(PantryScript.MAX_HOLDS - 1), 1000, "the last hold keeps its room")


func test_a_job_handed_to_someone_tries_its_walk_afresh() -> void:
	"""The farm board: a job given (back) to a resident starts its walk's tries at nothing, so a delivery
	tried again after a wait stands where a fresh one would."""
	var jobs := FarmJobs.new()
	assert_true(jobs.open_into(FarmJobs.KIND_HARVEST, BED_CARROTS, FarmJobs.ORIGIN_PLAYER, _read), "a job")
	jobs.tries[_read.value] = 2
	jobs.assign(_read.value, 1)
	assert_equal(jobs.tries[_read.value], 0, "tries reset")
