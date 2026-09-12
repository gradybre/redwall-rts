extends Control
## The settlement HUD: the §4 elements this milestone drives, built from the registry.
##
## Every control below is created from `ui_registry.gd`'s row -- its §4 name, its §2.2 profile,
## its minimum size and its §1.1 zone -- and then either WIRED to real state or rendered
## DISABLED with `ui_availability.gd`'s named missing owner. Nothing is drawn that looks
## operable and is not, which is task 04.4's own requirement: "The generic rendered shell cannot
## claim unbuilt panels work."
##
## ---------------------------------------------------------------------------------------
## THE CONTROLS ARE BUILT IN CODE, NOT IN A SCENE FILE, BECAUSE THE REGISTRY IS THE SOURCE.
## A `.tscn` would be a second copy of §4's sizes and names, free to drift from it. Building
## from the table means a row corrected in `ui_registry.gd` moves the real control, and
## `test_ui_shell.gd` can read the built tree back and compare it to the specification.
## `build()` is public and callable off-tree for exactly that reason: the headless runner's
## SceneTree root is not itself in the tree, so `_ready()` does not fire for an added child.
##
## ---------------------------------------------------------------------------------------
## WHAT CONSUMES A CLICK IS DECIDED HERE, ONCE. §1.2: "Full-screen HUD roots and decorative
## graphics use `MOUSE_FILTER_IGNORE`; interactive controls consume `_gui_input` events." This
## Control is itself IGNORE, the world surface overlay is IGNORE, every label and outline is
## IGNORE, and only panels and controls are STOP. `_register_hit_regions()` mirrors those exact
## filters into `ui_hit_test.gd`, so the table a test interrogates is not a second opinion about
## what the tree does -- it is read from the tree's own filters.
##
## ---------------------------------------------------------------------------------------
## NO CALLBACK HERE WRITES A STORE. Time goes to `GameManager`, which owns the clock; every
## economic action goes to `ui_command_bridge.gd` and becomes a command; world creation goes to
## `ui_world_session.gd`. There is no store reference in this file that is written to, and the
## reads are the ARCH-SYS-023 presentation snapshot and the published map masks.

const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiAvailability := preload("res://scripts/ui/ui_availability.gd")
const UiHitTest := preload("res://scripts/ui/ui_hit_test.gd")
const UiArt := preload("res://ui/ui_art.gd")
const UiFocusOrder := preload("res://scripts/ui/ui_focus_order.gd")
const UiCommandBridge := preload("res://scripts/ui/ui_command_bridge.gd")
const UiWorldSession := preload("res://scripts/ui/ui_world_session.gd")

