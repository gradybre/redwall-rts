# Connected settlement movement — adopted direction amendment

| Field | Value |
|---|---|
| Document | SET-MOVE-001, revision 1.0, 2026-09-06 |
| Policy authority | DEC-035; preserves DEC-029/031 |
| User authorization | “Agreed with your recommendation on movement, let’s make sure that’s built in the right places in the various spec/md files.” |
| Status | `ADOPTED_DIRECTION`; engineering closure remains `SPEC_INCOMPLETE` |
| Effect | Supersedes ground-only/one-floor claims as the complete required settlement design; defines mandatory cross-document behavior |
| Runtime | `settlement_rules_v2` remains the current baseline; no new save schema, runtime feature or ruleset activation is asserted |
| Technical companion | [Traversal review](art-reference/traversal_design_review.md), including proposed schemas, formulas and F01–F14 synthetic fixtures |
| Creative evidence | [Separate design-reading package](redwall-design/README.md) and [direct modeling guide](art-reference/model_reference_guide.md) |

## 1. Adoption and scope

The settlement shall support persistent constructed tunnels, inhabited underground spaces, surface swimming, diving, and connected climbing/canopy access as parts of ordinary community life. Digging creates space; tunnel travel uses completed space. Swimming moves a resident; boat transport is a separate mechanism. Climbing follows declared connected routes with supported contacts and landings. These are adopted directions, not optional slide ideas awaiting another preference interview.

Placed burrows, planned underground rooms/tunnels and free multi-level excavation remain interoperable first-release requirements under DEC-029/031. This amendment does not reduce those requirements to one floor or decorative entrances. The selected baseline map can remain a test fixture; its former prohibition on swimming cannot remain a final product exclusion. Implementation sequencing may start with ground and shore transitions but cannot report the adopted movement scope complete at that point.

| Included direction | Required practical use | Not settled by this approval |
|---|---|---|
| Finished tunnels | Homes, storage, service routes and workplaces continue to connect after builders leave | Geometric bounds, material costs, spoil, structural hazards |
| Wading/surface swimming/diving distinctions | Valid entry, exit, body/gear/load compatibility and planned return to air | Per-profile capability assignments, speeds, air/recovery rates, hazards |
| Ladders/trunks/branches | Ordinary access, orchard work and observation; safe descent | Specific canopy construction catalog, heights, capacities and clip timings |
| Shared spatial identity | Jobs, occupancy, rooms, transfers, picking and saves agree on actual location | Finite packed arena layouts and migration version |
| Individual eligibility | Body, posture, equipment, training and scenario can affect access | A blanket innate ability table inferred from species or slide lists |

Sapping, traps, combat ambushes, underwater attacks, free flight, moving vessels and arbitrary branch-gap jumping are not included merely because the slides mention them. The settlement remains without a combat layer. Neither new drowning/falling penalties nor immunity to all hazards is chosen here; unsafe behavior cannot be invented as an implementation fallback.

## 2. Normative EARS requirements

