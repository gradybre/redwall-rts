# Integrated CI and registry fingerprint refresh — 2026-10-04

CI run [37193630078](https://github.com/gradybre/redwall-rts/actions/runs/37193630078)
tested integration `3e36e7c4fe9c43f487952511a58d3d8d91dd4cd2` and **failed**.
All original gates stayed enabled. The run and all eight shard artifacts are
retained here; this is rejection evidence, not a passing milestone.

## Registry correction

The Specification contracts job passed its earlier checks, including the146
underground memory tests, then refused the stale capacity audit. Its raw log
is `specification-ci.log`. Running the existing generator changed exactly one
JSON leaf: `/audited_source/module_sha256/transforms`. `delta.json` records the
old/new file and source hashes. It refers to the already reviewed stationary
ground-turn change integrated in `3bac01b7` (Decision1125), not a new capacity.
All capacity values, relations, rows, counts, registry identity and source-line
evidence are equivalent after parsing; no checker or source changed.

```text
registry: 764 listed fields, 756 canonical, 8 non-hash (0 admitted here)
capacity census: 587 prose = 501 equality + 86 upper bound, 169 other canonical shapes, 65 distinct expressions
test_registry_capacity_audit: PASS -- 190 check(s), 0 failure(s)
```

The exact `--check` passes. All19 later Specification-contract commands, which
CI had skipped after this failure, also passed locally. Their exact argv,
durations and logs are in `followup-contracts/`. Earlier passing CI commands
were not represented as local reruns.

## Remaining integrated rejection

The eight runner summaries total:

```text
10823 test(s), 995744 assertion(s), 11 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

Those are sums of the eight actual lines, not a single-run summary. All382
observed suite names are unique. Shards5 and7 failed; their wrappers stopped
before the raw-log guard and success-report JSON. Only the other six shards
emitted the additional zero-unexpected/zero-leak `log:` line. No complete
aggregate success or single/sharded equivalence is claimed.

The11 failures are eight tests in `test_mole_qualified_profiles.gd` and three
in `test_demo_profile_pack.gd`. Their first failure is
`MOLE_CATALOG_SOURCE_DRIFT`: the immutable published Mole profile still pins
the earlier consumer source. The subsequent expected-success assertions then
fail. The source guard remains strict; this metadata-only registry correction
does not update or waive the animation-profile contract. Reviewed consumer
closure and renewed profile publication are still required.

The independent analyzer and all three metadata gate groups passed in CI:

```text
0 GDScript warning(s) in 0 of 1199 file(s)
```

`ci-summary.json` records the arithmetic, per-shard diagnostics, raw-guard
presence and failing suites. `ci-run.json` is the completed remote job state.
Source and diagnostic qualification must be renewed after the next integration.
