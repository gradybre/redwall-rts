# Live demo — a small Mossflower village

A presentation-only demo (decision 0196). It boots the real game — settlement, simulation clock,
HUD, UIManager — and draws a small village of real library assets on top: buildings, trees,
crops and props at game scale, and eight real rigged residents who walk between work spots with
live tail springs (`TailRig`, decision 0194), grounded clips (0193) and stride-matched speed.
The HUD wears a demo-only woodland skin in the visual language of
`docs/design/ui_refinement/visuals/05_woodland_art_concept.png`.

**Movement here is scripted wandering, not the simulation's.** The settlement's movement
system is not built (MOVE gates are open), so the demo cast is presentation-only and does not
feed the simulation. `scenes/main.tscn` is untouched.

## Run it

```
python3 tools/stage_demo_assets.py      # copy the library assets in (gitignored, ~1.6 GB)
godot --path godot demo/demo_village.tscn
```

Without staging it still runs, on placeholder shapes.

## Time

The demo opens running: `Game` starts the real clock and UIManager holds UI-SET-103's opening
inspection pause, which the demo releases once as it opens. From then on the HUD's pause and
1x / 2x / 4x buttons (and Space) are the game's own, and the whole village follows them through one
presentation clock (`demo_clock.gd`): residents' walking, turning and work, digging and walking
tunnels, the mound over a digger and every resident's clip. Paused, everyone holds their pose;
at 2x and 4x they move and dig two and four times as fast. The camera, the HUD, the demo party
panel and the selection and order marks stay on real time, so the player can still select, order
and dig while paused -- the orders are carried out on resume.

## One village: one calendar, one weather, one water, one feed

The farm and the tunnel works were built apart; in the demo they are one village, sharing four things
that `demo_village.gd` makes once (`demo_services.gd`) and hands to both:

- **One calendar** (`demo_calendar.gd`). Farm time, the weather's hour and the **date the HUD shows**
  are one tick counter on the real offset calendar, run on the demo clock at a game hour every 2.5 demo
  seconds (a day a minute at 1x) -- the one demo compression, applied to all three. The farm's model
  advances it; the HUD's date trigger prints its day (`ui/demo_hud_date.gd`, through the shell's
  public `set_status_line`, so the settlement's own clock runs on apart, unwritten) -- "Spring 3": the
  trigger's 88 px hold no hour, so its tooltip carries the full `Y1 Spring 3, 14:00` -- and the farm
  panel's clock line and every notice's stamp are that same date, e.g. `Y1 Spring 3, 14:00`.
- **One weather** (`weather/demo_weather.gd`). The authority is the farm's REAL §5.10 weather row
  (`scripts/core/weather.gd` in the farm's private `crop_weather.gd` stage): the season baselines, the
  forced first-spring Ideal spell and one seeded event a season. Each day's rain wets the beds at the
  day's start, and falls on screen as `rain / 200` whole hours of showers centred on 15:00 (spring's
  1200 is 12:00-17:59) -- so the rain that slows walkers is the rain that wets the beds. Frost nights
  (the farm's demo overlay) read as frost. Rain slows surface walking to 80%, snow to 60%, frost to 85%;
  tunnels are not slowed, so walkers take them in bad weather. Rain and snow fall, the light dims.
- **One water adapter** (`village_water.gd`, `demo_village.water()`) over the real water map
  (`water/water_map.gd`, see Water): the farm's water-edge query (irrigation: dry ground within 2.5 m
  of the waterline), the tunnels' wet ground (within 4.5 m), their flood (the stream spills over the
  ford's west bank, 8.2 m into the village) and their routes (no bore passes within half a bore of
  water: "a tunnel cannot pass under the stream or the pond"). The three reaches are demo values,
  each the one the placeholder it replaced used; the placeholders -- the farm's reed pond and the
  tunnels' stream table and flood sheet -- are gone.
- **One notice feed** (`demo_notices.gd`). Every farm warning, weather change, tunnel happening, threat
  and crew report is posted there with its date; the newest show bottom centre as **Village news
  (demo)** (`ui/demo_news_strip.gd`: notes 12 s, warnings 30 s, warnings worded and in clay), and the
  farm's and the tunnels' own latest stay in their panels. Nothing in the demo raises a HUD alert card
  any more: the HUD shows the two earliest unresolved notices, and demo lines, which nothing resolves,
  held both cards for good.

