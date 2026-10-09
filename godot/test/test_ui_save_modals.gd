extends "res://test/framework/test_case.gd"
## The save browser (UI-SET-076/077), the game menu (UI-SET-078) and their rows, slots and session
## calls (ADR 1222 step 11; DEC-055, 2026-10-08). Every file goes under TEST_ROOT.
##
## Brendan's choices pinned here: the quicksave and the pre-demolition quicksave are Autosave-tab
## rows; a manual save is auto-named and may be renamed; a recovered checkpoint is a "Recovered"
## row in its tab; the development-only note is in the browser header; Settings and Main menu are
## shown unavailable with a reason; F9 confirms through the browser's Load.

const UiSaveSession := preload("res://scripts/ui/ui_save_session.gd")
const UiSaveBrowser := preload("res://scripts/ui/ui_save_browser.gd")
const UiGameMenu := preload("res://scripts/ui/ui_game_menu.gd")
const UiSaveRows := preload("res://scripts/ui/ui_save_rows.gd")
const Slots := preload("res://scripts/core/settlement_save_slots.gd")
const SaveFile := preload("res://scripts/core/save_file.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

const TEST_ROOT: String = "user://test_ui_save_modals"

var _settlement: Node = null
var _manager: Node = null
var _session: UiSaveSession = null
var _loaded: Array[StringName] = []


func before_each() -> void:
	"""A generated settlement on its own started clock, an enabled session and an empty root."""
	_remove_tree(TEST_ROOT)
	Slots.root = TEST_ROOT
	_settlement = SettlementSystemScript.new()
	_manager = GameManagerScript.new()
	assert_true(_settlement.create_generated_settlement(_settlement.item_definitions()), "generates")
	assert_true(_manager.start_game(), "the clock runs")
	_session = UiSaveSession.new()
	_session.bind(_settlement, _manager)
	_session.set_enabled(true)
	_session.load_finished.connect(func(_k: String, _n: String, c: StringName, _d: String) -> void:
		_loaded.append(c))


func after_each() -> void:
	"""Free the nodes, restore the slot root and delete the test files."""
	_session = null
	_loaded.clear()
	_settlement.free()
	_manager.free()
	Slots.root = Slots.ROOT
	_remove_tree(TEST_ROOT)


func _remove_tree(directory: String) -> void:
	"""Delete every file one level under each kind directory, then the directories."""
	var absolute: String = ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for kind: String in DirAccess.get_directories_at(directory):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [directory, kind]):
			DirAccess.remove_absolute("%s/%s/%s" % [absolute, kind, file_name])
		DirAccess.remove_absolute("%s/%s" % [absolute, kind])
	DirAccess.remove_absolute(absolute)


func _browser() -> UiSaveBrowser:
	"""A built browser over the session (freed by the caller)."""
	var browser: UiSaveBrowser = UiSaveBrowser.new()
	browser.setup(_session)
	return browser


func _titles(rows: Array[UiSaveRows.Row]) -> PackedStringArray:
	"""The rows' titles in order."""
	var titles: PackedStringArray = PackedStringArray()
	for row: UiSaveRows.Row in rows:
		titles.append(row.title)
	return titles


# --- slots: auto-naming, rename, recovered checkpoints ---------------------------------------------

func test_manual_saves_are_auto_named_and_a_rename_changes_only_the_label() -> void:
	"""save_001, save_002; a rename rewrites the sidecar label and leaves the save's bytes alone."""
	assert_equal(Slots.next_manual_name(), "save_001", "the first name")
	assert_true(_session.save_new_manual().is_ok(), "first save")
	assert_equal(Slots.next_manual_name(), "save_002", "the next name")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(Slots.slot_path(Slots.KIND_MANUAL, "save_001"))
	assert_true(_session.rename_manual("save_001", "  Spring camp ").is_ok(), "renamed")
	assert_equal(FileAccess.get_file_as_bytes(Slots.slot_path(Slots.KIND_MANUAL, "save_001")), before,
		"the save's bytes are unchanged")
	var rows: Array[UiSaveRows.Row] = UiSaveRows.rows_for_tab(UiSaveRows.TAB_MANUAL)
	assert_equal(_titles(rows), PackedStringArray(["Spring camp"]), "the row shows the new name")
	assert_equal(_session.rename_manual("save_001", "bad\tname").code, Slots.REFUSE_LABEL,
		"a control character refuses")
	assert_equal(_session.rename_manual("save_001", "   ").code, Slots.REFUSE_LABEL, "so does nothing")
	assert_equal(Slots.rename_slot(Slots.KIND_QUICK, Slots.QUICK_NAME, "x").code, Slots.REFUSE_SLOT,
		"only a manual save is renamed")


