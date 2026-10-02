# 1043 — The leat head's obstacle is (x, radius, z)

Date: 2026-10-02 · Status: Accepted

## Decision

`WeirGateView.land_obstacles()` (`godot/demo/water/weir_gate_view.gd`) returns
the leat head as `Vector3(HEAD_AT.x, HEAD_RADIUS, HEAD_AT.y)`. That is the
`(x, radius, z)` circle that every obstacle handed to the cast uses
(`demo_cast.gd`, `cast_space.gd setup`).

## Cause: Tegwin Slipstone stuck in the cabbage bed

The function returned `Vector3(HEAD_AT.x, HEAD_AT.y, HEAD_RADIUS)` and called it
"(x, z, radius)". It has done so since `3b0331ea` (the weir's sluice and garden
leat, decision 0441). The cast read that as a circle at (−7.45, 0.55) with a
radius of **7.3 m**. That disc covered most of the west of the village: the west
lane, the square's west spot and the cabbage bed's spot.

`crops_cabbage` stands at (−9.40, 6.90), behind `bed_cabbage_e`, and is clear of
the bed's circles by 0.52 m. Inside the phantom disc, though, its clearance was
−0.66 m. `room_for` then walked the slot "out" from the phantom's edge and
straight into the bed. For the otter's body that put it at (−10.38, 7.72),
0.44 m inside a bed circle.

The cast places each resident at its POI slot as it is built (`_place`), so
Tegwin Slipstone, actor 4, started inside the bed. In a 3000-frame probe at 4x
he did not move for 2700 frames. Once the badger registered, the slot itself
moved further, to (−11.57, 7.38), but he was already standing where it had been.

With the fix, the cabbage spot is clear. Tegwin starts at (−9.40, 6.90) and
walks off to his routines within the first game minutes. The same probe also
showed the keeper, Wenna Tallowby, no longer sitting in ROUTE at the well. The
phantom disc reached that far.

## Why the tests missed it

`test_weir_sluice.gd` pinned the wrong order: it read `(obstacle.x, obstacle.y)`
as the head's position.

`test_demo_cast.gd`'s `_real_village_space()` is meant to be "the village as
demo_village.gd lays it for the cast", but it left out the weir's circles. The
cast suite's checks on every slot's clearance and reachability never saw the
disc. The world-only check, the one that requires every radius to be under
3 m, never saw it either.

Now:
- the fixture includes `WeirViewScript.land_obstacles()`;
- `test_every_circle_the_village_gives_the_cast_is_a_circle` checks every
  radius on the full list and pins the head's circle;
- `test_the_cabbage_bed_slot_stands_outside_the_bed` checks the spot directly;
- the weir test reads `(x, z)` for the position and `y` for the radius.

With the old order restored, five tests fail: the two new ones, the existing
slot-clearance and shared-slot reachability tests, and the weir test.

## Not changed

- The forestry circles are still not in `_real_village_space()`. They need a
  built world with its trees.
- A resident placed at build keeps the slot position worked out before a wider
  body re-placed the slots (`add_resident` → `_place_slots`). With true
  obstacles, that earlier spot is clear for that resident's own body, so it is
  harmless. It is noted here and not changed.
- The ferry acceptance harness's workaround that moved Tegwin to (−6.0, 6.0) is
  not in the repository. It lives only in an untracked scratch harness
  (`zz_ferry_accept.gd` in the ferry review's scratch worktree), so there is
  nothing in the tree to remove. That harness no longer needs the move.
