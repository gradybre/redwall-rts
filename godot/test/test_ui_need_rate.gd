extends "res://test/framework/test_case.gd"
## NEED-RATE-R01's display arithmetic: rounding, sign, the `-0.00` trap and Capped.
##
## Every fixture the ruling pins is checked here as a literal string, not as a comparison
## against a second call of the same function. The four that matter most:
##
##   * `R=250000 -> +2.50` and `245000 -> +2.45` are the units, exactly;
##   * `±250500 -> ±2.51` is ties-away-from-zero, on the tie itself;
##   * `±499 -> 0.00` is the `-0.00` trap. A magnitude that rounds to zero must lose its sign;
##   * `±500 -> ±0.01` is the first magnitude that does not.
##
## Capped has its own group, because the defect it guards against is arithmetically invisible:
## reporting 0 for a need at a bound reads as "nothing is happening" when the model condition
## has not changed at all, and a capped Hunger row would then imply starvation damage stopped.

const UiNeedRate := preload("res://scripts/ui/ui_need_rate.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")

## An interior need value, so a fixture is never accidentally capped.
const INTERIOR: int = 5000


# --- the ruling's pinned formatter fixtures ------------------------------------------------

func test_the_four_pinned_fixtures_print_exactly() -> void:
	"""`250000 -> +2.50`, `245000 -> +2.45`, `±250500 -> ±2.51`, and their negatives."""
	assert_equal(UiNeedRate.text(250000), "+2.50 pp/h", "250000 milli/hour is +2.50")
	assert_equal(UiNeedRate.text(245000), "+2.45 pp/h", "245000 is purpose's useful labor")
	assert_equal(UiNeedRate.text(250500), "+2.51 pp/h", "a tie rounds away from zero")
	assert_equal(UiNeedRate.text(-250500), "-2.51 pp/h", "and does so on the negative side too")
	assert_equal(UiNeedRate.text(-250000), "-2.50 pp/h", "hunger's small nonwinter decay")


func test_a_rounded_zero_never_carries_a_minus_sign() -> void:
	"""`±499 -> 0.00`. A `-0.00` claims a fall the display has decided is not a fall."""
	assert_equal(UiNeedRate.text(499), "0.00 pp/h", "+499 rounds to an unsigned zero")
	assert_equal(UiNeedRate.text(-499), "0.00 pp/h", "and -499 must NOT print -0.00")
	assert_false(UiNeedRate.text(-499).begins_with("-"), "there is no minus on a rounded zero")
	assert_false(UiNeedRate.text(-1).contains("-"), "nor on the smallest negative rate")
	assert_equal(UiNeedRate.signed_hundredths(-499), 0, "the hundredths are exactly zero")


func test_the_first_magnitude_that_keeps_its_sign() -> void:
	"""`±500 -> ±0.01`: the boundary between a rounded zero and a signed hundredth."""
	assert_equal(UiNeedRate.text(500), "+0.01 pp/h", "+500 is the first +0.01")
	assert_equal(UiNeedRate.text(-500), "-0.01 pp/h", "and -500 the first -0.01")
	assert_equal(UiNeedRate.signed_hundredths(500), 1, "one hundredth, positive")
	assert_equal(UiNeedRate.signed_hundredths(-500), -1, "one hundredth, negative")


func test_a_true_zero_rate_is_a_legitimate_answer() -> void:
	"""Mild-outdoor comfort is exactly 0, and that is a success rather than a missing rate."""
	assert_equal(UiNeedRate.text(0), "0.00 pp/h", "a balanced condition prints 0.00")
	assert_equal(UiNeedRate.sign_word(0), UiNeedRate.SIGN_WORD_STEADY, "and reads as steady")


# --- the inherited rate table, end to end ---------------------------------------------------

func test_every_inherited_rate_fixture_prints_its_published_display() -> void:
	"""The ruling's whole table of R values and their pp/h displays, one assertion each."""
	var expected: Dictionary = {
		-250000: "-2.50 pp/h", -300000: "-3.00 pp/h", -400000: "-4.00 pp/h",
		-360000: "-3.60 pp/h", -480000: "-4.80 pp/h", -375000: "-3.75 pp/h",
		1200000: "+12.00 pp/h", 750000: "+7.50 pp/h", -100000: "-1.00 pp/h",
		200000: "+2.00 pp/h", 0: "0.00 pp/h", 1100000: "+11.00 pp/h",
		-75000: "-0.75 pp/h", 245000: "+2.45 pp/h", 325000: "+3.25 pp/h",
	}
	for rate: int in expected:
		assert_equal(UiNeedRate.text(rate), expected[rate] as String,
			"R=%d displays as %s" % [rate, expected[rate]])


