# 0541 — A day and night lighting cycle on the demo calendar
Date: 2026-10-01 · Status: Accepted

Numbered 0541. The brief reserved 0541–0549. No branch, worktree or the main checkout held a 054x record (the highest
was 0533). Brendan approved the feature on 2026-10-01. Everything here is presentation: nothing reads the light to
decide an outcome, and no gameplay hour moves.

## Decision

The world's one light, its sky, ambient and haze follow the demo's one calendar (`demo_calendar.gd`, 25 s a game hour at
1x; decision 0421) through dawn, day, dusk and night. The weather sits on top. A small pool of night lights burns at the
homes and the tunnel mouths, and the HUD's date trigger shows a sun or a moon. The underground keeps its own look. Four
new files under `godot/demo/world/` hold it:

| File | Holds |
|---|---|
| `daylight_curves.gd` | THE DATA: every tunable, as named curves at four keys (NIGHT, DAWN, DAY, DUSK) and named constants |
| `daylight.gd` | The sampler: a moment and a season into one reused `Sample`; pure, allocating nothing |
| `day_night.gd` | The cycle: writes the sample (and the weather) onto the sun, the sky and the environment, and lights the lamps |
| `night_lights.gd` | The surface's pooled night lights |

## 1. The hours: the GDD's daylight, the brief's spring windows

- **Sunrise and sunset are the GDD's §5.10 "Daylight" column.** Spring 06:00–19:00, summer 05:00–21:00, autumn
  07:00–18:00, winter 08:00–16:00 (`SUNRISE_MIN`, `SUNSET_MIN`). The brief asked for the seasons to shift the times
  "if the GDD or calendar defines them". The GDD does, so they shift.
- **The windows.** Dawn runs an hour either side of sunrise. Dusk runs two hours on from sunset. In spring, where the
  demo opens, that gives exactly the brief's dawn 05:00–07:00 and dusk 19:00–21:00. Each curve eases (smoothstep) from
  NIGHT to DAWN over the dawn's first half and from DAWN to DAY over its second, and the same way through dusk.
- **Why the windows are asymmetric about the GDD's times.** The brief fixed spring's dusk at 19:00–21:00 and its dawn at
  05:00–07:00. The GDD's spring daylight ends at 19:00 and begins at 06:00, so the GDD sunrise is the middle of the dawn
  and the GDD sunset is the start of the dusk. The other seasons keep the same shape around their own times.
- **Every window lies inside its own day.** The latest dusk ends at 23:00 (summer) and the earliest dawn begins at 04:00
  (summer), so midnight is night in every season. The season changes at midnight (REQ-SET-141: "daylight ... at the
  exact boundary"), so the change shows nothing.
- **The sun's height is fixed.** Neither the GDD nor the calendar states it. So the peak (`SUN_PEAK_DEG` 57°) is the
  same all year, and only the hour of the peak moves. The peak was chosen so that half past ten in spring stands at
  about 50°, the late-morning sun the world was reviewed under (decision 0196, `world_look.gd SUN_TOWARD`).
- **Gameplay hours do not move.** The night routine (dusk 20:00, dawn 06:00), the hearths (19:00–07:00), the songs'
  evening (19:00–22:00) and the kitchen keep their own hours (decisions 0210, 0421, 0442, 0381). In winter, residents
  work on after dark until 20:00. That is the GDD's own picture ("unlit outdoor productive work×0.75 in darkness"),
  though the demo applies no darkness penalty.

## 2. One light: the sun by day, the moon by night

- **The world's one DirectionalLight3D is both.** Its direction blends from the moon's (`MOON_TOWARD`, high in the
  south-west) to the sun's by `SUN_WEIGHT`. The sun's arc runs from the east at sunrise, through due south in the
  middle of the daylight, to the west at sunset, and is never lower than `LIGHT_MIN_DEG` (12°), so shadows stay sane.
  Outside the daylight the arc holds at its ends.
- **A second light was rejected.** A separate moon would double the directional shadow cost or need its own shadow
  switch. One light needs neither. Its direction swings only in the darkest half of each twilight, when its energy and
  shadow are low.
- **The shadow** fades through `SHADOW` (`shadow_opacity`). Below 0.02 the shadow pass is switched off (`shadow_enabled
  = false`), so the whole night saves it. A gloomy sky softens the shadow further (`GLOOM_SHADOW`).
- **The shadow is off while the light swings.** It is off from the middle of the dusk to the middle of the dawn. Those
  are the halves in which the light's direction swings between the moon's and the sun's. The shadow fades in over the
  dawn's second half and out over the dusk's first, when the direction moves little.
- **Why: the review found a visible shadow jump.** The first curve kept a 0.28 shadow at 05:30, where the swing moved
  the light about 2° per write. That was a shadow visibly jumping every 0.43 s at 1x. Now the largest step with a
  shadow on is about a quarter of a degree, the sun's own travel in a game minute.
- **The DAY key is the world's own reviewed look** (decision 0301's targets): the sun's energy and colour, the sky's four
  colours and energy, the ambient's energy and sky share, the haze's colour and density, the saturation and exposure
  are `world_look.gd`'s values exactly. A constant cannot call `lerp`, so the sky's and haze's mixes of the base tones
  are written out, and `test_the_day_key_is_the_world_s_own_look` holds them to `world_look.gd`. Only the sun's
  direction moves through the day.

