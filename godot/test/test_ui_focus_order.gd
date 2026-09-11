extends "res://test/framework/test_case.gd"
## Coverage for §8.2's keyboard focus order and §3's Escape ladder.
##
## §8.2 gives the order as one sentence, quoted in the constants below, and §3 gives the Escape
## priority as another. Both are transcribed here independently of `ui_focus_order.gd`, so a
## reordered table fails rather than agreeing with itself.
##
## The property worth the most is the one §3 states negatively: "Closing a modal does not also
## clear selection in the same key press." One Escape press resolves EXACTLY ONE level, which is
## checked below with several layers open at once.

const UiFocusOrder := preload("res://scripts/ui/ui_focus_order.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## §8.2's stated order, as §4 element ids: world access, resources, alerts, time, minimap,
## commands, detail.
const EXPECTED_ORDER: Array[int] = [
	87,
	2, 3, 4, 5, 6, 7, 8,
	11, 102,
	14, 15, 16, 17, 101, 19,
	22, 21, 89,
	27, 28, 29, 30, 31, 32, 33,
	37, 38,
]

var _order: UiFocusOrder = null
var _availability: UiAvailability = null
var _buffer: PackedInt32Array = PackedInt32Array()


func before_each() -> void:
	"""Build the focus order over the real availability claim, with a buffer big enough."""
	_availability = UiAvailability.new()
	_order = UiFocusOrder.new(_availability)
	_buffer = PackedInt32Array()
	_buffer.resize(EXPECTED_ORDER.size())


func after_each() -> void:
	"""Drop everything so nothing crosses a test boundary."""
	_order = null
	_availability = null
	_buffer = PackedInt32Array()


# --- §8.2's order --------------------------------------------------------------------------------

func test_the_hud_order_is_the_one_section_eight_two_states() -> void:
	"""World access first, then resources, alerts, time, minimap, commands, detail."""
	var written: int = _order.sequence_into(true, _buffer)
	assert_equal(written, EXPECTED_ORDER.size(), "every stop is written")
	for index: int in EXPECTED_ORDER.size():
		assert_equal(_buffer[index], EXPECTED_ORDER[index],
			"stop %d is UI-SET-%03d" % [index, EXPECTED_ORDER[index]])


func test_the_world_access_shortcut_comes_before_every_hud_control() -> void:
	"""§8.2 puts F6 first so a keyboard user reaches the world before the chrome."""
	assert_equal(_order.position_of(87).value, 0, "UI-SET-087 is the first stop")
	assert_true(_order.position_of(2).value > _order.position_of(87).value,
		"the resource counters follow it")
	assert_true(_order.position_of(14).value > _order.position_of(11).value,
		"the time controls follow the alerts")
	assert_true(_order.position_of(37).value > _order.position_of(28).value,
		"and the detail panel comes last, after the commands")


func test_tab_and_shift_tab_walk_the_order_in_both_directions() -> void:
	"""Next and previous must be exact inverses inside the order."""
	assert_equal(_order.next_after(87).value, 2, "Tab from world access reaches the food counter")
	assert_equal(_order.previous_before(2).value, 87, "and Shift+Tab comes back")
	assert_equal(_order.next_after(17).value, 101, "Tab from 4x speed reaches the date trigger")
	assert_equal(_order.previous_before(101).value, 17, "and back again")


func test_the_ends_of_the_order_refuse_rather_than_wrapping() -> void:
	"""§8.2 gives a linear order; wrapping would be this module's invention."""
	assert_false(_order.previous_before(87).ok, "there is nothing before the first stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_AT_START, "with NO_PREVIOUS")
	assert_false(_order.next_after(38).ok, "there is nothing after the last stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_AT_END, "with NO_NEXT")


func test_an_element_outside_the_order_is_refused() -> void:
	"""A control with no stop in §8.2's sentence has no position to report."""
	assert_false(_order.position_of(54).ok, "the placement ghost is not a tab stop")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NOT_IN_ORDER, "with NOT_IN_ORDER")


# --- unavailable controls keep their stop ------------------------------------------------------

func test_unavailable_controls_stay_in_the_order_so_they_can_explain_themselves() -> void:
	"""§2.2: "Locked controls explain unlock requirements without requiring hover"."""
	assert_false(_availability.is_wired(3), "the fuel counter is unavailable")
	assert_true(_order.position_of(3).ok, "and it still has a keyboard stop")
	assert_equal(_order.sequence_length(true), EXPECTED_ORDER.size(),
		"the full order keeps every stop")


func test_the_activatable_filter_drops_exactly_the_unavailable_controls() -> void:
	"""The narrower question -- what can actually be activated -- excludes the excused."""
	var wired_only: int = _order.sequence_length(false)
	assert_true(wired_only < EXPECTED_ORDER.size(), "some stops are not activatable")
	var written: int = _order.sequence_into(false, _buffer)
	assert_equal(written, wired_only, "the filtered write agrees with the filtered length")
	for index: int in written:
		assert_true(_availability.is_wired(_buffer[index]),
			"UI-SET-%03d is activatable" % _buffer[index])


func test_a_buffer_smaller_than_the_order_reports_what_fit() -> void:
	"""The caller's buffer is never resized, so the count is how the caller learns it was short."""
	var small: PackedInt32Array = PackedInt32Array()
	small.resize(3)
	var written: int = _order.sequence_into(true, small)
	assert_equal(written, 3, "only three stops fit")
	assert_equal(small[0], EXPECTED_ORDER[0], "and they are the first three, in order")
	assert_equal(small[2], EXPECTED_ORDER[2], "third stop is in place")


# --- §3's Escape ladder ---------------------------------------------------------------------------

func test_escape_resolves_exactly_one_layer_per_press() -> void:
	"""§3: "Closing a modal does not also clear selection in the same key press"."""
	var mask: int = UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_WORKSPACE) \
		| UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_DETAIL) \
		| UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_SELECTION)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_WORKSPACE,
		"the workspace closes first")
	mask &= ~UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_WORKSPACE)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_DETAIL,
		"then the detail panel, on the next press")
	mask &= ~UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_DETAIL)
	assert_equal(_order.next_dismissal(mask).value, UiFocusOrder.DISMISS_SELECTION,
		"and only then is the selection cleared")


