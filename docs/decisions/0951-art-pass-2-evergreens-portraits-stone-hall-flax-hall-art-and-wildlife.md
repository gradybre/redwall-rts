# 0951 — Art pass 2: evergreens, portraits, the stone hall, flax, hall art and wildlife
Date: 2026-10-02 · Status: Accepted (Brendan's approval of the list; visual acceptance still his, through `tools/art_gate.py`)

Numbered 0951: art pass 2 was given 0951–0959, and none was taken on any branch. Pass 1 is 0941.

## What Brendan approved

On 2026-10-02 Brendan approved an itemised list for the live demo, in his words **"Build all"**:
- a pine and a yew;
- the nine named residents' portraits;
- the stone-built Great Hall (stage 2);
- flax at its growth stages;
- tapestry artwork;
- a chronicle page;
- a hall banner;
- a songbird, a butterfly, a frog and a leaping fish, with clips.

He also approved free fixes: window glow masks and the winter oak's shards.

The coordinator delegated the paid calls to a subagent under
[decision 0961](0961-paid-generation-is-by-request-and-may-be-delegated-within-an-approved-cap.md) (PR #213), with:
- a **hard cap of 450 credits**, counted from this pass's own tasks;
- Meshy as the only service.

The record of 0961 itself is on `docs/art-lock-request` until #213 merges.

## Spend

The pass spent **372 of 450 credits**. The balance was 782 before and 410 after; pass 1 shared the account and spent
nothing meanwhile. The balance was checked before each group and after it:

| Group | Calls | Credits | Balance after |
|---|---|---|---|
| 1 | 5 concepts and 5 meshy-7 high-polys (pine, yew, songbird, butterfly, frog) | 180 | 602 |
| 2 | 3 portrait sheets (nano-banana-pro), the stone hall concept (pro), the flax and banner concepts, the tapestry ground, the emblems and the chronicle page | 66 | — |
| 3 | 3 meshy-7 high-polys (hall stage 2, flax, banner) | 90 | 446 |
| Redo | the flying songbird: a concept and a meshy-7 high-poly | 36 | 410 |

All 24 tasks succeeded, so none failed or was charged for nothing. The ledger's art-pass-2 rows sum to 372. Task IDs
are in `docs/art-reference/asset_library/meshy_tasks.jsonl`.

## Choices

1. **No Meshy rig or animation was bought, for any of the wildlife.**
   - Meshy's rig is a generic 24-joint humanoid (decision 0188). A bird, a butterfly, a frog and a fish are not
     bipeds, so "where the rig supports them" is nowhere.
   - Each attempt would also need a 5-credit remesh first, because the auto-rigger takes at most 300,000 faces and
     every high-poly is over that.
   - Instead, `tools/art_pass2_blender.py` authors a small armature per animal and its clips:
     - bird: idle, hop and peck;
     - flying bird: flap and glide;
     - butterfly: flap and rest;
     - frog: idle and hop;
     - fish: swim and leap.
   - This is free, and was checked in Godot: every clip plays and moves (`art2_check/wildlife_clips_godot.png`).
2. **A second songbird, on the wing, was the one redo (36 credits).** The perched robin's folded wings cannot flap.
3. **The leaping fish reuses the 2026-09-29 pass's `item_trout` high-poly.** It is a whole, live-looking brown trout,
   so this spent nothing.
4. **Flax is one plant plus the farm's stage rules, not a model per stage.** That is how every crop is staged:
   `make_demo_props.py` `PLANTS` makes the card atlas, and `farm_look.gd` stages it by scale, cell and tint. The
   library's older `crop_flax_ripe` is a whole bed, so a single-plant `plant_flax` was bought to match the 2026-09-29
   plants. Its soil line is −0.797, measured as theirs were.
5. **The stone hall was conditioned on the timber hall's own concept,** so it reads as the same hall upgraded. It is
   then turned +90° and fitted to the timber L0's length and centre, so it drops into the same footprint at the timber
   hall's scale.
   - It brings a second chimney of its own. Decision 0771's composed `chimney_pot` should not also show.
6. **Portraits are per resident, in each resident's own clothes,** generated three to a sheet from their library
   concepts. They sit inside ART-LOCK-001 §5's medallion frame: the I03 roundel, the I07 ring, the I01 contour and the
   sprig.
   - The lock's species medallions wear one plain tunic, and ART-UI-06 keeps emblems as species marks. A portrait is a
     new slot beside that rule, and the integrator decides where it shows.
   - The 24 px export is the lock's diagnostic, not a size to ship.
7. **Tapestry art is original village design** (LORE-R07; decision 0771):
   - a woven ground with an oak, acorn and wheat border;
   - eight embroidered emblems, one per `tapestry.gd` kind.

   It has no figures, animals or weapons, and nothing of Martin's.
8. **Window glow is an emissive mask in each L0's own UV space** (decision 0541 found one baked material and no
   window slot). It is shipped two ways: as a PNG, and as a copy of the L0 with the mask as `emissiveTexture`.
   - Glass is the albedo's dark, cool texels, kept only under wall faces below the eaves and above the plinth. It is
     rasterised from the UVs, because Meshy's atlas packs slate and glass alike: a colour-only mask lit whole roofs.
   - The masks work for the timber hall and the stone hall.
   - The residence has **no glazed windows**, only closed shutters, so its mask is effectively empty. Its door spill
     light stays.
9. **The winter oak's shards came from two cuts that disagree.**
   - `bare_boughs.gd` keeps a triangle unless it is leaf at the 1.2 midpoint. The shader discards leaf texels from the
     ramp's start, 1.08. The yellow-green leaf triangles between the two survived as geometry and were half-discarded
     as texels.
   - The authored `oak_mature_bare.glb` cuts at 1.08 and then removes islands, slivers and branch-end flaps. It caps
     the open ends, settles the root mound's skirt under the 1.2 m sink line, and fills every leaf texel of its own
     albedo with bark, so nothing is discarded.
   - It has 778 triangles and one surface. A few root flares still catch snow.
10. **Two L0s needed a tighter unwrap.** `demo_props_blender.py`'s 1% island gap on thousands of Smart-UV islands left
    the pine and the stone hall using 1.8–1.9% of their texture. They are re-unwrapped at a 0.05% gap and repacked.
11. **The pine's needles were teal:** blue was above green in 86% of crown texels, so the season system's leaf test
    (green ≥ blue) read them as bark. The pine is re-tinted to pine green, and 82% of its texels pass now. The yew
    passed as generated.
12. **The wildlife sizes are proposals, not approvals:**
    - songbird 0.45 m;
    - butterfly 0.36 m span;
    - frog 0.40 m;
    - trout 0.80 m.

    They are judged against the 1.00 m mouse at the demo's storybook scale. The skill says a new species' height is
    Brendan's, recorded in `setting_decisions.md`. The bodies are in metres, so a resize is one uniform scale.

    The tree heights are proposed too: pine 16 m and yew 10 m, beside the demo's 13 m oak. They are `DEMO_HEIGHT_M`
    values, which are demo-only.

## What this does not do

It wires nothing into gameplay code; those branches are being integrated. The map is
`docs/art-reference/art_pass2_mapping.md`. It accepts no art either: the binaries live in the gitignored library and
`godot/demo/assets/` (decision 0188), and Brendan's visual acceptance through `tools/art_gate.py` is still to come.
Contact sheets for that are in the session scratchpad's `art2_check/`.

## Tool behaviour found

- `godot -s` scripts run before the tree exists. An `AnimationPlayer` added in `_init` does not apply `seek()`, so
  every clip read "moves 0". Running on the first `process_frame` fixes it.
- Godot's orthographic `Camera3D.size` is the **vertical** extent.
- Blender's `image.pixels` returns an 8-bit sRGB PNG's stored values, not linear ones. Thresholds written for shader
  nodes, which see linear values, must be converted.
- A bone with no roll that points along ±X has its local X along the body axis. Rolling it about its own Y twists the
  wing instead of flapping it. A vertical root bone's local Z is horizontal, so a "lift" keyed on it slides the body
  instead.
