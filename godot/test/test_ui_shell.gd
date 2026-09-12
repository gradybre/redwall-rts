extends "res://test/framework/test_case.gd"
## Coverage for the built HUD: what it actually renders, where, and what it refuses to claim.
##
## The other UI suites check tables. This one builds the real Control tree and reads it back:
## the accessible name on each control, its disabled state, its rectangle at two layout
## profiles, and the click-through table derived from its own mouse filters.
##
## Three properties matter most, and each has a test whose failure would be a real defect on
## screen rather than a table disagreement:
##
##   * a decorative region does not consume a world click, read from the built tree;
##   * a counter with no owning store REFUSES a value and keeps its named reason, so no zero
##     can be printed where a bed count would go;
##   * every element §8.2 names as a focus stop is actually built, so the keyboard order is not
##     a list of ids pointing at nothing.
##
## The shell is built OFF-TREE, exactly as `hud.gd` builds it when the headless runner
## instantiates the scene: `build()` is public for that reason.

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")
const UiFocusOrder := preload("res://scripts/ui/ui_focus_order.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiCommandBridge := preload("res://scripts/ui/ui_command_bridge.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const UiNotices := preload("res://scripts/ui/ui_notices.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const UiFrameBuilder := preload("res://ui/ui_frame_builder.gd")
const UiFrameGeometry := preload("res://ui/ui_frame_geometry.gd")
const UiResidentCard := preload("res://scripts/ui/ui_resident_card.gd")

## §1.2's published 1280x720 spans for the two zones asserted here.
const RESOURCE_SPAN: Array[float] = [16.0, 376.0, 16.0, 104.0]
const TIME_SPAN: Array[float] = [960.0, 1264.0, 16.0, 104.0]

## §2.2's disabled wording, stated independently.
const UNAVAILABLE_WORD: String = "Unavailable"

## R-UI-ALERT-001's reported condition, from the 2026-09-11 native capture: the sentence that
## wrapped to three lines inside a 44 px card and drew over the pause line at NARROW.
const THREE_LINE_REFUSAL: String = "Generation refused (WORLD_OCCUPIED): the settlement already has living residents, so the authored world was not published. The settlement is now empty."
## The acceptance case's long source name and validation code.
const LONG_SOURCE: String = "UI-SET-103 New settlement, Mossflower Woods north basin, generation attempt 4 of 4"
const LONG_CODE: String = "WORLD_INIT_REFUSED_OCCUPIED_SETTLEMENT_WITH_LIVING_RESIDENTS_PRESENT"
const RECOVERY: String = "Use New settlement again to generate a world."

## Elements the shell builds even though their owning store does not exist, so that a player who
## looks for fuel, beds or the build catalog is told WHICH owner is missing rather than finding
## nothing there. Every one of them is disabled and carries its reason.
const RENDERED_UNAVAILABLE: Array[int] = [3, 7, 27, 29, 30, 32, 33, 75, 82, 87, 89, 90, 98]

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


func _bound_settlement() -> Dictionary:
	"""Build a real queue, store set and basin, and bind the shell to that queue only.

	The shell is given the COMMAND QUEUE and nothing else, which is why a test can check that a
	button press moved the queue and left the stores alone.
	"""
	var residents: ResidentsScript = ResidentsScript.new()
	var jobs: JobsScript = JobsScript.new(residents)
	var forage: ForageScript = ForageScript.new(jobs.directory(), jobs)
	var queue: CommandsScript = CommandsScript.new(SimClockScript.new(), jobs.directory())
	_shell.bind_bridge(UiCommandBridge.new(queue))
	var made: ForageScript.OpResult = forage.create_zone(ForageScript.ZONE_TYPE_FORAGE,
		0, 0, false, true)
	assert_true(made.ok, "the basin is created (error: %s)" % made.error)
	assert_true(forage.create_patch_set(made.ref, PackedInt32Array([10, 11, 12, 13, 14])).ok,
		"the basin receives §5.5's five patches")
	return {"queue": queue, "forage": forage, "jobs": jobs, "basin": made.ref,
		"residents": residents}


# --- what is built ---------------------------------------------------------------------------------

func test_every_element_the_shell_claims_to_drive_is_actually_built() -> void:
	"""A wired claim with no control behind it would be the exact lie 04.4 forbids."""
	var availability: UiAvailability = _shell.availability()
	var missing: PackedInt32Array = PackedInt32Array()
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if availability.is_wired(id) and not _shell.renders(id):
			missing.append(id)
	assert_equal(missing.size(), 0, "every wired element is built, missing: %s" % missing)
	assert_equal(_shell.rendered_count(), availability.wired_count() + RENDERED_UNAVAILABLE.size(),
		"and the only extra controls are the seven rendered unavailable on purpose")


func test_every_built_control_carries_its_ui_set_id_in_its_accessible_name() -> void:
	"""REQ-UX-010: a focused control must expose a name matching its visible function."""
	var registry: UiRegistry = _shell.registry()
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if not _shell.renders(id):
			continue
		var control: Control = _shell.control_for(id)
		assert_true(control.accessibility_name.contains(String(registry.element_key(id))),
			"UI-SET-%03d names itself: '%s'" % [id, control.accessibility_name])
		assert_true(control.accessibility_name.contains(String(registry.name_of(id))),
			"UI-SET-%03d carries its §4 name" % id)


func test_the_unavailable_elements_that_are_drawn_can_never_be_operated() -> void:
	"""Rendering an excused element is only honest if it cannot be activated.

	A Button says so with `disabled`; a Panel or Label says so by having no focus mode at all,
	so Enter can never reach it. Both are checked, because the shell draws both kinds.
	"""
	for id: int in RENDERED_UNAVAILABLE:
		assert_true(_shell.renders(id), "UI-SET-%03d is drawn" % id)
		assert_false(_shell.availability().is_wired(id), "UI-SET-%03d is not wired" % id)
		_assert_inoperable(id)


func _assert_inoperable(id: int) -> void:
	"""One unavailable element cannot be pressed and says why."""
	var control: Control = _shell.control_for(id)
	var button: Button = control as Button
	if button != null:
		assert_true(button.disabled, "UI-SET-%03d cannot be pressed" % id)
	else:
		assert_equal(control.focus_mode, Control.FOCUS_NONE,
			"UI-SET-%03d cannot take focus, so Enter cannot activate it" % id)
	assert_true(control.accessibility_description.begins_with(UNAVAILABLE_WORD),
		"UI-SET-%03d explains itself: '%s'" % [id, control.accessibility_description])


func test_an_unknown_element_is_refused_rather_than_returning_a_control() -> void:
	"""Asking for an element this shell does not render must refuse, not hand back a neighbour."""
	assert_null(_shell.control_for(70), "the job matrix is not built")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_UNKNOWN_ELEMENT, "with UNKNOWN_ELEMENT")
	assert_false(_shell.renders(70), "and the shell says it does not render it")


# --- the honesty rule ---------------------------------------------------------------------------

func test_an_unavailable_counter_refuses_a_value_and_keeps_its_reason() -> void:
	"""The bed counter has no Building store; a "0" there would read as a measured absence."""
	var beds: Button = _shell.control_for(UiShell.ID_BEDS) as Button
	var before: String = beds.text
	assert_false(_shell.set_counter_display(UiShell.ID_BEDS, "0"), "the value is refused")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NOT_WIRED, "because it is not wired")
	assert_equal(beds.text, before, "and the cell text did not change")
	assert_true(beds.accessibility_description.begins_with(UNAVAILABLE_WORD),
		"the reason is still what a screen reader is given: '%s'" % beds.accessibility_description)


func test_unavailable_controls_are_disabled_and_explain_themselves() -> void:
	"""§2.2: disabled state plus its reason, on every element with no owning store."""
	var availability: UiAvailability = _shell.availability()
	for id: int in [UiShell.ID_FUEL, UiShell.ID_BEDS, UiShell.ID_BUILD, UiShell.ID_JOBS]:
		var control: Control = _shell.control_for(id)
		assert_false(availability.is_wired(id), "UI-SET-%03d is not wired" % id)
		assert_true((control as Button).disabled, "UI-SET-%03d is disabled" % id)
		assert_true(control.accessibility_description.contains(UNAVAILABLE_WORD),
			"UI-SET-%03d says it is unavailable" % id)


func test_wired_controls_are_enabled_and_describe_their_function() -> void:
	"""The other half: an element this shell drives must be operable, not decoratively disabled."""
	for id: int in [UiShell.ID_PAUSE, UiShell.ID_SPEED_2, UiShell.ID_ZONE, UiShell.ID_EXPAND]:
		var button: Button = _shell.control_for(id) as Button
		assert_false(button.disabled, "UI-SET-%03d is operable" % id)
		assert_false(button.accessibility_description.begins_with(UNAVAILABLE_WORD),
			"UI-SET-%03d does not claim to be unavailable" % id)


# --- geometry from the registry ------------------------------------------------------------------

func test_the_zones_land_on_section_one_twos_published_rectangles() -> void:
	"""The built controls, not the layout table, must sit where §1.2 says at 1280x720."""
	var resources: Control = _shell.control_for(UiShell.ID_RESOURCE_CLUSTER)
	assert_almost_equal(resources.position.x, RESOURCE_SPAN[0], "resource cluster left edge")
	assert_almost_equal(resources.position.x + resources.size.x, RESOURCE_SPAN[1], "right edge")
	assert_almost_equal(resources.position.y, RESOURCE_SPAN[2], "top edge")
	var time: Control = _shell.control_for(UiShell.ID_TIME_CLUSTER)
	assert_almost_equal(time.position.x, TIME_SPAN[0], "time cluster left edge")
	assert_almost_equal(time.position.x + time.size.x, TIME_SPAN[1], "right edge")


