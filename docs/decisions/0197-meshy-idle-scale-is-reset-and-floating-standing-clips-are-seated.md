# 0197 — Meshy's idle scale is reset, and standing clips that float are seated
Date: 2026-09-28 · Status: Accepted

## The defect

In the live demo, creatures **grew and shrank**. Brendan saw it on the badger, then on the otter.

Meshy's `anim_idle` keys the **Hips at a constant scale of (1.1765, 1.1765, 1.1765)**, on both
of its keys (0.033 s and 4.033 s), in **all ten** rigged creatures. The Hips rest scale is 1, so
each creature idles 17.65% larger than it walks. Every blend between idle and any other clip
visibly swells or shrinks it.

A scan of all 110 raw rigged and animation files found **no other channel** more than 1% from
its rest scale. Only `('anim_idle', 'Hips')` strays, ×10.

## Decision

1. **`tools/repair_meshy_rig.py` resets every animated bone scale key to that bone's rest
   scale**, where any key is more than `SCALE_TOLERANCE = 0.01` from it. No Meshy clip animates
   scale on purpose.
   - The keys are written as new accessors, and the source BIN stays an exact prefix.
   - The stamp (version 3) and `repaired.json` record `scale_channels_reset`.
   - It refuses a scale sampler that is shared with another channel, or cubic: resetting it
     would move the other channel, or turn tangents into scales.
2. **`tools/ground_meshy_clips.py` seats a standing clip that floats.** The idle's hips stand
   where they held the 17.65% larger body, so once the scale is gone its feet float 3 mm to
   20 cm (badger quarryman 0.197 m). The grounding rule was lift-only (0193), which left them
   floating.
   - The seat applies when a clip's lowest support, over **every** key, is more than
     `GROUND_TOLERANCE_M` above the ground. The whole clip is then lowered by that constant gap,
     so its motion is unchanged and its lowest key just touches.
   - A clip that touches the ground on any key is only ever lifted, as before, so a run keeps its
     flight phase.
   - Clips in `OFF_THE_GROUND` hover by design, and are never seated. Today that is only
     `anim_chair_sit_idle`: its height is the seat's.
   - The output is refused if a standing clip still floats. `grounded.json` records `seated_m`.
3. **`tools/ground_meshy_clips.py` refuses any clip that still scales a bone away from its rest.**
   Every clip passes through grounding, so this catches a clip that skipped the repair, or a
   new variant of the defect, before it reaches Godot.

## Why fix it in the pipeline, not the demo

It is a defect in Meshy's output, like the material and height defects the repair already
fixes (0190). Resetting it in the presentation would leave every other consumer of the
library, the crowd bake included, playing a 17.65% larger idle.

## Evidence

- **The library, regenerated** (repair → tail → ground → bake):
  - 10 scale channels reset, all `anim_idle` Hips.
  - 10 idles seated, by 0.0034–0.1973 m. The squirrel gatherer's idle dips below the ground,
    so it is lifted instead.
  - Every chair clip keeps its height.
  - No non-idle clip's grounding changed.
- **Audit of every output clip:** 160 `grounded/` and `baked/` files.
  - 0 scale channels off rest.
  - The Hips world scale is exactly 1 on every sampled key.
- **Re-bake:** verdicts are unchanged from 0195, except one: the squirrel gatherer idle's tail,
  5.4 mm below the ground before, is now 17.7 mm above it. The otter fisher's
  `collect_object` flick and the two clips burying their tail base remain, as recorded.
- **`tools/test_repair_meshy_rig.py`: 44 checks.** The new fixture is Meshy's idle, literally
  1.1765 on two keys, reset to 1. A 1.005 scale is left alone. A shared or cubic sampler
  refuses (N08).
  - Mutants: 6 of 7 killed (never reset, keep the keys, no tolerance, zero tolerance, no guard,
    no count).
  - The survivor, resetting after the root fold, is equivalent. The fold never touches a
    descendant's scale, and it refuses an animated root.
- **`tools/test_ground_meshy_clips.py`: 47 checks.** New tests cover:
  - a standing clip that floats 0.548 m is lowered by exactly that;
  - the same clip marked off the ground does not move;
  - a 0.9 mm float is not seated, and 1.1 mm is;
  - a sabotaged seat refuses;
  - only the chair clip is off the ground;
  - a clip that still scales the Hips to 1.1765 refuses (N06).

  Mutants: 10 of 10 killed (never seat, seat off-the-ground clips, zero tolerance, seat by half,
  seat by the highest key, no float check, no report, library ignores `OFF_THE_GROUND`, no scale
  refusal, refuse every scale).

## For future creatures

The asset-pipeline skill (`.claude/skills/asset-pipeline/SKILL.md` §6) now makes the four-step
chain mandatory for any rigged creature. It lists the defect each step fixes. It also requires
**a new clip that sits, hangs, swims or flies to be added to `OFF_THE_GROUND`**, and an
idle → walk → idle check by eye in Godot before a creature is called done.
