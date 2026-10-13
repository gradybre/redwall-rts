extends "res://test/framework/test_case.gd"
## Foraging trips (decision 0681; feature #22): the three pantry items (the catalogue's keys and §5.7 rows), the real
## forage store driven on the demo calendar (§5.5's seasons, floor, daily quota and regrowth, claims), whole trips on real
## brains walking the real village layout -- claimed at the spot, gathered, carried and shelved -- THE BOOKS kept every
## frame, cancel and interruption losing nothing, a full store holding the haul, and the work board's adapter.
##
## Built over the placeholder cast on the real layout and the village's real water band (as test_demo_ferry.gd) -- no
## staged assets, no scene tree. Expected numbers are restated from their sources (GDD §5.5/§5.7, forage_rules.gd).

const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const ForageCore := preload("res://scripts/core/forage.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")
const DriverScript := preload("res://demo/forage/forage_driver.gd")
const TripsScript := preload("res://demo/forage/forage_trips.gd")
const SkillsScript := preload("res://demo/forage/forage_skills.gd")
const SectionScript := preload("res://demo/forage/forage_section.gd")
const ForageWork := preload("res://demo/work/forage_work.gd")
const WorkBoard := preload("res://demo/work/work_board.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const ErrandScript := preload("res://demo/tunnel/tunnel_task.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
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
const TripsPlaces := preload("res://demo/routes/work_trips.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 12000
## Summer day 1 (absolute day 12): every kind in season.
const SUMMER_DAY: int = 12
const NUTS: int = 0
const MUSHROOMS: int = 1
const HERBS: int = 2

class Rig:
	var cast: DemoCastScript = null
	var trips: TripsScript = null
	var pantry: PantryScript = null
	var calendar: CalendarScript = null
	var weather: DemoWeatherScript = null

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _books_kept: bool = true
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


static func tick_at(day: int, hour: int) -> int:
	"""The calendar tick at `hour`:00 of absolute `day` (day 0's 06:00 is tick 0)."""
	return (day * SimClock.HOURS_PER_DAY + hour) * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


static func _driver(tick: int = 0) -> DriverScript:
	"""A driver over the compiled catalogue's five forage ids."""
	var ids: DriverScript.IdsResult = DriverScript.resolve_item_ids()
	return DriverScript.create(ids.ids, tick) as DriverScript


func _rig(day: int = SUMMER_DAY, hour: int = 8) -> Rig:
	"""The placeholder cast walking the real layout round the water's band, the pantry over its store, and the trips, at
	`hour`:00 of absolute `day`, a mild day."""
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
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = tick_at(day, hour)
	rig.weather = DemoWeatherScript.new()
	rig.weather.observe(1, 1, hour, 160, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.trips = TripsScript.new()
	rig.trips.configure(rig.cast, _driver(rig.calendar.tick), rig.pantry, rig.calendar, rig.weather)
	return rig


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES, board: bool = true) -> bool:
	"""Step the cast, the calendar and the trips until `done()` (bounded), the work board's part each 20 frames (not
	with `board` false: the work board leaves a seat promised to a forager to it); THE BOOKS checked every frame
	(`_books_kept`)."""
	_books_kept = true
	for frame: int in frames:
		if bool(done.call()):
			return true
		if board and frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.trips.update(usec)
		if not rig.trips.books_balance():
			_books_kept = false
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part (decision 0411): each waiting seat to the first idle resident who may take it
	-- never one promised to another, who means to come back to it (decision 0411; 1905)."""
	var t: TripsScript = rig.trips
	for j: int in Rules.MAX_JOBS:
		if not t.waiting(j):
			continue
		var keeper: int = _promised_to(rig, t.j_serial[j])
		for who: int in rig.cast.actor_count():
			if keeper >= 0 and keeper != who:
				continue
			var brain: BrainScript = t.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and t.eligibility(j, who).is_empty() and t.claim(j, who):
				break


func _promised_to(rig: Rig, task_key: int) -> int:
	"""Who means to come back to that task (the work board leaves it to them, decision 0411; -1: nobody)."""
	for who: int in rig.cast.actor_count():
		if rig.trips.brain_of(who).promises(WorkIds.SOURCE_FORAGE, task_key):
			return who
	return -1


# --- the items -------------------------------------------------------------------------------------------------

func test_the_four_items_are_the_catalogues_keys_and_their_rows() -> void:
	"""nuts, mushrooms, herb, berries: data/item_definitions.json's ids and shelf hours, each its own category; nuts and
	berries raw edible at §5.7's 1600 and 700 NP, mushrooms and herb never; the forage store's patch rows map to them,
	roots to none."""
	assert_equal(Catalog.FIRST_FORAGE + Catalog.FORAGE_COUNT, 30, "24 before, the dishes' potato and honey, and four (decision 0902)")
	assert_equal(Catalog.FIRST_FRUIT, Catalog.FIRST_FORAGE + Catalog.FORAGE_COUNT, "the orchard's fruit after (decision 0903)")
	assert_equal(Catalog.FIRST_FORAGE, Catalog.ITEM_HONEY + 1, "the forage after the dishes' two")
	var keys: Array[StringName] = [Catalog.ITEM_KEYS[Catalog.ITEM_NUTS], Catalog.ITEM_KEYS[Catalog.ITEM_MUSHROOMS],
		Catalog.ITEM_KEYS[Catalog.ITEM_HERB], Catalog.ITEM_KEYS[Catalog.ITEM_BERRIES]]
	assert_equal(keys, [&"nuts", &"mushrooms", &"herb", &"berries"] as Array[StringName], "the catalogue's keys")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_definitions.json"))
	var shelf: Dictionary = {}
	for row: Variant in (data["items"] if data is Dictionary else data):
		shelf[String(row["id"])] = int(row["shelf_hours"])
	for item: int in [Catalog.ITEM_NUTS, Catalog.ITEM_MUSHROOMS, Catalog.ITEM_HERB, Catalog.ITEM_BERRIES]:
		assert_equal(Catalog.shelf_hours_of(item), shelf[String(Catalog.ITEM_KEYS[item])], "%s's shelf" % Catalog.ITEM_KEYS[item])
	assert_equal([Catalog.category_of(Catalog.ITEM_NUTS), Catalog.category_of(Catalog.ITEM_MUSHROOMS),
		Catalog.category_of(Catalog.ITEM_HERB), Catalog.category_of(Catalog.ITEM_BERRIES)],
		[Catalog.CAT_NUTS, Catalog.CAT_MUSHROOMS, Catalog.CAT_HERB, Catalog.CAT_BERRIES], "their own categories")
	assert_equal(MealRules.raw_np_per_u(Catalog.ITEM_NUTS), 1600, "nuts raw edible")
	assert_equal(MealRules.raw_np_per_u(Catalog.ITEM_BERRIES), 700, "berries raw edible")
	assert_equal(MealRules.raw_np_per_u(Catalog.ITEM_MUSHROOMS) + MealRules.raw_np_per_u(Catalog.ITEM_HERB), 0, "never raw")
	assert_equal([Catalog.item_of_patch(ForageCore.PATCH_BERRIES), Catalog.item_of_patch(ForageCore.PATCH_NUTS),
		Catalog.item_of_patch(ForageCore.PATCH_MUSHROOMS), Catalog.item_of_patch(ForageCore.PATCH_HERB),
		Catalog.item_of_patch(ForageCore.PATCH_ROOTS), Catalog.item_of_patch(9)],
		[Catalog.ITEM_BERRIES, Catalog.ITEM_NUTS, Catalog.ITEM_MUSHROOMS, Catalog.ITEM_HERB, Catalog.NO_ITEM, Catalog.NO_ITEM], "patch -> item")
	for k: int in Rules.KIND_COUNT:
		assert_equal(TripsScript.item_of(k), Catalog.FIRST_FORAGE + k, "kind %d in the pantry's order" % k)
	assert_equal(Catalog.ITEM_LABELS.size(), Catalog.PANTRY_ITEM_COUNT, "a label each")
	assert_equal(Catalog.ITEM_SWATCH.size(), Catalog.PANTRY_ITEM_COUNT, "a swatch each")
	assert_equal(Catalog.ITEM_PROP.size(), Catalog.PANTRY_ITEM_COUNT, "a prop slot each")


# --- the rules -------------------------------------------------------------------------------------------------

func test_the_rules_share_ask_and_work() -> void:
	"""Shares add up exactly; a trip asks a basket a forager; work rounds up; heavy rain works at 80%."""
	for total: int in [1, 7999, 8000, 12001]:
		for party: int in [1, 2, 3]:
			var sum: int = 0
			for seat: int in party:
				sum += Rules.share_milli(total, party, seat)
			assert_equal(sum, total, "%d among %d" % [total, party])
	assert_equal(Rules.share_milli(8001, 2, 0), 4001, "the remainder to the first seat")
	assert_equal([Rules.ask_milli(1), Rules.ask_milli(3), Rules.ask_milli(9), Rules.ask_milli(0)], [4000, 12000, 12000, 4000], "a basket each, 1-3")
	assert_equal(Rules.work_mwu(4000, 5), 20000, "4 U at 5 WU")
	assert_equal(Rules.work_mwu(1, 5), 5, "rounded up")
	var dry: int = Rules.mwu_numerator(1000000, WeatherCore.EVENT_NONE)
	assert_equal(Rules.mwu_numerator(1000000, WeatherCore.EVENT_HEAVY_RAIN) * 10, dry * 8, "80% in heavy rain")
	assert_true(Rules.is_kind(0) and Rules.is_kind(3) and not Rules.is_kind(4) and not Rules.is_kind(-1), "four kinds")
	assert_equal(Rules.NATURAL_DANGER, 1, "§5.5: within 64 m of the hall, no lookout")


# --- the store ----------------------------------------------------------------------------------------------------

func test_the_basin_is_the_gdds_five_patches_at_eighty_percent() -> void:
	"""One basin, five patches at §5.1's 80% of §5.5's capacities; the floor 20%; work per U at danger 1 (nuts 5, herb 8
	at FORAGE 0); REQ-SET-068's chance max(1, 8 - level)."""
	var d: DriverScript = _driver()
	assert_true(d != null, "made")
	var caps: Array[int] = [300, 240, 180, 160, 300]
	for kind: int in 5:
		assert_equal(d.capacity_milli(kind), caps[kind] * 1000, "capacity %d" % kind)
		assert_equal(d.stock_milli(kind), caps[kind] * 800, "80%% %d" % kind)
		assert_equal(d.floor_milli(kind), caps[kind] * 200, "floor %d" % kind)
	assert_equal(d.work_per_u_wu(ForageCore.PATCH_NUTS, 0), 5, "ceil(5e6 / (1000 x 1100))")
	assert_equal(d.work_per_u_wu(ForageCore.PATCH_HERB, 0), 8, "ceil(8e6 / 1.1e6)")
	assert_equal(d.work_per_u_wu(ForageCore.PATCH_HERB, 10), 6, "a skilled forager")
	assert_equal([d.injury_per_10000(0), d.injury_per_10000(7), d.injury_per_10000(10)], [8, 1, 1], "max(1, 8 - level)")
	assert_true(DriverScript.create(PackedInt32Array([1, 2]), 0) == null, "five ids or none")
	assert_true(DriverScript.create(DriverScript.resolve_item_ids().ids, -1) == null, "a tick at or after 0")


func test_the_seasons_quota_and_regrowth_are_the_stores() -> void:
	"""Spring: nuts dormant (nothing harvestable), mushrooms and herb in; the automatic quota spring 10.72 U, summer 21.128;
	a claim takes quota and stock, its collection debits the stock; midnight regrows and reopens the quota."""
	var d: DriverScript = _driver(0)
	assert_equal(d.season(), 0, "spring")
	assert_equal(d.availability(ForageCore.PATCH_NUTS), 0, "nuts dormant in spring")
	assert_equal(d.harvestable_milli(ForageCore.PATCH_NUTS), 0, "none to gather")
	assert_equal(d.quota_today_milli(), 10720, "spring's automatic quota")
	var job: Vector2i = d.open_claim(ForageCore.PATCH_HERB, 4000)
	assert_true(job != DriverScript.NULL_REF, "claimed")
	assert_equal(d.quota_left_milli(), 6720, "the claim holds quota")
	assert_equal(d.remaining_milli(job), 4000, "outstanding")
	assert_equal(d.collect(job, ForageCore.PATCH_HERB, 4000), 4000, "collected")
	assert_equal(d.stock_milli(ForageCore.PATCH_HERB), 128000 - 4000, "the stock debited")
	assert_equal(d.harvested_today_milli(), 4000, "today's total")
	d.close(job)
	assert_equal(d.open_claims(), 0, "closed")
	assert_true(d.open_claim(ForageCore.PATCH_HERB, 7000) == DriverScript.NULL_REF, "over today's quota: refused")
	assert_equal(String(d.last_refusal), "QUOTA_REACHED", "said")
	assert_equal(d.follow(tick_at(1, 6)), 1, "one midnight")
	assert_equal(d.quota_left_milli(), 10720, "the quota reopens")
	assert_true(d.stock_milli(ForageCore.PATCH_HERB) > 124000, "regrown")
	d.follow(tick_at(SUMMER_DAY, 6))
	assert_equal(d.season(), 1, "summer")
	assert_equal(d.quota_today_milli(), 21128, "summer's quota")
	assert_true(d.harvestable_milli(ForageCore.PATCH_NUTS) > 0, "nuts in summer")
	assert_equal(d.follow(tick_at(SUMMER_DAY, 5)), 0, "never back")


func test_a_claim_released_at_midnight_is_collected_through_the_unclaimed_path() -> void:
	"""A seat whose claim midnight released (a season's change) still brings home what the store admits."""
	var d: DriverScript = _driver(tick_at(SUMMER_DAY - 1, 20))
	var job: Vector2i = d.open_claim(ForageCore.PATCH_MUSHROOMS, 3000)
	d.forage.release_claim(job)
	assert_equal(d.remaining_milli(job), 0, "released")
	var stock: int = d.stock_milli(ForageCore.PATCH_MUSHROOMS)
	assert_equal(d.collect(job, ForageCore.PATCH_MUSHROOMS, 3000), 3000, "collected all the same")
	assert_equal(d.stock_milli(ForageCore.PATCH_MUSHROOMS), stock - 3000, "debited once")
	assert_equal(d.collect(job, ForageCore.PATCH_MUSHROOMS, 0), 0, "nothing asked, nothing")
	d.close(DriverScript.NULL_REF)
	d.close(job)
	assert_equal(d.open_claims(), 0, "nothing outstanding")


# --- the trips ----------------------------------------------------------------------------------------------------

func test_a_trip_out_of_season_or_beyond_the_quota_is_refused() -> void:
	"""Nuts in spring: refused with their seasons; a party outside 1-3 refused; with the day's quota claimed, refused with
	when it reopens; the fourth trip refused."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_true(t.trip_refusal(NUTS, 2).contains("out of season"), t.trip_refusal(NUTS, 2))
	assert_true(t.trip_refusal(NUTS, 2).contains("summer, autumn, winter"), "when they come: %s" % t.trip_refusal(NUTS, 2))
	assert_true(t.trip_refusal(HERBS, 0).contains("party"), "no empty party")
	assert_true(t.trip_refusal(HERBS, 4).contains("party"), "nor four")
	assert_true(t.trip_refusal(-1, 2).contains("choose"), "a kind")
	var job: Vector2i = t.driver.open_claim(ForageCore.PATCH_HERB, t.driver.quota_left_milli())
	assert_true(job != DriverScript.NULL_REF, "the day's quota claimed elsewhere")
	assert_true(t.trip_refusal(HERBS, 1).contains("daily quota"), t.trip_refusal(HERBS, 1))
	t.driver.close(job)
	for k: int in Rules.MAX_TRIPS:
		assert_equal(t.order_trip(HERBS, 1, PackedInt32Array()), "", "trip %d" % k)
	assert_true(t.trip_refusal(MUSHROOMS, 1).contains("trips are out"), "the fourth")
	assert_equal(t.trip_count(), Rules.MAX_TRIPS, "three out")


func test_a_trip_goes_out_gathers_and_brings_the_haul_home() -> void:
	"""Summer: two foragers for nuts; each walks to the hazel brake, claims and gathers its share, carries it to the store
	in its basket and shelves it as nuts; THE BOOKS kept every frame; the basin's stock and quota debited by exactly the
	haul; FORAGE XP earned; the party's return said."""
	var rig: Rig = _rig()
	var t: TripsScript = rig.trips
	var said := PackedStringArray()
	t.say = func(text: String, _warning: bool) -> void: said.append(text)
	var stock: int = t.driver.stock_milli(ForageCore.PATCH_NUTS)
	assert_equal(t.trip_milli(NUTS, 2), 8000, "two baskets")
	assert_equal(t.order_trip(NUTS, 2, PackedInt32Array([1, 2])), "", "authorised")
	assert_equal(t.job_count(), 2, "two seats")
	assert_true(t.job_of_worker(1) >= 0 and t.job_of_worker(2) >= 0, "to the selected first")
	assert_true(t.trip_line(t.first_trip()).begins_with("Nuts from the hazel brake: 2 foragers ("), t.trip_line(t.first_trip()))
	assert_true(t.trip_line(t.first_trip()).contains("), 16 handfuls asked, none home"),
		"8 U of nuts asked: 16 handfuls of 0.5 U (decision 1011): " + t.trip_line(t.first_trip()))
	var carried: Array[bool] = [false]
	assert_true(_run(rig, func() -> bool:
		for j: int in Rules.MAX_JOBS:
			carried[0] = carried[0] or t.held_key_of_job(j) == TripsScript.BASKET_KEY
		return t.trip_count() == 0), "home (%s)" % _seats(t))
	assert_true(_books_kept, "THE BOOKS every frame")
	assert_true(carried[0], "carried in a basket")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_NUTS), 8000, "8 U of nuts shelved")
	assert_equal(t.stored_milli[NUTS], 8000, "booked")
	assert_equal(t.driver.stock_milli(ForageCore.PATCH_NUTS), stock - 8000, "the stock debited by the haul")
	assert_equal(t.driver.harvested_today_milli(), 8000, "today's quota by the haul")
	assert_equal(t.driver.open_claims(), 0, "no claim left")
	assert_equal(t.driver.jobs.job_count(), 0, "no FORAGE Job row left")
	assert_equal([t.skills.xp[1], t.skills.xp[2]], [200, 200], "§5.3: 10 XP a WU of the 20 WU each gathered (4 U at 5 WU)")
	assert_true(said[said.size() - 1].contains("back from the hazel brake: 16 handfuls of nuts"), said[said.size() - 1])
	assert_equal(t.trips_done, 1, "one trip done")
	assert_equal(t.quota_words(&"nuts"), "26 handfuls left of 42 handfuls of nuts",
		"summer's 21.128 U less the 8 U haul, in the chosen kind's handfuls (floored)")
	assert_equal(t.status_line(), "Foraging: 0 trips out · the woods' quota today: 2½ baskets left of 4 baskets of food",
		"the shared quota as mixed food: 13.128 U is 2½ baskets of 5 U, 21.128 U is 4 baskets (floored to halves)")


