# 0196 — The live demo
Date: 2026-09-30 · Status: Accepted

The number was reserved when the live demo began and is cited in the headers of `godot/demo/*.gd`
and in `godot/demo/README.md`; this record collects what every build step decided. Values are as
built on `feat/live-demo` (commit 114a902). Where the playtest fix pass later changed one, it is
marked **(changed by 0205)** and the new value is left to 0205. Every constant named here lives in
the file cited, and that file is the authority if the two disagree.

## Decision

### Scope and boot

1. **Presentation only.** `godot/demo/demo_village.tscn` instances `scenes/main.tscn` whole and
   unmodified, so the settlement, clock, UIManager and HUD boot as in the game and every HUD figure
   is live. The demo hides the game's placeholder ground, crowd, sun and camera and draws its own.
   Nothing in `godot/demo/` writes into the simulation. `scenes/main.tscn` is untouched.
2. **The opening pause is released.** `Game` starts the clock and UIManager holds UI-SET-103's opening
   inspection pause (PLAYER). The demo releases that one pause as it opens (changed by 0205: once
   its first frames are drawn), so the village opens running. This departs from the game's paused
   start on purpose.
3. **The Windows build** (`tools/build_demo_windows.py`, `tools/demo_build/`):
   - *Boot*: the export preset sets the custom feature `demo_build`. `godot/project.godot` overrides
     `run/main_scene`, the window mode (maximized) and the title ("Redwall Demo") for that feature
     only, so the editor and every other run still open `scenes/main.tscn`. The preset is kept in
     `tools/demo_build/windows_export_preset.cfg`, not `export_presets.cfg`. F11 toggles full screen,
     because Alt+Enter is already `brush_erase`.
   - *Textures* (`tools/demo_texture_imports.py`): every map a staged GLB carries is VRAM-compressed
     (S3TC). Colour and roughness use DXT1, normal maps BC5. Roughness is capped at its colour map's
     size, with mipmaps filtered by the normal map. The role is read from the GLB's material, never
     from the file name. Measured at 1920x1080: texture memory 6,216 -> 926 MB, video memory 6,502 ->
     1,115 MB, with no visible change. Card atlases, item icons and all UI art stay lossless (importer
     `keep`, read through `demo_manifest.gd readable_path`). Any unrecognised image is refused.
   - *Renderer*: Forward+ on Vulkan, falling back to Direct3D 12 (the system runtime) and then
     OpenGL (Compatibility). No D3D12 Agility SDK or ANGLE libraries ship, because the templates do
     not carry them. OpenGL is the dependable fallback.
   - *Stalls*: a frame that puts the clock 0.25 s behind at 1x holds REQ-SET-008's CRITICAL
     diagnostic pause. `ui/demo_stall_banner.gd` offers Resume (the button, Enter or Space), which
     calls `GameManager.acknowledge_overload()` once. **It never resumes by itself**: recovery is
     the player's, never automatic.

### Time, and one calendar / weather / water / notice feed / stores

4. **One presentation clock** (`demo_clock.gd`). Everything that moves with game time reads its
   seconds here: walking, turning, work timers, digging, the mound over a digger, and every
   AnimationPlayer. The speed is `get_effective_speed()`: 0 while paused, else 1, 2 or 4 (there is no
   3x). Time is counted in whole microseconds, so 2x is exactly twice 1x in every consumer. A frame is
   handed out in sub-steps of at most `MAX_STEP_USEC` 33334 (one 30 Hz frame).
5. **What stays on real time.** The camera, the HUD, the party panel, the selection and order marks,
   and the news strip's freshness all run on real time. They are the player's hands (UI §1.1), so
   selecting, ordering and digging work while the village is paused, and are carried out on resume.
6. **One calendar** (`demo_calendar.gd`). It is a tick counter on the real offset calendar
   (`sim_clock.gd`: 750 ticks an hour, 18000 a day, tick 0 = 06:00 spring day 1). The one demo
   compression is `HOUR_USEC` 2,500,000: 2.5 s a game hour, a day a minute at 1x. Farm time, the
   weather's hour and the HUD's date all use it. Only the farm model advances it, because every
   hour crossing and midnight must run the real crop and weather stage in order. The settlement's own
   clock runs on apart and is never written.
7. **The HUD date** (`ui/demo_hud_date.gd`) prints the calendar's day ("Spring 3") through the
   shell's public `set_status_line`. Its tooltip carries the full `Y1 Spring 3, 14:00`, because the
   trigger's 88 px holds no hour. `TEXT_PX` is 15.
8. **One weather** (`weather/demo_weather.gd`). It is bound to the farm's real §5.10 row
   (`crop_weather.gd` / `weather.gd`): season baselines, the forced first-spring Ideal spell and one
   seeded event a season. It holds no weather of its own, so the rain that slows walkers is the rain
   that wets the beds. The tunnel extension first built a compressed demo year from §5.10 table
   values; binding to the live row replaced that. How a day reads hour by hour is a demo value:
   - *Showers*: `rain / RAIN_PER_SHOWER_HOUR` (200) whole hours of rain, centred on 15:00. Spring's
     1200 is 12:00-17:59. (changed by 0205: spells, rain on one wet day in three.)
   - *Condition*: at or below freezing a rain hour is SNOW and any other hour FROST. Frost nights use
     the farm's overlay figure.
   - *Surface walking factor* (`SURFACE_SPEED_PERMILLE`): clear 1000, rain 800, snow 600, frost
     850. Rain's 800 is §5.10's heavy-rain "outdoor work x0.80", borrowed as a walking factor. Snow
     and frost are demo values. Tunnels are never slowed, so the router prefers them in bad weather.
   - *Look* (`weather/weather_view.gd`): rain dims the sun to `SUN_SHARE` 0.45, adds fog 0.012, and
     draws the rain at alpha 0.38. (changed by 0205.)
   - Weather notes post about twice a game day.
