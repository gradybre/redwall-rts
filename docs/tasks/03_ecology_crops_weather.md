# Task 03 — Ecology, crops and weather

Owning specs: `docs/game_gdd.md` §5.4–5.6, §5.9–5.10; `docs/systems_architecture.md`
§2, §5, §8; `docs/gameplay_balance.md` BAL-CROP/BAL-SAFE/BAL-RATIO.
Next group in ARCH-MIG-006 step 6's stated order.

## The finding that shapes this task

**Landing this entire group will not make the settlement loop do anything.**
Three independent blockers, none of which belong to this group:

1. **World generation does not exist.** `create_initial_settlement()` spawns the
   12-resident cohort and their per-resident rows only. REQ-SET-009's
   initialization contract — the guaranteed 100-tree grove, stone and iron
   deposits, forest ecology basins, starter fields — is unimplemented. **There is
   nothing in the world for a FARM, FORAGE or FISH job to reference.**
2. **No player command reaches the simulation** (blocker U2, ARCH-SYS-002
   absent). Designating a `HarvestZone`, sowing a field and starting a fishing
   cycle are all player actions with no delivery path.
3. **A created job cannot complete.** `jobs.assign_worker()` reaches only
   `JOB_STATE_RESERVED`; `RESERVED → TRAVEL → WORK` belongs to movement
   (ARCH-SYS-011/012, ARCH-MOVE-001), which does not exist and is gated by
   MOVE-G01–05 (decision 0020).

**Only `FarmPlot` creates a job automatically** — REQ-SET-073 (ripe → priority-2
harvest job) and REQ-SET-085 (health 0 → 10-WU clearing job). Foraging, fishing
and hive tending have **no stated job-creation trigger anywhere** in the document
set; sowing has a validation gate (REQ-SET-070) but no EARS trigger event.

So: this group is real work in the architecture's own order, and it is a
prerequisite. It is **not** the thing that animates the loop.

## Increments, dependency-ordered

| # | Increment | Depends on | Status |
|---|---|---|---|
| 1 | **RNG module** — ARCH-RNG-001/002 xorshift32, the named streams, seed derivation, draw-count persistence | nothing | **done** (`ea06c1c`) |
| 2 | **Weather** — §5.10, REQ-SET-141–150, single global row | 1 | **done** (`83db3c4`); selection mapping ruled, decision 0028 |
| 3 | **ResourceNode** + minimal tile placement | — | **done** |
| 4 | **HarvestZone + ForagePatch** — REQ-SET-066–069 | 1, 3 | **done**; quota reworked to the ruled daily aggregate, decisions 0026/0030 |
| 5 | **FishHabitat + FishStock** — §5.4 | 1 | **stock half done**; gear half still blocked by U5 (`GearInstance` has no allocator budget, so wear cycles cannot be completed) |
| 6 | **FarmPlot** + `CropState`/`Soil` catalog wiring — REQ-SET-072/073/085 | 2 | **done**; `TileHistory` built, five open contracts recorded in decision 0032 |
| 7 | **FieldPolicy + sowing** — REQ-SET-070/071/077/078/088 | 6 | **needs a decision**: the GDD states the sowing validation gate but never the triggering event |
| 8 | **OrchardPlot + Hive** — REQ-SET-079–084 | 2, 6 | **pollination blocked by U6** (`HivePollinationLinks` has no owner-major index formula) |
| 9 | **ARCH-SYS-005 Ecology** daily orchestration | 3,4,5,8 | closes one leg of REQ-SET-007 |
| 10 | **ARCH-SYS-006 CropWeather** orchestration | 2,6,7,9 | closes a second leg |

REQ-SET-007's five daily steps: this group closes **two** (ecology, crops/weather).
Age-stocks belongs to the earlier inventory group and is still open;
immigration/departures and progression come later.

## Gaps found while scoping — reported, not filled

- **`FaunaStockReserved` has no stated capacity anywhere.** SET-AMEND-001 §3 and
  REQ-SET-059 require the schema stay allocated, zeroed, with no live rows and no
  system writing it — but nothing says how large. Reserved is not the same as
  absent; REQ-SET-065 still requires its field shape be validated on load.
