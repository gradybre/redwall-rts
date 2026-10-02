extends "res://test/framework/test_case.gd"
## The orchard (decisions 0671-0677; feature #20 and review group Y's ECO-008, 009, 010, 015): its numbers against their
## documents (GDD §5.5/§5.6, BAL-CAT-010, the approved early yield), the model's §5.6 days, harvests, plans, hedge and
## grove, and whole jobs on real brains walking the real layout -- tending, a harvest into the baskets and on to a store,
## a picking, a planting, a propagation and the grove's observation -- with the books kept: every unit picked is at a
## stand, in a store or in a hand. Built over the placeholder cast on the real layout and water (as test_demo_fishery.gd):
## no staged assets, no scene tree. Expected numbers are restated from their sources.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const ForageCore := preload("res://scripts/core/forage.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const Text := preload("res://demo/orchard/orchard_text.gd")
const OrchardNode := preload("res://demo/orchard/demo_orchard.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const KitchenNode := preload("res://demo/kitchen/demo_kitchen.gd")
const FarmCatalog := preload("res://demo/farm/farm_catalog.gd")
const Layout := preload("res://demo/world/world_layout.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 8000
## The calendar's ticks at 06:00 of absolute day `d` are (d - 1) * TICKS_PER_DAY.
const APPLE_DAY: int = 25
const PEAR_DAY: int = 27

## The rig: the placeholder cast on the village's water, a pantry with the stands, the orchard's model and board.
class Rig:
	var cast: DemoCastScript = null
	var pantry: PantryScript = null
	var calendar: CalendarScript = null
	var weather: DemoWeatherScript = null
	var model: ModelScript = null
	var jobs: JobsScript = null
	var compost: int = 40000
	var day_seen: int = 1

	func compost_left() -> int:
		"""The rig's compost store."""
		return compost

	func take_compost(milli: int) -> bool:
		"""All or none."""
		if compost < milli:
			return false
		compost -= milli
		return true

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


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water, built once."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _rig(day: int = 1) -> Rig:
	"""The placeholder cast walking the real layout round the water's band and the orchard's obstacles, a pantry with
	the kitchen's store and the two basket stands, the calendar at 06:00 of `day`, mild weather, and the orchard."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	circles.append_array(OrchardNode.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var storage := StorageScript.new(DemoFarmScript.store_position(rig.cast))
	storage.add_provider(KitchenNode.pantry_provider())
	storage.add_provider(OrchardNode.stand_provider())
	storage.add_provider(_cellar)
	rig.pantry = PantryScript.new(storage)
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	rig.weather = DemoWeatherScript.new()
	rig.weather.observe(0, 1, 8, 120, 0, WeatherCore.EVENT_NONE)
	rig.model = ModelScript.new()
	rig.model.today_hint = day
	rig.day_seen = day
	rig.jobs = JobsScript.new()
	rig.jobs.configure(rig.model, rig.cast, rig.pantry, _services.stores, rig.calendar, rig.weather)
	rig.jobs.set_compost(rig.compost_left, rig.take_compost)
	if OS.get_environment("ORCHARD_DEBUG") == "1":
		rig.jobs.say = func(text: String, _warning: bool) -> void: printerr("##SAY## ", text)
	return rig


static func _cellar() -> Array:
	"""A root cellar by the hall (§5.8's 350): the store that keeps food longest (store 4)."""
	return [{StorageScript.KEY_ID: &"test_cellar", StorageScript.KEY_POSITION: Vector2(-3.0, -10.0),
		StorageScript.KEY_CAPACITY_U: 100, StorageScript.KEY_PERMILLE: 350, StorageScript.KEY_LABEL: "Cellar"}]


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast, the calendar (its midnights closing the orchard's days, as demo_orchard.gd does) and the board --
	and, as the work board does, hand a waiting job to the first idle resident who may take it -- until `done()`."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		_close_days(rig)
		rig.jobs.update(usec)
		if OS.get_environment("ORCHARD_DEBUG") == "1" and frame % 400 == 0:
			_debug(rig, frame)
	return bool(done.call())


func _debug(rig: Rig, frame: int) -> void:
	"""Print every live job (ORCHARD_DEBUG=1)."""
	for j: int in JobsScript.MAX_JOBS:
		if rig.jobs.is_live(j):
			var w: int = rig.jobs.worker[j]
			var b: BrainScript = rig.jobs.brain_of(w) if w >= 0 else null
			printerr("##ORCH## f%d job %d kind %d step %d w %d goal %s issued %d at %d done %d/%d words '%s' %s" % [frame,
				j, rig.jobs.kind[j], rig.jobs.step_of(j), w, rig.jobs.goal[j], rig.jobs.issued[j], rig.jobs.at_work[j],
				rig.jobs.done_mwu[j], rig.jobs.need_mwu[j], rig.jobs.words[j],
				("state %d pos %s order %d" % [b.state, b.position, b.order]) if b != null else ""])


func _close_days(rig: Rig) -> void:
	"""demo_orchard.gd `_follow_day`: each midnight passed closes its day."""
	var day: int = rig.calendar.now().absolute_day
	while rig.day_seen < day:
		rig.model.close_day(rig.day_seen, 120)
		rig.day_seen += 1


func _board_pass(rig: Rig) -> void:
	"""The work board's part: each waiting job to the first idle resident who may take it."""
	for j: int in JobsScript.MAX_JOBS:
		if not rig.jobs.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = rig.jobs.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and rig.jobs.eligibility(j, who).is_empty() and rig.jobs.claim(j, who):
				break


func _stand(rig: Rig, group: int) -> int:
	"""Group `group`'s stand's pantry location."""
	assert_true(rig.pantry.storage.index_of_id_into(Rules.STAND_IDS[group], _read), "the stand is a store")
	return _read.value


func _in_hand(rig: Rig, item: int) -> int:
	"""`item` cut and not yet stored (in hands or set down)."""
	var total: int = 0
	for j: int in JobsScript.MAX_JOBS:
		if rig.jobs.is_live(j) and rig.jobs.kind[j] != JobsScript.K_HAUL and rig.jobs.load_item[j] == item:
			total += rig.jobs.load_milli[j]
	return total


func _no_holds(rig: Rig, label: String) -> void:
	"""No room is held anywhere, and no reservation row is left live (a spent hold still takes a row)."""
	for at: int in rig.pantry.storage.count():
		assert_equal(rig.pantry.reserved_milli_of(at), 0, "%s: no room held at store %d" % [label, at])
	for hold: int in PantryScript.MAX_HOLDS:
		assert_false(rig.pantry.is_hold(hold), "%s: hold row %d released" % [label, hold])


# --- the numbers -----------------------------------------------------------------------------------------------------------

func test_the_numbers_are_the_documents() -> void:
	"""§5.6 through orchard_hive.gd, BAL-CAT-010's 80/40 WU, §5.5's Berries row, and decision 0672's early yield."""
	assert_equal(Hive.SPECIES_MATURITY_DAYS, [96, 144], "§5.6 maturity")
	assert_equal(Hive.SPECIES_YIELD_MILLI, [80000, 110000], "§5.6 yields")
	assert_equal(Rules.CARE_MWU, 20000, "§5.6 care 20 WU a day")
	assert_equal(Rules.HARVEST_MWU, 80000, "BAL-CAT-010 harvest 80 WU")
	assert_equal(Rules.PLANT_MWU, 40000, "BAL-CAT-010 planting 40 WU")
	assert_equal(Rules.PROPAGATE_MWU, 120000, "§5.6 nursery 120 WU")
	assert_equal(Rules.EARLY_YIELD_PERMILLE, 200, "ECO-008's 15-25%: the middle")
	assert_equal(Rules.EARLY_YIELD_AGE_DAYS, 48, "after one full seasonal cycle")
	assert_equal(Rules.EARLY_HARVEST_MWU, 16000, "an early picking's work is its share")
	assert_equal(Rules.HEDGE_CAPACITY_MILLI, 300000, "§5.5 Berries capacity 300 U")
	assert_equal(Rules.HEDGE_START_MILLI, 240000, "§5.1's 80% opening stock")
	assert_equal(Rules.berry_floor_milli(), 60000, "§5.5 sustainable floor 20%")
	assert_equal(Rules.pick_mwu(1000), 4000, "§5.5 4 WU a U at danger 1, FORAGE 0 (ceil(4e6/1.1e6))")
	assert_equal(Rules.pick_mwu(Rules.PICK_LOAD_MILLI), 20000, "a basket of 5 U")
	for season: int in 4:
		assert_equal(Rules.berry_availability(season), [0, 1000, 400, 0][season], "§5.5 availability %d" % season)
	assert_equal(Rules.GRANT_SAPLINGS, PackedInt32Array([2, 2]), "the M3 grant: two of each")


func test_the_early_yield_is_the_product_floored_once() -> void:
	"""Decision 0672: §5.6's product times 200/1000, one floor; the boundaries of health and chill."""
	assert_equal(Rules.early_yield_milli(80000, 10000, 1000, 100), 16000, "a fifth of a healthy apple's 80 U")
	assert_equal(Rules.early_yield_milli(110000, 10000, 1000, 100), 22000, "a fifth of a pear's 110 U")
	assert_equal(Rules.early_yield_milli(80000, 3500, 1000, 100), 5600, "at 35% health")
	assert_equal(Rules.early_yield_milli(80000, 10000, 1000, 75), 12000, "a warm winter's 75%")
	assert_equal(Rules.early_yield_milli(80000, 10000, 1150, 100), 18400, "two hives' 1150")
	assert_equal(Rules.early_yield_milli(80000, 1, 1000, 75), 1, "floored once, not thrice (80000*1*1000*75*200 / 10^12 = 1.2)")
	assert_equal(Rules.early_yield_milli(80000, 0, 1000, 100), 0, "a dead tree")


func test_berry_growth_is_the_capped_additive_form() -> void:
	"""§5.5 / decision 0036: min(K-P, floor((K-P)*120*S/10^6) + 1000); nothing dormant or full."""
	assert_equal(Rules.berry_growth_milli(0, 1), 37000, "summer, empty: 36 U + the 1 U term")
	assert_equal(Rules.berry_growth_milli(0, 2), 15400, "autumn's 400: 14.4 U + 1 U")
	assert_equal(Rules.berry_growth_milli(0, 0), 0, "spring: dormant")
	assert_equal(Rules.berry_growth_milli(0, 3), 0, "winter: dormant")
	assert_equal(Rules.berry_growth_milli(300000, 1), 0, "full")
	assert_equal(Rules.berry_growth_milli(299500, 1), 500, "capped at the room left")


func test_stages_by_age() -> void:
	"""A sapling to half a year, young to a year, bearing early to maturity, mature; inherited trees are old."""
	assert_equal(Rules.stage_of(0, Rules.APPLE, false), Rules.STAGE_SAPLING, "planted")
	assert_equal(Rules.stage_of(23, Rules.APPLE, false), Rules.STAGE_SAPLING, "23 days")
	assert_equal(Rules.stage_of(24, Rules.APPLE, false), Rules.STAGE_YOUNG, "half a year")
	assert_equal(Rules.stage_of(48, Rules.APPLE, false), Rules.STAGE_EARLY, "a year: bears early")
	assert_equal(Rules.stage_of(95, Rules.APPLE, false), Rules.STAGE_EARLY, "the day before maturity")
	assert_equal(Rules.stage_of(96, Rules.APPLE, false), Rules.STAGE_MATURE, "apple maturity")
	assert_equal(Rules.stage_of(96, Rules.PEAR, false), Rules.STAGE_EARLY, "a pear is not mature at 96")
	assert_equal(Rules.stage_of(10, Rules.PEAR, true), Rules.STAGE_OLD, "inherited")
	assert_equal(Rules.stage_of(Rules.OLD_FROM_DAYS, Rules.PEAR, false), Rules.STAGE_OLD, "six years")
	assert_almost_equal(Rules.grown_share(48, Rules.APPLE), 0.5, "half grown at 48 of 96")
	assert_almost_equal(Rules.grown_share(500, Rules.APPLE), 1.0, "full grown, clamped")


func test_the_sites_are_tile_blocks_clear_of_the_village() -> void:
	"""Four §5.6 blocks of 4x4 2 m tiles, apart, inside the walk bounds and the map, on dry ground, clear of the farm's
	beds, the world's own obstacles and the paths' middle; the stands, nursery and bushes clear too."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var walk: AABB = WaterplayScript.walk_bounds(world.bounds())
	for site: int in Rules.SITE_COUNT:
		var rect: Rect2 = Rules.site_rect_m(site)
		assert_almost_equal(rect.size.x, 8.0, "a block is 8 m")
		assert_true(Hive.is_block_origin(Rules.SITE_ORIGIN[site].x, Rules.SITE_ORIGIN[site].y), "in the map")
		assert_true(rect.position.x >= walk.position.x and rect.end.x <= walk.end.x, "x in the walk bounds")
		assert_true(rect.position.y >= walk.position.z and rect.end.y <= walk.end.z, "z in the walk bounds")
		for other: int in range(site + 1, Rules.SITE_COUNT):
			assert_false(rect.intersects(Rules.site_rect_m(other)), "sites %d and %d apart" % [site, other])
		for bed: int in FarmCatalog.BED_COUNT:
			assert_false(rect.has_point(FarmCatalog.bed_centre_m(bed)), "no bed on site %d" % site)
		for corner: Vector2 in [rect.position, rect.end, rect.get_center()]:
			assert_false(_map().is_water(Vector2i(roundi(corner.x * 1024.0), roundi(corner.y * 1024.0))), "dry")
	var places: Array[Vector2] = [Rules.NURSERY_AT, Rules.GROVE_AT]
	places.append_array(Rules.STAND_AT)
	places.append_array(Rules.BUSH_AT)
	for site: int in Rules.SITE_COUNT:
		places.append(Rules.site_centre_m(site))
	for at: Vector2 in places:
		for circle: Vector3 in world.obstacles():
			assert_true(at.distance_to(Vector2(circle.x, circle.z)) > circle.y + 0.4, "%s clear of the world" % at)


# --- the model -------------------------------------------------------------------------------------------------------------

func test_the_old_orchard_is_real_rows() -> void:
	"""ECO-008's inherited start: an old apple and an old pear as OrchardPlot rows, aged, neglected and chilled; the east
	sites empty; the M3 grant in the nursery; the grove protected."""
	var model := ModelScript.new()
	assert_true(model.has_tree(0) and model.has_tree(1), "two old trees")
	assert_false(model.has_tree(2) or model.has_tree(3), "two empty sites")
	assert_equal(model.store.orchard_count(), 2, "two rows in the store")
	assert_equal(model.species_of(0), Rules.APPLE, "the apple")
	assert_equal(model.species_of(1), Rules.PEAR, "the pear")
	assert_equal(model.age_of(0), 480, "ten years")
	assert_equal(model.health_of(1), Rules.OLD_HEALTH, "neglected")
	assert_true(model.is_mature(0) and model.is_mature(1), "mature")
	assert_equal(model.store.chill_days_of(model.slot_of(0)).value, Rules.OLD_CHILL_DAYS, "a cold last winter")
	assert_equal(model.stage_of(0), Rules.STAGE_OLD, "old")
	assert_equal(model.stage_of(2), ModelScript.NONE, "no tree, no stage")
	assert_equal(model.saplings, PackedInt32Array([2, 2]), "the grant")
	assert_true(model.grove_protected, "the grove starts protected")
	assert_equal(model.species_of(2), ModelScript.NONE, "no species on an empty site")
	assert_equal(model.age_of(2), 0, "no age")
	assert_equal(model.health_of(3), 0, "no health")
	assert_equal(model.slot_of(3), ModelScript.NONE, "no row")


func test_a_day_untended_costs_100_and_tended_restores_50() -> void:
	"""§5.6 through the store: spring and summer only; the tending flag is today's."""
	var model := ModelScript.new()
	model.close_day(1, 120)
	assert_equal(model.health_of(0), Rules.OLD_HEALTH - 100, "untended spring day")
	assert_true(model.record_tending(0), "tended")
	assert_true(model.tended_today(0), "flag set")
	model.close_day(2, 120)
	assert_equal(model.health_of(0), Rules.OLD_HEALTH - 50, "tended: +50")
	assert_false(model.tended_today(0), "the flag clears at midnight")
	assert_false(model.record_tending(2), "no tree to tend")
	var before: int = model.health_of(1)
	model.close_day(30, 120)
	assert_equal(model.health_of(1), before, "autumn: no change")
	assert_equal(model.today_hint, 31, "today moves on")


func test_the_old_trees_bear_once_in_their_window() -> void:
	"""REQ-SET-079/080 through the store: the apple Autumn 1-6 at its §5.6 yield (health and chill), once a year; the
	pear from Autumn 3; the flag cleared by the next year's first day."""
	var model := ModelScript.new()
	assert_equal(model.harvest_refusal(0, APPLE_DAY - 1), String(Hive.REFUSE_OUTSIDE_HARVEST_WINDOW), "summer")
	assert_equal(model.harvest_refusal(0, APPLE_DAY), "", "Autumn 1")
	assert_equal(model.harvest_refusal(1, APPLE_DAY), String(Hive.REFUSE_OUTSIDE_HARVEST_WINDOW), "not the pear's yet")
	assert_equal(model.harvest_refusal(1, PEAR_DAY), "", "the pear's Autumn 3")
	@warning_ignore("integer_division") var expected: int = 80000 * Rules.OLD_HEALTH / 10000
	assert_equal(model.expected_yield_milli(0), expected, "80 U at 35% health")
	assert_equal(model.pick_tree(0, APPLE_DAY), expected, "picked")
	assert_equal(model.fruit_picked_milli[Rules.APPLE], expected, "tallied")
	assert_equal(model.harvest_refusal(0, APPLE_DAY + 1), String(Hive.REFUSE_ALREADY_HARVESTED_THIS_YEAR), "once")
	assert_equal(model.pick_tree(0, APPLE_DAY + 1), 0, "a second picking gives nothing")
	model.close_day(SimClock.DAYS_PER_YEAR + 1, 120)
	assert_equal(model.harvest_refusal(0, SimClock.DAYS_PER_YEAR + APPLE_DAY), "", "next year's window")
	assert_equal(model.pick_tree(3, APPLE_DAY), 0, "no tree")


func test_a_young_tree_bears_early_then_fully() -> void:
	"""Decision 0672: an apple planted on day 1 bears a fifth from its first window past a year (Y2 Autumn 1), once;
	§5.6's full crop from maturity (day 97: Y3 Autumn 1)."""
	var model := ModelScript.new()
	assert_true(model.take_sapling(2, Rules.APPLE, false), "a free sapling")
	assert_true(model.plant(2, Rules.APPLE, 1), "planted day 1")
	assert_equal(model.health_of(2), Hive.HEALTH_MAX, "BAL-CAT-010: health 10000")
	assert_equal(model.harvest_refusal(2, APPLE_DAY), String(Hive.REFUSE_NOT_MATURE), "too young in Y1")
	assert_equal(model.next_harvest_day(2, 1), 73, "Y2 Autumn 1")
	assert_equal(model.first_early_day(Rules.APPLE, 1), 73, "the planting's early day")
	assert_equal(model.store.first_eligible_harvest_day(Rules.APPLE, 1).value, 121, "REQ-SET-081: Y3 Autumn 1")
	for day: int in range(1, 73):
		model.close_day(day, 120)
	assert_equal(model.age_of(2), 72, "aged")
	assert_equal(model.harvest_refusal(2, 73), "", "the early picking")
	var early: int = model.expected_yield_milli(2)
	assert_equal(early, Rules.early_yield_milli(80000, model.health_of(2), 1000, Hive.CHILL_FACTOR_LOW), "a fifth, at its health and chill")
	assert_equal(model.pick_tree(2, 73), early, "picked early")
	assert_equal(model.harvest_refusal(2, 74), String(Hive.REFUSE_ALREADY_HARVESTED_THIS_YEAR), "once a year")
	assert_equal(model.next_harvest_day(2, 74), 121, "next: the full crop")


func test_an_early_year_is_not_picked_twice_when_it_matures_in_its_window() -> void:
	"""A tree picked early whose maturity falls later in the same window is not picked again that year."""
	var model := ModelScript.new()
	model.take_sapling(2, Rules.APPLE, false)
	model.plant(2, Rules.APPLE, 1)
	model.store.restore_orchard_state(model.site_ref[2], 95, 10000, 6, false, false)
	model.today_hint = 120
	assert_equal(model.pick_tree(2, 121), Rules.early_yield_milli(80000, 10000, 1000, 100), "an early picking the day before maturity")
	model.close_day(121, 120)
	assert_true(model.is_mature(2), "mature now")
	assert_equal(model.harvest_refusal(2, 122), String(Hive.REFUSE_ALREADY_HARVESTED_THIS_YEAR), "not twice in one year")


func test_planting_refusals_and_saplings() -> void:
	"""A planting needs an empty site not promised to another plan and a sapling (its plan's, else a free one)."""
	var model := ModelScript.new()
	assert_equal(model.plant_refusal(0, Rules.APPLE, 1, false), ModelScript.REFUSE_SITE_TAKEN, "a tree stands there")
	assert_equal(model.plant_refusal(2, Rules.APPLE, 1, false), "", "an empty site, a free sapling")
	assert_equal(model.plant_refusal(2, 5, 1, false), ModelScript.REFUSE_NOT_ELIGIBLE, "no such species")
	assert_equal(model.plant_refusal(9, Rules.APPLE, 1, false), ModelScript.REFUSE_NOT_ELIGIBLE, "no such site")
	model.saplings[Rules.PEAR] = 0
	assert_equal(model.plant_refusal(2, Rules.PEAR, 1, false), ModelScript.REFUSE_NO_SAPLING, "no pear sapling")
	assert_false(model.take_sapling(2, Rules.PEAR, false), "none to take")
	assert_equal(model.add_plan(Rules.APPLE, 3), "", "a plan for east site 2")
	assert_equal(model.plant_refusal(3, Rules.PEAR, 1, false), ModelScript.REFUSE_SITE_PLANNED, "promised to the plan")
	assert_equal(model.plant_refusal(3, Rules.APPLE, 1, true), ModelScript.REFUSE_NO_SAPLING, "the plan's sapling is not ready")
	assert_true(model.take_sapling(2, Rules.APPLE, false), "a free apple")
	assert_equal(model.saplings[Rules.APPLE], 1, "one left")
	assert_true(model.plant(2, Rules.APPLE, 5), "planted")
	assert_equal(model.planted_day[2], 5, "on day 5")
	assert_false(model.plant(2, Rules.PEAR, 5), "the block is taken (the store refuses)")


func test_a_plan_grows_its_sapling_and_promises_its_site() -> void:
	"""ECO-009: a plan WAITS, GROWS §5.6's 12 days once propagated, is READY for its site, and closes when planted; a
	waiting plan may be dropped, a growing one may not; six plans at most."""
	var model := ModelScript.new()
	assert_equal(model.add_plan(Rules.PEAR, 0), ModelScript.REFUSE_SITE_TAKEN, "not on a tree")
	assert_equal(model.add_plan(Rules.PEAR, 2), "", "planned")
	assert_equal(model.add_plan(Rules.APPLE, 2), ModelScript.REFUSE_SITE_PLANNED, "one plan a site")
	var plan: int = model.plan_for_site(2)
	assert_equal(model.plan_state[plan], ModelScript.PLAN_WAITING, "waiting")
	assert_equal(model.plan_count(ModelScript.PLAN_WAITING), 1, "counted")
	model.start_growing(plan, 10)
	assert_equal(model.plan_ready_day[plan], 22, "§5.6: ready 12 days on")
	assert_false(model.drop_plan(plan), "a growing sapling stays promised")
	model.close_day(20, 120)
	assert_equal(model.plan_state[plan], ModelScript.PLAN_GROWING, "not yet")
	model.close_day(21, 120)
	assert_equal(model.plan_state[plan], ModelScript.PLAN_READY, "ready on day 22")
	assert_equal(model.plant_refusal(2, Rules.PEAR, 22, true), "", "the plan's own sapling")
	assert_true(model.take_sapling(2, Rules.PEAR, true), "taken from the plan")
	assert_equal(model.plan_for_site(2), ModelScript.NONE, "the plan is closed")
	assert_equal(model.saplings[Rules.PEAR], 2, "the free stock is untouched")
	assert_equal(model.add_plan(Rules.APPLE, 3), "", "another")
	assert_true(model.drop_plan(model.plan_for_site(3)), "a waiting plan dropped")
	assert_false(model.drop_plan(99), "no such plan")
	for k: int in Rules.MAX_PLANS:
		model.plan_state[k] = ModelScript.PLAN_WAITING
		model.plan_site[k] = 100 + k
	assert_equal(model.add_plan(Rules.APPLE, 3), ModelScript.REFUSE_NO_PLAN_ROW, "six at most")


func test_the_hedge_fruits_in_summer_and_keeps_its_floor() -> void:
	"""§5.5: nothing picked in spring or winter; never below a fifth; summer's regrowth at the day's close."""
	var model := ModelScript.new()
	assert_equal(model.berries_available_milli(0), 0, "spring: dormant")
	assert_equal(model.berries_available_milli(3), 0, "winter: dormant")
	assert_equal(model.berries_available_milli(1), 180000, "summer: all above the floor")
	assert_equal(model.pick_berries(5000, 0), 0, "nothing in spring")
	assert_equal(model.pick_berries(500000, 1), 180000, "down to the floor")
	assert_equal(model.hedge_milli, 60000, "the floor kept")
	assert_equal(model.berries_picked_milli, 180000, "tallied")
	assert_equal(model.pick_berries(1000, 1), 0, "nothing below the floor")
	model.close_day(12, 120)
	assert_equal(model.hedge_milli, 60000 + Rules.berry_growth_milli(60000, 1), "day 12 closes into summer: it grows")


func test_the_grove_record_keeps_the_newest() -> void:
	"""ECO-015: protection toggles; a season's observation noted, newest first, MAX_RECORDS kept."""
	var model := ModelScript.new()
	model.set_grove_protected(false)
	assert_false(model.grove_protected, "lifted")
	for k: int in Rules.MAX_RECORDS + 3:
		model.record_observation(k, "line %d" % k)
	assert_equal(model.grove_record.size(), Rules.MAX_RECORDS, "bounded")
	assert_equal(model.grove_record[0], "line %d" % (Rules.MAX_RECORDS + 2), "newest first")
	assert_equal(model.grove_seen_season, Rules.MAX_RECORDS + 2, "the season seen")
	assert_equal(ModelScript.season_index_of_day(1), 0, "Y1 spring")
	assert_equal(ModelScript.season_index_of_day(13), 1, "Y1 summer")
	assert_equal(ModelScript.season_index_of_day(49), 4, "Y2 spring")


# --- the pantry's hooks ------------------------------------------------------------------------------------------------------

func test_a_stand_is_never_a_destination() -> void:
	"""farm_storage.gd KEY_STAGING: the stands are stores the orchard reserves at by name; a harvest's or delivery's
	choice passes them by."""
	var rig := _rig()
	var stand: int = _stand(rig, 0)
	assert_true(rig.pantry.storage.is_staging(stand), "staging")
	assert_false(rig.pantry.storage.is_staging(0), "the covered store is not")
	assert_false(rig.pantry.storage.is_staging(99), "no such store")
	assert_true(rig.pantry.location_near_into(1000, Rules.STAND_AT[0], _read), "a place")
	assert_false(rig.pantry.storage.is_staging(_read.value), "never a stand, even beside it")
	assert_true(rig.pantry.reserve_at_into(Catalog.ITEM_APPLE, 5000, stand, _read), "held at the stand by name")
	assert_equal(rig.pantry.reserved_milli_of(stand), 5000, "held")
	assert_false(rig.pantry.reserve_at_into(Catalog.ITEM_APPLE, 999999, stand, _read), "more than it holds")
	assert_false(rig.pantry.reserve_at_into(99, 1000, stand, _read), "not an item")
	assert_false(rig.pantry.reserve_at_into(Catalog.ITEM_APPLE, 0, stand, _read), "nothing")
	assert_false(rig.pantry.reserve_at_into(Catalog.ITEM_APPLE, 1000, 99, _read), "no such store")


func test_moving_food_keeps_its_age_and_the_ledger() -> void:
	"""farm_pantry.gd `move_upto_into`: what fits moves, its lot's age with it (never fresher), the ledger untouched."""
	var rig := _rig()
	var stand: int = _stand(rig, 0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 12000, stand, _read), "stocked")
	var lot: int = _read.value
	for hour: int in 30:
		rig.pantry.age_hour(0)
	var age: int = rig.pantry.lot_age(lot)
	assert_true(age > 0, "aged")
	var stored: int = rig.pantry.stored_total_milli(Catalog.ITEM_APPLE)
	assert_true(rig.pantry.move_upto_into(lot, rig.pantry.lot_serial(lot), 10000, 0, -1, _read), "moved")
	assert_equal(_read.value, 10000, "all of it fitted")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), 2000, "the rest at the stand")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, 0), 10000, "in the covered store")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_APPLE), 12000, "nothing gained or lost")
	assert_equal(rig.pantry.stored_total_milli(Catalog.ITEM_APPLE), stored, "the ledger counts it once")
	assert_equal(rig.pantry.withdrawn_total_milli(Catalog.ITEM_APPLE), 0, "and not as used")
	for row: int in PantryScript.MAX_LOTS:
		if rig.pantry.lot_item(row) == Catalog.ITEM_APPLE and rig.pantry.lot_location(row) == 0:
			assert_equal(rig.pantry.lot_age(row), age, "the moved lot keeps its age")
	assert_false(rig.pantry.move_upto_into(lot, 12345, 1000, 0, -1, _read), "a stale lot is refused")
	assert_false(rig.pantry.move_upto_into(lot, rig.pantry.lot_serial(lot), 1000, stand, -1, _read), "not to itself")
	assert_false(rig.pantry.move_upto_into(lot, rig.pantry.lot_serial(lot), 0, 0, -1, _read), "nothing")


