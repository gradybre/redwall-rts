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
const FarmingScript := preload("res://scripts/core/farming.gd")
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
	assert_true(text.contains("short of nuts: %d.0 U needed, 0.0 U free" % (2 * Rules.second_batches(r.residents()))),
		"what can't be made, said from the real stock: %s" % text.replace("\n", " | "))
	assert_true(text.contains("short of herb: 0.2 U needed"), "the infusion's shortfall, said")
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
	"""Attendance is who ate the feast's bean hotpot at that supper, read from the meal-finalized event's committed
	diners (decision 0997): one who ate another dish, missed it, or is not among the event's diners is not counted."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	var key: int = Rules.feast_key(day)
	var hour: int = day * SimClock.HOURS_PER_DAY + 17
	for who: int in [1, 3, 5]:
		rig.kitchen.fed.ate_meal(who, key, MealRules.DISH_BEAN_HOTPOT, hour)
		rig.kitchen.note_course(who, key, MealRules.DISH_BEAN_HOTPOT)
	rig.kitchen.fed.ate_meal(2, key, MealRules.DISH_SOUP, hour)
	rig.kitchen.note_course(2, key, MealRules.DISH_SOUP)
	rig.kitchen.fed.missed(4, key)
	var final := KitchenScript.MealFinal.new()
	final.key = key
	final.diners = PackedInt32Array([3, 2, 1])
	r._tally(final)
	assert_equal(r.attendees, PackedInt32Array([1, 3]), "the two diners who ate the hotpot, in resident order -- not 5, whom the event does not carry")
	assert_equal(r.state, RegattaScript.ST_DONE, "the day over")
	assert_equal(r.feasts_served, 1, "someone ate the main course: a Regatta day (decision 1651)")


func test_a_supper_closed_with_no_hotpot_eaten_is_not_a_regatta_day() -> void:
	"""Brendan's ruling of 2026-10-07 (decision 1651): the supper's serving closed (a meal-finalized event), but its only
	diner ate soup -- nobody ate the feast's main course, so the day is held and NOT counted for "Regatta day"."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	var key: int = Rules.feast_key(day)
	rig.kitchen.fed.ate_meal(2, key, MealRules.DISH_SOUP, day * SimClock.HOURS_PER_DAY + 17)
	rig.kitchen.note_course(2, key, MealRules.DISH_SOUP)
	var final := KitchenScript.MealFinal.new()
	final.key = key
	final.diners = PackedInt32Array([2])
	r._tally(final)
	assert_equal(r.attendees.size(), 0, "nobody ate the hotpot")
	assert_equal([r.state, r.feasts_held, r.feasts_served], [RegattaScript.ST_DONE, 1, 0], "held, not a Regatta day")


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
	"""A season skip past the regatta's supper before it was served (the kitchen never planned it, never ended it: no
	meal-finalized event will come -- `meal_lapsed`): the tally, with nobody, gives the service wood and the reserved
	beans and cabbage back -- nothing stays held for good."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var wood: int = _services.stores.wood_milli_u
	var day: int = SUMMER_1 + 4
	assert_equal(r.hold(day, 2, true), "", "held")
	var take: int = r.take
	assert_false(rig.kitchen.occasion_adopted(), "not planned by the kitchen")
	rig.calendar.tick = tick_at(day + 1, 8)
	r.update()
	assert_equal(r.state, RegattaScript.ST_PLANNED, "the kitchen has not run past the supper: no tally yet")
	rig.kitchen.skip_to_hour(rig.calendar.hour_index())
	assert_true(rig.kitchen.meal_lapsed(Rules.feast_key(day)), "the supper lapsed")
	r.update()
	assert_equal(r.state, RegattaScript.ST_DONE, "the day is over")
	assert_equal(r.attendees.size(), 0, "nobody shared it")
	assert_equal([r.feasts_held, r.feasts_served], [1, 0], "a day held, no feast served: not a Regatta day (decision 1651)")
	assert_equal(_services.stores.wood_milli_u, wood, "the unserved wood back")
	for crop: int in [FarmingScript.CROP_BEANS, FarmingScript.CROP_CABBAGE]:
		assert_equal(rig.kitchen.takes.live_milli(rig.pantry, take, -1, crop), 0, "the feast's category %d let go" % crop)
	assert_equal([rig.pantry.milli_of(PEA), rig.pantry.milli_of(CABBAGE)], [8000, 8000], "none of it eaten")


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
	assert_equal([r.feasts_held, r.feasts_served], [1, 1], "a feast held and served")
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


# --- the full menu (decision 0682: Brendan's "add nuts & herbs now") ------------------------------------------

func _stock_menu(rig: Rig) -> void:
	"""The second course's flour and nuts and the infusion's herb, enough for nine, with some to spare."""
	_stock(rig, Catalog.ITEM_FLOUR, 8000)
	_stock(rig, Catalog.ITEM_NUTS, 8000)
	_stock(rig, Catalog.ITEM_HERB, 1000)


func test_the_nut_loaf_is_the_gdds_row_and_an_occasion_dish() -> void:
	"""§5.7's nut_loaf: flour 2 + nuts 2 + water 1 -> 3 x 2600 NP, 24 WU, 72 h; the library's nutbread; never the cook's
	choice (the recipe book's OCCASION dish; the hotpot is an everyday supper dish too, decision 0601); Shared Warmth is the Hearth row's -25% cold exposure and +400 mood for 48 h."""
	var loaf: int = MealRules.DISH_NUT_LOAF
	assert_equal(MealRules.GDD_ROWS[loaf], "nut_loaf", "the GDD's row")
	assert_equal([MealRules.INPUT_CROP[loaf], MealRules.SIDE_CROP[loaf]], [Catalog.CAT_FLOUR, Catalog.CAT_NUTS], "flour and nuts")
	assert_equal([MealRules.INPUT_MILLI[loaf], MealRules.SIDE_MILLI[loaf], MealRules.WATER_MILLI[loaf]], [2000, 2000, 1000], "2, 2, 1")
	assert_equal(MealRules.PORTIONS_PER_BATCH[loaf] * MealRules.NP_PER_PORTION[loaf], 7800, "3 x 2600 NP")
	assert_equal([MealRules.WORK_MWU[loaf], MealRules.SHELF_HOURS[loaf]], [24000, 72], "24 WU, 72 h")
	assert_true(MealRules.is_occasion_dish(loaf), "the nut loaf: an occasion dish")
	assert_false(MealRules.is_occasion_dish(MealRules.DISH_BEAN_HOTPOT), "the hotpot is everyday too (decision 0601)")
	assert_false(MealRules.is_meal_dish(loaf) or MealRules.is_everyday_dish(loaf), "never a meal's choice")
	assert_false(MealRules.is_occasion_dish(MealRules.DISH_SOUP), "the soup is everyday")
	assert_equal([Rules.BUFF_HOURS, Rules.BUFF_COLD_PERMILLE, Rules.BUFF_MOOD], [48, 750, 400], "Shared Warmth")


func test_the_preview_names_the_full_menu_when_the_pantry_holds_it() -> void:
	"""With flour, nuts and herb free, the second course and the infusion read makeable and the buff's terms are said;
	flour alone short names flour and the mill."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	_stock(rig, Catalog.ITEM_NUTS, 8000)
	_stock(rig, Catalog.ITEM_HERB, 1000)
	var e: int = r.residents()
	assert_true(r.menu.second_short(e).contains("short of flour"), "flour short: %s" % r.menu.second_short(e))
	_stock(rig, Catalog.ITEM_FLOUR, 8000)
	var text: String = " | ".join(r.preview_lines(SUMMER_1 + 1, 2))
	assert_false(text.contains("can't be made"), "every course makeable: %s" % text)
	@warning_ignore("integer_division") var needed: int = (800 * e + 999) / 1000
	assert_true(text.contains("Shared Warmth if %d of %d eat every course" % [needed, e]), "the buff's terms: %s" % text)


func test_holding_reserves_every_course_and_skipping_gives_it_all_back() -> void:
	"""Held with the whole menu in the pantry: the nut loaf's flour and nuts reserved, the infusion's herb and water set
	aside, the kitchen's occasion has its second course; skipped: every unit back."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	_stock_menu(rig)
	var water: int = _services.stores.water_milli_u
	assert_equal(r.hold(SUMMER_1 + 1, 2, true), "", "held")
	var e: int = r.residents()
	var loaf: int = 2000 * Rules.second_batches(e)
	assert_equal(r.menu.free_flour(), 8000 - loaf, "ceil(E/3) x 2 U of flour set aside")
	assert_equal(r.menu.free_nuts(), 8000 - loaf, "and of nuts")
	assert_equal(r.menu.free_herb(), 1000 - Rules.infusion_herb_milli(e), "the infusion's herb set aside")
	assert_equal(r.menu.water_held_milli, Rules.infusion_water_milli(e), "the infusion's water owed")
	assert_equal(_services.stores.water_milli_u, water, "the butt not drawn down ahead of the feast")
	assert_equal([rig.kitchen.occasion_second, rig.kitchen.occasion_second_batches],
		[MealRules.DISH_NUT_LOAF, Rules.second_batches(e)], "the second course")
	assert_equal(r.served_words(), "bean hotpot, nut loaf and the warm infusion", "the menu in words")
	assert_equal(r.skip(), "", "skipped")
	assert_equal([r.menu.free_flour(), r.menu.free_nuts(), r.menu.free_herb()], [8000, 8000, 1000], "everything back")
	assert_equal([_services.stores.water_milli_u, r.menu.water_held_milli], [water, 0], "nothing owed, the butt untouched")
	assert_equal(rig.kitchen.occasion_second, MealRules.NO_DISH, "no occasion")


func test_the_full_feast_is_cooked_eaten_and_warms_the_village() -> void:
	"""The day's supper with the whole menu: 3 batches of hotpot then 3 of nut loaf from the reserved food (exactly 6 U of
	flour and of nuts gone), each guest eats one portion of each, the infusion's herb poured for those who came, and --
	80% at every course -- Shared Warmth for 48 h, said in the chronicle."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	_stock_menu(rig)
	var water_start: int = _services.stores.water_milli_u
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_DONE, 30000), "the day is over (%s)" % r.status_line())
	var loaves: int = 0
	for dish: int in rig.kitchen.cooked_dishes:
		loaves += 1 if dish == MealRules.DISH_NUT_LOAF else 0
	var batches: int = Rules.second_batches(r.eligible)
	assert_equal(loaves, batches, "ceil(E/3) batches of nut loaf")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_FLOUR), 8000 - batches * 2000, "the loaves' flour, no more")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_NUTS), 8000 - batches * 2000, "the loaves' nuts, no more")
	@warning_ignore("integer_division") var herb: int = 250 * r.attendees.size() / r.eligible
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 1000 - herb, "the infusion's herb, for those who came")
	@warning_ignore("integer_division") var water: int = Rules.infusion_water_milli(r.eligible) * r.attendees.size() / r.eligible
	assert_equal(r.menu.water_used_milli, water, "its water, for those who came")
	assert_equal(water_start + rig.kitchen.poured_water_milli - rig.kitchen.consumed_water_milli, _services.stores.water_milli_u,
		"through the kitchen's water ledger")
	assert_equal(rig.kitchen.portions_eaten, r.attendees.size() * 2, "one portion of each course a guest, no more")
	assert_true(r.every_course * 10 >= r.eligible * 8, "80%% ate every course (%d of %d)" % [r.every_course, r.eligible])
	assert_true(r.menu.warmth_active(rig.calendar.tick), "Shared Warmth: %s" % r.warmth_line)
	assert_equal(r.menu.cold_exposure_permille(rig.calendar.tick), 750, "cold exposure -25%")
	assert_equal(r.menu.mood_bonus(rig.calendar.tick), 400, "mood +400")
	assert_true(rig.posted[0].contains("nut loaf") and rig.posted[0].contains("Shared Warmth"), "the chronicle: %s" % rig.posted[0])


