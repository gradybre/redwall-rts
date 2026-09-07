extends "res://test/framework/test_case.gd"
## Coverage for the checked-arithmetic core: division, overflow refusal, remainder carrying,
## and the GDD §7.1 worked economy fixtures reproduced with exact integer arithmetic.

const IntMathScript := preload("res://scripts/core/int_math.gd")


func _assert_ok(result: IntMathScript.IntResult, message: String) -> IntMathScript.IntResult:
	"""Assert a checked result succeeded (surfacing its refusal reason if not) and return it."""
	assert_true(result.ok, "%s (error: %s)" % [message, result.error])
	return result


func _assert_refused(result: IntMathScript.IntResult, message: String) -> void:
	"""Assert a checked result was refused rather than silently producing a value."""
	assert_false(result.ok, message)


# --- floor_div ---------------------------------------------------------------------------------

func test_floor_div_truncates_toward_zero_for_nonnegative_operands() -> void:
	"""Exact and inexact nonnegative divisions both floor correctly."""
	assert_equal(_assert_ok(IntMathScript.floor_div(7, 2), "7/2").value, 3, "floor_div(7,2)")
	assert_equal(_assert_ok(IntMathScript.floor_div(10, 5), "10/5").value, 2, "floor_div(10,5)")


func test_floor_div_rejects_negative_numerator() -> void:
	"""floor_div is defined only for a nonnegative numerator."""
	_assert_refused(IntMathScript.floor_div(-1, 2), "negative numerator must refuse")


func test_floor_div_rejects_non_positive_denominator() -> void:
	"""Zero and negative denominators are both refused explicitly."""
	_assert_refused(IntMathScript.floor_div(4, 0), "zero denominator must refuse")
	_assert_refused(IntMathScript.floor_div(4, -2), "negative denominator must refuse")


# --- ceil_div ------------------------------------------------------------------------------------

func test_ceil_div_rounds_up_inexact_divisions() -> void:
	"""(a+b-1)/b rounds up when the division is not exact, matches when it is."""
	assert_equal(_assert_ok(IntMathScript.ceil_div(7, 2), "ceil 7/2").value, 4, "ceil_div(7,2)")
	assert_equal(_assert_ok(IntMathScript.ceil_div(8, 2), "ceil 8/2").value, 4, "ceil_div(8,2) exact")


func test_ceil_div_rejects_negative_numerator_and_non_positive_denominator() -> void:
	"""ceil_div refuses the same invalid domains as floor_div."""
	_assert_refused(IntMathScript.ceil_div(-1, 2), "negative numerator must refuse")
	_assert_refused(IntMathScript.ceil_div(4, 0), "zero denominator must refuse")
	_assert_refused(IntMathScript.ceil_div(4, -2), "negative denominator must refuse")


func test_ceil_div_refuses_rather_than_overflowing_while_forming_the_numerator() -> void:
	"""a+b-1 must not silently wrap when a is already near INT64_MAX."""
	_assert_refused(IntMathScript.ceil_div(IntMathScript.INT64_MAX, 2), "a+b-1 overflow must refuse")


# --- trunc_div -----------------------------------------------------------------------------------

func test_trunc_div_matches_signed_truncation_toward_zero() -> void:
	"""trunc_div(a,b) = sign(a)*floor_div(abs(a),b): both signs of a truncate toward zero."""
	assert_equal(_assert_ok(IntMathScript.trunc_div(-7, 2), "trunc -7/2").value, -3, "trunc_div(-7,2)")
	assert_equal(_assert_ok(IntMathScript.trunc_div(7, 2), "trunc 7/2").value, 3, "trunc_div(7,2)")
	assert_equal(_assert_ok(IntMathScript.trunc_div(0, 5), "trunc 0/5").value, 0, "trunc_div(0,5)")


func test_trunc_div_rejects_non_positive_denominator() -> void:
	"""Denominators must be positive even for the signed variant."""
	_assert_refused(IntMathScript.trunc_div(7, 0), "zero denominator must refuse")
	_assert_refused(IntMathScript.trunc_div(7, -2), "negative denominator must refuse")


func test_trunc_div_handles_int64_min_without_a_spurious_refusal() -> void:
	"""INT64_MIN/1 is representable; an abs()-based implementation would wrongly overflow here."""
	var result: IntMathScript.IntResult = IntMathScript.trunc_div(IntMathScript.INT64_MIN, 1)
	assert_true(result.ok, "INT64_MIN/1 must not refuse")
	assert_equal(result.value, IntMathScript.INT64_MIN, "INT64_MIN/1 == INT64_MIN")


