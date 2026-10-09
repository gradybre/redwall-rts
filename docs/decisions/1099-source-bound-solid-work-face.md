# 1099 — Source-bound solid work-face observation

Date:2026-10-03

Status: independently reviewed component; no productive permission or playable acceptance.

## Decision

A connected route and a completed endpoint do not prove that a worker can stand,
strike a particular solid face and recover safely. Add a cold read-only geometry
query using actual Locations, SpaceOwner, Terrain and immutable Profiles from
the same actual Routes composition. No fabricated Selection, resident or Job is
created. The query accepts an exact full endpoint reference and profile/content
revisions, one datum-aligned physical cube and an explicit face. It reads every
geometry role from the loaded descriptor and translates already oriented bounds;
it never rotates the bounds a second time.

The observed profile must be a complete CERT_REQUIRED exact-yaw BUILD work
profile with CONTACT_ANCHOR_AND_PATCH. BODY_HELD_LOAD, WORK_APPROACH and TURN_RECOVERY require completed void
with only the actual SUPPORT intersection of the authored stance excusing any
negative body residual. The full stance independently needs real support. The
authored CONTACT_POINT must be on the selected face, including an exact max-face
plane, and its full positive-area CONTACT_PATCH must lie on that same plane
and inside the target face. A focus point cannot excuse a patch crossing a
corner. Legacy point-only descriptors do not qualify. The complete WORK_STROKE must be covered by completed void or the exact
solid target; a second solid cube, floor or wall is not excused. Actual terrain
dryness and live exclusions remain mandatory. Current retained void/support/
blockers cannot be called virgin solid just because the original terrain was dirt.

The query is a profile/geometry observation, not ownership of a physical cube,
a path proof, an excavation recipe or a claim. Actual Room/Sites preflight and
phase state still decide whether a project may own or operate on that cube.
It does not grant through travel in an unfinished connector, infer a surface
entrance, waive target obstructions or stand on an unfinished future floor.
Productive START/WORK will additionally requery the actual assigned worker,
tool, load, Job and dynamic occupancy through their owners.

## Lifetime and finite allocation

Hold the exact actual owner objects for the synchronous read and copy request
scalars before callbacks. Require the actual shared cold lease before a Domain,
Descriptor, endpoint, snapshot or fragment packet is created. Use one current
traversal snapshot and the already tested flat exact-union subtraction logic.
The observation is sequential after prior Room admission surveys have dropped.
At full R6144/O2048 the snapshot327680B plus two fragment banks49152B and
2048 logical numeric controls total378880B. With existing three Room cell images
24N atN16384 the peak is772096B, below the unchanged1048960B cold allowance.
The packet owns no persistent columns, saved state or per-resident object.
The source-counted packet and caller Request contain1051 logical numeric bytes
(after adding the patch flag), leaving997 within the2048 control reservation.
The1100 final source reader borrows existing source scratch and reserves its
bounded temporary controls within that remainder. The leased SpaceOwner snapshot
entry point separately admits its full capacity image and 256 logical copy
controls before source observations, then rechecks the original token immediately
before allocating. Its copy controls fit within the existing 2048 control reserve;
no second snapshot or additional persistent bank is introduced. Native overhead remains a
separate joint-accounting obligation; this is not a measured allocation claim.

Before the first endpoint/terrain observation, charge two complete local passes
of at most13 queries each at1025 bounded tile/leaf checks plus three6144+2048
source/claim scans. Exact fragment/profile scans use the remaining finite
Domain work budget. The final1100 reader precharges its own actual-source census
and leaf costs from the still-remaining budget. Insufficient work budget refuses
before the corresponding scan; an exit code or elapsed time is not this proof.

After source callbacks, recheck actual geometry, full endpoint/payload/section/
World identities, immutable content revisions and the exact original Budget
token. After the last ordinary endpoint read, a fresh Terrain leaf query checks the
actual target and every physical box; decision1100 rechecks retained actual
source/claim facts and the complete endpoint record without observation hooks.
This catches Building fact changes and newly placed unregistered obstructions
that do not change the sparse revision. A replaced equal-size token, stale
profile, retired endpoint or changed caller request cannot publish success.

## Verification obligation

Use real source owners and clearly labelled synthetic profile/geometry fixtures
for algorithm cases. Cover exact positive and max faces, a central clearance
hole, partial support, a second solid cube, below-floor body/tool residuals,
wrong yaw/content/generations, finite exhaustion, foreign/replaced leases and
late actual source mutation. Retain the strict runner and zero-warning analyzer,
then require independent review before committing source. Native source/profile
qualification remains a separate complementary lane, not supplied by tests.


## Verified component evidence

Iteration9 at the reviewed source pins ran 58 tests / 2124 assertions / 0 failures
across WorkFace, Terrain and FinalFacts after a clean own-checkout import. Strict
and raw logs each report zero unexpected errors/warnings and zero object/resource
leaks; the analyzer reports zero warnings in seven files. Geometry independently
reviewed the corrections, including the final leased-copy call and real source
callback regression. All source pins stayed unchanged and assets were restored.
See `docs/validation/evidence/underground-work-face-2026-10-03/README.md` for
reproduction, earlier rejected iterations and the exact acceptance scope.
