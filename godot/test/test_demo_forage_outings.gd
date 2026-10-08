extends "res://test/framework/test_case.gd"
## Prepared gathering outings (review ECO-014; decision 1721) and the protected groves' forage reserve (ECO-015): the
## rules' arithmetic (home by dusk at the slowest pace, the kit's share, the clock), a trip refused at night or too late,
## a forager who turns back for the dark with nothing claimed, the carry kit lent to one trip, a named lead, the place
## remembered (the latest trip only), and a grove's reserve kept above §5.5's floor. Built as test_demo_forage.gd builds
## its rig: the placeholder cast on the real layout, the real forage store on the demo calendar.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForageCore := preload("res://scripts/core/forage.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")
const DriverScript := preload("res://demo/forage/forage_driver.gd")
const TripsScript := preload("res://demo/forage/forage_trips.gd")
const SectionScript := preload("res://demo/forage/forage_section.gd")
const ForageNode := preload("res://demo/forage/demo_forage.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const OrchardRules := preload("res://demo/orchard/orchard_rules.gd")
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
	var said: PackedStringArray = PackedStringArray()

	func say(text: String, _warning: bool) -> void:
		"""The notice feed, kept."""
		said.append(text)

static var _map_cache: WaterMapScript = null

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


func _rig(day: int = SUMMER_DAY, hour: int = 8) -> Rig:
	"""test_demo_forage.gd's rig at `hour`:00 of absolute `day`, a mild day, its notices kept."""
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
	var weather := DemoWeatherScript.new()
	weather.observe(1, 1, hour, 160, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.trips = TripsScript.new()
	var ids: DriverScript.IdsResult = DriverScript.resolve_item_ids()
	rig.trips.configure(rig.cast, DriverScript.create(ids.ids, rig.calendar.tick) as DriverScript, rig.pantry, rig.calendar,
		weather)
	rig.trips.say = rig.say
	return rig


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast, the calendar and the trips until `done()`, the work board's part each 20 frames."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.trips.update(usec)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part: each waiting seat to the first idle resident who may take it."""
	var t: TripsScript = rig.trips
	for j: int in Rules.MAX_JOBS:
		if not t.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = t.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and t.eligibility(j, who).is_empty() and t.claim(j, who):
				break


# --- the rules ---------------------------------------------------------------------------------------------------------

func test_dusk_is_the_nights() -> void:
	"""The trips' dusk and dawn are the night routine's (night_routine.gd), read there, kept equal here."""
	assert_equal(Rules.DUSK_HOUR, NightScript.DUSK_HOUR, "dusk")
	assert_equal(Rules.DAWN_HOUR, NightScript.DAWN_HOUR, "dawn")
	assert_equal(Rules.WALK_M_PER_HOUR * 1000 * 1000000, 720 * CalendarScript.HOUR_USEC, "0.72 m/s for a 25 s hour: 18 m")


func test_daylight_is_counted_to_dusk() -> void:
	"""`daylight_ticks`: none before 06:00 or from 20:00; 14 hours at 06:00; one tick at 19:59:59."""
	var hour: int = SimClock.TICKS_PER_HOUR
	assert_equal(Rules.daylight_ticks(6 * hour - 1), 0, "before dawn")
	assert_equal(Rules.daylight_ticks(6 * hour), 14 * hour, "dawn: fourteen hours")
	assert_equal(Rules.daylight_ticks(20 * hour - 1), 1, "the last tick")
	assert_equal(Rules.daylight_ticks(20 * hour), 0, "dusk")
	assert_equal(Rules.daylight_ticks(23 * hour), 0, "night")


func test_walks_and_gathering_are_integer_ticks() -> void:
	"""`walk_ticks`: 18 m an hour at the slowest, rounded up; `gatherable_milli`: §5.2's 80 milli-WU a tick at the
	work per U, floored, 80% in heavy rain; nothing in no time."""
	assert_equal(Rules.walk_ticks(18.0), SimClock.TICKS_PER_HOUR, "an hour")
	assert_equal(Rules.walk_ticks(0.0), 0, "no walk")
	assert_equal(Rules.walk_ticks(-3.0), 0, "never negative")
	assert_equal(Rules.walk_ticks(0.01), 1, "rounded up")
	assert_equal(Rules.gatherable_milli(750, 5, 1000), 12000, "an hour at 5 WU a unit: 12 U")
	assert_equal(Rules.gatherable_milli(750, 5, 800), 9600, "heavy rain: 80%")
	assert_equal(Rules.gatherable_milli(1, 3, 1000), 26, "80 milli-WU at 3 WU a unit, floored")
	assert_equal(Rules.gatherable_milli(0, 5, 1000), 0, "no time")
	assert_equal(Rules.gatherable_milli(750, 0, 1000), 0, "no rate")


func test_the_kit_carrier_takes_two_shares() -> void:
	"""`seat_share_milli` with the kit: the first seat two parts, the remainder too; the shares add up exactly."""
	assert_equal(Rules.ask_with_kit(2, true), 12000, "a basket and the kit's two")
	assert_equal(Rules.ask_with_kit(2, false), 8000, "two baskets")
	assert_equal(Rules.seat_share_milli(12000, 2, 0, true), 8000, "the kit's carrier")
	assert_equal(Rules.seat_share_milli(12000, 2, 1, true), 4000, "the other")
	var total: int = 0
	for seat: int in 3:
		total += Rules.seat_share_milli(10001, 3, seat, true)
	assert_equal(total, 10001, "the shares add up")
	assert_equal(Rules.seat_share_milli(10001, 3, 1, true), 2500, "one part each")
	assert_equal(Rules.seat_share_milli(9000, 3, 2, false), 3000, "no kit: equal")


func test_permission_and_the_clock() -> void:
	"""REQ-SET-067 asks permission from danger 2 (the demo's woods are 1); the clock prints hours and minutes."""
	assert_false(Rules.needs_permission(Rules.NATURAL_DANGER), "danger 1: none")
	assert_true(Rules.needs_permission(2), "danger 2")
	assert_equal(Rules.clock_text(15000), "20:00", "dusk")
	assert_equal(Rules.clock_text(15000 + 375), "20:30", "half past")
	assert_equal(Rules.clock_text(SimClock.TICKS_PER_DAY + 750), "01:00", "past midnight wraps")


# --- home before dark ----------------------------------------------------------------------------------------------------

func test_no_trip_goes_out_at_night_or_too_late() -> void:
	"""Authorised at night: refused till dawn; at 19:00 to the far beech hollow: refused, it could not be back by dusk;
	at 08:00: allowed, home by about a time before dusk."""
	var night: Rig = _rig(SUMMER_DAY, 21)
	assert_true(night.trips.order_trip(HERBS, 1, PackedInt32Array()).contains("it is night"), "night")
	var late: Rig = _rig(SUMMER_DAY, 19)
	var far: int = late.trips.walk_home_ticks(MUSHROOMS)
	assert_true(2 * far > SimClock.TICKS_PER_HOUR, "the beech hollow is over half an hour's walk away")
	assert_true(late.trips.daylight_refusal(MUSHROOMS).contains("too late"), late.trips.daylight_refusal(MUSHROOMS))
	var morning: Rig = _rig(SUMMER_DAY, 8)
	assert_equal(morning.trips.daylight_refusal(MUSHROOMS), "", "the morning")
	assert_true(morning.trips.home_by_text(MUSHROOMS, 2, false).begins_with("home by about 1"),
		morning.trips.home_by_text(MUSHROOMS, 2, false))


func test_a_forager_turns_back_for_the_dark() -> void:
	"""Authorised in the morning, its forager reaches the spot as dusk nears: it turns back with nothing claimed or held,
	the news says why, and the trip ends with nothing home (no note)."""
	var rig: Rig = _rig(SUMMER_DAY, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "authorised")
	rig.calendar.tick = tick_at(SUMMER_DAY, 20) - t.walk_home_ticks(HERBS) - 2
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "over")
	assert_equal(t.driver.open_claims(), 0, "nothing claimed")
	assert_false(rig.pantry.is_hold(0), "no room held")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 0, "nothing home")
	assert_true(rig.said[rig.said.size() - 1].contains("turned back") and rig.said[rig.said.size() - 1].contains("dusk"),
		rig.said[rig.said.size() - 1])
	assert_equal(t.note_line(HERBS), "", "a turned-back trip leaves no note")


