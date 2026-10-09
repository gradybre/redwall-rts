extends "res://test/framework/test_case.gd"
## Water part B (decisions 0431-0436): the fishery's numbers, the boat core, the real gear, the pond's ice, and
## whole trips on real brains walking the real village layout -- a hand net from the bank, a boat from the jetty, ice
## fishing -- each catch debited from the real fishing store and landed in the pantry; the rack, the mill and the
## workbench; the boat rescue; and every cancel and interruption conserving the books: everything caught is in a
## store or in a hand, no cycle, gear claim, slot or held room is left behind.
##
## Built over the placeholder cast on the real layout and the real village water (as test_demo_water_play.gd) --
## no staged assets, no scene tree. Expected numbers are restated from their sources (GDD §5.4/§5.7/§5.9, gear.gd,
## fishery_rules.gd's named demo values).

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const LockerScript := preload("res://demo/fishery/gear_locker.gd")
const SkillsScript := preload("res://demo/fishery/fish_skills.gd")
const IceScript := preload("res://demo/fishery/pond_ice.gd")
const Text := preload("res://demo/fishery/fishery_text.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const BoatRescueScript := preload("res://demo/boats/boat_rescue.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const FisheryWork := preload("res://demo/work/fishery_work.gd")
const RescueCardScript := preload("res://demo/routes/rescue_card.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 6000

## The rig: the placeholder cast on the village water, the water's play, and the fishery over a fresh pantry.
class Rig:
	var cast: DemoCastScript = null
	var play: WaterplayScript = null
	var fishery: FisheryScript = null
	var pantry: PantryScript = null
	var takes: TakesScript = null
	var calendar: CalendarScript = null
	var weather: DemoWeatherScript = null
	var driver: Driver = null
	var boats: BoatRescueScript = null

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


# --- fixtures -------------------------------------------------------------------------------------

func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water, built once (immutable once finalised)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _rig() -> Rig:
	"""The placeholder cast walking the real layout round the water's band, the water's play wired as the village wires
	it, and the fishery over the real fishing driver (06:00 spring 1), a fresh pantry, the stores and a mild weather."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	rig.play = _keep(WaterplayScript.new()) as WaterplayScript
	rig.play.configure(rig.cast, null, null, _services, _map(), links)
	_fishery_over(rig)
	return rig


func _fishery_over(rig: Rig) -> void:
	"""The fishery and its boat rescue on the rig."""
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	assert_true(ids.ok, "the nine fish items bind")
	rig.driver = Driver.create(ids.ids, 0, _weir_width()).driver as Driver
	rig.calendar = CalendarScript.new()
	rig.weather = DemoWeatherScript.new()
	rig.weather.observe(0, 1, 8, 120, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.takes = TakesScript.new()
	rig.fishery = FisheryScript.new()
	rig.fishery.configure(rig.cast, rig.driver, rig.pantry, rig.takes, _services.stores, rig.calendar, rig.weather, _map())
	rig.boats = BoatRescueScript.new()
	rig.boats.configure(rig.fishery.fleet, _map(), rig.fishery.skills.can_helm)
	rig.play.rescue.boats = rig.boats


static func _weir_width() -> int:
	"""The stream's width at the weir (4.3 m, water_layout.gd: a weir is offered there)."""
	return 4403


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES, board: bool = true) -> bool:
	"""Step the cast, the calendar, the fishery store, the water and the fishery until `done()` (bounded) -- and, as the
	work board does (`board`), hand a job left waiting (a worker who could not get through, a load set down) to a free
	resident who may take it."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if board and frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.driver.advance_ticks(maxi(rig.calendar.tick - rig.driver.completed_tick(), 0))
		rig.play.step(usec)
		rig.fishery.update(usec)
		if OS.get_environment("FISHERY_DEBUG") == "1" and frame % 500 == 0:
			_debug(rig, frame)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part (decision 0411): each waiting job to the first idle resident who may take it."""
	var f: FisheryScript = rig.fishery
	for j: int in Tables.MAX_JOBS:
		if not f.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = f.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.in_water and f.eligibility(j, who).is_empty() and f.claim(j, who):
				break


func _debug(rig: Rig, frame: int) -> void:
	"""Print every live job (FISHERY_DEBUG=1)."""
	var f: FisheryScript = rig.fishery
	for j: int in Tables.MAX_JOBS:
		if f.tables.j_live[j] == 1:
			var w: int = f.tables.j_worker[j]
			var b: BrainScript = f.brain_of(w) if w >= 0 else null
			printerr("##ONE## f%d job %d step %d w %d goal %s words '%s' %s" % [frame, j, f.step_of(j), w, f.tables.j_goal[j],
				f.tables.j_words[j], ("state %d pos %s out %d" % [b.state, b.position, b.trip_outcome]) if b != null else ""])


func _helm(rig: Rig, who: int, level: int) -> void:
	"""Give placeholder `who` FISH `level` (the placeholders start at 0)."""
	rig.fishery.skills.xp[who] = level * level * 5000


func _fresh_fish(rig: Rig) -> int:
	"""Every fresh fish in the pantry, milli-U."""
	var total: int = 0
	for k: int in Catalog.CATCH_COUNT:
		total += rig.pantry.milli_of(Catalog.FIRST_CATCH + k)
	return total


func _in_hand(rig: Rig) -> int:
	"""Fish held in hands or set down for the next fisher, milli-U."""
	var total: int = 0
	for j: int in Tables.MAX_JOBS:
		if rig.fishery.tables.j_live[j] == 1 and Catalog.category_of(rig.fishery.tables.j_load_item[j]) == Catalog.CAT_FISH:
			total += rig.fishery.tables.j_load_milli[j]
	return total


func _assert_books(rig: Rig, label: String) -> void:
	"""THE BOOKS: everything caught is in a store or in a hand; the pantry holds exactly what was landed."""
	assert_equal(rig.fishery.caught_milli, rig.fishery.landed_milli + _in_hand(rig), "%s: caught == landed + in hand" % label)
	assert_equal(_fresh_fish(rig), rig.fishery.landed_milli, "%s: the pantry holds what was landed" % label)


func _assert_released(rig: Rig, label: String) -> void:
	"""Nothing left behind: no open cycle in the store, no gear claimed or set aside, no held room in any store, no
	job."""
	assert_equal(rig.driver.open_claims(), 0, "%s: no open fishing cycle" % label)
	for k: int in rig.fishery.locker.count():
		assert_true(rig.fishery.locker.is_free(k), "%s: gear %d free" % [label, k])
		assert_false(rig.fishery.locker.is_claimed(k), "%s: gear %d holds no cycle's claim" % [label, k])
	for at: int in rig.pantry.storage.count():
		assert_equal(rig.pantry.reserved_milli_of(at), 0, "%s: no room held at store %d" % [label, at])
	assert_equal(rig.fishery.tables.job_count(), 0, "%s: no job left" % label)
	assert_equal(rig.fishery.tables.trip_count(), 0, "%s: no trip left" % label)


# --- the numbers -----------------------------------------------------------------------------------

func test_methods_are_the_gdd_gear_rows_in_distinct_roles() -> void:
	"""§5.4: net 60 WU, trap 20 + 20 WU and 6 h, boat 120 party-WU by two, ice 90 WU; each its own role and sites."""
	assert_equal(Rules.METHOD_GEAR, [Fishing.GEAR_HAND_NET, Fishing.GEAR_TRAP, Fishing.GEAR_BOAT, Fishing.GEAR_ICE_KIT], "gear rows")
	assert_equal(Rules.METHOD_WORK_MWU, [60000, 20000, 120000, 90000], "work")
	assert_equal(Rules.TRAP_COLLECT_MWU, 20000, "the trap's collection")
	assert_equal(Rules.TRAP_SOAK_HOURS, 6, "the trap's soak")
	assert_equal(Rules.METHOD_CREW, [1, 1, 2, 1], "crews")
	assert_true(Rules.offers_site(Rules.METHOD_NET, Driver.SITE_RUN) and Rules.offers_site(Rules.METHOD_NET, Driver.SITE_POND), "a net at any bank")
	assert_false(Rules.offers_site(Rules.METHOD_BOAT, Driver.SITE_RUN), "no boat on the stream")
	assert_false(Rules.offers_site(Rules.METHOD_ICE, Driver.SITE_FORD), "no ice on the stream")
	assert_true(Rules.offers_site(Rules.METHOD_ICE, Driver.SITE_POND), "ice on the pond")
	assert_false(Rules.offers_site(4, Driver.SITE_POND), "no fifth method (no line: §5.4 has none)")


func test_work_runs_on_the_calendar_at_the_gdd_rate() -> void:
	"""§5.2: 80 milli-WU a tick at factor 1000 -- 60 WU is a game hour (750 ticks, 25 s); §5.3's 1000 + 50 x level."""
	assert_equal(Rules.work_ticks(60000, 0), 750, "a net cycle is an hour")
	assert_equal(Rules.work_usec(60000, 0), 25000000, "25 s at 1x")
	assert_equal(Rules.work_ticks(60000, 4), 625, "fishing 4 works 1.2x as fast")
	@warning_ignore("integer_division") assert_equal(Rules.mwu_numerator(25000000, 0) / Rules.MWU_DENOMINATOR, 60000, "an hour of demo time is 60 WU")
	@warning_ignore("integer_division") assert_equal(Rules.mwu_numerator(25000000, 4) / Rules.MWU_DENOMINATOR, 72000, "and 72 WU at fishing 4 (factor 1200)")


func test_the_catch_is_six_species_never_eel_pike_shrimp_or_the_coast() -> void:
	"""SET-AMEND-001's whitelist: the river's and the lake's six land as their own items; the coast's three have none
	here; no eel, pike or shrimp item exists in the pantry."""
	for row: int in 6:
		var item: int = Catalog.item_of_species(row)
		assert_true(Catalog.is_pantry_item(item), "%s has an item" % Fishing.SPECIES_KEYS[row])
		assert_equal(Catalog.ITEM_KEYS[item], Fishing.SPECIES_KEYS[row], "the species is the item")
		assert_equal(Catalog.category_of(item), Catalog.CAT_FISH, "in the fish category")
		assert_equal(Catalog.shelf_hours_of(item), 48, "§5.7: 48 h")
	for row: int in [Fishing.SPECIES_HERRING, Fishing.SPECIES_MACKEREL, Fishing.SPECIES_MUSSEL]:
		assert_equal(Catalog.item_of_species(row), Catalog.NO_ITEM, "%s: not caught inland" % Fishing.SPECIES_KEYS[row])
	for key: StringName in [&"eel", &"pike", &"shrimp", &"mussel", &"fish"]:
		assert_false(Catalog.ITEM_KEYS.has(key), "no %s item" % key)
	assert_equal(Catalog.shelf_hours_of(Catalog.ITEM_DRIED_FISH), 720, "dried fish 720 h")
	assert_equal(Catalog.shelf_hours_of(Catalog.ITEM_FLOUR), 240, "flour 240 h")
	assert_equal(Catalog.ITEM_COUNT, 16, "the crops are still sixteen")
	assert_false(Catalog.is_item(Catalog.ITEM_FLOUR), "flour is not a crop")


func test_dried_fish_is_the_reserve_eaten_as_it_is() -> void:
	"""§5.7: dried fish is directly edible (1800 NP/U) -- the raw emergency reserve; fresh fish and flour are not."""
	assert_equal(MealRules.raw_np_per_u(Catalog.ITEM_DRIED_FISH), 1800, "dried fish")
	assert_equal(MealRules.raw_np_per_u(Catalog.FIRST_CATCH), 0, "fresh fish is not eaten raw")
	assert_equal(MealRules.raw_np_per_u(Catalog.ITEM_FLOUR), 0, "nor flour")
	assert_false(MealRules.is_input(MealRules.DISH_PORRIDGE, Catalog.ITEM_FLOUR), "porridge takes grain, not flour (BAL-RATIO-003)")


# --- the gear (real gear.gd) -----------------------------------------------------------------------

func test_the_locker_opens_with_its_stock_as_real_gear() -> void:
	"""The opening stock (DEMO): a hand net, a trap and two tier-2 outfits as real gear rows, 4 U rope and 2 U iron."""
	var locker := LockerScript.new()
	assert_true(locker.open(), "the locker opens over the real item catalog")
	assert_equal([locker.count_of(0), locker.count_of(1), locker.count_of(2), locker.count_of(3)], [1, 1, 0, 2], "gear")
	assert_equal(locker.material_milli(LockerScript.MAT_ROPE), 4000, "rope")
	assert_equal(locker.material_milli(LockerScript.MAT_IRON), 2000, "iron")
	assert_equal(locker.gear_store().active_gear_count(), 4, "four gear rows in gear.gd")
	assert_equal(locker.durability_of(0), 1000, "a net starts full")
	assert_equal([locker.wear_of_kind(0), locker.wear_of_kind(1), locker.wear_of_kind(2), locker.wear_of_kind(3)], [20, 10, 20, 0],
		"§5.4's wear: net 20, trap 10, ice kit 20; an outfit none")


func test_gear_wears_once_per_cycle_and_never_breaks_in_use() -> void:
	"""A claim is the cycle's Job's; completion wears it exactly once, cancellation not at all; below a cycle's wear no
	cycle starts (INSUFFICIENT_DURABILITY) -- worn gear is refused before a trip, never broken during one."""
	var locker := LockerScript.new()
	locker.open()
	var job := Vector2i(5, 1)
	assert_equal(locker.claim(0, job), "", "claimed")
	assert_true(locker.cancel(0, job), "cancelled")
	assert_equal(locker.durability_of(0), 1000, "no wear for a cancelled cycle")
	for n: int in 50:
		assert_equal(locker.claim(0, Vector2i(5, 2 + n)), "", "cycle %d claimed" % n)
		assert_equal(locker.complete(0, Vector2i(5, 2 + n)), 20, "cycle %d wears 20" % n)
	assert_equal(locker.durability_of(0), 0, "fifty cycles wore it out")
	assert_equal(locker.claim(0, Vector2i(5, 99)), "INSUFFICIENT_DURABILITY", "a worn net cannot start a cycle")
	assert_false(locker.pick_into(LockerScript.KIND_NET, _read), "nothing to pick")
	assert_equal(_read.error, "GEAR_WORN", "worn, said as such")
	assert_equal(locker.mend(0), 200, "a mend restores 200")
	assert_true(locker.pick_into(LockerScript.KIND_NET, _read), "mended, it fishes again")
	assert_equal(locker.complete(0, Vector2i(5, 3)), -1, "a second completion of a closed claim takes nothing")


func test_making_gear_spends_the_recipe_and_refuses_short() -> void:
	"""§5.4's costs: a net wood 2 + rope 1, an ice kit wood 2 + iron 1; short of either, Make is refused, naming it."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_equal(f.make_refusal(LockerScript.KIND_ICE_KIT), "", "an ice kit can be made")
	f.locker.take_material(LockerScript.MAT_IRON, 2000)
	assert_equal(f.make_refusal(LockerScript.KIND_ICE_KIT), "it needs a bar of iron; the locker holds no iron (the village makes none)",
		"no iron: refused, naming it")
	assert_equal(f.refused_code, "NO_IRON", "its code")
	assert_true(f.make_refusal(LockerScript.KIND_OUTFIT).contains("cloth"), "outfits are not made here")
	_services.stores.wood_milli_u = 1000
	assert_equal(f.make_refusal(LockerScript.KIND_NET), "it needs 2 logs; the stores hold a log", "short of wood: refused")


func test_mend_takes_a_boat_too_worn_to_sail_before_worn_gear() -> void:
	"""Mend's pick: a free boat below a cycle's wear first (it can no longer set out), else the most worn gear."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_equal(f.locker.claim(0, Vector2i(7, 1)), "", "a cycle's claim on the net")
	assert_true(f.locker.complete(0, Vector2i(7, 1)) > 0, "worn once")
	assert_equal(f.worst_to_mend(), 0, "the worn net")
	f.fleet.durability[1] = 10
	assert_equal(f.worst_to_mend(), FisheryScript.BOAT_SLOT + 1, "the boat that cannot set out comes first")
	f.fleet.durability[1] = 500
	assert_equal(f.worst_to_mend(), 0, "a boat that can still sail waits behind the worn net")


func test_a_net_is_made_at_the_workbench_and_put_in_the_locker() -> void:
	"""Make net: walked to the workbench, paid there (wood from the stores, rope from the locker), 30 WU, carried to the
	locker -- a real gear row more."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var wood: int = _services.stores.wood_milli_u
	assert_equal(f.order_make(LockerScript.KIND_NET, PackedInt32Array([1])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return f.locker.count_of(LockerScript.KIND_NET) == 2), "a second net in the locker")
	assert_equal(_services.stores.wood_milli_u, wood - 2000, "wood 2 spent")
	assert_equal(f.locker.material_milli(LockerScript.MAT_ROPE), 3000, "rope 1 spent")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0, 400), "the job is over")


# --- the ice ---------------------------------------------------------------------------------------------

func test_ice_grows_in_the_cold_and_melts_in_the_thaw() -> void:
	"""DEMO (decision 0433): a millimetre an hour at -5.0 °C, frozen at 10 mm, safe at 60 mm; melting above 0 °C."""
	var ice := IceScript.new()
	for h: int in 9:
		ice.advance_hour(-50)
	assert_equal(ice.state(), IceScript.STATE_OPEN, "9 mm is not frozen")
	assert_true(ice.advance_hour(-50), "10 mm: the state changes")
	assert_equal(ice.state(), IceScript.STATE_THIN, "frozen, thin")
	assert_equal(IceScript.hours_to_safe(ice.thickness_um, -50), 50, "50 more hours to 60 mm")
	assert_equal(IceScript.hours_to_safe(ice.thickness_um, 20), -1, "not freezing: never safe")
	for h: int in 50:
		ice.advance_hour(-50)
	assert_true(ice.safe(), "60 mm is safe")
	ice.advance_hour(80)
	assert_equal(ice.thickness_um, 56800, "+8.0 °C melts 3.2 mm an hour")
	assert_equal(ice.state(), IceScript.STATE_THIN, "thin again")


func test_the_frozen_pond_takes_only_ice_kits_and_the_stream_never_freezes() -> void:
	"""REQ-SET-051 in the driver: frozen, the lake takes only the ice kit; open, never the ice kit; the river is not
	touched."""
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	var driver: Driver = Driver.create(ids.ids, 0, _weir_width()).driver as Driver
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_ICE_KIT), Driver.REFUSE_NOT_FROZEN, "open: no ice kit")
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_BOAT), Driver.REFUSE_NONE, "open: a boat")
	driver.set_lake_frozen(true)
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_BOAT), Driver.REFUSE_ICE_COVERS, "frozen: no boat")
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_HAND_NET), Driver.REFUSE_ICE_COVERS, "frozen: no net")
	assert_equal(driver.refusal(Driver.SITE_POND, 0, Fishing.GEAR_ICE_KIT), Driver.REFUSE_NONE, "frozen: the ice kit")
	assert_equal(driver.refusal(Driver.SITE_RUN, 0, Fishing.GEAR_HAND_NET), Driver.REFUSE_NONE, "the stream flows on")


func test_thin_ice_refuses_everyone_and_nobody_swims_under_ice() -> void:
	"""The fishery's own words for the ice: on thin ice nothing, on safe ice only ice fishing; the swimmers are refused
	the frozen pond (no link offered, no swim ordered) but not the stream."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.ice.thickness_um = 24000
	f.driver.set_lake_frozen(true)
	assert_true(f.trip_refusal(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array()).begins_with("ice covers the pond"), "no boat on ice")
	assert_true(f.trip_refusal(Rules.METHOD_ICE, Driver.SITE_POND, 0, PackedInt32Array()).contains("thin"), "thin ice: no ice fishing")
	assert_equal(f.refused_code, "THIN_ICE", "its code")
	f.ice.thickness_um = 70000
	assert_equal(f.trip_refusal(Rules.METHOD_ICE, Driver.SITE_POND, 0, PackedInt32Array()), "the locker has no ice kit", "safe ice: the kit is next")
	rig.play.motion.pond_frozen = true
	assert_true(rig.play.motion.iced_at(Vector2(27.8, 28.0)), "the pond is iced")
	assert_false(rig.play.motion.iced_at(Vector2(24.4, 11.0)), "the run is not")
	rig.play.state.swim_mm_s[0] = 600
	assert_true(rig.play.order_swim(PackedInt32Array([0]), Vector2(27.8, 28.0)).contains("ice"), "nobody swims under the ice")


# --- the boat core ------------------------------------------------------------------------------------

func test_the_jetty_and_routes_are_boat_water_outside_the_boathouse() -> void:
	"""Every route leg is water a boat floats in; the jetty's land end is dry ground outside the boathouse's footprint."""
	assert_equal(Routes.validate(_map()), "", "routes and jetty valid")
	var land: Vector2 = Routes.m_of(Routes.JETTY_LAND_U)
	for circle: Vector3 in WaterDressing.footprint_circles():
		if Vector2(circle.x, circle.y).distance_to(Vector2(22.9, 23.4)) < 5.0:
			assert_true(land.distance_to(Vector2(circle.x, circle.y)) > circle.z, "the jetty stands outside the boathouse")
	assert_false(_map().is_water(Routes.JETTY_LAND_U), "its land end is dry")
	assert_equal(Routes.STATION_NAMES.size(), Routes.ROUTES.size(), "every route's station is named")
	for boat: int in Routes.BERTH_COUNT:
		assert_true(_map().depth_at(Routes.BERTH_U[boat]) >= Routes.BOAT_DRAFT_U, "berth %d floats a boat" % boat)


func test_a_boat_rows_its_fixed_route_on_integer_progress() -> void:
	"""Out along its route at 0.8 m/s of demo time, on station at its end, back to its berth; positions follow the
	integer progress; a course over land is refused."""
	var fleet := FleetScript.new()
	assert_true(fleet.take(0, 7), "taken")
	assert_true(fleet.set_off(0), "off")
	var length: int = fleet.course_len_u[0]
	@warning_ignore("integer_division") var usec: int = (length * 1000000 + FleetScript.ROW_SPEED_U_S - 1) / FleetScript.ROW_SPEED_U_S
	assert_equal(fleet.step(usec - 100000), 0, "not there yet")
	assert_equal(fleet.step(100000), 1, "on station")
	assert_equal(fleet.phase[0], FleetScript.PHASE_ON_STATION, "on station")
	assert_true(fleet.position_m(0).distance_to(Routes.m_of(Routes.route_point(0, 2))) < 0.01, "at its station")
	fleet.row_back(0)
	assert_equal(fleet.step(usec), 1, "home")
	assert_equal(fleet.phase[0], FleetScript.PHASE_MOORED, "moored")
	assert_equal(fleet.position_m(0), Routes.m_of(Routes.BERTH_U[0]), "at its berth")
	assert_false(fleet.set_course(0, PackedInt32Array([Routes.BERTH_U[0].x, Routes.BERTH_U[0].y, 10240, 10240]), _map()), "no course over land")
	fleet.give_back(0, 6)
	assert_false(fleet.is_free(0), "only its owner gives it back")
	fleet.give_back(0, 7)
	assert_true(fleet.is_free(0), "given back")


func test_a_boat_wears_15_a_cycle_and_none_sets_out_below_it() -> void:
	"""§5.4: boat wear 15; a boat below it is refused (and Mend offered)."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.fleet.durability[0] = 14
	f.fleet.durability[1] = 14
	assert_true(f.trip_refusal(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array()).contains("worn"), "worn boats refused")
	assert_equal(f.refused_fix, "Mend boat", "the fix")
	assert_equal(f.worst_to_mend(), FisheryScript.BOAT_SLOT + 0, "Mend would mend the first boat")


# --- whole trips ------------------------------------------------------------------------------------------

func test_a_bank_net_trip_lands_its_catch_and_the_store_pays_for_it() -> void:
	"""A hand net at the run for trout: the net from the locker, cast at the bank (the cycle opened only there), an hour
	worked, the catch the store's own (stock and quota debited by exactly it), carried and put down in the store; the
	net worn 20, the slots and claims released."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var p: Driver.Preview = f.preview_of(Rules.METHOD_NET, Driver.SITE_RUN, 0, 0)
	var stock: int = p.stock_milli
	var quota: int = p.remaining_quota_milli
	assert_equal(f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1])), "", "authorised")
	assert_equal(rig.driver.open_claims(), 0, "nothing taken from the water before the fisher stands at it")
	assert_false(f.locker.is_free(0), "the net set aside")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing at the bank")
	assert_equal(rig.driver.open_claims(), 1, "the cycle opened at the water")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "the trip is over")
	var caught: int = f.caught_milli
	assert_true(caught > 0, "a catch")
	p = f.preview_of(Rules.METHOD_NET, Driver.SITE_RUN, 0, 0)
	assert_equal(stock - p.stock_milli, caught, "the stock paid exactly the catch")
	assert_equal(quota - p.remaining_quota_milli, caught, "the quota too")
	assert_equal(rig.pantry.milli_of(Catalog.item_of_species(Fishing.SPECIES_TROUT)), caught, "trout in the pantry")
	assert_equal(f.locker.durability_of(0), 980, "the net worn once")
	_assert_books(rig, "net")
	_assert_released(rig, "net")


