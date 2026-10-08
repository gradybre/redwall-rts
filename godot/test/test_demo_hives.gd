extends "res://test/framework/test_case.gd"
## The apiary (decision 1601; review group Y's ECO-011 and ECO-012): its numbers against GDD §5.6/§5.8, the model's §5.6
## days through the real Hive store (production, missed service, winter feed, abandonment, recolonising, §5.8's wildlife),
## ECO-012's winter feed put by first, the books (every milli-U of honey and wax made is somewhere), REQ-SET-082's
## pollination for the orchard's trees and the field's beans, the words, the view, and whole keeper's jobs on real brains
## walking the real layout (as test_demo_orchard.gd). Expected numbers are restated from their sources.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const Rng := preload("res://scripts/core/rng.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
const HiveText := preload("res://demo/hives/hive_text.gd")
const ApiaryScript := preload("res://demo/hives/apiary_model.gd")
const ApiaryViewScript := preload("res://demo/hives/apiary_view.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const ModelScript := preload("res://demo/orchard/orchard_model.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const CardsScript := preload("res://demo/orchard/orchard_cards.gd")
const OrchardNode := preload("res://demo/orchard/demo_orchard.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const Book := preload("res://demo/kitchen/dish_book.gd")
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
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 8000
## Absolute days: spring 2, summer 1 (13), autumn 1 (25), winter 1 (37) and winter 4 (40) of year one.
const SPRING_DAY: int = 2
const SUMMER_DAY: int = 13
const WINTER_DAY: int = 37
const PEA: int = 11
## Field beds (farm_catalog.gd BED_IDS): the west cabbage bed (12.2 m off: out of reach), the west grain bed (in reach).
const BED_FAR: int = 0
const BED_NEAR: int = 4

## The keeper's rig: the placeholder cast on the village's water, a pantry with the kitchen's store and the stands, the
## orchard's model (its apiary) and board, the kitchen's takes for the free honey.
class Rig:
	var cast: DemoCastScript = null
	var pantry: PantryScript = null
	var takes: TakesScript = TakesScript.new()
	var calendar: CalendarScript = null
	var model: ModelScript = null
	var jobs: JobsScript = null
	var day_seen: int = 1

	func free_honey() -> int:
		"""The pantry's honey nobody has set aside."""
		return takes.free_milli_of_crop(pantry, Catalog.CAT_HONEY)

	func take_honey(milli: int) -> int:
		"""Withdraw up to `milli` of free honey."""
		return takes.withdraw_free(pantry, Catalog.CAT_HONEY, milli, calendar.hour_index())

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built; reduced motion back off."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()
	DemoMotion.reduced = false


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _rig(day: int) -> Rig:
	"""The keeper's rig at 06:00 of `day` (see Rig)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	circles.append_array(OrchardNode.land_obstacles())
	var links := WaterplayScript.make_links(_map_cache, circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var storage := StorageScript.new(DemoFarmScript.store_position(rig.cast))
	storage.add_provider(KitchenNode.pantry_provider())
	storage.add_provider(OrchardNode.stand_provider())
	rig.pantry = PantryScript.new(storage)
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = (day - 1) * SimClock.TICKS_PER_DAY
	rig.model = _model_on(day)
	rig.day_seen = day
	rig.jobs = JobsScript.new()
	rig.jobs.configure(rig.model, rig.cast, rig.pantry, _services.stores, rig.calendar, null)
	rig.jobs.set_honey(rig.free_honey, rig.take_honey)
	return rig


func _model_on(day: int) -> ModelScript:
	"""The orchard (and its apiary) with its days closed up to `day` (the hive serviced each working day before it)."""
	var model := ModelScript.new()
	for d: int in range(1, day):
		model.apiary.service(0, d)
		model.close_day(d, 120)
	model.today_hint = day
	return model


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast, the calendar (its midnights closing the days) and the board -- handing each waiting job to the first
	idle resident who may take it -- until `done()`."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		var day: int = rig.calendar.now().absolute_day
		while rig.day_seen < day:
			rig.model.close_day(rig.day_seen, 120)
			rig.day_seen += 1
		rig.jobs.update(usec)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part: each waiting job to the first idle resident who may take it."""
	for j: int in JobsScript.MAX_JOBS:
		if not rig.jobs.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = rig.jobs.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and rig.jobs.eligibility(j, who).is_empty() and rig.jobs.claim(j, who):
				break


func _location(rig: Rig, id: StringName) -> int:
	"""A store's pantry location by its id."""
	assert_true(rig.pantry.storage.index_of_id_into(id, _read), "%s is a store" % id)
	return _read.value


func _set_hive(apiary: ApiaryScript, strength: int, feed: int, honey: int, wax: int) -> void:
	"""Put the hive's state at the given values (its serviced day kept), through the store's state writer."""
	var slot: int = apiary.slot_of(0)
	assert_true(apiary.store.restore_hive_state(apiary.hive_ref[0], strength, feed, honey, wax,
		apiary.store.hive_serviced_day_of(slot).value).ok, "the hive's state written")


func _books_balance(apiary: ApiaryScript, label: String) -> void:
	"""THE BOOKS: honey made, feed put by and wax made are each all accounted for."""
	assert_equal(apiary.honey_accounted_milli(), apiary.honey_made_milli, "%s: honey" % label)
	assert_equal(apiary.feed_accounted_milli(), apiary.fed_from_hive_milli + apiary.fed_from_pantry_milli,
		"%s: feed" % label)
	assert_equal(apiary.wax_accounted_milli(), apiary.wax_made_milli, "%s: wax" % label)


# --- the numbers -----------------------------------------------------------------------------------------------------------

func test_the_numbers_are_the_documents() -> void:
	"""§5.6's hive rows through orchard_hive.gd, §5.8's wildlife roll, and the demo's winter feed (12 days x 0.5 U)."""
	assert_equal(HiveRules.SERVICE_MWU, 20000, "§5.6: service 20 WU a day")
	assert_equal(HiveRules.RECOLONIZE_MWU, 60000, "§5.6: recolonising 60 WU")
	assert_equal([HiveRules.RECOLONIZE_HONEY_MILLI, HiveRules.RECOLONIZE_WOOD_MILLI, HiveRules.RECOLONIZE_WAIT_DAYS],
		[4000, 2000, 3], "§5.6: honey 4, wood 2, a 3-day wait")
	assert_equal(HiveRules.WINTER_FEED_MILLI, 6000, "a winter's feed: 12 days x 0.5 U")
	assert_equal([HiveRules.WILDLIFE_CHANCE, HiveRules.WILDLIFE_CHANCE_FENCED, HiveRules.WILDLIFE_DENOMINATOR], [200, 100,
		10000], "§5.8: 200/10000, halved by a fence")
	assert_equal(HiveRules.WILDLIFE_TAKE_MILLI, 2000, "§5.8: min(2 U, the honey)")
	assert_equal(HiveRules.FEED_MWU, MealRules.HANDLE_MWU, "a feeding is a handling's 1 WU")
	assert_equal(Hive.POLLINATION_FACTOR_ONE_HIVE, 1100, "REQ-SET-082: one hive")


func test_where_the_apiary_stands() -> void:
	"""Tiles 57..59 x 73..75: the skep at (-11, 21), its keeper 1.1 m south of it; a ground point's tile is farm_sim.gd's."""
	assert_true(HiveRules.is_apiary(0) and not HiveRules.is_apiary(HiveRules.APIARY_COUNT) and not HiveRules.is_apiary(-1),
		"one apiary")
	assert_equal(HiveRules.centre_m(0), Vector2(-11.0, 21.0), "its centre")
	assert_equal(HiveRules.keeper_spot(0), Vector2(-11.0, 19.9), "its keeper's spot")
	assert_equal(HiveRules.tile_of_m(Vector2(-12.6, 16.4)), Vector2i(57, 72), "64 + floor(x / 2)")
	assert_equal(HiveRules.tile_of_m(Vector2(0.0, -0.1)), Vector2i(64, 63), "the floor below zero")
	assert_equal(HiveRules.units(6000), "6.0 U", "its units")


func test_the_seasons_rules() -> void:
	"""§5.8's roll only in summer and autumn; the winter feed's need counts down through winter; a recolonisation's wait
	must end in spring."""
	assert_false(HiveRules.is_wildlife_season(Hive.SEASON_SPRING) or HiveRules.is_wildlife_season(Hive.SEASON_WINTER),
		"not spring or winter")
	assert_true(HiveRules.is_wildlife_season(Hive.SEASON_SUMMER) and HiveRules.is_wildlife_season(Hive.SEASON_AUTUMN),
		"summer and autumn")
	assert_equal(HiveRules.wildlife_chance(0), 200, "no fence")
	assert_equal(HiveRules.winter_days_left(SUMMER_DAY), 12, "a whole winter ahead")
	assert_equal(HiveRules.winter_days_left(WINTER_DAY), 12, "winter's first day: all of it")
	assert_equal(HiveRules.winter_days_left(WINTER_DAY + 11), 1, "its last day")
	assert_equal(HiveRules.feed_need_milli(WINTER_DAY + 3), 4500, "winter 4: nine days' feed")
	assert_true(HiveRules.recolonize_ends_in_spring(1) and HiveRules.recolonize_ends_in_spring(9), "spring 1 and 9")
	assert_false(HiveRules.recolonize_ends_in_spring(10), "spring 10: it would end in summer")
	assert_false(HiveRules.recolonize_ends_in_spring(SUMMER_DAY), "not in summer")


# --- the hive's days -------------------------------------------------------------------------------------------------------

func test_a_tended_hive_makes_honey_and_wax_by_the_formula() -> void:
	"""§5.6: serviced spring days make honey 2 U and wax 0.25 U x strength/10000, then restore 300."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	assert_equal(apiary.strength(0), 8000, "§5.6: starts 8000")
	var strength: int = 8000
	var honey: int = 0
	var wax: int = 0
	for day: int in range(1, 6):
		assert_true(apiary.service(0, day), "serviced on day %d" % day)
		model.close_day(day, 120)
		@warning_ignore("integer_division") var day_honey: int = 2000 * strength / 10000
		@warning_ignore("integer_division") var day_wax: int = 250 * strength / 10000
		honey += day_honey
		wax += day_wax
		strength += 300
	assert_equal(apiary.honey_in_hive(0), honey, "honey 2 U x strength/10000 a day")
	assert_equal(apiary.wax_in_hive(0), wax, "wax 0.25 U x strength/10000 a day")
	assert_equal(apiary.strength(0), strength, "+300 a tended spring day")
	assert_equal(apiary.honey_made_milli, honey, "booked")
	_books_balance(apiary, "after five days")


func test_a_missed_day_costs_strength_and_makes_nothing() -> void:
	"""§5.6: an unserviced working day removes 200 and produces no honey or wax; REQ-SET-083 shows the deficit."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	model.close_day(2, 120)
	assert_equal(apiary.strength(0), 7800, "-200")
	assert_equal(apiary.honey_in_hive(0), 0, "nothing made")
	assert_equal(apiary.missed_days, 1, "counted")
	assert_true(apiary.service_due(0, 3), "owed on day 3")
	assert_equal(apiary.service_deficit_days(0, 3), 2, "two days since day 1's")
	assert_true(HiveText.deficit_line(apiary, 0, 3).contains("not tended for 2 days"), "shown before abandonment")


func test_winter_eats_the_feed_or_costs_strength() -> void:
	"""§5.6: winter makes nothing, needs no tending, and eats 0.5 U a day from the feed; a day without it costs 500."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	_set_hive(apiary, 8000, 1000, 0, 0)
	assert_false(apiary.service_due(0, WINTER_DAY), "no tending in winter")
	model.close_day(WINTER_DAY, 0)
	model.close_day(WINTER_DAY + 1, 0)
	assert_equal([apiary.feed(0), apiary.strength(0), apiary.eaten_milli], [0, 8000, 1000], "two days fed")
	model.close_day(WINTER_DAY + 2, 0)
	assert_equal(apiary.strength(0), 7500, "an unfed day: -500")
	assert_equal(apiary.feed_shortfall_milli(0, WINTER_DAY + 3), 4500, "nine days' feed short")
	assert_equal(apiary.feed_shortfall_milli(0, SUMMER_DAY), 0, "nothing owed outside winter")
	assert_true(HiveText.deficit_line(apiary, 0, WINTER_DAY + 3).contains("winter feed short by 4.5 U"), "shown")


func test_the_winter_feed_is_put_by_first() -> void:
	"""ECO-012: a collection tops the hive's feed up to the coming winter's 6 U before any honey is released; only the
	rest goes to the baskets, up to the room held; the wax goes to the shelf."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	_set_hive(apiary, 8000, 0, 4000, 300)
	assert_equal(apiary.releasable_milli(0, SUMMER_DAY), 0, "nothing to release while the feed is short")
	assert_equal(apiary.collect(0, SUMMER_DAY, 10000), 0, "all of it put by")
	assert_equal([apiary.feed(0), apiary.honey_in_hive(0), apiary.wax_shelf_milli], [4000, 0, 300], "fed, shelved")
	_set_hive(apiary, 8000, 4000, 5000, 0)
	assert_equal(apiary.releasable_milli(0, SUMMER_DAY), 3000, "2 U still to put by")
	assert_equal(apiary.collect(0, SUMMER_DAY, 1000), 1000, "released up to the room held")
	assert_equal([apiary.feed(0), apiary.honey_in_hive(0)], [6000, 2000], "fed to 6 U; the rest left in the hive")
	assert_equal(apiary.fed_from_hive_milli, 6000, "booked")
	assert_equal(apiary.released_milli, 1000, "booked")


func test_the_wax_shelf_has_a_limit() -> void:
	"""The apiary's shelf holds WAX_SHELF_U; wax beyond it stays in the hive; `take_wax` takes what is there."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	var shelf: int = HiveRules.WAX_SHELF_U * 1000
	_set_hive(apiary, 8000, 6000, 0, shelf + 700)
	apiary.collect(0, SUMMER_DAY, 0)
	assert_equal([apiary.wax_shelf_milli, apiary.wax_in_hive(0)], [shelf, 700], "full shelf; the rest in the hive")
	assert_equal(apiary.take_wax(1500), 1500, "taken")
	assert_equal(apiary.take_wax(shelf * 2), shelf - 1500, "no more than there is")
	assert_equal(apiary.take_wax(-5), 0, "nothing for a bad quantity")


func test_abandonment_and_recolonising() -> void:
	"""§5.6: at 0 strength the hive is abandoned; it is recolonised in spring after the 3-day wait, back at 8000."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	_set_hive(apiary, 400, 0, 0, 0)
	model.close_day(3, 120)
	model.close_day(4, 120)
	assert_true(apiary.is_abandoned(0), "abandoned")
	assert_true(apiary.news.is_empty() or apiary.news_warning[0] == 1, "the news is a warning")
	assert_equal(apiary.recolonize_refusal(0, SUMMER_DAY), ApiaryScript.REFUSE_NOT_SPRING, "not in summer")
	assert_equal(apiary.recolonize_refusal(0, 10), ApiaryScript.REFUSE_NOT_SPRING, "not with the wait ending in summer")
	assert_true(apiary.start_recolonize(0, 5), "started on spring 5")
	assert_equal(apiary.recolonize_refusal(0, 5), ApiaryScript.REFUSE_UNDER_WAY, "under way")
	model.close_day(5, 120)
	model.close_day(6, 120)
	assert_true(apiary.is_abandoned(0), "still waiting")
	model.close_day(7, 120)
	assert_equal(apiary.strength(0), 8000, "a swarm settled on day 8")
	assert_equal(apiary.recolonize_day[0], 0, "the wait is over")
	assert_equal(apiary.news[apiary.news.size() - 1], "A swarm has settled in the apiary: the hive is alive again", "said")
	assert_equal(apiary.recolonize_refusal(0, 9), ApiaryScript.REFUSE_NOT_ABANDONED, "alive again")
	assert_false(apiary.start_recolonize(0, 9), "nothing to start")


func test_the_abandonment_is_news_once() -> void:
	"""The midnight a hive reaches 0 says so, as a warning; the next says nothing more."""
	var model := ModelScript.new()
	_set_hive(model.apiary, 200, 0, 0, 0)
	model.close_day(3, 120)
	assert_equal(model.apiary.news.size(), 1, "one line")
	assert_true(model.apiary.news[0].begins_with("The bees have left the apiary"), model.apiary.news[0])
	assert_equal(model.apiary.news_warning[0], 1, "a warning")
	model.close_day(4, 120)
	assert_true(model.apiary.news.is_empty(), "said once")


func test_wildlife_takes_honey_in_summer_and_autumn() -> void:
	"""§5.8: on the midnight roll's hit in summer or autumn, min(2 U, the honey) is taken; never in spring."""
	var hit: int = _first_hit_day(SUMMER_DAY, 24)
	assert_true(hit > 0, "the seeded roll hits some summer or autumn day")
	var model := ModelScript.new()
	_set_hive(model.apiary, 8000, 6000, 3500, 0)
	model.close_day(hit, 120)
	assert_equal(model.apiary.lost_milli, 2000, "2 U taken")
	assert_equal(model.apiary.wildlife_visits, 1, "one visit")
	assert_true(model.apiary.news[model.apiary.news.size() - 1].contains("2.0 U of honey gone"), "advised")
	_set_hive(model.apiary, 8000, 6000, 500, 0)
	model.close_day(_first_hit_day(hit + 1, 100), 120)
	assert_equal(model.apiary.lost_milli, 2500, "min(2 U, 0.5 U)")
	var empty := ModelScript.new()
	_set_hive(empty.apiary, 8000, 6000, 0, 0)
	empty.close_day(hit, 120)
	assert_equal(empty.apiary.news[empty.apiary.news.size() - 1], "Something got into the apiary in the night, but found no honey",
		"advised even with nothing to take")
	var spring := ModelScript.new()
	_set_hive(spring.apiary, 8000, 6000, 3500, 0)
	for day: int in range(1, SUMMER_DAY):
		spring.close_day(day, 120)
	assert_equal(spring.apiary.wildlife_visits, 0, "no roll in spring")


func _first_hit_day(from: int, span: int) -> int:
	"""The first summer or autumn day from `from` on whose seeded roll hits (0: none within `span` days)."""
	for day: int in range(from, from + span):
		var season: int = Hive.season_of_day(day)
		var roll: int = Rng.hash_pair(day, HiveRules.WILDLIFE_SEED) % HiveRules.WILDLIFE_DENOMINATOR
		if HiveRules.is_wildlife_season(season) and roll < HiveRules.WILDLIFE_CHANCE:
			return day
	return 0


func test_a_year_of_tending_keeps_the_books() -> void:
	"""A year with a collection most days (and none some): every milli-U of honey, feed and wax accounted for."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	for day: int in range(1, SimClock.DAYS_PER_YEAR + 1):
		if day % 5 != 0 and apiary.service_due(0, day):
			apiary.service(0, day)
			apiary.collect(0, day, 1500)
		model.close_day(day, 120)
	assert_true(apiary.honey_made_milli > 0 and apiary.released_milli > 0, "honey made and released")
	assert_true(apiary.eaten_milli > 0, "winter fed from the hive's own honey")
	_books_balance(apiary, "after a year")


# --- pollination (REQ-SET-082, ECO-011) ------------------------------------------------------------------------------------

func test_the_apiary_pollinates_the_old_trees_and_not_the_east_sites() -> void:
	"""The old apple (10.3 m) and pear (9.5 m) are within 12 m: x1100; a tree on an east site is not; a weak hive gives
	nothing; a second hive in reach gives x1150 (REQ-SET-082's bound)."""
	var model := ModelScript.new()
	for site: int in [0, 1]:
		assert_true(model.store.orchard_pollination_factor_into(model.slot_of(site), _read), "read")
		assert_equal(_read.value, 1100, "%s pollinated" % Rules.SITE_NAMES[site])
	assert_true(model.take_sapling(2, Rules.APPLE, false) and model.plant(2, Rules.APPLE, 1), "an east apple")
	assert_true(model.store.orchard_pollination_factor_into(model.slot_of(2), _read) and _read.value == 1000, "out of reach")
	_set_hive(model.apiary, 4999, 0, 0, 0)
	assert_true(model.store.orchard_pollination_factor_into(model.slot_of(0), _read) and _read.value == 1000, "weak")
	_set_hive(model.apiary, 8000, 0, 0, 0)
	var building: Vector2i = model.store.directory().create(0)
	assert_true(model.store.create_hive(building, 55, 77, 57, 79, 1).ok, "a second hive in reach")
	assert_true(model.store.orchard_pollination_factor_into(model.slot_of(0), _read) and _read.value == 1150, "two")
	var old: Vector2i = Rules.SITE_ORIGIN[1]
	var east: Vector2i = Rules.SITE_ORIGIN[2]
	assert_true(model.apiary.reaches(0, old, old + Vector2i(3, 3)) and not model.apiary.reaches(0, east, east + Vector2i(3, 3)),
		"the readout's reach agrees with the store's")


func test_beans_in_reach_are_pollinated_and_nothing_else() -> void:
	"""REQ-SET-082 through farm_sim.gd's join: peas (the beans row, sown in §5.6's Spring 5-10 window) in the west grain
	bed (in reach) x1100; in the west cabbage bed (12.2 m) 1000; a bed of another crop and an empty bed 1000; without the apiary 1000."""
	var sim := SimScript.new()
	var model := ModelScript.new()
	sim.pollinate = model.apiary.bed_factor
	sim.advance_usec(4 * 24 * CalendarScript.HOUR_USEC)
	for bed: int in [BED_NEAR, BED_FAR]:
		sim.choose(bed, PEA)
		assert_true(sim.sow_start(bed).ok and sim.sow_finish(bed).ok, "peas sown in bed %d" % bed)
	assert_equal(sim.pollination_of(BED_NEAR), 1100, "in reach")
	assert_equal(sim.pollination_of(BED_FAR), 1000, "out of reach")
	assert_equal(sim.pollination_of(5), 1000, "the wheat bed: not a pollinated crop")
	assert_equal(sim.pollination_of(1), 1000, "an empty bed")
	assert_equal(sim.pollination_of(-1), 1000, "no bed")
	assert_true(sim.expected_yield_into(BED_NEAR, _read), "its estimate")
	var pollinated: int = _read.value
	sim.pollinate = Callable()
	assert_true(sim.expected_yield_into(BED_NEAR, _read), "without the apiary")
	@warning_ignore("integer_division") var lifted: int = _read.value * 1100 / 1000
	assert_true(absi(pollinated - lifted) <= 1, "x1.10 (%d vs %d)" % [pollinated, _read.value])


func test_the_readout_says_which_crops_benefit() -> void:
	"""ECO-011: the apiary's readout names the old trees and the four northern field beds, and its state and stock."""
	var model := ModelScript.new()
	var cards := CardsScript.new()
	cards.configure(model, JobsScript.new(), null)
	var text: String = cards.text(CardsScript.SEL_APIARY, 0)
	assert_true(text.contains("the old apple") and text.contains("the old pear"), text)
	assert_true(text.contains("beans in bed 3, bed 4, bed 5, bed 6"), text)
	assert_true(text.contains("Strength 80%"), text)
	assert_true(text.contains("winter feed 0.0 U of 6.0 U"), text)
	assert_equal(cards.title(CardsScript.SEL_APIARY, 0), "The apiary", "its title")
	assert_equal(cards.shown_actions(CardsScript.SEL_APIARY, 0), [&"service", &"feed", &"recolonize"], "its verbs")
	assert_equal(cards.job_of(&"service", CardsScript.SEL_APIARY, 0), Vector3i(Rules.K_SERVICE, 0, -1), "its job")


# --- the words --------------------------------------------------------------------------------------------------------------

func test_the_refusals_in_words() -> void:
	"""hive_text.gd: the service, the feeding and the recolonisation say exactly why not."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	assert_equal(HiveText.service_refusal(apiary, 0, 1), HiveText.TENDED_TODAY, "founding day counts as tended")
	assert_equal(HiveText.service_refusal(apiary, 0, 2), "", "owed on day 2")
	assert_true(HiveText.service_refusal(apiary, 0, WINTER_DAY).begins_with("winter:"), "winter")
	assert_true(HiveText.feed_refusal(apiary, 0, SUMMER_DAY, 9000).begins_with("the hive puts by"), "not in summer")
	assert_equal(HiveText.feed_refusal(apiary, 0, WINTER_DAY, 0), HiveText.NO_FREE_HONEY % "6.0 U", "no free honey")
	assert_equal(HiveText.feed_refusal(apiary, 0, WINTER_DAY, 500), "", "owed, and honey to give")
	_set_hive(apiary, 8000, 6000, 0, 0)
	assert_true(HiveText.feed_refusal(apiary, 0, WINTER_DAY, 500).begins_with("its feed lasts"), "fed")
	assert_equal(HiveText.recolonize_refusal(apiary, 0, 2, 9000, 9000), HiveText.NOT_ABANDONED, "alive")
	_set_hive(apiary, 0, 0, 0, 0)
	assert_equal(HiveText.service_refusal(apiary, 0, 2), HiveText.ABANDONED, "abandoned")
	assert_equal(HiveText.feed_refusal(apiary, 0, WINTER_DAY, 500), HiveText.ABANDONED, "no feeding an empty hive")
	assert_true(HiveText.recolonize_refusal(apiary, 0, 2, 3999, 9000).begins_with("it needs 4.0 U of free honey"),
		"short of honey")
	assert_true(HiveText.recolonize_refusal(apiary, 0, 2, 4000, 1999).begins_with("it needs 2.0 U of wood"), "short of wood")
	assert_equal(HiveText.recolonize_refusal(apiary, 0, 2, 4000, 2000), "", "it can")
	assert_equal(HiveText.recolonize_refusal(apiary, 0, SUMMER_DAY, 4000, 2000), HiveText.NOT_SPRING, "not in summer")


func test_the_readout_lines() -> void:
	"""The state, deficit, stock and pollination lines; the recolonisation codes in words."""
	var model := ModelScript.new()
	var apiary: ApiaryScript = model.apiary
	assert_true(HiveText.state_line(apiary, 0, 2).begins_with("Strength 80% · healthy"), "healthy")
	assert_equal(HiveText.deficit_line(apiary, 0, 1), "Deficits: none.", "none")
	_set_hive(apiary, 4000, 0, 0, 0)
	assert_true(HiveText.state_line(apiary, 0, 2).contains("weak"), "weak")
	_set_hive(apiary, 0, 0, 0, 0)
	assert_equal(HiveText.state_line(apiary, 0, 2), "Abandoned · recolonise it in spring", "abandoned")
	assert_equal(HiveText.deficit_line(apiary, 0, 2), "No deficits: the hive is empty.", "empty")
	assert_true(apiary.start_recolonize(0, 2), "started")
	assert_equal(HiveText.state_line(apiary, 0, 2), "Abandoned · a swarm settles on day 5", "the wait")
	assert_equal(HiveText.stock_line(apiary, 0), "In the hive: honey 0.0 U, wax 0.0 U · winter feed 0.0 U of 6.0 U · wax on the shelf 0.0 U", "stock")
	assert_equal(HiveText.pollination_line(PackedStringArray(), PackedStringArray(), false),
		"Pollinates within 12 m (x1.10 yield): no orchard tree; beans in no field bed. Not while it is weak.", "none")
	assert_equal(HiveText.recolonize_words(ApiaryScript.REFUSE_UNDER_WAY), HiveText.UNDER_WAY, "under way")
	assert_equal(HiveText.recolonize_words(""), "", "nothing")


func test_honey_has_its_source_and_its_guide_entry() -> void:
	"""Decision 1601: honey leaves the dish book's pending sources (the cordial is cookable) and the field guide says
	where it comes from."""
	assert_false(Book.PENDING_SOURCES.has(&"honey"), "honey has a source")
	assert_false(MealRules.waits(MealRules.DISH_CORDIAL), "the raspberry cordial can be made")
	var fields: PackedStringArray = HiveText.guide_fields("Cooked in: a cordial.", 1200, 1440)
	assert_equal(fields.size(), 4, "the guide's four fields")
	assert_true(fields[1].contains("6.0 U") and fields[3].contains("1440"), "the winter feed and the shelf")
	var guide := FieldGuideScript.new()
	var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(Catalog.ITEM_HONEY)))
	assert_equal(entry.summary, HiveText.GUIDE_SUMMARY, "the guide's honey")


# --- the view ---------------------------------------------------------------------------------------------------------------

func test_the_bees_fly_in_season_and_rest_in_winter() -> void:
	"""bee_swarm.gd wired (art_pass3_mapping.md): one swarm over the skep, out spring to autumn, hidden in winter and
	while the hive is abandoned; reduced motion followed."""
	var model := ModelScript.new()
	var calendar := CalendarScript.new()
	var clock := DemoClockScript.new()
	var view: ApiaryViewScript = _keep(ApiaryViewScript.new()) as ApiaryViewScript
	view.configure(model.apiary, Callable(), calendar, clock)
	assert_equal(view.swarms.size(), 1, "a swarm")
	assert_true(view.swarms[0].visible, "out in spring")
	assert_equal(view.swarms[0].position, Vector3(-11.0, 0.0, 21.0), "over the skep")
	calendar.tick = (WINTER_DAY - 1) * SimClock.TICKS_PER_DAY
	view.follow()
	assert_false(view.swarms[0].visible, "resting in winter")
	calendar.tick = (SUMMER_DAY - 1) * SimClock.TICKS_PER_DAY
	_set_hive(model.apiary, 0, 0, 0, 0)
	view.follow()
	assert_false(view.swarms[0].visible, "an empty skep")
	DemoMotion.reduced = true
	clock.speed = 4
	view.follow()
	assert_true(bool(view.swarms[0].get("_reduced")), "reduced motion forwarded")
	assert_equal(float(view.swarms[0].get("_speed")), 4.0, "the clock's speed forwarded")


# --- the keeper's jobs on real brains --------------------------------------------------------------------------------------------

func test_the_routine_tends_the_bees_and_puts_the_feed_by() -> void:
	"""Spring 2: the routine raises the service (owed: day 1 was the founding day); a resident walks to the skep, works
	its 20 WU; the honey day 1 made goes into the winter feed, nothing to carry; tomorrow's service is not owed today."""
	var rig := _rig(SPRING_DAY)
	var made: int = rig.model.apiary.honey_in_hive(0)
	assert_true(made > 0, "day 1's honey")
	rig.jobs.plan_work()
	var j: int = rig.jobs.find(JobsScript.K_SERVICE, 0)
	assert_true(j >= 0, "the service raised")
	assert_true(_run(rig, func() -> bool: return not rig.model.apiary.service_due(0, SPRING_DAY)), "tended")
	assert_equal(rig.model.apiary.feed(0), made, "all of it put by for the winter")
	assert_true(_run(rig, func() -> bool: return rig.jobs.find(JobsScript.K_SERVICE, 0) < 0, 600), "the job ends")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HONEY), 0, "nothing carried")
	_books_balance(rig.model.apiary, "after the service")


func test_honey_past_the_feed_is_carried_to_the_baskets() -> void:
	"""With the winter's feed put by, the service's honey is carried to the old orchard's baskets (room held first)."""
	var rig := _rig(SUMMER_DAY)
	_set_hive(rig.model.apiary, 8000, 6000, 3000, 250)
	var stand: int = _location(rig, Rules.STAND_IDS[0])
	rig.jobs.plan_work()
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_at(Catalog.ITEM_HONEY, stand) > 0), "carried")
	assert_equal(rig.pantry.milli_at(Catalog.ITEM_HONEY, stand), 3000, "all of it, at the baskets")
	assert_equal(rig.model.apiary.wax_shelf_milli, 250, "the wax shelved")
	assert_equal(rig.model.apiary.released_milli, 3000, "booked as released")
	assert_true(_run(rig, func() -> bool: return rig.jobs.find(JobsScript.K_SERVICE, 0) < 0, 600), "ended")
	for at: int in rig.pantry.storage.count():
		assert_equal(rig.pantry.reserved_milli_of(at), _held_by_live_jobs(rig, at), "no room left held at store %d" % at)


