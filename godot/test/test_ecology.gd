extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/ecology.gd` — ARCH-SYS-005, REQ-SET-007's "update ecology" leg.
##
## This suite tests the ORCHESTRATION, not the four stores' arithmetic, which `test_fishing.gd`,
## `test_forage.gd`, `test_resource_nodes.gd` and `test_orchard_hive.gd` already pin in isolation.
## What is asserted here is that a real offset-calendar midnight reaches each store, that it
## reaches it exactly once, that it reaches it with the right day and season, and that the legs
## this stage does NOT own stay untouched.
##
## Every expected number below is recomputed here from the specification's own formula, never
## read back out of the module under test:
##   * §5.4 recovery `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`, with §5.4's capacity
##     and `r` columns transcribed independently, and salmon's "300 U at autumn day 1, capped
##     at K".
##   * §5.5 regrowth in decision 0036's ADDITIVE form,
##     `min(K-P, floor((K-P)*r*S/1000000) + 1000)`.
##   * §5.6's 200-strength unserviced loss, 500-strength unfed winter loss, `2 U honey and
##     0.25 U wax x strength/10000`, and spring's +300 tended gain.
##   * REQ-SET-138's 48-day stump.
##
## CALENDAR. Tick 0 is 06:00 of absolute day 1, so `(tick + 4500) mod 18000 == 0` is midnight and
## day D opens at `(D-1)*18000 - 4500`. Every tick constant below is that arithmetic done by hand,
## and NONE of them is a multiple of 18000 -- which is the point.

const EcologyScript := preload("res://scripts/core/ecology.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")

## Midnights, computed by hand as `(day - 1) * 18000 - 4500`.
const DAY_2_TICK: int = 13500
const DAY_3_TICK: int = 31500
const DAY_5_TICK: int = 67500
const SUMMER_DAY_1_TICK: int = 211500
const AUTUMN_DAY_1_TICK: int = 427500
const WINTER_DAY_1_TICK: int = 643500
const WINTER_DAY_2_TICK: int = 661500
const YEAR_2_DAY_1_TICK: int = 859500
const DAY_50_TICK: int = 877500
## 06:00 of day 2. A tick multiple of a day, and deliberately NOT a boundary.
const TICKS_PER_DAY: int = 18000

const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

## GDD §4.2 numbers HabitatType from its domain's ascending ASCII keys: COAST, LAKE, RIVER.
const RIVER: int = 2
## A river habitat's three stocks in §5.4's printed order: trout, dace, salmon.
const TROUT_INDEX: int = 0
const DACE_INDEX: int = 1
const SALMON_INDEX: int = 2

## §5.4's capacity and recovery columns for the river's three rows, transcribed from the GDD.
const TROUT_CAPACITY: int = 600000
const TROUT_RECOVERY: int = 80
const DACE_CAPACITY: int = 900000
const DACE_RECOVERY: int = 120
const SALMON_CAPACITY: int = 600000
const SALMON_RECOVERY: int = 100
## §5.4: "Initial stocks are 80% of capacity".
const TROUT_INITIAL: int = 480000
const DACE_INITIAL: int = 720000
const SALMON_INITIAL: int = 480000
## One day of §5.4 recovery from 80%, evaluated by hand.
##   trout  480000 + floor(80*480000*120000/(1000*600000)) + floor(600000/200) = 480000+7680+3000
##   dace   720000 + floor(120*720000*180000/(1000*900000)) + floor(900000/200) = 720000+17280+4500
##   salmon 480000 + floor(100*480000*120000/(1000*600000)) + floor(600000/200) = 480000+9600+3000
const TROUT_AFTER_ONE_DAY: int = 490680
const DACE_AFTER_ONE_DAY: int = 741780
const SALMON_AFTER_ONE_DAY: int = 492600
## §5.4: "Salmon additionally receive 300 U at autumn day 1, capped at K." 480000 + 312600 > K.
const SALMON_AUTUMN_DAY_1: int = 600000

## REQ-SET-048's two stated levels for a 600000 milli-U stock: 30% and 40% of capacity.
const TROUT_DEPLETION_LEVEL: int = 180000
const TROUT_RECOVERY_LEVEL: int = 240000
## Populations whose ONE day of §5.4 recovery lands exactly on those two levels, and the
## populations one milli-U either side of them. Solved from the recovery formula above; each is
## the unique population with that successor, so a single milli-U separates the four cases:
##   167347 -> 180000 (exactly 30%)   167346 -> 179999 (below 30%)
##   225736 -> 240000 (exactly 40%)   225737 -> 240001 (above 40%)
const SEED_LANDING_ON_30_PERCENT: int = 167347
const SEED_LANDING_BELOW_30_PERCENT: int = 167346
const SEED_LANDING_ON_40_PERCENT: int = 225736
const SEED_LANDING_ABOVE_40_PERCENT: int = 225737

## §5.5's five forage rows; herb is row 3 and is the only fixture kind used for regrowth here.
const BERRIES: int = 0
const HERB: int = 3
## §5.5: herb capacity 160 U, `r` 80/1000, spring availability 1000/1000; initial stock is 80%.
const HERB_CAPACITY: int = 160000
const HERB_INITIAL: int = 128000
## Decision 0036, additive: `min(32000, floor(32000*80*1000/1000000) + 1000)` = 2560 + 1000.
const HERB_SPRING_GROWTH: int = 3560
const HERB_AFTER_ONE_SPRING_DAY: int = 131560
## §5.5 herb winter availability 200/1000: `floor(32000*80*200/1000000) + 1000` = 512 + 1000.
## Decision 0036 prints this exact row, which is why it is the season-sensitivity fixture.
const HERB_WINTER_GROWTH: int = 1512
## GDD §4.2 numbers ZoneType from its domain's ascending ASCII keys; FORAGE is 2.
const ZONE_FORAGE: int = 2

