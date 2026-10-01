# 0571 — The winter fuel and warmth loop in the live demo
Date: 2026-10-01 · Status: Accepted

Numbered 0571 because the brief asked for 0571–0579. No record numbered 0570–0579 exists on any branch
(`git log --all -- 'docs/decisions/057*'`) or in any sibling worktree.

## Decision

The live demo gets GDD §5.8's heating fuel, REQ-SET-130/131's warm and cooling rooms and REQ-SET-018/019's cold
exposure, under Brendan's six rulings of 2026-10-01, in `godot/demo/winter/` (presentation only; the settlement
simulation is not written). `godot/demo/README.md` ("Winter") says what the player sees.

### Brendan's rulings (2026-10-01), verbatim

1. **Cold makes residents "Chilled".** At 4 or more exposure-hours, a resident works at 80% speed, borrowing the storm
   factor's magnitude if one exists, and takes a warm-up break at a heated home, which clears exposure at the GDD rate.
   There is **no health loss and no death.** Show Chilled on the resident card and in the needs or status UI, and say
   why.
2. **Hearths follow the GDD's continuous demand:** 4 U/day per home with an installed hearth in winter, and 2 U/day on
   spring or autumn days whose mean is below 10°C. Take the wood hourly through a milli-U accumulator; integer state
   only. The glow and lit state follow "fuelled AND demanded"; keep the 19:00–07:00 lit look where heat is demanded at
   night, and coordinate the look via the query. A home without fuel goes cold under REQ-SET-131 convergence. The
   hearth's comfort counts only while it is fuelled.
3. **Clothing tier 1** for everyone: outdoor winter work builds exposure, and heated breaks clear it.
4. **Reaching winter:** add a **"Skip to next season"** control (Demo Lab F8 and/or the speed or menu area, following
   the existing conventions). It advances the calendar cleanly to day 1 of the next season, letting systems catch up
   deterministically (crops, stores, weather) or documenting what is skipped. The spring opening stays.
5. **The HUD:** restore "Heating fuel: N days" / "No current heat demand" per UI-SET-003, with a warning state under 2
   days. Planks move to the stores ledger and the tooltip.
6. **The pre-winter target:** 12 winter days of projected demand (homes × 4 U, plus the cooking mean). Show it in
   autumn as the REQ-SET-114 projection, with progress.

The brief's interactions: bed allocation prefers heated homes; the planner gets a Fuel lane with the winter demand and
the last heated hour; the work board an automatic "Firewood" gather/fell order under the woods activity, Urgent below 2
fuel-days through the existing bucket; the guide a help topic and a fact, no new objective; notices for a cold home,
out of fuel and Chilled; the fuel metrics exposed for the balance sim.

### Derived choices

These are this record's, not Brendan's; each is the narrowest reading that makes the rulings and the GDD agree.

- **The hall has a hearth.** GDD §5.8 prices "one normal residence/hall hearth", and REQ-SET-133 sends the bedless to
  "a reachable heated hall". The demo opens with no burrow homes, so without the hall a first winter would have no heat
  demand ("No current heat demand" while everyone freezes) and nowhere for ruling 1's warm-up break. The hall is one
  more hearth source after the eight home rows; each hour the homes take their wood first, in row order, then the hall,
  each all or nothing.
