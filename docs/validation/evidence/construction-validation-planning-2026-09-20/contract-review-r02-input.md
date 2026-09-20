# Construction component local validation contract

CONSTRUCTION-S4-VALIDATE-R01v1 candidate for final owner-specific review, September20. Astra resolves the first independent review's conditions here; implementation remains undispatched pending confirmation and the final witness table. Existing section4 family and borrowed-view rules remain accepted. Local validation does not certify whole-file identity, delivered materials, capture/apply, demolition policy or playable construction.

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

`static columns_refusal(image:Columns)->StringName` returns existing empty REFUSE_NONE on success. It is read-only: no diagnostics, live reads, clock, callbacks, serialized copies, packed scratch or per-row objects. First null or wrong extent returns COLUMN_SHAPE. The source preflight below must fail before unsafe fact access. Direct validation never relies on prior bridge protection. COLUMN_SOURCE_METADATA is returned by the pure path; the bridge translates source drift into its METADATA result.

After source preflight, scan the entire present, paused, work_begun buffers in that exact order for canonical0/1; any invalid byte returns COLUMN_FLAG. Then visit rows0..82943; within each row return the first failing gate below. Remaining codes COLUMN_ENUM, COLUMN_VALUE, COLUMN_REF, COLUMN_FREE, COLUMN_TYPE, COLUMN_WORKERS, COLUMN_POLICY, COLUMN_PHASE. Each has a matching REFUSE_COLUMN_* constant. The complete code/constant mapping is frozen below.

1. ENUM: purpose0..3, phase0..4, refund_policy0..2.
2. VALUE: remaining_mwu>=0; assigned_count>=0; max_workers>=0; type_id>=-1. Upper i32 limits already follow packed storage; remaining remains i64 until its source-derived work bound is checked.
3. REF: each self and subject pair is exactlyNULL(-1,0) or Directory slot0..352417/generation1..MAX_i32. Material container is NULL or slot0..MAX_i32/generation1..MAX_i32 in Inventory's namespace; do not impose Directory capacity on it.
4. FREE: inactive rows require null self/subject/container, zero remaining/assigned/paused/work_begun. If max_workers==0, require exact clear row including purposeBUILD,type-1,phaseAWAITING,refundFULL; then accept this never-used row. An inactive nonzero-worker row proceeds as retained history. Present rows cannot use the clear-row shortcut and require nonnull self and subject.
5. TYPE: building ID0..29 for BUILD/DEMOLISH; furniture ID0..8 for FURNITURE; UPGRADE requires one of covered_store/hall/residence/workshop, canonical IDs5/12/23/29. Bounds precede indexing. The -1 sentinel is accepted only by the exact clear-row shortcut.
6. WORKERS: max_workers equals the source fact for building purpose, or MAX_BUILDERS4 for furniture; assigned<=max_workers. Paused or REFUNDING implies assigned0. Do not require assigned0 in unpaused AWAITING, READY or WORK_DONE: public setter permits these histories.
7. POLICY: live demolition alwaysDEMOLITION; other live rows FULL before work_begun and PARTIAL after. Inactive demolition remainsDEMOLITION. Inactive non-demolition WORK_DONE requiresPARTIAL; REFUNDING permitsFULL/PARTIAL. Never recompute retired refund from work_begun, which retirement clears.
8. PHASE: retained rows allow onlyWORK_DONE orREFUNDING. For live rows, W is frozen declared work for purpose/type (BUILD/FURNITURE facts, explicit upgrade work, or floor(base building work/4) for DEMOLISH). AWAITING requires work_begun0, remainingW and a nonempty delivery bill; READY requires work_begun0 and remainingW; WORKING requires work_begun1 and remaining1..W; WORK_DONE requires work_begun1 and remaining0; REFUNDING permits work_begun0 with remainingW or work_begun1 with remaining0..W. All W are positive. Dirt path BUILD and every DEMOLISH have no delivery bill, so AWAITING refuses. Ledger completeness is not inferred from READY.

No self uniqueness, saved liveness, directory kind, reciprocal construction link, subject overlap, loaded-tick relation or delivered material claim belongs to this local pass. A source-lost live row is structurally possible here; the saved consistency pass must reject incompatible identity, not normalize it.

## Exact public surface and refusals

Add an inner `Columns extends RefCounted` with the sixteen typed packed properties above. `_init(allocate_defaults:bool=true)` returns on false before any resize/fill; properties remain empty typed arrays. The default path resizes each to82944 and fills its declared clear value. `is_sized()->bool` checks all16 exact extents. `static columns_refusal(image:Columns)->StringName` is the sole public pure row predicate; `static column_source_metadata_refusal()->StringName` is a read-only source preflight shared with the bridge. No live store is constructed by either.

