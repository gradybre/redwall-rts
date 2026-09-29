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
genuinely the shorter way ("Using tunnel") and nobody is standing on its mouths; otters and the
badger walk round. Inside, walkers keep their distance behind anyone going their way and step
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
it belongs to (roots, cabbage, beans or grain). The farm keeps its own calendar on the demo clock, a
game hour every 2.5 demo seconds (a day a minute at 1x), so pause and 1x/2x/4x govern it too; the
HUD's date is the settlement's clock and runs apart. Harvests go into the **pantry**, counted per item;
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
| V | Map overlay: moisture, then ripeness, then off |
| K / Food | The Pantry |

Threats: spring is wet (beds waterlog and stop growing -- drain them with a tunnel, or raise them),
summer dry (water), frost nights are announced the day before (cover or raise), blight spreads to
the next beds at midnight unless the blighted bed is cleared, and a ripe crop starts losing yield after
48 hours and withers at 120. A finished tunnel under a bed drains it; a tunnel with a mouth at the
water's edge irrigates the beds it runs under. Details and every number's source: `farm/*.gd` headers.

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
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view |
| `farm/` | The farm: real FarmPlot rows, the pantry and its storage providers, the crew's jobs, beds, panels, alerts |
| `ui/` | The woodland HUD skin |
| `camera/` | The RTS camera |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
