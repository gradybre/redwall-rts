extends "res://test/framework/test_case.gd"
## PC-04 hunger wiring (decision 0521): the all-adult world is byte-identical to the base.
##
## THE BEFORE/AFTER PROOF. The two SHA-256 digests below were produced by running exactly these
## seeded runs on the UNMODIFIED base commit 3676652 (`fix/settlement-loose-ends`), before
## `needs.gd` or `residents.gd` learned the life-stage multiplier. The base had no staged sweep, so
## its standalone run called `needs.tick_all()`; this file now calls the production path
## `residents.tick_needs_all()`, which feeds Residents' own stage column into the sweep. Every
## resident in both runs is ADULT, so the stage multiplier is the authored 1000 and nothing may
## move: the digests cover every persisted Needs column, every daily-demand total and every
## published hunger rate, sampled through the run.
##
## A digest is pinned rather than recomputed because recomputing it from the code under test
## would prove only that the code agrees with itself.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const FIXTURE_WORLD_SEED: int = 20260910
const SEASON_WINTER: int = 3
const SEASON_SPRING: int = 0
const SAMPLE_EVERY: int = 250

## Base-commit digests (3676652). See the header.
const SETTLEMENT_DIGEST: String = "e9e1b8cb20bf5cfc9b3c37dc34dc7d57c49dadde619159682d528a98b8a33ffd"
const STANDALONE_DIGEST: String = "58ed43f84a22f88e881447d1634d61bd534e2128925a14128420ad2a271c5ec1"

## The standalone run's species, cycling small/medium/large so all three size rows are exercised.
const RUN_SPECIES: Array[StringName] = [&"mouse", &"otter", &"badger", &"mole", &"hare",
	&"fox", &"shrew", &"hedgehog", &"wolverine", &"squirrel", &"kestrel", &"wildcat"]

var _settlement: SettlementSystemScript = null
var _lcg: int = 0


func after_each() -> void:
	"""Free the settlement node and hand the shared pause queue back the way it was found."""
	if _settlement != null:
		_settlement.free()
		_settlement = null
	GameManager.scheduler_events().clear()
	GameManager.clock().set_pause(SimClockScript.CRITICAL, false)


func _absorb_needs(ctx: HashingContext, needs: NeedsScript, columns: NeedsScript.Columns) -> void:
	"""Feed every persisted Needs column and each published hunger rate into the digest."""
	assert(needs.copy_columns_into(columns))
	for column: PackedByteArray in [columns.present, columns.status, columns.size_class,
			columns.activity, columns.comfort_environment, columns.social_paired,
			columns.purpose_source, columns.cold_environment, columns.clothing_tier,
			columns.infirmary, columns.injury_state, columns.airless]:
		ctx.update(column)
	ctx.update(columns.need_value.to_byte_array())
	ctx.update(columns.need_remainder.to_byte_array())
	ctx.update(columns.health.to_byte_array())
	ctx.update(columns.health_remainder.to_byte_array())
	ctx.update(columns.cold_milli_hours.to_byte_array())
	ctx.update(columns.cold_remainder.to_byte_array())
	ctx.update(columns.starving_ticks.to_byte_array())
	ctx.update(columns.departure_days.to_byte_array())
	var rates: PackedInt64Array = PackedInt64Array()
	for size: int in NeedsScript.SIZE_COUNT:
		rates.append(needs.hunger_rate_milli_per_hour(size).value)
	ctx.update(rates.to_byte_array())


func _absorb_demand(ctx: HashingContext, residents: ResidentsScript) -> void:
	"""Feed the §5.8 food-days denominator and the §7.1 cohort forecast into the digest."""
	var demand: IntMath.IntResult = residents.daily_demand_np()
	var cohort: IntMath.IntResult = residents.daily_demand_for_cohort(3, 2, 1)
	ctx.update(PackedInt64Array([1 if demand.ok else 0, demand.value,
		1 if cohort.ok else 0, cohort.value]).to_byte_array())


func _next(bound: int) -> int:
	"""Deterministic 31-bit LCG draw in [0, bound). Integer only; no engine RNG is consulted."""
	_lcg = (_lcg * 1103515245 + 12345) & 0x7fffffff
	return _lcg % bound


func _perturb(needs: NeedsScript, slot: int) -> void:
	"""Change at most one input of one resident, chosen by the LCG."""
	match _next(9):
		0:
			needs.set_activity(slot, _next(NeedsScript.ACTIVITY_COUNT))
		1:
			needs.set_comfort_environment(slot, _next(NeedsScript.COMFORT_ENV_COUNT))
		2:
			needs.set_social_paired(slot, _next(2) == 1)
		3:
			needs.set_purpose_source(slot, _next(NeedsScript.PURPOSE_SOURCE_COUNT))
		4:
			needs.set_cold_environment(slot, _next(NeedsScript.COLD_ENV_COUNT))
		5:
			needs.set_clothing_tier(slot, 1 + _next(2))
		6:
			needs.add_food_nutrition(slot, _next(3000))
		_:
			pass