func test_cancel_gives_the_claims_and_room_back() -> void:
	"""Called off at the spot while gathering: nothing is gathered, the claims and the store's room are given back, and
	the seats end; a trip with nothing out cannot be called off."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_true(t.cancel_refusal(t.first_trip()).contains("no foraging trip"), "none out")
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_live[0] == 1 and t.j_step[0] == TripsScript.S_GATHER), "gathering")
	assert_equal(t.driver.open_claims(), 1, "its claim held")
	assert_true(rig.pantry.is_hold(t.j_hold[0]), "its room held")
	assert_equal(t.cancel_refusal(t.first_trip()), "", "may be called off")
	assert_equal(t.cancel_trip(t.first_trip()), "", "called off")
	assert_equal(t.driver.open_claims(), 0, "the claim given back")
	assert_equal(t.driver.quota_left_milli(), t.driver.quota_today_milli(), "the quota whole")
	assert_false(rig.pantry.is_hold(0) or rig.pantry.is_hold(1), "the room given back")
	assert_equal([t.job_count(), t.trip_count()], [0, 0], "over")
	assert_true(t.cancel_trip(-1).contains("no such"), "no such trip")


func test_an_interruption_loses_nothing_and_another_finishes() -> void:
	"""The forager called away mid-gathering: the seat goes back on the board with its claim, room and work done; another
	takes it, works only what is left, and shelves the whole share. A forager carrying home cannot be paused or swapped,
	and its seat cannot be cancelled."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_live[0] == 1 and t.j_mwu[0] > 4000), "partly gathered")
	var done: int = t.j_mwu[0]
	assert_equal(t.pause_job(0, true), "", "paused (its forager stood down)")
	assert_equal(t.j_worker[0], TripsScript.NONE, "free")
	assert_equal(t.driver.open_claims(), 1, "the claim kept")
	assert_true(t.j_mwu[0] >= done, "the work kept")
	assert_true(t.pause_job(0, true).contains("already"), "paused already")
	assert_equal(t.pause_job(0, false), "", "resumed")
	assert_equal(t.reassign_job(0, 4), "", "to another")
	assert_true(_run(rig, func() -> bool: return t.j_live[0] == 1 and t.j_load[0] > 0), "carrying")
	assert_true(t.hold_refusal(0).contains("carrying"), "a haul in hand: %s" % t.hold_refusal(0))
	assert_true(t.must_finish(0, t.j_serial[0]), "the night waits")
	assert_true(t.cancel_job(0).contains("delivery"), "not cancelled")
	assert_true(t.cancel_refusal(t.first_trip()).contains("carrying"), "nor the trip")
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 4000, "the whole basket shelved")
	assert_equal(t.driver.open_claims(), 0, "the one claim, taken over, collected and closed")
	assert_true(_books_kept, "THE BOOKS")


