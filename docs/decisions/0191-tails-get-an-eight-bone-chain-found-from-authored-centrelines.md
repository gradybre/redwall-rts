# 0191 — Tails get an eight-bone chain, found from authored centrelines
Date: 2026-09-26 · Status: Accepted

## Decision

`tools/rig_meshy_tail.py` adds a tail chain, `tail_00` to `tail_07` parented to `Hips`, to six
creatures, and re-weights their tail vertices onto it:

- both mice;
- both squirrels;
- both otters.

It works on the **repaired** files ([decision 0190](0190-repair-meshy-rigs-by-editing-the-gltf-not-by-re-exporting.md)),
applies to every clip as well as the rigged file, and writes to `assets/library/creature/<key>/tailed/`.
[`tailed.json`](../art-reference/asset_library/tailed.json) records all 66 files.

The four other rigged creatures get **no chain, by design, with a reason recorded**:
both moles and both badgers show no tail separable from the body in the bind-pose plots. The
robed badger steward isn't rigged at all.

## Why a chain was needed, not just nicer weights

Meshy's 24-joint rig has no tail. It bound each tail to whichever bone was nearest:

- the hips, for most;
- the **left thigh**, for all 6,926 of the squirrel gatherer's tail vertices;
- the **right thigh**, for the otter boatwright's;
- **both legs**, for the otter fisher's.

Those tails swung with one leg as the creature walked, and on bending clips they stood out
like a stick. A tail needs bones of its own.

## How the tail is found, and why it is authored

No single automatic rule separates a bushy squirrel tail curling above the head, a thin mouse
tail passing through a dress, and a thick otter tail hanging between the legs. So each chained
creature has an **authored rough centreline and capsule radius** in
[`tail_centrelines.json`](../art-reference/asset_library/tail_centrelines.json). Everything after
that is computed:

1. **Weld** vertices by position. glTF splits them at UV seams, and without welding the surface walk
   stopped after 3–21 vertices.
2. Walk the surface from the tail **tip**, inside the capsule and never back across the **root
   plane**.
3. **Refit** the centreline to the selection's own centroids, and segment again against it. The
   authored lines sat off-centre, which clipped the far side of thick tails.
4. **Grow** up to three rings of neighbours, capped at 1.35× the radius. A capsule sized to the
   axis cuts through a bushy tail's outer fur. Those clipped vertices kept their thigh binding,
   and once the tail moved, the triangles between them and the chain stretched into spikes.
5. Place 8 joints at equal arc length. Weight each tail vertex to its two neighbouring joints,
   and blend the first segment into the hips; a tail's base is its stiffest part.

Each step was checked against rendered back and side views. The back view is the one that shows
whether a leg has been swallowed. The final selection, in red, is in
`contact_sheets/tail_segmentation.png`.

## Eight bones

24 Meshy joints + 8 + the 3 sockets (`socket_main`, `socket_off`, `socket_head`) = **35**,
inside crowd §9.1's 64-bone budget. The tool refuses any chain that would leave no room for
the sockets.

## Verification that cannot agree with itself

The chain's node offsets and its inverse bind matrices are written by different arithmetic.
`verify_bind` rebuilds every joint's world matrix **from the node hierarchy** and requires
`world × inverse_bind` to be the same uniform scale for every joint: 1.0, or the repair's height
factor on a rescaled rig. It passed for all 66 files.

A first test fixture had its tail at exactly x = 0 and its hips unrotated. A mutant flipping the
sign of the inverse bind's x translation survived that fixture. The fixture was changed to an
off-centre tail on hips yawed 30°. That mutant and two further basis-handling mutants are now
killed.

## Driving the chain

The chain makes the tail bendable. It still has to be moved:

- **The skeletal pool (≤ 24 actors):** Godot 4.7's `SpringBoneSimulator3D`, a spring from
  `tail_00` to `tail_07` with a ground `SpringBoneCollisionPlane3D`. Per-creature starting values
  are in `tail_centrelines.json`. **Gravity and radius are in world units**, even though the
  skeleton sits under the glTF's 0.01-scale armature. Scaling both by 100 collapsed the squirrel
  forester's S-curve into a ball and lifted the otter's tail.
- **The crowd tier** plays baked clips (crowd §9), so it needs the tail motion **baked into the
  clips**. That is not done here.

## Evidence

- `tools/test_rig_meshy_tail.py`: **28 checks, 0 failures**, run in CI's contracts job. The fixture
  reproduces every real defect: a thigh-bound tail, a UV seam, fringe vertices at 1.2× and 1.6×
  the radius, a vertex just before the root plane, and rotated hips.
- **Eleven mutants, all killed:**
  - no welding;
  - no growth;
  - no root plane;
  - keep the thigh weights;
  - flip an inverse-bind sign;
  - transpose the hips basis;
  - drop the basis from a chain offset;
  - allow re-chaining;
  - drop the socket reserve;
  - skip the same-mesh proof;
  - make `verify_bind` always pass.

  Each file was restored byte-identical.
- **The real library:** 66 of 66 files chained, and every file passes `verify_bind`.
- **Godot 4.7.2:** each file imports with 32 bones. Before and after with the spring, in
  `contact_sheets/tail_before_after.png`:
  - the mouse's tail no longer stands up when she crouches;
  - the squirrel gatherer's tail follows its body, not its left thigh;
  - the squirrel forester's S-curl holds;
  - the otter's tail extends behind the leaning body.

## Not done here

- Tail motion baked into the clips for the crowd tier.
- The two spring settings copied rather than tested: `mouse_fieldworker` and `otter_fisher`.
- Tail chains for the moles and badgers, if a later model gives them a separable tail.
- The production rig: sockets, a fixed rig manifest, and the crowd bake.
