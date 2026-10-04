# Integrated checkpoint at 32db348a — 2026-10-04

Exact source `32db348a1a8473461f832cc2b06b410aa97c898a` passed the required
clean-assets/cache/import/no-argument full suite and full zero-warning analyzer.
`invocation.json` records 11.425 seconds import, 1,674.906 seconds full suite and
255.521 seconds analyzer; source and HEAD stayed unchanged, and the original
absent-assets state was restored.

```text
10895 test(s), 998370 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1210 file(s)
```

All 34 Specification commands from the pinned workflow also pass in
`specification/`. The independently reviewed source-catalog regression and 1141
guarded hauling are included; no diagnostics, leak or analyzer gate changed.

[Remote CI37208054867](https://github.com/gradybre/redwall-rts/actions/runs/37208054867)
passed all 14 jobs in 11 minutes 34 seconds. The retained
[CI packet](../../../../../validation/evidence/underground-ci-32db348a-2026-10-04/README.md)
proves all 388 suite files exactly once across 8 shards. The same 10,895 passed
test-case names and every diagnostic/leak total match this full run. Remote
assertions 998,359 differ from local 998,370 by 11; the strict all-counter
comparison refuses equality and remains unchanged. No per-suite local assertion
counters exist in the ordinary no-argument log, so the difference is explicitly
unattributed.

This is a component regression checkpoint. Later 1140 Delivery and 1142 source
handoffs are not in this frozen run. Playable Kitchen, actual handling and
stair activation, composed saves, full visual/input acceptance and 256-resident
qualification remain open. The 100 MB limit and wood-only stair policy remain
unchanged.
