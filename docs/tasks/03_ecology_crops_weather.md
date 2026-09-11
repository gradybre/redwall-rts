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
| 5 | **FishHabitat + FishStock** — §5.4 | 1 | **stock half done**; effort claims added (0037). `GearInstance`'s allocator now exists (0038), so **U5 no longer blocks portable gear** — the remaining gear work needs the Expedition store and the installed-gear contract for boats and weirs |
| 6 | **FarmPlot** + `CropState`/`Soil` catalog wiring — REQ-SET-072/073/085 | 2 | **done**; `TileHistory` built, five open contracts recorded in decision 0032 |
| 7 | **FieldPolicy + sowing** — REQ-SET-070/071/077/078/088 | 6 | **done**. The triggering event was ruled by [READY_06 §1](../rulings/2026-09-09_ready06_open_item_answers.md): R06-JOB-004's explicit first planting (decision 0040) and R06-JOB-005's configured rotation advance (decision 0045). `FieldPolicy` is built at its budgeted 128 rows plus a 40960-byte cycle and enrolment ledger. **No plot → field mapping exists** — §5.6 calls field grouping "a UI/work aggregation" — so the participating set is a validated caller-supplied group. REQ-SET-078 was already `farming.apply_fallow_day()`; REQ-SET-088 is an **unsatisfiable gate that refuses**, because every `reservations.gd` row is Job-owned and a standing seed reserve has no Job |
| 8 | **OrchardPlot + Hive** — REQ-SET-079–084 | 2, 6 | **done** (`godot/scripts/core/orchard_hive.gd`); U6's `HivePollinationLinks` half closed by ruling 2026-09-09 §3 and decision 0044 — 30720 references, +49152 bytes, ARCH-STATE-008. REQ-SET-084's frost belongs to `farming.gd` and was already implemented there. **Not built here:** R06-JOB-006's 20-WU hive-service producer, apiary/Building placement (no Building store), and the FarmPlot-side link refresh, which is the increment 10 join's |
| 9 | **ARCH-SYS-005 Ecology** daily orchestration | 3,4,5,8 | **done** (`godot/scripts/core/ecology.gd`, wired in `settlement_system.gd`); decision 0046. Closes REQ-SET-007's "update ecology" leg ONLY: fish recovery and the daily quota reset, decision 0036's additive forage regrowth and decision 0030 §4.4's quota midnight, every live hive's COMPLETED day with decision 0044's synchronous orchard link refresh, and REQ-SET-138 stump regrowth; annual counters at the year boundary only. **Not closed here:** REQ-SET-138's building-occupancy condition (no store owns `building_slot`), the FarmPlot-side pollination refresh (increment 10's join), §8's ECOLOGY wildlife-pressure roll (no store, no magnitude, so no draw is taken), and a cross-process round trip of the day latch (no save module) |
| 10 | **ARCH-SYS-006 CropWeather** orchestration | 2,6,7,9 | **done** (`godot/scripts/core/crop_weather.gd`, wired in `settlement_system.gd`); decision 0047. Closes REQ-SET-007's "advance crops/weather" leg, which now runs AFTER "update ecology" in the published leg log. **TWO CADENCES**: hourly (REQ-SET-072 growth, REQ-SET-084 frost per subzero hour, REQ-SET-075 expiry at the exact hour) driven from `run_tick()`, and midnight (completed-day REQ-SET-087 blight, `apply_orchard_day()` for the completed day, §5.10 event scheduling/forecast/baseline, REQ-SET-086 evaporate-then-rain moisture, the service reset, and decision 0044's FarmPlot-side pollination refresh). **Not closed here:** ideal spell's crop growth x1.20 (`farming.advance_growth_hour_into()` accepts no growth factor and REQ-SET-072 requires the retained remainder); drought's orchard water cost (no inventory join); mussel's summer blight closure (`fishing.gd` names BOTH ARCH-SYS-005 and ARCH-SYS-006 as its owner -- needs a ruling); `field_policy.gd`'s cycle resolution (needs a job completion, which needs the movement layer); the world seed, so an ungenerated world refuses its second season's WEATHER draw; and a cross-process round trip of either latch (no save module) |