func test_the_unit_is_stated_compactly_and_in_full_words() -> void:
	"""`pp/h` on the row, "percentage points per simulated hour" for the reader."""
	assert_equal(UiNeedRate.UNIT_SHORT, "pp/h", "the compact unit")
	assert_equal(UiNeedRate.UNIT_WORDS, "percentage points per simulated hour",
		"and the accessible words, including SIMULATED")
	assert_true(UiNeedRate.accessible_text(INTERIOR, -375000).contains(UiNeedRate.UNIT_WORDS),
		"which the accessible text carries")


func test_the_trend_word_comes_from_the_raw_sign() -> void:
	"""The explanation reads the sign, never the formatted string it produced."""
	assert_equal(UiNeedRate.sign_word(1200000), UiNeedRate.SIGN_WORD_RISING, "sleeping in a bed")
	assert_equal(UiNeedRate.sign_word(-375000), UiNeedRate.SIGN_WORD_FALLING, "awake")
	assert_equal(UiNeedRate.sign_word(-400), UiNeedRate.SIGN_WORD_STEADY,
		"and a rate that rounds to zero is steady rather than falling imperceptibly")


# --- Capped ---------------------------------------------------------------------------------

func test_a_bound_with_an_outward_rate_is_capped_and_keeps_its_rate() -> void:
	"""The ruling: KEEP R and mark Capped. Reporting 0 is the defect this guards against."""
	assert_true(UiNeedRate.is_capped(NeedsScript.NEED_MIN, -250000),
		"0 with a falling rate is capped")
	assert_true(UiNeedRate.is_capped(NeedsScript.NEED_MAX, 1200000),
		"and 10000 with a rising one")
	var row: String = UiNeedRate.row_text(NeedsScript.NEED_MIN, -250000)
	assert_true(row.contains("-2.50 pp/h"), "the capped row still shows R: '%s'" % row)
	assert_false(row.contains("0.00"), "and never replaces it with a zero")
	assert_true(row.contains(UiNeedRate.CAPPED_LABEL), "and it is marked Capped")


func test_an_inward_rate_at_a_bound_is_not_capped() -> void:
	""""Inward rates remain uncapped": recovery from 0 and decline from 10000 are not discarded."""
	assert_false(UiNeedRate.is_capped(NeedsScript.NEED_MIN, 1200000),
		"a resident at 0 who is recovering is not capped")
	assert_false(UiNeedRate.is_capped(NeedsScript.NEED_MAX, -250000),
		"nor one at 10000 who is declining")
	assert_equal(UiNeedRate.row_text(NeedsScript.NEED_MAX, -250000), "-2.50 pp/h",
		"so no Capped mark is added")


func test_a_zero_rate_at_a_bound_is_not_capped() -> void:
	"""Nothing is being discarded at either bound when R is exactly zero."""
	assert_false(UiNeedRate.is_capped(NeedsScript.NEED_MIN, 0), "0 at the floor is not capped")
	assert_false(UiNeedRate.is_capped(NeedsScript.NEED_MAX, 0), "nor at the ceiling")


func test_an_interior_value_is_never_capped_in_either_direction() -> void:
	"""Only the bounds cap. A resident at 50% is not capped whatever the rate does."""
	assert_false(UiNeedRate.is_capped(INTERIOR, -480000), "a steep fall mid-scale is not capped")
	assert_false(UiNeedRate.is_capped(INTERIOR, 1200000), "nor a steep rise")


func test_the_cap_explanation_stays_reachable_in_the_accessible_text() -> void:
	"""§5 requires the unit and cap explanation to remain accessible, not only visible."""
	var spoken: String = UiNeedRate.accessible_text(NeedsScript.NEED_MIN, -250000)
	assert_true(spoken.contains(UiNeedRate.CAPPED_EXPLANATION),
		"the capped row explains the bound: '%s'" % spoken)
	assert_true(spoken.contains("2.50"), "and still says what the rate is")
	assert_true(spoken.contains(UiNeedRate.SIGN_WORD_FALLING), "and which way it goes")
	assert_false(UiNeedRate.accessible_text(INTERIOR, -250000).contains(
		UiNeedRate.CAPPED_EXPLANATION), "while an uncapped row carries no cap explanation")


# --- what is deliberately absent -------------------------------------------------------------

func test_large_magnitudes_keep_two_decimals_without_overflow() -> void:
	"""Rest in a bed is +12.00 and nothing in the table is wider; the format must not truncate."""
	assert_equal(UiNeedRate.text(1200000), "+12.00 pp/h", "twelve whole points")
	assert_equal(UiNeedRate.text(99999500), "+1000.00 pp/h", "and a far larger one still reads")
	assert_equal(UiNeedRate.text(-99999500), "-1000.00 pp/h", "on either side")


func test_rounding_is_magnitude_first_across_the_sign_boundary() -> void:
	"""Positive and negative rates of equal magnitude must round to equal magnitudes."""
	for magnitude: int in [1, 499, 500, 501, 1499, 1500, 250500, 1200000]:
		assert_equal(UiNeedRate.signed_hundredths(magnitude),
			-UiNeedRate.signed_hundredths(-magnitude),
			"%d rounds symmetrically about zero" % magnitude)
