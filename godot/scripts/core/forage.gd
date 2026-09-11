extends RefCounted
## The HarvestZone store, its tile-membership links, and the ForagePatch stocks those zones
## harvest from: GDD §4.2's two rows and §5.5's forage rules (REQ-SET-066 to REQ-SET-069).
##
## SCHEMA, restated from the documents rather than summarised.
##   * GDD §4.2: "HarvestZone | type: enum, tiles: packed int32[], danger: int32,
##     quota_milli: int64, protected: bool, enabled: bool | Up to 128; tile membership max 16384
##     total zone links". systems_architecture.md §2.2 splits that row into `type, danger` (I32,
##     128 rows), `quota_milli` (I64, 128), `protected, enabled` (B8, 128) and
##     `HarvestZone.tiles | tile_id` (I32, 16384). entity_directory.gd reserves
##     KIND_HARVEST_ZONE at 128. All three agree and _init() asserts it.
##   * GDD §4.2: "ForagePatch | zone: EntityRef, item_id: int32, stock_milli: int64,
##     capacity_milli: int64, harvested_year_milli: int64 | 5 patches/forest zone".
##     systems_architecture.md §2.2 gives ForagePatch 640 rows, which is exactly 5 x 128, so the
##     patch block is OWNER-MAJOR: `patch_row = zone_slot * 5 + kind`. That formula is forced by
##     the two stated numbers; nothing is invented to obtain it.
##   * The five kinds are §5.5's five table rows, in the document's own order:
##     berries, nuts, mushrooms, herb, roots. The kind IS the row's index inside its owner block,
##     so the §5.5 table is addressable without a sixth column.
##
## ZoneType comes from catalog.gd's protected §4.3 table (decision 0018), never mirrored here.
## SET-AMEND-001 §3 retires `HUNT=1` to `RESERVED_1=1` and orders "reject creation";
## REQ-SET-060 repeats it, so create_zone() refuses that type before allocating anything.
##
## ---------------------------------------------------------------------------------------
## THE SHARING RULE, WHICH IS THE WHOLE POINT OF THE BASIN REFERENCE. GDD §5.1: "There is one
## stock basin of each habitat type; dividing a player zone never creates extra ecology stock"
## and "Player harvest zones reference basin IDs; all intersecting zones share its quotas and do
## not multiply capacity."
##
## So stock is a property of the BASIN, and a player zone is a designation that points at one.
## This store implements that literally:
##   * Every zone carries a basin reference. A freshly created zone is its OWN basin, so there
##     is no null case and no "unbound" state to forget about.
##   * set_basin() re-points a player zone at the basin zone whose stock it draws from. Chains
##     are refused, so basin_of(basin_of(z)) can never disagree with basin_of(z).
##   * Patches live on the basin zone. harvest() resolves zone -> basin -> patch row, so two
##     zones sharing a basin debit ONE stock column and accumulate ONE harvested_year_milli.
##   * A zone that already owns patches cannot be bound to another basin, and a zone bound to
##     another basin cannot be given patches. Those two refusals are what make "drawn twice"
##     unprofitable: the second designation cannot conjure a second stock to draw from.
##   * The quota is DAILY, AGGREGATE and SHARED -- see the next block. Both applicable limits are
##     enforced against their own collected and reserved totals, so a designation can be stricter
##     than its basin but never larger in effect.
##
## PROVISIONAL: SELF-REFERENCE AT CREATION. decision 0026's R05-BASIN-001/002 rule that a
## stock-owning basin may be created only by world generation or an explicit ecology-creation
## operation, and that a player designation binds to EXISTING ownership rather than creating a
## self-owned basin. create_zone() still makes a new zone its own basin. That stands only because
## no designation command exists (blocker U2) and a null basin would be an unbound state; it is
## NOT the finished contract. When the designation command lands it must bind through set_basin()
## and must not reach the self-owning creation path.
##
## ---------------------------------------------------------------------------------------
## THE DAILY AGGREGATE QUOTA (decision 0030; planner ruling 2026-09-09 §4, approved by Brendan).
## `HarvestZone.quota_milli` limits TOTAL forage collected per calendar day across all five kinds
## -- not per kind, and not per year. The basin's limit is shared by every designation bound to
## it, and a designation may impose an additional stricter local limit. With `Q` the effective
## daily quota, `H` today's collected total and `R` the outstanding reserved total:
##
##     available_quota = max(0, min(Q_b - H_b - R_b, Q_z - H_z - R_z))
##
## Stock floors, seasonal availability, protection, work eligibility and output capacity are
## INDEPENDENT restrictions; a larger quota overrides none of them. Collecting `amount` through
## designation `z` of basin `b` debits ONE harvest against TWO applicable policy limits -- it does
## not create duplicate inventory -- and when `z == b` that one zone's aggregates move ONCE.
##
## `ForagePatch.harvested_year_milli` stays ANNUAL ECOLOGICAL HISTORY and is not the quota
## accumulator. reset_harvested_year() is still the caller's year boundary and does not reopen a
## spent daily quota; run_midnight() is what does that.
##
## CLAIMS. One pending ForageClaim per owning Job, naming one basin, one designation, one kind and
## a remaining quantity; different kinds need different jobs, and shared work uses its COORDINATOR
## Job as the claim owner (decision 0017), so member Jobs duplicate nothing. Uncollected forage is
## ECOLOGICAL STOCK, not an InventoryLot, and no lot is fabricated to represent it.
##
##     stock_reserved  = sum(remaining_milli of active claims for this basin/patch)
##     stock_available = max(0, patch.stock_milli - applicable_stock_floor - stock_reserved)
##     admissible     <= min(available_quota, stock_available)
##
## claim_forage() preflights and commits quota and stock atomically or leaves every quantity
## unchanged. `claim_row = owning_job_typed_row` inside the existing 8192-Job capacity: an
## approved rule, not an inference from matching capacities, so there is no separate allocator and
## no free heap. The stored Job reference AND generation are validated before any use, so a
## retired or reused Job row can never act under a previous generation's claim.
##
## MIDNIGHT. run_midnight() applies the ruled order at a genuine offset-calendar crossing --
## `SimClock.is_day_boundary()`, NEVER `tick % 18000 == 0`, because tick 0 is 06:00 and the first
## midnight is tick 13500: reset collected totals, PRESERVE outstanding claims and their
## reservation totals, apply seasonal/automatic quota changes, release closure-invalidated claims
## and reconcile excess, and only then admit or collect. Outstanding claims consume part of the
## new day's allowance; collection is charged to the day it happens; hauling already collected
## cargo debits nothing. Annual counters reset only at the year boundary, and midnight never
## renews or extends a Job lease.
##
## RECONCILIATION. For a new effective quota `Q` and collected total `H`, the allowance for
## outstanding claims is `max(0, Q - H)`. Excess is released as WHOLE claims, newest first by
## `(job.created_tick, job.persistent_id)` DESCENDING, until the remainder fits: a job's promised
## collection is never silently shrunk, and a released claim must be reacquired before that job
## collects again. Releasing a claim yields no WU, XP, cargo or refund. Collected cargo always
## survives; a quota below today's collected total stops further collection without undoing
## history; quota zero releases every claim that zero limit reaches; deleting or rebinding a
## designation releases its claims FIRST and neither resets basin usage.
##
## MODES. Basins default to Automatic, designations to Inherit, and Manual survives a season
## change. The mode ids are compiled through catalog.gd's own ascending-ASCII mechanism rather
## than a second independent numbering scheme, and _init() asserts the compiled result, so
## `automatic=0, inherit=1, manual=2` cannot drift. They are NOT added to PROTECTED_ENUM_DOMAINS:
## §4.3 numbers no quota mode, and protecting a number nobody stated would give an implementer's
## choice the standing of a specified value -- the same reasoning HabitatType and WeatherEvent get.
##
##     target_stock_i = floor(800 * K_i / 1000)
##     allowance_i    = 0 if S_i == 0, else
##                      min(K_i - target_stock_i,
##                          floor((K_i - target_stock_i) * r_i * S_i / 1000000) + 1000)
##     automatic_daily_quota = sum over the five kinds
##
## giving spring 10720, summer 21128, autumn 22232 and winter 6056 milli-U/day. Manual settings run
## from 0 (no unlimited sentinel) to `sum(K_i)` = 1180000 milli-U/day, and a designation's larger
## manual value cannot expand its basin's allowance.
##
## ---------------------------------------------------------------------------------------
## RNG. ARCH-RNG-002 fixes the FORAGE stream's discipline exactly: "One hazard roll after each
## completed 60 WU exposure segment in natural danger>=1", ordered by "Worker ID, segment
## sequence". roll_exposure_injuries() therefore performs exactly one draw_below(FORAGE, 10000)
## per completed 60 WU segment and NONE at all at natural danger 0. Worker ordering belongs to
## the caller that walks its workers; this store rolls for one worker's segment run at a time.
## REQ-SET-068 gives the chance as `max(1, 8*danger - FORAGE_level)` per 10000, so a draw in
## [0, 10000) injures when it is strictly below that chance -- the only mapping that yields
## exactly `chance` outcomes in 10000.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS STORE DELIBERATELY DOES NOT DO.
##   * It CREATES NO JOB. No requirement in the document set states what creates a FORAGE job;
##     REQ-SET-073 makes FarmPlot the only automatic job-creation site. Inventing a trigger here
##     would be inventing a contract (docs/tasks/03_ecology_crops_weather.md).
##   * It does no world generation and no player-command designation. REQ-SET-009 is
##     unimplemented and there is no command path (blocker U2), so zones and patches are created
##     by an explicit caller.
##   * It does not apply REQ-SET-068's "10 health loss and severity 1 injury". Health lives in
##     needs.gd and the Injury row of §4.2 has no store yet. roll_exposure_injuries() reports how
##     many injuries were rolled; INJURY_HEALTH_LOSS and INJURY_SEVERITY are compiled here so the
##     store that lands them does not restate the numbers.
##   * It CREATES NO CARGO and RESERVES NO OUTPUT CAPACITY. §4.2's collection step says "create the
##     corresponding collected cargo exactly once"; lots and container capacity belong to
##     inventory.gd and the Job-owned output-capacity contract, and no binding between a Job and a
##     reserved container exists yet. collect_claim() returns the collected amount so its caller
##     creates that cargo exactly once. R05-QTEST-15's output-capacity leg therefore cannot be
##     exercised here; the quota and stock legs can, and are.
##   * It does not own STORAGE limits. REQ-SET-069's "stop new reservations and retain already
##     collected cargo for hauling" spans this store and inventory.gd; the forage-quota half is
##     owned here in full, the storage half is not.
##   * It does not implement the DESIGNATION PREVIEW (R05-DESIGNATION-001..004, ruling §4.8). That
##     needs the command queue (blocker U2) and the UI, and the ruling itself defers it to "when
##     their command/UI dependencies are available". Nothing here stubs it.
##   * It does not display R05-QUOTA-015's preview. claims_released_by_quota() is the
##     count-of-affected-jobs reader that display would read; the panel is ui's.
##   * It does not run §5.9's midnight wildlife-pressure roll. That is an ECOLOGY-stream draw
##     owned by ARCH-SYS-005, and its "complete enclosing fence/wall boundary" halving reads a
##     building store that does not exist.
##
## ---------------------------------------------------------------------------------------
## GAPS -- named, not invented (AGENTS.md: "do not invent a constant"):
##   * CORRECTED 2026-09-09. This header used to claim `quota_milli` "HAS NO STATED PERIOD" and
##     enforced the quota against each patch's ANNUAL total, which invented both an annual period
##     and a separate allowance per kind. THAT CLAIM WAS FALSE: `ui_ux_controls.md:219`
##     (UI-SET-050) already labelled the field "units per day". The period was stated, in the UI
##     document, and only the GDD and the architecture were searched. Decision 0030 records the
##     correction and the approved daily aggregate contract that replaced it.
##   * `quota_milli == 0` PERMITS NOTHING. The document states no "unlimited" encoding, §4.2 says
##     empty counters are 0, and the ruling makes the manual minimum zero with NO unlimited
##     sentinel. Zero is a zero budget: it admits nothing and releases every claim it reaches.
##   * R05-QUOTA-007's LEASE-EXPIRY TRIGGER IS UNREACHABLE. jobs.gd states that `lease_expiry`
##     exists, is always 0, and is never written because ARCH-JOB-004 is unimplemented. The
##     CANCELLATION half of that requirement is reachable and is implemented by
##     release_cancelled_claims(); the expiry half has nothing to fire on yet.
##   * THERE IS NO SAVE MODULE IN THIS REPOSITORY. R05-QUOTA-022's load path is implemented as
##     restore_claim() plus rebuild_reservation_aggregates(), which is the in-process substance of
##     it, but R05-QTEST-12's cross-process round trip CANNOT be executed and is not claimed.
##   * THE AUTOMATIC ALLOWANCE'S `K_i - target_stock_i` CAP NEVER BINDS with §5.5's published
##     capacities and regrowth fractions: the largest `floor((K-T)*r*S/1000000) + 1000` is 8200
##     against a 60000 headroom. It is implemented because the ruling states it, and a test that
##     removed it would still pass on the shipped table. Recorded rather than dropped.
##   * `stock_reserved` IS A LINEAR SCAN over the 8192 claim rows, deliberately. The ruling forbids
##     adding a stock-reservation index or cache inside §4.7's budget ("any such index must be
##     budgeted separately"), so the straightforward sum is used. UNMEASURED CONCERN: a claim-heavy
##     world pays 8192 byte reads per admissibility query and per reconciliation step, and no
##     profile of that cost has been taken on the REQ-SET-163 qualification floor.
##   * TWO ORDERING COLUMNS ARE EXTRA, AND COUNTED SEPARATELY. `(job.created_tick,
##     job.persistent_id)` is read from the owning Job ONCE at claim time and cached, because
##     jobs.gd's `created_tick_of()` allocates an IntResult and reconciliation compares that key
##     for every candidate claim. Neither value can change while a Job row lives, and both are
##     rebuilt by rebuild_reservation_aggregates(). They are 131072 bytes OUTSIDE the ruling's
##     305280-byte payload total, reported by extra_ordering_buffer_bytes() rather than hidden in
##     it (R05-QUOTA-024). No separate claim creation timestamp is introduced.
##   * A CLAIM'S OWNING JOB KIND IS NOT CHECKED. The ruling names the owner "the owning Job" and
##     never restricts it to JobKind.FORAGE. Refusing another kind would be inventing a contract,
##     so only membership (a member Job may not own a claim; its coordinator does) is enforced.
##   * ONE `danger` COLUMN, TWO STATED QUANTITIES. §5.5 defines natural danger ("the basin
##     center's distance category before lookout reductions, fixed at generation") for the
##     work-per-U formula, and separately says "Actual hazard danger still uses staffed lookouts
##     and resident consent". §4.2 gives HarvestZone exactly one `danger` field. Here the basin
##     zone's danger is the natural danger (nothing reduces it, because no lookout/building store
##     exists), and the harvesting zone's own danger is the hazard danger REQ-SET-067 gates on.
##     When staffed lookouts land, the reduced value needs its own field or a stated derivation.
##   * REQ-SET-067's "show an exposure warning" IS NOT IMPLEMENTED. Notices are §4.2's Notice
##     row with no store yet. check_worker_permitted() supplies the consent half only.
##   * THE REGROWTH FORMULA IS ADDITIVE AND CAPPED -- RULED, AND A CHANGE OF SHIPPED BEHAVIOUR.
##     §5.5 writes "Daily regrowth=floor((K-P)*r*season/1000000) plus a minimum 1 U when
##     season>0 and P<K" with no `min(K, ...)`, unlike §5.4's fish formula, which writes its cap
##     explicitly. Two separate questions sat inside that sentence and BAL-CONFLICT-012 named the
##     second one on its own: whether the 1 U is a floor (`max`) or a term (`plus`), and whether
##     the result may carry a patch above its own capacity column.
##     docs/rulings/2026-09-09_ready06_open_item_answers.md §8A settles both:
##
##         if S == 0 or P == K:  growth = 0
##         else:                 growth = min(K - P, floor((K - P) * r * S / 1000000) + 1000)
##
##     THE 1 U IS ADDED, NOT A FLOOR. This module previously computed `max(1000, ...)`, which is
##     what the ruling changes; every regrowth number in this store therefore moves, and the
##     ecology hashes with them. That is a deliberate behaviour change and NOT optimization
##     parity. The additive reading is also what decision 0030 §4.6's approved automatic-quota
##     allowance already used, so the two formulas in this file now read the same way rather than
##     disagreeing about the same sentence.
##     A MALFORMED `P > K` IS REFUSED rather than silently reported as zero growth: the ruling
##     says "reject malformed P>K instead of hiding corrupt state". No operation in this store can
##     produce it -- create_patch() writes 80% of K, harvest() only debits and regrowth is capped
##     -- so the guard is unreachable through the public API and is exercised through a subclass
##     in the suite. It is kept because a save/load path is coming and cannot be trusted.
##   * "5 patches/FOREST ZONE" IS READ AS ZoneType.FORAGE. §5.1 calls the ecology partitions
##     "forest ecology basins" and §4.3 has no FOREST zone type; FORESTRY is the wood-cutting
##     zone. Patch creation is therefore restricted to FORAGE zones.
##   * BASIN BINDING IS NOT DERIVED FROM GEOMETRY. §5.1 says intersecting zones share the basin,
##     but no store owns a tile -> basin mask (WorldTileMaps has building_slot, room_slot,
##     zone_link_head and resource_slot, and no basin column), and registering both shipping-map
##     forest basins tile by tile would consume most of the 16384 link budget. set_basin() is
##     therefore explicit and zones_intersect() is exposed so the eventual designation command
##     can require the intersection §5.1 describes.
##   * `item_id`'s DOMAIN IS SETTLED: THE COMPILED `ItemDefinition` ID. §4.2 types it int32 and
##     never says which catalog; READY_07 §2 (2026-09-11) rules that it is the same domain as
##     `ResourceNode.resource_id` -- the compiled `ItemDefinition` id of what the patch yields.
##     PATCH_KEYS holds §5.5's five item keys in PATCH ROW order and
##     `scripts/core/resource_catalog_binding.gd` reads THIS array to resolve them, so the ids it
##     produces are in patch-kind order by construction. Sorting them by compiled id would
##     associate the wrong capacity, work cost and regrowth rate with every row, which is why
##     `create_patch_set()` is addressed by kind and never by id. This store still validates the
##     range only: an int32 column cannot prove a catalog, and decision 0052 records who does.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Rng := preload("res://scripts/core/rng.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")