func test_a_boat_trip_is_crewed_launched_fished_landed_and_stored() -> void:
	"""A boat on the pond for perch: a helm (fishing 2) and a learner walk to the jetty -- outside the boathouse -- the
	cycle opens there (two effort slots), they board, row the fixed route out, work 120 party-WU on station, row back,
	step off and carry the catch, shared, to the store. The boat wears 15; the learner learns."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	var stock: int = f.preview_of(Rules.METHOD_BOAT, Driver.SITE_POND, 0, 1).stock_milli
	assert_equal(f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1])), "", "authorised")
	var boat: int = f.tables.t_boat[0]
	assert_equal(boat, 0, "the first boat")
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[boat] == FleetScript.PHASE_OUT), "launched")
	assert_true(f.brain_of(0).water_hold and f.brain_of(1).water_hold, "both held aboard (MOVE-REQ-007)")
	assert_equal(f.fleet.crew_of(boat, FleetScript.HELM), 0, "the helm at the helm")
	assert_equal(f.fleet.crew_of(boat, 1), 1, "the second aboard before the boat left (the helm waits for its mate)")
	assert_equal([f.fleet.boat_of_crew(0), f.fleet.boat_of_crew(1), f.fleet.boat_of_crew(2)], [boat, boat, -1], "who sits in it")
	assert_true(f.fleet.rowed_u > 0, "the fleet's tally of distance rowed")
	var slots: int = rig.driver.store().effort_slots_free_of(rig.driver.store().habitat_slot_of(rig.driver.habitat_ref_of_site(Driver.SITE_POND)).value).value
	assert_equal(slots, 4, "the lake's 6 slots less the boat's 2")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "the catch taken on station")
	assert_true(f.tables.t_work_mwu[0] >= 120000, "only after §5.4's 120 party-WU")
	var shares := [f.tables.j_load_milli[f.tables.t_seat_job[0]], f.tables.j_load_milli[f.tables.t_seat_job[1]]]
	assert_true(shares[0] > 0 and shares[1] > 0 and absi(shares[0] - shares[1]) <= 1, "the catch shared between the two")
	assert_equal(shares[0] + shares[1], f.caught_milli, "the whole catch in their hands")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "landed and stored")
	var caught: int = f.caught_milli
	assert_true(caught > 0, "a catch")
	assert_equal(stock - f.preview_of(Rules.METHOD_BOAT, Driver.SITE_POND, 0, 1).stock_milli, caught, "the stock paid it")
	assert_equal(rig.pantry.milli_of(Catalog.item_of_species(Fishing.SPECIES_PERCH)), caught, "perch in the pantry")
	assert_equal(f.fleet.durability[boat], 985, "the boat worn 15")
	assert_true(f.fleet.is_free(boat), "the boat free and moored")
	assert_false(f.brain_of(0).water_hold or f.brain_of(1).water_hold, "both ashore")
	assert_true(f.skills.xp[1] > 0, "the learner learned (§5.3: 10 XP a WU)")
	_assert_books(rig, "boat")
	_assert_released(rig, "boat")


func test_the_helm_waits_at_the_jetty_for_its_second() -> void:
	"""REQ-SET-052: no departure with a seat unstaffed -- a helm at the jetty with its second still on the way opens no
	cycle and nobody boards until both stand there."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.brain_of(0).start_at(Vector2(18.8, 27.7), 0.0, -1, -1)
	f.brain_of(1).start_at(Vector2(-6.0, -12.0), 0.0, -1, -1)
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1]))
	var helm: int = f.tables.t_seat_job[0]
	var mate: int = f.tables.t_seat_job[1]
	assert_true(_run(rig, func() -> bool: return f.step_of(helm) == FisheryScript.S_JETTY and f.tables.j_at[helm] == 1),
		"the helm at the jetty")
	assert_true(f.step_of(mate) != FisheryScript.S_JETTY or f.tables.j_at[mate] == 0, "its second still on the way")
	_run(rig, func() -> bool: return false, 30)
	assert_equal(rig.driver.open_claims(), 0, "no cycle opened")
	assert_equal(f.fleet.phase[0], FleetScript.PHASE_MOORED, "nobody aboard")
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_OUT), "out once both are there")
	assert_equal(f.fleet.crew_of(0, 1), 1, "with its second")