## The one Theme the whole UI root uses, built from `ui_theme.gd`'s tokens.
const THEME_PATH: String = "res://ui/theme/woodland_theme.tres"
## Theme type variation per §2.2 profile, in registry profile order.
const PROFILE_VARIATION: Array[StringName] = [
	&"WoodlandPanel", &"WoodlandButton", &"WoodlandToggle", &"WoodlandRow", &"WoodlandField",
	&"WoodlandReadout", &"WoodlandMeter", &"WoodlandNotice", &"WoodlandOverlay", &"WoodlandModal",
]
## Original SVG icons, one per element that has a recognisable subject. §2.2 gives a disabled
## control the LOCK icon instead of its own, which is why an unavailable element never shows a
## functional glyph it cannot perform.
const ICON_DIRECTORY: String = "res://ui/icons/"
## ART-UI-03/04: the painted object family, used at wide/standard sizes. ART-UI-05 keeps the
## small functional glyphs -- lock, cancel, pause, menu, calendar -- as the optical SVGs in
## ICON_DIRECTORY, because painted artwork must never obscure a required state marker.
const PAINTED_DIRECTORY: String = "res://ui/painted/"
## ART-UI-04: NARROW keeps the simpler 16 px symbolic variants rather than shrinking painted
## detail until it becomes noise.
const SYMBOLIC_DIRECTORY: String = "res://ui/symbolic16/"
## ART-UI-01/02: each framed container wears its OWN crafted edge, so the five do not share one
## rounded outline. `ui_art.gd` owns the declared insets and per-corner extents; the renderer
## keeps the flat opaque fill underneath, which is what keeps text surfaces legible.
const FRAME_DIRECTORY: String = "res://ui/frames/"
const FRAME_OF_ZONE: Dictionary = {
	1: 0, 13: 1, 20: 2, 36: 3, 26: 4,
}
## Corner order matches `ui_art.gd`: top-left, top-right, bottom-left, bottom-right.
const CORNER_SUFFIX: Array[String] = ["tl", "tr", "bl", "br"]
const CORNER_PRESET: Array[int] = [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT,
	Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
## Edge order matches `ui_art.gd`'s inset order: top, right, bottom, left.
const EDGE_SUFFIX: Array[String] = ["top", "right", "bottom", "left"]
const EDGE_PRESET: Array[int] = [Control.PRESET_TOP_WIDE, Control.PRESET_RIGHT_WIDE,
	Control.PRESET_BOTTOM_WIDE, Control.PRESET_LEFT_WIDE]
## Painted subject per §4 element, overriding the line icon where the lock authors one.
## Food reuses the ready-food bowl and People reuses the population group, identically --
## ART-LOCK-001 gives sixteen logical rows over fourteen distinct designs.
const PAINTED_OF_ELEMENT: Dictionary = {
	2: "res_food_ready", 3: "res_fuel", 4: "res_wood", 5: "res_stone",
	6: "res_population", 7: "res_beds",
	27: "cmd_build", 28: "cmd_zone", 29: "cmd_build", 30: "res_food_ready",
	31: "res_population", 62: "cmd_zone", 66: "cmd_zone",
}
## The 16 px symbolic variant per painted subject, for NARROW.
const SYMBOLIC_OF_PAINTED: Dictionary = {
	"cmd_build": "build", "cmd_zone": "zone", "cmd_work": "work", "cmd_goals": "goals",
	"res_food_ready": "food", "res_population": "people",
}
const LOCK_ICON: String = "res://ui/icons/lock.svg"
const ORNAMENT_SPRIG: String = "res://ui/ornaments/sprig.svg"
## Icon subject per §4 element. Only elements with a recognisable subject take one, and
## there is exactly one authored set, which is how "avoid ... mixing unrelated icon packs"
## is kept.
## Controls whose §4 size leaves no room for a word beside their glyph: the icon IS the label,
## and the accessible name carries the wording.
const ICON_ONLY_ELEMENTS: Array[int] = [8, 19, 22, 93, 102]
const ICON_OF_ELEMENT: Dictionary = {
	2: "provisions", 3: "fuel", 4: "wood", 5: "stone", 6: "residents", 7: "beds",
	8: "ledger", 14: "pause", 19: "menu", 22: "map", 27: "build", 28: "brush",
	29: "build", 30: "provisions", 31: "residents", 62: "brush", 66: "brush", 67: "cancel",
	93: "cancel", 101: "calendar", 102: "ledger",
}
const ForageScript := preload("res://scripts/core/forage.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")

# --- the §4 ids this shell builds -----------------------------------------------------------------

const ID_RESOURCE_CLUSTER: int = 1
const ID_FOOD: int = 2
const ID_FUEL: int = 3
const ID_WOOD: int = 4
const ID_STONE: int = 5
const ID_POPULATION: int = 6
const ID_BEDS: int = 7
const ID_EXPAND: int = 8
const ID_LEDGER: int = 9
const ID_ALERT_STACK: int = 10
const ID_ALERT_CARD: int = 11
const ID_HISTORY: int = 12
const ID_TIME_CLUSTER: int = 13
const ID_PAUSE: int = 14
const ID_SPEED_1: int = 15
const ID_SPEED_2: int = 16
const ID_SPEED_4: int = 17
const ID_CALENDAR: int = 18
const ID_MENU: int = 19
const ID_MINIMAP_FRAME: int = 20
const ID_MINIMAP_VIEW: int = 21
const ID_MAP_LAYERS: int = 22
const ID_WORLD_SURFACE: int = 23
const ID_COMMAND_STRIP: int = 26
const ID_BUILD: int = 27
const ID_ZONE: int = 28
const ID_JOBS: int = 29
const ID_FOOD_ORDERS: int = 30
const ID_RESIDENTS: int = 31
const ID_FEAST: int = 32
const ID_OBJECTIVES: int = 33
const ID_DETAIL: int = 36
const ID_DETAIL_TITLE: int = 37
const ID_DETAIL_TABS: int = 38
const ID_NEED_ROW: int = 39
const ID_SKILL_ROW: int = 40
const ID_WORKSPACE: int = 51
const ID_ZONE_BRUSH: int = 59
const ID_STEPPER: int = 62
const ID_CONFIRM: int = 66
const ID_CANCEL: int = 67
const ID_RESIDENT_ROW: int = 69
const ID_TOOLTIP: int = 73
const ID_FOCUS_OUTLINE: int = 74
const ID_SEARCH: int = 75
const ID_NAME_EDITOR: int = 82
const ID_ERROR_PANEL: int = 85
const ID_PAUSE_LABEL: int = 86
const ID_WORLD_LIST: int = 87
const ID_ZOOM: int = 89
const ID_PITCH: int = 90
const ID_BACK: int = 92
const ID_CLOSE: int = 93
const ID_SCROLL: int = 94
const ID_QUICK_MENU: int = 96
const ID_PIN: int = 98
const ID_WORK_POLICY: int = 100
const ID_DATE: int = 101
const ID_HISTORY_TRIGGER: int = 102
const ID_NEW_SETTLEMENT: int = 103

## The six counter cells §1.2's grid holds, in its stated left-to-right, top-to-bottom order.
const COUNTER_IDS: Array[int] = [ID_FOOD, ID_FUEL, ID_WOOD, ID_STONE, ID_POPULATION, ID_BEDS]
## The words §1.1's zone map uses for those six counters: "Food Fuel Wood / Stone Residents
## Beds". The VISIBLE text is short because the cell is 104-144 px wide; the full §4 value
## binding lives in the accessible name, which is where §4 puts it.
const COUNTER_LABELS: Array[String] = ["Food", "Fuel", "Wood", "Stone", "Residents", "Beds"]
## The command strip's visible words, each the §4 row's name without the word "command".
const COMMAND_LABELS: Array[String] = ["Build", "Zone", "Jobs", "Food", "Residents", "Feast",
	"Objectives"]
## The time cluster's controls in §1.2's row order, which is also §8.2's focus order.
const TIME_IDS: Array[int] = [ID_PAUSE, ID_SPEED_1, ID_SPEED_2, ID_SPEED_4, ID_DATE, ID_MENU]
## The command strip's buttons in §4's listed order.
const COMMAND_IDS: Array[int] = [ID_BUILD, ID_ZONE, ID_JOBS, ID_FOOD_ORDERS, ID_RESIDENTS,
	ID_FEAST, ID_OBJECTIVES]
## §4's stable action key for the UI-SET-066 instance inside UI-SET-103. §4 allows repeated
## rows as "instances of a definition with stable runtime IDs"; this is one of them, which is
## why it does not take UI-SET-066's single entry in the control table.
const CREATE_ACTION_KEY: String = "create_settlement"

## §4.3's speed toggles and the speed each requests.
const SPEED_VALUES: Array[int] = [1, 2, 4]

## §1.2's interior spacing, used where §4 gives an element a size but no interior geometry.
const ROW_GAP: float = 8.0
## §1.3's 32 px minimap header, which the layer and zoom controls sit in.
const MAP_HEADER_BUTTON: float = 32.0
## §5.1's authored map, which UI-SET-021 draws and picks tiles out of.
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
## No tile has been picked. Not a tile index: tile 0 is the map's north-west corner.
const NO_TILE: int = -1
## §5's `brush_smaller`/`brush_larger` widths: "1/2/4/8-tile brush widths".
const BRUSH_SIZES: Array[int] = [1, 2, 4, 8]
const PANEL_PADDING: float = 12.0
## How strongly the decorative sprig is drawn. Sparse, so selection and focus stay prominent.
const ORNAMENT_ALPHA: float = 0.55
## The authored icon grid: 24x24 with nominal 2 px strokes.
const SEVERITY_ICON_SIZE: float = 24.0
## Resident rows this shell builds. §5.1's starting cohort is twelve; §1.3's virtualized list
## for a 256-resident roster is NOT built, and `set_roster()` says so when more exist.
const ROSTER_POOL: int = 12
## UI-SET-059's maximum height, which its three controls need to sit inside it.
const ZONE_BRUSH_HEIGHT: float = 160.0
## The three workspace pages this shell builds. §3 allows one open at a time.
## §4.1 gives UI-SET-031 as "ALWAYS; opens roster rows 069", so the roster is a PAGE of the
## workspace frame like the other three, not a column built unconditionally beside them.
## UI-SET-087 stays out of this list: F6 is its only route, which `ui_registry.gd` asserts.
const WORKSPACE_PAGES: Array[int] = [ID_NEW_SETTLEMENT, ID_WORLD_LIST, ID_NAME_EDITOR,
	UiRegistry.ROSTER_ID]
## Room the Create action has inside UI-SET-103, which is at least 480 wide by §4.
const CREATE_BUTTON_ROOM: float = 480.0
const WARNING_ICON: String = "res://ui/icons/warning.svg"

## Displayed for a counter nobody has supplied a value for. Shared with `hud.gd`.
const UNPOPULATED: String = "--"

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_BUILT: StringName = &"UI_SHELL_NOT_BUILT"
const REFUSE_UNKNOWN_ELEMENT: StringName = &"UI_SHELL_UNKNOWN_ELEMENT"
const REFUSE_NOT_WIRED: StringName = &"UI_SHELL_ELEMENT_NOT_WIRED"
const REFUSE_NO_BRIDGE: StringName = &"UI_SHELL_NO_COMMAND_BRIDGE"
const REFUSE_NO_TARGET: StringName = &"UI_SHELL_NOTHING_SELECTED"
const REFUSE_TILE_RANGE: StringName = &"UI_SHELL_TILE_OUT_OF_RANGE"
const REFUSE_TILE_NOT_ASCENDING: StringName = &"UI_SHELL_TILE_NOT_ASCENDING"
const REFUSE_STROKE_FULL: StringName = &"UI_SHELL_STROKE_FULL"
const REFUSE_NO_LAYERS: StringName = &"UI_SHELL_NO_PRESENTATION_SNAPSHOT"

## §5.5's danger bands, which a designation carries from the basin it is painted over.
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3

signal shell_action(element_id: int)
## Emitted when the player picks a tile on UI-SET-021. The shell does not resolve what lives on
## that tile: the published map is the session's, and UIManager reads it.
signal tile_picked(tile_index: int)
## Emitted when a roster row is chosen. The shell holds no residents store, so the row INDEX is
## all it can say; UIManager resolves it to a real resident reference.
signal resident_row_picked(row_index: int)

var _registry: UiRegistry = UiRegistry.new()
var _layout: UiLayout = UiLayout.new()
var _theme: UiTheme = UiTheme.new()
var _availability: UiAvailability = UiAvailability.new()
var _hits: UiHitTest = UiHitTest.new()
var _focus: UiFocusOrder = null
## The runtime facts §4's Gate column is evaluated against. Owned here because the shell is
## what knows them: selection, an in-progress stroke, and which surface is open.
var _gates: UiAvailability.Gates = null
## Scratch for `outgoing_into()`; sized once so a workspace switch allocates nothing.
var _outgoing: PackedInt32Array = PackedInt32Array()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()

## Built controls by §4 id. One entry per element this shell renders.
var _controls: Dictionary = {}
## Zone containers the geometry positions directly.
var _zones: Dictionary = {}
var _built: bool = false
var _user_scale: int = UiLayout.USER_SCALE_100
var _detail_open: bool = false
var _last_refusal: StringName = REFUSE_NONE

var _bridge: UiCommandBridge = null
var _session: UiWorldSession = null
var _presentation: PresentationExtractScript = null

## Text nodes INSIDE atomic elements. §4: "Text/icons inside an atomic element inherit its
## profile and accessible name", so these are not separate registry entries and are never
## focusable or hit-testable; they are what their owning element prints.
var _ledger_line: Label = null
var _alert_message: Label = null
var _history_line: Label = null
var _error_line: Label = null
var _calendar_line: Label = null
var _workspace_line: Label = null
var _minimap_line: Label = null
var _tooltip_line: Label = null
var _picked_tile: int = NO_TILE
var _create_button: Button = null
var _brush_size: int = 1
var _focused_element: int = 0
var _roster_rows: Array[Button] = []
var _roster_shown: int = 0
var _workspace_page: int = ID_NEW_SETTLEMENT
var _workspace_scroll: ScrollContainer = null
var _workspace_column: VBoxContainer = null
## The roster's own container. UI-SET-069's id is the first ROW's control, so the page needs a
## holder of its own: without one the page loop would toggle row 0 and leave rows 1-11 standing
## on every other page.
var _roster_panel: VBoxContainer = null

## The current selection and tool stroke. None of this is authoritative state: it is what the
## player has pointed at, and it becomes a command only when Confirm is pressed.
var _selected_basin: Vector2i = EntityDirectoryScript.NULL_REF
var _selected_basin_danger: int = DANGER_MIN
var _selected_zone: Vector2i = EntityDirectoryScript.NULL_REF
var _selected_zone_enabled: bool = false
var _selected_job: Vector2i = EntityDirectoryScript.NULL_REF
var _selected_resident: Vector2i = EntityDirectoryScript.NULL_REF
var _pending_name: String = ""
## The painted tile stroke, ascending. Sized once at the owning store's own link capacity.
var _stroke: PackedInt32Array = PackedInt32Array()
var _stroke_count: int = 0


func _init() -> void:
	"""Compose the specification tables this shell reads, and size the stroke buffer once."""
	_focus = UiFocusOrder.new(_availability)
	_gates = UiAvailability.Gates.new()
	_outgoing.resize(UiRegistry.ELEMENT_COUNT)
	_stroke.resize(ForageScript.ZONE_LINK_CAPACITY)


func _ready() -> void:
	"""Build the HUD, keep processing through pauses, and lay out for the current viewport."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _built:
		build()
	resized.connect(_on_resized)
	_apply_geometry()


func build() -> bool:
	"""Create every element this shell renders. Public so a headless test can build off-tree."""
	if _built:
		return true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = load(THEME_PATH) as Theme
	_build_world_surface()
	_build_resources()
	_build_alerts()
	_build_time()
	_build_minimap()
	_build_commands()
	_build_detail()
	_build_workspace()
	_build_overlays()
	_built = true
	_last_refusal = REFUSE_NONE
	return true


# --- construction ---------------------------------------------------------------------------------

func _new_panel(id: int, text: String) -> Panel:
	"""Create one §4 PANEL/MODAL/NOTICE element: opaque, sized from the registry, hit-testable."""
	var panel: Panel = Panel.new()
	panel.name = String(_registry.element_key(id))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.theme_type_variation = PROFILE_VARIATION[_registry.profile_of(id).value]
	panel.custom_minimum_size = _minimum_size(id)
	panel.size = panel.custom_minimum_size
	_apply_semantics(panel, id, text)
	_controls[id] = panel
	if not _availability.is_wired(id):
		var reason: Label = _new_text(panel, &"Unavailable", _availability.unavailable_label(id))
		reason.clip_text = false
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel


func _new_button(id: int, text: String) -> Button:
	"""Create one §4 BUTTON/TOGGLE element, disabled when its owning store does not exist."""
	var button: Button = Button.new()
	button.name = String(_registry.element_key(id))
	button.text = text
	button.custom_minimum_size = _minimum_size(id)
	button.clip_text = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = _registry.profile_of(id).value == UiRegistry.PROFILE_TOGGLE
	button.disabled = not _availability.is_wired(id)
	button.focus_entered.connect(_on_control_focused.bind(id))
	_style_button(button, id)
	_apply_semantics(button, id, text)
	_controls[id] = button
	return button


func _style_button(button: Button, id: int) -> void:
	"""Point a button at its §2.2 profile in the shared Theme, and give it its icon.

	No per-control stylebox is created here: the Theme at the UI root owns every colour, border
	and radius, so one edit to the tokens changes every control rather than one of them.
	§2.2's disabled rendering is "PANEL/MUTED + lock icon", so an unavailable control shows the
	LOCK instead of the glyph for an action it cannot perform.
	"""
	button.theme_type_variation = PROFILE_VARIATION[_registry.profile_of(id).value]
	if not _availability.is_wired(id):
		button.icon = load(LOCK_ICON) as Texture2D
		return
	if not ICON_OF_ELEMENT.has(id) and not PAINTED_OF_ELEMENT.has(id):
		return
	button.icon = _icon_texture_for(id)
	if ICON_ONLY_ELEMENTS.has(id):
		button.text = ""


func _icon_texture_for(id: int) -> Texture2D:
	"""The icon an element wears: painted where the lock authors one, symbolic when NARROW.

	ART-UI-04 asks for the simpler 16 px variant at narrow sizes "rather than shrinking
	intricate painted detail until it becomes noise", so the profile picks the file rather
	than the renderer scaling one asset down. An element with no painted subject keeps its
	optical line glyph, which is ART-UI-05's rule for functional state markers."""
	if PAINTED_OF_ELEMENT.has(id):
		var subject: String = PAINTED_OF_ELEMENT[id]
		if _geometry.profile == UiLayout.PROFILE_NARROW and SYMBOLIC_OF_PAINTED.has(subject):
			return load("%s%s.svg" % [SYMBOLIC_DIRECTORY, SYMBOLIC_OF_PAINTED[subject]])
		return load("%s%s.svg" % [PAINTED_DIRECTORY, subject]) as Texture2D
	return load("%s%s.svg" % [ICON_DIRECTORY, ICON_OF_ELEMENT[id]]) as Texture2D


func _add_severity_icon(owner_control: Control, icon_path: String) -> void:
	"""§7: every notice carries "severity word+icon". Colour alone never states a failure.

	The icon is decorative in the accessibility tree because the panel's own description already
	says what failed; a second announcement of the same thing is what §2.2 warns against.
	"""
	var icon: TextureRect = TextureRect.new()
	icon.name = "SeverityIcon"
	icon.texture = load(icon_path) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.focus_mode = Control.FOCUS_NONE
	icon.accessibility_name = ""
	icon.modulate = UiTheme.color_of(UiTheme.TOKEN_DANGER)
	icon.position = Vector2(PANEL_PADDING, PANEL_PADDING)
	icon.size = Vector2(SEVERITY_ICON_SIZE, SEVERITY_ICON_SIZE)
	owner_control.add_child(icon)


func _decorate(owner_control: Control) -> void:
	"""Add §-restrained sprig ornament to a panel title margin.

	Decorative only: it ignores the mouse, can never take focus, and is excluded from the
	accessibility tree, which is what the visual direction requires of every ornament.
	"""
	var sprig: TextureRect = TextureRect.new()
	sprig.name = "Ornament"
	sprig.texture = load(ORNAMENT_SPRIG) as Texture2D
	sprig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprig.focus_mode = Control.FOCUS_NONE
	sprig.accessibility_name = ""
	sprig.position = Vector2(PANEL_PADDING, PANEL_PADDING)
	sprig.modulate = Color(1.0, 1.0, 1.0, ORNAMENT_ALPHA)
	owner_control.add_child(sprig)


func _new_label(id: int, text: String) -> Label:
	"""Create one §4 READOUT or OVERLAY element that is drawn but never consumes a click."""
	var label: Label = Label.new()
	label.name = String(_registry.element_key(id))
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = _minimum_size(id)
	## UXV-032: content wraps rather than being cut. Clipping a status line is exactly the
	## "ellipsis on critical content" the requirement forbids, and it was visible at NARROW --
	## "128 x 128 tiles, s|" with the seed cut off mid-word.
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = _label_variation(id)
	_apply_semantics(label, id, text)
	_controls[id] = label
	return label


func _new_text(owner_control: Control, text_name: StringName, text: String) -> Label:
	"""Add the text inside an atomic element: drawn, never focusable, never hit-tested."""
	var label: Label = Label.new()
	label.name = text_name
	label.text = text
	## UXV-032: wrap, never clip. The alert card cut "Settlement generated: 1695 resource no|"
	## at NARROW; a player cannot act on a sentence whose end is missing.
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = PANEL_PADDING
	label.offset_top = PANEL_PADDING
	label.offset_right = -PANEL_PADDING
	label.offset_bottom = -PANEL_PADDING
	label.add_theme_color_override(&"font_color", UiTheme.color_of(UiTheme.TOKEN_TEXT))
	owner_control.add_child(label)
	return label


func _label_variation(id: int) -> StringName:
	"""The §2.2 typographic role a drawn label takes: counter, secondary or body."""
	if _registry.profile_of(id).value == UiRegistry.PROFILE_READOUT:
		return &"WoodlandCounter"
	if not _availability.is_wired(id):
		return &"WoodlandSecondary"
	return &"WoodlandBody"


func _apply_semantics(control: Control, id: int, text: String) -> void:
	"""Give a control its §4 accessible name and, when unavailable, its named missing owner.

	§2.2: "'Disabled' is spoken as state and the reason follows", and "Locked controls explain
	unlock requirements without requiring hover" -- so the reason is the accessible DESCRIPTION,
	not only a tooltip.
	"""
	control.accessibility_name = "%s %s" % [_registry.element_key(id), _registry.name_of(id)]
	if _availability.is_wired(id):
		control.accessibility_description = text
		control.tooltip_text = text
		return
	var reason: String = _availability.unavailable_label(id)
	control.accessibility_description = reason
	control.tooltip_text = reason


func _minimum_size(id: int) -> Vector2:
	"""The registry's minimum size for an element, or a zero size for a runtime-sized row."""
	var size: UiRegistry.Size = UiRegistry.Size.new()
	if not _registry.size_into(id, size):
		return Vector2.ZERO
	return Vector2(float(size.min_width), float(size.min_height))


func _preferred_size(id: int, available_width: float) -> Vector2:
	"""§4 gives every row a "minimum->maximum" size. Take the maximum when it fits.

	Clipping a label to its minimum when the container has room for its maximum turns "Paused:
	PLAYER" into "Paused: PL", which is §1.3's "never truncate warnings/costs" failure. The
	minimum is the fallback, not the default.
	"""
	var size: UiRegistry.Size = UiRegistry.Size.new()
	if not _registry.size_into(id, size):
		return Vector2.ZERO
	var width: float = float(size.min_width)
	if float(size.max_width) <= available_width:
		width = float(size.max_width)
	return Vector2(width, float(size.min_height))








func _apply_frame_art(panel: Panel, frame: int) -> void:
	"""Dress one container in its own edge and corner art. NOT WIRED -- see ADR 0074.

	THIS IS NOT CALLED. Two placement attempts put the corners outside their panels and left the
	edge strips invisible; the captures are in the evidence directory. The pieces load and draw,
	so the fault is the placement contract, not the paths: `ui_art_manifest.json` declares each
	asset's actual bounds and stretch margins, and the author of that manifest owns what they mean.
	Kept here, uncalled, so the next attempt starts from the shape rather than from nothing.

	Four corners at their declared extents and four edges stretched along their own axis --
	not one texture scaled, which would distort a binding seam and a page edge alike. The
	journal is why the corner extent is per corner: its spine cap is 12x16 and its fore-edge
	corner 14x14, and one averaged number would misplace both.

	Every piece is decorative under ART-UI-07: mouse filter IGNORE, no focus, and no
	accessibility name, so ornament can never take a click or a tab stop from a control.
	"""
	var key: String = String(UiArt.FRAME_KEYS[frame])
	var holder: Control = Control.new()
	holder.name = "FrameArt"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.focus_mode = Control.FOCUS_NONE
	panel.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for corner: int in 4:
		var extent: Vector2i = UiArt.frame_corner_size(frame, corner)
		_add_frame_piece(holder, "%s%s/%s_corner_%s.svg" % [FRAME_DIRECTORY, key, key,
			CORNER_SUFFIX[corner]], CORNER_PRESET[corner], Vector2(extent))
	for side: int in 4:
		var inset: int = UiArt.frame_edge_inset(frame, side)
		_add_frame_piece(holder, "%s%s/%s_edge_%s.svg" % [FRAME_DIRECTORY, key, key,
			EDGE_SUFFIX[side]], EDGE_PRESET[side], Vector2(float(inset), float(inset)))


func _add_frame_piece(holder: Control, path: String, preset: int, extent: Vector2) -> void:
	"""One corner or edge of a frame, anchored to the side it belongs to."""
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	var piece: NinePatchRect = NinePatchRect.new()
	piece.texture = texture
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.focus_mode = Control.FOCUS_NONE
	piece.custom_minimum_size = extent
	holder.add_child(piece)
	## Anchors AND offsets, in MINSIZE mode. Setting anchors alone and then assigning `size`
	## leaves the offsets at zero, which put every corner outside its own panel -- visible in
	## the first capture as brackets floating past the tray and the folio.
	piece.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)


