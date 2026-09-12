extends "res://test/framework/test_case.gd"
## Coverage for R-UI-ALERT-001's notice record and its authored compact summaries.
##
## The test that matters most here is `test_every_authored_summary_fits_the_narrow_card`. The
## ruling allows a compact HUD card to show an authored summary INSTEAD of the full message,
## on the condition that "every supported summary must fit the minimum supported logical
## viewport at 100/125/150% scaling; if it fails, author a shorter equivalent category title
## and retest". That is not a claim that can be made by reading the strings: it is a font
## measurement against a layout width, and it is made below with the real theme font, the real
## NOTICE font size, and `ui_layout.alert_summary_width()`'s real interior -- the one that has
## already subtracted the severity icon, the gaps, the panel padding and §1.2's history rail.
##
## The second property is that the summary never REPLACES the record. Every test that reads a
## summary also reads the original message back and compares it byte for byte, because an
## implementation that summarised by overwriting would pass a summary test on its own.

const UiNotices := preload("res://scripts/ui/ui_notices.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const THEME_PATH: String = "res://ui/theme/woodland_theme.tres"

## The minimum supported display, and §1.2's three user scales. Stated here rather than read
## from the module under test.
const MIN_WIDTH: int = 1280
const MIN_HEIGHT: int = 720
const USER_SCALES: Array[int] = [100, 125, 150]

## The exact reported generation refusal from the 2026-09-11 evidence capture: the sentence that
## wrapped to three lines and drew over the pause line at NARROW.
const THREE_LINE_REFUSAL: String = "Generation refused (WORLD_OCCUPIED): the settlement already has living residents, so the authored world was not published. The settlement is now empty."

## A deliberately long source name and validation code, which the ruling lists as an acceptance
## case. Neither may be shortened and neither may be allowed into the compact summary.
const LONG_SOURCE: String = "UI-SET-103 New settlement, Mossflower Woods north basin, generation attempt 4 of 4"
const LONG_CODE: String = "WORLD_INIT_REFUSED_OCCUPIED_SETTLEMENT_WITH_LIVING_RESIDENTS_PRESENT"

var _notices: UiNotices = null
var _notice: UiNotices.Notice = null
var _layout: UiLayout = null


func before_each() -> void:
	"""A fresh notice record and one reusable expansion target for every test."""
	_notices = UiNotices.new()
	_notice = UiNotices.Notice.new()
	_layout = UiLayout.new()


func after_each() -> void:
	"""Drop the record so no notice crosses a test boundary."""
	_notices = null
	_notice = null
	_layout = null


# --- the measured fit, which is what the ruling conditions the exception on -----------------------

func test_every_authored_summary_fits_the_narrow_card() -> void:
	"""Every authored summary must fit the compact card at 100, 125 and 150 percent.

	The widest possible line is measured: the longest authored title, its severity word, and the
	largest count suffix the store can ever print. A failure here is an instruction to write a
	SHORTER TITLE, never to truncate at runtime.
	"""
	var font: Font = _notice_font()
	var size: int = _notice_font_size()
	for percent: int in USER_SCALES:
		var budget: float = _summary_budget(percent)
		assert_true(budget > 0.0, "the %d%% composition has a card interior" % percent)
		for category: int in UiNotices.CATEGORY_COUNT:
			var line: String = UiNotices.summary_line(category, UiNotices.MAX_OTHER_COUNT)
			var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			assert_true(width <= budget,
				"'%s' is %.1f px and must fit %.1f at %d%%" % [line, width, budget, percent])


func test_the_widest_summary_is_the_one_the_fit_test_would_catch() -> void:
	"""`widest_summary_line()` must actually name the longest line, or the fit test is blind."""
	var widest: String = UiNotices.widest_summary_line()
	for category: int in UiNotices.CATEGORY_COUNT:
		assert_true(UiNotices.summary_line(category, UiNotices.MAX_OTHER_COUNT).length()
			<= widest.length(), "no authored line is longer than the widest one")
	var font: Font = _notice_font()
	var width: float = font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		_notice_font_size()).x
	assert_true(width <= _summary_budget(150), "and the widest one fits the 150%% card")


func _notice_font() -> Font:
	"""The font a NOTICE body actually draws in, read from the shared Theme."""
	var theme: Theme = load(THEME_PATH) as Theme
	return theme.get_font(&"font", &"Label")


func _notice_font_size() -> int:
	"""§2.2's NOTICE body size, read from the Theme rather than restated as a literal."""
	var theme: Theme = load(THEME_PATH) as Theme
	return theme.get_font_size(&"font_size", &"Label")


func _summary_budget(percent: int) -> float:
	"""The card interior a summary must fit, at the minimum supported display and one scale."""
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	if not _layout.compute_into(MIN_WIDTH, MIN_HEIGHT, percent, false, geometry):
		fail("the %d%% minimum viewport must compute" % percent)
		return 0.0
	return UiLayout.alert_summary_width(geometry.profile, geometry.alerts.size.x)


