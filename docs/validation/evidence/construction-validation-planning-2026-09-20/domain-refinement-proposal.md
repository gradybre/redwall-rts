# Construction local-domain refinement — proposal for the next owner contract

September 20 continuation. This is a source-derived proposal, not an accepted implementation contract or runtime validator. It follows the existing component validation family and does not change Construction, its wire format, delivery ownership or gameplay.

The current 16-field owner image is 4,893,696 value bytes across 82,944 rows. Its material ledger lives outside this image. The Buildings borrowed-view pattern is appropriate for avoiding a second full image, but Construction needs its own allocation discriminator before acceptance. Pure local validation must not instantiate Construction, Buildings, Directory, Inventory or mutable definitions.

## Proposed row domains

All rows first require Boolean present/paused/work_begun flags, structural reference pairs, finite purpose/phase/refund ordinals and scalar range checks. Directory self/subject pairs use Directory capacity; material-container pairs use their own namespace and allow the full nonnegative signed-i32 slot range locally. Saved Inventory capacity, liveness, exact subject kind, Directory identity, subject uniqueness and reciprocal Building.construction bindings belong to the same-file binding pass.

Inactive rows are a union of the exact never-used image and retained terminal history. Both have null self/subject/container pairs, zero assigned/remaining/paused/work_begun. Never-used rows additionally have max_workers=0, purpose=BUILD, type_id=-1, phase=AWAITING, refund=FULL. Retired rows retain source-derived max_workers, a valid purpose/type pair, and phase WORK_DONE or REFUNDING. A retired WORK_DONE non-demolition has PARTIAL refund; a retired REFUNDING non-demolition can retain FULL or PARTIAL. Retired demolition retains DEMOLITION policy in either terminal phase. Do not recompute retired policy from the cleared work_begun flag.

Present rows have nonnull self and subject structural refs, optional material container, valid purpose/type pair and max_workers derived from the immutable definition (furniture uses MAX_BUILDERS). assigned_count is 0..max_workers; paused or REFUNDING requires zero. An unpaused AWAITING, READY or WORK_DONE row can retain assigned workers: the public setter permits it and the existing public probe observes it.

Let W be declared work for the selected purpose/type: base building work, furniture work, authored upgrade work, or floor(base building work/4) for demolition. All current W values are positive; source metadata must validate the facts before indexing. Live local phase relations are:

| Phase | work_begun | remaining_mwu | Additional local condition |
|---|---:|---|---|
| AWAITING | 0 | W | Delivery bill has at least one line |
| READY | 0 | W | None; delivery completeness is checked against the separate ledger later |
| WORKING | 1 | 1..W | Initial WORKING can retain the full W |
| WORK_DONE | 1 | 0 | Completion may be waiting on another owner |
| REFUNDING | 0 or 1 | W when 0; 0..W when 1 | Retains pause and progress; assigned_count=0 |

Live refund policy is DEMOLITION for every demolition phase, otherwise FULL when work_begun=0 and PARTIAL when work_begun=1. A missing or stale subject cannot be normalized away by this pass; cross-file identity validation refuses incompatible files later. The validator does not certify that a live runtime mutation is still able to complete against a stale subject.

Demolition and dirt_path build have no delivery bill and cannot be AWAITING. Other base builds, furniture and the four authored upgrades have nonempty bills. Do not infer READY ledger contents inside the owner-only image, or silently treat absent delivered_milli as zero.

## Evidence and remaining checks

These relations are derived from clear, _write_row, deliver_material, begin_work, add_work_mwu, begin_refund, commit_completion, close_refund and _retire. The existing three public probes cover worker assignment outside WORKING, paused/refunding history, no-material READY, capped final work and demolition cancellation before work. They do not inspect private retired columns. Final tests should decode the documented public state_bytes image or use a reviewed read-only capture API to observe retained terminal fields, with an independent offset table; no private mutable accessor should be added merely for tests.

Source pinning must cover compiled catalog membership and ordinals, enum/capacity/reference constants, all fact row types and named indexes used, upgrade package membership/work, and the distinction between empty/nonempty delivery bills. Validate metadata safely before typed assignment and source-derived array indexing. Historical Buildings metadata counterfactuals demonstrate why compile errors cannot count as semantic refusals.

Keep same-file identity/subject uniqueness in the binding pass, implemented with bounded Directory-derived identity tables or an explicitly budgeted sorting strategy. No quadratic scan over 82,944 rows and no unbudgeted full packed copy. Local metadata and row rejection must preserve the caller's input, and bridge projection must be independently shown to cover all 16 fields.

The unresolved tier-2 demolition economic basis is not answered by this validator; it records current declared base-building work behavior without claiming that broader gameplay design is complete. The subsequent accepted contract needs an exact refusal order, named codes, complete counterexample table, immutable fact review, memory arithmetic, independent source review and actual CI evidence.

## Stream allowance cross-check

`memory-arithmetic.json` recomputes all 16 field sizes against the unchanged source schema. The 4,893,696-byte caller image plus two 663,552-byte field allowances and three 65,536-byte windows totals exactly 6,417,408 bytes, the existing stream allowance. There is zero logical slack in that formula. A second default owner image alone would bring the pair to 9,787,392 bytes. This reinforces the borrowed-view requirement; it does not measure native overhead or authorize a larger budget. The eventual adapter still needs its own actual allocation discriminator.