func _standalone_tick(residents: ResidentsScript) -> bool:
	"""One production needs sweep over the Residents-owned stage column."""
	return residents.tick_needs_all().ok


func test_an_all_adult_settlement_run_matches_the_base_digest() -> void:
	"""The real settlement pipeline, seeded, across a winter handover and back."""
	_settlement = SettlementSystemScript.new()
	assert_true(_settlement.create_initial_settlement(), "the cohort was created")
	_settlement.rng().seed_world(FIXTURE_WORLD_SEED)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var columns: NeedsScript.Columns = NeedsScript.Columns.new()
	var committed: int = 0
	for tick: int in range(1, 4501):
		if tick == 1500:
			assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "winter applies")
		if tick == 3000:
			assert_true(_settlement.run_day_boundary(49, SEASON_SPRING), "spring applies")
		if _settlement.run_tick(tick):
			committed += 1
		if tick % SAMPLE_EVERY == 0:
			_absorb_needs(ctx, _settlement.needs(), columns)
			_absorb_demand(ctx, _settlement.residents())
	assert_equal(committed, 4500, "every tick committed")
	var digest: String = ctx.finish().hex_encode()
	print("PC04 SETTLEMENT_DIGEST ", digest)
	assert_equal(digest, SETTLEMENT_DIGEST,
		"the all-adult settlement is byte-identical to the base")


func test_an_all_adult_seeded_standalone_run_matches_the_base_digest() -> void:
	"""Twelve adults of all three sizes under LCG-driven inputs, winter toggled every 600 ticks."""
	var residents: ResidentsScript = ResidentsScript.new()
	var needs: NeedsScript = residents.needs()
	for key: StringName in RUN_SPECIES:
		assert_true(residents.spawn(key).ok, "spawn %s" % key)
	_lcg = 20261001
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var columns: NeedsScript.Columns = NeedsScript.Columns.new()
	var swept: int = 0
	for tick: int in range(1, 9001):
		if tick % 600 == 0:
			residents.set_winter(not residents.is_winter())
		_perturb(needs, _next(RUN_SPECIES.size()))
		if _standalone_tick(residents):
			swept += 1
		if tick % SAMPLE_EVERY == 0:
			_absorb_needs(ctx, needs, columns)
			_absorb_demand(ctx, residents)
	assert_equal(swept, 9000, "every sweep integrated")
	var digest: String = ctx.finish().hex_encode()
	print("PC04 STANDALONE_DIGEST ", digest)
	assert_equal(digest, STANDALONE_DIGEST, "the all-adult standalone run is byte-identical")


# --- the life-stage multiplier itself ---------------------------------------------------------

## FAMILY-RULES-R01's hunger table, restated as independent literals (milli-points/hour), index
## stage * 6 + size * 2 + winter.
const HUNGER_LITERALS: Array[int] = [250000, 300000, 300000, 360000, 400000, 480000,
	187500, 225000, 225000, 270000, 300000, 360000,
	250000, 300000, 300000, 360000, 400000, 480000]
## The §5.2 need denominator, restated: 750 ticks/hour x 1000 milli-points.
const NEED_DENOMINATOR: int = 750000
const INITIAL_NEED: int = 7500


func _hunger(needs: NeedsScript, slot: int) -> int:
	"""Current hunger of a row, failing the test loudly if it is refused."""
	var read: IntMath.IntResult = needs.need_of(slot, NeedsScript.NEED_HUNGER)
	assert_true(read.ok, "hunger of row %d is readable" % slot)
	return read.value


func _hunger_remainder(needs: NeedsScript, slot: int) -> int:
	"""Current retained hunger remainder of a row."""
	return needs.need_remainder_of(slot, NeedsScript.NEED_HUNGER).value


func test_the_needs_stage_ids_are_the_residents_stage_ids() -> void:
	"""Needs cannot preload Residents, so the shared protected IDs are pinned here instead."""
	assert_equal(NeedsScript.LIFE_STAGE_ADULT, ResidentsScript.LIFE_STAGE_ADULT, "adult")
	assert_equal(NeedsScript.LIFE_STAGE_CHILD, ResidentsScript.LIFE_STAGE_CHILD, "child")
	assert_equal(NeedsScript.LIFE_STAGE_ELDER, ResidentsScript.LIFE_STAGE_ELDER, "elder")
	assert_equal(NeedsScript.LIFE_STAGE_COUNT, ResidentsScript.LIFE_STAGE_COUNT, "bound")


