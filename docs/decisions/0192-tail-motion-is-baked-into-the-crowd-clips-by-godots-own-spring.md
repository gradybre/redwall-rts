# 0192 — Tail motion is baked into the crowd clips by Godot's own spring
Date: 2026-09-26 · Status: Accepted

## Decision

`tools/bake_meshy_tail.py` writes the tail's spring motion into every clip of the six tailed
creatures ([decision 0191](0191-tails-get-an-eight-bone-chain-found-from-authored-centrelines.md)).
It adds ordinary glTF rotation channels on `tail_00`–`tail_07` and writes the results to
`assets/library/creature/<key>/baked/`. All 60 clips are recorded in
[`baked.json`](../art-reference/asset_library/baked.json), each with its ground and motion
verdicts.

The crowd tier plays baked clips and runs no simulation (crowd architecture §9), so without this
its tails would hang rigid off the hips. The skeletal pool (≤ 24 actors) runs the spring live on
`tailed/`. That path has open problems; see the correction to 0191 below.

## Why Godot's simulator, headless, and not a Python spring

The motion is simulated by **Godot 4.7.2's own `SpringBoneSimulator3D`**, run headless by
`tools/godot/bake_tail_spring.gd`, with per-creature settings from `tail_centrelines.json`. The
skeletal pool uses the same simulator, so a tail moves the same way on either tier. A Python
re-implementation would have been a second spring to keep in agreement with the first.

## What the bake has to get right

Each of these was found by a wrong result, not anticipated.

- **A unit-scale skeleton.** Meshy's skeleton sits under the glTF armature's 0.01 scale. Under
  a scaled skeleton, Godot 4.7.2's `SpringBoneCollisionPlane3D` is wrong. This was isolated with
  a procedural 5-bone chain, with no Meshy data involved:
  - **At scale 1:** a plane 5 m below does nothing, and a plane at 0.5 m holds the chain at
    0.47–0.50 m. That is correct.
  - **Under a 0.01 parent, same world geometry:** the 0.5 m plane throws the chain horizontal,
    at 0.98–1.0 m, and the plane 5 m below still lifts it by about 0.2 m.

  On the real files this held the otters' tails horizontal, 20–44 cm off the ground, and flipped
  the otter fisher's up behind its body. The bake moves the scale into the bone rests and the
  bone position tracks before it builds the spring. That leaves every world position unchanged,
  and every local rotation, which is what is recorded. It refuses if unit scale isn't reached,
  or if a tail joint moves.
- **Per-joint radii need individual config.** Without `set_individual_config(0, true)`, Godot
  ignores `set_joint_radius` and uses the setting's radius, 0.02 m by default. Individual config
  also makes stiffness, drag and gravity per-joint, so every joint is set explicitly and read
  back, and any mismatch refuses the bake. With the line removed, the bake refuses.
- **Root motion carried across the loop.** The carry walks move the hips 1.0 m (mouse) to 1.8 m
  (otter) over the clip, then snap back at the wrap. The spring saw a teleport and whipped the
  tail through 150–176° in one frame. At the wrap the creature is now moved forward by the clip's
  horizontal travel, so the motion is continuous.
- **Never a zero-time step.** At the wrap the step was `times[0]`, which is 0, and that left
  `tail_00` about 170° off for one frame. The wrap is now one ordinary key gap.
- **Warm up for 3 s of motion, at least one loop**, and record the next loop. A cross-fade of
  two recorded loops was tried for the squirrel gatherer's 126° run seam and removed: the two
  loops were identical frame for frame. The motion was periodic, just violent (see the next item).
- **Otter and squirrel-gatherer settings.** These were tuned by eye under the collider bug. With
  correct collisions, the tails thrashed on `run` at a median of 31–47° per frame, with 54–127°
  seams. Stiffness ×4 and drag 0.9 bring the run to at most 24–25° per frame, with 12–14° seams.
