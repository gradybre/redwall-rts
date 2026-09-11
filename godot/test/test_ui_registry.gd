extends "res://test/framework/test_case.gd"
## Coverage for the §4 element registry: it must BE the specification, not resemble it.
##
## A transcription suite is worth nothing if it reads its expectations back out of the file it
## is checking. Every figure asserted below is quoted here independently from
## `docs/ui_ux_controls.md` §4, so a row typed wrongly into `ui_registry.gd` fails here rather
## than agreeing with itself. The spot-checked rows are chosen to span all three subsections and
## every size kind.

const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

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
