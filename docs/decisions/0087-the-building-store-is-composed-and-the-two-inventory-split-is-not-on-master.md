# 0087 — The Building/Room/Furniture store is composed into the settlement, and the two-inventory split is not on `master`
Date: 2026-09-12 · Status: Accepted

## Decision

Two parts, and they landed very differently.

**1. `settlement_system.gd` now constructs `buildings.gd`.** Decision 0080 landed the packed
Building, Room and Furniture stores complete and named the exact call it deliberately did not
make. That call is made:

```gdscript
const BuildingsScript := preload("res://scripts/core/buildings.gd")
var _buildings: BuildingsScript = null
# _init():        _buildings = BuildingsScript.new(_directory)
# _clear_stores(): _buildings.clear()
```

plus two accessors (`buildings()`, `building_definitions()`) and two composition assertions (the
store shares this settlement's directory; its tile grid is `world_init.gd`'s 128 x 128 grid).
Nothing else was required — the store allocates every column in `_init()`, and its `clear()`
releases only its own directory rows when the directory is shared.

**2. The two-inventory split is NOT present on `master` and was therefore not "fixed" here.**
It is introduced by PR #58 (`feat/stock-age`), which is open and unmerged. On `master` there is
exactly ONE stock-bearing `inventory.gd` instance in the running game — `economy_system.gd`'s —
`settlement_system.gd` composes none, `godot/scripts/core/stock_age.gd` does not exist, and
`inventory.gd` publishes no age-advance API at all. No `docs/decisions/0085-*.md` exists on
`master` either. Nothing was invented to make the defect appear so it could be repaired.

## Why

### Why the composition is exactly this and nothing more

**The shared directory IS the change.** A `Buildings` built with its own allocator would compile,
place buildings, count beds and pass its own suite — and would refuse every `set_furniture_user()`
for a real resident, because no resident would live in that directory. Verified both ways:
`set_furniture_user(bed, residents().ref_of(0))` succeeds and reads back the very reference
`residents()` published, while a live `KIND_HARVEST_ZONE` row from the same directory is refused
`STALE_USER_REF`. The shared directory is a *validator*, not just a common pool.

**`clear()` goes in `_clear_stores()` next to the ecology's, and the order is safe for the same
reason the ecology's is.** `_residents.clear()` runs first and clears the directory, so by the
time `_buildings.clear()` runs its `destroy()` calls hit stale references and return `false`.
`EntityDirectory.clear()` rebuilds both free heaps wholesale, so no slot is stranded either way.
This is `resource_nodes.gd`'s existing pattern, not a new one. One consequence is recorded in
Evidence: the shared-directory guard is *not* observable through `SettlementSystem`, and its
store-level test is what pins it.

**No stage was added to the tick or to the day boundary.** The store is structural state edited
by placement and demolition. ARCH-SYS-016 RoomHeat is the only §5 stage that would read it and it
still has no connected-heat model, so `run_tick()` and `run_day_boundary()` are unchanged and
`tick_stage_count()` is still 7.

**The §5.9 container masses were checked against the store instead of being replaced by it.**
`economy_system.gd` opens its two containers at 200000 g and 1600000 g, copied from a §5.9
sentence because nothing published a building's declared capacity. `building_definitions.gd` does
now: `base_store_g_of(open_stockpile)` is 400000 and §5.1 starts with four, which is exactly
1600000; `shelf_capacity_g_of(shelf)` is 50000 and §5.9's pantry has four, which is exactly
200000. Both agreements are asserted as tests. **The constants are not derived from the lookup**,
because §7.2's starter build does not exist and zero placed stockpiles would open a zero-gram
store. An assertion catches drift; a derivation would have produced an empty settlement.

### Why part 2 is a report and not a patch

Three findings, each checked against the code rather than the brief:

1. `grep -rn "StockAge\|stock_age" godot/` on `master` returns exactly one hit — a comment in
   `settlement_system.gd` saying ARCH-SYS-004 has no owner. `godot/scripts/core/stock_age.gd`
   does not exist.
2. `settlement_system.gd` on `master` contains no occurrence of the string `nventory`.
3. `git diff origin/master origin/feat/stock-age` is where all of it lives: +728 lines of
   `stock_age.gd`, +268 lines on `inventory.gd`, +171 on `settlement_system.gd`, and decision
   0085 itself. That branch's `settlement_system.gd` composes `InventoryScript.new()` in `_init()`
   and its own header states the defect in terms.

So the starter food does not age on `master`, but not for the reason the brief gives: **nothing
ages anything on `master`, because the ager does not exist.** Building the missing half in order
to repair it would have meant reimplementing an open PR's 1100 lines inside a task that owns
neither, and would have collided head-on with that PR's own 171-line diff to the same file.

