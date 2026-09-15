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
##
## MIGRATED BY UI-C3-R01, and only in the two bottom edges. §1.2 published `resources 16..104`
## and `alerts 16..112`; the ruling's §2 raises the resource frame to 128 high and its §3 raises
## the STANDARD/WIDE alert zone to 104, and its §4 states both consequences itself: "At all
## profiles the resource frame now ends at y144. Alerts end at 120 (Standard/Wide) or 124
## (Narrow); time keeps its existing geometry." Every other edge below is §1.2's, unchanged.
const SPAN_RESOURCES: Array[float] = [16.0, 376.0, 16.0, 144.0]
const SPAN_ALERTS: Array[float] = [460.0, 820.0, 16.0, 120.0]
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
	"""UI-C3-R01 §2: three columns, two 56-high rows at y8 and y64, gap 8, width min(144,(R-32)/3).

	MIGRATED. This asserted §1.2's "the second row is at y44" and "each row is 36 high". The
	ruling replaces both: "Standard/Wide retain three columns and two rows: local y=8,64 ...
	Replace the 36-high resource cells with 56-high readout buttons". The columns, the 8 px gap
	and the width formula are §1.2's and are asserted unchanged.
	"""
	var width: float = UiLayout.counter_width(480.0)
	assert_almost_equal(width, 144.0, "a wide cluster caps the counter width at 144")
	assert_almost_equal(UiLayout.counter_width(360.0), 109.3333, "a standard cluster is (360-32)/3")
	var first: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 0)
	var fourth: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 3)
	assert_almost_equal(first.position.x, 8.0, "the first cell starts at the 8 px frame padding")
	assert_almost_equal(first.position.y, 8.0, "the first row is at y8")
	assert_almost_equal(fourth.position.x, 8.0, "the fourth cell starts a new column run")
	assert_almost_equal(fourth.position.y, 64.0, "the second row is at y64")
	assert_almost_equal(first.size.y, 56.0, "each row is 56 high")
	assert_almost_equal(fourth.position.y + fourth.size.y + UiLayout.FRAME_PADDING,
		UiLayout.RESOURCE_HEIGHT, "and both rows plus the 8 px padding fill the 128 px frame")


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
	"""UI-C3-R01 §3: padding 2, two 48-high cards plus a 4 px gap fit 104; the rail is 36 px wide.

	MIGRATED. This asserted §1.2's "two cards end within 96" at 94. The ruling replaces the zone
	and the card floor together -- "STANDARD/WIDE outer alert height becomes 104 ... Minimum full
	or summary card height is 48 ... Two such full cards plus gap consume exactly 100" -- because
	a 44 px card cannot hold one 23 px line of body text beside a 24 px severity icon at the 12 px
	panel padding. The 2 px inset, the 4 px gap, the A-40 card width and the 36 px rail are §1.2's
	and are asserted unchanged.
	"""
	var second: Rect2 = _layout.alert_card(UiLayout.PROFILE_WIDE, 420.0, 1)
	assert_almost_equal(second.position.y + second.size.y, 102.0, "two cards end within 104")
	assert_almost_equal(second.size.y, 48.0, "each is the 48 px reachable minimum")
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
		measured, measured.size(), _stack), "the stack computes")
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
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_NARROW, 360.0, measured,
		measured.size(), _stack), "a short card computes")
	assert_equal(_stack.summarised[0], 1, "and still draws the authored summary")