func test_a_move_takes_what_fits_and_merges_keeping_the_older_age() -> void:
	"""A store with less room takes what fits; with no free lot row, the move merges into the oldest lot there, aged to
	the older of the two."""
	var rig := _rig()
	var stand: int = _stand(rig, 0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, 50000, stand, _read), "a big basket")
	var lot: int = _read.value
	var cover: int = StorageScript.STORE_CAPACITY_U * 1000
	assert_true(rig.pantry.add_into(0, cover - 3000, 0, _read), "the store nearly full")
	assert_true(rig.pantry.move_upto_into(lot, rig.pantry.lot_serial(lot), 10000, 0, -1, _read), "moved")
	assert_equal(_read.value, 3000, "only what fits")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_PEAR, stand), 47000, "the rest stays")
	var older: int = lot
	for hour: int in 12:
		rig.pantry.age_hour(0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, 1000, 1, _read), "a young pear lot in the kitchen's pantry")
	var young: int = _read.value
	while rig.pantry.lot_count() < PantryScript.MAX_LOTS:
		rig.pantry.add_into(5, 1, 1, _read)
	assert_true(rig.pantry.move_upto_into(older, rig.pantry.lot_serial(older), 2000, 1, -1, _read), "moved")
	assert_equal(_read.value, 2000, "into the merged lot")
	assert_equal(rig.pantry.lot_milli(young), 3000, "merged into the kitchen's pear lot")
	assert_equal(rig.pantry.lot_age(young), rig.pantry.lot_age(older), "aged to the older")