# --- capacities (GDD §4.2, systems_architecture.md §2.2, entity_directory.gd) ---------------------

## GDD §4.2: "Up to 128".
const HARVEST_ZONE_CAPACITY: int = 128
## GDD §4.2: "tile membership max 16384 total zone links".
const ZONE_LINK_CAPACITY: int = 16384
## GDD §4.2: "5 patches/forest zone".
const PATCHES_PER_ZONE: int = 5
## systems_architecture.md §2.2 ForagePatch length: 640 == 128 * 5.
const FORAGE_PATCH_CAPACITY: int = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE
## decision 0030 §4.7: `claim_row = owning_job_typed_row` inside the existing 8192 Job rows.
## `_init()` asserts this equals the directory's own KIND_JOB capacity rather than restating it.
const FORAGE_CLAIM_CAPACITY: int = 8192

## GDD §5.1 exterior grid: index `z*128+x`, 16384 tiles, matching WorldTileMaps' row count.
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z

# --- GDD §4.3 ZoneType, read from catalog.gd's protected table (decision 0018) --------------------

const ZONE_TYPE_FISH: int = Catalog.ZONE_TYPE["FISH"]
## SET-AMEND-001 §3: the retired hunting zone. Creation is rejected, the value is never reused.
const ZONE_TYPE_RESERVED_1: int = Catalog.ZONE_TYPE["RESERVED_1"]
const ZONE_TYPE_FORAGE: int = Catalog.ZONE_TYPE["FORAGE"]
const ZONE_TYPE_FARM: int = Catalog.ZONE_TYPE["FARM"]
const ZONE_TYPE_ORCHARD: int = Catalog.ZONE_TYPE["ORCHARD"]
const ZONE_TYPE_FORESTRY: int = Catalog.ZONE_TYPE["FORESTRY"]
const ZONE_TYPE_QUARRY: int = Catalog.ZONE_TYPE["QUARRY"]
const ZONE_TYPE_STOCKPILE: int = Catalog.ZONE_TYPE["STOCKPILE"]
const ZONE_TYPE_CONSERVATION: int = Catalog.ZONE_TYPE["CONSERVATION"]
const ZONE_TYPE_COUNT: int = 9

# --- GDD §4.3 Season, likewise from the protected table ------------------------------------------

const SEASON_SPRING: int = Catalog.SEASON["SPRING"]
const SEASON_SUMMER: int = Catalog.SEASON["SUMMER"]
const SEASON_AUTUMN: int = Catalog.SEASON["AUTUMN"]
const SEASON_WINTER: int = Catalog.SEASON["WINTER"]
const SEASON_COUNT: int = 4

# --- GDD §5.5 forage table, row for row ----------------------------------------------------------

const PATCH_BERRIES: int = 0
const PATCH_NUTS: int = 1
const PATCH_MUSHROOMS: int = 2
const PATCH_HERB: int = 3
const PATCH_ROOTS: int = 4

## §5.5's five "Forage item" rows in the document's own order, which IS patch-kind order. Item ids
## are compiled elsewhere: `resource_catalog_binding.gd` resolves this array against the catalog
## and must preserve its order, so these keys are never re-typed or re-sorted anywhere else.
const PATCH_KEYS: Array[StringName] = [&"berries", &"nuts", &"mushrooms", &"herb", &"roots"]

## §5.5 "Patch capacity U" column, whole units.
const PATCH_CAPACITY_U: Array[int] = [300, 240, 180, 160, 300]
## §5.5 "Base work WU/U" column.
const PATCH_BASE_WORK_WU: Array[int] = [4, 5, 5, 8, 6]
## §5.5 "Daily regrowth fraction/1000" column, the `r` of the regrowth formula.
const PATCH_REGROWTH_PER_1000: Array[int] = [120, 60, 100, 80, 70]
## §5.5's Spring/Summer/Autumn/Winter availability columns, flattened as `kind*4 + season`.
## Zeroes are §5.5's dormant seasons: "unavailable patches become dormant, not destroyed".
const PATCH_AVAILABILITY_PER_1000: Array[int] = [
	0, 1000, 400, 0,
	0, 200, 1200, 300,
	500, 300, 1200, 0,
	1000, 1200, 600, 200,
	800, 1000, 1200, 400,
]

## AGENTS.md: "Quantities are quantity_milli:int64 (1000 = one unit)."
const MILLI_PER_UNIT: int = 1000

## GDD §5.1: "forage stocks are floor(0.8xcapacity), including dormant stocks."
const INITIAL_STOCK_NUMERATOR: int = 8
const INITIAL_STOCK_DENOMINATOR: int = 10

## §5.5: "Sustainable floor 20%K; intensive floor 5%K."
const SUSTAINABLE_FLOOR_PERCENT: int = 20
const INTENSIVE_FLOOR_PERCENT: int = 5
const PERCENT_DENOMINATOR: int = 100

## §5.5: "Daily regrowth=floor((K-P)*r*season/1000000) plus a minimum 1 U when season>0 and P<K."
## Ruling §8A reads "plus" as ADDITIVE and caps the sum at the room left below K (see the header).
const REGROWTH_DENOMINATOR: int = 1000000
const REGROWTH_MINIMUM_MILLI: int = MILLI_PER_UNIT

## §5.5: "Work per U=ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))".
const WORK_NUMERATOR_SCALE: int = 1000000
const WORK_BASE_TERM: int = 1000
const WORK_SKILL_TERM: int = 40
const WORK_DANGER_TERM: int = 100

## §5.5: "Danger zones:0 inside 32 m of any staffed lookout;1 remaining land within 64 m of the
## central hall;2 at 64-96 m;3 beyond 96 m."
const DANGER_MIN: int = 0
const DANGER_MAX: int = 3
## REQ-SET-067: "While a forage zone has danger 2 or 3".
const DANGEROUS_WORK_DANGER: int = 2
## ARCH-RNG-002: rolls happen only "in natural danger>=1".
const INJURY_ROLL_MIN_DANGER: int = 1

## REQ-SET-068: "When a forager completes 60 WU in danger>=1, the system shall roll injury chance
## `max(1,8*danger-FORAGE_level)` per 10000, causing 10 health loss and severity 1 injury".
const EXPOSURE_SEGMENT_WU: int = 60
const INJURY_ROLL_DENOMINATOR: int = 10000
const INJURY_DANGER_FACTOR: int = 8
const INJURY_CHANCE_MINIMUM: int = 1
const INJURY_HEALTH_LOSS: int = 10
const INJURY_SEVERITY: int = 1

# --- decision 0030 §4.6 quota modes, compiled through catalog.gd's own mechanism ------------------

## The domain name compile_domain() is called with in `_init()`. NOT a PROTECTED_ENUM_DOMAIN:
## GDD §4.3 numbers no quota mode, so there is nothing specified here to protect (see the header).
const QUOTA_MODE_DOMAIN: String = "ForageQuotaMode"
## catalog.gd assigns ids in ascending ASCII order, so these three keys compile to 0, 1, 2 in
## exactly this order. `_init()` runs the compiler and asserts that, so no second numbering
## scheme exists and none can drift.
const QUOTA_MODE_KEYS: Array[StringName] = [&"automatic", &"inherit", &"manual"]
## Ruling §4.6: Automatic is a BASIN mode, Inherit is a DESIGNATION mode, Manual is either.
const QUOTA_MODE_AUTOMATIC: int = 0
const QUOTA_MODE_INHERIT: int = 1
const QUOTA_MODE_MANUAL: int = 2
const QUOTA_MODE_COUNT: int = 3

## Ruling §4.6: "This policy uses an 80% stock management target", as `floor(800 * K / 1000)`.
const AUTOMATIC_TARGET_PER_1000: int = 800
const AUTOMATIC_TARGET_DENOMINATOR: int = 1000
## `floor((K - target) * r * S / 1000000) + 1000`, the existing additive 1 U regrowth term.
const AUTOMATIC_ALLOWANCE_DENOMINATOR: int = 1000000
const AUTOMATIC_ALLOWANCE_TERM_MILLI: int = MILLI_PER_UNIT

## Ruling §4.6: "Minimum is zero: no unlimited sentinel is supported. Maximum is `sum(K_i)` across
## the basin's five patches: currently 1180000 milli-U/day." `_init()` asserts the sum.
const MANUAL_QUOTA_MIN_MILLI: int = 0
const MANUAL_QUOTA_MAX_MILLI: int = 1180000

# --- packed payload accounting (ruling §4.7 / R05-QUOTA-024) --------------------------------------

const BYTES_PER_BYTE_COLUMN: int = 1
const BYTES_PER_INT32: int = 4
const BYTES_PER_INT64: int = 8

## Empty value of `WorldTileMaps.zone_link_head` and of every link cursor.
const NO_LINK: int = -1
## Empty value of every claim cursor and of "no claim row selected".
const NO_CLAIM: int = -1
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_ZONE_NOT_PRESENT: StringName = &"ZONE_NOT_PRESENT"
const REFUSE_INVALID_ZONE_TYPE: StringName = &"INVALID_ZONE_TYPE"
const REFUSE_RESERVED_ZONE_TYPE: StringName = &"RESERVED_ZONE_TYPE"
const REFUSE_ZONE_TYPE_MISMATCH: StringName = &"ZONE_TYPE_MISMATCH"
const REFUSE_INVALID_DANGER: StringName = &"INVALID_DANGER"
const REFUSE_INVALID_QUOTA: StringName = &"INVALID_QUOTA"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_TILE_COORDINATE: StringName = &"INVALID_TILE_COORDINATE"
const REFUSE_TILE_ALREADY_LINKED: StringName = &"TILE_ALREADY_LINKED"
const REFUSE_TILE_NOT_LINKED: StringName = &"TILE_NOT_LINKED"
const REFUSE_ZONE_LINK_CAPACITY: StringName = &"CAPACITY_ZONE_LINK"
const REFUSE_INVALID_PATCH_KIND: StringName = &"INVALID_PATCH_KIND"
const REFUSE_INVALID_ITEM_ID: StringName = &"INVALID_ITEM_ID"
const REFUSE_PATCH_PRESENT: StringName = &"PATCH_ALREADY_PRESENT"
const REFUSE_PATCH_NOT_PRESENT: StringName = &"PATCH_NOT_PRESENT"
const REFUSE_STOCK_ABOVE_CAPACITY: StringName = &"STOCK_ABOVE_CAPACITY"
const REFUSE_PATCH_SET_SIZE: StringName = &"PATCH_SET_SIZE"
const REFUSE_PATCH_DORMANT: StringName = &"PATCH_DORMANT"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_BELOW_HARVEST_FLOOR: StringName = &"BELOW_HARVEST_FLOOR"
const REFUSE_QUOTA_REACHED: StringName = &"QUOTA_REACHED"
const REFUSE_ZONE_DISABLED: StringName = &"ZONE_DISABLED"
const REFUSE_ZONE_PROTECTED: StringName = &"ZONE_PROTECTED"
const REFUSE_DANGEROUS_WORK_REFUSED: StringName = &"DANGEROUS_WORK_REFUSED"
const REFUSE_BASIN_CHAIN: StringName = &"BASIN_CHAIN"
const REFUSE_BASIN_HAS_OWN_PATCHES: StringName = &"BASIN_HAS_OWN_PATCHES"
const REFUSE_ZONE_IS_BOUND: StringName = &"ZONE_IS_BOUND"
const REFUSE_INVALID_SKILL_LEVEL: StringName = &"INVALID_SKILL_LEVEL"
const REFUSE_INVALID_WORK: StringName = &"INVALID_WORK"
const REFUSE_NO_RNG: StringName = &"NO_RNG"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_INVALID_QUOTA_MODE: StringName = &"INVALID_QUOTA_MODE"
const REFUSE_QUOTA_MODE_NOT_VALID_HERE: StringName = &"QUOTA_MODE_NOT_VALID_HERE"
const REFUSE_NO_JOB_STORE: StringName = &"NO_JOB_STORE"
const REFUSE_JOB_NOT_PRESENT: StringName = &"JOB_NOT_PRESENT"
const REFUSE_JOB_IS_MEMBER: StringName = &"JOB_IS_MEMBER"
const REFUSE_CLAIM_PRESENT: StringName = &"CLAIM_ALREADY_PRESENT"
const REFUSE_CLAIM_NOT_PRESENT: StringName = &"CLAIM_NOT_PRESENT"
const REFUSE_CLAIM_STALE_JOB: StringName = &"CLAIM_STALE_JOB"
const REFUSE_STOCK_RESERVED: StringName = &"STOCK_RESERVED"
const REFUSE_NOT_DAY_BOUNDARY: StringName = &"NOT_DAY_BOUNDARY"
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"


