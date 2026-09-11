extends "res://test/framework/test_case.gd"
## Coverage for the §4 element registry: it must BE the specification, not resemble it.
##
## A transcription suite is worth nothing if it reads its expectations back out of the file it
## is checking. Every figure asserted below is quoted here independently from
## `docs/ui_ux_controls.md` §4, so a row typed wrongly into `ui_registry.gd` fails here rather
## than agreeing with itself. The spot-checked rows are chosen to span all three subsections and
## every size kind.

const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## §4's element count and id range, stated independently.
const EXPECTED_ELEMENT_COUNT: int = 103
const FIRST_ID: int = 1
const LAST_ID: int = 103

## Rows quoted from §4: id, name fragment, zone, profile, gate, min w/h, max w/h.
const QUOTED_ROWS: Array = [
	[1, "Resource cluster", UiRegistry.ZONE_TOP_LEFT, UiRegistry.PROFILE_PANEL,
		UiRegistry.GATE_ALWAYS, 176, 88, 480, 88],
	[2, "Food counter", UiRegistry.ZONE_TOP_LEFT, UiRegistry.PROFILE_READOUT,
		UiRegistry.GATE_ALWAYS, 104, 36, 144, 40],
	[14, "Pause button", UiRegistry.ZONE_TOP_RIGHT, UiRegistry.PROFILE_TOGGLE,
		UiRegistry.GATE_ALWAYS, 44, 36, 56, 44],
	[20, "Minimap frame", UiRegistry.ZONE_BOTTOM_LEFT, UiRegistry.PROFILE_PANEL,
		UiRegistry.GATE_ALWAYS, 160, 192, 256, 288],
	[26, "Command strip", UiRegistry.ZONE_BOTTOM_CENTER, UiRegistry.PROFILE_PANEL,
		UiRegistry.GATE_ALWAYS, 240, 136, 640, 136],
	[36, "Context detail", UiRegistry.ZONE_BOTTOM_RIGHT, UiRegistry.PROFILE_PANEL,
		UiRegistry.GATE_SELECTED, 320, 240, 384, 936],
	[51, "Workspace frame", UiRegistry.ZONE_CENTER, UiRegistry.PROFILE_MODAL,
		UiRegistry.GATE_WORKSPACE, 480, 320, 960, 720],
	[66, "Confirm", UiRegistry.ZONE_OWNER, UiRegistry.PROFILE_BUTTON,
		UiRegistry.GATE_MODAL, 120, 44, 240, 48],
	[86, "Pause label", UiRegistry.ZONE_TOP_CENTER, UiRegistry.PROFILE_READOUT,
		UiRegistry.GATE_CONDITION, 96, 32, 240, 40],
	[94, "Scroll bar", UiRegistry.ZONE_OWNER, UiRegistry.PROFILE_FIELD,
		UiRegistry.GATE_CONDITION, 16, 48, 24, 600],
	[102, "History trigger", UiRegistry.ZONE_TOP_CENTER, UiRegistry.PROFILE_BUTTON,
		UiRegistry.GATE_ALWAYS, 32, 32, 32, 32],
	[103, "New settlement", UiRegistry.ZONE_TOP_RIGHT, UiRegistry.PROFILE_MODAL,
		UiRegistry.GATE_MODAL, 480, 320, 960, 720],
]

## §4's four rows whose size is a runtime shape rather than a pixel range.
const RUNTIME_SIZED_IDS: Array[int] = [23, 25, 54, 74]

var _registry: UiRegistry = null
var _size: UiRegistry.Size = null


func before_each() -> void:
	"""Build the registry and one reusable size record."""
	_registry = UiRegistry.new()
	_size = UiRegistry.Size.new()


func after_each() -> void:
	"""Drop both so nothing crosses a test boundary."""
	_registry = null
	_size = null


# --- the catalog is complete and contiguous ---------------------------------------------------

