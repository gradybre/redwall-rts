# 1159 — Publish current directed work-approach source geometry

Date: 2026-10-04 · Status: integration engineering plan; qualification pending

Decision 1156 adds source-driven forward and backward approach poses and the
canonical fixed-tick transition into productive work. The existing all-heading
WALK envelope cannot fit the already authored work station. The additional
envelopes must contain the complete actual animation, held tool, foot projection
and READY transitions; they cannot be narrowed to make a route pass.

Publish an additive `profile-publication-v3` only after independent review of
the complete source proof, native canonical-clock witness and current consumer
closure. Preserve the immutable v1/v2 artifacts and their evidence. The new wire
uses decoder version 2 and content revision 2, retaining row revision 1. It has
26 profiles and 250 boxes: the original STAND/WALK at 0/1; four exact-heading
forward approaches at 2–5; four corresponding backward approaches at 6–9; and
the original sixteen WORK geometries at 10–25. Backward travel keeps the body
heading and reverses the path heading. All original geometry remains byte exact.

The source-policy byte distinguishes legacy/all-heading rows, forward travel,
backward travel and canonical WORK. All nine actual cached consumers must be
pinned, including the new stateless source-program module. A matching actor
image, supplied checksum or true qualification flag alone is insufficient.
Historical source locators may reproduce the original mesh/rig proof; they
never exempt a current consumer from review or runtime source checking.

The native diagnostic wire is deliberately distinct from production acceptance.
Independent review caught that its first serializer accepted a self-labelled
report with a caller-recomputed checksum. The corrected serializer pins the
entire independently checked report, including its original source inputs,
producer identities, handoffs and work joins. The rejected serializer remains
in evidence. Both diagnostic wires are byte identical; neither grants World
support, a paid target, worker readiness or construction progress.

`MoleCatalog.pins_into` continues to describe every published row. Add an
explicit `driver_pins_into` for the existing 54-scalar driver packet: STAND/WALK
and the sixteen WORK rows. The driver observes approach rows through the actual
Routes state. Do not grow that packet or give presentation its own progress.
Expose the cardinal forward/backward row mapping explicitly; no nearest-heading
rounding or first-match contact selection is introduced.

Reconcile the source-only stair-motion catalog's profile binding with the new
complete profile image. If its immutable wire is republished, preserve every
motion column, support primitive, join, permission bit and timing value, changing
only the proved profile-source binding. This does not activate stair traversal
or change Brendan's approved timing. The old source image remains available.

The paired profile-bank increase is 4,704 bytes, to 19,224 bytes. Source-count
all helpers, loaded-script references and coexisting packets. Combine this with
the existing motion/level/session ownership and the separately approved 8,192
byte retirement slice inside the unchanged 262,144 byte profile envelope. Native
allocation and full-game performance remain separate measured gates.

The integration owner controls publication tooling, immutable generated files,
Catalog, related tests/export includes and shared ledgers. Decision 1156 retains
its leased runtime sources until reviewed handoff. A source publication is not a
playable room: actual movement, resource debit, excavation, room completion,
demo input, save/resume and 256-resident qualification remain required.
