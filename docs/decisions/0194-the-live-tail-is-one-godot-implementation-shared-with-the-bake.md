# 0194 — The live tail is one Godot implementation, shared with the bake
Date: 2026-09-27 · Status: Accepted

## Decision

The skeletal pool (≤ 24 close-up actors, ARCH-GODOT-001) gets the same exact ground constraint the
crowd bake got in [decision 0193](0193-meshy-clips-are-lifted-so-the-support-never-goes-below-the-ground.md).
There is now **one** implementation, in the game, and the crowd bake runs it:

- **`godot/scripts/presentation/tail_ground_constraint.gd`** is a `SkeletonModifier3D` that runs
  after the spring every frame. Walking down the chain, any joint (or the tip the spring extends
  past `tail_07`) closer to `floor_height` than its segment's clearance is lifted by swinging the
  segment above it up. It keeps that segment's length, the base, and the other segments' world
  directions. A clear frame is left exactly as the spring made it. This replaces the Python
  `lift_tail` of 0193.
- **`godot/scripts/presentation/tail_rig.gd`** builds a creature's live tail: Godot's
  `SpringBoneSimulator3D` with per-joint individual config (read back, decision 0192), its ground
  plane, and the constraint after it. `set_floor(y)` moves both. It refuses:
  - a skeleton outside the tree;
  - a scaled skeleton;
  - a skeleton without a chain;
  - a skeleton without the metadata below.
- **`tools/godot/bake_tail_spring.gd`** builds each clip's tail with `TailRig`. The bake copies both
  scripts into its throwaway project at the same `res://` paths.

The pool itself (`skeletal_pool.gd`, crowd architecture EX-008) is not built yet. When it is, a
tailed actor needs one `TailRig.new().attach(skeleton)` and a `set_floor()` each frame.

## Everything comes from the asset

Godot imports glTF node extras as bone metadata named `extras` (checked on 4.7.2). So
`tools/rig_meshy_tail.py` now writes, onto every tail bone:
- `spring_radius_m` (the spring's collision radius, 95th percentile, as before);
- `ground_clearance_m` (the constraint's clearance: the 99th-percentile distance of the segment's
  vertices from its axis, measured on the chained mesh).

On `tail_00` it also writes the creature's `spring` settings (stiffness, drag, gravity) from
`tail_centrelines.json`. The live tail and the bake read them from the file being animated, so no
table in code can disagree with the asset.

## Fold Meshy's armature scale into the file, instead of working around it at runtime

Godot 4.7.2's `SpringBoneCollisionPlane3D` collides wrongly under a scaled skeleton (decision
0192). Meshy's skeleton sits under an Armature scaled 0.01, and the bake worked around that by
rescaling the skeleton and its tracks in memory. At runtime that would also mean rescaling the
shared skin bind poses and animation resources for every species, carefully, once.

So **`tools/repair_meshy_rig.py` now folds the root scale into the hierarchy** (`fold_root_scale`,
stamp version 2). With S = scale(s):
- every descendant's translation, and every translation key on one, is multiplied by s;
- every inverse bind becomes S × IBM;
- the root goes to scale 1.

Each joint's world becomes old_world × S⁻¹, so `joint_world × IBM × v` is unchanged: every vertex
is drawn exactly where it was, in every pose.

Checked in Godot 4.7.2: the mouse keeper and otter boatwright render **pixel-identical** (0 of
22,466 and 50,606 creature pixels differ) at the same frame, and the skeleton's scale goes from
0.0100 to 1.0000. The repair's height check now measures the drawn height from the joint and
inverse bind, not from the root scale, which no longer carries it.

## The bake poses the body from the file, not through Godot's animation import

Moving the constraint into Godot exposed a second import problem. The new read-back check
(`clearance_deficit_m`: how far any joint of the **written** clip falls short of its clearance)
found 7 clips 1.1–2.4 mm short and the otter boatwright's walk 9.9 mm short.

