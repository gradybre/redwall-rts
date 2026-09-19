extends RefCounted
## PROGRESS-C4-R01 v2: stateless timing for the continuous Charter requirement.
## Truth at T-54000..T inclusive covers 54000 complete intervals. Any false tick
## or departure from winter resets the interval. Paused frames make no call.
## This validates supplied history; only the future owner can establish that the
## observations occurred. No production caller, mutable state, arrays or save fields.
## Both _into methods mutate only caller-owned out, using static refusal strings.
## Calendar arithmetic uses SimClock constants/day_index_at, with no Calendar allocation.
## Ticks are bounded to the existing calendar addition's safe int64 domain.

const IntMathScript := preload("res://scripts/core/int_math.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## Season ordinal of winter in SimClock's `SEASON_NAMES` (spring, summer, autumn, winter).
const WINTER_SEASON: int = 3
## The award instant is the midnight STARTING winter day 12, so the day is 12 and the tick of day
## is 0. Day 12 at 00:00 is the first tick of that day, not its end.
const AWARD_SEASON_DAY: int = 12
const AWARD_TICK_OF_DAY: int = 0
## Year is 1-based, as `Calendar.year` is. "Year 3 or later" is the ruling's unchanged threshold.
const MIN_AWARD_YEAR: int = 3
## 54000 complete tick intervals, observed as 54001 committed states (endpoints inclusive).
const REQUIRED_INTERVAL_TICKS: int = 54000
const REQUIRED_OBSERVATIONS: int = REQUIRED_INTERVAL_TICKS + 1
## Sentinel for "no streak is running". Also the sentinel for "nothing has been observed yet";
## the two are named separately because they are different facts that happen to share a value.
const UNSET_SINCE: int = -1
const NO_OBSERVATION: int = -1
## The existing calendar addition's safe domain ceiling, identical to SimClock's restore ceiling.
const MAX_OBSERVABLE_TICK: int = IntMathScript.INT64_MAX - SimClockScript.CALENDAR_OFFSET_TICKS


static func advance_since_into(tick: int, last_observed_tick: int, true_since_tick: int,
		all_predicates_true: bool, out: IntMathScript.IntResult) -> bool:
	"""Fold ONE committed observation into the streak start. Writes the new since into `out`.

	Returns true on success with `out.ok` set and `out.value` holding the since the caller should
	store (-1 when no streak is running). Returns false on any refusal, having written only
	`out` (ok=false, value=0, error nonempty).

	The only fresh observation is tick 0 with last=-1 and since=-1. Every other observation must
	be exactly last+1: duplicate, skipped, reversed, negative and out-of-domain ticks refuse, and
	no truth is ever inferred for a skipped tick. A prior since must be -1, or 0<=since<=last and
	inside the winter containing last; a corrupt prior tuple refuses rather than being repaired.

	Outside winter, or with any predicate false, the streak is -1. Inside winter with all
	predicates true, a prior since in THIS winter is preserved and an unset one starts at tick.
	Entering a new winter can never carry an old streak.
	"""
	if not _validate_sequence_into(tick, last_observed_tick, true_since_tick, out):
		return false
	if not all_predicates_true or not _is_winter(tick):
		return out.succeed(UNSET_SINCE)
	if true_since_tick != UNSET_SINCE and _same_season_block(true_since_tick, tick):
		return out.succeed(true_since_tick)
	return out.succeed(tick)


static func award_eligible_into(tick: int, last_observed_tick: int, true_since_tick: int,
		all_predicates_true: bool, already_awarded: bool, out: IntMathScript.IntResult) -> bool:
	"""Decide whether the supplied history tuple is award-eligible AT `tick`. 1 eligible, 0 not.

	Returns true with `out.value` 1 exactly when the tuple is valid AND not already awarded AND
	all predicates are currently true AND year>=3 AND it is winter day 12 at exact midnight AND
	tick-since>=54000. Every other VALID tuple succeeds with 0. An INVALID tuple refuses.

	Validity requires last_observed_tick==tick (the final observation actually happened), and a
	since that is -1 or lies within the current winter and is <=tick. Outside winter since must
	be -1. Inside winter, true predicates require since>=0 and false predicates require since=-1;
	an inconsistent tuple refuses instead of masquerading as ineligible.

	The caller's predicates already include the year requirement and every authored live fact;
	this helper re-derives the date and year itself so a caller cannot bypass the temporal gate.
	It awards no bit, grants no item and pauses nothing -- it only answers the question.
	"""
	if not _validate_award_tuple_into(tick, last_observed_tick, true_since_tick,
			all_predicates_true, out):
		return false
	if already_awarded or not all_predicates_true:
		return out.succeed(0)
	if not is_award_instant(tick):
		return out.succeed(0)
	if true_since_tick == UNSET_SINCE:
		return out.succeed(0)
	if tick - true_since_tick < REQUIRED_INTERVAL_TICKS:
		return out.succeed(0)
	return out.succeed(1)


static func is_tick_in_domain(tick: int) -> bool:
	"""True when a tick is observable: 0..INT64_MAX-CALENDAR_OFFSET_TICKS, the calendar's domain."""
	return tick >= 0 and tick <= MAX_OBSERVABLE_TICK


static func is_award_instant(tick: int) -> bool:
	"""True when `tick` is the exact midnight starting winter day 12 of year 3 or later.

	The helper's independent date check. It answers false for every out-of-domain tick rather
	than decoding one, so no caller can reach the calendar arithmetic through this predicate.
	"""
	if not is_tick_in_domain(tick):
		return false
	var day_zero: int = SimClockScript.day_index_at(tick)
	if _season_of_day(day_zero) != WINTER_SEASON:
		return false
	if _season_day_of_day(day_zero) != AWARD_SEASON_DAY:
		return false
	if _year_of_day(day_zero) < MIN_AWARD_YEAR:
		return false
	return _tick_of_day(tick) == AWARD_TICK_OF_DAY


static func _validate_sequence_into(tick: int, last_observed_tick: int, true_since_tick: int,
		out: IntMathScript.IntResult) -> bool:
	"""Validate one contiguous observation step and its prior tuple. Refuses into `out` on fault.

	Ordering is checked WITHOUT overflowing: `last_observed_tick` is proven to be in the calendar
	domain before `last_observed_tick + 1` is ever formed, and that ceiling leaves 4500 units of
	headroom below INT64_MAX.
	"""
	if not is_tick_in_domain(tick):
		return out.refuse("PROGRESS_TICK_OUT_OF_DOMAIN")
	if last_observed_tick == NO_OBSERVATION:
		if tick != 0:
			return out.refuse("PROGRESS_FRESH_TICK_NOT_ZERO")
		if true_since_tick != UNSET_SINCE:
			return out.refuse("PROGRESS_FRESH_SINCE_SET")
		return true
	if not is_tick_in_domain(last_observed_tick):
		return out.refuse("PROGRESS_LAST_TICK_OUT_OF_DOMAIN")
	if tick != last_observed_tick + 1:
		return out.refuse("PROGRESS_NONCONTIGUOUS_OBSERVATION")
	return _validate_prior_since_into(last_observed_tick, true_since_tick, out)


static func _validate_prior_since_into(last_observed_tick: int, true_since_tick: int,
		out: IntMathScript.IntResult) -> bool:
	"""A prior since is -1, or 0<=since<=last inside the winter containing last. Else refuse.

	A set since whose last observation is not in winter is corrupt, not repairable: the streak it
	claims could not have survived the season change.
	"""
	if true_since_tick == UNSET_SINCE:
		return true
	if true_since_tick < 0:
		return out.refuse("PROGRESS_INVALID_SINCE")
	if true_since_tick > last_observed_tick:
		return out.refuse("PROGRESS_FUTURE_SINCE")
	if not _is_winter(last_observed_tick):
		return out.refuse("PROGRESS_SINCE_OUTSIDE_WINTER")
	if not _same_season_block(true_since_tick, last_observed_tick):
		return out.refuse("PROGRESS_SINCE_WRONG_WINTER")
	return true


static func _validate_award_tuple_into(tick: int, last_observed_tick: int, true_since_tick: int,
		all_predicates_true: bool, out: IntMathScript.IntResult) -> bool:
	"""Validate the tuple `award_eligible_into()` is handed. Refuses into `out` on any fault."""
	if not is_tick_in_domain(tick):
		return out.refuse("PROGRESS_TICK_OUT_OF_DOMAIN")
	if last_observed_tick != tick:
		return out.refuse("PROGRESS_FINAL_OBSERVATION_MISSING")
	if not _is_winter(tick):
		if true_since_tick != UNSET_SINCE:
			return out.refuse("PROGRESS_SINCE_OUTSIDE_WINTER")
		return true
	if not all_predicates_true:
		if true_since_tick != UNSET_SINCE:
			return out.refuse("PROGRESS_FALSE_WITH_SINCE")
		return true
	if true_since_tick == UNSET_SINCE:
		return out.refuse("PROGRESS_TRUE_WITHOUT_SINCE")
	if true_since_tick < 0:
		return out.refuse("PROGRESS_INVALID_SINCE")
	if true_since_tick > tick:
		return out.refuse("PROGRESS_FUTURE_SINCE")
	if not _same_season_block(true_since_tick, tick):
		return out.refuse("PROGRESS_SINCE_WRONG_WINTER")
	return true


static func _is_winter(tick: int) -> bool:
	"""True when a domain-valid tick falls in winter, derived from the existing offset calendar."""
	return _season_of_day(SimClockScript.day_index_at(tick)) == WINTER_SEASON


static func _same_season_block(tick_a: int, tick_b: int) -> bool:
	"""True when two ticks share one season occurrence, not merely the same season name.

	DAYS_PER_YEAR is an exact multiple of DAYS_PER_SEASON, so `day_index / DAYS_PER_SEASON`
	numbers the seasons consecutively from the epoch and equality of that block index is exactly
	"the same winter of the same year". No multiplication, so nothing here can overflow.
	"""
	return SimClockScript.day_index_at(tick_a) / SimClockScript.DAYS_PER_SEASON \
		== SimClockScript.day_index_at(tick_b) / SimClockScript.DAYS_PER_SEASON


static func _season_of_day(day_zero: int) -> int:
	"""Season ordinal of a zero-based day index, as `Calendar.set_tick()` computes it."""
	return (day_zero % SimClockScript.DAYS_PER_YEAR) / SimClockScript.DAYS_PER_SEASON


static func _season_day_of_day(day_zero: int) -> int:
	"""One-based day within the season of a zero-based day index."""
	return day_zero % SimClockScript.DAYS_PER_SEASON + 1


static func _year_of_day(day_zero: int) -> int:
	"""One-based year of a zero-based day index."""
	return day_zero / SimClockScript.DAYS_PER_YEAR + 1


static func _tick_of_day(tick: int) -> int:
	"""Ticks elapsed since 00:00 under the offset calendar; 0 is exact midnight."""
	return (tick + SimClockScript.CALENDAR_OFFSET_TICKS) % SimClockScript.TICKS_PER_DAY
