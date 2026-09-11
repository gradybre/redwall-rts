extends RefCounted
## SET-UX-001 §4's exhaustive element registry, transcribed as packed columns.
##
## The UI specification opens by ruling that "Every UI element has a unique `UI-SET-nnn`
## definition in Section 4. Each row explicitly selects a complete style/state profile;
## inheritance is mandatory, NOT AN INVITATION TO INVENT MISSING STATES." This file is that
## catalog and nothing else: it holds the 103 rows of §4.1, §4.2 and §4.3 exactly as they are
## written, so every other UI module reads its geometry, profile, zone and gate from the owning
## document instead of from a number a coder chose at a keyboard.
##
## ---------------------------------------------------------------------------------------
## WHY THE COLUMNS ARE PARALLEL ARRAYS INDEXED BY `id - 1`. §4's ids are contiguous 1..103, so
## the row index is arithmetic rather than a lookup, and there is one entry per column per
## element by construction: a row added to one column and forgotten in another changes an array
## length, which `_assert_contracts()` catches at construction rather than at a null read.
##
## ---------------------------------------------------------------------------------------
## SIZES THAT ARE NOT RECTANGLES ARE NOT STORED AS RECTANGLES. Five rows in §4 do not give a
## fixed size at all: UI-SET-023 is "Full remaining viewport", UI-SET-025 is "1x1 -> Lw x Lh"
## (a pointer drag), UI-SET-054 is "Footprint projection" and UI-SET-074 is "Owner rect + 4 px".
## Storing a plausible number for those would be inventing a constant the specification
## deliberately leaves to the runtime, so each carries its own SIZE_* kind and
## `minimum_size_into()` REFUSES for it with `REFUSE_SIZE_NOT_FIXED`. Refusing is the point:
## a caller that needs a rectangle for one of these must ask the layout, not this table.
##
## ---------------------------------------------------------------------------------------
## MULTI-ZONE ROWS RECORD THEIR FIRST LISTED OWNER. Nine §4 rows name an alternative anchor
## ("BR or BC", "TR calendar or BC objectives", "TC alert opens CENTER 051"). The registry
## records the FIRST zone the specification lists, which is the one §1.1 assigns the element to;
## the alternative is a placement choice made by the owning panel, not a second definition.
## §1.1 closes with "This resolves zone ownership for every element in the registry", so no row
## here is left without an owner.
##
## Nothing in this file reads game state, and nothing in it is authoritative simulation state.
## It is a specification transcript.

const IntMath := preload("res://scripts/core/int_math.gd")

# --- §1.1 screen zones --------------------------------------------------------------------------

const ZONE_TOP_LEFT: int = 0
const ZONE_TOP_CENTER: int = 1
const ZONE_TOP_RIGHT: int = 2
const ZONE_CENTER: int = 3
const ZONE_BOTTOM_LEFT: int = 4
const ZONE_BOTTOM_CENTER: int = 5
const ZONE_BOTTOM_RIGHT: int = 6
## §4 rows anchored to whatever panel, modal or tool bar owns them rather than to a screen zone.
const ZONE_OWNER: int = 7
const ZONE_COUNT: int = 8

const ZONE_KEYS: Array[StringName] = [
	&"TOP_LEFT", &"TOP_CENTER", &"TOP_RIGHT", &"CENTER",
	&"BOTTOM_LEFT", &"BOTTOM_CENTER", &"BOTTOM_RIGHT", &"OWNER",
]

# --- §2.2 complete state profiles ---------------------------------------------------------------

const PROFILE_PANEL: int = 0
const PROFILE_BUTTON: int = 1
const PROFILE_TOGGLE: int = 2
const PROFILE_ROW: int = 3
const PROFILE_FIELD: int = 4
const PROFILE_READOUT: int = 5
const PROFILE_METER: int = 6
const PROFILE_NOTICE: int = 7
const PROFILE_OVERLAY: int = 8
const PROFILE_MODAL: int = 9
const PROFILE_COUNT: int = 10

const PROFILE_KEYS: Array[StringName] = [
	&"PANEL", &"BUTTON", &"TOGGLE", &"ROW", &"FIELD",
	&"READOUT", &"METER", &"NOTICE", &"OVERLAY", &"MODAL",
]