# --- the authored table says what the ruling says it says ----------------------------------------

func test_the_generation_failure_is_the_severity_and_title_the_ruling_names() -> void:
	"""R-UI-ALERT-001: "use severity `Error` and title `Generation failed`". Both, exactly."""
	var category: int = UiNotices.CATEGORY_GENERATION_FAILED
	assert_equal(UiNotices.CATEGORY_SEVERITY[category], UiNotices.SEVERITY_ERROR,
		"the generation failure is an Error")
	assert_equal(UiNotices.SEVERITY_WORDS[UiNotices.SEVERITY_ERROR], "Error",
		"and Error is the word shown")
	assert_equal(UiNotices.CATEGORY_TITLES[category], "Generation failed",
		"with the ruling's own title")
	assert_equal(UiNotices.summary_line(category, 0), "Error: Generation failed",
		"which is the whole compact line when it is the only active notice")


func test_no_two_categories_share_a_title_and_none_is_generic() -> void:
	"""The ruling forbids replacing every cause with one generic line."""
	var seen: PackedStringArray = PackedStringArray()
	for category: int in UiNotices.CATEGORY_COUNT:
		var title: String = UiNotices.CATEGORY_TITLES[category]
		assert_false(seen.has(title), "'%s' is used by exactly one category" % title)
		assert_false(title.to_lower().contains("something"), "'%s' names a cause" % title)
		assert_true(title.length() >= 8, "'%s' is a cause, not a shrug" % title)
		seen.append(title)


func test_every_severity_carries_a_word_an_icon_and_a_colour() -> void:
	"""§7: "severity word+icon". Colour alone never states a failure, and neither does a word."""
	for severity: int in UiNotices.SEVERITY_COUNT:
		assert_true(UiNotices.SEVERITY_WORDS[severity].length() > 0, "severity %d has a word" % severity)
		assert_true(ResourceLoader.exists(UiNotices.SEVERITY_ICONS[severity]),
			"severity %d's icon file exists: %s" % [severity, UiNotices.SEVERITY_ICONS[severity]])
		assert_true(UiNotices.SEVERITY_TOKENS[severity] < UiTheme.TOKEN_COUNT,
			"severity %d names a real §2.1 colour token" % severity)


func test_the_count_suffix_appears_only_when_other_notices_are_active() -> void:
	"""§7: narrow shows "one highest-severity active alert plus count"."""
	var one: String = UiNotices.summary_line(UiNotices.CATEGORY_STOCK_EMPTY, 0)
	assert_false(one.contains("+"), "a lone notice prints no count")
	var many: String = UiNotices.summary_line(UiNotices.CATEGORY_STOCK_EMPTY, 3)
	assert_true(many.ends_with("(+3)"), "three others print as +3, got '%s'" % many)
	assert_true(many.begins_with(one), "and the authored line is unchanged by the count")


# --- the record keeps everything the summary leaves out -------------------------------------------

func test_the_three_line_generation_refusal_is_retained_byte_for_byte() -> void:
	"""The ruling's first acceptance case: the exact reported refusal preserved and available."""
	assert_true(_notices.push(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, "Use New settlement again.", 90), "the refusal is recorded")
	assert_true(_notices.notice_into(0, 0, _notice), "and expands")
	assert_equal(_notice.message, THREE_LINE_REFUSAL, "the whole sentence survives unaltered")
	assert_equal(_notice.source, LONG_SOURCE, "the long source name is not shortened")
	assert_equal(_notice.code, LONG_CODE, "and neither is the long validation code")
	assert_equal(_notice.summary, "Error: Generation failed", "the summary is the authored line")
	assert_false(_notice.summary.contains(LONG_CODE), "the code never enters the summary")
	assert_false(_notice.summary.contains("residents"), "nor any part of the sentence")


func test_the_expanded_disclosure_carries_message_source_code_and_recovery() -> void:
	"""The expanded view must hold "all original message text, severity, source, code and ...
	applicable recovery"."""
	assert_true(_notices.push(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, "Use New settlement again.", 90), "the refusal is recorded")
	assert_true(_notices.notice_into(0, 0, _notice), "and expands")
	var detail: String = _notices.detail_text(_notice)
	assert_true(detail.contains(THREE_LINE_REFUSAL), "the whole message is disclosed")
	assert_true(detail.contains(LONG_SOURCE), "with its source")
	assert_true(detail.contains(LONG_CODE), "its validation code")
	assert_true(detail.contains("Use New settlement again."), "and its recovery")
	assert_true(detail.contains("Error"), "and the severity word")