func test_the_tabs_hold_brendans_rows_and_a_recovered_checkpoint_is_marked() -> void:
	"""Quicksave and pre-demolition quicksave in Autosave; a kept .rollback is a Recovered row."""
	for slot: Array in [[Slots.KIND_QUICK, Slots.QUICK_NAME], [Slots.KIND_DEMOLITION,
			Slots.DEMOLITION_NAME], [Slots.KIND_PREWINTER, Slots.PREWINTER_NAME]]:
		assert_true(_session.save_slot(slot[0], slot[1]).is_ok(), "saved %s" % slot[0])
	var quick: String = Slots.slot_path(Slots.KIND_QUICK, Slots.QUICK_NAME)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(quick),
		ProjectSettings.globalize_path(quick + Slots.ROLLBACK_SUFFIX))
	var autosave: PackedStringArray = _titles(UiSaveRows.rows_for_tab(UiSaveRows.TAB_AUTOSAVE))
	assert_true(autosave.has("Quicksave") and autosave.has("Pre-demolition quicksave"),
		"both quicksaves are Autosave rows: %s" % autosave)
	assert_true(autosave.has("Recovered: the settlement before loading Quicksave"),
		"the recovered checkpoint is a marked row: %s" % autosave)
	assert_equal(_titles(UiSaveRows.rows_for_tab(UiSaveRows.TAB_PREWINTER)),
		PackedStringArray(["Prewinter autosave"]), "Prewinter holds its own")
	assert_true(UiSaveRows.rows_for_tab(UiSaveRows.TAB_MANUAL).is_empty(), "Manual is empty")
	for row: UiSaveRows.Row in UiSaveRows.rows_for_tab(UiSaveRows.TAB_AUTOSAVE):
		assert_true(row.valid, "%s loads in this build" % row.title)
		assert_equal(row.validity_text, UiSaveRows.VALID_TEXT, "and says so")
		assert_true(row.when_text.begins_with("Y1 "), "an in-game date: %s" % row.when_text)


func test_a_load_never_replaces_a_kept_checkpoint_and_a_recovered_row_loads_and_stays() -> void:
	"""Q10: a recovered file is never deleted -- not by loading its slot, not by loading it."""
	assert_true(_session.save_slot(Slots.KIND_QUICK, Slots.QUICK_NAME).is_ok(), "saved")
	var quick: String = Slots.slot_path(Slots.KIND_QUICK, Slots.QUICK_NAME)
	var kept: String = quick + Slots.ROLLBACK_SUFFIX
	DirAccess.copy_absolute(ProjectSettings.globalize_path(quick), ProjectSettings.globalize_path(kept))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(kept)
	assert_true(Slots.checkpoint_path(Slots.KIND_QUICK, Slots.QUICK_NAME).ends_with(
		"quicksave~2.rwlsave.rollback"), "a second checkpoint name while one is kept")
	assert_true(_session.load_slot(Slots.KIND_QUICK, Slots.QUICK_NAME).is_ok(), "the slot loads")
	assert_equal(FileAccess.get_file_as_bytes(kept), bytes, "the kept checkpoint is untouched")
	var file: String = "quicksave.rwlsave.rollback"
	assert_true(_session.load_recovered(Slots.KIND_QUICK, file).is_ok(), "the recovered row loads")
	assert_true(FileAccess.file_exists(kept), "and is kept afterwards")
	assert_equal(_session.load_recovered(Slots.KIND_QUICK, "nothing.rwlsave.rollback").code,
		Slots.REFUSE_SLOT, "an unlisted file refuses")


func test_a_damaged_header_is_shown_as_unloadable_without_reading_the_whole_file() -> void:
	"""The row's validity is the header/table/identity peek; a flipped magic byte fails it."""
	assert_true(_session.save_slot(Slots.KIND_MANUAL, "camp").is_ok(), "saved")
	var path: String = Slots.slot_path(Slots.KIND_MANUAL, "camp")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	bytes[0] ^= 0xFF
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var rows: Array[UiSaveRows.Row] = UiSaveRows.rows_for_tab(UiSaveRows.TAB_MANUAL)
	assert_false(rows[0].valid, "the row is not loadable")
	assert_true(rows[0].validity_text.begins_with(UiSaveRows.DAMAGED_TEXT), rows[0].validity_text)
	assert_true(Slots.row_validity(Slots.KIND_QUICK, "missing.rwlsave").code == SaveFile.REFUSE_IO,
		"a missing file is an I/O refusal")


