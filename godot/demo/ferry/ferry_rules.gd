extends RefCounted
## THE FERRY's numbers (decision 0437; review ECO-041, water part B lane 3). Every value is cited or named a DEMO value;
## pure constants and static functions, so the suite checks them without a scene.
##
## THE TIMETABLE (ECO-041: "a staffed timetable, a departure threshold"). The ferry departs from the ferry stage at
## the scheduled hours, 06:00 to 18:00 every EVERY_HOURS game hours (the demo's working day: decision 0421 puts the
## night at 20:00), when there is anything to carry -- cargo at either stage, or a passenger waiting -- and a crew
## (a helm, FISH >= 1: decision 0432's boat rule, LORE-P12: never a species) takes the crossing. Between them it
## departs at once when the far stage's stack reaches THRESHOLD_MILLI (a full hauler's load and more). A crossing is a
## round trip: out to the far stage and back, the boat given back to the boathouse rows between crossings.
##
## CARGO FIRST (ECO-041). The far bank's work is the FAR COPSE's windfall (THE FAR COPSE below): gathered, carried to
## the far stage's stack by the gatherer, loaded aboard by the crew (HANDLE_MWU_PER_U), rowed across, unloaded onto
## the ferry stage's stack, and carried to the village's log stack by a hauler (HAUL_LOAD_MILLI a trip) -- the one
## stores' wood. Passengers ride in the boat's second seat (one a crossing), cargo or none.
##
## CLOSURE (ECO-041: "weather closure"). A storm (§5.10's heavy rain: REQ-SET-052, "If a boat faces a storm ... prevent
## departure and preserve its queued order"), a hard freeze (REQ-SET-144), the tunnels' flood on the stream, or ice on
## the pond (its route crosses the pond's north-east lobe) close the ferry. Closed, no crossing departs and no passenger
## boards; a crossing already under way finishes the leg it is on and then holds (MOVE-REQ-007: a crossing entered is
## finished) -- at the far stage it waits there, its crew ashore, until the ferry opens again.
##
## THE FAR COPSE (DEMO, decision 0437). A windfall woodlot at the east woods' edge on the stream's far bank, between the
## ford and the pond: by land the village reaches it only over the ford (wading) or a bridge upstream, the far stage a
## few metres off. Its windfall follows the woods' own deadfall numbers
## (forest_rules.gd: 1.0..2.0 U a pile in 0.25 U steps, gathered at 20 WU a U) on its own fixed spots -- separate from
## the woods' deadfall rows, so no wood is counted twice -- one pile a day at midnight and two lying when the village
## opens. It is the ferry's reason: gathered wood rowed across is the stores' wood.

const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")

## The timetable (DEMO): departures from 06:00 to 18:00, every two game hours.
const FIRST_DEPARTURE_HOUR: int = 6
const LAST_DEPARTURE_HOUR: int = 18
const EVERY_HOURS: int = 2
## The departure threshold (DEMO): the far stage's stack at this or more departs a crossing at once (by day).
const THRESHOLD_MILLI: int = 4000
## What one crossing carries (DEMO: two haulers' loads of 6 U) and how many passengers (the boat's second seat).
const BOAT_CARGO_MILLI: int = 12000
const PASSENGER_SEAT: int = 1
## Loading and unloading (DEMO: the farm's and the kitchen's 1 WU a handling, a unit at a time).
const HANDLE_MWU_PER_U: int = 1000
## A hauler's load from the ferry stage to the log stack: the woods' (forest_rules.gd CARRY_LOAD_MILLI, 6 U).
const HAUL_LOAD_MILLI: int = ForestRules.CARRY_LOAD_MILLI
## Gathering windfall: the woods' deadfall rate (20 WU a U) and its pile sizes.
const GATHER_WU_PER_U: int = ForestRules.DEADFALL_WU_PER_U
const PILE_MIN_MILLI: int = ForestRules.DEADFALL_MIN_MILLI
const PILE_MAX_MILLI: int = ForestRules.DEADFALL_MAX_MILLI
const PILE_STEP_MILLI: int = ForestRules.DEADFALL_STEP_MILLI
## The far copse's spots (m; snapped to standable ground at configure), one pile at most on each, on the stream's far
## bank north of the far stage. Two lie when the village opens; one falls each midnight.
const COPSE_SPOTS: Array[Vector2] = [Vector2(33.2, 16.8), Vector2(35.2, 15.4), Vector2(34.0, 13.2), Vector2(31.8, 11.8),
	Vector2(34.6, 9.8), Vector2(32.6, 8.4)]