## §5.6's hive figures, transcribed from the GDD.
const HIVE_START_STRENGTH: int = 8000
const HIVE_HEALTHY_LINE: int = 5000
const UNSERVICED_LOSS: int = 200
const UNFED_WINTER_LOSS: int = 500
const WINTER_FEED_PER_DAY: int = 500
const SPRING_TENDED_GAIN: int = 300
## `2 U x 8000/10000` and `0.25 U x 8000/10000`.
const HONEY_AT_FULL_STRENGTH: int = 1600
const WAX_AT_FULL_STRENGTH: int = 200

## REQ-SET-138/§5.9: "Trees regrow after 48 days when their stumps remain".
const TREE_REGROW_DAYS: int = 48
const TREE_CAPACITY_MILLI: int = 12000
const TREE_TILE_X: int = 20
const TREE_TILE_Z: int = 20

## Tiles for the pollination fixture. A 4x4 orchard block at origin (8,8) centres on
## `(8 + 11 + 1) * 1024 = 20480`; a 1x1 hive on tile 13 centres on `(13 + 13 + 1) * 1024 = 27648`.
## The separation is 7168 on each axis, so the squared distance 102760448 is inside decision
## 0044's `(12 * 1024)^2 = 150994944`.
const ORCHARD_ORIGIN: int = 8
const HIVE_TILE: int = 13

var _ecology: EcologyScript = null
var _day: EcologyScript.DayResult = null
var _jobs: JobsScript = null
var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null


class SeededFishing extends FishingScript:
	"""A fishery whose stock populations can be placed exactly, which its public API cannot do.

	Decision 0037's restocking latch is specified with STRICT comparisons at exactly 30% and 40%
	of capacity, and no public operation can leave a population on either line: `harvest()` is
	bounded by the daily quota and the protection floor, and `recover_daily()` moves it. This
	subclass writes the two packed columns the latch reads and nothing else.
	"""

	func force_population_milli(row: int, population_milli: int) -> void:
		"""Place one stock's population with no validation and without touching the latch."""
		_stock_population_milli[row] = population_milli

	func force_restocking(row: int, restocking: bool) -> void:
		"""Place one stock's restocking latch, so its RETENTION in the band can be observed."""
		_stock_restocking[row] = 1 if restocking else 0


class CorruptibleForage extends ForageScript:
	"""A forage store that can be driven into a state its public API refuses to produce.

	Decision 0036 requires a stored `P > K` to be REFUSED with `STOCK_ABOVE_CAPACITY` rather
	than reported as zero growth, and nothing in the public surface can write such a stock. It
	is the only way to make a LEG of the stage refuse midway, which is what proves a refused day
	carries no counts from the legs that already ran.
	"""

	func force_stock_milli(row: int, stock_milli: int) -> void:
		"""Write one patch's stock column with no validation, corrupt values included."""
		_patch_stock_milli[row] = stock_milli


class SeededEcology extends EcologyScript:
	"""An ecology whose fishery or forage store can be swapped for a seedable one.

	The replacement takes this ecology's own directory, so every reference still validates in one
	directory; `forage.gd` publishes the Job store it was built with, so nothing has to be
	threaded through the production constructor for a test's benefit. Call either swap BEFORE
	creating any row in the store being replaced.
	"""

	func seed_the_fishery() -> SeededFishing:
		"""Replace the fishery with a seedable one. Call before creating any habitat."""
		_fishing = SeededFishing.new(_directory, _forage, _forage.jobs())
		return _fishing as SeededFishing

	func seed_the_forage() -> CorruptibleForage:
		"""Replace the forage store with a corruptible one. Call before creating any zone."""
		_forage = CorruptibleForage.new(_directory, _forage.jobs())
		return _forage as CorruptibleForage


func before_each() -> void:
	"""Give every test an ecology over its own directory, and one reusable day result."""
	_ecology = EcologyScript.new()
	_day = EcologyScript.DayResult.new()


func after_each() -> void:
	"""Drop the ecology and any Job store it owned claims through."""
	_ecology = null
	_day = null
	_jobs = null
	_residents = null
	_priorities = null
	_schedule = null


func _use_job_store() -> void:
	"""Rebuild the ecology over a live Job store, so its forage store can own claims."""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_ecology = EcologyScript.new(null, _jobs)


func _run(tick: int) -> bool:
	"""Run one ecology day into the shared result and report whether it committed."""
	return _ecology.run_day_into(tick, _day)


func _river() -> Vector2i:
	"""Create one river habitat with three opaque species ids, at §5.4's 80% of capacity."""
	var made: FishingScript.OpResult = _ecology.fishing().create_habitat(
		RIVER, EntityDirectoryScript.NULL_REF, PackedInt32Array([10, 11, 12]), 0, 0, 0)
	assert_true(made.ok, "the fixture habitat must be created (%s)" % made.error)
	return made.ref


func _stock_row(habitat: Vector2i, species_index: int) -> int:
	"""The FishStock row of one habitat's species slot."""
	var row: IntMathScript.IntResult = _ecology.fishing().stock_row_of(habitat, species_index)
	assert_true(row.ok, "the fixture stock row must resolve (%s)" % row.error)
	return row.value


func _population(habitat: Vector2i, species_index: int) -> int:
	"""One stock's population in milli-U."""
	return _ecology.fishing().population_milli_of(_stock_row(habitat, species_index)).value


