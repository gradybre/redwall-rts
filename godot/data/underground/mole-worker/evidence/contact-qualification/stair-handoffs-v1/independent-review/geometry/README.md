# Independent ADR1142 source review

Date: 2026-10-04. Reviewer: Geometry lane. Result: **accepted for the frozen offline source/proof scope**. No critical, high or medium finding remains. This review grants no runtime, native-renderer, paid-world, pace or memory qualification.

The reviewed worktree was `/Users/brendan/Developer/redwall-rts-codex-ug-space`, branch `codex/underground-stair-handoff`, tracked HEAD `606f2b8636677ef15ac5a863ae2b39d81dc87286`. No file in that worktree was edited and no engine/native command was run. All independent outputs in this directory were produced from the Geometry lane's separate haul worktree.

## Exact reviewed source

Paths below are relative to `godot/data/underground/mole-worker/evidence/contact-qualification/`.

| Source | SHA256 |
| --- | --- |
| `author_stair_handoffs.py` | `d9a711690e2da698adef2eabb6354e6dbc552fc6e2454b5055d9533c636adbda` |
| `prove_stair_handoffs.py` | `72e07b93d40b6d8fe6b0738f85bce35c7a6d5fe5cc932dbcf3324547cf5caf78` |
| `stair-handoffs-v1/diagnose_refusals.py` | `c42e11d948931cb062904f11c7f788f00d21c0cc00d73f2c411939bfb0927a95` |
| `stair-handoffs-v1/summarize_program.py` | `bfaaa3014e7958d9ad60688137e1f69222044b66aa0617838dbc92d01d2e8c36` |
| `test_stair_handoff_proof.py` | `3e2a31ed5ac60ac4f3c52b7938eccc94ff34134b5c19ad0e442b18aa471fb6fd` |
| `test_stair_handoffs.py` | `d2a7a8e72a688b172c6935b5e77a99ddfeec7717d9b85d40b4c01d92df7e31e2` |

The source manifest is `c9d5a97579bb0b5867082ff2b96db707532cd8d62cb6c4472347c24680f1b925`. All 6 source, 41 output, 93 history and 212 inherited manifest entries were independently rehashed before and after the replay, with no mismatch. Full observations are in `manifests-before.json` and `manifests-after.json`.

## Source and proof conclusions

The review read all six new source files, the ADR and packet documentation, and the inherited source reconstruction, anatomical-foot, exact sole-height/contact, projection, local/native error and common-heading simplex functions actually used by the new proof.

`author_stair_handoffs.py:36` preserves the complete nonloop Q16 range and exact terminal final/final/share0 pair. Its root is signed componentwise ceil in the fixed program frame; the separately interpolated integer heading selects the actual finite native Basis row. `program_points` at line 80 rotates the local geometry and adds the fixed root once. The normalized rotation at line 71 is limited to joint authoring. Ready endpoint palettes and grounding remain exact, and the original link/mesh/weight/material inputs remain pinned.

`prove_stair_handoffs.py:59` encloses each partial phase interval using outward local interpolation, every native heading row between its integer endpoint headings, and monotonic signed-ceil root bounds. It does not substitute a line between rotated world endpoints. Exact integer projection establishes separation; midpoint subdivision cannot turn unresolved overlap into permission after the depth/work limit.

The sole exception remains narrowly valid: constant root Y is required at line 35; at lines 174–184 the complete source Y is proved above the support plane, with exact rational fallback for a rounding-straddled vertex. At lines 200–204 only complete anatomical foot triangles on the exact designated support prism can take the projection/contact branch. The separately required full-foot projection and one identical continuous contact vertex cover every interval. No true below-plane source penetration is excused by the inherited numerical residual. Mixed foot triangles remain complete; every body triangle remains in the terrain pass.

The tool/body proof at line 221 uses one common heading/root for both bodies, pulls the complete native uncertainty back through the finite inverse-heading bound, and proves conservative common-pose hulls. Chunk boundaries overlap and their edge census exactly covers all intervals. Only the established 448 intentional palm triangles are omitted from that self-contact pass; they remain in the terrain proof. This does not claim general limb-versus-limb clearance.

The complete recorded primitive/interval census was independently validated for all three motions: 10,209 body/clothing and 1,150 tool triangles against 22 positive fixture prisms, across 90 approach, 270 turn/reposition and 90 retreat intervals. The four joins compare exact root, heading and complete palette/grounding digest to the accepted gait endpoints. Terminal heading remains 32768; no reset or closed-loop route is inferred. Earlier exact fixture quarter-turn proof remains distinct from native-yaw gait qualification.

## Independent execution

`replay.py` uses the pinned NumPy interpreter with `-B`, checks all manifests, runs the 8 source and 13 proof/census tests, independently reconstructs and proves the actual turn in both proof modes, then reconstructs the column/join proposal. Both small suites passed.

| Independent replay | Checks | Exact output SHA256 |
| --- | ---: | --- |
| Actual turn terrain/support, 270 intervals | 3,048 | `6603ca9bc3f7b2755ac8fc299622155dd073973e5fa0f376e2964b403163578e` |
| Actual turn tool/non-palm, 270 intervals | 1,566 | `edf869a55ec967d6dc0af5c727d8ec488a41b962179ad52e5cd24cd88cd83d15` |
| Column proposal and all four source joins | — | `34a62009ebefa9055444353a900abb24b5a225f10ee91dd81899292fe597177f` |

Each of those files is byte-for-byte identical to the retained author's result. Invocation records and raw logs are preserved here. The approach and retreat proof results were source-reviewed and their complete censuses validated, not independently rerun. Their retained checks are 869/522 and 874/522 respectively, yielding 4,791 terrain/support and 2,610 tool/non-palm checks over all 450 intervals.

`history_audit.py` independently compares candidate 5 and 6's actual decoded F32 matrices and grounding, verifies the original overreach, validates the three rejected collision runs against their retained executable snapshots and exact source images, and checks the final complete primitive/interval and storage census. It also confirms the sampled rejected toe polygon has an interior point, while retaining its explicit sample-only status. The first reviewer harness assumed all old invocation records used `source_before`; the first two instead use `source_sha256`. That review-harness failure is preserved in `history-audit-v1-refusal.json` with its script snapshot. The corrected history audit passed; no product result was waived.

The independent column-width sum is 48,548 bytes per numeric bank. Two banks plus 4,096 decode and 176 caller bytes yield 101,368 before native controls. This is an unadopted proposal, not an allocation. It neither absorbs the separate 1139 proposal nor fits current reported headroom. Whole presentation/source replacement lifetimes, shared Basis, native controls and whole-client memory still require their own admission.

## Retained boundaries

No existing runtime consumer, Profiles certificate, gameplay rate, timber recipe, paid part identity or capacity was changed by this source packet or review. Native deformation/visual replay, default Metal numerical closure, actual paid support and obstacle identity, authoritative phase/pace/save/cancel/retreat handling, reviewed arena reuse and complete runtime performance remain open. The accepted offline result may support the separately authorized additive native harness; it does not make that harness or an actual stair route qualified.
