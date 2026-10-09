extends RefCounted
## CATCH PLANS AND COLLECTION: which fish a trip takes, and when a soaked trap is lifted. Decision 1712 (the fishing
## revamp, #49; review ECO-024 and ECO-026). Pure functions over the fishing driver; nothing here writes into the
## settlement simulation.
##
## A CATCH PLAN (review ECO-024: "a small planning choice", two profiles). CHOSEN FISH is the player's species: §5.4's
## "A gear cycle targets one selected eligible species", and REQ-SET-046's block -- closed at the water, the trip waits
## with the reopening day. BEST CATCH is §5.4's AUTO MODE: "auto mode chooses highest `predicted_NP/work`, then earliest
## closure, then species ID", and REQ-SET-046's "select a legal fallback species only when auto mode is enabled": the
## species is chosen again at the water, so one that closed on the way is replaced by the best legal one.
## `predicted_NP` is the cycle's expected catch (fishing.gd's own `catch_milli`) at §5.7's fish row, "All fish species
## except mussel | 1400" NP a unit; `work` is the gear's §5.4 work. A trip's gear is fixed, so within one trip the work
## is equal and the comparison is the products cross-multiplied, in integers. "Earliest closure" is the fewest days to
## the species' next §5.4 closure window (fishing_driver.gd `days_to_closure`); "species ID" is §5.4's table row.
##
## COLLECTION (review ECO-026: "scheduled morning run ... collect before a warned closure"). WHEN SOAKED, the default,
## puts a trap's collection on the board as soon as its 6 h soak is done (§5.4). MORNING RUN keeps a soaked trap in the
## water until the morning window (PROVISIONAL: DAWN_HOUR 06:00 to 10:00, demo/burrow/night_routine.gd's dawn and a
## four-hour run), so the catch comes in with the day's work instead of in the evening -- but never into a closure: a
## trap whose species closes tomorrow is collected now (a catch completed in a closure is zero, fishing_driver.gd).

const Driver := preload("res://demo/water/fishing_driver.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1
## The catch plans. A trip's species choice 0..2 is CHOSEN FISH; PLAN_AUTO is BEST CATCH.
const SPECIES_PER_SITE: int = 3
const PLAN_AUTO: int = 3
const PLAN_CHOICES: int = 4
## §5.7: "All fish species except mussel | 1400" NP a unit (mussel is never caught inland).
const FISH_NP_PER_U: int = 1400
## The collection policies.
const COLLECT_SOAKED: int = 0
const COLLECT_MORNING: int = 1
const COLLECT_COUNT: int = 2
const COLLECT_WORDS: Array[String] = ["when soaked", "morning run"]
## MORNING RUN's window, game hours (PROVISIONAL, see the header).
## (06:00 is demo/burrow/night_routine.gd DAWN_HOUR, restated so the fishery does not load the night's module;
## test_demo_fishing_revamp.gd checks they agree.)
const MORNING_FROM_HOUR: int = 6
const MORNING_UNTIL_HOUR: int = 10
## A trap whose species closes within this many days is collected now (tomorrow's closure: ECO-026's warned one).
const CLOSURE_WARNING_DAYS: int = 1


static func is_auto(choice: int) -> bool:
	"""Whether a species choice is BEST CATCH."""
	return choice == PLAN_AUTO


static func predicted_np(expected_milli: int) -> int:
	"""§5.4's predicted NP of a cycle's expected catch (§5.7's 1400 NP a unit), in milli-NP."""
	return maxi(expected_milli, 0) * FISH_NP_PER_U


static func better(np_a: int, work_a: int, close_a: int, row_a: int, np_b: int, work_b: int, close_b: int,
		row_b: int) -> bool:
	"""§5.4's auto order: A before B on higher NP/work (cross-multiplied), then earlier closure, then lower species ID."""
	var lhs: int = np_a * work_b
	var rhs: int = np_b * work_a
	if lhs != rhs:
		return lhs > rhs
	if close_a != close_b:
		return close_a < close_b
	return row_a < row_b


static func best_species(driver: Driver, site: int, method: int, level: int, preview: Driver.Preview) -> int:
	"""BEST CATCH at `site` for `method` at FISH `level`: the legal species index 0..2 with §5.4's highest predicted
	NP/work, then earliest closure, then species ID; NONE when none may be fished now. `preview` is scratch."""
	if driver == null:
		return NONE
	var gear: int = Rules.METHOD_GEAR[method]
	var work: int = Rules.METHOD_WORK_MWU[method]
	var best: int = NONE
	var best_np: int = 0
	var best_close: int = 0
	for s: int in SPECIES_PER_SITE:
		if not driver.preview_into(site, s, gear, level, preview) or not preview.ok:
			continue
		var np: int = predicted_np(preview.expected_catch_milli)
		var close: int = driver.days_to_closure(site, s)
		if best == NONE or better(np, work, close, preview.species_row, best_np, work, best_close,
				driver.species_row_of(site, best)):
			best = s
			best_np = np
			best_close = close
	return best


static func in_morning(hour_of_day: int) -> bool:
	"""Whether an hour of the day is in MORNING RUN's window."""
	return hour_of_day >= MORNING_FROM_HOUR and hour_of_day < MORNING_UNTIL_HOUR


static func next_morning_tick(tick: int) -> int:
	"""The first tick at or after `tick` that is MORNING_FROM_HOUR (06:00)."""
	var of_day: int = posmod(tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_DAY)
	var morning: int = tick - of_day + MORNING_FROM_HOUR * SimClock.TICKS_PER_HOUR
	return morning if morning >= tick else morning + SimClock.TICKS_PER_DAY


static func closes_soon(days_to_closure: int) -> bool:
	"""Whether a species closing in `days_to_closure` days is a warned closure: its trap is collected now."""
	return days_to_closure <= CLOSURE_WARNING_DAYS