The cause is that **Godot's glTF import drops keys that lie near the line through their
neighbours.** The boatwright's walk lost a hips key 9.86 mm off that line. So Godot's pose, which
the constraint lifted against, and the file's pose, which ships, differed. None of these changed
it:
- import at 30 fps or 60 fps;
- the animation optimizer on, off, or at a 1e-5 tolerance;
- `remove_immutable_tracks` on or off.

So the bake no longer plays the clip. For every file key, Python samples every non-tail bone's
exact local transform (`clip_poses`). The bake sets those poses directly, with the
`AnimationPlayer` switched off, before advancing the skeleton. The worst shortfall then fell from
9.86 mm to 0.06 mm.

**For the live game, this is an open finding:** Godot plays these clips up to about 1 cm off the
file on such keys. The live constraint is exact against what Godot draws, but the feet may be
that far off the ground on those keys.

## Evidence

- **Library regenerated** from the raw Meshy files (repair → tail → ground → bake):
  - 110 files repaired, now at unit scale;
  - 66 chained, with the same segmentation and radii as before;
  - 100 grounded, with the same lifts as before;
  - 60 baked with the Godot constraint.

  The bake's verdicts are **identical to 0193's Python-constraint bake**:
  - 1 tail more than 5 mm under (squirrel gatherer idle, 5.4 mm);
  - 1 one-frame flick (otter fisher collect_object);
  - 2 clips whose own tail base is buried.

  **Worst clearance shortfall read back from the written files: 0.06 mm.**
- **Live, the skeletal-pool path.** Godot plays each grounded clip through its `AnimationPlayer`
  at 60 Hz with `TailRig` attached, and after every frame's modifiers the worst margin of any tail
  point above floor + clearance is measured. **59 of 60 clips never go below −0.07 mm**, which is
  float noise. The 60th is the mouse keeper's `chair_sit_idle`, 5.2 cm short: the clip seats her
  tail base below that floor, as the bake flags, and no swing of the segments above it can reach.
- **`godot/test/test_tail_rig.gd`: 57 assertions.** It covers:
  - the refusals;
  - the metadata read;
  - clearance per point;
  - `is_clear`;
  - `lift_segment`, including the heading fade;
  - the constraint on a procedural chain: it clears, the lift is **minimal**, a raised floor
    raises it, the base and lengths are kept, and a clear chain is left exactly as it was.

  The runner executes suites before the scene tree is live, so the constraint is exercised
  through its public `apply()`, which is exactly what the modifier runs. The spring itself running
  in a tree is exercised end to end by the bake.
- **GDScript mutants, 8 of 8 killed:**
  - never lift;
  - ignore the clearance;
  - ignore the floor;
  - don't re-parent;
  - lose length;
  - no heading fade;
  - judge the base;
  - take the clearance from one side.

  "Don't re-parent" first **survived**, because the tests checked only "at or above" and a chain
  lifted too far passes that. The minimal-lift test was added and kills it.
- **Python:**
  - `test_repair_meshy_rig.py` 37 checks; its 7 fold mutants are all killed, including "scale the
    inverse binds by columns".
  - `test_rig_meshy_tail.py` 46 checks, including the new extras and clearances.
  - `test_bake_meshy_tail.py` 49 checks; the 4 clearance-deficit mutants are all killed.
- Refactor: `read_accessor`, `append_accessor`, `COMPONENTS` and `WIDTHS` moved down into
  `repair_meshy_rig.py` (the base module), which the repair's fold needed; `rig_meshy_tail.py`
  re-exports them.

## Not done here

- **The skeletal pool itself** (`skeletal_pool.gd`): admission, LOD hysteresis and the per-frame
  `set_floor` from terrain height.
- **Godot's import drift** of up to about 1 cm on near-collinear keys, for live playback. Options:
  an import script that restores the file's keys, or authored clips without such keys.
- **Root motion in live playback.** The carry walks carry it; the bake carries it across the loop
  (0192), but the pool must extract it, per crowd §9.1's in-place root convention. Otherwise the
  spring sees the loop's snap back.
