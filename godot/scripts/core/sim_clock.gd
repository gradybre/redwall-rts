extends RefCounted
## Authoritative fixed-step simulation clock: integer host-debt scheduler, offset
## calendar, pause-reason mask, and the REQ-SET-008 overload ladder.
##
## Promoted from the verified `docs/validation/headless/fixed_clock.gd` kernel,
## which stays byte-unchanged as the isolated experimental control.
##
## Time contract (REQ-SET-002/003/006, ARCH-CLOCK-001):
##   30 ticks/second at 1x, 750 ticks/hour, 18000 ticks/day, 12 days/season,
##   48 days/year. Tick 0 is 06:00 of year 1, spring, day 1.
##
## Calendar contract (GDD §5.1): calendar time is `(tick + 4500) mod 18000`, so
## the first midnight is tick 13500. Daily boundaries (REQ-SET-007) are crossings
## of THIS offset calendar, never `tick mod 18000 == 0` -- tick 18000 is 06:00 of
## day 2 and is not a boundary. `is_day_boundary()` is the single definition; no
## caller may re-derive it.
##
## Scheduler contract (ARCH-CLOCK-001/002): host elapsed time accumulates as
## `elapsed_microseconds * 30 * effective_speed` debt units, one tick costs
## 1000000, and at most 8 ticks are drained per host frame. Host timing is a
## scheduler input only: speed never changes per-tick rules, so 2x and 4x run two
## and four times as many identical ticks per real second (REQ-SET-003). No
## `Engine.time_scale` is touched here and no frame time reaches gameplay.
##
## Pause contract (REQ-SET-004): while any pause reason is set, the effective
## speed is 0 and no debt accumulates, so needs, jobs, weather, spoilage and event
## deadlines freeze. Camera, selection and UI are outside this module and stay
## live. Reasons compose as a bitmask, so closing a menu cannot resume a pause
## another reason still holds.
##
## BLOCKER U2 (docs/tasks/02_settlement_foundation.md) IS CLOSED IN PROCESS, AND
## THE PART OF IT THAT IS NOT IS NAMED. Queued speed/pause scheduler events now
## exist: `scripts/core/scheduler_events.gd` implements R07-SCHED-001's separate
## 256-record queue, its own unsigned 64-bit sequence, and the boundary pump that
## `advance()`'s `before_tick` hook calls before each fixed-tick decision and on
## paused frames (decision 0054). The ordering tiebreak that was missing is that
## sequence; the ARCH-CMD-003 catalog is deliberately still 24 economic kinds,
## because the scheduler queue has its own two-value kind domain.
##
## STILL OPEN, and it is persistence only: THERE IS NO SAVE MODULE in this
## repository, so ARCH-SAVE-002 §12's scheduler subsection is implemented as an
## encoder, a decoder and its validation, and is UNWIRED. A paused queue cannot
## yet survive a process restart. Task 09 owns the codec.
##
## set_speed() and set_pause() remain the IMMEDIATE setters and are what the
## queue's pump calls; they are no longer the only way in.
##
## BLOCKER U3 (spec contradiction, resolved conservatively). ARCH-CLOCK-001:
## "Preserve remaining debt; never discard completed or owed ticks to hide
## sustained overload." ARCH-CLOCK-002: "Explicit 'resume without wall-time
## catch-up' may clear scheduler debt ... record this scheduler event." GDD
## REQ-SET-008: at 1x the system "shall pause with a diagnostic rather than skip
## ticks." These conflict on whether owed ticks may ever vanish. The conservative
## reading is taken: debt is NEVER discarded implicitly. The only two paths that
## reduce debt without running a tick are both explicit and both counted --
## acknowledge_without_catchup() (counted in acknowledged_catchup_resets() and
## acknowledged_ticks_discarded()) and the sub-tick presentation debt discarded on
## a player pause, which ARCH-CLOCK-002 permits by name and which can only fire
## when zero whole ticks are owed (counted in subtick_debt_discards()). Those
## counters are public and tested so the choice is observable, not buried.
##
## ALLOCATION (task 2.7, decision 0015). advance() runs every host frame, so nothing on that
## path allocates: the checked arithmetic writes into the single per-instance `_math` scratch
## through int_math's `*_into()` forms, and every scratch value is copied into a local or tested
## as a bool before the next call. `_math` is never live across `_drain_ticks()`, which is the
## only place a caller's `step` callback could re-enter advance(), so a re-entrant frame cannot
## observe or clobber an outer frame's half-finished value. Calendar objects are handled the
## opposite way: `calendar_into()` lets a polling HUD reuse one it owns, while the day-boundary
## callback still receives a FRESH Calendar, because that object escapes to a callee which may
## keep it and a reused instance would silently change under it.

