extends "res://test/framework/test_case.gd"
## Coverage for the Schedule component: the GDD §5.3 template hour boundaries, the compiled
## template domain, and the resolution of `current_activity` under the §5.3 sleep exception and
## the REQ-SET-012/013/015 needs interrupts.
##
## The load-bearing tests here are the boundary ones. A template that is approximately right --
## work starting at 08:00 instead of 07:00, sleep ending at 07:00 instead of 06:00 -- still
## produces a plausible 24-hour day, so every one of the seven §5.3 segment edges is asserted on
## both sides, and each interrupt threshold is asserted at the value and one point past it.

const IntMath := preload("res://scripts/core/int_math.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

const SLEEP: int = ScheduleScript.ACTIVITY_SLEEP
const ANYTHING: int = ScheduleScript.ACTIVITY_ANYTHING
const WORK: int = ScheduleScript.ACTIVITY_WORK
const SOCIAL: int = ScheduleScript.ACTIVITY_SOCIAL

## GDD §5.3: "22:00-06:00 SLEEP, 06:00-07:00 ANYTHING, 07:00-12:00 WORK, 12:00-13:00 ANYTHING,
## 13:00-18:00 WORK, 18:00-20:00 SOCIAL, 20:00-22:00 ANYTHING", written out hour by hour so a
## single shifted boundary fails a named assertion.
const EXPECTED_DEFAULT: Array[int] = [
	SLEEP, SLEEP, SLEEP, SLEEP, SLEEP, SLEEP,          # 00:00-06:00
	ANYTHING,                                          # 06:00-07:00
	WORK, WORK, WORK, WORK, WORK,                      # 07:00-12:00
	ANYTHING,                                          # 12:00-13:00
	WORK, WORK, WORK, WORK, WORK,                      # 13:00-18:00
	SOCIAL, SOCIAL,                                    # 18:00-20:00
	ANYTHING, ANYTHING,                                # 20:00-22:00
	SLEEP, SLEEP,                                      # 22:00-00:00
]

## "Night shift is the same pattern offset 12 hours", written out independently rather than
## derived from EXPECTED_DEFAULT, so a broken offset cannot agree with a broken expectation.
const EXPECTED_NIGHT_SHIFT: Array[int] = [
	ANYTHING,                                          # 00:00-01:00
	WORK, WORK, WORK, WORK, WORK,                      # 01:00-06:00
	SOCIAL, SOCIAL,                                    # 06:00-08:00
	ANYTHING, ANYTHING,                                # 08:00-10:00
	SLEEP, SLEEP, SLEEP, SLEEP, SLEEP, SLEEP, SLEEP, SLEEP,  # 10:00-18:00
	ANYTHING,                                          # 18:00-19:00
	WORK, WORK, WORK, WORK, WORK,                      # 19:00-00:00
]

var _needs: NeedsScript = null
var _schedule: ScheduleScript = null


func before_each() -> void:
	"""Fresh needs store shared with a fresh schedule store, with no rows in either."""
	_needs = NeedsScript.new()
	_schedule = ScheduleScript.new(_needs)


func after_each() -> void:
	"""Drop both stores so no test inherits another's rows."""
	_schedule = null
	_needs = null


func _template(key: StringName) -> int:
	"""Compiled ID of one schedule template key, failing the test if it refuses."""
	var result: IntMath.IntResult = _schedule.template_id_of(key)
	assert_true(result.ok, "template id for %s (error: %s)" % [key, result.error])
	return result.value


func _spawn(slot: int, key: StringName) -> void:
	"""Spawn a small resident's needs row and a schedule row on the same slot."""
	assert_true(_needs.spawn(slot, NeedsScript.SIZE_SMALL).ok, "needs spawn %d" % slot)
	assert_true(_schedule.spawn(slot, _template(key)).ok, "schedule spawn %d" % slot)


func _set_need(slot: int, need: int, value: int) -> void:
	"""Drive one need to an exact value from the §5.1 initial 7500."""
	var current: IntMath.IntResult = _needs.need_of(slot, need)
	assert_true(current.ok, "read need before setting it")
	assert_true(_needs.apply_need_event(slot, need, value - current.value).ok, "set need")
	assert_equal(_needs.need_of(slot, need).value, value, "need is now %d" % value)


func _resolve(slot: int, hour: int, prepared_meal_reachable: bool) -> int:
	"""Resolve one hour, failing the test if the module refuses."""
	var result: IntMath.IntResult = _schedule.resolve(slot, hour, prepared_meal_reachable)
	assert_true(result.ok, "resolve hour %d (error: %s)" % [hour, result.error])
	return result.value


# --- the compiled template domain ----------------------------------------------------------------

func test_template_ids_are_compiled_in_ascending_ascii_order() -> void:
	"""§4.3 does not number the templates, so BAL-CAT-001 assigns them from sorted keys: they are
	NOT numbered in the order §5.3 mentions them (default, night shift, flexible)."""
	assert_equal(_schedule.catalog_error(), "", "the template domain compiled")
	assert_equal(_template(ScheduleScript.TEMPLATE_DEFAULT_KEY), 0, "default sorts first")
	assert_equal(_template(ScheduleScript.TEMPLATE_FLEXIBLE_KEY), 1, "flexible sorts second")
	assert_equal(_template(ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY), 2, "night_shift sorts last")
	assert_equal(_schedule.template_ids().size(), 3, "§5.3 names exactly three templates")


func test_template_id_of_refuses_an_unknown_key() -> void:
	"""An unknown template name refuses rather than resolving to some default schedule."""
	var result: IntMath.IntResult = _schedule.template_id_of(&"graveyard")
	assert_false(result.ok, "unknown template key must refuse")
	assert_equal(result.error, "UNKNOWN_TEMPLATE_KEY", "explicit refusal code")
	assert_equal(result.value, 0, "a refusal carries no id")


func test_default_template_id_names_the_5_3_default_schedule() -> void:
	"""§5.1 states no starting template; default_template_id() names §5.3's without guessing."""
	var result: IntMath.IntResult = _schedule.default_template_id()
	assert_true(result.ok, "default template resolves")
	assert_equal(result.value, _template(ScheduleScript.TEMPLATE_DEFAULT_KEY), "same id")


# --- §5.3 default schedule hour boundaries -------------------------------------------------------

func test_default_template_matches_the_5_3_hour_table() -> void:
	"""All 24 hours of the default schedule, asserted one hour at a time."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		var activity: IntMath.IntResult = _schedule.template_activity_at(template_id, hour)
		assert_true(activity.ok, "hour %d reads" % hour)
		assert_equal(activity.value, EXPECTED_DEFAULT[hour],
			"§5.3 default schedule at %02d:00" % hour)


func test_every_default_boundary_differs_from_the_hour_before_it() -> void:
	"""The seven §5.3 segment edges, each asserted on both sides. A boundary shifted by one hour
	makes exactly one of these pairs agree where it must differ."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var boundaries: Array[int] = [6, 7, 12, 13, 18, 20, 22]
	for hour: int in boundaries:
		var before: int = _schedule.template_activity_at(
			template_id, (hour + 23) % ScheduleScript.HOURS_PER_DAY).value
		var after: int = _schedule.template_activity_at(template_id, hour).value
		assert_equal(before, EXPECTED_DEFAULT[(hour + 23) % 24], "%02d:00 is the last of its block" % hour)
		assert_equal(after, EXPECTED_DEFAULT[hour], "%02d:00 starts a new block" % hour)
		assert_true(before != after, "the activity changes at %02d:00" % hour)


func test_default_sleep_block_wraps_midnight_for_exactly_eight_hours() -> void:
	""""22:00-06:00 SLEEP" crosses midnight; 21:00 and 06:00 are outside it."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var sleep_hours: int = 0
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		if _schedule.template_activity_at(template_id, hour).value == SLEEP:
			sleep_hours += 1
	assert_equal(sleep_hours, 8, "22:00-06:00 is eight hours")
	assert_equal(_schedule.template_activity_at(template_id, 21).value, ANYTHING, "21:00 is not sleep")
	assert_equal(_schedule.template_activity_at(template_id, 22).value, SLEEP, "22:00 begins sleep")
	assert_equal(_schedule.template_activity_at(template_id, 5).value, SLEEP, "05:00 is still sleep")
	assert_equal(_schedule.template_activity_at(template_id, 6).value, ANYTHING, "06:00 ends sleep")


func test_default_block_lengths_sum_to_the_whole_day() -> void:
	"""8 SLEEP + 4 ANYTHING + 10 WORK + 2 SOCIAL = 24. A dropped segment loses hours silently."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var counts: Array[int] = [0, 0, 0, 0]
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		counts[_schedule.template_activity_at(template_id, hour).value] += 1
	assert_equal(counts[SLEEP], 8, "eight SLEEP hours")
	assert_equal(counts[ANYTHING], 4, "four ANYTHING hours: 06, 12, 20, 21")
	assert_equal(counts[WORK], 10, "ten WORK hours: 07-11 and 13-17")
	assert_equal(counts[SOCIAL], 2, "two SOCIAL hours: 18 and 19")


# --- §5.3 night shift and flexible ------------------------------------------------------------

func test_night_shift_matches_the_independently_written_offset_table() -> void:
	"""All 24 hours of the night shift, against a table written from the clock rather than from
	the default table, so a wrong offset cannot cancel out."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_schedule.template_activity_at(template_id, hour).value,
			EXPECTED_NIGHT_SHIFT[hour], "night shift at %02d:00" % hour)


func test_night_shift_is_the_default_pattern_offset_by_twelve_hours() -> void:
	""""Night shift is the same pattern offset 12 hours" -- an 11 or 13 hour offset fails here."""
	var default_id: int = _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var night_id: int = _template(ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	assert_equal(ScheduleScript.NIGHT_SHIFT_OFFSET_HOURS, 12, "the published offset is 12 hours")
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		var shifted: int = (hour + 12) % ScheduleScript.HOURS_PER_DAY
		assert_equal(_schedule.template_activity_at(night_id, shifted).value,
			_schedule.template_activity_at(default_id, hour).value,
			"night %02d:00 equals default %02d:00" % [shifted, hour])


func test_flexible_template_is_all_anything() -> void:
	""""Flexible is all ANYTHING" -- 24 hours with no work, sleep or social block."""
	var template_id: int = _template(ScheduleScript.TEMPLATE_FLEXIBLE_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_schedule.template_activity_at(template_id, hour).value, ANYTHING,
			"flexible at %02d:00" % hour)


func test_template_activity_refuses_an_unknown_template_or_hour() -> void:
	"""Hour 24 and template 3 name nothing; both refuse rather than wrapping or clamping."""
	assert_false(_schedule.template_activity_at(3, 0).ok, "template 3 must refuse")
	assert_false(_schedule.template_activity_at(-1, 0).ok, "template -1 must refuse")
	assert_false(_schedule.template_activity_at(0, 24).ok, "hour 24 must refuse")
	assert_false(_schedule.template_activity_at(0, -1).ok, "hour -1 must refuse")


# --- the segment-tiling guard ---------------------------------------------------------------------

func test_the_5_3_segment_list_tiles_the_day_at_both_offsets() -> void:
	"""The shipped §5.3 list must pass its own guard at offset 0 and at the 12-hour night shift."""
	assert_equal(ScheduleScript.segment_coverage_error(ScheduleScript.DEFAULT_SEGMENTS, 0), "",
		"the default segment list tiles all 24 hours")
	assert_equal(ScheduleScript.segment_coverage_error(ScheduleScript.DEFAULT_SEGMENTS, 12), "",
		"and still tiles them shifted 12 hours")


func test_the_tiling_guard_catches_a_gap() -> void:
	"""A guard that only ever sees correct data is indistinguishable from `return ""`. Here it is
	handed a list missing 06:00-07:00, which is exactly the shape of a dropped §5.3 segment."""
	var with_gap: Array[int] = [
		22, 6, SLEEP, 7, 12, WORK, 12, 13, ANYTHING, 13, 18, WORK, 18, 20, SOCIAL, 20, 22, ANYTHING,
	]
	var error: String = ScheduleScript.segment_coverage_error(with_gap, 0)
	assert_false(error.is_empty(), "a one-hour gap must be reported")
	assert_true(error.contains("uncovered"), "the reason names the uncovered hour(s): %s" % error)


func test_the_tiling_guard_catches_an_overlap() -> void:
	"""Two segments claiming the same hour would silently let declaration order decide it."""
	var overlapping: Array[int] = [
		22, 6, SLEEP, 5, 7, ANYTHING, 7, 12, WORK, 12, 13, ANYTHING,
		13, 18, WORK, 18, 20, SOCIAL, 20, 22, ANYTHING,
	]
	var error: String = ScheduleScript.segment_coverage_error(overlapping, 0)
	assert_false(error.is_empty(), "an overlapping hour must be reported")
	assert_true(error.contains("two segments"), "the reason names the doubly covered hour: %s" % error)


func test_the_tiling_guard_catches_malformed_segments() -> void:
	"""A ragged list, an out-of-range hour, an empty segment and a bad activity all refuse."""
	assert_false(ScheduleScript.segment_coverage_error([0, 24] as Array[int], 0).is_empty(),
		"a list that is not whole triples must be reported")
	assert_false(ScheduleScript.segment_coverage_error([] as Array[int], 0).is_empty(),
		"an empty list covers nothing and must be reported")
	assert_false(ScheduleScript.segment_coverage_error([0, 24, SLEEP] as Array[int], 0).is_empty(),
		"hour 24 must be reported")
	assert_false(ScheduleScript.segment_coverage_error([5, 5, SLEEP] as Array[int], 0).is_empty(),
		"an empty segment must be reported")
	assert_false(ScheduleScript.segment_coverage_error([0, 12, 9] as Array[int], 0).is_empty(),
		"activity 9 is not in §4.3's Activity enum")


# --- rows -----------------------------------------------------------------------------------------

func test_spawn_copies_all_twenty_four_template_hours_into_the_row() -> void:
	"""hourly_activity is per resident, not a pointer at the template."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_schedule.hour_activity_of(0, hour).value, EXPECTED_DEFAULT[hour],
			"row hour %02d:00" % hour)
	assert_equal(_schedule.template_of(0).value,
		_template(ScheduleScript.TEMPLATE_DEFAULT_KEY), "template is recorded")