# --- the board ---------------------------------------------------------------------------------------------------------------

func test_the_board_opens_one_job_a_kind_a_target() -> void:
	"""A second opening is the first; a full board refuses; find and count read it."""
	var rig := _rig()
	assert_true(rig.jobs.open_into(JobsScript.K_TEND, 0, JobsScript.ORIGIN_ROUTINE, _read), "opened")
	var first: int = _read.value
	assert_true(rig.jobs.open_into(JobsScript.K_TEND, 0, JobsScript.ORIGIN_PLAYER, _read), "again")
	assert_equal(_read.value, first, "the same job")
	assert_equal(rig.jobs.origin[first], JobsScript.ORIGIN_PLAYER, "the player's now")
	assert_equal(rig.jobs.find(JobsScript.K_TEND, 0), first, "found")
	assert_equal(rig.jobs.find(JobsScript.K_TEND, 1), JobsScript.NONE, "not on the other tree")
	assert_equal(rig.jobs.count_of(JobsScript.K_TEND, JobsScript.NONE), 1, "one tending")
	for t: int in JobsScript.MAX_JOBS - 1:
		assert_true(rig.jobs.open_into(JobsScript.K_OBSERVE, t, JobsScript.ORIGIN_ROUTINE, _read), "fill")
	assert_false(rig.jobs.open_into(JobsScript.K_PICK, 0, JobsScript.ORIGIN_ROUTINE, _read), "full")
	assert_false(rig.jobs.is_live(-1) or rig.jobs.is_live(JobsScript.MAX_JOBS), "out of range")


