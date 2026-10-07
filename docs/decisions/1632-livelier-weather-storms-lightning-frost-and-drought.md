# 1632 — Livelier weather: storms with lightning, frost, drought, and the storm's work factor applied once
Date: 2026-10-07 · Status: Accepted (the rules used are adopted; the PROPOSALS below wait on Brendan)

**Numbering.** The handoff's packet assigns WEATHER decisions 1291–1300 (`docs/handoff/BACKLOG.md`, "WEATHER"). The
lead remapped this lane to **1631–1649**, because a parallel digging branch already uses 0991–1217 and the packets'
ranges from 1101 collide with it. Wildlife is 1631; this record is 1632.

## Decision

Each of GDD §5.10's seven events is now shown and felt in the live demo, by its numbers:
- a **storm** (heavy rain) drives the rain slant and brings lightning over the trees and open ground;
- a **drought** parches the grass;
- an **early frost** and a **hard freeze** lay frost through their days;
- the village is told when each event **begins and ends**, with what it does;
- the forecast now says the event's **start, duration and effects** (REQ-SET-142);
- the storm's **outdoor work ×0.80** is applied **once**, through the village's work pace, instead of by two crews
  privately.

It uses art pass 3's effects (decision 0971): `fx/lightning_fx.gd` and `fx/fire_fx.gd`.

Feature #34, approved by Brendan on 2026-10-01 in the feature list ("FEATURE SCHEDULER"). That approval is recorded only
in the coordinator's tracker; `docs/handoff/RULINGS.md` is its first repository record.

## The rules used

- **GDD §5.10's event table**, read from `scripts/core/weather.gd`'s compiled tables, never mirrored:
  `EVENT_TEMPERATURE_*`, `EVENT_RAIN`, `EVENT_EXTRA_EVAPORATION`, `EVENT_CROP_DAMAGE_PER_DAY`,
  `EVENT_CROP_GROWTH_PER_1000`, `EVENT_OUTDOOR_WORK_PER_1000` and `EVENT_EXPOSURE_PER_1000`.
- **What was already applied, and stays where it is:**
  - the farm's temperature, rain, evaporation, crop growth and blight damage (`farm/farm_sim.gd` on the real row);
  - the storm's and the hard freeze's boat closures (`fishery/fishery.gd`, `ferry/ferry_rules.gd`, REQ-SET-052 and
    REQ-SET-144);
  - the hard freeze's exposure ×2 (`winter/demo_winter.gd`);
  - the drought's orchard watering (`orchard/orchard_jobs.gd`);
  - the storm's blow-down (`forestry/demo_forestry.gd`).
- **REQ-SET-142**: "disclose its start, duration, and affected systems three days in advance". The farm's forecast line
  named only the event. It now names the event, its first day, its length and its effects
  (`weather/weather_events.gd` `forecast_text`).
- **The storm's ×0.80, once** (the packet's acceptance; GDD §5.2 composes work factors by multiplying):
  - Before this, the woods (`forest_crew.gd` `step_usec`) and the bridge builders (`bridge_crew.gd` `_usec_per_wu`)
    each slowed their own storm work, and no other crew did.
  - Now the village's one work pace (`work/work_pace.gd`) carries a factor named "storm" (`weather/storm_pace.gd`).
    It is 800 for a resident outdoors on a storm day, and 1000 indoors or below ground.
  - The two private copies are gone. The factor reaches every crew that credits work through the brain
    (`work_credit`): the farm, the woods, the bridges and the spoil. The brain's `work_permille` is the work pace's
    product, written each running frame by `demo_winter.gd` `follow_exposure`; the live harness checks a resident
    outdoors reads 800 after a storm's frames.
- **GDD §5.9**: "no additional random disaster, structure fire, siege or raider simulation exists in release 1". So
  lightning never strikes a building and nothing burns down (see P1).
- **Photosensitivity** (WCAG 2.3.1, as `lightning_fx.gd` already states):
  - The flash runs in real time at any game speed.
  - Strikes are at least 3 real seconds apart.
  - Reduced motion gives one soft swell (decision 0471).

## What was built

| File | What |
|---|---|
| `godot/demo/weather/storm_pace.gd` | the storm's work factor on the village's work pace |
| `godot/demo/weather/weather_fx.gd` | the lightning (targets, scheduling, real-time flash), the pooled smoulder, the event notices; `wire` (the village's hook) |
| `godot/demo/weather/weather_events.gd` | each event's effects in words from the real tables; the forecast; the begin and end notices |
| `godot/demo/weather/event_look.gd` | each event's look: frost floor, dryness, haze, sun, the rain's slant |
| `godot/demo/weather/weather_view.gd` | eases toward the day's event look on top of the hour's condition |
| `godot/demo/world/demo_ground.gdshader` | a `dryness` uniform (0 draws exactly as before): the drought's parched grass |
| `godot/demo/farm/farm_alerts.gd` | the forecast line says start, duration and effects |
| `godot/demo/forestry/forest_crew.gd`, `godot/demo/waterplay/bridge_crew.gd` | their private storm factor removed |
| `godot/test/test_demo_weather_fx.gd` | 22 tests |
| `godot/test/test_demo_forestry.gd` | one test: the crew's own timing is not slowed on a storm day |
| `godot/test/live/demo_weather_live.gd` | the live harness and its frames |

**Shared files touched:**
- `godot/demo/demo_village.gd`: a `WeatherFxScript` const, a `_weather_fx` var, a `_build_weather_fx()` call in
  `_ready` after the wildlife's, and that six-line builder (make it, add it, `wire` it with the woods' `stand.state_of`).
  `wire` adds the storm factor to the work pace.
