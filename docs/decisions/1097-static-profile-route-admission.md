# 1097 — Static profile eligibility for existing routes

Date: 2026-10-03

Status: implemented, focused verification and independent review complete; playable admission remains open

## Decision

Room entrance planning needs to distinguish a connected graph from a route
that fits the intended travel profile before a construction Job exists.
WorldRoutes now exposes a read-only static profile/edge predicate over its
actual committed certificates. It takes the full local edge generation and
exact profile/content revisions, then reads the immutable loaded descriptor.
It creates no Selection, resident, Job, route, pace or movement permission.

The complete source/continuous/numerical/presentation flags, profile-specific
eligibility bit, geometry revision, connector catalog revision and actual
committed edge mode/posture must all agree. A private or aborted certificate
cannot qualify. Geometry preparation and active certificate compilation refuse
this read. The query holds the original graph, geometry, source and endpoint
owners strongly for its entire callback lifetime, and uses the existing
exclusive fixed query scratch. It adds no retained field, bank or save column.
After every callback, a final callback-free check repeats the actual current
profile/catalog content, geometry revision, full live graph edge and World
identity. Existing live worker travel uses the same committed certificate checks and
continues to require its independent actual Selection/Job/equipment proof.

## Limits and next composition

This predicate reports the existing static clearance proof. Dynamic residents,
new local resources or construction obstacles still need the current terrain
and occupancy checks at admission and actual movement. It is not a complete
path finder, prospective work-face proof or surface entrance. A later profile-
filtered Routes search must use this predicate on every traversed edge;
existing topology-only candidate_path_into cannot substitute. The WORK stance,
approach, stroke and exact paid face remain independently qualified, using the
actual authored work profile. No production profile or free passage is added.

The implementation belongs to root's WorldRoutes/test lease in its own
codex/underground-static-route-admission worktree branch, based on freshly
fetched origin/master and our frozen8334ce3a integration. Decision1096 and the
Locations/Routes room companions remain geometry-owned.

## Verification

Focused strict route/actor regression, source hashes, analyzer and independent
review are recorded in the accompanying evidence before commit. Synthetic
profile extents in the existing test fixture remain explicitly test-only.
The complete playable D20 workflow and256-resident qualification remain open.

## Verification

Independent geometry review found that the final Terrain binding callback could
replace actual content or geometry after the old certificate check. The corrected
query repeats pure current-owner checks after both metadata and final binding
callbacks. Countdown regressions replace the actual Catalog, Profiles and Space
after that last normal binding check and require stale-certificate refusal.
The reviewer accepted both exact iteration2 source pins; no remaining high/medium
finding was reported.

Focused clean-import strict tests:66 tests /10,886 assertions /0 failures.
Both suite and raw-log diagnostics report zero unexpected errors/warnings and
zero leaked objects/resources; expected/tolerated are also zero. The changed-file
analyzer reports0 warnings in2 files. Evidence:
`docs/validation/evidence/underground-static-routes-2026-10-03/`.