class OpResult:
	"""Outcome of one forage operation: success flag, refusal code, value and reference.

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


# --- collaborators -------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false
## The Job store every claim is owned by. Optional: a store built without one holds no claims and
## refuses every claim operation with REFUSE_NO_JOB_STORE rather than inventing an owner.
var _jobs: JobsScript = null

# --- HarvestZone columns (ARCH-MEM-001: packed, allocated once) -----------------------------------

var _zone_present: PackedByteArray = PackedByteArray()
var _zone_type: PackedInt32Array = PackedInt32Array()
var _zone_danger: PackedInt32Array = PackedInt32Array()
var _zone_quota_milli: PackedInt64Array = PackedInt64Array()
var _zone_protected: PackedByteArray = PackedByteArray()
var _zone_enabled: PackedByteArray = PackedByteArray()

## The directory reference owning each zone row, so a row can hand back a validatable ref.
var _zone_ref_slot: PackedInt32Array = PackedInt32Array()
var _zone_ref_generation: PackedInt32Array = PackedInt32Array()

## GDD §5.1's "Player harvest zones reference basin IDs". A new zone is its own basin.
var _zone_basin_slot: PackedInt32Array = PackedInt32Array()
var _zone_basin_generation: PackedInt32Array = PackedInt32Array()

## decision 0030 §4.7. `harvested_today_milli` and `quota_mode` are AUTHORITATIVE state;
## `quota_reserved_milli` is a DERIVED CACHE, maintained atomically and rebuilt from active claims
## by rebuild_reservation_aggregates().
var _zone_harvested_today_milli: PackedInt64Array = PackedInt64Array()
var _zone_quota_reserved_milli: PackedInt64Array = PackedInt64Array()
var _zone_quota_mode: PackedByteArray = PackedByteArray()

## Head of each zone's own tile-link list, and the length of that list.
var _zone_link_head: PackedInt32Array = PackedInt32Array()
var _zone_tile_count: PackedInt32Array = PackedInt32Array()
## Number of live ForagePatch rows in this zone's five-row block.
var _zone_patch_count: PackedInt32Array = PackedInt32Array()

## Ascending list of live zone rows, so a daily sweep iterates zones and not all 128 slots.
var _live_zone_slots: PackedInt32Array = PackedInt32Array()
var _live_zone_count: int = 0

# --- HarvestZone.tiles: the 16384-link arena, threaded into two lists per link --------------------

var _link_tile: PackedInt32Array = PackedInt32Array()
var _link_zone: PackedInt32Array = PackedInt32Array()
var _link_tile_next: PackedInt32Array = PackedInt32Array()
var _link_zone_next: PackedInt32Array = PackedInt32Array()

## `WorldTileMaps.zone_link_head` (systems_architecture.md §2): one int32 per exterior tile.
## A tile carries a LIST, not a slot, because §5.1's overlapping zones must all reach it.
var _tile_link_head: PackedInt32Array = PackedInt32Array()

## Bump allocator plus free list: `_link_bump` links have ever been handed out, and released
## links are recycled through `_link_free_head`. Neither ever resizes a column.
var _link_bump: int = 0
var _link_free_head: int = NO_LINK
var _link_used: int = 0

# --- ForagePatch columns, owner-major at `zone_slot * 5 + kind` -----------------------------------

var _patch_present: PackedByteArray = PackedByteArray()
var _patch_item_id: PackedInt32Array = PackedInt32Array()
var _patch_zone_slot: PackedInt32Array = PackedInt32Array()
var _patch_zone_generation: PackedInt32Array = PackedInt32Array()
var _patch_stock_milli: PackedInt64Array = PackedInt64Array()
var _patch_capacity_milli: PackedInt64Array = PackedInt64Array()
var _patch_harvested_year_milli: PackedInt64Array = PackedInt64Array()

# --- ForageClaim columns, indexed by OWNING JOB TYPED ROW (decision 0030 §4.7) ---------------------

var _claim_active: PackedByteArray = PackedByteArray()
var _claim_job_slot: PackedInt32Array = PackedInt32Array()
var _claim_job_generation: PackedInt32Array = PackedInt32Array()
var _claim_designation_slot: PackedInt32Array = PackedInt32Array()
var _claim_designation_generation: PackedInt32Array = PackedInt32Array()
var _claim_basin_slot: PackedInt32Array = PackedInt32Array()
var _claim_basin_generation: PackedInt32Array = PackedInt32Array()
var _claim_patch_kind: PackedInt32Array = PackedInt32Array()
var _claim_remaining_milli: PackedInt64Array = PackedInt64Array()

## The §4.5 release order key, cached from the owning Job at claim time. EXTRA to the ruling's
## 305280-byte payload and counted separately -- see the header and extra_ordering_buffer_bytes().
var _claim_created_tick: PackedInt64Array = PackedInt64Array()
var _claim_persistent_id: PackedInt64Array = PackedInt64Array()

## Live claim total. A scalar counter, not an index: no per-claim list is allocated.
var _claim_count: int = 0

# --- scratch (not simulation state) ---------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()
## A second scratch for the two places that need a live value while computing another.
var _math_b: IntMath.IntResult = IntMath.IntResult.new()
## A third scratch, owned exclusively by the quota/claim paths so they can nest inside a caller
## that is already holding `_math` or `_math_b`.
var _math_c: IntMath.IntResult = IntMath.IntResult.new()

## Rows resolved by the last claim preflight, consumed by the commit that immediately follows it.
## Plain ints, written and read inside one public call with no callback in between.
var _pending_designation_slot: int = EntityDirectory.NULL_SLOT
var _pending_basin_slot: int = EntityDirectory.NULL_SLOT
var _pending_patch_row: int = -1


func _init(p_directory: EntityDirectory = null, p_jobs: JobsScript = null) -> void:
	"""Allocate every column once and adopt or build the directory behind every zone reference.

	A Job store may be supplied so this store can own forage claims; when it is, its directory is
	adopted, because a claim validates its owning Job reference through exactly one directory.
	"""
	assert(HARVEST_ZONE_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_HARVEST_ZONE],
		"harvest-zone columns must match the directory's HARVEST_ZONE row capacity")
	assert(FORAGE_CLAIM_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_JOB],
		"claim rows are Job rows: decision 0030 indexes them by owning Job typed row")
	_assert_forage_table()
	_assert_quota_contracts()
	_jobs = p_jobs
	var adopted: EntityDirectory = p_directory
	if adopted == null and _jobs != null:
		adopted = _jobs.directory()
	assert(_jobs == null or adopted == _jobs.directory(),
		"a forage store and its Job store must validate references through one directory")
	_owns_directory = adopted == null
	_directory = adopted if adopted != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _assert_forage_table() -> void:
	"""Every §5.5 column carries exactly one entry per forage row."""
	assert(PATCH_KEYS.size() == PATCHES_PER_ZONE, "GDD §5.5 lists exactly five forage items")
	assert(PATCH_CAPACITY_U.size() == PATCHES_PER_ZONE, "one capacity per §5.5 forage row")
	assert(PATCH_BASE_WORK_WU.size() == PATCHES_PER_ZONE, "one base work per §5.5 forage row")
	assert(PATCH_REGROWTH_PER_1000.size() == PATCHES_PER_ZONE, "one r per §5.5 forage row")
	assert(PATCH_AVAILABILITY_PER_1000.size() == PATCHES_PER_ZONE * SEASON_COUNT,
		"§5.5 gives four seasonal availabilities for each of the five forage rows")


func _assert_quota_contracts() -> void:
	"""Recompile the quota-mode ids through catalog.gd and re-derive the manual ceiling.

	Neither number is restated independently: the mode ids come back out of the same
	ascending-ASCII compiler every other domain uses, and 1180000 is `sum(K_i)` over §5.5's own
	capacity column, so a table edit breaks construction instead of silently shifting a policy.
	"""
	var compiled: Catalog.DomainResult = Catalog.compile_domain(QUOTA_MODE_DOMAIN, QUOTA_MODE_KEYS)
	assert(compiled.ok, "the quota-mode domain must compile through catalog.gd")
	assert(compiled.ids[&"automatic"] == QUOTA_MODE_AUTOMATIC
			and compiled.ids[&"inherit"] == QUOTA_MODE_INHERIT
			and compiled.ids[&"manual"] == QUOTA_MODE_MANUAL,
		"quota-mode ids must be catalog.gd's ascending-ASCII ids, not a second numbering")
	assert(QUOTA_MODE_KEYS.size() == QUOTA_MODE_COUNT, "three modes: automatic, inherit, manual")
	var capacity_sum: int = 0
	for kind: int in PATCHES_PER_ZONE:
		capacity_sum += PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
	assert(capacity_sum == MANUAL_QUOTA_MAX_MILLI,
		"the manual ceiling is sum(K_i) over §5.5's capacity column")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_allocate_zone_columns()
	_allocate_link_columns()
	_allocate_patch_columns()
	_allocate_claim_columns()


func _allocate_claim_columns() -> void:
	"""Size the eleven ForageClaim columns at one row per Job row (decision 0030 §4.7)."""
	_claim_active.resize(FORAGE_CLAIM_CAPACITY)
	_claim_job_slot.resize(FORAGE_CLAIM_CAPACITY)
	_claim_job_generation.resize(FORAGE_CLAIM_CAPACITY)
	_claim_designation_slot.resize(FORAGE_CLAIM_CAPACITY)
	_claim_designation_generation.resize(FORAGE_CLAIM_CAPACITY)
	_claim_basin_slot.resize(FORAGE_CLAIM_CAPACITY)
	_claim_basin_generation.resize(FORAGE_CLAIM_CAPACITY)
	_claim_patch_kind.resize(FORAGE_CLAIM_CAPACITY)
	_claim_remaining_milli.resize(FORAGE_CLAIM_CAPACITY)
	_claim_created_tick.resize(FORAGE_CLAIM_CAPACITY)
	_claim_persistent_id.resize(FORAGE_CLAIM_CAPACITY)


func _allocate_zone_columns() -> void:
	"""Size the fifteen HarvestZone columns and the live-zone index at 128 rows."""
	_zone_present.resize(HARVEST_ZONE_CAPACITY)
	_zone_type.resize(HARVEST_ZONE_CAPACITY)
	_zone_danger.resize(HARVEST_ZONE_CAPACITY)
	_zone_quota_milli.resize(HARVEST_ZONE_CAPACITY)
	_zone_protected.resize(HARVEST_ZONE_CAPACITY)
	_zone_enabled.resize(HARVEST_ZONE_CAPACITY)
	_zone_ref_slot.resize(HARVEST_ZONE_CAPACITY)
	_zone_ref_generation.resize(HARVEST_ZONE_CAPACITY)
	_zone_basin_slot.resize(HARVEST_ZONE_CAPACITY)
	_zone_basin_generation.resize(HARVEST_ZONE_CAPACITY)
	_zone_harvested_today_milli.resize(HARVEST_ZONE_CAPACITY)
	_zone_quota_reserved_milli.resize(HARVEST_ZONE_CAPACITY)
	_zone_quota_mode.resize(HARVEST_ZONE_CAPACITY)
	_zone_link_head.resize(HARVEST_ZONE_CAPACITY)
	_zone_tile_count.resize(HARVEST_ZONE_CAPACITY)
	_zone_patch_count.resize(HARVEST_ZONE_CAPACITY)
	_live_zone_slots.resize(HARVEST_ZONE_CAPACITY)


func _allocate_link_columns() -> void:
	"""Size the 16384-entry link arena and the per-tile head column."""
	_link_tile.resize(ZONE_LINK_CAPACITY)
	_link_zone.resize(ZONE_LINK_CAPACITY)
	_link_tile_next.resize(ZONE_LINK_CAPACITY)
	_link_zone_next.resize(ZONE_LINK_CAPACITY)
	_tile_link_head.resize(TILE_COUNT)


func _allocate_patch_columns() -> void:
	"""Size the seven ForagePatch columns at 640 rows (128 zones x 5 patches)."""
	_patch_present.resize(FORAGE_PATCH_CAPACITY)
	_patch_item_id.resize(FORAGE_PATCH_CAPACITY)
	_patch_zone_slot.resize(FORAGE_PATCH_CAPACITY)
	_patch_zone_generation.resize(FORAGE_PATCH_CAPACITY)
	_patch_stock_milli.resize(FORAGE_PATCH_CAPACITY)
	_patch_capacity_milli.resize(FORAGE_PATCH_CAPACITY)
	_patch_harvested_year_milli.resize(FORAGE_PATCH_CAPACITY)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live zone's directory slot is released first, so dropping this store cannot strand
	allocated slots in a directory it does not own.
	"""
	_release_live_zones()
	_clear_zone_columns()
	_clear_link_columns()
	_clear_patch_columns()
	_clear_claim_columns()
	if _owns_directory:
		_directory.clear()


func _clear_claim_columns() -> void:
	"""Refill every ForageClaim column with its empty value and drop the live count."""
	_claim_active.fill(0)
	_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_designation_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_designation_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_basin_slot.fill(EntityDirectory.NULL_SLOT)
	_claim_basin_generation.fill(EntityDirectory.NULL_GENERATION)
	_claim_patch_kind.fill(-1)
	_claim_remaining_milli.fill(0)
	_claim_created_tick.fill(0)
	_claim_persistent_id.fill(0)
	_claim_count = 0


func _release_live_zones() -> void:
	"""Destroy the directory slot of every live zone, so a clear leaks no allocation."""
	for index: int in _live_zone_count:
		var slot: int = _live_zone_slots[index]
		if slot < 0 or slot >= HARVEST_ZONE_CAPACITY or _zone_present[slot] != 1:
			continue
		_directory.destroy(Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot]))


func _clear_zone_columns() -> void:
	"""Refill every HarvestZone column with its empty value."""
	_zone_present.fill(0)
	_zone_type.fill(0)
	_zone_danger.fill(0)
	_zone_quota_milli.fill(0)
	_zone_protected.fill(0)
	_zone_enabled.fill(0)
	_zone_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_zone_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_zone_basin_slot.fill(EntityDirectory.NULL_SLOT)
	_zone_basin_generation.fill(EntityDirectory.NULL_GENERATION)
	_zone_harvested_today_milli.fill(0)
	_zone_quota_reserved_milli.fill(0)
	_zone_quota_mode.fill(QUOTA_MODE_AUTOMATIC)
	_zone_link_head.fill(NO_LINK)
	_zone_tile_count.fill(0)
	_zone_patch_count.fill(0)
	_live_zone_slots.fill(EntityDirectory.NULL_SLOT)
	_live_zone_count = 0


func _clear_link_columns() -> void:
	"""Empty the link arena. The bump allocator makes this O(columns), not O(16384) writes."""
	_link_tile.fill(NO_LINK)
	_link_zone.fill(EntityDirectory.NULL_SLOT)
	_link_tile_next.fill(NO_LINK)
	_link_zone_next.fill(NO_LINK)
	_tile_link_head.fill(NO_LINK)
	_link_bump = 0
	_link_free_head = NO_LINK
	_link_used = 0


func _clear_patch_columns() -> void:
	"""Refill every ForagePatch column with its empty value."""
	_patch_present.fill(0)
	_patch_item_id.fill(-1)
	_patch_zone_slot.fill(EntityDirectory.NULL_SLOT)
	_patch_zone_generation.fill(EntityDirectory.NULL_GENERATION)
	_patch_stock_milli.fill(0)
	_patch_capacity_milli.fill(0)
	_patch_harvested_year_milli.fill(0)


func directory() -> EntityDirectory:
	"""The allocator behind every harvest-zone reference."""
	return _directory


func jobs() -> JobsScript:
	"""The Job store every forage claim is owned by, or null when this store holds no claims."""
	return _jobs


# --- GDD §5.1 exterior tile geometry ---------------------------------------------------------------

func is_tile_index(tile: int) -> bool:
	"""True when `tile` addresses one of the 16384 exterior tiles."""
	return tile >= 0 and tile < TILE_COUNT


func tile_index(x: int, z: int) -> IntMath.IntResult:
	"""GDD §5.1 exterior tile index `z*128+x`, or an explicit refusal off the 128x128 grid."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	tile_index_into(x, z, out)
	return out


func tile_index_into(x: int, z: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating tile_index(): write `z*128+x` into caller-owned `out`, return out.ok."""
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return out.refuse(String(REFUSE_INVALID_TILE_COORDINATE))
	return out.succeed(z * MAP_TILES_X + x)


# --- zone lifecycle ---------------------------------------------------------------------------------

func create_zone(zone_type: int, danger: int, quota_milli: int, is_protected: bool,
		is_enabled: bool) -> OpResult:
	"""Designate one HarvestZone with no tiles and no patches, owning itself as its basin.

	REQ-SET-060 and SET-AMEND-001 §3: a RESERVED_1 zone is refused "before allocating a job or
	changing the world", so the type is checked before the directory is touched. Refuses -- and
	allocates nothing -- on an unknown type, a danger outside §5.5's 0..3 bands, or a negative
	quota.
	"""
	var code: StringName = _refuse_create_zone(zone_type, danger, quota_milli)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_HARVEST_ZONE)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_zone(slot, ref, zone_type, danger, quota_milli, is_protected, is_enabled)
	return _succeed(slot, ref)