func test_the_hourly_stride_is_slot_times_twenty_four_plus_hour() -> void:
	"""Two adjacent rows on different templates must not bleed into one another."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_spawn(1, ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	_spawn(511, ScheduleScript.TEMPLATE_FLEXIBLE_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_schedule.hour_activity_of(0, hour).value, EXPECTED_DEFAULT[hour], "row 0")
		assert_equal(_schedule.hour_activity_of(1, hour).value, EXPECTED_NIGHT_SHIFT[hour], "row 1")
		assert_equal(_schedule.hour_activity_of(511, hour).value, ANYTHING, "row 511")


func test_set_hour_activity_customizes_one_hour_only() -> void:
	"""A player edit changes one slot and leaves its neighbours on the template."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_true(_schedule.set_hour_activity(0, 9, SOCIAL).ok, "customize 09:00")
	assert_equal(_schedule.hour_activity_of(0, 9).value, SOCIAL, "09:00 is now SOCIAL")
	assert_equal(_schedule.hour_activity_of(0, 8).value, WORK, "08:00 is untouched")
	assert_equal(_schedule.hour_activity_of(0, 10).value, WORK, "10:00 is untouched")


func test_set_hour_activity_refuses_a_value_outside_the_activity_enum() -> void:
	"""§4.3's Activity has four values; 4 and -1 are not activities."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_false(_schedule.set_hour_activity(0, 9, 4).ok, "activity 4 must refuse")
	assert_false(_schedule.set_hour_activity(0, 9, -1).ok, "activity -1 must refuse")
	assert_false(_schedule.set_hour_activity(0, 24, SLEEP).ok, "hour 24 must refuse")
	assert_equal(_schedule.hour_activity_of(0, 9).value, WORK, "09:00 kept its template value")


func test_assign_template_replaces_every_customized_hour() -> void:
	"""Reassigning a template discards per-hour edits rather than merging them."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_true(_schedule.set_hour_activity(0, 9, SOCIAL).ok, "customize")
	assert_true(_schedule.assign_template(0, _template(ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)).ok,
		"assign night shift")
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_schedule.hour_activity_of(0, hour).value, EXPECTED_NIGHT_SHIFT[hour],
			"hour %02d:00 follows the new template" % hour)


