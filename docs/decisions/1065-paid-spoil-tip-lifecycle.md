# 1065 — Paid spoil-tip preparation, compaction and reclamation

Date: 2026-10-03 · Status: Implementation packet; shared operation bridge pending

## Scope and adopted economics

UG20 implements SET-MOVE-ECON-001 ECON-002/004/005 through actual
Construction, Jobs, Work, Gear, Inventory and Reservations. It does not replace
actual hauling with a remote counter. The player designates an existing 2 m
exterior tile. Workers prepare it for 4000 milli-WU using BUILD and a tool.
Only delivered excavated earth may be compacted: q milli-U costs ceil(q/4)
milli-WU of KEEP work. Reclaiming q costs ceil(q/2) milli-WU of BUILD work.
Closing an empty tip costs 4000 milli-WU of BUILD work. These values are adopted
by the existing amendment, not new balance choices in this record.

The tip has 400000 g embedded capacity. Capacity is reserved for the whole
incoming amount before productive compaction. Embedded earth is unavailable
to recipes. Reclamation locks source stock, debits it only after successful
output commit, and creates the same quantity with the established
SPOIL_RECLAIM provenance. Its input is a source lock, not delivered material.
Cancellation releases that lock without a loose refund or loss from embedded
stock. Compaction consumes real delivered inputs into shared WIP at work start;
a started cancellation returns 80% per item and books the remainder as loss.
Retained work requires repayment of the full input bill before resumption.

Removing a designation must never clear embedded stock, create another virgin
yield, release capacity that is still occupied or reset ecological soil history.
Reclaim the stock and complete paid empty-tip closure first. Every operation
requires its actual adjacent safe worker/material/output contact and protects
occupants, fields, resource ownership, structures and protected routes.
Preparation reserves and blocks its real footprint; a ground pile must be
moved first. The existing terrain height/slope placement constraints apply.

## Shared operation owner

Use real Construction project identities with a distinct SPOIL_TIP purpose.
The existing surface and excavation purpose IDs remain unchanged. Its subject
is explicitly a local tip row/generation in the bound actual World, not a
Directory EntityRef. A typed operation router must prove that exact namespace
and World, subject and project generation, immutable operation/quantity bill,
actual job skill/tool/worker, delivered material, output capacity and geometry.
No fake Building or Room may supply a requester or footprint identity.

The UG07 shared operation increment supplies project-specific bill readers,
actual Work preflight and same-call-stack publication attestation. Reuse the
single Funding receipt arena owned by the bound Sites/Construction composition.
No second per-project receipt table or duplicate Inventory is allocated.
Compaction uses actual modular-input reservation ownership. Reclaim commits
Inventory output first only after source, work and geometry preflight, followed
synchronously by non-failing physical source publication. Retrying a completed
job spends no further work, XP, inputs or durability. A direct publication call
outside that exact transaction must refuse.

## Proposed finite owner schema for engineering review

The independent `spoil_tips.gd` owner will hold packed tip facts, with an explicit
capacity C no greater than the existing 16384 exterior tiles. Capacity is a
construction argument with no production default. A stable local handle uses a
row and generation. At most one active economic operation holds a tip at a
time; other orders remain queued. This serializes the one physical source and
does not impose a new global worker or population limit.

| Packed fields | Width / extent | Bytes |
| --- | --- | ---: |
| present, retired, prepared | 3 B8[C] | 3C |
| generation, tile, project slot/generation, operation | 5 I32[C] | 20C |
| embedded, operation quantity, locked source, reserved incoming quantity | 4 I64[C] | 32C |
| retained earned work for CLOSE, COMPACT, PREPARE, RECLAIM | I64[4C] | 32C |
| retained exact COMPACT and RECLAIM quantity contracts | I64[2C] | 16C |
| Persistent row subtotal | | **103C** |
| Derived lowest-free heap | I32[C] | 4C |
| Derived tile-to-row index | I32[16384] | 65536 |

World identity, configured capacity and lifetime compacted/reclaimed conservation
counters are persistent owner header facts and must be counted separately.
Transient permits, integer results, counter controls, capture/restore buffers
and actual simultaneous load/validation lifetimes also require explicit
accounting. Both directions of the tile map are audited; reads validate full
row generation and actual World binding. Closed empty rows may be reused with
an incremented generation; exhausted generations retire. Soil history belongs
to its existing owner and is never rewritten here.

