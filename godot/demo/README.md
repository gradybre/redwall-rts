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
| T (or "Dig tunnel") | With the mole selected: lay out a tunnel (below) |
| U | Underground view: the surface fades, tunnels show as lit bores with anyone inside |

The "Demo party" panel in the HUD's left column lists the selection. Orders move the demo cast
only, never the simulation.

## Digging tunnels

Select the mole and press T (or its panel's "Dig tunnel" button). Left-click where the entrance
opens, click again for each bend, and the last click is the exit; the route and its length follow
the pointer. Enter or right-click digs it, Backspace takes back the last point, Esc cancels. A
point off the map, or an entrance or exit inside a building, is refused with a clay marker and the
reason in the panel. Only moles dig; T with no mole selected says so.

The mole walks to the entrance, digs its shaft (the `pull_radish` clip), then goes underground:
a mound of earth moves along the route, the route fills in, and spoil heaps grow by the entrance
and, when it breaks through, the exit. The panel reads "Digging tunnel — 43%". Called away, the
mole backs out and the tunnel waits; right-click its entrance with the mole selected to resume.
A finished tunnel stays. Mice, moles and squirrels fit its bore and use it whenever it is
genuinely the shorter way ("Using tunnel"); otters and the badger walk round.

Digging runs at the adopted excavation rate (113 ticks and 2 U of spoil per cubic metre,
`docs/underground_economy_hazard_amendment.md`); the bore size, the stoop that lets a squirrel
through, the depth and the drawn size of a heap are demo values (`tunnel/tunnel_rules.gd`).

Staging also runs `tools/make_demo_crop_cards.py` (needs `blender` on PATH, ~2 minutes): the grain
and roots L0s shatter, so their beds are rebuilt as a bare bed plus alpha-cutout cards rendered
from the high-poly sources. Re-run it alone after changing it:
`python3 tools/make_demo_crop_cards.py`. Without Blender those two beds are placeholders.

## Layout

| Folder | Owns |
|---|---|
| `demo_manifest.gd` | Reads the staged manifest |
| `world/` | Terrain, lighting, village layout, points of interest |
| `cast/` | The residents: body, clips, live tail, job routines, orders |
| `control/` | Selecting and ordering residents, and the demo party panel |
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view |
| `ui/` | The woodland HUD skin |
| `camera/` | The RTS camera |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