func _held_by_live_jobs(rig: Rig, at: int) -> int:
	"""Room the orchard's other live jobs (a berry picking the routine raised meanwhile) still hold at store `at`."""
	var held: int = 0
	for j: int in JobsScript.MAX_JOBS:
		var hold: int = rig.jobs.hold[j]
		if rig.jobs.is_live(j) and rig.pantry.is_hold(hold) and rig.pantry.hold_location_into(hold, _read) \
				and _read.value == at:
			held += rig.pantry.hold_milli(hold)
	return held


func test_a_winter_feeding_draws_the_pantrys_honey() -> void:
	"""REQ-SET-083 made actionable: in winter, a hive short of feed is fed the shortfall drawn from the pantry's free
	honey (the keeper walks to the skep; the honey leaves its store when the feeding is done)."""
	var rig := _rig(WINTER_DAY + 3)
	_set_hive(rig.model.apiary, 8000, 0, 0, 0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_HONEY, 10000, _location(rig, KitchenNode.PANTRY_ID), _read), "honey")
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_FEED, 0) >= 0, "a feeding raised")
	assert_true(rig.jobs.find(JobsScript.K_SERVICE, 0) < 0, "no tending in winter")
	assert_true(_run(rig, func() -> bool: return rig.model.apiary.feed(0) > 0), "fed")
	assert_equal(rig.model.apiary.feed(0), 4500, "nine days' feed")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HONEY), 5500, "taken from the pantry")
	assert_equal(rig.model.apiary.fed_from_pantry_milli, 4500, "booked")