func test_the_jetty_recheck_holds_the_boat_in_a_storm() -> void:
	"""THE JETTY RECHECK: a storm come up after authorising stops the boat at the jetty (REQ-SET-052) -- nobody boards,
	nothing is taken, the trip waits on the board saying why; once it passes the crew goes out."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	assert_equal(f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1])), "", "authorised in fair weather")
	rig.weather.observe(0, 1, 8, 120, 2000, WeatherCore.EVENT_HEAVY_RAIN)
	assert_true(_run(rig, func() -> bool: return f.tables.t_words[0] != ""), "refused at the jetty")
	assert_true(f.tables.t_words[0].contains("storm"), "says the storm")
	assert_equal(rig.driver.open_claims(), 0, "nothing taken from the water")
	assert_equal(f.fleet.phase[0], FleetScript.PHASE_MOORED, "the boat stays moored")
	assert_equal(f.tables.trip_count(), 1, "the trip kept (its queued order preserved)")
	assert_equal(f.tables.j_worker[0], -1, "the crew stood down meanwhile, free for other work")
	rig.weather.observe(0, 1, 9, 120, 0, WeatherCore.EVENT_NONE)
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_OUT), "the storm passed: taken up again, out")


func test_cancelling_before_the_water_releases_everything() -> void:
	"""Called off on the way: no cycle was ever opened, the net is free, the jobs closed, the fisher back to its day."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[0] == 1, MAX_FRAMES, false), "the net taken")
	assert_equal(f.cancel_trip(0), "", "called off")
	assert_equal(rig.driver.open_claims(), 0, "nothing was taken from the water")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "the net carried back to the locker")
	assert_equal(f.brain_of(1).order, BrainScript.ORDER_NONE, "the fisher free")
	_assert_books(rig, "cancel before")
	_assert_released(rig, "cancel before")
	assert_equal(f.locker.durability_of(0), 1000, "no wear")