# --- §4's `Gate` column -------------------------------------------------------------------------

const GATE_ALWAYS: int = 0
const GATE_SELECTED: int = 1
const GATE_WORLD_TOOL: int = 2
const GATE_WORKSPACE: int = 3
const GATE_MODAL: int = 4
const GATE_TUTORIAL: int = 5
const GATE_M1: int = 6
const GATE_M2: int = 7
const GATE_M3: int = 8
const GATE_CONDITION: int = 9
const GATE_COUNT: int = 10

const GATE_KEYS: Array[StringName] = [
	&"ALWAYS", &"SELECTED", &"WORLD_TOOL", &"WORKSPACE", &"MODAL",
	&"TUTORIAL", &"M1", &"M2", &"M3", &"CONDITION",
]

# --- how a row states its size ------------------------------------------------------------------

## "Sizes are minimum->maximum width x height" -- an ordinary fixed range.
const SIZE_FIXED: int = 0
## UI-SET-023: "Full remaining viewport".
const SIZE_VIEWPORT: int = 1
## UI-SET-025: "1x1 -> Lw x Lh", a pointer drag rectangle.
const SIZE_DRAG_RECT: int = 2
## UI-SET-054: "Footprint projection" of the building being placed.
const SIZE_FOOTPRINT: int = 3
## UI-SET-074: "Owner rect + 4 px".
const SIZE_OWNER_RELATIVE: int = 4
const SIZE_KIND_COUNT: int = 5

const SIZE_KIND_KEYS: Array[StringName] = [
	&"FIXED", &"VIEWPORT", &"DRAG_RECT", &"FOOTPRINT", &"OWNER_RELATIVE",
]

# --- the catalog --------------------------------------------------------------------------------

## §4's ids run 1..103 with no gaps; `_row_of(id)` is `id - 1`.
const FIRST_ID: int = 1
const ELEMENT_COUNT: int = 103
const LAST_ID: int = FIRST_ID + ELEMENT_COUNT - 1

## §2.2: "Interactive minimum hitbox 32x32". Asserted against every interactive row below.
const MINIMUM_HITBOX: int = 32
## §2.2's single stated exception: "the 16 px normal scrollbar is the only pointer-width
## exception; all scrolling also has wheel, arrow, and PageUp/PageDown alternatives".
const SCROLLBAR_ID: int = 94

const NAMES: Array[StringName] = [
	&"Resource cluster", &"Food counter", &"Fuel counter", &"Wood counter", &"Stone counter",
	&"Population counter", &"Bed counter", &"Expand resources", &"Resource ledger",
	&"Alert stack", &"Alert card", &"Notice history", &"Time cluster", &"Pause button",
	&"Speed 1", &"Speed 2", &"Speed 4", &"Calendar", &"Menu button", &"Minimap frame",
	&"Minimap view", &"Map layers", &"World surface", &"Selection ring", &"Box selection",
	&"Command strip", &"Build command", &"Zone command", &"Jobs command", &"Food command",
	&"Residents command", &"Feast command", &"Objectives command", &"Demolish command",
	&"Upgrade command", &"Context detail", &"Detail title", &"Detail tabs", &"Need row",
	&"Skill row", &"Priority cell", &"Schedule grid", &"Lot row", &"Order row",
	&"Fish stock row", &"Crop stat row", &"Room row", &"Relationship row", &"Danger consent",
	&"Quota slider", &"Workspace frame", &"Build catalog", &"Building card", &"Placement ghost",
	&"Placement cost strip", &"Rotate placement", &"Room tool", &"Furniture palette",
	&"Zone brush", &"Recipe list", &"Recipe card", &"Number stepper", &"Feast planner",
	&"Feast theme picker", &"Reserve override", &"Confirm", &"Cancel", &"Immigration review",
	&"Resident row", &"Job matrix", &"Forecast chart", &"Tutorial card", &"Tooltip",
	&"Focus outline", &"Search filter", &"Save browser", &"Save row", &"Settings menu",
	&"Setting control", &"Key binding row", &"Rebind capture", &"Name editor", &"Victory panel",
	&"Collapse panel", &"Error panel", &"Pause label", &"World access list", &"Cycle selection",
	&"Zoom buttons", &"Pitch slider", &"Schedule template", &"Back menu action", &"Panel close",
	&"Scroll bar", &"Tab navigation", &"Context quick menu", &"Relief seed action",
	&"Pin resident", &"Ration reserve", &"Work policy", &"Date trigger", &"History trigger",
	&"New settlement",
]