func test_the_registry_holds_every_one_of_section_fours_103_elements() -> void:
	"""§4 defines UI-SET-001 through UI-SET-103 with no gaps."""
	assert_equal(UiRegistry.ELEMENT_COUNT, EXPECTED_ELEMENT_COUNT, "§4 defines 103 elements")
	assert_equal(UiRegistry.FIRST_ID, FIRST_ID, "the first id is 1")
	assert_equal(UiRegistry.LAST_ID, LAST_ID, "the last id is 103")
	for id: int in range(FIRST_ID, LAST_ID + 1):
		assert_true(UiRegistry.is_element(id), "UI-SET-%03d is defined" % id)


func test_ids_outside_the_range_are_refused_rather_than_wrapped() -> void:
	"""There is no element 0 and no element 104; both refuse with a named code."""
	assert_false(UiRegistry.is_element(0), "there is no element 0")
	assert_false(UiRegistry.is_element(LAST_ID + 1), "there is no element 104")
	assert_false(_registry.size_into(0, _size), "element 0 refuses")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_UNKNOWN_ID, "with UNKNOWN_ID")
	assert_false(_registry.zone_of(LAST_ID + 1).ok, "element 104 refuses a zone read")


func test_every_element_has_a_unique_non_empty_name() -> void:
	"""§4 requires "a unique `UI-SET-nnn` definition"; two rows may not share a name."""
	var seen: Dictionary = {}
	for id: int in range(FIRST_ID, LAST_ID + 1):
		var element_name: StringName = _registry.name_of(id)
		assert_false(String(element_name).is_empty(), "UI-SET-%03d is named" % id)
		assert_false(seen.has(element_name), "'%s' is used once" % element_name)
		seen[element_name] = id
	assert_equal(seen.size(), EXPECTED_ELEMENT_COUNT, "103 distinct names")


func test_element_keys_are_the_specifications_own_zero_padded_ids() -> void:
	"""The runtime id §4 names instances by is `UI-SET-nnn`, zero padded to three digits."""
	assert_equal(_registry.element_key(1), &"UI-SET-001", "the first key is padded")
	assert_equal(_registry.element_key(28), &"UI-SET-028", "a two-digit id is padded")
	assert_equal(_registry.element_key(103), &"UI-SET-103", "the last key is not padded further")


# --- the transcribed rows ----------------------------------------------------------------------

func test_quoted_rows_match_the_specification_exactly() -> void:
	"""Twelve §4 rows, quoted in this file, must match the registry field for field."""
	for row: Array in QUOTED_ROWS:
		var id: int = row[0]
		assert_equal(String(_registry.name_of(id)), String(row[1]),
			"UI-SET-%03d is named as §4 names it" % id)
		assert_equal(_registry.zone_of(id).value, row[2], "UI-SET-%03d sits in its §1.1 zone" % id)
		assert_equal(_registry.profile_of(id).value, row[3],
			"UI-SET-%03d selects its §2.2 profile" % id)
		assert_equal(_registry.gate_of(id).value, row[4], "UI-SET-%03d carries its gate" % id)
		_assert_quoted_size(id, row)


func _assert_quoted_size(id: int, row: Array) -> void:
	"""Compare one quoted row's four size figures against the registry."""
	assert_true(_registry.size_into(id, _size), "UI-SET-%03d has a fixed size" % id)
	assert_equal(_size.min_width, row[5], "UI-SET-%03d minimum width" % id)
	assert_equal(_size.min_height, row[6], "UI-SET-%03d minimum height" % id)
	assert_equal(_size.max_width, row[7], "UI-SET-%03d maximum width" % id)
	assert_equal(_size.max_height, row[8], "UI-SET-%03d maximum height" % id)