func test_a_full_store_holds_the_seat_until_there_is_room() -> void:
	"""No store has room: the forager at its spot claims nothing, says why and waits; room made, it gathers and shelves."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var cap: int = rig.pantry.storage.capacity_milli_of(0)
	assert_true(rig.pantry.add_into(Catalog.ITEM_HERB, cap, 0, _read), "the store filled")
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_words[0].contains("no store has room")), "waiting for room")
	assert_equal(t.driver.open_claims(), 0, "nothing claimed")
	var lot: int = 0
	assert_true(rig.pantry.withdraw_into(lot, rig.pantry.lot_serial(lot), 8000, _read), "room made")
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home (%s)" % _seats(t))
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), cap - 8000 + 4000, "shelved")


func test_the_work_board_reads_the_seats() -> void:
	"""Source 12 since the batch 7 integration (decision 0902: after the ferry, the food stores, the hall and the
	infirmary; the walk after it), the Woods activity; a waiting seat queued, taken, then its states; its words."""
	assert_equal(WorkIds.SOURCE_FORAGE, 12, "the source after the infirmary's")
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a queued walk is past every source")
	assert_equal(WorkIds.SOURCE_NAMES[WorkIds.SOURCE_FORAGE], "Foraging", "named")
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var work := ForageWork.new(t)
	assert_equal(work.capacity(), Rules.MAX_JOBS, "the seat rows")
	assert_equal(t.order_trip(MUSHROOMS, 1, PackedInt32Array()), "", "authorised")
	var task := TaskRecord.new()
	work.fill(task, 0)
	assert_equal([task.state, task.activity, task.action, task.target], [WorkIds.STATE_QUEUED, WorkIds.ACT_WOODS,
		"Forage mushrooms", "the beech hollow"], "queued")
	assert_true(work.live(0) and work.waiting(0) and work.worker(0) == -1, "waiting")
	assert_equal(work.eligibility(0, 2), "", "anyone may")
	assert_true(work.claim(0, 2), "taken")
	assert_equal(work.worker(0), 2, "by 2")
	assert_true(t.eligibility(1, 2).contains("another foraging trip"), "one seat at a time")
	work.fill(task, 0)
	assert_true(task.state == WorkIds.STATE_TRAVELLING or task.state == WorkIds.STATE_ASSIGNED, "on its way: %d" % task.state)
	assert_true(t.doing_text(0, t.j_serial[0]).contains("going to the beech hollow"), t.doing_text(0, t.j_serial[0]))
	assert_equal(work.key(0), t.j_serial[0], "its serial")
	assert_equal(work.pause(0, true), "", "paused")
	work.fill(task, 0)
	assert_equal(task.state, WorkIds.STATE_PAUSED, "paused")
	assert_equal(work.reassign(0, 3), "", "reassigned")
	assert_equal(work.cancel(0), "", "cancelled")
	assert_false(work.live(0), "gone")


func test_the_spots_stand_in_the_woods_and_on_the_routes_layer() -> void:
	"""Each kind's spot is snapped to standable ground near where it was placed, within the woods' 30 m reach of the
	square; the Routes layer's forage grounds are the hazel brake."""
	var rig: Rig = _rig()
	for k: int in Rules.KIND_COUNT:
		assert_true(rig.trips.spot_at[k].distance_to(Rules.SPOT_AT[k]) < 4.0, "spot %d snapped near" % k)
		assert_true(maxf(absf(rig.trips.spot_at[k].x), absf(rig.trips.spot_at[k].y)) <= 31.0, "spot %d in reach" % k)
		assert_true(rig.trips.spot_at[k].length() > 22.0, "spot %d beyond the clearing" % k)
	assert_equal(TripsPlaces.AUTHORED[TripsPlaces.FORAGE], Rules.SPOT_AT[0], "the forage grounds")
	assert_true(TripsPlaces.DISTRICTS.has(TripsPlaces.FORAGE), "a public way")


