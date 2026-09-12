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
## SCHEDULER-EVENT BINDING (R07-SCHED-001, decision 0084). Every speed and pause control on this
## node now travels through `scripts/core/scheduler_events.gd` instead of calling the clock's
## immediate setters, and `advance_host_time()` runs `advance_frame()` rather than `advance()`, so
## the running game gets the opening pump, the per-tick barrier, the unsigned-sequence tiebreak,
## the 250/256 reserve and decision 0054's queued overload rung. Decision 0054's open item 1 named
## this node as the thing that bypassed all of it.
##
## A CONTROL SUBMITTED BETWEEN FRAMES IS DRAINED IN THE SAME CALL. The contract stamps such an
## event with the CURRENT completed tick and says input between frames "belongs to the next safe
## boundary"; between ticks that boundary is the current one, so `_drain_boundary()` performs the
## very drain the next frame's opening pump would perform, and decision 0054 point 5 states that a
## second drain at one boundary is normal rather than a bug. That keeps `pause_game()` observable
## immediately -- `ui_manager.apply_opening_pause()` would otherwise report an inspection pause
## that is not yet held. An event submitted from INSIDE tick k is still left pending by the same
## call, and no guard is written for it: the queue stamps such a record k while `completed_tick()`
## still reads k-1, so the drain provably cannot reach it and the clock's per-tick barrier applies
## it after k commits.
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
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")

enum GameState { BOOT, PLAYING, PAUSED }

const STATE_NAMES: Array[String] = ["BOOT", "PLAYING", "PAUSED"]

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_STEP: StringName = &"INVALID_SIMULATION_STEP"
const REFUSE_INVALID_DAY_BOUNDARY: StringName = &"INVALID_SIMULATION_DAY_BOUNDARY"
const REFUSE_ALREADY_BOUND: StringName = &"SIMULATION_ALREADY_BOUND"
const REFUSE_NOT_STARTED: StringName = &"GAME_NOT_STARTED"
const REFUSE_SCHEDULER_REBIND: StringName = &"SCHEDULER_REBIND_REFUSED"

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
## R07-SCHED-001's speed/pause queue, bound to whichever clock `start_game()` last built.
var _events: SchedulerEventsScript = null
## Reused so no control path allocates a result record (decision 0015).
var _submit_result: SchedulerEventsScript.SubmitResult = SchedulerEventsScript.SubmitResult.new()


func _init() -> void:
	"""Bind the per-frame callables, the scheduler queue and clock signals before entering a tree."""
	_step_callable = _on_clock_step
	_day_boundary_callable = _on_clock_day_boundary
	_events = SchedulerEventsScript.new(_clock)
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
	"""Fold one host frame through the scheduler barrier into the clock. Returns ticks run.

	`advance_frame()` and not `advance()`: it opens the host frame (restoring the overload
	producer's single downgrade), pumps the queue once BEFORE any tick decision -- which is the
	pump a fully paused frame still performs -- and then hands the clock the per-tick barrier and
	the overload hook. Decision 0054's open item 1 was precisely that this line passed neither.
	"""
	if not _started:
		return 0
	var count: int = _events.advance_frame(elapsed_microseconds, _step_callable,
		_day_boundary_callable)
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
	"""Reason the most recent refused call was refused; empty after a successful one.

	Carries both this node's own codes and, unchanged, the scheduler queue's admission refusals,
	which nothing in production read before decision 0084 wired the queue in.
	"""
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


func start_game() -> bool:
	"""Leave BOOT and begin play at 1x from tick 0, discarding any previous run's clock and queue.

	THE ORDER OF THE FIRST THREE LINES IS LOAD-BEARING (decision 0054 open item 2). `clear()`
	FIRST, because `rebind_clock()` refuses a non-empty queue -- records stamped against the old
	clock's tick numbering cannot be re-based onto a clock that restarts at tick 0. Then the new
	clock, then the rebind, which must precede the first submission and the first frame.
	`clear()` is world initialization, not a drain: the previous run's pending events are
	discarded with it, which is correct because the world they addressed is gone.
	"""
	_events.clear()
	_clock = SimClockScript.new()
	_connect_clock_signals()
	if not _events.rebind_clock(_clock):
		return _refuse(REFUSE_SCHEDULER_REBIND)
	if not _queue_player_resume():
		return false
	_started = true
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()
	speed_changed.emit(get_speed())
	return true


