extends Node
## Top-level game state, pause control and the speed multiplier.
##
## Runs with PROCESS_MODE_ALWAYS so it can lift a pause it applied itself.

enum GameState { BOOT, PLAYING, PAUSED }

const SPEED_MULTIPLIERS: Array[float] = [1.0, 2.0, 3.0]
const STATE_NAMES: Array[String] = ["BOOT", "PLAYING", "PAUSED"]

signal state_changed(new_state: int)
signal speed_changed(multiplier: float)

var _state: int = GameState.BOOT
var _speed_index: int = 0
var _elapsed_play_seconds: float = 0.0


func _ready() -> void:
	"""Keep processing while the tree is paused and report readiness."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] ready")


func _process(delta: float) -> void:
	"""Accumulate in-game elapsed time while the game is playing."""
	if _state == GameState.PLAYING:
		_elapsed_play_seconds += delta


func start_game() -> void:
	"""Leave the boot state and begin play at the default speed, from a clean clock."""
	_elapsed_play_seconds = 0.0
	_speed_index = 0
	_apply_speed()
	_set_state(GameState.PLAYING)


func pause_game() -> void:
	"""Halt the scene tree and enter the paused state."""
	if _state != GameState.PLAYING:
		return
	_set_tree_paused(true)
	_set_state(GameState.PAUSED)


func resume_game() -> void:
	"""Unpause the scene tree and return to play."""
	if _state != GameState.PAUSED:
		return
	_set_tree_paused(false)
	_set_state(GameState.PLAYING)


func toggle_pause() -> void:
	"""Flip between playing and paused. No effect during boot."""
	if _state == GameState.PLAYING:
		pause_game()
	elif _state == GameState.PAUSED:
		resume_game()


func cycle_speed() -> float:
	"""Advance to the next speed multiplier, wrapping around, and return it."""
	_speed_index = (_speed_index + 1) % SPEED_MULTIPLIERS.size()
	_apply_speed()
	return get_speed()


func get_state() -> int:
	"""Current GameState value."""
	return _state


func get_state_name() -> String:
	"""Human-readable name of the current state, for HUD display."""
	return STATE_NAMES[_state]


func get_speed() -> float:
	"""Current speed multiplier."""
	return SPEED_MULTIPLIERS[_speed_index]


func get_elapsed_play_seconds() -> float:
	"""Seconds of unpaused play since start_game()."""
	return _elapsed_play_seconds


func _set_state(new_state: int) -> void:
	"""Store the new state and notify UI listeners when it actually changed."""
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)


func _apply_speed() -> void:
	"""Push the current multiplier onto the engine clock and notify UI listeners."""
	Engine.time_scale = get_speed()
	speed_changed.emit(get_speed())


func _set_tree_paused(paused: bool) -> void:
	"""Set tree pause, tolerating instances that are not inside a scene tree."""
	if not is_inside_tree():
		return
	get_tree().paused = paused
