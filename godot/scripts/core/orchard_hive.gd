extends RefCounted
## The OrchardPlot and Hive stores of GDD §4.2, §5.6's orchard/hive arithmetic, and the
## `HivePollinationLinks` table of systems_architecture.md §2.2 -- task 03 increment 8.
##
## Closes blocker **U6** for `HivePollinationLinks`. The owner-major formula, the capacity, the
## lookup rule, the selection order and the acceptance list are
## `docs/rulings/2026-09-09_ready06_open_item_answers.md` §3, adopted by Brendan, and decision
## 0044. Requirements implemented: REQ-SET-079, 080, 081, 082 and 083.
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "OrchardPlot | species_id: int32, age_days: int32, health: int32,
##     tended_today: bool, harvested_year: bool, chill_days: int32 | One per 4x4 farm-tile orchard
##     block". All six columns are here, none renamed, at `EntityDirectory`'s 1024 ORCHARD_PLOT
##     rows -- which is also ARCH-MEM-003's "Orchard blocks <= 16384/16 = 1024". `_init()` asserts
##     all three statements agree rather than trusting them to.
##   * GDD §4.2: "Hive | building: EntityRef, strength: int32, feed_milli: int64,
##     serviced_day: int32, honey_milli: int64, wax_milli: int64 | One per apiary; six
##     pollination links max per field block". All six fields are here at 1024 HIVE rows.
##   * systems_architecture.md §2.2: `HivePollinationLinks | hive_slot, hive_generation | I32`.
##     Ruling §3 fixes the length at **30720 references / 245760 bytes**, +49152 over the shipped
##     24576-row table, and fixes the index:
##
##         recipient_index(FarmPlot typed row p)    = p            # 0..4095
##         recipient_index(OrchardPlot typed row o) = 4096 + o     # 4096..5119
##         link_row(recipient, k)                   = 6*recipient_index + k   # k = 0..5
##
##     The 24576-row arithmetic covered 4096 farm recipients only and gave the 1024 orchard
##     recipients NO INDEPENDENT SLICE -- orchard 0 aliased farm 0. That is the bug this closes,
##     and `test_orchard_hive.gd` pins the first and last row of both owner kinds against it.
##
## ADDED COLUMNS, in the manner `farming.gd` and `fishing.gd` label theirs. NO SIMULATION FIELD IS
## ADDED to §4.2's twelve.
##   * `_o_origin_x` / `_o_origin_z`: the orchard block's minimum tile. §4.2 gives OrchardPlot no
##     position because the architecture's position link is `TileHistory.orchard_row`, a
##     tile-indexed column `farming.gd` allocates and (by its own header) leaves unwritten for this
##     increment. These two columns are the INVERSE of that link, exactly as `farming.gd`'s `_tile`
##     is the inverse of `TileHistory.active_plot_row`. THIS MODULE DOES NOT WRITE
##     `TileHistory.orchard_row`: doing so means calling into `farming.gd`, and the cross-store
##     join is ARCH-SYS-006's (increment 10), which every module in this group has left alone.
##     The consequence is named, not hidden: **this store cannot see farm plots, so it refuses an
##     orchard that overlaps another ORCHARD and cannot detect one overlapping a FarmPlot.**
##     `block_bounds_of()` is the rectangle a caller checks against `farming.gd` before committing.
##   * `_h_min_tile_x/_h_min_tile_z/_h_max_tile_x/_h_max_tile_z`: the apiary footprint bounds --
##     see "THE DEPENDENCY THIS MODULE REFUSES TO INVENT AROUND" below.
##   * `_*_present`, `_*_ref_slot`, `_*_ref_generation`, `_*_live_slots`: presence, the owning
##     directory reference and the ascending live list, ARCH-MEM-005's allocation overhead outside
##     field payload, as every other store in `scripts/core/` carries.
##
## ---------------------------------------------------------------------------------------
## THE DEPENDENCY THIS MODULE REFUSES TO INVENT AROUND. `Hive.building` is an `EntityRef` to a
## Building and **there is no Building store in this repository.** The lookup rule needs that
## building's committed, rotated footprint bounds. So the bounds are VALIDATED PARAMETERS of
## `create_hive()` and `set_hive_footprint()`, in the same way `farming.gd` takes
## `pollination_factor` and `fishing.gd` takes `base_catch_milli`. No Building store is created,
## no footprint is fabricated, and the reference itself is only ever checked for liveness and kind
## through the directory -- it is never dereferenced, because there is nothing to dereference.
## When a Building store lands, the bounds become a read from it and these four columns become
## that read's cache; until then they are the committed placement's own declaration.
##
## Ruling §3 also states that the lookup rule "does not define vertical/underground pollinator
## access": **non-surface recipients need an explicit ecology-access rule before activation.**
## Nothing here guesses one. Every coordinate in this module is a horizontal exterior-grid tile,
## and a recipient that is not on the surface has no defined answer, so none is returned.
##
## ---------------------------------------------------------------------------------------
## THE LOOKUP RULE, transcribed. Horizontal distance from the crop tile centre or orchard tree
## centre to the APIARY FOOTPRINT CENTRE, using the bounding rectangle of the committed, rotated
## footprint: `center_x = (min_tile_x + max_tile_x + 1) * 1024`, likewise z. A crop tile has
## min = max; an orchard uses its 4x4 block. This handles even dimensions without rounding.
##
## That formula is GDD §5.1's own tile centre in min/max form -- for min = max = x it is
## `2048x + 1024`, which is what `resource_nodes.gd` computes -- so `_init()` asserts the two
## agree against `resource_nodes.gd`'s constants instead of keeping a second copy of the geometry.
##
## Range is an **int64 squared distance**: `dx*dx + dz*dz <= 150994944`, inclusive 12 m at 1024
## units/m. No square root is taken and no float appears anywhere in this module.
##
## SELECTION. Healthy (`strength >= 5000`), active, in-range hives, sorted by squared distance
## then persistent hive ID, up to six unique generation-checked references, tail null-filled.
## Ruling §3 names the error to avoid by name: **do not cache the nearest six regardless of
## health and miss a qualifying seventh hive.** Health is therefore a filter applied BEFORE the
## six-entry buffer, never after it, and the acceptance test for that is
## `test_six_unhealthy_neighbours_do_not_hide_a_qualifying_seventh_hive`.
##
## "Active" needs no column of its own: §5.6 says "a hive at 0 strength is abandoned", so active
## is `strength > 0`, and healthy (`>= 5000`) already implies it. Adding an `abandoned` flag would
## be inventing a §4.2 field to store something two stated numbers already decide.
##
## REFRESH DISCIPLINE. Slices are refreshed SYNCHRONOUSLY as part of the committed change --
## recipient creation and destruction, hive creation, destruction, footprint change,
## strength-eligibility crossing -- before any dependent simulation read. **Yield and UI reads
## never repair or mutate links.** There are no dirty flags, because synchronous refresh needs
## none. A read that finds a stale or duplicated slice REFUSES (`POLLINATION_LINKS_STALE`); it
## does not quietly downgrade the multiplier, and it does not repair. That refusal is what makes
## "before any dependent simulation read" enforceable rather than merely stated.
##
## WHAT THIS STORE CAN AND CANNOT REFRESH ON ITS OWN. It owns the orchard recipients, so every
## hive change refreshes all live orchard slices here. **It cannot refresh farm recipients**: a
## FarmPlot's tile lives in `farming.gd` and this module never reads it, so the owning join
## passes `(farm_row, tile_x, tile_z)` to `refresh_farm_links()`. Finding WHICH farm rows a hive
## change affects needs a reverse index, and ruling §3 says any later reverse index requires its
## own budget -- so there is none, and `check_farm_links()` is the reader that proves a caller
## honoured the discipline. `clear_farm_links()` is the FarmPlot lifecycle's obligation on destroy
## and on typed-slot reuse; the orchard lifecycle does its own clearing here.
##
## SCRATCH, exactly as ruling §3 budgets it and counted separately from the 245760-byte payload:
## distance I64[6] (48 bytes), persistent ID I32[6] (24), hive slot/generation two I32[6] (48) --
## **120 bytes**, one reusable buffer, no allocation per refresh.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS MODULE DELIBERATELY DOES NOT DO.
##   * NO JOB IS CREATED. §5.6's 20 WU/day orchard care, 20 WU/day hive service, 120 WU nursery
##     propagation and 60 WU recolonisation are exposed as named work constants. R06-JOB-006's
##     hive-service producer is a CONSUMER of this store; `job_planner.gd` is not called from
##     here, and no job state is ever written.
##   * NO INVENTORY LOT IS CREATED OR CONSUMED. `plant_orchard()` states its sapling/compost cost,
##     `harvest_orchard()` returns fruit milli-units, `remove_orchard()` returns wood, and
##     `collect_honey()`/`collect_wax()` return what the hive has accumulated. Uncollected honey
##     and wax are hive stock, not an `InventoryLot`, in the manner decision 0026 gives
##     `ForagePatch`.
##   * NO WEATHER IS READ. Temperature arrives as `temperature_tenths` and drought as an explicit
##     argument, as in `farming.gd`.
##   * NO BUILDING IS PLACED. See above.
##   * NO ITEM ID IS COMPILED. The sapling/fruit/honey/wax/wood/compost item KEYS are named;
##     compiled ids belong to `item_definitions.gd` and are the caller's to resolve.
##
## ---------------------------------------------------------------------------------------
## GAPS AND INTERPRETATIONS -- named, not invented (AGENTS.md: "do not invent a constant").
##   * INTERPRETATION -- HIVE STRENGTH IS CLAMPED TO 0..10000. §5.6 states the 8000 start, the
##     5000 healthy line, the 0 abandonment floor and production "x strength/10000", but no
##     ceiling. Without one, "tended spring days ... restore 300" compounds forever and a hive
##     would produce more than the stated 2 U/day. 10000 is the denominator §5.6 itself prints
##     and the 0-10000 integer scale GDD §4.1 uses for every such quantity; it is read as the
##     full-strength value, not chosen freely.
##   * INTERPRETATION -- `chill_days` IS THE CURRENT WINTER'S COUNT, RESET AT WINTER DAY 1, AND
##     THAT IS WHY ONE COLUMN SUFFICES. §5.6: "Winter chill counter increments per day with
##     temperature<=5degC; fewer than 6 chill days in the PREVIOUS winter gives 75% yield." Winter
##     is the last season of the year and the harvest windows are in autumn, so the count standing
##     during any autumn IS the previous winter's completed total. A second "previous winter"
##     column would be a §4.2 field this store is not entitled to add.
##   * INTERPRETATION -- MISSING WINTER FEED CONSUMES NOTHING. §5.6 gives the 0.5 U/day
##     consumption and the 500-strength penalty for "missing winter feed" but not what happens to
##     a partial stock. A day's feed is taken only when the whole 500 milli-U is there; otherwise
##     the day is unfed, the penalty applies and the partial stock is left alone, which is what
##     keeps `feed_deficit_milli_into()` -- REQ-SET-083's "show feed deficits before
##     abandonment" -- a true statement of what is still owed.
##   * INTERPRETATION -- A NEWLY COLONISED HIVE COUNTS AS SERVICED ON ITS FOUNDING DAY. §5.6
##     states no initial `serviced_day`. Day 0 names no day in this calendar, so the alternative
##     reading would charge a missed-service penalty against a hive founded that morning.
##   * INTERPRETATION -- THE ORCHARD YIELD IS FLOORED ONCE. §5.6 gives "Yield multiplies
##     health/10000 and pollination factor" and "fewer than 6 chill days ... gives 75% yield"
##     without stating rounding. REQ-SET-074 floors its whole product once, so this does too:
##     one `floor(base * health * pollination * chill / 10^9)`, never three roundings.
##   * INTERPRETATION -- "REACHES MATURITY" IS `age_days >= maturity_days`, AND A TREE THAT
##     MATURES INSIDE ITS OWN HARVEST WINDOW MAY BE HARVESTED IN IT. REQ-SET-079's "next legal
##     annual harvest" is the earliest day that is both at-or-after maturity and inside the
##     species' stated window. `first_eligible_harvest_day_into()` is that reader and is what
##     REQ-SET-081 shows before the player confirms.
##   * BLOCKED -- OWNER REUSE ON THE FARM SIDE IS A CALLER OBLIGATION. Ruling §3 requires the
##     owner lifecycle to clear its slice "including on typed-slot reuse". This store owns the
##     orchard lifecycle and does exactly that. The FarmPlot lifecycle is `farming.gd`'s and is
##     not modified from here, so `clear_farm_links()` MUST be called by the join that destroys a
##     FarmPlot. The alternative -- an owner-generation guard column per recipient slice -- is
##     5120 rows x 2 int32 = 40960 bytes that ruling §3 does not budget, so it is named here
##     rather than allocated.
##   * BLOCKED -- CROSS-PROCESS SAVE. `link_state_bytes()` and `restore_links_from_state()` are a
##     deterministic in-process round trip and `revalidate_orchard_links_after_load()` is the
##     ruling's "validate/recompute against the canonical selection on load". The save FORMAT
##     does not exist: no header, chunk layout or version field is specified for any store, so a
##     cross-process round trip is blocked on that work, exactly as in `gear.gd`.

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Farming := preload("res://scripts/core/farming.gd")
const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")

# --- GDD §4.3 enums, read from catalog.gd's protected table (decision 0018) ----------------------

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4

# --- calendar, from sim_clock.gd rather than mirrored -------------------------------------------

const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
const DAYS_PER_YEAR: int = SimClock.DAYS_PER_YEAR
const SEASONS_PER_YEAR: int = SimClock.SEASONS_PER_YEAR
const TICKS_PER_DAY: int = SimClock.TICKS_PER_DAY
const FIRST_SEASON_DAY: int = 1
const FIRST_YEAR: int = 1
## §5.1 starts the calendar at day 1, so day 0 names no day and is refused, not stored.
const MIN_CALENDAR_DAY: int = 1

# --- exterior grid geometry, from resource_nodes.gd rather than mirrored ------------------------

const MAP_TILES_X: int = ResourceNodes.MAP_TILES_X
const MAP_TILES_Z: int = ResourceNodes.MAP_TILES_Z
const TILE_SIZE_UNITS: int = ResourceNodes.TILE_SIZE_UNITS
## Ruling §3's `(min + max + 1) * 1024`: half a tile, and GDD §5.1's own centre offset.
const TILE_HALF_UNITS: int = ResourceNodes.TILE_CENTER_OFFSET_UNITS
## Largest footprint-centre coordinate the 128x128 grid can produce, `(127 + 127 + 1) * 1024`.
const MAX_CENTER_UNITS: int = (2 * (MAP_TILES_X - 1) + 1) * TILE_HALF_UNITS