func test_the_routine_raises_the_seasons_work() -> void:
	"""Spring: a tending for each tree and the grove's observation; autumn (Autumn 1): no tending, the apple's harvest,
	the pear's not yet, a picking (the hedge above its floor in autumn)."""
	var spring := _rig(1)
	spring.jobs.plan_work()
	assert_true(spring.jobs.find(JobsScript.K_TEND, 0) >= 0 and spring.jobs.find(JobsScript.K_TEND, 1) >= 0, "tend both")
	assert_true(spring.jobs.find(JobsScript.K_OBSERVE, 0) >= 0, "the grove's observation")
	assert_equal(spring.jobs.count_of(JobsScript.K_PICK, JobsScript.NONE), 0, "no berries in spring")
	assert_equal(spring.jobs.count_of(JobsScript.K_HARVEST, JobsScript.NONE), 0, "no harvest")
	var autumn := _rig(APPLE_DAY)
	autumn.jobs.plan_work()
	assert_equal(autumn.jobs.count_of(JobsScript.K_TEND, JobsScript.NONE), 0, "no care in autumn")
	assert_true(autumn.jobs.find(JobsScript.K_HARVEST, 0) >= 0, "the apple")
	assert_equal(autumn.jobs.find(JobsScript.K_HARVEST, 1), JobsScript.NONE, "the pear waits for Autumn 3")
	assert_equal(autumn.jobs.count_of(JobsScript.K_PICK, JobsScript.NONE), 1, "one picking at a time")


