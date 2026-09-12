extends "res://test/framework/test_case.gd"
## Coverage for GDD §5.2: the integer remainder integration rule, every published decay and
## restoration rate, the size and winter multipliers, thresholds, health, cold exposure, the
## §7.1 mood fixture, and REQ-SET-011 speed independence.
##
## The load-bearing tests here are the long-run losslessness ones. An integration rule that is
## approximately right still produces exactly the right answer over three ticks; drift only
## becomes visible after thousands. So the remainder tests run tens of thousands of ticks and
## compare against closed-form integer arithmetic -- floor(T*R/750000) -- rather than against a
## previously recorded number, and they check the retained remainder itself at every checkpoint,
## not only the released whole units.
##
## Blocker U6: MoodMemory has no owner-major index formula, so mood_of() takes the active memory
## total as an argument. The §7.1 fixture's good-meal bonus and lost-friend penalty are therefore
## driven through the published §5.2 catalog values rather than through a stored memory row.

const NeedsScript := preload("res://scripts/core/needs.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## One game hour, in ticks (REQ-SET-006).
const HOUR: int = 750

## Both edges of every §5.2 mood band, for the fused work-factor reader's equivalence sweep.
const FUSED_MOOD_PROBES: Array[int] = [0, 1999, 2000, 3999, 4000, 6999, 7000, 8499, 8500, 10000]
## Both edges of every §5.2 health band. 1 rather than 0 because 0 is death, not a band edge.
const FUSED_HEALTH_PROBES: Array[int] = [1, 39, 40, 69, 70, 100]
## Memory totals spanning both ends of REQ-SET-020's 0-10000 clamp from a mood of 5000.
const FUSED_MEMORY_PROBES: Array[int] = [-1000000, -5001, -5000, -1000, 0, 1000, 5000, 1000000]

var _needs: NeedsScript = null


func before_each() -> void:
	"""Fresh needs store with no residents and no season modifiers."""
	_needs = NeedsScript.new()


func _spawn(slot: int = 0, size_class: int = NeedsScript.SIZE_SMALL) -> void:
	"""Spawn one resident at the GDD §5.1 start state and assert the spawn succeeded."""
	assert_true(_needs.spawn(slot, size_class).ok, "spawn(%d) succeeds" % slot)


func _need(slot: int, need: int) -> int:
	"""Read one need value, asserting the read was not refused."""
	var result := _needs.need_of(slot, need)
	assert_true(result.ok, "need_of(%d,%d) succeeds" % [slot, need])
	return result.value


func _remainder(slot: int, need: int) -> int:
	"""Read one retained need remainder, asserting the read was not refused."""
	var result := _needs.need_remainder_of(slot, need)
	assert_true(result.ok, "need_remainder_of(%d,%d) succeeds" % [slot, need])
	return result.value


func _health(slot: int) -> int:
	"""Read health, asserting the read was not refused."""
	var result := _needs.health_of(slot)
	assert_true(result.ok, "health_of(%d) succeeds" % slot)
	return result.value


func _tick(slot: int, count: int) -> void:
	"""Run `count` ticks for one resident, asserting no tick refused."""
	for _index: int in count:
		if not _needs.tick(slot).ok:
			fail("tick(%d) refused" % slot)
			return


func _set_need(slot: int, need: int, target: int) -> void:
	"""Move one need to an exact value using a whole-point event."""
	var current: int = _need(slot, need)
	assert_true(_needs.apply_need_event(slot, need, target - current).ok, "need event applies")
	assert_equal(_need(slot, need), target, "need reached its target value")


# --- capacity and lifecycle --------------------------------------------------------------------

func test_columns_are_sized_to_the_directory_resident_store() -> void:
	"""Needs rows are indexed by RESIDENT typed row, so the two capacities must be one number."""
	assert_equal(NeedsScript.RESIDENT_CAPACITY,
		EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_RESIDENT],
		"512 resident rows, matching entity_directory.gd")
	assert_equal(NeedsScript.RESIDENT_LIVING_CAP, EntityDirectoryScript.RESIDENT_LIVING_CAP,
		"256 living residents, matching entity_directory.gd")


func test_spawn_writes_the_gdd_start_state() -> void:
	"""GDD §5.1: all five needs 7500, health 100, every remainder and counter 0."""
	_spawn()
	for need: int in NeedsScript.NEED_COUNT:
		assert_equal(_need(0, need), 7500, "need %d starts at 7500" % need)
		assert_equal(_remainder(0, need), 0, "need %d starts with no remainder" % need)
	assert_equal(_health(0), 100, "health starts at 100")
	assert_equal(_needs.cold_milli_hours_of(0).value, 0, "no cold exposure at spawn")
	assert_equal(_needs.starving_hours_of(0).value, 0, "no starving hours at spawn")
	assert_equal(_needs.departure_days_of(0).value, 0, "departure_days is reserved and zero")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_ACTIVE, "spawns ACTIVE")
	assert_equal(_needs.living_count(), 1, "one living resident")


func test_spawn_refuses_out_of_range_duplicate_and_bad_size() -> void:
	"""Every spawn precondition refuses explicitly instead of clamping into a usable row."""
	assert_equal(_needs.spawn(-1, 0).error, NeedsScript.REFUSE_INVALID_SLOT, "negative slot")
	assert_equal(_needs.spawn(NeedsScript.RESIDENT_CAPACITY, 0).error,
		NeedsScript.REFUSE_INVALID_SLOT, "slot past capacity")
	_spawn()
	assert_equal(_needs.spawn(0, 0).error, NeedsScript.REFUSE_ALREADY_PRESENT, "duplicate spawn")
	assert_equal(_needs.spawn(1, NeedsScript.SIZE_COUNT).error, NeedsScript.REFUSE_INVALID_SIZE,
		"unknown size class")


func test_living_cap_refuses_at_256_rather_than_dropping_silently() -> void:
	"""GDD §4.1: 512 rows but never more than 256 living residents."""
	for slot: int in NeedsScript.RESIDENT_LIVING_CAP:
		assert_true(_needs.spawn(slot, NeedsScript.SIZE_SMALL).ok, "spawn %d fits" % slot)
	assert_equal(_needs.living_count(), 256, "256 living")
	var refused := _needs.spawn(256, NeedsScript.SIZE_SMALL)
	assert_false(refused.ok, "the 257th living resident is refused")
	assert_equal(refused.error, NeedsScript.REFUSE_LIVING_CAP, "explicit living-cap refusal")
	assert_equal(refused.value, 0, "a refusal carries no usable value")


func test_readers_refuse_absent_rows_instead_of_answering_zero() -> void:
	"""A reader must never hand back a default that reads like real data (finding H4)."""
	var absent := _needs.need_of(3, NeedsScript.NEED_HUNGER)
	assert_false(absent.ok, "an unspawned row refuses")
	assert_equal(absent.value, 0, "a refused read zeroes its value channel")
	_spawn()
	assert_false(_needs.need_of(0, NeedsScript.NEED_COUNT).ok, "unknown need index refuses")
	assert_false(_needs.health_of(-1).ok, "negative slot refuses")
	assert_true(_needs.health_of(0).ok, "a present row reads")


func test_work_facing_into_readers_match_wrappers_at_their_boundaries() -> void:
	"""Caller-owned readers preserve exact values at the bands the work chain depends on."""
	_spawn()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_needs.need_into(0, NeedsScript.NEED_REST, out), "rest reads into scratch")
	assert_equal(out.value, _needs.need_of(0, NeedsScript.NEED_REST).value, "need parity")
	assert_true(_needs.health_into(0, out), "health reads into the same scratch")
	assert_equal(out.value, _needs.health_of(0).value, "health parity at 100")
	assert_true(_needs.status_into(0, out), "status reads into the same scratch")
	assert_equal(out.value, _needs.status_of(0).value, "status parity")
	assert_true(_needs.mood_into(0, 0, out), "mood reads into the same scratch")
	assert_equal(out.value, _needs.mood_of(0, 0).value, "mood parity at 7500")
	assert_true(_needs.skill_factor_into(10, out), "maximum skill factor reads")
	assert_equal(out.value, _needs.skill_factor(10).value, "skill factor parity at level 10")
	assert_true(_needs.work_factor_into(10, 8500, 70, out), "threshold factors compose")
	assert_equal(out.value, _needs.work_factor(10, 8500, 70).value, "work factor parity")
	assert_equal(out.value, 1725, "level 10, mood 8500 and health 70 produce 1725")


func test_work_facing_into_reuse_clears_stale_values_and_errors() -> void:
	"""One output may cross success and refusal without leaking either prior channel."""
	_spawn()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_needs.need_into(0, NeedsScript.NEED_HUNGER, out), "seed a successful read")
	assert_false(_needs.need_into(0, NeedsScript.NEED_COUNT, out), "invalid need refuses")
	assert_equal(out.error, String(NeedsScript.REFUSE_INVALID_NEED), "the exact code is retained")
	assert_equal(out.value, 0, "refusal clears the previous need")
	assert_true(_needs.status_into(0, out), "a later status read succeeds")
	assert_equal(out.error, "", "success clears the old refusal")
	assert_false(_needs.mood_into(0, IntMath.INT64_MAX, out), "mood addition overflow refuses")
	assert_equal(out.error, String(NeedsScript.REFUSE_OVERFLOW), "overflow keeps the public code")
	assert_equal(out.value, 0, "overflow clears the previous status")
	assert_false(_needs.work_factor_into(11, 8500, 70, out), "invalid skill still refuses")
	assert_equal(out.error, String(NeedsScript.REFUSE_INVALID_SKILL_LEVEL), "factor refusal parity")
	assert_equal(out.value, 0, "factor refusal also clears its scratch")


func test_work_facing_allocating_wrappers_stay_fresh() -> void:
	"""Convenience results may escape, so every call must return a distinct IntResult."""
	_spawn()
	assert_false(_needs.need_of(0, 0) == _needs.need_of(0, 0), "need results are fresh")
	assert_false(_needs.health_of(0) == _needs.health_of(0), "health results are fresh")
	assert_false(_needs.status_of(0) == _needs.status_of(0), "status results are fresh")
	assert_false(_needs.mood_of(0, 0) == _needs.mood_of(0, 0), "mood results are fresh")
	assert_false(_needs.skill_factor(0) == _needs.skill_factor(0), "skill results are fresh")
	assert_false(_needs.work_factor(0, 5000, 100) == _needs.work_factor(0, 5000, 100),
		"work-factor results are fresh")


func test_despawn_clears_the_row_and_the_living_count() -> void:
	"""Despawn releases the data; entity_directory.gd still owns the slot itself."""
	_spawn()
	assert_true(_needs.despawn(0).ok, "despawn succeeds")
	assert_equal(_needs.living_count(), 0, "no living residents remain")
	assert_equal(_needs.present_count(), 0, "no present rows remain")
	assert_false(_needs.is_present(0), "the row is gone")
	assert_equal(_needs.despawn(0).error, NeedsScript.REFUSE_NOT_PRESENT, "second despawn refuses")


# --- §5.2 baseline decay rates ------------------------------------------------------------------

