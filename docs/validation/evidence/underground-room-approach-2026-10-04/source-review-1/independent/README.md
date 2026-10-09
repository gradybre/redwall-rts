# 1150 independent review of frozen candidate13

Date: 2026-10-04. Read-only source review by Geometry; no engine rerun or edits
in the author's worktree. Diff base:
`7e199b7669a5bad5613aaf2881c9a801cc1dda51`. The nine reviewed executable/UID/tool
pins are preserved in `source-sha256.json`, manifest SHA256
`9fcc7505a0b0867e5b82abc35afb9b938200e97512d2649ba1cd84b63a8a4e60`.
All nine matched before and after review/Python replay.

## Blocking finding: final source/terrain reads can still dispatch observers

**MEDIUM.** The new `Witness.final_refusal()` runs physical and companion
checks, then returns `source_refusal()`. That nominally final source check calls
`World.is_published()` / `section_1_published_seed()` at Approach lines113–114.
Its prepared endpoint branch calls `Buildings.is_live_room()` at line217.
World and Buildings are not restricted to their exact base scripts. The
endpoint helper also dispatches private Locations and Owner readers on
objects that may be subclasses. These calls do not satisfy a callback-free
final leaf.

A concrete public-observer witness is an actual Buildings subclass whose
`is_live_room()` copies the genuine result, then places an actual new well and
returns the copied success. Armed only for the final source tail, it runs
after the final Terrain check. The new well is not a retained sparse Space
source, so the subsequent root Directory/Sites/Space identity leaves do not
reobserve that exclusion. This is the same real well placement mechanism as
the author's late-Sites regression, moved beyond its current recheck.

The same defect reaches the inherited Terrain call, even though Approach
requires the exact Terrain script. `prepared_local_facts_refusal()` calls
`_leaf_binding_refusal()`, which dispatches World, Owner, CoreSources and
Construction methods. Its tile chain calls `World.terrain_into()`,
ResourceNodes readers and `Buildings.building_at_tile()`. An actual
`building_at_tile()` override can copy NULL, create a well and return NULL;
the query then succeeds without seeing the new foundation. A final getter
fix confined to Approach would not close this transitive call chain.

Furnishing accepted the finding, kept the rejected nine pins frozen until the
review completed, and requested root's explicit narrow Terrain ownership
seam. The correction must retain ordinary observations and add actual
final-only copied-result mutation regressions. No broad type substitution,
success flag, second survey or unowned source edit was authorized by this
review. Source acceptance is withheld pending the exact corrected packet.

## Other reviewed contracts

No additional high/medium finding was identified in this frozen slice:

- The original extended Request and the protected ordinary RoomPlan remain
  distinct, with exact source profiles, endpoint full refs, all extra fields,
  actual future candidate and original arena/token closure.
- Prospective WorkFace and real profile-path proof run before Room staging;
  complete travel BODY/TURN and STANCE are independently proved even for a
  zero-edge path. Target membership follows the same intersected metre-cube
  union while preserving fine cells and holes.
- Prepared Space can change only future Room metadata. Existing physical
  regions and endpoint/path payloads remain exact; actual Locations and
  WorldRoutes refresh candidates share the original RoomContext.
- The successful-confirm tests use real RoomOrders/RoomBindings and static
  publication kernels. They create no new approach endpoints/edges and do not
  claim paid phases or production source qualification. Synthetic initial
  corridor/profile inputs are stated explicitly.
- All large proof images are released before subsequent Locations,
  WorldRoutes and Sites stages. Original cold cleanup does not release a
  replacement lease.

## Independent arithmetic replay and author evidence

Executed only the author's six bounded Python census tests using `python3 -B`
from the reviewer's own worktree. All passed. Independently called the actual
census module and compared its complete structured result with
`candidate-13/census.json`; they are identical. `verification.json` records
the before/after pins and this equality.

The maximum complete logical cold lifetime is 938,368 / 1,048,960 bytes;
Locations preparation is the largest phase. New witness plus own conservative
numeric frames, path-call and expression allowances use 3,356 / 4,096 bytes.
The retained Face keeps its separate 2,048 allowance, and the old Room/Sites
allowance is charged once. No native RAM qualification follows from these
source counts.

Inspected the author's candidate13 results: 59 tests / 1,631 assertions / zero
failures across three official singleton suites; strict/raw diagnostics and
leaks zero; analyzer 0/4; source/HEAD/project/registry/assets restored or
unchanged. This review did not rerun those engines. Prior rejected attempts
remain in the author's history manifests.
