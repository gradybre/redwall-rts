# 0048 — World generation: the anchor it derives, and the eight things it refuses to invent
Date: 2026-09-10 · Status: Accepted
Implements REQ-SET-009 and task [04.3](../tasks/04_world_commands.md)'s terrain/ecology half in
`godot/scripts/core/world_init.gd`. Consumes decisions
[0026](0026-forage-patches-belong-to-the-basin.md),
[0029](0029-deposits-are-sixteen-nodes.md),
[0031](0031-a-deposit-declares-what-it-may-replace.md) and
[0037](0037-fishing-effort-is-claimed-by-the-cycle.md) unchanged.

## What this closes

Task 03's own preamble: *"There is nothing in the world for a FARM, FORAGE or FISH job to
reference."* Every ecology store was built, tested and orchestrated, and every one was **empty**.
A `DESIGNATE_ZONE` command had no basin to target, the ecology boundary had nothing to advance, and
`rng.gd` was composed unseeded, so the second season's first midnight refused `RNG_NOT_SEEDED`.

After `world_init.generate()`, the shipping estuary holds **1695 resource nodes, seven ecology
basins, nine fish stocks and nine seeded RNG streams**, and a `DESIGNATE_ZONE` targeting one of the
four forest basins commits, binds and produces one real FORAGE job through ARCH-SYS-009.

FARM is **not** closed: §5.1 authors no starter `FarmPlot`, and a plot is created by a player FARM
designation, which is task 04.4/05's.

## 1. The validation anchor is derived, not chosen

§5.1's generator guarantees are distances — "one river edge within 24 m, one forest zone within
32 m, 64 loam tiles within 24 m, a 1200 U wood stock and 1200 U stone deposit within 48 m,
renewable saplings, and an iron deposit within 80 m" — from an origin it names only as **map
center**: *"The starter hall and resource placement fit a 32 m radius of map center."*

On a 128×128 grid "map center" has two readings, and **they disagree on §5.1's own first
guarantee**:

| Reading | Origin, in simulation units | Nearest river tile (x=76) | Distance | 24 m guarantee |
|---|---:|---:|---:|---|
| Geometric mid-POINT of the map | 131072 | 156672 | 25600 units = **25 m** | **FAILS** |
| Centre of TILE (64,64) | 132096 | 156672 | 24576 units = **24 m** | passes, at equality |

One metre. Only the tile reading makes §5.1's guarantee satisfiable on §5.1's own geometry, so the
anchor is **tile (64,64)** and distances are measured tile centre to tile centre. That is arithmetic
on the authored numbers, not a preference, and `test_the_validation_anchor_puts_the_river_at_exactly_24_metres`
pins both halves of the table.

The starter **hall**'s exact footprint is still task 06's. §5.1 constrains it to within 32 m of this
anchor and never places it.

## 2. Natural danger is computed from that anchor, and its residual is stated

§5.5 fixes `HarvestZone.danger` "at generation" as "the basin center's distance category", with
bands "1 remaining land within 64 m of the central hall; 2 at 64–96 m; 3 beyond 96 m". Band 0 needs
a **staffed lookout**, of which a new world has none.

Two things §5.5 leaves open are settled here and recorded rather than buried:

- **"The basin center" of a basin with a hole in it** is its bounding-box centre. The east forest
  basin excludes the lake, so its centroid is not its bounding-box centre. Distances are compared
  in **half-tile units**, which removes the rounding decision entirely: a bounding-box centre can
  land on a half tile and never needs a rounding rule to be invented for it.
- **The band is measured from the map-centre anchor, not from the hall**, because the hall is
  blocked. All seven basins land at 39–113 half-tiles and none is within **five half-tiles** of a
  band edge, so the band is stable for a hall placed within about four tiles of the anchor — and it
  is **NOT** proved for the full sixteen-tile latitude §5.1's 32 m radius allows. That residual is
  real and belongs to task 06.

Result: the four forest basins are band **2**, the coast **3**, the lake **2**, the river **1**.

## 3. Five readings of §5.1 that could have gone the other way

