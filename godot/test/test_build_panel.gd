extends "res://test/framework/test_case.gd"
## UI-BUILD-001..009, the build panel off-tree: tabs and their gate, cards and the info card, the footer's words and
## states, the two questions, the Escape order, the geometry it is placed at, the accessible names, and that its
## per-frame refresh allocates nothing while the batch is still. Decision 1871.

const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")

const KITCHEN: int = 2

var _panel: BuildPanel = null
var _batch: Batch = null
var _catalog: BuildCatalog = null
var _closed: Array = []
var _confirms: int = 0
var _chosen: Array = []


func before_each() -> void:
	"""A panel over a fresh batch, placed for 1280×720, open on level 1."""
	_catalog = BuildCatalog.new()
	_batch = Batch.new()
	assert_equal(_batch.configure(_catalog, Rect2i(0, 0, 128, 128), 4096), &"", "batch")
	_panel = BuildPanel.new()
	_panel.configure(_batch, _catalog, _stock)
	_closed.clear()
	_chosen.clear()
	_confirms = 0
	_panel.closed.connect(func(kept: bool) -> void: _closed.append(kept))
	_panel.confirm_requested.connect(func() -> void: _confirms += 1)
	_panel.card_chosen.connect(func(card: BuildCatalog.Card) -> void: _chosen.append(card.name))
	_place(1280, 720, 100)
	_panel.open_on(1)


func after_each() -> void:
	"""Free the panel (its lambdas hold it and these lists)."""
	_panel.free()
	_panel = null


func _stock(good: StringName) -> int:
	"""The stores hold 40 logs and 20 blocks."""
	return 40000 if good == &"wood" else 20000


func _place(width: int, height: int, percent: int) -> void:
	"""Place the panel for a viewport."""
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	assert_true(UiLayout.new().compute_into(width, height, percent, false, geometry), "geometry")
	_panel.place(geometry)


func _paint(from: Vector2i, to: Vector2i) -> void:
	"""One Kitchen stroke on level 1."""
	_batch.begin_stroke(KITCHEN, 1, from)
	_batch.extend_stroke(to)
	_batch.finish_stroke()
	_panel.refresh(false)


func test_it_opens_on_the_rooms_tab_with_furnish_and_decor_gated() -> void:
	"""Furnish/Decor disabled with "Choose a room type first" until a room type is chosen."""
	var tabs: Array = _panel.controls()[&"tabs"]
	assert_true(_panel.is_open(), "open")
	assert_equal(_panel.shown_tab(), BuildCatalog.TAB_ROOMS, "Rooms")
	assert_true((tabs[1] as Button).disabled and (tabs[2] as Button).disabled, "Furnish and Decor disabled")
	assert_equal((tabs[1] as Button).tooltip_text, "Choose a room type first", "saying why")
	assert_false(_panel.select_tab(BuildCatalog.TAB_FURNISH), "refused")
	assert_equal((tabs[0] as Button).accessibility_name, "Rooms tab 1 of 3", "tab name")
	_panel.choose_card(2)
	assert_false((tabs[1] as Button).disabled, "a Kitchen chosen: Furnish opens")
	assert_true(_panel.select_tab(BuildCatalog.TAB_FURNISH), "and selects")
	assert_true(_panel.row_cards().size() > 0, "with the Kitchen's items")


func test_ctrl_tab_cycles_the_enabled_tabs() -> void:
	"""Rooms only until a type is chosen; then Rooms → Furnish → Decor → Rooms, and back."""
	assert_equal(_panel.cycle_tab(true), BuildCatalog.TAB_ROOMS, "only Rooms is enabled")
	_panel.choose_card(0)
	assert_equal(_panel.cycle_tab(true), BuildCatalog.TAB_FURNISH, "Furnish")
	assert_equal(_panel.cycle_tab(true), BuildCatalog.TAB_DECOR, "Decor")
	assert_equal(_panel.cycle_tab(true), BuildCatalog.TAB_ROOMS, "round to Rooms")
	assert_equal(_panel.cycle_tab(false), BuildCatalog.TAB_DECOR, "Ctrl+Shift+Tab back")


