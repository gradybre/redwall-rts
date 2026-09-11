# 0047 — ARCH-SYS-006 has two cadences, settles the *completed* day for damage and the *new* day for weather, and owns the FarmPlot side of the pollination refresh
Date: 2026-09-10 · Status: **Accepted** ·
Closes: increment 10 of `docs/tasks/03_ecology_crops_weather.md` ·
Depends on decisions [0028](0028-weather-event-selection-mapping.md),
[0032](0032-farming-interpretations-and-open-contracts.md),
[0036](0036-regrowth-adds-the-minimum-and-caps-it.md),
[0044](0044-pollination-links-are-per-recipient.md),
[0045](0045-field-rotation-advances-once-per-field-not-once-per-tile.md),
[0046](0046-ecology-runs-one-leg-of-the-daily-boundary.md)

## Decision

`godot/scripts/core/crop_weather.gd` is ARCH-SYS-006. It composes `farming.gd`
and `weather.gd` over the settlement's one entity directory, borrows
`ecology.gd`'s `orchard_hive.gd` and `resource_nodes.gd`, and runs **two
separate cadences**, wired in `settlement_system.gd`:

**Hourly**, from `run_tick()` at every crossing of `(tick + 4500) mod 750 == 0`:

1. REQ-SET-072 growth, `1000 × temperature_factor × moisture_factor / 1000000`.
2. REQ-SET-084 frost, the crop's stated damage **per subzero hour**.
3. REQ-SET-075 ripe expiry, at the exact hour the fifth day completes.

**Daily**, from `run_day_boundary()` at every offset-calendar midnight, **after
ARCH-SYS-005 Ecology**:

1. REQ-SET-087 blight for the **completed** day, with that day's tending flags.
2. `apply_orchard_day(ref, absolute_day - 1, temperature_tenths)` per block, at
   the temperature the row still holds for the completed day.
3. §5.10's new-day weather: end an expired event, schedule the season's event,
   disclose a due forecast, `refresh_daily(season, season_day)`.
4. REQ-SET-086 moisture: evaporate first, add rain, **one** clamped change.
5. `clear_tended_today()` — ARCH-TICK-003's service reset.
6. Decision 0044's **FarmPlot-side** pollination refresh, for the hive
   eligibility crossings ARCH-SYS-005 committed one call earlier.

Seven things were decided along the way and each could be undone by accident.

## 1. Frost and ripe expiry are HOURLY, against the increment brief

The brief for this increment listed frost, blight, the ripe grace and withering
all under "at midnight". Two of those four are wrong at that cadence, and the
GDD says so in its own units:

- **REQ-SET-084**: "remove the listed health/hour **while temperature<0°C**",
  and `farming.apply_frost_hour()` is documented as one hour. Called once per
  midnight, grain would lose 1000 health a day instead of 24000 — a 24× error
  that no test of `farming.gd` alone can see, because that store is right.
- **REQ-SET-075**: five days measured in **hours** from a tick-dated ripening.
  Ripening lands on an hour crossing, so 120 hours later is another hour
  crossing and an hourly check is exact. A midnight-only check withers up to 23
  hours late, and the lateness depends on what hour the crop happened to ripen.

Blight stays daily (REQ-SET-087 states 400 **per day**) and the ripe **decay**
needs no step at all: §5.6's 10%/day is a pure function of `ripe_tick`, which
`farming.gd` already evaluates at harvest. AGENTS.md's authority order puts the
GDD above a working instruction, so the units in the requirement won.

## 2. Damage settles the day that *ended*; weather opens the day that *began*

This is decision 0046 §2's split, applied to the crop layer, and it is why the
daily steps are in the order above rather than any other.

`tended_today` is set by a tending job **during** a day. REQ-SET-087's "reduced
to 200 if tended" is therefore only reachable if blight is charged at the
midnight that **ends** that day, before the service reset clears the flag.
Charging the day now beginning would read a flag nobody has had a chance to set:
every blighted plot would take 400 forever, every unit test of `farming.gd`
would still pass, and the stated 200 would be dead code.

The orchard day takes `absolute_day - 1` for the same reason and one more: the
midnight opening spring day 1 must settle **winter** day 12, which §5.6 charges
nothing for. Passing the day now beginning charges a spring untended day at the
moment winter ends. Both mutants are killed.

