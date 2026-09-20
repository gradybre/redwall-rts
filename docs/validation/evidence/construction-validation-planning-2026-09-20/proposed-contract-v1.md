# Construction component validation — contract draft

CONSTRUCTION-S4-VALIDATE-R01 draft1. Source-derived proposal, not adopted or dispatched. Reuse the accepted component family and Buildings borrowed-view pattern. Independent assessment must confirm the owner-specific domains and source preflight before implementation. This validates the existing local section4 image; delivered materials, saved identity consistency, capture/apply, demolition policy and live gameplay are separate.

## Existing schema and image

Owner1 construction/version1, primary82944, childcount0, fieldbegin29/count16, offset3298593, values4893696, payload4893828, block4893864. Do not renumber fields or derive their order from declaration order.

Columns stores the following typed packed arrays, with properties named by removing the schema key's leading underscore. `Columns.new(allocate_defaults:bool=true)` allocates the clear image. `false` leaves all typed packed properties empty before any resize/fill; an unbound borrowed view fails shape. No live Construction, Buildings, Directory or Definitions constructor is permitted in local validation or bridge projection.

| Ordinal | Property | Type/count | Clear value |
|---|---|---|---|
|0|present|u8[82944]|0|
|1|material_container_slot|i32[82944]|-1|
|2|material_container_generation|i32[82944]|0|
|3|assigned_count|i32[82944]|0|
|4|max_workers|i32[82944]|0|
|5|refund_policy|i32[82944]|0|
|6|remaining_mwu|i64[82944]|0|
|7|paused|u8[82944]|0|
|8|work_begun|u8[82944]|0|
|9|ref_slot|i32[82944]|-1|
|10|ref_generation|i32[82944]|0|
|11|subject_slot|i32[82944]|-1|
|12|subject_generation|i32[82944]|0|
|13|purpose|i32[82944]|0|
|14|type_id|i32[82944]|-1|
|15|phase|i32[82944]|0|

## Deterministic local refusal order

`static columns_refusal(image:Columns)->StringName` returns existing empty REFUSE_NONE on success. It is read-only: no diagnostics, live reads, clock, callbacks, serialized copies, packed scratch or per-row objects. First null or wrong extent returns COLUMN_SHAPE. The owner-specific immutable-fact helper safety policy must be confirmed during independent review: malformed source must fail before any unsafe fact access, and raw direct validation must not depend on a bridge having already protected it. Proposed code COLUMN_SOURCE_METADATA for that bounded preflight, also consumed by the bridge as METADATA.

After source preflight, scan the entire present, paused, work_begun buffers in that exact order for canonical0/1; any invalid byte returns COLUMN_FLAG. Then visit rows0..82943; within each row return the first failing gate below. Proposed remaining codes COLUMN_ENUM, COLUMN_VALUE, COLUMN_REF, COLUMN_FREE, COLUMN_TYPE, COLUMN_WORKERS, COLUMN_POLICY, COLUMN_PHASE. Each has a matching REFUSE_COLUMN_* constant. These code names and ordering are a review candidate, not an existing public promise.

1. ENUM: purpose0..3, phase0..4, refund_policy0..2.
2. VALUE: remaining_mwu>=0; assigned_count>=0; max_workers>=0; type_id>=-1. Upper i32 limits already follow packed storage; remaining remains i64 until its source-derived work bound is checked.
3. REF: each self and subject pair is exactlyNULL(-1,0) or Directory slot0..352417/generation1..MAX_i32. Material container is NULL or slot0..MAX_i32/generation1..MAX_i32 in Inventory's namespace; do not impose Directory capacity on it.
4. FREE: inactive rows require null self/subject/container, zero remaining/assigned/paused/work_begun. If max_workers==0, require exact clear row including purposeBUILD,type-1,phaseAWAITING,refundFULL; then accept this never-used row. An inactive nonzero-worker row proceeds as retained history. Present rows cannot use the clear-row shortcut and require nonnull self and subject.
5. TYPE: building ID0..29 for BUILD/DEMOLISH; furniture ID0..8 for FURNITURE; UPGRADE requires one of covered_store/hall/residence/workshop, canonical IDs5/12/23/29. Bounds precede indexing. The -1 sentinel is accepted only by the exact clear-row shortcut.
6. WORKERS: max_workers equals the source fact for building purpose, or MAX_BUILDERS4 for furniture; assigned<=max_workers. Paused or REFUNDING implies assigned0. Do not require assigned0 in unpaused AWAITING, READY or WORK_DONE: public setter permits these histories.
7. POLICY: live demolition alwaysDEMOLITION; other live rows FULL before work_begun and PARTIAL after. Inactive demolition remainsDEMOLITION. Inactive non-demolition WORK_DONE requiresPARTIAL; REFUNDING permitsFULL/PARTIAL. Never recompute retired refund from work_begun, which retirement clears.
8. PHASE: retained rows allow onlyWORK_DONE orREFUNDING. For live rows, W is frozen declared work for purpose/type (BUILD/FURNITURE facts, explicit upgrade work, or floor(base building work/4) for DEMOLISH). AWAITING requires work_begun0, remainingW and a nonempty delivery bill; READY requires work_begun0 and remainingW; WORKING requires work_begun1 and remaining1..W; WORK_DONE requires work_begun1 and remaining0; REFUNDING permits work_begun0 with remainingW or work_begun1 with remaining0..W. All W are positive. Dirt path BUILD and every DEMOLISH have no delivery bill, so AWAITING refuses. Ledger completeness is not inferred from READY.

