extends Control
## UI-BUILD-001..009: THE ONE BUILD PANEL (DEC-061 Q1; docs/ui_ux_controls.md UI-BUILD-001; decision 1871).
##
##   +--------------------------------------------------------------------------------------------+
##   | [Rooms] [Furnish] [Decor]                       Building on: Underground level 1           |
##   |                                                 ! 1 of 2 not ready: Kitchen: Too small ...  |
##   | +-info card-+ +card+ +card+ +card+ ...  (a horizontal scroll of type or item cards)         |
##   | | picture   | |    | |    | |    |                                                        |
##   | | purpose   | +----+ +----+ +----+                                                        |
##   | +-----------+                                                                              |
##   | [ledger: Plan 24 logs, 24 blocks ... ▴] [Undo] [Redo] [Discard all] [Confirm all (2)]       |
##   +--------------------------------------------------------------------------------------------+
##
## Game UI: it shows the batch (build_batch.gd) and the catalog's cards (build_catalog.gd) and SAYS what the player
## asked for -- `card_chosen`, `confirm_requested`, `closed` -- and owns nothing in the world. Opening it, choosing a
## card, Undo, Redo and Discard all change no store, reservation or job (BUILD-REQ-020, UX-BUILD-T04).
##
## TOOLS (decision 1912; Brendan's ruling on decision 1911 P-C7 (a)): with a room type chosen, a strip of four toggles
## along the info card's foot -- Rect · Oval · Paint · Erase (accessible names "Rectangle tool" ...) -- sets the
## batch's tool; the info card's last line names the tool and its gesture in words (never the pressed look alone).
## FURNISH AND DECOR (decision 1921): an item card chosen on levels 1-4 arms placing it (`piece_armed`); the host
## places it on a dug floor (build_furniture.gd judges it) and hands the info card the dug rooms' lines in words
## (`set_room_lines`: "✓ Kitchen ready", "! Kitchen: Needs 1 hearth"), shown under the card on those tabs.
## STYLE (decision 2002; BUILD-MOUND-001): two toggles after the tabs on the Rooms tab, "Built" and "Mound". The style
## follows the level shown -- Mound on the Surface, Built below -- and the other can be pressed to read why its cards are
## locked ("Not yet: built rooms on the surface ...", "X Not possible: Mound rooms are painted on the Surface").
## A FRONT DOOR'S COLOUR (P-2001-8 (a)): with the Front door card chosen the tool strip offers Oak · Green · Red · Blue
## (oak first and by default), and the info card names the colour in words.
## TABS. Furnish and Decor stay disabled, saying "Choose a room type first", until a room type or Passage is chosen;
## Ctrl+Tab / Ctrl+Shift+Tab cycle the enabled ones (`cycle_tab`). CARDS: arrow keys move along the row and Enter
## chooses (Godot's own focus and press); a locked card is chosen for INSPECTION only -- the info card says why it is
## locked. The info card follows the hovered or focused card, else the chosen one, else "Choose a room type to begin".
## FOOTER. The ledger button expands upward into the per-type lines, every operation's validity and the totals;
## Undo / Redo name their step or say "Nothing to undo / redo"; Discard all asks once when there is anything to
## discard; Confirm all is disabled while a stroke is in progress or any operation is invalid, naming the first reason
## and the count. CLOSING with pending changes asks "Keep N pending changes?" (Keep / Discard). The questions sit in the
## footer's place. ESCAPE (`escape`): the stroke in progress, then an open question, then the expanded ledger, then
## the panel. THE CONNECTOR CARD (UI-BUILD-012; decision 2021, P-D1-3 (a)): with a way's card chosen, the host pins
## its ghost at a cell (`pin_way`); the card offers Down / Up (P-D1-4 (a)), says where it leads or why not, and "Add to
## plan" (Enter: `add_pinned`) puts it in the batch -- the card chosen is put down unless Shift keeps it; Cancel or
## Escape (after the stroke, before the rest) closes it. R / Shift+R turn the way (`rotate_way`).