func test_shared_warmth_is_granted_once_and_neither_stacks_nor_extends() -> void:
	"""REQ-SET-105: a second Hearth feast while Shared Warmth lasts does not extend it; after it lapses it may be granted
	again; under 80% at every course, or a course unserved, it is not granted."""
	var menu := RegattaScript.MenuScript.new()
	menu.second_planned = true
	menu.infusion_planned = true
	assert_true(menu.settle(9, 0, 8, 1000, 0).contains("48 h"), "granted at 8 of 9")
	var until: int = menu.warmth_until
	assert_equal(until, 1000 + 48 * SimClock.TICKS_PER_HOUR, "for 48 game hours")
	assert_equal(menu.warmth_hours_left(1000), 48, "48 h left at once")
	menu.second_planned = true
	menu.infusion_planned = true
	assert_true(menu.settle(9, 0, 9, 2000, 0).contains("not stacked"), "not stacked")
	assert_equal(menu.warmth_until, until, "nor extended")
	assert_equal(menu.warmth_hours_left(until - 1), 0, "a part hour is not a whole one")
	assert_false(menu.warmth_active(until), "lapsed at its end")
	menu.second_planned = true
	menu.infusion_planned = true
	assert_true(menu.settle(9, 0, 7, until, 0).contains("7 of 9"), "7 of 9 is under 80%")
	assert_true(menu.settle(9, 0, 9, until, 0).contains("not every course"), "a course unserved: none")
	assert_equal(menu.warmth_granted, 1, "granted once")


