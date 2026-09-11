extends RefCounted
## SET-UX-001 §8.2's logical focus order and §3's Escape ladder, as two ordered tables.
##
## §8.2 states the order in one sentence: "F6 world access shortcut -> resources
## left-to-right/top-to-bottom -> alerts -> time controls -> minimap controls -> commands ->
## detail title/tabs/content. Within modal/workspace: title announcement -> search/filter ->
## content -> Cancel -> Confirm." Those are the two tables below, spelled out as §4 element ids
## so the shell sets `focus_neighbor_*` from the specification rather than from the order the
## nodes happened to be added in.
##
## ---------------------------------------------------------------------------------------
## AN UNAVAILABLE ELEMENT IS STILL VISIBLE AND STILL EXPLAINS ITSELF, SO IT KEEPS ITS TAB STOP.
## §2.2: "Locked controls explain unlock requirements WITHOUT REQUIRING HOVER", and "'Disabled'
## is spoken as state and the reason follows". A keyboard user who cannot reach the disabled
## control cannot hear why it is disabled, so `sequence_into()` keeps unavailable elements in
## the order by default. `include_unavailable = false` exists for the narrower question of which
## controls can actually be ACTIVATED, which is what the shell uses for Enter handling.
##
## ---------------------------------------------------------------------------------------
## THE ESCAPE LADDER IS A PRIORITY LIST, NOT A STACK OF BOOLEANS CHECKED IN SOURCE ORDER. §3:
## "Escape priority: cancel rebind capture -> close quick menu -> cancel current
## placement/zone/room stroke -> close top confirmation -> close workspace -> close detail ->
## clear selection -> open game menu", and "Closing a modal does not also clear selection in the
## same key press". `next_dismissal()` therefore returns EXACTLY ONE level for a given set of
## open layers, which is the property that rule is about; the caller dismisses that one and asks
## again on the next press.

const IntMath := preload("res://scripts/core/int_math.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")

# --- §8.2's HUD focus order ---------------------------------------------------------------------

## The permanent-HUD tab order, as §4 element ids in §8.2's stated sequence.
##   087  the F6 world access shortcut, which §8.2 puts first
##   002..007, 008  the six resource counters left-to-right, top-to-bottom, then the expander
##   011, 102  the alert card, then the history trigger in its right rail
##   014..017, 101, 019  pause, the three speeds, the date trigger, the menu button
##   022, 021, 089  minimap layers, the map itself, then the zoom controls
##   027..033, 028 first  the command strip, in §4's listed order
##   037, 038  the detail title and its tab bar, then the detail content
const HUD_ORDER: Array[int] = [
	87,
	2, 3, 4, 5, 6, 7, 8,
	11, 102,
	14, 15, 16, 17, 101, 19,
	22, 21, 89,
	27, 28, 29, 30, 31, 32, 33,
	37, 38,
]

## §8.2's order inside a modal or workspace: "title announcement -> search/filter -> content ->
## Cancel -> Confirm". The title is UI-SET-037's modal instance, the content is the owning
## panel, and the two actions are UI-SET-067 and UI-SET-066 in that order.
const MODAL_ORDER: Array[int] = [37, 75, 51, 67, 66]

# --- §3's Escape ladder ---------------------------------------------------------------------------

const DISMISS_REBIND_CAPTURE: int = 0
const DISMISS_QUICK_MENU: int = 1
const DISMISS_TOOL_STROKE: int = 2
const DISMISS_CONFIRMATION: int = 3
const DISMISS_WORKSPACE: int = 4
const DISMISS_DETAIL: int = 5
const DISMISS_SELECTION: int = 6
const DISMISS_OPEN_MENU: int = 7
const DISMISS_COUNT: int = 8

const DISMISS_KEYS: Array[StringName] = [
	&"cancel_rebind_capture", &"close_quick_menu", &"cancel_tool_stroke",
	&"close_confirmation", &"close_workspace", &"close_detail",
	&"clear_selection", &"open_game_menu",
]

## Bit per ladder level, for the open-layer mask `next_dismissal()` takes.
const DISMISS_BITS: Array[int] = [1, 2, 4, 8, 16, 32, 64, 128]

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_IN_ORDER: StringName = &"UI_ELEMENT_NOT_IN_FOCUS_ORDER"
const REFUSE_AT_END: StringName = &"UI_NO_NEXT_FOCUS_TARGET"
const REFUSE_AT_START: StringName = &"UI_NO_PREVIOUS_FOCUS_TARGET"
const REFUSE_UNKNOWN_LEVEL: StringName = &"UI_UNKNOWN_DISMISSAL_LEVEL"

