# INIT-C-PREP-R01v1 — authored refuge preparation

September 20, 2026. Astra accepts the bounded implementation contract following the independent design review in `docs/validation/evidence/starter-integration-planning-2026-09-20/design-review.md`. This is a dependency of INIT-C, not its completion. The complete INIT-C4-R01 and FP-01–12 requirements remain unchanged.

## Result and authority

Produce a compact, deterministic description of the exact GDD §5.9 starter buildings, room tiles, floor furniture, partition edges, candidate access tiles and exit. Use integer packed arrays; do not create or modify a mutable Buildings, EntityDirectory, SpatialWorld, Inventory, Navigation, Movement or settlement owner. No live refs, room-valid flags, measured contact objects, condition/temperature claims, save-schema changes or production startup wiring belong here.

The frozen diagram, positions and reference values are in `docs/validation/evidence/starter-integration-planning-2026-09-20/layout-reference.json`, derived from GDD source. The proposal beside it supplies the full geometry narrative; this contract supersedes its unresolved API/budget/edge-owner choices.

The plan describes tile adjacency. It does not qualify a resident body, a physical opening, support, passage, exterior connectivity, heat or a usable service. Missing final render assets are not permission to deny legal simulation; missing measured profile and contact definitions remain genuine admission dependencies.

## Source pins

Read protected compiled IDs through Catalog; never hand-number the room types as plan row ordinals. Pin the relevant immutable Catalog dictionaries and BuildingDefinitions fact dimensions/types before any indexing. Building keys are hall, open_stockpile, well, workbench; furniture keys bed, seat, shelf, kitchen_bench, hearth, interior_partition, interior_door; room keys DORMITORY, KITCHEN, COMMON, PANTRY; ACTIVE and tier1. Compiled building/furniture ID tables must agree with their ascending-key domains and all required keys must exist with integer IDs. Room types and ACTIVE must agree with the protected Catalog ordinals. Required source footprint values are hall12x10, stockpile4x4, well2x2, workbench3x3; floor dimensions bed/seat/shelf1x1, bench/hearth2x1, edge objects0x0. Building facts must carry ten integer fields and furniture facts four. Required unlock ordinal is read from B_UNLOCK and must be0 for these starter types. Refer to named fact-column constants and validate their expected indexes. Do not instantiate BuildingDefinitions just to inspect immutable facts.

## Exact packed layout

`class Plan` has exactly the following ten `PackedInt32Array` payloads. Multi-column arrays use column-major indexing `column * row_count + row`. Their extents are fixed and declared by named constants. Constructor allocates these small buffers, initializes every entry to -1, then header to zeros. It allocates no live-capacity arrays. Header schema is private preparation version1, not a save schema.

| Array | Columns in order | Rows | Bytes |
|---|---|---:|---:|
| buildings | type_id, global_origin_tile, rotation, tier, desired_state, footprint_x, footprint_z, required_unlock | 7 | 224 |
| rooms | room_type_id, tile_offset, tile_count | 4 | 48 |
| room_tiles | global_tile | 80 | 320 |
| furniture | type_id, room_ordinal, origin_local, rotation, footprint_offset, footprint_count, candidate_offset, candidate_count | 31 | 992 |
| footprints | local_tile | 33 | 132 |
| candidate_access_tiles | local_tile | 132 | 528 |
| edges | local_tile_a, local_tile_b, kind_id, room_ordinal_a, room_ordinal_b | 8 | 160 |
| exit_tiles | interior_local, wall_band_global, exterior_global | 1 | 12 |
| bed_furniture_ordinals | furniture_ordinal | 12 | 48 |
| header | version, candidate_used, footprint_used, walk_tile_count | 1 | 16 |
| **Total** | | | **2480** |

This logical payload is under the2560byte plan cap. Native object/Array overhead is not included or represented as measured. One staged Plan and one caller Plan are permitted for atomic cold preparation (4960 logical bytes), plus bounded graph scratch over80tiles and8edges. No full-world clone or permanent per-entity object graph. Register this as cold derived preparation, not saved authoritative state. Any alternative extra packed columns require updating this table before implementation.

## Exact contents

Building order: hall(58,59), stockpiles(50,60),(50,65),(70,60),(70,65), well(64,54), workbench(58,54), all rotation0/tier1/desired ACTIVE. Global tile is `z*128+x`. Hall interior origin(59,60), size10x8. Building footprints are bounded and pairwise disjoint.

Room ordinal0 DORMITORY owns local x0..4/all z; ordinal1 KITCHEN owns x5..9/z0..1; ordinal2 COMMON owns x5..9/z2..6; ordinal3 PANTRY owns x5..9/z7. Their packed global tile runs are each sorted ascending, contiguous in the arena, with counts40/10/25/5 and offsets0/40/50/75. These four ordinals differ from the compiled room IDs. All80interior tiles are owned exactly once.

