extends CanvasLayer
## The Map layer picker: which map layer shows, picked directly by its question, with the active one's
## name, subject, question and legend always in view. Decision 0292 (the review's F47 and UX-009). DEMO
## UI in the woodland skin; it switches what is drawn (demo/map_lenses.gd) and nothing else.
##
## WHAT. A header button naming the shown layer -- "Getting there: Water range ▾", or "Map layer: off ▾"
## -- which unfolds the list, and "Off". The list has one button per layer, its group first (Growing,
## Getting there, Woods, Underground), its question as the tooltip; pressing one shows it alone, pressing
## the shown one (or Off) shows none, and the list folds away. While a layer shows, the card under the
## header gives its ONE question, its subject when it has one ("Water range for: all 3 selected", with ◀ ▶
## to step through a group's members), what they can do there, and a small legend of swatches and words.
## V steps the same active layer (demo_farm.gd) and U the Underground one (map_lenses.gd follows it), so
## the picker always names what the map shows.
##
## WHERE. UI §1.1's bottom-left zone, "Minimap + layers" (UI-SET-022, "Map layers", belongs with the
## minimap), growing upward from its bottom edge (`slot_rect`), always just right of the demo party
## panel's column so that growing up never meets it: down on the command strip's top where the space
## left of the news strip's band is wide enough (1920x1080), else just above the bottom band (1280x720,
## where the news band leaves too little beside it, and whenever the journal pushes the band left). It
## never covers the minimap, the news strip, the command strip or the party panel (which at 1280x720
## fills its column with anyone selected, so the picker cannot share it). The slot follows the viewport
## alone, so the picker does not jump as layers change. The news band comes from the strip's own static
## equation (`band_placement`), so nothing of the strip's state is touched.
## Geometry is the HUD's own (scripts/ui/ui_layout.gd, read, never modified) in LOGICAL pixels at the
## HUD's scale. It draws below the HUD's layer, as the party panel does, so a modal covers it.
##
## Refreshed a few times a second on real time (it reads while paused); it re-texts labels and builds
## nothing after the legends are made (once per layer).

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const LensesScript := preload("res://demo/map_lenses.gd")
const PartyScript := preload("res://demo/control/demo_party_panel.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const SubjectScript := preload("res://demo/lens_subject.gd")

const TITLE: String = "Map layer"
const LIST_CLOSED: String = "▾"
const LIST_OPEN: String = "▴"
const KEY_HINT: String = "V steps through the layers · U switches the underground view"
## Its width above the bottom band, and at most beside the minimap; the carved frame's overhang.
const WIDTH: float = 340.0
const MAX_WIDTH: float = 440.0
const FRAME_EXPAND: float = 10.0
## Kept clear of the minimap, the news band, the command strip and the party panel's column.
const GAP: float = 8.0
## UI §2's interactive floor: every button at least this tall.
const TARGET_PX: float = 32.0
## UI §2: 14 px is the floor for any text; body text at the farm's 15.
const NOTE_PX: int = 14
const SWATCH_PX: float = 14.0
const REFRESH_S: float = 0.25

var _lenses: LensesScript = null
var _journal_open: Callable = Callable()
var _frame: PanelContainer = null
var _list_button: Button = null
var _off: Button = null
var _list: VBoxContainer = null
var _lens_buttons: Array[Button] = []
var _card: VBoxContainer = null
var _question: Label = null
var _subject_row: HBoxContainer = null
var _subject: Label = null
var _prev: Button = null
var _next: Button = null
var _notes: Label = null
var _legend_box: VBoxContainer = null
var _legends: Array[HFlowContainer] = []
var _refresh_in: float = 0.0
var _seen_subject: int = -1
var _seen_revision: int = -1
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(lenses: LensesScript, journal_open: Callable = Callable()) -> void:
	"""Pick among `lenses`; `journal_open() -> bool` says whether the resident journal holds the right column
	(demo_detail_zone.gd), which moves the news strip's band the picker keeps clear of (none: never). The
	band is worked out here from the strip's own static equation, so nothing of the strip's is touched."""
	_lenses = lenses
	_journal_open = journal_open
	name = "DemoLensPicker"
	layer = 0
	_build()
	refresh()


func _ready() -> void:
	"""Follow the viewport's size."""
	get_viewport().size_changed.connect(_place)
	_place()


func _build() -> void:
	"""The header, the folded list and the card."""
	_frame = FarmUi.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	column.add_child(_build_header())
	_list = _build_list()
	column.add_child(_list)
	_card = _build_card()
	column.add_child(_card)


func _build_header() -> HBoxContainer:
	"""'Map layer: <title>', the list's button and Off."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	_list_button = _button("")
	_list_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list_button.tooltip_text = "Choose a map layer by the question it answers"
	_list_button.pressed.connect(toggle_list)
	row.add_child(_list_button)
	_off = _button("Off")
	_off.tooltip_text = "Show no map layer"
	_off.pressed.connect(choose.bind(LensesScript.OFF))
	row.add_child(_off)
	return row


func _build_list() -> VBoxContainer:
	"""One button per layer, made as layers are added (`_ensure_rows`); folded at first."""
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 4)
	list.add_child(FarmUi.label(KEY_HINT, NOTE_PX, Palette.UMBER))
	list.visible = false
	return list


func _build_card() -> VBoxContainer:
	"""The shown layer's question, subject (with the group stepper), notes and legend."""
	var card := VBoxContainer.new()
	card.add_theme_constant_override(&"separation", 4)
	_question = FarmUi.label("", NOTE_PX, Palette.UMBER)
	card.add_child(_question)
	_subject_row = HBoxContainer.new()
	_subject_row.add_theme_constant_override(&"separation", 6)
	_subject = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	_subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subject_row.add_child(_subject)
	_prev = _stepper("◀", "The group, or the member before", -1)
	_next = _stepper("▶", "The next member, or the whole group", 1)
	card.add_child(_subject_row)
	_notes = FarmUi.label("", NOTE_PX, Palette.INK)
	card.add_child(_notes)
	_legend_box = VBoxContainer.new()
	card.add_child(_legend_box)
	return card


func _button(text: String) -> Button:
	"""A wood button at least TARGET_PX tall."""
	var made: Button = FarmUi.button(text)
	made.custom_minimum_size.y = TARGET_PX
	return made


func _stepper(text: String, tip: String, delta: int) -> Button:
	"""One of the subject's ◀ ▶ buttons, at least 32 px square (UI §2's target floor)."""
	var made: Button = FarmUi.button(text)
	made.custom_minimum_size = Vector2(TARGET_PX, TARGET_PX)
	made.tooltip_text = tip
	made.pressed.connect(step_subject.bind(delta))
	_subject_row.add_child(made)
	return made


func _ensure_rows() -> void:
	"""A list button and a legend for every layer the lenses have (made once each)."""
	while _lens_buttons.size() < _lenses.count() - 1:
		var lens: int = _lens_buttons.size() + 1
		var made: Button = _button(_lenses.title_of(lens))
		made.alignment = HORIZONTAL_ALIGNMENT_LEFT
		made.toggle_mode = true
		made.tooltip_text = _lenses.question_of(lens)
		made.pressed.connect(choose.bind(lens))
		_list.add_child(made)
		_lens_buttons.append(made)
	while _legends.size() < _lenses.count():
		_legends.append(_make_legend(_legends.size()))


func _make_legend(lens: int) -> HFlowContainer:
	"""A layer's legend: a swatch and its words, flowing in rows (words alone for a clear swatch)."""
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 10)
	flow.add_theme_constant_override(&"v_separation", 2)
	var swatches: PackedColorArray = _lenses.swatches_of(lens)
	var words: PackedStringArray = _lenses.words_of(lens)
	for k: int in words.size():
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override(&"separation", 4)
		if k < swatches.size() and swatches[k].a > 0.0:
			var swatch := ColorRect.new()
			swatch.color = Color(swatches[k], 1.0)
			swatch.custom_minimum_size = Vector2(SWATCH_PX, SWATCH_PX)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_child(swatch)
		var word: Label = FarmUi.label(words[k], NOTE_PX, Palette.INK)
		word.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(word)
		flow.add_child(chip)
	flow.visible = false
	_legend_box.add_child(flow)
	return flow