func test_a_two_course_occasion_holds_each_courses_food_and_no_more() -> void:
	"""The kitchen's AN OCCASION with a second course, set with nothing reserved on a supper the kitchen has planned: it
	holds the main course's beans and cabbage for its batches and the second's flour and nuts for its own -- never the
	main course's inputs for every batch."""
	var rig: Rig = _rig()
	var key: int = Rules.feast_key(SUMMER_1)
	for item: int in [PEA, CABBAGE, Catalog.ITEM_FLOUR, Catalog.ITEM_NUTS]:
		_stock(rig, item, 8000)
	var take: int = rig.kitchen.takes.new_take()
	rig.kitchen.set_occasion(key, MealRules.DISH_BEAN_HOTPOT, 2, take, MealRules.DISH_NUT_LOAF, 2)
	rig.kitchen.update()
	assert_true(rig.kitchen.occasion_adopted(), "adopted")
	var takes: RefCounted = rig.kitchen.takes
	for crop: int in [FarmingScript.CROP_BEANS, FarmingScript.CROP_CABBAGE, Catalog.CAT_FLOUR, Catalog.CAT_NUTS]:
		assert_equal(takes.live_milli(rig.pantry, take, -1, crop), 4000, "two batches' worth of category %d" % crop)
	assert_equal(rig.kitchen.plan_of(key)[1], 4, "four batches wanted: two of each")


