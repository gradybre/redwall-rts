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
	[12, UiAvailability.REASON_NO_NOTICE_STORE],
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