func test_the_trips_update_allocates_nothing() -> void:
	"""The per-frame update (the basin followed, the work credited, the retries) retains no object."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	t.order_trip(HERBS, 2, PackedInt32Array([1, 2]))
	_run(rig, func() -> bool: return t.j_step[0] == TripsScript.S_GATHER, MAX_FRAMES)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 200:
		t.update(33333)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object retained")


func test_the_skills_and_the_section() -> void:
	"""FORAGE: 10 XP a WU, the part carried; the section's lines and buttons."""
	var skills := SkillsScript.new()
	skills.setup(2)
	skills.add_work(0, 1500)
	assert_equal(skills.xp[0], 10, "one whole WU")
	skills.add_work(0, 500)
	assert_equal(skills.xp[0], 20, "the half carried")
	skills.add_work(5, 1000)
	skills.add_work(1, 0)
	assert_equal([skills.level_of(0), skills.level_of(9)], [0, 0], "levels")
	assert_equal(skills.line_of(1), "Foraging 0", "the party panel's line")
	assert_equal(skills.line_of(7), "", "nobody")
	var section: SectionScript = _keep(SectionScript.new()) as SectionScript
	section.build(280.0)
	section.show_lines("woods", "trip", "", "herbs", 3)
	assert_equal([section.line(&"woods"), section.button(SectionScript.ACTION_KIND).text,
		section.button(SectionScript.ACTION_PARTY).text], ["woods", "Gather ▸ herbs", "Party ▸ 3"], "shown")
	section.set_card(SectionScript.ACTION_AUTHORISE, "card", false)
	assert_true(section.button(SectionScript.ACTION_AUTHORISE).disabled, "refused")


