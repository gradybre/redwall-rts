extends "res://test/framework/test_case.gd"
## The demo's Resume from the clock's REQ-SET-008 diagnostic (CRITICAL) pause. Decision 0196. It drives
## a private GameManager into the real diagnostic pause -- the clock's own overload ladder at 1x, as a
## stalled frame does -- and checks the banner shows, never resumes by itself, and resumes on request.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const BannerScript := preload("res://demo/ui/demo_stall_banner.gd")

const FRAME_USEC: int = 33334
## One real second in a single frame: four times the quarter second of debt the 1x ladder allows.
const STALL_USEC: int = 1000000

var _game: GameManagerScript = null
var _banner: BannerScript = null


func before_each() -> void:
	"""A started private clock at 1x, and a banner watching it (out of the tree)."""
	_game = GameManagerScript.new()
	_game.start_game()
	_banner = BannerScript.new()
	_banner.bind(_game)


func after_each() -> void:
	"""Free both."""
	_banner.free()
	_game.free()


func _stall() -> void:
	"""A stalled frame, then the next: the ladder's rung lands and CRITICAL holds."""
	_game.advance_host_time(STALL_USEC)
	_game.advance_host_time(FRAME_USEC)


func test_hidden_while_the_clock_runs() -> void:
	"""No stall, no banner."""
	_game.advance_host_time(FRAME_USEC)
	assert_false(_banner.refresh(), "not held")
	assert_false(_banner.is_shown(), "not drawn")


func test_a_stall_shows_it_and_it_never_resumes_by_itself() -> void:
	"""The diagnostic pause holds however long the banner watches; only the player clears it."""
	_stall()
	assert_equal(_game.get_pause_reason_names(), ["CRITICAL"] as Array[String], "the clock holds CRITICAL")
	assert_true(_banner.refresh(), "held")
	assert_true(_banner.is_shown(), "drawn")
	for frame: int in 30:
		_game.advance_host_time(FRAME_USEC)
		_banner.refresh()
	assert_true(_game.is_paused(), "still paused after a second of watching")
	assert_equal(_banner.resumes, 0, "no resume happened")


func test_resume_acknowledges_and_the_clock_runs_again() -> void:
	"""Resume is acknowledge_overload(): CRITICAL goes, the owed ticks are dropped and counted."""
	_stall()
	_banner.refresh()
	var resets: int = _game.clock().acknowledged_catchup_resets()
	var dropped: int = _banner.resume()
	assert_true(dropped > 0, "owed ticks dropped explicitly")
	assert_equal(_game.clock().acknowledged_catchup_resets(), resets + 1, "and the clock counted it")
	assert_false(_game.is_paused(), "running again")
	assert_false(_banner.is_shown(), "the banner is gone")
	var before: int = _game.get_completed_tick()
	_game.advance_host_time(FRAME_USEC)
	assert_true(_game.get_completed_tick() > before, "ticks advance")


func test_resume_leaves_a_players_own_pause() -> void:
	"""Only CRITICAL is the banner's to clear."""
	_game.pause_game()
	_game.advance_host_time(FRAME_USEC)
	_game.clock().apply_overload()
	_game.advance_host_time(FRAME_USEC)
	assert_true(_banner.refresh(), "held beside PLAYER")
	_banner.resume()
	assert_equal(_game.get_pause_reason_names(), ["PLAYER"] as Array[String], "PLAYER stays")


func test_resume_without_a_stall_does_nothing() -> void:
	"""Pressing it when nothing is held changes nothing and counts nothing."""
	var resets: int = _game.clock().acknowledged_catchup_resets()
	assert_equal(_banner.resume(), 0, "nothing dropped")
	assert_equal(_game.clock().acknowledged_catchup_resets(), resets, "no acknowledgement recorded")
	assert_equal(_banner.resumes, 0, "no resume")


# --- playtest 2026-09-29: the banner is THE overload surface, and Resume ends the condition ---------

const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiNotices := preload("res://scripts/ui/ui_notices.gd")
const UiManagerScript := preload("res://scripts/systems/ui_manager.gd")


