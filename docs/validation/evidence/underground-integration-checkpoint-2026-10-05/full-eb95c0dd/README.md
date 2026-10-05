# Full local checkpoint eb95c0dd

The frozen owned qualification branch at `eb95c0dd418d97719a1772790265ae7d834b0291`
passes the exact clean-assets/cache/import, no-argument `./tools/run_tests.sh`,
all-file `tools/gdscript_warnings.py --max 0`, decision, memory and registry checks.
`invocation.json` records commands and timings. This checkout had no demo assets;
the wrapper retained/restored the original project, every source, HEAD and prior
import sidecars. All restoration checks pass; the checkout is tracked-clean.

```text
11283 test(s), 1082447 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1264 file(s)
```

The full suite took1,936.692 seconds. Raw import and analyzer editor findings
are empty. Every discovered file ran exactly once:410 files and11,283 named
cases. The same-commit eight-shard CI ran the identical cases and diagnostic
counts, with1,082,436 assertions. Local has11 more assertions, unattributed;
`comparison.json` records this explicitly. The all-counter comparator is not
relaxed, and exact assertion parity is not claimed. CI passed all14 jobs in
14m30s; see the adjacent `ci-eb95c0dd` evidence.

This checkpoint precedes ADR1187/1188 source publication and ongoing1178/1183/
1184 runtime integration. It does not qualify the first playable Kitchen,
save/resume, the full connector catalog or target-hardware performance.
