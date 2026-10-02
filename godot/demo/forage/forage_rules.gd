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

const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

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
## south woods' edge by the road. By index into KINDS.
const SPOT_AT: Array[Vector2] = [Vector2(-7.5, -29.4), Vector2(10.4, -30.4), Vector2(-12.0, 23.6), Vector2(8.0, 25.5)]
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
## Arrival, retries and handling (the fishery's: decision 0431).
const ARRIVE_M: float = 0.45
const RETRY_USEC: int = FisheryRules.RETRY_USEC
const MAX_TRIES: int = FisheryRules.MAX_TRIES
const HANDLE_MWU: int = FisheryRules.HANDLE_MWU
## §5.3's XP: 10 a completed productive WU.
const XP_PER_WU: int = FisheryRules.XP_PER_WU
const MILLI_PER_U: int = 1000
## `mwu_numerator`'s denominator (the fishery's).
const MWU_DENOMINATOR: int = FisheryRules.MWU_DENOMINATOR
## A forager's estimate for the walks out and back (DEMO, the fishery's allowance doubled for the woods' distance).
const WALK_ALLOWANCE_TICKS: int = 2 * SimClock.TICKS_PER_HOUR


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


static func units_text(milli: int) -> String:
	"""'4.0 U' (the woods' words)."""
	return ForestRules.units_text(milli)
