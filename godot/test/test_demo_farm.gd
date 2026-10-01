extends "res://test/framework/test_case.gd"
## The live demo's farm model (decision 0196): the ingredient catalog and its library joins, the farm
## calendar, the demo weather overlay, the real FarmPlot rows driven through farm_sim.gd (growth,
## ripening, harvest yield, rotation, frost, cover, raised beds, blight and its spread, clearing,
## compost, drainage, irrigation, banking), the pantry's lots and §5.8 spoilage over injected
## storage providers, the tunnel integration and the job board.
##
## No scene tree and no staged assets. Every expected value is a literal worked by hand from the
## cited constants: §5.6 (growth hours, 6 U roots yield, fertility 7000 -> factor 850, frost 1000/h
## grain and 300/h roots, blight 400/200), §5.10 spring +600 moisture/day, §5.8 store factors, and
## the demo values named in each module.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const VillageWaterScript := preload("res://demo/village_water.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

## Demo microseconds per farm hour (demo_calendar.HOUR_USEC), written out.
const HOUR_USEC: int = 2500000
const RADISH: int = 0
const CARROT: int = 2
const CABBAGE: int = 6
const LETTUCE: int = 7
const PEA: int = 11
const WHEAT: int = 13
## Beds: 0 cabbage_w (loam), 1 cabbage_e (clay), 2 roots_w (sand, carrots), 3 roots_e (loam,
## radish), 4 grain_w (clay), 5 grain_e (loam, wheat).
const BED_EMPTY_LOAM: int = 0
const BED_EMPTY_CLAY: int = 1
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_EMPTY_CLAY_2: int = 4
const BED_WHEAT: int = 5

var _read: IntMath.IntResult = IntMath.IntResult.new()


func _hours(sim: SimScript, hours: int) -> void:
	"""Run the farm `hours` game hours of demo time."""
	sim.advance_usec(hours * HOUR_USEC)


func _sow(sim: SimScript, bed: int, item: int) -> void:
	"""Choose and sow `item` in `bed` now (both halves of the sowing)."""
	sim.choose(bed, item)
	assert_true(sim.sow_start(bed).ok and sim.sow_finish(bed).ok, "sown in bed %d" % bed)


func _set_moisture(sim: SimScript, bed: int, value: int) -> void:
	"""Put a bed's moisture at `value` (a fixture)."""
	sim.farming().apply_moisture_delta(sim.slot_of(bed), value - sim.moisture_of(bed))


func _json(path: String) -> Variant:
	"""Parse a JSON file (res://)."""
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# --- catalog ----------------------------------------------------------------------------------

func test_every_item_is_a_pantry_leaf_with_a_crop_row() -> void:
	"""Sixteen ingredients, each a pantry LEAF in the committed index (same order), each on one of
	the four food rows of §5.6 -- never flax."""
	var index: Dictionary = _json("res://demo/farm/pantry_index.json")
	var items: Array = index["items"]
	assert_equal(Catalog.ITEM_COUNT, 16, "sixteen ingredients")
	assert_equal(items.size(), 16, "the index lists them all")
	assert_equal(index["activation"], "NOT_RUNTIME_ACTIVE", "the library stays inactive")
	for item: int in Catalog.ITEM_COUNT:
		assert_equal(String((items[item] as Dictionary)["leaf_id"]), Catalog.ITEM_LEAVES[item], "leaf %d" % item)
		assert_true(Catalog.ITEM_CROP[item] != FarmingScript.CROP_FLAX, "no fibre crop")
	assert_equal(Catalog.ITEM_LABELS.size(), 16, "labels")
	assert_equal(Catalog.ITEM_VISUAL.size(), 16, "visuals")
	assert_equal(Catalog.ITEM_TINT.size(), 16, "tints")
	assert_equal(Catalog.ITEM_RIPE_HEADS.size(), 16, "ripe heads")


func test_families_follow_the_crop_rows() -> void:
	"""Radish is a ROOT (4), lettuce LEAF (2), pea LEGUME (3), wheat CEREAL (0) -- the catalog ids."""
	assert_equal(Catalog.family_of(RADISH), 4, "radish: root")
	assert_equal(Catalog.family_of(LETTUCE), 2, "lettuce: leaf")
	assert_equal(Catalog.family_of(PEA), 3, "pea: legume")
	assert_equal(Catalog.family_of(WHEAT), 0, "wheat: cereal")
	assert_equal(Catalog.crop_of(CARROT), FarmingScript.CROP_ROOTS, "carrot grows as roots")


func test_shelf_hours_match_the_item_catalog() -> void:
	"""§5.7's shelf hours by row agree with data/item_definitions.json: beans 480, cabbage 144,
	grain 720, roots 240."""
	var data: Dictionary = _json("res://data/item_definitions.json")
	var shelf: Dictionary = {}
	for row: Dictionary in data["items"]:
		shelf[row["id"]] = int(row["shelf_hours"])
	for crop: int in FarmingScript.CROP_COUNT:
		assert_equal(Catalog.CROP_SHELF_HOURS[crop], shelf[String(Catalog.CROP_ITEM_ID[crop])], "row %d" % crop)
	assert_equal(Catalog.shelf_hours_of(CARROT), 240, "carrots keep 240 h")
	assert_equal(Catalog.shelf_hours_of(LETTUCE), 144, "lettuce 144 h")
	assert_equal(Catalog.shelf_hours_of(PEA), 480, "peas 480 h")
	assert_equal(Catalog.shelf_hours_of(WHEAT), 720, "wheat 720 h")


func test_beds_are_the_world_crop_beds_with_their_neighbours() -> void:
	"""Each bed is a world crop id; neighbours are the beds within 4 m (3.2 m across, 3.6 m along)."""
	for bed: int in Catalog.BED_COUNT:
		assert_true(Catalog.bed_centre_m(bed).is_finite(), "bed %d is a world crop" % bed)
	assert_equal(Catalog.bed_centre_m(BED_CARROTS), Vector2(-12.6, 12.8), "roots_w")
	assert_equal(Catalog.neighbours_of(0), PackedInt32Array([1, 2]), "cabbage_w: across and down")
	assert_equal(Catalog.neighbours_of(3), PackedInt32Array([1, 2, 5]), "roots_e: three, not the diagonal")


func test_a_bed_is_found_under_a_point() -> void:
	"""The 3 m bed square is 1.5 m each side of its centre; off it the lookup refuses."""
	assert_true(Catalog.bed_at_into(Vector2(-11.2, 9.2), _read), "1.4 m in")
	assert_equal(_read.value, 0, "cabbage_w")
	assert_false(Catalog.bed_at_into(Vector2(-11.05, 9.2), _read), "1.55 m out")
	assert_false(Catalog.bed_at_into(Vector2(-12.6, 11.0), _read), "between the rows, 1.8 m from both")
	assert_equal(_read.error, Catalog.REFUSE_NO_BED, "refused")


# --- calendar and weather ---------------------------------------------------------------------

func test_the_calendar_turns_demo_microseconds_into_ticks_exactly() -> void:
	"""2.5 s is 750 ticks; a microsecond carries 750 over; 3333 more brings one tick, 500 over."""
	var calendar := CalendarScript.new()
	assert_equal(calendar.ticks_for_usec(HOUR_USEC), 750, "an hour")
	assert_equal(calendar.ticks_for_usec(1), 0, "a microsecond: no tick")
	assert_equal(calendar.remainder(), 750, "but kept")
	assert_equal(calendar.ticks_for_usec(3333), 1, "carried over")
	assert_equal(calendar.remainder(), 500, "the rest kept")
	assert_equal(calendar.ticks_for_usec(-5), 0, "never backwards")


func test_hour_crossings_follow_the_offset_calendar() -> void:
	"""After tick 0 the first crossing is 750; after 750, 1500; the first midnight is 13500."""
	assert_equal(CalendarScript.next_hour_crossing(0), 750, "from 06:00")
	assert_equal(CalendarScript.next_hour_crossing(749), 750, "just before")
	assert_equal(CalendarScript.next_hour_crossing(750), 1500, "strictly after")
	assert_equal(CalendarScript.next_hour_crossing(13499), 13500, "midnight")
	assert_true(CalendarScript.is_day_boundary(13500), "is a day boundary")
	assert_false(CalendarScript.is_day_boundary(18000), "06:00 is not")


