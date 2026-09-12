# 0085 — Stock aging runs on the hour crossing, and a container must declare its store

Date: 2026-09-11 · Status: **Accepted**

ARCH-SYS-004 StockAge is implemented in `godot/scripts/core/stock_age.gd`, wired
into `settlement_system.gd`, and written through two new `inventory.gd` mutators.
REQ-SET-007's first daily leg now runs. This record fixes the four judgements the
work required, and names what it deliberately did not build.

## Decision

1. **The cadence is the hour crossing, not midnight.** `systems_architecture.md`
   line 558 gives ARCH-SYS-004 the frequency "Hour crossing and expiry crossing;
   midnight first", and §5.8 states the rate per *hour*. The pass therefore runs
   24 times a simulated day from `run_tick()`, gated on `(tick + 4500) mod 750 == 0`
   — **never** `tick mod 18000 == 0`. `stock_age.is_hour_boundary()` DELEGATES to
   `crop_weather.is_hour_boundary()` rather than restating the arithmetic, because
   two copies of one crossing can drift apart and one cannot.
2. **Midnight is that same pass, logged as the daily leg.** ARCH-TICK-002 forbids
   "a second age pass just because the same tick is both hourly and daily", and
   every midnight is also an hour crossing. `run_day_boundary()` therefore checks
   `stock_age.last_hour_tick()` against the boundary tick: if the tick path has
   already consumed it the leg is recorded and nothing is aged again; if nothing
   has (a boundary driven directly, in a test or a headless control), the leg runs
   the pass itself. It is placed **before** `_apply_season_handover()`, which is
   ARCH-TICK-003's stated position.
3. **Aging reads the ELAPSED interval's season, and the caller cannot supply it.**
   ARCH-TICK-003: "aging uses the season in the elapsed interval; ecology uses the
   new calendar day's season". `run_hour_into(tick)` decodes the season from
   `tick - 1` internally. A midnight that opens a new season therefore charges the
   season that just ended, by construction rather than by a caller getting it right.
4. **A container's store kind is DECLARED, and an undeclared container is not
   aged.** §5.8 gives four store factors — open pile 1500, covered store 1000,
   pantry 750, cellar 350 — by *store kind*, and §5.9 gives those kinds to
   buildings and furniture. ARCH-SYS-004's own row lists "storage factors" under
   **Reads**, so their owner is the building/room layer, which does not exist in
   this repository. `stock_age.gd` therefore holds an explicit,
   generation-validated declaration per container that the building layer will
   write, and reports `undeclared_containers` on every hourly result. No factor is
   defaulted, guessed, or inferred from a container's mass, filters or policy.

## Equipped lots: a named gap, not a choice

Decision 0061 gives a live lot with a null container exactly one meaning — an
equipped record held by a resident. §5.8 defines age as effective **storage** age
through a store factor, and it names every non-store case it covers: prepared food
left on tables takes the open-pile factor, and §5.9's ground piles take 1500. It
names **nothing** for equipment. There is therefore no factor to apply, and
applying one would be inventing a constant.

So equipped lots are not aged, `inventory.gd` refuses `LOT_EQUIPPED` for both new
mutators, and the sweep cannot reach one anyway because an equipped lot is threaded
into no container chain. **This is recorded as an unresolved contract, not as a
ruling**: the GDD does not say whether a satchel, a ground pile's contents or a
carried ration age, and only the ground pile has a stated factor.

It is currently unobservable, and there is a tripwire for the day it stops being
so: `gear.gd`'s `is_instance_required_item()` admits exactly `tool`, `net`, `trap`,
`ice_kit` and `outfit_tier2`, and all five carry `shelf_hours = 0`, which §5.8 says
do not spoil. `test_stock_age.gd` asserts that invariant directly, so making a
spoiling item equippable fails a test rather than quietly aging or quietly skipping.

## The seed → compost ratio is refused, not invented

§5.8 says "Seed shelf life is 1440h and spoilage becomes compost material" and
states **no quantity**. REQ-SET-108's "equal mass" is written about spoiled_food
specifically, and equal mass cannot be carried over to compost by analogy: §5.7's
compost recipe turns 4000 milli-U of spoiled_food (1000 g) into 2000 milli-U of
compost (2000 g), so the settled compost conversion in this game **doubles** mass.

An expired seed lot is therefore refused with `SEED_COMPOST_RATIO_UNSPECIFIED`,
left byte identical, and counted in `unconvertible_seed_lots`. A ratio is owed by
whoever owns §5.7's conversion table.

## A container filter cannot veto a spoilage conversion

§5.8's "food becomes spoiled_food at identical mass" is a **transformation in
place**, not a placement, so `transform_lot_item()` does not consult the
destination container's category filter. A §5.9 pantry admits RAW_FOOD and not
WASTE; if the filter could veto the conversion, food in a pantry would stay fresh
forever. `create_lot()` still enforces the same filter for everything that is
actually placed, and `test_stock_age.gd` asserts both halves against one container.

The conversion keeps the **same lot row** at the same generation, so every held
reference still resolves, and moves both conservation ledgers explicitly — the old
item sunk in full, the new item sourced in full — so `audit()`'s per-item
`live + sunk == sourced` still closes and BAL-RUN-007 sees a declared
transformation rather than a silent relabel. Age and remainder are reset there and
only there, because spoiled_food "lasts 240h" from the moment it becomes
spoiled_food.

