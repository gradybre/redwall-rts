extends "res://test/framework/test_case.gd"
## UI-C4-R01: the SELECTED and WORKSPACE gates must describe the same tree the shell draws.
##
## Before this packet `Gates.has_selection` was never written at all, and `open_workspace_page()`
## wrote only the open page's own surface bit -- never UI-SET-051's frame or UI-SET-092's Back.
## `_register_hit_regions()` refuses to register a region for anything `creates_control()` calls
## ABSENT, so a visibly `.visible = true` panel with an unsatisfied Gate was drawn opaque and
## was absent from the hit table: exactly the "drawn opaque detail/workspace controls kept out of the hit
## table" defect this suite exists to catch, off-tree, the same way `test_ui_shell.gd` does.
##
## Screenshots are not run here and are not claimed as ART-UI-12 acceptance; this proves the
## gate/registration state and emits button signals off-tree,
## the same class of evidence `test_ui_shell.gd` already relies on for its own hit-table claims.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

var _shell: UiShell = null


func before_each() -> void:
	"""Build the real shell off-tree and lay it out for the standard 1280x720 composition."""
	_shell = UiShell.new()
	_shell.build()
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")


func after_each() -> void:
	"""Free the whole built tree so no Control leaks into the next test."""
	if _shell != null:
		_shell.free()
		_shell = null


func _creates(id: int) -> bool:
	"""Whether this shell actually builds a live Control for `id` under the current gates."""
	return _shell.availability().creates_control(id, _shell.gates())


func _absolute_rect(control: Control) -> Rect2:
	"""Sum a control's own rectangle up through its Control ancestors to the shell root.

	Mirrors `ui_shell.gd`'s own private `_shell_rect_of()`: this suite builds the shell
	off-tree, and `global_position` is not trustworthy there either. Only used for controls
	this suite places explicitly through `_place()`, so the walk terminates cleanly.
	"""
	var origin: Vector2 = control.position
	var node: Node = control.get_parent()
	while node != null and node != _shell:
		if node is Control:
			origin += (node as Control).position
		node = node.get_parent()
	return Rect2(origin, control.size)


func _consumes_control(id: int) -> bool:
	"""True when a control's own on-screen rectangle is a registered, consuming hit region."""
	var control: Control = _shell.control_for(id)
	if control == null or not control.visible:
		return false
	var rect: Rect2 = _absolute_rect(control)
	var point: Vector2 = rect.position + rect.size * 0.5
	return not _shell.hit_test().world_receives(point) and _shell.hit_test().consumes_point(point)


func test_nothing_selected_leaves_the_selected_gate_false() -> void:
	"""No resident, job, zone, basin or open detail: SELECTED is false and stays ABSENT."""
	assert_false(_shell.gates().has_selection, "has_selection starts false")
	assert_false(_creates(UiShell.ID_DETAIL), "the journal is absent with nothing selected")
	assert_false(_creates(UiShell.ID_PIN), "and so is the pin action")


func test_opening_resident_detail_sets_the_gate_and_registers_the_panel() -> void:
	"""Selecting a resident and opening the panel sets SELECTED and hit-tests the panel."""
	_shell.select_resident(Vector2i(3, 1), "")
	_shell.set_detail_display("Rowan", "mouse", "")
	_shell.set_detail_open(true)
	assert_true(_shell.gates().has_selection, "a selected resident sets the gate")
	assert_true(_creates(UiShell.ID_DETAIL), "the journal now creates a control")
	assert_true(_consumes_control(UiShell.ID_DETAIL),
		"and its own visible rectangle is a real, registered, consuming region")


func test_closing_detail_keeps_a_still_valid_resident_selection_live() -> void:
	"""Closing the panel must not silently drop a resident/job/zone still selected."""
	_shell.select_resident(Vector2i(3, 1), "")
	_shell.set_detail_open(true)
	_shell.set_detail_open(false)
	assert_true(_shell.gates().has_selection,
		"the resident reference is still valid, so the gate stays true")
	assert_false(_shell.control_for(UiShell.ID_DETAIL).visible, "the journal itself is closed")
	assert_true(_creates(UiShell.ID_PIN),
		"a SELECTED-gated quick action stays reachable, not disabled by the close")


func test_clearing_every_reference_hides_the_selected_controls() -> void:
	"""Only clearing ALL context -- no ref and no open detail -- takes SELECTED away."""
	_shell.select_resident(Vector2i(3, 1), "")
	_shell.set_detail_open(true)
	_shell.set_detail_open(false)
	_shell.select_resident(EntityDirectoryScript.NULL_REF, "")
	assert_false(_shell.gates().has_selection, "no reference and no open detail: SELECTED is false")
	assert_false(_creates(UiShell.ID_PIN), "so the pin action is absent again")