func test_every_baseline_decay_rate_matches_the_gdd_table() -> void:
	"""Hunger 250, rest 375 (awake), comfort 100, social 100, purpose 75 need points per hour."""
	_spawn()
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 7250, "hunger decays 250/hour")
	assert_equal(_need(0, NeedsScript.NEED_REST), 7125, "rest decays 375/hour while awake")
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), 7400, "comfort decays 100/hour")
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), 7400, "social decays 100/hour")
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 7425, "purpose decays 75/hour")


func test_published_thresholds_match_the_gdd_table() -> void:
	"""The §5.2 threshold column, quoted as constants other systems will branch on."""
	assert_equal(NeedsScript.HUNGER_EAT_THRESHOLD, 3500, "eat at hunger<=3500")
	assert_equal(NeedsScript.HUNGER_URGENT_THRESHOLD, 1500, "urgent at hunger<=1500")
	assert_equal(NeedsScript.HUNGER_STARVING_VALUE, 0, "starving at hunger=0")
	assert_equal(NeedsScript.REST_SEEK_SLEEP_THRESHOLD, 2500, "seek sleep at rest<=2500")
	assert_equal(NeedsScript.REST_COLLAPSE_THRESHOLD, 500, "collapse at rest<=500")
	assert_equal(NeedsScript.REST_HAZARD_CLEAR_THRESHOLD, 4000, "REQ-SET-015 clears at rest>=4000")
	assert_equal(NeedsScript.COMFORT_LOW_THRESHOLD, 3000, "comfort low below 3000")
	assert_equal(NeedsScript.COMFORT_CONTENT_THRESHOLD, 6000, "comfort content from 6000")
	assert_equal(NeedsScript.SOCIAL_LONELY_THRESHOLD, 2500, "lonely below 2500")
	assert_equal(NeedsScript.PURPOSE_AIMLESS_THRESHOLD, 2500, "aimless below 2500")


# --- §5.2 restoration rates ----------------------------------------------------------------------

func test_sleep_restores_rest_in_bed_and_on_the_floor_with_no_awake_decay() -> void:
	"""Rest: +1200/hour in a bed, +750/hour on the floor, and no awake decay while asleep."""
	_spawn()
	_set_need(0, NeedsScript.NEED_REST, 1000)
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_BED).ok, "sleeps in a bed")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_REST), 2200, "bed sleep restores a gross 1200/hour")
	_set_need(0, NeedsScript.NEED_REST, 1000)
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "sleeps on the floor")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_REST), 1750, "floor sleep restores a gross 750/hour")


func test_comfort_restoration_is_net_of_the_hourly_decay() -> void:
	"""+300/hour in a valid heated room and +100/hour outdoors at 10-24 C, over -100/hour decay."""
	_spawn()
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), 7700, "heated room nets +200/hour")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_MILD_OUTDOORS).ok, "mild")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), 7700, "mild outdoors exactly offsets decay")


func test_social_and_purpose_restoration_match_the_control_kernel_net_rates() -> void:
	"""+1200 social and +320 purpose over their decays: the winter control's +1100 and +245."""
	_spawn()
	assert_true(_needs.set_social_paired(0, true).ok, "paired social activity")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "useful labor")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), 8600, "social nets +1100/hour")
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 7745, "purpose nets +245/hour")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_MENTORING).ok, "mentoring")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 8070, "mentoring nets +325/hour")


func test_meal_events_add_nutrition_and_the_shared_meal_social_bonus() -> void:
	"""Food adds its resolved NP one-for-one; dining adds +200 social per shared meal."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 3000)
	var eaten := _needs.add_food_nutrition(0, 1800)
	assert_true(eaten.ok, "a PLAIN porridge portion is eaten")
	assert_equal(eaten.value, 1800, "all 1800 NP is absorbed")
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 4800, "1 NP is 1 need point")
	assert_true(_needs.add_shared_meal_social(0).ok, "the meal is shared")
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), 7700, "dining adds +200 social")
	assert_equal(_needs.add_food_nutrition(0, -1).error, NeedsScript.REFUSE_INVALID_POINTS,
		"negative nutrition is refused, not treated as a diet")


func test_eating_at_the_cap_discards_the_surplus_without_refunding_it() -> void:
	"""§5.2: eating clamps fullness without refunding excess NP; the caller sees what fit."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 9500)
	var eaten := _needs.add_food_nutrition(0, 1800)
	assert_true(eaten.ok, "the portion is still eaten")
	assert_equal(eaten.value, 500, "only 500 NP fit under the 10000 cap")
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 10000, "fullness clamps at 10000")


# --- size and winter multipliers -------------------------------------------------------------------

func test_size_multipliers_scale_hunger_decay_exactly() -> void:
	"""Small 1000, medium 1200, large 1600 over denominator 1000: 250, 300 and 400 per hour."""
	_spawn(0, NeedsScript.SIZE_SMALL)
	_spawn(1, NeedsScript.SIZE_MEDIUM)
	_spawn(2, NeedsScript.SIZE_LARGE)
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_SMALL).value, 250000, "small")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_MEDIUM).value, 300000, "medium")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_LARGE).value, 400000, "large")
	assert_true(_needs.tick_all().ok, "one tick for the whole settlement")
	_tick(0, HOUR - 1)
	_tick(1, HOUR - 1)
	_tick(2, HOUR - 1)
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 7250, "small loses 250/hour")
	assert_equal(_need(1, NeedsScript.NEED_HUNGER), 7200, "medium loses 300/hour")
	assert_equal(_need(2, NeedsScript.NEED_HUNGER), 7100, "large loses 400/hour")


func test_winter_multiplies_hunger_demand_by_1_20_over_the_size_multiplier() -> void:
	"""REQ-SET-143 x1.20, compounded with the size multiplier in int64 before one division."""
	_spawn(0, NeedsScript.SIZE_SMALL)
	_spawn(1, NeedsScript.SIZE_MEDIUM)
	_spawn(2, NeedsScript.SIZE_LARGE)
	assert_true(_needs.set_winter(true).ok, "winter begins")
	assert_true(_needs.is_winter(), "winter is in force")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_SMALL).value, 300000, "small")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_MEDIUM).value, 360000, "medium")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_LARGE).value, 480000, "large")
	_tick(0, HOUR)
	_tick(1, HOUR)
	_tick(2, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 7200, "small loses 300/hour in winter")
	assert_equal(_need(1, NeedsScript.NEED_HUNGER), 7140, "medium loses 360/hour in winter")
	assert_equal(_need(2, NeedsScript.NEED_HUNGER), 7020, "large loses 480/hour in winter")


func test_winter_rate_matches_the_verified_winter_control_kernel() -> void:
	"""docs/validation/headless/winter_world.gd decays 300*size per tick over denominator 750000."""
	_spawn(0, NeedsScript.SIZE_SMALL)
	_spawn(1, NeedsScript.SIZE_MEDIUM)
	assert_true(_needs.set_winter(true).ok, "winter begins")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_SMALL).value,
		300 * NeedsScript.SIZE_MULTIPLIER[NeedsScript.SIZE_SMALL], "control kernel small rate")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_MEDIUM).value,
		300 * NeedsScript.SIZE_MULTIPLIER[NeedsScript.SIZE_MEDIUM], "control kernel medium rate")
	assert_true(_needs.set_winter(false).ok, "winter ends")
	assert_equal(_needs.hunger_rate_milli_per_hour(NeedsScript.SIZE_SMALL).value, 250000,
		"the multiplier is released, not accumulated")


# --- THE INTEGRATION RULE: long-run losslessness ----------------------------------------------------

func test_slow_rates_integrate_losslessly_over_tens_of_thousands_of_ticks() -> void:
	"""Purpose 75/hour is 0.1 need points per tick and social 100/hour is 2/15 of a point.

	Neither releases a whole point on most ticks, so an integrator that re-truncated instead of
	retaining its remainder would drift steadily. Over 56250 ticks (75 game hours) the released
	total must equal the closed form floor(T*R/750000) exactly, and the retained remainder must
	equal (T*R) mod 750000 exactly, at every checkpoint.
	"""
	_spawn()
	var checked: int = 0
	for tick: int in range(1, 56250):
		_tick(0, 1)
		if tick % 750 == 0:
			_hold_hunger_and_rest_steady(0)
		if tick % 997 != 0 and tick > 40:
			continue
		checked += 1
		_assert_closed_form(tick, NeedsScript.NEED_PURPOSE, 75000)
		_assert_closed_form(tick, NeedsScript.NEED_SOCIAL, 100000)
	assert_true(checked > 90, "the closed form was checked at many points, not just the end")
	assert_equal(_needs.death_count(), 0, "the resident was kept alive throughout")


func _hold_hunger_and_rest_steady(slot: int) -> void:
	"""Top hunger and rest back up each game hour so the long run isolates the tested needs."""
	assert_true(_needs.apply_need_event(slot, NeedsScript.NEED_HUNGER, 250).ok, "hunger held")
	assert_true(_needs.apply_need_event(slot, NeedsScript.NEED_REST, 375).ok, "rest held")


func _assert_closed_form(tick: int, need: int, rate_milli: int) -> void:
	"""Assert a decaying need equals 7500 - floor(T*R/D) with remainder -((T*R) mod D)."""
	var total: int = tick * rate_milli
	var released: int = total / NeedsScript.NEED_DENOMINATOR
	assert_equal(_need(0, need), 7500 - released,
		"need %d after %d ticks is the closed-form value" % [need, tick])
	assert_equal(_remainder(0, need), -(total % NeedsScript.NEED_DENOMINATOR),
		"need %d after %d ticks retains the exact remainder" % [need, tick])


func test_a_full_game_hour_of_any_rate_releases_exactly_that_rate() -> void:
	"""750 ticks of R milli-points per hour releases exactly R/1000 points and leaves no crumb."""
	_spawn()
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_BED).ok, "asleep in a bed")
	_set_need(0, NeedsScript.NEED_REST, 0)
	for hour: int in 8:
		_tick(0, HOUR)
		assert_equal(_need(0, NeedsScript.NEED_REST), 1200 * (hour + 1),
			"rest is exactly 1200 per whole hour slept")
		assert_equal(_remainder(0, NeedsScript.NEED_REST), 0,
			"a whole hour of a whole-point rate leaves no remainder")


func test_the_remainder_survives_a_rate_change_mid_stream() -> void:
	"""BAL-NUM-001 carries a remainder across task switches, not only across ticks."""
	_spawn()
	_tick(0, 5)
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), -375000, "5 ticks of decay are banked")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "starts work")
	_tick(0, 1)
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), -130000,
		"the banked -375000 absorbs the first +245000 of labor rather than being discarded")
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 7500, "no whole point has moved yet")


# --- THE INTEGRATION RULE: clamping and the bound remainder rule --------------------------------------

