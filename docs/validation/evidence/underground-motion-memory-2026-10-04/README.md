# Integrated Motion/Profile/Level memory and strict tests

ADR1143 source reader is integrated with the actual shared registry and memory
checker. The source-counted paired banks, configured Profiles18/194/1, Levels,
single4096B decoder window,176B caller,4096B logical/helper and32768B provisional
native allocation total232,436B within existing262,144B PROFILE_BYTES. They are
not added a second time to the global reservation. Global live plus reserve
remains99,998,782B; headroom1,218B under the unchanged100 MB ceiling.

The shared checker incorporates the independently reviewed source census and
checks current Profile member widths/allocators, Level constants, actual runtime
joint formula and the complete Motion fields/banks/helper/decoder lifetimes.
All205 memory tests and190 registry capacity tests pass; artifacts regenerate
exactly and READY07, registry coverage and merge gates pass. See invocation.json.
The independent review is in the motion-independent-review-2026-10-04 packet.

The integrated clean-assets/cache/import run uses the real shared registry:

```text
15 test(s), 13671 assertion(s), 0 failure(s)
25 test(s), 601 assertion(s), 0 failure(s)
10 test(s), 179 assertion(s), 0 failure(s)
8 test(s), 227 assertion(s), 0 failure(s)
```

Every suite reports these exact diagnostic and leak lines:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Total58 tests/14,678 assertions. integrated-focus retains source fingerprints,
raw logs, strict shard manifests/reports, analyzer JSON and restoration evidence.
Source, project and registry stayed unchanged and demo assets were restored.
Native allocation ceilings remain unmeasured; no actual route, timing activation,
save or256-resident performance qualification follows this source-only checkpoint.