func test_a_late_forager_gathers_only_what_daylight_allows() -> void:
	"""At the spot with 150 ticks of daylight past its walk home: it may gather only what that allows, under a basket."""
	var rig: Rig = _rig(SUMMER_DAY, 8)
	var t: TripsScript = rig.trips
	assert_equal(t.order_trip(NUTS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_step[0] == TripsScript.S_GATHER), "at the hazel brake")
	assert_equal(t.j_claimed[0], 4000, "a full basket in the morning")
	var wpu: int = t.driver.work_per_u_wu(ForageCore.PATCH_NUTS, 0)
	rig.calendar.tick = tick_at(SUMMER_DAY, 20) - t.walk_home_ticks(NUTS) - 150
	assert_equal(t.daylight_cap_milli(NUTS, 0), Rules.gatherable_milli(150, wpu, 1000), "150 ticks of gathering")
	assert_true(t.daylight_cap_milli(NUTS, 0) < 4000, "less than a basket")


# --- the kit, the lead and the note --------------------------------------------------------------------------------------

func test_the_kit_goes_with_one_trip_and_its_carrier_brings_two_baskets() -> void:
	"""Summer: with the kit, two foragers bring 12 U of herbs (8 + 4); a second trip may not have it while it is out;
	home, it is free again and the place remembers the trip."""
	var rig: Rig = _rig()
	var t: TripsScript = rig.trips
	assert_equal(t.trip_milli(HERBS, 2, true), 12000, "two baskets and the kit's")
	assert_equal(t.order_outing(HERBS, 2, PackedInt32Array([1, 2]), true, false), "", "authorised with the kit")
	assert_equal(t.kit_trip(), t.first_trip(), "the kit is out")
	assert_true(t.outing_refusal(HERBS, 1, PackedInt32Array(), true, false).contains("carry kit is out"), "not twice")
	assert_equal(t.outing_refusal(HERBS, 1, PackedInt32Array(), false, false), "", "a trip without it may go")
	assert_equal([t.j_share[0], t.j_share[1]], [8000, 4000], "the carrier's two shares")
	assert_true(t.trip_line(t.first_trip()).contains("with the carry kit"), t.trip_line(t.first_trip()))
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HERB), 12000, "12 U of herbs")
	assert_equal(t.kit_trip(), TripsScript.NONE, "the kit is home")
	assert_true(t.note_line(HERBS).contains("12.0 U of herbs"), t.note_line(HERBS))
	assert_true(t.note_line(HERBS).begins_with("Remembered (Y1 Summer 1)"), t.note_line(HERBS))