func test_at_the_upper_bound_only_the_outward_remainder_is_discarded() -> void:
	"""GDD §5.2 discards positive overflow at 10000; BAL-NUM-001 keeps an inward remainder."""
	_spawn()
	_set_need(0, NeedsScript.NEED_COMFORT, 10000)
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	_tick(0, 20)
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), 10000, "comfort holds at the cap")
	assert_equal(_remainder(0, NeedsScript.NEED_COMFORT), 0,
		"20 ticks of outward remainder are discarded, never banked against a later fall")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_NONE).ok, "leaves")
	_tick(0, 1)
	assert_equal(_remainder(0, NeedsScript.NEED_COMFORT), -100000,
		"an inward remainder at the cap is retained")
	_tick(0, 7)
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), 9999, "the eighth tick releases one point")
	assert_equal(_remainder(0, NeedsScript.NEED_COMFORT), -50000, "and keeps the rest")


func test_at_the_lower_bound_only_the_outward_remainder_is_discarded() -> void:
	"""The same rule of either sign at 0 (GDD §5.2: "discard overflow of either sign")."""
	_spawn()
	_set_need(0, NeedsScript.NEED_PURPOSE, 0)
	_tick(0, 100)
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 0, "purpose holds at the floor")
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), 0,
		"100 ticks of outward remainder are discarded")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "starts work")
	_tick(0, 1)
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), 245000,
		"an inward remainder at the floor is retained")
	_tick(0, 3)
	assert_equal(_need(0, NeedsScript.NEED_PURPOSE), 1, "the fourth tick releases one point")
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), 230000, "and keeps the rest")


func test_a_whole_point_event_also_discards_the_outward_remainder_at_a_bound() -> void:
	"""A need pushed to a bound by eating must not keep a remainder aimed outside it either."""
	_spawn()
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "at work")
	_tick(0, 1)
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), 245000, "an outward remainder is banked")
	_set_need(0, NeedsScript.NEED_PURPOSE, 10000)
	assert_equal(_remainder(0, NeedsScript.NEED_PURPOSE), 0,
		"reaching the cap by event discards it too")


func test_clamping_never_lets_a_need_leave_its_range() -> void:
	"""Needs are 0-10000 whatever the rate or the event (GDD §4.2)."""
	_spawn()
	assert_true(_needs.apply_need_event(0, NeedsScript.NEED_SOCIAL, 999999).ok, "huge gift")
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), 10000, "clamped up to 10000")
	assert_true(_needs.apply_need_event(0, NeedsScript.NEED_SOCIAL, -999999).ok, "huge loss")
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), 0, "clamped down to 0")


# --- REQ-SET-011: independence of game speed and batching -----------------------------------------

func test_the_same_tick_count_gives_the_same_result_however_it_is_batched() -> void:
	"""REQ-SET-011/003: speed changes how many of these ticks run, never what one tick does."""
	var single := NeedsScript.new()
	var batched := NeedsScript.new()
	assert_true(single.spawn(0, NeedsScript.SIZE_MEDIUM).ok, "reference resident")
	assert_true(batched.spawn(0, NeedsScript.SIZE_MEDIUM).ok, "batched resident")
	assert_true(single.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	assert_true(batched.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	for _index: int in 3000:
		assert_true(single.tick(0).ok, "one tick at a time")
	for _batch: int in [1, 2, 4, 993, 2000]:
		for _index: int in _batch:
			assert_true(batched.tick(0).ok, "the same tick inside a burst")
	_assert_same_state(single, batched)


func _assert_same_state(a: NeedsScript, b: NeedsScript) -> void:
	"""Assert two stores agree on every integrated column of resident 0."""
	for need: int in NeedsScript.NEED_COUNT:
		assert_equal(b.need_of(0, need).value, a.need_of(0, need).value,
			"need %d is batching independent" % need)
		assert_equal(b.need_remainder_of(0, need).value, a.need_remainder_of(0, need).value,
			"need %d remainder is batching independent" % need)
	assert_equal(b.health_of(0).value, a.health_of(0).value, "health is batching independent")
	assert_equal(b.health_remainder_of(0).value, a.health_remainder_of(0).value,
		"the health remainder is batching independent")


func test_tick_accepts_no_elapsed_time_speed_or_delta() -> void:
	"""REQ-SET-011 structurally: nothing about host time or speed can reach a need update."""
	var script: GDScript = _needs.get_script()
	var methods: Array[Dictionary] = script.get_script_method_list()
	var seen: int = 0
	for method: Dictionary in methods:
		if method["name"] == "tick":
			seen += 1
			assert_equal((method["args"] as Array).size(), 1, "tick takes only a resident slot")
		elif method["name"] == "tick_all":
			seen += 1
			assert_equal((method["args"] as Array).size(), 0, "tick_all takes nothing at all")
	assert_equal(seen, 2, "both tick entry points were inspected")


func test_interleaving_residents_does_not_couple_them() -> void:
	"""Each row integrates from its own columns; a sweep order cannot leak between residents."""
	_spawn(0, NeedsScript.SIZE_SMALL)
	_spawn(7, NeedsScript.SIZE_LARGE)
	assert_true(_needs.set_activity(7, NeedsScript.ACTIVITY_SLEEP_BED).ok, "one sleeps")
	for _index: int in HOUR:
		assert_true(_needs.tick_all().ok, "the settlement ticks together")
	assert_equal(_need(0, NeedsScript.NEED_HUNGER), 7250, "the small resident is unaffected")
	assert_equal(_need(7, NeedsScript.NEED_HUNGER), 7100, "the large resident keeps its own rate")
	assert_equal(_need(0, NeedsScript.NEED_REST), 7125, "the awake resident still decays")
	assert_equal(_need(7, NeedsScript.NEED_REST), 8700, "the sleeping resident still restores")


# --- health (REQ-SET-014, 016, 017) ------------------------------------------------------------------

func test_starvation_removes_four_health_per_hour_and_counts_starving_hours() -> void:
	"""REQ-SET-014, and the winter control kernel's -4000 per tick over denominator 750."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 0)
	_tick(0, HOUR)
	assert_equal(_health(0), 96, "4 health per starving hour")
	assert_equal(_needs.starving_hours_of(0).value, 1, "one starving hour counted")
	_tick(0, HOUR * 3)
	assert_equal(_health(0), 84, "the drain continues at 4/hour")
	assert_equal(_needs.starving_hours_of(0).value, 4, "four starving hours counted")


func test_starvation_kills_at_exactly_twenty_five_hours_and_records_the_death() -> void:
	"""REQ-SET-016: health 0 is death, and a dead row is refused rather than quietly ticked."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 0)
	_tick(0, HOUR * 25 - 1)
	assert_equal(_health(0), 1, "one health left after 24 hours and 749 ticks")
	_tick(0, 1)
	assert_equal(_health(0), 0, "the 25th hour completes the drain")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_DEAD, "status is DEAD")
	assert_equal(_needs.death_count(), 1, "the death is recorded")
	assert_equal(_needs.living_count(), 0, "the living count drops")
	assert_equal(_needs.tick(0).error, NeedsScript.REFUSE_RESIDENT_DEAD, "ticking a corpse refuses")


func test_tick_all_skips_the_dead_without_refusing_the_sweep() -> void:
	"""A settlement containing a death is not an error; the sweep reports how many it ran."""
	_spawn(0)
	_spawn(1)
	assert_true(_needs.apply_health_event(0, -100).ok, "resident 0 dies outright")
	assert_equal(_needs.death_count(), 1, "an instantaneous death is recorded too")
	var swept := _needs.tick_all()
	assert_true(swept.ok, "the sweep succeeds")
	assert_equal(swept.value, 1, "only the living resident was integrated")
	assert_equal(_needs.last_refused_slot(), -1, "nothing refused")


func test_health_recovers_at_two_per_hour_and_four_in_an_infirmary() -> void:
	"""REQ-SET-017 with hunger and rest above 4000 and no untreated serious injury."""
	_spawn()
	assert_true(_needs.apply_health_event(0, -50).ok, "an injury takes 50 health")
	assert_equal(_health(0), 50, "health is halved")
	_tick(0, HOUR)
	assert_equal(_health(0), 52, "2 health per hour outside an infirmary")
	assert_true(_needs.set_infirmary(0, true).ok, "carried to the infirmary")
	_tick(0, HOUR)
	assert_equal(_health(0), 56, "4 health per hour in an infirmary")


func test_health_recovery_is_gated_on_needs_and_untreated_serious_injury() -> void:
	"""REQ-SET-017's three conditions each block recovery on their own."""
	_spawn()
	assert_true(_needs.apply_health_event(0, -50).ok, "wounded")
	assert_true(_needs.set_injury_state(0, NeedsScript.INJURY_UNTREATED_SERIOUS).ok, "untreated")
	_tick(0, HOUR)
	assert_equal(_health(0), 50, "an untreated serious injury blocks recovery")
	assert_true(_needs.set_injury_state(0, NeedsScript.INJURY_NONE).ok, "treated")
	_set_need(0, NeedsScript.NEED_HUNGER, 3999)
	_tick(0, HOUR)
	assert_equal(_health(0), 50, "hunger below 4000 blocks recovery")
	_set_need(0, NeedsScript.NEED_HUNGER, 8000)
	_set_need(0, NeedsScript.NEED_REST, 3999)
	_tick(0, HOUR)
	assert_equal(_health(0), 50, "rest below 4000 blocks recovery")


func test_health_holds_at_one_hundred_and_discards_its_outward_remainder() -> void:
	"""A full-health resident cannot bank recovery against a later wound."""
	_spawn()
	_tick(0, HOUR * 4)
	assert_equal(_health(0), 100, "health stays at the cap")
	assert_equal(_needs.health_remainder_of(0).value, 0, "and banks nothing")
	assert_true(_needs.apply_health_event(0, -1).ok, "a scratch")
	_tick(0, HOUR)
	assert_equal(_health(0), 100, "one hour of recovery restores it, capped")


func test_health_events_refuse_a_dead_or_absent_resident() -> void:
	"""Treatment cannot be applied to a row that is not there or is already dead."""
	assert_equal(_needs.apply_health_event(0, 10).error, NeedsScript.REFUSE_NOT_PRESENT, "absent")
	_spawn()
	assert_true(_needs.apply_health_event(0, -100).ok, "killed")
	assert_equal(_needs.apply_health_event(0, 10).error, NeedsScript.REFUSE_RESIDENT_DEAD, "dead")
	assert_equal(_needs.apply_need_event(0, NeedsScript.NEED_HUNGER, 10).error,
		NeedsScript.REFUSE_RESIDENT_DEAD, "a corpse does not get hungry")


# --- cold exposure (REQ-SET-018, REQ-SET-019, §5.10) ---------------------------------------------------

func test_tier_one_clothing_accumulates_one_exposure_hour_per_hour() -> void:
	"""REQ-SET-018 with §5.2's milli-hour storage: 1000 milli-hours per exposure hour."""
	_spawn()
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "outdoors below 0")
	_tick(0, HOUR)
	assert_equal(_needs.cold_milli_hours_of(0).value, 1000, "1000 milli-hours per hour")
	assert_equal(_needs.cold_hours_of(0).value, 1, "cold_hours is the floor/1000 display value")
	_tick(0, HOUR / 2)
	assert_equal(_needs.cold_milli_hours_of(0).value, 1500, "the half hour is tracked exactly")
	assert_equal(_needs.cold_hours_of(0).value, 1, "but the display value floors")


