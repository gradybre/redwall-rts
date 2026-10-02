# 0971 — Art pass 3: preserving and brewing, the digging revamp, and free effects
Date: 2026-10-02 · Status: Accepted (Brendan's approval of the list, the icon style and the sizes, DEC-048; visual
acceptance is still his, through `tools/art_gate.py`)

Numbered 0971: art pass 3 was given 0971–0979, and none was taken on any branch or worktree. Pass 1 is 0941 and pass 2
is 0951.

## What Brendan approved

On 2026-10-02 Brendan approved an itemised list for the live demo, in his words **"Let's do the preserving/brewing,
digging revamp, free now"**:
- **Models**, in the world style (DEC-038, the right-hand panel):
  - a stoneware crock, a jar shelf, a barrel and a brew vat;
  - timber tunnel supports (props and a lintel, modular);
  - a rock face for hard ground in tunnels.
- **Icons**, at first held for his ruling on the icon style (see "Brendan's icon-style ruling" below):
  - jam, pickles, dried fruit, cheese, ale and cider;
  - coins, an old map and a spring.
- **Free**, with no credits:
  - bees for hives;
  - a fire for a lightning-started fire, and a lightning flash and bolt;
  - an ice shader for winter ponds and rivers.

The coordinator delegated the paid calls to a subagent under
[decision 0961](0961-paid-generation-is-by-request-and-may-be-delegated-within-an-approved-cap.md), with:
- a **hard cap of 270 credits**, counted from this pass's own tasks;
- Meshy as the only service.

## Brendan's icon-style ruling (2026-10-02)

After the icon-style probe ([decision 0981](0981-icon-style-probe-house-and-mouse.md), branch `art/style-probe`: one
icon-style house and mouse compared at the game camera), Brendan ruled, relayed by the coordinator:

- **The world keeps its current look.** DEC-038 is unchanged.
- **Item and dish icons stay in the 3D-render style,** matching the existing pantry icons and pass 1's 24.

This pass then:
- **generated the nine held icons in that style**: one `nano-banana-2` 3×3 sheet, 6 credits, conditioned on pass 1's
  `sheet_foods_a`, and cut exactly as pass 1 cut its sheets into transparent 128 px icons;
- **amended the UI art lock** to match: `asset_generation_lock.md` (its new "Style scope" section),
  `asset_generation_lock.json` (`style_scope`) and `docs/design/ui_refinement/README.md`.
  - Item, food and dish icons use the studio render that 0981 describes, and are outside ART-LOCK-001.
  - The watercolour with ink contours stays for portraits, emblems, medallions, the tapestry, and ceremonial or
    illustrative UI.
  - **Brendan's follow-up ruling (2026-10-02): the top bar stays watercolour.** The top bar's resource and command
    icons, including RES-FOOD's stew bowl, stay in the watercolour family. Only list item, food and dish icons use
    the 3D-render style. The lock's sixteen rows therefore stand as locked.

## Spend

The pass spent **228 of 270 credits**. The balance was checked before each group and after it:

| Group | Calls | Credits | Running |
|---|---|---|---|
| 1 | 6 concepts (nano-banana-2 image-to-image, from the world style reference) | 36 | 36 |
| Redo | the rock face's concept (see choice 5) | 6 | 42 |
| 2 | 6 meshy-7 high-polys (PBR, 2K, triangles, no remesh) | 180 | 222 |
| Icons | 1 nano-banana-2 3×3 sheet (after the style ruling) | 6 | 228 |

All 14 tasks succeeded. The ledger's art-pass-3 rows sum to 228; the task IDs are in
`docs/art-reference/asset_library/meshy_tasks.jsonl`.

- **The balance.** It was 410 at the start, 176 after the models and 104 after the icons. The style probe (decision
  0981) was spending from the same account at the same time; its tasks (`01a0fc72-…`, `01a0fc74-…` and its
  high-polys) are **not this pass's** and are left out of its ledger. The cap is counted from this pass's own tasks'
  `consumed_credits`.
- **What was not spent.** 42 credits of the cap are unspent. No Meshy remesh, rig or animation was bought: every L0,
  the kit's split and set, and every effect were made free in Blender and Godot.

## Choices

1. **The barrel is a brewing cask, not a second copy of the library's barrel.** The library already has an upright
   `barrel` (decision 0188). It is drawn at 0.95 m in the village and 0.5 m in cellars, and already has a spigot. The
   approved barrel was bought for brewing as `ale_cask`: a cask on its side on a two-beam cradle (a stillage). It reads
   as a different object at the kitchen and at the hall.
2. **The jar shelf is not the pantry shelf.** The library's `pantry_shelf` is a tall general larder rack. `jar_shelf`
   is low and wide, with solid plank ends (no thin legs, which meshy-7 breaks on). It carries only cloth-capped
   preserve jars.
3. **The tunnel supports are a modular kit bought as one model.**
   - One concept showed the two pieces apart, a prop post standing and a lintel lying, and one high-poly made both
     (36 credits, not 72). `tools/art_pass3_blender.py` cuts them apart.
   - **Pieces are found by shared vertex positions, not shared vertices.** The baked L0 splits its vertices at every
     UV seam, so edge-linked "parts" were UV charts. The first cut gave the post a stray lying beam and left the
     lintel without its top. Welding by position (1e-5) finds the two real pieces.
   - The post is stood plumb by its principal axis. The lintel is laid along X, sized to the springline (1.1 m), and
     its cross-section is squashed to 0.13 m: Meshy's beam was twice as deep as a cap over a 0.6 m post reads.
   - **The set** is two posts and the lintel seated on the posts' shoulders, measured at 0.883 of the post's height,
     so each tenon enters a housing. It is sized to the standard bore: 0.72 m tall (`FRAME_CROWN_SHARE` × the 1.0 m
     crown) and posts on the 1.0 m floor's edges. It replaces `tunnel_brace` by changing `BRACE_KEY`, because
     `frame_fit` fits any staged brace.
   - The set's budget is the furniture family's 2,000, so the kit was decimated to 1,200 for the pair. The set has
     1,714 triangles.
   - **The lintel is not turned over in the set.** It lay on the ground in the concept, so its underside is untextured.
     Turned over, that bare face showed along the top.
