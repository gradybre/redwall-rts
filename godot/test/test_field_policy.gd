extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/field_policy.gd`: GDD §4.2's `FieldPolicy` row and R06-JOB-005's
## rotation advance.
##
## THE RULING'S THREE NAMED FAILURE MODES ARE THE TEST LIST. Every one has a named method here:
## a mixed-duration field advances EXACTLY ONCE; a blocked entry is NOT skipped and no crop is
## substituted; erasing a tile is NOT a successful harvest and an explicitly cancelled cycle
## records a cancellation rather than a fabricated completion. Alongside them: `auto_rotation`
## false never reseeds, a future legal window retains the request, a missed one warns and waits,
## §4.2's four defaults, and REQ-SET-088's seed-reserve gate refusing rather than fabricating.
##
## THE CONSTANTS ARE TRANSCRIBED FROM THE DOCUMENTS, not read back out of the module. The crop
## ids are §4.3's ASCII ordering (beans 0, cabbage 1, flax 2, grain 3, roots 4), the planting
## windows are §5.6's own table, the seed cost is BAL-CROP-001's 250 milli-U/tile, and the day
## arithmetic is §5.1's OFFSET calendar -- the first midnight is tick 13500, written here as a
## literal, so a module that switched to `tick % 18000` would fail rather than agree with itself.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FieldPolicyScript := preload("res://scripts/core/field_policy.gd")

## §5.1's offset calendar: tick 0 is 06:00 of day 1 and the FIRST MIDNIGHT is tick 13500.
const FIRST_MIDNIGHT_TICK: int = 13500
const TICKS_PER_DAY: int = 18000
## §4.3's crop ids in ASCII order.
const BEANS: int = 0
const CABBAGE: int = 1
const FLAX: int = 2
const GRAIN: int = 3
const ROOTS: int = 4
## §4.2: "empty catalog IDs are -1".
const NO_CROP: int = -1
## §4.3 ZoneType, transcribed: FISH 0, RESERVED_1 1, FORAGE 2, FARM 3, ORCHARD 4.
const ZONE_FARM: int = 3
const ZONE_FORAGE: int = 2
## §5.6's soils, transcribed: LOAM 0, CLAY 1, SAND 2.
const LOAM: int = 0
## BAL-CROP-001: 250 milli-U of seed per tile, for every crop in §5.6's table.
const SEED_MILLI_PER_TILE: int = 250
## jobs.gd's §4.2 gate values: 0 not required, 1 satisfied, 3 declared but unanswerable.
const GATE_NOT_REQUIRED: int = 0
const GATE_SATISFIED: int = 1
const GATE_UNAVAILABLE: int = 3
## field_policy.gd's own domains, transcribed so a renumbering fails here.
const CYCLE_IDLE: int = 0
const CYCLE_OPEN: int = 1
const CYCLE_CLOSED: int = 2
const CLOSE_NONE: int = 0
const CLOSE_COMPLETED: int = 1
const CLOSE_CANCELLED: int = 2
const CLOSE_ABANDONED: int = 3
const OUTCOME_UNRESOLVED: int = 0
const OUTCOME_HARVESTED: int = 1
const OUTCOME_CLEARED: int = 2
const OUTCOME_WITHDRAWN: int = 3
const REQUEST_NONE: int = 0
const REQUEST_READY: int = 1
const REQUEST_WINDOW_FUTURE: int = 2
const REQUEST_WINDOW_MISSED: int = 3
const REQUEST_ENTRY_NOT_CONFIGURED: int = 4
const REQUEST_NO_LEGAL_WINDOW: int = 5

var _farming: FarmingScript = null
var _forage: ForageScript = null
var _policy: FieldPolicyScript = null
var _zone: Vector2i = Vector2i(-1, 0)
var _field: int = -1


func before_each() -> void:
	"""Build a farm store, a zone store sharing its directory, and one FARM-zone policy."""
	_farming = FarmingScript.new()
	_forage = ForageScript.new(_farming.directory())
	_policy = FieldPolicyScript.new(_farming, _forage)
	_zone = _farm_zone()
	var created: FieldPolicyScript.OpResult = _policy.create_policy(_zone)
	assert_true(created.ok, "the policy binds to its FARM zone (error: %s)" % created.error)
	_field = created.value


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_policy = null
	_forage = null
	_farming = null


# --- fixtures ------------------------------------------------------------------------------------

func _farm_zone() -> Vector2i:
	"""Designate one live FARM-type HarvestZone and return its EntityRef."""
	var created: ForageScript.OpResult = _forage.create_zone(ZONE_FARM, 0, 0, false, true)
	assert_true(created.ok, "the FARM zone designates (error: %s)" % created.error)
	return created.ref


func _plot(tile: int) -> int:
	"""Create one loam FarmPlot on a tile and return its typed row."""
	var created: FarmingScript.OpResult = _farming.create_plot_at_tile(tile, LOAM, 1)
	assert_true(created.ok, "the plot creates (error: %s)" % created.error)
	return created.value


func _day_tick(day: int) -> int:
	"""First tick of an absolute day under §5.1's offset calendar, computed from the GDD."""
	if day <= 1:
		return 0
	return FIRST_MIDNIGHT_TICK + (day - 2) * TICKS_PER_DAY


func _spring_day(season_day: int) -> int:
	"""A tick inside spring's season-local day. Spring days 1..12 are absolute days 1..12."""
	return _day_tick(season_day)


func _autumn_day(season_day: int) -> int:
	"""A tick inside autumn's season-local day. Autumn day 1 is absolute day 25."""
	return _day_tick(24 + season_day)


func _open_with_plots(tiles: Array[int]) -> Array[int]:
	"""Open a cycle and enrol one fresh plot per tile. Returns the enrolled plot rows."""
	assert_true(_policy.open_cycle(_zone).ok, "the cycle opens")
	var slots: Array[int] = []
	for tile: int in tiles:
		var slot: int = _plot(tile)
		var enrolled: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, slot)
		assert_true(enrolled.ok, "the plot enrols (error: %s)" % enrolled.error)
		slots.append(slot)
	return slots


func _enable_auto() -> void:
	"""Turn on §4.2's `auto_rotation`, which is false by default."""
	assert_true(_policy.set_auto_rotation(_zone, true).ok, "auto rotation enables")


func _cursor() -> int:
	"""§4.2's `rotation_cursor` for the fixture field, asserting the row answers."""
	var out: IntMath.IntResult = _policy.rotation_cursor_of(_field)
	assert_true(out.ok, "the cursor reads (error: %s)" % out.error)
	return out.value


func _request_state() -> int:
	"""The fixture field's request state, asserting the row answers."""
	var out: IntMath.IntResult = _policy.request_state_of(_field)
	assert_true(out.ok, "the request state reads (error: %s)" % out.error)
	return out.value


func _requested_crop() -> int:
	"""The fixture field's retained requested crop, asserting the row answers."""
	var out: IntMath.IntResult = _policy.requested_crop_of(_field)
	assert_true(out.ok, "the requested crop reads (error: %s)" % out.error)
	return out.value


func _close_reason() -> int:
	"""How the fixture field's last cycle closed, asserting the row answers."""
	var out: IntMath.IntResult = _policy.close_reason_of(_field)
	assert_true(out.ok, "the close reason reads (error: %s)" % out.error)
	return out.value


func _cycle_state() -> int:
	"""The fixture field's cycle state, asserting the row answers."""
	var out: IntMath.IntResult = _policy.cycle_state_of(_field)
	assert_true(out.ok, "the cycle state reads (error: %s)" % out.error)
	return out.value


# --- §4.2's four defaults --------------------------------------------------------------------------

func test_a_new_policy_carries_the_default_grain_beans_roots_rotation() -> void:
	"""§4.2 and §5.6: "default cycle grain->beans->roots", in that order."""
	var first: IntMath.IntResult = _policy.rotation_id_of(_field, 0)
	var second: IntMath.IntResult = _policy.rotation_id_of(_field, 1)
	var third: IntMath.IntResult = _policy.rotation_id_of(_field, 2)
	assert_true(first.ok and second.ok and third.ok, "all three entries read")
	assert_equal(first.value, GRAIN, "entry 0 is grain")
	assert_equal(second.value, BEANS, "entry 1 is beans")
	assert_equal(third.value, ROOTS, "entry 2 is roots")


func test_a_new_policy_starts_at_rotation_cursor_zero() -> void:
	"""§4.2 and the ruling: "cursor 0"."""
	assert_equal(_cursor(), 0, "a new policy's cursor is 0")


func test_a_new_policy_has_auto_rotation_off() -> void:
	"""§4.2 and the ruling: "auto false". This default is what makes an edit start no work."""
	assert_false(_policy.is_auto_rotation(_field), "auto_rotation defaults false")


func test_a_new_policy_has_the_seed_reserve_on() -> void:
	"""§4.2 and the ruling: "reserve true"."""
	assert_true(_policy.is_seed_reserve(_field), "seed_reserve defaults true")


func test_a_new_policy_is_idle_with_no_cycle_and_no_request() -> void:
	"""A policy that has never planted holds no cycle, no close reason and no request."""
	assert_equal(_cycle_state(), CYCLE_IDLE, "a new policy is idle")
	assert_equal(_close_reason(), CLOSE_NONE, "no cycle has closed")
	assert_equal(_request_state(), REQUEST_NONE, "no request stands")
	assert_equal(_requested_crop(), NO_CROP, "no crop is requested")
	var ordinal: IntMath.IntResult = _policy.cycle_ordinal_of(_field)
	assert_true(ordinal.ok, "the ordinal reads")
	assert_equal(ordinal.value, FieldPolicyScript.NO_CYCLE, "the ordinal is NO_CYCLE")


# --- R06-JOB-005: a mixed-duration field advances EXACTLY ONCE --------------------------------------

func test_a_mixed_duration_field_advances_its_cursor_exactly_once() -> void:
	"""The ruling: advancement "waits for all participating plots in the current cycle to resolve,
	preventing fast tiles from advancing the entire field repeatedly"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([10, 11, 12])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(5)).ok, "the fast plot resolves")
	assert_equal(_cursor(), 0, "the fast plot advances nothing")
	assert_equal(_policy.advance_count(), 0, "no advance has run yet")
	assert_true(_policy.record_plot_resolved(_zone, plots[1], OUTCOME_HARVESTED,
		_spring_day(9)).ok, "the middle plot resolves")
	assert_equal(_cursor(), 0, "two of three still advances nothing")
	assert_equal(_cycle_state(), CYCLE_OPEN, "the cycle is still open")
	assert_true(_policy.record_plot_resolved(_zone, plots[2], OUTCOME_HARVESTED,
		_spring_day(12)).ok, "the slow plot resolves")
	assert_equal(_cursor(), 1, "the last resolution advances the cursor by exactly one")
	assert_equal(_policy.advance_count(), 1, "exactly one advance ran for the whole field")
	assert_equal(_cycle_state(), CYCLE_CLOSED, "the cycle closed")
	assert_equal(_close_reason(), CLOSE_COMPLETED, "it closed as completed")


func test_a_resolution_after_the_cycle_closed_cannot_advance_again() -> void:
	"""Guard two: every resolution entry point requires an OPEN cycle."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([20, 21])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the first plot resolves")
	assert_true(_policy.record_plot_resolved(_zone, plots[1], OUTCOME_HARVESTED, 0).ok,
		"the second plot resolves and closes the cycle")
	assert_equal(_policy.advance_count(), 1, "one advance so far")
	var again: FieldPolicyScript.OpResult = _policy.record_plot_resolved(_zone, plots[0],
		OUTCOME_HARVESTED, 0)
	assert_false(again.ok, "a resolution after the close refuses")
	assert_equal(again.error, &"NO_OPEN_FIELD_CYCLE", "it names the closed cycle")
	assert_equal(_policy.advance_count(), 1, "still exactly one advance")
	assert_equal(_cursor(), 1, "the cursor did not move a second time")


func test_the_same_plot_cannot_resolve_twice_inside_one_cycle() -> void:
	"""Guard three: one plot cannot be counted twice, which is "advancing once per tile"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([30, 31, 32])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the fast plot resolves")
	for attempt: int in 4:
		var repeat: FieldPolicyScript.OpResult = _policy.record_plot_resolved(_zone, plots[0],
			OUTCOME_HARVESTED, 0)
		assert_false(repeat.ok, "repeat %d refuses" % attempt)
		assert_equal(repeat.error, &"PLOT_ALREADY_RESOLVED", "it names the recorded outcome")
	var resolved: IntMath.IntResult = _policy.resolved_count_of(_field)
	assert_true(resolved.ok, "the resolved count reads")
	assert_equal(resolved.value, 1, "four repeats added no resolutions")
	assert_equal(_cursor(), 0, "and advanced nothing")
	assert_equal(_policy.advance_count(), 0, "no advance ran")


func test_a_plot_enrolled_after_others_resolved_holds_the_cycle_open() -> void:
	"""Enrolling into an open cycle raises the participating set the advance must wait for."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([40])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the only enrolled plot resolves and closes the cycle")
	assert_equal(_policy.advance_count(), 1, "that cycle advanced once")
	assert_true(_policy.open_cycle(_zone).ok, "a second cycle opens")
	var late: int = _plot(41)
	assert_true(_policy.enrol_plot(_zone, late).ok, "a plot enrols into the second cycle")
	var extra: int = _plot(42)
	assert_true(_policy.record_plot_resolved(_zone, late, OUTCOME_CLEARED, 0).ok,
		"the enrolled plot clears")
	assert_equal(_policy.advance_count(), 2, "the second cycle advanced once too")
	assert_false(_policy.enrol_plot(_zone, extra).ok, "the closed cycle takes no enrolment")


func test_a_cleared_withered_plot_counts_as_a_resolution() -> void:
	"""The ruling says "finished harvesting/CLEARING", so REQ-SET-085's clearing resolves too."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([50, 51])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"one plot harvests")
	assert_true(_policy.record_plot_resolved(_zone, plots[1], OUTCOME_CLEARED, 0).ok,
		"the other clears")
	assert_equal(_close_reason(), CLOSE_COMPLETED, "the mixed cycle completed")
	assert_equal(_policy.advance_count(), 1, "and advanced exactly once")


# --- R06-JOB-005: no skipping and no substitution ----------------------------------------------------

func test_the_advance_requests_the_next_configured_crop_and_no_other() -> void:
	""""advance its cursor once and request the next configured crop"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([60])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(7)).ok, "the field completes in beans' spring window")
	assert_equal(_cursor(), 1, "the cursor moved from grain to beans")
	assert_equal(_requested_crop(), BEANS, "beans is requested -- entry 1, not a substitute")
	assert_equal(_request_state(), REQUEST_READY, "spring day 7 admits beans")


func test_a_blocked_rotation_entry_is_not_skipped_and_no_crop_is_substituted() -> void:
	"""The ruling: it shall not "skip blocked entries, or substitute a crop". §5.6: a blocked
	planting "does not choose a different seed without the player's rotation rule"."""
	assert_true(_policy.set_rotation(_zone, GRAIN, NO_CROP, ROOTS, 0).ok,
		"the player leaves entry 1 unconfigured")
	_enable_auto()
	var plots: Array[int] = _open_with_plots([70])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the field completes")
	assert_equal(_cursor(), 1, "the cursor advanced exactly one step, onto the blocked entry")
	assert_equal(_requested_crop(), NO_CROP, "no crop was substituted for the blocked entry")
	assert_equal(_request_state(), REQUEST_ENTRY_NOT_CONFIGURED, "the blocked reason is recorded")
	assert_equal(_policy.blocked_reason_of(_field), &"ROTATION_ENTRY_NOT_CONFIGURED",
		"REQ-SET-077 shows the blocked reason")


func test_a_blocked_entry_does_not_advance_onward_to_the_next_configured_crop() -> void:
	"""The cursor STAYS on the blocked entry: skipping to entry 2 would be skipping a blocked
	entry, and roots is what a skip would have chosen."""
	assert_true(_policy.set_rotation(_zone, GRAIN, NO_CROP, ROOTS, 0).ok, "entry 1 is blocked")
	_enable_auto()
	var plots: Array[int] = _open_with_plots([80])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the field completes")
	assert_true(_cursor() != 2, "the cursor did not skip onward to entry 2")
	assert_true(_requested_crop() != ROOTS, "roots was not substituted")
	assert_true(_requested_crop() != GRAIN, "and neither was the crop just harvested")
	assert_equal(_policy.advance_count(), 1, "exactly one advance still ran")


func test_the_cursor_wraps_from_the_third_entry_back_to_the_first() -> void:
	"""§5.6 calls the rotation "an explicit three-entry cycle", so the cursor wraps modulo three."""
	_enable_auto()
	assert_true(_policy.set_rotation_cursor(_zone, 2, 0).ok, "the cursor starts on entry 2")
	var plots: Array[int] = _open_with_plots([90])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(2)).ok, "the field completes")
	assert_equal(_cursor(), 0, "entry 2 advances to entry 0")
	assert_equal(_requested_crop(), GRAIN, "which is grain, the first configured entry")


func test_three_completed_cycles_walk_the_whole_rotation_in_order() -> void:
	"""Each completed cycle moves the cursor one step: grain -> beans -> roots -> grain."""
	_enable_auto()
	var expected: Array[int] = [BEANS, ROOTS, GRAIN]
	for index: int in 3:
		var plots: Array[int] = _open_with_plots([100 + index])
		assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
			_spring_day(1)).ok, "cycle %d completes" % index)
		assert_equal(_requested_crop(), expected[index],
			"cycle %d requests the next configured entry" % index)
	assert_equal(_policy.advance_count(), 3, "three completed cycles produced three advances")
	assert_equal(_cursor(), 0, "and the cursor is back on grain")


# --- R06-JOB-005: the window, retained and missed ----------------------------------------------------

func test_a_future_legal_window_retains_the_request() -> void:
	"""The ruling: "If its legal window is future, retain the request". §5.6 gives beans
	spring 5-10, so a completion on spring day 1 is ahead of it."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([110])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "the field completes on spring day 1")
	assert_equal(_request_state(), REQUEST_WINDOW_FUTURE, "the window is ahead")
	assert_equal(_requested_crop(), BEANS, "and the request is RETAINED, not dropped")
	assert_equal(_policy.blocked_reason_of(_field), &"PLANT_WINDOW_IS_FUTURE",
		"REQ-SET-077 shows why it is waiting")
	assert_equal(_policy.retained_request_count(), 1, "one request was retained")


func test_a_missed_window_warns_and_waits() -> void:
	"""The ruling: "if missed, show the existing warning and wait for its next legal window or a
	player edit". Beans' last window ends on summer day 3, so autumn day 1 has missed it."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([120])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_autumn_day(1)).ok, "the field completes on autumn day 1")
	assert_equal(_request_state(), REQUEST_WINDOW_MISSED, "the window is behind")
	assert_equal(_requested_crop(), BEANS, "the request is still retained, waiting")
	assert_equal(_policy.blocked_reason_of(_field), &"PLANT_WINDOW_MISSED",
		"REQ-SET-077 shows the missed-window warning")
	assert_equal(_policy.missed_request_count(), 1, "one missed request was recorded")
	assert_equal(_cursor(), 1, "and the cursor stayed on the missed entry")


func test_a_missed_window_is_not_replaced_by_a_crop_that_is_in_season() -> void:
	"""Cabbage is legal on autumn day 1 and beans is not; the module must still request beans."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([130])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_autumn_day(1)).ok, "the field completes on autumn day 1")
	assert_true(_requested_crop() != CABBAGE, "the in-season crop was not substituted")
	assert_equal(_requested_crop(), BEANS, "the player's own entry is what is requested")


func test_a_player_edit_resolves_a_missed_window_without_starting_work() -> void:
	"""The ruling's second way out: "wait for its next legal window OR A PLAYER EDIT"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([140])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_autumn_day(1)).ok, "the field completes on autumn day 1")
	assert_equal(_request_state(), REQUEST_WINDOW_MISSED, "beans has missed its window")
	assert_true(_policy.set_rotation(_zone, GRAIN, CABBAGE, ROOTS, _autumn_day(1)).ok,
		"the player edits entry 1 to cabbage")
	assert_equal(_requested_crop(), CABBAGE, "the request now names the edited entry")
	assert_equal(_request_state(), REQUEST_READY, "autumn day 1 admits cabbage")
	assert_equal(_cursor(), 1, "the edit did not move the cursor")
	assert_equal(_cycle_state(), CYCLE_CLOSED, "and the edit opened no cycle")
	assert_equal(_policy.opened_cycle_count(), 1, "no work was started")


func test_a_rotation_edit_creates_no_request_where_none_stood() -> void:
	"""The ruling: "Changing a rotation list without confirming planting shall not start work"."""
	assert_equal(_request_state(), REQUEST_NONE, "a new policy holds no request")
	assert_true(_policy.set_rotation(_zone, FLAX, CABBAGE, ROOTS, _spring_day(3)).ok,
		"the player edits the whole list")
	assert_equal(_request_state(), REQUEST_NONE, "the edit created no request")
	assert_equal(_requested_crop(), NO_CROP, "and requested no crop")
	assert_equal(_policy.opened_cycle_count(), 0, "and opened no cycle")
	assert_equal(_policy.advance_count(), 0, "and advanced nothing")


func test_a_cursor_edit_re_evaluates_an_outstanding_request() -> void:
	"""Moving the cursor is a player edit too, and it re-reads the entry it now points at."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([150])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "the field completes; beans is retained as future")
	assert_equal(_requested_crop(), BEANS, "beans is requested")
	assert_true(_policy.set_rotation_cursor(_zone, 0, _spring_day(1)).ok,
		"the player points the cursor back at grain")
	assert_equal(_requested_crop(), GRAIN, "the request follows the player's own cursor")
	assert_equal(_request_state(), REQUEST_READY, "spring day 1 admits grain")
	assert_equal(_policy.advance_count(), 1, "the edit is not an advance")


func test_opening_the_next_cycle_consumes_the_retained_request() -> void:
	"""A request is retained until the field acts on it; opening the cycle is that act."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([160])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "the field completes")
	assert_equal(_requested_crop(), BEANS, "beans is retained")
	assert_true(_policy.open_cycle(_zone).ok, "the next cycle opens")
	assert_equal(_request_state(), REQUEST_NONE, "the request is consumed")
	assert_equal(_requested_crop(), NO_CROP, "and no crop is left outstanding")


func test_a_crop_naming_no_legal_day_reports_its_own_blocked_reason() -> void:
	"""The defensive fourth answer, unreachable through §5.6's table: a crop with no legal day is
	NOT reported as a missed window, because "wait for its next legal window" would be a lie."""
	var windowless: WindowlessFarming = WindowlessFarming.new()
	var forage: ForageScript = ForageScript.new(windowless.directory())
	var policy: FieldPolicyScript = FieldPolicyScript.new(windowless, forage)
	var zone: ForageScript.OpResult = forage.create_zone(ZONE_FARM, 0, 0, false, true)
	assert_true(zone.ok, "the FARM zone designates")
	var field: FieldPolicyScript.OpResult = policy.create_policy(zone.ref)
	assert_true(field.ok, "the policy binds")
	assert_true(policy.set_auto_rotation(zone.ref, true).ok, "auto rotation enables")
	assert_true(policy.open_cycle(zone.ref).ok, "a cycle opens")
	var plot: FarmingScript.OpResult = windowless.create_plot_at_tile(3, LOAM, 1)
	assert_true(plot.ok, "the plot creates")
	assert_true(policy.enrol_plot(zone.ref, plot.value).ok, "the plot enrols")
	assert_true(policy.record_plot_resolved(zone.ref, plot.value, OUTCOME_HARVESTED, 0).ok,
		"the field completes")
	var state: IntMath.IntResult = policy.request_state_of(field.value)
	assert_true(state.ok, "the request state reads")
	assert_equal(state.value, REQUEST_NO_LEGAL_WINDOW, "no legal day is its own answer")
	assert_equal(policy.blocked_reason_of(field.value), &"CROP_HAS_NO_LEGAL_WINDOW",
		"and REQ-SET-077 shows it")


# --- R06-JOB-005: auto_rotation = false ---------------------------------------------------------------

func test_auto_rotation_off_never_requests_another_sowing_cycle() -> void:
	"""The ruling: "With auto_rotation=false, completion shall not request another sowing cycle"."""
	assert_false(_policy.is_auto_rotation(_field), "auto rotation is off by default")
	var plots: Array[int] = _open_with_plots([170, 171])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "one plot harvests")
	assert_true(_policy.record_plot_resolved(_zone, plots[1], OUTCOME_HARVESTED,
		_spring_day(3)).ok, "the other harvests and completes the cycle")
	assert_equal(_close_reason(), CLOSE_COMPLETED, "the cycle did complete")
	assert_equal(_cursor(), 0, "but the cursor did not advance")
	assert_equal(_request_state(), REQUEST_NONE, "no sowing cycle was requested")
	assert_equal(_requested_crop(), NO_CROP, "and no crop was named")
	assert_equal(_policy.advance_count(), 0, "no advance ran at all")


func test_ten_completed_cycles_with_auto_off_never_move_the_cursor() -> void:
	"""Repetition is the point: no number of completions reseeds a field with auto rotation off."""
	for index: int in 10:
		var plots: Array[int] = _open_with_plots([180 + index])
		assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
			"cycle %d completes" % index)
	assert_equal(_cursor(), 0, "ten completions moved the cursor nowhere")
	assert_equal(_policy.advance_count(), 0, "and produced no advance")
	var completed: IntMath.IntResult = _policy.completed_cycle_count_of(_field)
	assert_true(completed.ok, "the completion history reads")
	assert_equal(completed.value, 10, "while the completions themselves are all recorded")


func test_enabling_auto_rotation_does_not_retroactively_advance_a_closed_cycle() -> void:
	"""The gate is read at close time; enabling it afterwards starts nothing."""
	var plots: Array[int] = _open_with_plots([200])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the cycle completes with auto rotation off")
	assert_equal(_cursor(), 0, "nothing advanced")
	_enable_auto()
	assert_equal(_cursor(), 0, "and enabling it afterwards still advances nothing")
	assert_equal(_request_state(), REQUEST_NONE, "no request appeared")
	assert_equal(_policy.advance_count(), 0, "no advance ran")


# --- the ruling: erasing a tile is not a successful harvest -------------------------------------------

func test_erasing_a_tile_is_not_counted_as_a_harvest() -> void:
	"""The ruling: "Erasing a tile is not successful harvest"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([210, 211])
	assert_true(_policy.withdraw_plot(_zone, plots[0], 0).ok, "one tile is erased")
	var resolved: IntMath.IntResult = _policy.resolved_count_of(_field)
	assert_true(resolved.ok, "the resolved count reads")
	assert_equal(resolved.value, 0, "the erase resolved nothing")
	var withdrawn: IntMath.IntResult = _policy.withdrawn_count_of(_field)
	assert_true(withdrawn.ok, "the withdrawn count reads")
	assert_equal(withdrawn.value, 1, "it is recorded as a withdrawal instead")
	var outcome: IntMath.IntResult = _policy.plot_outcome_of(plots[0])
	assert_true(outcome.ok, "the plot outcome reads")
	assert_equal(outcome.value, OUTCOME_WITHDRAWN, "and not as a harvest")
	assert_equal(_cycle_state(), CYCLE_OPEN, "the surviving plot keeps the cycle open")
	assert_equal(_policy.advance_count(), 0, "so nothing advanced")


func test_erasing_every_tile_abandons_the_cycle_and_advances_nothing() -> void:
	"""A field whose every plot was erased never harvested, so it never completes and never
	advances. It closes ABANDONED rather than stalling forever -- decision 0045."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([220, 221])
	assert_true(_policy.withdraw_plot(_zone, plots[0], 0).ok, "the first tile is erased")
	assert_true(_policy.withdraw_plot(_zone, plots[1], 0).ok, "the second tile is erased")
	assert_equal(_cycle_state(), CYCLE_CLOSED, "the cycle closed")
	assert_equal(_close_reason(), CLOSE_ABANDONED, "as abandoned, not completed")
	assert_equal(_cursor(), 0, "the cursor did not advance")
	assert_equal(_policy.advance_count(), 0, "no advance ran")
	var completed: IntMath.IntResult = _policy.completed_cycle_count_of(_field)
	assert_true(completed.ok, "the completion history reads")
	assert_equal(completed.value, 0, "no completion was fabricated")
	assert_equal(_policy.abandoned_cycle_count(), 1, "the abandonment is counted")


func test_a_resolved_plot_cannot_then_be_withdrawn() -> void:
	"""A harvest that happened stays happened when its tile is erased afterwards. This is also
	what keeps resolved <= participants, and therefore what makes an empty field imply none
	resolved."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([230, 231])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the first plot harvests")
	var erased: FieldPolicyScript.OpResult = _policy.withdraw_plot(_zone, plots[0], 0)
	assert_false(erased.ok, "erasing the harvested plot refuses")
	assert_equal(erased.error, &"PLOT_ALREADY_RESOLVED", "it names the recorded outcome")
	var outcome: IntMath.IntResult = _policy.plot_outcome_of(plots[0])
	assert_true(outcome.ok, "the outcome reads")
	assert_equal(outcome.value, OUTCOME_HARVESTED, "and the harvest is still recorded")


func test_a_withdrawn_plot_cannot_then_be_recorded_as_harvested() -> void:
	"""An erased tile cannot be resolved back into a harvest by a second call."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([240, 241])
	assert_true(_policy.withdraw_plot(_zone, plots[0], 0).ok, "the tile is erased")
	var claimed: FieldPolicyScript.OpResult = _policy.record_plot_resolved(_zone, plots[0],
		OUTCOME_HARVESTED, 0)
	assert_false(claimed.ok, "claiming a harvest on it refuses")
	assert_equal(claimed.error, &"PLOT_WITHDRAWN",
		"with its OWN code -- an erasure is not a recorded harvest")
	var resolved: IntMath.IntResult = _policy.resolved_count_of(_field)
	assert_true(resolved.ok, "the resolved count reads")
	assert_equal(resolved.value, 0, "and no resolution was recorded")


func test_record_plot_resolved_refuses_the_withdrawn_outcome() -> void:
	"""`OUTCOME_WITHDRAWN` has its own entry point; it is not a resolution outcome."""
	var plots: Array[int] = _open_with_plots([250])
	var refused: FieldPolicyScript.OpResult = _policy.record_plot_resolved(_zone, plots[0],
		OUTCOME_WITHDRAWN, 0)
	assert_false(refused.ok, "a withdrawal cannot be recorded as a resolution")
	assert_equal(refused.error, &"INVALID_PLOT_OUTCOME", "the outcome domain refuses it")
	var unresolved: FieldPolicyScript.OpResult = _policy.record_plot_resolved(_zone, plots[0],
		OUTCOME_UNRESOLVED, 0)
	assert_false(unresolved.ok, "and neither is UNRESOLVED a resolution")


func test_erasing_the_last_unresolved_plot_completes_what_genuinely_resolved() -> void:
	"""With one genuine harvest and the rest erased, the surviving participating set is fully
	resolved, so the cycle completes. Decision 0045 records this as the stated interpretation."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([260, 261])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "one plot genuinely harvests")
	assert_true(_policy.withdraw_plot(_zone, plots[1], _spring_day(1)).ok,
		"the other tile is erased")
	assert_equal(_close_reason(), CLOSE_COMPLETED, "the surviving set fully resolved")
	assert_equal(_policy.advance_count(), 1, "and advanced exactly once")


# --- the ruling: an explicit cancellation is recorded, never a fabricated completion ------------------

func test_a_cancelled_cycle_records_a_cancellation_not_a_completion() -> void:
	"""The ruling: "explicitly cancelled unresolved cycles need a recorded cancellation rather
	than fabricated completion"."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([270, 271])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"one plot resolves")
	var cancelled: FieldPolicyScript.OpResult = _policy.cancel_cycle(_zone)
	assert_true(cancelled.ok, "the unresolved cycle cancels (error: %s)" % cancelled.error)
	assert_equal(_close_reason(), CLOSE_CANCELLED, "it closed as cancelled")
	var recorded: IntMath.IntResult = _policy.cancelled_cycle_count_of(_field)
	assert_true(recorded.ok, "the cancellation history reads")
	assert_equal(recorded.value, 1, "one cancellation is recorded")
	var completed: IntMath.IntResult = _policy.completed_cycle_count_of(_field)
	assert_true(completed.ok, "the completion history reads")
	assert_equal(completed.value, 0, "and no completion was fabricated")
	assert_equal(_cursor(), 0, "a cancelled cycle advances nothing")
	assert_equal(_policy.advance_count(), 0, "no advance ran")


func test_a_cancellation_needs_an_open_cycle() -> void:
	"""There is nothing to cancel on an idle or already closed field, and saying so is not a
	no-op: a caller cannot record a cancellation that never happened."""
	var idle: FieldPolicyScript.OpResult = _policy.cancel_cycle(_zone)
	assert_false(idle.ok, "an idle field cancels nothing")
	assert_equal(idle.error, &"NO_OPEN_FIELD_CYCLE", "it names the missing cycle")
	var plots: Array[int] = _open_with_plots([280])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the cycle completes")
	var closed: FieldPolicyScript.OpResult = _policy.cancel_cycle(_zone)
	assert_false(closed.ok, "a closed cycle cancels nothing either")
	var recorded: IntMath.IntResult = _policy.cancelled_cycle_count_of(_field)
	assert_true(recorded.ok, "the cancellation history reads")
	assert_equal(recorded.value, 0, "and no cancellation was recorded")


func test_cancellation_and_completion_histories_are_kept_separately() -> void:
	"""Both counters are durable and neither can be read back as the other."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([290])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the first cycle completes")
	assert_true(_policy.open_cycle(_zone).ok, "a second cycle opens")
	var late: int = _plot(291)
	assert_true(_policy.enrol_plot(_zone, late).ok, "a plot enrols")
	assert_true(_policy.cancel_cycle(_zone).ok, "the second cycle is cancelled")
	var completed: IntMath.IntResult = _policy.completed_cycle_count_of(_field)
	var cancelled: IntMath.IntResult = _policy.cancelled_cycle_count_of(_field)
	assert_true(completed.ok and cancelled.ok, "both histories read")
	assert_equal(completed.value, 1, "one completion")
	assert_equal(cancelled.value, 1, "one cancellation")
	assert_equal(_policy.advance_count(), 1, "and only the completion advanced")


# --- REQ-SET-088: the seed reserve gate refuses rather than fabricating -------------------------------

func test_the_seed_reserve_gate_is_unanswerable_while_the_reserve_is_on() -> void:
	"""REQ-SET-088 has no reservation path: every `reservations.gd` row is owned by a Job and a
	standing reserve has none. The gate must never read as satisfied."""
	var gate: IntMath.IntResult = _policy.seed_reserve_gate_of(_field)
	assert_true(gate.ok, "the gate answers")
	assert_equal(gate.value, GATE_UNAVAILABLE, "it declares the requirement unanswerable")
	assert_true(gate.value != GATE_SATISFIED, "and never fabricates a satisfied reserve")


func test_the_seed_reserve_gate_is_not_required_once_the_policy_is_off() -> void:
	"""With the policy off the field declares no such requirement -- which is not the same as
	saying the seed is reserved."""
	assert_true(_policy.set_seed_reserve(_zone, false).ok, "the reserve is turned off")
	var gate: IntMath.IntResult = _policy.seed_reserve_gate_of(_field)
	assert_true(gate.ok, "the gate answers")
	assert_equal(gate.value, GATE_NOT_REQUIRED, "no requirement is declared")
	assert_false(_policy.is_seed_reserve(_field), "and the column agrees")


func test_a_seed_release_refuses_while_the_reserve_is_enabled() -> void:
	"""REQ-SET-088 gates "seed export or nonplanting use" behind a reserve nothing can take."""
	var release: FieldPolicyScript.OpResult = _policy.authorise_seed_release(_zone)
	assert_false(release.ok, "the release refuses")
	assert_equal(release.error, &"SEED_RESERVE_UNANSWERABLE", "it names the unanswerable reserve")
	assert_equal(release.value, 0, "and carries no value an ignored refusal could use")


func test_a_seed_release_is_unconstrained_once_the_reserve_is_off() -> void:
	"""Turning the policy off removes the requirement this module gates on, and nothing else."""
	assert_true(_policy.set_seed_reserve(_zone, false).ok, "the reserve is turned off")
	var release: FieldPolicyScript.OpResult = _policy.authorise_seed_release(_zone)
	assert_true(release.ok, "this policy no longer objects (error: %s)" % release.error)
	assert_equal(release.value, GATE_NOT_REQUIRED, "and declares no requirement")


func test_the_seed_requirement_is_the_crops_own_per_tile_cost_times_the_tiles() -> void:
	"""BAL-CROP-001's 250 milli-U/tile, times a caller-supplied tile count. §5.6 caps a field
	designation at 256 tiles, so the largest honest answer is 64000 milli-U."""
	var eight: IntMath.IntResult = _policy.seed_requirement_milli_of(_field, 8)
	assert_true(eight.ok, "eight tiles answer (error: %s)" % eight.error)
	assert_equal(eight.value, SEED_MILLI_PER_TILE * 8, "8 tiles of grain need 2000 milli-U")
	var full: IntMath.IntResult = _policy.seed_requirement_milli_of(_field, 256)
	assert_true(full.ok, "a full field answers")
	assert_equal(full.value, SEED_MILLI_PER_TILE * 256, "256 tiles need 64000 milli-U")


func test_the_seed_requirement_follows_a_retained_request_rather_than_the_cursor() -> void:
	""""enough seed for the NEXT configured planting": once an advance has requested a crop, that
	is the next planting."""
	_enable_auto()
	assert_true(_policy.set_rotation(_zone, GRAIN, FLAX, ROOTS, 0).ok, "entry 1 becomes flax")
	var plots: Array[int] = _open_with_plots([300])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(2)).ok, "the field completes")
	var crop: IntMath.IntResult = _policy.next_planting_crop_of(_field)
	assert_true(crop.ok, "the next planting crop reads")
	assert_equal(crop.value, FLAX, "which is the retained request, not the old cursor entry")
	var need: IntMath.IntResult = _policy.seed_requirement_milli_of(_field, 4)
	assert_true(need.ok, "the requirement answers")
	assert_equal(need.value, SEED_MILLI_PER_TILE * 4, "flax costs the same 250 milli-U/tile")


func test_the_seed_requirement_refuses_a_negative_tile_count_and_an_overflow() -> void:
	"""Neither wraps and neither clamps: an impossible question is refused."""
	var negative: IntMath.IntResult = _policy.seed_requirement_milli_of(_field, -1)
	assert_false(negative.ok, "a negative tile count refuses")
	assert_equal(negative.value, 0, "and carries no number")
	var huge: IntMath.IntResult = _policy.seed_requirement_milli_of(_field,
		IntMath.INT64_MAX)
	assert_false(huge.ok, "an overflowing product refuses")
	assert_equal(huge.error, "OVERFLOW", "with the overflow code, never a wrapped value")


func test_the_seed_requirement_refuses_an_unconfigured_rotation_entry() -> void:
	"""An entry that names no crop has no seed cost, and saying zero would be a fabrication."""
	assert_true(_policy.set_rotation(_zone, NO_CROP, BEANS, ROOTS, 0).ok, "entry 0 is cleared")
	var need: IntMath.IntResult = _policy.seed_requirement_milli_of(_field, 4)
	assert_false(need.ok, "the requirement refuses")
	assert_equal(need.error, "INVALID_CROP", "because no crop is configured")


# --- creation, binding and destruction ---------------------------------------------------------------

func test_a_policy_binds_only_to_a_farm_type_zone() -> void:
	"""§4.2: `FieldPolicy.zone` is an EntityRef to a FARM-type zone."""
	var forage_zone: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, 0, 0, false, true)
	assert_true(forage_zone.ok, "a FORAGE zone designates")
	var refused: FieldPolicyScript.OpResult = _policy.create_policy(forage_zone.ref)
	assert_false(refused.ok, "a FORAGE zone takes no field policy")
	assert_equal(refused.error, &"ZONE_TYPE_MISMATCH", "it names the mismatch")


func test_a_policy_refuses_a_reference_that_names_no_live_zone() -> void:
	"""Both halves of the EntityRef are validated through the directory."""
	var refused: FieldPolicyScript.OpResult = _policy.create_policy(Vector2i(9999, 3))
	assert_false(refused.ok, "a stale reference binds nothing")
	assert_equal(refused.error, &"ZONE_NOT_PRESENT", "it names the missing zone")


func test_a_second_policy_on_the_same_live_zone_refuses() -> void:
	"""§4.2: "One per FARM zone"."""
	var again: FieldPolicyScript.OpResult = _policy.create_policy(_zone)
	assert_false(again.ok, "the second binding refuses")
	assert_equal(again.error, &"FIELD_POLICY_EXISTS", "it names the existing policy")
	assert_equal(_policy.policy_count(), 1, "and the store still holds one policy")


func test_a_row_whose_zone_was_destroyed_is_reclaimed_by_the_next_zone() -> void:
	"""A destroyed FARM zone must not block its row forever, and the new policy must not inherit
	the old one's edits."""
	assert_true(_policy.set_auto_rotation(_zone, true).ok, "the old policy enables auto rotation")
	assert_true(_forage.destroy_zone(_zone).ok, "the zone is destroyed")
	assert_false(_policy.zone_is_live(_field), "the policy's zone no longer resolves")
	var replacement: Vector2i = _farm_zone()
	var rebound: FieldPolicyScript.OpResult = _policy.create_policy(replacement)
	assert_true(rebound.ok, "a new policy binds (error: %s)" % rebound.error)
	assert_equal(_policy.policy_count(), 1, "the store still holds exactly one policy")
	assert_false(_policy.is_auto_rotation(rebound.value),
		"the replacement carries the default, not the destroyed policy's edit")


func test_an_enrolment_does_not_survive_its_policy_row_being_rebound() -> void:
	"""The cycle ordinal is never reset, so every stamp written under the old policy is already
	stale for whatever binds to the row next."""
	var plots: Array[int] = _open_with_plots([310])
	assert_true(_policy.is_plot_enrolled(plots[0]), "the plot is enrolled")
	assert_true(_forage.destroy_zone(_zone).ok, "the zone is destroyed")
	var replacement: Vector2i = _farm_zone()
	assert_true(_policy.create_policy(replacement).ok, "a new policy binds to the same row")
	assert_false(_policy.is_plot_enrolled(plots[0]), "the old enrolment is stale")


func test_destroy_policy_retires_the_row_and_its_open_cycle() -> void:
	"""Retiring a policy leaves no cycle behind for the next binding to inherit."""
	var plots: Array[int] = _open_with_plots([320])
	var destroyed: FieldPolicyScript.OpResult = _policy.destroy_policy(_zone)
	assert_true(destroyed.ok, "the policy retires (error: %s)" % destroyed.error)
	assert_false(_policy.is_present(_field), "the row holds no policy")
	assert_equal(_policy.policy_count(), 0, "and the count agrees")
	assert_false(_policy.is_plot_enrolled(plots[0]), "the enrolment is gone with it")
	var again: FieldPolicyScript.OpResult = _policy.destroy_policy(_zone)
	assert_false(again.ok, "retiring it twice refuses")


func test_field_slot_of_resolves_a_live_policy_and_refuses_anything_else() -> void:
	"""The public row lookup validates the zone reference and the policy together."""
	var found: IntMath.IntResult = _policy.field_slot_of(_zone)
	assert_true(found.ok, "the live policy resolves")
	assert_equal(found.value, _field, "to its own row")
	var other: Vector2i = _farm_zone()
	var missing: IntMath.IntResult = _policy.field_slot_of(other)
	assert_false(missing.ok, "a FARM zone with no policy refuses")
	assert_equal(missing.error, "NO_FIELD_POLICY", "and names the missing policy")


func test_the_zone_reference_reader_answers_the_null_reference_for_an_empty_row() -> void:
	"""§4.1's null reference `(-1, 0)` is an explicit absence, checked, never a plausible row."""
	assert_equal(_policy.zone_ref_of(_field), _zone, "a live policy answers its zone")
	assert_equal(_policy.zone_ref_of(_field + 1), EntityDirectory.NULL_REF,
		"an empty row answers the null reference")
	assert_equal(_policy.zone_ref_of(-1), EntityDirectory.NULL_REF, "and so does a bad row")


# --- the cycle's own gates ---------------------------------------------------------------------------

func test_a_second_open_while_a_cycle_runs_refuses() -> void:
	"""A caller cannot silently discard an unresolved cycle; cancel_cycle() records that instead."""
	assert_true(_policy.open_cycle(_zone).ok, "the first cycle opens")
	var again: FieldPolicyScript.OpResult = _policy.open_cycle(_zone)
	assert_false(again.ok, "a second open refuses")
	assert_equal(again.error, &"FIELD_CYCLE_ALREADY_OPEN", "it names the open cycle")
	assert_equal(_policy.opened_cycle_count(), 1, "and only one cycle was opened")


func test_each_open_cycle_takes_the_next_ordinal() -> void:
	"""The per-field ordinal is monotonic; it is what stamps an enrolment."""
	assert_true(_policy.open_cycle(_zone).ok, "the first cycle opens")
	var first: IntMath.IntResult = _policy.cycle_ordinal_of(_field)
	assert_true(first.ok, "the ordinal reads")
	assert_equal(first.value, FieldPolicyScript.FIRST_CYCLE, "the first cycle is ordinal 1")
	assert_true(_policy.cancel_cycle(_zone).ok, "it is cancelled")
	assert_true(_policy.open_cycle(_zone).ok, "the next cycle opens")
	var second: IntMath.IntResult = _policy.cycle_ordinal_of(_field)
	assert_true(second.ok, "the ordinal reads")
	assert_equal(second.value, FieldPolicyScript.FIRST_CYCLE + 1, "and takes the next ordinal")


func test_the_cycle_ordinal_refuses_at_int32s_maximum_rather_than_wrapping() -> void:
	"""A wrapped ordinal could match a stale enrolment stamp. The boundary is public and static
	so it can be tested without 2^31 cycles."""
	assert_true(FieldPolicyScript.can_open_cycle(FieldPolicyScript.NO_CYCLE),
		"a fresh row can open its first cycle")
	assert_true(FieldPolicyScript.can_open_cycle(IntMath.INT32_MAX - 1),
		"one below the cap still fits")
	assert_false(FieldPolicyScript.can_open_cycle(IntMath.INT32_MAX),
		"the cap itself refuses")
	assert_false(FieldPolicyScript.can_open_cycle(-1), "and so does a negative ordinal")


func test_enrolment_validates_the_plot_and_the_open_cycle() -> void:
	"""The participating set is caller-supplied, so everything that CAN be validated is."""
	var early: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, 0)
	assert_false(early.ok, "enrolling before a cycle opens refuses")
	assert_equal(early.error, &"NO_OPEN_FIELD_CYCLE", "it names the missing cycle")
	assert_true(_policy.open_cycle(_zone).ok, "a cycle opens")
	var absent: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, 7)
	assert_false(absent.ok, "a row holding no plot refuses")
	assert_equal(absent.error, &"PLOT_NOT_PRESENT", "it names the missing plot")
	var bad: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, -1)
	assert_false(bad.ok, "a row off the ledger refuses")
	assert_equal(bad.error, &"INVALID_PLOT_SLOT", "it names the bad row")


func test_a_plot_cannot_be_enrolled_in_two_open_cycles() -> void:
	"""One plot participates in at most one field's open cycle, which is what makes the ledger
	plot-major and bounded."""
	var plots: Array[int] = _open_with_plots([330])
	var again: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, plots[0])
	assert_false(again.ok, "a second enrolment in the same cycle refuses")
	assert_equal(again.error, &"PLOT_ALREADY_ENROLLED", "it names the existing enrolment")
	var other_zone: Vector2i = _farm_zone()
	assert_true(_policy.create_policy(other_zone).ok, "a second field gets a policy")
	assert_true(_policy.open_cycle(other_zone).ok, "and opens a cycle")
	var stolen: FieldPolicyScript.OpResult = _policy.enrol_plot(other_zone, plots[0])
	assert_false(stolen.ok, "another field cannot enrol the same plot")
	assert_equal(stolen.error, &"PLOT_ALREADY_ENROLLED", "it names the existing enrolment")


func test_a_plot_can_be_enrolled_again_in_the_next_cycle() -> void:
	"""The stamp goes stale when the cycle closes, so no ledger is ever walked to clear it."""
	var plots: Array[int] = _open_with_plots([340])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the cycle completes")
	assert_false(_policy.is_plot_enrolled(plots[0]), "the enrolment is stale once closed")
	assert_true(_policy.open_cycle(_zone).ok, "the next cycle opens")
	var again: FieldPolicyScript.OpResult = _policy.enrol_plot(_zone, plots[0])
	assert_true(again.ok, "the same plot enrols again (error: %s)" % again.error)
	assert_true(_policy.is_plot_enrolled(plots[0]), "and participates once more")
	var outcome: IntMath.IntResult = _policy.plot_outcome_of(plots[0])
	assert_true(outcome.ok, "the outcome reads")
	assert_equal(outcome.value, OUTCOME_UNRESOLVED, "starting unresolved again")


func test_one_fields_plot_cannot_be_resolved_through_another_field() -> void:
	"""The enrolment names its field, and a resolution must come through that same field."""
	var plots: Array[int] = _open_with_plots([350])
	var other_zone: Vector2i = _farm_zone()
	assert_true(_policy.create_policy(other_zone).ok, "a second field gets a policy")
	assert_true(_policy.open_cycle(other_zone).ok, "and opens a cycle")
	var wrong: FieldPolicyScript.OpResult = _policy.record_plot_resolved(other_zone, plots[0],
		OUTCOME_HARVESTED, 0)
	assert_false(wrong.ok, "the other field cannot resolve it")
	assert_equal(wrong.error, &"PLOT_NOT_ENROLLED", "it is not that field's participant")


func test_a_negative_tick_refuses_on_every_entry_point_that_takes_one() -> void:
	"""No gate clamps a bad tick into a plausible calendar day."""
	var plots: Array[int] = _open_with_plots([360])
	assert_false(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, -1).ok,
		"a resolution refuses")
	assert_false(_policy.withdraw_plot(_zone, plots[0], -1).ok, "a withdrawal refuses")
	assert_false(_policy.set_rotation(_zone, GRAIN, BEANS, ROOTS, -1).ok, "an edit refuses")
	assert_false(_policy.set_rotation_cursor(_zone, 1, -1).ok, "a cursor edit refuses")
	assert_equal(_cursor(), 0, "and nothing changed")


# --- the policy edit path ------------------------------------------------------------------------------

func test_a_rotation_edit_refuses_a_value_that_names_no_crop() -> void:
	"""An unknown catalog id writes nothing at all; §4.2's -1 is the only non-crop admitted."""
	var refused: FieldPolicyScript.OpResult = _policy.set_rotation(_zone, GRAIN, 99, ROOTS, 0)
	assert_false(refused.ok, "an unknown crop id refuses")
	assert_equal(refused.error, &"INVALID_CROP", "it names the bad id")
	var first: IntMath.IntResult = _policy.rotation_id_of(_field, 0)
	var second: IntMath.IntResult = _policy.rotation_id_of(_field, 1)
	assert_true(first.ok and second.ok, "the entries still read")
	assert_equal(first.value, GRAIN, "entry 0 was not written")
	assert_equal(second.value, BEANS, "and neither was entry 1")


func test_a_rotation_edit_accepts_the_empty_catalog_id() -> void:
	"""§4.2: "empty catalog IDs are -1". A field may legitimately configure fewer than three."""
	assert_true(_policy.set_rotation(_zone, GRAIN, NO_CROP, NO_CROP, 0).ok,
		"two entries may be cleared")
	var second: IntMath.IntResult = _policy.rotation_id_of(_field, 1)
	assert_true(second.ok, "the cleared entry reads")
	assert_equal(second.value, NO_CROP, "as the empty catalog id")


func test_a_cursor_edit_refuses_a_position_outside_the_three_entry_list() -> void:
	"""§4.2's `rotation_ids` is int32[3]; nothing addresses a fourth entry."""
	assert_false(_policy.set_rotation_cursor(_zone, 3, 0).ok, "entry 3 refuses")
	assert_false(_policy.set_rotation_cursor(_zone, -1, 0).ok, "a negative cursor refuses")
	assert_equal(_cursor(), 0, "and the cursor did not move")
	assert_true(_policy.set_rotation_cursor(_zone, 2, 0).ok, "entry 2 is admitted")
	assert_equal(_cursor(), 2, "and takes effect")


func test_every_edit_entry_point_refuses_a_zone_with_no_policy() -> void:
	"""Blocker U2's five entry points all validate their field before writing anything."""
	var bare: Vector2i = _farm_zone()
	assert_false(_policy.set_rotation(bare, GRAIN, BEANS, ROOTS, 0).ok, "set_rotation refuses")
	assert_false(_policy.set_rotation_cursor(bare, 1, 0).ok, "set_rotation_cursor refuses")
	assert_false(_policy.set_auto_rotation(bare, true).ok, "set_auto_rotation refuses")
	assert_false(_policy.set_seed_reserve(bare, false).ok, "set_seed_reserve refuses")
	assert_false(_policy.authorise_seed_release(bare).ok, "authorise_seed_release refuses")
	assert_false(_policy.open_cycle(bare).ok, "open_cycle refuses")


func test_the_auto_rotation_and_seed_reserve_flags_round_trip() -> void:
	"""Both §4.2 booleans are settable in both directions."""
	assert_true(_policy.set_auto_rotation(_zone, true).ok, "auto rotation enables")
	assert_true(_policy.is_auto_rotation(_field), "and reads back true")
	assert_true(_policy.set_auto_rotation(_zone, false).ok, "auto rotation disables")
	assert_false(_policy.is_auto_rotation(_field), "and reads back false")
	assert_true(_policy.set_seed_reserve(_zone, false).ok, "the reserve turns off")
	assert_false(_policy.is_seed_reserve(_field), "and reads back false")
	assert_true(_policy.set_seed_reserve(_zone, true).ok, "the reserve turns back on")
	assert_true(_policy.is_seed_reserve(_field), "and reads back true")


# --- readers, refusals and the store's own hygiene -------------------------------------------------------

func test_every_reader_refuses_a_row_that_holds_no_policy() -> void:
	"""No reader answers a plausible number for an empty row."""
	var empty: int = _field + 1
	assert_false(_policy.rotation_cursor_of(empty).ok, "the cursor refuses")
	assert_false(_policy.rotation_id_of(empty, 0).ok, "a rotation entry refuses")
	assert_false(_policy.cycle_state_of(empty).ok, "the cycle state refuses")
	assert_false(_policy.close_reason_of(empty).ok, "the close reason refuses")
	assert_false(_policy.participant_count_of(empty).ok, "the participant count refuses")
	assert_false(_policy.resolved_count_of(empty).ok, "the resolved count refuses")
	assert_false(_policy.withdrawn_count_of(empty).ok, "the withdrawn count refuses")
	assert_false(_policy.completed_cycle_count_of(empty).ok, "the completion history refuses")
	assert_false(_policy.cancelled_cycle_count_of(empty).ok, "the cancellation history refuses")
	assert_false(_policy.requested_crop_of(empty).ok, "the requested crop refuses")
	assert_false(_policy.request_state_of(empty).ok, "the request state refuses")
	assert_false(_policy.cycle_ordinal_of(empty).ok, "the cycle ordinal refuses")
	assert_false(_policy.seed_reserve_gate_of(empty).ok, "the seed gate refuses")
	assert_false(_policy.next_planting_crop_of(empty).ok, "the next planting crop refuses")
	assert_equal(_policy.blocked_reason_of(empty), &"NO_FIELD_POLICY", "and so does the reason")


func test_a_rotation_entry_reader_refuses_an_index_outside_the_list() -> void:
	"""Three entries, and nothing indexes past them."""
	assert_false(_policy.rotation_id_of(_field, 3).ok, "index 3 refuses")
	assert_false(_policy.rotation_id_of(_field, -1).ok, "a negative index refuses")
	assert_true(_policy.rotation_id_of(_field, 2).ok, "index 2 is admitted")


func test_the_plot_field_reader_refuses_rather_than_answering_the_null_row() -> void:
	""""Never return a sentinel to signal failure": an unenrolled plot refuses."""
	var lone: int = _plot(370)
	var missing: IntMath.IntResult = _policy.plot_field_slot_of(lone)
	assert_false(missing.ok, "an unenrolled plot refuses")
	assert_equal(missing.value, 0, "and carries no row number")
	assert_equal(missing.error, "PLOT_NOT_ENROLLED", "it names the missing enrolment")
	assert_false(_policy.plot_field_slot_of(-1).ok, "a row off the ledger refuses")
	var plots: Array[int] = _open_with_plots([371])
	var found: IntMath.IntResult = _policy.plot_field_slot_of(plots[0])
	assert_true(found.ok, "an enrolled plot answers")
	assert_equal(found.value, _field, "with its own field row")


func test_the_blocked_reason_table_covers_every_request_state() -> void:
	"""One mapping, so the byte on the row and the code shown to the player cannot drift."""
	assert_equal(_policy.blocked_reason_of_state(REQUEST_NONE), &"", "no request is not blocked")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_READY), &"", "nor is a ready one")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_WINDOW_FUTURE),
		&"PLANT_WINDOW_IS_FUTURE", "a future window has its own reason")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_WINDOW_MISSED),
		&"PLANT_WINDOW_MISSED", "and so does a missed one")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_ENTRY_NOT_CONFIGURED),
		&"ROTATION_ENTRY_NOT_CONFIGURED", "and so does an unconfigured entry")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_NO_LEGAL_WINDOW),
		&"CROP_HAS_NO_LEGAL_WINDOW", "and so does a crop with no legal day")
	assert_equal(_policy.blocked_reason_of_state(REQUEST_NO_LEGAL_WINDOW + 1),
		&"INVALID_REQUEST_STATE", "an ordinal off the domain refuses")


func test_the_into_readers_agree_with_their_allocating_forms() -> void:
	"""Every hot reader has a non-allocating `_into` twin, and the two cannot disagree."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([380])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED,
		_spring_day(1)).ok, "the cycle completes")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_policy.rotation_cursor_into(_field, out), "the cursor reads into")
	assert_equal(out.value, _policy.rotation_cursor_of(_field).value, "cursor agrees")
	assert_true(_policy.request_state_into(_field, out), "the request state reads into")
	assert_equal(out.value, _policy.request_state_of(_field).value, "request state agrees")
	assert_true(_policy.requested_crop_into(_field, out), "the requested crop reads into")
	assert_equal(out.value, _policy.requested_crop_of(_field).value, "requested crop agrees")
	assert_true(_policy.close_reason_into(_field, out), "the close reason reads into")
	assert_equal(out.value, _policy.close_reason_of(_field).value, "close reason agrees")


func test_more_into_readers_agree_with_their_allocating_forms() -> void:
	"""The remaining twins, so none of them can drift unnoticed."""
	var plots: Array[int] = _open_with_plots([390, 391])
	assert_true(_policy.withdraw_plot(_zone, plots[1], 0).ok, "one tile is erased")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_policy.participant_count_into(_field, out), "participants read into")
	assert_equal(out.value, _policy.participant_count_of(_field).value, "participants agree")
	assert_true(_policy.withdrawn_count_into(_field, out), "withdrawals read into")
	assert_equal(out.value, _policy.withdrawn_count_of(_field).value, "withdrawals agree")
	assert_true(_policy.resolved_count_into(_field, out), "resolutions read into")
	assert_equal(out.value, _policy.resolved_count_of(_field).value, "resolutions agree")
	assert_true(_policy.cycle_ordinal_into(_field, out), "the ordinal reads into")
	assert_equal(out.value, _policy.cycle_ordinal_of(_field).value, "the ordinal agrees")
	assert_true(_policy.cycle_state_into(_field, out), "the cycle state reads into")
	assert_equal(out.value, _policy.cycle_state_of(_field).value, "the cycle state agrees")
	assert_true(_policy.plot_outcome_into(plots[1], out), "the outcome reads into")
	assert_equal(out.value, _policy.plot_outcome_of(plots[1]).value, "the outcome agrees")


func test_history_and_gate_into_readers_agree_with_their_allocating_forms() -> void:
	"""The durable histories and the REQ-SET-088 gate have the same twins."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([400])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the cycle completes")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_policy.completed_cycle_count_into(_field, out), "completions read into")
	assert_equal(out.value, _policy.completed_cycle_count_of(_field).value, "completions agree")
	assert_true(_policy.cancelled_cycle_count_into(_field, out), "cancellations read into")
	assert_equal(out.value, _policy.cancelled_cycle_count_of(_field).value,
		"cancellations agree")
	assert_true(_policy.seed_reserve_gate_into(_field, out), "the seed gate reads into")
	assert_equal(out.value, _policy.seed_reserve_gate_of(_field).value, "the gate agrees")
	assert_true(_policy.next_planting_crop_into(_field, out), "the next crop reads into")
	assert_equal(out.value, _policy.next_planting_crop_of(_field).value, "the next crop agrees")
	assert_true(_policy.field_slot_of_into(_zone, out), "the field row reads into")
	assert_equal(out.value, _field, "and is the fixture's own row")


func test_the_store_allocates_its_columns_once_and_clear_refills_them() -> void:
	"""ARCH-MEM-001: nothing outside _allocate_columns() resizes, and clear() empties the store."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([410])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the cycle completes")
	assert_equal(_policy.advance_count(), 1, "an advance ran")
	_policy.clear()
	assert_equal(_policy.policy_count(), 0, "clear() retires every policy")
	assert_equal(_policy.advance_count(), 0, "and zeroes every counter")
	assert_equal(_policy.opened_cycle_count(), 0, "including the opened count")
	assert_equal(_policy.completed_cycle_count(), 0, "and the completed count")
	assert_false(_policy.is_present(_field), "no row holds a policy")
	assert_false(_policy.is_plot_enrolled(plots[0]), "and no plot is enrolled")
	var rebound: FieldPolicyScript.OpResult = _policy.create_policy(_zone)
	assert_true(rebound.ok, "the store still works after a clear (error: %s)" % rebound.error)
	assert_equal(rebound.value, _field, "binding to the same 128-row table")


func test_the_store_exposes_the_two_collaborators_it_validates_against() -> void:
	"""The farm store owns §5.6's windows and the zone store owns §4.2's ZoneType."""
	assert_true(_policy.farming() == _farming, "the farm store is the one supplied")
	assert_true(_policy.forage() == _forage, "and so is the zone store")
	assert_equal(FieldPolicyScript.FIELD_CAPACITY, ForageScript.HARVEST_ZONE_CAPACITY,
		"the policy table is the zone table's 128 rows")
	assert_equal(FieldPolicyScript.PLOT_CAPACITY, FarmingScript.FARM_PLOT_CAPACITY,
		"and the enrolment ledger is the FarmPlot table's 4096")


func test_slot_predicates_bound_both_tables() -> void:
	"""Both owner classes are addressed by their own capacity and nothing beyond it."""
	assert_true(_policy.is_field_slot(0), "row 0 is a field row")
	assert_true(_policy.is_field_slot(FieldPolicyScript.FIELD_CAPACITY - 1), "and so is the last")
	assert_false(_policy.is_field_slot(FieldPolicyScript.FIELD_CAPACITY), "one past is not")
	assert_false(_policy.is_field_slot(-1), "and neither is a negative row")
	assert_true(_policy.is_plot_slot(0), "row 0 is a ledger row")
	assert_true(_policy.is_plot_slot(FieldPolicyScript.PLOT_CAPACITY - 1), "and so is the last")
	assert_false(_policy.is_plot_slot(FieldPolicyScript.PLOT_CAPACITY), "one past is not")
	assert_false(_policy.is_plot_slot(-1), "and neither is a negative row")


func test_two_fields_advance_independently() -> void:
	"""Every column is per-field: one field's completion cannot move another's cursor."""
	_enable_auto()
	var other_zone: Vector2i = _farm_zone()
	var other: FieldPolicyScript.OpResult = _policy.create_policy(other_zone)
	assert_true(other.ok, "the second field gets a policy")
	assert_true(_policy.set_auto_rotation(other_zone, true).ok, "with auto rotation on")
	var plots: Array[int] = _open_with_plots([420])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"the first field completes")
	assert_equal(_cursor(), 1, "the first field advanced")
	var other_cursor: IntMath.IntResult = _policy.rotation_cursor_of(other.value)
	assert_true(other_cursor.ok, "the second field's cursor reads")
	assert_equal(other_cursor.value, 0, "and did not move")
	assert_equal(_policy.advance_count(), 1, "exactly one advance ran across both fields")


func test_the_global_counters_track_every_field() -> void:
	"""The observable counters are the store's own totals, not one field's."""
	_enable_auto()
	var plots: Array[int] = _open_with_plots([430, 431, 432])
	assert_true(_policy.record_plot_resolved(_zone, plots[0], OUTCOME_HARVESTED, 0).ok,
		"one plot harvests")
	assert_true(_policy.record_plot_resolved(_zone, plots[1], OUTCOME_CLEARED, 0).ok,
		"one plot clears")
	assert_true(_policy.withdraw_plot(_zone, plots[2], 0).ok, "one tile is erased")
	assert_equal(_policy.resolved_plot_count(), 2, "two participants resolved")
	assert_equal(_policy.withdrawn_plot_count(), 1, "one was withdrawn")
	assert_equal(_policy.completed_cycle_count(), 1, "the cycle completed")
	assert_equal(_policy.cancelled_cycle_count(), 0, "nothing was cancelled")
	assert_equal(_policy.abandoned_cycle_count(), 0, "and nothing was abandoned")


func test_a_window_starting_tomorrow_is_future_and_not_missed() -> void:
	"""The year scan's boundary is `ordinal > today`, and §5.6's own table cannot exercise it:
	every window there is at least three days long, so a crop whose next legal day is TOMORROW
	always has a legal day the day after too, and an off-by-one in `today` still finds one. A
	one-day window can tell the two apart, which is the only way to test that boundary against a
	real value instead of against itself."""
	var single: SingleDayWindowFarming = SingleDayWindowFarming.new()
	var policy: FieldPolicyScript = _policy_over(single)
	var zone: Vector2i = _bound_farm_zone(single, policy)
	var field: IntMath.IntResult = policy.field_slot_of(zone)
	assert_true(field.ok, "the policy row resolves")
	_complete_one_plot(single, policy, zone, _spring_day(11))
	var state: IntMath.IntResult = policy.request_state_of(field.value)
	assert_true(state.ok, "the request state reads")
	assert_equal(state.value, REQUEST_WINDOW_FUTURE,
		"spring day 12 is still ahead of spring day 11")


func test_the_one_day_window_is_ready_on_its_own_day_and_missed_after_it() -> void:
	"""The same one-day crop, read on its legal day and after it, so the boundary test above
	cannot pass by reporting FUTURE for everything."""
	var ready_farm: SingleDayWindowFarming = SingleDayWindowFarming.new()
	var ready_policy: FieldPolicyScript = _policy_over(ready_farm)
	var ready_zone: Vector2i = _bound_farm_zone(ready_farm, ready_policy)
	var ready_row: IntMath.IntResult = ready_policy.field_slot_of(ready_zone)
	assert_true(ready_row.ok, "the policy row resolves")
	_complete_one_plot(ready_farm, ready_policy, ready_zone, _spring_day(12))
	var ready_state: IntMath.IntResult = ready_policy.request_state_of(ready_row.value)
	assert_true(ready_state.ok, "the request state reads")
	assert_equal(ready_state.value, REQUEST_READY, "spring day 12 admits it")
	var late_farm: SingleDayWindowFarming = SingleDayWindowFarming.new()
	var late_policy: FieldPolicyScript = _policy_over(late_farm)
	var late_zone: Vector2i = _bound_farm_zone(late_farm, late_policy)
	var late_row: IntMath.IntResult = late_policy.field_slot_of(late_zone)
	assert_true(late_row.ok, "the policy row resolves")
	_complete_one_plot(late_farm, late_policy, late_zone, _autumn_day(1))
	var late_state: IntMath.IntResult = late_policy.request_state_of(late_row.value)
	assert_true(late_state.ok, "the request state reads")
	assert_equal(late_state.value, REQUEST_WINDOW_MISSED, "autumn day 1 has missed it")


func _policy_over(farm: FarmingScript) -> FieldPolicyScript:
	"""Build a policy store over a supplied farm store and a zone store sharing its directory."""
	return FieldPolicyScript.new(farm, ForageScript.new(farm.directory()))


func _bound_farm_zone(farm: FarmingScript, policy: FieldPolicyScript) -> Vector2i:
	"""Designate a FARM zone in that policy's own zone store, bind a policy, and enable auto."""
	var created: ForageScript.OpResult = policy.forage().create_zone(ZONE_FARM, 0, 0, false, true)
	assert_true(created.ok, "the FARM zone designates (error: %s)" % created.error)
	assert_true(policy.create_policy(created.ref).ok, "the policy binds")
	assert_true(policy.set_auto_rotation(created.ref, true).ok, "auto rotation enables")
	assert_true(farm.count() >= 0, "the supplied farm store answers")
	return created.ref


func _complete_one_plot(farm: FarmingScript, policy: FieldPolicyScript, zone: Vector2i,
		tick: int) -> void:
	"""Open a cycle on that field, enrol one plot, and harvest it at `tick` to complete it."""
	assert_true(policy.open_cycle(zone).ok, "the cycle opens")
	var plot: FarmingScript.OpResult = farm.create_plot_at_tile(5, LOAM, 1)
	assert_true(plot.ok, "the plot creates (error: %s)" % plot.error)
	assert_true(policy.enrol_plot(zone, plot.value).ok, "the plot enrols")
	assert_true(policy.record_plot_resolved(zone, plot.value, OUTCOME_HARVESTED, tick).ok,
		"the plot harvests and completes the cycle")


class SingleDayWindowFarming extends FarmingScript:
	"""A farm store whose crops are plantable on exactly ONE day of the year.

	§5.6's shortest planting window is three days (beans summer 1-3, cabbage autumn 1-3), so no
	crop in the compiled catalog can distinguish "the next legal day is tomorrow" from "the next
	legal day is the day after tomorrow". This subclass can, which is what makes the year scan's
	`ordinal > today` boundary and its `today` arithmetic testable against a real value.
	"""

	## Spring is §4.3's season 0; its season-local day 12 is the year's twelfth day.
	const ONLY_SEASON: int = 0
	const ONLY_SEASON_DAY: int = 12

	func is_plant_window(_crop_id: int, season: int, season_day: int) -> bool:
		"""Admit spring day 12 and no other day of the year."""
		return season == ONLY_SEASON and season_day == ONLY_SEASON_DAY


class WindowlessFarming extends FarmingScript:
	"""A farm store whose crops admit no planting day, for the defensive NO_LEGAL_WINDOW branch.

	§5.6's table gives every crop at least one window, so that branch is unreachable through the
	compiled catalog. It is kept for the save/load path that does not exist yet, and exercised
	here exactly as `forage.gd`'s malformed-stock guard is exercised through a subclass.
	"""

	func is_plant_window(_crop_id: int, _season: int, _season_day: int) -> bool:
		"""Admit no day of the year, so every legal-window search comes back empty."""
		return false
