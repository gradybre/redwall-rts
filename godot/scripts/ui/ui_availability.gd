extends RefCounted
## Which §4 elements this shell actually drives, and the exact owner every other one is waiting on.
##
## Task 04.4, bullet 2, closes with a rule this file exists to keep: "The generic rendered shell
## cannot claim unbuilt panels work." A registry of 103 elements makes that easy to violate --
## drawing a plausible empty panel for a store that does not exist reads, to a player and to a
## reviewer, exactly like a working one.
##
## `REASON_OF` below is that claim: WIRED means this shell drives the element from real state,
## and anything else names the exact store, codec or contract it is waiting on.
##
## ---------------------------------------------------------------------------------------
## THE CLAIM IS ONE AXIS OF FOUR STATES, NOT THE WHOLE ANSWER. Collapsing a §4 row to "hidden
## or greyed" loses three distinctions the specification makes, so `state_of()` returns one of:
##
##   ABSENT       §4's Gate is not satisfied. NO Control is created: no focus stop, no
##                accessibility node and no input rectangle. This is the state a hidden panel
##                has, and it is decided BEFORE the claim below is ever consulted.
##   LOCKED       an M-gated row whose milestone is not reached. §4: "A locked M-gated control
##                remains visible in its catalog with the GDD milestone condition; it is hidden
##                from quick commands until unlocked" -- so this state is view-dependent, and
##                REQ-SET-166 requires the underlying rule be inspectable rather than concealed.
##   UNAVAILABLE  visible, not operable, and carrying §2.2's "Unavailable" wording plus the
##                named missing owner. §2.2 gives the rendering: "disabled MUTED text with
##                'Unavailable' reason" for PANEL, "disabled PANEL/MUTED+lock icon" for BUTTON.
##   AVAILABLE    visible and driven by real state.
##
## ---------------------------------------------------------------------------------------
## VISIBILITY IS EVALUATED BEFORE AVAILABILITY, AND THAT ORDER IS THE CONTRACT. Asking "is this
## store missing?" first and hiding the control afterwards produces the same pixels and a
## different program: the Control was built, took a tab stop, announced itself to a screen
## reader and registered an input rectangle before anything hid it. `state_of()` therefore tests
## §4's Gate first and returns ABSENT without reading `REASON_OF` at all.
##
## ---------------------------------------------------------------------------------------
## AN ALWAYS-GATED ROW IS NEVER ABSENT. §4 gives those rows no condition to fail, so an unbuilt
## one stays discoverable as UNAVAILABLE with a COMPACT reason a focused row can print, rather
## than disappearing or opening a full-size page about its own absence.
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

## The longest compact reason §1.3 will let an always-visible row print without growing past two
## wrapped lines. A reason longer than this belongs in the inspection panel, not on the row.
const COMPACT_REASON_LIMIT: int = 40

## One short phrase per reason, for the focus announcement and the row itself. §2.2 requires a
## locked control to "explain unlock requirements WITHOUT REQUIRING HOVER" and §4 forbids a
## full-size unavailable page, so the row prints THIS and the long sentence stays in inspection.
const COMPACT_TEXTS: Array[String] = [
	"",
	"needs the Building store (task 06)",
	"needs the movement store (task 05)",
	"needs the save codec (task 09)",
	"needs the ManualTask store",
	"no system supplies heating demand",
	"needs the recipe order store",
	"needs settings persistence",
	"needs milestone state",
	"needs the immigration queue",
	"needs tutorial state",
	"needs the forecast model",
	"panel not built this milestone",
	"no camera is bound",
	"needs the notice history store",
]

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

# --- the four states ------------------------------------------------------------------------------

## §4's Gate is not satisfied. No Control, no focus stop, no accessibility node, no input rect.
const STATE_ABSENT: int = 0
## Visible in its catalog, not operable, showing the GDD milestone condition it is waiting for.
const STATE_LOCKED: int = 1
## Visible, not operable, showing §2.2's "Unavailable" wording and the named missing owner.
const STATE_UNAVAILABLE: int = 2
## Visible and driven by real state.
const STATE_AVAILABLE: int = 3
const STATE_COUNT: int = 4

const STATE_KEYS: Array[StringName] = [&"ABSENT", &"LOCKED", &"UNAVAILABLE", &"AVAILABLE"]

# --- the two views §4 distinguishes -----------------------------------------------------------------

## §4: "A locked M-gated control remains visible in its CATALOG with the GDD milestone condition".
const VIEW_CATALOG: int = 0
## §4: "...it is hidden from QUICK COMMANDS until unlocked."
const VIEW_QUICK_COMMANDS: int = 1
const VIEW_COUNT: int = 2

# --- tri-state facts the shell supplies -------------------------------------------------------------

