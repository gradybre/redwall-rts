# 0046 — ARCH-SYS-005 runs one leg of REQ-SET-007, resolves the hive's *completed* day, and latches the day it consumed
Date: 2026-09-10 · Status: **Accepted** ·
Closes: increment 9 of `docs/tasks/03_ecology_crops_weather.md` ·
Depends on decisions [0026](0026-forage-patches-belong-to-the-basin.md),
[0029](0029-deposits-are-sixteen-nodes.md),
[0030](0030-forage-quotas-are-daily-and-shared.md),
[0036](0036-regrowth-adds-the-minimum-and-caps-it.md),
[0037](0037-fishing-effort-is-claimed-by-the-cycle.md),
[0044](0044-pollination-links-are-per-recipient.md)

## Decision

`godot/scripts/core/ecology.gd` is ARCH-SYS-005. It composes the four ecology
stores over the settlement's one entity directory and runs, at each crossing of
the offset calendar into 00:00:

1. **§5.4 fish** — `reset_harvested_today()`, then `recover_daily(season, season_day)`.
2. **§5.5 forage** — `regrow_daily(season)`, then `run_midnight(tick, season)`.
3. **§5.6 hives** — `apply_hive_day_into(ref, absolute_day - 1)` per live hive.
4. **§5.9 resource nodes** — `regrow(slot, absolute_day)` for every exhausted node
   whose date has arrived.
5. **Annual counters** — `forage.reset_harvested_year()` at the **year** boundary only.

`settlement_system.gd` calls it once, in REQ-SET-007's order, after
ARCH-TICK-003's season handover. Five things were decided along the way and each
could be undone by accident.

## 1. The stage runs exactly one of REQ-SET-007's five legs, and says which

REQ-SET-007 is "age stocks, update ecology, advance crops/weather, process
immigration/departures, then evaluate progression **in that order**". Only
"update ecology" is implemented here. Age stocks (ARCH-SYS-004),
immigration/departures (ARCH-SYS-007) and progression (ARCH-SYS-020) have no
store at all; crops/weather is ARCH-SYS-006, increment 10.

The order is not left as a comment. `settlement_system.gd` records the legs a
boundary **actually executed**, in execution order, and publishes them through
`daily_leg_at()`/`daily_leg_count()`. A boundary today reports exactly
`[LEG_SEASON_HANDOVER, LEG_ECOLOGY]`, and
`test_the_boundary_runs_the_season_handover_then_ecology_and_no_other_leg`
fails if a leg is added, dropped or reordered. An orchestrator that quietly ran
a leg it does not own would otherwise pass every test it wrote for itself.

## 2. A hive's day is the day that *ended*; everything else is the day that began

ARCH-TICK-003 says "ecology uses the new calendar day's season", and legs 1, 2, 4
and 5 do exactly that. The hive leg passes `absolute_day - 1`, which looks like
an inconsistency and is not:

- `record_hive_service()` stamps the day the *work happened*.
- `apply_hive_day_into()` is documented as "one **completed** day", and decides
  production versus REQ-SET-083's 200-strength loss from
  `serviced_day == day`.
- `orchard_hive.gd`'s own `apply_orchard_day()` reads the same way.

Passing the day now beginning would find every hive unserviced — nobody can have
serviced a day that started one tick ago — and charge 200 strength **every day
forever**, quietly abandoning every apiary in 40 days while every unit test of
the store still passed. Two mutants pin the choice: `absolute_day` and
`absolute_day - 2` are both killed.

## 3. Hives run under ARCH-SYS-005, not ARCH-SYS-006, and the table is ambiguous

`docs/systems_architecture.md` §5 gives ARCH-SYS-005 the provenance
`[GDD §5.4–5.6, §5.9–5.10]`, which **includes** §5.6, while ARCH-SYS-006 lists
`Hive` in its *Reads* column and writes "service counters". Both rows can be read
as owning the hive's daily step.

The split taken is by **dependency, not by table row**: the hive day needs no
weather input, so it runs here; the *orchard* day (`apply_orchard_day()`) takes
`temperature_tenths` and stays with ARCH-SYS-006, which owns weather. If
increment 10's owner concludes otherwise, moving the call is one line —
`_advance_hives()` is a self-contained leg and this paragraph is the record that
the table did not settle it.

