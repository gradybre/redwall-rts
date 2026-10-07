# 1213 — Room-station planner: two of sixteen Kitchen cubes are reachable, and why the other fourteen are not

Date: 2026-10-06 · Status: Accepted (ADR 1202 Kitchen scope, step 5 groundwork and a test-level step 6).
Independent of the stair data (ADR 1209). Coordinates below are relative to the ADR 1161 fixture datum
(x from `X`, y from the Corridor floor, z from `Z`; heading +X is yaw 49152).

## Decision

`godot/scripts/core/underground_room_station_planner.gd` derives the ADR 1161 `FrontierPublication.Request`
for one Room Site, face and yaw. It reads only published Profile boxes and live Space/Location rows, and it
publishes nothing. `publish_into` stays the complete proof. `next_contact_into` is the step a foreman can call
later: `next_site_into` → `contact_into` → (on `ROOM_FRONTIER_EXISTING_CONTACT_REQUIRED`) plan → `publish_into`
→ fresh candidate → `contact_into`.

### Derivation (no new constants)

- **Gateway and heading.** The gateway is the provider's bound retreat endpoint; its plane and level fix every
  station. The bound retreat row fixes the heading family. The forward partner (`POLICY_READY_FORWARD`), the
  finite step pair (`POLICY_SHORT_*`) and the all-yaw ground row are chosen by `Itinerary._compatible`, so the
  plan uses exactly the rows the provider's retreat itinerary accepts. A work yaw other than the retreat row's
  refuses `ROOM_STATION_RETREAT_HEADING`.
- **Work row and root.** WORK rows of that yaw (BUILD, anchor-and-patch, the retreat row's actor/tool/cargo
  identity) are tried in ascending ID. The root along the face normal is the face plane minus the row's
  CONTACT_POINT offset. The anchor must lie strictly inside the cube's band above the Room floor, or the row is
  skipped. If no row qualifies, the plan refuses `ROOM_STATION_REACH_MISSING`.
- **Lateral root.** Candidates are the gateway's own line first, then every region or cube plane minus every
  published box face, ordered by distance from the anchor-centred root. A native sort orders them. The first
  candidate whose whole chain fits wins.
- **Chain.** The chain has an optional turn leg on the ground row at the gateway, then heading legs split at
  each section boundary. The full forward/backward pair is used where it fits. Otherwise the last leg is the
  published 232u step (`StepProgram.DISTANCE`). Each leg is checked with `section_span_refusal`, and both
  directed rows are swept over the whole span.
- **Fit tests.** These are exact half-open box subtractions against live rows:
  - air above the floor must lie in SUPPORTED_VOID, and Room reservation markers are not walls;
  - anything below the floor must lie in SUPPORT;
  - work strokes may also enter the target cube.
- **Station records.** Each station's single air AABB and footing AABB is rebuilt exactly as `publish_into`
  `_records` builds them (adjoining rows, air clamped to the floor). This check runs before the chain length is
  accepted.
- **Refusal precedence.** The planner reports the most advanced failure over all rows and candidates:
  REACH < GEOMETRY_CLOSED < SECTION < GROUND_SOURCE_MISSING < SHORT_STEP_MISSING < LOCATION_ENVELOPE <
  CHAIN_CAPACITY. Faces 2 and 3 refuse `ROOM_STATION_VERTICAL_FACE`, because stations are planned on the Room
  floor only.
- **Memory.** The planner allocates one private Query. Its declared logical slice is `CONTROL_BYTES` 44,460 B,
  admitted through `Frontier._guard`. That is a declared size, not a native measurement. The Query dies before
  `publish_into` admits its own lifetime in the same lease. The registry row is in
  `persistence_state_registry.md`.

## Proof on the ADR 1161 fixture (`test_underground_room_station_planner.gd`)

### Literal v3 fixture

- **First cube.** The plan for (2048,0,0) re-derives the hand-authored WORK endpoint from boxes alone: (1280,0,512),
  rows 5/9, FRONT 24, one station.
- **Lateral cube.** The plan for (2048,0,1024) after the first cube is a turn at (−1024,0,1530) on automatic ground
  1, then FRONT at (1280,0,1530) on 5/9. `publish_into` accepts it and `contact_into` proves the new WORK row.
- **Runtime seam.** v3 Routes still refuses the automatic-ground → selected handoff
  (`ROUTE_SOURCE_HANDOFF_REQUIRED`), so v3 cannot work that cube.

### Loop fixture

The loop fixture is the same Room geometry with the mounted content-6 wire. It adds pace rows 5/9/10/11/12 at
`RATE_GROUND_CAP` and a Corridor parking endpoint, as in ADR 1161's lateral test. The loop repeats until a full
canonical pass makes no progress.

| Cube(s) | Result |
|---|---|
| (2048,0,0) | Existing contact. Paid. |
| (2048,0,1024) | Published turn (−1024,0,1530) on 12/12 and FRONT 27 at (1280,0,1530) on 5/9. Paid. |
| (2048,1024,0/1024) | `ROOM_STATION_LOCATION_ENVELOPE` |
| (3072,0,·), (3072,1024,·) | `ROOM_STATION_GEOMETRY_CLOSED` |
| All 8 cubes at levels 2–3 | `ROOM_STATION_REACH_MISSING` |

**Ledgers (exact).**
- 2 Kitchen Sites are SUPPORTED_VOID, and `_ever_cut` = 2.
- Wood and stone are each debited by 2 × 250.
- Earth is 2 × 2,000.
- Work is 2 × (BRACE + CUT + FINISH) mWU.
- Support and earth conservation pass, no Project is live and the cold budget is quiescent.
- +2 Locations and +4 edges.
- The worker ends parked by real travel.

