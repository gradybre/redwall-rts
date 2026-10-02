extends CanvasLayer
## THE VILLAGE GUIDE (decision 0481): one modal window behind the HUD's Objectives command (UI-SET-033, O), the guide
## card's Help, the game menu's guide row and the Demo Lab's "Practice stories". Six tabs:
##   * OBJECTIVES  the four first-village objectives, each done, current (with its cause or blocker) or ahead;
##                 Show / Hide the guide card (skip and reopen: nothing granted or lost); the Charter's line;
##   * GOALS       the GDD's milestones and the village goals, for play after the guide (demo/goals/, decision 0781);
##   * PROJECTS    up to three player-named projects (projects_page.gd);
##   * FIELD GUIDE the almanac of what the demo has (field_guide_page.gd);
##   * HELP        the searchable help (help_page.gd, as the game menu's);
##   * PRACTICE    the practice stories (practice_page.gd), kept apart from the village.
## The header's "Chronicle" closes the guide and opens the village chronicle's book (decision 0631; hidden until set).
## A modal (demo_input_gate.gd): a scrim, focus trapped, Esc or O or × closes it. While open it holds the clock's MENU
## pause reason, as the game menu does, so the village waits (and a story's run cannot race it); closing releases only
## that. In the village the hold goes through the pause ledger (`hold_pause`: demo/session/pause_ledger.gd `hold_guide`,
## decision 0471), so closing the guide never lifts the menu's, a planning or a critical pause. DEMO UI in the woodland
## skin.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const GuideUi := preload("res://demo/guide/guide_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const HelpPageScript := preload("res://demo/guide/help_page.gd")
const FieldPageScript := preload("res://demo/guide/field_guide_page.gd")
const PracticePageScript := preload("res://demo/guide/practice_page.gd")
const ProjectsPageScript := preload("res://demo/guide/projects_page.gd")
const GoalsPageScript := preload("res://demo/goals/goals_page.gd")

const TAB_OBJECTIVES: int = 0
const TAB_GOALS: int = 1
const TAB_PROJECTS: int = 2
const TAB_FIELD_GUIDE: int = 3
const TAB_HELP: int = 4
const TAB_PRACTICE: int = 5
const TAB_NAMES: Array[String] = ["Objectives", "Goals", "Projects", "Field guide", "Help", "Practice"]
const LAYER: int = 2
const WIDTH: float = 680.0
## The pages scroll within the modal rectangle less this (title, tabs, margins).
const RESERVE_H: float = 170.0
const SCROLLBAR_W: float = 18.0
const TITLE: String = "Village guide"
const CLOSE_TEXT: String = "× Close (Esc)"
const PAUSED_LINE: String = "The village waits while the guide is open."
const CHARTER_LINE: String = "The Hearth Charter -- the village's long-term goal, set by its own community -- is beyond this demo; these first objectives are the demo's."
const GOALS_TEXT: String = "Goals for after the guide"

var help: HelpPageScript = HelpPageScript.new()
var field_guide: FieldPageScript = FieldPageScript.new()
var practice: PracticePageScript = PracticePageScript.new()
var projects: ProjectsPageScript = ProjectsPageScript.new()
var goals: GoalsPageScript = GoalsPageScript.new()
## `objective_lines() -> PackedStringArray` (the guide's four lines), `guide_hidden() -> bool`, `toggle_guide()`.
var objective_lines: Callable = Callable()
var guide_hidden: Callable = Callable()
var toggle_guide: Callable = Callable()

## `(held: bool) -> bool`: hold the MENU pause through the host's pause ledger (unset: on the clock directly).
var hold_pause: Callable = Callable()
## What the header's "Chronicle" opens once the guide has closed: the village chronicle (decision 0631; unset: hidden).
var _open_chronicle: Callable = Callable()
var _chronicle_button: Button = null

