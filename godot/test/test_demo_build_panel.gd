extends "res://test/framework/test_case.gd"
## The build panel and level bar mounted in the demo (demo/build_panel/demo_build.gd; decision 1871), off-tree over a real
## command layer and Dig tool: B, the level keys and their ends, the level mapping (levels 3-4 with no way in, Overview
## never painting), the keyboard's paint, Undo / Redo, the legacy cards and the panel's return, Escape, the hidden HUD,
## UX-BUILD-T04 (no silent cost) and UX-BUILD-T05 (selection identity across levels), and a still frame allocating
## nothing.

const BuildScript := preload("res://demo/build_panel/demo_build.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Orders := preload("res://demo/build_panel/demo_build_orders.gd")
const UiShellScript := preload("res://scripts/ui/ui_shell.gd")

const KITCHEN_CARD: int = 2

var _nodes: Array[Node] = []
var _build: BuildScript = null
var _command: CommandScript = null
var _said: PackedStringArray = PackedStringArray()
var _blocked: bool = false
var _hidden: CanvasLayer = null


func tolerates_outside_tree() -> bool:
	"""The command layer's marks read their transforms off-tree here."""
	return true


func before_each() -> void:
	"""A placeholder cast with a mole, its command layer and Dig tool, and the build panel over them."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	_command = CommandScript.new()
	_nodes.append(_command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	_command.configure(cast, camera, null)
	_hidden = CanvasLayer.new()
	_nodes.append(_hidden)
	_said.clear()
	_blocked = false
	_build = BuildScript.new()
	_nodes.append(_build)
	_build.configure(_command.tunnels(), null, camera, func() -> bool: return _blocked,
		func(text: String) -> void: _said.append(text), [_hidden] as Array[Node], null)
	_command.set_build_hooks(_build.takes_before_gui, _build.handle_input)


func after_each() -> void:
	"""Free every node (the lambdas hold this suite)."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_build = null
	_command = null


static func _key(code: Key, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	"""A key press."""
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	return event


func _press(code: Key, ctrl: bool = false, shift: bool = false) -> bool:
	"""A key through the command layer the way the village routes it: before the HUD, then the world."""
	var event := _key(code, ctrl, shift)
	return _command.take_before_gui(event) or _command.handle_input(event)


func _card(card_name: String) -> int:
	"""The index of the card named `card_name` in the panel's row now (-1: none)."""
	var cards: Array[BuildCatalog.Card] = _build.panel.row_cards()
	for k: int in cards.size():
		if cards[k].name == card_name:
			return k
	return -1


func _paint_kitchen_by_keys() -> void:
	"""Level 1, the Kitchen card, Enter, five rights and three downs, Enter: a 6 × 4 Kitchen."""
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_build.panel.choose_card(KITCHEN_CARD)
	_build.paint.set_cursor(Vector2i(2, 2), 1, 2)
	assert_true(_press(KEY_ENTER), "Enter: the first corner")
	for k: int in 5:
		assert_true(_press(KEY_RIGHT), "right")
	for k: int in 3:
		assert_true(_press(KEY_DOWN), "down")
	assert_true(_press(KEY_ENTER), "Enter: the second corner")


func test_b_opens_and_closes_the_panel() -> void:
	"""B through the command layer; with nothing pending it closes at once."""
	assert_true(_press(KEY_B), "B taken")
	assert_true(_build.is_open(), "open")
	assert_true(_press(KEY_B), "B again")
	assert_false(_build.is_open(), "closed")
	assert_false(_command.tunnels().planning, "B never opened the Dig tool")


func test_closing_with_pending_changes_asks_and_keep_keeps_them() -> void:
	"""B with a pending room asks “Keep 1 pending changes?”."""
	_paint_kitchen_by_keys()
	assert_equal(_build.batch.pending_count(), 1, "one change")
	_press(KEY_B)
	assert_true(_build.is_open(), "still open: it asks")
	assert_equal(_build.panel.question_text(), "Keep 1 pending changes?", "the question")
	_build.panel.answer(true)
	assert_false(_build.is_open(), "closed")
	assert_equal(_build.batch.pending_count(), 1, "kept")


func test_page_keys_step_the_bar_and_say_its_ends() -> void:
	"""Surface → Level 1 → Level 2 → Level 3 → Level 4; no level above the surface, none below level 4."""
	assert_equal(_build.bar.shown_level(), LevelBar.LEVEL_SURFACE, "the surface first")
	assert_true(_press(KEY_PAGEUP), "PageUp at the surface is taken")
	assert_equal(_said[-1], "X Not possible: No level above the surface", "and says why")
	for level: int in [1, 2, 3, 4]:
		assert_true(_press(KEY_PAGEDOWN), "PageDown to %d" % level)
		assert_equal(_build.bar.shown_level(), level, "on level %d" % level)
	assert_true(_command.tunnels().view.on, "the U view on")
	_press(KEY_PAGEDOWN)
	assert_equal(_said[-1], "X Not possible: No level below level 4", "the bottom")
	var alt := _key(KEY_PAGEUP)
	alt.alt_pressed = true
	assert_false(_build.takes_before_gui(alt), "Alt+PageUp is the camera's pitch")
	var echo := _key(KEY_PAGEUP)
	echo.echo = true
	assert_true(_build.takes_before_gui(echo), "a held key's repeat is taken")
	assert_equal(_build.bar.shown_level(), 4, "and does nothing")


func test_levels_one_and_two_are_the_u_view_and_three_four_have_no_way_in() -> void:
	"""Level 1/2: the U view on that level; 3/4: the U view drawing nothing (no way in yet); back up: shown again."""
	var view = _command.tunnels().view
	_build.bar.choose(2)
	assert_true(view.on and view.level == 2 and not view.unreached, "level 2 shown")
	_build.bar.choose(3)
	assert_true(view.on and view.unreached, "level 3: nothing dug there")
	assert_equal(_build.bar.shown_level(), 3, "the bar says level 3")
	assert_equal(_build.bar.level_button(3).accessibility_name, "Underground level 3; no way in yet", "in words")
	_build.bar.choose(1)
	assert_true(view.on and view.level == 1 and not view.unreached, "level 1 shown again")
	_build.bar.choose(LevelBar.LEVEL_SURFACE)
	assert_false(view.on, "the surface")


func test_u_still_toggles_the_view_and_the_bar_follows() -> void:
	"""The view's own switch moves the bar."""
	_command.tunnels().toggle_view()
	_build.follow_view()
	assert_equal(_build.bar.shown_level(), 1, "U: level 1")
	_build.bar.choose(3)
	_command.tunnels().toggle_view()
	_build.follow_view()
	assert_equal(_build.bar.shown_level(), LevelBar.LEVEL_SURFACE, "U from level 3: the surface, the special level forgotten")
	assert_false(_command.tunnels().view.unreached, "and the view drawn normally")


func test_overview_never_paints() -> void:
	"""UX-BUILD-T05: Overview is the surface view, and nothing is armed there even with a type chosen."""
	_build.open_panel()
	_build.bar.choose(1)
	_build.panel.choose_card(KITCHEN_CARD)
	assert_equal(_build.armed_type(), 2, "armed on level 1")
	_build.bar.choose(LevelBar.LEVEL_OVERVIEW)
	assert_equal(_build.bar.shown_level(), LevelBar.LEVEL_OVERVIEW, "Overview")
	assert_false(_command.tunnels().view.on, "the surface view")
	assert_equal(_build.armed_type(), -1, "never painting")
	_build.bar.choose(3)
	assert_equal(_build.armed_type(), -1, "nor on a level with no way in")


func test_the_keyboard_paints_a_room_and_undo_redo_step_it() -> void:
	"""Enter, arrows, Enter: a 6 × 4 Kitchen; Ctrl+Z undoes it, Ctrl+Shift+Z and Ctrl+Y redo."""
	_paint_kitchen_by_keys()
	assert_equal(_build.batch.pending_count(), 1, "one Kitchen")
	assert_equal(_build.batch.operation_cell_count(0), 24, "6 × 4 cells")
	assert_equal(_build.batch.operation_level(0), 1, "on level 1")
	assert_true(_press(KEY_Z, true), "Ctrl+Z")
	assert_equal(_build.batch.pending_count(), 0, "undone")
	assert_true(_press(KEY_Z, true, true), "Ctrl+Shift+Z")
	assert_equal(_build.batch.pending_count(), 1, "redone")
	_press(KEY_Z, true)
	assert_true(_press(KEY_Y, true), "Ctrl+Y")
	assert_equal(_build.batch.pending_count(), 1, "redone again")


func test_a_stroke_in_progress_shows_its_size_and_escape_drops_it_first() -> void:
	"""The label says the size and validity; Escape drops the stroke, then asks about the panel."""
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_build.panel.choose_card(KITCHEN_CARD)
	_build.paint.set_cursor(Vector2i(0, 0), 1, 2)
	_press(KEY_ENTER)
	_press(KEY_RIGHT)
	_build._process(0.016)
	assert_true(_build.label_text().begins_with("Paint Kitchen 2 × 1 cells (2 m × 1 m)\nX Not possible: Too narrow"),
		_build.label_text())
	assert_true(_press(KEY_ESCAPE), "Escape")
	assert_false(_build.batch.stroke_active(), "the stroke dropped")
	assert_true(_build.is_open(), "the panel stays")
	assert_true(_press(KEY_ESCAPE), "Escape again")
	assert_false(_build.is_open(), "nothing pending: closed")


func test_ctrl_tab_cycles_the_tabs() -> void:
	"""With a type chosen: Rooms → Furnish → Decor."""
	_build.open_panel()
	_build.bar.choose(1)
	_build.panel.choose_card(KITCHEN_CARD)
	assert_true(_press(KEY_TAB, true), "Ctrl+Tab")
	assert_equal(_build.panel.shown_tab(), BuildCatalog.TAB_FURNISH, "Furnish")
	assert_true(_press(KEY_TAB, true, true), "Ctrl+Shift+Tab")
	assert_equal(_build.panel.shown_tab(), BuildCatalog.TAB_ROOMS, "back to Rooms")


func test_passage_opens_the_dig_tool_and_the_panel_returns_when_it_closes() -> void:
	"""The Passage card: the panel hides, the Dig tool opens; B in the tool closes it; the panel comes back."""
	_command.select(PackedInt32Array([0]))
	_build.open_panel()
	_build.panel.choose_card(_card("Passage"))
	assert_true(_command.tunnels().planning, "the Dig tool is open")
	assert_true(_build.panel.suspended(), "the panel hidden behind it")
	assert_true(_command.handle_input(_key(KEY_B)), "B in the tool")
	assert_false(_command.tunnels().planning, "the tool closed")
	_build._process(0.016)
	assert_false(_build.panel.suspended(), "the panel back")
	assert_true(_build.is_open(), "still open")


func test_the_burrow_home_and_root_cellar_cards_open_the_room_tool() -> void:
	"""Each opens its template's room tool (H and C no longer do)."""
	_command.select(PackedInt32Array([0]))
	_build.open_panel()
	_build.panel.choose_card(_card("Burrow home"))
	assert_true(_command.tunnels().room.active, "the home tool")
	_command.tunnels().cancel_plan()
	_build._process(0.016)
	_build.panel.choose_card(_card("Root cellar"))
	assert_true(_command.tunnels().room.active, "the cellar tool")
	assert_false(_command.handle_input(_key(KEY_H)) and _command.tunnels().room.plan.kind == 1, "H is no switch")


func test_the_panel_hides_the_surfaces_it_replaces_and_gives_them_back() -> void:
	"""Hidden while open (and re-hidden each frame); back as they were on close, and while an old tool runs."""
	_hidden.visible = true
	_build.open_panel()
	_build._process(0.016)
	assert_false(_hidden.visible, "hidden while open")
	_hidden.visible = true
	_build._process(0.016)
	assert_false(_hidden.visible, "re-hidden")
	_build.panel.request_close()
	assert_true(_hidden.visible, "given back")


func test_ux_build_t04_no_silent_cost() -> void:
	"""Opening, painting, undoing, discarding and a refused Confirm all change no store, reservation or job."""
	var wood: int = EconomySystem.stock_milli(&"wood")
	var stone: int = EconomySystem.stock_milli(&"stone")
	var jobs := PackedInt32Array()
	_command.tunnels().network.job_list_into(jobs)
	_paint_kitchen_by_keys()
	_press(KEY_Z, true)
	_press(KEY_Z, true, true)
	_build.confirm_all()
	assert_equal(_build.batch.pending_count(), 1, "kept: no underground in this run")
	assert_equal(_build.batch.operation_reason(0), Orders.NOT_COMPOSED, "saying why")
	_build.batch.discard_all()
	var after := PackedInt32Array()
	_command.tunnels().network.job_list_into(after)
	assert_equal(EconomySystem.stock_milli(&"wood"), wood, "wood unchanged")
	assert_equal(EconomySystem.stock_milli(&"stone"), stone, "stone unchanged")
	assert_equal(after, jobs, "no job made")
	assert_false(_command.tunnels().planning, "no tool opened")


func test_ux_build_t05_selection_identity_survives_every_level() -> void:
	"""Selecting each level keeps the selected resident."""
	_command.select(PackedInt32Array([2]))
	for level: int in [1, 2, 3, 4, LevelBar.LEVEL_OVERVIEW, LevelBar.LEVEL_SURFACE]:
		_build.bar.choose(level)
		assert_equal(_command.selected(), PackedInt32Array([2]), "level %d keeps the selection" % level)


func test_nothing_is_taken_behind_a_modal() -> void:
	"""Blocked (a modal, the stall banner): B and the level keys pass, and the panel will not open."""
	_blocked = true
	assert_false(_build.handle_input(_key(KEY_B)), "B passes")
	assert_false(_build.takes_before_gui(_key(KEY_PAGEDOWN)), "PageDown passes")
	assert_false(_build.open_panel(), "refused")
	assert_false(_build.is_open(), "closed")


func test_a_still_frame_allocates_nothing() -> void:
	"""The panel open, a type armed, nothing moving: no object is made over many frames."""
	_paint_kitchen_by_keys()
	_build._process(0.016)
	_build._process(0.016)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for frame: int in 200:
		_build._process(0.016)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), before, "no objects made")