Everything else — the event, the forecast, the baseline, the moisture — is the
**new** day's, which is ARCH-TICK-003's own wording: "crop hourly growth uses
the elapsed hour's climate, followed by new-day weather/moisture/service reset".

## 3. Moisture is ONE clamped change, and the order is observable

§5.10: "Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer;
**rain adds after evaporation**", against REQ-SET-086's 0–10000 clamp.

Applied as a single net delta with a single clamp, this is identical to
evaporating and then raining. Applied as two clamped steps in the other order it
is not: a plot at 9800 in spring keeps 10000 under the stated order and drops to
9400 under the reverse, because the rain is clamped away before the evaporation
is taken off it. **A day's rain silently becomes a day's loss.** That is one
mutant (M25) and one test.

## 4. One event per season is the CALLER'S discipline, latched on the absolute season

`weather.gd`'s header states that §4.2's Weather row has no season column, so
that store cannot tell a new season from a repeated call and does not try:
"exactly one major event occurs per season" is explicitly the caller's. This is
the caller. `_last_scheduled_season` holds the **absolute** season index
`(day-1)/12`, read from `farming.absolute_season_of_day_into()` rather than
re-derived.

**Spring day 1 has no midnight.** The offset calendar opens at 06:00 of day 1
and its first crossing is day 2, so the season is scheduled at the **first
boundary the season sees**, not on its day 1. Year 1's spring is therefore
scheduled at spring day 2 — four days before the forced ideal spell's stated
day-6 start and one day before its day-3 forecast, so nothing is missed. Without
the absolute-season latch, the forced event would be re-scheduled every midnight
from spring day 9 onward, once its own window closed.

`prime_day()` writes the **opening** day's baseline, because otherwise a fresh
Weather row reports 0.0 °C for the first 18 game hours and every crop grows at
§5.6's cool-band half rate. `create_initial_settlement()` calls it for day 1; it
consumes zero draws, because year 1's spring is the forced onboarding event.

## 5. The FarmPlot-side refresh is a parameter, not a sweep

`orchard_hive.gd` cannot see a FarmPlot and says so; decision 0044 gives the
`(farm_row, tile_x, tile_z)` join to the crop layer's owner. Three places make
it, and a fourth deliberately does not:

- `create_plot_at_tile()` computes the new row's slice **before handing the row
  back**, and destroys the row again if the refresh refuses — a half-created
  plot would read the slice left by the previous owner of that typed row.
- `destroy_plot()` calls `clear_farm_links()` **before** `farming.destroy()`,
  which is ruling §3's "including on typed-slot reuse": after the destroy the
  reference is stale and the row is free to be reissued.
- The daily leg refreshes when ARCH-SYS-005 reports a **non-zero** hive
  eligibility crossing count, handed over explicitly by `settlement_system.gd`
  from `ecology.gd`'s own `DayResult`. Nothing runs between the two legs, so the
  refresh is still synchronous with the committed change in the only sense that
  matters: no dependent simulation read can interleave.
- **Zero crossings refresh nothing.** A blanket daily refresh would replace a
  synchronous discipline with a periodic repair and would hide a caller that
  skipped one. Both directions are mutants (M40, M41) and both are killed.

`check_farm_links_of()` is the pure comparison that proves the discipline was
honoured. **No read repairs**: a plot whose slice is one hive short still
answers 1100, not the 1150 a recomputation would find, and a plot linked to a
hive that fell below 5000 gets `POLLINATION_LINKS_STALE` rather than a quietly
downgraded multiplier.

## 6. The world seed is the one thing a fresh settlement genuinely lacks

`rng.gd` needs `seed_world()`; REQ-SET-009's world generation owns `World.seed`
and no store holds one. So `settlement_system.gd` composes the settlement's one
`Rng` **unseeded**, and the first midnight of the **second** season refuses with
the stream's own `RNG_NOT_SEEDED`.

That refusal fails the whole crops/weather leg rather than letting the season
run eventless, because §5.10 requires exactly one event per season and a
silently eventless season is a sentinel-shaped success. It is deliberately not
defaulted to a seed this stage invented. The whole first season still runs: the
forced first spring consumes zero draws structurally, because
`schedule_first_spring_event()` takes no `Rng` at all.