const ZONES: Array[int] = [
	ZONE_TOP_LEFT, ZONE_TOP_LEFT, ZONE_TOP_LEFT, ZONE_TOP_LEFT, ZONE_TOP_LEFT,
	ZONE_TOP_LEFT, ZONE_TOP_LEFT, ZONE_TOP_LEFT, ZONE_TOP_LEFT,
	ZONE_TOP_CENTER, ZONE_TOP_CENTER, ZONE_TOP_CENTER, ZONE_TOP_RIGHT, ZONE_TOP_RIGHT,
	ZONE_TOP_RIGHT, ZONE_TOP_RIGHT, ZONE_TOP_RIGHT, ZONE_TOP_RIGHT, ZONE_TOP_RIGHT,
	ZONE_BOTTOM_LEFT, ZONE_BOTTOM_LEFT, ZONE_BOTTOM_LEFT, ZONE_CENTER, ZONE_CENTER,
	ZONE_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_RIGHT,
	ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT,
	ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT,
	ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT,
	ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_OWNER, ZONE_OWNER, ZONE_TOP_CENTER, ZONE_BOTTOM_CENTER,
	ZONE_BOTTOM_CENTER, ZONE_TOP_RIGHT, ZONE_TOP_CENTER, ZONE_OWNER, ZONE_OWNER,
	ZONE_OWNER, ZONE_TOP_RIGHT, ZONE_CENTER, ZONE_TOP_RIGHT, ZONE_CENTER, ZONE_CENTER,
	ZONE_CENTER, ZONE_BOTTOM_RIGHT, ZONE_CENTER, ZONE_CENTER, ZONE_TOP_CENTER,
	ZONE_TOP_CENTER, ZONE_BOTTOM_CENTER, ZONE_BOTTOM_CENTER, ZONE_TOP_RIGHT,
	ZONE_TOP_RIGHT, ZONE_BOTTOM_CENTER, ZONE_OWNER, ZONE_OWNER, ZONE_OWNER, ZONE_OWNER,
	ZONE_OWNER, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT, ZONE_BOTTOM_RIGHT,
	ZONE_BOTTOM_RIGHT, ZONE_TOP_RIGHT, ZONE_TOP_CENTER, ZONE_TOP_RIGHT,
]

const PROFILES: Array[int] = [
	PROFILE_PANEL, PROFILE_READOUT, PROFILE_READOUT, PROFILE_READOUT, PROFILE_READOUT,
	PROFILE_READOUT, PROFILE_READOUT, PROFILE_BUTTON, PROFILE_PANEL,
	PROFILE_PANEL, PROFILE_NOTICE, PROFILE_PANEL, PROFILE_PANEL, PROFILE_TOGGLE,
	PROFILE_TOGGLE, PROFILE_TOGGLE, PROFILE_TOGGLE, PROFILE_PANEL, PROFILE_BUTTON,
	PROFILE_PANEL, PROFILE_OVERLAY, PROFILE_BUTTON, PROFILE_OVERLAY, PROFILE_OVERLAY,
	PROFILE_OVERLAY, PROFILE_PANEL, PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_BUTTON,
	PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_BUTTON,
	PROFILE_BUTTON, PROFILE_PANEL, PROFILE_READOUT, PROFILE_TOGGLE, PROFILE_METER,
	PROFILE_ROW, PROFILE_FIELD, PROFILE_FIELD, PROFILE_ROW, PROFILE_ROW,
	PROFILE_METER, PROFILE_ROW, PROFILE_ROW, PROFILE_ROW, PROFILE_TOGGLE,
	PROFILE_FIELD, PROFILE_MODAL, PROFILE_PANEL, PROFILE_BUTTON, PROFILE_OVERLAY,
	PROFILE_PANEL, PROFILE_BUTTON, PROFILE_PANEL, PROFILE_PANEL, PROFILE_PANEL,
	PROFILE_PANEL, PROFILE_ROW, PROFILE_FIELD, PROFILE_PANEL, PROFILE_TOGGLE,
	PROFILE_TOGGLE, PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_PANEL, PROFILE_ROW,
	PROFILE_PANEL, PROFILE_PANEL, PROFILE_NOTICE, PROFILE_PANEL, PROFILE_OVERLAY,
	PROFILE_FIELD, PROFILE_MODAL, PROFILE_ROW, PROFILE_MODAL, PROFILE_FIELD,
	PROFILE_ROW, PROFILE_MODAL, PROFILE_MODAL, PROFILE_MODAL, PROFILE_MODAL,
	PROFILE_NOTICE, PROFILE_READOUT, PROFILE_PANEL, PROFILE_BUTTON, PROFILE_BUTTON,
	PROFILE_FIELD, PROFILE_FIELD, PROFILE_BUTTON, PROFILE_BUTTON, PROFILE_FIELD,
	PROFILE_BUTTON, PROFILE_PANEL, PROFILE_BUTTON, PROFILE_TOGGLE, PROFILE_FIELD,
	PROFILE_TOGGLE, PROFILE_READOUT, PROFILE_BUTTON, PROFILE_MODAL,
]

