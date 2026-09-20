# Exact reservation rows and reconstructed indexes

SAVE-RES-R01 · version 2, accepted for bounded implementation · 2026-09-19

Deliver the Reservations owner boundary and a separate single-owner section 7
adapter. Preserve row identities, eight canonical arrays and existing healthy
wire bytes (owner schema1, section schema3, registry5). This is not whole-section
assembly, Inventory restoration, or full-world acceptance.

## Record and owner API

Add nested `ReservationColumns` in reservations.gd with native metadata
`row_capacity`, `job_capacity`, `lot_capacity` and eight packed arrays:
`occupied:u8`; `r_job_slot`, `r_job_generation`, `r_lot_slot`,
`r_lot_generation`, `r_purpose`:i32; `r_quantity_milli`, `r_expiry`:i64.
Every array has row_capacity entries. Defaults exactly match clear(): slot
columns -1, all other columns0. Constructor defaults to the existing compiled
32768/8192/16384 bounds. Preserve requested metadata without clamping it;
allocate only clampi(requested_rows,1,ROW_CAPACITY) entries so invalid requests
cannot allocate unbounded storage and are subsequently refused by shape checks.
Record owns no Inventory, index arrays, owner object or persistent work buffers.
Owner metadata must remain in the original compiled native ranges; malformed
owner extents or array shapes refuse SOURCE_DERIVED after caller shape checking.

Public methods (unique, not Inventory duck-typed names):
- copy_reservation_columns_into(out:ReservationColumns)->bool
- restore_reservation_columns(columns:ReservationColumns)->bool
- last_column_refusal()->StringName
- canonical_detail()->String, returns String(last_column_refusal()).

New `_last_column_refusal` is category3; the only owner field written on failure.
Success clears it. Existing `_math` and `_pending_new_rows` stay untouched on
success and failure; no changes to existing mutators or diagnostic APIs.
`_pending_new_rows` may retain an old value: `_preflight_rows` recomputes it
before every fresh-row-count read. Test that the next claim reports its actual
new-row count. canonical_detail is intentionally the code as text; no separate
diagnostic buffer or row detail is implied.
No new binding is introduced. Do not call clear, claim_batch, release, audit,
reserve_lot or any external callback during column operations.

Shape: nonnull record, metadata exactly equals this owner's three constructor
extents and all eight arrays exactly row_capacity. Capture checks output shape
first, then live canonical and derived shapes and native counts, then validates
live canonical payload and derived indexes. A caller shape error is SHAPE;
corrupt live shape/counts/indexes is SOURCE_DERIVED (canonical live semantic
errors retain their specific payload codes). Restore checks record shape,
then payload, builds all private derived outputs, then publishes. It can replace
a malformed old canonical payload; no validation of old payload is needed.
The existing object's construction extents and array shapes remain required.
No partial canonical or derived publication on any refused input.

Codes, exact StringNames:
COLUMN_RESERVATION_SHAPE, COLUMN_RESERVATION_OCCUPANCY,
COLUMN_RESERVATION_BLANK, COLUMN_RESERVATION_REF,
COLUMN_RESERVATION_QUANTITY, COLUMN_RESERVATION_EXPIRY,
COLUMN_RESERVATION_JOB_GENERATION, COLUMN_RESERVATION_LOT_GENERATION,
COLUMN_RESERVATION_DUPLICATE, COLUMN_RESERVATION_OVERFLOW,
COLUMN_RESERVATION_SOURCE_DERIVED.
The output/input record is unchanged on refusal, including any aliasing among
its arrays. Every installed or exported canonical array is a separate duplicate.

## Payload validation and private index construction

Validate before indexing by a supplied slot. Order is fixed:
1. All occupancy bytes are0/1, ascending row.
2. All inactive rows are exact blanks, ascending row and ordinal1..7.
3. All active fields, ascending row: job slot in [0,J), positive generation;
   lot slot in [0,L), positive generation; quantity>0; expiry>=0. Packed i32
   bounds purpose and generations. Any row slot or generation failure here
   returns COLUMN_RESERVATION_REF; JOB_GENERATION/LOT_GENERATION codes are
   reserved for mixed generations in the later group scans. Purpose is opaque signed i32, no catalog
   domain; expired leases are retained, no clock comparison or sweep.