func test_two_long_standard_cards_cannot_overlap() -> void:
	"""R-UI-ALERT-001's acceptance case: two long wide/standard cards cannot overlap.

	Both cards measure taller than the whole zone. The old rule grew each independently against
	the stack ceiling while keeping fixed row origins, which is precisely how they came to draw
	over one another; here the cursor advances by the height actually granted.
	"""
	var measured: PackedFloat32Array = PackedFloat32Array([400.0, 400.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_STANDARD, 360.0, measured,
		measured.size(), _stack), "the stack computes")
	for index: int in _stack.visible_count:
		var card: Rect2 = _stack.rects[index]
		assert_true(card.position.y >= UiLayout.ALERT_PADDING, "card %d starts inside the zone" % index)
		assert_true(card.position.y + card.size.y <= 104.0 - UiLayout.ALERT_PADDING,
			"card %d ends inside the 104 px zone" % index)
	if _stack.visible_count == 2:
		assert_true(_stack.rects[0].position.y + _stack.rects[0].size.y
			<= _stack.rects[1].position.y, "the first card ends before the second begins")
	assert_true(_stack.visible_count >= 1, "at least one card is shown")


func test_a_card_that_fills_the_zone_leaves_no_room_for_a_second_one() -> void:
	""""Their visible-card limit is a maximum, not a requirement to overlap ... show fewer"."""
	var measured: PackedFloat32Array = PackedFloat32Array([92.0, 44.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured,
		measured.size(), _stack), "the stack computes")
	assert_equal(_stack.visible_count, 1, "the second card is not placed at all")
	assert_almost_equal(_stack.rects[0].size.y, 92.0, "the first card takes the whole interior")
	assert_equal(_stack.summarised[0], 0, "and shows its full content")


func test_two_short_cards_keep_the_existing_wide_composition() -> void:
	"""Wide and standard "retain their existing layouts when content fits", at the new floor.

	MIGRATED. This asserted "the pair still ends at §1.2's 94" from two 44 px cards. UI-C3-R01 §3
	raises the floor to 48, so the same pair of short measurements is granted 48 each and the pair
	ends at 102 inside the 104 px zone: "Two such full cards plus gap consume exactly 100."
	"""
	var measured: PackedFloat32Array = PackedFloat32Array([44.0, 44.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured,
		measured.size(), _stack), "the stack computes")
	assert_equal(_stack.visible_count, 2, "both cards are shown")
	assert_almost_equal(_stack.rects[1].position.y + _stack.rects[1].size.y, 102.0,
		"and the pair ends at UI-C3-R01's 102")
	assert_almost_equal(_stack.rects[0].size.y, 48.0, "each granted the 48 px reachable minimum")
	assert_equal(_stack.summarised[1], 0, "neither has to summarise")


func test_alert_r02_packs_the_four_cases_its_consequences_list() -> void:
	"""UI-C3-R01 §3's own worked consequences, each as a measured pair and an expected shape.

	MIGRATED. This asserted ALERT-R02's four cases against a 92 px interior and a 44 px card:
	"two 44px full cards fit exactly 92px. A 44px first full card plus an oversized second gets a
	44px second summary. A 60px first full card appears alone. A first notice too large for 92px
	uses a summary; another card may then fit." §3 replaces that example in terms -- "This replaces
	ALERT-R02's unreachable two-44px-full-card example" -- and publishes its own: "48+4+48 fits;
	70+4+48 does not; a first full card of 101 becomes summary 48 and can admit a second 48." The
	PACKING RULES are unchanged; only the zone height and the card floor moved.
	"""
	_assert_pack([48.0, 48.0], 2, [0, 0], [48.0, 48.0], "48+4+48 fits")
	_assert_pack([70.0, 48.0], 1, [0], [70.0], "70+4+48 does not, so the 70 is alone")
	_assert_pack([101.0, 48.0], 2, [1, 0], [48.0, 48.0], "a 101 px first becomes a 48 summary")
	_assert_pack([48.0, 300.0], 2, [0, 1], [48.0, 48.0], "a full 48 and an oversized second")


