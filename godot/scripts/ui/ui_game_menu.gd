extends "res://scripts/ui/ui_modal_frame.gd"
## UI-SET-078, the "Game menu" variant (ADR 1222 step 11; DEC-055, 2026-10-08).
##
## §4.3: "Resume, Save, Load, Settings, Main menu, Quit via 066/067/092 templates", opened by
## UI-SET-019 and by Escape on an empty dismissal stack; it adds the MENU pause reason (the host
## holds it while any save modal is open). Brendan's choice: Settings and Main menu are SHOWN as
## unavailable with their reason -- no settings store exists, and the game has no main menu scene
## to return to -- rather than hidden, so the menu keeps §4's shape. Quit (UI-SET-092) gives the
## "dirty save warning when leaving world" when the world moved since the session's last save or
## load: a second step whose 066 quits and whose 067 keeps playing.
##
## Every action only asks the host (signals); nothing here writes game state.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")

signal resume_requested
signal save_requested
signal load_requested
signal quit_confirmed

const TITLE: String = "Game menu"
const PREFERRED_SIZE: Vector2 = Vector2(480.0, 600.0)
const ACTION_MINIMUM: Vector2 = Vector2(280.0, 44.0)
const SETTINGS_REASON: String = "Unavailable: no settings store exists yet."
const MAIN_MENU_REASON: String = "Unavailable: there is no main menu scene yet."
const QUIT_WARNING: String = "The settlement has changed since it was last saved or loaded.\nQuitting now loses that progress."

var _session: UiSaveSession = null
var _resume: Button = null
var _save: Button = null
var _load: Button = null
var _settings: Button = null
var _main_menu: Button = null
var _quit: Button = null
var _warning: Label = null
var _keep_playing: Button = null
var _confirm_quit: Button = null
var _confirming: bool = false


func setup(session: UiSaveSession) -> void:
	"""Build the menu over `session` (read only for the unsaved-progress warning)."""
	_session = session
	build(TITLE, "UI-SET-078", PREFERRED_SIZE, true)
	_resume = _action("UI-SET-067_resume", "Resume", "Resume the game", resume_requested.emit)
	_save = _action("UI-SET-066_save", "Save", "Save the settlement", save_requested.emit)
	_load = _action("UI-SET-066_load", "Load", "Load a saved settlement", load_requested.emit)
	_settings = _unavailable("UI-SET-078_settings", "Settings", SETTINGS_REASON)
	_main_menu = _unavailable("UI-SET-092_main_menu", "Main menu", MAIN_MENU_REASON)
	_quit = _action("UI-SET-092_quit", "Quit game", "Quit the game", _on_quit)
	_build_quit_step()
	dismiss_requested.connect(_on_dismiss)
	_paint()


func _action(key: String, text: String, accessible: String, handler: Callable) -> Button:
	"""One menu action button in the body column."""
	var button: Button = new_button(key, text, accessible)
	button.custom_minimum_size = ACTION_MINIMUM
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	body().add_child(button)
	return button


func _unavailable(key: String, text: String, reason: String) -> Button:
	"""A §2.2 disabled button with its reason printed under it and given to a screen reader."""
	var button: Button = _action(key, text, text, func() -> void: pass)
	make_unavailable(button, reason)
	var line: Label = Label.new()
	line.name = "%sReason" % text.replace(" ", "")
	line.text = reason
	line.theme_type_variation = &"WoodlandSecondary"
	body().add_child(line)
	return button


func _build_quit_step() -> void:
	"""The dirty-save warning and its two footer actions."""
	_warning = Label.new()
	_warning.name = "QuitWarning"
	_warning.text = QUIT_WARNING
	header().add_child(_warning)
	_keep_playing = new_button("UI-SET-067_keep_playing", "Keep playing", "Keep playing")
	_keep_playing.pressed.connect(_leave_quit_step)
	_confirm_quit = new_button("UI-SET-066_quit", "Quit game", "Quit the game and lose unsaved progress")
	_confirm_quit.custom_minimum_size = Vector2(120.0, BUTTON_HEIGHT)
	_confirm_quit.pressed.connect(quit_confirmed.emit)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control: Control in [_keep_playing, spacer, _confirm_quit]:
		footer().add_child(control)


func open() -> void:
	"""Show the menu on its first action."""
	_confirming = false
	_paint()
	show_modal(_resume)


func _paint() -> void:
	"""Show the menu actions, or the quit warning step."""
	_warning.visible = _confirming
	footer().visible = _confirming
	_keep_playing.visible = _confirming
	_confirm_quit.visible = _confirming
	for button: Button in [_resume, _save, _load, _quit]:
		button.disabled = _confirming
	var order: Array[Control] = [_resume, _save, _load, _settings, _main_menu, _quit]
	if _confirming:
		order = [_keep_playing, _confirm_quit]
	order.append(close_button())
	set_focus_ring(order)
	relayout()


func _on_quit() -> void:
	"""UI-SET-092 Quit: at once when nothing is unsaved, else the warning step first."""
	if _session == null or not _session.has_unsaved_progress():
		quit_confirmed.emit()
		return
	_confirming = true
	_paint()
	focus_later(_keep_playing)


func _leave_quit_step() -> void:
	"""Back from the warning to the menu."""
	_confirming = false
	_paint()
	focus_later(_quit)


func is_confirming_quit() -> bool:
	"""Whether the quit warning step is showing."""
	return _confirming


func action_button(key: String) -> Button:
	"""One of the menu's buttons by its registry key (for the host's focus return and the suite)."""
	for button: Button in [_resume, _save, _load, _settings, _main_menu, _quit, _keep_playing,
			_confirm_quit]:
		if String(button.name) == key:
			return button
	return null


func _on_dismiss() -> void:
	"""Escape or UI-SET-093: leave the quit step first, else resume."""
	if _confirming:
		_leave_quit_step()
		return
	resume_requested.emit()