4. Job slot groups: first scan the whole sorted sequence for one generation
   per slot (JOB_GENERATION), then scan for duplicate full
   (job_slot,job_generation,lot_slot,lot_generation,purpose) keys refuse.
5. Lot slot groups: first scan for one generation per slot (LOT_GENERATION),
   then scan checked positive quantity sums per lot; each sum must
   fit i64. Use local IntResult or MAX-total subtraction, never owner math.

The unchanged codec checks fields but not these cross-row properties or reduced
constructor extents. Codec-valid/owner-invalid is deliberate and must retain a
specific owner refusal. Do not modify the wire/codec validator to conceal this.
Do not reject a job's sum across different lots merely for exceeding i64; current
claim APIs admit such a set. The existing unchecked job-total accessor is a
separate arithmetic audit obligation. Per-lot overflow contradicts the invariant
that every lot has an i64 reserved total and is refused here.

Use deterministic packed bottom-up mergesort of occupied row indices, two local
PackedInt32Array buffers of lengthR, sorting twice sequentially:
- job order (job_slot,lot_slot,lot_generation,purpose), ascending, stable row tie;
- lot order (lot_slot,job_slot,job_generation,purpose), ascending, stable row tie.
Comparisons must compare fields directly, never subtract signed purposes.
Validation and rebuilding are O(R log R + J + L); no quadratic insertion,
Dictionary-per-row, recursion, public row replay or world allocation.

Build a private derived record containing `_free_heap`, `_job_head`, `_lot_head`,
`_job_prev`, `_job_next`, `_lot_prev`, `_lot_next`, active/free counts, and a
local refusal. All arrays initialized to-1. Fill free_heap prefix with ascending
free indices; its unused tail is-1 in restored owners. Build each intrusive list
by linking adjacent entries in its sorted sequence. These private arrays are
never published to the caller's record. Install them only after validation;
they may transfer directly to the owner because private staging does not escape.

Capture additionally checks the existing derived arrays before exporting:
all heads and four links equal the private expected arrays (including inactive
links); counts match occupancy; live heap prefix has every free row exactly once
and satisfies min-heap parent<=child, with bounds checked before membership
indexing. The heap's unused tail is irrelevant and may differ. Any valid heap
permutation is accepted; it must not be compared to the ascending rebuilt array.
Precisely: check free_count == R-active_count before reading its prefix. For
each i in [0,free_count), bounds-check heap[i] into [0,R), then reject occupied
or duplicate membership. For i>0 require heap[(i-1)/2] <= heap[i], with integer
division. Read no heap entry at or beyond free_count.
Use a local R-byte membership buffer if needed. Never call existing audit on
malformed derived indexes: its traversal is not a total hostile-shape validator.
Refuse corrupt source; do not repair it as a side effect of capture.

Restore installs eight independent canonical duplicates, private derived arrays
and recomputed counts. The restored -1 heap tail is noncanonical construction
residue; later allocations may leave stale values there. Never capture, compare
or hash that tail. Preserve exact occupied row indices. Lowest-free-index
allocation and semantic chain order must match future public operations even
when source heap layout differed. There is no reservation row generation.

## Separate adapter and caller obligations

New `save_reservations_restore.gd`, preloads owner, Codec, SaveHeader, SimClock,
Inventory. Owner must not preload any save module. Works on one OwnerRecord,
never Codec.Record or a second Inventory. Public static methods:
- block_shape_refusal(block:Codec.OwnerRecord)->SaveHeader.Refusal
- capture_into(store:Reservations,out:Codec.OwnerRecord,
  inventory:Inventory=null)->SaveHeader.Refusal
- apply(block:Codec.OwnerRecord,store:Reservations,clock:SimClock=null,
  inventory:Inventory=null)->SaveHeader.Refusal

Null defaults deliberately refuse; supplied Inventory is mandatory for both
adapter entry points and used only for its pure transaction flags. It is not
bound, mutated, attested, or assumed to be the correct world automatically.
Caller must prevent reentry and invoke at a quiescent boundary. The supplied
clock is required only for the load barrier, not to expire or validate leases.