func _assert_pack(measured_values: Array, expect_visible: int, expect_summarised: Array,
		expect_heights: Array, what: String) -> void:
	"""Pack one measured pair at WIDE and assert the card count, summaries and heights."""
	var measured: PackedFloat32Array = PackedFloat32Array(measured_values)
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured,
		measured.size(), _stack), "%s packs" % what)
	assert_equal(_stack.visible_count, expect_visible, "%s shows %d card(s)" % [what, expect_visible])
	for index: int in expect_visible:
		assert_equal(_stack.summarised[index], int(expect_summarised[index]),
			"%s: card %d summarised flag" % [what, index])
		assert_almost_equal(_stack.rects[index].size.y, float(expect_heights[index]),
			"%s: card %d height" % [what, index])
	if expect_visible == 2:
		assert_almost_equal(_stack.rects[1].position.y,
			_stack.rects[0].position.y + _stack.rects[0].size.y + UiLayout.ALERT_CARD_GAP,
			"%s: card 2 begins at card1_bottom + 4, not at a fixed origin" % what)


func test_the_narrow_zone_interior_is_one_card_so_its_ceiling_equals_its_floor() -> void:
	"""`ALERT_H` is [48,96,96]: NARROW's 44 px interior IS one card, so nothing can grow there.

	This is the arithmetic that makes the compact NARROW form a construction rather than a
	length-dependent fallback. If the interior ever exceeded the card height, a NARROW card
	could be granted room it has no zone for.
	"""
	assert_almost_equal(UiLayout.alert_zone_interior(UiLayout.PROFILE_NARROW),
		UiLayout.ALERT_CARD_HEIGHT, "the narrow interior is exactly one 44 px card")
	## MIGRATED: this asserted "standard leaves 92 for content" from §1.2's 96 px zone.
	## UI-C3-R01 §3: "Content height is 100."
	assert_almost_equal(UiLayout.alert_zone_interior(UiLayout.PROFILE_STANDARD), 100.0,
		"standard leaves 100 for content")
	assert_almost_equal(UiLayout.alert_zone_interior(UiLayout.PROFILE_WIDE), 100.0,
		"and so does wide")
	assert_almost_equal(UiLayout.alert_zone_interior(UiLayout.PROFILE_COUNT), 0.0,
		"an unknown profile has no interior to state")


func test_no_measured_content_makes_a_narrow_card_show_its_full_text() -> void:
	"""ALERT-R02: "NARROW always compact". Swept, so no single short value can slip through."""
	for height: float in [0.0, 1.0, 20.0, 43.0, 44.0, 45.0, 92.0, 400.0]:
		var measured: PackedFloat32Array = PackedFloat32Array([height, height])
		assert_true(_layout.alert_stack_into(UiLayout.PROFILE_NARROW, 360.0, measured,
			measured.size(), _stack), "a %.0f px measurement packs at NARROW" % height)
		assert_equal(_stack.visible_count, 1, "NARROW places exactly one card at %.0f" % height)
		assert_equal(_stack.summarised[0], 1,
			"and it is the authored summary at %.0f px measured" % height)
		assert_almost_equal(_stack.rects[0].size.y, UiLayout.ALERT_CARD_HEIGHT,
			"at the fixed 44 px row at %.0f" % height)


func test_no_packed_card_can_be_drawn_outside_its_own_zone() -> void:
	"""Swept containment: no rectangle may start above the inset or end past the zone height.

	This is the property a "grow each card against the whole ceiling" regression breaks, and it
	is swept rather than sampled because a single measured pair can pass by luck.
	"""
	var sizes: Array[float] = [0.0, 10.0, 44.0, 45.0, 47.0, 60.0, 88.0, 92.0, 93.0, 400.0]
	for profile: int in UiLayout.PROFILE_COUNT:
		for first: float in sizes:
			for second: float in sizes:
				_assert_contained(profile, PackedFloat32Array([first, second]))


