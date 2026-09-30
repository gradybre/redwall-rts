# 0204 — The underground pass: which Meshy actions stand in for sleep, dig and crouch, and how they are grounded
Date: 2026-09-29 · Status: Accepted

Builds on [0201](0201-meshy-idles-are-untwisted-to-the-walk-heading-with-the-feet-pinned.md),
[0202](0202-planted-feet-are-pinned-where-they-land.md) and
[0203](0203-the-beaver-joins-the-pipeline-and-every-creature-can-swim.md). The underground revamp design
(§7 asset plan, §10 ruling 4) approved 309 credits: seven props, plus sleep, pick-swing dig and crouch-walk
clips. The asset library README's *Underground revamp pass* lists every task.

## Decision

1. **The actions.** Meshy's library *can* be listed without spending: the public catalogue at
   `docs.meshy.ai/en/api/animation-library` gives every ID, name and category, with a preview GIF for each.
   0203 thought otherwise. The choices, each 3 credits:
   - **Sleep: 267 `Sleep_Normally`**, a looping sleep lying on the back. Not 269 `sleep`, which is a
     sit-then-lie transition, and not 266 `Lie_Down_Hands_Spread`.
   - **Dig: 128 `Heavy_Hammer_Swing` — a substitute.** The catalogue has no pickaxe, mining, digging or
     shovel action. 128 is a two-handed overhead swing brought down to the ground. Rejected:
     - 237 `Charged_Axe_Chop`: a 185-frame crouched charge-up;
     - 99 `Reaping_Swing`: a sideways sword sweep;
     - 127 `Charged_Ground_Slam`: a spell.
   - **Crouch-walk: 524 `Cautious_Crouch_Walk_Forward`**, empty-handed. Not 520
     `Crouch_Walk_with_Torch`, which holds one arm up, and not 559 `Sneaky_Walk`, a comic tiptoe. It
     travels, and grounding extracts that as root motion (0195).
   - One clip of each was bought on `mole_digger` and put through the chain on a copy, before the other 16.
2. **The crouch walk is a gait.** `GAIT_CLIPS` in `tools/ground_meshy_clips.py` gains
   `anim_cautious_crouch_walk_forward`, as 0202 requires for any new locomotion clip. On the trial mole:
   - left out, its travelling feet read as 42 cm of planted slide, and no pin could reach them;
   - listed, its three contacts pin, from 3.6 cm to 0.02 cm.

   This is the tool's only change, and the test names it.
3. **The sleep stays out of `OFF_THE_GROUND`.** That list is for clips whose support hovers: a chair, and
   whatever sits, hangs, swims or flies. A sleeper lies *on* the ground. So the sleep is a standing clip,
   seated by its legs like the idle (0197). On the trial mole, the body lands at +1 mm and the legs at 0.
   A test pins that the sleep stands and the chair does not. To sleep in a bed, play it raised by the
   bed's height.
4. **`root_bin`'s L0 is furniture, 1,900 triangles.** At the small-prop 1,150, the voxel remesh lost its
   feet, posts and top 27 cm. The other six keep the family their size suggests (see the README).

## Consequences

- The dig does not loop cleanly. It ends turned 68–81° from where it began, and grounding leaves an
  intended turn alone (0201). Play it once per strike, facing the work, or author a loop.
- Seating by the legs lets a lying torso sink, up to 19.5 cm for `squirrel_forester`. Grounding counts only
  foot, toe and leg joints as support. A sleep whose body carries weight needs its own rule; this pass does
  not add one.
- `otter_boatwright`'s baked sleep falls 2.6 cm short of its tail's clearance constraint, and the bake exits
  1 on it. Its `grounded/` clip, which the skeletal pool plays, is unaffected.

## Source

- Brendan's ruling 4 (underground revamp design §10, 2026-09-29): 309 credits for exactly this list.
- Meshy's animation library page, fetched 2026-09-29.
- The trial on `mole_digger`, and the manifests `grounded.json` and `baked.json`.
