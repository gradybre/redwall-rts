extends "res://test/framework/test_case.gd"
## The infirmary's numbers and state (decision 0622): the GDD's injury, treatment and recovery arithmetic on the
## demo's private real stores -- the merge, the drains and recovery an hour, the infirmary's rate, airless and
## exhaustion, the floor that keeps the demo non-fatal, the treatment's one payment and its kept work, the herb patch's
## regrowth and the foraging roll -- and the work pace's composition. No scene tree.

const Rules := preload("res://demo/infirmary/care_rules.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")
const Text := preload("res://demo/infirmary/care_text.gd")
const PaceScript := preload("res://demo/work/work_pace.gd")
const Injury := preload("res://scripts/core/injury.gd")
const Needs := preload("res://scripts/core/needs.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const Rng := preload("res://scripts/core/rng.gd")

const HOUR: int = SimClock.TICKS_PER_HOUR
const FED: int = 9000


func _state(count: int, herbalist: int = -1) -> StateScript:
	"""A care state of `count` small residents from tick 0."""
	var s := StateScript.new()
	var sizes := PackedByteArray()
	sizes.resize(count)
	s.configure(sizes, herbalist)
	s.start_at(0, 1)
	return s


func _needs_row(count: int, value: int) -> PackedInt32Array:
	"""A demo need column (hunger or rest) of `count` residents all at `value`."""
	var out := PackedInt32Array()
	out.resize(count)
	out.fill(value)
	return out


func _run(s: StateScript, ticks: int, hunger: int = FED, rest: int = FED) -> void:
	"""Integrate `ticks` more ticks with every resident's demo hunger and rest at these values, a frame's share at a time
	(so every tick integrates one by one)."""
	var n: int = s.resident_count()
	var h: PackedInt32Array = _needs_row(n, hunger)
	var r: PackedInt32Array = _needs_row(n, rest)
	var to: int = s._tick + ticks
	while s._tick < to:
		s.advance_to(mini(s._tick + Rules.MAX_TICKS_PER_FRAME, to), h, r)


# --- the starting state ------------------------------------------------------------------------------------------

func test_everyone_starts_well_and_the_supplies_are_the_gdd_s_starting_stocks() -> void:
	"""Health 100, nobody hurt; the herbalist at HEAL 2 (P3); herb 12 U and cloth 24 U (§5.1); the patch at 0.8 K."""
	var s := _state(3, 1)
	for i in 3:
		assert_equal(s.health(i), 100, "resident %d at full health" % i)
		assert_false(s.is_hurt(i), "resident %d unhurt" % i)
		assert_true(s.is_up(i), "resident %d up" % i)
	assert_equal(s.heal_level(1), 2, "the herbalist at HEAL 2")
	assert_equal(s.heal_level(0), 0, "everyone else at 0")
	assert_equal(s.herb_milli, 12000, "herb 12 U")
	assert_equal(s.cloth_milli, 24000, "cloth 24 U")
	assert_equal(s.patch_milli, 128000, "the patch at 0.8 x 160 U")
	assert_equal(Rules.HERB_FLOOR_MILLI, 32000, "its floor 20% K")


func test_the_cited_numbers_are_the_core_modules() -> void:
	"""Treatment herb 1000 + cloth 500, 60000 milli-WU, +10; the floor 16, up at 70; 80 milli-WU a work tick."""
	assert_equal(Rules.CARE_HERB_MILLI, 1000, "herb 1 U")
	assert_equal(Rules.CARE_CLOTH_MILLI, 500, "cloth 0.5 U")
	assert_equal(Rules.CARE_WORK_MWU, 60000, "60 WU")
	assert_equal(Rules.CARE_HEALTH_RESTORE, 10, "+10 health")
	assert_equal(Rules.HEALTH_FLOOR, 16, "the INJURED band's foot")
	assert_equal(Rules.UP_HEALTH, 70, "the full work band")
	assert_equal(Rules.MWU_PER_TICK, 80, "80 milli-WU a tick")
	assert_equal(Rules.UNTREATED_DRAIN_PER_HOUR, [0, 1, 4] as Array[int], "drains by severity")


# --- injuries -----------------------------------------------------------------------------------------------------

func test_an_injury_takes_its_loss_once_and_merges_by_severity() -> void:
	"""A bite takes 20; a serious exposure replaces it (and takes 35); a later minor cut leaves the serious one."""
	var s := _state(1)
	assert_true(s.hurt(0, Injury.KIND_BITE, 1, 20), "bitten")
	assert_equal(s.health(0), 80, "−20")
	assert_equal(s.kind(0), Injury.KIND_BITE, "a bite")
	assert_true(s.hurt(0, Injury.KIND_EXPOSURE, 2, 35), "exposed")
	assert_equal(s.health(0), 45, "−35 more")
	assert_equal([s.kind(0), s.severity(0)], [Injury.KIND_EXPOSURE, 2], "the worse replaces")
	assert_true(s.hurt(0, Injury.KIND_CUT, 1, 10), "cut")
	assert_equal([s.kind(0), s.severity(0)], [Injury.KIND_EXPOSURE, 2], "a lower severity leaves it")
	assert_equal(s.incidents, 3, "three incidents")
	assert_false(s.hurt(0, Injury.KIND_NONE, 1, 5), "no kind: refused")
	assert_false(s.hurt(0, Injury.KIND_CUT, 3, 5), "severity 3: refused")
	assert_false(s.hurt(4, Injury.KIND_CUT, 1, 5), "no such resident")
	assert_equal(s.ordinal_of(0), 3, "a refused incident takes no ordinal")


func test_equal_severity_keeps_the_lower_kind() -> void:
	"""HAZ-004: equal severity, the lower InjuryKind ID is kept."""
	var s := _state(1)
	s.hurt(0, Injury.KIND_BITE, 1, 0)
	s.hurt(0, Injury.KIND_CUT, 1, 0)
	assert_equal(s.kind(0), Injury.KIND_CUT, "cut (1) beats bite (2)")


func test_untreated_minor_drains_one_an_hour_but_recovers_two_when_fed_and_rested() -> void:
	"""REQ-SET-172 and REQ-SET-017 sum: fed and rested, a minor injury nets +1 an hour; hungry, −1; serious, −4 and
	no recovery."""
	var s := _state(3)
	for i in 3:
		s.hurt(i, Injury.KIND_CUT if i < 2 else Injury.KIND_EXPOSURE, 1 if i < 2 else 2, 20)
	var hunger := PackedInt32Array([FED, 3000, FED])
	while s._tick < HOUR:
		s.advance_to(s._tick + Rules.MAX_TICKS_PER_FRAME, hunger, _needs_row(3, FED))
	assert_equal(s.health(0), 81, "minor, fed: +1")
	assert_equal(s.health(1), 79, "minor, hungry: −1")
	assert_equal(s.health(2), 76, "serious: −4")
	assert_equal(s.untreated_hours(0), 1, "an hour untreated")
	assert_equal(s.rate_per_hour(0), 1, "the card's rate")
	assert_equal(s.rate_per_hour(2), -4, "serious")


func test_health_never_falls_below_the_floor_and_nobody_dies() -> void:
	"""P1: a serious injury at 20 drains to 16 and stays (INJURED, never INCAPACITATED or DEAD); a loss bigger than
	what lies above the floor is capped."""
	var s := _state(2)
	s.hurt(0, Injury.KIND_EXPOSURE, 2, 80)
	assert_equal(s.health(0), 20, "−80 from 100")
	_run(s, 3 * HOUR)
	assert_equal(s.health(0), 16, "held at the floor")
	assert_true(s.floor_holds > 0, "the floor caught it")
	assert_equal(s.status(0), Needs.STATUS_INJURED, "injured, not incapacitated")
	s.hurt(1, Injury.KIND_EXPOSURE, 2, 100)
	assert_equal(s.health(1), 16, "a lethal loss capped at the floor")
	var lowest: int = 100
	for t in 20 * HOUR:
		_run(s, 1, 0, 0)
		lowest = mini(lowest, mini(s.health(0), s.health(1)))
	assert_equal(lowest, 16, "starving and hurt, tick by tick: never under 16")
	assert_equal(s.needs_store().death_count(), 0, "nobody died")


func test_starving_costs_four_an_hour() -> void:
	"""REQ-SET-014 on the kitchen's mirrored hunger: −4 an hour at hunger 0, nothing back."""
	var s := _state(1)
	_run(s, 2 * HOUR, 0)
	assert_equal(s.health(0), 92, "two hours starving")
	assert_true(s.is_starving(0), "starving")
	assert_equal(s.rate_per_hour(0), -4, "the card's rate")


func test_quiet_ticks_are_skipped_and_nothing_is_retained() -> void:
	"""Everyone well: no tick is integrated; ticking on retains no object."""
	var s := _state(4)
	_run(s, 10)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_run(s, 3 * HOUR)
	assert_equal(s.ticks_integrated, 0, "nothing integrated")
	assert_equal(s.ticks_quiet, 3 * HOUR + 10, "every tick skipped")
	s.hurt(2, Injury.KIND_CUT, 1, 10)
	_run(s, 10)
	objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_run(s, HOUR)
	assert_equal(s.ticks_integrated, HOUR + 10, "integrated while someone mends")
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object retained")


# --- the water's hazards -------------------------------------------------------------------------------------------

func test_airless_is_one_serious_exposure_and_a_hundred_and_twenty_nine_an_hour() -> void:
	"""HAZ-002: entering airless is one EXPOSURE severity 2 incident (no immediate loss), −125 an hour with the −4
	untreated; leaving ends the −125 and a second entry is a second incident."""
	var s := _state(1)
	assert_true(s.set_airless(0, true), "airless")
	assert_false(s.set_airless(0, true), "already")
	assert_equal([s.kind(0), s.severity(0), s.health(0)], [Injury.KIND_EXPOSURE, 2, 100], "exposure, no loss")
	@warning_ignore("integer_division")
	_run(s, HOUR / 10)
	assert_equal(s.health(0), 88, "−129 x 0.1 h, truncated")
	assert_true(s.set_airless(0, false), "breathing")
	assert_equal(s.rate_per_hour(0), -4, "only the untreated drain")
	s.set_airless(0, true)
	assert_equal(s.incidents, 2, "a second episode, a second incident")


func test_exhaustion_is_one_incident_until_rest_four_thousand() -> void:
	"""HAZ-003: one EXHAUSTION severity 1 incident, no loss; latched until rest is back at 4000."""
	var s := _state(1)
	assert_true(s.exhaustion(0), "exhausted")
	assert_equal([s.kind(0), s.severity(0), s.health(0)], [Injury.KIND_EXHAUSTION, 1, 100], "exhaustion, no loss")
	assert_false(s.exhaustion(0), "latched")
	assert_false(s.rearm_exhaustion(0, 3999), "not below 4000")
	assert_true(s.rearm_exhaustion(0, 4000), "re-armed at 4000")
	assert_true(s.exhaustion(0), "a second incident")


# --- treatment ----------------------------------------------------------------------------------------------------

func test_treatment_pays_once_at_work_start_and_takes_an_hour_at_factor_one_thousand() -> void:
	"""REQ-SET-173: herb 1 + cloth 0.5 paid once; 60 WU at 80 milli-WU a tick is 750 ticks at factor 1000; then the
	injury clears and +10 health; the healer earns 600 XP (10 a WU)."""
	var s := _state(2)
	s.hurt(0, Injury.KIND_BITE, 1, 20)
	assert_false(s.care(0, 1, 10, 1000), "unpaid: no work")
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NONE, "paid")
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NONE, "again: nothing more")
	assert_equal([s.herb_milli, s.cloth_milli], [11000, 23500], "paid once")
	assert_false(s.care(0, 1, 749, 1000), "749 ticks: not yet")
	assert_equal(s.care_mwu(0), 59920, "59.92 WU")
	assert_true(s.care(0, 1, 1, 1000), "the 750th completes it")
	assert_false(s.is_hurt(0), "cleared")
	assert_equal(s.health(0), 90, "+10")
	assert_equal(s.heal_xp[1], 600, "600 XP")
	assert_equal(s.treated, 1, "one treatment")
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NOT_HURT, "nothing to treat")