func test_a_named_lead_is_in_the_news_and_the_note() -> void:
	"""Lead ▸ yes: refused with nobody selected; with residents selected the first leads (the first seat); the news and
	the place's note name them; the next trip's note replaces it (the latest only). Summer: the quota holds both."""
	var rig: Rig = _rig()
	var t: TripsScript = rig.trips
	assert_true(t.order_outing(HERBS, 1, PackedInt32Array(), false, true).contains("select"), "nobody to lead")
	assert_equal(t.order_outing(HERBS, 2, PackedInt32Array([4, 5]), false, true), "", "authorised")
	var lead: String = t.name_of(4)
	assert_equal(t.t_lead[t.first_trip()], 4, "the first selected leads")
	assert_true(t.lead_refusal(PackedInt32Array([4])).contains("another foraging trip"), "a lead out already")
	assert_true(rig.said[rig.said.size() - 1].contains("led by %s" % lead), rig.said[rig.said.size() - 1])
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home")
	assert_true(rig.said[rig.said.size() - 1].contains("led by %s" % lead), rig.said[rig.said.size() - 1])
	assert_true(t.note_line(HERBS).ends_with("led by %s" % lead), t.note_line(HERBS))
	assert_equal(t.order_trip(HERBS, 1, PackedInt32Array([3])), "", "another, nobody named")
	assert_true(_run(rig, func() -> bool: return t.trip_count() == 0), "home again")
	assert_true(t.note_line(HERBS).contains("4.0 U of herbs") and not t.note_line(HERBS).contains("led by"),
		"the latest trip's note only: %s" % t.note_line(HERBS))


