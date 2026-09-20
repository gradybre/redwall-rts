# Exact storage-aging declarations and owner adapter

SAVE-AGE-R01 · version1 draft for independent review · 2026-09-19 · Astra

Close StockAge's owner boundary and provide its section7block adapter. Inventory
already publishes columns; fishing/forage/gear/reservations remain separate I1
work. No whole-section capture, world publication, catalog activation or stock
fault/retry/hold policy is supplied. Keep StockAge owner schema1, section7schema3
and canonical registry5 unchanged. Preserve healthy runtime bytes exactly.

## Owner record and interface

Add nested StockAge.CanonicalColumns (RefCounted) with container_capacity:int set
to CONTAINER_CAPACITY=101376, and4separate arrays allocated at that extent:
c_storage_class:PackedByteArray initially0, c_heated_interior:PackedByteArray0,
c_declared_generation:PackedInt32Array0, declared_slots:PackedInt32Array(-1).
Scalars declared_count:int=0,last_hour_tick:int=NO_HOUR_RUN(-1). Constructor
has no extent parameter; capacity metadata is validated if caller later changes
it. No Inventory/catalog/owner instance is allocated by this record.

Public owner methods:
- copy_canonical_columns_into(out:CanonicalColumns)->bool
- restore_canonical_columns(columns:CanonicalColumns)->bool
- last_column_refusal()->StringName
- canonical_detail()->String, returns String(last_column_refusal()).

Add category3 _last_column_refusal only. Failure changes only this scalar;
success clears it. Never change existing _last_refusal on either path. Refusals:
COLUMN_STOCK_AGE_SHAPE, COLUMN_STOCK_AGE_BINDING, COLUMN_STOCK_AGE_BUSY,
COLUMN_STOCK_AGE_RECORD. No new persisted or derived owner arrays.

Owner capture order: null/shape of output; binding; busy; source array shapes;
source native scalar domains; source row/list validation; publication. Restore:
null/shape of input; binding; busy; input scalar domains; row/list validation;
installation. Shape means capacity metadata exactly101376 and all4arrays exact
size. Bindings require nonnull Inventory and nonnull loaded ItemDefinitions.
Busy is bound Inventory.is_transaction_open() or is_transaction_poisoned();
these existing queries are pure. This is not a claim that this adapter certifies
Inventory journal/attestation or world quiescence; full coordinator remains owner
of those preconditions. Source wrong array extents refuse RECORD; caller wrong
shape refuses SHAPE. No scalar narrowing before native-range checks.

Payload validation (before any output/live write): count in0..101376; latch>=-1;
then ascending container rows: class0..4, heated0/1, generation>=0; declared
(class>0) requires generation>0; undeclared requires heated0 and generation0.
Int32 storage already bounds positive generation<=I32_MAX. Prefix entries of
declared_slots in0..101375, unique, naming declared rows; every declared row
occurs once; tail[count,capacity) all-1. Use one byte membership scratch at
capacity101376; never index it before slot range checks. No sorting or repair.

Match the existing codec's latch domain>=NO_HOUR_RUN. Do not newly reject751 or
invent a maximum tick here; stronger clock/latch/fault consistency is a separate
coordinator requirement. Never call is_hour_boundary/calendar/aging to validate
or reconstruct a saved latch. This scalar is preserved, not inferred from lots.

Stale container generations are legitimate until the normal hourly sweep drops
them. Do not query current container validity, crop/item meanings, current
storage_class_of or present-day operational gates during capture/restore.
Preserve stale references and dense prefix order exactly. No mark-all,
declaration replay, clear, hourly sweep, Inventory mutation, signal or callback.

Capture may validate existing arrays directly using pure helpers and then
replace output fields with4independent duplicates and exact2scalars. No staging
full record is required: no yield/callback occurs between validation/publication.
Restore validates first, installs4independent duplicates and2exact scalars, then
sets cached _spoiled_food_id/_compost_id=-1 for normal _preflight re-resolution.
Leave borrowed objects, calendar/math, store/temperature scratch and existing
_last_refusal unchanged. Rebinding a different Inventory clears declarations,
so bind_stores must precede restore. Adapter does not bind on a caller's behalf.

## Separate adapter, no codec-owner cycle

New save_stock_age_restore.gd preloads StockAge, save_section_inventories,
SaveHeader and SimClock. Do not preload the codec from StockAge. Accept a single
Codec.OwnerRecord to avoid allocating all6owner blocks. Public static surface:
- capture_into(store:StockAge,out:Codec.OwnerRecord)->SaveHeader.Refusal
- apply(block:Codec.OwnerRecord,store:StockAge,clock:SimClock=null)->SaveHeader.Refusal
- block_shape_refusal(block:Codec.OwnerRecord)->SaveHeader.Refusal