Codes: SAVE_RES_BLOCK_SHAPE, SAVE_RES_NULL_STORE, SAVE_RES_NULL_CLOCK,
SAVE_RES_BARRIER_NOT_HELD, SAVE_RES_NULL_INVENTORY, SAVE_RES_BUSY.
Forward existing codec refusal and owner code/detail verbatim. SAVE_RES_BUSY
is the code for either Inventory.is_transaction_open() or
Inventory.is_transaction_poisoned(); these are existing pure bool predicates,
queried in that order. No new Inventory API or private reflection is needed.

Shape is total: owner4, primary_count in1..32768, child_extents empty; typed
groups u8/i32/i64 lengths1/5/2 checked before indexing; each column lengthR.
Capture: nullstore -> out shape and out R==store.row_capacity -> nullInventory
-> open/poisoned Inventory -> owner capture -> private staged OwnerRecord
-> existing Codec.owner_refusal -> replace three output groups. Metadata stays.
Map all eight ordinals by Codec.storage_index_of; direct private array transfer
avoids redundant setters/duplication. Returned Refusal is authoritative if the
defensive codec gate refuses after successful owner capture cleared its code.

Apply: nullblock -> nullstore -> nullclock -> barrierheld -> blockshape and
R==store.row_capacity -> nullInventory -> open/poisoned Inventory -> codec
-> local record view using target J/L extents -> owner restore. Input buffers
may be borrowed by the local view because owner restore duplicates them.
No barrier acquire/release, bind, tick, claim/release, external callback or yield.
Clock/Inventory identities and every value field stay unchanged.

J/L are absent from existing wire. The target constructor extents are the
explicit interpretation context; apply refuses any row outside them. Do not
pretend a block recovers source J/L. Full coordinator constructs the configured
world, associates all blocks from one validated file, restores Inventory first,
then verifies every live lot's reserved total against rows, including lots with
NO reservation rows, using checked sums. Existing audit(inventory) skips
unreferenced lots, so it alone is insufficient. Validate job mapping/liveness
in that cross-owner phase, preserving the currently admitted structural pairs.
Any failed reconciliation requires the full world's disk rollback; this adapter
provides no rollback or valid-world publication.

## Evidence and memory

Canonical packed payload37R =1212416bytes maximum. Derived outputs20R+4J+4L
=753664bytes. Merge buffers8R=262144bytes. Heap validation bitmapR=32768bytes.
All staging is cold local allocation, not owner persistent scratch. Account for
record constructor buffers, existing owner, caller record, private derived and
new duplicates by phase; retained caller buffers are additional. No RSS claim.
Single-owner payload4+8*8+37R =68+37R; wrapper36 (key length12), block104+37R,
full1212520. Verify actual codec constants and byte hash baselines before edit.
No schema/registry canonical field changes.

Required tests: all eight fields and ordinals; empty/sparse/full/reduced extents;
exact row identities despite gaps; reverse semantic chain order; nonascending
valid minheap accepted, corrupt heap/list/count/source shape refused safely;
next lowest-free allocation; coalesce after restore without fresh row; per-job
and per-lot release and expiry/renewal; repeated replacement over populated pool;
expired leases and negative/extreme purposes; malformed row/blank/occupancy,
slot/gen/range/duplicate/mixed generations/per-lot overflow and every shape;
owner/input/Inventory/clock/scratch refusal atomicity; independent buffers;
codec-owner deliberate asymmetry; null/barrier/busy precedence; full-capacity
adversarial sort remains bounded. Actual world fixtures reconstruct matching
Inventory through public operations; this adapter restores only reservations.
Literal existing single-block hashes, focused/full/static/import checks,
independent contract and source review, negative controls and exact-head CI.

Correct registry prose: zero quantity is an inactive blank, never an occupied
empty claim. Preserve the source's actual positive-quantity rule. Clarify that
chain construction uses semantic key order, not appending ascending row IDs.

Review additions to required tests: live heap tail residue accepted versus prefix
duplicate refused; occupancy/count disagreement; aliased i32 caller buffers;
restore over malformed old payload; full-context acceptance versus reduced J/L
refusal; next claim's fresh count despite old pending scratch; owner-accepted
payloads pass codec gate; all adapter precedence steps; recapture byte stability.