- ~~**The `FarmPlot` tile-backing store is named but not itemised.**~~
  **STALE, corrected 2026-09-09.** `systems_architecture.md` §2 itemises
  `TileHistory` at 16384 rows with `fertility, last_family, last_legume_day,
  compost_season, active_plot_row, orchard_row`, `ripe_tick, growth_remainder`
  and `tended_today` — the backing store ARCH-STATE-003 requires, tile→plot link
  included. The original note looked only at `WorldTileMaps`. Implemented in
  increment 6. ~~**One real shortfall survives**: `family_streak` has no
  `TileHistory` column, so a redraw restores the family but not the count.~~
  **CLOSED 2026-09-09** by the adopted [READY_06 §7 ruling](../rulings/2026-09-09_ready06_open_item_answers.md):
  `TileHistory.family_streak: I32[16384]` is added, that I32 group is now seven
  columns and **458752 bytes (+65536)**, the tile owns the
  `(last_family, family_streak)` pair and a redraw restores both — a
  third-or-later 700 stays 700. See decision 0032's resolution section.
- ~~**`CropState`, `Soil` and `OrderMode` are not compiled**~~ — **done in
  increment 6.** `PROTECTED_ENUM_DOMAINS` now holds eleven domains.
- **No RNG module exists.** ARCH-RNG-002 names `ECOLOGY`, `FISHING`, `FORAGE` and
  `WEATHER` streams with exact draw disciplines. This is a genuine new-module
  dependency not previously tracked as a blocker. **Resolved by increment 1.**

### Found while implementing (2026-09-09)

### Planner rulings received 2026-09-09 — see `docs/rulings/2026-09-09_task03_planner_rulings.md`

Rulings 1–3 answered and implemented; the contracts are folded into §5.10, §5.1,
§4.2 and ARCH-RNG-002 so the handoff is not their only home.

- **Weather selection** (decision 0028) — mapping ruled, increment 2 **done**.
- **4×4 deposits** (decision 0029) — sixteen independently exhaustible nodes
  each; placement implemented, and decision 0031 records the one judgement call
  (the caller declares which occupant may be replaced, because `resource_id`'s
  domain is still unstated).
- **Basin ownership** (0026, now Accepted) — confirmed with five constraints. A
  designation must **bind to existing** ownership; the current
  self-reference-at-creation is provisional only because no designation command
  exists (blocker U2).
- **Forage quotas** (decision 0030) — the shipped annual per-patch enforcement is
  **replaced** by a daily aggregate shared by the basin, with a Job-indexed claim
  table. `harvested_year_milli` is ecological history, not the quota accumulator.

**A claim this repository made repeatedly was wrong.** `quota_milli`'s period was
*not* unstated: `ui_ux_controls.md:219` (UI-SET-050) already labelled it "units
per day". The GDD and the architecture were searched; the UI document was not.
The narrower defect stands — the UI stated a period the GDD gave no contract for.

### Still open after the rulings

