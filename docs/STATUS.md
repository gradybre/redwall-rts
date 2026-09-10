# Status — the programme, task 03, and the READY_06 answers

Generated 2026-09-09. `master` at `d60b72f`; work branch `feat/catalog-ids-artifact`.
**1224 tests, 35844 assertions, 0 failures**, enforced by CI on every PR since #7.

This file exists so Brendan and Astra can check the plan against the repository
rather than against a chat transcript. Every claim below is checkable from a
commit, a decision record, or a test count.

## Where the code actually is

| | |
|---|---|
| Merged | PRs #3, #4, #5, #6, #7 |
| `master` | `d60b72f` — all of task 03's shipped increments plus CI |
| Open branch | `feat/catalog-ids-artifact`, one commit (`33cdc2a`), not yet PR'd |
| CI | `.github/workflows/tests.yml`, Godot 4.7.2 pinned, gate asserts the runner's summary line rather than the exit code |

## The whole programme, not just task 03

Task 03 is one group inside a much larger specification. This section is the
wider picture, so the detail below is not mistaken for overall progress.

### Task files

| Task | State |
|---|---|
| `01_initial_setup.md` | **complete** — 9/9 |
| `02_settlement_foundation.md` | **complete** — 28/28, with blockers U1–U7 recorded |
| `02_test_migration_ledger.md` | reference ledger, not a checklist |
| `03_ecology_crops_weather.md` | **6 of 10 increments**, detail below |

**Planning update, 2026-09-09:** [the next package](planning/README.md) now adds
[a release roadmap](tasks/00_release_roadmap.md), detailed tasks 04/05, milestone
cards 06–10, movement-contract decisions, requirement ownership and first-playable
acceptance. These are plans, not runtime progress; task 03 remains the executor's
active work. The implementation/test snapshot elsewhere in this file is unchanged.

### Requirement coverage

| Family | Specified | Appears in code |
|---|---:|---:|
| `REQ-SET-###` (GDD) | 181 | 75 |
| `UI-SET-###` (UI/UX) | 103 | 1 |
| `MOVE-REQ-###` (movement) | 20 | 0 |

**"Appears in code" is a weak proxy and overstates progress.** A module header
that names `REQ-SET-051` to record it as *blocked* counts in that 75. Read the
column as "has been considered somewhere", not "is implemented and tested".

The UI row is the honest one: **1 of 103**. The only UI is `hud.gd`.

### System stages — 5 of 23 running

`settlement_system.gd` runs ARCH-SYS-003 (needs, with 017 folded in), 008's
activity half, 010 and 013. The other eighteen are declared and idle.

The missing links for the player-driven loop:

- **ARCH-SYS-002 CommandCommit** — the ordered ECONOMIC command queue now exists
  (`scripts/core/commands.gd`, decision 0042): ARCH-CMD-001 ordering, ARCH-CMD-003's
  24 compiled kinds, §8.1's 64-byte records. **Blocker U2 is only partly closed** —
  ARCH-CMD-002's separate speed/pause scheduler-event queue still awaits task 04.1's
  amendment, and nothing dispatches a drained command, so **no player action reaches
  the simulation yet**.
- **ARCH-SYS-009 JobPlanner** — **nothing creates jobs.** READY_06 item 1 answers
  this with eight EARS contracts; none are built yet.
- **ARCH-SYS-011/012 Navigation and Movement** — no pathfinder, no Transform
  store. A job cannot progress past `RESERVED`.

**Separate reproducibility/persistence gap:** ARCH-SYS-022 CheckpointHash has no
save stream. This blocks full save/replay evidence, but is not a prerequisite to
observing the first command → travel → work → delivery loop.

### What exists as data versus what runs

The task-03 work built **stores**: RNG, resource nodes, forage, fishing, weather,
farm plots and tile history. They are tested and correct in isolation. **None of
them is wired into the tick**, because ARCH-SYS-005 and 006 — the two
orchestration stages that would drive them — are increments 9 and 10 and are not
started.

So the accurate summary of task 03 is: *the ecology model exists and nothing
runs it yet.*

### Prototype code still present

`godot/scripts/components/` (`component.gd`, `health_component.gd`,
`position_component.gd`) and `entity_manager.gd` are the original prototype,
still autoloaded, still diverging from the GDD as decision 0006 records. They are
not part of the settlement architecture and have not been removed.

## Task 03 increments