func _hud_shell() -> UiShell:
	"""A real HUD shell raising the clock's diagnostic as UIManager does (`_on_clock_diagnostic`:
	its category, source, code and recovery), bound to the banner."""
	var shell := UiShell.new()
	shell.build()
	shell.layout_for(1920, 1080)
	_game.clock_diagnostic.connect(func(message: String) -> void:
		shell.raise_notice(UiNotices.CATEGORY_CLOCK_OVERLOAD, message, UiManagerScript.CLOCK_SOURCE,
			UiManagerScript.CLOCK_OVERLOAD_CODE, UiManagerScript.CLOCK_RECOVERY))
	_banner.bind_shell(shell)
	return shell


func _overload_row(shell: UiShell) -> UiNotices.Notice:
	"""The shell's overload row, expanded."""
	var row := UiNotices.Notice.new()
	for index: int in shell.notices().count():
		shell.notices().notice_into(index, 0, row)
		if row.code == BannerScript.OVERLOAD_CODE:
			return row
	row.reset()
	return row


func test_the_banner_carries_the_clocks_sentence_and_withholds_the_card() -> void:
	"""One condition, one surface: the notice is recorded and active, but no card draws it while the
	banner -- printing the clock's own sentence -- is up."""
	var shell := _hud_shell()
	_stall()
	_banner.refresh()
	assert_true(_banner.is_shown(), "the banner is up")
	assert_equal(shell.notices().active_count(), 1, "the overload is recorded and active")
	assert_equal(shell.wanted_alert_cards(), 0, "but takes no card")
	assert_false(shell.alert_card_at(0).visible, "none drawn")
	assert_equal(_banner.diagnostic_text(), _game.clock().last_diagnostic(), "the banner prints the clock's sentence")
	assert_true(_banner.diagnostic_text().begins_with("Simulation overloaded at 1x"), "the 1x pause's")
	shell.free()


func test_resume_resolves_the_overload_and_a_second_stall_raises_it_again() -> void:
	"""Resume ends the condition: the notice is resolved, no card comes back, the history keeps the row.
	A later stall regroups onto that row, active again, and Resume resolves it again."""
	var shell := _hud_shell()
	_stall()
	_banner.refresh()
	_banner.resume()
	assert_false(_banner.is_shown(), "the banner is gone")
	assert_equal(shell.notices().active_count(), 0, "resolved")
	assert_equal(shell.wanted_alert_cards(), 0, "no card is left behind")
	assert_equal(shell.notices().count(), 1, "the history keeps the row")
	for frame: int in 5:
		_game.advance_host_time(FRAME_USEC)
	_stall()
	assert_true(_banner.refresh(), "a second stall: the banner again")
	assert_equal(shell.notices().count(), 1, "one row")
	assert_equal(_overload_row(shell).occurrences, 2, "seen twice")
	assert_false(_overload_row(shell).resolved, "active again")
	_banner.resume()
	assert_true(_overload_row(shell).resolved, "resolved again")
	shell.free()


func test_a_step_down_warning_without_the_banner_still_takes_its_card() -> void:
	"""Hidden, the banner withholds nothing: a 2x/4x step-down (no pause, no banner) is drawn as a card."""
	var shell := _hud_shell()
	_stall()
	_banner.refresh()
	_banner.resume()
	shell.raise_notice(UiNotices.CATEGORY_CLOCK_OVERLOAD, "Simulation overloaded: speed reduced to 2x; 3 whole tick(s) owed.",
		UiManagerScript.CLOCK_SOURCE, UiManagerScript.CLOCK_OVERLOAD_CODE, UiManagerScript.CLOCK_RECOVERY)
	assert_false(_banner.is_shown(), "no banner")
	assert_equal(shell.wanted_alert_cards(), 1, "the warning has its card")
	shell.free()