func test_the_info_card_follows_the_shown_card_or_asks_for_a_choice() -> void:
	"""Nothing chosen: "Choose a room type to begin"; a card: its purpose, cost, rules; a locked one: why."""
	assert_equal(_panel.info_text(), "Choose a room type to begin", "nothing chosen")
	_panel.choose_card(2)
	assert_true(_panel.info_text().begins_with("Kitchen\n"), _panel.info_text())
	assert_true(_panel.info_text().contains("Needs 1 bench and 1 hearth; at least 24 cells"), "rules")
	assert_true(_panel.info_text().contains("per cell"), "cost")
	var info: Control = _panel.controls()[&"info"]
	assert_true(info.accessibility_name.begins_with("Picture (placeholder): "), "the picture described")
	_panel.choose_card(8)
	assert_true(_panel.info_text().contains("! Blocked: Not yet:"), "a locked card says why: %s" % _panel.info_text())
	assert_equal(_panel.paint_type(), KITCHEN, "inspecting a locked card keeps the Kitchen armed")


func test_choosing_arms_paintable_types_only() -> void:
	"""A room type arms painting -- Passage too, as CORRIDOR (BUILD-REQ-014, decision 1912); a locked card is only
	told to the host and keeps the armed type."""
	_panel.choose_card(2)
	assert_equal(_panel.paint_type(), KITCHEN, "Kitchen armed")
	_panel.choose_card(7)
	assert_equal(_panel.paint_type(), BuildCatalog.CORRIDOR, "Passage paints")
	_panel.choose_card(9)
	assert_equal(_panel.paint_type(), BuildCatalog.CORRIDOR, "the locked Remove card keeps Passage armed")
	assert_equal(_chosen, ["Kitchen", "Passage", "Remove"], "each told to the host")
	_panel.choose_card(99)
	assert_equal(_chosen.size(), 3, "a card past the row does nothing")


func test_on_the_surface_nothing_paints() -> void:
	"""Room types are locked on the surface; a chosen type is disarmed on the way up."""
	_panel.choose_card(2)
	_panel.set_level(0)
	assert_equal(_panel.paint_type(), -1, "no surface painting")
	assert_null(_panel.chosen_card(), "disarmed")
	_panel.choose_card(2)
	assert_equal(_panel.paint_type(), -1, "a locked type does not arm")
	assert_true(_panel.info_text().contains("rooms on the surface"), _panel.info_text())
	var where: Label = _panel.controls()[&"where"]
	assert_equal(where.text, "Building on: Surface", "the words follow the level")


func test_the_footer_with_an_empty_batch() -> void:
	"""Undo/Redo say "Nothing to undo/redo"; Discard all and Confirm all are disabled, Confirm saying why."""
	var c: Dictionary = _panel.controls()
	assert_true((c[&"undo"] as Button).disabled and (c[&"redo"] as Button).disabled, "no history")
	assert_equal((c[&"undo"] as Button).accessibility_name, "Nothing to undo", "Undo's words")
	assert_equal((c[&"redo"] as Button).accessibility_name, "Nothing to redo", "Redo's words")
	assert_true((c[&"discard"] as Button).disabled, "nothing to discard")
	assert_true((c[&"confirm"] as Button).disabled, "nothing to confirm")
	assert_equal(_panel.confirm_blocked(), "Nothing to confirm yet", "and why")
	assert_true((c[&"ledger"] as Button).text.begins_with("Plan: nothing yet"), (c[&"ledger"] as Button).text)
	assert_equal((c[&"frame"] as Control).accessibility_name, "Build on Underground level 1; 0 pending changes", "frame")