func test_every_zone_profile_and_gate_value_is_a_defined_one() -> void:
	"""No element may claim an undefined zone, profile or gate."""
	for id: int in range(FIRST_ID, LAST_ID + 1):
		var zone: int = _registry.zone_of(id).value
		var profile: int = _registry.profile_of(id).value
		var gate: int = _registry.gate_of(id).value
		assert_true(zone >= 0 and zone < UiRegistry.ZONE_COUNT, "UI-SET-%03d zone" % id)
		assert_true(profile >= 0 and profile < UiRegistry.PROFILE_COUNT, "UI-SET-%03d profile" % id)
		assert_true(gate >= 0 and gate < UiRegistry.GATE_COUNT, "UI-SET-%03d gate" % id)


func test_every_fixed_size_has_a_maximum_no_smaller_than_its_minimum() -> void:
	"""§4's column is "minimum->maximum"; a row with the two exchanged would be unbuildable."""
	for id: int in range(FIRST_ID, LAST_ID + 1):
		if RUNTIME_SIZED_IDS.has(id):
			continue
		assert_true(_registry.size_into(id, _size), "UI-SET-%03d has a fixed size" % id)
		assert_true(_size.max_width >= _size.min_width, "UI-SET-%03d width range" % id)
		assert_true(_size.max_height >= _size.min_height, "UI-SET-%03d height range" % id)


# --- the four rows with no fixed rectangle ------------------------------------------------------

func test_runtime_sized_rows_refuse_a_rectangle_instead_of_inventing_one() -> void:
	"""UI-SET-023, 025, 054 and 074 are sized at runtime; asking for pixels must refuse."""
	for id: int in RUNTIME_SIZED_IDS:
		assert_false(_registry.size_into(id, _size),
			"UI-SET-%03d has no fixed rectangle to report" % id)
		assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_SIZE_NOT_FIXED,
			"UI-SET-%03d refuses with SIZE_NOT_FIXED" % id)
		assert_equal(_size.min_width, 0, "and leaves no invented width behind")


func test_each_runtime_sized_row_states_which_runtime_shape_it_is() -> void:
	"""The four are not interchangeable: a viewport, a drag, a footprint and an owner rect."""
	assert_equal(_registry.size_kind_of(23).value, UiRegistry.SIZE_VIEWPORT,
		"UI-SET-023 is the full remaining viewport")
	assert_equal(_registry.size_kind_of(25).value, UiRegistry.SIZE_DRAG_RECT,
		"UI-SET-025 is a pointer drag rectangle")
	assert_equal(_registry.size_kind_of(54).value, UiRegistry.SIZE_FOOTPRINT,
		"UI-SET-054 is a building footprint projection")
	assert_equal(_registry.size_kind_of(74).value, UiRegistry.SIZE_OWNER_RELATIVE,
		"UI-SET-074 is its owner's rectangle plus 4 px")


# --- §2.2's hit target rule ---------------------------------------------------------------------

func test_every_interactive_row_meets_the_32_pixel_minimum_hitbox() -> void:
	"""§2.2: "Interactive minimum hitbox 32x32", with the scrollbar as the only exception."""
	for id: int in range(FIRST_ID, LAST_ID + 1):
		if not _registry.is_interactive(id) or id == UiRegistry.SCROLLBAR_ID:
			continue
		assert_true(_registry.size_into(id, _size), "UI-SET-%03d has a size" % id)
		assert_true(_size.min_width >= UiRegistry.MINIMUM_HITBOX,
			"UI-SET-%03d is at least 32 wide" % id)
		assert_true(_size.min_height >= UiRegistry.MINIMUM_HITBOX,
			"UI-SET-%03d is at least 32 high" % id)


