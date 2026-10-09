extends Node
## The save controls in the running game: one `ui_save_session.gd`, its frame poll and its HUD reports
## (ADR 1222 step 11).
##
## `main.gd` adds this node only when it IS the game scene (a host that instances the game, such as
## the live demo, keeps saves off). It polls the session every frame, also while paused, so F5 and the
## autosaves are taken at the first quiescent boundary between ticks. Its signal handlers only paint the
## HUD (CLAUDE.md: signals for UI updates): a saved or loaded notice, or UI-SET-085's code, plain reason
## and recovery action kept as an error notice. It writes no game state; the session reads and loads the
## world through the save slots.
##
## The notices use the HUD's existing authored categories -- "Settlement notice" for a save, a load
## and a recovery report, "Action refused" for a refused save or load -- with the save's own wording in
## the message, so no notice title or severity table changes for this.
##
## THE SAVE MODALS (ADR 1222 step 11, DEC-055 2026-10-08). This node also hosts UI-SET-078's game
## menu and UI-SET-076's save browser on a §3 layer-80 CanvasLayer, laid out on the HUD shell's
## §1.2 geometry. UI-SET-019 opens the menu through the shell's host-menu seam
## (`set_menu_handler`); `main.gd` opens it on Escape when nothing else is open and opens the
## browser on F9. While either is showing it holds the MENU pause reason. They are not built into
## `ui_shell.gd`'s registry tree: that file builds the HUD's permanent zones and one workspace
## frame, and both reviewed census witnesses (`ui_manager.gd`, `ui_notices.gd`) stay untouched.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const UiNotices := preload("res://scripts/ui/ui_notices.gd")
const UiGameMenu := preload("res://scripts/ui/ui_game_menu.gd")
const UiSaveBrowser := preload("res://scripts/ui/ui_save_browser.gd")
const UiSaveRows := preload("res://scripts/ui/ui_save_rows.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const Slots := preload("res://scripts/core/settlement_save_slots.gd")

const SOURCE: String = "Settlement save"
const REFUSE_NONE: StringName = &""

var _session: UiSaveSession = UiSaveSession.new()
var _hud: HudScript = null
var _manager: Node = null
var _layer: CanvasLayer = null
var _menu: UiGameMenu = null
var _browser: UiSaveBrowser = null
var _menu_open: bool = false
var _browser_open: bool = false
var _menu_pause_held: bool = false
## What Quit game does once confirmed; unset, the tree quits. A suite sets its own.
var quit_handler: Callable = Callable()


func _ready() -> void:
	"""Keep polling while the world is paused, and re-place the modals when the window resizes."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout_modals)


func bind(settlement: Node, manager: Node, hud: HudScript) -> void:
	"""Serve this settlement and clock owner, and report to this HUD (null: no reports)."""
	_manager = manager
	_hud = hud
	_session.bind(settlement, manager)
	if not _session.save_finished.is_connected(_on_save_finished):
		_session.save_finished.connect(_on_save_finished)
		_session.load_finished.connect(_on_load_finished)
		_session.demolition_placed.connect(_on_demolition_placed)
	_build_modals()
	if _has_hud() and _hud.shell() != null:
		_hud.shell().set_menu_handler(open_game_menu)


func _exit_tree() -> void:
	"""Give UI-SET-019 back to the shell's own default and drop any MENU this node held."""
	if _has_hud() and _hud.shell() != null:
		_hud.shell().set_menu_handler(Callable())
	close_modals()


func enable() -> int:
	"""Turn the controls on and run DEC-055 Q10's launch recovery once. Returns the files reported."""
	_session.set_enabled(true)
	var rows: Array[Dictionary] = _session.recover_at_launch()
	for row: Dictionary in rows:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, UiSaveSession.recovery_line(row),
			"SAVE_RECOVERY_%s" % String(row["action"]).to_upper(), "")
	return rows.size()


func session() -> UiSaveSession:
	"""The save session these controls drive."""
	return _session


func request_quicksave() -> bool:
	"""UI §5 `save_quick` (F5): the quicksave at the next quiescent boundary."""
	return _session.request_quicksave()


func _process(_delta: float) -> void:
	"""Between ticks, every frame: take the queued saves."""
	_session.poll()


func _has_hud() -> bool:
	"""A bound HUD that has not been freed."""
	return _hud != null and is_instance_valid(_hud)


func _notice(category: int, message: String, code: String, recovery: String) -> void:
	"""Raise one notice on the HUD, when one is bound."""
	if _has_hud():
		_hud.shell().raise_notice(category, message, SOURCE, code, recovery)


func _on_save_finished(kind: String, slot: String, code: StringName, detail: String) -> void:
	"""A save finished: a notice naming the slot and its development status, or the refusal in full."""
	var title: String = UiSaveSession.slot_title(kind, slot)
	if code == REFUSE_NONE:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "%s saved at %s. %s" % [title,
			_manager.get_calendar_text(), UiSaveSession.DEVELOPMENT_NOTE], "", "")
		return
	_report(title, code, detail, false)


func _on_load_finished(kind: String, slot: String, code: StringName, detail: String) -> void:
	"""A load finished: a notice naming the slot, or the refusal in full."""
	var title: String = UiSaveSession.slot_title(kind, slot)
	if code == REFUSE_NONE:
		_notice(UiNotices.CATEGORY_SETTLEMENT_NOTICE, "%s loaded at %s." % [title,
			_manager.get_calendar_text()], "", "")
		return
	_report(title, code, detail, true)