- **Hearth states.** NONE (no hearth), BANKED (the player let it go out), IDLE (no demand today), HEATED (demanded, the
  hour's wood taken), OUT (demanded, the stores could not give it). The **glow** (`hearth_lit`) is HEATED, day or night
  -- "fuelled AND demanded"; how it looks by hour is the lighting's, which reads the query. A consequence: with the
  winter bound a hearth is dark when no heat is demanded (a 12 °C spring night). Without a winter bound (a suite's
  village) the old 19:00–07:00 rule stands. **Comfort** counts a hearth unless OUT or BANKED: "fuelled" means "not
  lacking fuel", so a summer home keeps its hearth's comfort. A bed is **warm** while its home is HEATED or no heat is
  demanded.
- **The accumulator.** Each demanded hour adds the day's rate (milli-U a day) to the hearth's accumulator and takes
  `acc / 24`; an OUT hour gives its share back. Exactly the day's rate over 24 hours, no drift.
- **Temperatures.** The day's §5.10 temperature is the farm's real row's for that day's active event (an early frost's
  −3 °C is absolute; heavy rain's is baseline −3 °C). The hour's air is that, pulled down by the demo's frost nights
  (`farm_weather.gd`). The **daily mean** is the floored mean of the day's 24 hourly airs, so a frost night's day
  demands heat: spring 12 °C with a frost night means 9.5 °C, autumn's 10 °C means 7.8 °C. (Found by the review, H1:
  with the mean taken as the bare day temperature, a frost night chilled the hall's sleepers in a season of no demand,
  with no heated place anywhere to clear it.) A room without heat converges halfway to the air with the odd tenth taken
  toward the air, so it reaches it. REQ-SET-147's forecast is the coldest of today's
  mean, the next two days' (an event only once REQ-SET-142 has announced it) and the announced frost nights.
- **Where a resident is.** Outdoors or in the water: the air. Indoors (only the bedless sleeper, or a break, goes
  indoors, at the hall): the hall. Below, inside a dug home's void on its level: that home. Anywhere else below (tunnels,
  cellars): neither gain nor clear. Hard freeze doubles the gain outdoors and in an unheated room alike (§5.2's "base
  cold gain" in hard freeze). Integrated each frame over the calendar ticks the frame brought, with a signed remainder
  (§5.2); a frame bringing more than a game hour (a skip) is not lived.
- **Chilled's lines and the cap.** Entered at 4 exposure-hours (needs.gd `COLD_DAMAGE_HOURS`), left only at 0 (warmed
  through), so it does not flicker at the line. Exposure is capped at 8 exposure-hours: without REQ-SET-018's health
  loss an uncapped count would keep a resident Chilled for days after the fire was relit.
- **The 80%** is §5.10's heavy-rain outdoor-work factor (`weather.gd EVENT_OUTDOOR_WORK_PER_1000`), credited through
  `resident_brain.gd work_credit` (a remainder kept) where outdoor work is credited: the farm, the woods, the bridges and
  the spoil heaps. Sheltered work (tunnels, fit-out, the kitchen) is not slowed.
- **The warm-up break** goes to the resident's own bed's home if heated, else the nearest heated home it can reach, else
  the hall if heated; with none it keeps working at 80%. It parks the job as the night does, ends warmed through or when
  that fire goes out, and dusk replaces it with bed. A resident asleep, in the water, crossing, or in an emergency is not
  sent. The party panel's "Why" says it (`demo_people.gd` asks a task for its own `why()`).
- **Roots and the Hearth feast** (−25% buildup) are not applied: the demo has no ingredient effects and no feasts.
- **The Firewood order.** One at a time on the woods' board (forest_jobs.gd `ORIGIN_FIREWOOD`): the deadfall pile nearest
  the log stack, else the nearest fellable mature tree in a forestry zone (never a conservation zone, never an unzoned
  tree). Wanted while the wood is under the twelve-day projection in autumn or winter, or on any day heat is demanded.
  Listed under Woods whatever its kind. Marked Urgent on the work board (its bucket 2, systems_architecture.md's
  food/fuel bucket) under 2 fuel-days or while a hearth is out -- REQ-SET-131's urgent refuel job -- written only when
  that changes, so a player's own mark holds between changes.
- **The HUD.** The cell prints "N.N days" (a floored tenth) or "No demand": UI-SET-003's "No current heat demand" does
  not fit the 104 px cell, so it is the tooltip's, the ledger's and the breakdown's. Warning: the value in clay and the
  shell's warning glyph. The ledger keeps its length (the shell's ledger is a fixed size): Heating fuel is one line, and
  the planks ride on Wood's line ("Wood: 40.0 U · planks 2.5 U in store", measured to fit the ledger's 296 px line)
  and in Wood's tooltip. The cell's click opens the **fuel breakdown**
  (UI-SET-003: "opens fuel breakdown"), a modal holding the figures and the emergency choices.
