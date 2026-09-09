extends Node
## Adapter from the Godot host frame onto the authoritative fixed-step clock.
##
## ARCH-MIG-006 step 4: this node owns no time rules of its own. Every rule lives in
## `scripts/core/sim_clock.gd`, which the exact tick/calendar suite covers; GameManager only
## converts host frames into integer microseconds, forwards them, and re-derives the coarse
## BOOT/PLAYING/PAUSED state the HUD shows.
##
## Three prototype defects recorded in `docs/decisions/0006-prototype-diverges-from-gdd.md`
## are closed here:
##   * Speeds are exactly 0/1/2/4 (REQ-SET-003). There is no 3x, and 4x now exists.
##   * `Engine.time_scale` is never written. Authoritative time is integer fixed ticks; host
##     scaling is a scheduler input, not the clock (ARCH-CLOCK-001).
##   * The offset calendar exists: `(tick + 4500) mod 18000`, tick 0 = 06:00 (GDD §5.1).
##
## Pause is a reason MASK held by the clock, not a boolean owned here, so a menu pause cannot
## be lifted by a player resume. The scene tree is deliberately never paused: pausing the
## simulation must leave camera, selection and UI live (UI §1.1), and tree pause would freeze
## them too.
##
## Runs with PROCESS_MODE_ALWAYS so host frames keep arriving no matter what else pauses.
##
## SIMULATION BINDING (ARCH-MIG-006 step 6). The clock takes a per-tick callback and a
## day-boundary callback. `bind_simulation()` is how `settlement_system.gd` becomes the thing they
## call, and it is a DIRECT CALL, not a signal: the four signals on this node all end at a HUD
## label, and simulation ordering may not depend on connection order. The tick index handed to the
## bound handler is `completed_tick() + 1` -- the index of the tick being committed -- read from
## the clock rather than counted here, so no second tick counter can drift from the authoritative
## one. Nothing is bound by default, and an unbound GameManager runs the clock and no simulation,
## which is exactly what a test instance wants.

const SimClockScript := preload("res://scripts/core/sim_clock.gd")

enum GameState { BOOT, PLAYING, PAUSED }

const STATE_NAMES: Array[String] = ["BOOT", "PLAYING", "PAUSED"]

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_STEP: StringName = &"INVALID_SIMULATION_STEP"
const REFUSE_INVALID_DAY_BOUNDARY: StringName = &"INVALID_SIMULATION_DAY_BOUNDARY"
const REFUSE_ALREADY_BOUND: StringName = &"SIMULATION_ALREADY_BOUND"

## UI-only notifications. Game logic calls the accessors below directly instead.
signal state_changed(new_state: int)
signal speed_changed(speed: int)
signal day_advanced(absolute_day: int)
signal clock_diagnostic(message: String)

var _clock: SimClockScript = SimClockScript.new()
var _state: int = GameState.BOOT
var _started: bool = false
var _last_host_usec: int = 0
## Cached callables and Calendar so the per-frame path allocates nothing (decision 0015).
var _step_callable: Callable = Callable()
var _day_boundary_callable: Callable = Callable()
var _calendar: SimClockScript.Calendar = SimClockScript.Calendar.new(0)
## The bound simulation, or two invalid callables while nothing is bound.
var _simulation_step: Callable = Callable()
var _simulation_day_boundary: Callable = Callable()
var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:
	"""Bind the per-frame callables and clock signals before the node ever enters a tree."""
	_step_callable = _on_clock_step
	_day_boundary_callable = _on_clock_day_boundary
	_connect_clock_signals()


func _ready() -> void:
	"""Keep processing while anything else pauses and report readiness."""
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] ready")


func _process(_delta: float) -> void:
	"""Fold real elapsed host time into the fixed-step clock.

	The host delta is read as integer microseconds from Time rather than the float `delta`, so
	no float ever reaches authoritative state (ARCH-AUTH-003).
	"""
	if not _started:
		return
	var now: int = Time.get_ticks_usec()
	var elapsed: int = now - _last_host_usec
	_last_host_usec = now
	advance_host_time(elapsed)


func advance_host_time(elapsed_microseconds: int) -> int:
	"""Fold one host frame into the clock and re-derive game state. Returns ticks run."""
	if not _started:
		return 0
	var count: int = _clock.advance(elapsed_microseconds, _step_callable, _day_boundary_callable)
	_sync_state()
	return count


func bind_simulation(step: Callable, day_boundary: Callable) -> bool:
	"""Adopt the simulation this clock drives. Returns false and binds nothing on a refusal.

	Refuses a second binding while one is held: two simulations sharing one clock would each run
	a partial tick, and silently replacing the first would leave a live settlement receiving no
	ticks while the game still looked as though it were running. Call `unbind_simulation()` first.
	"""
	if not step.is_valid():
		return _refuse(REFUSE_INVALID_STEP)
	if not day_boundary.is_valid():
		return _refuse(REFUSE_INVALID_DAY_BOUNDARY)
	if _simulation_step.is_valid():
		return _refuse(REFUSE_ALREADY_BOUND)
	_simulation_step = step
	_simulation_day_boundary = day_boundary
	_last_refusal = REFUSE_NONE
	return true


func unbind_simulation() -> void:
	"""Release the bound simulation. The clock keeps running and drives nothing."""
	_simulation_step = Callable()
	_simulation_day_boundary = Callable()


func has_simulation() -> bool:
	"""True while a simulation is bound to this clock."""
	return _simulation_step.is_valid()