func test_cancelling_while_fishing_releases_the_cycle_and_takes_nothing() -> void:
	"""Called off with the net in the water: the cycle cancelled (its slot back, the stock untouched), the gear's claim
	released with no wear, the held room given back; the net carried back to the locker."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var stock: int = f.preview_of(Rules.METHOD_NET, Driver.SITE_RUN, 0, 0).stock_milli
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing")
	assert_true(rig.pantry.reserved_milli_of(0) > 0, "room held for the catch")
	assert_equal(f.cancel_trip(0), "", "called off")
	assert_equal(rig.driver.open_claims(), 0, "the cycle cancelled at once")
	assert_equal(rig.pantry.reserved_milli_of(0), 0, "the room given back at once")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "the net carried home")
	assert_equal(f.preview_of(Rules.METHOD_NET, Driver.SITE_RUN, 0, 0).stock_milli, stock, "the stock untouched")
	assert_equal(f.locker.durability_of(0), 1000, "no wear")
	_assert_books(rig, "cancel fishing")
	_assert_released(rig, "cancel fishing")


func test_a_boat_called_off_afloat_rows_home_empty() -> void:
	"""Called off on station: the cycle cancelled, the boat rows home, both step off at the jetty; no catch, no wear."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1]))
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_ON_STATION), "on station")
	assert_equal(f.cancel_trip(0), "", "called off afloat")
	assert_equal(rig.driver.open_claims(), 0, "the cycle released at once")
	assert_equal(f.cancel_trip(0), "it is coming back already", "said once")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "home and over")
	assert_equal(f.fleet.durability[0], 1000, "no wear")
	assert_false(f.brain_of(0).water_hold or f.brain_of(1).water_hold, "both ashore")
	_assert_books(rig, "boat called off")
	_assert_released(rig, "boat called off")


