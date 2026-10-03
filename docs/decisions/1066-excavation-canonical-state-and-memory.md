# 1066 — Declare excavation history, funded inputs and their memory

Date: 2026-10-02 · Status: Accepted engineering implementation, validated 2026-10-03

## Decision

Register the actual state implemented by decision1056 before treating its
integration as a passing specification checkpoint. Both new owners live in
section6: `excavation_inventory` and `excavation_sites`, each at owner schema1.
The registry identity becomes `RWL-CANONICAL-REGISTRY-2026-10-02-UG2`, registry
version9 and section6 schema3. Existing owner ordinals, fields and exclusions
remain unchanged. This is a declaration and allocation reconciliation; UG16
still owns the composed codec, restore, source-version checks and replay proof.

## Exact state and ordering

Funding adds sixteen packed source fields and two scalar records. Keep the
capacity and free count, the exact used free-stack prefix/pop order, full
Construction/output references, receipt chains, item/quality/provenance/recipe,
quantity/age/remainder and per-item cancellation loss. Hashing only quantities
would permit a refund to change its actual lot attributes. Sorting the free
stack during restore would change the next receipt allocation.

Sites adds twenty packed source fields and twenty scalar/domain records. The
scalar records include the immutable world's full reference, datum, minimum
and dimensions, sparse capacity/count, domain volume and physical conservation
counters. Packed state includes permanent physical keys, phase/support/source
flags, embedded earth, earned work for each of the five operations, full
room/project/job/output references and registered worker generation/face.
Retiring the last paid project cannot remove this history from saves or hashes.

The sorted key/row index and Job lookup remain derived category2 state and are
rebuilt from the authoritative fields. The new earned-capacity scalar is also
derived. Delivery totals, staged receipt data, synchronous publication permits
and borrowed owner wiring are category3. Neither classification makes their
live allocation free. No persistent column was demoted to make a gate pass.

The new census is **55 owners,681 declared fields,673 hashed records and602
persisted packed source fields**: exactly two owners,58 records and36 packed
fields beyond decision1060. The unchanged eight exclusions remain excluded.
Generated declaration order is section, ASCII owner key, then explicit field
ordinal. Independent literal tests pin the new identity, counts, exact field
sets/types and the free-stack/physical-work ordering.

## Bounded storage and unchanged proof gates

Sites takes an explicit caller budget S, at most73909 permanent records. Its
packed arena is `113*S +36880` bytes; at the maximum this is8388597, eleven bytes
below8MiB. Another row would exceed the arena. History never evicts or recycles.
This engineering bound does not choose a production room count, map depth or
number of floors. Funding takes R in1..32768, also bounded by the actual
Reservations pool. Invalid requests refuse before allocation; neither owner
silently truncates a request into an accepted smaller world.

The capacity sidecar's existing grammar and zero-quarantine checks remain
unchanged. Each runtime capacity has one bounded source assignment. Earned
work's allocation uses a derived `_earned_capacity`, bounded by
`MAX_SITE_CAPACITY * Contract.OP_COUNT`, so the sidecar can prove the maximum
without inventing support for mixed dynamic products. Memory arithmetic also
checks the relation to S and the five protected operations independently.

The historical Astra Cycle3 census at388f4f4 stays unchanged. Relative to that
snapshot the new totals differ by48 prose rows,21 equalities,27 upper bounds,
26 other record shapes,6 expression texts,74 canonical records,49 packed fields
and3 owners. Earlier decisions explain the prior part; this decision adds35
capacity rows (9 equalities/26 bounds),22 scalars and the free-prefix shape.

## Logical payload ledger

| Allocation | Exact maximum bytes |
|---|---:|
| Funding persistent packed state:2324480+48R |3897344|
| Sites persistent packed state:101S+4096 |7468905|
| Sites derived packed indexes:12S+32768 |919676|
| Funding/Sites packed transaction scratch:6144+40R+16 |1316880|
| Numeric controls/domain:132; derived earned-capacity:8 |140|
| Numeric synchronous permits/results/counts and Work publication reference |75|
| New mutable logical payload |**13603020**|

The packed total is13602805. Scalar numeric values are additional; native
Variant/String/object headers, allocator overhead and imported resources still
need actual measurement. The75-byte numeric scratch term is Sites'32-byte
permit/candidate values, three IntResults'27-byte value/success payload,
Funding's8-byte staged count and Work's8-byte publication reference. Existing
Inventory journals and Reservation arrays are reused, not allocated again.
Constructor-only domain-copy scratch occurs before the large arenas allocate;
it does not require another simultaneously live arena. Local test `state_bytes`
images are explicitly not the production save path.

The shared declaration is `55*16 +681*15 +10008 =21103` logical bytes,1674 above
decision1062. The architecture's live maximum therefore advances as follows:

| Current declared quantity | Before | After |
|---|---:|---:|
| Auxiliary payload |27302640|39588705|
| Planned allocated payload |72669312|86274006|
| One world plus unchanged8388608 reserve |81057920|94662614|
| Arithmetic headroom below100000000 |18942080|5337386|
| Additional candidate mutable state |66423763|80026783|
| Rejected two-world peak plus reserve |147481683|174689397|

The full modular composition remains **unqualified**. Sparse spatial banks and
snapshots, room layouts, profile/cargo catalogs, render caches and the future
UG16 decode/rebuild/rollback lifetimes must fit the same whole-world limit.
Independent arena ceilings are not additive permission to exceed that limit.
No implemented load staging means an unimplemented obligation, not zero
required memory. The existing rejected two-world approach remains rejected.

## Validation

The independent source and arithmetic review found no blocking issue. All 32
specification CI commands passed on the assembled source, including 494 proved
equalities, 73 proved upper bounds and the 190 capacity-audit self-checks.
The focused canonical suite passed 54 tests / 4070 assertions with zero
unexpected diagnostics or leaks; its analyzer reported zero warnings in two
files. [Exact logs and source hashes](../validation/evidence/underground-registry-1066-2026-10-03/README.md)
record the tested scope and independent review. Updating a declaration never
sets `release_save_ready` true or establishes production save parity.

## Authority

AGENTS.md integer/SoA and memory requirements; ARCH-MEM/ARCH-SAVE and REG-R01;
the adopted underground economy amendment; decision1056's actual owners;
Brendan's authorization to implement and integrate the complete underground
building design. No excavation price, source quantity, room purpose or
player-facing level limit changes here.
