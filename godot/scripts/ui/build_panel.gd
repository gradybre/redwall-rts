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
## TABS. Furnish and Decor stay disabled, saying "Choose a room type first", until a room type or Passage is chosen;
## Ctrl+Tab / Ctrl+Shift+Tab cycle the enabled ones (`cycle_tab`). CARDS: arrow keys move along the row and Enter
## chooses (Godot's own focus and press); a locked card is chosen for INSPECTION only -- the info card says why it is
## locked. The info card follows the hovered or focused card, else the chosen one, else "Choose a room type to begin".
## FOOTER. The ledger button expands upward into the per-type lines, every operation's validity and the totals;
## Undo / Redo name their step or say "Nothing to undo / redo"; Discard all asks once when there is anything to
## discard; Confirm all is disabled while a stroke is in progress or any operation is invalid, naming the first reason
## and the count. CLOSING with pending changes asks "Keep N pending changes?" (Keep / Discard). The questions sit in the
## footer's place. ESCAPE (`escape`): the stroke in progress, then an open question, then the expanded ledger, then
## the panel (the connector card, UI-BUILD-012, comes with slice D).

const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const BuildLayout := preload("res://scripts/ui/build_layout.gd")
const Ledger := preload("res://scripts/ui/build_ledger.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const LevelBar := preload("res://scripts/ui/level_bar.gd")
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
const NONE_PENDING: String = "No pending changes"
const PICTURE: String = "Picture (placeholder): %s"

## A card was clicked or pressed with Enter (a locked one too: the host may only show it).
signal card_chosen(card: BuildCatalog.Card)
## Confirm all was pressed with every operation valid.
signal confirm_requested
## The panel closed: `kept` false when its pending changes were discarded on the way.
signal closed(kept: bool)

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
var _ledger: Button = null
var _ledger_open: Panel = null
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
	_build_info()
	_build_cards()
	_build_footer()
	_build_question()
	_build_ledger_open()


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
	for k: int in CARD_POOL:
		var card: Button = Button.new()
		card.name = "UI-BUILD-003-%d" % k
		card.theme_type_variation = &"WoodlandButton"
		card.focus_mode = Control.FOCUS_ALL
		card.clip_text = false
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override(&"font_size", TEXT_PX)
		card.custom_minimum_size = Vector2(BuildLayout.CARD_MIN_WIDTH, BuildLayout.CONTENT_HEIGHT - 12.0)
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
	"""UI-BUILD-005 expanded: a panel above the footer, growing upward."""
	_ledger_open = Panel.new()
	_ledger_open.name = "UI-BUILD-005-open"
	_ledger_open.theme_type_variation = &"WoodlandPanel"
	_ledger_open.mouse_filter = Control.MOUSE_FILTER_STOP
	_ledger_open.visible = false
	add_child(_ledger_open)
	_ledger_text = Label.new()
	_ledger_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger_text.add_theme_font_size_override(&"font_size", TEXT_PX)
	_ledger_open.add_child(_ledger_text)


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


func _place_tabs() -> void:
	"""Three tabs from the left of the tabs row; the words in the rest of it."""
	var row: Rect2 = BuildLayout.tabs_rect(_panel_rect.size.x)
	var width: float = BuildLayout.TAB_MAX_WIDTH if row.size.x >= 900.0 else BuildLayout.TAB_MIN_WIDTH + 24.0
	for tab: int in _tabs.size():
		_tabs[tab].position = row.position + Vector2(tab * (width + BuildLayout.GAP), 0.0)
		_tabs[tab].size = Vector2(width, row.size.y)
	var x: float = row.position.x + _tabs.size() * (width + BuildLayout.GAP) + BuildLayout.GAP
	var words_width: float = maxf(row.end.x - x, 0.0)
	_where.position = Vector2(x, row.position.y)
	_where.size = Vector2(words_width, row.size.y / 2.0)
	_status.position = Vector2(x, row.position.y + row.size.y / 2.0)
	_status.size = Vector2(words_width, row.size.y / 2.0)


func _place_content() -> void:
	"""The info card and the card row."""
	var info: Rect2 = BuildLayout.info_rect(_profile)
	_info.position = info.position
	_info.size = info.size
	_info_scroll.position = Vector2(8.0, 6.0)
	_info_scroll.size = info.size - Vector2(12.0, 12.0)
	_info_text.custom_minimum_size.x = info.size.x - 32.0
	var cards: Rect2 = BuildLayout.cards_rect(_panel_rect.size.x, _profile)
	_scroll.position = cards.position
	_scroll.size = cards.size
	var width: float = BuildLayout.CARD_MAX_WIDTH if _profile == UiLayout.PROFILE_WIDE else BuildLayout.CARD_MIN_WIDTH
	for card: Button in _card_buttons:
		card.custom_minimum_size = Vector2(width, BuildLayout.CONTENT_HEIGHT - 12.0)


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
	"""The expanded ledger above the footer's left, growing upward from it."""
	var lines: int = maxi(_ledger_text.get_line_count(), 1)
	var open: Vector2 = BuildLayout.ledger_open_size(lines, float(TEXT_PX + 6), _profile)
	var footer: Rect2 = BuildLayout.footer_rect(_panel_rect.size.x)
	var bottom: float = _panel_rect.position.y + footer.position.y - BuildLayout.GAP
	_ledger_open.position = Vector2(_panel_rect.position.x + footer.position.x, bottom - open.y)
	_ledger_open.size = open
	_ledger_text.position = Vector2(BuildLayout.PADDING, BuildLayout.PADDING)
	_ledger_text.size = open - 2.0 * Vector2(BuildLayout.PADDING, BuildLayout.PADDING)


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
	"""Whether the panel is open (suspended or not)."""
	return visible


func suspend(value: bool) -> void:
	"""Hide the panel's frame without closing it (the host ran one of the old tools from a card); the batch, the tab
	and the choice stay."""
	_frame.visible = not value
	if value:
		_ledger_open.visible = false
		_ledger.button_pressed = false


func suspended() -> bool:
	"""Whether the open panel is suspended behind an old tool."""
	return visible and not _frame.visible


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
	_chosen = null
	_furnish_type = -1
	_tab = BuildCatalog.TAB_ROOMS
	_question_kind = QUESTION_NONE
	_ledger.button_pressed = false
	_ledger_open.visible = false
	closed.emit(kept)


func set_level(level: int, reachable: bool = true) -> void:
	"""The level the panel builds on, and whether it has a way in: its cards and words follow (the pending batch keeps
	every level's changes)."""
	if level == _level and reachable == _reachable and not _cards.is_empty():
		return
	_level = level
	_reachable = reachable
	_where.text = WHERE % LevelBar.level_name(level)
	if _chosen != null and not _card_still_usable():
		_chosen = null
	_fill_cards()


func building_level() -> int:
	"""The level the panel builds on."""
	return _level


func _card_still_usable() -> bool:
	"""Whether the chosen card is usable on the level now shown (a room type is locked on the surface)."""
	_catalog.cards_into(BuildCatalog.TAB_ROOMS, _level, _furnish_type, _cards, _reachable)
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
	if card.usable() and (card.kind == BuildCatalog.CARD_ROOM or card.kind == BuildCatalog.CARD_LEGACY):
		_chosen = card if card.kind == BuildCatalog.CARD_ROOM else null
		if card.room_type >= 0:
			_furnish_type = card.room_type
	_shown = card
	_sync_tabs()
	_sync_cards()
	_sync_info()
	card_chosen.emit(card)


func chosen_card() -> BuildCatalog.Card:
	"""The room-type card armed for painting (null: none)."""
	return _chosen


func paint_type() -> int:
	"""The room type a stroke paints now, or -1 (none chosen, or not paintable on this level)."""
	return _chosen.room_type if _chosen != null and _level >= 1 and _level <= LevelBar.LEVEL_DEEPEST else -1


func clear_choice() -> void:
	"""Disarm the chosen card (the host left painting)."""
	_chosen = null
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
	_catalog.cards_into(_tab, _level, _furnish_type, _cards, _reachable)
	_shown = null
	_sync_tabs()
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
	for k: int in _card_buttons.size():
		var button: Button = _card_buttons[k]
		button.visible = k < _cards.size()
		if not button.visible:
			continue
		var card: BuildCatalog.Card = _cards[k]
		var lock: String = "" if card.usable() else "\n%s %s" % [Validity.glyph(Validity.KIND_BLOCKED), "Not yet"]
		var mark: String = "✓ " if _chosen != null and card.id == _chosen.id else ""
		button.text = "%s%s\n%s%s" % [mark, card.name, card.footprint, lock]
		button.accessibility_name = card.accessible_name()
		button.tooltip_text = card.accessible_name()


func _on_card_pressed(index: int) -> void:
	"""A card was clicked or pressed with Enter."""
	choose_card(index)


func _show_card(index: int) -> void:
	"""The info card follows the hovered or focused card (-1: back to the chosen one)."""
	_shown = _cards[index] if index >= 0 and index < _cards.size() else null
	_sync_info()


func _sync_info() -> void:
	"""UI-BUILD-004: picture description, purpose, cost, rules and gesture; "Choose a room type to begin" with none."""
	var card: BuildCatalog.Card = _shown if _shown != null else _chosen
	if card == null:
		_info_text.text = BuildCatalog.NOTHING_CHOSEN
		_info.accessibility_name = BuildCatalog.NOTHING_CHOSEN
		return
	var lock: String = "" if card.usable() else "\n%s" % Validity.line(Validity.KIND_BLOCKED, card.locked)
	_info_text.text = "%s\n%s\n%s\n%s%s" % [card.name, card.purpose, card.cost, card.rules, lock]
	_info.accessibility_name = "%s; %s; %s; %s; %s; %s" % [PICTURE % card.picture, card.name, card.purpose, card.cost,
		card.rules, card.gesture]
	_info.tooltip_text = "%s\n%s" % [PICTURE % card.picture, card.gesture]


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
	_seen_revision = _batch.revision
	_seen_stroke = _batch.stroke_revision
	_sync_history()
	_sync_confirm()
	_sync_ledger()
	_frame.accessibility_name = ACCESSIBLE % [LevelBar.level_name(_level), _batch.pending_count()]
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
	_status.text = blocked if not blocked.is_empty() and pending > 0 else (READY % pending if pending > 0 else NONE_PENDING)
	_status.tooltip_text = _status.text


func confirm_blocked() -> String:
	"""Why Confirm all is disabled ("" when it is not): nothing pending, a stroke in progress, or the first invalid
	operation's reason and how many are invalid."""
	if _batch.stroke_active():
		return FINISH_STROKE
	if _batch.pending_count() == 0:
		return NOTHING_TO_CONFIRM
	var first: int = _batch.first_invalid()
	if first < 0:
		return ""
	var kind: int = _batch.operation_kind(first)
	return NOT_READY % [Validity.glyph(kind), _batch.invalid_count(), _batch.pending_count(),
		BuildCatalog.type_name(_batch.operation_type(first)), _batch.operation_reason(first)]


func _sync_ledger() -> void:
	"""UI-BUILD-005: the short form on the button, the full one when expanded and in the accessible name."""
	var cells: int = _batch.total_cells()
	var wood: int = int(_stock.call(&"wood")) if _stock.is_valid() else 0
	var stone: int = int(_stock.call(&"stone")) if _stock.is_valid() else 0
	var summary: String = Ledger.summary(cells, _catalog_height(), wood, stone, _tally)
	_ledger.accessibility_name = summary
	_ledger.tooltip_text = summary
	_ledger.text = _short_ledger(cells) + (" ▾" if _ledger.button_pressed else " ▴")
	_ledger_text.text = ledger_lines(summary)
	_place_ledger_open()


func _catalog_height() -> int:
	"""The clear height the catalog prices cells at."""
	return _catalog.clear_height() if _catalog != null else Ledger.DEFAULT_CLEAR_HEIGHT_U


func _short_ledger(cells: int) -> String:
	"""The collapsed ledger: "Plan: 24 logs · 24 blocks · work about 6.8 hours" (all of it is in the expanded view)."""
	if cells <= 0:
		return "Plan: nothing yet"
	Ledger.totals_into(cells, _catalog_height(), _tally)
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
	lines.append(summary)
	return "\n".join(lines)


func toggle_ledger() -> void:
	"""Expand or fold the ledger."""
	_ledger_open.visible = _ledger.button_pressed
	refresh(true)


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
		&"frame": _frame, &"info": _info}
