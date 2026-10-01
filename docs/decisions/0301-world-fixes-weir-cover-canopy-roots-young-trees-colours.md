# 0301 — World fixes: the weir in its stream, frost and snow on surfaces, crowns out of the camera's way, roots where they are, a young-tree stage, world-domain colours
Date: 2026-09-30 · Status: Accepted

**Numbering.** The highest decision on this branch (`fix/review-q-world`, from `fix/review-d-tree-leak`, which
holds 0241) is 0241. Other review fixes are being written in parallel on other branches, so this one takes
**0241 + 60 = 0301**; the gap is deliberate.

Review group Q: findings **F41, F42, F53, F40, F52 and F51** of the live-demo review
(`redwall-review/REVIEW.md`, read-only), and its P8 material, camera, weather and asset/contact packets.
Presentation only throughout: nothing here changes a row, a rate, a tick or an integer the simulation reads.

## Decision

### F41 — the weir joins the stream (`water/weir_fit.gd`, `tools/make_demo_weir.py`)

The weir was the library diorama (its own earth slab, pool and tail water) sunk 0.43 m: a raised block
mid-stream, its bottom 0.47–0.83 m over the bed, touching neither bank.

- **A derived structure.** `tools/make_demo_weir.py` (Blender half `tools/demo_weir_blender.py`) reads the
  library L0 (never writes it) and writes the gitignored `world/weir_structure.glb`: faces whose texel is
  water-blue (747) go; of the rest, only faces with every corner in the structure's own region — the wall's
  band across the model and three downstream stone piers — are kept, and the slab's bottom and the pool's
  upstream fringe go (1783 in all); the mesh is cut through at four x planes (the CUTS). Its own UVs and
  maps are kept. Provenance is recorded the props tool's way: `weir_structure.made.json` (the job, stamped
  with the Blender script's SHA-256, and the source's SHA-256) and the manifest row (source path and
  SHA-256, faces removed and why, the cuts, the stone patch). `stage_demo_assets.py` runs it with the world.
- **Fitted at load** (`water_dressing.gd weir_piece`, through `weir_fit.gd`), at the library weir's own
  scale and sink, so the crest stands where the model has it — it is fitted, not buried:
  - the span to each waterline, from the stream's own capsules (pure: the dressing's footprint knows it
    without a map, and it agrees with `water_map.gd`'s margin to 4 mm);
  - the ends beyond the outer cuts (the left stone pier, the right wall end) move out to stand **0.7 m past
    each waterline, on the bank**, the gaps tiled edge to edge with copies of the plain wall between the
    inner cuts (stretched at most to the next whole copy); the gate, the wheel and the middle pier stay;
  - every foot vertex is let down to 0.08 m under the ground or bed at its own spot;
  - a stone **sill** runs under the wall bank to bank, each block's foot on the bed, low downstream (just
    under the surface) and up to 0.52 model units upstream, where stripping the pool left the wall's foot
    open — textured from the structure's own stone texel patch, each block a little different.
  - It is drawn in the demo's **one water surface**; the upstream pool is no longer higher (the demo has one
    level per body). Unstaged, a plain wall and sill of the same fitted span stand in.
- **Moved 2.2 m upstream** (23.7, −16.2), where the stream is still 4.1 m wide (GDD §5.4's 4–12 m), so
  the swimmers' `weir_bank` landing (z = −14.0) is clear of its west abutment. At the first spot the
  abutment would have stood across that landing's way into the water. The weir-work spot faces it.
- **Its footprint is the fitted one** (cast obstacles, woods blockers, the ground cover hidden).

### F42 — frost and snow lie on surfaces (`weather/weather_view.gd`)

The 60 m camera-following veil (white, alpha 0.42/0.22, laid over the water at y = 0.02) is gone. The cover
is a property of the surfaces, in world space, so it has no edge:

- the ground's shader and the bank film's take `snow_cover` and `frost_cover`: on what faces up, thinner on
  the worn paths (trodden), patchy under frost, **never at or below the water line** (and on the bank, not on
  the wet mud at it);
- every building and prop under the village wears `snow_cover.gdshader` as its `material_overlay` while any
  cover lies (113 meshes): roofs, lids, the tops of stones. Trees and the ground cover do not;
- the water surfaces are not touched. Snow lies fully (COVER 1.0), frost at 0.6, patchy (FROSTY). The
  shared rules (the dry band above the water line, the albedo and roughness under cover, the up test through
  the normal matrix) are one include, `weather/cover.gdshaderinc`.
- The water line is the resting level: in a flood (the tunnels' threat raises the stream at the ford) the
  risen water can lie over a little cover on the bank. Left as it is.
- Particles still follow the camera. Configured twice (tunnel_ext.gd does), the view keeps one set of falls
  (it used to make a second, hidden set).

### F53 — crowns out of the camera's way (`camera/canopy_clear.gd`, `canopy_math.gd`)

- **Crown volumes, measured.** Each crown is an ellipsoid cut at its base, from the staged models at size 1
  after the sink (a probe banded the oak's and the beech's vertices by height): oak 2.6–11.8 m, widest
  6.4 m at 5–6.5 m (centre 6.0, half-axes 6.6 × 6.0); beech 5.5–14.5 m, widest 4.2 m (centre 8.5,
  4.4 × 6.0). A young tree's crown scales with its share.
- **The eye** (`allowed_distance`, `demo_camera.gd` CLEARANCE): an eye that would sit inside a crown
  (grown 0.6 m for the lens) moves along its own line **out past the crown's far side** (at most 25 m
  farther), else in short of its near side (never nearer the focus than 3 m), 0.8 m clear — at once, with
  the zoom target untouched, so the player's zoom returns by itself. Rejected first: always pulling in (a
  spring arm). At the review's NW-oak pose it parked the eye under the crown, 3 m from the trunk, looking
  into bark; out past the crown, with the crown thinned, the trunk, roots and mouse read clearly.
