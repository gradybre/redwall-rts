extends Control
## The UI specimen: every §2.2 profile in every state, with SYNTHETIC values. Not the game.
##
## The visual direction requires that "any synthetic values" live in "a clearly labeled UI
## specimen scene", and this is that scene. Nothing here reads or writes simulation state, and
## every number on it is invented for the purpose of judging contrast, weight and spacing. It
## exists so a reviewer can see all five interaction states at once -- hover and pressed in
## particular, which a screenshot of the running HUD cannot show without a pointer in the frame.
##
## It shares ONE thing with the real HUD: `woodland_theme.tres`. If the specimen looks right and
## the HUD does not, the difference is in the HUD's own code, not in two divergent palettes.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")

const THEME_PATH: String = "res://ui/theme/woodland_theme.tres"
const BANNER: String = "UI SPECIMEN - SYNTHETIC VALUES, NOT SIMULATION STATE"

## The profile rows this specimen draws, and the variation each uses.
const SPECIMEN_PROFILES: Array[int] = [
	UiRegistry.PROFILE_BUTTON, UiRegistry.PROFILE_TOGGLE, UiRegistry.PROFILE_ROW,
	UiRegistry.PROFILE_FIELD, UiRegistry.PROFILE_READOUT,
]
const PROFILE_VARIATION: Array[StringName] = [
	&"WoodlandPanel", &"WoodlandButton", &"WoodlandToggle", &"WoodlandRow", &"WoodlandField",
	&"WoodlandReadout", &"WoodlandMeter", &"WoodlandNotice", &"WoodlandOverlay", &"WoodlandModal",
]
## §2.2's five states, in the order the row draws them.
const STATE_LABELS: Array[String] = ["default", "hover", "pressed", "disabled", "selected"]

const MARGIN: float = 24.0
const ROW_HEIGHT: float = 56.0
const CELL_WIDTH: float = 150.0
const CELL_GAP: float = 12.0
const LABEL_WIDTH: float = 130.0
const METER_VALUE: float = 62.0
const SYNTHETIC_COUNTER: String = "1,234 U"


func _ready() -> void:
	"""Build the whole specimen once, against the same theme the real HUD uses."""
	theme = load(THEME_PATH) as Theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_background()
	var cursor: float = MARGIN
	cursor = _add_banner(cursor)
	for profile: int in SPECIMEN_PROFILES:
		cursor = _add_profile_row(profile, cursor)
	cursor = _add_field_row(cursor)
	cursor = _add_meter_row(cursor)
	_add_refusal_row(cursor)


func _add_background() -> void:
	"""An opaque INK backdrop, so contrast is judged against a known colour, not the world."""
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = UiTheme.color_of(UiTheme.TOKEN_INK)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)


func _add_banner(cursor: float) -> float:
	"""The label that keeps this scene from ever being mistaken for the running game."""
	var banner: Label = Label.new()
	banner.name = "Banner"
	banner.text = BANNER
	banner.theme_type_variation = &"WoodlandPageTitle"
	banner.position = Vector2(MARGIN, cursor)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	return cursor + ROW_HEIGHT + CELL_GAP


func _add_profile_row(profile: int, cursor: float) -> float:
	"""One §2.2 profile drawn in all five of its interaction states."""
	_add_row_label(UiRegistry.PROFILE_KEYS[profile], cursor)
	for state: int in STATE_LABELS.size():
		var sample: Button = Button.new()
		sample.name = "%s_%s" % [UiRegistry.PROFILE_KEYS[profile], STATE_LABELS[state]]
		sample.text = STATE_LABELS[state]
		sample.theme_type_variation = PROFILE_VARIATION[profile]
		sample.position = Vector2(MARGIN + LABEL_WIDTH + float(state) * (CELL_WIDTH + CELL_GAP),
			cursor)
		sample.size = Vector2(CELL_WIDTH, UiTheme.ORDINARY_BUTTON_HEIGHT)
		_apply_state(sample, state)
		add_child(sample)
	return cursor + ROW_HEIGHT


func _apply_state(sample: Button, state: int) -> void:
	"""Force one sample into the state it is meant to demonstrate."""
	if state == UiTheme.STATE_DISABLED:
		sample.disabled = true
		sample.icon = load("res://ui/icons/lock.svg") as Texture2D
		return
	if state == UiTheme.STATE_SELECTED:
		sample.toggle_mode = true
		sample.button_pressed = true
		sample.theme_type_variation = PROFILE_VARIATION[UiRegistry.PROFILE_TOGGLE]
		return
	if state == UiTheme.STATE_HOVER or state == UiTheme.STATE_PRESSED:
		sample.add_theme_stylebox_override(&"normal", _forced_style(state))


func _forced_style(state: int) -> StyleBoxFlat:
	"""Draw a resting control with the hover or pressed background, for the specimen only."""
	var tokens: UiTheme = UiTheme.new()
	var box: StyleBoxFlat = tokens.panel_style(UiRegistry.PROFILE_BUTTON, state)
	box.set_content_margin_all(2.0)
	return box




func _add_row_label(text: String, cursor: float) -> void:
	"""The name of the profile a row demonstrates."""
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"WoodlandSecondary"
	label.position = Vector2(MARGIN, cursor + CELL_GAP)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_field_row(cursor: float) -> float:
	"""A real text field, so the FIELD profile is judged as an input and not as a button."""
	_add_row_label("FIELD input", cursor)
	var field: LineEdit = LineEdit.new()
	field.name = "SpecimenField"
	field.text = "Rowan's Refuge"
	field.position = Vector2(MARGIN + LABEL_WIDTH, cursor)
	field.size = Vector2(CELL_WIDTH * 2.0, UiTheme.ORDINARY_BUTTON_HEIGHT)
	add_child(field)
	return cursor + ROW_HEIGHT


func _add_meter_row(cursor: float) -> float:
	"""A METER with its value ABOVE the track, as §2.2 requires, on an opaque panel."""
	_add_row_label("METER", cursor)
	var readout: Label = Label.new()
	readout.name = "SpecimenMeterValue"
	readout.text = "Rest %d of 100  (synthetic)" % int(METER_VALUE)
	readout.theme_type_variation = &"WoodlandCounter"
	readout.position = Vector2(MARGIN + LABEL_WIDTH, cursor)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(readout)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "SpecimenMeter"
	bar.value = METER_VALUE
	bar.show_percentage = false
	bar.position = Vector2(MARGIN + LABEL_WIDTH, cursor + 28.0)
	bar.size = Vector2(CELL_WIDTH * 2.0, 8.0)
	add_child(bar)
	return cursor + ROW_HEIGHT


func _add_refusal_row(cursor: float) -> void:
	"""§7's notice shape: a severity icon AND words, never colour alone."""
	_add_row_label("NOTICE refusal", cursor)
	var panel: Panel = Panel.new()
	panel.name = "SpecimenRefusal"
	panel.theme_type_variation = &"WoodlandNotice"
	panel.position = Vector2(MARGIN + LABEL_WIDTH, cursor)
	panel.size = Vector2(CELL_WIDTH * 4.0, UiTheme.ORDINARY_BUTTON_HEIGHT)
	add_child(panel)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://ui/icons/warning.svg") as Texture2D
	icon.modulate = UiTheme.color_of(UiTheme.TOKEN_DANGER)
	icon.position = Vector2(10.0, 10.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.accessibility_name = ""
	panel.add_child(icon)
	var text: Label = Label.new()
	text.text = "Refused: paint at least one tile before designating. (synthetic)"
	text.position = Vector2(44.0, 12.0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text)