func _zone_panel(id: int, text: String) -> Panel:
	"""Create a zone container and record it for the geometry pass to position."""
	var panel: Panel = _new_panel(id, text)
	_zones[id] = panel
	add_child(panel)
	return panel


# --- the zones ------------------------------------------------------------------------------------

func _build_world_surface() -> void:
	"""UI-SET-023: the world surface is an overlay and must never block the centre (§1.2)."""
	var surface: Control = Control.new()
	surface.name = String(_registry.element_key(ID_WORLD_SURFACE))
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_semantics(surface, ID_WORLD_SURFACE,
		"Settlement world; use the world list for keyboard navigation")
	_controls[ID_WORLD_SURFACE] = surface
	_zones[ID_WORLD_SURFACE] = surface
	add_child(surface)


func _build_resources() -> void:
	"""UI-SET-001's cluster, its six counter cells, the expander and the ledger below it."""
	var cluster: Panel = _zone_panel(ID_RESOURCE_CLUSTER, "Settlement resources")
	for index: int in COUNTER_IDS.size():
		var id: int = COUNTER_IDS[index]
		var cell: Button = _new_button(id, "%s %s" % [COUNTER_LABELS[index], UNPOPULATED])
		cell.toggle_mode = false
		cluster.add_child(cell)
	var expand: Button = _new_button(ID_EXPAND, "+")
	expand.pressed.connect(_on_expand_pressed)
	cluster.add_child(expand)
	var ledger: Panel = _zone_panel(ID_LEDGER, "Resource ledger")
	ledger.visible = false
	_ledger_line = _new_text(ledger, &"Line", "")
	var bar: VScrollBar = VScrollBar.new()
	bar.name = String(_registry.element_key(ID_SCROLL))
	bar.custom_minimum_size = _minimum_size(ID_SCROLL)
	_apply_semantics(bar, ID_SCROLL, "Scroll the resource ledger")
	_controls[ID_SCROLL] = bar
	ledger.add_child(bar)


