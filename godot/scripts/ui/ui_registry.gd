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

# --- §4's activation column: what activating a row OPENS -----------------------------------------
#
# §4's last column says, row by row, what a control opens. Transcribing it is what stops an
# ordinary selection from opening a centre workspace: §4.2 gates UI-SET-051 "WORKSPACE or MODAL",
# two named variants, and a row that opens neither must never be given one. Only rows whose
# activation column names a NUMERIC UI-SET id are in `OPENS` -- "opens housing" without an id is
# left out rather than guessed at, because a guess here would be a surface nobody specified.

## The row opens nothing new; it reads, edits or acts in place.
const SURFACE_NONE: int = 0
## §3 layer 30: "Entity detail/ledger/calendar/history", one expansion per zone.
const SURFACE_EXPANSION: int = 1
## §3 layer 40: "Build/recipe/roster/job/feast workspace", the UI-SET-051 WORKSPACE variant.
const SURFACE_WORKSPACE: int = 2
## §3 layer 50: the context quick menu.
const SURFACE_QUICK_MENU: int = 3
## §3 layer 80: "Confirmation/error/modal menu", the UI-SET-051 MODAL variant or a standalone.
const SURFACE_MODAL: int = 4
## §3 layer 10: a world tool strip or ghost. Explicitly NOT a centre frame.
const SURFACE_WORLD_TOOL: int = 5
const SURFACE_COUNT: int = 6

const SURFACE_KEYS: Array[StringName] = [
	&"NONE", &"EXPANSION", &"WORKSPACE", &"QUICK_MENU", &"MODAL", &"WORLD_TOOL",
]

## UI-SET-051, the one centre frame. §4.2 names it "Workspace/modal frame".
const FRAME_ID: int = 51
## The two variants §4.2's gate column gives UI-SET-051. FRAME_VARIANT_NONE is not a third
## variant: it is the answer "this element opens no centre frame at all", which most rows are.
const FRAME_VARIANT_NONE: int = 0
const FRAME_VARIANT_WORKSPACE: int = 1
const FRAME_VARIANT_MODAL: int = 2

## UI-SET-087 World access list. §4.3 gates it "F6/accessible mode" -- a key and an accessibility
## setting, NOT an element. `OPENS` therefore contains no row that opens it, which
## `_assert_contracts()` proves, and no command button can reach it.
const ACCESS_MODE_ID: int = 87
## UI-SET-069 Resident row. §4.1 gives UI-SET-031 "ALWAYS; opens roster rows 069": the roster is
## what the Residents command opens.
const ROSTER_ID: int = 69

## Opener id -> [opened element id, surface kind]. Each entry quotes its §4 phrase.
const OPENS: Dictionary = {
	8: [9, SURFACE_EXPANSION],         # 008 "ALWAYS; toggle 009"
	18: [71, SURFACE_EXPANSION],       # 018 "opens 071 forecast"
	19: [78, SURFACE_MODAL],           # 019 "ALWAYS; opens 078 menu variant; adds MENU"
	22: [96, SURFACE_QUICK_MENU],      # 022 "ALWAYS; opens layers in 096"
	27: [52, SURFACE_WORKSPACE],       # 027 "ALWAYS; opens 052"
	28: [59, SURFACE_WORLD_TOOL],      # 028 "ALWAYS; opens 059"
	29: [70, SURFACE_WORKSPACE],       # 029 "ALWAYS; opens 070"
	30: [60, SURFACE_WORKSPACE],       # 030 "ALWAYS; opens 060"
	31: [69, SURFACE_WORKSPACE],       # 031 "ALWAYS; opens roster rows 069"
	32: [63, SURFACE_WORKSPACE],       # 032 "M1; opens 063"
	33: [51, SURFACE_WORKSPACE],       # 033 "ALWAYS; opens progress in 051/071"
	34: [51, SURFACE_MODAL],           # 034 "opens confirmation, never immediate destruction"
	53: [54, SURFACE_WORLD_TOOL],      # 053 "activate placement 054"
	98: [82, SURFACE_MODAL],           # 098 "resident pin opens 082"
	101: [18, SURFACE_EXPANSION],      # 101 "activates 018; T shortcut"
	102: [12, SURFACE_EXPANSION],      # 102 "activates 012; N shortcut"
}

# --- §1.3 and §2.2's overflow rules --------------------------------------------------------------
#
# There are exactly two policies and NEITHER of them truncates. §1.3 forbids the alternatives by
# name: "never truncate warnings/costs", "no reduced font size fallback", "no auto shorten
# quantity or critical condition". A CLIP or ELLIPSIS or SHRINK value does not exist in this
# enum, so no caller can select one.