**The fix, when #58 merges, and why its direction is available.** The previous agent recorded that
a `_ready()` bind was unavailable because `SettlementSystem` is constructed before
`EconomySystem`. That ordering is real and it makes the OPPOSITE direction available, which is
the one that is wanted. `project.godot` orders the autoloads EntityManager, GameManager,
**SettlementSystem, EconomySystem**, UIManager, and every suite run prints them ready in exactly
that order. So:

* `EconomySystem` should ADOPT the settlement's `inventory.gd` instance rather than composing a
  second one — `bind_inventory(store)`, defaulting to its own private store so a test-built
  instance still touches no autoload state.
* The call belongs in `scripts/main.gd`, beside the `EconomySystem.bind_residents(
  SettlementSystem.residents())` that is already there and has exactly this shape. A scene-level
  composition root reaching two autoloads is not an autoload reaching another autoload, and no
  test-built `SettlementSystem` or `EconomySystem` is affected.
* **One wrinkle must be handled, not discovered later:** `EconomySystem.reset()` calls
  `_inventory.clear()`, which on a BORROWED store would destroy the settlement's lots. A bound
  economy must drop the binding instead of clearing it — the rule `bind_residents()` already
  follows for its borrowed residents store.
* No construction-order change is needed and none is requested.

The cleanest place for that change is inside PR #58, before it merges, since it is that PR's own
`settlement_system.gd` diff that creates the second store.

## Consequences

* **Composition is not construction.** `live_building_count()`, `live_room_count()` and
  `live_furniture_count()` are 0 after `create_generated_settlement()` exactly as before it.
  `world_init.gd` clears §5.9's seven authored footprints (decision 0060) and places no building
  in them. A `Beds` HUD counter wired to `live_furniture_of_kind(bed)` today reads a TRUE 0.
  `test_a_generated_settlement_still_places_no_building_and_counts_no_bed` pins that so no later
  reader mistakes the one for the other.
* **The §7.2 starter settlement is still outstanding, and five distinct things block it** (see
  the list under Source). None of them was worked around here.
* **`gear.gd` still has no production caller.** `seed_starter_tools()` can now be given a real
  container owner — `place_building(open_stockpile)` publishes the Building row and
  `base_store_g_of()` states the 400000 g the container should be created with — but nothing in
  `godot/scripts/` constructs `gear.gd` at all, so the §5.9 starter tools are still unseeded in
  the running game.
* **Memory is now actually allocated in the running game for decision 0080's columns**, which
  makes its eight unreconciled §3 ledger rows load-bearing rather than prospective. They are
  reproduced below and are still NOT edited in; `systems_architecture.md` and
  `docs/validation/ready07_arithmetic.py` are byte-untouched and the latter still passes at 141
  field rows / 24 allocation rows.

### Memory ledger rows still required (decision 0080's, unreconciled, totalling 1 885 220 bytes)

| Table | Columns | Type | Width | Cols | Length | Bytes |
|---|---|---|---:|---:|---:|---:|
| BuildingIndex | `present` | B8 | 1 | 1 | 1024 | 1024 |
| BuildingIndex | `ref_slot, ref_generation, room_head, room_count` | I32 | 4 | 4 | 1024 | 16384 |
| RoomIndex | `present` | B8 | 1 | 1 | 16384 | 16384 |
| RoomIndex | `ref_slot, ref_generation, building_next, building_prev, furniture_head, furniture_count` | I32 | 4 | 6 | 16384 | 393216 |
| FurnitureIndex | `present` | B8 | 1 | 1 | 81920 | 81920 |
| FurnitureIndex | `ref_slot, ref_generation, room_next, room_prev` | I32 | 4 | 4 | 81920 | 1310720 |
| WorldTileMaps | `furniture_slot` (a FIFTH column on the existing four-column row) | I32 | 4 | 1 | 16384 | 65536 |
| FurnitureKindCount | `kind_count` | I32 | 4 | 1 | 9 | 36 |

`docs/persistence_state_registry.md` already carries every one of these columns under
`godot/scripts/core/buildings.gd`, so `state_registry_coverage.py` passes unchanged; it is
`systems_architecture.md` §3 that is missing the rows.

### A numbering collision to reconcile by hand

`docs/decisions/` contains **two files numbered 0080** —
`0080-asset-save-and-focus-engineering-contracts.md` and
`0080-the-packed-building-room-and-furniture-stores.md`. Reported rather than renamed: renaming
either breaks every existing cross-reference, and this task does not own the numbering.

## Evidence

`./tools/run_tests.sh`: **2997 tests, 103959 assertions, 0 failures** (baseline on `origin/master`
in a fresh worktree: 2985 / 103903 / 0). `state_registry_coverage.py`: PASS, 41 modules, 307 rows,
625 packed columns. `ready07_arithmetic.py`: PASS, 141 field rows, 24 allocation rows.

Seven single-line mutations, one per invocation, each restored and `shasum -a 256`-compared
against a pristine copy. `buildings.gd` and `economy_system.gd` are byte-identical to
`origin/master` afterwards, verified by `shasum` against `git show origin/master:...`.