# --- checked_add / checked_mul --------------------------------------------------------------------

func test_checked_add_basic() -> void:
	"""In-range addition succeeds and returns the exact sum."""
	assert_equal(_assert_ok(IntMathScript.checked_add(2, 3), "2+3").value, 5, "checked_add(2,3)")
	assert_equal(_assert_ok(IntMathScript.checked_add(-2, 3), "-2+3").value, 1, "checked_add(-2,3)")


func test_checked_add_refuses_positive_overflow() -> void:
	"""INT64_MAX+1 must refuse, not wrap to INT64_MIN."""
	_assert_refused(IntMathScript.checked_add(IntMathScript.INT64_MAX, 1), "positive overflow")


func test_checked_add_refuses_negative_overflow() -> void:
	"""INT64_MIN-1 must refuse, not wrap to INT64_MAX."""
	_assert_refused(IntMathScript.checked_add(IntMathScript.INT64_MIN, -1), "negative overflow")
	_assert_refused(IntMathScript.checked_add(IntMathScript.INT64_MIN, IntMathScript.INT64_MIN), "double min overflow")


func test_checked_mul_basic_and_zero_short_circuit() -> void:
	"""Ordinary products compute exactly; multiplying by zero never risks overflow."""
	assert_equal(_assert_ok(IntMathScript.checked_mul(544000, 500), "mul").value, 272000000, "544000*500")
	assert_equal(_assert_ok(IntMathScript.checked_mul(0, IntMathScript.INT64_MAX), "zero mul").value, 0, "0*x=0")


func test_checked_mul_refuses_overflow() -> void:
	"""INT64_MAX*2 must refuse rather than silently wrapping to -2."""
	_assert_refused(IntMathScript.checked_mul(IntMathScript.INT64_MAX, 2), "overflow mul")


func test_checked_mul_refuses_int64_min_times_negative_one() -> void:
	"""The one product-overflow case the divide-back check alone cannot see is special-cased."""
	_assert_refused(IntMathScript.checked_mul(IntMathScript.INT64_MIN, -1), "MIN*-1 overflow")
	_assert_refused(IntMathScript.checked_mul(-1, IntMathScript.INT64_MIN), "-1*MIN overflow")


# --- narrow_to_int32 -------------------------------------------------------------------------------

func test_narrow_to_int32_accepts_boundary_values() -> void:
	"""The int32 range endpoints themselves must narrow successfully."""
	assert_true(IntMathScript.narrow_to_int32(IntMathScript.INT32_MAX).ok, "INT32_MAX fits")
	assert_true(IntMathScript.narrow_to_int32(IntMathScript.INT32_MIN).ok, "INT32_MIN fits")


func test_narrow_to_int32_refuses_just_outside_the_range() -> void:
	"""One past either boundary must refuse rather than truncate silently."""
	_assert_refused(IntMathScript.narrow_to_int32(IntMathScript.INT32_MAX + 1), "over max refuses")
	_assert_refused(IntMathScript.narrow_to_int32(IntMathScript.INT32_MIN - 1), "under min refuses")


# --- inventory_capacity_debit_g --------------------------------------------------------------------

func test_inventory_capacity_debit_matches_ceil_div_formula() -> void:
	"""BAL-NUM-001: ceil_div(quantity_milli*mass_g,1000), reproducing the winter-stock mass."""
	var result: IntMathScript.IntResult = IntMathScript.inventory_capacity_debit_g(8280000, 500)
	assert_true(result.ok, "debit succeeds")
	assert_equal(result.value, 4140000, "8280000 milli-U at 500g/U debits 4,140,000g")


func test_inventory_capacity_debit_rounds_up_so_splitting_creates_no_free_capacity() -> void:
	"""A one-milli lot still debits a whole gram; splitting cannot create free capacity."""
	var result: IntMathScript.IntResult = IntMathScript.inventory_capacity_debit_g(1, 1)
	assert_true(result.ok, "debit succeeds")
	assert_equal(result.value, 1, "ceil_div(1,1000) rounds up to 1, not down to 0")


func test_inventory_capacity_debit_rejects_negative_inputs() -> void:
	"""Neither quantity nor mass may be negative."""
	_assert_refused(IntMathScript.inventory_capacity_debit_g(-1, 500), "negative quantity refuses")
	_assert_refused(IntMathScript.inventory_capacity_debit_g(500, -1), "negative mass refuses")