func _seats(t: TripsScript) -> String:
	"""Every live seat, for a failure's message."""
	var parts := PackedStringArray()
	for j: int in Rules.MAX_JOBS:
		if t.j_live[j] == 1:
			parts.append("seat %d step %d worker %d load %d words '%s' goal %s" % [j, t.j_step[j], t.j_worker[j], t.j_load[j],
				t.j_words[j], t.j_goal[j]])
	return "; ".join(parts)


func test_cancel_lets_a_haul_in_hand_come_home() -> void:
	"""A trip called off with one forager carrying and one still gathering: the gatherer's seat ends, the carrier
	delivers."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_live[0] == 1 and t.j_load[0] > 0 and t.j_live[1] == 1 and t.j_load[1] == 0),
		"one carrying, one not (%s)" % _seats(t))
	assert_equal(t.cancel_trip(t.first_trip()), "", "called off")
	assert_equal([t.j_live[0], t.j_live[1]], [1, 0], "the carrier goes on, the other ends")
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 4000, "its haul shelved")


func test_a_claim_released_at_work_brings_home_what_the_woods_still_admit() -> void:
	"""A seat's claim released while it works (midnight's reconciliation) and the day's quota nearly spent elsewhere: it
	collects what the store still admits, its room trimmed to the smaller haul, and shelves exactly that."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_live[0] == 1 and t.j_step[0] == TripsScript.S_GATHER and t.j_claimed[0] > 0),
		"claimed")
	t.driver.forage.release_claim(Vector2i(t.j_claim_slot[0], t.j_claim_gen[0]))
	var other: Vector2i = t.driver.open_claim(ForageCore.PATCH_HERB, t.driver.quota_left_milli() - 1000)
	assert_true(other != DriverScript.NULL_REF, "the rest of today's quota claimed elsewhere")
	assert_true(_run(rig, func() -> bool: return t.j_load[0] > 0), "gathered")
	assert_equal(t.j_load[0], 1000, "what the woods still admit")
	assert_equal(rig.pantry.hold_milli(t.j_hold[0]), 1000, "its room trimmed to it")
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 1000, "shelved")
	t.driver.close(other)


