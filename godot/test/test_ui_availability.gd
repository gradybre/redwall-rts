extends "res://test/framework/test_case.gd"
## Coverage for the rule 04.4 states outright: an unbuilt panel must not be claimed as working.
##
## This suite is the one that stops the shell lying. It checks three things that a rendered-but-
## empty panel would pass and a truthful one must not:
##
##   1. EVERY §4 element is claimed, one way or the other. A missing claim is a panel with no
##      position on the question.
##   2. An UNAVAILABLE element's label names a MISSING OWNER, not a mood. Every reason sentence
##      is checked for length and for the absence of the empty string.
##   3. Asking for an "unavailable" label for a WIRED element REFUSES. That is the direction the
##      lie would travel in: a regression that stops driving an element would otherwise print a
##      plausible excuse and look deliberate.
##
## The specific ids asserted below are stated here from the task's own out-of-scope list --
## beds and buildings are task 06, movement and selection are task 05, saves are task 09 -- so
## the claim table cannot be quietly widened without this file disagreeing.

const UiAvailability := preload("res://scripts/ui/ui_availability.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

## Elements this milestone claims to drive, quoted from the task's scope: New Settlement, the
## paused world, time controls, the resource summary, resident detail, the zone tool, pending
## preview, cancellation and the accessible refusal display.
const MUST_BE_WIRED: Array[int] = [
	103,  # New settlement modal
	14, 15, 16, 17, 101,  # pause, the three speeds, the date trigger
	1, 2, 4, 5, 6,  # the resource cluster and the counters that have a source
	36, 37, 38, 39, 40,  # context detail, its title, tabs, need and skill rows
	31, 69,  # the roster command and its resident rows
	28, 59,  # the zone command and the zone brush
	85, 86,  # the accessible refusal display and the pause label
	96,  # the quick menu that cancels a job
	20, 21, 22, 23,  # minimap frame, map, layers, world surface
	62, 66, 67,  # the brush stepper and the confirm/cancel actions
]

## Elements whose owning store genuinely does not exist, with the owner each is waiting on.
const MUST_BE_UNAVAILABLE: Array = [
	[7, UiAvailability.REASON_NO_BUILDING_STORE],
	[27, UiAvailability.REASON_NO_BUILDING_STORE],
	[34, UiAvailability.REASON_NO_BUILDING_STORE],
	[47, UiAvailability.REASON_NO_BUILDING_STORE],
	[52, UiAvailability.REASON_NO_BUILDING_STORE],
	[3, UiAvailability.REASON_NO_HEATING_DEMAND],
	[24, UiAvailability.REASON_NO_TRANSFORM_STORE],
	[25, UiAvailability.REASON_NO_TRANSFORM_STORE],
	[76, UiAvailability.REASON_NO_SAVE_CODEC],
	[77, UiAvailability.REASON_NO_SAVE_CODEC],
	[78, UiAvailability.REASON_NO_SETTINGS_STORE],
	[30, UiAvailability.REASON_NO_RECIPE_ORDER_STORE],
	[63, UiAvailability.REASON_NO_MILESTONE_STATE],
	[68, UiAvailability.REASON_NO_IMMIGRATION_EVENT],
	[72, UiAvailability.REASON_NO_TUTORIAL_STATE],
	[71, UiAvailability.REASON_NO_FORECAST_MODEL],
	[70, UiAvailability.REASON_PANEL_NOT_BUILT],
	[87, UiAvailability.REASON_PANEL_NOT_BUILT],
	[89, UiAvailability.REASON_NO_WORLD_CAMERA],
	[90, UiAvailability.REASON_NO_WORLD_CAMERA],
]

## §2.2's disabled wording, stated independently of the module under test.
const UNAVAILABLE_WORD: String = "Unavailable"
## A reason short enough to be a shrug names no owner. Every sentence must beat this.
const MINIMUM_REASON_LENGTH: int = 20

var _availability: UiAvailability = null


func before_each() -> void:
	"""Build the availability claim."""
	_availability = UiAvailability.new()


func after_each() -> void:
	"""Drop it so nothing crosses a test boundary."""
	_availability = null


# --- every element is claimed ---------------------------------------------------------------------

func test_every_registered_element_carries_a_claim() -> void:
	"""All 103 §4 elements are either driven or explained; none is left unanswered."""
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		var claim: bool = _availability.is_wired(id) or _availability.is_unavailable(id)
		assert_true(claim, "UI-SET-%03d carries an availability claim" % id)
	assert_equal(_availability.wired_count() + _availability.unavailable_count(),
		UiRegistry.ELEMENT_COUNT, "the two counts partition the whole registry")


func test_the_wired_and_unavailable_states_are_exclusive() -> void:
	"""No element may be both driven and excused at once."""
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		assert_false(_availability.is_wired(id) and _availability.is_unavailable(id),
			"UI-SET-%03d is in exactly one state" % id)


func test_an_unknown_element_is_refused_rather_than_assumed_available() -> void:
	"""An id §4 does not define has no claim, and asking refuses with a named code."""
	assert_false(_availability.reason_of(0).ok, "element 0 has no claim")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_UNKNOWN_ID, "with UNKNOWN_ID")
	assert_false(_availability.is_wired(104), "and an id past the end is not wired")
	assert_false(_availability.is_unavailable(104), "nor is it claimed unavailable")