9. **One water adapter** (`village_water.gd`) sits over the real water map. It answers four integer
   questions in u:
   - irrigation edge: dry ground within `EDGE_REACH_U` 2560 (2.5 m) of the waterline;
   - wet ground: within `WET_REACH_U` 4608 (4.5 m);
   - the flood: a spill at the `ford_west` landing reaching `SPILL_REACH_U` 8397 (8.2 m);
   - `crosses_water` for tunnel routes.

   Each reach is the value of the placeholder it replaced, so behaviour did not move with the swap.
   The farm's reed pond and the tunnels' stream table and flood sheet are gone. The flood raises the
   stream by `FLOOD_RISE_PERMILLE` 900 of its level drop (`water/demo_water.gd`), and the flood film
   reaches `FILM_M` 3.0 m (`events/events_view.gd`).
10. **One notice feed** (`demo_notices.gd`). Every demo warning and report posts here with its demo
    date, source and level (NOTE or WARNING, worded, never colour alone), in a ring of 32. **Nothing
    in the demo raises a HUD alert card.** The HUD shows the two earliest unresolved notices (UI §7),
    and demo lines, which nothing resolves, held both cards for good. The tunnel extension's first
    choice, short lines through `UIManager.push_alert`, is superseded by this feed. Freshness is real
    time (`posted_msec`).
11. **One stores** (`tunnel/tunnel_stores.gd`, in `demo_services.gd`) holds wood, stone, planks and
    finds, in integer milli-U. It opens at `START_WOOD_MILLI_U` 40000 and `START_STONE_MILLI_U`
    20000. Every spend is all or nothing. The woods put wood in and saw planks from it; bracing,
    lanterns and bridges are paid from it. The HUD's Wood and Stone are the settlement's and are
    never written.

### Cast, selection and orders

12. **The world** (`world/`) is a clearing about 40 x 40 m. The play square is `PLAY_HALF_EXTENT_M`
    ±20 m on flat ground at y = 0.
    - Buildings are scaled uniformly to `BUILDING_MAX_Y_MM`; crop beds to a 3 m width. Everything else
      uses a demo-only height table judged against DEC-039's creature heights.
    - Obstacles are published as `Vector3(x, radius, z)` circles. A non-positive radius is refused at
      setup, because 96 of 196 circles once arrived with a negative radius.
    - (changed by 0205: trees and buildings sunk flush into the ground.)
13. **Pathing** (`cast/cast_nav.gd`, `cast_space.gd`):
    - One static visibility graph per body class (radius rounded up to 0.1 m), with circles bucketed in
      a 2 m grid and A* on a binary heap. Each plan adds only its start, goal, local rings (1.5 m) and
      rings round standing residents.
    - Margins: `PLAN_MARGIN_M` 0.18 on the graph, and `LINK_MARGIN_M` 0.05 on the plan's own edges, so a
      badger can leave a pocket its padded class could not.
    - Measured on the real layout: mean 0.24 ms, worst 1.5 ms per plan (was 34 / 329 ms), and 57 ms to
      build four classes.
    - The per-frame `constrain()` is exact and monotone, and refuses a step that would squeeze a body
      through a gap narrower than itself.
14. **Routines** (`cast/cast_routines.gd`). Each creature has two or three trade HOME POIs, grouped by
    neighbourhood. `SOCIAL_CHANCE` 0.2 sends it to a social spot instead. The next POI is weighted
    1 / (1 + d / `NEAR_M` 8 m). The beaver's homes are `weir_work`, `boat_landing` and `log_stack`.
    Tuning showed a ten-minute soak with walking at 14-28% of each resident's time (was 34-69%).
15. **Work per walk.** A wandering resident works at a POI at least `WORK_PER_WALK` 2.0 times its trip
    time, in bouts of 1-3 activities played for whole clip loops, so no one's day is mostly walking.
16. **Turn blending** (`cast/resident_brain.gd`). The walker walks from the start of a turn when it is
    within `START_WALK_ANGLE` about 12°. Between that and `BLEND_WALK_ANGLE` about 60°, it finishes
    the turn walking if 0.7 m ahead is clear. It stops and turns on the spot past `STOP_TO_TURN_ANGLE`
    about 75°, and shuffles in place past 45°. Turn rates are 1.75 rad/s walking and 3.2 on the spot.
    Tuning brought the longest turn from 1.53 to 0.65 s.
17. **Getting unstuck, bounded.** A walker replans at once when someone stops across its leg. It also
    replans when blocked for 0.35 s, when it makes no headway for 2.5 s, or after more than 4
    walk/turn flips on one leg. After 4 replans it gives the trip up and frees its slot. A walker with
    no route out waits in place rather than grinding along a straight-line fallback.
18. **Formations** (`cast/cast_orders.gd`). A formation is a spiral: the clicked point, then rings of
    6k spots at k spacings (`FORMATION_GAP_M` 0.35 between bodies). A spot counts only if it is:
    - inside the bounds;
    - clear of obstacles by body + `CLEAR_MARGIN_M` 0.12;
    - clear of standing residents and tunnel mouths;
    - reachable.

    A click with nothing within `FORMATION_MAX_M` 8 m is refused. Residents are matched greedily,
    nearest pair first. Distances are measured from where each resident stands on the surface (for
    one underground, the mouth it will come up at).
