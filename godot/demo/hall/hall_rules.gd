extends RefCounted
## THE HALL'S RULES (decision 0771; Brendan's ruling of 2026-10-01: "the adopted version"). Presentation only: the
## demo's hall, never the simulation's. Every number is the GDD's unless it is marked DEMO or RULING (Brendan, 2026-10-01).
##
## STAGES. The hall has exactly two (GDD §5.9): STAGE 1 is the refuge/community hall the village starts with (built,
## tier 1); STAGE 2 is its ONE tier-2 upgrade, REQ-SET-136's package -- stone 40 + wood 20 + cloth 8, 1200 WU; heat fuel
## x0.75 and room comfort target +1000; no new floor and no new beds. "Only one upgrade per building; tier 3 is absent",
## and BAL-SAFE-013 refuses a second application. There is no stage 3.
##
## BANNERS. An optional dressing step, not a stage: up to BANNERS_MAX of §5.9's Decoration furniture row (wood 1 + wax
## 0.25, 12 WU, "room comfort target +250, cap 1000"), comfort only. The demo has no wax: decision 0210's substitution
## for the same row (a decoration costs its wood alone) applies, so a banner is wood 1, 12 WU.
##
## WHAT THE HALL GIVES (each from an adopted rule):
##   * dining and gathering: the starter interior's 12 seat places (§5.9's layout, the T cells), the same at both stages
##     (tier 2 adds no floor); a feast needs seats >= ceil(E / 3) (§5.7), so 12 seats serve up to 36 eligible;
##   * sleeping: floor sleep for anyone without a bed (REQ-SET-133); the GDD's starter beds are not modelled in the demo
##     (its beds are the burrow homes', decision 0210), and tier 2 adds none;
##   * comfort: the heated common room's target 7500 (§5.9 baseline), +1000 at tier 2, +250 a banner up to 1000, at most
##     10000 -- a readout, as the burrow homes' comfort is (room_fixtures.gd);
##   * heat: a hearth here burns fuel x1.00 at tier 1 and x0.75 at tier 2 (`fuel_permille`) -- for whoever lights one.
##
## DELIVERY (REQ-SET-124/125, REQ-SET-111). A project's materials are carried from the village stores by the
## stockpile to the hall in loads no heavier than the carrier's §5.2 capacity (12000 / 16000 / 24000 g, small / medium
## / large) at §5.7's masses (wood and stone 5000 g a unit, cloth 250 g), one material a load; building starts only
## once all of it is delivered. REQ-SET-126: cancelled before work begins, 100% of the delivered materials come back;
## after, 80%, rounded down to milli-U. At most UPGRADE_PLACES builders work the upgrade (§5.9: "Maximum 4
## builders/project").
##
## THE CLOTH. The village's one cloth, the GDD's opening 24 U (§5.1's initial inventory), at the stockpile with the rest
## of the stores (Brendan's ruling, decision 0771). The infirmary building and the treatments draw on the same cloth, so
## the stores keep it and every claimant reserves there (tunnel_stores.gd CLOTH; Brendan's ruling on R01, decision 0993).
##
## THE UNLOCK (Brendan's ruling of 2026-10-01, decision 0771). The GDD names no unlock for the tier-2 package, and the adopted milestones
## (§5.11: M1 needs 12 residents) are out of the nine-resident demo's reach. So one data constant decides it,
## UNLOCK_CONDITION: the first harvest gathered into store.

const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

const TIER_REFUGE: int = 1
const TIER_GREAT: int = 2
const STAGE_COUNT: int = 2
## By tier: what the hall is called at that stage.
const STAGE_NAMES: Array[String] = ["", "Community hall", "Great hall"]

const MAT_WOOD: int = 0
const MAT_STONE: int = 1
const MAT_CLOTH: int = 2
const MAT_COUNT: int = 3
const MAT_NAMES: Array[String] = ["wood", "stone", "cloth"]
## GDD §5.7's material masses, grams a unit.
const MAT_GRAMS_PER_U: Array[int] = [5000, 5000, 250]

## The projects: the upgrade, then one per banner.
const PROJECT_UPGRADE: int = 0
const PROJECT_BANNER_FIRST: int = 1
const BANNERS_MAX: int = 4
const PROJECT_COUNT: int = 5
## REQ-SET-136's tier-2 package (wood, stone, cloth milli-U) and its work.
const UPGRADE_MILLI: Array[int] = [20000, 40000, 8000]
const UPGRADE_WU: int = 1200
## §5.9's Decoration row with decision 0210's substitution (see BANNERS).
const BANNER_MILLI: Array[int] = [1000, 0, 0]
const BANNER_WU: int = 12
## The work board's rows: the upgrade's builder places, then one per banner.
const UPGRADE_PLACES: int = 4
const ROWS: int = UPGRADE_PLACES + BANNERS_MAX

## REQ-SET-126: after work begins, this much of the delivered materials comes back.
const REFUND_STARTED_PERMILLE: int = 800
const PERMILLE: int = 1000

## §5.9's comfort targets and decoration rule.
const COMMON_COMFORT: int = 7500
const TIER_GREAT_COMFORT: int = 1000
const DECORATION_COMFORT: int = 250
const DECORATION_CAP: int = 1000
const COMFORT_MAX: int = 10000
## Heat fuel per mille, by tier (REQ-SET-136: x0.75 at tier 2).
const FUEL_PERMILLE: Array[int] = [1000, 1000, 750]

