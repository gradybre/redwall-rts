extends "res://test/framework/test_case.gd"
## The fishing revamp (#49, decisions 1711-1713): §5.4's hazard and rare-quality rolls on the FISHING stream and the
## hazard's injury through the infirmary's hook; catch plans (§5.4's auto mode, REQ-SET-046's fallback) and the traps'
## collection policy (review ECO-024, ECO-026); each water's record, the recovery prediction against the store's own
## midnight, and the intensive policy's card (review ECO-025, REQ-SET-049). Built over the placeholder cast on the real
## layout and water, as test_demo_fishery.gd builds its rig. Expected numbers are restated from GDD §5.4 and §5.7.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Injury := preload("res://scripts/core/injury.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const RollsScript := preload("res://demo/fishery/fishing_rolls.gd")
const PlanScript := preload("res://demo/fishery/catch_plan.gd")
const StewardScript := preload("res://demo/fishery/fishery_stewardship.gd")
const DemoFisheryScript := preload("res://demo/fishery/demo_fishery.gd")
const CareRules := preload("res://demo/infirmary/care_rules.gd")
const NightRoutine := preload("res://demo/burrow/night_routine.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
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
const BoatRescueScript := preload("res://demo/boats/boat_rescue.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 6000

## Rolls that always hit the hazard and the rare bonus (the draws are still the stream's two).
class SureRolls:
	extends "res://demo/fishery/fishing_rolls.gd"

	func resolve_into(gear: int, danger: int, crew_skill: int, crew: int, catch_milli: int, out: Outcome) -> void:
		"""The real resolution, then a forced hit and rare success."""
		super.resolve_into(gear, danger, crew_skill, crew, catch_milli, out)
		out.hurt = true
		out.excellent_milli = excellent_share(catch_milli)


class Rig:
	var cast: DemoCastScript = null
	var play: WaterplayScript = null
	var fishery: FisheryScript = null
	var pantry: PantryScript = null
	var calendar: CalendarScript = null
	var driver: Driver = null

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _hurts: Array = []


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()
	_hurts = []


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
	"""The village's water, built once."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


static func _new_driver(start_tick: int = 0) -> Driver:
	"""A fishing driver over the real nine fish items (the weir offered at the run, 4.3 m)."""
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	return Driver.create(ids.ids, start_tick, 4403).driver as Driver


func _rig() -> Rig:
	"""The placeholder cast on the real layout, the water's play, and the fishery (06:00 spring 1)."""
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
	rig.driver = _new_driver()
	rig.calendar = CalendarScript.new()
	var weather := DemoWeatherScript.new()
	weather.observe(0, 1, 8, 120, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.fishery = FisheryScript.new()
	rig.fishery.configure(rig.cast, rig.driver, rig.pantry, TakesScript.new(), _services.stores, rig.calendar, weather,
		_map())
	var boats := BoatRescueScript.new()
	boats.configure(rig.fishery.fleet, _map(), rig.fishery.skills.can_helm)
	rig.play.rescue.boats = boats
	rig.fishery.hurt = _record_hurt
	return rig


func _record_hurt(who: int, kind: int, severity: int, loss: int) -> bool:
	"""The infirmary's hook, recorded."""
	_hurts.append([who, kind, severity, loss])
	return true


func _skip_days(rig: Rig, days: int) -> void:
	"""Move the rig's calendar and the store on by whole days (the stores' midnights run)."""
	rig.calendar.tick += days * SimClock.TICKS_PER_DAY
	rig.driver.advance_ticks(days * SimClock.TICKS_PER_DAY)


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step everything until `done()` (bounded), handing waiting jobs to free residents as the work board does."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.driver.advance_ticks(maxi(rig.calendar.tick - rig.driver.completed_tick(), 0))
		rig.play.step(usec)
		rig.fishery.update(usec)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part: each waiting job to the first idle resident who may take it."""
	var f: FisheryScript = rig.fishery
	for j: int in Tables.MAX_JOBS:
		if not f.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = f.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.in_water and f.eligibility(j, who).is_empty() \
					and f.claim(j, who):
				break


# --- the rolls (decision 1711) ----------------------------------------------------------------------

func test_hazard_chance_is_the_gdd_formula_for_the_whole_crew() -> void:
	"""§5.4: max(1, base*(1+danger) - 2*skill - 4*additional crew); net 12, trap 8, weir 5, boat 20, ice 24."""
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_HAND_NET, 0, 0, 1), 12, "net")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_TRAP, 0, 0, 1), 8, "trap")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_WEIR, 0, 0, 1), 5, "weir")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_ICE_KIT, 0, 0, 1), 24, "ice")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_BOAT, 0, 0, 2), 16, "a boat of two: 20 - 4")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_BOAT, 0, 2, 2), 12, "and its group skill 2: - 4")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_HAND_NET, 1, 0, 1), 24, "danger 1 doubles the base")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_HAND_NET, 0, 10, 1), 1, "never below 1")
	assert_equal(RollsScript.hazard_chance(Fishing.GEAR_HAND_NET, 0, 0, 0), 12, "no crew counts as one")


func test_rare_chance_and_the_excellent_share() -> void:
	"""§5.4: min(1000, 100 + 30*skill) per 10000; success makes 25% of the catch EXCELLENT, rounded down."""
	assert_equal(RollsScript.rare_chance(0), 100, "skill 0")
	assert_equal(RollsScript.rare_chance(4), 220, "skill 4")
	assert_equal(RollsScript.rare_chance(30), 1000, "the cap: skill 30")
	assert_equal(RollsScript.rare_chance(31), 1000, "capped beyond")
	assert_equal(RollsScript.rare_chance(-3), 100, "no negative skill")
	assert_equal(RollsScript.excellent_share(9600), 2400, "a quarter")
	assert_equal(RollsScript.excellent_share(3), 0, "rounded down")
	assert_equal(RollsScript.excellent_share(-5), 0, "never negative")


func test_a_roll_succeeds_strictly_below_its_chance() -> void:
	"""A draw 0..9999 against a chance per 10000: draw == chance fails, chance - 1 succeeds; chance 0 never."""
	assert_true(RollsScript.hits(11, 12), "11 < 12")
	assert_false(RollsScript.hits(12, 12), "12 is not below 12")
	assert_false(RollsScript.hits(0, 0), "no chance, no hit")
	assert_true(RollsScript.hits(9999, 10000), "a certain chance")


func test_settle_decides_at_the_exact_boundaries() -> void:
	"""An outcome's draws against its chances: a hazard draw one below the chance hurts, at it does not; a rare draw one
	below makes a quarter EXCELLENT, at it none."""
	var out := RollsScript.Outcome.new()
	out.hazard_per_10000 = 12
	out.rare_per_10000 = 190
	out.hazard_roll = 11
	out.rare_roll = 189
	RollsScript.settle(out, Fishing.GEAR_HAND_NET, 8000)
	assert_true(out.hurt, "11 against 12: hurt")
	assert_equal(out.excellent_milli, 2000, "189 against 190: a quarter")
	out.hazard_roll = 12
	out.rare_roll = 190
	RollsScript.settle(out, Fishing.GEAR_HAND_NET, 8000)
	assert_false(out.hurt, "12 against 12: not")
	assert_equal(out.excellent_milli, 0, "190 against 190: none")


func test_two_draws_a_cycle_hazard_then_quality_matching_the_stream() -> void:
	"""ARCH-RNG-002: one hazard then one rare roll per completed cycle on FISHING, seeded from the demo world's seed;
	each outcome is exactly an independent replica's draws compared with the chances."""
	var rolls := RollsScript.new()
	var replica := Rng.new()
	replica.seed_world(CareRules.WORLD_SEED)
	var read := IntMath.IntResult.new()
	var out := RollsScript.Outcome.new()
	var hits: int = 0
	var fine: int = 0
	for n: int in 300:
		var gear: int = [Fishing.GEAR_HAND_NET, Fishing.GEAR_BOAT, Fishing.GEAR_ICE_KIT][n % 3]
		assert_true(rolls.roll_into(Vector2i(n, 1), gear, 0, 3, 1, 8000, out), "rolled %d" % n)
		replica.draw_below_into(Rng.STREAM_FISHING, 10000, read)
		assert_equal(out.hazard_roll, read.value, "hazard draw %d" % n)
		assert_equal(out.hurt, read.value < RollsScript.hazard_chance(gear, 0, 3, 1), "hit %d" % n)
		hits += 1 if out.hurt else 0
		replica.draw_below_into(Rng.STREAM_FISHING, 10000, read)
		assert_equal(out.rare_roll, read.value, "rare draw %d" % n)
		assert_equal(out.excellent_milli, 2000 if read.value < 190 else 0, "excellent %d" % n)
		fine += out.excellent_milli
		assert_equal(out.expedition, Vector2i(n, 1), "keyed by its expedition")
	assert_equal(rolls.draws(), 600, "exactly two draws a cycle")
	assert_equal(rolls.cycles_rolled, 300, "counted")
	assert_equal(rolls.injuries, hits, "the injuries counted")
	assert_true(fine > 0, "some rare successes in 300 at 1.9%")
	assert_equal(rolls.excellent_milli, fine, "the excellent catch totalled")


func test_the_injury_is_the_gdd_bite_or_exposure_by_gear() -> void:
	"""§5.4: a net, trap or weir hazard is a severity 1 bite, −20; a boat or ice one severity 2 exposure, −35."""
	var rolls := SureRolls.new()
	var out := RollsScript.Outcome.new()
	rolls.roll_into(Vector2i(1, 1), Fishing.GEAR_TRAP, 0, 0, 1, 0, out)
	assert_equal([out.injury_kind, out.injury_severity, out.injury_loss], [Injury.KIND_BITE, Injury.SEVERITY_MINOR, 20],
		"a trap: a bite")
	rolls.roll_into(Vector2i(2, 1), Fishing.GEAR_ICE_KIT, 0, 0, 1, 0, out)
	assert_equal([out.injury_kind, out.injury_severity, out.injury_loss],
		[Injury.KIND_EXPOSURE, Injury.SEVERITY_SERIOUS, 35], "the ice: exposure")
	assert_true(RollsScript.serious(Fishing.GEAR_BOAT) and not RollsScript.serious(Fishing.GEAR_WEIR), "boat serious")
	assert_true(RollsScript.hazard_words(Fishing.GEAR_HAND_NET, RollsScript.ENCOUNTER_EEL).contains("eel"), "an eel")
	assert_true(RollsScript.hazard_words(Fishing.GEAR_TRAP, RollsScript.ENCOUNTER_PIKE).contains("pike"), "a pike")
	assert_true(RollsScript.hazard_words(Fishing.GEAR_BOAT, 0).contains("cold water"), "a boat: the cold water")
	assert_true(RollsScript.hazard_words(Fishing.GEAR_ICE_KIT, 0).contains("ice"), "the ice")


func test_the_encounter_is_a_habitat_day_hash_drawing_nothing() -> void:
	"""§5.4: pike or eel by habitat/day hash -- stable, both occur, and no stream draw."""
	var rolls := RollsScript.new()
	var seen := PackedInt32Array([0, 0])
	for day: int in 40:
		var e: int = RollsScript.encounter_of(Fishing.HABITAT_RIVER, day)
		assert_equal(e, RollsScript.encounter_of(Fishing.HABITAT_RIVER, day), "stable")
		assert_equal(e, Rng.hash_pair(Fishing.HABITAT_RIVER, day) & 1, "the hash's low bit")
		seen[e] += 1
	assert_true(seen[0] > 0 and seen[1] > 0, "pike and eel both described")
	assert_equal(rolls.draws(), 0, "no draw")


# --- catch plans and collection (decision 1712) -----------------------------------------------------

func test_auto_order_is_np_per_work_then_closure_then_species_id() -> void:
	"""§5.4's auto mode: higher NP/work first (cross-multiplied), then the earlier closure, then the lower species ID."""
	assert_true(PlanScript.better(2000, 10, 9, 5, 1000, 10, 1, 0), "more NP")
	assert_true(PlanScript.better(1000, 5, 9, 5, 1500, 10, 1, 0), "more NP per work")
	assert_false(PlanScript.better(1000, 10, 9, 5, 1000, 5, 1, 0), "less NP per work")
	assert_true(PlanScript.better(1000, 10, 2, 5, 1000, 10, 3, 0), "equal: the earlier closure")
	assert_true(PlanScript.better(1000, 10, 3, 1, 1000, 10, 3, 2), "then the lower species ID")
	assert_false(PlanScript.better(1000, 10, 3, 2, 1000, 10, 3, 1), "not the higher")
	assert_equal(PlanScript.predicted_np(2500), 3500000, "§5.7's 1400 NP a unit")
	assert_equal(PlanScript.predicted_np(-1), 0, "nothing")
	assert_true(PlanScript.is_auto(PlanScript.PLAN_AUTO) and not PlanScript.is_auto(2), "the fourth choice")


func test_best_catch_picks_the_largest_legal_expected_catch() -> void:
	"""Spring 1 at the run, a hand net at skill 0: the species with the most expected catch; spring 5 trout's spawning
	closure takes it out of the running."""
	var driver: Driver = _new_driver()
	var p := Driver.Preview.new()
	var best: int = PlanScript.best_species(driver, Driver.SITE_RUN, Rules.METHOD_NET, 0, p)
	var most: int = -1
	var most_catch: int = -1
	for s: int in 3:
		driver.preview_into(Driver.SITE_RUN, s, Fishing.GEAR_HAND_NET, 0, p)
		if p.ok and p.expected_catch_milli > most_catch:
			most = s
			most_catch = p.expected_catch_milli
	assert_true(best >= 0, "something to fish")
	driver.preview_into(Driver.SITE_RUN, best, Fishing.GEAR_HAND_NET, 0, p)
	assert_equal(p.expected_catch_milli, most_catch, "the most expected catch (%d)" % most)
	driver.advance_ticks(4 * SimClock.TICKS_PER_DAY)
	assert_equal(driver.season_day(), 5, "spring 5")
	var trout: int = 0
	assert_equal(driver.species_key_of(Driver.SITE_RUN, trout), &"trout", "trout is the run's first")
	assert_true(PlanScript.best_species(driver, Driver.SITE_RUN, Rules.METHOD_NET, 0, p) != trout, "trout closed")
	assert_equal(PlanScript.best_species(null, Driver.SITE_RUN, Rules.METHOD_NET, 0, p), -1, "no driver: none")


func test_best_catch_is_none_when_nothing_may_be_fished() -> void:
	"""Every river species closed by its event bit: no auto pick."""
	var driver: Driver = _new_driver()
	for s: int in 3:
		driver.store().set_closed(driver.habitat_ref_of_site(Driver.SITE_RUN), s, true)
	assert_equal(PlanScript.best_species(driver, Driver.SITE_RUN, Rules.METHOD_NET, 0, Driver.Preview.new()), -1, "none")


func test_days_to_closure_scans_the_gdd_windows() -> void:
	"""Spring 1: trout's spawning closure is spring 5 (4 days), carp's spring 8 (7); dace has none in a year."""
	var driver: Driver = _new_driver()
	assert_equal(driver.days_to_closure(Driver.SITE_RUN, 0), 4, "trout")
	assert_equal(driver.days_to_closure(Driver.SITE_RUN, 1), Driver.REOPEN_SCAN_DAYS + 1, "dace: none")
	assert_equal(driver.species_key_of(Driver.SITE_POND, 1), &"carp", "the pond's second")
	assert_equal(driver.days_to_closure(Driver.SITE_POND, 1), 7, "carp")
	driver.advance_ticks(4 * SimClock.TICKS_PER_DAY)
	assert_equal(driver.days_to_closure(Driver.SITE_RUN, 0), 0, "closed today")


func test_collection_policy_morning_window_and_warned_closure() -> void:
	"""The morning run's window is 06:00-10:00 (06:00 is the night's dawn); a closure tomorrow is a warned one."""
	assert_equal(PlanScript.MORNING_FROM_HOUR, NightRoutine.DAWN_HOUR, "the night's dawn")
	assert_false(PlanScript.in_morning(5), "05:00 waits")
	assert_true(PlanScript.in_morning(6), "06:00")
	assert_true(PlanScript.in_morning(9), "09:00")
	assert_false(PlanScript.in_morning(10), "10:00 is past it")
	assert_false(PlanScript.in_morning(15), "the afternoon waits")
	assert_true(PlanScript.closes_soon(0) and PlanScript.closes_soon(1), "closed today or tomorrow: now")
	assert_equal(PlanScript.next_morning_tick(0), 0, "tick 0 is 06:00 itself (at or after)")
	assert_equal(PlanScript.next_morning_tick(1), SimClock.TICKS_PER_DAY, "just after 06:00: tomorrow's")
	var noon: int = 6 * SimClock.TICKS_PER_HOUR
	assert_equal(PlanScript.next_morning_tick(noon), SimClock.TICKS_PER_DAY, "noon: tomorrow 06:00")
	assert_equal(PlanScript.next_morning_tick(SimClock.TICKS_PER_DAY - 1), SimClock.TICKS_PER_DAY, "05:59: 06:00")
	assert_false(PlanScript.closes_soon(2), "the day after: waits")


# --- stewardship (decision 1713) ----------------------------------------------------------------------

func test_the_prediction_is_the_stores_own_midnight() -> void:
	"""grow_milli is fishing.gd's recovery to the milli-U for every inland stock, and a chain of it is the store after
	real midnights."""
	var driver: Driver = _new_driver()
	var store: Fishing = driver.store()
	var predicted := PackedInt64Array()
	for site: int in [Driver.SITE_RUN, Driver.SITE_POND]:
		for s: int in 3:
			var row: int = driver.stock_row(site, s)
			var p: int = store.population_milli_of(row).value
			var k: int = store.stock_capacity_milli_of(row).value
			var species: int = driver.species_row_of(site, s)
			assert_equal(StewardScript.grow_milli(species, p, k, 2, 1) - p, store.daily_recovery_milli(row, 2, 1).value,
				"%s on autumn 1" % Fishing.SPECIES_KEYS[species])
			for day: int in 5:
				p = StewardScript.grow_milli(species, p, k, 0, day + 2)
			predicted.append(p)
	driver.advance_ticks(5 * SimClock.TICKS_PER_DAY)
	var k_index: int = 0
	for site: int in [Driver.SITE_RUN, Driver.SITE_POND]:
		for s: int in 3:
			assert_equal(store.population_milli_of(driver.stock_row(site, s)).value, predicted[k_index], "after 5 days")
			k_index += 1
	assert_equal(StewardScript.grow_milli(Fishing.SPECIES_TROUT, 600000, 600000, 0, 1), 600000, "full stays full")


func test_days_to_recover_counts_to_strictly_above_forty_percent() -> void:
	"""From the 10% floor, back strictly above 40%; already above: 0; exactly 40% is not above."""
	var steward := StewardScript.new()
	var k: int = 600000
	assert_equal(steward.days_to_recover(Fishing.SPECIES_TROUT, 300000, k, 0), 0, "50%: already")
	assert_true(steward.days_to_recover(Fishing.SPECIES_TROUT, 240000, k, 0) > 0, "exactly 40% is not above")
	var days: int = steward.days_to_recover(Fishing.SPECIES_TROUT, 60000, k, 0)
	var p: int = 60000
	var scan := SimClock.Calendar.new(0)
	for day: int in days:
		scan.set_tick((day + 1) * SimClock.TICKS_PER_DAY - SimClock.CALENDAR_OFFSET_TICKS)
		assert_true(100 * p <= 40 * k, "not yet above 40%% before day %d" % day)
		p = StewardScript.grow_milli(Fishing.SPECIES_TROUT, p, k, scan.season, scan.season_day)
	assert_true(100 * p > 40 * k, "above after %d days" % days)
	assert_equal(steward.days_to_recover(Fishing.SPECIES_TROUT, 0, 0, 0), -1, "no capacity: never")
	var summer_12: int = (SimClock.DAYS_PER_SEASON * 2 - 1) * SimClock.TICKS_PER_DAY
	assert_equal(steward.days_to_recover(Fishing.SPECIES_SALMON, 60000, k, summer_12), 1,
		"salmon on summer 12: the first midnight is autumn 1's run, +300 U")
	assert_true(steward.days_to_recover(Fishing.SPECIES_SALMON, 60000, k, summer_12 - SimClock.TICKS_PER_DAY) > 1,
		"a day earlier the run is the second midnight")


func test_the_record_rolls_by_day_and_keeps_a_season() -> void:
	"""A catch on today's slot; a day on, still counted; a season on, gone. The dawn stock noted each day."""
	var driver: Driver = _new_driver()
	var steward := StewardScript.new()
	steward.record(Driver.SITE_RUN, 5000)
	assert_equal(steward.landed_recent(StewardScript.WATER_STREAM), 0, "before the first day is followed: nothing")
	steward.follow(driver)
	assert_equal(steward.stock_at_dawn[StewardScript.WATER_POND], steward.stock_now(driver, StewardScript.WATER_POND),
		"the pond's dawn stock")
	steward.record(Driver.SITE_FORD, 5000)
	steward.record(Driver.SITE_POND, 3000)
	steward.record(Driver.SITE_RUN, 0)
	assert_equal(steward.landed_recent(StewardScript.WATER_STREAM), 5000, "the ford is the stream")
	assert_equal(steward.landed_recent(StewardScript.WATER_POND), 3000, "the pond")
	driver.advance_ticks(SimClock.TICKS_PER_DAY)
	steward.follow(driver)
	steward.record(Driver.SITE_RUN, 1000)
	assert_equal(steward.landed_recent(StewardScript.WATER_STREAM), 6000, "yesterday's kept")
	driver.advance_ticks(StewardScript.RECORD_DAYS * SimClock.TICKS_PER_DAY)
	steward.follow(driver)
	assert_equal(steward.landed_recent(StewardScript.WATER_STREAM), 0, "a season on: gone")
	assert_equal(StewardScript.water_of_site(Driver.SITE_POND), StewardScript.WATER_POND, "the pond is the lake")


func test_record_line_and_intensive_card_show_the_figures() -> void:
	"""ECO-025's record and REQ-SET-049's card: the floor and every species' days back from it."""
	var driver: Driver = _new_driver()
	var steward := StewardScript.new()
	steward.follow(driver)
	var line: String = steward.record_line(driver, StewardScript.WATER_STREAM, func(m: int) -> String: return str(m))
	assert_true(line.begins_with("The stream: landed 0 in 12 days"), line)
	assert_true(line.contains("0 of 4 places in use") and line.contains("intensive off"), line)
	var caught: Driver.CatchResult = driver.resolve_cycle(Driver.SITE_RUN, 1, Fishing.GEAR_HAND_NET, 0)
	assert_true(caught.ok and caught.quantity_milli > 0, "a cycle taken from the stream")
	line = steward.record_line(driver, StewardScript.WATER_STREAM, func(m: int) -> String: return str(m))
	assert_true(line.contains("(−%d today)" % caught.quantity_milli), "the stock's fall today: " + line)
	assert_equal(StewardScript.days_words(-1), "not within two years", "the sentinel in words")
	assert_equal(StewardScript.days_words(5), "in about 5 days", "a prediction")
	var card: PackedStringArray = steward.intensive_lines(driver, Driver.SITE_POND)
	assert_true(card[0].contains("10% hard floor"), "the floor named")
	for key: String in ["perch", "carp", "whitefish"]:
		assert_true(card[1].contains(key), "%s's recovery" % key)
	assert_equal(steward.from_floor_days(driver, Driver.SITE_POND, 0), steward.days_to_recover(Fishing.SPECIES_PERCH,
		90000, 900000, 0), "perch from 10% of 900 U")


func test_intensive_is_the_stores_one_flag_per_water() -> void:
	"""The driver sets fishing.gd's flag for the site's habitat: the run and the ford share it, the pond does not."""
	var driver: Driver = _new_driver()
	assert_false(driver.intensive(Driver.SITE_RUN), "off at first")
	assert_true(driver.set_intensive(Driver.SITE_RUN, true), "set")
	assert_true(driver.intensive(Driver.SITE_FORD), "the ford is the same river")
	assert_false(driver.intensive(Driver.SITE_POND), "not the pond")
	var row: int = driver.stock_row(Driver.SITE_RUN, 1)
	assert_equal(driver.store().floor_percent_for(row, 0, 1).value, 10, "dace's floor 10%")
	driver.set_intensive(Driver.SITE_RUN, false)
	assert_equal(driver.store().floor_percent_for(row, 0, 1).value, 30, "back to 30%")
	assert_equal(driver.danger_of_site(Driver.SITE_RUN), 0, "the estuary's danger")
	assert_equal(driver.habitat_type_of_site(Driver.SITE_POND), Fishing.HABITAT_LAKE, "the pond is the lake")


func test_the_boat_preview_counts_its_second_crew() -> void:
	"""REQ-SET-055's risk for a boat of two: 20 - 4 = 16, not the lone fisher's 20."""
	var driver: Driver = _new_driver()
	var p := Driver.Preview.new()
	driver.preview_into(Driver.SITE_POND, 0, Fishing.GEAR_BOAT, 0, p, 1)
	assert_equal(p.injury_per_10000, 16, "a crew of two")
	driver.preview_into(Driver.SITE_POND, 0, Fishing.GEAR_BOAT, 0, p)
	assert_equal(p.injury_per_10000, 20, "one")
	var rig := _rig()
	assert_equal(rig.fishery.preview_of(Rules.METHOD_BOAT, Driver.SITE_POND, 0, 0).injury_per_10000, 16,
		"the fishery's card reckons the boat's two")
	assert_equal(rig.fishery.preview_of(Rules.METHOD_NET, Driver.SITE_POND, 0, 0).injury_per_10000, 12, "a net's one")


# --- in the fishery -------------------------------------------------------------------------------

func test_a_completed_net_trip_rolls_twice_and_records_its_catch() -> void:
	"""A bank net trip: two FISHING draws at completion, the water's record holds the catch, the trip its excellent."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_equal(f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_equal(f.rolls.draws(), 2, "two draws")
	assert_equal(f.steward.landed_recent(StewardScript.WATER_STREAM), f.caught_milli, "the stream's record")
	var rare: bool = RollsScript.hits(f.tables.t_rare_roll[0], RollsScript.rare_chance(f.skills.level_of(1)))
	assert_equal(f.tables.t_excellent[0], RollsScript.excellent_share(f.caught_milli) if rare else 0,
		"the quarter exactly when the departure's rare draw is below the chance")
	assert_equal(f.tables.t_hazard_roll[0], -1, "the draws resolved once")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "landed")


func test_a_cycle_called_off_after_departure_keeps_its_draws() -> void:
	"""ARCH-RNG-002: "already departed cancelled cycle retains saved rolls" -- drawn when the cycle opened at the bank,
	spent though it is called off; the next trip's cycle draws the next two."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing")
	assert_equal(f.rolls.draws(), 2, "drawn at departure")
	assert_true(f.tables.t_hazard_roll[0] >= 0 and f.tables.t_rare_roll[0] >= 0, "kept on the trip")
	assert_equal(f.cancel_trip(0), "", "called off")
	_run(rig, func() -> bool: return f.tables.trip_count() == 0)
	assert_equal(f.rolls.draws(), 2, "the two stay spent; no more")
	assert_equal(f.rolls.injuries, 0, "nothing resolved")


func test_a_trip_called_off_before_the_water_draws_nothing() -> void:
	"""ARCH-RNG-002: a cycle cancelled before it completes consumes no FISHING draw."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_equal(f.cancel_trip(0), "", "called off")
	_run(rig, func() -> bool: return f.tables.trip_count() == 0)
	assert_equal(f.rolls.draws(), 0, "nothing drawn")


func test_a_hazard_hurts_the_net_fisher_through_the_infirmary() -> void:
	"""A hit on a net trip: the infirmary's hook gets the fisher, a severity 1 bite, −20; said in the feed."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.rolls = SureRolls.new()
	var said: Array = []
	f.say = func(text: String, warning: bool) -> void: said.append([text, warning])
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_equal(_hurts.size(), 1, "one injury")
	assert_equal(_hurts[0], [1, Injury.KIND_BITE, Injury.SEVERITY_MINOR, 20], "the fisher, a bite")
	var hazard_said: bool = false
	var encounter: String = RollsScript.ENCOUNTER_WORDS[RollsScript.encounter_of(Fishing.HABITAT_RIVER,
		SimClock.day_index_at(rig.calendar.tick))]
	for line: Array in said:
		hazard_said = hazard_said or (bool(line[1]) and String(line[0]).contains("was bitten by " + encounter))
	assert_true(hazard_said, "said as a warning, naming the day's %s" % encounter)
	assert_equal(f.tables.t_excellent[0], RollsScript.excellent_share(f.caught_milli), "the rare quarter booked")
	said.clear()
	f.say = Callable()


func test_a_refused_injury_is_not_announced() -> void:
	"""The infirmary refusing the injury (no such row): nothing said, nobody counted hurt by the fishery's note."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.rolls = SureRolls.new()
	f.hurt = func(_who: int, _kind: int, _severity: int, _loss: int) -> bool: return false
	var said: Array = []
	f.say = func(text: String, warning: bool) -> void: said.append([text, warning])
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	for line: Array in said:
		assert_false(String(line[0]).contains("was bitten"), "not announced: " + String(line[0]))
	f.say = Callable()
	f.hurt = Callable()


func test_a_boat_hazard_hurts_the_helm_with_exposure() -> void:
	"""A hit on a boat trip: the helm (decision 1711 P1), severity 2 exposure, −35."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.rolls = SureRolls.new()
	f.skills.xp[0] = 2 * 2 * 5000
	f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_equal(_hurts.size(), 1, "one injury for the one cycle")
	assert_equal(_hurts[0], [0, Injury.KIND_EXPOSURE, Injury.SEVERITY_SERIOUS, 35], "the helm, exposure")
	assert_equal(f._outcome.hazard_per_10000, 20 - 2 * 1 - 4 * 1,
		"§5.4 for a crew of two at group skill floor((2 + 0) / 2) = 1")


func test_a_best_catch_trip_falls_back_when_its_fish_closes() -> void:
	"""REQ-SET-046: a BEST CATCH trip whose pick closes on the way fishes the best legal species at the water; a chosen
	fish in the same case waits, naming the reopening (here: none known, the event bit)."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_equal(f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, PlanScript.PLAN_AUTO, PackedInt32Array([1])), "", "auto")
	assert_equal(f.tables.t_auto[0], 1, "a best-catch trip")
	var first: int = f.tables.t_species[0]
	assert_equal(first, f.planned_species(Rules.METHOD_NET, Driver.SITE_RUN, PlanScript.PLAN_AUTO,
		PackedInt32Array([1])), "its pick")
	rig.driver.store().set_closed(rig.driver.habitat_ref_of_site(Driver.SITE_RUN), first, true)
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing anyway")
	assert_true(f.tables.t_species[0] != first, "another species")
	assert_equal(f.tables.t_item[0], Rules.pantry_item_of(rig.driver.species_row_of(Driver.SITE_RUN,
		f.tables.t_species[0])), "its item follows")


func test_a_chosen_fish_closed_names_its_reopening_day() -> void:
	"""REQ-SET-046: at spring 5 trout is in its spawning closure; the refusal names spring 8."""
	var rig := _rig()
	_skip_days(rig, 4)
	var why: String = rig.fishery.trip_refusal(Rules.METHOD_NET, Driver.SITE_RUN, 0, PackedInt32Array())
	assert_true(why.contains("reopens spring 8"), why)
	for s: int in 3:
		rig.driver.store().set_closed(rig.driver.habitat_ref_of_site(Driver.SITE_RUN), s, true)
	why = rig.fishery.trip_refusal(Rules.METHOD_NET, Driver.SITE_RUN, PlanScript.PLAN_AUTO, PackedInt32Array())
	assert_equal(rig.fishery.refused_code, "NO_LEGAL_FISH", "best catch with nothing legal: " + why)
	why = rig.fishery.trip_refusal(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array())
	assert_true(why.contains("reopening not known"), "dace closed by its event bit: no invented date: " + why)
	rig.driver.set_lake_frozen(true)
	rig.fishery.trip_refusal(Rules.METHOD_NET, Driver.SITE_POND, PlanScript.PLAN_AUTO, PackedInt32Array())
	assert_equal(rig.fishery.refused_code, String(Driver.REFUSE_ICE_COVERS), "best catch says the ice, not 'no fish'")


func test_a_morning_run_trap_waits_for_the_morning() -> void:
	"""A dace trap on the morning run, set at once (06:00): soaked by midday, but collected only from 06:00 next day."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.collect_policy = PlanScript.COLLECT_MORNING
	assert_equal(f.authorise(Rules.METHOD_TRAP, Driver.SITE_RUN, 1, PackedInt32Array([1])), "", "a trap for dace")
	assert_equal(f.tables.t_collect[0], PlanScript.COLLECT_MORNING, "its policy")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_SOAKING), "set")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "the setter goes home")
	rig.calendar.tick += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
	_run(rig, func() -> bool: return false, 20)
	assert_equal(f.tables.job_count(), 0, "soaked in the afternoon: no collection yet")
	var to_dawn: int = SimClock.TICKS_PER_DAY - posmod(rig.calendar.tick + SimClock.CALENDAR_OFFSET_TICKS,
		SimClock.TICKS_PER_DAY) + 6 * SimClock.TICKS_PER_HOUR
	rig.calendar.tick += to_dawn
	rig.driver.advance_ticks(to_dawn)
	_run(rig, func() -> bool: return f.tables.job_count() == 1, 20)
	assert_equal(f.tables.job_count(), 1, "06:00: the collection is on the board")