19. **Work orders and queueing.** A right-click within `POI_PICK_M` 1.1 m of a POI is a work order.
    The POI's free slots are filled nearest first, and the overflow holds in a formation
    `OVERFLOW_BACK_M` 1.8 m behind it, facing it. Every order goes through the brain, so slot
    reservations stay exact.
20. **Input bindings** (`control/demo_command.gd`, `tunnel/tunnel_control.gd`). Raw mouse buttons only,
    because the game's pointer router is not built. Picking is an analytic capsule ray, with no
    physics body per resident.
    - Left click or drag selects (Shift adds). A right click on ground moves the selection into a
      formation and holds it.
    - **R** is the project's `placement_rotate`, unused because no placement tool is open. It
      releases the selection.
    - **Esc** is `selection_clear`. It is consumed only while something is selected, because it is
      also `ui_cancel`/`open_menu`.
    - **T reuses the `open_calendar` key** to plan a tunnel. **U** toggles the underground view, and
      **V** cycles the map overlays.
    - **Enter** while laying a route is read in `_input`, before the GUI, so it can never press a
      focused HUD button.
    - A drag already started on the world is followed through `_input`, so a box dragged over a HUD
      panel still closes.
21. **Walk speed and clips.**
    - *Walk speed* is the gait speed the grounding tool recorded on each walk clip
      (`gait.speed_m_s`, decision 0202). It replaced the demo's old toe-slide estimate. (changed by
      0205: walk pace.)
    - *Clip rate rule*: the clip's rate is always ground speed over walk speed, on the surface, in
      weather, in a lit bore, and when closing up behind someone.
    - *Carrying* (decision 0195): a trip away from a stockpile carries with `CARRY_CHANCE` 0.5, only
      when it is at most `CARRY_MAX_TRIP_M` 8 m on the surface. It follows the carry clip's recorded
      root path key by key. Carry speed is `CARRY_WALK_FRACTION` 0.5 of walk speed (changed by
      0205), clamped to 1.0-1.6 of the clip's mean speed (upper bound changed by 0205).
    - Grounded clips come from decision 0193; the live tail is decision 0194's `TailRig`. The mole and
      badger have no tail chain, and nothing scales a body.

### Tunnels

22. **The bore is one cut quantum** (`tunnel/tunnel_rules.gd`), a 1024 u cube, so one metre of tunnel
    is one quantum. Digging time and spoil follow the adopted amendment directly (ECON-001/002/003):
    brace 25 + cut 50 + finish 38 = 113 ticks a quantum for one F1000 worker, and 2000 milli-U of
    `excavated_earth` a quantum. The bore size is a demo choice, because ECON-002 calls its example
    height "not a creature-fit ruling" and G01/G02 own the geometry.
23. **Shafts** are one quantum each, dug before and after the bore, with the spoil split between the
    entrance and exit heaps.
24. **Spoil posts when a quantum's cut completes** (75 ticks in), not when the quantum finishes.
25. **Fit.** Fit is taken from each resident's body with a `STOOP_PERMILLE` 850 stoop: 2 x radius <= bore
    width and ceil(height x 0.85) <= bore height, with the failed dimension named (MOVE-REQ-005). That
    admits mice, moles and squirrels, and refuses otters and the badger. **Only moles dig**, and T with
    no mole selected says so.
26. **Planner costs.** A tunnel is offered at its own length, never discounted. Of two equally short
    routes, the one with fewer tunnels wins. Tunnel cost rounds each leg **up**, while length for
    walking and digging stays floored. Refused lengths round away from the limit.
27. **MOVE-REQ-002.** Only finished, unclosed tunnels are routable. A digger called away leaves the
    tunnel PAUSED with every tick and unit of spoil (ECON-005). A tunnel with nothing dug is freed.
    **An unreached dig is kept paused at 0%** (`hold_unreached`), because the player chose that route.
28. **MOVE-REQ-007.** A crossing entered is finished: an order given underground is carried out from
    the far mouth, and a work-order release underground carries on to the POI. A digger called away
    backs out through what it dug.
29. **MOVE-REQ-004.** Finished tunnels are permanent, because the demo has no world edit that could
    change them.
30. **Integer state.** Positions and lengths are integer u (1/1024 m). Digging is an integer
    microsecond count turned into 30 Hz ticks, with the remainder kept.
31. **The digging clip** is `pull_radish` for every creature, else `collect_object`.
32. **Route limits.**
    - 2 m to 64 m long, at most 8 points (entrance, six bends, exit), at most 8 tunnels.
    - No leg may come within half a bore of a building's circles or the well. Bores may pass under
      crops, fences, trees and props.
    - No route may pass under water (`REFUSE_UNDER_WATER`).
33. **Integer clearances.**
    - Consecutive points at least 256 u apart.
    - A mouth half a bore (512 u) clear of every obstacle, plus `SPOT_KEEP_U` 512 from a work spot and
      `MOUTH_KEEP_U` 768 from another mouth.
    - A right-click resumes a tunnel when it lands within `RESUME_PICK_M` 1.1 m of the entrance.
34. **Right-click rules.** With the mole selected, a right-click on the tunnel it is digging changes
    nothing (and says so). On a paused tunnel, it resumes that one and pauses the current dig with its
    progress kept.
35. **Mouths are no-stand zones, not nav obstacles.** Formations, step-outs and heaps keep off them,
    but walks may cross a rim. Planning round every mouth measured about five times the cost of a plan
    (16 more circles to ring).
36. **Heaps** (`tunnel/tunnel_heaps.gd`). A heap is placed at its finished size when the dig is
    accepted, and is an obstacle from then on. Rebuilds are lazy: one per dig, never per frame.
    - Candidate order: right of the way out, left, the four diagonals, straight on.
    - Clearances: `HEAP_CLEAR_M` 0.15 from obstacles and `SPOT_CLEAR_M` 0.45 from work spots. With none
      clear, the candidate with the most room wins.
    - Drawn at 0.06 m³ per U. (changed by 0205: spoil heaps can be cleared.)
