extends RefCounted
## Which §4 elements this shell actually drives, and the exact owner every other one is waiting on.
##
## Task 04.4, bullet 2, closes with a rule this file exists to keep: "The generic rendered shell
## cannot claim unbuilt panels work." A registry of 103 elements makes that easy to violate --
## drawing a plausible empty panel for a store that does not exist reads, to a player and to a
## reviewer, exactly like a working one. So every element is in one of two states here and there
## is no third:
##
##   WIRED        the shell builds it, it reads or writes real state, and its suite proves it.
##   UNAVAILABLE  the shell builds it DISABLED, with §2.2's "Unavailable" wording plus the name
##                of the missing owner, and no control inside it can be activated.
##
## §2.2 already specifies that rendering: "disabled MUTED text with 'Unavailable' reason" for
## PANEL, "disabled PANEL/MUTED+lock icon" for BUTTON, "disabled MUTED+'Unavailable'" for
## READOUT. An unavailable element is therefore still VISIBLE and still in the catalog -- §4's
## gate rules say "A locked M-gated control remains visible in its catalog with the GDD milestone
## condition" -- it is simply never mistakable for a working one.
##
## ---------------------------------------------------------------------------------------
## THE REASONS NAME OWNERS, NOT MOODS. "Not implemented" is not a reason a player or the next
## coder can act on. Each code below names the store, codec or contract that does not exist yet
## and the task that owns it, and `PANEL_NOT_BUILT` is used ONLY where the owning store DOES
## exist and the panel is honestly the missing part -- which is a different and weaker excuse,
## stated as such rather than disguised as a blocker.
##
## ---------------------------------------------------------------------------------------
## WHY THIS IS A TABLE AND NOT A RUNTIME PROBE. A probe ("is the store null?") would silently
## flip an element to WIRED the moment another agent lands a store, with no panel built for it
## and no test covering it. The table is a claim this milestone makes and its suite checks; a
## new store changes it by an edit a reviewer can see.