func _build_alerts() -> void:
	"""UI-SET-010's stack, its card, the history trigger in its rail and the history panel."""
	var stack: Panel = _zone_panel(ID_ALERT_STACK, "Active settlement alerts")
	var card: Panel = _new_panel(ID_ALERT_CARD, "")
	stack.add_child(card)
	_alert_message = _new_text(card, &"Message", "")
	var trigger: Button = _new_button(ID_HISTORY_TRIGGER, "N")
	trigger.pressed.connect(_on_history_pressed)
	stack.add_child(trigger)
	var history: Panel = _zone_panel(ID_HISTORY, "Notification history, 0 entries")
	history.visible = false
	_history_line = _new_text(history, &"Line", "")
	var error: Panel = _zone_panel(ID_ERROR_PANEL, "")
	error.visible = false
	_add_severity_icon(error, WARNING_ICON)
	_error_line = _new_text(error, &"Line", "")
	_error_line.offset_left = PANEL_PADDING + SEVERITY_ICON_SIZE + ROW_GAP
	var pause_label: Label = _new_label(ID_PAUSE_LABEL, "")
	_zones[ID_PAUSE_LABEL] = pause_label
	add_child(pause_label)


func _build_time() -> void:
	"""UI-SET-013's cluster: pause, the three speeds, the date trigger and the menu button."""
	var cluster: Panel = _zone_panel(ID_TIME_CLUSTER, "Time and season")
	var pause: Button = _new_button(ID_PAUSE, "Pause")
	pause.pressed.connect(_on_pause_pressed)
	cluster.add_child(pause)
	for index: int in SPEED_VALUES.size():
		var speed: Button = _new_button(TIME_IDS[index + 1], "%dx" % SPEED_VALUES[index])
		speed.pressed.connect(_on_speed_pressed.bind(SPEED_VALUES[index]))
		cluster.add_child(speed)
	var date: Button = _new_button(ID_DATE, UNPOPULATED)
	date.pressed.connect(_on_calendar_pressed)
	cluster.add_child(date)
	var menu: Button = _new_button(ID_MENU, "=")
	menu.pressed.connect(_on_menu_pressed)
	cluster.add_child(menu)
	var calendar: Panel = _zone_panel(ID_CALENDAR, "Calendar")
	calendar.visible = false
	_calendar_line = _new_text(calendar, &"Line", "")
	calendar.add_child(_new_label(ID_PITCH, "Camera pitch"))


func _build_minimap() -> void:
	"""UI-SET-020's frame, the map inside it, the layer toggle and the camera controls."""
	var frame: Panel = _zone_panel(ID_MINIMAP_FRAME, "Settlement minimap")
	var layers: Button = _new_button(ID_MAP_LAYERS, "L")
	layers.pressed.connect(_on_layers_pressed)
	frame.add_child(layers)
	var zoom: Button = _new_button(ID_ZOOM, "+/-")
	zoom.pressed.connect(_on_zoom_pressed)
	frame.add_child(zoom)
	var view: Panel = _new_panel(ID_MINIMAP_VIEW, "Map. Enter to move camera.")
	view.gui_input.connect(_on_minimap_input)
	frame.add_child(view)
	_minimap_line = _new_text(view, &"Line", "No world generated yet")



func _build_commands() -> void:
	"""UI-SET-026's strip and its seven command buttons, in §4's listed order."""
	var strip: Panel = _zone_panel(ID_COMMAND_STRIP, "Commands for the settlement")
	for index: int in COMMAND_IDS.size():
		var id: int = COMMAND_IDS[index]
		var button: Button = _new_button(id, COMMAND_LABELS[index])
		if id == ID_ZONE:
			button.pressed.connect(_on_zone_tool_pressed)
		elif id == ID_RESIDENTS:
			button.pressed.connect(_on_residents_pressed)
		strip.add_child(button)
	var brush: Panel = _zone_panel(ID_ZONE_BRUSH, "Zone brush")
	brush.visible = false
	var stepper: Button = _new_button(ID_STEPPER, "Brush 1")
	stepper.pressed.connect(_on_brush_size_pressed)
	brush.add_child(stepper)
	var confirm: Button = _new_button(ID_CONFIRM, "Designate zone")
	confirm.pressed.connect(_on_confirm_pressed)
	brush.add_child(confirm)
	var cancel: Button = _new_button(ID_CANCEL, "Cancel")
	cancel.pressed.connect(_on_cancel_pressed)
	brush.add_child(cancel)


func _build_detail() -> void:
	"""UI-SET-036's detail panel: title, tabs, need and skill rows, policy toggle and close."""
	var detail: Panel = _zone_panel(ID_DETAIL, "Details")
	detail.visible = false
	_decorate(detail)
	detail.add_child(_new_label(ID_DETAIL_TITLE, "Nothing selected"))
	detail.add_child(_new_button(ID_DETAIL_TABS, "Overview"))
	detail.add_child(_new_label(ID_NEED_ROW, ""))
	detail.add_child(_new_label(ID_SKILL_ROW, ""))
	var policy: Button = _new_button(ID_WORK_POLICY, "Harvesting enabled")
	policy.pressed.connect(_on_work_policy_pressed)
	detail.add_child(policy)
	var pin: Button = _new_button(ID_PIN, "Name")
	pin.pressed.connect(_on_pin_pressed)
	detail.add_child(pin)
	var close: Button = _new_button(ID_CLOSE, "x")
	close.pressed.connect(_on_close_pressed)
	detail.add_child(close)


func _build_workspace() -> void:
	"""UI-SET-051's frame: a scrolling content column above a fixed action footer.

	§1.3: "Long inventories/rosters: Virtualized rows,44 px base height" and "Large text: Scroll
	panels vertically; fixed bottom confirmation row". A roster of twelve already overflows the
	frame, so the content scrolls and the footer does not move with it.
	"""
	var frame: Panel = _zone_panel(ID_WORKSPACE, "Workspace")
	frame.visible = false
	frame.clip_contents = true
	_decorate(frame)
	_workspace_scroll = ScrollContainer.new()
	_workspace_scroll.name = "Scroll"
	_workspace_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_workspace_scroll)
	_workspace_column = VBoxContainer.new()
	_workspace_column.name = "Content"
	_workspace_column.add_theme_constant_override(&"separation", int(ROW_GAP))
	_workspace_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_scroll.add_child(_workspace_column)
	_workspace_column.add_child(_new_label(ID_SEARCH, ""))
	var new_world: Panel = _new_panel(ID_NEW_SETTLEMENT, "Create a settlement")
	_workspace_column.add_child(new_world)
	_build_create_action(new_world)
	_workspace_column.add_child(_new_panel(ID_WORLD_LIST, "World locations and entities"))
	_workspace_column.add_child(_new_panel(ID_NAME_EDITOR, "Name this notable resident"))
	_build_roster(_workspace_column)
	var back: Button = _new_button(ID_BACK, "Back")
	back.pressed.connect(_on_back_pressed)
	frame.add_child(back)
	var bar: VScrollBar = _workspace_scroll.get_v_scroll_bar()
	bar.custom_minimum_size = _minimum_size(ID_SCROLL)
	_apply_semantics(bar, ID_SCROLL, "Scroll the workspace")
	_controls[ID_SCROLL] = bar


func _build_create_action(new_world: Panel) -> void:
	"""UI-SET-103's Create: a UI-SET-066 instance with the stable `create_settlement` key."""
	_workspace_line = _new_text(new_world, &"Line", "")
	_create_button = Button.new()
	_create_button.name = "%s/%s" % [_registry.element_key(ID_CONFIRM), CREATE_ACTION_KEY]
	_create_button.text = "Create settlement"
	_create_button.clip_text = true
	_create_button.custom_minimum_size = _preferred_size(ID_CONFIRM, CREATE_BUTTON_ROOM)
	_create_button.focus_mode = Control.FOCUS_ALL
	_create_button.theme_type_variation = PROFILE_VARIATION[UiRegistry.PROFILE_BUTTON]
	_create_button.position = Vector2(PANEL_PADDING, PANEL_PADDING * 3.0)
	_create_button.accessibility_name = "%s Create a settlement" % _registry.element_key(ID_CONFIRM)
	_create_button.accessibility_description = \
		"Create the authored estuary refuge and open it paused"
	_create_button.pressed.connect(_on_create_pressed)
	new_world.add_child(_create_button)


func _show_open_page() -> void:
	"""Show exactly the open workspace page and hide the others.

	§3: "Only one primary management workspace open". Called from `open_workspace_page()` as
	well as from the layout pass, because which page is open is not a geometry question --
	`_apply_geometry()` refuses when the canvas has no size, and page visibility must not
	depend on whether a layout happened to succeed."""
	for id: int in WORKSPACE_PAGES:
		_page_control_of(id).visible = id == _workspace_page


func _page_control_of(page_id: int) -> Control:
	"""The Control that IS one workspace page.

	UI-SET-069 is the exception: its element id belongs to a roster ROW, not to a container,
	so the page is `_roster_panel` and toggling `_controls[69]` would show one row and leave
	the other eleven visible underneath every other page."""
	if page_id == UiRegistry.ROSTER_ID:
		return _roster_panel
	return _controls[page_id] as Control