func test_a_recolonisation_pays_its_honey_and_wood_and_waits() -> void:
	"""§5.6: an abandoned hive in spring, honey 4 U and wood 2 U to hand: the routine raises it; after its 60 WU both are
	taken; three days later the hive is back at 8000."""
	var rig := _rig(SPRING_DAY)
	_set_hive(rig.model.apiary, 0, 0, 0, 0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_HONEY, 5000, _location(rig, KitchenNode.PANTRY_ID), _read), "honey")
	var wood: int = _services.stores.wood_milli_u
	rig.jobs.plan_work()
	assert_true(rig.jobs.find(JobsScript.K_RECOLONIZE, 0) >= 0, "raised")
	assert_true(_run(rig, func() -> bool: return rig.model.apiary.recolonize_day[0] != 0), "the work done")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HONEY), 1000, "honey 4 U taken")
	assert_equal(_services.stores.wood_milli_u, wood - 2000, "wood 2 U taken")
	var back: int = rig.model.apiary.recolonize_day[0]
	for day: int in range(rig.day_seen, back):
		rig.model.close_day(day, 120)
	assert_equal(rig.model.apiary.strength(0), 8000, "a swarm settled")


func test_the_player_orders_the_keepers_work() -> void:
	"""`order` checks as the work does: a service owed is taken; one not owed, a feeding outside winter and a
	recolonisation of a live hive are refused in words."""
	var rig := _rig(SPRING_DAY)
	assert_equal(rig.jobs.order_refusal(JobsScript.K_FEED, 0, -1).begins_with("the hive puts by"), true, "no feeding")
	assert_equal(rig.jobs.order_refusal(JobsScript.K_RECOLONIZE, 0, -1), HiveText.NOT_ABANDONED, "alive")
	assert_equal(rig.jobs.order(JobsScript.K_SERVICE, 0, -1, PackedInt32Array([0])), "", "ordered")
	var j: int = rig.jobs.find(JobsScript.K_SERVICE, 0)
	assert_equal(rig.jobs.worker[j], 0, "to the selected resident")
	assert_equal(rig.jobs.place_of(j, JobsScript.S_GO), HiveRules.keeper_spot(0), "at the skep")
	assert_true(rig.jobs.doing_text(j, rig.jobs.serial[j]).contains("Tend the bees — the apiary"), "its words")