func test_a_healer_called_away_leaves_the_work_with_the_patient() -> void:
	"""HAZ-004: care work is the patient's; another healer finishes it without paying again."""
	var s := _state(3)
	s.hurt(0, Injury.KIND_CUT, 1, 10)
	s.pay_treatment(0)
	s.care(0, 1, 300, 1000)
	s.book_care(0)
	assert_equal(s.injury_store().care_progress_mwu_of(0).value, 24000, "24 WU booked to the patient")
	assert_true(s.care(0, 2, 450, 1000), "the second healer finishes it")
	assert_equal(s.herb_milli, 11000, "paid once")


func test_the_supplies_short_stop_a_treatment_starting() -> void:
	"""No herb: NO_HERB; herb but no cloth: NO_CLOTH; nothing is taken."""
	var s := _state(1)
	s.hurt(0, Injury.KIND_CUT, 1, 10)
	s.herb_milli = 999
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NO_HERB, "no herb")
	s.herb_milli = 1000
	s.cloth_store.cloth_milli_u = 499
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NO_CLOTH, "no cloth")
	assert_equal([s.herb_milli, s.cloth_milli], [1000, 499], "nothing taken")


func test_the_skill_and_pace_set_the_work_factor() -> void:
	"""§5.3's skill factor times the pace, clamped 300..1800: HEAL 2 at full pace 1100; 0 at 850, 850; a crawl, 300."""
	assert_equal(Rules.care_factor(2, 1000), 1100, "level 2")
	assert_equal(Rules.care_factor(0, 850), 850, "health 40-69")
	assert_equal(Rules.care_factor(0, 100), 300, "the floor")
	assert_equal(Rules.care_factor(10, 2000), 1800, "the ceiling")
	var s := _state(2)
	s.hurt(0, Injury.KIND_CUT, 1, 10)
	s.pay_treatment(0)
	assert_false(s.care(0, 1, 681, 1100), "681 ticks at 1100: 59.9 WU")
	assert_true(s.care(0, 1, 1, 1100), "682 ticks")