**The right column holds one demo panel at a time** (`ui/demo_detail_zone.gd`): a tab strip, *Farm*
and *Tunnels & burrows*, over the HUD's detail zone. Clicking a bed brings the farm's panel; selecting a
tunnel or laying a route brings the tunnels'; the tabs switch by hand; both hide while the resident
journal is open.

## Commanding the residents

| Input | Does |
|---|---|
| Left click a resident | Select it alone (Shift: toggle it in the selection) |
| Left drag | Box-select by screen position (Shift: add to the selection) |
| Left click empty ground | Clear the selection |
| Right click ground | Move there in a formation, then hold |
| Right click a work spot | Work there; anyone beyond its free slots holds behind it |
| R | Release the selection back to its own routine |
| Esc | Clear the selection |
| T (or "Dig tunnel") | With the mole selected: lay out a tunnel (below); again: cancel it |
| U | Underground view: the surface fades, tunnels show as lit bores with anyone inside |
| Left click a finished tunnel | Select it for the "Tunnels & burrows (demo)" panel (see below) |
| V | The one map-overlay cycle: the farm's moisture, its ripeness, the water's zones and fishery (wade / swim / dive, fords, bridge spans, landings, fish stocks), off |

The "Demo party" panel in the HUD's left column lists the selection. Orders move the demo cast
only, never the simulation.

## Digging tunnels