const COPSE_OPENING: Array[int] = [1500, 1250]
const COPSE_NAME: String = "the far copse"
## The stacks beside each stage's land end, inland (m, before snapping), and the village's log stack is the woods' own.
const NEAR_STACK_AT: Vector2 = Vector2(22.4, 14.2)
const FAR_STACK_AT: Vector2 = Vector2(34.6, 20.2)
## Where a passenger waits by a stage, inland of its land end (m, before snapping).
const NEAR_WAIT_AT: Vector2 = Vector2(22.3, 15.9)
const FAR_WAIT_AT: Vector2 = Vector2(35.0, 21.6)
## Walking a stage's deck (the fishery's DECK_WALK_M_S, 0.6 m/s: a careful walk), in mm a second for the boat row's
## ride (decision 1821) and in m/s for the walk drawn.
const DECK_WALK_MM_S: int = 600
const DECK_WALK_M_S: float = DECK_WALK_MM_S * 0.001
## A passenger is offered the ferry only when its wait for a boarding is at most this (game hours, as ticks): a longer
## wait is no crossing to plan for (the router plans round by land instead).
const MAX_WAIT_HOURS: int = 2
const MAX_WAIT_TICKS: int = MAX_WAIT_HOURS * SimClock.TICKS_PER_HOUR
## A refused crew stands down and the crossing is looked at again after this (demo microseconds; the fishery's
## RECHECK_USEC).
const RECHECK_USEC: int = 5000000
## A worker that could not get to its place tries again after this, at most MAX_TRIES times (the fishery's).
const RETRY_USEC: int = 3000000
const MAX_TRIES: int = 3

## Why the ferry is closed (OPEN: it is not).
const OPEN: int = 0
const CLOSED_STORM: int = 1
const CLOSED_FREEZE: int = 2
const CLOSED_FLOOD: int = 3
const CLOSED_ICE: int = 4
const CLOSED_WORDS: Array[String] = ["open", "a storm", "a hard freeze", "the stream in flood", "ice on the pond"]


static func departure_tick_at_or_after(at_tick: int) -> int:
	"""The first scheduled departure at or after `at_tick`: an hour crossing at FIRST_DEPARTURE_HOUR..LAST_DEPARTURE_HOUR
	of a day, every EVERY_HOURS (exact ticks on the offset calendar)."""
	var hour_index: int = CalendarScript.hour_index_at(at_tick)
	var start: int = hour_tick(hour_index)
	if start < at_tick:
		hour_index += 1
	while not is_departure_hour(posmod(hour_index, SimClock.HOURS_PER_DAY)):
		hour_index += 1
	return hour_tick(hour_index)


static func hour_tick(hour_index: int) -> int:
	"""The tick an hour index begins at (CalendarScript.hour_index_at's inverse)."""
	return hour_index * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


static func is_departure_hour(hour: int) -> bool:
	"""Whether `hour` of the day is a scheduled departure."""
	return hour >= FIRST_DEPARTURE_HOUR and hour <= LAST_DEPARTURE_HOUR \
		and (hour - FIRST_DEPARTURE_HOUR) % EVERY_HOURS == 0


static func is_day_hour(hour: int) -> bool:
	"""Whether the ferry works at `hour` of the day (from its first departure to an hour past its last)."""
	return hour >= FIRST_DEPARTURE_HOUR and hour <= LAST_DEPARTURE_HOUR + 1


static func pile_milli(day: int) -> int:
	"""The day's windfall pile (the woods' 1.0..2.0 U in 0.25 U steps), a fixed function of the day: no generator."""
	@warning_ignore("integer_division") var steps: int = (PILE_MAX_MILLI - PILE_MIN_MILLI) / PILE_STEP_MILLI
	return PILE_MIN_MILLI + posmod(day * 3, steps + 1) * PILE_STEP_MILLI


static func handle_mwu(milli: int) -> int:
	"""Milli-WU to load or unload `milli` of cargo (HANDLE_MWU_PER_U a unit, part units in proportion, at least 1 WU)."""
	@warning_ignore("integer_division") var mwu: int = milli * HANDLE_MWU_PER_U / 1000
	return maxi(mwu, HANDLE_MWU_PER_U)


static func gather_mwu(milli: int) -> int:
	"""Milli-WU to gather a pile of `milli` (GATHER_WU_PER_U a unit)."""
	return milli * GATHER_WU_PER_U


static func row_seconds(length_u: int) -> float:
	"""Demo seconds the ferry boat takes to row `length_u` (boat_fleet.gd ROW_SPEED_U_S, at its ordinary pace)."""
	return float(length_u) / float(FleetScript.ROW_SPEED_U_S)
