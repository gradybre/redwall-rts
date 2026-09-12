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
const REFUSE_NO_CONTROL: StringName = &"UI_NO_CONTROL_FOR_ELEMENT"
const REFUSE_TRAPPED: StringName = &"UI_FOCUS_IS_TRAPPED_IN_A_MODAL"
const REFUSE_NO_SURFACE: StringName = &"UI_NO_SURFACE_IS_OPEN"
const REFUSE_SURFACE_FULL: StringName = &"UI_SURFACE_MEMBER_LIMIT"
const REFUSE_NOT_FOCUSED: StringName = &"UI_NOTHING_IS_FOCUSED"

## `focused_element()` uses a refusal, never this, to say nothing is focused. It exists only so
## the internal cursor has a value §4 can never mistake for an element: §4's ids start at 1.
const NO_ELEMENT: int = 0
## Stops the wired HUD order can hold. §8.2's order is 28 long; the headroom is for the modal
## ring, which replaces it while a surface is open.
const ORDER_CAPACITY: int = 64
## Members one workspace or modal surface can declare. §4's largest, UI-SET-070, lists a title,
## a filter, its rows, its cells and two actions.
const SURFACE_CAPACITY: int = 32

var _availability: UiAvailability = null
var _registry: UiRegistry = null
var _last_refusal: StringName = REFUSE_NONE

## §4 id -> the real Control the shell built for it. Bound once; never rebuilt per frame.
var _controls: Dictionary = {}
## The order currently wired into those Controls' focus_next/focus_previous properties.
var _order: PackedInt32Array = PackedInt32Array()
var _order_count: int = 0
## Which element the router last moved focus to. NO_ELEMENT until something is focused.
var _focused: int = NO_ELEMENT

## The open workspace or modal page, its members, and the control that opened it.
var _surface_page: int = NO_ELEMENT
var _surface_opener: int = NO_ELEMENT
var _surface_modal: bool = false
var _members: PackedInt32Array = PackedInt32Array()
var _member_count: int = 0
## The members of the surface the last switch replaced, for the caller to remove from the tree.
var _outgoing: PackedInt32Array = PackedInt32Array()
var _outgoing_count: int = 0
## Background controls an open modal has taken out of the focus order, and the focus mode each
## had before it did. Restored verbatim on close; this router never invents a focus mode.
var _suppressed: PackedInt32Array = PackedInt32Array()
var _suppressed_mode: PackedInt32Array = PackedInt32Array()
var _suppressed_count: int = 0


func _init(p_availability: UiAvailability = null) -> void:
	"""Adopt the availability claim, size every buffer once, and prove both tables are legal."""
	_availability = p_availability if p_availability != null else UiAvailability.new()
	_registry = UiRegistry.new()
	_order.resize(ORDER_CAPACITY)
	_members.resize(SURFACE_CAPACITY)
	_outgoing.resize(SURFACE_CAPACITY)
	_suppressed.resize(ORDER_CAPACITY)
	_suppressed_mode.resize(ORDER_CAPACITY)
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


# --- the order actually on screen ------------------------------------------------------------------

func visible_sequence_into(gates: UiAvailability.Gates, out: PackedInt32Array) -> int:
	"""§8.2's order with every element whose §4 Gate is unsatisfied REMOVED, not merely disabled.

	This is the ordering contract, and it is different from `sequence_into()` above. That one
	writes §8.2's full table, which is the specification. This one writes the stops that exist:
	an element with no Control has no tab stop, so a hidden workspace contributes nothing here
	however many rows §8.2 lists inside it. Unavailable and locked stops DO remain -- they are
	on screen, and §2.2 requires a keyboard user to reach them to hear why they are disabled.
	"""
	var written: int = 0
	for id: int in HUD_ORDER:
		if written >= out.size():
			break
		if not _availability.creates_control(id, gates):
			continue
		out[written] = id
		written += 1
	_last_refusal = REFUSE_NONE
	return written


func bind_controls(controls: Dictionary) -> void:
	"""Adopt the shell's built Controls by §4 id. The router writes focus properties on these."""
	_controls = controls


func wire_hud(gates: UiAvailability.Gates) -> int:
	"""Compute the visible HUD order and write it into the real Controls. Returns stops wired.

	`focus_next`, `focus_previous` and the four `focus_neighbor_*` properties are what Godot's
	own Tab and arrow navigation read. Setting them here is the difference between a focus order
	that exists and one a player can feel; an array nothing writes is the defect, not the fix.
	"""
	_order_count = visible_sequence_into(gates, _order)
	_apply_chain(_order, _order_count, false)
	if _focused != NO_ELEMENT and not _is_in(_order, _order_count, _focused):
		_focused = NO_ELEMENT
	_last_refusal = REFUSE_NONE
	return _order_count


