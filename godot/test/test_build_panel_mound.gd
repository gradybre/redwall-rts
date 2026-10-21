extends "res://test/framework/test_case.gd"
## The build panel's Mound parts (decision 2002), off-tree: the Built / Mound style toggles, the Front door and Window
## cards with the door's colour strip, the ledger's door, window and heap lines, and Confirm all's reason for a door
## or window that cannot be built.

const BuildPanel := preload("res://scripts/ui/build_panel.gd")
const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const KITCHEN: int = 2
const BEDROOM: int = 1

var _panel: BuildPanel = null
var _batch: Batch = null


func before_each() -> void:
	"""A panel over a fresh batch, placed for 1280×720, open on the Surface."""
	var catalog: BuildCatalog = BuildCatalog.new()
	_batch = Batch.new()
	assert_equal(_batch.configure(catalog, Rect2i(0, 0, 128, 128), 4096), &"", "batch")
	_panel = BuildPanel.new()
	_panel.configure(_batch, catalog, func(_good: StringName) -> int: return 0)
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	assert_true(UiLayout.new().compute_into(1280, 720, 100, false, geometry), "geometry")
	_panel.place(geometry)
	_panel.open_on(LevelBar.LEVEL_SURFACE)


func after_each() -> void:
	"""Free the panel."""
	_panel.free()
	_panel = null


func _paint(room_type: int, from: Vector2i, to: Vector2i) -> void:
	"""One Mound stroke on the Surface."""
	_batch.begin_stroke(room_type, Mound.SURFACE, from, Mound.STYLE_MOUND)
	_batch.extend_stroke(to)
	_batch.finish_stroke()


func _card_named(card_name: String) -> int:
	"""The row's card called `card_name` (-1: none)."""
	for k: int in _panel.row_cards().size():
		if _panel.row_cards()[k].name == card_name:
			return k
	return -1


func _furnish_kitchen() -> void:
	"""A Kitchen chosen, then the Furnish tab."""
	_panel.choose_card(KITCHEN)
	assert_true(_panel.select_tab(BuildCatalog.TAB_FURNISH), "Furnish")


func test_the_style_toggles_follow_the_level_and_say_why_one_is_locked() -> void:
	"""BUILD-MOUND-001: Mound pressed on the Surface, Built below; each names its lock in words; on the Rooms tab
	only; an unknown style is refused."""
	var buttons: Array[Button] = _panel.style_buttons()
	assert_equal(buttons.size(), Mound.STYLE_COUNT, "Built and Mound")
	assert_equal([buttons[0].text, buttons[1].text], ["Built", "Mound"], "named")
	assert_true(buttons[Mound.STYLE_MOUND].button_pressed and not buttons[Mound.STYLE_BUILT].button_pressed, "Mound")
	assert_equal(buttons[Mound.STYLE_BUILT].tooltip_text,
		Validity.line(Validity.KIND_BLOCKED, "Not yet: " + Mound.LATER_BUILT_SURFACE), "built: not yet on the Surface")
	assert_equal(buttons[Mound.STYLE_MOUND].accessibility_name, "Mound style", "its accessible name")
	_panel.set_level(1)
	assert_equal(_panel.style(), Mound.STYLE_BUILT, "below: Built")
	assert_true(buttons[Mound.STYLE_BUILT].button_pressed, "pressed")
	assert_equal(buttons[Mound.STYLE_MOUND].tooltip_text,
		Validity.line(Validity.KIND_NOT_POSSIBLE, Mound.TEXT_SURFACE_ONLY), "a Mound below: X in words")
	assert_false(_panel.choose_style(7), "no such style")
	assert_equal(_panel.style(), Mound.STYLE_BUILT, "unchanged")
	_panel.choose_card(KITCHEN)
	_panel.select_tab(BuildCatalog.TAB_FURNISH)
	assert_false(buttons[0].visible or buttons[1].visible, "not on the Furnish tab")


func test_choosing_the_mound_style_below_locks_and_disarms_the_room_types() -> void:
	"""On level 1 in the Mound style a chosen Kitchen is put down and its card names the Surface rule."""
	_panel.set_level(1)
	_panel.choose_card(KITCHEN)
	assert_equal(_panel.paint_type(), KITCHEN, "a built Kitchen paints below")
	assert_true(_panel.choose_style(Mound.STYLE_MOUND), "chosen")
	assert_null(_panel.chosen_card(), "disarmed")
	assert_equal(_panel.paint_type(), -1, "nothing paints")
	assert_false(_panel.row_cards()[KITCHEN].usable(), "the Kitchen card locked")
	assert_equal(_panel.row_cards()[KITCHEN].lock_kind, Validity.KIND_NOT_POSSIBLE, "as X")
	_panel.set_level(LevelBar.LEVEL_SURFACE)
	assert_equal(_panel.style(), Mound.STYLE_MOUND, "the Surface's own style")