37. **Sharing a bore** (demo values). `BORE_GAP_M` 0.15 behind anyone going the same way; a pass offset
    of 0.25 m to the right within a 1.6 m window, side-stepping at 0.6 m/s; an emerge wait of at most
    6 s below a mouth someone stands on.
38. **Step-out order** from an exit is 0, ±45°, ±90°, ±135°. It takes the first direction that is
    `STEP_OUT_M` 1.0 m on, inside the village, and clear of obstacles, holes and residents.
39. **The mound** over a digger (`tunnel/tunnel_overlay.gd`) is drawn at its size up to 22 m of camera
    distance and scaled beyond that, capped at 2.5x. Ground cover is hidden within the route's
    clearing (`COVER_CLEAR_M` 0.6 m either side) plus `COVER_MARGIN_M` 0.45 m (`world/demo_world.gd`).
    The bore floor is 1.25 m deep, with 1.5 m end ramps.
40. **The mouth-to-mouth cache** is keyed by network revision and body radius. A cached route is checked
    against the residents standing now before use, and replanned round them when one is in the way.

### Tunnel extensions

41. **Weather.** The one weather (item 8). Tunnels are exempt from its slowdown, and the router
    compares walking time: each surface edge costs length x 1000 / `surface_permille`.
42. **The wide bore** (Widen) is 2 x 3 quanta (`BORE_WIDTHS_U` 2048, `BORE_HEIGHTS_U` 3072). That is
    the smallest lattice bore an otter (1.49 m, stooped 1.27 m) and the badger (2.55 m, stooped
    2.17 m) fit: 6 quanta a metre, so 5 extra to re-dig.
    - *Loaded envelope* (MOVE-REQ-005): a carrier's width is `LOAD_WIDTH_PERMILLE` 850 of its height.
      So mice and squirrels haul through a standard bore, an otter only through a wide one, and the
      badger through none.
    - Only the surface part of a hauling trip counts toward the carry limit.
