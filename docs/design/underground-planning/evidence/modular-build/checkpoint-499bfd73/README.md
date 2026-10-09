# Full integration checkpoint — 499bfd73

The frozen source was `499bfd737cb25f444f44f581be3cd11e6fe537cd` on
`codex/underground-modular-integration`. The exact clean CI procedure completed:
park `godot/demo/assets` if present, delete this worktree's `godot/.godot`, run
`godot --headless --path godot --editor --quit`, then the complete no-argument
`./tools/run_tests.sh`, and run `tools/gdscript_warnings.py --max 0`. The wrapper
restored any parked assets in its final cleanup. Assets were absent in this
worktree, and that original state was preserved.

```text
10321 test(s), 956322 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 10321 tests, 956322 assertions, 0 failures.
0 GDScript warning(s) in 0 of 1148 file(s)
```

Import took 9.576 seconds, the complete suite 1292.480 seconds, and the analyzer
226.757 seconds. Source hashes and HEAD remained unchanged throughout; the
[invocation](invocation.json), [source pins](source-sha256.json), full raw logs
and analyzer report retain that evidence. This passes the two corrected Funding
loss-domain regressions from the rejected `60f22f11` checkpoint.

This is local headless/analyzer evidence, not complete playable or native
memory acceptance. Remote run37149792747 separately failed its specification
memory-ledger arithmetic gate and is being corrected; no all-gates CI pass is
claimed. Later World Locations, assembly grouping and SurfaceAnchor work are
outside this frozen source and retain their own focused evidence.

To reproduce on an explicitly selected source checkout, run the copied
`reproduce.py` from that checkout's root with one fresh output-directory argument.
The script records the actual HEAD it tests; it does not mislabel a later
checkout as this checkpoint. It mutates only that chosen checkout's generated
cache and temporarily parked demo assets.