# --- called away, a forager keeps its seat (decision 1905, as the orchard's 1900) ----------------------------------

func _gathering_a_quarter_done(rig: Rig, who: int) -> int:
	"""Resident `who` sent for herbs alone and run until a quarter of its gathering is done; the seat's row."""
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([who])), "", "authorised for %d" % who)
	var j: int = t.job_of_worker(who)
	var quarter := func() -> bool: return t.j_step[j] == TripsScript.S_GATHER and t.j_need[j] > 0 \
		and t.j_mwu[j] * 4 >= t.j_need[j]
	assert_true(_run(rig, quarter, MAX_FRAMES, false), "a quarter gathered")
	return j


func _board_over(rig: Rig, j: int) -> WorkBoard:
	"""The REAL work board over the rig's residents, its one source: a crew key a resident, and every crew allowed job
	`j`'s activity, so the board WOULD give it to an idle resident -- the promise is what stops it."""
	var board := WorkBoard.new()
	var brains: Array[BrainScript] = []
	var names := PackedStringArray()
	var keys: Array[StringName] = []
	for who: int in rig.cast.actor_count():
		brains.append(rig.trips.brain_of(who))
		names.append(rig.trips.name_of(who))
		keys.append(&"")
	board.bind(brains, names, keys)
	var source := ForageWork.new(rig.trips)
	for crew: int in CrewsScript.CREW_COUNT:
		board.crews.set_priority(crew, source.activity(j), WorkIds.PRIORITY_NORMAL)
	board.add_source(source)
	return board


func test_a_forager_called_away_keeps_the_seat_promised_on_the_work_board() -> void:
	"""Decision 1905: resident 3, a quarter into gathering herbs, is called away by an order -- as a meal's call does --
	and keeps the seat: on her list naming it, the REAL work board gives it to none of the idle residents, her order
	done it is hers again, and back at the spot she goes on from where she stopped."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var j: int = _gathering_a_quarter_done(rig, 3)
	var board: WorkBoard = _board_over(rig, j)
	var brain: BrainScript = t.brain_of(3)
	var no_rules: Array[Callable] = []
	assert_equal(InterruptScript.resume_of(brain, no_rules, 3), InterruptScript.RESUMES, "the card: goes back to it")
	var done: int = t.j_mwu[j]
	var need: int = t.j_need[j]
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, ForageWork.new(t).key(j)), "kept, naming its seat")
	assert_true(t.waiting(j) and t.eligibility(j, 2).is_empty(), "the seat waits, and another may take it")
	assert_equal(brain.queue_entry(0).label() if brain.queue_size() > 0 else "", "Forage herbs, the herb bank",
		"in the order list's words")
	board.rebuild_index()
	for who: int in rig.cast.actor_count():
		board.consider(who)
	assert_equal(t.j_worker[j], TripsScript.NONE, "nobody else was given it")
	brain.work_done()
	assert_equal(t.j_worker[j], 3, "back to it")
	var at_work := func() -> bool: return t.j_step[j] == TripsScript.S_GATHER and t.j_at[j] == 1
	assert_true(_run(rig, at_work, MAX_FRAMES, false), "gathering again")
	assert_equal(t.j_need[j], need, "the same share")
	@warning_ignore("integer_division") var one_frame: int = need / 20
	assert_true(t.j_mwu[j] >= done and t.j_mwu[j] < done + one_frame,
		"from where she stopped: %d after %d" % [t.j_mwu[j], done])
	assert_true(_books_kept, "THE BOOKS")


func test_a_seat_lost_on_the_way_paused_or_reassigned_keeps_nothing() -> void:
	"""Decision 1905: a walk given up keeps nothing (the seat waits RETRY_USEC, one try counted), nor do the board's
	Pause and Reassign for the forager they take the seat from."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	var j: int = t.job_of_worker(3)
	assert_equal(t.pause_job(j, true), "", "paused")
	assert_equal(t.brain_of(3).queue_size(), 0, "a pause keeps nothing")
	assert_equal(t.pause_job(j, false), "", "resumed")
	assert_equal(t.reassign_job(j, 3), "", "given back to 3")
	assert_equal(t.reassign_job(j, 4), "", "and on to 4")
	assert_equal(t.brain_of(3).queue_size(), 0, "a reassign keeps nothing")
	var brain: BrainScript = t.brain_of(4)
	brain.trip_outcome = BrainScript.TRIP_FAILED
	brain.order_task(ErrandScript.new())
	assert_equal(brain.queue_size(), 0, "a walk it could not finish keeps nothing")
	assert_equal(t.j_wait_usec[j], Rules.RETRY_USEC, "the seat waits to be offered again")
	assert_equal(t.j_tries[j], 1, "one try counted")


