extends VBoxContainer
## The game menu's sound settings (demo_menu.gd's Settings page): a volume and a mute for each of the five
## buses, and the three mixes. Decision 0351 (review F43, UX-031; UI §8.1's master, ambience, effects and
## notice volumes). DEMO UI in the woodland skin.
##
## A ROW per bus: its name, − and + (5 % steps: UI §8.1's stepper, and the keyboard's way, since the input gate
## steps through buttons), a slider for the mouse (it takes no focus), the percent, and Mute. The MIXES row:
## Balanced, Quiet focus and Atmosphere (sound_mix.gd PRESET_*); the one the volumes match is lit, none when
## they are the player's own. Every change goes into SoundMix's settings (kept through Restart) and then to the
## buses through the host's `apply`.
##
## The NOTE says what is true: with no sound files staged the demo is silent and the settings wait for them;
## and every sound has a text or picture match, so nothing is lost muted (UI §7).

const SoundMix := preload("res://demo/sound/sound_mix.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const TITLE: String = "Sound"
const MIXES_TITLE: String = "Mix"
const MUTE_TEXT: String = "Mute"
const MUTED_TEXT: String = "Muted"
const PERCENT_TEXT: String = "%d%%"
const SILENT_NOTE: String = "The demo's sound files are not in yet, so it is silent: these settings are kept for them."
const MATCH_NOTE: String = "Every sound has a text or picture match: with the sound off, nothing is missed."
const LABEL_W: float = 132.0
const VALUE_W: float = 46.0
const SLIDER_W: float = 110.0

## `apply()`: write the settings to the buses (the director's mix). Unset: the settings are only kept.
var apply: Callable = Callable()

var _sliders: Array[HSlider] = []
var _values: Array[Label] = []
var _mutes: Array[Button] = []
var _downs: Array[Button] = []
var _ups: Array[Button] = []
## The − and + buttons' tooltips, by bus (FarmUi.set_enabled clears an enabled button's tooltip).
var _down_tips: PackedStringArray = PackedStringArray()
var _up_tips: PackedStringArray = PackedStringArray()
var _presets: Array[Button] = []
var _note: Label = null
var _silent: bool = true
var _refreshing: bool = false


func _init() -> void:
	"""Built at once, from the settings as they stand."""
	name = "SoundSettings"
	add_theme_constant_override(&"separation", 4)
	add_child(FarmUi.label(TITLE, FarmUi.BODY_PX, Palette.INK, true))
	for bus: int in SoundMix.BUS_COUNT:
		add_child(_bus_row(bus))
	add_child(_preset_row())
	_note = FarmUi.label("", FarmUi.SMALL_PX, Palette.UMBER)
	add_child(_note)
	refresh()


func _bus_row(bus: int) -> HBoxContainer:
	"""Bus `bus`'s row: name, −, slider, +, percent, Mute."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var name_label: Label = FarmUi.label(SoundMix.BUS_LABELS[bus], FarmUi.SMALL_PX, Palette.INK)
	name_label.custom_minimum_size.x = LABEL_W
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	_downs.append(_step_button("−", bus, -SoundMix.PERCENT_STEP, row))
	row.add_child(_slider(bus))
	_ups.append(_step_button("+", bus, SoundMix.PERCENT_STEP, row))
	var value: Label = FarmUi.label("", FarmUi.SMALL_PX, Palette.INK)
	value.custom_minimum_size.x = VALUE_W
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value)
	_values.append(value)
	var mute: Button = FarmUi.button(MUTE_TEXT, FarmUi.SMALL_PX)
	mute.toggle_mode = true
	mute.tooltip_text = "Silence %s (its volume is kept)" % SoundMix.BUS_LABELS[bus].to_lower()
	mute.toggled.connect(set_muted.bind(bus))
	row.add_child(mute)
	_mutes.append(mute)
	return row


func _step_button(text: String, bus: int, by: int, row: HBoxContainer) -> Button:
	"""A − or + that moves bus `bus` by `by` percent."""
	var button: Button = FarmUi.button(text, FarmUi.SMALL_PX)
	button.tooltip_text = "%s %s by %d%%" % ["Lower" if by < 0 else "Raise", SoundMix.BUS_LABELS[bus].to_lower(),
		absi(by)]
	button.pressed.connect(step.bind(bus, by))
	(_down_tips if by < 0 else _up_tips).append(button.tooltip_text)
	row.add_child(button)
	return button


func _slider(bus: int) -> HSlider:
	"""Bus `bus`'s slider, 0..100 in 5 % steps (the mouse's; no keyboard focus -- − and + are the keys')."""
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = float(SoundMix.PERCENT_MAX)
	slider.step = float(SoundMix.PERCENT_STEP)
	slider.custom_minimum_size = Vector2(SLIDER_W, 20.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.scrollable = false  # the wheel scrolls the page, never a volume
	slider.tooltip_text = "%s volume" % SoundMix.BUS_LABELS[bus]
	slider.value_changed.connect(_on_slider.bind(bus))
	_sliders.append(slider)
	return slider


func _preset_row() -> HBoxContainer:
	"""The three mixes, lit when the volumes are a mix's."""
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var title: Label = FarmUi.label(MIXES_TITLE, FarmUi.SMALL_PX, Palette.INK, true)
	title.custom_minimum_size.x = LABEL_W
	row.add_child(title)
	for index: int in SoundMix.PRESET_NAMES.size():
		var button: Button = FarmUi.button(SoundMix.PRESET_NAMES[index], FarmUi.SMALL_PX)
		button.toggle_mode = true
		button.tooltip_text = SoundMix.PRESET_TIPS[index]
		button.pressed.connect(choose_preset.bind(index))
		row.add_child(button)
		_presets.append(button)
	return row


# --- changes ----------------------------------------------------------------------------------------

func step(bus: int, by: int) -> void:
	"""Move bus `bus`'s volume by `by` percent (− / +)."""
	set_percent(bus, SoundMix.percents[bus] + by)


func set_percent(bus: int, percent: int) -> void:
	"""Set bus `bus`'s volume, apply it and repaint."""
	if SoundMix.set_percent(bus, percent):
		_changed()


func set_muted(on: bool, bus: int) -> void:
	"""Mute or unmute bus `bus` (Mute's toggle), apply and repaint."""
	if not _refreshing and SoundMix.set_muted(bus, on):
		_changed()


func choose_preset(index: int) -> void:
	"""Take mix `index`'s volumes, apply and repaint."""
	if SoundMix.choose_preset(index):
		_changed()


func _on_slider(value: float, bus: int) -> void:
	"""The slider moved (by the mouse; a repaint's own write is ignored)."""
	if not _refreshing:
		set_percent(bus, int(roundf(value)))


func _changed() -> void:
	"""Apply through the host, then repaint."""
	if apply.is_valid():
		apply.call()
	refresh()


func set_silent(silent: bool) -> void:
	"""Whether the demo has no sound files staged (the note says so)."""
	_silent = silent
	refresh()


func refresh() -> void:
	"""Repaint every row, the lit mix and the note from the settings as they stand."""
	_refreshing = true
	for bus: int in SoundMix.BUS_COUNT:
		var percent: int = SoundMix.percents[bus]
		_sliders[bus].set_value_no_signal(float(percent))
		_values[bus].text = PERCENT_TEXT % percent
		_mutes[bus].set_pressed_no_signal(SoundMix.muted[bus] == 1)
		_mutes[bus].text = MUTED_TEXT if SoundMix.muted[bus] == 1 else MUTE_TEXT
		_set_step_enabled(_downs[bus], percent > 0, _down_tips[bus], "Already silent")
		_set_step_enabled(_ups[bus], percent < SoundMix.PERCENT_MAX, _up_tips[bus], "Already at full volume")
	for index: int in _presets.size():
		_presets[index].set_pressed_no_signal(index == SoundMix.preset)
	_note.text = (SILENT_NOTE + " " if _silent else "") + MATCH_NOTE
	_refreshing = false


static func _set_step_enabled(button: Button, enabled: bool, tip: String, why: String) -> void:
	"""A − or + enabled with its own tooltip, or disabled with the reason."""
	FarmUi.set_enabled(button, enabled, why)
	if enabled:
		button.tooltip_text = tip


# --- checks -----------------------------------------------------------------------------------------

func slider(bus: int) -> HSlider:
	"""Bus `bus`'s slider."""
	return _sliders[bus]


func mute_button(bus: int) -> Button:
	"""Bus `bus`'s Mute."""
	return _mutes[bus]


func up_button(bus: int) -> Button:
	"""Bus `bus`'s +."""
	return _ups[bus]


func down_button(bus: int) -> Button:
	"""Bus `bus`'s −."""
	return _downs[bus]


func preset_button(index: int) -> Button:
	"""Mix `index`'s button."""
	return _presets[index]


func note_text() -> String:
	"""The note's text."""
	return _note.text