func test_the_ladder_follows_section_threes_stated_priority() -> void:
	"""Rebind capture beats the quick menu, which beats a tool stroke, and so on down."""
	var all_open: int = 0
	for level: int in UiFocusOrder.DISMISS_COUNT:
		all_open |= UiFocusOrder.dismissal_bit(level)
	assert_equal(_order.next_dismissal(all_open).value, UiFocusOrder.DISMISS_REBIND_CAPTURE,
		"rebind capture is cancelled first")
	var without_rebind: int = all_open & ~UiFocusOrder.dismissal_bit(
		UiFocusOrder.DISMISS_REBIND_CAPTURE)
	assert_equal(_order.next_dismissal(without_rebind).value, UiFocusOrder.DISMISS_QUICK_MENU,
		"then the quick menu")
	var tool_only: int = UiFocusOrder.dismissal_bit(UiFocusOrder.DISMISS_TOOL_STROKE)
	assert_equal(_order.next_dismissal(tool_only).value, UiFocusOrder.DISMISS_TOOL_STROKE,
		"a lone tool stroke is cancelled on its own")


func test_an_empty_dismissal_stack_opens_the_game_menu() -> void:
	"""§3's documented fall-through: "open game menu" when nothing is open to dismiss."""
	assert_equal(_order.next_dismissal(0).value, UiFocusOrder.DISMISS_OPEN_MENU,
		"Escape with nothing open opens the menu")
	assert_equal(_order.dismissal_key(UiFocusOrder.DISMISS_OPEN_MENU), &"open_game_menu",
		"and the level carries its stable action key")


