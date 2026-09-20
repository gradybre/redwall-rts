# Design review — INIT-C-PREP-R01 compact authored starter structure plan

September 20, 2026. Independent design review only. No code was written, no test was run, no
measurement was taken. Nothing here completes INIT-C or INIT-E, admits a body, or qualifies a
contact. Astra owns every decision listed in the final section.

## Verdict

The proposal is a useful and correctly scoped prerequisite for the authored refuge FP-01 needs.
Its central distinction — a finite authored room/edge candidate graph is not physical clearance,
profile fit or contact admission — is right and is corroborated by the excerpts: `spatial_world.gd`
publishes no body clearance and imposes no approach adjacency rule, and MOVE-C2-R01 leaves all four
adult ground/ford starter bindings `S/N` (unqualified). I found **no blocking contradiction**.
Dispatch after corrections C1–C9 and Astra rulings D1–D6.

## 1. Independent arithmetic re-derivation from GDD §5.9

I re-derived every figure from the diagram bytes rather than trusting either supplied file.

| Claim | Re-derived | Agrees |
|---|---|---|
| Occupied interior tiles | 8+1+8+0+8+4+0+4 = 33 | yes |
| Walk tiles | 80 − 33 = 47 | yes |
| Floor instances | 12 bed + 12 seat + 5 shelf + 1 bench + 1 hearth = 31 | yes |
| Room partition | 40 / 10 / 25 / 5 = 80, each tile once | yes |
| Partition column edges | (z·10+4, z·10+5) for z0..7 = 8; door at (44,45) | yes |
| Connectivity | flood from 75 reaches 28 left + 19 right = 47 | yes |
| Candidate entries | 51 across 31 instances; every instance ≥ 1 | yes |
| South exit globals | local (5,7)=(64,67) → wall band (64,68) → exterior (64,69) | yes |

Both the x4 and x5 columns are entirely walk tiles, so the left component (28 tiles) reaches the
right component (19 tiles) **only** through the z4 door edge (44,45). The z4 door is therefore
load-bearing for dormitory exterior access and, under GDD §5.9's heated-component rule, for
dormitory heat. State that dependency in the plan documentation.

Footprints: hall x58..69/z59..68; stockpiles x50..53/z60..63, x50..53/z65..68, x70..73/z60..63,
x70..73/z65..68; well x64..65/z54..55; workbench x58..60/z54..56. All in-bounds on 128×128 and
pairwise disjoint. Dimensions match `BUILDING_FACTS` exactly (hall 12×10 room_tiles 80,
`open_stockpile` 4×4, `well` 2×2, `workbench` 3×3).

Pantry claim verified precisely: shelves at local 77/78/79 have candidates 67/68/69 only, all in
COMMON. An owning-room-only rule rejects exactly those three, as the proposal states. Shelf 76 has
66 (COMMON) and 75 (PANTRY). The kitchen shelf 19 is reached from 18 (KITCHEN) and contributes no
pantry capacity, matching R-BUILD-DOM-004 and `pantry_capacity_g_of_room()`'s outright refusal of a
non-PANTRY room.

The stricter GDD sentence "every seat has an adjacent walk tile above or below" also holds for all
twelve seats under vertical-only reading, so the general four-neighbour rule introduces no conflict.

## 2. Substantive corrections

**C1 — split room ordinal from room type.** `layout-reference.json` uses `room` 0..3 as an
allocation ordinal; `Catalog.ROOM_TYPE` supplies a different compiled id. The plan must carry both
as separate columns and never index one by the other.

**C2 — edge records need both adjacent room ordinals.** Assigning all eight edges to DORMITORY is
an authored choice with no GDD basis. `buildings.gd` requires an edge piece's `origin_tile` to lie
in its own room, so the choice fixes the origin tile to the x4 side. Record `tile_a`, `tile_b`,
`kind_id`, `room_ordinal_a`, `room_ordinal_b` and let the reviewed edge-encoding contract choose.
Restate in the plan that `origin_tile`+`rotation` naming an edge is **unstated** and that
BAL-BUILD-001's edge-overlap rule is explicitly not enforced by `buildings.gd`, so the plan's own
duplicate-edge refusal is the only guard until 06.2 lands. Rotation 0 on edges is a placeholder.

**C3 — the exit needs three refusals, not one.** Replace "malformed exit" with: interior tile is not
a walk tile; wall-band tile is inside the hall footprint but outside the interior rectangle and is
orthogonally adjacent to the interior tile; exterior tile is in-bounds, adjacent to the wall band,
and outside every building footprint. Also state that the interior flood proves interior
connectivity from the exit-adjacent tile and **not** exterior connectivity; the wall-band traversal
is unproven by construction.

**C4 — resolve the refusal/validity contradiction.** "Refusal preserves all previous output fields
byte-for-byte" means a success flag also survives, so a caller ignoring the return value reads a
stale plan as valid. Add a monotonically increasing `serial` bumped only on success, document that
refusal leaves the previous *successful* plan intact, and test the pairing. Note this inverts
`spatial_world.gd`'s `bind_ground_contact()` clear-first convention; the divergence must be stated.