func test_the_narrow_profile_shows_two_counter_cells_and_hides_the_rest() -> void:
	"""§1.3's narrow resource area holds food-days and population only."""
	assert_true(_shell.layout_for(1280, 720), "the standard layout shows six cells")
	assert_true((_shell.control_for(UiShell.ID_STONE) as Control).visible, "stone is shown wide")
	_shell.apply_user_scale(UiLayout.USER_SCALE_150)
	assert_true(_shell.layout_for(1280, 720), "the narrow layout computes")
	assert_equal(_shell.geometry().profile, UiLayout.PROFILE_NARROW, "1280 at 150 percent is narrow")
	assert_true((_shell.control_for(UiShell.ID_FOOD) as Control).visible, "food-days is kept")
	assert_false((_shell.control_for(UiShell.ID_STONE) as Control).visible, "stone is dropped")


func test_an_unsupported_user_scale_is_refused_by_the_shell_too() -> void:
	"""§1.2 defines three user scales; the shell does not invent a fourth composition."""
	assert_false(_shell.apply_user_scale(110), "110 percent refuses")
	assert_equal(_shell.last_refusal(), UiLayout.REFUSE_USER_SCALE, "with UNSUPPORTED_USER_SCALE")


func test_every_built_control_meets_its_registry_minimum_size() -> void:
	"""A control smaller than §4's minimum would be a hit target the specification forbids."""
	var registry: UiRegistry = _shell.registry()
	var size: UiRegistry.Size = UiRegistry.Size.new()
	for id: int in range(UiRegistry.FIRST_ID, UiRegistry.LAST_ID + 1):
		if not _shell.renders(id) or not registry.size_into(id, size):
			continue
		var control: Control = _shell.control_for(id)
		assert_true(control.custom_minimum_size.x >= float(size.min_width) - 0.01,
			"UI-SET-%03d is at least its minimum width" % id)
		assert_true(control.custom_minimum_size.y >= float(size.min_height) - 0.01,
			"UI-SET-%03d is at least its minimum height" % id)


# --- §1.2's click-through rule, read from the built tree ------------------------------------------

func test_the_centre_of_the_world_is_not_consumed_by_the_hud() -> void:
	"""UX-T04 against the real tree: the world surface overlay must not block the centre."""
	assert_true(_shell.hit_test().world_receives(Vector2(640.0, 300.0)),
		"the centre of the viewport reaches the world")
	assert_true(_shell.hit_test().world_receives(Vector2(500.0, 400.0)), "and so does its left")
	assert_true(_shell.hit_test().world_receives(Vector2(700.0, 200.0)), "and its upper right")


func test_the_world_surface_overlay_is_registered_as_non_consuming() -> void:
	"""§4: UI-SET-023 is "not a fullscreen UI hit block", so its filter must be IGNORE."""
	var surface: Control = _shell.control_for(UiShell.ID_WORLD_SURFACE)
	assert_equal(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the overlay ignores the mouse")
	var elsewhere: Vector2 = Vector2(640.0, 300.0)
	assert_false(_shell.hit_test().element_at(elsewhere).ok,
		"and no element owns a point in the middle of the world")


func test_a_real_control_does_consume_its_own_rectangle() -> void:
	"""The other half of the rule: the time cluster must take the clicks aimed at it."""
	var time: Control = _shell.control_for(UiShell.ID_TIME_CLUSTER)
	var inside: Vector2 = time.position + Vector2(4.0, 4.0)
	assert_false(_shell.hit_test().world_receives(inside), "a click on the cluster is not a world click")
	assert_true(_shell.hit_test().consumes_point(inside), "it is consumed by the HUD")


func test_an_empty_alert_stack_does_not_block_the_world() -> void:
	"""§4: "empty does not block world". A hidden stack must leave no hit rectangle behind."""
	_shell.set_alert_display("")
	var stack: Control = _shell.control_for(UiShell.ID_ALERT_STACK)
	var centre: Vector2 = stack.position + stack.size * 0.5
	assert_false(stack.visible, "the stack is hidden with no alert")
	assert_true(_shell.hit_test().world_receives(centre), "and the world gets that point")
	_shell.set_alert_display("Out of ration!")
	assert_true(stack.visible, "an alert shows the stack")
	assert_false(_shell.hit_test().world_receives(centre), "which then takes its own point")


func test_the_pause_label_has_no_hit_rectangle_when_the_world_is_running() -> void:
	"""§4: UI-SET-086 is "not clickable; no empty hit rect"."""
	_shell.set_pause_display(false, "")
	var label: Control = _shell.control_for(UiShell.ID_PAUSE_LABEL)
	assert_false(label.visible, "the label is hidden while the world runs")
	assert_equal(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and never consumes input")


func test_hidden_expansions_are_not_in_the_hit_table_until_they_open() -> void:
	"""A closed ledger must not take clicks from the world that is drawn behind it."""
	var ledger: Control = _shell.control_for(UiShell.ID_LEDGER)
	var point: Vector2 = ledger.position + Vector2(4.0, 4.0)
	assert_false(ledger.visible, "the ledger starts closed")
	assert_true(_shell.hit_test().world_receives(point), "so that point is the world's")


# --- values are rendered verbatim ---------------------------------------------------------------

func test_the_status_line_and_ledger_are_printed_byte_for_byte() -> void:
	"""The shell renders; it does not reformat. A rounded figure here would be a fabrication."""
	_shell.set_status_line("Paused  x4  Y1 spring 1")
	assert_equal(_shell.status_label().text, "Paused  x4  Y1 spring 1", "the status line is exact")
	_shell.set_ledger_display("Food-days 5.48   Beds --")
	assert_equal(_shell.ledger_label().text, "Food-days 5.48   Beds --", "the ledger line is exact")
	_shell.set_counter_display(UiShell.ID_FOOD, "5.48")
	assert_true((_shell.control_for(UiShell.ID_FOOD) as Button).text.contains("5.48"),
		"and the counter cell shows the supplied string")


func test_the_speed_toggles_show_which_speed_is_requested() -> void:
	"""UI-SET-015/016/017: selected state follows the requested speed, and only one is selected."""
	_shell.set_speed_selected(2)
	assert_false((_shell.control_for(UiShell.ID_SPEED_1) as Button).button_pressed, "1x is not selected")
	assert_true((_shell.control_for(UiShell.ID_SPEED_2) as Button).button_pressed, "2x is selected")
	assert_false((_shell.control_for(UiShell.ID_SPEED_4) as Button).button_pressed, "4x is not")
	_shell.set_speed_selected(4)
	assert_true((_shell.control_for(UiShell.ID_SPEED_4) as Button).button_pressed, "4x is selected")
	assert_false((_shell.control_for(UiShell.ID_SPEED_2) as Button).button_pressed, "2x is released")


func test_the_pause_label_names_the_held_reasons() -> void:
	"""UI-SET-086's value binding is "Paused: "+ordered_pause_reasons, not a bare word."""
	_shell.set_pause_display(true, "PLAYER")
	var label: Label = _shell.control_for(UiShell.ID_PAUSE_LABEL) as Label
	assert_true(label.visible, "the label is shown while paused")
	assert_equal(label.text, "Paused: PLAYER", "and names the reason")
	assert_true((_shell.control_for(UiShell.ID_PAUSE) as Button).button_pressed,
		"UI-SET-014 shows selected while effectively paused")


func test_the_refusal_display_carries_the_exact_text_it_was_given() -> void:
	"""UI-SET-085: "Error code+plain reason+recovery action", not a generic apology."""
	_shell.set_refusal_display("Paint at least one tile before designating. (UI_ZONE_STROKE_IS_EMPTY)")
	var panel: Control = _shell.control_for(UiShell.ID_ERROR_PANEL)
	assert_true(panel.visible, "the error panel opens for a refusal")
	assert_true(panel.accessibility_description.contains("UI_ZONE_STROKE_IS_EMPTY"),
		"the exact code reaches the accessible description")
	_shell.set_refusal_display("")
	assert_false(panel.visible, "and it closes when there is nothing to report")


func test_the_minimap_says_when_no_world_has_been_generated() -> void:
	"""A generated world is the only thing the map can show; its absence is stated, not drawn."""
	_shell.set_minimap_display("No world generated yet. Use New settlement.")
	var line: Label = _shell.control_for(UiShell.ID_MINIMAP_VIEW).get_node("Line") as Label
	assert_true(line.text.contains("No world generated"), "the map says what it does not have")
	assert_equal(line.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"and the text itself takes no click")


# --- §8.2's focus order points at real controls ---------------------------------------------------

func test_every_focus_stop_names_an_element_this_shell_built() -> void:
	"""A keyboard order listing ids with no control is an order that goes nowhere."""
	var order: UiFocusOrder = _shell.focus_order()
	var stops: PackedInt32Array = PackedInt32Array()
	stops.resize(order.sequence_length(true))
	var written: int = order.sequence_into(true, stops)
	assert_true(written > 0, "the order has stops")
	for index: int in written:
		assert_true(_shell.renders(stops[index]),
			"focus stop UI-SET-%03d is built" % stops[index])


func test_interactive_controls_can_take_keyboard_focus() -> void:
	"""§2.2: every interactive element has a focus outline, which requires a focus mode."""
	for id: int in [UiShell.ID_PAUSE, UiShell.ID_ZONE, UiShell.ID_EXPAND, UiShell.ID_MENU]:
		var control: Control = _shell.control_for(id)
		assert_equal(control.focus_mode, Control.FOCUS_ALL, "UI-SET-%03d is focusable" % id)


func test_the_detail_panel_opens_and_changes_the_command_interval() -> void:
	"""§1.2's command strip shortens when the detail panel is open; both must be reachable."""
	var closed_width: float = _shell.geometry().commands.size.x
	_shell.set_detail_open(true)
	assert_true(_shell.layout_for(1280, 720), "the open-detail layout computes")
	assert_true((_shell.control_for(UiShell.ID_DETAIL) as Control).visible, "the panel is open")
	assert_true(_shell.geometry().detail_open, "the geometry knows it")
	assert_true(_shell.geometry().commands.size.x <= closed_width,
		"and the command interval did not grow")


# --- pressing a button issues a command, and never writes a store --------------------------------

func test_pressing_confirm_designates_a_zone_through_the_command_queue() -> void:
	"""The whole of 04.4's acceptance, driven through the real button: a command, not a write."""
	var fixture: Dictionary = _bound_settlement()
	var basin: Vector2i = fixture["basin"]
	assert_true(_shell.select_basin(basin, 0), "the zone tool is pointed at a basin")
	assert_true(_shell.paint_tile(5), "a tile is painted")
	assert_true(_shell.paint_tile(6), "and another")
	var zones_before: int = (fixture["forage"] as ForageScript).zone_count()
	(_shell.control_for(UiShell.ID_CONFIRM) as Button).emit_signal(&"pressed")
	assert_equal((fixture["queue"] as CommandsScript).pending_count(), 1, "one command is queued")
	assert_equal((fixture["forage"] as ForageScript).zone_count(), zones_before,
		"and not one store row changed")
	assert_equal(_shell.stroke_size(), 0, "the committed stroke is cleared")


func test_pressing_confirm_with_nothing_selected_refuses_visibly() -> void:
	"""A button that quietly does nothing is indistinguishable from a broken one."""
	_bound_settlement()
	(_shell.control_for(UiShell.ID_CONFIRM) as Button).emit_signal(&"pressed")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_TARGET, "the action refuses")
	var panel: Control = _shell.control_for(UiShell.ID_ERROR_PANEL)
	assert_true(panel.visible, "and says so in the accessible refusal display")
	assert_true(panel.accessibility_description.contains("UI_SHELL_NOTHING_SELECTED"),
		"with the exact code: '%s'" % panel.accessibility_description)


func test_cancelling_a_stroke_changes_no_queue_or_store_state() -> void:
	"""REQ-UX-012: cancelling a preview removes only uncommitted preview state."""
	var fixture: Dictionary = _bound_settlement()
	assert_true(_shell.select_basin(fixture["basin"], 0), "a basin is selected")
	assert_true(_shell.paint_tile(9), "a tile is painted")
	(_shell.control_for(UiShell.ID_CANCEL) as Button).emit_signal(&"pressed")
	assert_equal(_shell.stroke_size(), 0, "the stroke is gone")
	assert_equal((fixture["queue"] as CommandsScript).pending_count(), 0, "no command was queued")
	assert_equal((fixture["forage"] as ForageScript).zone_count(), 1, "and the basin is untouched")


func test_the_policy_toggle_issues_a_set_policy_command() -> void:
	"""UI-SET-100 reaches `forage.gd` only through ARCH-CMD-001, like every other edit."""
	var fixture: Dictionary = _bound_settlement()
	_shell.select_zone(fixture["basin"], true)
	(_shell.control_for(UiShell.ID_WORK_POLICY) as Button).emit_signal(&"pressed")
	assert_equal((fixture["queue"] as CommandsScript).pending_count(), 1, "one command is queued")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NONE, "the action was accepted")


