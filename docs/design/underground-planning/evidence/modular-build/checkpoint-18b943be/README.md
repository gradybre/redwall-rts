# Full frozen checkpoint 18b943be

Source: `18b943be79e034e62103dd7deb9e7d7003123fd8` on the isolated
`codex/underground-modular-integration` branch. The invocation and SHA256 manifest
pin the exact candidate; source and HEAD remained unchanged throughout.

The demo assets were already absent. Only this worktree's `.godot` was removed,
then `godot --headless --path godot --editor --quit` completed in 3.663 seconds.
The full no-argument `./tools/run_tests.sh` followed. Original asset state was
preserved. Suite duration: 1234.278 seconds.

```text
9995 test(s), 708261 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 9995 tests, 708261 assertions, 0 failures.
```

The full analyzer command was
`python3 tools/gdscript_warnings.py --max 0 --port 6196`, with the JSON output
retained here. It completed in 228.266 seconds:

```text
0 GDScript warning(s) in 0 of 1109 file(s)
```

This checkpoint includes mixed-height terrain exclusions, the finite world-bound
level catalog, the actual Routes owner, prepared route observations, exact Room
section metadata, the atomic room furniture coordinator and its physical bridge,
and matrix actor grounding. Those additions are covered together by this run.

It predates the concrete WorldRoutes provider, exact phase-mask provider, connector
catalog and later native pose qualification. Their later focused results must not
be attributed to this run. The player continues to paint directly on dirt at the
selected depth; a separate blueprint drawing canvas is not the interaction.

The complete playable room workflow, installed and separately paid connectors,
qualified productive contacts, composed save/load, 1280x720 demo interaction and
256-resident runtime qualification remain open. Passing component and regression
tests does not establish those outstanding requirements.