**C5 — the partition-blocking branch is unreachable from the authored layout.** No occupied tile
sits at x4 or x5, so no candidate pair crosses the partition. The authored plan cannot exercise
that branch; a bounded counterfactual fixture is required. The door branch *is* exercised, but only
via connectivity, never via a candidate.

**C6 — the allocation tiebreak is dead code.** Each tile carries one symbol, so row-major origins
are distinct. Convert "then compiled type ID if ever tied" into a duplicate-origin refusal.

**C7 — carry `required_unlock` as data.** `place_building()` never defaults `unlocked_mask`. All
seven keys are unlock 0, but the materializer should read the column rather than assume M0.

**C8 — omit condition and temperature columns.** `_write_furniture_row()` and `_write_room_row()`
already write 0. There is no ambiguity to resolve at plan level and no value to guess.

**C9 — emit bed ordinal order.** `starter_settlement.md` requires beds by resident persistent ID
ascending then bed ID ascending. Emit the twelve bed furniture indices in allocation order so
INIT-D/E do not re-derive it from geometry.

## 3. Missing source facts (record, do not infer)

1. Edge `origin_tile`/`rotation` encoding — unstated; named as open in `buildings.gd`.
2. `Building.condition` scale and `Building.interior_id` domain — both unstated.
3. No exterior-door furniture kind exists: `FURNITURE_FACTS` has only `interior_door` and
   `interior_partition`. This *confirms* the proposal's "building geometry, not a furnishing".
4. Approach/work contact envelope and clearance class — owned elsewhere; `spatial_world.gd` imposes
   no adjacency rule and MOVE-C2-R01 supplies no qualified starter clearance. Name the plan field
   `candidate_access_tiles`, never `contacts`.
5. Room validity remains `set_room_valid()`'s owner; the plan proves only the countable and
   candidate-graph halves.

## 4. Proposed packed Plan budget (exact, to be frozen before dispatch)

| Array | Cols × rows | Bytes |
|---|---|---|
| buildings (type_id, origin_tile, rotation, tier, state, footprint_x, footprint_z, required_unlock) | 8 × 7 | 224 |
| rooms (room_type, tile_offset, tile_count) | 3 × 4 | 48 |
| room_tiles | 1 × 80 | 320 |
| floor furniture (type_id, room_ordinal, origin_local, rotation, fp_offset, fp_count, cand_offset, cand_count) | 8 × 31 | 992 |
| footprint arena | 1 × 33 | 132 |
| candidate arena (bound 4 × 33; 51 used) | 1 × 132 | 528 |
| edges (tile_a, tile_b, kind_id, room_ord_a, room_ord_b) | 5 × 8 | 160 |
| exit (interior_local, wall_band_global, exterior_global) | 1 × 3 | 12 |
| bed ordinals | 1 × 12 | 48 |
| scalars (counts, serial, last refusal ordinal) | 13 | 52 |
| **Total** | | **2516** |

Cap the contract at 2560 bytes and require one byte-exact layout test. Strings stay immutable
compiled keys; no per-entity RefCounted rows; no live-capacity arrays.

## 5. API and deterministic refusal order

Prefer `prepare_into(out: Plan) -> bool` plus `last_refusal() -> StringName`, matching
`spatial_world.gd`'s bool + `_last_refusal` convention rather than allocating an `OpResult`.

Refusal order, checked fully before any write: (1) null/typed input; (2) catalog identity and
immutable footprint/furniture dimensions; (3) building extents, bounds, pairwise disjointness;
(4) room assignment and exact partition of 80 tiles; (5) floor occupancy, duplicate origin, overlap;
(6) edges — duplicate, non-adjacent, wrong column, unknown kind; (7) exit — the three C3 checks;
(8) connectivity of all 47 walk tiles from the exit interior tile; (9) candidate lists — empty,
unsorted, duplicated, or crossing a solid edge.

## 6. Test gaps beyond the proposal's list

Counterfactual fixture for C5; serial/refusal pairing for C4; each of the three exit refusals
separately; an assertion that the room ordinal and compiled ROOM_TYPE columns are distinct; and an
assertion that the plan allocates no EntityDirectory ref, no Buildings store and no SpatialWorld.

## 7. Scope preserved

INIT-C4-R01, the complete settlement release, FP-01–12 and PC-03/PC-04 authoring remain binding and
unreduced. This review claims no materialization, no measured passage, no heat, no room validity, no
INIT-C or INIT-E completion, and no execution of any kind.

## 8. Decisions for Astra

- **D1** edge owning-room convention and whether to record both adjacent ordinals (C2).
- **D2** refusal-preservation semantics and the `serial` field (C4).
- **D3** the 2560-byte plan cap and frozen column list (§4).
- **D4** `prepare_into` + `last_refusal` versus an `OpResult` return (§5).
- **D5** whether bed-ordinal emission belongs in this plan or in INIT-D (C9).
- **D6** acceptance of the counterfactual fixture as the only means of covering the
  partition-blocking branch (C5).