const IntMathScript := preload("res://scripts/core/int_math.gd")

## Pause reasons (UI §3 / ARCH-CMD-002). Independent bits, composed as a mask.
const PLAYER: int = 1
const MENU: int = 2
const CRITICAL: int = 4
const VICTORY: int = 8
const LOAD: int = 16
const ALL_PAUSE_REASONS: Array[int] = [PLAYER, MENU, CRITICAL, VICTORY, LOAD]
const PAUSE_REASON_NAMES: Array[String] = ["PLAYER", "MENU", "CRITICAL", "VICTORY", "LOAD"]

## Speed enum. Explicitly numbered 0/1/2/4 and never renumbered; there is no 3x.
const SPEED_PAUSED: int = 0
const SPEED_NORMAL: int = 1
const SPEED_DOUBLE: int = 2
const SPEED_QUADRUPLE: int = 4
const SELECTABLE_SPEEDS: Array[int] = [SPEED_NORMAL, SPEED_DOUBLE, SPEED_QUADRUPLE]

## Fixed-step and calendar constants (REQ-SET-002/006, GDD §5.1).
const TICKS_PER_SECOND: int = 30
const TICKS_PER_HOUR: int = 750
const TICKS_PER_DAY: int = 18000
const DAYS_PER_SEASON: int = 12
const DAYS_PER_YEAR: int = 48
const SEASONS_PER_YEAR: int = 4
const HOURS_PER_DAY: int = 24
const MINUTES_PER_HOUR: int = 60
## Tick 0 is 06:00, so calendar time leads tick count by six hours.
const CALENDAR_OFFSET_TICKS: int = 4500
## First crossing of the offset calendar into 00:00 (18000 - 4500).
const FIRST_MIDNIGHT_TICK: int = 13500
const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]

## Scheduler constants (ARCH-CLOCK-001).
const TICK_COST: int = 1000000
const MAX_TICKS_PER_FRAME: int = 8
## Debt accrued by one real second at 1x; the overload comparison's denominator.
const DEBT_PER_REAL_SECOND: int = TICKS_PER_SECOND * TICK_COST
## REQ-SET-008 backlog limit expressed without division: overload iff
## `OVERLOAD_NUMERATOR * debt > DEBT_PER_REAL_SECOND * effective_speed`, which is
## exactly "strictly more than 1/4 real second of backlog".
const OVERLOAD_NUMERATOR: int = 4

## UI-only notifications (game logic uses the return values and counters instead).
signal clock_overload_warning(reduced_to_speed: int)
signal clock_diagnostic_pause(diagnostic: String)
signal clock_day_boundary(absolute_day: int)