## 3. Night stays playable, and Brighter nights

- **Moon and starlight read the village.** At night the sky gives only 20% of the ambient (`SKY_SHARE`). The rest is a
  moonlit blue (`AMBIENT_COLOUR`) at energy 0.72. The moon is a soft key light (0.4), the exposure is 1.08 and the
  saturation 0.78. The paths still read lighter than the grass, and the selection rings and marks are unshaded, so
  they read at any hour. The frames at 23:00 (a resident selected and walking the hall path) show it.
- **Unshaded things in the world's light take the hour's tint** (`UNLIT_TINT`): the rain streaks, the snowflakes and the
  chimney smoke. They darken with the evening instead of glowing in the night. Marks and rings are never tinted.
  - **Each chimney's smoke is tinted on its own particles** (`CPUParticles3D.color`, which multiplies the colour ramp;
    `fixture_view.gd set_smoke_tint`). A chimney built later takes the current tint.
  - **The shared, cached puff material is never written.** The first cut wrote it, and the review rejected that: a
    static resource outlives the scene and is read elsewhere.
- **Brighter nights** is a new accessibility setting (`demo_access.gd SET_BRIGHT_NIGHTS`, off by default) with a
  toggle in Settings. At full night it raises the ambient 1.75 times and the moon 1.5 times, gives the sky 0.1 less of
  the ambient, and adds 0.22 to the exposure. All four scale with how much night there is (the LAMPS curve), so noon
  is untouched and twilight is raised in part. **It is part of the Large readable preset**, whose purpose is
  readability. That changes the preset's diff ("… · Brighter nights off → on"), and `test_demo_access.gd` says so.
  The cycle reads the flag directly, and it writes the moment the flag changes.
- **Reduced motion** affects only the lamps' flicker. The flicker is gentle (±5%, 0.9 and 2.3 Hz) and holds steady with
  reduced motion on. It runs in real time, so 2x and 4x do not quicken it, and only while the demo clock runs: paused,
  the lamps hold still and nothing is written.

## 4. The weather on top of the hour

