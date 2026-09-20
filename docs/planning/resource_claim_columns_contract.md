# Exact Fishing and Forage claim columns

SAVE-CLAIMS-R01 · version2 · accepted after independent review · 2026-09-19

Scope is two section7 claim tables, not all state in their owning modules.
Fishing also owns section4 habitats/stocks; Forage owns sections1/4/5 tile heads,
zones, patches and link arenas. Never clear, replay or rebuild those other parts
from this boundary. Preserve every nonclaim field, borrowed identity and scratch
value exactly, except each new category3 claim-column diagnostic. No hot API,
codec/schema or full-world behavior change is authorized here.

## Records and API

Fishing.EffortClaimColumns: seven arrays, fixed512cells, no metadata/count field:
effort_claim_active:u8; effort_claim_expedition_generation, effort_claim_habitat_slot,
effort_claim_habitat_generation, effort_claim_job_slot, effort_claim_job_generation,
effort_claim_slot_count:i32. Constructor has no arguments. Exact blanks are
active0, bothslots-1, all3generations0, slot_count0. Packed body12800bytes.

Forage.ForageClaimColumns: eleven arrays, fixed8192cells, no metadata/count field:
claim_active:u8; claim_job_slot, claim_job_generation, claim_designation_slot,
claim_designation_generation, claim_basin_slot, claim_basin_generation,
claim_patch_kind:i32; claim_remaining_milli, claim_created_tick,
claim_persistent_id:i64. Constructor has no arguments. Exact blanks: active0,
all3slots andkind-1, all3generations0, all3i64zero. Packed body434176bytes.

Fishing owner methods copy_effort_claim_columns_into(out)->bool and
restore_effort_claim_columns(columns)->bool. Forage methods
copy_forage_claim_columns_into(out)->bool and restore_forage_claim_columns(cols)->bool.
Both expose last_claim_column_refusal()->StringName and claim_column_detail()->String
(code echo). New _last_claim_column_refusal changes only on refusal or clears on
success; no existing diagnostic/scratch changes. Do not add generic Inventory
column API names. Returned bool and diagnostic describe structural admission,
not a reconciled world. Existing live-count getters remain authoritative queries.

## Validation, exact restoration and field ownership

Codes COLUMN_FISH_CLAIM_SHAPE/OCCUPANCY/BLANK/REF/SLOT_COUNT/SOURCE_COUNT;
COLUMN_FORAGE_CLAIM_SHAPE/OCCUPANCY/BLANK/REF/KIND/QUANTITY/ORDER_KEY/SOURCE_COUNT.
All names in each list carry its full prefix. Deterministic first gate wins.

1. Caller null or any caller/live CLAIM array length mismatch -> SHAPE. Check
   every7/11array before indexing. Othersection arrays are neither validated nor
   accessed. Fixed native constants512/8192 cannot be reconfigured by records.
2. Validate all active bytes across the whole table before per-row fields; only0/1.
3. Ascending rows: inactive exact blank; active field validation in wire order.
   Every generation>0; every stored directory slot0..352417. Fishing's owning
   Expedition slot is implicit through its TYPED ROW identity and savedgeneration;
   no directory lookup/reconstruction occurs here. Forage row is owning Job's
   TYPED ROW; stored Job slot is a DIRECTORY slot, not numerically equal to row.
   Preserve stale generations and exact row indices. No sorting/compaction.
4. Fishing slot_count1..6 inclusive. Six is the maximum existing habitat effort
   capacity (coast6,lake6,river4) in EFFORT_SLOTS_BY_TYPE. Compute bound from these
   existing constants without allocating/sorting; do not restate a new gameplay
   cap. All existing public habitat writes use that table. This is a deliberate
   stronger owner gate than codec>=1, and no per-habitat lookup is performed.
5. Forage patchkind0..4; remaining1..MANUAL_QUOTA_MAX_MILLI(1180000), createdtick>=0,
   persistentID>=0 (zero orderkeys structurally preserved; coordinator verifies
   provenance). A collected-to-zero claim is cleared by existing code, so active
   zero refuses. Existing public/legacy claim bounds are preserved. No clamp,
   masking or repaired value. This is stronger than codec nonnegative-i64.
6. Capture only: compare native _effort_claim_count/_claim_count with counted
   active rows; invalid/wrong count -> SOURCE_COUNT. Restore ignores prior payload
   and count, requiring old shapes only. No caller-supplied count: it is derived.