- `godot/demo/farm/farm_alerts.gd`: the forecast line.
- `godot/demo/world/demo_ground.gdshader`: one uniform pair and one guarded mix.
- `forest_crew.gd` and `bridge_crew.gd`: as above.

**No key** was added.

### Each event, shown and applied

| Event (§5.10) | Applied (where) | Shown |
|---|---|---|
| Heavy rain / storm | rain +2000, −3 °C (farm); boats disabled (fishery, ferry); **outdoor work ×0.80 (work pace, once)** | driven rain, the storm's gloom, lightning, a struck tree's smoulder; notice |
| Drought | 30 °C, rain 0, −1500 moisture a day (farm); orchards need water (orchard) | parched grass, heat haze; notice |
| Blight | 400 crop damage a day (farm) | the farm's blighted beds; notice |
| Early frost | −3 °C, frost (farm) | a rime lying through its days; notice |
| Hard freeze | −12 °C (farm); exposure ×2 (winter); no boat departs | a heavy hoar frost, freezing mist, a low cold sun; notice |
| Calm days | none | notice ("no change: a safe interval") |
| Ideal spell | 18 °C (2 °C in winter), growth ×1.20, rain +600 (farm) | a little brighter; notice |

### Cost

- **Built once.** `weather_fx.gd` builds the bolt and two fires in `configure`. A storm frame allocates no Object
  (`test_a_storm_frame_allocates_no_object`, strikes included).
- **Particles.** The fires hold 2 × 54 particles, outside the warren's 200, as `art_pass3_mapping.md` asks. Reduced
  motion cuts them (`demo_motion.gd`).
- **Per frame:**
  - the event's look eases a handful of numbers;
  - the rain's slant is written only on a change;
  - a strike search runs only when a strike is due: one pass over about 300 targets (173 trees, the rest open ground),
    with a distance check per resident; when none is allowed the next try waits 5 s;
  - the bolt's and the fires' speeds are handed over only when they change (`fire_fx.gd` `set_speed` builds an
    array).

## PROPOSALS for Brendan

- **P1 (Q-D15). Where lightning strikes.** Built as Q-D15's recommended option (a):
  - It strikes trees still standing (not a stump or cleared: the woods' stand, `forest_stand.gd` `state_of`), or open
    ground off the water and at least 6 m from every building: the village's, the water-side ones (the mill, the
    boathouse, the shelter, the weir: `water_dressing.gd`), the leat head, the orchard's stands, and every structure
    standing at the moment of the strike, the player's included (`cast_space.gd` `structure_circles`).
  - It never strikes a building, and never within 6 m of a resident on the surface.
  - No fire spreads.
  - Options: (a) as built; (b) lightning may start a fire.
  - Recommendation: (a). The GDD's §5.9 rules out a structure fire in release 1.
- **P2. A struck tree smoulders briefly.**
  - A strike on a tree leaves a small flare at its foot, 0.8 m across. It catches, burns half a second and dies down in
    the rain, about 13 demo seconds in all.
  - It damages nothing.
  - Options: (a) as built; (b) no fire at all, the bolt only.
  - Recommendation: (a). It is the art pass's fire effect, used without burning anything.
- **P3. The events' looks.**
  - The demo values in `event_look.gd`: the frost floors (early frost 0.35, hard freeze 0.9), the drought's parched
    grass, the hazes, the sun's shares, and the storm rain's slant (0.38 rad).
  - Options: (a) as built; (b) adjust any.
  - Recommendation: (a).
- **P4. Lightning frequency.**
  - A strike every 5–12 demo seconds while a storm day rains: about two to five a game hour.
  - Strikes land within 16 m of where the camera looks, so the player sees them.
  - Recommendation: as built.

## Gates

Run on 2026-10-07 on a loaded machine (load average 21–27).

- **Focused suites:**
  - `test_demo_weather_fx.gd`: 22 tests, 0 failures.
  - With `test_demo_forestry.gd`, `test_demo_farm.gd` and `test_demo_farm_alerts_bound.gd`: 140 tests, 0 failures.
  - Diagnostics: 0 unexpected, 0 leaked. The tolerated lines are the fires' particle restarts outside the tree.