func test_every_ladder_level_is_named_and_an_unknown_one_refuses() -> void:
	"""Eight levels, eight keys; a ninth has no name to return."""
	for level: int in UiFocusOrder.DISMISS_COUNT:
		assert_false(String(_order.dismissal_key(level)).is_empty(), "level %d is named" % level)
	assert_equal(_order.dismissal_key(UiFocusOrder.DISMISS_COUNT), &"", "there is no ninth level")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_UNKNOWN_LEVEL,
		"and asking for one refuses")


# --- UXV-033: the order is WIRED into real Controls, not merely tabulated ---------------------------
#
# A focus-order array nothing reads is the defect, not the fix. Every test below builds real
# Controls, hands them to the router and then reads the properties GODOT'S OWN Tab and arrow
# navigation use -- `focus_next`, `focus_previous` and the four `focus_neighbor_*` NodePaths --
# resolving each path back to a Control. If the router stops writing them, movement stops here
# too, because `focus_step()` follows the written path rather than a parallel list.
#
# `grab_focus()` cannot be asserted on under the headless runner: `SceneTree.root` is not itself
# inside the tree during `_initialize()`, so `Control.grab_focus()` errors and `has_focus()` is
# always false. The router calls it when a control IS in a tree; what this suite proves is the
# wiring and the cursor, which is everything that decides where focus goes.

const UiRegistry := preload("res://scripts/ui/ui_registry.gd")

## A resident row, the search filter and the two actions: a plausible workspace membership.
## Deliberately NOT in §8.2's focus order -- the content is declared first -- so a router that
## takes opening focus from the declaration order instead of the specification is caught.
const ROSTER_MEMBERS: Array[int] = [69, 37, 75, 67, 66]
## UI-SET-087's own members, which F6 opens and no command button does.
const ACCESS_MEMBERS: Array[int] = [37, 75, 87, 67, 66]

var _root: Control = null
var _controls: Dictionary = {}
var _gates: UiAvailability.Gates = null


func _build_controls() -> void:
	"""Create one real Button per §4 id the HUD order and both surfaces name, under one parent."""
	_root = Control.new()
	_controls = {}
	var wanted: Array[int] = []
	for id: int in UiFocusOrder.HUD_ORDER:
		wanted.append(id)
	for id: int in ROSTER_MEMBERS:
		if not wanted.has(id):
			wanted.append(id)
	for id: int in ACCESS_MEMBERS:
		if not wanted.has(id):
			wanted.append(id)
	for id: int in wanted:
		var button: Button = Button.new()
		button.name = "UI-SET-%03d" % id
		button.focus_mode = Control.FOCUS_ALL
		_root.add_child(button)
		_controls[id] = button


func _open_gates() -> UiAvailability.Gates:
	"""Gates with a selection, the access list readable and every workspace member present."""
	var gates: UiAvailability.Gates = UiAvailability.Gates.new()
	gates.reset()
	gates.has_selection = true
	gates.milestone = UiAvailability.MILESTONE_M3
	return gates


func _resolved(id: int, forward: bool) -> Control:
	"""Resolve one Control's wired focus NodePath back to the Control it points at."""
	var here: Control = _controls[id] as Control
	var path: NodePath = here.focus_next if forward else here.focus_previous
	if path.is_empty():
		return null
	return here.get_node_or_null(path) as Control


# --- wiring ---------------------------------------------------------------------------------------

