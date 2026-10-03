# 1083 — Atomic planned Room admission

Date: 2026-10-03 · Status: Allocator/Buildings prerequisite verified; composed admission follows

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