func test_confirm_all_names_the_first_reason_and_the_count() -> void:
	"""BUILD-REQ-021: disabled with "! 1 of 1 not ready: Kitchen: Too small: ..."; enabled once valid."""
	_paint(Vector2i(0, 0), Vector2i(3, 3))
	var confirm: Button = _panel.controls()[&"confirm"]
	assert_true(confirm.disabled, "a 16-cell Kitchen holds it back")
	assert_equal(_panel.confirm_blocked(),
		"! 1 of 1 not ready: Kitchen: Too small: Kitchen needs at least 24 cells (has 16)", "first reason and count")
	assert_equal(confirm.tooltip_text, _panel.confirm_blocked(), "said on the button")
	assert_equal((_panel.controls()[&"status"] as Label).text, _panel.confirm_blocked(), "and in the status line")
	_paint(Vector2i(0, 4), Vector2i(3, 5))
	assert_false(confirm.disabled, "24 cells: ready")
	assert_equal(confirm.accessibility_name, "Confirm all; 1 changes", "UI-BUILD-008's name")
	assert_equal(confirm.text, "Confirm all (1)", "the count on it")
	confirm.pressed.emit()
	assert_equal(_confirms, 1, "asked the host to order it")
	_batch.begin_stroke(KITCHEN, 1, Vector2i(20, 20))
	_panel.refresh(false)
	assert_true(confirm.disabled, "never mid-stroke")
	assert_equal(_panel.confirm_blocked(), "Finish or cancel the stroke first", "and why")


func test_undo_and_redo_buttons_step_the_batch_and_name_their_step() -> void:
	"""UI-BUILD-006/007: “Undo Paint Kitchen”, “Redo Paint Kitchen”."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	var c: Dictionary = _panel.controls()
	assert_equal((c[&"undo"] as Button).accessibility_name, "Undo Paint Kitchen", "named")
	(c[&"undo"] as Button).pressed.emit()
	assert_equal(_batch.pending_count(), 0, "undone")
	assert_equal((c[&"redo"] as Button).accessibility_name, "Redo Paint Kitchen", "redo named")
	(c[&"redo"] as Button).pressed.emit()
	assert_equal(_batch.pending_count(), 1, "redone")


func test_discard_all_asks_once_and_keep_them_keeps_them() -> void:
	"""“Discard 1 pending changes?” — Keep them keeps; Discard all discards; no store is touched."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	(_panel.controls()[&"discard"] as Button).pressed.emit()
	assert_equal(_panel.question(), BuildPanel.QUESTION_DISCARD, "asked")
	assert_equal(_panel.question_text(), "Discard 1 pending changes?", "in words")
	assert_false((_panel.controls()[&"confirm"] as Button).visible, "the question stands in the footer's place")
	_panel.answer(false)
	assert_equal(_batch.pending_count(), 1, "kept")
	(_panel.controls()[&"discard"] as Button).pressed.emit()
	_panel.answer(true)
	assert_equal(_batch.pending_count(), 0, "discarded")
	assert_true(_panel.is_open(), "the panel stays open")


func test_closing_with_pending_changes_asks_keep_or_discard() -> void:
	"""“Keep 1 pending changes?” (Keep / Discard); closing with none just closes."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	assert_false(_panel.request_close(), "asked first")
	assert_equal(_panel.question_text(), "Keep 1 pending changes?", "the question")
	_panel.answer(true)
	assert_false(_panel.is_open(), "closed")
	assert_equal(_closed, [true], "kept")
	assert_equal(_batch.pending_count(), 1, "the batch kept")
	_panel.open_on(1)
	_panel.request_close()
	_panel.answer(false)
	assert_equal(_closed, [true, false], "discarded the second time")
	assert_equal(_batch.pending_count(), 0, "the batch gone")
	_panel.open_on(1)
	assert_true(_panel.request_close(), "nothing pending: closes at once")


func test_escape_goes_stroke_question_ledger_then_panel() -> void:
	"""The Escape order: the stroke in progress, the question, the expanded ledger, the panel."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	_panel.set_ledger_expanded(true)
	_batch.begin_stroke(KITCHEN, 1, Vector2i(10, 10))
	assert_true(_panel.escape(), "one")
	assert_false(_batch.stroke_active(), "the stroke went first")
	assert_true(_panel.ledger_expanded(), "the ledger still open")
	assert_true(_panel.escape(), "two")
	assert_false(_panel.ledger_expanded(), "then the ledger")
	assert_true(_panel.escape(), "three")
	assert_equal(_panel.question(), BuildPanel.QUESTION_CLOSE, "then the panel, which asks")
	assert_true(_panel.escape(), "four")
	assert_equal(_panel.question(), BuildPanel.QUESTION_NONE, "Escape withdraws the question")
	assert_true(_panel.is_open(), "still open")
	_panel.answer(true)
	_panel.request_close()
	_panel.answer(true)
	assert_false(_panel.escape(), "a closed panel takes no Escape")