func _build_roster(column: VBoxContainer) -> void:
	"""UI-SET-069's rows: one real resident each, up to the pool this shell builds.

	§1.3 requires a VIRTUALIZED list for a roster that can reach 256. This pool is fixed at
	ROSTER_POOL rows and the panel says so when more residents exist than it can show, rather
	than silently listing a prefix as though it were everybody.
	"""
	_roster_panel = VBoxContainer.new()
	_roster_panel.name = "%s/Rows" % _registry.element_key(ID_RESIDENT_ROW)
	_roster_panel.add_theme_constant_override(&"separation", int(ROW_GAP))
	_roster_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_roster_panel)
	var first: Button = _new_button(ID_RESIDENT_ROW, "")
	first.pressed.connect(_on_resident_row_pressed.bind(0))
	_roster_panel.add_child(first)
	_roster_rows.append(first)
	for index: int in range(1, ROSTER_POOL):
		var row: Button = Button.new()
		row.name = "%s/%d" % [_registry.element_key(ID_RESIDENT_ROW), index]
		row.clip_text = true
		row.custom_minimum_size = _minimum_size(ID_RESIDENT_ROW)
		row.focus_mode = Control.FOCUS_ALL
		row.theme_type_variation = PROFILE_VARIATION[UiRegistry.PROFILE_ROW]
		row.accessibility_name = "%s resident row %d" % [_registry.element_key(ID_RESIDENT_ROW),
			index + 1]
		row.pressed.connect(_on_resident_row_pressed.bind(index))
		_roster_panel.add_child(row)
		_roster_rows.append(row)
	_set_roster_visible(0)


func set_roster(labels: PackedStringArray, total_living: int) -> void:
	"""Fill UI-SET-069's rows from the residents store, and state what is not shown.

	The caller owns the store; this prints what it was given, in order, and nothing else.
	"""
	var shown: int = mini(labels.size(), ROSTER_POOL)
	for index: int in shown:
		_roster_rows[index].text = labels[index]
		_roster_rows[index].accessibility_description = labels[index]
	_set_roster_visible(shown)
	var frame: Panel = _controls[ID_WORKSPACE] as Panel
	frame.accessibility_description = "Residents: showing %d of %d" % [shown, total_living]
	if total_living > ROSTER_POOL:
		frame.accessibility_description += "; the virtualized list for 256 is not built"
	_apply_geometry()


func _set_roster_visible(shown: int) -> void:
	"""Show exactly `shown` roster rows and hide the rest of the pool."""
	for index: int in _roster_rows.size():
		_roster_rows[index].visible = index < shown
	_roster_shown = shown


func roster_shown() -> int:
	"""How many resident rows are currently filled and visible."""
	return _roster_shown


func roster_row(index: int) -> Button:
	"""One resident row control, or null for an index outside the built pool."""
	if index < 0 or index >= _roster_rows.size():
		_refuse(REFUSE_UNKNOWN_ELEMENT)
		return null
	_last_refusal = REFUSE_NONE
	return _roster_rows[index]


func _on_resident_row_pressed(index: int) -> void:
	"""A roster row was chosen. Resolving which resident that is belongs to the store's owner."""
	if index >= _roster_shown:
		return
	resident_row_picked.emit(index)


func _build_overlays() -> void:
	"""The three overlays §3 puts above the HUD, none of which may consume a click."""
	var tooltip: Panel = _new_panel(ID_TOOLTIP, "")
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	add_child(tooltip)
	_tooltip_line = _new_text(tooltip, &"Line", "")
	add_child(_new_label(ID_FOCUS_OUTLINE, ""))
	var quick: Panel = _zone_panel(ID_QUICK_MENU, "Actions for the selected job")
	quick.visible = false


# --- geometry -------------------------------------------------------------------------------------

func _on_control_focused(id: int) -> void:
	"""§2.2: a focused control shows its description at 0 ms and takes the GOLD focus outline.

	"Tooltips wait 350 ms pointer hover or 0 ms keyboard focus" -- the pointer half is Godot's
	own tooltip from `tooltip_text`; this is the keyboard half, plus UI-SET-074's outline, which
	"is never hidden by selected state".
	"""
	var control: Control = _controls[id]
	var tooltip: Panel = _controls[ID_TOOLTIP] as Panel
	_tooltip_line.text = control.tooltip_text
	tooltip.visible = not _tooltip_line.text.is_empty()
	var rect: Rect2 = _shell_rect_of(control).grow(float(UiTheme.FOCUS_OUTLINE_OFFSET))
	var outline: Label = _controls[ID_FOCUS_OUTLINE] as Label
	_set_rect(outline, rect)
	outline.visible = true
	_set_rect(tooltip, Rect2(rect.position + Vector2(0.0, rect.size.y + ROW_GAP),
		Vector2(rect.size.x, MAP_HEADER_BUTTON)))
	_focused_element = id


func focused_element() -> int:
	"""The §4 id of the control that last took keyboard focus, or 0 when none has."""
	return _focused_element


func _on_resized() -> void:
	"""Recompute every rectangle when the viewport changes (§1.3's resize rule)."""
	_apply_geometry()


func apply_user_scale(percent: int) -> bool:
	"""Set §8.1's `ui_scale` and relay out. Refuses a value §1.2 does not define."""
	if not UiLayout.is_user_scale(percent):
		return _refuse(UiLayout.REFUSE_USER_SCALE)
	_user_scale = percent
	_apply_geometry()
	return true


func layout_for(width: int, height: int) -> bool:
	"""Lay the HUD out for an explicit viewport size. Used by the headless suite."""
	if not _layout.compute_into(width, height, _user_scale, _detail_open, _geometry):
		return _refuse(_layout.last_refusal())
	_place_zones()
	_apply_scale_transform()
	_register_hit_regions()
	_wire_focus()
	_last_refusal = REFUSE_NONE
	return true


func _apply_scale_transform() -> void:
	"""Draw the logical layout at the user's scale. UI 1.2's second half.

	The geometry is computed against W/S by H/S, so at 150% a 1280x720 window lays out as
	853x480 -- correct, and invisible without this. The engine's own base stretching is
	DISABLED in project.godot precisely so this transform is the only one: Astra's ruling is
	"do not apply both engine base stretching and the spec's scale". Scaling the shell rather
	than the window keeps the 3D render at its own resolution, which is the rest of that rule.
	"""
	var factor: float = float(_user_scale) / 100.0
	scale = Vector2(factor, factor)


func _apply_geometry() -> void:
	"""Lay out for the canvas this shell is drawn into, keeping the last layout if it refuses.

	THE SIZE USED HERE IS THE CANVAS SIZE, NOT THE WINDOW SIZE, AND AT PRESENT THOSE DIFFER.
	`project.godot` sets `window/stretch/mode="canvas_items"` against a 1920x1080 base, so a
	1280x720 window gives this Control a 1920x1080 rectangle and scales the whole canvas by
	0.667 -- measured, not assumed: the shell reports profile WIDE in a 1280x720 window.
	§1.2 says the opposite: "Do not scale the entire game through a low-resolution pixel
	viewport ... retain crisp fonts and explicit logical layout", and its own equations would
	give Lw 1280 and the STANDARD profile there.
	Laying out against the window size instead would be worse, not better: the rectangles would
	then be scaled a second time by the same stretch transform. The fix belongs in
	`project.godot`, which the integration lead owns, and is reported rather than worked around.
	"""
	var viewport: Vector2 = size
	if not is_inside_tree() or viewport.x <= 0.0:
		return
	layout_for(int(viewport.x), int(viewport.y))


func _place_zones() -> void:
	"""Move every zone container onto its §1.2 rectangle, then lay out its children."""
	_place(ID_WORLD_SURFACE, Rect2(0.0, 0.0, _geometry.logical_width, _geometry.logical_height))
	_place(ID_RESOURCE_CLUSTER, _geometry.resources)
	_place(ID_LEDGER, Rect2(_geometry.resources.position
		+ Vector2(0.0, _geometry.resources.size.y + ROW_GAP), _minimum_size(ID_LEDGER)))
	_place(ID_ALERT_STACK, _geometry.alerts)
	var below_alerts: Vector2 = _geometry.alerts.position \
		+ Vector2(0.0, _geometry.alerts.size.y + ROW_GAP)
	_place(ID_PAUSE_LABEL, Rect2(below_alerts,
		_preferred_size(ID_PAUSE_LABEL, _geometry.alerts.size.x)))
	var below_pause: Vector2 = below_alerts \
		+ Vector2(0.0, _minimum_size(ID_PAUSE_LABEL).y + ROW_GAP)
	_place(ID_ERROR_PANEL, Rect2(below_pause, _minimum_size(ID_ERROR_PANEL)))
	_place(ID_HISTORY, Rect2(below_pause
		+ Vector2(0.0, _minimum_size(ID_ERROR_PANEL).y + ROW_GAP), _minimum_size(ID_HISTORY)))
	_place(ID_TIME_CLUSTER, _geometry.time)
	_place(ID_CALENDAR, Rect2(_geometry.time.position
		+ Vector2(0.0, _geometry.time.size.y + ROW_GAP), _minimum_size(ID_CALENDAR)))
	_place(ID_MINIMAP_FRAME, _geometry.minimap)
	_place(ID_COMMAND_STRIP, _geometry.commands)
	var brush_size: Vector2 = Vector2(_geometry.commands.size.x, ZONE_BRUSH_HEIGHT)
	_place(ID_ZONE_BRUSH, Rect2(_geometry.commands.position
		- Vector2(0.0, brush_size.y + ROW_GAP), brush_size))
	_place(ID_DETAIL, _geometry.detail)
	_place(ID_WORKSPACE, _geometry.modal)
	_place_interiors()


