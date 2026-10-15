# 1934 — Slice C2.2 scoping: Delivery's room pin, and retiring a room's station chains

Date: 2026-10-15 · Status: Proposed. Scoping only; no code. Stopped for Brendan's ruling on P-C22-1 and for the
coordinator's sequencing of P-C22-2 against the cost lane (`perf/dig-tick-cost`).

Number range: this lane's 1931–1949 (decision 1931). The branch is `feat/room-foreman-c2-2`, from `00b30c0e` (C2.1,
PR #262).

## Decision

C2.2 has two parts (decision 1933, "For C2.2 and C2.3"):

- **Delivery's room pin:** room Projects get their wood and stone through the existing underground haul path.
- **Station-chain retirement:** for rooms that need more route edges than the cold check budget allows.

Both were checked against the code at `00b30c0e` before any edit. Each has a finding that needs a ruling or
sequencing first.

1. **No certified way exists to carry wood or stone down a stair.** The entry's haul works only on the surface,
   R → M. A room Delivery can therefore move stock only between containers on the same underground level. Nothing
   puts stock on any level today.
2. **Retiring a room's stations needs an edit to `underground_locations.gd`.** That file removes endpoints only for
   the entry's own retirement scope. The graph half needs no edit, only the public Routes and WorldRoutes staging
   calls.

## 1. Delivery's room pin

### What exists

- **`underground_entry_hauler.gd`** moves one whole unit per trip from R's staging (`crew.output`) to M
  (`crew.storage`). Each trip is: walk to R's stand, turn, lift row, CARRY to M's stand, set-down row.
  - It reads its owners and crew by duck typing (`owners.delivery`, `.inventory`, `.routes`, `.jobs`, `.locations`,
    `.binding`, `.work`, `.construction`, `.profiles`, `.residents`; `crew.worker`, `.storage`, `.output`).
  - So a room builder can reuse it **unchanged**, with the room's storage as M and a same-level staging container
    as R.
- **`underground_connector_delivery.gd`** pins every excavation haul to the one live entry Placement:
  - `_pin_project` (about l. 245) sets `_excavation`, takes `_placement = _entry_placement()` and reads the
    Placement's frame and Frontier installation;
  - `_excavation_material_leaf` (l. 332) requires the destination to be a room-free STORAGE endpoint in the entry
    anchor's own surface section;
  - `_source_leaf` (about l. 752) re-proves that Placement;
  - `_endpoint_leaf` (l. 808, 817) and the final transfer check (l. 1215) compare the container owner with the
    Placement order's `world`.

  A room's storage endpoint (`ROOM_SLOT` set) is refused at `_excavation_material_leaf`.

### Finding: the stair carries nobody's load

The only way below the surface is the entry stair (ADR 1229). Its rows are source-4 WALK rows with POLICY_STAIR
(8, 9). Profiles admits stair rows "only on YAW_EXACT WALK rows, with no tool or cargo" (ADR 1229, constraint 4).
The grip carry rows 32 (wood) and 37 (stone) are automatic ground rows; no stair row carries cargo. The entry's own
haul therefore climbs back to the surface empty, hauls R → M on the surface, and descends again (ADR 1229, the
hauled prefix).

So no wood or stone can reach a room below the surface by any certified motion, and a room Delivery could move
stock only between two containers on the same level. No such stock exists in the game.

### Files and functions (if P-C22-1 (a) or (c))

| File | Change |
|---|---|
| `scripts/core/underground_connector_delivery.gd` | `_pin_project`: an excavation Project whose Site belongs to a non-entry Room takes a room branch: no Placement, Frontier frame or installation, and the world from the Inventory's bound spatial world. New `_room_material_leaf`: a live STORAGE endpoint in the Site's Room or its access section; Sites already proved the container at `bind_material_container` and re-proves it at `record_deliveries`. `_source_leaf`, `_endpoint_leaf` and the transfer leaf use the room branch's world and skip the Placement re-proof. One retained flag (the census delta goes through ADR 1212's projection update; Delivery's `RESERVED_BYTES` still fits). **Not a cost-lane file** |
| `scripts/core/underground_room_builder.gd` | A HAUL stage before BRACE's START, after the entry foreman's `_phase_units` and `_begin_haul`: `Hauler.units_into` gives the missing whole units in the room's storage; `Hauler.begin(...)` with legs to the storage endpoint; on DONE the builder walks on to its station. `Owners` gains `delivery` and `locations`; `Context` gains the staging container |
| `scripts/core/underground_room_foreman.gd`, `underground_room_runtime.gd` | The staging container in the room's record and context (+8 B per room row, so `RECORD_BYTES` becomes 29) |
| `scripts/core/underground_entry_hauler.gd` | No change |
| Tests | A same-level staging container in the Kitchen fixture's Corridor, its two grip stands, and the carry rows' paces in the fixture catalog (test geometry and wire only) |