Retained work for each variable-quantity operation is valid only for the same
tip identity and exact q contract. A mismatched quantity cannot inherit it.
Changing that contract must not silently transfer earned work or erase funded
WIP. The concrete coordinator will expose a refusal until the prior operation
is resolved; it must not invent a free progress conversion. Prepare and closure
have their separate fixed-work records. Source locks and incoming reservations
are live physical facts, not predicted capacity from unfinished work.

These independent maxima do not grant a production allocation pack. The shared
underground composition must admit all owner and cold-copy lifetimes together
under the existing 100000000-byte budget before activation. The currently
published baseline leaves 5206314 logical bytes before this owner, sparse space,
Room/Furniture discriminators, profiles and layout/load staging. Reducing actual
configured arenas or other explicit composition choices is engineering work;
reporting independent maxima as if they fit is not permitted.

## Implementation and evidence gates

1. Review the exact owner schema and shared router signatures before source
   edits. Preserve full identities and a single receipt arena.
2. Implement preparation, capacity/quantity contracts, retained work, source
   locks and non-failing publication with actual core owners.
3. Prove compaction/reclamation and cancellation with real Inventory lots,
   Work contributions, tools, metadata and atomic failure at output capacity,
   source reuse, changed contact and final publication.
4. Exercise legacy save refusal and register every persistent field before
   integrating the full composed codec in UG16. Round-trip every phase and
   retain conservation across retries and cancellation.
5. Connect actual ground siting, adjacent containers and paid hauling to the
   village. A synthetic geometry fixture is test evidence only; it cannot
   activate missing movement/support inputs.
6. Include tips in whole-world earth conservation: initial plus virgin yield
   equals loose inventory, shared WIP, backfill, tip stock and cancellation loss.

This packet is not implementation or runtime evidence. UG20 remains running
until the actual economic, spatial, hauling and save-owner contracts above
have independently reviewed source and recorded test diagnostics.


## Isolated ledger implementation checkpoint

The reviewed owner implements the stable tip identity, exact-q retained work,
whole source/capacity claims, conservative publication guards and paid closure
rules above. It allocates **107C+65536** live packed bytes (103C persistent plus
derived indexes), independently of its persistent header and numeric controls.
A cold audit needs C additional bytes. Its diagnostic image returns48+103C bytes
but its actual capture peak is **48+119C** packed scratch: the output coexists
with a converted32C earned-work column or the final16C exact-q column. These
cold operations are sequential. Native buffer growth and object/Variant storage
remain separately unmeasured; do not confuse output length with capture peak.

Sixteen strict component tests passed with747 assertions, zero failures, zero
unexpected diagnostics and zero exit leaks. The focused analyzer reported zero
GDScript warnings in two files. These tests use actual Construction identities
and progress with a deliberately synthetic publication/accounting adapter.
They do not prove real Inventory funding, worker/tool eligibility, physical
haulage, siting or save/load. The initial run failed one test's injected heap
restoration; the corrected fixture restores the actual saved value rather than
assuming heap layout. Both logs are retained in the evidence packet.

Independent review of the exact source/test hashes found no functional blocker
and corrected the capture-peak accounting above. Source publication remains
inert until the exact typed paid operation owner binds. UG20 remains running;
its actual shared modular coordinator and world integration are still required.


## Actual operation adapter increment

The tip store exposes read-only physical admission checks before Construction
allocates a project. These validate the candidate tile/handle, preparation state,
source or incoming capacity, idle ownership and exact retained-q contract. They
do not reserve stock, allocate an identity, or attest geometry or payment. The
existing real-project checks repeat those conditions before publication and
then validate the exact remaining-work/accounting identity. This keeps a
rejected order from consuming a Directory generation.

The concrete `SpoilWork` owner supplies the shared modular router's immutable
quote from that ledger, the actual catalog and adopted Work prices. One cold
pending admission carries the requested tile/operation/q until the router has
allocated the real project. A nested weak Publisher proves actual Construction
purpose, local subject, operation and same-call-stack owner publication; it
never recursively prices a project through its own facts callback. Later facts
come from the live tip/project relationship, not a second per-project table.

Physical siting/contact/support/route checks are a separately typed composition
with the actual World and existing owners. Each admission/transition stages all
fallible work before an Inventory or owner mutation. Publication is synchronous
and non-failing; source/contact facts are captured before closing a tip can
retire its handle. A refused, missing or expired binding supplies no permission.
This interface is not a replacement terrain store or an approval of fabricated
worker clearance. Actual ground binding and village haul dispatch remain in
the final UG20 integration packet.