## The owning store does not exist, so the gate's real state cannot be read. NOT a false.
const FACT_UNKNOWN: int = 0
const FACT_MET: int = 1
const FACT_NOT_MET: int = 2

## `Gates.milestone` when no milestone or Hearth Charter progression state exists yet.
const MILESTONE_UNKNOWN: int = -1
const MILESTONE_M0: int = 0
const MILESTONE_M1: int = 1
const MILESTONE_M2: int = 2
const MILESTONE_M3: int = 3

## The GDD's own condition for each M gate, quoted from its milestone table. A locked control
## prints the condition it is waiting on, which is what REQ-SET-166 and UX-T11 ask for.
const MILESTONE_CONDITIONS: Array[String] = [
	"",
	"M1 Settled Hearth: day 4 or later, at least 12 residents, 200 portions prepared",
	"M2 Abundance: population 48 or more, survive the first winter, master 3 recipes",
	"M3 Deep Roots: population 80 or more, year 2 or later, food-days 8 or more",
]

# --- what this milestone actually creates a Control for -----------------------------------------------
#
# §4 defines 103 elements. Expanding all of them into disabled on-screen panels would be a
# different and worse lie than omitting them: a screen of scaffolding no owner has designed. So
# this milestone RENDERS the sixty ids below -- task 04.4's own surfaces plus the child templates
# those surfaces require -- and every other row exists only as a specification entry.

const RENDERED_IDS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37, 38, 39, 40, 51, 59, 62, 66,
	67, 69, 73, 74, 75, 82, 85, 86, 87, 89, 90, 92, 93, 94, 96, 98, 100, 101, 102, 103,
]

# --- the value axis, which is NOT the availability axis -------------------------------------------
#
# A counter reading "0" and a counter reading "--" are different claims, and four situations get
# collapsed into one if nobody names them. Only TRUE_ZERO has a figure to print; the other three
# refuse, each with its own code, so a caller cannot turn "nothing is selected" into a zero.

## The store exists, was read, and the answer really is zero.
const VALUE_TRUE_ZERO: int = 0
## Nothing is selected, so there is no subject to report a figure about.
const VALUE_NO_SELECTION: int = 1
## The store exists but no world has populated it yet.
const VALUE_UNINITIALIZED: int = 2
## No owning store exists at all; the feature is not built.
const VALUE_UNSUPPORTED: int = 3
const VALUE_COUNT: int = 4

const VALUE_KEYS: Array[StringName] = [
	&"UI_VALUE_TRUE_ZERO", &"UI_VALUE_NO_SELECTION",
	&"UI_VALUE_UNINITIALIZED", &"UI_VALUE_UNSUPPORTED",
]

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_ID: StringName = &"UI_UNKNOWN_ELEMENT_ID"
const REFUSE_UNKNOWN_REASON: StringName = &"UI_UNKNOWN_UNAVAILABLE_REASON"
const REFUSE_ELEMENT_IS_WIRED: StringName = &"UI_ELEMENT_IS_WIRED"
const REFUSE_UNKNOWN_VIEW: StringName = &"UI_UNKNOWN_VIEW"
const REFUSE_UNKNOWN_VALUE_KIND: StringName = &"UI_UNKNOWN_VALUE_KIND"
const REFUSE_VALUE_IS_A_FIGURE: StringName = &"UI_VALUE_IS_A_REAL_FIGURE"
const REFUSE_NOT_LOCKED: StringName = &"UI_ELEMENT_IS_NOT_MILESTONE_LOCKED"
const REFUSE_NOT_RENDERED: StringName = &"UI_ELEMENT_NOT_RENDERED_THIS_MILESTONE"


class Gates:
	"""The runtime facts §4's Gate column is evaluated against. Sized once, never per frame."""

	## Which of §4's two views is being built: the catalog, or the quick command strip.
	var view: int = VIEW_CATALOG
	## SELECTED gates: is anything selected at all?
	var has_selection: bool = false
	## WORLD_TOOL gates: is a placement, zone or room stroke in progress?
	var world_tool_active: bool = false
	## TUTORIAL gates: is tutorial disclosure running?
	var tutorial_active: bool = false
	## The highest milestone reached, or MILESTONE_UNKNOWN when no progression state exists.
	var milestone: int = MILESTONE_UNKNOWN
	## 1 for each element whose owning workspace or modal surface is currently open.
	var surface_open: PackedByteArray = PackedByteArray()
	## FACT_UNKNOWN / FACT_MET / FACT_NOT_MET per CONDITION-gated element.
	var condition: PackedByteArray = PackedByteArray()

	func _init() -> void:
		"""Size both columns to §4's registry once. Nothing after this resizes one."""
		surface_open.resize(UiRegistry.ELEMENT_COUNT)
		condition.resize(UiRegistry.ELEMENT_COUNT)

	func reset() -> void:
		"""Close every surface and forget every condition without freeing a column."""
		surface_open.fill(0)
		condition.fill(FACT_UNKNOWN)
		has_selection = false
		world_tool_active = false
		tutorial_active = false

	func set_surface_open(id: int, open: bool) -> void:
		"""Mark one element's owning workspace or modal surface open or closed."""
		if UiRegistry.is_element(id):
			surface_open[id - UiRegistry.FIRST_ID] = 1 if open else 0

	func set_condition(id: int, fact: int) -> void:
		"""Record a CONDITION gate's tri-state fact for one element."""
		if UiRegistry.is_element(id) and fact >= FACT_UNKNOWN and fact <= FACT_NOT_MET:
			condition[id - UiRegistry.FIRST_ID] = fact


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
	_assert_state_contracts()