func test_every_stage_size_and_season_hunger_rate_is_the_literal() -> void:
	"""All eighteen published rates, read back through Needs in both seasons."""
	var needs: NeedsScript = NeedsScript.new()
	for winter: int in 2:
		assert_true(needs.set_winter(winter == 1).ok, "season applies")
		for stage: int in 3:
			for size: int in 3:
				var read: IntMath.IntResult = needs.hunger_rate_milli_per_hour_for_stage(stage,
					size)
				assert_true(read.ok, "stage %d size %d reads" % [stage, size])
				assert_equal(read.value, HUNGER_LITERALS[stage * 6 + size * 2 + winter],
					"stage %d size %d winter %d" % [stage, size, winter])
		for size: int in 3:
			assert_equal(needs.hunger_rate_milli_per_hour(size).value,
				HUNGER_LITERALS[size * 2 + winter], "the legacy reader is the ADULT row")


func test_a_bad_stage_or_size_is_refused_stage_first() -> void:
	"""FAMILY-RULES-R01's precedence: an invalid stage is named before an invalid size."""
	var needs: NeedsScript = NeedsScript.new()
	for pair: Array in [[-1, 0], [3, 0], [3, 9], [0, -1], [0, 3]]:
		var read: IntMath.IntResult = needs.hunger_rate_milli_per_hour_for_stage(pair[0], pair[1])
		assert_false(read.ok, "%s refuses" % [pair])
		assert_equal(read.value, 0, "and carries no plausible rate")
		var expected: String = "FAMILY_STAGE_INVALID" if pair[0] < 0 or pair[0] > 2 \
			else "INVALID_SIZE_CLASS"
		assert_equal(read.error, expected, "%s names its cause" % [pair])


func _three_stages(residents: ResidentsScript, key: StringName) -> PackedInt32Array:
	"""Spawn one ADULT, one CHILD and one ELDER of the same species; return their rows."""
	var rows: PackedInt32Array = PackedInt32Array()
	for stage: int in [ResidentsScript.LIFE_STAGE_ADULT, ResidentsScript.LIFE_STAGE_CHILD,
			ResidentsScript.LIFE_STAGE_ELDER]:
		var made: ResidentsScript.OpResult = residents.spawn_with_stage(key, stage)
		assert_true(made.ok, "spawn stage %d" % stage)
		rows.append(made.value)
	return rows


func test_a_child_releases_three_quarters_of_the_adult_hunger_exactly() -> void:
	"""1001 staged ticks release trunc(T*R/750000) hunger and keep the exact signed remainder."""
	var residents: ResidentsScript = ResidentsScript.new()
	var rows: PackedInt32Array = _three_stages(residents, &"mouse")
	for tick: int in 1001:
		assert_true(residents.tick_needs_all().ok, "tick %d" % tick)
	var needs: NeedsScript = residents.needs()
	var rates: Array[int] = [250000, 187500, 250000]
	for index: int in 3:
		var released: int = 1001 * rates[index]
		var whole: int = released / NEED_DENOMINATOR
		assert_equal(_hunger(needs, rows[index]), INITIAL_NEED - whole,
			"stage %d hunger" % index)
		assert_equal(_hunger_remainder(needs, rows[index]), -(released - whole * NEED_DENOMINATOR),
			"stage %d remainder" % index)
	assert_equal(_hunger(needs, rows[1]), 7250, "the child lost 250 points, not 333")
	assert_equal(_hunger(needs, rows[0]), _hunger(needs, rows[2]), "elder equals adult")


func test_winter_raises_a_childs_rate_by_the_same_multiplier() -> void:
	"""A large child in winter is 360000 milli/hour: 3000 ticks release exactly 1440 points."""
	var residents: ResidentsScript = ResidentsScript.new()
	var rows: PackedInt32Array = _three_stages(residents, &"badger")
	assert_true(residents.set_winter(true).ok, "winter")
	for tick: int in 3000:
		residents.tick_needs_all()
	assert_equal(_hunger(residents.needs(), rows[1]), INITIAL_NEED - 1440, "child large winter")
	assert_equal(_hunger(residents.needs(), rows[0]), INITIAL_NEED - 1920, "adult large winter")


func test_a_composed_store_refuses_the_stage_blind_sweep_and_changes_nothing() -> void:
	"""No child can be integrated at the adult rate by calling the old entry point."""
	var residents: ResidentsScript = ResidentsScript.new()
	_three_stages(residents, &"mouse")
	var needs: NeedsScript = residents.needs()
	assert_true(needs.life_stages_required(), "Residents composed the store")
	var before: PackedByteArray = needs.state_bytes()
	var swept: NeedsScript.OpResult = needs.tick_all()
	assert_false(swept.ok, "tick_all refuses")
	assert_equal(swept.error, NeedsScript.REFUSE_LIFE_STAGES_REQUIRED, "and says why")
	var one: NeedsScript.OpResult = needs.tick(0)
	assert_equal(one.error, NeedsScript.REFUSE_LIFE_STAGES_REQUIRED, "tick refuses too")
	assert_equal(needs.state_bytes(), before, "nothing was integrated")