func test_the_expanded_ledger_lists_types_operations_and_totals() -> void:
	"""“Kitchen (+24 cells)”, each operation's validity, then the totals beside the stores."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	_panel.set_ledger_expanded(true)
	var lines: String = _panel.ledger_lines("TOTALS")
	assert_true(lines.begins_with("Kitchen (+24 cells)\n"), lines)
	assert_true(lines.contains("Level 1 · Kitchen (+24 cells): ✓ Can build"), lines)
	assert_true(lines.ends_with("TOTALS"), "totals last")
	var ledger: Button = _panel.controls()[&"ledger"]
	assert_true(ledger.accessibility_name.begins_with("Plan needs 24 logs"), ledger.accessibility_name)
	assert_true(ledger.accessibility_name.contains("stores hold 40 logs"), ledger.accessibility_name)
	assert_true(_panel.ledger_rect().size.x >= 320.0, "at least 320 wide")


func test_it_is_placed_by_the_geometry_equations() -> void:
	"""1280×720: x 296, y 448, 912 × 256; the footer's controls inside the frame."""
	assert_equal(_panel.frame_rect(), Rect2(296, 448, 912, 256), "1280×720")
	var frame: Rect2 = Rect2(Vector2.ZERO, _panel.frame_rect().size)
	for key: StringName in [&"ledger", &"undo", &"redo", &"discard", &"confirm"]:
		var control: Control = _panel.controls()[key]
		assert_true(frame.encloses(Rect2(control.position, control.size)), "%s inside the panel" % key)
		assert_true(control.size.y >= 44.0, "%s at least 44 high" % key)
	_place(1280, 720, 150)
	assert_almost_equal(_panel.frame_rect().size.x, 645.333, "narrow width")
	assert_almost_equal(_panel.screen_rect().size.x, 645.333 * 1.5, "drawn at the HUD's scale")


