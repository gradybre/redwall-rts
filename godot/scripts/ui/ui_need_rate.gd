extends RefCounted
## NEED-RATE-R01's display arithmetic for a need's continuous per-simulated-hour rate.
##
## The ruling fixes the meaning first, because the number is easy to print and easy to mean the
## wrong thing by: UXV-020's hourly figure is "the continuous rate produced by the current model
## conditions, BEFORE need-value clamping". It is not the last tick's rounded difference, not a
## forecast that the conditions hold for an hour, and it is never estimated by advancing the
## resident 750 ticks.
##
## ---------------------------------------------------------------------------------------
## THE UNITS. A need value is `value/100` percent on `needs.gd`'s 0..10000 scale. A rate R is in
## milli-need-points per simulated hour, and `R/100000` is percentage points per hour. So 250000
## milli/hour is 2.50 pp/h, which is the ruling's own worked fixture.
##
## ROUNDING IS MAGNITUDE-FIRST, SIGN AFTER. `(abs(R)+500)//1000` is nearest with ties away from
## zero over the validated domain; the sign is reapplied to the rounded hundredths. Doing it in
## that order is the whole reason `-499` prints `0.00` and NOT `-0.00`: the magnitude rounds to
## zero, and `signed_hundredths()` refuses to carry a sign onto a zero. A displayed `-0.00`
## says "falling, imperceptibly" about a rate the display has just decided is not falling at all.
##
## ---------------------------------------------------------------------------------------
## CAPPED IS NOT ZERO. At need 0 with a negative R, or 10000 with a positive R, the ruling says
## KEEP R and mark Capped. Reporting 0 because the stored value cannot move would claim the
## model condition had changed when it has not -- and specifically, "a capped Hunger row does
## not imply starvation health damage has stopped; health retains its own owner". Inward rates
## are never capped, at either bound.
##
## PAUSE AND SPEED DO NOT APPEAR IN THIS FILE. Speeds 0/1/2/4 scale how fast simulated hours
## elapse, not how much a need changes per simulated hour. There is deliberately no speed
## parameter here for a caller to multiply by.
##
## Nothing here is authoritative. These strings are never fed back into the simulation.

const NeedsScript := preload("res://scripts/core/needs.gd")

## Milli-need-points per hundredth of a percentage point per hour: 1000 milli is one need
## point, and 100 need points is one percentage point of the 10000-point scale.
const MILLI_PER_HUNDREDTH: int = 1000
## Half of that, added before the integer division to round to nearest, ties away from zero.
const ROUND_HALF: int = MILLI_PER_HUNDREDTH / 2
## Two decimal places, as the divisor that splits them off.
const HUNDREDTHS: int = 100

## The compact unit shown beside the number.
const UNIT_SHORT: String = "pp/h"
## The ruling's "full accessible words", for the row's accessible description.
const UNIT_WORDS: String = "percentage points per simulated hour"
## What the row is marked with when the value has reached a bound and R still pushes outward.
const CAPPED_LABEL: String = "Capped"
## The explanation that must remain reachable, per the ruling's own wording.
const CAPPED_EXPLANATION: String = \
	"further outward change is discarded at the bound; inward rates remain uncapped"
## Said when no binding published a rate. Not a zero, and not a blank.
const UNAVAILABLE: String = "Rate unavailable"

## The words a sign is read as, so a screen reader does not announce a bare hyphen.
const SIGN_WORD_RISING: String = "rising"
const SIGN_WORD_FALLING: String = "falling"
const SIGN_WORD_STEADY: String = "steady"


static func signed_hundredths(rate_milli: int) -> int:
	"""R in milli-need-points/hour as signed hundredths of a percentage point per hour.

	Magnitude is rounded FIRST and the sign is applied to the rounded magnitude. There is
	deliberately no `if magnitude == 0: return 0` guard here: integers have no negative zero,
	so `-0` IS `0` and such a guard would be unreachable code that no mutation could kill. The
	`-0.00` trap lives one level up, in `text()`, which takes its sign from THESE hundredths
	and never from the raw `rate_milli` -- see the guard there.
	"""
	var magnitude: int = (absi(rate_milli) + ROUND_HALF) / MILLI_PER_HUNDREDTH
	return -magnitude if rate_milli < 0 else magnitude


static func text(rate_milli: int) -> String:
	"""A signed rate to two decimals with the compact unit: `+2.50 pp/h`, `-3.00 pp/h`, `0.00 pp/h`."""
	var hundredths: int = signed_hundredths(rate_milli)
	var magnitude: int = absi(hundredths)
	var body: String = "%d.%02d %s" % [magnitude / HUNDREDTHS, magnitude % HUNDREDTHS, UNIT_SHORT]
	if hundredths == 0:
		return body
	## The sign comes from the ROUNDED hundredths, never from `rate_milli`. Reading the raw
	## rate here is what produces `-0.00 pp/h` for R=-499: a magnitude the display has just
	## decided is zero, wearing a minus that claims it is falling.
	return ("-" if hundredths < 0 else "+") + body


static func is_capped(basis_points: int, rate_milli: int) -> bool:
	"""True when the value sits at a bound and R still pushes outward past it.

	Outward only. A resident at 0 whose rate is positive is recovering, and a resident at 10000
	whose rate is negative is declining; neither is capped, because neither is being discarded.
	"""
	if basis_points <= NeedsScript.NEED_MIN and rate_milli < 0:
		return true
	return basis_points >= NeedsScript.NEED_MAX and rate_milli > 0


static func row_text(basis_points: int, rate_milli: int) -> String:
	"""What the need row prints: the rate, and `Capped` beside it when it is being discarded.

	The rate itself is unchanged by the cap. The ruling forbids reporting 0 "merely because the
	current value is capped".
	"""
	if is_capped(basis_points, rate_milli):
		return "%s  %s" % [text(rate_milli), CAPPED_LABEL]
	return text(rate_milli)


static func sign_word(rate_milli: int) -> String:
	"""How the trend is read aloud, from the RAW sign and never from the formatted string."""
	var hundredths: int = signed_hundredths(rate_milli)
	if hundredths > 0:
		return SIGN_WORD_RISING
	if hundredths < 0:
		return SIGN_WORD_FALLING
	return SIGN_WORD_STEADY


static func accessible_text(basis_points: int, rate_milli: int) -> String:
	"""The rate in full words, with the cap explanation when the row is capped."""
	var magnitude: int = absi(signed_hundredths(rate_milli))
	var spoken: String = "%s, %d.%02d %s" \
		% [sign_word(rate_milli), magnitude / HUNDREDTHS, magnitude % HUNDREDTHS, UNIT_WORDS]
	if is_capped(basis_points, rate_milli):
		return "%s; %s: %s" % [spoken, CAPPED_LABEL, CAPPED_EXPLANATION]
	return spoken
