# Rejected CI at cddc4412 and exact capacity-sidecar repair

[Run37196812223](https://github.com/gradybre/redwall-rts/actions/runs/37196812223)
tested `cddc4412e3d829ec3193b2aaa3a5c7e257bcdfe5`.
All8 shard artifacts are retained, including the two failed shards. Their383
observed suite files are unique. Combined results:

```text
10833 test(s), 996002 assertion(s), 11 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
0 GDScript warning(s) in 0 of 1201 file(s)
```

Six passing shards emitted zero raw diagnostics/leaks. Shards3 and5 stopped on
three demo-pack and eight Mole-profile failures before the raw guard. All eleven
retain the current-consumer source-drift refusal. There is no aggregate pass or
same-head full-run equivalence claim. The live source publication still needs
the reviewed current consumers and native replay under Decision1137.

The Specification job separately refused one stale source fingerprint in
`registry_capacity_audit.json`: the reviewed1136 ModularProjects START publication
changed its source. The unchanged generator was rerun, and `registry-delta.json`
records the sole old/new fingerprint. Every capacity, census, canonical registry
and other audit fact is byte-equivalent. The regenerated check passes, as do
`190 check(s), 0 failure(s)`. No source parser or limit was changed.

Large raw logs are losslessly stored as `.log.gz`. `compressed-evidence.json`
records both byte counts and hashes; every compressed stream was round-trip
checked. Decompress to the original recorded name when replaying evidence tools.