var _completed_tick: int = 0
var _debt: int = 0
var _requested_speed: int = SPEED_NORMAL
## A freshly constructed clock is player-paused: nothing simulates until the
## caller releases PLAYER, matching the kernel's initial mask.
var _pause_mask: int = PLAYER
var _fallback_count: int = 0
var _diagnostic_pause_count: int = 0
var _acknowledged_catchup_resets: int = 0
var _acknowledged_ticks_discarded: int = 0
var _subtick_debt_discards: int = 0
var _day_boundaries_crossed: int = 0
var _last_diagnostic: String = ""
var _last_error: String = ""
## Single reused arithmetic scratch for the per-frame scheduler path (task 2.7). Every read of
## `.value` is copied into a local immediately, so no two live values ever share it.
var _math: IntMathScript.IntResult = IntMathScript.IntResult.new()


class Calendar:
	"""One decoded calendar instant. All fields are derived from the offset formula."""
	var tick: int
	var absolute_day: int
	var year: int
	var season: int
	var season_day: int
	var hour: int
	var minute: int
	var tick_of_day: int

	func _init(p_tick: int = 0) -> void:
		"""Decode a tick index into calendar fields using `(tick + 4500) mod 18000`."""
		set_tick(p_tick)

	func set_tick(p_tick: int) -> void:
		"""Re-decode this instance in place for another tick, overwriting every field.

		Every field is rewritten, so a reused instance can carry nothing over from its previous
		tick. Only call this on an instance you own; see calendar_into().
		"""
		tick = p_tick
		var time: int = p_tick + CALENDAR_OFFSET_TICKS
		var day_zero: int = time / TICKS_PER_DAY
		tick_of_day = time % TICKS_PER_DAY
		absolute_day = day_zero + 1
		year = day_zero / DAYS_PER_YEAR + 1
		season = (day_zero % DAYS_PER_YEAR) / DAYS_PER_SEASON
		season_day = day_zero % DAYS_PER_SEASON + 1
		hour = tick_of_day / TICKS_PER_HOUR
		minute = (tick_of_day % TICKS_PER_HOUR) * MINUTES_PER_HOUR / TICKS_PER_HOUR

	func season_name() -> String:
		"""Display name of this instant's season."""
		return SEASON_NAMES[season]

	func clock_text() -> String:
		"""Zero-padded HH:MM for the HUD."""
		return "%02d:%02d" % [hour, minute]


# --- speed and pause state -----------------------------------------------------------------------

func set_speed(value: int) -> bool:
	"""Request 1x, 2x or 4x. Rejects 3x and every other value, leaving state untouched.

	Returns false without mutating anything on a rejected value. SPEED_PAUSED is not
	requestable: pause is authoritative through the reason mask, so a caller asking for 0
	must name a reason via set_pause(). Speed changes never clear a pause reason.

	This is the IMMEDIATE setter. `scheduler_events.gd`'s boundary pump calls it when it applies
	an admitted SET_REQUESTED_SPEED, so a queued speed change lands here too (blocker U2 closed
	in process, decision 0054); persistence of a pending queue is still blocked on task 09.
	"""
	if not SELECTABLE_SPEEDS.has(value):
		_last_error = "speed %d is not one of 1, 2, 4" % value
		return false
	_requested_speed = value
	return true


func set_pause(reason: int, enabled: bool) -> bool:
	"""Set or clear exactly one pause reason. Returns false on an unknown or composite reason.

	Reasons are independent bits, so two reasons require two releases. Pausing for PLAYER
	discards sub-tick presentation debt ONLY when zero whole ticks are owed, which
	ARCH-CLOCK-002 permits by name; that discard is counted (blocker U3).

	This is the IMMEDIATE setter. `scheduler_events.gd`'s boundary pump calls it when it applies
	an admitted SET_PAUSE_REASON, so a queued pause lands here too (blocker U2 closed in process,
	decision 0054); persistence of a pending queue is still blocked on task 09.
	"""
	if not ALL_PAUSE_REASONS.has(reason):
		_last_error = "pause reason %d is not a single known reason" % reason
		return false
	if not enabled:
		_pause_mask &= ~reason
		return true
	_pause_mask |= reason
	if reason == PLAYER and _debt > 0 and _debt < TICK_COST:
		_debt = 0
		_subtick_debt_discards += 1
	return true