func test_together_timing_waits_for_the_whole_group() -> void:
	"""ECO-010: All together holds the apple until the pear may be picked too (Autumn 3), or its window closes."""
	var rig := _rig(APPLE_DAY)
	rig.model.group_timing[0] = Rules.TIMING_TOGETHER
	rig.jobs.plan_work()
	assert_equal(rig.jobs.find(JobsScript.K_HARVEST, 0), JobsScript.NONE, "the apple waits")
	var later := _rig(PEAR_DAY)
	later.model.group_timing[0] = Rules.TIMING_TOGETHER
	later.jobs.plan_work()
	assert_true(later.jobs.find(JobsScript.K_HARVEST, 0) >= 0 and later.jobs.find(JobsScript.K_HARVEST, 1) >= 0, "together")


func test_a_cancelled_routine_job_is_not_raised_again_today() -> void:
	"""The player's Cancel holds for the day; a player's order lifts it."""
	var rig := _rig(1)
	rig.jobs.plan_work()
	var j: int = rig.jobs.find(JobsScript.K_TEND, 0)
	assert_equal(rig.jobs.cancel(j), "", "cancelled")
	rig.jobs.plan_work()
	assert_equal(rig.jobs.find(JobsScript.K_TEND, 0), JobsScript.NONE, "not again today")
	assert_equal(rig.jobs.order(JobsScript.K_TEND, 0, -1, PackedInt32Array()), "", "ordered")
	assert_true(rig.jobs.find(JobsScript.K_TEND, 0) >= 0, "back on the board")
	assert_equal(rig.jobs.cancel(99), Text.GONE, "no such job")


func test_a_resident_tends_a_tree() -> void:
	"""A tending on the real layout: walked to, 20 WU worked at the trunk, recorded today -- +50 at midnight."""
	var rig := _rig(1)
	assert_equal(rig.jobs.order(JobsScript.K_TEND, 0, -1, PackedInt32Array([0])), "", "ordered for resident 0")
	var j: int = rig.jobs.find(JobsScript.K_TEND, 0)
	assert_equal(rig.jobs.worker[j], 0, "resident 0 has it")
	assert_true(_run(rig, func() -> bool: return rig.model.tended_today(0)), "tended")
	assert_equal(rig.jobs.find(JobsScript.K_TEND, 0), JobsScript.NONE, "the job is done")
	rig.model.close_day(1, 120)
	assert_equal(rig.model.health_of(0), Rules.OLD_HEALTH + 50, "+50 at midnight")


func test_a_harvest_goes_to_the_baskets_and_on_to_a_store() -> void:
	"""Autumn 1: the old apple picked (80 WU), its fruit carried to the old orchard's baskets, then hauled on to the
	store that keeps it longest (never the other stand); every unit accounted for at each step; no room left held."""
	var rig := _rig(APPLE_DAY)
	var expected: int = rig.model.expected_yield_milli(0)
	rig.model.group_keep[0] = 0
	assert_equal(rig.jobs.order(JobsScript.K_HARVEST, 0, -1, PackedInt32Array([1])), "", "ordered")
	var stand: int = _stand(rig, 0)
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) > 0), "at the baskets")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), expected, "all of it")
	assert_equal(rig.model.fruit_picked_milli[Rules.APPLE], expected, "tallied")
	assert_equal(rig.pantry.stored_total_milli(Catalog.ITEM_APPLE), expected, "the ledger: harvested once")
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_HAUL, 0) >= 0, "a haul raised")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) == 0 \
		and rig.jobs.count_of(JobsScript.K_HAUL, JobsScript.NONE) == 0), "hauled on (the routine raising each next haul)")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_APPLE), expected, "nothing lost or gained")
	assert_equal(rig.pantry.stored_total_milli(Catalog.ITEM_APPLE), expected, "the moves are not counted again")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, _stand(rig, 1)), 0, "not to the other stand")
	_no_holds(rig, "after the hauls")


