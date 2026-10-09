# 1096 — Preserve completed endpoints across Room confirmation

2026-10-03. Component implemented and independently reviewed; no first-entry permission.

## Scope and transaction

Confirming a Room publishes its real identity, exact pending claims and a new
Space revision. Existing Locations and Routes must not retain proofs for the
previous revision. An unbuilt Room is not an excavation Site, so borrowing an
unrelated Sites publication window is incorrect.

Locations binds the sole actual RoomOrders authority weakly at quiescence.
`begin_room_prepare(cold_token, space_token, room, room_type)` accepts only the
original actual Budget and the sealed future Room candidate. The actual Orders
reader `room_companion_refusal` compares exact Space and Budget instances, both
operation tokens, the full Room/type, retained allocator observation and unchanged
original/private plan. It performs no provider or Space callback. The existing
`is_publishing_room_admission` supplies the final same-stack publication proof.

The real callback order matters: `room_plan_refusal` runs before Space seals;
`room_prepared_refusal` runs afterward. The latter may begin the Locations
companion, refresh every existing endpoint against the sealed future, then seal
Locations and the corresponding Routes/certificate companions. There is no
fallible reconstruction after Directory allocation. Publication is actual Room,
exact Space, Locations, then Routes and its certificates. Locations requires the
successful exact Space token as well as the actual Orders callback; a different
candidate published at the same numeric revision cannot substitute.

This increment only refreshes completed, already-existing immutable endpoints.
Addition, removal and load cannot run in the Room context. Every live endpoint
must retain its full generation, payload and Inventory identity and have a proof
for the candidate revision before sealing. Refusal preserves all live banks and
the caller's lease. Source, Inventory-retention and exact-token checks remain;
callback reentry poisons the outer attestation. Reverse authority links remain
weak, with a strong borrow for each synchronous call.

## Memory and bounded work

No authoritative column, wire image, allocator or permanent bank changes. The
new transient full Room pair (8), Room type integer (8) and context boolean (1)
add 17 logical bytes. The fixed topology control census becomes 2,085 within the
existing 2,112 ceiling; the complete 1,041,728-byte reservation is unchanged.
The weak Orders handle/native call overhead remain separately obligated in the
existing bindings/native allowance.

The Room path checks actual Space allocations against R6144/O2048 and Domain
survey rows against K8192 before callbacks or copies. A sequential Locations
proof uses one future snapshot, 48R+16O = 327,680 bytes, two bounded fragment lists
24K = 196,608 bytes, and 384 bytes of packet scratch. The maximum retained Room
cell copies are 24N = 393,216 bytes at N16384. Including the existing 2,048-byte
Room control allowance gives 919,936 logical bytes, below the original actual
1,048,960-byte lease. Prior admission surveys/footprint scratch and later route
surveys must be released before the next proof begins; this is not permission
to overlap their independent peaks. The preallocated banks are counted once in
their existing owner reservation. Native Array/packed headers and whole-process
growth remain unmeasured.

The extra row check is a bounded capacity scan of local packed facts, not a
per-resident or per-tick source survey. Endpoint geometry refresh retains the
existing shared finite operation budget and exact union checks.

## Explicit boundary

Refreshing the existing circulation does not create a first entrance, surface
anchor, paid cut, support, connector, work contact, profile certificate or Job.
Those actual owners and fixed construction-frontier content remain separate.
The pending Room stays solid. Surface-anchor registration requires independently
established real terrain/support truth and is outside this increment.

## Verification

The clean CI-style import and strict wrapper runs passed 36 Locations tests /
1,148 assertions, 30 actual RoomOrders tests / 1,533 assertions, and 40 Routes
tests / 9,175 assertions: 106 tests / 11,856 assertions / zero failures total.
Every strict and raw footer reports zero unexpected errors/warnings and zero
object/resource leaks; expected and tolerated diagnostics are also zero.
The analyzer reports zero warnings in two files. Full logs and exact source
hashes are retained in
`docs/validation/evidence/underground-room-location-companions-2026-10-03/`.

The new fixture follows actual RoomOrders pre-seal/post-seal/publication order.
It covers an omitted endpoint, late refusal/retry, original request drift,
wrong full Room/token/type, unavailable exact publication window, wrong Space
receipt, callback reentry and replacement of the original Budget lease. Actual
Inventory retains its full endpoint/payload revision through confirmation;
removing its support in the sealed future refuses before any Room allocation.
The first rejected run exposed a fault-probe timing error in the new fixture,
which is preserved honestly with the evidence. Production source was unchanged.

Independent source review accepted the exact source and test hashes, including
original-lease preallocation, full Room identity, guarded callbacks, complete
existing-row refresh, exact publication receipt, final retention checks and the
byte census. The reviewer did not repeat the runtime suites. These tests use synthetic initial
surface geometry and admission-profile permission only to isolate the actual
owner composition. They do not establish a surface entrance or productive
contact. Whole-demo and 256-resident qualification remain separate.

## Sites companion lifetime coordination

The forthcoming real Sites ClaimBatch must be prepared after Locations and
Routes are sealed and their copied surveys have dropped. Locations.seal drops
its retained Snapshot; later prepared and publication checks inspect current
source/scope, packed rows, retention and exact receipts without rebuilding a
survey. A concurrent extra 8N cursor bank would exceed the shared ceiling at
the largest room even before its controls. The agreed later Sites step repeats
its read-only key proof under the original lease and prepares the real batch
before Directory publication. Sealed Locations banks are already counted in
their existing reservation and need no later allocating refresh if all exact
proofs remain current. No identity is written between the sequential proofs.