func _basin(quota_milli: int) -> Vector2i:
	"""One enabled, unprotected FORAGE basin with a MANUAL daily quota and all five patches."""
	var made: ForageScript.OpResult = _ecology.forage().create_zone(
		ZONE_FORAGE, 1, quota_milli, false, true)
	assert_true(made.ok, "the fixture basin must be created (%s)" % made.error)
	assert_true(_ecology.forage().set_quota_milli(made.ref, quota_milli, SUMMER).ok,
		"the fixture quota must be set manually, so a season change cannot move it")
	_ecology.forage().create_patch_set(made.ref, PackedInt32Array([10, 11, 12, 13, 14]))
	return made.ref


func _patch_row(basin: Vector2i, kind: int) -> int:
	"""The ForagePatch row of one basin's forage kind."""
	var row: IntMathScript.IntResult = _ecology.forage().patch_row_for_zone(basin, kind)
	assert_true(row.ok, "the fixture patch row must resolve (%s)" % row.error)
	return row.value


func _zone_slot(basin: Vector2i) -> int:
	"""The HarvestZone row a live basin reference names."""
	return _ecology.forage().zone_slot_of(basin).value


func _make_job(created_tick: int) -> Vector2i:
	"""Create one FORAGE job with a stated creation tick and hand back its reference."""
	var made: JobsScript.OpResult = _jobs.create_job(
		JobsScript.JOB_KIND_FORAGE, 0, 0, 100, created_tick)
	assert_true(made.ok, "the fixture job must be created (%s)" % made.error)
	return made.ref


func _hive(day: int) -> Vector2i:
	"""Colonise one 1x1 hive at HIVE_TILE, serviced on `day`, at §5.6's starting strength."""
	var building: Vector2i = _ecology.directory().create(EntityDirectoryScript.KIND_BUILDING)
	var made: OrchardHiveScript.OpResult = _ecology.orchard_hive().create_hive(
		building, HIVE_TILE, HIVE_TILE, HIVE_TILE, HIVE_TILE, day)
	assert_true(made.ok, "the fixture hive must be created (%s)" % made.error)
	return made.ref


func _hive_strength(hive: Vector2i) -> int:
	"""One hive's stored §5.6 strength."""
	var slot: int = _ecology.directory().get_typed_row(hive)
	return _ecology.orchard_hive().hive_strength_of(slot).value


func _felled_tree(felling_day: int, regrow_days: int) -> int:
	"""Place one tree node, fell it on `felling_day`, and return its row. Exhausted afterwards."""
	var tile: int = _ecology.resource_nodes().tile_index(TREE_TILE_X, TREE_TILE_Z).value
	var made: ResourceNodesScript.OpResult = _ecology.resource_nodes().create_at_tile(
		tile, 1, TREE_CAPACITY_MILLI, regrow_days, 1)
	assert_true(made.ok, "the fixture node must be placed (%s)" % made.error)
	var slot: int = made.value
	assert_true(_ecology.resource_nodes().harvest_all(slot, felling_day).ok, "the tree is felled")
	assert_true(_ecology.resource_nodes().is_exhausted(slot), "and its stump is dated")
	return slot


# --- the boundary predicate -------------------------------------------------------------------

func test_the_first_midnight_is_tick_13500_and_not_tick_18000() -> void:
	"""REQ-SET-007 crosses the OFFSET calendar: tick 18000 is 06:00 of day 2, not a boundary."""
	assert_false(_run(TICKS_PER_DAY), "tick 18000 is 06:00 of day 2 and opens no day")
	assert_equal(_day.error, &"NOT_A_DAY_BOUNDARY", "with the boundary code")
	assert_false(_run(0), "tick 0 is 06:00 of day 1 and starts no new day")
	assert_false(_run(-1), "a negative tick is refused")
	assert_equal(_day.error, &"INVALID_TICK", "with the tick code")
	assert_equal(_ecology.last_day_run(), 0, "and none of those consumed a day")
	assert_true(_run(DAY_2_TICK), "tick 13500 is the first midnight")
	assert_equal(_day.absolute_day, 2, "which opens absolute day 2")


func test_exactly_two_boundaries_fall_in_the_first_two_simulated_days() -> void:
	"""One boundary per day, at 13500 and 31500, over every tick of two days. Not `tick % 18000`."""
	var boundaries: Array[int] = []
	for tick: int in range(1, 2 * TICKS_PER_DAY + 1):
		if SimClockScript.is_day_boundary(tick):
			boundaries.append(tick)
	assert_equal(boundaries, [DAY_2_TICK, DAY_3_TICK] as Array[int],
		"exactly two crossings, and neither is a multiple of 18000")
	assert_true(_run(DAY_2_TICK), "the first crossing runs the stage")
	assert_true(_run(DAY_3_TICK), "and so does the second")
	assert_equal(_ecology.last_day_run(), 3, "leaving day 3 as the consumed day")


func test_the_midnight_inverse_is_gated_on_the_clocks_own_predicate() -> void:
	"""`(day-1)*18000-4500`, refused for any day that opens at no crossing."""
	var out: IntMathScript.IntResult = IntMathScript.IntResult.new()
	assert_true(EcologyScript.midnight_tick_of_day_into(2, out), "day 2 opens at a crossing")
	assert_equal(out.value, DAY_2_TICK, "at tick 13500")
	assert_true(EcologyScript.midnight_tick_of_day_into(37, out), "winter day 1 opens")
	assert_equal(out.value, WINTER_DAY_1_TICK, "at tick 643500")
	assert_false(EcologyScript.midnight_tick_of_day_into(1, out),
		"day 1 begins at 06:00 and has no midnight")
	assert_equal(out.error, "NOT_A_DAY_BOUNDARY", "and says so rather than answering -4500")
	assert_false(EcologyScript.midnight_tick_of_day_into(0, out), "day 0 names no day")
	assert_equal(out.error, "INVALID_ABSOLUTE_DAY", "with the day code")


