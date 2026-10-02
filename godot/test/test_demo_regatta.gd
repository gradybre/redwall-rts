extends "res://test/framework/test_case.gd"
## The regatta (decision 0438; review SOC-023, SOC-025, UX-028; water part B lane 3): the GDD's Hearth feast numbers for
## the village, the preview's refusals (a host who cooks, the main course's beans and cabbage, REQ-SET-101's reserves and
## their override), holding it (the food reserved, the wood set aside, the kitchen's occasion), once a season and the
## graceful skip (everything given back untouched), the first in summer, the deterministic race on the real pond (the
## faster crew home first; a dead heat; called off in a storm), and the feast at the day's supper -- bean hotpot cooked
## from the reserved food and eaten at the hall's tables -- with its tally, chronicle, the winners' deed and the feast's
## company.
##
## Built over the placeholder cast on the real layout and the real village water (as test_demo_fishery.gd), the real
## kitchen over its brains at the hall's real tables -- no staged assets, no scene tree.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/regatta/regatta_rules.gd")
const RegattaScript := preload("res://demo/regatta/regatta.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const KitchenNode := preload("res://demo/kitchen/demo_kitchen.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const Ledger := preload("res://demo/people/people_ledger.gd")
const PeopleText := preload("res://demo/people/people_text.gd")

const DT: float = 0.1
const SUMMER_1: int = 12
const PEA: int = 11
const CABBAGE: int = 6
const CARROT: int = 2
const OATS: int = 15

## The rig: the placeholder cast on the village water, the fishery's fleet and skills, the kitchen at the hall's tables
## and the regatta over them; and what the regatta told the people and the news.
class Rig:
	var cast: DemoCastScript = null
	var play: WaterplayScript = null
	var fishery: FisheryScript = null
	var kitchen: KitchenScript = null
	var pantry: PantryScript = null
	var calendar: CalendarScript = null
	var weather: DemoWeatherScript = null
	var regatta: RegattaScript = null
	var posted: PackedStringArray = PackedStringArray()
	var deeds: Array = []
	var shared: Array = []

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
## Every rig a test built: its regatta's hooks are lambdas that hold the rig, which holds the regatta -- a cycle
## `after_each` breaks (decision 0501).
var _rigs: Array[Rig] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built, and let each rig's regatta drop the hooks that hold the rig."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()
	for rig: Rig in _rigs:
		if rig.regatta != null:
			rig.regatta.post = Callable()
			rig.regatta.record_deed = Callable()
			rig.regatta.share_feast = Callable()
	_rigs.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water, built once."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of absolute `day`."""
	return Rules.race_tick(day, hour)


func _rig(day: int = SUMMER_1, hour: int = 8) -> Rig:
	"""The placeholder cast walking the real layout round the water's band, the water's play (its band), the fishery's
	fleet and skills (two helms: residents 4 and 5, fishing 2 and 4), the kitchen at the hall's tables (resident 0 its
	cook), and the regatta, on the calendar at `hour`:00 of absolute `day`."""
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
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = tick_at(day, hour)
	rig.weather = DemoWeatherScript.new()
	rig.weather.observe(1, 1, hour, 160, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.fishery = FisheryScript.new()
	rig.fishery.configure(rig.cast, null, rig.pantry, null, _services.stores, rig.calendar, rig.weather, _map())
	rig.fishery.skills.xp[4] = 2 * 2 * 5000
	rig.fishery.skills.xp[5] = 4 * 4 * 5000
	_kitchen_over(rig)
	rig.regatta = RegattaScript.new()
	rig.regatta.configure(rig.cast, rig.fishery.fleet, rig.fishery.skills, rig.fishery.ice, rig.kitchen, _services.stores,
		rig.calendar, rig.weather, _map())
	rig.regatta.post = func(text: String, _summary: String) -> void: rig.posted.append(text)
	rig.regatta.record_deed = func(who: PackedInt32Array, subject: String) -> int:
		rig.deeds.append([who, subject])
		return rig.deeds.size()
	rig.regatta.share_feast = func(who: PackedInt32Array) -> void: rig.shared.append(who)
	_rigs.append(rig)
	return rig


func _kitchen_over(rig: Rig) -> void:
	"""The real kitchen over the cast's brains at the hall's real cauldron, tables, well and butt (demo_kitchen.gd's
	places); resident 0 the village cook."""
	var places := PlacesScript.new()
	places.set_points(KitchenNode._at(Layout.PROPS, KitchenNode.CAULDRON_ID), KitchenNode._at(Layout.PROPS, KitchenNode.TABLE_E_ID),
		KitchenNode._at(Layout.BUILDINGS, KitchenNode.WELL_ID), KitchenNode._at(Layout.PROPS, KitchenNode.BUTT_ID))
	places.add_table_seats(KitchenNode._at(Layout.PROPS, KitchenNode.TABLE_E_ID), PlacesScript.SEATS_PER_TABLE)
	places.add_table_seats(KitchenNode._at(Layout.PROPS, KitchenNode.TABLE_W_ID), PlacesScript.SEATS_PER_TABLE)
	places.find_spots(rig.cast.space(), rig.cast.bounds(), KitchenNode.CAULDRON_POI, KitchenNode.WELL_POI)
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var species := PackedStringArray()
	var keys: Array[StringName] = []
	for i: int in rig.cast.actor_count():
		var actor := rig.cast.actor(i) as DemoActorScript
		brains.append(actor.brain)
		names.append(actor.display_name)
		species.append("mouse")
		keys.append(&"mouse_keeper" if i == 0 else StringName("mouse_%d" % i))
	rig.kitchen = KitchenScript.new()
	rig.kitchen.configure(brains, names, species, keys, rig.pantry, _services.stores, rig.calendar, places)


func _stock(rig: Rig, item: int, milli: int) -> void:
	"""Put `milli` of `item` in the covered store."""
	assert_true(rig.pantry.add_into(item, milli, 0, _read), "stocked")


func _stock_feast(rig: Rig) -> void:
	"""Enough for the main course and some to spare: peas, cabbage, the butt full."""
	_stock(rig, PEA, 8000)
	_stock(rig, CABBAGE, 8000)
	_services.stores.add_water(40000)


func _run(rig: Rig, done: Callable, frames: int) -> bool:
	"""Step the cast, the calendar, the water, the fleet, the kitchen and the regatta until `done()` (bounded)."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.play.step(usec)
		rig.fishery.fleet.step(usec)
		rig.kitchen.update()
		rig.regatta.update()
		if OS.get_environment("REGATTA_DEBUG") == "1" and frame % 300 == 0:
			var r: RegattaScript = rig.regatta
			var parts := PackedStringArray()
			for place: int in RegattaScript.PLACES:
				var who: int = r.crews[place]
				var b: BrainScript = r.brain_of(who) if who >= 0 and who < rig.cast.actor_count() else null
				parts.append("%d:%d st%d %s task %s" % [who, r.crew_step[place], b.state if b != null else -1,
					b.position if b != null else Vector2.ZERO, b.task if b != null else null])
			printerr("##REG## f%d %s state %d h %d boats %s %s | %s" % [frame, r.day_text(r.today()), r.state, r.hour(),
				rig.fishery.fleet.owner, rig.fishery.fleet.phase, " | ".join(parts)])
	return bool(done.call())


# --- the numbers ---------------------------------------------------------------------------------------

func test_the_hearth_feast_for_nine_is_the_gdds() -> void:
	"""GDD §5.7's Hearth feast for E = 9: main ceil(9/3) = 3 bean_hotpot, second 3 nut_loaf, infusion water ceil(9/4) = 3 U
	and herb 0.25 x ceil(9/12) = 0.25 U; seats ceil(9/3) = 3; service wood ceil(9/12) = 1 U; 80% of E over every course
	for its buff; +5 affinity a pair (REQ-SET-036)."""
	assert_equal(Rules.main_batches(9), 3, "3 hotpot batches")
	assert_equal(Rules.main_batches(10), 4, "rounded up: 10 residents take 4")
	assert_equal(Rules.second_batches(9), 3, "3 nut loaf batches")
	assert_equal(Rules.infusion_water_milli(9), 3000, "3 U of water")
	assert_equal(Rules.infusion_herb_milli(9), 250, "0.25 U of herb")
	assert_equal(Rules.seats_needed(9), 3, "3 seats")
	assert_equal(Rules.service_wood_milli(9), 1000, "1 U of wood")
	assert_equal(Rules.service_wood_milli(13), 2000, "13 residents: 2 U")
	assert_true(Rules.covered(8, 10) and not Rules.covered(7, 10), "80% exactly")
	assert_false(Rules.covered(0, 9), "nobody at every course: no buff")
	assert_equal(Ledger.FEAST_GAIN, 5, "REQ-SET-036's feast gain")
	var hotpot: int = MealRules.DISH_BEAN_HOTPOT
	assert_equal(MealRules.GDD_ROWS[hotpot], "bean_hotpot", "the GDD's row")
	assert_equal(MealRules.INPUT_MILLI[hotpot] + MealRules.SIDE_MILLI[hotpot], 4000, "beans 2 + cabbage 2")
	assert_equal(MealRules.WATER_MILLI[hotpot], 2000, "water 2")
	assert_equal(MealRules.PORTIONS_PER_BATCH[hotpot] * MealRules.NP_PER_PORTION[hotpot], 6300, "3 x 2100 NP")
	assert_equal(MealRules.WORK_MWU[hotpot], 20000, "20 WU")
	assert_equal(MealRules.SHELF_HOURS[hotpot], 36, "keeps 36 h")


func test_the_race_lanes_are_equal_boat_water() -> void:
	"""Each boat's lane is boat water from its berth, the two equal in length; a better crew's pace is higher."""
	for boat: int in RegattaScript.BOATS:
		var lane: PackedInt32Array = Rules.lane(boat)
		assert_true(Routes.leg_is_water(_map(), Vector2i(lane[0], lane[1]), Vector2i(lane[2], lane[3])), "lane %d is water" % boat)
		assert_equal(Routes.leg_length_u(Vector2i(lane[0], lane[1]), Vector2i(lane[2], lane[3])), Rules.LANE_U, "lane %d's length" % boat)
	assert_equal(Rules.pace_permille(0, 0), FleetScript.PACE_NORMAL, "no fishing, the ordinary pace")
	assert_equal(Rules.pace_permille(4, 1), 1200, "fishing 4 + 1: 120%")


# --- planning ------------------------------------------------------------------------------------------

func test_the_first_regatta_is_in_summer_and_the_day_is_the_players() -> void:
	"""In spring the choices are the coming summer's days; in summer, its days from tomorrow."""
	var rig: Rig = _rig(3, 8)
	assert_equal(rig.regatta.target_season(), Rules.FIRST_SEASON, "the first is summer's")
	var days: PackedInt32Array = rig.regatta.day_choices()
	assert_equal(days.size(), SimClock.DAYS_PER_SEASON, "every summer day")
	assert_equal(days[0], SUMMER_1, "from summer 1")
	assert_equal(rig.regatta.day_text(days[0]), "Summer 1", "named")
	rig = _rig(SUMMER_1 + 4, 8)
	days = rig.regatta.day_choices()
	assert_equal(days[0], SUMMER_1 + 5, "in summer: from tomorrow")
	assert_equal(days[days.size() - 1], SUMMER_1 + 11, "to the season's end")
	rig.regatta.choice_day = days[0]
	rig.regatta.step_day(1)
	assert_equal(rig.regatta.choice_day, days[1], "Day ▶")
	rig.regatta.step_day(-5)
	assert_equal(rig.regatta.choice_day, days[0], "◀ Day stops at the first")


func test_the_preview_refuses_what_is_invalid_and_names_what_is_missing() -> void:
	"""A host who cooks; no beans; no cabbage; the reserves under 3 days without the override -- each refused with its
	fix; the crews are the two helms and two others, never the host or the cook; the preview says the second course
	and the infusion can't be made and no buff follows."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	var day: int = SUMMER_1 + 1
	assert_equal(rig.kitchen.designated, 0, "resident 0 is the village cook")
	r.refusal(day, 0, true)
	assert_equal(r.refused_code, "HOST_COOKS", "the cook can't host")
	r.refusal(day, 2, true)
	assert_equal(r.refused_code, "NO_BEANS", "no beans: %s" % r.refusal(day, 2, true))
	_stock(rig, PEA, 8000)
	r.refusal(day, 2, true)
	assert_equal(r.refused_code, "NO_CABBAGE", "no cabbage")
	_stock(rig, CABBAGE, 8000)
	r.refusal(day, 2, false)
	assert_equal(r.refused_code, "RESERVES", "no ready food: the reserves are under 3 days")
	assert_equal(r.refusal(day, 2, true), "", "the explicit override holds it")
	var crew: PackedInt32Array = r.crews_for(2)
	assert_equal(crew[0], 5, "the best helm takes the first boat")
	assert_equal(crew[2], 4, "the second helm the other")
	assert_false(crew.has(2) or crew.has(0), "never the host or the cook")
	var text: String = "\n".join(r.preview_lines(day, 2))
	assert_true(text.contains("bean hotpot x%d" % Rules.main_batches(r.residents())), "the main course: %s" % text)
	assert_true(text.contains("no nuts or herb"), "what can't be made, said")
	assert_true(text.contains("no Shared Warmth"), "no buff without every course")
	_stock(rig, OATS, 40000)
	_stock(rig, CARROT, 40000)
	assert_equal(r.refusal(day, 2, false), "", "with ready food in store, no override is needed")


func test_holding_reserves_the_food_and_wood_and_skipping_gives_them_back() -> void:
	"""Held: the main course's beans and cabbage reserved (no longer free), the service wood out of the stores, the
	kitchen's supper of that day the occasion's; skipped before the feast: every unit back, nothing lost; once a season."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var wood: int = _services.stores.wood_milli_u
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	var need: int = r.main_food_milli(r.residents())
	assert_equal(need, Rules.main_batches(r.residents()) * 2000, "2 U of each a batch")
	assert_equal(r.free_beans(), 8000 - need, "the main course's beans set aside")
	assert_equal(r.free_cabbage(), 8000 - need, "its cabbage set aside")
	assert_equal(_services.stores.wood_milli_u, wood - 1000, "1 U of service wood set aside")
	assert_equal(rig.kitchen.occasion_key, Rules.feast_key(day), "the kitchen's supper of that day")
	assert_equal(rig.kitchen.plan_of(Rules.feast_key(day))[0], MealRules.DISH_BEAN_HOTPOT, "planned as bean hotpot")
	assert_true(r.refusal(day, 2, true).contains("already"), "once a season: no second plan")
	assert_equal(r.skip(), "", "skipped")
	assert_equal(_services.stores.wood_milli_u, wood, "the wood back")
	assert_equal(rig.kitchen.occasion_key, KitchenScript.FREE, "no occasion")
	# The supper goes back to the cook's own choice, which may be the hotpot: since the recipe book it is an everyday
	# supper dish as well (decision 0601), so the kitchen may hold some beans and greens for it again -- its own.
	var plan: PackedInt32Array = rig.kitchen.plan_of(Rules.feast_key(day))
	var own: int = plan[3] * 2000 if plan[0] == MealRules.DISH_BEAN_HOTPOT else 0
	assert_equal(r.free_beans(), 8000 - own, "the beans back, but the everyday supper's own")
	assert_equal(r.free_cabbage(), 8000 - own, "the cabbage back, but the everyday supper's own")
	assert_true(r.skip().contains("skipped"), "skipped already")
	assert_true(r.target_season() > Rules.FIRST_SEASON, "this season is done: the next one's is next")


func test_food_is_reserved_at_once_for_a_day_beyond_the_kitchens_plans() -> void:
	"""Held for a day the kitchen has not planned yet, the main course's beans and cabbage are set aside at once (the
	regatta's own reservation), and the kitchen adopts it when it plans that supper."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 4
	assert_equal(r.hold(day, 2, true), "", "held")
	assert_false(rig.kitchen.occasion_adopted(), "the kitchen has not planned that supper yet")
	assert_equal(r.free_beans(), 8000 - r.main_food_milli(r.residents()), "the beans set aside all the same")
	assert_equal(r.free_cabbage(), 8000 - r.main_food_milli(r.residents()), "and the cabbage")


func test_the_kitchen_cooks_an_occasion_as_set_whatever_its_count_or_food() -> void:
	"""The kitchen's AN OCCASION contract: a meal set as an occasion before the kitchen plans it is adopted when planned
	-- the occasion's dish and its own batch count, never one counted from the residents -- and its dish is never
	re-chosen by the alternation, even with nothing reserved for it yet."""
	var rig: Rig = _rig()
	var day: int = SUMMER_1 + 4
	var key: int = Rules.feast_key(day)
	_stock(rig, CABBAGE, 8000)
	_stock(rig, CARROT, 40000)
	rig.kitchen.set_occasion(key, MealRules.DISH_BEAN_HOTPOT, 5, rig.kitchen.takes.new_take())
	assert_false(rig.kitchen.occasion_adopted(), "not planned yet")
	rig.calendar.tick = tick_at(day, 6)
	rig.kitchen.update()
	assert_true(rig.kitchen.occasion_adopted(), "adopted when the kitchen plans that supper")
	var plan: PackedInt32Array = rig.kitchen.plan_of(key)
	assert_equal(plan.size(), 5, "that supper planned")
	if plan.size() == 5:
		assert_equal(plan[0], MealRules.DISH_BEAN_HOTPOT, "the occasion's dish, though no beans are there and the soup's food is")
		assert_equal(plan[1], 5, "the occasion's own five batches, not a count of the residents")


func test_the_tally_counts_only_those_who_ate_the_main_course() -> void:
	"""Attendance is who ate the feast's bean hotpot at that supper: one who ate another dish, or missed it, is not
	counted."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	var key: int = Rules.feast_key(day)
	var hour: int = day * SimClock.HOURS_PER_DAY + 17
	rig.kitchen.fed.ate_meal(1, key, MealRules.DISH_BEAN_HOTPOT, hour)
	rig.kitchen.fed.ate_meal(3, key, MealRules.DISH_BEAN_HOTPOT, hour)
	rig.kitchen.fed.ate_meal(2, key, MealRules.DISH_SOUP, hour)
	rig.kitchen.fed.missed(4, key)
	r._tally()
	assert_equal(r.attendees, PackedInt32Array([1, 3]), "the two who ate the hotpot, no one else")
	assert_equal(r.state, RegattaScript.ST_DONE, "the day over")


func test_called_off_while_crews_walk_the_boats_stay_the_boathouses() -> void:
	"""A call-off while crews are still on their way (the give-up hour, a storm): arriving, a crew's part is over -- it
	never takes a boat for a race that is off, and every rowboat is free again at its ordinary pace."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_CREWING, 2000), "crews called")
	assert_true(r.crew_step.has(RegattaScript.C_WALK), "some crew still walking")
	r._call_off("a crew was not aboard by 16:00")
	_run(rig, func() -> bool: return false, 3000)
	assert_equal(r.crew_step.count(RegattaScript.C_NONE), RegattaScript.PLACES, "every crew's part over")
	for boat: int in RegattaScript.BOATS:
		assert_true(rig.fishery.fleet.is_free(boat), "rowboat %d the boathouse's" % boat)
		assert_equal(rig.fishery.fleet.pace_permille[boat], FleetScript.PACE_NORMAL, "at its ordinary pace")


func test_a_race_under_way_cannot_be_skipped() -> void:
	"""Skip is for an unplanned or planned season: once the crews are called the day goes on."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_CREWING, 2000), "crews called")
	assert_false(r.skip().is_empty(), "skip refused once the crews are called")
	assert_equal(r.state, RegattaScript.ST_CREWING, "the day goes on")


func test_a_feast_never_served_gives_its_food_and_wood_back() -> void:
	"""The calendar past the regatta's supper before it was served (the kitchen never planned it): the tally gives the
	service wood and the reserved beans and cabbage back -- nothing stays held for good."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var wood: int = _services.stores.wood_milli_u
	var day: int = SUMMER_1 + 4
	assert_equal(r.hold(day, 2, true), "", "held")
	assert_false(rig.kitchen.occasion_adopted(), "not planned by the kitchen")
	rig.calendar.tick = tick_at(day + 1, 8)
	r.update()
	assert_equal(r.state, RegattaScript.ST_DONE, "the day is over")
	assert_equal(_services.stores.wood_milli_u, wood, "the unserved wood back")
	assert_equal(r.free_beans(), 8000, "the beans back")
	assert_equal(r.free_cabbage(), 8000, "the cabbage back")


func test_skipping_a_plan_the_kitchen_has_not_planned_gives_the_food_back() -> void:
	"""Held for a day beyond the kitchen's plans (its own reservation only), a skip releases that reservation."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	assert_equal(r.hold(SUMMER_1 + 4, 2, true), "", "held")
	assert_false(rig.kitchen.occasion_adopted(), "not planned by the kitchen")
	assert_equal(r.skip(), "", "skipped")
	assert_equal(r.free_beans(), 8000, "the beans back")
	assert_equal(r.free_cabbage(), 8000, "the cabbage back")


func test_a_skip_costs_nothing() -> void:
	"""Skipping an unplanned season changes no store, pantry or resident; the next season's regatta opens with it."""
	var rig: Rig = _rig()
	_stock_feast(rig)
	var wood: int = _services.stores.wood_milli_u
	assert_equal(rig.regatta.skip(), "", "skipped")
	assert_equal(_services.stores.wood_milli_u, wood, "no wood")
	assert_equal(rig.regatta.free_beans(), 8000, "no food")
	assert_true(rig.posted.is_empty() and rig.deeds.is_empty(), "no chronicle, no deed, no item")
	rig.calendar.tick = tick_at(SUMMER_1 + SimClock.DAYS_PER_SEASON, 8)
	rig.regatta.update()
	assert_equal(rig.regatta.state, RegattaScript.ST_IDLE, "autumn's regatta opens")
	assert_equal(rig.regatta.target_season(), Rules.FIRST_SEASON + 1, "for autumn")


# --- the day -------------------------------------------------------------------------------------------

func test_the_race_is_rowed_and_the_faster_crew_wins_every_time() -> void:
	"""The crews walk to the boathouse jetty, board, row their lanes out and home; the better-fishing crew's boat is home
	first (deterministic); the boats given back, the crews ashore."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_RACING, 6000), "the race is off (%s)" % r.status_line())
	assert_true(rig.fishery.fleet.owner[0] == RegattaScript.RACE_SERIAL and rig.fishery.fleet.owner[1] == RegattaScript.RACE_SERIAL,
		"both rowboats the race's")
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_RACED, 3000), "the race is over")
	var fast: int = 0 if r.pace_of(0, r.crews) > r.pace_of(1, r.crews) else 1
	assert_equal(r.winner, fast, "the faster crew home first")
	assert_true(r.finish_tick[fast] < r.finish_tick[1 - fast], "by its finish tick")
	assert_true(r.moment_line.contains("home first"), "the moment: %s" % r.moment_line)
	var ashore := func() -> bool: return r.crew_step.count(RegattaScript.C_NONE) == RegattaScript.PLACES
	assert_true(_run(rig, ashore, 2000), "every crew ashore")
	for boat: int in RegattaScript.BOATS:
		assert_true(rig.fishery.fleet.is_free(boat), "boat %d given back" % boat)
		assert_equal(rig.fishery.fleet.pace_permille[boat], FleetScript.PACE_NORMAL, "its ordinary pace back")
	for place: int in RegattaScript.PLACES:
		assert_false(r.brain_of(r.crews[place]).water_hold, "crew %d off the water" % place)


func test_equal_crews_row_a_dead_heat() -> void:
	"""Equal paces bring both boats home on the same tick: a dead heat, both crews named in the chronicle (no deed: no
	crew won)."""
	var rig: Rig = _rig()
	rig.fishery.skills.xp[5] = 2 * 2 * 5000
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	r.hold(day, 2, true)
	r.crews = PackedInt32Array([4, 1, 5, 3])
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_RACED, 9000), "the race is over")
	assert_equal(r.pace_of(0, r.crews), r.pace_of(1, r.crews), "equal paces")
	assert_equal(r.winner, RegattaScript.BOATS, "a dead heat")
	assert_true(r.moment_line.contains("dead heat"), "said: %s" % r.moment_line)


func test_a_storm_calls_the_race_off_and_the_feast_goes_on() -> void:
	"""REQ-SET-052: no boat leaves in a storm -- the race is called off at the start, the boats given back, the crews
	ashore; the plan stays for the feast."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	r.hold(day, 2, true)
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	rig.weather.observe(1, 2, 14, 160, 2400, WeatherCore.EVENT_HEAVY_RAIN)
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_RACED, 6000), "decided")
	assert_true(r.race_off.contains("storm"), "called off: %s" % r.race_off)
	assert_equal(r.winner, RegattaScript.NONE, "no winner")
	assert_true(_run(rig, func() -> bool: return r.crew_step.count(RegattaScript.C_NONE) == RegattaScript.PLACES, 3000), "crews ashore")
	assert_true(rig.fishery.fleet.is_free(0) and rig.fishery.fleet.is_free(1), "the boats given back")
	assert_equal(rig.kitchen.occasion_key, Rules.feast_key(day), "the feast still planned")


