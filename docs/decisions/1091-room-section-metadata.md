# 1091 — Room section metadata and exact painted claims

Date: 2026-10-03 · Status: metadata component verified and independently reviewed; physical mapping remains separate

## Decision

Each newly confirmed single authored Room section owns one real `FLOOR_DATUM`
region enclosing its painted bounds. The exact contiguous X-run claims keep their
original integer world extents and all reference that full section handle. The
metadata box is one unit high at the authored floor Y, retains the actual Room
generation and level, and has `CLAIM_NONE`. It does not occupy the enclosed area,
grant usable floor or support, or create a physical cut.

Previously the coordinator created one datum per painted row run. At a fine
paint pitch those narrow metadata extents unnecessarily fragmented one floor
section and prevented a real storage/work endpoint from fitting the section even
where an eventual completed shell could provide its entire footprint. Section
metadata should identify the authored floor; the exact painted claim and paid
physical geometry determine occupancy, usable area and clearance.

This change preserves the canonical painted cells, explicit cell size, origin,
height, selected level, permanent Room type, concave corners and holes. It scans
the canonical cells' X extrema and uses their ordered Z endpoints, transforms in
int64, and refuses any int32 or actual Domain escape before publishing identity.
The enclosing rectangle is never substituted for the painted footprint. Another
Room may reserve a genuinely unclaimed hole when the actual physical provider
permits it; overlapping metadata alone does not block that reservation.

The existing atomic Room confirmation remains intact: actual cold admission
precedes copies, an observed Directory identity is not spent until every source,
claim and companion preflight passes, and actual Room/Space publication shares
the exact synchronous window. Neither a successful metadata operation nor an
accepted Room becomes finished, furnished or service-ready.

## Representation, memory and compatibility

For R canonical X runs this uses exactly `R+1` sparse region rows rather than
`2R`. It adds no authoritative columns, capacity, Directory entity kind, persistent
map, heap, per-site reference or save image. The same existing SpaceOwner banks
and schema store the existing `FLOOR_DATUM` and typed `OBSTACLE`/`CLAIM_ROOM` roles.
Previously accepted multiple-datum Rooms remain valid; this increment does not
migrate their handles, collapse their sections or reinterpret saved coordinates.

The new section's local Region and box are dropped before claim-run staging;
only its Result/full handle crosses that boundary. Peak current box payload is
24 bytes and remains inside the previously admitted 48-byte staging allowance.
The copied plan's8N cells, Domain/descriptor bounds, Footprint dictionary/boundary
validation and independently owned future-source pins retain their existing cold
admission obligations. No metadata array is copied or retained by RoomOrders.

The changed helper chain has a conservative **128 logical numeric bytes** at its
peak: run-loop indexes plus its section argument24, per-run start/end/section
arguments24, four cell-box arguments and four int64 transformed endpoints64,
and the retained section Result's token/full handle16. The separate section
extrema path uses at most88 of these bytes before its Result exists. Unchanged
outer frames, Region/Result native headers, references and packed headers remain
in the existing joint helper/native allowance; this is a bounded cold-frame
charge, not a claim of measured allocation or a new permanent128-byte store.
No START/WORK hot path is changed.

## Paid physical boundary remains separate

ECON-001 still prices immutable1024u cubical cuts and retains virgin/backfill
history in Sites. An envelope, marker or touched cube cannot create unpriced
outside space or make a concave hole usable. The current physical authority's
whole-cube finish publication is not a complete fine-room shell mapping. Its
following composed packet must retain the exact Room boundary through actual
physical exclusion/lining/support and separately qualified contact geometry.
No new finer tariff, free wall, invisible support or production permission is
introduced here.

The selected follow-on section resolver will inspect actual `CLAIM_ROOM` rows
intersecting a paid cube and require one unique full section identity. A cube's
upper-cut Y is not a floor Y. The resolver remains metadata evidence; actual
whole volume, boundary, support and source proofs still determine whether that
phase is allowed. It belongs to the separately owned SpaceOwner integration and
is not implemented by this increment.

## Verification scope

The focused tests use actual Directory, Buildings, RoomOrders, SpaceOwner and
accounting owners; the inherited terrain/profile/cut-map/cold permission fixture
is explicitly synthetic. They exercise exact256/512u concave and holed claims,
full shared section handles, negative cell indices and non-first-row extrema,
another real Room in a hole, exact64-row capacity, all-byte capacity/domain
refusals, no physical/accounting changes and no premature Room validity. Existing
paid Furniture, atomic furniture batches and typed Layout Sources remain in the
focused regression set.

After a clean Godot4.7.2 import with demo assets absent and the import cache
deleted, the four unchanged strict suites report **62 tests,7688 assertions,
0 failures**. Each reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`. Exact hashes,
import/analyzer logs, complete shard manifest and raw suite outputs are under
`docs/validation/evidence/underground-room-section-2026-10-03/`.
Independent root review accepted both frozen source/test hashes with no high or
medium finding after inspecting the complete transform/claim delta and tests;
it did not duplicate the author's engine runs. Demo activation, composed
save/load, real terrain admission and hardware memory/performance qualification
are not claimed.

## Approved next physical mapping

The root coordinator accepted the following ECON-003 interpretation as a
separate engineering increment: CUT opens and accounts for the entire paid
quantum once; FINISH publishes usable supported void only at intersections with
the exact Room claims. The remaining already-paid cavity stays explicitly
nontraversable `UNFINISHED`, never fake solid or unpaid usable void. This does
not add a new tariff, role or multiple-Room-per-Site policy. Sites' paid finishing
state is therefore not proof that the whole cube is navigable. Actual physical
mask/section proof and the Authority mutation hook are still to be implemented
and independently verified; this metadata commit does not activate them.
