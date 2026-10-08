extends RefCounted
## EACH RESIDENT'S COLD: exposure in milli-hours and whether it is CHILLED. Decision 0571 (Brendan's rulings 1 and 3).
## Pure logic over packed columns; demo_winter.gd tells it, a few times a game hour, where each resident is (an
## environment, winter_rules.gd ENV_*) and how many calendar ticks have passed, and reads back who became Chilled or
## warmed through. Presentation only: the settlement's Needs store is not written.
##
## INTEGRATION (GDD §5.2: "Health drains and recovery integrate per tick with signed remainders"; "cold_milli_hours
## stores 1000 per exposure-hour"). A stretch of `ticks` at a rate of R milli-hours an hour adds R x ticks / 750, the
## division's remainder kept per resident (signed), so however the stretches are cut the sum is exact. Exposure is
## clamped to 0..COLD_CAP_MILLI (winter_rules.gd CHILLED); a clamp drops the remainder.
##
## CHILLED (ruling 1): ENTERED when exposure reaches CHILLED_AT_MILLI (4 exposure-hours); LEFT only when it is warmed
## through, exposure back to 0 -- so a resident is not Chilled and well again by turns at the line. While Chilled it
## works at CHILLED_WORK_PERMILLE and is sent for a warm-up break (demo_winter.gd). No health is lost.
##
## WHY (the panels say it): each resident's last environment and the place it was in (a source of hearth_fuel.gd, or
## OUTDOORS / BELOW for a tunnel), and the air or room temperature there.
##
## A FEAST'S WARMTH (decision 1701; GDD §5.7 Hearth row, "Shared Warmth: cold-exposure accumulation -25%"): exposure
## GAINED is scaled by `gain_permille` (1000: none; the feasts set 750 while Shared Warmth lasts, demo/feast/), never
## below §5.7's cap of a 40% reduction (GAIN_FLOOR_PERMILLE); clearing at a hearth is never scaled. §5.2's figures are
## exact at 750: 2000 -> 1500 and 1000 -> 750 milli-hours an hour.

const Rules := preload("res://demo/winter/winter_rules.gd")

## Where a resident was, besides a hearth source row (hearth_fuel.gd): outdoors, or below in a tunnel (no room).
const OUTDOORS: int = -1
const BELOW: int = -2
## §5.7: "cold-exposure reductions cap 40% across food/feast effects".
const GAIN_FLOOR_PERMILLE: int = 600
const FULL_GAIN_PERMILLE: int = 1000

var cold_milli: PackedInt64Array = PackedInt64Array()
var chilled: PackedByteArray = PackedByteArray()
## The environment, the place and its temperature (tenths) at the last stretch (see WHY).
var env: PackedByteArray = PackedByteArray()
var place: PackedInt32Array = PackedInt32Array()
var place_tenths: PackedInt32Array = PackedInt32Array()
## Who became Chilled and who warmed through since the last `take_changes_into`.
var entered: PackedInt32Array = PackedInt32Array()
var warmed: PackedInt32Array = PackedInt32Array()
## Times anyone became Chilled (a metric for the balance sim).
var chilled_count: int = 0
var revision: int = 0
## Exposure gained, per mille (see A FEAST'S WARMTH).
var gain_permille: int = FULL_GAIN_PERMILLE

var _remainder: PackedInt64Array = PackedInt64Array()


func configure(residents: int) -> void:
	"""One row per resident, every one warm."""
	cold_milli.resize(residents)
	cold_milli.fill(0)
	_remainder.resize(residents)
	_remainder.fill(0)
	chilled.resize(residents)
	chilled.fill(0)
	env.resize(residents)
	env.fill(Rules.ENV_NEUTRAL)
	place.resize(residents)
	place.fill(OUTDOORS)
	place_tenths.resize(residents)
	place_tenths.fill(0)


func count() -> int:
	"""How many residents."""
	return cold_milli.size()


func note_place(i: int, p_env: int, p_place: int, tenths: int) -> void:
	"""Where resident `i` is now (see WHY)."""
	env[i] = p_env
	place[i] = p_place
	place_tenths[i] = tenths


func integrate(i: int, rate_milli_per_hour: int, ticks: int) -> void:
	"""`ticks` calendar ticks at `rate_milli_per_hour` for resident `i` (see INTEGRATION), then CHILLED's two lines."""
	if ticks <= 0:
		return
	if rate_milli_per_hour != 0:
		var rate: int = gained_rate(rate_milli_per_hour, gain_permille)
		var scaled: int = rate * ticks + _remainder[i]
		var whole: int = Rules.div(scaled, Rules.TICKS_PER_HOUR)
		_remainder[i] = scaled - whole * Rules.TICKS_PER_HOUR
		var value: int = cold_milli[i] + whole
		if value <= 0 or value >= Rules.COLD_CAP_MILLI:
			_remainder[i] = 0
		cold_milli[i] = clampi(value, 0, Rules.COLD_CAP_MILLI)
	_follow_chilled(i)


static func gained_rate(rate_milli_per_hour: int, permille: int) -> int:
	"""A rate after A FEAST'S WARMTH: a gain scaled by `permille` (clamped to GAIN_FLOOR_PERMILLE..1000, floored), a
	loss (clearing) unchanged."""
	if rate_milli_per_hour <= 0:
		return rate_milli_per_hour
	return Rules.div(rate_milli_per_hour * clampi(permille, GAIN_FLOOR_PERMILLE, FULL_GAIN_PERMILLE), FULL_GAIN_PERMILLE)


func _follow_chilled(i: int) -> void:
	"""Enter Chilled at the line, leave it warmed through (see CHILLED)."""
	if chilled[i] == 0 and cold_milli[i] >= Rules.CHILLED_AT_MILLI:
		chilled[i] = 1
		chilled_count += 1
		entered.append(i)
		revision += 1
	elif chilled[i] == 1 and cold_milli[i] == 0:
		chilled[i] = 0
		warmed.append(i)
		revision += 1


func is_chilled(i: int) -> bool:
	"""Whether resident `i` is Chilled."""
	return i >= 0 and i < chilled.size() and chilled[i] == 1


func hours_tenths(i: int) -> int:
	"""Resident `i`'s exposure in tenths of an exposure-hour (floored), for the panels."""
	return Rules.div(cold_milli[i], 100)


func work_permille(i: int) -> int:
	"""Resident `i`'s work rate: the Chilled factor, or full."""
	return Rules.CHILLED_WORK_PERMILLE if is_chilled(i) else Rules.FULL_PERMILLE


func chilled_total() -> int:
	"""How many residents are Chilled now."""
	var n: int = 0
	for value: int in chilled:
		n += value
	return n


func take_changes_into(into_entered: PackedInt32Array, into_warmed: PackedInt32Array) -> void:
	"""Who became Chilled and who warmed through since the last call, into the caller's arrays (cleared first)."""
	into_entered.clear()
	into_entered.append_array(entered)
	into_warmed.clear()
	into_warmed.append_array(warmed)
	entered.clear()
	warmed.clear()
