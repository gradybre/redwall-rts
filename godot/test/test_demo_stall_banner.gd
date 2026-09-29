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