func _refuse_create_zone(zone_type: int, danger: int, quota_milli: int) -> StringName:
	"""The code blocking a zone creation, or REFUSE_NONE when every argument is storable."""
	if zone_type == ZONE_TYPE_RESERVED_1:
		return REFUSE_RESERVED_ZONE_TYPE
	if zone_type < 0 or zone_type >= ZONE_TYPE_COUNT:
		return REFUSE_INVALID_ZONE_TYPE
	if danger < DANGER_MIN or danger > DANGER_MAX:
		return REFUSE_INVALID_DANGER
	if quota_milli < 0:
		return REFUSE_INVALID_QUOTA
	return REFUSE_NONE


func _write_created_zone(slot: int, ref: Vector2i, zone_type: int, danger: int, quota_milli: int,
		is_protected: bool, is_enabled: bool) -> void:
	"""Write every §4.2 column of a freshly designated zone and make it its own basin.

	R05-QUOTA-017: a created zone owns itself, so it is a basin, and a basin defaults to
	Automatic. Its stored `quota_milli` is §4.2's own column and takes effect only once
	set_quota_milli() puts the zone in Manual mode.
	"""
	_zone_present[slot] = 1
	_zone_harvested_today_milli[slot] = 0
	_zone_quota_reserved_milli[slot] = 0
	_zone_quota_mode[slot] = QUOTA_MODE_AUTOMATIC
	_zone_type[slot] = zone_type
	_zone_danger[slot] = danger
	_zone_quota_milli[slot] = quota_milli
	_zone_protected[slot] = 1 if is_protected else 0
	_zone_enabled[slot] = 1 if is_enabled else 0
	_zone_ref_slot[slot] = ref.x
	_zone_ref_generation[slot] = ref.y
	_zone_basin_slot[slot] = ref.x
	_zone_basin_generation[slot] = ref.y
	_zone_link_head[slot] = NO_LINK
	_zone_tile_count[slot] = 0
	_zone_patch_count[slot] = 0
	_insert_live_zone(slot)


func destroy_zone(ref: Vector2i) -> OpResult:
	"""Remove one zone, release every tile link and patch it owns, and free its directory slot.

	Returns the number of tile links released. Refuses a stale or wrong-kind reference rather
	than clearing whatever row it points at, which is what makes a reused slot safe.

	Ruling §4.5: deleting a designation "releases its outstanding claims first" and does not reset
	the basin's usage. Only THIS row's daily totals are cleared; the basin it drew from keeps its
	collected total, its own claims and its annual patch counters.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	_release_claims_of_zone_slot(slot)
	var released: int = _release_zone_links(slot)
	_release_zone_patches(slot)
	_zone_harvested_today_milli[slot] = 0
	_zone_quota_reserved_milli[slot] = 0
	_zone_quota_mode[slot] = QUOTA_MODE_AUTOMATIC
	_zone_present[slot] = 0
	_zone_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_zone_basin_slot[slot] = EntityDirectory.NULL_SLOT
	_zone_basin_generation[slot] = EntityDirectory.NULL_GENERATION
	_remove_live_zone(slot)
	_directory.destroy(ref)
	return _succeed(released, NULL_REF)


func _release_zone_links(zone_slot: int) -> int:
	"""Unlink and recycle every tile link of a zone. Returns how many were released."""
	var released: int = 0
	var link: int = _zone_link_head[zone_slot]
	while link != NO_LINK:
		var next_link: int = _link_zone_next[link]
		_unlink_from_tile(_link_tile[link], link)
		_free_link(link)
		released += 1
		link = next_link
	_zone_link_head[zone_slot] = NO_LINK
	_zone_tile_count[zone_slot] = 0
	return released


func _release_zone_patches(zone_slot: int) -> void:
	"""Empty the five-row ForagePatch block a destroyed zone owns."""
	var base: int = zone_slot * PATCHES_PER_ZONE
	for kind: int in PATCHES_PER_ZONE:
		var row: int = base + kind
		_patch_present[row] = 0
		_patch_item_id[row] = -1
		_patch_zone_slot[row] = EntityDirectory.NULL_SLOT
		_patch_zone_generation[row] = EntityDirectory.NULL_GENERATION
		_patch_stock_milli[row] = 0
		_patch_capacity_milli[row] = 0
		_patch_harvested_year_milli[row] = 0
	_zone_patch_count[zone_slot] = 0


func _insert_live_zone(slot: int) -> void:
	"""Insert a created zone into the ascending live list, keeping iteration order stable."""
	var index: int = _live_zone_count
	while index > 0 and _live_zone_slots[index - 1] > slot:
		_live_zone_slots[index] = _live_zone_slots[index - 1]
		index -= 1
	_live_zone_slots[index] = slot
	_live_zone_count += 1


func _remove_live_zone(slot: int) -> void:
	"""Remove a zone from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_zone_count and _live_zone_slots[index] != slot:
		index += 1
	if index >= _live_zone_count:
		return
	while index + 1 < _live_zone_count:
		_live_zone_slots[index] = _live_zone_slots[index + 1]
		index += 1
	_live_zone_count -= 1
	_live_zone_slots[_live_zone_count] = EntityDirectory.NULL_SLOT


# --- zone readers -------------------------------------------------------------------------------------

func is_zone_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a designated harvest zone."""
	return slot >= 0 and slot < HARVEST_ZONE_CAPACITY and _zone_present[slot] == 1


func zone_count() -> int:
	"""Number of live harvest zones."""
	return _live_zone_count


func live_zone_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live zone in ascending slot order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _live_zone_count:
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_live_zone_slots[index])
	return out


func zone_ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a zone row, or the §4.1 null reference `(-1, 0)`."""
	if not is_zone_present(slot):
		return NULL_REF
	return Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot])


func zone_slot_of(ref: Vector2i) -> IntMath.IntResult:
	"""The row a live harvest-zone reference addresses, or an explicit refusal when it is stale."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	zone_slot_of_into(ref, out)
	return out


func zone_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating zone_slot_of(): write the validated row into caller-owned `out`."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	var slot: int = _directory.get_typed_row(ref)
	if not is_zone_present(slot):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	return out.succeed(slot)


func zone_type_of(slot: int) -> IntMath.IntResult:
	"""The zone's §4.3 ZoneType, or an explicit refusal."""
	return _read_zone(slot, _zone_type)


func zone_danger_of(slot: int) -> IntMath.IntResult:
	"""The zone's own §5.5 danger band, 0..3 -- the hazard danger REQ-SET-067 gates on."""
	return _read_zone(slot, _zone_danger)


func zone_quota_milli_of(slot: int) -> IntMath.IntResult:
	"""The zone's stored §4.2 `quota_milli`: the MANUAL daily value, in milli-U per calendar day.

	It is the effective limit only while the zone's quota mode is Manual; daily_quota_milli_of()
	is the reader that resolves Automatic and Inherit as well.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_zone_quota_milli[slot])
	return out


func is_zone_protected(slot: int) -> bool:
	"""True when §5.5's "Protected tiles are never automatically harvested" applies to this zone."""
	return is_zone_present(slot) and _zone_protected[slot] == 1


func is_zone_enabled(slot: int) -> bool:
	"""True when the zone's §4.2 `enabled` flag is set."""
	return is_zone_present(slot) and _zone_enabled[slot] == 1


func set_zone_enabled(ref: Vector2i, is_enabled: bool) -> OpResult:
	"""Set the zone's `enabled` flag. Refuses a stale reference rather than writing a dead row."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	_zone_enabled[_math.value] = 1 if is_enabled else 0
	return _succeed(_math.value, ref)


func set_zone_protected(ref: Vector2i, is_protected: bool) -> OpResult:
	"""Set the zone's `protected` flag. Refuses a stale reference rather than writing a dead row."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	_zone_protected[_math.value] = 1 if is_protected else 0
	return _succeed(_math.value, ref)


func _read_zone(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 zone column of a live row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


# --- HarvestZone.tiles: membership links ------------------------------------------------------------

func add_tile(ref: Vector2i, tile: int) -> OpResult:
	"""Link one exterior tile into a zone. Returns the zone's tile count after the link.

	Refuses at GDD §4.2's 16384 total-link ceiling, off the grid, and on a tile this zone already
	covers -- a duplicate link would spend the shared budget on nothing. A tile covered by
	ANOTHER zone is accepted: §5.1's overlapping designations are the case the per-tile list
	exists for, and sharing is settled by the basin reference, not by refusing the overlap.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if not is_tile_index(tile):
		return _refuse(REFUSE_INVALID_TILE)
	if _find_link(slot, tile) != NO_LINK:
		return _refuse(REFUSE_TILE_ALREADY_LINKED)
	if _link_used >= ZONE_LINK_CAPACITY:
		return _refuse(REFUSE_ZONE_LINK_CAPACITY)
	var link: int = _take_link()
	_link_tile[link] = tile
	_link_zone[link] = slot
	_link_tile_next[link] = _tile_link_head[tile]
	_tile_link_head[tile] = link
	_link_zone_next[link] = _zone_link_head[slot]
	_zone_link_head[slot] = link
	_zone_tile_count[slot] += 1
	return _succeed(_zone_tile_count[slot], ref)


func remove_tile(ref: Vector2i, tile: int) -> OpResult:
	"""Unlink one tile from a zone and recycle its link. Returns the zone's remaining tile count."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if not is_tile_index(tile):
		return _refuse(REFUSE_INVALID_TILE)
	var link: int = _find_link(slot, tile)
	if link == NO_LINK:
		return _refuse(REFUSE_TILE_NOT_LINKED)
	_unlink_from_tile(tile, link)
	_unlink_from_zone(slot, link)
	_free_link(link)
	_zone_tile_count[slot] -= 1
	return _succeed(_zone_tile_count[slot], ref)


func _take_link() -> int:
	"""Hand out one link from the free list, or from the never-used bump region."""
	var link: int = _link_free_head
	if link != NO_LINK:
		_link_free_head = _link_tile_next[link]
	else:
		link = _link_bump
		_link_bump += 1
	_link_used += 1
	return link


func _free_link(link: int) -> void:
	"""Return one link to the free list, clearing every field it carried."""
	_link_tile[link] = NO_LINK
	_link_zone[link] = EntityDirectory.NULL_SLOT
	_link_zone_next[link] = NO_LINK
	_link_tile_next[link] = _link_free_head
	_link_free_head = link
	_link_used -= 1


func _find_link(zone_slot: int, tile: int) -> int:
	"""The link joining a zone to a tile, or NO_LINK. Walks the tile's list, which is the short one."""
	var link: int = _tile_link_head[tile]
	while link != NO_LINK:
		if _link_zone[link] == zone_slot:
			return link
		link = _link_tile_next[link]
	return NO_LINK


func _unlink_from_tile(tile: int, link: int) -> void:
	"""Splice one link out of its tile's list, updating `WorldTileMaps.zone_link_head` if it led."""
	var cursor: int = _tile_link_head[tile]
	if cursor == link:
		_tile_link_head[tile] = _link_tile_next[link]
		return
	while cursor != NO_LINK and _link_tile_next[cursor] != link:
		cursor = _link_tile_next[cursor]
	if cursor != NO_LINK:
		_link_tile_next[cursor] = _link_tile_next[link]


func _unlink_from_zone(zone_slot: int, link: int) -> void:
	"""Splice one link out of its zone's list, updating the zone's head if it led."""
	var cursor: int = _zone_link_head[zone_slot]
	if cursor == link:
		_zone_link_head[zone_slot] = _link_zone_next[link]
		return
	while cursor != NO_LINK and _link_zone_next[cursor] != link:
		cursor = _link_zone_next[cursor]
	if cursor != NO_LINK:
		_link_zone_next[cursor] = _link_zone_next[link]


func zone_covers_tile(ref: Vector2i, tile: int) -> bool:
	"""True when a live zone has this exterior tile in its membership list."""
	if not zone_slot_of_into(ref, _math_b):
		return false
	return is_tile_index(tile) and _find_link(_math_b.value, tile) != NO_LINK


func tile_count_of(slot: int) -> IntMath.IntResult:
	"""The number of tiles a live zone covers, or an explicit refusal."""
	return _read_zone(slot, _zone_tile_count)


func link_count() -> int:
	"""Total live tile links across every zone, against GDD §4.2's 16384 ceiling."""
	return _link_used


func tile_link_head_of(tile: int) -> IntMath.IntResult:
	"""`WorldTileMaps.zone_link_head` for one tile: its first link, or NO_LINK when uncovered."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(_tile_link_head[tile])
	return out


func next_tile_link(link: int) -> IntMath.IntResult:
	"""The next link in a tile's list, or an explicit refusal for a cursor off the arena."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if link < 0 or link >= ZONE_LINK_CAPACITY:
		out.refuse(String(REFUSE_ZONE_LINK_CAPACITY))
		return out
	out.succeed(_link_tile_next[link])
	return out


func zone_slot_of_link(link: int) -> IntMath.IntResult:
	"""The zone row a link belongs to, or an explicit refusal for a cursor off the arena."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if link < 0 or link >= ZONE_LINK_CAPACITY:
		out.refuse(String(REFUSE_ZONE_LINK_CAPACITY))
		return out
	out.succeed(_link_zone[link])
	return out


func zones_intersect(a_ref: Vector2i, b_ref: Vector2i) -> bool:
	"""True when two live zones share at least one exterior tile.

	§5.1 describes the basin as shared by "all intersecting zones". Nothing here derives the
	basin from this test -- see the header -- but the designation command will need it.
	"""
	if not zone_slot_of_into(a_ref, _math) or not zone_slot_of_into(b_ref, _math_b):
		return false
	var a_slot: int = _math.value
	var b_slot: int = _math_b.value
	var link: int = _zone_link_head[a_slot]
	while link != NO_LINK:
		if _find_link(b_slot, _link_tile[link]) != NO_LINK:
			return true
		link = _link_zone_next[link]
	return false


# --- GDD §5.1 basin references ------------------------------------------------------------------------

func set_basin(ref: Vector2i, basin_ref: Vector2i) -> OpResult:
	"""Point a zone at the basin zone whose forage stock it draws from (GDD §5.1).

	This is the anti-multiplication gate. Refuses a zone that already owns patches (its stock
	would be stranded), a basin that is itself bound elsewhere (a chain would give two answers
	for one zone), and a basin of a different ZoneType.

	Ruling §4.5: rebinding "releases its outstanding claims first ... before changing its identity
	or basin", and neither release nor rebind resets basin usage. Both zones' collected totals
	survive; only the claims this zone owned go.
	"""
	if not zone_slot_of_into(ref, _math) or not zone_slot_of_into(basin_ref, _math_b):
		return _refuse(REFUSE_ZONE_NOT_PRESENT)
	var slot: int = _math.value
	var basin_slot: int = _math_b.value
	if _zone_patch_count[slot] > 0:
		return _refuse(REFUSE_BASIN_HAS_OWN_PATCHES)
	if _zone_type[slot] != _zone_type[basin_slot]:
		return _refuse(REFUSE_ZONE_TYPE_MISMATCH)
	if basin_slot != slot and _zone_basin_slot[basin_slot] != basin_ref.x:
		return _refuse(REFUSE_BASIN_CHAIN)
	_release_claims_of_zone_slot(slot)
	_zone_basin_slot[slot] = basin_ref.x
	_zone_basin_generation[slot] = basin_ref.y
	_normalise_quota_mode(slot)
	return _succeed(basin_slot, basin_ref)


func _normalise_quota_mode(slot: int) -> void:
	"""Keep a zone's quota mode legal for what it now is (ruling §4.6's Valid-use column).

	Automatic is a BASIN mode and Inherit is a DESIGNATION mode, so binding a self-owned zone to
	another basin turns Automatic into Inherit -- which is also R05-QUOTA-018's default for a new
	designation -- and unbinding turns Inherit back into Automatic. Manual is valid on both and is
	never touched, so a player setting survives a rebind exactly as it survives a season change.
	INTERPRETATION: the ruling states the valid-use table and the Inherit default, and this is the
	only operation in this module that turns a basin into a designation.
	"""
	var is_designation: bool = _zone_basin_slot[slot] != _zone_ref_slot[slot]
	if is_designation and _zone_quota_mode[slot] == QUOTA_MODE_AUTOMATIC:
		_zone_quota_mode[slot] = QUOTA_MODE_INHERIT
	elif not is_designation and _zone_quota_mode[slot] == QUOTA_MODE_INHERIT:
		_zone_quota_mode[slot] = QUOTA_MODE_AUTOMATIC


func basin_ref_of(slot: int) -> Vector2i:
	"""The basin reference a live zone draws from, or the §4.1 null reference `(-1, 0)`."""
	if not is_zone_present(slot):
		return NULL_REF
	return Vector2i(_zone_basin_slot[slot], _zone_basin_generation[slot])


func basin_slot_of(ref: Vector2i) -> IntMath.IntResult:
	"""The zone row holding the forage stock this zone harvests, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	basin_slot_of_into(ref, out)
	return out