func test_the_wildlife_roll_is_the_day_just_ended() -> void:
	"""§5.8's roll is made for the day just ended, only when it was a summer or autumn day: spring's last day and winter's
	first never roll; summer's first and autumn's last roll on the seeded draw."""
	var apiary: ApiaryScript = ModelScript.new().apiary
	assert_false(apiary.wildlife_strikes(0, SUMMER_DAY - 1), "spring's last day")
	assert_false(apiary.wildlife_strikes(0, WINTER_DAY), "winter's first day")
	for day: int in [SUMMER_DAY, WINTER_DAY - 1, 19]:
		var hits: bool = Rng.hash_pair(day, HiveRules.WILDLIFE_SEED) % HiveRules.WILDLIFE_DENOMINATOR < HiveRules.WILDLIFE_CHANCE
		assert_equal(apiary.wildlife_strikes(0, day), hits, "day %d rolls" % day)
	assert_true(apiary.wildlife_strikes(0, 19), "the seeded summer hit")
	assert_false(apiary.wildlife_strikes(0, 1980), "a spring's last day, its draw a hit, does not roll")
	assert_true(apiary.wildlife_strikes(0, 2868), "an autumn's last day, its draw a hit, rolls")


func test_missed_days_count_only_live_working_days() -> void:
	"""A winter day needs no tending and an abandoned hive is past it: neither counts as a missed service."""
	var model := ModelScript.new()
	_set_hive(model.apiary, 8000, 6000, 0, 0)
	model.close_day(WINTER_DAY, 0)
	assert_equal(model.apiary.missed_days, 0, "no tending in winter")
	_set_hive(model.apiary, 0, 0, 0, 0)
	model.close_day(SUMMER_DAY, 120)
	assert_equal(model.apiary.missed_days, 0, "an empty hive owes no service")