func test_cancelling_a_job_issues_a_cancel_job_command() -> void:
	"""UI-SET-096's cancel action, which 04.4's acceptance ends on."""
	var fixture: Dictionary = _bound_settlement()
	_shell.select_job(fixture["basin"])
	assert_true(_shell.cancel_selected_job(), "the cancellation is accepted")
	assert_equal((fixture["queue"] as CommandsScript).pending_count(), 1, "as one queued command")
	_shell.select_job(Vector2i(-1, 0))
	assert_false(_shell.cancel_selected_job(), "cancelling nothing refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_TARGET, "with NOTHING_SELECTED")


func test_a_stroke_must_be_ascending_and_inside_the_map() -> void:
	"""§8.1's payload shape is enforced while painting, not discovered at Confirm."""
	assert_true(_shell.paint_tile(10), "a tile is painted")
	assert_false(_shell.paint_tile(10), "the same tile again refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_TILE_NOT_ASCENDING, "as not ascending")
	assert_false(_shell.paint_tile(9), "an earlier tile refuses too")
	assert_false(_shell.paint_tile(ForageScript.TILE_COUNT), "a tile past the grid refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_TILE_RANGE, "as out of range")


func test_an_unbound_shell_refuses_an_action_rather_than_appearing_to_work() -> void:
	"""With no command bridge there is nowhere for an action to go, and it must say so."""
	(_shell.control_for(UiShell.ID_CONFIRM) as Button).emit_signal(&"pressed")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_BRIDGE, "the action refuses")
	assert_true((_shell.control_for(UiShell.ID_ERROR_PANEL) as Control).visible,
		"and the refusal is on screen")


# --- picking a tile on the map ---------------------------------------------------------------

func _click_map(local_position: Vector2) -> void:
	"""Send one left-button press into UI-SET-021 at a position inside the map rectangle."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = local_position
	_shell.control_for(UiShell.ID_MINIMAP_VIEW).emit_signal(&"gui_input", event)


func test_clicking_the_map_picks_the_tile_under_the_pointer() -> void:
	"""UI-SET-021 is the one pointer selection this milestone has, and it needs no camera."""
	var view: Control = _shell.control_for(UiShell.ID_MINIMAP_VIEW)
	assert_true(view.size.x > 0.0, "the map has a rectangle to pick inside")
	_click_map(Vector2(0.0, 0.0))
	assert_equal(_shell.picked_tile(), 0, "the north-west corner is tile 0")
	_click_map(view.size * 0.5)
	var middle: int = 64 * UiShell.MAP_TILES_X + 64
	assert_equal(_shell.picked_tile(), middle, "the centre of the map is tile (64,64)")


func test_a_click_outside_the_map_picks_nothing_and_says_so() -> void:
	"""A pick that resolves to no tile must refuse rather than silently choosing tile 0."""
	var view: Control = _shell.control_for(UiShell.ID_MINIMAP_VIEW)
	_click_map(Vector2(-4.0, 4.0))
	assert_equal(_shell.picked_tile(), UiShell.NO_TILE, "nothing was picked")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_TILE_RANGE, "and the pick refused")
	_click_map(view.size + Vector2(8.0, 8.0))
	assert_equal(_shell.picked_tile(), UiShell.NO_TILE, "past the far corner picks nothing either")


func test_a_right_click_on_the_map_does_not_pick_a_tile() -> void:
	"""§5.1's right-click table never selects; a right button here must do nothing at all."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = Vector2(4.0, 4.0)
	_shell.control_for(UiShell.ID_MINIMAP_VIEW).emit_signal(&"gui_input", event)
	assert_equal(_shell.picked_tile(), UiShell.NO_TILE, "no tile was picked")


# --- the brush stepper -----------------------------------------------------------------------

func test_the_brush_stepper_cycles_the_documented_widths() -> void:
	"""§5: "1/2/4/8-tile brush widths", cycled by UI-SET-062."""
	assert_equal(_shell.brush_size(), 1, "the brush starts at one tile")
	var stepper: Button = _shell.control_for(UiShell.ID_STEPPER) as Button
	stepper.emit_signal(&"pressed")
	assert_equal(_shell.brush_size(), 2, "then two")
	stepper.emit_signal(&"pressed")
	assert_equal(_shell.brush_size(), 4, "then four")
	stepper.emit_signal(&"pressed")
	assert_equal(_shell.brush_size(), 8, "then eight")
	stepper.emit_signal(&"pressed")
	assert_equal(_shell.brush_size(), 1, "and wraps back to one")


func test_a_brush_stroke_paints_a_block_of_ascending_tiles() -> void:
	"""The stroke stays a legal §8.1 payload however wide the brush is."""
	var stepper: Button = _shell.control_for(UiShell.ID_STEPPER) as Button
	stepper.emit_signal(&"pressed")
	assert_true(_shell.paint_brush_at(0), "a 2x2 block paints")
	assert_equal(_shell.stroke_size(), 4, "four tiles are in the stroke")
	_shell.clear_stroke()
	assert_false(_shell.paint_brush_at(UiShell.MAP_TILES_X - 1),
		"a block that would leave the map refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_TILE_RANGE, "as out of range")
	assert_equal(_shell.stroke_size(), 0, "and paints nothing at all")


# --- hiding a layer changes no truth -----------------------------------------------------------

func test_hiding_the_ecology_layer_changes_no_committed_value() -> void:
	"""04.4: "hiding layers does not change truth"."""
	var residents: ResidentsScript = ResidentsScript.new()
	var jobs: JobsScript = JobsScript.new(residents)
	var presentation: PresentationExtractScript = PresentationExtractScript.new(residents, jobs)
	_shell.bind_presentation(presentation)
	assert_true(presentation.capture(1), "a snapshot is captured")
	var population_before: int = presentation.value_of(
		PresentationExtractScript.FIELD_POPULATION).value
	assert_true(_shell.ecology_layer_visible(), "the ecology layer starts visible")
	(_shell.control_for(UiShell.ID_MAP_LAYERS) as Button).emit_signal(&"pressed")
	assert_false(_shell.ecology_layer_visible(), "the layer is hidden")
	assert_equal(presentation.value_of(PresentationExtractScript.FIELD_POPULATION).value,
		population_before, "and the population field is byte-identical")


func test_the_layer_toggle_refuses_when_no_snapshot_is_bound() -> void:
	"""With no ARCH-SYS-023 snapshot there is no layer to hide, and the shell must say so."""
	(_shell.control_for(UiShell.ID_MAP_LAYERS) as Button).emit_signal(&"pressed")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_LAYERS, "the toggle refuses")
	assert_true((_shell.control_for(UiShell.ID_ERROR_PANEL) as Control).visible,
		"and the refusal is on screen")


# --- keyboard focus shows the description and the outline ---------------------------------------

func test_focusing_a_control_shows_its_description_and_the_gold_outline() -> void:
	"""§2.2: tooltips appear at 0 ms on keyboard focus, and the outline follows the focus."""
	var zone: Button = _shell.control_for(UiShell.ID_ZONE) as Button
	zone.emit_signal(&"focus_entered")
	assert_equal(_shell.focused_element(), UiShell.ID_ZONE, "the shell knows what is focused")
	var tooltip: Control = _shell.control_for(UiShell.ID_TOOLTIP)
	assert_true(tooltip.visible, "the description is shown immediately")
	assert_equal(_shell.tooltip_label().text, zone.tooltip_text,
		"and it is that control's own description")
	var outline: Control = _shell.control_for(UiShell.ID_FOCUS_OUTLINE)
	assert_true(outline.visible, "the focus outline is shown")
	assert_true(outline.size.x > zone.size.x, "and it surrounds the control it follows")


func test_focusing_an_unavailable_control_shows_the_missing_owner() -> void:
	"""§2.2: "Locked controls explain unlock requirements without requiring hover"."""
	var build: Button = _shell.control_for(UiShell.ID_BUILD) as Button
	build.emit_signal(&"focus_entered")
	var reason: String = _shell.tooltip_label().text
	assert_true(reason.begins_with(UNAVAILABLE_WORD), "the reason is shown on focus")
	assert_true(reason.contains("Building"), "and it names the missing store")


# --- decorative regions, read from the built tree, never take a world click ----------------------

func test_the_world_surface_covers_the_viewport_without_consuming_it() -> void:
	"""§4: UI-SET-023 is the full remaining viewport AND "not a fullscreen UI hit block"."""
	var surface: Control = _shell.control_for(UiShell.ID_WORLD_SURFACE)
	assert_almost_equal(surface.size.x, _shell.geometry().logical_width,
		"the overlay spans the logical viewport")
	assert_almost_equal(surface.size.y, _shell.geometry().logical_height, "in both directions")
	assert_true(_shell.hit_test().world_receives(surface.size * 0.5),
		"and a click in the middle of it still reaches the world")


func test_a_visible_decorative_label_does_not_take_the_point_under_it() -> void:
	"""§4: UI-SET-086 is "not clickable; no empty hit rect", even while it is on screen.

	This is the assertion that fails if the shell ever registers its regions as consuming
	wholesale instead of reading each control's own mouse filter.
	"""
	_shell.set_pause_display(true, "PLAYER")
	assert_true(_shell.layout_for(1280, 720), "the layout recomputes with the label shown")
	var label: Control = _shell.control_for(UiShell.ID_PAUSE_LABEL)
	assert_true(label.visible, "the pause label is on screen")
	assert_true(label.size.x > 0.0, "with a real rectangle")
	var inside: Vector2 = label.position + label.size * 0.5
	assert_true(_shell.hit_test().world_receives(inside),
		"and the world still gets the point under it")
	assert_false(_shell.hit_test().element_at(inside).ok, "no element claims that point")


func test_the_ornament_and_the_focus_outline_are_outside_the_hit_table() -> void:
	"""Decoration ignores the mouse, cannot take focus and carries no accessible name."""
	var outline: Control = _shell.control_for(UiShell.ID_FOCUS_OUTLINE)
	assert_equal(outline.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the outline ignores input")
	var detail: Control = _shell.control_for(UiShell.ID_DETAIL)
	var sprig: TextureRect = detail.get_node("Ornament") as TextureRect
	assert_not_null(sprig, "the detail panel carries the sprig ornament")
	assert_equal(sprig.mouse_filter, Control.MOUSE_FILTER_IGNORE, "which ignores input")
	assert_equal(sprig.focus_mode, Control.FOCUS_NONE, "can never take focus")
	assert_equal(sprig.accessibility_name, "", "and is excluded from the accessibility tree")


# --- integration: the routing, the page container and the focus wiring actually run --------------

func test_residents_opens_the_roster_and_never_the_unbuilt_world_access_panel() -> void:
	"""UXV-004. §4.1:182 gives UI-SET-031 as "ALWAYS; opens roster rows 069".

	This shell used to open UI-SET-087 here -- the one element `ui_availability.gd` marks
	PANEL_NOT_BUILT -- so the Residents button opened a panel that does not exist. The
	destination is read from the registry, so a literal cannot drift away from §4.1 again.
	"""
	assert_true(_shell.open_workspace_page(UiRegistry.OPENS[UiShell.ID_RESIDENTS][0]),
		"the registry's destination for 031 is a page this shell builds")
	assert_equal(_shell.workspace_page(), UiRegistry.ROSTER_ID,
		"which is the roster, UI-SET-069")
	assert_true(UiRegistry.ROSTER_ID != UiShell.ID_WORLD_LIST,
		"and the roster is not the world-access list F6 owns")


func test_opening_another_page_hides_the_whole_roster_not_just_its_first_row() -> void:
	"""UI-SET-069's element id is the first ROW's control, so the page needs its own container.

	Without one the page loop toggles row 0 and leaves rows 1-11 standing underneath whichever
	page is open. The roster is populated first because `_set_roster_visible(0)` hides every row
	at build time -- asserting on an empty roster would pass whether or not the container works.
	"""
	_shell.set_roster(PackedStringArray(["Warden Rowan mouse", "Unnamed mole"]), 2)
	assert_true(_shell.open_workspace_page(UiRegistry.ROSTER_ID), "open the roster")
	var row_zero: Control = _shell.control_for(UiShell.ID_RESIDENT_ROW)
	var holder: Control = row_zero.get_parent() as Control
	assert_true(holder != null, "the roster rows live inside a container of their own")
	assert_true(holder.visible, "which is shown while the roster is the open page")
	assert_true(row_zero.visible, "and a populated row is shown inside it")
	assert_true(_shell.open_workspace_page(UiShell.ID_NEW_SETTLEMENT), "switch pages")
	assert_false(holder.visible,
		"the whole roster leaves with the page, so no row survives underneath the new one")


func test_the_focus_order_is_written_onto_the_real_controls() -> void:
	"""UXV-033 names "focus-list data without runtime wiring" as insufficient, and it WAS the state.

	`bind_controls()` and `wire_hud()` had no call site anywhere in the repository, so the
	computed order was a data structure Godot never read. `focus_next` is one of the properties
	Godot's own Tab navigation follows, so a written one is the difference between an order that
	exists and an order a player can feel. Counting them is what makes an unwired shell fail:
	a shell that never calls the router leaves every one of these empty.
	"""
	var wired: int = 0
	for id: int in UiRegistry.FIRST_ID + UiRegistry.ELEMENT_COUNT:
		if id < UiRegistry.FIRST_ID:
			continue
		var control: Control = _shell.control_for(id)
		if control != null and not control.focus_next.is_empty():
			wired += 1
	assert_true(wired > 0,
		"at least one built control carries a focus_next path after layout; zero means nothing "
		+ "called bind_controls()/wire_hud() and the order is data only")


# --- R-UI-ALERT-001: the compact summary, and the full disclosure behind it ----------------------

func test_the_narrow_card_shows_the_authored_summary_and_retains_the_whole_message() -> void:
	"""The ruling's core exchange: a compact authored line, with nothing discarded behind it.

	The message used here is the exact three-line generation refusal from the 2026-09-11 native
	capture -- the one that wrapped over the pause line. It must not appear on the NARROW card,
	and it must still be retrievable byte for byte.
	"""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	_narrow()
	assert_equal(_shell.alert_label().text, "Error: Generation failed",
		"the card draws the authored summary")
	assert_true(_shell.card_is_summarised(), "and reports that it is summarising")
	var notice: UiNotices.Notice = UiNotices.Notice.new()
	assert_true(_shell.card_notice_into(notice), "the card's notice expands")
	assert_equal(notice.message, THREE_LINE_REFUSAL, "with the whole message intact")
	assert_equal(notice.code, LONG_CODE, "and the whole validation code")


func test_the_narrow_card_keeps_the_rectangle_the_ruling_fixes() -> void:
	"""The zone stays 48 high at y=76 and the card stays 44 high, whatever the message is."""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	_narrow()
	var stack: Control = _shell.control_for(UiShell.ID_ALERT_STACK)
	var card: Control = _shell.control_for(UiShell.ID_ALERT_CARD)
	assert_almost_equal(stack.position.y, 76.0, "the zone is still at y=76")
	assert_almost_equal(stack.size.y, 48.0, "and still 48 high")
	assert_almost_equal(card.size.y, 44.0, "the card is still 44 high")
	assert_true(card.position.y + card.size.y <= stack.size.y,
		"and it ends inside the zone rather than over the pause line")


func test_the_narrow_summary_is_one_measured_line_inside_the_card() -> void:
	"""The ruling: "render the title/severity in one measured line" at NOTICE 16 px typography.

	Measured against the font the Label will actually draw with, not against a character count.
	"""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_CLOCK_OVERLOAD,
		"Simulation overloaded at 1x: 3 whole tick(s) owed; paused rather than skipping.",
		"Simulation clock", "CLOCK_OVERLOADED", RECOVERY), "the diagnostic is raised")
	_narrow()
	var label: Label = _shell.alert_label()
	var font: Font = label.get_theme_font(&"font")
	var interior: float = UiLayout.alert_summary_width(_shell.geometry().profile,
		_shell.geometry().alerts.size.x)
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label.get_theme_font_size(&"font_size")).x
	assert_equal(label.get_theme_font_size(&"font_size"), UiTheme.FONT_CRITICAL_MINIMUM,
		"the card draws at the NOTICE 16 px size; nothing shrank the font")
	assert_true(width <= interior,
		"'%s' is %.1f px and must fit the %.1f px interior" % [label.text, width, interior])