func test_the_season_and_season_day_come_from_the_boundary_tick() -> void:
	"""ARCH-TICK-003: ecology uses the NEW calendar day's season, decoded from the one tick."""
	assert_true(_run(WINTER_DAY_1_TICK), "the winter boundary runs")
	assert_equal(_day.absolute_day, 37, "absolute day 37")
	assert_equal(_day.season, WINTER, "which is winter")
	assert_equal(_day.season_day, 1, "day 1 of it")


# --- idempotence --------------------------------------------------------------------------------

func test_running_the_same_day_twice_changes_nothing_the_second_time() -> void:
	"""The whole stage, replayed: every store must hold exactly what the first run left."""
	var habitat: Vector2i = _river()
	var basin: Vector2i = _basin(10000)
	var hive: Vector2i = _hive(1)
	var node: int = _felled_tree(2, TREE_REGROW_DAYS)
	assert_true(_run(DAY_2_TICK), "the first run commits")
	var trout: int = _population(habitat, TROUT_INDEX)
	var herb: int = _ecology.forage().stock_milli_of(_patch_row(basin, HERB)).value
	var strength: int = _hive_strength(hive)
	var stock: int = _ecology.resource_nodes().quantity_milli_of(node).value
	assert_false(_run(DAY_2_TICK), "the second run for the same day is refused")
	assert_equal(_day.error, &"ECOLOGY_DAY_ALREADY_RUN", "with the replay code")
	assert_equal(_population(habitat, TROUT_INDEX), trout, "the fish stock did not recover twice")
	assert_equal(_ecology.forage().stock_milli_of(_patch_row(basin, HERB)).value, herb,
		"the forage patch did not grow twice")
	assert_equal(_hive_strength(hive), strength, "the hive was not charged twice")
	assert_equal(_ecology.resource_nodes().quantity_milli_of(node).value, stock,
		"and the node was not restored twice")


func test_a_day_before_the_last_one_consumed_is_refused() -> void:
	"""Replaying an EARLIER day is the same fault as replaying the same one, and refuses too."""
	assert_true(_run(DAY_3_TICK), "day 3 runs")
	assert_false(_run(DAY_2_TICK), "day 2 cannot follow it")
	assert_equal(_day.error, &"ECOLOGY_DAY_ALREADY_RUN", "with the replay code")
	assert_equal(_ecology.last_day_run(), 3, "and the consumed day does not move backwards")


func test_clearing_the_ecology_drops_the_day_latch_and_every_store() -> void:
	"""A cleared settlement starts a fresh calendar with nothing left to advance."""
	_river()
	_basin(10000)
	_hive(1)
	assert_true(_run(DAY_3_TICK), "a day is consumed")
	_ecology.clear()
	assert_equal(_ecology.last_day_run(), 0, "the latch is dropped")
	assert_equal(_ecology.fishing().habitat_count(), 0, "the fishery is empty")
	assert_equal(_ecology.forage().zone_count(), 0, "the harvest zones are empty")
	assert_equal(_ecology.orchard_hive().hive_count(), 0, "the apiaries are empty")
	assert_true(_run(DAY_2_TICK), "and day 2 may run again")


# --- §5.4 fishing --------------------------------------------------------------------------------

func test_every_fish_stock_recovers_by_the_section_five_four_formula() -> void:
	"""One midnight, three stocks, each moved by the logistic term plus `floor(K/200)`."""
	var habitat: Vector2i = _river()
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_INITIAL, "trout start at 80% of K")
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_day.fish_stocks_recovered, 3, "all three stocks gained population")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_AFTER_ONE_DAY, "trout 480000+7680+3000")
	assert_equal(_population(habitat, DACE_INDEX), DACE_AFTER_ONE_DAY, "dace 720000+17280+4500")
	assert_equal(_population(habitat, SALMON_INDEX), SALMON_AFTER_ONE_DAY,
		"salmon 480000+9600+3000, with no autumn restock on a spring day")


func test_a_closed_species_still_recovers() -> void:
	"""§5.4: "closed" means no harvest job, not zero population."""
	var habitat: Vector2i = _river()
	assert_true(_ecology.fishing().set_closed(habitat, TROUT_INDEX, true).ok, "trout are closed")
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_true(_ecology.fishing().is_closed_flag(_stock_row(habitat, TROUT_INDEX)),
		"the closure is still in force")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_AFTER_ONE_DAY,
		"and the closed stock recovered by exactly the same formula")
	assert_equal(_day.fish_stocks_recovered, 3, "the closed stock is counted with the others")


func test_salmon_receive_the_autumn_day_one_restock_capped_at_capacity() -> void:
	"""§5.4: "Salmon additionally receive 300 U at autumn day 1, capped at K"."""
	var habitat: Vector2i = _river()
	assert_true(_run(AUTUMN_DAY_1_TICK), "the autumn day 1 boundary runs")
	assert_equal(_day.season, AUTUMN, "the decoded season is autumn")
	assert_equal(_day.season_day, 1, "on its first day")
	assert_equal(_population(habitat, SALMON_INDEX), SALMON_AUTUMN_DAY_1,
		"480000 + 312600 is capped at the 600000 capacity")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_AFTER_ONE_DAY,
		"and no other species receives the run")


func test_salmon_receive_no_restock_on_autumn_day_two() -> void:
	"""The restock is day 1 of autumn only; the day after it is an ordinary recovery."""
	var habitat: Vector2i = _river()
	assert_true(_run(AUTUMN_DAY_1_TICK + TICKS_PER_DAY), "autumn day 2 opens")
	assert_equal(_day.season_day, 2, "and is decoded as day 2")
	assert_equal(_population(habitat, SALMON_INDEX), SALMON_AFTER_ONE_DAY,
		"480000+9600+3000, with no 300 U added")