func _apply_chain(ids: PackedInt32Array, count: int, closed: bool) -> void:
	"""Wire `count` ids into their Controls' focus properties.

	`closed` makes the last stop's `focus_next` point back at the first, which is what a modal
	focus trap physically IS: a ring with no path out of it. The HUD is wired OPEN, because
	§8.2 gives one linear order and says nothing about wrapping.
	"""
	for index: int in count:
		var here: Control = _control_of(ids[index])
		if here == null:
			continue
		_link(here, _step(ids, count, index, 1, closed), true)
		_link(here, _step(ids, count, index, -1, closed), false)


func _step(ids: PackedInt32Array, count: int, index: int, delta: int, closed: bool) -> Control:
	"""The Control one step along a chain, or null at an OPEN chain's end. Closed chains wrap."""
	var target: int = index + delta
	if target < 0 or target >= count:
		if not closed:
			return null
		target = (target + count) % count
	return _control_of(ids[target])


func _link(here: Control, target: Control, forward: bool) -> void:
	"""Write one direction of a Control's focus wiring, clearing it when there is no target."""
	var path: NodePath = NodePath() if target == null else here.get_path_to(target)
	if forward:
		here.focus_next = path
		here.focus_neighbor_right = path
		here.focus_neighbor_bottom = path
		return
	here.focus_previous = path
	here.focus_neighbor_left = path
	here.focus_neighbor_top = path


func _control_of(id: int) -> Control:
	"""The bound Control for a §4 id, or null when the shell built none."""
	if not _controls.has(id):
		return null
	return _controls[id] as Control


static func _is_in(ids: PackedInt32Array, count: int, id: int) -> bool:
	"""True when `id` appears in the first `count` entries of a packed column."""
	for index: int in count:
		if ids[index] == id:
			return true
	return false


func wired_count() -> int:
	"""How many stops are currently wired into real Controls."""
	return _order_count


# --- moving focus ------------------------------------------------------------------------------------

func focus_element(id: int) -> bool:
	"""Move focus to one element. Refuses an unbound element and anything outside an open trap."""
	var control: Control = _control_of(id)
	if control == null:
		return _refuse(REFUSE_NO_CONTROL)
	if _surface_modal and not _is_in(_members, _member_count, id):
		return _refuse(REFUSE_TRAPPED)
	if control.is_inside_tree():
		control.grab_focus()
	_focused = id
	_last_refusal = REFUSE_NONE
	return true


func focus_step(forward: bool) -> bool:
	"""Follow the WIRED `focus_next`/`focus_previous` path from the focused control.

	The step reads the NodePath this router wrote onto the Control, not a parallel list. A
	regression that stops writing those properties therefore stops moving focus here too,
	instead of leaving a bookkeeping cursor that walks an order nothing on screen obeys.
	"""
	if _focused == NO_ELEMENT:
		return _refuse(REFUSE_NOT_FOCUSED)
	var here: Control = _control_of(_focused)
	if here == null:
		return _refuse(REFUSE_NO_CONTROL)
	var path: NodePath = here.focus_next if forward else here.focus_previous
	if path.is_empty():
		return _refuse(REFUSE_AT_END if forward else REFUSE_AT_START)
	var target: Control = here.get_node_or_null(path) as Control
	if target == null:
		return _refuse(REFUSE_NO_CONTROL)
	return focus_element(_id_of_control(target))


func _id_of_control(control: Control) -> int:
	"""The §4 id of a bound Control, or NO_ELEMENT when it is not one of ours."""
	for id: int in _controls:
		if _controls[id] == control:
			return id
	return NO_ELEMENT


func focus_first() -> bool:
	"""Put opening focus on the first stop of whatever is currently wired."""
	if _order_count == 0:
		return _refuse(REFUSE_NO_CONTROL)
	return focus_element(_order[0])


func focused_element() -> IntMath.IntResult:
	"""Which element holds focus, or a NOTHING_IS_FOCUSED refusal. Never a sentinel id."""
	if _focused == NO_ELEMENT:
		_refuse(REFUSE_NOT_FOCUSED)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, _focused)


# --- workspaces and modals ----------------------------------------------------------------------------

func open_surface(page_id: int, members: PackedInt32Array, count: int, opener_id: int) -> bool:
	"""Open one workspace or modal page, replacing any open one, and take its opening focus.

	§3 allows "Only one primary management workspace open", so opening a second REPLACES the
	first: its members move to `outgoing_into()` for the caller to remove from the tree, and any
	focus still standing on one of them is dropped rather than left pointing at a dead surface.
	"""
	if count < 0 or count > SURFACE_CAPACITY:
		return _refuse(REFUSE_SURFACE_FULL)
	_restore_background()
	_retire_members()
	_member_count = count
	for index: int in count:
		_members[index] = members[index]
	_surface_page = page_id
	_surface_opener = opener_id
	_surface_modal = _registry.profile_of(page_id).value == UiRegistry.PROFILE_MODAL
	_apply_chain(_members, _member_count, true)
	if _surface_modal:
		_suppress_background()
	_last_refusal = REFUSE_NONE
	return _focus_opening_stop()