- **Live harness** (`test/live/demo_weather_live.gd`), at 1920x1080 and 1280x720: `LIVE-SUMMARY 16 0` each. It checks:
  - the storm factor is on the work pace once;
  - the driven rain;
  - an outdoor resident at 80%, on the work pace and then on its brain after running frames;
  - the storm's notice with its effects;
  - a strike near the view, and one on open ground;
  - the flash at its peak;
  - a struck tree smouldering;
  - no target at a building;
  - the drought's parched grass, the early frost's rime and the hard freeze's hoar frost;
  - calm days changing nothing.
- **Frames looked at** (session scratchpad `weather_check/frames_final2/`, not committed):
  - the storm;
  - the lightning bolt;
  - a struck sapling's smoulder;
  - the drought, the early frost, the hard freeze, blight, calm days and an ideal spell, all at noon.
- **Analyzer:** `0 GDScript warning(s)`. **Contracts:** all pass.
- **Mutation testing:** 40 mutants, one per run, against the focused suites.
  - The first round of 28 killed 22. Five survivors were real gaps, each closed by a new test:
    - a negative resident index;
    - the safety check skipped;
    - a smoulder on open ground;
    - the fire pool's idle check;
    - striking while paused.
  - One is equivalent: `TEMPERATURE_DELTA` against "not `TEMPERATURE_ABSOLUTE`". The only other mode, the baseline,
    belongs to events whose words name no temperature.
  - The second round of 12, on the review's fixes, killed 10. The 2 survivors were closed by new tests:
    - paused time counting toward the gap;
    - the retry wait.
  - Final: 39 killed and 1 equivalent. `SURVIVED_MUTANTS: none` (the equivalent one is declared).
  - Not mutated in the unit suite: `wire` adding the factor. The live harness checks it, because `wire` needs the
    whole cast.
- **Independent review** (`code-reviewer`):
  - **C1:** the bolt's and the fires' `set_speed` were called every frame, and `fire_fx.gd`'s builds an array.
    - Fixed: they are handed over only on a change.
  - **H1:** lightning could strike within the water-side buildings and next to player-built structures.
    - Fixed: the exclusions above, rechecked at each strike.
    - The test checks the water-side footprints independently.
  - **M1:** other outdoor work credits raw time.
    - Recorded as a follow-up below.
  - **M2:** paused time counted toward the 3 s.
    - Fixed: the gap counts running time only, and a test covers it.
  - **M3:** felled trees stayed targets.
    - Fixed: the stand is consulted.
  - **M4:** test gaps.
    - Covered: the forecast on the real farm row (the first spring's ideal spell from Spring 6 for 3 days), and the
      brain check in the live harness.
  - **M5:** effects missing from the text.
    - Fixed: the season's ideal-spell temperature, blight's summer mussel closure, and the hard freeze's "only the ice
      is open".
  - **The LOWs:**
    - the target count and the stroke wording are corrected;
    - the dead `_weather` members are recorded below;
    - `is_safe`'s indoor clause and the rain's direction now have tests;
    - `dryness` is written only on a change.

## Follow-ups (not built here)

- **Foraging still applies its own storm factor.**
  - Its trips (`forage/forage_trips.gd`) do not credit work through the brain, so they do not read the work pace.
    `forage_rules.gd` therefore keeps its private ×0.80.
  - The fix is to move the foraging trips onto the work pace and drop the private factor. The SKILLS packet changes the
    same files.
- **The action card's predicted time ignores the work pace.**
  - The woods' action card predicts a storm-day step at full pace; the work then runs at 80%.
  - It ignores the Chilled and health factors in the same way.
- **River and pond ice from the ice shader** (`water/water_ice.gdshaderinc`) belongs to the WATER packet.
  - The packet lists WEATHER's river ice as depending on WATER.
  - The pond's ice is already drawn by `fishery_view.gd`'s sheet, which the shader is to replace.
- **Thunder.** The demo's sound library has no thunder cue. Adding one needs a download, which group R asks Brendan
  before each one.
- **Other outdoor work credits raw time and so is not slowed by the storm (or the Chill, or health):**
  - the infirmary's builders (`infirmary/infirmary_builders.gd`);
  - the hall's crew (`hall/hall_crew.gd`);
  - the orchard's jobs (`orchard/orchard_jobs.gd`).

  Routing them through `brain.work_credit(usec)` would apply all three factors once. That is a change in those owners'
  pacing, so it is left to their owners or the SKILLS packet.
- **`bridge_crew.gd` and `forest_crew.gd` each keep a `_weather` member** they no longer read for timing, set by
  `configure`. Their signatures are left alone, because other code calls them. `forest_crew.gd`'s `speed_pm` in
  `step_usec` is now the constant 1000, kept so that `forest_rules.gd` `work_usec`'s signature stands.
- **The effects text is written per event**, from the real tables, rather than derived from `forecast_effect_mask()`.
  It names the season-conditional effects (the ideal spell's winter temperature, blight's summer mussel closure) when
  it knows the season.
