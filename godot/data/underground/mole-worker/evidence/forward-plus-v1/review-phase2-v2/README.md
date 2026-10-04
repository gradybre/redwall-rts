# Phase-two output-identity correction and final review packet

The original `review-phase2-v1` manifests and README are preserved unchanged.
Root independently reviewed the reader and native witness with no high/medium
finding, then requested a LOW correction: literal output-name comparison could
miss two names for the same file. The native helper now delegates to the exact
pinned existing world-basis producer's canonical/create-only output guard.
Relative `unused-parent/../x` and absolute/user-path aliases refuse before any
write. The accepted Actor.WorldBasis source remains byte-identical.

`historical-locators.json` maps only the three superseded current paths in the
original manifests to exact preserved bytes. All original source/output hashes
still resolve; historical manifests and execution records are not rewritten.
The v1 native helper and v2 reader test are retained as non-executable `.gd.txt`.

`actor-binding-v3` repeats the affected native evidence and exact singleton CI
suite after a clean assets-aside/cache-delete/import. It does not repeat the
unchanged Actor suite: that retained result is21tests/225assertions/0failures.
The new WorldBasis result is:

```text
ok: 12 tests, 246 assertions, 0 failures.
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 3 file(s)
native-forward: 45 assertions, 0 failures; actual Metal pixels and two attachment cycles; qualified=0
native-world: 21 assertions, 0 failures; actual complete source, synthetic meshes; qualified=0
```

All five exact commands, pre/post source hashes, raw logs and executed wrapper
are retained. The wrapper records source/project unchanged, assets/override
restored and no raw diagnostics. The native output preserves the actual
backend distinction and the original two-cycle render/cleanup checks.

The unchanged one-table544768-byte reservation and complete remaining gates
are in `review-phase2-v1/README.md`. This is bounded reader/presentation evidence,
not a Metal numerical-enclosure, production profile, World or paid-workpiece
certificate. Root's narrow correction re-review is pending at these pins.