Floor furniture follows the literal GDD diagram and row-major origin order. A repeated origin is invalid; there is no secondary allocation tie. Each bed/seat/shelf is one1x1 instance, each contiguous K/H pair one2x1 instance. Exactly31instances occupy33unique tiles; both footprint tiles belong to the owning room. Footprint arena runs are contiguous, sorted within each instance. Bed ordinals are the12bed instance indices in allocation order; the eventual materializer pairs their actual persistent IDs with resident IDs1..12, never invents EntityRefs here.

Eight edges are sorted by local tile_a: (4,5),(14,15),…,(74,75); only(44,45) is interior_door. Others are interior_partition. Endpoints are sorted, adjacent, distinct, and carry both adjacent room ordinals. The plan assigns no runtime owning side or edge rotation: Buildings' origin_tile/rotation edge encoding and overlap guard remain unresolved consumers. The door is the only left/right walk connection and is necessary for eventual dormitory access and heat.

Exit entries are [75, 68*128+64, 69*128+64]. Interior local75 maps to global(64,67); the wall-band tile is(64,68); exterior is(64,69). No exterior-door furniture instance is invented. Each segment is orthogonally adjacent; the wall tile is inside hall footprint/outside interior, the final tile outside every starter footprint. This is not permission to jump the wall in SpatialWorld.

Candidates are all sorted, unique orthogonal adjacent unoccupied tiles across unblocked edges for each floor furnishing, including an adjacent room across an open boundary. The47walk tiles must all be flood-reachable from75 under four-neighbor movement and the seven solid partition edges. Every furnishing has at least one candidate. The canonical plan has51candidate entries. Unused candidate arena entries51..131 remain -1. Three pantry shelves have their only access tile in COMMON; preserving that is mandatory. All twelve seats additionally have a vertical neighbor as the GDD specifies.

## API and refusal behavior

`prepare_into(out: Plan) -> bool` builds the exact authored plan after source validation, validates the staged plan, then publishes all ten arrays only on success. `last_refusal() -> StringName` belongs to the producer, not the Plan. `plan_refusal(plan: Plan) -> StringName` is a pure read-only validator for the complete fixed plan; it never repairs. Wrong GDScript class types may be rejected by static typing; null is an explicit runtime refusal. Expose named column and extent constants for consumers/tests.

There is no validity boolean or generation/serial in Plan. A refused prepare leaves the previous successful plan byte-for-byte intact, and callers must consume its returned bool and producer refusal. This is intentional transactional output semantics, unlike SpatialWorld's clear-first contact binding. A serial would not protect a caller ignoring the return value and would break byte-identical repeated preparation; the review's serial suggestion is declined. A fresh all-default Plan is invalid until successful preparation. Successful repeated preparation produces identical payloads and overwrites stale output data completely.

Refusal order/codes (empty StringName is success): `STARTER_PLAN_NULL`; `STARTER_SOURCE_METADATA`; `STARTER_PLAN_SHAPE`; `STARTER_BUILDING_LAYOUT`; `STARTER_ROOM_LAYOUT`; `STARTER_FURNITURE_LAYOUT`; `STARTER_EDGE_LAYOUT`; `STARTER_EXIT_INTERIOR`; `STARTER_EXIT_WALL`; `STARTER_EXIT_EXTERIOR`; `STARTER_WALK_DISCONNECTED`; `STARTER_ACCESS_CANDIDATES`; `STARTER_AUTHORED_LAYOUT`. Validate shape before any indexing; scalar/range/type/footprint ownership before graph work; invalid indices never reach array access. Source metadata runs before source-derived expectations are constructed. The final authored-layout gate compares all remaining values with the frozen exact fixture; structural checks must remain independently testable rather than all malformed cases collapsing into this last code.

Small private pure adjacency/flood helpers may be tested directly with bounded counterfactual geometry to cover solid-edge candidate rejection, since the fixed layout contains no furniture at x4/x5. Never add a public switch permitting an arbitrary plan to bypass the authored-layout gate. Producer validation can use internal source-derived expected arrays; independent tests must load the frozen reference and explicitly assert the remaining fixed building/room/edge/header values, not simply call the producer twice as their oracle.

## Acceptance and integration

Verify exact every-array contents and2480byte payload, source IDs/room ordinals distinction,31/33/47/51/8/12counts, bed order, south exit, cross-room pantry access, all refusal gates and input/output nonmutation, repeated success and refusal-after-success, candidate unused tail, wrong shape and malformed index without engine errors. Counterfactual graph tests must demonstrate a blocked partition candidate, missing sole door, and each exit failure. Source metadata counterfactuals belong in owned cold clones and may not count parse errors as refusal evidence. Require source inspection/preload closure proving no mutable owner constructor, focused/full tests, applicable deterministic checks, independent code review and exact-head CI.

Allowlist: new `godot/scripts/core/starter_structures.gd`, its UID, new focused tests/focus script and UID, bounded metadata test if needed, its integration step in `.github/workflows/tests.yml`, registry/queue/contract evidence by Astra. No edits to existing gameplay owners, startup, Catalog, BuildingDefinitions or save schemas. This packet completes compact preparation only. INIT-C physical geometry/contact/materialization, INIT-D goods and equipment, INIT-B relationships, INIT-E safe publication and prior-world rollback remain separate tracked work.