func test_a_second_course_that_cannot_come_is_not_waited_for_nor_doubled() -> void:
	"""Held with the whole menu, then the nuts taken from the pantry: no loaf can be cooked, so a guest who has eaten the
	hotpot gets up and goes -- never taking a second hotpot portion -- and the feast grants no Shared Warmth."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	_stock_menu(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	r.menu.kitchen.takes.release(r.take)
	for lot: int in PantryScript.MAX_LOTS:
		if rig.pantry.lot_item(lot) == Catalog.ITEM_NUTS:
			rig.pantry.withdraw_into(lot, rig.pantry.lot_serial(lot), rig.pantry.lot_milli(lot), _read)
	rig.kitchen.takes.reserve_into(rig.pantry, r.take, FarmingScript.CROP_BEANS, r.main_food_milli(r.residents()), 0, _read)
	rig.kitchen.takes.reserve_into(rig.pantry, r.take, FarmingScript.CROP_CABBAGE, r.main_food_milli(r.residents()), 0, _read)
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_DONE, 30000), "the day is over (%s)" % r.status_line())
	assert_equal(rig.kitchen.portions_eaten, r.attendees.size(), "one hotpot portion a guest, never two")
	assert_false(r.menu.warmth_active(rig.calendar.tick), "no Shared Warmth without the second course")
	assert_true(r.warmth_line.begins_with("no Shared Warmth"), r.warmth_line)


# --- the feast's end is the kitchen's meal-finalized event (decision 0997; Brendan's ruling on review R05) -----------

func _guest_eating_at_the_suppers_end(rig: Rig, day: int) -> int:
	"""Hold the feast on `day` and run its supper until a guest is eating the hotpot (not yet half through its bowl) after
	two others have eaten theirs;
	then move the calendar to the supper's end (19:00) with every bowl in hand still in hand, and run the frame in which
	the kitchen ends the serving. The guest."""
	assert_equal(rig.regatta.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	var key: int = Rules.feast_key(day)
	var guest: Array[int] = [-1]
	_run(rig, func() -> bool:
		guest[0] = _eating(rig.kitchen, key) if _ate_main(rig.kitchen) >= 2 else -1
		return guest[0] >= 0, 30000)
	assert_true(guest[0] >= 0, "a guest eating the hotpot (%s)" % rig.regatta.status_line())
	rig.calendar.tick = tick_at(day, MealRules.END_HOUR[Rules.FEAST_MEAL]) - 1
	rig.kitchen._credited.fill(rig.calendar.tick)
	_run(rig, func() -> bool: return false, 1)
	assert_true(rig.kitchen.final_pending(key), "the supper's serving ended with a bowl held")
	assert_true(rig.regatta.state != RegattaScript.ST_DONE, "no tally while a bowl is out")
	return guest[0]


static func _ate_main(kitchen: KitchenScript) -> int:
	"""How many residents have eaten the occasion's main course."""
	var n: int = 0
	for i: int in kitchen.fed.count():
		n += 1 if kitchen.occasion_courses(i) & KitchenScript.COURSE_MAIN != 0 else 0
	return n