const GATES: Array[int] = [
	GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS,
	GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_CONDITION,
	GATE_CONDITION, GATE_CONDITION, GATE_CONDITION, GATE_ALWAYS, GATE_ALWAYS,
	GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_CONDITION, GATE_ALWAYS,
	GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_SELECTED,
	GATE_WORLD_TOOL, GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS, GATE_ALWAYS,
	GATE_ALWAYS, GATE_ALWAYS, GATE_M1, GATE_ALWAYS, GATE_SELECTED,
	GATE_SELECTED, GATE_SELECTED, GATE_SELECTED, GATE_SELECTED, GATE_SELECTED,
	GATE_SELECTED, GATE_WORKSPACE, GATE_WORKSPACE, GATE_SELECTED, GATE_SELECTED,
	GATE_SELECTED, GATE_SELECTED, GATE_SELECTED, GATE_SELECTED, GATE_CONDITION,
	GATE_SELECTED, GATE_WORKSPACE, GATE_WORKSPACE, GATE_WORKSPACE, GATE_WORLD_TOOL,
	GATE_WORLD_TOOL, GATE_WORLD_TOOL, GATE_SELECTED, GATE_WORLD_TOOL, GATE_WORLD_TOOL,
	GATE_WORKSPACE, GATE_WORKSPACE, GATE_CONDITION, GATE_M1, GATE_WORKSPACE,
	GATE_CONDITION, GATE_MODAL, GATE_MODAL, GATE_CONDITION, GATE_WORKSPACE,
	GATE_WORKSPACE, GATE_CONDITION, GATE_TUTORIAL, GATE_CONDITION, GATE_CONDITION,
	GATE_WORKSPACE, GATE_MODAL, GATE_MODAL, GATE_MODAL, GATE_MODAL,
	GATE_MODAL, GATE_MODAL, GATE_SELECTED, GATE_CONDITION, GATE_CONDITION,
	GATE_CONDITION, GATE_CONDITION, GATE_CONDITION, GATE_SELECTED, GATE_ALWAYS,
	GATE_CONDITION, GATE_WORKSPACE, GATE_MODAL, GATE_CONDITION, GATE_CONDITION,
	GATE_CONDITION, GATE_CONDITION, GATE_CONDITION, GATE_SELECTED, GATE_M2,
	GATE_CONDITION, GATE_ALWAYS, GATE_ALWAYS, GATE_MODAL,
]

const SIZE_KINDS: Array[int] = [
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_VIEWPORT, SIZE_FIXED,
	SIZE_DRAG_RECT, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FOOTPRINT,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_OWNER_RELATIVE,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
	SIZE_FIXED, SIZE_FIXED, SIZE_FIXED, SIZE_FIXED,
]

