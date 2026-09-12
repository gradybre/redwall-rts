extends "res://test/framework/test_case.gd"
## Coverage for §1.2's layout arithmetic, checked against the numbers §1.2 publishes itself.
##
## §1.2 does not only give equations; it gives their ANSWERS at two viewports: "At 1280x720
## default scale: resources x16..376; alerts x460..820; time x960..1264; minimap x16..224,
## y464..704; detail x928..1264, y128..704; commands with detail x256..896, y568..704. These
## rectangles do not overlap." and "At the minimum tested logical width 853.33 (1280 pixels with
## 1.5x user scale), open-detail available width 309.33, so it still fits."
##
## Those published spans are the anchors below. An equation mistyped in `ui_layout.gd` moves at
## least one of them, and no amount of internal consistency hides that, because this file states
## the expected edges independently.
##
## UX-T01 is also checked here in full: "At 1280x720,1920x1080,3840x2160 and 100/125/150 user
## scale, all active HUD rectangles remain inbounds; commands and detail/minimap do not overlap"
## -- all nine combinations, with the detail panel both open and closed.

const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## §1.2's own worked example at 1280x720, default scale: left and right, top and bottom edges.
const SPAN_RESOURCES: Array[float] = [16.0, 376.0, 16.0, 104.0]
const SPAN_ALERTS: Array[float] = [460.0, 820.0, 16.0, 112.0]
const SPAN_TIME: Array[float] = [960.0, 1264.0, 16.0, 104.0]
const SPAN_MINIMAP: Array[float] = [16.0, 224.0, 464.0, 704.0]
const SPAN_DETAIL: Array[float] = [928.0, 1264.0, 128.0, 704.0]
const SPAN_COMMANDS: Array[float] = [256.0, 896.0, 568.0, 704.0]

## §1.2's minimum tested logical width and the open-detail command width it states.
const MINIMUM_LOGICAL_WIDTH: float = 853.33
const MINIMUM_AVAILABLE_WIDTH: float = 309.33
const SPAN_EPSILON: float = 0.02

const SUPPORTED_SIZES: Array = [[1280, 720], [1920, 1080], [3840, 2160]]
const USER_SCALES: Array[int] = [100, 125, 150]

var _layout: UiLayout = null
var _geometry: UiLayout.Geometry = null
var _stack: UiLayout.Stack = null


func before_each() -> void:
	"""Build the layout, one reusable geometry record and one reusable alert stack."""
	_layout = UiLayout.new()
	_geometry = UiLayout.Geometry.new()
	_stack = UiLayout.Stack.new()


func after_each() -> void:
	"""Drop all three so nothing crosses a test boundary."""
	_layout = null
	_geometry = null
	_stack = null


# --- helpers ------------------------------------------------------------------------------------

func _assert_span(rect: Rect2, span: Array[float], element: String) -> void:
	"""Compare a rectangle's four edges against §1.2's published span for it."""
	assert_almost_equal(rect.position.x, span[0], "%s left edge" % element)
	assert_almost_equal(rect.position.x + rect.size.x, span[1], "%s right edge" % element)
	assert_almost_equal(rect.position.y, span[2], "%s top edge" % element)
	assert_almost_equal(rect.position.y + rect.size.y, span[3], "%s bottom edge" % element)


func _overlaps(first: Rect2, second: Rect2) -> bool:
	"""True when two rectangles share any area at all."""
	return first.intersects(second)


# --- §1.2's scale equations -----------------------------------------------------------------------

func test_base_scale_is_clamped_between_one_and_two() -> void:
	"""`clamp(min(W/1920,H/1080),1,2)`: 1 below the reference, 2 at 4K, never outside."""
	assert_almost_equal(UiLayout.base_scale(1280, 720), 1.0, "1280x720 clamps up to 1")
	assert_almost_equal(UiLayout.base_scale(1920, 1080), 1.0, "the reference viewport is 1")
	assert_almost_equal(UiLayout.base_scale(3840, 2160), 2.0, "3840x2160 is exactly 2")
	assert_almost_equal(UiLayout.base_scale(7680, 4320), 2.0, "and it never exceeds 2")


func test_effective_scale_multiplies_the_user_scale_in() -> void:
	"""S = base x user scale, with the user scale carried as an exact integer percent."""
	assert_almost_equal(UiLayout.effective_scale(1920, 1080, 100), 1.0, "100 percent is 1.0")
	assert_almost_equal(UiLayout.effective_scale(1920, 1080, 125), 1.25, "125 percent is 1.25")
	assert_almost_equal(UiLayout.effective_scale(3840, 2160, 150), 3.0, "2 x 1.5 is 3.0")