func test_the_card_never_ellipsizes_or_crops_what_it_draws() -> void:
	"""Do not "ellipsize, substring, crop or silently discard". The Label wraps; it never clips."""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	var label: Label = _shell.alert_label()
	assert_false(label.clip_text, "the card's text is not clipped")
	assert_equal(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING,
		"and nothing trims it with an ellipsis")
	assert_false(label.text.ends_with("..."), "the drawn line is not an abbreviation")


func test_the_standard_card_still_shows_the_whole_message_when_it_fits() -> void:
	"""Wide and standard "retain their existing layouts when content fits"."""
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!",
		"stores", "STOCK_EMPTY", ""), "the depletion is raised")
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	assert_equal(_shell.geometry().profile, UiLayout.PROFILE_STANDARD, "1280 at 100% is STANDARD")
	assert_equal(_shell.alert_label().text, "Out of ration!", "the message is shown in full")
	assert_false(_shell.card_is_summarised(), "with no summary needed")


func test_the_card_carries_its_severity_icon_and_word() -> void:
	"""§7: "severity word+icon". The icon follows the notice; the word is inside the summary."""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	_narrow()
	var icon: TextureRect = _shell.alert_icon()
	assert_true(icon.texture != null, "the card has a severity icon")
	assert_true(_shell.alert_label().text.begins_with("Error"), "and the severity word beside it")
	assert_equal(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the icon takes no click")
	assert_equal(icon.accessibility_name, "",
		"and stays out of the accessibility tree, which the description already covers")


# --- the accessible description is a full access path, not a tooltip -----------------------------

func test_the_accessible_description_carries_severity_and_the_whole_message() -> void:
	"""A tooltip alone is not a full-message access path; the description must carry it."""
	_narrow()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	var card: Control = _shell.control_for(UiShell.ID_ALERT_CARD)
	assert_true(card.accessibility_name.contains("Error"), "the name states the severity")
	assert_true(card.accessibility_description.contains(THREE_LINE_REFUSAL),
		"the description carries the FULL original message")
	assert_true(card.accessibility_description.contains("Open alert details"),
		"and names the action that discloses the rest")


# --- mouse AND keyboard reach the full content ----------------------------------------------------

func test_enter_on_the_card_opens_the_expanded_view_with_that_notice_selected() -> void:
	"""Keyboard access is half the ruling's guarantee, and Enter is the project's `ui_accept`."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	assert_true(_shell.notice_details_open(), "Enter opened UI-SET-012")
	assert_true(_shell.selected_notice().ok, "with a notice selected")
	assert_true(_expanded_text().contains(THREE_LINE_REFUSAL), "and its full message expanded")


func test_space_on_the_card_opens_the_expanded_view() -> void:
	"""The ruling names Enter/Space. UI §5 puts pause on Space "with world focus", not HUD focus."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_SPACE))
	assert_true(_shell.notice_details_open(), "Space opened UI-SET-012")
	assert_true(_expanded_text().contains(LONG_CODE), "with the validation code disclosed")


func test_a_left_click_on_the_card_opens_the_expanded_view() -> void:
	"""Pointer activation is the other half of "mouse AND keyboard access"."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_click_event(MOUSE_BUTTON_LEFT))
	assert_true(_shell.notice_details_open(), "a left click opened UI-SET-012")
	assert_true(_expanded_text().contains(RECOVERY), "with the recovery action disclosed")


func test_an_unrelated_key_and_a_right_click_do_not_open_the_expanded_view() -> void:
	"""The activation is Enter, Space and the left button, and nothing else."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_A))
	assert_false(_shell.notice_details_open(), "a letter key does not open it")
	_shell.activate_alert_card(_click_event(MOUSE_BUTTON_RIGHT))
	assert_false(_shell.notice_details_open(), "and neither does a right click")


func test_the_expanded_view_wraps_and_scrolls_its_content() -> void:
	"""Full content stays available "with wrapping and vertical scrolling"."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	assert_true(_shell.history_scroll() != null, "the expanded view has a scrolling body")
	assert_equal(_shell.history_scroll().horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED, "which scrolls vertically, not sideways")
	var row: Label = _shell.history_rows()[0]
	assert_false(row.clip_text, "its rows are not clipped")
	assert_equal(row.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "they wrap instead")


func test_closing_the_expanded_view_returns_focus_to_the_card_that_opened_it() -> void:
	"""§2.2: "focus returns to the opening control if still present"."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	assert_true(_shell.close_notice_details(), "the expanded view closes")
	assert_false(_shell.notice_details_open(), "and is hidden")
	var focused: IntMath.IntResult = _shell.focus_order().focused_element()
	assert_true(focused.ok, "something holds focus afterwards")
	assert_equal(focused.value, UiShell.ID_ALERT_CARD, "and it is the card that opened it")


func test_the_expanded_view_is_reachable_from_the_card_by_tab() -> void:
	"""An expanded view a keyboard cannot step into and out of is not keyboard-reachable."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	var panel: Control = _shell.control_for(UiShell.ID_HISTORY)
	assert_equal(panel.focus_mode, Control.FOCUS_ALL, "the expanded view can hold focus")
	assert_false(panel.focus_next.is_empty(), "and carries a forward tab path while open")
	assert_true(_shell.focus_order().focus_step(true), "Tab steps forward out of it")
	var focused: IntMath.IntResult = _shell.focus_order().focused_element()
	assert_equal(focused.value, UiShell.ID_HISTORY_TRIGGER,
		"onto the history trigger, which closes it")


func test_the_history_trigger_closes_the_expanded_view_and_acknowledges_nothing() -> void:
	"""The reachable close control. "Neither acknowledges nor resolves a condition automatically"."""
	_raise_and_focus_card()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	var before: int = _shell.notices().active_count()
	(_shell.control_for(UiShell.ID_HISTORY_TRIGGER) as Button).pressed.emit()
	assert_false(_shell.notice_details_open(), "the trigger closed the expanded view")
	assert_equal(_shell.notices().active_count(), before, "and resolved nothing")
	assert_equal(_shell.notices().count(), 1, "the notice is still retained")


func test_the_history_trigger_opens_the_whole_history_with_nothing_selected() -> void:
	"""§4: the trigger "activates 012" -- the whole history, not one notice's disclosure."""
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "a notice exists")
	(_shell.control_for(UiShell.ID_HISTORY_TRIGGER) as Button).pressed.emit()
	assert_true(_shell.notice_details_open(), "the history opens")
	assert_false(_shell.selected_notice().ok, "with no notice selected")
	assert_true(_expanded_text().contains(THREE_LINE_REFUSAL), "though every message is listed")