func test_inventory_capacity_debit_refuses_multiplication_overflow() -> void:
	"""A quantity/mass pair whose product overflows int64 must refuse, not wrap."""
	_assert_refused(IntMathScript.inventory_capacity_debit_g(IntMathScript.INT64_MAX, 2), "mul overflow refuses")


# --- RemainderAccumulator --------------------------------------------------------------------------

func test_remainder_accumulator_is_lossless_across_many_small_steps() -> void:
	"""Ten steps of 1/3 unit must total exactly 10/3: three whole units, one third left over."""
	var accumulator: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var total_whole: int = 0
	for _index: int in 10:
		var result: IntMathScript.IntResult = accumulator.integrate(1, 3)
		assert_true(result.ok, "integrate succeeds")
		total_whole += result.value
	assert_equal(total_whole, 3, "three whole units released across ten 1/3 steps")
	assert_equal(accumulator.remainder(), 1, "one third remains uncommitted, not discarded")


func test_remainder_accumulator_stays_lossless_over_a_long_run() -> void:
	"""1000 steps of 1/7 unit: floor(1000/7)=142 whole units with remainder 6, nothing dropped."""
	var accumulator: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var total_whole: int = 0
	for _index: int in 1000:
		total_whole += _assert_ok(accumulator.integrate(1, 7), "integrate").value
	assert_equal(total_whole, 142, "142 whole units released")
	assert_equal(accumulator.remainder(), 6, "remainder 6 accounts for the rest of 1000")


func test_remainder_accumulator_rejects_negative_step() -> void:
	"""A negative step numerator would make the accumulated value ambiguous; refuse it."""
	var accumulator: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	_assert_refused(accumulator.integrate(-1, 3), "negative step refuses")


func test_remainder_accumulator_rejects_non_positive_denominator() -> void:
	"""The accumulator enforces the same positive-denominator rule as the free functions."""
	var accumulator: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	_assert_refused(accumulator.integrate(1, 0), "zero denominator refuses")
	_assert_refused(accumulator.integrate(1, -3), "negative denominator refuses")


func test_remainder_accumulator_reset_discards_the_remainder() -> void:
	"""reset() is the only sanctioned way to drop a held remainder."""
	var accumulator: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	accumulator.integrate(1, 3)
	accumulator.reset()
	assert_equal(accumulator.remainder(), 0, "reset clears the retained remainder")


# --- GDD §7.1 golden fixtures -----------------------------------------------------------------------

func _demand_np(small: int, medium: int, large: int) -> int:
	"""GDD §7.1 weighted population demand at a 6000 NP/day small-resident baseline."""
	var weighted_milli: int = small * 1000 + medium * 1200 + large * 1600
	var product: int = _assert_ok(IntMathScript.checked_mul(weighted_milli, 6000), "demand product").value
	return _assert_ok(IntMathScript.floor_div(product, 1000), "demand np").value


func _winter_np(base_np: int) -> int:
	"""Winter demand is 1.2x the daily baseline, per GDD §7.1."""
	var product: int = _assert_ok(IntMathScript.checked_mul(base_np, 1200), "winter product").value
	return _assert_ok(IntMathScript.floor_div(product, 1000), "winter np").value


func test_golden_population_demand_200_small() -> void:
	"""GDD §7.1: 200 small residents require 1,200,000 NP/day; winter requires 1,440,000."""
	var base: int = _demand_np(200, 0, 0)
	assert_equal(base, 1200000, "200 small baseline demand")
	assert_equal(_winter_np(base), 1440000, "200 small winter demand")


func test_golden_population_demand_mixed_cohort() -> void:
	"""GDD §7.1: (120+60*1.2+20*1.6)*6000=1,344,000 NP/day; winter 1,612,800."""
	var base: int = _demand_np(120, 60, 20)
	assert_equal(base, 1344000, "mixed cohort baseline demand")
	assert_equal(_winter_np(base), 1612800, "mixed cohort winter demand")