| ID | Requirement |
|---|---|
| MOVE-REQ-001 | WHEN a resident changes spatial domain, the simulation shall execute a declared connection with stable endpoints and a valid traversal profile. |
| MOVE-REQ-002 | WHILE excavation is incomplete, the simulation shall keep its unfinished space unavailable for through travel. |
| MOVE-REQ-003 | WHEN any supported underground construction method completes a connected space, the simulation shall publish it through the same topology, room, service and reservation interfaces. |
| MOVE-REQ-004 | WHEN builders leave a completed tunnel, the simulation shall retain the passage until a valid world edit changes it. |
| MOVE-REQ-005 | IF any required capability, body clearance, posture, grip or carried-load condition fails, THEN the planner shall reject that connection and identify the failed condition. |
| MOVE-REQ-006 | WHEN a profile or topology revision changes, the planner shall revalidate affected future route segments before entry. |
| MOVE-REQ-007 | WHILE a resident occupies a transition, the simulation shall preserve its committed progress and valid occupancy when replanning or cancellation occurs. |
| MOVE-REQ-008 | WHEN a player requests deletion of occupied access or its only safe exit, the world-edit transaction shall refuse removal until occupants and held reservations are safely resolved. |
| MOVE-REQ-009 | IF a planned dive lacks a valid air endpoint or its required budget, THEN the simulation shall reject entry before submergence. |
| MOVE-REQ-010 | WHILE a budget-limited resident is submerged, the simulation shall account for travel and waiting on fixed ticks and shall consume no budget while paused. |
| MOVE-REQ-011 | WHEN a resident begins canopy work, the planner shall validate the work contact and a supported return route. |
| MOVE-REQ-012 | WHEN a group requests a constrained route, the planner shall check each participant rather than granting passage from the presence of one specialist. |
| MOVE-REQ-013 | WHEN two residents share X/Z on different levels, the simulation shall retain distinct occupancy and shall require a real connection for transfer or service access. |
| MOVE-REQ-014 | WHEN movement reaches an existing fishing task, the economy shall use the basin's existing authoritative stock and edible whitelist. |
| MOVE-REQ-015 | WHEN a view hides a floor, canopy or water layer, presentation shall preserve simulation occupancy, discovery and visibility. |
| MOVE-REQ-016 | WHEN saving during traversal, the save shall preserve profile revision, occupied locations/edge, progress, reservations, queue order, pending planner readiness and consumed budgets needed for next-tick parity. |
| MOVE-REQ-017 | WHILE distant rendering is active, the renderer shall retain the actual movement family and domain. |
| MOVE-REQ-018 | WHEN a route is blocked, the UI shall distinguish planning, waiting for access, incompatibility and lack of an exit using text as well as color. |
| MOVE-REQ-019 | WHEN a resident changes carried items before a crossing, the economy and movement systems shall agree on the committed load; presentation shall not stow or discard authoritative inventory implicitly. |
| MOVE-REQ-020 | WHEN a development stage lacks the completed movement contract, its release report shall identify that stage as partial and list unimplemented adopted requirements. |

These requirements adopt behavior. The earlier review's proposed numeric encodings, queue rule and synthetic values are not silently promoted to final production catalogs.

## 3. Shared ownership and data contract

Use integer authoritative state and packed structure-of-arrays storage. Reuse generation-validated references and the global identity contract. Keep settlement residents and battle entities in their separate stores. Do not introduce a per-creature movement Node, physics-driven arrival, or animation-event-driven state transition.

| Data owner | Required fields/relations to finalize | Consistency requirement |
|---|---|---|
| Spatial catalog | Stable location handle; domain; level; integer position; topology revision; clearance/occupancy | A flat cell index is insufficient across levels |
| Connection catalog | Endpoint handles; directed access type; supported posture; clearance; load/grip requirements; duration/cost definition | Nearby positions are not implicitly connected |
| Resident movement SoA | Location/edge references; committed profile revision; progress; route reference; mode; budget | At most one committed traversal state per resident |
| Reservation store | Connection/landing claims, ordered requests, owner refs and expiry/release semantics | Removal and admission share a transactional view |
| Job/service store | Work contact, required access and inventory transfer endpoint | Being horizontally close cannot satisfy a below-floor job |
| Construction store | Planned/working/completed space; spoil/material transfers; supporting access; edit dependencies | All three underground tools generate the same usable-space interfaces |
| Rendering catalog | Mode-to-clip mapping, gear posture, contact anchors, bounds and LOD mapping | Animation expresses authority; it never decides legality |
| Save serializer | All state affecting next-tick decisions and content revisions | No unversioned reinterpretation of older ground cells as new locations |

The production contract must define exact field types, finite capacities, sentinel values, overflow/refusal behavior, transaction order and save migration. The conceptual fields above are requirements for that contract, not a completed binary schema.

## 4. Algorithms and arithmetic boundaries

The current flat-grid octile heuristic is admissible only for its original cost graph. A new connection may create a cheaper nonlocal route, so reusing the old heuristic can return incorrect results. The reference solver for an expanded graph shall be Dijkstra (`h=0`) with documented stable tie handling; any optimized production heuristic must prove a lower bound for that graph and agree with the reference on the fixtures. This reference choice does not establish that the inherited expansion quota meets latency targets.

For a completed contract, edge eligibility must conjunct all applicable checks:

`eligible = live_endpoints AND capability_match AND posture_supported AND width_fit AND height_fit AND load_fit AND grip_fit AND access_policy_allows`.

