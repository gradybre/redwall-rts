# Live selector and static reachability correctness

Base: `f08b3fea37fea76910e7a8fd96d6c366ebaa5d8e`.
The exact five source/test SHA-256 values are in `source-sha256.json`.

The clean run passed Locations 55/1654, Routes 56/9961, and unchanged
WorldRoutes 26/1711: **137 tests / 13,326 assertions /0 failures**. Every strict
and raw diagnostic/leak footer is zero. LSP reports 0 warnings in 5 files.
`invocation.json` records exact commands, unchanged source pins, restored assets,
and the original/restored project bytes. No production source profile is
qualified by the inherited synthetic certificate/paid-geometry fixtures.

Reproduce from this checkout:

```sh
python3 docs/validation/evidence/underground-connector-placements-2026-10-03/reproduce-hot.py --out /tmp/ug1105-hot-repeat
```

The runner temporarily sets `config/use_custom_user_dir=true` and
`config/custom_user_dir_name="Redwall-ug-geometry-hot-tests"` in this worktree's
project; it restores the exact original file in `finally`. This isolates shared
`user://` names from other worktrees. The parent full suite was running during
this test, so timing is diagnostic and must not be presented as isolated runtime
qualification. Port 6254 is separate from the parent's analyzer.

The 20 batches of 256 callers each take45.749 ms minimum,46.649 ms median,
47.555 ms p95 and47.770 ms maximum at O2048 and a three-span route. All 5,120
queries succeed with 256 actual living residents. Object count stays unchanged.
**Timing qualification failed**: this does not fit the whole simulation tick
budget and cannot justify a full path search on every productive worker.
No native transient-allocation or overall-memory qualification is claimed.

The earlier hot-1 failure is retained. A wrong byte-column count check refused
all new successful cases before routing; its printed timing is invalid for a
successful-query workload. Correcting the expected actual flags-bank length
was the only production correction before hot-2. Construction independently reviewed all five exact hot-2 pins and accepted
this bounded correctness scope with no high/medium finding. Review was read-only
and did not repeat the engine run. The only subsequent test change replaces an
overly strong Object-counter assertion label; hot-3 retains the exact final
five-file manifest and repeats all three suites and the analyzer.