func test_a_catch_is_landed_before_it_can_be_called_off() -> void:
	"""Once the catch is out of the water Cancel is refused: it is always landed (decision 0222)."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_true(f.cancel_trip(0).contains("landed first"), "refused")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "landed")
	_assert_books(rig, "landing")


func test_a_carrier_called_away_sets_the_catch_down_for_the_next() -> void:
	"""Interrupted with the catch in hand (an order): the catch is set down where it was (REQ-SET-054: cargo retained),
	still in the books; the next fisher fetches it and lands it -- nothing lost, nothing stored twice."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.step_of(0) == FisheryScript.S_TO_STORE, MAX_FRAMES, false), "carrying")
	var caught: int = f.caught_milli
	f.brain_of(1).order_move(Vector2(0.0, 6.0))
	assert_equal(f.tables.j_worker[0], -1, "the carrier is called away")
	assert_true(f.tables.j_load_at[0].is_finite(), "the catch set down")
	_assert_books(rig, "set down")
	assert_true(f.claim(0, 2), "another fetches it")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "landed")
	assert_equal(f.landed_milli, caught, "the whole catch, once")
	_assert_books(rig, "fetched and landed")


func test_an_unreachable_bank_is_given_up_with_every_claim_released() -> void:
	"""A fisher who cannot get to the bank tries again (anyone may); after MAX_TRIES the trip is called off and the feed
	says where nobody could get -- the net free, nothing taken."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var said := PackedStringArray()
	f.say = func(text: String, _w: bool) -> void: said.append(text)
	f._spots[&"locker"] = Vector2(27.8, 28.0)
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "given up after its tries (by anyone)")
	assert_true("\n".join(said).contains("could not reach the gear locker"), "the feed says where")
	_assert_released(rig, "unreachable")


func test_a_trap_is_set_left_to_soak_and_collected() -> void:
	"""The trap's role: 20 WU to set, left 6 h with its cycle open (its slot held, nobody there), then collected (20 WU)
	and its catch landed; the trap worn 10 and back in the locker."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_equal(f.authorise(Rules.METHOD_TRAP, Driver.SITE_RUN, 1, PackedInt32Array([1])), "", "a trap for dace")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_SOAKING), "set")
	assert_equal(rig.driver.open_claims(), 1, "its cycle open while it soaks")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "the setter goes home")
	rig.calendar.tick += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 1, 20, false), "a collection on the board")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "taken up, collected and landed")
	assert_true(f.caught_milli > 0, "a catch")
	assert_equal(f.locker.durability_of(1), 990, "the trap worn 10")
	_assert_books(rig, "trap")
	_assert_released(rig, "trap")