func test_the_scrollbar_is_the_only_element_below_the_minimum_width() -> void:
	"""§2.2 names exactly one exception, and it is 16 px with keyboard alternatives."""
	assert_true(_registry.size_into(UiRegistry.SCROLLBAR_ID, _size), "UI-SET-094 has a size")
	assert_equal(_size.min_width, 16, "the scrollbar is 16 logical pixels wide")
	assert_true(_size.min_width < UiRegistry.MINIMUM_HITBOX, "which is below the 32 px minimum")
	var below: int = 0
	for id: int in range(FIRST_ID, LAST_ID + 1):
		if not _registry.is_interactive(id):
			continue
		if _registry.size_into(id, _size) and _size.min_width < UiRegistry.MINIMUM_HITBOX:
			below += 1
	assert_equal(below, 1, "exactly one interactive element is narrower than 32 px")


func test_interactivity_follows_the_profile_rather_than_the_element_name() -> void:
	"""BUTTON, TOGGLE, ROW and FIELD rows are reachable; PANEL and READOUT rows are containers."""
	assert_true(_registry.is_interactive(14), "the pause TOGGLE is interactive")
	assert_true(_registry.is_interactive(28), "the zone BUTTON is interactive")
	assert_true(_registry.is_interactive(69), "the resident ROW is interactive")
	assert_true(_registry.is_interactive(75), "the search FIELD is interactive")
	assert_false(_registry.is_interactive(1), "the resource cluster PANEL is not itself a control")
	assert_false(_registry.is_interactive(24), "the selection ring OVERLAY is not a control")


# --- §4's activation column: what a row opens ------------------------------------------------------
#
# UXV-004 and UXV-005. §4.1 gives UI-SET-031 "ALWAYS; opens roster rows 069" and §4.3 gives
# UI-SET-087 "F6/accessible mode". Those are two different controls opening two different things,
# and the rows are quoted here independently of `ui_registry.gd` so a swapped table disagrees
# with this file rather than with itself.

## Opener, opened element, surface -- transcribed from §4 by hand for this suite.
const QUOTED_OPENINGS: Array = [
	[31, 69, UiRegistry.SURFACE_WORKSPACE],   # "ALWAYS; opens roster rows 069"
	[27, 52, UiRegistry.SURFACE_WORKSPACE],   # "ALWAYS; opens 052"
	[29, 70, UiRegistry.SURFACE_WORKSPACE],   # "ALWAYS; opens 070"
	[30, 60, UiRegistry.SURFACE_WORKSPACE],   # "ALWAYS; opens 060"
	[19, 78, UiRegistry.SURFACE_MODAL],       # "ALWAYS; opens 078 menu variant; adds MENU"
	[98, 82, UiRegistry.SURFACE_MODAL],       # "resident pin opens 082"
	[28, 59, UiRegistry.SURFACE_WORLD_TOOL],  # "ALWAYS; opens 059"
	[22, 96, UiRegistry.SURFACE_QUICK_MENU],  # "ALWAYS; opens layers in 096"
	[8, 9, UiRegistry.SURFACE_EXPANSION],     # "ALWAYS; toggle 009"
	[102, 12, UiRegistry.SURFACE_EXPANSION],  # "ALWAYS, even when no alerts; activates 012"
]


func test_the_residents_command_opens_the_roster_and_not_the_world_access_list() -> void:
	"""§4.1: UI-SET-031 is "ALWAYS; opens roster rows 069". 087 is a different control."""
	assert_equal(_registry.opens_element(31).value, 69,
		"the Residents command opens the resident roster")
	assert_true(_registry.opens_element(31).value != 87,
		"and never the world access list")
	assert_equal(_registry.opens_surface(31).value, UiRegistry.SURFACE_WORKSPACE,
		"the roster is a workspace, per UI-SET-069's WORKSPACE gate")


func test_no_element_opens_the_world_access_list_because_f6_does() -> void:
	"""§4.3 gates UI-SET-087 on "F6/accessible mode" -- a key, not a command button."""
	for opener: int in range(FIRST_ID, LAST_ID + 1):
		var opened: IntMath.IntResult = _registry.opens_element(opener)
		if not opened.ok:
			continue
		assert_true(opened.value != UiRegistry.ACCESS_MODE_ID,
			"UI-SET-%03d must not open the world access list" % opener)
	assert_false(_registry.opens_element(87).ok, "and 087 itself opens nothing further")