func test_tier_two_clothing_removes_the_baseline_exposure_but_not_a_hard_freeze() -> void:
	"""§5.10: tier 2 removes -5 C exposure; hard freeze still adds 1/hour even with it."""
	_spawn()
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "exposed")
	assert_true(_needs.set_clothing_tier(0, 2).ok, "wearing tier 2")
	_tick(0, HOUR * 4)
	assert_equal(_needs.cold_milli_hours_of(0).value, 0, "tier 2 takes no baseline exposure")
	assert_true(_needs.set_hard_freeze(true).ok, "a hard freeze arrives")
	_tick(0, HOUR)
	assert_equal(_needs.cold_milli_hours_of(0).value, 1000, "tier 2 still gains 1000/hour")
	assert_true(_needs.set_clothing_tier(0, 1).ok, "back to tier 1")
	_tick(0, HOUR)
	assert_equal(_needs.cold_milli_hours_of(0).value, 3000, "tier 1 gains 2000/hour in a freeze")


func test_shelter_clears_exposure_at_two_thousand_per_hour_down_to_zero() -> void:
	"""REQ-SET-019 / §5.2: "Clearing shelter remains 2000/hour", floored at no exposure."""
	_spawn()
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "exposed")
	_tick(0, HOUR * 6)
	assert_equal(_needs.cold_milli_hours_of(0).value, 6000, "six exposure hours banked")
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_HEATED_SHELTER).ok, "indoors")
	_tick(0, HOUR)
	assert_equal(_needs.cold_milli_hours_of(0).value, 4000, "2000 milli-hours cleared per hour")
	_tick(0, HOUR * 5)
	assert_equal(_needs.cold_milli_hours_of(0).value, 0, "clearing floors at zero")
	assert_equal(_needs.cold_hours_of(0).value, 0, "and so does the display value")


func test_exposure_damages_health_only_after_four_hours_and_stops_on_shelter() -> void:
	"""REQ-SET-018's 3 health/hour after 4 exposure hours; REQ-SET-019 stops it immediately.

	The injury flag holds off REQ-SET-017 recovery so the cold drain is the only rate running.
	"""
	_spawn()
	assert_true(_needs.set_injury_state(0, NeedsScript.INJURY_UNTREATED_SERIOUS).ok, "no recovery")
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "exposed")
	_tick(0, HOUR * 4)
	assert_equal(_needs.cold_hours_of(0).value, 4, "four exposure hours banked")
	assert_equal(_health(0), 100, "no damage before the fourth hour completes")
	_tick(0, HOUR)
	assert_equal(_health(0), 97, "3 health per hour once the threshold is passed")
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_HEATED_SHELTER).ok, "indoors")
	_tick(0, HOUR)
	assert_equal(_health(0), 97, "exposure damage stops immediately on shelter")


func test_proper_clothing_also_stops_exposure_damage() -> void:
	"""REQ-SET-018 runs "until sheltered or properly clothed": tier 2 at -5 C ends the drain."""
	_spawn()
	assert_true(_needs.set_injury_state(0, NeedsScript.INJURY_UNTREATED_SERIOUS).ok, "no recovery")
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "exposed")
	_tick(0, HOUR * 5)
	assert_equal(_health(0), 97, "the drain has started")
	assert_true(_needs.set_clothing_tier(0, 2).ok, "given a tier 2 outfit")
	_tick(0, HOUR * 3)
	assert_equal(_health(0), 97, "proper clothing ends the drain with the exposure still banked")
	assert_equal(_needs.cold_hours_of(0).value, 5, "banked exposure is not cleared by clothing")


func test_cold_and_starvation_drains_sum_rather_than_override() -> void:
	"""REQ-SET-014 and REQ-SET-018 are independent requirements with independent conditions."""
	_spawn()
	assert_true(_needs.set_cold_environment(0, NeedsScript.COLD_ENV_EXPOSED).ok, "exposed")
	_tick(0, HOUR * 4)
	_set_need(0, NeedsScript.NEED_HUNGER, 0)
	_tick(0, HOUR)
	assert_equal(_health(0), 93, "4 starving plus 3 freezing is 7 health in one hour")


func test_clothing_tier_and_environment_inputs_refuse_unknown_values() -> void:
	"""Every environment input refuses a value outside its documented set."""
	_spawn()
	assert_equal(_needs.set_clothing_tier(0, 3).error, NeedsScript.REFUSE_INVALID_CLOTHING_TIER,
		"there is no tier 3")
	assert_equal(_needs.set_clothing_tier(0, 0).error, NeedsScript.REFUSE_INVALID_CLOTHING_TIER,
		"there is no tier 0")
	assert_equal(_needs.set_activity(0, 9).error, NeedsScript.REFUSE_INVALID_ACTIVITY, "activity")
	assert_equal(_needs.set_comfort_environment(0, 9).error,
		NeedsScript.REFUSE_INVALID_COMFORT_ENVIRONMENT, "comfort environment")
	assert_equal(_needs.set_purpose_source(0, 9).error, NeedsScript.REFUSE_INVALID_PURPOSE_SOURCE,
		"purpose source")
	assert_equal(_needs.set_cold_environment(0, 9).error,
		NeedsScript.REFUSE_INVALID_COLD_ENVIRONMENT, "cold environment")
	assert_equal(_needs.set_injury_state(0, 9).error, NeedsScript.REFUSE_INVALID_INJURY_STATE,
		"injury state")


# --- status precedence (§5.2) ---------------------------------------------------------------------------

func test_status_follows_the_declared_precedence() -> void:
	"""DEAD at 0, INCAPACITATED 1-15, INJURED 16-99 with an Injury, else ACTIVE or RESTING."""
	_spawn()
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_ACTIVE, "awake and well is ACTIVE")
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "sleeps")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_RESTING, "asleep is RESTING")
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_AWAKE).ok, "wakes")
	assert_true(_needs.set_injury_state(0, NeedsScript.INJURY_ACTIVE).ok, "injured")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_ACTIVE,
		"an injury at full health does not yet show as INJURED")
	assert_true(_needs.apply_health_event(0, -1).ok, "loses a point")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_INJURED, "99 with an Injury")
	assert_true(_needs.apply_health_event(0, -84).ok, "badly hurt")
	assert_equal(_health(0), 15, "health 15")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_INCAPACITATED, "1-15 is INCAPACITATED")
	assert_true(_needs.apply_health_event(0, -15).ok, "killed")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_DEAD, "0 is DEAD")


func test_a_treated_resident_becomes_conscious_again_at_sixteen() -> void:
	"""§5.2: "A treated resident becomes conscious once health>=16"."""
	_spawn()
	assert_true(_needs.apply_health_event(0, -90).ok, "reduced to 10")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_INCAPACITATED, "unconscious at 10")
	assert_true(_needs.apply_health_event(0, 5).ok, "treated to 15")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_INCAPACITATED, "still 15")
	assert_true(_needs.apply_health_event(0, 1).ok, "treated to 16")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_ACTIVE, "conscious at 16")


# --- §7.1 mood fixture and the §5.2 factors -----------------------------------------------------------------