func test_the_daily_fishing_quota_accumulator_is_reset_at_midnight() -> void:
	"""§5.4's `harvested_today_milli` is a DAILY total, and midnight is what reopens it."""
	var habitat: Vector2i = _river()
	var slot: int = _ecology.directory().get_typed_row(habitat)
	assert_true(_ecology.fishing().harvest(habitat, TROUT_INDEX, 1000, SPRING, 1).ok,
		"1 U of trout is taken on spring day 1")
	assert_equal(_ecology.fishing().harvested_today_total_of(slot).value, 1000,
		"the habitat's daily total holds it")
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_ecology.fishing().harvested_today_total_of(slot).value, 0,
		"and the new day starts from zero")


func test_the_restocking_latch_does_not_enter_at_exactly_thirty_percent() -> void:
	"""Decision 0037: the entry comparison is `100*P < 30*K`, STRICTLY, so equality flips nothing."""
	var seeded: SeededEcology = SeededEcology.new()
	var fishery: SeededFishing = seeded.seed_the_fishery()
	_ecology = seeded
	var habitat: Vector2i = _river()
	var row: int = _stock_row(habitat, TROUT_INDEX)
	fishery.force_population_milli(row, SEED_LANDING_ON_30_PERCENT)
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_DEPLETION_LEVEL,
		"the day's recovery lands the stock exactly on 30% of capacity")
	assert_false(_ecology.fishing().is_restocking(row), "and exactly 30% does not latch")


func test_the_restocking_latch_enters_one_milli_unit_below_thirty_percent() -> void:
	"""The other side of the same line: one milli-U lower and the latch must engage."""
	var seeded: SeededEcology = SeededEcology.new()
	var fishery: SeededFishing = seeded.seed_the_fishery()
	_ecology = seeded
	var habitat: Vector2i = _river()
	var row: int = _stock_row(habitat, TROUT_INDEX)
	fishery.force_population_milli(row, SEED_LANDING_BELOW_30_PERCENT)
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_DEPLETION_LEVEL - 1,
		"the day's recovery lands one milli-U below 30%")
	assert_true(_ecology.fishing().is_restocking(row), "which does latch")


func test_the_restocking_latch_does_not_clear_at_exactly_forty_percent() -> void:
	"""Decision 0037: the release comparison is `100*P > 40*K`, STRICTLY; the band retains."""
	var seeded: SeededEcology = SeededEcology.new()
	var fishery: SeededFishing = seeded.seed_the_fishery()
	_ecology = seeded
	var habitat: Vector2i = _river()
	var row: int = _stock_row(habitat, TROUT_INDEX)
	fishery.force_population_milli(row, SEED_LANDING_ON_40_PERCENT)
	fishery.force_restocking(row, true)
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_RECOVERY_LEVEL,
		"the day's recovery lands the stock exactly on 40% of capacity")
	assert_true(_ecology.fishing().is_restocking(row), "and exactly 40% does not release it")


func test_the_restocking_latch_clears_one_milli_unit_above_forty_percent() -> void:
	"""The other side of that line: one milli-U higher and the latch must release."""
	var seeded: SeededEcology = SeededEcology.new()
	var fishery: SeededFishing = seeded.seed_the_fishery()
	_ecology = seeded
	var habitat: Vector2i = _river()
	var row: int = _stock_row(habitat, TROUT_INDEX)
	fishery.force_population_milli(row, SEED_LANDING_ABOVE_40_PERCENT)
	fishery.force_restocking(row, true)
	assert_true(_run(DAY_2_TICK), "the boundary runs")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_RECOVERY_LEVEL + 1,
		"the day's recovery lands one milli-U above 40%")
	assert_false(_ecology.fishing().is_restocking(row), "which does release it")


# --- §5.5 forage ----------------------------------------------------------------------------------

func test_a_forage_patch_grows_by_decision_0036s_additive_rule() -> void:
	"""`min(K-P, floor((K-P)*r*S/1000000) + 1000)`: the 1 U is a TERM, not a floor."""
	var basin: Vector2i = _basin(10000)
	var row: int = _patch_row(basin, HERB)
	assert_equal(_ecology.forage().stock_milli_of(row).value, HERB_INITIAL, "herb starts at 80%")
	assert_true(_run(DAY_2_TICK), "the spring boundary runs")
	assert_equal(_ecology.forage().stock_milli_of(row).value, HERB_AFTER_ONE_SPRING_DAY,
		"128000 + 2560 + 1000, not 128000 + 2560")
	assert_equal(_day.forage_patches_grown, 3,
		"herb, mushrooms and roots grow in spring; berries and nuts are dormant")


func test_a_forage_patch_grows_by_the_new_days_season_not_a_fixed_one() -> void:
	"""ARCH-TICK-003: the season is the NEW calendar day's, and §5.5's `S` moves every value.

	Decision 0036's own worked row: herb, winter, `K-P` 32000 grows 1512, not spring's 3560.
	`min(32000, floor(32000*80*200/1000000) + 1000)` = 512 + 1000.
	"""
	var basin: Vector2i = _basin(10000)
	var row: int = _patch_row(basin, HERB)
	assert_true(_run(WINTER_DAY_1_TICK), "the winter boundary runs")
	assert_equal(_day.season, WINTER, "on the new day's season")
	assert_equal(_ecology.forage().stock_milli_of(row).value, HERB_INITIAL + HERB_WINTER_GROWTH,
		"128000 + 1512, which is winter's growth and not spring's 3560")