func test_honey_is_taken_all_or_none() -> void:
	"""demo_orchard.gd `take_all_or_none`: short of the whole amount, nothing leaves the pantry (a recolonisation's 4 U
	never half-paid); with enough, exactly that much."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var takes := TakesScript.new()
	assert_true(pantry.add_into(Catalog.ITEM_HONEY, 1500, 0, _read) and pantry.add_into(Catalog.ITEM_HONEY, 2000, 0, _read), "two lots")
	assert_equal(OrchardNode.take_all_or_none(takes, pantry, Catalog.CAT_HONEY, 4000, 0), 0, "3.5 U is short of 4")
	assert_equal(pantry.milli_of(Catalog.ITEM_HONEY), 3500, "nothing taken")
	assert_equal(takes.free_milli_of_crop(pantry, Catalog.CAT_HONEY), 3500, "nothing left reserved")
	assert_equal(OrchardNode.take_all_or_none(takes, pantry, Catalog.CAT_HONEY, 3000, 0), 3000, "3 U taken")
	assert_equal(pantry.milli_of(Catalog.ITEM_HONEY), 500, "from both lots")


func test_bind_farm_wires_the_beans_and_the_honey() -> void:
	"""demo_orchard.gd `bind_farm`, as demo_village.gd calls it: the field's pollination join, and the keeper's honey
	through the kitchen's takes (food the kitchen has set aside is not free)."""
	var node: OrchardNode = _keep(OrchardNode.new()) as OrchardNode
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var takes := TakesScript.new()
	node.set("_pantry", pantry)
	node.set("_services", _services)
	var sim := SimScript.new()
	node.bind_farm(sim, takes)
	assert_true(sim.pollinate.is_valid(), "the beans' join")
	pantry.add_into(Catalog.ITEM_HONEY, 5000, 0, _read)
	takes.reserve_into(pantry, takes.new_take(), Catalog.CAT_HONEY, 2000, 0, _read)
	assert_equal(node.free_honey(), 3000, "the kitchen's 2 U are not free")
	assert_equal(node.jobs.hive_honey_free(), 3000, "the keeper reads the same")
	assert_equal(node.take_honey(4000), 0, "all or none")
	assert_equal(node.take_honey(3000), 3000, "taken")
	assert_equal(pantry.milli_of(Catalog.ITEM_HONEY), 2000, "the kitchen's left")


func test_the_skep_stands_clear_of_the_village() -> void:
	"""The skep's circle overlaps no building, fence, stump or bush of the world, nor the herb bank."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	for apiary: int in HiveRules.APIARY_COUNT:
		var at: Vector2 = HiveRules.centre_m(apiary)
		for theirs: Vector3 in world.obstacles():
			var gap: float = at.distance_to(Vector2(theirs.x, theirs.z))
			assert_true(gap >= HiveRules.SKEP_RADIUS_M + theirs.y, "clear of (%.1f, %.1f)" % [theirs.x, theirs.z])