func test_opening_the_details_does_not_pause_the_world_or_resolve_the_condition() -> void:
	"""The ruling's acceptance case: "no unexpected pause or acknowledgment"."""
	_raise_and_focus_card()
	var paused_before: bool = GameManager.is_paused()
	_shell.activate_alert_card(_key_event(KEY_ENTER))
	assert_equal(GameManager.is_paused(), paused_before, "the clock is untouched")
	assert_equal(_shell.notices().active_count(), 1, "the condition is still active")
	assert_true(_shell.control_for(UiShell.ID_ALERT_CARD).visible, "and its card is still shown")


func test_twenty_notices_are_retained_and_reachable_from_the_expanded_view() -> void:
	"""The acceptance case for retention, read back off the built rows rather than the store."""
	for index: int in 20:
		assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY,
			"Out of item %d!" % index, "item %d" % index, "STOCK_%d" % index, ""),
			"notice %d is raised" % index)
	assert_equal(_shell.notices().count(), 20, "all twenty are retained")
	(_shell.control_for(UiShell.ID_HISTORY_TRIGGER) as Button).pressed.emit()
	var shown: int = 0
	for row: Label in _shell.history_rows():
		if row.visible:
			shown += 1
	assert_equal(shown, 20, "and all twenty are printed into the expanded view")
	assert_true(_expanded_text().contains("Out of item 19!"), "including the last one")