var _availability: UiAvailability = null
var _last_refusal: StringName = REFUSE_NONE


func _init(p_availability: UiAvailability = null) -> void:
	"""Adopt the availability claim used to filter the order, and prove both tables are legal."""
	_availability = p_availability if p_availability != null else UiAvailability.new()
	_assert_contracts()


func _assert_contracts() -> void:
	"""Every id in both orders must be a real §4 element, and the ladder must be fully named."""
	for id: int in HUD_ORDER:
		assert(UiRegistry.is_element(id), "the HUD focus order names a §4 element that does not exist")
	for id: int in MODAL_ORDER:
		assert(UiRegistry.is_element(id), "the modal focus order names a §4 element that does not exist")
	assert(DISMISS_KEYS.size() == DISMISS_COUNT and DISMISS_BITS.size() == DISMISS_COUNT,
		"every §3 Escape level must have a name and a bit")


func sequence_into(include_unavailable: bool, out: PackedInt32Array) -> int:
	"""Write the HUD focus order into `out` and return how many ids were written.

	`out` is the caller's buffer and is never resized here: a buffer too small to hold the
	order is filled as far as it goes and the returned count says how many fit, so the caller
	can tell the difference rather than reading past the end of its own array.
	"""
	var written: int = 0
	for id: int in HUD_ORDER:
		if written >= out.size():
			break
		if not include_unavailable and not _availability.is_wired(id):
			continue
		out[written] = id
		written += 1
	_last_refusal = REFUSE_NONE
	return written


func sequence_length(include_unavailable: bool) -> int:
	"""How many ids the HUD focus order holds under this filter."""
	if include_unavailable:
		return HUD_ORDER.size()
	var total: int = 0
	for id: int in HUD_ORDER:
		if _availability.is_wired(id):
			total += 1
	return total


func position_of(id: int) -> IntMath.IntResult:
	"""Zero-based position of an element in the HUD focus order, or a NOT_IN_ORDER refusal."""
	var index: int = HUD_ORDER.find(id)
	if index < 0:
		_refuse(REFUSE_NOT_IN_ORDER)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, index)


func next_after(id: int) -> IntMath.IntResult:
	"""The element Tab moves to from `id`, or a refusal at the end of the order.

	Refuses rather than wrapping: §8.2 gives one linear order and says nothing about wrapping,
	so the shell decides what happens at the end rather than this table inventing it.
	"""
	var here: IntMath.IntResult = position_of(id)
	if not here.ok:
		return here
	if here.value + 1 >= HUD_ORDER.size():
		_refuse(REFUSE_AT_END)
		return IntMath.IntResult.new(false, 0)
	return IntMath.IntResult.new(true, HUD_ORDER[here.value + 1])


func previous_before(id: int) -> IntMath.IntResult:
	"""The element Shift+Tab moves to from `id`, or a refusal at the start of the order."""
	var here: IntMath.IntResult = position_of(id)
	if not here.ok:
		return here
	if here.value == 0:
		_refuse(REFUSE_AT_START)
		return IntMath.IntResult.new(false, 0)
	return IntMath.IntResult.new(true, HUD_ORDER[here.value - 1])


static func is_dismissal_level(level: int) -> bool:
	"""True for one of §3's eight Escape levels."""
	return level >= 0 and level < DISMISS_COUNT


static func dismissal_bit(level: int) -> int:
	"""The open-layer bit for a ladder level. Callers validate the level first."""
	return DISMISS_BITS[level]


func next_dismissal(open_mask: int) -> IntMath.IntResult:
	"""The single §3 level this Escape press acts on, given which layers are open.

	Walks the ladder in the specification's own order and stops at the first open layer.
	DISMISS_OPEN_MENU is the documented fall-through -- "open game menu" when the dismissal
	stack is empty -- so this never refuses for a legal mask.
	"""
	for level: int in DISMISS_COUNT:
		if level == DISMISS_OPEN_MENU:
			break
		if (open_mask & DISMISS_BITS[level]) != 0:
			_last_refusal = REFUSE_NONE
			return IntMath.IntResult.new(true, level)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, DISMISS_OPEN_MENU)


func dismissal_key(level: int) -> StringName:
	"""The stable action key for a ladder level, or the empty StringName after a refusal."""
	if not is_dismissal_level(level):
		_refuse(REFUSE_UNKNOWN_LEVEL)
		return &""
	_last_refusal = REFUSE_NONE
	return DISMISS_KEYS[level]


func availability() -> UiAvailability:
	"""The availability claim this order filters by."""
	return _availability


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