# --- store capacities ---------------------------------------------------------------------------

## GDD §4.2 "One per 4x4 farm-tile orchard block"; ARCH-MEM-003 "Orchard blocks <= 16384/16=1024".
const ORCHARD_CAPACITY: int = 1024
## GDD §4.2 "One per apiary".
const HIVE_CAPACITY: int = 1024

const NULL_SLOT: int = EntityDirectory.NULL_SLOT
const NULL_GENERATION: int = EntityDirectory.NULL_GENERATION
const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const NO_ROW: int = EntityDirectory.NULL_SLOT
## §4.2: "empty catalog IDs are -1".
const SPECIES_NONE: int = -1
## Day 0 names no day, so it is "never serviced".
const NO_SERVICE_DAY: int = 0

# --- §5.6 orchard table -------------------------------------------------------------------------

## §4.3's ASCII-key rule numbers this domain: apple 0, pear 1. `_init()` compiles the keys through
## catalog.gd rather than trusting the ordinals written here.
const SPECIES_KEYS: Array[StringName] = [&"apple", &"pear"]
const SPECIES_APPLE: int = 0
const SPECIES_PEAR: int = 1
const SPECIES_COUNT: int = 2
const SPECIES_DOMAIN: String = "OrchardSpecies"

## §5.6: "Block | 4x4 tiles" for both species.
const BLOCK_SIZE: int = 4
const BLOCK_TILE_COUNT: int = BLOCK_SIZE * BLOCK_SIZE
## §5.6's "Maturity" column: apple 96 days, pear 144 days.
const SPECIES_MATURITY_DAYS: Array[int] = [96, 144]
## §5.6's "Yield/mature tree/year" column in milli-units: apple 80 fruit U, pear 110 fruit U.
const SPECIES_YIELD_MILLI: Array[int] = [80000, 110000]
## §5.6's "Harvest" column: apple Autumn 1-6, pear Autumn 3-8. Inclusive season-local days.
const SPECIES_HARVEST_SEASON: int = SEASON_AUTUMN
const SPECIES_HARVEST_FIRST_DAY: Array[int] = [1, 3]
const SPECIES_HARVEST_LAST_DAY: Array[int] = [6, 8]
## §5.6's "Plant cost/block" column: sapling_apple/sapling_pear 1, compost 4.
const SPECIES_SAPLING_ITEM_KEYS: Array[StringName] = [&"sapling_apple", &"sapling_pear"]
const PLANT_SAPLING_MILLI: int = 1000
const PLANT_COMPOST_MILLI: int = 4000
## §5.6's "Care" column: "20 WU/day in spring/summer; water 2 U/day during drought", both species.
const CARE_WORK_MILLI_WU: int = 20000
const CARE_DROUGHT_WATER_MILLI: int = 2000
## §5.6: "Untended spring/summer days remove 100 health; tended days restore 50, max 10000."
const UNTENDED_HEALTH_LOSS: int = 100
const TENDED_HEALTH_GAIN: int = 50
## The 0-10000 scale `farming.gd` already carries for crop health, read from it, not copied.
const HEALTH_MIN: int = Farming.HEALTH_MIN
const HEALTH_MAX: int = Farming.HEALTH_MAX
const HEALTH_FACTOR_DENOMINATOR: int = Farming.HEALTH_MAX
## §5.6: "Winter chill counter increments per day with temperature<=5degC; fewer than 6 chill days
## in the previous winter gives 75% yield." Tenths, because that is what §4.2 stores.
const CHILL_TEMPERATURE_MAX_TENTHS: int = 50
const CHILL_DAYS_REQUIRED: int = 6
const CHILL_FACTOR_FULL: int = 100
const CHILL_FACTOR_LOW: int = 75
const CHILL_FACTOR_DENOMINATOR: int = 100
## §5.6: "Orchard removal yields wood 8 and no refunded sapling."
const REMOVAL_WOOD_MILLI: int = 8000
## §5.6: "Saplings are propagated at a nursery for fruit 4 + compost 2 + water 2, 120 WU plus
## 12-day wait". Transcribed; the nursery RECIPE belongs to §5.7 production, not to this store.
const NURSERY_FRUIT_MILLI: int = 4000
const NURSERY_COMPOST_MILLI: int = 2000
const NURSERY_WATER_MILLI: int = 2000
const NURSERY_WORK_MILLI_WU: int = 120000
const NURSERY_WAIT_DAYS: int = 12
## §5.6: "the first two saplings of each type arrive with milestone M3". Progression is §5.12's.
const MILESTONE_STARTER_SAPLINGS: int = 2

# --- §5.6 hive table ----------------------------------------------------------------------------

## "Hive strength starts 8000, healthy>=5000." The 0..10000 clamp is an interpretation; see header.
const HIVE_INITIAL_STRENGTH: int = 8000
const HIVE_HEALTHY_STRENGTH: int = 5000
const HIVE_STRENGTH_MIN: int = 0
const HIVE_STRENGTH_MAX: int = 10000
const HIVE_STRENGTH_DENOMINATOR: int = 10000
## "a tended hive produces honey 2 U + wax 0.25 U/day x strength/10000; service is 20 WU/day".
const HIVE_HONEY_MILLI_PER_DAY: int = 2000
const HIVE_WAX_MILLI_PER_DAY: int = 250
const HIVE_SERVICE_WORK_MILLI_WU: int = 20000
## "Winter produces 0 and consumes honey 0.5 U/day. Missing winter feed removes 500 strength/day".
const HIVE_WINTER_FEED_MILLI_PER_DAY: int = 500
const HIVE_MISSING_FEED_STRENGTH_LOSS: int = 500
## "a missed service day in spring/summer/autumn removes 200 strength and produces no honey/wax".
const HIVE_MISSED_SERVICE_STRENGTH_LOSS: int = 200
## "tended spring days with strength>0 restore 300 after production".
const HIVE_TENDED_SPRING_STRENGTH_GAIN: int = 300
## "can be recolonized in spring with honey 4, wood 2, 60 WU and a 3-day wait".
const HIVE_RECOLONIZE_HONEY_MILLI: int = 4000
const HIVE_RECOLONIZE_WOOD_MILLI: int = 2000
const HIVE_RECOLONIZE_WORK_MILLI_WU: int = 60000
const HIVE_RECOLONIZE_WAIT_DAYS: int = 3
## Item keys §5.6 names for hive produce and feed. Compiled ids are `item_definitions.gd`'s.
const HONEY_ITEM_KEY: StringName = &"honey"
const WAX_ITEM_KEY: StringName = &"wax"
const FRUIT_ITEM_KEY: StringName = &"fruit"
const WOOD_ITEM_KEY: StringName = &"wood"
const COMPOST_ITEM_KEY: StringName = &"compost"
const WATER_ITEM_KEY: StringName = &"water"

# --- ruling §3 HivePollinationLinks --------------------------------------------------------------

## `recipient_index(FarmPlot typed row p) = p`, so the farm block is exactly FarmPlot's capacity.
const FARM_RECIPIENT_CAPACITY: int = Farming.FARM_PLOT_CAPACITY
## `recipient_index(OrchardPlot typed row o) = 4096 + o`.
const ORCHARD_RECIPIENT_BASE: int = FARM_RECIPIENT_CAPACITY
const RECIPIENT_CAPACITY: int = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY
## "one fixed six-reference slice per recipient".
const LINKS_PER_RECIPIENT: int = 6
const LINK_CAPACITY: int = RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT
## Ruling §3's stated payload: two I32 columns of 30720.
const LINK_COLUMN_COUNT: int = 2
const LINK_BYTES_PER_ENTRY: int = 4
const LINK_PAYLOAD_BYTES: int = LINK_CAPACITY * LINK_COLUMN_COUNT * LINK_BYTES_PER_ENTRY
## The shipped table this replaces, and the delta the architecture ledger moves by.
const LEGACY_LINK_CAPACITY: int = 24576
const LEGACY_LINK_PAYLOAD_BYTES: int = 196608
const LINK_PAYLOAD_DELTA_BYTES: int = LINK_PAYLOAD_BYTES - LEGACY_LINK_PAYLOAD_BYTES
## Ruling §3's scratch budget: I64[6] + I32[6] + I32[6] + I32[6], counted separately.
const CANDIDATE_SCRATCH_BYTES: int = 6 * 8 + 6 * 4 + 6 * 4 + 6 * 4

## "inclusive 12 m at 1024 units/m" and its square. Both are stated; `_init()` checks they agree.
const POLLINATION_RANGE_UNITS: int = 12288
const POLLINATION_RANGE_SQUARED: int = 150994944

## §5.6: "Pollination factor is 1100 for beans and orchard fruit with one healthy hive within
## 12 m, 1150 with two; other crops 1000." Ruling §3: "Further hives add no yield."
const POLLINATION_FACTOR_NEUTRAL: int = Farming.POLLINATION_FACTOR_NEUTRAL
const POLLINATION_FACTOR_ONE_HIVE: int = 1100
const POLLINATION_FACTOR_TWO_HIVES: int = 1150
const POLLINATION_FACTOR_DENOMINATOR: int = 1000
## The one crop §5.6 pollinates. Read from `farming.gd`'s compiled table, never re-derived here.
const POLLINATED_CROP_ID: int = Farming.CROP_BEANS

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SPECIES: StringName = &"INVALID_SPECIES"
const REFUSE_INVALID_DAY: StringName = &"INVALID_DAY"
const REFUSE_INVALID_BLOCK: StringName = &"INVALID_BLOCK"
const REFUSE_BLOCK_OCCUPIED: StringName = &"BLOCK_OCCUPIED"
const REFUSE_INVALID_FOOTPRINT: StringName = &"INVALID_FOOTPRINT"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_ROW: StringName = &"INVALID_ROW"
const REFUSE_INVALID_LINK_INDEX: StringName = &"INVALID_LINK_INDEX"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
const REFUSE_INVALID_STATE_IMAGE: StringName = &"INVALID_STATE_IMAGE"
const REFUSE_ORCHARD_NOT_PRESENT: StringName = &"ORCHARD_NOT_PRESENT"
const REFUSE_HIVE_NOT_PRESENT: StringName = &"HIVE_NOT_PRESENT"
const REFUSE_BUILDING_NOT_PRESENT: StringName = &"BUILDING_NOT_PRESENT"
const REFUSE_NOT_MATURE: StringName = &"ORCHARD_NOT_MATURE"
const REFUSE_OUTSIDE_HARVEST_WINDOW: StringName = &"OUTSIDE_HARVEST_WINDOW"
const REFUSE_ALREADY_HARVESTED_THIS_YEAR: StringName = &"ALREADY_HARVESTED_THIS_YEAR"
const REFUSE_HIVE_ABANDONED: StringName = &"HIVE_ABANDONED"
const REFUSE_HIVE_NOT_ABANDONED: StringName = &"HIVE_NOT_ABANDONED"
const REFUSE_NOT_SPRING: StringName = &"NOT_SPRING"
## Ruling §3: a yield or UI read never repairs links, so a stale or duplicated slice refuses.
const REFUSE_LINKS_STALE: StringName = &"POLLINATION_LINKS_STALE"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class OpResult:
	"""Outcome of one orchard, hive or pollination operation.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, and never a partially applied effect.
	"""
	var ok: bool
	var error: StringName
	var value: int
	var ref: Vector2i

	func _init(p_ok: bool, p_error: StringName, p_value: int, p_ref: Vector2i) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value
		ref = p_ref


class HiveDayResult:
	"""One hive's completed day: what it produced, what it consumed and what it lost.

	`.ok` MUST be inspected first; a refusal leaves every quantity 0 and applies nothing.
	"""
	var ok: bool
	var error: StringName
	var serviced: bool
	var honey_milli: int
	var wax_milli: int
	var feed_consumed_milli: int
	var strength_before: int
	var strength_after: int
	var abandoned: bool

	func _init() -> void:
		"""Start cleared; every field is written by the day step before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value, so no field can survive from a previous day."""
		ok = false
		error = REFUSE_NONE
		serviced = false
		honey_milli = 0
		wax_milli = 0
		feed_consumed_milli = 0
		strength_before = 0
		strength_after = 0
		abandoned = false

	func refuse(code: StringName) -> void:
		"""Record a refusal that applied nothing."""
		clear()
		error = code


class PlantingPreview:
	"""REQ-SET-081's pre-confirmation preview: the exact first eligible harvest and the block.

	`.ok` MUST be inspected first. Every field is empty on a refusal, so an unchecked preview
	cannot be shown as a plausible date.
	"""
	var ok: bool
	var error: StringName
	var species_id: int
	var plant_day: int
	var maturity_day: int
	var first_harvest_day: int
	var first_harvest_year: int
	var first_harvest_season: int
	var first_harvest_season_day: int
	var min_tile_x: int
	var min_tile_z: int
	var max_tile_x: int
	var max_tile_z: int

	func _init() -> void:
		"""Start cleared; the preview writes every field before it returns."""
		clear()

	func clear() -> void:
		"""Return every field to its empty value."""
		ok = false
		error = REFUSE_NONE
		species_id = SPECIES_NONE
		plant_day = 0
		maturity_day = 0
		first_harvest_day = 0
		first_harvest_year = 0
		first_harvest_season = 0
		first_harvest_season_day = 0
		min_tile_x = 0
		min_tile_z = 0
		max_tile_x = 0
		max_tile_z = 0


class BlockBounds:
	"""The inclusive tile rectangle an orchard block occupies, in exterior-grid tile coordinates.

	Tile INDICES are deliberately not produced here: `resource_nodes.gd` owns `z*128+x` and this
	module keeps no second copy of it.
	"""
	var ok: bool
	var error: StringName
	var min_tile_x: int
	var min_tile_z: int
	var max_tile_x: int
	var max_tile_z: int

	func _init(p_ok: bool = false, p_error: StringName = REFUSE_NONE, p_min_x: int = 0,
			p_min_z: int = 0, p_max_x: int = 0, p_max_z: int = 0) -> void:
		"""Store the rectangle, or a refusal carrying an empty one."""
		ok = p_ok
		error = p_error
		min_tile_x = p_min_x
		min_tile_z = p_min_z
		max_tile_x = p_max_x
		max_tile_z = p_max_z


# --- collaborators --------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false

# --- §4.2 OrchardPlot columns ----------------------------------------------------------------------