func test_a_dormant_kind_grows_nothing_and_is_not_an_error() -> void:
	"""§5.5: an unavailable patch is "dormant, not destroyed"; spring berries grow 0."""
	var basin: Vector2i = _basin(10000)
	var row: int = _patch_row(basin, BERRIES)
	var before: int = _ecology.forage().stock_milli_of(row).value
	assert_true(_run(DAY_2_TICK), "the spring boundary runs and commits")
	assert_equal(_ecology.forage().stock_milli_of(row).value, before,
		"spring berries have availability 0, so nothing grows")


func test_a_claim_outstanding_across_midnight_consumes_the_new_days_allowance() -> void:
	"""Decision 0030 §4.4's ruled order, driven from the stage: reset H, PRESERVE R, then admit."""
	_use_job_store()
	var basin: Vector2i = _basin(10000)
	var job: Vector2i = _make_job(10)
	assert_true(_ecology.forage().harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U collected")
	assert_true(_ecology.forage().claim_forage(job, basin, BERRIES, 3000, SUMMER, false).ok,
		"3 U is claimed and still outstanding")
	assert_equal(_ecology.forage().available_quota_milli(basin, SUMMER).value, 3000,
		"10000 - 4000 collected - 3000 reserved is today's remainder")
	assert_true(_run(SUMMER_DAY_1_TICK), "the boundary runs")
	assert_equal(_day.forage_claims_released, 0, "the claim survives the crossing")
	assert_equal(_ecology.forage().harvested_today_milli_of(_zone_slot(basin)).value, 0,
		"the collected total is reset")
	assert_equal(_ecology.forage().quota_reserved_milli_of(_zone_slot(basin)).value, 3000,
		"and the outstanding claim is preserved with it")
	assert_equal(_ecology.forage().available_quota_milli(basin, SUMMER).value, 7000,
		"so the claim consumes part of the NEW day's allowance, not the old one")


func test_a_claim_on_a_kind_dormant_in_the_new_season_is_released() -> void:
	"""§4.4's fourth step, reached through the stage: winter closes berries, so its claim goes."""
	_use_job_store()
	var basin: Vector2i = _basin(1000000)
	var berry_job: Vector2i = _make_job(10)
	var root_job: Vector2i = _make_job(20)
	var berry_row: int = _ecology.forage().claim_forage(
		berry_job, basin, BERRIES, 2000, AUTUMN, false).value
	var root_row: int = _ecology.forage().claim_forage(
		root_job, basin, 4, 2000, AUTUMN, false).value
	assert_true(_run(WINTER_DAY_1_TICK), "the winter boundary runs")
	assert_equal(_day.forage_claims_released, 1, "exactly one claim is released")
	assert_false(_ecology.forage().is_claim_active(berry_row), "the dormant kind's claim went")
	assert_true(_ecology.forage().is_claim_active(root_row), "the available kind's claim stayed")


func test_annual_patch_counters_do_not_reset_at_an_ordinary_midnight() -> void:
	"""Decision 0030 §4.4: annual counters reset only at the YEAR boundary."""
	var basin: Vector2i = _basin(1000000)
	var row: int = _patch_row(basin, BERRIES)
	assert_true(_ecology.forage().harvest(basin, BERRIES, 40000, SUMMER, false).ok, "40 U taken")
	assert_equal(_ecology.forage().harvested_year_milli_of(row).value, 40000, "the year holds it")
	assert_true(_run(WINTER_DAY_1_TICK), "an ordinary midnight runs")
	assert_false(_day.annual_counters_reset, "which is not a year boundary")
	assert_equal(_ecology.forage().harvested_year_milli_of(row).value, 40000,
		"and the annual counter is untouched by it")


func test_annual_patch_counters_reset_at_the_year_boundary() -> void:
	"""The other half: spring day 1 of year 2 does clear the year-to-date totals."""
	var basin: Vector2i = _basin(1000000)
	var row: int = _patch_row(basin, BERRIES)
	assert_true(_ecology.forage().harvest(basin, BERRIES, 40000, SUMMER, false).ok, "40 U taken")
	assert_true(_run(YEAR_2_DAY_1_TICK), "the midnight opening absolute day 49 runs")
	assert_equal(_day.season, SPRING, "which is spring")
	assert_equal(_day.season_day, 1, "day 1, so a new year")
	assert_true(_day.annual_counters_reset, "the year boundary is reported")
	assert_equal(_ecology.forage().harvested_year_milli_of(row).value, 0,
		"and the year-to-date total is cleared")


# --- §5.6 hives -----------------------------------------------------------------------------------

func test_an_unserviced_hive_loses_two_hundred_strength_for_the_completed_day() -> void:
	"""REQ-SET-083: the day SETTLED is the day that ended, judged on the service it received."""
	var hive: Vector2i = _hive(1)
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH, "a new hive starts at 8000")
	assert_true(_run(DAY_3_TICK), "the midnight opening day 3 settles day 2")
	assert_equal(_day.hives_advanced, 1, "one hive was advanced")
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH - UNSERVICED_LOSS,
		"day 2 was never serviced, so 200 strength is lost")


func test_a_hive_serviced_on_the_completed_day_produces_and_is_not_charged() -> void:
	"""The colonisation day counts as serviced, so the midnight after it produces instead."""
	var hive: Vector2i = _hive(1)
	var slot: int = _ecology.directory().get_typed_row(hive)
	assert_true(_run(DAY_2_TICK), "the midnight opening day 2 settles day 1")
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH + SPRING_TENDED_GAIN,
		"a tended spring day restores 300 after production")
	assert_equal(_ecology.orchard_hive().hive_honey_milli_of(slot).value, HONEY_AT_FULL_STRENGTH,
		"2 U x 8000/10000 of honey")
	assert_equal(_ecology.orchard_hive().hive_wax_milli_of(slot).value, WAX_AT_FULL_STRENGTH,
		"0.25 U x 8000/10000 of wax")


