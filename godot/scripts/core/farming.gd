extends RefCounted
## The FarmPlot store of GDD §4.2, the TileHistory ledger of systems_architecture.md §2, the
## five-row CropDefinition catalog of §5.6, and the crop arithmetic §5.6 states in full:
## REQ-SET-072 hourly growth, 073 ripening, 074 harvest yield, 075 the ripe grace and withering,
## 076 compost, 078 fallow recovery, 084 frost, 085 the withered-clearing amounts, 086 the
## moisture clamp and 087 blight.
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "FarmPlot | crop_id: int32, state: enum, soil: enum, fertility: int32,
##     moisture: int32, growth_milli_hours: int64, health: int32, last_family: int32,
##     family_streak: int32, compost_milli: int64, sow_day: int32 | One per 2 m tile; up to 4096
##     active farm tiles". All eleven columns are here, none renamed, and
##     `entity_directory.gd` already reserves `KIND_FARM_PLOT` at 4096 rows; `_init()` asserts the
##     two agree rather than trusting them to.
##   * systems_architecture.md §2 itemises TileHistory at 16384 rows: `fertility, last_family,
##     last_legume_day, compost_season, active_plot_row, orchard_row` (I32), `ripe_tick,
##     growth_remainder` (I64) and `tended_today` (B8). All nine columns are here at that exact
##     length. 16384 is also §5.1's 128x128 exterior grid, so a TileHistory row IS an exterior
##     tile -- §5.6's "2 m x 2 m tiles" and §5.1's 2048-unit tile are the same square.
##   * `resource_nodes.gd` owns §5.1's tile geometry primitive (`z*128+x`, tile centres). This
##     module never decodes a coordinate: the caller passes a tile INDEX, so there is one copy of
##     that formula and this store cannot disagree with it.
##
## ADDED COLUMNS, in the manner fishing.gd labels its two. `_tile`, `_ref_slot`, `_ref_generation`
## and `_live_slots` are the reverse index, the owning directory reference and the ascending live
## list -- ARCH-MEM-005's "owner-to-child indexes ... allocation overhead outside original field
## payload", exactly as resource_nodes.gd carries `_tile` against `WorldTileMaps.resource_slot`.
## `_tile` is the inverse of TileHistory's own `active_plot_row`; every mutator writes both, so
## neither direction can be believed on its own. NO SIMULATION FIELD IS ADDED to §4.2's eleven.
##
## ---------------------------------------------------------------------------------------
## ARCH-STATE-003 IS THE POINT OF TileHistory. "Recreating a field can allocate a FarmPlot row,
## but it SHALL copy the existing tile state; it SHALL not restore fertility or reset compost
## eligibility." So:
##   * TileHistory.fertility is AUTHORITATIVE. §4.2's `FarmPlot.fertility` is a mirror of it,
##     written by the same private helper on every change, and `create_plot_at_tile()` COPIES the
##     tile's value in -- it never writes the 7000 starting value over a worked tile.
##   * TileHistory.last_family, last_legume_day, compost_season, ripe_tick, growth_remainder and
##     tended_today all survive `destroy()` untouched. BAL-SAFE-014 states the same rule from the
##     balance side and is satisfied by the same columns.
##   * ONE PART OF ARCH-STATE-003 CANNOT BE SATISFIED: `family_streak`. §4.2 puts the streak
##     LENGTH on the FarmPlot row and systems_architecture.md gives TileHistory no column for it,
##     so a designation redraw restores the family but not the count. `_rotation_factor()`
##     therefore treats a restored plot whose tile records the same family as a SECOND
##     consecutive harvest (850), never a first (1000): a redraw can never fabricate a rotation
##     bonus, which is what BAL-SAFE-014 forbids. It CAN still lose a third-or-later penalty --
##     700 becomes 850 across a redraw. That is a REPORTED SHORTFALL in ARCH-STATE-003's column
##     list, not a choice made here.
##   * TileHistory HAS NO SOIL-TYPE COLUMN, so `soil` is the caller's declaration on every
##     create. Soil type is not time-dependent metadata, so its absence is consistent with
##     ARCH-STATE-003's wording, but it means recreating a plot on a tile may declare a different
##     soil than the tile carried before and THIS STORE CANNOT DETECT IT. §5.1's soil bands
##     belong to world generation (REQ-SET-009), which does not exist.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS MODULE DELIBERATELY DOES NOT DO. None of it is stubbed; the numbers are simply not
## compiled in, so nothing here can drift from a contract that does not exist yet.
##   * NO JOB IS CREATED. REQ-SET-073's priority-2 harvest job, REQ-SET-085's 10-WU clearing job
##     and §5.6's 4/1/6 WU sow/tend/harvest work are exposed as the RIPE/WITHERED state
##     transitions plus named work and priority constants. `jobs.gd` IS NOT CALLED FROM HERE:
##     ARCH-SYS-006 (increment 10) owns orchestration, and every module in this group has held
##     that line.
##   * NO INVENTORY LOT IS CREATED OR CONSUMED. `plant()` returns the seed milli-units
##     REQ-SET-071 must consume, `tend()` returns the water, `apply_compost()` returns the
##     compost, `harvest()` returns the produce and `clear_withered()` returns the waste compost.
##     `inventory.gd` owns every lot; this store returns quantities and creates nothing.
##   * NO WEATHER IS READ. Temperature arrives as `temperature_tenths` and blight as an explicit
##     `apply_blight_day()` call, in the manner fishing.gd takes `base_catch_milli` as an
##     argument. weather.gd supplies both readers (`temperature_tenths()`, `is_blight_active()`);
##     joining them is increment 10. Ideal spell's stated "crop growth x1.20" is therefore NOT
##     folded into the hourly step here -- weather.gd reports it and the join owns it.
##   * NO SOWING TRIGGER. REQ-SET-070's field connectivity, seed supply and output capacity are
##     three gates this store cannot evaluate, and §5.6 states no triggering EVENT for sowing at
##     all. `plant()` implements only the two gates that are per-plot facts -- soil compatibility
##     and the planting window -- and refuses everything else to increment 7's `FieldPolicy`.
##   * NO ROTATION POLICY AND NO SEED RESERVE. REQ-SET-077 and REQ-SET-088/089 are `FieldPolicy`,
##     increment 7. The rotation FACTOR of REQ-SET-074 is implemented here; the automated cycle
##     that chooses the next crop is not.
##   * NO ORCHARD AND NO HIVE. REQ-SET-079-083 are increment 8. `TileHistory.orchard_row` is
##     allocated to the architecture's ledger and initialised to NO_ROW; nothing here ever writes
##     it. `pollination_factor` is a PARAMETER of the yield readers, so REQ-SET-074's formula is
##     complete while `HivePollinationLinks` stays blocked by U6. Its stated default 1000 for
##     non-pollinated crops is the caller's to pass; 1100/1150 for beans belongs to increment 8.
##
## ---------------------------------------------------------------------------------------
## GAPS AND INTERPRETATIONS -- named, not invented (AGENTS.md: "do not invent a constant").
##   * CORRECTED -- `CropFamily` WAS NEVER UNNUMBERED. An earlier comment in this module claimed
##     §4.3's enumeration table lists no crop-family enum and concluded a planner ruling was
##     needed, and numbered the five families in §5.6's printed table order. That claim was
##     wrong and the rule was simply missed: GDD §4.2's closing paragraph numbers every gameplay
##     enum it does not individually list from the ascending ASCII keys of its own domain, and
##     BAL-CAT-002 names crop-family explicitly as using BAL-CAT-001's generated IDs. The ids
##     are CEREAL=0, FIBER=1, LEAF=2, LEGUME=3, ROOT=4, they live in catalog.gd's compiled-enum
##     registry, and this module reads them from there.
##   * INTERPRETATION -- SOWN vs GROWING. §4.3 numbers both states and §5.6 never says what
##     separates them. Read here as: SOWN is the seed committed with the 4-WU sowing work
##     outstanding; GROWING is that work complete and REQ-SET-072's hourly integration running,
##     which is what §5.6's "1 WU tending/day while growing" and REQ-SET-084's "growing crop"
##     select. `begin_growing()` is the transition, and its caller is the job that finishes the
##     sowing work. The alternative -- SOWN as a same-tick transient -- would make one of §4.3's
##     five states dead. NEEDS A RULING; `state` is persisted.
##   * INTERPRETATION -- THE TEMPERATURE BANDS ARE WHOLE DEGREES. §5.6 gives "0 below 0°C, 500 at
##     0-7°C, 1000 at 8-26°C, 700 above 26°C" in whole degrees, while weather.gd stores TENTHS.
##     7.5°C falls in no stated band. The bands are read as covering their whole degree
##     completely, so the thresholds are 0, 80 and 270 tenths. The alternative -- "above 26°C"
##     starting at 26.1°C -- differs only for fractional degrees, and EVERY temperature §5.10 can
##     produce is a whole degree (its table is 18, -3, 30, -12, 2 and the four baselines 12, 22,
##     10, -5), so no world state distinguishes the two readings today.
##   * INTERPRETATION -- "WITHIN 2000 OUTSIDE RANGE" IS INCLUSIVE. Distance <= 2000 gives 500,
##     distance > 2000 gives 0. BAL-PROBE-001 corroborates the shape but not the endpoint: grain
##     (3500-7500) scores 500 at moisture 9400 (distance 1900) and 0 at 9600 (distance 2100).
##     The 2000/2001 boundary itself is asserted by test, not by a document.
##   * INTERPRETATION -- THE 48-HOUR GRACE AND THE 5-DAY WITHERING SHARE ONE INSTANT. §5.6:
##     "Ripe crops remain for 48 hours before losing 10% remaining yield/day; after 5 days
##     unharvested they become compost-equivalent waste". Both are measured from `ripe_tick`
##     here, so decay runs on the third, fourth and fifth days and the crop withers at 120 hours.
##     The alternative -- five days AFTER the grace, i.e. 168 hours -- is not taken, because
##     "after 5 days unharvested" counts from the harvest becoming possible, not from the
##     penalty starting. NEEDS A RULING: the two readings differ by two whole days of yield.
##   * INTERPRETATION -- LEGUME AS THE FIRST CROP EVER SCORES 1000, NOT 1100. §5.6 gives "1000
##     for first crop/family change, ... with LEGUME after a different family 1100". A first crop
##     follows no family at all, so it is not "after a different family"; it takes the first-crop
##     1000. The 1100 needs a previous family that is not LEGUME.
##   * INTERPRETATION -- family_streak COUNTS HARVESTS, NOT SOWINGS. §5.6 words the penalty as
##     "a second consecutive same-family harvest", so a crop that withers before harvest does not
##     advance the streak. NEEDS A RULING: counting sowings would penalise a failed crop, and the
##     column is persisted either way.
##   * INTERPRETATION -- compost_season HOLDS AN ABSOLUTE SEASON INDEX. §4.3's Season is 0-3 and
##     repeats every year, so a bare ordinal cannot tell spring of year 1 from spring of year 2
##     and REQ-SET-076's "until the next season" gate would become permanent. The column stores
##     `(absolute_day - 1) / 12`, which is 0 for the first spring and rises forever; NO_SEASON
##     (-1) means never composted, following §4.2's "empty catalog IDs are -1".
##   * UNRESOLVED -- WHAT `FarmPlot.compost_milli` HOLDS. TileHistory.compost_season already
##     gates eligibility, so the §4.2 column is not the gate. It is used here as the QUANTITY
##     ledger: the milli-units of compost applied to this plot, 0 before an application and 2000
##     after, reset when a plot is created. That does not survive `destroy()` -- there is no tile
##     column for it -- which is consistent, since eligibility (which must survive) lives on the
##     tile and the quantity (which need not) lives on the plot. NEEDS A RULING; an alternative
##     reading is a partial-application buffer, which §5.6's flat "2 U/tile" gives no support to.
##   * INTERPRETATION -- FERTILITY IS CLAMPED TO 0..10000 EVERYWHERE. §5.6 states the 10000 cap
##     for compost only. Beans' fertility cost of -800 is a GAIN, and the fallow rates also add,
##     so without the same cap they would reach values no compost could. A floor of 0 is required
##     because `500+floor(fertility/20)` is defined over nonnegative fertility.
##   * INTERPRETATION -- NEW PLOTS START AT §5.1's INITIAL VALUES. §5.1 states "Initial farm
##     moisture is 6000, health 10000" for the initial settlement and §5.6/BAL-CROP-001 state
##     health 10000 and fertility 7000 for any crop-compatible soil. A virgin tile therefore
##     starts at fertility 7000 and a new plot at moisture 6000; a worked tile keeps its own
##     fertility (ARCH-STATE-003 above).
##   * REQ-SET-085's "cancel tending/harvest" IS PARTIAL HERE. The plot's own tending flag is
##     cleared and a WITHERED plot refuses `tend()` and `harvest()`, so no further work can be
##     recorded against it. Cancelling an already-queued Job row is `jobs.gd`'s, through the same
##     ARCH-SYS-006 join, and is not reached into from here.
##   * REQ-SET-086's "show its growth consequence in the crop panel" IS UI. The clamp is
##     implemented; `moisture_factor_of()` is the reader that panel needs.