- **The spring's ground is y = 0, lowered only where the clip buries the tail's base.** Kneeling
  clips carry `tail_00`, which the hips place and the spring doesn't, below the ground. With the
  plane at 0 the chain started inside it, and the mouse's thin tail folded into hairpins: joints
  bent back 150–173°. So the plane, per key, is min(0, tail_00's height less its radius).
  **The feet are deliberately not followed.** A plane that followed Meshy's sunk feet took the
  tails down with them, and 27 of 60 clips then failed against y = 0, against 9 with the base alone.
- **The clip's own key times, from the file.** Godot re-optimises clips on import, so its tracks
  aren't the file's frames. The file's times are passed in and stepped to, and `write_keys`
  refuses a recording off them by more than 0.1 ms. The file's timeline is its **longest**
  LINEAR rotation input, because Meshy compresses a constant channel to 2 keys on a timeline of
  its own.
- **Mouse spring settings.** 0.35 / 0.35 / 3.0 were tuned by eye under the collider bug. With
  correct collisions, that floppy tail, which lies on the floor at rest, folded. The mice now
  use stiffness 4.0, drag 0.9 and gravity 0.5.
- The spring is configured only after the scene is live; set in `_initialize`, its bone names
  never resolve. The source BIN survives as an exact prefix, and a stamp prevents re-baking.

**Twist was checked and ruled out.** The one-frame flips looked like twist about the bone axis:
the fieldworker's idle turned 179.9° while the bone's direction changed 5°. Rebuilding each
rotation as a minimal-twist arc moved no joint (under 1e-12) and changed no step. The flips were
hairpin folds, where a rotation's axis is ill-conditioned, so that step was removed again.

## The checks, and what they judge

`ground_report` checks the result without Godot. It skins the tail's vertices itself on every
key, from:
- the node hierarchy;
- the channels (STEP holds, LINEAR blends, rotations take the short way);
- the inverse binds and weights.

It reports the lowest point the tail's surface reaches.

- **Ground.** Every bind pose stands exactly on y = 0, but **Meshy's clips sink the feet**: 1–10
  cm even at idle, and 34 cm in the squirrels' `pull_radish`. Kneeling clips also bury the tail's
  base. So `ground_verdict` asks the tail's lowest point to be no lower than the lowest of:
  - the ground;
  - the feet;
  - the base's floor.

  It allows 5 mm. A clip that sinks the feet or the base is flagged `clip_below_ground`: that is
  the clip's fault, and a clip fix, not a spring setting, will cure it.
- **Motion.** `max_step_deg` is the largest turn of any tail joint between consecutive frames,
  and `seam_deg` is the turn from the last frame to the first. A step over 90° is reported as
  `motion_ok: false`. Like the ground, it is reported rather than refused, so a defect is named
  in the manifest instead of blocking the other 59 clips; the run exits 1.

## Correction to decision 0191

Decision 0191's spring findings were all made under the scaled skeleton, so they describe the
collider bug as much as the spring:
- "gravity and radius are in world units";
- the per-creature settings;
- `viewer/capture_tail.gd` and `contact_sheets/tail_before_after.png`.

**The skeletal pool has the same bug.** A live spring on a `tailed/` file under the 0.01
armature collides wrongly, and it will meet the same root-motion teleport. The production rig
must have a unit-scale skeleton, or the runtime must unscale it the way this bake does. The
otter and squirrel settings also need tuning again by eye with correct collisions.

## Evidence

- **The library, 60 clips baked** (`baked.json`):
  - **Largest loop seam:** 14°.
  - **Largest one-frame step outside the four flagged clips:** 69°.
  - **53 of 60 clips sink the feet or bury the tail base themselves.**
  - **8 clips put the tail more than 5 mm below its floor.**
    - `mouse_fieldworker` `chair_sit_idle`: -1.1 cm
    - `mouse_keeper` `chair_sit_idle`: -7.3 cm
    - `mouse_keeper` `idle`: -1.4 cm
    - `mouse_keeper` `stand_and_drink`: -0.9 cm
    - `otter_boatwright` `chair_sit_idle`: -2.0 cm
    - `otter_boatwright` `collect_object`: -11.9 cm
    - `otter_fisher` `chair_sit_idle`: -1.5 cm
    - `squirrel_gatherer` `chair_sit_idle`: -1.2 cm

    Five are the sitting clip, where the tail rests on the floor and its fur dips 1–7 cm. The
    keeper's idle and drink dip 0.9–1.4 cm. The boatwright's kneel buries the base (flagged
    `clip_below_ground`).
  - **4 clips have a tail joint turning more than 90° in one frame.**
    - `mouse_fieldworker` `collect_object`: 94°
    - `mouse_keeper` `collect_object`: 112°
    - `otter_fisher` `collect_object`: 99°
    - `otter_fisher` `pull_radish`: 91°

    Each is the tail's buried base straightening as the creature rises from a kneel. It is a real
    flick about 2 frames long. Tuning did not remove it, and fixing the clip will.
  - The runs, which thrashed at 20–127° per frame before, now peak at 24–25°.

- `tools/test_bake_meshy_tail.py`: **46 checks, 0 failures**, run in CI's contracts job. The
  fixture is shaped like a Meshy clip: the first rotation channel is a 2-key constant, and the
  hips drop 0.6 m on key 2, so every ground and floor value is a literal.
- **22 mutants, all killed**, re-run with bytecode caching off (`python3 -B`, `__pycache__`
  cleared). A mutant that keeps the file's size can otherwise run stale bytecode. The mutants:
  - take the first timeline;
  - skip the short-way flip;
  - ignore STEP;
  - drop the time check;
  - drop the frame-count check;
  - drop the stamp check;
  - drop the tail-channel check;
  - normalise instead of refusing;
  - judge against the ground only;
  - judge against the feet only;
  - ignore the base in the verdict;
  - ignore the base in the clip flag;
  - ignore the weights;
  - ignore the animation;
  - measure the seam in radians;
  - write on the wrong sampler;
  - never sample the base;
  - ignore the base radius;
  - measure the step against the same frame;
  - ignore the base in the spring's floor;
  - don't cap that floor at 0;
  - ignore the base radius in that floor.
  The stamp mutant first **survived**, because a baked file's tail channels refuse it earlier;
  the test now also stamps a file with no tail channels.
- The Godot half checks itself at runtime: individual config, unit scale, and no joint moved by
  unscaling. It refuses with the individual-config line removed.
- **In Godot 4.7.2** (`viewer/capture_baked.gd`, played with no spring running):
  - all six creatures;
  - the otters' tails lie back along the ground;
  - the fisher's no longer flips;
  - the gatherer's run tail follows without thrashing;
  - the mouse keeper's dress is no longer dragged (decision 0191 addendum).

## Not done here

- **The clips.** Meshy's clips sink the feet in most clips and bury the tail base when kneeling.
  A foot-lock or root-height pass on the clips is separate work. So is a production rig with
  authored rather than retargeted clips. Re-bake after either.
- **The named defects in `baked.json`**; see Evidence.
- The skeletal pool's live spring: unit scale, root motion, and new settings (see the correction
  above).