# --- the scoped elements ---------------------------------------------------------------------------

func test_the_elements_this_milestone_claims_are_marked_wired() -> void:
	"""Each element named in task 04.4's own scope must be driven, not excused."""
	for id: int in MUST_BE_WIRED:
		assert_true(_availability.is_wired(id),
			"UI-SET-%03d (%s) is wired" % [id, _availability.reason_key_of(id)])


func test_elements_with_no_owning_store_name_the_owner_they_wait_on() -> void:
	"""Every out-of-scope element carries the exact missing owner, not a generic excuse."""
	for row: Array in MUST_BE_UNAVAILABLE:
		var id: int = row[0]
		assert_true(_availability.is_unavailable(id), "UI-SET-%03d is unavailable" % id)
		assert_equal(_availability.reason_of(id).value, row[1],
			"UI-SET-%03d names the owner it waits on" % id)


func test_the_bed_counter_is_not_drawn_as_a_zero() -> void:
	"""The Bed counter's store does not exist, so it must be excused rather than shown empty."""
	assert_false(_availability.is_wired(7), "UI-SET-007 is not claimed as working")
	var label: String = _availability.unavailable_label(7)
	assert_true(label.begins_with(UNAVAILABLE_WORD), "it reads as unavailable: '%s'" % label)
	assert_true(label.contains("Building"), "and names the Building store it needs")
	assert_true(label.contains("task 06"), "and the task that owns that contract")
	assert_false(label.ends_with("0"), "the label is a reason, not a count ending in a figure")


# --- the labels ------------------------------------------------------------------------------------

func test_every_unavailable_element_has_a_usable_reason_sentence() -> void:
	"""§2.2 requires disabled controls to explain themselves without hover."""
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if not _availability.is_unavailable(id):
			continue
		var label: String = _availability.unavailable_label(id)
		assert_true(label.begins_with("%s:" % UNAVAILABLE_WORD),
			"UI-SET-%03d starts with the disabled wording" % id)
		assert_true(label.length() > MINIMUM_REASON_LENGTH + UNAVAILABLE_WORD.length(),
			"UI-SET-%03d names an owner rather than shrugging: '%s'" % [id, label])


func test_asking_a_wired_element_for_an_excuse_refuses() -> void:
	"""A working element has no unavailable label, and inventing one would hide a regression."""
	assert_true(_availability.is_wired(14), "the pause button is wired")
	assert_equal(_availability.unavailable_label(14), "", "it has no excuse to print")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_ELEMENT_IS_WIRED,
		"and asking for one refuses explicitly")


func test_the_wired_reason_carries_no_sentence_and_every_other_one_does() -> void:
	"""REASON_WIRED is the absence of an excuse; all twelve others are real sentences."""
	assert_equal(_availability.reason_text(UiAvailability.REASON_WIRED), "",
		"a wired element has no reason text")
	for reason: int in range(1, UiAvailability.REASON_COUNT):
		var text: String = _availability.reason_text(reason)
		assert_true(text.length() > MINIMUM_REASON_LENGTH,
			"reason %s is a sentence: '%s'" % [UiAvailability.REASON_KEYS[reason], text])


func test_an_undefined_reason_index_is_refused() -> void:
	"""There is no thirteenth reason, and asking for one does not return an empty excuse."""
	assert_equal(_availability.reason_text(UiAvailability.REASON_COUNT), "", "no such reason")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_UNKNOWN_REASON,
		"and it refuses with UNKNOWN_REASON")
	assert_false(_availability.count_with_reason(-1).ok, "a negative reason cannot be counted")


