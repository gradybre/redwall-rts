extends "res://test/framework/test_case.gd"
## The live demo's game menu (decision 0261; review F29), off-tree: its MENU pause and the speed it restores
## (through the real GameManager script), its pages and Esc's way back through them, Restart and Quit
## asking first with the no-save line, Settings offering only what works, the demo's interface scale, and
## the HUD's Menu button opening the host's menu instead of the New Settlement form. The real scene's
## clicks and keys are test_demo_input_live.gd's.

const MenuScript := preload("res://demo/ui/demo_menu.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiShellScript := preload("res://scripts/ui/ui_shell.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const FarmUi := preload("res://demo/farm/farm_ui.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const NewsScript := preload("res://demo/ui/demo_news_strip.gd")
const PartyScript := preload("res://demo/control/demo_party_panel.gd")
const SoundSettingsScript := preload("res://demo/sound/sound_settings_ui.gd")

var _nodes: Array[Node] = []
var _game: GameManagerScript = null


func before_each() -> void:
	"""A started clock, as the demo has once it runs."""
	_game = GameManagerScript.new()
	_game.start_game()


func after_each() -> void:
	"""Free what a test built, and put the demo's interface scale back."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	if _game != null:
		_game.free()
	_game = null
	DemoUiScale.percent = UiLayout.USER_SCALE_100


func _menu() -> MenuScript:
	"""A menu on the test's clock."""
	var menu := MenuScript.new()
	_nodes.append(menu)
	menu.bind(_game)
	return menu


func _reasons() -> Array[String]:
	"""The clock's held pause reasons."""
	return _game.get_pause_reason_names()


# --- the MENU pause -----------------------------------------------------------------------------

func test_opening_holds_menu_and_closing_restores_the_speed() -> void:
	"""At 2x: open -> MENU held, the village stops; close -> MENU gone, 2x again."""
	var menu := _menu()
	assert_true(_game.set_speed(2), "2x")
	menu.open()
	assert_true(menu.visible, "open")
	assert_true(_reasons().has("MENU"), "MENU held")
	assert_equal(_game.get_effective_speed(), 0, "stopped")
	assert_true(menu.is_holding_pause(), "the menu knows it holds it")
	menu.close()
	assert_false(_reasons().has("MENU"), "MENU released")
	assert_equal(_game.get_effective_speed(), 2, "back at 2x")


func test_a_player_pause_held_before_the_menu_is_still_held_after() -> void:
	"""Closing the menu removes MENU only (UI §3)."""
	var menu := _menu()
	assert_true(_game.pause_game(), "the player paused")
	menu.open()
	menu.close()
	assert_equal(_reasons(), ["PLAYER"] as Array[String], "PLAYER alone remains")
	assert_true(_game.is_paused(), "still paused")


func test_set_menu_pause_is_refused_before_start_and_holds_once() -> void:
	"""Before start_game the clock refuses; a second hold changes nothing; release is exact."""
	var fresh := GameManagerScript.new()
	assert_false(fresh.set_menu_pause(true), "refused before start")
	assert_equal(fresh.last_refusal(), GameManagerScript.REFUSE_NOT_STARTED, "not started")
	fresh.free()
	assert_true(_game.set_menu_pause(true), "held")
	assert_true(_game.set_menu_pause(true), "held again")
	assert_true(_game.set_menu_pause(false), "released")
	assert_false(_game.is_paused(), "nothing held")


func test_a_refused_release_keeps_the_menu_open_and_runs_nothing() -> void:
	"""While a load holds the clock's barrier the release is refused: the menu stays open (no pause is left
	with nothing to explain it), and Restart and the Lab do not run; Quit still does."""
	var menu := _menu()
	var ran: Array[String] = []
	menu.on_restart = func() -> void: ran.append("restart")
	menu.on_lab = func() -> void: ran.append("lab")
	menu.open()
	_game.set("_loading", true)
	assert_false(menu.close(), "refused")
	assert_true(menu.visible, "still open")
	menu.on_quit = func() -> void: ran.append("quit")
	menu.confirm(MenuScript.CONFIRM_RESTART)
	menu.confirm_button().pressed.emit()
	menu.open_lab()
	assert_equal(ran.size(), 0, "nothing ran")
	menu.confirm(MenuScript.CONFIRM_QUIT)
	menu.confirm_button().pressed.emit()
	assert_equal(ran, ["quit"] as Array[String], "but Quit still quits: it needs no pause released")
	ran.clear()
	_game.set("_loading", false)
	assert_true(menu.close(), "released once the barrier lifts")
	assert_false(_game.is_paused(), "running")


func test_opening_twice_and_closing_twice_hold_and_release_once() -> void:
	"""open/open/close/close: one hold, one release, never an unmatched release."""
	var menu := _menu()
	menu.open()
	menu.open()
	menu.close()
	assert_false(_game.is_paused(), "released")
	menu.close()
	assert_false(menu.is_holding_pause(), "still released")
	menu.toggle()
	assert_true(menu.visible and _game.is_paused(), "toggle opens")
	menu.toggle()
	assert_false(menu.visible or _game.is_paused(), "and closes")


# --- pages ----------------------------------------------------------------------------------------

func test_the_menu_page_offers_the_six_actions_and_the_no_save_line() -> void:
	"""Resume, Restart…, Controls, Settings, Demo Lab, Quit…, and the line that the demo cannot save."""
	var menu := _menu()
	for k: int in MenuScript.MENU_BUTTONS.size():
		assert_equal(menu.menu_button(k).text, MenuScript.MENU_BUTTONS[k], "button %d" % k)
		assert_equal(menu.menu_button(k).focus_mode, Control.FOCUS_ALL, "focusable")
	assert_true(menu.page_text(MenuScript.PAGE_MENU).contains(MenuScript.NO_SAVE_LINE), "the no-save line")
	assert_false(menu.page_text(MenuScript.PAGE_MENU).contains("New settlement"), "no New Settlement")


func test_escape_goes_back_a_page_then_closes() -> void:
	"""Controls -> Esc -> the menu (still open) -> Esc -> closed."""
	var menu := _menu()
	menu.open()
	menu.menu_button(2).pressed.emit()
	assert_equal(menu.page(), MenuScript.PAGE_CONTROLS, "Controls")
	menu.back_or_close()
	assert_equal(menu.page(), MenuScript.PAGE_MENU, "back to the menu")
	assert_true(menu.visible, "still open")
	menu.back_or_close()
	assert_false(menu.visible, "closed")


func test_controls_list_the_demo_s_keys() -> void:
	"""The Controls page names the focus switch, the Lab and the tools, one key per row."""
	var menu := _menu()
	var text: String = menu.page_text(MenuScript.PAGE_CONTROLS)
	for key: String in ["F7", "F8", "Tab / Shift+Tab", "B", "T", "G", "F6", "K", "Esc", "Space"]:
		assert_true(text.contains(key), "lists %s" % key)
	assert_true(text.contains("Back"), "and Back")


func test_resume_closes() -> void:
	"""Resume is close."""
	var menu := _menu()
	menu.open()
	menu.menu_button(0).pressed.emit()
	assert_false(menu.visible, "closed")
	assert_false(_game.is_paused(), "running")


# --- restart and quit ask first ---------------------------------------------------------------------

func test_restart_and_quit_ask_first_and_say_the_village_is_lost() -> void:
	"""Restart… and Quit… show the question with the lost-village line; Cancel goes back; nothing ran."""
	var menu := _menu()
	var ran: Array[String] = []
	menu.on_restart = func() -> void: ran.append("restart")
	menu.on_quit = func() -> void: ran.append("quit")
	menu.open()
	for k: int in [1, 5]:
		menu.menu_button(k).pressed.emit()
		assert_equal(menu.page(), MenuScript.PAGE_CONFIRM, "asks first")
		assert_true(menu.page_text(MenuScript.PAGE_CONFIRM).contains("can't save"), "says it cannot save")
		menu.cancel_button().pressed.emit()
		assert_equal(menu.page(), MenuScript.PAGE_MENU, "Cancel goes back")
	assert_equal(ran.size(), 0, "nothing ran")


func test_a_confirmed_restart_or_quit_releases_the_pause_and_runs() -> void:
	"""The verb closes the menu (MENU released) and hands the host its action."""
	var menu := _menu()
	var ran: Array[String] = []
	menu.on_restart = func() -> void: ran.append("restart:%s" % _game.is_paused())
	menu.on_quit = func() -> void: ran.append("quit")
	menu.open()
	menu.confirm(MenuScript.CONFIRM_RESTART)
	assert_equal(menu.confirm_button().text, "Restart demo", "the verb")
	menu.confirm_button().pressed.emit()
	assert_equal(ran, ["restart:false"] as Array[String], "restarted with no MENU pause left")
	assert_false(menu.visible, "the menu closed")
	menu.open()
	menu.confirm(MenuScript.CONFIRM_QUIT)
	assert_equal(menu.confirm_button().text, "Quit demo", "the verb")
	menu.confirm_button().pressed.emit()
	assert_equal(ran[1], "quit", "quit")


func test_the_demo_lab_entry_closes_the_menu_and_opens_the_lab() -> void:
	"""Demo Lab: MENU released, the host's Lab opened."""
	var menu := _menu()
	var opened: Array[int] = [0]
	menu.on_lab = func() -> void: opened[0] += 1
	menu.open()
	menu.menu_button(4).pressed.emit()
	assert_false(menu.visible, "the menu closed")
	assert_false(_reasons().has("MENU"), "its pause with it")
	assert_equal(opened[0], 1, "the Lab opened")


# --- settings -------------------------------------------------------------------------------------

func test_settings_offer_only_the_scales_that_fit_and_the_sound() -> void:
	"""A size the window cannot fit is disabled with the reason; the chosen one is lit; the sound section is there
	(decision 0351; its own checks are test_demo_sound.gd's)."""
	var menu := _menu()
	menu.scale_fits = func(percent: int) -> bool: return percent <= UiLayout.USER_SCALE_125
	menu.open()
	menu.menu_button(3).pressed.emit()
	assert_equal(menu.page(), MenuScript.PAGE_SETTINGS, "Settings")
	assert_true(menu.scale_button(0).button_pressed, "100% lit")
	assert_false(menu.scale_button(1).disabled, "125% offered")
	assert_true(menu.scale_button(2).disabled, "150% refused")
	assert_equal(menu.scale_button(2).tooltip_text, MenuScript.SCALE_TOO_SMALL % 150, "with the reason")
	assert_true(menu.page_text(MenuScript.PAGE_SETTINGS).contains(SoundSettingsScript.TITLE), "the sound section")
	assert_true(menu.page_text(MenuScript.PAGE_SETTINGS).contains("150% needs a larger window"), "the note says why")
	assert_equal(MenuScript.refused_note(PackedStringArray(["125%", "150%"])), "125% and 150% need a larger window",
		"two refused read as one sentence")
	assert_equal(MenuScript.refused_note(PackedStringArray()), "", "none refused: no note")


func test_choosing_a_scale_applies_it_only_where_it_fits() -> void:
	"""125% goes to the host and lights; a refused 150% does not reach it."""
	var menu := _menu()
	var applied: Array[int] = []
	menu.scale_fits = func(percent: int) -> bool: return percent <= UiLayout.USER_SCALE_125
	menu.on_scale = func(percent: int) -> void: applied.append(percent)
	menu.choose_scale(UiLayout.USER_SCALE_125)
	menu.choose_scale(UiLayout.USER_SCALE_150)
	assert_equal(applied, [125] as Array[int], "only 125")
	assert_equal(menu.scale_percent, 125, "125 chosen")
	assert_true(menu.scale_button(1).button_pressed, "and lit")


func test_full_screen_says_its_state_and_toggles_through_the_host() -> void:
	"""The button reads off/on from the host and calls its toggle."""
	var menu := _menu()
	var full: Array[bool] = [false]
	menu.is_fullscreen = func() -> bool: return full[0]
	menu.on_fullscreen = func() -> void: full[0] = not full[0]
	menu.menu_button(3).pressed.emit()
	assert_equal(menu.fullscreen_button().text, MenuScript.FULLSCREEN_TEXT % "off", "off")
	menu.fullscreen_button().pressed.emit()
	assert_equal(menu.fullscreen_button().text, MenuScript.FULLSCREEN_TEXT % "on", "on")


func test_the_demo_s_interface_scale_fits_and_applies() -> void:
	"""1280x720 fits only 100% at the demo's 720 logical rows; 1920x1080 fits all three; a percent §1.2 does
	not define is refused; the panels' shared geometry follows the chosen percent."""
	assert_true(DemoUiScale.fits(1280, 720, 100, 720.0), "720p at 100%")
	assert_false(DemoUiScale.fits(1280, 720, 125, 720.0), "not 125%")
	assert_true(DemoUiScale.fits(1920, 1080, 150, 720.0), "1080p at 150%")
	assert_false(DemoUiScale.apply(110, null), "110% refused")
	assert_equal(DemoUiScale.percent, 100, "unchanged")
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	FarmUi.geometry_for(Vector2(1920.0, 1080.0), layout, geometry)
	var at_100: float = geometry.scale
	assert_true(DemoUiScale.apply(150, null), "150% applied")
	FarmUi.geometry_for(Vector2(1920.0, 1080.0), layout, geometry)
	assert_almost_equal(geometry.scale, at_100 * 1.5, "the demo's panels lay out at 150%")


func test_every_demo_layout_site_follows_the_scale() -> void:
	"""The right column's strip, the news band and the party panel lay out at the chosen percent; applying
	it raises the viewport's size_changed, which every demo panel re-places on."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	var at_100: PackedFloat32Array = _site_scales(layout, geometry)
	var viewport := SubViewport.new()
	_nodes.append(viewport)
	var raised: Array[int] = [0]
	viewport.size_changed.connect(func() -> void: raised[0] += 1)
	assert_true(DemoUiScale.apply(150, viewport), "150%")
	assert_equal(raised[0], 1, "size_changed raised once")
	var at_150: PackedFloat32Array = _site_scales(layout, geometry)
	for k: int in at_100.size():
		assert_almost_equal(at_150[k], at_100[k] * 1.5, "site %d at 150%%" % k)


func _site_scales(layout: UiLayout, geometry: UiLayout.Geometry) -> PackedFloat32Array:
	"""The HUD scale each static demo layout site computes at 1920x1080."""
	var out := PackedFloat32Array()
	ZoneScript.strip_placement(1920, 1080, layout, geometry)
	out.append(geometry.scale)
	NewsScript.band_placement(1920, 1080, layout, geometry)
	out.append(geometry.scale)
	PartyScript.placement(1920, 1080, layout, geometry)
	out.append(geometry.scale)
	return out


# --- the HUD's Menu button --------------------------------------------------------------------------

func test_the_hud_menu_button_opens_the_host_menu_not_new_settlement() -> void:
	"""With a handler the Menu button calls it and opens no workspace; without one it keeps the form."""
	var shell := UiShellScript.new()
	_nodes.append(shell)
	shell.build()
	assert_true(shell.layout_for(1280, 720), "laid out")
	var opened: Array[int] = [0]
	shell.set_menu_handler(func() -> void: opened[0] += 1)
	(shell.control_for(UiShellScript.ID_MENU) as Button).pressed.emit()
	assert_equal(opened[0], 1, "the host's menu")
	assert_false(shell.control_for(UiShellScript.ID_WORKSPACE).visible, "no workspace: not the New Settlement form")
	shell.set_menu_handler(Callable())
	(shell.control_for(UiShellScript.ID_MENU) as Button).pressed.emit()
	assert_true(shell.control_for(UiShellScript.ID_WORKSPACE).visible, "no handler: the workspace opens")
	assert_equal(shell.workspace_page(), UiShellScript.ID_NEW_SETTLEMENT, "on the form, as before")
	assert_equal(opened[0], 1, "the host was not called")
