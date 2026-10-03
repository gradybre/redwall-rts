# UG07 B3 shared paid Router evidence

Frozen source independently reviewed by the root integration owner on 2026-10-03;
all five pins in `source-sha256.json` matched. No unresolved finding in this scope.
Source remained unchanged during final validation. This is not a full-suite,
production geometry, actual tip-stock, save/load or target-hardware performance claim.

The own worktree is `redwall-rts-codex-ug-orders`, branch
`codex/underground-orders`, parent `a1a06b1e`. The final clean setup checked for
`godot/demo/assets` (absent), deleted this worktree's `.godot`, and ran
`godot --headless --path godot --editor --quit`. Exit0 and zero error/warning
lines are recorded in `clean-import.log`; no foreign worktree was changed.

Eight singleton shards used the unchanged strict `tools/run_tests.sh` with
`--shard i/N --output-dir /tmp/ug07-b3-final-strict`; i/N was derived from the
actual discovery/plan in `tools/ci_test_shards.py`, not an independent test runner.
Each raw log contains coverage, discovery and strict diagnostic output.

| Suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| test_construction | 48 | 515 | 0 |
| test_construction_modular | 11 | 135 | 0 |
| test_excavation_physical | 38 | 22446 | 0 |
| test_gear | 80 | 1139 | 0 |
| test_modular_inventory | 11 | 268 | 0 |
| test_modular_projects | 19 | 1816 | 0 |
| test_save_owner_work | 10 | 12786 | 0 |
| test_work | 76 | 9234 | 0 |
| Total | 293 | 48339 | 0 |

Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The targeted actual editor-language-server analyzer ran with `--max 0 --port
6156` over all five pinned files and reports `0 GDScript warning(s) in 0 of 5
file(s)`. The reviewed production functions have at most30 nonblank,
noncomment/docstring lines. Registry coverage reports103 modules,487 rows,
828 packed columns checked; full canonical/memory reconciliation is the root
1072 packet, not silently replaced by this local Markdown source gate.

The new19 tests use real Inventory, Reservations, shared Funding, Construction,
Jobs, Work, Residents, Gear and Buildings. Only spatial/contact and purpose
publication admission is explicitly synthetic. The actual paid Furniture test
installs a real pending Kitchen bench after full catalog delivery/work and
checks that retirement asks for no post-install pending quote. The separate
real Tips adapter is verified in the root's UG20 composition. No fixture
permission is connected to live demo dispatch.

Development checks initially caught one incorrect test helper reader name and
one child fixture still in a nonproductive Job state. The helper name was
corrected; the child test now explicitly attempts JOB_STATE_WORK. The runner
failed both rather than treating exit0 as success. All final pins above pass.
Byte-equality refusals are asserted as Boolean equality to avoid printing
multi-megabyte owner images if an assertion fails; the compared bytes are unchanged.

The physical regression includes the existing synthetic-contact timing probes:
256 actual workers mean10506us/max10852us, generic Work baseline2485us. This
branch predates the root's separately reviewed Gear index; neither figure
qualifies the target hardware or whole simulation tick budget. Values are
retained as diagnostic evidence, never a performance pass.