func test_the_three_breakpoints_are_the_documented_logical_widths() -> void:
	"""Wide at Lw>=1600, Standard at 1120<=Lw<1600, Narrow below 1120."""
	assert_equal(UiLayout.profile_for(1600.0), UiLayout.PROFILE_WIDE, "1600 is wide")
	assert_equal(UiLayout.profile_for(1599.9), UiLayout.PROFILE_STANDARD, "just below is standard")
	assert_equal(UiLayout.profile_for(1120.0), UiLayout.PROFILE_STANDARD, "1120 is standard")
	assert_equal(UiLayout.profile_for(1119.9), UiLayout.PROFILE_NARROW, "just below is narrow")
	assert_equal(UiLayout.profile_for(MINIMUM_LOGICAL_WIDTH), UiLayout.PROFILE_NARROW,
		"the minimum tested logical width is narrow")


# --- §1.2's published rectangles ------------------------------------------------------------------

func test_the_1280_by_720_composition_matches_every_published_span() -> void:
	"""§1.2 states all six spans at 1280x720 default scale; each must land on the pixel."""
	assert_true(_layout.compute_into(1280, 720, 100, true, _geometry), "the geometry computes")
	assert_equal(_geometry.profile, UiLayout.PROFILE_STANDARD, "1280 logical is the standard layout")
	_assert_span(_geometry.resources, SPAN_RESOURCES, "resources")
	_assert_span(_geometry.alerts, SPAN_ALERTS, "alerts")
	_assert_span(_geometry.time, SPAN_TIME, "time")
	_assert_span(_geometry.minimap, SPAN_MINIMAP, "minimap")
	_assert_span(_geometry.detail, SPAN_DETAIL, "detail")
	_assert_span(_geometry.commands, SPAN_COMMANDS, "commands")


func test_those_rectangles_do_not_overlap() -> void:
	"""§1.2 closes the worked example with "These rectangles do not overlap"."""
	assert_true(_layout.compute_into(1280, 720, 100, true, _geometry), "the geometry computes")
	assert_false(_overlaps(_geometry.resources, _geometry.alerts), "resources clear of alerts")
	assert_false(_overlaps(_geometry.alerts, _geometry.time), "alerts clear of the time cluster")
	assert_false(_overlaps(_geometry.minimap, _geometry.commands), "minimap clear of commands")
	assert_false(_overlaps(_geometry.commands, _geometry.detail), "commands clear of detail")
	assert_false(_overlaps(_geometry.minimap, _geometry.detail), "minimap clear of detail")


func test_the_minimum_tested_logical_width_still_fits_the_command_strip() -> void:
	"""1280 px at 150 percent gives Lw 853.33 and an open-detail command width of 309.33."""
	assert_true(_layout.compute_into(1280, 720, 150, true, _geometry), "the geometry computes")
	assert_true(absf(_geometry.logical_width - MINIMUM_LOGICAL_WIDTH) < SPAN_EPSILON,
		"Lw is 853.33, got %f" % _geometry.logical_width)
	assert_true(absf(_geometry.commands.size.x - MINIMUM_AVAILABLE_WIDTH) < SPAN_EPSILON,
		"the command strip is 309.33 wide, got %f" % _geometry.commands.size.x)
	assert_false(_geometry.commands_below_minimum,
		"which is above §1.2's minimum command width of 240")


# --- UX-T01: all nine combinations -----------------------------------------------------------------

func test_every_supported_viewport_and_scale_keeps_the_hud_in_bounds() -> void:
	"""UX-T01, first half: all active HUD rectangles remain inbounds at all nine combinations."""
	for size: Array in SUPPORTED_SIZES:
		for scale: int in USER_SCALES:
			assert_true(_layout.compute_into(size[0], size[1], scale, true, _geometry),
				"%dx%d at %d percent computes" % [size[0], size[1], scale])
			_assert_in_bounds("%dx%d@%d" % [size[0], size[1], scale])