func test_a_bad_stage_column_refuses_the_whole_sweep_before_any_row_moves() -> void:
	"""Shape and per-row stage domain are both checked before the first write."""
	var needs: NeedsScript = NeedsScript.new()
	for slot: int in 3:
		assert_true(needs.spawn(slot, NeedsScript.SIZE_SMALL).ok, "row %d" % slot)
	var before: PackedByteArray = needs.state_bytes()
	var short: PackedByteArray = PackedByteArray()
	short.resize(511)
	assert_equal(needs.tick_all_staged(short).error, NeedsScript.REFUSE_LIFE_STAGE_SHAPE, "shape")
	var stages: PackedByteArray = PackedByteArray()
	stages.resize(NeedsScript.RESIDENT_CAPACITY)
	stages[2] = 3
	var swept: NeedsScript.OpResult = needs.tick_all_staged(stages)
	assert_equal(swept.error, NeedsScript.REFUSE_STAGE_INVALID, "stage 3 is not a stage")
	assert_equal(needs.last_refused_slot(), 2, "the offending row is named")
	assert_equal(needs.state_bytes(), before, "rows 0 and 1 did not integrate either")
	stages[2] = 0
	stages[400] = 7
	assert_equal(needs.tick_all_staged(stages).value, 3, "a free row's byte is not consulted")
	assert_equal(needs.tick_staged(0, 3).error, NeedsScript.REFUSE_STAGE_INVALID, "one row")


func test_a_standalone_store_keeps_its_stage_blind_adult_fixture_path() -> void:
	"""Without a Residents owner there is no stage column; tick_all integrates the ADULT row."""
	var needs: NeedsScript = NeedsScript.new()
	assert_true(needs.spawn(0, NeedsScript.SIZE_SMALL).ok, "row 0")
	assert_true(needs.spawn(1, NeedsScript.SIZE_SMALL).ok, "row 1")
	assert_false(needs.life_stages_required(), "no owner composed it")
	for tick: int in 750:
		assert_true(needs.tick(0).ok, "adult fixture tick")
		assert_true(needs.tick_staged(1, NeedsScript.LIFE_STAGE_CHILD).ok, "explicit child tick")
	assert_equal(_hunger(needs, 0), INITIAL_NEED - 250, "adult hour")
	assert_equal(_hunger(needs, 1), INITIAL_NEED - 187, "child hour truncates 187.5")
	assert_equal(_hunger_remainder(needs, 1), -375000, "and keeps the half point")


func test_daily_demand_sums_each_residents_own_stage_row() -> void:
	"""Child 4500 + adult medium 7200 + elder large 9600; winter 5400 + 8640 + 11520."""
	var residents: ResidentsScript = ResidentsScript.new()
	var child: int = residents.spawn_with_stage(&"mouse", ResidentsScript.LIFE_STAGE_CHILD).value
	residents.spawn(&"otter")
	residents.spawn_with_stage(&"badger", ResidentsScript.LIFE_STAGE_ELDER)
	assert_equal(residents.resident_daily_demand_np(child).value, 4500, "one child")
	assert_equal(residents.daily_demand_np().value, 21300, "the settlement")
	assert_equal(residents.daily_demand_for_cohort(3, 2, 1).value, 42000, "adult cohort unchanged")
	residents.set_winter(true)
	assert_equal(residents.resident_daily_demand_np(child).value, 5400, "one child in winter")
	assert_equal(residents.daily_demand_np().value, 25560, "the settlement in winter")


func test_the_non_allocating_stage_reader_answers_minus_one_for_an_empty_row() -> void:
	"""`life_stage_code_of()` never reports a free row's leftover byte as a stage."""
	var residents: ResidentsScript = ResidentsScript.new()
	var child: int = residents.spawn_with_stage(&"mouse", ResidentsScript.LIFE_STAGE_CHILD).value
	assert_equal(residents.life_stage_code_of(child), ResidentsScript.LIFE_STAGE_CHILD, "a child")
	assert_equal(residents.life_stage_code_of(child + 1), -1, "a free row")
	assert_equal(residents.life_stage_code_of(-1), -1, "out of range")


func test_the_refuge_start_stays_twelve_adults() -> void:
	"""DEC-044 activates no child: the §5.1 cohort is twelve ADULT rows."""
	_settlement = SettlementSystemScript.new()
	assert_true(_settlement.create_initial_settlement(), "the cohort was created")
	var residents: ResidentsScript = _settlement.residents()
	assert_equal(residents.population(), 12, "twelve residents")
	for slot: int in 12:
		assert_equal(residents.life_stage_of(slot).value, ResidentsScript.LIFE_STAGE_ADULT,
			"row %d is adult" % slot)