func test_a_carrier_with_no_store_room_waits_standing_then_stores() -> void:
	"""Decision 0222: a catch with nowhere to go is held by its carrier, who waits where it stands -- planning again only
	every RETRY_USEC, never a frame -- and stores it once room is made; the books balance throughout."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.step_of(0) == FisheryScript.S_TO_STORE and f.tables.j_load_milli[0] > 0),
		"carrying the catch")
	rig.pantry.release(f.tables.j_hold[0])
	f.tables.j_hold[0] = -1
	for at: int in rig.pantry.storage.count():
		rig.pantry.add_into(13, rig.pantry.room_milli_of(at), at, _read)
	assert_true(_run(rig, func() -> bool: return f.tables.j_words[0].contains("no store has room")), "waiting for room")
	var planned := [0]
	_run(rig, func() -> bool:
		planned[0] += 1 if f.tables.j_issued[0] != 0 else 0
		return false, 60)
	assert_true(planned[0] <= 6, "planned again only on its retries (%d frames of 60)" % planned[0])
	_assert_books(rig, "waiting for room")
	for lot: int in PantryScript.MAX_LOTS:
		if rig.pantry.lot_item(lot) == 13:
			rig.pantry.withdraw_into(lot, rig.pantry.lot_serial(lot), rig.pantry.lot_milli(lot), _read)
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "stored once there is room")
	_assert_books(rig, "room made")
	_assert_released(rig, "room made")


func test_no_store_room_at_the_water_opens_no_cycle_and_claims_no_gear() -> void:
	"""begin_cycle is all or nothing: at the bank with every store full, the cycle the driver opened is cancelled and
	the net's claim released -- the trip waits saying why, nothing taken from the water."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[0] == 1, MAX_FRAMES, false), "the net taken")
	for at: int in rig.pantry.storage.count():
		rig.pantry.add_into(13, rig.pantry.room_milli_of(at), at, _read)
	assert_true(_run(rig, func() -> bool: return f.tables.t_words[0].contains("no store has room")), "refused at the water")
	assert_equal(rig.driver.open_claims(), 0, "no cycle left open")
	assert_false(f.locker.is_claimed(0), "the net holds no claim")
	assert_equal(f.tables.t_state[0], Tables.TRIP_QUEUED, "the trip still waiting")


func test_a_refused_catch_brings_the_boat_home_without_fishing_again() -> void:
	"""A cycle the store no longer holds when the work is done (the driver refuses the catch): nothing is taken, no wear,
	and the boat rows home and the trip ends -- it does not row straight back out to fish again."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1]))
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_ON_STATION), "on station")
	rig.driver.cancel_cycle(f.tables.t_cycle[0] as Driver.Cycle)
	assert_true(_run(rig, func() -> bool: return f.tables.t_called_off[0] == 1), "the refusal turns the trip home")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0, 3000), "home and over")
	assert_equal(f.caught_milli, 0, "nothing caught")
	assert_equal(f.fleet.durability[0], 1000, "no wear")
	assert_true(f.fleet.is_free(0), "the boat moored and free")
	_assert_released(rig, "refused catch")


func test_ice_forming_calls_a_pond_boat_home() -> void:
	"""Decision 0433: ice forming on the pond under a boat fishing it calls the trip off -- the cycle released, the boat
	rows home, no catch and no wear."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing")
	f.ice.thickness_um = IceScript.FROZEN_UM
	assert_true(_run(rig, func() -> bool: return f.tables.t_called_off[0] == 1, 5), "called off at once")
	assert_equal(rig.driver.open_claims(), 0, "the cycle released")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "home and over")
	assert_equal(f.fleet.durability[0], 1000, "no wear")
	_assert_released(rig, "ice forming")


func test_a_trap_called_off_before_its_collector_lifts_it_ends_the_collection() -> void:
	"""A soaking trap's collection under way, called off before the trap is lifted: the collection ends at once (its
	worker free, no 20 WU for nothing), the cycle and the trap's claim released."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_TRAP, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_SOAKING), "set")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "the setter goes home")
	rig.calendar.tick += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 1 and f.tables.j_worker[f.tables.j_live.find(1)] >= 0),
		"a collector on the way")
	var j: int = f.tables.j_live.find(1)
	var who: int = f.tables.j_worker[j]
	assert_equal(f.tables.j_started[j], 0, "the trap not yet lifted")
	assert_equal(f.cancel_trip(0), "", "called off")
	assert_equal(f.tables.job_count(), 0, "the collection ended at once")
	assert_equal(f.brain_of(who).order, BrainScript.ORDER_NONE, "its collector free")
	assert_equal(f.caught_milli, 0, "nothing caught")
	_assert_released(rig, "trap called off")


func test_ice_fishing_through_safe_ice() -> void:
	"""Winter: an ice kit and a winter outfit from the locker, out over SAFE ice to the hole (held on the ice), 90 WU,
	whitefish landed; the walker back on land, the kit worn 20, the outfit unworn and back."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.locker.add_gear(LockerScript.KIND_ICE_KIT)
	rig.weather.observe(3, 1, 8, -50, 0, WeatherCore.EVENT_NONE)
	f.ice.thickness_um = 80000
	rig.driver.set_lake_frozen(true)
	assert_equal(f.authorise(Rules.METHOD_ICE, Driver.SITE_POND, 2, PackedInt32Array([1])), "", "ice fishing authorised")
	assert_true(_run(rig, func() -> bool: return f.step_of(0) == FisheryScript.S_WORK and f.tables.j_at[0] == 1), "fishing through the hole")
	assert_true(f.brain_of(1).water_hold, "held out on the ice")
	assert_true(f.brain_of(1).position.distance_to(FisheryScript.ICE_HOLE) < 0.1, "at the hole")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "landed")
	assert_equal(rig.pantry.milli_of(Catalog.item_of_species(Fishing.SPECIES_WHITEFISH)), f.caught_milli, "whitefish in the pantry")
	assert_true(f.caught_milli > 0, "a catch")
	assert_false(f.brain_of(1).water_hold, "back on land")
	_assert_released(rig, "ice")