func _assert_in_bounds(label: String) -> void:
	"""Every permanent rectangle must sit inside the logical viewport."""
	var rects: Array[Rect2] = [_geometry.resources, _geometry.time, _geometry.alerts,
		_geometry.minimap, _geometry.detail, _geometry.commands, _geometry.modal]
	var viewport: Rect2 = Rect2(0.0, 0.0, _geometry.logical_width, _geometry.logical_height)
	for rect: Rect2 in rects:
		assert_true(rect.position.x >= -SPAN_EPSILON and rect.position.y >= -SPAN_EPSILON,
			"%s: a rectangle starts inside the viewport" % label)
		assert_true(rect.position.x + rect.size.x <= viewport.size.x + SPAN_EPSILON,
			"%s: a rectangle ends inside the viewport width" % label)
		assert_true(rect.position.y + rect.size.y <= viewport.size.y + SPAN_EPSILON,
			"%s: a rectangle ends inside the viewport height" % label)


func test_commands_never_overlap_the_detail_panel_or_the_minimap() -> void:
	"""UX-T01, second half, with the detail panel both open and closed."""
	for size: Array in SUPPORTED_SIZES:
		for scale: int in USER_SCALES:
			for open_detail: bool in [false, true]:
				assert_true(_layout.compute_into(size[0], size[1], scale, open_detail, _geometry),
					"%dx%d at %d percent computes" % [size[0], size[1], scale])
				assert_false(_overlaps(_geometry.commands, _geometry.minimap),
					"commands clear of the minimap at %dx%d@%d" % [size[0], size[1], scale])
				if open_detail:
					assert_false(_overlaps(_geometry.commands, _geometry.detail),
						"commands clear of detail at %dx%d@%d" % [size[0], size[1], scale])


# --- refusals ---------------------------------------------------------------------------------------

func test_an_unsupported_user_scale_is_refused_rather_than_rounded() -> void:
	"""§1.2 gives three user scales; a fourth has no defined composition."""
	assert_false(_layout.compute_into(1920, 1080, 110, false, _geometry), "110 percent refuses")
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_USER_SCALE, "with UNSUPPORTED_USER_SCALE")
	assert_almost_equal(_geometry.logical_width, 0.0, "and leaves no geometry behind")


func test_a_viewport_below_the_supported_floor_is_refused_not_clamped() -> void:
	"""The supported range starts at 1280x720; below it the composition is undefined."""
	assert_false(_layout.compute_into(1024, 768, 100, false, _geometry), "1024x768 refuses")
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_VIEWPORT_BELOW_SUPPORTED,
		"with VIEWPORT_BELOW_SUPPORTED_RANGE")
	assert_false(_layout.compute_into(1280, 719, 100, false, _geometry), "one pixel short refuses")


# --- cluster interiors ------------------------------------------------------------------------------

func test_the_resource_cluster_lays_out_six_counters_in_three_columns() -> void:
	"""§1.2: three columns, two 36-high rows at y8 and y44, gap 8, width min(144,(R-32)/3)."""
	var width: float = UiLayout.counter_width(480.0)
	assert_almost_equal(width, 144.0, "a wide cluster caps the counter width at 144")
	assert_almost_equal(UiLayout.counter_width(360.0), 109.3333, "a standard cluster is (360-32)/3")
	var first: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 0)
	var fourth: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 3)
	assert_almost_equal(first.position.x, 8.0, "the first cell starts at the 8 px frame padding")
	assert_almost_equal(first.position.y, 8.0, "the first row is at y8")
	assert_almost_equal(fourth.position.x, 8.0, "the fourth cell starts a new column run")
	assert_almost_equal(fourth.position.y, 44.0, "the second row is at y44")
	assert_almost_equal(first.size.y, 36.0, "each row is 36 high")


func test_a_seventh_counter_cell_is_refused_rather_than_placed_outside() -> void:
	"""Six cells fit §1.2's grid; there is no seventh position to invent."""
	assert_equal(UiLayout.counter_cell_count(UiLayout.PROFILE_WIDE), 6, "six cells when wide")
	assert_equal(UiLayout.counter_cell_count(UiLayout.PROFILE_NARROW), 2, "§1.3 gives narrow two")
	var refused: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 6)
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_INVALID_INDEX, "the seventh refuses")
	assert_almost_equal(refused.size.x, 0.0, "and no rectangle is returned")


