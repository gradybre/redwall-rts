extends RefCounted
## The FishHabitat and FishStock stores of GDD §4.2, and the part of §5.4's fishing ecology that
## the document set fully specifies: the nine-row species table, daily recovery, seasonal
## availability, closure windows, the habitat daily quota, the conservation floors, the catch
## arithmetic and the effort-slot cap.
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "FishHabitat | type: enum, zone: EntityRef, capacity_milli: int64,
##     effort_slots: int32, pollution: int32, danger: int32, protected_fraction: int32 | One per
##     marked water basin; up to 32". systems_architecture.md §2.2 splits that row into
##     `type, zone_slot, zone_generation, effort_slots, pollution, danger, protected_fraction`
##     (I32, 7 columns, 32 rows) and `capacity_milli` (I64, 32). entity_directory.gd reserves
##     KIND_FISH_HABITAT at 32. All three agree and _init() asserts it.
##   * GDD §4.2: "FishStock | habitat: EntityRef, species_id: int32, population_milli: int64,
##     capacity_milli: int64, harvested_today_milli: int64, closed: bool | 3 stocks/habitat; no
##     shared global fish counter". systems_architecture.md §2.2 gives FishStock 96 rows and
##     annotates them "32*3", so the stock block is OWNER-MAJOR:
##     `stock_row = habitat_slot * 3 + species_index`.
##
##     That formula is DERIVABLE from two stated numbers -- §4.2's "3 stocks/habitat" and §2.2's
##     96 -- reinforced by §5.4's table listing exactly three species under each of River, Lake
##     and Coast. Nothing is invented to obtain it. Decision 0026 drew this distinction for
##     `ForagePatch` (derivable, 640 == 128 * 5) against `HivePollinationLinks` (blocker U6, no
##     stated formula and none derivable); this index is on the derivable side of that line.
##   * The three species of a habitat ARE §5.4's three table rows for its type, so
##     `species_index` addresses the table without a fourth column. WHICH three is an EXPLICIT
##     BINDING, not a formula: HABITAT_SPECIES_ROWS maps a compiled habitat id to its three
##     §5.4 rows. Stock addressing (`habitat_slot*3 + species_index`) and species identity used
##     to share the single expression `habitat_type*3 + species_index`, which was only ever
##     correct while the habitat ordinals happened to match §5.4's printed River/Lake/Coast row
##     order. They are two different things and are now stored as two different tables; under
##     the compiled ids (COAST=0, LAKE=1, RIVER=2) the shared formula would have handed a river
##     habitat the coast species silently, with no error anywhere.
##
## ---------------------------------------------------------------------------------------
## THE QUOTA, AND WHY IT IS EVIDENCE ABOUT FORAGE. §5.4 states the period outright -- "A
## habitat's sustainable daily quota is `floor(K_total_milli/40)` milli-U across species (2.5% of
## capacity)" -- and §4.2 gives FishStock the matching accumulator `harvested_today_milli`. Both
## halves are present here.
##
## `HarvestZone.quota_milli` in forage.gd has NEITHER: no clause states its period and
## `ForagePatch` has no `harvested_*` column but the year one that store had to fall back on.
## That contrast is the evidence for the open forage question, and it is recorded here because
## this is the module that shows what a fully specified quota looks like in the same document.
##
## The quota is measured per HABITAT and "across species", so remaining_quota_milli() sums the
## three stocks' `harvested_today_milli` against one habitat budget. Nothing here decides when
## "today" ends: reset_harvested_today() is the sweep and ARCH-SYS-005 (increment 9) owns the
## midnight call.
##
## ---------------------------------------------------------------------------------------
## THE CONSERVATION FLOORS AND THE INTENSIVE POLICY. §5.4: "Conservation defaults:25% habitat
## refuge and minimum stock 30%K. Hard harvest floor is 10%K; the 30% limit can be lowered by an
## explicitly visible "intensive harvest" policy, never by auto-fallback."
##
## "Never by auto-fallback" is enforced structurally, not by convention: harvest() takes NO
## intensive argument. The only input that can lower a floor below 30% is the habitat's stored
## `intensive_harvest` flag, written by exactly one setter. This deliberately differs from
## forage.gd's harvest(), which does take an `intensive` boolean -- §5.5 attaches no visibility
## requirement to its floors and §5.4 emphatically does.
##
## REQ-SET-047 ("While a spawning closure is active, the system shall prohibit intensive-harvest
## override for the closed species") is applied in floor_percent_for(): during a closure window
## the floor is 30% whatever the flag says. See the gap list on carp.
##
## ---------------------------------------------------------------------------------------
## NO RANDOM NUMBERS ARE DRAWN HERE. Every FISHING-stream draw ARCH-RNG-002 names belongs to a
## gear cycle or an expedition -- the hazard roll (REQ-SET-053) and the rare-quality roll
## (`min(1000,100+30*skill)` per 10000) -- and cycles are out of scope below. A draw taken here
## would consume a number the cycle owner is expecting and desynchronise every later replay, so
## this module does not take an Rng at all.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS STORE DELIBERATELY DOES NOT DO. None of it is stubbed; the numbers are simply not
## compiled in, so nothing here can drift from a contract that does not exist yet.
##   * GEAR. §5.4's gear table, durability 0-1000, wear per cycle, repairs and "a cycle cannot
##     start with durability below wear" all need a `GearInstance` store, which is blocker U5:
##     it has no row in §4.2, no length in systems_architecture.md §2.2 and no directory kind in
##     entity_directory.gd. The catch formula takes `base_catch_milli` as an ARGUMENT precisely
##     so §5.4's arithmetic is complete without it -- the gear table supplies that one number.
##   * EXPEDITIONS AND HAZARDS. REQ-SET-053/054's hazard roll, injury, rescue job and cargo
##     retention, and the rare-quality roll, need the `Expedition` allocator and per-cycle
##     FISHING draws. §4.2's Expedition row exists and its store does not.
##   * WEATHER-GATED ACCESS. REQ-SET-051 (winter ice, ice-kit crews, ice-access station) and
##     REQ-SET-052 (storm departures), plus mussel's "Summer blight event closes harvest", are
##     all weather-event conditions. CORRECTED 2026-09-09: weather is no longer blocked -- the
##     roll-to-row mapping was ruled (decision 0028) and weather.gd exists. This module still
##     evaluates no weather condition and no closure below is a blight closure, because JOINING
##     the two stores is ARCH-SYS-006's job (increment 10), not this store's.
##   * JOBS AND LOTS. REQ-SET-045's "create corresponding fish lots" and any FISH job creation
##     belong to later increments; §5.5's fishing has no stated job-creation trigger at all
##     (docs/tasks/03_ecology_crops_weather.md).
##   * AUTO-MODE SPECIES SELECTION. §5.4's "auto mode chooses highest `predicted_NP/work`" needs
##     a nutrition value per fish species; the nine species have none in §4.3's ItemDefinition
##     catalog or anywhere else. REQ-SET-046's fallback selection is therefore not implemented;
##     the closure readers it would need are.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md: "do not invent a constant"):
##   * `HabitatType` IS A COMPILED DOMAIN, AND THIS MODULE PREVIOUSLY GOT IT WRONG. An earlier
##     header here claimed §4.3 numbers no HabitatType and concluded a ruling was needed. The
##     rule was already stated -- GDD §4.2's closing paragraph numbers every gameplay enum it
##     does not individually list from the ascending ASCII keys of its own domain, and
##     BAL-CAT-001 repeats it -- and this module missed it, using §5.4's printed table order
##     (RIVER=0, LAKE=1, COAST=2) instead. What was genuinely open was only the key spelling:
##     docs/rulings/2026-09-09_ready06_open_item_answers.md §2 binds `FishHabitat.type` to the
##     canonical uppercase keys COAST, LAKE, RIVER, whose inherited ASCII order is COAST=0,
##     LAKE=1, RIVER=2. The ids live in catalog.gd's COMPILED_ENUM_DOMAINS -- read from there,
##     never mirrored -- and deliberately NOT in PROTECTED_ENUM_DOMAINS, which means "§4.3
##     stated this number". §5.1's terrain-mask phrase "coast, river, lake" orders prose, not
##     ordinals, and settles nothing either way. `type` is persisted state: the old ordinals are
##     NOT interchangeable with these, so any retained snapshot is translated through
##     Catalog.convert_legacy_id() (HabitatType map [2,1,0]) or refused.
##   * `species_id`'s DOMAIN IS UNSTATED. §4.2 types it int32 and never says which catalog. The
##     nine fish are not in item_definitions.gd, and §5.5 names them only as "edible aquatic
##     species ... explicitly sapient=false in the food-stock catalog", a catalog that does not
##     exist. This store validates the range only and refuses a negative id, the same treatment
##     `resource_id` has in resource_nodes.gd. SPECIES_KEYS holds §5.4's nine keys so a caller
##     can compile them once the owning catalog is settled.
##   * `pollution` HAS NO STATED EFFECT. It appears in §4.2's field list and nowhere else in the
##     document set -- no formula, no requirement, no range. It is stored and returned; no
##     reader or harvest path consults it. Inventing an effect would be inventing a contract.
##   * `protected_fraction`'s UNITS ARE UNSTATED, and so is what the refuge DOES. §5.4 states
##     "25% habitat refuge" as a conservation default; §4.2 gives an int32 `protected_fraction`
##     with no unit (percent? per-1000? tiles?) and no clause connects the two. The column is
##     stored and validated for range only. HABITAT_REFUGE_PERCENT compiles §5.4's 25 and
##     habitat_refuge_milli_of() expresses it against the habitat's own capacity, but NO harvest
##     path applies it: §5.4 states no mechanical effect for the refuge, and guessing one would
##     also double-count against the 30% minimum stock. When the unit is ruled on, the refuge
##     reader should read the column instead of the constant.
##   * "UP TO 32" HABITATS VERSUS §5.1's THREE. §4.2 allows 32 habitats and §5.1 says "There is
##     one stock basin of each habitat type; dividing a player zone never creates extra ecology
##     stock" -- three basins. That is the same tension decision 0026 resolved for forage by
##     hanging stock off the basin. It is NOT resolved unilaterally here: this store holds the
##     32 rows §4.2 and §2.2 both size, and adds no basin indirection, because FishStock's owner
##     is `habitat` and §5.4 gives no zone-sharing rule of its own. If a player designation is
##     ever allowed to create a habitat, the same anti-multiplication guard forage.gd has will
##     be needed here. NEEDS A PLANNER RULING.
##   * EFFORT-SLOT OCCUPANCY HAS NO COLUMN. §5.4 states the capacities ("Habitat effort capacity:
##     river 4, lake 6, coast 6") and REQ-SET-044 says a starting cycle "shall reserve its effort
##     slots", but §4.2's FishHabitat row has only `effort_slots` -- a capacity, with nowhere to
##     record how many are taken. The occupancy counter below is therefore an ADDED column, and
##     it is state a save would have to carry. REQ-SET-050's queue itself is NOT added: JobState
##     already has QUEUED=0 and §4.2 sizes the Job store at 8192 active/queued rows, so the queue
##     lives there. What this store owns is the cap that makes queueing necessary --
##     reserve_effort_slot() refuses once `effort_slots` are taken, so extra fishers can never
##     multiply a habitat's yield.
##   * REQ-SET-048's HYSTERESIS HAS NO COLUMN EITHER. "When fishing stock falls below 30%
##     capacity, the system shall warn of depletion and default to restocking until stock
##     recovers above 40%" needs one bit of memory: between 30% and 40% the required behaviour
##     depends on which threshold was crossed last, and population alone cannot answer that. The
##     two thresholds are stated explicitly and are NOT collapsed into one. `restocking` is an
##     added FishStock bit; §4.2 gives that row only `closed`.
##   * INTERPRETATION -- WHAT "DEFAULT TO RESTOCKING" DOES. Below 30% the 30% minimum stock
##     already refuses every harvest, so the restocking flag can only bite in the 30..40% band.
##     It is read there as blocking harvest, unless the habitat's visible intensive-harvest
##     policy is on (which §5.4 says lowers the 30% limit to the 10% hard floor). "Default to"
##     implies something the player may override, and the only override §5.4 offers is that
##     policy. Labelled an interpretation, in the manner resource_nodes.gd labelled
##     `regrow_days == 0`; a warning-only reading is the alternative and is one line away.
##   * CARP'S WINDOW IS NOT LABELLED A SPAWNING CLOSURE. §5.4 writes "Spring days 8-10 closure"
##     for carp against "spawning closure" for trout and salmon. REQ-SET-047 prohibits the
##     intensive override during "a spawning closure". is_closure_window() covers all three and
##     the override is refused in all three -- strictly safer, since it can only ever keep the
##     floor at 30%, never lower it. If carp's window is meant to permit the override, that is a
##     one-line change and a stated distinction this module cannot make for itself.
##   * `FishHabitat.zone`'s ZoneType CANNOT BE CHECKED HERE. §4.3 has ZoneType.FISH=0 and
##     forage.gd owns the HarvestZone store; reaching into it would fork ownership of that row.
##     A zone reference is validated as a live KIND_HARVEST_ZONE reference in the shared
##     directory, and the null reference `(-1, 0)` is accepted, because §5.1 puts a basin of each
##     habitat type on the map whether or not the player has designated a zone over it. Whoever
##     binds the two must check the type is FISH.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- capacities (GDD §4.2, systems_architecture.md §2.2, entity_directory.gd) ---------------------