func _place_interiors() -> void:
	"""Lay out the interiors §1.2 gives explicit geometry for, then the flowed panels."""
	for index: int in COUNTER_IDS.size():
		var visible_cell: bool = index < UiLayout.counter_cell_count(_geometry.profile)
		var cell: Control = _controls[COUNTER_IDS[index]]
		cell.visible = visible_cell
		if visible_cell:
			_set_rect(cell, _layout.counter_cell(_geometry.profile,
				_geometry.resources.size.x, index))
	var narrow: bool = _geometry.profile == UiLayout.PROFILE_NARROW
	(_controls[ID_EXPAND] as Control).visible = narrow
	if narrow:
		_place_local(ID_EXPAND, UiLayout.narrow_expand_rect())
	for index: int in TIME_IDS.size():
		_set_rect(_controls[TIME_IDS[index]], _layout.time_control(_geometry.profile, index))
	_place_local(ID_ALERT_CARD, _layout.alert_card(_geometry.profile, _geometry.alerts.size.x, 0))
	_place_local(ID_HISTORY_TRIGGER, UiLayout.history_trigger_rect(_geometry.alerts.size.x))
	_place_local(ID_MINIMAP_VIEW, UiLayout.minimap_content_rect(_geometry.profile))
	_wrap_children(ID_COMMAND_STRIP, COMMAND_IDS, _geometry.commands.size)
	_flow_children(ID_DETAIL, [ID_DETAIL_TITLE, ID_DETAIL_TABS, ID_NEED_ROW, ID_SKILL_ROW,
		ID_WORK_POLICY, ID_PIN, ID_CLOSE])
	_flow_workspace()
	_wrap_children(ID_ZONE_BRUSH, [ID_STEPPER, ID_CONFIRM, ID_CANCEL],
		(_controls[ID_ZONE_BRUSH] as Control).size)
	_place_local(ID_MAP_LAYERS, Rect2(UiLayout.FRAME_PADDING, 0.0, MAP_HEADER_BUTTON, MAP_HEADER_BUTTON))
	_place_local(ID_ZOOM, Rect2(UiLayout.FRAME_PADDING + MAP_HEADER_BUTTON + ROW_GAP, 0.0,
		MAP_HEADER_BUTTON, MAP_HEADER_BUTTON))
	var map_rect: Rect2 = UiLayout.minimap_content_rect(_geometry.profile)
	_place_local(ID_MINIMAP_VIEW, map_rect)
	_flow_children(ID_CALENDAR, [ID_PITCH])


func _wrap_children(owner_id: int, children: Array, owner_size: Vector2) -> void:
	"""Lay children left to right inside an owner, wrapping to a new row at its right edge.

	§1.2: "Command buttons wrap into two or three rows; excess commands live in the context quick
	menu, not outside the viewport." A child that would start below the owner is not placed at
	all -- it is hidden, which is the "not outside the viewport" half of that rule.
	"""
	var cursor: Vector2 = Vector2(PANEL_PADDING, PANEL_PADDING)
	var row_height: float = 0.0
	var available: float = owner_size.x - 2.0 * PANEL_PADDING
	for id: int in children:
		var child: Control = _controls[id]
		var preferred: Vector2 = _preferred_size(id, available)
		if cursor.x + preferred.x > owner_size.x - PANEL_PADDING and cursor.x > PANEL_PADDING:
			cursor = Vector2(PANEL_PADDING, cursor.y + row_height + ROW_GAP)
			row_height = 0.0
		child.visible = cursor.y + preferred.y <= owner_size.y - PANEL_PADDING
		_set_rect(child, Rect2(cursor, preferred))
		cursor.x += preferred.x + ROW_GAP
		row_height = maxf(row_height, preferred.y)


func _flow_workspace() -> void:
	"""Size the scrolling body and pin the footer, then show only the open page.

	§3: "Only one primary management workspace open". The three pages this shell builds are
	mutually exclusive, so the column shows exactly the one the player asked for.
	"""
	var frame: Control = _controls[ID_WORKSPACE]
	var footer: Vector2 = _preferred_size(ID_BACK, frame.size.x - 2.0 * PANEL_PADDING)
	_set_rect(_workspace_scroll, Rect2(PANEL_PADDING, PANEL_PADDING,
		frame.size.x - 2.0 * PANEL_PADDING,
		frame.size.y - footer.y - 3.0 * PANEL_PADDING))
	_workspace_column.custom_minimum_size = Vector2(_workspace_scroll.size.x, 0.0)
	_set_rect(_controls[ID_BACK], Rect2(PANEL_PADDING,
		frame.size.y - footer.y - PANEL_PADDING, footer.x, footer.y))
	_show_open_page()


func _flow_children(owner_id: int, children: Array) -> void:
	"""Stack an owner's children down its interior at their registry minimum heights.

	§4 gives these children a size but no interior coordinates -- the section only fixes the
	interiors it names in §1.2. Stacking at the panel's own 12 px padding and §1.2's 8 px grid
	is derived from those two figures rather than chosen here.
	"""
	var owner_width: float = (_controls[owner_id] as Control).size.x - 2.0 * PANEL_PADDING
	var cursor: float = PANEL_PADDING
	for id: int in children:
		var child: Control = _controls[id]
		var preferred: Vector2 = _preferred_size(id, owner_width)
		_set_rect(child, Rect2(PANEL_PADDING, cursor, preferred.x, preferred.y))
		cursor += preferred.y + ROW_GAP


func _place(id: int, rect: Rect2) -> void:
	"""Position a zone container in shell-local coordinates."""
	if not _zones.has(id):
		return
	_set_rect(_zones[id] as Control, rect)


func _place_local(id: int, rect: Rect2) -> void:
	"""Position a child inside its own parent's local coordinates."""
	if not _controls.has(id):
		return
	_set_rect(_controls[id] as Control, rect)


func _set_rect(control: Control, rect: Rect2) -> void:
	"""Apply one rectangle to a control without disturbing its anchors."""
	control.position = rect.position
	control.size = rect.size


func _wire_focus() -> int:
	"""Write the computed focus order onto the real Controls. Returns the stops wired.

	UXV-033 names "focus-list data without runtime wiring" as insufficient, and that was
	exactly the state: `ui_focus_order.gd` computed a correct order, was unit-tested, and
	NOTHING CALLED IT -- `bind_controls()` and `wire_hud()` had no call site anywhere in the
	repository. `focus_next`, `focus_previous` and the four `focus_neighbor_*` properties are
	what Godot's own Tab and arrow navigation read, so until they are written the order is a
	data structure and not a behaviour. Called from `_apply_geometry()` because the visible
	set changes with the profile, so the order must be recomputed when the layout changes."""
	_focus.bind_controls(_controls)
	return _focus.wire_hud(_gates)


func _register_hit_regions() -> void:
	"""Mirror the built tree's own mouse filters into the §1.2 click-through table.

	The `consumes` flag is READ FROM THE CONTROL, not asserted here, so the table cannot
	disagree with what the engine will actually do with the event.
	"""
	_hits.reset()
	for id: int in _controls:
		var control: Control = _controls[id]
		if not control.visible or not _is_visible_chain(control):
			continue
		var consumes: bool = control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		_hits.add_visible_region(id, _shell_rect_of(control), _layer_of(id), consumes,
			_availability.creates_control(id, _gates))
	if _workspace_page == ID_NAME_EDITOR:
		_hits.raise_scrim(UiHitTest.LAYER_MODAL)
	else:
		_hits.lower_scrim()


func _shell_rect_of(control: Control) -> Rect2:
	"""A control's rectangle in this shell's coordinates, summed from its own parent chain.

	`global_position` is not used: the headless suite builds this tree without a Window, and a
	rectangle that is only correct inside a real tree cannot be the one a test interrogates.
	"""
	var origin: Vector2 = control.position
	var node: Node = control.get_parent()
	while node != null and node != self:
		if node is Control:
			origin += (node as Control).position
		node = node.get_parent()
	return Rect2(origin, control.size)


func _is_visible_chain(control: Control) -> bool:
	"""True when a control and every ancestor up to this shell are visible."""
	var node: Node = control.get_parent()
	while node != null and node != self:
		if node is Control and not (node as Control).visible:
			return false
		node = node.get_parent()
	return true


func _layer_of(id: int) -> int:
	"""§3's layer for an element: world overlay, permanent HUD, expansion, workspace or modal."""
	if id == ID_WORLD_SURFACE:
		return UiHitTest.LAYER_WORLD_OVERLAY
	if id == ID_TOOLTIP:
		return UiHitTest.LAYER_TOOLTIP
	if id == ID_QUICK_MENU:
		return UiHitTest.LAYER_QUICK_MENU
	if id == ID_WORKSPACE or id == ID_NEW_SETTLEMENT or id == ID_WORLD_LIST \
			or id == ID_NAME_EDITOR:
		return UiHitTest.LAYER_MODAL
	if id == ID_LEDGER or id == ID_HISTORY or id == ID_CALENDAR or id == ID_DETAIL:
		return UiHitTest.LAYER_EXPANSION
	return UiHitTest.LAYER_PERMANENT_HUD


# --- bindings ---------------------------------------------------------------------------------------

func bind_bridge(bridge: UiCommandBridge) -> void:
	"""Adopt the command bridge every economic action travels through."""
	_bridge = bridge


func bind_session(session: UiWorldSession) -> void:
	"""Adopt the New Settlement session that owns world generation and its published map."""
	_session = session


# --- rendering real values -------------------------------------------------------------------------