Select the mole and press T (or its panel's "Dig tunnel" button). Left-click where the entrance
opens, click again for each bend, and the last click is the exit; the route and its length follow
the pointer, drawn over roofs so it stays readable. Enter or right-click digs it, Backspace takes
back the last point, Esc (or T, or the button again) cancels. Refused, with a clay marker and the
reason in the panel: a point off the map or on top of the last one; an entrance or exit inside an
obstacle or heap, on a work spot or on another tunnel's mouth; a leg passing under a building or the
well (bores may pass under trees, props, crops and fences); an entrance someone is standing on, or
one the mole cannot walk to. Only moles dig; T with no mole selected says so.

The mole walks to the entrance, digs its shaft (the `pull_radish` clip), then goes underground:
a mound of earth moves along the route (click it to select the mole), the route fills in, and spoil
heaps grow by the entrance and, when it breaks through, the exit. The heaps are placed when the dig
is accepted -- off work spots, obstacles and holes -- and are obstacles from then on; the grass is
cleared from the holes, heaps and route. The panel reads "Digging tunnel — 43%". Called away, the
mole backs out and the tunnel waits, marked with a clay ring and "Tunnel paused at N%"; right-click
its entrance with the mole selected to resume it (on the tunnel it is digging, a right-click
changes nothing; on another paused one, it pauses this one and goes there). A mole that cannot
reach the entrance leaves the tunnel paused at 0%, and says so. Coming up, the mole steps clear of
the exit, inside the village, off every hole and resident.

A finished tunnel stays. Mice, moles and squirrels fit its bore and use it whenever it is
genuinely the quicker way ("Using tunnel") and nobody is standing on its mouths; otters and the
badger walk round until it is widened. Inside, walkers keep their distance behind anyone going their way and step
aside to pass anyone coming the other way; at the far mouth they wait below (at most 6 s) while
someone stands on the hole.

Digging runs at the adopted excavation rate (113 ticks and 2 U of spoil per cubic metre,
`docs/underground_economy_hazard_amendment.md`); the bore size, the stoop that lets a squirrel
through, the depth and the drawn size of a heap are demo values (`tunnel/tunnel_rules.gd`).

## Farming

The six crop beds grow **individual pantry ingredients** -- radish, turnip, carrot, beetroot, parsnip,
onion, cabbage, lettuce, spinach, leek, celery, pea, broad bean, wheat, barley, oats, each a LEAF of the
content library's pantry -- by the settlement's **own crop arithmetic** (`scripts/core/farming.gd` and
`crop_weather.gd`, GDD §5.6): each bed is a real FarmPlot row, and each ingredient grows by the §5.6 row
it belongs to (roots, cabbage, beans or grain), on the demo's one calendar (above). Harvests go into
the **pantry**, counted per item, at the slowest-spoiling store with room -- a **root cellar** dug off a
tunnel (spoilage 350 per mille, the GDD's cellar) before the covered store (1000), and of two cellars
the one nearer the bed (`farm/farm_cellars.gd` turns `burrow_chambers.cellars()` into pantry stores);
the HUD's Food cell shows the pantry total, and the Food command (or K) opens the Pantry: stock per
ingredient, freshness (GDD §5.8 spoilage by where it is stored), and the library dishes each feeds.

| Input | Does |
|---|---|
| Left click a bed | Its panel: crop, stage, hours to ripe or withering, moisture band, fertility, health, what was done to the ground, expected yield, jobs, and the verbs |
| Right click a bed (residents selected) | The nearest selected resident does its most pressing work: clear, harvest, water a dry bed, cover before frost, sow |
| Plant… (bed panel) | The crop picker: every ingredient, sowable ones first, with growth hours, yield, family and its rotation effect in this bed; the rest say why not (soil, planting window) |
| Water / Harvest / Clear / Compost / Cover | Given to the selected residents, or queued for the field crew (the fieldworker and gatherer take queued work while wandering) |
| Raise / Bank | A resident fetches 2 U of tunnel spoil from a heap: a raised bed drains and is warmer at night; a banked bed keeps half of each dry day's loss |
| Rest | Rest the bed fallow (it regains fertility; nothing is sown) |
| V | Map overlay: moisture, then ripeness, then the water's zones, then off (one key for every overlay) |
| K / Food | The Pantry |

Threats: spring is wet (beds waterlog and stop growing -- drain them with a tunnel, or raise them),
summer dry (water), frost nights are announced the day before (cover or raise), blight spreads to
the next beds at midnight unless the blighted bed is cleared, and a ripe crop starts losing yield after
48 hours and withers at 120. A finished tunnel under a bed drains it; a tunnel with a mouth at the
real stream's edge (dry ground within 2.5 m of its waterline -- inside the square, by the ford or at
x 19.5 m, z 4) irrigates the beds it runs under. Details and every number's source: `farm/*.gd` headers.

## Weather, upgrades, hazards, finds, chambers, crews and threats

The tunnel extensions (`tunnel/tunnel_ext.gd`) add a **"Tunnels & burrows (demo)"** panel, the right
column's second tab. Everything runs on the demo clock: paused, the weather, hazards, jobs and threats
hold; at 2x and 4x they run faster.

| Input | Does |
|---|---|
| Left click a finished tunnel's mouth or route | Select it (selected residents stay selected) |
| Panel: Widen / Brace / Hang lanterns / Repair | A job on the selected tunnel (see below) |
| Panel: Burrow home / Root cellar, then left click beside the tunnel | Dig a chamber there (Esc or right click: cancel) |
| T with the mole **and** others selected | The others join the Foremole's dig crew |
| Right click a tunnel being dug, residents selected | They join its crew |
| Panel: Next weather (demo) / Test event (demo) | Run the one calendar -- farm, weather and date together -- on to the next change of weather (at most 48 h) / bring the next threat |

- **Weather**: the village's one weather (above). Hazards soak while it rains.
- **Hauling**: a carrier may take a bore its load fits (a mouse or squirrel a standard bore, an otter a
  widened one, the badger none); only the surface part of its trip counts toward the carry limit.
  A busy mouth has a short **queue**: walkers wait in a line beside it rather than crowding the hole.
- **Upgrades**: Widen (the mole re-digs five more quanta a metre; otters and the badger then fit),
  Brace (ECON-002's wood 250 + stone 250 milli-U and 25 ticks a quantum, from the demo's own stores --
  the HUD's Wood and Stone are the settlement's), Hang lanterns (a lit bore, walked 10% faster).
- **Hazards** (deterministic, warned, preventable): an unbraced tunnel through wet ground floods after
  40 s of rain (warned at 20); through sand it partly collapses after 75 s of rain or crossings (warned
  at half). The tunnel closes, walkers inside turn back, and Pump out / Clear the fall reopens it.
  Bracing prevents both.
- **Ground** (`tunnel/tunnel_ground.gd`): loam, clay, sand and rock pockets, and the wet stream edge,
  tinted over the village while laying a route and shown as strata underground. Clay digs slower,
  sand faster; rock needs the badger on the crew (the mole alone scratches at a quarter pace).
- **Finds**: every metre cut rolls once (seeded) for flint, clay, an old root store or a rare relic;
  relics tell a short story. The tally is in the panel.
- **Chambers** (`burrow/`): a burrow home has 2 demo beds for moles (counted in the panel, not the
  HUD's Beds); a root cellar is a cold store (spoilage factor 350 per mille, the GDD's cellar). The
  farming demo reads cellars through `burrow_chambers.cellars()`.
- **Crews**: up to three helpers with the Foremole; one worker per quantum's face, so a helper who
  fits finishes behind it (1506 per mille on a standard bore), more faces when widening. The
  Foremole's experience raises its rate a little.
- **Threats** (`events/`): a seeded flood at the stream edge or a fire at the covered store. Residents
  in it take the nearest tunnel out (or walk out), shelter, and go home when it clears.

Staging also runs `tools/make_demo_crop_cards.py` (needs `blender` on PATH, ~2 minutes): the grain
and roots L0s shatter, so their beds are rebuilt as a bare bed plus alpha-cutout cards rendered
from the high-poly sources. Re-run it alone after changing it:
`python3 tools/make_demo_crop_cards.py`. Without Blender those two beds are placeholders.

## Water

A stream runs down the village's east edge -- narrowing to a neck at the north-east corner, past
the weir and the mill, spreading into a shallow ford where the east road crosses it, then deepening
by the fisher shelter -- into a pond beyond the south-east corner with a boathouse on its shore.
All of it lies outside the ±20 m square residents and tunnels are kept in, so nothing in the
village moved; the spots that serve it (fishing, the weir, the boat landing) stand at the square's
edge. The ground is carved into banks and beds; the surface flows at the stream's own speed and
stops when the game pauses. V's overlay cycle ends on the zones and the live fishery. The fishery
runs on the demo's one calendar (its days are the farm's and the HUD's). A flood (the tunnels' threat)
raises the stream up its banks at the ford.

