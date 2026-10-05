# Independent focused Room integration check

The frozen checkpoint is `8003bfe155092e9a8bc8b5590228e6069b859173`, containing
the accepted 1161, 1163, 1165 and 1166 components. This evidence-only worktree
was created on `codex/underground-room-integration-check` from freshly fetched
`origin/master` at `82d60ba86dcecf6e7c6184eeaf77a389e8b2b5c2`, then fast-forwarded
to the checkpoint. No runtime source, registry or queue was edited.

## Exact-checkpoint result: refused

`checkpoint-1` invokes the existing root `verify_profile_integration.py`
unchanged. It removes the local cache, parks/restores demo assets, performs a
clean import and uses the official strict singleton runner with every gate
enabled. The permanent state registry passed: 153 modules, 730 rows and 1,055
packed columns. Clean import had no raw diagnostics.

The first requested suite, RoomComposition, failed: **16 tests, 102 assertions,
16 failures**. Its earliest refusal was `MOLE_CATALOG_SOURCE_DRIFT` during the
actual Host foundation mount. The fixture then dereferenced the absent Session,
producing **24 raw `SCRIPT ERROR` lines**. The ordinary diagnostic footer lists
zero unexpected/expected/tolerated diagnostics and zero leaks; this does not
erase the separately retained raw script errors or failed tests.

`consumer-source-mismatch.json` correlates the real runtime refusal with the
exact published pins. WorkFace, Routes and WorldRoutes differ after accepted
1161; the other six published consumer pins match. The guard correctly stays
closed. No historical consumer was restored, no source fingerprint was changed,
and no Catalog guard was bypassed.

The root runner stopped at the first failed suite. The remaining Session,
Host, Retirement, RoomCatalog and ConnectorCatalog suites and the planned
23-file analyzer were **not attempted**. Root confirmed that dependent attempts
should stop until the current consumer publication is renewed. Earlier accepted
component tests are not reported as passes from this failed integrated run.

## Reproduction and restoration

```sh
python3 -B docs/validation/evidence/underground-room-integration-check-2026-10-05/reproduce.py \
  --out docs/validation/evidence/underground-room-integration-check-2026-10-05/replay
```

The wrapper requires the exact checkpoint. It retains the original root runner
bytes, complete source/content pins, commands, logs and both invocation reports.
It also records the intended analyzer file set and verifies original project,
registry, import sidecars, assets, source bytes and HEAD after cleanup. Every
restoration check passed; the worktree has evidence changes only. The fixed
root-runner user directory was used exclusively for this bounded run and is now
released. No Godot or analyzer process remains active in this worktree.

This is an honest failed integration checkpoint, not runtime, native-memory,
clearance or playable acceptance.

## Separate shared-memory tool review

`memory-review-1` retains the independent projection/lifetime review, complete
budget replay and reproduced MEDIUM missing-Movement-closure finding.
`memory-review-2` accepts the corrected source checker after all 11 focused
tests and the exact original scratch mutant refuse before producer execution.
The complete no-Git budget replay changes only source provenance; the declared
total remains 99,999,806 bytes with 194 bytes of headroom and runtime/native
qualification false. This accounting acceptance does not change the failed
runtime checkpoint above.