func test_the_gdd_7_1_mood_fixture_reproduces_exactly() -> void:
	"""GDD §7.1: hunger 6000, rest 7000, comfort 5000, social 4000, purpose 8000 gives
	(18000+14000+10000+4000+16000)/10 = 6200; a good meal gives 6500 at work factor 1000;
	losing a friend adds -1800 for 4700, still factor 1000."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 6000)
	_set_need(0, NeedsScript.NEED_REST, 7000)
	_set_need(0, NeedsScript.NEED_COMFORT, 5000)
	_set_need(0, NeedsScript.NEED_SOCIAL, 4000)
	_set_need(0, NeedsScript.NEED_PURPOSE, 8000)
	var base := _needs.mood_of(0, 0)
	assert_true(base.ok, "the mood reads")
	assert_equal(base.value, 6200, "the weighted need average is 6200")
	var good_meal: int = _needs.memory_value_of(&"good_meal").value
	assert_equal(good_meal, 300, "the good_meal memory is +300")
	assert_equal(_needs.mood_of(0, good_meal).value, 6500, "a good meal gives 6500")
	assert_equal(_needs.mood_factor(6500), 1000, "6500 is work mood factor 1000")
	var friend_died: int = _needs.memory_value_of(&"friend_died").value
	assert_equal(friend_died, -1800, "the friend_died memory is -1800")
	assert_equal(_needs.mood_of(0, good_meal + friend_died).value, 4700,
		"losing a friend brings the result to 4700")
	assert_equal(_needs.mood_factor(4700), 1000, "4700 is still factor 1000")


func test_a_further_decline_crosses_the_four_thousand_threshold() -> void:
	"""§7.1: "another comfort/hunger decline can cross the 4000 threshold"."""
	_spawn()
	_set_need(0, NeedsScript.NEED_HUNGER, 6000)
	_set_need(0, NeedsScript.NEED_REST, 7000)
	_set_need(0, NeedsScript.NEED_COMFORT, 5000)
	_set_need(0, NeedsScript.NEED_SOCIAL, 4000)
	_set_need(0, NeedsScript.NEED_PURPOSE, 8000)
	var memories: int = _needs.memory_value_of(&"good_meal").value \
		+ _needs.memory_value_of(&"friend_died").value
	_set_need(0, NeedsScript.NEED_COMFORT, 1000)
	assert_equal(_needs.mood_of(0, memories).value, 3900, "comfort 5000 to 1000 costs 800 mood")
	assert_equal(_needs.mood_factor(3900), 800, "below 4000 the productivity factor drops to 800")


func test_mood_is_clamped_and_weighted_exactly_as_written() -> void:
	"""Mood = clamp(floor((3h+2r+2c+s+2p)/10)+memories, 0, 10000), floor not round."""
	_spawn()
	for need: int in NeedsScript.NEED_COUNT:
		_set_need(0, need, 10000)
	assert_equal(_needs.mood_of(0, 0).value, 10000, "every need full is mood 10000")
	assert_equal(_needs.mood_of(0, 500).value, 10000, "a memory cannot push mood past 10000")
	for need: int in NeedsScript.NEED_COUNT:
		_set_need(0, need, 0)
	assert_equal(_needs.mood_of(0, -500).value, 0, "a memory cannot push mood below 0")
	_set_need(0, NeedsScript.NEED_SOCIAL, 9)
	assert_equal(_needs.mood_of(0, 0).value, 0, "9/10 floors to 0 rather than rounding to 1")
	assert_false(_needs.mood_of(9, 0).ok, "an absent resident has no mood")


func test_mood_and_health_factor_bands_match_the_gdd() -> void:
	"""Productivity <2000->600, 2000-3999->800, 4000-6999->1000, 7000-8499->1100, >=8500->1150;
	health <40->600, 40-69->850, >=70->1000."""
	assert_equal(_needs.mood_factor(0), 600, "mood 0")
	assert_equal(_needs.mood_factor(1999), 600, "mood 1999")
	assert_equal(_needs.mood_factor(2000), 800, "mood 2000")
	assert_equal(_needs.mood_factor(3999), 800, "mood 3999")
	assert_equal(_needs.mood_factor(4000), 1000, "mood 4000")
	assert_equal(_needs.mood_factor(6999), 1000, "mood 6999")
	assert_equal(_needs.mood_factor(7000), 1100, "mood 7000")
	assert_equal(_needs.mood_factor(8499), 1100, "mood 8499")
	assert_equal(_needs.mood_factor(8500), 1150, "mood 8500")
	assert_equal(_needs.mood_factor(10000), 1150, "mood 10000")
	assert_equal(_needs.health_factor(39), 600, "health 39")
	assert_equal(_needs.health_factor(40), 850, "health 40")
	assert_equal(_needs.health_factor(69), 850, "health 69")
	assert_equal(_needs.health_factor(70), 1000, "health 70")
	assert_equal(_needs.health_factor(100), 1000, "health 100")


func test_work_factor_multiplies_skill_mood_and_health_before_dividing() -> void:
	"""§5.2: skill=1000+50*level; work factor=clamp(floor(skill*mood*health/1000000),300,1800)."""
	assert_equal(_needs.skill_factor(0).value, 1000, "level 0")
	assert_equal(_needs.skill_factor(4).value, 1200, "level 4")
	assert_equal(_needs.skill_factor(10).value, 1500, "level 10")
	assert_false(_needs.skill_factor(11).ok, "there is no level 11")
	assert_false(_needs.skill_factor(-1).ok, "there is no negative level")
	assert_equal(_needs.work_factor(4, 6500, 100).value, 1200, "1200*1000*1000/1000000")
	assert_equal(_needs.work_factor(10, 10000, 100).value, 1725, "the best case is 1725, under 1800")
	assert_equal(_needs.work_factor(0, 1000, 30).value, 360, "1000*600*600/1000000")
	assert_false(_needs.work_factor(99, 5000, 50).ok, "an impossible skill level refuses")


# --- decision 0024 section 4: the fused work-factor reader ---------------------------------------

func _place_row(slot: int, mood: int, health: int) -> void:
	"""Move one resident's five needs so its weighted mood is exactly `mood`, and set health.

	Every need holds the same value, so REQ-SET-020's weighted sum is `10*value` and its divisor
	is 10 -- the weights cancel and the mood term is the value itself, with no rounding involved.
	"""
	for need: int in NeedsScript.NEED_COUNT:
		_set_need(slot, need, mood)
	assert_equal(_needs.mood_of(slot, 0).value, mood, "the row sits at mood %d" % mood)
	var current: int = _health(slot)
	assert_true(_needs.apply_health_event(slot, health - current).ok,
		"health moves to %d" % health)


func _chain_factor_into(slot: int, level: int, memory_total: int,
		out: IntMath.IntResult) -> bool:
	"""The three-call reader chain work.gd ran before the fused reader: health, mood, factor.

	Kept here rather than in production so the equivalence tests compare the fused reader with
	the sequence it replaced, in the same order and through the same published readers.
	"""
	if not _needs.health_into(slot, out):
		return false
	var health: int = out.value
	if not _needs.mood_into(slot, memory_total, out):
		return false
	var mood: int = out.value
	return _needs.work_factor_into(level, mood, health, out)


func _assert_factor_parity(slot: int, level: int, memory_total: int, label: String) -> void:
	"""Assert the fused reader and the unfused chain agree in flag, value and reason."""
	var chain: IntMath.IntResult = IntMath.IntResult.new()
	var fused: IntMath.IntResult = IntMath.IntResult.new()
	var chain_ok: bool = _chain_factor_into(slot, level, memory_total, chain)
	var fused_ok: bool = _needs.work_factor_for_resident_into(slot, level, memory_total, fused)
	assert_equal(fused_ok, chain_ok, "%s: both paths agree on success" % label)
	assert_equal(fused.value, chain.value, "%s: both paths agree on the value" % label)
	assert_equal(fused.error, chain.error, "%s: both paths agree on the reason" % label)


func test_the_fused_work_factor_reader_agrees_with_the_unfused_chain_in_every_band() -> void:
	"""Decision 0024 section 4's reader must return what the three-call chain returned, exactly.

	The sweep covers both edges of every §5.2 mood band (<2000, 2000-3999, 4000-6999, 7000-8499,
	>=8500), both edges of every health band (<40, 40-69, >=70) and every legal skill level 0-10
	-- 660 combinations, each compared against the chain rather than against a recorded number.
	"""
	_spawn()
	for mood: int in FUSED_MOOD_PROBES:
		for health: int in FUSED_HEALTH_PROBES:
			_place_row(0, mood, health)
			for level: int in NeedsScript.SKILL_LEVEL_MAX + 1:
				_assert_factor_parity(0, level, 0,
					"mood %d health %d level %d" % [mood, health, level])


func test_the_fused_work_factor_reader_agrees_with_the_chain_on_memory_totals() -> void:
	"""The memory term is an argument, not stored state, so it is swept separately.

	The extremes push mood past both ends of REQ-SET-020's 0-10000 clamp, which is the one place
	the two paths could disagree by clamping in different orders.
	"""
	_spawn()
	_place_row(0, 5000, 70)
	for memory_total: int in FUSED_MEMORY_PROBES:
		for level: int in NeedsScript.SKILL_LEVEL_MAX + 1:
			_assert_factor_parity(0, level, memory_total,
				"memory %d level %d" % [memory_total, level])


func test_the_fused_work_factor_reader_refuses_exactly_as_the_unfused_chain_does() -> void:
	"""Refusal parity, not just value parity: an unusable input must be unusable identically.

	A negative slot, a slot past capacity, a never-spawned row and a despawned row all fail in
	the needs store; a negative and an over-cap skill level fail in the factor step. Both paths
	must refuse each of them with the same reason and carry no number.
	"""
	_spawn(0)
	_spawn(1)
	assert_true(_needs.despawn(1).ok, "the second row despawns")
	_assert_factor_parity(-1, 0, 0, "a negative slot")
	_assert_factor_parity(NeedsScript.RESIDENT_CAPACITY, 0, 0, "a slot past capacity")
	_assert_factor_parity(7, 0, 0, "a never-spawned row")
	_assert_factor_parity(1, 0, 0, "a despawned row")
	_assert_factor_parity(0, -1, 0, "a negative skill level")
	_assert_factor_parity(0, NeedsScript.SKILL_LEVEL_MAX + 1, 0, "a skill level past the cap")
	_assert_factor_parity(-1, NeedsScript.SKILL_LEVEL_MAX + 1, 0,
		"a bad slot and a bad level together, where the ORDER of the two checks decides")
	var fused: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(_needs.work_factor_for_resident_into(1, 0, 0, fused), "the despawned row refuses")
	assert_equal(fused.error, String(NeedsScript.REFUSE_NOT_PRESENT), "with the presence code")
	assert_equal(fused.value, 0, "and no plausible-looking number")


func test_the_fused_work_factor_reader_computes_the_gdd_factors_from_the_stored_row() -> void:
	"""Absolute §5.2 answers, so a change to the shared formula fails HERE as well as in the
	chain's own tests -- which is what proves the two share one implementation."""
	_spawn()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_place_row(0, 6500, 100)
	assert_true(_needs.work_factor_for_resident_into(0, 4, 0, out), "level 4 at mood 6500 reads")
	assert_equal(out.value, 1200, "1200*1000*1000/1000000")
	_place_row(0, 10000, 100)
	assert_true(_needs.work_factor_for_resident_into(0, 10, 0, out), "the best case reads")
	assert_equal(out.value, 1725, "1500*1150*1000/1000000, under the 1800 ceiling")
	_place_row(0, 1000, 30)
	assert_true(_needs.work_factor_for_resident_into(0, 0, 0, out), "the worst case reads")
	assert_equal(out.value, 360, "1000*600*600/1000000, above the 300 floor")
	_place_row(0, 5000, 100)
	assert_true(_needs.work_factor_for_resident_into(0, 0, 3000, out), "a memory total reads")
	assert_equal(out.value, 1100, "mood 5000+3000 lands in the 7000-8499 band")
	assert_true(_needs.work_factor_for_resident_into(0, 0, -100000, out), "a huge penalty reads")
	assert_equal(out.value, 600, "mood clamps to 0, whose band is 600")


func test_the_fused_work_factor_reader_reads_the_row_as_it_stands_on_every_call() -> void:
	"""Decision 0024 section 4: a call-count reduction, NOT a cache.

	Each call must observe the columns at that instant. A need change, then a health change,
	between calls on the same resident must both move the answer immediately -- there is nothing
	retained to invalidate, and this test is what would fail if a cache were ever added quietly.
	"""
	_spawn()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_place_row(0, 8500, 100)
	assert_true(_needs.work_factor_for_resident_into(0, 10, 0, out), "the first read succeeds")
	assert_equal(out.value, 1725, "mood 8500 at full health and level 10 gives 1725")
	_set_need(0, NeedsScript.NEED_HUNGER, 0)
	assert_true(_needs.work_factor_for_resident_into(0, 10, 0, out), "the second read succeeds")
	assert_equal(out.value, 1500, "emptying hunger drops mood to 5950, whose band is 1000")
	assert_true(_needs.apply_health_event(0, -40).ok, "health falls to 60")
	assert_true(_needs.work_factor_for_resident_into(0, 10, 0, out), "the third read succeeds")
	assert_equal(out.value, 1275, "1500*1000*850/1000000 floors to 1275")


func test_a_fused_refusal_overwrites_a_previous_success_in_the_same_result() -> void:
	"""A caller-owned result reused across calls must never let an earlier factor read as this
	call's answer -- the finding H4 sentinel, in the shape this reader could reintroduce it."""
	_spawn()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	_place_row(0, 6500, 100)
	assert_true(_needs.work_factor_for_resident_into(0, 4, 0, out), "a successful read first")
	assert_equal(out.value, 1200, "carrying a real factor")
	assert_false(_needs.work_factor_for_resident_into(0, NeedsScript.SKILL_LEVEL_MAX + 1, 0, out),
		"then an impossible skill level")
	assert_false(out.ok, "the result reads as a refusal")
	assert_equal(out.value, 0, "the earlier factor cannot survive as this call's answer")
	assert_equal(out.error, String(NeedsScript.REFUSE_INVALID_SKILL_LEVEL), "with the reason")
	assert_false(_needs.work_factor_for_resident_into(9, 4, 0, out), "and an absent row too")
	assert_equal(out.error, String(NeedsScript.REFUSE_NOT_PRESENT), "reported as absence")


# --- the §5.2 memory catalog ---------------------------------------------------------------------------------

