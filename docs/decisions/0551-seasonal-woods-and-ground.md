# 0551 — The woods and the ground follow the seasons: one tree material per model, per-tree instance numbers, bare boughs in winter
Date: 2026-10-01 · Status: Accepted

**Numbering.** Other agents are writing decisions in parallel; this work was given the block 0551–0559 and
takes 0551 (checked free on every local and remote branch and in the sibling worktrees).

Brendan approved seasonal visuals for the live demo on 2026-10-01 (autumn leaf colour, bare winter trees,
spring blossom on the existing tree models, following the demo calendar). It is the seasonal-art part of the
approved review item **UX-028** (its slice 4, "extend seasonal art"). UX-028's own point -- lived seasonal
*scenes* tied to real gatherings, feasts and persistent memories -- is **not** delivered here; it needs the
communal routines it names as prerequisites. Presentation only throughout: nothing here reads or writes a row,
a rate or a tick the village runs on.

## Decision

### What each season looks like (`godot/demo/seasons/season_look.gd`)

- A tree's look is three numbers: a leaf **tint** (a linear hue at unit luminance times a value lift, and how
  much of it the leaves take), the **bare** share of leaf texels dropped, and the **blossom** share. A texel is
  leaf by its colour (green over red in linear light -- the staged oak's leaves ~1.6, its bark ~0.85, the
  beech's grey bark ~0.95 -- and green over blue) and by height: nothing in the model's own bottom 12 % (easing to
  leaf over the next 8 %) is leaf, because the texture paints moss on the roots as green as a leaf
  (`season_leaves.gdshaderinc roots_y`, set per model from its own bound, `bare_boughs.gd roots_mask`). The mask is
  in the mesh's own units: a first version in world height left saplings, shoots, young trees drawn small and a
  felled crown lying on the ground untinted (the review's HIGH finding).
- Twelve days a season. Each season eases in over **2.5 days** (BLEND_DAYS) from the previous season's end,
  and each tree starts that blend up to **1.5 days** late (STAGGER_DAYS) by a stable 32-bit hash of where it
  stands (MurmurHash3's finaliser on a 1/64 m grid; ten bits each for the stagger, the colour and the pace).
- Spring: the fresh green (40 %), and the oaks' catkins -- the demo has no fruit or flowering tree, and an oak's
  spring flowers *are* its catkins, so the blossom is a pale speckle on the oaks, none on the beech. Summer: the
  texture as authored. Autumn: each tree turns over 5–10 days to its own gold, ochre or russet (a tenth dark
  red), 70 % of the way -- DEC-038's restrained ochre and earth; the first pass, fully saturated and lifted
  1.3x, read as salmon orange in the sun and was rejected on the frames. Winter: the leaves fall over the first
  days; bare after, but for marcescent trees (12 % of oaks, 35 % of beeches, 80 % of young oaks keep 30 % of
  their leaves, dry brown).
- **The leaf-out is at the end of winter, not the start of spring** (the thaw, days 8.5–10.5 of winter,
  staggered). The demo opens on Spring 1; a blend at spring's start greeted every new village with bare woods
  for its first forty minutes. Spring's own blend is then from the thawed look into itself.
- **Autumn crowns stay whole.** The first version thinned them from day 6 (55 % by the end); measured, that
  put every crown in the woods through a discard in the depth prepass and every shadow cascade for half the
  season (below). The thinning was dropped; the falling particles and the leaves lying on the ground say the
  leaves are coming down, and they fall in winter's first days.
- An EVERGREEN kind keeps the summer look all year. **The demo stages no conifer**: it is there, and tested,
  so one drops in unchanged; no tree in the village uses it today.
- The ground follows the same calendar without the stagger: fresher grass in spring, drier in autumn and winter,
  fallen leaves through autumn (to 55 %) and 35 % under winter. Every ground colour stays in its DEC-038 value
  group on every day of the year (decision 0301's groups; the suite walks them); the fallen leaves' colour sits
  in the mid group, with the grass it lies on.

### How it is drawn (`season_view.gd`, `season_tree.gdshader`, `canopy_fade.gdshader`)

- **One tree material per model, never one per tree.** The canopy's fade shader (decision 0301) now includes
  the season (`season_leaves.gdshaderinc`), and `canopy_clear.gd fade_material_for` keys its one material per
  model on the mesh's own glTF material. Every staged tree wears it -- or its **in-leaf variant**,
  `season_tree.gdshader`, the same parameters without any discard -- as its *surface override*; the canopy still
  thins a crown by putting the same material on as the override and taking it off. A released fade now sets the
  `fade` instance uniform back to 0 (the tree keeps the shader, so a stale value would leave a dither).
  `roughness` became `roughness_scale` in the shader: the cover include's own `roughness` parameter clashed.
- **Per tree: three instance uniforms** (`leaf_tint`, `leaf_bare`, `leaf_blossom`), written for every dressed
  mesh when the calendar's hour turns, or when a stand revision made or replaced a node (173 trees: 519 calls an
  hour; a revision that made none -- a trunk hauled -- writes nothing). Instance
  uniforms persist across the canopy's material swaps. Nodes are re-collected only when the woods make or
  replace one (a fall's upper part, a shoot, a replanting: `forest_view.gd upper_part` was added for this).
- **What a tree wears**: the in-leaf variant while no leaf is down; the tree shader while some are; its model's
  **bare boughs** in the tree shader once all are (`bare_boughs.gd`: the model's own mesh without the triangles
  that are leaf by the same texel test -- centre leaf, or two corners -- and never a triangle in the model's
  bottom 12 %). A stricter test (no leaf at any corner or edge) shredded the trunks; the bare boughs without the
  discard left leaf shards standing. Made once per model in the boot prewarm (87 ms for three models, under
  heavy load), and one sample of each drawn below the ground in the prewarm's frames, so the first winter
  compiles nothing. If no model gives boughs (its albedo would not read back) the view warns and winter falls back
  to discarding every leaf. Placeholder trees (no texture) keep their own material.
- The weather's cover (`weather_view.gd cover()`, `frost()`, read, never written) is set on the tree materials
  in 0.02 steps and lies on the boughs' and leaves' upward faces through `cover.gdshaderinc`.
- **The ground** is not rebuilt: the view reads the ground material's own grass and litter colours once as the
  base and moves them, and sets `demo_ground.gdshader`'s new `leaf_fall` (drifts at leaf scale, thickest toward
  the woods, none on the worn paths, under any snow). The grass tufts' MultiMesh draws through one shared copy
  of its own material whose albedo the season multiplies.
- **Falling leaves**: one CPUParticles3D of 40 leaf cards (a procedural leaf-shaped alpha-scissor card, the
  autumn colours per particle), over the view's focus, from autumn's day 3 into winter's first days, at the
  game's speed. **Reduced motion turns them off entirely** (decoration, not the 35 % working particles keep).
  Their colours are sRGB vertex colours; they cast no shadow. Drawn two frames below the ground in the boot
  prewarm.
- **The Demo Lab's Season preview** (F8) steps through mid-spring, mid-summer, early autumn (day 3), late autumn
  (day 10), mid-winter (day 6) and back to the calendar. It draws the trees, ground and tufts only: the calendar,
  the crops and the weather do not move (a crop bed keeps growing in a previewed winter). It stays on when the Lab
  closes -- closing the modal is how the previewed village is looked at -- and the button names it. `demo_lab.gd
  add_trigger` takes an optional `done` line for a trigger that makes no news.

## Evidence

- Frames, 1920x1080, paused, UI hidden, canopy clearance off (`scratchpad/season_check/`): the village from the
  default 46 m / 42° view, and a lone oak at the clearing's west edge from 30 m / 14°, at each preset; mid-winter
  under snow weather. Earlier passes (`scratchpad/seasons_agent/v1`–`v6`) record the rejected saturation, the
  bare-woods spring opening, the orange root moss and the two rejected bare-bough meshes.
- Performance, 1920x1080 on the Mac (Apple Silicon), vsync off, paused, clear weather, canopy idle: 8 interleaved
  blocks of 90 frames per configuration, so the machine's load (33–47 during the run) falls on every
  configuration alike; quoted as the quiet blocks (the lower five), against a baseline of every tree on its own
  StandardMaterial3D and no leaves:

  | View | Baseline | Spring | Summer | Early autumn | Late autumn | Mid-winter |
  |---|---|---|---|---|---|---|
  | Woods, 30 m / 30° (NW edge) | 11.35–11.94 | 11.39–11.49 | 11.32–11.57 | 11.38–11.83 | 11.48–11.89 | 13.88–14.20 |
  | Village, 46 m / 42° | 24.6–36.0 | 25.7–34.5 | 24.6–34.8 | 24.4–35.5 | 25.6–34.3 | 24.5–35.6 |

  Spring to late autumn cost nothing measurable. **Mid-winter costs about 2.5 ms in a woods-filled view**: the
  bare boughs still discard the leaf texels left on their kept triangles, and the bare woods show the trees
  behind. The village view was too loaded to resolve below ~1 ms; no configuration stood out. Before the in-leaf
  variant, the bare boughs and the whole autumn crowns, the same woods view measured (quiet blocks, load ~20) summer
  +1.2 ms, late autumn +3.7 ms and mid-winter +5.6 ms. Not measured on the qualification floor.
- New suite `test/test_demo_seasons.gd` (50 tests, no staged assets: the trees are small textured meshes it makes).
  Mutation, one mutant at a time on the new logic and the touched canopy, lab and forest-view lines (each file
  restored and its SHA-256 checked): the first 70 mutants left 15 alive -- the pace draw, the blossom and ground
  blends, the grass shares, the hour gate, the upper part, the dedupe, the redress guard, three bough tests, the
  particles' speed, the own-material fallback and the fade reset -- each now killed by a test; the final set of 77
  (with the review's fixes) is 77 killed.
- Full suite: the hand-back quotes the final line. Two tests failed in full runs under load 30–47 and pass alone:
  the routes live harness at 1280x720 (a dig confirm refused for 120 frames; its own comment records the same on a
  slow CI runner) and the sound cost benchmark's p99.

## Review

The independent `code-reviewer` found no CRITICAL issue. HIGH, both fixed: the world-height leaf mask (above), and
an untested load-bearing line (a re-collect in winter must restore each bare tree's own mesh, or the thaw leaves it
bare all year) -- now tested. MEDIUM fixed: the first winter prewarmed; the instance-uniform parity of the two
shaders tested in declaration order; a dead `fade_materials()` removed; the falling leaves' colours sRGB and
shadowless; revisions without new nodes no longer rewrite every tree; a warning when no boughs are made.
MEDIUM left, recorded here: the bare boughs are built from the surface arrays, so they lose the import's LODs,
shadow mesh and attribute compression (a likely share of winter's 2.5 ms; building them through `ImporterMesh`
with `generate_lods()` is the follow-up); the boughs' texture read-back is not checked inside the exported pack
(the warning says so if it fails); a look whose first split for a fall happens in winter would split the boughs
(the boot prewarm splits every look standing at boot, so the demo never meets it); a re-collect resets every
tree's wear before the refresh puts it back (rare: a fell, a shoot, a replanting). LOW fixed: dead constants,
tautological assertions, the roughness rename's test, the leaf-ratio comment.

## Consequences

- A new tree model needs no table: its leaves are read from its texture, its bare boughs made at boot. A model
  whose bark is green over red (or whose leaves are not) would be misread; check its frames.
- The canopy's fade material is now every staged tree's material: a change to `canopy_fade.gdshader` changes every
  tree, and `season_tree.gdshader` must keep the same parameter list (the suite compares them).
- The leaf-out happens in winter's calendar days; the autumn crowns never thin.
- Winter in a dense woods view costs ~2.5 ms on the Mac; the qualification-floor figure is owed.

## Source

Brendan's approval of 2026-10-01; review UX-028 (`REVIEW_2026-09-30.md`); DEC-038 and
`docs/art-reference/visual_direction_alignment.md`; `world_art_lookdev_brief.md` C2 ("the winter state being a
distinct leaf state and not a colour filter"); decisions 0196, 0205/0206 (prewarm), 0301 (canopy fade, cover,
value groups), 0421 (the calendar's rate), 0471 (reduced motion).