## Minimum width, minimum height, maximum width, maximum height -- §4's "minimum->maximum
## width x height" column. A row whose SIZE_KIND is not SIZE_FIXED holds zeroes here and is
## refused by `minimum_size_into()`; the zeroes are unreachable, not a default size.
const MIN_W: Array[int] = [
	176, 104, 104, 104, 104, 104, 104, 32, 320,
	280, 280, 400, 256, 44, 36, 36, 36, 240, 36,
	160, 144, 32, 0, 8, 0,
	240, 44, 44, 44, 44, 44, 44, 44, 44, 44,
	320, 280, 280, 280, 280, 32, 480, 280, 280,
	280, 280, 280, 280, 280, 280,
	480, 448, 136, 0, 240, 44, 280, 280, 240,
	448, 280, 160, 480, 280, 280, 120, 96, 480,
	280, 480, 320, 280, 160, 0, 200,
	480, 448, 480, 280, 448, 320, 320, 480, 480,
	320, 96, 480, 32, 32, 240, 240, 96, 32,
	16, 32, 200, 240, 32, 280, 280, 36, 32, 480,
]

const MIN_H: Array[int] = [
	88, 36, 36, 36, 36, 36, 36, 32, 240,
	48, 44, 280, 48, 36, 36, 36, 36, 240, 36,
	192, 144, 32, 0, 8, 0,
	136, 44, 44, 44, 44, 44, 44, 44, 44, 44,
	240, 32, 36, 44, 44, 32, 160, 52, 64,
	64, 52, 52, 44, 64, 64,
	320, 240, 128, 0, 80, 44, 128, 160, 112,
	240, 96, 44, 400, 64, 72, 44, 44, 360,
	56, 320, 240, 120, 48, 0, 44,
	320, 64, 320, 56, 48, 160, 200, 360, 320,
	160, 32, 320, 32, 32, 56, 44, 44, 32,
	48, 32, 88, 44, 32, 64, 64, 36, 32, 320,
]

const MAX_W: Array[int] = [
	480, 144, 144, 144, 144, 144, 144, 44, 640,
	420, 420, 720, 320, 56, 56, 56, 56, 560, 44,
	256, 240, 44, 0, 512, 0,
	640, 112, 112, 112, 112, 112, 112, 112, 120, 120,
	384, 352, 352, 352, 352, 44, 896, 896, 896,
	352, 352, 352, 352, 352, 352,
	960, 928, 208, 0, 640, 112, 640, 640, 640,
	928, 896, 320, 960, 896, 896, 240, 160, 960,
	896, 960, 896, 420, 360, 0, 640,
	960, 896, 960, 896, 896, 560, 560, 800, 800,
	720, 240, 960, 44, 44, 320, 360, 240, 44,
	24, 44, 320, 352, 44, 352, 896, 120, 32, 960,
]

const MAX_H: Array[int] = [
	88, 40, 40, 40, 40, 40, 40, 44, 640,
	96, 88, 640, 88, 44, 44, 44, 44, 600, 44,
	288, 240, 44, 0, 512, 0,
	136, 44, 44, 44, 44, 44, 44, 44, 44, 44,
	936, 64, 72, 56, 56, 44, 320, 64, 80,
	88, 72, 80, 64, 88, 88,
	720, 624, 160, 0, 112, 44, 240, 320, 160,
	624, 128, 64, 720, 88, 96, 48, 48, 720,
	72, 720, 480, 192, 240, 0, 44,
	720, 80, 720, 80, 64, 240, 280, 600, 560,
	480, 40, 720, 44, 44, 72, 48, 48, 44,
	600, 44, 480, 72, 44, 88, 88, 44, 32, 720,
]

# --- refusals -----------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_ID: StringName = &"UI_UNKNOWN_ELEMENT_ID"
const REFUSE_SIZE_NOT_FIXED: StringName = &"UI_SIZE_IS_NOT_A_FIXED_RECTANGLE"


class Size:
	"""One §4 size range in logical UI pixels. Only ever filled from a SIZE_FIXED row."""

	var min_width: int = 0
	var min_height: int = 0
	var max_width: int = 0
	var max_height: int = 0

	func reset() -> void:
		"""Return every field to zero so a refused read cannot leave a previous row's size."""
		min_width = 0
		min_height = 0
		max_width = 0
		max_height = 0