- **The crowns in the way**: only those the lines from the eye to the focus and to each selected resident
  cross, and any within 4 m of the eye, are thinned — at most 8, easing at 5 per second. The thinning is
  `canopy_fade.gdshader`: the tree's own maps, an opaque-pass ordered dither above the crown's base (75 %
  of its pixels, all of them within 5 m of the lens), the trunk untouched, and only in the view's passes —
  the sun's shadow cascades see the whole crown, so the shadow does not speckle.
- **The selected**: `selected_xray.gdshader` on the selected residents' body meshes, drawn only where the
  scene's nearest surface is more than 0.6 m nearer than the resident (as view distances): a brass
  silhouette through a crown or a roof, never through the grass at its feet (the first version, comparing
  depth-buffer values with a tiny bias, speckled the body wherever a grass card crossed it).
- **No first-use stall**: both materials, and every resident's silhouette, are drawn for two frames in the
  boot prewarm (`demo_prewarm.gd add_frame_step`, decisions 0205/0206); so is the frost/snow overlay.

### F40 — roots where they are (`forestry/forest_root_field.gd`)

The walkers' lift read a radial median profile; the staged oak's roots are lobes, and the review's point by
`oak_nw` — (−18.08, −19.12), tree-local (−0.39, 1.45) at yaw 110°, size 0.95 — got 0.76 m of lift over
bare ground. Now each staged model's own **support heightfield** is baked once from its mesh (12.5 cm
cells out to the root reach; the highest surface at or below 1.6 m — anything higher is trunk or crown),
about 8 ms a model, once (the woods' obstacles and the view share the bake), and read in the tree's own frame (its spot, the world's `Basis(UP, yaw)`, its size, a
young tree's share) bilinearly. At the review's point the field reads **0.09 m** (the radial profile:
0.76 m). The lift keeps its bucket grid as the broad phase and adds a reach test before the lookup.

**Root obstacles** where there is no stable walk surface (proud by more than 0.45 m): one flare circle about
the trunk out to the farthest proud cell within 0.8 m of the trunk's own circle (the oak's buttresses: radius
1.9 m at size 1), then the proudest lobes beyond, 0.5 m each, 16 circles a model at most (oak 10, beech 1).
They join the cast's obstacles before it is built (168 for the staged woods in reach). Like the trunk circles
they are static: a felled or young tree keeps its full-size circles (documented, not changed). The review's
point now lies inside the oak's flare circle: a mouse ordered there stops just outside it.

### F52 — a young-tree stage (`forestry/forest_view.gd` GROWING)

A regrowing tree climbs **one height ramp** over the row's 48 days, from 0.3 of the sapling to the mature
tree's own height. Below the sapling's full size (GROW_TO 1.35 of it) the sapling or shoot is drawn; past it,
the tree's **own mature model scaled to the ramp's height** — about a third at the swap (0.33–0.35 for the
oak, 0.29 for a beech), the heights equal within one permille of growth — let down by the same share of its
sink, at the tree's centre, with the stump model and the stub hidden. The ramp makes the swap fall about a
quarter of the way through (it depends on the kind and size), so most of the growth is a young tree. At
the midnight it matures it stands at its unscaled transform (`_tree_rest`, kept apart from `_rest`, which
is the falling part's), so the fall reads the full-size pose. The drawing is a function of the calendar hour
alone, so 1x and 4x reach the same poses. A spot the woods call occupied (§5.9's hold) keeps its shoot — no
young tree grows through a spoil heap. The walkers' lift reads a young tree's roots at its share; its
blocking keeps the static full-size circles (above).

### F51 — world-domain colours (`world/world_look.gd`)

`world_look.gd` and `water_surface.gd` said their colours were blends of the UI lock's ART-LOCK-001 pigments;
the world-art direction says the UI's twelve pigments "do not become global world-rendering rules". The
authority is now DEC-038: named **material targets** (ground, bank, water), each held in a declared **value
group** by linear luminance — dark < 0.10, mid 0.10–0.26, light 0.26–0.50, sky > 0.50 — and the worn path at
least 1.4× the grass. **No colour changed.** Compared against the approved example's RTS panel (median
texels, lit): dirt path 0.39–0.43, lit grass 0.11–0.22, stone flags 0.49, fern shade 0.06, timber 0.06 —
path over grass 1.8–3.4×. Ours (albedo): path 0.315, grass 0.159/0.217 (1.45–1.98×), moss, earth, litter,
muds and bed 0.05–0.10, shallows 0.24, deep water 0.016, foam and horizon > 0.6. Every target already sits
in its group and keeps DEC-038's restrained moss, oatmeal, ochre and earth relationship; the example has no
water, so the water targets are judged by value order alone (deep < shallows < sky). A new hue may be added
when the world reference calls for one. `farm/farm_look.gd` still cites the lock for the crops' tints
(group B's file; left open).

## Evidence

- Suite: `./tools/run_tests.sh` — see the hand-back for the final line. New suites (no staged assets):
  `test_weir_fit.gd`, `test_weather_cover.gd`, `test_canopy_clear.gd`, `test_forest_root_field.gd`,
  `test_forest_young_tree.gd`, `test_world_material_targets.gd`; `tools/test_make_demo_weir.py`.
- Frames, before and after (`scratchpad/rv_q_check/before`, `after`): the weir from the east, west, low and
  upstream; frost and snow over the stream, the village, the pond and far; the NW-oak case at 7/11/22/70 m and
  30/50/75°, with a selected mouse under the crown, and behind the hall's roof; a mouse round `oak_nw`'s
  roots; the regrowth sequence.
- Performance, 1920×1080 on the Mac (Apple Silicon), vsync off, paused (render and frame work), 600 frames:

  | View | Mean | p95 | p99 |
  |---|---|---|---|
  | Default view | 8.33 | 8.45 | 8.55 |
  | NW oak 22 m / 50°, canopy off | 9.02 | 9.22 | 9.35 |
  | — two crowns thinned | 11.50 | 11.77 | 11.88 |
  | — and a selected silhouette | 11.51 | 11.74 | 11.91 |
  | Village, clear | 8.33 | 8.49 | 8.57 |
  | Village, snow lying (113 overlaid meshes) | 9.08 | 9.29 | 9.42 |

  The thinning's cost is the discard (the same shader without it measured 9.25 ms): about 2.5 ms when two
  crowns fill most of the screen, 0.1 ms in the far and close NW-oak views, 0.9 ms west of the square — it
  scales with the thinned crowns' screen area, which MAX_FADED and the sight-line rule bound. **First fade:
  no stall** — the 40 frames after the canopy wakes run 8.9–11.7 ms, rising to the thinned steady state as
  the fade eases in; the first snow cover's 40 frames run 8.0–10.7 ms. Boot prewarm steps: canopy fade and
  silhouette 18.0 ms, frost and snow overlay 18.6 ms (two frames each, behind the opening pause).
- Crossing navigation: no swim link, ford or bridge candidate meets the fitted weir; one swim link that
  crossed the stream where the weir now stands (z ≈ −14.8…−15.1) is no longer offered (23 → 22), and every
  landing keeps its status.

## Review

The independent `code-reviewer` found no CRITICAL issue. Its HIGH finding — the canopy's own frame path
(`_process`, the selection's sight lines, the silhouette in the U view, the prewarm's reset, the release of a
hidden faded tree, the revision refresh, the rig's per-frame clearance) had no test, and a mutation of each
survived — is fixed with tests that drive that path (a placeholder cast and a real command layer; outside
the tree the frame reads the rig's and the actors' own transforms). Its MEDIUM findings are fixed: the
weather prewarm's overlay was taken off by the view's next frame (now held while the step runs); the weir's
normal test now checks the stretch's direction; each model's root field is baked once; the cover rules are
one shader include; containers typed. LOW: a non-finite clearance is ignored; the sight-line scan stops at
MAX_FADED; a freed faded mesh is dropped before its tree fades again; the cover's up test uses the normal
matrix; the weather step has its own frame constant.

Mutation runs, one mutant at a time on the new logic (each file restored and its SHA-256 checked): 92
mutants, 90 killed. The two that survived first were equivalent — an early return for triangles wholly
below the ground and a shortcut for an eye already in the open — and that code was removed.

## Consequences

- A weir is fitted from its structure and the map; re-staging needs Blender for `weir_structure.glb` (else
  the placeholder). Changing the CUTS means changing `weir_fit.gd`'s constants too (`test_make_demo_weir.py`
  checks they match).
- Root obstacles are static and baked from the staged model: a new tree model needs no table, only staging.
- The camera may sit farther than the zoom asks while a crown is in the way.
- Thinned crowns cost frame time in proportion to their screen area; the qualification-floor measurement is
  still owed.

## Source

Review F40–F42, F51–F53 and P8; decisions 0196, 0205 (prewarm, "flush in the ground" sinks), 0206 (the
prewarm frame step), 0241; DEC-038 and `docs/art-reference/visual_direction_alignment.md`.