var _o_present: PackedByteArray = PackedByteArray()
var _o_species_id: PackedInt32Array = PackedInt32Array()
var _o_age_days: PackedInt32Array = PackedInt32Array()
var _o_health: PackedInt32Array = PackedInt32Array()
var _o_chill_days: PackedInt32Array = PackedInt32Array()
var _o_tended_today: PackedByteArray = PackedByteArray()
var _o_harvested_year: PackedByteArray = PackedByteArray()
## ADDED: the block's minimum tile, the inverse of TileHistory.orchard_row. See the header.
var _o_origin_x: PackedInt32Array = PackedInt32Array()
var _o_origin_z: PackedInt32Array = PackedInt32Array()
var _o_ref_slot: PackedInt32Array = PackedInt32Array()
var _o_ref_generation: PackedInt32Array = PackedInt32Array()
var _o_live_slots: PackedInt32Array = PackedInt32Array()
var _o_live_count: int = 0

# --- §4.2 Hive columns -----------------------------------------------------------------------------

var _h_present: PackedByteArray = PackedByteArray()
var _h_building_slot: PackedInt32Array = PackedInt32Array()
var _h_building_generation: PackedInt32Array = PackedInt32Array()
var _h_strength: PackedInt32Array = PackedInt32Array()
var _h_serviced_day: PackedInt32Array = PackedInt32Array()
var _h_feed_milli: PackedInt64Array = PackedInt64Array()
var _h_honey_milli: PackedInt64Array = PackedInt64Array()
var _h_wax_milli: PackedInt64Array = PackedInt64Array()
## ADDED: the apiary footprint bounds. There is no Building store; see the header.
var _h_min_tile_x: PackedInt32Array = PackedInt32Array()
var _h_min_tile_z: PackedInt32Array = PackedInt32Array()
var _h_max_tile_x: PackedInt32Array = PackedInt32Array()
var _h_max_tile_z: PackedInt32Array = PackedInt32Array()
var _h_ref_slot: PackedInt32Array = PackedInt32Array()
var _h_ref_generation: PackedInt32Array = PackedInt32Array()
var _h_live_slots: PackedInt32Array = PackedInt32Array()
var _h_live_count: int = 0

# --- HivePollinationLinks columns (ruling §3) --------------------------------------------------------

var _link_hive_slot: PackedInt32Array = PackedInt32Array()
var _link_hive_generation: PackedInt32Array = PackedInt32Array()

# --- scratch (not simulation state; 120 bytes, ruling §3) ----------------------------------------------

var _cand_distance: PackedInt64Array = PackedInt64Array()
var _cand_persistent_id: PackedInt32Array = PackedInt32Array()
var _cand_slot: PackedInt32Array = PackedInt32Array()
var _cand_generation: PackedInt32Array = PackedInt32Array()
var _cand_count: int = 0

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and assert every transcribed §5.6 and ruling §3 figure holds.

	Passing an existing directory shares it; passing none creates a private one, which is what a
	test or a standalone fixture wants.
	"""
	_assert_capacities()
	_assert_species_tables()
	_assert_species_ids_match_the_compiled_catalog()
	_assert_link_arithmetic()
	_assert_geometry_matches_the_tile_primitive()
	_assert_calendar_matches_sim_clock()
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _assert_capacities() -> void:
	"""Assert both stores' row counts are the directory's and the architecture's, not local."""
	assert(ORCHARD_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_ORCHARD_PLOT],
		"OrchardPlot columns must match the directory's ORCHARD_PLOT row capacity")
	assert(HIVE_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_HIVE],
		"Hive columns must match the directory's HIVE row capacity")
	assert(ORCHARD_CAPACITY == Farming.TILE_COUNT / BLOCK_TILE_COUNT,
		"ARCH-MEM-003: orchard blocks are 16384/16, which must equal the 1024 stored rows")
	assert(FARM_RECIPIENT_CAPACITY == Farming.FARM_PLOT_CAPACITY,
		"the farm recipient block is exactly FarmPlot's own capacity")
	assert(Catalog.SEASON.size() == SEASON_COUNT, "GDD §4.3 Season has exactly four values")


func _assert_species_tables() -> void:
	"""Assert every §5.6 orchard-table column carries exactly one entry per species row."""
	assert(SPECIES_KEYS.size() == SPECIES_COUNT, "§5.6 lists exactly two orchard rows")
	assert(SPECIES_MATURITY_DAYS.size() == SPECIES_COUNT, "one maturity per §5.6 row")
	assert(SPECIES_YIELD_MILLI.size() == SPECIES_COUNT, "one annual yield per §5.6 row")
	assert(SPECIES_HARVEST_FIRST_DAY.size() == SPECIES_COUNT, "one window start per §5.6 row")
	assert(SPECIES_HARVEST_LAST_DAY.size() == SPECIES_COUNT, "one window end per §5.6 row")
	assert(SPECIES_SAPLING_ITEM_KEYS.size() == SPECIES_COUNT, "one sapling item per §5.6 row")
	for species: int in SPECIES_COUNT:
		assert(SPECIES_HARVEST_FIRST_DAY[species] >= FIRST_SEASON_DAY,
			"§5.6's harvest windows are inclusive season-local days from day 1")
		assert(SPECIES_HARVEST_LAST_DAY[species] <= DAYS_PER_SEASON,
			"§5.6's harvest windows end inside the 12-day season")
		assert(SPECIES_HARVEST_FIRST_DAY[species] <= SPECIES_HARVEST_LAST_DAY[species],
			"§5.6's harvest window start must not follow its end")
		assert(SPECIES_MATURITY_DAYS[species] > 0, "§5.6's maturities are positive day counts")
	assert(CHILL_FACTOR_LOW * SPECIES_YIELD_MILLI[SPECIES_APPLE] % CHILL_FACTOR_DENOMINATOR == 0,
		"§5.6's 75% low-chill yield is exact at the stated apple figure")


func _assert_species_ids_match_the_compiled_catalog() -> void:
	"""Assert SPECIES_APPLE/SPECIES_PEAR are what the ascending-ASCII compiler produces.

	§4.3: "All gameplay enum numeric values not individually listed are generated once from the
	lexicographically sorted ASCII catalog keys within their own domain". `species_id` is such a
	value, so the ordinals are checked against catalog.gd's compiler rather than against
	themselves -- a renamed or added species then fails here instead of silently repointing
	every table above at the other tree.
	"""
	var compiled: Catalog.DomainResult = Catalog.compile_domain(SPECIES_DOMAIN, SPECIES_KEYS)
	assert(compiled.ok, "the OrchardSpecies catalog must compile")
	assert(compiled.ids.size() == SPECIES_COUNT, "two compiled orchard species ids")
	assert(compiled.ids[&"apple"] == SPECIES_APPLE, "apple is the compiled id SPECIES_APPLE")
	assert(compiled.ids[&"pear"] == SPECIES_PEAR, "pear is the compiled id SPECIES_PEAR")


func _assert_link_arithmetic() -> void:
	"""Assert ruling §3's stated capacity, payload and delta are what these constants produce."""
	assert(RECIPIENT_CAPACITY == 5120, "ruling §3: 4096 farm + 1024 orchard recipients")
	assert(ORCHARD_RECIPIENT_BASE == 4096, "ruling §3: orchard recipients start at 4096")
	assert(LINK_CAPACITY == 30720, "ruling §3: 30720 references")
	assert(LINK_PAYLOAD_BYTES == 245760, "ruling §3: 245760 payload bytes")
	assert(LINK_PAYLOAD_DELTA_BYTES == 49152, "ruling §3: +49152 bytes over the 24576-row table")
	assert(LEGACY_LINK_CAPACITY == FARM_RECIPIENT_CAPACITY * LINKS_PER_RECIPIENT,
		"the superseded 24576 rows are exactly the 4096 farm recipients' six slices")
	assert(CANDIDATE_SCRATCH_BYTES == 120, "ruling §3: 120 scratch bytes for the six-candidate buffer")


func _assert_geometry_matches_the_tile_primitive() -> void:
	"""Assert ruling §3's footprint-centre formula IS GDD §5.1's tile centre, not a second copy.

	For a single tile min == max, so `(min + max + 1) * 1024` must equal `2048 * x + 1024`, which
	is what `resource_nodes.gd` computes. Checked at both ends of the axis and at the 12 m range,
	whose square the ruling states independently of the distance itself.
	"""
	assert(TILE_SIZE_UNITS == 2 * TILE_HALF_UNITS, "GDD §5.1: a tile centre sits half a tile in")
	var sample_tiles: Array[int] = [0, 1, MAP_TILES_X - 1]
	for tile_x: int in sample_tiles:
		var stated: int = tile_x * TILE_SIZE_UNITS + TILE_HALF_UNITS
		assert(_footprint_center_units(tile_x, tile_x) == stated,
			"ruling §3's footprint centre must equal GDD §5.1's tile centre for a 1x1 footprint")
	assert(MAX_CENTER_UNITS == (MAP_TILES_X - 1) * TILE_SIZE_UNITS + TILE_HALF_UNITS,
		"the largest centre is the last tile's own centre")
	assert(POLLINATION_RANGE_UNITS == 12 * 1024, "ruling §3: 12 m at 1024 units/m")
	assert(POLLINATION_RANGE_SQUARED == POLLINATION_RANGE_UNITS * POLLINATION_RANGE_UNITS,
		"ruling §3's 150994944 must be the square of its own 12 m range")
	assert(2 * MAX_CENTER_UNITS * MAX_CENTER_UNITS < IntMath.INT64_MAX,
		"the grid bounds every squared distance well inside int64")


func _assert_calendar_matches_sim_clock() -> void:
	"""Assert this module's day decode is `sim_clock.gd`'s, checked against a real Calendar.

	`sim_clock.gd` decodes a TICK; §5.6's orchard and hive rules are stated in DAYS. Rather than
	re-derive the calendar, the day decode is compared against a Calendar built at that day's
	first tick, at a year boundary, a season boundary and an ordinary day.
	"""
	var sample_days: Array[int] = [1, 12, 13, 48, 49, 121, 1000]
	for day: int in sample_days:
		var calendar: SimClock.Calendar = SimClock.calendar_at((day - MIN_CALENDAR_DAY) * TICKS_PER_DAY)
		assert(calendar.absolute_day == day, "the sample tick must decode to the sampled day")
		assert(season_of_day(day) == calendar.season, "season decode must match sim_clock.gd")
		assert(season_day_of_day(day) == calendar.season_day, "season day must match sim_clock.gd")
		assert(year_of_day(day) == calendar.year, "year decode must match sim_clock.gd")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_allocate_orchard_columns()
	_allocate_hive_columns()
	_link_hive_slot.resize(LINK_CAPACITY)
	_link_hive_generation.resize(LINK_CAPACITY)
	_cand_distance.resize(LINKS_PER_RECIPIENT)
	_cand_persistent_id.resize(LINKS_PER_RECIPIENT)
	_cand_slot.resize(LINKS_PER_RECIPIENT)
	_cand_generation.resize(LINKS_PER_RECIPIENT)


func _allocate_orchard_columns() -> void:
	"""Size §4.2's six OrchardPlot columns and the added index columns at 1024 rows."""
	_o_present.resize(ORCHARD_CAPACITY)
	_o_species_id.resize(ORCHARD_CAPACITY)
	_o_age_days.resize(ORCHARD_CAPACITY)
	_o_health.resize(ORCHARD_CAPACITY)
	_o_chill_days.resize(ORCHARD_CAPACITY)
	_o_tended_today.resize(ORCHARD_CAPACITY)
	_o_harvested_year.resize(ORCHARD_CAPACITY)
	_o_origin_x.resize(ORCHARD_CAPACITY)
	_o_origin_z.resize(ORCHARD_CAPACITY)
	_o_ref_slot.resize(ORCHARD_CAPACITY)
	_o_ref_generation.resize(ORCHARD_CAPACITY)
	_o_live_slots.resize(ORCHARD_CAPACITY)


func _allocate_hive_columns() -> void:
	"""Size §4.2's six Hive fields, the footprint bounds and the added index columns."""
	_h_present.resize(HIVE_CAPACITY)
	_h_building_slot.resize(HIVE_CAPACITY)
	_h_building_generation.resize(HIVE_CAPACITY)
	_h_strength.resize(HIVE_CAPACITY)
	_h_serviced_day.resize(HIVE_CAPACITY)
	_h_feed_milli.resize(HIVE_CAPACITY)
	_h_honey_milli.resize(HIVE_CAPACITY)
	_h_wax_milli.resize(HIVE_CAPACITY)
	_h_min_tile_x.resize(HIVE_CAPACITY)
	_h_min_tile_z.resize(HIVE_CAPACITY)
	_h_max_tile_x.resize(HIVE_CAPACITY)
	_h_max_tile_z.resize(HIVE_CAPACITY)
	_h_ref_slot.resize(HIVE_CAPACITY)
	_h_ref_generation.resize(HIVE_CAPACITY)
	_h_live_slots.resize(HIVE_CAPACITY)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live row's directory slot is released first, so a clear leaks no allocation into a
	directory this store may not own.
	"""
	_release_live_rows()
	_clear_orchard_columns()
	_clear_hive_columns()
	clear_all_links()
	_o_live_count = 0
	_h_live_count = 0
	_cand_count = 0
	if _owns_directory:
		_directory.clear()


func _clear_orchard_columns() -> void:
	"""Empty every §4.2 OrchardPlot column and the added index columns."""
	_o_present.fill(0)
	_o_species_id.fill(SPECIES_NONE)
	_o_age_days.fill(0)
	_o_health.fill(0)
	_o_chill_days.fill(0)
	_o_tended_today.fill(0)
	_o_harvested_year.fill(0)
	_o_origin_x.fill(NO_ROW)
	_o_origin_z.fill(NO_ROW)
	_o_ref_slot.fill(NULL_SLOT)
	_o_ref_generation.fill(NULL_GENERATION)
	_o_live_slots.fill(NULL_SLOT)


func _clear_hive_columns() -> void:
	"""Empty every §4.2 Hive column, the footprint bounds and the added index columns."""
	_h_present.fill(0)
	_h_building_slot.fill(NULL_SLOT)
	_h_building_generation.fill(NULL_GENERATION)
	_h_strength.fill(0)
	_h_serviced_day.fill(NO_SERVICE_DAY)
	_h_feed_milli.fill(0)
	_h_honey_milli.fill(0)
	_h_wax_milli.fill(0)
	_h_min_tile_x.fill(NO_ROW)
	_h_min_tile_z.fill(NO_ROW)
	_h_max_tile_x.fill(NO_ROW)
	_h_max_tile_z.fill(NO_ROW)
	_h_ref_slot.fill(NULL_SLOT)
	_h_ref_generation.fill(NULL_GENERATION)
	_h_live_slots.fill(NULL_SLOT)


func clear_all_links() -> void:
	"""Null every one of ruling §3's 30720 references. The empty reference is `(-1, 0)`."""
	_link_hive_slot.fill(NULL_SLOT)
	_link_hive_generation.fill(NULL_GENERATION)


