extends CanvasLayer
## THE FEASTS PANEL (decision 1701; UI-SET-032's Feast command, which opens it): call one of the GDD's three feasts for
## one of the next suppers. DEMO UI in the woodland skin (farm_ui.gd's frame, type and wood buttons), laid out in the
## HUD's logical pixels and drawn at its scale, placed as the hall's panel is (top centre under the alert zone).
##
## WHAT, top to bottom: "Feasts" with The regatta... and x; the status (the feast called, the buffs lasting, feasts
## completed); THE CHOICE -- the theme, the day, the keeper and the reserve override, each stepped by a button -- and
## Call the feast and Cancel the feast, each with its action card (decision 0332) from the feast's own decision, and
## the answer line under them; REQ-SET-100's plan for the choice, its refusal first when it cannot be held; the themes'
## readiness ("needs X"); the last feast. Not modal; Esc or x closes it. Rewritten a few times a second while open, a label only when its text
## changed.

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoScroll := preload("res://demo/ui/demo_scroll.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const Rules := preload("res://demo/feast/feast_rules.gd")
const RegattaRules := preload("res://demo/regatta/regatta_rules.gd")
const FeastScript := preload("res://demo/feast/called_feast.gd")
const Words := preload("res://demo/feast/feast_text.gd")
const MenuScript := preload("res://demo/feast/feast_menu.gd")

const LAYER: int = 1
const MAX_W: float = 560.0
const MAX_H: float = 660.0
const GAP: float = 10.0
const SECTION_PX: int = 16
const REFRESH_S: float = 0.25
## The buttons: their actions (Callables under these names, `set_actions`), words and tips.
const CHOICE_BUTTONS: Array[Array] = [
	[&"theme_prev", "◀ Theme", "The previous theme: Hearth, Harvest, Orchard"],
	[&"theme_next", "Theme ▶", "The next theme"],
	[&"day_prev", "◀ Day", "An earlier supper"],
	[&"day_next", "Day ▶", "A later supper (up to three ahead)"],
	[&"host", "Keeper ▸", "The next resident to keep the feast (never its cook)"],
	[&"override", "Override reserves", "REQ-SET-101: hold it even when it leaves under 3 days of ready food or fuel"],
]

var feast: FeastScript = null
var _actions: Dictionary = {}
var _buttons: Dictionary = {}
var _card: CardScript = CardScript.new()
var _frame: PanelContainer = null
var _labels: Dictionary = {}
var _refresh_in: float = 0.0
## The feast's revision when the answer line was written: it is cleared once the feast changes again.
var _said_at: int = 0
var _layout: UiLayout = UiLayout.new()
var _geometry: UiLayout.Geometry = UiLayout.Geometry.new()


func configure(p_feast: FeastScript) -> void:
	"""Show this feast."""
	feast = p_feast
	build()


func set_actions(actions: Dictionary) -> void:
	"""What the buttons do: Callables `() -> String` (the answer shown) under each button's name (CHOICE_BUTTONS,
	&"call", &"cancel", &"regatta")."""
	_actions = actions


func _ready() -> void:
	"""Place, and follow the viewport's size."""
	build()
	get_viewport().size_changed.connect(_place)
	_place()


func build() -> void:
	"""The hidden window (also out of the tree, for checks)."""
	if _frame != null:
		return
	layer = LAYER
	name = "FeastPanel"
	_frame = FarmUi.frame()
	_frame.visible = false
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_frame.add_child(column)
	_build_header(column)
	var scroll := DemoScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 6)
	scroll.add_child(body)
	_build_body(body)


func _build_header(column: VBoxContainer) -> void:
	"""The title, The regatta... and the close; the status under them."""
	var row := HBoxContainer.new()
	column.add_child(row)
	var title: Label = FarmUi.label("Feasts", FarmUi.TITLE_PX, Palette.UMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_button(&"regatta", "The regatta…", "The season's regatta and its Hearth feast (the Water panel)"))
	var close: Button = FarmUi.button("×", FarmUi.BODY_PX + 2)
	close.name = "Close"
	close.tooltip_text = "Close the feasts (Esc)"
	close.pressed.connect(close_window)
	row.add_child(close)
	_line(column, &"status", FarmUi.SMALL_PX, Palette.UMBER)


