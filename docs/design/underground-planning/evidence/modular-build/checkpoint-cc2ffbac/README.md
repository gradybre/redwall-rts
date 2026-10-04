# Full integration checkpoint — cc2ffbac

Frozen source `cc2ffbac9dcada03c24cfb298cba0c9bf8870d4d` on the owned
`codex/underground-modular-integration` branch passed the exact clean CI
procedure: park demo assets if present, delete this worktree's `.godot`, clean
headless editor import, the complete no-argument `./tools/run_tests.sh`, and
`tools/gdscript_warnings.py --max 0`. Assets were absent and that state was
preserved. No source or HEAD changed during the run.

```text
10383 test(s), 957996 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 10383 tests, 957996 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1152 file(s)
```

Import took 10.413 seconds, the suite 1288.354 seconds and the analyzer
234.606 seconds. The invocation, source hashes, raw logs and analyzer JSON
are retained beside this file. Reproduce from the desired checkout root with
`../checkpoint-499bfd73/reproduce.py` (resolved relative to this evidence
directory), passing a fresh output directory; that script records the actual
HEAD and does not relabel later source as this checkpoint.

This adds actual World Locations, immutable connector assembly grouping,
natural surface anchors and their reconciled logical storage census to the
earlier accepted499bfd73 checkpoint. It is headless component evidence, not
playable entrance, worker motion, save/resume, 720p or256-resident acceptance.

## Specification report mismatch, retained as a failure

The separate Specification checks at this exact source ran35 commands (the34
workflow commands plus the9-case memory-ledger regression). Two commands
failed: capacity sidecar `--check` and its190-case regression. The reviewed
SpaceOwner implementation changed its source hash and one recorded resize
line, but the generated capacity JSON still named the old source. Both stale
values are corrected separately in own commit`daf5ab65`; no capacity, schema,
arithmetic, source implementation or gate was changed by that correction.
The rejected checks remain under `specification-contracts/` and are not
retroactively called passing.

[Remote run37152867094](https://github.com/gradybre/redwall-rts/actions/runs/37152867094)
likewise passed all eight suite shards and all four Godot gates, while
Specification failed on the stale capacity report. The aggregate correctly
failed. Its failure log is retained here. Later corrected checks must identify
their own exact source. No all-gates CI pass is claimed forcc2ffbac.
