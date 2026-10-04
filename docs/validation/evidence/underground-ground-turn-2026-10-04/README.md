# Stationary ground turn — decision1125

The final candidate is `candidate-7/source-sha256.json`. It adds a concrete
ground-only turn command and a static, original-pose-checked Transform commit.
It adds no retained field or bank. Tests use actual Directory, World, geometry,
Locations, actor, Job, Work, Gear and Inventory owners; source certificate flags
are explicitly synthetic and grant no production content qualification.

From the owning checkout:

```sh
python3 docs/validation/evidence/underground-ground-turn-2026-10-04/reproduce.py --out /tmp/ug1125-fresh-run
python3 docs/validation/evidence/underground-ground-turn-2026-10-04/census.py
```

The output directory must be new. The wrapper removes only this checkout's
import cache, temporarily parks its demo assets if present, uses the isolated
`Redwall-ug-geometry-turn-tests` user directory, runs strict singleton shards,
then analyzer port6274. Project bytes and assets restore in `finally`; source
pins are checked again afterward. Each invocation records its actual commands
and restoration results. This is focused component evidence, not a full-suite
or complete-client runtime result.

| Final suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| WorldRoutes |39|2437|0|
| Routes |62|10393|0|
| Transforms |32|221|0|
| Total |133|13051|0|

Every strict and raw footer reports zero unexpected errors/warnings and zero
objects/resources leaked at exit. Analyzer reports zero warnings in five files.
All five pins, project bytes and asset restoration checks pass.

Thirteen new actual-World turn tests cover all-yaw admission, unchanged current
position and route/economy, exact interpolation history, invalid yaw and Job,
queued/prepared refusal, complete source recovery/stance geometry, new World
resource exclusions, late actual pose/Job/equipment/source changes, callback
reentry, exact endpoint payload, current occupants, unregistered living
occupants and exact finite work exhaustion. Transform tests separately check
full identity, stale pose/revision and complete refused-image preservation.

`census.py` reads the pinned production source and emits the declared numeric
frames for the reviewed paths. `candidate-7/helper-census.json` retains the
result. The longest observing cargo chain is464 bytes plus48 expression/result
bytes, using the existing512 ceiling. Borrowed object references, StringNames,
Variant headers, native frames and existing OpResult allocations are explicitly
outside that logical numeric count and remain unmeasured. No field or schema
delta is inferred from an interpreter stack estimate.

## Rejected and intermediate evidence

- Candidate1/2 retained early test API/loader failures. They are not passes.
- Candidate3 retained a wrongly admitted overlapping test actor and its failed
  assertions. The actual actor admission correctly refused that test setup;
  the final test proves the same recovery-overlap predicate without pretending
  the failed admission succeeded.
- Candidate4/5 retained an inherited test-fixture class resolution failure.
  The negative Location callback property is now accessed through an explicit
  `RefusingLocations` cast in the test helper. All negative probes remain active.
  The `inheritance-*.json` files record the bounded parser diagnosis.
- Candidate6 was strict green before independent review. Construction found
  that a live actual resident with no Routes row was skipped as empty air.
- `review-occupancy-rejected` adds the real spawn/place witness to that original
  production source:39 tests /2437 assertions /1 failure, with zero unexpected
  diagnostics/leaks. Candidate7 refuses with `ROUTE_TURN_ACTOR_UNBOUND`, preserves
  complete Transform/route images, then succeeds after actual despawn.

Four large raw logs printed whole byte arrays on failed assertions. They are
losslessly retained as `.log.gz`; `compressed-logs.json` records original and
compressed SHA-256 values. Decompression yields the original recorded filename
and bytes. Other raw logs, exact manifests and invocation files remain intact.

The Routes suite's inherited256-caller timing diagnostic in candidate7 was
51.376ms p95. It remains a failed timing qualification; the previously accepted
performance packet and saved1124 experiment are separate. This turn component
does not certify production profiles, source WORK recovery, stair support or
the playable first-prefix composition.

## Independent review

Construction reviewed the full five-file packet without duplicating engine
execution. Its sole medium finding was the unregistered-living-resident skip;
the rejected witness and narrow correction are retained above. Construction accepted the corrected five-file pins after rechecking the
actual refusal/retry and source census. No high/medium finding remains in this
bounded component. Exact source pins and verdict are recorded in `review.json`.
