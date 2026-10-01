extends RefCounted
## WATER PART B's NUMBERS: the fishing methods and their roles, the work, the gear, the ice, the drying rack and the
## mill. Decision 0431 (live demo; Brendan approved water part B whole). Every number is cited to the GDD or the balance
## sheet, or named a DEMO value here and recorded in decisions 0431-0436. Presentation only: nothing here writes into
## the settlement simulation; the fishery's own arithmetic is `scripts/core/fishing.gd`'s, run by
## `demo/water/fishing_driver.gd`.
##
## THE METHODS (GDD §5.4's gear table, "GDD:394"; review ECO-023: distinct roles, not a yield ladder):
##   HAND NET  from the bank -- the flexible one: any of the site's fish, one fisher, 60 WU, base 8 U, wear 20, injury
##             12/10000. Offered at the run, the ford and the pond's west bank.
##   TRAP      from the bank -- low attendance: set (20 WU), left to soak 6 h, collected (20 WU); base 12 U, wear 10,
##             injury 8; takes only dace, perch and carp here (§5.4: "dace/perch/carp/mussel"; no mussel inland).
##   BOAT      on the pond -- the big planned catch: a crew of two, 120 party-WU, base 36 U, wear 15, injury 20, two
##             effort slots. Fixed routes only (decision 0432).
##   ICE       through the pond's ice in winter -- an ice kit and a tier-2 outfit (§5.4: "Frozen lake; tier 2 clothing
##             required"), a net cycle of 90 WU, base 6 U, wear 20, injury 24; only on SAFE ice (decision 0433).
## There is no LINE: §5.4 has no line row, and inventing one would add a gear the GDD does not have (decision 0431). The
## weir is a structure with its own lane; this lane does not fish it.
##
## WORK (§5.2/§5.3): a WU is a game minute of base-speed labour, "80 milli-WU x factor/1000" a calendar tick; the factor
## is §5.3's `1000 + 50 x level` of the worker's FISH (or CRAFT/PRESERVE: the demo keeps one FISH skill and no others,
## so station work runs at factor 1000). So a hand-net cycle is an hour of game time, 25 s at 1x.
##
## SKILL (§5.3): XP 10 a productive WU, level `min(10, floor_sqrt(xp / 5000))`; "Group boat skill = floor(mean crew FISH
## levels)". The demo seeds FISH by trade (DEMO, decision 0431): the otter fisher 4, the otter boatwright 2, everyone
## else 0 -- and anyone learns by fishing (LORE-P12: skills are not species). A boat's HELM needs FISH >= 1; its second
## seat may be a learner.

