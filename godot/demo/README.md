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

## Weather, upgrades, hazards, finds, chambers, crews and threats

The tunnel extensions (`tunnel/tunnel_ext.gd`) add a **"Tunnels & burrows (demo)"** panel in the HUD's
right column (it hides while the resident journal is open). Everything runs on the demo clock:
paused, the weather, hazards, jobs and threats hold; at 2x and 4x they run faster.

| Input | Does |
|---|---|
| Left click a finished tunnel's mouth or route | Select it (selected residents stay selected) |
| Panel: Widen / Brace / Hang lanterns / Repair | A job on the selected tunnel (see below) |
| Panel: Burrow home / Root cellar, then left click beside the tunnel | Dig a chamber there (Esc or right click: cancel) |
| T with the mole **and** others selected | The others join the Foremole's dig crew |
| Right click a tunnel being dug, residents selected | They join its crew |
| Panel: Next weather (demo) / Test event (demo) | Skip to the next spell / bring the next threat |

- **Weather** (`weather/demo_weather.gd`, the one weather source): a compressed year of spells, each
  45 s, whose temperatures and rain are read from the real §5.10 tables (`scripts/core/weather.gd`).
  Rain slows surface walking to 80%, snow to 60%, frost to 85% (`surface_speed_permille()`); tunnels
  are not slowed, so walkers take them in bad weather. Rain and snow fall, the light dims, snow and
  frost whiten the ground.
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

## Layout

| Folder | Owns |
|---|---|
| `demo_manifest.gd` | Reads the staged manifest |
| `demo_clock.gd` | The presentation clock that follows the HUD's pause and speed |
| `world/` | Terrain, lighting, village layout, points of interest |
| `cast/` | The residents: body, clips, live tail, job routines, orders |
| `control/` | Selecting and ordering residents, and the demo party panel |
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view; and their extensions -- ground, queues, crews, jobs, hazards, finds, the demo stores, the tunnel panel |
| `weather/` | The demo's one weather source and its rain, snow and light |
| `burrow/` | Chambers dug off tunnels: burrow homes and root cellars (the cellar API) |
| `events/` | Seeded threats (a flood, a fire) and evacuation |
| `ui/` | The woodland HUD skin |
| `camera/` | The RTS camera |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
