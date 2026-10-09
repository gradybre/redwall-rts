# UG07 A0 — physical owner identity readers

2026-10-03. This evidence covers only the three read-only Sites queries and
their adversarial test, recorded in decision 1069. No persistent state changes.

The orders worktree was fast-forwarded to integration `5d2d8eca`. Demo assets
were absent. Its first clean import diagnosed seven tracked LFS pointers;
`initial-lfs-import-diagnostics.txt` preserves those setup diagnostics. Local
`git lfs checkout` hydrated only those own-worktree assets. After restoring
the generated import sidecars and deleting `godot/.godot`, the clean import
had zero error/warning/script-error lines. Source assets were not changed.

The existing CI shard planner isolated `test_excavation_physical.gd`; the
unchanged strict `tools/run_tests.sh --shard … --output-dir …` ran all gates.
`focused.stdout.txt` retains its actual output, including 35 tests / 22325
assertions / zero failures and zero unexpected diagnostics or leaks.
`analyzer.stdout.txt` retains the `--max 0 --port 6156` result for Sites and
the physical test: zero warnings in two files.

The adversarial case creates another actual Directory whose World ref has
the same numeric slot and generation. Distinct Construction/SpatialAuthority
objects do not match; valid bindings, null, failed initialization and weak
target expiration are covered. No getter itself proves World liveness,
clearance, worker eligibility or permission to publish a physical transition.

The existing performance probes remain unqualified and are included only
because the physical suite contains them. There is no new performance claim.