REQ-SET-007's five daily steps: this group closes **two** (ecology, crops/weather),
and both now run, in the requirement's order, in `settlement_system.gd`'s published leg
log. Age-stocks belongs to the earlier inventory group and is still open;
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

### Found while implementing increment 10 (2026-09-10) — see decision 0047

- **`fishing.gd` names two different owners for the mussel blight closure.** One
  comment says joining weather to the fishery is "ARCH-SYS-006's job (increment
  10)"; the comment on `set_closed()` says "ARCH-SYS-005 owns any daily
  orchestration that would write the bit". ARCH-SYS-006's §5 *Writes* column
  lists no fish closure at all. **No bit is written either way**; this needs a
  ruling, not a coin toss.
- **Ideal spell's "crop growth ×1.20" has no API to land in.** REQ-SET-072
  requires the fractional progress be retained, and `farming.gd` retains it
  inside `_release_growth_milli_hours()` under one floor.
  `advance_growth_hour_into()` accepts no growth factor, so the join cannot
  apply the modifier without flooring twice — BAL-WORK-001 forbids that shape by
  name. The fix is one per-1000 parameter on that function.
- **The world seed still has no owner.** `rng.gd` needs `seed_world()` and
  REQ-SET-009's world generation owns `World.seed`. A fresh settlement's first
  season runs (the forced first spring consumes zero draws, structurally), and
  its second season's midnight refuses `RNG_NOT_SEEDED` rather than defaulting to
  an invented seed.
- **The offset calendar gives absolute day 1 no midnight**, so the opening day's
  weather has to be written outside the boundary. `crop_weather.prime_day()` does
  it and `create_initial_settlement()` calls it; without it the first 18 game
  hours read a cleared Weather row at 0.0 °C and every crop grows at §5.6's
  cool-band half rate.

### Found while implementing increment 9 (2026-09-10) — see decision 0046

- **The §5 table does not settle who runs the hive's daily step.** ARCH-SYS-005's
  provenance is `[GDD §5.4–5.6, §5.9–5.10]`, which includes §5.6; ARCH-SYS-006
  lists `Hive` in its *Reads* column and writes "service counters". The split
  taken is by dependency: the hive day needs no weather, the orchard day takes
  `temperature_tenths`, so hives run under ARCH-SYS-005 and orchards under
  ARCH-SYS-006. Recorded rather than resolved in the document, because either
  reading is defensible.
- **§8's ECOLOGY RNG stream has no implementable subject.** It asks for "one
  wildlife-pressure roll per eligible summer/autumn basin/apiary at midnight". No
  store models wildlife pressure, no eligibility predicate exists and no magnitude
  is stated anywhere. **No draw is taken**, so the stream's draw count is still
  0 — consuming a deterministic stream for an effect that does not exist would be
  worse than the gap.
- **REQ-SET-138's building-occupancy condition is still unevaluable.**
  `resource_nodes.gd` recorded it and named ARCH-SYS-005 as the system that must
  apply it. ARCH-SYS-005 now exists and still cannot: `WorldTileMaps.building_slot`
  has no owner. Regrowth applies the day condition alone, and the limitation moved
  forward with the caller instead of being fabricated.
- **`settlement_system.gd`'s header undercounted its own stages.** It said THREE
  implemented stages while listing four. Corrected to five (one partial) as part
  of wiring ARCH-SYS-005.

### Acceptance evidence that could not be executed, and why

| Fixture | Blocking dependency |
|---|---|
| R05-QTEST-12 cross-process round trip | **No save module exists in the repository.** The in-process rebuild — its substance — is implemented and tested |
| ARCH-SYS-005 day-latch round trip | **No save module exists.** `ecology.gd`'s `_last_day` idempotence latch has no persisted form, so replay protection is tested within one process only |
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