func _release_live_rows() -> void:
	"""Destroy the directory slot of every live row, so a clear leaks no allocation."""
	for index: int in _o_live_count:
		var slot: int = _o_live_slots[index]
		if slot >= 0 and slot < ORCHARD_CAPACITY and _o_present[slot] == 1:
			_directory.destroy(Vector2i(_o_ref_slot[slot], _o_ref_generation[slot]))
	for index: int in _h_live_count:
		var slot: int = _h_live_slots[index]
		if slot >= 0 and slot < HIVE_CAPACITY and _h_present[slot] == 1:
			_directory.destroy(Vector2i(_h_ref_slot[slot], _h_ref_generation[slot]))


func directory() -> EntityDirectory:
	"""The allocator behind every orchard and hive reference."""
	return _directory


# --- calendar decode, checked against sim_clock.gd in `_init()` -------------------------------------

static func is_calendar_day(day: int) -> bool:
	"""True when `day` is a storable absolute calendar day: day 1 or later, and int32-storable."""
	return day >= MIN_CALENDAR_DAY and IntMath.fits_int32(day)


static func season_of_day(day: int) -> int:
	"""§4.3's 0-3 Season ordinal of an absolute day. Callers validate the day first."""
	return ((day - MIN_CALENDAR_DAY) % DAYS_PER_YEAR) / DAYS_PER_SEASON


static func season_day_of_day(day: int) -> int:
	"""The season-local day 1..12 of an absolute day. Callers validate the day first."""
	return (day - MIN_CALENDAR_DAY) % DAYS_PER_SEASON + FIRST_SEASON_DAY


static func year_of_day(day: int) -> int:
	"""The 1-based year of an absolute day. Callers validate the day first."""
	return (day - MIN_CALENDAR_DAY) / DAYS_PER_YEAR + FIRST_YEAR


static func first_day_of_year(year: int) -> int:
	"""The absolute day that opens a year: spring, season-local day 1."""
	return (year - FIRST_YEAR) * DAYS_PER_YEAR + MIN_CALENDAR_DAY


static func is_growing_season(season: int) -> bool:
	"""§5.6's spring/summer orchard care season, the one that gains and loses tree health."""
	return season == SEASON_SPRING or season == SEASON_SUMMER


# --- §5.6 orchard table readers ----------------------------------------------------------------------

static func is_species(species_id: int) -> bool:
	"""True when `species_id` names one of §5.6's two orchard rows. SPECIES_NONE is not one."""
	return species_id >= 0 and species_id < SPECIES_COUNT


func species_key_of(species_id: int) -> StringName:
	"""The catalog key of a species row, or the empty StringName when it names no row."""
	if not is_species(species_id):
		return &""
	return SPECIES_KEYS[species_id]


func sapling_item_key_of(species_id: int) -> StringName:
	"""§5.6's "Plant cost/block" sapling item key, or the empty StringName for an unknown row."""
	if not is_species(species_id):
		return &""
	return SPECIES_SAPLING_ITEM_KEYS[species_id]


func maturity_days_of(species_id: int) -> IntMath.IntResult:
	"""§5.6's "Maturity" column: apple 96 days, pear 144 days."""
	return _read_species(species_id, SPECIES_MATURITY_DAYS)


func annual_yield_milli_of(species_id: int) -> IntMath.IntResult:
	"""§5.6's "Yield/mature tree/year" column in milli-units, before health/pollination/chill."""
	return _read_species(species_id, SPECIES_YIELD_MILLI)


func harvest_first_day_of(species_id: int) -> IntMath.IntResult:
	"""§5.6's "Harvest" column, inclusive first season-local autumn day."""
	return _read_species(species_id, SPECIES_HARVEST_FIRST_DAY)


func harvest_last_day_of(species_id: int) -> IntMath.IntResult:
	"""§5.6's "Harvest" column, inclusive last season-local autumn day."""
	return _read_species(species_id, SPECIES_HARVEST_LAST_DAY)


func _read_species(species_id: int, column: Array[int]) -> IntMath.IntResult:
	"""Read one §5.6 orchard-table column, refusing an unknown species rather than defaulting."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_species(species_id):
		out.refuse(String(REFUSE_INVALID_SPECIES))
		return out
	out.succeed(column[species_id])
	return out


static func is_harvest_window(species_id: int, season: int, season_day: int) -> bool:
	"""True when §5.6's "Harvest" column admits this species on this season-local day.

	Both endpoints are inclusive. An out-of-range argument reports false, because it names no
	legal window at all.
	"""
	if not is_species(species_id) or season != SPECIES_HARVEST_SEASON:
		return false
	if season_day < FIRST_SEASON_DAY or season_day > DAYS_PER_SEASON:
		return false
	return season_day >= SPECIES_HARVEST_FIRST_DAY[species_id] \
		and season_day <= SPECIES_HARVEST_LAST_DAY[species_id]


static func is_harvest_day(species_id: int, day: int) -> bool:
	"""True when an absolute day falls inside §5.6's harvest window for this species."""
	if not is_calendar_day(day):
		return false
	return is_harvest_window(species_id, season_of_day(day), season_day_of_day(day))


# --- ruling §3 geometry ------------------------------------------------------------------------------

static func is_tile_coordinate(value: int) -> bool:
	"""True when `value` is an exterior-grid tile coordinate on either axis (§5.1's 128x128)."""
	return value >= 0 and value < MAP_TILES_X


static func is_footprint(min_tile_x: int, min_tile_z: int, max_tile_x: int,
		max_tile_z: int) -> bool:
	"""True when the four bounds are an on-grid, non-inverted rectangle of committed tiles.

	Apiary ROTATION is resolved by the caller before the bounds are taken (ruling §3); this store
	receives an axis-aligned bounding rectangle and never a rotation angle.
	"""
	if not is_tile_coordinate(min_tile_x) or not is_tile_coordinate(max_tile_x):
		return false
	if not is_tile_coordinate(min_tile_z) or not is_tile_coordinate(max_tile_z):
		return false
	return min_tile_x <= max_tile_x and min_tile_z <= max_tile_z


static func _footprint_center_units(min_tile: int, max_tile: int) -> int:
	"""Ruling §3's `(min_tile + max_tile + 1) * 1024` on one axis, for validated bounds.

	This handles even dimensions without rounding, which is the whole reason the ruling states it
	in min/max form rather than as a midpoint; `_init()` checks it against GDD §5.1's tile centre.
	"""
	return (min_tile + max_tile + 1) * TILE_HALF_UNITS


func footprint_center_units(min_tile: int, max_tile: int) -> IntMath.IntResult:
	"""Ruling §3's footprint-centre coordinate on one axis, or an explicit refusal off-grid."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_coordinate(min_tile) or not is_tile_coordinate(max_tile) or min_tile > max_tile:
		out.refuse(String(REFUSE_INVALID_FOOTPRINT))
		return out
	out.succeed(_footprint_center_units(min_tile, max_tile))
	return out


static func is_in_pollination_range(squared_distance: int) -> bool:
	"""Ruling §3's inclusive test `dx*dx + dz*dz <= 150994944`, i.e. 12 m at 1024 units/m.

	A negative argument is not a distance and reports false rather than passing the bound.
	"""
	return squared_distance >= 0 and squared_distance <= POLLINATION_RANGE_SQUARED


func squared_distance(ax: int, az: int, bx: int, bz: int) -> IntMath.IntResult:
	"""Ruling §3's int64 squared horizontal distance. See squared_distance_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	squared_distance_into(ax, az, bx, bz, out)
	return out