## Two inventories, and why that was not fixed here

`settlement_system.gd` composes its own `inventory.gd` with the §4.3 catalog
registered into it, and ARCH-SYS-004 ages that store. `economy_system.gd` owns a
**separate** `inventory.gd` instance holding §5.1's starter stock. That is two
authorities for one settlement's goods, and it means the running game's starting
food does not yet age.

It was not merged here because `economy_system.gd` and `world_init.gd` are outside
this work's file ownership, and because the two autoloads are constructed in an
order (`SettlementSystem` before `EconomySystem`) that makes a bind at `_ready()`
unavailable. Reaching across to the autoload from the tick path would also have
made every `SettlementSystem` built by a test mutate shared autoload state. The
duplication is stated in `settlement_system.gd`'s header and is the next step for
whoever owns those two files.

## What REQ-SET-108 still owes

* **"trigger recipe/meal replanning"** — there is no recipe store, no order store
  and no meal plan. Each conversion increments `replans_owed`; nothing is notified.
* **The removal notice** for expired spoiled_food — ARCH-SYS-021 owns Notice and
  NoticeCondition rows and neither exists. Counted in `notices_owed`.
* **Job-side reservation invalidation** — GDD §4.2's per-lot `reserved_milli` IS
  released, inside the same transaction as the conversion. The Reservation ROW
  store (job, lot, quantity, expiry, purpose) is still blocked by U4/U5, so
  REQ-SET-116's "stable job-ID order" has nothing to order.
* **"invalid leases"** in ARCH-SYS-004's Writes column — ARCH-JOB-004's travel
  leases have no store.
* **Merging produced waste** — two lots that both become spoiled_food in one
  container are not merged. §5.8's merge rule requires identical quality, recipe
  and provenance, which the conversion carries from each source, so they are
  frequently not mergeable at all; REQ-SET-120 makes merging the response to
  reaching the lot cap, and that cap's response has its own owner.

## Memory

Four packed columns land in `stock_age.gd`, all sized from
`inventory.gd`'s own `CONTAINER_CAPACITY = 101376`, allocated once in `_init()`
and never resized:

| Column | Type | Width B | Count | Bytes |
|---|---|---:|---|---:|
| `_c_storage_class` | `PackedByteArray` | 1 | 101376 | 101376 |
| `_c_heated_interior` | `PackedByteArray` | 1 | 101376 | 101376 |
| `_c_declared_generation` | `PackedInt32Array` | 4 | 101376 | 405504 |
| `_declared_slots` | `PackedInt32Array` | 4 | 101376 | 405504 |
| **Total** | | | | **1013760** |

All four are registered in `docs/persistence_state_registry.md`, category 1,
ARCH-SAVE-002 §7 INVENTORIES_AND_LEASE_INDEXES. **The ARCH-MEM-009 ledger row in
`docs/systems_architecture.md` is NOT written by this work** — that file is owned
elsewhere and is reconciled by hand against the numbers above.

`_declared_slots` is category 1 rather than a rebuilt index because its order is
observable: withdrawal swaps the last entry into the freed position, so the order
is not recoverable from `_c_storage_class` ascending, and it is the order
containers are swept in. A lot that expires to nothing retires its row onto
`inventory.gd`'s last-freed-first free stack, so two sweep orders hand the next
`create_lot()` different slots.

## Verification

`./tools/run_tests.sh`: `ok: 2886 tests, 101596 assertions, 0 failures.`
`state_registry_coverage.py`: `PASS -- 39 modules, 287 rows, 552 packed columns checked`.
`godot --headless --path godot --editor --quit` imports with no script error.

Thirteen mutants, one per run, each file restored and `shasum -a 256` compared
against its pre-mutation digest; every one killed. The two that matter most:
turning the hour crossing into a two-hour period killed 22 tests, and moving the
aging leg after the season handover killed
`test_the_boundary_runs_aging_then_the_handover_then_ecology_then_crops`,
`test_the_midnight_leg_logs_aging_without_running_a_second_age_pass` and
`test_a_replayed_day_boundary_is_refused_rather_than_applied_twice` — so
ARCH-TICK-003's ordering is pinned by tests rather than by a comment.

One mutant survived on its first run and is recorded because the fix was a design
change, not a test addition: rounding an inexact equal-mass conversion instead of
refusing it changed nothing observable, because every shipped catalog mass divides
into spoiled_food's 250 g. The inexactness check had also been written as a `0`
return, which is the sentinel-in-the-value-channel pattern this repository has
been bitten by twice. It is now the pure, explicitly refusing
`StockAge.equal_mass_quantity_into()`, tested directly, and the re-run killed it.

## Tests changed rather than added

Four existing assertions in `test_settlement_system.gd` changed because the
behaviour they described genuinely changed, and each is now stated in its own
docstring:

* the daily leg log is four legs, not three, and begins with `LEG_STOCK_AGE`;
* a replayed day boundary logs two legs, not one (aging, then the handover), and
  still refuses with `ECOLOGY_DAY_ALREADY_RUN`;
* the unseeded-weather boundary logs three legs, not two;
* `tick_stage_count()` is eight, not seven.

No test was weakened or deleted.
