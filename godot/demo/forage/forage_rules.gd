extends RefCounted
## FORAGING TRIPS' numbers (decision 0681; feature #22, Brendan's approval of 2026-10-01: "send a small party into the
## woods for nuts, mushrooms and herbs; they come back hours later with a haul"). Pure constants and static functions,
## so the suite checks them without a scene.
##
## WHAT IS THE GDD'S. Every ecological number is scripts/core/forage.gd's own (GDD §5.5, REQ-SET-066..069), never
## restated here: the five patches' capacities, seasonal availability, base work and daily regrowth; the 80% opening
## stock; the sustainable floor (20% of capacity); the daily aggregate quota (decision 0030: automatic, shared by the
## basin); work per U = ceil(base_work x 1000000 / ((1000 + 40 x FORAGE) x (1000 + 100 x danger))); the injury chance
## max(1, 8 x danger - FORAGE) per 10000 per 60 WU. The items are §5.7's (farm_catalog.gd THE WOODS' FORAGE).
##
## WHAT IS THE DEMO'S (each named DEMO below; decision 0681's choices, approved by Brendan as built on 2026-10-01):
##   * THE BASIN'S DANGER is §5.5's rule applied, not chosen: "Danger zones: 0 inside 32 m of any staffed lookout; 1
##     remaining land within 64 m of the central hall". The demo village has no lookout and its woods lie within 64 m of
##     the hall, so its one forage basin's natural danger is 1.
##   * THE SPOTS: where each kind is gathered, in the woods beyond the clearing, all three in the ONE basin (§5.1: one
##     stock basin; the spots are where a forager stands, not three stocks).
##   * THE PARTY: one to three foragers; THE BASKET: each brings back at most BASKET_MILLI. A trip asks the basin for
##     party x basket, bounded by what it admits now (its daily quota and the stock above its sustainable floor), and
##     each forager's share is claimed (forage.gd `claim_forage`) when it reaches its spot.
##   * The work rate is §5.2's base step (80 milli-WU a calendar tick: the fishery's arithmetic at level 0) -- FORAGE
##     skill enters through §5.5's work per U, not a work speed -- times §5.10's 80% on a heavy-rain day (the woods').
##
## PREPARED OUTINGS (review ECO-014; decision 1721, each a PROPOSAL with its reasoning below):
##   * HOME BEFORE DARK: a trip is planned to be home by DUSK_HOUR (the night's 20:00). Its walk is counted at the
##     slowest resident's pace, WALK_M_PER_HOUR; a forager at its spot claims only what it can gather and still walk
##     home by dusk, and TURNS BACK with nothing when that is under MIN_SHARE_MILLI. A trip that could not be home by
##     dusk is not authorised.
##   * THE CARRY KIT: the village's one pannier frame, lent to one trip at a time: its carrier (the first seat) brings
##     KIT_BASKET_MILLI, two baskets.
##   * A NAMED LEAD (optional): the first selected resident leads the trip (the first seat); the news and the place's note
##     name them. Routine trips stay anonymous seats.
##   * A REMEMBERED PLACE: each spot keeps one note -- the latest trip home from it: when, what it brought, how long it was
##     out and who led it. Information for next time, never a bonus (ECO-014: "not an infinitely stacking skill bonus").
##   * CONSENT: REQ-SET-067 asks a resident's dangerous-work permission in danger 2 or 3. The demo's woods are danger 1
##     (NATURAL_DANGER), so no permission is asked; the card says so (`needs_permission`).