func test_the_paint_label_stays_on_screen_and_off_the_panel() -> void:
	"""Clamped into the window; lifted above the panel rather than drawn over it."""
	var view: Vector2 = Vector2(1280, 720)
	var panel: Rect2 = Rect2(296, 448, 912, 256)
	assert_equal(BuildScript.label_position(Vector2(100, 100), Vector2(200, 40), view, panel), Vector2(100, 100), "free")
	assert_equal(BuildScript.label_position(Vector2(1200, 100), Vector2(200, 40), view, panel), Vector2(1064, 100),
		"kept 16 px inside the right edge")
	assert_equal(BuildScript.label_position(Vector2(700, 500), Vector2(200, 40), view, panel), Vector2(700, 400),
		"lifted above the panel, 8 px clear")
	assert_equal(BuildScript.label_position(Vector2(-50, -50), Vector2(200, 40), view, panel), Vector2(16, 16),
		"16 px inside the top-left")


func test_a_setup_refusal_disarms_painting() -> void:
	"""Review M4: a setup step's refusal is kept and painting stays disarmed; the first refusal wins."""
	assert_equal(_build.setup_refusal(), &"", "set up")
	_build.open_panel()
	_press(KEY_PAGEDOWN)
	_build.panel.choose_card(KITCHEN_CARD)
	assert_equal(_build.armed_type(), 2, "armed")
	_build.take_setup(&"BUILD_TEST_REFUSAL")
	_build.take_setup(&"A_SECOND_ONE")
	assert_equal(_build.setup_refusal(), &"BUILD_TEST_REFUSAL", "kept, the first")
	assert_equal(_build.armed_type(), -1, "painting disarmed")
	_build._process(0.016)
	assert_true(true, "a frame with a refused setup runs")