func _build_body(body: VBoxContainer) -> void:
	"""The choice and its plan, the call and cancel, the themes, the last feast, the answer."""
	body.add_child(FarmUi.label("Call a feast", SECTION_PX, Palette.UMBER, true))
	_line(body, &"choice", FarmUi.BODY_PX, Palette.INK)
	var steps: Array = []
	for spec: Array in CHOICE_BUTTONS:
		steps.append(_button(spec[0], spec[1], spec[2]))
	_add_row(body, steps.slice(0, 4))
	_add_row(body, steps.slice(4))
	_add_row(body, [_button(&"call", "Call the feast", ""), _button(&"cancel", "Cancel the feast", "")])
	_line(body, &"message", FarmUi.BODY_PX, Palette.LEAF)
	_line(body, &"plan", FarmUi.SMALL_PX, Palette.INK)
	body.add_child(FarmUi.label("The themes", SECTION_PX, Palette.UMBER, true))
	_line(body, &"themes", FarmUi.SMALL_PX, Palette.INK)
	_line(body, &"last", FarmUi.SMALL_PX, Palette.UMBER)


func _line(parent: VBoxContainer, key: StringName, px: int, colour: Color) -> void:
	"""A wrapping line, kept under `key`."""
	var made: Label = FarmUi.label("", px, colour)
	made.name = String(key).capitalize().replace(" ", "")
	parent.add_child(made)
	_labels[key] = made