const Fishing := preload("res://scripts/core/fishing.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const METHOD_NET: int = 0
const METHOD_TRAP: int = 1
const METHOD_BOAT: int = 2
const METHOD_ICE: int = 3
const METHOD_COUNT: int = 4
## fishing.gd's gear row for each method.
const METHOD_GEAR: Array[int] = [Fishing.GEAR_HAND_NET, Fishing.GEAR_TRAP, Fishing.GEAR_BOAT, Fishing.GEAR_ICE_KIT]
const METHOD_NAMES: Array[String] = ["Hand net", "Trap", "Boat", "Ice fishing"]
const METHOD_SHORT: Array[String] = ["net", "trap", "boat", "ice"]
const METHOD_ROLES: Array[String] = [
	"from the bank: any fish there, an hour's work by one fisher",
	"from the bank: set, left 6 h to soak, then collected; dace, perch and carp",
	"on the pond: the biggest planned catch, rowed by a crew of two",
	"through the pond's ice in winter: an ice kit and a winter outfit",
]
## Residents each method takes (§5.4 Workers column).
const METHOD_CREW: Array[int] = [1, 1, 2, 1]
## §5.4's work per cycle in milli-WU: the net 60, the trap's set (its collect is TRAP_COLLECT_MWU), the boat's 120
## party-WU (each of the two rows half), the ice kit's 90.
const METHOD_WORK_MWU: Array[int] = [60000, 20000, 120000, 90000]
const TRAP_COLLECT_MWU: int = 20000
const TRAP_SOAK_HOURS: int = 6
## Sites per method (fishing_driver.gd SITE_*): every bank but the trap's own species limit; the boat and the ice on
## the pond only.
## As bit masks over fishing_driver.gd's SITE_* (bit 0 the run, 1 the ford, 2 the pond).
const METHOD_SITE_MASK: Array[int] = [0b111, 0b111, 0b100, 0b100]
const SITE_NAMES: Array[String] = ["the run", "the ford", "the pond"]
## Each site's bank, where a net or trap fisher stands, and the water it casts into (m; DEMO, snapped to standable
## ground at configure): the run just north of the fisher shelter (clear of its walls, between the rod and the rack),
## the ford's west bank (its landing), and the pond's south-west bank (clear of the jetty; the pond's own landing is
## inside the boathouse, decision 0432).
const SITE_BANK: Array[StringName] = [&"bank_run", &"bank_ford", &"bank_pond"]
const SITE_BANK_AT: Array[Vector2] = [Vector2(21.1, 10.5), Vector2(20.4, -0.9), Vector2(20.7, 32.6)]
const SITE_WATER_AT: Array[Vector2] = [Vector2(22.6, 10.6), Vector2(21.9, -0.87), Vector2(22.3, 32.3)]

## §5.2/§5.3 work arithmetic (see WORK).
const MWU_PER_TICK: int = 80
const PERMILLE: int = 1000
const XP_PER_WU: int = 10
const MILLI_PER_U: int = 1000
## Handling a load (picking gear up, putting a catch down): 1 WU, as the farm's and the kitchen's (DEMO).
const HANDLE_MWU: int = 1000

## FISH seeds by trade (see SKILL; DEMO). A level's XP is §5.3's curve.
const FISH_SEED_KEYS: Array[StringName] = [&"otter_fisher", &"otter_boatwright"]
const FISH_SEED_LEVELS: Array[int] = [4, 2]
const HELM_MIN_LEVEL: int = 1

## A trip is OVERDUE (an incident) once it runs this long past its estimate (DEMO: two game hours).
const OVERDUE_MARGIN_TICKS: int = 2 * SimClock.TICKS_PER_HOUR
## A crew member who cannot reach its place tries again this often, at most this many times (DEMO, as the spoil
## crew's).
const RETRY_USEC: int = 3000000
const MAX_TRIES: int = 3

## THE DRYING RACK (§5.7 `dry_fish`: "fish 4 | dried_fish 3x1800 | 24+12 h passive | Dryer/PRESERVE | 720"; §5.9 Dryer:
## "Preserver 1 | 4 passive batch slots"). The rack by the fisher shelter is that dryer, drawn as a smoking rack: the
## GDD has no smoking method, so smoking IS its drying row (decision 0434).
const DRY_IN_MILLI: int = 4000
const DRY_OUT_MILLI: int = 3000
const DRY_WORK_MWU: int = 24000
const DRY_PASSIVE_HOURS: int = 12
const RACK_SLOTS: int = 4

## THE MILL (§5.7 `flour`: "grain 3 | flour 3 | 12 | Mill/CRAFT | 240"; §5.9 Mill: "Crafter 2 | 2 mill slots"). Its
## waterwheel turns while it grinds (presentation).
const MILL_IN_MILLI: int = 3000
const MILL_OUT_MILLI: int = 3000
const MILL_WORK_MWU: int = 12000
const MILL_SLOTS: int = 2

## REQ-SET-094: production cancelled after its inputs were consumed yields half their food mass as spoiled food.
const CANCEL_SPOIL_PERMILLE: int = 500


static func work_ticks(mwu: int, level: int) -> int:
	"""Calendar ticks `mwu` milli-WU take one worker at FISH `level` (§5.2: 80 x factor / 1000 a tick), rounded up."""
	@warning_ignore("integer_division") var per_tick: int = MWU_PER_TICK * ForestRules.skill_factor_permille(level) / PERMILLE
	@warning_ignore("integer_division") return (mwu + per_tick - 1) / per_tick


static func work_usec(mwu: int, level: int) -> int:
	"""Demo microseconds `mwu` milli-WU take one worker at `level`, on the demo calendar."""
	return CalendarScript.usec_for_ticks(work_ticks(mwu, level))


static func mwu_numerator(usec: int, level: int) -> int:
	"""Milli-WU one worker at `level` does in `usec` demo microseconds, times MWU_DENOMINATOR: a caller adds it to its
	carried remainder and divides, so no fraction of a milli-WU is ever lost between frames."""
	return usec * MWU_PER_TICK * ForestRules.skill_factor_permille(level) * SimClock.TICKS_PER_HOUR


## `mwu_numerator`'s denominator: the factor's thousand and the calendar's game hour in demo microseconds.
const MWU_DENOMINATOR: int = PERMILLE * CalendarScript.HOUR_USEC


static func is_method(method: int) -> bool:
	"""Whether `method` names one of the four."""
	return method >= 0 and method < METHOD_COUNT


static func offers_site(method: int, site: int) -> bool:
	"""Whether `method` is used at `site` in this village."""
	return is_method(method) and site >= 0 and site < Driver.SITE_COUNT and METHOD_SITE_MASK[method] & (1 << site) != 0


static func pantry_item_of(species_row: int) -> int:
	"""The pantry item a caught species lands as (farm_catalog.gd; NO_ITEM: never caught here)."""
	return Catalog.item_of_species(species_row)