`test_settlement_system.gd`'s `_populated()` fixture now seeds the world, which
is what a world generator would do; the unseeded behaviour keeps its own named
test rather than disappearing.

## 7. `field_policy.gd`'s cycle is NOT resolvable from crop state

The brief asked for an honest answer on this rather than a half-wiring.
`record_plot_resolved()` accepts only `OUTCOME_HARVESTED` or `OUTCOME_CLEARED`,
and both are the **completion of a job** — `farming.harvest()` and
`farming.clear_withered()`. A crop reaching RIPE is not a harvest and a crop
withering is not a clearing; resolving a cycle from either would fabricate
exactly the completion decision 0045's ruling forbids fabricating.

To close it honestly needs: R06-JOB-005's producer path (the command layer, so
that a cycle can be opened and plots enrolled), plus `job_planner.gd` creating
the harvest and clearing jobs, plus `RESERVED → TRAVEL → WORK` from
ARCH-SYS-011/012. `field_policy.gd` is therefore not composed here at all.

## Dependencies refused rather than invented around

- **Ideal spell's "crop growth ×1.20" is NOT applied.** `weather.gd` publishes
  it and says "the join owns it"; the join cannot apply it. REQ-SET-072 requires
  the fractional progress be **retained**, `farming.gd` retains it inside
  `_release_growth_milli_hours()` under a single floor, and
  `advance_growth_hour_into()` accepts no growth factor. Multiplying its
  returned total afterwards floors twice and discards the remainder —
  BAL-WORK-001 forbids that shape by name ("one final floor and retained
  remainder"). It happens to be exact today only because every §5.6 factor is a
  multiple of 100, which decision 0032 already flagged as a coincidence rather
  than a contract. **The fix is one per-1000 parameter on
  `farming.advance_growth_hour_into()`, in a file this increment does not own.**
  This is the largest single gap this increment leaves.
- **Drought's "water 2 U/day" orchard care is not charged.**
  `weather.needs_orchard_water()` reports the condition and
  `apply_orchard_day()` takes no water argument; the cost is an `inventory.gd`
  lot and a care job, and neither is joined here.
- **Mussel's summer blight closure is not written, and the documents contradict
  each other about whose it is.** `fishing.gd` says in one comment that joining
  weather to the fishery is "ARCH-SYS-006's job (increment 10)" and in another,
  on `set_closed()`, that "ARCH-SYS-005 owns any daily orchestration that would
  write the bit". ARCH-SYS-006's §5 *Writes* column lists "Crop progress/health/
  ripe state, moisture, weather forecast, service counters" and no fish closure.
  **NEEDS A RULING**; no bit is written either way.
- **No job is created or advanced.** `job_planner.gd` is not called, no Job row
  is written, `JOB_STATE_WORK` is never set. A crop that ripens here marks itself
  RIPE and creates no priority-2 harvest job; a crop that withers marks itself
  WITHERED and creates no 10-WU clearing job.
- **No cross-process round trip.** ARCH-SYS-022 has no save stream, so neither
  latch and neither the season nor the hour they hold has a persisted form.
  Idempotence is tested **within one process**; across two it is
  `BLOCKED_RUNTIME` on the save module.
- **A fresh settlement has no plots and no orchards**, because REQ-SET-009's
  world generation places the starter fields and no world generator exists. Both
  cadences honestly do nothing. Creating a plot here to make the hour look busy
  would measure a fiction.

## No storage was added

`crop_weather.gd` allocates no simulation column. `farming.gd`'s FarmPlot and
TileHistory columns and `weather.gd`'s single 32-byte row are already itemised
in `docs/systems_architecture.md` §2; **composing** them adds nothing to the
ledger. This module holds one `Calendar`, one `IntResult`, two decoded tile
coordinates and three `int` latches; `settlement_system.gd` adds one
`CropWeather`, one `Rng`, one `DayResult` and one `HourResult`. None of that is
ARCH-MEM payload, so the memory trail and ARCH-MEM-009's row-by-row
reconciliation are untouched by this increment and no architecture document
needed editing.

## Evidence

`./tools/run_tests.sh` on `origin/master` (`55d2d80`) before any change:
**1808 test(s), 46482 assertion(s), 0 failure(s)**.
After: **1871 test(s), 47370 assertion(s), 0 failure(s)** — 55 new tests in
`godot/test/test_crop_weather.gd` and 8 in `godot/test/test_settlement_system.gd`.
`godot --headless --path godot --editor --quit` exits 0 and imports cleanly.

**One existing test changed behaviour and was updated, not weakened.**
`test_the_boundary_runs_the_season_handover_then_ecology_and_no_other_leg`
asserted a two-leg log because ARCH-SYS-006 had no owner. It is now
`test_the_boundary_runs_the_handover_then_ecology_then_crops_and_no_other_leg`
and asserts **three** legs in REQ-SET-007's order, with `LEG_CROP_WEATHER` after
`LEG_ECOLOGY` and `daily_leg_at(3)` refusing `INVALID_INDEX`. The four other
tests that began failing did so because their fixture had no world seed; they
now seed it in `_populated()`, and the unseeded case has its own named test.

**53 mutants plus 2 re-runs, one per `godot` invocation**, each with a 420-second per-run
timeout, each restored from a pristine copy and `sha256`-compared afterwards;
both production files are byte-identical to the pre-mutation copies. The harness
**parses the failure count as an integer** from the runner's summary line: a
recent increment's harness tested `"0 failure(s)" not in summary`, which matches
`"10 failure(s)"` as a substring and manufactured a phantom survivor.

**51 of 53 killed on the first sweep; both survivors produced a new test rather than an
equivalence claim, and both are killed after the additions.** The mutated lines include both
cadence predicates (the hour gate turned into a daily gate, made to accept tick 0, and given the
wrong offset; the day gate replaced by `tick % 18000 == 0`), both idempotence latches (weakened to
`<`, and never advanced), the completed-day offset in two directions, four reorderings of the six
daily steps, every store invocation, the season-event latch in both directions, the forced first
spring's zero-draw claim, the tile decode transposed, and in `settlement_system.gd` the REQ-SET-007
leg order, both dispatch sites, the crossing handover and both halves of `reset()`.

- **`M14` — running the moisture step before the weather step — survived**, because §5.10's event
  start days are 6 and 10 and a season is normally scheduled on its day 1, so the newly scheduled
  event is never active on the day it is scheduled. It IS reachable: a stage whose FIRST boundary
  falls on a season's day 6 schedules an event that is active immediately.
  `test_a_stage_first_running_mid_season_schedules_before_it_waters` drives exactly that with
  summer's drought and pins the day's moisture at 2400 rather than 600.
- **`M49` — removing the hour-crossing guard from `settlement_system._integrate_crops()` —
  survived**, because `run_hour_into()` gates itself and simply refuses on the other 23 ticks. The
  difference is real and was untested: the settlement would record 23 refused crop hours per game
  hour and overwrite `last_refusal()` on almost every tick, hiding any genuine refusal.
  `test_the_hourly_crop_leg_runs_on_hour_crossings_and_not_only_at_midnight` now asserts that a
  non-crossing tick records no refusal and leaves the error channel empty.

**One mutant is recorded as an expected non-kill and is NOT claimed**: writing the hour gate as
`tick % 750 == 0` without the calendar offset is **exactly equivalent**, because 4500 is six whole
hours. The offset is kept because ARCH-TICK-002 states the predicate in that form and because a
changed offset would silently break the bare version; `M03` mutates the offset to a value that is
NOT a multiple of 750 and is killed by 112 tests.

**The orchard day's TEMPERATURE source is an equivalent mutant under §5.10's own table and is not
claimed as covered.** The only thing `apply_orchard_day()` uses `temperature_tenths` for is the
winter chill counter's "temperature<=5 °C" test, and every temperature §5.10 can produce in winter
-- the -5 °C baseline, the ideal spell's 2 °C and hard freeze's -12 °C -- is at or below 5 °C. No
world state distinguishes the completed day's temperature from the new day's here. The orchard
day's **day index** is a different matter and is killed twice (`M11`, `M18`).

## Source

Task 03 increment 10, 2026-09-10. GDD §5.6, §5.10, REQ-SET-007, REQ-SET-072–087,
REQ-SET-141–145; `docs/systems_architecture.md` ARCH-SYS-006, ARCH-TICK-002/003,
ARCH-RNG-002; decisions 0028, 0032, 0044, 0045, 0046.
