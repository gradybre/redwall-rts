# Loaded gait independent source review — first pass

Read-only subject: `/Users/brendan/Developer/redwall-rts-codex-ug-haul-handling`,
base `9a36f68b170e6f31cac28fc48913ef4fe436520d`. The five additive Python files
are named in the subject's `loaded-gait-review-v1/source-sha256.json`.
The earlier accepted static and four-phase source was used as a dependency,
not re-reviewed as new code.

This pass has one **MEDIUM** blocking loader-capacity finding. The remaining
new source proof has no additional high/medium finding. Acceptance awaits the
bounded loader correction; the valid frozen candidate geometry is unaffected.

## Reproduced finding

`prove_loaded_gait.py:24–32` checks archive disk size, then retrieves both NumPy
arrays before checking dtype, shape and the 256-key limit. A 5,259-byte compressed
archive passes the 312,320-byte file gate and materializes a 4,096-key matrices
array of 4,915,200 bytes plus a 16,384-byte grounding array before finally
refusing `HAUL_GAIT_KEYS`. Arbitrarily larger declared/decompressed arrays are
not bounded by the on-disk check.

`loader-capacity-probe.json` records the actual array retrievals. The probe
wraps `NpzFile.__getitem__` without changing its behavior and uses only a fresh
temporary input. `loader_capacity_probe.py` reproduces it. The correction must
validate bounded ZIP member and NPY header/dtype/shape facts before array
materialization; checking only compressed byte count or checking shapes after
allocation is insufficient. Both compressed excess keys and an oversized
declared shape need negative tests.

## Independent verification

- All 32 subject input hashes and all 40 replay output hashes matched before
  and after the review. Exact manifest and invocation hashes are in
  `pin-and-proof-audit.json`.
- All 15 frozen tests passed independently in 70.407 seconds. `invocation.json`
  records the exact executable, arguments, own-worktree cwd, input pins and log
  hash. Python `-B` was used. No source, cache, project or output was written in
  the author's worktree; no Godot/native process was run.
- The four clips cover 1 + 64 + 218 + 64 = 347 rendered intervals, including
  the actual penultimate-to-first loop wrap. Every original gait key remains;
  the rejected original unsupported foot-transfer interval still refuses.
- Rational plane-distance polynomials have degree at most three. The retained
  hand-edge intersection has a strictly positive denominator across the
  closed interval, and the triangle-interior numerators have degree at most
  seven. Exact Bernstein subdivision proves all signs or refuses; positive
  endpoints alone cannot grant contact. The executed counterexamples include
  interior contact loss, rotating-stock degeneracy and proof exhaustion.
- Every body/stock vertex is included in the affine floor checks; a shared
  actual sole vertex remains in the accepted vertical floor cell throughout
  each interval. Complete foot bounds are emitted separately. Every non-grip
  triangle participates in the conservative interval envelopes. The current
  accepted geometry separates at that broad phase; the executable between-key
  stock/body crossing exercises the refusing narrow proof.
- Full 10,209 body and 768 stock triangles remain, with 9,283 non-grip body
  triangles and only the previously accepted 478/448 hand groups excluded from
  stock separation. This does not prove arbitrary body self-collision or a
  finite-world footing/obstacle configuration.

This is offline source geometry only. Native numerical bounds, loaded turns,
world-root progression, rate adoption, interrupted movement/repost, runtime
source publication and joint runtime memory remain outside this review.
