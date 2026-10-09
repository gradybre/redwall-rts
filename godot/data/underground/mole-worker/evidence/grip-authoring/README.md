# Mole pick contact correction

The accepted original matrix/source proof remains unchanged. Its native close
views fail the intended handling quality: the shaft is anchored at the wrist
behind the paw. The current rig has one rigid hand bone per paw, without finger
bones. A translated socket must never be presented as a clenched-hand pose.

This engineering authoring pass uses the actual staged mole body, skin bind
poses, hand-local vertices, original pick and existing material resources.
`grip-probe-v1` contains a rejected preload attempt: Godot reported a dependency
compile error despite returning exit 0 and a measurement. A corrected deferred
dependency load is required before that output counts as clean evidence.

The inherited art reference is DEC-038's opened grounded expressive example:
broad mole paws, readable claws, work clothing and convincing timber/iron
contact. The original body, scale, silhouette, palette, tool and costume remain
the source. Newly authored palm/socket or hand-pose changes are explicitly
derivative content, not a supplied reference fact or new gameplay permission.
They must read at a close view and at RTS size through idle, walk and the whole
strike/recovery sequence. No paid generation is used.

First compare the unmodified fit with hand-local candidate placements derived
from the actual palm geometry. If repositioning still leaves implausible open
claws, create and document an explicit closed-grip mesh variant, preserving
original skin, UV/material provenance and wrist continuity. Only accepted
derivative content may replace the source in a new bake. Every changed palette,
continuous envelope, state union and downstream source pin must be regenerated;
none of the old bounds grants permission to the modified representation.

## Selected engineering candidate

The independently inspected front images provisionally select the firmer
candidate. Its hand-local socket translation is `(-40, 80, 5) / 1024` metres,
applied before the unchanged source `pick_fit`. This is a measured-source
authoring choice, not a gameplay reach, clearance, speed or capability value.

The actual hand skin bind is 19, named `RightHand`, on the original 24-bind
mole body. The source has no finger bones. An explicit fixed hand mesh variant
contracts only vertices with positive influence from that hand and hand-local
Y greater than 0.025 m. The smoothstep interval ends at 0.130 m, transverse
contraction reaches 70% at full hand influence, and distal length contraction
reaches 15%. The wrist and every unaffected vertex remain unchanged. Normals
use the inverse transpose of the analytic local derivative; tangents follow
that derivative and are orthogonalized to the new normal. Original skin
weights, triangle indices, UVs and materials are retained. These numbers author
the mesh itself; they grant no new physical permission.

The candidate changes 845 of 17,172 vertices. The original geometric fingerprint
is `a938d479014ebd3a431a118a7b1c9f7aa0b522d0a33a5c5d281e58e1e2f497c1`;
the firm candidate is
`29f8d3218fddfaa6f2369c1c1c7dfd9b0a429b3df5cbefa38c6bf6ab9364fe14`.
The original remained unchanged in three actual source checks. `grip-closed-v4`
records 642 native poses and the selected front comparison. `grip-angles-v1`
records another 1,926 native poses across both sides and the rear. Those runs
have no unexpected diagnostics or leaks. This is animated visual evidence,
not first-playable, HUD, exact collision, physical contact or clearance proof.

`grip-preview-v1` and `grip-closed-v1` retain the rejected reversed comparison
captions and original source snapshots. `grip-closed-v2` retains a rejected
GDScript indentation error, and `grip-closed-v3` a runner path error before
engine launch. The corrected v4 and angle bundles do not overwrite them.

The reusable source derivative must refuse any different original geometric
fingerprint, right-hand bind pose or source pick fit. Its output is built once
per shared presentation archetype and remains immutable while borrowed by
actors. A new finite bake and compact content image must include this exact
module and both source and derivative hashes before downstream use. New
buffers and borrowed mesh resources belong to the presentation memory ledger;
the simulation budget is not evidence for that loading peak.
