extends "res://test/framework/test_case.gd"
## UI-BUILD-013/014, the level bar: six levels, one selected, PageUp/PageDown stepping Surface ... Level 4 and never
## to Overview, its ends, never disabled ("no way in yet"), accessible names, and its place at every profile.
## Decision 1871.

const LevelBar := preload("res://scripts/ui/level_bar.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")

var _bar: LevelBar = null
var _chosen: PackedInt32Array = PackedInt32Array()


func before_each() -> void:
	"""A built bar, listening for its choices."""
	_bar = LevelBar.new()
	_bar.build()
	_chosen.clear()
	_bar.level_chosen.connect(_on_chosen)


func after_each() -> void:
	"""Free the bar."""
	_bar.free()


func _on_chosen(level: int) -> void:
	"""Record a choice."""
	_chosen.append(level)


func test_six_levels_with_their_full_names() -> void:
	"""Surface, Underground level 1-4, Overview, all levels."""
	assert_equal(LevelBar.LEVEL_COUNT, 6, "six")
	assert_equal(LevelBar.level_name(0), "Surface", "surface")
	assert_equal(LevelBar.level_name(4), "Underground level 4", "level 4")
	assert_equal(LevelBar.level_name(5), "Overview, all levels", "overview")
	assert_equal(LevelBar.level_name(6), "", "no seventh")
	assert_equal(LevelBar.level_name(-1), "", "none before")


func test_exactly_one_level_is_selected() -> void:
	"""Choosing one presses it and releases the rest."""
	_bar.choose(2)
	for level: int in LevelBar.LEVEL_COUNT:
		assert_equal(_bar.level_button(level).button_pressed, level == 2, "level %d" % level)
	assert_equal(_chosen, PackedInt32Array([2]), "told the host")
	_bar.set_level(0)
	assert_equal(_chosen.size(), 1, "set_level tells no one")
	assert_true(_bar.level_button(0).button_pressed and not _bar.level_button(2).button_pressed, "the view's level shown")


func test_page_down_and_up_step_surface_to_level_4_and_stop_at_the_ends() -> void:
	"""PageDown deeper, PageUp shallower; no level above the surface, none below level 4."""
	assert_false(_bar.step(-1), "no level above the surface")
	for expected: int in [1, 2, 3, 4]:
		assert_true(_bar.step(1), "down to %d" % expected)
		assert_equal(_bar.shown_level(), expected, "on %d" % expected)
	assert_false(_bar.step(1), "no level below level 4")
	assert_equal(_bar.shown_level(), 4, "still level 4")
	assert_true(_bar.step(-1), "up")
	assert_equal(_bar.shown_level(), 3, "level 3")
	assert_equal(_chosen, PackedInt32Array([1, 2, 3, 4, 3]), "each step chose its level")


func test_overview_is_only_reached_by_clicking_and_steps_from_the_level_before_it() -> void:
	"""No step ever lands on Overview; from Overview, PageDown goes one below the level shown before it."""
	_bar.choose(2)
	_bar.level_button(LevelBar.LEVEL_OVERVIEW).pressed.emit()
	assert_equal(_bar.shown_level(), LevelBar.LEVEL_OVERVIEW, "clicked")
	assert_equal(_bar.step_target(1), 3, "from level 2")
	assert_true(_bar.step(1), "PageDown leaves Overview")
	assert_equal(_bar.shown_level(), 3, "level 3")
	for k: int in 10:
		_bar.step(1 if k % 2 == 0 else -1)
		assert_true(_bar.shown_level() != LevelBar.LEVEL_OVERVIEW, "never a step's target")
	_bar.choose(0)
	_bar.choose(LevelBar.LEVEL_OVERVIEW)
	assert_true(_bar.step(-1), "PageUp from Overview over the surface still leaves Overview")
	assert_equal(_bar.shown_level(), 0, "for the surface")


func test_no_level_button_is_ever_disabled_and_unreached_ones_say_so() -> void:
	"""Levels 3 and 4 without a way in still select, and read "no way in yet"."""
	_bar.set_reachable(3, false)
	_bar.set_reachable(4, false)
	for level: int in LevelBar.LEVEL_COUNT:
		assert_false(_bar.level_button(level).disabled, "level %d enabled" % level)
	assert_equal(_bar.level_button(3).accessibility_name, "Underground level 3; no way in yet", "level 3 says so")
	assert_equal(_bar.level_button(1).accessibility_name, "Underground level 1; way in open", "level 1 open")
	assert_false(_bar.is_reachable(3), "remembered")
	_bar.choose(3)
	assert_equal(_bar.shown_level(), 3, "and it selects")
	_bar.set_reachable(9, false)
	assert_false(_bar.is_reachable(9), "an unknown level is never reachable")


func test_the_bar_names_the_level_viewed() -> void:
	"""UI-BUILD-013: "Levels; viewing <name>"."""
	_bar.choose(1)
	assert_equal(_bar.accessible_text(), "Levels; viewing Underground level 1", "level 1")
	_bar.set_level(9)
	assert_equal(_bar.shown_level(), 1, "an unknown level is ignored")


func test_labels_shorten_in_narrow_and_names_stay_full() -> void:
	"""Visible “Surf.”, “L1”… in NARROW; “Surface”, “Level 1” otherwise; accessible names always full."""
	var layout: UiLayout = UiLayout.new()
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	assert_true(layout.compute_into(1280, 720, 150, false, geometry), "narrow geometry")
	_bar.place(geometry, true)
	assert_equal(_bar.level_button(0).text, "Surf.", "narrow surface")
	assert_equal(_bar.level_button(5).text, "All", "narrow overview")
	assert_true(_bar.level_button(0).accessibility_name.begins_with("Surface;"), "full name")
	assert_almost_equal(_bar.frame_rect().position.y, 160.0, "narrow y 160")
	assert_true(layout.compute_into(1920, 1080, 100, false, geometry), "wide geometry")
	_bar.place(geometry, false)
	assert_equal(_bar.level_button(1).text, "Level 1", "wide label")
	assert_equal(_bar.frame_rect(), Rect2(16, 1080 - 16 - 44 - 8 - 140, 256, 140), "above the hidden map's restore control")
	assert_equal(_bar.screen_rect(), _bar.frame_rect(), "scale 1")


func test_choosing_an_unknown_level_does_nothing() -> void:
	"""Out of range choices are ignored."""
	_bar.choose(-1)
	_bar.choose(6)
	assert_equal(_chosen.size(), 0, "nothing chosen")
	assert_null(_bar.level_button(7), "no button past the six")


func test_an_unreached_level_carries_a_mark_besides_colour() -> void:
	"""Review LOW: "Level 3 !" (NARROW "L3 !"); the spec's labels otherwise unchanged; the mark goes with the way in."""
	_bar.set_reachable(3, false)
	assert_equal(_bar.level_button(3).text, "Level 3 !", "marked")
	assert_equal(_bar.level_button(2).text, "Level 2", "a reached level unmarked")
	assert_equal(_bar.level_button(3).tooltip_text, "Underground level 3; no way in yet", "the words in the tooltip")
	var geometry: UiLayout.Geometry = UiLayout.Geometry.new()
	assert_true(UiLayout.new().compute_into(1280, 720, 150, false, geometry), "NARROW geometry")
	_bar.place(geometry, true)
	assert_equal(_bar.level_button(3).text, "L3 !", "NARROW marked")
	assert_equal(_bar.level_button(5).text, "All", "NARROW's labels kept")
	_bar.set_reachable(3, true)
	assert_equal(_bar.level_button(3).text, "L3", "the mark leaves with a way in")