func test_the_memory_catalog_matches_the_gdd_values_and_durations() -> void:
	"""Every (value, duration hours) pair from §5.2's memory catalog."""
	var expected: Dictionary = {
		&"good_meal": [300, 6], &"excellent_meal": [600, 8], &"monotonous_meal": [-400, 6],
		&"feast": [1000, 24], &"friend_died": [-1800, 72], &"stranger_died": [-300, 24],
		&"rescued": [600, 48], &"cold_home": [-600, 12], &"conflict": [-600, 12],
		&"milestone": [500, 24],
	}
	for key: StringName in expected:
		var pair: Array = expected[key]
		assert_equal(_needs.memory_value_of(key).value, pair[0], "%s value" % key)
		assert_equal(_needs.memory_duration_hours_of(key).value, pair[1], "%s duration" % key)
	assert_equal(_needs.memory_value_of(&"untreated_injury").value, -800, "untreated_injury value")
	assert_equal(NeedsScript.MEMORY_SLOTS_PER_RESIDENT, 8, "up to eight memories per resident")


func test_untreated_injury_has_no_hour_duration_and_says_so() -> void:
	"""§5.2 gives it "until treated", so a duration read refuses instead of inventing a number."""
	var conditional := _needs.memory_duration_hours_of(&"untreated_injury")
	assert_false(conditional.ok, "the duration read refuses")
	assert_equal(conditional.value, 0, "and carries no usable number")
	assert_false(_needs.memory_value_of(&"nostalgia").ok, "an unknown memory key refuses")
	assert_false(_needs.memory_duration_hours_of(&"nostalgia").ok, "for durations too")


func test_memory_keys_are_in_ascending_ascii_order() -> void:
	"""BAL-CAT-001: catalog members are enumerated in sorted key order, never insertion order."""
	var keys: Array[StringName] = NeedsScript.MEMORY_KEYS
	assert_equal(keys.size(), 11, "eleven memory kinds")
	assert_equal(keys.size(), NeedsScript.MEMORY_VALUES.size(), "one value per key")
	assert_equal(keys.size(), NeedsScript.MEMORY_DURATION_HOURS.size(), "one duration per key")
	for index: int in range(1, keys.size()):
		assert_true(String(keys[index - 1]) < String(keys[index]),
			"%s sorts before %s" % [keys[index - 1], keys[index]])


# --- deferred surfaces ----------------------------------------------------------------------------------------

func test_departure_days_is_reserved_and_never_written() -> void:
	"""REQ-SET-021..024 are deferred: the column exists, stays zero, and claims nothing."""
	_spawn()
	for need: int in NeedsScript.NEED_COUNT:
		_set_need(0, need, 0)
	_tick(0, HOUR * 24)
	assert_equal(_needs.mood_of(0, 0).value, 0, "the resident is as miserable as possible")
	assert_equal(_needs.departure_days_of(0).value, 0,
		"departure is not counted here, so the column stays explicitly zero")


# --- the integrator's overflow preconditions -----------------------------------------------------------------

func test_the_remainder_invariant_holds_across_a_long_varied_run() -> void:
	"""_integrate_step()'s overflow proof assumes |remainder| < denominator on entry.

	That is the invariant the function re-establishes on every step, and it is what makes the
	unchecked accumulator arithmetic sound, so it is asserted against real state rather than
	argued: 6000 ticks across sleeping, working, socialising, freezing and starving.
	"""
	_spawn()
	for phase: int in 6:
		_drive_phase(phase)
		for need: int in NeedsScript.NEED_COUNT:
			var remainder: int = _remainder(0, need)
			assert_true(absi(remainder) < NeedsScript.NEED_DENOMINATOR,
				"need %d remainder stays inside its denominator" % need)
		assert_true(absi(_needs.health_remainder_of(0).value) < NeedsScript.HEALTH_DENOMINATOR,
			"the health remainder stays inside its denominator")


func _drive_phase(phase: int) -> void:
	"""Run 1000 ticks under one combination of the environment inputs."""
	assert_true(_needs.set_activity(0, phase % NeedsScript.ACTIVITY_COUNT).ok, "activity set")
	assert_true(_needs.set_comfort_environment(0, phase % NeedsScript.COMFORT_ENV_COUNT).ok, "comfort")
	assert_true(_needs.set_social_paired(0, phase % 2 == 0).ok, "pairing set")
	assert_true(_needs.set_purpose_source(0, phase % NeedsScript.PURPOSE_SOURCE_COUNT).ok, "purpose")
	assert_true(_needs.set_cold_environment(0, phase % NeedsScript.COLD_ENV_COUNT).ok, "cold")
	assert_true(_needs.set_clothing_tier(0, 1 + phase % 2).ok, "clothing set")
	if _needs.is_alive(0):
		_tick(0, 1000)


func test_every_published_rate_is_inside_the_bound_the_integrator_relies_on() -> void:
	"""MAX_RATE_MAGNITUDE is the other half of the overflow proof, so no rate may exceed it."""
	var bound: int = NeedsScript.MAX_RATE_MAGNITUDE
	assert_true(_needs.set_winter(true).ok, "the worst case is a large resident in winter")
	assert_true(_needs.set_hard_freeze(true).ok, "with the worst cold gain")
	for size_class: int in NeedsScript.SIZE_COUNT:
		assert_true(_needs.hunger_rate_milli_per_hour(size_class).value <= bound,
			"hunger rate for size %d is inside the bound" % size_class)
	assert_true(NeedsScript.REST_RESTORE_BED_MILLI_PER_HOUR <= bound, "bed sleep")
	assert_true(NeedsScript.SOCIAL_RESTORE_PAIRED_MILLI_PER_HOUR <= bound, "paired social")
	assert_true(NeedsScript.PURPOSE_RESTORE_MENTORING_MILLI_PER_HOUR
		+ NeedsScript.PURPOSE_DECAY_MILLI_PER_HOUR <= bound, "mentoring net of decay")
	assert_true(NeedsScript.COLD_GAIN_HARD_FREEZE_TIER1_MILLI_PER_HOUR <= bound, "hard-freeze cold")
	assert_true(NeedsScript.COLD_CLEAR_SHELTER_MILLI_PER_HOUR <= bound, "shelter clearing")
	assert_true(NeedsScript.HEALTH_STARVATION_DRAIN_PER_HOUR
		+ NeedsScript.HEALTH_COLD_DRAIN_PER_HOUR
		+ NeedsScript.HEALTH_RECOVERY_INFIRMARY_PER_HOUR <= bound, "every health cause at once")


func test_the_integrator_refuses_a_broken_precondition_instead_of_integrating_it() -> void:
	"""The three guards are unreachable through the public API by construction, so they are
	exercised directly: an unproven input must refuse, never produce a plausible number.

	These are the branches that would go uncovered otherwise -- the finding H6 shape -- and
	each one is a proof obligation for the arithmetic that follows it.
	"""
	var over: int = NeedsScript.MAX_RATE_MAGNITUDE + 1
	assert_equal(_needs._integrate_step(0, 0, over, NeedsScript.NEED_DENOMINATOR, 0, 10000),
		NeedsScript.REFUSE_RATE_OUT_OF_RANGE, "a rate above the bound refuses")
	assert_equal(_needs._integrate_step(0, 0, -over, NeedsScript.NEED_DENOMINATOR, 0, 10000),
		NeedsScript.REFUSE_RATE_OUT_OF_RANGE, "a rate below the bound refuses")
	assert_equal(_needs._integrate_step(0, 0, 1000, 0, 0, 10000),
		NeedsScript.REFUSE_INVALID_DENOMINATOR, "a zero denominator refuses")
	assert_equal(_needs._integrate_step(0, 0, 1000, -750, 0, 10000),
		NeedsScript.REFUSE_INVALID_DENOMINATOR, "a negative denominator refuses")
	assert_equal(_needs._integrate_step(0, NeedsScript.NEED_DENOMINATOR, 1000,
		NeedsScript.NEED_DENOMINATOR, 0, 10000), NeedsScript.REFUSE_REMAINDER_INVARIANT,
		"a remainder at the denominator refuses")
	assert_equal(_needs._integrate_step(0, -NeedsScript.NEED_DENOMINATOR, 1000,
		NeedsScript.NEED_DENOMINATOR, 0, 10000), NeedsScript.REFUSE_REMAINDER_INVARIANT,
		"a negative remainder at the denominator refuses")
	assert_equal(_needs._integrate_step(9223372036854775807, 0, 750000,
		NeedsScript.NEED_DENOMINATOR, 0, 9223372036854775807), NeedsScript.REFUSE_OVERFLOW,
		"an int64 value that cannot absorb its whole units refuses rather than wrapping")


# --- NEED-RATE-R01: the four published net need-rate readers ---------------------------------
#
# These tests exist in two halves and BOTH halves are load-bearing.
#
# The first half pins each of the seventeen inherited rate rows to its literal number from the
# ruling's table. Written alone that proves very little: a reader and its expectation can share
# one wrong expression and agree with each other forever. The ruling says so outright -- "do not
# compare only two functions sharing the same mistaken expression."
#
# The second half is what makes the first half mean something. For each row it runs 750 ACTUAL
# ticks of the real integrator from an interior value with a known nonzero starting remainder,
# and requires the published rate R to predict both the released whole units and the retained
# signed remainder exactly:
#
#     delta     = trunc((initial_remainder + 750*R) / 750000)
#     remainder = (initial_remainder + 750*R) - 750000*delta
#
# A sign error, a doubled negation or a baseline subtracted twice survives the table and dies
# here, because the integrator is not reading the same expression the reader is.

## Every signed row of the ruling's fixture table: reader name, the context to install, and R.
const RATE_FIXTURES: Array[Dictionary] = [
	{&"need": 1, &"activity": 1, &"rate": 1200000, &"label": "rest sleeping in bed"},
	{&"need": 1, &"activity": 2, &"rate": 750000, &"label": "rest sleeping on the floor"},
	{&"need": 1, &"activity": 0, &"rate": -375000, &"label": "rest awake"},
	{&"need": 2, &"comfort": 1, &"rate": 200000, &"label": "comfort in a valid heated room"},
	{&"need": 2, &"comfort": 2, &"rate": 0, &"label": "comfort in mild outdoors"},
	{&"need": 2, &"comfort": 0, &"rate": -100000, &"label": "comfort with no restoration"},
	{&"need": 3, &"paired": true, &"rate": 1100000, &"label": "social paired"},
	{&"need": 3, &"paired": false, &"rate": -100000, &"label": "social unpaired"},
	{&"need": 4, &"purpose": 1, &"rate": 245000, &"label": "purpose from useful labor"},
	{&"need": 4, &"purpose": 2, &"rate": 325000, &"label": "purpose from mentoring"},
	{&"need": 4, &"purpose": 0, &"rate": -75000, &"label": "purpose with no restoration"},
]

## The six hunger rows: size class, winter flag and the POSITIVE decay magnitude the existing
## `hunger_rate_milli_per_hour()` publishes. The signed rate the integrator uses is -magnitude.
const HUNGER_FIXTURES: Array[Dictionary] = [
	{&"size": 0, &"winter": false, &"magnitude": 250000, &"label": "hunger small, nonwinter"},
	{&"size": 1, &"winter": false, &"magnitude": 300000, &"label": "hunger medium, nonwinter"},
	{&"size": 2, &"winter": false, &"magnitude": 400000, &"label": "hunger large, nonwinter"},
	{&"size": 0, &"winter": true, &"magnitude": 300000, &"label": "hunger small, winter"},
	{&"size": 1, &"winter": true, &"magnitude": 360000, &"label": "hunger medium, winter"},
	{&"size": 2, &"winter": true, &"magnitude": 480000, &"label": "hunger large, winter"},
]

