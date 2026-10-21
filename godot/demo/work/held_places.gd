extends RefCounted
## HELD PLACES (decision 1905; Brendan's rulings of 2026-10-12, "Trip doesn't wait", "Player's order holds" and "Only in
## working hours"): the one rule the fishery's boat seats, the forage party's seats and the ferry's crew place share
## when a trip is ready to leave but a place in it is held for a worker who is away.
##
## Each owner records, per job row, the KEEPER: the resident `called_away` let keep the job (and clears it when anyone
## claims the job, or the row is opened afresh). Only that resident's KEPT entry is ever released, and only through
## `forget_kept` -- so a place the player queued for someone (Shift+right-click, `work_board.queue_task`) is never
## touched: it waits for her (the player can always Reassign it). And it is released only in WORKING HOURS -- the
## demo's day, outside the night routine's night (night_routine.gd `is_night_hour`: from DUSK_HOUR 20:00 to DAWN_HOUR
## 06:00) -- while others are up and could fill it; overnight it stays hers. O(1): no brain is looked at for a place
## nobody kept. Presentation only.

const NightScript := preload("res://demo/burrow/night_routine.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1


static func working_hours(calendar: CalendarScript) -> bool:
	"""Whether it is the demo's day now (not the night routine's night; no calendar: always)."""
	if calendar == null:
		return true
	return not NightScript.is_night_hour(posmod(calendar.hour_index(), SimClock.HOURS_PER_DAY))


static func may_release(keeper: int, calendar: CalendarScript) -> bool:
	"""Whether a place kept by `keeper` (NONE: nobody kept it) may be given up now: someone kept it, in working hours."""
	return keeper != NONE and working_hours(calendar)


static func release(brain: BrainScript, task_source: int, task_key: int) -> bool:
	"""Give up the place `brain` kept: its KEPT entry naming that task goes (a queued one stays). Whether one went."""
	return brain.forget_kept(task_source, task_key)


static func try_release(keeper: int, calendar: CalendarScript, owner: Object, task_source: int, task_key: int) -> bool:
	"""TRIP DOESN'T WAIT's one step, shared by every owner: when a place kept by `keeper` may be given up now
	(`may_release`), the keeper's brain (the owner's `brain_of`) gives it up (`release`). Whether the owner should clear
	its keeper column: true exactly when the place was released."""
	if not may_release(keeper, calendar):
		return false
	release(owner.call(&"brain_of", keeper) as BrainScript, task_source, task_key)
	return true


static func hand_over(keeper: int, owner: Object, task_source: int, task_key: int) -> void:
	"""A kept job claimed by anyone: the old keeper (NONE: nobody kept it) keeps it no longer -- her kept entry goes, as
	the board's Reassign does (her own take-back has popped it already) -- else her promise would outlive the owner's
	keeper column and hold the trip. The owner then clears that column."""
	if keeper != NONE:
		release(owner.call(&"brain_of", keeper) as BrainScript, task_source, task_key)