func _report(title: String, code: StringName, detail: String, loading: bool) -> void:
	"""UI-SET-085: the code, the plain reason and the recovery action, kept as an error notice."""
	var reason: String = "%s: %s %s" % [title, UiSaveSession.reason_for(code, loading), detail]
	var recovery: String = UiSaveSession.recovery_for(code, loading)
	if _has_hud():
		_hud.show_refusal("%s %s %s" % [String(code), reason, recovery])
	_notice(UiNotices.CATEGORY_ACTION_REFUSED, reason, String(code), recovery)


func _on_demolition_placed(_building_ref: Vector2i, code: StringName) -> void:
	"""A demolition order placed behind its pre-demolition save was refused: show why."""
	if code == REFUSE_NONE:
		return
	var reason: String = "The demolition order placed after its pre-demolition quicksave was refused."
	if _has_hud():
		_hud.show_refusal("%s %s" % [String(code), reason])
	_notice(UiNotices.CATEGORY_ACTION_REFUSED, reason, String(code), "")


# --- the save modals: UI-SET-078 game menu and UI-SET-076 save browser --------------------------

## §3 layer 80: "Confirmation/error/modal menu".
const MODAL_LAYER: int = 80


func _build_modals() -> void:
	"""The game menu and the save browser on their own layer-80 CanvasLayer, hidden."""
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "SaveModals"
	_layer.layer = MODAL_LAYER
	add_child(_layer)
	_menu = UiGameMenu.new()
	_menu.setup(_session)
	_layer.add_child(_menu)
	_browser = UiSaveBrowser.new()
	_browser.setup(_session)
	_layer.add_child(_browser)
	_connect_modals()


func _connect_modals() -> void:
	"""Every modal action reaches the host as a signal; the browser repaints on the session's."""
	_menu.resume_requested.connect(close_modals)
	_menu.save_requested.connect(open_browser.bind(UiSaveRows.TAB_MANUAL))
	_menu.load_requested.connect(open_browser.bind(UiSaveRows.TAB_MANUAL))
	_menu.quit_confirmed.connect(_on_quit_confirmed)
	_browser.closed.connect(_on_browser_closed)
	_browser.load_done.connect(_on_browser_load_done)
	_session.save_finished.connect(_refresh_browser.unbind(4))
	_session.slot_renamed.connect(_refresh_browser.unbind(3))


func modal_open() -> bool:
	"""Whether the game menu or the save browser is showing."""
	return _menu_open or _browser_open


func game_menu() -> UiGameMenu:
	"""UI-SET-078 (built when the controls are bound in the tree)."""
	return _menu


func browser() -> UiSaveBrowser:
	"""UI-SET-076 (built when the controls are bound in the tree)."""
	return _browser


func open_game_menu() -> bool:
	"""UI-SET-019 or Escape on an empty dismissal stack: the game menu, holding MENU."""
	if _menu == null or not _session.is_bound() or _manager.is_loading():
		return false
	_hold_menu_pause(true)
	_menu_open = true
	_layout_modals()
	_menu.open()
	return true


func open_browser(tab: int, kind: String = "", slot: String = "") -> bool:
	"""UI-SET-076 on `tab`, over the menu when it is open, selecting `kind/slot` when given."""
	if _browser == null or not _session.is_bound() or _manager.is_loading():
		return false
	_hold_menu_pause(true)
	_browser_open = true
	_menu.visible = false
	_layout_modals()
	_browser.open(tab, kind, slot)
	return true


func open_quickload() -> bool:
	"""UI §5 `load_quick` (F9): the browser on the quicksave, its Load focused. Load names the save
	and its date, and nothing loads until it is pressed."""
	return open_browser(UiSaveRows.tab_of_kind(Slots.KIND_QUICK),
		Slots.KIND_QUICK, Slots.QUICK_NAME)


func close_modals() -> void:
	"""Hide both modals and release MENU (a PLAYER pause the player set is kept)."""
	_browser_open = false
	_menu_open = false
	if _browser != null:
		_browser.hide_modal()
	if _menu != null:
		_menu.hide_modal()
	_hold_menu_pause(false)


func _on_browser_closed() -> void:
	"""The browser closed: back to the menu it was opened from, else back to the world."""
	_browser_open = false
	_browser.hide_modal()
	if _menu_open:
		_menu.open()
		return
	close_modals()


func _on_browser_load_done(code: StringName) -> void:
	"""A load from the browser: on success the world is the save's, so every modal closes."""
	if code == REFUSE_NONE:
		close_modals()


func _refresh_browser() -> void:
	"""Repaint the browser's rows after a save or a rename (a UI update on the session's signal)."""
	if _browser_open:
		_browser.refresh()


func _hold_menu_pause(held: bool) -> void:
	"""§3: an open game menu or save browser holds the MENU pause reason; closing releases it."""
	if held == _menu_pause_held or _manager == null:
		return
	if _manager.set_menu_pause(held):
		_menu_pause_held = held


func _layout_modals() -> void:
	"""Place both modals on the HUD shell's own §1.2 geometry and scale."""
	if _layer == null or not _has_hud() or _hud.shell() == null:
		return
	var geometry: UiLayout.Geometry = _hud.shell().geometry()
	if geometry == null or geometry.logical_width <= 0.0:
		return
	var logical: Rect2 = Rect2(0.0, 0.0, geometry.logical_width, geometry.logical_height)
	_menu.layout(logical, geometry.modal, geometry.scale)
	_browser.layout(logical, geometry.modal, geometry.scale)


func _on_quit_confirmed() -> void:
	"""UI-SET-092 Quit game, after the unsaved-progress warning when there was progress."""
	close_modals()
	if quit_handler.is_valid():
		quit_handler.call()
		return
	get_tree().quit()