func test_a_repeated_condition_groups_rather_than_filling_the_history() -> void:
	"""§7's grouping policy, driven through the shell's own entry point."""
	for index: int in 5:
		assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!",
			"ration", "STOCK_EMPTY", ""), "repeat %d is accepted" % index)
	assert_equal(_shell.notices().count(), 1, "five repeats are one condition")


# --- the empty state, and announcements ------------------------------------------------------------

func test_an_empty_alert_zone_shows_the_history_trigger_and_nothing_else() -> void:
	"""The acceptance case: "empty state showing only History".

	Read from the HIT TABLE, not from `Control.visible`. `visible` is a control's own local flag
	and stays true under a hidden parent, so a trigger parented to the hidden alert stack would
	pass a `visible` assertion while being invisible on screen -- a mutation that did exactly
	that survived this test in its first form. `_register_hit_regions()` walks the real parent
	chain, so a control nobody can see registers no rectangle here.
	"""
	_shell.set_alert_display("")
	var stack: Control = _shell.control_for(UiShell.ID_ALERT_STACK)
	var trigger: Control = _shell.control_for(UiShell.ID_HISTORY_TRIGGER)
	assert_false(stack.visible, "the stack is hidden")
	assert_false(_shell.control_for(UiShell.ID_ALERT_CARD).visible, "so is the card")
	assert_true(_shell.hit_test().consumes_point(trigger.position + trigger.size * 0.5),
		"but §4's ALWAYS trigger still takes its own 32x32, so it is on screen")
	assert_true(_shell.hit_test().world_receives(stack.position + stack.size * 0.5),
		"and the rest of the empty zone belongs to the world")


func test_hiding_the_card_retains_the_notice_and_resolves_nothing() -> void:
	"""`hud.gd`'s hold expiry hides the card. It must not silently acknowledge the condition."""
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!",
		"ration", "STOCK_EMPTY", ""), "the depletion is raised")
	_shell.set_alert_display("")
	assert_false(_shell.control_for(UiShell.ID_ALERT_CARD).visible, "the card is hidden")
	assert_equal(_shell.notices().count(), 1, "the notice is retained")
	assert_equal(_shell.notices().active_count(), 1, "and the condition is still active")


func test_a_repeated_state_update_announces_once_and_never_steals_focus() -> void:
	""""State updates must not steal focus or generate repeated announcements without a real
	notice change"."""
	var before: int = _shell.notice_announcements()
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!",
		"ration", "STOCK_EMPTY", ""), "the depletion is raised")
	assert_equal(_shell.notice_announcements(), before + 1, "a new notice announces once")
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "Out of ration!",
		"ration", "STOCK_EMPTY", ""), "the same condition repeats")
	assert_equal(_shell.notice_announcements(), before + 1, "and does not announce again")
	assert_false(_shell.control_for(UiShell.ID_ALERT_CARD).has_focus(),
		"and the card never took focus for itself")


func test_opening_the_details_with_no_notice_is_refused_by_name() -> void:
	"""An expanded view with nothing in it would claim to be showing something."""
	assert_false(_shell.open_notice_details(), "there is no notice to disclose")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_NOTICE, "and the refusal is named")
	assert_false(_shell.notice_details_open(), "so nothing opened")


func test_an_unknown_notice_category_is_refused_rather_than_defaulted() -> void:
	"""A category with no authored summary cannot be shown, so it is not accepted."""
	assert_false(_shell.raise_notice(UiNotices.CATEGORY_COUNT, "text", "", "", ""),
		"an out-of-range category is refused")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NOTICE_CATEGORY, "by name")
	assert_equal(_shell.notices().count(), 0, "and nothing is recorded")


func test_a_notice_the_record_refuses_is_refused_by_the_shell_too() -> void:
	"""A shell that swallowed the store's refusal would report a disclosure it never recorded.

	An empty message is the case the record refuses by name. The shell must pass that refusal
	up rather than return true and leave the card showing whatever was on it before.
	"""
	assert_false(_shell.raise_notice(UiNotices.CATEGORY_STOCK_EMPTY, "", "", "", ""),
		"a notice with no message is refused")
	assert_equal(_shell.last_refusal(), UiNotices.REFUSE_EMPTY_MESSAGE,
		"with the record's own code, not a shell code invented over it")
	assert_equal(_shell.notices().count(), 0, "and nothing is retained")
	assert_false(_shell.control_for(UiShell.ID_ALERT_CARD).visible, "and no card is shown")


func test_the_error_panel_grows_to_its_refusal_and_scrolls_past_its_maximum() -> void:
	"""The exception is for COMPACT HUD notices only. UI-SET-085 still obeys wrap/scroll.

	A fixed 160 px panel drew the generation refusal through its own bottom edge and over the
	command strip -- visible in the native capture that prompted this. §4 gives 085 a
	160..480 band, so the panel grows inside it and the body scrolls beyond it.
	"""
	var short_height: float = _refusal_panel_height("Short refusal.")
	assert_almost_equal(short_height, 160.0, "a short refusal keeps §4's minimum height")
	var long_height: float = _refusal_panel_height(_repeated_refusal(6))
	assert_true(long_height > short_height,
		"a longer refusal gets a taller panel, got %.1f against %.1f" % [long_height, short_height])
	var huge_height: float = _refusal_panel_height(_repeated_refusal(40))
	assert_almost_equal(huge_height, 480.0, "and the growth stops at §4's maximum height")
	assert_true(huge_height > long_height, "which is above the height the shorter one needed")
	var body: ScrollContainer = _shell.control_for(UiShell.ID_ERROR_PANEL).get_node("Body") \
		as ScrollContainer
	assert_true(body != null, "the error body is a scrolling container")
	var panel: Control = _shell.control_for(UiShell.ID_ERROR_PANEL)
	assert_true(body.size.y > 0.0 and body.size.y <= panel.size.y,
		"sized inside the panel that holds it")
	assert_true(body.position.x + body.size.x <= panel.size.x,
		"and inside its width, beside the severity icon")
	var line: Label = body.get_node("Line") as Label
	assert_false(line.clip_text, "its text is not clipped")
	assert_equal(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "it wraps instead")


func _repeated_refusal(times: int) -> String:
	"""A refusal long enough to need more than one panel height, built from the reported one."""
	var parts: PackedStringArray = PackedStringArray()
	for index: int in times:
		parts.append(THREE_LINE_REFUSAL)
	return " ".join(parts)


func _refusal_panel_height(text: String) -> float:
	"""Show one refusal at the standard composition and report UI-SET-085's resulting height."""
	_shell.set_refusal_display(text)
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	return _shell.control_for(UiShell.ID_ERROR_PANEL).size.y


func test_the_expanded_view_replaces_the_error_panel_and_gives_it_back_on_close() -> void:
	"""§3 allows one expansion per zone, and both live in the top-centre column.

	The refusal must not be LOST by that: it is a retained Error notice, the expanded view shows
	its code and reason, the condition stays active, and UI-SET-085 returns when the view closes.
	"""
	_narrow()
	_shell.set_refusal_display(THREE_LINE_REFUSAL)
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	assert_true(_shell.control_for(UiShell.ID_ERROR_PANEL).visible, "the error panel is open")
	assert_true(_shell.open_notice_details(), "the expanded view opens")
	assert_false(_shell.control_for(UiShell.ID_ERROR_PANEL).visible,
		"and takes the column from the error panel")
	assert_true(_expanded_text().contains(LONG_CODE), "while showing the same validation code")
	assert_equal(_shell.notices().active_count(), 1, "the condition is still active")
	assert_true(_shell.close_notice_details(), "the expanded view closes")
	assert_true(_shell.control_for(UiShell.ID_ERROR_PANEL).visible,
		"and the error panel comes back")


func test_the_open_expanded_view_is_drawn_above_the_permanent_hud() -> void:
	"""§3 puts an expansion above the permanent HUD, and the hit table already agreed.

	The DRAW order did not: the minimap frame and the command strip are built after UI-SET-012
	and painted over it in the native capture. Child order is what Godot draws by, so the test
	is on child order -- and the overlays §3 puts above everything stay above it.
	"""
	_raise_and_focus_card()
	assert_true(_shell.open_notice_details(), "the expanded view opens")
	var history: Control = _shell.control_for(UiShell.ID_HISTORY)
	for id: int in [UiShell.ID_MINIMAP_FRAME, UiShell.ID_COMMAND_STRIP, UiShell.ID_RESOURCE_CLUSTER]:
		assert_true(history.get_index() > _shell.control_for(id).get_index(),
			"UI-SET-012 is drawn after UI-SET-%03d" % id)
	for id: int in [UiShell.ID_TOOLTIP, UiShell.ID_FOCUS_OUTLINE]:
		assert_true(_shell.control_for(id).get_index() > history.get_index(),
			"but §3's UI-SET-%03d overlay stays above it" % id)


