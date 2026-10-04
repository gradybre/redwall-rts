# 1083 — Atomic planned Room admission

Date: 2026-10-03 · Status: Allocator/Buildings and single-Room components verified; actual WorldBindings and batch admission remain open

## Decision

An accepted underground plan must create a real Room and its exact spatial
reservation together. A failed attempt cannot create then destroy an entity:
that would spend a persistent ID and advance a generation even if all visible
geometry were removed. The existing Directory's two min-heaps remain the only
allocators. There are no new allocator columns, transaction-sized copies,
generation rollback, fake surface parent or surrogate Room references.

The first bounded increment exposes a cold `CreateCandidate`: a weak exact
Directory, future full reference, kind, typed row and next persistent ID.
`peek_create_into` observes the existing global and per-kind heap roots.
`candidate_refusal` rechecks actual owner identity, the existing capacity and
living-population gates, both roots, generation and PID. `create_candidate`
performs that check immediately before using the existing allocator. A
refusal leaves every authoritative and derived Directory byte unchanged;
the existing nonpersistent last-refusal diagnostic may report the reason.

The packet is a mutable observation, not a reservation or sealed permit.
Another world with identical numbers cannot consume it. Changing a packet
does not change either heap or grant an identity: publication still requires
the exact current allocation tuple. A composed spatial candidate must pin
all its observed fields and reject subsequent changes. Candidates are never
serialized and must be discarded across reset/restore. Normal live-reference
readers continue to hide inactive slots. An unrelated retirement may leave a
candidate valid when both actual next choices and the PID remain unchanged;
there is no added global epoch that unnecessarily forbids that case.

Buildings adds a separate candidate preflight and
`designate_spatial_room_candidate`. The existing exact spatial authority must
attest the prepared candidate and permanent Room type, then separately attest
its exact synchronous room-publication window. Preparation alone permits no
mutation and does not open legacy `designate_spatial_room`. The actual
Directory publishes the expected full identity and Buildings uses its same
complete Room initializer, explicit underground discriminator, null surface
parent and zero surface TileLinks. Validity remains false and no service or
usable shell is granted.

## Composed boundary

The following single-Room coordinator increment will acquire the actual
shared cold-memory lease before copying plan/geometry data, prepare exact
Room-owned footprint claims through the separately owned sparse-space
bridge, revalidate both owners, then publish identity and geometry on one
synchronous call stack. SpaceOwner owns the narrowly attested future-Room
source bridge; arbitrary caller source facts are not an alternative.

Confirmation may publish `FLOOR_DATUM` metadata and explicit
`OBSTACLE`/`CLAIM_ROOM` reservation markers. Those reserve an accepted plan;
they are not physical unfinished cuts, supported void, completed shell or
services. Actual paid 1024-unit cubical excavation, permanent cut history,
worker/tool/material contacts and completion remain with the physical owners.
The live in-world drawing adapter must preserve the picked World, selected
level and immutable datum without rounding a finer preview into free volume.

This decision's first increment does not yet implement that composition.
Multi-entity RoomLayout/Furniture/Construction batch acceptance is another
following packet: single-entity candidate publication does not make a series
of otherwise fallible creates atomic.

## State and allocation

No persistent or derived owner columns or save images are added. One
caller-owned candidate carries 32 logical numeric bytes: full ref 8, kind 8,
typed row 8 and persistent ID 8. Its weak owner and object/Variant/reference
headers require native/control accounting and are not described as zero
runtime allocation. It is cold operation scratch, not one object per entity.
The read/validation/commit functions do not copy either heap or allocate
packed arrays. Buildings shares the existing Room row initialization path.
The later composed caller must include each simultaneously live candidate
and the geometry bridge's pinned copy in its admitted shared cold peak.

## Verification