func test_a_morning_run_trap_is_collected_before_tomorrows_closure() -> void:
	"""A carp trap on the morning run on spring 7: carp closes on spring 8, so it is collected as soon as soaked."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_skip_days(rig, 6)
	f.collect_policy = PlanScript.COLLECT_MORNING
	assert_equal(f.authorise(Rules.METHOD_TRAP, Driver.SITE_POND, 1, PackedInt32Array([1])), "", "a trap for carp")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_SOAKING), "set")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "the setter goes home")
	rig.calendar.tick += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
	_run(rig, func() -> bool: return f.tables.job_count() == 1, 20)
	assert_equal(f.tables.job_count(), 1, "collected now, before the closure")


func test_the_panel_shows_the_plan_record_and_intensive_card() -> void:
	"""The Water panel's words: Best catch names its pick, the record names both waters, the rare chance is shown, and
	Intensive's card shows the floor before it is pressed; pressing sets the store's flag."""
	var rig := _rig()
	var node: DemoFisheryScript = _keep(DemoFisheryScript.new()) as DemoFisheryScript
	node.fishery = rig.fishery
	node._cast = rig.cast
	node.choice_site = Driver.SITE_RUN
	node.choice_method = Rules.METHOD_NET
	node.choice_species = PlanScript.PLAN_AUTO
	assert_true(node.choice_line().contains("best catch ("), node.choice_line())
	assert_true(node.preview_text().contains("Rare catch: "), node.preview_text())
	rig.fishery.steward.follow(rig.driver)
	var record: String = node.record_text()
	assert_true(record.contains("The stream") and record.contains("The pond"), record)
	var card: String = node.intensive_card().text()
	assert_true(card.contains("10% hard floor") and card.contains("trout"), card)
	var first: String = node.toggle_intensive()
	assert_true(first.contains("Press Intensive again") and first.contains("10% hard floor"), first)
	assert_false(rig.driver.intensive(Driver.SITE_RUN), "the first press only shows the figures")
	assert_true(node.toggle_intensive().contains("ON"), "the second accepts")
	assert_true(rig.driver.intensive(Driver.SITE_RUN), "the store's flag")
	assert_true(node.intensive_card().text().contains("30% floor"), "the card to turn it off")
	assert_true(node.toggle_intensive().contains("off"), "off")
	for s: int in 3:
		rig.driver.store().set_closed(rig.driver.habitat_ref_of_site(Driver.SITE_RUN), s, true)
	assert_true(node.choice_line().contains("nothing now"), node.choice_line())
	assert_true(node.preview_text().begins_with("Best catch: no fish"), node.preview_text())


func test_a_boat_crew_walks_to_the_jetty_through_the_route_desk() -> void:
	"""Perf 1001: with the live scene's tight routing window the crew's walks to the jetty wait their turn at the routing
	desk ("finding a route") and the boat still sails, fishes and lands -- the boat's own legs stay its fixed route."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.cast.set_route_budget(1)
	f.skills.xp[0] = 2 * 2 * 5000
	f.brain_of(0).start_at(Vector2(-6.0, -12.0), 0.0, -1, -1)
	f.brain_of(1).start_at(Vector2(-5.0, -12.5), 0.0, -1, -1)
	assert_equal(f.authorise(Rules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array([0, 1])), "", "authorised")
	assert_true(_run(rig, func() -> bool: return f.tables.trip_count() == 0), "sailed, fished and landed")
	assert_true(rig.cast.space().routes.served > 0, "plans were served late by the desk")
	assert_true(f.caught_milli > 0, "a catch")


