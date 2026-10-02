extends RefCounted
## "RUN UNTIL...": run the village at the chosen speed, then pause with a reason when something real happens.
## Decision 0471 (review UX-022). Presentation only: every predicate READS a system the demo already runs, and the
## pause is the player's own (pause_ledger.gd `pause_player`, with the arrival as its note).
##
## THE TARGETS (TARGET_*), and what each reads:
##   * DAWN, DUSK -- the demo calendar (demo_calendar.gd) reaching the night routine's own hours
##     (night_routine.gd DAWN_HOUR 06:00, DUSK_HOUR 20:00), strictly after now.
##   * NEXT MEAL  -- the calendar reaching the next meal call (meal_rules.gd CALL_HOUR: breakfast 07:00, supper
##     17:00), the hour the kitchen itself calls it.
##   * PROJECT    -- a selected project's own completion: the tunnel being dug, the room, or the bridge being built
##     (the host hands a `state() -> PROJECT_*` watch over underground_graph.gd, underground_rooms.gd, bridges.gd).
##     A project removed before it is done ends the run (END_GONE).
##   * HARVEST    -- a bed coming RIPE that was not ripe when the run began (farm_sim.gd STAGE_RIPE): the next
##     harvest window opening. Offered only while something grows toward one.
##   * WARNING    -- a new warning line in the notice feed, not of a snoozed kind, or a new or recurring incident
##     (demo_notices.gd, demo_incidents.gd; decision 0591: a line the toast budget held back still counts).
##
## EXACT ON THE CALENDAR. The three calendar targets know their tick in advance, so the run caps the demo clock's next
## frame (`usec_limit` -> demo_clock.gd `limit_usec`) at exactly the demo time that brings the calendar to it: under
## the ten-minute day (decision 0421) "Run until dawn" stops at 06:00 to the tick, at 1x, 2x or 4x, however the frames
## are cut. The event targets stop on the frame their system reports the change.
##
## ENDING. A predicate firing ends it REACHED (the host pauses with `end_text`). The host ends it otherwise:
## any pause before arrival (END_PAUSED: the player, a menu, a planning pause, a stall), a critical event
## (END_CRITICAL), the player's Stop (END_STOPPED), a removed project (END_GONE). Integer throughout.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")

const TARGET_DAWN: int = 0
const TARGET_DUSK: int = 1
const TARGET_MEAL: int = 2
const TARGET_PROJECT: int = 3
const TARGET_HARVEST: int = 4
const TARGET_WARNING: int = 5
const TARGET_COUNT: int = 6
const NO_TARGET: int = -1
const TARGET_TITLES: Array[String] = ["Dawn", "Dusk", "Next meal", "Project done", "Harvest window", "Next warning"]
## What the run is "until", in a sentence ("Run until dawn").
const TARGET_WORDS: Array[String] = ["dawn", "dusk", "the next meal", "%s is done", "the next harvest window",
	"the next warning or incident"]

const PROJECT_UNFINISHED: int = 0
const PROJECT_DONE: int = 1
const PROJECT_GONE: int = 2

const END_NONE: int = 0
const END_REACHED: int = 1
const END_PAUSED: int = 2
const END_CRITICAL: int = 3
const END_STOPPED: int = 4
const END_GONE: int = 5

const NO_PROJECT: String = "Select a tunnel, room or bridge being built first"
const NOTHING_GROWING: String = "Nothing is growing toward a harvest"
const REACHED: String = "Reached %s: %s"
const CANCELLED: String = "Run until %s cancelled: %s"

var calendar: CalendarScript = null
## `() -> int`: a bit per farm bed that is ripe now. `() -> bool`: whether anything grows toward a harvest.
var ripe_mask: Callable = Callable()
var growing: Callable = Callable()
## `() -> int`: warnings and incidents raised so far (only ever counts up).
var warnings: Callable = Callable()

## The target running (NO_TARGET: idle), its calendar tick (-1 for an event target).
var target: int = NO_TARGET
var target_tick: int = -1
## How the last run ended (END_*), in words, and the calendar tick it ended on.
var ended: int = END_NONE
var end_text: String = ""
var ended_tick: int = -1

