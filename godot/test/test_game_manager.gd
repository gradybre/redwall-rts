extends "res://test/framework/test_case.gd"
## Coverage for the game state machine, pause toggle and speed cycling.

const GameManagerScript := preload("res://scripts/systems/game_manager.gd")

var _game: GameManagerScript = null
var _states: Array[int] = []


func before_each() -> void:
	"""Build a fresh game manager outside the scene tree."""
	_game = GameManagerScript.new()
	_states = []
	_game.state_changed.connect(_on_state_changed)


func after_each() -> void:
	"""Free the manager and restore the engine clock it may have changed."""
	if _game != null:
		_game.free()
		_game = null
	Engine.time_scale = 1.0


func test_starts_in_boot_state() -> void:
	"""Before start_game() the manager reports the boot state."""
	assert_equal(_game.get_state(), GameManagerScript.GameState.BOOT, "state is BOOT")
	assert_equal(_game.get_state_name(), "BOOT", "state name matches the enum")


func test_start_game_enters_play() -> void:
	"""start_game() moves to PLAYING at the base speed and signals once."""
	_game.start_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "state is PLAYING")
	assert_almost_equal(_game.get_speed(), 1.0, "speed resets to 1x")
	assert_equal(_states.size(), 1, "the transition was signalled once")


func test_pause_and_resume() -> void:
	"""Pausing and resuming move between PAUSED and PLAYING."""
	_game.start_game()
	_game.pause_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "state is PAUSED")
	_game.resume_game()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "state is PLAYING again")


func test_toggle_pause_flips_state() -> void:
	"""toggle_pause() alternates between the two live states."""
	_game.start_game()
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PAUSED, "first toggle pauses")
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.PLAYING, "second toggle resumes")


func test_pause_does_nothing_during_boot() -> void:
	"""Pause controls are inert until the game has started."""
	_game.toggle_pause()
	assert_equal(_game.get_state(), GameManagerScript.GameState.BOOT, "still in BOOT")
	assert_equal(_states.size(), 0, "no transition was signalled")


func test_resume_does_nothing_while_playing() -> void:
	"""Resuming an unpaused game is a no-op, not a duplicate transition."""
	_game.start_game()
	_game.resume_game()
	assert_equal(_states.size(), 1, "only the start transition was signalled")


func test_cycle_speed_wraps_through_multipliers() -> void:
	"""Speed cycles through every multiplier and returns to the first."""
	_game.start_game()
	var seen: Array[float] = []
	for index: int in GameManagerScript.SPEED_MULTIPLIERS.size():
		seen.append(_game.cycle_speed())
	assert_almost_equal(seen[seen.size() - 1], 1.0, "the cycle wraps back to 1x")
	assert_almost_equal(_game.get_speed(), 1.0, "reported speed matches the cycle")


func test_cycle_speed_drives_the_engine_clock() -> void:
	"""The active multiplier is applied to Engine.time_scale."""
	_game.start_game()
	var speed: float = _game.cycle_speed()
	assert_almost_equal(Engine.time_scale, speed, "engine time scale follows the speed")


func test_elapsed_time_only_accumulates_while_playing() -> void:
	"""Paused frames do not advance the in-game clock."""
	_game.start_game()
	_game._process(0.5)
	_game.pause_game()
	_game._process(0.5)
	assert_almost_equal(_game.get_elapsed_play_seconds(), 0.5, "only the playing frame counted")


func test_restarting_resets_the_play_clock() -> void:
	"""A second start_game() does not inherit the previous run's elapsed time."""
	_game.start_game()
	_game._process(2.0)
	_game.start_game()
	assert_almost_equal(_game.get_elapsed_play_seconds(), 0.0, "the clock restarted at zero")


func _on_state_changed(new_state: int) -> void:
	"""Record a state transition for assertion."""
	_states.append(new_state)