func test_room_first_a_full_stand_waits() -> void:
	"""Decision 0222: with the baskets full the tree is not picked -- the job waits saying why."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	assert_true(rig.pantry.add_into(5, Rules.STAND_CAPACITY_U * 1000, stand, _read), "full")
	assert_equal(rig.jobs.order(JobsScript.K_HARVEST, 0, -1, PackedInt32Array([1])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HARVEST, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.words[j].begins_with(Text.NO_ROOM_HEAD), 3000), "waits")
	assert_equal(rig.model.fruit_picked_milli[Rules.APPLE], 0, "not picked")
	assert_equal(rig.model.harvest_refusal(0, APPLE_DAY), "", "still on the tree")
	assert_true(rig.jobs.is_live(j), "the job stays")
	assert_true(rig.jobs.words[j].contains("Pantry (K)"), "it says where to make room")


func test_a_picking_fills_a_basket_of_berries() -> void:
	"""Summer: the canes picked (4 WU a U), the pantry's one `berries` item carried to the east orchard's baskets, the
	hedge debited."""
	var rig := _rig(14)
	var before: int = rig.model.hedge_milli
	assert_equal(rig.jobs.order(JobsScript.K_PICK, 0, -1, PackedInt32Array([2])), "", "ordered")
	var stand: int = _stand(rig, 1)
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_BERRIES, stand) > 0), "picked")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_BERRIES, stand), Rules.PICK_LOAD_MILLI, "a basket")
	assert_equal(rig.model.berries_picked_milli, Rules.PICK_LOAD_MILLI, "tallied")
	assert_true(rig.model.hedge_milli <= before - Rules.PICK_LOAD_MILLI + Rules.berry_growth_milli(0, 1),
		"the hedge gave them (less a day's regrowth at most)")


func test_a_planting_takes_its_sapling_and_compost_when_done() -> void:
	"""An apple planted on east site 1: 40 WU, then the sapling and §5.6's compost 4 U taken; a new row."""
	var rig := _rig(3)
	assert_equal(rig.jobs.order(JobsScript.K_PLANT, 2, Rules.APPLE, PackedInt32Array([3])), "", "ordered")
	assert_equal(rig.compost, 40000, "nothing taken at the order")
	assert_true(_run(rig, func() -> bool: return rig.model.has_tree(2)), "planted")
	assert_equal(rig.compost, 36000, "4 U of compost")
	assert_equal(rig.model.saplings[Rules.APPLE], 1, "one sapling")
	assert_equal(rig.model.species_of(2), Rules.APPLE, "an apple")
	assert_equal(rig.model.planted_day[2], 3, "planted on day 3")
	rig.compost = 0
	assert_true(rig.jobs.order(JobsScript.K_PLANT, 3, Rules.PEAR, PackedInt32Array()).contains("compost"), "no compost: refused")


func test_a_plan_is_propagated_grown_and_planted() -> void:
	"""ECO-009 end to end: a plan, the nursery's 120 WU taking fruit 4, compost 2 and water 2, the 12-day wait, then
	the planting the routine raises for its site."""
	var rig := _rig(30)
	_services.stores.add_water(10000)
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, 6000, _stand(rig, 0), _read), "pears at the baskets")
	assert_equal(rig.model.add_plan(Rules.PEAR, 3), "", "planned")
	var plan: int = rig.model.plan_for_site(3)
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_PROPAGATE, plan) >= 0, "a propagation raised")
	assert_true(_run(rig, func() -> bool: return rig.model.plan_state[plan] == ModelScript.PLAN_GROWING), "propagated")
	assert_equal(rig.pantry.withdrawn_total_milli(Catalog.ITEM_PEAR), 4000, "fruit 4 U taken, as used")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_PEAR), 2000 + rig.model.fruit_picked_milli[Rules.PEAR] \
		- _in_hand(rig, Catalog.ITEM_PEAR), "the rest (and the old pear's routine harvest, Autumn 3-8)")
	assert_equal(rig.compost, 38000, "compost 2 U")
	assert_equal(_services.stores.water_milli_u, 8000, "water 2 U")
	rig.calendar.tick += 12 * SimClock.TICKS_PER_DAY
	_close_days(rig)
	assert_equal(rig.model.plan_state[plan], ModelScript.PLAN_READY, "ready after 12 days")
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_PLANT, 3) >= 0, "its planting raised")
	assert_true(_run(rig, func() -> bool: return rig.model.has_tree(3)), "planted")
	assert_equal(rig.model.species_of(3), Rules.PEAR, "the plan's pear")
	assert_equal(rig.model.saplings[Rules.PEAR], 2, "the free saplings untouched")
	assert_equal(rig.model.plan_for_site(3), ModelScript.NONE, "the plan closed")


func test_the_grove_is_observed_once_a_season() -> void:
	"""ECO-015: the routine's observation walks to the grove's stone and notes the season, the trees standing counted."""
	var rig := _rig(2)
	rig.jobs.grove_trees = func() -> int: return 2
	rig.jobs.plan_work()
	assert_true(_run(rig, func() -> bool: return rig.model.grove_record.size() == 1), "observed")
	assert_true(rig.model.grove_record[0].contains("2 trees standing"), rig.model.grove_record[0])
	assert_true(rig.model.grove_record[0].contains("bees"), "spring's sighting")
	rig.jobs.plan_work()
	assert_equal(rig.jobs.find(JobsScript.K_OBSERVE, 0), JobsScript.NONE, "once a season")


func test_a_drought_tending_pays_two_units_of_water() -> void:
	"""§5.6: water 2 U a day during drought, from the butt; with none, no tending."""
	var rig := _rig(15)
	rig.weather.observe(1, 3, 12, 300, 0, WeatherCore.EVENT_DROUGHT)
	assert_true(rig.jobs.drought(), "a drought")
	assert_true(rig.jobs.order(JobsScript.K_TEND, 0, -1, PackedInt32Array()).contains("water"), "no water: refused")
	_services.stores.add_water(5000)
	assert_equal(rig.jobs.order(JobsScript.K_TEND, 0, -1, PackedInt32Array([0])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return rig.model.tended_today(0)), "tended")
	var tended: int = (1 if rig.model.tended_today(0) else 0) + (1 if rig.model.tended_today(1) else 0)
	assert_equal(_services.stores.water_milli_u, 5000 - 2000 * tended, "2 U of water a tending (the pear's routine one too)")


func test_a_carrier_called_away_sets_its_load_down_and_another_carries_it_on() -> void:
	"""Decision 0222: a picker called away mid-carry sets the fruit down where it stands; Cancel and Pause refuse while
	it is in hand; the next to take the job fetches it and stores it -- nothing lost."""
	var rig := _rig(APPLE_DAY)
	var expected: int = rig.model.expected_yield_milli(0)
	assert_equal(rig.jobs.order(JobsScript.K_HARVEST, 0, -1, PackedInt32Array([1])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HARVEST, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.in_hand(j)), "picked and carrying")
	assert_equal(rig.jobs.load_milli[j], expected, "the whole crop in hand")
	assert_true(rig.jobs.must_finish(j, rig.jobs.serial[j]), "the night waits for it")
	assert_equal(rig.jobs.cancel(j), Text.DELIVERY_GOES_ON, "Cancel refuses a delivery")
	assert_true(rig.jobs.pause(j, true).contains("carrying"), "Pause refuses a load in hand")
	assert_true(rig.jobs.reassign(j, 2).contains("carrying"), "and so does Reassign")
	rig.jobs.brain_of(1).release()
	assert_true(rig.jobs.load_at[j].is_finite(), "set down where it stood")
	assert_equal(rig.jobs.worker[j], JobsScript.NONE, "no worker")
	assert_equal(rig.jobs.point(j), rig.jobs.load_at[j], "the job is where the load lies")
	var stand: int = _stand(rig, 0)
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) > 0), "carried on")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) + _in_hand(rig, Catalog.ITEM_APPLE), expected, "all of it")


func test_pause_resume_and_reassign_a_waiting_job() -> void:
	"""A paused job is not offered; resumed it is; reassigned it goes to the named resident."""
	var rig := _rig(1)
	assert_equal(rig.jobs.order(JobsScript.K_TEND, 0, -1, PackedInt32Array()), "", "queued")
	var j: int = rig.jobs.find(JobsScript.K_TEND, 0)
	assert_true(rig.jobs.waiting(j), "waiting")
	assert_equal(rig.jobs.pause(j, true), "", "paused")
	assert_false(rig.jobs.waiting(j), "not offered while paused")
	assert_equal(rig.jobs.pause(j, false), "", "resumed")
	assert_true(rig.jobs.waiting(j), "offered again")
	assert_equal(rig.jobs.reassign(j, 4), "", "given to resident 4")
	assert_equal(rig.jobs.worker[j], 4, "resident 4 has it")
	assert_equal(rig.jobs.job_of_worker(4), j, "found by its worker")
	assert_equal(rig.jobs.eligibility(JobsScript.NONE, 4), Text.OTHER_JOB, "one orchard job a resident")
	assert_equal(rig.jobs.reassign(j, 5), "", "and on to resident 5")
	assert_equal(rig.jobs.job_of_worker(4), JobsScript.NONE, "4 let go")
	assert_equal(rig.jobs.pause(j, true), "", "a worker's job paused: let go")
	assert_equal(rig.jobs.worker[j], JobsScript.NONE, "no worker while paused")
	assert_equal(rig.jobs.pause(99, true), Text.GONE, "no such job")
	assert_equal(rig.jobs.reassign(99, 1), Text.GONE, "no such job to reassign")