## One tick in the DEFAULT context before the fixture context is installed. Without it the
## rest-on-the-floor row is untestable for carry: +750000/hour is exactly the 750000 denominator,
## so from a zero remainder it releases a whole point every tick and never retains anything.
## Priming from the awake rate gives even that row a nonzero signed remainder to carry.
const RATE_PRIME_TICKS: int = 1
## Ticks run in the fixture's own context before the measured hour. Together with the priming
## tick this leaves every one of the seventeen rows a nonzero retained remainder; each value is
## worked out in the ruling's own arithmetic, not discovered by running the code.
const RATE_WARMUP_TICKS: int = 100


func _trunc_div(numerator: int, denominator: int) -> int:
	"""Integer division truncated toward zero, written out rather than assumed of `/`."""
	var quotient: int = absi(numerator) / denominator
	return -quotient if numerator < 0 else quotient


func _rate_into(need: int, slot: int, out: IntMath.IntResult) -> bool:
	"""Dispatch to the published reader that owns `need`, so one test body covers all four."""
	match need:
		NeedsScript.NEED_REST:
			return _needs.rest_rate_milli_per_hour_into(slot, out)
		NeedsScript.NEED_COMFORT:
			return _needs.comfort_rate_milli_per_hour_into(slot, out)
		NeedsScript.NEED_SOCIAL:
			return _needs.social_rate_milli_per_hour_into(slot, out)
		NeedsScript.NEED_PURPOSE:
			return _needs.purpose_rate_milli_per_hour_into(slot, out)
	fail("no published reader owns need %d" % need)
	return false


func _rate(need: int, slot: int = 0) -> int:
	"""Read one published net rate, asserting the read succeeded and returning its value."""
	var out := IntMath.IntResult.new()
	assert_true(_rate_into(need, slot, out), "rate reader for need %d succeeds" % need)
	assert_true(out.ok, "rate reader for need %d reports ok" % need)
	return out.value


func _install_context(fixture: Dictionary, slot: int = 0) -> void:
	"""Install one fixture's activity / comfort environment / pairing / purpose source."""
	if fixture.has(&"activity"):
		assert_true(_needs.set_activity(slot, int(fixture[&"activity"])).ok, "activity set")
	if fixture.has(&"comfort"):
		assert_true(_needs.set_comfort_environment(slot, int(fixture[&"comfort"])).ok,
			"comfort environment set")
	if fixture.has(&"paired"):
		assert_true(_needs.set_social_paired(slot, bool(fixture[&"paired"])).ok, "pairing set")
	if fixture.has(&"purpose"):
		assert_true(_needs.set_purpose_source(slot, int(fixture[&"purpose"])).ok, "purpose set")


func test_every_published_rate_row_matches_its_inherited_fixture() -> void:
	"""Pin all eleven signed rows of the ruling's table to their literal milli/hour numbers."""
	for fixture: Dictionary in RATE_FIXTURES:
		_needs = NeedsScript.new()
		_spawn()
		_install_context(fixture)
		assert_equal(_rate(int(fixture[&"need"])), int(fixture[&"rate"]),
			"%s is %d milli/hour" % [fixture[&"label"], fixture[&"rate"]])


func test_every_hunger_fixture_row_matches_its_positive_decay_magnitude() -> void:
	"""The six size/season hunger rows. This reader keeps its POSITIVE magnitude contract."""
	for fixture: Dictionary in HUNGER_FIXTURES:
		_needs = NeedsScript.new()
		_spawn(0, int(fixture[&"size"]))
		assert_true(_needs.set_winter(bool(fixture[&"winter"])).ok, "season set")
		var result := _needs.hunger_rate_milli_per_hour(int(fixture[&"size"]))
		assert_true(result.ok, "hunger_rate_milli_per_hour succeeds")
		assert_equal(result.value, int(fixture[&"magnitude"]),
			"%s is +%d milli/hour" % [fixture[&"label"], fixture[&"magnitude"]])
		assert_true(result.value > 0, "%s stays a positive magnitude" % fixture[&"label"])


func _assert_hour_matches_rate(slot: int, need: int, rate: int, label: String) -> void:
	"""Run 750 real ticks and require `rate` to predict the delta AND the retained remainder."""
	var value_before: int = _need(slot, need)
	var remainder_before: int = _remainder(slot, need)
	_tick(slot, HOUR)
	var total: int = remainder_before + HOUR * rate
	var whole: int = _trunc_div(total, NeedsScript.NEED_DENOMINATOR)
	assert_equal(_need(slot, need) - value_before, whole,
		"%s releases trunc((r0 + 750R)/750000) = %d over an hour" % [label, whole])
	assert_equal(_remainder(slot, need), total - whole * NeedsScript.NEED_DENOMINATOR,
		"%s retains the exact signed remainder" % label)


func test_every_published_rate_predicts_750_real_ticks_from_a_nonzero_remainder() -> void:
	"""The check that makes the fixture table mean something: the integrator must agree.

	Each row starts from an interior value of 5000, warms up until it carries a nonzero signed
	remainder, and is then required to move by exactly what its published rate says over one
	simulated hour. A reader that shares a wrong expression with its expectation dies here.
	"""
	for fixture: Dictionary in RATE_FIXTURES:
		_needs = NeedsScript.new()
		_spawn()
		var need: int = int(fixture[&"need"])
		var rate: int = int(fixture[&"rate"])
		_set_need(0, need, 5000)
		_tick(0, RATE_PRIME_TICKS)
		_install_context(fixture)
		_tick(0, RATE_WARMUP_TICKS)
		assert_true(_remainder(0, need) != 0,
			"%s carries a nonzero remainder into the hour" % fixture[&"label"])
		assert_equal(_rate(need), rate, "%s still reads its rate" % fixture[&"label"])
		_assert_hour_matches_rate(0, need, rate, String(fixture[&"label"]))


func test_every_hunger_fixture_predicts_750_real_ticks_as_a_negative_rate() -> void:
	"""Hunger's published magnitude, negated exactly once, must predict the real integration."""
	for fixture: Dictionary in HUNGER_FIXTURES:
		_needs = NeedsScript.new()
		_spawn(0, int(fixture[&"size"]))
		assert_true(_needs.set_winter(bool(fixture[&"winter"])).ok, "season set")
		var result := _needs.hunger_rate_milli_per_hour(int(fixture[&"size"]))
		assert_true(result.ok, "hunger_rate_milli_per_hour succeeds")
		_set_need(0, NeedsScript.NEED_HUNGER, 5000)
		_tick(0, RATE_PRIME_TICKS + RATE_WARMUP_TICKS)
		assert_true(_remainder(0, NeedsScript.NEED_HUNGER) != 0, "a nonzero remainder is carried")
		_assert_hour_matches_rate(0, NeedsScript.NEED_HUNGER, -result.value,
			String(fixture[&"label"]))


func test_a_zero_comfort_rate_retains_its_remainder_across_a_whole_hour() -> void:
	"""Mild outdoors is a real 0: an hour of it moves nothing and discards no carried remainder."""
	_spawn()
	_set_need(0, NeedsScript.NEED_COMFORT, 5000)
	_tick(0, 1)
	var carried: int = _remainder(0, NeedsScript.NEED_COMFORT)
	assert_equal(carried, -NeedsScript.COMFORT_DECAY_MILLI_PER_HOUR, "one awake tick carries -100000")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_MILD_OUTDOORS).ok,
		"mild outdoors set")
	assert_equal(_rate(NeedsScript.NEED_COMFORT), 0, "mild outdoors is a net zero rate")
	_assert_hour_matches_rate(0, NeedsScript.NEED_COMFORT, 0, "comfort mild outdoors")
	assert_equal(_remainder(0, NeedsScript.NEED_COMFORT), carried,
		"a zero rate neither releases nor discards the retained remainder")


func test_a_direction_change_carries_the_signed_remainder_into_the_new_rate() -> void:
	"""Waking rates are negative and sleeping rates positive; the carried remainder changes sign."""
	_spawn()
	_set_need(0, NeedsScript.NEED_REST, 5000)
	_tick(0, 1)
	assert_equal(_remainder(0, NeedsScript.NEED_REST), -375000, "an awake tick carries -375000")
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_BED).ok, "sent to bed")
	assert_equal(_rate(NeedsScript.NEED_REST), 1200000, "the bed rate is read immediately")
	_assert_hour_matches_rate(0, NeedsScript.NEED_REST, 1200000, "rest bed after an awake tick")
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_AWAKE).ok, "woken again")
	assert_equal(_rate(NeedsScript.NEED_REST), -375000, "the awake rate returns immediately")
	_assert_hour_matches_rate(0, NeedsScript.NEED_REST, -375000, "rest awake after a bed hour")


func test_every_context_change_is_visible_on_the_next_read_with_no_cached_lag() -> void:
	"""No cache, no dirty flag: each setter changes the published rate on the very next call."""
	_spawn()
	assert_equal(_rate(NeedsScript.NEED_REST), -375000, "awake")
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "to the floor")
	assert_equal(_rate(NeedsScript.NEED_REST), 750000, "floor, with no intervening tick")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	assert_equal(_rate(NeedsScript.NEED_COMFORT), 200000, "heated room, with no intervening tick")
	assert_true(_needs.set_social_paired(0, true).ok, "paired")
	assert_equal(_rate(NeedsScript.NEED_SOCIAL), 1100000, "paired, with no intervening tick")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_MENTORING).ok, "mentoring")
	assert_equal(_rate(NeedsScript.NEED_PURPOSE), 325000, "mentoring, with no intervening tick")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "labor")
	assert_equal(_rate(NeedsScript.NEED_PURPOSE), 245000, "labor, with no intervening tick")


func test_a_rate_reader_refuses_an_invalid_free_or_dead_row_with_a_cleared_value() -> void:
	"""Refusal travels on `.ok` with the real reason and a zeroed value; 0 is not an answer."""
	_spawn(3)
	assert_true(_needs.apply_health_event(3, -NeedsScript.INITIAL_HEALTH).ok, "resident dies")
	_spawn(4)
	assert_true(_needs.despawn(4).ok, "slot 4 released")
	var cases: Array[Array] = [
		[-1, NeedsScript.REFUSE_INVALID_SLOT], [NeedsScript.RESIDENT_CAPACITY,
		NeedsScript.REFUSE_INVALID_SLOT], [5, NeedsScript.REFUSE_NOT_PRESENT],
		[4, NeedsScript.REFUSE_NOT_PRESENT], [3, NeedsScript.REFUSE_RESIDENT_DEAD],
	]
	for need: int in [NeedsScript.NEED_REST, NeedsScript.NEED_COMFORT, NeedsScript.NEED_SOCIAL,
			NeedsScript.NEED_PURPOSE]:
		for case: Array in cases:
			var out := IntMath.IntResult.new()
			out.succeed(999999)
			assert_false(_rate_into(need, int(case[0]), out),
				"need %d at slot %d refuses" % [need, case[0]])
			assert_false(out.ok, "the refusal is on the ok channel")
			assert_equal(out.value, 0, "the refused value is cleared, not left at 999999")
			assert_equal(out.error, String(case[1]), "the actual refusal reason is named")