# --- the browser -------------------------------------------------------------------------------------

func test_f9_opens_the_browser_on_the_quicksave_and_its_load_names_the_save_and_date() -> void:
	"""§5 load_quick: the confirmation is Load itself, naming the save and its in-game date."""
	assert_true(_session.save_slot(Slots.KIND_QUICK, Slots.QUICK_NAME).is_ok(), "saved")
	var browser: UiSaveBrowser = _browser()
	browser.open(UiSaveRows.TAB_AUTOSAVE, Slots.KIND_QUICK, Slots.QUICK_NAME)
	var confirm: Button = browser.find_child("UI-SET-066_load", true, false) as Button
	var row: UiSaveRows.Row = browser.selected_row()
	assert_not_null(row, "the quicksave is selected")
	assert_equal(confirm.text, "Load Quicksave, %s" % row.when_text, "Load names it and its date")
	assert_false(confirm.disabled, "and can be pressed")
	assert_true(_loaded.is_empty(), "nothing loaded before the press")
	confirm.pressed.emit()
	assert_equal(_loaded, [SaveHeader.REFUSE_NONE] as Array[StringName], "one load, accepted")
	browser.free()


func test_with_no_quicksave_load_is_unavailable_and_says_so() -> void:
	"""F9 with nothing to load: Load disabled with its reason, the status names the gap."""
	var browser: UiSaveBrowser = _browser()
	browser.open(UiSaveRows.TAB_AUTOSAVE, Slots.KIND_QUICK, Slots.QUICK_NAME)
	var confirm: Button = browser.find_child("UI-SET-066_load", true, false) as Button
	assert_true(confirm.disabled, "nothing to load")
	assert_true(confirm.tooltip_text.begins_with("Unavailable"), confirm.tooltip_text)
	assert_equal(browser.status_text(), UiSaveSession.reason_for(UiSaveSession.REFUSE_NO_QUICKSAVE,
		true), "the status names the missing quicksave")
	browser.free()


func test_the_header_carries_the_development_note_on_every_tab() -> void:
	"""DEC-055 Q8/Q9: the statement sits under the title, outside the tab's rows."""
	var browser: UiSaveBrowser = _browser()
	var note: Label = browser.find_child("DevelopmentNote", true, false) as Label
	assert_equal(note.text, UiSaveBrowser.DEVELOPMENT_NOTE, "the note")
	assert_true(browser.header().is_ancestor_of(note), "in the header")
	for tab: int in UiSaveRows.TAB_COUNT:
		browser.open_tab(tab)
		assert_true(note.visible, "visible on the %s tab" % UiSaveRows.TAB_NAMES[tab])
	browser.free()