# --- what it does -------------------------------------------------------------------------------

func choose(lens: int) -> void:
	"""Show `lens` alone -- or none, for Off or the layer already shown -- and fold the list."""
	_lenses.select(LensesScript.OFF if lens == _lenses.active else lens)
	_list.visible = false
	refresh()


func toggle_list() -> void:
	"""Unfold or fold the list of layers."""
	_list.visible = not _list.visible
	refresh()


func step_subject(delta: int) -> void:
	"""Step the shown layer's subject (a group, then each member)."""
	_lenses.subject_of(_lenses.active).step(delta)
	refresh()


func _process(delta: float) -> void:
	"""Adopt U's switch at once; re-text a few times a second on real time."""
	if _lenses == null:
		return
	var changed: bool = _lenses.sync()
	var subject: int = _lenses.subject_of(_lenses.active).revision
	_refresh_in -= delta
	if changed or subject != _seen_subject or _lenses.revision != _seen_revision or _refresh_in <= 0.0:
		_seen_subject = subject
		_seen_revision = _lenses.revision
		_refresh_in = REFRESH_S
		refresh()


func refresh() -> void:
	"""Re-text the header, the list's state and the card for the active layer."""
	if _lenses == null:
		return
	_ensure_rows()
	var active: int = _lenses.active
	FarmUi.set_enabled(_off, active != LensesScript.OFF, "No map layer is shown")
	_list_button.text = "%s %s" % [title_text(), LIST_OPEN if _list.visible else LIST_CLOSED]
	for k: int in _lens_buttons.size():
		_lens_buttons[k].set_pressed_no_signal(k + 1 == active)
	_card.visible = active != LensesScript.OFF and not _list.visible
	for k: int in _legends.size():
		_legends[k].visible = k == active
	if _card.visible:
		_fill_card(active)
	_place.call_deferred()


