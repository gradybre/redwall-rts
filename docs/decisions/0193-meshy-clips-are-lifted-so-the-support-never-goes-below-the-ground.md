# 0193 — Meshy's clips are lifted so the support never goes below the ground
Date: 2026-09-26 · Status: Accepted

## Decision

`tools/ground_meshy_clips.py` rewrites the Hips translation of every Meshy clip. Key by key,
it lifts the hips by exactly as far as the lowest **support** point is below y = 0, and it never
lowers them. Output goes to `assets/library/creature/<key>/grounded/` for all ten rigged
creatures (100 clips), plus each `rigged.glb` unchanged, and every clip is recorded in
[`grounded.json`](../art-reference/asset_library/grounded.json). The tail bake
([decision 0192](0192-tail-motion-is-baked-into-the-crowd-clips-by-godots-own-spring.md)) now
reads `grounded/`.

## The defect

Every repaired bind pose stands exactly on y = 0 (decision 0190). Meshy's retargeted clips
don't:

- **90 of 100 clips** sink the support below the ground.
- **At idle** the sink is 0.4–10.6 cm.
- **In the otter boatwright's walk** it is 17 cm.
- **In pull_radish** it reaches 26–37 cm; the squirrel forester was buried to the waist.

Nothing downstream can hide that. The crowd plays these clips as they are, and decision 0192's
tail bake could only follow the feet down or flag the clip.

## What counts as support, and why

Support is every vertex whose strongest influence is a **foot, toe or leg** joint. That covers
the feet when standing and the knees when kneeling. This was measured before it was chosen, per
body part, on every clip, with tails excluded:

- **Standing, walking, carrying, running:** the feet are the lowest part, and after the lift
  they land on y = 0.
- **Kneeling (collect_object, pull_radish):** Meshy's human kneel on short legs puts the
  knees 21–37 cm below the ground, with the feet near it. Grounding by the feet would leave the
  shins buried, which reads as stumps. Grounding by the knees lifts the feet off the ground
  behind a kneeling creature, which reads as a kneel. Checked in Godot on the badger cellarer's
  pull_radish and the mouse keeper's collect_object.
- **Not support:**
  - **Arms**, which reach into the soil to dig or pull a radish (the badger's hands go 33 cm
    down).
  - **The body**: the mouse keeper's dress hem hangs below her feet on the chair, and doesn't
    bear weight.
  - **The tail**: the spring handles it. A chained tail's vertices have a tail joint as their
    strongest influence, and rig_meshy_tail.py strips Meshy's thigh weights from them, so they
    are never support anyway.

## Only ever lift

`lift = max(0, -lowest)`. So:
- a run keeps its flight phase;
- a chair clip keeps its seat height: nine of the ten chair clips had the feet 1–10 cm up, and
  they are untouched;
- a clip already on the ground is unchanged.

The lift is continuous wherever the lowest point is, because it is a function of that point.

## How the file is changed

Only the Hips translation changes. It is re-sampled onto the clip's full timeline (its longest
LINEAR rotation input, as in 0192), and each key has the lift added. The lift is converted into
the Hips parent's space: Meshy's armature is scaled 0.01, and a rotated parent is handled too.
The new keys are appended as a new accessor, so the source BIN survives as an exact prefix. The
output carries a stamp holding the source hash.

The tool refuses:
- a clip that animates an ancestor of Hips, because a Hips lift would not be a world lift;
- a clip with no Hips translation;
- a skin with no support joints;
- an already-grounded file.

Each output is **re-skinned from the written file** and refused if any key's support is below
−1 mm, or if a key that needed no lift moved.

## What grounding exposed in the tail bake, and the exact constraint that fixes it

With the feet on the ground, the verdict's floor (decision 0192: the lowest of the ground, the
feet and the tail base) rose to y = 0. That exposed tails whose fur dipped 0.5–2.7 cm into the
ground, in **39 of 60 clips**, and more in a few. The sunk feet had been giving the tail that much
slack.

The cause was not the radius. **The joints themselves sat below their radius**: the
fieldworker's `tail_06` at −0.7 cm, and the otter boatwright's `tail_05` at 2 cm against a 6.6 cm
radius. Godot's collision is soft. It pushes a joint out once per step, and the stiffness pulls
it back towards the animated pose, which for a rigid tail points into the ground. Raising the
stiffness in 0192, to stop the runs thrashing, made that pull stronger.

