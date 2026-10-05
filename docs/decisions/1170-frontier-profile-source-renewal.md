# 1170 — Renew unchanged worker geometry for frontier consumers

Date: 2026-10-05 · Status: source renewal; full Room qualification remains open

## Trigger and decision

The actual Room Session correctly refused to mount after 1161 extended
WorkFace, Routes and WorldRoutes: the immutable v3 catalog still identified
their earlier source. Preserve that strict check. Create an additive
`profile-publication-v3-frontier` publication only after independent review of
those three changes and a fresh native replay using the current consumers.

The worker wire remains byte-for-byte v3: 26 profiles, 250 boxes, content
revision 2, per-profile revision 1 and source program 5. Actor data, geometry,
role mapping, bounds, timing, certificate flags and bank sizes are unchanged.
Only the exact consumer source identities, reviewed consumer commit and
publication provenance change. Keep the earlier publications immutable.

`renew_work_approach_profiles.py` verifies all 509 original prerequisite
identities. For exactly the three reviewed changed source files, it checks
the immutable historical snapshots that established the old proof. Separately
it requires all nine current consumers to match reviewed commit 8003bfe1 and
current files. The native run must match the five executed canonical movement
consumers, its before/after source maps, successful diagnostic-free commands
and the exact independent matrix oracle. Historical source never runs in
place of a current consumer, and unknown source changes still refuse.

The successor is create-only with a final prerequisite check before writing.
The live Catalog and export preset select the new publication; the cached
source validation and its refusal tests remain unchanged.

## Evidence and limitations

Independent compatibility review found no geometry or clock equation change:
WorkFace retains the same physical checks, Routes refuses during frontier
publication without changing its clock, and WorldRoutes validates existing
certificates before the same bank swap. The other six consumers are identical.

The unchanged canonical native harness passed 9,336 assertions over 1,504
poses, with 469,248 exact native scalar comparisons, four headings, two views
and 64 captures at 1280×720. Both import and native commands exited zero with
no raw diagnostic; source and override restoration were verified. A separate
read-only oracle replay reproduced the same result. WorkFace was reviewed
statically and exercised by the strict frontier component tests; this native
scene does not exercise a real WorkFace target.

The outer asset staging wrapper originally refused to remove directories
containing 15 engine-extracted texture files. The successful native result
and that cleanup error are retained separately. Known generated textures were
removed with recorded hashes and borrowed source files remained unchanged.
The corrected cleanup helper has isolated removal/refusal checks; the original
wrapper is not represented as a successful run.

Evidence is under
`docs/validation/evidence/underground-frontier-profile-renewal-2026-10-05/`.
This verifies worker source compatibility only. It does not grant World
support, clearance, paid inputs, productive work, save/resume, complete Room
visuals or 256-resident acceptance. `world_activation_qualified` remains false.

## Subsequent CI fixture correction

CI37259107677 at9dad correctly failed two original FrontierPublication tests
which still asserted pre-renewal `MOLE_CATALOG_SOURCE_DRIFT`. The independently
reviewed correction changes only those two expected values and one scope
comment. Geometry refusal, real paid-state/actor conservation, exact published
endpoint/edge counts and all source-drift negatives stay unchanged. The strict
FrontierPublication/Itinerary/QualifiedProfiles regression passes37 tests/
1,149 assertions/0 with every diagnostic/leak count0 and analyzer0/3. Raw failed
CI and corrected focused evidence are retained under the renewal evidence path;
no whole-build acceptance is inferred.
