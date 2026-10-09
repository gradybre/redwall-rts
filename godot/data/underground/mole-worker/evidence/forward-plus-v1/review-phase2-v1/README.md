# Phase-two WorldBasis and native binding review

Decision1132. Frozen diff against6d1495f1 changes only Actor.WorldBasis and its
leased test, adds native_forward_actor.gd/UID and this evidence. All bytes from
Actor.Palette onward are unchanged. No pose/root equation, profile flag,
current source catalog, World permission or actor resource ownership changes.

The loader pairs UGYAW001/schema1/desktop GL with UGYEND01 and
UGYAW002/schema2/Metal4.0/macOS/Forward+ with UGYEND02. The old v1 format keeps
its prior optional-schema compatibility but explicit conflicting schemas
refuse. V2 checks its full coefficient provenance/orientation fields; actual
producer and same-stream digest stay mandatory. Refreshing a corrupt file's
expected hash cannot admit crossed headers, footers, metadata or backends.
Neither a legacy stream nor the identical coefficient payload binds to a
foreign actual renderer. A refused source clears candidate rows and preserves
caller scratch and original file bytes. Only one immutable524288-byte numeric
bank exists; RESERVED_BYTES stays544768, no new retained fields. Local wire
selection and a bounded temporary metadata comparison are cold operations
inside the existing stream/control allowance; native allocation peak remains
unqualified, not newly measured by a global prior peak.

## Evidence

actor-binding-v1 ran clean assets-aside import, unchanged strict CI singleton
WorldBasis10tests/225assertions and Actor21tests/225assertions, plus LSP0/3.
It then ran the actual default Metal4.0 Forward+ witness and unchanged OpenGL
world-equation witness. All commands and raw diagnostics/leaks passed; source,
project, assets and override restoration are recorded true. The source hashes
and exact executed wrapper are retained. The earlier test source is preserved
as non-executable .gd.txt rather than relabelled as the later expanded test.

actor-binding-v2 adds two independent backend relabels whose schema/footer still
match, plus explicit valid schema1, and makes the headless assertion explicitly
headless-only. It repeats clean import, both strict singleton suites and LSP0/3.
The final WorldBasis result is11tests/241assertions and Actor21tests/225assertions,
zero failures, and both final suites report:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The actual Actor/native helper stayed byte-identical between these runs, so the
native witness was not repeated for a test-only change. Native Metal reports
45total assertions/0failures; its JSON records43observations before the two
report-write assertions. The legacy GL witness has21assertions/0failures.
Synthetic half-sum skin weights distinguish correct post-skin grounding from
an incorrectly bone-weighted translation. Both actual body/held pixels move32
pixels for the exact half-metre root/grounding change, mirror under the real
heading table, and are unaffected by a transformed parent. Exit retires every
mesh/native attachment; re-entry with the same shared table renders both parts
again. Metal green body centroid/count are(74,496); the static blue part is
(180.6667,2016). Actual stale World, heading and malformed pose updates refuse
without altering either native part. No numerical all-source enclosure follows
from these synthetic pixels.

The complete source table is the exact accepted phase-one file and producer;
legacy GL uses its unchanged old file and digest. The GL table is released
before the Metal table is loaded in this witness, preserving the one-table
lifetime. The raw allocator observation records live_before148917988 and
live_after149442440, but its global preexisting peak244623287 is explicitly not
an isolated loading peak. No full-client or simulation memory claim is made.

## Reproduction and remaining gates

Run each retained executed-runner.py.txt from the own repository worktree with
new output paths. It uses ./tools/run_tests.sh --shard through the current real
ci_test_shards singleton plan, removes own cache, temporarily moves own assets
outside Godot, isolates user:// with a temporary override, and restores all
inputs in finally. The historical exact shard plan and raw footer are pinned.
No no-argument full-suite result is claimed here.

This is source-reader and native presentation evidence only. Independent
source review is pending. Complete Metal input/decode/skin/model residuals,
arbitrary fast-math transformation closure, whole-source continuous body/tool
role enclosure, immutable current publication and actual World/paid-workpiece
qualification remain separate. The already accepted OpenGL publication stays
unchanged and will refuse current source drift.
