extends "res://test/framework/test_case.gd"
## The Demo party panel's compact form and its sheet (decision 1891; decision 1871 P-B8, Brendan's ruling "Compact
## panel, next"): which form a column takes, which rows the compact frame keeps, the Open action's words, the inspector
## moving to the sheet and back, the sheet's placement beside the column, and folding on a press away.
##
## Built out of the tree (the runner's worker has no root in the tree yet), so the choices are checked through their
## pure functions and the nodes' parents and visibility; the live harnesses (demo_layout_live.gd, demo_input_live.gd)
## check the real layout, the real clicks and the input gate.

const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const SheetScript := preload("res://demo/control/party_sheet.gd")
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free what a test built; the interface scale back to 100 %."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	DemoUiScale.percent = UiLayout.USER_SCALE_100


func _panel(count: int) -> PanelScript:
	"""A built party panel showing `count` residents."""
	var panel := PanelScript.new()
	_nodes.append(panel)
	panel.build()
	var entries: Array[Dictionary] = []
	for i: int in count:
		entries.append({"index": i, "name": "Resident %d" % i, "species": "Mouse", "state": "holding"})
	panel.show_party(entries)
	return panel


func _press(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	"""A mouse button event."""
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


# --- which form ------------------------------------------------------------------------------------------

func test_the_full_form_needs_min_inspector_h_or_all_its_content() -> void:
	"""full_fits: MIN_INSPECTOR_H of inspector, or as much as its content needs, keeps the full form."""
	var least: float = PanelScript.MIN_INSPECTOR_H
	assert_true(PanelScript.full_fits(least, 500.0), "exactly MIN_INSPECTOR_H")
	assert_false(PanelScript.full_fits(least - 0.5, 500.0), "just under it, with more content")
	assert_true(PanelScript.full_fits(40.0, 40.0), "room for all the content, however little")
	assert_false(PanelScript.full_fits(39.5, 40.0), "just short of the content")
	assert_false(PanelScript.full_fits(-10.0, 0.5), "less than nothing")


func test_the_compact_frame_drops_the_title_then_the_summary() -> void:
	"""compact_rows: the actions always; the summary above them where it fits; the title above that where it fits too
	(1280x720: all three in 140 px; 125 %: the actions alone in 80)."""
	var actions: float = 76.0
	var line: float = 22.0
	var header: float = 28.0
	var sep: float = PanelScript.SEPARATION
	var all: float = actions + line + header + 2.0 * sep
	assert_equal(PanelScript.compact_rows(all, actions, line, header), PanelScript.ROWS_ALL, "everything fits")
	assert_equal(PanelScript.compact_rows(all - 0.5, actions, line, header), PanelScript.ROWS_SUMMARY, "the title goes first")
	assert_equal(PanelScript.compact_rows(actions + sep + line, actions, line, header), PanelScript.ROWS_SUMMARY,
		"the summary while it fits")
	assert_equal(PanelScript.compact_rows(actions + sep + line - 0.5, actions, line, header), PanelScript.ROWS_ACTIONS,
		"then the summary")
	assert_equal(PanelScript.compact_rows(80.0, actions, line, header), PanelScript.ROWS_ACTIONS, "125 % at 1280x720")
	assert_equal(PanelScript.compact_rows(140.0, actions, line, header), PanelScript.ROWS_ALL, "100 % at 1280x720")


func test_open_carries_the_count() -> void:
	"""The Open action's words: "Open · 6 selected", plain "Open" for nobody."""
	assert_equal(PanelScript.open_caption(6), "Open · 6 selected", "the count rides on it")
	assert_equal(PanelScript.open_caption(1), "Open · 1 selected", "one")
	assert_equal(PanelScript.open_caption(0), "Open", "nobody")
	var panel := _panel(6)
	assert_equal(panel.open_button().text, "Open · 6 selected", "shown on the button")
	assert_equal(panel.open_button().tooltip_text, PanelScript.OPEN_TIP, "with what it does")
	assert_true(panel.open_button().custom_minimum_size.y >= 32.0, "a 32 px target")
	assert_equal(panel.open_button().focus_mode, Control.FOCUS_ALL, "an F7/Tab stop")


# --- the two forms ------------------------------------------------------------------------------------------

func test_the_compact_form_moves_the_inspector_to_the_sheet_and_back() -> void:
	"""No room: the compact form -- the thin carving, Open shown with the count, the header's count hidden, the
	inspector in the sheet's slot. Room again: the full form, everything back, the sheet folded."""
	var panel := _panel(6)
	var frame: PanelContainer = panel.get("_frame")
	assert_true(panel.fit(4000.0), "a tall column: full")
	assert_false(panel.open_button().visible, "no Open in the full form")
	assert_equal(panel.count_control(), panel.get("_count"), "the count in the header")
	assert_false(panel.fit(1.0), "a short one: compact")
	assert_true(panel.compact(), "compact")
	assert_equal(panel.inspector().get_parent(), panel.sheet().slot(), "the inspector in the sheet")
	assert_true(panel.open_button().visible, "Open shown")
	assert_false((panel.get("_count") as Label).visible, "the header's count hidden")
	assert_equal(panel.count_control(), panel.open_button(), "the count on Open")
	assert_equal(frame.get_theme_stylebox(&"panel"), panel.get("_compact_box"), "the thin carving")
	assert_true(panel.release_button().visible and panel.follow_button().visible, "Release and Follow in the frame")
	assert_true(panel.get("_column").is_ancestor_of(panel.release_button()), "the actions stay in the column")
	var stops: Array[Control] = GateScript.focusables([panel] as Array[Node])
	assert_true(stops.has(panel.open_button()), "Open a stop of the left column")
	assert_false(stops.has(panel.sheet().close_button()), "the folded sheet's Close is not")
	panel.open_sheet()
	assert_true(panel.fit(4000.0), "room again: full")
	assert_false(panel.sheet().is_open(), "the sheet folds")
	assert_equal(panel.inspector().get_parent(), panel.get("_column"), "the inspector back in the column")
	assert_equal(panel.inspector().get_index(), panel.get("_column").get_child_count() - 1, "last, under the actions")
	assert_equal(frame.get_theme_stylebox(&"panel"), panel.get("_full_box"), "the carved frame again")
	assert_false(panel.open_button().visible, "no Open in the full form again")
	assert_true((panel.get("_count") as Label).visible, "the header's count again")
	assert_true((panel.get("_header") as Control).visible and (panel.get("_summary_line") as Control).visible,
		"the title and the summary back")


func test_only_the_compact_form_opens_the_sheet() -> void:
	"""open_sheet does nothing in the full form; in the compact form Open opens it and fold_sheet folds it; its
	inspector starts from the top."""
	var panel := _panel(6)
	panel.fit(4000.0)
	panel.open_sheet()
	assert_false(panel.sheet().is_open(), "full form: nothing to open")
	panel.fit(1.0)
	panel.inspector().scroll_vertical = 40
	panel.open_button().pressed.emit()
	assert_true(panel.sheet().is_open(), "Open opens it")
	assert_equal(panel.inspector().scroll_vertical, 0, "from the top")
	panel.fold_sheet()
	assert_false(panel.sheet().is_open(), "folded")


func test_the_sheet_says_the_count_and_the_whole_summary() -> void:
	"""The sheet's head counts the party, and its summary is the panel's, on up to SUMMARY_LINES lines, whole in its
	tooltip."""
	var panel := _panel(6)
	assert_equal(panel.sheet().count_text(), "6 selected", "the count")
	assert_equal(panel.sheet().summary_label().text, panel.summary(), "the summary")
	assert_equal(panel.sheet().summary_label().tooltip_text, panel.summary(), "whole in its tooltip")
	assert_equal(panel.sheet().summary_label().autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "wrapped")
	assert_equal(panel.sheet().summary_label().max_lines_visible, SheetScript.SUMMARY_LINES, "on two lines at most")
	panel.show_party([] as Array[Dictionary])
	assert_equal(panel.sheet().count_text(), "", "nobody: no count")
	assert_equal(panel.open_button().text, "Open", "and plain Open")


func test_the_actions_show_with_open_alone() -> void:
	"""Nobody selected and no other owner's row: the full form hides the actions; the compact form shows them for
	Open."""
	var panel := _panel(0)
	panel.fit(4000.0)
	assert_false((panel.get("_actions") as Control).visible, "full: nothing to act on")
	panel.fit(1.0)
	assert_true((panel.get("_actions") as Control).visible, "compact: Open")


# --- the sheet --------------------------------------------------------------------------------------------

func _sheet() -> SheetScript:
	"""A built, folded sheet."""
	var sheet := SheetScript.new()
	_nodes.append(sheet)
	sheet.build(PanelScript.inner_width())
	return sheet


func test_the_sheet_is_built_folded_on_its_layer() -> void:
	"""Folded: the layer, the catcher and the frame hidden (no focus stop for F7 and Tab); open: all shown, above the
	HUD's layer; Close folds it."""
	var sheet := _sheet()
	assert_equal(sheet.layer, SheetScript.LAYER, "the modals' layer")
	assert_true(sheet.layer > 1, "above the HUD's")
	assert_false(sheet.is_open(), "built folded")
	assert_false(sheet.frame().visible or sheet.catcher().visible, "frame and catcher hidden")
	assert_true(GateScript.focusables([sheet] as Array[Node]).is_empty(), "no stop while folded")
	sheet.open()
	assert_true(sheet.frame().visible and sheet.catcher().visible, "shown")
	assert_true(GateScript.focusables([sheet] as Array[Node]).has(sheet.close_button()), "Close a stop when open")
	sheet.close_button().pressed.emit()
	assert_false(sheet.is_open(), "Close folds it")
	assert_equal(sheet.close_button().text, "×", "the demo panels' close mark")
	assert_true(sheet.close_button().tooltip_text.begins_with("Close (Esc)"), "its key in its tooltip")
	assert_true(sheet.close_button().custom_minimum_size.y >= 32.0, "a 32 px target")


func test_a_press_away_folds_the_sheet() -> void:
	"""The catcher: a left, right or middle press folds the sheet; a release or the wheel does not."""
	var sheet := _sheet()
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		sheet.open()
		sheet.catcher().gui_input.emit(_press(button))
		assert_false(sheet.is_open(), "a press of %d folds it" % button)
	sheet.open()
	sheet.catcher().gui_input.emit(_press(MOUSE_BUTTON_LEFT, false))
	assert_true(sheet.is_open(), "a release does not")
	sheet.catcher().gui_input.emit(_press(MOUSE_BUTTON_WHEEL_DOWN))
	assert_true(sheet.is_open(), "the wheel does not")
	sheet.catcher().gui_input.emit(InputEventMouseMotion.new())
	assert_true(sheet.is_open(), "a move does not")
	assert_equal(sheet.catcher().mouse_filter, Control.MOUSE_FILTER_STOP, "and none reaches the world")
	assert_true(sheet.catcher().get_index() < sheet.frame().get_index(), "under the frame")


func test_the_sheet_stands_beside_the_column_down_to_the_level_bar_s_foot() -> void:
	"""At every size: GAP right of the column's carved frame, the column's content width, from the management top to
	the level bar's foot (UI-BUILD-013); clear of the resources, time, alerts, minimap, right column, commands and the
	level bar; on screen; and taller than five member rows where the compact form is used."""
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3456, 2160)]:
		var geometry := UiLayout.Geometry.new()
		var column: Rect2 = PanelScript.placement(size.x, size.y, UiLayout.new(), geometry).grow(PanelScript.FRAME_EXPAND)
		var rect: Rect2 = SheetScript.placement(geometry, PanelScript.column_right(), PanelScript.inner_width())
		var bar: Rect2 = BuildLayout.level_bar_rect(geometry, true)
		assert_almost_equal(rect.position.x, column.end.x + SheetScript.GAP, "%s: beside the column" % size)
		assert_almost_equal(rect.size.x, PanelScript.inner_width() + 24.0, "%s: the column's content width" % size)
		assert_almost_equal(rect.position.y, geometry.management_top, "%s: the column's top" % size)
		assert_almost_equal(rect.end.y, bar.end.y, "%s: the level bar's foot" % size)
		_assert_clear(rect, geometry, bar, column, size)


