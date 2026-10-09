# 1215 — Per-motion Location air

Date: 2026-10-07 · Status: Accepted (implements Brendan's 2026-10-07 choice of **an air box per motion**).

## Problem

ADR 1213 found that the near upper Kitchen cubes are blocked by the Location record, not by motion content.
`publish_into` merges every adjoining source's air into one AABB per station. At the HIGH station (1512,0,z)
that AABB spans [2048,2244]×[1024,1192], which is inside the solid target cube. Each motion's own boxes fit.

## Decision

A Location's air is now its **envelope plus up to `MAX_AIR_EXTRA` = 3 further half-open boxes**. A station
claims only the air its motions use: either the sources' own air primitives, or unions of them where that union
is itself open void.

### Storage: a fixed pool, sized by admission

The extra boxes live in a pool of `S` slots in each `Locations.Bank`. Each slot holds the owner row (−1 when free)
and one half-open box, 28 B.

- `S = min(256, (arena_bytes − 228N − 256) / 56)`, which is the surplus a caller admits beyond the schema-1
  banks.
- **Existing callers pass exactly 228N + 256, so they get S = 0.** Their banks, wire bytes and every result are
  unchanged. With S = 0 any extra air refuses `LOCATION_GEOMETRY_FORMAT`.
- `Record.air_count` and `Record.air` (a fixed 18-int shape, set in `_init`) carry the boxes. Readers never resize
  caller packets.
- Slots are taken lowest-first at `stage_add`, and released by `_clear_row`. `stage_add` refuses
  `LOCATION_AIR_CAPACITY` when the pool is full.

A per-row inline layout was rejected: at the session's 1,024 Locations it would cost about 0.52 MB more than the
1 MiB Location/topology reserve.

### Proof

- Every extra box must be valid, inside the domain and wholly above the root plane.
- Each extra box must be covered by SUPPORTED_VOID, and any blocking row meeting it refuses
  `LOCATION_ENVELOPE_BLOCKED`. Unlike the envelope, extra boxes get no pending-bearer exemption.
- **Image.** A Location with extra air is proved on the **traversal image**, the one route sweeps use, where a
  Room's reservation markers are not walls. On the Site image, the Kitchen's markers would block a Corridor
  WORK station's per-motion air even over paid, cut cubes. Single-box Locations keep the image they used before.
- **Consumers.**
  - WorldRoutes endpoint body containment (route and stationary turn) accepts a box inside the envelope **or**
    inside one extra box (`Locations.air_contains`).
  - The ordinary provider's approach contact uses the whole box when it lies inside one air box; otherwise it
    clips to the envelope as before.
  - Connector contacts refuse any multi-air endpoint (installation contacts are single-box).
  - FinalFacts, Room approach and the frontier row checks compare the extra air exactly.

### Publication

`FrontierPublication.Request` gains optional per-station air (`air_counts`, `air`). Zero keeps the one-AABB
record exactly as before. Otherwise:

- the first box must hold the root on its floor;
- every adjoining source's body/turn/approach primitive above the root must lie wholly inside one supplied box
  (`ROOM_FRONTIER_STATION_AIR` otherwise);
- Locations then proves each box;
- occupancy is checked over every air box.

The Room-station planner keeps a count of 0 whenever the one AABB is open. Otherwise it collects the primitives,
drops contained duplicates and greedily merges any pair whose AABB is open void. It refuses if more than 4 boxes
remain.

### ADR 1207 incremental re-proof

A carried row must also have every extra box untouched by the full-view journal and by staged changes, and free
of blocking rows in the sealed full image. The carry precharge scales with 1 + `air_count`. A change that meets
only an extra box forces the full re-proof, which refuses (tested).

### Persistence

The extra air is saved: category 1, §1 WORLD. It is published payload, and the request that produced it is
not retained, so it cannot be rebuilt.

- Wire schema 2 appends the pool (28S B) after `retired`. A different S changes the image size, so the image is
  refused by shape.
- Restore checks the pool is canonical: free slots are zero, and owners are present rows with at most 3 boxes
  each (`LOCATION_IMAGE_AIR`). It then re-proves every extra box.
- `_row_payload_unchanged` and the frontier unchanged-row check include each row's extra-air sequence.

## Memory

| Item | Bytes | Where |
|---|---:|---|
| Session pool, 64 slots (`underground_room_composition.LOCATION_AIR_SLOTS`) | 3,584 banks + 1,792 wire = **5,376** | Unallocated 6,848 B of `LOCATION_AND_TOPOLOGY_BYTES`, which does not grow |
| `Record` packets | +80 each | |
| `_air_box` and `_air_slots` | +32 | |
| Publication `Request` | +300, held twice in the private Query | Pushes ADR 1161's 8,050 B control census to about 8,650 B, over its 8,192 B ceiling. The ceiling is not raised |
| Planner `CONTROL_BYTES` | 45,752 | |

`tools/underground_memory_budget.py --check` already failed before this change, on another worker's
`underground_session.gd` delta. It now stops first on this change's reviewed-witness edit
(`underground_final_facts.gd`). The tool and its reviewed-delta rows belong to the worker shrinking the journals.
No budget was raised; the figures above are reported for that review.

## Not done

- World-preparation re-proof of a multi-air Room endpoint still uses the full image. A Kitchen marker under its
  air would refuse there unless the row is carried. This is unchanged from single-box Kitchen endpoints.
- No composed save adapter.
- No native measurement.