func test_every_quoted_opening_matches_the_specification() -> void:
	"""Each §4 activation phrase names the element it opens and the surface class it is."""
	for row: Array in QUOTED_OPENINGS:
		assert_equal(_registry.opens_element(row[0]).value, row[1],
			"UI-SET-%03d opens UI-SET-%03d" % [row[0], row[1]])
		assert_equal(_registry.opens_surface(row[0]).value, row[2],
			"UI-SET-%03d opens a %s" % [row[0], UiRegistry.SURFACE_KEYS[row[2]]])


func test_a_row_that_opens_nothing_refuses_rather_than_answering_zero() -> void:
	"""§4 has no element zero, so "opens nothing" cannot be reported as "opens element 0"."""
	assert_false(_registry.opens_element(2).ok, "a counter opens no numbered element")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_OPENS_NOTHING, "with OPENS_NOTHING")
	assert_false(_registry.opens_surface(104).ok, "and an id past the end is unknown")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_UNKNOWN_ID, "with UNKNOWN_ID")


# --- UXV-005: the two explicit UI-SET-051 variants -------------------------------------------------

func test_the_centre_frame_has_exactly_the_two_variants_section_four_names() -> void:
	"""§4.2 gates UI-SET-051 "WORKSPACE or MODAL"; a caller must name which one it wants."""
	assert_equal(_registry.frame_variant_for(31).value, UiRegistry.FRAME_VARIANT_WORKSPACE,
		"the Residents command asks for the workspace variant")
	assert_equal(_registry.frame_variant_for(19).value, UiRegistry.FRAME_VARIANT_MODAL,
		"the menu button asks for the modal variant")
	assert_true(_registry.opens_centre_frame(27), "the build command opens the centre frame")


func test_a_tool_or_expansion_opener_is_refused_a_centre_frame() -> void:
	"""A zone brush is a bottom-centre tool strip; giving it a centre frame invents a surface."""
	assert_false(_registry.frame_variant_for(28).ok, "the zone command opens no centre frame")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_NO_CENTRE_FRAME, "with NO_CENTRE_FRAME")
	assert_false(_registry.opens_centre_frame(8), "nor does the resource expander")
	assert_false(_registry.opens_centre_frame(22), "nor the minimap layer button")


func test_no_selection_gated_row_opens_a_centre_workspace() -> void:
	"""Ordinary selection may open a MODAL -- UI-SET-082 is one -- but never a workspace."""
	var selection_openers: int = 0
	for opener: int in range(FIRST_ID, LAST_ID + 1):
		if _registry.gate_of(opener).value != UiRegistry.GATE_SELECTED:
			continue
		var surface: IntMath.IntResult = _registry.opens_surface(opener)
		if not surface.ok:
			continue
		selection_openers += 1
		assert_true(surface.value != UiRegistry.SURFACE_WORKSPACE,
			"UI-SET-%03d is SELECTED and must not open a centre workspace" % opener)
	assert_true(selection_openers > 0, "at least one SELECTED row does open something")
	assert_equal(_registry.frame_variant_for(98).value, UiRegistry.FRAME_VARIANT_MODAL,
		"the resident pin opens UI-SET-082, which §4.3 gives the MODAL profile")


# --- UXV-032: long content wraps or scrolls, and never shrinks --------------------------------------

func test_the_overflow_policies_are_only_grow_and_scroll() -> void:
	"""§1.3 rules out the alternatives by name, so no third policy value exists to select."""
	assert_equal(UiRegistry.OVERFLOW_COUNT, 2, "there are two policies and no truncating third")
	for id: int in range(FIRST_ID, LAST_ID + 1):
		var policy: IntMath.IntResult = _registry.overflow_policy_of(id)
		assert_true(policy.ok and policy.value >= 0 and policy.value < UiRegistry.OVERFLOW_COUNT,
			"UI-SET-%03d states a legal overflow policy" % id)