func _assert_clear(rect: Rect2, geometry: UiLayout.Geometry, bar: Rect2, column: Rect2, size: Vector2i) -> void:
	"""`rect` misses the HUD's zones, the level bar and the column, and is on screen."""
	var zones: Array[Rect2] = [geometry.resources, geometry.time, geometry.alerts, geometry.minimap, geometry.detail,
		geometry.commands, bar, column]
	var hits: int = 0
	for zone: Rect2 in zones:
		hits += 1 if rect.intersects(zone) else 0
	assert_equal(hits, 0, "%s: clear of the HUD's zones, the level bar and the column" % size)
	assert_true(Rect2(0, 0, geometry.logical_width, geometry.logical_height).encloses(rect), "%s: on screen" % size)
	assert_true(rect.size.y >= 5.0 * 33.0, "%s: room for rows (%.0f px)" % [size, rect.size.y])


func test_at_125_percent_on_1280x720_the_sheet_keeps_clear_of_the_right_column() -> void:
	"""The narrow profile (1024x576 logical): the sheet ends GAP short of the right column, and the column's carved
	extent still holds two rows of actions with the compact margins."""
	DemoUiScale.percent = UiLayout.USER_SCALE_125
	var geometry := UiLayout.Geometry.new()
	var column: Rect2 = PanelScript.placement(1280, 720, UiLayout.new(), geometry).grow(PanelScript.FRAME_EXPAND)
	var rect: Rect2 = SheetScript.placement(geometry, PanelScript.column_right(), PanelScript.inner_width())
	assert_equal(geometry.profile, UiLayout.PROFILE_NARROW, "narrow")
	assert_true(rect.end.x <= geometry.detail.position.x - SheetScript.GAP, "%s vs %s" % [rect, geometry.detail])
	_assert_clear(rect, geometry, BuildLayout.level_bar_rect(geometry, true), column, Vector2i(1280, 720))
	var inner: float = column.size.y - PanelScript.COMPACT_MARGINS[1] - PanelScript.COMPACT_MARGINS[3]
	assert_true(inner >= 2.0 * 35.0 + PanelScript.SEPARATION, "two rows of actions (%.0f px)" % inner)