Freeze these names and exact StringName values: REFUSE_COLUMN_SHAPE/COLUMN_SHAPE; REFUSE_COLUMN_SOURCE_METADATA/COLUMN_SOURCE_METADATA; REFUSE_COLUMN_FLAG/COLUMN_FLAG; REFUSE_COLUMN_ENUM/COLUMN_ENUM; REFUSE_COLUMN_VALUE/COLUMN_VALUE; REFUSE_COLUMN_REF/COLUMN_REF; REFUSE_COLUMN_FREE/COLUMN_FREE; REFUSE_COLUMN_TYPE/COLUMN_TYPE; REFUSE_COLUMN_WORKERS/COLUMN_WORKERS; REFUSE_COLUMN_POLICY/COLUMN_POLICY; REFUSE_COLUMN_PHASE/COLUMN_PHASE. Existing REFUSE_NONE is success. Flat gate names are deliberate: Construction has one row family, unlike Buildings' separate building/room/furniture families.

## Immutable facts and safe source preflight

Use source-extracted frozen-source-facts.json in the planning evidence directory as the independent numerical oracle. No new game values are assigned. Gate-consumed typed constant Arrays live in Construction: canonical building/furniture keys in ID order, building work/max-workers/build bill pair counts, furniture work/bill pair counts, four upgrade IDs/work/bill pair counts. Demolition work is integer base work/4, no delivery. The helper scans the four upgrade IDs without constructing a map. Direct preflight compares these fixed arrays with authored BuildingDefinitions facts and Construction bill/work dictionaries. Its array lengths and scalar index constants are validated before any access.

Freeze gate-array names and representations: COLUMN_BUILDING_KEYS:Array[String][30], COLUMN_BUILDING_WORK_MWU:Array[int][30], COLUMN_BUILDING_MAX_WORKERS:Array[int][30], COLUMN_BUILDING_BILL_PAIR_COUNTS:Array[int][30]; COLUMN_FURNITURE_KEYS:Array[String][9], COLUMN_FURNITURE_WORK_MWU:Array[int][9], COLUMN_FURNITURE_BILL_PAIR_COUNTS:Array[int][9]; COLUMN_UPGRADE_IDS:Array[int][4], COLUMN_UPGRADE_WORK_MWU:Array[int][4], COLUMN_UPGRADE_BILL_PAIR_COUNTS:Array[int][4]. Bracketed extents here are contract notation, not GDScript fixed-array syntax. Values come exactly from frozen-source-facts.json in canonical ID order (upgrade IDs5,12,23,29). Bridge anchors use the same suffixes with SOURCE_ in place of COLUMN_, plus SOURCE_BUILD_BILLS, SOURCE_FURNITURE_BILLS and SOURCE_UPGRADE_BILLS exact frozen dictionaries. These names and values are part of the contract.

The bridge holds independent out-of-file SOURCE_* frozen anchors for those arrays and exact authored bill contents. Its metadata gate compares source facts, gate-consumed owner arrays and its own frozen anchors. Pure validation still protects itself independently; it may not assume the bridge already ran. Exact bill quantities are drift checks; only bill emptiness, work, max-workers and upgrade membership affect local row gates. This creates no mutable catalog, live compiled Definitions instance, packed fact cache or new state authority.

Walk IDs0..29 and0..8 using the frozen key permutation. Prove each source dictionary has exactly the expected keys, each ID is an actual integer equal to that visited ordinal, and every fact row has its exact shape/types/values. No key-only iteration, duplicate IDs, unreferenced IDs, sorting, coercion or object-returning catalog lookup. Pin Catalog ordinals and BuildingDefinitions row index constants before indexing. Constructor assert() calls are not evidence that release code is protected.

Pin source scalars: Construction capacity82944/MAX_BUILDERS4/MATERIAL_SLOTS_PER_PROJECT4/DEMOLITION_WORK_NUM1/DEN4; purpose0..3, phase0..4, refund0..2 exact semantic names; Directory capacity352418 and null(-1,0); building/furniture counts30/9, B_WORK_MWU2/B_MAX_BUILDERS9/B_FIELD_COUNT10/F_WORK_MWU2/F_FIELD_COUNT4; maximum signed-i32 reference boundary. Material-container namespace remains separate. Pin the six known material keys against the existing source.

For each bill, first require Variant TYPE_ARRAY, then an even length, then paircount0..4, then each key's actual string type/known membership and each quantity's actual integer type/positive value. The bridge additionally compares every frozen key/quantity in exact order; the pure helper does not pretend to own a second quantity mirror. Zero pairs is valid only where authored (dirt_path BUILD and all DEMOLISH); validate exact dictionary membership and contents without typed assignment of an unchecked Variant. Bounds and type proof always precede indexing/conversion. No runtime hashing, serialization, per-row objects or additional packed buffer.

## Bridge and projection