func test_the_router_writes_real_focus_neighbours_onto_the_controls() -> void:
	"""The properties Godot's Tab and arrow navigation read must actually change."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	var stops: int = _order.wire_hud(_gates)
	assert_true(stops > 1, "more than one stop is wired")
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(UiFocusOrder.ORDER_CAPACITY)
	var written: int = _order.visible_sequence_into(_gates, buffer)
	assert_equal(written, stops, "the wired count matches the visible order")
	assert_equal(_resolved(buffer[0], true), _controls[buffer[1]],
		"the first stop's focus_next points at the second")
	assert_equal(_resolved(buffer[1], false), _controls[buffer[0]],
		"and the second's focus_previous points back")
	_root.free()


func test_the_arrow_neighbours_are_wired_as_well_as_tab() -> void:
	"""§8.2 gives one logical order; arrows and Tab must not disagree about what it is."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(UiFocusOrder.ORDER_CAPACITY)
	_order.visible_sequence_into(_gates, buffer)
	var first: Control = _controls[buffer[0]] as Control
	assert_equal(first.focus_neighbor_right, first.focus_next, "right follows Tab")
	assert_equal(first.focus_neighbor_bottom, first.focus_next, "so does down")
	var second: Control = _controls[buffer[1]] as Control
	assert_equal(second.focus_neighbor_left, second.focus_previous, "left follows Shift+Tab")
	assert_equal(second.focus_neighbor_top, second.focus_previous, "so does up")
	_root.free()


func test_focus_moves_by_following_the_wiring_rather_than_a_parallel_list() -> void:
	"""`focus_step()` reads the NodePath on the control, so broken wiring breaks movement."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	assert_true(_order.focus_first(), "opening focus lands on the first stop")
	var first: int = _order.focused_element().value
	assert_true(_order.focus_step(true), "Tab moves on")
	var second: int = _order.focused_element().value
	assert_true(second != first, "to a different element")
	assert_equal(_resolved(first, true), _controls[second], "exactly the one the wiring names")
	assert_true(_order.focus_step(false), "and Shift+Tab comes back")
	assert_equal(_order.focused_element().value, first, "to where it started")
	_root.free()


func test_the_hud_chain_is_open_so_tab_does_not_wrap() -> void:
	"""§8.2 gives a linear order; a wrapping HUD would be this router's invention."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	var stops: int = _order.wire_hud(_gates)
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(UiFocusOrder.ORDER_CAPACITY)
	_order.visible_sequence_into(_gates, buffer)
	assert_null(_resolved(buffer[0], false), "the first stop has no previous")
	assert_null(_resolved(buffer[stops - 1], true), "and the last has no next")
	assert_true(_order.focus_element(buffer[stops - 1]), "focus can reach the last stop")
	assert_false(_order.focus_step(true), "stepping past it refuses")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_AT_END, "with NO_NEXT")
	_root.free()


# --- UXV-002: a hidden gate makes no focus stop ------------------------------------------------------

func test_an_element_behind_a_closed_gate_gets_no_tab_stop_at_all() -> void:
	"""A hidden gate creates no Control, so there is nothing for Tab to land on."""
	_build_controls()
	_order.bind_controls(_controls)
	var closed: UiAvailability.Gates = UiAvailability.Gates.new()
	closed.reset()
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(UiFocusOrder.ORDER_CAPACITY)
	var written: int = _order.visible_sequence_into(closed, buffer)
	for index: int in written:
		assert_true(buffer[index] != 37, "the SELECTED detail title is not a stop")
		assert_true(buffer[index] != 38, "nor are its tabs")
	assert_true(written < UiFocusOrder.HUD_ORDER.size(),
		"the visible order is shorter than §8.2's full table")
	_root.free()


func test_selecting_something_adds_its_stops_back_in_specification_order() -> void:
	"""The same elements return, in §8.2's own places, once their gate is satisfied."""
	_build_controls()
	_order.bind_controls(_controls)
	var gates: UiAvailability.Gates = _open_gates()
	var buffer: PackedInt32Array = PackedInt32Array()
	buffer.resize(UiFocusOrder.ORDER_CAPACITY)
	var written: int = _order.visible_sequence_into(gates, buffer)
	var detail_at: int = -1
	for index: int in written:
		if buffer[index] == 37:
			detail_at = index
	assert_true(detail_at > 0, "the detail title is a stop again")
	assert_equal(buffer[detail_at + 1], 38, "and its tabs follow it, as §8.2 states")
	_root.free()


# --- UXV-004: switching a workspace removes the outgoing one and its focus ---------------------------