func test_the_kitchen_policy_sends_the_baskets_to_the_kitchen_and_the_keep_stays() -> void:
	"""ECO-010's destination: with the old orchard set to the kitchen, a haul takes the apples to the kitchen's pantry;
	the nursery's share (4 U) stays at the stand."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_dest[0] = Rules.DEST_KITCHEN
	rig.model.group_keep[0] = Rules.KEEP_STEPS[1]
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 9000, stand, _read), "apples at the baskets")
	rig.jobs.plan_work()
	var j: int = rig.jobs.find(JobsScript.K_HAUL, 0)
	assert_true(j >= 0, "a haul")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, 1) > 0 \
		and rig.jobs.count_of(JobsScript.K_HAUL, JobsScript.NONE) == 0), "hauled")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, 1), 5000, "to the kitchen pantry (store 1)")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), 4000, "the nursery's share kept")
	rig.jobs.plan_work()
	assert_equal(rig.jobs.find(JobsScript.K_HAUL, 0), JobsScript.NONE, "nothing above the keep: no haul")


func test_order_refusals_say_why() -> void:
	"""Each kind's refusal in words, and a full board."""
	var rig := _rig(1)
	assert_true(rig.jobs.order_refusal(JobsScript.K_HARVEST, 0, -1).contains("picking time"), "out of the window")
	assert_true(rig.jobs.order_refusal(JobsScript.K_HARVEST, 2, -1).contains("no tree"), "no tree")
	assert_true(rig.jobs.order_refusal(JobsScript.K_PICK, 0, -1).contains("no berries"), "spring hedge")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_HAUL, 0, -1), Text.NOTHING_TO_HAUL, "empty baskets")
	assert_true(rig.jobs.order_refusal(JobsScript.K_PLANT, 0, Rules.APPLE, ).contains("already stands"), "a tree there")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_PROPAGATE, 0, -1), Text.PLAN_GONE, "no waiting plan")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_OBSERVE, 0, -1), "", "the grove may always be observed")
	assert_true(rig.jobs.order_refusal(JobsScript.K_TEND, 2, -1).contains("no tree"), "no tree to tend")
	var autumn := _rig(30)
	assert_true(autumn.jobs.order_refusal(JobsScript.K_TEND, 0, -1).contains("autumn"), "no care in autumn")


func test_the_keeping_policy_sends_the_baskets_to_the_cellar() -> void:
	"""ECO-010's other destination: the store that keeps food longest (the cellar's 350, not the kitchen's 750)."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 6000, stand, _read), "apples at the baskets")
	rig.jobs.plan_work()
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, 4) == 6000), "hauled")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, 1), 0, "not the kitchen")


func test_a_year_old_tree_bears_on_the_day_it_turns_one() -> void:
	"""Decision 0672's boundary: at exactly 48 days old, in its window, a young tree may be picked; at 47 it may not."""
	var model := ModelScript.new()
	model.take_sapling(2, Rules.APPLE, false)
	model.plant(2, Rules.APPLE, 1)
	model.store.restore_orchard_state(model.site_ref[2], 47, 10000, 6, false, false)
	assert_equal(model.harvest_refusal(2, APPLE_DAY), String(Hive.REFUSE_NOT_MATURE), "47 days: no")
	model.store.restore_orchard_state(model.site_ref[2], 48, 10000, 6, false, false)
	assert_equal(model.harvest_refusal(2, APPLE_DAY), "", "48 days: yes")


func test_a_ready_plan_plants_only_its_own_species() -> void:
	"""A site's ready plan's sapling is its species: planting the other species there is refused."""
	var model := ModelScript.new()
	model.add_plan(Rules.PEAR, 2)
	var plan: int = model.plan_for_site(2)
	model.start_growing(plan, 1)
	model.close_day(12, 120)
	assert_equal(model.plan_state[plan], ModelScript.PLAN_READY, "ready")
	assert_equal(model.plant_refusal(2, Rules.APPLE, 13, true), ModelScript.REFUSE_SITE_PLANNED, "not an apple")
	assert_equal(model.plant_refusal(2, Rules.PEAR, 13, true), "", "its pear")


func test_work_completes_at_exactly_its_need() -> void:
	"""§5.2: 20 WU of care take `work_usec(20000)` at the base rate (its microseconds rounded down: a hundred more
	finish it) -- complete then, not a milli-WU later."""
	var rig := _rig(1)
	assert_true(rig.jobs.open_into(JobsScript.K_TEND, 0, JobsScript.ORIGIN_ROUTINE, _read), "a tending")
	var j: int = _read.value
	rig.jobs.need_mwu[j] = Rules.CARE_MWU
	rig.jobs.pos[j] = 1
	rig.jobs._credit(j, Rules.work_usec(Rules.CARE_MWU) - 50000)
	assert_false(rig.model.tended_today(0), "not before")
	rig.jobs._credit(j, 50100)
	assert_true(rig.model.tended_today(0), "done at its need")


func test_a_carrier_lost_three_times_keeps_its_load() -> void:
	"""A job with fruit cut is never given up for an unreachable walk: its load waits where it was set down."""
	var rig := _rig(APPLE_DAY)
	assert_true(rig.jobs.open_into(JobsScript.K_HARVEST, 0, JobsScript.ORIGIN_ROUTINE, _read), "a harvest")
	var j: int = _read.value
	rig.jobs.load_item[j] = Catalog.ITEM_APPLE
	rig.jobs.load_milli[j] = 5000
	for k: int in JobsScript.MAX_TRIES + 1:
		rig.jobs.worker[j] = 0
		rig.jobs._unreached(j, rig.jobs.brain_of(0))
	assert_true(rig.jobs.is_live(j), "kept")
	assert_equal(rig.jobs.load_milli[j], 5000, "its load with it")
	assert_true(rig.jobs.load_at[j].is_finite(), "set down")


func test_a_held_picking_leaves_less_for_the_next() -> void:
	"""Room held by one picking is not offered to another: with a basket's worth above the floor held, there is none."""
	var rig := _rig(14)
	rig.model.hedge_milli = Rules.berry_floor_milli() + Rules.PICK_LOAD_MILLI
	assert_true(rig.jobs.open_into(JobsScript.K_PICK, 0, JobsScript.ORIGIN_ROUTINE, _read), "a picking")
	assert_true(rig.pantry.reserve_at_into(Catalog.ITEM_BERRIES, Rules.PICK_LOAD_MILLI, _stand(rig, 1), _read), "held")
	rig.jobs.hold[rig.jobs.find(JobsScript.K_PICK, 0)] = _read.value
	assert_equal(rig.jobs.order_refusal(JobsScript.K_PICK, 1, -1), Text.NO_BERRIES, "nothing left for another bush")


