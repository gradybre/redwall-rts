# 1172 — Canonical short-step Room itineraries

Date: 2026-10-05 · Status: independently reviewed component; shared publication and playable qualification remain open

## Decision

Extend the existing stateless Room itinerary reader to the explicit protocol6
profile family in1168. Original26-profile queries retain their unchanged
profile1 automatic-ground and selected2–9 behavior. The new29-profile family
uses canonical-ground12 and exact-heading selected2–11, including the finite
232u forward/backward steps. The selected anchor supplies the body heading;
an all-yaw ground row is not itself an anchor. All WORK rows remain excluded.

The new family must not select legacy automatic-ground1: that row has no
canonical READY clock and cannot participate in1168's runtime handoff. The
parser is selected by the immutable profile layout, then each considered row
must satisfy the full protocol, policy, revision, actor digest and descriptor
checks. Source identity, species, stage, rig, posture, tools, cargo and quantity
range must match the selected anchor. A certificate bit, full live endpoint,
current physical source and current actual graph are still mandatory for every
leg. No coordinate proximity or completed Room provides route permission.

The complete short programme remains one separately certified terminal edge.
The itinerary reader only establishes static eligibility. It cannot enroll an
actor, change READY, turn the body, consume a fourth short-step tick, or carry
unused distance into another leg. Those remain the actual Routes/WorldRoutes
runtime operations and need their own integration evidence.

## Ownership, accounting and verification

Root owns the existing Itinerary source/test and this record. Geometry retains
Profiles, Routes, WorldRoutes, Driver and the1168 source programme. No new
actor column, path bank or retained query state is introduced. Count the added
source constants and complete helper closure in the existing joint cold
reservation; do not raise its limit. No executable source is committed until
its exact1168 dependency is accepted and integrated.

Retain the full legacy tests. Add actual29-profile paths containing canonical
ground and short steps in both directions; reject legacy-ground, different
headings, changed policies/source/payload, stale certificates and missing bits.
Refused queries leave caller output and paid state unchanged. Verify stable
choices and bounded work. Strict diagnostics/leaks, zero-warning analyzer,
source-derived memory and independent review remain required. Component tests
alone do not close the first playable Kitchen or whole-demo acceptance.

## Accepted component evidence

The final14-line production extension leaves the legacy26-profile branch intact.
The three affected suites pass45tests/498assertions/0failures (new8/94 plus
historical phase24/290 and itinerary13/114). All strict and raw diagnostics,
expected/tolerated notices and object/resource leaks are0. The analyzer reports
0warnings over the two changed production/new-test files and the separately
migrated historical fixture. Clean import and asset/project restoration are
recorded in `underground-short-step-itinerary-2026-10-05/` evidence.

The old paid `SourceFixture` is now explicitly pinned to its original v3 wire,
full reviewed digest and26/250/19224 layout. Its downstream profile24/content2
checks remain historical protocol5 regressions when the current catalog moves
to v4. Every selected historical row also checks the original source programme;
no synthetic certificate or edited wire is used. Current publication gates
remain separate and must cover actual v4 before it is mounted.

Independent review found two gaps in the first census guards: static retained
fields and an unreviewed large range. Both are rejected in candidate2. Eleven
negative/bound tests pass; the report additionally pins the exact reviewed
executable after counting the source graph, rather than claiming to be a
complete GDScript allocation analyzer. The original rejected producer/tests
and reviewer probes remain available. Counts are432/512bytes for Itinerary,
509/512 for the complete current Provider source path,344/576 for Contacts'
foreign leaf, and2094/4096 for WorldRoutes controls. These are logical payload
counts, not measured native memory or256-resident performance.