func test_a_winter_hive_without_feed_loses_five_hundred_strength() -> void:
	"""§5.6's winter day: no produce, and a missing feed costs 500."""
	var hive: Vector2i = _hive(1)
	assert_true(_run(WINTER_DAY_2_TICK), "the midnight opening winter day 2 settles winter day 1")
	assert_equal(_day.season, WINTER, "the new day is winter")
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH - UNFED_WINTER_LOSS,
		"the settled winter day found no feed")


func test_a_fed_winter_hive_eats_its_feed_and_keeps_its_strength() -> void:
	"""The other winter branch: 500 milli-U of stocked feed is consumed instead."""
	var hive: Vector2i = _hive(1)
	var slot: int = _ecology.directory().get_typed_row(hive)
	assert_true(_ecology.orchard_hive().add_hive_feed(hive, WINTER_FEED_PER_DAY).ok, "feed stocked")
	assert_true(_run(WINTER_DAY_2_TICK), "the winter boundary runs")
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH, "the colony is not weakened")
	assert_equal(_ecology.orchard_hive().hive_feed_milli_of(slot).value, 0, "and the feed is gone")


func test_a_hive_reaching_zero_strength_is_reported_abandoned() -> void:
	"""§5.6: a hive that reaches 0 is abandoned, and the stage reports it rather than hiding it."""
	var hive: Vector2i = _hive(1)
	assert_true(_ecology.orchard_hive().restore_hive_state(hive, UNSERVICED_LOSS, 0, 0, 0, 1).ok,
		"the hive is placed one unserviced day from the floor")
	assert_true(_run(DAY_3_TICK), "the boundary settles an unserviced day 2")
	assert_equal(_hive_strength(hive), 0, "the colony reaches the abandonment floor")
	assert_equal(_day.hives_abandoned, 1, "and exactly one abandonment is reported")


func test_a_strength_change_crossing_five_thousand_refreshes_the_orchard_links() -> void:
	"""Decision 0044: an eligibility crossing refreshes the recipient slices SYNCHRONOUSLY."""
	var hive: Vector2i = _hive(1)
	var orchard: OrchardHiveScript.OpResult = _ecology.orchard_hive().plant_orchard(
		ORCHARD_ORIGIN, ORCHARD_ORIGIN, OrchardHiveScript.SPECIES_APPLE, 1)
	assert_true(orchard.ok, "the fixture orchard must be planted (%s)" % orchard.error)
	var row: int = _ecology.orchard_hive().orchard_row_of(orchard.ref).value
	var count: IntMathScript.IntResult = IntMathScript.IntResult.new()
	assert_true(_ecology.orchard_hive().restore_hive_state(
		hive, HIVE_HEALTHY_LINE + UNSERVICED_LOSS - 100, 0, 0, 0, 1).ok, "strength is set to 5100")
	assert_true(_ecology.orchard_hive().orchard_hive_count_into(row, count), "the slice reads")
	assert_equal(count.value, 1, "an eligible hive is linked before the day")
	assert_true(_run(DAY_3_TICK), "an unserviced day takes it to 4900")
	assert_equal(_hive_strength(hive), HIVE_HEALTHY_LINE - 100, "which is below the 5000 line")
	assert_equal(_day.hive_eligibility_crossings, 1, "the crossing is reported")
	assert_true(_ecology.orchard_hive().orchard_hive_count_into(row, count), "the slice reads")
	assert_equal(count.value, 0, "and the link was refreshed away by the committed change")
	assert_true(_ecology.orchard_hive().check_orchard_links(orchard.ref),
		"the slice is consistent, so no read had to repair it")


func test_a_strength_change_inside_the_band_crosses_nothing() -> void:
	"""A change that stays on one side of 5000 must not be reported as a crossing."""
	var hive: Vector2i = _hive(1)
	assert_true(_run(DAY_3_TICK), "an unserviced day takes 8000 to 7800")
	assert_equal(_hive_strength(hive), HIVE_START_STRENGTH - UNSERVICED_LOSS, "7800")
	assert_equal(_day.hive_eligibility_crossings, 0, "both sides of the change are eligible")


# --- §5.9 resource nodes ---------------------------------------------------------------------------

func test_an_exhausted_tree_regrows_on_its_forty_eighth_day() -> void:
	"""REQ-SET-138: "Trees regrow after 48 days when their stumps remain"."""
	var node: int = _felled_tree(2, TREE_REGROW_DAYS)
	assert_equal(_ecology.resource_nodes().quantity_milli_of(node).value, 0, "the stump is empty")
	assert_true(_run(YEAR_2_DAY_1_TICK), "day 49 is one day early for a day-2 felling")
	assert_equal(_day.nodes_regrown, 0, "so nothing regrows")
	assert_equal(_ecology.resource_nodes().quantity_milli_of(node).value, 0, "the stump stands")
	assert_true(_run(DAY_50_TICK), "day 50 is `planted_day 2 + 48`")
	assert_equal(_day.nodes_regrown, 1, "and the node is restored")
	assert_equal(_ecology.resource_nodes().quantity_milli_of(node).value, TREE_CAPACITY_MILLI,
		"to its full capacity")
	assert_false(_ecology.resource_nodes().is_exhausted(node), "and it is no longer exhausted")


