# Route composition memory renewal — accepted

The current 1167 route composition census is replayed before the older Room
constructor is projected onto three named archived sources. The original
manifest is unchanged; `route-owner-manifest.json` contains the complete new
54-module and 41-witness closure.

`route-extension-tests-2.log`: 15 tests passed.
`route-joint-tests-2.log`: 251 tests passed in 125.745 seconds.
`route-pack-1.log`: 99,999,806 logical bytes, 194 bytes headroom; qualification false.

Independent review commit `1ab85c261d27a5c723a6a083d35732d36b80fc36`, integrated
as `c97bddd6`, independently passed 17 tests and all 115 before-producer refusal
probes and reproduced the full pack byte-identically without Git/subprocess
access. See the complete review under
`../underground-room-integration-check-2026-10-05/route-memory-review-1/`.
Constructor coexistence is 8,161/8,192; UI reset controls/helpers are 6,067/1,919.
No global or per-component reservation grew. Native RAM qualification is open.

The initial 15-test run had one test-harness error: its source index excludes
system modules, so the new Host mutation needed to load its manifest-identified
source explicitly before injecting it. The first full 251-test run then had two
old UI-refusal-message expectations: the expanded closure correctly rejects
those same mutations earlier. Both failed logs are retained. Only those test
expectations/fixtures were corrected; the production refusal did not change.

Registry checks passed: 154 classified modules, 731 rows, 1,055 packed columns;
671 persisted packed fields, 61 owners, 756 canonical records; unchanged
capacity audit and generated canonical declaration checks.