## GDD §4.2: "One per marked water basin; up to 32".
const FISH_HABITAT_CAPACITY: int = 32
## GDD §4.2: "3 stocks/habitat".
const SPECIES_PER_HABITAT: int = 3
## systems_architecture.md §2.2 FishStock length: 96 == 32 * 3.
const FISH_STOCK_CAPACITY: int = FISH_HABITAT_CAPACITY * SPECIES_PER_HABITAT

# --- GDD §4.3 Season, read from catalog.gd's protected table (decision 0018) ----------------------

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4

## REQ-SET-006's "one season as 12 days", via sim_clock.gd's own constant rather than a mirror.
## §5.4's windows ("Spring days 5-7") are days WITHIN a season, which is what Calendar.season_day
## reports, numbered from 1.
const DAYS_PER_SEASON: int = SimClock.DAYS_PER_SEASON
const FIRST_SEASON_DAY: int = 1

# --- habitat type: catalog.gd's compiled HabitatType domain, see the header -----------------------

## Read from catalog.gd, never mirrored: `Catalog.HABITAT_TYPE[...]` is a constant expression, so
## there is exactly one copy of each id (GDD §4.2's closing paragraph via decision 0018's rule).
const HABITAT_TYPE_DOMAIN: String = Catalog.HABITAT_TYPE_DOMAIN
const HABITAT_COAST: int = Catalog.HABITAT_TYPE["COAST"]
const HABITAT_LAKE: int = Catalog.HABITAT_TYPE["LAKE"]
const HABITAT_RIVER: int = Catalog.HABITAT_TYPE["RIVER"]
const HABITAT_TYPE_COUNT: int = 3

## §5.4: "Habitat effort capacity: river 4, lake 6, coast 6." Indexed by the COMPILED habitat id,
## so a caller can never supply a slot count that disagrees with the specification. _init()
## asserts each entry against its named habitat, so this literal cannot drift out of that order.
const RIVER_EFFORT_SLOTS: int = 4
const LAKE_EFFORT_SLOTS: int = 6
const COAST_EFFORT_SLOTS: int = 6
const EFFORT_SLOTS_BY_TYPE: Array[int] = [
	COAST_EFFORT_SLOTS, LAKE_EFFORT_SLOTS, RIVER_EFFORT_SLOTS,
]

# --- GDD §5.4 species table, row for row ----------------------------------------------------------

## §5.4's nine table rows in the document's printed order. These are TABLE ROWS, not habitat ids
## and not catalog ids: HABITAT_SPECIES_ROWS binds a habitat to its three rows explicitly.
const SPECIES_TROUT: int = 0
const SPECIES_DACE: int = 1
const SPECIES_SALMON: int = 2
const SPECIES_PERCH: int = 3
const SPECIES_CARP: int = 4
const SPECIES_WHITEFISH: int = 5
const SPECIES_HERRING: int = 6
const SPECIES_MACKEREL: int = 7
const SPECIES_MUSSEL: int = 8
const SPECIES_COUNT: int = HABITAT_TYPE_COUNT * SPECIES_PER_HABITAT

## THE EXPLICIT HABITAT-ID-TO-SPECIES BINDING, flattened as `habitat_type*3 + species_index`.
## §5.4 lists trout/dace/salmon under River, perch/carp/whitefish under Lake and
## herring/mackerel/mussel under Coast; the compiled ids order those habitats COAST, LAKE, RIVER.
## Indexing a TABLE by a compiled id is not the same as COMPUTING identity from one -- see the
## header -- and _init() asserts this table and SPECIES_HABITAT_TYPE are mutual inverses.
const HABITAT_SPECIES_ROWS: Array[int] = [
	SPECIES_HERRING, SPECIES_MACKEREL, SPECIES_MUSSEL,
	SPECIES_PERCH, SPECIES_CARP, SPECIES_WHITEFISH,
	SPECIES_TROUT, SPECIES_DACE, SPECIES_SALMON,
]

## The same binding read backwards: §5.4's nine rows in printed order, each naming its habitat.
const SPECIES_HABITAT_TYPE: Array[int] = [
	HABITAT_RIVER, HABITAT_RIVER, HABITAT_RIVER,
	HABITAT_LAKE, HABITAT_LAKE, HABITAT_LAKE,
	HABITAT_COAST, HABITAT_COAST, HABITAT_COAST,
]

## §5.4's "Species" column. §5.5 confirms the same nine: "Edible aquatic species are exactly
## carp, dace, herring, mackerel, mussel, perch, salmon, trout and whitefish". Ids are compiled
## elsewhere (see the header on the unstated domain); these keys exist so a caller can resolve
## them once that catalog is settled.
const SPECIES_KEYS: Array[StringName] = [
	&"trout", &"dace", &"salmon",
	&"perch", &"carp", &"whitefish",
	&"herring", &"mackerel", &"mussel",
]

## §5.4's "Capacity U" column, whole units.
const SPECIES_CAPACITY_U: Array[int] = [600, 900, 600, 900, 700, 600, 1200, 900, 1000]

## §5.4's "Spring/Summer/Autumn/Winter availability" column, flattened as `species*4 + season`.
## Mackerel's winter 0 IS §5.4's "No winter harvest"; salmon's three zeroes are its autumn-only
## run. Herring's spring 1200 is overridden to 1500 on days 1-4 by its special window.
const SPECIES_AVAILABILITY_PER_1000: Array[int] = [
	1000, 800, 1000, 500,
	1000, 1200, 800, 300,
	0, 0, 2000, 0,
	800, 1200, 1000, 600,
	1000, 1300, 1000, 200,
	800, 700, 1000, 1000,
	1200, 1000, 800, 500,
	500, 1500, 1000, 0,
	800, 1000, 1200, 500,
]

## §5.4's "Daily recovery r/1000" column, the `r` of the midnight recovery formula.
const SPECIES_RECOVERY_PER_1000: Array[int] = [80, 120, 100, 100, 80, 90, 120, 100, 60]

# --- GDD §5.4 special windows ---------------------------------------------------------------------

## "River | trout | Spring days 5-7 spawning closure".
const TROUT_CLOSURE_FIRST_DAY: int = 5
const TROUT_CLOSURE_LAST_DAY: int = 7
## "River | salmon | Autumn days 1-4 harvest run; days 5-8 spawning closure".
const SALMON_RUN_FIRST_DAY: int = 1
const SALMON_RUN_LAST_DAY: int = 4
const SALMON_CLOSURE_FIRST_DAY: int = 5
const SALMON_CLOSURE_LAST_DAY: int = 8
## "Lake | carp | Spring days 8-10 closure". See the header: not labelled a SPAWNING closure.
const CARP_CLOSURE_FIRST_DAY: int = 8
const CARP_CLOSURE_LAST_DAY: int = 10
## "Coast | herring | Spring days 1-4 multiplier 1500 instead of 1200".
const HERRING_RUN_FIRST_DAY: int = 1
const HERRING_RUN_LAST_DAY: int = 4
const HERRING_RUN_PER_1000: int = 1500
## "Salmon additionally receive 300 U at autumn day 1, capped at K."
const SALMON_AUTUMN_RESTOCK_U: int = 300