Widths, heights and loads must use the actual committed body-plus-gear profile. Reservation availability is a separate admission/queue condition; a temporarily occupied edge is not necessarily permanently unreachable. Air feasibility requires considering the whole submerged plan, including any permitted wait and safe endpoint. One shortest path that ignores remaining air is insufficient.

| Number or rule | Provenance and handling |
|---|---|
| 30 Hz; 18000 ticks/day; 750/hour; speeds 0/1/2/4 | Inherited and retained |
| Integer positions in 1/1024 m; −Z forward; 1.0 m mouse | Inherited asset/simulation conventions |
| 256 living / 512 resident slots | Inherited population limits; deeper spaces add no residents |
| 2048 planner expansions/tick | Existing baseline quota; expanded-graph performance unverified |
| ARCH-MEM-002 one-floor counts | Baseline-only calculation; invalid as a bound for the adopted expanded scope |
| Review F01–F14 numbers | Authored synthetic tests only; no biological or balance authority |
| New production speeds, depths, oxygen values or recipe quantities | None originated by this amendment |

## 5. Required owner updates and completion gates

| Gate | Owner | Exact closure artifact |
|---|---|---|
| MOVE-G01 | GDD and balance | Finite spatial/depth extents; all construction states, costs and spoil rules; actual traversal profiles; all allowed modes and disabled cases; interruption/hazard policy |
| MOVE-G02 | Architecture | Typed packed tables with finite capacities and byte arithmetic; deterministic routing/queue/deadlock algorithm; ordered topology transactions; versioned save migration |
| MOVE-G03 | UI | Registered layer controls and route panel, exact layout/focus/picking behavior; editing previews; truthful blocked/cancel states |
| MOVE-G04 | Asset/crowd | Versioned clip catalog including transition/contact/held-gear states; exact baked-frame totals, bounds and memory; model clearance fixtures |
| MOVE-G05 | Validation | F01–F14 plus expanded fixtures below; source hashes and reproducible results; workload latency and memory evidence |

These gates are outstanding engineering work with specified outputs. They do not reopen the accepted creative direction. A coding agent may build validated independent baseline systems while these gates are open; it must not invent missing production constants or claim movement/release completeness.

### Acceptance scenarios

| ID | Setup and action | Required observation |
|---|---|---|
| MOVE-TEST-01 | Connect a placed burrow, a planned tunnel and a freely excavated deeper room through finished access | One valid job/service route; builder departure does not remove it |
| MOVE-TEST-02 | Haul through a completed tunnel; change to a load that fails its declared clearance | Future incompatible entry is refused; inventory remains conserved |
| MOVE-TEST-03 | Queue several residents at a constrained crossing; pause/save/reload mid-queue and mid-crossing | Same next owner, progress, resources and authoritative hash as uninterrupted control |
| MOVE-TEST-04 | Plan a dive with no valid exit or inadequate budget; then provide the fixture's valid exit/budget | First entry rejected; valid case admitted under its profile; paused time consumes none |
| MOVE-TEST-05 | Begin branch work and request removal of its only descent | Destructive edit refused with a reason; resident remains on its real route |
| MOVE-TEST-06 | Put residents above/below one another; switch cutaway and select each from the list | Selection follows explicit identity; no cross-floor accidental transfer/picking |
| MOVE-TEST-07 | Harvest one basin from bank and supported water work contacts | One stock balance and the existing whitelist; no separate swimmer stock |
| MOVE-TEST-08 | Run identical commands at 1×/2×/4× and multiple LOD/cutaway states | Equal authoritative state at equal ticks; presentation differences do not alter travel |
| MOVE-TEST-09 | Use a cheap nonlocal connection that defeats flat octile admissibility | Production route equals Dijkstra reference cost and preserves deterministic ties |
| MOVE-TEST-10 | Exhaust each new finite arena and interrupt a topology edit | Defined refusal/rollback; no corrupted handles, lost inventory or stranded occupant |

The user's Windows PC has 64 GB RAM and an RTX 5090 and is currently unavailable. Mac work continues. Record Windows parity/performance as deferred pending its return, and retain the separate qualification-floor obligation. Neither hardware specification nor these document fixtures is benchmark evidence.