- **One writer.** The weather view used to write the sun's energy and the haze. Now the cycle writes both. It reads the
  weather view's eased `sun_share`, `fog_add` and new `gloom`, and sets the view's `drives_light` false. So the weather
  multiplies the time of day instead of fighting it every frame. Without a cycle (the suites' fixtures) the view
  writes its light as before.
- **Gloom** (`weather_view.gd GLOOM_*`, eased with the rest). An overcast dry hour of a wet day gives 0.35, rain 0.6, a
  storm 1.0 (rain on a day whose own figure is the GDD's heavy rain, `DOWNPOUR_RAIN` or more) and falling snow 0.45.
  Clear and frost give none. At full gloom the ambient and sky lose 35% of their energy and the saturation 35%, the
  shadow loses 60% of its opacity, and the sky, haze and ambient colours go 70% of the way to their own grey. This
  works whatever the hour: a rainy dusk is a darker, greyer dusk.
- **Frost and snow at night.** The cover (decision 0301) is lit like the surface under it, so at night it reads a pale
  moonlit blue (frame 07). The flakes take the night's tint.

## 5. Night lights, and the light budget

- **A surface pool of at most 8** (`NIGHT_LIGHTS`) shadowless omni lights, made once, on the SURFACE layer and lighting
  only the surface view. They go to the spots nearest the camera's focus, and are reassigned only when the spots change
  or the focus has moved 2 m. However many lanterns and homes there are, at most 8 pools are lit. This is the same
  rule as the underground's 32-light pool (decision 0207), which this does not touch.
- **The spots.**
  - **The five homes' doors**: the hall, the three residences and the kitchen, 0.55 m out from each front, 1.1 m up.
  - **Every standing tunnel mouth's lantern**: the staged arch's glow, or the procedural gateway's lantern
    (`tunnel_overlay.gd lantern_spots_into`, read twice a second).
- **Which homes are lit is one query** (`night_lights.gd set_home_lit`): `lit(k) -> bool`, for home k in
  `LIT_HOMES` order (the hall, three residences, the kitchen), read twice a second.
  - **Without a query**, every home is lit while the lamps are. That is this branch.
  - **The winter fuel lane** (`feat/demo-winter-fuel`) defines a lit hearth as "fuelled and demanded":
    `tunnel_ext.gd hearth_lit(r)` over `night_routine.hearth_lit(r)` for a home, `demo_winter.fuel.hearth_lit(HALL)`
    for the hall. Integration wires the query to that, and an unfuelled home stands dark.
  - **The underground hearth's glow and smoke** stay `fixture_view.gd`'s, driven by its own `set_lit`. That branch
    makes `set_lit` per home, so this cycle never decides whether a hearth burns.
- **No window glow.** The brief allowed window glow "if the building models have window materials or emissive slots".
  They do not: every building GLB (residence, hall, kitchen, covered store, workbench, well) carries one surface with
  one `BakedMaterial`. Tinting that would light the whole wall, and no new asset was to be made. So a home reads lit
  by lamplight spilling from its front.
- **Glow (bloom) is on in the surface environment while the lamps are lit** (soft-light, threshold 1.0, intensity 0.55
  at full night). The mouth lanterns' emissive glass and glow then bloom. The glow is off by day, so the day look is
  unchanged.
- **Hearths.** Their glow below is the underground pool's own (decision 0210), unchanged. Their chimney smoke on the
  surface takes the night's tint.

## 6. The underground is not touched

The U view wears its own Environment on the camera (decisions 0206/0207). The cycle never writes it. The light lights
only `SURFACE_VIEW` (`tunnel_view.gd set_world`), and the night lights sit on `SURFACE` and light only `SURFACE_VIEW`,
so the U view culls both. The suite (`test_the_underground_is_never_touched`) and the live harness check that the U
view's environment keeps every value through the day and at night, and that the camera culls the moon and the lamps
below.

## 7. How often, and the cost

- **A write moves the sky.** The procedural sky reads the light (its sun disc), so its radiance is redrawn
  (incrementally) after a change. So the cycle writes only:
  - when the calendar has moved `APPLY_TICKS` (13 ticks, about a game minute: 0.43 s at 1x, 0.11 s at 4x);
  - when the weather's eased look has moved: the share or the gloom by `WEATHER_STEP` (0.02), the haze by
    `WEATHER_STEP_FOG` (0.0002). Such a write comes at most every `WEATHER_EVERY_S` (0.25 real seconds), so a
    weather's 3 s ease is about a dozen writes. The second review found it writing every frame at 4x;
  - when Brighter nights changes;
  - when the season changes.

  A twilight is about 120 steps. While paused, nothing is written.
- **Nothing is allocated.** A write fills one reused Sample and sets properties. The suite runs 2000 frames at 4x's tick
  rate, with the weather easing and the lamps flickering. No object and no static memory is kept, and a frame costs
  12–14 µs on average, writes included (headless, Apple Silicon).

## 8. The prewarm

The boot (decision 0205's prewarm) is held at two moments:

- **Noon for every frame step before the night's** (`begin_day_prewarm`, called before the steps are listed). The demo
  opens at 06:00, sunrise, where the shadow is off. Without this hold every boot frame (the rooms on the ground, the U
  view, the canopy, the frost overlay) would draw shadowless, and the shadowed pipelines would first be used a couple
  of seconds into the morning. The second review measured that: the first shadowed write fell at tick 65. Held at
  noon, the boot draws the world as it drew it before this cycle.
- **Midnight for a last frame step, "the night's light"** (2 frames): the shadowless moon, the glow on, every night
  light lit, and the frost and snow overlay worn (drawn, with no cover). The night's pipelines compile behind the
  opening pause. The step's end gives the calendar's own hour back, sunrise, before the clock starts.

Turning the directional shadow off can change the scene shaders' specialisation, and the glow is a post-process the
surface never drew before, so both moments matter. The live harness runs the boot's own sunrise at 1x, untouched, to
06:06: the shadow comes on with no stall pause.

## 9. The HUD

The date trigger's 24 px glyph (UI-SET-101) shows a sun by day and a moon by night.

- **It replaces the calendar glyph while the demo runs** (`ui_shell.gd ICON_OF_ELEMENT`'s `calendar`). The trigger
  keeps its text, its "Open calendar" accessible name and its action. The shell, which the game uses, is untouched.
- **The glyphs** are drawn from SVG text in the HUD's own line-icon style (a 2 px cream stroke, as `ui/icons/*.svg`)
  and made once. They are set only when they change.
- **The sun shows** while the light is mostly the sun's and the lamps are at most half lit.
- The UI skin is not otherwise affected by the 3D lighting.

## Verification

- **Frames** (1920x1080, one fixed camera on the square, `test/live/demo_daylight_live.gd --capture`): 06:00, 12:00,
  19:30, 23:00 with a resident selected on the hall path, 04:30, a rainy dusk (spring 2, a spell's wet day), a snowy
  night, the underground at night, and the snowy night with Brighter nights on. Every frame was looked at.
- **Tests**: `test_demo_daylight.gd` (32 tests) covers:
  - the curve sampling exactly on every key's hour and continuously across every boundary;
  - monotonic dawn and dusk, the seasons' shifts, the sun's arc, the moon;
  - the day key held to the world's look;
  - each sky's gloom, gloom on every hour, the weather multiplying and the one writer, the falls and smoke tinted;
  - noon and midnight on the light, the write throttle, the underground untouched;
  - Brighter nights applied and part of Large readable;
  - the home spots and which homes are lit, the pool's cap and nearest-first choice, the level and the flicker;
  - the mouth lanterns read from the overlay;
  - the prewarm, the date icon, and nothing allocated.

  `test_demo_daylight_live.gd` runs the harness headless: 38 checks on the real scene, including the boot's own
  sunrise and Brighter nights pressed in Settings.
- **Performance** (`demo_daylight_live.gd --measure`).
  - **Setup.** Staged assets, 1920x1080, vsync asked off, the one camera, Apple Silicon. GPU timestamps read 0 on this
    Mac, so these are real frame times. The 8.3 ms floor looks like the display's 120 Hz pacing, which still held.
  - **Load.** Measured once the parallel agents' load had dropped. An earlier run under about 30 other Godot
    processes was about 1.5x slower throughout but kept the same relations.

  | Frames | Count | p50 ms | p95 ms | p99 ms | Max ms | Night lights lit | Draw calls |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | The boot's own sunrise at 1x, 06:00–06:06 (the shadow comes on) | 293 | 8.4 | 11.0 | 11.5 | 16.0 | 5 | 687 |
  | Noon, paused | 301 | 10.4 | 11.2 | 11.8 | 12.3 | 0 | 650 |
  | Midnight, paused, the pool full | 301 | 8.3 | 8.7 | 8.8 | 9.5 | 8 | 558 |
  | The boot's first dusk at 4x, 18:45–21:15 | 1385 | 8.4 | 19.6 | 20.7 | 22.1 | 5 | 554 |
  | A later dusk at 4x, the cycle on | 1412 | 8.4 | 18.9 | 19.7 | 34.0 | 5 | 556 |
  | The next dusk at 4x, the cycle stopped (control) | 960 | 16.3 | 17.7 | 18.1 | 22.3 | 0 | 642 |
  | Day at 4x, 13:00–15:30 | 1423 | 10.9 | 12.0 | 12.5 | 22.0 | 0 | 669 |
  | The U view at 23:00, just switched | 301 | 8.3 | 8.7 | 8.7 | 8.9 | 5 | 539 |

  - **The night is cheaper than the day.** The shadow pass is off, and that outweighs 8 lamps: midnight's p95 is 8.7
    ms against noon's 11.2, with 92 fewer draw calls.
  - **The dusk's tail is the village's.** It is everyone sent home and routed at 4x. With the light held, the same
    village's dusk has a p95 of 17.7 ms; with the cycle on, 18.9 ms, of which the night-cheaper second half takes
    back the p50.
  - **No stalls.** No frame of any run took 50 ms or more. The boot's sunrise, when the shadow first comes on, peaked
    at 16 ms, and the first dusk at 22 ms.
  - **Switching U at night does not stall.** The frames after the switch were 7.9–8.9 ms.
- **Mutation testing** (`light_check/mutate.py`, against the daylight, weather-cover and access suites). 95 mutants of
  the new logic: the sampler, the cycle, the night lights, the gloom, the overlay's spots, the setting, the data and
  the second review's fixes.
  - **94 killed.** The first run killed 78 of 89; a 90th, whose pattern had not matched, was fixed and killed. The 11
    survivors led to tests of:
    - the easing between keys;
    - the shadow's off-halves;
    - the grey's luminance;
    - a share-only weather write;
    - the tinter binding;
    - the prewarm's overlay;
    - the pool shown again after the lamps go out;
    - the flicker under reduced motion.

    Ten of them now die. All five mutants of the second review's fixes die (one after a further test of a
    reassignment's energies).
  - **One survivor is equivalent.** At exactly sunrise, `<` and `<=` give the same key and phase.

## Review

The independent `code-reviewer` agent found no CRITICAL issues and one HIGH: `test_demo_access.gd`'s Restore diff now
ends "· Brighter nights on → off". That is fixed. Its MEDIUM findings are also fixed:

- the haze's one writer is now tested;
- every value the cycle writes is checked on the real sun, sky and environment at five hours;
- gloom alone (an overcast dry hour) is shown to trigger a write;
- the shared smoke material is no longer mutated (above);
- the underground test now puts the U view's camera, with its own environment, inside the world the cycle searches.

The LOW findings fixed:

- the twilight shadow steps (above);
- the flicker now runs in real time, and stops while paused;
- the mouth cap is the tunnel rules' `MAX_MOUTHS`;
- the overlay is worn in the night's prewarm;
- the date glyph's replacement is recorded;
- more exact Brighter-nights, lamp-range and moved-mouth assertions.

A second review of those fixes found one more HIGH, now fixed: the boot drew shadowless (see §8). It also found a
MEDIUM: weather-triggered writes ran every frame at 4x, now limited (§7). Its LOW findings are dealt with as follows.

- **Fixed.**
  - A level change while paused now writes the lamps' energies at once.
  - A reassignment while paused writes them too, and is tested.
  - The tautological cull-mask assertion now checks that the cycle never writes the mask.
- **Dropped.** The "hand the light back on free" hook restored only the energy and haze, and nothing frees the cycle
  alone.
- **Known and left.**
  - The staged arch's glow branch of `lantern_spots_into` is covered only by the procedural gateway case.
  - The water's sky sheen (`demo_water.gd`) keeps the day sky's colours, read once at build. Its shader is lit, so
    at night it darkens with the scene. Feeding it the hour's sky is a follow-up.

## Follow-ups (not in this change)

- Feed the water's sky sheen (`demo_water.gd`) the hour's sky colours on each write.
- A staged-props test of `lantern_spots_into`'s arch-glow branch.
- At integration, wire `night_lights.gd set_home_lit` to the winter fuel lane's "fuelled and demanded" hearth query.
- The demo's pause card can stay tall after the guide card hides (seen in the frames; pre-existing, `demo_pause_card.gd`).

## Files touched outside `demo/world/`

- `demo/weather/weather_view.gd`: gloom, `drives_light`, `fog_add`, `set_unlit_tint`.
- `demo/access/demo_access.gd` and `access_settings_ui.gd`: the setting and its toggle; Large readable.
- `demo/tunnel/tunnel_overlay.gd`: `lantern_spots_into`.
- `demo/burrow/fixture_view.gd`: `set_smoke_tint`, so each chimney's own particles are tinted.
- `demo/demo_village.gd`: built after the shared UI, plus the prewarm step and accessors.
- `test/test_demo_access.gd`: the Large readable diff.
- `godot/demo/README.md`.