# --- GDD §5.4 arithmetic ---------------------------------------------------------------------------

## AGENTS.md: "Quantities are quantity_milli:int64 (1000 = one unit)."
const MILLI_PER_UNIT: int = 1000

## §5.4: "Initial stocks are 80% of capacity."
const INITIAL_STOCK_NUMERATOR: int = 8
const INITIAL_STOCK_DENOMINATOR: int = 10

## §5.4: "At midnight `P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`". The 1000 is r's
## denominator; the 200 is external recruitment's, "not reproduction from nothing".
const RECOVERY_DENOMINATOR: int = 1000
const RECRUITMENT_DIVISOR: int = 200

## §5.4: "A habitat's sustainable daily quota is `floor(K_total_milli/40)` milli-U across
## species (2.5% of capacity)."
const DAILY_QUOTA_DIVISOR: int = 40

## §5.4 conservation defaults and floors.
const MIN_STOCK_PERCENT: int = 30
const HARD_FLOOR_PERCENT: int = 10
const HABITAT_REFUGE_PERCENT: int = 25
const PERCENT_DENOMINATOR: int = 100

## REQ-SET-048's two stated thresholds. Numerically 30 matches the minimum stock above, but it
## is a different sentence in a different requirement and is kept separate on purpose.
const DEPLETION_WARNING_PERCENT: int = 30
const RESTOCK_RECOVERY_PERCENT: int = 40

## §5.4: "Catch for species i is `floor(base_catch_milli*(1000+50*skill)*A*S/1000000000)`, where
## `A=clamp(floor(1000*P/K),200,1000)`".
const CATCH_BASE_TERM: int = 1000
const CATCH_SKILL_TERM: int = 50
const CATCH_DENOMINATOR: int = 1000000000
const ABUNDANCE_SCALE: int = 1000
const ABUNDANCE_MIN: int = 200
const ABUNDANCE_MAX: int = 1000

## §5.3: "Level=`min(10,floor_sqrt(floor(xp/5000)))`" -- skills are 0..10, not 0..20.
const SKILL_LEVEL_MIN: int = 0
const SKILL_LEVEL_MAX: int = 10

## §5.4: "danger 0-3".
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- refusal codes ---------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_HABITAT_NOT_PRESENT: StringName = &"HABITAT_NOT_PRESENT"
const REFUSE_STOCK_NOT_PRESENT: StringName = &"STOCK_NOT_PRESENT"
const REFUSE_INVALID_HABITAT_TYPE: StringName = &"INVALID_HABITAT_TYPE"
const REFUSE_INVALID_ZONE_REF: StringName = &"INVALID_ZONE_REF"
const REFUSE_INVALID_POLLUTION: StringName = &"INVALID_POLLUTION"
const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
const REFUSE_INVALID_PROTECTED_FRACTION: StringName = &"INVALID_PROTECTED_FRACTION"
const REFUSE_SPECIES_SET_SIZE: StringName = &"SPECIES_SET_SIZE"
const REFUSE_INVALID_SPECIES_ID: StringName = &"INVALID_SPECIES_ID"
const REFUSE_DUPLICATE_SPECIES_ID: StringName = &"DUPLICATE_SPECIES_ID"
const REFUSE_INVALID_SPECIES: StringName = &"INVALID_SPECIES"
const REFUSE_INVALID_SPECIES_INDEX: StringName = &"INVALID_SPECIES_INDEX"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_SEASON_DAY: StringName = &"INVALID_SEASON_DAY"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_INVALID_BASE_CATCH: StringName = &"INVALID_BASE_CATCH"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
const REFUSE_SPECIES_CLOSED: StringName = &"SPECIES_CLOSED"
const REFUSE_SPECIES_UNAVAILABLE: StringName = &"SPECIES_UNAVAILABLE"
const REFUSE_RESTOCKING: StringName = &"RESTOCKING"
const REFUSE_BELOW_STOCK_FLOOR: StringName = &"BELOW_STOCK_FLOOR"
const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
const REFUSE_EFFORT_SLOTS_FULL: StringName = &"EFFORT_SLOTS_FULL"
const REFUSE_NO_EFFORT_SLOT_RESERVED: StringName = &"NO_EFFORT_SLOT_RESERVED"
const REFUSE_EFFORT_SLOTS_RESERVED: StringName = &"EFFORT_SLOTS_RESERVED"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class OpResult:
	"""Outcome of one fishing operation: success flag, refusal code, value and reference.

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

# --- FishHabitat columns (ARCH-MEM-001: packed, allocated once) --------------------------------------

var _habitat_present: PackedByteArray = PackedByteArray()
var _habitat_type: PackedInt32Array = PackedInt32Array()
var _habitat_zone_slot: PackedInt32Array = PackedInt32Array()
var _habitat_zone_generation: PackedInt32Array = PackedInt32Array()
var _habitat_effort_slots: PackedInt32Array = PackedInt32Array()
var _habitat_pollution: PackedInt32Array = PackedInt32Array()
var _habitat_danger: PackedInt32Array = PackedInt32Array()
var _habitat_protected_fraction: PackedInt32Array = PackedInt32Array()
var _habitat_capacity_milli: PackedInt64Array = PackedInt64Array()

## The directory reference owning each habitat row, so a row can hand back a validatable ref.
var _habitat_ref_slot: PackedInt32Array = PackedInt32Array()
var _habitat_ref_generation: PackedInt32Array = PackedInt32Array()

## ADDED COLUMNS, see the header. Occupancy against §4.2's `effort_slots` capacity, and §5.4's
## "explicitly visible" intensive-harvest policy.
var _habitat_effort_used: PackedInt32Array = PackedInt32Array()
var _habitat_intensive: PackedByteArray = PackedByteArray()

## Ascending list of live habitat rows, so a daily sweep iterates habitats and not all 32 slots.
var _live_habitat_slots: PackedInt32Array = PackedInt32Array()
var _live_habitat_count: int = 0

# --- FishStock columns, owner-major at `habitat_slot * 3 + species_index` ------------------------------

var _stock_present: PackedByteArray = PackedByteArray()
var _stock_habitat_slot: PackedInt32Array = PackedInt32Array()
var _stock_habitat_generation: PackedInt32Array = PackedInt32Array()
var _stock_species_id: PackedInt32Array = PackedInt32Array()
var _stock_population_milli: PackedInt64Array = PackedInt64Array()
var _stock_capacity_milli: PackedInt64Array = PackedInt64Array()
var _stock_harvested_today_milli: PackedInt64Array = PackedInt64Array()
var _stock_closed: PackedByteArray = PackedByteArray()
## ADDED COLUMN, see the header: REQ-SET-048's 30-down/40-up hysteresis needs one bit of memory.
var _stock_restocking: PackedByteArray = PackedByteArray()

# --- scratch (not simulation state) -------------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## A second scratch for the paths that need a live value while computing another.
var _math_b: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and adopt or build the directory behind every habitat ref."""
	assert(FISH_HABITAT_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_FISH_HABITAT],
		"fish-habitat columns must match the directory's FISH_HABITAT row capacity")
	assert(SPECIES_KEYS.size() == SPECIES_COUNT, "GDD §5.4 lists exactly nine fish species")
	assert(SPECIES_CAPACITY_U.size() == SPECIES_COUNT, "one capacity per §5.4 species row")
	assert(SPECIES_RECOVERY_PER_1000.size() == SPECIES_COUNT, "one r per §5.4 species row")
	assert(SPECIES_AVAILABILITY_PER_1000.size() == SPECIES_COUNT * SEASON_COUNT,
		"§5.4 gives four seasonal availabilities for each of the nine species rows")
	assert(EFFORT_SLOTS_BY_TYPE.size() == HABITAT_TYPE_COUNT, "§5.4 gives three effort capacities")
	_assert_habitat_binding()
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _assert_habitat_binding() -> void:
	"""Assert the compiled HabitatType ids and the explicit species binding agree with §5.4.

	Three separate statements are checked against each other: catalog.gd's compiled ids against
	its own ASCII compiler, §5.4's effort capacities against the NAMED habitat they belong to
	(never a bare position), and HABITAT_SPECIES_ROWS against its inverse SPECIES_HABITAT_TYPE.
	"""
	assert(Catalog.verify_compiled_enum(HABITAT_TYPE_DOMAIN).ok,
		"HabitatType ids must be what ascending ASCII order generates")
	assert(Catalog.HABITAT_TYPE.size() == HABITAT_TYPE_COUNT, "§5.4 defines three habitats")
	assert(SPECIES_HABITAT_TYPE.size() == SPECIES_COUNT, "one habitat per §5.4 species row")
	assert(HABITAT_SPECIES_ROWS.size() == SPECIES_COUNT, "three species per §5.4 habitat")
	assert(EFFORT_SLOTS_BY_TYPE[HABITAT_RIVER] == RIVER_EFFORT_SLOTS, "§5.4: river 4")
	assert(EFFORT_SLOTS_BY_TYPE[HABITAT_LAKE] == LAKE_EFFORT_SLOTS, "§5.4: lake 6")
	assert(EFFORT_SLOTS_BY_TYPE[HABITAT_COAST] == COAST_EFFORT_SLOTS, "§5.4: coast 6")
	for habitat_type: int in HABITAT_TYPE_COUNT:
		for species_index: int in SPECIES_PER_HABITAT:
			var species: int = HABITAT_SPECIES_ROWS[habitat_type * SPECIES_PER_HABITAT
				+ species_index]
			assert(SPECIES_HABITAT_TYPE[species] == habitat_type,
				"the habitat-to-species binding must read back to the same habitat")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_allocate_habitat_columns()
	_allocate_stock_columns()


func _allocate_habitat_columns() -> void:
	"""Size the FishHabitat columns and the live-habitat index at 32 rows."""
	_habitat_present.resize(FISH_HABITAT_CAPACITY)
	_habitat_type.resize(FISH_HABITAT_CAPACITY)
	_habitat_zone_slot.resize(FISH_HABITAT_CAPACITY)
	_habitat_zone_generation.resize(FISH_HABITAT_CAPACITY)
	_habitat_effort_slots.resize(FISH_HABITAT_CAPACITY)
	_habitat_pollution.resize(FISH_HABITAT_CAPACITY)
	_habitat_danger.resize(FISH_HABITAT_CAPACITY)
	_habitat_protected_fraction.resize(FISH_HABITAT_CAPACITY)
	_habitat_capacity_milli.resize(FISH_HABITAT_CAPACITY)
	_habitat_ref_slot.resize(FISH_HABITAT_CAPACITY)
	_habitat_ref_generation.resize(FISH_HABITAT_CAPACITY)
	_habitat_effort_used.resize(FISH_HABITAT_CAPACITY)
	_habitat_intensive.resize(FISH_HABITAT_CAPACITY)
	_live_habitat_slots.resize(FISH_HABITAT_CAPACITY)


