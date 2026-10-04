# Frozen bounded source reuse and cold identity correction

The five files in `source-sha256.json` stayed unchanged through clean import,
three strict suites and analyzer. Locations57 tests/1731 assertions,
Routes61/10108 and WorldRoutes26/1711 total **144 tests/13550 assertions/0
failures**. Every strict and raw diagnostic/leak footer is0; analyzer0/5.
Original project bytes and assets were restored. The run used the same isolated
`user://` setting as prior hot checks; no other worktree was changed.

Reproduction from the repository root (choose a new output directory):

```sh
python3 docs/validation/evidence/underground-connector-placements-2026-10-03/reproduce-hot.py --out docs/validation/evidence/underground-connector-placements-2026-10-03/hot-recheck --port 6254
```

The Locations hint adds16 logical retained bytes (full source EntityRef8 +
row8). It rechecks actual presence/full generation; source revision and
World/Room facts remain fresh. Real source/Room retirement and generation reuse
are covered. SourceOwner's sealed/loaded unique-source invariant permits the
hint; it does not store validity or authorize an endpoint.

WorldRoutes adds32 logical bytes: original Catalog/Profile/Level object IDs
plus last fully attested Catalog revision. Actual monotonic Catalog/Profile
loading and load-once Levels make their already-compared digest bytes reusable.
Every current owner, complete Domain, source revision and selected endpoint/
section proof remains mandatory. Tests use genuine loaded foreign equal-byte
owners and actual replacement/recompilation, not asserted success flags.

The original rejected outer-provider override from hot-4 is restored as its own
active regression. The existing Catalog reference now belongs to the typed
Routes.Bindings base; WorldRoutes no longer declares a duplicate. The cold
caller compares that direct field with its retained original Catalog after
callbacks and before copying output. The test returns exact ROUTE_OWNER_MISMATCH,
preserves all8 output integers and performs no later permission callback.
A separate actual Terrain callback replacement test also passes. No additional
provider reference or virtual final guard was introduced. Hot-4 and hot-5 retain
the rejected test/analyzer evidence; neither is counted as final acceptance.

Actual topology fixed controls are2102/2112; combined Locations/Routes reserved
bytes stay1041728. The WorldRoutes32 bytes fit its existing4096 fixed allowance.
Placement remains1670/2048. The deepest numeric helper-frame path stays336/512
inside the actual caller's allowance. These are logical source counts; native
capacity/temporary interpreter allocation are not measured here.

Timing remains **failed runtime qualification**. Twenty batches of256 actual
living callers (5120 successful queries, three committed spans, O2048) measured
25.307ms minimum,25.609ms median,26.018ms p95 and26.232ms maximum. The Object
counter is unchanged across the completed loop; that is not a transient/native
allocation proof. Mac diagnostics improve on the prior46.419ms p95 but do not
qualify an every-worker full search, an aggregate simulation tick or the
qualification-floor hardware. Larger distinct-path workloads and a suitable
bounded/shared runtime admission strategy remain open.

Independent Construction read-only review accepted all five hot-6 source/test
pins, rehashed unchanged at the end, with no high/medium finding. It reviewed
source-row/full-generation freshness, immutable owner/revision reuse, the outer
callback cold-boundary correction and the48-byte census. It did not rerun engine
tests. The timing/native qualification limits above remain open.