| # | Mutation | File | Result |
|---|---|---|---|
| M1 | `Buildings.new(_directory)` -> `Buildings.new()` (private directory) | settlement_system | **killed, 113** |
| M2 | `_buildings.clear()` removed from `_clear_stores()` | settlement_system | killed, 1 |
| M3 | `if _owns_directory:` guard removed from `clear()` | buildings | killed, 1 |
| M4 | `buildings()` returns a fresh `Buildings.new(_directory)` per call | settlement_system | killed, 6 |
| M5 | `MATERIAL_STORE_MAX_MASS_G` 1600000 -> 1200000 | economy_system | killed, 19 |
| M6 | `PANTRY_MAX_MASS_G` 200000 -> 250000 | economy_system | killed, 1 |
| M7 | `clear()` stops releasing its own live BUILDING rows | buildings | killed, 1 |

M3 and M7 are the shared-directory contract the brief asked to be pinned specifically. Both are
killed by `test_a_shared_directory_is_not_cleared_by_this_store` in `test_buildings.gd`, and by
that test alone. **Neither is observable through `SettlementSystem`**, and that is a property of
the composition rather than a gap in the new tests: `_residents.clear()` clears the directory
before `_buildings.clear()` is reached, so a store that wrongly cleared a shared directory, and a
store that wrongly kept its rows, both produce the same empty directory at settlement level. The
store-level test is the only place either can be seen, which is why it must not be weakened.

M1's 113 failures are the `_assert_shared_contracts()` assertion aborting every method in the
suite, so it is a blunt kill; M4 is the sharp one, and it fails exactly the six new tests that
depend on the store's identity and state continuity.

## Source

Decision 0080 (`buildings.gd`, its "What is deliberately NOT implemented" list, and its
unreconciled ledger rows); decision 0074 / `docs/rulings/2026-09-11_building_room_domains.md`
(R-BUILD-DOM-001 to 004); decision 0075 / R-INIT-ID-001 (the cohort takes ids 1-12 before the
world — re-asserted here after a building is placed); decision 0060 (`world_init.gd` clears §5.9's
footprints and creates no building); decision 0059 (allocate before consume); GDD §4.1-4.3, §5.1,
§5.9, §5.11 and its `R-BUILD-DOM-001 mask binding` paragraph ("Active new worlds start with
M0=0 and both masks=1"); `gameplay_balance.md` BAL-CAT-006 (`open_stockpile` base_store_g 400000,
shelf 50000), BAL-RATIO-010 (one hearth heats 120 connected interior tiles), BAL-BUILD-001;
`docs/tasks/06_buildings_rooms_logistics.md`'s 2026-09-11 note ("neither is composition into
`settlement_system.gd`"); PR #58 `feat/stock-age` and its decision 0085, read from
`origin/feat/stock-age` and left untouched.

### What the §7.2 starter settlement still needs, itemised

Each is a real blocker found by trying to reach it, not a guess:

1. **An owner.** `world_init.gd` owns §5.1's geometry and clears the seven authored footprints
   (hall 12x10 at (58,59), four 4x4 stockpiles, the 2x2 well, the 3x3 workbench shelter) but
   places nothing in them. Whether the starter build belongs to `world_init.gd`'s transaction or
   to a new step in `create_generated_settlement()` is unassigned.
2. **A store for the unlock mask.** `place_building()` requires `unlocked_mask` and refuses mask
   0 outright. §5.11 authors the value — "Active new worlds start with M0=0 and both masks=1" —
   so the number is not missing, but `World.milestone_mask` and `Progress.unlocked_mask` have no
   owning module (`persistence_state_registry.md` records that `milestones.gd` deliberately holds
   neither). A §7.2 caller today would have to pass a literal with nothing to read it back from.
3. **Room validity.** `set_room_valid()` is a separate call by design; §5.9's validity list mixes
   countable rules with connectivity, enclosure, exterior links and "heated", none of which any
   module evaluates. Until something declares the starter rooms valid, the pantry room refuses
   its 200000 g and the kitchen provides no station slots.
4. **The edge-furniture representation.** §5.9's starter layout has "a partition separates x4/x5,
   with a door at row 4". `interior_partition` and `interior_door` are `0/0` edge furniture, and
   decision 0080 states that nothing defines how `origin_tile` + `rotation` name an undirected
   tile edge. The starter interior therefore cannot be placed unambiguously, and BAL-BUILD-001's
   overlap rule cannot be enforced. This is the hardest of the five.
5. **Container creation and `gear.gd`.** §5.9's four stockpiles and the pantry should become
   `inventory.gd` containers OWNED BY their Building rows, at `base_store_g_of()` grams. Who
   creates them is precisely the two-inventory question above, and `gear.gd` — which
   `seed_starter_tools()` lives in — is not composed into any system at all.