func test_a_node_with_no_regrow_period_never_regrows() -> void:
	"""`regrow_days == 0` reads as "never regrows"; a quarry does not refill the day it empties."""
	var node: int = _felled_tree(2, 0)
	assert_true(_run(DAY_3_TICK), "the next boundary runs")
	assert_equal(_day.nodes_regrown, 0, "and restores nothing")
	assert_true(_run(DAY_50_TICK), "nor does a much later one")
	assert_equal(_day.nodes_regrown, 0, "at any distance from the felling")
	assert_equal(_ecology.resource_nodes().quantity_milli_of(node).value, 0, "the row stays empty")


func test_a_node_that_was_never_felled_is_left_alone() -> void:
	"""A mature node is not "topped up" by a midnight; only an exhausted one has a cycle."""
	var tile: int = _ecology.resource_nodes().tile_index(TREE_TILE_X, TREE_TILE_Z).value
	var made: ResourceNodesScript.OpResult = _ecology.resource_nodes().create_at_tile(
		tile, 1, TREE_CAPACITY_MILLI, TREE_REGROW_DAYS, 1)
	assert_true(made.ok, "the node is placed at full capacity")
	assert_true(_ecology.resource_nodes().harvest(made.value, 5000, 2).ok, "5 U is taken")
	assert_true(_run(DAY_50_TICK), "a boundary well past its regrow period runs")
	assert_equal(_day.nodes_regrown, 0, "a live node has no pending cycle")
	assert_equal(_ecology.resource_nodes().quantity_milli_of(made.value).value,
		TREE_CAPACITY_MILLI - 5000, "so the partial node keeps exactly what it held")


# --- the legs this stage does not own ---------------------------------------------------------------

func test_the_stage_creates_and_advances_no_job() -> void:
	"""The producers are their own layer: no Job row is written and JOB_STATE_WORK is never set."""
	_use_job_store()
	_basin(10000)
	_river()
	_hive(1)
	assert_equal(_jobs.job_count(), 0, "the queue starts empty")
	assert_true(_run(DAY_2_TICK), "a full ecology day runs")
	assert_equal(_jobs.job_count(), 0, "and creates no job")


func test_the_stage_advances_no_orchard_and_reads_no_weather() -> void:
	"""ARCH-SYS-006 owns `apply_orchard_day()`; it needs a temperature this stage never has."""
	var planted: OrchardHiveScript.OpResult = _ecology.orchard_hive().plant_orchard(
		ORCHARD_ORIGIN, ORCHARD_ORIGIN, OrchardHiveScript.SPECIES_APPLE, 1)
	assert_true(planted.ok, "the fixture orchard must be planted (%s)" % planted.error)
	var slot: int = _ecology.directory().get_typed_row(planted.ref)
	assert_equal(_ecology.orchard_hive().age_days_of(slot).value, 0, "a new block is 0 days old")
	assert_true(_run(DAY_2_TICK), "a full ecology day runs")
	assert_equal(_ecology.orchard_hive().age_days_of(slot).value, 0,
		"and the block does not age: that is increment 10's leg, not this one")
	assert_equal(_ecology.orchard_hive().chill_days_of(slot).value, 0,
		"and no chill day is accumulated from a temperature nothing supplied")


func test_an_empty_ecology_runs_a_day_that_changes_nothing() -> void:
	"""A settlement with no world generated has nothing to advance, and says so honestly."""
	assert_true(_run(DAY_2_TICK), "the boundary still commits")
	assert_equal(_day.fish_stocks_recovered, 0, "no stock")
	assert_equal(_day.forage_patches_grown, 0, "no patch")
	assert_equal(_day.hives_advanced, 0, "no hive")
	assert_equal(_day.nodes_regrown, 0, "no node")
	assert_equal(_ecology.last_day_run(), 2, "and the day is still consumed")


func test_a_refused_day_clears_every_count_on_the_result() -> void:
	"""A refusal carries no numbers, so an unchecked result cannot surface a previous day's."""
	_river()
	assert_true(_run(DAY_2_TICK), "a real day fills the result")
	assert_equal(_day.fish_stocks_recovered, 3, "with three recovered stocks")
	assert_false(_run(TICKS_PER_DAY), "then a non-boundary tick is refused")
	assert_equal(_day.fish_stocks_recovered, 0, "and the stale count is cleared")
	assert_equal(_day.absolute_day, 0, "along with the day it belonged to")
	assert_false(_day.ok, "the result reports the refusal")


func test_a_leg_refusing_midway_carries_no_count_from_the_legs_that_ran() -> void:
	"""A refused day names the store that refused and reports NOTHING the earlier legs did.

	The fish leg runs before the forage leg, so a corrupt patch refuses AFTER three stocks have
	already recovered. The recovery is real and stands in the store -- the day is consumed and
	`ecology.gd` says why it may not be replayed -- but the RESULT must carry no half-day of
	counts, and must not name a day it did not finish.
	"""
	var seeded: SeededEcology = SeededEcology.new()
	var forage: CorruptibleForage = seeded.seed_the_forage()
	_ecology = seeded
	var habitat: Vector2i = _river()
	var basin: Vector2i = _basin(10000)
	forage.force_stock_milli(_patch_row(basin, HERB), HERB_CAPACITY + 1)
	assert_false(_run(DAY_2_TICK), "the forage leg refuses the corrupt patch")
	assert_equal(_day.error, &"STOCK_ABOVE_CAPACITY", "and the store's own code travels out")
	assert_equal(_day.fish_stocks_recovered, 0,
		"the three stocks the fish leg recovered are NOT reported by a refused day")
	assert_equal(_day.absolute_day, 0, "nor is the day it did not finish")
	assert_equal(_day.boundary_tick, 0, "nor the tick it was given")
	assert_equal(_population(habitat, TROUT_INDEX), TROUT_AFTER_ONE_DAY,
		"the committed recovery itself stands, which is why the day stays consumed")
	assert_equal(_ecology.last_day_run(), 2, "and the latch names the day that refused")