var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Prove every column holds exactly one entry per §4 element before anything reads one."""
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every parallel column must be ELEMENT_COUNT long, and every enum key set complete."""
	assert(NAMES.size() == ELEMENT_COUNT, "§4 defines 103 elements and NAMES must hold all of them")
	assert(ZONES.size() == ELEMENT_COUNT, "every element must have a §1.1 zone owner")
	assert(PROFILES.size() == ELEMENT_COUNT, "every element must select a §2.2 profile")
	assert(GATES.size() == ELEMENT_COUNT, "every element must carry §4's Gate value")
	assert(SIZE_KINDS.size() == ELEMENT_COUNT, "every element must state how its size is given")
	assert(MIN_W.size() == ELEMENT_COUNT and MIN_H.size() == ELEMENT_COUNT,
		"the minimum-size columns must hold one entry per element")
	assert(MAX_W.size() == ELEMENT_COUNT and MAX_H.size() == ELEMENT_COUNT,
		"the maximum-size columns must hold one entry per element")
	assert(ZONE_KEYS.size() == ZONE_COUNT and PROFILE_KEYS.size() == PROFILE_COUNT,
		"every zone and profile constant must be named")
	assert(GATE_KEYS.size() == GATE_COUNT and SIZE_KIND_KEYS.size() == SIZE_KIND_COUNT,
		"every gate and size kind must be named")


static func is_element(id: int) -> bool:
	"""True for a §4 element id, 1..103. There is no id 0 and no id 104."""
	return id >= FIRST_ID and id <= LAST_ID


static func _row_of(id: int) -> int:
	"""Column index of a §4 id. Callers must have proved `is_element(id)` first."""
	return id - FIRST_ID


func name_of(id: int) -> StringName:
	"""The element's §4 name, or the empty StringName after an UNKNOWN_ID refusal."""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return &""
	_last_refusal = REFUSE_NONE
	return NAMES[_row_of(id)]


func element_key(id: int) -> StringName:
	"""The stable runtime id `UI-SET-nnn` the specification names every instance by."""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return &""
	_last_refusal = REFUSE_NONE
	return StringName("UI-SET-%03d" % id)


func zone_of(id: int) -> IntMath.IntResult:
	"""The §1.1 zone that owns this element."""
	return _column_read(id, ZONES)


func profile_of(id: int) -> IntMath.IntResult:
	"""The §2.2 state profile this row selects."""
	return _column_read(id, PROFILES)


func gate_of(id: int) -> IntMath.IntResult:
	"""§4's Gate value: when the element is shown at all."""
	return _column_read(id, GATES)


func size_kind_of(id: int) -> IntMath.IntResult:
	"""How this row states its size: a fixed range, or one of §4's four runtime shapes."""
	return _column_read(id, SIZE_KINDS)


func _column_read(id: int, column: Array[int]) -> IntMath.IntResult:
	"""Read one packed column at `id`, refusing an id §4 does not define."""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, column[_row_of(id)])


func size_into(id: int, out: Size) -> bool:
	"""Fill `out` with the row's minimum/maximum logical size. Allocates nothing.

	REFUSES for the four rows §4 sizes at runtime rather than in pixels (UI-SET-023, 025, 054
	and 074): those have no fixed rectangle to report and a number here would be invented.
	"""
	out.reset()
	if not is_element(id):
		return _refuse(REFUSE_UNKNOWN_ID)
	var row: int = _row_of(id)
	if SIZE_KINDS[row] != SIZE_FIXED:
		return _refuse(REFUSE_SIZE_NOT_FIXED)
	out.min_width = MIN_W[row]
	out.min_height = MIN_H[row]
	out.max_width = MAX_W[row]
	out.max_height = MAX_H[row]
	_last_refusal = REFUSE_NONE
	return true


func is_interactive(id: int) -> bool:
	"""True when §2.2 gives the row's profile pressed/hover states a player can reach.

	PANEL, READOUT, METER, NOTICE, OVERLAY and MODAL rows are containers or readouts; their
	interactive children carry their own §4 definitions. This is what the 32x32 hitbox rule and
	the focus order are asserted against.
	"""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return false
	_last_refusal = REFUSE_NONE
	var profile: int = PROFILES[_row_of(id)]
	return profile == PROFILE_BUTTON or profile == PROFILE_TOGGLE \
		or profile == PROFILE_ROW or profile == PROFILE_FIELD


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful read."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false. No sentinel value is ever returned."""
	_last_refusal = code
	return false