func _allocate_stock_columns() -> void:
	"""Size the FishStock columns at 96 rows (32 habitats x 3 species)."""
	_stock_present.resize(FISH_STOCK_CAPACITY)
	_stock_habitat_slot.resize(FISH_STOCK_CAPACITY)
	_stock_habitat_generation.resize(FISH_STOCK_CAPACITY)
	_stock_species_id.resize(FISH_STOCK_CAPACITY)
	_stock_population_milli.resize(FISH_STOCK_CAPACITY)
	_stock_capacity_milli.resize(FISH_STOCK_CAPACITY)
	_stock_harvested_today_milli.resize(FISH_STOCK_CAPACITY)
	_stock_closed.resize(FISH_STOCK_CAPACITY)
	_stock_restocking.resize(FISH_STOCK_CAPACITY)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live habitat's directory slot is released first, so dropping this store cannot strand
	allocated slots in a directory it does not own.
	"""
	_release_live_habitats()
	_clear_habitat_columns()
	_clear_stock_columns()
	if _owns_directory:
		_directory.clear()


func _release_live_habitats() -> void:
	"""Destroy the directory slot of every live habitat, so a clear leaks no allocation."""
	for index: int in _live_habitat_count:
		var slot: int = _live_habitat_slots[index]
		if slot < 0 or slot >= FISH_HABITAT_CAPACITY or _habitat_present[slot] != 1:
			continue
		_directory.destroy(Vector2i(_habitat_ref_slot[slot], _habitat_ref_generation[slot]))


func _clear_habitat_columns() -> void:
	"""Refill every FishHabitat column with its empty value (§4.2: refs (-1,0), counters 0)."""
	_habitat_present.fill(0)
	_habitat_type.fill(0)
	_habitat_zone_slot.fill(EntityDirectory.NULL_SLOT)
	_habitat_zone_generation.fill(EntityDirectory.NULL_GENERATION)
	_habitat_effort_slots.fill(0)
	_habitat_pollution.fill(0)
	_habitat_danger.fill(0)
	_habitat_protected_fraction.fill(0)
	_habitat_capacity_milli.fill(0)
	_habitat_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_habitat_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_habitat_effort_used.fill(0)
	_habitat_intensive.fill(0)
	_live_habitat_slots.fill(EntityDirectory.NULL_SLOT)
	_live_habitat_count = 0


func _clear_stock_columns() -> void:
	"""Refill every FishStock column with its empty value."""
	_stock_present.fill(0)
	_stock_habitat_slot.fill(EntityDirectory.NULL_SLOT)
	_stock_habitat_generation.fill(EntityDirectory.NULL_GENERATION)
	_stock_species_id.fill(-1)
	_stock_population_milli.fill(0)
	_stock_capacity_milli.fill(0)
	_stock_harvested_today_milli.fill(0)
	_stock_closed.fill(0)
	_stock_restocking.fill(0)


func directory() -> EntityDirectory:
	"""The allocator behind every fish-habitat reference."""
	return _directory


# --- GDD §5.4 species table -----------------------------------------------------------------------

func is_habitat_type(habitat_type: int) -> bool:
	"""True when `habitat_type` names one of §5.4's three habitats (river, lake, coast)."""
	return habitat_type >= 0 and habitat_type < HABITAT_TYPE_COUNT


func is_species(species: int) -> bool:
	"""True when `species` names one of §5.4's nine table rows."""
	return species >= 0 and species < SPECIES_COUNT


func is_species_index(species_index: int) -> bool:
	"""True when `species_index` names one of a habitat's three §4.2 stock slots."""
	return species_index >= 0 and species_index < SPECIES_PER_HABITAT


func species_of(habitat_type: int, species_index: int) -> IntMath.IntResult:
	"""§5.4's table row for one habitat type's `species_index`-th species."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	species_of_into(habitat_type, species_index, out)
	return out


func species_of_into(habitat_type: int, species_index: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating species_of(): read the explicit habitat-to-species binding into `out`.

	The lookup is a TABLE READ, never `habitat_type*3 + species_index` arithmetic: the compiled
	habitat ids do not follow §5.4's printed row order (see the header).
	"""
	if not is_habitat_type(habitat_type):
		return out.refuse(String(REFUSE_INVALID_HABITAT_TYPE))
	if not is_species_index(species_index):
		return out.refuse(String(REFUSE_INVALID_SPECIES_INDEX))
	return out.succeed(HABITAT_SPECIES_ROWS[habitat_type * SPECIES_PER_HABITAT + species_index])


func habitat_type_of_species(species: int) -> IntMath.IntResult:
	"""Which of §5.4's three habitats a species belongs to, from the explicit binding read back."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_species(species):
		out.refuse(String(REFUSE_INVALID_SPECIES))
		return out
	out.succeed(SPECIES_HABITAT_TYPE[species])
	return out


func species_capacity_milli(species: int) -> IntMath.IntResult:
	"""§5.4's "Capacity U" for one species, in milli-U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_species(species):
		out.refuse(String(REFUSE_INVALID_SPECIES))
		return out
	out.succeed(SPECIES_CAPACITY_U[species] * MILLI_PER_UNIT)
	return out


func species_recovery_per_1000(species: int) -> IntMath.IntResult:
	"""§5.4's "Daily recovery r/1000" for one species."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_species(species):
		out.refuse(String(REFUSE_INVALID_SPECIES))
		return out
	out.succeed(SPECIES_RECOVERY_PER_1000[species])
	return out


func capacity_milli_for_type(habitat_type: int) -> IntMath.IntResult:
	"""`K_total_milli`: the summed §5.4 capacity of one habitat type's three species."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_habitat_type(habitat_type):
		out.refuse(String(REFUSE_INVALID_HABITAT_TYPE))
		return out
	out.succeed(_capacity_milli_for_type(habitat_type))
	return out


static func _capacity_milli_for_type(habitat_type: int) -> int:
	"""Sum §5.4's three capacities for a validated habitat type, in milli-U.

	The nine capacities are compiled constants of at most 1200 U, so this sum is at most
	3100000 and cannot overflow; no caller-supplied number reaches it.
	"""
	var total: int = 0
	for species_index: int in SPECIES_PER_HABITAT:
		var species: int = HABITAT_SPECIES_ROWS[habitat_type * SPECIES_PER_HABITAT + species_index]
		total += SPECIES_CAPACITY_U[species] * MILLI_PER_UNIT
	return total


static func _percent_of(value_milli: int, percent: int) -> int:
	"""`floor(value_milli*percent/100)` for a compiled capacity, which cannot overflow.

	Every caller passes a `capacity_milli` that came from SPECIES_CAPACITY_U (at most 1200000)
	or from their sum (at most 3100000), and every percent here is at most 100, so the product
	is at most 310000000. Checked arithmetic is reserved for the caller-supplied catch path.
	"""
	return value_milli * percent / PERCENT_DENOMINATOR


# --- FishHabitat lifecycle ---------------------------------------------------------------------------

func create_habitat(habitat_type: int, zone_ref: Vector2i, species_ids: PackedInt32Array,
		pollution: int, danger: int, protected_fraction: int) -> OpResult:
	"""Create one §5.4 habitat together with its three §4.2 stocks, at §5.4's 80% of capacity.

	The habitat and its stocks are created in one operation because `capacity_milli` is
	`K_total_milli` -- the sum of the three species capacities -- so a habitat without its
	stocks would carry a quota basis nothing backs. `effort_slots` and every capacity come from
	§5.4's table, never from the caller. Everything is validated before the directory is
	touched, so a refusal allocates nothing.
	"""
	var code: StringName = _refuse_habitat_fields(habitat_type, zone_ref, pollution, danger,
		protected_fraction)
	if code == REFUSE_NONE:
		code = _refuse_species_ids(species_ids)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_FISH_HABITAT)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_habitat(slot, ref, habitat_type, zone_ref, pollution, danger,
		protected_fraction)
	_write_created_stocks(slot, ref, habitat_type, species_ids)
	return _succeed(slot, ref)


func _refuse_habitat_fields(habitat_type: int, zone_ref: Vector2i, pollution: int, danger: int,
		protected_fraction: int) -> StringName:
	"""The code blocking a habitat creation on its own §4.2 fields, or REFUSE_NONE.

	`pollution` and `protected_fraction` are range-checked only: neither has a stated effect or
	a stated unit (see the header), so no narrower rule can be honestly enforced.
	"""
	if not is_habitat_type(habitat_type):
		return REFUSE_INVALID_HABITAT_TYPE
	if zone_ref != NULL_REF \
			and not _directory.is_valid_of_kind(zone_ref, EntityDirectory.KIND_HARVEST_ZONE):
		return REFUSE_INVALID_ZONE_REF
	if pollution < 0 or not IntMath.fits_int32(pollution):
		return REFUSE_INVALID_POLLUTION
	if danger < DANGER_MIN or danger > DANGER_MAX:
		return REFUSE_INVALID_DANGER
	if protected_fraction < 0 or not IntMath.fits_int32(protected_fraction):
		return REFUSE_INVALID_PROTECTED_FRACTION
	return REFUSE_NONE


func _refuse_species_ids(species_ids: PackedInt32Array) -> StringName:
	"""The code blocking a habitat's three stock ids, or REFUSE_NONE when all three are storable.

	Duplicates are refused: two stocks of one habitat carrying the same id would make every
	`species_id` lookup ambiguous, and §5.4 gives each habitat three distinct species.
	"""
	if species_ids.size() != SPECIES_PER_HABITAT:
		return REFUSE_SPECIES_SET_SIZE
	for species_index: int in SPECIES_PER_HABITAT:
		var species_id: int = species_ids[species_index]
		if species_id < 0 or not IntMath.fits_int32(species_id):
			return REFUSE_INVALID_SPECIES_ID
		for other: int in species_index:
			if species_ids[other] == species_id:
				return REFUSE_DUPLICATE_SPECIES_ID
	return REFUSE_NONE