func effective_speed() -> int:
	"""Requested speed, or SPEED_PAUSED while any pause reason is held (REQ-SET-004)."""
	return SPEED_PAUSED if _pause_mask != 0 else _requested_speed


func requested_speed() -> int:
	"""Speed the player asked for, which survives pauses unchanged."""
	return _requested_speed


func is_paused() -> bool:
	"""True while at least one pause reason is held."""
	return _pause_mask != 0


func pause_mask() -> int:
	"""Raw composed pause bitmask."""
	return _pause_mask


func has_pause_reason(reason: int) -> bool:
	"""True when the given single reason is currently held."""
	return _pause_mask & reason != 0


func pause_reason_names() -> Array[String]:
	"""Held pause reasons as display names, for the HUD's pause indicator."""
	var names: Array[String] = []
	for index: int in ALL_PAUSE_REASONS.size():
		if _pause_mask & ALL_PAUSE_REASONS[index] != 0:
			names.append(PAUSE_REASON_NAMES[index])
	return names


# --- scheduler -----------------------------------------------------------------------------------

func advance(elapsed_microseconds: int, step: Callable = Callable(), day_boundary: Callable = Callable(),
		before_tick: Callable = Callable(), on_overload: Callable = Callable()) -> int:
	"""Fold one host frame of elapsed time into debt and drain whole ticks. Returns ticks run.

	`step` runs once per completed tick; `day_boundary` runs once per crossing of the offset
	calendar into 00:00, receiving that day's Calendar (REQ-SET-007 ordering is the callee's).
	Paused host time contributes no debt. A negative or overflowing input is refused with
	last_error() set and no state change, rather than wrapping.

	`before_tick` is ARCH-CMD-002's scheduler barrier: R07-SCHED-001 runs it BEFORE each decision
	about whether another tick may start, so a pause admitted during tick 3 stops tick 4.
	`on_overload` replaces the immediate ladder step with the caller's own handling, which
	`scheduler_events.gd` uses to carry the rung through that same barrier. BOTH DEFAULT TO
	INVALID, and with them invalid this function behaves exactly as it did before they existed.
	"""
	_last_error = ""
	var speed: int = effective_speed()
	if speed == SPEED_PAUSED:
		return 0
	if not _accumulate_debt(elapsed_microseconds, speed):
		return 0
	var count: int = _drain_ticks(step, day_boundary, before_tick)
	if _pause_mask == 0 and _is_overloaded(speed):
		_dispatch_overload(on_overload)
	return count


func _dispatch_overload(on_overload: Callable) -> void:
	"""Take one ladder step, or hand the decision to a scheduler queue that will carry it."""
	if on_overload.is_valid():
		on_overload.call()
		return
	apply_overload()


func apply_overload() -> void:
	"""Step the REQ-SET-008 ladder once: 4x to 2x, 2x to 1x, then a diagnostic pause at 1x.

	Debt is retained untouched in every branch: the ladder slows or stops the clock, it never
	skips owed ticks (ARCH-CLOCK-001, blocker U3). No automatic speed increase ever occurs.
	State is applied before the diagnostic is recorded, so a signal handler reading
	requested_speed() or is_paused() sees the rung that has already landed.
	"""
	var target: int = overload_ladder_target()
	apply_overload_target(target)
	note_overload_step(target)


func overload_ladder_target() -> int:
	"""The next REQ-SET-008 rung from the current requested speed, without applying it.

	SPEED_PAUSED is the answer at 1x and means "hold CRITICAL with a diagnostic", which is the
	only rung that is not a speed. A scheduler that queues the rung asks this first.
	"""
	if _requested_speed == SPEED_QUADRUPLE:
		return SPEED_DOUBLE
	if _requested_speed == SPEED_DOUBLE:
		return SPEED_NORMAL
	return SPEED_PAUSED


