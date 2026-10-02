extends "res://test/framework/test_case.gd"
## The demo's pause types and its one Resume (decision 0471, review UX-022), off-tree on the real GameManager script:
## each kind -- the player's, the menu's, a planning surface's, a critical incident's, a stall -- held and said in its
## own words; Resume clearing exactly the player's, the planning and the critical pause and never the menu's or a
## stall; panels never overriding the player's pause; the planning waiver; the settings; the game menu holding its
## pause through the ledger; and the time control's Space, HUD-button and incident paths.

const LedgerScript := preload("res://demo/session/pause_ledger.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const TimeControlScript := preload("res://demo/session/time_control.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const CardScript := preload("res://demo/ui/demo_pause_card.gd")

var _game: GameManagerScript = null
var _ledger: LedgerScript = null
var _nodes: Array[Node] = []
var _reasons: PackedStringArray = PackedStringArray()


func before_each() -> void:
	"""A started clock at 2x, as the demo has once it runs, and a ledger on it."""
	_game = GameManagerScript.new()
	_game.start_game()
	_game.set_speed(2)
	_ledger = LedgerScript.new()
	_ledger.bind(_game)


func after_each() -> void:
	"""Free the clock and what a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_game.free()
	_game = null


func _clock_reasons() -> Array[String]:
	"""The clock's own held reasons."""
	return _game.get_pause_reason_names()


func _words() -> String:
	"""The ledger's reasons, joined."""
	_ledger.reasons_into(_reasons)
	return " | ".join(_reasons)


# --- each kind, and its words ------------------------------------------------------------------------------

func test_the_player_pause_is_player_and_says_so() -> void:
	"""Space's pause: PLAYER on the clock, KIND_PLAYER, 'You paused'."""
	assert_true(_ledger.pause_player(), "paused")
	assert_equal(_clock_reasons(), ["PLAYER"] as Array[String], "the clock holds PLAYER")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_PLAYER, "one kind")
	assert_equal(_words(), LedgerScript.PLAYER_WORDS, "its words")


func test_a_run_arrival_is_the_player_pause_with_its_note() -> void:
	"""A run that arrives pauses as the player, its note saying where."""
	_ledger.pause_player("Reached dawn: Y1 Spring 2, 06:00")
	assert_equal(_words(), "Reached dawn: Y1 Spring 2, 06:00", "the note is the reason")
	_ledger.resume()
	_ledger.pause_player()
	assert_equal(_words(), LedgerScript.PLAYER_WORDS, "a later pause of the player's own has no note")


func test_the_menu_pause_holds_menu_and_says_so() -> void:
	"""The game menu's hold: MENU on the clock, KIND_MENU, 'The game menu is open'."""
	assert_true(_ledger.hold_menu(true), "held")
	assert_equal(_clock_reasons(), ["MENU"] as Array[String], "the clock holds MENU")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_MENU, "the menu kind")
	assert_equal(_words(), LedgerScript.MENU_WORDS, "its words")


func test_the_village_guide_holds_a_menu_pause_of_its_own() -> void:
	"""The village guide's window (decision 0481) holds MENU through the ledger as its own hold (batch 5): its words and
	Resume refusal, and neither it nor the game menu releases the other's pause."""
	assert_true(_ledger.hold_guide(true), "held")
	assert_equal(_clock_reasons(), ["MENU"] as Array[String], "the clock holds MENU")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_MENU, "a menu kind")
	assert_equal(_words(), LedgerScript.GUIDE_WORDS, "its own words")
	assert_equal(_ledger.resume_refusal(), LedgerScript.RESUME_GUIDE, "close the guide to resume")
	assert_true(_ledger.hold_menu(true), "the game menu too")
	assert_equal(_words(), "%s | %s" % [LedgerScript.MENU_WORDS, LedgerScript.GUIDE_WORDS], "both said")
	assert_equal(_ledger.resume_refusal(), LedgerScript.RESUME_MENU, "the menu first")
	assert_true(_ledger.hold_guide(false), "the guide let go")
	assert_true(_game.is_paused(), "the menu's pause stands")
	assert_equal(_words(), LedgerScript.MENU_WORDS, "the menu alone")
	assert_true(_ledger.hold_guide(true) and _ledger.hold_menu(false), "the other way round")
	assert_true(_game.is_paused(), "the guide's pause stands")
	assert_true(_ledger.hold_guide(false), "released")
	assert_false(_game.is_paused(), "the village runs")