const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

# --- GDD §4.3 enums, read from catalog.gd's protected table (decision 0018) ------------------------

const SOIL_LOAM: int = Catalog.SOIL["LOAM"]
const SOIL_CLAY: int = Catalog.SOIL["CLAY"]
const SOIL_SAND: int = Catalog.SOIL["SAND"]
const SOIL_COUNT: int = 3

const STATE_EMPTY: int = Catalog.CROP_STATE["EMPTY"]
const STATE_SOWN: int = Catalog.CROP_STATE["SOWN"]
const STATE_GROWING: int = Catalog.CROP_STATE["GROWING"]
const STATE_RIPE: int = Catalog.CROP_STATE["RIPE"]
const STATE_WITHERED: int = Catalog.CROP_STATE["WITHERED"]
const STATE_COUNT: int = 5

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_COUNT: int = 4

## BAL-CROP-001: "`allowed_soils` bit `1<<Soil` yields LOAM=1, CLAY=2, SAND=4."
const SOIL_MASK_LOAM: int = 1 << SOIL_LOAM
const SOIL_MASK_CLAY: int = 1 << SOIL_CLAY
const SOIL_MASK_SAND: int = 1 << SOIL_SAND

# --- calendar constants, from sim_clock.gd rather than mirrored -----------------------------------

const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
const HOURS_PER_DAY: int = SimClock.HOURS_PER_DAY
const FIRST_SEASON_DAY: int = 1
## §5.1 starts the calendar at day 1, so day 0 names no day and is refused, not stored.
const MIN_CALENDAR_DAY: int = 1

# --- store capacities -------------------------------------------------------------------------------

## GDD §4.2: "up to 4096 active farm tiles"; `_init()` checks the directory agrees.
const FARM_PLOT_CAPACITY: int = 4096
## systems_architecture.md §2: TileHistory "Length/column 16384", which is §5.1's 128x128 grid.
const TILE_COUNT: int = 16384

## Empty values. §4.2: "Empty references are (-1,0); empty catalog IDs are -1; empty
## counters/remainders are 0."
const CROP_NONE: int = -1
const FAMILY_NONE: int = -1
const NO_ROW: int = EntityDirectory.NULL_SLOT
const NO_SEASON: int = -1
## Tick 0 is a real tick (§5.1: "Tick 0 corresponds to 06:00 on the first day"), so "not ripe"
## cannot be 0 and uses -1, which names no tick.
const NO_RIPE_TICK: int = -1
## Day 0 names no day, so it is the "no legume crop recorded" value for `last_legume_day`.
const NO_LEGUME_DAY: int = 0

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- §5.6 crop families: catalog.gd's compiled CropFamily domain, see the header ---------------------

## Read from catalog.gd, never mirrored: `Catalog.CROP_FAMILY[...]` is a constant expression, so
## there is exactly one copy of each id. BAL-CAT-002 names crop-family explicitly as a domain
## whose numeric IDs are generated by BAL-CAT-001, i.e. the ascending ASCII order of §5.6's own
## uppercase family names -- NOT §5.6's printed table order, which is what this module used to
## use. `FarmPlot.last_family` is persisted, so the old ordinals are not interchangeable with
## these: a retained snapshot is translated through Catalog.convert_legacy_id() (CropFamily map
## [0,4,3,2,1]) or refused.
const CROP_FAMILY_DOMAIN: String = Catalog.CROP_FAMILY_DOMAIN
const FAMILY_CEREAL: int = Catalog.CROP_FAMILY["CEREAL"]
const FAMILY_FIBER: int = Catalog.CROP_FAMILY["FIBER"]
const FAMILY_LEAF: int = Catalog.CROP_FAMILY["LEAF"]
const FAMILY_LEGUME: int = Catalog.CROP_FAMILY["LEGUME"]
const FAMILY_ROOT: int = Catalog.CROP_FAMILY["ROOT"]
const FAMILY_COUNT: int = 5

# --- §5.6 / §4.3 CropDefinition catalog ---------------------------------------------------------------

## §4.3: "All gameplay enum numeric values not individually listed are generated once from the
## lexicographically sorted ASCII catalog keys within their own domain". CropDefinition IS such a
## catalog, so crop ids are the ASCII order of these five keys -- NOT §5.6's printed table order.
## `_init()` compiles them through catalog.gd's own compiler and asserts the ids below match, so
## the ordering rule has exactly one implementation.
const CROP_KEYS: Array[StringName] = [&"beans", &"cabbage", &"flax", &"grain", &"roots"]
const CROP_BEANS: int = 0
const CROP_CABBAGE: int = 1
const CROP_FLAX: int = 2
const CROP_GRAIN: int = 3
const CROP_ROOTS: int = 4
const CROP_COUNT: int = 5
const CROP_DEFINITION_DOMAIN: String = "CropDefinition"

## §5.6's "Family" column: beans LEGUME, cabbage LEAF, flax FIBER, grain CEREAL, roots ROOT.
const CROP_FAMILY: Array[int] = [
	FAMILY_LEGUME, FAMILY_LEAF, FAMILY_FIBER, FAMILY_CEREAL, FAMILY_ROOT,
]

## §5.6's "Soils" column as BAL-CROP-001's `1<<Soil` mask: beans loam/clay, cabbage loam/clay,
## flax loam/sand, grain loam/clay, roots loam/sand.
const CROP_ALLOWED_SOILS: Array[int] = [
	SOIL_MASK_LOAM | SOIL_MASK_CLAY,
	SOIL_MASK_LOAM | SOIL_MASK_CLAY,
	SOIL_MASK_LOAM | SOIL_MASK_SAND,
	SOIL_MASK_LOAM | SOIL_MASK_CLAY,
	SOIL_MASK_LOAM | SOIL_MASK_SAND,
]
## The same column as BAL-CROP-001 prints it numerically. Stated twice in two documents, so
## `_init()` compares the two transcriptions against each other rather than against itself.
const BALANCE_ALLOWED_SOILS: Array[int] = [3, 3, 5, 3, 5]

## §5.6's "Growth game hours" column: beans 144, cabbage 120, flax 168, grain 192, roots 120.
const CROP_GROWTH_HOURS: Array[int] = [144, 120, 168, 192, 120]

## §5.6's "Yield U/tile" column in milli-units: beans 7, cabbage 6, flax 5, grain 10, roots 6.
const CROP_BASE_YIELD_MILLI: Array[int] = [7000, 6000, 5000, 10000, 6000]

## §5.6's "Seed U/tile" column in milli-units: every crop is 0.25 U, which BAL-CROP-001 restates
## as "Seed consumption is 250 milli-U/tile at sow start".
const CROP_SEED_MILLI: Array[int] = [250, 250, 250, 250, 250]

## §5.6's "Moisture min-max" column: beans 4000-8000, cabbage 4000-8500, flax 3000-7500,
## grain 3500-7500, roots 2500-7000.
const CROP_MOISTURE_MIN: Array[int] = [4000, 4000, 3000, 3500, 2500]
const CROP_MOISTURE_MAX: Array[int] = [8000, 8500, 7500, 7500, 7000]

## §5.6's "Frost damage/hour" column, which BAL-CROP-001 confirms is `frost_tolerance` storing
## "damage per subzero hour", not a temperature threshold: beans 1500, cabbage 150, flax 800,
## grain 1000, roots 300.
const CROP_FROST_DAMAGE_PER_HOUR: Array[int] = [1500, 150, 800, 1000, 300]

## §5.6's "Fertility cost/harvest" column: beans -800 -- A GAIN, NOT A COST, and the sign is
## transcribed -- cabbage 900, flax 800, grain 1200, roots 700.
const CROP_FERTILITY_COST: Array[int] = [-800, 900, 800, 1200, 700]

## §5.6's "Plant windows" column. Two windows at most, so the three tables below are read in
## strides of `PLANT_WINDOWS_PER_CROP`; an absent second window is NO_WINDOW. BAL-CROP-001:
## "Plant-window endpoints are inclusive season-local days."
##   beans   Spring 5-10; Summer 1-3      cabbage Summer 5-10; Autumn 1-3
##   flax    Spring 1-6                   grain   Spring 1-4
##   roots   Spring 1-8; Summer 1-4
const PLANT_WINDOWS_PER_CROP: int = 2
const NO_WINDOW: int = -1
const CROP_WINDOW_SEASON: Array[int] = [
	SEASON_SPRING, SEASON_SUMMER,
	SEASON_SUMMER, SEASON_AUTUMN,
	SEASON_SPRING, NO_WINDOW,
	SEASON_SPRING, NO_WINDOW,
	SEASON_SPRING, SEASON_SUMMER,
]
const CROP_WINDOW_FIRST_DAY: Array[int] = [5, 1, 5, 1, 1, 0, 1, 0, 1, 1]
const CROP_WINDOW_LAST_DAY: Array[int] = [10, 3, 10, 3, 6, 0, 4, 0, 8, 4]

# --- §5.6 initial plot state ---------------------------------------------------------------------------

## §5.6: "Any crop-compatible soil starts fertility 7000"; BAL-CROP-001 repeats it.
const INITIAL_FERTILITY: int = 7000
## §5.1: "Initial farm moisture is 6000, health 10000". See the header on the reading.
const INITIAL_MOISTURE: int = 6000
const INITIAL_HEALTH: int = 10000

# --- §5.6 bounds -----------------------------------------------------------------------------------------

## REQ-SET-086: "clamp moisture 0-10000".
const MOISTURE_MIN: int = 0
const MOISTURE_MAX: int = 10000
## GDD §4.1: needs and mood are integers 0-10000, and §5.6's health factor divides health by 10
## to reach a 0-1000 factor, so crop health shares the same 0-10000 scale.
const HEALTH_MIN: int = 0
const HEALTH_MAX: int = 10000
## REQ-SET-076's stated compost ceiling, applied to every fertility change (see the header).
const FERTILITY_MIN: int = 0
const FERTILITY_MAX: int = 10000

# --- REQ-SET-072 hourly growth ---------------------------------------------------------------------------