func set_counter_display(id: int, value_text: String) -> bool:
	"""Print one counter's value verbatim. Refuses for a counter with no owning source.

	A counter whose store does not exist keeps its "Unavailable" reason: writing a value into it
	would be exactly the fabricated reading this shell exists not to produce.
	"""
	if not _controls.has(id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	if not _availability.is_wired(id):
		return _refuse(REFUSE_NOT_WIRED)
	var button: Button = _controls[id] as Button
	button.text = "%s %s" % [COUNTER_LABELS[COUNTER_IDS.find(id)], value_text]
	button.accessibility_description = button.text
	_last_refusal = REFUSE_NONE
	return true


func set_status_line(text: String) -> void:
	"""Print UI-SET-101's readout verbatim: the caller's state, speed and date line.

	The string is printed byte for byte. Reformatting a supplied figure here would put a reading
	on screen that the player cannot tell apart from one the simulation derived.
	"""
	var date: Button = _controls[ID_DATE] as Button
	date.text = text
	date.accessibility_description = "%s. Open calendar" % text


func set_speed_selected(speed: int) -> void:
	"""Show which of UI-SET-015/016/017 carries the requested speed. 0/1/2/4 only."""
	for index: int in SPEED_VALUES.size():
		var toggle: Button = _controls[TIME_IDS[index + 1]] as Button
		toggle.button_pressed = SPEED_VALUES[index] == speed


func set_pause_display(paused: bool, reasons: String) -> void:
	"""UI-SET-014's selected state and UI-SET-086's pause label, from the clock's own reasons."""
	var pause: Button = _controls[ID_PAUSE] as Button
	pause.button_pressed = paused
	pause.accessibility_description = "Paused: %s" % reasons if paused else "Resume"
	var label: Label = _controls[ID_PAUSE_LABEL] as Label
	label.text = "Paused: %s" % reasons if paused else ""
	label.visible = paused


func set_alert_display(text: String) -> void:
	"""UI-SET-011's card. An empty stack is hidden, so it "does not block world" (§4.1).

	KNOWN DEFECT, NARROW ONLY, NOT THIS FILE'S TO FIX. The message now wraps rather than
	clipping (UXV-032), and at NARROW a long generation sentence wraps to three lines and
	draws outside a card whose height `ui_layout.alert_card()` fixes -- over the pause
	line. Growing the card here does nothing: `_place_local()` re-sets its rect from the
	layout on every pass. The card must become content-sized in `ui_layout.gd`, which the
	component owner holds. Evidence: docs/validation/evidence/ui-refinement/screenshots/
	06_narrow_1280x720_150.png."""
	var card: Panel = _controls[ID_ALERT_CARD] as Panel
	card.accessibility_description = text
	card.tooltip_text = text
	card.visible = not text.is_empty()
	_alert_message.text = text
	var stack: Panel = _controls[ID_ALERT_STACK] as Panel
	stack.visible = not text.is_empty()
	_register_hit_regions()


func set_refusal_display(text: String) -> void:
	"""UI-SET-085's error panel: the exact refusal code and its plain reading, or hidden."""
	var panel: Panel = _controls[ID_ERROR_PANEL] as Panel
	panel.accessibility_description = text
	panel.tooltip_text = text
	panel.visible = not text.is_empty()
	_error_line.text = text
	_register_hit_regions()


func set_detail_display(title: String, need_text: String, skill_text: String) -> void:
	"""UI-SET-037/039/040: the selected entity's title and its need and skill rows."""
	(_controls[ID_DETAIL_TITLE] as Label).text = title
	(_controls[ID_NEED_ROW] as Label).text = need_text
	(_controls[ID_SKILL_ROW] as Label).text = skill_text


func set_detail_open(open: bool) -> void:
	"""Open or close UI-SET-036, which also changes §1.2's command-strip interval."""
	_detail_open = open
	(_zones[ID_DETAIL] as Control).visible = open
	_apply_geometry()


func set_minimap_display(text: String) -> void:
	"""UI-SET-021: what the published map actually contains, or that none is published."""
	_minimap_line.text = text


func set_ledger_display(text: String) -> void:
	"""UI-SET-009's ledger line: every counter, including the unpopulated markers.

	Printed verbatim, for the same reason `set_status_line()` is: this shell renders values, it
	never derives or reformats one.
	"""
	_ledger_line.text = text


# --- actions ------------------------------------------------------------------------------------------

func _on_pause_pressed() -> void:
	"""UI-SET-014: toggle the PLAYER pause reason through the clock's owner."""
	GameManager.toggle_pause()
	shell_action.emit(ID_PAUSE)


func _on_speed_pressed(speed: int) -> void:
	"""UI-SET-015/016/017: request 1x, 2x or 4x. Other pause reasons are untouched."""
	GameManager.set_speed(speed)
	shell_action.emit(ID_SPEED_1)


func _on_expand_pressed() -> void:
	"""UI-SET-008: toggle the resource ledger open."""
	var ledger: Control = _zones[ID_LEDGER]
	ledger.visible = not ledger.visible
	_register_hit_regions()
	shell_action.emit(ID_EXPAND)


func _on_history_pressed() -> void:
	"""UI-SET-102: open the notification history."""
	_toggle_zone(ID_HISTORY)
	shell_action.emit(ID_HISTORY_TRIGGER)


func _on_calendar_pressed() -> void:
	"""UI-SET-101: open the calendar panel."""
	_toggle_zone(ID_CALENDAR)
	shell_action.emit(ID_DATE)


func _on_menu_pressed() -> void:
	"""UI-SET-019: open the workspace frame on the New Settlement form."""
	open_workspace_page(ID_NEW_SETTLEMENT)
	shell_action.emit(ID_MENU)


func _on_minimap_input(event: InputEvent) -> void:
	"""UI-SET-021: a click on the map picks the tile under the pointer.

	This is the only pointer-driven selection this milestone has, and it needs no camera and no
	Transform store: the map is §5.1's authored 128x128 grid, so a position inside the map
	rectangle IS a tile index. A click outside a published world picks nothing.
	"""
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event == null or not button_event.pressed:
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var view: Control = _controls[ID_MINIMAP_VIEW]
	var tile: int = _tile_at(button_event.position, view.size)
	if tile < 0:
		_report_action(REFUSE_TILE_RANGE)
		return
	_picked_tile = tile
	tile_picked.emit(tile)


func _tile_at(local_position: Vector2, view_size: Vector2) -> int:
	"""The §5.1 tile index under a point inside the map rectangle, or -1 when it is outside.

	The -1 never leaves this file: `_on_minimap_input()` turns it into an explicit refusal.
	"""
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return -1
	if local_position.x < 0.0 or local_position.y < 0.0:
		return -1
	if local_position.x >= view_size.x or local_position.y >= view_size.y:
		return -1
	var tile_x: int = int(local_position.x / view_size.x * float(MAP_TILES_X))
	var tile_z: int = int(local_position.y / view_size.y * float(MAP_TILES_Z))
	return tile_z * MAP_TILES_X + tile_x


func picked_tile() -> int:
	"""The tile the player last picked on the map, or NO_TILE when none has been picked."""
	return _picked_tile


func _on_layers_pressed() -> void:
	"""UI-SET-022: hide or show ARCH-SYS-023's ecology layer.

	04.4: "hiding layers does not change truth". This toggles the PRESENTATION snapshot's layer
	visibility and nothing else -- no store, no tick and no committed value moves with it.
	"""
	shell_action.emit(ID_MAP_LAYERS)
	if _presentation == null:
		_report_action(REFUSE_NO_LAYERS)
		return
	var visible_now: bool = _presentation.is_layer_visible(PresentationExtractScript.LAYER_ECOLOGY)
	if not _presentation.set_layer_visible(PresentationExtractScript.LAYER_ECOLOGY, not visible_now):
		_report_action(_presentation.last_refusal())
		return
	_accept_action()


func bind_presentation(presentation: PresentationExtractScript) -> void:
	"""Adopt the ARCH-SYS-023 snapshot whose layers UI-SET-022 shows and hides."""
	_presentation = presentation


func ecology_layer_visible() -> bool:
	"""Whether the ecology presentation layer is currently shown. False with nothing bound."""
	if _presentation == null:
		return false
	return _presentation.is_layer_visible(PresentationExtractScript.LAYER_ECOLOGY)


func _on_zoom_pressed() -> void:
	"""UI-SET-089: camera zoom, reported to whoever owns a camera."""
	shell_action.emit(ID_ZOOM)


func _on_zone_tool_pressed() -> void:
	"""UI-SET-028: open the zone brush. No command is issued until Confirm."""
	_toggle_zone(ID_ZONE_BRUSH)
	shell_action.emit(ID_ZONE)


func _on_residents_pressed() -> void:
	"""UI-SET-031: open the ROSTER, which §4.1 line 182 gives as "ALWAYS; opens roster rows 069".

	This used to open UI-SET-087, the world-access list -- the one element `ui_availability.gd`
	marks PANEL_NOT_BUILT, so the button opened a panel that does not exist. §4.3 gates 087 on
	F6/accessible mode, and `ui_registry.gd` now asserts no element opens it, so F6 is its only
	route. The destination comes from the registry rather than a literal, so the two cannot
	disagree again."""
	open_workspace_page(UiRegistry.OPENS[ID_RESIDENTS][0])
	shell_action.emit(ID_RESIDENTS)


func open_workspace_page(page_id: int, opener_id: int = ID_RESIDENTS) -> bool:
	"""Show one workspace page, taking its opening focus and retiring the outgoing one.

	§3 allows only one primary management workspace open, so opening a second REPLACES the
	first. The router decides what that means for focus; this function's job is to act on the
	answer -- hide the members it retires and re-register the hit table, so a control that is
	no longer shown cannot keep an input rectangle."""
	if not WORKSPACE_PAGES.has(page_id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	var members: PackedInt32Array = PackedInt32Array([page_id])
	if not _focus.open_surface(page_id, members, members.size(), opener_id):
		return _refuse(REFUSE_UNKNOWN_ELEMENT)
	_retire_outgoing_members()
	_workspace_page = page_id
	_gates.set_surface_open(page_id, true)
	(_zones[ID_WORKSPACE] as Control).visible = true
	_show_open_page()
	_apply_geometry()
	_last_refusal = REFUSE_NONE
	return true


func _retire_outgoing_members() -> void:
	"""Hide every member of the surface the last switch retired, so none keeps a hit region."""
	var count: int = _focus.outgoing_into(_outgoing)
	for index: int in count:
		var id: int = _outgoing[index]
		if _controls.has(id):
			(_controls[id] as Control).visible = false
		_gates.set_surface_open(id, false)


func workspace_page() -> int:
	"""Which workspace page is currently shown."""
	return _workspace_page


func select_basin(basin: Vector2i, danger_band: int) -> bool:
	"""Point the zone tool at a generated ecology basin. Refuses a band §5.5 does not define."""
	if danger_band < DANGER_MIN or danger_band > DANGER_MAX:
		return _refuse(REFUSE_TILE_RANGE)
	_selected_basin = basin
	_selected_basin_danger = danger_band
	_last_refusal = REFUSE_NONE
	return true


func paint_tile(tile: int) -> bool:
	"""Add one tile to the current stroke. Ascending and bounded by the owning store's grid.

	§8.1's zone-tile payload is ascending, so the stroke is built in that order rather than
	sorted afterwards: a stroke that cannot be a payload is refused while the player is making
	it, not when they press Confirm.
	"""
	if tile < 0 or tile >= ForageScript.TILE_COUNT:
		return _refuse(REFUSE_TILE_RANGE)
	if _stroke_count >= _stroke.size():
		return _refuse(REFUSE_STROKE_FULL)
	if _stroke_count > 0 and tile <= _stroke[_stroke_count - 1]:
		return _refuse(REFUSE_TILE_NOT_ASCENDING)
	_stroke[_stroke_count] = tile
	_stroke_count += 1
	_last_refusal = REFUSE_NONE
	return true


func clear_stroke() -> void:
	"""Drop the uncommitted stroke. REQ-UX-012: no store or queue state changes with it."""
	_stroke_count = 0


func stroke_size() -> int:
	"""How many tiles the current uncommitted stroke holds."""
	return _stroke_count


func select_zone(zone: Vector2i, enabled: bool) -> void:
	"""Select a designated zone, carrying the enabled flag its policy toggle will invert."""
	_selected_zone = zone
	_selected_zone_enabled = enabled


func select_job(job: Vector2i) -> void:
	"""Select a queued job, which the quick menu can cancel."""
	_selected_job = job


func select_resident(resident: Vector2i, proposed_name: String) -> void:
	"""Select a resident and the name typed into UI-SET-082's editor."""
	_selected_resident = resident
	_pending_name = proposed_name


func cancel_selected_job() -> bool:
	"""UI-SET-096's cancel action: one CANCEL_JOB command, never a Job store write."""
	if _bridge == null:
		return _report_action(REFUSE_NO_BRIDGE)
	if _selected_job == EntityDirectoryScript.NULL_REF:
		return _report_action(REFUSE_NO_TARGET)
	if not _bridge.cancel_job(_selected_job):
		return _report_action(_bridge.last_refusal())
	return _accept_action()


func _on_confirm_pressed() -> void:
	"""UI-SET-066: turn the current stroke or typed name into a command, or report the refusal."""
	shell_action.emit(ID_CONFIRM)
	if _bridge == null:
		_report_action(REFUSE_NO_BRIDGE)
		return
	if _pending_name != "" and _selected_resident != EntityDirectoryScript.NULL_REF:
		_confirm_name()
		return
	_confirm_designation()


func _confirm_designation() -> bool:
	"""Submit the painted stroke as one DESIGNATE_ZONE over the selected basin."""
	if _selected_basin == EntityDirectoryScript.NULL_REF:
		return _report_action(REFUSE_NO_TARGET)
	var tiles: PackedInt32Array = _stroke.slice(0, _stroke_count)
	if not _bridge.designate_zone(_selected_basin, ForageScript.ZONE_TYPE_FORAGE,
			_selected_basin_danger, tiles):
		return _report_action(_bridge.last_refusal())
	clear_stroke()
	return _accept_action()


func _confirm_name() -> bool:
	"""Submit the typed alias as one NAME_RESIDENT command."""
	if not _bridge.name_resident(_selected_resident, _pending_name):
		return _report_action(_bridge.last_refusal())
	_pending_name = ""
	return _accept_action()


func _report_action(code: StringName) -> bool:
	"""Show a refused action in UI-SET-085 with its exact code, and record it here."""
	var sentence: String = String(code)
	if _bridge != null:
		sentence = _bridge.refusal_sentence(code)
	set_refusal_display(sentence)
	return _refuse(code)


func _accept_action() -> bool:
	"""Clear the refusal display after an accepted action."""
	set_refusal_display("")
	_last_refusal = REFUSE_NONE
	return true


func _on_cancel_pressed() -> void:
	"""UI-SET-067: drop the uncommitted stroke. REQ-UX-012: no store or queue state changes."""
	clear_stroke()
	_toggle_zone(ID_ZONE_BRUSH)
	set_refusal_display("")
	shell_action.emit(ID_CANCEL)


func _on_brush_size_pressed() -> void:
	"""UI-SET-062 as §5's brush stepper: cycle the 1/2/4/8-tile widths that section fixes."""
	var index: int = BRUSH_SIZES.find(_brush_size)
	_brush_size = BRUSH_SIZES[(index + 1) % BRUSH_SIZES.size()]
	var stepper: Button = _controls[ID_STEPPER] as Button
	stepper.text = "Brush %d" % _brush_size
	stepper.accessibility_description = "Brush size %d tiles" % _brush_size
	shell_action.emit(ID_STEPPER)


func brush_size() -> int:
	"""The current brush width in tiles: one of §5's 1, 2, 4 or 8."""
	return _brush_size


func paint_brush_at(tile: int) -> bool:
	"""Paint the brush-sized block whose north-west corner is `tile`, in ascending order.

	Every tile is added through `paint_tile()`, so the stroke stays ascending and inside the
	grid; a block that would leave the map is refused rather than clipped to a smaller one the
	player did not draw.
	"""
	var origin_x: int = tile % MAP_TILES_X
	var origin_z: int = tile / MAP_TILES_X
	if origin_x + _brush_size > MAP_TILES_X or origin_z + _brush_size > MAP_TILES_Z:
		return _refuse(REFUSE_TILE_RANGE)
	for step_z: int in _brush_size:
		for step_x: int in _brush_size:
			if not paint_tile((origin_z + step_z) * MAP_TILES_X + origin_x + step_x):
				return false
	return true


func _on_work_policy_pressed() -> void:
	"""UI-SET-100: a policy edit, which reaches the store only as a SET_POLICY command."""
	shell_action.emit(ID_WORK_POLICY)
	if _bridge == null:
		_report_action(REFUSE_NO_BRIDGE)
		return
	if _selected_zone == EntityDirectoryScript.NULL_REF:
		_report_action(REFUSE_NO_TARGET)
		return
	if not _bridge.set_zone_enabled(_selected_zone, not _selected_zone_enabled):
		_report_action(_bridge.last_refusal())
		return
	_accept_action()


func _on_pin_pressed() -> void:
	"""UI-SET-098: open the name editor for the selected resident."""
	shell_action.emit(ID_PIN)


func _on_create_pressed() -> void:
	"""UI-SET-103's Create: ask whoever owns the stores to generate, and report what happened.

	The shell does not generate. `world_init.gd` writes resource, forage and fishing stores, and
	this file deliberately holds no store it could hand to it -- UIManager does, and it listens
	for this action.
	"""
	shell_action.emit(ID_NEW_SETTLEMENT)


func create_button() -> Button:
	"""UI-SET-103's Create action instance, for the suite and for keyboard focus."""
	return _create_button


func report_action_result(accepted: bool, message: String) -> void:
	"""Show the outcome of an action the shell asked an owner to perform.

	An accepted action clears the refusal display and says what it did; a refusal fills
	UI-SET-085 with the owner's exact code. The shell never decides which of those happened.
	"""
	if accepted:
		set_refusal_display("")
		set_alert_display(message)
		return
	set_refusal_display(message)


func _on_back_pressed() -> void:
	"""UI-SET-092: close the workspace frame, returning focus where §2.2 sends it.

	§2.2: focus returns to the opening control if still present, otherwise the zone's first
	control. The router owns both branches; closing without it left focus standing on a
	control that had just been hidden."""
	_focus.close_surface(_gates)
	_retire_outgoing_members()
	_gates.set_surface_open(_workspace_page, false)
	_toggle_zone(ID_WORKSPACE)
	shell_action.emit(ID_BACK)


func _on_close_pressed() -> void:
	"""UI-SET-093: close the detail panel."""
	set_detail_open(false)
	shell_action.emit(ID_CLOSE)


func _toggle_zone(id: int) -> void:
	"""Show or hide one expansion or workspace, then rebuild the click-through table."""
	var zone: Control = _zones[id]
	zone.visible = not zone.visible
	_register_hit_regions()


# --- readers for the suite and for UIManager -----------------------------------------------------------

func tooltip_label() -> Label:
	"""UI-SET-073's text, which keyboard focus fills at 0 ms."""
	return _tooltip_line


func ledger_label() -> Label:
	"""UI-SET-009's line: every counter, including the unpopulated markers."""
	return _ledger_line


func alert_label() -> Label:
	"""UI-SET-011's message text."""
	return _alert_message


func status_label() -> Button:
	"""UI-SET-101's date trigger, which also carries the state and speed readout."""
	return _controls[ID_DATE] as Button


func control_for(id: int) -> Control:
	"""The built control for a §4 id, or null when this shell does not render it."""
	if not _controls.has(id):
		_refuse(REFUSE_UNKNOWN_ELEMENT)
		return null
	_last_refusal = REFUSE_NONE
	return _controls[id]


func renders(id: int) -> bool:
	"""True when this shell built a control for the element."""
	return _controls.has(id)


func rendered_count() -> int:
	"""How many §4 elements this shell built."""
	return _controls.size()


func hit_test() -> UiHitTest:
	"""The §1.2 click-through table for the current layout."""
	return _hits


func geometry() -> UiLayout.Geometry:
	"""The current §1.2 geometry."""
	return _geometry


func focus_order() -> UiFocusOrder:
	"""The §8.2 focus order this shell applies."""
	return _focus


func availability() -> UiAvailability:
	"""The availability claim every control's disabled state is derived from."""
	return _availability


func registry() -> UiRegistry:
	"""The §4 registry every control's name and size comes from."""
	return _registry


func is_built() -> bool:
	"""True once `build()` has created the controls."""
	return _built


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a successful call."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record an explicit refusal code and return false."""
	_last_refusal = code
	return false
