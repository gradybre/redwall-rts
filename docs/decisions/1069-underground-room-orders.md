# 1069 — Actual underground Room and furniture order identities

Date: 2026-10-03 · Status: Approved engineering schema; staged implementation

## Decision

Use the existing Directory-backed `Buildings` Room and Furniture identities
for modular underground orders. An accepted underground room has its actual
permanent purpose and a null exterior Building parent. Its volume, selected
floor sections, contact geometry and spatial claims belong to the underground
space owner. No surface Building, flattened ground-tile alias or synthetic
master Construction project stands in for the room.

The player paints a plan directly on dirt at the selected underground level
(D29). Confirmation establishes a Room-owned footprint claim. Each paid
physical phase continues to have its own actual Construction project through
ExcavationSites. Retiring one of those projects does not release the room's
entire reservation. A spatial exemption must prove the exact Sites→Room and
current phase/project relationship. Foreign room, furniture, occupant,
protected-access and project claims remain blocking.

## Approved owner extension

Add two authoritative packed byte columns to Buildings:

| Column | Extent | Meaning | Live payload |
| --- | ---: | --- | ---: |
| `_r_spatial_kind` | 16384 | Surface interior or underground room | 16384 bytes |
| `_f_installed` | 81920 | Accepted identity versus completed installation | 81920 bytes |
| Total | | | **98304 bytes** |

These use the existing Room/Furniture arena capacities. They introduce no
room-size policy, per-building underground room limit or new Directory kind.
The existing sixteen-room limit remains specific to managed surface buildings.
Spatial geometry, absolute positions and source revisions are not copied into
another world-geometry table. A future staged copy of these two columns costs
another 98304 bytes; this arithmetic is not measured runtime qualification.
Canonical declarations and the composed memory ledger must be reconciled
before integration.

Legacy `place_furniture` remains an installed surface placement. An accepted
underground furnishing order instead reserves a real pending Furniture
identity. Pending rows retain finite identity and room membership capacity,
but grant no presence mask, installed-kind count, user claim, bed, storage or
station service. Installation requires the real material/work owners and a
fresh spatial commit. Room removal, reassignment, validity and service gates
must not provide an alternate way around that lifecycle.

A typed, weakly bound Buildings authority exposes the coordinator boundary.
An absent, expired or foreign owner refuses. Actual room area is read from
the spatial owner; zero surface TileLinks never assert zero underground area
or make a ground tile a multilevel coordinate. The existing protected Room
and Furniture catalog identities, footprints, material recipes and work
amounts stay unchanged. No finish recipe, furniture clearance profile,
equipment variant, service readiness or movement permission is invented.

The frozen legacy column codec remains a surface-only contract. Capture must
explicitly refuse spatial or pending state and unknown discriminator values
until the versioned composed codec exists. Restoring a legacy surface image
must explicitly initialize surface room kinds and installed live furniture.
New persistent fields cannot silently disappear or inherit a previous row's
flags on reuse. UG16 still owns complete save/load integration.

## Implemented prerequisite: exact physical-owner readers

ExcavationSites now exposes `construction_owner()` and
`bound_spatial_authority()` as typed, read-only composition queries. A failed
initializer returns null. The spatial target is held weakly; expiration also
returns null. `is_bound_spatial(candidate)` rejects null and compares the
actual live object. Coincident EntityRef numbers in another owner do not
establish shared world ownership.

These readers add no persistent state or array allocation, and grant no
World-liveness, geometry, traversal or paid-work permission. They let the underground space
adapter bind an immutable domain and compare its actual Construction/Sites
composition without reading private columns.

## Remaining increments

The Buildings state extension and room-order coordinator are being built
under this decision; the readers alone do not implement them. A following
paid-furniture increment must reuse the existing consumed-input receipt
owner, preserve exact Inventory metadata/refunds, and gate real Work and
Construction mutations. It must not allocate a duplicate 2.3 MB project-WIP
arena or make numeric delivery counters proof that material was consumed.
The receipt/schema extension receives its own bounded review before edits.

The complete shell, post-shell furniture, room removal/backfill/rebuild,
service contacts and native demo dispatch require the actual geometry and
economy composition. Unit-test authorities remain explicit synthetic
fixtures. They do not activate missing production profiles, claim the whole
UG07 lane complete or close performance and persistence qualification.

## Verification

The fresh orders worktree initially contained seven unhydrated tracked LFS
assets. A clean import exited zero while reporting invalid PNG/glTF data.
Those own-worktree assets were hydrated from the existing local LFS cache;
the import-generated sidecars were restored and the cache was deleted again.
The subsequent import reported zero error/warning lines. No other worktree,
asset source bytes or diagnostic allowance was changed.

The prerequisite's strict singleton shard reports:

```text
35 test(s), 22325 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer on the two changed GDScript files, with `--max 0 --port 6156`,
reports `0 GDScript warning(s) in 0 of 2 file(s)`. Independent source review
accepted the exact reader/test diff before commit. Evidence and source hashes
are retained under
`docs/validation/evidence/underground-ug07-identity-readers-2026-10-03/`.
This is a focused prerequisite result, not UG07 completion or a full-suite,
save/load, production-clearance or performance qualification claim.