## §1.3 "Long labels": "Wrap to 2 lines within fixed-height cells only if font>=16; otherwise
## expand row height; never truncate warnings/costs".
const OVERFLOW_GROW: int = 0
## §1.3 "Large text": "Scroll panels vertically; fixed bottom confirmation row". §4's preamble:
## a container bound "override[s] a maximum only by reducing available height and adding
## internal vertical scroll; they never reduce font size or hitboxes".
const OVERFLOW_SCROLL: int = 1
const OVERFLOW_COUNT: int = 2

const OVERFLOW_KEYS: Array[StringName] = [&"GROW", &"SCROLL"]

## §2.1: "Minimum rendered font size 14 logical pixels".
const MINIMUM_FONT_PX: int = 14
## §2.1: "critical message body 16 minimum".
const CRITICAL_BODY_FONT_PX: int = 16
## §1.3: "Wrap to 2 lines within fixed-height cells only if font>=16".
const WRAP_MINIMUM_FONT_PX: int = 16
## §1.3's stated wrap limit inside a fixed-height cell, before the row must grow instead.
const WRAP_MAXIMUM_LINES: int = 2
## §2.2: "Modal body height scrolls independently of its 60 px confirmation footer".
const CONFIRMATION_FOOTER_PX: int = 60

# --- refusals -----------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_ID: StringName = &"UI_UNKNOWN_ELEMENT_ID"
const REFUSE_SIZE_NOT_FIXED: StringName = &"UI_SIZE_IS_NOT_A_FIXED_RECTANGLE"
const REFUSE_OPENS_NOTHING: StringName = &"UI_ELEMENT_OPENS_NO_SURFACE"
const REFUSE_NO_CENTRE_FRAME: StringName = &"UI_ELEMENT_OPENS_NO_CENTRE_FRAME"
const REFUSE_NOT_A_MODAL: StringName = &"UI_ELEMENT_IS_NOT_A_MODAL"
const REFUSE_DOES_NOT_GROW: StringName = &"UI_ELEMENT_SCROLLS_RATHER_THAN_GROWING"
const REFUSE_NEGATIVE_TEXT: StringName = &"UI_NEGATIVE_TEXT_MEASUREMENT"


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
	assert(SURFACE_KEYS.size() == SURFACE_COUNT and OVERFLOW_KEYS.size() == OVERFLOW_COUNT,
		"every surface kind and overflow policy must be named")
	_assert_opens_contracts()


func _assert_opens_contracts() -> void:
	"""§4's activation column, checked for the three ways a transcription of it can go wrong."""
	for opener: int in OPENS:
		var row: Array = OPENS[opener]
		assert(is_element(opener) and is_element(row[0]),
			"an activation row names an element §4 does not define")
		assert(row[1] > SURFACE_NONE and row[1] < SURFACE_COUNT,
			"an activation row names a surface kind that does not exist")
		assert(row[0] != ACCESS_MODE_ID,
			"§4.3 gates UI-SET-087 on F6/accessible mode, so no element may open it")
		assert(not (GATES[opener - FIRST_ID] == GATE_SELECTED and row[1] == SURFACE_WORKSPACE),
			"an ordinary selection must never open a centre workspace")
	assert(OPENS[31][0] == ROSTER_ID,
		"§4.1: UI-SET-031 is 'ALWAYS; opens roster rows 069'")


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


func opens_element(id: int) -> IntMath.IntResult:
	"""The §4 element this row's activation opens, or an OPENS_NOTHING refusal.

	REFUSES rather than returning 0: §4 has no element zero, and "this button opens nothing"
	is a different answer from "this button opens element zero". UI-SET-031 answers 69, the
	roster; nothing answers 87, because §4.3 gates the world access list on F6/accessible mode.
	"""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return IntMath.IntResult.new(false, 0)
	if not OPENS.has(id):
		_refuse(REFUSE_OPENS_NOTHING)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, OPENS[id][0])


func opens_surface(id: int) -> IntMath.IntResult:
	"""Which §3 surface class this row's activation opens: expansion, workspace, modal, tool."""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return IntMath.IntResult.new(false, 0)
	if not OPENS.has(id):
		_refuse(REFUSE_OPENS_NOTHING)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, OPENS[id][1])


