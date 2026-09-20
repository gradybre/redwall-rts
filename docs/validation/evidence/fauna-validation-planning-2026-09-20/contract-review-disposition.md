# Astra final contract disposition

Accepted: FAUNA-S4-VALIDATE-R01v1 / ADR 0174. The independent final review found no blocker and re-derived the fixed image, byte counts, typed API, metadata arithmetic and 19 required mutation witnesses.

The final contract makes the requested wording explicit: metadata detail identifies the failed owner-count or field comparison; source-sentinel checks happen before column evaluation; the seventeen repository checks are distinguished from owner index 17; no WorldInit or collaborator is constructed; ordinals 0–7 use i32 accessors and ordinal 8 uses an i64 accessor. Most were already specified, and no scope change follows.

One repeated wording error in the review is not adopted: after zone slot and zone generation, six further i32 columns remain, not seven. The review's table, arithmetic and following paragraph are correct. The final contract's nine-row field table is authoritative.

The metadata field-count counterfactual moves Work descriptor 288 to final index 297. It does not grow the 298-entry tables. The first nine fauna fields remain exact; therefore bypassing the owner count guard cannot be masked by a different field guard. Source sentinel faults use canonical fixture values -1/0 and must be rejected before the predicate evaluates a changed sentinel.

The existing public generation test remains in the full suite. New focused tests check the shared reader, every reserved field and row, actual section 1 diagnostics and publication state, and all frame paths. No private snapshot is invented. Existing IntMath/SaveCodec self-preloads remain recorded; only the new bridge must avoid a new cycle, and actual import is mandatory.

Ordinary settlement-scope implementation is authorized. Combined WorldInit section 1/4 restoration and complete save publication remain separate.