Adapter codes SAVE_AGE_BLOCK_SHAPE, SAVE_AGE_NULL_STORE, SAVE_AGE_NULL_CLOCK,
SAVE_AGE_BARRIER_NOT_HELD. Forward owner column codes and the existing codec
owner_refusal code/detail for semantic failures; no generic success fallback.

Total block shape: nonnull; owner==Codec.OWNER_STOCK_AGE(5); primary_count==
101376; child_extents length0; u8/i32/i64 groups each exactly2columns. Bothu8
and bothi32 columns length101376; bothi64 columns length1 (u32count stored in
i64 group). Check groups before indexing. Do not call generic owner_refusal
until this gate passes; its current implementation assumes valid shape.

Capture order: null store; target block shape; one local CanonicalColumns; owner
capture; stage one private OwnerRecord(5,101376,nochildren); map ordinals0count,
1latch,2class,3heated,4generation,5slots; existing Codec.owner_refusal(staged);
only then replace output's3typed groups. Scalar values are i64group singletons,
not narrowed to u32 without the owner count bound. Output metadata unchanged
and buffers independent of owner. Private Columns arrays may be transferred
into the private stage and published without another duplicate because neither
private record escapes otherwise. Prior held target arrays retain old values.

Apply order: null block(SHAPE); null store; null clock; lowered barrier; block
shape; existing codec owner_refusal; create one local CanonicalColumns view of
all6values; owner restore. The local view may borrow block arrays because owner
restore duplicates before installation and never writes its input. No local
view escapes. Failure leaves block, live owner and collaborators unchanged
except owner _last_column_refusal if its API was reached. Caller reads returned
Refusal; a codec-stage rejection leaves older owner diagnostic alone.

The supplied actual world's clock must have is_load_barrier_held(). Do not
acquire/release it, pause, tick or bind owners. Clock/world/catalog association,
Inventory restore, valid publication and disk rollback remain caller obligations.

## Memory and evidence

Existing owner packed arrays1013760B. Each Columns adds1013760B plus metadata/
native scalars; each OwnerRecord1013776B packed because both scalar columns are
i64-backed. Validation membership101376B. Capture owns local Columns plus
private staged OwnerRecord; target/old buffers and live owner coexist. Restore
owns one local Columns plus newly duplicated owner buffers while old fields
are replaced. Constructor arrays may temporarily coexist with adopted arrays.
Document phase allocations and retained caller buffers; do not repeat the
auditor's understated2.03MB peak or claim RSS qualification. This is cold work.

Owner wire payload unchanged:608320+4*declared_count; wrapper33; empty
block608353, full1013857. Do not allocate all6owners merely to test one block.

Required independent tests:
1. Empty/real declarations, all4classes/heatedvariants, exact2scalars/4arrays
and row/list order; all6codec ordinals/schema/type/extents against registry.
2. Declaration order counterexample: createA,B,C; withdrawA =>[C,B]. Waste lots
at expiry inB,C retire in that order. After snapshot/restore into equivalently
bound world, next2lot IDs match uninterrupted; sorted order yields a different
first ID. Preserve this actual witness, not an ascending fixture.
3. Restore latchT: run_hour(T) refuses, nextT+750 ages once; declaration stale
after destroyed/reused container survives until next normal sweep. Do not
reuse a cache from another catalog or call clear to restore.
4. Every shape/binding/busy/nativecount/domain/list/tail refusal atomic. Use
probe-only reflection to compare all value fields and scratch even when source
is corrupt and cannot capture. Exclude only _last_column_refusal. No production
reflection. A valid restore invalidates exactly2compiled IDs; all other scratch
and borrowed identities unchanged.
5. Malformed block metadata/group lengths/extents refuse without runtimeerrors;
block semantic failure and owner-specifictailfailure preserve both input/output.
Null/missing/lowered barrier precedence, callerclockunchanged, no secondworld.
6. Export/restore buffer independence and aliased caller class/heated arrays.
Old output buffers remain previous snapshots. Count native2^32 refuses before
wire narrowing. Prefixfirst/lastindices, full/empty list, duplicates/omissions.
7. Golden single-block hashes before/after adapter unchanged: the evidence probe
composes the literal existing wrapper plus public column_slice output without
allocating a6owner Record. This is not a full section encode/decode claim; the
existing whole-codec suite remains the integration regression. Count0/1/capacity
byte arithmetic. Full suite/static gates/import, independent contract/source
reviews and exact-head CI before merge.

Ownership: stock_age.gd, new save_stock_age_restore.gd, dedicated tests/focus.
Parent owns registry/ADR/queue/evidence. Split this bounded child from the
SAVE-COLUMNS-INVENTORY umbrella without claiming I1 done.
