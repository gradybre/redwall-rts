# Integrated remote CI at 1f5b1e4d

[Run 37154863566](https://github.com/gradybre/redwall-rts/actions/runs/37154863566)
completed successfully at exact source `1f5b1e4dccc3b707c52a2c00144a9f06557a4021`. All eight suite
shards, all four Godot gate jobs, Specification contracts and the final required
aggregate passed. Earliest job start to final aggregate completion was
9 minutes 26 seconds; the slowest suite process took428 seconds.
This measures this GitHub run, not local or target-hardware game performance.

The aggregate verified:

```text
ok: 360 suite files executed exactly once across 8 shards
10387 test(s), 958137 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1156 file(s)
```

The test/diagnostic total lines above are formatted from the retained aggregate
JSON; each raw shard additionally reports zero unexpected raw-log errors and
warnings and zero leaked objects/resources. `run.log.gz` contains the actual
workflow log, `run.json` its job/step outcomes and exact head, and `aggregate.json`
the original verifier result. The machine field `baseline_matches: false`
means no single-run baseline was supplied to this invocation; it is not a
reported comparison failure. See `tools/ci_test_shards.py`'s return expression.

The prior local no-argument full suite was at `cc2ffbac`:10383 tests and957996
assertions. This later source adds four exact-WORK-profile tests and141
assertions. Matching272 expected and353 tolerated diagnostics are observed,
but a same-source full-versus-shard comparison for this head was not run. The
next coherent integrated source checkpoint must again use the clean-assets,
delete-cache, editor-import, no-argument full-suite and zero-warning analyzer
procedure. This successful remote result does not certify playable stairs,
composed persistence, native720p end-to-end acceptance or256-resident runtime.