func test_a_planning_surface_pauses_only_with_the_setting_on() -> void:
	"""Pause while planning is off by default (UI §8.1): the Pantry open pauses nothing until it is on."""
	_ledger.set_planning(true, "the Pantry")
	assert_false(_game.is_paused(), "off: the Pantry does not pause")
	_ledger.auto_planning = true
	_ledger.set_planning(true, "the Pantry")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_PLANNING, "on: the planning kind")
	assert_equal(_clock_reasons(), ["MENU"] as Array[String], "held on the clock's MENU reason")
	assert_equal(_words(), "Planning: the Pantry is open", "its words name the surface")
	_ledger.set_planning(false, "")
	assert_false(_game.is_paused(), "closing the Pantry lets it go")


func test_a_critical_incident_pauses_and_says_which() -> void:
	"""Pause on a critical incident (on by default): KIND_CRITICAL with the incident's words; a second counts."""
	assert_true(_ledger.raise_critical("Mouse keeper is in difficulty"), "paused")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_CRITICAL, "the critical kind")
	assert_equal(_words(), "Critical: Mouse keeper is in difficulty", "its words")
	_ledger.raise_critical("A flood in tunnel 2")
	assert_equal(_words(), "Critical: A flood in tunnel 2 (and 1 more)", "the newest, and how many more")


func test_a_critical_incident_does_not_pause_with_the_setting_off() -> void:
	"""With Pause on a critical incident off nothing is held."""
	_ledger.auto_critical = false
	assert_false(_ledger.raise_critical("Mouse keeper is in difficulty"), "not paused")
	assert_false(_game.is_paused(), "the village runs")


func test_a_stall_is_its_own_kind() -> void:
	"""The clock's CRITICAL (the overload diagnostic) is KIND_STALL, said as a stall, never the incident kind."""
	_game.clock().set_pause(SimClock.CRITICAL, true)
	assert_equal(_ledger.kinds(), LedgerScript.KIND_STALL, "the stall kind")
	assert_true(_words().begins_with("Critical: the computer stalled"), _words())


func test_reasons_are_listed_most_urgent_first() -> void:
	"""Critical, then menu, then planning, then the player's."""
	_ledger.auto_planning = true
	_ledger.pause_player()
	_ledger.set_planning(true, "the Work screen")
	_ledger.hold_menu(true)
	_ledger.raise_critical("A fire in tunnel 1")
	assert_equal(_words(), "Critical: A fire in tunnel 1 | The game menu is open | Planning: the Work screen is open | You paused",
		"in order")


# --- Resume clears only the right pause ----------------------------------------------------------------------

func test_resume_clears_the_player_pause_and_the_speed_comes_back() -> void:
	"""PLAYER alone: Resume clears it and the village runs at the 2x it had."""
	_ledger.pause_player()
	assert_equal(_ledger.resume(), LedgerScript.KIND_PLAYER, "cleared the player's")
	assert_equal(_game.get_effective_speed(), 2, "back at 2x")


func test_resume_clears_planning_and_critical_but_not_the_menu() -> void:
	"""All four kinds held: Resume clears the player's, the planning and the critical pause; MENU stays held."""
	_ledger.auto_planning = true
	_ledger.pause_player()
	_ledger.set_planning(true, "the Pantry")
	_ledger.raise_critical("A fire")
	_ledger.hold_menu(true)
	var cleared: int = _ledger.resume()
	assert_equal(cleared, LedgerScript.RESUMABLE, "the three it may clear")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_MENU, "the menu's pause alone stands")
	assert_equal(_clock_reasons(), ["MENU"] as Array[String], "the clock still holds MENU")
	_ledger.hold_menu(false)
	assert_false(_game.is_paused(), "closing the menu then runs the village")