func _assert_state_contracts() -> void:
	"""The four states, the compact phrases and the render set, checked before anything reads one."""
	assert(STATE_KEYS.size() == STATE_COUNT and VALUE_KEYS.size() == VALUE_COUNT,
		"every state and value kind must be named")
	assert(COMPACT_TEXTS.size() == REASON_COUNT,
		"every reason must have a compact phrase as well as a full sentence")
	assert(MILESTONE_CONDITIONS.size() == MILESTONE_M3 + 1,
		"every M gate must carry the GDD condition it is waiting on")
	for index: int in range(1, REASON_COUNT):
		assert(COMPACT_TEXTS[index].length() <= COMPACT_REASON_LIMIT,
			"a compact reason must fit a focused row rather than opening a page")
		assert(not COMPACT_TEXTS[index].is_empty(), "a compact reason must name something")
	for id: int in RENDERED_IDS:
		assert(UiRegistry.is_element(id), "the render set names an element §4 does not define")
	assert(RENDERED_IDS.size() < UiRegistry.ELEMENT_COUNT,
		"the registry must never be expanded wholesale into rendered panels")


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


# --- visibility first, availability second ----------------------------------------------------------

func is_visible(id: int, gates: Gates) -> bool:
	"""Is §4's Gate satisfied? Asked BEFORE anything looks at whether the element works.

	This function never reads `REASON_OF`. That is the whole ordering contract: a gate that is
	not satisfied means no Control exists, so there is nothing for an availability reason to
	describe, and nothing to take a tab stop, announce itself or claim an input rectangle.
	"""
	if not UiRegistry.is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return false
	_last_refusal = REFUSE_NONE
	return _gate_satisfied(id, UiRegistry.GATES[id - UiRegistry.FIRST_ID], gates)


func _gate_satisfied(id: int, gate: int, gates: Gates) -> bool:
	"""One §4 Gate value against the runtime facts. Pure; reads no availability claim."""
	match gate:
		UiRegistry.GATE_ALWAYS:
			return true
		UiRegistry.GATE_SELECTED:
			return gates.has_selection
		UiRegistry.GATE_WORLD_TOOL:
			return gates.world_tool_active
		UiRegistry.GATE_TUTORIAL:
			return gates.tutorial_active
		UiRegistry.GATE_WORKSPACE, UiRegistry.GATE_MODAL:
			return gates.surface_open[id - UiRegistry.FIRST_ID] == 1
		UiRegistry.GATE_M1, UiRegistry.GATE_M2, UiRegistry.GATE_M3:
			return _milestone_visible(gate, gates)
		_:
			return gates.condition[id - UiRegistry.FIRST_ID] != FACT_NOT_MET


func _milestone_visible(gate: int, gates: Gates) -> bool:
	"""§4: a locked M-gated control stays in its catalog and leaves the quick commands."""
	if gates.view == VIEW_CATALOG:
		return true
	return _milestone_reached(gate, gates)


func _milestone_reached(gate: int, gates: Gates) -> bool:
	"""Has the milestone behind an M gate been reached? Unknown progression is never 'yes'."""
	if gates.milestone == MILESTONE_UNKNOWN:
		return false
	return gates.milestone >= gate - UiRegistry.GATE_M1 + MILESTONE_M1


