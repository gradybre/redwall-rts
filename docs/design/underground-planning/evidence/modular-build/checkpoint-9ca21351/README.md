# Clean full checkpoint 9ca21351

The frozen own worktree at `9ca2135119ceafe8879f4d39eb1c58939a264657`
completed the prescribed procedure: park demo assets if present, remove
`godot/.godot`, run `godot --headless --path godot --editor --quit`, run
**`./tools/run_tests.sh` with no arguments**, then run the analyzer with
`--max 0`. Assets were absent initially and remained absent. Original project
settings, every tracked source pin and HEAD were restored or unchanged.

```text
10941 test(s), 1016692 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1220 file(s)
```

Clean import took 10.998 seconds, the full suite 1,780.946 seconds, and the
analyzer 261.886 seconds. All commands and restoration checks are recorded in
`invocation.json`. The actual full raw log, analyzer report and source pins are
retained beside the reproducible harness.

The earlier `1eb7a64d` and `c24421ab` attempts stopped at the nested capture
project warning; the parent offline-subtree `.gdignore` fixed that import
problem. Their failed logs remain recorded. This checkpoint includes that fix
but predates the subsequent Session, Gear/Carry host and Clock commits, which
have their own focused evidence.

Remote CI at `1eb7a64d` passed all 391 suite files exactly once across eight
shards in 13m10s, with the same test count and every diagnostics/leak total.
It has nine fewer assertions and is a different commit. This packet makes no
same-head all-counter equivalence claim; the exact comparator remains strict.
Passing these source tests does not close playable demo, save/resume or
256-resident acceptance.
