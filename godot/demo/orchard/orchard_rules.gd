extends RefCounted
## THE ORCHARD'S NUMBERS (decisions 0671-0677; feature #20 and review group Y: ECO-008, 009, 010, 015). Presentation
## only: nothing here is the settlement's simulation. Every number is either a document's -- named where it is used --
## or a DEMO VALUE named below and nowhere else.
##
## THE DOCUMENTS' RULES, used as written:
##   GDD §5.6 orchard table (scripts/core/orchard_hive.gd carries it and is called, never retyped): a block is 4x4 farm
##     tiles with one modelled large fruit tree; apple 96 days to maturity and 80 fruit U a year, Autumn 1-6; pear 144
##     days and 110 U, Autumn 3-8; planting costs the sapling and compost 4 U; care is 20 WU a day in spring and summer
##     and water 2 U a day during drought; untended spring/summer days remove 100 health, tended days restore 50; fewer
##     than 6 winter chill days (at or below 5 C) give 75% yield; the nursery propagates for fruit 4 + compost 2 + water
##     2, 120 WU and a 12-day wait.
##   gameplay_balance.md BAL-CAT-010: planting one block 40 WU, harvesting a mature block 80 WU, a haul payload 2 WU to
##     load and 2 to unload; a new tree's health starts 10000.
##   GDD §5.5 Berries forage row (scripts/core/forage.gd carries it): availability spring 0, summer 1000, autumn 400,
##     winter 0; capacity 300 U; base work 4 WU a U; regrowth 120 per mille a day, by decision 0036's capped additive
##     form `min(K-P, floor((K-P)*r*S/10^6) + 1000)`; sustainable floor 20% of K; "unavailable patches become
##     dormant": nothing is picked in a season of availability 0. Work a U = ceil(base*10^6 / ((1000+40*FORAGE) *
##     (1000+100*danger))): danger 1 (land within 64 m of the hall, no staffed lookout), FORAGE 0 -- 4 WU a U.
##   GDD §5.2's work rate, 80 milli-WU a tick at skill factor 1000 (demo/fishery/fishery_rules.gd `work_ticks`).
##
## THE APPROVED CHANGE (decision 0672; review ECO-008, approved 2026-09-30 in group Y): "a small first yield of 15-25%
## of mature output after one full seasonal cycle", and the inherited old orchard as the first scenario's start. A
## young tree EARLY_YIELD_AGE_DAYS old (one 48-day year) yields EARLY_YIELD_PERMILLE (20%, the range's middle) of its
## §5.6 yield, once a year in its window, until it matures; maturity itself is §5.6's unchanged 96/144 days.
##
## DEMO VALUES (PROPOSALS in decision 0671 unless a decision says otherwise):
##   * THE SITES: four blocks, tile-aligned (the square's centre is exterior tile 64,64; a tile is 2 m): the old
##     orchard south of the field beds (an apple and a pear) and the east orchard's two empty planting sites by the
##     south road.
##   * THE OLD TREES (ECO-008's "inherited old orchard restored"): ages, a neglected 3500 health and a cold last winter.
##   * THE BASKET STANDS (ECO-010's gathering points): one a group, a store of STAND_CAPACITY_U at the covered store's
##     factor, where picked fruit waits to be hauled on; HAUL_LOAD_MILLI a trip.
##   * THE HEDGE: three bushes of the east group -- raspberry, blackberry, strawberry -- sharing ONE §5.5 Berries patch
##     (300 U), every picking the pantry's one `berries` item (decision 0676); PICK_LOAD_MILLI a picking.
##   * THE NURSERY's place and the M3 grant (2 apple + 2 pear saplings) held there from the start.
##   * THE GROVE (ECO-015): one protected grove in the North stand, never felled while protected, observed once a
##     season (OBSERVE_MWU).
##
## THE REVIEW GROUP Y REMAINDERS (decision 1721; Brendan's ruling of 2026-10-07 on open question Q-D7: "Both, agent
## proposes numbers" -- a sapling can be moved once, with a delay of some days; carts are a haul tool for harvest groups).
## Every number below is a PROPOSAL of decision 1721, its source or reasoning beside it:
##   * MOVING A SAPLING (ECO-009): a planted tree still a sapling (its first half-year, HALF_YEAR_DAYS) may be lifted
##     and replanted on a free site ONCE; it then SETTLES for MOVE_SETTLE_DAYS, not growing (its age stands still).
##   * A CART (ECO-010): a group may build one handcart at its baskets (CART_WOOD_MILLI, CART_BUILD_MWU); its hauls
##     then carry up to CART_LOAD_MILLI a trip instead of a basket's HAUL_LOAD_MILLI.
##   * THE FRESH-TABLE SHARE (ECO-010's "shares as desired priorities"): a group sends FRESH_STEPS percent of what it
##     hauls to the kitchen pantry and the rest to the best keeping store -- a priority, not a guarantee.
##   * A SECOND GROVE and the groves' FORAGE RESERVE (ECO-015): the beech hollow round the mushroom spot; while a grove
##     is protected the foraging trips leave GROVE_RESERVE_PERMILLE of the woods' stock of the kind gathered in it.

