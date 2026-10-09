# Four-phase haul source checkpoint

This is source geometry only. It does not publish a profile, adopt a HAUL rate,
grant delivery permission, or qualify native animation or the playable entrance.
The prior nine static source files remain byte-identical.

`invocation.json` records the complete nine-command reproduction, source and
output hashes, logs and unchanged-input check. Run `reproduce_program.py` with
the two pinned palette paths and a new output directory. `source/` retains the
exact new producer/prover/test/runner, alongside their static dependencies.

The four clips each have 61 source keys and 60 adjacent affine interpolation
intervals. The sample count describes the source image; it is not gameplay
timing. Source-local root and yaw stay fixed. Approach/recovery display the stock
at its actual floor target for proof; that stock is world geometry, not attached
cargo. Lift/place move the actual complete stock while retaining both hand
grips. The world-to-cargo switch would require the actual successful Inventory
transfer at the exact shared contact key; this packet adds no runtime switch.

All 240 intervals complete with zero unresolved non-grip intersections or floor
penetrations. Every interval has an actual anatomical foot vertex in the closed
one-unit floor contact cell at both ends; affine interpolation keeps that vertex
inside the same cell throughout. All foot triangles remain part of the support
projection and world occupancy. The same 10,209 body/clothing triangles and 768
stock triangles are retained. Only 478 left and 448 right complete distal-palm
triangles may intentionally meet their own stock; the other 9,283 remain solids.
The mixed boundary triangles are unchanged.

Both grips are proved through every lift and place interval. A fixed actual hand
edge intersects a fixed actual stock triangle at every common source time. The
stock translates without rotating; its exact plane distances are linear and the
three intersection half-plane numerators are quadratic. Their exact rational
closed-interval minima establish contact. Endpoint overlap or a copied flag is
not a certificate. A dedicated counterexample has valid endpoint contacts but
leaves the triangle between them and correctly refuses.

Complete body union is `[-430,0,-589 ..432,849,233]u`. The moving stock union is
`[-412,0,-627 ..412,550,-333]u`; the floor stock is
`[-412,0,-627 ..412,102,-525]u`. Full left/right foot projections are
`[-274,-169 ..-79,95]` and `[70,-64 ..298,174]` in X/Z. These are measured source
bounds, not clearance or support granted by a game owner.

The pickup/set-down pose equals the reviewed static source byte for byte. The
lift/place hub is identical, and the empty approach/recovery body joins it
exactly. Place is the exact reverse of lift; recovery reverses approach.
Reversal therefore traverses the same proved source segments. Each authored
joint key retains the actual original rig link lengths. The proof follows the
rendered matrix interpolation between keys; it does not claim interpolated
matrices are exact rigid joint rotations.

All 13 tests pass, including an actual stock crossing through the body between
clear endpoints, a late hand departure, lowered mid-key floor penetration,
changed stock rotation, exact joins, unchanged static files and the rational
interior-contact counterexample. The original adapter bring-up failure is
retained in `../handling-program-v1/proof-bringup-rejected-1/`: it misread a
per-surface helper as per-frame output and emitted no acceptance report.

Still open: native arithmetic/residual proof; a no-tool empty-world entry;
loaded gait/turn and their transitions; quantity-to-geometry admission and
partial-unload remainder; separate BUILD workpiece set-down; runtime station /
curved-grip source contract; joint source-image and memory admission. The loaded
body hub alone is not a qualified ground-walk or turn state. No arbitrary
partial quantity is hidden or declared delivered by these clips.