So the bake now applies **an exact constraint after the simulation** (`lift_tail`). On every
frame it walks down the chain, and wherever a joint (or the tip) would be closer to that key's
floor than its **clearance**, it swings the segment above it up just far enough:
- The segment's length is kept, and so are the world directions of the segments below it.
- The rotations are rebuilt parent by parent.
- The base is never moved.
- A frame that needs nothing is passed through exactly.

Choices, each measured on the real bake:
- **Clearance is each segment's 99th-percentile vertex distance from its axis**, in the bind
  pose (`tail_clearances`). Clips still more than 5 mm under: 4 at the 95th percentile, 2 at the
  99th, 1 at the maximum. The maximum over-lifted, floating the fisher's tail 5 cm up.
- **The swing turns towards "behind the hips"** (the creature's backward direction, from the
  hips' own frame). That blend fades in with the segment's depth. Without the fade, the blend
  switched on the instant a near-vertical segment touched, and that switch alone swung the
  segment up to 57°. The first version took its heading from the tail's own base-to-tip line,
  which flips for a tail hanging straight down; that version was also replaced.
- **The remaining large steps are geometry, not glitches.** Lifting the tip of a near-vertical
  3.7 cm segment by 1 cm takes about 40° of swing. The fieldworker's run tip segment steps 57°,
  which is a 3.5 cm move. No clip crosses the 90° motion flag because of the constraint.

## Evidence

- **The library:**
  - 100 clips grounded; 90 lifted, and the largest lift is 0.371 m (badger cellarer
    pull_radish).
  - Lowest support: −0.371 m before, 0.000 after.
  - Median largest lift per clip: 5.9 cm.
  - Untouched: nine chair clips, plus the badger quarryman's idle, which already stood on the
    ground.
- **Godot 4.7.2**, grounded against Meshy's clip:
  - squirrel forester pull_radish;
  - badger cellarer pull_radish;
  - mouse keeper collect_object;
  - otter boatwright walk.
- `tools/test_ground_meshy_clips.py`: **22 checks**, in the CI contracts job. The fixture is the
  bake tests' Meshy-shaped clip, with the hips dropping 0.6 m on key 2. The foot reaches −0.052
  while the tail and body reach −0.1, so a lift of exactly 0.052 on key 2 alone shows that
  neither the tail nor the body is counted. A scale-2 armature case checks the parent-space
  conversion.
- **12 mutants, all killed** (run with `python3 -B`, `__pycache__` cleared):
  - count every joint as support;
  - allow lowering;
  - lift every key by the clip's worst;
  - drop the stamp, animation, support or ancestor check;
  - ignore the parent space;
  - transpose the parent solve;
  - lift along the wrong axis;
  - drop the re-skinned after-check;
  - drop the unlifted-key check.

  Three **survived** at first:
  - A dead tail-exclusion check. It was removed, and why a tail is never support is documented.
  - Ignoring the parent space. It was invisible at armature scale 1; a scale-2 case was added.
  - The two after-checks. They only fire on a wrong lift, so the tests now sabotage the lift
    and expect a refusal.
- **The re-bake from `grounded/`, with the constraint** (`baked.json`):

  | | Meshy's clips (0192) | grounded + constraint |
  |---|---|---|
  | clips putting the feet or tail base below ground | 53 | **2**, both a buried tail base, feet on the ground |
  | tail more than 5 mm below its floor | 8 (39 once the feet were grounded) | **1**: squirrel gatherer idle, −5.4 mm |
  | a tail joint over 90° in one frame | 4 | **1**: otter fisher collect_object, rising from the kneel |
  | largest loop seam | 14° | 20° |

- `tools/test_bake_meshy_tail.py`: the constraint and the clearances add **13 checks** (59 in
  all). Their **8 mutants are all killed**:
  - never lift;
  - ignore the clearance;
  - ignore the floor;
  - don't re-parent the local rotation;
  - change the segment length;
  - measure no clearances;
  - never take the pass-through;
  - take the clearance from one side only.

  Three survived at first, and each was killed by a test that should have existed:
  - a floor above 0;
  - the hips' 30° yaw, which changes no heights;
  - a non-identity rotation, whose recomputation is not bit-exact.

## Not done here

- **Foot sliding.** A planted foot may still slide horizontally; only height is corrected.
- **Kneels lift the feet.** In the pull_radish and collect_object kneels, the feet come off the
  ground behind the knees, by up to 25 cm on the badger cellarer. That is Meshy's human kneel on
  short legs. A retarget or a hand-authored kneel is the real fix.
- **The keeper's dress** still passes below the ground on the chair; it is cloth, not support.
- **The skeletal pool** runs the spring live and has no exact constraint yet; it still has the
  0192 collider bug too.