func apply_overload_target(target: int) -> void:
	"""Apply one already-chosen rung's authoritative state change and nothing else.

	Debt is untouched here as in every other ladder path. Called directly by apply_overload(); a
	scheduler queue instead reaches this state through an ordinary drained speed or pause event.
	"""
	if target == SPEED_PAUSED:
		_pause_mask |= CRITICAL
		return
	_requested_speed = target


func note_overload_step(target: int) -> void:
	"""Record one ladder step's counters and emit its UI signal. Changes no authoritative state.

	Split out so a scheduler that defers the rung to its next barrier still keeps fallback_count(),
	diagnostic_pause_count() and last_diagnostic() -- the evidence task 02 recorded under blocker
	U3 -- rather than silently retiring them.
	"""
	_fallback_count += 1
	if target == SPEED_PAUSED:
		_diagnostic_pause_count += 1
		_last_diagnostic = "Simulation overloaded at 1x: %d whole tick(s) owed; paused rather than skipping." % owed_ticks()
		clock_diagnostic_pause.emit(_last_diagnostic)
		return
	_last_diagnostic = "Simulation overloaded: speed reduced to %dx; %d whole tick(s) owed." % [target, owed_ticks()]
	clock_overload_warning.emit(target)


func acknowledge_without_catchup() -> int:
	"""Explicit player recovery: clear scheduler debt and the CRITICAL pause. Returns ticks dropped.

	Blocker U3, conservative rule: this is the ONLY path that drops whole owed ticks, it is
	never called implicitly, and every call is recorded in acknowledged_catchup_resets() with
	the dropped total in acknowledged_ticks_discarded() (ARCH-CLOCK-002 "record this scheduler
	event"). Completed state never rewinds or advances: _completed_tick is untouched.
	"""
	var discarded: int = _debt / TICK_COST
	_debt = 0
	_acknowledged_catchup_resets += 1
	_acknowledged_ticks_discarded += discarded
	_pause_mask &= ~CRITICAL
	_last_diagnostic = ""
	return discarded


func _accumulate_debt(elapsed_microseconds: int, speed: int) -> bool:
	"""Add `elapsed_microseconds * 30 * speed` debt units. False (state unchanged) on refusal."""
	if elapsed_microseconds < 0:
		_last_error = "elapsed_microseconds must be nonnegative"
		return false
	if not IntMathScript.checked_mul_into(elapsed_microseconds, TICKS_PER_SECOND * speed, _math):
		_last_error = _math.error
		return false
	var rate: int = _math.value
	if not IntMathScript.checked_add_into(_debt, rate, _math):
		_last_error = _math.error
		return false
	_debt = _math.value
	return true


func _drain_ticks(step: Callable, day_boundary: Callable, before_tick: Callable) -> int:
	"""Run at most MAX_TICKS_PER_FRAME whole ticks, stopping the moment a pause reason appears.

	`before_tick` runs BEFORE each decision, including the first, which is where ARCH-CMD-002's
	scheduler events drain; the mask is then re-tested, so a pause that arrived either inside
	`step` or through that barrier takes effect before another tick starts. Undrained debt stays
	owed.
	"""
	var count: int = 0
	var running: bool = true
	while running:
		if before_tick.is_valid():
			before_tick.call()
		running = _debt >= TICK_COST and count < MAX_TICKS_PER_FRAME and _pause_mask == 0
		if not running:
			continue
		_debt -= TICK_COST
		if step.is_valid():
			step.call()
		_completed_tick += 1
		count += 1
		if is_day_boundary(_completed_tick):
			_notify_day_boundary(day_boundary)
	return count


func _notify_day_boundary(day_boundary: Callable) -> void:
	"""Record and dispatch one 00:00 crossing of the offset calendar (REQ-SET-007).

	This Calendar is deliberately fresh rather than a reused instance: it escapes into a caller
	supplied callback that may keep it, and one crossing per simulated day is not a hot path.
	"""
	_day_boundaries_crossed += 1
	var moment: Calendar = Calendar.new(_completed_tick)
	if day_boundary.is_valid():
		day_boundary.call(moment)
	clock_day_boundary.emit(moment.absolute_day)


