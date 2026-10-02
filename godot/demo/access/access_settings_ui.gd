extends VBoxContainer
## The game menu's ACCESSIBILITY AND TIME settings (demo_menu.gd's Settings page). Decision 0471 (review UX-023,
## UX-022; UI §8.1). DEMO UI in the woodland skin.
##
## PRESETS: Large readable, Keyboard planner, Reduced motion, Quiet focus (demo_access.gd). Hovering or focusing one
## PREVIEWS it -- the line under them says exactly what it would change ("Interface scale 100% → 150% · Bigger
## tooltips off → on") -- and pressing applies it at once: the interface, the panels and the world change live, and
## each setting it turned on stays the player's to turn off below.
## SETTINGS: one toggle per setting, saying "on" or "off" in words (colour never says it alone), with what it does as
## its tooltip; under "Time", the two auto-pauses (pause while planning; pause on a critical incident).
## RESTORE DEFAULTS shows the change it would make and asks first (UI §8.1); with nothing to change it says so.
## Everything goes through the host: `scale_to(percent)` (the menu's interface scale), `scale_fits(percent) -> bool`
## and `applied()` (the settings' effects, access_effects.gd).

const FarmUi := preload("res://demo/farm/farm_ui.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Access := preload("res://demo/access/demo_access.gd")

const TITLE: String = "Accessibility"
const PRESETS_TITLE: String = "Presets (point at one to preview it)"
const TIME_TITLE: String = "Time"
const TOGGLE_TEXT: String = "%s: %s"
const PREVIEW_TEXT: String = "%s would change: %s"
const APPLIED_TEXT: String = "Applied %s: %s"
const RESTORE_TEXT: String = "Restore defaults"
const RESTORE_ASK: String = "Restore the defaults? This changes: %s"
const RESTORE_DONE: String = "Defaults restored: %s"
const RESTORE_NONE: String = "Everything is at its default already."
const RESTORE_OK: String = "Restore"
const CANCEL_TEXT: String = "Cancel"
const LINE_W: float = 500.0
## The settings under "Accessibility" and under "Time", in the order shown.
const ACCESS_SETTINGS: PackedInt32Array = [Access.SET_TOOLTIPS, Access.SET_CONTRAST, Access.SET_FOCUS_HINTS,
	Access.SET_TARGETS, Access.SET_MOTION, Access.SET_BRIGHT_NIGHTS, Access.SET_QUIET_TOASTS]
const TIME_SETTINGS: PackedInt32Array = [Access.SET_PAUSE_PLANNING, Access.SET_PAUSE_CRITICAL]

var scale_to: Callable = Callable()
var scale_fits: Callable = Callable()
var applied: Callable = Callable()

var _presets: Array[Button] = []
var _toggles: Array[Button] = []
var _preview: Label = null
var _status: String = ""
var _restore: Button = null
var _confirm: HBoxContainer = null
var _ask: Label = null
var _cancel: Button = null
var _now: Access.Snapshot = Access.Snapshot.new()
var _then: Access.Snapshot = Access.Snapshot.new()
## The refresh's own two (a refresh runs inside an apply, which still holds `_now` and `_then`).
var _lit_now: Access.Snapshot = Access.Snapshot.new()
var _lit_then: Access.Snapshot = Access.Snapshot.new()


func _init() -> void:
	"""Built at once, from the settings as they stand."""
	name = "AccessSettings"
	add_theme_constant_override(&"separation", 6)
	add_child(FarmUi.label(TITLE, FarmUi.BODY_PX, Palette.INK, true))
	add_child(_line(PRESETS_TITLE, Palette.UMBER))
	add_child(_preset_grid())
	_preview = _line("", Palette.UMBER)
	add_child(_preview)
	_toggles.resize(Access.SET_COUNT)
	for setting: int in ACCESS_SETTINGS:
		add_child(_toggle(setting))
	add_child(FarmUi.label(TIME_TITLE, FarmUi.BODY_PX, Palette.INK, true))
	for setting: int in TIME_SETTINGS:
		add_child(_toggle(setting))
	_restore = FarmUi.button(RESTORE_TEXT, FarmUi.SMALL_PX)
	_restore.pressed.connect(ask_restore)
	add_child(_restore)
	add_child(_build_confirm())
	refresh()


func _line(text: String, colour: Color) -> Label:
	"""A small wrapping line, wide from the start."""
	var line: Label = FarmUi.label(text, FarmUi.SMALL_PX, colour)
	line.custom_minimum_size.x = LINE_W
	return line


func _preset_grid() -> GridContainer:
	"""The four presets, two a row; each previews on hover and focus."""
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 6)
	for preset: int in Access.PRESET_COUNT:
		var button: Button = FarmUi.button(Access.PRESET_NAMES[preset], FarmUi.SMALL_PX)
		button.toggle_mode = true
		button.tooltip_text = Access.PRESET_TIPS[preset]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(apply_preset.bind(preset))
		for entered: Signal in [button.mouse_entered, button.focus_entered]:
			entered.connect(preview.bind(preset))
		for left: Signal in [button.mouse_exited, button.focus_exited]:
			left.connect(_show_status)
		grid.add_child(button)
		_presets.append(button)
	return grid


