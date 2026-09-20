# Ground placement follow-up — review proposal, not adopted runtime policy

The static mouse vertex diagnostic supplies a real source case for the existing G02 placement gap: X lower bound -438u plus baseline root offset256u is negative. It is not a continuous envelope or an approved profile, and it must not be used to publish a production clearance.

One candidate worth reviewing is a profile-specific anchor offset that preserves the existing root-centre lattice. Restrict offsets to `o = 256 + 512*q` on each horizontal axis, with an authored nonnegative integer q. If a current root coordinate is `512*r + 256`, choosing route anchor `r-q` preserves that exact root coordinate: `512*(r-q) + (256+512*q) = 512*r+256`. This avoids assuming that a larger clearance class recentres a footprint, and demonstrates that a reviewed anchor change need not itself teleport a resident.

For the static diagnostic alone, qx=1/qz=0 would give offsets768/256 and translated bounds X330..1206, Z46..466, whose upper bounds fit a class3 square. This is a worked alternative-placement arithmetic example only. It supplies no margin, interpolation/turn sweep, gear/load/profile admission, map/support validity or physical doorway proof. It is not an instruction to change the live offsets.

Before adoption, a single G02 contract must separate the route footprint anchor from the cell containing the root, define start/goal/contact lookup in both spaces, preserve interpolation and picking, reject out-of-map anchors without clamping, and version the route/save/profile meaning. Existing saved paths cannot be silently reinterpreted by subtracting an offset. Changing a body's committed load/profile must also revalidate future entries while preserving occupied traversal and valid recovery.

The conservative grid square and a real doorway aperture are different geometric constraints. A doorway whose edges do not align to the512u grid can lose usable width under conservative cell blocking even when the body physically fits. Review explicit contact/connection aperture semantics and wall rasterization together; moving the anchor alone does not close the hall exit/partition or contact contract. Keep the already-authored1536u doorway width and3072u clear height as model-brief inputs, without claiming measured passage.

This proposal is independent of INIT-C-PREP and changes none of its inputs or acceptance. It is recorded for architectural review after the starter plan's current verification work; no schema, capacity, saved field, runtime position or movement gate is changed here.

A source-impact check is recorded in `placement-source-impact.json`. Navigation already uses “anchor” for its PATH-R02 exact-start/cache compatibility fields. Those fields cannot be silently repurposed as a body-footprint anchor: the future contract must distinguish the physical footprint anchor, root-containing cell, exact route start and macro/cache anchor, and preserve the accepted exact-start path behavior.