## 4. Replaying a day REFUSES, and the latch is raised *before* the legs run

`_last_day` records the last absolute day consumed; a day at or before it refuses
with `ECOLOGY_DAY_ALREADY_RUN`. Without it, one replayed boundary charges a hive
two days of missed service, recovers every fish stock twice, and resets the
forage day's collected totals under a claim that had already collected against
them — all silently, because each store's own operation is perfectly happy to be
called again.

The latch is raised **before** the legs, so a leg that refuses half way through
leaves the day *consumed*. That is deliberate and is the less bad of two bad
options: the legs before the refusal have already committed, and re-running would
apply them twice. The refusal is the report; `last_day_run()` names the day
either way.

## 5. The boundary tick is recovered by an inverse that is *gated*, not trusted

`sim_clock.gd` states that `is_day_boundary()` is the single definition of a
crossing and that no caller may re-derive it. But the clock hands the day
boundary callback `(absolute_day, season)` and `forage.run_midnight()` needs a
**tick**. Rather than change the callback's signature — a file another agent is
editing concurrently — `Ecology.midnight_tick_of_day_into()` computes
`(day - 1) * 18000 - 4500` and then **passes the result through
`SimClock.is_day_boundary()` before returning it**. A wrong inverse refuses
instead of travelling; the predicate stays the single definition.

`settlement_system.gd` then decodes that tick back through
`SimClock.calendar_at_into()` and refuses `DAY_BOUNDARY_CALENDAR_MISMATCH` unless
it round-trips to the day *and the season* it was given. Day 1 refuses, because
tick 0 is 06:00 and day 1 opens at no crossing — which is why the clock's first
boundary is day 2 at tick 13500 and never `tick % 18000 == 0`.

## Dependencies refused rather than invented around

- **REQ-SET-138's "no building occupies the tile" is still unevaluable.**
  `resource_nodes.gd` records that the condition reads
  `WorldTileMaps.building_slot`, which no store owns, and that ARCH-SYS-005 must
  apply it before calling `regrow()`. No store can answer it today, so leg 4
  applies the **day condition alone**, exactly as the store computes it. The
  limitation is carried forward in `ecology.gd`'s header, not fabricated.
- **The FARM side of the pollination refresh is increment 10's.**
  `orchard_hive.gd` refreshes every ORCHARD recipient itself on an eligibility
  crossing — which is why a hive strength change committed by leg 3 refreshes
  synchronously and no yield read repairs anything. A FarmPlot's tile lives in
  `farming.gd`, decision 0044 gives the `(farm_row, tile_x, tile_z)` join to the
  crop layer's owner, and this stage does not reach into `farming.gd` to do it
  early.
- **No job is created or advanced.** `job_planner.gd` is not called; no Job row is
  written; `JOB_STATE_WORK` is never set. A forage claim released by leg 2 is
  released by `forage.gd`'s ruled order and generates no WU, cargo or refund.
- **No wildlife-pressure event is rolled.** §8's ECOLOGY RNG stream asks for "one
  wildlife-pressure roll per eligible summer/autumn basin/apiary at midnight". No
  store models wildlife pressure, no eligibility predicate exists and no
  magnitude is stated, so **no draw is taken** — consuming a deterministic stream
  for an effect that does not exist would be worse than the gap.
- **No cross-process round trip.** ARCH-SYS-022 has no save stream, so `_last_day`
  has no persisted form. Idempotence is tested **within one process**; across two
  it is `BLOCKED_RUNTIME` on the save module.
- **A fresh settlement's ecology is empty and the stage honestly does nothing.**
  GDD §5.1's world generation places the tree cover, the deposits, the basins and
  the estuary, and no world generator exists. Placing a node here to make the day
  look busy would measure a fiction, exactly as a fabricated job would.

## Order *within* the stage, and what is not load-bearing