func test_no_open_expansion_is_drawn_outside_the_viewport_at_narrow() -> void:
	"""UXV-032: content a player cannot see is not shown content.

	At NARROW the logical viewport is 853x480. A taller UI-SET-085 pushed UI-SET-012 off the
	bottom and a 720-wide panel ran off the right edge; both were visible in the native capture.
	Every open top-centre expansion must now lie inside the viewport.
	"""
	_narrow()
	_shell.set_refusal_display(_repeated_refusal(6))
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	assert_true(_shell.open_notice_details(), "the expanded view opens")
	_narrow()
	for id: int in [UiShell.ID_ERROR_PANEL, UiShell.ID_HISTORY, UiShell.ID_ALERT_STACK]:
		var panel: Control = _shell.control_for(id)
		if not panel.visible:
			continue
		assert_true(panel.position.x >= 0.0 and panel.position.y >= 0.0,
			"UI-SET-%03d starts inside the viewport at (%.1f, %.1f)"
			% [id, panel.position.x, panel.position.y])
		assert_true(panel.position.x + panel.size.x <= _shell.geometry().logical_width,
			"UI-SET-%03d ends inside its width" % id)
		assert_true(panel.position.y + panel.size.y <= _shell.geometry().logical_height,
			"UI-SET-%03d ends inside its height" % id)


# --- helpers for the notice tests -------------------------------------------------------------------

func _narrow() -> void:
	"""Lay the shell out at 1280x720 with 150 percent user scale, which is the NARROW profile."""
	assert_true(_shell.apply_user_scale(150), "150 percent is a supported user scale")
	assert_true(_shell.layout_for(1280, 720), "the narrow layout computes")


func _raise_and_focus_card() -> void:
	"""Raise the reported generation refusal and put keyboard focus on its card."""
	assert_true(_shell.raise_notice(UiNotices.CATEGORY_GENERATION_FAILED, THREE_LINE_REFUSAL,
		LONG_SOURCE, LONG_CODE, RECOVERY), "the refusal is raised")
	assert_true(_shell.focus_order().focus_element(UiShell.ID_ALERT_CARD), "the card takes focus")


func _key_event(keycode: Key) -> InputEventKey:
	"""One pressed key event, as the engine would deliver it to the focused card."""
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _click_event(button: MouseButton) -> InputEventMouseButton:
	"""One pressed mouse button event inside the card."""
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _expanded_text() -> String:
	"""Everything the expanded view is currently printing, header and rows together."""
	var parts: PackedStringArray = PackedStringArray([_shell.history_header().text])
	for row: Label in _shell.history_rows():
		if row.visible:
			parts.append(row.text)
	return "\n".join(parts)


# --- ART-UI-01/02: the crafted panel edges are actually applied ---------------------------------

func test_every_framed_container_wears_its_own_silhouette() -> void:
	"""ART-UI-01/02: five containers, five distinct frames, all BUILT rather than declared.

	`ui_frame_builder.gd` was tested by 23 geometry assertions and called by nothing, so the
	frames existed on disk and never on screen. This asserts the holder exists under each
	panel with all eight pieces, which is the property that was false.
	"""
	assert_equal(UiShell.FRAME_OF_ZONE.size(), UiFrameGeometry.frame_count(),
		"every declared silhouette has an owning panel")
	for id: int in UiShell.FRAME_OF_ZONE:
		var panel: Control = _shell.control_for(id)
		assert_true(UiFrameBuilder.has_frame(panel), "UI-SET-%03d carries a frame" % id)
		var holder: Node = panel.get_node(NodePath(UiFrameBuilder.HOLDER_NAME))
		assert_equal(holder.get_child_count(), UiFrameGeometry.PIECE_COUNT,
			"UI-SET-%03d has all eight pieces" % id)


func test_each_panel_wears_the_silhouette_the_table_assigns_it() -> void:
	"""Five containers sharing one rounded outline is the defect ART-UI-01 names."""
	var assigned: Array[int] = []
	for id: int in UiShell.FRAME_OF_ZONE:
		assigned.append(UiShell.FRAME_OF_ZONE[id])
	assigned.sort()
	assert_equal(assigned, [0, 1, 2, 3, 4], "the five frames are assigned once each")
	var journal: Control = _shell.control_for(UiShell.ID_DETAIL)
	var corner: Control = journal.get_node(NodePath("%s/CornerTL"
		% UiFrameBuilder.HOLDER_NAME)) as Control
	assert_equal(corner.size, Vector2(12.0, 16.0),
		"the journal's spine cap is its own 12x16, not an averaged corner")


func test_every_frame_piece_lies_inside_its_own_panel() -> void:
	"""ART-UI-07: the first two attempts put the right and bottom corners OUTSIDE the panel."""
	for id: int in UiShell.FRAME_OF_ZONE:
		var panel: Control = _shell.control_for(id)
		var holder: Node = panel.get_node(NodePath(UiFrameBuilder.HOLDER_NAME))
		for index: int in holder.get_child_count():
			var piece: Control = holder.get_child(index) as Control
			assert_true(piece.position.x >= -0.01 and piece.position.y >= -0.01,
				"UI-SET-%03d %s starts inside the panel at %v" % [id, piece.name, piece.position])
			assert_true(piece.position.x + piece.size.x <= panel.size.x + 0.01
				and piece.position.y + piece.size.y <= panel.size.y + 0.01,
				"UI-SET-%03d %s ends inside %v" % [id, piece.name, panel.size])


func test_frame_art_never_takes_a_click_a_focus_stop_or_an_announcement() -> void:
	"""ART-UI-07/08: ornament may never steal input or be announced as a control."""
	for id: int in UiShell.FRAME_OF_ZONE:
		var holder: Control = _shell.control_for(id).get_node(
			NodePath(UiFrameBuilder.HOLDER_NAME)) as Control
		assert_equal(holder.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"UI-SET-%03d's frame ignores the mouse" % id)
		assert_equal(holder.focus_mode, Control.FOCUS_NONE, "and takes no focus")
		assert_equal(holder.accessibility_name, "", "and is not announced")


func test_frame_art_is_drawn_beneath_the_panels_own_controls() -> void:
	"""A 22 px dock corner over a control at the 12 px inset would violate ART-UI-07."""
	for id: int in UiShell.FRAME_OF_ZONE:
		var panel: Control = _shell.control_for(id)
		var holder: Node = panel.get_node(NodePath(UiFrameBuilder.HOLDER_NAME))
		assert_equal(holder.get_index(), 0,
			"UI-SET-%03d draws its frame first, under everything else" % id)


func test_relaying_out_moves_the_frame_with_its_panel() -> void:
	"""`Control.resized` never fires off-tree, so the shell must refresh the frames itself."""
	assert_true(_shell.layout_for(1920, 1080), "the wide layout computes")
	for id: int in UiShell.FRAME_OF_ZONE:
		var panel: Control = _shell.control_for(id)
		var corner: Control = panel.get_node(NodePath("%s/CornerBR"
			% UiFrameBuilder.HOLDER_NAME)) as Control
		assert_almost_equal(corner.position.x + corner.size.x, panel.size.x,
			"UI-SET-%03d's bottom-right corner tracks the new width" % id)
		assert_almost_equal(corner.position.y + corner.size.y, panel.size.y,
			"and its new height")


# --- UXV-020: five need rows, a percent, a track and a rate --------------------------------------

func test_the_detail_panel_builds_five_independent_need_rows() -> void:
	"""UXV-020: "Render five independent need rows". One combined string is not five rows."""
	assert_not_null(_shell.need_row(0), "the first UI-SET-039 instance is built")
	assert_not_null(_shell.need_row(4), "and so is the fifth")
	assert_null(_shell.need_row(5), "and there is no sixth")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_UNKNOWN_ELEMENT,
		"which refuses by name rather than returning a spare row")


func test_a_need_row_is_the_amendments_52_pixel_height() -> void:
	"""§4.1: "52 px need rows when displaying hourly rates", inside §4's own 44..56 band."""
	var size: UiRegistry.Size = UiRegistry.Size.new()
	assert_true(_shell.registry().size_into(UiShell.ID_NEED_ROW, size), "§4 sizes the row")
	assert_equal(_shell.need_row(0).custom_minimum_size.y, 52.0, "the row is 52 px tall")
	assert_true(52.0 >= float(size.min_height) and 52.0 <= float(size.max_height),
		"which is inside §4's %d..%d band" % [size.min_height, size.max_height])


func test_the_track_fill_is_the_rows_own_value_and_nothing_else() -> void:
	"""UXV-020's 8 px track must be the same number as the printed percent, not a second one."""
	assert_true(_shell.set_need_row(0, "Fullness", "75%", "-2.50 pp/h", 7500, "detail"),
		"a row at 7500 basis points is accepted")
	var full: float = _shell.need_track_fill(0).size.x
	assert_true(_shell.set_need_row(0, "Fullness", "100%", "-2.50 pp/h", 10000, "detail"),
		"and the same row at the ceiling")
	var whole: float = _shell.need_track_fill(0).size.x
	assert_almost_equal(full / whole, 0.75, "the 7500 track is exactly three quarters")
	assert_true(_shell.set_need_row(0, "Fullness", "0%", "-2.50 pp/h", 0, "detail"),
		"and at the floor")
	assert_equal(_shell.need_track_fill(0).size.x, 0.0, "an empty need draws no fill")