func test_the_per_frame_refresh_allocates_nothing_while_the_batch_is_still() -> void:
	"""Two integer compares a frame: the same strings, no new objects."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	_panel.refresh(false)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var text: String = (_panel.controls()[&"ledger"] as Button).text
	for frame: int in 200:
		_panel._process(0.016)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), before, "no objects made")
	assert_equal((_panel.controls()[&"ledger"] as Button).text, text, "nothing redrawn")


func test_card_buttons_carry_the_cards_accessible_names() -> void:
	"""UI-BUILD-003: Name; cost; footprint; unlock state."""
	var first: Button = _panel.card_button(0)
	assert_true(first.visible, "a card")
	assert_true(first.accessibility_name.begins_with("Dormitory; per cell "), first.accessibility_name)
	assert_true(first.text.contains("Dormitory"), first.text)
	var locked: Button = _panel.card_button(9)
	assert_true(locked.text.contains("! Not yet"), "a locked card shows its glyph: %s" % locked.text)
	assert_false(_panel.card_button(10).visible, "the pool's spare buttons are hidden")
	assert_null(_panel.card_button(99), "none past the pool")


func test_the_expanded_ledger_scrolls_many_operations_inside_the_panel() -> void:
	"""Review H2: twelve rooms (most of them refused) never push the ledger over the footer, off screen or over the
	alerts: it stands inside the panel and its words scroll. At 1280×720 and at NARROW."""
	for k: int in 12:
		_batch.begin_stroke(6, 1, Vector2i(k * 6, 40))
		_batch.extend_stroke(Vector2i(k * 6 + 3, 43))
		_batch.finish_stroke()
	var answer: Dictionary = {"ok": false, "error": "No way in: connect to a finished Passage or entrance", "kind": 1}
	_batch.confirm_all(func(_d: Object, _l: int, _t: int) -> Dictionary: return answer)
	for percent: int in [100, 150]:
		_place(1280, 720, percent)
		_panel.set_ledger_expanded(true)
		var open: Rect2 = _panel.ledger_rect()
		assert_true(open.size.y > 0.0 and _panel.screen_rect().encloses(open), "%d%%: inside the panel %s" % [percent, open])
		assert_equal(open.position.y, _panel.screen_rect().position.y, "%d%%: from its top edge, below the alerts" % percent)
		assert_true(_panel.ledger_lines("T").count("\n") >= 13, "%d%%: every room listed" % percent)
		var scroll: ScrollContainer = _panel.controls()[&"ledger_scroll"]
		assert_true(scroll.position.y + scroll.size.y <= open.size.y / _panel.scale.y, "%d%%: the words scroll inside it" % percent)
		_panel.set_ledger_expanded(false)


func test_a_route_refusal_reads_in_the_status_and_confirm_all_stays_enabled() -> void:
	"""Review H3: "! Refused last time, Confirm all tries again: …"; Confirm all enabled."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	var answer: Dictionary = {"ok": false, "error": "No way in: x", "kind": 1}
	_batch.confirm_all(func(_d: Object, _l: int, _t: int) -> Dictionary: return answer)
	_panel.refresh(true)
	assert_false((_panel.controls()[&"confirm"] as Button).disabled, "Confirm all still enabled: it retries")
	assert_equal((_panel.controls()[&"status"] as Label).text,
		"! Refused last time, Confirm all tries again: Kitchen: No way in: x", "the status says so")


func test_a_row_longer_than_the_pool_drops_no_card() -> void:
	"""Review LOW: the card pool grows; every card gets a button."""
	var many: Array[BuildCatalog.Card] = []
	for k: int in BuildPanel.CARD_POOL + 5:
		many.append(_catalog.room_card(k % 7, ""))
	_panel._cards = many
	_panel._sync_cards()
	assert_true(_panel.card_button(BuildPanel.CARD_POOL + 4) != null, "the 21st card has a button")
	assert_true(_panel.card_button(BuildPanel.CARD_POOL + 4).visible, "shown")


func test_a_stroke_alone_does_not_rebuild_the_ledger() -> void:
	"""Review LOW: a stroke's moves redraw the history and Confirm all, never the ledger's words."""
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	var ledger: Button = _panel.controls()[&"ledger"]
	ledger.text = "SENTINEL"
	_batch.begin_stroke(KITCHEN, 1, Vector2i(20, 20))
	_batch.extend_stroke(Vector2i(23, 23))
	_panel.refresh(false)
	assert_equal(ledger.text, "SENTINEL", "the ledger untouched by the stroke")
	assert_equal(_panel.confirm_blocked(), "Finish or cancel the stroke first", "Confirm all followed it")


