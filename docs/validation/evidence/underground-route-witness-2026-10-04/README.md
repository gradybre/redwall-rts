# Charge-stable existing route scratch experiment

Decision1124, diff base `f6d3bdb33edcb550adb08bc15b2034e9f77c54e5`.
`source-sha256.json` pins the three changed source/test files. The accepted1125
stationary-turn behavior is preserved. `census.py` recounts all104 added logical
bytes and the384/512 helper peak; it does not measure native memory.

Exact raw execution is retained in the adjacent historical packet:

- `../underground-connector-placements-2026-10-03/hot-witness-baseline/`: earlier
  unmodified runtime145/13840/all-zero baseline, p95 21.888ms per256 calls.
- `../underground-connector-placements-2026-10-03/hot-witness-resumed-1/`: strict
  158/14566/all-zero, rejected because12 statically accessed fields were reported
  unused by the analyzer; source remains pinned in that manifest.
- `../underground-connector-placements-2026-10-03/hot-witness-resumed-2/`: final
  Locations57/1731, Routes69/11132 and unchanged WorldRoutes39/2437, total
  **165 tests/15300 assertions/0 failures**; every strict/raw unexpected/error/
  warning/leak footer is zero, LSP0/5 and source/project/assets restoration true.

Reproduce from this exact candidate into a new directory:

```sh
python3 docs/validation/evidence/underground-connector-placements-2026-10-03/reproduce-hot.py --out /tmp/ug1124-fresh-evidence --port 6254
python3 docs/validation/evidence/underground-route-witness-2026-10-04/census.py
```

The runner temporarily uses isolated `user://` directory
`Redwall-ug-geometry-hot-tests` and restores original project bytes. Its existing
five-file execution manifest also pins unchanged Locations and its test; the
three changed files are repeated in this packet. WorldRoutes' turn test source
is unchanged from1125 and its strict suite is included. No duplicate engine run
was requested of the independent reviewer.

Tests compare exact remaining work with fresh, reused, cleared and actual
restored owners; include a one-check-short atomic refusal; exercise real cold
search and certificate publication; and reject stale source/full-edge/mask
facts even after a warm query. Two exact zero-span endpoints do not alias.
Saturated unsaved serials permanently disable reuse without disabling queries.

The final paired fresh/repeat p95 measurements are22.892/17.516ms for256 calls;
256 distinct ordered endpoint pairs on an actual16-endpoint directed ring take
38.524ms p95. All are **failed timing qualification**. Complete tick performance,
maximum distinct paths, physical Contacts work, production source certification
and target hardware/native memory remain separate gates. Object counts are not
packed-array/native allocation measurements.

Independent root review accepted the three exact pins and reproduced the
source-derived census. It found no remaining high/medium source issue in this
scope and did not rerun the engine. `review.json` records that bounded verdict.