Add `save_owner_construction.gd` with the accepted family `framed_refusal(record:Section.FramedOwner)->SaveHeader.Refusal` interface and four direct preloads: Construction, Schema, Section, SaveHeader. Other immutable sources are reached through Construction's existing preloads. Seven gates: null; owner1; unchanged Schema.schema_refusal; owner and source metadata; unchanged Section.owner_shape_refusal; empty Columns(false) plus16 canonical typed assignments; pure columns_refusal. No extra default image, copies, resize/fill, serialization or live constructor.

Freeze owner key construction/version1, primary82944, zero child extents, field begin29/count16 and every key/type/count in the table. Canonical projection uses one private static `_project_columns(record,out)` helper called by framed_refusal; exactly16 explicit assignments from the matching typed reader/ordinal into the corresponding public Columns property. This helper performs no validation, allocation or hidden alternate mapping. Tests can invoke this production mapper on a shape-valid framed record and a caller-owned empty view to inspect all16 property values; this adds no live-state accessor or production bypass entry point.

Gate4 detail prefix: `Construction owner1 metadata:`. Gate7 prefix: `Construction owner 1 `. Preserve the deliberate spacing. Owner/schema/framed-shape refusals forward existing family code/detail unchanged. Source drift maps to family METADATA with gate4 prefix; ordinary pure codes propagate exactly with gate7 prefix and no row identity. Success has empty code/detail.

Direct SHAPE precedes SOURCE_METADATA. Bridge metadata precedes framed shape. This deliberate entry-point ordering difference requires a collision witness for both paths; the bridge does not rewrite the pure contract.

## Required evidence and witnesses

The accepted witness manifest must enumerate clear/default/borrowed shape; every16short/long/empty field; flags and all ordered gate collisions; first/interior/final rows; each purpose/type domain; every valid live phase with exact work/refund/worker/paused relationships; full-capacity mixed image; all retained completion and cancellation variants. Preserve maximum signed-i32 container pair, structural-but-stale self/subject references, assigned workers in unpaused AWAITING/READY/WORK_DONE and zero workers when paused/refunding. Never recompute a retired policy from cleared work_begun.

Projection evidence has two distinct forms: all16 omitted assignments leave an empty property and must fail COLUMN_SHAPE; a separate actual production mapper witness gives every column a distinguishable pattern and checks all16 output properties against the corresponding framed input. Same-type self/subject swaps are not detectable by this local semantic predicate; they must be caught by exact projection witnesses, while saved identity remains a named binding obligation. No exhaustive mutation claim.

Retained-history proof uses synthetic complete row cases plus real public lifecycle histories. The engine-bound feasibility probe observes public state_bytes using an explicit serialization-order table (container fields first, present eighth; delivered ledger/livecount last), deriving every segment length through the running engine's var_to_bytes of an exact-type/extent prototype. It checks total size before slicing, decoded type/count before indexing, and keeps only requested row scalars. It assumes no Variant header/tag/padding offset, adds no private field accessor and defines no save format. Actual probe evidence and independent review must confirm this method before its use in final tests. Public getters alone refuse retired handles and do not observe retained values.

Counterfactuals include safe source key/type/ordinal/row/index/work/worker/upgrade/bill drift, coherent schema mismatches, every16 projection omission, real mapper swaps, row-scan skips, directory-bound container confusion, forbidden workers-only-in-WORKING shortcut, retired refund recomputation, work/phase relation omissions, and input mutation. Count unique fault units separately from reruns; parse/runtime errors are invalid evidence.

The existing6417408 stream allowance equals4893696 caller bytes +2*663552 +3*65536. Zero logical slack; no new packed scratch. A second default owner image would produce9787392 caller+view bytes and is forbidden. The actual adapter allocation discriminator must require valid positive static-memory observations, ballast above prior peak, incremental peak<1048576 and a caught Columns(false)->Columns() mutation. Native constant/container/object overhead is unmeasured, not zero.

Actual import, focused/full regression, schema/specification checks, metadata and semantic counterfactuals, allocation discriminator, independent exact-source review, committed identity, exact-head CI and merge remain gates. No author self-acceptance.

## Saved coverage and integration boundary

The delivered-material ledger is already registered in section5 CHILD_ARENAS:331776i64 values,2654208bytes, owner-major stride4. It was not omitted from the persistence design. SAVE-S5-CODEC, capture/apply and section4+5 binding remain required; no section4 result makes Construction alone savable. Derived live_count and immutable compiled bill columns retain their existing classifications. Frozen section5 registry evidence is in persistence-coverage-excerpt.json.

CONSTRUCTION-SAVED-BINDINGS retains same-file Directory identity/kinds/liveness, self and subject uniqueness, reciprocal building/project links, section5 delivered quantities and material conservation, loaded-tick relations and common-file provenance. No quadratic scan or unbudgeted sort/image is authorized here. Tier2 demolition economics remain a separate gameplay ruling; this validator preserves current declared base-building work without inventing the unresolved policy.