func test_resume_never_acknowledges_a_stall() -> void:
	"""A stall with a player pause: Resume clears PLAYER only; CRITICAL waits for the banner's own Resume."""
	_ledger.pause_player()
	_game.clock().set_pause(SimClock.CRITICAL, true)
	assert_equal(_ledger.resume(), LedgerScript.KIND_PLAYER, "only the player's")
	assert_equal(_clock_reasons(), ["CRITICAL"] as Array[String], "the stall stands")
	assert_equal(_ledger.resume_refusal(), LedgerScript.RESUME_STALL, "and Resume says where its Resume is")


func test_resume_with_only_the_menu_says_close_the_menu() -> void:
	"""Nothing Resume may clear: it clears nothing and says why."""
	_ledger.hold_menu(true)
	assert_false(_ledger.can_resume(), "nothing to clear")
	assert_equal(_ledger.resume(), 0, "cleared nothing")
	assert_equal(_ledger.resume_refusal(), LedgerScript.RESUME_MENU, "close the menu")
	_ledger.hold_menu(false)
	assert_equal(_ledger.resume_refusal(), LedgerScript.RESUME_NONE, "running: nothing to resume")


func test_a_resumed_planning_pause_stays_waived_until_every_surface_closes() -> void:
	"""Resume while planning: the village runs with the panel open; reopening it later pauses again."""
	_ledger.auto_planning = true
	_ledger.set_planning(true, "the Pantry")
	_ledger.resume()
	_ledger.set_planning(true, "the Pantry")
	assert_false(_game.is_paused(), "still open, still running (waived)")
	assert_true(_ledger.planning_waived(), "waived")
	_ledger.set_planning(false, "")
	_ledger.set_planning(true, "the Pantry")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_PLANNING, "reopened: paused again")


func test_a_panel_never_overrides_the_players_pause() -> void:
	"""The player paused, then a planning surface opened and closed: the player's pause stays."""
	_ledger.auto_planning = true
	_ledger.pause_player()
	_ledger.set_planning(true, "the Pantry")
	_ledger.set_planning(false, "")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_PLAYER, "PLAYER alone remains")
	assert_true(_game.is_paused(), "still paused")


func test_closing_the_menu_does_not_lift_a_planning_or_critical_pause() -> void:
	"""The menu holds MENU through the ledger: closing it leaves the planning and critical holds standing."""
	var menu := MenuScript.new()
	_nodes.append(menu)
	menu.bind(_game)
	menu.hold_pause = _ledger.hold_menu
	_ledger.raise_critical("A fire")
	menu.open()
	assert_true(menu.is_holding_pause(), "the menu holds its pause")
	assert_true(menu.close(), "closed")
	assert_equal(_ledger.kinds(), LedgerScript.KIND_CRITICAL, "the critical pause stands")
	assert_true(_game.is_paused(), "the village stays paused")


func test_toggle_pauses_when_running_and_resumes_when_paused() -> void:
	"""Space: running -> the player's pause; paused by planning -> Resume (not a second pause)."""
	_ledger.toggle()
	assert_equal(_ledger.kinds(), LedgerScript.KIND_PLAYER, "paused")
	_ledger.toggle()
	assert_false(_game.is_paused(), "resumed")
	_ledger.auto_planning = true
	_ledger.set_planning(true, "the Pantry")
	_ledger.toggle()
	assert_false(_game.is_paused(), "Space resumed a planning pause")


func test_release_all_leaves_no_menu_reason() -> void:
	"""The scene leaving lets every demo hold go."""
	_ledger.auto_planning = true
	_ledger.hold_menu(true)
	_ledger.raise_critical("A fire")
	_ledger.release_all()
	assert_false(_game.is_paused(), "nothing held")


func test_a_stale_menu_reason_is_let_go_on_bind() -> void:
	"""A new ledger on a clock holding MENU nobody holds (a restarted scene) lets it go."""
	_game.set_menu_pause(true)
	var fresh := LedgerScript.new()
	fresh.bind(_game)
	assert_false(_game.is_paused(), "released")