7. Capture publishes all7/11 independent duplicates only after checks; source
   read-only except diagnostic. Restore privately duplicates all7/11 arrays,
   then publishes exact arrays and computed native count with no fallible work
   remaining. Output/input may alias existing arrays; later mutation cannot leak
   across the new boundary. No extra full record allocated for source validation.

Only claim arrays, corresponding count and new diagnostic may change on successful
restore. _habitat_effort_used, _zone_quota_reserved_milli, _live_* arrays/counts,
allother canonical sections, _math/_math_b/_math_c, _effort_total_scratch,
_pending_*, _owns_directory, _directory/_jobs/_zones and existing section1
Forage diagnostics remain untouched. No new binding, owned Directory, Inventory,
Jobs or clock is constructed. No collaborator method, signal, callback or yield.
A tiny per-call native tally/code object is permitted; no per-row object,
Dictionary, reflection, sorting or unaccounted packed scratch. O(fixedR).

Forbidden calls: clear, all claim clearers/writers, restore_effort_claim,
restore_claim, rebuild_effort_aggregates, validate_effort_aggregates,
rebuild_reservation_aggregates, _refresh_claim_order_key, all hot mutators.
Existing rebuild methods change othersection canonical fields and scratch;
Forage also rewrites canonical createdtick/PID. New restore preserves those keys
verbatim even when current Jobs fields differ. Do not reinterpret them as caches.

## Adapter over one block at a time

One new stateless core/save_resource_claims_restore.gd; no module-levelvar. Typed
public static methods fishing_block_shape_refusal(block), forage_block_shape_refusal(block),
capture_fishing_into(store,out), capture_forage_into(store,out),
apply_fishing(block,store,clock=null), apply_forage(block,store,clock=null).
All return SaveHeader.Refusal. No caller scratch argument and no Inventory gate.

Fishing owner0 primary512, zerochildren, groups1u8/6i32/0i64, everycolumn512.
Forage owner1 primary8192, zerochildren, groups1u8/7i32/3i64, everycolumn8192.
Check group counts before indexing, and every column length before codec access.
Named wire ordinalconstants + Codec.storage_index_of for all accesses; never
confuse ordinals and storage positions. No full six-owner Record allocation.

capture: nullstore -> totaloutputshape -> ownercapture to private fixedColumns ->
privateOwnerRecord mapallfields -> Codec.owner_refusal -> publish3groups.
apply: nullblock -> nullstore -> nullclock -> heldbarrier -> fullshape ->
Codec.owner_refusal -> localfixedColumns borrowblockarrays -> ownerrestore
(which duplicates). No gate acquires/releases barrier or changes clock. Capture
caller guarantees completed quiescent boundary; pending scratch is not busy.
Codes SAVE_CLAIMS_NULL_STORE/BLOCK_SHAPE/NULL_CLOCK/BARRIER_NOT_HELD. Nullblock
usesBLOCK_SHAPE. Forward owner/codec codes verbatim; detailnonempty onfailure,
owner detail is exactcodeecho. On adapterearlyfailure, old ownerdiagnostic stays.
Source capture's defensive codec gate may clear ownerdiagnostic before refusing;
returned Refusal is authoritative. No metadata write before successful publication.

## Wire, memory and acceptance boundaries

Fishing payload12860, wrapper31(key fishing7), block12891. Forage payload434268,
wrapper30(key forage6), block434298. Same existing owner-schema1 and section7schema3.
A pair is not a fullsection: do not emit store_count2 as a completed section7.

For each owner letP be its12800/434176byte claim slice. Conservative packed
complete-call envelope: ownercapture3P, ownerrestore3P, adaptercapture5P,
adapterapply4P. Include liveclaimP, callerinput/outputP, publicationduplicatesP,
and adapterconstructor allocations even when reclaimed. No new packed staging
otherwise. Forage largest5P=2170880bytes, Fishing5P=64000. Add unchanged nonclaim
packed fields in the same live object, unrelated/borrowed owners, external
snapshots, native/object/container overhead and codec stream buffers separately.
These are slice allocation bounds, not full-process peak/RSS or a sub1MB claim.

Before resuming a world, coordinator verifies actual row/Directory/Job association,
reference liveness policy, habitat/zone presence, per-habitat effort capacity,
checked aggregate totals versus SAVED section4 effort/quota columns, Forage
orderkey provenance and all othercrosssection invariants. Claim-only restore
must not silently rebuild/repair these values. All fixed-row legal quantities
sum safely even before grouping:512*6=3072 fitsi32;8192*1180000=9666560000 fitsi64.
Those domain bounds do not replace checked arithmetic in the world reconciler.
Do not call unsafe old rebuilders on raw decoded streams. External-file loading
remains gated on complete reconciliation and rollback. No public-API arithmetic
bug is claimed from forged codec-only data.

