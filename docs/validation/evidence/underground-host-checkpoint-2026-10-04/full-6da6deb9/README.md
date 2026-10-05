# Full checkpoint6da6deb9

Exact commit `6da6deb952ebfce5d748563c1c1166f0f6b15dd3` passed the original no-argument suite in a frozen owned worktree. The tracked `../reproduce.py` parked demo assets if present, deleted `godot/.godot`, ran clean editor import, then `./tools/run_tests.sh`, then `python3 tools/gdscript_warnings.py --max 0 --port 6199`. Actual commands, timings and isolated user-directory setup are in `invocation.json`. Source and HEAD were unchanged; project and asset presence were restored.

```text
11156 test(s), 1026365 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1243 file(s)
```

The suite took 1899.36seconds; analyzer took 303.561seconds. The analyzer recovered automatically from an editor connection reset; its complete1243-file result is retained. Lossless logs and decoded/compressed SHA256 values are in `log-archives.json`.

Compared with same-commit CI37251846477, both execute exactly the same402 files and11,156 named test cases, each once, with identical failure, expected/tolerated/unexpected diagnostic and leak totals. CI completes all14 jobs in884seconds. Local assertions exceed CI by10 (1,026,365 versus1,026,355); the cause remains unattributed because the no-argument runner does not emit per-suite assertion counts. No all-counter equivalence is claimed, and the existing strict baseline aggregator is unchanged. `comparison.json` retains both exact results. This checkpoint does not qualify later1161/1165/1163 runtime changes or the full playable workflow.