func test_opening_the_roster_takes_opening_focus_on_the_title() -> void:
	"""§8.2 inside a workspace: "title announcement -> search/filter -> content -> Cancel -> Confirm"."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var members: PackedInt32Array = PackedInt32Array(ROSTER_MEMBERS)
	assert_true(_order.open_surface(UiRegistry.ROSTER_ID, members, members.size(), 31),
		"the roster opens")
	assert_equal(_order.focused_element().value, 37, "opening focus is the title announcement")
	assert_equal(_order.open_page().value, UiRegistry.ROSTER_ID, "and the roster is the open page")
	_root.free()


func test_retiring_a_surface_drops_focus_standing_on_it() -> void:
	"""Focus must never keep naming a member of a surface that has just been removed.

	The replacement page here declares no members, so it takes no opening focus of its own.
	That isolates the question: after the roster is retired, is the focus that stood on one of
	its rows gone, or is it still pointing into a surface the caller is about to free?
	"""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var roster: PackedInt32Array = PackedInt32Array(ROSTER_MEMBERS)
	_order.open_surface(UiRegistry.ROSTER_ID, roster, roster.size(), 31)
	assert_true(_order.focus_element(69), "focus stands on a roster row")
	var empty: PackedInt32Array = PackedInt32Array()
	assert_false(_order.open_surface(51, empty, 0, 33),
		"a page that declares no members takes no opening focus")
	assert_false(_order.focused_element().ok,
		"and the focus standing on the retired row is dropped, not left dangling")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NOT_FOCUSED, "with NOTHING_IS_FOCUSED")
	_root.free()


func test_switching_workspaces_retires_every_outgoing_child_and_stale_focus() -> void:
	"""UXV-004: the replaced surface's children come back for removal, and its focus is dropped."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var roster: PackedInt32Array = PackedInt32Array(ROSTER_MEMBERS)
	_order.open_surface(UiRegistry.ROSTER_ID, roster, roster.size(), 31)
	assert_true(_order.focus_element(69), "focus stands on a roster row")
	var access: PackedInt32Array = PackedInt32Array(ACCESS_MEMBERS)
	assert_true(_order.open_surface(UiRegistry.ACCESS_MODE_ID, access, access.size(), 0),
		"F6 replaces it with the world access list")
	var outgoing: PackedInt32Array = PackedInt32Array()
	outgoing.resize(UiFocusOrder.SURFACE_CAPACITY)
	var count: int = _order.outgoing_into(outgoing)
	assert_equal(count, roster.size(), "every outgoing child is reported for removal")
	assert_true(_order.focused_element().value != 69, "and focus no longer stands on one")
	var stale: Control = _controls[69] as Control
	assert_true(stale.focus_next.is_empty(), "the retired row keeps no wiring behind it")
	_root.free()


func test_only_the_open_surfaces_members_are_wired_into_its_ring() -> void:
	"""A workspace's ring holds its own members and nothing from the one it replaced."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var access: PackedInt32Array = PackedInt32Array(ACCESS_MEMBERS)
	_order.open_surface(UiRegistry.ACCESS_MODE_ID, access, access.size(), 0)
	assert_true(_order.trap_contains(87), "the world access list is a member")
	assert_false(_order.trap_contains(69), "and the roster row is not")
	assert_equal(_resolved(87, true), _controls[67], "content is followed by Cancel")
	assert_equal(_resolved(67, true), _controls[66], "and Cancel by Confirm")
	_root.free()


# --- UXV-033: the modal trap and the return of focus -------------------------------------------------

func test_a_modal_ring_is_closed_so_focus_cannot_tab_out_of_it() -> void:
	"""REQ-UX-003: while a modal is open, focus is trapped in it."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var members: PackedInt32Array = PackedInt32Array([37, 75, 82, 67, 66])
	assert_true(_order.open_surface(82, members, members.size(), 98), "the name editor opens")
	assert_true(_order.is_trapped(), "UI-SET-082 is a MODAL, so focus is trapped")
	assert_equal(_resolved(66, true), _controls[37],
		"Confirm wraps back to the title: the ring has no way out")
	assert_true(_order.focus_element(66), "focus can reach Confirm")
	assert_true(_order.focus_step(true), "and Tab moves on")
	assert_equal(_order.focused_element().value, 37, "back to the first member, never outside")
	_root.free()