func test_frost_nights_and_outbreaks_are_on_their_days() -> void:
	"""Spring's one frost night is the night into spring 11 (no longer 4 and 9), autumn's 3 and 8; the
	outbreaks open spring 12 (no longer 7), summer 4 and 10, autumn 6; winter needs neither."""
	assert_true(Weather.is_frost_night(0, 11), "spring 11")
	assert_false(Weather.is_frost_night(0, 4), "not spring 4")
	assert_false(Weather.is_frost_night(0, 9), "not spring 9")
	assert_false(Weather.is_frost_night(0, 10), "spring 10")
	assert_false(Weather.is_frost_night(0, 12), "spring 12")
	assert_true(Weather.is_frost_night(2, 3), "autumn 3")
	assert_true(Weather.is_frost_night(2, 8), "autumn 8")
	assert_false(Weather.is_frost_night(1, 4), "never summer")
	assert_false(Weather.is_frost_night(0, 13), "no day 13")
	assert_true(Weather.is_blight_outbreak(0, 12), "spring 12")
	assert_false(Weather.is_blight_outbreak(0, 7), "not spring 7")
	assert_false(Weather.is_blight_outbreak(0, 11), "not spring 11")
	assert_true(Weather.is_blight_outbreak(1, 4), "summer 4")
	assert_true(Weather.is_blight_outbreak(1, 10), "summer 10")
	assert_true(Weather.is_blight_outbreak(2, 6), "autumn 6")
	assert_false(Weather.is_blight_outbreak(3, 6), "not winter")


func test_a_frost_night_is_the_early_hours() -> void:
	"""Hours 2-5 of a frost day freeze; 1 and 6 do not; tonight means tomorrow's early hours."""
	assert_false(Weather.is_frost_hour(0, 11, 1), "01:00")
	assert_true(Weather.is_frost_hour(0, 11, 2), "02:00")
	assert_true(Weather.is_frost_hour(0, 11, 5), "05:00")
	assert_false(Weather.is_frost_hour(0, 11, 6), "06:00")
	assert_false(Weather.is_frost_hour(0, 10, 3), "not the night before")
	assert_true(Weather.frost_tonight(0, 10), "the evening before")
	assert_false(Weather.frost_tonight(0, 3), "spring 3 -> 4 is no longer a frost night")
	assert_false(Weather.frost_tonight(0, 12), "spring 12 -> summer 1")
	assert_true(Weather.frost_tonight(2, 2), "autumn 2 -> 3")
	assert_equal(Weather.next_day(0, 12), Vector2i(1, 1), "spring 12 -> summer 1")
	assert_equal(Weather.next_day(3, 12), Vector2i(0, 1), "winter 12 -> spring 1")
	assert_equal(Weather.next_day(1, 5), Vector2i(1, 6), "summer 5 -> 6")


func test_a_frost_is_due_from_its_warning_to_its_last_hour() -> void:
	"""Straw still helps from ALERT_HOUR (12:00) the day before a frost night until 05:59 of it."""
	assert_false(Weather.frost_due(0, 10, 11), "spring 10, 11:00: not yet announced")
	assert_true(Weather.frost_due(0, 10, 12), "12:00: announced")
	assert_true(Weather.frost_due(0, 10, 23), "23:00")
	assert_true(Weather.frost_due(0, 11, 0), "midnight into the frost night")
	assert_true(Weather.frost_due(0, 11, 5), "05:00, the last frost hour")
	assert_false(Weather.frost_due(0, 11, 6), "06:00: over")
	assert_false(Weather.frost_due(0, 11, 12), "noon after: no frost the next night")
	assert_false(Weather.frost_due(0, 9, 12), "two days before")
	assert_true(Weather.frost_due(2, 2, 12), "autumn 2 noon")


func test_bed_temperature_takes_frost_cover_and_raising() -> void:
	"""-3 C at night (unless colder); straw +4 C, raised +3 C."""
	assert_equal(Weather.air_tenths(120, true), -30, "a spring frost night")
	assert_equal(Weather.air_tenths(-50, true), -50, "winter is colder already")
	assert_equal(Weather.air_tenths(120, false), 120, "no frost")
	assert_equal(Weather.bed_tenths(-30, true, false), 10, "covered")
	assert_equal(Weather.bed_tenths(-30, false, true), 0, "raised")
	assert_equal(Weather.bed_tenths(-30, true, true), 40, "both")


# --- the real FarmPlot rows ----------------------------------------------------------------------

func test_the_farm_opens_with_its_history() -> void:
	"""Carrots 96 of 120 h (800 permille), radish 36 h (300), wheat 60 of 192 h (312); the rest empty;
	every bed at §5.1's 6000 moisture and 7000 fertility."""
	var sim := SimScript.new()
	assert_equal(sim.growth_permille(BED_CARROTS), 800, "carrots")
	assert_equal(sim.growth_permille(BED_RADISH), 300, "radish")
	assert_equal(sim.growth_permille(BED_WHEAT), 312, "wheat")
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_GROWING, "growing")
	assert_equal(sim.stage_of(BED_RADISH), SimScript.STAGE_GROWING, "300 permille is past sprouting")
	assert_equal(sim.stage_of(BED_EMPTY_LOAM), SimScript.STAGE_EMPTY, "empty")
	assert_equal(sim.item_of(BED_CARROTS), CARROT, "carrots stand")
	assert_equal(sim.moisture_of(BED_EMPTY_LOAM), 6000, "moisture")
	assert_equal(sim.fertility_of(BED_CARROTS), 7000, "fertility")
	assert_equal(sim.absolute_day(), 1, "day 1")
	assert_equal(sim.band_of(BED_CARROTS), SimScript.BAND_GOOD, "6000 is inside roots' 2500-7000")


func test_a_day_runs_real_weather_and_ripens_the_carrots() -> void:
	"""24 hours: 24 crossings, one midnight (+600 spring moisture), and carrots at 120 h ripen, logged."""
	var sim := SimScript.new()
	assert_equal(sim.advance_usec(24 * HOUR_USEC), 24, "24 crossings")
	assert_equal(sim.absolute_day(), 2, "day 2")
	assert_equal(sim.calendar.tick, 18000, "06:00 of day 2")
	assert_equal(sim.moisture_of(BED_EMPTY_LOAM), 6600, "spring +600")
	assert_equal(sim.last_weather_delta(), 600, "the weather's own delta")
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_RIPE, "ripe")
	assert_equal(sim.growth_permille(BED_CARROTS), 1000, "full")
	var events := PackedInt32Array()
	assert_equal(sim.take_events_into(events), 1, "one event")
	assert_equal(events, PackedInt32Array([SimScript.EVENT_RIPENED, BED_CARROTS]), "the carrots ripened")
	assert_equal(sim.hours_run, 24, "hours")
	assert_equal(sim.days_run, 1, "days")


func test_a_harvest_yields_the_formula_and_costs_fertility() -> void:
	"""6000 x 850 x 1000 x 1000 x 1000 / 10^12 = 5100 milli-U; fertility 7000 - 700 = 6300; the bed
	is empty and holds no item; its chosen crop is kept."""
	var sim := SimScript.new()
	_hours(sim, 24)
	assert_true(sim.expected_yield_into(BED_CARROTS, _read), "a ripe yield")
	assert_equal(_read.value, 5100, "expected")
	var cut: FarmingScript.OpResult = sim.harvest(BED_CARROTS)
	assert_true(cut.ok, "harvested")
	assert_equal(cut.value, 5100, "5.1 U of carrots")
	assert_equal(sim.fertility_of(BED_CARROTS), 6300, "roots cost 700")
	assert_equal(sim.stage_of(BED_CARROTS), SimScript.STAGE_EMPTY, "empty")
	assert_equal(sim.item_of(BED_CARROTS), SimScript.NO_ITEM, "no item")
	assert_false(sim.harvest(BED_CARROTS).ok, "nothing left to harvest")