func _add_row(body: VBoxContainer, buttons: Array) -> void:
	"""A row of buttons."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	for each: Button in buttons:
		row.add_child(each)
	body.add_child(row)


func _button(action: StringName, words: String, tip: String) -> Button:
	"""A wood button that runs `action` (see `set_actions`)."""
	var made: Button = FarmUi.button(words)
	made.name = String(action)
	made.tooltip_text = tip
	made.pressed.connect(press.bind(action))
	_buttons[action] = made
	return made


# --- opening, pressing ----------------------------------------------------------------------------------------------

func open() -> void:
	"""Show the panel, current."""
	build()
	_frame.visible = true
	refresh()
	_place.call_deferred()


func close_window() -> void:
	"""Hide the panel."""
	if _frame != null:
		_frame.visible = false


func is_open() -> bool:
	"""Whether the panel is shown."""
	return _frame != null and _frame.visible


func press(action: StringName) -> String:
	"""Press a button (a click, or a check): its action's answer, shown on the answer line until the feast next
	changes."""
	var act: Callable = _actions.get(action, Callable())
	if not act.is_valid():
		return ""
	var said: Variant = act.call()
	var words: String = said if said is String else ""
	_set_text(&"message", words)
	_said_at = feast.revision if feast != null else 0
	refresh()
	return words


func _input(event: InputEvent) -> void:
	"""Esc closes the open panel before any world handler reads it (the top of UI §5's dismissal ladder)."""
	if is_open() and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		close_window()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	"""Refresh a few times a second while open."""
	if not is_open():
		return
	_refresh_in -= delta
	if _refresh_in > 0.0:
		return
	_refresh_in = REFRESH_S
	refresh()


# --- drawing --------------------------------------------------------------------------------------------------------

func refresh() -> void:
	"""Rewrite every line whose text changed, and the buttons' cards."""
	if feast == null or _frame == null:
		return
	feast.keep_choice_current()
	if feast.revision != _said_at:
		_set_text(&"message", "")
	_set_text(&"status", Words.status_line(feast))
	_set_text(&"choice", Words.choice_line(feast))
	_set_text(&"plan", plan_text())
	var themes := PackedStringArray()
	for theme: int in Rules.THEME_COUNT:
		themes.append(Words.theme_ready_words(feast, theme))
	_set_text(&"themes", "\n".join(themes))
	_set_text(&"last", "Last feast: %s" % feast.last_line if not feast.last_line.is_empty() else "No feast held yet.")
	_draw_buttons()


func _set_text(key: StringName, text: String) -> void:
	"""Label `key`'s text, written only when it changed."""
	var label: Label = _labels.get(key, null) as Label
	if label != null and label.text != text:
		label.text = text


func plan_text() -> String:
	"""The plan for the choice (its refusal first), or the planned feast's own."""
	var planning: bool = feast.state == FeastScript.ST_IDLE
	var theme: int = feast.choice_theme if planning else feast.plan_theme
	var day: int = feast.choice_day if planning else feast.plan_day
	var host: int = feast.choice_host if planning else feast.plan_host
	var lines: PackedStringArray = Words.preview_lines(feast, theme, day, host)
	if planning:
		var why: String = feast.refusal(theme, day, host, feast.override)
		lines.insert(0, "Can't call it: %s%s" % [why, (" — to fix: %s" % feast.refused_fix) if not feast.refused_fix.is_empty() else ""]
			if not why.is_empty() else "Ready to call")
	return "\n".join(lines)


func _draw_buttons() -> void:
	"""The choice's steps while planning; Call and Cancel by their cards."""
	var planning: bool = feast.state == FeastScript.ST_IDLE
	for spec: Array in CHOICE_BUTTONS:
		FarmUi.set_enabled(_buttons[spec[0]], planning, "A feast is called: cancel it to choose again")
	var card: CardScript = call_card()
	FarmUi.set_card(_buttons[&"call"], card.is_ok(), card.text())
	card = cancel_card()
	FarmUi.set_card(_buttons[&"cancel"], card.is_ok(), card.text())


func call_card() -> CardScript:
	"""Call the feast's card: the feast's own `refusal`, its wood, its result."""
	var e: int = feast.residents()
	_card.reset("Call the %s feast for %s" % [Rules.THEME_NAMES[feast.choice_theme], feast.day_text(feast.choice_day)])
	_card.add_cost("Wood", feast.stores.wood_milli_u if feast.stores != null else 0, RegattaRules.service_wood_milli(e))
	_card.result = "%s at the %02d:00 supper for %d; %s if 80%% eat every course" % [
		FeastScript.served_words(feast.choice_theme), Rules.FEAST_HOUR, e, Rules.BUFF_NAMES[feast.choice_theme]]
	_card.prerequisites.append("every course's food and its %s free; a keeper who does not cook" % MenuScript.bev_words(
		feast.choice_theme))
	var why: String = feast.refusal(feast.choice_theme, feast.choice_day, feast.choice_host, feast.override)
	if not why.is_empty():
		_card.refuse(feast.refused_code, why, feast.refused_fix)
	return _card


func cancel_card() -> CardScript:
	"""Cancel the feast's card: REQ-SET-102's terms."""
	_card.reset("Cancel the feast")
	_card.result = "Everything set aside goes back untouched (until 15:00 on its day, when the kitchen starts cooking it)"
	var why: String = feast.cancel_refusal()
	if not why.is_empty():
		_card.refuse("CANNOT", why, "")
	return _card


# --- placing --------------------------------------------------------------------------------------------------------

func _place() -> void:
	"""Top centre under the alert zone, as wide as MAX_W allows, down to just above the command strip."""
	if not is_inside_tree() or _frame == null:
		return
	FarmUi.geometry_for(get_viewport().get_visible_rect().size, _layout, _geometry)
	var width: float = minf(MAX_W, _geometry.logical_width - 2.0 * GAP)
	var x: float = clampf(_geometry.alerts.get_center().x - width / 2.0, GAP, _geometry.logical_width - GAP - width)
	var top: float = _geometry.alerts.end.y + GAP
	var height: float = minf(MAX_H, _geometry.commands.position.y - GAP - top)
	_frame.scale = Vector2(_geometry.scale, _geometry.scale)
	_frame.position = Vector2(x, top) * _geometry.scale
	_frame.custom_minimum_size = Vector2(width, height)
	_frame.size = Vector2(width, height)


func frame_rect() -> Rect2:
	"""Where the panel is drawn, in viewport pixels (checks)."""
	return Rect2(_frame.position, _frame.size * _frame.scale)


func text_of(key: StringName) -> String:
	"""Line `key`'s text (checks)."""
	var label: Label = _labels.get(key, null) as Label
	return label.text if label != null else ""


func button(action: StringName) -> Button:
	"""The button for `action` (checks)."""
	return _buttons.get(action, null) as Button