func test_the_collection_tick_is_now_in_the_morning_else_the_next_morning() -> void:
	"""A morning-run trap that soaks at 09:30 is collected then; at 10:30 or 05:30 at the next 06:00; when soaked."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var t: int = f.tables.open_trip(Rules.METHOD_TRAP, Driver.SITE_RUN, 1)
	f.tables.t_collect[t] = PlanScript.COLLECT_MORNING
	var day: int = SimClock.TICKS_PER_DAY
	rig.calendar.tick = day + 3 * SimClock.TICKS_PER_HOUR + 375
	assert_equal(f._collect_tick(t), rig.calendar.tick, "09:30: now")
	rig.calendar.tick = day + 4 * SimClock.TICKS_PER_HOUR + 375
	assert_equal(f._collect_tick(t), 2 * day, "10:30: tomorrow 06:00")
	rig.calendar.tick = 2 * day - 375
	assert_equal(f._collect_tick(t), 2 * day, "05:30: 06:00 today")
	f.tables.t_collect[t] = PlanScript.COLLECT_SOAKED
	assert_equal(f._collect_tick(t), rig.calendar.tick, "when soaked: now")
	f.tables.close_trip(t)


func test_the_collection_tick_is_worked_out_once_when_the_soak_ends() -> void:
	"""A carp trap on the morning run soaked on spring 6's afternoon is collected at spring 7's 06:00 -- not at
	midnight, when carp's spring 8 closure becomes "tomorrow": the tick was settled when the soak ended."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_skip_days(rig, 5)
	f.collect_policy = PlanScript.COLLECT_MORNING
	assert_equal(f.authorise(Rules.METHOD_TRAP, Driver.SITE_POND, 1, PackedInt32Array([1])), "", "a trap for carp")
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_SOAKING), "set")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "the setter goes home")
	rig.calendar.tick += Rules.TRAP_SOAK_HOURS * SimClock.TICKS_PER_HOUR
	_run(rig, func() -> bool: return false, 5)
	assert_equal(f.tables.t_collect_at[0], PlanScript.next_morning_tick(rig.calendar.tick), "spring 7 06:00")
	var to_one: int = SimClock.TICKS_PER_DAY - posmod(rig.calendar.tick + SimClock.CALENDAR_OFFSET_TICKS,
		SimClock.TICKS_PER_DAY) + SimClock.TICKS_PER_HOUR
	rig.calendar.tick += to_one
	rig.driver.advance_ticks(to_one)
	_run(rig, func() -> bool: return false, 5)
	assert_equal(f.tables.job_count(), 0, "01:00 on spring 7: still waiting for the morning")