static func squared_distance_into(ax: int, az: int, bx: int, bz: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating squared_distance(): `dx*dx + dz*dz` in checked int64, no square root.

	Every multiplication and the sum are checked, so an out-of-grid coordinate refuses rather
	than wrapping into a small "distance" that would put a hive inside range.
	"""
	if not IntMath.checked_add_into(ax, -bx, out):
		return false
	var dx: int = out.value
	if not IntMath.checked_mul_into(dx, dx, out):
		return false
	var x_squared: int = out.value
	if not IntMath.checked_add_into(az, -bz, out):
		return false
	var dz: int = out.value
	if not IntMath.checked_mul_into(dz, dz, out):
		return false
	return IntMath.checked_add_into(x_squared, out.value, out)


# --- ruling §3 owner-major index -------------------------------------------------------------------

static func is_farm_row(farm_row: int) -> bool:
	"""True when `farm_row` is one of FarmPlot's 4096 typed rows."""
	return farm_row >= 0 and farm_row < FARM_RECIPIENT_CAPACITY


static func is_orchard_row(orchard_row: int) -> bool:
	"""True when `orchard_row` is one of OrchardPlot's 1024 typed rows."""
	return orchard_row >= 0 and orchard_row < ORCHARD_CAPACITY


static func is_recipient_index(recipient: int) -> bool:
	"""True when `recipient` is one of the 5120 pollination recipients."""
	return recipient >= 0 and recipient < RECIPIENT_CAPACITY


func recipient_index_of_farm_row(farm_row: int) -> IntMath.IntResult:
	"""Ruling §3's `recipient_index(FarmPlot typed row p) = p`, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_farm_row(farm_row):
		out.refuse(String(REFUSE_INVALID_ROW))
		return out
	out.succeed(farm_row)
	return out


func recipient_index_of_orchard_row(orchard_row: int) -> IntMath.IntResult:
	"""Ruling §3's `recipient_index(OrchardPlot typed row o) = 4096 + o`, or a refusal.

	This is the line blocker U6 was missing: without the 4096 base, orchard row 0 aliases farm
	row 0 and the 1024 orchard recipients have no independent slice at all.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_orchard_row(orchard_row):
		out.refuse(String(REFUSE_INVALID_ROW))
		return out
	out.succeed(ORCHARD_RECIPIENT_BASE + orchard_row)
	return out


func link_row_of(recipient: int, link_index: int) -> IntMath.IntResult:
	"""Ruling §3's `link_row(recipient, k) = 6*recipient_index + k`, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_recipient_index(recipient):
		out.refuse(String(REFUSE_INVALID_ROW))
		return out
	if link_index < 0 or link_index >= LINKS_PER_RECIPIENT:
		out.refuse(String(REFUSE_INVALID_LINK_INDEX))
		return out
	out.succeed(_link_row(recipient, link_index))
	return out


static func _link_row(recipient: int, link_index: int) -> int:
	"""Ruling §3's link row for validated arguments."""
	return recipient * LINKS_PER_RECIPIENT + link_index


# --- ruling §3 candidate selection ------------------------------------------------------------------

func _is_hive_eligible(slot: int) -> bool:
	"""Ruling §3's "healthy, active" filter, applied BEFORE the six-entry buffer.

	Healthy is §5.6's `strength >= 5000`, which already implies active (`strength > 0`), because
	§5.6 abandons a hive only at strength 0. Applying this before the buffer is exactly what stops
	six unhealthy neighbours from hiding a qualifying seventh hive.
	"""
	return _h_present[slot] == 1 and _h_strength[slot] >= HIVE_HEALTHY_STRENGTH


func _select_candidates(center_x: int, center_z: int) -> StringName:
	"""Fill the six-candidate scratch with the eligible in-range hives, best first.

	Ordered by squared distance then persistent hive ID; at most six are retained and further
	hives are discarded, which is ruling §3's "further hives add no yield". Returns REFUSE_NONE,
	or the refusal of an arithmetic failure -- never a partially filled buffer read as complete.
	"""
	_cand_count = 0
	for index: int in _h_live_count:
		var slot: int = _h_live_slots[index]
		if not _is_hive_eligible(slot):
			continue
		var hive_x: int = _footprint_center_units(_h_min_tile_x[slot], _h_max_tile_x[slot])
		var hive_z: int = _footprint_center_units(_h_min_tile_z[slot], _h_max_tile_z[slot])
		if not squared_distance_into(center_x, center_z, hive_x, hive_z, _math):
			_cand_count = 0
			return REFUSE_OVERFLOW
		var distance: int = _math.value
		if not is_in_pollination_range(distance):
			continue
		var ref: Vector2i = Vector2i(_h_ref_slot[slot], _h_ref_generation[slot])
		_insert_candidate(distance, _directory.get_persistent_id(ref), ref)
	return REFUSE_NONE


func _insert_candidate(distance: int, persistent_id: int, ref: Vector2i) -> void:
	"""Insert one eligible in-range hive into the ordered six-entry buffer.

	The buffer is a fixed six-slot insertion sort, so a refresh allocates nothing. A seventh
	candidate is admitted only when it ranks before the current sixth, and then displaces it.
	"""
	var index: int = _cand_count
	if index >= LINKS_PER_RECIPIENT:
		if not _ranks_before(distance, persistent_id, LINKS_PER_RECIPIENT - 1):
			return
		index = LINKS_PER_RECIPIENT - 1
	else:
		_cand_count += 1
	while index > 0 and _ranks_before(distance, persistent_id, index - 1):
		_copy_candidate(index - 1, index)
		index -= 1
	_cand_distance[index] = distance
	_cand_persistent_id[index] = persistent_id
	_cand_slot[index] = ref.x
	_cand_generation[index] = ref.y


func _ranks_before(distance: int, persistent_id: int, index: int) -> bool:
	"""Ruling §3's order: squared distance ascending, then persistent hive ID ascending.

	The persistent ID is the tiebreak precisely because it is never reused, so two hives at the
	same distance order the same way in every world that created them in the same order.
	"""
	if distance != _cand_distance[index]:
		return distance < _cand_distance[index]
	return persistent_id < _cand_persistent_id[index]


func _copy_candidate(from_index: int, to_index: int) -> void:
	"""Move one candidate down the buffer during insertion, all four columns together."""
	_cand_distance[to_index] = _cand_distance[from_index]
	_cand_persistent_id[to_index] = _cand_persistent_id[from_index]
	_cand_slot[to_index] = _cand_slot[from_index]
	_cand_generation[to_index] = _cand_generation[from_index]


func _write_slice(recipient: int) -> void:
	"""Write the selected candidates into a recipient's six-entry slice and null-fill the tail.

	The tail is rewritten on every refresh, not merely left alone, so a slice that used to hold
	six hives and now qualifies for two cannot keep four stale references in its unused entries.
	"""
	var base: int = _link_row(recipient, 0)
	for link_index: int in LINKS_PER_RECIPIENT:
		if link_index < _cand_count:
			_link_hive_slot[base + link_index] = _cand_slot[link_index]
			_link_hive_generation[base + link_index] = _cand_generation[link_index]
			continue
		_link_hive_slot[base + link_index] = NULL_SLOT
		_link_hive_generation[base + link_index] = NULL_GENERATION


func _slice_matches_candidates(recipient: int) -> bool:
	"""True when a recipient's stored slice is exactly the canonical selection in the scratch."""
	var base: int = _link_row(recipient, 0)
	for link_index: int in LINKS_PER_RECIPIENT:
		var expected_slot: int = NULL_SLOT
		var expected_generation: int = NULL_GENERATION
		if link_index < _cand_count:
			expected_slot = _cand_slot[link_index]
			expected_generation = _cand_generation[link_index]
		if _link_hive_slot[base + link_index] != expected_slot:
			return false
		if _link_hive_generation[base + link_index] != expected_generation:
			return false
	return true


func _clear_slice(recipient: int) -> void:
	"""Null every entry of one recipient's slice. The empty reference is `(-1, 0)`."""
	var base: int = _link_row(recipient, 0)
	for link_index: int in LINKS_PER_RECIPIENT:
		_link_hive_slot[base + link_index] = NULL_SLOT
		_link_hive_generation[base + link_index] = NULL_GENERATION


# --- ruling §3 refresh, synchronous and caller-committed ------------------------------------------

func refresh_farm_links(farm_row: int, tile_x: int, tile_z: int) -> OpResult:
	"""Recompute one FarmPlot tile's slice. Returns the number of eligible hives it now links.

	The crop tile's coordinates are the caller's, because a FarmPlot's tile lives in `farming.gd`
	and this store never reads it. A crop tile has min == max, so its centre is ruling §3's
	`(x + x + 1) * 1024` -- GDD §5.1's own tile centre.
	"""
	if not is_farm_row(farm_row):
		return _refuse(REFUSE_INVALID_ROW)
	if not is_tile_coordinate(tile_x) or not is_tile_coordinate(tile_z):
		return _refuse(REFUSE_INVALID_TILE)
	var refusal: StringName = _select_candidates(_footprint_center_units(tile_x, tile_x),
		_footprint_center_units(tile_z, tile_z))
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	_write_slice(farm_row)
	return _succeed(_cand_count, NULL_REF)


func check_farm_links(farm_row: int, tile_x: int, tile_z: int) -> bool:
	"""True when a FarmPlot's stored slice already equals the canonical selection.

	A pure comparison: it writes the candidate scratch and NOTHING else, because ruling §3 says a
	read never repairs links. This is the reader that proves a caller honoured the synchronous
	refresh discipline after a hive change.
	"""
	if not is_farm_row(farm_row):
		return false
	if not is_tile_coordinate(tile_x) or not is_tile_coordinate(tile_z):
		return false
	if _select_candidates(_footprint_center_units(tile_x, tile_x),
			_footprint_center_units(tile_z, tile_z)) != REFUSE_NONE:
		return false
	return _slice_matches_candidates(farm_row)


func clear_farm_links(farm_row: int) -> OpResult:
	"""Null one FarmPlot recipient's slice: the FarmPlot lifecycle's obligation on destroy.

	Ruling §3 requires the owner lifecycle to clear its slice "including on typed-slot reuse".
	`farming.gd` owns that lifecycle and is not called from here, so the join that destroys or
	recreates a FarmPlot MUST call this. See the header's BLOCKED note.
	"""
	if not is_farm_row(farm_row):
		return _refuse(REFUSE_INVALID_ROW)
	_clear_slice(farm_row)
	return _succeed(0, NULL_REF)


func refresh_orchard_links(orchard_ref: Vector2i) -> OpResult:
	"""Recompute one orchard block's slice from its own 4x4 footprint centre."""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	var refusal: StringName = _refresh_orchard_slot(slot)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	return _succeed(_cand_count, orchard_ref)


func _refresh_orchard_slot(slot: int) -> StringName:
	"""Recompute the slice of a validated live orchard row. Returns REFUSE_NONE on success."""
	var refusal: StringName = _select_candidates(_orchard_center_x(slot), _orchard_center_z(slot))
	if refusal != REFUSE_NONE:
		return refusal
	_write_slice(ORCHARD_RECIPIENT_BASE + slot)
	return REFUSE_NONE


func refresh_all_orchard_links() -> OpResult:
	"""Recompute every live orchard's slice. Returns how many slices were rewritten.

	This is what a committed hive placement, destruction, footprint change or eligibility
	crossing runs synchronously. It sweeps the live orchards rather than consulting a reverse
	index, because ruling §3 excludes any later reverse index from this table's budget.
	"""
	var refreshed: int = 0
	for index: int in _o_live_count:
		var refusal: StringName = _refresh_orchard_slot(_o_live_slots[index])
		if refusal != REFUSE_NONE:
			return _refuse(refusal)
		refreshed += 1
	return _succeed(refreshed, NULL_REF)


func check_orchard_links(orchard_ref: Vector2i) -> bool:
	"""True when an orchard's stored slice already equals the canonical selection. Mutates nothing."""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return false
	if _select_candidates(_orchard_center_x(slot), _orchard_center_z(slot)) != REFUSE_NONE:
		return false
	return _slice_matches_candidates(ORCHARD_RECIPIENT_BASE + slot)


func _orchard_center_x(slot: int) -> int:
	"""Ruling §3's block centre on x: an orchard uses its 4x4 block, so max = min + 3."""
	return _footprint_center_units(_o_origin_x[slot], _o_origin_x[slot] + BLOCK_SIZE - 1)


func _orchard_center_z(slot: int) -> int:
	"""Ruling §3's block centre on z: an orchard uses its 4x4 block, so max = min + 3."""
	return _footprint_center_units(_o_origin_z[slot], _o_origin_z[slot] + BLOCK_SIZE - 1)


# --- ruling §3 slice readers: they never repair and never mutate -----------------------------------

func farm_link_at(farm_row: int, link_index: int) -> OpResult:
	"""One entry of a FarmPlot's slice as an EntityRef; `(-1, 0)` for an empty tail entry."""
	if not is_farm_row(farm_row):
		return _refuse(REFUSE_INVALID_ROW)
	return _link_at(farm_row, link_index)


func orchard_link_at(orchard_row: int, link_index: int) -> OpResult:
	"""One entry of an orchard's slice as an EntityRef; `(-1, 0)` for an empty tail entry."""
	if not is_orchard_row(orchard_row):
		return _refuse(REFUSE_INVALID_ROW)
	return _link_at(ORCHARD_RECIPIENT_BASE + orchard_row, link_index)


func _link_at(recipient: int, link_index: int) -> OpResult:
	"""One entry of a validated recipient's slice. An empty entry is success carrying `(-1, 0)`."""
	if link_index < 0 or link_index >= LINKS_PER_RECIPIENT:
		return _refuse(REFUSE_INVALID_LINK_INDEX)
	var row: int = _link_row(recipient, link_index)
	return _succeed(0, Vector2i(_link_hive_slot[row], _link_hive_generation[row]))


func is_slice_valid(recipient: int) -> bool:
	"""True when a recipient's slice is a well-formed, live, unique, still-eligible selection.

	Checks, in ruling §3's own terms: every non-empty entry resolves to a LIVE hive of the right
	kind (a stale reference fails), no hive appears twice (a duplicate fails), the empty entries
	are a suffix (a hole fails), and every linked hive is still healthy -- because an eligibility
	crossing that was not followed by a synchronous refresh leaves a slice that would otherwise
	pay a multiplier the hive no longer earns. It does NOT recompute the selection; that is
	`check_farm_links()`/`check_orchard_links()`.
	"""
	if not is_recipient_index(recipient):
		return false
	var base: int = _link_row(recipient, 0)
	var seen: int = 0
	for link_index: int in LINKS_PER_RECIPIENT:
		var slot: int = _link_hive_slot[base + link_index]
		var generation: int = _link_hive_generation[base + link_index]
		if slot == NULL_SLOT:
			return _is_empty_suffix(base, link_index) and generation == NULL_GENERATION
		if not _is_live_eligible_link(Vector2i(slot, generation)):
			return false
		if _duplicates_earlier_link(base, link_index, slot, generation):
			return false
		seen += 1
	return seen == LINKS_PER_RECIPIENT


func _is_empty_suffix(base: int, from_index: int) -> bool:
	"""True when every entry from `from_index` on is the empty reference `(-1, 0)`."""
	for link_index: int in range(from_index, LINKS_PER_RECIPIENT):
		if _link_hive_slot[base + link_index] != NULL_SLOT:
			return false
		if _link_hive_generation[base + link_index] != NULL_GENERATION:
			return false
	return true


func _is_live_eligible_link(ref: Vector2i) -> bool:
	"""True when a stored link still names a live, healthy hive of this store's own."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HIVE):
		return false
	var slot: int = _directory.get_typed_row(ref)
	if slot < 0 or slot >= HIVE_CAPACITY:
		return false
	return _is_hive_eligible(slot)


func _duplicates_earlier_link(base: int, link_index: int, slot: int, generation: int) -> bool:
	"""True when this entry repeats a hive already named earlier in the same slice."""
	for earlier: int in link_index:
		if _link_hive_slot[base + earlier] == slot \
				and _link_hive_generation[base + earlier] == generation:
			return true
	return false


func farm_hive_count_into(farm_row: int, out: IntMath.IntResult) -> bool:
	"""Eligible hives linked to a FarmPlot tile, 0..6. Refuses a stale or duplicated slice."""
	if not is_farm_row(farm_row):
		return out.refuse(String(REFUSE_INVALID_ROW))
	return _slice_count_into(farm_row, out)


func orchard_hive_count_into(orchard_row: int, out: IntMath.IntResult) -> bool:
	"""Eligible hives linked to an orchard block, 0..6. Refuses a stale or duplicated slice."""
	if not is_orchard_row(orchard_row):
		return out.refuse(String(REFUSE_INVALID_ROW))
	return _slice_count_into(ORCHARD_RECIPIENT_BASE + orchard_row, out)


func _slice_count_into(recipient: int, out: IntMath.IntResult) -> bool:
	"""Count a validated recipient's non-empty links, refusing rather than repairing a bad slice.

	`0` is a legal answer -- no hive in range -- so this is an `_into` reader; a refusal never
	arrives as a number that could be mistaken for "no hives".
	"""
	if not is_slice_valid(recipient):
		return out.refuse(String(REFUSE_LINKS_STALE))
	var base: int = _link_row(recipient, 0)
	var total: int = 0
	for link_index: int in LINKS_PER_RECIPIENT:
		if _link_hive_slot[base + link_index] == NULL_SLOT:
			break
		total += 1
	return out.succeed(total)


# --- REQ-SET-082 the bounded one/two-hive multiplier ------------------------------------------------

static func is_crop_id(crop_id: int) -> bool:
	"""True when `crop_id` names one of `farming.gd`'s five §5.6 crop rows.

	The bound is `farming.gd`'s own CROP_COUNT, read from it; this module compiles no second crop
	table and `farming.gd`'s equivalent predicate is an instance method it cannot call statically.
	"""
	return crop_id >= 0 and crop_id < Farming.CROP_COUNT


static func is_pollinated_crop(crop_id: int) -> bool:
	"""True for §5.6's one pollinated field crop, beans. Every other crop stays at 1000."""
	return crop_id == POLLINATED_CROP_ID


static func pollination_factor_for_count(hive_count: int) -> int:
	"""§5.6's factor for a count of eligible healthy hives: 0 -> 1000, 1 -> 1100, 2+ -> 1150.

	REQ-SET-082's "ignore further hives for that crop": three, six or sixty hives all pay 1150.
	A negative count names no hive and takes the neutral factor.
	"""
	if hive_count <= 0:
		return POLLINATION_FACTOR_NEUTRAL
	if hive_count == 1:
		return POLLINATION_FACTOR_ONE_HIVE
	return POLLINATION_FACTOR_TWO_HIVES


func farm_pollination_factor_into(farm_row: int, crop_id: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-082's factor for the crop standing on a FarmPlot tile, for `farming.gd`'s yield.

	This is the source of the `pollination_factor` parameter `farming.gd`'s `harvest()` has taken
	since increment 6. An unpollinated crop is 1000 without consulting the slice at all, which is
	why a grain tile beside six hives still pays exactly 1000.
	"""
	if not is_farm_row(farm_row):
		return out.refuse(String(REFUSE_INVALID_ROW))
	if not is_crop_id(crop_id):
		return out.refuse(String(REFUSE_INVALID_CROP))
	if not is_pollinated_crop(crop_id):
		return out.succeed(POLLINATION_FACTOR_NEUTRAL)
	if not _slice_count_into(farm_row, out):
		return false
	return out.succeed(pollination_factor_for_count(out.value))


func orchard_pollination_factor_into(orchard_row: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-082's factor for orchard fruit, which §5.6 pollinates like beans."""
	if not is_orchard_row(orchard_row):
		return out.refuse(String(REFUSE_INVALID_ROW))
	if not _slice_count_into(ORCHARD_RECIPIENT_BASE + orchard_row, out):
		return false
	return out.succeed(pollination_factor_for_count(out.value))


# --- OrchardPlot lifecycle ---------------------------------------------------------------------------

func is_orchard_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a live orchard block."""
	return slot >= 0 and slot < ORCHARD_CAPACITY and _o_present[slot] == 1


func _orchard_slot_of(orchard_ref: Vector2i) -> int:
	"""The live typed row of an orchard reference, or NO_ROW for a stale or wrong-kind one."""
	if not _directory.is_valid_of_kind(orchard_ref, EntityDirectory.KIND_ORCHARD_PLOT):
		return NO_ROW
	var slot: int = _directory.get_typed_row(orchard_ref)
	if not is_orchard_present(slot):
		return NO_ROW
	return slot


static func is_block_origin(origin_x: int, origin_z: int) -> bool:
	"""True when a 4x4 orchard block starting here lies wholly inside §5.1's 128x128 grid."""
	if origin_x < 0 or origin_z < 0:
		return false
	return origin_x + BLOCK_SIZE <= MAP_TILES_X and origin_z + BLOCK_SIZE <= MAP_TILES_Z


func is_block_free(origin_x: int, origin_z: int) -> bool:
	"""True when no live orchard block overlaps the 4x4 block starting here.

	FARM PLOTS ARE NOT CHECKED and cannot be: their tiles live in `farming.gd`, which this store
	never reads. `block_bounds_of()` publishes the rectangle for the caller to check there.
	"""
	for index: int in _o_live_count:
		var slot: int = _o_live_slots[index]
		if origin_x + BLOCK_SIZE <= _o_origin_x[slot] or _o_origin_x[slot] + BLOCK_SIZE <= origin_x:
			continue
		if origin_z + BLOCK_SIZE <= _o_origin_z[slot] or _o_origin_z[slot] + BLOCK_SIZE <= origin_z:
			continue
		return false
	return true


func plant_orchard(origin_x: int, origin_z: int, species_id: int, day: int) -> OpResult:
	"""Plant one 4x4 orchard block. Returns the new row and reference; costs are §5.6 constants.

	§5.6: "Each orchard block contains one modeled large fruit tree", planted for
	`sapling_<species> 1, compost 4`. The materials are the caller's to consume -- no
	`InventoryLot` is touched here. Age starts at 0, health at 10000 and the chill counter at 0;
	the block's pollination slice is cleared and then refreshed synchronously, so a newly planted
	tree can never inherit the links of whatever occupied its typed row before.
	"""
	var refusal: StringName = _refuse_plant(origin_x, origin_z, species_id, day)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_ORCHARD_PLOT)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_orchard(slot, ref, origin_x, origin_z, species_id)
	_clear_slice(ORCHARD_RECIPIENT_BASE + slot)
	_refresh_orchard_slot(slot)
	return _succeed(slot, ref)


func _refuse_plant(origin_x: int, origin_z: int, species_id: int, day: int) -> StringName:
	"""REFUSE_NONE when §5.6 admits this planting, otherwise the one reason it does not."""
	if not is_species(species_id):
		return REFUSE_INVALID_SPECIES
	if not is_calendar_day(day):
		return REFUSE_INVALID_DAY
	if not is_block_origin(origin_x, origin_z):
		return REFUSE_INVALID_BLOCK
	if not is_block_free(origin_x, origin_z):
		return REFUSE_BLOCK_OCCUPIED
	return REFUSE_NONE


func _write_created_orchard(slot: int, ref: Vector2i, origin_x: int, origin_z: int,
		species_id: int) -> void:
	"""Write every §4.2 column of a newly planted block before it is published as live."""
	_o_species_id[slot] = species_id
	_o_age_days[slot] = 0
	_o_health[slot] = HEALTH_MAX
	_o_chill_days[slot] = 0
	_o_tended_today[slot] = 0
	_o_harvested_year[slot] = 0
	_o_origin_x[slot] = origin_x
	_o_origin_z[slot] = origin_z
	_o_ref_slot[slot] = ref.x
	_o_ref_generation[slot] = ref.y
	_o_present[slot] = 1
	_insert_live_orchard(slot)


func remove_orchard(orchard_ref: Vector2i) -> OpResult:
	"""Remove one orchard block. Returns §5.6's wood 8; no sapling is refunded.

	The block's pollination slice is cleared as part of the removal, which is ruling §3's "the
	owner lifecycle clears its slice, including on typed-slot reuse".
	"""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	_clear_slice(ORCHARD_RECIPIENT_BASE + slot)
	_o_present[slot] = 0
	_o_species_id[slot] = SPECIES_NONE
	_o_age_days[slot] = 0
	_o_health[slot] = 0
	_o_chill_days[slot] = 0
	_o_tended_today[slot] = 0
	_o_harvested_year[slot] = 0
	_o_origin_x[slot] = NO_ROW
	_o_origin_z[slot] = NO_ROW
	_o_ref_slot[slot] = NULL_SLOT
	_o_ref_generation[slot] = NULL_GENERATION
	_remove_live_orchard(slot)
	_directory.destroy(orchard_ref)
	return _succeed(REMOVAL_WOOD_MILLI, NULL_REF)


func _insert_live_orchard(slot: int) -> void:
	"""Insert a planted block into the ascending live list, keeping iteration order stable."""
	var index: int = _o_live_count
	while index > 0 and _o_live_slots[index - 1] > slot:
		_o_live_slots[index] = _o_live_slots[index - 1]
		index -= 1
	_o_live_slots[index] = slot
	_o_live_count += 1


func _remove_live_orchard(slot: int) -> void:
	"""Remove a block from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _o_live_count and _o_live_slots[index] != slot:
		index += 1
	if index >= _o_live_count:
		return
	while index + 1 < _o_live_count:
		_o_live_slots[index] = _o_live_slots[index + 1]
		index += 1
	_o_live_count -= 1
	_o_live_slots[_o_live_count] = NULL_SLOT


# --- OrchardPlot readers -------------------------------------------------------------------------------

func orchard_count() -> int:
	"""Number of live orchard blocks."""
	return _o_live_count


func orchard_live_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live orchard row in ascending row order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _o_live_count:
		out.refuse(String(REFUSE_INVALID_ROW))
		return out
	out.succeed(_o_live_slots[index])
	return out


func orchard_ref_of(slot: int) -> Vector2i:
	"""The directory reference of a live orchard row, or the null reference `(-1, 0)`."""
	if not is_orchard_present(slot):
		return NULL_REF
	return Vector2i(_o_ref_slot[slot], _o_ref_generation[slot])


func orchard_row_of(orchard_ref: Vector2i) -> IntMath.IntResult:
	"""The typed row a live orchard reference addresses, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		out.refuse(String(REFUSE_ORCHARD_NOT_PRESENT))
		return out
	out.succeed(slot)
	return out


func species_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `species_id` for a live orchard row, or an explicit refusal."""
	return _read_orchard(slot, _o_species_id)


func age_days_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `age_days`, which §5.6 retains across winter."""
	return _read_orchard(slot, _o_age_days)


func orchard_health_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `health`, on the same 0-10000 scale `farming.gd` uses for crop health."""
	return _read_orchard(slot, _o_health)


func chill_days_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `chill_days`: the CURRENT winter's count, which in autumn is the previous winter's."""
	return _read_orchard(slot, _o_chill_days)


func _read_orchard(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one OrchardPlot column, refusing an absent row rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_orchard_present(slot):
		out.refuse(String(REFUSE_ORCHARD_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


func is_tended_today(slot: int) -> bool:
	"""§4.2's `tended_today`. False for an absent row, which has received no care either."""
	return is_orchard_present(slot) and _o_tended_today[slot] == 1


func is_harvested_year(slot: int) -> bool:
	"""§4.2's `harvested_year`: REQ-SET-080's flag prohibiting a second harvest that year."""
	return is_orchard_present(slot) and _o_harvested_year[slot] == 1


func is_mature(slot: int) -> bool:
	"""True when a block has reached §5.6's maturity for its species. Immature trees yield 0."""
	if not is_orchard_present(slot):
		return false
	return _o_age_days[slot] >= SPECIES_MATURITY_DAYS[_o_species_id[slot]]


func block_bounds_of(slot: int) -> BlockBounds:
	"""REQ-SET-081's occupied block: the inclusive 4x4 tile rectangle this orchard holds.

	Also the rectangle a caller checks against `farming.gd`'s tiles before committing a planting,
	because this store cannot see farm plots.
	"""
	if not is_orchard_present(slot):
		return BlockBounds.new(false, REFUSE_ORCHARD_NOT_PRESENT)
	return BlockBounds.new(true, REFUSE_NONE, _o_origin_x[slot], _o_origin_z[slot],
		_o_origin_x[slot] + BLOCK_SIZE - 1, _o_origin_z[slot] + BLOCK_SIZE - 1)


# --- REQ-SET-079/081 maturity and the first legal annual harvest ------------------------------------

func first_eligible_harvest_day(species_id: int, plant_day: int) -> IntMath.IntResult:
	"""REQ-SET-081's exact first eligible harvest day. See first_eligible_harvest_day_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	first_eligible_harvest_day_into(species_id, plant_day, out)
	return out


func first_eligible_harvest_day_into(species_id: int, plant_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating first_eligible_harvest_day(): the earliest legal harvest of a new planting.

	REQ-SET-079: maturity enables the NEXT legal annual harvest and generates no previous years'
	fruit, so this is the earliest day that is both at or after `plant_day + maturity_days` and
	inside §5.6's autumn window for the species. A tree maturing after its window has passed
	therefore waits a full year rather than back-filling the one it missed.
	"""
	if not is_species(species_id):
		return out.refuse(String(REFUSE_INVALID_SPECIES))
	if not is_calendar_day(plant_day):
		return out.refuse(String(REFUSE_INVALID_DAY))
	if not IntMath.checked_add_into(plant_day, SPECIES_MATURITY_DAYS[species_id], out):
		return false
	var maturity_day: int = out.value
	var year: int = year_of_day(maturity_day)
	var harvest_day: int = _first_window_day_of_year(species_id, year + 1)
	if maturity_day <= _last_window_day_of_year(species_id, year):
		harvest_day = maxi(_first_window_day_of_year(species_id, year), maturity_day)
	if not IntMath.fits_int32(harvest_day):
		return out.refuse(String(REFUSE_OVERFLOW))
	return out.succeed(harvest_day)


func _first_window_day_of_year(species_id: int, year: int) -> int:
	"""The absolute day of the first day of one year's autumn harvest window for a species."""
	return first_day_of_year(year) + SPECIES_HARVEST_SEASON * DAYS_PER_SEASON \
		+ SPECIES_HARVEST_FIRST_DAY[species_id] - FIRST_SEASON_DAY


func _last_window_day_of_year(species_id: int, year: int) -> int:
	"""The absolute day of the last day of one year's autumn harvest window for a species."""
	return first_day_of_year(year) + SPECIES_HARVEST_SEASON * DAYS_PER_SEASON \
		+ SPECIES_HARVEST_LAST_DAY[species_id] - FIRST_SEASON_DAY


func preview_planting(origin_x: int, origin_z: int, species_id: int,
		day: int) -> PlantingPreview:
	"""REQ-SET-081: the exact first eligible harvest year/day and occupied block, before confirming.

	Refuses for exactly the reasons `plant_orchard()` would, so a preview that succeeds describes
	a planting the store will accept, and one that refuses names the same blocker the player would
	otherwise hit at confirmation.
	"""
	var preview: PlantingPreview = PlantingPreview.new()
	preview.error = _refuse_plant(origin_x, origin_z, species_id, day)
	if preview.error != REFUSE_NONE:
		return preview
	if not first_eligible_harvest_day_into(species_id, day, _math):
		preview.error = StringName(_math.error)
		return preview
	_fill_preview(preview, origin_x, origin_z, species_id, day, _math.value)
	return preview


func _fill_preview(preview: PlantingPreview, origin_x: int, origin_z: int, species_id: int,
		day: int, harvest_day: int) -> void:
	"""Write every field of a successful REQ-SET-081 preview."""
	preview.ok = true
	preview.species_id = species_id
	preview.plant_day = day
	preview.maturity_day = day + SPECIES_MATURITY_DAYS[species_id]
	preview.first_harvest_day = harvest_day
	preview.first_harvest_year = year_of_day(harvest_day)
	preview.first_harvest_season = season_of_day(harvest_day)
	preview.first_harvest_season_day = season_day_of_day(harvest_day)
	preview.min_tile_x = origin_x
	preview.min_tile_z = origin_z
	preview.max_tile_x = origin_x + BLOCK_SIZE - 1
	preview.max_tile_z = origin_z + BLOCK_SIZE - 1


# --- §5.6 orchard care, chill and the daily step --------------------------------------------------------

func record_tending(orchard_ref: Vector2i) -> OpResult:
	"""Record §5.6's 20 WU/day care as completed for today. The WU itself lives on the Job.

	Idempotent within a day: the flag is a boolean, so a second completed care task the same day
	cannot bank a second 50 health.
	"""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	_o_tended_today[slot] = 1
	return _succeed(CARE_WORK_MILLI_WU, orchard_ref)


func apply_orchard_day(orchard_ref: Vector2i, day: int, temperature_tenths: int) -> OpResult:
	"""Advance one block by one completed day. Returns its health after the day.

	In order: the year boundary clears REQ-SET-080's harvested flag, age advances (§5.6 retains
	age across winter), spring/summer applies §5.6's -100 untended or +50 tended health, winter
	advances the chill counter, and the day's tending flag is cleared last.
	"""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	if not is_calendar_day(day):
		return _refuse(REFUSE_INVALID_DAY)
	if not IntMath.checked_add_into(_o_age_days[slot], 1, _math) or not IntMath.fits_int32(_math.value):
		return _refuse(REFUSE_OVERFLOW)
	var season: int = season_of_day(day)
	if season == SEASON_SPRING and season_day_of_day(day) == FIRST_SEASON_DAY:
		_o_harvested_year[slot] = 0
	_o_age_days[slot] = _math.value
	_apply_orchard_health_day(slot, season)
	_apply_orchard_chill_day(slot, season, season_day_of_day(day), temperature_tenths)
	_o_tended_today[slot] = 0
	return _succeed(_o_health[slot], orchard_ref)


func _apply_orchard_health_day(slot: int, season: int) -> void:
	"""§5.6: "Untended spring/summer days remove 100 health; tended days restore 50, max 10000"."""
	if not is_growing_season(season):
		return
	var health: int = _o_health[slot] - UNTENDED_HEALTH_LOSS
	if _o_tended_today[slot] == 1:
		health = _o_health[slot] + TENDED_HEALTH_GAIN
	_o_health[slot] = clampi(health, HEALTH_MIN, HEALTH_MAX)


func _apply_orchard_chill_day(slot: int, season: int, season_day: int,
		temperature_tenths: int) -> void:
	"""§5.6's winter chill counter, reset on winter's first day so autumn reads last winter's total.

	Nothing outside winter touches the counter, which is what lets the single §4.2 column answer
	"the previous winter" at every autumn harvest.
	"""
	if season != SEASON_WINTER:
		return
	if season_day == FIRST_SEASON_DAY:
		_o_chill_days[slot] = 0
	if temperature_tenths <= CHILL_TEMPERATURE_MAX_TENTHS:
		_o_chill_days[slot] += 1


func chill_factor_of(slot: int) -> IntMath.IntResult:
	"""§5.6's chill multiplier as a percentage: 100, or 75 below six chill days last winter."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_orchard_present(slot):
		out.refuse(String(REFUSE_ORCHARD_NOT_PRESENT))
		return out
	if _o_chill_days[slot] >= CHILL_DAYS_REQUIRED:
		out.succeed(CHILL_FACTOR_FULL)
		return out
	out.succeed(CHILL_FACTOR_LOW)
	return out


# --- REQ-SET-079/080 the annual harvest ------------------------------------------------------------------

func orchard_yield_milli_into(slot: int, out: IntMath.IntResult) -> bool:
	"""§5.6's orchard yield: base x health/10000 x pollination/1000 x chill/100, floored ONCE.

	A read, not a mutation: this is what a UI panel shows and what `harvest_orchard()` pays. It
	refuses -- it does not repair -- when the block's pollination slice is stale, so a yield can
	never be paid against links the synchronous refresh discipline has not caught up with.
	"""
	if not is_orchard_present(slot):
		return out.refuse(String(REFUSE_ORCHARD_NOT_PRESENT))
	if not is_mature(slot):
		return out.succeed(0)
	if not orchard_pollination_factor_into(slot, out):
		return false
	var pollination: int = out.value
	var chill: int = CHILL_FACTOR_LOW
	if _o_chill_days[slot] >= CHILL_DAYS_REQUIRED:
		chill = CHILL_FACTOR_FULL
	return _yield_product_into(SPECIES_YIELD_MILLI[_o_species_id[slot]], _o_health[slot],
		pollination, chill, out)


func _yield_product_into(base_milli: int, health: int, pollination: int, chill: int,
		out: IntMath.IntResult) -> bool:
	"""`floor(base * health * pollination * chill / (10000 * 1000 * 100))` in checked int64.

	One floor at the end, matching REQ-SET-074's single division, so no intermediate rounding can
	shave a milli-unit off a yield the table states exactly.
	"""
	if not IntMath.checked_mul_into(base_milli, health, out):
		return false
	if not IntMath.checked_mul_into(out.value, pollination, out):
		return false
	if not IntMath.checked_mul_into(out.value, chill, out):
		return false
	var denominator: int = HEALTH_FACTOR_DENOMINATOR * POLLINATION_FACTOR_DENOMINATOR \
		* CHILL_FACTOR_DENOMINATOR
	return IntMath.floor_div_into(out.value, denominator, out)


func harvest_orchard(orchard_ref: Vector2i, day: int) -> OpResult:
	"""REQ-SET-079/080: take this year's fruit once, inside §5.6's window, from a mature tree.

	Sets `harvested_year`, which prohibits a second harvest that year; the flag is cleared only by
	the next year's first day, so no missed year is ever back-filled. Returns the fruit in
	milli-units; creating the lot is `inventory.gd`'s.
	"""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	var refusal: StringName = _refuse_harvest(slot, day)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	if not orchard_yield_milli_into(slot, _math):
		return _refuse(StringName(_math.error))
	_o_harvested_year[slot] = 1
	return _succeed(_math.value, orchard_ref)


func _refuse_harvest(slot: int, day: int) -> StringName:
	"""REFUSE_NONE when §5.6 and REQ-SET-079/080 admit a harvest today, else the one reason."""
	if not is_calendar_day(day):
		return REFUSE_INVALID_DAY
	if not is_mature(slot):
		return REFUSE_NOT_MATURE
	if not is_harvest_day(_o_species_id[slot], day):
		return REFUSE_OUTSIDE_HARVEST_WINDOW
	if _o_harvested_year[slot] == 1:
		return REFUSE_ALREADY_HARVESTED_THIS_YEAR
	return REFUSE_NONE


func restore_orchard_state(orchard_ref: Vector2i, age_days: int, health: int, chill_days: int,
		tended_today: bool, harvested_year: bool) -> OpResult:
	"""Write a loaded block's §4.2 state onto a live row, validating every field first.

	The load path, and the only way this store's orchard columns are written other than by the
	stated §5.6 arithmetic. Refuses the WHOLE restore on any out-of-range field rather than
	storing a plausible-looking one, so a corrupt image cannot enter the world half-applied.
	"""
	var slot: int = _orchard_slot_of(orchard_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_ORCHARD_NOT_PRESENT)
	if age_days < 0 or not IntMath.fits_int32(age_days):
		return _refuse(REFUSE_INVALID_AMOUNT)
	if health < HEALTH_MIN or health > HEALTH_MAX:
		return _refuse(REFUSE_INVALID_AMOUNT)
	if chill_days < 0 or chill_days > DAYS_PER_SEASON:
		return _refuse(REFUSE_INVALID_AMOUNT)
	_o_age_days[slot] = age_days
	_o_health[slot] = health
	_o_chill_days[slot] = chill_days
	_o_tended_today[slot] = 1 if tended_today else 0
	_o_harvested_year[slot] = 1 if harvested_year else 0
	return _succeed(slot, orchard_ref)


func first_harvest_window_day_of_year(species_id: int, year: int) -> IntMath.IntResult:
	"""The absolute day §5.6's autumn window opens for a species in a given year."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _window_arguments_ok(species_id, year, out):
		return out
	out.succeed(_first_window_day_of_year(species_id, year))
	return out


func last_harvest_window_day_of_year(species_id: int, year: int) -> IntMath.IntResult:
	"""The absolute day §5.6's autumn window closes for a species in a given year."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not _window_arguments_ok(species_id, year, out):
		return out
	out.succeed(_last_window_day_of_year(species_id, year))
	return out


func _window_arguments_ok(species_id: int, year: int, out: IntMath.IntResult) -> bool:
	"""Validate a (species, year) pair for the window readers, refusing into `out` if it fails."""
	if not is_species(species_id):
		return out.refuse(String(REFUSE_INVALID_SPECIES))
	if year < FIRST_YEAR:
		return out.refuse(String(REFUSE_INVALID_DAY))
	return true


# --- Hive lifecycle -------------------------------------------------------------------------------------

func is_hive_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a live hive."""
	return slot >= 0 and slot < HIVE_CAPACITY and _h_present[slot] == 1


func _hive_slot_of(hive_ref: Vector2i) -> int:
	"""The live typed row of a hive reference, or NO_ROW for a stale or wrong-kind one."""
	if not _directory.is_valid_of_kind(hive_ref, EntityDirectory.KIND_HIVE):
		return NO_ROW
	var slot: int = _directory.get_typed_row(hive_ref)
	if not is_hive_present(slot):
		return NO_ROW
	return slot


func create_hive(building_ref: Vector2i, min_tile_x: int, min_tile_z: int, max_tile_x: int,
		max_tile_z: int, day: int) -> OpResult:
	"""Colonise one apiary's hive at §5.6's starting strength 8000, at a committed footprint.

	THE FOOTPRINT IS A PARAMETER, NOT A LOOKUP. `Hive.building` is an `EntityRef` to a Building
	and there is no Building store: the bounds of the committed, ROTATED footprint are supplied by
	whoever committed the placement, exactly as `farming.gd` takes `pollination_factor`. The
	building reference is validated for liveness and kind through the directory and is never
	dereferenced. Every live orchard slice is refreshed synchronously, because a new healthy hive
	changes who is eligible before anything reads a yield.
	"""
	if not _directory.is_valid_of_kind(building_ref, EntityDirectory.KIND_BUILDING):
		return _refuse(REFUSE_BUILDING_NOT_PRESENT)
	if not is_footprint(min_tile_x, min_tile_z, max_tile_x, max_tile_z):
		return _refuse(REFUSE_INVALID_FOOTPRINT)
	if not is_calendar_day(day):
		return _refuse(REFUSE_INVALID_DAY)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_HIVE)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_hive(slot, ref, building_ref, min_tile_x, min_tile_z, max_tile_x, max_tile_z, day)
	refresh_all_orchard_links()
	return _succeed(slot, ref)


func _write_created_hive(slot: int, ref: Vector2i, building_ref: Vector2i, min_tile_x: int,
		min_tile_z: int, max_tile_x: int, max_tile_z: int, day: int) -> void:
	"""Write every §4.2 Hive column and the footprint bounds before publishing the row as live."""
	_h_building_slot[slot] = building_ref.x
	_h_building_generation[slot] = building_ref.y
	_h_strength[slot] = HIVE_INITIAL_STRENGTH
	_h_serviced_day[slot] = day
	_h_feed_milli[slot] = 0
	_h_honey_milli[slot] = 0
	_h_wax_milli[slot] = 0
	_h_min_tile_x[slot] = min_tile_x
	_h_min_tile_z[slot] = min_tile_z
	_h_max_tile_x[slot] = max_tile_x
	_h_max_tile_z[slot] = max_tile_z
	_h_ref_slot[slot] = ref.x
	_h_ref_generation[slot] = ref.y
	_h_present[slot] = 1
	_insert_live_hive(slot)


func destroy_hive(hive_ref: Vector2i) -> OpResult:
	"""Remove one hive and release its directory slot, refreshing every orchard slice after it.

	The refresh is what makes ruling §3's "removing a cached hive discovers a previously seventh
	candidate" true for orchard recipients without a reverse index. FARM recipients are the
	caller's to refresh; see the header.
	"""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	_h_present[slot] = 0
	_h_building_slot[slot] = NULL_SLOT
	_h_building_generation[slot] = NULL_GENERATION
	_h_strength[slot] = 0
	_h_serviced_day[slot] = NO_SERVICE_DAY
	_h_feed_milli[slot] = 0
	_h_honey_milli[slot] = 0
	_h_wax_milli[slot] = 0
	_h_min_tile_x[slot] = NO_ROW
	_h_min_tile_z[slot] = NO_ROW
	_h_max_tile_x[slot] = NO_ROW
	_h_max_tile_z[slot] = NO_ROW
	_h_ref_slot[slot] = NULL_SLOT
	_h_ref_generation[slot] = NULL_GENERATION
	_remove_live_hive(slot)
	_directory.destroy(hive_ref)
	refresh_all_orchard_links()
	return _succeed(slot, NULL_REF)


func set_hive_footprint(hive_ref: Vector2i, min_tile_x: int, min_tile_z: int, max_tile_x: int,
		max_tile_z: int) -> OpResult:
	"""Re-declare a hive's committed footprint bounds and refresh every orchard slice.

	For a committed re-placement of the apiary. Rotation is resolved before the bounds are taken.
	"""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	if not is_footprint(min_tile_x, min_tile_z, max_tile_x, max_tile_z):
		return _refuse(REFUSE_INVALID_FOOTPRINT)
	_h_min_tile_x[slot] = min_tile_x
	_h_min_tile_z[slot] = min_tile_z
	_h_max_tile_x[slot] = max_tile_x
	_h_max_tile_z[slot] = max_tile_z
	refresh_all_orchard_links()
	return _succeed(slot, hive_ref)


func _insert_live_hive(slot: int) -> void:
	"""Insert a colonised hive into the ascending live list, keeping iteration order stable."""
	var index: int = _h_live_count
	while index > 0 and _h_live_slots[index - 1] > slot:
		_h_live_slots[index] = _h_live_slots[index - 1]
		index -= 1
	_h_live_slots[index] = slot
	_h_live_count += 1


func _remove_live_hive(slot: int) -> void:
	"""Remove a hive from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _h_live_count and _h_live_slots[index] != slot:
		index += 1
	if index >= _h_live_count:
		return
	while index + 1 < _h_live_count:
		_h_live_slots[index] = _h_live_slots[index + 1]
		index += 1
	_h_live_count -= 1
	_h_live_slots[_h_live_count] = NULL_SLOT


# --- Hive readers ------------------------------------------------------------------------------------------

func hive_count() -> int:
	"""Number of live hives."""
	return _h_live_count


func hive_live_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live hive row in ascending row order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _h_live_count:
		out.refuse(String(REFUSE_INVALID_ROW))
		return out
	out.succeed(_h_live_slots[index])
	return out


func hive_ref_of(slot: int) -> Vector2i:
	"""The directory reference of a live hive row, or the null reference `(-1, 0)`."""
	if not is_hive_present(slot):
		return NULL_REF
	return Vector2i(_h_ref_slot[slot], _h_ref_generation[slot])


func hive_building_ref_of(slot: int) -> Vector2i:
	"""§4.2's `building` EntityRef, stored and returned but never dereferenced here."""
	if not is_hive_present(slot):
		return NULL_REF
	return Vector2i(_h_building_slot[slot], _h_building_generation[slot])


func hive_strength_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `strength`, §5.6's 0-10000 scale with 5000 the healthy line and 0 abandonment."""
	return _read_hive_int(slot, _h_strength)


func hive_serviced_day_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `serviced_day`: the absolute day §5.6's 20 WU service was last completed."""
	return _read_hive_int(slot, _h_serviced_day)


func hive_feed_milli_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `feed_milli`: the honey stocked against §5.6's winter consumption."""
	return _read_hive_long(slot, _h_feed_milli)


func hive_honey_milli_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `honey_milli`: uncollected hive produce, not an InventoryLot."""
	return _read_hive_long(slot, _h_honey_milli)


func hive_wax_milli_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `wax_milli`: uncollected hive produce, not an InventoryLot."""
	return _read_hive_long(slot, _h_wax_milli)


func hive_center_x_of(slot: int) -> IntMath.IntResult:
	"""Ruling §3's footprint centre on x for a live hive, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_hive_present(slot):
		out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
		return out
	out.succeed(_footprint_center_units(_h_min_tile_x[slot], _h_max_tile_x[slot]))
	return out


func hive_center_z_of(slot: int) -> IntMath.IntResult:
	"""Ruling §3's footprint centre on z for a live hive, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_hive_present(slot):
		out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
		return out
	out.succeed(_footprint_center_units(_h_min_tile_z[slot], _h_max_tile_z[slot]))
	return out


func hive_footprint_of(slot: int) -> BlockBounds:
	"""The committed apiary footprint bounds this hive was created or re-placed with."""
	if not is_hive_present(slot):
		return BlockBounds.new(false, REFUSE_HIVE_NOT_PRESENT)
	return BlockBounds.new(true, REFUSE_NONE, _h_min_tile_x[slot], _h_min_tile_z[slot],
		_h_max_tile_x[slot], _h_max_tile_z[slot])


func is_hive_healthy(slot: int) -> bool:
	"""§5.6's "healthy>=5000", the eligibility line ruling §3 selects on."""
	return is_hive_present(slot) and _h_strength[slot] >= HIVE_HEALTHY_STRENGTH


func is_hive_abandoned(slot: int) -> bool:
	"""§5.6: "A hive at 0 strength is abandoned". No column stores this; the strength decides it."""
	return is_hive_present(slot) and _h_strength[slot] <= HIVE_STRENGTH_MIN


func _read_hive_int(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 Hive column, refusing an absent row rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_hive_present(slot):
		out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


func _read_hive_long(slot: int, column: PackedInt64Array) -> IntMath.IntResult:
	"""Read one int64 Hive column, refusing an absent row rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_hive_present(slot):
		out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


# --- §5.6 hive service, feed and produce --------------------------------------------------------------------

func record_hive_service(hive_ref: Vector2i, day: int) -> OpResult:
	"""Record §5.6's 20 WU/day service as completed on `day`. Returns that work quantity.

	The 20 WU itself is R06-JOB-006's job, which is not built and is not called from here; the
	absolute day is what survives a load, a rebuild and a worker replacement.
	"""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	if not is_calendar_day(day):
		return _refuse(REFUSE_INVALID_DAY)
	if _h_strength[slot] <= HIVE_STRENGTH_MIN:
		return _refuse(REFUSE_HIVE_ABANDONED)
	_h_serviced_day[slot] = day
	return _succeed(HIVE_SERVICE_WORK_MILLI_WU, hive_ref)


func add_hive_feed(hive_ref: Vector2i, quantity_milli: int) -> OpResult:
	"""Stock honey against §5.6's winter consumption. Returns the hive's feed after the delivery."""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	if quantity_milli <= 0:
		return _refuse(REFUSE_INVALID_AMOUNT)
	if not IntMath.checked_add_into(_h_feed_milli[slot], quantity_milli, _math):
		return _refuse(REFUSE_OVERFLOW)
	_h_feed_milli[slot] = _math.value
	return _succeed(_h_feed_milli[slot], hive_ref)


func collect_honey(hive_ref: Vector2i) -> OpResult:
	"""Take everything the hive has produced. Returns the honey milli-units; the lot is elsewhere."""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	var collected: int = _h_honey_milli[slot]
	_h_honey_milli[slot] = 0
	return _succeed(collected, hive_ref)


func collect_wax(hive_ref: Vector2i) -> OpResult:
	"""Take everything the hive has produced. Returns the wax milli-units; the lot is elsewhere."""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	var collected: int = _h_wax_milli[slot]
	_h_wax_milli[slot] = 0
	return _succeed(collected, hive_ref)


func recolonize_hive(hive_ref: Vector2i, day: int) -> OpResult:
	"""§5.6: an abandoned hive "can be recolonized in spring with honey 4, wood 2, 60 WU".

	This call is the COMPLETION of that work and of its 3-day wait, in the manner `farming.gd`'s
	`plant()` is a productive start: the materials and the wait are the caller's, and what this
	store owns is the resulting state -- strength back to 8000 and the day recorded as serviced.
	"""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	if not is_calendar_day(day):
		return _refuse(REFUSE_INVALID_DAY)
	if _h_strength[slot] > HIVE_STRENGTH_MIN:
		return _refuse(REFUSE_HIVE_NOT_ABANDONED)
	if season_of_day(day) != SEASON_SPRING:
		return _refuse(REFUSE_NOT_SPRING)
	_h_serviced_day[slot] = day
	_write_hive_strength(slot, HIVE_INITIAL_STRENGTH)
	return _succeed(HIVE_INITIAL_STRENGTH, hive_ref)


# --- REQ-SET-083 deficits, shown before abandonment --------------------------------------------------------

func is_service_due(slot: int, day: int) -> bool:
	"""True when §5.6 requires a service today and it has not been completed.

	Winter "needs feed but no tending labor", so no service is due then; an abandoned hive is
	past service rather than owing one.
	"""
	if not is_hive_present(slot) or not is_calendar_day(day):
		return false
	if season_of_day(day) == SEASON_WINTER or _h_strength[slot] <= HIVE_STRENGTH_MIN:
		return false
	return _h_serviced_day[slot] != day


func service_deficit_days_into(slot: int, day: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-083's service deficit: days since the last completed service, 0 when serviced today.

	Exposed for every live hive, including one still well above the abandonment floor -- that is
	the point of "show feed/service deficits BEFORE abandonment". A hive never serviced at all
	reports the days since the calendar began, because day 0 names no day.
	"""
	if not is_hive_present(slot):
		return out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
	if not is_calendar_day(day):
		return out.refuse(String(REFUSE_INVALID_DAY))
	if _h_serviced_day[slot] >= day:
		return out.succeed(0)
	return IntMath.checked_add_into(day, -_h_serviced_day[slot], out)


func feed_deficit_milli_into(slot: int, day: int, out: IntMath.IntResult) -> bool:
	"""REQ-SET-083's feed deficit: the winter day's 500 milli-U less what the hive holds.

	Outside winter §5.6 requires no feed, so the deficit is 0 there; inside winter it is what is
	still owed before the next daily step charges 500 strength for a missing one.
	"""
	if not is_hive_present(slot):
		return out.refuse(String(REFUSE_HIVE_NOT_PRESENT))
	if not is_calendar_day(day):
		return out.refuse(String(REFUSE_INVALID_DAY))
	if season_of_day(day) != SEASON_WINTER:
		return out.succeed(0)
	if _h_feed_milli[slot] >= HIVE_WINTER_FEED_MILLI_PER_DAY:
		return out.succeed(0)
	return out.succeed(HIVE_WINTER_FEED_MILLI_PER_DAY - _h_feed_milli[slot])


# --- §5.6 the hive's daily step ------------------------------------------------------------------------------

func apply_hive_day(hive_ref: Vector2i, day: int) -> HiveDayResult:
	"""§5.6's completed hive day. See apply_hive_day_into(); this form allocates one result."""
	var out: HiveDayResult = HiveDayResult.new()
	apply_hive_day_into(hive_ref, day, out)
	return out


func apply_hive_day_into(hive_ref: Vector2i, day: int, out: HiveDayResult) -> bool:
	"""Non-allocating apply_hive_day(): advance one hive by one completed day into `out`.

	Spring/summer/autumn: a serviced hive produces `honey 2 U + wax 0.25 U x strength/10000` and,
	in spring only, restores 300 strength AFTER production; an unserviced day removes 200 and
	produces nothing. Winter: no production, `honey 0.5 U/day` consumed from stocked feed, and a
	missing feed removes 500. A hive that reaches 0 is abandoned.
	"""
	out.clear()
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		out.refuse(REFUSE_HIVE_NOT_PRESENT)
		return false
	if not is_calendar_day(day):
		out.refuse(REFUSE_INVALID_DAY)
		return false
	out.strength_before = _h_strength[slot]
	out.serviced = _h_serviced_day[slot] == day
	if season_of_day(day) == SEASON_WINTER:
		_apply_hive_winter_day(slot, out)
	else:
		_apply_hive_working_day(slot, season_of_day(day), out)
	out.strength_after = _h_strength[slot]
	out.abandoned = _h_strength[slot] <= HIVE_STRENGTH_MIN
	out.ok = true
	return true


func _apply_hive_winter_day(slot: int, out: HiveDayResult) -> void:
	"""§5.6's winter day: no produce, 500 milli-U of feed eaten, or 500 strength lost without it."""
	if _h_feed_milli[slot] >= HIVE_WINTER_FEED_MILLI_PER_DAY:
		_h_feed_milli[slot] -= HIVE_WINTER_FEED_MILLI_PER_DAY
		out.feed_consumed_milli = HIVE_WINTER_FEED_MILLI_PER_DAY
		return
	_write_hive_strength(slot, _h_strength[slot] - HIVE_MISSING_FEED_STRENGTH_LOSS)


func _apply_hive_working_day(slot: int, season: int, out: HiveDayResult) -> void:
	"""§5.6's spring/summer/autumn day: produce when serviced, lose 200 when not."""
	if not out.serviced:
		_write_hive_strength(slot, _h_strength[slot] - HIVE_MISSED_SERVICE_STRENGTH_LOSS)
		return
	out.honey_milli = _produced_milli(HIVE_HONEY_MILLI_PER_DAY, _h_strength[slot])
	out.wax_milli = _produced_milli(HIVE_WAX_MILLI_PER_DAY, _h_strength[slot])
	_h_honey_milli[slot] += out.honey_milli
	_h_wax_milli[slot] += out.wax_milli
	if season == SEASON_SPRING and _h_strength[slot] > HIVE_STRENGTH_MIN:
		_write_hive_strength(slot, _h_strength[slot] + HIVE_TENDED_SPRING_STRENGTH_GAIN)


func _produced_milli(daily_milli: int, strength: int) -> int:
	"""§5.6's `daily x strength/10000`, floored. Both operands are bounded, so this cannot wrap."""
	return daily_milli * strength / HIVE_STRENGTH_DENOMINATOR


func _write_hive_strength(slot: int, strength: int) -> void:
	"""Store a clamped strength and refresh every orchard slice when eligibility CROSSES 5000.

	Ruling §3 names strength-eligibility change as one of the events that must refresh affected
	recipient slices synchronously. Orchard recipients are refreshed here; FARM recipients are the
	owning join's, because this store cannot see a FarmPlot's tile.
	"""
	var was_healthy: bool = _h_strength[slot] >= HIVE_HEALTHY_STRENGTH
	_h_strength[slot] = clampi(strength, HIVE_STRENGTH_MIN, HIVE_STRENGTH_MAX)
	if was_healthy != (_h_strength[slot] >= HIVE_HEALTHY_STRENGTH):
		refresh_all_orchard_links()


func restore_hive_state(hive_ref: Vector2i, strength: int, feed_milli: int, honey_milli: int,
		wax_milli: int, serviced_day: int) -> OpResult:
	"""Write a loaded hive's §4.2 state onto a live row, validating every field first.

	The load path, and the only writer of `strength` outside §5.6's own arithmetic. Refuses the
	WHOLE restore on any out-of-range field. An eligibility crossing refreshes the orchard slices,
	so a load cannot leave a slice describing a hive the restored strength no longer qualifies.
	"""
	var slot: int = _hive_slot_of(hive_ref)
	if slot == NO_ROW:
		return _refuse(REFUSE_HIVE_NOT_PRESENT)
	if strength < HIVE_STRENGTH_MIN or strength > HIVE_STRENGTH_MAX:
		return _refuse(REFUSE_INVALID_AMOUNT)
	if feed_milli < 0 or honey_milli < 0 or wax_milli < 0:
		return _refuse(REFUSE_INVALID_AMOUNT)
	if serviced_day < NO_SERVICE_DAY or not IntMath.fits_int32(serviced_day):
		return _refuse(REFUSE_INVALID_DAY)
	_h_feed_milli[slot] = feed_milli
	_h_honey_milli[slot] = honey_milli
	_h_wax_milli[slot] = wax_milli
	_h_serviced_day[slot] = serviced_day
	_write_hive_strength(slot, strength)
	return _succeed(_h_strength[slot], hive_ref)


# --- ruling §3 serialization and the load-time canonical check -------------------------------------------------

func link_state_bytes() -> PackedByteArray:
	"""Deterministic image of all 30720 references in ruling §3's declared owner order.

	Farm recipients 0..4095 then orchard recipients 0..1023, each recipient's six entries in
	index order, slot then generation. NOT A PRODUCTION CALL: it allocates.

	The save FORMAT does not exist -- no header, chunk layout or version field is specified for
	any store here -- so this is the in-process half only, exactly as in `gear.gd`.
	"""
	var image: PackedInt32Array = PackedInt32Array()
	image.resize(LINK_CAPACITY * LINK_COLUMN_COUNT)
	for row: int in LINK_CAPACITY:
		image[row * LINK_COLUMN_COUNT] = _link_hive_slot[row]
		image[row * LINK_COLUMN_COUNT + 1] = _link_hive_generation[row]
	return var_to_bytes(image)


func restore_links_from_state(state: PackedByteArray) -> OpResult:
	"""Load an image written by `link_state_bytes()` back into the link columns.

	Structure only: the references are written as recorded and are NOT trusted. Ruling §3 requires
	them to be validated or recomputed against the canonical selection before a yield is applied,
	which is `revalidate_orchard_links_after_load()` and `revalidate_farm_links_after_load()`.
	A malformed image refuses whole and writes nothing.
	"""
	var decoded: Variant = bytes_to_var(state)
	if typeof(decoded) != TYPE_PACKED_INT32_ARRAY:
		return _refuse(REFUSE_INVALID_STATE_IMAGE)
	var image: PackedInt32Array = decoded
	if image.size() != LINK_CAPACITY * LINK_COLUMN_COUNT:
		return _refuse(REFUSE_INVALID_STATE_IMAGE)
	for row: int in LINK_CAPACITY:
		_link_hive_slot[row] = image[row * LINK_COLUMN_COUNT]
		_link_hive_generation[row] = image[row * LINK_COLUMN_COUNT + 1]
	return _succeed(LINK_CAPACITY, NULL_REF)


func revalidate_orchard_links_after_load() -> OpResult:
	"""Ruling §3's load rule for orchard recipients: validate against canonical, recompute if not.

	Returns how many slices had to be recomputed, so a load that silently disagreed with its own
	image is visible rather than merely corrected.
	"""
	var recomputed: int = 0
	for index: int in _o_live_count:
		var slot: int = _o_live_slots[index]
		if _select_candidates(_orchard_center_x(slot), _orchard_center_z(slot)) != REFUSE_NONE:
			return _refuse(REFUSE_OVERFLOW)
		if _slice_matches_candidates(ORCHARD_RECIPIENT_BASE + slot):
			continue
		_write_slice(ORCHARD_RECIPIENT_BASE + slot)
		recomputed += 1
	return _succeed(recomputed, NULL_REF)


func revalidate_farm_links_after_load(farm_row: int, tile_x: int, tile_z: int) -> OpResult:
	"""Ruling §3's load rule for one FarmPlot recipient. Returns 1 when the slice was recomputed."""
	if not is_farm_row(farm_row):
		return _refuse(REFUSE_INVALID_ROW)
	if not is_tile_coordinate(tile_x) or not is_tile_coordinate(tile_z):
		return _refuse(REFUSE_INVALID_TILE)
	if _select_candidates(_footprint_center_units(tile_x, tile_x),
			_footprint_center_units(tile_z, tile_z)) != REFUSE_NONE:
		return _refuse(REFUSE_OVERFLOW)
	if _slice_matches_candidates(farm_row):
		return _succeed(0, NULL_REF)
	_write_slice(farm_row)
	return _succeed(1, NULL_REF)


# --- result helpers -------------------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never carries
	a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)