func basin_slot_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating basin_slot_of(): resolve zone -> basin row into caller-owned `out`.

	The basin reference is validated on the way through, so a basin destroyed under a live zone
	refuses here instead of resolving to whatever row later reused its slot.
	"""
	if not zone_slot_of_into(ref, out):
		return false
	var slot: int = out.value
	var basin: Vector2i = Vector2i(_zone_basin_slot[slot], _zone_basin_generation[slot])
	return zone_slot_of_into(basin, out)


func zones_share_basin(a_ref: Vector2i, b_ref: Vector2i) -> bool:
	"""True when two live zones resolve to the same basin row, and so to the same forage stock."""
	if not basin_slot_of_into(a_ref, _math):
		return false
	var a_basin: int = _math.value
	if not basin_slot_of_into(b_ref, _math_b):
		return false
	return a_basin == _math_b.value


# --- ForagePatch lifecycle ----------------------------------------------------------------------------

func create_patch(ref: Vector2i, kind: int, item_id: int) -> OpResult:
	"""Create one of a forage basin's five §5.5 patches, full to GDD §5.1's 80% of capacity.

	Returns the patch row. Capacity and kind come from §5.5's table, never from the caller.
	Refuses a non-FORAGE zone, a zone bound to another basin, a kind outside 0..4, a negative
	item id, and a second patch of the same kind.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	var code: StringName = _refuse_create_patch(slot, kind, item_id)
	if code != REFUSE_NONE:
		return _refuse(code)
	var row: int = slot * PATCHES_PER_ZONE + kind
	var capacity: int = PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
	_patch_present[row] = 1
	_patch_item_id[row] = item_id
	_patch_zone_slot[row] = ref.x
	_patch_zone_generation[row] = ref.y
	_patch_capacity_milli[row] = capacity
	_patch_stock_milli[row] = capacity * INITIAL_STOCK_NUMERATOR / INITIAL_STOCK_DENOMINATOR
	_patch_harvested_year_milli[row] = 0
	_zone_patch_count[slot] += 1
	return _succeed(row, ref)


func _refuse_create_patch(zone_slot: int, kind: int, item_id: int) -> StringName:
	"""The code blocking a patch creation, or REFUSE_NONE when the basin can hold it."""
	if _zone_type[zone_slot] != ZONE_TYPE_FORAGE:
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_basin_slot[zone_slot] != _zone_ref_slot[zone_slot]:
		return REFUSE_ZONE_IS_BOUND
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if item_id < 0 or not IntMath.fits_int32(item_id):
		return REFUSE_INVALID_ITEM_ID
	if _patch_present[zone_slot * PATCHES_PER_ZONE + kind] == 1:
		return REFUSE_PATCH_PRESENT
	return REFUSE_NONE


func create_patch_set(ref: Vector2i, item_ids: PackedInt32Array) -> OpResult:
	"""Create all five §5.5 patches of a forage basin at once, in PATCH_KEYS order.

	All or nothing: every kind is validated before the first is written, so a refusal leaves the
	basin with the patches it already had. Returns the number of patches created.
	"""
	if item_ids.size() != PATCHES_PER_ZONE:
		return _refuse(REFUSE_PATCH_SET_SIZE)
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	for kind: int in PATCHES_PER_ZONE:
		var code: StringName = _refuse_create_patch(slot, kind, item_ids[kind])
		if code != REFUSE_NONE:
			return _refuse(code)
	for kind: int in PATCHES_PER_ZONE:
		var created: OpResult = create_patch(ref, kind, item_ids[kind])
		if not created.ok:
			return created
	return _succeed(PATCHES_PER_ZONE, ref)


func is_patch_kind(kind: int) -> bool:
	"""True when `kind` names one of §5.5's five forage rows."""
	return kind >= 0 and kind < PATCHES_PER_ZONE


func is_patch_present(row: int) -> bool:
	"""True when `row` is in range and holds a live forage patch."""
	return row >= 0 and row < FORAGE_PATCH_CAPACITY and _patch_present[row] == 1


func patch_count_of(slot: int) -> IntMath.IntResult:
	"""How many of a live zone's five patch rows exist, or an explicit refusal."""
	return _read_zone(slot, _zone_patch_count)


func patch_row_for_zone(ref: Vector2i, kind: int) -> IntMath.IntResult:
	"""The patch row a zone harvests for one kind, resolved through its basin (GDD §5.1)."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	patch_row_for_zone_into(ref, kind, out)
	return out


func patch_row_for_zone_into(ref: Vector2i, kind: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating patch_row_for_zone(): write `basin_slot*5 + kind` into caller-owned `out`.

	Two zones sharing a basin resolve to the SAME row here, which is the whole mechanism behind
	§5.1's "all intersecting zones share its quotas and do not multiply capacity".
	"""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not basin_slot_of_into(ref, out):
		return false
	var row: int = out.value * PATCHES_PER_ZONE + kind
	if _patch_present[row] != 1:
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	return out.succeed(row)


func patch_item_id_of(row: int) -> IntMath.IntResult:
	"""The patch's `item_id`, or an explicit refusal. See the header on its unstated domain."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_item_id[row])
	return out


func patch_zone_ref_of(row: int) -> Vector2i:
	"""The basin zone a live patch belongs to, or the §4.1 null reference `(-1, 0)`."""
	if not is_patch_present(row):
		return NULL_REF
	return Vector2i(_patch_zone_slot[row], _patch_zone_generation[row])


func patch_kind_of_row(row: int) -> IntMath.IntResult:
	"""Which of §5.5's five rows a patch row is, from the owner-major index."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(row % PATCHES_PER_ZONE)
	return out


func stock_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's remaining stock in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	stock_milli_into(row, out)
	return out