## "Growth advances each hour by 1000 milli-hours x temperature_factor x moisture_factor/1000000".
const MILLI_HOURS_PER_HOUR: int = 1000
const GROWTH_FACTOR_DENOMINATOR: int = 1000000

## "Temperature factor is 0 below 0°C, 500 at 0-7°C, 1000 at 8-26°C, 700 above 26°C", in tenths of
## a degree because that is the unit §4.2's `Weather.temperature_tenths` stores. See the header on
## the whole-degree band reading that fixes 80 and 270.
const TEMPERATURE_COOL_MIN_TENTHS: int = 0
const TEMPERATURE_IDEAL_MIN_TENTHS: int = 80
const TEMPERATURE_HOT_MIN_TENTHS: int = 270
const TEMPERATURE_FACTOR_FROZEN: int = 0
const TEMPERATURE_FACTOR_COOL: int = 500
const TEMPERATURE_FACTOR_IDEAL: int = 1000
const TEMPERATURE_FACTOR_HOT: int = 700

## "moisture factor 1000 within range, 500 within 2000 outside range, 0 farther outside".
const MOISTURE_NEAR_MARGIN: int = 2000
const MOISTURE_FACTOR_IN_RANGE: int = 1000
const MOISTURE_FACTOR_NEAR: int = 500
const MOISTURE_FACTOR_FAR: int = 0

# --- REQ-SET-074 harvest yield ------------------------------------------------------------------------------

## "Fertility factor=`500+floor(fertility/20)` (500-1000)".
const FERTILITY_FACTOR_BASE: int = 500
const FERTILITY_FACTOR_DIVISOR: int = 20
const FERTILITY_FACTOR_MIN: int = 500
const FERTILITY_FACTOR_MAX: int = 1000
## "health factor=health 0-10000 divided by 10".
const HEALTH_FACTOR_DIVISOR: int = 10
## "rotation factor=1000 for first crop/family change, 850 for a second consecutive same-family
## harvest, 700 for third+, with LEGUME after a different family 1100".
const ROTATION_FACTOR_FIRST: int = 1000
const ROTATION_FACTOR_SECOND: int = 850
const ROTATION_FACTOR_THIRD_PLUS: int = 700
const ROTATION_FACTOR_LEGUME_AFTER_CHANGE: int = 1100
## §5.6: "Pollination factor is ... other crops 1000". The 1100/1150 hive multipliers are
## increment 8; this is the stated neutral value a caller passes for an unpollinated crop.
const POLLINATION_FACTOR_NEUTRAL: int = 1000
## "floor(base_yield_milli*fertility_factor*health_factor*rotation_factor*pollination_factor/10^12)"
const YIELD_DENOMINATOR: int = 1000000000000
## "Cap final yield at 125% base."
const YIELD_CAP_NUMERATOR: int = 125
const YIELD_CAP_DENOMINATOR: int = 100

# --- REQ-SET-075 ripe grace, decay and withering ------------------------------------------------------------

## "Ripe crops remain for 48 hours before losing 10% remaining yield/day; after 5 days unharvested
## they become compost-equivalent waste and the plot WITHERED." Both windows run from `ripe_tick`.
const RIPE_GRACE_HOURS: int = 48
const RIPE_WITHER_DAYS: int = 5
const RIPE_LOSS_PER_1000_PER_DAY: int = 100
const FACTOR_DENOMINATOR: int = 1000

# --- REQ-SET-076 compost, REQ-SET-078 fallow ------------------------------------------------------------------

## "Compost applies 2 U/tile for 8 WU and restores 1500 fertility, capped 10000, at most
## once/tile/season."
const COMPOST_MILLI_PER_TILE: int = 2000
const COMPOST_FERTILITY_GAIN: int = 1500
## "Empty/fallow plot gains 50 fertility/day; last LEGUME crop adds another 50/day for the next
## 12 days."
const FALLOW_FERTILITY_PER_DAY: int = 50
const LEGUME_FALLOW_BONUS_PER_DAY: int = 50
const LEGUME_FALLOW_DAYS: int = 12

# --- REQ-SET-084 frost, REQ-SET-087 blight, §5.6 tending --------------------------------------------------------

## REQ-SET-084: the crop's listed damage/hour "while temperature<0°C, halved for cabbage in a
## tended plot".
const FROST_TEMPERATURE_TENTHS: int = 0
const CABBAGE_TENDED_FROST_DIVISOR: int = 2
## REQ-SET-087: "remove 400 health/day, reduced to 200 if tended". §5.6 states the same reduction
## as "reduces blight health loss by 50%", so `_init()` checks the two statements agree.
const BLIGHT_HEALTH_LOSS_PER_DAY: int = 400
const BLIGHT_TENDED_HEALTH_LOSS_PER_DAY: int = 200
const BLIGHT_TENDED_DIVISOR: int = 2
## §5.6: "Tending restores 1000 moisture using water 0.25 U when below minimum".
const TEND_MOISTURE_RESTORE: int = 1000
const TEND_WATER_MILLI: int = 250

# --- work quantities, exposed for the jobs this store does not create ---------------------------------------------

## §5.6: "Each plot needs 4 WU sowing, 1 WU tending/day while growing, and 6 WU harvest";
## BAL-CROP-001 restates them as 4000/1000/6000 milli-WU. REQ-SET-085's clearing job is 10 WU and
## §5.6's compost application is 8 WU.
const SOW_WORK_MILLI_WU: int = 4000
const TEND_WORK_MILLI_WU: int = 1000
const HARVEST_WORK_MILLI_WU: int = 6000
const CLEARING_WORK_MILLI_WU: int = 10000
const COMPOST_WORK_MILLI_WU: int = 8000
## REQ-SET-085: the clearing job yields "compost 0.5 U/tile".
const CLEARING_COMPOST_MILLI: int = 500
## REQ-SET-073: "create a priority 2 harvest job". The priority is stated; the job is not made here.
const HARVEST_JOB_PRIORITY: int = 2

# --- refusal codes -----------------------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_TILE_OCCUPIED: StringName = &"TILE_OCCUPIED"
const REFUSE_NOT_PRESENT: StringName = &"FARM_PLOT_NOT_PRESENT"
const REFUSE_INVALID_SOIL: StringName = &"INVALID_SOIL"
const REFUSE_INVALID_CROP: StringName = &"INVALID_CROP"
const REFUSE_SOIL_INCOMPATIBLE: StringName = &"SOIL_INCOMPATIBLE"
const REFUSE_OUTSIDE_PLANT_WINDOW: StringName = &"OUTSIDE_PLANT_WINDOW"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_SEASON_DAY: StringName = &"INVALID_SEASON_DAY"
const REFUSE_INVALID_DAY: StringName = &"INVALID_DAY"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
const REFUSE_INVALID_FACTOR: StringName = &"INVALID_FACTOR"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_NOT_EMPTY: StringName = &"PLOT_NOT_EMPTY"
const REFUSE_NOT_SOWN: StringName = &"PLOT_NOT_SOWN"
const REFUSE_NOT_GROWING: StringName = &"PLOT_NOT_GROWING"
const REFUSE_NOT_RIPE: StringName = &"PLOT_NOT_RIPE"
const REFUSE_NOT_WITHERED: StringName = &"PLOT_NOT_WITHERED"
const REFUSE_NO_CROP: StringName = &"PLOT_HAS_NO_CROP"
const REFUSE_COMPOST_NOT_ELIGIBLE: StringName = &"COMPOST_NOT_ELIGIBLE"
const REFUSE_RIPE_TICK_MISSING: StringName = &"RIPE_TICK_MISSING"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class OpResult:
	"""Outcome of one farming operation: success flag, refusal code, value and reference.

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


# --- collaborators ---------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false

# --- §4.2 FarmPlot columns (ARCH-MEM-001: packed, allocated once, indexed by typed row) ------------

var _present: PackedByteArray = PackedByteArray()
var _crop_id: PackedInt32Array = PackedInt32Array()
var _state: PackedInt32Array = PackedInt32Array()
var _soil: PackedInt32Array = PackedInt32Array()
var _fertility: PackedInt32Array = PackedInt32Array()
var _moisture: PackedInt32Array = PackedInt32Array()
var _growth_milli_hours: PackedInt64Array = PackedInt64Array()
var _health: PackedInt32Array = PackedInt32Array()
var _last_family: PackedInt32Array = PackedInt32Array()
var _family_streak: PackedInt32Array = PackedInt32Array()
var _compost_milli: PackedInt64Array = PackedInt64Array()
var _sow_day: PackedInt32Array = PackedInt32Array()

## ADDED COLUMNS, see the header: the reverse of TileHistory.active_plot_row, the owning directory
## reference, and the ascending live list a daily sweep iterates instead of all 4096 rows.
var _tile: PackedInt32Array = PackedInt32Array()
var _ref_slot: PackedInt32Array = PackedInt32Array()
var _ref_generation: PackedInt32Array = PackedInt32Array()
var _live_slots: PackedInt32Array = PackedInt32Array()
var _live_count: int = 0

# --- TileHistory columns (systems_architecture.md §2, ARCH-STATE-003) -------------------------------

var _tile_fertility: PackedInt32Array = PackedInt32Array()
var _tile_last_family: PackedInt32Array = PackedInt32Array()
var _tile_last_legume_day: PackedInt32Array = PackedInt32Array()
var _tile_compost_season: PackedInt32Array = PackedInt32Array()
var _tile_active_plot_row: PackedInt32Array = PackedInt32Array()
## Allocated to the architecture's ledger and never written here: orchards are increment 8.
var _tile_orchard_row: PackedInt32Array = PackedInt32Array()
var _tile_ripe_tick: PackedInt64Array = PackedInt64Array()
var _tile_growth_remainder: PackedInt64Array = PackedInt64Array()
var _tile_tended_today: PackedByteArray = PackedByteArray()

# --- scratch (not simulation state) -------------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and assert every transcribed §5.6 table has its stated width.

	Passing an existing directory shares it; passing none creates a private one, which is what a
	test or a standalone fixture wants.
	"""
	assert(FARM_PLOT_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_FARM_PLOT],
		"FarmPlot columns must match the directory's FARM_PLOT row capacity")
	assert(Catalog.SOIL.size() == SOIL_COUNT, "GDD §4.3 Soil has exactly three values")
	assert(Catalog.CROP_STATE.size() == STATE_COUNT, "GDD §4.3 CropState has exactly five values")
	assert(Catalog.SEASON.size() == SEASON_COUNT, "GDD §4.3 Season has exactly four values")
	_assert_crop_tables()
	_assert_crop_ids_match_the_compiled_catalog()
	_assert_stated_relations()
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _assert_crop_tables() -> void:
	"""Assert every §5.6 column table carries exactly one entry per crop row."""
	assert(CROP_KEYS.size() == CROP_COUNT, "§5.6 lists exactly five crop rows")
	assert(CROP_FAMILY.size() == CROP_COUNT, "one family per §5.6 row")
	assert(CROP_ALLOWED_SOILS.size() == CROP_COUNT, "one soil mask per §5.6 row")
	assert(BALANCE_ALLOWED_SOILS.size() == CROP_COUNT, "one BAL-CROP-001 mask per §5.6 row")
	assert(CROP_GROWTH_HOURS.size() == CROP_COUNT, "one growth duration per §5.6 row")
	assert(CROP_BASE_YIELD_MILLI.size() == CROP_COUNT, "one base yield per §5.6 row")
	assert(CROP_SEED_MILLI.size() == CROP_COUNT, "one seed quantity per §5.6 row")
	assert(CROP_MOISTURE_MIN.size() == CROP_COUNT, "one moisture minimum per §5.6 row")
	assert(CROP_MOISTURE_MAX.size() == CROP_COUNT, "one moisture maximum per §5.6 row")
	assert(CROP_FROST_DAMAGE_PER_HOUR.size() == CROP_COUNT, "one frost damage per §5.6 row")
	assert(CROP_FERTILITY_COST.size() == CROP_COUNT, "one fertility cost per §5.6 row")
	for crop: int in CROP_COUNT:
		assert(CROP_FAMILY[crop] >= 0 and CROP_FAMILY[crop] < FAMILY_COUNT,
			"every §5.6 family ordinal must name one of the five families")
	var window_entries: int = CROP_COUNT * PLANT_WINDOWS_PER_CROP
	assert(CROP_WINDOW_SEASON.size() == window_entries, "two window seasons per §5.6 row")
	assert(CROP_WINDOW_FIRST_DAY.size() == window_entries, "two window first days per §5.6 row")
	assert(CROP_WINDOW_LAST_DAY.size() == window_entries, "two window last days per §5.6 row")