func test_golden_field_fixture_grain_yield_and_seed_replacement() -> void:
	"""GDD §7.1 field fixture: 64 tiles yield 544 U; 4 U covers the 16 U seed reserve via
	separation, leaving 540 U worth 972000 NP (979200 NP before the seed cost)."""
	var fertility_term: int = _assert_ok(IntMathScript.floor_div(7000, 20), "fertility term").value
	var yield_product: int = _assert_ok(IntMathScript.checked_mul(64 * 10000, 500 + fertility_term), "yield product").value
	var grain_milli: int = _assert_ok(IntMathScript.floor_div(yield_product, 1000), "grain milli").value
	assert_equal(grain_milli, 544000, "field yields 544 U of grain")
	var seed_from_grain_milli: int = _assert_ok(IntMathScript.ceil_div(64 * 250, 4), "seed replacement").value
	assert_equal(seed_from_grain_milli, 4000, "4 U of grain covers the 16 U seed reserve")
	var net_grain_milli: int = grain_milli - seed_from_grain_milli
	var np_before: int = _assert_ok(IntMathScript.floor_div(grain_milli * 1800, 1000), "np before seed").value
	var np_after: int = _assert_ok(IntMathScript.floor_div(net_grain_milli * 1800, 1000), "np after seed").value
	assert_equal(np_before, 979200, "979200 NP before the seed cost")
	assert_equal(np_after, 972000, "972000 NP after the seed cost")


func test_golden_field_fixture_work_and_byproducts() -> void:
	"""GDD §7.1 field fixture: 1152 WU of crop work; 272 cooking batches at 12 WU and 0.1 wood
	U each, using 544 water U — 3264 cooking WU and 27.2 wood U in total."""
	var crop_work_mwu: int = (64 * 4 + 64 * 8 + 64 * 6) * 1000
	assert_equal(crop_work_mwu, 1152000, "1152 WU of sowing/tending/harvest work")
	var batches: int = _assert_ok(IntMathScript.floor_div(544000, 2000), "porridge batches").value
	assert_equal(batches, 272, "544 U of grain makes 272 porridge batches")
	var cooking_work_mwu: int = _assert_ok(IntMathScript.checked_mul(batches, 12000), "cooking work").value
	var cooking_wood_milli: int = _assert_ok(IntMathScript.checked_mul(batches, 100), "cooking wood").value
	assert_equal(cooking_work_mwu, 3264000, "3264 WU of cooking work")
	assert_equal(cooking_wood_milli, 27200, "27.2 U of wood consumed")


func test_golden_winter_stock_fixture_rations_and_ingredients() -> void:
	"""GDD §7.1 winter fixture: 200 residents need 17,280,000 NP over 12 days, covered by 8280 U
	of ration at a 15% reserve margin, made in 2760 batches needing 5520 flour/2760 each of
	dried_fish/nuts/water and 66240 WU."""
	var winter_np: int = _winter_np(_demand_np(200, 0, 0)) * 12
	assert_equal(winter_np, 17280000, "17,280,000 NP over 12 winter days")
	var ration_needed_milli: int = _assert_ok(IntMathScript.ceil_div(winter_np * 1000, 2400), "ration need").value
	var ration_milli: int = _assert_ok(IntMathScript.floor_div(ration_needed_milli * 115, 100), "reserve margin").value
	assert_equal(ration_milli, 8280000, "8280 U of ration after the 15% reserve margin")
	var batches: int = _assert_ok(IntMathScript.ceil_div(ration_milli, 3000), "ration batches").value
	assert_equal(batches, 2760, "2760 ration batches")
	assert_equal(batches * 2000, 5520000, "5520 U of flour")
	assert_equal(batches * 1000, 2760000, "2760 U each of dried_fish/nuts/water")
	assert_equal(batches * 24000, 66240000, "66240 WU of preservation work")


func test_golden_winter_stock_fixture_mass_and_cellars() -> void:
	"""GDD §7.1 winter fixture: 8280 U of ration at 500g/U needs 4,140,000g, or 5 cellars."""
	var mass_result: IntMathScript.IntResult = IntMathScript.inventory_capacity_debit_g(8280000, 500)
	assert_true(mass_result.ok, "mass debit succeeds")
	assert_equal(mass_result.value, 4140000, "4,140,000g of ration mass")
	var cellars: int = _assert_ok(IntMathScript.ceil_div(mass_result.value, 1000000), "cellars needed").value
	assert_equal(cellars, 5, "5 cellars of 1,000,000g each")