func test_the_infirmary_doubles_recovery() -> void:
	"""REQ-SET-017: a treated patient recovers +2 an hour, +4 in an infirmary bed."""
	var s := _state(2)
	for i in 2:
		s.hurt(i, Injury.KIND_CUT, 1, 40)
		s.pay_treatment(i)
		s.care(i, 1 - i, 750, 1000)
	s.set_in_infirmary(1, true)
	_run(s, 2 * HOUR)
	assert_equal(s.health(0), 74, "70 + 2 x 2")
	assert_equal(s.health(1), 78, "70 + 4 x 2")
	assert_equal(s.rate_per_hour(1), 4, "the card's rate")


func test_the_health_factor_bands() -> void:
	"""§5.2: below 40 600, below 70 850, from 70 1000; the pace factor is it."""
	assert_equal([Rules.health_factor(39), Rules.health_factor(40)], [600, 850], "40")
	assert_equal([Rules.health_factor(69), Rules.health_factor(70)], [850, 1000], "70")
	var s := _state(1)
	s.hurt(0, Injury.KIND_CUT, 1, 31)
	assert_equal(s.pace_permille(0), 850, "health 69")


# --- herbs --------------------------------------------------------------------------------------------------------

func test_the_herb_patch_regrows_by_the_ruled_formula() -> void:
	"""§5.5 (decision 0036): `min(K − P, floor((K − P) x 80 x S / 10^6) + 1000)`: spring from 128 U +3.56 U; winter
	(S 200) less; full, none."""
	assert_equal(Rules.herb_regrowth_milli(128000, 0), 3560, "spring")
	assert_equal(Rules.herb_regrowth_milli(128000, 3), 1512, "winter")
	assert_equal(Rules.herb_regrowth_milli(160000, 1), 0, "full")
	assert_equal(Rules.herb_regrowth_milli(159500, 1), 500, "capped at the room left")
	var s := _state(1)
	assert_equal(s.regrow_to(3, 0), 3560 + Rules.herb_regrowth_milli(131560, 0), "two midnights")