var _manager: GameManagerScript = null
var _holding: bool = false
var _frame: PanelContainer = null
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _objectives: VBoxContainer = null
var _objective_labels: Array[Label] = []
var _guide_toggle: Button = null
var _scroll: ScrollContainer = null
var _close: Button = null
var _tab: int = TAB_OBJECTIVES
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func _init() -> void:
	"""Built hidden, above the HUD."""
	name = "GuideWindow"
	layer = LAYER
	visible = false
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_frame.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title: Label = FarmUi.label(TITLE, FarmUi.TITLE_PX, Palette.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_chronicle_button = FarmUi.button("Chronicle", FarmUi.SMALL_PX)
	_chronicle_button.tooltip_text = "The village chronicle: a page for each season, from what the village recorded"
	_chronicle_button.visible = false
	_chronicle_button.pressed.connect(_on_chronicle)
	head.add_child(_chronicle_button)
	_close = FarmUi.button(CLOSE_TEXT, FarmUi.SMALL_PX)
	_close.pressed.connect(close)
	head.add_child(_close)
	column.add_child(FarmUi.label(PAUSED_LINE, FarmUi.SMALL_PX, Palette.UMBER))
	_build_tabs(column)
	_build_pages(column)
	show_tab(TAB_OBJECTIVES)


func _build_tabs(column: VBoxContainer) -> void:
	"""One toggle button a tab."""
	var row: HFlowContainer = GuideUi.row(6)
	column.add_child(row)
	for k: int in TAB_NAMES.size():
		var tab_choice: Button = FarmUi.button(TAB_NAMES[k], FarmUi.BODY_PX)
		tab_choice.toggle_mode = true
		tab_choice.pressed.connect(show_tab.bind(k))
		row.add_child(tab_choice)
		_tabs.append(tab_choice)


func _build_pages(column: VBoxContainer) -> void:
	"""The objectives page and the five others, one shown at a time."""
	_objectives = _build_objectives()
	for page: Control in [_objectives, goals, projects, field_guide, help, practice]:
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pages.append(page)
	var parts: Array = GuideUi.scroll_column(8)
	_scroll = parts[0]
	column.add_child(_scroll)
	for page: Control in [_objectives, goals, projects, practice]:
		(parts[1] as VBoxContainer).add_child(page)
	for page: Control in [field_guide, help]:
		column.add_child(page)


func _build_objectives() -> VBoxContainer:
	"""Four objective lines, the card's Show / Hide, the Charter's line and the way to the goals."""
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 6)
	for k: int in 4:
		var line: Label = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
		page.add_child(line)
		_objective_labels.append(line)
	_guide_toggle = FarmUi.button("", FarmUi.BODY_PX)
	_guide_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_guide_toggle.pressed.connect(func() -> void:
		if toggle_guide.is_valid():
			toggle_guide.call()
		refresh())
	page.add_child(_guide_toggle)
	page.add_child(FarmUi.label(CHARTER_LINE, FarmUi.SMALL_PX, Palette.UMBER))
	var to_goals: Button = FarmUi.button(GOALS_TEXT, FarmUi.BODY_PX)
	to_goals.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	to_goals.pressed.connect(show_tab.bind(TAB_GOALS))
	page.add_child(to_goals)
	return page


func set_chronicle(open_chronicle: Callable) -> void:
	"""What the header's "Chronicle" opens (decision 0631): the guide closes first, then this is called. None: hidden."""
	_open_chronicle = open_chronicle
	_chronicle_button.visible = open_chronicle.is_valid()


func _on_chronicle() -> void:
	"""Close the guide (its pause let go) and open the chronicle -- unless the clock refused the close."""
	if close() and _open_chronicle.is_valid():
		_open_chronicle.call()


func chronicle_button() -> Button:
	"""The header's "Chronicle" (checks)."""
	return _chronicle_button


func bind(manager: GameManagerScript) -> void:
	"""The clock whose MENU pause reason the window holds while open."""
	_manager = manager


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


# --- opening, closing, tabs --------------------------------------------------------------------------

func open(index: int = -1) -> void:
	"""Show the window (on `index`, else the last one) and hold the MENU pause."""
	if index >= 0:
		show_tab(index)
	if visible:
		return
	_hold(true)
	refresh()
	visible = true
	_place.call_deferred()
	GuideUi.focus_later(_first_focus())


func close() -> bool:
	"""Release the MENU pause (the village comes back at its speed) and hide the window. If the clock refuses the
	release (a load holds its barrier) the window stays open, as the game menu does, so a pause is never left with
	nothing to explain it. Returns whether it closed."""
	if not visible:
		return true
	_hold(false)
	if _holding:
		push_warning("the clock refused to release the guide's pause; the guide stays open")
		return false
	visible = false
	return true


