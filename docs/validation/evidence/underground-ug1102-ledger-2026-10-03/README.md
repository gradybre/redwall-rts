# Decision1102 CI ledger reconciliation

Base: `2a5d382c8698a611b223d0d0f3c75d55997082f9`, following the clean Godot
checkpoint at `499bfd737cb25f444f44f581be3cd11e6fe537cd`. Own branch:
`codex/underground-ledger-reconcile`, created from freshly fetched origin/master
and fast-forwarded to the reviewed integration base. Only the arithmetic gate,
printed architecture ledger, decision1102 appendix and this evidence change.

## Failure and correction

[CI run37149792747](https://github.com/gradybre/redwall-rts/actions/runs/37149792747)
failed `Specification contracts / Memory ledger arithmetic` at the exact
Funding packed-byte assertion. `ci-failed-contract.log`, `ci-held-aggregate.log`
and `ci-jobs.json` retain the remote evidence. The aggregate correctly refused
`CONTRACTS_RESULT: failure`; individual shard successes do not establish a
successful aggregate or its exactly-once report audit.

The real fourth loss domain adds256 I64 cells:2048 live bytes plus2048 for
the conservative cold image. No runtime code, canonical data, workflow, capacity
limit or diagnostic threshold changes.

| Current derived quantity | Bytes |
|---|---:|
| Funding26 packed columns at source maxima | 5220352 |
| Funding loss column1024 I64 cells | 8192 |
| Auxiliary payload including the live delta | 39758689 |
| Joint allocation row excluding6144 already counted live growth | 4960341 |
| Current joint mutable/reserved increment | 4966485 |
| Planned allocated payload | 91570642 |
| Live plus existing reserve | 99959250 |
| Headroom below unchanged100000000 limit | 40750 |
| Rejected two-world peak | 185280199 |

Historical1066 and1072 values are preserved. A new1102 trail row adds4096.
The current reported source census remains distinct from those historical
increments. These are logical static bytes, not measured native RAM.

## Verification

Reproduce from the repository root:

```sh
python3 -B docs/validation/evidence/underground-ug1102-ledger-2026-10-03/run_checks.py
```

`checks.json` records all command arguments, exits, durations and log hashes.
All34 Specification contracts commands from the existing workflow pass, plus
the new nine-case stale-census check: **35 command checks,0 failures**.
`ready07_arithmetic.py --output` performs the same assertions as the CI command
and additionally retains `arithmetic.json`; the setting report is likewise
written here instead of CI's temporary directory. No gate is replaced by a
partial or synthetic success test.

Relevant direct summaries:

```text
ready07_arithmetic: PASS;145 field rows;45 allocation rows;131 checked links
merge_gate: PASS -- ledger only,0 problem(s)
test_underground_memory_budget:25 tests,OK
test_registry_capacity_audit: PASS --190 check(s),0 failure(s)
test_component_columns_schema: PASS --58 checks
test_stale_census:9 tests,OK
```

The nine-case test executes the actual arithmetic script unchanged. Only named
input reads are replaced within a child process; repository source and metadata
are never rewritten. Its valid control passes. Three-domain and unaccounted
five-domain source, old schema, internally balanced old loss row, missing cold
image, double live charge, stale headroom and missing final trail each cause
an actual assertion failure. Import errors or absent files cannot count as a
successful refusal.

No engine run or analyzer is repeated for this static-only correction. Parent's
separately retained499bfd73 checkpoint passed10321 tests/956322 assertions,
0 failures, all unexpected strict/raw diagnostics and leaks0, analyzer0/1148.
That does not imply the failed remote Specification contracts run passed.

## Independent review

Parent root independently reviewed all five exact pins in `source-sha256.json`,
the source-derived census, historical trail, printed table and negative-input
harness. All five hashes matched. Root also reran the nine-case harness:9/9
passed. Review accepted the correction with no gate weakening or duplicate
charge found. The reviewed five files stayed unchanged afterward; this review
note is evidence only.