func last_refusal() -> StringName:
	"""Reason the most recent refused binding was refused; empty after a successful one."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false


func _on_clock_step() -> void:
	"""Run the bound simulation for the tick the clock is committing.

	The clock has not yet incremented its counter when it calls this, so the tick being committed
	is `completed_tick() + 1`. That index is read from the clock every tick rather than counted
	here, so this adapter cannot drift from authoritative time.
	"""
	if not _simulation_step.is_valid():
		return
	_simulation_step.call(_clock.completed_tick() + 1)


func start_game() -> void:
	"""Leave BOOT and begin play at 1x from tick 0, discarding any previous run's clock."""
	_clock = SimClockScript.new()
	_connect_clock_signals()
	_started = true
	_last_host_usec = Time.get_ticks_usec()
	_clock.set_pause(SimClockScript.PLAYER, false)
	_sync_state()
	speed_changed.emit(get_speed())


func pause_game() -> void:
	"""Hold the PLAYER pause reason. Other held reasons are untouched."""
	if not _started:
		return
	_clock.set_pause(SimClockScript.PLAYER, true)
	_sync_state()


func resume_game() -> void:
	"""Release the PLAYER pause reason. The game stays paused if another reason still holds."""
	if not _started:
		return
	_clock.set_pause(SimClockScript.PLAYER, false)
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()


func toggle_pause() -> void:
	"""Flip the PLAYER pause reason only. No effect during boot."""
	if not _started:
		return
	if _clock.has_pause_reason(SimClockScript.PLAYER):
		resume_game()
	else:
		pause_game()


func acknowledge_overload() -> int:
	"""Player recovery from a REQ-SET-008 diagnostic pause. Returns owed ticks explicitly dropped.

	This is the only path that drops owed ticks, it is never automatic, and the clock counts
	every call (blocker U3, conservative rule).
	"""
	var dropped: int = _clock.acknowledge_without_catchup()
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()
	return dropped


func set_speed(value: int) -> bool:
	"""Request 1x, 2x or 4x. Returns false and changes nothing for any other value."""
	if not _clock.set_speed(value):
		return false
	speed_changed.emit(get_speed())
	return true


func cycle_speed() -> int:
	"""Advance to the next selectable speed, wrapping 1 -> 2 -> 4 -> 1, and return it."""
	var speeds: Array[int] = SimClockScript.SELECTABLE_SPEEDS
	var index: int = speeds.find(_clock.requested_speed())
	set_speed(speeds[(index + 1) % speeds.size()])
	return get_speed()


func get_state() -> int:
	"""Current GameState value."""
	return _state


func get_state_name() -> String:
	"""Human-readable name of the current state, for HUD display."""
	return STATE_NAMES[_state]


func get_speed() -> int:
	"""Speed the player asked for: 1, 2 or 4. Survives pauses unchanged."""
	return _clock.requested_speed()


func get_effective_speed() -> int:
	"""Speed actually simulated: 0 while any pause reason is held, otherwise get_speed()."""
	return _clock.effective_speed()


func is_paused() -> bool:
	"""True while any pause reason is held."""
	return _clock.is_paused()


func get_pause_reason_names() -> Array[String]:
	"""Held pause reasons as display names, for the HUD pause indicator."""
	return _clock.pause_reason_names()


func get_completed_tick() -> int:
	"""Simulation ticks completed since start_game(). 30 ticks is one game second at any speed."""
	return _clock.completed_tick()


func get_absolute_day() -> int:
	"""One-based day number under the offset calendar."""
	_clock.calendar_into(_calendar)
	return _calendar.absolute_day


func get_calendar_text() -> String:
	"""Date line for the top-right zone: year, season and day within that season."""
	_clock.calendar_into(_calendar)
	return "Y%d %s %d" % [_calendar.year, _calendar.season_name(), _calendar.season_day]


func get_clock_text() -> String:
	"""Zero-padded 24-hour HH:MM of the current tick (UI §2.2 uses 24-hour time)."""
	_clock.calendar_into(_calendar)
	return _calendar.clock_text()


func clock() -> SimClockScript:
	"""The authoritative clock, for systems that need tick or calendar state directly."""
	return _clock


func _connect_clock_signals() -> void:
	"""Forward the clock's UI notifications after start_game() swaps in a fresh instance."""
	_clock.clock_overload_warning.connect(_on_clock_overload_warning)
	_clock.clock_diagnostic_pause.connect(_on_clock_diagnostic_pause)


func _sync_state() -> void:
	"""Re-derive BOOT/PLAYING/PAUSED from the clock's mask and notify UI on a real change."""
	if not _started:
		return
	var new_state: int = GameState.PAUSED if _clock.is_paused() else GameState.PLAYING
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)


func _on_clock_day_boundary(moment: SimClockScript.Calendar) -> void:
	"""Run REQ-SET-007's daily work, then republish the crossing for the HUD date readout.

	Simulation first, UI second: the HUD must observe committed state, so the date it shows is
	never a day whose boundary work has not run.
	"""
	if _simulation_day_boundary.is_valid():
		_simulation_day_boundary.call(moment.absolute_day, moment.season)
	day_advanced.emit(moment.absolute_day)


func _on_clock_overload_warning(reduced_to_speed: int) -> void:
	"""Report the REQ-SET-008 ladder stepping the speed down under sustained overload."""
	speed_changed.emit(reduced_to_speed)
	clock_diagnostic.emit(_clock.last_diagnostic())


func _on_clock_diagnostic_pause(diagnostic: String) -> void:
	"""Report the 1x diagnostic pause the clock raises instead of skipping owed ticks."""
	clock_diagnostic.emit(diagnostic)