- **The projection** (REQ-SET-114, ruling 6) is the fuel half -- every burning hearth at 4 U a day plus the cooking mean,
  for 12 days. The food half stays the kitchen's Ready food. Shown in autumn and through winter (the breakdown, the
  cell's tooltip, the planner's Fuel lane on autumn's last day), and posted at autumn's first dawn.
- **REQ-SET-149's summary** is a ROUTINE incident pinned on the top-centre card at the first winter's 06:00 (the hour a
  skip lands), resolved a day later and gone when the player dismisses it. "Outdoor staffing" is the residents on any crew
  but the Diggers.
- **The emergency actions** (GDD §5.10, "consolidate residents into heated halls"): Consolidate PACKS the sleepers into
  the fewest homes with a hearth that hold them (heated homes first, then the roomiest, the lower row on a tie), allocates
  beds with those as the warm ones (anyone asleep sent to the new bed), and lets the hearths of homes nobody then sleeps
  in go out; per-hearth Let it go out / Light it again. Only the player takes them. A banked hearth stays banked until
  the player lights it again.
- **Cold-home warnings** are raised only for a home with a hearth, while heat is demanded: elsewhere wood would not help.
- **The fishery is not slowed by Chilled.** Its trips run on the fishing driver's own ticks, not on a worker's credited
  work, so the 80% is not applied there; a Chilled fisher still warms up between trips.
- **The skip** lands at 06:00 on day 1 of the next season, exactly on the tick (the calendar's carried remainder
  accounted). The farm's hours and the hearths' run in lockstep, each on its own day's weather. The kitchen skips
  quietly (`kitchen.gd skip_to_hour`): no meal called, cooked or eaten, hunger held, the table's portions aged; the
  skipped days are not counted as days without cooking in the fuel-days' three-day mean (`rebase_cooking`). The
  settlement clock forgives the skip's real time (its host-clock field re-based by name, checked, with a test that fails
  on a rename), so it is not reported as a stall. The demo clock's next frame still
  carries that real time (a fraction of a game hour at 4x).
- **"A fact"** in the guide is read as a field-guide entry ("Hearths and heating fuel", built from `winter_rules.gd`'s
  figures) beside the help topic, since the guide's outcome facts exist only to complete objectives and none is added.
- **The metrics** for the balance sim: `demo_village.winter().metrics_into(out)`.

## Why

The rulings fix the rates, the Chilled consequence and the UI; the GDD fixes the rest. Where the two meet, the demo
already had most pieces -- the one calendar, the real §5.10 row, the stores' wood, the kitchen's 0.1 U a batch, the
work board's urgent bucket, the incidents -- so the winter reads them rather than keeping copies, and adds one pure model
per concern (`winter_rules.gd`, `hearth_fuel.gd`, `cold_exposure.gd`) that the suite drives hour by hour.

## Consequences

- The fuel cell is the winter's; decision 0251's "Fuel's slot holds Planks" is superseded on that point.
- The 19:00–07:00 hearth hours remain only for a village without the winter.
- Changing a rate means changing `winter_rules.gd` (and `needs.gd` for exposure), never a copy.
- The lighting reads `night_routine.gd hearth_lit(r)` (or `tunnel_ext.gd hearth_lit(r)`, which `fixture_view.gd`'s
  `set_lit` now calls per home); the hall's is `hearth_fuel.gd hearth_lit(HALL)`.

## Source

Brendan's rulings of 2026-10-01 (above); GDD §5.2, §5.8 (fuel-days), §5.9 (tier 2), §5.10 (seasons, events, failure
table), REQ-SET-018/019/114/119/130/131/132/133/147/149; `ui_ux_controls.md` UI-SET-003 and §7's warning table;
`systems_architecture.md` ARCH-STATE-005's food/fuel bucket; `gameplay_balance.md` (wood, 5000 g a unit).