func _assert_contained(profile: int, measured: PackedFloat32Array) -> void:
	"""Pack one measured pair and assert every placed card lies inside the zone, in order."""
	assert_true(_layout.alert_stack_into(profile, 360.0, measured, measured.size(), _stack),
		"profile %d packs %s" % [profile, measured])
	var limit: float = float(UiLayout.ALERT_H[profile]) - UiLayout.ALERT_PADDING
	var previous_bottom: float = UiLayout.ALERT_PADDING
	assert_true(_stack.visible_count <= UiLayout.alert_card_count(profile),
		"profile %d never exceeds its card budget" % profile)
	for index: int in _stack.visible_count:
		var card: Rect2 = _stack.rects[index]
		assert_true(card.position.y >= previous_bottom,
			"profile %d card %d starts at or below the previous bottom" % [profile, index])
		assert_true(card.position.y + card.size.y <= limit,
			"profile %d card %d ends inside the zone (%s of %.0f)" % [profile, index,
				card.position.y + card.size.y, limit])
		assert_true(card.size.y >= UiLayout.alert_card_min_height(profile),
			"profile %d card %d is never shorter than its own minimum row" % [profile, index])
		previous_bottom = card.position.y + card.size.y + UiLayout.ALERT_CARD_GAP


func test_the_stack_refuses_a_count_it_has_no_measurements_for() -> void:
	"""A count beyond the measured buffer is refused by name, never clamped into a guess."""
	var measured: PackedFloat32Array = PackedFloat32Array([44.0, 44.0])
	assert_false(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, 3, _stack),
		"three cards cannot be packed from two measurements")
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_ALERT_COUNT, "and it refuses by name")
	assert_equal(_stack.visible_count, 0, "with no card placed")
	assert_false(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, -1, _stack),
		"a negative count is refused too")
	assert_equal(_layout.last_refusal(), UiLayout.REFUSE_ALERT_COUNT, "by the same name")


func test_a_stack_asked_for_no_cards_places_none() -> void:
	"""An empty alert zone is a real state: no notice wants a card, so no card is drawn."""
	var measured: PackedFloat32Array = PackedFloat32Array([44.0, 44.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, 0, _stack),
		"packing nothing succeeds")
	assert_equal(_stack.visible_count, 0, "and places nothing")
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_WIDE, 420.0, measured, 1, _stack),
		"packing one succeeds")
	assert_equal(_stack.visible_count, 1, "and places exactly one")


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
	assert_false(_layout.alert_stack_into(UiLayout.PROFILE_COUNT, 360.0, measured,
		measured.size(), _stack), "an unknown profile is refused")
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


# --- UI-C3-R01 §2: the resource cell's measured interior --------------------------------------

func test_the_resource_frame_ends_at_y144_at_every_supported_profile() -> void:
	"""UI-C3-R01 §4: "At all profiles the resource frame now ends at y144"."""
	for size: Array in SUPPORTED_SIZES:
		for scale: int in USER_SCALES:
			assert_true(_layout.compute_into(size[0], size[1], scale, false, _geometry),
				"%dx%d at %d percent computes" % [size[0], size[1], scale])
			assert_almost_equal(_geometry.resources.position.y + _geometry.resources.size.y,
				144.0, "%dx%d@%d: the resource frame ends at y144" % [size[0], size[1], scale])
			assert_almost_equal(_geometry.resources.size.y, UiLayout.RESOURCE_HEIGHT,
				"%dx%d@%d: which is the 128 px frame" % [size[0], size[1], scale])


func test_the_time_cluster_did_not_grow_with_the_resource_frame() -> void:
	"""§4: "time keeps its existing geometry". The two 88s were one constant and are now two."""
	assert_true(_layout.compute_into(1280, 720, 100, false, _geometry), "the geometry computes")
	assert_almost_equal(_geometry.time.size.y, 88.0, "the standard time cluster is still 88 high")
	assert_true(_layout.compute_into(1280, 720, 150, false, _geometry), "narrow computes")
	assert_almost_equal(_geometry.time.size.y, 48.0, "and §1.3's narrow row is still 48")