`water/water_map.gd` is the foundation the next phase builds on: integer depth, wade / swim / dive
zones, ground and bed height, flow, nearest bank, landings, ford and bridge candidates, and
`segment_crosses_water` for tunnels. `water/fishing_driver.gd` runs the real fishing store
(`scripts/core/fishing.gd`) on demo time -- the stream is the river habitat, the pond the lake --
and returns each cycle's catch as species lots without touching any pantry. The depths and the
zone thresholds are demo values (`water/water_rules.gd`); decision 0196 records them.

## Layout

| Folder | Owns |
|---|---|
| `demo_manifest.gd` | Reads the staged manifest |
| `demo_clock.gd` | The presentation clock that follows the HUD's pause and speed |
| `world/` | Terrain, lighting, village layout, points of interest |
| `cast/` | The residents: body, clips, live tail, job routines, orders |
| `control/` | Selecting and ordering residents, and the demo party panel |
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view; and their extensions -- ground, queues, crews, jobs, hazards, finds, the demo stores, the tunnel panel |
| `demo_calendar.gd`, `demo_services.gd`, `village_water.gd`, `demo_notices.gd` | The one calendar, the shared set, the one water adapter (over `water/water_map.gd`), the one notice feed |
| `weather/` | The demo's one weather (read from the farm's real §5.10 row) and its rain, snow and light |
| `burrow/` | Chambers dug off tunnels: burrow homes and root cellars (the cellar API) |
| `events/` | Seeded threats (a flood, a fire) and evacuation |
| `water/` | The stream and pond: the integer depth/shore map, carved banks, surfaces, dressing, the fishery driver, the V overlay |
| `farm/` | The farm: real FarmPlot rows, the pantry and its storage providers, the crew's jobs, beds, panels, alerts |
| `ui/` | The woodland HUD skin; the HUD date, the news strip and the right column's tabs |
| `camera/` | The RTS camera |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
