# Exact Gear owner columns

SAVE-GEAR-R01 · version 1 · Astra draft for independent review · 2026-09-19

Scope: exact section7 owner2 capture/restore, not whole-world loading. Preserve
bare gear row identity, occupied/equipped flags, lot/owner/claim references and
wear/manufacture values. Do not replay begin_restore/restore_row/finish_restore:
that legacy route publishes rows individually and loses equipped state. Keep
legacy entry points unchanged. No codec/schema change, gameplay activation,
new gear kind, catalog redesign, or claim-domain repair is in this packet.

## Interfaces and record

Nested GearColumns contains native row_capacity and these12packed arrays in
wire order: occupied:u8, lot_slot:i32, lot_generation:i32, item_id:i32,
durability:i32, durability_cap:i32, owner_slot:i32, owner_generation:i32,
manufacture_recipe:i32, equipped:u8, claim_job_slot:i32, claim_job_generation:i32.
Constructor defaults R16384, records requested metadata unchanged, allocates
clampi(requested,1,16384); malformed requested metadata is subsequently refused.
Canonical blanks exactly match clear(): slots and item_id -1, all generations,
durability/cap/manufacture/flags 0. No borrowed refs, caches or derived arrays in
this record. 42R packed bytes. Preserve all12 arrays independently on publication.

