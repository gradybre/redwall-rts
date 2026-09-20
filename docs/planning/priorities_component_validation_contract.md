# Priorities component validation — PRIORITIES-S4-VALIDATE-R01 v1

Date:2026-09-20. Accepted by Astra after independent feasibility and final contract reviews; ordinary settlement-scope authoring is authorized. Scope is the owner11 argument-only predicate and framed bridge; no owner capture/apply or complete world validity.

## Source-backed domain

SET-AMEND-001 fixes JobKind index3 at0 with a physical12-kind stride. GDD REQ-SET-026 accepts priorities0..4; policy flags are boolean. Current clear/despawn zero every byte of an inactive row. Current public spawn accepts all512 physical rows; this owner cannot identify living residents and must not impose the separate256living cap. A present row need not have spawn-default priorities or flags.

Owner11 metadata is keypriorities, version1, primary512, zero child extents, four fields: ordinal0 _present u8/512; ordinal1 _job_priority u8/6144; ordinal2 _auto_fallback u8/512; ordinal3 _dangerous_work u8/512. No schema, field, owner version or canonical-state change.

## Single predicate

Add to priorities.gd:

`static func columns_refusal(present: PackedByteArray, job_priority: PackedByteArray, auto_fallback: PackedByteArray, dangerous_work: PackedByteArray) -> StringName`

The four arguments are explicit typed packed columns in canonical order. There is no live owner, Columns constructor, default buffer, diagnostic write or new publication Array. Later bulk restore must reuse this exact predicate. No existing lifecycle/mutator behavior changes.

Exact first-refusal order:
1. Any extent wrong, including empty: REFUSE_COLUMN_SHAPE / COLUMN_SHAPE. Check all four before domain/index reads.
2. present not0..1: REFUSE_COLUMN_PRESENT_BYTE / COLUMN_PRESENT_BYTE.
3. auto_fallback not0..1: REFUSE_COLUMN_AUTO_FALLBACK_BYTE / COLUMN_AUTO_FALLBACK_BYTE; then dangerous_work not0..1: REFUSE_COLUMN_DANGEROUS_WORK_BYTE / COLUMN_DANGEROUS_WORK_BYTE. Separate codes make a flag-argument transposition observable and identify the offending column.
4. Any job_priority not0..4: REFUSE_COLUMN_PRIORITY_RANGE / COLUMN_PRIORITY_RANGE.
5. At any physical slot, job_priority[slot*12+JOB_KIND_RESERVED_INDEX] !=0: REFUSE_COLUMN_RESERVED_PRIORITY / COLUMN_RESERVED_PRIORITY.
6. Any present0 row with either flag nonzero or any of its12priorities nonzero: REFUSE_COLUMN_FREE_ROW / COLUMN_FREE_ROW.
7. Success is existing REFUSE_NONE.

Helpers are static, argument-only and bounded by named owner constants. Byte-domain scans may use count() per legal value (already exercised by Needs on pinned Godot4.7.2) or a bounded single pass; no duplicate(), sort(), per-row objects or derived occupancy array. Reserved/free scans must include slots0 and511. Use exactly `static func _free_row_is_clear(job_priority: PackedByteArray, auto_fallback: PackedByteArray, dangerous_work: PackedByteArray, slot: int) -> bool` as the one definition for both the packed free-row gate and the existing inactive_row_is_clear reader. The reader retains its exact invalid-address/present-row false guard before delegating; the validator calls the helper only after complete shape/domain admission. The helper has no present argument and must not read live presence. Its two flag checks are symmetric; target the observable bridge/predicate argument boundary, not that symmetric helper, with the flag-swap mutant. Do not otherwise refactor ordinary behavior.

Order examples are intentional: reserved byte7 returns COLUMN_PRIORITY_RANGE; an inactive row with reserved byte3 returns COLUMN_RESERVED_PRIORITY before COLUMN_FREE_ROW; an inactive row with auto_fallback1 returns COLUMN_FREE_ROW. Codes report the first violated gate, not every applicable problem, and COLUMN_* details name only the owner and returned code, with no row identity claim. Pin these cases explicitly.