None of these is `work.gd`, a routes module, or the excavation and phase-start paths (`excavation_sites.gd`,
`excavation_inventory.gd`, Construction).

## 2. Station-chain retirement

### Measured (the 16-Site Kitchen, one builder, PR #260 merged)

| | Start | End |
|---|---:|---:|
| Route edges | 4 | 20 (4 more per column; each column's chain is published once and its upper cubes reuse it) |
| Locations | 3 | 11 |
| Peak sealed route proof | | 255,082 checks of 1,048,576 (24 %), about 12.7 k per live edge |

At that rate the cold budget allows about 82 live edges. That is about 20 cells of rooms on one level, counting
every room, not each one: chains outlive their rooms, because nothing retires them. So retirement is needed before
a second or third Kitchen-sized room on a level, unless the cost lane changes the cost per edge.

### What exists

- **The entry's retirement (ADR 1191):** `underground_entry_contact_retirement.gd` and
  `underground_entry_contact_retirement_scope.gd`. It works in two publications under one cold lease:
  - graph: `binding.begin_prepare` → `routes.stage_remove` for every incident edge → `binding.seal` →
    `binding.publish`;
  - Locations: `locations.begin_contact_retirement` → `prepare_contact_retirement` →
    `commit_contact_retirement_preflighted`.

  Removed edge rows return to Routes' free heap (`stage_remove`), so retirement really frees capacity.
- **The Locations gate.** `underground_locations.gd` `_contact_retirement_context_refusal` (about l. 3334) admits
  only `context.issuer.get_script() == ContactRetirementScope`, the entry's scope script. A room retirement scope
  cannot remove endpoints without an edit there.

### Files and functions (if P-C22-2 (b))

| File | Change | Owner |
|---|---|---|
| `scripts/core/underground_locations.gd` | Admit a second, closed issuer script: the room retirement scope, beside the entry's. No other change to the removal path | **Not named in the cost lane's list, but it is the endpoint owner every route proof reads.** Needs sequencing |
| new `scripts/core/underground_room_station_retirement.gd` (+ scope) | Select a finished column's station chain that no unfinished cube and no other builder still uses, and that is not another chain's gateway (ADR 1215 gateway reuse; ADR 1213's start at an existing TRANSIT station). Then the two publications, as ADR 1191 does | This lane |
| `scripts/core/underground_room_foreman.gd` | Retire after a column finishes, when every builder is clear of the chain | This lane |
| `underground_routes.gd`, `underground_world_routes.gd` | **No edit.** Public staging calls only | Cost lane |

## Proposals

**P-C22-1 — Where a room's wood and stone come from (for Brendan).**

- **(a) Author stair-carry rows:** claw stair gaits holding a wood or stone unit, under ADR 1217's derivation and
  review. Then build the room Delivery so units go R → down the stair → the room's storage.
- **(b) Look into satchel transport first.** A builder could take a cube's brace inputs down in its satchel, if a
  satchel load does not change stair-row eligibility (ECON-004: "committed cargo still affects passage/profile
  eligibility"). This is unverified.
- **(c) Build the same-level room Delivery now, as listed in §1.** It is proven on the fixture between two Corridor
  containers. The stair leg is a named gap (`ROOM_HAUL_NO_STAIR_CARRY`) until (a) or (b).

**Recommendation: (c) now, and (a) as a content lane.**

- Same-level Delivery is needed whatever brings stock to a level: a level's staging container to each room.
- Neither (c) nor (a) touches the cost lane's files.
- Until (a), no room is dug in the game anyway (slice D gives level 1 its way in).

**P-C22-2 — Station-chain retirement (for the coordinator's sequencing).**

- **(a) Wait for the cost lane, re-measure the cost per edge, then build retirement against the real limit.** If
  incremental proofs cut the cost per carried edge, the limit may move far enough to change the policy.
- **(b) Build now.** This edits `underground_locations.gd` (a second issuer). Everything else is new files and
  public calls.

**Recommendation: (a), then (b).** The Locations edit is small, but it sits on the path every route proof reads.

## Source

Decisions 1191, 1205, 1210, 1213, 1215, 1229, 1931, 1933; ECON-004; `underground_connector_delivery.gd`,
`underground_entry_hauler.gd`, `underground_entry_contact_retirement.gd`, `underground_locations.gd`,
`underground_routes.gd` `stage_remove`, at `00b30c0e`. The edge and proof figures were measured with a scratch
suite (not committed) on the 16-Site Kitchen.
