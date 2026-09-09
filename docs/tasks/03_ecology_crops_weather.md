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
| 2 | **Weather** — §5.10, REQ-SET-141–150, single global row | 1 | unblocked |
| 3 | **ResourceNode** + minimal tile placement | — | **done** |
| 4 | **HarvestZone + ForagePatch** — REQ-SET-066–069 | 1, 3 | unblocked |
| 5 | **FishHabitat + FishStock** — §5.4 | 1 | **partly blocked by U5** (`GearInstance` has no allocator budget, so gear-wear cycles cannot be completed) |
| 6 | **FarmPlot** + `CropState`/`Soil` catalog wiring — REQ-SET-072/073/085 | 2 | unblocked; **the only real job-creation site** |
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
- **The `FarmPlot` tile-backing store is named but not itemised.**
  ARCH-STATE-003 requires per-tile soil history (last crop family, last
  legume-harvest day, compost season, ripe tick, service state) to **outlive** a
  deleted `FarmPlot` row, but `WorldTileMaps` has only four columns
  (`building_slot`, `room_slot`, `zone_link_head`, `resource_slot`) — no
  `farm_plot_slot`, and no fields or capacity for the history it must keep.
- **`CropState`, `Soil` and `OrderMode` are not compiled** into `catalog.gd`'s
  protected enum table, unlike the eight already there (decision 0018).
- **No RNG module exists.** ARCH-RNG-002 names `ECOLOGY`, `FISHING`, `FORAGE` and
  `WEATHER` streams with exact draw disciplines. This is a genuine new-module
  dependency not previously tracked as a blocker. **Resolved by increment 1.**

### Found while implementing (2026-09-09)

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