func test_the_feast_is_cooked_from_the_reserved_food_eaten_and_remembered() -> void:
	"""The day's supper is the occasion: three batches of bean hotpot cooked from the reserved beans and cabbage (exactly
	6 U of each gone), eaten at the hall's tables; at the supper's end the tally, the chronicle with its one moment, the
	winners' deed, and the feast's company shared; the season held."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_DONE, 30000), "the day is over (%s)" % r.status_line())
	var hotpot: int = 0
	for dish: int in rig.kitchen.cooked_dishes:
		hotpot += 1 if dish == MealRules.DISH_BEAN_HOTPOT else 0
	var batches: int = Rules.main_batches(r.eligible)
	assert_equal(hotpot, batches, "ceil(E/3) batches of bean hotpot")
	assert_equal(rig.pantry.milli_of(PEA), 8000 - batches * 2000, "the main course's beans eaten, no more")
	assert_equal(rig.pantry.milli_of(CABBAGE), 8000 - batches * 2000, "its cabbage eaten, no more")
	assert_true(r.attendees.size() * 2 > r.eligible, "most shared the feast (%d of %d)" % [r.attendees.size(), r.eligible])
	assert_equal(r.feasts_held, 1, "a feast held")
	assert_equal(rig.posted.size(), 1, "one chronicle line")
	assert_true(rig.posted[0].contains("regatta") and rig.posted[0].contains("The moment:"), "with its moment: %s" % rig.posted[0])
	assert_equal(rig.deeds.size(), 1, "the winners' deed recorded")
	assert_equal((rig.deeds[0][0] as PackedInt32Array).size(), 2, "both of the winning crew")
	assert_equal(rig.shared.size(), 1, "the feast's company shared once")
	assert_equal(r.wood_burnt_milli, 1000, "the service wood burnt")
	assert_equal(rig.kitchen.occasion_key, KitchenScript.FREE, "the occasion over")
	assert_true(r.seasons_done.has(Rules.FIRST_SEASON), "this season's is held")


func test_the_regatta_deed_reads_in_the_people_words() -> void:
	"""The ledger's new kind (KIND_REGATTA) is worded in a resident's history and told of the winner."""
	assert_equal(Ledger.KIND_COUNT, 9, "one kind added")
	assert_equal(Ledger.REFLECT_RANK.size(), Ledger.KIND_COUNT, "a reflection rank for it")
	assert_equal(PeopleText.event_text(Ledger.KIND_REGATTA, "summer regatta's race", "", 0), "Won the summer regatta's race", "its history row")
	assert_equal(PeopleText.deed_text(Ledger.KIND_REGATTA, "Corra Netley", "summer regatta's race", "", 0),
		"Corra Netley won the summer regatta's race", "told of the winner")
	var ledger := Ledger.new()
	ledger.setup(3)
	assert_true(ledger.add_feast(0, 1, 5), "a feast shared")
	assert_equal(ledger.affinity_of(0, 1), Ledger.FEAST_GAIN, "+5")