func test_the_card_is_withheld_in_the_call_that_raised_it() -> void:
	"""The stalled frame reports the pause (and UIManager raises the card) a frame before the rung
	lands; the banner withholds the card on the clock's report, so it is never drawn in between."""
	var shell := _hud_shell()
	_game.advance_host_time(STALL_USEC)
	assert_false(_game.is_paused(), "the rung has not landed yet")
	assert_equal(shell.notices().active_count(), 1, "but the notice is raised")
	assert_equal(shell.wanted_alert_cards(), 0, "and its card is already withheld")
	assert_false(_banner.refresh(), "a refresh before the rung lands keeps it withheld")
	assert_equal(shell.wanted_alert_cards(), 0, "still withheld")
	_game.advance_host_time(FRAME_USEC)
	assert_true(_banner.refresh(), "the rung lands: the banner shows")
	assert_equal(shell.wanted_alert_cards(), 0, "and the card never drew")
	shell.free()


func test_a_reported_pause_that_never_lands_hands_the_card_back() -> void:
	"""A pause the clock reported but that never took hold (refused) does not hide its card for good."""
	var shell := _hud_shell()
	_game.clock().clock_diagnostic_pause.emit("Simulation overloaded at 1x: 9 whole tick(s) owed; paused rather than skipping.")
	assert_equal(shell.wanted_alert_cards(), 0, "withheld while it may still land")
	_banner._process(1.2)
	_banner.refresh()
	assert_equal(shell.wanted_alert_cards(), 0, "the stalled frame's own long delta does not spend the grace")
	_banner._process(BannerScript.PENDING_MAX_S * 0.5)
	_banner.refresh()
	assert_equal(shell.wanted_alert_cards(), 0, "still inside the grace")
	_banner._process(BannerScript.PENDING_MAX_S)
	_banner.refresh()
	assert_false(_banner.is_shown(), "no banner")
	assert_equal(shell.wanted_alert_cards(), 1, "the card is handed back")
	shell.free()


func test_the_banner_draws_above_the_pantry_and_the_hud() -> void:
	"""The way out of the pause is never under a pop-up: above the HUD's layer 1 and the pantry's."""
	var Pantry: GDScript = load("res://demo/farm/farm_pantry_panel.gd")
	assert_true(BannerScript.LAYER > Pantry.LAYER, "above the pantry")
	assert_true(Pantry.LAYER > 1, "which is above the HUD")


func test_the_condition_ends_however_the_pause_is_acknowledged() -> void:
	"""CRITICAL cleared by another path than the button (the game's own acknowledge): the banner's next
	look sees it gone, resolves the notice, and hands back no card."""
	var shell := _hud_shell()
	_stall()
	assert_true(_banner.refresh(), "shown")
	_game.acknowledge_overload()
	assert_false(_banner.refresh(), "gone")
	assert_true(_overload_row(shell).resolved, "the condition is resolved")
	assert_equal(shell.wanted_alert_cards(), 0, "no card comes back")
	shell.free()


func test_a_step_down_warning_is_resolved_once_the_clock_runs_quiet() -> void:
	"""Decision 0205: a 2x/4x step-down raises no banner and has no Resume; once the clock has run
	CLEAR_TICKS without raising it again, the notice is resolved and its card goes. Not sooner, and never
	while a stall's pause is held."""
	var shell := _hud_shell()
	shell.raise_notice(UiNotices.CATEGORY_CLOCK_OVERLOAD, "Simulation overloaded: speed reduced to 2x; 3 whole tick(s) owed.",
		UiManagerScript.CLOCK_SOURCE, UiManagerScript.CLOCK_OVERLOAD_CODE, UiManagerScript.CLOCK_RECOVERY)
	var start: int = _game.get_completed_tick()
	while _game.get_completed_tick() - start < BannerScript.CLEAR_TICKS - 30:
		_game.advance_host_time(FRAME_USEC)
	assert_equal(_banner.expire_quiet_overload(), 0, "not yet")
	assert_equal(shell.wanted_alert_cards(), 1, "the card stays meanwhile")
	while _game.get_completed_tick() - start < BannerScript.CLEAR_TICKS + 5:
		_game.advance_host_time(FRAME_USEC)
	assert_equal(_banner.expire_quiet_overload(), 1, "resolved")
	assert_equal(shell.wanted_alert_cards(), 0, "the card is gone")
	_stall()
	_banner.refresh()
	for frame: int in 400:
		_game.advance_host_time(FRAME_USEC)
	assert_equal(_banner.expire_quiet_overload(), 0, "a held pause is Resume's, not the timer's")
	shell.free()