func test_a_ghost_refused_by_its_floor_never_breaks_a_frame() -> void:
	"""Review M4: the painter refuses an empty planning area and draws nothing on a frame without a ghost."""
	var paint = BuildScript.Paint.new()
	_nodes.append(paint)
	assert_true(paint.configure(_build.batch, null, Vector2i.ZERO, Rect2i()) != &"",
		"an empty area is refused")
	paint.refresh(1, true)
	assert_equal(paint.stroke_draws, 0, "nothing drawn, nothing broken")


func test_the_passage_card_says_who_would_dig_and_what_they_would_stop() -> void:
	"""Review M8: the old tool's action card on the Passage card's info and tooltip."""
	_command.select(PackedInt32Array([0]))
	_build.set_interrupts(_command.interrupt_text)
	_build.open_panel()
	var passage: int = _card("Passage")
	_build.panel._show_card(passage)
	assert_true(_build.panel.info_text().contains("Who: "), _build.panel.info_text())
	assert_true(_build.panel.card_button(passage).tooltip_text.contains("Who: "), "and in its tooltip")
	_build.panel._show_card(_card("Kitchen"))
	assert_false(_build.panel.info_text().contains("Who: "), "a room type has no such note")


func test_redo_waits_for_a_keyboard_stroke() -> void:
	"""Review M2: Ctrl+Shift+Z during a keyboard stroke redoes nothing."""
	_paint_kitchen_by_keys()
	_press(KEY_Z, true)
	_build.paint.set_cursor(Vector2i(20, 20), 1, 2)
	_press(KEY_ENTER)
	assert_true(_build.batch.stroke_active(), "a stroke")
	assert_true(_press(KEY_Z, true, true), "taken")
	assert_equal(_build.batch.pending_count(), 0, "nothing redone mid-stroke")