func _write_created_habitat(slot: int, ref: Vector2i, habitat_type: int, zone_ref: Vector2i,
		pollution: int, danger: int, protected_fraction: int) -> void:
	"""Write every §4.2 column of a freshly created habitat."""
	_habitat_present[slot] = 1
	_habitat_type[slot] = habitat_type
	_habitat_zone_slot[slot] = zone_ref.x
	_habitat_zone_generation[slot] = zone_ref.y
	_habitat_effort_slots[slot] = EFFORT_SLOTS_BY_TYPE[habitat_type]
	_habitat_pollution[slot] = pollution
	_habitat_danger[slot] = danger
	_habitat_protected_fraction[slot] = protected_fraction
	_habitat_capacity_milli[slot] = _capacity_milli_for_type(habitat_type)
	_habitat_ref_slot[slot] = ref.x
	_habitat_ref_generation[slot] = ref.y
	_habitat_effort_used[slot] = 0
	_habitat_intensive[slot] = 0
	_insert_live_habitat(slot)


func _write_created_stocks(slot: int, ref: Vector2i, habitat_type: int,
		species_ids: PackedInt32Array) -> void:
	"""Write the habitat's three FishStock rows at §5.4's "Initial stocks are 80% of capacity".

	`row` is the owner-major STOCK address `habitat_slot*3 + species_index`; `species` is the
	§5.4 table row the explicit binding gives this habitat. The two indices are unrelated.
	"""
	for species_index: int in SPECIES_PER_HABITAT:
		var row: int = slot * SPECIES_PER_HABITAT + species_index
		var species: int = HABITAT_SPECIES_ROWS[habitat_type * SPECIES_PER_HABITAT + species_index]
		var capacity: int = SPECIES_CAPACITY_U[species] * MILLI_PER_UNIT
		_stock_present[row] = 1
		_stock_habitat_slot[row] = ref.x
		_stock_habitat_generation[row] = ref.y
		_stock_species_id[row] = species_ids[species_index]
		_stock_capacity_milli[row] = capacity
		_stock_population_milli[row] = \
			capacity * INITIAL_STOCK_NUMERATOR / INITIAL_STOCK_DENOMINATOR
		_stock_harvested_today_milli[row] = 0
		_stock_closed[row] = 0
		_stock_restocking[row] = 0


func destroy_habitat(ref: Vector2i) -> OpResult:
	"""Remove one habitat and its three stocks, and free its directory slot.

	Returns the number of stock rows released. Refuses while an effort slot is still reserved --
	destroying the habitat under a live reservation would strand it -- and refuses a stale or
	wrong-kind reference rather than clearing whatever row it points at.
	"""
	if not habitat_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if _habitat_effort_used[slot] > 0:
		return _refuse(REFUSE_EFFORT_SLOTS_RESERVED)
	var released: int = _release_habitat_stocks(slot)
	_habitat_present[slot] = 0
	_habitat_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_habitat_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_habitat_zone_slot[slot] = EntityDirectory.NULL_SLOT
	_habitat_zone_generation[slot] = EntityDirectory.NULL_GENERATION
	_habitat_capacity_milli[slot] = 0
	_habitat_intensive[slot] = 0
	_remove_live_habitat(slot)
	_directory.destroy(ref)
	return _succeed(released, NULL_REF)


func _release_habitat_stocks(habitat_slot: int) -> int:
	"""Empty the three-row FishStock block a destroyed habitat owns. Returns rows released."""
	var released: int = 0
	for species_index: int in SPECIES_PER_HABITAT:
		var row: int = habitat_slot * SPECIES_PER_HABITAT + species_index
		if _stock_present[row] == 1:
			released += 1
		_stock_present[row] = 0
		_stock_habitat_slot[row] = EntityDirectory.NULL_SLOT
		_stock_habitat_generation[row] = EntityDirectory.NULL_GENERATION
		_stock_species_id[row] = -1
		_stock_population_milli[row] = 0
		_stock_capacity_milli[row] = 0
		_stock_harvested_today_milli[row] = 0
		_stock_closed[row] = 0
		_stock_restocking[row] = 0
	return released


func _insert_live_habitat(slot: int) -> void:
	"""Insert a created habitat into the ascending live list, keeping iteration order stable."""
	var index: int = _live_habitat_count
	while index > 0 and _live_habitat_slots[index - 1] > slot:
		_live_habitat_slots[index] = _live_habitat_slots[index - 1]
		index -= 1
	_live_habitat_slots[index] = slot
	_live_habitat_count += 1


func _remove_live_habitat(slot: int) -> void:
	"""Remove a habitat from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_habitat_count and _live_habitat_slots[index] != slot:
		index += 1
	if index >= _live_habitat_count:
		return
	while index + 1 < _live_habitat_count:
		_live_habitat_slots[index] = _live_habitat_slots[index + 1]
		index += 1
	_live_habitat_count -= 1
	_live_habitat_slots[_live_habitat_count] = EntityDirectory.NULL_SLOT


# --- FishHabitat readers ---------------------------------------------------------------------------

func is_habitat_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a live fish habitat."""
	return slot >= 0 and slot < FISH_HABITAT_CAPACITY and _habitat_present[slot] == 1


func habitat_count() -> int:
	"""Number of live fish habitats."""
	return _live_habitat_count


func live_habitat_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live habitat in ascending slot order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _live_habitat_count:
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_live_habitat_slots[index])
	return out


func habitat_ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a habitat row, or the §4.1 null reference `(-1, 0)`."""
	if not is_habitat_present(slot):
		return NULL_REF
	return Vector2i(_habitat_ref_slot[slot], _habitat_ref_generation[slot])


func habitat_slot_of(ref: Vector2i) -> IntMath.IntResult:
	"""The row a live fish-habitat reference addresses, or an explicit refusal when it is stale."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	habitat_slot_of_into(ref, out)
	return out