func test_a_kept_seat_cancelled_is_stale() -> void:
	"""Decision 1905: a kept seat the player cancels -- its row reused by the next trip -- is neither taken back nor
	kept again."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	var j: int = t.job_of_worker(3)
	var old_serial: int = t.j_serial[j]
	var brain: BrainScript = t.brain_of(3)
	brain.order_task(ErrandScript.new())
	assert_equal(brain.queue_size(), 1, "kept")
	assert_equal(t.cancel_job(j), "", "cancelled")
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array()), "", "another trip")
	assert_equal(t.j_live[j], 1, "its seat in the same row")
	assert_false(t.take_back(brain, j, old_serial), "the old entry is stale")
	assert_null(t.unfinished_of(j, old_serial), "and makes no entry")
	assert_equal(t.j_worker[j], TripsScript.NONE, "the new seat is not hers")


func test_a_party_seat_refilled_while_its_forager_is_away_is_not_taken_back() -> void:
	"""Decision 1905's pitfall: one of a party of two, called away, keeps her seat; the board's Reassign gives it to
	another meanwhile -- she no longer promises it (nobody does), it is not taken back, and nobody is displaced."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var serial: int = t.j_serial[j]
	var board: WorkBoard = _board_over(rig, j)
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "kept")
	assert_equal(board.reassign(WorkIds.SOURCE_FORAGE, j, 5), "", "the seat refilled by Reassign")
	assert_false(brain.promises(WorkIds.SOURCE_FORAGE, serial), "she no longer promises it")
	assert_false(t.take_back(brain, j, serial), "not taken back")
	brain.work_done()
	assert_equal(t.j_worker[j], 5, "nobody displaced")


func test_without_her_promise_the_board_gives_the_seat_to_another() -> void:
	"""The control for the REAL work board test (decision 1905): the same seat, her entry removed, is given to another
	idle resident -- so it is the promise, not the board's setup, that keeps it for her."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var j: int = _gathering_a_quarter_done(rig, 3)
	var board: WorkBoard = _board_over(rig, j)
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_true(brain.remove_queued(0), "her entry removed")
	board.rebuild_index()
	for who: int in rig.cast.actor_count():
		board.consider(who)
	assert_true(t.j_worker[j] >= 0 and t.j_worker[j] != 3, "another took it: %d" % t.j_worker[j])


# --- TRIP DOESN'T WAIT (Brendan, 2026-10-12; decision 1905) ---------------------------------------------------------

func _party_with_one_away(rig: Rig) -> int:
	"""A party of two (3 and 4) for herbs, 3 called away at once and keeping her seat; run until the party, under way,
	gives the seat up. Its row."""
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var serial: int = t.j_serial[j]
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "kept at first")
	var released := func() -> bool: return not brain.promises(WorkIds.SOURCE_FORAGE, serial)
	assert_true(_run(rig, released, MAX_FRAMES, false), "released: the party is under way")
	return j


func test_a_party_under_way_does_not_wait_for_a_forager_called_away() -> void:
	"""TRIP DOESN'T WAIT: the seat of a forager called away is offered by the REAL work board to an idle resident, who
	gathers it and brings the share home."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var j: int = _party_with_one_away(rig)
	var board: WorkBoard = _board_over(rig, j)
	board.rebuild_index()
	for who: int in rig.cast.actor_count():
		board.consider(who)
	assert_true(t.j_worker[j] >= 0 and t.j_worker[j] != 3, "another took it: %d" % t.j_worker[j])
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0, MAX_FRAMES, false), "the party home")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 8000, "both shares shelved")


func test_the_forager_back_from_her_meal_steps_aside() -> void:
	"""TRIP DOESN'T WAIT: back, the forager called away has nothing to come back to -- no promise, no seat taken from
	whoever has it now; she goes on with her routine."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var j: int = _party_with_one_away(rig)
	var board: WorkBoard = _board_over(rig, j)
	board.rebuild_index()
	for who: int in rig.cast.actor_count():
		board.consider(who)
	var now: int = t.j_worker[j]
	var brain: BrainScript = t.brain_of(3)
	brain.work_done()
	assert_equal(brain.queue_size(), 0, "nothing on her list")
	assert_equal(t.j_worker[j], now, "the seat still theirs")
	assert_equal(t.job_of_worker(3), TripsScript.NONE, "no seat of hers")


func test_a_forager_alone_still_keeps_her_seat() -> void:
	"""TRIP DOESN'T WAIT is for a party only: a forager out alone, called away, keeps her seat however long she is away
	(solo work waits for its worker)."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	var j: int = _gathering_a_quarter_done(rig, 3)
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_equal(t.order_trip(MUSHROOMS, 1, PackedInt32Array([5])), "", "another forager out on a trip of her own")
	_run(rig, func() -> bool: return false, 600, false)
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, t.j_serial[j]), "still kept")
	assert_equal(t.j_worker[j], TripsScript.NONE, "and nobody else's")


