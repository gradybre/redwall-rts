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
##
## LOAD BARRIER (RESTORE-R01, decision 0091). `begin_load()` raises a transient guard that this
## node checks BEFORE host advance and BEFORE every scheduler pump, and that every operational
## control refuses under: start, pause, resume, toggle, speed, cycle and overload acknowledgement
## each return a `LOAD_IN_PROGRESS` refusal having altered neither the clock nor the queue. The
## guard is NOT a pause reason. It is never OR-ed into the clock's mask, never queued and never
## serialized, because the saved logical mask is the thing being restored and must not acquire a
## bit describing the act of restoring it. `is_loading()` exists so the HUD can say LOAD anyway.
##
## Only `restore_clock_runtime()` writes under that guard, and it goes straight to the clock's one
## validated assignment boundary -- never through `set_pause()`, whose PLAYER path deliberately
## ZEROES a sub-tick debt and counts the discard, which would corrupt the very debt being restored.
## `publish_restored_world()` then sets `_started` and derives PLAYING/PAUSED from the RESTORED
## mask while the guard still holds. `end_load()` releases it and resets the monotonic host origin,
## so however many real seconds the load spanned, no debt is owed for them.
##
## ROLLBACK USES THE SAME API. `begin_load()` copies the clock's ten runtime scalars into a
## pre-allocated checkpoint column, and `rollback_load()` reinstalls them through the same
## `restore_runtime()` call before restoring the previous `_started`/`_state` -- so a load that
## fails after the clock was installed leaves BOOT as BOOT, and a running game as it stood.
##
## WHAT THIS GUARD DOES NOT REACH, and cannot from this file: `clock()` and `scheduler_events()`
## hand out the raw clock and queue, whose own mutators know nothing about this barrier.
## RESTORE-R01 requires the shared guard to reach inside those two objects, and both files are
## owned elsewhere, so the hole is recorded in decision 0091 rather than papered over with a check
## a raw caller bypasses anyway. The disk half of "disk-backed rollback" is equally absent: no
## section 1 WORLD writer exists on this base, so the checkpoint here is in memory only.

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

## Load-barrier refusals (RESTORE-R01). `LOAD_IN_PROGRESS` is what an ordinary control gets while
## the guard is held; the rest are misuse of the load sequence itself.
const REFUSE_LOADING: StringName = &"LOAD_IN_PROGRESS"
const REFUSE_LOAD_ALREADY_OPEN: StringName = &"LOAD_ALREADY_IN_PROGRESS"
const REFUSE_LOAD_NOT_OPEN: StringName = &"LOAD_NOT_IN_PROGRESS"
const REFUSE_LOAD_INSIDE_TICK: StringName = &"LOAD_INSIDE_TICK"
const REFUSE_CLOCK_RESTORE: StringName = &"CLOCK_RESTORE_REFUSED"
const REFUSE_LOAD_NOT_INSTALLED: StringName = &"LOAD_NOT_INSTALLED"
const REFUSE_LOAD_NOT_PUBLISHED: StringName = &"LOAD_NOT_PUBLISHED"
const REFUSE_LOAD_UNRECOVERABLE: StringName = &"LOAD_UNRECOVERABLE"

## Rollback checkpoint column: the clock's ten runtime scalars in `restore_runtime()` argument
## order, allocated once in `_init()` and overwritten in place, never resized.
const CHECKPOINT_FIELDS: int = 10
const CHECKPOINT_COMPLETED_TICK: int = 0
const CHECKPOINT_DEBT: int = 1
const CHECKPOINT_REQUESTED_SPEED: int = 2
const CHECKPOINT_PAUSE_MASK: int = 3
const CHECKPOINT_FALLBACK_COUNT: int = 4
const CHECKPOINT_DIAGNOSTIC_PAUSE_COUNT: int = 5
const CHECKPOINT_ACKNOWLEDGED_CATCHUP_RESETS: int = 6
const CHECKPOINT_ACKNOWLEDGED_TICKS_DISCARDED: int = 7
const CHECKPOINT_SUBTICK_DEBT_DISCARDS: int = 8
const CHECKPOINT_DAY_BOUNDARIES_CROSSED: int = 9

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
## RESTORE-R01's transient load barrier and the phase flags of one load, none of them serialized.
var _loading: bool = false
var _restore_installed: bool = false
var _published: bool = false
## Set only when a rollback could not reinstall its own checkpoint: the barrier then stays held.
var _unrecoverable: bool = false
## Pre-load checkpoint, allocated once so a rollback allocates nothing at its worst moment.
var _checkpoint: PackedInt64Array = PackedInt64Array()
var _checkpoint_started: bool = false
var _checkpoint_state: int = GameState.BOOT