func habitat_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating habitat_slot_of(): write the validated row into caller-owned `out`."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_FISH_HABITAT):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	var slot: int = _directory.get_typed_row(ref)
	if not is_habitat_present(slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	return out.succeed(slot)


func _read_habitat(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 habitat column of a live row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_habitat_present(slot):
		out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


func habitat_type_of(slot: int) -> IntMath.IntResult:
	"""The habitat's §5.4 type. See the header: this ordinal is module-local, not a §4.3 enum."""
	return _read_habitat(slot, _habitat_type)


func effort_slots_of(slot: int) -> IntMath.IntResult:
	"""§5.4's "Habitat effort capacity: river 4, lake 6, coast 6" for this habitat."""
	return _read_habitat(slot, _habitat_effort_slots)


func pollution_of(slot: int) -> IntMath.IntResult:
	"""The habitat's §4.2 `pollution`. Stored and returned; no rule in the GDD consumes it."""
	return _read_habitat(slot, _habitat_pollution)


func danger_of(slot: int) -> IntMath.IntResult:
	"""The habitat's §5.4 danger band, 0..3 -- the hazard input the expedition store will need."""
	return _read_habitat(slot, _habitat_danger)


func protected_fraction_of(slot: int) -> IntMath.IntResult:
	"""The habitat's §4.2 `protected_fraction`. See the header on its unstated unit."""
	return _read_habitat(slot, _habitat_protected_fraction)


func habitat_zone_ref_of(slot: int) -> Vector2i:
	"""The HarvestZone this habitat is bound to, or the §4.1 null reference `(-1, 0)`."""
	if not is_habitat_present(slot):
		return NULL_REF
	return Vector2i(_habitat_zone_slot[slot], _habitat_zone_generation[slot])


func habitat_capacity_milli_of(slot: int) -> IntMath.IntResult:
	"""`K_total_milli`: the habitat's §4.2 capacity, which the daily quota is a fraction of."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	habitat_capacity_milli_into(slot, out)
	return out


func habitat_capacity_milli_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating habitat_capacity_milli_of(): write `K_total_milli` into caller-owned `out`."""
	if not is_habitat_present(slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	return out.succeed(_habitat_capacity_milli[slot])


func habitat_refuge_milli_of(slot: int) -> IntMath.IntResult:
	"""§5.4's "25% habitat refuge" default, expressed against this habitat's own capacity.

	NOTHING APPLIES THIS. §5.4 states the refuge as a conservation default and states no
	mechanical effect for it, and §4.2's `protected_fraction` -- the field it presumably
	configures -- has no stated unit. See the header; this reader exists so the number is in one
	place when the contract is settled, not so a harvest path can quietly consume it.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_habitat_present(slot):
		out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
		return out
	out.succeed(_percent_of(_habitat_capacity_milli[slot], HABITAT_REFUGE_PERCENT))
	return out


# --- REQ-SET-050 effort slots ------------------------------------------------------------------------

func reserve_effort_slot(ref: Vector2i) -> OpResult:
	"""Take one of §5.4's effort slots for a fisher. Returns the number of slots now taken.

	REQ-SET-050: "While a habitat's effort slots are occupied, the system shall queue further
	fishers rather than multiply yield with unbounded workers." This is the half that makes
	queueing necessary -- once `effort_slots` are taken, a further reservation is REFUSED, so no
	extra worker can draw a second catch from the same habitat at the same time. The queue
	itself is the Job store's `JobState.QUEUED`; see the header on why no queue is added here.
	"""
	if not habitat_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if _habitat_effort_used[slot] >= _habitat_effort_slots[slot]:
		return _refuse(REFUSE_EFFORT_SLOTS_FULL)
	_habitat_effort_used[slot] += 1
	return _succeed(_habitat_effort_used[slot], ref)


func release_effort_slot(ref: Vector2i) -> OpResult:
	"""Give one effort slot back. Returns the number of slots still taken.

	Refuses when nothing is reserved rather than clamping at zero: a release without a matching
	reservation is a bookkeeping error in the caller, and silently absorbing it would let a
	double release open a slot that was never closed.
	"""
	if not habitat_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if _habitat_effort_used[slot] <= 0:
		return _refuse(REFUSE_NO_EFFORT_SLOT_RESERVED)
	_habitat_effort_used[slot] -= 1
	return _succeed(_habitat_effort_used[slot], ref)


func effort_slots_used_of(slot: int) -> IntMath.IntResult:
	"""How many of a habitat's effort slots are currently reserved."""
	return _read_habitat(slot, _habitat_effort_used)


func effort_slots_free_of(slot: int) -> IntMath.IntResult:
	"""How many of a habitat's effort slots are still free, never below 0."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	effort_slots_free_into(slot, out)
	return out


func effort_slots_free_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating effort_slots_free_of(): write the free-slot count into caller-owned `out`."""
	if not is_habitat_present(slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	return out.succeed(maxi(_habitat_effort_slots[slot] - _habitat_effort_used[slot], 0))


func must_queue(ref: Vector2i) -> bool:
	"""REQ-SET-050: true when a further fisher must queue because every effort slot is taken.

	A stale reference reports true, because a fisher cannot be admitted to a habitat that is not
	there either; reserve_effort_slot() is the form that refuses with the reason.
	"""
	if not habitat_slot_of_into(ref, _math_b):
		return true
	var slot: int = _math_b.value
	return _habitat_effort_used[slot] >= _habitat_effort_slots[slot]


# --- §5.4 intensive-harvest policy -------------------------------------------------------------------

func set_intensive_harvest(ref: Vector2i, enabled: bool) -> OpResult:
	"""§5.4's "explicitly visible 'intensive harvest' policy". Returns 1 when on, 0 when off.

	This is the ONLY way the 30% minimum stock can become the 10% hard floor. No harvest,
	reservation or catch path takes an intensive argument, so §5.4's "never by auto-fallback" is
	structural here rather than a convention a later caller could break. REQ-SET-049's duty to
	"show the 10% hard stock floor and predicted recovery time before accepting that policy" is
	the UI's half: HARD_FLOOR_PERCENT and floor_percent_for() supply the floor, and no predicted
	recovery time is computed because §5.4 states no horizon for one.
	"""
	if not habitat_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	_habitat_intensive[_math.value] = 1 if enabled else 0
	return _succeed(_habitat_intensive[_math.value], ref)


func is_intensive_harvest(slot: int) -> bool:
	"""True when this habitat's visible intensive-harvest policy is on."""
	return is_habitat_present(slot) and _habitat_intensive[slot] == 1


func intensive_permitted_for(species: int, season: int, season_day: int) -> bool:
	"""REQ-SET-047: false while a closure window is active for this species.

	"While a spawning closure is active, the system shall prohibit intensive-harvest override
	for the closed species." All three of §5.4's windows count; see the header on carp, whose
	window §5.4 does not call a spawning closure. Being stricter can only keep a floor at 30%.
	"""
	if not is_species(species) or not is_season(season) or not is_season_day(season_day):
		return false
	return not _is_closure_window(species, season, season_day)


# --- FishStock readers -------------------------------------------------------------------------------

func is_stock_present(row: int) -> bool:
	"""True when `row` is in range and holds a live fish stock."""
	return row >= 0 and row < FISH_STOCK_CAPACITY and _stock_present[row] == 1


func stock_row_of(ref: Vector2i, species_index: int) -> IntMath.IntResult:
	"""The FishStock row for one of a habitat's three species, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	stock_row_into(ref, species_index, out)
	return out


func stock_row_into(ref: Vector2i, species_index: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating stock_row_of(): write `habitat_slot*3 + species_index` into `out`."""
	if not is_species_index(species_index):
		return out.refuse(String(REFUSE_INVALID_SPECIES_INDEX))
	if not habitat_slot_of_into(ref, out):
		return false
	var row: int = out.value * SPECIES_PER_HABITAT + species_index
	if _stock_present[row] != 1:
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	return out.succeed(row)


func species_of_row(row: int) -> IntMath.IntResult:
	"""Which of §5.4's nine species a live stock row holds, from the owner-major index."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	out.succeed(_species_of_row(row))
	return out


func _species_of_row(row: int) -> int:
	"""§5.4's table row for a validated stock row, through the explicit habitat binding.

	The stock row is decomposed with `SPECIES_PER_HABITAT` because stock storage IS owner-major;
	the species then comes from HABITAT_SPECIES_ROWS, not from the habitat id's arithmetic.
	"""
	var habitat_slot: int = row / SPECIES_PER_HABITAT
	var species_index: int = row % SPECIES_PER_HABITAT
	var habitat_type: int = _habitat_type[habitat_slot]
	return HABITAT_SPECIES_ROWS[habitat_type * SPECIES_PER_HABITAT + species_index]


func stock_habitat_ref_of(row: int) -> Vector2i:
	"""The habitat a live stock belongs to, or the §4.1 null reference `(-1, 0)`."""
	if not is_stock_present(row):
		return NULL_REF
	return Vector2i(_stock_habitat_slot[row], _stock_habitat_generation[row])


func species_id_of(row: int) -> IntMath.IntResult:
	"""The stock's §4.2 `species_id`. See the header on its unstated catalog domain."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	out.succeed(_stock_species_id[row])
	return out


func population_milli_of(row: int) -> IntMath.IntResult:
	"""The stock's `P` in milli-U, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	population_milli_into(row, out)
	return out


func population_milli_into(row: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating population_milli_of(): write `P` into caller-owned `out`."""
	if not is_stock_present(row):
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	return out.succeed(_stock_population_milli[row])


func stock_capacity_milli_of(row: int) -> IntMath.IntResult:
	"""The stock's `K` in milli-U, taken from §5.4's table and never from a caller."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	stock_capacity_milli_into(row, out)
	return out


func stock_capacity_milli_into(row: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating stock_capacity_milli_of(): write `K` into caller-owned `out`."""
	if not is_stock_present(row):
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	return out.succeed(_stock_capacity_milli[row])


func harvested_today_milli_of(row: int) -> IntMath.IntResult:
	"""The stock's §4.2 `harvested_today_milli`, the accumulator the daily quota is measured on."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	out.succeed(_stock_harvested_today_milli[row])
	return out


func reset_harvested_today() -> void:
	"""Zero every stock's daily harvested total. ARCH-SYS-005 owns the midnight call."""
	_stock_harvested_today_milli.fill(0)


func is_closed_flag(row: int) -> bool:
	"""The stored §4.2 `closed` bit alone, ignoring §5.4's calendar windows."""
	return is_stock_present(row) and _stock_closed[row] == 1


func set_closed(ref: Vector2i, species_index: int, closed: bool) -> OpResult:
	"""Write §4.2's stored `closed` bit for one stock. Returns 1 when closed, 0 when open.

	§4.2 stores `closed`, so it is a column and not merely a derived predicate -- an event-driven
	closure (mussel's summer blight) has nowhere else to live. NOTHING here syncs this bit with
	§5.4's calendar windows: is_harvest_closed() reports the union of the two, and ARCH-SYS-005
	owns any daily orchestration that would write the bit.
	"""
	if not stock_row_into(ref, species_index, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	_stock_closed[row] = 1 if closed else 0
	return _succeed(_stock_closed[row], ref)


# --- §5.4 seasonal availability and closure windows -----------------------------------------------

func is_season(season: int) -> bool:
	"""True when `season` is one of §4.3's four Season values."""
	return season >= 0 and season < SEASON_COUNT


func is_season_day(season_day: int) -> bool:
	"""True when `season_day` is a day within a season, 1..12 (REQ-SET-006, via sim_clock.gd).

	§5.4's windows ("Spring days 5-7") count days inside their season, which is exactly what
	`SimClock.Calendar.season_day` reports; nothing here reads a clock, so the caller passes it.
	"""
	return season_day >= FIRST_SEASON_DAY and season_day <= DAYS_PER_SEASON


func availability_per_1000(species: int, season: int, season_day: int) -> IntMath.IntResult:
	"""§5.4's seasonal availability multiplier `S` for one species, per 1000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	availability_per_1000_into(species, season, season_day, out)
	return out


func availability_per_1000_into(species: int, season: int, season_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating availability_per_1000(): write `S` into caller-owned `out`."""
	if not is_species(species):
		return out.refuse(String(REFUSE_INVALID_SPECIES))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if not is_season_day(season_day):
		return out.refuse(String(REFUSE_INVALID_SEASON_DAY))
	return out.succeed(_availability_of(species, season, season_day))


static func _availability_of(species: int, season: int, season_day: int) -> int:
	"""§5.4's `S` for validated arguments, including herring's spring day 1-4 window.

	"Coast | herring | Spring days 1-4 multiplier 1500 instead of 1200" is the only special
	window that changes a multiplier. Mackerel's "No winter harvest" and salmon's autumn-only run
	are already the table's own zeroes, and mussel's summer blight is an EVENT, not a calendar
	window -- it is not applied here (see the header).
	"""
	if species == SPECIES_HERRING and season == SEASON_SPRING \
			and season_day >= HERRING_RUN_FIRST_DAY and season_day <= HERRING_RUN_LAST_DAY:
		return HERRING_RUN_PER_1000
	return SPECIES_AVAILABILITY_PER_1000[species * SEASON_COUNT + season]


func is_closure_window(species: int, season: int, season_day: int) -> bool:
	"""True inside one of §5.4's three stated closure windows for this species.

	Trout spring 5-7 and salmon autumn 5-8 are "spawning closure"; carp spring 8-10 is written
	"closure" (see the header). An out-of-range argument reports false, because it names no
	window at all; availability_per_1000() is the form that refuses those with a reason.
	"""
	if not is_species(species) or not is_season(season) or not is_season_day(season_day):
		return false
	return _is_closure_window(species, season, season_day)


static func _is_closure_window(species: int, season: int, season_day: int) -> bool:
	"""§5.4's closure windows for validated arguments, species by species."""
	if species == SPECIES_TROUT and season == SEASON_SPRING:
		return season_day >= TROUT_CLOSURE_FIRST_DAY and season_day <= TROUT_CLOSURE_LAST_DAY
	if species == SPECIES_SALMON and season == SEASON_AUTUMN:
		return season_day >= SALMON_CLOSURE_FIRST_DAY and season_day <= SALMON_CLOSURE_LAST_DAY
	if species == SPECIES_CARP and season == SEASON_SPRING:
		return season_day >= CARP_CLOSURE_FIRST_DAY and season_day <= CARP_CLOSURE_LAST_DAY
	return false


func is_harvest_run(species: int, season: int, season_day: int) -> bool:
	"""§5.4's "Autumn days 1-4 harvest run" for salmon, the only stated run window.

	The run is not a bonus of its own: salmon's autumn multiplier is already 2000 for the whole
	season. This reports the window so a UI or a job planner can name it.
	"""
	if not is_species(species) or not is_season(season) or not is_season_day(season_day):
		return false
	if species != SPECIES_SALMON or season != SEASON_AUTUMN:
		return false
	return season_day >= SALMON_RUN_FIRST_DAY and season_day <= SALMON_RUN_LAST_DAY


func is_harvest_closed(row: int, season: int, season_day: int) -> bool:
	"""True when §5.4 permits no harvest job for this stock: the stored bit OR a closure window.

	§5.4: ""closed" means no harvest job, not zero population" -- the stock still recovers.
	"""
	if not is_stock_present(row) or not is_season(season) or not is_season_day(season_day):
		return true
	if _stock_closed[row] == 1:
		return true
	return _is_closure_window(_species_of_row(row), season, season_day)


# --- §5.4 daily recovery ---------------------------------------------------------------------------

func daily_recovery_milli(row: int, season: int, season_day: int) -> IntMath.IntResult:
	"""§5.4's midnight recovery increment for one stock, already capped at the room below K."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_recovery_milli_into(row, season, season_day, out)
	return out


func daily_recovery_milli_into(row: int, season: int, season_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_recovery_milli(): the increment of §5.4's `P'` formula, into `out`.

	`P'=min(K,P+floor(r*P*(K-P)/(1000*K))+floor(K/200))`, so the increment is
	`min(K-P, logistic + recruitment)`. §5.4: "Closed species still recover", and no closure or
	availability term appears anywhere in this function for that reason.
	"""
	if not is_stock_present(row):
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if not is_season_day(season_day):
		return out.refuse(String(REFUSE_INVALID_SEASON_DAY))
	var capacity: int = _stock_capacity_milli[row]
	var room: int = capacity - _stock_population_milli[row]
	if room <= 0:
		return out.succeed(0)
	if not _logistic_growth_into(row, capacity, room, out):
		return false
	var grown: int = out.value + capacity / RECRUITMENT_DIVISOR
	grown += _salmon_restock_milli(_species_of_row(row), season, season_day)
	return out.succeed(mini(grown, room))


func _logistic_growth_into(row: int, capacity: int, room: int, out: IntMath.IntResult) -> bool:
	"""§5.4's `floor(r*P*(K-P)/(1000*K))` term for one stock, into caller-owned `out`."""
	var recovery: int = SPECIES_RECOVERY_PER_1000[_species_of_row(row)]
	if not IntMath.checked_mul_into(recovery, _stock_population_milli[row], out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, room, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var numerator: int = out.value
	if not IntMath.checked_mul_into(RECOVERY_DENOMINATOR, capacity, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.floor_div_into(numerator, out.value, out)


static func _salmon_restock_milli(species: int, season: int, season_day: int) -> int:
	"""§5.4: "Salmon additionally receive 300 U at autumn day 1, capped at K." 0 otherwise.

	The cap is the caller's `min(K-P, ...)`: capping the sum at K is the same value as capping
	the logistic result first, because every term here is nonnegative.
	"""
	if species != SPECIES_SALMON or season != SEASON_AUTUMN:
		return 0
	if season_day != SALMON_RUN_FIRST_DAY:
		return 0
	return SALMON_AUTUMN_RESTOCK_U * MILLI_PER_UNIT


func recover_stock(row: int, season: int, season_day: int) -> OpResult:
	"""Apply one day of §5.4 recovery to one stock. Returns the population after recovery."""
	if not daily_recovery_milli_into(row, season, season_day, _math):
		return _refuse(StringName(_math.error))
	_stock_population_milli[row] += _math.value
	_update_restocking(row)
	return _succeed(_stock_population_milli[row], stock_habitat_ref_of(row))


func recover_daily(season: int, season_day: int) -> OpResult:
	"""Apply one day of recovery to every live stock. Returns how many stocks gained population.

	Iterates the ascending live-habitat list, so the order is slot order and not a hash order.
	ARCH-SYS-005 owns the midnight call; this is the sweep it needs, and nothing here reads a
	clock or resets the daily quota -- reset_harvested_today() is the separate step.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	if not is_season_day(season_day):
		return _refuse(REFUSE_INVALID_SEASON_DAY)
	var recovered: int = 0
	for index: int in _live_habitat_count:
		var base: int = _live_habitat_slots[index] * SPECIES_PER_HABITAT
		for species_index: int in SPECIES_PER_HABITAT:
			var row: int = base + species_index
			if _stock_present[row] != 1:
				continue
			if not daily_recovery_milli_into(row, season, season_day, _math):
				return _refuse(StringName(_math.error))
			if _math.value > 0:
				_stock_population_milli[row] += _math.value
				_update_restocking(row)
				recovered += 1
	return _succeed(recovered, NULL_REF)


# --- §5.4 daily quota -------------------------------------------------------------------------------

func daily_quota_milli_of(habitat_slot: int) -> IntMath.IntResult:
	"""§5.4's `floor(K_total_milli/40)`: one habitat's sustainable daily quota, across species."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_quota_milli_into(habitat_slot, out)
	return out


func daily_quota_milli_into(habitat_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_quota_milli_of(): write the daily quota into caller-owned `out`."""
	if not is_habitat_present(habitat_slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	return IntMath.floor_div_into(_habitat_capacity_milli[habitat_slot], DAILY_QUOTA_DIVISOR, out)


func harvested_today_total_of(habitat_slot: int) -> IntMath.IntResult:
	"""What a habitat has taken today across all three species, the quota's own accumulator."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	harvested_today_total_into(habitat_slot, out)
	return out


func harvested_today_total_into(habitat_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating harvested_today_total_of(): write the habitat's daily total into `out`."""
	if not is_habitat_present(habitat_slot):
		return out.refuse(String(REFUSE_HABITAT_NOT_PRESENT))
	var total: int = 0
	for species_index: int in SPECIES_PER_HABITAT:
		var row: int = habitat_slot * SPECIES_PER_HABITAT + species_index
		if _stock_present[row] != 1:
			continue
		if not IntMath.checked_add_into(total, _stock_harvested_today_milli[row], out):
			return out.refuse(String(REFUSE_OVERFLOW))
		total = out.value
	return out.succeed(total)


func remaining_quota_milli(habitat_slot: int) -> IntMath.IntResult:
	"""How much of §5.4's daily quota this habitat has left today, never below 0."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	remaining_quota_milli_into(habitat_slot, out)
	return out


func remaining_quota_milli_into(habitat_slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating remaining_quota_milli(): write the quota left today into caller-owned `out`.

	The quota is the HABITAT's and the accumulators are its three stocks', exactly as §5.4 words
	it ("across species"), so taking dace to the quota leaves nothing for trout that day.
	"""
	if not harvested_today_total_into(habitat_slot, out):
		return false
	var taken: int = out.value
	if not daily_quota_milli_into(habitat_slot, out):
		return false
	return out.succeed(maxi(out.value - taken, 0))


func is_quota_reached(habitat_slot: int) -> bool:
	"""True when a habitat has spent its whole daily quota and can release no more biomass."""
	if not remaining_quota_milli_into(habitat_slot, _math_b):
		return true
	return _math_b.value <= 0


# --- §5.4 conservation floors ------------------------------------------------------------------------

func floor_percent_for(row: int, season: int, season_day: int) -> IntMath.IntResult:
	"""The percentage of K this stock may not be taken below, right now: 30, or 10 intensively.

	§5.4: "minimum stock 30%K. Hard harvest floor is 10%K; the 30% limit can be lowered by an
	explicitly visible "intensive harvest" policy, never by auto-fallback." The ONLY input that
	returns 10 here is the habitat's stored policy flag; there is no argument, no fallback and
	no caller-supplied override. REQ-SET-047 restores 30 during a closure window.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	if not is_season_day(season_day):
		out.refuse(String(REFUSE_INVALID_SEASON_DAY))
		return out
	out.succeed(_floor_percent_for(row, season, season_day))
	return out


func _floor_percent_for(row: int, season: int, season_day: int) -> int:
	"""§5.4's floor percentage for a validated stock row, 30 by default and 10 intensively."""
	var habitat_slot: int = row / SPECIES_PER_HABITAT
	if _habitat_intensive[habitat_slot] != 1:
		return MIN_STOCK_PERCENT
	if _is_closure_window(_species_of_row(row), season, season_day):
		return MIN_STOCK_PERCENT
	return HARD_FLOOR_PERCENT


func harvest_floor_milli(row: int, season: int, season_day: int) -> IntMath.IntResult:
	"""The stock level this harvest may not take the population below, in milli-U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	harvest_floor_milli_into(row, season, season_day, out)
	return out


func harvest_floor_milli_into(row: int, season: int, season_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest_floor_milli(): write `floor(K*percent/100)` into caller-owned `out`."""
	if not is_stock_present(row):
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if not is_season_day(season_day):
		return out.refuse(String(REFUSE_INVALID_SEASON_DAY))
	var percent: int = _floor_percent_for(row, season, season_day)
	return out.succeed(_percent_of(_stock_capacity_milli[row], percent))


func allowed_stock_milli(row: int, season: int, season_day: int) -> IntMath.IntResult:
	"""How much biomass sits above the active floor and may legally be taken, never below 0."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	allowed_stock_milli_into(row, season, season_day, out)
	return out


func allowed_stock_milli_into(row: int, season: int, season_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating allowed_stock_milli(): write the stock above the floor into `out`."""
	if not harvest_floor_milli_into(row, season, season_day, out):
		return false
	return out.succeed(maxi(_stock_population_milli[row] - out.value, 0))


# --- REQ-SET-048 depletion warning and restocking hysteresis --------------------------------------------

func depletion_threshold_milli(row: int) -> IntMath.IntResult:
	"""REQ-SET-048's "below 30% capacity" warning level for one stock, in milli-U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	out.succeed(_percent_of(_stock_capacity_milli[row], DEPLETION_WARNING_PERCENT))
	return out


func recovery_threshold_milli(row: int) -> IntMath.IntResult:
	"""REQ-SET-048's "recovers above 40%" release level for one stock, in milli-U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_stock_present(row):
		out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
		return out
	out.succeed(_percent_of(_stock_capacity_milli[row], RESTOCK_RECOVERY_PERCENT))
	return out


func is_depleted(row: int) -> bool:
	"""REQ-SET-048's warning condition: population strictly below 30% of capacity."""
	if not is_stock_present(row):
		return false
	return _stock_population_milli[row] \
		< _percent_of(_stock_capacity_milli[row], DEPLETION_WARNING_PERCENT)


func is_restocking(row: int) -> bool:
	"""True while REQ-SET-048's restocking default is in force for this stock.

	It is set when the population falls below 30% of capacity and cleared only once the
	population rises above 40% -- two stated thresholds, deliberately not collapsed into one. In
	the 30..40% band the answer depends on which threshold was crossed last, which is why this
	is a stored bit and not a derivation.
	"""
	return is_stock_present(row) and _stock_restocking[row] == 1


func update_restocking(row: int) -> OpResult:
	"""Re-evaluate REQ-SET-048's hysteresis for one stock. Returns 1 when restocking, else 0.

	Both mutators here already call this, so it exists for a caller that changed a population by
	some other stated route; ARCH-SYS-005 may also sweep it at midnight.
	"""
	if not is_stock_present(row):
		return _refuse(REFUSE_STOCK_NOT_PRESENT)
	_update_restocking(row)
	return _succeed(_stock_restocking[row], stock_habitat_ref_of(row))


func _update_restocking(row: int) -> void:
	"""Apply REQ-SET-048's 30-down/40-up hysteresis to one validated stock row.

	Neither threshold is crossed in the band between them, so the flag is left exactly as it
	was: that retention IS the requirement's "until stock recovers above 40%".
	"""
	var capacity: int = _stock_capacity_milli[row]
	var population: int = _stock_population_milli[row]
	if population < _percent_of(capacity, DEPLETION_WARNING_PERCENT):
		_stock_restocking[row] = 1
	elif population > _percent_of(capacity, RESTOCK_RECOVERY_PERCENT):
		_stock_restocking[row] = 0


# --- §5.4 catch formula ------------------------------------------------------------------------------

func abundance_per_1000(row: int) -> IntMath.IntResult:
	"""§5.4's `A=clamp(floor(1000*P/K),200,1000)` for one stock."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	abundance_per_1000_into(row, out)
	return out


func abundance_per_1000_into(row: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating abundance_per_1000(): write `A` into caller-owned `out`."""
	if not is_stock_present(row):
		return out.refuse(String(REFUSE_STOCK_NOT_PRESENT))
	if not IntMath.checked_mul_into(ABUNDANCE_SCALE, _stock_population_milli[row], out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.floor_div_into(out.value, _stock_capacity_milli[row], out):
		return false
	return out.succeed(clampi(out.value, ABUNDANCE_MIN, ABUNDANCE_MAX))


func formula_catch_milli(row: int, base_catch_milli: int, skill: int, season: int,
		season_day: int) -> IntMath.IntResult:
	"""§5.4's catch formula alone, before the quota and floor limits are applied."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	formula_catch_milli_into(row, base_catch_milli, skill, season, season_day, out)
	return out


func formula_catch_milli_into(row: int, base_catch_milli: int, skill: int, season: int,
		season_day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating formula_catch_milli(): `floor(base*(1000+50*skill)*A*S/1000000000)`.

	`base_catch_milli` is an ARGUMENT because §5.4's "Base catch U/cycle" is a column of the gear
	table, and the gear store is blocker U5 (see the header). `skill` is a §5.3 FISH level, 0..10;
	a level outside that range is refused rather than scaled, and every multiplication is checked,
	so a caller passing an enormous base catch gets an OVERFLOW refusal and never a wrapped one.
	"""
	var code: StringName = _refuse_catch_arguments(row, base_catch_milli, skill, season,
		season_day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if not abundance_per_1000_into(row, out):
		return false
	var abundance: int = out.value
	var availability: int = _availability_of(_species_of_row(row), season, season_day)
	if not IntMath.checked_mul_into(base_catch_milli, CATCH_BASE_TERM + CATCH_SKILL_TERM * skill,
			out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, abundance, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, availability, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.floor_div_into(out.value, CATCH_DENOMINATOR, out)


func _refuse_catch_arguments(row: int, base_catch_milli: int, skill: int, season: int,
		season_day: int) -> StringName:
	"""The code blocking a catch computation, or REFUSE_NONE when every argument is usable."""
	if not is_stock_present(row):
		return REFUSE_STOCK_NOT_PRESENT
	if base_catch_milli < 0:
		return REFUSE_INVALID_BASE_CATCH
	if skill < SKILL_LEVEL_MIN or skill > SKILL_LEVEL_MAX:
		return REFUSE_INVALID_SKILL_LEVEL
	if not is_season(season):
		return REFUSE_INVALID_SEASON
	if not is_season_day(season_day):
		return REFUSE_INVALID_SEASON_DAY
	return REFUSE_NONE


func catch_milli(row: int, base_catch_milli: int, skill: int, season: int,
		season_day: int) -> IntMath.IntResult:
	"""§5.4's catch, limited to the remaining quota and the stock above the policy floor."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	catch_milli_into(row, base_catch_milli, skill, season, season_day, out)
	return out


func catch_milli_into(row: int, base_catch_milli: int, skill: int, season: int, season_day: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating catch_milli(): the legal catch for one cycle, into caller-owned `out`.

	§5.4: "Limit the result to remaining quota and allowed stock above policy floor." 0 is a
	truthful answer here and not a sentinel -- a closed, unavailable, quota-spent or floored
	stock really does offer nothing this cycle. harvest() is the form that refuses with a reason.
	"""
	var code: StringName = _refuse_catch_arguments(row, base_catch_milli, skill, season,
		season_day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if _harvest_block_code(row, season, season_day) != REFUSE_NONE:
		return out.succeed(0)
	if not formula_catch_milli_into(row, base_catch_milli, skill, season, season_day, out):
		return false
	var caught: int = out.value
	if not remaining_quota_milli_into(row / SPECIES_PER_HABITAT, out):
		return false
	caught = mini(caught, out.value)
	if not allowed_stock_milli_into(row, season, season_day, out):
		return false
	return out.succeed(mini(caught, out.value))


# --- harvest ------------------------------------------------------------------------------------------

func harvest(ref: Vector2i, species_index: int, amount_milli: int, season: int,
		season_day: int) -> OpResult:
	"""Take `amount_milli` from one of a habitat's stocks. Returns the population left after it.

	Refuses rather than clamping when the stock cannot legally give up exactly that much: a
	silent short delivery would let a cycle book more biomass than the habitat released. There
	is NO intensive-harvest argument -- §5.4's floor can be lowered only by the habitat's stored
	and visible policy, "never by auto-fallback".
	"""
	if not harvest_into(ref, species_index, amount_milli, season, season_day, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_math.value, ref)


func harvest_into(ref: Vector2i, species_index: int, amount_milli: int, season: int,
		season_day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest(): write the population remaining after the debit into `out`.

	`out` doubles as this call's scratch, so it must not be a result the caller still needs. A
	refusal debits nothing: neither the population nor the habitat's daily total is touched, and
	the restocking flag is left alone.
	"""
	if not stock_row_into(ref, species_index, out):
		return false
	var row: int = out.value
	var code: StringName = _check_harvest(row, amount_milli, season, season_day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	_stock_population_milli[row] -= amount_milli
	_stock_harvested_today_milli[row] += amount_milli
	_update_restocking(row)
	return out.succeed(_stock_population_milli[row])


func _check_harvest(row: int, amount_milli: int, season: int, season_day: int) -> StringName:
	"""REFUSE_NONE when this stock may legally give up exactly `amount_milli` right now."""
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if not is_season(season):
		return REFUSE_INVALID_SEASON
	if not is_season_day(season_day):
		return REFUSE_INVALID_SEASON_DAY
	var code: StringName = _harvest_block_code(row, season, season_day)
	if code != REFUSE_NONE:
		return code
	if not allowed_stock_milli_into(row, season, season_day, _math_b):
		return StringName(_math_b.error)
	if amount_milli > _math_b.value:
		return REFUSE_BELOW_STOCK_FLOOR
	if not remaining_quota_milli_into(row / SPECIES_PER_HABITAT, _math_b):
		return StringName(_math_b.error)
	if amount_milli > _math_b.value:
		return REFUSE_QUOTA_REACHED
	return REFUSE_NONE


func _harvest_block_code(row: int, season: int, season_day: int) -> StringName:
	"""Why no harvest job may run on this stock today, or REFUSE_NONE when one may.

	The three stated blocks, in order: §4.2's stored `closed` bit and §5.4's calendar closure
	windows; a seasonal availability of 0 (mackerel in winter, salmon outside autumn), which
	makes §5.4's catch formula zero anyway; and REQ-SET-048's restocking default, which the
	habitat's visible intensive-harvest policy overrides. That last one is an INTERPRETATION --
	see the header. Takes no scratch of its own, so any caller may hold a live result.
	"""
	var species: int = _species_of_row(row)
	if _stock_closed[row] == 1 or _is_closure_window(species, season, season_day):
		return REFUSE_SPECIES_CLOSED
	if _availability_of(species, season, season_day) == 0:
		return REFUSE_SPECIES_UNAVAILABLE
	if _stock_restocking[row] != 1:
		return REFUSE_NONE
	if _habitat_intensive[row / SPECIES_PER_HABITAT] == 1:
		return REFUSE_NONE
	return REFUSE_RESTOCKING


func harvest_block_code(row: int, season: int, season_day: int) -> StringName:
	"""Public form of the block reason, for a UI that must explain an unavailable species.

	Returns REFUSE_STOCK_NOT_PRESENT, REFUSE_INVALID_SEASON or REFUSE_INVALID_SEASON_DAY for a
	bad argument, so every path out of it names a condition rather than defaulting to "fine".
	"""
	if not is_stock_present(row):
		return REFUSE_STOCK_NOT_PRESENT
	if not is_season(season):
		return REFUSE_INVALID_SEASON
	if not is_season_day(season_day):
		return REFUSE_INVALID_SEASON_DAY
	return _harvest_block_code(row, season, season_day)


# --- result helpers ------------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)