| # | Increment | Status |
|---|---|---|
| 1 | RNG module | **done** |
| 2 | Weather | **done** — mapping ruled (0028) |
| 3 | ResourceNode + tile placement | **done** — deposits added (0029, 0031) |
| 4 | HarvestZone + ForagePatch | **done** — quota reworked to the ruled daily aggregate (0026, 0030) |
| 5 | FishHabitat + FishStock | **stock half done**; effort claims added (0037), `GearInstance` allocator added (0038). Remaining gear work needs the Expedition store and the installed-gear contract, **not** U5 |
| 6 | FarmPlot + TileHistory + catalog wiring | **done** — five open contracts recorded (0032) |
| 7 | FieldPolicy + sowing | **not started** — unblocked by READY_06 item 1 |
| 8 | OrchardPlot + Hive | **not started** — unblocked by READY_06 item 3 |
| 9 | ARCH-SYS-005 Ecology orchestration | **not started** |
| 10 | ARCH-SYS-006 CropWeather orchestration | **not started** |

## The READY_06 answers, item by item

Astra's recommended order is followed. Items are marked against
`docs/rulings/2026-09-09_ready06_open_item_answers.md`.

| # | Item | Status |
|---|---|---|
| 2 | Compiled enum IDs from ASCII keys | **DONE** — `cc20c42`, decision 0033 |
| 10B | U1 `catalog_ids.json` artifact and hash | **DONE** — `33cdc2a`, decision 0034 |
| 7 | Persist `family_streak` on tiles (+65536 B) | **NEXT** |
| 6 | Farming's five readings | **not started** — 6.4 ratifies what shipped; the decay formula still needs checking against Astra's fixture |
| 5 | Fishing occupancy, hysteresis, intensive policy, `FishingEffortClaim` (+12800 B) | **partial** — the three columns exist and are now fully ledgered; the claim table and the two-slot atomic reserve are not built |
| 8A | Regrowth: additive `+1 U`, capped | **not started** — this **changes shipped behaviour**, see below |
| 8B | Three generated habitats within the 32 ceiling | **not started** |
| 3 | `HivePollinationLinks`, six links per recipient (+49152 B) | **not started** — unblocks increment 8 |
| 4 | `GearInstance` allocator (+212996 B) | **not started** — unblocks increment 5's gear half |
| 1 | Job-creation triggers, eight EARS contracts | **not started** — the largest item, unblocks increments 7 and 10 |
| 9 | Integration fixtures | **owners assigned, still blocked** |
| 10A | Decision 0016 performance ownership | **not started** — still `Owner: unassigned` in the record |
| 10C | U7 six golden fixture families | **not started** |

## Three things worth checking specifically

**1. Item 8A changes behaviour that already shipped.** `forage.gd` currently
computes `max(1000, calculated_growth)`; Astra rules the additive form,
`min(K-P, floor((K-P)*r*S/1000000) + 1000)`. These differ: for a 100000 gap at
`r=60, S=300` the current code yields 1800 and the ruled form yields 2800. This
is a **deliberate behaviour change**, and its changed hashes must be recorded as
such, never as optimisation parity.

**2. Item 6.4 ratified the implementation, but the decay steps need checking.**
The shipped `RIPE_WITHER_DAYS = 5` from `ripe_tick` is 120 hours, which is
exactly what Astra ruled ("120, not 168"). What still needs verifying is the
decay schedule: `loss_count = max(0, floor((elapsed-48)/24))` with each loss
`floor(yield*900/1000)`, giving 100000 → 90000 at 72h → 81000 at 96h → not
harvestable at 120h, and **no third harvestable decay step at 120**.

**3. A ledger error Astra caught, now fixed.** `FishHabitat.intensive_harvest`
(`B8[32]`, 32 bytes) exists in `fishing.gd` and I had omitted it from §2.2.
Decision 0027's provisional group is **256 bytes, not 224**; the payload total is
now **24586066**.

## Still needing Astra

- **Decision 0027 remains Provisional.** Item 5 recommends ratifying it, but the
  record's status has not been changed pending confirmation that the
  recommendation is adopted rather than proposed.
- **Decision 0032's five items** are answered by READY_06 item 6 and will be
  updated to Accepted as each is implemented, not before.
- **Decision 0016** still reads `Owner: unassigned`. Item 10A recommends
  "implementation lead, with independent performance review" and a checkpoint
  after the integrated ecology/needs/work path exists.

## Standing constraints that shaped all of the above

- Integer-only authoritative state; `float` is presentation and import only.
- No module in this group calls `jobs.gd`; ARCH-SYS-006 owns orchestration.
- Mutation testing runs one mutation per run, restored and hash-compared, and a
  mutant killed only by an `_init` drift assert is paired with a variant that
  leaves the assert satisfied — because the first kind proves the guard works,
  not that the behaviour is tested.
- A blocked acceptance fixture is reported blocked. There is still **no save
  module in this repository**.