func stock_milli_into(row: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating stock_milli_of(): write the stock into caller-owned `out`."""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	return out.succeed(_patch_stock_milli[row])


func patch_capacity_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's §5.5 capacity in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_capacity_milli[row])
	return out


func harvested_year_milli_of(row: int) -> IntMath.IntResult:
	"""The patch's year-to-date harvested total: ANNUAL ECOLOGICAL HISTORY (decision 0030).

	This is NOT the quota accumulator. The daily aggregate quota is measured against
	HarvestZone.harvested_today_milli; this column exists so a year of pressure on one patch stays
	visible after the daily counters have been reset 48 times.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_present(row):
		out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
		return out
	out.succeed(_patch_harvested_year_milli[row])
	return out


func reset_harvested_year() -> void:
	"""Zero every patch's year-to-date total. The caller owns the year boundary (48 days, §5.1).

	Ruling §4.4: "Annual patch counters reset only at the existing year boundary." This does NOT
	reopen a spent daily quota, and run_midnight() does not call it.
	"""
	_patch_harvested_year_milli.fill(0)


# --- §5.5 seasonal availability ------------------------------------------------------------------------

func is_season(season: int) -> bool:
	"""True when `season` is one of §4.3's four Season values."""
	return season >= 0 and season < SEASON_COUNT


func availability_per_1000(kind: int, season: int) -> IntMath.IntResult:
	"""§5.5's seasonal availability multiplier for one forage kind, per 1000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	availability_per_1000_into(kind, season, out)
	return out


func availability_per_1000_into(kind: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating availability_per_1000(): write the multiplier into caller-owned `out`."""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	return out.succeed(PATCH_AVAILABILITY_PER_1000[kind * SEASON_COUNT + season])


func is_dormant(kind: int, season: int) -> bool:
	"""True when §5.5 makes this kind unavailable this season: "dormant, not destroyed".

	A dormant patch keeps its stock and its capacity; it neither regrows nor yields a harvest.
	An out-of-range kind or season is reported as NOT dormant, because it names no patch at all;
	availability_per_1000() is the form that refuses those with a reason.
	"""
	if not availability_per_1000_into(kind, season, _math_b):
		return false
	return _math_b.value == 0


# --- §5.5 regrowth ---------------------------------------------------------------------------------------

func daily_regrowth_milli(row: int, season: int) -> IntMath.IntResult:
	"""§5.5's daily regrowth for one patch, already clamped to the room left below capacity."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_regrowth_milli_into(row, season, out)
	return out


func daily_regrowth_milli_into(row: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_regrowth_milli(): ruling §8A's capped additive regrowth, into `out`.

	`min(K - P, floor((K - P) * r * S / 1000000) + 1000)`, zero when the patch is dormant or
	already full, and an explicit refusal when the stored stock is above its own capacity.

	The `room == 0` half of that early return states §5.5's "when ... P<K" rather than changing an
	answer: with no room the cap already yields 0. Decision 0036 records that a mutation deleting
	it survives, so a later reader does not read the survival as a missing test.
	"""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	var room: int = _patch_capacity_milli[row] - _patch_stock_milli[row]
	if room < 0:
		return out.refuse(String(REFUSE_STOCK_ABOVE_CAPACITY))
	var kind: int = row % PATCHES_PER_ZONE
	if not availability_per_1000_into(kind, season, out):
		return false
	if out.value == 0 or room == 0:
		return out.succeed(0)
	var availability: int = out.value
	if not IntMath.checked_mul_into(room, PATCH_REGROWTH_PER_1000[kind], out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, availability, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.floor_div_into(out.value, REGROWTH_DENOMINATOR, out):
		return false
	if not IntMath.checked_add_into(out.value, REGROWTH_MINIMUM_MILLI, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return out.succeed(mini(out.value, room))


func regrow_patch(row: int, season: int) -> OpResult:
	"""Apply one day of §5.5 regrowth to a patch. Returns the stock after growing.

	A dormant patch grows nothing (§5.5 conditions the minimum on season>0) and is not an error:
	"unavailable patches become dormant, not destroyed".
	"""
	if not daily_regrowth_milli_into(row, season, _math):
		return _refuse(StringName(_math.error))
	_patch_stock_milli[row] += _math.value
	return _succeed(_patch_stock_milli[row], patch_zone_ref_of(row))


func regrow_daily(season: int) -> OpResult:
	"""Apply one day of regrowth to every live patch. Returns how many patches grew.

	Iterates the ascending live-zone list, so the order is the slot order and not a hash order.
	ARCH-SYS-005 owns the midnight call; this is the sweep it needs, and nothing else here reads
	a clock.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	var grown: int = 0
	for index: int in _live_zone_count:
		var base: int = _live_zone_slots[index] * PATCHES_PER_ZONE
		for kind: int in PATCHES_PER_ZONE:
			var row: int = base + kind
			if _patch_present[row] != 1:
				continue
			if not daily_regrowth_milli_into(row, season, _math):
				return _refuse(StringName(_math.error))
			if _math.value > 0:
				_patch_stock_milli[row] += _math.value
				grown += 1
	return _succeed(grown, NULL_REF)


# --- §5.5 protection floors and quotas -------------------------------------------------------------------

func harvest_floor_milli(row: int, intensive: bool) -> IntMath.IntResult:
	"""§5.5's protection floor for a patch: 20% of K, or 5% of K under intensive harvest."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	harvest_floor_milli_into(row, intensive, out)
	return out


func harvest_floor_milli_into(row: int, intensive: bool, out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest_floor_milli(): write the floor into caller-owned `out`."""
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	var percent: int = INTENSIVE_FLOOR_PERCENT if intensive else SUSTAINABLE_FLOOR_PERCENT
	if not IntMath.checked_mul_into(_patch_capacity_milli[row], percent, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.floor_div_into(out.value, PERCENT_DENOMINATOR, out)


# --- decision 0030 §4.6: quota modes and the automatic seasonal allowance -------------------------

func is_quota_mode(mode: int) -> bool:
	"""True when `mode` names one of catalog.gd's three compiled ForageQuotaMode ids."""
	return mode >= 0 and mode < QUOTA_MODE_COUNT


func quota_mode_of(slot: int) -> IntMath.IntResult:
	"""The zone's quota mode, or an explicit refusal for a row holding no zone."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_zone_quota_mode[slot])
	return out


func is_designation(slot: int) -> bool:
	"""True when this live zone draws from ANOTHER zone's basin, which is what makes it one."""
	return is_zone_present(slot) and _zone_basin_slot[slot] != _zone_ref_slot[slot]


func set_quota_mode(ref: Vector2i, mode: int, season: int) -> OpResult:
	"""Set a zone's quota mode, then reconcile. Returns how many whole claims were released.

	Ruling §4.6's Valid-use column is enforced, not merely documented: Automatic is a BASIN mode,
	Inherit is a DESIGNATION mode, and Manual needs its stored value to be inside R05-QUOTA-020's
	0..1180000 range, so a zone created with a larger §4.2 value cannot smuggle it in here.
	"""
	if not is_quota_mode(mode):
		return _refuse(REFUSE_INVALID_QUOTA_MODE)
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	if mode == QUOTA_MODE_AUTOMATIC and is_designation(slot):
		return _refuse(REFUSE_QUOTA_MODE_NOT_VALID_HERE)
	if mode == QUOTA_MODE_INHERIT and not is_designation(slot):
		return _refuse(REFUSE_QUOTA_MODE_NOT_VALID_HERE)
	if mode == QUOTA_MODE_MANUAL and not _is_manual_quota(_zone_quota_milli[slot]):
		return _refuse(REFUSE_INVALID_QUOTA)
	_zone_quota_mode[slot] = mode
	return reconcile_claims(season)


func set_quota_milli(ref: Vector2i, quota_milli: int, season: int) -> OpResult:
	"""Supply a manual daily quota (R05-QUOTA-020), then reconcile §4.5's excess claims.

	Returns how many whole claims the change released. Supplying a value IS the manual override,
	so the mode moves to Manual and then survives every later season change. The value is refused
	outside 0..1180000 rather than clamped: there is no unlimited sentinel, and a designation's
	larger value could never expand its basin's allowance anyway.
	"""
	if not _is_manual_quota(quota_milli):
		return _refuse(REFUSE_INVALID_QUOTA)
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var slot: int = _math.value
	_zone_quota_milli[slot] = quota_milli
	_zone_quota_mode[slot] = QUOTA_MODE_MANUAL
	return reconcile_claims(season)


func _is_manual_quota(quota_milli: int) -> bool:
	"""True when a value is inside ruling §4.6's inclusive 0..sum(K_i) manual range."""
	return quota_milli >= MANUAL_QUOTA_MIN_MILLI and quota_milli <= MANUAL_QUOTA_MAX_MILLI


func automatic_allowance_milli(kind: int, season: int) -> IntMath.IntResult:
	"""Ruling §4.6's per-kind automatic allowance in milli-U/day."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	automatic_allowance_milli_into(kind, season, out)
	return out


func automatic_allowance_milli_into(kind: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating automatic_allowance_milli(): the §4.6 formula, into caller-owned `out`.

	`0` when the kind is dormant; otherwise `min(K - target, floor((K - target) * r * S / 1000000)
	+ 1000)` with `target = floor(800 * K / 1000)`. The headroom cap never binds on §5.5's shipped
	table (header); it is implemented because the ruling states it.
	"""
	if not availability_per_1000_into(kind, season, out):
		return false
	var availability: int = out.value
	if availability == 0:
		return out.succeed(0)
	var capacity: int = PATCH_CAPACITY_U[kind] * MILLI_PER_UNIT
	var target: int = capacity * AUTOMATIC_TARGET_PER_1000 / AUTOMATIC_TARGET_DENOMINATOR
	var headroom: int = capacity - target
	if not IntMath.checked_mul_into(headroom, PATCH_REGROWTH_PER_1000[kind], out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.checked_mul_into(out.value, availability, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if not IntMath.floor_div_into(out.value, AUTOMATIC_ALLOWANCE_DENOMINATOR, out):
		return false
	return out.succeed(mini(headroom, out.value + AUTOMATIC_ALLOWANCE_TERM_MILLI))


func automatic_daily_quota_milli(season: int) -> IntMath.IntResult:
	"""Ruling §4.6's automatic basin quota: the sum of the five per-kind allowances."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	automatic_daily_quota_milli_into(season, out)
	return out


func automatic_daily_quota_milli_into(season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating automatic_daily_quota_milli(): the five-kind sum into caller-owned `out`.

	It depends on §5.5's table and the season alone, not on any basin's current stock, exactly as
	the ruling specifies: "It does not substitute current stock for target_stock_i."
	"""
	var total: int = 0
	for kind: int in PATCHES_PER_ZONE:
		if not automatic_allowance_milli_into(kind, season, out):
			return false
		total += out.value
	return out.succeed(total)


func daily_quota_milli_of(slot: int, season: int) -> IntMath.IntResult:
	"""One zone's effective daily quota under its own mode."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	daily_quota_milli_into(slot, season, out)
	return out


func daily_quota_milli_into(slot: int, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating daily_quota_milli_of(): resolve Manual/Automatic/Inherit into `out`.

	Inherit follows the basin's own effective quota, and basin chains are refused by set_basin(),
	so this recurses exactly once. A zone left Inherit while owning itself is refused rather than
	looped on; _normalise_quota_mode() is what stops that state existing.
	"""
	if not is_zone_present(slot):
		return out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	var mode: int = _zone_quota_mode[slot]
	if mode == QUOTA_MODE_MANUAL:
		return out.succeed(_zone_quota_milli[slot])
	if mode == QUOTA_MODE_AUTOMATIC:
		return automatic_daily_quota_milli_into(season, out)
	if not basin_slot_of_into(zone_ref_of(slot), out):
		return false
	var basin_slot: int = out.value
	if basin_slot == slot:
		return out.refuse(String(REFUSE_QUOTA_MODE_NOT_VALID_HERE))
	return daily_quota_milli_into(basin_slot, season, out)


# --- decision 0030 §4.2: the daily aggregate quota ------------------------------------------------

func harvested_today_milli_of(slot: int) -> IntMath.IntResult:
	"""`H`: total forage collected through this zone today, across all five kinds."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_zone_harvested_today_milli[slot])
	return out


func quota_reserved_milli_of(slot: int) -> IntMath.IntResult:
	"""`R`: uncollected quantity of every active claim naming this zone. A DERIVED CACHE.

	Maintained atomically by the claim paths and rebuildable in full from the claim table by
	rebuild_reservation_aggregates(); the ruling excludes it from canonical hashing for that
	reason.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_zone_present(slot):
		out.refuse(String(REFUSE_ZONE_NOT_PRESENT))
		return out
	out.succeed(_zone_quota_reserved_milli[slot])
	return out


func available_quota_milli(ref: Vector2i, season: int) -> IntMath.IntResult:
	"""`max(0, min(Q_b - H_b - R_b, Q_z - H_z - R_z))` for a harvest through this designation."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	available_quota_milli_into(ref, season, out)
	return out


func available_quota_milli_into(ref: Vector2i, season: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating available_quota_milli(): write the ruling §4.2 formula into `out`."""
	if not is_season(season):
		return out.refuse(String(REFUSE_INVALID_SEASON))
	if not zone_slot_of_into(ref, out):
		return false
	var designation_slot: int = out.value
	if not basin_slot_of_into(ref, out):
		return false
	return _available_quota_into(designation_slot, out.value, season, out)


func _available_quota_into(designation_slot: int, basin_slot: int, season: int,
		out: IntMath.IntResult) -> bool:
	"""Both applicable limits against their own collected and reserved totals, never below zero.

	When the designation IS the basin there is one limit, read once. Otherwise the stricter of the
	two binds, which is what makes a designation able to be stricter but never larger in effect.
	"""
	if not daily_quota_milli_into(basin_slot, season, out):
		return false
	var basin_left: int = (out.value - _zone_harvested_today_milli[basin_slot]
		- _zone_quota_reserved_milli[basin_slot])
	if designation_slot == basin_slot:
		return out.succeed(maxi(0, basin_left))
	if not daily_quota_milli_into(designation_slot, season, out):
		return false
	var zone_left: int = (out.value - _zone_harvested_today_milli[designation_slot]
		- _zone_quota_reserved_milli[designation_slot])
	return out.succeed(maxi(0, mini(basin_left, zone_left)))


func is_quota_reached(ref: Vector2i, season: int) -> bool:
	"""True when REQ-SET-069's daily quota condition holds and no new claim may be admitted."""
	if not available_quota_milli_into(ref, season, _math_b):
		return true
	return _math_b.value <= 0


# --- decision 0030 §4.3: stock reserved by outstanding claims -------------------------------------

func stock_reserved_milli(ref: Vector2i, kind: int) -> IntMath.IntResult:
	"""Uncollected quantity of every active claim on this basin's patch of one kind."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_kind(kind):
		out.refuse(String(REFUSE_INVALID_PATCH_KIND))
		return out
	if not basin_slot_of_into(ref, out):
		return out
	out.succeed(_stock_reserved_milli(out.value, kind))
	return out


func _stock_reserved_milli(basin_slot: int, kind: int) -> int:
	"""Sum `remaining_milli` over active claims naming this basin and kind.

	A STRAIGHT SCAN of the 8192 claim rows, deliberately: the ruling budgets any acceleration
	index separately and excludes it from §4.7's total, so none is added here. See the header's
	unmeasured-cost note.
	"""
	var basin_ref: Vector2i = Vector2i(_zone_ref_slot[basin_slot], _zone_ref_generation[basin_slot])
	var total: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or _claim_patch_kind[row] != kind:
			continue
		if _claim_basin_slot[row] != basin_ref.x or _claim_basin_generation[row] != basin_ref.y:
			continue
		total += _claim_remaining_milli[row]
	return total


func stock_available_milli(ref: Vector2i, kind: int, intensive: bool) -> IntMath.IntResult:
	"""`max(0, stock - applicable_floor - stock_reserved)` for this zone's basin patch."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_kind(kind):
		out.refuse(String(REFUSE_INVALID_PATCH_KIND))
		return out
	if not basin_slot_of_into(ref, out):
		return out
	stock_available_milli_into(out.value, kind, intensive, out)
	return out


func stock_available_milli_into(basin_slot: int, kind: int, intensive: bool,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating stock_available_milli(), taking the already-resolved BASIN row."""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	var row: int = basin_slot * PATCHES_PER_ZONE + kind
	if not is_patch_present(row):
		return out.refuse(String(REFUSE_PATCH_NOT_PRESENT))
	if not harvest_floor_milli_into(row, intensive, out):
		return false
	var above_floor: int = _patch_stock_milli[row] - out.value
	return out.succeed(maxi(0, above_floor - _stock_reserved_milli(basin_slot, kind)))


func harvestable_milli(ref: Vector2i, kind: int, season: int, intensive: bool)\
		-> IntMath.IntResult:
	"""The largest collection admissible right now: `min(available_quota, stock_available)`.

	0 is a truthful answer here, not a sentinel: a dormant, floored, fully reserved or
	quota-stopped patch really does offer nothing. harvest() refuses with the reason.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_patch_kind(kind):
		out.refuse(String(REFUSE_INVALID_PATCH_KIND))
		return out
	if not zone_slot_of_into(ref, out):
		return out
	var designation_slot: int = out.value
	if not patch_row_for_zone_into(ref, kind, out):
		return out
	_harvestable_into(designation_slot, out.value / PATCHES_PER_ZONE, kind, season, intensive, out)
	return out


func _harvestable_into(designation_slot: int, basin_slot: int, kind: int, season: int,
		intensive: bool, out: IntMath.IntResult) -> bool:
	"""`min(available_quota, stock_available)` for already-resolved designation and basin rows."""
	if not availability_per_1000_into(kind, season, out):
		return false
	if out.value == 0:
		return out.succeed(0)
	if not stock_available_milli_into(basin_slot, kind, intensive, out):
		return false
	var stock: int = out.value
	if not _available_quota_into(designation_slot, basin_slot, season, out):
		return false
	return out.succeed(mini(stock, out.value))


# --- harvest: collection with no outstanding claim ------------------------------------------------

func harvest(ref: Vector2i, kind: int, amount_milli: int, season: int, intensive: bool)\
		-> OpResult:
	"""Collect `amount_milli` of one forage kind through a zone. Returns the stock left after it.

	The unclaimed path: nothing was reserved in advance, so the whole amount is checked against
	today's remaining allowance and against stock that no claim has already spoken for. Refuses
	rather than clamping when the patch cannot give up exactly that much: a silent short delivery
	would let a job book more cargo than the basin released. The stock debit and the annual
	counter land on the BASIN's row; the collected total lands on the basin and, when it differs,
	on the designation -- one harvest against two policy limits, never duplicate inventory.
	"""
	if not patch_row_for_zone_into(ref, kind, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	if not harvest_into(ref, kind, amount_milli, season, intensive, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_math.value, patch_zone_ref_of(row))


func harvest_into(ref: Vector2i, kind: int, amount_milli: int, season: int, intensive: bool,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest(): write the stock remaining after the debit into caller-owned `out`.

	`out` doubles as this call's scratch, so it must not be a result the caller still needs. A
	refusal debits nothing: stock, the annual counter and both collected totals are untouched.
	"""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if not zone_slot_of_into(ref, out):
		return false
	var designation_slot: int = out.value
	if not patch_row_for_zone_into(ref, kind, out):
		return false
	var row: int = out.value
	var basin_slot: int = row / PATCHES_PER_ZONE
	var code: StringName = _check_harvest(ref, row, kind, amount_milli, season, intensive)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if not _may_credit_collected(designation_slot, basin_slot, amount_milli, out):
		return false
	_credit_collected(designation_slot, basin_slot, amount_milli)
	_patch_stock_milli[row] -= amount_milli
	_patch_harvested_year_milli[row] += amount_milli
	return out.succeed(_patch_stock_milli[row])


func _may_credit_collected(designation_slot: int, basin_slot: int, amount_milli: int,
		out: IntMath.IntResult) -> bool:
	"""Preflight both collected-total additions, so the commit that follows cannot wrap midway."""
	if not IntMath.checked_add_into(_zone_harvested_today_milli[basin_slot], amount_milli, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if designation_slot == basin_slot:
		return true
	if not IntMath.checked_add_into(_zone_harvested_today_milli[designation_slot], amount_milli,
			out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return true


func _credit_collected(designation_slot: int, basin_slot: int, amount_milli: int) -> void:
	"""Add one collection to today's totals: the basin always, the designation only if different.

	Ruling §4.2: "For `z == b`, update that zone's aggregates once." The two writes are sequential
	`+=` on purpose, so crediting the same row twice would visibly double the total.
	"""
	_zone_harvested_today_milli[basin_slot] += amount_milli
	if designation_slot != basin_slot:
		_zone_harvested_today_milli[designation_slot] += amount_milli


func _check_harvest(ref: Vector2i, row: int, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when this zone may collect exactly `amount_milli` from `row` this season."""
	var zone_code: StringName = _check_harvest_zone(ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	if not availability_per_1000_into(kind, season, _math_c):
		return StringName(_math_c.error)
	if _math_c.value == 0:
		return REFUSE_PATCH_DORMANT
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	return _check_harvest_limits(ref, row, kind, amount_milli, season, intensive)


func _check_harvest_limits(ref: Vector2i, row: int, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""The floor, the claim-reserved stock and both daily quota limits, in that order.

	The floor is reported separately from the reservation so a caller can tell "the ecology says
	no" from "another job already promised this".
	"""
	var basin_slot: int = row / PATCHES_PER_ZONE
	if not harvest_floor_milli_into(row, intensive, _math_c):
		return StringName(_math_c.error)
	if _patch_stock_milli[row] - amount_milli < _math_c.value:
		return REFUSE_BELOW_HARVEST_FLOOR
	if not stock_available_milli_into(basin_slot, kind, intensive, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_STOCK_RESERVED
	if not available_quota_milli_into(ref, season, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_QUOTA_REACHED
	return REFUSE_NONE


func _check_harvest_zone(ref: Vector2i) -> StringName:
	"""REFUSE_NONE when the designation itself permits an automatic harvest.

	§5.5: "Protected tiles are never automatically harvested." This store owns no manual harvest
	path -- none is specified -- so a protected zone refuses outright.
	"""
	if not zone_slot_of_into(ref, _math_b):
		return StringName(_math_b.error)
	var slot: int = _math_b.value
	if _zone_type[slot] != ZONE_TYPE_FORAGE:
		return REFUSE_ZONE_TYPE_MISMATCH
	if _zone_enabled[slot] != 1:
		return REFUSE_ZONE_DISABLED
	if _zone_protected[slot] == 1:
		return REFUSE_ZONE_PROTECTED
	return REFUSE_NONE


# --- decision 0030 §4.3: ForageClaim lifecycle ----------------------------------------------------

func claim_count() -> int:
	"""Number of active forage claims across the whole 8192-row table."""
	return _claim_count


func is_claim_active(row: int) -> bool:
	"""True when `row` is in range and holds an active claim."""
	return row >= 0 and row < FORAGE_CLAIM_CAPACITY and _claim_active[row] == 1


func claim_row_of(job_ref: Vector2i) -> IntMath.IntResult:
	"""The claim row a Job owns, or an explicit refusal naming why it owns none."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	claim_row_of_into(job_ref, out)
	return out


func claim_row_of_into(job_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating claim_row_of(): validate the Job reference AND its generation into `out`.

	R05-QUOTA-023: a retired or reused Job row must not leave a prior generation's claim usable.
	The claim stores the reference it was created with, so a row whose Job has been destroyed and
	replaced refuses with CLAIM_STALE_JOB instead of acting for the newcomer.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	var row: int = _directory.get_typed_row(job_ref)
	if row < 0 or row >= FORAGE_CLAIM_CAPACITY:
		return out.refuse(String(REFUSE_JOB_NOT_PRESENT))
	if _claim_active[row] != 1:
		return out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
	if _claim_job_slot[row] != job_ref.x or _claim_job_generation[row] != job_ref.y:
		return out.refuse(String(REFUSE_CLAIM_STALE_JOB))
	return out.succeed(row)


func claim_remaining_milli_of(row: int) -> IntMath.IntResult:
	"""The uncollected quantity a claim still promises its owning Job."""
	return _read_claim(row, _claim_remaining_milli)


func claim_created_tick_of(row: int) -> IntMath.IntResult:
	"""The owning Job's `created_tick`, cached at claim time: §4.5's first release-order term."""
	return _read_claim(row, _claim_created_tick)


func claim_persistent_id_of(row: int) -> IntMath.IntResult:
	"""The owning Job's persistent ID, cached at claim time: §4.5's release-order tiebreak."""
	return _read_claim(row, _claim_persistent_id)


func _read_claim(row: int, column: PackedInt64Array) -> IntMath.IntResult:
	"""Read one int64 claim column of an active row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_claim_active(row):
		out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
		return out
	out.succeed(column[row])
	return out


func claim_kind_of(row: int) -> IntMath.IntResult:
	"""Which of §5.5's five forage rows a claim names. One claim names exactly one kind."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_claim_active(row):
		out.refuse(String(REFUSE_CLAIM_NOT_PRESENT))
		return out
	out.succeed(_claim_patch_kind[row])
	return out


func claim_job_ref_of(row: int) -> Vector2i:
	"""The owning Job reference of an active claim, or the §4.1 null reference `(-1, 0)`."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_job_slot[row], _claim_job_generation[row])


func claim_designation_ref_of(row: int) -> Vector2i:
	"""The designation an active claim harvests through, or the §4.1 null reference."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_designation_slot[row], _claim_designation_generation[row])


func claim_basin_ref_of(row: int) -> Vector2i:
	"""The basin an active claim draws stock from, or the §4.1 null reference."""
	if not is_claim_active(row):
		return NULL_REF
	return Vector2i(_claim_basin_slot[row], _claim_basin_generation[row])


func claim_forage(job_ref: Vector2i, designation_ref: Vector2i, kind: int, amount_milli: int,
		season: int, intensive: bool) -> OpResult:
	"""Reserve the COMPLETE intended collection for one Job. Returns its claim row.

	R05-QUOTA-005: quota and stock are preflighted and committed atomically, or every quantity is
	left unchanged. One pending claim per owning Job, naming one basin, one designation and one
	kind, so a second kind needs a second Job; shared work claims through its COORDINATOR, and a
	member Job is refused rather than reserving the same stock twice. Output capacity, consent and
	destination legality are the caller's preflights and are not checked here (header).
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	var request_code: StringName = _check_claim_request(designation_ref, kind, amount_milli,
		season, intensive)
	if request_code != REFUSE_NONE:
		return _refuse(request_code)
	if not _may_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli,
			_math_c):
		return _refuse(StringName(_math_c.error))
	_reserve_quota(_pending_designation_slot, _pending_basin_slot, amount_milli)
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, amount_milli)
	return _succeed(row, job_ref)


func _check_claim_owner(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Job may own a new forage claim on its own row."""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	if _claim_active[job_slot] != 1:
		return REFUSE_NONE
	if _claim_job_slot[job_slot] == job_ref.x and _claim_job_generation[job_slot] == job_ref.y:
		return REFUSE_CLAIM_PRESENT
	return REFUSE_CLAIM_STALE_JOB


func _check_claim_request(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""REFUSE_NONE when the designation, kind, season and amount are claimable.

	Leaves the resolved designation row, basin row and patch row in `_pending_*` for the commit
	that immediately follows. Nothing between the two calls can re-enter this store.
	"""
	var zone_code: StringName = _check_harvest_zone(designation_ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	if not is_patch_kind(kind):
		return REFUSE_INVALID_PATCH_KIND
	if not zone_slot_of_into(designation_ref, _math_c):
		return StringName(_math_c.error)
	_pending_designation_slot = _math_c.value
	if not patch_row_for_zone_into(designation_ref, kind, _math_c):
		return StringName(_math_c.error)
	_pending_patch_row = _math_c.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if not availability_per_1000_into(kind, season, _math_c):
		return StringName(_math_c.error)
	if _math_c.value == 0:
		return REFUSE_PATCH_DORMANT
	return _check_claim_limits(designation_ref, kind, amount_milli, season, intensive)


func _check_claim_limits(designation_ref: Vector2i, kind: int, amount_milli: int, season: int,
		intensive: bool) -> StringName:
	"""`admissible <= min(available_quota, stock_available)`, with the floor reported separately."""
	if not available_quota_milli_into(designation_ref, season, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_QUOTA_REACHED
	if not harvest_floor_milli_into(_pending_patch_row, intensive, _math_c):
		return StringName(_math_c.error)
	if _patch_stock_milli[_pending_patch_row] - amount_milli < _math_c.value:
		return REFUSE_BELOW_HARVEST_FLOOR
	if not stock_available_milli_into(_pending_basin_slot, kind, intensive, _math_c):
		return StringName(_math_c.error)
	if amount_milli > _math_c.value:
		return REFUSE_STOCK_RESERVED
	return REFUSE_NONE


func _may_reserve_quota(designation_slot: int, basin_slot: int, amount_milli: int,
		out: IntMath.IntResult) -> bool:
	"""Preflight both reservation additions, so the commit that follows cannot wrap midway."""
	if not IntMath.checked_add_into(_zone_quota_reserved_milli[basin_slot], amount_milli, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	if designation_slot == basin_slot:
		return true
	if not IntMath.checked_add_into(_zone_quota_reserved_milli[designation_slot], amount_milli,
			out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return true


func _reserve_quota(designation_slot: int, basin_slot: int, amount_milli: int) -> void:
	"""Add one claim to the outstanding totals: the basin always, the designation if different."""
	_zone_quota_reserved_milli[basin_slot] += amount_milli
	if designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] += amount_milli


func _write_claim(row: int, job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		amount_milli: int) -> void:
	"""Write one claim row and cache §4.5's release-order key from the owning Job.

	`created_tick` and the persistent ID are read from the Job exactly once here. Neither can
	change while that Job row lives, and both are rebuilt on load, so this is a cache of the
	Job's own fields and NOT a separate claim creation timestamp.
	"""
	var basin_ref: Vector2i = Vector2i(_zone_ref_slot[_pending_basin_slot],
		_zone_ref_generation[_pending_basin_slot])
	_claim_active[row] = 1
	_claim_job_slot[row] = job_ref.x
	_claim_job_generation[row] = job_ref.y
	_claim_designation_slot[row] = designation_ref.x
	_claim_designation_generation[row] = designation_ref.y
	_claim_basin_slot[row] = basin_ref.x
	_claim_basin_generation[row] = basin_ref.y
	_claim_patch_kind[row] = kind
	_claim_remaining_milli[row] = amount_milli
	_claim_created_tick[row] = _jobs.created_tick_of(row).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)
	_claim_count += 1


func collect_claim(job_ref: Vector2i, amount_milli: int, season: int, intensive: bool)\
		-> OpResult:
	"""Collect part or all of a Job's claim. Returns the amount collected, for one cargo creation.

	R05-QUOTA-003: the amount moves from reserved to collected in one atomic transaction, the
	basin's stock and annual counter move with it, and a fully collected claim closes. Collection
	is charged to the day it happens. The claim does NOT bypass collection-time validation: the
	designation must still be enabled, unprotected and in season, and the floor still binds.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if not claim_row_of_into(job_ref, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	var code: StringName = _check_collect(row, amount_milli, season, intensive)
	if code != REFUSE_NONE:
		return _refuse(code)
	_apply_collection(row, amount_milli)
	return _succeed(amount_milli, job_ref)


func _check_collect(row: int, amount_milli: int, season: int, intensive: bool) -> StringName:
	"""REFUSE_NONE when this claim may collect exactly `amount_milli` right now.

	Leaves the resolved designation, basin and patch rows in `_pending_*` for _apply_collection().
	"""
	if amount_milli <= 0 or amount_milli > _claim_remaining_milli[row]:
		return REFUSE_INVALID_AMOUNT
	var designation_ref: Vector2i = claim_designation_ref_of(row)
	var zone_code: StringName = _check_harvest_zone(designation_ref)
	if zone_code != REFUSE_NONE:
		return zone_code
	var kind: int = _claim_patch_kind[row]
	if not availability_per_1000_into(kind, season, _math_c):
		return StringName(_math_c.error)
	if _math_c.value == 0:
		return REFUSE_PATCH_DORMANT
	if not zone_slot_of_into(designation_ref, _math_c):
		return StringName(_math_c.error)
	_pending_designation_slot = _math_c.value
	if not patch_row_for_zone_into(designation_ref, kind, _math_c):
		return StringName(_math_c.error)
	_pending_patch_row = _math_c.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	if not harvest_floor_milli_into(_pending_patch_row, intensive, _math_c):
		return StringName(_math_c.error)
	if _patch_stock_milli[_pending_patch_row] - amount_milli < _math_c.value:
		return REFUSE_BELOW_HARVEST_FLOOR
	return _check_collect_quota(amount_milli, season)


func _check_collect_quota(amount_milli: int, season: int) -> StringName:
	"""Both daily limits still admit this collection, measured against collected totals alone.

	The amount is already inside `R`, so converting it to `H` leaves `Q - H - R` unchanged. What
	is checked is the limit itself. Every admission path guarantees `H + R <= Q`, so this can only
	fire where that invariant was not established here: a caller collecting under a DIFFERENT
	season than the boundary reconciled with meets a lower automatic quota, and restore_claim()
	writes a saved record with no preflight at all. Both must stop the collection rather than
	overshoot the limit.
	"""
	if not daily_quota_milli_into(_pending_basin_slot, season, _math_c):
		return StringName(_math_c.error)
	if _zone_harvested_today_milli[_pending_basin_slot] + amount_milli > _math_c.value:
		return REFUSE_QUOTA_REACHED
	if _pending_designation_slot == _pending_basin_slot:
		return REFUSE_NONE
	if not daily_quota_milli_into(_pending_designation_slot, season, _math_c):
		return StringName(_math_c.error)
	if _zone_harvested_today_milli[_pending_designation_slot] + amount_milli > _math_c.value:
		return REFUSE_QUOTA_REACHED
	return REFUSE_NONE


func _apply_collection(row: int, amount_milli: int) -> void:
	"""Ruling §4.2's collection transaction, in its stated order and with its `z == b` rule.

	Reserved falls and collected rises by the same amount on the basin, and again on the
	designation ONLY when it is a different row; stock falls and the annual counter rises once.
	A claim collected to zero closes, so its Job must reacquire before collecting again.
	"""
	var designation_slot: int = _pending_designation_slot
	var basin_slot: int = _pending_basin_slot
	_claim_remaining_milli[row] -= amount_milli
	_zone_quota_reserved_milli[basin_slot] -= amount_milli
	_zone_harvested_today_milli[basin_slot] += amount_milli
	if designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] -= amount_milli
		_zone_harvested_today_milli[designation_slot] += amount_milli
	_patch_stock_milli[_pending_patch_row] -= amount_milli
	_patch_harvested_year_milli[_pending_patch_row] += amount_milli
	if _claim_remaining_milli[row] == 0:
		_clear_claim_row(row)
		_claim_count -= 1


func release_claim(job_ref: Vector2i) -> OpResult:
	"""Release a Job's uncollected claim. Returns the row it occupied.

	R05-QUOTA-007's cancellation half. Releasing produces no WU, no XP, no cargo and no refund; it
	returns the uncollected quantity to both applicable allowances and nothing else. Cargo already
	collected under this claim is untouched.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if not claim_row_of_into(job_ref, _math):
		return _refuse(StringName(_math.error))
	var row: int = _math.value
	_release_claim_row(row)
	return _succeed(row, job_ref)


func _release_claim_row(row: int) -> void:
	"""Return one claim's uncollected quantity to both allowances and empty its row.

	A zone that no longer exists is skipped rather than written to: destroy_zone() already zeroed
	its totals, and the basin it drew from keeps its own usage either way.
	"""
	var amount: int = _claim_remaining_milli[row]
	var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
	var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
	if basin_slot != EntityDirectory.NULL_SLOT:
		_zone_quota_reserved_milli[basin_slot] -= amount
	if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
		_zone_quota_reserved_milli[designation_slot] -= amount
	_clear_claim_row(row)
	_claim_count -= 1


func _clear_claim_row(row: int) -> void:
	"""Return one claim row to exactly the state _clear_claim_columns() produces."""
	_claim_active[row] = 0
	_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_designation_slot[row] = EntityDirectory.NULL_SLOT
	_claim_designation_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_basin_slot[row] = EntityDirectory.NULL_SLOT
	_claim_basin_generation[row] = EntityDirectory.NULL_GENERATION
	_claim_patch_kind[row] = -1
	_claim_remaining_milli[row] = 0
	_claim_created_tick[row] = 0
	_claim_persistent_id[row] = 0


func _typed_zone_row_of(ref: Vector2i) -> int:
	"""The live HarvestZone row a reference names, or NULL_SLOT when it names none."""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_HARVEST_ZONE):
		return EntityDirectory.NULL_SLOT
	var slot: int = _directory.get_typed_row(ref)
	return slot if is_zone_present(slot) else EntityDirectory.NULL_SLOT


func release_claims_of_zone(ref: Vector2i) -> OpResult:
	"""Release every claim naming this zone as basin or designation. Returns how many went."""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_release_claims_of_zone_slot(_math.value), ref)


func _release_claims_of_zone_slot(slot: int) -> int:
	"""Release every claim naming this zone row, in ascending claim-row order."""
	var zone_ref: Vector2i = Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot])
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		var names_zone: bool = ((_claim_basin_slot[row] == zone_ref.x
				and _claim_basin_generation[row] == zone_ref.y)
			or (_claim_designation_slot[row] == zone_ref.x
				and _claim_designation_generation[row] == zone_ref.y))
		if not names_zone:
			continue
		_release_claim_row(row)
		released += 1
	return released


func purge_stale_claims() -> OpResult:
	"""Release every claim whose owning Job reference no longer validates. Returns how many.

	R05-QUOTA-023's housekeeping half: a Job destroyed without releasing its claim first leaves a
	row that must not survive into the next Job to occupy it. claim_forage() refuses such a row
	explicitly rather than reclaiming it silently, so this is the only path that clears it.
	"""
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		if _directory.is_valid_of_kind(claim_job_ref_of(row), EntityDirectory.KIND_JOB):
			continue
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func release_cancelled_claims() -> OpResult:
	"""R05-QUOTA-007: release the claims of Jobs that are cancelled or gone. Returns how many.

	The LEASE-EXPIRY half of that requirement is unreachable: jobs.gd records that `lease_expiry`
	exists, is always 0 and is never written because ARCH-JOB-004 is unimplemented. Nothing here
	invents an expiry rule to fire on.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		if not _claim_is_cancelled(row):
			continue
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func _claim_is_cancelled(row: int) -> bool:
	"""True when a claim's owning Job is gone, replaced, or in JobState CANCELLED."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return true
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.state_into(job_slot, _math_c):
		return true
	return _math_c.value == JobsScript.JOB_STATE_CANCELLED


# --- decision 0030 §4.5: reconciliation by whole claims, newest first ------------------------------

func reconcile_claims(season: int) -> OpResult:
	"""Release whole claims, newest first, until every applicable limit is satisfied.

	Ruling §4.5: `maximum_outstanding_claims = max(0, Q - H)`, and excess is removed by releasing
	WHOLE claims in `(job.created_tick, job.persistent_id)` DESCENDING order -- a job's promised
	collection is never silently shrunk. One global order serves every zone at once, so a claim
	over on either of its two applicable limits is released exactly once. Returns the count.
	"""
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	var released: int = 0
	while true:
		var row: int = _newest_over_claim(season)
		if row == NO_CLAIM:
			break
		_release_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func _newest_over_claim(season: int) -> int:
	"""The newest active claim whose basin or designation is over its allowance, or NO_CLAIM."""
	var best: int = NO_CLAIM
	var best_tick: int = 0
	var best_id: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or not _claim_is_over_allowance(row, season):
			continue
		var tick: int = _claim_created_tick[row]
		var persistent_id: int = _claim_persistent_id[row]
		if best != NO_CLAIM and not _key_is_newer(tick, persistent_id, best_tick, best_id):
			continue
		best = row
		best_tick = tick
		best_id = persistent_id
	return best


func _key_is_newer(tick: int, persistent_id: int, other_tick: int, other_id: int) -> bool:
	"""True when `(tick, persistent_id)` sorts strictly after `(other_tick, other_id)`."""
	if tick != other_tick:
		return tick > other_tick
	return persistent_id > other_id


func _claim_is_over_allowance(row: int, season: int) -> bool:
	"""True when this claim must go: its zone is gone, or a zone it names is over its allowance."""
	var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
	var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
	if basin_slot == EntityDirectory.NULL_SLOT or designation_slot == EntityDirectory.NULL_SLOT:
		return true
	if _zone_is_over_allowance(basin_slot, season):
		return true
	return designation_slot != basin_slot and _zone_is_over_allowance(designation_slot, season)


func _zone_is_over_allowance(slot: int, season: int) -> bool:
	"""True when a zone's outstanding total exceeds `max(0, Q - H)` for this season."""
	if not daily_quota_milli_into(slot, season, _math_c):
		return true
	var allowance: int = maxi(0, _math_c.value - _zone_harvested_today_milli[slot])
	return _zone_quota_reserved_milli[slot] > allowance


func claims_released_by_quota(ref: Vector2i, quota_milli: int, season: int)\
		-> IntMath.IntResult:
	"""How many whole claims a reduction to `quota_milli` would release on this zone.

	R05-QUOTA-015's number, without applying anything: the preview panel that would display it is
	the UI's and is not built here. Walks the same newest-first order §4.5 releases in.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_season(season):
		out.refuse(String(REFUSE_INVALID_SEASON))
		return out
	if not zone_slot_of_into(ref, out):
		return out
	var slot: int = out.value
	out.succeed(_count_claims_over(slot, maxi(0, quota_milli - _zone_harvested_today_milli[slot])))
	return out


func _count_claims_over(slot: int, allowance_milli: int) -> int:
	"""How many newest-first claims on one zone must go before its outstanding total fits.

	The walk descends the `(created_tick, persistent_id)` order by carrying the previously chosen
	key as an exclusive upper bound, so it needs no scratch list and mutates nothing.
	"""
	var outstanding: int = _zone_quota_reserved_milli[slot]
	var bound_tick: int = IntMath.INT64_MAX
	var bound_id: int = IntMath.INT64_MAX
	var count: int = 0
	while outstanding > allowance_milli:
		var row: int = _newest_claim_of_zone_below(slot, bound_tick, bound_id)
		if row == NO_CLAIM:
			break
		outstanding -= _claim_remaining_milli[row]
		bound_tick = _claim_created_tick[row]
		bound_id = _claim_persistent_id[row]
		count += 1
	return count


func _newest_claim_of_zone_below(slot: int, bound_tick: int, bound_id: int) -> int:
	"""The newest claim on one zone whose order key is strictly below `(bound_tick, bound_id)`."""
	var zone_ref: Vector2i = Vector2i(_zone_ref_slot[slot], _zone_ref_generation[slot])
	var best: int = NO_CLAIM
	var best_tick: int = 0
	var best_id: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1 or not _claim_names_zone(row, zone_ref):
			continue
		var tick: int = _claim_created_tick[row]
		var persistent_id: int = _claim_persistent_id[row]
		if not _key_is_newer(bound_tick, bound_id, tick, persistent_id):
			continue
		if best != NO_CLAIM and not _key_is_newer(tick, persistent_id, best_tick, best_id):
			continue
		best = row
		best_tick = tick
		best_id = persistent_id
	return best


func _claim_names_zone(row: int, zone_ref: Vector2i) -> bool:
	"""True when a claim names this exact zone reference as its basin or its designation."""
	if _claim_basin_slot[row] == zone_ref.x and _claim_basin_generation[row] == zone_ref.y:
		return true
	return (_claim_designation_slot[row] == zone_ref.x
		and _claim_designation_generation[row] == zone_ref.y)


# --- decision 0030 §4.4: the midnight boundary -----------------------------------------------------

func run_midnight(tick: int, season: int) -> OpResult:
	"""Apply the ruled quota order at one offset-calendar midnight. Returns claims released.

	The order is exactly §4.4's: reset collected totals, PRESERVE outstanding claims and their
	reservation totals, apply seasonal and automatic quota changes, release closure-invalidated
	claims and reconcile the excess -- and only then may a caller admit or collect again.

	`tick` must be a real crossing of `(tick + 4500) mod 18000`, taken from SimClock and never
	re-derived: tick 0 is 06:00 and the first midnight is tick 13500, so `tick % 18000 == 0` names
	06:00 of the next day and is refused here. Annual patch counters are NOT reset (that is
	reset_harvested_year(), at the year boundary), and no Job lease is renewed or extended.
	"""
	if tick < 0:
		return _refuse(REFUSE_INVALID_TICK)
	if not SimClock.is_day_boundary(tick):
		return _refuse(REFUSE_NOT_DAY_BOUNDARY)
	if not is_season(season):
		return _refuse(REFUSE_INVALID_SEASON)
	_zone_harvested_today_milli.fill(0)
	var closed: int = _release_closed_claims(season)
	var reconciled: OpResult = reconcile_claims(season)
	if not reconciled.ok:
		return reconciled
	return _succeed(closed + reconciled.value, NULL_REF)


func _release_closed_claims(season: int) -> int:
	"""Release every claim whose forage kind is dormant in the season now beginning.

	§5.5 makes an unavailable patch "dormant, not destroyed", and a dormant patch yields nothing,
	so a claim on one can never be collected and holds an allowance hostage until it is released.
	"""
	var released: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		if not availability_per_1000_into(_claim_patch_kind[row], season, _math_c):
			continue
		if _math_c.value != 0:
			continue
		_release_claim_row(row)
		released += 1
	return released


# --- decision 0030 §4.7: the load path and its derived aggregates ----------------------------------

func restore_claim(job_ref: Vector2i, designation_ref: Vector2i, kind: int,
		remaining_milli: int) -> OpResult:
	"""Write one saved claim record WITHOUT touching the derived reservation totals.

	R05-QUOTA-022's load half. A loader restores authoritative claim records and then calls
	rebuild_reservation_aggregates() before any admission or collection resumes; that is why this
	deliberately leaves `quota_reserved_milli` alone rather than maintaining it. It performs NO
	quota or stock preflight either: the world being restored already committed those. References,
	the patch kind and a positive quantity ARE validated, because a save that fails them must be
	refused rather than loaded.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	if remaining_milli <= 0 or remaining_milli > MANUAL_QUOTA_MAX_MILLI:
		return _refuse(REFUSE_INVALID_AMOUNT)
	var owner_code: StringName = _check_claim_owner(job_ref)
	if owner_code != REFUSE_NONE:
		return _refuse(owner_code)
	if not is_patch_kind(kind):
		return _refuse(REFUSE_INVALID_PATCH_KIND)
	if not zone_slot_of_into(designation_ref, _math):
		return _refuse(StringName(_math.error))
	_pending_designation_slot = _math.value
	if not patch_row_for_zone_into(designation_ref, kind, _math):
		return _refuse(StringName(_math.error))
	_pending_patch_row = _math.value
	_pending_basin_slot = _pending_patch_row / PATCHES_PER_ZONE
	var row: int = _directory.get_typed_row(job_ref)
	_write_claim(row, job_ref, designation_ref, kind, remaining_milli)
	return _succeed(row, job_ref)


func rebuild_reservation_aggregates() -> OpResult:
	"""Rebuild every derived quota total from the claim table. Returns the claims counted.

	Ruling §4.7: "For each zone, reconstruct its outstanding total by summing active claims for
	which it is the basin or designation, COUNTING A CLAIM ONCE when those references are
	identical." Every zone total is zeroed first, so a stale cache cannot survive as an addend,
	and the release-order keys are re-read from the owning Jobs at the same time.
	"""
	if _jobs == null:
		return _refuse(REFUSE_NO_JOB_STORE)
	_zone_quota_reserved_milli.fill(0)
	var counted: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if _claim_active[row] != 1:
			continue
		counted += 1
		_refresh_claim_order_key(row)
		var amount: int = _claim_remaining_milli[row]
		var basin_slot: int = _typed_zone_row_of(claim_basin_ref_of(row))
		var designation_slot: int = _typed_zone_row_of(claim_designation_ref_of(row))
		if basin_slot != EntityDirectory.NULL_SLOT:
			_zone_quota_reserved_milli[basin_slot] += amount
		if designation_slot != EntityDirectory.NULL_SLOT and designation_slot != basin_slot:
			_zone_quota_reserved_milli[designation_slot] += amount
	_claim_count = counted
	return _succeed(counted, NULL_REF)


func _refresh_claim_order_key(row: int) -> void:
	"""Re-read §4.5's release-order key from the owning Job, leaving it alone when the Job is gone."""
	var job_ref: Vector2i = claim_job_ref_of(row)
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return
	var job_slot: int = _directory.get_typed_row(job_ref)
	_claim_created_tick[row] = _jobs.created_tick_of(job_slot).value
	_claim_persistent_id[row] = _directory.get_persistent_id(job_ref)


func claim_payload_bytes() -> int:
	"""Packed bytes of the ForageClaim columns the ruling specifies, from their actual sizes."""
	return (_claim_active.size() * BYTES_PER_BYTE_COLUMN
		+ (_claim_job_slot.size() + _claim_job_generation.size()
			+ _claim_designation_slot.size() + _claim_designation_generation.size()
			+ _claim_basin_slot.size() + _claim_basin_generation.size()
			+ _claim_patch_kind.size()) * BYTES_PER_INT32
		+ _claim_remaining_milli.size() * BYTES_PER_INT64)


func quota_addition_bytes() -> int:
	"""Ruling §4.7's whole quota addition: the claim payload plus the three HarvestZone columns.

	It EXCLUDES decision 0026's separate 1024-byte basin reference and the ordering cache reported
	by extra_ordering_buffer_bytes(), exactly as R05-QUOTA-024 requires.
	"""
	return (claim_payload_bytes()
		+ (_zone_harvested_today_milli.size() + _zone_quota_reserved_milli.size())
			* BYTES_PER_INT64
		+ _zone_quota_mode.size() * BYTES_PER_BYTE_COLUMN)


func extra_ordering_buffer_bytes() -> int:
	"""The two release-order columns, counted OUTSIDE the ruling's payload total (header)."""
	return (_claim_created_tick.size() + _claim_persistent_id.size()) * BYTES_PER_INT64


# --- §5.5 work, REQ-SET-067 consent, REQ-SET-068 injury ------------------------------------------------------

func natural_danger_of(ref: Vector2i) -> IntMath.IntResult:
	"""§5.5's natural danger: the BASIN's band, "fixed at generation", before lookout reductions."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	natural_danger_of_into(ref, out)
	return out


func natural_danger_of_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating natural_danger_of(): write the basin's danger band into caller-owned `out`."""
	if not basin_slot_of_into(ref, out):
		return false
	return out.succeed(_zone_danger[out.value])


func work_per_u(kind: int, forage_level: int, natural_danger: int) -> IntMath.IntResult:
	"""§5.5: `ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))` WU/U."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	work_per_u_into(kind, forage_level, natural_danger, out)
	return out


func work_per_u_into(kind: int, forage_level: int, natural_danger: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating work_per_u(): write the whole-WU cost of one unit into caller-owned `out`."""
	if not is_patch_kind(kind):
		return out.refuse(String(REFUSE_INVALID_PATCH_KIND))
	if forage_level < 0 or not IntMath.fits_int32(forage_level):
		return out.refuse(String(REFUSE_INVALID_SKILL_LEVEL))
	if natural_danger < DANGER_MIN or natural_danger > DANGER_MAX:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	var skill_term: int = WORK_BASE_TERM + WORK_SKILL_TERM * forage_level
	var danger_term: int = WORK_BASE_TERM + WORK_DANGER_TERM * natural_danger
	if not IntMath.checked_mul_into(PATCH_BASE_WORK_WU[kind], WORK_NUMERATOR_SCALE, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	var numerator: int = out.value
	if not IntMath.checked_mul_into(skill_term, danger_term, out):
		return out.refuse(String(REFUSE_OVERFLOW))
	return IntMath.ceil_div_into(numerator, out.value, out)


func requires_dangerous_work(ref: Vector2i) -> bool:
	"""REQ-SET-067: true while this zone's own danger band is 2 or 3."""
	if not zone_slot_of_into(ref, _math_b):
		return false
	return _zone_danger[_math_b.value] >= DANGEROUS_WORK_DANGER


func check_worker_permitted(ref: Vector2i, dangerous_work_consent: bool) -> OpResult:
	"""REQ-SET-067's consent half: refuse a danger 2/3 zone without the resident's permission.

	The requirement's "show an exposure warning" is the Notice store's half and is not done here.
	Returns the zone's danger band on success.
	"""
	if not zone_slot_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var danger: int = _zone_danger[_math.value]
	if danger >= DANGEROUS_WORK_DANGER and not dangerous_work_consent:
		return _refuse(REFUSE_DANGEROUS_WORK_REFUSED)
	return _succeed(danger, ref)


func injury_chance_per_10000(natural_danger: int, forage_level: int) -> IntMath.IntResult:
	"""REQ-SET-068's `max(1, 8*danger - FORAGE_level)` per 10000."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	injury_chance_per_10000_into(natural_danger, forage_level, out)
	return out


func injury_chance_per_10000_into(natural_danger: int, forage_level: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating injury_chance_per_10000(): write the per-10000 chance into `out`."""
	if natural_danger < DANGER_MIN or natural_danger > DANGER_MAX:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	if forage_level < 0 or not IntMath.fits_int32(forage_level):
		return out.refuse(String(REFUSE_INVALID_SKILL_LEVEL))
	var chance: int = INJURY_DANGER_FACTOR * natural_danger - forage_level
	return out.succeed(maxi(INJURY_CHANCE_MINIMUM, chance))


func completed_exposure_segments(before_wu: int, after_wu: int) -> IntMath.IntResult:
	"""How many whole 60 WU exposure segments a worker crossed between two work totals.

	ARCH-RNG-002 orders the FORAGE stream by "Worker ID, segment sequence", so the accumulated
	work total belongs to the worker and is passed in; this store keeps no per-worker column,
	because GDD §4.2 gives exposure work no field on any row.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	completed_exposure_segments_into(before_wu, after_wu, out)
	return out


func completed_exposure_segments_into(before_wu: int, after_wu: int,
		out: IntMath.IntResult) -> bool:
	"""Non-allocating completed_exposure_segments(): write the segment count into `out`."""
	if before_wu < 0 or after_wu < before_wu:
		return out.refuse(String(REFUSE_INVALID_WORK))
	if not IntMath.fits_int32(after_wu):
		return out.refuse(String(REFUSE_INVALID_WORK))
	return out.succeed(after_wu / EXPOSURE_SEGMENT_WU - before_wu / EXPOSURE_SEGMENT_WU)


func roll_injury_into(rng: Rng, natural_danger: int, forage_level: int,
		out: IntMath.IntResult) -> bool:
	"""One FORAGE hazard roll: exactly one draw, 1 when it injures and 0 when it does not.

	REQ-SET-068 states the chance "per 10000", so a draw in [0, 10000) injures when it is
	strictly below the chance -- exactly `chance` of the 10000 outcomes. Refuses at natural
	danger 0 without drawing, because ARCH-RNG-002 rolls only "in natural danger>=1" and a
	consumed draw there would desynchronise every later replay.
	"""
	if rng == null:
		return out.refuse(String(REFUSE_NO_RNG))
	if natural_danger < INJURY_ROLL_MIN_DANGER:
		return out.refuse(String(REFUSE_INVALID_DANGER))
	if not injury_chance_per_10000_into(natural_danger, forage_level, out):
		return false
	var chance: int = out.value
	if not rng.draw_below_into(Rng.STREAM_FORAGE, INJURY_ROLL_DENOMINATOR, out):
		return false
	return out.succeed(1 if out.value < chance else 0)


func roll_exposure_injuries(rng: Rng, ref: Vector2i, forage_level: int, before_wu: int,
		after_wu: int) -> OpResult:
	"""ARCH-RNG-002's FORAGE discipline for one worker's run of work. Returns injuries rolled.

	Exactly one draw per completed 60 WU segment, in segment order, and NO draws at all when the
	basin's natural danger is 0. Applying REQ-SET-068's "10 health loss and severity 1 injury" is
	the injury store's job; INJURY_HEALTH_LOSS and INJURY_SEVERITY carry the numbers.
	"""
	if not natural_danger_of_into(ref, _math):
		return _refuse(StringName(_math.error))
	var danger: int = _math.value
	if not completed_exposure_segments_into(before_wu, after_wu, _math):
		return _refuse(StringName(_math.error))
	var segments: int = _math.value
	if danger < INJURY_ROLL_MIN_DANGER:
		return _succeed(0, ref)
	var injuries: int = 0
	for _segment: int in segments:
		if not roll_injury_into(rng, danger, forage_level, _math):
			return _refuse(StringName(_math.error))
		injuries += _math.value
	return _succeed(injuries, ref)


# --- result helpers -----------------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)