func test_panels_and_modals_scroll_while_rows_and_readouts_grow() -> void:
	"""§1.3: "Large text: Scroll panels vertically"; "Long labels: ... expand row height"."""
	assert_equal(_registry.overflow_policy_of(51).value, UiRegistry.OVERFLOW_SCROLL,
		"the workspace/modal frame scrolls")
	assert_equal(_registry.overflow_policy_of(9).value, UiRegistry.OVERFLOW_SCROLL,
		"the resource ledger panel scrolls")
	assert_equal(_registry.overflow_policy_of(69).value, UiRegistry.OVERFLOW_GROW,
		"a resident row grows instead")
	assert_equal(_registry.overflow_policy_of(2).value, UiRegistry.OVERFLOW_GROW,
		"and so does a readout counter")


## §2.1: "Body 16/400/TEXT, line height 1.35" -- 16 x 1.35 rounded up, stated independently.
const BODY_LINE_HEIGHT: int = 22


func test_a_thirty_two_character_name_grows_its_row_without_reaching_the_maximum() -> void:
	"""§4.3 caps a resident name at 32 characters, and UI-SET-037 is the title that prints it.

	§1.3: "Long labels: Wrap to 2 lines within fixed-height cells only if font>=16; otherwise
	expand row height; never truncate". So the second line must make the row taller and must
	still fit inside §4's own maximum, which is what "without clipping" means here.
	"""
	var one_line: int = _registry.grown_height_of(37, 1, BODY_LINE_HEIGHT).value
	var two_lines: int = _registry.grown_height_of(37, 2, BODY_LINE_HEIGHT).value
	assert_true(two_lines > one_line, "wrapping a 32-character name makes the title taller")
	_size.reset()
	assert_true(_registry.size_into(37, _size), "the detail title has a fixed range")
	assert_true(two_lines < _size.max_height,
		"and the grown title is inside §4's own maximum, so nothing is clipped")
	assert_true(one_line >= _size.min_height, "a single line never shrinks below the minimum")
	assert_true(BODY_LINE_HEIGHT >= UiRegistry.WRAP_MINIMUM_FONT_PX,
		"§1.3 only allows the wrap at all because the body font is at least 16")


func test_growing_refuses_a_font_below_the_fourteen_pixel_floor() -> void:
	"""§2.1: "Minimum rendered font size 14 logical pixels"; §1.3 has no shrink fallback."""
	assert_false(_registry.grown_height_of(69, 2, UiRegistry.MINIMUM_FONT_PX - 1).ok,
		"a 13 px line height is refused rather than used to make the text fit")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_NEGATIVE_TEXT, "with NEGATIVE_TEXT")
	assert_true(_registry.grown_height_of(69, 2, UiRegistry.MINIMUM_FONT_PX).ok,
		"the floor itself is accepted")
	assert_false(_registry.grown_height_of(69, 0, 22).ok, "and zero lines is not a measurement")


func test_a_scrolling_container_refuses_to_grow_a_row() -> void:
	"""A panel scrolls its body; growing it instead would push its footer off the bottom."""
	assert_false(_registry.grown_height_of(51, 8, 22).ok, "the modal frame does not grow")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_DOES_NOT_GROW, "with DOES_NOT_GROW")


func test_a_modal_body_leaves_the_sixty_pixel_confirmation_footer_uncovered() -> void:
	"""§2.2: "Modal body height scrolls independently of its 60 px confirmation footer"."""
	_size.reset()
	assert_true(_registry.size_into(103, _size), "UI-SET-103 has a fixed range")
	var body: int = _registry.body_height_of(103).value
	assert_equal(body, _size.max_height - UiRegistry.CONFIRMATION_FOOTER_PX,
		"the scrolling body stops 60 px above the bottom")
	assert_true(body + UiRegistry.CONFIRMATION_FOOTER_PX <= _size.max_height,
		"so the Confirm and Cancel row is never covered by content")
	assert_false(_registry.body_height_of(69).ok, "a resident row has no confirmation footer")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_NOT_A_MODAL, "with NOT_A_MODAL")