func test_rotation_preview_is_the_real_rule() -> void:
	"""After a root harvest: roots again 850, a legume 1100, a cereal 1000 -- and the preview for
	radish equals rotation_factor_of() once the radish is sown."""
	var sim := SimScript.new()
	_hours(sim, 24)
	sim.harvest(BED_CARROTS)
	assert_equal(sim.rotation_preview(BED_CARROTS, CARROT), 850, "second root harvest")
	assert_equal(sim.rotation_preview(BED_CARROTS, PEA), 1100, "a legume after a change")
	assert_equal(sim.rotation_preview(BED_CARROTS, WHEAT), 1000, "a change")
	assert_equal(sim.rotation_preview(BED_EMPTY_LOAM, PEA), 1000, "a legume as a first crop")
	sim.choose(BED_CARROTS, RADISH)
	assert_true(sim.sow_start(BED_CARROTS).ok, "radish sown on sand in spring")
	var actual: IntMath.IntResult = sim.farming().rotation_factor_of(sim.slot_of(BED_CARROTS))
	assert_equal(actual.value, 850, "the store agrees")


func test_sowing_is_gated_by_fallow_soil_and_window() -> void:
	"""Sand refuses wheat; clay refuses radish; peas wait for spring 5; a fallow bed refuses; a sown
	bed refuses a second sowing."""
	var sim := SimScript.new()
	assert_equal(sim.sow_refusal(BED_CARROTS, WHEAT), FarmingScript.REFUSE_NOT_EMPTY, "carrots stand")
	assert_equal(sim.sow_refusal(BED_EMPTY_CLAY, RADISH), FarmingScript.REFUSE_SOIL_INCOMPATIBLE, "clay")
	assert_equal(sim.sow_refusal(BED_EMPTY_LOAM, PEA), FarmingScript.REFUSE_OUTSIDE_PLANT_WINDOW, "peas: spring 5-10")
	assert_equal(sim.sow_refusal(BED_EMPTY_LOAM, CABBAGE), FarmingScript.REFUSE_OUTSIDE_PLANT_WINDOW, "cabbage: summer")
	assert_equal(sim.sow_refusal(BED_EMPTY_LOAM, WHEAT), SimScript.REFUSE_NONE, "wheat on loam, spring 1")
	sim.set_fallow(BED_EMPTY_LOAM, true)
	assert_equal(sim.sow_refusal(BED_EMPTY_LOAM, WHEAT), SimScript.REFUSE_FALLOW, "resting")
	assert_false(sim.sow_start(BED_EMPTY_CLAY).ok, "nothing chosen")
	assert_equal(sim.sow_start(BED_EMPTY_CLAY).error, SimScript.REFUSE_NO_ITEM, "says so")
	assert_false(sim.choose(BED_EMPTY_CLAY, 16).ok, "not an item")
	assert_false(sim.choose(6, WHEAT).ok, "not a bed")


func test_sowing_starts_and_finishes() -> void:
	"""Productive start makes the bed SOWN with the item standing; completion makes it grow."""
	var sim := SimScript.new()
	sim.choose(BED_EMPTY_LOAM, WHEAT)
	assert_true(sim.sow_start(BED_EMPTY_LOAM).ok, "seed committed")
	assert_equal(sim.stage_of(BED_EMPTY_LOAM), SimScript.STAGE_SOWN, "sown")
	assert_equal(sim.item_of(BED_EMPTY_LOAM), WHEAT, "wheat stands")
	assert_true(sim.sow_finish(BED_EMPTY_LOAM).ok, "sowing done")
	assert_equal(sim.stage_of(BED_EMPTY_LOAM), SimScript.STAGE_SPROUTING, "sprouting at 0")
	assert_true(sim.hours_to_ripe_into(BED_EMPTY_LOAM, _read), "a rate")
	assert_equal(_read.value, 192, "192 h at 12 C and 6000 moisture")


func test_a_frost_night_hurts_growing_crops_unless_covered() -> void:
	"""Spring 11, 02:00-05:59, -3 C: wheat sown on spring 1 loses 4 x 1000; the same wheat covered on
	the evening of spring 10 loses nothing; the opening wheat, ripe since spring 8, is past frost. The
	straw is gone at 06:00."""
	var sim := SimScript.new()
	_sow(sim, BED_EMPTY_CLAY, WHEAT)
	_sow(sim, BED_EMPTY_CLAY_2, WHEAT)
	_hours(sim, 24 * 9 + 12)
	assert_true(sim.cover(BED_EMPTY_CLAY_2).ok, "covered on the evening of spring 10")
	assert_false(sim.cover(BED_EMPTY_CLAY_2).ok, "once")
	_hours(sim, 12)
	assert_equal(sim.calendar.tick, 180000, "06:00 of spring 11")
	assert_equal(sim.health_of(BED_EMPTY_CLAY), 6000, "wheat lost 4000")
	assert_equal(sim.health_of(BED_EMPTY_CLAY_2), 10000, "the covered wheat lost nothing")
	assert_equal(sim.stage_of(BED_WHEAT), SimScript.STAGE_RIPE, "the opening wheat is ripe")
	assert_equal(sim.health_of(BED_WHEAT), 10000, "and past frost")
	assert_false(sim.is_covered(BED_EMPTY_CLAY_2), "the straw came off at 06:00")


func test_a_raised_bed_is_frost_free_at_minus_three() -> void:
	"""Raised: -3 C + 3 C = 0 C, not below freezing: no damage. The wheat beside it loses 4 x 1000."""
	var sim := SimScript.new()
	_sow(sim, BED_EMPTY_CLAY, WHEAT)
	_sow(sim, BED_EMPTY_CLAY_2, WHEAT)
	assert_true(sim.raise_bed(BED_EMPTY_CLAY_2).ok, "raised")
	assert_false(sim.raise_bed(BED_EMPTY_CLAY_2).ok, "once")
	_hours(sim, 24 * 10)
	assert_equal(sim.health_of(BED_EMPTY_CLAY_2), 10000, "no frost damage")
	assert_equal(sim.health_of(BED_EMPTY_CLAY), 6000, "the unraised wheat lost 4000")


func test_blight_damages_daily_halves_when_tended_and_spreads() -> void:
	"""Blighted wheat: 400 at the first midnight; watered the next day, 200; then it spreads to the
	growing radish beside it (not the empty clay bed), logged."""
	var sim := SimScript.new()
	sim.infect_for_test(BED_WHEAT)
	assert_equal(sim.stage_of(BED_WHEAT), SimScript.STAGE_BLIGHTED, "shows blighted")
	_hours(sim, 18)
	assert_equal(sim.health_of(BED_WHEAT), 9600, "400")
	assert_false(sim.is_blighted(BED_RADISH), "not spread yet")
	assert_true(sim.water(BED_WHEAT).ok, "tended")
	assert_true(sim.is_tended_today(BED_WHEAT), "marked")
	_hours(sim, 24)
	assert_equal(sim.health_of(BED_WHEAT), 9400, "200 while tended")
	assert_true(sim.is_blighted(BED_RADISH), "spread to the radish")
	assert_false(sim.is_blighted(BED_EMPTY_CLAY_2), "an empty bed cannot catch it")
	var events := PackedInt32Array()
	sim.take_events_into(events)
	assert_true(events.has(SimScript.EVENT_BLIGHT_SPREAD), "logged")


func test_clearing_a_blighted_crop_uproots_it_for_compost() -> void:
	"""Clear refuses an empty bed; on blighted wheat it withers and clears it: +500 compost."""
	var sim := SimScript.new()
	assert_equal(sim.clear_refusal(BED_EMPTY_LOAM), SimScript.REFUSE_NOTHING_TO_CLEAR, "nothing")
	assert_equal(sim.clear_refusal(BED_WHEAT), SimScript.REFUSE_NOTHING_TO_CLEAR, "healthy wheat")
	sim.infect_for_test(BED_WHEAT)
	var cleared: FarmingScript.OpResult = sim.clear(BED_WHEAT)
	assert_true(cleared.ok, "cleared")
	assert_equal(cleared.value, 500, "REQ-SET-085's 0.5 U")
	assert_equal(sim.compost_milli, 4500, "4 U + 0.5")
	assert_equal(sim.stage_of(BED_WHEAT), SimScript.STAGE_EMPTY, "empty")
	assert_false(sim.is_blighted(BED_WHEAT), "clean")