func _init() -> void:
	"""Bind the per-frame callables, queue, rollback column and clock signals before any tree."""
	_step_callable = _on_clock_step
	_day_boundary_callable = _on_clock_day_boundary
	_events = SchedulerEventsScript.new(_clock)
	_checkpoint.resize(CHECKPOINT_FIELDS)
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
	if _loading:
		return
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

	THE LOAD BARRIER IS CHECKED FIRST, before `_started` and before the frame is opened, because
	RESTORE-R01 requires it ahead of both host advance and scheduler pumping INCLUDING direct
	test and service entry points -- `_process` is not the only way in. Zero is the true number
	of ticks run, not a failure sentinel; `last_refusal()` names the refusal.
	"""
	if _loading:
		_refuse(REFUSE_LOADING)
		return 0
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

	REFUSED UNDER THE LOAD BARRIER. RESTORE-R01 step 3 forbids reaching a restored world through
	this API at all: it clears the queue section 12 is restoring, replaces the clock section 1 was
	just written into, and queues a player resume the saved mask never asked for.
	"""
	if _loading:
		return _refuse(REFUSE_LOADING)
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

	Refused outright while a load holds the barrier, leaving the restored queue untouched.
	"""
	if _loading:
		return _refuse(REFUSE_LOADING)
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

	Refused outright while a load holds the barrier: a restored PLAYER pause is saved state.
	"""
	if _loading:
		return _refuse(REFUSE_LOADING)
	if not _started:
		return _refuse(REFUSE_NOT_STARTED)
	if not _queue_player_resume():
		return false
	_last_host_usec = Time.get_ticks_usec()
	_sync_state()
	return true