func test_each_profile_reserves_the_authored_value_width_inside_its_cell() -> void:
	"""§2: "Value width is cell_width-8: Standard 101⅓, Wide 136, Narrow 96"."""
	var standard: Rect2 = _layout.counter_cell(UiLayout.PROFILE_STANDARD, 360.0, 0)
	var wide: Rect2 = _layout.counter_cell(UiLayout.PROFILE_WIDE, 480.0, 0)
	var narrow: Rect2 = _layout.counter_cell(UiLayout.PROFILE_NARROW, 176.0, 0)
	assert_almost_equal(UiLayout.resource_value_width(standard.size.x), 101.3333,
		"standard values get 101⅓")
	assert_almost_equal(UiLayout.resource_value_width(wide.size.x), 136.0, "wide values get 136")
	assert_almost_equal(UiLayout.resource_value_width(narrow.size.x), 96.0, "narrow values get 96")


func test_the_two_lines_and_their_padding_fit_the_fifty_six_pixel_cell() -> void:
	"""§2: "Combined 46px plus 8px padding fits 56", with "no extra interline gap"."""
	var cell: Vector2 = Vector2(109.3333, UiLayout.RESOURCE_CELL_HEIGHT)
	var caption: Rect2 = UiLayout.resource_caption_rect(cell)
	var value: Rect2 = UiLayout.resource_value_rect(cell)
	assert_almost_equal(caption.position.y, 4.0, "the caption line starts at the 4 px edge")
	assert_almost_equal(caption.size.y, 20.0, "the 14 px caption has a 20 px line box")
	assert_almost_equal(value.position.y, caption.position.y + caption.size.y,
		"the numeric line begins exactly where the caption ends, with no interline gap")
	assert_almost_equal(value.size.y, 26.0, "the 18 px number has a 26 px line box")
	assert_true(value.position.y + value.size.y <= cell.y - 4.0,
		"and both lines end inside the reserved 4 px bottom edge")


func test_the_caption_line_reserves_its_icon_its_gap_and_nothing_else() -> void:
	"""§2: "a 16px optical resource icon and 4px gap beside the caption in the first line"."""
	var cell: Vector2 = Vector2(109.3333, UiLayout.RESOURCE_CELL_HEIGHT)
	var icon: Rect2 = UiLayout.resource_icon_rect(cell)
	var caption: Rect2 = UiLayout.resource_caption_rect(cell)
	assert_almost_equal(icon.size.x, 16.0, "the icon is 16 px, not §2.2's 24")
	assert_almost_equal(icon.size.y, 16.0, "square")
	assert_almost_equal(icon.position.x, 4.0, "at the cell's own left edge reserve")
	assert_almost_equal(icon.position.y, 6.0, "centred in the 20 px caption line")
	assert_almost_equal(caption.position.x, icon.position.x + icon.size.x + 4.0,
		"and the caption begins one 4 px gap after it")
	assert_almost_equal(UiLayout.resource_caption_width(cell.x), 81.3333,
		"leaving the caption 81⅓ px to measure inside at STANDARD")


func test_the_resource_focus_ring_stays_inside_its_own_cell() -> void:
	"""§2: "a 2px ring inset 1px inside the cell, contained entirely in the reserved 4px padding".

	The two rows TOUCH at y64, so this is asserted against the real neighbour: the ring drawn on
	the top row must not intersect the bottom row's rectangle at all, which §2.2's outward
	offset-2 ring would.
	"""
	var first: Rect2 = _layout.counter_cell(UiLayout.PROFILE_STANDARD, 360.0, 0)
	var below: Rect2 = _layout.counter_cell(UiLayout.PROFILE_STANDARD, 360.0, 3)
	assert_almost_equal(first.position.y + first.size.y, below.position.y,
		"the two rows genuinely touch, which is why the ring is inset")
	var ring: Rect2 = UiLayout.resource_focus_rect(first.size)
	var drawn: Rect2 = Rect2(first.position + ring.position, ring.size)
	assert_false(drawn.intersects(below), "the ring never reaches the row below it")
	assert_true(ring.position.x >= UiLayout.RESOURCE_FOCUS_INSET,
		"it is inset by 1 px")
	assert_true(ring.position.x + UiLayout.RESOURCE_FOCUS_WIDTH
		<= UiLayout.RESOURCE_CELL_PADDING,
		"and its 2 px stroke ends inside the reserved 4 px padding")