Owner APIs (unique names avoid Inventory's generic duck-typed boundary):
copy_gear_columns_into(out:GearColumns,definitions:ItemDefinitions)->bool;
restore_gear_columns(columns:GearColumns,definitions:ItemDefinitions)->bool;
last_column_refusal()->StringName; canonical_detail()->String code echo;
column_inventory_matches(inventory:Inventory)->bool, pure identity predicate:
true only for nonnull argument and (_inventory==null or _inventory==inventory).
The identity predicate does not attest a world or write bindings.

New _last_column_refusal is category3, the only owner field changed on failure;
success clears it. Both owner operations refuse _restoring. Preserve seed
buffers/count, _wear_math and borrowed Inventory/Directory/Residents identities
on every path. Successful seed leaves count24: this is residue, never a busy
flag. Completed synchronous boundary and no concurrent mutation are caller
obligations. Owner APIs do not call Inventory/Directory/Residents, perform
attestation, invoke existing audit(), bind collaborators or replay hot mutators.

## Validation and publication order

Codes COLUMN_GEAR_SHAPE, RESTORING, DEFINITIONS, OCCUPANCY, BLANK, REF, ITEM,
DURABILITY, MANUFACTURE, DUPLICATE_LOT, BINDING, SOURCE_CACHE, SOURCE_DERIVED all
use prefix COLUMN_GEAR_. First failing gate wins deterministically.

1. Null caller or metadata/12array shapes/R mismatch -> SHAPE. Check native
   owner R1..16384 and all12 live arrays plus free_heap have exactly R before
   indexing or allocating derived staging. Restore ignores old payload/counts,
   but requires valid construction metadata and array extents.
2. _restoring -> RESTORING, then null/unloaded definitions -> DEFINITIONS.
   Read exactly five compiled IDs for existing KEY_TOOL/NET/TRAP/ICE_KIT/
   OUTFIT_TIER2 into locals, with no capture_item_ids mutation. Missing IDs -1
   are valid; never require all five keys. ItemDefinitions is an actual typed
   loaded catalog; full coordinator owns verified catalog identity/provenance.
3. Validate all occupancy/equipped flags 0/1 across R first. Then ascending
   rows: inactive exact blanks; active lot slot0..16383/gen>0; owner either
   exact(-1,0) or slot0..352417/gen>0; claim either exact(-1,0) or
   slot0..8191/gen>0. Equipped requires nonnull owner. These are structural
   identities, not liveness checks. Preserve stale generations. Item>=0,
   cap>=0 and 0<=durability<=cap; manufacture BASIC0 or IRON1. After per-row
   fields pass, reject duplicate lot SLOT using a16384-byte bitmap (including
   same slot/different generations). No quadratic scans, Dictionaries or sort.
4. If any equipped rows, require existing is_equipment_bound()==true. This
   only checks three nonnull borrowed refs. Initial target binds before restore;
   reused world retains the same collaborator objects. No post-install blind
   bind: bind_equipment refuses when equipped rows exist. Owner does not check
   mirrors or call is_equipped_record; full-world reconciliation follows later.
5. Capture only: for any occupied rows, five source cache IDs must equal the
   five staged IDs. Empty source accepts either all five -1 or exact staged
   IDs; mixed stale caches refuse SOURCE_CACHE. Compare native counts to derived
   free/active/equipped totals, checking ranges before heap indexing. Validate
   heap live prefix is exactly the free set, no duplicates and min-heap property
   with an R-byte bitmap. Any valid heap permutation is admitted; tail ignored.
6. Capture duplicates all12 live columns into caller only after checks; never
   rewrites source caches. Restore privately prepares ascending free heap lengthR
   with -1 tail and derived counts, duplicates12 caller arrays, then publishes
   arrays/heap/counts and five staged cache IDs with no remaining fallible work.
   No input alias or failure partial write. Native metadata and bindings stay.

This deliberately preserves structural wire durability/manufacture/item values,
including unusual values accepted by old restore_row. Exact catalog membership,
per-kind cap/manufacture validity, equipped-tool subtype, lot item/quantity,
owner liveness/kind/mirror, equipment biconditional, claim liveness and Work
bindings are full coordinator checks BEFORE resuming. Do not silently claim
this owner accepts a playable world merely because its arrays are well formed.

Two explicit stronger owner gates than existing codec: exact null reference
pairs and claim slot<8192. Existing public claim_for_job bounds8192, while the
codec bounds352418; do not change either here. Registry's claim-generation
wording and Jobs directory/typed-row mapping need separate integration ruling;
this packet preserves the live Gear API's admitted numeric domain and does not
reinterpret a generation. Owner refusal must be tested with codec-admitted
counterexamples. Bulk save is not a repair of malformed legacy restore data.

## Single-block adapter

New stateless core/save_gear_restore.gd; register category3. Follow existing
single-owner adapters and SaveHeader.Refusal convention. Owner2, R1..16384,
zerochildren, groups exactly2u8/10i32/0i64, everycolumnR. Validate all group counts
before indexing. No six-owner Record/second Inventory/reflection/callback.

capture(store,out,definitions,inventory=null): nullstore, out fullshape and
Rmatch, nullInventory, column_inventory_matches, Inventory open/poison flags,
then ownercapture private GearColumns. Populate a private OwnerRecord by literal
ordinals0..11, run Codec.owner_refusal, publish threegroups only after success.
apply(block,store,clock,definitions,inventory=null): nullblock,nullstore,
nullclock,heldbarrier,blockfullshape/Rmatch,nullInventory,identitymatch,busyflags,
Codec.owner_refusal, localGearColumns borrowing validatedblock arrays, then
ownerrestore (which duplicates). Adapter never acquires/releases barrier.
Codes SAVE_GEAR_NULL_STORE/BLOCK_SHAPE/NULL_INVENTORY/INVENTORY_MISMATCH/BUSY/
NULL_CLOCK/BARRIER_NOT_HELD; nullblock uses BLOCK_SHAPE. Forward owner/codec
codes verbatim. No definitions gate ahead of owner gate. No collaboratorwrites.
Unbound store's identity predicate cannot prove world association; coordinator
still owns that check. Bound store rejects a foreign supplied Inventory.

## Wire and memory

Payload100+42R; wrapper28 (key gear length4); fullblock128+42R=688256 atR16384.
Canonical owner42R; derivedheap4R; validationbitmap16384 plus captureheapbitmapR.
No new persistent packed field. Existing seed buffers add192bytes per owner.
Conservative complete-call packed envelopes counting disjoint constructor
allocations even if reclaimed: ownercapture131R+16384; ownerrestore134R+16384;
adaptercapture215R+16384; adapterapply176R+16384. Add existing192-byte seed
buffers; exclude native/object/container overhead, unrelated borrowed owners,
external snapshots and codec stream buffers. These are allocation accounting
bounds, not measured peak memory or RSS. Verify against implementation before
acceptance; do not omit input/output arrays or publication duplicates.

## Required acceptance

- Parent-authored tests: default/bounded R, requested invalid metadata, every
  input/live shape, fullflags/blanks/domain boundaries, duplicate slot including
  stale generation, canonical empty/sparse/full payload and literal wire probes.
- Capture wrong/range-invalid counts, duplicate/missing/nonheap free prefix;
  valid nonascending heap, arbitrary ignored tail. Restore ignores corrupt old
  payload/derivedvalues while preserving valid oldshapes and constructorR.
- Source cache mismatch and valid unresolvedkeys; restore refreshes all five
  IDs without mutation on refusal. Snapshot all owner fields and all three
  collaborators through every refusal and successful noncollaborator operation;
  input/output aliasing and repeated capture/restore independence.
- Real public create tool/net/trap/icekit/outfit as catalog permits; claimed
  fishing wear continuation, general wear + externally owned remainder, cancel,
  repair and lowest-free allocation identical before/after. No invented catalog.
- Real equipped-tool fixture with actual Directory/Residents/Inventory binding,
  capture preserves equipped byte/owner/durability; restore into correctly bound
  target, then actual inventory/mirror audits and unequip/equip continuation.
  Missing bindings refuse with no publication; stale owners are structurally
  preserved but explicitly fail subsequent world audit.
- Transactionopen/poison guards and boundforeignInventory rejection, heldbarrier,
  codec-admitted nullgeneration and highclaimslot ownerrefusal controls. Seed
  count24 legal residue; nonzero wear scratch unchanged; restoringwindowrefusal.
- Empty/sparse/full default-capacity literal goldens independently constructed,
  encode/decode where feasible, precise scope of owner versus fullsection probes.
- Mutants drop equipped restore, skip duplicate-lot guard and skip sourceheap
  validation must fail tests. Fullsuite/static/editor/exact-headCI, independent
  source review, corrected registry and capacity fingerprint required.

Independent review may require bounded corrections before implementation.