func _assert_crop_ids_match_the_compiled_catalog() -> void:
	"""Assert the CROP_* and FAMILY_* ids are what the ascending-ASCII compiler produces.

	This is the one place the ordering rule is applied; the constants are checked against the
	compiler rather than against each other, so a renamed or reordered key fails here instead of
	silently repointing every table below at a different crop. The CropFamily domain is checked
	the same way, in catalog.gd, because §4.2's closing paragraph covers both.
	"""
	assert(Catalog.verify_compiled_enum(CROP_FAMILY_DOMAIN).ok,
		"CropFamily ids must be what ascending ASCII order generates")
	assert(Catalog.CROP_FAMILY.size() == FAMILY_COUNT, "§5.6 defines five crop families")
	var compiled: Catalog.DomainResult = Catalog.compile_domain(CROP_DEFINITION_DOMAIN, CROP_KEYS)
	assert(compiled.ok, "the CropDefinition catalog must compile")
	assert(compiled.ids.size() == CROP_COUNT, "five compiled crop ids")
	assert(compiled.ids[&"beans"] == CROP_BEANS, "beans is the compiled id CROP_BEANS")
	assert(compiled.ids[&"cabbage"] == CROP_CABBAGE, "cabbage is the compiled id CROP_CABBAGE")
	assert(compiled.ids[&"flax"] == CROP_FLAX, "flax is the compiled id CROP_FLAX")
	assert(compiled.ids[&"grain"] == CROP_GRAIN, "grain is the compiled id CROP_GRAIN")
	assert(compiled.ids[&"roots"] == CROP_ROOTS, "roots is the compiled id CROP_ROOTS")


func _assert_stated_relations() -> void:
	"""Assert the relations two documents state twice, so a drifting edit contradicts a document.

	Each check compares two independently written statements -- §5.6's soil names against
	BAL-CROP-001's numeric masks, §5.6's "reduces blight health loss by 50%" against
	REQ-SET-087's "reduced to 200", and §5.6's factor bounds against its own stated range.
	"""
	for crop: int in CROP_COUNT:
		assert(CROP_ALLOWED_SOILS[crop] == BALANCE_ALLOWED_SOILS[crop],
			"§5.6's soil names and BAL-CROP-001's mask must describe the same soils")
		assert(CROP_MOISTURE_MIN[crop] < CROP_MOISTURE_MAX[crop],
			"§5.6's moisture minimum must be below its maximum")
	assert(BLIGHT_HEALTH_LOSS_PER_DAY / BLIGHT_TENDED_DIVISOR == BLIGHT_TENDED_HEALTH_LOSS_PER_DAY,
		"§5.6's 50% blight reduction must equal REQ-SET-087's stated 200/day")
	assert(FERTILITY_FACTOR_BASE + FERTILITY_MAX / FERTILITY_FACTOR_DIVISOR == FERTILITY_FACTOR_MAX,
		"§5.6's fertility factor must reach exactly 1000 at the stated 10000 fertility cap")
	assert(HEALTH_MAX / HEALTH_FACTOR_DIVISOR == FACTOR_DENOMINATOR,
		"§5.6's health factor must reach exactly 1000 at full health")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_present.resize(FARM_PLOT_CAPACITY)
	_crop_id.resize(FARM_PLOT_CAPACITY)
	_state.resize(FARM_PLOT_CAPACITY)
	_soil.resize(FARM_PLOT_CAPACITY)
	_fertility.resize(FARM_PLOT_CAPACITY)
	_moisture.resize(FARM_PLOT_CAPACITY)
	_growth_milli_hours.resize(FARM_PLOT_CAPACITY)
	_health.resize(FARM_PLOT_CAPACITY)
	_last_family.resize(FARM_PLOT_CAPACITY)
	_family_streak.resize(FARM_PLOT_CAPACITY)
	_compost_milli.resize(FARM_PLOT_CAPACITY)
	_sow_day.resize(FARM_PLOT_CAPACITY)
	_tile.resize(FARM_PLOT_CAPACITY)
	_ref_slot.resize(FARM_PLOT_CAPACITY)
	_ref_generation.resize(FARM_PLOT_CAPACITY)
	_live_slots.resize(FARM_PLOT_CAPACITY)
	_allocate_tile_history()


