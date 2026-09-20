# Source geometry finding while architecture review runs

The prior X-shift example contains only the imported mesh's original static pose. `mouse-rigid-yaw-diagnostic.json` now computes a conservative bound for its full continuous rigid root yaw using exact rational squared radii of all 11,103 float32 vertices. The outward radius is 439 simulation units. Thus +768/+256 placement still fails the Z minimum during a turn; +768/+768 contains this rigid diagnostic within a three-cell square.

This supplies a concrete counterexample to treating one static facing as a turning envelope. It grants no movement profile, margin, animated-pose coverage, gear/cargo shape, support, door fit or placement policy. The mesh is unskinned and has no animations. Profile placement selection must follow the actual complete source sweep, including all supported variants, rather than adopt either diagnostic offset as a species constant.

The script is retained next to the result for reproduction. It computes a sufficient conservative circle for rigid yaw only; it does not measure joint deformation or interpolate missing clips. This finding does not alter the in-flight review's frozen inputs or claim that the reviewer saw this later artifact.