func test_the_narrow_expand_button_moved_down_with_the_taller_rows() -> void:
	"""§2: "a 32x44 Expand button at (136,42)", centred against the two 56 px rows."""
	var expand: Rect2 = UiLayout.narrow_expand_rect()
	assert_almost_equal(expand.position.x, 136.0, "at x136")
	assert_almost_equal(expand.position.y, 42.0, "and y42, not §1.3's old y22")
	assert_almost_equal(expand.size.x, 32.0, "32 wide")
	assert_almost_equal(expand.size.y, 44.0, "and 44 high")
	assert_true(expand.position.x + expand.size.x + UiLayout.FRAME_PADDING
		<= float(UiLayout.RESOURCE_W[UiLayout.PROFILE_NARROW]),
		"and it still ends inside the 176 px narrow frame")


# --- UI-C3-R01 §3: reachable alert cards ------------------------------------------------------

func test_a_forty_four_pixel_card_cannot_hold_one_line_beside_its_own_icon() -> void:
	"""§3's reason for the 48: "max(text23,icon24)+24=48". 44 was two pixels short of legible.

	This is the arithmetic ALERT-R02 got wrong, restated as a check rather than as prose: one
	16 px notice line measures 23, the severity icon is 24, and the panel padding is 12 on each
	edge. Nothing below reads a measured font -- these are the specification's own figures.
	"""
	var content: float = maxf(23.0, UiLayout.ALERT_SEVERITY_ICON)
	assert_almost_equal(content + 2.0 * UiLayout.PANEL_PADDING, 48.0,
		"a full one-line card needs 48 px")
	assert_almost_equal(UiLayout.alert_card_min_height(UiLayout.PROFILE_STANDARD), 48.0,
		"which is what STANDARD grants it")
	assert_almost_equal(UiLayout.alert_card_min_height(UiLayout.PROFILE_WIDE), 48.0,
		"and WIDE")
	assert_true(UiLayout.ALERT_CARD_HEIGHT < 48.0,
		"§1.2's 44 px row is smaller than that, which is the defect §3 replaces")


func test_the_narrow_summary_keeps_its_forty_four_pixel_card_in_a_forty_eight_pixel_zone() -> void:
	"""§3: "NARROW retains outer 48/card 44 ... Its summary-only vertical padding is 8"."""
	assert_almost_equal(float(UiLayout.ALERT_H[UiLayout.PROFILE_NARROW]), 48.0,
		"the NARROW zone stays 48")
	assert_almost_equal(UiLayout.alert_card_min_height(UiLayout.PROFILE_NARROW), 44.0,
		"and its card stays 44")
	assert_almost_equal(UiLayout.alert_summary_padding_y(UiLayout.PROFILE_NARROW), 8.0,
		"with 8 px of vertical padding, not the generic 12")
	assert_almost_equal(maxf(UiLayout.ALERT_SEVERITY_ICON, 23.0)
		+ 2.0 * UiLayout.alert_summary_padding_y(UiLayout.PROFILE_NARROW), 40.0,
		"max(icon24,text23)+16 is 40, which fits the 44 px card")
	assert_almost_equal(UiLayout.alert_summary_padding_y(UiLayout.PROFILE_STANDARD), 12.0,
		"a full message elsewhere keeps the 12 px panel padding")