func test_tile_detail_with_no_resident_ref_still_sets_the_gate() -> void:
	"""UIManager opens a bare tile's detail with no resident/job/zone reference at all."""
	_shell.set_detail_display("Tile 4,9 - forest", "No ecology basin here.", "")
	_shell.set_detail_open(true)
	assert_true(_shell.gates().has_selection, "the open tile detail alone sets the gate")
	assert_true(_creates(UiShell.ID_DETAIL), "and the panel is registered")
	_shell.set_detail_open(false)
	assert_false(_shell.gates().has_selection,
		"closing it with no reference behind it drops the gate again")


func test_selecting_a_zone_sets_the_gate_and_shows_its_policy() -> void:
	"""A designated zone is a selection too, and its own policy control follows the gate."""
	var zone: Vector2i = Vector2i(2, 5)
	_shell.select_zone(zone, true)
	assert_true(_shell.gates().has_selection, "selecting a zone sets SELECTED")
	assert_true(_shell.control_for(UiShell.ID_WORK_POLICY).visible, "its policy toggle is shown")
	_shell.select_zone(EntityDirectoryScript.NULL_REF, false)
	assert_false(_shell.gates().has_selection, "clearing the zone drops the gate")
	assert_false(_shell.control_for(UiShell.ID_WORK_POLICY).visible, "and hides the toggle")


func test_selecting_a_job_alone_sets_and_clears_the_gate() -> void:
	"""A job selection with no resident and no open detail also sets SELECTED."""
	_shell.select_job(Vector2i(1, 1))
	assert_true(_shell.gates().has_selection, "a selected job sets the gate")
	_shell.select_job(EntityDirectoryScript.NULL_REF)
	assert_false(_shell.gates().has_selection, "clearing it drops the gate")


func test_opening_a_workspace_gates_the_page_the_frame_and_back() -> void:
	"""§4 gates UI-SET-051 and UI-SET-092 on WORKSPACE, the same fact as the page itself."""
	assert_false(_creates(UiShell.ID_WORKSPACE), "the frame starts absent")
	assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID), "the roster opens")
	assert_true(_creates(UiRegistry.ROSTER_ID), "the page itself is gated open")
	assert_true(_creates(UiShell.ID_WORKSPACE), "so is the frame")
	assert_true(_creates(UiShell.ID_BACK), "and so is Back")
	assert_true(_consumes_control(UiShell.ID_WORKSPACE),
		"the visible frame is a real, registered, consuming region")


func test_switching_pages_keeps_the_frame_and_back_open_throughout() -> void:
	"""A page switch retires the old page only; the frame and Back must not blink absent."""
	assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID), "the roster opens")
	assert_true(_shell.open_workspace_page(UiShell.ID_NEW_SETTLEMENT), "then New Settlement")
	assert_false(_creates(UiRegistry.ROSTER_ID), "the roster's own gate is retired")
	assert_true(_creates(UiShell.ID_NEW_SETTLEMENT), "the new page is gated open")
	assert_true(_creates(UiShell.ID_WORKSPACE), "the frame stayed open across the switch")
	assert_true(_creates(UiShell.ID_BACK), "and so did Back")


func test_back_is_an_idempotent_close_not_a_toggle() -> void:
	"""Pressing Back twice must not reopen what the first press closed."""
	assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID), "the roster opens")
	var frame: Control = _shell.control_for(UiShell.ID_WORKSPACE)
	var point: Vector2 = frame.position + frame.size * 0.5
	assert_false(_shell.hit_test().world_receives(point), "the open frame owns that point")
	(_shell.control_for(UiShell.ID_BACK) as Button).pressed.emit()
	assert_false(frame.visible, "the first Back closes the frame")
	assert_false(_creates(UiShell.ID_WORKSPACE), "and the gate is cleared")
	assert_true(_shell.hit_test().world_receives(point),
		"the world now receives the point the panel used to cover")
	(_shell.control_for(UiShell.ID_BACK) as Button).pressed.emit()
	assert_false(frame.visible, "a second Back does not reopen it")
	assert_false(_creates(UiShell.ID_WORKSPACE), "the gate stays closed")