func test_the_slot_gets_what_the_head_leaves() -> void:
	"""slot_room: the sheet's height less its margins, head, summary and gaps; never below nothing."""
	var sheet := _sheet()
	sheet.show_words("6 selected", "Holding ×6")
	var head: float = (sheet.get("_head") as Control).get_combined_minimum_size().y
	var line: float = sheet.summary_label().get_combined_minimum_size().y
	var used: float = SheetScript.MARGINS[1] + SheetScript.MARGINS[3] + head + line + 2.0 * SheetScript.SEPARATION
	assert_almost_equal(sheet.slot_room(300.0), 300.0 - used, "the rest")
	assert_almost_equal(sheet.slot_room(1.0), 0.0, "never below nothing")


func test_the_compact_frame_shows_the_rows_its_height_holds() -> void:
	"""_fit_compact on a frame `h` tall (less its COMPACT_MARGINS): the title and the summary where both fit, the summary
	alone just short of that, the actions alone just short of the summary -- measured on the panel's own rows."""
	var panel := _panel(6)
	panel.fit(1.0)
	var actions: float = (panel.get("_actions") as Control).get_combined_minimum_size().y
	var line: float = (panel.get("_summary_line") as Control).get_combined_minimum_size().y
	var header: float = (panel.get("_header") as Control).get_combined_minimum_size().y
	var margins: float = PanelScript.COMPACT_MARGINS[1] + PanelScript.COMPACT_MARGINS[3]
	var sep: float = PanelScript.SEPARATION
	var title_line: Control = panel.get("_header")
	var summary_line: Control = panel.get("_summary_line")
	panel.call(&"_fit_compact", margins + actions + line + header + 2.0 * sep)
	assert_true(title_line.visible and summary_line.visible, "both fit")
	panel.call(&"_fit_compact", margins + actions + line + header + 2.0 * sep - 0.5)
	assert_true(summary_line.visible and not title_line.visible, "the title goes first")
	panel.call(&"_fit_compact", margins + actions + line + sep - 0.5)
	assert_false(summary_line.visible or title_line.visible, "then the summary")
	panel.call(&"_fit_compact", margins + actions + line + sep)
	assert_true(summary_line.visible and not title_line.visible, "the summary back")


func test_fixed_height_is_the_full_form_s_fixed_part() -> void:
	"""fixed_height: the carved frame's margins, the header, the summary line, the actions and the gaps (the least the
	panel needs below an open ledger)."""
	var panel := _panel(6)
	var box: StyleBox = panel.get("_full_box")
	var actions: float = (panel.get("_actions") as Control).get_combined_minimum_size().y
	var expected: float = box.get_minimum_size().y + (panel.get("_header") as Control).get_combined_minimum_size().y \
		+ (panel.get("_summary_line") as Control).get_combined_minimum_size().y \
		+ (actions + PanelScript.SEPARATION if actions > 0.0 else 0.0) + PanelScript.SEPARATION
	assert_almost_equal(panel.fixed_height(), expected, "the fixed part")
	assert_almost_equal(panel.full_room(500.0), 500.0 - expected - PanelScript.SEPARATION, "the rest of the column")