func toggle_pause() -> bool:
	"""Flip the PLAYER pause reason only. Refused during boot, under load, and on a queue refusal."""
	if _loading:
		return _refuse(REFUSE_LOADING)
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

	Refused under the load barrier, where zero ticks were genuinely dropped and the restored debt
	and U3 counters stay exactly as the save recorded them.
	"""
	if _loading:
		_refuse(REFUSE_LOADING)
		return 0
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

	Refused under the load barrier before the submission, so the restored queue gains no record.
	"""
	if _loading:
		return _refuse(REFUSE_LOADING)
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

	AND THE SECOND HALF OF THE LOAD BARRIER: RESTORE-R01 wants the guard before scheduler pumping
	as well as before host advance. Every caller below already refuses first, so this check is the
	one that survives a future caller that forgets -- a load frame pumps nothing.
	"""
	if _loading:
		return
	_events.pump()


# --- load barrier and the RESTORE-R01 call site --------------------------------------------------
#
# THE SEQUENCE IS begin_load -> restore_clock_runtime -> (section 12 queue restore, save owner) ->
# publish_restored_world -> end_load, or begin_load -> ... -> rollback_load on any failure. Every
# operational control above refuses in between, and `_drain_boundary()` pumps nothing, so the load
# may span as many host frames as it needs without a tick racing the state being installed.


func begin_load() -> bool:
	"""Raise the load barrier and capture the rollback checkpoint. False if one is already open.

	The checkpoint is taken HERE, before any operational setter could have moved the clock, which
	is what makes step 6's rollback a return to the pre-load state rather than to some midpoint.
	Refused from inside a tick: the queue is executing a boundary and the clock is mid-drain, so
	nothing may be installed underneath it.
	"""
	if _loading:
		return _refuse(REFUSE_LOAD_ALREADY_OPEN)
	if _events.is_executing_tick():
		return _refuse(REFUSE_LOAD_INSIDE_TICK)
	_capture_checkpoint()
	_checkpoint_started = _started
	_checkpoint_state = _state
	_restore_installed = false
	_published = false
	_loading = true
	_last_refusal = REFUSE_NONE
	return true


func restore_clock_runtime(completed_tick: int, debt: int, requested_speed: int, pause_mask: int,
		fallback_count: int, diagnostic_pause_count: int, acknowledged_catchup_resets: int,
		acknowledged_ticks_discarded: int, subtick_debt_discards: int,
		day_boundaries_crossed: int) -> bool:
	"""Install a saved clock runtime under the barrier. THE call site of `restore_runtime()`.

	Ten integers straight to the clock's one validated assignment boundary: no setter, no queued
	event, no tick, no drain, no day notification and no state signal happen here, which is the
	whole point of RESTORE-R01. A clock-side refusal leaves all ten fields untouched and surfaces
	as CLOCK_RESTORE_REFUSED; `clock().last_error()` is deliberately NOT consulted, because a
	refused restore does not write it -- the save owner already holds the record it failed on.
	"""
	if not _loading:
		return _refuse(REFUSE_LOAD_NOT_OPEN)
	if _events.is_executing_tick():
		return _refuse(REFUSE_LOAD_INSIDE_TICK)
	if not _clock.restore_runtime(completed_tick, debt, requested_speed, pause_mask,
			fallback_count, diagnostic_pause_count, acknowledged_catchup_resets,
			acknowledged_ticks_discarded, subtick_debt_discards, day_boundaries_crossed):
		return _refuse(REFUSE_CLOCK_RESTORE)
	_restore_installed = true
	_last_refusal = REFUSE_NONE
	return true


func publish_restored_world() -> bool:
	"""Leave BOOT on the RESTORED mask, with the barrier still held (RESTORE-R01 step 4).

	`_started` is set explicitly rather than by `start_game()`, and PLAYING/PAUSED is derived from
	the pause mask the save carried, so a file saved inside a MENU or PLAYER pause comes back
	paused. The one state signal this may emit is the permitted post-publication refresh; no tick,
	day or overload event is replayed. Refused until a restore has actually been installed.
	"""
	if not _loading:
		return _refuse(REFUSE_LOAD_NOT_OPEN)
	if not _restore_installed:
		return _refuse(REFUSE_LOAD_NOT_INSTALLED)
	_started = true
	_published = true
	_sync_state()
	_last_refusal = REFUSE_NONE
	return true


func end_load() -> bool:
	"""Release the barrier and reset the monotonic host origin. Refused before publication.

	RESTORE-R01 step 5: the origin moves to NOW, so the real seconds the load spent -- however
	many host frames that was -- accrue no debt against the restored tick. Requiring publication
	first means a half-installed world cannot be released by calling the ordinary exit;
	`rollback_load()` is the only other way out.
	"""
	if not _loading:
		return _refuse(REFUSE_LOAD_NOT_OPEN)
	if not _published:
		return _refuse(REFUSE_LOAD_NOT_PUBLISHED)
	_loading = false
	_last_host_usec = Time.get_ticks_usec()
	_last_refusal = REFUSE_NONE
	return true


func rollback_load() -> bool:
	"""Reinstall the pre-load checkpoint through the same API, restore `_started`/`_state`, release.

	Step 6. The previous coordinator state returns with the clock, so a failed FIRST load stays in
	BOOT with no partial world published. If the checkpoint itself will not reinstall, the barrier
	stays HELD and `is_load_unrecoverable()` reports it: a world that could not be put back is not
	released to the player.
	"""
	if not _loading:
		return _refuse(REFUSE_LOAD_NOT_OPEN)
	if not _apply_checkpoint():
		_unrecoverable = true
		return _refuse(REFUSE_LOAD_UNRECOVERABLE)
	_started = _checkpoint_started
	_set_state(_checkpoint_state)
	_restore_installed = false
	_published = false
	_loading = false
	_last_host_usec = Time.get_ticks_usec()
	_last_refusal = REFUSE_NONE
	return true


func is_loading() -> bool:
	"""True while the load barrier is held. UI may show LOAD; the pause mask never carries it."""
	return _loading


func is_load_published() -> bool:
	"""True once the current load has published its restored world and before the barrier drops."""
	return _published


func is_load_unrecoverable() -> bool:
	"""True when a rollback could not reinstall its own checkpoint and the barrier stayed held."""
	return _unrecoverable


func _capture_checkpoint() -> void:
	"""Copy the clock's ten runtime scalars into the pre-allocated column, in argument order."""
	_checkpoint[CHECKPOINT_COMPLETED_TICK] = _clock.completed_tick()
	_checkpoint[CHECKPOINT_DEBT] = _clock.debt()
	_checkpoint[CHECKPOINT_REQUESTED_SPEED] = _clock.requested_speed()
	_checkpoint[CHECKPOINT_PAUSE_MASK] = _clock.pause_mask()
	_checkpoint[CHECKPOINT_FALLBACK_COUNT] = _clock.fallback_count()
	_checkpoint[CHECKPOINT_DIAGNOSTIC_PAUSE_COUNT] = _clock.diagnostic_pause_count()
	_checkpoint[CHECKPOINT_ACKNOWLEDGED_CATCHUP_RESETS] = _clock.acknowledged_catchup_resets()
	_checkpoint[CHECKPOINT_ACKNOWLEDGED_TICKS_DISCARDED] = _clock.acknowledged_ticks_discarded()
	_checkpoint[CHECKPOINT_SUBTICK_DEBT_DISCARDS] = _clock.subtick_debt_discards()
	_checkpoint[CHECKPOINT_DAY_BOUNDARIES_CROSSED] = _clock.day_boundaries_crossed()