func test_compost_takes_two_units_once_a_season() -> void:
	"""From the store: +1500 fertility (7000 -> 8500), the store 4 U -> 2 U; a second time the tile
	refuses; with 1.9 U in the store another bed refuses -- and nothing else can bring it (decision 0401)."""
	var sim := SimScript.new()
	assert_true(sim.compost(BED_EMPTY_LOAM).ok, "composted")
	assert_equal(sim.fertility_of(BED_EMPTY_LOAM), 8500, "+1500")
	assert_equal(sim.compost_milli, 2000, "2 U used")
	assert_equal(sim.compost(BED_EMPTY_LOAM).error, FarmingScript.REFUSE_COMPOST_NOT_ELIGIBLE, "once a season")
	sim.compost_milli = 1900
	assert_equal(sim.compost_refusal(BED_EMPTY_CLAY), SimScript.REFUSE_NO_COMPOST, "short")
	assert_equal(sim.compost(BED_EMPTY_CLAY).error, SimScript.REFUSE_NO_COMPOST, "refused")
	assert_equal(sim.fertility_of(BED_EMPTY_CLAY), 7000, "no fertility without the store's compost")
	assert_equal(sim.compost_milli, 1900, "the store untouched")


func test_tunnels_drain_irrigate_and_spoil_raises() -> void:
	"""After the first midnight (+600 to 6600): drained -> 6600 - 1500 = 5100 (toward 4500); irrigated
	-> pulled to the 6000 middle; raised -> 6600 - 800 = 5800; plain 6600."""
	var sim := SimScript.new()
	sim.set_tunnel_water(BED_EMPTY_LOAM, true, false)
	sim.set_tunnel_water(BED_EMPTY_CLAY, false, true)
	sim.raise_bed(BED_EMPTY_CLAY_2)
	_hours(sim, 18)
	assert_equal(sim.moisture_of(BED_EMPTY_LOAM), 5100, "drained")
	assert_equal(sim.moisture_of(BED_EMPTY_CLAY), 6000, "irrigated")
	assert_equal(sim.moisture_of(BED_EMPTY_CLAY_2), 5800, "raised")
	assert_equal(sim.moisture_of(BED_CARROTS), 6600, "plain")
	assert_true(sim.is_drained(BED_EMPTY_LOAM), "drained flag")
	assert_true(sim.is_irrigated(BED_EMPTY_CLAY), "irrigated flag")


func test_drainage_stops_at_the_low_side_and_irrigation_lifts_a_dry_bed() -> void:
	"""Drained from 4800: +600 to 5400, then down to 4000 + 500 = 4500 (not the full 1500). Irrigated
	from 2000: +600 to 2600, then up by the full 1500 to 4100. Raised AND irrigated: the irrigation
	holds it at the 6000 middle and the raising does not drain it."""
	var sim := SimScript.new()
	var farming: FarmingScript = sim.farming()
	farming.apply_moisture_delta(sim.slot_of(BED_EMPTY_LOAM), 4800 - 6000)
	farming.apply_moisture_delta(sim.slot_of(BED_EMPTY_CLAY), 2000 - 6000)
	sim.set_tunnel_water(BED_EMPTY_LOAM, true, false)
	sim.set_tunnel_water(BED_EMPTY_CLAY, false, true)
	sim.set_tunnel_water(BED_EMPTY_CLAY_2, false, true)
	sim.raise_bed(BED_EMPTY_CLAY_2)
	_hours(sim, 18)
	assert_equal(sim.moisture_of(BED_EMPTY_LOAM), 4500, "drained to the low side")
	assert_equal(sim.moisture_of(BED_EMPTY_CLAY), 4100, "irrigated up")
	assert_equal(sim.moisture_of(BED_EMPTY_CLAY_2), 6000, "held at the middle")


func test_an_empty_bed_rests_back_its_fertility() -> void:
	"""REQ-SET-078: an empty bed gains 50 fertility a day without a worker; a sown one does not."""
	var sim := SimScript.new()
	sim.compost(BED_EMPTY_LOAM)
	assert_equal(sim.fertility_of(BED_EMPTY_LOAM), 8500, "composted")
	_hours(sim, 18)
	assert_equal(sim.fertility_of(BED_EMPTY_LOAM), 8550, "+50 at midnight")
	assert_equal(sim.fertility_of(BED_CARROTS), 7000, "a growing bed does not rest")


func test_every_visible_change_moves_the_revision() -> void:
	"""An hour, a verb that took, and a tunnel change move it; the same tunnel state again does not."""
	var sim := SimScript.new()
	var seen: int = sim.revision
	_hours(sim, 1)
	assert_true(sim.revision > seen, "an hour")
	seen = sim.revision
	sim.water(BED_WHEAT)
	assert_true(sim.revision > seen, "watering")
	seen = sim.revision
	sim.set_tunnel_water(BED_WHEAT, true, false)
	assert_true(sim.revision > seen, "drained")
	seen = sim.revision
	sim.set_tunnel_water(BED_WHEAT, true, false)
	assert_equal(sim.revision, seen, "unchanged")
	assert_false(sim.harvest(BED_WHEAT).ok, "a refused verb")
	assert_equal(sim.revision, seen, "changes nothing")


func test_a_banked_bed_keeps_half_of_a_dry_day() -> void:
	"""Into summer (-600 a day): the banked bed keeps 300 of it; the unbanked loses it all."""
	var sim := SimScript.new()
	sim.bank_bed(BED_EMPTY_LOAM)
	assert_false(sim.bank_bed(BED_EMPTY_LOAM).ok, "once")
	_hours(sim, 18 + 24 * 12)
	var delta: int = sim.last_weather_delta()
	assert_equal(sim.season(), 1, "summer")
	assert_true(delta < 0, "summer dries")
	var before_banked: int = sim.moisture_of(BED_EMPTY_LOAM)
	var before_plain: int = sim.moisture_of(BED_EMPTY_CLAY)
	_hours(sim, 24)
	delta = sim.last_weather_delta()
	assert_equal(before_plain + delta, sim.moisture_of(BED_EMPTY_CLAY), "plain: the weather's delta")
	assert_equal(before_banked + delta - delta / 2, sim.moisture_of(BED_EMPTY_LOAM), "banked: half back")