func test_a_party_seat_with_its_haul_set_down_is_still_kept() -> void:
	"""TRIP DOESN'T WAIT gives up a seat with nothing in hand only: one of a party called away while carrying home sets
	the haul down and keeps her seat (a load in hand is a delivery, decision 0222)."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var partner: int = t.job_of_worker(4)
	var carrying := func() -> bool: return t.j_worker[j] == 3 and t.j_load[j] > 0 and t.j_worker[partner] == 4
	assert_true(_run(rig, carrying, MAX_FRAMES, false), "carrying home, her partner still out")
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_true(t.j_load_at[j].is_finite(), "the haul set down")
	_run(rig, func() -> bool: return false, 60, false)
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, t.j_serial[j]), "still kept")


func _next_hour(rig: Rig, hour: int) -> int:
	"""The calendar tick of the next `hour`:00 (0..23) from now."""
	var now: int = rig.calendar.hour_index()
	var at: int = now - posmod(now, SimClock.HOURS_PER_DAY) + hour
	if at <= now:
		at += SimClock.HOURS_PER_DAY
	return at * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


# --- held places: the player's order holds, working hours, O(1) (Brendan, 2026-10-12; decision 1905) -----------------

func test_a_seat_the_player_queued_holds_for_her() -> void:
	"""PLAYER'S ORDER HOLDS: 3, called away, kept her seat; the player then queued it (Shift+right-click) for resident
	5, busy. With the party under way the KEPT place -- 3's -- is given up, but 5's queued order holds, and the board
	gives the seat to nobody else."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var serial: int = t.j_serial[j]
	var board: WorkBoard = _board_over(rig, j)
	t.brain_of(3).order_move(t.brain_of(3).position + Vector2(-1.0, 0.0))
	var brain: BrainScript = t.brain_of(5)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_equal(board.queue_task(WorkIds.SOURCE_FORAGE, j, 5), "", "the seat queued for 5")
	var released := func() -> bool: return not t.brain_of(3).promises(WorkIds.SOURCE_FORAGE, serial)
	assert_true(_run(rig, released, MAX_FRAMES, false), "3's kept place given up")
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "5's queued order holds")
	board.rebuild_index()
	for who: int in rig.cast.actor_count():
		board.consider(who)
	assert_equal(t.j_worker[j], TripsScript.NONE, "the seat waits for her")


func test_a_kept_party_seat_is_given_up_only_in_working_hours() -> void:
	"""ONLY IN WORKING HOURS: one of a party called away keeps her seat overnight though her partner is out; in the
	morning the party gives it up."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var serial: int = t.j_serial[t.job_of_worker(3)]
	rig.calendar.tick = _next_hour(rig, 21)
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	_run(rig, func() -> bool: return false, 60, false)
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "overnight it stays hers")
	rig.calendar.tick = _next_hour(rig, 6)
	var released := func() -> bool: return not brain.promises(WorkIds.SOURCE_FORAGE, serial)
	assert_true(_run(rig, released, 60, false), "given up at dawn (06:00)")


func test_only_the_keepers_seat_entry_is_given_up() -> void:
	"""O(1): the party gives up only the entry of the forager it let keep the seat (its keeper column) -- another
	resident's kept entry naming the same seat (put on 5's list by hand) is not looked at."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var serial: int = t.j_serial[j]
	t.brain_of(3).order_move(t.brain_of(3).position + Vector2(-1.0, 0.0))
	var brain: BrainScript = t.brain_of(5)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	brain.remember_unfinished(t.unfinished_of(j, serial))
	var released := func() -> bool: return not t.brain_of(3).promises(WorkIds.SOURCE_FORAGE, serial)
	assert_true(_run(rig, released, MAX_FRAMES, false), "the keeper's place given up")
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "5's entry not looked at")


func test_two_party_seats_both_away_stay_kept() -> void:
	"""Both of a party called away (as the night takes both): nobody is out, the party is not under way, and both keep
	their seats."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var serials := PackedInt32Array([t.j_serial[t.job_of_worker(3)], t.j_serial[t.job_of_worker(4)]])
	for who: int in [3, 4]:
		t.brain_of(who).order_move(t.brain_of(who).position + Vector2(-1.0, 0.0))
	_run(rig, func() -> bool: return false, 300, false)
	assert_true(t.brain_of(3).promises(WorkIds.SOURCE_FORAGE, serials[0]), "3 still keeps hers")
	assert_true(t.brain_of(4).promises(WorkIds.SOURCE_FORAGE, serials[1]), "4 still keeps hers")


func test_her_own_queued_order_outlives_the_release_of_her_kept_seat() -> void:
	"""PLAYER'S ORDER HOLDS: one of a party also queued her own seat (Shift+right-click) before she was called away. The
	party gives up only her KEPT entry; her queued order holds, so the seat still waits for her."""
	var rig: Rig = _rig(2, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 2, PackedInt32Array([3, 4])), "", "a party of two")
	var j: int = t.job_of_worker(3)
	var serial: int = t.j_serial[j]
	var board: WorkBoard = _board_over(rig, j)
	assert_equal(board.queue_task(WorkIds.SOURCE_FORAGE, j, 3), "", "queued for herself")
	var brain: BrainScript = t.brain_of(3)
	brain.order_move(brain.position + Vector2(-1.0, 0.0))
	assert_equal(brain.queue_size(), 2, "queued and kept")
	_run(rig, func() -> bool: return false, 60, false)
	assert_equal(brain.queue_size(), 1, "the kept entry given up")
	assert_true(brain.promises(WorkIds.SOURCE_FORAGE, serial), "her queued order holds")