func test_both_standard_cards_are_reachable_rather_than_merely_placed() -> void:
	"""§3: "Two such full cards plus gap consume exactly 100" inside the 104 px zone."""
	var measured: PackedFloat32Array = PackedFloat32Array([48.0, 48.0])
	assert_true(_layout.alert_stack_into(UiLayout.PROFILE_STANDARD, 360.0, measured,
		measured.size(), _stack), "the stack computes")
	assert_equal(_stack.visible_count, 2, "both cards are placed")
	for index: int in 2:
		assert_almost_equal(_stack.rects[index].size.y, 48.0,
			"card %d is a full 48 px card" % index)
		assert_equal(_stack.summarised[index], 0, "card %d shows its whole message" % index)
	assert_almost_equal(_stack.rects[1].position.y + _stack.rects[1].size.y
		- _stack.rects[0].position.y, 100.0, "and the pair consumes exactly the 100 px interior")


# --- UI-C3-R01 §4: the reserved band and the ordinary workspace ---------------------------------

func test_the_management_band_is_152_at_every_supported_profile() -> void:
	"""§4: "management_top = max(128, bottom(resources), bottom(alerts), bottom(time)) + 8",
	"giving 152 at the supported profiles"."""
	for size: Array in SUPPORTED_SIZES:
		for scale: int in USER_SCALES:
			assert_true(_layout.compute_into(size[0], size[1], scale, false, _geometry),
				"%dx%d at %d percent computes" % [size[0], size[1], scale])
			assert_almost_equal(_geometry.management_top, 152.0,
				"%dx%d@%d reserves 152" % [size[0], size[1], scale])
			assert_true(_geometry.management_top >= _geometry.alerts.position.y
				+ _geometry.alerts.size.y, "%dx%d@%d: below the alert zone" % [size[0],
				size[1], scale])


func test_a_refused_geometry_leaves_no_management_band_behind() -> void:
	"""A refused computation must not leave a reserved band a caller could place against."""
	assert_false(_layout.compute_into(1024, 768, 100, false, _geometry), "below the floor refuses")
	assert_almost_equal(_geometry.management_top, UiLayout.MANAGEMENT_TOP_FLOOR,
		"and the band returns to its own floor rather than keeping the last one")


func test_the_ordinary_workspace_clears_the_alert_zone_and_the_resource_frame() -> void:
	"""§1: the defect the cycle-01 captures measured, asserted as geometry rather than pixels.

	§1.2's modal rectangle at the supported floor is `(160,16,960,688)`, which CONTAINS the alert
	zone `(460,16,360,104)` and two of the three resource columns. §4.2's ordinary workspace does
	not, and this asserts the difference both ways so a revert to `_geometry.modal` fails here.
	"""
	assert_true(_layout.compute_into(1280, 720, 100, false, _geometry), "the geometry computes")
	assert_true(_geometry.modal.intersects(_geometry.alerts),
		"the centred modal really does swallow the alert zone")
	var workspace: Rect2 = UiLayout.workspace_rect(_geometry, 560.0)
	assert_false(workspace.intersects(_geometry.alerts), "the ordinary workspace does not")
	assert_false(workspace.intersects(_geometry.resources), "nor the resource frame")
	assert_false(workspace.intersects(_geometry.time), "nor the time cluster")
	assert_false(workspace.intersects(_geometry.minimap), "nor the minimap")


func test_the_ordinary_workspace_takes_four_twos_own_dimensions() -> void:
	"""§4.2: "Width min(640,Lw−32) ... Bottom is command-strip top−8; top must be at least 128"."""
	assert_true(_layout.compute_into(1280, 720, 100, false, _geometry), "the geometry computes")
	var workspace: Rect2 = UiLayout.workspace_rect(_geometry, 560.0)
	assert_almost_equal(workspace.size.x, 640.0, "the frame is 640 wide, not 960")
	assert_almost_equal(workspace.position.y + workspace.size.y,
		_geometry.commands.position.y - 8.0, "its bottom is the command strip's top less 8")
	assert_true(workspace.position.y >= _geometry.management_top - 0.01,
		"and its top is at or below the reserved band")
	assert_almost_equal(workspace.position.x + workspace.size.x / 2.0,
		_geometry.commands.position.x + _geometry.commands.size.x / 2.0,
		"it is centred on the command strip")