# --- the time control's paths ----------------------------------------------------------------------------------

func _control() -> TimeControlScript:
	"""A time control on this clock with a feed and incidents (off-tree)."""
	var control := TimeControlScript.new()
	_nodes.append(control)
	var notices := NoticesScript.new()
	var incidents := IncidentsScript.new()
	incidents.bind(notices, null, null)
	control.configure(_game, null, notices, incidents)
	control.set_meta(&"incidents", incidents)
	return control


func test_the_hud_pause_button_pressed_while_planning_paused_resumes() -> void:
	"""The HUD's button toggles PLAYER only; the time control makes it the whole Resume while paused."""
	var control := _control()
	control.ledger.auto_planning = true
	control.ledger.set_planning(true, "the Pantry")
	_game.toggle_pause()
	control.call(&"_on_shell_action", UiShell.ID_PAUSE)
	assert_false(_game.is_paused(), "resumed")


func test_the_hud_pause_button_pressed_while_running_pauses() -> void:
	"""Running: the button's PLAYER pause stands."""
	var control := _control()
	_game.toggle_pause()
	control.call(&"_on_shell_action", UiShell.ID_PAUSE)
	assert_equal(control.ledger.kinds(), LedgerScript.KIND_PLAYER, "the player's pause")


func test_a_critical_incident_raised_pauses_through_the_time_control() -> void:
	"""The incidents' critical cue holds the critical pause, in the incident's own words."""
	var control := _control()
	var incidents: IncidentsScript = control.get_meta(&"incidents")
	incidents.raise("water:rescue:1", NoticesScript.SOURCE_WATER, IncidentsScript.SEVERITY_CRITICAL,
		"Mouse keeper is in difficulty in the water")
	assert_equal(control.ledger.kinds(), LedgerScript.KIND_CRITICAL, "paused as critical")
	assert_true(_words_of(control.ledger).contains("Mouse keeper is in difficulty"), _words_of(control.ledger))


func test_a_warning_incident_does_not_pause() -> void:
	"""Only a critical incident pauses."""
	var control := _control()
	var incidents: IncidentsScript = control.get_meta(&"incidents")
	incidents.raise("farm:wet:1", NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, "Bed 1 is waterlogged")
	assert_false(_game.is_paused(), "a warning does not pause")


func _words_of(ledger: LedgerScript) -> String:
	"""Another ledger's reasons, joined."""
	ledger.reasons_into(_reasons)
	return " | ".join(_reasons)


func test_the_pause_card_says_what_resume_clears() -> void:
	"""The card's Resume tooltip names the kinds it clears; disabled with the menu alone, with why."""
	var card := CardScript.new()
	_nodes.append(card)
	_ledger.auto_planning = true
	card.configure(_ledger, _game.get_speed)
	_ledger.pause_player()
	_ledger.set_planning(true, "the Pantry")
	assert_true(card.refresh(), "shown")
	assert_true(card.text().contains("Planning: the Pantry is open"), card.text())
	assert_equal(card.resume_button().tooltip_text, "Clears your pause and the planning pause; the village runs on at 2x",
		"what Resume clears")
	_ledger.resume()
	_ledger.hold_menu(true)
	card.refresh()
	assert_true(card.resume_button().disabled, "the menu alone: Resume disabled")
	assert_equal(card.resume_button().tooltip_text, LedgerScript.RESUME_MENU, "saying why")
	_ledger.hold_menu(false)
	assert_false(card.refresh(), "running: hidden")


func test_the_pause_card_rises_above_an_open_pop_up() -> void:
	"""A pop-up open: the card on the pop-ups' layer; closed: back under them."""
	var card := CardScript.new()
	_nodes.append(card)
	card.configure(_ledger, _game.get_speed)
	var open: Array[bool] = [true]
	card.modal_open = func() -> bool: return open[0]
	_ledger.pause_player()
	card.refresh()
	assert_equal(card.layer, CardScript.MODAL_LAYER, "above the pop-up")
	open[0] = false
	card.refresh()
	assert_equal(card.layer, CardScript.LAYER, "back under")