func _toggle(setting: int) -> Button:
	"""Setting `setting`'s toggle ("Reduced motion: on")."""
	var button: Button = FarmUi.button("", FarmUi.SMALL_PX)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = Access.SET_TIPS[setting]
	button.toggled.connect(set_setting.bind(setting))
	_toggles[setting] = button
	return button


func _build_confirm() -> HBoxContainer:
	"""Restore's question: what it changes, Restore and Cancel (hidden until asked)."""
	_confirm = HBoxContainer.new()
	_confirm.add_theme_constant_override(&"separation", 8)
	_confirm.visible = false
	_ask = _line("", Palette.CLAY)
	_ask.custom_minimum_size.x = LINE_W - 200.0
	_ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.add_child(_ask)
	var ok: Button = FarmUi.button(RESTORE_OK, FarmUi.SMALL_PX)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(restore_defaults)
	_confirm.add_child(ok)
	_cancel = FarmUi.button(CANCEL_TEXT, FarmUi.SMALL_PX)
	_cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cancel.pressed.connect(cancel_restore)
	_confirm.add_child(_cancel)
	return _confirm


# --- changes --------------------------------------------------------------------------------------------------

func preview(preset: int) -> String:
	"""Show what preset `preset` would change (nothing applied); returns the line."""
	Access.current_into(_now)
	Access.preset_into(preset, _now, scale_fits, _then)
	var change: String = Access.diff_text(_now, _then)
	_preview.text = PREVIEW_TEXT % [Access.PRESET_NAMES[preset], change if not change.is_empty() else Access.NO_CHANGE]
	return _preview.text


func apply_preset(preset: int) -> String:
	"""Apply preset `preset`'s settings now; returns what changed ("" nothing)."""
	Access.current_into(_now)
	Access.preset_into(preset, _now, scale_fits, _then)
	var change: String = _take(_then)
	_status = APPLIED_TEXT % [Access.PRESET_NAMES[preset], change if not change.is_empty() else Access.NO_CHANGE]
	_show_status()
	return change


func set_setting(on: bool, setting: int) -> void:
	"""One setting's toggle."""
	if Access.set_flag(setting, on):
		_applied()
	refresh()


func ask_restore() -> void:
	"""Restore defaults: show what it would change and ask, or say there is nothing to restore."""
	Access.current_into(_now)
	Access.defaults_into(_then)
	var change: String = Access.diff_text(_now, _then)
	if change.is_empty():
		_status = RESTORE_NONE
		_show_status()
		return
	_ask.text = RESTORE_ASK % change
	_confirm.visible = true
	_focus_cancel.call_deferred()


func _focus_cancel() -> void:
	"""The question's Cancel takes the focus (UI §8.2: a confirmation focuses Cancel), which scrolls it into view
	(demo_scroll.gd) once the row is laid out."""
	if _cancel.is_inside_tree() and _cancel.is_visible_in_tree():
		_cancel.grab_focus()


func restore_defaults() -> String:
	"""Restore every setting here to its default (asked first: `ask_restore`); returns what changed."""
	Access.current_into(_now)
	Access.defaults_into(_then)
	var change: String = _take(_then)
	_confirm.visible = false
	_status = RESTORE_DONE % change if not change.is_empty() else RESTORE_NONE
	_show_status()
	return change


func cancel_restore() -> void:
	"""Leave the settings as they are."""
	_confirm.visible = false


func _take(wanted: Access.Snapshot) -> String:
	"""Make `wanted` the settings -- flags and mix, then the scale through the host -- apply them; the change made."""
	var change: String = Access.diff_text(_now, wanted)
	Access.store(wanted)
	if wanted.scale_percent != _now.scale_percent and scale_to.is_valid():
		scale_to.call(wanted.scale_percent)
	_applied()
	refresh()
	return change


func _applied() -> void:
	"""Have the host apply the settings' effects."""
	if applied.is_valid():
		applied.call()


func _show_status() -> void:
	"""The preview line back to the last thing done."""
	_preview.text = _status


func refresh() -> void:
	"""Every toggle's words and state from the settings as they stand; a preset lit while all it sets is in place."""
	Access.current_into(_lit_now)
	for preset: int in Access.PRESET_COUNT:
		Access.preset_into(preset, _lit_now, scale_fits, _lit_then)
		_presets[preset].set_pressed_no_signal(_lit_now.same_as(_lit_then))
	for setting: int in Access.SET_COUNT:
		var on: bool = Access.is_on(setting)
		_toggles[setting].set_pressed_no_signal(on)
		_toggles[setting].text = TOGGLE_TEXT % [Access.SET_NAMES[setting], Access.ON_OFF[1 if on else 0]]


# --- checks ---------------------------------------------------------------------------------------------------

func preset_button(preset: int) -> Button:
	"""Preset `preset`'s button."""
	return _presets[preset]


func toggle_button(setting: int) -> Button:
	"""Setting `setting`'s toggle."""
	return _toggles[setting]


func restore_button() -> Button:
	"""Restore defaults."""
	return _restore


func confirm_shown() -> bool:
	"""Whether Restore is asking."""
	return _confirm.visible


func preview_text() -> String:
	"""The preview line."""
	return _preview.text