func test_golden_starter_food_fixture() -> void:
	"""GDD §7.1 starter fixture: 408000 ready NP against a 74400 NP/day cohort demand gives
	5.48 food-days (548 centi-days), rounded down rather than up."""
	var starter_np: int = 60 * 2400 + 60 * 1800 + 80 * 800 + 40 * 700 + 40 * 1600
	assert_equal(starter_np, 408000, "408000 NP of ready starter food")
	var cohort_demand: int = _demand_np(10, 2, 0)
	assert_equal(cohort_demand, 74400, "74400 NP/day for 10 small + 2 medium residents")
	var food_days_centi: int = _assert_ok(IntMathScript.floor_div(starter_np * 100, cohort_demand), "food days").value
	assert_equal(food_days_centi, 548, "5.48 ready food-days, floored per BAL-NUM-001")


# --- Non-allocating *_into forms (task 2.7, decision 0015) ---------------------------------------

func _fresh() -> IntMathScript.IntResult:
	"""A caller-owned scratch result, in the neutral state a fresh IntResult holds."""
	return IntMathScript.IntResult.new()


func test_into_forms_agree_with_the_allocating_forms_on_every_success_case() -> void:
	"""Adding a non-allocating path must not create a second arithmetic with its own answers."""
	var out: IntMathScript.IntResult = _fresh()
	assert_true(IntMathScript.floor_div_into(7, 2, out), "floor_div_into(7,2) succeeds")
	assert_equal(out.value, IntMathScript.floor_div(7, 2).value, "floor_div agrees")
	assert_true(IntMathScript.ceil_div_into(7, 2, out), "ceil_div_into(7,2) succeeds")
	assert_equal(out.value, IntMathScript.ceil_div(7, 2).value, "ceil_div agrees")
	assert_true(IntMathScript.trunc_div_into(-7, 2, out), "trunc_div_into(-7,2) succeeds")
	assert_equal(out.value, IntMathScript.trunc_div(-7, 2).value, "trunc_div agrees")
	assert_true(IntMathScript.checked_add_into(5, 6, out), "checked_add_into succeeds")
	assert_equal(out.value, IntMathScript.checked_add(5, 6).value, "checked_add agrees")
	assert_true(IntMathScript.checked_mul_into(5, 6, out), "checked_mul_into succeeds")
	assert_equal(out.value, IntMathScript.checked_mul(5, 6).value, "checked_mul agrees")
	assert_true(IntMathScript.narrow_to_int32_into(5, out), "narrow_to_int32_into succeeds")
	assert_equal(out.value, IntMathScript.narrow_to_int32(5).value, "narrow_to_int32 agrees")
	assert_true(IntMathScript.inventory_capacity_debit_g_into(8280000, 500, out), "debit succeeds")
	assert_equal(out.value, 4140000, "debit_g_into reproduces the GDD §7.1 winter mass")


func test_into_forms_refuse_exactly_where_the_allocating_forms_refuse() -> void:
	"""Every refusal domain must survive the move onto the non-allocating path."""
	var out: IntMathScript.IntResult = _fresh()
	assert_false(IntMathScript.floor_div_into(-1, 2, out), "negative numerator refuses")
	assert_false(IntMathScript.floor_div_into(4, 0, out), "zero denominator refuses")
	assert_false(IntMathScript.ceil_div_into(-1, 2, out), "ceil negative numerator refuses")
	assert_false(IntMathScript.ceil_div_into(IntMathScript.INT64_MAX, 2, out), "a+b-1 overflow refuses")
	assert_false(IntMathScript.trunc_div_into(7, 0, out), "trunc zero denominator refuses")
	assert_false(IntMathScript.checked_add_into(IntMathScript.INT64_MAX, 1, out), "add overflow refuses")
	assert_false(IntMathScript.checked_mul_into(IntMathScript.INT64_MAX, 2, out), "mul overflow refuses")
	assert_false(IntMathScript.narrow_to_int32_into(IntMathScript.INT32_MAX + 1, out), "int32 refuses")
	assert_false(IntMathScript.inventory_capacity_debit_g_into(-1, 500, out), "negative debit refuses")


func test_a_refused_into_call_leaves_no_usable_looking_value_behind() -> void:
	"""Finding H4's rule: a refusal must never be readable as an in-band number.

	The bool return and `out.ok` must agree, the reason must be non-empty, and the stale value
	from the previous SUCCESSFUL call must be zeroed rather than left to be mistaken for this
	call's answer.
	"""
	var out: IntMathScript.IntResult = _fresh()
	assert_true(IntMathScript.checked_mul_into(1000, 1000, out), "seed the scratch with 1000000")
	assert_equal(out.value, 1000000, "scratch holds the earlier answer")
	assert_false(IntMathScript.ceil_div_into(-1, 1000, out), "an invalid age refuses")
	assert_false(out.ok, "out.ok agrees with the bool return")
	assert_equal(out.value, 0, "the refused call zeroes the stale value")
	assert_true(out.error.length() > 0, "the refusal carries a reason")