func test_assign_template_resets_the_sleep_exception_latch() -> void:
	"""The latch is scoped to a particular scheduled sleep window. Changing the template changes
	which hours that window covers, so an earlier window's satisfaction must not carry over."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 2, true), ANYTHING, "the exception latched under the default")
	assert_true(_schedule.assign_template(0, _template(ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)).ok,
		"switch to the night shift")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 0, "the latch reset with the template")
	_set_need(0, NeedsScript.NEED_REST, 6000)
	assert_equal(_resolve(0, 12, true), SLEEP, "the new window's 12:00 sleeps normally")


func test_despawn_leaves_no_residue_in_the_inactive_row() -> void:
	"""Two logically identical worlds must serialize to identical columns, so a released row is
	returned to exactly the state clear() produces -- not left holding the last resident's day."""
	_spawn(9, ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	_set_need(9, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(9, 12, true), ANYTHING, "resolve and latch before releasing the row")
	assert_false(_schedule.inactive_row_is_clear(9), "a present row is never reported clear")
	assert_true(_schedule.despawn(9).ok, "despawn succeeds")
	assert_true(_schedule.inactive_row_is_clear(9), "the released row holds no residue")
	assert_true(_schedule.inactive_row_is_clear(8), "a never-used row is clear too")


func test_clear_returns_every_row_to_the_same_empty_state_as_despawn() -> void:
	"""clear() refills the existing buffers; the empty state it produces is the one despawn()
	must reproduce, so the two are asserted against the same predicate."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_spawn(1, ScheduleScript.TEMPLATE_FLEXIBLE_KEY)
	assert_equal(_resolve(0, 9, true), WORK, "resolve one row first")
	_schedule.clear()
	assert_equal(_schedule.present_count(), 0, "no rows survive clear()")
	assert_true(_schedule.inactive_row_is_clear(0), "row 0 is empty")
	assert_true(_schedule.inactive_row_is_clear(1), "row 1 is empty")


func test_lifecycle_refusals_and_capacity() -> void:
	"""512 rows exist (architecture §2.2); a row spawns once and reads refuse when absent."""
	_spawn(511, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_false(_schedule.spawn(511, 0).ok, "respawning an occupied row refuses")
	assert_false(_schedule.spawn(512, 0).ok, "slot 512 is out of range")
	assert_false(_schedule.hour_activity_of(3, 0).ok, "an unspawned row refuses reads")
	assert_true(_schedule.despawn(511).ok, "despawn succeeds")
	assert_false(_schedule.despawn(511).ok, "double despawn refuses")
	assert_equal(_schedule.present_count(), 0, "no rows remain")


# --- current_activity is resolved, not looked up --------------------------------------------------

func test_current_activity_refuses_before_the_first_resolve() -> void:
	"""A freshly spawned row has no resolved activity; returning ANYTHING would be a sentinel."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var read: IntMath.IntResult = _schedule.current_activity_of(0)
	assert_false(read.ok, "unresolved current_activity must refuse")
	assert_equal(read.error, "ACTIVITY_NOT_RESOLVED", "explicit refusal code")
	assert_equal(read.value, 0, "a refusal carries no activity")


func test_resolve_stores_the_activity_it_returns() -> void:
	"""After a resolve, current_activity_of() answers with that hour's resolved value."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_equal(_resolve(0, 9, true), WORK, "09:00 is a work hour for a well-fed resident")
	assert_equal(_schedule.current_activity_of(0).value, WORK, "stored")
	assert_equal(_resolve(0, 19, true), SOCIAL, "19:00 is a social hour")
	assert_equal(_schedule.current_activity_of(0).value, SOCIAL, "overwritten")


func test_resolution_reads_the_owners_own_hour_row_not_slot_zeros() -> void:
	"""resolve() must index `slot*24 + hour` like every other reader. On slot 0 a wrong stride is
	invisible (0*23 == 0*24), so this drives the resolution from high slots on two templates and
	checks every hour of both. A stride of 23 makes row 300 read row 287's bytes."""
	_spawn(300, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_spawn(301, ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_resolve(300, hour, true), EXPECTED_DEFAULT[hour],
			"slot 300 resolves its own default schedule at %02d:00" % hour)
		assert_equal(_resolve(301, hour, true), EXPECTED_NIGHT_SHIFT[hour],
			"slot 301 resolves its own night shift at %02d:00" % hour)


func test_resolution_of_one_row_does_not_disturb_another() -> void:
	"""Two residents on the same hour with different needs resolve independently."""
	_spawn(10, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_spawn(11, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(10, NeedsScript.NEED_REST, 400)
	assert_equal(_resolve(10, 9, true), SLEEP, "the collapsed resident sleeps")
	assert_equal(_resolve(11, 9, true), WORK, "their neighbour still works")
	assert_equal(_schedule.current_activity_of(10).value, SLEEP, "slot 10 kept its own value")
	assert_equal(_schedule.sleep_satisfied_of(11).value, 0, "slot 11's latch is its own")


func test_a_contented_resident_resolves_to_the_scheduled_activity() -> void:
	"""With every need at the §5.1 initial 7500, no interrupt fires and the schedule stands."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	for hour: int in ScheduleScript.HOURS_PER_DAY:
		assert_equal(_resolve(0, hour, true), EXPECTED_DEFAULT[hour],
			"unmodified needs leave %02d:00 alone" % hour)


# --- REQ-SET-015 rest collapse ----------------------------------------------------------------

func test_rest_at_or_below_500_forces_sleep_over_scheduled_work() -> void:
	"""REQ-SET-015: "While rest<=500 ... cancel ordinary work, place the resident in floor sleep"."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 500)
	assert_equal(_resolve(0, 9, true), SLEEP, "a work hour becomes sleep at rest 500")
	assert_equal(_resolve(0, 19, true), SLEEP, "a social hour becomes sleep at rest 500")
	assert_equal(_resolve(0, 6, true), SLEEP, "an anything hour becomes sleep at rest 500")


func test_rest_of_501_does_not_force_sleep() -> void:
	"""The collapse threshold is inclusive at 500 and nothing more; 501 still works."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 501)
	assert_equal(_resolve(0, 9, true), WORK, "rest 501 leaves the work hour intact")


# --- REQ-SET-012 eat before work ------------------------------------------------------------------

func test_hunger_at_or_below_3500_displaces_scheduled_work_when_a_meal_is_reachable() -> void:
	"""REQ-SET-012: "start a 12-WU eating task before ordinary work". §4.3 has no EAT activity, so
	the hour resolves to ANYTHING -- the activity under which a personal need task runs."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 3500)
	assert_equal(_resolve(0, 9, true), ANYTHING, "hunger 3500 interrupts work")
	assert_equal(_resolve(0, 14, true), ANYTHING, "the afternoon work block too")


func test_hunger_of_3501_does_not_displace_work() -> void:
	"""The eat threshold is inclusive at 3500; one point above it the resident works."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 3501)
	assert_equal(_resolve(0, 9, true), WORK, "hunger 3501 leaves the work hour intact")


func test_the_eat_interrupt_only_displaces_work_hours() -> void:
	"""REQ-SET-012 displaces "ordinary work". A SOCIAL or ANYTHING hour already permits eating,
	so hunger does not rewrite it into something else."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 1000)
	assert_equal(_resolve(0, 19, true), SOCIAL, "18:00-20:00 stays SOCIAL")
	assert_equal(_resolve(0, 6, true), ANYTHING, "06:00-07:00 stays ANYTHING")


# --- REQ-SET-013 raw fallback ------------------------------------------------------------------

func test_no_reachable_meal_leaves_work_alone_above_the_urgent_threshold() -> void:
	"""REQ-SET-013 permits raw-edible food only at hunger<=1500, so between 1501 and 3500 with
	nothing prepared there is no permitted meal to interrupt for."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 3000)
	assert_equal(_resolve(0, 9, false), WORK, "hunger 3000 with no prepared meal still works")
	_set_need(0, NeedsScript.NEED_HUNGER, 1501)
	assert_equal(_resolve(0, 9, false), WORK, "hunger 1501 with no prepared meal still works")


func test_no_reachable_meal_displaces_work_at_or_below_1500() -> void:
	"""REQ-SET-013's raw-edible fallback fires at the urgent threshold and displaces work."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 1500)
	assert_equal(_resolve(0, 9, false), ANYTHING, "hunger 1500 with no prepared meal interrupts")
	_set_need(0, NeedsScript.NEED_HUNGER, 0)
	assert_equal(_resolve(0, 9, false), ANYTHING, "a starving resident interrupts")


func test_meal_reachability_changes_the_threshold_at_the_same_hunger() -> void:
	"""The same resident at hunger 2000 interrupts with a prepared meal and works without one.
	This is the whole difference between REQ-SET-012 and REQ-SET-013."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_HUNGER, 2000)
	assert_equal(_resolve(0, 9, true), ANYTHING, "prepared meal reachable: eat first")
	assert_equal(_resolve(0, 9, false), WORK, "nothing prepared and not yet urgent: work")


# --- §5.3 sleep exception ---------------------------------------------------------------------

func test_sleep_continues_below_the_rest_threshold() -> void:
	""""Sleep only continues until rest>=9000": at 8999 the resident is still asleep."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 8999)
	assert_equal(_resolve(0, 2, true), SLEEP, "02:00 is still sleep at rest 8999")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 0, "the exception has not latched")


func test_rest_reaching_9000_ends_sleep_for_the_rest_of_the_window() -> void:
	""""a resident then uses ANYTHING until the scheduled sleep window ends"."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 2, true), ANYTHING, "02:00 becomes ANYTHING at rest 9000")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 1, "the exception latched")


func test_the_sleep_exception_survives_rest_decaying_inside_the_window() -> void:
	"""Rest decays 375/hour while awake (§5.2), so an unlatched live comparison would put the
	resident back to bed 2.7 hours later -- inside the same window, which §5.3 forbids."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 2, true), ANYTHING, "the exception fires at 02:00")
	_set_need(0, NeedsScript.NEED_REST, 6000)
	assert_equal(_resolve(0, 3, true), ANYTHING, "03:00 stays ANYTHING at rest 6000")
	assert_equal(_resolve(0, 4, true), ANYTHING, "04:00 stays ANYTHING")
	assert_equal(_resolve(0, 5, true), ANYTHING, "05:00, the last sleep hour, stays ANYTHING")


func test_the_sleep_exception_clears_when_the_window_ends() -> void:
	"""The latch is scoped to one scheduled sleep window; the next night starts asleep again."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 5, true), ANYTHING, "the exception fires in the sleep window")
	assert_equal(_resolve(0, 6, true), ANYTHING, "06:00 is scheduled ANYTHING and ends the window")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 0, "the latch cleared with the window")
	_set_need(0, NeedsScript.NEED_REST, 6000)
	assert_equal(_resolve(0, 22, true), SLEEP, "the next night's 22:00 sleeps normally")


func test_a_collapse_restarts_sleep_even_after_the_exception_latched() -> void:
	"""REQ-SET-015 outranks the §5.3 exception: rest<=500 sleeps and clears the latch, so
	recovering past 500 does not immediately throw the resident back out of bed."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 2, true), ANYTHING, "the exception latched")
	_set_need(0, NeedsScript.NEED_REST, 400)
	assert_equal(_resolve(0, 3, true), SLEEP, "collapse forces sleep")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 0, "the latch cleared")
	_set_need(0, NeedsScript.NEED_REST, 2000)
	assert_equal(_resolve(0, 4, true), SLEEP, "recovery to 2000 keeps the resident asleep")


func test_the_sleep_exception_applies_to_the_night_shift_window_too() -> void:
	"""The exception is about the scheduled SLEEP block, not about a particular clock hour."""
	_spawn(0, ScheduleScript.TEMPLATE_NIGHT_SHIFT_KEY)
	_set_need(0, NeedsScript.NEED_REST, 9000)
	assert_equal(_resolve(0, 12, true), ANYTHING, "12:00 is a night-shift sleep hour")
	assert_equal(_resolve(0, 20, true), WORK, "20:00 is a night-shift work hour")
	assert_equal(_schedule.sleep_satisfied_of(0).value, 0, "the latch cleared at the work hour")


# --- resolution refusals ------------------------------------------------------------------------

func test_resolve_refuses_a_dead_resident() -> void:
	"""§4.3 numbers no activity for a corpse; REQ-SET-016 replaces them with a burial job."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_equal(_resolve(0, 9, true), WORK, "alive and working")
	assert_true(_needs.apply_health_event(0, -100).ok, "kill the resident")
	var result: IntMath.IntResult = _schedule.resolve(0, 9, true)
	assert_false(result.ok, "resolving a dead resident must refuse")
	assert_equal(result.error, "RESIDENT_DEAD", "explicit refusal code")
	assert_equal(_schedule.current_activity_of(0).value, WORK, "the last resolved value is intact")


func test_resolve_refuses_an_incapacitated_resident() -> void:
	"""§5.2 puts INCAPACITATED at health 1-15; REQ-SET-023 creates a rescue job instead of a
	schedule, and inventing an Activity for an unconscious resident would be inventing a rule."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_true(_needs.apply_health_event(0, -90).ok, "drop health to 10")
	assert_equal(_needs.status_of(0).value, NeedsScript.STATUS_INCAPACITATED, "incapacitated")
	var result: IntMath.IntResult = _schedule.resolve(0, 9, true)
	assert_false(result.ok, "resolving an incapacitated resident must refuse")
	assert_equal(result.error, "RESIDENT_INCAPACITATED", "explicit refusal code")


func test_resolve_refuses_a_row_with_no_needs_and_an_invalid_hour() -> void:
	"""A schedule row without its needs row cannot be resolved; nor can hour 24."""
	assert_true(_schedule.spawn(0, _template(ScheduleScript.TEMPLATE_DEFAULT_KEY)).ok, "schedule only")
	var no_needs: IntMath.IntResult = _schedule.resolve(0, 9, true)
	assert_false(no_needs.ok, "no needs row must refuse")
	assert_equal(no_needs.error, "NEEDS_ROW_UNAVAILABLE", "explicit refusal code")
	_spawn(1, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	assert_false(_schedule.resolve(1, 24, true).ok, "hour 24 must refuse")
	assert_false(_schedule.resolve(1, -1, true).ok, "hour -1 must refuse")


func test_resolve_into_reports_failure_without_allocating_a_result() -> void:
	"""The non-allocating form returns false and refuses into the caller's own IntResult."""
	_spawn(0, ScheduleScript.TEMPLATE_DEFAULT_KEY)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_schedule.resolve_into(0, 9, true, out), "a valid resolve returns true")
	assert_equal(out.value, WORK, "the value lands in the caller's object")
	assert_false(_schedule.resolve_into(0, 99, true, out), "an invalid hour returns false")
	assert_false(out.ok, "the caller's object carries the refusal")
	assert_equal(out.value, 0, "a refusal zeroes the value rather than leaving the stale WORK")


# --- catalog agreement -------------------------------------------------------------------------

func test_activity_constants_come_from_the_protected_catalog_table() -> void:
	"""Decision 0018: there is one copy of every §4.3 number, and it lives in catalog.gd."""
	var activity: Dictionary = CatalogScript.fixed_enum("Activity")
	assert_equal(ScheduleScript.ACTIVITY_SLEEP, activity["SLEEP"], "SLEEP")
	assert_equal(ScheduleScript.ACTIVITY_ANYTHING, activity["ANYTHING"], "ANYTHING")
	assert_equal(ScheduleScript.ACTIVITY_WORK, activity["WORK"], "WORK")
	assert_equal(ScheduleScript.ACTIVITY_SOCIAL, activity["SOCIAL"], "SOCIAL")
	assert_equal(ScheduleScript.ACTIVITY_COUNT, activity.size(), "four activities")


func test_the_rest_thresholds_are_the_specified_ones() -> void:
	"""9000 is §5.3's sleep-exception threshold; 500 is §5.2's collapse threshold. Different
	numbers from different sentences, and neither is derived from the other."""
	assert_equal(ScheduleScript.REST_SLEEP_SATISFIED_THRESHOLD, 9000, "§5.3 sleep exception")
	assert_equal(NeedsScript.REST_COLLAPSE_THRESHOLD, 500, "§5.2 collapse")
	assert_equal(NeedsScript.HUNGER_EAT_THRESHOLD, 3500, "§5.2 eat threshold")
	assert_equal(NeedsScript.HUNGER_URGENT_THRESHOLD, 1500, "§5.2 urgent threshold")
