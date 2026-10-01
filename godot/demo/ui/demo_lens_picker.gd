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
##
## THE LEGEND AND THE COMPARED LAYER (decision 0581). Each layer's legend (demo_lens_legend.gd) gives what its ramp
## measures with units, its ramp as one bar with a threshold under each entry, and its keys. COMPARE is the header's
## second button (two overlapping squares, between the layer's name and Off): it unfolds, in the card, the layers that
## can be outlined over the shown one (those with an outlining probe, map_lenses.gd `is_compare_candidate`); picking
## one outlines its areas on the map (demo/lenses/lens_contours.gd), keeps the button pressed and adds a line under
## the legend -- "Outlined: Growing: Water service ✕" -- with that layer's legend drawn as outlines; picking it again,
## or ✕, turns it off. That is the one way in and out; V and the list change the shown layer and keep the compared one
## unless it becomes the shown one. The control sits in the header so the card stays short at 1280x720, where the
## guide's card must fit above the picker (decision 0481).

const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const LensesScript := preload("res://demo/map_lenses.gd")
const PartyScript := preload("res://demo/control/demo_party_panel.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const SubjectScript := preload("res://demo/lens_subject.gd")
const LegendScript := preload("res://demo/ui/demo_lens_legend.gd")

const TITLE: String = "Map layer"
const LIST_CLOSED: String = "▾"
const LIST_OPEN: String = "▴"
const KEY_HINT: String = "V steps through the layers · U switches the underground view"
const COMPARE_TIP: String = "Compare: outline a second layer's areas over this one"
const COMPARE_ON_TEXT: String = "Outlined: %s"
## The compare button's glyph, drawn like the HUD's line icons (24 px, a 2 px cream stroke): a filled square under an
## outlined one -- a layer, and a second outlined over it.
const COMPARE_SVG: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#F5F0DF\" stroke-width=\"2\"><rect x=\"3\" y=\"3\" width=\"12\" height=\"12\" fill=\"#F5F0DF\"/><rect x=\"9\" y=\"9\" width=\"12\" height=\"12\"/></svg>"

## The compare button: wide enough for its glyph inside the wood button's margins; the glyph's size.
const COMPARE_W: float = 42.0
const COMPARE_ICON_PX: int = 20

static var _compare_icon: Texture2D = null
## Its width above the bottom band, and at most beside the minimap; the carved frame's overhang.
const WIDTH: float = 340.0
const MAX_WIDTH: float = 440.0
## The narrowest it may be (decision 0391): the header's "Map layer: …" and Off on one row.
const MIN_WIDTH: float = 280.0
const FRAME_EXPAND: float = 10.0
## Kept clear of the minimap, the news band, the command strip and the party panel's column.
const GAP: float = 8.0
## UI §2's interactive floor: every button at least this tall.
const TARGET_PX: float = 32.0
## UI §2: 14 px is the floor for any text; body text at the farm's 15.
const NOTE_PX: int = 14
const REFRESH_S: float = 0.25

var _lenses: LensesScript = null
var _journal_open: Callable = Callable()
var _frame: PanelContainer = null
var _list_button: Button = null
var _off: Button = null
var _list: VBoxContainer = null
var _header: HBoxContainer = null
## The list and the card scroll under the header where the slot is shorter than they are (125 % and 150 % at
## 1280x720; decision 0391).
var _body: DemoScroll = null
var _place_queued: bool = false
var _lens_buttons: Array[Button] = []
var _card: VBoxContainer = null
var _question: Label = null
var _subject_row: HBoxContainer = null
var _subject: Label = null
var _prev: Button = null
var _next: Button = null
var _notes: Label = null
var _legend_box: VBoxContainer = null
var _legends: Array[LegendScript] = []
var _compare_row: HBoxContainer = null
var _compare_button: Button = null
var _compare_label: Label = null
var _compare_off: Button = null
var _compare_list: VBoxContainer = null
var _compare_buttons: Array[Button] = []
var _outline_box: VBoxContainer = null
var _outline_legends: Array[LegendScript] = []
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
	_header = _build_header()
	column.add_child(_header)
	_body = DemoScroll.new()
	column.add_child(_body)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 6)
	_body.add_child(content)
	_list = _build_list()
	content.add_child(_list)
	_card = _build_card()
	content.add_child(_card)
	content.minimum_size_changed.connect(_queue_place)


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
	_compare_button = _button("")
	_compare_button.custom_minimum_size.x = COMPARE_W
	_compare_button.toggle_mode = true
	_compare_button.icon = compare_icon()
	_compare_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compare_button.add_theme_constant_override(&"icon_max_width", COMPARE_ICON_PX)
	for state: StringName in [&"icon_pressed_color", &"icon_hover_pressed_color"]:
		_compare_button.add_theme_color_override(state, Palette.DEEP_SHADE)
	_compare_button.tooltip_text = COMPARE_TIP
	_compare_button.pressed.connect(toggle_compare_list)
	row.add_child(_compare_button)
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
	_build_compare(card)
	return card


