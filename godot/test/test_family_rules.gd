extends "res://test/framework/test_case.gd"
## FAMILY-RULES-R01: independent literal expectations for the unbound fixed-stage catalog helper.
const Rules := preload("res://scripts/core/family_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Residents := preload("res://scripts/core/residents.gd")


func test_input_ids_match_the_existing_owners() -> void:
	"""Test-side imports pin identity without creating a helper-to-consumer preload cycle."""
	assert_equal(Residents.LIFE_STAGE_ADULT, 0, "adult")
	assert_equal(Residents.LIFE_STAGE_CHILD, 1, "child")
	assert_equal(Residents.LIFE_STAGE_ELDER, 2, "elder")
	assert_equal(Needs.SIZE_SMALL, 0, "small")
	assert_equal(Needs.SIZE_MEDIUM, 1, "medium")
	assert_equal(Needs.SIZE_LARGE, 2, "large")


func test_all_stage_size_season_results_match_independent_literals() -> void:
	"""Pin every output from the reviewed table, without reusing the helper's constants or formula."""
	var rules: Rules = Rules.new()
	assert_true(rules.is_ready(), "complete checked table")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var hunger: Array[int] = [250000, 300000, 300000, 360000, 400000, 480000,
		187500, 225000, 225000, 270000, 300000, 360000,
		250000, 300000, 300000, 360000, 400000, 480000]
	var demand: Array[int] = [6000, 7200, 7200, 8640, 9600, 11520,
		4500, 5400, 5400, 6480, 7200, 8640,
		6000, 7200, 7200, 8640, 9600, 11520]
	for stage: int in 3:
		for size: int in 3:
			for season: int in 2:
				var index: int = stage * 6 + size * 2 + season
				assert_true(rules.hunger_rate_milli_into(stage, size, season == 1, out), "hunger accepts each row")
				assert_equal(out.value, hunger[index], "literal hunger row %d" % index)
				assert_equal(out.error, "", "successful hunger clears error")
				assert_true(rules.daily_demand_np_into(stage, size, season == 1, out), "demand accepts each row")
				assert_equal(out.value, demand[index], "literal demand row %d" % index)
				assert_equal(out.error, "", "successful demand clears error")


func test_invalid_domains_clear_reused_outcomes_in_declared_precedence() -> void:
	"""Large signed inputs refuse before index arithmetic; a prior successful value never leaks."""
	var rules: Rules = Rules.new()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for method: StringName in [&"hunger_rate_milli_into", &"daily_demand_np_into"]:
		for pair: Array in [[-1, 0], [3, 0], [9223372036854775807, 0],
				[-9223372036854775807 - 1, 0], [-1, -1], [0, -1], [0, 3],
				[0, 9223372036854775807], [0, -9223372036854775807 - 1]]:
			assert_true(rules.call(method, 2, 2, true, out), "prior success")
			assert_false(rules.call(method, pair[0], pair[1], true, out), "invalid request refuses")
			assert_false(out.ok, "explicit refusal")
			assert_equal(out.value, 0, "stale value cleared")
			var expected: String = "FAMILY_STAGE_INVALID" if pair[0] < 0 or pair[0] >= 3 else "FAMILY_SIZE_INVALID"
			assert_equal(out.error, expected, "stage precedes size")
		assert_true(rules.call(method, 1, 0, false, out), "valid after every refusal")
		assert_equal(out.value, 187500 if method == &"hunger_rate_milli_into" else 4500, "table unchanged")
		assert_equal(out.error, "", "success clears refusal")


func test_adult_and_elder_hunger_match_the_actual_current_needs_owner() -> void:
	"""Compare the inherited adult coefficient to the real owner, not another formula copy."""
	var rules: Rules = Rules.new()
	var needs: Needs = Needs.new()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for winter: bool in [false, true]:
		assert_true(needs.set_winter(winter).ok, "set existing season")
		for size: int in 3:
			var existing: IntMath.IntResult = needs.hunger_rate_milli_per_hour(size)
			assert_true(existing.ok, "existing owner value")
			for stage: int in [0, 2]:
				assert_true(rules.hunger_rate_milli_into(stage, size, winter, out), "adult or elder rule")
				assert_equal(out.value, existing.value, "inherited magnitude unchanged")
		assert_equal(needs.is_winter(), winter, "helper did not modify the real owner")


func test_flat_packed_payload_is_288_bytes_and_queries_leave_it_identical() -> void:
	"""White-box payload census only; production callers receive scalar outcomes, never these arrays."""
	var rules: Rules = Rules.new()
	var hunger: PackedInt64Array = rules.get("_hunger_rates_milli")
	var demand: PackedInt64Array = rules.get("_daily_demand_np")
	assert_equal(hunger.size(), 18, "18 hunger rows")
	assert_equal(demand.size(), 18, "18 demand rows")
	assert_equal(hunger.to_byte_array().size() + demand.to_byte_array().size(), 288, "packed payload excludes object overhead")
	var hunger_before: PackedByteArray = hunger.to_byte_array()
	var demand_before: PackedByteArray = demand.to_byte_array()
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for repeat: int in 100:
		assert_true(rules.hunger_rate_milli_into(repeat % 3, (repeat / 3) % 3, repeat % 2 == 1, out), "repeated hunger")
		assert_true(rules.daily_demand_np_into(repeat % 3, (repeat / 3) % 3, repeat % 2 == 1, out), "repeated demand")
	assert_false(rules.hunger_rate_milli_into(-1, 0, false, out), "refusal also read-only")
	var hunger_after: PackedInt64Array = rules.get("_hunger_rates_milli")
	var demand_after: PackedInt64Array = rules.get("_daily_demand_np")
	assert_equal(hunger_after.to_byte_array(), hunger_before, "hunger payload unchanged")
	assert_equal(demand_after.to_byte_array(), demand_before, "demand payload unchanged")