func test_an_absent_recovery_is_stated_rather_than_invented() -> void:
	"""A condition whose owner published no recovery must not acquire one here."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "", "", "", 5),
		"the depletion is recorded")
	assert_true(_notices.notice_into(0, 0, _notice), "and expands")
	var detail: String = _notices.detail_text(_notice)
	assert_true(detail.contains(UiNotices.NO_RECOVERY), "the absence of recovery is stated")
	assert_true(detail.contains(UiNotices.NO_SOURCE), "so is the absence of a source")
	assert_true(detail.contains(UiNotices.NO_CODE), "and of a code")


func test_the_accessible_text_exposes_severity_the_full_message_and_the_action() -> void:
	"""The ruling: the accessible description carries severity AND the full original message."""
	assert_true(_notices.push(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, "", 3), "the refusal is recorded")
	assert_true(_notices.notice_into(0, 0, _notice), "and expands")
	var accessible: String = _notices.accessible_text(_notice)
	assert_true(accessible.begins_with("Error"), "severity is spoken first")
	assert_true(accessible.contains(THREE_LINE_REFUSAL), "the FULL message is in the description")
	assert_true(accessible.contains(UiNotices.OPEN_DETAILS_ACTION), "and the action is named")


# --- §7's retention, grouping and ordering -------------------------------------------------------

func test_twenty_notices_are_all_retained() -> void:
	"""The ruling's acceptance case: twenty notices retained and grouped under existing policy."""
	for index: int in 20:
		assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of item %d!" % index,
			"stores", "STOCK_%d" % index, "", index), "notice %d is recorded" % index)
	assert_equal(_notices.count(), 20, "all twenty are retained")
	assert_equal(_notices.active_count(), 20, "and all twenty are still active")


func test_a_repeat_of_the_same_code_and_source_counts_rather_than_adding_a_row() -> void:
	"""§7: "Repeated same code/source updates count/last-seen tick without replaying chime"."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "stores",
		"STOCK_EMPTY", "", 10), "the first depletion is recorded")
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "stores",
		"STOCK_EMPTY", "", 40), "the repeat is accepted")
	assert_equal(_notices.count(), 1, "and adds no second row")
	assert_true(_notices.notice_into(0, 0, _notice), "the row expands")
	assert_equal(_notice.occurrences, 2, "the occurrence count rose")
	assert_equal(_notice.first_tick, 10, "the first tick is unchanged")
	assert_equal(_notice.last_tick, 40, "and the last-seen tick moved")


func test_two_different_sources_of_one_code_stay_two_notices() -> void:
	"""§7 groups on code AND source; two items running out are two conditions."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "ration",
		"STOCK_EMPTY", "", 1), "the first item is recorded")
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of grain!", "grain",
		"STOCK_EMPTY", "", 2), "the second item is recorded")
	assert_equal(_notices.count(), 2, "both are retained separately")


func test_two_uncoded_messages_never_overwrite_each_other() -> void:
	"""With no code to group on, two different sentences are two different conditions."""
	assert_true(_notices.push(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "Mossflower stirs.",
		"", "", "", 1), "the first line is recorded")
	assert_true(_notices.push(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "The hearth is lit.",
		"", "", "", 2), "the second line is recorded")
	assert_equal(_notices.count(), 2, "neither replaces the other")


func test_the_top_card_is_the_highest_severity_then_the_earliest() -> void:
	"""§7: "Order active cards by severity descending, then earliest tick, then notice ID"."""
	assert_true(_notices.push(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "Mossflower stirs.",
		"", "", "", 1), "an Info notice is recorded first")
	assert_true(_notices.push(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		"world", "WORLD_OCCUPIED", "", 9), "and an Error notice after it")
	var top: IntMath.IntResult = _notices.top_active()
	assert_true(top.ok, "a card is selected")
	assert_true(_notices.notice_into(top.value, 0, _notice), "and expands")
	assert_equal(_notice.severity, UiNotices.SEVERITY_ERROR, "the Error outranks the Info")
	assert_true(_notices.push(UiNotices.CATEGORY_ACTION_REFUSED, "A later refusal.",
		"queue", "LATER", "", 20), "a second Error arrives later")
	assert_true(_notices.notice_into(_notices.top_active().value, 0, _notice), "the top expands")
	assert_equal(_notice.message, THREE_LINE_REFUSAL, "the earlier Error keeps the card")