func pause_game() -> bool:
	"""Hold the PLAYER pause reason through the scheduler queue. Other held reasons are untouched.

	Returns false, with `last_refusal()` naming the queue's own code, when the submission is
	refused -- a full queue is visible and retryable rather than a silently dropped pause.
	"""
	if not _started:
		return _refuse(REFUSE_NOT_STARTED)
	if not _queue_pause(SchedulerEventsScript.PRODUCER_PLAYER, SimClockScript.PLAYER,
			SchedulerEventsScript.VALUE_HOLD):
		return false
	_sync_state()
	return true


func resume_game() -> bool:
	"""Release the PLAYER pause reason and nothing else, through the scheduler queue.

	`submit_player_resume_into()` is the contract's "ordinary Resume clears PLAYER only" path and
	can express nothing else, so this cannot lift a MENU, LOAD or overload CRITICAL hold.
	"""
	if not _started:
		return _refuse(REFUSE_NOT_STARTED)
	if not _queue_player_resume():
		return false
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()
	return true


func toggle_pause() -> bool:
	"""Flip the PLAYER pause reason only. Refused during boot, and refused if the queue refuses."""
	if not _started:
		return _refuse(REFUSE_NOT_STARTED)
	if _clock.has_pause_reason(SimClockScript.PLAYER):
		return resume_game()
	return pause_game()


func acknowledge_overload() -> int:
	"""Player recovery from a REQ-SET-008 diagnostic pause. Returns owed ticks explicitly dropped.

	This is the only path that drops owed ticks, it is never automatic, and the clock counts
	every call (blocker U3, conservative rule). It deliberately does NOT travel through the queue:
	the queue's two kinds cannot express "clear the retained debt", and decision 0054 keeps
	`acknowledge_without_catchup()` byte-unchanged.

	The queue is drained FIRST so a ladder rung still pending from the frame that raised the
	diagnostic lands before the acknowledgement, instead of re-applying CRITICAL one pump later
	and paging the player back into the pause they just cleared.
	"""
	_drain_boundary()
	var dropped: int = _clock.acknowledge_without_catchup()
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()
	return dropped


func set_speed(value: int) -> bool:
	"""Request 1x, 2x or 4x through the scheduler queue. Returns false and changes nothing else.

	Every rejection the clock used to make itself is now the queue's admission refusal, named in
	`last_refusal()`: 3x and 0 refuse as SCHEDULER_SPEED_NOT_SELECTABLE and leave the queue
	byte-identical (allocate before consume, decision 0059).
	"""
	if not _events.submit_speed_into(value, _submit_result):
		return _refuse(_submit_result.error)
	_drain_boundary()
	_last_refusal = REFUSE_NONE
	speed_changed.emit(get_speed())
	return true


func _queue_pause(producer: int, reason: int, value: int) -> bool:
	"""Submit one pause hold or clear through the queue and drain the current boundary."""
	if not _events.submit_pause_into(producer, reason, value, _submit_result):
		return _refuse(_submit_result.error)
	_drain_boundary()
	_last_refusal = REFUSE_NONE
	return true


func _queue_player_resume() -> bool:
	"""Submit the ordinary Resume -- PLAYER cleared, every other reason left standing."""
	if not _events.submit_player_resume_into(_submit_result):
		return _refuse(_submit_result.error)
	_drain_boundary()
	_last_refusal = REFUSE_NONE
	return true


func _drain_boundary() -> void:
	"""Apply the queue's admitted prefix for the CURRENT completed boundary, right now.

	THE SINGLE PLACE THIS NODE'S SAME-BOUNDARY DRAIN POLICY IS WRITTEN. Between ticks the current
	completed tick is the next safe boundary the contract sends between-frame input to, so this is
	the very drain the next frame's opening pump would perform; decision 0054 point 5 makes a
	second drain at one boundary normal rather than a bug.

	NO GUARD IS NEEDED FOR A SUBMISSION MADE FROM INSIDE TICK k, and none is written, because the
	queue already enforces it: such a record is stamped k while `completed_tick()` still reads
	k-1, and `pump_into()` drains only `boundary_tick <= completed_tick`. So this call is provably
	a no-op on the record just submitted, which is then applied by the clock's per-tick barrier
	after k commits -- never midway through k.
	"""
	_events.pump()


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
	"""The authoritative clock, for systems that need tick or calendar state directly.

	`start_game()` REPLACES this instance, so a caller that caches it must re-read it rather than
	hold it: a stale reference keeps a `completed_tick` that has stopped moving. ARCH-SYS-002's
	command queue re-reads it every tick for exactly that reason.
	"""
	return _clock


func scheduler_events() -> SchedulerEventsScript:
	"""The R07-SCHED-001 queue every speed and pause control on this node travels through.

	`start_game()` REBINDS this instance to the clock it builds rather than replacing it, so a
	cached reference stays valid across a restart -- unlike `clock()`.
	"""
	return _events


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