## The starter interior's seat places, and §5.7's feast seating: seats >= ceil(E / SEAT_SHARE).
const SEATS: int = 12
const SEAT_SHARE: int = 3

## DEMO: a WU is this much demo time for one worker -- decision 0210's fit-out rate, the demo's other furniture work.
const USEC_PER_WU: int = 150000
## DEMO: lifting a load at the stockpile, and setting it down at the hall (the spoil baskets' 1.4 s and 0.9 s).
const LOAD_USEC: int = 1400000
const PUT_DOWN_USEC: int = 900000

## THE UNLOCK (see THE UNLOCK).
const UNLOCK_AT_START: int = 0
const UNLOCK_FIRST_HARVEST: int = 1
const UNLOCK_FIRST_WINTER: int = 2
const UNLOCK_CONDITION: int = UNLOCK_FIRST_HARVEST
const UNLOCK_WORDS: Array[String] = ["from the start", "once the first harvest is gathered into store",
	"once the first winter sets in"]

## The village's cloth at the start (GDD §5.1: cloth 24 U), the stores' one cloth (see THE CLOTH).
const START_CLOTH_MILLI: int = StoresScript.START_CLOTH_MILLI_U


static func is_project(project: int) -> bool:
	"""Whether `project` names one of the hall's projects."""
	return project >= 0 and project < PROJECT_COUNT


static func is_banner(project: int) -> bool:
	"""Whether `project` is one of the banners."""
	return project >= PROJECT_BANNER_FIRST and project < PROJECT_COUNT


static func need_milli(project: int, mat: int) -> int:
	"""How much of material `mat` project `project` takes (milli-U; 0 for none or an unknown one)."""
	if not is_project(project) or mat < 0 or mat >= MAT_COUNT:
		return 0
	return UPGRADE_MILLI[mat] if project == PROJECT_UPGRADE else BANNER_MILLI[mat]


static func work_wu(project: int) -> int:
	"""Project `project`'s construction work (WU)."""
	if not is_project(project):
		return 0
	return UPGRADE_WU if project == PROJECT_UPGRADE else BANNER_WU


static func places_of(project: int) -> int:
	"""How many builders may work project `project` at once."""
	if not is_project(project):
		return 0
	return UPGRADE_PLACES if project == PROJECT_UPGRADE else 1


static func row_project(row: int) -> int:
	"""The project board row `row` is a place on (-1: no such row)."""
	if row < 0 or row >= ROWS:
		return -1
	return PROJECT_UPGRADE if row < UPGRADE_PLACES else PROJECT_BANNER_FIRST + row - UPGRADE_PLACES


static func first_row(project: int) -> int:
	"""Project `project`'s first board row (-1: none)."""
	if not is_project(project):
		return -1
	return 0 if project == PROJECT_UPGRADE else UPGRADE_PLACES + project - PROJECT_BANNER_FIRST


static func load_milli(size_class: int, mat: int) -> int:
	"""The most of material `mat` one carrier of §5.2 size class `size_class` carries a trip (milli-U)."""
	if mat < 0 or mat >= MAT_COUNT:
		return 0
	var size: int = clampi(size_class, MealRules.SIZE_SMALL, MealRules.SIZE_LARGE)
	@warning_ignore("integer_division")
	return MealRules.CARRY_G[size] * 1000 / MAT_GRAMS_PER_U[mat]


static func refund_milli(delivered_milli: int, work_begun: bool) -> int:
	"""REQ-SET-126: what comes back of `delivered_milli` when a project is cancelled -- all of it before work begins,
	80% rounded down to milli-U after."""
	if delivered_milli <= 0:
		return 0
	if not work_begun:
		return delivered_milli
	@warning_ignore("integer_division")
	return delivered_milli * REFUND_STARTED_PERMILLE / PERMILLE


static func comfort_target(tier: int, banners: int) -> int:
	"""The common room's comfort target: 7500, +1000 at tier 2, +250 a banner up to 1000, at most 10000."""
	var bonus: int = TIER_GREAT_COMFORT if tier >= TIER_GREAT else 0
	var decoration: int = mini(maxi(banners, 0) * DECORATION_COMFORT, DECORATION_CAP)
	return mini(COMMON_COMFORT + bonus + decoration, COMFORT_MAX)


static func fuel_permille(tier: int) -> int:
	"""A hearth's fuel use here, per mille of the ordinary (REQ-SET-136)."""
	return FUEL_PERMILLE[clampi(tier, TIER_REFUGE, TIER_GREAT)]


static func seats_needed(eligible: int) -> int:
	"""§5.7: the seats a feast for `eligible` residents needs, ceil(E / 3) (0 for nobody)."""
	if eligible <= 0:
		return 0
	@warning_ignore("integer_division")
	return (eligible + SEAT_SHARE - 1) / SEAT_SHARE


static func gathering_capacity(seats: int) -> int:
	"""The most residents a feast can be planned for with `seats` seats (seats >= ceil(E / 3))."""
	return maxi(seats, 0) * SEAT_SHARE
