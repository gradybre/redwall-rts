# Complete carry handoff source proof — review candidate

This is an offline source-intersection proof for the exact finite program in the independently reviewed mole presentation driver. It admits no worker, route, stance, tool claim, or work credit; production-qualified profiles remain **0**.

The frozen `prove_state_handoffs.py` and its eight adversarial tests use the accepted actual firm-grip idle/walk image. The program has 155 handoffs: ready idle frame 8 to the frozen walk-start pose, every real idle interval to ready, and every real walk interval to ready. Loop closing edges use the exact penultimate-to-first rule emitted by ActorContent. A new request cannot interrupt an unfinished fade. Down/high entry and recovery source proofs remain separate; this report does not silently extend them to other headings.

The check exhausts 9,761 non-grip body triangles against 1,150 complete pick triangles with a shared positive source-pose simplex. The 448 intentionally gripping palm triangles are excluded only from the tool/body self-intersection check, never from physical body bounds. Exact integer separating projections and conservative barycentric subdivision cover interpolation interiors. Failed separation, depth exhaustion, malformed bounds, and a 16,000,000-check ceiling refuse. No sampled noncollision is treated as proof.

Native world-coordinate error is mapped conservatively back to the local source frame by inspecting every one of the 65,536 exact finite WorldBasis coefficients, including nonunit norm. The same convex combination multiplies the shared body/tool origin, so subtracting it preserves the intersection question. Per-triangle error intervals remain conservative after that subtraction. Reported physical boxes still use the source-local frame.

Actual result: **155 handoffs, 7,962,301 separating checks, 0 unresolved pairs**. The included Python log reports **8 tests, OK**. No duplicate engine/native run was required for this new offline proof; the source driver itself has separate strict/native obligations. All executed producers, the actual driver, source image and WorldBasis digest are pinned in the report and checked before/after execution.

Reproduce from the worktree root with the exact local NumPy-enabled interpreter used for this run (the ordinary `python3` does not have NumPy installed here):

```sh
/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 godot/data/underground/mole-worker/evidence/contact-qualification/test_state_handoffs.py
/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 godot/data/underground/mole-worker/evidence/contact-qualification/prove_state_handoffs.py godot/data/underground/mole-worker/evidence/contact-qualification/analysis-carry-arm-v7 /a/new/output.json --fixed-ready
```

The existing output is create-only. Raw/source/import inputs are validated, and an unavailable or drifted input refuses. The earlier broad all-pose hull and 2M/16M capacity refusals remain retained in the adjacent `state-handoff-*` directories. The accepted finite program deliberately proves only the handoffs it emits. A prior v5 attempt ran while the isolated clean-test wrapper had moved this worktree’s assets and refused for missing input; it is not counted as successful evidence. The source-identical v6 was run after restoration.

Independent root review accepted the exact source/test/report pins and independently reran the eight small adversarial tests (8 tests, OK). No high/medium finding remained.

Remaining gates: actual complete-state native driver exercise, immutable Profile/source-role binding, actual stance/target/approach proof, and whole presentation peak admission. No gameplay permission follows from this result.
