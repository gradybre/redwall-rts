extends Control
## UI-BUILD-013 the level bar and UI-BUILD-014 its level buttons (DEC-061 Q1, Q6; docs/ui_ux_controls.md UI-BUILD-001;
## registers the level part of UI-MOVE-001). ALWAYS shown -- also with the minimap hidden and outside build mode --
## bottom-left above the minimap (build_layout.gd). Six toggles in 2 columns × 3 rows: Surface, Underground levels 1-4
## and Overview; exactly one is selected. PageUp / PageDown (the `level_up` / `level_down` actions, decision 1851
## OPEN-09) step Surface ... Level 4; Overview is reached only by clicking it. No button is ever disabled: a level with
## no way in yet still selects, and says so in its accessible name and tooltip.
##
## Game UI: it owns no view. The host maps a chosen level onto its own view (`level_chosen`) and tells the bar what
## it shows (`set_level`) and which levels have a way in (`set_reachable`). Pure presentation; no game state.

const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const ThemeResource: Theme = preload("res://ui/theme/woodland_theme.tres")

const LEVEL_SURFACE: int = 0
const LEVEL_DEEPEST: int = 4
const LEVEL_OVERVIEW: int = 5
const LEVEL_COUNT: int = 6
const FULL_NAMES: Array[String] = ["Surface", "Underground level 1", "Underground level 2", "Underground level 3",
	"Underground level 4", "Overview, all levels"]
const SHORT_NAMES: Array[String] = ["Surface", "Level 1", "Level 2", "Level 3", "Level 4", "Overview"]
const NARROW_NAMES: Array[String] = ["Surf.", "L1", "L2", "L3", "L4", "All"]
const OPEN_WORDS: String = "way in open"
const NO_WAY_IN: String = "no way in yet"
const VIEWING: String = "Levels; viewing %s"
const FONT_PX: int = 14

## A level button was clicked or stepped to: the host shows `level` (LEVEL_*).
signal level_chosen(level: int)

var _frame: Panel = null
var _buttons: Array[Button] = []
var _level: int = LEVEL_SURFACE
## The last level stepped from (Overview steps from here).
var _last_plain: int = LEVEL_SURFACE
var _reachable: PackedByteArray = PackedByteArray([1, 1, 1, 1, 1, 1])
var _profile: int = UiLayout.PROFILE_STANDARD
var _bar: Rect2 = Rect2()


func _init() -> void:
	"""Named; the bar never takes the mouse outside its own frame."""
	name = "LevelBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	"""The frame and its six toggles (also off-tree, for checks)."""
	if _frame != null:
		return
	theme = ThemeResource
	_frame = Panel.new()
	_frame.name = "UI-BUILD-013"
	_frame.theme_type_variation = &"WoodlandPanel"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_frame)
	for level: int in LEVEL_COUNT:
		var button: Button = Button.new()
		button.name = "UI-BUILD-014-%d" % level
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.theme_type_variation = &"WoodlandToggle"
		button.add_theme_font_size_override(&"font_size", FONT_PX)
		button.pressed.connect(choose.bind(level))
		_frame.add_child(button)
		_buttons.append(button)
	_sync()


static func level_name(level: int) -> String:
	"""A level's full name ("Underground level 2"), "" for none."""
	return FULL_NAMES[level] if level >= 0 and level < LEVEL_COUNT else ""


static func is_level(level: int) -> bool:
	"""Whether `level` is one of the bar's six."""
	return level >= LEVEL_SURFACE and level < LEVEL_COUNT


func place(geometry: UiLayout.Geometry, minimap_shown: bool) -> void:
	"""Lay the bar out at the HUD's scale for this geometry (build_layout.gd's equations, logical px)."""
	build()
	_profile = geometry.profile
	_bar = BuildLayout.level_bar_rect(geometry, minimap_shown)
	scale = Vector2(geometry.scale, geometry.scale)
	position = Vector2.ZERO
	size = Vector2(geometry.logical_width, geometry.logical_height)
	_frame.position = _bar.position
	_frame.size = _bar.size
	for level: int in LEVEL_COUNT:
		var cell: Rect2 = BuildLayout.level_button_rect(_bar, level, _profile)
		_buttons[level].position = cell.position
		_buttons[level].size = cell.size
		_buttons[level].custom_minimum_size = cell.size
	_sync()


func set_level(level: int) -> void:
	"""Show `level` as the one selected (the host's view moved); emits nothing."""
	if not is_level(level):
		return
	_level = level
	if level != LEVEL_OVERVIEW:
		_last_plain = level
	_sync()


func shown_level() -> int:
	"""The level selected."""
	return _level


func choose(level: int) -> void:
	"""Select `level` and ask the host to show it (a click, or a step)."""
	if not is_level(level):
		return
	set_level(level)
	level_chosen.emit(level)


func step_target(by: int) -> int:
	"""The level a PageDown (+1, deeper) or PageUp (-1) from here goes to: Surface ... Level 4, clamped; from Overview,
	from the level shown before it. Overview is never a step's target."""
	var from: int = _last_plain if _level == LEVEL_OVERVIEW else _level
	return clampi(from + by, LEVEL_SURFACE, LEVEL_DEEPEST)


func step(by: int) -> bool:
	"""PageUp (-1) or PageDown (+1): choose the next level; false at an end (no level above the surface, none below
	level 4), where nothing changes."""
	var to: int = step_target(by)
	var from: int = _last_plain if _level == LEVEL_OVERVIEW else _level
	if to == from and _level != LEVEL_OVERVIEW:
		return false
	choose(to)
	return true


func set_reachable(level: int, reachable: bool) -> void:
	"""Whether `level` has a way in; one without reads "no way in yet" (never disabled)."""
	if is_level(level):
		_reachable[level] = 1 if reachable else 0
		_sync()


func is_reachable(level: int) -> bool:
	"""Whether `level` has a way in, as the host last said."""
	return is_level(level) and _reachable[level] == 1


func button_name(level: int) -> String:
	"""UI-BUILD-014's accessible name: the full name and its access state."""
	return "%s; %s" % [level_name(level), OPEN_WORDS if is_reachable(level) else NO_WAY_IN]


func accessible_text() -> String:
	"""UI-BUILD-013's accessible name: "Levels; viewing Underground level 1"."""
	return VIEWING % level_name(_level)


func level_button(level: int) -> Button:
	"""Level `level`'s button (null before build)."""
	return _buttons[level] if level >= 0 and level < _buttons.size() else null


func frame_rect() -> Rect2:
	"""Where the bar stands, logical px."""
	return _bar


func screen_rect() -> Rect2:
	"""Where the bar is drawn, viewport px."""
	return Rect2(_bar.position * scale, _bar.size * scale)


func _sync() -> void:
	"""Labels for the profile, the selected toggle, and every accessible name and tooltip."""
	if _frame == null:
		return
	_frame.accessibility_name = accessible_text()
	var names: Array[String] = NARROW_NAMES if _profile == UiLayout.PROFILE_NARROW else SHORT_NAMES
	for level: int in LEVEL_COUNT:
		var button: Button = _buttons[level]
		button.text = names[level]
		button.set_pressed_no_signal(level == _level)
		button.accessibility_name = button_name(level)
		button.tooltip_text = button_name(level)