static func _eating(kitchen: KitchenScript, key: int) -> int:
	"""A resident at work eating meal `key`, not yet half through its bowl (-1: none)."""
	for i: int in kitchen.fed.count():
		if kitchen.meal_of(i) == key and kitchen.step_of(i) == KitchenScript.WORK_EAT and kitchen._at_work[i] == 1 \
				and kitchen._mwu[i] * 2 <= MealRules.EAT_MWU:
			return i
	return -1


func test_a_guest_eating_at_the_suppers_end_shares_the_feast_once_its_bowl_is_eaten() -> void:
	"""BOUNDARY (R05): a guest still eating the hotpot when the supper's serving ends at 19:00 is counted -- the tally,
	the chronicle's number, the feast's company (its affinity) and the buff's coverage are taken from the kitchen's
	meal-finalized event, published only once that last bowl is eaten."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	var guest: int = _guest_eating_at_the_suppers_end(rig, day)
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_DONE, 3000), "tallied (%s)" % r.status_line())
	var final: KitchenScript.MealFinal = rig.kitchen.final_of(Rules.feast_key(day))
	assert_true(final != null and final.diners.has(guest), "the guest is a committed diner")
	assert_true(r.attendees.has(guest), "and shared the feast")
	assert_true(rig.posted.size() == 1 and rig.posted[0].contains("%d of %d shared" % [r.attendees.size(), r.eligible]),
		"the chronicle counts it")
	assert_equal(rig.shared.size(), 1, "the feast's company shared once")
	var company: PackedInt32Array = rig.shared[0] if not rig.shared.is_empty() else PackedInt32Array()
	assert_true(company.has(guest), "with the guest among it: %s" % company)


func test_a_guest_giving_its_bowl_back_after_the_suppers_end_is_not_counted() -> void:
	"""BOUNDARY (R05): a guest still eating at 19:00 is ordered away and gives its bowl back: the feast is tallied from
	the event published on that return, without the guest."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	var day: int = SUMMER_1 + 1
	var guest: int = _guest_eating_at_the_suppers_end(rig, day)
	r.brain_of(guest).order_move(r.brain_of(guest).position + Vector2(0.0, 1.0))
	assert_true(_run(rig, func() -> bool: return r.state == RegattaScript.ST_DONE, 3000), "tallied (%s)" % r.status_line())
	var final: KitchenScript.MealFinal = rig.kitchen.final_of(Rules.feast_key(day))
	assert_true(final != null and not final.diners.has(guest) and final.without >= 1, "the guest went without")
	assert_false(r.attendees.has(guest), "and did not share the feast")
	for company: PackedInt32Array in rig.shared:
		assert_false(company.has(guest), "nor its company")
	assert_equal(rig.kitchen.occasion_courses(guest), 0, "no course eaten")