# --- the counts this milestone reports --------------------------------------------------------------

func test_the_claim_is_a_minority_of_the_registry_and_says_so() -> void:
	"""The shell drives part of §4; the count must be reportable rather than implied."""
	var wired: int = _availability.wired_count()
	assert_true(wired > 1, "more than the single element that existed before this milestone")
	assert_true(wired < UiRegistry.ELEMENT_COUNT, "and not a claim to have built all 103")
	assert_equal(_availability.unavailable_count(), UiRegistry.ELEMENT_COUNT - wired,
		"the remainder is accounted for")


func test_blocked_elements_group_under_the_owners_that_are_missing() -> void:
	"""The largest blocked groups must be the stores the task names as out of scope."""
	var buildings: int = _availability.count_with_reason(
		UiAvailability.REASON_NO_BUILDING_STORE).value
	var movement: int = _availability.count_with_reason(
		UiAvailability.REASON_NO_TRANSFORM_STORE).value
	assert_true(buildings >= 10, "task 06's building contracts block a whole family of panels")
	assert_true(movement >= 2, "task 05's movement blocks world selection")
	assert_equal(_availability.count_with_reason(UiAvailability.REASON_WIRED).value,
		_availability.wired_count(), "counting by reason agrees with the wired total")


# --- UXV-001: the 103-entry registry is not expanded wholesale into panels -------------------------

const UiShell := preload("res://scripts/ui/ui_shell.gd")


func test_this_milestone_renders_a_minority_of_the_registry() -> void:
	"""§4 defines 103 elements. Building all of them as disabled panels is its own kind of lie."""
	assert_true(_availability.rendered_count() < UiRegistry.ELEMENT_COUNT,
		"the registry is not expanded wholesale")
	assert_true(_availability.rendered_count() > 0, "but this milestone does render surfaces")
	var not_rendered: int = 0
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if not _availability.renders(id):
			not_rendered += 1
	assert_equal(not_rendered, UiRegistry.ELEMENT_COUNT - _availability.rendered_count(),
		"every element is either rendered or a specification entry only")


func test_the_render_claim_is_exactly_what_the_shell_actually_builds() -> void:
	"""A render claim nobody cross-checks drifts. This compares it to the built control tree."""
	var shell: Control = UiShell.new()
	shell.build()
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		assert_equal(_availability.renders(id), shell.renders(id),
			"UI-SET-%03d: the render claim and the built tree agree" % id)
	shell.free()


func test_an_element_outside_the_render_set_has_no_compact_reason_to_print() -> void:
	"""There is no row on screen for it, so a phrase for one would describe nothing."""
	assert_false(_availability.renders(41), "UI-SET-041 is not built this milestone")
	assert_equal(_availability.compact_reason_of(41), "", "so it has no compact reason")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_NOT_RENDERED,
		"and asking refuses with NOT_RENDERED")


# --- UXV-002: visibility is decided before availability --------------------------------------------

func _closed_gates() -> UiAvailability.Gates:
	"""A world with nothing selected, no tool running, every surface closed and no milestones."""
	var gates: UiAvailability.Gates = UiAvailability.Gates.new()
	gates.reset()
	gates.milestone = UiAvailability.MILESTONE_UNKNOWN
	return gates


func test_an_unsatisfied_gate_makes_an_element_absent_without_consulting_the_claim() -> void:
	"""UI-SET-036 is SELECTED-gated: with nothing selected it has no Control to be excused."""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_true(_availability.is_wired(36), "the detail panel IS wired when it is shown")
	assert_equal(_availability.state_of(36, gates).value, UiAvailability.STATE_ABSENT,
		"but with nothing selected it is absent, not available")
	assert_false(_availability.creates_control(36, gates), "so no Control is created for it")
	gates.has_selection = true
	assert_equal(_availability.state_of(36, gates).value, UiAvailability.STATE_AVAILABLE,
		"and selecting something brings it back as available")