func test_the_pause_card_hides_while_asked() -> void:
	"""A hide query true (the stall banner, the game menu): hidden though paused."""
	var card := CardScript.new()
	_nodes.append(card)
	card.configure(_ledger, _game.get_speed)
	card.hide_while = [func() -> bool: return true] as Array[Callable]
	_ledger.pause_player()
	assert_false(card.refresh(), "hidden")


func test_the_pause_card_places_again_when_its_minimum_changes() -> void:
	"""Decision 0931: the panel's minimum changed (its words re-measured) queues one placing, however often asked."""
	var card := CardScript.new()
	_nodes.append(card)
	assert_false(bool(card.get(&"_place_queued")), "nothing queued at first")
	card.frame().minimum_size_changed.emit()
	assert_true(bool(card.get(&"_place_queued")), "a placing queued")
	card.call(&"_place")
	assert_false(bool(card.get(&"_place_queued")), "placed (out of the tree: nothing to place against), unqueued")


func test_the_pause_card_moves_when_what_it_sits_against_moves() -> void:
	"""Decision 0931: the top card shown, gone or resized, or the HUD's cards shown or gone, since it was placed."""
	var card := CardScript.new()
	_nodes.append(card)
	var top: Array[Rect2] = [Rect2()]
	var cards: Array[bool] = [false]
	card.avoid = func() -> Rect2: return top[0]
	card.hud_cards_shown = func() -> bool: return cards[0]
	assert_false(bool(card.call(&"_moved")), "as placed")
	top[0] = Rect2(10.0, 130.0, 420.0, 217.0)
	assert_true(bool(card.call(&"_moved")), "a top card shown")
	card.set(&"_placed_clear", top[0])
	assert_false(bool(card.call(&"_moved")), "placed against it")
	top[0].size.y = 160.0
	assert_true(bool(card.call(&"_moved")), "the top card resized")
	card.set(&"_placed_clear", top[0])
	cards[0] = true
	assert_true(bool(card.call(&"_moved")), "the HUD's cards shown")
	card.set(&"_placed_cards", true)
	assert_false(bool(card.call(&"_moved")), "placed under them")
	top[0] = Rect2()
	assert_true(bool(card.call(&"_moved")), "the top card gone")


func test_a_refused_release_keeps_the_hold() -> void:
	"""Review M5: under a load barrier the clock refuses; the ledger keeps its hold, so the open menu keeps its pause."""
	assert_true(_ledger.hold_menu(true), "held")
	assert_true(_game.begin_load(), "a load holds the barrier")
	assert_false(_ledger.hold_menu(false), "the release is refused")
	assert_true(_ledger.has_hold(LedgerScript.HOLD_MENU), "the hold is kept")
	_ledger.sync()
	assert_true(_game.clock().has_pause_reason(SimClock.MENU), "MENU still held on the clock")
	_game.rollback_load()


func test_the_hud_pause_button_releasing_player_also_waives_planning() -> void:
	"""Paused by the player and a planning surface: the button releases PLAYER; the rest of Resume follows."""
	var control := _control()
	control.ledger.auto_planning = true
	control.ledger.pause_player()
	control.ledger.set_planning(true, "the Pantry")
	_game.toggle_pause()
	control.call(&"_on_shell_action", UiShell.ID_PAUSE)
	assert_false(_game.is_paused(), "resumed")


func test_an_open_planning_surface_pauses_through_the_time_control() -> void:
	"""A surface the time control watches, open, with the setting on: the planning pause, named."""
	var control := _control()
	control.ledger.auto_planning = true
	var open: Array[bool] = [true]
	control.add_planning("the Work screen", func() -> bool: return open[0])
	control._process(0.0)
	assert_equal(control.ledger.kinds(), LedgerScript.KIND_PLANNING, "planning")
	assert_true(_words_of(control.ledger).contains("the Work screen"), _words_of(control.ledger))
	open[0] = false
	control._process(0.0)
	assert_false(_game.is_paused(), "closed: running")