func frame_variant_for(id: int) -> IntMath.IntResult:
	"""Which UI-SET-051 variant this opener asks for: WORKSPACE or MODAL.

	REFUSES for every row that opens no centre frame, which is most of them. That refusal is
	the whole point: a caller that cannot name a variant has no business building a centre
	frame, so ordinary selection can never produce empty centre scaffolding.
	"""
	var surface: IntMath.IntResult = opens_surface(id)
	if not surface.ok:
		return surface
	if surface.value == SURFACE_WORKSPACE:
		_last_refusal = REFUSE_NONE
		return IntMath.IntResult.new(true, FRAME_VARIANT_WORKSPACE)
	if surface.value == SURFACE_MODAL:
		_last_refusal = REFUSE_NONE
		return IntMath.IntResult.new(true, FRAME_VARIANT_MODAL)
	_refuse(REFUSE_NO_CENTRE_FRAME)
	return IntMath.IntResult.new(false, 0)


func opens_centre_frame(id: int) -> bool:
	"""True when activating this row opens the UI-SET-051 centre frame in either variant."""
	return frame_variant_for(id).ok


func overflow_policy_of(id: int) -> IntMath.IntResult:
	"""§1.3's behaviour when this row's content is longer than its rectangle.

	Containers scroll and content rows grow. There is no third answer, because §1.3 rules the
	alternatives out by name: no truncation of warnings or costs, no reduced font size fallback
	and no auto-shortened quantity.
	"""
	var profile: IntMath.IntResult = profile_of(id)
	if not profile.ok:
		return profile
	var scrolls: bool = profile.value == PROFILE_PANEL or profile.value == PROFILE_MODAL
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, OVERFLOW_SCROLL if scrolls else OVERFLOW_GROW)


func body_height_of(id: int) -> IntMath.IntResult:
	"""A MODAL row's scrolling body height: its maximum less §2.2's 60 px confirmation footer.

	REFUSES for every non-MODAL row. §2.2 gives the fixed footer to modals only, and subtracting
	60 px from a counter would invent a scrolling region that row does not have.
	"""
	var profile: IntMath.IntResult = profile_of(id)
	if not profile.ok:
		return profile
	if profile.value != PROFILE_MODAL:
		_refuse(REFUSE_NOT_A_MODAL)
		return IntMath.IntResult.new(false, 0)
	if SIZE_KINDS[_row_of(id)] != SIZE_FIXED:
		_refuse(REFUSE_SIZE_NOT_FIXED)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, MAX_H[_row_of(id)] - CONFIRMATION_FOOTER_PX)


func grown_height_of(id: int, lines: int, line_height_px: int) -> IntMath.IntResult:
	"""§1.3's grown height for a row whose label wrapped to `lines`, clamped to §4's range.

	Takes a MEASURED line count and line height from the caller rather than guessing glyph
	widths here. REFUSES for a scrolling container, which grows no rows, and for a font below
	§2.1's 14 px floor -- shrinking the text is the one escape §1.3 forbids outright.
	"""
	var policy: IntMath.IntResult = overflow_policy_of(id)
	if not policy.ok:
		return policy
	if policy.value != OVERFLOW_GROW:
		_refuse(REFUSE_DOES_NOT_GROW)
		return IntMath.IntResult.new(false, 0)
	if lines < 1 or line_height_px < MINIMUM_FONT_PX:
		_refuse(REFUSE_NEGATIVE_TEXT)
		return IntMath.IntResult.new(false, 0)
	var row: int = _row_of(id)
	if SIZE_KINDS[row] != SIZE_FIXED:
		_refuse(REFUSE_SIZE_NOT_FIXED)
		return IntMath.IntResult.new(false, 0)
	var wanted: int = lines * line_height_px
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, clampi(wanted, MIN_H[row], MAX_H[row]))


func overflow_needs_scroll(id: int, lines: int, line_height_px: int) -> bool:
	"""True when measured content exceeds §4's maximum and the owner must scroll it instead.

	§4's preamble gives the ONLY legal response to that: a container bound "override[s] a maximum
	only by reducing available height and ADDING INTERNAL VERTICAL SCROLL; they never reduce font
	size or hitboxes". So the answer is scroll or not-scroll, and there is no answer meaning clip,
	ellipsize or shrink -- this module has no value that could express one.
	"""
	if not is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return false
	if lines < 1 or line_height_px < MINIMUM_FONT_PX:
		_refuse(REFUSE_NEGATIVE_TEXT)
		return false
	var row: int = _row_of(id)
	if SIZE_KINDS[row] != SIZE_FIXED:
		_refuse(REFUSE_SIZE_NOT_FIXED)
		return false
	_last_refusal = REFUSE_NONE
	return lines * line_height_px > MAX_H[row]


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful read."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false. No sentinel value is ever returned."""
	_last_refusal = code
	return false