func test_workspace_gates_hold_at_every_supported_profile() -> void:
	"""The same open/close gating must hold at the profiles this milestone actually supports."""
	for case: Array in [[1920, 1080, 100], [1280, 720, 100], [1280, 720, 125], [1280, 720, 150]]:
		assert_true(_shell.apply_user_scale(int(case[2])), "the %d%% scale applies" % case[2])
		assert_true(_shell.layout_for(int(case[0]), int(case[1])), "the layout computes")
		assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID),
			"%dx%d@%d: the roster opens" % case)
		assert_true(_creates(UiShell.ID_WORKSPACE), "%dx%d@%d: the frame is gated open" % case)
		assert_true(_creates(UiShell.ID_BACK), "%dx%d@%d: Back is gated open" % case)
		(_shell.control_for(UiShell.ID_BACK) as Button).pressed.emit()
		assert_false(_creates(UiShell.ID_WORKSPACE), "%dx%d@%d: closed after Back" % case)
		assert_false(_creates(UiShell.ID_BACK), "%dx%d@%d: and Back closed with it" % case)
	assert_true(_shell.apply_user_scale(100), "the scale is restored")


func test_an_unavailable_true_gated_control_only_registers_when_selected() -> void:
	"""PIN is not wired this milestone, but a true SELECTED gate still admits it to the hit
	table so a keyboard/pointer user can reach its disabled explanation; ABSENT removes it
	from that same table entirely rather than merely disabling it in place.
	"""
	var without_selection: int = _shell.hit_test().region_count()
	assert_false(_creates(UiShell.ID_PIN), "nothing is selected, so PIN is absent")
	_shell.select_resident(Vector2i(5, 2), "")
	_shell.set_detail_open(true)
	var pin: Button = _shell.control_for(UiShell.ID_PIN) as Button
	assert_true(pin.disabled, "PIN is still disabled; this milestone does not wire it")
	assert_true(_creates(UiShell.ID_PIN),
		"but a true SELECTED gate still creates a control for it")
	assert_true(_shell.hit_test().region_count() > without_selection,
		"and the hit table gained a real region for it, not merely a disabled pixel")


func test_selection_rewires_keyboard_order_without_waiting_for_layout() -> void:
	var before: int = _shell.focus_order().wired_count()
	_shell.select_resident(Vector2i(5, 2), "")
	assert_true(_shell.focus_order().wired_count() > before, "selection updates the wired keyboard order")
	_shell.select_resident(EntityDirectoryScript.NULL_REF, "")
	assert_equal(_shell.focus_order().wired_count(), before, "clearing context retires its stops immediately")


func _assert_visible_controls_have_satisfied_gates() -> void:
	for id: int in _shell.availability().RENDERED_IDS:
		var control: Control = _shell.control_for(id)
		if control == null:
			continue
		var shown: bool = true
		var current: Node = control
		while current != null and current != _shell:
			if current is Control and not (current as Control).visible:
				shown = false
			current = current.get_parent()
		if shown:
			assert_true(_creates(id), "visible UI-SET-%03d has a satisfied gate" % id)


func test_visible_control_gate_invariant_in_every_context_and_profile() -> void:
	for profile: Array in [[1920, 1080, 100], [1280, 720, 100], [1280, 720, 125], [1280, 720, 150]]:
		_shell.apply_user_scale(profile[2])
		_shell.layout_for(profile[0], profile[1])
		_assert_visible_controls_have_satisfied_gates()
		_shell.set_detail_open(true)
		_assert_visible_controls_have_satisfied_gates()
		_shell.set_detail_open(false)
		for page: int in [UiRegistry.ROSTER_ID, UiShell.ID_NEW_SETTLEMENT, UiShell.ID_NAME_EDITOR]:
			if page == UiShell.ID_NAME_EDITOR:
				_shell.select_resident(Vector2i(3, 1), "Rowan")
			_shell.open_workspace_page(page)
			_assert_visible_controls_have_satisfied_gates()
			(_shell.control_for(UiShell.ID_BACK) as Button).pressed.emit()
			_shell.select_resident(EntityDirectoryScript.NULL_REF, "")
			_assert_visible_controls_have_satisfied_gates()


func test_name_editor_without_selected_context_refuses_before_drawing() -> void:
	assert_false(_shell.open_workspace_page(UiShell.ID_NAME_EDITOR), "no selected subject means no name context")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_TARGET, "the missing subject is named")
	assert_false(_shell.control_for(UiShell.ID_WORKSPACE).visible, "no frame was opened on refusal")
	_assert_visible_controls_have_satisfied_gates()