**Lateral seam at runtime.** The turn leg runs on canonical ground 12. Before the selected row, the body is
turned in place with `WorldRoutes.turn_actor`, because an exact-yaw row needs the body facing its yaw. With
that, the lateral cube's approach and its retreat (9 → turn → 12 → turn → 9 to parking) run at runtime. This
closes ADR 1161's multi-heading retreat seam for turns through all-yaw ground.

### What each refusal means, and what is missing

**1. Upper cubes (2048,1024,·): the one-AABB Location record.**
- *What does fit.* The per-box chain fits once both lower near cubes are paid:
  - the stations are step start (1280,0,512) on 5/9, then HIGH 26 at (1512,0,512) on step 10/11;
  - for z1 the stations are turn (−1024,0,1167), (1280,0,1167) and (1512,0,1167);
  - this is ADR 1161's 232u step seam, closed by existing content.
- *What blocks it.* `publish_into` merges every adjoining row's air into one AABB per station:
  - HIGH 26's turn/recovery box reaches y 1192 at x ≤ +536;
  - its approach box, and the step rows' tool box, reach x +732 at y ≤ 972;
  - so the AABB spans [2048,2244] × [1024,1192], which is inside the solid target cube.
- *Agreement.* The actual prover agrees: the same request refuses `LOCATION_ENVELOPE_BLOCKED` (asserted).
- *Content cannot fix it.* Striking the anchor at y 1039 needs body air above 1024, and approaching it needs a
  tool box past the face plane. That contradiction is why no new motion can close this.
- *Missing.* A Location air representation that is the union of the source boxes, or one box per adjoining
  source, instead of one AABB. This is a Locations/publication data-model change (Geometry lease), not motion
  content.
- *Negative-only check.* With the step rows' policies withdrawn, the same opened geometry refuses
  `ROOM_STATION_SHORT_STEP_MISSING` (asserted).

**2. Deep cubes (3072,·,·): the 1036u travel body.**
- Forward row 5's held-tool box spans y 379..1036 and x −64..+732. At any station past x 1316 it enters the
  upper near cubes (y ≥ 1024), which stay solid because of item 1.
- The step rows stay at or below 972u, but they are one finite terminal 232u leg. They reach x 1548 at most.
- Once item 1 opens the upper near cubes, the hand derivation predicts the following. These are *not proved*;
  the cubes are still closed.

| Cube | Predicted chain | Stations |
|---|---|---:|
| (3072,0,0) | turn z 537, boundary 2048, FRONT 2304 | 3 |
| (3072,0,1024) | turn z 1138, boundary 2048, FRONT 2304 | 3 |
| (3072,1024,0) | boundary 2048, step start 2304, HIGH 2536 | 3 |
| (3072,1024,1024) | needs a turn as well: 4 stations | `ROOM_STATION_CHAIN_CAPACITY` |

  The last row exceeds `Publication.MAX_STATIONS` = 3. `_existing`'s gateway checks are single-profile, so an
  earlier station cannot serve as the gateway.
- *Missing content, as an alternative to item 1.* A repeatable forward/backward travel pair at yaw 49152 whose
  every air box stays at or below 1024u above the stance.

**3. Levels 2–3: no anchor high enough.**
- The highest BUILD anchor at yaw 49152 is 1039u above the stance (HIGH 26).
- Missing: a WORK row with an anchor 2049..3071u (level 2) or 3073..4095u (level 3) above the stance, or a
  standing datum at those heights with its own ascent motion. Neither exists.

**4. Other headings: one bound retreat row.**
- The provider binds a single retreat row.
- Missing: per-heading retreat binding. This is code, since content has backward rows for all four yaws.

## Budgets (ADR 1205/1207), measured in the loop

| Preparation | Graph | Route checks | Location checks |
|---|---|---:|---:|
| Station publication (2 stations, 4 edges) | 8 edges | 66,854 | 30 |
| Phase peak (CUT commit), cube 1 | 4 edges, 3 Locations | 121,894 | 64 |
| Phase peak (CUT commit), cube 2 | 8 edges, 5 Locations | 162,914 (15.5 %) | 109 |

- **Locations.** Room and phase preparations are still not incremental for Locations (ADR 1207 changed only
  World preparations). Here they cost about 20 checks per Location, so no change is needed.
- **Routes.** Phase commits already carry edges (ADR 1205), but each added edge still costs about 10.3k checks at
  the CUT commit. Extrapolated, the 1,048,576 budget is reached near 94 edges.
- **Today.** The two reachable cubes use 8 edges, so nothing needs to change.
- **A full Kitchen.** About 3–6 new edges per cube over 16 cubes, plus the base, lands at 60–100 edges, which is
  at or over the budget. Before a full Kitchen, either retire a finished cube's station chain (as ADR 1191 does
  for entry contacts) or lower the per-carried-edge cost.

## Also learned

- **Parking.** Publication refuses `ROUTE_OCCUPIED` while the worker stands at the gateway. A foreman must
  park the worker off every new span (here, at a Corridor endpoint reached by real travel) before
  `publish_into`.
- **Stale candidate.** A Location publication changes the qualification revision, so the candidate must be
  re-derived (`next_site_into` from `key − 1`) before `contact_into`.

## Not done

- Production composition: entry foreman, `bind_room_phase_contacts` in entry composition, and Delivery pinning
  (ADR 1202 steps 3, 4 and 7).
- The four seams above.
- Native memory or timing.
- The loop is test-level. The production piece is `next_contact_into`.