func test_a_haul_called_away_releases_its_room() -> void:
	"""A haul's worker called away mid-carry: its room at the store released, its basket still in its lot."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 6000, stand, _read), "apples at the baskets")
	assert_equal(rig.jobs.order(JobsScript.K_HAUL, 0, -1, PackedInt32Array([2])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HAUL, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.carrying(j)), "loaded")
	var held: int = rig.jobs.hold[j]
	assert_true(rig.pantry.is_hold(held), "room held at the store")
	rig.jobs.brain_of(2).release()
	assert_false(rig.pantry.is_hold(held), "its room released")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), 6000, "the basket never left its lot")
	assert_equal(rig.jobs.step_of(j), JobsScript.S_GO, "it starts again from the stand")


func test_a_haul_follows_its_store_when_the_stores_move() -> void:
	"""H1: a store added ahead of the kitchen moves its index; the haul unloads where its room is held, by id."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	rig.model.group_keep[0] = 0
	rig.model.group_dest[0] = Rules.DEST_KITCHEN
	assert_true(rig.pantry.add_into(Catalog.ITEM_APPLE, 6000, stand, _read), "apples at the baskets")
	assert_equal(rig.jobs.order(JobsScript.K_HAUL, 0, -1, PackedInt32Array([2])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HAUL, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.carrying(j)), "loaded")
	var kitchen_id: Variant = rig.pantry.storage.id_of(1)
	rig.pantry.storage.add_provider(func() -> Array: return [])
	rig.pantry.storage._providers.push_front(func() -> Array: return [{StorageScript.KEY_ID: &"new_cellar",
		StorageScript.KEY_POSITION: Vector2(0.0, -10.0), StorageScript.KEY_CAPACITY_U: 50, StorageScript.KEY_PERMILLE: 350}])
	rig.pantry.refresh_locations()
	assert_true(rig.pantry.storage.index_of_id_into(kitchen_id, _read) and _read.value != 1, "the kitchen moved")
	var kitchen: int = _read.value
	var held: int = rig.jobs.hold[j]
	assert_true(_run(rig, func() -> bool: return not rig.jobs.is_live(j)), "unloaded")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, kitchen), 6000, "into the kitchen, wherever it now stands")
	assert_false(rig.pantry.is_hold(held), "its room released")


func test_a_worker_off_its_spot_walks_back_and_resumes_the_work() -> void:
	"""M1: a picker moved off its spot mid-work walks back and finishes the same work (its progress kept)."""
	var rig := _rig(APPLE_DAY)
	assert_equal(rig.jobs.order(JobsScript.K_HARVEST, 0, -1, PackedInt32Array([1])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HARVEST, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.done_mwu[j] > 5000), "working")
	var job_serial: int = rig.jobs.serial[j]
	var brain: BrainScript = rig.jobs.brain_of(1)
	brain.position += Vector2(3.0, 0.0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.carrying(j)), "picked after walking back")
	assert_equal(rig.jobs.serial[j], job_serial, "the same job finished its work (not ended and raised afresh)")
	assert_equal(rig.jobs.load_milli[j], rig.model.fruit_picked_milli[Rules.APPLE], "the crop in hand")


func test_no_job_is_raised_that_cannot_start() -> void:
	"""M2/M3: a drought with an empty butt raises no tending; a tree too spent to bear raises no harvest."""
	var dry := _rig(15)
	dry.weather.observe(1, 3, 12, 300, 0, WeatherCore.EVENT_DROUGHT)
	dry.jobs.plan_work()
	assert_equal(dry.jobs.count_of(JobsScript.K_TEND, JobsScript.NONE), 0, "no water: no tending raised")
	var spent := _rig(APPLE_DAY)
	spent.model.store.restore_orchard_state(spent.model.site_ref[0], 480, 0, 8, false, false)
	spent.jobs.plan_work()
	assert_equal(spent.jobs.find(JobsScript.K_HARVEST, 0), JobsScript.NONE, "a dead tree: no harvest raised")
	assert_equal(spent.jobs.order_refusal(JobsScript.K_HARVEST, 0, -1), Text.BEARS_NOTHING, "and the order says why")


func test_a_partial_delivery_keeps_the_rest_in_hand() -> void:
	"""A picker whose room at the stand was lost stores what fits there and keeps the rest in hand until there is room
	-- nothing lost."""
	var rig := _rig(APPLE_DAY)
	var stand: int = _stand(rig, 0)
	assert_equal(rig.jobs.order(JobsScript.K_HARVEST, 0, -1, PackedInt32Array([1])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_HARVEST, 0)
	assert_true(_run(rig, func() -> bool: return rig.jobs.in_hand(j)), "carrying")
	var carried: int = rig.jobs.load_milli[j]
	var lost: int = rig.jobs.hold[j]
	rig.jobs.hold[j] = JobsScript.NONE
	assert_true(rig.pantry.add_into(5, Rules.STAND_CAPACITY_U * 1000 - carried - 3000, stand, _read), "the stand nearly full")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_APPLE, stand) > 0, 4000), "some stored")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_APPLE, stand), 3000, "what fitted")
	assert_equal(rig.jobs.load_milli[j], carried - 3000, "the rest still in hand")
	assert_true(rig.jobs.is_live(j) and rig.jobs.kind[j] == JobsScript.K_HARVEST, "the delivery goes on")
	rig.pantry.release(lost)


func test_a_job_nobody_can_reach_is_given_up_after_three_tries() -> void:
	"""MAX_TRIES unreachable walks with nothing in hand: the job is dropped (the routine raises it again)."""
	var rig := _rig(1)
	assert_true(rig.jobs.open_into(JobsScript.K_TEND, 0, JobsScript.ORIGIN_ROUTINE, _read), "a tending")
	var j: int = _read.value
	for k: int in JobsScript.MAX_TRIES:
		rig.jobs.worker[j] = 0
		rig.jobs._unreached(j, rig.jobs.brain_of(0))
	assert_false(rig.jobs.is_live(j), "given up")


func test_together_picks_a_tree_whose_window_closes() -> void:
	"""ECO-010: All together never lets a window pass -- on its last day a tree is picked whatever the group waits for."""
	var rig := _rig(APPLE_DAY + 5)
	rig.model.group_timing[0] = Rules.TIMING_TOGETHER
	rig.model.early_year[1] = 1
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_HARVEST, 0) >= 0, "the apple on its window's last day")


func test_the_first_early_day_boundary() -> void:
	"""An early day falling on the day of maturity is no early day (`<`, not `<=`): the tree is mature then."""
	var model := ModelScript.new()
	for plant_day: int in range(1, 49):
		var early: int = model.first_early_day(Rules.APPLE, plant_day)
		assert_true(early == 0 or early < plant_day + 96, "before maturity (day %d)" % plant_day)
	assert_equal(model.first_early_day(Rules.APPLE, 25), 73, "planted on Autumn 1: early on the next Autumn 1")


func test_a_propagation_does_not_work_a_new_plan_on_a_reused_row() -> void:
	"""A plan dropped and its row reused by another: the old propagation is refused, not finished against it."""
	var rig := _rig(30)
	assert_equal(rig.model.add_plan(Rules.PEAR, 3), "", "planned")
	var plan: int = rig.model.plan_for_site(3)
	assert_true(rig.jobs.open_into(JobsScript.K_PROPAGATE, plan, JobsScript.ORIGIN_ROUTINE, _read), "a propagation")
	rig.jobs._note_target(_read.value)
	assert_true(rig.model.drop_plan(plan), "dropped")
	assert_equal(rig.model.add_plan(Rules.APPLE, 2), "", "a new plan on the same row")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_PROPAGATE, plan, -1), Text.PLAN_GONE, "not its plan")


func test_the_nursery_takes_its_fruit_from_the_stands_only() -> void:
	"""The propagation's fruit comes from the baskets, never a store's (older) lots the kitchen may plan to cook."""
	var rig := _rig(30)
	_services.stores.add_water(10000)
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, 6000, 0, _read), "older pears in the covered store")
	for hour: int in 12:
		rig.pantry.age_hour(2)
	assert_true(rig.pantry.add_into(Catalog.ITEM_PEAR, 5000, _stand(rig, 0), _read), "pears at the baskets")
	assert_equal(rig.model.add_plan(Rules.PEAR, 3), "", "planned")
	var plan: int = rig.model.plan_for_site(3)
	assert_true(rig.jobs.open_into(JobsScript.K_PROPAGATE, plan, JobsScript.ORIGIN_ROUTINE, _read), "a propagation")
	var j: int = _read.value
	rig.jobs.need_mwu[j] = Rules.PROPAGATE_MWU
	rig.jobs.pos[j] = 1
	rig.jobs._credit(j, Rules.work_usec(Rules.PROPAGATE_MWU) + 100)
	assert_equal(rig.model.plan_state[plan], ModelScript.PLAN_GROWING, "propagated")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_PEAR, 0), 6000, "the store's pears untouched")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_PEAR, _stand(rig, 0)), 1000, "4 U from the baskets")