static func _eating_second(kitchen: KitchenScript, key: int) -> int:
	"""A guest at work eating meal `key`'s SECOND course (its main eaten), not yet half through that bowl (-1: none)."""
	for i: int in kitchen.fed.count():
		if kitchen.meal_of(i) == key and kitchen.step_of(i) == KitchenScript.WORK_EAT and kitchen._at_work[i] == 1 \
				and kitchen.occasion_courses(i) == KitchenScript.COURSE_MAIN and kitchen._mwu[i] * 2 <= MealRules.EAT_MWU:
			return i
	return -1


func test_a_guest_giving_back_its_second_course_after_the_end_still_ate_the_feast() -> void:
	"""The R05 review's H1: a guest who ate the hotpot and holds its second course at 19:00, then gives that bowl back,
	ate the meal -- it is one of the committed diners and is not ALSO counted as gone without: every resident is counted
	exactly once (diners + raw + without), so the people's "for everyone" deed is not wrongly withheld."""
	var rig: Rig = _rig()
	var r: RegattaScript = rig.regatta
	_stock_feast(rig)
	_stock_menu(rig)
	var day: int = SUMMER_1 + 1
	assert_equal(r.hold(day, 2, true), "", "held")
	rig.calendar.tick = tick_at(day, Rules.CREW_CALL_HOUR) - 30
	rig.kitchen.update()
	var key: int = Rules.feast_key(day)
	var guest: Array[int] = [-1]
	_run(rig, func() -> bool:
		guest[0] = _eating_second(rig.kitchen, key)
		return guest[0] >= 0, 30000)
	assert_true(guest[0] >= 0, "a guest eating its second course (%s)" % r.status_line())
	rig.calendar.tick = tick_at(day, MealRules.END_HOUR[Rules.FEAST_MEAL]) - 1
	rig.kitchen._credited.fill(rig.calendar.tick)
	_run(rig, func() -> bool: return false, 1)
	assert_true(rig.kitchen.final_pending(key), "ended with the second bowl held")
	r.brain_of(guest[0]).order_move(r.brain_of(guest[0]).position + Vector2(0.0, 1.0))
	assert_true(_run(rig, func() -> bool: return rig.kitchen.final_of(key) != null, 3000), "finalized on the return")
	var final: KitchenScript.MealFinal = rig.kitchen.final_of(key)
	assert_true(final.diners.has(guest[0]), "the guest ate the meal (its hotpot)")
	assert_equal(final.diners.size() + final.raw.size() + final.without, rig.kitchen.fed.count(),
		"every resident counted once: %d diners, %d raw, %d without" % [final.diners.size(), final.raw.size(), final.without])
	var at: int = rig.kitchen.meal_keys.rfind(key)
	assert_equal(rig.kitchen.meal_ate[at] + rig.kitchen.meal_raw[at] + rig.kitchen.meal_without[at],
		rig.kitchen.fed.count(), "and so is the kitchen's own tally")