# --- UXV-032: a long refusal and larger text scroll, and never shrink or clip -----------------------

## §2.1's body line height at the three §1.2 user scales: 16 x 1.35 at 100%, 125% and 150%.
const LINE_HEIGHT_AT_SCALE: Array[int] = [22, 27, 33]
## A refusal long enough to overflow UI-SET-085's own maximum at body size.
const LONG_REFUSAL_LINES: int = 30


func test_a_long_refusal_scrolls_its_panel_rather_than_being_clipped() -> void:
	"""§1.3: "Localization overflow: Content grows/scrolls; no auto shorten ... critical condition"."""
	_size.reset()
	assert_true(_registry.size_into(85, _size), "the error panel has a fixed range")
	var tall: int = LONG_REFUSAL_LINES * LINE_HEIGHT_AT_SCALE[0]
	assert_true(tall > _size.max_height, "a 30-line refusal is taller than UI-SET-085's maximum")
	assert_true(_registry.overflow_needs_scroll(85, LONG_REFUSAL_LINES, LINE_HEIGHT_AT_SCALE[0]),
		"so the panel scrolls")
	assert_false(_registry.overflow_needs_scroll(85, 4, LINE_HEIGHT_AT_SCALE[0]),
		"a short refusal needs no scroll at all")


func test_larger_text_scrolls_instead_of_shrinking_the_font() -> void:
	"""§1.3: "Large text: Scroll panels vertically ...; no reduced font size fallback"."""
	for index: int in LINE_HEIGHT_AT_SCALE.size():
		var line_height: int = LINE_HEIGHT_AT_SCALE[index]
		assert_true(line_height >= UiRegistry.MINIMUM_FONT_PX,
			"scale %d keeps the 14 px floor" % index)
		assert_true(_registry.grown_height_of(37, 2, line_height).ok,
			"a two-line title is measurable at scale %d" % index)
	assert_false(_registry.overflow_needs_scroll(37, 2, LINE_HEIGHT_AT_SCALE[0]),
		"at 100% the wrapped 32-character name fits UI-SET-037")
	assert_true(_registry.overflow_needs_scroll(37, 2, LINE_HEIGHT_AT_SCALE[2]),
		"at 150% it no longer fits, so the owner scrolls rather than reducing the font")


func test_the_grown_height_never_falls_below_the_row_minimum_at_any_scale() -> void:
	"""Clamping downwards would be a shrink by another name."""
	for id: int in [2, 37, 69, 85]:
		_size.reset()
		assert_true(_registry.size_into(id, _size), "UI-SET-%03d has a fixed range" % id)
		for line_height: int in LINE_HEIGHT_AT_SCALE:
			var grown: int = _registry.grown_height_of(id, 1, line_height).value
			assert_true(grown >= _size.min_height,
				"UI-SET-%03d stays at or above its minimum at %d px" % [id, line_height])


func test_scroll_is_refused_for_a_measurement_the_specification_forbids() -> void:
	"""A sub-14 px line height is not a smaller answer; it is not an answer."""
	assert_false(_registry.overflow_needs_scroll(85, 4, UiRegistry.MINIMUM_FONT_PX - 1),
		"a 13 px line is refused")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_NEGATIVE_TEXT, "with NEGATIVE_TEXT")
	assert_false(_registry.overflow_needs_scroll(23, 4, LINE_HEIGHT_AT_SCALE[0]),
		"and a row §4 sizes at runtime has no maximum to overflow")
	assert_equal(_registry.last_refusal(), UiRegistry.REFUSE_SIZE_NOT_FIXED, "with SIZE_NOT_FIXED")
