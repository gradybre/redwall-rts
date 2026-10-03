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

The Buildings identity/service-gate extension is implemented as increment A
below. The room-order coordinator is the following increment. A following
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

## Implemented prerequisite A0b: synchronous spatial publication

`ExcavationSites.is_publishing_spatial_transition(origin_u, operation, stage,
room, candidate)` attests only the exact synchronous `_publish_candidate`
callback after the actual physical payment, output or cancellation has
committed. It checks the actual live weak authority, candidate row range,
exact origin, operation, stage and full Room generation. Preparing a spatial
candidate, calling the adapter directly, or retaining a previous callback's
arguments grants no publication permission. The adapter must still validate
its own prepared revision before installing its non-failing candidate.

A single `_publishing_spatial` logical bool byte is transient category 3
call-stack control, never saved or hashed. It brackets only that callback
and is false again before phase retirement. There is no new packed column,
receipt arena or steady-state tick work. The focused strict run passed 36
tests / 22404 assertions with zero failures, unexpected diagnostics and leaks;
the two-file analyzer reported zero warnings. The exact independently reviewed
sources, clean-import log and test output are in
`docs/validation/evidence/underground-ug07-publication-window-2026-10-03/`.

## Implemented increment A: spatial Rooms and pending furniture

`Buildings` now owns the approved two packed discriminator columns. An
underground Room allocates a real KIND_ROOM generation with its permanent
protected RoomType, null exterior Building parent and no ground TileLinks.
The ordinary sixteen-room managed-building limit does not apply. A pending
piece allocates real KIND_FURNITURE membership without any installed mask,
kind count, resident use, pantry capacity or work slot. An exact coordinator
installation publishes those presence facts once. Both directions of slot
reuse reset every new flag; removal and whole-world reset retire Directory
identities and preserve their generation rules.

`SpatialAuthority` is typed and bound weakly once to the exact Buildings
object. Unbound, expired, replaced and later foreign-rewired authorities
refuse. Mutations carry exact action, full subject/related identities and
values, and the default authority supplies no permission. Installation,
removal, reassignment, room validity/occupancy/heat and furniture condition/use
cannot use a legacy surface door to bypass the coordinator. Pending membership
still prevents room removal. Occupants and furniture users must be released
before approved removal. The authority must eventually prove actual physical
retirement, payment, fit and services; its test fixtures establish no such
production qualifications.

`spatial_kind_of_room` and `is_furniture_installed` are the generation-checked
readers for other owners. Underground tile offset/count and furniture origin
readers explicitly refuse; ordinary rotation remains its real authored value.
`area_units_squared_of_room` reads actual owner-qualified area under that exact
Room generation. GDD whole-tile count thresholds use integer floor division
by 2048², never rounding a short area upward. Service reads freshly check the
actual authority, so retaining a valid bit after owner expiration does not
supply access or capacity.

The fixed flags consume 98304 persistent logical bytes. A cold exact
`spatial_state_bytes` image copies another 98304 bytes when requested; it is a
diagnostic image, not a load codec. There is no new geometric arena or
per-room object. The weak authority is nonpersistent composition wiring.
The aggregate canonical and memory updates belong to the integration owner.

The existing S1 surface tile-map capture and cross-check call
`legacy_save_refusal` before copying. Legacy restore validates before writing
and explicitly initializes surface kinds and installed live legacy furniture.
Unknown flags, current spatial/pending rows, and retained spatial furniture
with a non-null parent and NO_LINK origin all refuse. A retired spatial pose
is preserved rather than normalized into an apparent surface save. The frozen
29-column S4 validator remains unchanged. Buildings never had a full live
component capture/restore implementation; these guards do not claim to add
one. UG16 must provide the actual versioned spatial codec, all-row validation,
owner rebinding and canonical hash coverage before live save support.

The independent review covered the actual diff and the fifteen adversarial
boundary tests. Final focused evidence totals **211 tests / 43554 assertions /
0 failures** across new spatial Buildings, legacy Buildings, frozen Buildings
save validator, S1 world columns, Construction and the actual physical owner.
Each strict suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The final two-file analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`.
The tests followed an asset-free clean cache/import; that import had no
error/warning lines. Exact per-suite counts, source hashes and raw evidence
are retained at
`docs/validation/evidence/underground-ug07-buildings-a-2026-10-03/`.
This is the isolated identity/service boundary. It does not claim the actual
room-order coordinator, paid furnishings, UG10 service-consumer integration,
production geometry, full suite, save/load or hardware performance complete.