func test_herbs_reach_the_shelf_only_above_the_patch_floor() -> void:
	"""A delivery takes from the patch down to its floor and no further."""
	var s := _state(1)
	s.patch_milli = 34000
	assert_equal(s.deliver_herbs(4000), 2000, "only 2 U above the floor")
	assert_equal([s.patch_milli, s.herb_milli], [32000, 14000], "moved")
	assert_equal(s.deliver_herbs(1000), 0, "at the floor: none")


func test_the_herb_work_and_forage_hazard_numbers() -> void:
	"""§5.5's work per U and REQ-SET-068's chance."""
	assert_equal(Rules.herb_work_mwu(0, 1), 8000, "ceil(7.27) WU at danger 1")
	assert_equal(Rules.herb_work_mwu(0, 0), 8000, "8 WU at danger 0")
	assert_equal(Rules.herb_work_mwu(5, 3), 6000, "ceil(5.13) WU")
	assert_equal(Rules.forage_injury_chance(1, 0), 8, "8 in 10000")
	assert_equal(Rules.forage_injury_chance(1, 10), 1, "at least 1")


func test_forage_rolls_once_per_sixty_wu() -> void:
	"""No roll before a 60 WU segment is complete (the draws themselves: test_the_forage_rolls_are_the_forage_stream_s_draws)."""
	var s := _state(1)
	assert_equal(s.forage(0, 59999), 0, "no segment completed")
	assert_equal(s.forage(0, 0), 0, "no work: nothing")