## Required tests and review

- Parent tests cover fixeddefaults, everycaller/live shape, flags, blanks, all
  ref/domain boundaries, stalegens and exactrow0/lastrow identity, capturecount
  mismatches, oldpayload/count ignored onrestore, independent duplicatedarrays.
- Snapshot allnonclaim module fields and borrowedidentities on success/failure,
  explicit othersection effort/quota sentinels and scratch; no collaboratorcalls.
- Preserve distinct createdtick/PID values including0/MAX acrossrestore. Pin
  sourcecount/orderkey diagnostics, successclear and firstgateprecedence.
- Public real Fishing/Forage claims; snapshotonlyclaims, restore into same other
  worldstate, continue release/collect/cancel and compare future authoritative
  values. Preserve real stale claim cases for normal purge; no invented fixtures
  presented as valid worlds. Retain loader-reconciliation limits in test titles.
- Both adapters shape/null/barrier/refusaldetail/order checks; literal allfield
  mapping and recapture equality. Codec-admitted quantity0/>1180000 or fish>6
  refuses ownerverbatim, input/storeunchanged, no repair.
- Independent empty/sparse/full literalwire goldens before implementation, actual
  defaultcap probes, existing section7codec regression. Do not overstate framing
  probes as an integrated disk writer or wholeworldcontinuation.
- Mutants drop Forage ordering-key publication, rewrite Fishing habitat effort,
  skip Forage amount bound and skip Fishing amount bound must fail. Fullsuite,
  staticchecks, editor, exactheadCI and independent source review required.
- Registry Fishingclaimcount category2, newownerdiagnostics/category3 and new
  statelessadapter row; canonical fieldcounts/widths unchanged. Record oldsource
  cache/rebuild comments as legacy-only; no behavior change to oldmethods.

## Independent review disposition

No contract blocker. Ordinary review findings are resolved as follows:
- SAVE-CLAIM-RECONCILIATION, specified by PLAN-CLAIM-RECONCILIATION and required
  by SAVE-ORCHESTRATOR, must implement NEW read-only checked computations of
  per-habitat effort and per-zone quota claims against SAVED section4 values.
  Never call old rebuild/validate helpers or repair saved aggregates/orderkeys.
  Reconcile missing habitats even if the legacy counter allowed destruction;
  Forage zero PID is an explicit provenance anomaly for a live Job.
- Shape/count malformed-source tests deliberately use replaced/shrunken caller
  arrays and owner reflection (test-only), not a purported healthy public witness.
- Capture's staged codec gate is defensive owner/codec equivalence. Owner domains
  are stricter; no reachable healthy failure is promised after owner success.
- Forage _claim_count is ALREADY category2 in persistence_state_registry.md;
  retain it. Move Fishing _effort_claim_count from scratch to category2. Canonical
  record_count, owner/schema versions and all18declared fields remain unchanged.
- Publish group Array containers only from the private staged OwnerRecord. They
  may transfer ownership because that stage never escapes; never reuse a caller-
  visible group container. Packed publication buffers are independent duplicates.
- Code echo intentionally matches Gear/Reservations/StockAge owner precedent.
  No new row/detail state field. Separate claimdiagnostics preserve Forage's
  independent existing section1 diagnostic; both interfaces remain stable.
- Owner methods are low-level synchronous primitives with caller-enforced
  quiescence. Held-clock check belongs to the adapter. The modules' current
  mutators have no yield/reentry, so _pending_* are stale scratch at a completed
  boundary, not executable busy flags. Do not infer quiescence from their values.
- Explicitly forbidden in addition to the earlier list: purge_stale_effort_claims,
  release_cancelled_effort_claims, purge_stale_claims, release_cancelled_claims,
  release_claims_of_zone, reconcile_claims, run_midnight, collect_claim, release_claim.
- Literalgoldens mean independent byte generator plus pinned digests and lengths,
  not embedding434298-byte text blobs. Existing preimplementation generator covers
  empty/sparse/full for both owners; keep full Forage within the bounded probe.

Required four mutants remain. Additional sourcecount, compaction and reference-
namespace defects must be covered by direct assertions; add a mutation only when
it adds meaningful distinct evidence. A correct independent duplicated packed
array may be behaviorally indistinguishable from COW sharing under public tests;
source review must verify explicit duplicates without claiming an equivalent
mutant was killed.