const ForageScript := preload("res://scripts/core/forage.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The kinds a trip gathers, as forage.gd patch rows -- Brendan's approval named nuts, mushrooms and herbs; berries were
## added at the dishes lane's request (its cordial's raspberries are forage); roots stay in the basin, ungathered (the
## farm grows its own). In the pantry's item order (farm_catalog.gd FIRST_FORAGE on).
const KINDS: Array[int] = [ForageScript.PATCH_NUTS, ForageScript.PATCH_MUSHROOMS, ForageScript.PATCH_HERB,
	ForageScript.PATCH_BERRIES]
const KIND_COUNT: int = 4
## What each kind is called (a trip "for nuts"), by index into KINDS.
const KIND_WORDS: Array[String] = ["nuts", "mushrooms", "herbs", "berries"]
## §5.5 applied (see THE BASIN'S DANGER).
const NATURAL_DANGER: int = 1
## The spots (DEMO; metres, snapped to standable ground at configure): the hazel brake under the north woods' oaks and
## beeches, the beech hollow in the north-east shade, the herb bank at the sunny south-west edge, the bramble edge at the
## south woods' edge by the road. By index into KINDS. The bramble edge was (8.0, 25.5) on its lane, inside the orchard's
## east planting block (orchard_rules.gd: x 6-14, z 22-30), where a planted tree would stand on it; since the batch 8
## integration (decision 0903) it is west of the old orchard, at the south-west woods' edge (within the woods' 30 m
## reach of the square, as every spot).
const SPOT_AT: Array[Vector2] = [Vector2(-7.5, -29.4), Vector2(10.4, -30.4), Vector2(-12.0, 23.6), Vector2(-25.0, 27.0)]
const SPOT_NAMES: Array[String] = ["the hazel brake", "the beech hollow", "the herb bank", "the bramble edge"]
## The party (DEMO).
const PARTY_MIN: int = 1
const PARTY_MAX: int = 3
const PARTY_DEFAULT: int = 2
## The basket (DEMO; decision 0681, Brendan's ruling of 2026-10-01): a forager's most, milli-U.
const BASKET_MILLI: int = 4000
## The least worth a trip (DEMO): a share under a tenth of a unit is not claimed.
const MIN_SHARE_MILLI: int = 100
## Trips out at once (DEMO), and the job rows they take (a seat each).
const MAX_TRIPS: int = 3
const MAX_JOBS: int = MAX_TRIPS * PARTY_MAX
## Arrival and retries (the fishery's: decision 0431).
const ARRIVE_M: float = 0.45
const RETRY_USEC: int = FisheryRules.RETRY_USEC
const MAX_TRIES: int = FisheryRules.MAX_TRIES
## §5.3's XP: 10 a completed productive WU.
const XP_PER_WU: int = FisheryRules.XP_PER_WU
const MILLI_PER_U: int = 1000
## `mwu_numerator`'s denominator (the fishery's).
const MWU_DENOMINATOR: int = FisheryRules.MWU_DENOMINATOR

## PREPARED OUTINGS (decision 1721; see the header).
## The night begins at 20:00 (demo/burrow/night_routine.gd DUSK_HOUR -- the suite checks they agree); it ends at 06:00.
const DUSK_HOUR: int = 20
const DAWN_HOUR: int = 6
## The slowest resident's pace, metres a game hour: 0.72 m/s x 25 s (demo_calendar.gd; night_routine.gd's "18-26 m a
## game hour"), so every forager of the party is home in time.
const WALK_M_PER_HOUR: int = 18
## The carry kit (PROPOSAL): one in the village; its carrier brings two baskets (8 U, 2 kg at §5.7's 250 g a unit).
const KIT_BASKET_MILLI: int = 8000
## §5.2's base step, milli-WU a calendar tick (the fishery's).
const MWU_PER_TICK: int = FisheryRules.MWU_PER_TICK
## REQ-SET-067: a resident's dangerous-work permission is asked from this danger up.
const PERMISSION_DANGER: int = 2


static func is_kind(k: int) -> bool:
	"""Whether `k` indexes KINDS."""
	return k >= 0 and k < KIND_COUNT


static func ask_milli(party: int) -> int:
	"""What a trip of `party` foragers asks for: a basket each (before the basin's bound)."""
	return clampi(party, PARTY_MIN, PARTY_MAX) * BASKET_MILLI


static func share_milli(total: int, party: int, seat: int) -> int:
	"""Seat `seat`'s share of a trip's `total` among `party` foragers: equal, the remainder to the first seats, so the
	shares add up to the total exactly."""
	@warning_ignore("integer_division") var each: int = total / party
	return each + (1 if seat < total - each * party else 0)


static func work_mwu(milli: int, work_per_u_wu: int) -> int:
	"""Milli-WU to gather `milli` of a kind at `work_per_u_wu` WU a unit (§5.5's work per U), rounded up."""
	@warning_ignore("integer_division") var mwu: int = (milli * work_per_u_wu * 1000 + MILLI_PER_U - 1) / MILLI_PER_U
	return mwu


static func mwu_numerator(usec: int, weather_event: int) -> int:
	"""Milli-WU a forager does in `usec` demo microseconds, times MWU_DENOMINATOR (§5.2's base step; §5.10's 80% on a
	heavy-rain day)."""
	@warning_ignore("integer_division") var slowed: int = FisheryRules.mwu_numerator(usec, 0) * ForestRules.weather_permille(weather_event) / 1000
	return slowed


static func ask_with_kit(party: int, kit: bool) -> int:
	"""What a trip of `party` foragers asks for: a basket each, the kit's carrier two (decision 1721)."""
	return ask_milli(party) + (KIT_BASKET_MILLI - BASKET_MILLI if kit else 0)


static func seat_share_milli(total: int, party: int, seat: int, kit: bool) -> int:
	"""Seat `seat`'s share of a trip's `total`: equal shares, the kit's carrier (seat 0) two; the remainder to seat 0,
	so the shares add up to the total exactly."""
	if not kit:
		return share_milli(total, party, seat)
	var parts: int = party + 1
	@warning_ignore("integer_division") var each: int = total / parts
	return each * (2 if seat == 0 else 1) + (total - each * parts if seat == 0 else 0)


static func daylight_ticks(tick_of_day: int) -> int:
	"""Calendar ticks from `tick_of_day` (ticks since midnight) to dusk: 0 at night (dusk to dawn)."""
	if tick_of_day < DAWN_HOUR * SimClock.TICKS_PER_HOUR:
		return 0
	return maxi(0, DUSK_HOUR * SimClock.TICKS_PER_HOUR - tick_of_day)


static func walk_ticks(metres: float) -> int:
	"""Calendar ticks a walk of `metres` takes at the slowest pace, rounded up (a planning figure: the route's own
	length can only be longer, BAL-WORK-003)."""
	return ceili(maxf(metres, 0.0) * float(SimClock.TICKS_PER_HOUR) / float(WALK_M_PER_HOUR))


static func gatherable_milli(ticks: int, work_per_u_wu: int, weather_permille: int) -> int:
	"""What one forager gathers in `ticks` at §5.2's base step (times the weather's share) and `work_per_u_wu` WU a
	unit, rounded down."""
	if ticks <= 0 or work_per_u_wu <= 0:
		return 0
	@warning_ignore("integer_division") var mwu: int = ticks * MWU_PER_TICK * weather_permille / 1000
	@warning_ignore("integer_division") var milli: int = mwu / work_per_u_wu
	return milli


static func needs_permission(danger: int) -> bool:
	"""REQ-SET-067: whether gathering at `danger` asks the resident's dangerous-work permission."""
	return danger >= PERMISSION_DANGER


static func clock_text(tick_of_day: int) -> String:
	"""'15:40' -- a time of day from ticks since midnight (wrapped past midnight)."""
	var t: int = posmod(tick_of_day, SimClock.TICKS_PER_DAY)
	@warning_ignore("integer_division") var hour: int = t / SimClock.TICKS_PER_HOUR
	@warning_ignore("integer_division") var minute: int = (t % SimClock.TICKS_PER_HOUR) * 60 / SimClock.TICKS_PER_HOUR
	return "%02d:%02d" % [hour, minute]