func test_the_tool_strip_shows_with_a_room_type_and_sets_the_batch_tool() -> void:
	"""Decision 1912 (P-C7 (a)): Rect · Oval · Paint · Erase under the info card once a room type is chosen; a press
	sets the batch's tool, the pressed one is named "selected", and the info card says the tool and its gesture."""
	var tools: Array[Button] = _panel.tool_buttons()
	assert_equal(tools.size(), 4, "four tools")
	for button: Button in tools:
		assert_false(button.visible, "hidden before a choice")
	_panel.choose_card(2)
	assert_true(tools[0].visible and tools[0].button_pressed, "Rectangle shown and pressed")
	assert_equal(tools[1].accessibility_name, "Oval tool", "named in words")
	assert_true(_panel.choose_tool(Stroke.TOOL_ERASE), "Erase")
	assert_equal(_batch.tool(), Stroke.TOOL_ERASE, "the batch's tool")
	assert_true(tools[3].button_pressed and not tools[0].button_pressed, "only Erase pressed")
	assert_equal(tools[3].accessibility_description, "selected", "said, not only shown")
	assert_true(_panel.info_text().ends_with("Tool: Erase. %s" % Stroke.TOOL_GESTURES[Stroke.TOOL_ERASE]),
		_panel.info_text())
	assert_false(_panel.choose_tool(9), "no ninth tool")
	_panel.select_tab(1)
	assert_false(tools[0].visible, "hidden on Furnish")


func test_the_tool_strip_sits_inside_the_info_card_at_every_profile() -> void:
	"""The strip's four toggles lie wholly inside the info card, 32 px high, never over the card row."""
	for profile: int in [UiLayout.PROFILE_NARROW, UiLayout.PROFILE_STANDARD, UiLayout.PROFILE_WIDE]:
		var strip: Rect2 = BuildLayout.tool_strip_rect(profile)
		var info: Rect2 = BuildLayout.info_rect(profile)
		assert_true(info.encloses(strip), "inside the info card at profile %d" % profile)
		assert_equal(strip.size.y, BuildLayout.TOOL_STRIP_HEIGHT, "32 high")
		assert_false(strip.intersects(BuildLayout.cards_rect(912.0, profile)), "clear of the cards")


func test_the_ledger_prices_each_room_at_its_own_level() -> void:
	"""Review LOW: a room on a taller level costs more in the ledger than the same room on level 1."""
	_catalog.set_level_clear_height(2, 8192)
	_paint(Vector2i(0, 0), Vector2i(5, 3))
	var level_one: String = (_panel.controls()[&"ledger"] as Button).accessibility_name
	_batch.discard_all()
	_batch.begin_stroke(KITCHEN, 2, Vector2i(0, 0))
	_batch.extend_stroke(Vector2i(5, 3))
	_batch.finish_stroke()
	_panel.refresh(false)
	assert_true((_panel.controls()[&"ledger"] as Button).accessibility_name != level_one, "level 2 priced its own way")


func test_the_expanded_ledger_hides_the_tab_row_under_it() -> void:
	"""Review LOW a: expanded, the tabs and the where/status words are hidden (none clickable or showing beside it);
	folded, or the panel closed and opened again, they are back."""
	var tabs: Array = _panel.controls()[&"tabs"]
	_panel.set_ledger_expanded(true)
	for tab: Button in tabs:
		assert_false(tab.visible, "%s hidden" % tab.text)
	assert_false((_panel.controls()[&"where"] as Label).visible or (_panel.controls()[&"status"] as Label).visible,
		"the words hidden")
	_panel.set_ledger_expanded(false)
	assert_true((tabs[2] as Button).visible and (_panel.controls()[&"status"] as Label).visible, "folded: back")
	_panel.set_ledger_expanded(true)
	assert_true(_panel.request_close(), "closed")
	_panel.open_on(1)
	assert_true((tabs[0] as Button).visible and (_panel.controls()[&"where"] as Label).visible, "reopened: back")
	assert_false(_panel.ledger_expanded(), "folded")


func test_a_locked_card_says_its_own_reason() -> void:
	"""Review LOW d: on Overview a room card reads "! Choose one level to paint on"; on a level with no way in it is
	usable (its cells say "No way in" on the ghost, decision 1912); the whole reason stays in the info card."""
	_panel.set_level(LevelBar.LEVEL_OVERVIEW)
	assert_true(_panel.card_button(0).text.ends_with("\n! Choose one level to paint on"), _panel.card_button(0).text)
	_panel.set_level(3, false)
	assert_false(_panel.card_button(0).text.contains("!"), _panel.card_button(0).text)