# --- the work pace ------------------------------------------------------------------------------------------------

func test_the_work_pace_multiplies_its_factors() -> void:
	"""Factors compose by multiplication, in the order added; a duplicate name is refused; none slow: 1000."""
	var pace := PaceScript.new()
	assert_equal(pace.permille(0), 1000, "no factor")
	assert_true(pace.add_factor("health", func(_who: int) -> int: return 850), "health")
	assert_false(pace.add_factor("health", func(_who: int) -> int: return 500), "a second health: refused")
	assert_false(pace.add_factor("", func(_who: int) -> int: return 500), "no name: refused")
	assert_true(pace.add_factor("chill", func(who: int) -> int: return 800 if who == 1 else 1000), "chill")
	assert_equal(pace.permille(0), 850, "health only")
	assert_equal(pace.permille(1), 680, "850 x 800")
	assert_equal(pace.scale(1, 1000), 680, "scaled")
	assert_equal(pace.slowed_text(1), "work at 68% (health 85%, chill 80%)", "said")
	assert_equal(pace.count(), 2, "two factors")
	assert_equal([pace.name_of(1), pace.name_of(5)], ["chill", ""], "names")
	assert_equal(pace.factor_of(9, 0), 1000, "out of range")
	pace.add_factor("broken", func(_who: int) -> int: return -5)
	assert_equal([pace.factor_of(2, 0), pace.permille(0)], [0, 0], "a negative factor counts as 0")


# --- words --------------------------------------------------------------------------------------------------------

func test_the_card_and_news_words() -> void:
	"""The card's lines and the news lines, in plain words."""
	assert_equal(Text.injury_words(Injury.KIND_BITE, 1), "a bite (minor)", "injury")
	assert_equal(Text.rate_words(-4), "−4 an hour", "rate")
	assert_equal(Text.rate_words(0), "steady", "steady")
	assert_equal(Text.hurt_lines(78, Injury.KIND_BITE, 1, 2, -1, "Waiting: a healer is coming"),
		PackedStringArray(["Hurt: a bite (minor) · health 78", "Untreated 2 h · health −1 an hour until treated",
		"Waiting: a healer is coming"]), "hurt lines")
	assert_equal(Text.recovering_line(66, 4, true, true), "Recovering · health 66 · +4 an hour in the infirmary · up at 70 in about 1 h",
		"recovering")
	assert_equal(Text.short_word(true, Injury.KIND_CUT, 80), "hurt (cut)", "group: hurt")
	assert_equal(Text.short_word(false, 0, 100), "", "group: well")
	assert_equal(Text.units(11500), "11.5", "units")
	assert_true(Text.hurt_notice("Corra", Injury.KIND_BITE, 1, 20, "in the water").begins_with(
		"Corra is hurt in the water: a bite (minor) and lost 20 health."), "notice")
	assert_equal(Text.treated_notice("Linnet", "Corra", Injury.KIND_BITE, 90),
		"Linnet treated Corra's bite (herb 1 U, cloth 0.5 U): health 90", "treated")


# --- boundaries (mutation testing) -----------------------------------------------------------------------------------

