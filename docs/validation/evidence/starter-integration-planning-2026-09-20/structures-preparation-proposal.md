# INIT-C-PREP-R01 — compact authored starter structure plan

September 20, 2026. Draft for independent design review. This is the first deliverable of INIT-C, not completion of INIT-C or production travel admission. It directly prepares the authored refuge needed by FP-01. INIT-C4-R01 and the complete settlement release remain binding.

## Scope and ownership

Implement a pure `core/starter_structures.gd` plan producer and validator. It must read compiled BuildingDefinitions/Catalog identity, retain the GDD layout verbatim, and return a compact packed plan. It must not construct Buildings, EntityDirectory, SpatialWorld, Inventory, Navigation or another mutable world. Preparation does not mutate a live store, mint EntityRefs, set room validity, publish a contact, or claim a measured passage. Production materialization and spatial admission are subsequent named consumers.

The currently missing spatial/topology contract cannot be substituted with `override_static_legality`. A finite authored tile graph is useful for checking the layout and generating candidate contacts; it is not proof that a measured body fits. Keep those meanings distinct in API names, refusal codes, documentation and tests.

## Exact authored content

Seven building rows in allocation order: hall (58,59), four stockpiles (50,60),(50,65),(70,60),(70,65), well (64,54), workbench (58,54). Compiled catalog keys, tier 1, rotation 0, ACTIVE desired state; dimensions read and pinned to 12x10, 4x4, 4x4, 4x4, 4x4, 2x2, 3x3. Do not assign condition, interior-kit ID, heat or physical door dimensions by guessing. Those are unresolved materialization fields, separate from layout preparation.

Hall interior origin (59,60), extent 10x8; row-major local index `z*10+x`. Room rows: DORMITORY for x0..4 all eight rows; KITCHEN for x5..9,z0..1; COMMON for x5..9,z2..6; PANTRY for x5..9,z7. They contain exactly 40/10/25/5 tiles and partition all 80 tiles exactly once.

Preserve GDD §5.9:

```text
BBBB..KKHH
.........S
BBBB..TTTT
..........
BBBB..TTTT
......TTTT
..........
......SSSS
```

Floor furniture allocation order is row-major origin, then compiled type ID if ever tied. Each B/T/S is one instance. The paired K cells form one 2x1 kitchen bench and paired H cells one 2x1 hearth, both rotation 0. Thus 31 floor instances cover 33 tiles: 12 beds, 12 seats, five shelves, one bench, one hearth. Every footprint belongs to one room. Four pantry shelves contribute potential 200000g only after real room validity; the kitchen shelf is never pantry capacity. Assign bed ordinal 0..11 to resident persistent ID 1..12 in the eventual materializer; no residents or references exist in this pure plan.

Eight edge records span the partition between (4,z) and (5,z), z0..7: seven solid partitions and one interior door at z4. Edge records store the two distinct adjacent local tile indices in ascending order, plus kind and owning room ordinal (dormitory). This undirected representation is explicit plan data, not an implicit interpretation of the current Furniture `origin_tile/rotation` columns; converting it into runtime edge furniture requires the subsequent reviewed edge-encoding contract. Edge objects consume no floor tile. Floor furniture must not be accidentally counted as edge furniture or vice versa.

The exterior south exit is separately described as the hall boundary connection from local (5,7), through the one-tile exterior wall band at global (64,68), to exterior global (64,69). It is building geometry, not an extra floor furnishing. These are topological endpoints, not yet measured doorway openings or body locations. Require both endpoints and the wall-band tile to remain part of the spatial preparation contract; jumping across a blocked wall tile is forbidden.

## Pure geometry proof

Use four-neighbor tile adjacency over the 47 unoccupied interior tiles. Solid partition edges block adjacency; the z4 door permits it. Other room boundaries remain open. Flood from local (5,7); all 47 unoccupied tiles must be reachable. For every floor furnishing, enumerate orthogonally adjacent unoccupied tiles reachable from this root and connected across an open boundary (including a different room), sorted by local tile index; at least one is required. Keep all candidates instead of choosing a physical contact before the profile/geometry proof. No diagonal corner cutting, width proxy, synthetic clearance or final production `Contact` objects.

The pantry shelves explicitly use the open common-room edge under GDD §5.9; requiring every candidate to be in the furnishing's owning room would wrongly reject three of those shelves. Candidate adjacency must obey the partition edge as well as floor occupancy. If any other authored diagram condition contradicts these rules, return the counterexample to Astra rather than move furniture or add a new walk tile. Door and exterior access geometry remains separately qualified.

Building footprints must be in the 128x128 exterior grid and pairwise disjoint. Hall room/furniture bounds and row-major global tile conversion must be exact. The producer's plan and independent expected fixture must agree on every field, not just census totals.

## Interface and refusal contract to finalize in review

Prefer `prepare_into(out: Plan)` with a typed reusable small `Plan` and explicit refusal result. All proposed fields are packed integer arrays; strings remain immutable compiled keys. No per-entity RefCounted records. The plan has fixed extents derived from seven buildings, four rooms, 80 room tiles, 31 floor furnishings, eight edges, and bounded adjacency candidate lists (at most four per occupied floor cell, with deduplication within an instance). Record each array's columns/count/bytes before dispatch and require one byte-exact layout test. No live-capacity arrays or full world scan.

Refuse null output, malformed catalogs, incorrect immutable footprint/furniture dimensions, illegal compiled ordinals, malformed layout, overlap, room ownership mismatch, duplicate/malformed edge, disconnected walk tile, furnishing without a candidate and malformed exit. Validate all inputs before writing caller-owned output; refusal preserves all previous output fields byte-for-byte. Success overwrites every output column, preventing retained history from a prior plan. Order refusal checks deterministically: input/type, catalogs, extents, room assignment, floor occupancy, edges/exit, connectivity, candidate lists. The candidate is cold preparation, not per-tick work.

## Review and acceptance

Independent design review must settle the exact columns/API/budget and identify any missing source facts before implementation. Astra accepts the contract; Claude authors code/tests in separate allowlists; independent integrated review and exact-head CI follow. Tests need exact layout/identity equality, all public refusals with no mutation, malformed edge/room/exit and disconnected access, deterministic repeated preparation, and proof that no mutable world owner was allocated. Use bounded counterfactual plans or explicit pure validation input to reach malformed cases; do not expose an arbitrary caller plan as trusted production publication.

Unresolved next consumers: runtime edge and building boundary geometry; source-bound measured adult starter envelopes and full segment/corner fit; real revisioned furniture/building/service contacts; terrain/slope/support placement; condition/interior-kit/temperature initialization; generation-safe materialization; INIT-D real container/gear placement; INIT-B relationships; INIT-E prior-world checkpoint/rollback. The compact plan can finish while these remain open, but it cannot be credited as any of them.

Source basis: current GDD §5.9, INIT-C4-R01, Buildings public APIs and comments, MOVE-C2-R01, MOVE-C3-R01, MOVE-DEP-R01–05, FP-01–12. Historical manifest hashes will be refreshed when dispatching the contract and implementation packets.