func test_every_bed_sheds_down_toward_its_band_s_top() -> void:
	"""At midnight (+600): a radish bed at 9800 goes to 10000 (the clamp) and sheds the full 500 to
	9500; one at 6800 goes to 7400 and sheds only the 400 above 7000; the carrots at 6000 shed none."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_RADISH, 9800)
	_set_moisture(sim, BED_WHEAT, 6800)
	sim.choose(BED_EMPTY_LOAM, RADISH)
	_set_moisture(sim, BED_EMPTY_LOAM, 6800)
	_hours(sim, 18)
	assert_equal(sim.moisture_of(BED_RADISH), 9500, "clamped, then 500 shed")
	assert_equal(sim.moisture_of(BED_EMPTY_LOAM), 7000, "only down to the band's top (roots 7000)")
	assert_equal(sim.moisture_of(BED_WHEAT), 7400, "wheat's band runs to 7500: nothing shed")
	assert_equal(sim.moisture_of(BED_CARROTS), 6600, "inside the band: the weather's +600 only")


func test_draining_drops_a_wet_bed_to_its_band_s_top_and_ditches_it() -> void:
	"""A good bed refuses (NOT_TOO_WET); a wet radish at 7500 drops to 7000 (500 shed); a waterlogged
	one at 9800 drops to 7000 too; the bed is ditched for good and the revision moves."""
	var sim := SimScript.new()
	assert_equal(sim.drain_refusal(BED_RADISH), SimScript.REFUSE_NOT_TOO_WET, "6000 is good")
	assert_false(sim.drain_bed(BED_RADISH).ok, "refused")
	assert_false(sim.is_ditched(BED_RADISH), "no ditch")
	assert_equal(sim.drain_refusal(6), SimScript.REFUSE_NOT_A_BED, "not a bed")
	_set_moisture(sim, BED_RADISH, 7001)
	assert_equal(sim.drain_refusal(BED_RADISH), SimScript.REFUSE_NONE, "7001 is wet")
	_set_moisture(sim, BED_RADISH, 7500)
	var seen: int = sim.revision
	var drained: FarmingScript.OpResult = sim.drain_bed(BED_RADISH)
	assert_true(drained.ok, "drained")
	assert_equal(drained.value, 500, "500 shed")
	assert_equal(sim.moisture_of(BED_RADISH), 7000, "the band's top")
	assert_true(sim.is_ditched(BED_RADISH), "ditched")
	assert_true(sim.revision > seen, "a visible change")
	_set_moisture(sim, BED_RADISH, 9800)
	assert_true(sim.drain_bed(BED_RADISH).ok, "a ditched bed that floods again drains again")
	assert_equal(sim.moisture_of(BED_RADISH), 7000, "to 7000")
	assert_equal(sim.band_of(BED_RADISH), SimScript.BAND_GOOD, "good")


func test_a_ditched_bed_sheds_toward_its_low_side_at_midnight() -> void:
	"""Two roots beds at 7000: the ditched radish +600 -> 7600 - 1000 = 6600, then 6200; the plain
	carrots +600 -> 7600 - 500 natural = 7100. A ditched wheat bed a pond tunnel irrigates is pulled
	toward grain's 5500 middle by irrigation's 1500 only: 7500 + 600 - 1500 = 6600, not 1000 more."""
	var sim := SimScript.new()
	_set_moisture(sim, BED_RADISH, 7500)
	sim.drain_bed(BED_RADISH)
	_set_moisture(sim, BED_CARROTS, 7000)
	_set_moisture(sim, BED_WHEAT, 7600)
	sim.drain_bed(BED_WHEAT)
	sim.set_tunnel_water(BED_WHEAT, false, true)
	_hours(sim, 18)
	assert_equal(sim.moisture_of(BED_RADISH), 6600, "ditched: 1000 shed")
	assert_equal(sim.moisture_of(BED_CARROTS), 7100, "plain: the natural 500")
	assert_equal(sim.moisture_of(BED_WHEAT), 6600, "irrigated: the ditch does not drain it too")
	_hours(sim, 24)
	assert_equal(sim.moisture_of(BED_RADISH), 6200, "the next midnight")


func test_waterlogging_is_read_from_the_bands() -> void:
	"""Radish (2500-7000): 7000 good, 7001 wet, 9001 waterlogged; 2499 low, 499 dry."""
	var sim := SimScript.new()
	var slot: int = sim.slot_of(BED_RADISH)
	var farming: FarmingScript = sim.farming()
	for case: Array in [[7000, SimScript.BAND_GOOD], [7001, SimScript.BAND_WET], [9000, SimScript.BAND_WET],
			[9001, SimScript.BAND_WATERLOGGED], [2500, SimScript.BAND_GOOD], [2499, SimScript.BAND_LOW],
			[500, SimScript.BAND_LOW], [499, SimScript.BAND_DRY]]:
		farming.apply_moisture_delta(slot, int(case[0]) - sim.moisture_of(BED_RADISH))
		assert_equal(sim.band_of(BED_RADISH), int(case[1]), "moisture %d" % case[0])


func test_an_outbreak_takes_a_growing_bed_on_spring_12() -> void:
	"""No outbreak through spring 11; by the midnight opening spring 12 a growing bed (the wheat sown
	on spring 1 -- the opening crops have ripened) has blight, logged as an outbreak."""
	var sim := SimScript.new()
	_sow(sim, BED_EMPTY_CLAY, WHEAT)
	var events := PackedInt32Array()
	_hours(sim, 18 + 24 * 9)
	assert_equal(sim.season_day(), 11, "spring 11")
	sim.take_events_into(events)
	assert_false(_has_event(events, SimScript.EVENT_BLIGHT), "no outbreak yet")
	_hours(sim, 24)
	assert_equal(sim.season_day(), 12, "spring 12")
	events.clear()
	sim.take_events_into(events)
	assert_true(_has_event(events, SimScript.EVENT_BLIGHT), "an outbreak")
	assert_true(sim.is_blighted(BED_EMPTY_CLAY), "on the growing wheat")


func _has_event(events: PackedInt32Array, kind: int) -> bool:
	"""Whether the (kind, bed) pairs hold an event of `kind`."""
	for k: int in range(0, events.size(), 2):
		if events[k] == kind:
			return true
	return false


func test_the_first_spring_spaces_waterlogging_frost_and_blight() -> void:
	"""The first spring walked hour by hour with the real sim and its alerts, as a player might play it
	(wheat sown in the clay bed on spring 1; the carrots harvested and radish sown in their place on
	spring 2): the first waterlogging warning is on spring 8 (the Ideal spell's last day, not spring
	6), the frost warning on spring 10, the outbreak on spring 12 -- distinct days, two apart."""
	var sim := SimScript.new()
	var alerts := AlertsScript.new()
	_sow(sim, BED_EMPTY_CLAY, WHEAT)
	var first := PackedInt32Array([0, 0, 0])
	var lines := PackedStringArray()
	var events := PackedInt32Array()
	for hour: int in 18 + 24 * 11:
		_hours(sim, 1)
		if hour == 23:
			assert_true(sim.harvest(BED_CARROTS).ok, "the carrots harvested on spring 2")
			_sow(sim, BED_CARROTS, RADISH)
		lines.clear()
		events.clear()
		sim.take_events_into(events)
		alerts.collect_into(sim, events, PackedInt32Array(), lines)
		for line: String in lines:
			for k: int in 3:
				if first[k] == 0 and line.contains(["waterlogged", "Frost tonight", "Blight on"][k]):
					first[k] = sim.season_day()
	assert_equal(first, PackedInt32Array([8, 10, 12]), "waterlogging, frost warning, blight")
	assert_true(first[1] - first[0] >= 2 and first[2] - first[1] >= 2, "two days apart at least")


func test_the_opening_radish_waterlogs_only_with_the_ideal_spell() -> void:
	"""Idle, the opening radish bed (roots, 2500-7000) creeps past its band on +600 days against the
	500 natural drainage, and only the Ideal spell's +1200 days waterlog it: wet from spring 4, 9300
	and waterlogged at the midnight opening spring 8 -- the wheat (grain, to 7500) never passes 9500."""
	var sim := SimScript.new()
	var expected: Array[int] = [6600, 7000, 7100, 7200, 7900, 8600, 9300, 9400]
	for day: int in expected.size():
		_hours(sim, 18 if day == 0 else 24)
		assert_equal(sim.moisture_of(BED_RADISH), expected[day], "radish, spring %d" % (day + 2))
		assert_equal(sim.band_of(BED_RADISH) == SimScript.BAND_WATERLOGGED, day + 2 >= 8, "waterlogged? spring %d" % (day + 2))
		assert_true(sim.moisture_of(BED_WHEAT) <= 9500, "the wheat never waterlogs, spring %d" % (day + 2))


# --- storage and the pantry -------------------------------------------------------------------

func _cellar(id: Variant, capacity_u: int, permille: int) -> Dictionary:
	"""One fixture storage entry."""
	return {"id": id, "position": Vector2(1.0, 2.0), "capacity_u": capacity_u,
		"spoilage_permille": permille, "label": "Root cellar"}


func test_storage_starts_with_the_covered_store() -> void:
	"""Location 0: §5.8's covered store at 1000, 400 U, where the store is."""
	var storage := StorageScript.new(Vector2(14.0, 3.0))
	assert_equal(storage.count(), 1, "one place")
	assert_equal(storage.permille_of(0), 1000, "covered store factor")
	assert_equal(storage.capacity_milli_of(0), 400000, "400 U")
	assert_equal(storage.position_of(0), Vector2(14.0, 3.0), "delivered there")
	assert_equal(storage.label_of(0), "Covered store", "named")


func test_providers_add_cellars_and_bad_entries_are_refused() -> void:
	"""A cellar (Vector3 position accepted) joins; a missing id, a zero capacity, a permille of 0 or
	10001, a repeated id, a non-dictionary and a provider returning no array are refused."""
	var storage := StorageScript.new()
	var cellar_3d: Dictionary = _cellar(&"a", 10, 350)
	cellar_3d["position"] = Vector3(5.0, -1.0, 6.0)
	storage.add_provider(func() -> Array: return [cellar_3d, _cellar(&"a", 5, 350), {"position": Vector2.ZERO},
		_cellar(&"b", 0, 350), _cellar(&"c", 3, 0), _cellar(&"d", 3, 10001), 7])
	storage.add_provider(func() -> String: return "nothing")
	assert_equal(storage.count(), 2, "the store and one cellar")
	assert_equal(storage.permille_of(1), 350, "cellar factor")
	assert_equal(storage.position_of(1), Vector2(5.0, 6.0), "x and z")
	assert_equal(storage.capacity_milli_of(1), 10000, "10 U")
	assert_equal(storage.refused_entries(), 7, "six bad entries and one bad provider")
	var full := StorageScript.new()
	full.add_provider(Callable())
	assert_equal(full.refused_entries(), 1, "an invalid provider is refused")
	var many: Array = []
	for k: int in 20:
		many.append(_cellar(k, 5, 350))
	full.add_provider(func() -> Array: return many)
	assert_equal(full.count(), StorageScript.MAX_LOCATIONS, "at most 16 places")
	assert_equal(full.refused_entries(), 6, "the invalid provider and 5 cellars over the cap")