func test_the_narrow_time_row_fits_its_256_pixel_cluster() -> void:
	"""§1.3: Pause 44, three speeds 36, calendar 36, menu 36, gaps 4, padding 4 -- total 252."""
	var last: Rect2 = _layout.time_control(UiLayout.PROFILE_NARROW, 5)
	assert_almost_equal(last.position.x + last.size.x + UiLayout.NARROW_TIME_PADDING,
		UiLayout.NARROW_TIME_TOTAL,
		"4 padding + 44 + five 36s + five 4 gaps + 4 padding is §1.3's stated 252")
	assert_true(UiLayout.NARROW_TIME_TOTAL <= float(UiLayout.TIME_W[UiLayout.PROFILE_NARROW]),
		"which fits inside the 256-wide narrow cluster")
	var first: Rect2 = _layout.time_control(UiLayout.PROFILE_NARROW, 0)
	assert_almost_equal(first.position.x, 4.0, "the row starts at the 4 px narrow padding")
	assert_almost_equal(first.size.x, 44.0, "and Pause is 44 wide")


func test_the_standard_time_cluster_uses_two_rows() -> void:
	"""§1.2: row 1 holds Pause and three speeds; row 2 holds the date and the menu."""
	assert_almost_equal(_layout.time_control(UiLayout.PROFILE_STANDARD, 0).position.y, 8.0,
		"Pause is in row 1")
	assert_almost_equal(_layout.time_control(UiLayout.PROFILE_STANDARD, 3).position.y, 8.0,
		"the 4x speed is still in row 1")
	assert_almost_equal(_layout.time_control(UiLayout.PROFILE_STANDARD, 4).position.y, 44.0,
		"the date trigger is in row 2")
	assert_almost_equal(_layout.time_control(UiLayout.PROFILE_STANDARD, 5).position.y, 44.0,
		"and so is the menu button")


func test_the_alert_stack_fits_two_cards_and_keeps_its_history_rail() -> void:
	"""§1.2: padding 2, two 44-high cards plus a 4 px gap fit 96; the rail is 36 px wide."""
	var second: Rect2 = _layout.alert_card(UiLayout.PROFILE_WIDE, 420.0, 1)
	assert_almost_equal(second.position.y + second.size.y, 94.0, "two cards end within 96")
	assert_almost_equal(second.size.x, 380.0, "each card is A-40 wide")
	assert_equal(UiLayout.alert_card_count(UiLayout.PROFILE_NARROW), 1, "§7 gives narrow one card")
	var trigger: Rect2 = UiLayout.history_trigger_rect(420.0)
	assert_almost_equal(trigger.size.x, 32.0, "the history trigger is 32 wide")
	assert_true(trigger.position.x >= 420.0 - 36.0, "and sits in the right 36 px rail")


func test_the_narrow_alert_zone_holds_exactly_one_card_at_y_seventy_six() -> void:
	"""R-UI-ALERT-001: "retain the NARROW alerts zone at y=76 and height=48 ... one 44-high card".

	The ruling forbids growing the zone over another HUD zone, so this asserts the numbers it
	names rather than only that a card fits. A change that quietly enlarged NARROW to fix the
	overflow would fail here before it reached a screenshot.
	"""
	assert_true(_layout.compute_into(1280, 720, 150, false, _geometry), "the narrow layout computes")
	assert_equal(_geometry.profile, UiLayout.PROFILE_NARROW, "1280 at 150% is NARROW")
	assert_almost_equal(_geometry.alerts.position.y, 76.0, "the zone stays at y=76")
	assert_almost_equal(_geometry.alerts.size.y, 48.0, "and 48 logical pixels high")
	var measured: PackedFloat32Array = PackedFloat32Array([200.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_NARROW, _geometry.alerts.size.x,
		measured, _stack), "the stack computes")
	assert_equal(_stack.visible_count, 1, "one card is placed")
	assert_almost_equal(_stack.rects[0].size.y, 44.0, "44 high however tall its content measures")
	assert_almost_equal(_stack.rects[0].position.y + _stack.rects[0].size.y, 46.0,
		"and it ends inside the 48 px zone")
	assert_equal(_stack.summarised[0], 1, "so it must draw the authored summary")


func test_a_narrow_card_summarises_even_when_its_content_would_fit() -> void:
	"""The ruling makes the NARROW card the summary presentation, not a length-dependent one.

	A card that showed the message verbatim whenever it happened to be short would announce
	different things for the same condition depending on the sentence, which is exactly the
	unpredictability the authored table exists to remove.
	"""
	var measured: PackedFloat32Array = PackedFloat32Array([20.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_NARROW, 360.0, measured, _stack),
		"a short card computes")
	assert_equal(_stack.summarised[0], 1, "and still draws the authored summary")


