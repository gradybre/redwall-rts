# Corrected Specification checkpoint — e9d52293

At frozen integration HEAD `e9d52293e2aef0e08eed68bdcf99ffd5f2c1ebf5`, all35
recorded commands passed: the34 Specification workflow checks and the9-case
stale-memory-ledger regression. HEAD stayed unchanged. `checks.json` retains
each exact command, duration, output hash and exit status; the adjacent logs
retain assertion counts and diagnostics. The capacity audit reports
`test_registry_capacity_audit: PASS -- 190 check(s), 0 failure(s)` and the
memory checker tests report38 passing tests.

This includes the independently reviewed generated capacity provenance fix
`d20f4678` (original own commit`daf5ab65`), source-local motion proof`c62d6236`,
exact WORK query`e134818f` and registry reconciliation`e9d52293`. The failed
capacity checks oncc2ffbac remain under that earlier checkpoint. No gate,
capacity or memory arithmetic was loosened. This result does not relabel the
previous remote failure or constitute another full Godot suite run.

The reproduction commands are in `checks.json`; output paths identify this
fresh directory. To repeat elsewhere, use the local Python executable and
replace only those output paths. Run from the explicitly chosen checkout root.