## Framed bridge

Add save_owner_priorities.gd with one public API:

`static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal`

Allowed preloads: Priorities, Schema, Section, SaveHeader. No owner instance, clock, capture, apply, I/O, reflection, callbacks or dynamic registry reads.

Order: null -> SAVE_COMPONENT_SHAPE; owner!=11 -> SAVE_COMPONENT_OWNER; Schema.schema_refusal forwarded unchanged; exact metadata below -> SAVE_COMPONENT_METADATA; Section.owner_shape_refusal forwarded unchanged; call the shared predicate using the four explicit u8_column ordinals. Return the raw unwrapped COLUMN_* code with detail identifying Priorities owner11 and that code. Success has emptycode/detail.

Metadata guard checks owner key/version/primary/zerochildren/4fields and each explicit key/type/count. Cross-check PRIORITY_CAPACITY==512 and JOB_KIND_COUNT==12 as well as compiled extents. Named scalar constants may pin identities, ordinals and expected metadata; no new Array table is needed for four fields. Gate4 detail begins exactly `Priorities owner11 metadata:`. Gate3 forwards its original detail, so a shared metadata code alone is not evidence of gate identity. Unlike Needs, there are no owner publication arrays to compare. This bridge compares the schema to the pinned contract literals and existing capacity/stride constants; the independent schema generator/source-capacity audit still proves the registry against actual owner declarations. Do not claim an owner-publication-table parity check.

The caller freezes the record for this synchronous call. Accessors and packed arguments share COW buffers. Do not allocate substitute columns, construct a live Priorities, or retain the record. An all-zero frame is a valid empty Priorities image, unlike Needs. Cross-owner occupancy, resident identity, consent-dependent eligibility, low-risk fallback, lifecycle/barrier publication and full-file provenance remain downstream.

## Accounting and evidence

One framed image is6144+3*512=7680 logical packed bytes. Predicate/bridge add no packed buffers; charge the caller's7680 once, with wrapper/native overhead unmeasured. No resident allocation or immutable Array row is introduced. Cold metadata/string/Refusal overhead remains subject to the existing runtime qualification gate.

Parent tests cover all byte domains, every physical priority byte, both flag columns, reserved first/last rows and all other active kinds, inactive exact clearing, all512present allowed, nondefault priorities/consent, all-zero accepted, malformed shapes/buckets and wrongowner/null, exactcode/detail success/failure, first-refusal across differentrows, allinput arrays unchanged. Current public lifecycle outputs must be admitted and existing test_priorities.gd remain green.

Four projection-substitution mutants replace one mapped argument with an allzero correctly-sized column; exactcode fixtures must kill them by assertions. Use the explicit parent-test-matrix.md evidence: base row0 present1 and active priority2; present2 expects COLUMN_PRESENT_BYTE while a zero substitute yields COLUMN_FREE_ROW; priority5 expects COLUMN_PRIORITY_RANGE while zero accepts; one flag2 with the other0 expects its distinct flag code while zero accepts. Also test a valid nondefault present row whose presence substitution produces COLUMN_FREE_ROW. The allzero accepted control is not a mutation witness. Also a swapped auto/dangerous argument mutant, reserved-rule omission, free-row omission and a reserved/free precedence mutant. Compile/parser failures never count. Metadata faults must prove schema-valid key/version/primary/child/field disagreement and exact schema forwarding; bypass at least the identity guards using real engine tests in a disposable clone, with source integrity verification.

Production author owns only priorities.gd and new save_owner_priorities.gd through a bounded SHA-pinned unified patch. Parent owns tests, classification, sidecar regeneration, queue, docs and CI. Focused/full suites, import, static source gates, independent source review, mutation evidence and exact-head CI precede merge. Do not mark SAVE-S4-SEMANTICS or owner bindings complete from this primitive.