43. **Ground types** (`tunnel/tunnel_ground.gd`) are loam, clay and sand (§4.3's `Soil`), plus a demo
    ROCK, on authored patches with seeded edges (SEED 1964, wobble 320 u).

    | Ground | Dig (‰ of 113 ticks) | Spoil (milli-U) |
    |---|---|---|
    | Loam | 1000 | 2000 |
    | Clay | 1300 | 2400 |
    | Sand | 800 | 1800 |
    | Rock | 1000 | 1200 |

    Rock also yields 800 milli-U of stone, and needs a badger on the crew; the mole alone works it at
    250‰. **This departs from ECON-002/003** ("no soil type multiplier") on purpose.
44. **Crews** (`tunnel/tunnel_crew.gd`), read as a pipeline from ECON-002/003.
    - One worker per quantum's face. Beyond that, a helper finishes behind the face, so the face yields
      a quantum every 75 ticks instead of 113. Rate 1506‰ (113/75, floored) on a standard bore; when
      widening, 2000/3000/4000 for one per face.
    - At most 4 builders (ECON-002). Surface hands add no face work.
    - The Foremole's experience adds 20‰ per 8 quanta, capped at 100‰.
45. **Brace** charges ECON-002's materials: wood 250 + stone 250 milli-U and 25 ticks a quantum, paid
    once at work start (ECON-003) from the one stores. The demo's plain digs count brace time without
    timber.
    - *Lanterns*: one per 4 m, 60 ticks and 500 milli-U of wood each. A lit bore is walked at 1100‰.
    - *Pump*: 30 ticks a quantum.
    - *Chamber*: 9 quanta.
    - A paused job keeps its progress and paid inputs (ECON-005).
46. **Hazards** (`tunnel/tunnel_hazards.gd`) are deterministic, warned and preventable, apply only to
    unbraced tunnels, and hurt no one.
    - *Seep*: in wet ground while it rains, 40 s to flood, 4x faster in a stream flood.
    - *Strain*: in sand while it rains, plus 8 s per crossing, 75 s to a collapse of up to 3 quanta,
      which never falls on anyone.
    - Warned at 500‰. Nothing builds in frost or snow. Pump out and Clear the fall reopen the tunnel,
      and bracing removes both hazards for good.
    - This **departs from HAZ-001**, under which supported tunnels never fail and an unbraced tunnel
      would not be cut at all.
47. **Finds** (`tunnel/tunnel_finds.gd`) are rolled once per physical cubic metre and layer (bore,
    widen, chamber): an integer hash (SEED 7043) mod 10000. A metre already rolled yields nothing.

    | Ground | Flint | Clay | Root store | Relic |
    |---|---|---|---|---|
    | Loam | 600 | 300 | 500 | 60 |
    | Clay | 300 | 2500 | 200 | 60 |
    | Sand | 900 | 100 | 300 | 60 |
    | Rock | 2500 | 0 | 0 | 100 |

    Relic stories (including the key and the banner) and the Foremole's lines are original text in
    light mole dialect (DEC-017), not quoted.
48. **Chambers** (`burrow/burrow_chambers.gd`) are 3 x 3 quanta, centred 2048 u off the route, at least
    3584 u from each other and 2048 u from any mouth. They may not go under a building or over another
    tunnel. At most 8.
    - A burrow home has `BEDS_PER_HOME` 2, derived from the GDD dormitory: floor(9 x 12 / 40).
    - A root cellar's spoilage is 350‰, the GDD's cellar factor (cited). Its capacity of 60 U is a demo
      value.
    - The cellar API is `cellars()` / `cellar_count()` / `revision`.
49. **Demo beds and stores show only in the panels.** The HUD's simulation counters (Beds, Wood, Stone)
    are left untouched.
50. **Threats** (`events/demo_events.gd`) are a seeded flood at the ford or a fire at the covered store
    (SEED 5155), each lasting 40 s.
    - The first comes on its own at 360 s (6 min), then every 540 s plus up to 120 s of jitter. "Test
      event (demo)" brings the next one at once.
    - Residents inside the disc escape through the nearest fitting tunnel whose far mouth is 1 m outside
      it, or on foot, shelter 2 m beyond, and go home when it clears.
51. **Queues** (`tunnel/tunnel_queue.gd`). A busy mouth holds a line of at most 4, joined within 2.2 m,
    starting 1.4 m out and spaced 0.8 m. Each walker queued costs 3 m in the planner, a full queue is
    INF, and a walker gives up after 25 s.
52. **The generic `ORDER_TASK` hook** in the resident brain (`tunnel/tunnel_task.gd`: `site`,
    `arrived`, `step`, `finish`, `cancel`) carries tunnel jobs, crew places, evacuations, farm and woods
    work, swims, dives and rescues. A new order cancels the task first. (changed by 0205: a job
    interrupted by another order is queued to resume.)

### Farm and pantry

The pantry agent's 12 decisions are reconstructed from the `farm/*.gd` headers.

53. **Individual ingredients, real arithmetic** (`farm/farm_catalog.gd`). The 16 items are LEAF ids of
    the content library's pantry. Each grows by the one §5.6 row it maps to, and every item of a row
    grows identically, because giving a radish its own numbers would invent constants.
    - *Roots*: radish, turnip, carrot, beetroot, parsnip, onion.
    - *Cabbage*: cabbage, lettuce, spinach, leek, celery (the alliums split families, a stated
      simplification).
    - *Beans*: pea, broad bean.
    - *Grain*: wheat, barley, oats.

    Shelf hours follow §5.7: roots 240, cabbage 144, beans 480, grain 720.
54. **Excluded crops**: flax (fibre, not food), strawberry (no §5.6 row fits), the library's fictional
    leaves, and the livestock, dairy and egg pipelines. Library records stay NOT_RUNTIME_ACTIVE, and
    dishes are candidates only (`pantry_index.json`).
55. **Beds are real FarmPlot rows** advanced by `crop_weather.gd` and `farming.gd` entry points, with no
    arithmetic re-implemented. The hourly leg runs per bed because covered and raised beds differ in
    temperature. `WEATHER_SEED` is 196. Each bed's soil is a demo value, varied so the soil filter
    matters.
56. **Demo moisture additions**, per farm day:
    - drained by a tunnel: up to 1500 toward the low side;
    - irrigated: up to 1500 toward the middle;
    - raised: sheds 800 and is warmer at night;
    - banked: keeps half of each dry day's loss.

    A bore within `UNDER_REACH_U` 1536 of a bed's centre runs under it. Clearing a blighted crop
    uproots it for REQ-SET-085's 0.5 U of compost.
57. **Demo threats** (`farm/farm_weather.gd`):
    - Frost nights fall 02:00-05:59 to -3 °C (§5.10's Early-frost figure) and are announced at 12:00
      the day before. A covered bed is 4.0 °C warmer, a raised bed 3.0 °C.
    - Blight outbreaks spread to neighbouring beds at midnight.
    - Days: frost spring 4 and 9 and autumn 3 and 8; blight spring 7, summer 4 and 10, autumn 6.
      (First-spring threat days changed by 0205.)
    - A ripe crop loses yield after 48 h and withers at 120 h (§5.6).
58. **Farm verbs and WU** (`farm/farm_jobs.gd`). Cited: sow 4, tend 1, harvest 6, clear 10, compost 8.
    Demo values: cover 2, raise 6, bank 6, fetch 1, dig 2, drop 1. A WU is shown as 1.5 s of cast
    time. Raise, bank and spoil-compost each take §5.6's 2 U dose of tunnel spoil. (changed by 0205:
    a Drain verb.)
59. **The crew** (`farm/farm_crew.gd`). The fieldworker and gatherer take queued work while wandering.
    A player's order goes to the nearest selected resident. The farm itself raises only REQ-SET-073
    harvest jobs and REQ-SET-085 clearing jobs.
60. **The pantry is lots** (`farm/farm_pantry.gd`), up to 128, one item each, aged by §5.8.
    - Each hour a lot ages floor(store factor x temperature factor / 1000). The temperature factors are
      spring 1000, summer 1500, autumn 1000, winter 500.
    - A full table merges into the oldest lot of the same item and place, keeping the older age.
    - Spoiled food leaves the count and can go to compost at §5.7's 4 : 2.
61. **The storage-provider API** (`farm/farm_storage.gd`) takes `{id, position, capacity_u,
    spoilage_permille, label}`. Malformed entries are refused and counted, never repaired.
    - Location 0 is the covered store: factor 1000 and a demo capacity of 400 U.
    - Lots of a vanished location move to location 0.
62. **Harvest routing.** A harvest goes to the slowest-spoiling store with room, and to the nearer on a
    tie. `farm/farm_cellars.gd` adapts the cellar API: the id becomes `root_cellar:<slot>:<gen>` and
    the delivery point is the cellar's tunnel door.
63. **HUD hooks** (`farm/farm_hud.gd`).
    - The Food cell shows the pantry total through the shell's public `set_counter_display`. The
      ledger line still shows the settlement's figure, a stated difference.
    - The locked UI-SET-030 Food command, and K, open the Pantry.
    - Seed is unlimited (REQ-SET-071's 250 milli-U is reported only). The compost store opens at 4 U.
64. **The water is outside the square**, so only tunnel mouths by the ford (or at x 19.5 m, z 4) can
    irrigate. The west beds only drain.

### Woods

65. **Trees are real ResourceNode rows** (`forestry/forest_stand.gd`): 173 trees on their §5.1 tiles,
    with the square's centre at exterior tile (64, 64). A mature tree holds 12 U. Felling is the store's
    single debit, which dates the stump (REQ-SET-138). Planting uses create plus a discarded same-day
    `harvest_all` until the store gets a planting call.
66. **Retention.** The floor is a share of the zone's live rows, and fells already ordered count
    against it: 20%, or 10% intensive (§5.9). Conservation zones are never cut by order or routine,
    but their deadfall may be gathered. The demo opens with the North stand (forestry) and the Old
    grove (conservation). Auto-fell is off by default.
67. **Felling and sawing are demo skills** using §5.3's arithmetic: 10 XP a WU, and the factor
    1000 + 50 x level. The GDD does not say which skill extraction trains. The forester and the beaver
    start at felling 3.
68. **The cut.** A felled tree is cut above its root mound, and walkers are lifted onto mounds
    (`forest_lift.gd`). Storm blow-downs uproot the tree, which leaves cleared spots to replant.
69. **Demo values** (`forestry/forest_rules.gd`):

    | Item | Value |
    |---|---|
    | A WU on screen | 0.1 s (a 120-WU felling is 12 s at 1x), at least 2.5 s |
    | Winter felling time | 80% (no sap) |
    | A haul | 6 U a trip |
    | Deadfall pile | 1-2 U, gathered at 20 WU a U; one a day, three more on a storm day, at most 10 |
    | Sawing | 2 U of logs to 2 U of planks for 40 WU |
    | Grubbing a stump | 30 WU |
    | Reach | 30 m from the square, with an 11 m work margin |
    | Storm | one blow-down per storm day |

    Cited: regrowth 48 days, planting 0.25 U compost + 4 WU (§5.9), storm work x0.80 (§5.10).
70. **Staging.** The stager stages the fresh oak stump and the swim, tread-water and dive clips.

### Water

71. **Water stays outside the ±20 m square** (`water/water_layout.gd`). Its resident spots stand at the
    square's edge, and nothing in the village moved. The tunnel "never under water" rule held through
    geometry until tunnels call `segment_crosses_water(..., 512)`; they now do (item 32).
72. **Zone thresholds** (`water/water_rules.gd`): wade up to 250‰ and dive from 1000‰ of body height.
    These are demo values, since SET-MOVE-001 §4 originates no depths. A zone classifies water and
    grants no capability.
73. **Geometry.** Water is a union of tapered capsules, with a trapezoid depth rounded up. Demo values:
    - bank 1.2 m, surface 0.18 m down;
    - ramps 1.2 m (stream) and 2.2 m (pond);
    - flow 0.4 m/s;
    - the shore sampled along a 64-direction integer table every 0.375 m, so `nearest_bank` returns
      the nearest sample, not the exact point.
74. **Crossings** (`water/water_map.gd`). A ford is the narrowest station of a run that a mouse still
    wades. Bridges are the 4 narrowest stations, at least 6 m (6144 u) apart.
75. **Fishing** (`water/fishing_driver.gd`) drives the real `fishing.gd` store: stream = river,
    pond = lake. The estuary's COAST habitat exists but is unbound. The run and the ford share one
    river stock (§5.1, MOVE-TEST-07). Eel, pike and shrimp are excluded, and mussel is coast-only.
    §5.4's gear columns are compiled into the driver.
76. **Named blockers**, not invented:
    - gear durability and wear;
    - the hazard and rare-quality rolls (the FISHING RNG stream has no owner);
    - injury and rescue at sites;
    - M1-M3 unlocks;
    - winter ice and storms (REQ-SET-051/052).
77. **The saltpan stays unplaced.** §5.7 accepts only coastal brine, so a saltpan by a freshwater pond
    would read as a working salt source.
78. **Creels and dioramas.** The fish creel has a demo-only height of 0.5 m. The diorama sinks were
    measured from each model's baked water level: boathouse 1.02 m, fisher shelter 0.84, weir 0.43,
    mill 0.48 (`water/water_dressing.gd`). Water props are placed from
    the depth map (probed at 0.5 m), and the jetty deck height was measured from its model.
79. **The woods keep off the water.** Trees and logs in the water, and one log behind the boathouse,
    were removed; one log re-flowed south-west outside the square. The obstacle count went from 196
    to 192, and a diff confirmed nothing inside the square changed.
80. **The camera focus bounds** are extended over the water, for viewing only.

### Water gameplay, part A

Every number is in `waterplay/swim_rules.gd`, either cited or named as a demo value.

81. **The walking area widens** to x -20..36, z -34..42 (the camera too), with a ±44 m planning area.
    Water deeper than a mouse wades is a band of circles (r <= 1 m) running 6 m past the area. The
    ford is open ground, and tunnels are still refused under water.
82. **Wading** is ground movement at 55% of walk pace, feet on the bed (TRV-W01). Routes pay its cost,
    so a longer dry way can win.
83. **Swimming capability is per resident**, seeded by species. Speeds: mouse 0.60, squirrel 0.55,
    mole 0.50, otter 1.10, beaver 0.90 m/s (changed by 0205). **The badger wades only**, and only
    otters dive. A loaded resident never swims.
84. **Swim links and pond chords are router crossings.** At most 3 are offered per trip (`SWIM_OFFERS`).
    A link costs its bank walks plus 1 m in and out, plus the swim at the speed made good across the
    flow, in metres at walk speed. Pond chords cost twice their length (`SWIM_WEIGHT` 2.0).
85. **HAZ-001/002/003 are used as cited.** Air is 1200, spent 1 a tick below, recovered 4 a tick, with
    a 300-tick reserve and an advisory at 450. Rest must be at least 4000 to enter, the swimmer turns
    back at 1500, and it is in difficulty at 0. Stamina and dive figures are demo values:
    - 3 a tick swimming and 6 a tick recovered on land;
    - doubled in water below 10.0 °C, plus the flow's share;
    - a flood doubles the flow;
    - dives at 0.5 m/s down and up, with 8 s of search.
86. **Rescue** (REQ-SET-054). The nearest free swimmer tows the victim at 60% of its swim speed to a
    landing it can reach against the flow. With none free, a line of 8 m reach hauls at 0.5 m/s.
    - Nobody drowns: the victim washes ashore after 90 s with nobody coming, or 240 s with a rescuer
      on the way (who then stands down).
    - It then rests 20 s at 3x recovery.
    - Landings inside a building footprint on the widened ground are unused.
87. **Bridges** (`waterplay/bridges.gd`, `bridge_crew.gd`).
    - *Plank footbridge*: 1.0 U of planks a metre of deck, plus 1.0 U of wood a pier (one per started
      2.5 m of span over 3.5 m), at most 8 m of deck.
    - *Log bridge*: one 6 U log, at most 5.5 m.
    - *Work*: 40 WU a pier, 25 WU/m of beams, 20 WU/m of deck, or 30 / 20 / 10 WU for a log, at
      forestry's 0.1 s a WU.
    - Paid all or nothing. The beaver bridgewright starts at level 6 (180000 XP), and anybeast learns
      (DEC-041).
88. **Freshwater finds** come from the dive's number with seed 92 (a stone, a hook, silt, then a relic).
    A relic joins the stores' finds, and a stone adds 0.25 U of stone.
89. **Nothing stands, idles or works in water.** Every spot chooser keeps a body clear of the waterline.
90. **The Water panel** caches its surveys per site and layout, and refreshes only while shown.
91. **Helper lookups refuse explicitly** (e.g. `nearest_free_into`) instead of returning -1.

### Assets

92. **Game-budget versions** are made free in Blender (`tools/make_demo_props.py`), baked onto fresh
    UVs from UV-less decimated copies, with a voxel-remesh fallback.
    - Small props: 1,150 of a 1,200-triangle budget. Furniture: 1,900 of 2,000.
    - Textures: 512 px for small props and plants, 1,024 px for furniture.
    - The older library props (lantern, bed, basket, jars, shelf, tools) were rebuilt, because their
      2,048 px maps exceed GAP-04's 1,024.
93. **Sizes are demo-only** (`props/demo_props.gd`, `world/world_sizes.gd`): by height for what stands,
    by longest side for what lies or is carried. They are judged against DEC-039's heights and are not
    a sizing policy.
94. **Plants.** Heights, spacing, top-card lift and scale, stage-view subsets and the wither/blight
    shading are demo values set by eye. Soil lines were measured from each model. The broad bean uses
    the pea plant; lettuce is drawn as its 580-triangle mesh once it fills out.
95. **Shelves and held tools.** Goods are laid out on the shelf, most first, with a jar per started
    third of fullness. The lantern's orientation was read off a top render. The pick's grip
    (`PICK_GRIP_SHARE` 0.14) is a demo guess.
96. **Facing is unchecked.** Models keep +Z facing as authored, but the project's convention is -Z
    forward.

### HUD skin and UI

97. **The woodland skin** (`ui/woodland_*.gd`) re-dresses the live HUD in place: theme copies and
    per-node fixes found by UI-SET names. No game UI file is edited.
98. **The Demo party panel** sits in the HUD's empty left column. It yields to UI-SET-009, is titled
    "Demo", and sits below the HUD's layer so a modal covers it.
99. **The Village news strip** (`ui/demo_news_strip.gd`) shows the 3 newest lines at bottom centre:
    notes for 12 s and warnings for 30 s of real time, at most 640 px wide. It ignores the mouse.
    (Centring changed by 0205.)
100. **The detail zone holds one panel at a time** (`ui/demo_detail_zone.gd`): Farm / Tunnels & burrows
     / Woods / Water tabs, switched by intent or by hand. All of it hides while the resident journal
     (UI-SET-036) is open, and at 1280x720 each panel sits above the command strip.
101. **Nothing raises HUD alert cards** (item 10). The game's own "Mossflower stirs." notice
     (`scripts/main.gd`) still holds one card permanently, and the demo leaves it alone.

## Why

- **Movement is presentation-only because the MOVE gates are open.** MOVE-G01..05 contain outstanding
  engineering work (`docs/movement_direction_amendment.md`), so nothing the demo cast does may feed
  the simulation or stand in for its movement system. Every order, tunnel, swim and bridge moves the
  demo cast only. Where adopted rules exist, the demo follows them to the letter:
  MOVE-REQ-002/004/005/007/009/015, ECON-001..005, HAZ-001..003, §5.3/§5.4/§5.6/§5.8/§5.9/§5.10.
  Where the demo departs from them, the departure is named in the file that makes it.
- **Integer authoritative state.** Positions are in u (1/1024 m), time in 30 Hz ticks or whole
  microseconds, quantities in milli-U, and needs 0..10000. Float enters at import (a click, a body
  size) and leaves only for drawing, as AGENTS.md requires, so tests pin every boundary exactly and
  2x is exactly twice 1x.
- **Real systems where they exist.** The farm runs `farming.gd` and `crop_weather.gd`, the woods run
  `resource_nodes.gd`, the fishery runs `fishing.gd`, and the weather is the farm's live §5.10 row.
  So what the demo shows is the game's arithmetic, not an imitation to be reconciled later.
- **Demo values are named constants**, each commented as DEMO in the file that owns it, never in
  prose. The GDD and amendments do not state bore sizes, water depths, swim speeds, walking weather
  factors, queue spacings or prop sizes. Inventing them silently would violate AGENTS.md; naming
  them keeps them findable and replaceable.
- **Why the demo departs from GDD rules where it does:**
  - *Opening pause*: a presentation must open alive.
  - *Soil multipliers and rock*: ground has to matter on screen.
  - *Unbraced tunnels and their hazards*: HAZ-001 would refuse to cut them, but the demo must show a
    warned, preventable consequence.
  - *Frost and blight in spring*: §5.10 brings neither for half an hour.
  - *One calendar compression*: a crop takes 50-80 real minutes at the settlement's rate.
  - *No HUD alert cards*: UI §7's two cards are for settlement conditions, which demo notices are not.
- **One of each** (calendar, weather, water, feed, stores). The farm, tunnels, woods and water were
  built apart. Two dates, two weathers or two wood stocks on one screen was wrong, and each merge
  kept the replaced placeholder's values, so behaviour did not move with the swap.

## Consequences

- **Nothing here is a GDD value unless cited.** Every demo constant above (bore geometry, stoop 850,
  load 850‰, ground multipliers, find tables, hazard timings, queue and bore-sharing distances, water
  depths and thresholds, swim speeds, stamina, bridge costs, woods timings, prop and plant sizes, the
  2.5 s game hour) is provisional. None may be copied into `scripts/` or cited as settled. Production
  values come from MOVE-G01..05, the owning amendments and Brendan's rulings.
- `godot/demo/` must stay out of the simulation's write path, and `scenes/main.tscn` must stay
  untouched. A demo feature that needs sim state reads it or shows its own labelled figure.
- The tunnel extension's first alert and water choices (`push_alert`, a stream table and flood sheet)
  and its compressed weather year are superseded within this record by items 8-10.
- **Open items and known issues:**
  - *Idle clip*: needs a pipeline follow-up.
  - *Facing*: which way creatures and props face needs a human look. No tool checks it, and some
    props face the wrong way.
  - *Gait swing-foot scrape*: in all 40 walk, run and carry clips the swinging foot drags 0.1-1.2 m
    (0202). Two kneeling contacts are unpinned and four clips keep a slow creep. Godot's import drops
    keys.
  - *Beaver audit*: the beaver was left out of 0202's foot audit because `repair_meshy_rig.py`
    crashed on it; 0203 resolved the crash.
  - *Sentinel returns*: one cast pick path returns -1 for "no hit", against the house rule on sentinel
    returns.
  - *Staged but unplaced*: the composter, spade, hoe and sickle. The axe went to the woods.
  - *Tunnels*: the walk slows when a resident closes up behind another in a tunnel.
  - *Windows*: the build was verified only by booting the pack on macOS. Brendan's 2026-09-29
    Windows playtest (`docs/playtests/2026-09-29-windows.md`) is the first real run.
  - *SmartScreen*: it warns because the exe is unsigned. README.txt covers "More info" then
    "Run anyway".
  - *Stalls*: CRITICAL stalls recur on first loads. The first U-view stall, the tunnel's flat-ribbon
    look and the chamber slabs go to the separate underground revamp; its clip choices are decision
    0204.
  - *Threats*: they fire on their own schedule, not the calendar (a flood about 6 minutes in).
  - *Weather notes*: about twice a game day may read as chatty.
- The playtest fix pass (0205) changes the values marked above and adds a boot prewarm, spoil
  clearing and a job-resume queue. Read 0205 for the current figures.

## Source

- `docs/movement_direction_amendment.md`: MOVE-REQ-001/002/004/005/007/009/010/015, MOVE-G01..05,
  SET-MOVE-001 §1/§4, TRV-W01..W04, MOVE-TEST-07.
- `docs/underground_economy_hazard_amendment.md` (adopted by decision 0107): ECON-001, ECON-002,
  ECON-003, ECON-005, HAZ-001, HAZ-002 (`air_standard_v1`), HAZ-003.
- `docs/game_gdd.md`:
  - REQ-SET-008 (clock overload), REQ-SET-044/045, 050-056, 071-078, 084, 085, 138;
  - §4.1 (WU), §4.3 (Soil), §5.1, §5.3, §5.4, §5.6, §5.7, §5.8, §5.9, §5.10.
- `docs/ui_ux_controls.md`: UI §1.1, §1.2, §7, UI-SET-009/030/036/101/103.
- `docs/setting_decisions.md`: DEC-017 (light dialect), DEC-039 (creature heights), DEC-040 (warned
  hazards), DEC-041 (the beaver).
- Decisions 0082 (building envelopes), 0191-0195 (tails, grounded clips, carry root motion), 0202
  (gait speed, foot pinning), 0203 (beaver and swim clips), 0204 (underground revamp clips) and 0205
  (the playtest fix pass).
- The build agents' collected lists (`decision_0196_inputs.md`, session scratchpad); the file headers
  of `godot/demo/**/*.gd`; `godot/demo/README.md`; `tools/demo_build/README.txt`; the commit messages
  on `feat/live-demo` (e.g. 05e5cbc, 10ad254 for the planner and routine measurements).