func test_a_short_content_column_does_not_stretch_the_workspace_frame() -> void:
	"""§4.2: "Height is the lesser of content height,560 and that available height"."""
	assert_true(_layout.compute_into(1920, 1080, 100, false, _geometry), "the geometry computes")
	assert_almost_equal(UiLayout.workspace_rect(_geometry, 300.0).size.y, 300.0,
		"a 300 px column gets a 300 px frame")
	assert_almost_equal(UiLayout.workspace_rect(_geometry, 900.0).size.y, 560.0,
		"and a 900 px column is capped at 560, not at the available height")


func test_the_open_detail_column_pushes_the_workspace_off_it() -> void:
	"""§4.2: "clamped within safe viewport and avoiding the detail column when open"."""
	assert_true(_layout.compute_into(1920, 1080, 100, true, _geometry), "detail open computes")
	var workspace: Rect2 = UiLayout.workspace_rect(_geometry, 560.0)
	assert_false(workspace.intersects(_geometry.detail),
		"the frame never overlaps the open detail column")
	assert_true(workspace.position.x >= UiLayout.SAFE_INSET,
		"and it is still inside the 16 px safe inset")


func test_the_minimum_logical_viewport_uses_the_compact_management_variant() -> void:
	"""§4's own worked answer: "At 1280x720/150% (logical 853⅓x480), body is (106⅔,152,640,312)".

	Every figure here is quoted, not derived: the ruling states the whole rectangle, and it
	states why it is not the 560 px dialog -- "This is intentional reflow, not a clipped 560px
	dialog", with "188px of scrollable body between header and footer".
	"""
	assert_true(_layout.compute_into(1280, 720, 150, false, _geometry), "the geometry computes")
	assert_equal(_geometry.profile, UiLayout.PROFILE_NARROW, "1280 at 150% is NARROW")
	assert_true(absf(_geometry.logical_height - 480.0) < SPAN_EPSILON, "Lh is 480")
	assert_true(UiLayout.workspace_is_compact(_geometry),
		"under 248 px remain, so the compact variant owns the placement")
	var body: Rect2 = UiLayout.workspace_rect(_geometry, 560.0)
	assert_almost_equal(body.position.x, 106.6667, "x is 106⅔")
	assert_almost_equal(body.position.y, 152.0, "y is the reserved band at 152")
	assert_almost_equal(body.size.x, 640.0, "640 wide")
	assert_almost_equal(body.size.y, 312.0, "and 312 high, not 560")
	assert_almost_equal(body.size.y - 64.0 - 60.0, 188.0,
		"leaving 188 px of scrollable body between the fixed header and footer")


func test_the_compact_variant_still_starts_below_the_reserved_band() -> void:
	"""§4: "no opaque management content covers it". The band is reserved at every viewport."""
	for size: Array in SUPPORTED_SIZES:
		for scale: int in USER_SCALES:
			assert_true(_layout.compute_into(size[0], size[1], scale, false, _geometry),
				"%dx%d at %d percent computes" % [size[0], size[1], scale])
			var body: Rect2 = UiLayout.workspace_rect(_geometry, 560.0)
			assert_true(body.position.y >= _geometry.management_top - 0.01,
				"%dx%d@%d starts at or below the band" % [size[0], size[1], scale])
			assert_true(body.position.y + body.size.y
				<= _geometry.logical_height - UiLayout.SAFE_INSET + 0.01,
				"%dx%d@%d ends inside the safe viewport" % [size[0], size[1], scale])
			assert_true(body.size.x <= UiLayout.WORKSPACE_MAX_WIDTH + 0.01,
				"%dx%d@%d is never wider than 640" % [size[0], size[1], scale])