func test_the_track_is_eight_pixels_and_sits_inside_its_row() -> void:
	"""UXV-020 fixes the track at 8 px; it must not overflow the 52 px row."""
	assert_true(_shell.set_need_row(0, "Rest", "50%", "Rate unavailable", 5000, "detail"),
		"the row is filled")
	var edge: ColorRect = _shell.need_row(0).get_node("TrackEdge") as ColorRect
	assert_equal(edge.size.y, 8.0, "the track is 8 px tall")
	assert_almost_equal(edge.position.y + edge.size.y, 52.0, "and ends at the row's own bottom")


func test_a_need_value_outside_the_scale_refuses_rather_than_overdrawing() -> void:
	"""A bar longer than its own track would be a drawn lie about a clamped store."""
	assert_false(_shell.set_need_row(0, "Fullness", "101%", "-2.50 pp/h", 10001, "detail"),
		"a value above the scale refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NEED_OUT_OF_RANGE, "by name")
	assert_false(_shell.set_need_row(0, "Fullness", "-1%", "-2.50 pp/h", -1, "detail"),
		"and so does one below it")


func test_selecting_something_without_needs_empties_the_need_rows() -> void:
	"""A tile must never be shown under the previous resident's percentages."""
	assert_true(_shell.set_need_row(0, "Fullness", "75%", "-2.50 pp/h", 7500, "detail"),
		"a resident row is drawn")
	assert_equal(_shell.need_rows_shown(), 1, "and is visible")
	_shell.set_detail_display("Tile 4,9 - forest", "Basin: Mossflower", "Danger band 1")
	assert_equal(_shell.need_rows_shown(), 0, "selecting a tile hides every need row")
	assert_equal(_shell.need_row_text(0).strip_edges(), "", "and leaves none of its text")


func test_the_need_row_track_never_takes_input_or_an_announcement() -> void:
	"""The track duplicates the percent beside it, so it is decoration in both trees."""
	for part: String in ["TrackEdge", "TrackWell", "TrackFill", "Name", "Value", "Rate"]:
		var control: Control = _shell.need_row(0).get_node(NodePath(part)) as Control
		assert_equal(control.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s ignores the mouse" % part)
		assert_equal(control.accessibility_name, "", "and is not announced separately")


# --- ART-UI-06/09: the species medallion ---------------------------------------------------------

func test_the_species_medallion_loads_and_is_shown_beside_the_name() -> void:
	"""ART-UI-06: four illustrated medallions existed in the repository and nothing loaded one."""
	var path: String = UiResidentCard.emblem_path(&"mouse", _shell.detail_emblem_pixels())
	assert_true(_shell.set_detail_emblem(path, "Generic mouse species emblem"),
		"the mouse medallion is applied from %s" % path)
	assert_not_null(_shell.detail_emblem().texture, "a real texture is loaded")
	assert_true(_shell.detail_emblem().visible, "and it is shown")


func test_the_medallion_leads_the_card_and_never_draws_over_the_name() -> void:
	"""ART-UI-09: identity first, and the roundel must not overlap the name it identifies."""
	assert_true(_shell.set_detail_emblem(
		UiResidentCard.emblem_path(&"otter", _shell.detail_emblem_pixels()), "otter"),
		"the otter medallion is applied")
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	var emblem: Control = _shell.detail_emblem()
	var title: Control = _shell.control_for(UiShell.ID_DETAIL_TITLE)
	assert_false(Rect2(emblem.position, emblem.size).intersects(
		Rect2(title.position, title.size)), "the roundel and the heading do not overlap")
	assert_true(emblem.position.y <= title.position.y + 0.01,
		"and the roundel leads the card rather than following the name")
	assert_almost_equal(emblem.size.x, float(_shell.detail_emblem_pixels()),
		"and is drawn at a production size")


func test_the_medallion_is_a_production_size_at_every_reachable_profile() -> void:
	"""ART-LOCK-001: "Actual production sizes are 48/64px"; 24 px is a diagnostic only.

	The three profiles are reached the way the native evidence reaches them: two window sizes
	and the 150% user scale, because §1.2's own floor refuses a viewport below 1280x720.
	"""
	for scale: int in [UiLayout.USER_SCALE_100, UiLayout.USER_SCALE_150]:
		assert_true(_shell.apply_user_scale(scale), "the %d%% scale applies" % scale)
		for width: int in [1920, 1280]:
			assert_true(_shell.layout_for(width, 720), "the %d layout computes" % width)
			assert_true([48, 64].has(_shell.detail_emblem_pixels()),
				"%d at %d%% draws the roundel at %d px"
				% [width, scale, _shell.detail_emblem_pixels()])
	assert_true(_shell.apply_user_scale(UiLayout.USER_SCALE_100), "the scale is restored")


func test_a_species_with_no_medallion_leaves_the_roundel_hidden() -> void:
	"""The lock forbids reusing the mouse emblem, so an absent one shows nothing at all."""
	assert_false(_shell.set_detail_emblem("", "no emblem"), "an empty source refuses")
	assert_equal(_shell.last_refusal(), UiShell.REFUSE_NO_EMBLEM, "by name")
	assert_false(_shell.detail_emblem().visible, "and the roundel stays hidden")
	assert_null(_shell.detail_emblem().texture, "carrying no borrowed texture")


func test_the_medallion_is_decorative_in_the_accessibility_tree() -> void:
	"""ART-UI-07/08: the species is already in the identity line; announcing it twice is noise."""
	assert_true(_shell.set_detail_emblem(
		UiResidentCard.emblem_path(&"mole", 48), "Generic mole species emblem"),
		"the mole medallion is applied")
	assert_equal(_shell.detail_emblem().accessibility_name, "", "the roundel is not a control")
	assert_true(_shell.control_for(UiShell.ID_DETAIL).accessibility_description.contains(
		"Generic mole"), "and the panel says what the mark is")


# --- 4.1's scrolling journal body -----------------------------------------------------------------

func test_the_journal_body_scrolls_so_five_need_rows_are_reachable() -> void:
	"""§4.1: "Long content scrolls inside the panel, not past the window"."""
	assert_not_null(_shell.detail_scroll(), "UI-SET-036 has a scrolling body")
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	var panel: Control = _shell.control_for(UiShell.ID_DETAIL)
	var body: Control = _shell.detail_scroll()
	assert_true(body.position.y + body.size.y <= panel.size.y + 0.01,
		"the body ends inside the panel")
	assert_true(body.size.y > 0.0, "and has room to scroll in")


func test_the_heading_and_the_close_control_never_scroll_away() -> void:
	"""§4.1: "Keep the header/close ... visible; the content body scrolls"."""
	var title: Control = _shell.control_for(UiShell.ID_DETAIL_TITLE)
	var close: Control = _shell.control_for(UiShell.ID_CLOSE)
	assert_equal(title.get_parent(), _shell.control_for(UiShell.ID_DETAIL),
		"the heading is a direct child of the panel, not of the scroll")
	assert_equal(close.get_parent(), _shell.control_for(UiShell.ID_DETAIL),
		"and so is the close control")


func test_a_long_name_grows_the_header_instead_of_overlaying_close() -> void:
	"""§4.1: "Header grows to wrap long names; never reduce name size or overlay Close"."""
	var title: Control = _shell.control_for(UiShell.ID_DETAIL_TITLE)
	var close: Control = _shell.control_for(UiShell.ID_CLOSE)
	_shell.set_detail_display("Rowan", "mouse", "")
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	var short_height: float = title.size.y
	var short_font: int = title.get_theme_font_size(&"font_size")
	_shell.set_detail_display(
		"Sister Amabel of the Eastern Orchard and the Long Rampart Watch", "mouse", "")
	assert_true(_shell.layout_for(1280, 720), "the layout recomputes around the long name")
	assert_true(title.size.y > short_height, "the header grew to hold the wrapped name")
	assert_equal(title.get_theme_font_size(&"font_size"), short_font,
		"and the name was not shrunk to make it fit")
	assert_false(Rect2(title.position, title.size).intersects(
		Rect2(close.position, close.size)), "and it never overlays Close")


func test_the_detail_ornament_never_sits_over_the_medallion_or_the_body() -> void:
	"""ART-UI-07: "decoration shall not overlap text/controls"."""
	assert_true(_shell.layout_for(1280, 720), "the standard layout computes")
	var sprig: Control = _shell.control_for(UiShell.ID_DETAIL).get_node("Ornament") as Control
	var body: Control = _shell.detail_scroll()
	assert_true(sprig.position.y >= body.position.y + body.size.y - 0.01,
		"the sprig sits below the scrolling body, not across it")
	assert_true(sprig.position.y > _shell.detail_emblem().position.y
		+ _shell.detail_emblem().size.y, "and nowhere near the medallion")


func test_the_zone_harvesting_policy_never_stands_on_a_resident() -> void:
	"""UXV-023: "zone harvesting policies never appear on a resident merely because a template
	exists". The journal carried `Harvesting enabled` under every resident's needs, where the
	action could only ever refuse with UI_SHELL_NOTHING_SELECTED."""
	var policy: Control = _shell.control_for(UiShell.ID_WORK_POLICY)
	assert_false(policy.visible, "nothing is selected, so no policy is offered")
	var bound: Dictionary = _bound_settlement()
	_shell.select_zone(bound["basin"], true)
	assert_true(policy.visible, "selecting a real zone offers its policy")
	_shell.set_detail_display("Rowan", "mouse - Warden - Active", "")
	assert_false(policy.visible, "and selecting a resident takes it away again")