func _fill_card(active: int) -> void:
	"""The active layer's question, subject and notes."""
	_question.text = _lenses.question_of(active)
	var subject: SubjectScript = _lenses.subject_of(active)
	_subject_row.visible = subject.has_subject()
	_subject.text = subject.subject_line()
	_prev.visible = subject.can_step()
	_next.visible = subject.can_step()
	_notes.text = subject.notes()
	_notes.visible = not _notes.text.is_empty()


# --- readouts (tests and the scripted check) ---------------------------------------------------------

func title_text() -> String:
	"""What the picker names as shown: 'Map layer: off', or 'Getting there: Water range'."""
	return "%s: off" % TITLE if _lenses.active == LensesScript.OFF else _lenses.title_of(_lenses.active)


func lens_button(lens: int) -> Button:
	"""The list's button for `lens` (1..)."""
	_ensure_rows()
	return _lens_buttons[lens - 1]


func off_button() -> Button:
	"""The header's Off."""
	return _off


func list_shown() -> bool:
	"""Whether the list of layers is unfolded."""
	return _list.visible


func card_shown() -> bool:
	"""Whether the active layer's card shows."""
	return _card.visible


func question_text() -> String:
	"""The card's question."""
	return _question.text


func subject_text() -> String:
	"""The card's subject line (empty when the layer has none)."""
	return _subject.text if _subject_row.visible else ""


func notes_text() -> String:
	"""The card's notes."""
	return _notes.text if _notes.visible else ""


func stepper_shown() -> bool:
	"""Whether either of the ◀ ▶ subject stepper's buttons shows."""
	return _prev.visible or _next.visible


func subject_shown() -> bool:
	"""Whether the subject line shows."""
	return _subject_row.visible


func notes_shown() -> bool:
	"""Whether the notes show."""
	return _notes.visible


func legend_words(lens: int) -> PackedStringArray:
	"""The words of `lens`'s legend as drawn."""
	var out := PackedStringArray()
	for chip: Node in _legends[lens].get_children():
		out.append((chip.get_child(chip.get_child_count() - 1) as Label).text)
	return out


func legend_shown(lens: int) -> bool:
	"""Whether `lens`'s legend shows."""
	return _legends[lens].visible


func frame_rect() -> Rect2:
	"""The frame's rectangle on screen, in viewport pixels."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


# --- placement --------------------------------------------------------------------------------

func _place() -> void:
	"""In the bottom-left zone (see WHERE), as tall as its content; an unfolded list grows upward from it."""
	if not is_inside_tree() or _frame == null:
		return
	var slot: Rect2 = slot_for(get_viewport().get_visible_rect().size)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.custom_minimum_size = Vector2(slot.size.x, 0.0)
	_frame.size = Vector2(slot.size.x, 0.0)
	var top: float = slot.end.y - _frame.get_combined_minimum_size().y
	_frame.position = Vector2(slot.position.x, top) * _geometry.scale


func slot_for(viewport_size: Vector2) -> Rect2:
	"""The slot (`slot_rect`) for this viewport with the journal as it is now; fills the picker's geometry
	(its scale). The news band is the strip's own static equation: nothing of the strip's is read or set."""
	var journal: bool = _journal_open.is_valid() and bool(_journal_open.call())
	var band: Rect2 = NewsScript.band_placement(int(viewport_size.x), int(viewport_size.y), _layout, _geometry, journal)
	return slot_rect(_geometry, band)


static func slot_rect(geometry: UiLayout.Geometry, news_band: Rect2) -> Rect2:
	"""Where the picker goes, in logical pixels: its x and width, and its BOTTOM edge (it grows upward; the
	height is all the room it has, up to the reserved band). Always right of the party panel's column, so
	growing up never meets it: down on the command strip where the space left of the news band is at least
	WIDTH (1920x1080), else just above the bottom band (1280x720, or the journal open). Chosen by the
	viewport alone, never by what the card shows, so the picker does not jump when a layer changes."""
	var left: float = UiLayout.SAFE_INSET + 2.0 * PartyScript.FRAME_EXPAND + PartyScript.WIDTH + GAP + FRAME_EXPAND
	var top: float = geometry.management_top + FRAME_EXPAND
	var right: float = news_band.position.x - GAP - FRAME_EXPAND if news_band.size.x > 0.0 else geometry.commands.end.x
	if right - left >= WIDTH:
		return Rect2(left, top, minf(right - left, MAX_WIDTH), geometry.commands.position.y - GAP - FRAME_EXPAND - top)
	return Rect2(left, top, WIDTH, geometry.minimap.position.y - GAP - FRAME_EXPAND - top)