func _build_compare(card: VBoxContainer) -> void:
	"""The compare row (its list's button and ✕), the folded list, and the outlined legends' box."""
	_compare_list = VBoxContainer.new()
	_compare_list.add_theme_constant_override(&"separation", 4)
	_compare_list.visible = false
	card.add_child(_compare_list)
	_compare_row = HBoxContainer.new()
	_compare_row.add_theme_constant_override(&"separation", 6)
	_compare_label = FarmUi.label("", NOTE_PX, Palette.INK, true)
	_compare_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare_row.add_child(_compare_label)
	_compare_off = _button("✕")
	_compare_off.custom_minimum_size.x = TARGET_PX
	_compare_off.tooltip_text = "Stop outlining the second layer"
	_compare_off.pressed.connect(choose_compare.bind(LensesScript.OFF))
	_compare_row.add_child(_compare_off)
	card.add_child(_compare_row)
	_outline_box = VBoxContainer.new()
	card.add_child(_outline_box)


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
		_legends.append(_make_legend(_legends.size(), _legend_box, false))
		_outline_legends.append(_make_legend(_outline_legends.size(), _outline_box, true))
	while _compare_buttons.size() < _lenses.count() - 1:
		var lens: int = _compare_buttons.size() + 1
		var made: Button = _button(_lenses.title_of(lens))
		made.alignment = HORIZONTAL_ALIGNMENT_LEFT
		made.toggle_mode = true
		made.tooltip_text = "Outline %s over the shown layer" % _lenses.title_of(lens)
		made.pressed.connect(choose_compare.bind(lens))
		_compare_list.add_child(made)
		_compare_buttons.append(made)


func _make_legend(lens: int, box: VBoxContainer, outlined: bool) -> LegendScript:
	"""A layer's legend (demo_lens_legend.gd): its caption, its ramp with thresholds, and its keys; hidden."""
	var made := LegendScript.new()
	box.add_child(made)
	made.build(_lenses, lens, outlined)
	made.visible = false
	return made


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


func choose_compare(lens: int) -> void:
	"""Outline `lens` over the shown layer -- or none, for ✕ or the layer already outlined -- and fold its list."""
	_lenses.set_compare(LensesScript.OFF if lens == _lenses.compare else lens)
	_compare_list.visible = false
	refresh()


func toggle_compare_list() -> void:
	"""Unfold or fold the list of layers that can be outlined."""
	_compare_list.visible = not _compare_list.visible
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
		_outline_legends[k].visible = k == _lenses.compare
		if k == active or k == _lenses.compare:
			_legends[k].retext()
			_outline_legends[k].retext()
	if _card.visible:
		_fill_card(active)
	_fill_compare()
	_place.call_deferred()


func _fill_compare() -> void:
	"""The compare button's state, which layers its list offers, and the Outlined line."""
	var compare: int = _lenses.compare
	var any: bool = compare != LensesScript.OFF
	for k: int in _compare_buttons.size():
		var candidate: bool = _lenses.is_compare_candidate(k + 1)
		_compare_buttons[k].visible = candidate
		_compare_buttons[k].set_pressed_no_signal(k + 1 == compare)
		any = any or candidate
	_compare_list.visible = _compare_list.visible and any and _card.visible
	FarmUi.set_enabled(_compare_button, any and _card.visible, "No other layer can be outlined over this one")
	_compare_button.set_pressed_no_signal(compare != LensesScript.OFF or _compare_list.visible)
	_compare_row.visible = compare != LensesScript.OFF
	_outline_box.visible = _compare_row.visible
	if _compare_row.visible:
		_compare_label.text = COMPARE_ON_TEXT % _lenses.title_of(compare)


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
	return _legends[lens].words()