func state_of(id: int, gates: Gates) -> IntMath.IntResult:
	"""The element's single state under these gates: ABSENT, LOCKED, UNAVAILABLE or AVAILABLE.

	The order is fixed and load-bearing. Visibility is decided first and short-circuits; only a
	visible element is asked about its milestone, and only an unlocked visible element is asked
	whether this shell drives it.
	"""
	if not UiRegistry.is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return IntMath.IntResult.new(false, 0)
	if not is_visible(id, gates):
		_last_refusal = REFUSE_NONE
		return IntMath.IntResult.new(true, STATE_ABSENT)
	if _is_milestone_locked(id, gates):
		_last_refusal = REFUSE_NONE
		return IntMath.IntResult.new(true, STATE_LOCKED)
	var reason: IntMath.IntResult = reason_of(id)
	if not reason.ok:
		return reason
	if reason.value != REASON_WIRED:
		_last_refusal = REFUSE_NONE
		return IntMath.IntResult.new(true, STATE_UNAVAILABLE)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, STATE_AVAILABLE)


func _is_milestone_locked(id: int, gates: Gates) -> bool:
	"""True for an M-gated element whose milestone has not been reached or is not known."""
	var gate: int = UiRegistry.GATES[id - UiRegistry.FIRST_ID]
	if gate != UiRegistry.GATE_M1 and gate != UiRegistry.GATE_M2 and gate != UiRegistry.GATE_M3:
		return false
	return not _milestone_reached(gate, gates)


func creates_control(id: int, gates: Gates) -> bool:
	"""Whether the shell builds a Control for this element at all under these gates.

	False for ABSENT and false for anything outside this milestone's render set. A control that
	is not created has no focus stop, no accessibility node and no input rectangle, which is the
	property this predicate exists to make checkable in one call.
	"""
	if not renders(id):
		return false
	var state: IntMath.IntResult = state_of(id, gates)
	return state.ok and state.value != STATE_ABSENT


func can_activate(id: int, gates: Gates) -> bool:
	"""Whether Enter or a click may do anything. Only a visible, unlocked, wired element."""
	var state: IntMath.IntResult = state_of(id, gates)
	return state.ok and state.value == STATE_AVAILABLE


func locked_condition_of(id: int, gates: Gates) -> String:
	"""The GDD milestone condition a locked control prints, or "" after a NOT_LOCKED refusal."""
	if not UiRegistry.is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return ""
	if not _is_milestone_locked(id, gates):
		_refuse(REFUSE_NOT_LOCKED)
		return ""
	_last_refusal = REFUSE_NONE
	var gate: int = UiRegistry.GATES[id - UiRegistry.FIRST_ID]
	return MILESTONE_CONDITIONS[gate - UiRegistry.GATE_M1 + MILESTONE_M1]


# --- what this milestone renders ------------------------------------------------------------------

func renders(id: int) -> bool:
	"""True when this milestone creates a Control for the element at all."""
	if not UiRegistry.is_element(id):
		_refuse(REFUSE_UNKNOWN_ID)
		return false
	_last_refusal = REFUSE_NONE
	return RENDERED_IDS.has(id)


func rendered_count() -> int:
	"""How many of §4's 103 elements this milestone builds a Control for."""
	return RENDERED_IDS.size()


func compact_reason_of(id: int) -> String:
	"""The short phrase an always-visible unbuilt row prints on focus or inspection.

	REFUSES for a wired element, exactly as `unavailable_label()` does, and for an element this
	milestone never renders -- there is no row to print on, so a phrase for one would describe
	something nobody can focus.
	"""
	if not renders(id):
		_refuse(REFUSE_NOT_RENDERED)
		return ""
	var reason: IntMath.IntResult = reason_of(id)
	if not reason.ok:
		return ""
	if reason.value == REASON_WIRED:
		_refuse(REFUSE_ELEMENT_IS_WIRED)
		return ""
	_last_refusal = REFUSE_NONE
	return COMPACT_TEXTS[reason.value]


# --- the value axis -------------------------------------------------------------------------------

static func is_value_kind(kind: int) -> bool:
	"""True for one of the four situations a counter can be in."""
	return kind >= 0 and kind < VALUE_COUNT


func value_has_figure(kind: int) -> bool:
	"""Only VALUE_TRUE_ZERO has a figure to print. The other three have a reason instead."""
	if not is_value_kind(kind):
		_refuse(REFUSE_UNKNOWN_VALUE_KIND)
		return false
	_last_refusal = REFUSE_NONE
	return kind == VALUE_TRUE_ZERO


func value_reason_key_of(kind: int) -> StringName:
	"""The distinct code for a counter with no figure, refusing for a genuine zero.

	Refusing for TRUE_ZERO is the point: a real zero must be printed as a number, and a caller
	that asks this function for one is about to erase the difference.
	"""
	if not is_value_kind(kind):
		_refuse(REFUSE_UNKNOWN_VALUE_KIND)
		return &""
	if kind == VALUE_TRUE_ZERO:
		_refuse(REFUSE_VALUE_IS_A_FIGURE)
		return &""
	_last_refusal = REFUSE_NONE
	return VALUE_KEYS[kind]


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