func test_an_unavailable_element_behind_a_closed_gate_is_absent_not_unavailable() -> void:
	"""The ordering under test: the gate decides first, so the missing owner never gets a say.

	UI-SET-034 is gated SELECTED and its Building store does not exist. If availability were
	evaluated first this would report UNAVAILABLE -- a disabled Demolish button drawn while
	nothing is selected. Visibility first makes it ABSENT, which is no control at all.
	"""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_false(_availability.is_wired(34), "the demolish command has no Building store")
	assert_equal(_availability.state_of(34, gates).value, UiAvailability.STATE_ABSENT,
		"and with nothing selected it is absent")
	gates.has_selection = true
	assert_equal(_availability.state_of(34, gates).value, UiAvailability.STATE_UNAVAILABLE,
		"only once it is visible does the missing owner decide its state")


func test_a_world_tool_row_appears_only_while_a_stroke_is_running() -> void:
	"""UI-SET-025's box selection is WORLD_TOOL-gated; idle, it is not a control at all."""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_equal(_availability.state_of(25, gates).value, UiAvailability.STATE_ABSENT,
		"no tool is running, so the box selection is absent")
	gates.world_tool_active = true
	assert_true(_availability.state_of(25, gates).value != UiAvailability.STATE_ABSENT,
		"starting a stroke makes it exist")


func test_a_workspace_row_is_absent_until_its_surface_is_opened() -> void:
	"""§3 opens one workspace at a time; a closed one contributes no controls at all."""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_equal(_availability.state_of(69, gates).value, UiAvailability.STATE_ABSENT,
		"the roster row is absent while the roster is closed")
	gates.set_surface_open(69, true)
	assert_equal(_availability.state_of(69, gates).value, UiAvailability.STATE_AVAILABLE,
		"and available once the roster is open")


func test_an_always_gated_element_is_never_absent() -> void:
	"""ALWAYS rows have no condition to fail, so discoverability survives every gate state."""
	var gates: UiAvailability.Gates = _closed_gates()
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if UiRegistry.GATES[id - UiRegistry.FIRST_ID] != UiRegistry.GATE_ALWAYS:
			continue
		assert_true(_availability.state_of(id, gates).value != UiAvailability.STATE_ABSENT,
			"UI-SET-%03d is ALWAYS and must stay discoverable" % id)


func test_an_unreadable_condition_is_unavailable_rather_than_hidden_or_faked() -> void:
	"""A gate whose owning store does not exist is a named unavailable state, not a false."""
	var gates: UiAvailability.Gates = _closed_gates()
	gates.set_condition(87, UiAvailability.FACT_UNKNOWN)
	assert_equal(_availability.state_of(87, gates).value, UiAvailability.STATE_UNAVAILABLE,
		"an unreadable F6 gate leaves the world access list visible and excused")
	gates.set_condition(87, UiAvailability.FACT_NOT_MET)
	assert_equal(_availability.state_of(87, gates).value, UiAvailability.STATE_ABSENT,
		"and a condition known to be false is the one that removes it")


# --- UXV-030: four states, not "hidden or greyed" ---------------------------------------------------

func test_the_four_states_are_all_reachable_and_distinct() -> void:
	"""Collapsing these to hidden-or-greyed loses three distinctions §4 and §2.2 make."""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_equal(UiAvailability.STATE_COUNT, 4, "there are four states")
	assert_equal(_availability.state_of(36, gates).value, UiAvailability.STATE_ABSENT, "absent")
	assert_equal(_availability.state_of(32, gates).value, UiAvailability.STATE_LOCKED, "locked")
	assert_equal(_availability.state_of(3, gates).value, UiAvailability.STATE_UNAVAILABLE,
		"unavailable")
	assert_equal(_availability.state_of(14, gates).value, UiAvailability.STATE_AVAILABLE,
		"available")


func test_a_locked_milestone_control_stays_in_its_catalog_and_states_the_condition() -> void:
	"""§4: it "remains visible in its catalog with the GDD milestone condition"."""
	var gates: UiAvailability.Gates = _closed_gates()
	gates.view = UiAvailability.VIEW_CATALOG
	assert_true(_availability.is_visible(32, gates), "the Feast command is visible in the catalog")
	var condition: String = _availability.locked_condition_of(32, gates)
	assert_true(condition.contains("M1"), "and names its milestone: '%s'" % condition)
	assert_true(condition.contains("12 residents"), "with the GDD's own condition")
	assert_false(_availability.can_activate(32, gates), "while nothing can be committed from it")