No self uniqueness, saved liveness, directory kind, reciprocal construction link, subject overlap, loaded-tick relation or delivered material claim belongs to this local pass. A source-lost live row is structurally possible here; the saved consistency pass must reject incompatible identity, not normalize it.

## Immutable facts and bridge proposal

Use frozen-source-facts.json from this directory:30 building work/max-worker/bill rows,9 furniture rows and4 explicit upgrades, with source hashes. Pure code accesses bounded immutable facts without live construction. The accepted contract must freeze the exact static representation and helper signature before author dispatch, and independent review must resolve whether duplicated fact tables are necessary. No source table may be silently treated as measured runtime metadata.

The bridge `save_owner_construction.gd` follows the family Result interface and seven gates: null; owner1; unchanged full schema refusal; owner/source metadata; unchanged framed shape; `Construction.Columns.new(false)` plus16 explicit canonical typed assignments; pure refusal wrapped into Result. Success code/detail empty; source drift uses the family METADATA result and a Construction-specific detail. The exact prefix will be frozen with the final contract. Projection must borrow buffers, never copy/serialize or allocate another full image.

Pin exact schema owner/key/version/counts/field extents and all16key/type/count rows. Pin purpose/phase/refund ordinals and bounds, Construction capacity82944/MAX_BUILDERS4/DEMOLITION_WORK_NUM1/DEN4, Directory capacity352418/null pair, building/furniture counts30/9, relevant source field indexes B_WORK_MWU2/B_MAX_BUILDERS9/F_WORK_MWU2 and source row sizes10/4. Catalog key membership, integer types and canonical ordinals must be exact, with unknown/missing keys refused. Pin upgrade membership and integer work values. Pin delivery-bill shape and frozen content without flattening a full owner image: keys known, pair counts bounded4, quantities positive exact integers, key entries strings, and exact source values. Source drift must not pass by coercing string numbers to integers or by preserving only lengths.

## Memory and tests

Existing stream allowance6417408 = caller4893696 +2*largestfield663552 +3*65536 windows. Zero logical slack; no allowance increase. Caller plus a second default image9787392 is forbidden. Native overhead and process RSS remain unmeasured. Actual adapter allocation discriminator must use valid positive Godot static-memory readings with ballast above prior peak, require incremental peak<1048576, and catch a new(false)→new() mutation. Invalid measurement, import, parse or engine error cannot count as a semantic refusal or memory pass.

Freeze independent test data before author dispatch: all16short/long and each empty property shapes, all3flag-order cases; each gate alone and ordered collisions; first/interior/last rows for each field; valid clear, everypurpose/phase, partial/full work, paused/unpaused, full-capacity mixed image; retained completion and cancellation before/afterwork across eachpurpose. Explicitly include maximum structural container slot and stale-but-structural references. Derive test expected values independently from source tables and compare frozen data at runtime or by an archived exact-content checker.

Public-history evidence should decode state_bytes' documented serialization order for retired rows with an independent offset table, or use an independently reviewed read-only capture API. Do not add private mutable accessors for tests or claim public reads observe retired state when they reject retired handles.

Metadata counterfactuals cover key missing/extra/rename/type/id, rowtype/length/index drift, sourcework/maxworker/upgrade/bill drift, owner fact mismatch and schema coherent bypasses. Semantic mutants cover every16 projection omission, skipped first/odd/final rows, wrongly requiring workers only inWORKING, treating container slots asDirectory slots, recomputing retiredrefund, omitting work/phase relationships and writing into input. Use the existing fault harness family; count unique units separately from reruns.

Actual import, focused/full regression, static/schema checks, metadata faults, actual allocation mutation, independent exact-source review, committed identity, exact-head CI and merge remain acceptance gates. Validation is not a full save/load or runtime construction milestone.

## Remaining decisions before dispatch

Confirm direct-pure immutable preflight design, exact frozen static arrays/helper interface, detail prefixes and the complete witness tables. Resolve only owner-specific questions; do not reopen the accepted component wire format or borrowed-view policy. This draft deliberately leaves those named implementation-contract decisions visible and does not authorize an author to guess them.