Evidence: `docs/validation/evidence/underground-room-admission-2026-10-03/allocator/`.
The own worktree's demo assets were absent, its Godot cache was deleted, and
`godot --headless --path godot --editor --quit` completed with no ERROR or
WARNING lines. Four singleton CI shards use the unchanged strict runner:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Entity Directory candidate | 11 | 358 | 0 |
| Existing Entity Directory | 61 | 638 | 0 |
| Spatial Buildings | 18 | 321 | 0 |
| Existing Buildings | 63 | 906 | 0 |
| Total | 153 | 2223 | 0 |

Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 4 file(s)`.
Tests compare complete real Directory/Buildings images on stale, foreign,
tampered, wrong-kind/type, exhausted and duplicate refusals. They also cover
actual final generation/PID use, the 256 living cap, typed-root drift, safe
unrelated retirement and preparation versus publication. Spatial permission
in these boundary tests is explicitly synthetic; no live terrain, profile,
room-drawing, shared-budget or composed save/load qualification is claimed.

Independent parent-agent review accepted the four frozen source/test hashes,
with no remaining high or medium finding in this prerequisite. The reviewer
read the new adversarial tests and owner delta; it did not claim to rerun
the suites or qualify the later spatial composition.

## Narrow Terrain reader prerequisite

`Buildings.spatial_identity_into(ref, out)` fills a caller-owned four-int32
array with actual Building type, origin tile, rotation and state. It clears
the supplied array on every refusal and requires exact size four without
resizing. The existing full Directory kind/generation/reverse map and actual
Buildings presence/ref mirror gate every read. No result object or owner
column is allocated. The caller's reusable16-byte buffer belongs in its own
Terrain binding ledger; this function grants no terrain/contact permission.

The separate `terrain-reader/` evidence retains the initially rejected
fixture retirement call and corrected final strict84 tests/1340 assertions/0
failures. Both suite diagnostic/raw unexpected/leak totals are zero; analyzer
reports zero warnings in two files. Parent independently reviewed the exact
production reader and the adversarial test delta.

## Single-Room composition candidate

`RoomPlan` retains the exact painted canonical cells, explicit positive cell
size, world origin, authored height, selected level, permanent type, actual
World and expected sparse revision. These dimensions are request data, not
newly adopted geometry/profile constants. Confirmation does not force painting
onto the one-metre cut grid. Contiguous horizontal cell runs become exact
world-space metadata/claim boxes; concave absent cells and inner holes remain
absent. Actual bindings must qualify any hole policy and map the painted
outline to the separate whole1024-cube physical excavation/support contract.
No snapping, inflated Room outline or unpaid physical void is published.

`confirm_room` first marks its exclusive local stage, before any provider
callback. It then takes a fresh exact-world binding, acquires the room's shared
cold peak, then copies the request. It validates canonical connectivity and
unambiguous boundaries through the existing Footprint helper, prepares the
actual future identity, stages only its floor metadata and typed Room claim
markers, and asks the mandatory provider to prepare and recheck the real
terrain/profile/selected-level/cut-map companions. Space seals its exact
future source; all candidate and geometry checks precede the first live
identity write. The caller request and owned copy must still agree.
The retained-candidate and same-stack publication attestations read only
actual local owner identities and the existing weak binding. They invoke
neither provider callbacks nor Space validation. The provider's fresh physical
proof is completed before this window, so a reentrant binding callback cannot
change the sealed request after the final unchanged-plan check.

Only the synchronous Room publication window permits Buildings to consume
that exact candidate. The already sealed Space candidate then publishes its
actual created after-facts; prepared companions publish before the shared
peak is released. Every refused candidate aborts only its own Space token,
drops its companions and copied cells, resets candidate scratch, and then
releases only its own lease. A busy foreign Space stage or shared lease is
left alone. The Furniture router's public discard path explicitly refuses
the separate Room-admission stage. Legacy creation/removal/service setters
cannot borrow this publication window.

The typed base provider refuses room cold admission, actual plan proof and
prepared proof. Component fixtures use real Directory, Buildings, Space,
Construction, Inventory, Jobs, Work, Gear and Funding owners, but explicitly
synthetic terrain/profile/whole-cut-map/shared-budget qualification. This
increment alone does not activate the live demo's draw/confirm command.
Full multi-owner paid excavation dispatch, accepted-plan editing/cancellation,
room shell/service completion, atomic RoomLayout/Furniture batches and UG16
composed save/load remain following owner integrations.

### Single-Room cold accounting

Two reusable packets add92 logical numeric bytes to RoomOrders: RoomPlan60
and Directory CreateCandidate32. Existing operation refs/action/token and
publication/cold-held flags are reused, giving151 logical numeric controls
for RoomOrders. Its copied cell payload is8N bytes with N bounded by the
actual Domain operation capacity and the existing16384-cell helper envelope.
The caller-owned original request is a separate lifetime and must also be
counted by its composer; borrowing it here does not make it free. The source
bridge's own pinned candidate and ordinary Space banks remain separately
accounted by their owner. No persistent field or save image is added here.

Footprint validation precedes `Space.begin_stage`, so its peak is sequential
with the sparse staging bank. For N cells, E boundary edges and H closed
loops, E<=4N and H<=N give a conservative logical packed peak
`8N + 12E + 16(E+H) + 60 <= 136N + 60`: owned cells, boundary triples,
coexisting traced/canonical loop payloads and fixed Domain/descriptor/temp
packets. Connectivity's queue is at most8N and is an earlier phase.
Native Dictionary capacity (up to4N entries), loop-array headers, packed
append growth/reallocation and helper frames are additional, not certified
by the logical payload formula. The actual cold binding must admit all of
those before copying/validation and refuse when it cannot; this does not
claim that independently maximal N fits the shared524288-byte control reserve
or the joint production memory pack. Runtime/cold-peak qualification remains
open until the concrete provider is composed and measured.

After validation, row staging retains8N copied cells plus Domain/descriptor
bounds48 and at most48 bytes of current marker/floor boxes; Room/Space result
packets, Region numeric controls and the sealed source's pins are separately
counted helper lifetimes. Cold packet cleanup completes before release. No
new hot Work allocation, receipt arena or per-Room object is introduced.

### Single-Room component verification

Evidence: `docs/validation/evidence/underground-room-admission-2026-10-03/confirmation/`.
The own worktree had no demo assets; its cache was deleted and the required
headless editor import completed without ERROR or WARNING lines. The unchanged
strict runner executed five singleton CI shards:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| RoomOrders, including exact Room confirmation | 22 | 867 | 0 |
| Existing paid Furniture composition | 15 | 4628 | 0 |
| Actual SpaceOwner, including future Room source | 49 | 812 | 0 |
| Spatial Buildings | 21 | 434 | 0 |
| Entity Directory candidate | 11 | 358 | 0 |
| Total | 118 | 7099 | 0 |

Independent review found that the original entry path called the provider
before establishing exclusivity and dereferenced a second binding without
checking absence. The correction establishes the stage first and clears it
on all pre-lease failures, including a missing second binding. Two new
adversarial tests cover initial-callback reentry and a provider passing its
first check but refusing its second; actual live state stays unchanged and a
fresh retry succeeds. After correction, a second clean import preceded the
final RoomOrders22/867 and Furniture15/4628 rerun. The three unchanged
dependency suite results above are from the first clean run; their actual
source and tests did not change in this correction. Historical source pins
and the earlier passing logs remain in `history/pre-entry-review/`.

Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 3 file(s)`. An earlier
draft's `floor` identifier warning was corrected before this clean run and its
rejected analyzer output remains in the evidence history. The local selector
initially mistyped the candidate suite filename after four successful suites;
that selected no engine suite. The corrected actual candidate suite ran once,
and the invocation record distinguishes that tooling error from runtime evidence.

The new assertions cover real identity/PID publication, exact256/512-unit
concavities and holes, full XYZ overlap across level labels, unchanged live
owner bytes on malformed/capacity/source/candidate refusals, no rollback of
intervening real Directory history, cold admission before any Domain/Space
copy, preservation of foreign leases/tokens, balanced cleanup and reentrant
creation/discard attempts. A late actual provider binding loss refuses before
publication; publication attestation invokes no mutable provider callback.
Existing paid Furniture and owner tests remain strict. No completed physical
excavation, active service, demo workflow, composed save or performance gate is
inferred from these component results.

Independent source re-review accepted the final three frozen own source/test
pins after the entry correction, with no remaining high or medium finding in
this single-Room coordinator scope. The reviewer read the full fine-shape,
candidate publication, cleanup and adversarial tests; runtime evidence remains
the exact component checks above, not a production or full-suite claim.
