# Integrated validation comparison

Runtime/test source: `92fcf82a32eba7daf57926a0554100322e288855`, based on
master `82d60ba8`. Subsequent evidence/documentation commits do not change those
runtime or test sources. Both environments use Godot 4.7.2.

| Counter | Local macOS, full single run | Linux CI, eight shards |
| --- | ---: | ---: |
| Tests | 9,138 | 9,138 |
| Assertions | 612,134 | 612,123 |
| Failures | 0 | 0 |
| Unexpected errors | 0 | 0 |
| Unexpected warnings | 0 | 0 |
| Expected diagnostics | 272 | 272 |
| Tolerated notices | 353 | 353 |
| Leaked objects | 0 | 0 |
| Leaked resources | 0 | 0 |

The CI coverage auditor confirms **298 suite files executed exactly once**.
All 14 CI checks passed, including the unchanged analyzer, metadata groups and
aggregate gate. See [CI checks](ci-checks.json), [shard audit](ci-shards.txt),
[full-run evidence](full-suite.txt) and the
[CI run](https://github.com/gradybre/redwall-rts/actions/runs/37082107961).

## Assertion-count limit

The optional cross-environment command

```sh
python3 tools/ci_test_shards.py verify --reports /tmp/redwall-underground-ci-37082107961/combined --count 8 --baseline-log /tmp/redwall-underground-full-final.log
```

correctly **refused exact equivalence** because of the 11-assertion difference.
No gate, allowance or counter was changed to hide it. Test counts and every
diagnostic/leak total agree; exact assertion parity is not claimed.

Ten extra assertions reproduce in the existing `test_demo_build.gd`:
224 locally versus 214 on Linux. Its F11 test at line 53 iterates all actual
`InputMap` actions and key events, including platform-specific built-ins.
The same difference appears when running all 24 suites preceding and including
that file in full-run order. That prefix passed 839 tests and 37,655 assertions
with zero failures, unexpected diagnostics or leaks.

A comparison of 123 short suites found no other assertion-count difference;
it passed 3,095 tests and 128,343 assertions. The remaining one assertion in
the complete run has not been isolated and remains an evidence limitation.

The seven directly relevant room/input and newly integrated route/performance
suites have identical test, assertion and failure counts on both machines:

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| `test_demo_bursts.gd` | 8 | 73 |
| `test_demo_input_live.gd` | 3 | 555 |
| `test_demo_people_pairs.gd` | 1 | 4,919 |
| `test_demo_resident_cells.gd` | 8 | 14 |
| `test_demo_route_planning.gd` | 25 | 1,990 |
| `test_demo_tunnel_ext_world.gd` | 76 | 530 |
| `test_demo_work_index.gd` | 2 | 4 |

Their integrated local check passed **123 tests, 8,085 assertions, 0 failures**;
diagnostics were **0 unexpected errors, 0 unexpected warnings, 0 expected,
137 tolerated, 0 leaked objects and 0 leaked resources**. These targeted
comparisons diagnose the counter difference; they do not replace the full run.