func test_deliveries_go_where_food_keeps_longest() -> void:
	"""5 U fits the 10 U cellar (350) first; 11 U goes to the covered store; the pantry counts by item."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_cellar(&"cellar", 10, 350)])
	var pantry := PantryScript.new(storage)
	assert_true(pantry.location_for_into(5000, _read), "room")
	assert_equal(_read.value, 1, "the cellar")
	assert_true(pantry.add_into(CARROT, 5100, 1, _read), "stored")
	assert_true(pantry.location_for_into(5000, _read), "room again")
	assert_equal(_read.value, 0, "the cellar holds 5.1 of 10: the store")
	assert_false(pantry.add_into(CARROT, 5000, 1, _read), "the cellar is too full")
	assert_equal(_read.error, PantryScript.REFUSE_NO_ROOM, "says so")
	assert_true(pantry.add_into(RADISH, 2999, 0, _read), "radish")
	assert_equal(pantry.units_of(CARROT), 5, "5 carrots")
	assert_equal(pantry.units_of(RADISH), 2, "2 radishes")
	assert_equal(pantry.total_milli(), 8099, "8.099 U in all, summed before any rounding")
	assert_equal(pantry.milli_at(CARROT, 1), 5100, "in the cellar")


func test_pantry_refuses_bad_deliveries() -> void:
	"""An unknown item, a zero quantity, an unknown location."""
	var pantry := PantryScript.new(StorageScript.new())
	assert_false(pantry.add_into(99, 1000, 0, _read), "item")
	assert_equal(_read.error, PantryScript.REFUSE_NOT_AN_ITEM, "item code")
	assert_false(pantry.add_into(CARROT, 0, 0, _read), "quantity")
	assert_false(pantry.add_into(CARROT, 1000, 1, _read), "location")
	assert_equal(pantry.lot_count(), 0, "nothing stored")


func test_food_spoils_at_the_section_5_8_rate() -> void:
	"""Covered store, spring: 1000 milli-h an hour, carrots spoil at 240 h; half way they are 500
	fresh. Spoiled food leaves the count and composts 4 : 2."""
	var pantry := PantryScript.new(StorageScript.new())
	pantry.add_into(CARROT, 5101, 0, _read)
	for hour: int in 120:
		pantry.age_hour(0)
	assert_true(pantry.freshness_permille_into(CARROT, _read), "fresh")
	assert_equal(_read.value, 500, "half its shelf life")
	for hour: int in 119:
		assert_equal(pantry.age_hour(0), 0, "not yet")
	assert_equal(pantry.units_of(CARROT), 5, "still 5 at 239 h")
	assert_equal(pantry.age_hour(0), 1, "spoils at 240 h")
	assert_equal(pantry.units_of(CARROT), 0, "gone")
	assert_equal(pantry.spoiled_milli, 5101, "equal mass spoiled")
	var spoiled := PackedInt32Array()
	assert_equal(pantry.take_spoiled_items_into(spoiled), 1, "one lot")
	assert_equal(spoiled, PackedInt32Array([CARROT]), "carrots")
	assert_equal(pantry.compost_spoiled(), 2550, "5100 -> 2550")
	assert_equal(pantry.spoiled_milli, 1, "the odd milli-U stays")


func test_hours_left_are_the_oldest_lot_s() -> void:
	"""Two lots of carrots, 10 h apart: the pantry warns by the older one (230 h left, not 240)."""
	var pantry := PantryScript.new(StorageScript.new())
	pantry.add_into(CARROT, 1000, 0, _read)
	for hour: int in 10:
		pantry.age_hour(0)
	pantry.add_into(CARROT, 1000, 0, _read)
	assert_true(pantry.hours_left_into(CARROT, _read), "held")
	assert_equal(_read.value, 230, "the older lot")
	assert_false(pantry.hours_left_into(RADISH, _read), "no radish")
	assert_equal(_read.error, PantryScript.REFUSE_NO_STOCK, "says so")


func test_a_cellar_slows_spoilage_by_its_multiplier() -> void:
	"""350 in spring: 350 milli-h an hour; in summer 350 x 1500 / 1000 = 525; a factor of 7 in summer
	is 10.5, so two summer hours make 21 (the half is kept, not floored away twice)."""
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return [_cellar(&"cellar", 50, 350), _cellar(&"slow", 50, 7)])
	var pantry := PantryScript.new(storage)
	pantry.add_into(CARROT, 1000, 1, _read)
	var cellar_lot: int = _read.value
	pantry.add_into(RADISH, 1000, 2, _read)
	var slow_lot: int = _read.value
	pantry.age_hour(0)
	assert_equal(pantry.lot_age(cellar_lot), 350, "spring")
	pantry.age_hour(1)
	assert_equal(pantry.lot_age(cellar_lot), 875, "then summer")
	pantry.age_hour(1)
	assert_equal(pantry.lot_age(slow_lot), 7 + 10 + 11, "7: 7 in spring, then 10.5 twice: 10, then 11")


func test_lots_follow_their_cellar_and_fall_back_to_the_store() -> void:
	"""A lot in cellar "b" follows it when "a" disappears (index 2 -> 1); when "b" goes too it moves to
	the covered store."""
	var listed: Array = [[_cellar(&"a", 20, 350), _cellar(&"b", 20, 350)]]
	var storage := StorageScript.new()
	storage.add_provider(func() -> Array: return listed[0])
	var pantry := PantryScript.new(storage)
	pantry.add_into(CARROT, 1000, 2, _read)
	var lot: int = _read.value
	listed[0] = [_cellar(&"b", 20, 350)]
	pantry.refresh_locations()
	assert_equal(pantry.lot_location(lot), 1, "followed b")
	listed[0] = []
	pantry.refresh_locations()
	assert_equal(pantry.lot_location(lot), 0, "to the store")
	assert_equal(pantry.units_of(CARROT), 1, "nothing lost")


func test_a_full_lot_table_merges_keeping_the_older_age() -> void:
	"""With every row taken, a delivery merges into the oldest lot of its item and place."""
	var pantry := PantryScript.new(StorageScript.new())
	for lot: int in PantryScript.MAX_LOTS:
		pantry.add_into(RADISH, 1000, 0, _read)
		if lot == 0:
			pantry.age_hour(0)
	assert_true(pantry.add_into(RADISH, 500, 0, _read), "merged")
	assert_equal(_read.value, 0, "into the oldest")
	assert_equal(pantry.lot_age(0), 1000, "its age kept")
	assert_false(pantry.add_into(CARROT, 500, 0, _read), "no carrot lot to merge into")
	assert_equal(pantry.units_of(RADISH), 128, "128.5 U")


# --- the tunnel integration -----------------------------------------------------------------------

func _open(network: GraphScript, points_m: Array[Vector2]) -> PackedInt32Array:
	"""Add a mouth-to-mouth route (metres, at least 8 m: two 4 m ramps) to the network as a piece and dig
	every segment of it to the end; returns [entrance mouth row, exit mouth row] -- its two heaps."""
	var route := PackedInt32Array()
	for p: Vector2 in points_m:
		route.append(Rules.to_u(p.x))
		route.append(Rules.to_u(p.y))
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(route, points_m.size(), 0, ref), "the fixture tunnel is stored")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot: int in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 3600 * Rules.USEC_PER_SECOND)
	assert_true(network.piece_done(ref[2]), "and dug")
	return PackedInt32Array([network.mouth_of_end(chain[0], false), network.mouth_of_end(chain[chain.size() - 1], true)])


func test_the_farm_s_water_edge_is_the_real_stream_s_bank() -> void:
	"""The farm asks the village's water adapter, over the real stream: dry ground within 2.5 m of the
	waterline is at its edge -- by the ford 2460 u away, yes; by the run 2567 u away, no; in the water
	or in the square, no."""
	var village_water := VillageWaterScript.new()
	var query: Callable = village_water.edge_query()
	assert_true(bool(query.call(Rules.to_u(19.5), Rules.to_u(-0.8))), "by the ford: 2460 u from the waterline")
	assert_true(bool(query.call(Rules.to_u(19.5), Rules.to_u(4.0))), "2502 u")
	assert_false(bool(query.call(Rules.to_u(19.5), Rules.to_u(9.0))), "by the run: 2567 u, just too far")
	assert_false(bool(query.call(Rules.to_u(24.5), Rules.to_u(9.0))), "in the stream is not its edge")
	assert_false(bool(query.call(0, 0)), "the square is dry")


func test_segment_nearness_is_exact_in_integers() -> void:
	"""Perpendicular: 500 u away is within 500, not 499. Past an end: the end's distance."""
	assert_true(TunnelsScript.segment_near(0, 0, -1000, 500, 1000, 500, 500), "500 within 500")
	assert_false(TunnelsScript.segment_near(0, 0, -1000, 500, 1000, 500, 499), "not 499")
	assert_true(TunnelsScript.segment_near(0, 0, 600, 0, 2000, 0, 600), "the end 600 away")
	assert_false(TunnelsScript.segment_near(0, 0, 600, 0, 2000, 0, 599), "not 599")
	assert_true(TunnelsScript.segment_near(0, 0, 0, 0, 0, 0, 0), "a point on a point")
	assert_false(TunnelsScript.segment_near(-20480, -20480, 20480, 20480, 20480, -20480, 973), "far corner")
	assert_false(TunnelsScript.segment_near(1500, 100, 0, 0, 1000, 0, 200), "past the end: 510 away, not 100")
	assert_true(TunnelsScript.segment_near(1100, 100, 0, 0, 1000, 0, 200), "past the end: 141 away")


