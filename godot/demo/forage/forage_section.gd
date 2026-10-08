extends VBoxContainer
## The Woods panel's FORAGING section (decision 0681): what the woods hold of each kind and what a trip would bring home,
## the trips out, and the verbs -- Gather ▸ (nuts, mushrooms, herbs, berries), Party ▸ (1-3), Kit ▸ and Lead ▸ (decision
## 1721's prepared outing: the carry kit, the first selected resident named to lead), Authorise trip, Cancel trip. Built
## in the Woods panel's own type and wood buttons (forest_panel.gd), placed there by its `add_section`; its buttons emit
## `action` with a name (ACTION_*) and nothing here decides anything. Each order's tooltip is its ACTION CARD (decision
## 0332, `set_card`).

const Styles := preload("res://demo/ui/woodland_styles.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

signal action(name: StringName)

const ACTION_KIND: StringName = &"forage_kind"
const ACTION_PARTY: StringName = &"forage_party"
const ACTION_AUTHORISE: StringName = &"forage_authorise"
const ACTION_CANCEL: StringName = &"forage_cancel"
const ACTION_KIT: StringName = &"forage_kit"
const ACTION_LEAD: StringName = &"forage_lead"
const ACTIONS: Array[StringName] = [&"forage_kind", &"forage_party", &"forage_kit", &"forage_lead", &"forage_authorise",
	&"forage_cancel"]
const BUTTON_TEXT: Dictionary = {&"forage_kind": "Gather ▸ nuts", &"forage_party": "Party ▸ 2",
	&"forage_kit": "Kit ▸ no", &"forage_lead": "Lead ▸ no", &"forage_authorise": "Authorise trip",
	&"forage_cancel": "Cancel trip"}
const TIPS: Dictionary = {&"forage_kind": "What the trip gathers: nuts, mushrooms, herbs or berries (each in its season)",
	&"forage_party": "How many go: one to three foragers, a basket each",
	&"forage_kit": "Take the village's one carry kit: its carrier brings two baskets",
	&"forage_lead": "Name a lead: the first selected resident leads the trip, and the news and the place's note name them"}
const LINE_KEYS: Array[StringName] = [&"woods", &"trip", &"note", &"out"]
const TITLE: String = "Foraging"
## The Woods panel's type and buttons (forest_panel.gd).
const BODY_PX: int = 14
const SMALL_PX: int = 14
const BUTTON_H: float = 32.0
const BUTTON_MARGINS: PackedFloat32Array = [8.0, 5.0, 8.0, 6.0]

var _lines: Dictionary = {}
var _buttons: Dictionary = {}
var _width: float = 288.0


func build(width: float) -> void:
	"""Build the section's widgets for lines `width` logical px wide (also out of the tree, for checks)."""
	if not _lines.is_empty():
		return
	name = "ForageSection"
	_width = width
	add_theme_constant_override(&"separation", 4)
	add_child(_label(TITLE, BODY_PX + 1, Palette.INK, Styles.heading_font()))
	for key: StringName in LINE_KEYS:
		_lines[key] = _label("", BODY_PX if key == &"woods" or key == &"trip" else SMALL_PX, Palette.UMBER, null)
		add_child(_lines[key])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	for key: StringName in ACTIONS:
		grid.add_child(_button(key))
	add_child(grid)


func _label(text: String, px: int, colour: Color, font: Font) -> Label:
	"""One wrapped label in the panel's type."""
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = _width
	label.add_theme_font_size_override(&"font_size", px)
	label.add_theme_color_override(&"font_color", colour)
	if font != null:
		label.add_theme_font_override(&"font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(key: StringName) -> Button:
	"""A wood button (the Woods panel's) that emits `action(key)`; takes keyboard focus (decision 0261)."""
	var b := Button.new()
	b.text = BUTTON_TEXT[key]
	b.tooltip_text = TIPS.get(key, "")
	Styles.focusable(b, BUTTON_MARGINS)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = BUTTON_H
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override(&"font_size", SMALL_PX)
	b.add_theme_stylebox_override(&"normal", Styles.box(Styles.PIECE_WOOD, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"hover", Styles.box(Styles.PIECE_WOOD_HOVER, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"pressed", Styles.box(Styles.PIECE_BRASS, BUTTON_MARGINS))
	b.add_theme_stylebox_override(&"disabled", Styles.box(Styles.PIECE_WOOD_DISABLED, BUTTON_MARGINS))
	for item: StringName in [&"font_color", &"font_hover_color"]:
		b.add_theme_color_override(item, Palette.text_on(Palette.SURFACE_WOOD))
	b.add_theme_color_override(&"font_pressed_color", Palette.text_on(Palette.SURFACE_BRASS))
	b.add_theme_color_override(&"font_disabled_color", Palette.text_on(Palette.SURFACE_WOOD_DISABLED))
	b.pressed.connect(func() -> void: action.emit(key))
	_buttons[key] = b
	return b


func button(key: StringName) -> Button:
	"""The button for an action (checks and scripted runs)."""
	return _buttons[key]


func line(key: StringName) -> String:
	"""A line's text: woods, trip, note or out."""
	return (_lines[key] as Label).text


func show_lines(woods: String, trip: String, out: String, kind_word: String, party: int) -> void:
	"""The section's lines, and the choices on their buttons."""
	_set_line(&"woods", woods)
	_set_line(&"trip", trip)
	_set_line(&"out", out)
	(_lines[&"out"] as Label).visible = not out.is_empty()
	_set_text(ACTION_KIND, "Gather ▸ %s" % kind_word)
	_set_text(ACTION_PARTY, "Party ▸ %d" % party)


func show_outing(note: String, kit: bool, lead: bool) -> void:
	"""Decision 1721: the chosen spot's remembered note ("" hides it) and the kit and lead choices on their buttons."""
	_set_line(&"note", note)
	(_lines[&"note"] as Label).visible = not note.is_empty()
	_set_text(ACTION_KIT, "Kit ▸ %s" % ("yes" if kit else "no"))
	_set_text(ACTION_LEAD, "Lead ▸ %s" % ("yes" if lead else "no"))


func set_card(key: StringName, card_text: String, enabled: bool) -> void:
	"""An order's card (decision 0332) as its button's tooltip, the button pressable only when the card allows it."""
	var b := _buttons[key] as Button
	CardScript.dress(b)
	if b.tooltip_text != card_text:
		b.tooltip_text = card_text
	b.disabled = not enabled


func _set_line(key: StringName, text: String) -> void:
	"""Set a line when its text changed."""
	var label := _lines[key] as Label
	if label.text != text:
		label.text = text


func _set_text(key: StringName, text: String) -> void:
	"""Set a button's text when it changed."""
	var b := _buttons[key] as Button
	if b.text != text:
		b.text = text