4. **Wide bores take more pieces, not a stretched lintel.** A 2 m floor gets three posts and two lintels end to end,
   as a wide drift is timbered. One lintel stretched 2× would stretch its notches and grain.
5. **The rock face's first concept was rejected (6 credits).** It drew the slab inside a translucent box, which
   image-to-3D would have built. The redo asked for a solid upright slab with "no box, no glass, no frame". The
   rejected image is kept as `concept_rejected_box.png`, and its task is in the ledger.
6. **The rock reads against earth by temperature and fracture:** cool blue-grey veined stone against the bores' warm
   brown earth. It is a wall piece, 1.0 m across (a standard floor), back flat to the wall, front (+Z) to the bore. It
   can be tinted through the instance colour if it reads too cool under lantern light.
7. **The effects are committed code, not staged assets.** Bees, fire, lightning and ice build their own meshes and
   materials, so they draw identically in CI and on a fresh clone, and need no LFS.
   - **Bees are a MultiMesh, not particles.** The warren's particle budget is spent (decision 0211), and a bee flies a
     path and faces it. The wing beat is per-instance custom data, so one shared material holds no swarm's state.
   - **The fire is pool-friendly.** Its emitters and light are built once, at a fixed 54 particles a fire.
     `ignite`, `douse`, `release` and `is_idle` reuse it, and nothing is allocated after `configure`.
   - **The lightning never flashes more than twice a second** (`MIN_GAP_S` 1.5 s; two strokes a strike), which is
     under WCAG 2.3.1's three. Reduced motion gives one soft swell instead.
   - **The ice is an include plus an iced copy of the water shader.** It is not edited into `water.gdshader`, because
     the brief was a material the water revamp switches on. `make_art_pass3.py --check-ice` guards the copy against
     drift. Moving water resists freezing, so the stream keeps an open channel, as `pond_ice.gd` says it must.
8. **Icons: briefed in both styles while held, then made in the 3D-render style** once Brendan ruled. The briefs and
   both styles' prompts are in `docs/art-reference/art_pass3_icon_prompts.md`. Style A's sheet,
   `assets/library/icon/sheet_preserves_finds/sheet.png`, was used as written. `make_art_pass3.py --icons` cuts it
   into `godot/demo/assets/icons/<key>.png` (128 px RGBA, 4 px margin). It uses pass 1's cutter, repeated so this
   branch stands alone.
   - The keys are proposed: `item_jam`, `item_pickles`, `item_dried_fruit`, `item_cheese`, `item_ale`,
     `item_cider`, `find_coins`, `find_old_map`, `find_spring`.
   - **Two deviations from the briefs** were accepted rather than spending a redo, because neither reads at 128 px:
     - the map carries scribbled pseudo-lettering and a compass rose;
     - one coin has a square hole.
   - Pass 1's `sheet_dishes_c` also holds an uncut cheese wedge in the same style, so there is an alternative cheese
     at no cost.
9. **The sizes are Brendan's ruling (2026-10-02).** They were proposed by this pass, judged against the 1.00 m
   mouse, and approved as proposed; they are recorded as [DEC-048](../setting_decisions.md):

   | Asset | Proposed size |
   |---|---|
   | Crock (`crock_stoneware`) | 0.50 m tall |
   | Jar shelf (`jar_shelf`) | 0.95 m tall |
   | Ale cask (`ale_cask`) | 0.80 m tall (0.70 read as a keg beside the vat) |
   | Brew vat (`brew_vat`) | 0.95 m tall, its rim at 0.80 m (1.10 put the rim at a mouse's chin) |
   | Post (`tunnel_post`) | 0.668 m tall |
   | Lintel (`tunnel_lintel`) | 1.10 m long |
   | Timber set (`tunnel_set`) | 1.10 × 0.72 m |
   | Rock face (`rock_face`) | 1.00 m across, 0.765 m tall |
   | Bee (`bee_swarm.gd` `BEE_LENGTH_M`) | 0.09 m long |

   The kit's sizes follow from the bore profile; the rest were judgement. They stay demo presentation sizes, like
   pass 2's (DEC-047).

## What this does not do

- **It wires nothing into gameplay code.** The map, with the code each asset serves and what the integrator changes,
  is `docs/art-reference/art_pass3_mapping.md`. It covers the preserving, brewing and feasts stations, the digging
  revamp, hives, weather and water.
- **It accepts no art.** The binaries live in the gitignored library and `godot/demo/assets/` (decision 0188).
- Brendan's review uses the contact sheets in the session scratchpad's `art3_check/`.

## Tool behaviour found

- **A young CPUParticles3D smoke emitter showed a black ball at its base.** This was seen with a
  `StandardMaterial3D` that used `BILLBOARD_PARTICLES` and vertex colour, while the emitter was younger than its
  lifetime. It went once the billboards were drawn with `fire_fx.gd`'s own particle shader, which discards any
  particle with no colour (no flame, smoke or ember is black). The likely cause is the particles not yet born, but
  the engine source was not read to confirm it.
- **`godot --path godot -s <absolute path>` runs a script that lives outside the project**, so review harnesses need
  not be added to the repository.
- **The baked L0's vertices are split at UV seams** (glTF must split them). Any "connected part" test on an L0 must weld
  by position first (choice 3).