func test_a_reused_slot_publishes_the_new_residents_rates_not_the_previous_ones() -> void:
	"""Slot reuse must not leak the retired resident's context into the replacement's rates."""
	_spawn(7, NeedsScript.SIZE_LARGE)
	assert_true(_needs.set_activity(7, NeedsScript.ACTIVITY_SLEEP_BED).ok, "in bed")
	assert_true(_needs.set_comfort_environment(7, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	assert_true(_needs.set_social_paired(7, true).ok, "paired")
	assert_true(_needs.set_purpose_source(7, NeedsScript.PURPOSE_SOURCE_MENTORING).ok, "mentoring")
	assert_equal(_rate(NeedsScript.NEED_REST, 7), 1200000, "the first resident sleeps in a bed")
	assert_true(_needs.despawn(7).ok, "slot 7 released")
	var stale := IntMath.IntResult.new()
	assert_false(_needs.rest_rate_milli_per_hour_into(7, stale), "a released slot has no rate")
	assert_equal(stale.error, String(NeedsScript.REFUSE_NOT_PRESENT), "the reason is NOT_PRESENT")
	_spawn(7, NeedsScript.SIZE_SMALL)
	assert_equal(_rate(NeedsScript.NEED_REST, 7), -375000, "the replacement is awake")
	assert_equal(_rate(NeedsScript.NEED_COMFORT, 7), -100000, "the replacement has no heating")
	assert_equal(_rate(NeedsScript.NEED_SOCIAL, 7), -100000, "the replacement is unpaired")
	assert_equal(_rate(NeedsScript.NEED_PURPOSE, 7), -75000, "the replacement has no purpose source")


func _observable_state(slot: int) -> PackedInt64Array:
	"""Every value this module publishes for one resident, plus the store-wide counters."""
	var snapshot := PackedInt64Array()
	for need: int in NeedsScript.NEED_COUNT:
		snapshot.append(_need(slot, need))
		snapshot.append(_remainder(slot, need))
	snapshot.append(_health(slot))
	snapshot.append(_needs.health_remainder_of(slot).value)
	snapshot.append(_needs.cold_milli_hours_of(slot).value)
	snapshot.append(_needs.cold_hours_of(slot).value)
	snapshot.append(_needs.starving_hours_of(slot).value)
	snapshot.append(_needs.departure_days_of(slot).value)
	snapshot.append(_needs.status_of(slot).value)
	snapshot.append(_needs.size_class_of(slot).value)
	snapshot.append(_needs.present_count())
	snapshot.append(_needs.living_count())
	snapshot.append(_needs.death_count())
	snapshot.append(1 if _needs.is_winter() else 0)
	snapshot.append(1 if _needs.is_hard_freeze() else 0)
	for size_class: int in NeedsScript.SIZE_COUNT:
		snapshot.append(_needs.hunger_rate_milli_per_hour(size_class).value)
	return snapshot


func test_repeated_rate_reads_leave_every_observable_state_value_unchanged() -> void:
	"""Asking for a rate applies no event: 400 reads mid-run change nothing that is published."""
	_spawn(0, NeedsScript.SIZE_MEDIUM)
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_BED).ok, "in bed")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "labor")
	_tick(0, 400)
	var before: PackedInt64Array = _observable_state(0)
	var out := IntMath.IntResult.new()
	for _repeat: int in 100:
		for need: int in [NeedsScript.NEED_REST, NeedsScript.NEED_COMFORT,
				NeedsScript.NEED_SOCIAL, NeedsScript.NEED_PURPOSE]:
			assert_true(_rate_into(need, 0, out), "the read succeeds")
	assert_equal(_observable_state(0), before, "400 rate reads changed no published value")


func test_rate_reads_do_not_perturb_the_simulation_a_twin_store_runs_without_them() -> void:
	"""The strongest no-side-effect check available: two identical stores, one read constantly.

	Private columns cannot be snapshotted from a test, so divergence is detected the way it
	would actually hurt -- by running both stores forward and comparing every published value.
	A reader that wrote a remainder, flipped an activity flag or applied an event would show up
	here even though `_activity` and `_rate_scratch` are invisible from outside.
	"""
	var quiet: NeedsScript = NeedsScript.new()
	assert_true(quiet.spawn(0, NeedsScript.SIZE_LARGE).ok, "twin spawns")
	assert_true(quiet.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "twin on the floor")
	assert_true(quiet.set_social_paired(0, true).ok, "twin paired")
	_spawn(0, NeedsScript.SIZE_LARGE)
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "on the floor")
	assert_true(_needs.set_social_paired(0, true).ok, "paired")
	var out := IntMath.IntResult.new()
	for _tick_index: int in 900:
		for need: int in [NeedsScript.NEED_REST, NeedsScript.NEED_COMFORT,
				NeedsScript.NEED_SOCIAL, NeedsScript.NEED_PURPOSE]:
			assert_true(_rate_into(need, 0, out), "the interleaved read succeeds")
		assert_true(_needs.tick(0).ok, "the observed store ticks")
		assert_true(quiet.tick(0).ok, "the twin ticks")
	var observed: PackedInt64Array = _observable_state(0)
	_needs = quiet
	assert_equal(observed, _observable_state(0), "900 interleaved reads produced no divergence")


func test_a_capped_need_still_publishes_its_outward_rate_and_moves_on_an_inward_one() -> void:
	"""UXV-020: at a bound keep R and mark Capped. The reader never reports 0 for a capped row."""
	_spawn()
	_set_need(0, NeedsScript.NEED_COMFORT, NeedsScript.NEED_MIN)
	assert_equal(_rate(NeedsScript.NEED_COMFORT), -100000, "an emptied need still publishes -1.00")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_COMFORT), NeedsScript.NEED_MIN, "it stays at the floor")
	assert_equal(_remainder(0, NeedsScript.NEED_COMFORT), 0, "outward remainder is discarded")
	assert_equal(_rate(NeedsScript.NEED_COMFORT), -100000, "and the published rate is unchanged")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	assert_equal(_rate(NeedsScript.NEED_COMFORT), 200000, "the inward rate publishes immediately")
	_assert_hour_matches_rate(0, NeedsScript.NEED_COMFORT, 200000, "comfort recovering off the floor")


func test_a_full_need_still_publishes_its_outward_rate_and_moves_on_an_inward_one() -> void:
	"""The same rule at the 10000 ceiling, where the outward direction is the positive one."""
	_spawn()
	assert_true(_needs.set_social_paired(0, true).ok, "paired")
	_set_need(0, NeedsScript.NEED_SOCIAL, NeedsScript.NEED_MAX)
	assert_equal(_rate(NeedsScript.NEED_SOCIAL), 1100000, "a full need still publishes +11.00")
	_tick(0, HOUR)
	assert_equal(_need(0, NeedsScript.NEED_SOCIAL), NeedsScript.NEED_MAX, "it stays at the ceiling")
	assert_equal(_remainder(0, NeedsScript.NEED_SOCIAL), 0, "outward remainder is discarded")
	assert_equal(_rate(NeedsScript.NEED_SOCIAL), 1100000, "and the published rate is unchanged")
	assert_true(_needs.set_social_paired(0, false).ok, "unpaired")
	assert_equal(_rate(NeedsScript.NEED_SOCIAL), -100000, "the inward rate publishes immediately")
	_assert_hour_matches_rate(0, NeedsScript.NEED_SOCIAL, -100000, "social decaying off the ceiling")


func test_published_rates_are_per_simulated_hour_and_ignore_tick_cadence() -> void:
	"""REQ-SET-003: pause and 0/1/2/4 run different numbers of ticks, never a different rate.

	The store has no speed input by design, so speed is exactly "how many ticks were run". A
	paused frame runs none. At equal model conditions every one of those must publish the same
	per-simulated-hour number.
	"""
	_spawn(0, NeedsScript.SIZE_MEDIUM)
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_BED).ok, "in bed")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_LABOR).ok, "labor")
	for ticks_this_frame: int in [0, 0, 1, 2, 4]:
		_tick(0, ticks_this_frame)
		assert_equal(_rate(NeedsScript.NEED_REST), 1200000, "rest is unscaled by tick cadence")
		assert_equal(_rate(NeedsScript.NEED_COMFORT), -100000, "comfort is unscaled")
		assert_equal(_rate(NeedsScript.NEED_SOCIAL), -100000, "social is unscaled")
		assert_equal(_rate(NeedsScript.NEED_PURPOSE), 245000, "purpose is unscaled")


func test_each_reader_publishes_only_its_own_need_column() -> void:
	"""Four distinct contexts at once, so a reader wired to the wrong scratch entry is caught."""
	_spawn()
	assert_true(_needs.set_activity(0, NeedsScript.ACTIVITY_SLEEP_FLOOR).ok, "on the floor")
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_HEATED_ROOM).ok, "heated")
	assert_true(_needs.set_social_paired(0, true).ok, "paired")
	assert_true(_needs.set_purpose_source(0, NeedsScript.PURPOSE_SOURCE_MENTORING).ok, "mentoring")
	var out := IntMath.IntResult.new()
	assert_true(_needs.rest_rate_milli_per_hour_into(0, out), "rest reads")
	assert_equal(out.value, 750000, "rest reports the floor rate")
	assert_true(_needs.comfort_rate_milli_per_hour_into(0, out), "comfort reads")
	assert_equal(out.value, 200000, "comfort reports the heated-room rate")
	assert_true(_needs.social_rate_milli_per_hour_into(0, out), "social reads")
	assert_equal(out.value, 1100000, "social reports the paired rate")
	assert_true(_needs.purpose_rate_milli_per_hour_into(0, out), "purpose reads")
	assert_equal(out.value, 325000, "purpose reports the mentoring rate")


func test_a_successful_zero_is_distinguishable_from_a_refusal_carrying_zero() -> void:
	"""Finding H4 in one assertion pair: both carry 0, and only `.ok` tells them apart."""
	_spawn()
	assert_true(_needs.set_comfort_environment(0, NeedsScript.COMFORT_ENV_MILD_OUTDOORS).ok, "mild")
	var valid := IntMath.IntResult.new()
	assert_true(_needs.comfort_rate_milli_per_hour_into(0, valid), "a balanced resident succeeds")
	assert_true(valid.ok, "ok is true")
	assert_equal(valid.value, 0, "and the value is a legitimate 0")
	assert_equal(valid.error, "", "with no refusal reason")
	var refused := IntMath.IntResult.new()
	assert_false(_needs.comfort_rate_milli_per_hour_into(99, refused), "an empty slot refuses")
	assert_false(refused.ok, "ok is false")
	assert_equal(refused.value, 0, "the value is also 0")
	assert_true(refused.error != "", "but a refusal reason is present")