func test_two_long_standard_cards_cannot_overlap() -> void:
	"""R-UI-ALERT-001's acceptance case: two long wide/standard cards cannot overlap.

	Both cards measure taller than the whole zone. The old rule grew each independently against
	the stack ceiling while keeping fixed row origins, which is precisely how they came to draw
	over one another; here the cursor advances by the height actually granted.
	"""
	var measured: PackedFloat32Array = PackedFloat32Array([400.0, 400.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_STANDARD, 360.0, measured, _stack),
		"the stack computes")
	for index: int in _stack.visible_count:
		var card: Rect2 = _stack.rects[index]
		assert_true(card.position.y >= UiLayout.ALERT_PADDING, "card %d starts inside the zone" % index)
		assert_true(card.position.y + card.size.y <= 96.0 - UiLayout.ALERT_PADDING,
			"card %d ends inside the 96 px zone" % index)
	if _stack.visible_count == 2:
		assert_true(_stack.rects[0].position.y + _stack.rects[0].size.y
			<= _stack.rects[1].position.y, "the first card ends before the second begins")
	assert_true(_stack.visible_count >= 1, "at least one card is shown")


func test_a_card_that_fills_the_zone_leaves_no_room_for_a_second_one() -> void:
	""""Their visible-card limit is a maximum, not a requirement to overlap ... show fewer"."""
	var measured: PackedFloat32Array = PackedFloat32Array([92.0, 44.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, _stack),
		"the stack computes")
	assert_equal(_stack.visible_count, 1, "the second card is not placed at all")
	assert_almost_equal(_stack.rects[0].size.y, 92.0, "the first card takes the whole interior")
	assert_equal(_stack.summarised[0], 0, "and shows its full content")


func test_two_short_cards_keep_the_existing_wide_composition() -> void:
	"""Wide and standard "retain their existing layouts when content fits"."""
	var measured: PackedFloat32Array = PackedFloat32Array([44.0, 44.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, _stack),
		"the stack computes")
	assert_equal(_stack.visible_count, 2, "both cards are shown")
	assert_almost_equal(_stack.rects[1].position.y + _stack.rects[1].size.y, 94.0,
		"and the pair still ends at §1.2's 94")
	assert_equal(_stack.summarised[1], 0, "neither has to summarise")


func test_the_summary_interior_accounts_for_the_icon_the_gaps_and_the_rail() -> void:
	"""The ruling requires the compact line measured "with its real icon/gaps/rail accounted for".

	360 alert width, less §1.2's 40 px card margin (which holds the 36 px history rail), less
	two 12 px paddings, less the 24 px severity icon and its 8 px grid gap, is 264.
	"""
	assert_almost_equal(UiLayout.alert_summary_width(UiLayout.PROFILE_NARROW, 360.0), 264.0,
		"the narrow card gives a summary 264 logical pixels")
	assert_almost_equal(UiLayout.alert_summary_width(UiLayout.PROFILE_WIDE, 420.0), 324.0,
		"and the wide card 324")
	var card: Rect2 = _layout.alert_card(UiLayout.PROFILE_NARROW, 360.0, 0)
	assert_true(UiLayout.alert_summary_width(UiLayout.PROFILE_NARROW, 360.0) < card.size.x,
		"the text interior is narrower than the card that holds it")


func test_the_alert_stack_refuses_a_profile_it_has_no_zone_for() -> void:
	"""No rectangle is invented for a profile §1.2 does not define."""
	var measured: PackedFloat32Array = PackedFloat32Array([44.0])
	assert_false(_layout.alert_stack_into(UiLayout.PROFILE_COUNT, 360.0, measured, _stack),
		"an unknown profile is refused")
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_INVALID_PROFILE, "by name")
	assert_equal(_stack.visible_count, 0, "and no card is placed")


func test_the_modal_frame_is_centred_and_capped() -> void:
	"""§1.2: width min(960,Lw-32), height min(720,Lh-32), centred in the logical viewport."""
	assert_true(_layout.compute_into(1920, 1080, 100, false, _geometry), "the geometry computes")
	assert_almost_equal(_geometry.modal.size.x, 960.0, "the width caps at 960")
	assert_almost_equal(_geometry.modal.size.y, 720.0, "the height caps at 720")
	assert_almost_equal(_geometry.modal.position.x, 480.0, "centred horizontally")
	assert_almost_equal(_geometry.modal.position.y, 180.0, "and vertically")
	assert_true(_layout.compute_into(1280, 720, 150, false, _geometry), "a narrow viewport computes")
	assert_almost_equal(_geometry.modal.size.y, 448.0, "a short viewport uses Lh-32")