func legend(lens: int) -> LegendScript:
	"""`lens`'s legend (its caption, ramp thresholds and keys)."""
	return _legends[lens]


func outline_legend(lens: int) -> LegendScript:
	"""`lens`'s legend as the compare outlines draw it."""
	return _outline_legends[lens]


static func compare_icon() -> Texture2D:
	"""The compare button's glyph (made once)."""
	if _compare_icon == null:
		var image := Image.new()
		if image.load_svg_from_string(COMPARE_SVG, 1.0) == OK:
			_compare_icon = ImageTexture.create_from_image(image)
	return _compare_icon


func compare_button() -> Button:
	"""The header's compare button (it unfolds the compare list)."""
	return _compare_button


func compare_text() -> String:
	"""The Outlined line ('' while nothing is compared)."""
	return _compare_label.text if _compare_row.visible else ""


func compare_off_button() -> Button:
	"""The Outlined line's ✕."""
	return _compare_off


func compare_lens_button(lens: int) -> Button:
	"""The compare list's button for `lens` (1..)."""
	_ensure_rows()
	return _compare_buttons[lens - 1]


func compare_list_shown() -> bool:
	"""Whether the compare list is unfolded."""
	return _compare_list.visible


func compare_offered() -> bool:
	"""Whether the compare button can be used (a layer is shown and another can be outlined over it)."""
	return _card.visible and not _compare_button.disabled


func legend_shown(lens: int) -> bool:
	"""Whether `lens`'s legend shows."""
	return _legends[lens].visible


func frame_rect() -> Rect2:
	"""The frame's rectangle on screen, in viewport pixels."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


# --- placement --------------------------------------------------------------------------------

func _queue_place() -> void:
	"""Place the frame again at the end of this frame, once (the list or the card changed size)."""
	if not _place_queued:
		_place_queued = true
		_place.call_deferred()


func _place() -> void:
	"""In the bottom-left zone (see WHERE), as tall as its content up to the slot's height -- past that the list and
	card scroll under the header; an unfolded list grows upward from it."""
	_place_queued = false
	if not is_inside_tree() or _frame == null:
		return
	var slot: Rect2 = slot_for(get_viewport().get_visible_rect().size)
	var content: Control = _body.get_child(0) as Control
	var fixed: float = _frame.get_theme_stylebox(&"panel").get_minimum_size().y + _header.get_combined_minimum_size().y + 6.0
	_body.custom_minimum_size.y = clampf(content.get_combined_minimum_size().y, 0.0, maxf(slot.size.y - fixed, 0.0))
	_body.visible = _list.visible or _card.visible
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
	height is all the room it has, past which its list and card scroll). Chosen by the viewport alone, never by
	what the card shows, so the picker does not jump when a layer changes; never over the detail zone (decision
	0391: at 125 % and 150 % on 1280x720 it reached into the right column). The first that fits:
	  * right of the party panel's column, down on the command strip, where the space left of the news band is
	    at least WIDTH (1920x1080);
	  * right of the party column, just above the bottom band, at least MIN_WIDTH wide (1280x720, the journal
	    open, 125 %);
	  * right of the minimap, below the party column, down on the command strip (150 % on 1280x720)."""
	var left: float = UiLayout.SAFE_INSET + 2.0 * PartyScript.FRAME_EXPAND + PartyScript.WIDTH + GAP + FRAME_EXPAND
	var top: float = geometry.management_top + FRAME_EXPAND
	var detail_left: float = geometry.detail.position.x - GAP - FRAME_EXPAND
	var right: float = news_band.position.x - GAP - FRAME_EXPAND if news_band.size.x > 0.0 else geometry.commands.end.x
	right = minf(right, detail_left)
	if right - left >= WIDTH:
		return Rect2(left, top, minf(right - left, MAX_WIDTH), geometry.commands.position.y - GAP - FRAME_EXPAND - top)
	if detail_left - left >= MIN_WIDTH:
		return Rect2(left, top, minf(WIDTH, detail_left - left), geometry.minimap.position.y - GAP - FRAME_EXPAND - top)
	var beside: float = geometry.minimap.end.x + GAP + FRAME_EXPAND
	var under: float = geometry.minimap.position.y + FRAME_EXPAND
	return Rect2(beside, under, minf(WIDTH, maxf(detail_left - beside, 0.0)),
		geometry.commands.position.y - GAP - FRAME_EXPAND - under)