const IntMath := preload("res://scripts/core/int_math.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

# --- reasons -------------------------------------------------------------------------------------

## The element is built and driven by real state.
const REASON_WIRED: int = 0
const REASON_NO_BUILDING_STORE: int = 1
const REASON_NO_TRANSFORM_STORE: int = 2
const REASON_NO_SAVE_CODEC: int = 3
const REASON_NO_MANUAL_TASK_STORE: int = 4
const REASON_NO_HEATING_DEMAND: int = 5
const REASON_NO_RECIPE_ORDER_STORE: int = 6
const REASON_NO_SETTINGS_STORE: int = 7
const REASON_NO_MILESTONE_STATE: int = 8
const REASON_NO_IMMIGRATION_EVENT: int = 9
const REASON_NO_TUTORIAL_STATE: int = 10
const REASON_NO_FORECAST_MODEL: int = 11
const REASON_PANEL_NOT_BUILT: int = 12
const REASON_NO_WORLD_CAMERA: int = 13
const REASON_NO_NOTICE_STORE: int = 14
const REASON_COUNT: int = 15

const REASON_KEYS: Array[StringName] = [
	&"WIRED",
	&"UI_NO_BUILDING_STORE",
	&"UI_NO_TRANSFORM_STORE",
	&"UI_NO_SAVE_CODEC",
	&"UI_NO_MANUAL_TASK_STORE",
	&"UI_NO_HEATING_DEMAND",
	&"UI_NO_RECIPE_ORDER_STORE",
	&"UI_NO_SETTINGS_STORE",
	&"UI_NO_MILESTONE_STATE",
	&"UI_NO_IMMIGRATION_EVENT",
	&"UI_NO_TUTORIAL_STATE",
	&"UI_NO_FORECAST_MODEL",
	&"UI_PANEL_NOT_BUILT",
	&"UI_NO_WORLD_CAMERA",
	&"UI_NO_NOTICE_STORE",
]

## §2.2's disabled wording. Every unavailable element's accessible description starts with it.
const UNAVAILABLE_WORD: String = "Unavailable"

const REASON_TEXTS: Array[String] = [
	"",
	"no Building, Furniture or Room store exists; task 06 owns those contracts",
	"no Transform or route store exists; task 05 and SET-MOVE-001 own movement",
	"no save codec exists; task 09 owns it",
	"no ManualTask store exists; blocker U6 leaves its indexing unspecified",
	"no implemented system supplies a daily heating demand to divide fuel by",
	"no recipe order or production station store exists",
	"no settings or key-binding persistence exists",
	"no milestone or Hearth Charter progression state exists",
	"no immigration candidate queue exists",
	"no tutorial disclosure state exists",
	"no forecast model exists; potential harvest must never be drawn as ready food",
	"the owning store exists, but this panel is not built in this milestone",
	"the interface binds no camera; the prototype scene's fixed camera is not §6's contract",
	"no notification history store exists; only the live alert is kept",
]

# --- the claim ------------------------------------------------------------------------------------

## Reason per §4 element, indexed by `id - 1`. REASON_WIRED means this shell builds and drives it.
const REASON_OF: Array[int] = [
	REASON_WIRED,                     # 001 Resource cluster
	REASON_WIRED,                     # 002 Food counter
	REASON_NO_HEATING_DEMAND,         # 003 Fuel counter
	REASON_WIRED,                     # 004 Wood counter
	REASON_WIRED,                     # 005 Stone counter
	REASON_WIRED,                     # 006 Population counter
	REASON_NO_BUILDING_STORE,         # 007 Bed counter
	REASON_WIRED,                     # 008 Expand resources
	REASON_WIRED,                     # 009 Resource ledger
	REASON_WIRED,                     # 010 Alert stack
	REASON_WIRED,                     # 011 Alert card
	REASON_NO_NOTICE_STORE,           # 012 Notice history
	REASON_WIRED,                     # 013 Time cluster
	REASON_WIRED,                     # 014 Pause button
	REASON_WIRED,                     # 015 Speed 1
	REASON_WIRED,                     # 016 Speed 2
	REASON_WIRED,                     # 017 Speed 4
	REASON_WIRED,                     # 018 Calendar
	REASON_WIRED,                     # 019 Menu button
	REASON_WIRED,                     # 020 Minimap frame
	REASON_WIRED,                     # 021 Minimap view
	REASON_WIRED,                     # 022 Map layers
	REASON_WIRED,                     # 023 World surface
	REASON_NO_TRANSFORM_STORE,        # 024 Selection ring
	REASON_NO_TRANSFORM_STORE,        # 025 Box selection
	REASON_WIRED,                     # 026 Command strip
	REASON_NO_BUILDING_STORE,         # 027 Build command
	REASON_WIRED,                     # 028 Zone command
	REASON_PANEL_NOT_BUILT,           # 029 Jobs command
	REASON_NO_RECIPE_ORDER_STORE,     # 030 Food command
	REASON_WIRED,                     # 031 Residents command
	REASON_NO_MILESTONE_STATE,        # 032 Feast command
	REASON_NO_MILESTONE_STATE,        # 033 Objectives command
	REASON_NO_BUILDING_STORE,         # 034 Demolish command
	REASON_NO_BUILDING_STORE,         # 035 Upgrade command
	REASON_WIRED,                     # 036 Context detail
	REASON_WIRED,                     # 037 Detail title
	REASON_WIRED,                     # 038 Detail tabs
	REASON_WIRED,                     # 039 Need row
	REASON_WIRED,                     # 040 Skill row
	REASON_PANEL_NOT_BUILT,           # 041 Priority cell
	REASON_PANEL_NOT_BUILT,           # 042 Schedule grid
	REASON_PANEL_NOT_BUILT,           # 043 Lot row
	REASON_NO_RECIPE_ORDER_STORE,     # 044 Order row
	REASON_PANEL_NOT_BUILT,           # 045 Fish stock row
	REASON_PANEL_NOT_BUILT,           # 046 Crop stat row
	REASON_NO_BUILDING_STORE,         # 047 Room row
	REASON_PANEL_NOT_BUILT,           # 048 Relationship row
	REASON_PANEL_NOT_BUILT,           # 049 Danger consent
	REASON_PANEL_NOT_BUILT,           # 050 Quota slider
	REASON_WIRED,                     # 051 Workspace frame
	REASON_NO_BUILDING_STORE,         # 052 Build catalog
	REASON_NO_BUILDING_STORE,         # 053 Building card
	REASON_NO_BUILDING_STORE,         # 054 Placement ghost
	REASON_NO_BUILDING_STORE,         # 055 Placement cost strip
	REASON_NO_BUILDING_STORE,         # 056 Rotate placement
	REASON_NO_BUILDING_STORE,         # 057 Room tool
	REASON_NO_BUILDING_STORE,         # 058 Furniture palette
	REASON_WIRED,                     # 059 Zone brush
	REASON_NO_RECIPE_ORDER_STORE,     # 060 Recipe list
	REASON_NO_RECIPE_ORDER_STORE,     # 061 Recipe card
	REASON_WIRED,                     # 062 Number stepper
	REASON_NO_MILESTONE_STATE,        # 063 Feast planner
	REASON_NO_MILESTONE_STATE,        # 064 Feast theme picker
	REASON_NO_MILESTONE_STATE,        # 065 Reserve override
	REASON_WIRED,                     # 066 Confirm
	REASON_WIRED,                     # 067 Cancel
	REASON_NO_IMMIGRATION_EVENT,      # 068 Immigration review
	REASON_WIRED,                     # 069 Resident row
	REASON_PANEL_NOT_BUILT,           # 070 Job matrix
	REASON_NO_FORECAST_MODEL,         # 071 Forecast chart
	REASON_NO_TUTORIAL_STATE,         # 072 Tutorial card
	REASON_WIRED,                     # 073 Tooltip
	REASON_WIRED,                     # 074 Focus outline
	REASON_PANEL_NOT_BUILT,           # 075 Search filter
	REASON_NO_SAVE_CODEC,             # 076 Save browser
	REASON_NO_SAVE_CODEC,             # 077 Save row
	REASON_NO_SETTINGS_STORE,         # 078 Settings menu
	REASON_NO_SETTINGS_STORE,         # 079 Setting control
	REASON_NO_SETTINGS_STORE,         # 080 Key binding row
	REASON_NO_SETTINGS_STORE,         # 081 Rebind capture
	REASON_PANEL_NOT_BUILT,           # 082 Name editor
	REASON_NO_MILESTONE_STATE,        # 083 Victory panel
	REASON_NO_MILESTONE_STATE,        # 084 Collapse panel
	REASON_WIRED,                     # 085 Error panel
	REASON_WIRED,                     # 086 Pause label
	REASON_PANEL_NOT_BUILT,           # 087 World access list
	REASON_NO_TRANSFORM_STORE,        # 088 Cycle selection
	REASON_NO_WORLD_CAMERA,           # 089 Zoom buttons
	REASON_NO_WORLD_CAMERA,           # 090 Pitch slider
	REASON_PANEL_NOT_BUILT,           # 091 Schedule template
	REASON_WIRED,                     # 092 Back menu action
	REASON_WIRED,                     # 093 Panel close
	REASON_WIRED,                     # 094 Scroll bar
	REASON_PANEL_NOT_BUILT,           # 095 Tab navigation
	REASON_WIRED,                     # 096 Context quick menu
	REASON_PANEL_NOT_BUILT,           # 097 Relief seed action
	REASON_PANEL_NOT_BUILT,           # 098 Pin resident
	REASON_NO_MILESTONE_STATE,        # 099 Ration reserve
	REASON_WIRED,                     # 100 Work policy
	REASON_WIRED,                     # 101 Date trigger
	REASON_WIRED,                     # 102 History trigger
	REASON_WIRED,                     # 103 New settlement
]

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_ID: StringName = &"UI_UNKNOWN_ELEMENT_ID"
const REFUSE_UNKNOWN_REASON: StringName = &"UI_UNKNOWN_UNAVAILABLE_REASON"
const REFUSE_ELEMENT_IS_WIRED: StringName = &"UI_ELEMENT_IS_WIRED"

var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Prove the claim covers every §4 element and names every reason it uses."""
	_assert_contracts()


func _assert_contracts() -> void:
	"""One reason per element, one key and one sentence per reason, and no unnamed reason used."""
	assert(REASON_OF.size() == UiRegistry.ELEMENT_COUNT,
		"every §4 element must carry an availability claim")
	assert(REASON_KEYS.size() == REASON_COUNT and REASON_TEXTS.size() == REASON_COUNT,
		"every reason must have both a stable key and a player-readable sentence")
	for reason: int in REASON_OF:
		assert(reason >= 0 and reason < REASON_COUNT, "an element claims an undefined reason")


static func is_reason(reason: int) -> bool:
	"""True for a defined reason index."""
	return reason >= 0 and reason < REASON_COUNT


func reason_of(id: int) -> IntMath.IntResult:
	"""The reason index for a §4 element. REASON_WIRED means the shell drives it."""
	if not UiRegistry.is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, REASON_OF[id - UiRegistry.FIRST_ID])


func is_wired(id: int) -> bool:
	"""True when this shell builds the element and drives it from real state."""
	var reason: IntMath.IntResult = reason_of(id)
	return reason.ok and reason.value == REASON_WIRED


func is_unavailable(id: int) -> bool:
	"""True when the element is rendered visibly unavailable with a named missing owner."""
	var reason: IntMath.IntResult = reason_of(id)
	return reason.ok and reason.value != REASON_WIRED


func reason_key_of(id: int) -> StringName:
	"""The stable reason code for an element, or the empty StringName after a refusal."""
	var reason: IntMath.IntResult = reason_of(id)
	if not reason.ok:
		return &""
	return REASON_KEYS[reason.value]


func reason_text(reason: int) -> String:
	"""The player-readable sentence for a reason index, or "" after an UNKNOWN_REASON refusal."""
	if not is_reason(reason):
		_refuse(REFUSE_UNKNOWN_REASON)
		return ""
	_last_refusal = REFUSE_NONE
	return REASON_TEXTS[reason]


func unavailable_label(id: int) -> String:
	"""§2.2's disabled wording for an element: "Unavailable: <named missing owner>".

	REFUSES for a wired element and returns "". There is no such thing as an unavailable label
	for something that works, and returning a plausible one would let a wiring regression print
	an excuse instead of failing.
	"""
	var reason: IntMath.IntResult = reason_of(id)
	if not reason.ok:
		return ""
	if reason.value == REASON_WIRED:
		_refuse(REFUSE_ELEMENT_IS_WIRED)
		return ""
	_last_refusal = REFUSE_NONE
	return "%s: %s" % [UNAVAILABLE_WORD, REASON_TEXTS[reason.value]]


func wired_count() -> int:
	"""How many of §4's 103 elements this shell claims to drive from real state."""
	var total: int = 0
	for reason: int in REASON_OF:
		if reason == REASON_WIRED:
			total += 1
	return total


func unavailable_count() -> int:
	"""How many elements are rendered visibly unavailable with a named missing owner."""
	return UiRegistry.ELEMENT_COUNT - wired_count()


func count_with_reason(reason: int) -> IntMath.IntResult:
	"""How many elements are blocked on one particular missing owner."""
	if not is_reason(reason):
		_refuse(REFUSE_UNKNOWN_REASON)
		return IntMath.IntResult.new(false, 0)
	var total: int = 0
	for claimed: int in REASON_OF:
		if claimed == reason:
			total += 1
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, total)


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