Legs 1–4 touch disjoint stores and disjoint columns, so no leg can observe
another's result. The order is ARCH-SYS-005's own stated write order ("Stock
growth, quotas, migration, resource regrowth"), fixed for determinism and for the
record — **not** because a value depends on it. Swapping two of them is an
equivalent mutant and is not claimed as a kill. The same is true of
`regrow_daily()` before `run_midnight()`: `reconcile_claims()` measures claims
against quota and the day's collected total, never against patch stock.

What *is* load-bearing, and is mutation-tested: the boundary predicate, the
idempotence latch, each store's invocation, the season and season-day handed to
each store, the completed-day offset in leg 3, the year-boundary predicate in leg
5, and the REQ-SET-007 leg order in `settlement_system.gd`.

## No storage was added

`ecology.gd` allocates no simulation column. It holds one `Calendar`, one
`IntResult`, one `HiveDayResult` and one `int` latch; `settlement_system.gd` adds
a 6-entry `PackedInt32Array` leg log and one `DayResult`. None of that is
ARCH-MEM payload, so `docs/systems_architecture.md`'s memory trail is unchanged
and ARCH-MEM-009's reconciliation is untouched by this increment.

## Evidence

`./tools/run_tests.sh` on the base branch `feat/orchard-hive-pollination`
(`75ba7ef`) before any change: **1600 test(s), 40141 assertion(s), 0 failure(s)**.
After: **1645 test(s), 40442 assertion(s), 0 failure(s)** — 36 new tests in
`godot/test/test_ecology.gd`, 7 in `godot/test/test_settlement_system.gd`, and 2
added afterwards to kill surviving mutants. `godot --headless --path godot
--editor --quit` exits 0 and imports cleanly.

**44 mutants, one per `godot` invocation**, each with a 240-second per-run
timeout, each restored from a pristine copy and `sha256`-compared afterwards;
both production files are byte-identical to the pre-mutation copies. **43 killed.**
The mutated lines include the boundary predicate (removed, and replaced by
`tick % 18000 == 0`), the idempotence latch (weakened to `<`, and never
advanced), each of the five legs' invocations, the season and season-day handed
to each store, the completed-day offset in the hive leg (`day` and `day - 2`),
the year-boundary predicate, all three steps of the midnight inverse, and the
REQ-SET-007 leg order and calendar join in `settlement_system.gd`.

**Two mutants initially survived and each produced a new test rather than an
equivalence claim.** Passing `regrow_daily()` a fixed `SEASON_SPRING` survived
because every regrowth test ran a spring day —
`test_a_forage_patch_grows_by_the_new_days_season_not_a_fixed_one` now pins
decision 0036's own winter herb row (1512, not spring's 3560). Removing
`DayResult.refuse()`'s `clear()` survived because `run_day_into()` clears the
result before any leg can refuse — `test_a_leg_refusing_midway_carries_no_count_from_the_legs_that_ran`
now drives a corrupt patch through the forage leg *after* the fish leg has
recovered three stocks, so the mutant leaves a half-day of counts on a refused
result. Both are killed after the additions.

**One mutant survives and is expected to**: deleting the `_init` drift assert
that the ecology stores share the settlement's directory. It is a guard with no
behaviour of its own. Its behavioural pair — building the ecology on a **private**
directory, with that assert deleted in the same run so the assert cannot be what
kills it — fails **43 tests** by value, so the invariant is caught by value tests
and not only by the assert.

**Not claimed as kills.** Swapping two of legs 1–4, or `regrow_daily()` before
`run_midnight()`, are equivalent mutants: the columns are disjoint. That is
recorded above so a later reader does not read the survival as a missing test.

## Consequences

- Increment 9 of `docs/tasks/03_ecology_crops_weather.md` is closed. **Every
  ecology store is now advanced by something.**
- Increment 10 inherits `settlement.ecology().orchard_hive()` and
  `settlement.ecology().forage()` rather than composing its own, and owns:
  `apply_orchard_day()`, `farming.gd`, `weather.gd`, and decision 0044's
  FarmPlot-side link refresh.
- `settlement_system.gd`'s header count is corrected: an earlier revision said
  **three** implemented stages while listing four. It is **five** now, one of
  them (ARCH-SYS-008) partial.
- `run_day_boundary(absolute_day, season)` now **refuses** a pair the calendar
  does not join, and refuses day 1. Both were previously accepted and neither was
  reachable from the clock; the two new refusals are named tests.

## Source

GDD REQ-SET-007, §5.4, §5.5, §5.6, §5.9; `docs/systems_architecture.md` §5
(ARCH-SYS-005/006, ARCH-TICK-002/003) and §8's ECOLOGY RNG stream row; decisions
0030 §4.4, 0036, 0037 and 0044; `godot/scripts/core/sim_clock.gd`'s offset
calendar contract.