func test_overwrite_needs_its_own_confirmation_and_save_writes_a_new_auto_named_save() -> void:
	"""§4 077: overwrite confirmation explicit. Save adds save_NNN at once and selects it."""
	var browser: UiSaveBrowser = _browser()
	browser.open(UiSaveRows.TAB_MANUAL)
	(browser.find_child("UI-SET-066_save_new", true, false) as Button).pressed.emit()
	assert_equal(browser.selected_row().name, "save_001", "the new save is selected")
	var path: String = Slots.slot_path(Slots.KIND_MANUAL, "save_001")
	var stamp: int = FileAccess.get_modified_time(path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	(browser.find_child("UI-SET-076_overwrite", true, false) as Button).pressed.emit()
	var confirm: Button = browser.find_child("UI-SET-066_load", true, false) as Button
	assert_equal(confirm.text, "Overwrite save_001", "the second step names the save replaced")
	(browser.find_child("UI-SET-067_cancel", true, false) as Button).pressed.emit()
	assert_equal(FileAccess.get_file_as_bytes(path), bytes, "keeping it wrote nothing")
	assert_equal(FileAccess.get_modified_time(path), stamp, "not even a rewrite")
	(browser.find_child("UI-SET-076_overwrite", true, false) as Button).pressed.emit()
	confirm.pressed.emit()
	assert_true(browser.status_text().begins_with("Saved over"), browser.status_text())
	browser.free()


# --- the game menu -----------------------------------------------------------------------------------

func test_the_game_menu_shows_settings_and_main_menu_unavailable_with_reasons() -> void:
	"""Brendan's choice: shown, disabled, and each says why -- to the eye and to a screen reader."""
	var menu: UiGameMenu = UiGameMenu.new()
	menu.setup(_session)
	for key: String in ["UI-SET-078_settings", "UI-SET-092_main_menu"]:
		var button: Button = menu.action_button(key)
		assert_true(button.disabled, "%s is disabled" % key)
		assert_true(button.accessibility_description.begins_with("Unavailable"), "%s says why" % key)
	for key: String in ["UI-SET-067_resume", "UI-SET-066_save", "UI-SET-066_load", "UI-SET-092_quit"]:
		assert_false(menu.action_button(key).disabled, "%s works" % key)
	menu.free()


func test_quit_warns_about_unsaved_progress_and_not_when_everything_is_saved() -> void:
	"""UI-SET-092: dirty save warning when leaving the world; a saved world quits at once."""
	var menu: UiGameMenu = UiGameMenu.new()
	menu.setup(_session)
	var quits: Array[int] = [0]
	menu.quit_confirmed.connect(func() -> void: quits[0] += 1)
	menu.action_button("UI-SET-092_quit").pressed.emit()
	assert_true(menu.is_confirming_quit(), "unsaved progress: the warning step")
	assert_equal(quits[0], 0, "and no quit yet")
	menu.action_button("UI-SET-066_quit").pressed.emit()
	assert_equal(quits[0], 1, "the warning's Quit quits")
	assert_true(_session.save_new_manual().is_ok(), "now saved")
	assert_false(_session.has_unsaved_progress(), "nothing unsaved")
	menu.open()
	menu.action_button("UI-SET-092_quit").pressed.emit()
	assert_equal(quits[0], 2, "a saved world quits without the warning")
	menu.free()


# --- the host: SaveControls -------------------------------------------------------------------------

const UiSaveControls := preload("res://scripts/ui/ui_save_controls.gd")


func _controls() -> UiSaveControls:
	"""Save controls bound to the settlement (no HUD), with their modals built."""
	var controls: UiSaveControls = UiSaveControls.new()
	controls.bind(_settlement, _manager, null)
	controls.session().set_enabled(true)
	return controls


func test_the_menu_holds_menu_pause_and_the_browser_returns_to_it() -> void:
	"""§3: the menu adds MENU; Save opens the browser over it; closing the browser returns to the
	menu; Resume closes both and releases MENU only."""
	var controls: UiSaveControls = _controls()
	assert_true(controls.open_game_menu(), "the menu opens")
	assert_true(controls.modal_open(), "a modal is open")
	assert_true(_manager.get_pause_reason_names().has("MENU"), "MENU is held")
	controls.game_menu().action_button("UI-SET-066_save").pressed.emit()
	assert_true(controls.browser().visible, "Save opens the browser")
	assert_equal(controls.browser().current_tab(), UiSaveRows.TAB_MANUAL, "on the Manual tab")
	assert_false(controls.game_menu().visible, "over the menu")
	controls.browser().close_button().pressed.emit()
	assert_true(controls.game_menu().visible, "closing the browser returns to the menu")
	controls.game_menu().action_button("UI-SET-067_resume").pressed.emit()
	assert_false(controls.modal_open(), "Resume closes everything")
	assert_false(_manager.get_pause_reason_names().has("MENU"), "and releases MENU")
	controls.free()


func test_f9_opens_the_browser_alone_and_a_successful_load_closes_it() -> void:
	"""load_quick opens the browser on the quicksave; its Load loads and every modal closes."""
	var controls: UiSaveControls = _controls()
	assert_true(controls.session().save_slot(Slots.KIND_QUICK, Slots.QUICK_NAME).is_ok(), "saved")
	assert_true(controls.open_quickload(), "F9 opens the browser")
	assert_false(controls.game_menu().visible, "without the menu")
	assert_equal(controls.browser().selected_row().title, "Quicksave", "on the quicksave")
	(controls.browser().find_child("UI-SET-066_load", true, false) as Button).pressed.emit()
	assert_false(controls.modal_open(), "a successful load closes the browser")
	assert_false(_manager.get_pause_reason_names().has("MENU"), "and MENU is released")
	controls.free()


func test_quit_game_calls_the_hosts_quit_once_confirmed() -> void:
	"""UI-SET-092 Quit game reaches the quit handler (the tree's quit in the game)."""
	var controls: UiSaveControls = _controls()
	var quits: Array[int] = [0]
	controls.quit_handler = func() -> void: quits[0] += 1
	controls.open_game_menu()
	controls.game_menu().action_button("UI-SET-092_quit").pressed.emit()
	controls.game_menu().action_button("UI-SET-066_quit").pressed.emit()
	assert_equal(quits[0], 1, "quit once")
	assert_false(controls.modal_open(), "and the modals closed first")
	controls.quit_handler = Callable()
	controls.free()