func test_a_modal_refuses_to_give_focus_to_a_background_control() -> void:
	"""Asking directly must refuse; a trap that only works for Tab is not a trap."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var members: PackedInt32Array = PackedInt32Array([37, 75, 82, 67, 66])
	_order.open_surface(82, members, members.size(), 98)
	assert_false(_order.focus_element(14), "the pause button cannot take focus")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_TRAPPED, "with TRAPPED")
	assert_true(_order.suppressed_count() > 0, "and the background is out of the focus order")
	assert_equal((_controls[14] as Control).focus_mode, Control.FOCUS_NONE,
		"the pause button is not a focus stop while the modal is open")
	_root.free()


func test_closing_a_modal_returns_focus_to_the_control_that_opened_it() -> void:
	"""§2.2: "On close, focus returns to the opening control if still present"."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var members: PackedInt32Array = PackedInt32Array(ROSTER_MEMBERS)
	_order.open_surface(UiRegistry.ROSTER_ID, members, members.size(), 31)
	assert_true(_order.focus_element(69), "focus moves inside the workspace")
	assert_true(_order.close_surface(_gates), "the workspace closes")
	assert_equal(_order.focused_element().value, 31,
		"and focus returns to the Residents command that opened it")
	assert_false(_order.open_page().ok, "with no surface left open")
	assert_equal((_controls[14] as Control).focus_mode, Control.FOCUS_ALL,
		"the background is a focus stop again")
	_root.free()


func test_closing_falls_back_to_the_zone_when_the_opener_is_gone() -> void:
	"""§2.2's second branch: "otherwise the zone's first control"."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	var members: PackedInt32Array = PackedInt32Array(ACCESS_MEMBERS)
	_order.open_surface(UiRegistry.ACCESS_MODE_ID, members, members.size(), 0)
	assert_true(_order.close_surface(_gates), "F6's list closes with no opening control")
	var landed: IntMath.IntResult = _order.focused_element()
	assert_true(landed.ok, "focus still lands somewhere real")
	assert_true(_availability.creates_control(landed.value, _gates),
		"on a control that actually exists")
	_root.free()


func test_closing_nothing_refuses_rather_than_moving_focus() -> void:
	"""With no surface open there is nothing to close and no focus decision to make."""
	_build_controls()
	_order.bind_controls(_controls)
	_gates = _open_gates()
	_order.wire_hud(_gates)
	assert_false(_order.close_surface(_gates), "closing with nothing open refuses")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NO_SURFACE, "with NO_SURFACE")
	assert_false(_order.focused_element().ok, "and nothing has been focused")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NOT_FOCUSED, "reported as NOT_FOCUSED")
	_root.free()


func test_an_unbound_element_cannot_be_focused() -> void:
	"""Focus must land on a Control, not on an id the shell never built."""
	_build_controls()
	_order.bind_controls(_controls)
	assert_false(_order.focus_element(41), "UI-SET-041 has no control")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NO_CONTROL, "with NO_CONTROL")
	assert_false(_order.focus_step(true), "and stepping with nothing focused refuses")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_NOT_FOCUSED, "with NOT_FOCUSED")
	_root.free()


func test_a_surface_larger_than_the_member_limit_is_refused() -> void:
	"""The member buffer is sized once; a caller that overruns it is told, not truncated."""
	_build_controls()
	_order.bind_controls(_controls)
	var oversized: PackedInt32Array = PackedInt32Array()
	oversized.resize(UiFocusOrder.SURFACE_CAPACITY + 1)
	assert_false(_order.open_surface(51, oversized, oversized.size(), 31), "it refuses")
	assert_equal(_order.last_refusal(), UiFocusOrder.REFUSE_SURFACE_FULL, "with SURFACE_FULL")
	assert_false(_order.open_page().ok, "and no surface was opened")
	_root.free()