func test_exactly_enough_supplies_pay_and_a_new_injury_pays_again() -> void:
	"""Herb exactly 1 U and cloth exactly 0.5 U pay; treated, the next injury's treatment is paid afresh."""
	var s := _state(2)
	s.herb_milli = 1000
	s.cloth_store.cloth_milli_u = 500
	s.hurt(0, Injury.KIND_CUT, 1, 10)
	assert_equal(s.pay_treatment(0), StateScript.REFUSE_NONE, "exactly enough")
	assert_true(s.care(0, 1, 750, 1000), "treated")
	s.herb_milli = 5000
	s.cloth_store.cloth_milli_u = 5000
	s.hurt(0, Injury.KIND_BITE, 1, 10)
	assert_false(s.is_paid(0), "a new injury is unpaid")
	s.pay_treatment(0)
	assert_equal([s.herb_milli, s.cloth_milli], [4000, 4500], "paid again")


func test_the_work_remainder_is_kept_tick_by_tick() -> void:
	"""§5.2's retained remainder: at factor 999 a tick makes 79.92 milli-WU, so 60 WU take 751 ticks, not 750 (and
	not 760, as dropping it would)."""
	var s := _state(2)
	s.hurt(0, Injury.KIND_CUT, 1, 10)
	s.pay_treatment(0)
	var early: int = 0
	for t in 750:
		early += 1 if s.care(0, 1, 1, 999) else 0
	assert_equal(early, 0, "not within 750 ticks")
	assert_true(s.care(0, 1, 1, 999), "the 751st tick completes it")


func test_up_at_exactly_seventy() -> void:
	"""P4: no injury and health exactly 70 is up; 69 is not."""
	var s := _state(2)
	s.hurt(0, Injury.KIND_CUT, 1, 40)
	s.pay_treatment(0)
	s.care(0, 1, 750, 1000)
	assert_equal(s.health(0), 70, "60 + 10")
	assert_true(s.is_up(0), "70: up")
	s.hurt(1, Injury.KIND_CUT, 1, 41)
	s.pay_treatment(1)
	s.care(1, 0, 750, 1000)
	assert_false(s.is_up(1), "69: resting")


func test_the_forage_rolls_are_the_forage_stream_s_draws() -> void:
	"""REQ-SET-068 exactly: one FORAGE draw per 60 WU, injuring when it is under 8; the same draws from a replica
	stream seeded alike give the same count over 60000 segments."""
	var s := _state(1)
	var replica := Rng.new()
	replica.seed_world(Rules.WORLD_SEED)
	var expected: int = 0
	var got: int = 0
	for k in 60000:
		got += s.forage(0, 60000)
		expected += 1 if replica.draw_below(Rng.STREAM_FORAGE, 10000).value < 8 else 0
	assert_equal(got, expected, "the same injuries")
	assert_true(expected > 0, "some")


func test_a_jump_is_taken_in_closed_form_but_its_last_ticks_one_by_one() -> void:
	"""A JUMP: quiet, a 48-hour jump is skipped whole; while one mends (minor, fed and rested: +1 an hour), 48 hours take
	it from 80 to 100 with only the last 30 ticks integrated; a serious one (−4 an hour) lands on the floor, not under."""
	var s := _state(2)
	var fed := _needs_row(2, FED)
	assert_equal(s.advance_to(48 * HOUR, fed, fed), 0, "quiet: nothing integrated")
	assert_equal(s.ticks_quiet, 48 * HOUR, "skipped whole")
	s.hurt(0, Injury.KIND_CUT, 1, 20)
	assert_equal(s.advance_to(60 * HOUR, fed, fed), Rules.MAX_TICKS_PER_FRAME, "the last ticks one by one")
	assert_equal(s.ticks_fast, 12 * HOUR - Rules.MAX_TICKS_PER_FRAME, "the rest in closed form")
	assert_equal(s.health(0), 91, "80 + 11 (11.96 h at +1, then 30 ticks)")
	s.hurt(1, Injury.KIND_EXPOSURE, 2, 50)
	s.advance_to(108 * HOUR, fed, fed)
	assert_equal([s.health(0), s.health(1)], [100, 16], "capped at 100; held at the floor")
	assert_equal(s.needs_store().death_count(), 0, "nobody died")
