# Integrated checkpoint 454eae23

Frozen source: `454eae23dec8de897cc606540829db4e00d6bde6` on
`codex/underground-modular-integration`. This is a component integration
checkpoint; the complete playable underground workflow remains open.

The recorded wrapper used the exact required procedure: park demo assets if
present, delete this worktree's `.godot`, run
`godot --headless --path godot --editor --quit`, then the unchanged no-argument
`./tools/run_tests.sh`, and restore the original asset state. Assets were absent
before and after. Source hashes and HEAD stayed unchanged. The zero-warning
analyzer ran after the successful full suite.

```text
10637 test(s), 976936 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1180 file(s)
```

Exact commands and restoration evidence are in `invocation.json`. Clean import
took 10.829 seconds, the full suite 1,361.483 seconds, and the analyzer 255.214
seconds. Reproduction uses the retained checkpoint wrapper:

```sh
python3 docs/design/underground-planning/evidence/modular-build/checkpoint-499bfd73/reproduce.py /absolute/fresh/evidence-directory
```

[CI run 37180183367](https://github.com/gradybre/redwall-rts/actions/runs/37180183367)
passed all fourteen jobs. The first required job started at 05:32:24 UTC and the
aggregate finished at 05:44:19 UTC: **715 seconds (11m55s)**. All 370 suite files
executed exactly once across eight shards. The raw artifacts independently
verify 10,637 tests, 976,930 assertions, zero failures, 272 expected and 353
tolerated diagnostics, and zero unexpected diagnostics or leaks.

The exact full-run comparator **refused equivalence** because CI has six fewer
assertions. Test-file coverage, test count and every diagnostic/leak total match.
The original no-argument runner emits no per-suite assertion counters, so these
artifacts do not identify which suite caused the assertion difference. No cause
or exact assertion equivalence is claimed; the comparator was not weakened.

`ci-run.json`, `ci-jobs.json` and `ci-artifacts.json` retain the GitHub metadata;
`ci-artifacts/` contains the unmodified downloaded manifests, reports and logs,
flattened from their eight artifact directories for the existing auditor.
`ci-invocation.json`, `ci-aggregate.log` and `ci-equivalence.log` retain the actual
audit commands/results. All gates in the existing workflow remain enabled.

This checkpoint includes the reviewed phase-contact packet, its memory census,
the INSTALL animation driver and prior source qualification. Later guard1120,
installed-timber1114, source compiler/native-v3 and concrete phase adapters are
not covered by this full result. Logical memory admission remains distinct from
native memory/performance qualification. Kitchen gameplay, all later queued
workflows, complete 1280×720 acceptance and 256-resident qualification remain open.