const Hive := preload("res://scripts/core/orchard_hive.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1
const APPLE: int = Hive.SPECIES_APPLE
const PEAR: int = Hive.SPECIES_PEAR
const SPECIES_NAMES: Array[String] = ["apple", "pear"]
## Each species' sapling as goods_measures.gd counts it (decision 1801).
const SAPLING_GOODS: Array[StringName] = [&"sapling_apple", &"sapling_pear"]

# --- the sites --------------------------------------------------------------------------------------------------------

const TILE_M: float = 2.0
const BLOCK_M: float = TILE_M * Hive.BLOCK_SIZE
## Each site's block origin tile (its minimum x, z), then its group and what grows there when the village opens (NONE:
## an empty planting site).
const SITE_ORIGIN: Array[Vector2i] = [Vector2i(54, 77), Vector2i(58, 77), Vector2i(67, 75), Vector2i(67, 79)]
const SITE_GROUP: PackedInt32Array = [0, 0, 1, 1]
const SITE_START_SPECIES: PackedInt32Array = [APPLE, PEAR, NONE, NONE]
const SITE_NAMES: Array[String] = ["the old apple's block", "the old pear's block", "east site 1", "east site 2"]
const SITE_COUNT: int = 4
## The old trees (ECO-008): age in days (ten and thirteen years: well past §5.6's maturity), a neglected health, and
## last winter's chill days (cold enough: at least §5.6's six).
const OLD_AGE_DAYS: PackedInt32Array = [480, 624, 0, 0]
const OLD_HEALTH: int = 3500
const OLD_CHILL_DAYS: int = 8

# --- the groups (ECO-010) ---------------------------------------------------------------------------------------------

const GROUP_NAMES: Array[String] = ["The old orchard", "The east orchard"]
const GROUP_COUNT: int = 2
const STAND_AT: Array[Vector2] = [Vector2(-4.6, 23.2), Vector2(4.4, 30.0)]
const STAND_IDS: Array[StringName] = [&"orchard_stand_old", &"orchard_stand_east"]
const STAND_LABELS: Array[String] = ["Old orchard baskets", "East orchard baskets"]
const STAND_CAPACITY_U: int = 120
## §5.8's covered-store factor: baskets under the trees' shade, out of the rain.
const STAND_PERMILLE: int = 1000
const HAUL_LOAD_MILLI: int = 10000
## BAL-CAT-010: "handling a haul payload 2000 milli-WU to load plus 2000 to unload".
const HAUL_LOAD_MWU: int = 2000
const HAUL_UNLOAD_MWU: int = 2000
## The group's TIMING (ECO-010: "mix earlier apple and later pear harvests to trade concentrated festival abundance
## against manageable preserving labor"): each tree picked as its window opens, or every tree of the group together
## on the first day all their windows share.
const TIMING_STAGGERED: int = 0
const TIMING_TOGETHER: int = 1
const TIMING_NAMES: Array[String] = ["As each ripens", "All together"]
const TIMING_SHORT: Array[String] = ["staggered", "together"]
## Where the baskets go on to (ECO-010's destination policy): the kitchen's pantry for the table, or the store that
## keeps food longest (a root cellar before the covered store). Decision 0674 built it as a choice of one; decision
## 1721 makes it the group's fresh-table share (FRESH_STEPS below): 100% is the old "kitchen", 0% the old "keeping".
const KITCHEN_STORE_ID: StringName = &"kitchen_pantry"
## How much of each fruit the stand keeps back for the nursery (ECO-010's "seedling" share): 0, one propagation's
## fruit, or two.
const KEEP_STEPS: PackedInt32Array = [0, 4000, 8000]

# --- the hedge (§5.5 Berries) -------------------------------------------------------------------------------------------

const BUSH_AT: Array[Vector2] = [Vector2(17.0, 25.0), Vector2(17.0, 27.4), Vector2(16.8, 29.6)]
## What every bush is picked as: the generic §5.7 `berries` item (Brendan's ruling of 2026-10-01, decision 0676).
const BERRY_ITEM: int = Catalog.ITEM_BERRIES
const BUSH_GROUP: int = 1
const BUSH_COUNT: int = 3
const BERRY_KIND: int = ForageScript.PATCH_BERRIES
const HEDGE_CAPACITY_MILLI: int = ForageScript.PATCH_CAPACITY_U[ForageScript.PATCH_BERRIES] * ForageScript.MILLI_PER_UNIT
## §5.1's opening stock (forage.gd INITIAL_STOCK 8/10): the bushes are in leaf; their fruit can be picked from summer.
@warning_ignore("integer_division") const HEDGE_START_MILLI: int = HEDGE_CAPACITY_MILLI * ForageScript.INITIAL_STOCK_NUMERATOR \
	/ ForageScript.INITIAL_STOCK_DENOMINATOR
const PICK_LOAD_MILLI: int = 5000
## §5.5's danger band for the hedge: 1 (land within 64 m of the hall; the demo has no staffed lookout).
const HEDGE_DANGER: int = 1

# --- the nursery (ECO-009) ------------------------------------------------------------------------------------------------

const NURSERY_AT: Vector2 = Vector2(-2.6, 25.4)
## The M3 grant (§5.6 "the first two saplings of each type arrive with milestone M3"), held from the start in the
## restoration scenario (decision 0672).
const GRANT_SAPLINGS: PackedInt32Array = [Hive.MILESTONE_STARTER_SAPLINGS, Hive.MILESTONE_STARTER_SAPLINGS]
const MAX_PLANS: int = 6

# --- the grove (ECO-015) -------------------------------------------------------------------------------------------------

const GROVE_NAME: String = "the North hollow"
const GROVE_AT: Vector2 = Vector2(-10.0, -25.5)
const GROVE_RADIUS_M: float = 6.5
## Every grove (decision 1721: more than one, ECO-015): the North hollow (above, decision 0675) and the beech hollow, a
## 6 m circle round the foraging trips' mushroom spot (forage_rules.gd SPOT_AT[1], (10.4, -30.4)) and two mature
## beeches. Each has its mossy stone (its rest and observation spot), its toggle and its record.
const GROVE_NAMES: Array[String] = [GROVE_NAME, "the beech hollow"]
const GROVE_CENTRES: Array[Vector2] = [GROVE_AT, Vector2(10.4, -30.4)]
const GROVE_RADII_M: PackedFloat32Array = [GROVE_RADIUS_M, 6.0]
## Each grove's stone: the North hollow's at its heart (decision 0675), the beech hollow's off the foragers' spot.
const GROVE_STONES: Array[Vector2] = [GROVE_AT, Vector2(8.8, -29.2)]
const GROVE_COUNT: int = 2
## ECO-015's "protected areas maintain identifiable seasonal forage reserves" (decision 1721, PROPOSAL): while a grove
## is protected, a foraging trip to a spot inside it leaves a tenth of the kind's §5.5 capacity above the sustainable
## floor (so trips stop at 30% of the stock, not §5.5's 20%). The basin's own rules are untouched.
const GROVE_RESERVE_PERMILLE: int = 100
const OBSERVE_MWU: int = 10000
const MAX_RECORDS: int = 16

# --- the approved early yield (decision 0672) -------------------------------------------------------------------------------

const EARLY_YIELD_PERMILLE: int = 200
const EARLY_YIELD_AGE_DAYS: int = SimClock.DAYS_PER_YEAR
## Half a year: a tree is drawn as a sapling until then.
@warning_ignore("integer_division") const HALF_YEAR_DAYS: int = SimClock.DAYS_PER_YEAR / 2
const PERMILLE: int = 1000

# --- the jobs' kinds (orchard_jobs.gd; here so the words can name them without a cycle) -------------------------------

const K_TEND: int = 0
const K_HARVEST: int = 1
const K_PICK: int = 2
const K_HAUL: int = 3
const K_PLANT: int = 4
const K_PROPAGATE: int = 5
const K_OBSERVE: int = 6
## The apiary's (decision 1601, demo/hives/): the keeper's daily service and collection, a winter feeding from the
## pantry's honey, and a recolonisation.
const K_SERVICE: int = 7
const K_FEED: int = 8
const K_RECOLONIZE: int = 9
## Decision 1721: a sapling lifted and replanted on another site (ECO-009), and a group's handcart built (ECO-010).
const K_MOVE: int = 10
const K_CART: int = 11
const KIND_COUNT: int = 12

# --- work (milli-WU) -------------------------------------------------------------------------------------------------------

const CARE_MWU: int = Hive.CARE_WORK_MILLI_WU
const HARVEST_MWU: int = 80000
const PLANT_MWU: int = 40000
const PROPAGATE_MWU: int = Hive.NURSERY_WORK_MILLI_WU
## An early harvest is picked in the share of a full one's work that its fruit is of a full crop (decision 0672).
@warning_ignore("integer_division") const EARLY_HARVEST_MWU: int = HARVEST_MWU * EARLY_YIELD_PERMILLE / PERMILLE
const RETRY_USEC: int = FisheryRules.RETRY_USEC

# --- moving a sapling (ECO-009; decision 1721, Brendan's ruling on Q-D7, 2026-10-07) -----------------------------------
## The delay (PROPOSAL): one season, 12 days (SimClock.DAYS_PER_SEASON -- the same as §5.6's nursery wait, the time the
## demo already gives a sapling to take), in which the moved tree does not grow: its age stands still, so its early
## fruit and its maturity both come 12 days later. Health, tending and the winter's chill go on as §5.6 says.
const MOVE_SETTLE_DAYS: int = SimClock.DAYS_PER_SEASON
## Lifting it (PROPOSAL): half a planting's BAL-CAT-010 40 WU -- the hole is dug round the root ball, not filled.
@warning_ignore("integer_division") const MOVE_LIFT_MWU: int = PLANT_MWU / 2
## Replanting it: BAL-CAT-010's planting, 40 WU, with §5.6's planting compost 4 U (the sapling is the one lifted).
const MOVE_REPLANT_MWU: int = PLANT_MWU
const MOVE_COMPOST_MILLI: int = Hive.PLANT_COMPOST_MILLI

# --- the groups' carts (ECO-010; decision 1721, Brendan's ruling on Q-D7) -------------------------------------------------
## A handcart's load (PROPOSAL): four baskets, 40 U -- 10 kg of fruit at §5.7's 250 g a unit, under a medium resident's
## own 16 kg carry (BAL-WORK-003), pushed rather than carried. Loading and unloading stay one payload's BAL-CAT-010
## 2 WU each: that, and a quarter of the trips, is what the cart saves.
const CART_LOAD_MILLI: int = 40000
## Building one (PROPOSAL): wood 4 U (20 kg at §5.7's 5000 g a unit: a bed, two wheels and the handles) and 60 WU at
## the group's baskets -- one and a half times §5.9's 40 WU workbench trap, a larger piece. No rope (open question Q-D3).
const CART_WOOD_MILLI: int = 4000
const CART_BUILD_MWU: int = 60000
## Where each group's cart stands when it is not out: beside its baskets, clear of the stump by the east stand and of
## every obstacle by CART_CLEAR_M (the suite checks it against the real layout).
const CART_PARK_AT: Array[Vector2] = [Vector2(-2.4, 22.0), Vector2(2.2, 29.0)]
## The handcart's half-length (world_sizes.gd's `handcart` bound: 0.95 m) and a hand's breadth.
const CART_CLEAR_M: float = 1.1

# --- the fresh-table share (ECO-010; decision 1721) --------------------------------------------------------------------------
## The share of a group's hauls it would like on the fresh table (the kitchen pantry), in percent; the rest go to the
## best keeping store. A desired priority (ECO-010): each haul goes where the share is furthest behind, and to the other
## when that has no room.
const FRESH_STEPS: PackedInt32Array = [0, 25, 50, 75, 100]
const PERCENT: int = 100

## A tree's drawn stages, by age: a sapling until YOUNG_FROM_DAYS, then the tree's model growing to full size at
## maturity (presentation).
const STAGE_SAPLING: int = 0
const STAGE_YOUNG: int = 1
const STAGE_EARLY: int = 2
const STAGE_MATURE: int = 3
const STAGE_OLD: int = 4
const STAGE_NAMES: Array[String] = ["Sapling", "Young tree", "Bearing early", "Mature", "Old tree"]
## Past this many years a tree is "old" in words (the inherited trees are).
const OLD_FROM_DAYS: int = SimClock.DAYS_PER_YEAR * 6


static func site_centre_m(site: int) -> Vector2:
	"""Where site `site`'s tree stands: its block's centre (x, z metres)."""
	var o: Vector2i = SITE_ORIGIN[site]
	var half: float = BLOCK_M * 0.5
	return Vector2(float(o.x - ForestRules.TILE_ORIGIN) * TILE_M + half, float(o.y - ForestRules.TILE_ORIGIN) * TILE_M + half)


static func site_rect_m(site: int) -> Rect2:
	"""Site `site`'s block on the ground (metres)."""
	var c: Vector2 = site_centre_m(site)
	return Rect2(c - Vector2.ONE * BLOCK_M * 0.5, Vector2.ONE * BLOCK_M)


static func is_site(site: int) -> bool:
	"""Whether `site` names one of the sites."""
	return site >= 0 and site < SITE_COUNT


static func is_group(group: int) -> bool:
	"""Whether `group` names one of the groups."""
	return group >= 0 and group < GROUP_COUNT


static func is_grove(grove: int) -> bool:
	"""Whether `grove` names one of the groves."""
	return grove >= 0 and grove < GROVE_COUNT


static func grove_of(at: Vector2) -> int:
	"""The grove `at` stands in (NONE: none)."""
	for grove: int in GROVE_COUNT:
		if at.distance_to(GROVE_CENTRES[grove]) <= GROVE_RADII_M[grove]:
			return grove
	return NONE


static func is_movable_age(age_days: int) -> bool:
	"""Whether a planted tree `age_days` old is still a sapling that may be moved (its first half-year)."""
	return age_days >= 0 and age_days < HALF_YEAR_DAYS


static func to_kitchen(fresh_pct: int, to_kitchen_milli: int, hauled_milli: int, load_milli: int) -> bool:
	"""Whether the next haul of `load_milli` should go to the fresh table: the share's kitchen part is furthest behind --
	what has gone there (`to_kitchen_milli` of `hauled_milli` hauled) is under `fresh_pct` of the total with this load."""
	if fresh_pct <= 0:
		return false
	if fresh_pct >= PERCENT:
		return true
	return to_kitchen_milli * PERCENT < fresh_pct * (hauled_milli + load_milli)


static func is_bush(bush: int) -> bool:
	"""Whether `bush` names one of the hedge's bushes."""
	return bush >= 0 and bush < BUSH_COUNT


static func early_yield_milli(base_milli: int, health: int, pollination: int, chill: int) -> int:
	"""Decision 0672's early yield: §5.6's product (orchard_hive.gd `orchard_yield_milli_into`'s factors) times
	EARLY_YIELD_PERMILLE, floored ONCE as the store floors its own: `floor(base * health * pollination * chill * 200 /
	(10000 * 1000 * 100 * 1000))`. Integer throughout (int64 holds 110000 * 10000 * 1150 * 100 * 200)."""
	var numerator: int = base_milli * health * pollination * chill * EARLY_YIELD_PERMILLE
	var denominator: int = Hive.HEALTH_FACTOR_DENOMINATOR * Hive.POLLINATION_FACTOR_DENOMINATOR \
		* Hive.CHILL_FACTOR_DENOMINATOR * PERMILLE
	@warning_ignore("integer_division") return numerator / denominator


static func berry_growth_milli(stock_milli: int, season: int) -> int:
	"""One day of §5.5 regrowth for the hedge (decision 0036's capped additive form; forage.gd's table read): 0 in a
	dormant season or when full."""
	var room: int = HEDGE_CAPACITY_MILLI - stock_milli
	var availability: int = berry_availability(season)
	if room <= 0 or availability == 0:
		return 0
	@warning_ignore("integer_division") var grown: int = room * ForageScript.PATCH_REGROWTH_PER_1000[BERRY_KIND] * availability \
		/ ForageScript.REGROWTH_DENOMINATOR + ForageScript.REGROWTH_MINIMUM_MILLI
	return mini(grown, room)


static func berry_availability(season: int) -> int:
	"""§5.5's Berries availability for `season` (0 spring .. 3 winter), per mille."""
	return ForageScript.PATCH_AVAILABILITY_PER_1000[BERRY_KIND * ForageScript.SEASON_COUNT + posmod(season, 4)]


static func berry_floor_milli() -> int:
	"""§5.5's sustainable floor for the hedge: 20% of its capacity."""
	@warning_ignore("integer_division") return HEDGE_CAPACITY_MILLI * ForageScript.SUSTAINABLE_FLOOR_PERCENT \
		/ ForageScript.PERCENT_DENOMINATOR


static func pick_mwu(milli: int) -> int:
	"""§5.5's work to pick `milli` of berries at FORAGE 0 and the hedge's danger: ceil(4 * 10^6 / (1000 * 1100)) WU a
	U, so 4 WU (4000 milli-WU) a unit, counted per milli-U."""
	var numerator: int = ForageScript.PATCH_BASE_WORK_WU[BERRY_KIND] * ForageScript.WORK_NUMERATOR_SCALE
	var denominator: int = ForageScript.WORK_BASE_TERM * (ForageScript.WORK_BASE_TERM
		+ ForageScript.WORK_DANGER_TERM * HEDGE_DANGER)
	@warning_ignore("integer_division") var per_u: int = (numerator + denominator - 1) / denominator
	return per_u * milli


static func work_usec(mwu: int) -> int:
	"""Demo microseconds `mwu` milli-WU take one worker at the base rate (§5.2), on the demo calendar."""
	return FisheryRules.work_usec(mwu, 0)


static func stage_of(age_days: int, species: int, inherited: bool) -> int:
	"""A tree's stage in words by its age (STAGE_*)."""
	if inherited or age_days >= OLD_FROM_DAYS:
		return STAGE_OLD
	if age_days >= Hive.SPECIES_MATURITY_DAYS[species]:
		return STAGE_MATURE
	if age_days >= EARLY_YIELD_AGE_DAYS:
		return STAGE_EARLY
	return STAGE_YOUNG if age_days >= HALF_YEAR_DAYS else STAGE_SAPLING


static func grown_share(age_days: int, species: int) -> float:
	"""How far a tree has grown toward its full drawn size: 0 planted, 1 at maturity (presentation)."""
	return clampf(float(age_days) / float(Hive.SPECIES_MATURITY_DAYS[species]), 0.0, 1.0)
