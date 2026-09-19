# Resumption evidence — 2026-09-19

Baseline `47a4da2642912afee4d5249424d31ab6c92f014a`, Godot
`4.7.2.stable.official.ed1daf0bf`. All local execution is against the isolated
resumption worktree. The original mixed checkout remains untouched.

## Accepted evidence paths

- `tests-acceptance.log`: final supervised repository suite. Read its final
  summary and exit result in `acceptance.json`; intermediate logs are not this gate.
- `contracts-final.json`: exact commands/results for fifteen static checks.
- `capacity-final.log`: sidecar regeneration and 190 checks; 470 equalities,
  46 upper bounds. The sidecar remains unadopted; schema 2 describes metadata.
- `ui-engine-command-control.log`: six actual Godot viewport-routing cases with
  an instrumented world handler, a real UiCommandBridge, and the live Settlement
  command queue. Open world adds one command; panel/Back cases add none. It uses
  a seeded resident fixture and no simulation ticks. It does not prove the
  production world router or native pointer/visual acceptance.
- `stock-lifetime-final.log`: after external refs are dropped, neither member of
  the Inventory/StockAge pair remains. Optional cleanup is explicitly marked
  unattempted/null after the pair is already released.
- `capacity-independent-review.md`, `final-independent-review.md`,
  `review-closure.md`: separate Claude reviews. The final closure closes the four
  bounded follow-up findings; reviewers did not run tests or certify full release.
- `worker-ledger.json`: actual model/session IDs, stopped-process evidence,
  input hashes and strict-output recovery history. No unattended service runs.

## Reproduction

From the repository root:

```sh
godot --headless --path godot --script test/run_tests.gd
python3 tools/audit_registry_capacities.py --check
python3 tools/test_registry_capacity_audit.py
godot --headless --path godot --script ../docs/validation/evidence/resumption-2026-09-19/ui_engine_input_probe.gd
godot --headless --path godot --script ../docs/validation/evidence/resumption-2026-09-19/stock_lifetime_probe.gd
```

`focused_tests.gd` is a bounded diagnostic only. The repository's supervised
runner, which detects printed GDScript errors, supplies the acceptance gate.

## Retained failures and refinements

`tests.log` and `startup.log` are the unchanged baseline. The initial startup
probe called a wrong accessor; `startup-attempt1.log` retains that failure.
`ui-engine-before.log` likewise retains a failed eager-load attempt: autoloads
must exist before loading UiShell under `--script`. Both owned failed processes
were stopped; corrected deferred probes exited normally.

`ui-engine-baseline.log` proved table/engine disagreement, not command leakage.
`ui-engine-after.log` exposed the missing off-tree input refresh.
`ui-engine-final.log` passed routing but its all-zero command counts lacked a
positive control; the newer command-control log supersedes that claim.
`stock-lifetime-after.log` mislabeled a skipped unbind as false; the final log
labels attempted versus succeeded separately.

`tests-ui-c4.log` failed the old outside-point assertion: its point lay inside
the workspace. The replacement asserts both the point's actual geometry and the
panel's consumption. `tests-final.log` then exposed one seed-guard control test
that discarded its owning reference; the borrowed contract requires the fixture
to retain that owner. Neither failing run is called a pass.

The first focused repair run exposed visible search/name controls with closed
gates. The repair gives search the workspace's context and refuses a selected-only
name editor without a subject before drawing. The stronger invariant passes in
the later focused log and is part of the final full suite.

The raw worker patches are proposals and may have inaccurate hunk counts.
`cap-sound-applied.patch` records exact-text normalization. The actual repository
diff, tests and independent review define what landed, including Astra's bounded
integration repairs.

## Integration clarifications to the review text

The closure review's `ui-engine-command-command-control.log` spelling is a typo;
the supplied artifact is `ui-engine-command-control.log`. Its mention of a
canvas/stretch mismatch follows an obsolete source comment: project.godot
already uses `stretch/mode="disabled"`. The earlier 14-object boot leak warning
was from the pre-stock-repair UI log; the final isolated lifetime/boot log has no
such warning. Full-suite residual leaks remain a separate open finding.
