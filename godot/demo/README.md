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
| V | Water inspection overlay: wade / swim / dive zones, fords, bridge spans, landings, fish stocks |

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
stops when the game pauses. Press V for the zones and the live fishery.

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
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view |
| `water/` | The stream and pond: the integer depth/shore map, carved banks, surfaces, dressing, the fishery driver, the V overlay |
| `ui/` | The woodland HUD skin |
| `camera/` | The RTS camera |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