func toggle() -> void:
	"""O: open on the last tab, or close."""
	if visible:
		close()
	else:
		open()


func show_tab(index: int) -> void:
	"""One tab's page shown; the page's first control takes focus when the window is up."""
	_tab = clampi(index, 0, TAB_NAMES.size() - 1)
	for k: int in _pages.size():
		_pages[k].visible = k == _tab
		_tabs[k].set_pressed_no_signal(k == _tab)
	_scroll.visible = _tab in [TAB_OBJECTIVES, TAB_GOALS, TAB_PROJECTS, TAB_PRACTICE]
	refresh()
	if visible and is_inside_tree():
		var first: Control = _first_focus()
		GuideUi.focus_later(first)


func _first_focus() -> Control:
	"""Where focus lands on a tab: a search field, the projects' name, the first story, else the tab itself."""
	match _tab:
		TAB_HELP: return help.field()
		TAB_FIELD_GUIDE: return field_guide.field()
		TAB_PROJECTS: return projects.name_field()
		TAB_PRACTICE: return practice.start_button(0)
	return _tabs[_tab]


func refresh() -> void:
	"""The objectives' lines and the card's Show / Hide, the projects' and the goals' figures."""
	var lines: PackedStringArray = objective_lines.call() if objective_lines.is_valid() else PackedStringArray()
	for k: int in _objective_labels.size():
		_objective_labels[k].text = lines[k] if k < lines.size() else ""
	var hidden: bool = guide_hidden.is_valid() and bool(guide_hidden.call())
	_guide_toggle.text = "Show the guide card" if hidden else "Hide the guide card"
	if _tab == TAB_PROJECTS:
		projects.refresh()
	if _tab == TAB_GOALS:
		goals.refresh()


func tab() -> int:
	"""The tab shown (TAB_*)."""
	return _tab


func is_holding_pause() -> bool:
	"""Whether the window holds the MENU pause reason now."""
	return _holding


func _hold(held: bool) -> void:
	"""Hold or release MENU once, through the host's ledger when it has one (a refused request leaves the window's
	record unchanged)."""
	if held == _holding:
		return
	if hold_pause.is_valid():
		if bool(hold_pause.call(held)):
			_holding = held
		return
	if _manager != null and _manager.set_menu_pause(held):
		_holding = held


# --- checks and the gate -----------------------------------------------------------------------------

func frame() -> PanelContainer:
	"""The carved frame (the gate's focus trap root)."""
	return _frame


func close_button() -> Button:
	"""The window's ×."""
	return _close


func tab_button(k: int) -> Button:
	"""Tab `k`'s button."""
	return _tabs[k]


func guide_toggle() -> Button:
	"""The Objectives tab's Show / Hide the guide card."""
	return _guide_toggle


func objectives_text() -> String:
	"""The objective lines (checks)."""
	var lines := PackedStringArray()
	for line: Label in _objective_labels:
		lines.append(line.text)
	return "\n".join(lines)


# --- placement ---------------------------------------------------------------------------------------

func _place() -> void:
	"""Centred in the HUD's modal rectangle at the HUD's scale; each page's list scrolls in what is left."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var zone: Rect2 = _geometry.modal
	var width: float = minf(WIDTH, zone.size.x - 2.0 * FarmUi.FRAME_EXPAND)
	var text_w: float = width - FarmUi.CONTENT_MARGINS[0] - FarmUi.CONTENT_MARGINS[2] - SCROLLBAR_W
	var list_h: float = maxf(140.0, zone.size.y - RESERVE_H)
	help.set_text_width(text_w)
	field_guide.set_text_width(text_w)
	practice.set_text_width(text_w)
	projects.set_text_width(text_w)
	goals.set_text_width(text_w)
	for label: Label in _objective_labels:
		label.custom_minimum_size.x = text_w
	help.set_list_height(list_h - 70.0)
	field_guide.set_list_height(list_h - 70.0)
	_scroll.custom_minimum_size = Vector2(0.0, list_h)
	_frame.reset_size()
	var height: float = minf(_frame.get_combined_minimum_size().y, zone.size.y - 2.0 * FarmUi.FRAME_EXPAND)
	FarmUi.place(_frame, Rect2(zone.position + Vector2((zone.size.x - width) / 2.0, FarmUi.FRAME_EXPAND),
		Vector2(width, height)), _geometry.scale)