var _project_name: String = ""
var _project_state: Callable = Callable()
var _ripe_seen: int = 0
var _warnings_seen: int = 0


# --- the calendar targets ---------------------------------------------------------------------------------

static func next_hour_tick(now_tick: int, hour: int) -> int:
	"""The first tick strictly after `now_tick` at which the offset calendar reads `hour`:00."""
	var into_day: int = posmod(now_tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_DAY)
	var ahead: int = posmod(hour * SimClock.TICKS_PER_HOUR - into_day, SimClock.TICKS_PER_DAY)
	return now_tick + (ahead if ahead > 0 else SimClock.TICKS_PER_DAY)


static func next_meal_tick(now_tick: int) -> int:
	"""The next meal call after `now_tick` (the earlier of breakfast's and supper's)."""
	var best: int = -1
	for meal: int in MealRules.CALL_HOUR.size():
		var at: int = next_hour_tick(now_tick, MealRules.CALL_HOUR[meal])
		if best < 0 or at < best:
			best = at
	return best


static func usec_to_tick(at: CalendarScript, wanted_tick: int) -> int:
	"""The fewest demo microseconds that bring calendar `at` to `wanted_tick` exactly (0: there already)."""
	var needed: int = wanted_tick - at.tick
	if needed <= 0:
		return 0
	var scaled: int = needed * CalendarScript.HOUR_USEC - at.remainder()
	@warning_ignore("integer_division") return (scaled + SimClock.TICKS_PER_HOUR - 1) / SimClock.TICKS_PER_HOUR


func tick_for(which: int) -> int:
	"""Calendar target `which`'s tick from now (-1: an event target, or no calendar)."""
	if calendar == null:
		return -1
	match which:
		TARGET_DAWN:
			return next_hour_tick(calendar.tick, NightScript.DAWN_HOUR)
		TARGET_DUSK:
			return next_hour_tick(calendar.tick, NightScript.DUSK_HOUR)
		TARGET_MEAL:
			return next_meal_tick(calendar.tick)
	return -1


# --- availability -------------------------------------------------------------------------------------------

func set_project(title: String, state: Callable) -> void:
	"""The selected project, and its watch `state() -> PROJECT_*` (an invalid Callable: none selected)."""
	_project_name = title
	_project_state = state


func project_name() -> String:
	"""The selected project's name ("" when none)."""
	return _project_name if _project_state.is_valid() else ""


func refusal(which: int) -> String:
	"""Why target `which` cannot be run to now ("" when it can)."""
	match which:
		TARGET_DAWN, TARGET_DUSK, TARGET_MEAL:
			return "" if calendar != null else "No calendar"
		TARGET_PROJECT:
			return "" if _project_state.is_valid() and int(_project_state.call()) == PROJECT_UNFINISHED else NO_PROJECT
		TARGET_HARVEST:
			return "" if growing.is_valid() and bool(growing.call()) else NOTHING_GROWING
		TARGET_WARNING:
			return "" if warnings.is_valid() else "No notice feed"
	return "No such target"


func words(which: int) -> String:
	"""What target `which` runs until, in words ("dawn", "Tunnel 3 is done")."""
	if which < 0 or which >= TARGET_COUNT:
		return ""
	return TARGET_WORDS[which] % _project_name if which == TARGET_PROJECT else TARGET_WORDS[which]


# --- running ------------------------------------------------------------------------------------------------

func start(which: int) -> bool:
	"""Begin running until `which` (refused, nothing changed, when it is not available now)."""
	if which < 0 or which >= TARGET_COUNT or not refusal(which).is_empty():
		return false
	target = which
	target_tick = tick_for(which)
	ended = END_NONE
	end_text = ""
	ended_tick = -1
	_ripe_seen = int(ripe_mask.call()) if ripe_mask.is_valid() else 0
	_warnings_seen = int(warnings.call()) if warnings.is_valid() else 0
	return true


func is_running() -> bool:
	"""Whether a run is under way."""
	return target != NO_TARGET


func usec_limit() -> int:
	"""The most demo time the next frame may pass so the calendar lands on the target exactly (-1: no limit)."""
	if not is_running() or target_tick < 0 or calendar == null:
		return -1
	return usec_to_tick(calendar, target_tick)