func test_a_locked_milestone_control_leaves_the_quick_commands() -> void:
	"""§4: "it is hidden from quick commands until unlocked" -- the same row, a different view."""
	var gates: UiAvailability.Gates = _closed_gates()
	gates.view = UiAvailability.VIEW_QUICK_COMMANDS
	assert_equal(_availability.state_of(32, gates).value, UiAvailability.STATE_ABSENT,
		"the locked Feast command is absent from the quick commands")
	gates.milestone = UiAvailability.MILESTONE_M1
	assert_true(_availability.state_of(32, gates).value != UiAvailability.STATE_ABSENT,
		"and reaching M1 puts it back")


func test_reaching_the_milestone_unlocks_and_removes_the_condition() -> void:
	"""Once unlocked there is no condition left to print, and asking for one refuses."""
	var gates: UiAvailability.Gates = _closed_gates()
	gates.milestone = UiAvailability.MILESTONE_M1
	assert_true(_availability.state_of(32, gates).value != UiAvailability.STATE_LOCKED,
		"M1 unlocks the Feast command")
	assert_equal(_availability.locked_condition_of(32, gates), "", "with no condition to show")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_NOT_LOCKED,
		"refusing NOT_LOCKED")


func test_unknown_milestone_state_locks_rather_than_unlocking() -> void:
	"""No progression store exists, and an unread milestone must never read as reached."""
	var gates: UiAvailability.Gates = _closed_gates()
	assert_equal(gates.milestone, UiAvailability.MILESTONE_UNKNOWN, "no progression state exists")
	assert_equal(_availability.state_of(32, gates).value, UiAvailability.STATE_LOCKED,
		"so the M1 control is locked, not quietly unlocked")


func test_an_always_visible_unbuilt_row_gives_a_compact_reason() -> void:
	"""UXV-030: a compact reason on focus, not an automatically opened full-size page."""
	var compact: String = _availability.compact_reason_of(3)
	assert_true(compact.length() > 0, "the fuel counter has a compact reason")
	assert_true(compact.length() <= UiAvailability.COMPACT_REASON_LIMIT,
		"short enough for a focused row: '%s'" % compact)
	assert_true(_availability.unavailable_label(3).length() > compact.length(),
		"and the full sentence, which belongs in inspection, is longer")


func test_every_compact_reason_fits_a_row_and_names_something() -> void:
	"""A phrase too long for the row would force the page UXV-030 forbids."""
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if not _availability.renders(id) or _availability.is_wired(id):
			continue
		var compact: String = _availability.compact_reason_of(id)
		assert_true(compact.length() > 0
			and compact.length() <= UiAvailability.COMPACT_REASON_LIMIT,
			"UI-SET-%03d has a row-sized reason: '%s'" % [id, compact])


# --- the value axis stays four situations, not one marker ------------------------------------------

func test_a_true_zero_is_not_the_same_answer_as_three_kinds_of_no_answer() -> void:
	"""A counter reading 0 and a counter with no source are different claims about the world."""
	assert_true(_availability.value_has_figure(UiAvailability.VALUE_TRUE_ZERO),
		"a real zero has a figure to print")
	for kind: int in [UiAvailability.VALUE_NO_SELECTION, UiAvailability.VALUE_UNINITIALIZED,
			UiAvailability.VALUE_UNSUPPORTED]:
		assert_false(_availability.value_has_figure(kind), "kind %d has no figure" % kind)
	assert_equal(_availability.value_reason_key_of(UiAvailability.VALUE_NO_SELECTION),
		UiAvailability.VALUE_KEYS[UiAvailability.VALUE_NO_SELECTION],
		"and each carries its own distinct code")
	assert_true(_availability.value_reason_key_of(UiAvailability.VALUE_UNINITIALIZED)
		!= _availability.value_reason_key_of(UiAvailability.VALUE_UNSUPPORTED),
		"uninitialized and unsupported are not the same code")


func test_asking_a_true_zero_for_a_no_value_reason_refuses() -> void:
	"""That request is the moment a genuine zero would be turned into a dash."""
	assert_equal(_availability.value_reason_key_of(UiAvailability.VALUE_TRUE_ZERO),
		StringName(""), "a true zero has no no-value reason")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_VALUE_IS_A_FIGURE,
		"and asking refuses with VALUE_IS_A_FIGURE")
	assert_equal(_availability.value_reason_key_of(UiAvailability.VALUE_COUNT),
		StringName(""), "there is no fifth situation")
	assert_equal(_availability.last_refusal(), UiAvailability.REFUSE_UNKNOWN_VALUE_KIND,
		"with UNKNOWN_VALUE_KIND")