func _allocate_tile_history() -> void:
	"""Size systems_architecture.md §2's nine TileHistory columns at their stated 16384 rows."""
	_tile_fertility.resize(TILE_COUNT)
	_tile_last_family.resize(TILE_COUNT)
	_tile_last_legume_day.resize(TILE_COUNT)
	_tile_compost_season.resize(TILE_COUNT)
	_tile_active_plot_row.resize(TILE_COUNT)
	_tile_orchard_row.resize(TILE_COUNT)
	_tile_ripe_tick.resize(TILE_COUNT)
	_tile_growth_remainder.resize(TILE_COUNT)
	_tile_tended_today.resize(TILE_COUNT)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live row's directory slot is released first, so a clear leaks no allocation into a
	directory this store may not own. Tile fertility returns to §5.6's stated 7000 starting value
	because a cleared world has no worked soil left to remember.
	"""
	_release_live_rows()
	_clear_plot_columns()
	_clear_tile_history()
	_live_count = 0
	if _owns_directory:
		_directory.clear()


func _clear_plot_columns() -> void:
	"""Empty every §4.2 FarmPlot column and the added index columns."""
	_present.fill(0)
	_crop_id.fill(CROP_NONE)
	_state.fill(STATE_EMPTY)
	_soil.fill(SOIL_LOAM)
	_fertility.fill(0)
	_moisture.fill(0)
	_growth_milli_hours.fill(0)
	_health.fill(0)
	_last_family.fill(FAMILY_NONE)
	_family_streak.fill(0)
	_compost_milli.fill(0)
	_sow_day.fill(0)
	_tile.fill(NO_ROW)
	_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_live_slots.fill(EntityDirectory.NULL_SLOT)


func _clear_tile_history() -> void:
	"""Empty the TileHistory ledger: no worked soil, no plot, no orchard, nothing composted."""
	_tile_fertility.fill(INITIAL_FERTILITY)
	_tile_last_family.fill(FAMILY_NONE)
	_tile_last_legume_day.fill(NO_LEGUME_DAY)
	_tile_compost_season.fill(NO_SEASON)
	_tile_active_plot_row.fill(NO_ROW)
	_tile_orchard_row.fill(NO_ROW)
	_tile_ripe_tick.fill(NO_RIPE_TICK)
	_tile_growth_remainder.fill(0)
	_tile_tended_today.fill(0)


func _release_live_rows() -> void:
	"""Destroy the directory slot of every live row, so a clear leaks no allocation."""
	for index: int in _live_count:
		var slot: int = _live_slots[index]
		if slot < 0 or slot >= FARM_PLOT_CAPACITY or _present[slot] != 1:
			continue
		_directory.destroy(Vector2i(_ref_slot[slot], _ref_generation[slot]))


func directory() -> EntityDirectory:
	"""The allocator behind every farm-plot reference."""
	return _directory


# --- argument validation -----------------------------------------------------------------------------

func is_tile_index(tile: int) -> bool:
	"""True when `tile` addresses one of the 16384 TileHistory rows (§5.1's 128x128 grid)."""
	return tile >= 0 and tile < TILE_COUNT


func is_crop(crop_id: int) -> bool:
	"""True when `crop_id` names one of §5.6's five crop rows. CROP_NONE is not one of them."""
	return crop_id >= 0 and crop_id < CROP_COUNT


func is_soil(soil: int) -> bool:
	"""True when `soil` is one of §4.3's three Soil values."""
	return soil >= 0 and soil < SOIL_COUNT


func is_season(season: int) -> bool:
	"""True when `season` is one of §4.3's four Season values."""
	return season >= 0 and season < SEASON_COUNT


func is_season_day(season_day: int) -> bool:
	"""True when `season_day` is a day within a season, 1..12 (REQ-SET-006, via sim_clock.gd)."""
	return season_day >= FIRST_SEASON_DAY and season_day <= DAYS_PER_SEASON


func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a live farm plot."""
	return slot >= 0 and slot < FARM_PLOT_CAPACITY and _present[slot] == 1


func _check_day(day: int) -> StringName:
	"""REFUSE_NONE when `day` is a storable calendar day, day 1 or later."""
	if day < MIN_CALENDAR_DAY or not IntMath.fits_int32(day):
		return REFUSE_INVALID_DAY
	return REFUSE_NONE


# --- §5.6 CropDefinition readers ------------------------------------------------------------------------

func crop_key_of(crop_id: int) -> StringName:
	"""The catalog key of a crop row, or the empty StringName when `crop_id` names no row."""
	if not is_crop(crop_id):
		return &""
	return CROP_KEYS[crop_id]


func family_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Family" column as this module's local ordinal (see the header on its numbering)."""
	return _read_crop(crop_id, CROP_FAMILY)


func allowed_soils_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Soils" column as BAL-CROP-001's `1<<Soil` mask."""
	return _read_crop(crop_id, CROP_ALLOWED_SOILS)


func growth_hours_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Growth game hours" column: the duration REQ-SET-073 ripens at."""
	return _read_crop(crop_id, CROP_GROWTH_HOURS)


func base_yield_milli_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Yield U/tile" column in milli-units."""
	return _read_crop(crop_id, CROP_BASE_YIELD_MILLI)


func seed_milli_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Seed U/tile" column in milli-units: 250 for every crop."""
	return _read_crop(crop_id, CROP_SEED_MILLI)


func moisture_min_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Moisture min-max" column, lower endpoint, inclusive."""
	return _read_crop(crop_id, CROP_MOISTURE_MIN)


func moisture_max_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Moisture min-max" column, upper endpoint, inclusive."""
	return _read_crop(crop_id, CROP_MOISTURE_MAX)


func frost_damage_per_hour_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Frost damage/hour" column: BAL-CROP-001's damage per subzero hour."""
	return _read_crop(crop_id, CROP_FROST_DAMAGE_PER_HOUR)


func fertility_cost_of(crop_id: int) -> IntMath.IntResult:
	"""§5.6's "Fertility cost/harvest" column. Beans state -800, which is a GAIN, not a cost."""
	return _read_crop(crop_id, CROP_FERTILITY_COST)


func _read_crop(crop_id: int, column: Array[int]) -> IntMath.IntResult:
	"""Read one §5.6 crop-table column, refusing an unknown crop rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_crop(crop_id):
		out.refuse(String(REFUSE_INVALID_CROP))
		return out
	out.succeed(column[crop_id])
	return out


func is_soil_compatible(crop_id: int, soil: int) -> bool:
	"""True when §5.6's soil column admits this crop on this soil.

	An out-of-range argument reports false, because it names no compatible pair at all;
	allowed_soils_of() is the form that refuses those with a reason.
	"""
	if not is_crop(crop_id) or not is_soil(soil):
		return false
	return (CROP_ALLOWED_SOILS[crop_id] & (1 << soil)) != 0


func window_count_of(crop_id: int) -> IntMath.IntResult:
	"""How many planting windows §5.6 gives a crop: one or two."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_crop(crop_id):
		out.refuse(String(REFUSE_INVALID_CROP))
		return out
	var total: int = 0
	for index: int in PLANT_WINDOWS_PER_CROP:
		if CROP_WINDOW_SEASON[crop_id * PLANT_WINDOWS_PER_CROP + index] != NO_WINDOW:
			total += 1
	out.succeed(total)
	return out


func is_plant_window(crop_id: int, season: int, season_day: int) -> bool:
	"""True when §5.6's "Plant windows" column admits this crop on this season-local day.

	BAL-CROP-001: "Plant-window endpoints are inclusive season-local days." An out-of-range
	argument reports false, because it names no legal window at all.
	"""
	if not is_crop(crop_id) or not is_season(season) or not is_season_day(season_day):
		return false
	return _is_plant_window(crop_id, season, season_day)


static func _is_plant_window(crop_id: int, season: int, season_day: int) -> bool:
	"""§5.6's window test for arguments the caller has already validated."""
	for index: int in PLANT_WINDOWS_PER_CROP:
		var entry: int = crop_id * PLANT_WINDOWS_PER_CROP + index
		if CROP_WINDOW_SEASON[entry] != season:
			continue
		if season_day >= CROP_WINDOW_FIRST_DAY[entry] and season_day <= CROP_WINDOW_LAST_DAY[entry]:
			return true
	return false


# --- REQ-SET-072 growth factors, as pure readers -------------------------------------------------------

static func temperature_factor_of(temperature_tenths: int) -> int:
	"""§5.6's temperature factor for a temperature in tenths of a degree.

	"0 below 0°C, 500 at 0-7°C, 1000 at 8-26°C, 700 above 26°C". Every int is a temperature, so
	this reader cannot fail; see the header on the whole-degree band reading behind 80 and 270.
	"""
	if temperature_tenths < TEMPERATURE_COOL_MIN_TENTHS:
		return TEMPERATURE_FACTOR_FROZEN
	if temperature_tenths < TEMPERATURE_IDEAL_MIN_TENTHS:
		return TEMPERATURE_FACTOR_COOL
	if temperature_tenths < TEMPERATURE_HOT_MIN_TENTHS:
		return TEMPERATURE_FACTOR_IDEAL
	return TEMPERATURE_FACTOR_HOT


func moisture_factor_of(crop_id: int, moisture: int) -> IntMath.IntResult:
	"""§5.6's moisture factor for a crop at a moisture level. See moisture_factor_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	moisture_factor_into(crop_id, moisture, out)
	return out


func moisture_factor_into(crop_id: int, moisture: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating moisture_factor_of(): write the factor into caller-owned `out`.

	"1000 within range, 500 within 2000 outside range, 0 farther outside", with both range
	endpoints inclusive and the 2000 margin inclusive (see the header).
	"""
	if not is_crop(crop_id):
		return out.refuse(String(REFUSE_INVALID_CROP))
	if moisture < MOISTURE_MIN or moisture > MOISTURE_MAX:
		return out.refuse(String(REFUSE_INVALID_AMOUNT))
	return out.succeed(_moisture_factor(crop_id, moisture))


static func _moisture_factor(crop_id: int, moisture: int) -> int:
	"""§5.6's moisture factor for validated arguments.

	Both distances are bounded by the 0..10000 moisture clamp and the crop's own endpoints, so
	no subtraction here can overflow.
	"""
	if moisture >= CROP_MOISTURE_MIN[crop_id] and moisture <= CROP_MOISTURE_MAX[crop_id]:
		return MOISTURE_FACTOR_IN_RANGE
	var distance: int = CROP_MOISTURE_MIN[crop_id] - moisture
	if moisture > CROP_MOISTURE_MAX[crop_id]:
		distance = moisture - CROP_MOISTURE_MAX[crop_id]
	if distance <= MOISTURE_NEAR_MARGIN:
		return MOISTURE_FACTOR_NEAR
	return MOISTURE_FACTOR_FAR


func growth_step_milli_hours(temperature_factor: int, moisture_factor: int) -> IntMath.IntResult:
	"""REQ-SET-072's whole hourly step. See growth_step_milli_hours_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	growth_step_milli_hours_into(temperature_factor, moisture_factor, out)
	return out


func growth_step_milli_hours_into(temperature_factor: int, moisture_factor: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating growth_step_milli_hours(): `1000*tf*mf/1000000`, floored.

	This is the figure §5.6 prints. `advance_growth_hour_into()` uses the same numerator but
	retains the sub-milli-hour remainder in TileHistory.growth_remainder instead of flooring it
	away, which is what REQ-SET-072's "retain fractional progress" requires.
	"""
	if temperature_factor < 0 or moisture_factor < 0:
		return out.refuse(String(REFUSE_INVALID_FACTOR))
	if not IntMath.checked_mul_into(temperature_factor, moisture_factor, out):
		return false
	if not IntMath.checked_mul_into(MILLI_HOURS_PER_HOUR, out.value, out):
		return false
	return IntMath.floor_div_into(out.value, GROWTH_FACTOR_DENOMINATOR, out)


# --- lifecycle -------------------------------------------------------------------------------------------

func create_plot_at_tile(tile: int, soil: int) -> OpResult:
	"""Allocate one FarmPlot row on an unoccupied tile, COPYING that tile's existing soil history.

	ARCH-STATE-003: recreating a field "SHALL copy the existing tile state; it SHALL not restore
	fertility or reset compost eligibility". Fertility, the last crop family, the last legume day
	and the compost season therefore come from the tile, not from §5.6's 7000 starting value --
	which a tile only still carries if nothing has ever worked it. Refuses, allocating nothing,
	on an off-grid tile, an occupied tile or an unknown soil.
	"""
	if not is_tile_index(tile):
		return _refuse(REFUSE_INVALID_TILE)
	if _tile_active_plot_row[tile] != NO_ROW:
		return _refuse(REFUSE_TILE_OCCUPIED)
	if not is_soil(soil):
		return _refuse(REFUSE_INVALID_SOIL)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_FARM_PLOT)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_row(slot, ref, tile, soil)
	return _succeed(slot, ref)


func _write_created_row(slot: int, ref: Vector2i, tile: int, soil: int) -> void:
	"""Write every §4.2 column of a new plot and link it to its tile in both directions."""
	_present[slot] = 1
	_crop_id[slot] = CROP_NONE
	_state[slot] = STATE_EMPTY
	_soil[slot] = soil
	_fertility[slot] = _tile_fertility[tile]
	_moisture[slot] = INITIAL_MOISTURE
	_growth_milli_hours[slot] = 0
	_health[slot] = INITIAL_HEALTH
	_last_family[slot] = _tile_last_family[tile]
	_family_streak[slot] = 0
	_compost_milli[slot] = 0
	_sow_day[slot] = 0
	_tile[slot] = tile
	_ref_slot[slot] = ref.x
	_ref_generation[slot] = ref.y
	_tile_active_plot_row[tile] = slot
	_insert_live_slot(slot)


func destroy(ref: Vector2i) -> OpResult:
	"""Remove one plot and release its directory slot, LEAVING THE TILE'S HISTORY INTACT.

	Returns the freed tile. Fertility, last family, last legume day, compost season, ripe tick,
	growth remainder and the tending flag are TileHistory's and are not touched here -- that is
	ARCH-STATE-003 and BAL-SAFE-014. Refuses a stale or wrong-kind reference rather than clearing
	whatever row it points at, which is what makes a reused slot safe.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_FARM_PLOT):
		return _refuse(REFUSE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	var tile: int = _tile[slot]
	if is_tile_index(tile) and _tile_active_plot_row[tile] == slot:
		_tile_active_plot_row[tile] = NO_ROW
	_present[slot] = 0
	_crop_id[slot] = CROP_NONE
	_state[slot] = STATE_EMPTY
	_tile[slot] = NO_ROW
	_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_remove_live_slot(slot)
	_directory.destroy(ref)
	return _succeed(tile, NULL_REF)


func _insert_live_slot(slot: int) -> void:
	"""Insert a created row into the ascending live list, keeping iteration order stable."""
	var index: int = _live_count
	while index > 0 and _live_slots[index - 1] > slot:
		_live_slots[index] = _live_slots[index - 1]
		index -= 1
	_live_slots[index] = slot
	_live_count += 1


func _remove_live_slot(slot: int) -> void:
	"""Remove a row from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_count and _live_slots[index] != slot:
		index += 1
	if index >= _live_count:
		return
	while index + 1 < _live_count:
		_live_slots[index] = _live_slots[index + 1]
		index += 1
	_live_count -= 1
	_live_slots[_live_count] = EntityDirectory.NULL_SLOT


# --- §4.2 FarmPlot readers -------------------------------------------------------------------------------

func count() -> int:
	"""Number of live farm plots."""
	return _live_count


func live_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live row in ascending slot order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _live_count:
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_live_slots[index])
	return out


func ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a row, or the null reference when the row is empty."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_ref_slot[slot], _ref_generation[slot])


func has_plot_at_tile(tile: int) -> bool:
	"""True when a tile currently carries a live FarmPlot row."""
	return is_tile_index(tile) and _tile_active_plot_row[tile] != NO_ROW


func plot_at_tile(tile: int) -> IntMath.IntResult:
	"""TileHistory.active_plot_row: the plot on a tile, or an explicit refusal when none is."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	if _tile_active_plot_row[tile] == NO_ROW:
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(_tile_active_plot_row[tile])
	return out


func tile_of(slot: int) -> IntMath.IntResult:
	"""The tile a plot stands on, or an explicit refusal."""
	return _read(slot, _tile)


func crop_id_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `crop_id` column, or CROP_NONE on a plot with nothing sown."""
	return _read(slot, _crop_id)


func state_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `state` column, one of §4.3's five CropState values."""
	return _read(slot, _state)


func soil_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `soil` column, one of §4.3's three Soil values."""
	return _read(slot, _soil)


func fertility_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `fertility` column, the mirror of this tile's authoritative TileHistory value."""
	return _read(slot, _fertility)


func moisture_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `moisture` column, clamped to REQ-SET-086's 0..10000."""
	return _read(slot, _moisture)


func health_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `health` column, 0..10000."""
	return _read(slot, _health)


func last_family_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `last_family` column, or FAMILY_NONE when no crop has been harvested here."""
	return _read(slot, _last_family)


func family_streak_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `family_streak` column: consecutive HARVESTS of `last_family` (see the header)."""
	return _read(slot, _family_streak)


func sow_day_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `sow_day` column, the absolute calendar day the current crop was planted."""
	return _read(slot, _sow_day)


func growth_milli_hours_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `growth_milli_hours` column: REQ-SET-072's retained integrated progress."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(_growth_milli_hours[slot])
	return out


func compost_milli_of(slot: int) -> IntMath.IntResult:
	"""§4.2's `compost_milli` column: compost applied to this plot (see the header on its reading)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(_compost_milli[slot])
	return out


func _read(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 column of a live row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


# --- TileHistory readers (systems_architecture.md §2) ------------------------------------------------------

func tile_fertility_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.fertility: the authoritative soil value that outlives every FarmPlot row."""
	return _read_tile(tile, _tile_fertility)