func test_a_pond_tunnel_irrigates_and_another_drains() -> void:
	"""From the real stream's edge by the ford west along z 12.8: irrigates both roots beds (every open
	segment joined to that mouth carries its water); along z 16.4 from inland (8 m, x -15 to -7): drains
	both grain beds; the cabbage beds are untouched."""
	var network := GraphScript.new()
	var tunnels := TunnelsScript.new()
	_open(network, [Vector2(19.5, -0.8), Vector2(-7.0, 12.8), Vector2(-14.0, 12.8)])
	_open(network, [Vector2(-15.0, 16.4), Vector2(-7.0, 16.4)])
	var water := PackedByteArray([0, 0])
	for case: Array in [[BED_CARROTS, 0, 1], [BED_RADISH, 0, 1], [BED_WHEAT, 1, 0], [BED_EMPTY_CLAY_2, 1, 0],
			[BED_EMPTY_LOAM, 0, 0], [BED_EMPTY_CLAY, 0, 0]]:
		tunnels.water_of_into(network, int(case[0]), water)
		assert_equal(water, PackedByteArray([int(case[1]), int(case[2])]), "bed %d" % case[0])


func test_the_water_query_is_pluggable() -> void:
	"""With a fixture query that calls everything east of x = 0 water, a tunnel with its mouth there
	irrigates; with one that calls nothing water, the same tunnel drains."""
	var network := GraphScript.new()
	var tunnels := TunnelsScript.new()
	_open(network, [Vector2(1.0, 12.8), Vector2(-14.0, 12.8)])
	var water := PackedByteArray([0, 0])
	tunnels.water_edge = func(x_u: int, _z_u: int) -> bool: return x_u > 0
	tunnels.water_of_into(network, BED_RADISH, water)
	assert_equal(water, PackedByteArray([0, 1]), "irrigates from the fixture water")
	tunnels.water_edge = func(_x_u: int, _z_u: int) -> bool: return false
	tunnels.water_of_into(network, BED_RADISH, water)
	assert_equal(water, PackedByteArray([1, 0]), "drains with none")


func test_an_unfinished_tunnel_does_nothing_for_the_beds() -> void:
	"""Only a finished tunnel drains: laid, its first segment digging, it drains nothing."""
	var network := GraphScript.new()
	var tunnels := TunnelsScript.new()
	var route := PackedInt32Array([Rules.to_u(-15.0), Rules.to_u(16.4), Rules.to_u(-7.0), Rules.to_u(16.4)])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(route, 2, 0, ref), "laid")
	assert_equal(network.phase[ref[0]], GraphScript.PHASE_DIGGING, "being dug")
	var water := PackedByteArray([0, 0])
	tunnels.water_of_into(network, BED_WHEAT, water)
	assert_equal(water, PackedByteArray([0, 0]), "digging: nothing")


func test_spoil_is_taken_off_a_heap_and_the_heap_shrinks() -> void:
	"""An 8 m tunnel is two 4 m ramps sharing a foot: a shaft and 4 quanta, then 4 quanta and a shaft.
	Every cut but the exit shaft heaps at the entrance mouth: 9 x 2 U = 18 U there, 2 U at the exit.
	Taking 2 U leaves 16; more than is left is refused; a reused mouth row starts clean."""
	var network := GraphScript.new()
	var tunnels := TunnelsScript.new()
	var heaps: PackedInt32Array = _open(network, [Vector2(-15.0, 16.4), Vector2(-7.0, 16.4)])
	var entrance: int = heaps[0]
	var exit: int = heaps[1]
	assert_equal(tunnels.spoil_left(network, entrance), 18000, "entrance heap")
	assert_equal(tunnels.spoil_left(network, exit), 2000, "exit heap")
	assert_true(tunnels.take_spoil_into(network, entrance, 2000, _read), "taken")
	assert_equal(_read.value, 16000, "left")
	assert_equal(tunnels.taken_milli(network, entrance), 2000, "recorded")
	assert_false(tunnels.take_spoil_into(network, exit, 2001, _read), "not more than is there")
	assert_equal(_read.error, TunnelsScript.REFUSE_NO_SPOIL, "says so")
	assert_false(tunnels.take_spoil_into(network, 99, 1000, _read), "no such heap")
	assert_equal(tunnels.total_spoil(network), 18000, "16 + 2")
	network.mouth_gen[entrance] += 1
	assert_equal(tunnels.spoil_left(network, entrance), 18000, "a reused mouth row's heap starts clean")


func test_the_nearest_heap_with_enough_earth_is_chosen() -> void:
	"""Nearest to the exit end, but the exit heap holds only 2 U: 3 U comes from the entrance (18 U, the
	8 m tunnel's); nothing holds 19 U. No stores bound: heaps only."""
	var network := GraphScript.new()
	var tunnels := TunnelsScript.new()
	var heaps: PackedInt32Array = _open(network, [Vector2(-15.0, 16.4), Vector2(-7.0, 16.4)])
	network.set_heap(heaps[0], Vector2(-15.0, 17.4), 0.8, Vector2(0.0, 1.0))
	network.set_heap(heaps[1], Vector2(-7.0, 17.4), 0.3, Vector2(0.0, 1.0))
	assert_true(tunnels.nearest_earth_into(network, Vector2(-6.0, 17.0), 2000, _read), "2 U")
	assert_equal(_read.value, heaps[1], "the exit heap")
	assert_true(tunnels.nearest_earth_into(network, Vector2(-6.0, 17.0), 3000, _read), "3 U")
	assert_equal(_read.value, heaps[0], "the entrance heap")
	assert_true(tunnels.nearest_earth_into(network, Vector2.ZERO, 18000, _read), "18 U: the entrance heap")
	assert_false(tunnels.nearest_earth_into(network, Vector2.ZERO, 18001, _read), "none that big")


# --- the job board ----------------------------------------------------------------------------