**"Forest masks" are the forest ecology basins.** §5.1 puts tree centres "in forest masks" and
defines a forest nowhere else in tiles — the macro map's `F` cells are explicitly overridden by
"Exact tile masks and coordinates above override this coarse overview". The reading is confirmed by
construction: both ore footprints fall inside the west rectangle and each covers exactly four tree
centres, which is what gives §5.1's "Ore footprints replace tree nodes" anything to replace.

**"Every second x/every second z" is even x and even z.** The mask-relative reading (count from each
mask's first column) and the global-parity reading COINCIDE, because all four mask bounds — x=8,
x=82 and z=20 twice — start on even coordinates. The ambiguity is not load-bearing on this map.

**The grove places exactly 100 NEW nodes.** "Add a guaranteed grove of 100 trees … skipping
duplicate centers and all cleared aprons; replace any skipped center at the lowest unused land tile
inside x=36..49,z=50..67 until exactly 100 guaranteed nodes exist." A skipped tile already carries a
centre, so counting it toward the 100 would make "replace any skipped center" do nothing. 25 of the
grove's 100 tiles are centres, so **75 land in the grove and 25 relocate** — to the seven odd
columns of z=50, all fourteen of z=51 and four of z=52, in ascending tile order.

**The basins split north = z < 62, south = z ≥ 62.** §5.1 says "split at z=62" and the macro map's
"N is decreasing Z" fixes which side is north. The alternative — an even 43/43 split at z ≤ 62 /
z ≥ 63 — is the rounder-looking one and is not what the text says. The partnership itself has **no
live representation**: `migration_link` is a `FaunaStockReserved` column and REQ-SET-059 pins every
one of its numeric fields at 0, so nothing writes a partner reference.

**The basins are created `enabled = false`.** §5.1's closing rule — "All other initial fields follow
the registry zero/null defaults unless a catalog specifies a different value" — and no catalog
specifies a `HarvestZone` default. All three of `quota_milli` 0, `protected` false and `enabled`
false are **inert on a basin** under every current reader: `job_planner.gd`'s enabled/protected gate
and `forage.gd`'s harvest gate both read the DESIGNATION's row, and a basin fails `is_designation()`
before either matters. **The hazard is recorded here rather than papered over with a friendlier
invented `true`:** a future reader that treats a disabled basin as a closure would silently stop
ecology, and this paragraph is where it should be caught.

## 4. Allocate before consume, at world scale

Task 04.3: *"Failed initialization retains the previous valid world and reports the exact failed
assertion."* The implementation is structural, not a rollback:

- `_prepare()` writes the entire terrain/soil/basin/clearing/tree plan into **staged** columns and
  only READS the collaborating stores, for capacity.
- `_validate()` measures the staged plan against §5.1's guarantees.
- `_publish()` is the first statement that mutates anything outside the object.

So a refused generation leaves every store byte-identical **because nothing wrote to them**, not
because an undo ran. The published map is double-buffered and publishing **swaps** the two
allocations, so no `resize()` happens outside `_init()` and a failed generation cannot have touched
the published map either. `_publish()` still inspects every `OpResult` and asserts: that assert is a
drift guard on the preflight above it, not an error path.

One consequence is worth stating plainly. **`_prepare()` refuses `WORLD_FOREIGN_LIVE_ROWS` when any
directory kind this generator was not given has live rows**, naming the kind. Publishing clears the
`EntityDirectory`, and a row owned by an unknown store would lose its identity silently. A refusal
is recoverable; an orphaned resident is not.

`EntityDirectory.clear()` deliberately never resets a generation (ARCH-ID-002). Two worlds generated
into two FRESH directories therefore agree on every reference; a world regenerated into a USED
directory holds identical content under NEWER references. Both are tested, separately, because they
are different claims.

## 5. Which §5.1 guarantees are validated, and which are blocked

Task 04.3: *"Validate … reachability using task 05's topology once available. Before that mark
topology assertions blocked."*

| §5.1 guarantee | Straight-line check | Reachability |
|---|---|---|
| one river edge within 24 m | **validated** (exactly 24 m) | **BLOCKED — task 05** |
| one forest zone within 32 m | **validated** (30 m) | **BLOCKED — task 05** |
| 64 loam tiles within 24 m | **validated** | **BLOCKED — task 05** |
| 1200 U wood stock within 48 m | **validated** | **BLOCKED — task 05** |
| 1200 U stone deposit within 48 m | **validated** (whole footprint) | **BLOCKED — task 05** |
| renewable saplings | **validated** as every tree node carrying §5.9's 48-day period | n/a |
| an iron deposit within 80 m | **validated** (58 m) | **BLOCKED — task 05** |

"Renewable saplings" has a second reading — §5.7's nursery sapling propagation — which is milestone
M3 content and not a property of terrain. §5.1 lists the phrase among *terrain generator* validation
guarantees, so the terrain reading is taken and the alternative is named in the module header.

Each guarantee has its own refusal code, and `validate_measurements()` is a **pure** function of a
measured tuple, so every assertion AND the order §5.1 lists them in is testable without a map.

§5.1's "rejects generation after at most 16 seed attempts" is implemented literally, including
"Invalid seeds are rejected and regenerated with seed+1". Because the authored geometry is
seed-independent, sixteen attempts return the same assertion sixteen times — which is exactly
§5.1's "the authored geometry makes repeated topology failure an implementation error, not an
endless retry", and the caller sees the assertion, never a generic "gave up".

## 6. What is refused rather than invented

1. **The 12-resident fixture, the starter hall, beds, containers and equipped tools.** 04.3 permits
   pulling task 06's building/furniture/container slice forward "if the contracts remain open, mark
   full initialization blocked; do not substitute unlimited piles, fictional beds, duplicated tools
   or unregistered inventory owners". **No Building, Furniture or Container store exists.** FULL
   INITIALIZATION IS BLOCKED and none of it is built.
2. **The cleared building footprints and their one-tile apron.** §5.1 says to clear them; it gives
   no footprint coordinates anywhere. Only the authored loam rectangle `x=58..65,z=46..53` is
   cleared, and `is_cleared_at()` answers for that alone.
3. **The renewable bedrock access at (48,70).** Named by §5.1, in neither ore total per decision
   0029, and given no quantity, regrow period or footprint by any document. The coordinates are
   constants; the tile carries the ordinary tree centre its even/even position earns it and no
   invented ore node.
4. **The arrival/departure exit (64,126).** Recorded as constants. §5.1 joins it to the hall "by
   ordinary land navigation"; there is no navigation graph (ARCH-SYS-011) and no hall.
5. **Any FarmPlot, OrchardPlot or Hive.** §5.1's initial conditions list buildings, inventory and
   residents, and no plot, block or apiary. `farming.gd` and `orchard_hive.gd` are RESET and
   populated with nothing.
6. **Any Job, and `job_planner.gd` is not called.** `JOB_STATE_WORK` is never written here.
7. **A save round trip.** Task 09 owns the codec; nothing here serialises.
8. **A regrow period for stone or iron.** §5.9 gives trees 48 days and states none for ore;
   `resource_nodes.gd` documents 0 as "never regrows" and that encoding is used rather than a
   fabricated period. Decision 0031's `replaceable_resource_id` is the TREE id, because §5.1
   authorises replacing tree nodes and nothing else.

`FaunaStockReserved` is the one reserved row that IS allocated: §4.2 fixes its contents ("all
numeric fields 0, refs (-1,0), no active rows or updates") and `systems_architecture.md` §2.2 fixes
its length at 384 rows, so the allocation is fully specified. It lives in `world_init.gd` with **no
mutator anywhere**, because SET-AMEND-001 §3 retired hunting and REQ-SET-059 forbids a live row —
a store would imply operations that must never exist.

## 7. Basin geometry is a tile column, not 6267 zone links

Decision 0026's amendment left this open: "the planner may still prefer derivation", and noted that
"the 16384-link-budget objection applies only to the variant that registers ~6880 tiles as zone
links". Registering the seven basins' tiles as `HarvestZone` links would consume **9252 of §4.2's
16384 total zone links** before the player draws a single designation.

`world_init.gd` therefore owns a **tile → basin byte column** and exposes `basin_ref_for_tile()`.
That is R05-BASIN-003's map side — "binding shall be validated to agree with the actual harvesting
location" — at O(1), it costs no zone link, and the whole 16384-link arena stays available to the
player. The ford falls out of it for free: `is_fishing_work_tile()` is false there because §5.1 says
the ford "is not a fishing work tile", so it belongs to no basin.

## 8. A stale figure found in ARCH-MEM-010

The ARCH-MEM-009 trail **reconciles row by row**: every running total is the one above it plus its
own delta, from 57713254 to 59656914, and the reserve column is the payload plus 8388608 at both
ends. Checked line by line before adding to it.

ARCH-MEM-010's prose is stale. It says "Re-adding those rows as printed gives **60004434**, which is
**437632** higher". 60004434 − 59656914 is 347520, not 437632. The 437632 gap was computed against
decision 0043's carried total of 59566802; decisions 0044 (+49152) and 0045 (+40960) then raised the
carried total to 59656914 **and the printed rows with it**, but the 60004434 figure was not updated.
The correct current row sum is **60094546**, and the 437632 gap is unchanged. The figure is
corrected in place with a dated note; every conclusion in that paragraph, and every derived metric,
is untouched by it. This is exactly the silent-drift failure that paragraph exists to prevent, so
leaving it would have been the worse option.

## Packed payload

`world_init.gd` adds **159968 bytes**: nine 16384-byte tile columns (published and staged terrain,
soil, basin and clearing, plus the staging occupancy mask), four 7-entry i32 basin columns
(published and staged danger, basin reference slot and generation), the 3000-entry tree-centre plan
and the 100-entry grove plan. `FaunaStockReserved`'s 15360 bytes are NOT added: §2.2 already carries
them, and this is the allocation that row describes.

## Evidence

`./tools/run_tests.sh` on this change: **1947 tests, 56433 assertions, 0 failures**. The measured
baseline on `origin/master` (0b3781b) immediately before it was **1871 tests, 47370 assertions, 0
failures**, confirmed twice — once before any file was written and once with the three new files
moved out of the tree.

**73 mutation runs, one mutation per suite invocation**, each restored from a pristine copy and
`shasum -a 256` byte-compared before the next was applied, with a 900-second per-run timeout and the
failure count parsed as an INTEGER (a substring test for `"0 failure(s)"` matches `"10 failure(s)"`
and manufactures a phantom survivor). 69 distinct mutants: every authored §5.1 constant moved by one,
the mask precedence order, the soil precedence order, the 3000 cap's tie-break, the grove replacement
loop's used-tile guard, the publish/rollback boundary, the seeding call, the habitat binding, the ore
deposit's declared replaceable occupant and the foreign-live-row guard.

**65 killed on the first pass; four survived and all four were killed by adding the missing test,
not by declaring equivalence:**

| Mutant | Why it survived | Test added |
|---|---|---|
| `RIVER_FIRST_Z` 16 → 17 | the river's first row was never asserted, only the coast tile above it | `test_river_mask_boundary` now pins `(77,16)` as RIVER |
| `if attempt + 1 == MAX_SEED_ATTEMPTS` → `== 0` | removing the sixteenth attempt's early return changes nothing unless that attempt's seed+1 would overflow | `test_the_sixteenth_attempt_returns_without_a_seventeenth_advance`, started fifteen below the int64 ceiling |
| the `WORLD_GROVE_INCOMPLETE` guard → `if false` | unreachable on the authored map, which always reaches 100 | a `ShortGroveWorld` subclass overriding one method, the device `test_command_dispatch.gd` and `test_forage.gd` already use |
| `written >= keep` → `written >= out.size()` | the two agree whenever the cap equals the buffer size, which both existing calls did | `collect_tree_centres_into(5, buffer_of_3000)` must still return 5 |

After those four tests, **73/73 mutants killed, no survivor and no declared equivalent.**

## Source
Task 04.3, 2026-09-10. GDD §5.1, §5.4, §5.5, §5.9, §4.2, §4.3; REQ-SET-009 and REQ-SET-059.