func test_thinning_ice_calls_an_ice_trip_back() -> void:
	"""A thaw under an ice fisher: the trip is called off at once (the cycle released) and it walks straight back."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.locker.add_gear(LockerScript.KIND_ICE_KIT)
	rig.weather.observe(3, 1, 8, -50, 0, WeatherCore.EVENT_NONE)
	f.ice.thickness_um = 61000
	rig.driver.set_lake_frozen(true)
	f.authorise(Rules.METHOD_ICE, Driver.SITE_POND, 2, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.step_of(0) == FisheryScript.S_WORK), "out on the ice")
	f.ice.thickness_um = 59000
	assert_true(_run(rig, func() -> bool: return f.tables.t_called_off[0] == 1, 5), "called off")
	assert_equal(rig.driver.open_claims(), 0, "released at once")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "back and over")
	assert_false(f.brain_of(1).water_hold, "on land")
	_assert_released(rig, "thaw")


# --- the rack and the mill ---------------------------------------------------------------------------------

func test_the_rack_dries_four_fish_into_three_over_twelve_hours() -> void:
	"""§5.7 dry_fish (smoked on the rack: decision 0434): the 4 U that spoil first set aside, withdrawn only at the rack
	(REQ-SET-118), 24 WU hung, 12 h curing in its slot with the worker free (REQ-SET-093), taken down: 3 U dried fish
	stored."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 6000, 0, _read)
	assert_equal(f.order_dry(PackedInt32Array([1])), "", "ordered")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FISH), 2000, "4 U set aside")
	assert_equal(rig.pantry.milli_of(Catalog.FIRST_CATCH), 6000, "still in its lot until the batch starts")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[0] == Tables.SLOT_CURING), "hung")
	assert_equal(rig.pantry.milli_of(Catalog.FIRST_CATCH), 2000, "4 U withdrawn at the rack")
	assert_equal(f.tables.job_count(), 0, "the worker free while it cures")
	rig.calendar.tick += Rules.DRY_PASSIVE_HOURS * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 1, 20, false), "a take-down on the board")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_DRIED_FISH) == 3000), "taken down: 3 U dried fish stored")
	assert_equal([f.dried_in_milli, f.dried_out_milli, f.dried_stored_milli], [4000, 3000, 3000], "the rack's books")
	assert_equal(f.tables.s_state[0], Tables.SLOT_EMPTY, "the slot free")


func test_a_rack_batch_cancelled_after_its_fish_was_hung_spoils_half() -> void:
	"""REQ-SET-094: cancelled once its food was withdrawn, half its mass becomes spoiled food; before, nothing moves."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 8000, 0, _read)
	f.order_dry(PackedInt32Array([1]))
	assert_equal(f.cancel_job(0), "", "cancelled before it started")
	assert_equal(rig.pantry.milli_of(Catalog.FIRST_CATCH), 8000, "nothing moved")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FISH), 8000, "nothing set aside")
	f.order_dry(PackedInt32Array([1]))
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[j] == 1), "hanging")
	assert_equal(f.cancel_job(j), "", "cancelled while hanging")
	assert_equal(rig.pantry.spoiled_milli, 2000, "half the 4 U spoiled")
	assert_equal(rig.pantry.milli_of(Catalog.FIRST_CATCH), 4000, "the rest of the stock untouched")
	assert_equal(f.tables.s_state[0], Tables.SLOT_EMPTY, "the slot free")
	assert_equal(rig.pantry.reserved_milli_of(0), 0, "its output's room released")


func test_the_mill_grinds_three_grain_into_three_flour() -> void:
	"""§5.7 flour: 3 U of the grain that spoils first, ground at the mill over the stream (12 WU), 3 U flour stored."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(13, 5000, 0, _read)
	assert_equal(f.order_mill(PackedInt32Array([1])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_FLOUR) == 3000), "3 U flour stored")
	assert_equal(rig.pantry.milli_of(13), 2000, "3 U wheat ground")
	assert_equal([f.milled_in_milli, f.milled_out_milli, f.milled_stored_milli], [3000, 3000, 3000], "the mill's books")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0, 400), "over")


func test_a_cured_batch_waits_for_a_free_job_row_and_is_never_lost() -> void:
	"""A batch cured while every job row is taken stays READY and is put on the board as soon as a row is free -- its
	dried fish and its held room never lost."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 6000, 0, _read)
	f.order_dry(PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[0] == Tables.SLOT_CURING and f.tables.job_count() == 0), "curing")
	var filler := PackedInt32Array()
	while f.tables.job_count() < Tables.MAX_JOBS:
		filler.append(f.tables.open_job(Tables.KIND_MEND, FisheryScript.PROG_MEND, -1))
	rig.calendar.tick += Rules.DRY_PASSIVE_HOURS * SimClock.TICKS_PER_HOUR
	f.update(100000)
	assert_equal(f.tables.s_state[0], Tables.SLOT_READY, "cured, waiting for a row")
	for j: int in filler:
		f.tables.close_job(j)
	f.update(100000)
	assert_equal(f.tables.s_state[0], Tables.SLOT_TAKING, "on the board once a row is free")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_DRIED_FISH) == 3000), "taken down and stored")


func test_the_mill_holds_room_for_its_flour_and_a_cancel_gives_it_back() -> void:
	"""REQ-SET-112, as the rack's: ordering a mill batch holds the 3 U of room its flour needs; cancelling it gives the
	room and the grain back."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(13, 5000, 0, _read)
	assert_equal(f.order_mill(PackedInt32Array([1])), "", "ordered")
	var held: int = 0
	for at: int in rig.pantry.storage.count():
		held += rig.pantry.reserved_milli_of(at)
	assert_equal(held, Rules.MILL_OUT_MILLI, "room held for the flour")
	assert_equal(f.cancel_job(f.tables.j_live.find(1)), "", "cancelled before it started")
	for at: int in rig.pantry.storage.count():
		assert_equal(rig.pantry.reserved_milli_of(at), 0, "the room given back")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, FarmingScript.CROP_GRAIN), 5000, "the grain given back")


func test_the_mill_refuses_grain_the_kitchen_has_set_aside() -> void:
	"""The mill takes only unreserved grain: the kitchen's porridge reservations are never milled away."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(13, 4000, 0, _read)
	var take: int = rig.takes.new_take()
	rig.takes.reserve_into(rig.pantry, take, FarmingScript.CROP_GRAIN, 2000, 0, _read)
	assert_true(f.mill_refusal().begins_with("the stores have 2 scoops of grain free"), "refused, saying why")
	assert_true(f.mill_refusal().contains("; a batch takes 3 scoops of grain"), "and what a batch takes")
	assert_equal(f.refused_code, "NO_GRAIN", "its code")


# --- the boat rescue -------------------------------------------------------------------------------------

func test_a_boat_answers_a_victim_in_the_pond_when_no_swimmer_is_free() -> void:
	"""BOAT RESCUE (RESPONSE_BOAT): a mouse in difficulty at the pond's surface, nobody else swimming -- a helm rows a
	moored boat straight out, hauls it aboard, rows back; it is set ashore at the jetty; the boat is free again."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	rig.play.state.swim_mm_s[1] = 600
	var victim: BrainScript = f.brain_of(1)
	victim.start_at(Vector2(25.0, 31.0), 0.0, -1, -1)
	victim.water_in()
	rig.play.rescue.start_difficulty(1)
	var task: Tasks.VictimTask = rig.play.rescue.victim_task(1)
	assert_equal(task.response, Tasks.RESPONSE_BOAT, "a boat answers")
	assert_equal(task.responder, 0, "the helm")
	assert_equal(task.why, "no swimmer is free", "and why")
	assert_true(_run(rig, func() -> bool: return task.towed), "hauled aboard")
	assert_equal([task.response, task.responder], [Tasks.RESPONSE_BOAT, 0], "by the boat (no line took over)")
	var card := RescueCardScript.new()
	card.configure(rig.play.rescue, rig.play.state, rig.cast)
	var details := RescueCardScript.Details.new()
	assert_true(card.details_into("water:rescue:1", details), "the rescue card (decision 0461) reads the boat")
	assert_true(details.phase.begins_with(card.name_of(0) + ": by boat"), "the boat's phase: %s" % details.phase)
	assert_true(details.landing.distance_to(Routes.m_of(Routes.JETTY_LAND_U)) < 0.01, "bound for the jetty")
	assert_true(details.time.begins_with("safe ashore in about "), "a time: %s" % details.time)
	assert_true(f.fleet.phase[0] == FleetScript.PHASE_ON_STATION or f.fleet.phase[1] == FleetScript.PHASE_ON_STATION,
		"alongside the victim")
	assert_true(_run(rig, func() -> bool: return not rig.play.rescue.victims.has(1)), "ashore")
	assert_equal([rig.play.rescue.assisted_by[-1], rig.play.rescue.assisted_victim[-1]], [0, 1],
		"logged as the helm's assistance: the people's ledger records the deed for the rescuer by name (decision 0491)")
	assert_true(victim.position.distance_to(Routes.m_of(Routes.JETTY_LAND_U)) < 4.0, "at the jetty")
	assert_true(_run(rig, func() -> bool: return f.fleet.is_free(0) and f.fleet.is_free(1)), "the boat free again")
	assert_false(f.brain_of(0).water_hold, "the rescuer ashore")


