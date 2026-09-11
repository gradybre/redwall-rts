extends "res://test/framework/test_case.gd"
## Coverage for §8.2's keyboard focus order and §3's Escape ladder.
##
## §8.2 gives the order as one sentence, quoted in the constants below, and §3 gives the Escape
## priority as another. Both are transcribed here independently of `ui_focus_order.gd`, so a
## reordered table fails rather than agreeing with itself.
##
## The property worth the most is the one §3 states negatively: "Closing a modal does not also
## clear selection in the same key press." One Escape press resolves EXACTLY ONE level, which is
## checked below with several layers open at once.

const UiFocusOrder := preload("res://scripts/ui/ui_focus_order.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")

## §8.2's stated order, as §4 element ids: world access, resources, alerts, time, minimap,
## commands, detail.
const EXPECTED_ORDER: Array[int] = [
	87,
	2, 3, 4, 5, 6, 7, 8,
	11, 102,
	14, 15, 16, 17, 101, 19,
	22, 21, 89,
	27, 28, 29, 30, 31, 32, 33,
	37, 38,
]

var _order: UiFocusOrder = null
var _availability: UiAvailability = null
var _buffer: PackedInt32Array = PackedInt32Array()


func before_each() -> void:
	"""Build the focus order over the real availability claim, with a buffer big enough."""
	_availability = UiAvailability.new()
	_order = UiFocusOrder.new(_availability)
	_buffer = PackedInt32Array()
	_buffer.resize(EXPECTED_ORDER.size())


func after_each() -> void:
	"""Drop everything so nothing crosses a test boundary."""
	_order = null
	_availability = null
	_buffer = PackedInt32Array()


# --- §8.2's order --------------------------------------------------------------------------------

func test_the_hud_order_is_the_one_section_eight_two_states() -> void:
	"""World access first, then resources, alerts, time, minimap, commands, detail."""
	var written: int = _order.sequence_into(true, _buffer)
	assert_equal(written, EXPECTED_ORDER.size(), "every stop is written")
	for index: int in EXPECTED_ORDER.size():
		assert_equal(_buffer[index], EXPECTED_ORDER[index],
			"stop %d is UI-SET-%03d" % [index, EXPECTED_ORDER[index]])


func test_the_world_access_shortcut_comes_before_every_hud_control() -> void:
	"""§8.2 puts F6 first so a keyboard user reaches the world before the chrome."""
	assert_equal(_order.position_of(87).value, 0, "UI-SET-087 is the first stop")
	assert_true(_order.position_of(2).value > _order.position_of(87).value,
		"the resource counters follow it")
	assert_true(_order.position_of(14).value > _order.position_of(11).value,
		"the time controls follow the alerts")
	assert_true(_order.position_of(37).value > _order.position_of(28).value,
		"and the detail panel comes last, after the commands")


func test_tab_and_shift_tab_walk_the_order_in_both_directions() -> void:
	"""Next and previous must be exact inverses inside the order."""
	assert_equal(_order.next_after(87).value, 2, "Tab from world access reaches the food counter")
	assert_equal(_order.previous_before(2).value, 87, "and Shift+Tab comes back")
	assert_equal(_order.next_after(17).value, 101, "Tab from 4x speed reaches the date trigger")
	assert_equal(_order.previous_before(101).value, 17, "and back again")