func test_a_successful_into_call_clears_a_previous_refusal_reason() -> void:
	"""A reused scratch must not carry an old error into a call that actually succeeded."""
	var out: IntMathScript.IntResult = _fresh()
	assert_false(IntMathScript.checked_add_into(IntMathScript.INT64_MAX, 1, out), "seed a refusal")
	assert_true(IntMathScript.checked_add_into(2, 3, out), "the next call succeeds")
	assert_true(out.ok, "ok is set")
	assert_equal(out.value, 5, "value is the new answer")
	assert_equal(out.error, "", "the stale refusal reason is cleared")


func test_debit_using_its_out_as_its_own_intermediate_scratch_is_exact() -> void:
	"""inventory_capacity_debit_g_into() reuses `out` for the product; that must not corrupt it."""
	var out: IntMathScript.IntResult = _fresh()
	assert_true(IntMathScript.inventory_capacity_debit_g_into(1001, 1000, out), "1001 milli at 1kg")
	assert_equal(out.value, 1001, "ceil_div(1001*1000,1000) is exact and needs no rounding up")
	assert_true(IntMathScript.inventory_capacity_debit_g_into(1, 1, out), "1 milli of a 1g item")
	assert_equal(out.value, 1, "ceil_div(1,1000) rounds a sub-gram lot up to 1g")


func test_fits_int32_matches_narrow_to_int32_on_the_boundaries() -> void:
	"""The allocation-free range check must not disagree with the narrowing it stands in for."""
	for value: int in [0, IntMathScript.INT32_MAX, IntMathScript.INT32_MIN]:
		assert_true(IntMathScript.fits_int32(value), "%d fits int32" % value)
		assert_true(IntMathScript.narrow_to_int32(value).ok, "%d narrows" % value)
	for value: int in [IntMathScript.INT32_MAX + 1, IntMathScript.INT32_MIN - 1]:
		assert_false(IntMathScript.fits_int32(value), "%d does not fit int32" % value)
		assert_false(IntMathScript.narrow_to_int32(value).ok, "%d refuses to narrow" % value)


func test_integrate_into_carries_the_remainder_losslessly_without_allocating() -> void:
	"""BAL-NUM-001 lossless carrying must hold on the non-allocating path too."""
	var acc: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var out: IntMathScript.IntResult = IntMathScript.IntResult.new()
	var released: int = 0
	for i: int in range(300):
		assert_true(acc.integrate_into(1, 7, out), "step %d integrates" % i)
		released += out.value
	assert_equal(released * 7 + acc.remainder(), 300, "every numerator is accounted for")
	assert_equal(released, 42, "300/7 = 42 whole units released")


func test_integrate_into_refuses_without_disturbing_the_retained_remainder() -> void:
	"""A refused step must not consume, release or corrupt the carried fraction."""
	var acc: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var out: IntMathScript.IntResult = IntMathScript.IntResult.new()
	assert_true(acc.integrate_into(3, 7, out), "seed a remainder of 3")
	assert_equal(acc.remainder(), 3, "3/7 retained")
	assert_false(acc.integrate_into(-1, 7, out), "a negative step refuses")
	assert_equal(out.value, 0, "the refusal carries no releasable quantity")
	assert_false(acc.integrate_into(1, 0, out), "a zero denominator refuses")
	assert_equal(acc.remainder(), 3, "the retained remainder is untouched by both refusals")


func test_two_accumulators_do_not_share_a_scratch() -> void:
	"""Interleaved accumulators must keep independent remainders (no per-class scratch)."""
	var a: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var b: IntMathScript.RemainderAccumulator = IntMathScript.RemainderAccumulator.new()
	var out_a: IntMathScript.IntResult = IntMathScript.IntResult.new()
	var out_b: IntMathScript.IntResult = IntMathScript.IntResult.new()
	for i: int in range(5):
		a.integrate_into(1, 3, out_a)
		b.integrate_into(1, 10, out_b)
	assert_equal(a.remainder(), 2, "a carries 5 mod 3")
	assert_equal(b.remainder(), 5, "b carries 5 mod 10")
	assert_equal(a.integrate(1, 3).value, 1, "a releases its whole unit on the next step")
	assert_equal(b.integrate(1, 10).value, 0, "b is still short of a whole unit")