func test_a_nearer_swimmer_still_goes_before_the_boat() -> void:
	"""Ranked by route: a swimmer standing at the pond's edge is nearer than a boat from the jetty -- it swims."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.brain_of(0).start_at(Vector2(-10.0, -10.0), 0.0, -1, -1)
	rig.play.state.swim_mm_s[2] = 1100
	f.brain_of(2).start_at(Vector2(30.5, 34.5), 0.0, -1, -1)
	var victim: BrainScript = f.brain_of(1)
	victim.start_at(Vector2(29.5, 32.0), 0.0, -1, -1)
	victim.water_in()
	rig.play.rescue.start_difficulty(1)
	assert_equal(rig.play.rescue.victim_task(1).response, Tasks.RESPONSE_SWIM, "the swimmer goes")


func test_a_nearer_boat_goes_before_a_far_swimmer() -> void:
	"""Ranked by route: a free swimmer far off in the village and a helm at the jetty -- the boat's way is shorter, so
	the boat goes."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	f.brain_of(0).start_at(Vector2(19.0, 28.6), 0.0, -1, -1)
	rig.play.state.swim_mm_s[2] = 1100
	f.brain_of(2).start_at(Vector2(-6.0, -12.0), 0.0, -1, -1)
	var victim: BrainScript = f.brain_of(1)
	victim.start_at(Vector2(25.0, 31.0), 0.0, -1, -1)
	victim.water_in()
	rig.play.rescue.start_difficulty(1)
	assert_equal(rig.play.rescue.victim_task(1).response, Tasks.RESPONSE_BOAT, "the boat goes")
	assert_equal(rig.play.rescue.victim_task(1).responder, 0, "the helm")


func test_a_boat_that_cannot_reach_its_victim_leaves_it_for_another() -> void:
	"""The victim drifted off the boat's straight leg: the boat finds nobody in reach, rows home empty, and the victim
	is released at once for another rescuer (ONE RESPONDER) -- never left reserved by a boat that gave up."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	var victim: BrainScript = f.brain_of(1)
	victim.start_at(Vector2(25.0, 31.0), 0.0, -1, -1)
	victim.water_in()
	rig.play.rescue.start_difficulty(1)
	var task: Tasks.VictimTask = rig.play.rescue.victim_task(1)
	assert_equal(task.response, Tasks.RESPONSE_BOAT, "a boat answers")
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_OUT or f.fleet.phase[1] == FleetScript.PHASE_OUT),
		"rowing out")
	victim.position = Vector2(29.5, 32.0)
	assert_true(_run(rig, func() -> bool: return f.fleet.phase[0] == FleetScript.PHASE_BACK or f.fleet.phase[1] == FleetScript.PHASE_BACK),
		"nobody in reach: rowing home")
	assert_false(task.towed, "nobody hauled aboard")
	assert_true(task.responder != 0, "the victim released by the boat that gave up")
	assert_true(_run(rig, func() -> bool: return f.fleet.is_free(0) and f.fleet.is_free(1)), "the boat free again")
	assert_false(f.brain_of(0).water_hold, "the helm ashore")


# --- the board --------------------------------------------------------------------------------------------

func test_the_work_board_lists_claims_and_cancels_fishery_jobs() -> void:
	"""work/fishery_work.gd: a seat waits, is claimed by an eligible resident (a helm needs fishing 1), reads as the
	Work screen's record, and Cancel calls the trip off."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_helm(rig, 0, 2)
	var source := FisheryWork.new(f)
	assert_equal(source.id, WorkIds.SOURCE_FISHERY, "its source")
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a queued walk is past every source")
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array())
	assert_true(source.waiting(0) and source.waiting(1), "both seats wait")
	assert_equal(source.activity(0), WorkIds.ACT_FISH, "fishing")
	assert_true(source.eligibility(0, 1).contains("helm"), "a learner may not take the helm")
	assert_equal(source.eligibility(1, 1), "", "but may take the second seat")
	assert_true(source.claim(0, 0), "the helm claimed")
	var record := TaskRecord.new()
	source.fill(record, 0)
	assert_equal(record.worker, 0, "its worker")
	assert_equal(record.action, "Fish", "its action")
	assert_true(record.target.contains("pond"), "its target")
	assert_equal(source.cancel(0), "", "called off")
	assert_equal(f.tables.trip_count(), 0, "gone")
	assert_true(f.fleet.is_free(0), "the boat free")


func test_the_fishery_s_words_count_fish_one_a_unit() -> void:
	"""Decision 1801 (slice 6), 1011 P3: a catch is counted in its species ("9 perch"), rounded down; the room it needs
	rounded up ("10 perch"); a non-pantry catch is "fish"; REQ-SET-055's stock line says "about" the stock, its share
	of the water's capacity, and the water's quota in fish a day."""
	assert_equal(Text.catch_text(9600, 19), "9 perch", "a catch, down")
	assert_equal(Text.catch_need(9600, 19), "10 perch", "its room, up")
	assert_equal(Text.catch_text(1000, 16), "a trout", "one fish")
	assert_equal(Text.catch_text(0, 16), "no trout", "none")
	assert_equal(Text.catch_text(3000, Catalog.NO_ITEM), "3 fish", "not a pantry item: fish")
	var p := Driver.Preview.new()
	p.species_key = &"perch"
	p.stock_milli = 720400
	p.capacity_milli = 900000
	p.quota_milli = 52500
	p.remaining_quota_milli = 25500
	assert_equal(Text.stock_line(p), "Stock: about 720 perch (80% of 900 perch) · quota 52 fish a day, 25 fish left",
		"the stock and the quota")
	p.stock_milli = 0
	p.remaining_quota_milli = 0
	p.restocking = true
	assert_equal(Text.stock_line(p), "Stock: no perch (0% of 900 perch) · restocking · quota 52 fish a day, no fish left",
		"none left")