- **Ruling 4 was never answered** — the handoff responded to the three-ruling
  brief at head `90739ef`, written before `fishing.gd` existed, so decision 0027
  (effort-slot occupancy and REQ-SET-048's hysteresis bit) is still provisional.
- **Ruling 5 is new** — §4.3 has no `WeatherEvent`, but it *does* list an
  `EventDefinition` catalog, and `catalog.gd` compiles keys in ascending ASCII
  order. That numbering agrees with §5.10's printed order on `drought` alone, and
  `event` is persisted.

### Acceptance evidence that could not be executed, and why

| Fixture | Blocking dependency |
|---|---|
| R05-QTEST-12 cross-process round trip | **No save module exists in the repository.** The in-process rebuild — its substance — is implemented and tested |
| R05-QTEST-14 designation preview | Command queue (U2) and UI |
| R05-QTEST-15 output-capacity leg | No Job↔reserved-container binding exists; the quota and floor legs pass |
| R05-QTEST-07 cargo creation | `inventory.gd` owns cargo; `collect_claim()` returns the amount so a caller creates it once |
| R05-QUOTA-007 lease-expiry trigger | `jobs.gd` states `lease_expiry` is always 0 and never written (ARCH-JOB-004). The **cancellation** trigger is implemented and tested |

- **Increment 5's stock half is done** (`fishing.gd`): both stores, §5.4's nine-row
  species table, daily recovery, seasonal windows and closures, the daily quota,
  conservation floors, effort-slot capacity and the catch formula as a pure
  parameterised reader. Gear, expeditions, hazard/rare rolls, weather-gated access
  and lot creation are out and documented, not stubbed. **No RNG draws** — every
  §5.4 draw belongs to a cycle, and cycles need gear.
- **Two §4.2 columns had to be added, recorded as provisional decision 0027.**
  `FishHabitat` has `effort_slots` (a capacity) but nowhere to record occupancy,
  which REQ-SET-044/050 require; and REQ-SET-048's 30-down/40-up hysteresis needs
  one bit that population alone cannot supply. Both are save-carried state.
- **No `HabitatType` enum exists.** §4.2 types `FishHabitat.type` as `enum`, §4.3
  does not list one, and the ordinal is ambiguous — §5.1 orders the terrain masks
  "coast, river, lake", §5.4's table orders them "River, Lake, Coast". Held as
  module-local constants and deliberately **not** added to `PROTECTED_ENUM_DOMAINS`
  (decision 0018 covers enums §4.3 *numbers*). `type` is persisted, so a later
  renumbering breaks saves.
- **`pollution` has no stated effect** anywhere, and **§5.4 states no mechanical
  effect for the 25% refuge** either. Both are stored and range-validated; tests
  assert neither changes recovery, catch, or allowed stock.
- **Carp's window is not labelled a spawning closure** while trout's and salmon's
  are, leaving REQ-SET-047's scope ambiguous. Treated as a closure for the
  override prohibition — strictly safer, since it can only hold the floor at 30%.
- **`quota_milli`'s missing period, by contrast.** §5.4 states its quota is daily
  *and* §4.2 supplies `harvested_today_milli`. `HarvestZone.quota_milli` has
  neither, and `ForagePatch` has no daily accumulator. This is the worked example
  of what the complete version looks like.

- **The WEATHER stream has no roll-to-row mapping.** ARCH-RNG-002 fixes the draw
  count at one per season and §5.10 says weights are normalised within the
  season's eligible rows, but **nothing states the cumulative scan direction, the
  tie rule, or the normalisation rounding.** No weighted picker was written —
  that mapping would be an invented contract. **Increment 2 cannot consume the
  stream until this is ruled on.**
- **§5.1's 4×4 deposit footprints have no schema.** A 4x4 stone deposit of
  1200 U is either sixteen nodes whose per-tile split the document never states,
  or one node with an extent the §4.2 `ResourceNode` row cannot hold — it has no
  footprint field, and a tile holds one node. **This blocks REQ-SET-009 world
  generation**, not the store itself.
- **`resource_id`'s domain is unstated.** §4.2 types it `int32` and never says
  whether it is a compiled `ItemDefinition` id or a separate resource catalog.
  The store validates range only.
- **`regrow_days == 0` has no stated meaning.** §5.9 gives 48 days for trees and
  no period for stone or iron while saying surface stone can exhaust. Read as
  "never regrows", because a zero period under `day >= planted_day + 0` would
  refill every worked-out quarry the same day. **This is an interpretation**, and
  it is flagged in the module header.
- **REQ-SET-138's "no building occupies the tile" regrowth condition is
  unimplementable here** — it reads `WorldTileMaps.building_slot`, which no store
  owns. Only the day condition is implemented; ARCH-SYS-005 owns the rest.

## What completion does NOT establish

Not a playable colony. Foraging, farming and fishing will not happen end to end
without world generation (REQ-SET-009), the command queue (ARCH-SYS-002, U2) and
movement (ARCH-MOVE-001, MOVE-G01–05) — none of which are in this group, and none
of which should be quietly folded into it.