func test_resolving_a_condition_keeps_it_in_the_history() -> void:
	"""§7: "history retained". Resolution changes the active set, never the record."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "ration",
		"STOCK_EMPTY", "", 1), "the depletion is recorded")
	assert_true(_notices.resolve(0), "it resolves")
	assert_equal(_notices.active_count(), 0, "nothing is active")
	assert_equal(_notices.count(), 1, "but the history still holds it")
	assert_false(_notices.top_active().ok, "and no card is selected")


func test_resolved_notices_sort_below_active_ones() -> void:
	"""The expanded view lists what is still happening before what has finished."""
	assert_true(_notices.push(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		"world", "A", "", 1), "an Error is recorded first")
	assert_true(_notices.push(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "Mossflower stirs.",
		"", "", "", 2), "an Info after it")
	assert_true(_notices.resolve(0), "the Error resolves")
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(_notices.capacity())
	assert_equal(_notices.order_into(order), 2, "both rows are ordered")
	assert_true(_notices.notice_into(order[0], 0, _notice), "the first row expands")
	assert_equal(_notice.message, "Mossflower stirs.", "the active Info leads")


# --- refusals are explicit, and never a sentinel --------------------------------------------------

func test_an_unknown_category_is_refused_by_name() -> void:
	"""A category outside the authored table has no summary, so no notice is invented for it."""
	assert_false(_notices.push(UiNotices.CATEGORY_COUNT, "text", "", "", "", 0),
		"an out-of-range category is refused")
	assert_equal(_notices.last_refusal(), UiNotices.REFUSE_UNKNOWN_CATEGORY, "by name")
	assert_equal(_notices.count(), 0, "and nothing is recorded")


func test_an_empty_message_is_refused_rather_than_stored_as_a_blank_notice() -> void:
	"""A notice with no message discloses nothing, so it is not a notice."""
	assert_false(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "", "", "", "", 0),
		"an empty message is refused")
	assert_equal(_notices.last_refusal(), UiNotices.REFUSE_EMPTY_MESSAGE, "by name")


func test_reading_a_row_that_does_not_exist_is_refused_and_leaves_no_stale_notice() -> void:
	"""`notice_into()` must not return the previous notice when asked for a missing one."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!", "r", "S", "", 1),
		"one notice exists")
	assert_true(_notices.notice_into(0, 0, _notice), "which expands")
	assert_false(_notices.notice_into(7, 0, _notice), "row 7 does not exist")
	assert_equal(_notices.last_refusal(), UiNotices.REFUSE_UNKNOWN_INDEX, "and is refused by name")
	assert_equal(_notice.message, "", "leaving no stale message behind")
	assert_equal(_notice.index, -1, "and no stale index")


func test_an_empty_record_refuses_a_top_card_instead_of_answering_zero() -> void:
	"""Index 0 is a real row, so "nothing active" cannot be reported as an index."""
	assert_false(_notices.top_active().ok, "an empty record has no top card")
	assert_equal(_notices.last_refusal(), UiNotices.REFUSE_NONE_ACTIVE, "and says so by name")


func test_a_full_record_of_live_conditions_refuses_rather_than_evicting_by_an_unstated_rule() -> void:
	"""§7 states two eviction tiers, both of which need a RESOLVED row. Neither applies here."""
	for index: int in UiNotices.HISTORY_CAP:
		assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Out of item %d!" % index,
			"item%d" % index, "STOCK_EMPTY", "", index), "notice %d is recorded" % index)
	assert_false(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "one too many", "extra",
		"STOCK_EMPTY", "", 1), "the 501st live condition is refused")
	assert_equal(_notices.last_refusal(), UiNotices.REFUSE_HISTORY_FULL, "by its named code")
	assert_true(_notices.resolve(0), "resolving the oldest makes room")
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "one too many", "extra",
		"STOCK_EMPTY", "", 1), "and the notice is then accepted")
	assert_equal(_notices.count(), UiNotices.HISTORY_CAP, "with the cap still held")


func test_the_oldest_resolved_info_is_evicted_before_a_resolved_warning() -> void:
	"""§7: "evicts oldest resolved INFO first, then oldest resolved higher severity"."""
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "A warning.", "w", "W", "", 1),
		"a Warning is recorded first")
	assert_true(_notices.push(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "An info.", "", "", "", 2),
		"an Info after it")
	assert_true(_notices.resolve(0), "the Warning resolves")
	assert_true(_notices.resolve(1), "and so does the Info")
	for index: int in UiNotices.HISTORY_CAP - 2:
		assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "Filler %d" % index,
			"f%d" % index, "F%d" % index, "", 100 + index), "filler %d is recorded" % index)
	assert_true(_notices.push(UiNotices.CATEGORY_STOCK_EMPTY, "The newest.", "n", "N", "", 999),
		"one more evicts the resolved INFO")
	assert_false(_retained_messages().has("An info."), "the resolved INFO went first")
	assert_true(_retained_messages().has("A warning."), "the resolved Warning stayed")


func _retained_messages() -> PackedStringArray:
	"""Every retained message, for asserting what eviction did and did not remove."""
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(_notices.capacity())
	var written: int = _notices.order_into(order)
	var out: PackedStringArray = PackedStringArray()
	for index: int in written:
		if _notices.notice_into(order[index], 0, _notice):
			out.append(_notice.message)
	return out