func test_jobs_open_once_per_kind_and_bed() -> void:
	"""A second sow on bed 0 is refused; a water on bed 0 is not; the board holds 24."""
	var jobs := JobsScript.new()
	assert_true(jobs.open_into(JobsScript.KIND_SOW, 0, JobsScript.ORIGIN_PLAYER, _read), "sow")
	assert_equal(_read.value, 0, "row 0")
	assert_false(jobs.open_into(JobsScript.KIND_SOW, 0, JobsScript.ORIGIN_PLAYER, _read), "again")
	assert_equal(_read.error, JobsScript.REFUSE_DUPLICATE, "duplicate")
	assert_true(jobs.open_into(JobsScript.KIND_WATER, 0, JobsScript.ORIGIN_PLAYER, _read), "water")
	for kind: int in JobsScript.KIND_COUNT:
		for bed: int in 3:
			jobs.open_into(kind, bed, JobsScript.ORIGIN_ROUTINE, _read)
	assert_equal(jobs.live_count(), 24, "full")
	assert_false(jobs.open_into(JobsScript.KIND_COVER, 5, JobsScript.ORIGIN_PLAYER, _read), "full")
	assert_equal(_read.error, JobsScript.REFUSE_BOARD_FULL, "says so")
	assert_equal(JobsScript.KIND_COUNT, 9, "nine kinds: Drain is the ninth")
	assert_equal(JobsScript.KIND_DELIVER, JobsScript.KIND_COUNT, "the delivery after the orderable kinds")
	assert_equal(JobsScript.KIND_RETURN_EARTH, JobsScript.KIND_COUNT + 1, "then the earth return")
	assert_equal(JobsScript.KIND_NAMES.size(), JobsScript.KIND_COUNT + 2, "a name each, the delivery's and return's too")
	assert_equal(JobsScript.KIND_DOING.size(), JobsScript.KIND_COUNT + 2, "a doing each")
	assert_equal(JobsScript.PLANS.size(), JobsScript.KIND_COUNT + 2, "a plan each")
	assert_false(jobs.open_into(JobsScript.KIND_COUNT, 0, JobsScript.ORIGIN_PLAYER, _read), "no such kind")
	assert_equal(_read.error, JobsScript.REFUSE_BAD_KIND, "says so")


func test_a_watering_job_walks_its_plan_and_keeps_work_on_rewind() -> void:
	"""Well, fetch, carry to the bed, tend; a worker leaving mid-tend rewinds to the carry with the
	tending done so far kept; leaving the work step clears it."""
	var jobs := JobsScript.new()
	jobs.open_into(JobsScript.KIND_WATER, 1, JobsScript.ORIGIN_PLAYER, _read)
	var row: int = _read.value
	var seen := PackedInt32Array([jobs.current_step(row)])
	while jobs.advance(row):
		seen.append(jobs.current_step(row))
	assert_equal(seen, PackedInt32Array([JobsScript.STEP_GO_WELL, JobsScript.STEP_WORK + JobsScript.WORK_FETCH,
		JobsScript.STEP_CARRY_BED, JobsScript.STEP_WORK + JobsScript.WORK_TEND]), "the plan")
	var fetch := JobsScript.new()
	fetch.open_into(JobsScript.KIND_WATER, 1, JobsScript.ORIGIN_PLAYER, _read)
	fetch.advance(_read.value)
	fetch.elapsed_usec[_read.value] = 500000
	assert_true(fetch.advance(_read.value), "past the fetch")
	assert_equal(fetch.elapsed_usec[_read.value], 0, "leaving a work step clears its work")
	jobs.elapsed_usec[row] = 700000
	jobs.begun[row] = 1
	jobs.rewind_to_walk(row)
	assert_equal(jobs.current_step(row), JobsScript.STEP_CARRY_BED, "back to the carry")
	assert_equal(jobs.elapsed_usec[row], 700000, "work kept")
	assert_true(jobs.advance(row), "on to the work")
	assert_equal(jobs.elapsed_usec[row], 700000, "still kept")
	assert_equal(jobs.begun[row], 1, "its start kept")
	assert_equal(jobs.work_usec(JobsScript.WORK_TEND), 1500000, "1 WU at 1.5 s")
	assert_equal(jobs.work_usec(JobsScript.WORK_CLEAR), 15000000, "10 WU")


func test_a_drain_job_walks_to_the_bed_and_digs() -> void:
	"""Drain: to the bed, then 6 WU of digging (9 s of the cast's time)."""
	var jobs := JobsScript.new()
	assert_true(jobs.open_into(JobsScript.KIND_DRAIN, 3, JobsScript.ORIGIN_PLAYER, _read), "opened")
	var row: int = _read.value
	assert_equal(jobs.current_step(row), JobsScript.STEP_GO_BED, "to the bed")
	assert_true(jobs.advance(row), "then")
	assert_equal(jobs.current_step(row), JobsScript.STEP_WORK + JobsScript.WORK_DRAIN, "dig the ditch")
	assert_false(jobs.advance(row), "and done")
	assert_equal(jobs.work_usec(JobsScript.WORK_DRAIN), 9000000, "6 WU at 1.5 s")
	assert_equal(JobsScript.KIND_NAMES[JobsScript.KIND_DRAIN], "Drain", "named")


func test_compost_goes_to_the_bed_and_never_to_a_heap() -> void:
	"""Decision 0401: compost is the compost store's, walked to the bed and worked in -- no plan digs a heap but Raise
	and Bank, and an earth return carries back to one."""
	var jobs := JobsScript.new()
	jobs.open_into(JobsScript.KIND_COMPOST, 2, JobsScript.ORIGIN_PLAYER, _read)
	assert_equal(jobs.current_step(_read.value), JobsScript.STEP_GO_BED, "to the bed")
	assert_equal(jobs.plan_size(_read.value), 2, "two steps")
	for kind: int in JobsScript.PLANS.size():
		var digs: bool = JobsScript.PLANS[kind].has(JobsScript.STEP_WORK + JobsScript.WORK_DIG)
		assert_equal(digs, kind == JobsScript.KIND_RAISE or kind == JobsScript.KIND_BANK, "%s digs earth" % JobsScript.KIND_NAMES[kind])
	assert_equal(JobsScript.PLANS[JobsScript.KIND_RETURN_EARTH], [JobsScript.STEP_CARRY_HEAP,
		JobsScript.STEP_WORK + JobsScript.WORK_DROP], "an earth return: carry back, tip")


func test_verbs_are_offered_by_the_bed_state() -> void:
	"""Sow needs a sowable choice; water a growing crop; harvest a ripe one; raise and bank need 2 U of
	spoil and are once only; cover not on an empty bed."""
	var sim := SimScript.new()
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_SOW, BED_EMPTY_LOAM, 0), SimScript.REFUSE_NO_ITEM, "no choice")
	sim.choose(BED_EMPTY_LOAM, WHEAT)
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_SOW, BED_EMPTY_LOAM, 0), &"", "sowable")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_WATER, BED_EMPTY_LOAM, 0),
		StringName(JobsScript.REFUSE_NOT_GROWING), "nothing growing")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_WATER, BED_WHEAT, 0), &"", "wheat grows")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_HARVEST, BED_WHEAT, 0),
		StringName(JobsScript.REFUSE_NOT_RIPE), "not ripe")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_RAISE, BED_WHEAT, 1999),
		StringName(JobsScript.REFUSE_NO_EARTH), "1.999 U")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_BANK, BED_WHEAT, 2000), &"", "2 U")
	sim.raise_bed(BED_WHEAT)
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_RAISE, BED_WHEAT, 5000), SimScript.REFUSE_ALREADY, "once")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COVER, BED_EMPTY_CLAY, 0), SimScript.REFUSE_NO_CROP, "empty")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COVER, BED_WHEAT, 0), &"", "a crop to cover")
	sim.cover(BED_WHEAT)
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COVER, BED_WHEAT, 0), SimScript.REFUSE_ALREADY, "covered already")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_CLEAR, BED_WHEAT, 0), SimScript.REFUSE_NOTHING_TO_CLEAR, "healthy")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_DRAIN, BED_RADISH, 0), SimScript.REFUSE_NOT_TOO_WET, "not wet")
	_set_moisture(sim, BED_RADISH, 9800)
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_DRAIN, BED_RADISH, 0), &"", "waterlogged: drain it")


func test_compost_is_the_store_s_and_no_amount_of_earth_stands_in() -> void:
	"""Decision 0401: 4 U in store, compost can go on; 1 U, it is refused whatever earth there is."""
	var sim := SimScript.new()
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COMPOST, BED_EMPTY_LOAM, 0), &"", "the store")
	sim.compost_milli = 1000
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COMPOST, BED_EMPTY_LOAM, 1999), SimScript.REFUSE_NO_COMPOST, "short")
	assert_equal(JobsScript.refusal_for(sim, JobsScript.KIND_COMPOST, BED_EMPTY_LOAM, 1 << 40), SimScript.REFUSE_NO_COMPOST,
		"earth will not do")