func test_a_cursor_move_redraws_no_room_ghost() -> void:
	"""Review M5: room ghosts redraw only when the batch changes; the cursor moves only the stroke ghost."""
	_paint_kitchen_by_keys()
	_build._process(0.016)
	var rooms: int = _build.paint.operation_draws
	var strokes: int = _build.paint.stroke_draws
	for k: int in 10:
		_press(KEY_RIGHT)
		_build._process(0.016)
	assert_equal(_build.paint.operation_draws, rooms, "no room ghost redrawn by the cursor")
	assert_true(_build.paint.stroke_draws > strokes, "the cursor ghost was")
	_press(KEY_Z, true)
	_build._process(0.016)
	assert_true(_build.paint.operation_draws >= rooms, "a batch change redraws the rooms")


func test_the_demo_build_command_opens_and_closes_the_panel() -> void:
	"""P-B3 (approved 2026-10-12): in the demo the HUD's Build command is enabled and does what B does -- opens the
	panel, asks Keep / Discard when closing with changes, and in the Dig tool closes the tool."""
	assert_false(_build.unlock_build_command(), "no shell: nothing to unlock")
	var shell := UiShellScript.new()
	_nodes.append(shell)
	shell.build()
	assert_true((shell.control_for(UiShellScript.ID_BUILD) as Button).disabled, "the game's shell keeps it locked")
	_build._shell = shell
	assert_true(_build.unlock_build_command(), "unlocked in the demo")
	var button: Button = shell.control_for(UiShellScript.ID_BUILD) as Button
	assert_false(button.disabled, "enabled")
	assert_equal(button.tooltip_text, "Build (B) — " + BuildScript.BUILD_COMMAND, "its tip")
	button.pressed.emit()
	assert_true(_build.is_open(), "a click opens the panel")
	button.pressed.emit()
	assert_false(_build.is_open(), "and closes it with nothing pending")
	_paint_kitchen_by_keys()
	button.pressed.emit()
	assert_equal(_build.panel.question(), BuildScript.BuildPanel.QUESTION_CLOSE, "with a change it asks first")
	_build.panel.answer(false)
	assert_true(_command.tunnels().begin_plan(), "the Dig tool open")
	button.pressed.emit()
	assert_false(_command.tunnels().planning, "in the Dig tool it closes the tool, as B does")
	assert_true(_build.unlock_build_command(), "unlocking twice connects once")
	assert_equal(button.pressed.get_connections().size(), 1, "one connection")


func test_confirm_all_names_the_room_the_route_refused() -> void:
	"""Review LOW b: "0 ordered, 1 kept back -- Kitchen: <why>" even when the refusal does not hold Confirm all back."""
	_paint_kitchen_by_keys()
	_build.confirm_all()
	assert_equal(_said[_said.size() - 1], "Confirm all: 0 ordered, 1 kept back -- Kitchen: " + Orders.NOT_COMPOSED,
		_said[_said.size() - 1])


func test_the_old_tools_notes_are_reread_on_the_party_panel_cadence() -> void:
	"""Review LOW c: while the panel shows, its card notes are re-read every PANEL_REFRESH_S, not on the frames
	between."""
	var reads: Array[int] = [0]
	_build.panel.card_note = func(_unused: BuildCatalog.Card) -> String:
		reads[0] += 1
		return ""
	_build.open_panel()
	_build._process(0.05)
	assert_true(reads[0] > 0, "read on the first frame open")
	reads[0] = 0
	_build._process(0.05)
	_build._process(0.05)
	assert_equal(reads[0], 0, "not between")
	_build._process(0.11)
	assert_true(reads[0] > 0, "read again after %.2f s" % CommandScript.PANEL_REFRESH_S)
	_build.panel.card_note = Callable()