func test_the_front_door_card_arms_it_and_offers_its_colours() -> void:
	"""P-2001-8 (a): the Front door's strip reads Oak · Green · Red · Blue, oak pressed; a choice names its colour in
	the info card; Window shows no strip."""
	_furnish_kitchen()
	var door: int = _card_named("Front door")
	assert_true(door >= 0 and _card_named("Window") >= 0, "both cards on the Surface")
	_panel.choose_card(door)
	assert_true(_panel.edge_armed(), "armed")
	assert_equal(_panel.armed_edge_kind(), Mound.KIND_DOOR, "the door")
	assert_equal(_panel.paint_type(), -1, "nothing paints meanwhile")
	var strip: Array[Button] = _panel.tool_buttons()
	assert_equal([strip[0].text, strip[1].text, strip[2].text, strip[3].text], ["Oak", "Green", "Red", "Blue"], "colours")
	assert_true(strip[0].visible and strip[Mound.COLOUR_OAK].button_pressed, "oak by default")
	assert_equal(strip[2].accessibility_name, "Red door", "named")
	assert_true(_panel.choose_tool(2), "the strip's third toggle")
	assert_equal(_panel.door_colour(), 2, "red")
	assert_true(strip[2].button_pressed and not strip[0].button_pressed, "pressed")
	assert_true(_panel.info_text().contains("Colour: Red."), _panel.info_text())
	assert_false(_panel.choose_colour(Mound.COLOUR_NAMES.size()), "no such colour")
	assert_equal(_batch.tool(), Stroke.TOOL_RECTANGLE, "the batch's tool untouched")
	_panel.choose_card(_card_named("Window"))
	assert_equal(_panel.armed_edge_kind(), Mound.KIND_WINDOW, "the window")
	assert_false(strip[0].visible, "no strip for a window")


func test_below_the_surface_only_the_window_card_and_never_on_overview() -> void:
	"""BUILD-MOUND-020: below, the Window card stays (refused where it is placed); the Front door goes, and a chosen
	door is put down; on Overview neither, and nothing is armed."""
	_furnish_kitchen()
	_panel.choose_card(_card_named("Front door"))
	_panel.set_level(1)
	assert_null(_panel.chosen_card(), "the door put down below")
	assert_equal(_card_named("Front door"), -1, "no door card")
	assert_true(_card_named("Window") >= 0, "the Window card")
	_panel.choose_card(_card_named("Window"))
	assert_true(_panel.edge_armed(), "armed below (its click is refused in words)")
	_panel.set_level(LevelBar.LEVEL_OVERVIEW)
	assert_false(_panel.edge_armed(), "never on Overview")
	assert_equal(_panel.armed_edge_kind(), -1, "none")


func test_the_ledger_lists_doors_windows_removals_and_the_heap() -> void:
	"""Each pending door (its colour), window and the Mound heap's ruled measures, free."""
	_paint(KITCHEN, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 1)
	_batch.toggle_mound_edge(0, Vector2i(15, 11), 1, Mound.KIND_WINDOW, 0)
	_panel.refresh(true)
	var lines: String = _panel.ledger_lines("summary").replace("\n", " | ")
	assert_true(lines.contains("Surface · Front door, green (free for now): ✓ Can build"), lines)
	assert_true(lines.contains("Surface · Window (free for now): ✓ Can build"), lines)
	assert_true(lines.contains(BuildPanel.HEAP_LINE % 24), lines)
	_batch.discard_all()
	_panel.refresh(true)
	assert_false(_panel.ledger_lines("s").contains("Mound heap"), "no Mound room: no heap line")


func test_confirm_all_names_a_window_that_cannot_be_built() -> void:
	"""A window whose edge a later room made inner holds Confirm all back in its own words."""
	_paint(KITCHEN, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 13), 2, Mound.KIND_DOOR, 0)
	_batch.toggle_mound_edge(0, Vector2i(11, 10), 0, Mound.KIND_WINDOW, 0)
	_panel.refresh(true)
	assert_equal(_panel.confirm_blocked(), "", "all ready")
	_paint(BEDROOM, Vector2i(10, 6), Vector2i(15, 9))
	_panel.refresh(true)
	assert_equal(_panel.confirm_blocked(), "X 1 of 4 not ready: Window: %s" % Mound.TEXT_OFF_OUTER, "the window")
	var confirm: Button = _panel.controls()[&"confirm"]
	assert_true(confirm.disabled, "held back")