# --- the grove's reserve -------------------------------------------------------------------------------------------------

func test_a_protected_grove_keeps_its_reserve() -> void:
	"""The hazel brake in a protected grove: the trips may take only the stock above the floor and a tenth of the
	capacity; out of the grove (the herb bank) the basin's own bound; lifted, the basin's again."""
	var rig: Rig = _rig()
	var t: TripsScript = rig.trips
	var permille: Array[int] = [OrchardRules.GROVE_RESERVE_PERMILLE]
	t.reserve_permille = func(at: Vector2) -> int: return permille[0] if OrchardRules.grove_of(at) == 0 else 0
	var kind: int = ForageCore.PATCH_NUTS
	@warning_ignore("integer_division") var reserve: int = t.driver.capacity_milli(kind) / 10
	assert_equal(t.reserve_milli(NUTS), reserve, "a tenth of the capacity")
	assert_equal(t.reserve_milli(HERBS), 0, "no grove at the herb bank")
	var above: int = t.driver.stock_milli(kind) - t.driver.floor_milli(kind) - reserve
	assert_equal(t.harvestable_milli(NUTS), mini(above, t.driver.harvestable_milli(kind)), "the reserve kept")
	assert_equal(t.harvestable_milli(HERBS), t.driver.harvestable_milli(ForageCore.PATCH_HERB), "the basin's own bound")
	permille[0] = 0
	assert_equal(t.harvestable_milli(NUTS), t.driver.harvestable_milli(kind), "lifted")


func test_the_reserve_stops_a_trip_and_says_so() -> void:
	"""A reserve above the stock: nothing may be taken, and the refusal names the grove's share above the floor; a seat's
	claim counts against what is left."""
	var rig: Rig = _rig()
	var t: TripsScript = rig.trips
	var permille: Array[int] = [900]
	t.reserve_permille = func(at: Vector2) -> int: return permille[0] if OrchardRules.grove_of(at) == 0 else 0
	assert_equal(t.harvestable_milli(NUTS), 0, "all of it kept")
	assert_true(t.trip_refusal(NUTS, 1).contains("in the protected grove"), t.trip_refusal(NUTS, 1))
	permille[0] = OrchardRules.GROVE_RESERVE_PERMILLE
	assert_true(t.nothing_left_words(NUTS).contains("in the protected grove"), t.nothing_left_words(NUTS))
	assert_false(t.nothing_left_words(HERBS).contains("grove"), "the herb bank has none")
	var before: int = t.harvestable_milli(NUTS)
	assert_equal(t.order_trip(NUTS, 1, PackedInt32Array([3])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return t.j_claimed[0] > 0), "claimed")
	assert_equal(t.claimed_milli(NUTS), 4000, "the seat's claim")
	assert_true(t.harvestable_milli(NUTS) <= before - 4000, "counted against what is left")


func test_the_section_shows_the_outing() -> void:
	"""The section's note line and its Kit and Lead buttons; the node steps them and authorises the outing."""
	var section: SectionScript = _keep(SectionScript.new()) as SectionScript
	section.build(280.0)
	section.show_outing("Remembered: 8.0 U", true, false)
	assert_equal(section.line(&"note"), "Remembered: 8.0 U", "the note")
	assert_equal([section.button(SectionScript.ACTION_KIT).text, section.button(SectionScript.ACTION_LEAD).text],
		["Kit ▸ yes", "Lead ▸ no"], "the choices")
	section.show_outing("", false, true)
	assert_equal([section.button(SectionScript.ACTION_KIT).text, section.button(SectionScript.ACTION_LEAD).text],
		["Kit ▸ no", "Lead ▸ yes"], "changed")
	var node := ForageNode.new()
	node.on_action(SectionScript.ACTION_KIT)
	node.on_action(SectionScript.ACTION_LEAD)
	assert_true(node.choice_kit and node.choice_lead, "both stepped")
	node.on_action(SectionScript.ACTION_KIT)
	assert_false(node.choice_kit, "and back")
	node.free()