func _is_overloaded(speed: int) -> bool:
	"""True when backlog exceeds 1/4 real second, compared without division (ARCH-CLOCK-001)."""
	if not IntMathScript.checked_mul_into(OVERLOAD_NUMERATOR, _debt, _math):
		return true
	return _math.value > DEBT_PER_REAL_SECOND * speed


# --- observable scheduler state ------------------------------------------------------------------

func completed_tick() -> int:
	"""Number of ticks completed, which is also the current authoritative tick index."""
	return _completed_tick


func debt() -> int:
	"""Retained scheduler debt in tick-cost units."""
	return _debt


func owed_ticks() -> int:
	"""Whole ticks currently owed and not yet run."""
	return _debt / TICK_COST


func fallback_count() -> int:
	"""Times the overload ladder has stepped, including the diagnostic pause step."""
	return _fallback_count


func diagnostic_pause_count() -> int:
	"""Times overload at 1x has paused with a diagnostic rather than skipping ticks."""
	return _diagnostic_pause_count


func acknowledged_catchup_resets() -> int:
	"""Blocker U3 counter: explicit resume-without-catch-up acknowledgements."""
	return _acknowledged_catchup_resets


func acknowledged_ticks_discarded() -> int:
	"""Blocker U3 counter: whole owed ticks dropped by those explicit acknowledgements."""
	return _acknowledged_ticks_discarded


func subtick_debt_discards() -> int:
	"""Blocker U3 counter: player pauses that dropped sub-tick presentation debt only."""
	return _subtick_debt_discards


func day_boundaries_crossed() -> int:
	"""Offset-calendar 00:00 crossings observed since construction."""
	return _day_boundaries_crossed


func last_diagnostic() -> String:
	"""Most recent overload warning or diagnostic-pause message; empty when none stands."""
	return _last_diagnostic


func last_error() -> String:
	"""Reason the most recent refused call was refused; empty after a successful call."""
	return _last_error


# --- calendar ------------------------------------------------------------------------------------

func calendar() -> Calendar:
	"""Decoded calendar instant at the current completed tick, as a freshly allocated Calendar."""
	return Calendar.new(_completed_tick)


func calendar_into(out: Calendar) -> void:
	"""Non-allocating calendar(): re-decode the current completed tick into a Calendar you own.

	For a HUD that polls the clock every frame. `out` must be an instance the caller owns and
	no one else holds, because every field is overwritten; this clock keeps no reference to it
	and never hands the same instance to two callers.
	"""
	out.set_tick(_completed_tick)


static func calendar_at(tick: int) -> Calendar:
	"""Decoded calendar instant at an arbitrary nonnegative tick index."""
	return Calendar.new(tick)


static func calendar_at_into(tick: int, out: Calendar) -> void:
	"""Non-allocating calendar_at(): re-decode an arbitrary tick into a Calendar you own."""
	out.set_tick(tick)


static func day_index_at(tick: int) -> int:
	"""Zero-based day number of a tick under the offset calendar."""
	return (tick + CALENDAR_OFFSET_TICKS) / TICKS_PER_DAY


static func is_day_boundary(tick: int) -> bool:
	"""True when this tick is the first of a new day under `(tick + 4500) mod 18000`.

	This is a crossing of the OFFSET calendar, not `tick mod 18000 == 0`: tick 13500 is the
	first midnight and is a boundary, while tick 18000 is 06:00 of day 2 and is not. Tick 0
	is 06:00 of day 1 and starts no new day.
	"""
	return tick > 0 and (tick + CALENDAR_OFFSET_TICKS) % TICKS_PER_DAY == 0