func test_the_ends_of_the_order_refuse_rather_than_wrapping() -> void:
	"""§8.2 gives a linear order; wrapping would be this module's invention."""
	assert_false(_order.previous_before(87).ok, "there is nothing before the first stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_AT_START, "with NO_PREVIOUS")
	assert_false(_order.next_after(38).ok, "there is nothing after the last stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_AT_END, "with NO_NEXT")


func test_an_element_outside_the_order_is_refused() -> void:
	"""A control with no stop in §8.2's sentence has no position to report."""
	assert_false(_order.position_of(54).ok, "the placement ghost is not a tab stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NOT_IN_ORDER, "with NOT_IN_ORDER")


# --- unavailable controls keep their stop ------------------------------------------------------

func test_unavailable_controls_stay_in_the_order_so_they_can_explain_themselves() -> void:
	"""§2.2: "Locked controls explain unlock requirements without requiring hover"."""
	assert_false(_availability.is_wired(3), "the fuel counter is unavailable")
	assert_true(_order.position_of(3).ok, "and it still has a keyboard stop")
	assert_equal(_order.sequence_length(true), EXPECTED_ORDER.size(),
		"the full order keeps every stop")


func test_the_activatable_filter_drops_exactly_the_unavailable_controls() -> void:
	"""The narrower question -- what can actually be activated -- excludes the excused."""
	var wired_only: int = _order.sequence_length(false)
	assert_true(wired_only < EXPECTED_ORDER.size(), "some stops are not activatable")
	var written: int = _order.sequence_into(false, _buffer)
	assert_equal(written, wired_only, "the filtered write agrees with the filtered length")
	for index: int in written:
		assert_true(_availability.is_wired(_buffer[index]),
			"UI-SET-%03d is activatable" % _buffer[index])


func test_a_buffer_smaller_than_the_order_reports_what_fit() -> void:
	"""The caller's buffer is never resized, so the count is how the caller learns it was short."""
	var small: PackedInt32Array = PackedInt32Array()
	small.resize(3)
	var written: int = _order.sequence_into(true, small)
	assert_equal(written, 3, "only three stops fit")
	assert_equal(small[0], EXPECTED_ORDER[0], "and they are the first three, in order")
	assert_equal(small[2], EXPECTED_ORDER[2], "third stop is in place")


# --- §3's Escape ladder ---------------------------------------------------------------------------

func test_escape_resolves_exactly_one_layer_per_press() -> void:
	"""§3: "Closing a modal does not also clear selection in the same key press"."""
	var mask: int = UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_WORKSPACE) \
		| UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_DETAIL) \
		| UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_SELECTION)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_WORKSPACE,
		"the workspace closes first")
	mask &= ~UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_WORKSPACE)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_DETAIL,
		"then the detail panel, on the next press")
	mask &= ~UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_DETAIL)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_SELECTION,
		"and only then is the selection cleared")


func test_the_ladder_follows_section_threes_stated_priority() -> void:
	"""Rebind capture beats the quick menu, which beats a tool stroke, and so on down."""
	var all_open: int = 0
	for level: int in UiFocusOrder.DISMISS_COUNT:
		all_open |= UiFocusOrder.dismissal_bit(level)
	assert_equal(_order.next_dismissal(all_open).value, UiFocusOrder.DISMISS_REBIND_CAPTURE,
		"rebind capture is cancelled first")
	var without_rebind: int = all_open & ~UiFocusOrder.dismissal_bit(
		UiFocusOrder.DISMISS_REBIND_CAPTURE)
	assert_equal(_order.next_dismissal(without_rebind).value, UiFocusOrder.DISMISS_QUICK_MENU,
		"then the quick menu")
	var tool_only: int = UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_TOOL_STROKE)
	assert_equal(_order.next_dismissal(tool_only).value, UiFocusOrder.DISMISS_TOOL_STROKE,
		"a lone tool stroke is cancelled on its own")


func test_an_empty_dismissal_stack_opens_the_game_menu() -> void:
	"""§3's documented fall-through: "open game menu" when nothing is open to dismiss."""
	assert_equal(_order.next_dismissal(0).value, UiFocusOrder.DISMISS_OPEN_MENU,
		"Escape with nothing open opens the menu")
	assert_equal(_order.dismissal_key(UiFocusOrder.DISMISS_OPEN_MENU), &"open_game_menu",
		"and the level carries its stable action key")


func test_every_ladder_level_is_named_and_an_unknown_one_refuses() -> void:
	"""Eight levels, eight keys; a ninth has no name to return."""
	for level: int in UiFocusOrder.DISMISS_COUNT:
		assert_false(String(_order.dismissal_key(level)).is_empty(), "level %d is named" % level)
	assert_equal(_order.dismissal_key(UiFocusOrder.DISMISS_COUNT), &"", "there is no ninth level")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_UNKNOWN_LEVEL,
		"and asking for one refuses")