func test_a_completion_without_departure_draws_resolves_nothing() -> void:
	"""A cycle whose draws are not on the trip (none were taken) resolves no hazard or rare catch."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.rolls = SureRolls.new()
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing")
	f.tables.t_hazard_roll[0] = -1
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_equal(_hurts.size(), 0, "nobody hurt")
	assert_equal(f.tables.t_excellent[0], 0, "no rare share")


func test_best_catch_stays_chosen_when_the_site_changes() -> void:
	"""Site ▸ keeps Best catch; a chosen fish goes back to the water's first."""
	var node: DemoFisheryScript = _keep(DemoFisheryScript.new()) as DemoFisheryScript
	node.choice_species = PlanScript.PLAN_AUTO
	node.step_site()
	assert_equal(node.choice_species, PlanScript.PLAN_AUTO, "kept")
	node.choice_species = 2
	node.step_site()
	assert_equal(node.choice_species, 0, "the first fish")


func test_completion_resolves_the_draws_kept_on_the_trip() -> void:
	"""The draws resolved are the trip's own, taken at departure: planted at 0 (below any chance) they hurt and make a
	quarter excellent at completion, whatever the stream draws meanwhile."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.authorise(Rules.METHOD_NET, Driver.SITE_RUN, 1, PackedInt32Array([1]))
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_FISHING), "fishing")
	f.tables.t_hazard_roll[0] = 0
	f.tables.t_rare_roll[0] = 0
	assert_true(_run(rig, func() -> bool: return f.tables.t_state[0] == Tables.TRIP_LANDING), "caught")
	assert_equal(_hurts.size(), 1, "the planted hazard draw hurt")
	assert_equal(f.tables.t_excellent[0], RollsScript.excellent_share(f.caught_milli), "the planted rare draw")