func _apply_checkpoint() -> bool:
	"""Reinstall the captured checkpoint through the SAME validated assignment boundary."""
	return _clock.restore_runtime(_checkpoint[CHECKPOINT_COMPLETED_TICK],
		_checkpoint[CHECKPOINT_DEBT], _checkpoint[CHECKPOINT_REQUESTED_SPEED],
		_checkpoint[CHECKPOINT_PAUSE_MASK], _checkpoint[CHECKPOINT_FALLBACK_COUNT],
		_checkpoint[CHECKPOINT_DIAGNOSTIC_PAUSE_COUNT],
		_checkpoint[CHECKPOINT_ACKNOWLEDGED_CATCHUP_RESETS],
		_checkpoint[CHECKPOINT_ACKNOWLEDGED_TICKS_DISCARDED],
		_checkpoint[CHECKPOINT_SUBTICK_DEBT_DISCARDS],
		_checkpoint[CHECKPOINT_DAY_BOUNDARIES_CROSSED])


func cycle_speed() -> int:
	"""Advance to the next selectable speed, wrapping 1 -> 2 -> 4 -> 1, and return it.

	Under the load barrier it changes nothing and returns the speed that still stands, which is
	the restored one; `last_refusal()` carries the reason.
	"""
	if _loading:
		_refuse(REFUSE_LOADING)
		return get_speed()
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
	_set_state(GameState.PAUSED if _clock.is_paused() else GameState.PLAYING)


func _set_state(value: int) -> void:
	"""Assign the coarse state and notify UI only on a real change.

	The single writer of `_state`, so the rollback path restores BOOT through exactly the
	transition rule the running game uses rather than a silent assignment the HUD never hears.
	"""
	if _state == value:
		return
	_state = value
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
