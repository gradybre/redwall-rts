extends VBoxContainer
## The weir sluice's controls in the farm panel (farm_bed_panel.gd shows it for the weir): the setting now, the three
## settings as buttons whose tooltips are their action cards, and the AFFECTED-BED PREVIEW -- for the setting under the
## pointer (or keyboard focus), else the setting now -- bed by bed. Decision 0441 (review ECO-006). DEMO UI in the
## woodland skin. It only shows and asks: a press emits `sluice_chosen`, and demo_farm.gd gives the order.

const LeatScript := preload("res://demo/farm/farm_leat.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const CardScript := preload("res://demo/ui/action_card.gd")

signal sluice_chosen(setting: int)

const ZONE_TEXT: String = "The garden leat serves Bed 2, Bed 4 and Bed 6 (the east column), in that order. Tunnels under a bed still drain or water it while the leat runs dry."
const NOW_TITLE: String = "Now:"
const IF_TITLE: String = "If set to %s:"
## No setting under the pointer: the preview shows the setting now.
const NO_HOVER: int = -1

var _leat: LeatScript = null
var _state: Label = null
var _buttons: Array[Button] = []
var _preview_title: Label = null
var _preview: Label = null
var _rows: Array[Label] = []
var _hover: int = NO_HOVER
var _card: CardScript = CardScript.new()
var _shown: LeatScript.Preview = LeatScript.Preview.new()


func _init() -> void:
	"""Built at once; filled by `refresh` once a leat is bound."""
	name = "SluiceBox"
	add_theme_constant_override(&"separation", 5)
	_state = FarmUi.label("", FarmUi.BODY_PX, Palette.INK, true)
	add_child(_state)
	add_child(FarmUi.label(ZONE_TEXT, FarmUi.SMALL_PX, Palette.UMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	for setting: int in Sluice.SLUICE_COUNT:
		var button: Button = FarmUi.button(Sluice.SLUICE_VERBS[setting])
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: sluice_chosen.emit(setting))
		button.mouse_entered.connect(hover.bind(setting))
		button.focus_entered.connect(hover.bind(setting))
		button.mouse_exited.connect(hover.bind(NO_HOVER))
		button.focus_exited.connect(hover.bind(NO_HOVER))
		row.add_child(button)
		_buttons.append(button)
	add_child(row)
	_preview_title = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER, true)
	add_child(_preview_title)
	_preview = FarmUi.label("", FarmUi.BODY_PX, Palette.INK)
	add_child(_preview)
	for k: int in Sluice.ZONE_SIZE:
		_rows.append(FarmUi.label("", FarmUi.SMALL_PX, Palette.INK))
		add_child(_rows[k])


func bind(leat: LeatScript) -> void:
	"""Show this leat."""
	_leat = leat
	refresh()


func hover(setting: int) -> void:
	"""The pointer (or focus) is on setting `setting`'s button (NO_HOVER: on none): preview it."""
	_hover = setting
	refresh()


func refresh() -> void:
	"""Rewrite the state, each button's card and the preview from the leat as it stands."""
	if _leat == null:
		return
	_state.text = "Sluice: %s" % Sluice.SLUICE_NAMES[_leat.setting]
	for setting: int in Sluice.SLUICE_COUNT:
		_leat.card_into(_card, setting)
		var button: Button = _buttons[setting]
		FarmUi.set_card(button, _card.is_ok(), _card.text())
		button.set_pressed_no_signal(setting == _leat.setting)
		if setting == _leat.setting:
			button.modulate.a = 1.0
	var shown: int = _hover if Sluice.is_sluice(_hover) else _leat.setting
	_leat.preview_into(shown, _shown)
	_preview_title.text = NOW_TITLE if shown == _leat.setting else IF_TITLE % Sluice.SLUICE_NAMES[shown].to_lower()
	_preview.text = _shown.text
	for k: int in _shown.size():
		_rows[k].text = row_text(_shown, k)


static func row_text(p: LeatScript.Preview, k: int) -> String:
	"""Zone bed k's row: 'Bed 2 · good now · leat dry → wet · +15% from the leat' (its own share at the next
	midnight; the weather and the drainage above the band's top come on top)."""
	var change: String = Sluice.SERVICE_NAMES[p.service_after[k]]
	if p.service_now[k] != p.service_after[k]:
		change = "%s → %s" % [Sluice.SERVICE_NAMES[p.service_now[k]], change]
	var nudge: String = "nothing added" if p.nudge[k] == 0 else "%+d%% from the leat" % (p.nudge[k] / 100)
	var text: String = "%s · %s now · leat %s · %s" % [Sluice.bed_word(p.beds[k]), SimScript.BAND_NAMES[p.band_now[k]],
		change, nudge]
	if p.flooding and p.flood_rise[k] > 0:
		text += " · flood +%d%%" % (p.flood_rise[k] / 100)
	return text


func button(setting: int) -> Button:
	"""Setting `setting`'s button (checks)."""
	return _buttons[setting]


func preview_text() -> String:
	"""The preview's sentence as shown (checks)."""
	return _preview.text


func row(k: int) -> String:
	"""Zone bed k's row as shown (checks)."""
	return _rows[k].text
