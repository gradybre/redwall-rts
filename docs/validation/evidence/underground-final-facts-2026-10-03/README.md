# Final actual-source attestation — decision 1100

Frozen three-file source hashes are in `source-sha 256.json`. Final validation
used Godot 4.7.2 on macOS, a fresh `.godot` import, and CI assets-aside conditions
(no staged `godot/demo/assets` directory was present in this isolated checkout).
The strict shell gate remains unchanged; only its external copy's repository
root and entry point select the existing shard runner with three exact suites.
No test, diagnostic or leak allowance was changed.

```
149 test(s), 15296 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 3 file(s)
```

The new suite is 16 tests/944 counted assertions, Owner 88/5024 and Routes 45/9328.
Nested actual-fixture setup/helper failures propagate to the outer tests; their
internal assertion counts are not added to the reported 944. The fixtures use
real identity, source, pose and packed stores, with explicitly synthetic
geometry/profile certificates. This evidence grants no production work,
movement, first-entry or performance qualification.

Parent independently accepted the three frozen source/test hashes. The
`historical/` logs retain the rejected fixture failures and qualified-static
self-class resource leak, plus isolated original-owner and corrected dispatch
probes. The exact final source passed all strict/raw leak gates. All final
source hashes were rechecked after the analyzer before packaging.

Reproduce into a new output directory:

```
python 3 docs/validation/evidence/underground-final-facts-2026-10-03/reproduce.py --out /tmp/ug 1100-reproduction --port 6211
```

Only the caller-created editor/processes are used. The reproducer restores any
parked assets on refusal as well as success. Native allocation headers and
whole-world timing remain unmeasured; the decision records the logical 256-byte
helper-frame ceiling and exact finite-work formula.