const Batch := preload("res://scripts/ui/build_batch.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const Furniture := preload("res://scripts/ui/build_furniture.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
const ConnectorCard := preload("res://scripts/ui/build_connector_card.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const ThemeResource: Theme = preload("res://ui/theme/woodland_theme.tres")

const QUESTION_NONE: int = 0
const QUESTION_CLOSE: int = 1
const QUESTION_DISCARD: int = 2
const TEXT_PX: int = 14
const TITLE_PX: int = 16
const CARD_POOL: int = 16
const ACCESSIBLE: String = "Build on %s; %d pending changes"
const WHERE: String = "Building on: %s"
const KEEP_QUESTION: String = "Keep %d pending changes?"
const DISCARD_QUESTION: String = "Discard %d pending changes?"
const NOTHING_TO_CONFIRM: String = "Nothing to confirm yet"
const FINISH_STROKE: String = "Finish or cancel the stroke first"
const NOT_READY: String = "%s %d of %d not ready: %s: %s"
const READY: String = "%d pending changes, all ready"
const RETRY: String = "! Refused last time, Confirm all tries again: %s: %s"
const NONE_PENDING: String = "No pending changes"
const PICTURE: String = "Picture (placeholder): %s"
const TOOL_LINE: String = "Tool: %s. %s"
const ITEM_LINE: String = "%s · %s (%s; placeholder, free for now): %s"
const REMOVAL_LINE: String = "%s · Remove %s: %s"
const PIECE_LINE: String = "%s · %s%s (free for now): %s"
const FURNITURE_BILL: String = "Furniture needs %s; work %s (free for now: nothing is taken from the stores)"
const TOOL_ACCESSIBLE: String = "%s tool"
## Decision 2002: the style toggles, the door colour strip, and the ledger's Mound lines.
const STYLE_WIDTH: float = 76.0
const STYLE_ACCESSIBLE: String = "%s style"
const COLOUR_ACCESSIBLE: String = "%s door"
const COLOUR_LINE: String = "Colour: %s. %s"
const EDGE_LINE: String = "%s · %s%s (free for now): %s"
const HEAP_LINE: String = "Mound heap (free for now): %d room cells, 5 quanta of earth heaped over each and 4 dug back out; the berm's earth is measured with the ground heights (MOUND-TERRAIN)"

## A card was clicked or pressed with Enter (a locked one too: the host may only show it).
signal card_chosen(card: BuildCatalog.Card)
## Confirm all was pressed with every operation valid.
signal confirm_requested
## The panel closed: `kept` false when its pending changes were discarded on the way.
signal closed(kept: bool)
## The connector card's way went into the batch (or was dropped, kind "X"): the batch's kind (decision 2021).
signal way_added(kind: int)

var _batch: Batch = null
var _catalog: BuildCatalog = null
var _stock: Callable = Callable()
var _frame: Panel = null
var _tabs: Array[Button] = []
var _where: Label = null
var _status: Label = null
var _info: Panel = null
var _info_scroll: ScrollContainer = null
var _info_text: Label = null
var _scroll: ScrollContainer = null
var _row: HBoxContainer = null
var _card_buttons: Array[Button] = []
var _card_size: Vector2 = Vector2(BuildLayout.CARD_MIN_WIDTH, BuildLayout.CONTENT_HEIGHT - 12.0)
## The tool strip's four toggles, in build_stroke.gd TOOL_* order.
var _tools: Array[Button] = []
var _ledger: Button = null
var _ledger_open: Panel = null
var _ledger_scroll: ScrollContainer = null
var _ledger_text: Label = null
var _undo: Button = null
var _redo: Button = null
var _discard: Button = null
var _confirm: Button = null
## The footer's five controls in order (ledger, Undo, Redo, Discard all, Confirm all).
var _footer: Array[Button] = []
var _question: HBoxContainer = null
var _question_text: Label = null
var _question_yes: Button = null
var _question_no: Button = null
var _question_kind: int = QUESTION_NONE
var _cards: Array[BuildCatalog.Card] = []
var _tab: int = BuildCatalog.TAB_ROOMS
var _level: int = LevelBar.LEVEL_SURFACE
var _reachable: bool = true
var _chosen: BuildCatalog.Card = null
var _furnish_type: int = -1
var _shown: BuildCatalog.Card = null
var _seen_revision: int = -1
var _seen_stroke: int = -1
var _profile: int = UiLayout.PROFILE_STANDARD
var _panel_rect: Rect2 = Rect2()
var _widths: PackedFloat32Array = PackedFloat32Array()
var _tally: PackedInt64Array = PackedInt64Array()
var _types: PackedInt32Array = PackedInt32Array()
var _type_cells: PackedInt32Array = PackedInt32Array()
var _goods: PackedStringArray = PackedStringArray()
var _goods_milli: PackedInt64Array = PackedInt64Array()
## The dug rooms' lines the host hands in (decision 1921), shown on the Furnish and Decor tabs.
var _room_lines: String = ""
## Decision 2002: the style toggles (build_mound.gd STYLE_* order), the style chosen, and the front door's colour.
var _style_buttons: Array[Button] = []
## The panel starts on the Surface, so in the Mound style.
var _style: int = Mound.STYLE_MOUND
var _door_colour: int = Mound.COLOUR_OAK
## Decision 2021: the connector card, the armed way's quarter turns, and the way pinned on the card (its cell, whether
## it goes up).
var _connector: ConnectorCard = null
var _way_turn: int = 0
var _pinned: bool = false
var _pin_cell: Vector2i = Vector2i.ZERO
var _pin_up: bool = false


func _init() -> void:
	"""Named; hidden until opened; the empty full-viewport root never takes the mouse."""
	name = "BuildPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(batch: Batch, catalog: BuildCatalog, stock: Callable) -> void:
	"""The batch it shows, the cards it offers, and `stock(good: StringName) -> int` milli-U the stores hold (read for
	the ledger only; nothing is reserved)."""
	_batch = batch
	_catalog = catalog
	_stock = stock
	build()


func build() -> void:
	"""Every control (also off-tree, for checks)."""
	if _frame != null:
		return
	theme = ThemeResource
	_frame = Panel.new()
	_frame.name = "UI-BUILD-001"
	_frame.theme_type_variation = &"WoodlandPanel"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_frame)
	_build_tabs()
	_build_styles()
	_build_info()
	_build_tools()
	_build_cards()
	_build_footer()
	_build_question()
	_build_ledger_open()
	_build_connector()


func _build_connector() -> void:
	"""UI-BUILD-012, hidden until a way is pinned."""
	_connector = ConnectorCard.new()
	_connector.direction_chosen.connect(set_way_up)
	_connector.add_pressed.connect(_on_add_pressed)
	_connector.cancel_pressed.connect(cancel_pin)
	add_child(_connector)


# --- construction --------------------------------------------------------------------------------------------------

func _build_tabs() -> void:
	"""UI-BUILD-002 ×3 and the "Building on" words with the batch's status under them."""
	for tab: int in BuildCatalog.TAB_COUNT:
		var button: Button = _button("UI-BUILD-002-%d" % tab, BuildCatalog.TAB_NAMES[tab], select_tab.bind(tab))
		button.toggle_mode = true
		button.theme_type_variation = &"WoodlandToggle"
		_tabs.append(button)
	_where = _label("BuildingOn", TITLE_PX)
	_status = _label("Status", TEXT_PX)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true


func _build_styles() -> void:
	"""The style toggles (decision 2002): "Built" and "Mound", in the tabs row after the tabs."""
	for kind: int in Mound.STYLE_COUNT:
		var button: Button = _button("BuildStyle-%s" % Mound.STYLE_NAMES[kind], Mound.STYLE_NAMES[kind],
			choose_style.bind(kind))
		button.toggle_mode = true
		button.theme_type_variation = &"WoodlandToggle"
		button.accessibility_name = STYLE_ACCESSIBLE % Mound.STYLE_NAMES[kind]
		_style_buttons.append(button)


func _build_info() -> void:
	"""UI-BUILD-004: one wrapped text block in a framed card that scrolls when the words outgrow it (§1.3: never
	truncated)."""
	_info = Panel.new()
	_info.name = "UI-BUILD-004"
	_info.theme_type_variation = &"WoodlandReadout"
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.clip_contents = true
	_frame.add_child(_info)
	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info.add_child(_info_scroll)
	_info_text = Label.new()
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.add_theme_font_size_override(&"font_size", TEXT_PX)
	_info_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_scroll.add_child(_info_text)


func _build_tools() -> void:
	"""The tool strip: four toggles over the info card's foot, hidden until a room type is chosen."""
	for tool: int in Stroke.TOOL_COUNT:
		var button: Button = Button.new()
		button.name = "BuildTool-%s" % Stroke.TOOL_NAMES[tool]
		button.text = Stroke.TOOL_LABELS[tool]
		button.toggle_mode = true
		button.theme_type_variation = &"WoodlandToggle"
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override(&"font_size", TEXT_PX)
		button.accessibility_name = TOOL_ACCESSIBLE % Stroke.TOOL_NAMES[tool]
		button.tooltip_text = Stroke.TOOL_GESTURES[tool]
		button.visible = false
		button.pressed.connect(choose_tool.bind(tool))
		_frame.add_child(button)
		_tools.append(button)


func _build_cards() -> void:
	"""UI-BUILD-003: a horizontal scroll of a pooled row of card buttons."""
	_scroll = ScrollContainer.new()
	_scroll.name = "Cards"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_frame.add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", int(BuildLayout.GAP))
	_scroll.add_child(_row)
	_grow_cards(CARD_POOL)


func _grow_cards(count: int) -> void:
	"""Pooled card buttons up to `count` (cold: at build, and when a row has more cards than the pool -- no card is
	ever dropped)."""
	for k: int in range(_card_buttons.size(), count):
		var card: Button = Button.new()
		card.name = "UI-BUILD-003-%d" % k
		card.theme_type_variation = &"WoodlandButton"
		card.focus_mode = Control.FOCUS_ALL
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override(&"font_size", TEXT_PX)
		card.custom_minimum_size = _card_size
		card.pressed.connect(_on_card_pressed.bind(k))
		card.focus_entered.connect(_show_card.bind(k))
		card.mouse_entered.connect(_show_card.bind(k))
		card.mouse_exited.connect(_show_card.bind(-1))
		card.visible = false
		_row.add_child(card)
		_card_buttons.append(card)


func _build_footer() -> void:
	"""UI-BUILD-005..009."""
	_ledger = _button("UI-BUILD-005", "", toggle_ledger)
	_ledger.toggle_mode = true
	_ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_undo = _button("UI-BUILD-006", "Undo", _on_undo)
	_redo = _button("UI-BUILD-007", "Redo", _on_redo)
	_discard = _button("UI-BUILD-009", "Discard all", ask_discard)
	_confirm = _button("UI-BUILD-008", "Confirm all", _on_confirm)
	_footer = [_ledger, _undo, _redo, _discard, _confirm]


func _build_question() -> void:
	"""The one-line question that stands in the footer's place: words, a yes and a no."""
	_question = HBoxContainer.new()
	_question.name = "Question"
	_question.add_theme_constant_override(&"separation", int(BuildLayout.GAP))
	_question.visible = false
	_frame.add_child(_question)
	_question_text = Label.new()
	_question_text.add_theme_font_size_override(&"font_size", TITLE_PX)
	_question_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_question_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question.add_child(_question_text)
	_question_yes = _plain_button("Yes", _answer.bind(true))
	_question.add_child(_question_yes)
	_question_no = _plain_button("No", _answer.bind(false))
	_question.add_child(_question_no)


func _build_ledger_open() -> void:
	"""UI-BUILD-005 expanded: a panel over the content and tab rows, its words in a vertical scroll."""
	_ledger_open = Panel.new()
	_ledger_open.name = "UI-BUILD-005-open"
	_ledger_open.theme_type_variation = &"WoodlandPanel"
	_ledger_open.mouse_filter = Control.MOUSE_FILTER_STOP
	_ledger_open.visible = false
	_ledger_open.clip_contents = true
	add_child(_ledger_open)
	_ledger_scroll = ScrollContainer.new()
	_ledger_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ledger_open.add_child(_ledger_scroll)
	_ledger_text = Label.new()
	_ledger_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger_text.add_theme_font_size_override(&"font_size", TEXT_PX)
	_ledger_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_scroll.add_child(_ledger_text)


func _button(control_name: String, text: String, pressed: Callable) -> Button:
	"""A focusable WoodlandButton in the frame."""
	var button: Button = _plain_button(text, pressed)
	button.name = control_name
	_frame.add_child(button)
	return button


static func _plain_button(text: String, pressed: Callable) -> Button:
	"""A focusable WoodlandButton, at least 44 px tall, its text at the 14 px floor or more."""
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = &"WoodlandButton"
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = BuildLayout.ROW_HEIGHT
	button.add_theme_font_size_override(&"font_size", TEXT_PX)
	button.pressed.connect(pressed)
	return button


func _label(control_name: String, px: int) -> Label:
	"""A label in the frame."""
	var label: Label = Label.new()
	label.name = control_name
	label.add_theme_font_size_override(&"font_size", px)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(label)
	return label


# --- placing -------------------------------------------------------------------------------------------------------

func place(geometry: UiLayout.Geometry) -> void:
	"""Lay the panel out at the HUD's scale (build_layout.gd's equations, logical px)."""
	build()
	_profile = geometry.profile
	_panel_rect = BuildLayout.panel_rect(geometry)
	scale = Vector2(geometry.scale, geometry.scale)
	position = Vector2.ZERO
	size = Vector2(geometry.logical_width, geometry.logical_height)
	_frame.position = _panel_rect.position
	_frame.size = _panel_rect.size
	_place_tabs()
	_place_content()
	_place_footer()
	_place_ledger_open()
	_connector.place_in(BuildLayout.connector_rect(geometry))


func _place_tabs() -> void:
	"""Three tabs from the left of the tabs row; the words in the rest of it."""
	var row: Rect2 = BuildLayout.tabs_rect(_panel_rect.size.x)
	var width: float = BuildLayout.TAB_MAX_WIDTH if row.size.x >= 900.0 else BuildLayout.TAB_MIN_WIDTH + 24.0
	for tab: int in _tabs.size():
		_tabs[tab].position = row.position + Vector2(tab * (width + BuildLayout.GAP), 0.0)
		_tabs[tab].size = Vector2(width, row.size.y)
	var x: float = row.position.x + _tabs.size() * (width + BuildLayout.GAP)
	for toggle: Button in _style_buttons:
		toggle.position = Vector2(x, row.position.y)
		toggle.size = Vector2(STYLE_WIDTH, row.size.y)
		x += STYLE_WIDTH
	x += BuildLayout.GAP * 2.0
	var words_width: float = maxf(row.end.x - x, 0.0)
	_where.position = Vector2(x, row.position.y)
	_where.size = Vector2(words_width, row.size.y / 2.0)
	_status.position = Vector2(x, row.position.y + row.size.y / 2.0)
	_status.size = Vector2(words_width, row.size.y / 2.0)


func _place_content() -> void:
	"""The info card (its words above the tool strip while the strip shows) and the card row."""
	var info: Rect2 = BuildLayout.info_rect(_profile)
	_info.position = info.position
	_info.size = info.size
	_info_scroll.position = Vector2(8.0, 6.0)
	var strip: float = BuildLayout.TOOL_STRIP_HEIGHT + BuildLayout.TOOL_STRIP_INSET if _strip_shown() else 0.0
	_info_scroll.size = info.size - Vector2(12.0, 12.0 + strip)
	_info_text.custom_minimum_size.x = info.size.x - 32.0
	_place_tools()
	var cards: Rect2 = BuildLayout.cards_rect(_panel_rect.size.x, _profile)
	_scroll.position = cards.position
	_scroll.size = cards.size
	var width: float = BuildLayout.CARD_MAX_WIDTH if _profile == UiLayout.PROFILE_WIDE else BuildLayout.CARD_MIN_WIDTH
	_card_size = Vector2(width, BuildLayout.CONTENT_HEIGHT - 12.0)
	for card: Button in _card_buttons:
		card.custom_minimum_size = _card_size


func _place_tools() -> void:
	"""The four toggles side by side along the strip, 4 px apart."""
	var strip: Rect2 = BuildLayout.tool_strip_rect(_profile)
	var width: float = (strip.size.x - BuildLayout.TOOL_STRIP_INSET * (_tools.size() - 1)) / _tools.size()
	for tool: int in _tools.size():
		_tools[tool].position = strip.position + Vector2(tool * (width + BuildLayout.TOOL_STRIP_INSET), 0.0)
		_tools[tool].size = Vector2(width, strip.size.y)


func _strip_shown() -> bool:
	"""Whether the tool strip shows: a room type chosen on the Rooms tab, or the Front door's colours."""
	return (_chosen != null and _chosen.kind == BuildCatalog.CARD_ROOM and _tab == BuildCatalog.TAB_ROOMS) \
		or _colour_strip()


func choose_tool(tool: int) -> bool:
	"""Set the batch's tool (build_stroke.gd TOOL_*), or with the Front door chosen its colour; the strip and the info
	card follow. False for an unknown tool."""
	if _colour_strip():
		return choose_colour(tool)
	if _batch == null or not _batch.set_tool(tool):
		_sync_tools()
		return false
	_sync_tools()
	_sync_info()
	return true


func _sync_tools() -> void:
	"""The strip shown with a room type chosen, the batch's tool pressed and named in its accessible state."""
	var shown: bool = _strip_shown()
	var colours: bool = _colour_strip()
	var current: int = _door_colour if colours else (_batch.tool() if _batch != null else Stroke.TOOL_RECTANGLE)
	for tool: int in _tools.size():
		_tools[tool].visible = shown
		_tools[tool].text = Mound.COLOUR_NAMES[tool] if colours else Stroke.TOOL_LABELS[tool]
		_tools[tool].accessibility_name = COLOUR_ACCESSIBLE % Mound.COLOUR_NAMES[tool] if colours \
			else TOOL_ACCESSIBLE % Stroke.TOOL_NAMES[tool]
		_tools[tool].set_pressed_no_signal(tool == current)
		_tools[tool].accessibility_description = "selected" if tool == current else ""
	if _info != null and _info_scroll.size.y > 0.0:
		_place_content_scroll(shown)


func _place_content_scroll(shown: bool) -> void:
	"""The info card's words make room for the strip while it shows."""
	var strip: float = BuildLayout.TOOL_STRIP_HEIGHT + BuildLayout.TOOL_STRIP_INSET if shown else 0.0
	_info_scroll.size = _info.size - Vector2(12.0, 12.0 + strip)


func tool_buttons() -> Array[Button]:
	"""The tool strip's toggles (checks)."""
	return _tools


func _place_footer() -> void:
	"""Ledger, Undo, Redo, Discard all, Confirm all at 8 px gaps; the question in the same place."""
	var footer: Rect2 = BuildLayout.footer_rect(_panel_rect.size.x)
	BuildLayout.footer_widths_into(footer.size.x, _widths)
	var x: float = footer.position.x
	for k: int in _footer.size():
		var control: Button = _footer[k]
		control.position = Vector2(x, footer.position.y)
		control.size = Vector2(_widths[k], footer.size.y)
		x += _widths[k] + BuildLayout.GAP
	_confirm.position.x = footer.end.x - _widths[4]
	_question.position = footer.position
	_question.size = footer.size


func _place_ledger_open() -> void:
	"""The expanded ledger at the panel's top edge down to the footer (build_layout.gd `ledger_open_rect`)."""
	var open: Rect2 = BuildLayout.ledger_open_rect(_panel_rect, _profile)
	_ledger_open.position = open.position
	_ledger_open.size = open.size
	var inner: Vector2 = Vector2(BuildLayout.PADDING, BuildLayout.PADDING)
	_ledger_scroll.position = inner
	_ledger_scroll.size = open.size - 2.0 * inner
	_ledger_text.custom_minimum_size.x = maxf(open.size.x - 2.0 * inner.x - 16.0, 0.0)


# --- opening, closing, the level -----------------------------------------------------------------------------------

func open_on(level: int, reachable: bool = true) -> void:
	"""Open on `level` (LevelBar.LEVEL_*; `reachable`: it has a way in): the Rooms tab, the batch as it stands."""
	visible = true
	_frame.visible = true
	_question_kind = QUESTION_NONE
	set_level(level, reachable)
	select_tab(BuildCatalog.TAB_ROOMS)
	refresh(true)


func is_open() -> bool:
	"""Whether the panel is open."""
	return visible


func request_close() -> bool:
	"""Close, or -- with pending changes -- ask "Keep N pending changes?" first. True when it closed now."""
	if not visible:
		return true
	if _batch != null and _batch.pending_count() > 0:
		_ask(QUESTION_CLOSE)
		return false
	_finish_close(true)
	return true


func _finish_close(kept: bool) -> void:
	"""Close: the stroke in progress dropped, the questions and the expanded ledger shut, the choice forgotten (the
	next opening starts on Rooms with nothing chosen; the batch is the player's to keep or discard)."""
	if _batch != null:
		_batch.cancel_stroke()
	visible = false
	cancel_pin()
	_chosen = null
	_furnish_type = -1
	_tab = BuildCatalog.TAB_ROOMS
	_question_kind = QUESTION_NONE
	_show_ledger(false)
	closed.emit(kept)


func set_level(level: int, reachable: bool = true) -> void:
	"""The level the panel builds on, and whether it has a way in: its cards and words follow (the pending batch keeps
	every level's changes)."""
	if level == _level and reachable == _reachable and not _cards.is_empty():
		return
	if level != _level and level < LevelBar.LEVEL_OVERVIEW:
		_style = Mound.STYLE_MOUND if level == Mound.SURFACE else Mound.STYLE_BUILT
	_level = level
	_reachable = reachable
	cancel_pin()
	_where.text = WHERE % LevelBar.level_name(level)
	if _chosen != null and not _card_still_usable():
		_chosen = null
	_fill_cards()


func building_level() -> int:
	"""The level the panel builds on."""
	return _level


func _card_still_usable() -> bool:
	"""Whether the chosen card is usable on the level now shown (a room type is locked on the surface, and so is a
	piece of furniture: its own tab's cards are read)."""
	var tab: int = BuildCatalog.TAB_ROOMS if _chosen.kind != BuildCatalog.CARD_ITEM \
		and _chosen.kind != BuildCatalog.CARD_EDGE else _tab
	_catalog.cards_into(tab, _level, _furnish_type, _cards, _reachable, _style)
	for card: BuildCatalog.Card in _cards:
		if card.id == _chosen.id:
			return card.usable()
	return false


# --- tabs and cards -------------------------------------------------------------------------------------------------

func select_tab(tab: int) -> bool:
	"""Show tab `tab`; refused (false) for Furnish and Decor until a room type or Passage is chosen."""
	if tab < 0 or tab >= BuildCatalog.TAB_COUNT or not tab_enabled(tab):
		_sync_tabs()
		return false
	_tab = tab
	_fill_cards()
	return true


func shown_tab() -> int:
	"""The tab shown."""
	return _tab


func tab_enabled(tab: int) -> bool:
	"""Rooms always; Furnish and Decor once a room type or Passage has been chosen."""
	return tab == BuildCatalog.TAB_ROOMS or _furnish_type >= 0


func cycle_tab(forward: bool) -> int:
	"""Ctrl+Tab / Ctrl+Shift+Tab: the next enabled tab round the three; returns the tab shown."""
	for step: int in range(1, BuildCatalog.TAB_COUNT + 1):
		var next: int = posmod(_tab + (step if forward else -step), BuildCatalog.TAB_COUNT)
		if tab_enabled(next):
			select_tab(next)
			break
	return _tab


func choose_card(index: int) -> void:
	"""Choose card `index` of the row: a usable room type or Passage arms it (and opens Furnish/Decor); every card is
	shown in the info card and told to the host."""
	if index < 0 or index >= _cards.size():
		return
	var card: BuildCatalog.Card = _cards[index]
	if card.usable() and card.kind != BuildCatalog.CARD_TOOL:
		_chosen = card
		if card.kind == BuildCatalog.CARD_ROOM:
			_furnish_type = card.room_type
	_shown = card
	_sync_tabs()
	_sync_tools()
	_sync_cards()
	_sync_info()
	card_chosen.emit(card)


func chosen_card() -> BuildCatalog.Card:
	"""The room-type card armed for painting (null: none)."""
	return _chosen


func paint_type() -> int:
	"""The room type a stroke paints now, or -1 (none chosen, a way down chosen, or not paintable on this level in the
	style chosen: Built on levels 1-4, Mound on the Surface)."""
	if _chosen == null or _chosen.kind != BuildCatalog.CARD_ROOM:
		return -1
	var below: bool = _level >= 1 and _level <= LevelBar.LEVEL_DEEPEST and _style == Mound.STYLE_BUILT
	var surface: bool = _level == Mound.SURFACE and _style == Mound.STYLE_MOUND
	return _chosen.room_type if below or surface else -1


func style() -> int:
	"""The style rooms are painted in (build_mound.gd STYLE_*)."""
	return _style


func choose_style(chosen: int) -> bool:
	"""Choose Built or Mound (decision 2002): the room cards follow (a card locked in the other style puts the chosen
	one down). False for an unknown style."""
	if not Mound.valid_style(chosen):
		_sync_styles()
		return false
	_style = chosen
	if _chosen != null and _chosen.kind == BuildCatalog.CARD_ROOM and not _card_still_usable():
		_chosen = null
	_fill_cards()
	return true


func _sync_styles() -> void:
	"""The style toggles: on the Rooms tab only, the chosen one pressed, each naming why it is locked here."""
	for style_at: int in _style_buttons.size():
		var button: Button = _style_buttons[style_at]
		button.visible = _tab == BuildCatalog.TAB_ROOMS
		button.set_pressed_no_signal(style_at == _style)
		var lock: String = BuildCatalog.room_lock(_level, true, style_at)
		button.tooltip_text = Validity.line(BuildCatalog.lock_kind_of(_level, style_at), lock) if not lock.is_empty() \
			else STYLE_ACCESSIBLE % Mound.STYLE_NAMES[style_at]
		button.accessibility_description = "selected" if style_at == _style else ""


func style_buttons() -> Array[Button]:
	"""The style toggles (checks)."""
	return _style_buttons


func way_down_armed() -> bool:
	"""Whether a click places a way down now (its card chosen on a level that has one)."""
	return _chosen != null and _chosen.kind == BuildCatalog.CARD_WAY_DOWN and _level < LevelBar.LEVEL_OVERVIEW


func armed_family() -> int:
	"""The connector family a click places (build_connector_families.gd; -1: no way armed)."""
	return _chosen.item_type if way_down_armed() else -1


func way_turn() -> int:
	"""The armed way's quarter turns, 0-3."""
	return _way_turn


func rotate_way(by: int) -> int:
	"""R (+1) / Shift+R (-1): turn the armed (or pinned) way; its turns now."""
	_way_turn = posmod(_way_turn + by, 4)
	if _pinned:
		_sync_connector()
	return _way_turn


func default_up(level: int) -> bool:
	"""The direction a way placed on `level` starts with: down, except from level 4 (only up there)."""
	return level >= LevelBar.LEVEL_DEEPEST


static func direction_refusal(level: int, up: bool) -> String:
	"""Why a way placed on `level` cannot go `up` (or down): "No level above the surface" / "No level below level 4";
	"" when it can (BUILD-REQ-016, -018)."""
	if up and level <= LevelBar.LEVEL_SURFACE:
		return Validity.no_level_above()
	if not up and level >= LevelBar.LEVEL_DEEPEST:
		return Validity.no_level_below()
	return ""


func standing_level() -> int:
	"""The level the pinned way stands on: the level shown going down, the one above going up."""
	return _level - 1 if _pin_up else _level


func pin_way(cell: Vector2i) -> bool:
	"""Pin the armed way's ghost at `cell` on the level shown and open its card (direction: `default_up`). False with
	no way armed."""
	if not way_down_armed():
		return false
	_pinned = true
	_pin_cell = cell
	_pin_up = default_up(_level)
	_sync_connector()
	return true


func pinned() -> bool:
	"""Whether a way is pinned on the card."""
	return _pinned


func pinned_cell() -> Vector2i:
	"""Where the pinned way's north-west cell is."""
	return _pin_cell


func pinned_up() -> bool:
	"""Whether the pinned way goes up."""
	return _pin_up


func set_way_up(up: bool) -> bool:
	"""Down or Up on the card; an impossible direction is refused (false) and the card stays as it was."""
	if not _pinned or not direction_refusal(_level, up).is_empty():
		_sync_connector()
		return false
	_pin_up = up
	_sync_connector()
	return true


func add_pinned(keep: bool = false) -> int:
	"""Add to plan: the pinned way into the batch (build_batch.gd `place_item`); the card closes and, unless `keep`
	(Shift), the way's card is put down. Returns the batch's kind (-1: nothing pinned or nothing tried)."""
	if not _pinned:
		return -1
	var kind: int = _batch.place_item(standing_level(), _pin_cell, armed_family(), _way_turn)
	if kind >= 0 and kind != Validity.KIND_NOT_POSSIBLE:
		cancel_pin()
		if not keep:
			clear_choice()
	way_added.emit(kind)
	refresh(true)
	return kind


func _on_add_pressed() -> void:
	"""The card's Add to plan, clicked (Shift held keeps the way's card)."""
	add_pinned(Input.is_key_pressed(KEY_SHIFT))


func cancel_pin() -> void:
	"""Close the card; nothing is added."""
	if _connector == null:
		return
	_pinned = false
	_connector.visible = false
	if _scroll != null:
		_scroll.visible = true


func connector() -> ConnectorCard:
	"""The connector card (checks)."""
	return _connector


func connector_words() -> String:
	"""What the card says now ("" while it is closed)."""
	return _connector.words() if _connector.visible else ""


func _sync_connector() -> void:
	"""The card from the pinned way's judgement now (cold: on a pin, a turn, a direction or a batch change)."""
	var family: int = armed_family()
	var judged: Array = _batch.judge_item(standing_level(), _pin_cell, -1, family, _way_turn)
	var kind: int = int(judged[0])
	var target: int = _level - 1 if _pin_up else _level + 1
	var result: String = "%s %s" % [Validity.glyph(kind), Validity.connects(LevelBar.level_name(target))] \
		if kind == Validity.KIND_CAN_BUILD else Validity.line(kind, String(judged[1]))
	var notes: PackedStringArray = PackedStringArray([Families.PLACEHOLDER])
	if family == Families.LADDER_HATCH:
		notes.append(Families.CLIMBERS_ONLY)
	notes.append(Families.NOT_QUALIFIED)
	var reasons: PackedStringArray = PackedStringArray([direction_refusal(_level, false), direction_refusal(_level, true)])
	_connector.show_way(Families.name_of(family), reasons, _pin_up, kind, result, "\n".join(notes))
	# NARROW: the card stands in the content row in the card grid's place (UI-BUILD's geometry).
	_scroll.visible = _profile != UiLayout.PROFILE_NARROW


func piece_armed() -> bool:
	"""Whether a click places a piece of furniture now (an item card chosen on an underground level, decision 1921, or
	on the Surface for a Mound room's floor, decision 2002)."""
	return _chosen != null and _chosen.kind == BuildCatalog.CARD_ITEM and _level >= 0 and _level <= LevelBar.LEVEL_DEEPEST


func edge_armed() -> bool:
	"""Whether a click places a Mound's front door or window now (its card chosen on a level that has one)."""
	return _chosen != null and _chosen.kind == BuildCatalog.CARD_EDGE and _level <= LevelBar.LEVEL_DEEPEST


func armed_edge_kind() -> int:
	"""The door or window a click places (build_mound.gd KIND_*; -1: none armed)."""
	return _chosen.edge_kind if edge_armed() else -1


func door_colour() -> int:
	"""The front door's colour chosen (build_mound.gd COLOUR_*; oak by default)."""
	return _door_colour


func choose_colour(colour: int) -> bool:
	"""Choose the front door's colour; false for an unknown one."""
	if colour < 0 or colour >= Mound.COLOUR_NAMES.size():
		return false
	_door_colour = colour
	_sync_tools()
	_sync_info()
	return true


func _colour_strip() -> bool:
	"""Whether the tool strip offers the door's colours (the Front door card chosen on the Furnish tab)."""
	return _chosen != null and _chosen.kind == BuildCatalog.CARD_EDGE and _chosen.edge_kind == Mound.KIND_DOOR


func armed_item() -> int:
	"""The item a click places (-1: none armed)."""
	return _chosen.item_type if piece_armed() else -1


func set_room_lines(text: String) -> void:
	"""The dug rooms' lines in words, from the host (shown under the info card on Furnish and Decor)."""
	if text == _room_lines:
		return
	_room_lines = text
	_sync_info()


func clear_choice() -> void:
	"""Disarm the chosen card (the host left painting)."""
	cancel_pin()
	_chosen = null
	_sync_tools()
	_sync_cards()
	_sync_info()


func row_cards() -> Array[BuildCatalog.Card]:
	"""The cards the row shows now."""
	return _cards


func card_button(index: int) -> Button:
	"""The row's button `index` (null past the pool)."""
	return _card_buttons[index] if index >= 0 and index < _card_buttons.size() else null


func _fill_cards() -> void:
	"""The tab's cards for the level, into the pooled buttons (cold: on a tab, level or choice change)."""
	if _catalog == null:
		return
	_catalog.cards_into(_tab, _level, _furnish_type, _cards, _reachable, _style)
	_shown = null
	_sync_tabs()
	_sync_styles()
	_sync_tools()
	_sync_cards()
	_sync_info()
	_scroll.scroll_horizontal = 0


func _sync_tabs() -> void:
	"""The tab toggles: the one shown pressed; Furnish and Decor disabled, saying why, until a type is chosen."""
	for tab: int in _tabs.size():
		var enabled: bool = tab_enabled(tab)
		_tabs[tab].disabled = not enabled
		_tabs[tab].set_pressed_no_signal(tab == _tab)
		_tabs[tab].accessibility_name = "%s tab %d of %d" % [BuildCatalog.TAB_NAMES[tab], tab + 1, BuildCatalog.TAB_COUNT]
		_tabs[tab].tooltip_text = "" if enabled else BuildCatalog.CHOOSE_FIRST
		_tabs[tab].accessibility_description = _tabs[tab].tooltip_text


func _sync_cards() -> void:
	"""Each pooled button shows its card's words: name, cost, size, and a lock line when locked."""
	_grow_cards(_cards.size())
	for k: int in _card_buttons.size():
		var button: Button = _card_buttons[k]
		button.visible = k < _cards.size()
		if not button.visible:
			continue
		var card: BuildCatalog.Card = _cards[k]
		var lock: String = "" if card.usable() else "\n%s %s" % [Validity.glyph(card.lock_kind), lock_head(card)]
		var mark: String = "✓ " if _chosen != null and card.id == _chosen.id else ""
		button.text = "%s%s\n%s%s" % [mark, card.name, card.footprint, lock]
		button.accessibility_name = card.accessible_name()
		button.tooltip_text = card.accessible_name()


static func lock_head(card: BuildCatalog.Card) -> String:
	"""A locked card's short reason, its words before the colon ("Not yet", "No way in", "Choose one level to paint
	on"); the whole reason is in the info card and the accessible name."""
	return card.locked.get_slice(":", 0)


func _on_card_pressed(index: int) -> void:
	"""A card was clicked or pressed with Enter."""
	choose_card(index)


func _show_card(index: int) -> void:
	"""The info card follows the hovered or focused card (-1: back to the chosen one)."""
	_shown = _cards[index] if index >= 0 and index < _cards.size() else null
	_sync_info()


func _sync_info() -> void:
	"""UI-BUILD-004: picture description, purpose, cost, rules and gesture; "Choose a room type to begin" with none
	("Choose a piece to place" on Furnish and Decor); there, the dug rooms' lines under it (decision 1921)."""
	var card: BuildCatalog.Card = _shown if _shown != null else _chosen
	var rooms: String = "\n%s" % _room_lines if _tab != BuildCatalog.TAB_ROOMS and not _room_lines.is_empty() else ""
	if card == null:
		var none: String = BuildCatalog.NOTHING_CHOSEN if _tab == BuildCatalog.TAB_ROOMS else BuildCatalog.CHOOSE_PIECE
		_info_text.text = none + rooms
		_info.accessibility_name = none
		return
	var lock: String = "" if card.usable() else "\n%s" % Validity.line(card.lock_kind, card.locked)
	var gesture: String = _gesture_of(card)
	_info_text.text = "%s\n%s\n%s\n%s%s\n%s%s" % [card.name, card.purpose, card.cost, card.rules, lock, gesture, rooms]
	_info.accessibility_name = "%s; %s; %s; %s; %s; %s" % [PICTURE % card.picture, card.name, card.purpose, card.cost,
		card.rules, gesture]
	_info.tooltip_text = "%s\n%s" % [PICTURE % card.picture, gesture]


func _gesture_of(card: BuildCatalog.Card) -> String:
	"""The chosen room type's tool and its gesture ("Tool: Oval. Drag the box an oval fills; ..."), the chosen front
	door's colour ("Colour: Oak. Click ..."), else the card's."""
	if _chosen == null or card.id != _chosen.id or _batch == null:
		return card.gesture
	if _colour_strip():
		return COLOUR_LINE % [Mound.colour_name(_door_colour), card.gesture]
	return TOOL_LINE % [Stroke.TOOL_NAMES[_batch.tool()], Stroke.TOOL_GESTURES[_batch.tool()]]


func info_text() -> String:
	"""What the info card says now (checks)."""
	return _info_text.text


# --- the footer -----------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	"""Redraw the batch's words only when it changed (two integer compares a frame; no allocation otherwise)."""
	if visible:
		refresh(false)


func refresh(force: bool) -> void:
	"""Re-read the batch: the footer, the status words and the accessible names (cold: on a batch change)."""
	if _batch == null or (not force and _batch.revision == _seen_revision and _batch.stroke_revision == _seen_stroke):
		return
	var batch_changed: bool = force or _batch.revision != _seen_revision
	_seen_revision = _batch.revision
	_seen_stroke = _batch.stroke_revision
	_sync_history()
	_sync_confirm()
	if batch_changed:
		_sync_ledger()
	_frame.accessibility_name = ACCESSIBLE % [LevelBar.level_name(_level), _batch.pending_count()]
	if _pinned and batch_changed:
		_sync_connector()
	_question.visible = _question_kind != QUESTION_NONE
	for control: Button in _footer:
		control.visible = not _question.visible


func _sync_history() -> void:
	"""UI-BUILD-006/007: their step in words, or disabled with "Nothing to undo / redo"."""
	_undo.disabled = not _batch.can_undo()
	_undo.accessibility_name = _batch.undo_label()
	_undo.tooltip_text = _batch.undo_label()
	_redo.disabled = not _batch.can_redo()
	_redo.accessibility_name = _batch.redo_label()
	_redo.tooltip_text = _batch.redo_label()
	var pending: int = _batch.pending_count()
	_discard.disabled = pending == 0
	_discard.accessibility_name = "Discard %d pending changes" % pending
	_discard.tooltip_text = _discard.accessibility_name


func _sync_confirm() -> void:
	"""UI-BUILD-008: "Confirm all; N changes", disabled naming the first reason and the count while any is invalid."""
	var pending: int = _batch.pending_count()
	var blocked: String = confirm_blocked()
	_confirm.disabled = not blocked.is_empty()
	_confirm.text = "Confirm all (%d)" % pending if pending > 0 else "Confirm all"
	_confirm.accessibility_name = "Confirm all; %d changes" % pending
	_confirm.tooltip_text = blocked if not blocked.is_empty() else _confirm.accessibility_name
	_confirm.accessibility_description = blocked
	_status.text = status_words(blocked)
	_status.tooltip_text = _status.text


func status_words(blocked: String) -> String:
	"""The status line: why Confirm all is held back; else a room the route refused last time (retried by Confirm
	all); else how many changes are ready; else none pending."""
	var pending: int = _batch.pending_count()
	if pending == 0:
		return NONE_PENDING
	if not blocked.is_empty():
		return blocked
	var refused: int = _batch.first_refused()
	if refused >= 0:
		return RETRY % [BuildCatalog.type_name(_batch.operation_type(refused)), _batch.operation_reason(refused)]
	return READY % pending


func confirm_blocked() -> String:
	"""Why Confirm all is disabled ("" when it is not): nothing pending, a stroke in progress, or the first invalid
	operation's reason and how many are invalid."""
	if _batch.stroke_active():
		return FINISH_STROKE
	if _batch.pending_count() == 0:
		return NOTHING_TO_CONFIRM
	var first: int = _batch.first_invalid()
	if first >= 0:
		var kind: int = _batch.operation_kind(first)
		return NOT_READY % [Validity.glyph(kind), _batch.invalid_count(), _batch.pending_count(),
			BuildCatalog.type_name(_batch.operation_type(first)), _batch.operation_reason(first)]
	var item: int = _batch.first_invalid_item()
	if item >= 0:
		return NOT_READY % [Validity.glyph(_batch.item_kind(item)), _batch.invalid_count(), _batch.pending_count(),
			_batch.items().name_of_row(item), _batch.item_reason(item)]
	var piece: int = _batch.first_invalid_piece()
	if piece >= 0:
		return NOT_READY % [Validity.glyph(_batch.piece_kind(piece)), _batch.invalid_count(), _batch.pending_count(),
			Furniture.name_of(_batch.furniture().item_of(piece)), _batch.piece_reason(piece)]
	var edge: int = _batch.first_invalid_edge()
	if edge < 0:
		return ""
	return NOT_READY % [Validity.glyph(_batch.edge_kind(edge)), _batch.invalid_count(), _batch.pending_count(),
		Mound.kind_name(_batch.mound_edges().kind_of(edge)), _batch.edge_reason(edge)]


func _sync_ledger() -> void:
	"""UI-BUILD-005: the short form on the button, the full one when expanded and in the accessible name."""
	var cells: int = _sum_tally()
	var any: bool = cells > 0 or _batch.furniture().live_count() > 0 or _batch.mound_edges().live_count() > 0 \
		or _batch.items().live_count() > 0
	var wood: int = int(_stock.call(&"wood")) if _stock.is_valid() else 0
	var stone: int = int(_stock.call(&"stone")) if _stock.is_valid() else 0
	var summary: String = Ledger.summary_of(_tally, any, wood, stone)
	_ledger.accessibility_name = summary
	_ledger.tooltip_text = summary
	_ledger.text = _short_ledger(any) + (" ▾" if _ledger.button_pressed else " ▴")
	_ledger_text.text = ledger_lines(summary)
	_place_ledger_open()


func _sum_tally() -> int:
	"""Every pending operation's cells into `_tally`, each at its own level's clear height, and the pending furniture's
	wood, stone and work (its other goods are the expanded ledger's furniture line); returns the cells."""
	_tally.resize(Ledger.SLOTS)
	_tally.fill(0)
	var cells: int = 0
	for k: int in _batch.operation_count():
		var count: int = _batch.operation_cell_count(k)
		if count > 0:
			Ledger.add_into(count, _catalog.clear_height_of(_batch.operation_level(k)), _tally)
			cells += count
	var items: Items = _batch.items()
	for row: int in items.count():
		if items.is_live(row) and not items.is_removal(row):
			Families.bill_into(items.family_of(row), _tally)
	_tally[Ledger.WORK] += _batch.furniture().bill_into(_goods, _goods_milli)
	for at: int in _goods.size():
		if _goods[at] == "wood" or _goods[at] == "stone":
			_tally[Ledger.WOOD if _goods[at] == "wood" else Ledger.STONE] += _goods_milli[at]
	return cells


func _short_ledger(any: bool) -> String:
	"""The collapsed ledger (`_tally` already summed): "Plan: 24 logs · 24 blocks · work about 6.8 hours" -- all of it
	is in the expanded view."""
	if not any:
		return "Plan: nothing yet"
	return "Plan: %s · %s\nwork %s" % [Measures.need_cell(&"wood", _tally[Ledger.WOOD]),
		Measures.need_cell(&"stone", _tally[Ledger.STONE]), Ledger.work_text(int(_tally[Ledger.WORK]))]


func ledger_lines(summary: String) -> String:
	"""The expanded ledger: one line per room type ("Kitchen (+24 cells)"), each operation's validity, the totals."""
	var lines: PackedStringArray = PackedStringArray()
	_batch.type_cells_into(_types, _type_cells)
	for at: int in _types.size():
		lines.append(Ledger.line(BuildCatalog.type_name(_types[at]), _type_cells[at]))
	for k: int in _batch.operation_count():
		if _batch.operation_cell_count(k) > 0:
			lines.append("%s · %s" % [LevelBar.SHORT_NAMES[_batch.operation_level(k)], _batch.operation_line(k)])
	_item_lines(lines)
	_piece_lines(lines)
	_mound_lines(lines)
	lines.append(summary)
	return "\n".join(lines)


func _item_lines(lines: PackedStringArray) -> void:
	"""Each pending way ("Surface · Burrow mouth (down to Underground level 1; placeholder, free for now): ✓ Can build")
	and removal ("Level 1 · Remove Hatch with ladder: X Not possible: Would cut off ...")."""
	var items: Items = _batch.items()
	for row: int in items.count():
		if not items.is_live(row):
			continue
		var where: String = LevelBar.SHORT_NAMES[items.level_of(row)]
		var result: String = Validity.line(_batch.item_kind(row), _batch.item_reason(row))
		if items.is_removal(row):
			lines.append(REMOVAL_LINE % [where, items.name_of_row(row), result])
		else:
			lines.append(ITEM_LINE % [where, items.name_of_row(row), "down to %s" % LevelBar.level_name(
				items.level_of(row) + 1), result])


func _mound_lines(lines: PackedStringArray) -> void:
	"""Decision 2002: each pending door, window or removal ("Surface · Front door, oak (free for now): ✓ Can build"), and
	the Mounds' heap in the ruled measures (P-2001-3: five quanta heaped over a room cell, four dug back out), free."""
	var edges: MoundEdges = _batch.mound_edges()
	for row: int in edges.count():
		if not edges.is_live(row):
			continue
		var kind: int = edges.kind_of(row)
		var colour: String = ", %s" % Mound.colour_name(edges.colour_of(row)).to_lower() if kind == Mound.KIND_DOOR \
			and not edges.is_removal(row) else ""
		var named: String = ("Remove " if edges.is_removal(row) else "") + Mound.kind_name(kind)
		lines.append(EDGE_LINE % [LevelBar.SHORT_NAMES[edges.level_of(row)], named, colour,
			Validity.line(_batch.edge_kind(row), _batch.edge_reason(row))])
	var mound_cells: int = 0
	for k: int in _batch.operation_count():
		if _batch.operation_style(k) == Mound.STYLE_MOUND:
			mound_cells += _batch.operation_cell_count(k)
	if mound_cells > 0:
		lines.append(HEAP_LINE % mound_cells)


func _piece_lines(lines: PackedStringArray) -> void:
	"""Each pending piece ("L1 · Kitchen bench, turned once (free for now): ✓ Can build") and the furniture's whole
	bill in its own goods (decision 1921: the ledger shows the bill; nothing is deducted)."""
	var pieces: Furniture = _batch.furniture()
	for row: int in pieces.count():
		if not pieces.is_live(row):
			continue
		var item: int = pieces.item_of(row)
		var turned: String = Furniture.turn_words(pieces.is_edge(item), pieces.turn_of(row))
		lines.append(PIECE_LINE % [LevelBar.SHORT_NAMES[pieces.level_of(row)], Furniture.name_of(item),
			", " + turned if not turned.is_empty() else "", Validity.line(_batch.piece_kind(row), _batch.piece_reason(row))])
	var work: int = pieces.bill_into(_goods, _goods_milli)
	if pieces.live_count() == 0:
		return
	var parts: PackedStringArray = PackedStringArray()
	for at: int in _goods.size():
		parts.append(Measures.need(StringName(_goods[at]), _goods_milli[at]))
	lines.append(FURNITURE_BILL % [", ".join(parts), Ledger.work_text(work)])


func toggle_ledger() -> void:
	"""Expand or fold the ledger. Expanded, it covers the tab row, so the tabs and the where/status words are hidden
	with it (none of them clickable or showing beside it) and come back when it folds (decision 1871 E18)."""
	_show_ledger(_ledger.button_pressed)
	refresh(true)


func _show_ledger(expanded: bool) -> void:
	"""The expanded ledger shown or folded, the tab row's controls the other way round."""
	_ledger.set_pressed_no_signal(expanded)
	_ledger_open.visible = expanded
	for tab: Button in _tabs:
		tab.visible = not expanded
	_where.visible = not expanded
	_status.visible = not expanded


func ledger_expanded() -> bool:
	"""Whether the ledger is expanded."""
	return _ledger_open.visible


func set_ledger_expanded(expanded: bool) -> void:
	"""Expand or fold the ledger (the keyboard's way, and checks)."""
	_ledger.button_pressed = expanded
	toggle_ledger()


func _on_undo() -> void:
	"""Undo one step of the batch."""
	_batch.undo()
	refresh(true)


func _on_redo() -> void:
	"""Redo one step of the batch."""
	_batch.redo()
	refresh(true)


func _on_confirm() -> void:
	"""Confirm all, when nothing holds it back: the host orders the batch through its route."""
	if confirm_blocked().is_empty():
		confirm_requested.emit()


func ask_discard() -> void:
	"""Discard all: asks once when there is anything to discard."""
	if _batch.pending_count() > 0:
		_ask(QUESTION_DISCARD)


func _ask(kind: int) -> void:
	"""Show one question in the footer's place and give its first answer the focus."""
	_question_kind = kind
	var pending: int = _batch.pending_count()
	_question_text.text = KEEP_QUESTION % pending if kind == QUESTION_CLOSE else DISCARD_QUESTION % pending
	_question_yes.text = "Keep" if kind == QUESTION_CLOSE else "Discard all"
	_question_no.text = "Discard" if kind == QUESTION_CLOSE else "Keep them"
	refresh(true)
	if is_inside_tree():
		_question_yes.grab_focus()


func question() -> int:
	"""The question shown (QUESTION_*)."""
	return _question_kind


func question_text() -> String:
	"""The question's words (checks)."""
	return _question_text.text


func answer(yes: bool) -> void:
	"""Answer the question shown: Keep closes keeping the batch, Discard closes discarding it; for Discard all, yes
	discards and no keeps."""
	_answer(yes)


func _answer(yes: bool) -> void:
	"""See `answer`."""
	var kind: int = _question_kind
	_question_kind = QUESTION_NONE
	if kind == QUESTION_CLOSE:
		if not yes:
			_batch.discard_all()
		_finish_close(yes)
	elif kind == QUESTION_DISCARD and yes:
		_batch.discard_all()
	refresh(true)


func escape() -> bool:
	"""Escape, one layer: the stroke in progress, an open question, the expanded ledger, then the panel (asking about
	pending changes). False when the panel was not open."""
	if not visible:
		return false
	if _batch.cancel_stroke():
		refresh(true)
	elif _pinned:
		cancel_pin()
	elif _question_kind != QUESTION_NONE:
		_question_kind = QUESTION_NONE
		refresh(true)
	elif _ledger_open.visible:
		set_ledger_expanded(false)
	else:
		request_close()
	return true


func frame_rect() -> Rect2:
	"""Where the panel stands, logical px."""
	return _panel_rect


func screen_rect() -> Rect2:
	"""Where the panel is drawn, viewport px."""
	return Rect2(_panel_rect.position * scale, _panel_rect.size * scale)


func ledger_rect() -> Rect2:
	"""Where the expanded ledger is drawn, viewport px (empty when folded)."""
	if not _ledger_open.visible:
		return Rect2()
	return Rect2(_ledger_open.position * scale, _ledger_open.size * scale)


func controls() -> Dictionary:
	"""The panel's named controls (checks and the host's focus region)."""
	return {&"tabs": _tabs, &"ledger": _ledger, &"undo": _undo, &"redo": _redo, &"discard": _discard,
		&"confirm": _confirm, &"yes": _question_yes, &"no": _question_no, &"status": _status, &"where": _where,
		&"frame": _frame, &"info": _info, &"ledger_scroll": _ledger_scroll, &"cards": _scroll, &"connector": _connector}