func check() -> bool:
	"""Once a frame, after the village has advanced: true (and the run ended REACHED) when the target arrived. A
	removed project ends the run END_GONE (false)."""
	if not is_running():
		return false
	match target:
		TARGET_DAWN, TARGET_DUSK, TARGET_MEAL:
			return _arrive_if(calendar != null and calendar.tick >= target_tick)
		TARGET_PROJECT:
			return _check_project()
		TARGET_HARVEST:
			return _arrive_if(_newly_ripe() != 0)
		TARGET_WARNING:
			return _arrive_if(warnings.is_valid() and int(warnings.call()) > _warnings_seen)
	return false


func _check_project() -> bool:
	"""The project's watch: done arrives; gone ends the run."""
	var state: int = int(_project_state.call()) if _project_state.is_valid() else PROJECT_GONE
	if state == PROJECT_GONE:
		cancel(END_GONE, "the project was removed")
		return false
	return _arrive_if(state == PROJECT_DONE)


func _newly_ripe() -> int:
	"""Beds ripe now that were not at the last look (a bed harvested and ripening again counts once more)."""
	var now: int = int(ripe_mask.call()) if ripe_mask.is_valid() else 0
	var fresh: int = now & ~_ripe_seen
	_ripe_seen = now
	return fresh


func _arrive_if(arrived: bool) -> bool:
	"""End the run REACHED, dated, when `arrived`."""
	if not arrived:
		return false
	end_text = REACHED % [words(target), date_at(calendar.tick) if calendar != null else ""]
	_finish(END_REACHED)
	return true


func cancel(why_end: int, why: String) -> void:
	"""End a run before arrival (END_PAUSED, END_CRITICAL, END_STOPPED, END_GONE), saying why."""
	if not is_running():
		return
	end_text = CANCELLED % [words(target), why]
	_finish(why_end)


func _finish(how: int) -> void:
	"""The run is over."""
	ended = how
	ended_tick = calendar.tick if calendar != null else -1
	target = NO_TARGET
	target_tick = -1


# --- words --------------------------------------------------------------------------------------------------

static func date_at(at_tick: int) -> String:
	"""'Y1 Spring 2, 06:00' for any tick (the demo's own date form, demo_calendar.gd `date_text`)."""
	var at := SimClock.Calendar.new(at_tick)
	return "Y%d %s, %02d:%02d" % [at.year, CalendarScript.day_text(at.season, at.season_day), at.hour, at.minute]


static func span_text(ticks: int) -> String:
	"""Game time in words: 'in 3 h 20 min', 'in 45 min' (750 ticks an hour, 12.5 a minute)."""
	@warning_ignore("integer_division") var minutes: int = ticks * SimClock.MINUTES_PER_HOUR / SimClock.TICKS_PER_HOUR
	if minutes >= SimClock.MINUTES_PER_HOUR:
		@warning_ignore("integer_division") return "in %d h %d min" % [minutes / SimClock.MINUTES_PER_HOUR, minutes % SimClock.MINUTES_PER_HOUR]
	return "in %d min" % minutes


func preview(which: int, speed: int) -> String:
	"""A target's line in the menu: 'Dawn: 06:00, in 3 h 20 min (about 50 s at 4x)' for a calendar target, its
	refusal when it is not available, else what it waits for."""
	var why: String = refusal(which)
	if not why.is_empty():
		return "%s: %s" % [TARGET_TITLES[which], why]
	var at: int = tick_for(which)
	if at < 0:
		return "%s: %s" % [TARGET_TITLES[which], "when %s" % words(which) if which == TARGET_PROJECT
			else "whenever it comes"]
	@warning_ignore("integer_division") var real_s: int = usec_to_tick(calendar, at) / maxi(speed, 1) / 1000000
	var at_calendar := SimClock.Calendar.new(at)
	@warning_ignore("integer_division") return "%s: %02d:00, %s (about %d min %d s at %dx)" % [TARGET_TITLES[which], at_calendar.hour,
		span_text(at - calendar.tick), real_s / 60, real_s % 60, maxi(speed, 1)]
