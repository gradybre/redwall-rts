# Remote checkpoint f9854b4b

GitHub Actions run [37158872557](https://github.com/gradybre/redwall-rts/actions/runs/37158872557) completed successfully at exact head `f9854b4bcf0b1fc2e0f446d6ac8152ec15198680`. All eight suite shards, four Godot gates, Specification and aggregate jobs passed. The original CLI run metadata and complete compressed run log are retained as `run.json` and `run.log.gz`; `aggregate.json` was extracted from that log.

The aggregate verifies all362 discovered test files exactly once: **10433 tests,961393 assertions,0 failures**. Totals are **0 unexpected errors,0 unexpected warnings,272 expected,353 tolerated,0 leaked objects,0 leaked resources**. Each shard also passed the raw log diagnostic/leak check. The analyzer reported **0 GDScript warning(s) in0 of1160 file(s)**.

Run creation through completion was686 seconds (11m26s). Shard suite durations were245,399,449,213,242,317,383,334 seconds. The analyzer gate was665 seconds. These are measured remote timings, not a claim that every future run will finish within the same time.

The aggregator received no same-head full-run baseline. Its `baseline_matches:false` therefore records no supplied comparison, not a mismatch. This checkpoint predates the newer reviewed driver, Placement, EntryPlan and state-handoff source. A fresh exact clean-assets/cache/import/no-argument full suite and analyzer remain required for the next integrated milestone. No playable underground requirement is closed by CI alone.