func tile_last_family_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.last_family: the last family harvested here, surviving a designation redraw."""
	return _read_tile(tile, _tile_last_family)


func tile_last_legume_day_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.last_legume_day: REQ-SET-078's 12-day legume bonus clock, or 0 for none."""
	return _read_tile(tile, _tile_last_legume_day)


func tile_compost_season_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.compost_season: REQ-SET-076's gate, as an ABSOLUTE season index (see header)."""
	return _read_tile(tile, _tile_compost_season)


func tile_active_plot_row_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.active_plot_row: the live FarmPlot row here, or NO_ROW."""
	return _read_tile(tile, _tile_active_plot_row)


func tile_orchard_row_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.orchard_row: always NO_ROW here -- REQ-SET-079-083 orchards are increment 8."""
	return _read_tile(tile, _tile_orchard_row)


func tile_ripe_tick_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.ripe_tick: the tick REQ-SET-075's grace and withering run from, or -1."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_tile_ripe_tick[tile])
	return out


func tile_growth_remainder_of(tile: int) -> IntMath.IntResult:
	"""TileHistory.growth_remainder: REQ-SET-072's retained sub-milli-hour fraction."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_tile_growth_remainder[tile])
	return out


func is_tile_tended_today(tile: int) -> bool:
	"""TileHistory.tended_today: ARCH-STATE-003's "growing-day service state" for one tile."""
	return is_tile_index(tile) and _tile_tended_today[tile] == 1