func _suppress_background() -> void:
	"""REQ-UX-003: while a modal is open, no background control is a focus stop at all.

	Each suppressed control's previous `focus_mode` is recorded so `_restore_background()` puts
	back exactly what the shell chose, rather than this router deciding which controls are
	focusable -- a decision §2.2 gives to the profile, not to the focus order.
	"""
	_suppressed_count = 0
	for index: int in _order_count:
		var id: int = _order[index]
		if _is_in(_members, _member_count, id):
			continue
		var control: Control = _control_of(id)
		if control == null or control.focus_mode == Control.FOCUS_NONE:
			continue
		_suppressed[_suppressed_count] = id
		_suppressed_mode[_suppressed_count] = control.focus_mode
		_suppressed_count += 1
		control.focus_mode = Control.FOCUS_NONE
		_unwire(id)


func _restore_background() -> void:
	"""Give every suppressed background control back the focus mode the shell gave it."""
	for index: int in _suppressed_count:
		var control: Control = _control_of(_suppressed[index])
		if control != null:
			control.focus_mode = _suppressed_mode[index] as Control.FocusMode
	_suppressed_count = 0


func suppressed_count() -> int:
	"""How many background controls the open modal has taken out of the focus order."""
	return _suppressed_count


func _retire_members() -> void:
	"""Move the open surface's members to the outgoing list and drop focus standing on one."""
	_outgoing_count = _member_count
	for index: int in _member_count:
		_outgoing[index] = _members[index]
		_unwire(_members[index])
	if _focused != NO_ELEMENT and _is_in(_outgoing, _outgoing_count, _focused):
		_focused = NO_ELEMENT
	_member_count = 0


func _unwire(id: int) -> void:
	"""Strip the focus wiring off one Control so a removed surface leaves no path behind."""
	var control: Control = _control_of(id)
	if control == null:
		return
	control.focus_next = NodePath()
	control.focus_previous = NodePath()
	control.focus_neighbor_left = NodePath()
	control.focus_neighbor_right = NodePath()
	control.focus_neighbor_top = NodePath()
	control.focus_neighbor_bottom = NodePath()


func _focus_opening_stop() -> bool:
	"""§8.2: opening focus is the title announcement, then search/filter, then content."""
	for id: int in MODAL_ORDER:
		if _is_in(_members, _member_count, id):
			return focus_element(id)
	if _member_count > 0:
		return focus_element(_members[0])
	return _refuse(REFUSE_NO_CONTROL)


func close_surface(gates: UiAvailability.Gates) -> bool:
	"""Close the open surface and return focus where §2.2 says it goes.

	§2.2: "On close, focus returns to the opening control if still present, otherwise the zone's
	first control." Both branches are taken here; neither leaves focus on a control that has
	just been removed from the tree.
	"""
	if _surface_page == NO_ELEMENT:
		return _refuse(REFUSE_NO_SURFACE)
	_restore_background()
	_retire_members()
	var opener: int = _surface_opener
	_surface_page = NO_ELEMENT
	_surface_opener = NO_ELEMENT
	_surface_modal = false
	wire_hud(gates)
	if opener != NO_ELEMENT and _is_in(_order, _order_count, opener):
		return focus_element(opener)
	return _focus_zone_first(opener)


func _focus_zone_first(opener: int) -> bool:
	"""§2.2's fallback: the first control of the opener's own §1.1 zone, else the first stop."""
	var zone: IntMath.IntResult = _registry.zone_of(opener)
	if zone.ok:
		for index: int in _order_count:
			if _registry.zone_of(_order[index]).value == zone.value:
				return focus_element(_order[index])
	return focus_first()


func outgoing_into(out: PackedInt32Array) -> int:
	"""The members of the surface the last switch or close retired, for the caller to remove."""
	var written: int = 0
	for index: int in _outgoing_count:
		if written >= out.size():
			break
		out[written] = _outgoing[index]
		written += 1
	return written


func outgoing_count() -> int:
	"""How many child surfaces the last switch or close left for the caller to remove."""
	return _outgoing_count


func open_page() -> IntMath.IntResult:
	"""Which workspace or modal page is open, or a NO_SURFACE refusal when none is."""
	if _surface_page == NO_ELEMENT:
		_refuse(REFUSE_NO_SURFACE)
		return IntMath.IntResult.new(false, 0)
	_last_refusal = REFUSE_NONE
	return IntMath.IntResult.new(true, _surface_page)


func is_trapped() -> bool:
	"""REQ-UX-003: true while a modal owns focus and nothing outside it can take it."""
	return _surface_modal


func trap_contains(id: int) -> bool:
	"""True when the element is a member of the open surface."""
	return _is_in(_members, _member_count, id)


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