func _read_tile(tile: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 TileHistory column, refusing an off-grid tile rather than defaulting."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(column[tile])
	return out


# --- planting (the two per-plot gates of REQ-SET-070; see the header for the other three) ---------------

func plant(slot: int, crop_id: int, day: int, season: int, season_day: int) -> OpResult:
	"""Commit a crop to an EMPTY plot and return the seed milli-units REQ-SET-071 must consume.

	Validates the two gates that are per-plot facts: §5.6's "incompatible soil rejects planting"
	and its planting window. Field connectivity, seed supply and output capacity are the other
	three gates of REQ-SET-070 and belong to increment 7, which also owns the triggering event
	§5.6 never states. NO SEED IS CONSUMED HERE -- the quantity is returned and `inventory.gd`
	owns the lot. The plot enters SOWN, not GROWING; see the header on that distinction.
	"""
	var code: StringName = _refuse_plant(slot, crop_id, day, season, season_day)
	if code != REFUSE_NONE:
		return _refuse(code)
	_state[slot] = STATE_SOWN
	_crop_id[slot] = crop_id
	_sow_day[slot] = day
	_growth_milli_hours[slot] = 0
	_health[slot] = INITIAL_HEALTH
	_tile_growth_remainder[_tile[slot]] = 0
	_tile_ripe_tick[_tile[slot]] = NO_RIPE_TICK
	return _succeed(CROP_SEED_MILLI[crop_id], ref_of(slot))


func _refuse_plant(slot: int, crop_id: int, day: int, season: int, season_day: int) -> StringName:
	"""The code blocking a planting, or REFUSE_NONE when both stated per-plot gates pass."""
	if not is_present(slot):
		return REFUSE_NOT_PRESENT
	if _state[slot] != STATE_EMPTY:
		return REFUSE_NOT_EMPTY
	if not is_crop(crop_id):
		return REFUSE_INVALID_CROP
	if not is_season(season):
		return REFUSE_INVALID_SEASON
	if not is_season_day(season_day):
		return REFUSE_INVALID_SEASON_DAY
	if (CROP_ALLOWED_SOILS[crop_id] & (1 << _soil[slot])) == 0:
		return REFUSE_SOIL_INCOMPATIBLE
	if not _is_plant_window(crop_id, season, season_day):
		return REFUSE_OUTSIDE_PLANT_WINDOW
	return _check_day(day)


func begin_growing(slot: int) -> OpResult:
	"""Move a SOWN plot to GROWING: §5.6's 4 WU of sowing work is complete.

	The work itself belongs to `jobs.gd`; this is the state change its completion applies. See
	the header -- §5.6 never states what separates SOWN from GROWING, and this is the reading.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_SOWN:
		return _refuse(REFUSE_NOT_SOWN)
	_state[slot] = STATE_GROWING
	return _succeed(STATE_GROWING, ref_of(slot))


# --- REQ-SET-072 hourly growth and REQ-SET-073 ripening ------------------------------------------------------

func growth_target_milli_hours_of(slot: int) -> IntMath.IntResult:
	"""The crop's stated duration in milli-hours: the threshold REQ-SET-073 marks RIPE at."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	if not is_crop(_crop_id[slot]):
		out.refuse(String(REFUSE_NO_CROP))
		return out
	out.succeed(CROP_GROWTH_HOURS[_crop_id[slot]] * MILLI_HOURS_PER_HOUR)
	return out


func advance_growth_hour(slot: int, temperature_tenths: int, tick: int) -> OpResult:
	"""One hour of REQ-SET-072 growth. See advance_growth_hour_into() for the contract."""
	if not advance_growth_hour_into(slot, temperature_tenths, tick, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_math.value, ref_of(slot))


func advance_growth_hour_into(slot: int, temperature_tenths: int, tick: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating advance_growth_hour(): integrate one hour and write the total into `out`.

	The step is `1000 milli-hours * temperature_factor * moisture_factor / 1000000`, with the
	sub-milli-hour fraction RETAINED in TileHistory.growth_remainder rather than floored away.
	Reaching the crop's duration marks the plot RIPE and dates TileHistory.ripe_tick with `tick`
	(REQ-SET-073); the priority-2 harvest job is the caller's, not this store's. `out` doubles as
	this call's scratch, so it must not be a result the caller still needs.
	"""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if _state[slot] != STATE_GROWING:
		return out.refuse(String(REFUSE_NOT_GROWING))
	if not is_crop(_crop_id[slot]):
		return out.refuse(String(REFUSE_NO_CROP))
	if tick < 0:
		return out.refuse(String(REFUSE_INVALID_TICK))
	var released: int = _release_growth_milli_hours(_tile[slot],
		temperature_factor_of(temperature_tenths), _moisture_factor(_crop_id[slot], _moisture[slot]))
	if not IntMath.checked_add_into(_growth_milli_hours[slot], released, out):
		return false
	_growth_milli_hours[slot] = out.value
	_ripen_if_complete(slot, tick)
	return out.succeed(_growth_milli_hours[slot])


func _release_growth_milli_hours(tile: int, temperature_factor: int, moisture_factor: int) -> int:
	"""Fold one hour's numerator into the tile's retained remainder; return the whole milli-hours.

	The numerator is at most `1000*1000*1000` and the retained remainder is always below
	1000000, so neither the sum nor the product can approach int64 -- no caller-supplied number
	reaches this, because both factors come from §5.6's own tables.
	"""
	var total: int = _tile_growth_remainder[tile] \
		+ MILLI_HOURS_PER_HOUR * temperature_factor * moisture_factor
	_tile_growth_remainder[tile] = total % GROWTH_FACTOR_DENOMINATOR
	return total / GROWTH_FACTOR_DENOMINATOR


func _ripen_if_complete(slot: int, tick: int) -> void:
	"""REQ-SET-073: mark RIPE and date the tile once growth reaches the crop's stated duration."""
	var target: int = CROP_GROWTH_HOURS[_crop_id[slot]] * MILLI_HOURS_PER_HOUR
	if _growth_milli_hours[slot] < target:
		return
	_state[slot] = STATE_RIPE
	_tile_ripe_tick[_tile[slot]] = tick


func is_ripe(slot: int) -> bool:
	"""True while a live plot stands RIPE and unharvested."""
	return is_present(slot) and _state[slot] == STATE_RIPE


func is_withered(slot: int) -> bool:
	"""True while a live plot stands WITHERED and awaiting REQ-SET-085's clearing job."""
	return is_present(slot) and _state[slot] == STATE_WITHERED


# --- REQ-SET-074 harvest yield -----------------------------------------------------------------------------

func fertility_factor_of(slot: int) -> IntMath.IntResult:
	"""§5.6's fertility factor `500+floor(fertility/20)`, clamped to its stated 500-1000 range."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	var factor: int = FERTILITY_FACTOR_BASE + _fertility[slot] / FERTILITY_FACTOR_DIVISOR
	out.succeed(clampi(factor, FERTILITY_FACTOR_MIN, FERTILITY_FACTOR_MAX))
	return out


func health_factor_of(slot: int) -> IntMath.IntResult:
	"""§5.6's health factor: "health 0-10000 divided by 10", so 0..1000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(_health[slot] / HEALTH_FACTOR_DIVISOR)
	return out


func rotation_factor_of(slot: int) -> IntMath.IntResult:
	"""§5.6's rotation factor for the crop currently standing on this plot."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	if not is_crop(_crop_id[slot]):
		out.refuse(String(REFUSE_NO_CROP))
		return out
	out.succeed(_rotation_factor(CROP_FAMILY[_crop_id[slot]], _last_family[slot],
		_family_streak[slot]))
	return out


static func _rotation_factor(family: int, last_family: int, streak: int) -> int:
	"""§5.6's rotation factor: 1000 first/changed, 850 second, 700 third+, 1100 legume after change.

	A streak below 1 alongside a matching family is what a designation redraw leaves behind --
	TileHistory restores the family but has no column for the count -- and is read as a SECOND
	consecutive harvest, never a first, so a redraw can never fabricate a rotation bonus.
	"""
	if last_family != family:
		if family == FAMILY_LEGUME and last_family != FAMILY_NONE:
			return ROTATION_FACTOR_LEGUME_AFTER_CHANGE
		return ROTATION_FACTOR_FIRST
	if maxi(streak, 1) + 1 == 2:
		return ROTATION_FACTOR_SECOND
	return ROTATION_FACTOR_THIRD_PLUS


func formula_yield_milli(slot: int, pollination_factor: int) -> IntMath.IntResult:
	"""REQ-SET-074's yield before REQ-SET-075's spoilage. See formula_yield_milli_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	formula_yield_milli_into(slot, pollination_factor, out)
	return out


func formula_yield_milli_into(slot: int, pollination_factor: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating formula_yield_milli(): REQ-SET-074's formula, capped at 125% of base.

	`floor(base*fertility*health*rotation*pollination/10^12)`. `pollination_factor` is an ARGUMENT
	because §5.6 sources it from hives, whose links are blocked by U6; 1000 is the stated neutral
	value. The loosest bound over the table maxima is 10000*1000*1000*1100*1150 = 1.265e16, four
	orders below int64, and every step is checked anyway. The 125% cap bounds the result whatever
	factor a caller passes; a factor large enough to overflow the product refuses instead.
	"""
	if pollination_factor < 0:
		return out.refuse(String(REFUSE_INVALID_FACTOR))
	if not _yield_product_into(slot, pollination_factor, out):
		return false
	if not IntMath.floor_div_into(out.value, YIELD_DENOMINATOR, out):
		return false
	var base: int = CROP_BASE_YIELD_MILLI[_crop_id[slot]]
	return out.succeed(mini(out.value, base * YIELD_CAP_NUMERATOR / YIELD_CAP_DENOMINATOR))


func _yield_product_into(slot: int, pollination_factor: int, out: IntMath.IntResult) -> bool:
	"""Multiply REQ-SET-074's five terms with a checked product at every step."""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if not is_crop(_crop_id[slot]):
		return out.refuse(String(REFUSE_NO_CROP))
	var factor: int = clampi(FERTILITY_FACTOR_BASE + _fertility[slot] / FERTILITY_FACTOR_DIVISOR,
		FERTILITY_FACTOR_MIN, FERTILITY_FACTOR_MAX)
	if not IntMath.checked_mul_into(CROP_BASE_YIELD_MILLI[_crop_id[slot]], factor, out):
		return false
	if not IntMath.checked_mul_into(out.value, _health[slot] / HEALTH_FACTOR_DIVISOR, out):
		return false
	factor = _rotation_factor(CROP_FAMILY[_crop_id[slot]], _last_family[slot], _family_streak[slot])
	if not IntMath.checked_mul_into(out.value, factor, out):
		return false
	return IntMath.checked_mul_into(out.value, pollination_factor, out)


# --- REQ-SET-075 ripe grace, decay and withering ------------------------------------------------------------

func ripe_elapsed_hours_of(slot: int, tick: int) -> IntMath.IntResult:
	"""Whole game hours since this plot ripened. See ripe_elapsed_hours_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	ripe_elapsed_hours_into(slot, tick, out)
	return out


func ripe_elapsed_hours_into(slot: int, tick: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating ripe_elapsed_hours_of(): `(tick - ripe_tick)/750`, floored.

	Refuses a plot that never ripened rather than reporting 0 hours, which would read as "ripe
	this instant" and hand a spoiled crop its full yield.
	"""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if tick < 0:
		return out.refuse(String(REFUSE_INVALID_TICK))
	var ripe_tick: int = _tile_ripe_tick[_tile[slot]]
	if ripe_tick == NO_RIPE_TICK:
		return out.refuse(String(REFUSE_RIPE_TICK_MISSING))
	if tick < ripe_tick:
		return out.refuse(String(REFUSE_INVALID_TICK))
	return IntMath.floor_div_into(tick - ripe_tick, SimClock.TICKS_PER_HOUR, out)


func ripe_decay_days_of(slot: int, tick: int) -> IntMath.IntResult:
	"""How many whole 10%-loss days REQ-SET-075 has applied. See ripe_decay_days_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	ripe_decay_days_into(slot, tick, out)
	return out


func ripe_decay_days_into(slot: int, tick: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating ripe_decay_days_of(): whole days elapsed since the 48-hour grace ended.

	0 for the whole grace period, 1 at 72 hours, 2 at 96, and 3 at 120 -- where the crop has
	already withered, so a live RIPE plot never reaches it. Both windows run from `ripe_tick`;
	see the header on that reading.
	"""
	if not ripe_elapsed_hours_into(slot, tick, out):
		return false
	if out.value < RIPE_GRACE_HOURS:
		return out.succeed(0)
	return IntMath.floor_div_into(out.value - RIPE_GRACE_HOURS, HOURS_PER_DAY, out)


func spoiled_yield_milli(base_milli: int, decay_days: int) -> IntMath.IntResult:
	"""REQ-SET-075's 10%-per-day loss. See spoiled_yield_milli_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	spoiled_yield_milli_into(base_milli, decay_days, out)
	return out


func spoiled_yield_milli_into(base_milli: int, decay_days: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating spoiled_yield_milli(): "losing 10% remaining yield/day", compounded.

	REMAINING yield, so each day multiplies by 900/1000 and floors -- not a flat 10% of the
	original. `decay_days` above the withering window is refused rather than compounded into an
	answer for a crop that no longer exists.
	"""
	if base_milli < 0:
		return out.refuse(String(REFUSE_INVALID_AMOUNT))
	if decay_days < 0 or decay_days > RIPE_WITHER_DAYS:
		return out.refuse(String(REFUSE_INVALID_AMOUNT))
	var remaining: int = base_milli
	var retained: int = FACTOR_DENOMINATOR - RIPE_LOSS_PER_1000_PER_DAY
	for _day: int in decay_days:
		if not IntMath.checked_mul_into(remaining, retained, out):
			return false
		if not IntMath.floor_div_into(out.value, FACTOR_DENOMINATOR, out):
			return false
		remaining = out.value
	return out.succeed(remaining)


func is_ripe_expired(slot: int, tick: int) -> bool:
	"""True once a RIPE plot has stood 5 days unharvested (REQ-SET-075's withering threshold)."""
	if not is_ripe(slot):
		return false
	if not ripe_elapsed_hours_into(slot, tick, _math):
		return false
	return _math.value >= RIPE_WITHER_DAYS * HOURS_PER_DAY


func apply_ripe_expiry(slot: int, tick: int) -> OpResult:
	"""REQ-SET-075: wither a RIPE plot that has stood 5 days unharvested. 1 if it withered, 0 if not.

	The "compost-equivalent waste" §5.6 describes is REQ-SET-085's clearing yield, returned by
	clear_withered(); nothing is spawned here.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_RIPE:
		return _refuse(REFUSE_NOT_RIPE)
	if not ripe_elapsed_hours_into(slot, tick, _math):
		return _refuse(StringName(_math.error))
	if _math.value < RIPE_WITHER_DAYS * HOURS_PER_DAY:
		return _succeed(0, ref_of(slot))
	_wither(slot)
	return _succeed(1, ref_of(slot))


func _wither(slot: int) -> void:
	"""REQ-SET-085's state change: WITHERED, and no further tending is recorded for the plot.

	Cancelling an already-queued Job row is `jobs.gd`'s through the ARCH-SYS-006 join; a WITHERED
	plot refuses tend() and harvest() here, so no further work can be recorded against it.
	"""
	_state[slot] = STATE_WITHERED
	_tile_tended_today[_tile[slot]] = 0


# --- harvest -------------------------------------------------------------------------------------------------

func harvest_yield_milli(slot: int, pollination_factor: int, tick: int) -> IntMath.IntResult:
	"""The yield a harvest at `tick` actually delivers. See harvest_yield_milli_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	harvest_yield_milli_into(slot, pollination_factor, tick, out)
	return out


func harvest_yield_milli_into(slot: int, pollination_factor: int, tick: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest_yield_milli(): REQ-SET-074's formula after REQ-SET-075's spoilage.

	`out` doubles as this call's scratch. The decay day count is read first and copied into a
	local, because the formula overwrites the same result object.
	"""
	if not ripe_decay_days_into(slot, tick, out):
		return false
	var decay_days: int = out.value
	if not formula_yield_milli_into(slot, pollination_factor, out):
		return false
	return spoiled_yield_milli_into(out.value, decay_days, out)


func harvest(slot: int, day: int, tick: int, pollination_factor: int) -> OpResult:
	"""REQ-SET-074: harvest a RIPE plot, apply its fertility change ONCE, and return the yield.

	The yield is computed in full -- and can refuse -- BEFORE anything is written, so a refusal
	leaves the plot exactly as it was (decision 0024). No lot is created: `inventory.gd` owns the
	produce. The plot returns to EMPTY with its rotation history advanced on both the plot and
	its tile.
	"""
	var code: StringName = _refuse_harvest(slot, day, tick)
	if code != REFUSE_NONE:
		return _refuse(code)
	if not harvest_yield_milli_into(slot, pollination_factor, tick, _math):
		return _refuse(StringName(_math.error))
	var yield_milli: int = _math.value
	_record_rotation(slot, day)
	_apply_fertility_delta(slot, -CROP_FERTILITY_COST[_crop_id[slot]])
	_reset_to_empty(slot)
	return _succeed(yield_milli, ref_of(slot))


func _refuse_harvest(slot: int, day: int, tick: int) -> StringName:
	"""The code blocking a harvest, or REFUSE_NONE when a RIPE plot can be taken on `day`."""
	if not is_present(slot):
		return REFUSE_NOT_PRESENT
	if _state[slot] != STATE_RIPE:
		return REFUSE_NOT_RIPE
	if not is_crop(_crop_id[slot]):
		return REFUSE_NO_CROP
	if tick < 0:
		return REFUSE_INVALID_TICK
	return _check_day(day)


func _record_rotation(slot: int, day: int) -> void:
	"""Advance §5.6's rotation history on the plot and mirror it onto the tile.

	The streak counts consecutive HARVESTS of one family (see the header). A LEGUME harvest also
	dates REQ-SET-078's 12-day fallow bonus, which is tile state and outlives the plot.
	"""
	var family: int = CROP_FAMILY[_crop_id[slot]]
	var streak: int = 1
	if _last_family[slot] == family:
		streak = maxi(_family_streak[slot], 1) + 1
	_last_family[slot] = family
	_family_streak[slot] = streak
	_tile_last_family[_tile[slot]] = family
	if family == FAMILY_LEGUME:
		_tile_last_legume_day[_tile[slot]] = day


func _reset_to_empty(slot: int) -> void:
	"""Return a harvested or cleared plot to EMPTY, keeping its soil, moisture and rotation history.

	The tile's tending flag is cleared with the crop that received the service: carrying it into a
	same-day replant would halve REQ-SET-087's blight loss for a crop nobody tended.
	"""
	_state[slot] = STATE_EMPTY
	_crop_id[slot] = CROP_NONE
	_growth_milli_hours[slot] = 0
	_health[slot] = INITIAL_HEALTH
	_sow_day[slot] = 0
	_tile_growth_remainder[_tile[slot]] = 0
	_tile_ripe_tick[_tile[slot]] = NO_RIPE_TICK
	_tile_tended_today[_tile[slot]] = 0


# --- REQ-SET-085 clearing a dead crop -------------------------------------------------------------------------

func clearing_work_milli_wu() -> int:
	"""REQ-SET-085's "10-WU clearing job", in milli-WU. The job itself is ARCH-SYS-006's."""
	return CLEARING_WORK_MILLI_WU


func clearing_compost_milli() -> int:
	"""REQ-SET-085's "compost 0.5 U/tile", in milli-units. No lot is created here."""
	return CLEARING_COMPOST_MILLI


func clear_withered(slot: int) -> OpResult:
	"""Clear a WITHERED plot and return the compost REQ-SET-085 says its clearing job yields.

	No fertility change is applied: §5.6 charges `fertility_cost` "per harvest", and a withered
	crop was never harvested.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_WITHERED:
		return _refuse(REFUSE_NOT_WITHERED)
	_reset_to_empty(slot)
	return _succeed(CLEARING_COMPOST_MILLI, ref_of(slot))


# --- REQ-SET-086 moisture, and §5.6 tending -------------------------------------------------------------------

func apply_moisture_delta(slot: int, delta: int) -> OpResult:
	"""REQ-SET-086: apply a weather moisture change and CLAMP the result to 0..10000.

	The clamp is stated, so this one does not refuse an overshoot -- it clamps, exactly as the
	requirement says. weather.gd's `moisture_delta_for()` supplies the day's figure; joining the
	two is increment 10.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if not IntMath.checked_add_into(_moisture[slot], delta, _math):
		return _refuse(REFUSE_OVERFLOW)
	_moisture[slot] = clampi(_math.value, MOISTURE_MIN, MOISTURE_MAX)
	return _succeed(_moisture[slot], ref_of(slot))


func needs_water(slot: int) -> bool:
	"""True when a growing plot's moisture is below its crop's stated minimum.

	This is the condition §5.6 attaches the tending water cost to: "Tending restores 1000
	moisture using water 0.25 U WHEN BELOW MINIMUM".
	"""
	if not is_present(slot) or not is_crop(_crop_id[slot]):
		return false
	return _moisture[slot] < CROP_MOISTURE_MIN[_crop_id[slot]]


func tend(slot: int) -> OpResult:
	"""§5.6's daily tending of a GROWING plot. Returns the water milli-units it consumes.

	Below the crop's minimum this restores 1000 moisture and costs water 0.25 U; at or above it
	the plot is still tended -- which is what halves REQ-SET-087's blight loss and REQ-SET-084's
	cabbage frost for the day -- and costs no water. No lot is consumed here.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_GROWING:
		return _refuse(REFUSE_NOT_GROWING)
	if not is_crop(_crop_id[slot]):
		return _refuse(REFUSE_NO_CROP)
	_tile_tended_today[_tile[slot]] = 1
	if _moisture[slot] >= CROP_MOISTURE_MIN[_crop_id[slot]]:
		return _succeed(0, ref_of(slot))
	_moisture[slot] = mini(_moisture[slot] + TEND_MOISTURE_RESTORE, MOISTURE_MAX)
	return _succeed(TEND_WATER_MILLI, ref_of(slot))


func tend_work_milli_wu() -> int:
	"""§5.6's "1 WU tending/day while growing", in milli-WU. The job itself is ARCH-SYS-006's."""
	return TEND_WORK_MILLI_WU


func sow_work_milli_wu() -> int:
	"""§5.6's "4 WU sowing", in milli-WU. The job itself is increment 7's, not this store's."""
	return SOW_WORK_MILLI_WU


func harvest_work_milli_wu() -> int:
	"""§5.6's "6 WU harvest", in milli-WU. The job itself is ARCH-SYS-006's."""
	return HARVEST_WORK_MILLI_WU


func harvest_job_priority() -> int:
	"""REQ-SET-073's stated harvest-job priority, 2. Exposed; NO JOB IS CREATED HERE."""
	return HARVEST_JOB_PRIORITY


func neutral_pollination_factor() -> int:
	"""§5.6's stated pollination factor for a crop with no hive: 1000. See the header on U6."""
	return POLLINATION_FACTOR_NEUTRAL


func clear_tended_today() -> void:
	"""Reset ARCH-STATE-003's service state for every tile: the daily boundary of REQ-SET-007.

	One fill over the ledger's 16384 bytes, allocating nothing. ARCH-SYS-006 owns calling it at
	midnight; nothing here advances a day.
	"""
	_tile_tended_today.fill(0)


# --- REQ-SET-084 frost and REQ-SET-087 blight ------------------------------------------------------------------

func frost_damage_per_hour_for(slot: int, temperature_tenths: int) -> IntMath.IntResult:
	"""REQ-SET-084's hourly frost damage. See frost_damage_per_hour_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	frost_damage_per_hour_into(slot, temperature_tenths, out)
	return out


func frost_damage_per_hour_into(slot: int, temperature_tenths: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating frost_damage_per_hour_for(): the crop's listed damage while below 0°C.

	"halved for cabbage in a tended plot" -- cabbage alone, and only while TileHistory records
	the plot tended today. At or above 0°C the damage is 0.
	"""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if not is_crop(_crop_id[slot]):
		return out.refuse(String(REFUSE_NO_CROP))
	if temperature_tenths >= FROST_TEMPERATURE_TENTHS:
		return out.succeed(0)
	var damage: int = CROP_FROST_DAMAGE_PER_HOUR[_crop_id[slot]]
	if _crop_id[slot] == CROP_CABBAGE and _tile_tended_today[_tile[slot]] == 1:
		damage = damage / CABBAGE_TENDED_FROST_DIVISOR
	return out.succeed(damage)


func apply_frost_hour(slot: int, temperature_tenths: int) -> OpResult:
	"""REQ-SET-084: remove one hour of frost damage from a GROWING crop. Returns health after.

	Health reaching 0 withers the plot (REQ-SET-085); the clearing job is the caller's.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_GROWING:
		return _refuse(REFUSE_NOT_GROWING)
	if not frost_damage_per_hour_into(slot, temperature_tenths, _math):
		return _refuse(StringName(_math.error))
	return _apply_health_loss(slot, _math.value)


func blight_damage_per_day_for(slot: int) -> IntMath.IntResult:
	"""REQ-SET-087's daily blight damage: 400, or 200 while TileHistory records the plot tended."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	if _tile_tended_today[_tile[slot]] == 1:
		out.succeed(BLIGHT_TENDED_HEALTH_LOSS_PER_DAY)
		return out
	out.succeed(BLIGHT_HEALTH_LOSS_PER_DAY)
	return out


func apply_blight_day(slot: int) -> OpResult:
	"""REQ-SET-087: remove one day of blight damage from a GROWING crop. Returns health after.

	Whether a blight event covers this plot is weather.gd's `is_blight_active()`; the caller
	makes that join (increment 10) and calls this only on a blighted day, which is also why
	"stop damage when the event ends" needs nothing here -- the call simply is not made.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_GROWING:
		return _refuse(REFUSE_NOT_GROWING)
	var damage: int = BLIGHT_HEALTH_LOSS_PER_DAY
	if _tile_tended_today[_tile[slot]] == 1:
		damage = BLIGHT_TENDED_HEALTH_LOSS_PER_DAY
	return _apply_health_loss(slot, damage)


func apply_health_loss(slot: int, amount: int) -> OpResult:
	"""Remove `amount` health from a GROWING crop, withering it at 0. Returns health after.

	The named cause is the caller's -- frost and blight have their own entry points above; this
	is the shared path for any other stated loss.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _state[slot] != STATE_GROWING:
		return _refuse(REFUSE_NOT_GROWING)
	if amount < 0:
		return _refuse(REFUSE_INVALID_AMOUNT)
	return _apply_health_loss(slot, amount)


func _apply_health_loss(slot: int, amount: int) -> OpResult:
	"""Apply a validated health loss, clamp at 0, and wither the plot when it reaches 0.

	REQ-SET-085: "If crop health reaches 0, then the system shall mark it withered, cancel
	tending/harvest, and create a 10-WU clearing job" -- the first two are here, the third is
	the caller's.
	"""
	_health[slot] = maxi(_health[slot] - amount, HEALTH_MIN)
	if _health[slot] == HEALTH_MIN:
		_wither(slot)
	return _succeed(_health[slot], ref_of(slot))


# --- REQ-SET-076 compost -----------------------------------------------------------------------------------

func absolute_season_of_day(day: int) -> IntMath.IntResult:
	"""The absolute season index a calendar day falls in: `(day-1)/12`, 0 for the first spring.

	NOT §4.3's 0-3 Season ordinal. REQ-SET-076's gate must distinguish spring of year 1 from
	spring of year 2, which a repeating ordinal cannot; see the header.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	absolute_season_of_day_into(day, out)
	return out


func absolute_season_of_day_into(day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating absolute_season_of_day(): write the absolute season index into `out`."""
	var code: StringName = _check_day(day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	return IntMath.floor_div_into(day - MIN_CALENDAR_DAY, DAYS_PER_SEASON, out)


func is_compost_eligible(tile: int, day: int) -> bool:
	"""REQ-SET-076's "at most once/tile/season", asked of the TILE so it survives a redraw.

	An off-grid tile or an invalid day reports false, because neither names an eligible tile.
	"""
	if not is_tile_index(tile):
		return false
	if not absolute_season_of_day_into(day, _math):
		return false
	return _tile_compost_season[tile] != _math.value


func compost_milli_per_tile() -> int:
	"""§5.6's "Compost applies 2 U/tile", in milli-units. No lot is consumed here."""
	return COMPOST_MILLI_PER_TILE


func apply_compost(slot: int, day: int) -> OpResult:
	"""REQ-SET-076: add 1500 fertility, capped 10000, once per tile per season. Returns the 2 U.

	The eligibility gate is TileHistory.compost_season, so destroying and recreating a plot
	cannot buy a second application in the same season (ARCH-STATE-003). The compost itself is
	not consumed here; the quantity is returned and `inventory.gd` owns the lot.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if not absolute_season_of_day_into(day, _math):
		return _refuse(StringName(_math.error))
	var season_index: int = _math.value
	if _tile_compost_season[_tile[slot]] == season_index:
		return _refuse(REFUSE_COMPOST_NOT_ELIGIBLE)
	_apply_fertility_delta(slot, COMPOST_FERTILITY_GAIN)
	_compost_milli[slot] = COMPOST_MILLI_PER_TILE
	_tile_compost_season[_tile[slot]] = season_index
	return _succeed(COMPOST_MILLI_PER_TILE, ref_of(slot))


func compost_work_milli_wu() -> int:
	"""§5.6's "for 8 WU" compost application work, in milli-WU. The job itself is ARCH-SYS-006's."""
	return COMPOST_WORK_MILLI_WU


# --- REQ-SET-078 fallow recovery -----------------------------------------------------------------------------

func fallow_gain_for(tile: int, day: int) -> IntMath.IntResult:
	"""REQ-SET-078's daily fallow gain for a tile. See fallow_gain_into()."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	fallow_gain_into(tile, day, out)
	return out


func fallow_gain_into(tile: int, day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating fallow_gain_for(): 50/day, plus 50 more for 12 days after a LEGUME harvest.

	§5.6: "Empty/fallow plot gains 50 fertility/day; last LEGUME crop adds another 50/day for the
	next 12 days." "The next 12 days" is read as the twelve days FOLLOWING the legume harvest
	day, so the bonus runs on `last_legume_day+1 .. last_legume_day+12` inclusive.
	"""
	if not is_tile_index(tile):
		return out.refuse(String(REFUSE_INVALID_TILE))
	var code: StringName = _check_day(day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	var gain: int = FALLOW_FERTILITY_PER_DAY
	var legume_day: int = _tile_last_legume_day[tile]
	if legume_day != NO_LEGUME_DAY and day > legume_day and day <= legume_day + LEGUME_FALLOW_DAYS:
		gain += LEGUME_FALLOW_BONUS_PER_DAY
	return out.succeed(gain)


func apply_fallow_day(tile: int, day: int) -> OpResult:
	"""REQ-SET-078: restore a fallow tile's fertility for one day, without a worker. Returns it.

	Addressed by TILE, because §5.6's "empty/fallow plot" includes ground with no designation on
	it at all, and ARCH-STATE-003 keeps that soil history whether a FarmPlot row exists or not.
	A tile whose plot is not EMPTY is refused: a growing crop is not fallow.
	"""
	if not fallow_gain_into(tile, day, _math):
		return _refuse(StringName(_math.error))
	var gain: int = _math.value
	var slot: int = _tile_active_plot_row[tile]
	if slot != NO_ROW and _state[slot] != STATE_EMPTY:
		return _refuse(REFUSE_NOT_EMPTY)
	_set_tile_fertility(tile, _tile_fertility[tile] + gain)
	return _succeed(_tile_fertility[tile], NULL_REF)


func fallow_fertility_per_day() -> int:
	"""REQ-SET-078's declared base rate: 50 fertility per fallow day."""
	return FALLOW_FERTILITY_PER_DAY


# --- fertility, written on the tile and mirrored to the plot ---------------------------------------------------

func _apply_fertility_delta(slot: int, delta: int) -> void:
	"""Change a plot's fertility and its tile's together, clamped to 0..10000 (see the header)."""
	_set_tile_fertility(_tile[slot], _tile_fertility[_tile[slot]] + delta)


func _set_tile_fertility(tile: int, value: int) -> void:
	"""Write TileHistory's authoritative fertility and mirror it onto the live plot, if any.

	Every fertility change in this module goes through here, so the tile and the §4.2 column
	cannot drift apart. The clamp is applied once, in this one place.
	"""
	_tile_fertility[tile] = clampi(value, FERTILITY_MIN, FERTILITY_MAX)
	var slot: int = _tile_active_plot_row[tile]
	if slot != NO_ROW:
		_fertility[slot] = _tile_fertility[tile]


# --- result helpers ---------------------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)
